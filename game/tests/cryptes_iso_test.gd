extends Node
## Étage 4 (cryptes_noyees, biome cryptes) en iso dans une vraie run (data/floors.json + data/maps) :
## 1. trois sorties par le téléporteur -> étage 4 = cryptes_noyees iso (plan de run : variante A) ;
## 2. sol en tuiles iso, murs en sprites triés (sans prisme), fond d'abîme, falaises de bord ; tuiles du lot F4
##    (terrain/crypts/iso/) si livrées, sinon substitut teinté (ISO_FALLBACK : terrasses assombries, refroidies) ;
## 3. ambiance cryptes_noyees (appoint froid faible, cristaux crystal_vein), eau du lac sous map_xform, occluders ;
## 4. roster : biome cryptes (EnemyVisual), gros pilier = boss du plan (tiré dans data/floors.json), 2 petits piliers ;
## 5. NavField : départ, coffres, piliers, capsules atteignables ; monstres apparus hors murs ;
## 6. sauvegarde / reprise sur l'étage 4 (même carte, même plan, projection iso45).
## godot --headless --path game res://tests/cryptes_iso_test.tscn  -> RESULT: OK
## Sauvegarde de test seulement (jamais user://run_save.json).

const SAVE := "user://test_cryptes_iso.json"
const F4 := "res://assets/sprites/terrain/crypts/iso/"

var _main: Node
var _fails := 0


func _ready() -> void:
	_main = _new_main({})
	await _main.game_ready
	await _frames(5)
	var stage: StageManager = _main.get(&"stage")
	_check("plan : étage 4 = cryptes_noyees", String(stage.plan_entry(4).get("map_id", "")) == "cryptes_noyees", str(stage.plan_entry(4)))
	for want in ["foret_brume", "cite_rouille", "cryptes_noyees"]:
		stage.floor_cleared = true
		stage.teleporter.set_active(true)
		stage.teleporter.used.emit()
		await _frames(8)
		_check("étage %d = %s" % [RunState.stage, want], stage.map_id == want, stage.map_id)
	_check("étage 4", RunState.stage == 4)
	await _check_floor4(stage)

	# --- sauvegarde / reprise sur l'étage 4
	var player: Node2D = _main.get(&"player")
	player.global_position = stage.map.to_global(stage.map.get_player_start() + Vector2(64, 64))
	await _frames(2)
	var pos_before := player.global_position
	var n_chests := stage.chests.size()
	var plan_before := str(stage.floor_plan)
	_check("sauvegarde écrite", _main.autosave())
	var doc := RunSave.load(SAVE)
	_check("sauvegarde : plan de run", (doc.get("data", {}).get("stage", {}).get("floor_plan", []) as Array).size() == StageManager.FINAL_STAGE)
	_main.queue_free()
	await _frames(3)
	LightRig.clear_all()
	_main = _new_main(doc.get("data", {}))
	await _main.game_ready
	await _frames(5)
	stage = _main.get(&"stage")
	player = _main.get(&"player")
	_check("reprise : étage 4 cryptes_noyees iso", RunState.stage == 4 and stage.map_id == "cryptes_noyees" and stage.map.is_iso())
	_check("reprise : même plan", str(stage.floor_plan) == plan_before)
	_check("reprise : joueur au même endroit", player.global_position.distance_to(pos_before) < 1.0)
	_check("reprise : coffres", stage.chests.size() == n_chests, "%d / %d" % [stage.chests.size(), n_chests])
	# ancienne sauvegarde (sans floor_plan) : plan recalculé depuis la seed, identique
	var legacy: Dictionary = (doc.get("data", {}) as Dictionary).duplicate(true)
	(legacy["stage"] as Dictionary).erase("floor_plan")
	_main.queue_free()
	await _frames(3)
	LightRig.clear_all()
	_main = _new_main(legacy)
	await _main.game_ready
	await _frames(3)
	stage = _main.get(&"stage")
	_check("ancienne sauvegarde sans plan : plan recalculé", str(stage.floor_plan) == plan_before and stage.map_id == "cryptes_noyees")
	_finish()


func _new_main(resume: Dictionary) -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"save_path", SAVE)
	m.set(&"saves_in_headless", true)
	m.set(&"run_seed", 41)
	if not resume.is_empty():
		m.set(&"resume_data", resume)
	add_child(m)
	return m


