extends Node
## Panneau d'objectifs (HUD) et conversion or -> XP au changement d'étage, sur la vraie scène de jeu.
## godot --headless --path game res://tests/objectives_test.tscn

var _fails := 0
var _main: Node


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


## XP totale accumulée depuis le niveau 1 (indépendante des montées de niveau).
static func _total_xp() -> float:
	var t := RunState.xp
	for l in range(1, RunState.level):
		t += Balance.xp_required(l)
	return t


static func _overlaps(a: Rect2, b: Rect2) -> bool:
	return a.size.x > 0.0 and b.size.x > 0.0 and a.grow(-1.0).intersects(b.grow(-1.0))


func _check_layout(hud: Hud, label: String) -> void:
	await _frames(3)
	var vp := hud.get_viewport().get_visible_rect().size
	var r := hud.objectives.get_global_rect()
	var safe: Dictionary = Platform.safe_margins()
	_check(r.end.x <= vp.x - float(safe["right"]) + 0.5 and r.position.x >= float(safe["left"]) - 0.5, "%s : panneau dans la zone sûre (horizontal) %s" % [label, r])
	_check(r.position.y >= float(safe["top"]) - 0.5 and r.end.y <= vp.y - float(safe["bottom"]), "%s : panneau dans la zone sûre (vertical)" % label)
	_check(not _overlaps(r, hud.minimap.get_global_rect()), "%s : ne masque pas la minimap" % label)
	if hud.boss_bars.visible:
		_check(not _overlaps(r, hud.boss_bars.get_global_rect()), "%s : ne masque pas les barres de boss %s / %s" % [label, r, hud.boss_bars.get_global_rect()])
	if hud.touch_layer.visible:
		for b in hud.spell_buttons:
			_check(not _overlaps(r, b.get_global_rect()), "%s : ne masque pas le bouton de sort %d" % [label, b.slot])
		_check(not _overlaps(r, hud.interact_button.get_global_rect()), "%s : ne masque pas Interagir %s / %s" % [label, r, hud.interact_button.get_global_rect()])
	var lbl_w := 0.0
	for row in hud.objectives.get_child(0).get_children():
		if row is HBoxContainer and row.visible:
			lbl_w = maxf(lbl_w, (row as HBoxContainer).get_combined_minimum_size().x)
	_check(lbl_w <= r.size.x + 0.5, "%s : lignes lisibles sans débordement (%.0f <= %.0f)" % [label, lbl_w, r.size.x])


