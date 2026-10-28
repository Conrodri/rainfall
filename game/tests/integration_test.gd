extends Node
## Test d'intégration : la vraie scène de jeu (scenes/main.tscn) déroule un étage avec les vrais
## systèmes (Director, StageManager, piliers, boss, coffre, téléporteur, ambiance, audio, HUD).
## godot --headless --path game res://tests/integration_test.tscn
##
## Vérifie aussi : branchements des cartes (Director / AmbianceManager / Audio, une fois par étage),
## limites de caméra, couche des télégraphes, lumières LightRig, signaux Events ajoutés (foudre,
## palier, charge), bondisseur (charge télégraphiée), protection de reprise, choix de fin d'étage 3,
## écran de fin avec rubis.

var _fails := 0
var _main: Node
var _ev := {"lightning": 0, "tier": 0, "charge": 0, "charge_max": 0.0, "floor_started": 0, "boss_spawned": 0}
var _restart := false


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _ready() -> void:
	Events.lightning_struck.connect(func(_i: float, _p: Vector2) -> void: _ev["lightning"] += 1)
	Events.difficulty_tier_changed.connect(func(_t: StringName, _d: float) -> void: _ev["tier"] += 1)
	Events.pillar_charge_progress.connect(func(_p: Node, r: float) -> void:
		_ev["charge"] += 1
		_ev["charge_max"] = maxf(_ev["charge_max"], r))
	Events.floor_started.connect(func(_s: int) -> void: _ev["floor_started"] += 1)
	Events.boss_spawned.connect(func(_b: Node2D, _f: bool) -> void: _ev["boss_spawned"] += 1)

	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 4242)
	add_child(_main)
	_check(_main.get_node_or_null(^"LoadingScreen") != null, "écran de chargement affiché pendant la préchauffe")
	await _main.game_ready
	_check(_main.get_node_or_null(^"LoadingScreen") == null or _main.get_node(^"LoadingScreen").is_queued_for_deletion(), "écran de chargement retiré")
	await _frames(3)

	var stage: StageManager = _main.stage
	var director: Director = _main.director
	var amb: AmbianceManager = _main.ambiance
	var player: Node2D = _main.player
	player.grant_invulnerability(1.0e6)

	# --- Branchements de carte
	_check(stage.map != null and director.get_map() == stage.map, "Director.bind_map : carte de l'étage")
	_check(amb.map == stage.map and amb.profile != null, "AmbianceManager.bind_map : profil « %s »" % stage.map_id)
	_check(Audio.current_map_id() == stage.map_id, "Audio.start_map : %s" % Audio.current_map_id())
	_check(_ev["floor_started"] == 1, "un seul floor_started")
	var b := stage.get_bounds()
	var cam: Camera2D = _main.camera
	_check(cam != null and cam.limit_left == int(stage.map.to_global(b.position).x) and cam.limit_bottom == int(stage.map.to_global(b.end).y), "limites de caméra = StageManager.get_bounds()")
	var layer := AmbianceManager.telegraph_layer(get_tree())
	_check(layer != null and _main.damage_numbers.get_parent() == layer, "chiffres de dégâts sous la couche des télégraphes")
	_check((_main.damage_numbers as CanvasItem).light_mask == 0, "chiffres de dégâts : light_mask 0")
	_check(_ev["tier"] >= 1, "Events.difficulty_tier_changed émis")
	_check(LightRig.instance() != null and _has_light(&"player"), "lumière du joueur (LightRig player)")
	_check(_has_light(&"chest_petit") or _has_light(&"chest_large"), "lumières des coffres (chest_<rareté>)")

	# --- HUD : 4 sorts visibles (icône ou libellé), recharges, touches, aide de démarrage
	var hud: Hud = _main.hud
	_check(hud.bar_buttons.size() == 4 and hud.bar_buttons.all(func(sb: SpellButton) -> bool: return sb.icon != null or sb.caption != ""), "barre des 4 sorts : icône ou libellé")
	_check(hud.spell_buttons.all(func(sb: SpellButton) -> bool: return sb.icon != null), "boutons tactiles : icônes des sorts")
	_check(hud.bar_buttons[0].is_auto and hud.bar_buttons[1].total > 0.0, "sort 1 auto, recharges transmises")
	_check(hud.bar_keys.size() == 4 and (hud.bar_keys[1].text() != "" or Platform.input_mode == Platform.InputMode.TOUCH) and hud.bar_keys[1].get_child_count() > 0, "touche sous les sorts (%s)" % hud.bar_keys[1].text())
	# headless : rien n'est écrit, la clé reflète l'état avant la partie
	var first_game := not bool(GameSettings.get_value("gameplay", "help_shown", false))
	_check(hud.is_help_visible() == first_game, "aide des commandes au démarrage (première partie : %s)" % first_game)

	# --- Bondisseur (tier 2, charge télégraphiée)
	var leaper: Enemy = director.spawn_enemy(2, player.global_position + Vector2(220, 0), false, [] as Array[StringName], Enemy.VARIANT_LEAPER)
	_check(leaper != null and leaper.variant == Enemy.VARIANT_LEAPER, "bondisseur créé")
	if leaper != null:
		leaper.set(&"_spell_cd", 0.0)
		await _frames(2)
		_check(leaper.telegraph.get_parent() == layer, "télégraphe sous la couche des télégraphes")
		_check(leaper.telegraph.visible and leaper.telegraph.get(&"_shape") == EnemyTelegraph.Shape.LINE, "charge télégraphiée (ligne)")
		var p0 := leaper.position
		await _frames(int(Enemy.LEAP_WINDUP * 60.0) + 20)
		_check(leaper.position.distance_to(p0) > 2.0 * Balance.UNIT_PX or not leaper.active, "course de charge (%.0f px)" % leaper.position.distance_to(p0))

	# --- Petits piliers : mini-boss, zone, mort du boss
	var smalls: Array = []
	var big: Pillar = null
	for p in stage.pillars:
		if p.kind == Pillar.Kind.SMALL:
			smalls.append(p)
		else:
			big = p
	_check(smalls.size() == 2 and big != null and big.state == Pillar.STATE_LOCKED, "2 petits piliers + 1 gros verrouillé")
	for p: Pillar in smalls:
		player.global_position = p.global_position + Vector2(0, 60)
		await _frames(2)
		_check(p.activate(), "activation du pilier %d" % p.zone_id)
		await _frames(2)
		var zv: Node = p.get(&"_zone_vis")
		_check(zv != null and zv.get_parent() == layer, "zone du pilier sous la couche des télégraphes")
		var boss: Node2D = p.get(&"_boss")
		_check(boss != null and boss.is_in_group(&"bosses"), "mini-boss apparu")
		_check(_light_of(boss) == &"boss", "lumière de boss")
		boss.take_damage(1.0e9)
		await _frames(3)
		_check(p.state == Pillar.STATE_DONE, "pilier %d terminé à la mort du boss" % p.zone_id)
	_check(big.state == Pillar.STATE_READY, "gros pilier déverrouillé")

	# --- Gros pilier : boss d'étage + charge (n'avance que joueur dedans)
	var lightning_before: int = _ev["lightning"]
	player.global_position = big.global_position + Vector2(0, 60)
	await _frames(2)
	_check(big.activate(), "activation du gros pilier")
	var fboss: Node2D = big.get(&"_boss")
	await _frames(30)
	_check(_ev["charge"] > 0 and big.charge > 0.0, "charge qui avance + Events.pillar_charge_progress (%d)" % _ev["charge"])
	var cl: LightRig.Handle = big.get(&"_charge_light")
	_check(cl != null and cl.radius_mult > 1.0, "lumière de charge qui monte (rayon ×%.2f)" % (cl.radius_mult if cl else 0.0))
	big.charge = Balance.PILLAR_CHARGE_S - 0.05
	await _frames(10)
	_check(big.is_charged(), "gros pilier chargé")
	fboss.take_damage(1.0e9)
	await _frames(3)
	_check(big.state == Pillar.STATE_DONE and stage.floor_cleared, "étage terminé")
	_check(_ev["lightning"] > lightning_before, "foudre de fin de pilier -> Events.lightning_struck")
	_check(stage.teleporter.active, "téléporteur actif")

	# --- Coffre du boss (gratuit) : UI, dé, choix
	var boss_chest: Node = null
	for c in stage.chests:
		if is_instance_valid(c) and c.get(&"kind") == &"boss":
			boss_chest = c
	_check(boss_chest != null, "coffre du boss posé")
	var items_before := RunState.items.size()
	if boss_chest != null:
		_check(boss_chest.try_open(), "ouverture du coffre du boss")
		await _frames(1)
		_check(get_tree().paused, "coffre : arbre en pause")
		var ui: Node = null
		for n in get_tree().current_scene.get_children():
			if n.has_method(&"_on_choose"):
				ui = n
		var t := 0.0
		while ui != null and bool(ui.get(&"_busy")) and t < 8.0:
			await _wait(0.1)
			t += 0.1
		_check(ui != null and not bool(ui.get(&"_busy")), "intro du coffre jouée (%.1f s)" % t)
		if ui != null:
			ui.call(&"_on_choose", 0)
		await _frames(2)
		_check(not get_tree().paused and RunState.items.size() > items_before, "item choisi, jeu repris")

	# --- Pause : reprise après compte à rebours, puis 1,5 s de protection
	player.set(&"_invuln", 0.0)
	var pm: PauseMenu = _main.hud.pause_menu
	pm.open()
	_check(get_tree().paused, "pause ouverte")
	pm.call(&"_sync_settings")
	pm.call(&"_fill_controls")
	var ctl: Array = pm.controls_texts()
	_check(ctl.has("Déplacement") and ctl.has("Pause"), "menu pause : écran Commandes")
	# Compte à rebours (M-D) : 3 s si danger proche, 1 s sinon ; puis Main applique 1,5 s de protection.
	var resume_s := pm.resume_duration()
	var expected_s := Balance.RESUME_COUNTDOWN_DANGER_S if pm.danger_near() else Balance.RESUME_COUNTDOWN_CALM_S
	_check(is_equal_approx(resume_s, expected_s), "reprise : compte à rebours de %.0f s (danger proche : %s)" % [resume_s, pm.danger_near()])
	pm.call(&"_on_resume")
	await _wait(resume_s - 0.3)
	_check(get_tree().paused, "reprise : toujours en pause pendant le compte à rebours")
	await _wait(0.5)
	_check(not get_tree().paused and player.is_invulnerable(), "reprise : protection de 1,5 s après le compte à rebours")

	# --- Téléporteur : étage suivant, carte rebranchée une fois
	var old_map := stage.map
	stage.teleporter.use()
	await _frames(3)
	_check(RunState.stage == 2 and stage.map != old_map, "étage 2 lancé")
	_check(_ev["floor_started"] == 2 and amb.map == stage.map and director.get_map() == stage.map, "carte 2 branchée (ambiance, Director)")
	_check(Audio.current_map_id() == stage.map_id, "musique de la carte 2 (%s)" % stage.map_id)

	# --- Étage final (5, la Source) : choix de fin (Continuer en sans fin)
	var fin := StageManager.FINAL_STAGE
	RunState.stage = fin
	stage.floor_cleared = true
	stage.request_exit()
	await _frames(1)
	var vs: RunScreens = _main.victory_screen
	_check(vs != null and get_tree().paused, "écran de choix à l'étage %d" % fin)
	if vs != null:
		vs.press(1)
		await _frames(3)
		_check(stage.endless and RunState.stage == fin + 1 and not get_tree().paused, "continuer en sans fin -> étage %d" % (fin + 1))

	# --- Abandon : écran de fin, rubis, relance
	_main.restart_requested.connect(func() -> void: _restart = true)
	_main.hud.abandon_requested.emit()
	await _frames(1)
	var es: RunScreens = _main.end_screen
	_check(es != null and _main.run_over and get_tree().paused, "écran de fin de run")
	if es != null:
		var txt := " ".join(es.texts())
		_check(txt.contains("Rubis gagnés : %d" % _main.last_rubies) and _main.last_rubies > 0, "rubis affichés (%d)" % _main.last_rubies)
		es.press(0)
		await _frames(1)
		_check(_restart and not get_tree().paused, "relance demandée")
	var save: Dictionary = _main.build_save_data()
	_check(save.has("run") and save.has("stage") and int(save["run"]["stage"]) == fin + 1, "Sauvegarder et quitter : instantané de run (stub)")

	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().paused = false
	get_tree().quit(0 if _fails == 0 else 1)


func _has_light(preset: StringName) -> bool:
	for h in LightRig._requests:
		if not h.released and h.preset == preset:
			return true
	return false


func _light_of(n: Node) -> StringName:
	var h: LightRig.Handle = n.get(&"_light") if n != null else null
	return h.preset if h != null else &""
