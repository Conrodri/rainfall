class_name Forge
extends RefCounted
## Logique pure de la Forge (docs/Design_Forge.md) : recettes par tags (data/recipes.json), appariement des
## ingrédients, pré-remplissage « les moins utiles », forge (consommation + objet exclusif). Aucun nœud, aucune
## interface : l'écran est scripts/ui/forge_panel.gd. Tout est par joueur (PlayerState) : noyaux, objets, forge.
##
## Règles : 1 noyau d'orage par forge ; rang I = clé A + clé B (tags, commun ou mieux) + 1 commun ; rang II = clé A
## (peu commun ou mieux) + clé B (commun ou mieux) + 1 peu commun + 1 commun. Une qualité supérieure remplace la
## qualité demandée ; les légendaires et les objets forgés ne sont jamais consommés ; Phénix de poche : exemplaires
## non consommés seulement (StationState.spendable_stacks, règle du Fondoir). Un joueur spectateur peut forger.

const RECIPES_PATH := "res://data/recipes.json"
const QUALITY_ORDER: Array[StringName] = [&"commun", &"peu_commun", &"rare", &"legendaire"]
const MAX_QUALITY := &"rare" ## qualité la plus haute consommable

static var _path := RECIPES_PATH
static var _recipes: Array[Dictionary] = []
static var _loaded := false


