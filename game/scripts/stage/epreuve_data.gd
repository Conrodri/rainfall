class_name EpreuveData
extends RefCounted
## Données des Épreuves par biome (data/epreuves.json, docs/Design_Epreuves.md §7.2) : verbes, interrupteur par biome,
## skin des relais du Rituel, libellés d'interaction. Chargé une fois ; fichier absent ou invalide = aucune épreuve.

const PATH := "res://data/epreuves.json"

static var _data: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {}
	if not FileAccess.file_exists(PATH):
		push_warning("EpreuveData : %s absent, aucune épreuve." % PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("EpreuveData : %s invalide, aucune épreuve." % PATH)


## Recharge le fichier (tests).
static func reload() -> void:
	_loaded = false
	_load()


static func _biome(biome: String) -> Dictionary:
	_load()
	var b = (_data.get("biomes", {}) as Dictionary).get(biome, {})
	return b if b is Dictionary else {}


## Le biome (clé de `floors.json` : terrasses, foret, cite, cryptes, source) figure dans le fichier.
static func has_biome(biome: String) -> bool:
	return not _biome(biome).is_empty()


## Les épreuves du biome sont actives (interrupteur `enabled` et au moins un verbe).
static func enabled(biome: String) -> bool:
	var b := _biome(biome)
	return bool(b.get("enabled", false)) and not verbs(biome).is_empty()


## Verbes du biome, dans l'ordre (épreuve 1, épreuve 2).
static func verbs(biome: String) -> Array[String]:
	var out: Array[String] = []
	for v in _biome(biome).get("verbs", []):
		out.append(String(v))
	return out


## Verbes connus (clé `names`).
static func all_verbs() -> Array[String]:
	_load()
	var out: Array[String] = []
	for k in (_data.get("names", {}) as Dictionary).keys():
		out.append(String(k))
	return out


static func verb_name(verb: String) -> String:
	_load()
	return String((_data.get("names", {}) as Dictionary).get(verb, verb.capitalize()))


## Dossier de sprites des leviers (`lever_<skin>_{off,on}`) pour les relais du Rituel dans ce biome.
static func lever_skin(biome: String) -> StringName:
	return StringName(String(_biome(biome).get("lever_skin", "terraces")))


## Libellé d'interaction (`key` : "start", "relay") ; `fallback` si absent.
static func label(biome: String, verb: String, key: String, fallback: String = "") -> String:
	var l = (_biome(biome).get("labels", {}) as Dictionary).get(verb, {})
	if l is Dictionary:
		return String((l as Dictionary).get(key, fallback))
	return fallback
