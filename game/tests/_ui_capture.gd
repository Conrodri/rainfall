extends Node
## Captures visuelles de l'UI (à lancer SANS --headless) : HUD avec boss, coffre, titre, nouvelle run, fiche, progression,
## fin de run, pause, en 1920x1080 et 2400x1080.
## godot --path game res://tests/_ui_capture.tscn -- --out=<dossier> --tag=avant [--touch]

class FakeProfile extends RefCounted:
	var rubies := 4820
	var unlocked_modes: Array = ["facile", "moyen"]
	var unlocked_spells: Array = []
	var last_mode := "moyen"
	var last_character := "averse"
	var stats := {"runs": 37, "victories": 5, "kills": 18423, "play_time_s": 43200.0, "best_time_s": {"facile": 812.0}}
	var unlocked_skins: Array = ["ardent_skin1", "averse_skin1"]
	var selected_skin := {"averse": "averse_skin1"}
	var best_runs := {}

	func is_unlocked(_key: StringName) -> bool:
		return false

var _out := ""
var _tag := "x"
var _touch := false
var _sim_sheet := false ## simule le correctif de character_sheet.gd (marges des cellules relevées) pour juger de l'effet


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
		elif a == "--sim-sheet":
			_sim_sheet = true
		elif a == "--touch":
			_touch = true
	Platform.set_input_mode(Platform.InputMode.TOUCH if _touch else Platform.InputMode.KBM)
	await _f(3)
	for sz in [Vector2i(1920, 1080), Vector2i(2400, 1080)]:
		get_window().size = sz
		await _f(4)
		await _menus("%d" % sz.x)
	await _hud()
	get_tree().quit()


func _menus(sz: String) -> void:
	var t := (load("res://scenes/menu/title.tscn") as PackedScene).instantiate() as TitleScreen
	t.summary_provider = func(): return {"character": "ardent", "character_name": "Ardent", "mode": "moyen", "stage": 2, "active_time_s": 252.0, "map_id": "terrasses_noyees", "saved_at": 0}
	add_child(t)
	await _f(40)
	_save("%s_titre" % sz)
	t.queue_free()
	var s := NewRunScreen.new()
	s.profile = FakeProfile.new()
	add_child(s)
	await _f(25)
	_save("%s_newrun" % sz)
	s.cards[1].pressed.emit()
	await _f(20)
	if _sim_sheet:
		_pad_panels(s)
		await _f(6)
	_save("%s_fiche" % sz)
	s.queue_free()
	var st := (load("res://scenes/menu/settings.tscn") as PackedScene).instantiate()
	add_child(st)
	await _f(20)
	_save("%s_options" % sz)
	st.queue_free()
	var pr := (load("res://scenes/menu/progress.tscn") as PackedScene).instantiate()
	pr.set("profile", FakeProfile.new())
	add_child(pr)
	await _f(25)
	_save("%s_progression" % sz)
	pr.tab_skins.pressed.emit()
	await _f(8)
	_save("%s_progression_skins" % sz)
	pr.queue_free()
	var e := EndRunScreen.create({"victory": false, "reason": "death", "character_name": "Averse", "mode": "moyen",
		"stage": 3, "active_time_s": 642.0, "level": 17, "pillars": 4, "kills": 1204, "items": 9, "gold": 230,
		"rubies": 87, "unlocks": [&"character:rictus", &"spell:roaming_embers", &"mode:difficile"]})
	add_child(e)
	await _f(80)
	_save("%s_finrun" % sz)
	e.queue_free()
	await _f(2)


func _pad_panels(n: Node) -> void:
	for c in n.get_children():
		if c is PanelContainer and (c as Control).has_theme_stylebox_override(&"panel"):
			var sb := (c as Control).get_theme_stylebox(&"panel")
			if sb is StyleBoxTexture:
				UiTheme.pad_box(sb, 26)
				(c as Control).add_theme_stylebox_override(&"panel", sb)
		_pad_panels(c)


func _hud() -> void:
	RunState.character = &"averse"
	var m := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	m.set(&"run_seed", 2024)
	add_child(m)
	while not bool(m.get(&"is_ready")):
		await _f(1)
	var hud: Hud = m.hud
	var p: Node2D = m.player
	p.grant_invulnerability(1.0e6)
	var d: Director = m.director
	var pp: Vector2 = p.global_position
	d.spawn_boss(&"etage", pp + Vector2(560, -280))
	d.spawn_boss(&"mini", pp + Vector2(-480, 220))
	RunState.difficulty_changed.emit(4.4, &"Furieux")
	Platform.mobile_preview = _touch
	for sz in [Vector2i(1920, 1080), Vector2i(2400, 1080)]:
		get_window().size = sz
		await _f(60)
		_save("%d_hud" % sz.x)
		if sz.x == 1920: # bandeau de difficulté : début, passage de palier, Cataclysme
			RunState.running = false # sinon RunState réémet D à chaque image
			for dv in [1.0, 1.25, 1.9, 2.6, 5.0]:
				RunState.difficulty_changed.emit(dv, Balance.difficulty_tier_name(dv))
				await _f(120)
				_save("diff_%s" % str(dv).replace(".", "_"))
			RunState.running = true
		var mgr := get_tree().get_first_node_in_group("stage_manager")
		hud.call(&"_on_level", RunState.level + 1)
		if mgr != null:
			mgr.set("floor_cleared", true)
		var sb: SpellButton = hud.bar_buttons[1] if hud.bar_buttons[1].is_visible_in_tree() else hud.spell_buttons[0]
		var info := hud.spell_hint.describe(sb)
		hud.spell_hint.tip.show_for(sb, info.title, info.tag, info.body)
		await _f(20)
		_save("%d_hud_tip" % sz.x)
		hud.spell_hint.tip.hide_tip()
		hud.pause_menu.open()
		await _f(25)
		_save("%d_pause" % sz.x)
		hud.pause_menu._close()
		await _f(4)
		hud.pause_menu.open_items()
		await _f(25)
		_save("%d_pause_objets" % sz.x)
		hud.pause_menu._close()
		await _f(4)
		var ui := (load("res://scenes/ui/chest/chest_ui.tscn") as PackedScene).instantiate() as ChestUI
		m.add_child(ui)
		ui.open(&"large", 2, 60.0)
		await _f(150)
		_save("%d_coffre" % sz.x)
		get_tree().paused = false
		ui.queue_free()
		await _f(3)
	Platform.mobile_preview = false


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(n: String) -> void:
	if _out != "":
		CaptureUtil.save_viewport(get_viewport(), "%s/%s_%s.png" % [_out, _tag, n])
	print("shot ", n)
