class_name Cosmetics
extends RefCounted
## Boutique cosmétique (docs/Boutique_Rubis.md) : lecture du catalogue data/cosmetics.json et de ce que le joueur a
## équipé. Purement cosmétique : payé en rubis gagnés en jouant, jamais en argent réel, aucun effet sur le jeu
## (aucun script de scripts/core/ ne lit cette classe pour une valeur de gameplay).
##
## Familles v1 : `panoplie` (tenues thématiques par personnage, contrat de skin de docs/Skins.md), `ciel` (profil
## d'ambiance alternatif par biome), `sillage` (traces de pas sous le joueur), `parement` (cadres 9-slices de l'UI),
## `veillee` (thème de l'écran titre). Article : {id, family, name, desc, price, target, assets: {...}}.
##
## Un seul point de vérité, le profil (Profile) :
##   - possession : Profile.owned_cosmetics (ids) ; achat : Profile.buy_cosmetic(id) (débit par Profile.spend_rubies) ;
##   - équipement : Profile.equipped["<famille>:<cible>"] = id, via Profile.equip_cosmetic(slot, id). Les Panoplies
##     passent par Profile.selected_skin (inchangé) : une Panoplie est un skin de plus du personnage (Skins.skins_of).
## Cible : id du personnage (panoplie), id du biome (ciel), sinon « all » (familles globales).
##
## Assets absents (Codex les rend plus tard) : l'article reste visible en boutique, marqué « bientôt », non achetable ;
## un article possédé dont un asset manque retombe silencieusement sur l'apparence par défaut (has_assets).
## Mode test : `test_override` (slot -> id) équipe n'importe quel article sans l'acheter ni écrire au profil ; il n'est
## lu que si TestMode.active.

const DATA_PATH := "res://data/cosmetics.json"
const FAMILIES: Array[StringName] = [&"panoplie", &"ciel", &"sillage", &"parement", &"veillee"]
## Noms affichés par défaut (le catalogue peut les remplacer : families.<id>.name).
const FAMILY_NAMES := {&"panoplie": "Panoplies", &"ciel": "Ciels", &"sillage": "Sillages", &"parement": "Parements", &"veillee": "Veillées"}
## Familles dont l'équipement dépend d'une cible (personnage, biome).
const TARGETED: Array[StringName] = [&"panoplie", &"ciel"]
const GLOBAL_TARGET := "all"
const SILLAGE_STEPS := "pas"
const SILLAGE_DODGE := "esquive"
## Scènes des cartes (asset « map » d'une Veillée : id de carte, pas un chemin).
const MAPS_DIR := "res://scenes/stage/maps/"
## Clés interdites dans un article : un cosmétique ne porte jamais d'effet de jeu (docs/Boutique_Rubis.md §2.3).
const FORBIDDEN_KEYS: Array[String] = ["effects", "stats", "mult", "bonus", "unlock_rule", "damage", "hp"]
const FALLBACK_PRICE := 250

## Catalogue injectable (tests) ; null = data/cosmetics.json.
static var data_override: Variant = null
## Mode test : slot « famille:cible » -> id forcé ("" = défaut). Ignoré hors TestMode.active.
static var test_override := {}
static var _test_hooked := false
static var _cache: Variant = null