static func set_source(path: String) -> void:
	_path = path
	_loaded = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_recipes = []
	if not FileAccess.file_exists(_path):
		push_warning("Forge : %s introuvable" % _path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Forge : format invalide dans %s" % _path)
		return
	for r in parsed:
		if typeof(r) != TYPE_DICTIONARY or not r.has("id") or not r.has("result"):
			continue
		var keys: Array = []
		for k in r.get("keys", []):
			var alts: Array[String] = []
			if k is Array:
				for t in k:
					alts.append(str(t))
			else:
				alts.append(str(k))
			keys.append(alts)
		_recipes.append({"id": StringName(str(r["id"])), "result": StringName(str(r["result"])), "tier": int(r.get("tier", 1)),
			"keys": keys, "hint": str(r.get("hint", ""))})


## Toutes les recettes (carnet complet : toutes visibles dans l'onglet Forge), dans l'ordre du fichier.
static func recipes() -> Array[Dictionary]:
	_ensure()
	return _recipes


static func recipe(id: StringName) -> Dictionary:
	for r in recipes():
		if r["id"] == id:
			return r
	return {}


static func quality_rank(q: Variant) -> int:
	return QUALITY_ORDER.find(StringName(str(q)))


## Rôles d'une recette : [{key: bool, tags: Array[String], min_q: StringName}] ; tags vide = ingrédient quelconque.
static func roles(r: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tier: Dictionary = Balance.CRAFT_TIERS.get(int(r.get("tier", 1)), Balance.CRAFT_TIERS[1])
	var keys: Array = r.get("keys", [])
	for i in keys.size():
		out.append({"key": true, "tags": keys[i], "min_q": tier["key_a_q"] if i == 0 else tier["key_b_q"]})
	for q in tier["fillers"]:
		out.append({"key": false, "tags": [], "min_q": q})
	return out


## Texte d'un rôle pour l'écran : « Objet [Feu] (commun ou mieux) ».
static func role_text(role: Dictionary) -> String:
	var q := StringName(str(role["min_q"]))
	var qtxt: String = {&"commun": "commun", &"peu_commun": "peu commun", &"rare": "rare"}.get(q, "commun")
	var tags: Array = role["tags"]
	var s := "Objet " + (" ou ".join(tags.map(func(t: Variant) -> String: return "[%s]" % str(t))) if not tags.is_empty() else "quelconque")
	return "%s (%s%s)" % [s, qtxt, " ou mieux" if q != MAX_QUALITY else ""]


## L'objet `id` remplit-il ce rôle (qualité et tags) ?
static func fits(id: StringName, role: Dictionary) -> bool:
	var it := ItemDB.get_item(id)
	var qr := quality_rank(it.get("quality", ""))
	if qr < 0 or qr > quality_rank(MAX_QUALITY) or qr < quality_rank(role["min_q"]):
		return false
	var tags: Array = role["tags"]
	if tags.is_empty():
		return true
	var mine: Array = it.get("tags", [])
	for t in tags:
		if mine.has(t):
			return true
	return false


## Objet consommable en principe : ni forgé, ni légendaire, ni Phénix consommé (au moins 1 exemplaire disponible).
static func spendable(id: StringName, st: PlayerState) -> int:
	if ItemDB.is_craft_only(id) or quality_rank(ItemDB.get_item(id).get("quality", "")) > quality_rank(MAX_QUALITY):
		return 0
	return StationState.spendable_stacks(id, st)


## Les ids (avec doublons : un par exemplaire) peuvent-ils remplir tous les rôles, un exemplaire par rôle ?
static func matches(r: Dictionary, ids: Array) -> bool:
	var rl := roles(r)
	if ids.size() != rl.size():
		return false
	return _assign(rl, ids, 0, [])


static func _assign(rl: Array[Dictionary], ids: Array, ri: int, used: Array) -> bool:
	if ri >= rl.size():
		return true
	for i in ids.size():
		if used.has(i) or not fits(StringName(str(ids[i])), rl[ri]):
			continue
		used.append(i)
		if _assign(rl, ids, ri + 1, used):
			used.pop_back()
			return true
		used.pop_back()
	return false


## Raison de refus d'une sélection ("" = valide) : nombre, exemplaires possédés, rôles non remplis.
static func selection_reason(r: Dictionary, ids: Array, st: PlayerState) -> String:
	var need := roles(r).size()
	if ids.size() != need:
		return "Choisissez %d objets (%d/%d)" % [need, ids.size(), need]
	var counts := {}
	for i in ids:
		var id := StringName(str(i))
		counts[id] = int(counts.get(id, 0)) + 1
		if int(counts[id]) > spendable(id, st):
			return "Pas assez d'exemplaires de %s" % str(ItemDB.get_item(id).get("name", id))
	if not matches(r, ids):
		return "Ces objets ne remplissent pas la recette"
	return ""


## Refus global d'une recette pour ce joueur ("" = on peut chercher des ingrédients) : noyau, exemplaires maximum.
static func blocked_reason(r: Dictionary, st: PlayerState) -> String:
	if r.is_empty():
		return "Recette inconnue"
	if st.stacks(r["result"]) >= Balance.CRAFT_MAX_STACKS:
		return "Déjà %d exemplaires" % Balance.CRAFT_MAX_STACKS
	if st.catalysts <= 0:
		return "Il faut un noyau d'orage"
	return ""


## Coût d'un exemplaire pour le pré-remplissage : plus il est bas, moins l'objet est utile au joueur.
static func usefulness(id: StringName, st: PlayerState) -> float:
	var q := maxi(quality_rank(ItemDB.get_item(id).get("quality", "")), 0)
	var c := float(q) * 10.0 - float(st.stacks(id) - 1) # un doublon pèse moins que l'unique exemplaire
	if StationState.is_capped(id, st):
		c -= 5.0 # déjà au plafond : n'apporte plus rien
	return c


## Meilleure sélection (ids avec doublons, dans l'ordre des rôles) : la somme d'utilité la plus basse. [] si impossible.
static func auto_fill(r: Dictionary, st: PlayerState) -> Array[StringName]:
	var cands: Array[StringName] = []
	for id in st.items:
		if spendable(StringName(id), st) > 0:
			cands.append(StringName(id))
	var state := {"best": [], "cost": INF, "picks": [], "used": {}}
	_search(roles(r), cands, st, 0, 0.0, state)
	var out: Array[StringName] = []
	for id in state["best"]:
		out.append(StringName(str(id)))
	return out


static func _search(rl: Array[Dictionary], cands: Array[StringName], st: PlayerState, ri: int, cost: float, state: Dictionary) -> void:
	if cost >= float(state["cost"]):
		return
	if ri >= rl.size():
		state["cost"] = cost
		state["best"] = (state["picks"] as Array).duplicate()
		return
	var used: Dictionary = state["used"]
	var picks: Array = state["picks"]
	for id in cands:
		if int(used.get(id, 0)) >= spendable(id, st) or not fits(id, rl[ri]):
			continue
		used[id] = int(used.get(id, 0)) + 1
		picks.append(id)
		_search(rl, cands, st, ri + 1, cost + usefulness(id, st), state)
		picks.pop_back()
		used[id] = int(used[id]) - 1



## Recette réalisable maintenant : pas bloquée, et des ingrédients existent.
static func can_craft(r: Dictionary, st: PlayerState) -> bool:
	return blocked_reason(r, st) == "" and not auto_fill(r, st).is_empty()


## Au moins une recette réalisable avec un noyau en poche : pastille « Forge possible ».
static func forge_ready(st: PlayerState) -> bool:
	if st == null or st.catalysts <= 0:
		return false
	for r in recipes():
		if can_craft(r, st):
			return true
	return false


## Forge : consomme les ingrédients et un noyau, donne l'objet. {ok, reason, item}. `tree` : recalcul des stats du joueur.
static func craft(tree: SceneTree, recipe_id: StringName, ids: Array, st: PlayerState) -> Dictionary:
	var r := recipe(recipe_id)
	var why := blocked_reason(r, st)
	if why == "":
		why = selection_reason(r, ids, st)
	if why != "":
		return {"ok": false, "reason": why, "item": &""}
	var lost: Array[StringName] = []
	for i in ids:
		lost.append(StringName(str(i)))
	st.spend_catalyst(1)
	for id in lost:
		st.remove_item(id)
	st.add_item(r["result"])
	StationState.apply_items(tree, st)
	Events.item_crafted.emit(st.slot, r["result"], lost, RunState.stage)
	return {"ok": true, "reason": "", "item": r["result"]}
