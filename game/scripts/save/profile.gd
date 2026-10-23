extends Node
## Autoload `Profile` : méta-progression persistante (docs/Design_Menus.md §6.2).
## Fichier `user://profile.json` : rubis, modes / personnages / sorts débloqués, dernier choix,
## stats. Chargé dans _ready ; jamais écrit en headless (sauf `write_enabled` forcé par un test
## avec un `path` de test). Écriture atomique (`.tmp` puis renommage), immédiate à chaque changement.
##
## Clés de déblocage (`is_unlocked`) : "mode:<id>", "character:<id>", "spell:<id>".
## Variantes de sorts (game/CONTRACTS.md « Variantes de sorts ») : `loadout` mémorise par personnage le sort choisi
## par emplacement ; `unlock_rule` des variantes (characters.json) évaluées en fin de run par VariantUnlocks ;
## compteurs génériques `stats[<clé>]` via `add_stat(key, n)`.

signal changed

const PATH := "user://profile.json"
const VERSION := 1
const DEFAULT_MODES: Array = [&"facile", &"moyen"]
const DEFAULT_CHARACTERS: Array = [&"ardent"]
## Mode débloqué par une victoire dans un mode donné.
const UNLOCK_ON_VICTORY := {&"moyen": &"difficile"}
## Objectifs cumulés sur toutes les runs : clé du résultat de run -> [seuil, clé débloquée].
## Rictus (caché) : 200 monstres tués à moins de 2 u de soi (Player.close_kills).
const UNLOCK_ON_OBJECTIVE := {"close_kills": [200.0, &"character:rictus"]}
const VariantUnlocks := preload("res://scripts/save/variant_unlocks.gd")
## TEMPORAIRE (à retirer avant la sortie) : toutes les variantes de sorts débloquées, sans rien écrire au profil.
## Variable d'environnement `RAINFALL_UNLOCK_ALL_VARIANTS=1` ou argument utilisateur `-- --unlock-variants`.
const UNLOCK_ALL_VARIANTS_ENV := "RAINFALL_UNLOCK_ALL_VARIANTS"
const UNLOCK_ALL_VARIANTS_ARG := "--unlock-variants"

var path := PATH
var write_enabled := DisplayServer.get_name() != "headless"

var rubies := 0:
	set(v):
		rubies = maxi(v, 0)
		_touch()
var unlocked_modes: Array = DEFAULT_MODES.duplicate() ## StringName
var unlocked_characters: Array = DEFAULT_CHARACTERS.duplicate() ## StringName
var unlocked_spells: Array = [] ## StringName (ids de variantes de sorts)
var last_mode: StringName = &"moyen":
	set(v):
		last_mode = StringName(v)
		_touch()
var last_character: StringName = &"ardent":
	set(v):
		last_character = StringName(v)
		_touch()
## runs, victories, kills, play_time_s, best_time_s {mode: s} (temps de la run victorieuse la plus courte)
var stats := _default_stats()
var objectives := {} ## id -> progression (float)
## Mémoire des boss (docs/Design_Etages.md §2.2, §6.2) : étage (clé texte "1".."5") -> id du boss d'étage vu à cet
## étage lors de la run la plus récente. Au tirage du plan (FloorPlan), ce boss pèse × Balance.BOSS_MEMORY_WEIGHT.
var last_floor_boss := {}
## Invites d'onboarding déjà montrées (docs/ux/Audit_Menus.md §3.1, lot M-A) : ids texte (OnboardingHints.SEQUENCE).
var seen_hints: Array = []
## Sorts choisis par personnage (fiche Nouvelle run) : id perso (texte) -> {"<slot>": "<id du sort>"} (base ou variante).
var loadout := {}
## TEMPORAIRE (test) : vrai = toutes les variantes passent pour débloquées (lu une fois au démarrage, injectable).
var unlock_all_variants := _detect_unlock_all_variants()
## Roster lu par le moteur de déblocage des variantes (null = data/characters.json ; tests : liste injectée).
var characters_override: Variant = null

var _loading := false


func _ready() -> void:
	load_profile()
	Events.boss_spawned.connect(_on_boss_spawned)


func _default_stats() -> Dictionary:
	return {"runs": 0, "victories": 0, "kills": 0, "play_time_s": 0.0, "best_time_s": {}}