func _check_floor4(stage: StageManager) -> void:
	var map := stage.map
	_check("cryptes iso", map.is_iso() and map.get_meta(&"projection", "") == "iso45")
	var ground := map.get_node(^"Visual/Ground") as TileMapLayer
	_check("sol en tuiles iso", ground.tile_set != null and ground.tile_set.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC)
	_check("fond d'abîme", map.get_node_or_null(^"Visual/Void") != null)
	_check("falaises de bord", map.get_node_or_null(^"Visual/Edges") != null)
	var blocks := map.get_node_or_null(^"Blocks")
	var sprites := 0
	var prisms := 0
	if blocks != null:
		for b in blocks.get_children():
			if b is Sprite2D:
				sprites += 1
			elif b is Polygon2D:
				prisms += 1
	_check("murs en sprites triés (sans prisme)", blocks != null and blocks.y_sort_enabled and sprites > 50 and prisms == 0, "%d sprites, %d prismes" % [sprites, prisms])
	var real := StageMap._has_textures(F4, StageMap.GROUND_VARIANTS)
	var tint: Dictionary = map.get(&"_tint")
	if real:
		_check("F4 livré : tuiles crypts/iso sans teinte", map.iso_dir_used == F4 and tint.is_empty(), map.iso_dir_used)
	else:
		_check("F4 absent : substitut teinté (ISO_FALLBACK cryptes)", not tint.is_empty() and map.iso_dir_used == String(StageMap.ISO_FALLBACK["cryptes"]["dir"]), map.iso_dir_used)
		_check("substitut : sol assombri", ground.self_modulate.v < 0.95, str(ground.self_modulate))
	# ambiance
	var amb: AmbianceManager = _main.get(&"ambiance")
	_check("ambiance cryptes_noyees", amb.profile != null and amb.profile.map_id == &"cryptes_noyees")
	if amb.profile != null:
		_check("lumière d'appoint faible, sans pluie", amb.profile.sun_energy < 0.5 and amb.profile.rain_opacity == 0.0)
	_check("cristaux (lumières de carte)", amb.map_light_count() >= 8, str(amb.map_light_count()))
	_check("lac noir iso (map_xform)", amb.water != null and amb.water.deep_rects > 0 and amb.water.deep_root.global_transform.get_rotation() != 0.0)
	var occ := amb.occluders.get_child_count() if amb.occluders != null else 0
	_check("occluders", occ > 0, str(occ))
	# roster
	_check("biome cryptes", EnemyVisual.current_biome() == &"cryptes", str(EnemyVisual.current_biome()))
	_check("3 piliers (2 petits + gros verrouillé)", stage.pillars.size() == 3 and stage.pillars[2].kind == Pillar.Kind.BIG and stage.pillars[2].state == Pillar.STATE_LOCKED)
	# boss du plan de run (FloorPlan, data/floors.json) : tiré parmi les boss d'étage 4 livrés, plus seulement recluse
	var plan_boss := StringName(stage.plan_entry(4).get("floor_boss", ""))
	var roster: Array = FloorPlan.floor_entry(4).get("floor_bosses", [])
	_check("boss d'étage du plan (%s) : roster de l'étage 4, sprite livré, sur le gros pilier" % plan_boss,
		roster.has(String(plan_boss)) and EnemyVisual.boss_available(plan_boss) and stage.floor_boss == plan_boss
		and stage.pillars[2].boss_id == plan_boss, "%s / %s / %s" % [plan_boss, stage.floor_boss, str(roster)])
	_check("Audio : carte des cryptes", Audio.current_map_id() == "cryptes_noyees", Audio.current_map_id())
	# NavField
	var director: Director = _main.get(&"director")
	var nav := director.nav
	_check("NavField lié", nav != null and nav.is_valid())
	if nav == null:
		return
	var start := map.to_global(map.get_player_start())
	nav.compute_now(start)
	var pts: Array = [["départ", start]]
	for c in stage.chests:
		pts.append(["coffre", c.global_position])
	for p in stage.pillars:
		pts.append(["pilier", p.global_position])
	for c in stage.capsules:
		pts.append(["capsule", c.global_position])
	var bad: Array = []
	for e in pts:
		var p: Vector2 = e[1]
		var c := nav.cell_of(p)
		if c < 0 or nav.is_inside_obstacle(p) or nav._dist[c] == NavField.UNREACHED:
			bad.append("%s %s" % [e[0], map.to_map(map.to_local(p))])
	_check("départ, coffres, piliers, capsules atteignables (%d)" % pts.size(), bad.is_empty(), ", ".join(bad))
	var player: Node2D = _main.get(&"player")
	player.global_position = start
	var total0 := director.spawned_total
	director.credits = 200.0
	director.wave_credits = 200.0
	director.trigger_wave()
	var inside: Array = []
	for i in 240:
		await get_tree().physics_frame
		if i % 10 != 0:
			continue
		for e: Enemy in director._active:
			if nav.is_inside_obstacle(e.global_position):
				inside.append(str(map.to_map(map.to_local(e.global_position)).snapped(Vector2.ONE)))
	var n := director.spawned_total - total0
	print("cryptes_noyees : %d monstres, %d sprites de murs, %d occluders, %d lumières" % [n, sprites, occ, amb.map_light_count()])
	_check("monstres apparus", n > 0, str(n))
	_check("monstres hors murs (échantillonné 4 s)", inside.is_empty(), ", ".join(inside.slice(0, 8)))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok  ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _finish() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
