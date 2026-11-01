extends Node
## Boutique de skins (rubis) : prix (data/shop.json), Profile.buy_skin (débit, possession, refus, double achat), équipement,
## persistance, ancien fichier de profil, mode test (bac à sable sans écriture), écran ShopScreen et bouton du titre.
## godot --headless --path game res://tests/shop_test.tscn   (RESULT: OK)

const ProfileScript := preload("res://scripts/save/profile.gd")
const TMP := "user://shop_test_profile.json"
const TMP2 := "user://shop_test_sandbox.json"
var _fails := 0
var _asked := 0
var _asked_answer := false


func _check(ok: bool, msg: String) -> void:
	print("ok   " if ok else "FAIL ", msg)
	if not ok:
		_fails += 1


func _fresh(rub := 0) -> Node:
	var p: Node = ProfileScript.new()
	p.write_enabled = false
	p.unlock_all_variants = false
	p.rubies = rub
	return p


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _rm(path: String) -> void:
	for f in [path, path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


func _cell(scr: ShopScreen, sid: String) -> Button:
	for c in scr.cells:
		if c.name == "Skin_" + sid:
			return c
	return null


func _confirm(_t: String, _l: String) -> bool:
	_asked += 1
	return _asked_answer


func _ready() -> void:
	_rm(TMP)
	_rm(TMP2)
	SkinShop.data_override = null

	# --- Prix ---
	var all := Skins.all_skins()
	var prices_ok := all.size() == 10
	for e in all:
		prices_ok = prices_ok and SkinShop.price_of(e.id) >= 1
	_check(prices_ok, "10 skins, prix >= 1 rubis (défaut %d)" % SkinShop.price_of("ardent_skin1"))
	SkinShop.data_override = {"skin_default_price": 100, "skin_prices": {"rictus_skin1": 40}}
	_check(SkinShop.price_of("ardent_skin1") == 100 and SkinShop.price_of("rictus_skin1") == 40, "prix par défaut et prix propre à un skin (données)")
	SkinShop.data_override = {"skin_default_price": 0}
	_check(SkinShop.price_of("ardent_skin1") == 1, "prix plancher à 1")
	SkinShop.data_override = null
	var price := SkinShop.price_of("ardent_skin1")

	# --- Achat ---
	var p := _fresh(1000)
	_check(p.buy_skin("ardent_skin1") == &"ok", "achat d'un skin : ok")
	_check(p.rubies == 1000 - price, "rubis débités du prix (%d -> %d)" % [1000, p.rubies])
	_check(Skins.is_unlocked(p, "ardent_skin1") and p.unlocked_skins.has(&"ardent_skin1"), "skin possédé")
	_check(Skins.equipped("ardent", p) == "", "l'achat n'équipe pas")
	_check(int(p.stats.get("rubies_spent", 0)) == price, "compteur stats.rubies_spent")
	var before: int = p.rubies
	_check(p.buy_skin("ardent_skin1") == &"owned" and p.rubies == before, "double achat refusé, rien débité")
	_check(p.unlocked_skins.count(&"ardent_skin1") == 1, "possession non dupliquée")
	_check(p.set_selected_skin(&"ardent", "ardent_skin1") and Skins.equipped("ardent", p) == "ardent_skin1", "skin acheté équipable")
	_check(p.buy_skin("n_importe_quoi") == &"unknown", "id inconnu refusé")

	# --- Rubis insuffisants ---
	var q := _fresh(price - 1)
	_check(q.buy_skin("rictus_skin1") == &"poor", "rubis insuffisants : refusé")
	_check(q.rubies == price - 1 and not q.unlocked_skins.has(&"rictus_skin1") and not q.stats.has("rubies_spent"), "refus : rubis et possession inchangés")
	q.rubies += 1
	_check(q.buy_skin("rictus_skin1") == &"ok" and q.rubies == 0, "juste assez : achat, solde à 0")

	# --- Deux voies : condition puis achat ---
	var w := _fresh(500)
	var res: Array = w.add_run_result({"victory": true, "mode": "difficile", "character": "tocsin", "active_time_s": 700.0, "kills": 100,
		"rubies": 0, "stage": 5, "level": 10, "items": {}, "loadout": {}, "counters": {}, "bosses_killed": []})
	_check(res.has(&"skin:tocsin_skin1"), "skin débloqué par sa condition (victoire en Difficile)")
	var rb: int = w.rubies
	_check(w.buy_skin("tocsin_skin1") == &"owned" and w.rubies == rb, "skin déjà gagné : pas racheté, rien débité")

	# --- Interrupteur de test des variantes ---
	var u := _fresh(500)
	u.unlock_all_variants = true
	_check(u.buy_skin("vigie_skin1") == &"owned" and u.rubies == 500, "tous débloqués (test) : rien débité")

	# --- Rendu pas livré = non vendu ---
	var fake := [{"id": "foo", "name": "Foo", "playable": true, "sprite_frames": "user://shop_test_foo/foo.tres",
		"skins": [{"id": "foo_skin1", "name": "Bar", "desc": "d", "unlock_text": "u", "unlock_key": "skin:foo_skin1",
			"unlock_rule": {"type": "win_with", "character": "foo", "mode": "difficile"}}]}]
	Skins.roster_override = fake
	var f := _fresh(9999)
	f.characters_override = fake
	_check(f.buy_skin("foo_skin1") == &"no_art" and f.rubies == 9999, "assets non livrés : non vendu, rien débité")
	Skins.roster_override = null
	f.free()

	# --- Persistance ---
	var d := _fresh(600)
	d.path = TMP
	d.write_enabled = true
	_check(d.buy_skin("averse_skin1") == &"ok" and FileAccess.file_exists(TMP), "achat écrit le profil")
	d.set_selected_skin(&"averse", "averse_skin1")
	var e2 := _fresh()
	e2.path = TMP
	e2.load_profile()
	_check(e2.rubies == 600 - price and e2.unlocked_skins.has(&"averse_skin1") and Skins.equipped("averse", e2) == "averse_skin1", "rechargé : rubis, possession, skin équipé")
	_check(int(e2.stats.get("rubies_spent", 0)) == price, "rechargé : rubis dépensés")
	_check(e2.buy_skin("averse_skin1") == &"owned", "rechargé : double achat toujours refusé")
	d.free()
	e2.free()

	# --- Ancien fichier (version 4 sans trace de boutique, et version 1) ---
	var old := FileAccess.open(TMP, FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 4, "rubies": 400, "unlocked_skins": ["ardent_skin1"], "history": []}))
	old.close()
	var m4 := _fresh()
	m4.path = TMP
	m4.load_profile()
	_check(m4.rubies == 400 and m4.unlocked_skins == [&"ardent_skin1"], "ancien profil v4 chargé tel quel")
	_check(m4.buy_skin("ardent_skin1") == &"owned" and m4.buy_skin("rictus_skin1") == &"ok" and m4.rubies == 400 - price, "ancien profil : achat possible, skin déjà possédé respecté")
	m4.free()
	old = FileAccess.open(TMP, FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 1, "rubies": 90}))
	old.close()
	var m1 := _fresh()
	m1.path = TMP
	m1.load_profile()
	var want: StringName = &"ok" if 90 >= price else &"poor"
	_check(m1.rubies == 90 and m1.unlocked_skins.is_empty() and m1.buy_skin("ardent_skin1") == want, "ancien profil v1 chargé, achat selon le solde")
	m1.free()
	_rm(TMP)

	# --- Mode test : bac à sable, aucune écriture ---
	var s := _fresh(800)
	s.path = TMP2
	s.write_enabled = true
	s.save()
	var disk_before := FileAccess.get_file_as_string(TMP2)
	s.begin_sandbox()
	_check(s.buy_skin("bourbe_skin1") == &"ok" and s.unlocked_skins.has(&"bourbe_skin1"), "bac à sable : achat en mémoire")
	_check(FileAccess.get_file_as_string(TMP2) == disk_before, "bac à sable : disque inchangé")
	s.end_sandbox()
	_check(s.rubies == 800 and not s.unlocked_skins.has(&"bourbe_skin1") and not s.stats.has("rubies_spent"), "sortie du mode test : rubis et skins d'avant")
	_check(FileAccess.get_file_as_string(TMP2) == disk_before, "après sortie : disque inchangé")
	s.free()
	_rm(TMP2)

	# --- Écran ---
	var sp := _fresh(price + 30)
	var scr := ShopScreen.new()
	scr.profile = sp
	scr.confirm_override = _confirm
	add_child(scr)
	await _frames(3)
	_check(scr.cells.size() == 10, "écran : un carton par skin (%d)" % scr.cells.size())
	_check(scr.ruby_label.text == ShopScreen.format_int(price + 30), "écran : solde de rubis affiché (%s)" % scr.ruby_label.text)
	var ca := _cell(scr, "ardent_skin1")
	_check(ca != null and ca.get_meta(&"state") == ShopScreen.State.BUYABLE and ca.find_child("PriceText", true, false) != null, "carton achetable : prix affiché")
	var cr := _cell(scr, "rictus_skin1")
	_check(cr.get_meta(&"state") == ShopScreen.State.BUYABLE, "un autre skin achetable avec le solde")
	_check(scr.back_button.custom_minimum_size.y >= 88, "bouton Retour >= 88 px")
	# refus à la confirmation
	_asked_answer = false
	ca.pressed.emit()
	await _frames(3)
	_check(_asked == 1 and sp.rubies == price + 30 and not Skins.is_unlocked(sp, "ardent_skin1"), "confirmation refusée : rien acheté")
	# achat confirmé
	_asked_answer = true
	ca.pressed.emit()
	await _frames(3)
	_check(_asked == 2 and sp.rubies == 30 and Skins.is_unlocked(sp, "ardent_skin1"), "confirmation acceptée : acheté et débité")
	_check(Skins.equipped("ardent", sp) == "" and scr.toast_text.begins_with("Skin acquis"), "acheté : pas équipé, message affiché")
	_check(scr.ruby_label.text == "30", "solde mis à jour (%s)" % scr.ruby_label.text)
	ca = _cell(scr, "ardent_skin1")
	_check(ca.get_meta(&"state") == ShopScreen.State.OWNED, "carton : possédé")
	# rubis insuffisants
	var cr2 := _cell(scr, "rictus_skin1")
	_check(cr2.get_meta(&"state") == ShopScreen.State.POOR, "carton : rubis insuffisants")
	var asked_before := _asked
	cr2.pressed.emit()
	await _frames(2)
	_check(_asked == asked_before and sp.rubies == 30 and scr.toast_text.begins_with("Il vous manque"), "insuffisant : pas de confirmation, message « il manque »")
	# équiper / retirer
	ca.pressed.emit()
	await _frames(2)
	_check(Skins.equipped("ardent", sp) == "ardent_skin1" and _cell(scr, "ardent_skin1").get_meta(&"state") == ShopScreen.State.EQUIPPED, "appui sur un skin possédé : équipé")
	_cell(scr, "ardent_skin1").pressed.emit()
	await _frames(2)
	_check(Skins.equipped("ardent", sp) == "", "nouvel appui : retiré")
	var back_got := [false]
	scr.back_requested.connect(func() -> void: back_got[0] = true)
	scr.back_button.pressed.emit()
	_check(back_got[0], "Retour émet back_requested")
	scr.queue_free()
	sp.free()

	# --- Bouton du titre ---
	var t := load("res://scenes/menu/title.tscn").instantiate() as TitleScreen
	t.summary_provider = func() -> Dictionary: return {}
	add_child(t)
	await _frames(3)
	var shop_sig := [false]
	t.shop_requested.connect(func() -> void: shop_sig[0] = true)
	_check(t.shop_button != null and t.shop_button.custom_minimum_size.x >= 88 and t.shop_button.custom_minimum_size.y >= 88, "titre : bouton Boutique >= 88 px")
	t.shop_button.pressed.emit()
	_check(shop_sig[0], "titre : Boutique émet shop_requested")
	t.queue_free()
	await _frames(2)

	p.free()
	q.free()
	w.free()
	u.free()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
