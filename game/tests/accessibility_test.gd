extends Node
## Passe accessibilité 28/10/2026 : persistance et application de chaque option (texte, daltonisme, flashs, secousses,
## mouvement réduit, vibrations, maintien des infobulles, télégraphes renforcés) + palette sémantique.
## godot --headless --path game res://tests/accessibility_test.tscn  -> RESULT: OK
## Fichier de réglages injecté : la config réelle du joueur n'est ni lue ni écrite.

const TEST_CFG := "user://test_accessibility.cfg"
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	Platform.set_input_mode(Platform.InputMode.KBM)
	GameSettings.cfg_path = TEST_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	GameSettings.reset_all(get_tree())
	CvdPalette.clear_cache()

	# --- Défauts
	_check(GameSettings.text_scale_index() == 0 and is_equal_approx(GameSettings.text_scale(), 1.0), "défaut : texte 100 %")
	_check(GameSettings.tooltip_hold_index() == 0 and GameSettings.tooltip_hold() == 0.0, "défaut : infobulle au relâchement")
	_check(GameSettings.colorblind() == 0 and not GameSettings.strong_telegraphs(), "défaut : pas de daltonisme, télégraphes normaux")
	_check(GameSettings.haptics(), "défaut : vibrations actives")

	# --- Persistance : écriture dans le fichier injecté puis relecture
	GameSettings.set_text_scale_index(2)
	GameSettings.set_tooltip_hold_index(2)
	GameSettings.set_colorblind(2)
	GameSettings.set_strong_telegraphs(true)
	GameSettings.set_flashes(1)
	GameSettings.set_shake(0.0)
	GameSettings.set_reduce_motion(true)
	GameSettings.set_haptics(false)
	var cf := ConfigFile.new()
	cf.load(TEST_CFG)
	_check(int(cf.get_value("accessibility", "text_scale", -1)) == 2, "persistance : text_scale écrit")
	_check(int(cf.get_value("accessibility", "tooltip_hold", -1)) == 2, "persistance : tooltip_hold écrit")
	_check(int(cf.get_value("graphics", "colorblind", -1)) == 2, "persistance : colorblind écrit")
	_check(bool(cf.get_value("accessibility", "strong_telegraphs", false)), "persistance : télégraphes renforcés écrit")
	_check(int(cf.get_value("graphics", "flashes", -1)) == 1, "persistance : flashs écrit")
	_check(is_zero_approx(float(cf.get_value("gameplay", "shake", 1.0))), "persistance : secousses 0 écrit")
	_check(bool(cf.get_value("gameplay", "reduce_motion", false)), "persistance : mouvement réduit écrit")
	_check(not bool(cf.get_value("gameplay", "haptics", true)), "persistance : vibrations coupées écrit")
	# relecture à froid (caches oubliés)
	GameSettings._ts_path = "<unset>"
	GameSettings._cache_path = "<unset>"
	_check(GameSettings.text_scale_index() == 2 and is_equal_approx(GameSettings.text_scale(), 1.3), "relecture : texte 130 %")
	_check(is_equal_approx(GameSettings.tooltip_hold(), 6.0), "relecture : maintien 6 s")
	_check(GameSettings.shake_scale() == 0.0 and GameSettings.reduce_motion() and not GameSettings.hitstop_enabled(), "relecture : secousses 0, mouvement réduit, pas d'arrêt sur image")
	_check(Quality.flashes_level == 1 and is_equal_approx(GameSettings.flash_scale(), 0.25), "flashs réduits -> Quality.flashes_level 1")
	_check(GameSettings.strong_telegraphs(), "relecture : télégraphes renforcés")

	# --- Texte : thème et surcharge de police
	Accessibility.apply_text_scale()
	var th := UiTheme.theme()
	_check(th.get_font_size(&"font_size", &"Label") == roundi(UiTheme.FONT_BODY * 1.3), "texte 130 % : thème Label")
	_check(th.get_font_size(&"font_size", &"Button") == roundi(UiTheme.FONT_BUTTON * 1.3), "texte 130 % : thème Button")
	var layer := CanvasLayer.new()
	var lab := Label.new()
	lab.add_theme_font_size_override("font_size", 40)
	layer.add_child(lab)
	add_child(layer)
	var world := Node2D.new()
	var wlab := Label.new()
	wlab.add_theme_font_size_override("font_size", 40)
	world.add_child(wlab)
	add_child(world)
	await _frames(3)
	_check(lab.get_theme_font_size("font_size") == 52, "texte 130 %% : Label d'interface 40 -> 52 (%d)" % lab.get_theme_font_size("font_size"))
	_check(wlab.get_theme_font_size("font_size") == 40, "texte du monde non touché")
	lab.add_theme_font_size_override("font_size", 30) # le code repose une taille (mise en page du HUD)
	Accessibility.apply_text_scale()
	_check(lab.get_theme_font_size("font_size") == 39, "surcharge reposée par le code : 30 -> 39, sans double échelle (%d)" % lab.get_theme_font_size("font_size"))
	GameSettings.set_text_scale_index(1)
	Accessibility.apply_text_scale()
	_check(lab.get_theme_font_size("font_size") == roundi(30 * 1.15), "texte 115 %% : 30 -> 35 (%d)" % lab.get_theme_font_size("font_size"))
	GameSettings.set_text_scale_index(0)
	Accessibility.apply_text_scale()
	_check(lab.get_theme_font_size("font_size") == 30, "retour à 100 % : taille d'origine restituée")
	_check(th.get_font_size(&"font_size", &"Label") == UiTheme.FONT_BODY, "retour à 100 % : thème d'origine")
	layer.queue_free()
	world.queue_free()

	# --- Daltonisme : palette sémantique
	for m in 4:
		Palette.override_mode = m
		var set: Array = []
		for q in Palette.RARITY_ORDER:
			set.append(Palette.rarity(q))
		# raretés distinguables entre elles dans la vue simulée du mode (les formes et les mots complètent)
		var worst := 999.0
		for i in 4:
			for j in range(i + 1, 4):
				worst = minf(worst, CvdPalette.delta_e(set[i], set[j], m))
		_check(worst >= 15.0, "mode %d : raretés distinctes entre elles (ΔE min %.1f)" % [m, worst])
	Palette.override_mode = 1
	_check(Palette.rarity(&"legendaire") != Palette.RARITY_NONE[&"legendaire"] and Palette.rarity(&"rare") != Palette.RARITY_NONE[&"rare"], "deutéranopie : palette de raretés remappée")
	_check(Palette.rank_suffix(&"rare") == " · 3/4" and Palette.rank_corner(&"legendaire", 8) == 0 and Palette.rank_corner(&"commun", 8) == 18, "daltonisme : rang et forme redondants")
	_check(Palette.rank_border(&"legendaire") > Palette.rank_border(&"commun"), "daltonisme : bordure plus épaisse avec la rareté")
	_check(Palette.telegraph_tint() == Palette.TEL_RG and Palette.hp() == Palette.HP_RG and Palette.hp_low() == Palette.HP_LOW_RG, "deutéranopie : télégraphes orange, PV bleu / orange")
	var de := CvdPalette.delta_e(Palette.hp(), Palette.hp_low(), CvdPalette.DEUTAN)
	_check(de >= 20.0, "deutéranopie : PV et PV bas distincts (ΔE %.1f)" % de)
	Palette.override_mode = 0
	_check(Palette.rank_suffix(&"rare") == "" and Palette.rank_corner(&"rare", 8) == 8 and Palette.rarity(&"rare") == Palette.RARITY_NONE[&"rare"], "mode aucun : couleurs et formes d'origine")
	_check(is_equal_approx(Palette.telegraph(Color(0.95, 0.1, 0.1, 0.28)).a, 0.28), "télégraphe : alpha conservé")
	Palette.override_mode = -1

	# --- Palette.mode() suit le réglage courant (protanopie écrite plus haut)
	CvdPalette.clear_cache()
	_check(Palette.mode() == 2, "Palette.mode() suit le réglage daltonien (protanopie)")
	_check(ItemBar.quality_backing(&"legendaire").get_theme_stylebox("panel") is StyleBoxFlat, "fond de rareté construit en mode daltonien")

	# --- Réinitialiser : tout revient aux défauts
	GameSettings.reset_all(get_tree())
	_check(GameSettings.text_scale_index() == 0 and GameSettings.tooltip_hold_index() == 0 and GameSettings.colorblind() == 0, "réinitialiser : texte, infobulle, daltonisme par défaut")
	_check(not GameSettings.strong_telegraphs() and GameSettings.shake_scale() == 1.0 and not GameSettings.reduce_motion(), "réinitialiser : télégraphes, secousses, mouvement par défaut")

	# --- Panneau de réglages : les nouvelles lignes existent
	var sp := SettingsPanel.new()
	add_child(sp)
	await _frames(2)
	var labels := sp.row_labels()
	_check("Taille du texte" in labels and "Maintien des infobulles" in labels and "Mode daltonien" in labels, "panneau : lignes Accessibilité présentes")
	sp.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	CvdPalette.clear_cache()
	GameSettings.cfg_path = GameSettings.PATH
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
