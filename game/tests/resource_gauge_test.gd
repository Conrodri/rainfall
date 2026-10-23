extends Node
## Jauges de kit (audit HUD lot C) : contraste >= 3:1 (remplissage / fond, pastille pleine / fond), état plein, polices
## minimales PC / mobile, ressource distincte des PV par la forme (épaisseur, écart), PV overhead verts.
## godot --headless --path game res://tests/resource_gauge_test.tscn

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	Platform.set_input_mode(Platform.InputMode.KBM)
	# --- Contraste : chaque accent de kit relevé à >= 3:1 sur le fond de jauge
	var accents := {
		"Avare": Color("#E0B040"), "Taliant": Color("#CDEB6E"), "Vigie": Color("#FF3A4F"), "Averse": Color("#4FA3E0"),
		"Rainette": RainetteKit.ACCENT, "Tocsin": Color("#B35A1F"), "Bourbe": Color("#8DDBA8"), "sombre": Color("#301005"),
	}
	for n: String in accents:
		var c := ResourceGauge.lift(accents[n] as Color)
		_check(ResourceGauge.contrast(c, ResourceGauge.BG) >= ResourceGauge.MIN_CONTRAST - 0.01, "%s : remplissage / fond = %.2f:1" % [n, ResourceGauge.contrast(c, ResourceGauge.BG)])
	var dark := Color("#6A2E0E") # pastille Tocsin sombre
	var pf := ResourceGauge.lift(Color(minf(dark.r * 1.3, 1.0), minf(dark.g * 1.3, 1.0), minf(dark.b * 1.3, 1.0)))
	_check(ResourceGauge.contrast(pf, ResourceGauge.BG) >= 3.0, "Tocsin : pastille pleine / vide >= 3:1 (%.2f)" % ResourceGauge.contrast(pf, ResourceGauge.BG))
	_check(ResourceGauge.contrast(OverheadBars.COL_HP, HpBarStyle.COL_BG) >= 3.0, "PV overhead verts / fond >= 3:1")
	_check(OverheadBars.COL_HP.g > OverheadBars.COL_HP.r and OverheadBars.COL_HP.g > OverheadBars.COL_HP.b, "PV overhead = vert")
	# --- Forme : ressource plus fine que les PV, écart 3 px
	_check(OverheadBars.RES_H < OverheadBars.HP_H * 0.5 and OverheadBars.HP_H == 10.0 and OverheadBars.RES_H == 4.0, "ressource 4 px < moitié des PV 10 px")
	_check(OverheadBars.GAP == 3.0, "écart PV / ressource 3 px")
	# --- État plein
	_check(ResourceGauge.is_full({"ratio": 1.0}) and not ResourceGauge.is_full({"ratio": 0.5}), "jauge continue pleine détectée")
	_check(ResourceGauge.is_full({"pips": 5, "filled": 5}) and not ResourceGauge.is_full({"pips": 5, "filled": 4}), "pastilles toutes pleines détectées")
	_check(not ResourceGauge.is_full({"ratio": 1.0, "blocked": true}), "bloquée : jamais pleine")
	_check(ResourceGauge.pulse_alpha(0.25) <= 0.7001 and ResourceGauge.pulse_alpha(0.75) >= 0.3499, "pulsation 0,35 -> 0,7")
	# --- Tailles : PC / mobile
	var g := ResourceGauge.new()
	add_child(g)
	g.apply_scale(1.0)
	_check(g.custom_minimum_size == ResourceGauge.BASE_SIZE, "PC : 250 x 76")
	_check(ResourceGauge.min_font() == 18, "PC : police min 18")
	Platform.mobile_preview = true
	if Platform.is_mobile():
		g.apply_scale(1.0)
		_check(g.custom_minimum_size == ResourceGauge.MOBILE_SIZE, "mobile : 330 x 96")
		_check(ResourceGauge.min_font() == 26 and AverseWaterText.font_px() == 26, "mobile : polices >= 26")
	else:
		print("skip mobile (Platform.is_mobile() faux sur PC : tailles mobiles à vérifier par capture)")
	Platform.mobile_preview = false
	_check(AverseWaterText.font_px() == 22, "PC : « +N » d'Averse 22 px")
	# --- Rendu sans erreur (états variés)
	for st: Dictionary in [{"label": "Bourse", "text": "+70 %", "ratio": 1.0, "color": Color("#E0B040")},
			{"label": "Membres", "pips": 5, "filled": 3, "ratio": 0.4, "color": Color("#B35A1F")},
			{"label": "Aiguisage", "ratio": 0.5, "mark": 0.5, "color": Color("#CDEB6E"), "regen": 1.3}]:
		g.set_state(st)
		await get_tree().process_frame
	g.queue_free()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
