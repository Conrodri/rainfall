class_name SteamCloudSync
extends RefCounted
## Sauvegarde du profil (user://profile.json) dans Steam Cloud par l'API Remote Storage de GodotSteam.
## Pourquoi Remote Storage plutôt qu'Auto-Cloud : docs/Integration_Steam.md §5 (règle de conflit maîtrisée + copie
## de l'ancienne version, qu'Auto-Cloud ne fait pas).
##
## Règles (jamais de perte) :
## - Le fichier local reste la source : le jeu lit et écrit toujours user://profile.json ; le cloud n'en est qu'une copie.
## - Au démarrage (`sync_at_start`) : contenus identiques = rien ; un seul côté lisible = il gagne ; sinon le plus récent
##   gagne (date de modification du fichier local contre horodatage Steam du fichier distant ; égalité = local).
## - Le perdant est toujours copié dans user://profile_backups/ (BACKUP_KEEP copies au plus, les plus anciennes partent).
## - En cours de partie (`push`) : envoie le fichier local tel qu'il est sur le disque (jamais l'état mémoire), seulement
##   s'il a changé depuis le dernier envoi. Aucun envoi en bac à sable (mode test) ni si l'écriture du profil est coupée.
##
## `api` : singleton GodotSteam (ou faux des tests) ; `profile` : autoload Profile (ou équivalent : path, write_enabled,
## sandbox, load_profile(), signal changed).

const REMOTE_FILE := "profile.json"
const BACKUP_DIR := "user://profile_backups"
const BACKUP_KEEP := 5

## Dossier des copies de sauvegarde (les tests passent un user://test_…).
var backup_dir := BACKUP_DIR
var _api: Object
var _profile: Object
var _last_hash := ""
## Dernier résultat de `sync_at_start` : "off" | "same" | "pushed" | "pulled" | "empty" | "error".
var last_result := "off"


func _init(api: Object, profile: Object) -> void:
	_api = api
	_profile = profile


## Le cloud est-il utilisable ? (Steam initialisé, cloud activé pour le compte ET pour le jeu, profil inscriptible.)
func available() -> bool:
	if _api == null or _profile == null:
		return false
	if not bool(_profile.get(&"write_enabled")) or bool(_profile.get(&"sandbox")):
		return false
	return bool(_call(&"isCloudEnabledForAccount", [], false)) and bool(_call(&"isCloudEnabledForApp", [], false))


## Réconciliation au démarrage. Renvoie last_result.
func sync_at_start() -> String:
	last_result = "off"
	if not available():
		return last_result
	var path := _local_path()
	var local_text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var local_ok := _valid(local_text)
	var remote_text := _read_remote()
	var remote_ok := _valid(remote_text)
	if not local_ok and not remote_ok:
		last_result = "empty"
		return last_result
	if local_ok and remote_ok and local_text == remote_text:
		_last_hash = local_text.sha256_text()
		last_result = "same"
		return last_result
	var take_remote := false
	if remote_ok and not local_ok:
		take_remote = true
	elif remote_ok and local_ok:
		var remote_ts := int(_call(&"getFileTimestamp", [REMOTE_FILE], 0))
		var local_ts := int(FileAccess.get_modified_time(path))
		take_remote = remote_ts > local_ts
	if take_remote:
		if local_text != "":
			backup(local_text, "local")
		if not _write_local(remote_text):
			last_result = "error"
			return last_result
		_last_hash = remote_text.sha256_text()
		if _profile.has_method(&"load_profile"):
			_profile.call(&"load_profile")
		if _profile.has_signal(&"changed"):
			_profile.emit_signal(&"changed")
		last_result = "pulled"
	else:
		if remote_text != "":
			backup(remote_text, "cloud")
		last_result = "pushed" if push(true) else "error"
	return last_result


## Envoie le fichier local au cloud s'il a changé depuis le dernier envoi (ou si `force`). true si envoyé.
func push(force := false) -> bool:
	if not available():
		return false
	var path := _local_path()
	if not FileAccess.file_exists(path):
		return false
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	if not _valid(text):
		return false # jamais de profil illisible envoyé au cloud
	var h := text.sha256_text()
	if h == _last_hash and not force:
		return false
	if not bool(_call(&"fileWrite", [REMOTE_FILE, bytes, bytes.size()], false)):
		return false
	_last_hash = h
	return true


## Copie `text` dans user://profile_backups/profile_<date>_<origine>.json ; garde les BACKUP_KEEP plus récentes.
func backup(text: String, origin: String) -> String:
	DirAccess.make_dir_recursive_absolute(backup_dir)
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "-").replace("T", "_")
	var p := "%s/profile_%s_%s.json" % [backup_dir, stamp, origin]
	var n := 1
	while FileAccess.file_exists(p):
		n += 1
		p = "%s/profile_%s_%s_%d.json" % [backup_dir, stamp, origin, n]
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		push_warning("Steam Cloud : copie de sauvegarde impossible (%s)" % p)
		return ""
	f.store_string(text)
	f.close()
	_prune_backups()
	return p


func _prune_backups() -> void:
	var files: Array = []
	for fname in DirAccess.get_files_at(backup_dir):
		if fname.begins_with("profile_") and fname.ends_with(".json"):
			files.append(fname)
	files.sort() # nom horodaté : ordre chronologique
	while files.size() > BACKUP_KEEP:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [backup_dir, files.pop_front()]))


func _local_path() -> String:
	return str(_profile.get(&"path"))


func _read_remote() -> String:
	if not bool(_call(&"fileExists", [REMOTE_FILE], false)):
		return ""
	var size := int(_call(&"getFileSize", [REMOTE_FILE], 0))
	if size <= 0:
		return ""
	var r: Variant = _call(&"fileRead", [REMOTE_FILE, size], {})
	if not (r is Dictionary) or int((r as Dictionary).get("ret", 0)) <= 0:
		return ""
	var buf: Variant = (r as Dictionary).get("buf", PackedByteArray())
	if not (buf is PackedByteArray):
		return ""
	return (buf as PackedByteArray).slice(0, int(r["ret"])).get_string_from_utf8()


## Écriture atomique du profil local (.tmp puis renommage), comme Profile.save.
func _write_local(text: String) -> bool:
	var path := _local_path()
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Steam Cloud : écriture du profil impossible (%s)" % tmp)
		return false
	f.store_string(text)
	f.flush()
	f.close()
	var abs_p := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_p)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_p) == OK


## Texte de profil lisible (objet JSON). JSON.parse (instance) plutôt que JSON.parse_string : aucune erreur
## affichée sur un fichier corrompu.
static func _valid(text: String) -> bool:
	if text == "":
		return false
	var j := JSON.new()
	return j.parse(text) == OK and j.data is Dictionary


func _call(method: StringName, args: Array, fallback: Variant) -> Variant:
	if _api == null or not _api.has_method(method):
		return fallback
	return _api.callv(method, args)
