extends Node
## Historique des runs (Profile.history) et écran HistoryScreen : enregistrement, tris, filtre, migration, plafond, mode test.
## godot --headless --path game res://tests/history_test.tscn   (RESULT: OK)

const ProfileScript := preload("res://scripts/save/profile.gd")
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


func _run(cid: String, t: float, extra := {}) -> Dictionary:
	var r := {"victory": false, "mode": "moyen", "character": cid, "active_time_s": t, "kills": 100, "rubies": 5, "stage": 2,
		"level": 8, "gold": 321, "difficulty": 4.5, "items": {"moisson": 2, "lame_jumelle": 1}, "loadout": {},
		"counters": {}, "bosses_killed": [], "reason": "death"}
	r.merge(extra, true)
	return r


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var p := _fresh()
	_check(p.history.is_empty(), "profil vierge : historique vide")
	p.add_run_result(_run("ardent", 600.0))
	_check(p.history.size() == 1, "défaite enregistrée")
	var e: Dictionary = p.history[0]
	_check(e.character == "ardent" and not e.victory and e.reason == "death" and int(e.stage) == 2 and is_equal_approx(float(e.time_s), 600.0), "champs de base")
	_check(int(e.kills) == 100 and int(e.level) == 8 and int(e.gold) == 321 and int(e.rubies) == 5 and is_equal_approx(float(e.difficulty), 4.5), "stats")
	_check(e.items == {"moisson": 2, "lame_jumelle": 1} and int(e.n_items) == 3, "objets {id: stacks} et total")
	_check(not bool(e.final_boss_killed) and float(e.win_time_s) == 0.0, "pas de boss final tué")
	_check(str(e.date).length() >= 10, "date")
	# Victoires (boss final tué), abandon, défaite après boss en sans fin.
	p.add_run_result(_run("ardent", 1500.0, {"victory": true, "stage": 5, "boss_time_s": 1400.0, "final_boss_time_s": 1400.0, "reason": "victory", "items": {"moisson": 9}}))
	p.add_run_result(_run("rictus", 1200.0, {"victory": true, "stage": 5, "boss_time_s": 1100.0, "final_boss_time_s": 1100.0, "reason": "victory", "items": {"moisson": 1}}))
	p.add_run_result(_run("rictus", 300.0, {"reason": "abandon", "items": {}}))
	p.add_run_result(_run("averse", 2000.0, {"stage": 7, "final_boss_time_s": 1900.0, "items": {"moisson": 5}}))
	_check(p.history.size() == 5, "5 runs")
	_check(bool(p.history[1].final_boss_killed) and is_equal_approx(float(p.history[1].win_time_s), 1400.0), "victoire : temps d'abattage")
	_check(bool(p.history[4].final_boss_killed) and not bool(p.history[4].victory), "mort en sans fin après le boss final : boss tué conservé")
	_check(HistoryScreen.result_text(p.history[3]) == "Abandon — étage 2" and HistoryScreen.result_text(p.history[0]) == "Défaite — étage 2", "libellés de résultat")

	# --- tris ---
	var h: Array = p.history
	var rec := HistoryScreen.sorted_entries(h, HistoryScreen.SORT_RECENT)
	_check(rec.size() == 5 and rec[0] == h[4] and rec[4] == h[0], "récentes : la dernière en tête")
	var fast := HistoryScreen.sorted_entries(h, HistoryScreen.SORT_FASTEST)
	_check(fast.size() == 3 and fast[0].character == "rictus" and float(fast[0].win_time_s) == 1100.0 and float(fast[1].win_time_s) == 1400.0 and float(fast[2].win_time_s) == 1900.0,
		"plus rapide : seulement les runs avec boss tué, par temps d'abattage")
	var its := HistoryScreen.sorted_entries(h, HistoryScreen.SORT_ITEMS)
	_check(int(its[0].n_items) == 9 and int(its[1].n_items) == 5 and int(its[4].n_items) == 0, "objets : décroissant")
	var lg := HistoryScreen.sorted_entries(h, HistoryScreen.SORT_LONGEST)
	_check(is_equal_approx(float(lg[0].time_s), 2000.0) and is_equal_approx(float(lg[4].time_s), 300.0), "plus longue")
	var sh := HistoryScreen.sorted_entries(h, HistoryScreen.SORT_SHORTEST)
	_check(is_equal_approx(float(sh[0].time_s), 300.0) and is_equal_approx(float(sh[4].time_s), 2000.0), "plus courte")
	var fr := HistoryScreen.sorted_entries(h, HistoryScreen.SORT_RECENT, "rictus")
	_check(fr.size() == 2 and fr[0].reason == "abandon", "filtre personnage")
	_check(HistoryScreen.sorted_entries(h, HistoryScreen.SORT_FASTEST, "ardent").size() == 1, "filtre + tri speedrun")
	_check(HistoryScreen.characters_in(h) == ["averse", "rictus", "ardent"], "personnages présents (récent d'abord)")
	_check(HistoryScreen.time_text(3725.0) == "1:02:05" and HistoryScreen.time_text(65.0) == "01:05", "format du temps")

	# --- sérialisation, migration ---
	var d: Dictionary = JSON.parse_string(JSON.stringify(p.to_dict()))
	_check(int(d.version) >= 4 and d.history is Array and d.history.size() == 5, "sauvegarde v%d avec historique" % int(d.version))
	var q := _fresh()
	q._apply_dict(d)
	_check(q.history.size() == 5 and q.history[1].items == {"moisson": 9} and q.history[4].final_boss_killed, "rechargement identique")
	var old := d.duplicate(true)
	old.erase("history")
	old["version"] = 3
	var m := _fresh()
	m._apply_dict(old)
	_check(m.history.is_empty(), "profil v3 sans historique : se charge, historique vide")
	m.add_run_result(_run("ardent", 100.0))
	_check(m.history.size() == 1, "puis la run s'ajoute")
	var bad := d.duplicate(true)
	bad["history"] = [3, "x", {"time_s": "abc"}, {"time_s": 12, "character": "ardent", "items": "oops"}]
	var b := _fresh()
	b._apply_dict(bad)
	_check(b.history.size() == 1 and b.history[0].items == {} and int(b.history[0].n_items) == 0, "entrées illisibles ignorées")

	# --- plafond ---
	var c := _fresh()
	for i in ProfileScript.HISTORY_MAX + 15:
		c.add_run_result(_run("ardent", float(i + 1)))
	_check(c.history.size() == ProfileScript.HISTORY_MAX, "plafond %d" % ProfileScript.HISTORY_MAX)
	_check(is_equal_approx(float(c.history[0].time_s), 16.0) and is_equal_approx(float(c.history[c.history.size() - 1].time_s), float(ProfileScript.HISTORY_MAX + 15)), "les plus anciennes sont supprimées")
	var big: Dictionary = c.to_dict()
	big["history"] = (big["history"] as Array) + (big["history"] as Array)
	var c2 := _fresh()
	c2._apply_dict(JSON.parse_string(JSON.stringify(big)))
	_check(c2.history.size() == ProfileScript.HISTORY_MAX, "plafond aussi au chargement")

	# --- bac à sable (mode test) ---
	var s := _fresh()
	s.add_run_result(_run("ardent", 50.0))
	s.begin_sandbox()
	s.add_run_result(_run("ardent", 60.0))
	_check(s.history.size() == 1, "mode test : rien ajouté")
	s.end_sandbox()
	_check(s.history.size() == 1, "fin du bac à sable : historique inchangé")

	# --- écran ---
	var fake := _fresh()
	for r in [_run("ardent", 1500.0, {"victory": true, "stage": 5, "final_boss_time_s": 1400.0, "boss_time_s": 1400.0, "reason": "victory"}),
			_run("rictus", 800.0), _run("ardent", 400.0, {"reason": "abandon", "omens": {"3": "marche_noir", "2": "usure"}})]:
		fake.add_run_result(r)
	var scr: HistoryScreen = load("res://scenes/menu/history.tscn").instantiate()
	scr.profile = fake
	add_child(scr)
	await _frames(3)
	_check(scr.cards.size() == 3 and scr.sort_buttons.size() == 5, "écran : 3 cartes, 5 tris")
	_check(scr.cards[0].get_meta(&"entry").character == "ardent" and scr.cards[0].get_meta(&"entry").reason == "abandon", "écran : plus récente en tête")
	scr.set_sort(HistoryScreen.SORT_FASTEST)
	_check(scr.cards.size() == 1 and scr.sort_buttons[1].button_pressed and not scr.sort_buttons[0].button_pressed, "écran : tri speedrun")
	scr.set_sort(HistoryScreen.SORT_LONGEST)
	_check(scr.cards.size() == 3 and float(scr.cards[0].get_meta(&"entry").time_s) == 1500.0, "écran : tri plus longue")
	scr.cycle_filter()
	_check(scr.character_filter == "ardent" and scr.cards.size() == 2, "écran : filtre ardent")
	scr.cycle_filter()
	scr.cycle_filter()
	_check(scr.character_filter == "" and scr.cards.size() == 3, "écran : filtre bouclé sur Tous")
	scr.cards[0].pressed.emit()
	await _frames(2)
	_check(scr.detail != null and scr.detail.get_node_or_null("Sheet") != null and scr.detail.find_child("Item_moisson", true, false) != null and scr.detail.find_child("Omen_2", true, false) == null, "écran : détail avec icônes d'objets, sans section présages")
	var omen_card: Button = null
	for cd in scr.cards:
		if (cd.get_meta(&"entry") as Dictionary).has("omens"):
			omen_card = cd
	_check(omen_card != null, "historique : présages conservés dans l'entrée")
	scr.close_detail()
	await _frames(2)
	if omen_card != null:
		omen_card.pressed.emit()
		await _frames(2)
		_check(scr.detail != null and scr.detail.find_child("Omen_2", true, false) != null and scr.detail.find_child("Omen_3", true, false) != null, "écran : détail avec les présages par étage")
		scr.close_detail()
		await _frames(2)
	_check(scr.detail == null, "écran : détail fermé")
	var got := []
	scr.back_requested.connect(func(): got.append(1))
	scr.back_button.pressed.emit()
	_check(got.size() == 1, "écran : retour")
	# onglets : Records, Objets, Skins
	scr.show_tab(HistoryScreen.TAB_RECORDS)
	await _frames(2)
	_check(scr.views[0].visible and not scr._scroll.visible and scr.views[0].cells.size() > 0, "onglet Records : une cellule par personnage")
	scr.views[0].cells[0].pressed.emit()
	await _frames(2)
	_check(scr.best_panel != null and scr.best_panel is BestRunsPanel, "onglet Records : clic = panneau des meilleures runs")
	scr.best_panel.close()
	await _frames(2)
	_check(scr.best_panel == null, "panneau des meilleures runs fermé")
	scr.show_tab(HistoryScreen.TAB_ITEMS)
	await _frames(2)
	_check(scr.views[1].visible and scr.views[1].cells.size() == ItemDB.all_ids().size() and scr.count_label.text.ends_with("objets débloqués"), "onglet Objets : tout le catalogue (%s)" % scr.count_label.text)
	scr.show_tab(HistoryScreen.TAB_SKINS)
	await _frames(2)
	var skin_cells: Array[Button] = scr.views[2].cells
	_check(skin_cells.size() > 0 and scr.count_label.text.ends_with("skins débloqués"), "onglet Skins : un skin par personnage (%s)" % scr.count_label.text)
	var sid := str(skin_cells[0].get_meta(&"skin_id"))
	var cid := ""
	for sk in Skins.all_skins(CharacterCard.load_characters()):
		if str(sk.id) == sid:
			cid = str(sk.character.get("id", ""))
	fake.unlocked_skins.append(StringName(sid))
	skin_cells[0].pressed.emit()
	await _frames(2)
	_check(fake.selected_skin.get(cid, "") == sid, "onglet Skins : clic = skin équipé")
	scr.views[2].cells[0].pressed.emit()
	await _frames(2)
	_check(fake.selected_skin.get(cid, "") == "", "onglet Skins : second clic = skin retiré")
	scr.show_tab(HistoryScreen.TAB_RUNS)
	await _frames(2)
	_check(scr._scroll.visible and scr.cards.size() == 3 and not scr.views[2].visible, "retour à l'onglet Parties")
	scr.queue_free()
	var empty_scr: HistoryScreen = load("res://scenes/menu/history.tscn").instantiate()
	empty_scr.profile = _fresh()
	add_child(empty_scr)
	await _frames(2)
	_check(empty_scr.cards.is_empty() and empty_scr._empty.visible, "écran : état vide")
	empty_scr.queue_free()

	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
