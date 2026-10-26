extends Node
## godot --headless --path game res://tests/passive_hud_test.tscn  -> RESULT: OK
## Retours du joueur 23/10/2026, en jeu (Vigie) :
##  - icône de passif près des sorts : infobulle au survol (souris), à l'appui long (tactile) ; la jauge de
##    ressource ouvre la même infobulle ; visible pour les 10 personnages ;
##  - infobulle de sort : dégâts affichés = SpellCaster.compute_damage (même formule), origine du scaling.

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
	RunState.character = &"vigie"
	RunState.level = 1
	_main = load("res://scenes/main.tscn").instantiate()
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	_main.set(&"run_seed", 78)
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
	await _frames(4)
	var hint := hud.spell_hint
	var vp := get_viewport()
	var ft := vp.get_final_transform()
	var vis := vp.get_visible_rect()
	var badge: Control = hud.passive_badge

	# --- badge présent pour Vigie ---
	Platform.set_input_mode(Platform.InputMode.KBM)
	await _frames(4)
	_check(badge != null and badge.visible and badge.char_id == &"vigie", "Vigie : icône de passif affichée")
	_check(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "PC : l'icône n'intercepte pas la souris (elle vise)")
	_check(vis.encloses(badge.get_global_rect()), "icône dans l'écran %s" % str(badge.get_global_rect()))
	for b in hud.bar_buttons:
		_check(not badge.get_global_rect().intersects(b.get_global_rect()), "icône ne chevauche pas la case de sort %d" % b.slot)
	_check(not badge.get_global_rect().intersects(hud.bar_gauge.get_global_rect()), "icône ne chevauche pas la jauge")

	# --- PC : survol de l'icône ---
	var mm := InputEventMouseMotion.new()
	mm.position = ft * badge.get_global_rect().get_center()
	vp.push_input(mm)
	await _frames(4)
	_check(hint.tip.visible and hint.passive_anchor == badge, "survol de l'icône -> infobulle de passif")
	var txt := hint.text_content()
	_check(txt.contains("Tension") and txt.contains("Passif"), "texte : nom du passif : %s" % txt.replace("\n", " | ").left(120))
	_check(txt.contains(KitResource.fmt(VigieKit.TENSION_MOVING_S)) and txt.contains(KitResource.fmt(VigieKit.ALLONGE_RANGE_U)), "texte : chiffres du kit (%s s, %s u)" % [KitResource.fmt(VigieKit.TENSION_MOVING_S), KitResource.fmt(VigieKit.ALLONGE_RANGE_U)])
	_check(txt.contains("Remplit") and txt.contains("Vide") and txt.contains("Effet"), "texte : ce qui remplit, vide, effet de palier")
	_check(vis.encloses(hint.tip.get_global_rect()), "infobulle dans l'écran")
	# --- PC : survol de la jauge de ressource ---
	hud.bar_gauge.visible = true
	mm = InputEventMouseMotion.new()
	mm.position = ft * hud.bar_gauge.get_global_rect().get_center()
	vp.push_input(mm)
	await _frames(4)
	_check(hud.bar_gauge.visible and hint.tip.visible and hint.passive_anchor == hud.bar_gauge, "survol de la jauge -> même infobulle de passif")
	mm = InputEventMouseMotion.new()
	mm.position = ft * Vector2(vis.size.x * 0.5, vis.size.y * 0.3)
	vp.push_input(mm)
	await _frames(4)
	_check(not hint.tip.visible and hint.passive_anchor == null, "sortie du survol -> infobulle fermée")

	# --- dégâts réels dans l'infobulle de sort ---
	var caster: SpellCaster = player.spells
	for slot in [1, 2, 3, 4]:
		var btn: SpellButton = hud.bar_buttons[slot - 1]
		var sd: SpellData = null
		for s in player.character.spells:
			if s.slot == slot:
				sd = s
		_check(sd != null, "sort %d connu" % slot)
		if sd == null:
			continue
		var d := hint.describe(btn)
		var expect := caster.compute_damage(sd, null, false)
		if sd.coef > 0.0:
			_check(d.body.contains("Dégâts : %s par coup" % KitResource.fmt(snappedf(expect, 0.1))), "sort %d : dégâts affichés = compute_damage (%s)" % [slot, KitResource.fmt(snappedf(expect, 0.1))])
			_check(is_equal_approx(caster.preview_damage(sd), expect), "sort %d : preview_damage = compute_damage" % slot)
			_check(d.body.contains("du dégât de base") and d.body.contains("Chaque niveau"), "sort %d : origine du scaling (coef, niveau)" % slot)
		else:
			_check(not d.body.contains("Dégâts :"), "sort %d sans dégâts : pas de ligne de dégâts" % slot)
	# le scaling suit le niveau et les objets (aucune valeur figée)
	var sd1: SpellData = player.character.spells[0]
	var d_lvl1: String = hint.describe(hud.bar_buttons[0]).body
	RunState.level = 6
	var d_lvl6: String = hint.describe(hud.bar_buttons[0]).body
	_check(d_lvl1 != d_lvl6 and d_lvl6.contains(KitResource.fmt(snappedf(caster.compute_damage(sd1, null, false), 0.1))), "niveau 6 : dégâts recalculés (%s)" % d_lvl6.replace("\n", " | ").left(100))
	player.stats["damage_add"] = 0.5
	var d_item: String = hint.describe(hud.bar_buttons[0]).body
	_check(d_item.contains("objets") and d_item != d_lvl6, "bonus d'objets visible dans le scaling")
	player.stats.erase("damage_add")
	RunState.level = 1

	# --- tactile : appui long sur l'icône ---
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	await _frames(4)
	_check(badge.visible and badge.mouse_filter == Control.MOUSE_FILTER_STOP, "tactile : l'icône reçoit l'appui")
	_check(vis.encloses(badge.get_global_rect()), "tactile : icône dans l'écran %s" % str(badge.get_global_rect()))
	for b in hud.spell_buttons:
		_check(not badge.get_global_rect().intersects(b.get_global_rect()), "tactile : icône ne chevauche pas le sort %d" % b.slot)
	var t := InputEventScreenTouch.new()
	t.index = 5
	t.pressed = true
	t.position = ft * badge.get_global_rect().get_center()
	vp.push_input(t)
	await get_tree().create_timer(0.35).timeout
	_check(not hint.tip.visible, "tactile : pas d'infobulle avant l'appui long")
	await get_tree().create_timer(0.5).timeout
	await _frames(3)
	_check(hint.tip.visible and hint.passive_anchor == badge and badge.is_long_pressed(), "tactile : appui long -> infobulle de passif")
	_check(vis.encloses(hint.tip.get_global_rect()), "tactile : infobulle dans l'écran %s" % str(hint.tip.get_global_rect()))
	var tr := t.duplicate()
	tr.pressed = false
	vp.push_input(tr)
	await _frames(5)
	_check(not hint.tip.visible, "tactile : relâcher -> infobulle fermée")

	# --- tactile : appui long sur la jauge de ressource (Vigie en a une) = même infobulle ---
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	await _frames(4)
	if hud.touch_gauge.visible:
		_check(hud.touch_gauge.mouse_filter == Control.MOUSE_FILTER_STOP, "tactile : la jauge reçoit l'appui")
		var tg := InputEventScreenTouch.new()
		tg.index = 6
		tg.pressed = true
		tg.position = ft * hud.touch_gauge.get_global_rect().get_center()
		vp.push_input(tg)
		await get_tree().create_timer(0.8).timeout
		await _frames(3)
		_check(hint.tip.visible and hint.passive_anchor == badge, "tactile : appui long sur la jauge -> infobulle de passif")
		var tgr := tg.duplicate()
		tgr.pressed = false
		vp.push_input(tgr)
		await _frames(5)
		_check(not hint.tip.visible, "tactile : relâcher la jauge -> infobulle fermée")
	else:
		_check(false, "Vigie : jauge tactile attendue")

	# --- les 10 personnages : icône visible, dans l'écran, sans chevauchement, infobulle non vide ---
	var ids: Array[StringName] = [&"ardent", &"rictus", &"tocsin", &"averse", &"arpenteuse", &"rainette", &"avare", &"bourbe", &"vigie", &"morfil"]
	_main.queue_free()
	await _frames(3)
	for cid in ids:
		await _check_character(cid)

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check_character(cid: StringName) -> void:
	RunState.character = cid
	RunState.level = 1
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.process_mode = Node.PROCESS_MODE_PAUSABLE
	m.set(&"run_seed", 78)
	add_child(m)
	for i in 600:
		await get_tree().process_frame
		if bool(m.get(&"is_ready")):
			break
	var hud: Hud = m.hud
	m.player.grant_invulnerability(1.0e6)
	if hud.pause_menu.is_open:
		hud.pause_menu._close()
	get_tree().paused = false
	var badge: Control = hud.passive_badge
	var vis := get_viewport().get_visible_rect()
	for mode in [Platform.InputMode.KBM, Platform.InputMode.TOUCH]:
		Platform.set_input_mode(mode)
		await _frames(5)
		var tag := "%s/%s" % [cid, "tactile" if mode == Platform.InputMode.TOUCH else "PC"]
		_check(badge.visible and badge.char_id == cid, "%s : icône de passif visible" % tag)
		var r := badge.get_global_rect()
		_check(vis.encloses(r), "%s : icône dans l'écran %s" % [tag, str(r)])
		var others: Array = hud.reserved_rects()
		var overlap := false
		for o in others:
			if (o as Rect2).is_equal_approx(r):
				continue
			if r.intersects(o) and not (o as Rect2).encloses(r):
				overlap = true
		_check(not overlap, "%s : icône sans chevauchement des zones réservées" % tag)
		var info: Dictionary = badge.info
		_check(not String(info.get("name", "")).is_empty() and not String(info.get("desc", "")).is_empty(), "%s : texte de passif non vide" % tag)
		_check(not hud.spell_hint.describe_passive().body.is_empty(), "%s : infobulle de passif non vide" % tag)
	Platform.set_input_mode(Platform.InputMode.KBM)
	m.queue_free()
	await _frames(3)
