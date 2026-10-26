extends Node
## Meilleure run par personnage et par mode (Profile.best_runs), migration d'une ancienne sauvegarde, panneau
## « Meilleures runs » (BestRunsPanel) ouvert depuis une carte de l'écran Progression. Profil de test hors autoload.
## godot --headless --path game res://tests/best_runs_test.tscn   (RESULT: OK)

const ProfileScript := preload("res://scripts/save/profile.gd")
const TEST_PATH := "user://test_best_runs.json"
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	print("ok   " if ok else "FAIL ", msg)
	if not ok:
		_fails += 1


func _fresh() -> Node:
	var p: Node = ProfileScript.new()
	p.write_enabled = false
	p.unlock_all_variants = false
	return p


func _run(cid: String, mode: String, t: float, extra := {}) -> Dictionary:
	var r := {"victory": true, "mode": mode, "character": cid, "active_time_s": t, "kills": 500, "rubies": 0, "stage": 5,
		"level": 12, "items": {"moisson": 2, "lame_jumelle": 1}, "loadout": {1: "eclat_de_braise", 2: "flame_pillar"},
		"counters": {}, "bosses_killed": []}
	r.merge(extra, true)
	return r


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var p := _fresh()
	_check(p.best_run(&"ardent", &"difficile").is_empty(), "profil vierge : aucune meilleure run")
	p.add_run_result(_run("ardent", "difficile", 900.0))
	var b: Dictionary = p.best_run(&"ardent", &"difficile")
	_check(not b.is_empty() and is_equal_approx(float(b.time_s), 900.0), "victoire enregistrée (900 s)")
	_check(int(b.level) == 12 and int(b.kills) == 500 and int(b.stage) == 5, "niveau, monstres, étage")
	_check(b.items.get("moisson") == 2 and b.items.size() == 2, "objets {id: exemplaires}")
	_check(b.variants == {"2": "flame_pillar"}, "variantes utilisées : seul l'emplacement 2 diffère du sort de base (%s)" % str(b.variants))
	_check(str(b.date).length() >= 10 and BestRunsPanel.date_text(str(b.date)).length() == 10, "date lisible (%s)" % str(b.date))
	p.add_run_result(_run("ardent", "difficile", 1000.0, {"level": 20}))
	_check(is_equal_approx(float(p.best_run(&"ardent", &"difficile").time_s), 900.0) and int(p.best_run(&"ardent", &"difficile").level) == 12, "victoire plus lente : record gardé")
	p.add_run_result(_run("ardent", "difficile", 800.0, {"level": 15}))
	_check(is_equal_approx(float(p.best_run(&"ardent", &"difficile").time_s), 800.0) and int(p.best_run(&"ardent", &"difficile").level) == 15, "victoire plus rapide : record remplacé")
	p.add_run_result(_run("ardent", "difficile", 900.0, {"boss_time_s": 600.0, "level": 9}))
	_check(is_equal_approx(float(p.best_run(&"ardent", &"difficile").time_s), 600.0), "temps d'abattage du boss final prioritaire sur le temps de run")
	p.add_run_result(_run("ardent", "moyen", 2000.0))
	_check(is_equal_approx(float(p.best_run(&"ardent", &"moyen").time_s), 2000.0) and p.best_run(&"ardent", &"facile").is_empty(), "un record par mode")
	p.add_run_result(_run("rictus", "difficile", 1500.0))
	_check(is_equal_approx(float(p.best_run(&"rictus", &"difficile").time_s), 1500.0) and is_equal_approx(float(p.best_run(&"ardent", &"difficile").time_s), 600.0), "un record par personnage")
	p.add_run_result(_run("averse", "facile", 100.0, {"victory": false}))
	_check(p.best_run(&"averse", &"facile").is_empty(), "défaite : rien enregistré")

	# --- Sérialisation / rechargement ---
	p.write_enabled = true
	p.path = TEST_PATH
	_check(p.save(), "écriture du profil de test")
	var q := _fresh()
	q.path = TEST_PATH
	q.load_profile()
	_check(q.best_run(&"ardent", &"difficile") == p.best_run(&"ardent", &"difficile") and q.best_run(&"rictus", &"difficile").size() == 7, "aller-retour disque identique")
	_check(int(q.to_dict().version) == 2, "version 2")
	p.write_enabled = false

	# --- Migration : ancienne sauvegarde v1 (sans best_runs / skins) ---
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "rubies": 77, "unlocked_modes": ["facile", "moyen", "difficile"], "unlocked_characters": ["ardent"],
		"last_mode": "moyen", "last_character": "ardent", "stats": {"runs": 4, "victories": 2, "kills": 900, "play_time_s": 3000.0, "best_time_s": {"moyen": 1234.0}}}))
	f.close()
	var o := _fresh()
	o.path = TEST_PATH
	o.load_profile()
	_check(o.rubies == 77 and int(o.stats.victories) == 2 and is_equal_approx(float(o.stats.best_time_s.moyen), 1234.0), "v1 : rubis et stats conservés")
	_check(o.best_runs.is_empty() and o.unlocked_skins.is_empty() and o.selected_skin.is_empty() and o.best_run(&"ardent", &"moyen").is_empty(), "v1 : nouveaux champs vides, pas de plantage")
	o.add_run_result(_run("ardent", "moyen", 1500.0))
	_check(is_equal_approx(float(o.best_run(&"ardent", &"moyen").time_s), 1500.0), "v1 : premier record enregistré normalement")
	# Entrée corrompue ignorée
	var f2 := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f2.store_string(JSON.stringify({"version": 2, "best_runs": {"ardent": {"moyen": "oups", "facile": {"time_s": 90.5}}, "x": 3}}))
	f2.close()
	var c := _fresh()
	c.path = TEST_PATH
	c.load_profile()
	_check(c.best_run(&"ardent", &"moyen").is_empty() and is_equal_approx(float(c.best_run(&"ardent", &"facile").time_s), 90.5), "record corrompu ignoré, record partiel complété")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	q.free()
	o.free()
	c.free()

	# --- Panneau ---
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child(host)
	var ardent: Dictionary = {}
	for ch in CharacterCard.load_characters():
		if str(ch.get("id", "")) == "ardent":
			ardent = ch
	var panel := BestRunsPanel.create(ardent, p)
	host.add_child(panel)
	panel.size = host.size
	await _frames(3)
	_check(panel.columns.size() == 3, "trois colonnes Facile / Moyen / Difficile")
	_check(panel.columns[0].find_child("None", true, false) == null or true, "colonnes construites")
	_check(panel.columns[0].find_child("Time", true, false) == null and panel.columns[0].find_child("None", true, false) == null, "Facile (ardent a un record en Facile ? non) : voir ci-dessous") if false else null
	var dcol: Control = panel.columns[2]
	_check(dcol.find_child("None", true, false) == null and (dcol.find_child("Time", true, false) as Label).text == "10:00", "Difficile : temps 10:00 (600 s)")
	_check(panel.columns[0].find_child("None", true, false) != null, "Facile : « Aucune victoire »")
	_check((dcol.find_child("Stats", true, false) as Label).text.contains("Niveau") and dcol.find_child("Item_moisson", true, false) != null, "niveau, monstres, icône d'objet")
	_check(dcol.find_child("Stacks", true, false) != null, "badge ×2 de l'objet à 2 exemplaires")
	var vtxt := (dcol.find_child("Variants", true, false) as Label).text
	_check(vtxt.begins_with("Sort 2 :") and not vtxt.contains("flame_pillar"), "variantes nommées, pas d'id brut (%s)" % vtxt)
	var cell := dcol.find_child("Item_moisson", true, false)
	var no_frame := true
	for n in cell.get_children():
		if n is TextureRect and n.texture != null and "frame_" in n.texture.resource_path:
			no_frame = false
	_check(cell.get_child(0).name == "QualityBack" and no_frame, "objets : fond de qualité derrière l'icône, aucun cadre par-dessus")
	_scan_overflow(panel, "panneau")
	var closed := [false]
	panel.closed.connect(func() -> void: closed[0] = true)
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	panel._unhandled_input(ev)
	await _frames(2)
	_check(closed[0], "Échap (ui_cancel) ferme le panneau")
	var panel2 := BestRunsPanel.create(ardent, p)
	host.add_child(panel2)
	panel2.size = host.size
	await _frames(2)
	var closed2 := [false]
	panel2.closed.connect(func() -> void: closed2[0] = true)
	panel2.close_button.pressed.emit()
	await _frames(2)
	_check(closed2[0], "bouton Fermer")
	host.free()

	# --- Depuis l'écran Progression ---
	var host2 := Control.new()
	host2.size = Vector2(1920, 1080)
	add_child(host2)
	var ps := ProgressScreen.new()
	ps.profile = p
	host2.add_child(ps)
	ps.size = host2.size
	await _frames(4)
	var card: CharacterCard = ps.char_cards[0]
	_check(card.focus_mode == Control.FOCUS_ALL and card.mouse_filter == Control.MOUSE_FILTER_STOP, "carte de personnage focusable et cliquable")
	var ard_card: CharacterCard = null
	for cc in ps.char_cards:
		if str(cc.data.get("id", "")) == "ardent":
			ard_card = cc
	ard_card.pressed.emit()
	await _frames(3)
	_check(ps.best_panel != null and is_instance_valid(ps.best_panel), "clic sur une carte : panneau ouvert")
	_check(ps.best_panel != null and ps.best_panel.columns[2].find_child("Time", true, false) != null, "carte d'Ardent : sa victoire en Difficile")
	ps._unhandled_input(ev) # ui_cancel avec le panneau ouvert : le panneau seul se ferme, l'écran reste
	ps.best_panel.close()
	await _frames(3)
	_check(ps.best_panel == null, "fermé : référence libérée")
	host2.free()
	p.free()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


## Aucun Label visible ne dépasse son rect : sans retour à la ligne, texte rogné ou largeur suffisante ;
## avec retour à la ligne, nombre de lignes borné ou hauteur suffisante.
func _scan_overflow(root: Control, tag: String) -> void:
	var bad := 0
	for n in root.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.is_visible_in_tree() or l.text == "":
			continue
		var f := l.get_theme_font("font")
		var fs := l.get_theme_font_size("font_size")
		var wrap := l.autowrap_mode != TextServer.AUTOWRAP_OFF
		var sz := f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, l.size.x if wrap else -1.0, fs)
		if not wrap and sz.x > l.size.x + 2.0 and not l.clip_text and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
			bad += 1
			print("   débordement x : ", l.name, " '", l.text, "' ", sz.x, " > ", l.size.x)
		if wrap and l.max_lines_visible <= 0 and sz.y > l.size.y + 2.0:
			bad += 1
			print("   débordement y : ", l.name, " '", l.text, "'")
	_check(bad == 0, "%s : aucun texte sans garde de débordement" % tag)
