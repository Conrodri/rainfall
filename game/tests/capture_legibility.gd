extends Node
## Capture (SANS --headless) de la lisibilité des attaques de base : armement et impact, avant (teinte et pose
## d'origine, sans écrasement) / après (set_charge réel), face (s) et profil (e), télégraphe de la brute, puis
## cadavres au sol après un massacre.
## godot --path game res://tests/capture_legibility.tscn -- --out=<dossier>

var _out := ""
const OLD_ARM := Color(1.2, 1.08, 0.9, 1.3)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	Platform.set_input_mode(Platform.InputMode.KBM)
	_run.call_deferred()


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	TestMode.begin()
	EnemyVisual.biome_override = &"terrasses"
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"run_seed", 5)
	add_child(m)
	await m.game_ready
	await _f(30)
	var player := m.get(&"player") as Node2D
	var d: Director = get_tree().get_first_node_in_group(&"director") as Director
	var base := player.global_position
	var spots := [Vector2(-3.0, 2.0), Vector2(-1.8, 2.0), Vector2(1.0, 2.0), Vector2(2.6, 2.0)]
	var list: Array[Enemy] = []
	var defs := [[1, 0], [2, 0], [2, 1], [3, 0]]
	for i in 4:
		list.append(d.spawn_enemy(defs[i][0], base + spots[i] * 64.0, false, [] as Array[StringName], defs[i][1]))
	for e in list:
		e.visual.process_mode = Node.PROCESS_MODE_ALWAYS # le Director est figé pendant la prise de vue, pas les effets de rendu
	d.process_mode = Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_DISABLED
	for n in get_tree().get_nodes_in_group(&"player_projectiles"):
		n.queue_free()
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam.global_position = base + Vector2(-0.5, 1.8) * 64.0
	await _f(8)
	for dn in [["s", PI / 2.0], ["e", 0.0]]:
		for e in list:
			e.visual.clear_charge()
			e.visual.set_facing(dn[1])
			e.visual.set_action(&"idle")
		await _f(6)
		await _shot("%s_0_idle" % dn[0])
		# AVANT : teinte d'origine, pose d'armement (anim attack frame 1), aucun écrasement
		for e in list:
			e.visual.set_action_timed(&"attack" if e.tier != 3 else &"attack", 0.6)
			e.visual._sprite.modulate = OLD_ARM
		await get_tree().create_timer(0.15).timeout
		for e in list:
			e.visual._sprite.modulate = OLD_ARM
		await _shot("%s_1_arm_before" % dn[0])
		await get_tree().create_timer(0.45).timeout
		for e in list:
			e.visual._sprite.modulate = Color.WHITE
		await _shot("%s_3_impact_before" % dn[0])
		# APRÈS : set_charge réel
		for e in list:
			e.visual.set_action_timed(&"attack", 0.6)
			e.visual.set_charge(1, e.tier != 1)
		await get_tree().create_timer(0.20).timeout
		await _shot("%s_2_arm_after" % dn[0])
		await get_tree().create_timer(0.35).timeout
		for e in list:
			e.visual.set_charge(0)
		await _shot("%s_4_impact_after" % dn[0])
		await get_tree().create_timer(0.3).timeout
		for e in list:
			e.visual.clear_charge()
	# télégraphe de la brute : vraie attaque, joueur à 1,2 u
	d.despawn_all()
	var b := d.spawn_enemy(3, base + Vector2(1.4, 0.0) * 64.0, false, [] as Array[StringName], 0)
	d.process_mode = Node.PROCESS_MODE_INHERIT
	TestMode.freeze_ai = false
	await get_tree().create_timer(0.5).timeout
	await _shot("brute_tele_early")
	await get_tree().create_timer(0.35).timeout
	await _shot("brute_tele_late")
	# massacre
	d.despawn_all()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var victims: Array[Enemy] = []
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.5, 6.0)
		var e2 := d.spawn_enemy(1, base + Vector2(cos(a), sin(a) * 0.6) * r * 64.0, false, [] as Array[StringName], 0)
		e2.visual.set_facing(float(rng.randi() % 8) * TAU / 8.0)
		victims.append(e2)
	await _f(4)
	for e3 in victims:
		e3.take_damage(1.0e9)
	d.corpses.process_mode = Node.PROCESS_MODE_ALWAYS
	d.corpses.set_capacity(40)
	print("cadavres vivants : ", d.corpses.live_count)
	await get_tree().create_timer(0.7).timeout
	if cam != null:
		cam.global_position = base + Vector2(0.0, 0.0)
	await _f(4)
	await _shot("corpses_massacre")
	get_tree().quit()


func _shot(n: String) -> void:
	await _f(2) # la capture lit l'image déjà rendue : laisser passer deux images
	if _out != "":
		CaptureUtil.save_viewport(get_viewport(), "%s/leg_%s.png" % [_out, n])
	print("shot ", n)