func _ready() -> void:
	Platform.set_input_mode(Platform.InputMode.KBM)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 4321)
	add_child(_main)
	await _main.game_ready
	await _frames(5)
	var hud: Hud = _main.hud
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	if player.has_method(&"grant_invulnerability"):
		player.call(&"grant_invulnerability", 1.0e6)
	var panel: ObjectivesPanel = hud.objectives
	_check(panel != null, "le HUD a un panneau d'objectifs")
	_check(not panel.visible, "panneau masqué avant l'activation du gros pilier")

	# --- Petits piliers : le panneau reste masqué
	var big: Pillar = null
	for p in stage.pillars:
		if p.kind == Pillar.Kind.BIG:
			big = p
	_check(big != null and big.state == Pillar.STATE_LOCKED, "gros pilier verrouillé au départ")
	stage.pillars[0].activate()
	await _frames(2)
	_check(not panel.visible, "panneau masqué à l'activation d'un petit pilier")
	for p in stage.pillars:
		if p.kind == Pillar.Kind.SMALL:
			p.activate()
			p.boss_dead = true
			p._check_done() # petits piliers terminés (boss tués) -> gros pilier déverrouillé
	_check(big.state == Pillar.STATE_READY, "gros pilier déverrouillé")

	# --- Activation du gros pilier : 2 objectifs
	player.global_position = big.global_position + Vector2(2000, 0) # hors zone : la charge ne monte pas
	big.activate()
	await _frames(3)
	_check(panel.visible, "panneau visible à l'activation du gros pilier")
	_check(not panel.is_boss_done() and not panel.is_charge_done(), "deux objectifs en cours")
	_check(panel.charge_text() == "0 %", "charge 0 %% hors zone (%s)" % panel.charge_text())
	_check(not panel.is_teleport_shown(), "« Activer le téléporteur » pas encore affiché")
	await _check_layout(hud, "PC")

	player.global_position = big.global_position
	await _wait(1.2)
	var pct := int(floor(big.charge_ratio() * 100.0))
	_check(big.charge > 0.5 and panel.charge_text() == "%d %%" % pct, "la charge réelle monte : %s (pilier %.2f s)" % [panel.charge_text(), big.charge])
	big.charge = Pillar.CHARGE_TIME - 0.05
	await _wait(0.3)
	_check(panel.is_charge_done() and panel.charge_text() == "100 %", "charge terminée cochée (%s)" % panel.charge_text())
	_check(not panel.is_boss_done(), "boss encore vivant")

	# --- Mort du boss : coché, étage terminé -> « Activer le téléporteur »
	var boss: Node = big._boss
	_check(boss != null, "boss d'étage apparu")
	if boss != null and boss.has_method(&"take_damage"):
		boss.call(&"take_damage", 1.0e9)
	for i in 60:
		if big.state == Pillar.STATE_DONE:
			break
		await _frames(1)
	await _frames(2)
	_check(big.state == Pillar.STATE_DONE and stage.floor_cleared, "gros pilier terminé, étage terminé")
	_check(panel.is_boss_done() and panel.is_charge_done(), "les deux objectifs cochés")
	_check(panel.is_teleport_shown(), "« Activer le téléporteur » affiché")

	# --- Tactile (mobile) : même panneau, sans chevaucher les boutons
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	hud._apply_layout()
	await _check_layout(hud, "Tactile")
	Platform.set_input_mode(Platform.InputMode.KBM)
	hud._apply_layout()

	# --- Conversion or -> XP au changement d'étage
	await _wait(0.3)
	var pm := get_tree().get_first_node_in_group(&"pickups") as PickupManager
	var far := player.global_position + Vector2(3000, 3000)
	# Ramassage automatique (22/10/2026) : or et XP déposés loin sont crédités tout de suite (portée infinie).
	var g_drop := RunState.gold
	var xp_drop := _total_xp()
	pm.drop(far, PickupManager.KIND_GOLD, 40.0)
	pm.drop(far, PickupManager.KIND_XP, 5.0)
	_check(RunState.gold - g_drop >= 40.0 - 0.001, "or déposé loin crédité tout de suite (%.1f)" % (RunState.gold - g_drop))
	_check(_total_xp() - xp_drop >= 5.0 - 0.001, "XP déposée loin créditée tout de suite")
	RunState.add_gold(300.0)
	var ground_gold: float = pm.gold_carry # seule la fraction d'or reportée n'est pas encore créditée
	var ground_xp := 0.0
	var purse := RunState.gold
	var D := RunState.difficulty()
	var expected := Balance.gold_to_xp(RunState.gold + ground_gold, D) + ground_xp
	var xp0 := _total_xp()
	var conv: Array = []
	Events.gold_converted.connect(func(g: float, x: float) -> void: conv.append([g, x]))
	stage.teleporter.use() # = interagir sur le téléporteur
	_check(RunState.stage == 2, "étage 2")
	_check(RunState.gold == 0.0, "or remis à 0 (%.1f)" % RunState.gold)
	_check(pm.active_count == 0, "plus aucune pièce ni gemme au sol (%d)" % pm.active_count)
	_check(absf(_total_xp() - xp0 - expected) < 0.01, "XP gagnée = conversion (%.2f, attendu %.2f)" % [_total_xp() - xp0, expected])
	_check(expected > ground_xp + 1.0, "l'or rapporte bien de l'XP (%.1f)" % (expected - ground_xp))
	_check(conv.size() == 1 and absf(float(conv[0][0]) - purse - ground_gold) < 0.01, "Events.gold_converted émis une fois avec l'or total")
	await _frames(3)
	var fl := hud.root.get_node_or_null(^"GoldConvertedLabel") as Label
	_check(fl != null and fl.text.contains("XP (or converti)"), "texte flottant « +N XP (or converti) » (%s)" % (fl.text if fl else "absent"))
	_check(not panel.visible, "panneau masqué au nouvel étage")

	# --- Sauvegarde cohérente après conversion
	var save: Dictionary = _main.build_save_data()
	var run: Dictionary = save.get("run", {})
	_check(float(run.get("gold", -1.0)) == 0.0 and int(run.get("stage", 0)) == 2, "sauvegarde : or 0, étage 2")
	_check(int((save.get("stage", {}) as Dictionary).get("stage", 0)) == 2, "sauvegarde de l'étage : étage 2")
	var lvl := RunState.level
	var xp := RunState.xp
	RunState.add_gold(55.0)
	RunState.add_xp(500.0)
	RunState.from_dict(run)
	_check(RunState.gold == 0.0 and RunState.level == lvl and absf(RunState.xp - xp) < 0.001, "RunState.from_dict restaure or/XP/niveau après conversion")
	# sans or : pas de signal, XP inchangée
	conv.clear()
	var xp1 := _total_xp()
	_check(RunState.convert_gold_to_xp() == 0.0 and _total_xp() == xp1, "aucune XP sans or")

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