## Remet les valeurs par défaut (sans écrire).
func reset() -> void:
	_loading = true
	rubies = 0
	unlocked_modes = DEFAULT_MODES.duplicate()
	unlocked_characters = DEFAULT_CHARACTERS.duplicate()
	unlocked_spells = []
	last_mode = &"moyen"
	last_character = &"ardent"
	stats = _default_stats()
	objectives = {}
	last_floor_boss = {}
	seen_hints = []
	loadout = {}
	_loading = false


## Relit le profil depuis `path` (absent ou illisible : valeurs par défaut).
func load_profile() -> void:
	reset()
	if not FileAccess.file_exists(path):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		push_warning("Profil illisible (%s) : valeurs par défaut" % path)
		return
	_loading = true
	rubies = int(d.get("rubies", 0))
	unlocked_modes = _names(d.get("unlocked_modes", []), DEFAULT_MODES)
	unlocked_characters = _names(d.get("unlocked_characters", []), DEFAULT_CHARACTERS)
	unlocked_spells = _names(d.get("unlocked_spells", []), [])
	last_mode = StringName(str(d.get("last_mode", "moyen")))
	last_character = StringName(str(d.get("last_character", "ardent")))
	var s: Variant = d.get("stats", {})
	if s is Dictionary:
		for k in stats:
			if s.has(k):
				stats[k] = s[k]
		stats["runs"] = int(stats["runs"])
		stats["victories"] = int(stats["victories"])
		stats["kills"] = int(stats["kills"])
		stats["play_time_s"] = float(stats["play_time_s"])
		if not (stats["best_time_s"] is Dictionary):
			stats["best_time_s"] = {}
		for k in s: # compteurs génériques (add_stat) : toute clé numérique inconnue est gardée
			if not stats.has(k) and (s[k] is float or s[k] is int):
				stats[str(k)] = float(s[k])
	var o: Variant = d.get("objectives", {})
	objectives = o if o is Dictionary else {}
	var lb: Variant = d.get("last_floor_boss", {})
	last_floor_boss = {}
	if lb is Dictionary:
		for k in lb:
			last_floor_boss[str(k)] = str(lb[k])
	var sh: Variant = d.get("seen_hints", [])
	seen_hints = []
	if sh is Array:
		for v in sh:
			if not seen_hints.has(str(v)):
				seen_hints.append(str(v))
	var lo: Variant = d.get("loadout", {})
	loadout = {}
	if lo is Dictionary:
		for cid in lo:
			if lo[cid] is Dictionary:
				var m := {}
				for slot in lo[cid]:
					m[str(int(str(slot)))] = str(lo[cid][slot])
				loadout[str(cid)] = m
	_loading = false
	changed.emit()


func _names(src: Variant, defaults: Array) -> Array:
	var out: Array = defaults.duplicate()
	if src is Array:
		for v in src:
			var n := StringName(str(v))
			if not out.has(n):
				out.append(n)
	return out


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "rubies": rubies,
		"unlocked_modes": unlocked_modes.map(func(v): return String(v)),
		"unlocked_characters": unlocked_characters.map(func(v): return String(v)),
		"unlocked_spells": unlocked_spells.map(func(v): return String(v)),
		"last_mode": String(last_mode), "last_character": String(last_character),
		"stats": stats, "objectives": objectives, "last_floor_boss": last_floor_boss,
		"seen_hints": seen_hints, "loadout": loadout,
	}


## Écriture atomique immédiate. false si désactivée (headless) ou en échec.
func save() -> bool:
	if not write_enabled:
		return false
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Profil : écriture impossible (%s)" % tmp)
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.flush()
	f.close()
	var abs_p := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_p)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_p) == OK


func _touch() -> void:
	if _loading:
		return
	save()
	changed.emit()


# --- Déblocages ---------------------------------------------------------------

## "mode:<id>" | "character:<id>" | "spell:<id>" (un id seul = personnage).
func is_unlocked(key: StringName) -> bool:
	var s := String(key)
	var i := s.find(":")
	var kind := s.substr(0, i) if i >= 0 else "character"
	var id := StringName(s.substr(i + 1) if i >= 0 else s)
	match kind:
		"mode":
			return unlocked_modes.has(id)
		"character":
			return unlocked_characters.has(id)
		"spell":
			return unlock_all_variants or unlocked_spells.has(id)
	return false


