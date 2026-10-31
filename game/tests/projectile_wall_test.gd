extends Node
## Les murs pleins (« # ») arrêtent les projectiles du joueur et écartent les cibles cachées du ciblage auto ;
## le sol et l'eau ne bloquent pas.
## godot --headless --path game res://tests/projectile_wall_test.tscn  -> RESULT: OK

class FakeEnemy extends Node2D:
	var hits := 0
	func take_damage(_a: float, _c: bool = false, _e: StringName = &"", _h: Dictionary = {}) -> void:
		hits += 1

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _run() -> void:
	var map := (load("res://scenes/stage/maps/foret_brume.tscn") as PackedScene).instantiate() as StageMap
	add_child(map)
	await get_tree().physics_frame
	var grid: Array = map._vis_grid
	_check("grille visuelle chargée", not grid.is_empty())
	var size_px: Vector2 = map.get_meta(&"size_u") * StageMap.UNIT_PX
	var cell := StageMap.OUTLINE_CELL_PX
	# 3 cases ouvertes (« . ») suivies d'un « # » vers l'est
	var found := Vector2i(-1, -1)
	for y in grid.size():
		var row: String = grid[y]
		for x in range(1, row.length() - 4):
			if row.substr(x, 3) == "..." and row[x + 3] == "#":
				found = Vector2i(x, y)
				break
		if found.x >= 0:
			break
	_check("cellule test trouvée", found.x >= 0)
	var to_g := func(cx: float, cy: float) -> Vector2:
		return map.to_global(map.from_map(-size_px * 0.5 + Vector2(cx, cy) * cell))
	var start: Vector2 = to_g.call(found.x + 0.5, found.y + 0.5)
	var wall_c: Vector2 = to_g.call(found.x + 3.5, found.y + 0.5)
	var dir := (wall_c - start).normalized()
	_check("sol libre", not map.is_projectile_wall_at(start))
	_check("mur plein détecté", map.is_projectile_wall_at(wall_c))
	_check("segment vers le mur bloqué", map.is_projectile_blocked(start, wall_c))
	_check("segment dégagé", not map.is_projectile_blocked(start, to_g.call(found.x + 2.5, found.y + 0.5)))

	# projectile du joueur
	var p := (load("res://scenes/spells/projectile.tscn") as PackedScene).instantiate()
	add_child(p)
	p.launch(start, dir, null, null, 900.0, 2000.0, 1)
	var wall_dist := start.distance_to(wall_c)
	var crossed := false
	for i in 120:
		p._physics_process(1.0 / 60.0)
		if not p.active:
			break
		if map.is_projectile_wall_at(p.global_position):
			crossed = true
	_check("projectile détruit avant le mur", not p.active and not crossed, "dist=%s" % [p.global_position.distance_to(start)])
	_check("arrêt avant le centre du mur", p.global_position.distance_to(start) < wall_dist)

	# ciblage auto : cible cachée ignorée si une cible visible existe
	RunState.character = &"ardent"
	RunState.loadout = {}
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	await get_tree().physics_frame
	var pstart: Vector2 = to_g.call(found.x + 2.5, found.y + 0.5)
	player.global_position = pstart
	var hidden := FakeEnemy.new()
	var seen := FakeEnemy.new()
	for e in [hidden, seen]:
		e.add_to_group("enemies")
		add_child(e)
	hidden.global_position = to_g.call(found.x + 3.4, found.y + 0.5) # derrière le mur, à moins d'une case
	seen.global_position = to_g.call(found.x + 0.5, found.y + 0.5) # visible, 2 cases
	var sp: SpellCaster = player.spells
	_check("caché plus proche que visible", hidden.global_position.distance_to(pstart) < seen.global_position.distance_to(pstart))
	var pick := sp.nearest_enemy(1500.0)
	_check("ciblage auto : cible visible choisie", pick == seen, str(pick))
	seen.remove_from_group("enemies")
	_check("seule cible cachée : aucune", sp.nearest_enemy(1500.0) == null)

	# mêlée / zone : le monstre derrière le mur n'est pas touché, le monstre visible l'est
	seen.add_to_group("enemies")
	var spell := SpellData.new()
	spell.id = &"wall_test_nova"
	spell.behavior = SpellData.Behavior.NOVA
	spell.radius_u = 6.0
	var zone_pos: Vector2 = pstart
	var z := sp.spawn_zone(spell, zone_pos)
	_check("zone : monstre visible dans le rayon", seen.global_position.distance_to(zone_pos) <= z.radius)
	_check("zone : monstre caché dans le rayon", hidden.global_position.distance_to(zone_pos) <= z.radius)
	_check("zone : le visible est touché", seen.hits > 0, str(seen.hits))
	_check("zone : le caché derrière le mur n'est pas touché", hidden.hits == 0, str(hidden.hits))
	_check("ligne de vue : caché bloqué", not StageMap.los(get_tree(), zone_pos, hidden.global_position))
	_check("ligne de vue : visible dégagé", StageMap.los(get_tree(), zone_pos, seen.global_position))
	var orig_hits := sp.nearest_enemies(zone_pos, 1500.0, 5)
	_check("nearest_enemies ignore le caché", seen in orig_hits and not (hidden in orig_hits), str(orig_hits))
	var dense = sp.densest_point(1500.0)
	_check("densest_point ignore le caché", dense != null and (dense as Vector2).distance_to(hidden.global_position) > 1.0)
	var chain := sp.chain_targets(seen, 3, 2000.0)
	_check("chaîne : pas de rebond à travers le mur", not (hidden in chain), str(chain))
	_check("chaîne : atteint le visible", seen != null and sp.chain_targets(player, 3, 2000.0).has(seen))
	_check("sans arbre ni carte : tout est visible", StageMap.los(null, Vector2.ZERO, Vector2.ONE))

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
