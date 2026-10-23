extends Node
## Charge les 3 cartes : marqueurs, obstacles, accessibilité, contraintes de tirage.
## godot --headless --path game res://tests/maps_test.tscn

const MAPS := {
	"terrasses_noyees": {"chests": 18, "pillars": 10, "small": 7, "big": 3},
	"foret_brume": {"chests": 17, "pillars": 9, "small": 6, "big": 3},
	"cite_rouille": {"chests": 17, "pillars": 11, "small": 8, "big": 3},
	"cryptes_noyees": {"chests": 20, "pillars": 9, "small": 6, "big": 3},
	"la_source": {"chests": 12, "pillars": 1, "small": 0, "big": 1, "final": true}, ## arène du boss final : paratonnerre-mère seul
}
const CELL := 32.0 ## 0,5 u
const CLEARANCE := 24.0 ## rayon joueur approx + marge
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	for id in MAPS:
		_test_map(id, MAPS[id])
	print("RESULT: ", "OK" if _fails == 0 else "FAILED (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _rects(map: Node) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for n in map.get_node("Obstacles").find_children("*", "CollisionShape2D", true, false):
		var cs := n as CollisionShape2D
		var r := cs.shape as RectangleShape2D
		out.append(Rect2(map.to_map(map.to_local(cs.global_position)) - r.size / 2.0, r.size)) # repère carte
	return out


func _blocked(rects: Array[Rect2], p: Vector2, margin: float) -> bool:
	for r in rects:
		if r.grow(margin).has_point(p):
			return true
	return false


## Méta `projection` de la scène = champ du JSON ; en iso, Obstacles et Markers portent Iso.map_xform().
func _check_projection(map: StageMap, meta: Dictionary) -> bool:
	var proj := String(meta.get("projection", "flat"))
	if String(map.get_meta(&"projection", "flat")) != proj:
		return false
	var xf := map.map_xform()
	if proj == StageMap.PROJECTION_ISO and not xf.is_equal_approx(Iso.map_xform()):
		return false
	for n in [^"Obstacles", ^"Markers", ^"Visual"]:
		if not (map.get_node(n) as Node2D).transform.is_equal_approx(xf):
			return false
	# aller-retour des repères
	var p := Vector2(123.0, -456.0)
	return map.to_map(map.from_map(p)).is_equal_approx(p)


func _test_map(id: String, exp: Dictionary) -> void:
	var f := FileAccess.open("res://data/maps/%s.json" % id, FileAccess.READ)
	_check(f != null, id + " json manquant")
	if f == null:
		return
	var meta: Dictionary = JSON.parse_string(f.get_as_text())
	var map := (load(meta["scene"]) as PackedScene).instantiate() as StageMap
	add_child(map)
	var size_u := Vector2(meta["size_u"][0], meta["size_u"][1])
	var half := size_u * 32.0
	var chests := map.get_chest_markers()
	var pillars := map.get_pillar_markers()
	_check(chests.size() == exp["chests"], "%s coffres %d != %d" % [id, chests.size(), exp["chests"]])
	_check(pillars.size() == exp["pillars"], "%s piliers %d != %d" % [id, pillars.size(), exp["pillars"]])
	var small := 0
	var big := 0
	for p in pillars:
		if p.is_in_group("pillar_small"): small += 1
		if p.is_in_group("pillar_big"): big += 1
	_check(small == exp["small"] and big == exp["big"], "%s petits/gros %d/%d" % [id, small, big])
	_check(get_tree().get_nodes_in_group("player_start").size() == 1, id + " player_start != 1")
	_check(map.get_node("Visual") != null, id + " Visual manquant")
	var rects := _rects(map)
	_check(rects.size() > 10, id + " peu d'obstacles")
	for cs in map.get_node("Obstacles").find_children("*", "StaticBody2D", true, false):
		_check((cs as StaticBody2D).collision_layer == 1, id + " couche != 1")
	# A* sur grille 0,5 u
	var cols := int(size_u.x * 2.0)
	var rows := int(size_u.y * 2.0)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, cols, rows)
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y in rows:
		for x in cols:
			var c := Vector2(x + 0.5, y + 0.5) * CELL - half
			if _blocked(rects, c, CLEARANCE):
				grid.set_point_solid(Vector2i(x, y))
	var to_cell := func(p: Vector2) -> Vector2i:
		var q: Vector2 = (p + half) / CELL
		return Vector2i(int(floor(q.x)), int(floor(q.y)))
	var start := map.to_map(map.get_player_start()) # repère carte (marqueurs sous Markers, tourné en iso)
	_check(_check_projection(map, meta), id + " projection incohérente")
	_check(not _blocked(rects, start, CLEARANCE), id + " départ dans un obstacle")
	var s_cell: Vector2i = to_cell.call(start)
	var all: Array[Marker2D] = []
	all.append_array(chests)
	all.append_array(pillars)
	all.append_array(map.find_children("*", "Marker2D", true, false).filter(func(n): return n.is_in_group("event_spawn")))
	for m in all:
		var p := m.position
		_check(absf(p.x) < half.x and absf(p.y) < half.y, "%s %s hors carte" % [id, m.name])
		_check(not _blocked(rects, p, CLEARANCE), "%s %s dans un obstacle" % [id, m.name])
		var path := grid.get_id_path(s_cell, to_cell.call(p))
		_check(not path.is_empty(), "%s %s inatteignable" % [id, m.name])
	# disque autour des piliers : >= 70 % praticable (regle de tirage : un candidat trop encombre est simplement ecarte)
	var small_ok := 0
	var big_ok := 0
	for p in pillars:
		var radius := 9.0 if p.is_in_group("pillar_big") else 7.0
		var ok := 0
		var tot := 0
		var r := radius * 64.0
		var y := -r
		while y <= r:
			var x := -r
			while x <= r:
				if x * x + y * y <= r * r:
					tot += 1
					if not _blocked(rects, p.position + Vector2(x, y), 0.0):
						ok += 1
				x += 32.0
			y += 32.0
		if float(ok) / tot >= 0.7:
			if p.is_in_group("pillar_big"): big_ok += 1
			else: small_ok += 1
		else:
			print("  info %s %s non eligible (sol %.0f %%, regle >= 70 %%)" % [id, p.name, 100.0 * ok / tot])
	var final := bool(exp.get("final", false))
	_check((final or small_ok >= 2) and big_ok >= 1, "%s candidats eligibles insuffisants (petits %d, gros %d)" % [id, small_ok, big_ok])
	if final: # 6 petits + 2 grands + 1 légendaire garanti (+ 1 marqueur libre)
		_check(chests.size() >= 10, "%s : coffres de l'arène finale %d < 10" % [id, chests.size()])
		_check(int((meta.get("draw_rules", {}) as Dictionary).get("small_pillars", -1)) == 0, id + " : draw_rules.small_pillars != 0")
	# faisabilite du tirage (distances du doc)
	var bigs := pillars.filter(func(n): return n.is_in_group("pillar_big") and n.position.distance_to(start) >= 20.0 * 64.0)
	_check(bigs.size() >= 1, id + " aucun gros pilier a >= 20 u du depart")
	var legend := chests.filter(func(n): return n.position.distance_to(start) >= 24.0 * 64.0)
	_check(legend.size() >= 1, id + " aucun coffre legendaire possible (>= 24 u)")
	var far_ok := final
	for g in bigs:
		for s in pillars:
			if s.is_in_group("pillar_small") and s.position.distance_to(g.position) >= 18.0 * 64.0:
				far_ok = true
	_check(far_ok, id + " pas de couple gros/petit pilier >= 18 u")
	print("%s: coffres %d piliers %d (%d/%d) obstacles %d, %d marqueurs atteignables" % [id, chests.size(), pillars.size(), small, big, rects.size(), all.size()])
	map.free()
