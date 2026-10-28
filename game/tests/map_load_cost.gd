extends Node
## Coût de chargement et de structure des cartes (comparaison A / B, docs/Design_Variantes_B.md §8) : temps
## d'instanciation + ambiance, nombre de nœuds, rectangles de collision, occluders, bandes d'eau, lumières de carte.
## Sans rendu (headless) : mesure la structure et le CPU de construction, pas le GPU.
## godot --headless --path game res://tests/map_load_cost.tscn      (sortie « RESULT: OK »)

const PAIRS := [
	["terrasses_noyees", "terrasses_rizieres_hautes"], ["foret_brume", "foret_mangrove_lanternes"],
	["cite_rouille", "cite_fonderie_canal"], ["cryptes_noyees", "cryptes_ossuaire_pluies"],
]
## Plafonds de structure (les pires A mesurées + marge) : occluders (plafond actuel constaté 40), lumières ponctuelles.
const MAX_OCCLUDERS := 45
const MAX_MAP_LIGHTS := 40
var _fails := 0


func _ready() -> void:
	await get_tree().process_frame
	for pair in PAIRS:
		var a := await _measure(pair[0])
		var b := await _measure(pair[1])
		for m in [a, b]:
			print("  %-26s nœuds %4d  collisions %3d  occluders %3d  bandes d'eau %3d  lumières %2d  chargement %4.0f ms" % [
				m["id"], m["nodes"], m["rects"], m["occ"], m["water"], m["lights"], m["ms"]])
		for m in [a, b]:
			if m["occ"] > MAX_OCCLUDERS:
				_fails += 1
				print("FAIL: %s : %d occluders > %d" % [m["id"], m["occ"], MAX_OCCLUDERS])
			if m["lights"] > MAX_MAP_LIGHTS:
				_fails += 1
				print("FAIL: %s : %d lumières de carte > %d" % [m["id"], m["lights"], MAX_MAP_LIGHTS])
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _measure(id: String) -> Dictionary:
	var out := {"id": id}
	var n0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var t0 := Time.get_ticks_usec()
	var map := (load("res://scenes/stage/maps/%s.tscn" % id) as PackedScene).instantiate() as StageMap
	add_child(map)
	var amb: AmbianceManager = load("res://scenes/ambiance/ambiance_manager.tscn").instantiate()
	add_child(amb)
	amb.bind_map(map)
	await get_tree().process_frame
	await get_tree().process_frame
	out["ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	out["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - n0
	var all_rects := 0
	for cs in map.find_children("*", "CollisionShape2D", true, false):
		if not (cs as CollisionShape2D).disabled:
			all_rects += 1
	out["rects"] = all_rects
	out["occ"] = get_tree().get_nodes_in_group(OccluderBuilder.OCCLUDER_GROUP).size()
	out["water"] = (amb.water.shallow_rects + amb.water.deep_rects) if amb.water != null else -1
	out["lights"] = (amb.get("_map_lights") as Array).size()
	amb.queue_free()
	map.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return out
