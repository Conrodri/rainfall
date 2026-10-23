extends Node
## Disposition des sorts : tactile = grappe au pouce en bas à droite (roulade la plus grosse et la plus proche du
## coin, sorts 2/3/4 en arc, icône de l'auto en petit indicateur non cliquable) ; clavier-souris / manette = barre
## centrée en bas, inchangée. À 1920x1080, 2400x1080 et 1280x720 : tout dans l'écran, aucun chevauchement
## (Interagir, minimap, joystick, panneau d'objectifs compris), cibles tactiles >= 96 px (en unités de 1080p).
## A11y-L4 (audit E-03/E-04/E-05/E-06) : encoche simulée à gauche puis à droite sans redimensionnement (bandeau du
## haut, bouton pause, minimap, joystick et grappe recalculés), zones de frappe (+16 px sorts, pause 140 px, aucune
## superposition), joystick (zone morte remise à l'échelle, réglages accessibility/joystick_*), Retour Android = Échap.
## godot --headless --path game res://tests/touch_layout_test.tscn  → « RESULT: OK »

class FakePlayer extends CharacterBody2D:
	signal hp_changed(hp: float, max_hp: float)
	var hp := 100.0
	var max_hp := 100.0
	var pickup_radius := 200.0
	var kit: Node = null ## FakeKit : ressource (jauge du HUD)

	func get_spell_cooldowns() -> Array:
		return []


class FakeKit extends Node:
	func resource_state() -> Dictionary:
		return KitResource.make(&"water", "Eau", 0.6, Color("#5FD4E8"), {"text": "60", "mark": 0.8})

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1280, 720)]
const MIN_TARGET := 96.0

