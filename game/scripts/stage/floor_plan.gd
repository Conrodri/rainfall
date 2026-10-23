class_name FloorPlan
extends RefCounted
## Plan de run façon RoR2 (docs/Design_Etages.md §2.2, §6.2) lu dans data/floors.json (source de vérité
## du roster : étage -> biome, nom, cartes, boss d'étage, mini-boss, étage final).
##
## Le plan des étages 1..final est tiré une fois par run, à partir de `RunState.run_seed` avec un générateur
## PROPRE (jamais RunState.rng : les coffres et piliers gardent leur seed, une sauvegarde sans plan le
## recalcule à l'identique). Par étage : {floor, stage, biome, name, map_id, variant, floor_boss, minis, final}.
## - carte : 50/50 parmi les variantes dont data/maps/<id>.json existe ; sans fin : variante opposée à
##   chaque boucle (index + boucle) ;
## - boss d'étage : uniforme parmi ceux dont le sprite est livré (EnemyVisual.boss_available), sinon le
##   premier de la liste (repli propre : placeholder + IA générique ou cerveau dédié) ; MÉMOIRE DE PROFIL
##   (§2.2) : le boss vu à cet étage lors de la run précédente (Profile.last_floor_boss) pèse × Balance.BOSS_MEMORY_WEIGHT
##   (pick_floor_boss ; sans mémoire, tirage identique à l'uniforme) ;
## - mini-boss : 2 distincts parmi les livrés ; moins de 2 livrés -> [] (rotation de EnemyVisual.mini_pool).
## Sans fin : étage n -> étage ((n - 1) % floors_per_loop) + 1 (6-9 = biomes 1-4, 10 = la Source).

const PATH := "res://data/floors.json"
const MAPS_DIR := "res://data/maps"
const DEFAULT_PER_LOOP := 5

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if FileAccess.file_exists(PATH):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if d is Dictionary:
				_data = d
		if _data.is_empty():
			push_warning("FloorPlan : %s absent ou invalide" % PATH)
			_data = {"floors": []}
	return _data


static func reset_cache() -> void:
	_data = {}


static func floors() -> Array:
	return data().get("floors", [])


static func floors_per_loop() -> int:
	return maxi(int(data().get("floors_per_loop", DEFAULT_PER_LOOP)), 1)


## Étage du boss final (entrée `final`), sinon le dernier de la boucle.
static func final_floor() -> int:
	for f: Dictionary in floors():
		if bool(f.get("final", false)):
			return int(f.get("floor", floors_per_loop()))
	return floors_per_loop()


## Étage de la boucle (1..floors_per_loop) pour un étage de run (sans fin compris).
static func floor_of_stage(stage: int) -> int:
	return ((maxi(stage, 1) - 1) % floors_per_loop()) + 1


static func loop_of_stage(stage: int) -> int:
	return (maxi(stage, 1) - 1) / floors_per_loop()


## Entrée de data/floors.json pour un étage de la boucle ({} si absente).
static func floor_entry(floor_n: int) -> Dictionary:
	for f: Dictionary in floors():
		if int(f.get("floor", -1)) == floor_n:
			return f
	return {}


static func is_final_stage(stage: int) -> bool:
	return bool(floor_entry(floor_of_stage(stage)).get("final", false))


static func map_exists(map_id: String) -> bool:
	return map_id != "" and FileAccess.file_exists("%s/%s.json" % [MAPS_DIR, map_id])


## Variantes jouables (JSON présent) de l'étage, dans l'ordre de floors.json.
static func playable_maps(floor_n: int) -> Array:
	var out: Array = []
	for m in floor_entry(floor_n).get("maps", []):
		if map_exists(String(m)):
			out.append(String(m))
	return out


## Plan des étages 1..final_floor() pour une seed de run.
## `memory` : étage (texte) -> boss vu la dernière fois ; null = mémoire du profil (autoload Profile).
static func build(run_seed: int, memory: Variant = null) -> Array:
	var mem := _memory(memory)
	var out: Array = []
	for f in range(1, final_floor() + 1):
		out.append(_draw(f, f, 0, -1, run_seed, mem))
	return out


## Entrée de plan pour l'étage de run `stage` : celle du plan (boucle 1), sinon tirée à la demande (sans fin).
static func entry_for_stage(plan: Array, stage: int, run_seed: int, memory: Variant = null) -> Dictionary:
	var f := floor_of_stage(stage)
	var loop := loop_of_stage(stage)
	if loop == 0 and stage - 1 < plan.size() and plan[stage - 1] is Dictionary and not (plan[stage - 1] as Dictionary).is_empty():
		return plan[stage - 1]
	var base_idx := -1
	if f - 1 < plan.size() and plan[f - 1] is Dictionary:
		base_idx = playable_maps(f).find(String((plan[f - 1] as Dictionary).get("map_id", "")))
	return _draw(f, stage, loop, base_idx, run_seed, _memory(memory))


