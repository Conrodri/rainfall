class_name LootRoller
extends RefCounted
## Tirages de coffre (docs/Maths_Scaling.md §8). Fonctions pures : le RNG est passé en argument
## (production : RunState.rng, déterministe).

const ORDER: Array[StringName] = [&"commun", &"peu_commun", &"rare", &"legendaire"]
const OWNED_WEIGHT := 0.6
const BUILD_TAG_WEIGHT := 1.3


static func quality_rank(q: StringName) -> int:
	return ORDER.find(q)


## Plage [lo, hi] du d100 pour une qualité dans la table d'un type de coffre ((0,0) si absente).
static func die_range(kind: StringName, quality: StringName) -> Vector2i:
	var table: Dictionary = Balance.CHEST_QUALITY_TABLE[kind]
	var acc := 0
	for q in ORDER:
		if not table.has(q):
			continue
		var w: int = table[q]
		if q == quality:
			return Vector2i(acc + 1, acc + w)
		acc += w
	return Vector2i(0, 0)


static func quality_from_die(kind: StringName, die: int) -> StringName:
	var table: Dictionary = Balance.CHEST_QUALITY_TABLE[kind]
	var acc := 0
	var last: StringName = &"commun"
	for q in ORDER:
		if not table.has(q):
			continue
		acc += int(table[q])
		last = q
		if die <= acc:
			return q
	return last


## d100 de qualité. luck = relances (on garde le meilleur). Retourne {quality, die}.
static func roll_quality(kind: StringName, rng: RandomNumberGenerator, luck: int = 0) -> Dictionary:
	var best := 0
	for i in range(maxi(luck, 0) + 1):
		best = maxi(best, rng.randi_range(1, 100))
	return {"quality": quality_from_die(kind, best), "die": best}


static func build_tags(owned: Dictionary) -> Dictionary:
	var tags := {}
	for id in owned:
		if int(owned[id]) <= 0:
			continue
		for t in ItemDB.get_item(id).get("tags", []):
			tags[str(t)] = true
	return tags


static func item_weight(id: String, owned: Dictionary, tags: Dictionary) -> float:
	var w := 1.0
	if int(owned.get(id, owned.get(StringName(id), 0))) > 0:
		w *= OWNED_WEIGHT
	for t in ItemDB.get_item(id).get("tags", []):
		if tags.has(str(t)):
			w *= BUILD_TAG_WEIGHT
			break
	return w


static func _weighted_pick(pool: Array, owned: Dictionary, tags: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	var ws: Array[float] = []
	for id in pool:
		var w := item_weight(id, owned, tags)
		ws.append(w)
		total += w
	var r := rng.randf() * total
	for i in pool.size():
		r -= ws[i]
		if r < 0.0:
			return pool[i]
	return pool[pool.size() - 1]


## 2 items de la qualité. `exclude` = ids déjà montrés pour ce coffre. Distincts si possible ;
## si la table privée de `exclude` a moins de 2 items, on complète avec les exclus, puis doublons si table < 2.
static func pick_pair(quality: StringName, owned: Dictionary, exclude: Array, rng: RandomNumberGenerator) -> Array:
	var table: Array = ItemDB.ids_of_quality(quality)
	if table.is_empty():
		return []
	var tags := build_tags(owned)
	var pool: Array = table.filter(func(i): return not (i in exclude))
	var out: Array = []
	for slot in 2:
		if pool.is_empty():
			pool = table.filter(func(i): return not (i in out))
			if pool.is_empty():
				pool = table.duplicate()
		var pick := _weighted_pick(pool, owned, tags, rng)
		out.append(pick)
		pool.erase(pick)
	return out
