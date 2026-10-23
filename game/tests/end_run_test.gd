extends Node
## Lot B : récap de fin de run (EndRunScreen, docs/Design_Menus.md §3.10).

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _cancel() -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await _frames(1)


func _all_text(n: Node) -> String:
	var out := ""
	for c in n.get_children():
		if c is Label or c is Button:
			out += c.text + "\n"
		out += _all_text(c)
	return out


func _ready() -> void:
	get_tree().paused = true # le récap tourne arbre en pause
	var info := {
		"victory": true, "reason": &"victory", "character_name": "Ardent", "mode": &"moyen", "stage": 3,
		"active_time_s": 642.0, "level": 18, "pillars": 7, "kills": 1204, "items": 27, "gold": 980,
		"rubies": 87, "unlocks": [&"mode:difficile"],
		"next_objective": {"title": "Rictus", "text": "Tuer 200 monstres à moins de 2 u de soi.", "progress": 0.4},
	}
	var s := EndRunScreen.create(info)
	add_child(s)
	await _frames(2)
	_check(s.get_script() == EndRunScreen and s.layer == RunScreens.LAYER_SCREENS, "scène end_run.tscn instanciée")
	var txt := _all_text(s)
	_check(txt.contains("Victoire !"), "titre victoire")
	_check(txt.contains("Ardent · Moyen · Étage 3 · 10:42 · niveau 18"), "ligne d'infos")
	_check(txt.contains("1 204") and txt.contains("Monstres") and txt.contains("Piliers") and txt.contains("Objets") and txt.contains("Or restant") and txt.contains("980"), "4 tuiles (monstres 1 204)")
	_check(txt.contains("Mode Difficile débloqué !"), "ligne de déblocage")
	_check(not txt.contains("×"), "pas de multiplicateur en Moyen")
	# M-F : détail des rubis (642 s = 10,7 min -> 12 ; 7 piliers -> 56 ; victoire 25 ; 980 or -> 1) et prochain objectif
	_check(EndRunScreen.ruby_breakdown(info) == "Temps +12 · Piliers +56 · Victoire +25 · Or +1", "détail des rubis : " + EndRunScreen.ruby_breakdown(info))
	_check(Balance.run_rubies(642.0 / 60.0, &"moyen", 7, true, 980.0) == 12 + 56 + 25 + 1, "détail = Balance.run_rubies")
	_check(EndRunScreen.ruby_breakdown({"mode": &"facile", "active_time_s": 600.0}) == "Temps +9", "détail Facile ×0,8, termes nuls omis")
	_check(txt.contains("Temps +12 · Piliers +56"), "ligne de détail affichée")
	_check(txt.contains("Prochain objectif : Rictus") and txt.contains("Tuer 200 monstres"), "prochain objectif affiché")
	_check(s.find_child("NextObjective", true, false) != null and s.find_child("NextObjective", true, false).get_child(2) is ProgressBar, "barre d'objectif")
	var rl := s.find_child("RubyDetail", true, false) as Label
	# 26 px × UiTheme.scale() (réduction des petites fenêtres PC), jamais sous le plancher HudMetrics (18 PC / 26 mobile)
	var want_px := maxi(int(26 * UiTheme.scale()), HudMetrics.floor_px())
	var got_px := rl.get_theme_font_size("font_size") if rl != null else 0
	_check(got_px == want_px and got_px >= HudMetrics.floor_px(), "détail des rubis en %d px (attendu %d, plancher %d)" % [got_px, want_px, HudMetrics.floor_px()])
	_check(EndRunScreen.next_objective(null, []).is_empty(), "next_objective sans profil ni persos = vide")
	_check(" ".join(s.texts()).contains("Rubis gagnés : 87"), "texts() : rubis finaux")
	_check(s.animating and s.shown_rubies < 87, "compteur en cours d'animation (%d)" % s.shown_rubies)
	var cont := [0]
	var rep := [0]
	s.continue_pressed.connect(func() -> void: cont[0] += 1)
	s.replay_pressed.connect(func() -> void: rep[0] += 1)
	await _cancel()
	_check(cont[0] == 0, "Échap ignoré pendant l'animation")
	await get_tree().create_timer(1.4, true, false, true).timeout
	_check(not s.animating and s.shown_rubies == 87, "compteur arrivé à 87")
	_check(s._ticks > 0 and s._ticks <= EndRunScreen.MAX_TICKS, "tics pickup.ruby (%d, max 12)" % s._ticks)
	for b in s._buttons:
		_check((b as Button).get_combined_minimum_size().y >= 88.0, "bouton « %s » >= 88 px" % b.text)
	_check(s._buttons[0].text == "Rejouer" and s._buttons[1].text == "Continuer", "Rejouer à gauche, Continuer à droite")
	_check(get_viewport().gui_get_focus_owner() == s._buttons[1], "focus sur Continuer")
	await _cancel()
	_check(cont[0] == 1, "Échap = Continuer après l'animation")
	s.press(0)
	_check(rep[0] == 1, "Rejouer -> replay_pressed")
	s.queue_free()
	await _frames(1)

	var s2 := EndRunScreen.create({"victory": false, "reason": &"abandon", "mode": &"difficile", "rubies": 0, "kills": 5})
	add_child(s2)
	await _frames(2)
	var t2 := _all_text(s2)
	_check(t2.contains("Run abandonnée") and t2.contains("(×1,3 Difficile)") and not t2.contains("débloqué"), "abandon Difficile : titre, ×1,3, pas de déblocage")
	s2.queue_free()
	var s3 := EndRunScreen.create({"victory": false, "reason": &"death", "mode": &"facile"})
	add_child(s3)
	await _frames(2)
	_check(_all_text(s3).contains("Vous êtes tombé") and _all_text(s3).contains("(×0,8 Facile)"), "mort Facile : titre, ×0,8")

	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().paused = false
	get_tree().quit(0 if _fails == 0 else 1)