## Mémoire des boss : celle passée, sinon celle de l'autoload Profile (absent : aucune).
static func _memory(memory: Variant) -> Dictionary:
	if memory is Dictionary:
		return memory
	var tree := Engine.get_main_loop() as SceneTree
	var prof: Node = tree.root.get_node_or_null(^"Profile") if tree != null and tree.root != null else null
	if prof != null and prof.get(&"last_floor_boss") is Dictionary:
		return (prof.get(&"last_floor_boss") as Dictionary).duplicate()
	return {}


## Poids de tirage de chaque boss de `ids` à l'étage `floor_n` (1, ou BOSS_MEMORY_WEIGHT pour le dernier vu).
static func boss_weights(ids: Array, floor_n: int, memory: Dictionary) -> Array[float]:
	var last := String(memory.get(str(floor_n), ""))
	var w: Array[float] = []
	for id in ids:
		w.append(Balance.BOSS_MEMORY_WEIGHT if String(id) == last else 1.0)
	return w


## Tirage pondéré du boss d'étage. Sans boss mémorisé parmi `ids`, même tirage (et même suite de nombres) que
## l'uniforme d'avant la mémoire : les plans des seeds existantes ne changent pas.
static func pick_floor_boss(ids: Array, floor_n: int, rng: RandomNumberGenerator, memory: Dictionary) -> String:
	if ids.is_empty():
		return ""
	var last := String(memory.get(str(floor_n), ""))
	if ids.size() < 2 or not ids.has(last):
		return String(ids[rng.randi_range(0, ids.size() - 1)])
	var w := boss_weights(ids, floor_n, memory)
	var total := 0.0
	for x in w:
		total += x
	var roll := rng.randf() * total
	for i in ids.size():
		roll -= w[i]
		if roll < 0.0:
			return String(ids[i])
	return String(ids[ids.size() - 1])


static func _draw(floor_n: int, stage: int, loop: int, base_idx: int, run_seed: int, memory: Dictionary = {}) -> Dictionary:
	var e := floor_entry(floor_n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "floor_plan", stage])
	var maps := playable_maps(floor_n)
	var map_id := ""
	var variant := ""
	if not maps.is_empty():
		var idx := rng.randi_range(0, maps.size() - 1)
		if loop > 0 and base_idx >= 0:
			idx = (base_idx + loop) % maps.size() # sans fin : l'autre variante si elle existe
		map_id = maps[idx]
		variant = "AB"[idx] if idx < 2 and maps.size() > 1 else ""
	var bosses: Array = []
	for b in e.get("floor_bosses", []):
		if EnemyVisual.boss_available(StringName(b)):
			bosses.append(String(b))
	var floor_boss := ""
	if not bosses.is_empty():
		floor_boss = pick_floor_boss(bosses, floor_n, rng, memory)
	elif not (e.get("floor_bosses", []) as Array).is_empty():
		floor_boss = String(e["floor_bosses"][0])
	var minis_av: Array = []
	for m in e.get("minis", []):
		if EnemyVisual.boss_available(StringName(m)):
			minis_av.append(String(m))
	var minis: Array = []
	if minis_av.size() >= 2:
		for i in range(minis_av.size() - 1, 0, -1): # Fisher-Yates, puis les 2 premiers (distincts)
			var j := rng.randi_range(0, i)
			var t = minis_av[i]
			minis_av[i] = minis_av[j]
			minis_av[j] = t
		minis = [minis_av[0], minis_av[1]]
	return {
		"floor": floor_n, "stage": stage, "biome": String(e.get("biome", "")), "name": String(e.get("name", "")),
		"map_id": map_id, "variant": variant, "floor_boss": floor_boss, "minis": minis,
		"final": bool(e.get("final", false)),
	}


## Entrée relue d'une sauvegarde JSON (nombres en float) remise aux types de `build`.
static func normalize(e: Dictionary) -> Dictionary:
	var minis: Array = []
	for m in e.get("minis", []):
		minis.append(String(m))
	return {
		"floor": int(e.get("floor", 1)), "stage": int(e.get("stage", 1)), "biome": String(e.get("biome", "")),
		"name": String(e.get("name", "")), "map_id": String(e.get("map_id", "")), "variant": String(e.get("variant", "")),
		"floor_boss": String(e.get("floor_boss", "")), "minis": minis, "final": bool(e.get("final", false)),
	}


## Nom affiché d'un étage de run (« Étage 3 · Cité de rouille »).
static func display_name(stage: int) -> String:
	var n := String(floor_entry(floor_of_stage(stage)).get("name", ""))
	return "Étage %d" % stage if n == "" else "Étage %d · %s" % [stage, n]
