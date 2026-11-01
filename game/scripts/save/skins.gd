class_name Skins
extends RefCounted
## Skins de personnage : une LISTE par personnage (skins_of). D'abord les trophées de data/characters.json (clé `skins`),
## débloqués par une règle de VariantUnlocks (type `win_with` : gagner une run en Difficile avec le personnage) ou achetés
## (Profile.buy_skin, prix data/shop.json) ; clé « skin:<id> » (Profile.unlocked_skins). Puis les Panoplies de la boutique
## cosmétique (data/cosmetics.json, famille `panoplie`, cible = id du personnage), achetées en rubis seulement
## (Profile.buy_cosmetic, possession Profile.owned_cosmetics). Choix du joueur : Profile.selected_skin {perso: skin_id}
## (inchangé : une seule apparence par personnage, trophée ou Panoplie).
##
## Contrat d'assets (game/CONTRACTS.md « Skins de personnage ») : `<dossier du perso>/skins/<skin_id>/` contient les
## MÊMES fichiers que le dossier par défaut (mêmes noms, tailles, frames, masques _e, portrait.png) plus
## `<skin_id>.tres` (SpriteFrames, mêmes animations que `<perso>.tres`). Style cel : `skins/<skin_id>_cel/` optionnel
## (règle `_cel` de RenderStyle). Rien n'est rendu : tout repli sur le dossier par défaut, jamais d'erreur.

const VariantUnlocks := preload("res://scripts/save/variant_unlocks.gd")
const CHARACTERS_PATH := "res://data/characters.json"
const CHAR_SPRITE_DIR := "res://assets/sprites/characters/"
const SKIN_SUBDIR := "skins"

## Roster injectable (tests) ; null = data/characters.json.
static var roster_override: Variant = null


static func roster() -> Array:
	if roster_override is Array:
		return roster_override
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS_PATH))
	return parsed if parsed is Array else []


static func character(cid: Variant) -> Dictionary:
	for c in roster():
		if c is Dictionary and str(c.get("id", "")) == str(cid):
			return c
	return {}


## Le skin trophée (le premier de characters.json) d'un personnage : {} si aucun.
static func skin_of(cid: Variant) -> Dictionary:
	return skin_of_dict(character(cid))


## Tous les skins d'un personnage : trophées puis Panoplies (boutique cosmétique).
static func skins_of(cid: Variant) -> Array:
	var c := character(cid)
	if c.is_empty():
		c = {"id": str(cid)}
	return skins_of_dict(c)


## Le personnage a-t-il ce skin (trophée ou Panoplie) ?
static func has_skin(cid: Variant, skin_id: Variant) -> bool:
	if str(skin_id) == "":
		return false
	for s in skins_of(cid):
		if str(s.get("id", "")) == str(skin_id):
			return true
	return false


## Tous les skins : [{character (dict), skin (dict), id, key «skin:<id>», rule, shop (vrai = Panoplie)}].
static func all_skins(characters: Variant = null) -> Array:
	var out: Array = []
	for c in (characters if characters is Array else roster()):
		if not (c is Dictionary) or not bool(c.get("playable", true)):
			continue
		for s in skins_of_dict(c):
			var shop := is_panoplie(s)
			out.append({"character": c, "skin": s, "id": str(s.id), "key": key_of(s), "rule": {} if shop else rule_of(c, s), "shop": shop})
	return out


static func skin_of_dict(c: Dictionary) -> Dictionary:
	var arr: Variant = c.get("skins", [])
	if arr is Array:
		for s in arr:
			if s is Dictionary and str(s.get("id", "")) != "":
				return s
	return {}


