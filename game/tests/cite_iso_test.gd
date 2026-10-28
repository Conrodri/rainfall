extends Node
## Étage 3 (cite_rouille) en iso (lot F3, 22/10/2026), dans une vraie run (catalogue data/maps) :
## 1. étages 1 et 2 (terrasses_noyees, foret_brume) iso ; deux sorties par le téléporteur -> étage 3 ;
## 2. étage 3 = cite_rouille iso : sol en tuiles iso, murs en sprites triés (pas de prisme), fond d'abîme,
##    ambiance de la cité, eau du canal sous map_xform, occluders, lampes à vapeur du canal ;
## 3. NavField : départ, coffres, piliers et capsules atteignables, hors murs ; monstres apparus hors murs ;
## 4. sauvegarde/reprise sur l'étage 3 (projection iso45) + reprise d'une sauvegarde de l'ancienne cité plate ;
## 5. vraies tuiles du lot F3 (terrain/rust_city/iso/) : sol, eau, murs, bords, abîme ; accent émissif ;
##    sol en tuiles chevauchantes (pas de jointure) ; eau du canal sombre (profil : reflets bas) ;
## 6. sortie de l'étage 3 : pas de choix (étage final = 5), étage 4 = cryptes_noyees.
## godot --headless --path game res://tests/cite_iso_test.tscn  -> RESULT: OK
## Sauvegarde de test seulement (jamais user://run_save.json).

const SAVE := "user://test_cite_iso.json"

var _main: Node
var _fails := 0


func _ready() -> void:
	FloorPlan.force_variant = "A" # ce test vise les cartes A (les variantes B ont leurs propres tests)
	_main = _new_main({})
	await _main.game_ready
	await _frames(5)
	var stage: StageManager = _main.get(&"stage")
	_check("étage 1 = terrasses_noyees", RunState.stage == 1 and stage.map_id == "terrasses_noyees", stage.map_id)
	_check("étage 1 iso", stage.map.is_iso())
	# fin d'étage 1 : gros pilier terminé (sortie ouverte), puis interaction avec le téléporteur
	stage.floor_cleared = true
	stage.teleporter.set_active(true)
	stage.teleporter.used.emit()
	await _frames(10)
	_check("étage 2 = foret_brume iso", RunState.stage == 2 and stage.map_id == "foret_brume" and stage.map.is_iso(), "%d %s" % [RunState.stage, stage.map_id])
	stage.floor_cleared = true
	stage.teleporter.set_active(true)
	stage.teleporter.used.emit()
	await _frames(10)
	_check("étage 3 = cite_rouille", RunState.stage == 3 and stage.map_id == "cite_rouille", "%d %s" % [RunState.stage, stage.map_id])
	await _check_floor3(stage)

	# --- sauvegarde / reprise sur l'étage 3
	var player: Node2D = _main.get(&"player")
	player.global_position = stage.map.to_global(stage.map.get_player_start() + Vector2(96, 32))
	await _frames(2)
	var pos_before := player.global_position
	var n_chests := stage.chests.size()
	var n_caps := stage.capsules.size()
	var caps_before: Array = []
	for c in stage.capsules:
		caps_before.append(c.position)
	_check("sauvegarde écrite", _main.autosave())
	var doc := RunSave.load(SAVE)
	_check("sauvegarde relue", not doc.is_empty() and doc.has("data"))
	_check("sauvegarde : projection iso", doc.get("data", {}).get("stage", {}).get("projection", "") == "iso45")
	# même sauvegarde « d'avant la conversion » (cite_rouille plate) : sans `projection`, positions en repère carte
	var legacy: Dictionary = (doc.get("data", {}) as Dictionary).duplicate(true)
	if legacy.has("stage"):
		var ls: Dictionary = legacy["stage"]
		ls.erase("projection")
		var lc: Array = []
		for xy in ls.get("capsules", []):
			var q := stage.map.to_map(Vector2(float(xy[0]), float(xy[1])))
			lc.append([q.x, q.y])
		ls["capsules"] = lc
		var lp := stage.map.to_global(stage.map.to_map(stage.map.to_local(pos_before)))
		legacy["player"]["pos"] = [lp.x, lp.y]
	_main.queue_free()
	await _frames(3)
	LightRig.clear_all()
	_main = _new_main(doc.get("data", {}))
	await _main.game_ready
	await _frames(5)
	stage = _main.get(&"stage")
	player = _main.get(&"player")
	_check("reprise : étage 3 cite_rouille", RunState.stage == 3 and stage.map_id == "cite_rouille" and stage.map.is_iso())
	_check("reprise : joueur au même endroit", player.global_position.distance_to(pos_before) < 1.0, str(player.global_position - pos_before))
	_check("reprise : coffres", stage.chests.size() == n_chests, "%d / %d" % [stage.chests.size(), n_chests])
	var same_caps := stage.capsules.size() == n_caps
	for i in mini(stage.capsules.size(), caps_before.size()):
		same_caps = same_caps and (stage.capsules[i].position as Vector2).distance_to(caps_before[i]) < 1.0
	_check("reprise : capsules identiques", same_caps)
	await _check_floor3(stage)

	# --- reprise d'une sauvegarde faite sur l'ancienne cite_rouille plate
	_main.queue_free()
	await _frames(3)
	LightRig.clear_all()
	_main = _new_main(legacy)
	await _main.game_ready
	await _frames(3)
	stage = _main.get(&"stage")
	player = _main.get(&"player")
	_check("ancienne sauvegarde : joueur reconverti", player.global_position.distance_to(pos_before) < 1.0, str(player.global_position - pos_before))
	var legacy_caps := stage.capsules.size() == caps_before.size()
	for i in mini(stage.capsules.size(), caps_before.size()):
		legacy_caps = legacy_caps and (stage.capsules[i].position as Vector2).distance_to(caps_before[i]) < 1.0
	_check("ancienne sauvegarde : capsules reconverties", legacy_caps)

	# --- fin de l'étage 3 : plus d'étage final ici (5 étages, data/floors.json) -> étage 4 = Cryptes noyées
	var asked := [0]
	stage.victory_choice_requested.connect(func(_s: int) -> void: asked[0] += 1)
	stage.floor_cleared = true
	stage.request_exit()
	await _frames(10)
	_check("sortie de la cité : pas de choix de victoire", asked[0] == 0, str(asked[0]))
	_check("étage 4 = cryptes_noyees chargé après la cité", RunState.stage == 4 and stage.map != null and stage.map_id == "cryptes_noyees", "%d %s" % [RunState.stage, stage.map_id])
	_finish()


