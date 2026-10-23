extends Node
## godot --headless --path game res://tests/ui_test_hud_pickups.tscn
## HUD + pickups avec un faux joueur : enemy_killed -> aimantation -> or/XP dans RunState.

class FakePlayer extends CharacterBody2D:
	signal hp_changed(hp: float, max_hp: float)
	var hp := 100.0
	var max_hp := 100.0
	var pickup_radius := 200.0
	func get_spell_cooldowns() -> Array:
		return [{"slot": 2, "remaining": 1.5, "total": 3.0}]

var _fails := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", msg)


class FakeInteractable extends Node2D:
	var ok := true
	func can_interact() -> bool:
		return ok
	func interact_label() -> String:
		return "Ouvrir - 240 or"


func _ready() -> void:
	var events := Events
	var rs := RunState
	var player := FakePlayer.new()
	player.add_to_group("player")
	add_child(player)
	var mgr = load("res://scripts/pickups/pickup_manager.gd").new()
	add_child(mgr)
	var dn = load("res://scripts/fx/damage_numbers.gd").new()
	add_child(dn)
	var hud = load("res://scripts/ui/hud.gd").new()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	player.hp = 40.0
	player.hp_changed.emit(40.0, 100.0)
	_check(hud._hp_label.text == "40 / 100", "hp label: " + hud._hp_label.text)
	_check(hud.spell_buttons[0].remaining > 1.0, "cooldown propage")

	var gold0: float = rs.gold
	var xp0: float = rs.xp
	var lvl0: int = rs.level
	events.enemy_killed.emit(null, Vector2(100, 0), 2, true)
	events.enemy_killed.emit(null, Vector2(-100, 50), 1, false)
	_check(mgr.active_count > 0, "pickups deposes")
	events.enemy_damaged.emit(player, 12.0, true, &"fire")
	_check(dn.active_count == 1, "chiffre de degats")
	for i in 120:
		await get_tree().process_frame
	_check(mgr.active_count == 0, "tous ramasses, reste %d" % mgr.active_count)
	_check(rs.gold > gold0, "or recu")
	_check(rs.xp > xp0 or rs.level > lvl0, "xp recue")
	_check(hud._gold_label.text != "Or  0", "label or: " + hud._gold_label.text)

	# fusion : beaucoup de gemmes
	for i in 600:
		events.enemy_killed.emit(null, Vector2(5000 + i, 5000), 1, false)
	_check(mgr.active_count <= mgr.MAX_PICKUPS, "borne pickups")

	# joystick
	hud.joystick.set_vector(Vector2(1, 0))
	_check(Input.get_axis("move_left", "move_right") > 0.9, "joystick -> move_right")
	hud.joystick.release()
	_check(Input.get_axis("move_left", "move_right") == 0.0, "joystick relache")

	# bouton Interagir
	var it := FakeInteractable.new()
	it.add_to_group("interactable")
	it.position = Vector2(30, 0)
	add_child(it)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(hud.interact_button.is_shown(), "bouton interagir visible")
	_check(hud.interact_button.label_text == "Ouvrir - 240 or", "label interagir")
	hud.interact_button.trigger()
	_check(Input.is_action_pressed("interact"), "interact presse")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not Input.is_action_pressed("interact"), "interact relache")
	it.ok = false
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not hud.interact_button.is_shown(), "bouton interagir cache")

	# multi-touch : pouce gauche sur le joystick, pouce droit sur Interagir
	it.ok = true
	await get_tree().process_frame
	await get_tree().process_frame
	var vp := get_viewport()
	var ft := vp.get_final_transform()
	var t0 := InputEventScreenTouch.new()
	t0.index = 0
	t0.pressed = true
	var jp: Vector2 = hud.joystick.global_position + hud.joystick.size * Vector2(0.2, 0.6) # dans la zone du joystick, quelle que soit la taille d écran
	t0.position = ft * jp
	vp.push_input(t0)
	var d0 := InputEventScreenDrag.new()
	d0.index = 0
	d0.position = ft * (jp + Vector2(100, 0))
	d0.relative = Vector2(100, 0)
	vp.push_input(d0)
	_check(Input.get_axis("move_left", "move_right") > 0.5, "joystick tactile actif")
	var t1 := InputEventScreenTouch.new()
	t1.index = 1
	t1.pressed = true
	t1.position = ft * (hud.interact_button.global_position + Vector2(100, 70))
	vp.push_input(t1)
	_check(Input.is_action_pressed("interact"), "interact presse en multi-touch")
	_check(Input.get_axis("move_left", "move_right") > 0.5, "joystick toujours actif pendant interact")
	var t1r := t1.duplicate()
	t1r.pressed = false
	vp.push_input(t1r)
	var t0r := t0.duplicate()
	t0r.pressed = false
	vp.push_input(t0r)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(Input.get_axis("move_left", "move_right") == 0.0, "joystick relache (touch)")
	# un appui sur un bouton de sort ne demarre pas le joystick
	var t2 := InputEventScreenTouch.new()
	t2.index = 2
	t2.pressed = true
	t2.position = ft * (hud.spell_buttons[0].global_position + Vector2(60, 60))
	vp.push_input(t2)
	_check(hud.spell_buttons[0].is_held(), "sort presse")
	_check(hud.joystick.vector == Vector2.ZERO, "joystick non demarre par un bouton")
	var t2r := t2.duplicate()
	t2r.pressed = false
	vp.push_input(t2r)

	# pause
	hud.pause_menu.open()
	_check(get_tree().paused, "arbre en pause")
	hud.pause_menu._on_resume()
	for i in 200:
		await get_tree().process_frame
		if not get_tree().paused:
			break
	hud.pause_menu._count = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not get_tree().paused, "reprise apres compte a rebours")

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
