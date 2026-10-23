extends Node
## godot --headless --path game res://tests/spell_tooltip_test.tscn
## Description des sorts en jeu (SpellHint) : survol souris -> bulle avec le bon texte (characters.json) ;
## appui tactile long -> bulle, aucun sort ; relâcher -> bulle cachée ; tap court -> sort, pas de bulle ;
## bulle toujours dans l'écran et au-dessus du bouton.

var _fails := 0
var _main: Node


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", msg)
	else:
		print("ok: ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = load("res://scenes/main.tscn").instantiate()
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	_main.set(&"run_seed", 77)
	add_child(_main)
	for i in 600:
		await get_tree().process_frame
		if bool(_main.get(&"is_ready")):
			break
	var hud: Hud = _main.hud
	var player: Node = _main.player
	player.grant_invulnerability(1.0e6)
	if hud.pause_menu.is_open:
		hud.pause_menu._close()
	get_tree().paused = false
	await _frames(3)
	var hint := hud.spell_hint
	_check(hint != null and hint.tip != null, "SpellHint créé par le HUD")
	_check(hint.mouse_filter == Control.MOUSE_FILTER_IGNORE and hint.tip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "bulle transparente aux entrées")
	var vp := get_viewport()
	var ft := vp.get_final_transform()
	var vis := vp.get_visible_rect()
	var json_desc := _json_spell(String(RunState.character), 2)

	# --- PC : survol de la case du sort 2 ---
	Platform.set_input_mode(Platform.InputMode.KBM)
	await _frames(3)
	var bb: SpellButton = hud.bar_buttons[1]
	var mm := InputEventMouseMotion.new()
	mm.position = ft * bb.get_global_rect().get_center()
	vp.push_input(mm)
	await _frames(3)
	_check(Platform.input_mode == Platform.InputMode.KBM, "souris -> mode clavier-souris")
	_check(hint.tip.visible and hint.button == bb, "survol -> bulle visible")
	var txt := hint.text_content()
	_check(json_desc.size() > 0 and txt.contains(String(json_desc.name)) and txt.contains(String(json_desc.desc)), "texte = nom + desc de characters.json : %s" % txt.replace("\n", " | "))
	_check(txt.contains("Recharge") or txt.contains("Ultime") or txt.contains("Auto"), "type du sort affiché")
	var tr := hint.tip.get_global_rect()
	_check(vis.encloses(tr), "bulle PC dans l'écran %s" % str(tr))
	_check(tr.end.y <= bb.get_global_rect().position.y + 1.0, "bulle PC au-dessus du bouton")
	# sort 1 (auto)
	mm = InputEventMouseMotion.new()
	mm.position = ft * hud.bar_buttons[0].get_global_rect().get_center()
	vp.push_input(mm)
	await _frames(3)
	_check(hint.text_content().contains("Auto"), "sort 1 : « Auto »")
	_check(vis.encloses(hint.tip.get_global_rect()), "bulle sort 1 dans l'écran")
	# sortie du survol
	mm = InputEventMouseMotion.new()
	mm.position = ft * Vector2(vis.size.x * 0.5, vis.size.y * 0.3)
	vp.push_input(mm)
	await _frames(3)
	_check(not hint.tip.visible, "sortie du survol -> bulle cachée")
	# pause : pas de bulle
	mm = InputEventMouseMotion.new()
	mm.position = ft * bb.get_global_rect().get_center()
	vp.push_input(mm)
	await _frames(2)
	get_tree().paused = true
	await _frames(2)
	_check(not hint.tip.visible, "pause -> pas de bulle")
	get_tree().paused = false
	mm = InputEventMouseMotion.new()
	mm.position = ft * Vector2(vis.size.x * 0.5, vis.size.y * 0.3)
	vp.push_input(mm)
	await _frames(2)

	# --- Tactile : appui long ---
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	await _frames(3)
	player.auto_cast_spells = false # isole le test du réglage d'accessibilité sauvegardé (sorts 2-4 auto)
	var d: Director = _main.director
	d.spawn_enemy(1, player.global_position + Vector2(120, 0))
	var sb: SpellButton = hud.spell_buttons[0]
	_check(player.spells.cooldown_remaining(2) == 0.0, "sort 2 prêt avant le test")
	var t := InputEventScreenTouch.new()
	t.index = 3
	t.pressed = true
	t.position = ft * sb.get_global_rect().get_center()
	vp.push_input(t)
	var pressed_seen := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700:
		await get_tree().process_frame
		if Input.is_action_pressed(&"spell_2"):
			pressed_seen = true
	_check(sb.is_held() and sb.is_long_pressed(), "appui long détecté")
	_check(not pressed_seen, "appui long : action spell_2 jamais simulée")
	_check(player.spells.cooldown_remaining(2) == 0.0, "appui long : sort non lancé")
	_check(hint.tip.visible and hint.button == sb, "appui long -> bulle visible")
	_check(hint.text_content().contains(String(json_desc.get("desc", "?"))), "appui long : bonne description")
	var ttr := hint.tip.get_global_rect()
	_check(vis.encloses(ttr), "bulle tactile dans l'écran %s" % str(ttr))
	_check(ttr.end.y <= sb.get_global_rect().position.y + 1.0, "bulle tactile au-dessus du bouton")
	var tr_rel := t.duplicate()
	tr_rel.pressed = false
	vp.push_input(tr_rel)
	await _frames(6)
	_check(not hint.tip.visible, "relâcher -> bulle cachée")
	_check(player.spells.cooldown_remaining(2) == 0.0 and not Input.is_action_pressed(&"spell_2"), "relâcher après appui long : pas de sort")

	# --- Tactile : tap court ---
	var tap := InputEventScreenTouch.new()
	tap.index = 4
	tap.pressed = true
	tap.position = ft * sb.get_global_rect().get_center()
	vp.push_input(tap)
	await _frames(2)
	var tap_r := tap.duplicate()
	tap_r.pressed = false
	vp.push_input(tap_r)
	var shown := hint.tip.visible
	for i in 8:
		await get_tree().physics_frame
		shown = shown or hint.tip.visible
	_check(player.spells.cooldown_remaining(2) > 0.0, "tap court -> sort lancé")
	_check(not shown, "tap court -> pas de bulle")
	_check(not Input.is_action_pressed(&"spell_2"), "tap court : action relâchée")

	# --- arbitre des bulles (H5) : tutoriel de la Bourse vs bulle demandée par le joueur
	SpellTooltip.set_user_bubble(&"spell_hint", false)
	SpellTooltip.set_user_bubble(&"item_tip", false)
	_check(not SpellTooltip.user_bubble_open(), "arbitre : aucune bulle P1 au départ")
	var tipn := AvarePurseTip.spawn(get_tree(), Color("#F2C14E"))
	await get_tree().create_timer(0.6).timeout
	_check(tipn.modulate.a > 0.9 and tipn.visible, "arbitre : le tutoriel est visible seul")
	var tip_t0 := tipn.t
	SpellTooltip.set_user_bubble(&"spell_hint", true)
	await get_tree().create_timer(0.6).timeout
	_check(tipn.modulate.a < 0.01 and not tipn.visible, "arbitre : bulle de sort ouverte -> tutoriel masqué")
	_check(is_equal_approx(tipn.t, tip_t0), "arbitre : minuteur du tutoriel figé")
	_check(SpellTooltip.other_user_bubble_open(&"item_tip"), "arbitre : infobulle d'item doit s'abstenir")
	SpellTooltip.set_user_bubble(&"spell_hint", false)
	await get_tree().create_timer(0.6).timeout
	_check(tipn.modulate.a > 0.9 and tipn.t > tip_t0, "arbitre : bulle fermée -> tutoriel revient, minuteur reprend")
	tipn.queue_free()
	# --- barre de boss : plaque discrète
	_check(BossBars.PLATE_ALPHA == 0.35 and BossBars.PLATE_ALPHA_TOP == 0.2 and BossBars.PLATE_H == 84.0, "barre de boss : plaque 0,35 / 0,20, 84 px")

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## Sort du slot (1-4) du personnage joué dans characters.json : {name, desc}.
func _json_spell(cid: String, slot: int) -> Dictionary:
	for c in CharacterCard.load_characters():
		if c is Dictionary and String(c.get("id", "")) == cid:
			var arr: Array = c.get("spells", [])
			if arr.size() >= slot:
				return arr[slot - 1]
	return {}
