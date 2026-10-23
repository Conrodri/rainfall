extends Node
## godot --headless --path game res://tests/platform_layout_test.tscn
## Layout du HUD et du menu pause en 1600x900 (PC), 1080x1920 (mobile) et formats limites :
## aucun contrôle visible hors écran ; contrôles tactiles masqués hors mode tactile.

class FakePlayer extends CharacterBody2D:
	signal hp_changed(hp: float, max_hp: float)
	var hp := 100.0
	var max_hp := 100.0
	var pickup_radius := 200.0
	func get_spell_cooldowns() -> Array:
		return [{"slot": 2, "remaining": 1.5, "total": 3.0}]

class FakeInteractable extends Node2D:
	func can_interact() -> bool:
		return true
	func interact_label() -> String:
		return "Partir"

var _fails := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", msg)


func _ready() -> void:
	_run.call_deferred()


## Contrôles visibles dont le rectangle global sort du viewport.
func _offscreen(node: Node, vp: Rect2, out: Array) -> void:
	for c in node.get_children():
		if c is Control and (c as Control).is_visible_in_tree():
			var ctl := c as Control
			var r := ctl.get_global_rect()
			if r.size.x > 0.0 and r.size.y > 0.0 and not vp.grow(1.5).encloses(r):
				out.append("%s %s hors %s" % [ctl.name, r, vp])
		if not c is ScrollContainer: # contenu défilant : hors vue par nature
			_offscreen(c, vp, out)


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _layout_case(size: Vector2i, touch: bool) -> void:
	var sv := SubViewport.new()
	sv.size = size
	add_child(sv)
	var hud: Hud = load("res://scripts/ui/hud.gd").new()
	sv.add_child(hud)
	var player := FakePlayer.new()
	player.add_to_group("player")
	sv.add_child(player)
	var it := FakeInteractable.new()
	it.add_to_group("interactable")
	sv.add_child(it)
	Platform.set_input_mode(Platform.InputMode.TOUCH if touch else Platform.InputMode.KBM)
	await _frames()
	hud.bind_player(player)
	player.hp_changed.emit(60.0, 100.0)
	await _frames()
	await get_tree().create_timer(0.4).timeout # fin de l animation du bouton Interagir
	var vp := Rect2(Vector2.ZERO, Vector2(size))
	var tag := "%dx%d %s" % [size.x, size.y, "tactile" if touch else "kbm"]
	var bad: Array = []
	_offscreen(hud, vp, bad)
	_check(bad.is_empty(), "%s : contrôles hors écran %s" % [tag, str(bad)])
	_check(hud.touch_layer.visible == touch, "%s : couche tactile visible = %s" % [tag, touch])
	_check(hud._prompt_panel.visible == (not touch), "%s : invite d'interaction" % tag)
	if touch:
		_check(hud.interact_button.is_visible_in_tree(), "%s : bouton Interagir visible" % tag)
		var rects: Array[Rect2] = [hud.interact_button.get_global_rect()]
		for b in hud.spell_buttons:
			_check(b.is_visible_in_tree(), "%s : bouton de sort visible" % tag)
			rects.append(b.get_global_rect())
		_check(hud.dodge_button.is_visible_in_tree(), "%s : bouton Roulade visible" % tag)
		rects.append(hud.dodge_button.get_global_rect())
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				_check(not rects[i].intersects(rects[j]), "%s : chevauchement boutons %d/%d" % [tag, i, j])
		var top_end: float = hud._top.get_global_rect().end.y
		_check(hud.interact_button.get_global_rect().position.y >= top_end * 0.8, "%s : Interagir sous le bandeau" % tag)
	else:
		_check(not hud.joystick.is_visible_in_tree(), "%s : joystick masqué" % tag)
		var txt: String = hud._prompt_label.text
		_check(txt.begins_with("[") and txt.ends_with("Partir"), "%s : invite « %s »" % [tag, txt])

	# redimensionnement : le layout se recalcule
	var swapped := Vector2i(size.y, size.x)
	sv.size = swapped
	await get_tree().create_timer(0.1).timeout
	await _frames()
	bad.clear()
	_offscreen(hud, Rect2(Vector2.ZERO, Vector2(swapped)), bad)
	_check(bad.is_empty(), "%s -> %dx%d : hors écran après redimensionnement %s" % [tag, swapped.x, swapped.y, str(bad)])

	# menu pause (panneaux principal, réglages, confirmation)
	sv.size = size
	await _frames()
	hud.pause_menu.open()
	await _frames()
	for panel in [hud.pause_menu._panel_main, hud.pause_menu._panel_settings, hud.pause_menu._panel_confirm]:
		hud.pause_menu._show_only(panel)
		await _frames()
		bad.clear()
		_offscreen(hud.pause_menu, vp, bad)
		_check(bad.is_empty(), "%s : pause hors écran %s" % [tag, str(bad)])
	hud.pause_menu._close()
	sv.queue_free()
	await _frames(1)


func _run() -> void:
	for sz in [Vector2i(1600, 900), Vector2i(1080, 1920), Vector2i(1920, 1080), Vector2i(1080, 2340), Vector2i(1280, 720), Vector2i(800, 600)]:
		await _layout_case(sz, true)
		await _layout_case(sz, false)
	# bascule de mode en direct
	var sv := SubViewport.new()
	sv.size = Vector2i(1600, 900)
	add_child(sv)
	var hud: Hud = load("res://scripts/ui/hud.gd").new()
	sv.add_child(hud)
	await _frames(2)
	Platform.set_input_mode(Platform.InputMode.KBM)
	_check(not hud.touch_layer.visible, "kbm : tactile masqué")
	Platform.set_input_mode(Platform.InputMode.GAMEPAD)
	_check(not hud.touch_layer.visible and not hud.pause_button.visible, "manette : tactile et bouton pause masqués")
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	_check(hud.touch_layer.visible and hud.joystick.is_visible_in_tree(), "toucher : contrôles réapparaissent")
	sv.queue_free()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
