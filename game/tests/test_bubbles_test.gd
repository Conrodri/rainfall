extends Node
## Mode test : bulles de test (TestBubbles). Bulles créées, bascule VFX / HUD par bulle (drapeau + HUD caché puis rétabli),
## bulle de sort qui lance le vrai sort, Poutch, rangée de boss et attaques forcées sur tous les boss du catalogue.
## godot --headless --path game res://tests/test_bubbles_test.tscn  -> RESULT: OK

const PROFILE_PATH := "user://test_bubbles_profile.json"

var _fails := 0
var _main: Node
var _bubbles: TestBubbles
var _old_path := ""
var _old_write := false


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _btn(path: String) -> Button:
	return _bubbles.find_child(path, true, false) as Button


func _run() -> void:
	_old_path = Profile.path
	_old_write = Profile.write_enabled
	Profile.path = PROFILE_PATH
	Profile.write_enabled = false
	TestMode.begin()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 78)
	add_child(_main)
	await _main.game_ready
	await _frames(5)
	var player: CharacterBody2D = _main.get(&"player")
	var overlay := _main.get_node_or_null(^"TestOverlay") as TestOverlay
	_check("overlay présent", overlay != null)
	_bubbles = overlay.bubbles
	_check("bulles créées", _bubbles != null and _bubbles.visible and TestBubbles.shown)
	await _frames(3)
	_check("bulles VFX, HUD, Poutch", _btn("Bubble_vfx") != null and _btn("Bubble_hud") != null and _btn("Bubble_poutch") != null)
	var sc: SpellCaster = player.spells
	var n_spells := sc.character.spells.size()
	var n_bubbles := 0
	for s in sc.character.spells:
		if _btn("Bubble_spell_%d" % s.slot) != null:
			n_bubbles += 1
	_check("une bulle par sort (%d)" % n_spells, n_spells > 0 and n_bubbles == n_spells, str(n_bubbles))

	# --- bascule VFX
	_btn("Bubble_vfx").pressed.emit()
	_check("bulle VFX : vfx_test allumé", TestMode.vfx_test)
	_btn("Bubble_vfx").pressed.emit()
	_check("bulle VFX : vfx_test éteint", not TestMode.vfx_test)

	# --- bascule HUD
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	var minimap := hud.get(&"minimap") as CanvasItem
	var root := hud.get(&"root") as Control
	var vis0: Array = root.get_children().map(func(c): return c.visible if c is CanvasItem else true)
	_btn("Bubble_hud").pressed.emit()
	await _frames(2)
	_check("bulle HUD : hide_hud allumé", TestMode.hide_hud)
	_check("HUD caché (minimap, barres)", not minimap.visible and not (hud.get(&"overhead") as CanvasItem).visible)
	var joy := hud.get(&"joystick") as CanvasItem
	var touch := hud.get(&"touch_layer") as CanvasItem
	_check("joystick et sa couche épargnés", joy.get_parent() == touch)
	_btn("Bubble_hud").pressed.emit()
	await _frames(2)
	var vis1: Array = root.get_children().map(func(c): return c.visible if c is CanvasItem else true)
	_check("bulle HUD : HUD rétabli à l'identique", not TestMode.hide_hud and vis0 == vis1)

	# --- Poutch + sort
	_check("Poutch : aucun au départ", TestTools.poutchs(get_tree()).is_empty())
	_btn("Bubble_poutch").pressed.emit()
	await _frames(3)
	_check("bulle Poutch : mannequin apparu", TestTools.poutchs(get_tree()).size() == 1)
	var cast_ok := false
	for s in sc.character.spells:
		if s.slot < 2:
			continue
		sc.set_cooldown(s.slot, 0.0, 1.0)
		_btn("Bubble_spell_%d" % s.slot).pressed.emit()
		if sc.cooldown_remaining(s.slot) > 0.0:
			cast_ok = true
			break
	_check("bulle de sort : le vrai sort est lancé (recharge relancée)", cast_ok)
	sc.set_cooldown(1, 0.0, 1.0)
	_btn("Bubble_spell_1").pressed.emit()
	_check("bulle sort 1 : lancé sur le mannequin", sc.cooldown_remaining(1) > 0.0)
	get_tree().paused = true
	var ok_paused := _bubbles.cast_slot(2)
	get_tree().paused = false
	_check("lancer en pause sans erreur", ok_paused or not sc.has_pending())
	_btn("Bubble_poutch").pressed.emit()
	await _frames(2)
	_check("bulle Poutch : rappuyer le retire", TestTools.poutchs(get_tree()).is_empty())

	# --- replis et mode bulles
	_bubbles._handle.pressed.emit()
	_check("poignée : replie", _bubbles.collapsed and not _bubbles._content.visible)
	_bubbles._handle.pressed.emit()
	_check("poignée : déplie", not _bubbles.collapsed and _bubbles._content.visible)
	_bubbles._set_pad_mode(true)
	_check("mode bulles : focus pris", _btn("Bubble_vfx").focus_mode == Control.FOCUS_ALL and _btn("Bubble_vfx").has_focus())
	# mode bulles : le joueur ne bouge pas malgré l'action move, à la sortie le mouvement revient
	var p0 := player.global_position
	Input.action_press(&"move_right")
	await _frames(15)
	_check("mode bulles : joueur immobile malgré move_right", player.global_position.distance_to(p0) < 1.0, str(player.global_position.distance_to(p0)))
	_check("mode bulles : source muette", player.input_source() is TestMutedInput and player.input_source().move_vector() == Vector2.ZERO)
	_bubbles._set_pad_mode(false)
	_check("mode bulles quitté : plus de focus", _btn("Bubble_vfx").focus_mode == Control.FOCUS_NONE)
	_check("sortie : source d'origine rendue", not (player.input_source() is TestMutedInput))
	var p1 := player.global_position
	await _frames(15)
	Input.action_release(&"move_right")
	_check("sortie : mouvement rendu", player.global_position.distance_to(p1) > 5.0, str(player.global_position.distance_to(p1)))
	_bubbles._set_pad_mode(true)
	_bubbles._set_pad_mode(false)
	_check("entrer / sortir : source d'origine", not (player.input_source() is TestMutedInput))
	TestBubbles.set_shown(false)
	_check("option panneau : bulles masquées", not _bubbles.visible)
	TestBubbles.set_shown(true)
	_check("option panneau : bulles rendues", _bubbles.visible)
	await _frames(2)
	var vp := get_viewport().get_visible_rect().size
	var wr: Rect2 = _bubbles._wrap.get_global_rect()
	_check("colonne dans l'écran", Rect2(Vector2.ZERO, vp).encloses(wr), "%s / %s" % [wr, vp])

	# --- boss : rangée de bulles + attaque forcée
	var cat := TestTools.monster_catalog()
	var first_boss: Dictionary = cat.filter(func(e): return e.kind == &"boss")[0]
	var made := TestTools.spawn(get_tree(), first_boss, 1, false)
	_check("boss invoqué", made.size() == 1)
	await _frames(45)
	var grid: GridContainer = _bubbles._boss_grid
	_check("rangée de bulles de boss présente", grid.visible and grid.get_child_count() >= 2, str(grid.get_child_count()))
	var fired := false
	for c in grid.get_children():
		var b := c as Button
		if b != null and not b.disabled and b.name != &"Boss_head" and not String(b.name).begins_with("Boss_phase"):
			b.pressed.emit()
			fired = true
			break
	await _frames(20)
	_check("attaque forcée lancée par bulle", fired)
	TestTools.clean(get_tree())
	await _frames(50)
	_check("boss retiré : rangée disparue", not grid.visible)

	# --- rain_sower : attaque forcée dès l'apparition (intro passée)
	var rs: Dictionary = {}
	for e in cat:
		if String(e.get("boss_id", "")) == "rain_sower":
			rs = e
	_check("rain_sower au catalogue", not rs.is_empty())
	if not rs.is_empty():
		var rres := TestTools.spawn(get_tree(), rs, 1, false)
		await _frames(2)
		var rb := rres[0] as Enemy
		var rbr: Object = rb.brain
		_check("rain_sower en intro à l'apparition", int(rbr.get("state")) == 0, str(rbr.get("state")))
		var atk: Dictionary = {}
		for a in TestBossAdapter.attacks(rb):
			if a.kind == &"method":
				atk = a
				break
		_check("rain_sower : attaque forcée réussie pendant l'intro", not atk.is_empty() and TestBossAdapter.fire(rb, atk, player.global_position))
		_check("rain_sower : intro passée", int(rbr.get("state")) != 0)
		await _frames(4)
		var ok2 := false
		for a in TestBossAdapter.attacks(rb):
			if a.kind == &"method" and a.id != atk.id:
				ok2 = TestBossAdapter.fire(rb, a, player.global_position)
				break
		_check("rain_sower : attaque forcée pendant une autre", ok2)
		TestTools.clean(get_tree())
		await _frames(2)

	# --- adaptateur : toutes les attaques de tous les boss du catalogue
	var supported := 0
	var total := 0
	var grey := []
	for e in cat:
		if e.kind == &"tier":
			continue
		var res := TestTools.spawn(get_tree(), e, 1, false)
		if res.size() != 1:
			continue
		await _frames(12)
		var boss := res[0] as Enemy
		var list := TestBossAdapter.attacks(boss)
		var lst := []
		for a in list:
			total += 1
			if not bool(a.ok):
				grey.append("%s/%s" % [e.boss_id, a.id])
				continue
			if TestBossAdapter.fire(boss, a, player.global_position):
				supported += 1
				lst.append(String(a.label))
			else:
				grey.append("%s/%s" % [e.boss_id, a.id])
			await _frames(4)
		print("  boss %s (%s) : %s" % [e.boss_id, TestBossAdapter.brain_name(boss), ",".join(lst)])
		await _frames(30)
		TestTools.clean(get_tree())
		await _frames(2)
	print("  attaques forcées : %d/%d ; non supportées : %s" % [supported, total, grey])
	_check("adaptateur : au moins la moitié des attaques lancées", supported > 0 and supported >= total / 2)

	# --- sortie
	TestMode.set_flag(&"hide_hud", true)
	remove_child(_main)
	_main.queue_free()
	await _frames(3)
	_check("sortie : drapeaux VFX / HUD remis", not TestMode.hide_hud and not TestMode.vfx_test and not TestMode.active)
	Profile.path = _old_path
	Profile.write_enabled = _old_write
	Profile.reset()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
