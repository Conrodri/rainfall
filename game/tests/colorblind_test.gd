extends Node
## Mode daltonien réel + doublage de la couleur par la forme (lot UX A11y-L1 + D).
## - ΔE2000 des palettes de statuts en SIMULATION (Machado 2009, sévérité 1,0) : >= 20 dans le mode visé ;
##   dégât subi / critique >= 20 dans les 4 vues ; dégât subi / éléments >= 12 dans la vue du mode.
## - Formes : motifs d'aura distincts, pictogrammes de statut distincts (silhouettes), « − » + contour des dégâts subis.
## - Réglage lu en lecture seule (fichier injecté), chiffres hors des zones réservées du HUD.
## godot --headless --path game res://tests/colorblind_test.tscn

const MIN_STATUS_DE := 20.0
const MIN_HURT_CRIT_DE := 20.0
const MIN_HURT_ELEMENT_DE := 12.0
const CFG := "user://_colorblind_test.cfg"

var _fails := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _min_pair(cols: Dictionary, view: int) -> Array:
	var keys := cols.keys()
	var best: Array = [INF, &"", &""]
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var d := CvdPalette.delta_e(cols[keys[i]], cols[keys[j]], view)
			if d < float(best[0]):
				best = [d, keys[i], keys[j]]
	return best


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	CvdPalette.override_mode = -1
	print("Outil ΔE2000 (jeu de référence Sharma 2005)")
	var de := CvdPalette.delta_e2000(Vector3(50.0, 2.6772, -79.7751), Vector3(50.0, 0.0, -82.7485))
	_check("ΔE2000 de référence = 2,0425 (%.4f)" % de, absf(de - 2.0425) < 0.001)
	_check("ΔE d'une couleur avec elle-même = 0", CvdPalette.delta_e(Color.RED, Color.RED, CvdPalette.DEUTAN) < 0.001)
	_check("rouge / vert très différents en vision normale", CvdPalette.delta_e(Color.RED, Color.GREEN, CvdPalette.NONE) > 50.0)

	print("Le problème (audit A-02) : palette d'origine en simulation")
	var base := {&"burn": HpBarStyle.STATUS_COL[&"burn"], &"poison": HpBarStyle.STATUS_COL[&"poison"], &"frost": HpBarStyle.STATUS_COL[&"frost"]}
	var d0 := _min_pair(base, CvdPalette.DEUTAN)
	_check("brûlure / poison d'origine se confondent en deutéranopie (ΔE %.1f < 10)" % d0[0], float(d0[0]) < 10.0)
	_check("mode « aucun » : couleurs d'origine inchangées", CvdPalette.status(&"burn", 0).is_equal_approx(base[&"burn"])
			and CvdPalette.status(&"poison", 0).is_equal_approx(base[&"poison"]))

	print("Palettes de statuts par mode (cible ΔE2000 >= %.0f)" % MIN_STATUS_DE)
	for m in [CvdPalette.DEUTAN, CvdPalette.PROTAN]:
		for view in [CvdPalette.DEUTAN, CvdPalette.PROTAN]:
			var r := _min_pair(CvdPalette.status_set(m), view)
			_check("mode %d vu en %d : min ΔE %.1f (%s / %s)" % [m, view, r[0], r[1], r[2]], float(r[0]) >= MIN_STATUS_DE)
	var rt := _min_pair(CvdPalette.status_set(CvdPalette.TRITAN), CvdPalette.TRITAN)
	_check("tritanopie vue en tritanopie : min ΔE %.1f (%s / %s)" % [rt[0], rt[1], rt[2]], float(rt[0]) >= MIN_STATUS_DE)
	for m in [CvdPalette.DEUTAN, CvdPalette.TRITAN]:
		var rn := _min_pair(CvdPalette.status_set(m), CvdPalette.NONE)
		_check("palette %d en vision normale : min ΔE %.1f >= 20" % [m, rn[0]], float(rn[0]) >= MIN_STATUS_DE)
	_check("les palettes alternatives diffèrent de l'originale", not CvdPalette.status(&"poison", 1).is_equal_approx(CvdPalette.status(&"poison", 0))
			and not CvdPalette.status(&"burn", 3).is_equal_approx(CvdPalette.status(&"burn", 0)))
	_check("deutéranopie et protanopie partagent la palette", CvdPalette.status(&"poison", 1).is_equal_approx(CvdPalette.status(&"poison", 2)))

	print("Chiffres de dégâts : dégât subi / critique / éléments")
	for view in [CvdPalette.NONE, CvdPalette.DEUTAN, CvdPalette.PROTAN, CvdPalette.TRITAN]:
		var d := CvdPalette.delta_e(DamageNumbers.PLAYER_HURT_COLOR, DamageNumbers.CRIT_COLOR, view)
		_check("dégât subi / critique, vue %d : ΔE %.1f >= 20" % [view, d], d >= MIN_HURT_CRIT_DE)
	for m in 4:
		var cols := {}
		for el in [&"fire", &"ice", &"lightning", &"poison"]:
			cols[el] = CvdPalette.element(el, m)
		cols[&"base"] = DamageNumbers.BASE_COLOR
		var worst := INF
		var who: StringName = &""
		for k in cols:
			var d2 := CvdPalette.delta_e(DamageNumbers.PLAYER_HURT_COLOR, cols[k], m)
			if d2 < worst:
				worst = d2
				who = k
		_check("mode %d : dégât subi / éléments, ΔE min %.1f (%s) >= %.0f" % [m, worst, who, MIN_HURT_ELEMENT_DE], worst >= MIN_HURT_ELEMENT_DE)

	print("Réglage lu en lecture seule (fichier injecté)")
	var saved := GameSettings.cfg_path
	GameSettings.cfg_path = CFG
	var cf := ConfigFile.new()
	cf.set_value("graphics", "colorblind", 2)
	cf.save(CFG)
	CvdPalette.clear_cache()
	_check("mode lu depuis GameSettings = 2", CvdPalette.mode() == 2)
	_check("statut selon le mode lu", CvdPalette.status(&"poison").is_equal_approx(CvdPalette.status(&"poison", 2)))
	cf.set_value("graphics", "colorblind", 0)
	cf.save(CFG)
	CvdPalette.clear_cache()
	_check("retour au mode 0 après relecture", CvdPalette.mode() == 0)
	GameSettings.cfg_path = saved
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	CvdPalette.clear_cache()
	CvdPalette.override_mode = 0

	print("Formes : motifs d'aura et pictogrammes")
	var pats := {}
	for a in [&"burn", &"poison", &"slow"]:
		pats[EnemyAura.pattern_of(a)] = true
	_check("trois affixes, trois motifs", pats.size() == 3)
	_check("couleur d'aura suit le mode", not CvdPalette.affix(&"poison", 1).is_equal_approx(CvdPalette.affix(&"poison", 0)))
	var atlas := StatusPictos.atlas().get_image()
	_check("atlas de pictogrammes 5 × 16 px", atlas.get_width() == 80 and atlas.get_height() == 16)
	var masks: Array = []
	for i in StatusPictos.IDS.size():
		var m := PackedByteArray()
		for y in 16:
			for x in 16:
				m.append(1 if atlas.get_pixel(i * 16 + x, y).a > 0.5 else 0)
		masks.append(m)
		var on := 0
		for v in m:
			on += v
		_check("pictogramme %s : %d px opaques" % [StatusPictos.IDS[i], on], on >= 40 and on <= 220)
	var min_diff := 999
	for i in masks.size():
		for j in range(i + 1, masks.size()):
			var diff := 0
			for k in 256:
				if masks[i][k] != masks[j][k]:
					diff += 1
			min_diff = mini(min_diff, diff)
	_check("silhouettes distinctes deux à deux (>= 30 px de différence, min %d)" % min_diff, min_diff >= 30)

	print("Chiffres de dégâts : « − », contour, taille, zones réservées")
	var dn := DamageNumbers.new()
	dn.scale_override = 0.8
	add_child(dn)
	await get_tree().process_frame
	_check("taille plancher 20 px en « Petits » (%d)" % dn.font_px(false, false), dn.font_px(false, false) >= 20 and dn.font_px(false, true) >= 20)
	dn.scale_override = 1.0
	_check("« Normaux » = 24 px", dn.font_px(false, false) == 24)
	dn.scale_override = 1.3
	_check("« Grands » > Normaux", dn.font_px(false, false) > 24)
	dn.scale_override = 1.0
	dn.show_number(Vector2(300, 400), 12.0, DamageNumbers.PLAYER_HURT_COLOR)
	var lh: Label = dn._labels[0]
	_check("dégât subi : préfixe « − » (%s)" % lh.text, lh.text.length() == 3 and lh.text.ends_with("12"))
	_check("dégât subi : contour épais de 4 px, clair", lh.get_theme_constant("outline_size") == 4 and lh.get_theme_color("font_outline_color").v > 0.7)
	dn.show_number(Vector2(900, 400), 12.0, DamageNumbers.CRIT_COLOR, true)
	var lc: Label = dn._labels[1]
	_check("critique : pas de signe, contour sombre", lc.text.ends_with("12") and lc.text.length() <= 3 and not lc.text.begins_with("-")
			and not lc.text.begins_with(DamageNumbers.MINUS) and lc.get_theme_color("font_outline_color").v < 0.3)
	dn.show_number(Vector2(1500, 400), 7.0, Color(0.5, 0.85, 1.0))
	var ln: Label = dn._labels[2]
	_check("dégât infligé : pas de signe", ln.text == "7")
	# zones réservées : un chiffre apparu dans le HUD est décalé hors de la zone
	var reserved := Rect2(1400, 600, 400, 500) # écran (le nœud écrase y par 2 : local y 300-550)
	dn.hud_provider = func() -> Array[Rect2]: return [reserved]
	dn._rects_frame = -1
	dn.show_number(Vector2(1500, 380), 99.0, Color(0.9, 0.9, 0.2))
	var org: Vector2 = dn._origin[3]
	var xf := dn.get_global_transform_with_canvas()
	var k := xf.get_scale().abs()
	var sz := (dn._labels[3] as Label).get_minimum_size()
	var box := Rect2(xf * (org + Vector2(-sz.x * 0.5, -DamageNumbers.RISE)), Vector2(sz.x, sz.y + DamageNumbers.RISE) * k)
	_check("chiffre décalé hors de la zone réservée du HUD (%s / %s)" % [box, reserved], not reserved.intersects(box) and org != Vector2(1500, 380))
	dn.hud_provider = Callable()
	dn._rects_frame = -1
	dn.show_number(Vector2(120, 380), 5.0, Color(0.1, 0.9, 0.9))
	_check("sans HUD ni fonction : aucun décalage", (dn._origin[4] as Vector2).is_equal_approx(Vector2(120, 380)))
	dn.queue_free()

	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)
