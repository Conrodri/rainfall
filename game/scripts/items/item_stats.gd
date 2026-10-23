class_name ItemStats
extends RefCounted
## Agrège les items possédés en bonus de stats pour Player.apply_stats (game/CONTRACTS.md).
## Stacking aligné sur Risk of Rain 2 (docs/Maths_Scaling.md §14), n = exemplaires, a = valeur du JSON :
##  - L linéaire a·n ; H hyperbolique 1 - 1/(1 + a·n) (a = coefficient RoR2, ex. Tougher Times 0,15 -> 13 % à 1) ;
##  - E exponentiel (1 + a)ⁿ - 1 (a < 0 pour la recharge : ×0,75ⁿ) ; F fixe (a, quel que soit n).
##  - Une stat donnée en tableau [premier, suivants] vaut premier + suivants × (n - 1).
##  - `stat_stack` {clé: type} remplace le type de l'item pour une stat (ex. Armure du colosse).
## Entre items différents : somme, sauf
##  - `damage_mult`, `cooldown_mult` : produit des (1 + v) (1 = neutre ; présentes seulement si un item y contribue),
##  - `damage_taken_reduction`, `dot_taken_reduction`, `dodge` : 1 - produit(1 - v) (combinaison hyperbolique).
## Procs : un proc par item (pas de fusion entre items aux données identiques). Chance selon le `stack` du proc
## (défaut : celui de l'item ; L : min(1, c·n), H : 1 - 1/(1 + c·n), F : c) ; le lanceur la multiplie par le
## proc coefficient du coup. Les clés `<x>_stack` de `data` ajoutent (n - 1) × valeur à `<x>`
## (ex. Givre : durée 2 s + 2 s par exemplaire).
## Plafonds : Balance.*_BONUS_CAP (déplacement, vitesse d'attaque, projectile, zone, XP, portée, ramassage) et PIERCE_CAP.

const MULT_KEYS := ["damage_mult", "cooldown_mult"]
const COMBINED_KEYS := ["damage_taken_reduction", "dot_taken_reduction", "dodge"]
const STACK_SUFFIX := "_stack"


static func stack_value(stack_type: String, a: float, n: int) -> float:
	if n <= 0:
		return 0.0
	match stack_type:
		"H":
			return Balance.stack_hyperbolic(a, n)
		"E":
			return Balance.stack_exponential(a, n)
		"F":
			return a
		_:
			return Balance.stack_linear(a, n)


## Valeur d'une stat : nombre (stacking `st`) ou [premier, suivants] (linéaire décalé).
static func stat_value(st: String, raw: Variant, n: int) -> float:
	if typeof(raw) == TYPE_ARRAY:
		var arr: Array = raw
		if n <= 0 or arr.is_empty():
			return 0.0
		return float(arr[0]) + float(arr[mini(1, arr.size() - 1)]) * (n - 1)
	return stack_value(st, float(raw), n)


## Chance d'un proc pour n exemplaires (avant proc coefficient).
static func proc_chance(stack_type: String, c: float, n: int) -> float:
	if n <= 0:
		return 0.0
	match stack_type:
		"H":
			return Balance.stack_hyperbolic(c, n)
		"F", "E":
			return clampf(c, 0.0, 1.0)
		_:
			return minf(c * n, 1.0)


## items : {id: nombre d'exemplaires}. Retourne le Dictionary de stats (clés absentes = 0).
static func compute(items: Dictionary) -> Dictionary:
	var out := {}
	var specials := {}
	var procs: Array = []
	for raw_id in items:
		var n: int = int(items[raw_id])
		if n <= 0:
			continue
		var it := ItemDB.get_item(raw_id)
		if it.is_empty():
			continue
		var st := str(it.get("stack", "L"))
		var overrides: Dictionary = it.get("stat_stack", {})
		var stats: Dictionary = it.get("stats", {})
		for key in stats:
			var v := stat_value(str(overrides.get(key, st)), stats[key], n)
			if key in MULT_KEYS:
				out[key] = float(out.get(key, 1.0)) * (1.0 + v)
			elif key in COMBINED_KEYS:
				out[key] = 1.0 - (1.0 - float(out.get(key, 0.0))) * (1.0 - clampf(v, 0.0, 0.95))
			else:
				out[key] = float(out.get(key, 0.0)) + v
		for p in it.get("procs", []):
			if typeof(p) != TYPE_DICTIONARY:
				continue
			var chance := proc_chance(str(p.get("stack", st)), float(p.get("chance", 0.0)), n)
			procs.append({"status": StringName(str(p.get("status", ""))), "chance": chance,
				"data": _scaled_data(p.get("data", {}), n)})
		var sp: Variant = it.get("special", null)
		if sp != null and str(sp) != "" and str(sp) != "null":
			specials[StringName(str(sp))] = int(specials.get(StringName(str(sp)), 0)) + n
	for key in Balance.ITEM_BONUS_CAPS:
		if out.has(key):
			out[key] = minf(out[key], Balance.ITEM_BONUS_CAPS[key])
	out["procs"] = procs
	out["specials"] = specials
	return out


## Données d'un proc pour n exemplaires : `<x>_stack` ajoute (n - 1) × valeur à `<x>`, puis disparaît.
static func _scaled_data(data: Dictionary, n: int) -> Dictionary:
	var d := data.duplicate(true)
	for key in data:
		var k := str(key)
		if k.ends_with(STACK_SUFFIX):
			var base := k.trim_suffix(STACK_SUFFIX)
			d[base] = float(d.get(base, 0.0)) + float(data[key]) * (n - 1)
			d.erase(key)
	return d
