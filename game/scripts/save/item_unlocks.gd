class_name ItemUnlocks
extends RefCounted
## Objets débloquables. Un objet de data/items.json portant `"unlock": {"type", ..., "text"}` est verrouillé tant que
## le profil ne le possède pas (clé « item:<id> », Profile.unlocked_items). Les objets sans `unlock` sont toujours
## disponibles. Moteur de règles = VariantUnlocks (types counter / win_with / boss_kill / floor_reached) ; une règle
## sans `character` vaut « n'importe quel personnage ». Compteurs : stats du profil (kills, runs, play_time_s) et
## compteurs de run versés au profil (gold_collected, chests_opened : scripts/game/main.gd).
## Le mode test RAINFALL_UNLOCK_ALL_VARIANTS / --unlock-variants (Profile.unlock_all_variants) débloque aussi les objets.

const VariantUnlocks := preload("res://scripts/save/variant_unlocks.gd")
const COUNTER_GOLD := "gold_collected"
const COUNTER_CHESTS := "chests_opened"


## Règle d'un objet ({} = jamais verrouillé).
static func rule_of(id: Variant) -> Dictionary:
	var u: Variant = ItemDB.get_item(id).get("unlock")
	return u if u is Dictionary else {}


static func is_lockable(id: Variant) -> bool:
	return not rule_of(id).is_empty()


## Ids des objets verrouillables (ordre de items.json).
static func lockable_ids() -> Array:
	var out: Array = []
	for id in ItemDB.all_ids():
		if is_lockable(id):
			out.append(str(id))
	return out


## Disponible pour le joueur : pas de règle, mode test, ou débloqué au profil (`profile` null = autoload Profile).
static func is_unlocked(id: Variant, profile: Object = null) -> bool:
	if not is_lockable(id):
		return true
	var p: Object = profile if profile != null else _autoload()
	if p == null:
		return true
	if "unlock_all_variants" in p and bool(p.get("unlock_all_variants")):
		return true
	var owned: Variant = p.get("unlocked_items") if "unlocked_items" in p else null
	return owned is Array and (owned as Array).has(StringName(str(id)))


## Filtre un tableau d'ids : ne garde que les objets disponibles (ordre conservé).
static func filter_unlocked(ids: Array, profile: Object = null) -> Array:
	return ids.filter(func(i): return is_unlocked(i, profile))


## Clés « item:<id> » dont la règle est remplie par la run `result` (compteurs du profil déjà à jour) et pas encore possédées.
static func evaluate(profile: Object, result: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var owned: Array = profile.get("unlocked_items") if profile != null and "unlocked_items" in profile else []
	for id in lockable_ids():
		if owned.has(StringName(id)):
			continue
		var rule := rule_of(id).duplicate()
		if not rule.has("character"):
			rule["character"] = "any"
		if VariantUnlocks.rule_met(rule, &"", profile, result):
			out.append(StringName("item:" + id))
	return out


## Avancement d'une règle à compteur : {value, target} ; {} pour les autres types.
static func progress(id: Variant, profile: Object) -> Dictionary:
	var r := rule_of(id)
	if str(r.get("type", "")) != "counter":
		return {}
	var key := str(r.get("key", ""))
	var v := 0.0
	if profile != null:
		if profile.has_method(&"stat"):
			v = float(profile.call(&"stat", key))
		else:
			var st: Variant = profile.get("stats") if "stats" in profile else null
			if st is Dictionary and ((st as Dictionary).get(key) is float or (st as Dictionary).get(key) is int):
				v = float((st as Dictionary)[key])
	return {"value": minf(v, float(r.get("value", 0.0))), "target": float(r.get("value", 0.0))}


static func condition_text(id: Variant) -> String:
	return str(rule_of(id).get("text", "Déblocage à venir."))


static func _autoload() -> Object:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Profile") if tree != null else null