func _new_main(resume: Dictionary) -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"save_path", SAVE)
	m.set(&"saves_in_headless", true)
	m.set(&"run_seed", 23)
	if not resume.is_empty():
		m.set(&"resume_data", resume)
	add_child(m)
	return m


func _check_floor3(stage: StageManager) -> void:
	var map := stage.map
	_check("cite iso", map.is_iso() and map.get_meta(&"projection", "") == "iso45")
	var ground := map.get_node(^"Visual/Ground") as TileMapLayer
	_check("sol en tuiles iso", ground.tile_set != null and ground.tile_set.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC)
	_check("fond d'abîme", map.get_node_or_null(^"Visual/Void") != null)
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
	_check("falaises de bord", map.get_node_or_null(^"Visual/Edges") != null)
	_check_real_tiles(map, ground)
	var amb: AmbianceManager = _main.get(&"ambiance")
	_check("ambiance cite_rouille", amb.profile != null and amb.profile.map_id == &"cite_rouille")
	_check("eau du canal iso (map_xform)", amb.water != null and amb.water.deep_rects > 0 and amb.water.deep_root.global_transform.get_rotation() != 0.0)
	_check("eau du canal sombre (reflets bas)", amb.profile.water_reflect <= 0.5 and amb.profile.sky_reflect <= 0.15, "%.2f %.2f" % [amb.profile.water_reflect, amb.profile.sky_reflect])
	_check("lampes à vapeur du canal", amb.map_light_count() >= 8, str(amb.map_light_count()))
	var occ := 0
	if amb.occluders != null:
		occ = amb.occluders.get_child_count()
	_check("occluders", occ > 0, str(occ))
	# NavField : tout ce qui compte est atteignable depuis le départ, hors murs
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
	# monstres du Director : laisser tourner, aucun dans un mur
	var player: Node2D = _main.get(&"player")
	player.global_position = start
	var total0 := director.spawned_total
	director.credits = 200.0 # début d'étage : banques vides, on force flux et vague
	director.wave_credits = 200.0
	director.trigger_wave()
	var inside: Array = []
	for i in 300:
		await get_tree().physics_frame
		if i % 10 != 0:
			continue
		for e: Enemy in director._active:
			if nav.is_inside_obstacle(e.global_position):
				inside.append(str(map.to_map(map.to_local(e.global_position)).snapped(Vector2.ONE)))
	var n := director.spawned_total - total0
	print("cite_rouille : %d monstres apparus, %d sprites de murs, %d occluders" % [n, sprites, occ])
	_check("monstres apparus", n > 0, str(n))
	_check("monstres hors murs (échantillonné 5 s)", inside.is_empty(), ", ".join(inside.slice(0, 8)))