var _fails := 0
var _seen_back: Array[String] = [] ## actions reçues pendant Platform.handle_back()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", msg)


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var prev_mode: int = Platform.input_mode
	for size in SIZES:
		await _case(size, true)
		await _case(size, false)
	await _safe_case()
	_joystick_case()
	_back_case()
	Platform.set_input_mode(prev_mode)
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _case(size: Vector2i, touch: bool) -> void:
	var sv := SubViewport.new()
	sv.size = size
	add_child(sv)
	var hud: Hud = load("res://scripts/ui/hud.gd").new()
	sv.add_child(hud)
	var player := FakePlayer.new()
	player.add_to_group("player")
	player.kit = FakeKit.new()
	player.add_child(player.kit)
	sv.add_child(player)
	Platform.set_input_mode(Platform.InputMode.TOUCH if touch else Platform.InputMode.KBM)
	await _frames()
	hud.bind_player(player)
	player.hp_changed.emit(60.0, 100.0)
	await _frames()
	var vp := Rect2(Vector2.ZERO, Vector2(size))
	var tag := "%dx%d %s" % [size.x, size.y, "tactile" if touch else "kbm"]
	var s: float = hud.ui_scale
	var mm: Rect2 = hud.minimap.get_global_rect()
	var obj: Rect2 = hud.objectives.get_global_rect()
	if touch:
		_check(hud.touch_layer.visible and not hud._spell_bar.visible, "%s : grappe tactile visible, barre masquée" % tag)
		var named := {"roulade": hud.dodge_button, "sort2": hud.spell_buttons[0], "sort3": hud.spell_buttons[1],
			"sort4": hud.spell_buttons[2], "interagir": hud.interact_button}
		var rects := {}
		for k in named:
			var c: Control = named[k]
			rects[k] = c.get_global_rect()
			_check(vp.encloses(rects[k]), "%s : %s hors écran %s" % [tag, k, rects[k]])
			_check(minf(c.size.x, c.size.y) / s >= MIN_TARGET - 0.5, "%s : cible %s < %d px (%.0f)" % [tag, k, int(MIN_TARGET), minf(c.size.x, c.size.y) / s])
		var auto_r: Rect2 = hud.auto_indicator.get_global_rect()
		rects["auto"] = auto_r
		_check(hud.touch_gauge.visible and not hud.bar_gauge.visible, "%s : jauge de ressource tactile visible" % tag)
		rects["jauge"] = hud.touch_gauge.get_global_rect()
		_check(vp.encloses(rects["jauge"]), "%s : jauge hors écran %s" % [tag, rects["jauge"]])
		_check(hud.auto_indicator.visible and not hud.auto_indicator.interactive, "%s : auto = indicateur non cliquable" % tag)
		_check(hud.auto_indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s : l'indicateur laisse passer les appuis" % tag)
		_check(vp.encloses(auto_r), "%s : indicateur auto hors écran" % tag)
		# roulade : la plus grosse et la plus proche du coin ; l'ultime (sort 4) est le plus proche après elle
		var corner := vp.end
		var dist := {}
		for k in ["roulade", "sort2", "sort3", "sort4"]:
			dist[k] = (rects[k] as Rect2).get_center().distance_to(corner)
		var dc: Vector2 = (rects["roulade"] as Rect2).get_center()
		_check(rects["roulade"].size.x > rects["sort2"].size.x, "%s : roulade plus grosse que les sorts" % tag)
		_check(dist["roulade"] < dist["sort2"] and dist["roulade"] < dist["sort3"] and dist["roulade"] < dist["sort4"], "%s : roulade au plus près du coin" % tag)
		var v4: Vector2 = dc - (rects["sort4"] as Rect2).get_center()
		var ang4 := rad_to_deg(atan2(v4.y, v4.x))
		_check(ang4 > 30.0 and ang4 < 60.0, "%s : ultime en diagonale du pouce (%.0f°)" % [tag, ang4])
		# marge de sécurité : pas collé au bord
		var safe: Dictionary = Platform.safe_margins()
		_check(vp.end.x - (rects["roulade"] as Rect2).end.x >= float(safe["right"]) + 1.0, "%s : roulade dans la zone sûre (droite)" % tag)
		_check(vp.end.y - (rects["roulade"] as Rect2).end.y >= float(safe["bottom"]) + 1.0, "%s : roulade dans la zone sûre (bas)" % tag)
		# aucun chevauchement
		var keys := rects.keys()
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				_check(not (rects[keys[i]] as Rect2).intersects(rects[keys[j]]), "%s : %s %s chevauche %s %s" % [tag, keys[i], rects[keys[i]], keys[j], rects[keys[j]]])
		var joy := Rect2(Vector2(0.0, vp.size.y * 0.5), Vector2(vp.size.x * 0.48, vp.size.y * 0.5))
		for k in keys:
			var r: Rect2 = rects[k]
			_check(not r.intersects(mm), "%s : %s chevauche la minimap" % [tag, k])
			_check(not r.intersects(obj), "%s : %s chevauche le panneau d'objectifs %s %s" % [tag, k, r, obj])
			_check(not r.intersects(joy), "%s : %s %s chevauche la zone du joystick %s" % [tag, k, r, joy])
	else:
		_check(not hud.touch_layer.visible and hud._spell_bar.visible, "%s : barre visible, grappe tactile masquée" % tag)
		_check(hud.bar_buttons.size() == 4, "%s : 4 sorts dans la barre" % tag)
		var bar: Rect2 = hud._spell_bar.get_global_rect()
		_check(vp.encloses(bar), "%s : barre hors écran %s" % [tag, bar])
		_check(absf(bar.get_center().x - vp.size.x * 0.5) < 4.0 * s + 40.0, "%s : barre centrée (%.0f)" % [tag, bar.get_center().x])
		_check(bar.end.y > vp.size.y * 0.8, "%s : barre en bas" % tag)
		_check(not bar.intersects(mm), "%s : barre chevauche la minimap" % tag)
		var gr: Rect2 = hud.bar_gauge.get_global_rect()
		_check(hud.bar_gauge.visible and vp.encloses(gr) and not gr.intersects(bar) and gr.end.x <= bar.position.x, "%s : jauge à gauche de la barre %s %s" % [tag, gr, bar])
		_check(gr.end.y <= bar.end.y and gr.end.y > bar.end.y - 140.0 * s, "%s : jauge au niveau des icônes" % tag)
		_check(not gr.intersects(mm) and not gr.intersects(obj), "%s : jauge chevauche minimap / objectifs" % tag)
	sv.queue_free()
	await _frames(2)


func _unhandled_input(event: InputEvent) -> void:
	for a in ["pause", "ui_cancel"]:
		if event.is_action_pressed(a):
			_seen_back.append(a)


## Encoche de 132 px à gauche puis à droite, 2400x1080 tactile : la fenêtre ne change pas de taille, seul
## Platform.safe_area_changed déclenche le recalcul.
func _safe_case() -> void:
	var size := Vector2i(2400, 1080)
	var sv := SubViewport.new()
	sv.size = size
	add_child(sv)
	var hud: Hud = load("res://scripts/ui/hud.gd").new()
	sv.add_child(hud)
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	await _frames()
	var vp := Rect2(Vector2.ZERO, Vector2(size))
	const NOTCH := 132.0
	for side in ["left", "right"]:
		var ins := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
		ins[side] = NOTCH
		Platform.set_safe_override(ins)
		await _frames()
		var tag := "encoche %s" % side
		var safe: Dictionary = Platform.safe_margins()
		_check(is_equal_approx(float(safe[side]), NOTCH), "%s : marge %s = %.0f" % [tag, side, float(safe[side])])
		var top_l := float(hud._top.get_theme_constant(&"margin_left"))
		var top_r := float(hud._top.get_theme_constant(&"margin_right"))
		_check(top_l >= float(safe["left"]) - 0.5, "%s : bandeau du haut hors encoche à gauche (%.0f)" % [tag, top_l])
		_check(top_r >= float(safe["right"]) - 0.5, "%s : bandeau du haut hors encoche à droite (%.0f)" % [tag, top_r])
		var pb: Rect2 = hud.pause_button.get_global_rect()
		_check(pb.end.x <= vp.end.x - float(safe["right"]) + 0.5, "%s : bouton pause hors encoche %s" % [tag, pb])
		_check(pb.position.y >= float(safe["top"]) - 0.5, "%s : bouton pause sous la marge du haut" % tag)
		var mm: Rect2 = hud.minimap.get_global_rect()
		_check(mm.end.x <= vp.end.x - float(safe["right"]) + 0.5, "%s : minimap hors encoche %s" % [tag, mm])
		var joy: Rect2 = hud.joystick.get_global_rect()
		_check(joy.position.x >= float(safe["left"]) + FloatingJoystick.EDGE_GAP - 0.5, "%s : joystick à >= zone sûre + 24 px du bord gauche (%.0f)" % [tag, joy.position.x])
		_check(joy.end.y <= vp.end.y - 32.0 + 0.5, "%s : joystick au-dessus de la barre de gestes (%.0f)" % [tag, joy.end.y])
		var cluster: Array[SpellButton] = [hud.dodge_button, hud.spell_buttons[0], hud.spell_buttons[1], hud.spell_buttons[2]]
		for c in cluster:
			var r := c.get_global_rect()
			_check(r.end.x <= vp.end.x - float(safe["right"]) + 0.5, "%s : bouton %d dans la zone sûre" % [tag, c.slot])
		# zones de frappe : sorts >= 150 px, disques de +16 px sans chevauchement (écart libre >= 40 px)
		for i in cluster.size():
			var a := cluster[i]
			if a != hud.dodge_button:
				_check(a.size.x >= HudMetrics.TOUCH_SPELL_PX - 0.5, "%s : sort %d >= 150 px" % [tag, a.slot])
			_check(a.hit_pad() >= 15.5, "%s : marge de frappe %.1f" % [tag, a.hit_pad()])
			for j in range(i + 1, cluster.size()):
				var b := cluster[j]
				var d := a.get_global_rect().get_center().distance_to(b.get_global_rect().get_center())
				var gap := d - a.size.x * 0.5 - b.size.x * 0.5
				_check(gap >= 40.0 - 0.5, "%s : écart %d-%d = %.0f px < 40" % [tag, a.slot, b.slot, gap])
				_check(d >= a.hit_radius() + b.hit_radius(), "%s : zones de frappe %d-%d superposées" % [tag, a.slot, b.slot])
		# un toucher à 10 px hors du visuel du sort 2 reste pris par le bouton
		var s2: SpellButton = hud.spell_buttons[0]
		_check(s2._has_point(Vector2(-10.0, s2.size.y * 0.5)), "%s : zone de frappe du sort 2 (+16 px)" % tag)
		_check(not s2._has_point(Vector2(-20.0, s2.size.y * 0.5)), "%s : zone de frappe du sort 2 bornée" % tag)
		var pbtn: PauseButton = hud.pause_button
		_check(absf(pbtn.size.x + 2.0 * pbtn.hit_pad() - PauseButton.HIT_PX * pbtn.size.x / PauseButton.VISUAL_PX) < 0.5, "%s : pause 140 px de frappe" % tag)
		_check(pbtn._has_point(Vector2(-12.0, -12.0)) and not pbtn._has_point(Vector2(-20.0, 0.0)), "%s : zone de frappe du bouton pause" % tag)
	# l'encoche est passée à droite : le bandeau revient à sa marge minimale à gauche
	_check(float(hud._top.get_theme_constant(&"margin_left")) < NOTCH, "encoche à droite : bandeau du haut recalé à gauche")
	Platform.set_safe_override({})
	sv.queue_free()
	await _frames(2)


## Joystick : zone morte remise à l'échelle, réglages accessibility/joystick_* lus via GameSettings (fichier injecté).
func _joystick_case() -> void:
	var prev_path: String = GameSettings.cfg_path
	var path := "user://_touch_layout_test_settings.cfg"
	var cf := ConfigFile.new()
	cf.set_value(FloatingJoystick.SETTINGS_SECTION, FloatingJoystick.KEY_DEADZONE, 0.2)
	cf.set_value(FloatingJoystick.SETTINGS_SECTION, FloatingJoystick.KEY_SIZE, 1.25)
	cf.save(path)
	GameSettings.cfg_path = path
	var j := FloatingJoystick.new()
	add_child(j)
	_check(is_equal_approx(j.deadzone, 0.2) and is_equal_approx(j.size_factor, 1.25), "joystick : réglages lus (%.2f, %.2f)" % [j.deadzone, j.size_factor])
	_check(is_equal_approx(j.radius(), FloatingJoystick.MAX_RADIUS * 1.25), "joystick : rayon à l'échelle")
	j.set_vector(Vector2(0.15, 0.0))
	_check(j.vector == Vector2.ZERO, "joystick : sous la zone morte -> 0")
	j.set_vector(Vector2(0.6, 0.0))
	_check(absf(j.vector.x - 0.5) < 0.01, "joystick : course remise à l'échelle (%.2f)" % j.vector.x)
	j.set_vector(Vector2(1.0, 0.0))
	_check(is_equal_approx(j.vector.x, 1.0), "joystick : plein débattement")
	j.release()
	_check(j.vector == Vector2.ZERO and not Input.is_action_pressed("move_right"), "joystick : relâché")
	j.apply_safe_area({"left": 132.0, "bottom": 32.0})
	_check(is_equal_approx(j.offset_left, 156.0) and is_equal_approx(j.offset_bottom, -32.0), "joystick : apply_safe_area")
	j.queue_free()
	GameSettings.cfg_path = prev_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Retour Android : le projet ne quitte pas, Retour = Échap (pause / ui_cancel), sans changer le mode d'entrée.
func _back_case() -> void:
	_check(ProjectSettings.get_setting("application/config/quit_on_go_back", true) == false, "quit_on_go_back = false")
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	_seen_back.clear()
	var got := [false]
	var cb := func() -> void: got[0] = true
	Platform.back_requested.connect(cb)
	Platform.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	Platform.back_requested.disconnect(cb)
	_check(got[0], "Retour : signal back_requested")
	_check(_seen_back.has("pause") and _seen_back.has("ui_cancel"), "Retour : pause et ui_cancel reçus %s" % [_seen_back])
	_check(_seen_back.count("pause") == 1, "Retour : une seule pause (%d)" % _seen_back.count("pause"))
	_check(Platform.input_mode == Platform.InputMode.TOUCH, "Retour : mode tactile conservé")