## Débloque une clé ; true si c'est nouveau.
func unlock(key: StringName) -> bool:
	var s := String(key)
	var i := s.find(":")
	var kind := s.substr(0, i) if i >= 0 else "character"
	var id := StringName(s.substr(i + 1) if i >= 0 else s)
	# Possession réelle (le mode test « toutes les variantes » n'empêche pas d'enregistrer un vrai déblocage).
	if (kind == "spell" and unlocked_spells.has(id)) or (kind != "spell" and is_unlocked(key)):
		return false
	match kind:
		"mode":
			unlocked_modes.append(id)
		"character":
			unlocked_characters.append(id)
		"spell":
			unlocked_spells.append(id)
		_:
			return false
	_touch()
	return true


func is_mode_unlocked(mode: StringName) -> bool:
	return unlocked_modes.has(StringName(mode))


func is_character_unlocked(id: StringName) -> bool:
	return unlocked_characters.has(StringName(id))


## Personnages déjà jouables sans le profil (`"unlocked": true` dans data/characters.json, ex. ouverts pour les
## tests). Lu une fois ; un test peut injecter une liste (ex. [] pour simuler la configuration de sortie).
var open_characters: Variant = null


## Vrai si le personnage est déjà jouable (profil OU characters.json) : son déblocage n'est alors pas « nouveau ».
func is_character_available(id: StringName) -> bool:
	if is_character_unlocked(id):
		return true
	if open_characters == null:
		var arr: Array = []
		var f := FileAccess.open("res://data/characters.json", FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		if parsed is Array:
			for c in parsed:
				if c is Dictionary and bool(c.get("unlocked", false)):
					arr.append(StringName(str(c.get("id", ""))))
		open_characters = arr
	return (open_characters as Array).has(StringName(id))


func add_rubies(n: int) -> void:
	if n != 0:
		rubies += n


func objective_progress(id: StringName) -> float:
	return float(objectives.get(String(id), 0.0))


func set_objective_progress(id: StringName, value: float) -> void:
	objectives[String(id)] = value
	_touch()


## Résultat d'une run terminée : {victory, mode, character, active_time_s, kills, rubies}.
## Crédite les rubis, met à jour les stats, applique les déblocages ; une seule écriture.
## Retourne les déblocages obtenus (ex. [&"mode:difficile"]).
func add_run_result(r: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var mode := StringName(str(r.get("mode", "moyen")))
	var victory := bool(r.get("victory", false))
	var t := float(r.get("active_time_s", 0.0))
	_loading = true
	rubies += int(r.get("rubies", 0))
	stats["runs"] = int(stats["runs"]) + 1
	stats["kills"] = int(stats["kills"]) + int(r.get("kills", 0))
	stats["play_time_s"] = float(stats["play_time_s"]) + t
	if victory:
		stats["victories"] = int(stats["victories"]) + 1
		var best: Dictionary = stats["best_time_s"]
		var k := String(mode)
		if not best.has(k) or t < float(best[k]):
			best[k] = t
		if UNLOCK_ON_VICTORY.has(mode):
			var key := StringName("mode:" + String(UNLOCK_ON_VICTORY[mode]))
			if not is_unlocked(key):
				unlocked_modes.append(UNLOCK_ON_VICTORY[mode])
				out.append(key)
	for obj: String in UNLOCK_ON_OBJECTIVE:
		if not r.has(obj):
			continue
		var v := float(objectives.get(obj, 0.0)) + float(r[obj])
		objectives[obj] = v
		var rule: Array = UNLOCK_ON_OBJECTIVE[obj]
		var ukey := StringName(rule[1])
		if v >= float(rule[0]) and not is_unlocked(ukey):
			# Annoncé seulement si c'est nouveau pour le joueur (pas un perso déjà ouvert par characters.json).
			var us := String(ukey)
			var known := us.begins_with("character:") and is_character_available(StringName(us.substr(10)))
			unlock(ukey)
			if not known:
				out.append(ukey)
	# Compteurs génériques de la run (RunState.counters -> clé "counters") : cumulés dans stats[<clé>].
	var cn: Variant = r.get("counters", {})
	if cn is Dictionary:
		for ck in cn:
			add_stat(str(ck), float(cn[ck]))
	# Variantes de sorts : règles `unlock_rule` de characters.json (VariantUnlocks).
	for vkey: StringName in VariantUnlocks.evaluate(self, _roster(), r):
		if not unlocked_spells.has(StringName(String(vkey).substr(6))):
			unlocked_spells.append(StringName(String(vkey).substr(6)))
			out.append(vkey)
	_loading = false
	_touch()
	return out


# --- Compteurs et variantes de sorts ------------------------------------------------------

## Ajoute `n` au compteur générique `stats[key]` (créé à 0). Écrit le profil (sauf pendant add_run_result).
func add_stat(key: String, n: float = 1.0) -> void:
	if key == "" or n == 0.0:
		return
	if key in ["runs", "victories", "kills"]:
		stats[key] = int(stats.get(key, 0)) + int(n)
	elif stats.get(key) is Dictionary:
		push_warning("Profile.add_stat : clé réservée « %s »" % key)
		return
	else:
		stats[key] = float(stats.get(key, 0.0)) + n
	_touch()


## Valeur d'un compteur générique (0 si absent).
func stat(key: String) -> float:
	var v: Variant = stats.get(key, 0.0)
	return float(v) if (v is float or v is int) else 0.0


## Sorts mémorisés pour un personnage : {slot (int) -> id du sort (StringName)} ; {} si rien.
func get_loadout(cid: StringName) -> Dictionary:
	var out := {}
	var m: Variant = loadout.get(String(cid), {})
	if m is Dictionary:
		for k in m:
			out[int(str(k))] = StringName(str(m[k]))
	return out


## Mémorise les sorts choisis {slot -> id} d'un personnage (écrit seulement si ça change).
func set_loadout(cid: StringName, spells: Dictionary) -> void:
	if String(cid) == "":
		return
	var m := {}
	for k in spells:
		var id := str(spells[k])
		if id != "":
			m[str(int(str(k)))] = id
	if loadout.get(String(cid), {}) == m:
		return
	loadout[String(cid)] = m
	_touch()


func _roster() -> Array:
	if characters_override is Array:
		return characters_override
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	return parsed if parsed is Array else []


static func _detect_unlock_all_variants() -> bool:
	var e := OS.get_environment(UNLOCK_ALL_VARIANTS_ENV)
	if e != "" and e != "0" and e.to_lower() != "false":
		return true
	return OS.get_cmdline_user_args().has(UNLOCK_ALL_VARIANTS_ARG)


# --- Mémoire des boss -----------------------------------------------------------------

## Boss d'étage vu à l'étage `floor_n` lors de la run la plus récente (&"" si aucun).
func last_boss_of_floor(floor_n: int) -> StringName:
	return StringName(str(last_floor_boss.get(str(floor_n), "")))


## Poids du boss `id` au tirage de l'étage `floor_n` : Balance.BOSS_MEMORY_WEIGHT s'il y a été vu la dernière fois.
func floor_boss_weight(floor_n: int, id: StringName) -> float:
	return Balance.BOSS_MEMORY_WEIGHT if id != &"" and last_boss_of_floor(floor_n) == id else 1.0


## Note le boss d'étage vu à l'étage `floor_n` (écrit seulement s'il change).
func record_floor_boss(floor_n: int, id: StringName) -> void:
	if floor_n <= 0 or id == &"" or last_boss_of_floor(floor_n) == id:
		return
	last_floor_boss[str(floor_n)] = String(id)
	_touch()


## Apparition d'un boss d'étage : mémorisé pour l'étage de la boucle courante (FloorPlan.floor_of_stage).
func _on_boss_spawned(boss: Node2D, is_floor_boss: bool) -> void:
	if not is_floor_boss or boss == null or not boss.has_method(&"boss_id"):
		return
	record_floor_boss(FloorPlan.floor_of_stage(int(RunState.stage)), boss.boss_id())


# --- Onboarding (lot M-A) ------------------------------------------------------

func has_seen_hint(id: String) -> bool:
	return seen_hints.has(id)


## Note une invite comme vue (écrit le profil). Sans effet si déjà vue.
func mark_hint_seen(id: String) -> void:
	if id == "" or seen_hints.has(id):
		return
	seen_hints.append(id)
	_touch()