## Lot F3 : toutes les textures du sol, de l'eau, des murs, des bords et de l'abîme viennent de rust_city/iso/.
func _check_real_tiles(map: StageMap, ground: TileMapLayer) -> void:
	const F3 := "res://assets/sprites/terrain/rust_city/iso/"
	_check("F3 : pas de substitut teinté (ISO_FALLBACK)", (map.get(&"_tint") as Dictionary).is_empty() and not StageMap.ISO_FALLBACK.has("cite"))
	_check("F3 : dossier de tuiles = rust_city/iso", map.iso_dir_used == F3, map.iso_dir_used)
	var bad: Array = []
	var ts := ground.tile_set
	for i in ts.get_source_count():
		var src := ts.get_source(ts.get_source_id(i)) as TileSetAtlasSource
		var path := _tex_path(src.texture if src != null else null)
		if not path.begins_with(F3 + "ground_"):
			bad.append(path)
	_check("F3 : sol ground_a..d du lot cité", ts.get_source_count() == 4 and bad.is_empty(), str(bad))
	_check("F3 : tuiles de sol chevauchantes (504 × 252 pour 512 × 256)", ts.tile_size == Vector2i(504, 252), str(ts.tile_size))
	var decor := map.get_node(^"Visual/Decor") as TileMapLayer
	if decor.tile_set != null:
		bad.clear()
		for i in decor.tile_set.get_source_count():
			var src := decor.tile_set.get_source(decor.tile_set.get_source_id(i)) as TileSetAtlasSource
			var path := _tex_path(src.texture if src != null else null)
			if not path.begins_with(F3 + "water_"):
				bad.append(path)
		_check("F3 : eau du lot cité", bad.is_empty(), str(bad))
	var void_spr := map.get_node(^"Visual/Void") as Sprite2D
	_check("F3 : abîme void_1024 du lot cité", _tex_path(void_spr.texture) == F3 + "void_1024.png", _tex_path(void_spr.texture))
	_check("F3 : abîme assombri (VOID_TINT_BIOME)", void_spr.self_modulate.v < StageMap.VOID_TINT.v - 0.05, str(void_spr.self_modulate))
	bad.clear()
	var names := {}
	var lit := 0
	var walls: Array = map.get_node(^"Blocks").get_children()
	walls.append_array(map.get_node(^"Visual/Edges").get_children())
	for b in walls:
		if not b is Sprite2D or b.has_meta(&"prop"):
			continue
		var path := _tex_path((b as Sprite2D).texture)
		if not path.begins_with(F3):
			bad.append(path)
		names[path.get_file().get_basename()] = true
		if path.ends_with("block_b.png") or path.ends_with("rampart_corner_n.png"):
			for ch in b.get_children():
				if ch is CanvasItem and (ch as CanvasItem).visible:
					lit += 1
					break
		if (b as CanvasItem).self_modulate != Color.WHITE:
			bad.append("teinte " + path)
	_check("F3 : murs, remparts et falaises du lot cité (sans teinte)", bad.is_empty(), str(bad.slice(0, 6)))
	var want := ["block_a", "block_b", "block_c", "rampart_ne", "rampart_nw", "rampart_corner_n", "cliff_sw", "cliff_se"]
	var missing: Array = []
	for w in want:
		if not names.has(w):
			missing.append(w)
	_check("F3 : variantes de murs et de bords posées", missing.is_empty(), str(missing))
	_check("F3 : accent émissif ambre (block_b / rampart_corner_n)", lit > 0, str(lit))


static func _tex_path(t: Texture2D) -> String:
	if t is CanvasTexture:
		t = (t as CanvasTexture).diffuse_texture
	return t.resource_path if t != null else ""


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