## Trophées (characters.json) puis Panoplies (cosmetics.json, cible = id du personnage), sans doublon d'id.
static func skins_of_dict(c: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	var arr: Variant = c.get("skins", [])
	if arr is Array:
		for s in arr:
			if s is Dictionary and str(s.get("id", "")) != "" and not seen.has(str(s.id)):
				seen[str(s.id)] = true
				out.append(s)
	for it in Cosmetics.items_of(&"panoplie", str(c.get("id", ""))):
		var sid := str(it.get("id", ""))
		if sid == "" or seen.has(sid):
			continue
		seen[sid] = true
		out.append({"id": sid, "name": str(it.get("name", sid)), "desc": str(it.get("desc", "")), "family": "panoplie",
			"price": Cosmetics.price_of(sid), "unlock_key": "skin:" + sid})
	return out


## Vrai pour une Panoplie (achetable en boutique cosmétique seulement, jamais par condition de jeu).
static func is_panoplie(skin: Dictionary) -> bool:
	return str(skin.get("family", "")) == "panoplie"


static func key_of(skin: Dictionary) -> StringName:
	var k := str(skin.get("unlock_key", ""))
	return StringName(k if k != "" else "skin:" + str(skin.get("id", "")))


## Règle effective : `unlock_rule`, sinon victoire en Difficile avec le propriétaire.
static func rule_of(c: Dictionary, skin: Dictionary) -> Dictionary:
	var r: Variant = skin.get("unlock_rule")
	if r is Dictionary and not (r as Dictionary).is_empty():
		return r
	return {"type": "win_with", "character": str(c.get("id", "")), "mode": "difficile"}


static func quest_text(c: Dictionary, skin: Dictionary) -> String:
	if is_panoplie(skin):
		return "En boutique : %d rubis." % int(skin.get("price", Cosmetics.price_of(skin.get("id", ""))))
	var t := str(skin.get("unlock_text", ""))
	return t if t != "" else "Gagner une run en Difficile avec %s." % str(c.get("name", "ce personnage"))


## Clés « skin:<id> » dont la règle est remplie par la run `result` et pas encore possédées.
static func evaluate(profile: Object, characters: Array, result: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var owned: Array = profile.get("unlocked_skins") if profile != null and "unlocked_skins" in profile else []
	for e in all_skins(characters):
		if bool(e.shop): # Panoplie : boutique seulement
			continue
		var key: StringName = e.key
		if owned.has(StringName(String(key).substr(5))) or out.has(key):
			continue
		if VariantUnlocks.rule_met(e.rule, StringName(str(e.character.get("id", ""))), profile, result):
			out.append(key)
	return out


static func is_unlocked(profile: Object, skin_id: Variant) -> bool:
	if profile == null or str(skin_id) == "":
		return false
	if "unlock_all_variants" in profile and bool(profile.get("unlock_all_variants")):
		return true
	var owned: Variant = profile.get("unlocked_skins") if "unlocked_skins" in profile else null
	if owned is Array and (owned as Array).has(StringName(str(skin_id))):
		return true
	return Cosmetics.is_owned(profile, skin_id) # Panoplie achetée


## Skin équipé et valide pour ce personnage ("" = défaut). `profile` null = autoload Profile.
static func equipped(cid: Variant, profile: Object = null) -> String:
	if TestMode.active and TestMode.skin_override.has(str(cid)):
		return str(TestMode.skin_override[str(cid)]) # mode test : apparence forcée, sans condition de déblocage
	var p: Object = profile if profile != null else _autoload()
	if p == null or not ("selected_skin" in p):
		return ""
	var sel: Variant = p.get("selected_skin")
	var id := str((sel as Dictionary).get(str(cid), "")) if sel is Dictionary else ""
	if id == "" or not has_skin(cid, id) or not is_unlocked(p, id):
		return ""
	return id


# --- Assets ---------------------------------------------------------------------------------

## Dossier par défaut du personnage (celui du `sprite_frames` de characters.json, sinon characters/<id>/).
static func base_dir(cid: Variant) -> String:
	var sf := str(character(cid).get("sprite_frames", ""))
	if sf != "":
		return sf.get_base_dir() + "/"
	return CHAR_SPRITE_DIR + str(cid) + "/"


## Dossier des assets d'un skin : <dossier perso>/skins/<skin_id>/ (qu'il existe ou non). Une Panoplie peut déclarer
## un autre `assets.frames` dans cosmetics.json : son dossier est alors celui de ce fichier.
static func skin_dir(cid: Variant, skin_id: Variant) -> String:
	var decl := _declared_frames(skin_id)
	if decl != "":
		return decl.get_base_dir() + "/"
	return "%s%s/%s/" % [base_dir(cid), SKIN_SUBDIR, str(skin_id)]


static func skin_frames_path(cid: Variant, skin_id: Variant) -> String:
	var decl := _declared_frames(skin_id)
	return decl if decl != "" else skin_dir(cid, skin_id) + str(skin_id) + ".tres"


## `assets.frames` (ou `sprite_frames`) d'une Panoplie (texte brut, qu'il existe ou non) ; "" sinon.
static func _declared_frames(skin_id: Variant) -> String:
	var it := Cosmetics.item(skin_id)
	if it.is_empty():
		return ""
	var a: Variant = it.get("assets", {})
	if not (a is Dictionary):
		return ""
	return str((a as Dictionary).get("frames", (a as Dictionary).get("sprite_frames", "")))


## Le skin a-t-il ses SpriteFrames livrés ? (Panoplie : tous ses assets déclarés aussi, Cosmetics.has_assets.)
static func has_assets(cid: Variant, skin_id: Variant) -> bool:
	if str(skin_id) == "" or not ResourceLoader.exists(skin_frames_path(cid, skin_id)):
		return false
	var it := Cosmetics.item(skin_id)
	return it.is_empty() or Cosmetics.has_assets(it)


## UN point d'entrée pour le SpriteFrames du joueur : `default_path` (celui du kit, "" = Ardent / scène) remplacé par
## celui du skin équipé s'il est livré. Le fichier principal (`sprite_frames` de characters.json) devient `<skin_id>.tres` ;
## un autre fichier du dossier (calque de Tocsin) est pris dans le dossier du skin s'il y existe.
static func resolve_frames(cid: Variant, default_path: String, profile: Object = null) -> String:
	var sid := equipped(cid, profile)
	if sid == "" or not has_assets(cid, sid):
		return default_path
	var main := str(character(cid).get("sprite_frames", ""))
	if default_path == "" or default_path == main:
		return skin_frames_path(cid, sid)
	# Autre fichier du dossier par défaut (ex. calque de Tocsin) : le même fichier du dossier du skin s'il existe.
	if default_path.get_base_dir() + "/" == base_dir(cid):
		var alt := skin_dir(cid, sid) + default_path.get_file()
		if ResourceLoader.exists(alt):
			return alt
	return default_path


## Dossier d'assets à utiliser pour un kit qui lit plusieurs fichiers du dossier du personnage (Tocsin : calques,
## membres détachés) : celui du skin équipé s'il est livré, sinon `default_dir`. Toujours terminé par « / ».
static func asset_dir(cid: Variant, default_dir: String, profile: Object = null) -> String:
	var sid := equipped(cid, profile)
	return skin_dir(cid, sid) if sid != "" and has_assets(cid, sid) else default_dir


## Portrait d'un skin : {tex, emit, bust, exists}. `exists` faux : portrait par défaut (CharacterCard).
static func portrait_info(cid: Variant, skin_id: Variant) -> Dictionary:
	var d := skin_dir(cid, skin_id)
	var p := d + "portrait.png"
	if str(skin_id) != "" and ResourceLoader.exists(p):
		var e := d + "portrait_e.png"
		return {"tex": load(p), "emit": load(e) if ResourceLoader.exists(e) else null, "bust": true, "exists": true}
	return {"tex": null, "emit": null, "bust": false, "exists": false}


static func _autoload() -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Profile") if tree != null else null
