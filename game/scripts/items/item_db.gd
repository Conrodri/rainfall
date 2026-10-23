class_name ItemDB
extends RefCounted
## Chargement et cache de data/items.json (schéma : game/CONTRACTS.md).

const DEFAULT_PATH := "res://data/items.json"
const QUALITIES: Array[StringName] = [&"commun", &"peu_commun", &"rare", &"legendaire"]

static var _path := DEFAULT_PATH
static var _items: Dictionary = {} ## id (String) -> Dictionary
static var _by_quality: Dictionary = {} ## qualité (StringName) -> Array[String]
static var _loaded := false


## Change la source (tests : fixture) et invalide le cache.
static func set_source(path: String) -> void:
	_path = path
	_loaded = false


static func reload() -> void:
	_loaded = false
	_ensure()


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_items = {}
	_by_quality = {}
	for q in QUALITIES:
		_by_quality[q] = []
	if not FileAccess.file_exists(_path):
		push_warning("ItemDB : %s introuvable" % _path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("items"):
		parsed = parsed["items"]
	if typeof(parsed) != TYPE_ARRAY:
		push_error("ItemDB : format invalide dans %s" % _path)
		return
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			continue
		var id := str(entry["id"])
		_items[id] = entry
		var q := StringName(str(entry.get("quality", "commun")))
		if not _by_quality.has(q):
			_by_quality[q] = []
		_by_quality[q].append(id)


static func has_item(id: Variant) -> bool:
	_ensure()
	return _items.has(str(id))


## Retourne la fiche (Dictionary vide si inconnue).
static func get_item(id: Variant) -> Dictionary:
	_ensure()
	return _items.get(str(id), {})


static func all_ids() -> Array:
	_ensure()
	return _items.keys()


## Table d'une qualité : Array d'ids (String).
static func ids_of_quality(quality: StringName) -> Array:
	_ensure()
	return _by_quality.get(quality, [])