static func data() -> Dictionary:
	if data_override is Dictionary:
		return data_override
	if _cache == null:
		_cache = {}
		if FileAccess.file_exists(DATA_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
			if parsed is Dictionary:
				_cache = parsed
			else:
				push_warning("Cosmetics : %s illisible" % DATA_PATH)
	return _cache


## Relit data/cosmetics.json au prochain accès (après une livraison, ou pour les tests).
static func reload() -> void:
	_cache = null


static func items() -> Array:
	var arr: Variant = data().get("items", [])
	return arr if arr is Array else []


static func item(id: Variant) -> Dictionary:
	var s := str(id)
	if s == "":
		return {}
	for it in items():
		if it is Dictionary and str(it.get("id", "")) == s:
			return it
	return {}


static func is_item(id: Variant) -> bool:
	return not item(id).is_empty()


static func family_of(it: Dictionary) -> StringName:
	return StringName(str(it.get("family", "")))


## Cible d'un article : personnage / biome, « all » pour une famille globale. Sillages : deux emplacements distincts,
## lus du catalogue (`target`) et jamais déduits des assets : « sillage:pas » (traces de pas : assets particle/step) et
## « sillage:esquive » (traînée d'esquive : assets wake/burst), pour qu'une traînée d'esquive n'efface pas les traces
## de pas. Un Sillage sans cible (ou avec une cible inconnue) vaut « pas ».
static func target_of(it: Dictionary) -> String:
	var t := str(it.get("target", ""))
	var fam := family_of(it)
	if TARGETED.has(fam):
		return t
	if fam == &"sillage":
		return SILLAGE_DODGE if t == SILLAGE_DODGE else SILLAGE_STEPS
	return t if t != "" else GLOBAL_TARGET


## Emplacement d'équipement « famille:cible » (cible vide d'une famille globale = « all » ; sillage vide = « pas »).
static func slot(family: Variant, target: Variant = "") -> String:
	var t := str(target)
	if t == "" and not TARGETED.has(StringName(str(family))):
		t = SILLAGE_STEPS if StringName(str(family)) == &"sillage" else GLOBAL_TARGET
	return "%s:%s" % [str(family), t]


static func slot_of(it: Dictionary) -> String:
	return slot(family_of(it), target_of(it))


## Articles d'une famille (et d'une cible si `target` n'est pas null), dans l'ordre du catalogue.
static func items_of(family: Variant, target: Variant = null) -> Array:
	var out: Array = []
	for it in items():
		if not (it is Dictionary) or family_of(it) != StringName(str(family)):
			continue
		if target != null and target_of(it) != str(target):
			continue
		out.append(it)
	return out


## Familles à montrer en boutique (ordre FAMILIES, puis celles en plus du catalogue s'il en déclare).
static func families() -> Array[StringName]:
	var out: Array[StringName] = FAMILIES.duplicate()
	var fam: Variant = data().get("families", {})
	if fam is Dictionary:
		for k in fam:
			if not out.has(StringName(str(k))):
				out.append(StringName(str(k)))
	return out


static func family_name(family: Variant) -> String:
	var fam: Variant = data().get("families", {})
	if fam is Dictionary and (fam as Dictionary).get(str(family)) is Dictionary:
		var n := str(fam[str(family)].get("name", ""))
		if n != "":
			return n
	return str(FAMILY_NAMES.get(StringName(str(family)), str(family).capitalize()))


static func family_desc(family: Variant) -> String:
	var fam: Variant = data().get("families", {})
	if fam is Dictionary and (fam as Dictionary).get(str(family)) is Dictionary:
		return str(fam[str(family)].get("desc", ""))
	return ""


## Prix en rubis (>= 1).
static func price_of(id: Variant) -> int:
	var it := item(id)
	if it.is_empty():
		return FALLBACK_PRICE
	return maxi(int(it.get("price", FALLBACK_PRICE)), 1)


# --- Assets ------------------------------------------------------------------------------------------------------

## Tous les fichiers cités par l'article (assets aplatis : texte, liste, dictionnaire imbriqué). Conventions du catalogue :
## `dir` (dossier, terminé par « / ») n'est pas un fichier : les noms nus des listes `files` / `props` y sont résolus ;
## `map` (Veillée) est un id de carte : sa scène res://scenes/stage/maps/<id>.tscn est exigée.
static func asset_paths(it: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var a: Variant = it.get("assets", {})
	if not (a is Dictionary):
		return out
	var dir := str((a as Dictionary).get("dir", ""))
	for k in a:
		var v: Variant = a[k]
		match str(k):
			"dir":
				continue
			"map":
				if str(v) != "":
					_add(out, MAPS_DIR + str(v) + ".tscn")
			"files", "props":
				if v is Array:
					for f in v:
						var s := str(f)
						_add(out, s if s.begins_with("res://") else dir + s)
			_:
				_collect(v, out)
	return out


static func _add(out: Array[String], p: String) -> void:
	if p.begins_with("res://") and not out.has(p):
		out.append(p)


static func _collect(v: Variant, out: Array[String]) -> void:
	if v is String:
		_add(out, v)
	elif v is Array:
		for e in v:
			_collect(e, out)
	elif v is Dictionary:
		for k in v:
			_collect(v[k], out)


## L'article est-il livré ? Faux s'il est marqué `pending`, s'il ne cite aucun asset, ou si un asset manque.
static func has_assets(it: Dictionary) -> bool:
	if it.is_empty() or bool(it.get("pending", false)):
		return false
	var paths := asset_paths(it)
	if paths.is_empty():
		return false
	for p in paths:
		if not _exists(p):
			return false
	return true


static func _exists(p: String) -> bool:
	return ResourceLoader.exists(p) or FileAccess.file_exists(p)


## Chemin d'un asset nommé de l'article ("" s'il n'est pas déclaré ou pas livré).
static func asset(it: Dictionary, key: String) -> String:
	var a: Variant = it.get("assets", {})
	if not (a is Dictionary):
		return ""
	var v: Variant = (a as Dictionary).get(key, "")
	if v is String and v != "" and _exists(v):
		return v
	return ""


## Premier asset déclaré parmi `keys` qui existe.
static func asset_any(it: Dictionary, keys: Array) -> String:
	for k in keys:
		var p := asset(it, str(k))
		if p != "":
			return p
	return ""


## Aperçu de boutique : `preview` (ou assets.preview / icon / portrait) s'il existe ; "" = placeholder.
static func preview_path(it: Dictionary) -> String:
	var p := str(it.get("preview", ""))
	if p != "" and _exists(p):
		return p
	return asset_any(it, ["preview", "icon", "portrait", "thumb"])


# --- Possession et équipement ---------------------------------------------------------------------------------------

static func is_owned(profile: Object, id: Variant) -> bool:
	if profile == null:
		return false
	var owned: Variant = profile.get("owned_cosmetics") if "owned_cosmetics" in profile else null
	return owned is Array and (owned as Array).has(StringName(str(id)))


## Id équipé dans un emplacement ("" = défaut), sans vérifier les assets. Mode test : override d'abord.
static func equipped_id(slot_key: String, profile: Object = null) -> String:
	if TestMode.active and test_override.has(slot_key):
		return str(test_override[slot_key])
	var p: Object = profile if profile != null else _autoload()
	if p == null:
		return ""
	if slot_key.begins_with("panoplie:"):
		return Skins.equipped(slot_key.substr(9), p)
	if p.has_method(&"equipped_cosmetic"):
		return str(p.call(&"equipped_cosmetic", slot_key))
	return ""


## Article équipé ET livré dans un emplacement ({} = apparence par défaut). Hors mode test, il faut le posséder.
static func equipped_item(family: Variant, target: Variant = "", profile: Object = null) -> Dictionary:
	var sk := slot(family, target)
	var id := equipped_id(sk, profile)
	if id == "":
		return {}
	var it := item(id)
	if it.is_empty() or slot_of(it) != sk or not has_assets(it):
		return {}
	var forced := TestMode.active and test_override.has(sk)
	if not forced:
		var p: Object = profile if profile != null else _autoload()
		if not is_owned(p, id) and not (family_of(it) == &"panoplie" and Skins.is_unlocked(p, id)):
			return {}
	return it


## Mode test : équipe `id` ("" = défaut) dans l'emplacement de l'article, sans achat ni écriture au profil.
static func set_test_override(slot_key: String, id: String) -> void:
	test_override[slot_key] = id
	if not _test_hooked:
		_test_hooked = true
		TestMode.changed.connect(func() -> void: Cosmetics._on_test_mode_changed())


## Sortie du mode test : les cosmétiques forcés sont oubliés (rien n'a été écrit au profil).
static func _on_test_mode_changed() -> void:
	if not TestMode.active and not test_override.is_empty():
		var had_parement := test_override.has(slot(&"parement"))
		test_override = {}
		if had_parement:
			UiTheme.refresh_parement() # le thème partagé revient au Parement du profil


static func clear_test_overrides() -> void:
	test_override = {}


static func _autoload() -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Profile") if tree != null else null
