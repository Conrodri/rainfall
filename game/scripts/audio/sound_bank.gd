extends RefCounted
## Table identifiant logique -> fichiers (data/audio/sounds.json) + découverte automatique dans
## assets/audio/ (convention : id "hit.light" -> fichier hit_light.ogg / hit_light_01.ogg ...).
## Un son manquant renvoie simplement null : jamais d'erreur, un seul avertissement par id.

const AUDIO_ROOT := "res://assets/audio/"
const DEFAULT_JSON := "res://data/audio/sounds.json"
const EXTS := ["ogg", "wav", "mp3"]

var families: Dictionary = {}
var sounds: Dictionary = {}
var maps: Dictionary = {}
var ducks: Dictionary = {}
var config: Dictionary = {} ## hit_power, pas, etc.
var prefixes: Array = []
var load_ok := false
var verbose := false

var _index: Dictionary = {} ## clé (basename sans suffixe numérique) -> Array[String] chemins
var _file_cache: Dictionary = {} ## chemin -> AudioStream ou null
var _id_cache: Dictionary = {} ## id -> Array[AudioStream]
var _overrides: Dictionary = {} ## id -> Array[AudioStream] (tests, synthèse de secours)
var _warned: Dictionary = {}
var _last_pick: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func load_json(path: String = DEFAULT_JSON, scan := true) -> bool:
	load_ok = false
	if not FileAccess.file_exists(path):
		push_warning("SoundBank : %s introuvable." % path)
		return false
	var txt := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("SoundBank : JSON invalide (%s)." % path)
		return false
	var d: Dictionary = data
	families = d.get("families", {})
	sounds = d.get("sounds", {})
	maps = d.get("maps", {})
	ducks = d.get("ducks", {})
	config = d.get("config", {})
	prefixes = d.get("prefixes", [])
	_id_cache.clear()
	if scan:
		scan_assets()
	load_ok = true
	return true


## Indexe les fichiers audio présents (récursif). Tolère un dossier absent ou vide.
func scan_assets() -> void:
	_index.clear()
	_scan_dir(AUDIO_ROOT)


func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if dir.current_is_dir():
			if not f.begins_with("."):
				_scan_dir(dir_path + f + "/")
		else:
			var name := f
			if name.ends_with(".import"):
				name = name.trim_suffix(".import")
			elif name.ends_with(".remap"):
				name = name.trim_suffix(".remap")
			var ext := name.get_extension().to_lower()
			if ext in EXTS:
				_add_index(dir_path + name, name.get_basename().to_lower())
		f = dir.get_next()
	dir.list_dir_end()


func _add_index(path: String, base: String) -> void:
	var keys := [base]
	var stripped := _strip_variant(base)
	if stripped != base:
		keys.append(stripped)
	for k in keys:
		var arr: Array = _index.get(k, [])
		if not arr.has(path):
			arr.append(path)
			arr.sort()
		_index[k] = arr


static func _strip_variant(base: String) -> String:
	var i := base.length()
	while i > 0 and base[i - 1] >= "0" and base[i - 1] <= "9":
		i -= 1
	if i < base.length() and i > 0 and (base[i - 1] == "_" or base[i - 1] == "-"):
		i -= 1
	return base.substr(0, i) if i > 0 else base


func indexed_count() -> int:
	return _index.size()


func set_override(id: StringName, streams: Array) -> void:
	_overrides[id] = streams
	_id_cache.erase(id)


func clear_overrides() -> void:
	_overrides.clear()
	_id_cache.clear()


## Définition fusionnée : valeurs de la famille puis du son.
func get_def(id: StringName) -> Dictionary:
	var s: Dictionary = sounds.get(String(id), {})
	var fam_name: String = s.get("family", "")
	if fam_name == "":
		fam_name = _family_by_prefix(String(id))
	var fam: Dictionary = families.get(fam_name, {})
	var def := fam.duplicate()
	def.merge(s, true)
	def["family"] = fam_name
	if not def.has("bus"):
		def["bus"] = "SFX"
	return def


func _family_by_prefix(id: String) -> String:
	for p in prefixes:
		if typeof(p) == TYPE_ARRAY and p.size() == 2 and id.begins_with(String(p[0])):
			return String(p[1])
	return "misc"


func streams_for(id: StringName) -> Array:
	if _overrides.has(id):
		return _overrides[id]
	if _id_cache.has(id):
		return _id_cache[id]
	var out: Array = []
	var s: Dictionary = sounds.get(String(id), {})
	for rel in s.get("files", []):
		var st := _load_file(AUDIO_ROOT + String(rel))
		if st != null:
			out.append(st)
	if out.is_empty():
		var key := String(id).replace(".", "_").to_lower()
		for path in _index.get(key, []):
			var st := _load_file(String(path))
			if st != null:
				out.append(st)
	if out.is_empty():
		_warn_once(id)
	_id_cache[id] = out
	return out


func has_sound(id: StringName) -> bool:
	return not streams_for(id).is_empty()


func pick_stream(id: StringName) -> AudioStream:
	var arr := streams_for(id)
	if arr.is_empty():
		return null
	if arr.size() == 1:
		return arr[0]
	var last: int = _last_pick.get(id, -1)
	var i := _rng.randi() % arr.size()
	if i == last:
		i = (i + 1) % arr.size()
	_last_pick[id] = i
	return arr[i]


func _load_file(path: String) -> AudioStream:
	if _file_cache.has(path):
		return _file_cache[path]
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is AudioStream:
			st = r
	elif FileAccess.file_exists(path) and path.get_extension().to_lower() == "ogg":
		st = AudioStreamOggVorbis.load_from_file(path) # fichier non encore importé (dev)
	_file_cache[path] = st
	return st


func _warn_once(id: StringName) -> void:
	if verbose and not _warned.has(id):
		_warned[id] = true
		print("Audio : son manquant « %s » (silence)." % id)


## Copie bouclée d'un flux (sans toucher la ressource partagée).
static func looped(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	if stream is AudioStreamOggVorbis:
		var s := (stream as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
		s.loop = true
		return s
	if stream is AudioStreamWAV:
		var w := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / maxi(1, (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1))
		return w
	return stream
