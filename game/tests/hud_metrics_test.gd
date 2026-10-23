extends Node
## Lot HUD-B : table de tailles HudMetrics, planchers 18/26 px, PV verts, Hud.reserved_rects.
## godot --headless --path game res://tests/hud_metrics_test.tscn

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	# --- table : plancher et facteur mobile (pure, sans HUD)
	var levels := {
		"T1_HP": HudMetrics.T1_HP, "T1_COOLDOWN": HudMetrics.T1_COOLDOWN, "T2_TIME": HudMetrics.T2_TIME,
		"T2_GOLD": HudMetrics.T2_GOLD, "T2_BOSS": HudMetrics.T2_BOSS, "T3_GAUGE": HudMetrics.T3_GAUGE,
		"T4_SMALL": HudMetrics.T4_SMALL, "T5_BADGE": HudMetrics.T5_BADGE, "PROMPT": HudMetrics.PROMPT,
	}
	for k in levels:
		_check(HudMetrics.font(levels[k], 1.0, false) >= 18 and HudMetrics.font(levels[k], 0.6, false) >= 18, "%s >= 18 px (PC, même fenêtre réduite)" % k)
		_check(HudMetrics.font(levels[k], 1.0, true) >= 26 and HudMetrics.font(levels[k], 0.6, true) >= 26, "%s >= 26 px (mobile)" % k)
	_check(HudMetrics.T1_HP[0] > HudMetrics.T4_SMALL[0] and HudMetrics.T2_TIME[0] > HudMetrics.T2_GOLD[0], "ordre des niveaux PC")
	_check(HudMetrics.pick(HudMetrics.HP_BAR, true).y > HudMetrics.pick(HudMetrics.HP_BAR, false).y, "barre de PV plus haute en mobile")
	_check(HudMetrics.user_scale() >= HudMetrics.USER_SCALE_MIN and HudMetrics.user_scale() <= HudMetrics.USER_SCALE_MAX, "user_scale borné")

	# --- HUD réel
	Platform.set_input_mode(Platform.InputMode.KBM)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 778)
	add_child(main)
	await main.game_ready
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: Hud = main.hud
	var mobile := HudMetrics.is_mobile()
	var fs: int = hud._hp_label.get_theme_font_size("font_size")
	_check(fs >= HudMetrics.floor_px(mobile), "PV : police %d >= plancher" % fs)
	_check(hud._time_label.get_theme_font_size("font_size") <= HudMetrics.font(HudMetrics.T2_TIME, 1.0 * HudMetrics.user_scale(), mobile), "chrono <= T2")
	_check(hud._hp_regen.get_theme_font_size("font_size") >= HudMetrics.floor_px(mobile), "régénération >= plancher")
	_check(hud._diff_label.get_theme_font_size("font_size") >= HudMetrics.floor_px(mobile), "difficulté >= plancher")
	_check(hud._xp_bar.custom_minimum_size.y >= 10.0 * 0.6, "barre d'XP >= 10 px (échelle 1)")
	var fill := hud._hp_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		_check(is_equal_approx((fill as StyleBoxFlat).bg_color.g, HudMetrics.COL_HP.g) and (fill as StyleBoxFlat).bg_color.g > (fill as StyleBoxFlat).bg_color.r, "PV du joueur : vert")
		hud._on_hp(20.0, 100.0)
		_check((fill as StyleBoxFlat).bg_color.is_equal_approx(HudMetrics.COL_HP_LOW), "PV < 25 % : rouge vif")
		hud._on_hp(100.0, 100.0)
		_check((fill as StyleBoxFlat).bg_color.is_equal_approx(HudMetrics.COL_HP), "PV pleins : vert")
	_check(HudMetrics.COL_HP.is_equal_approx(OverheadBars.COL_HP), "vert HUD = vert au-dessus de la tête")
	# plaque commune minimap + difficulté
	var plate: Panel = hud._map_plate
	hud._place_difficulty()
	_check(plate.visible and plate.get_global_rect().encloses(hud._diff_box.get_global_rect()) and plate.get_global_rect().encloses(hud.minimap.get_compact_rect()), "plaque commune minimap + difficulté")
	# zones réservées
	var rects := hud.reserved_rects()
	_check(rects.size() >= 4, "reserved_rects : %d zones" % rects.size())
	var vp := get_viewport().get_visible_rect()
	var inside := true
	for r in rects:
		inside = inside and vp.grow(2.0).encloses(r)
	_check(inside, "zones réservées dans l'écran")
	var pr := hud._player_plate.get_global_rect()
	var has_plate := false
	for r in rects:
		has_plate = has_plate or r.intersects(pr)
	_check(has_plate, "la fiche joueur est une zone réservée")
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
