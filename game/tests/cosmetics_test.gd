extends Node
## Boutique cosmétique (scripts/save/cosmetics.gd) : catalogue data/cosmetics.json (schéma, aucun effet de jeu, articles
## sans assets non achetables), Profile.spend_rubies / buy_cosmetic (débit, solde insuffisant, double achat, compteur
## rubies_spent), équipement Profile.equipped["famille:cible"], Panoplies comme skins de plus (Skins.skins_of), migration
## v4 -> v5 sans perte, bac à sable du mode test (aucune écriture), override du mode test, Ciel (garde-fou de luminance,
## jamais à l'étage 5), Parement (texture substituée, marges du kit DA gardées), Sillage (<= 8 sprites vivants), Veillée
## (props autour du feu du titre), écran ShopScreen (onglets, « Bientôt », achat confirmé).
## godot --headless --path game res://tests/cosmetics_test.tscn   (RESULT: OK)

const ProfileScript := preload("res://scripts/save/profile.gd")
const TMP := "user://cosmetics_test_profile.json"
const DA := "res://assets/sprites/ui/da/"
const ALT_UI := "res://assets/sprites/ui/menu/" ## contient un button_normal.png : sert de faux Parement livré
var _fails := 0
var _asked := 0


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


func _confirm(_t: String, _l: String) -> bool:
	_asked += 1
	return true


## Catalogue d'essai : des articles dont les assets existent déjà dans le projet (faux livrés) et un article en attente.
func _fake_catalogue() -> Dictionary:
	return {"families": {"panoplie": {"name": "Panoplies"}, "ciel": {"name": "Ciels"}, "sillage": {"name": "Sillages"},
		"parement": {"name": "Parements"}, "veillee": {"name": "Veillées"}},
		"items": [
			{"id": "t_pano", "family": "panoplie", "name": "Pano", "desc": "d", "price": 300, "target": "ardent",
				"assets": {"frames": "res://assets/sprites/characters/ardent/ardent.tres"}},
			{"id": "t_ciel", "family": "ciel", "name": "Ciel", "desc": "d", "price": 600, "target": "terrasses",
				"assets": {"profiles": ["res://data/ambiance/terrasses_noyees.tres"]}},
			{"id": "t_pas", "family": "sillage", "name": "Pas", "desc": "d", "price": 250, "target": "pas",
				"assets": {"particle": DA + "icon_ruby.png", "step": DA + "icon_gold.png"}},
			{"id": "t_esq", "family": "sillage", "name": "Esquive", "desc": "d", "price": 200, "target": "esquive",
				"assets": {"wake": DA + "icon_gold.png", "burst": DA + "icon_ruby.png"}},
			{"id": "t_par", "family": "parement", "name": "Parement", "desc": "d", "price": 400, "target": "",
				"assets": {"dir": ALT_UI, "files": ["button_normal.png"]}},
			{"id": "t_vei", "family": "veillee", "name": "Veillée", "desc": "d", "price": 500, "target": "",
				"assets": {"map": "terrasses_noyees", "dir": "res://assets/sprites/ui/hud/", "props": ["icon_gold.png", "icon_ruby.png"],
					"fire": "res://assets/sprites/characters/ardent/ardent.tres"}},
			{"id": "t_wait", "family": "sillage", "name": "Attente", "desc": "d", "price": 250, "target": "pas", "pending": true,
				"assets": {"particle": DA + "icon_ruby.png"}},
			{"id": "t_missing", "family": "parement", "name": "Absent", "desc": "d", "price": 400, "target": "",
				"assets": {"dir": "res://assets/sprites/ui/parements/nope/", "files": ["button_normal.png"]}},
		]}


func _ready() -> void:
	_rm(TMP)
	Cosmetics.data_override = null
	Cosmetics.reload()

	# --- Catalogue réel : schéma, aucun effet de jeu, rien d'achetable sans assets ---
	var real := Cosmetics.items()
	_check(not real.is_empty(), "catalogue data/cosmetics.json lu (%d articles)" % real.size())
	var schema_ok := true
	var no_effect := true
	var fams := Cosmetics.families()
	var ids := {}
	for it in real:
		var id := str(it.get("id", ""))
		schema_ok = schema_ok and id != "" and not ids.has(id) and fams.has(Cosmetics.family_of(it)) and str(it.get("name", "")) != "" \
			and str(it.get("desc", "")) != "" and (it.get("price") is float or it.get("price") is int) and int(it.price) > 0 and it.get("assets") is Dictionary
		ids[id] = true
		for k in Cosmetics.FORBIDDEN_KEYS:
			if (it as Dictionary).has(k):
				no_effect = false
				print("     clé interdite ", k, " dans ", id)
	_check(schema_ok, "catalogue : id unique, famille connue, nom, desc, prix > 0, assets")
	_check(no_effect, "catalogue : aucune clé d'effet de jeu (effects, stats, mult, bonus, unlock_rule…)")
	var fam_ok := true
	for f in [&"panoplie", &"ciel", &"sillage", &"parement", &"veillee"]:
		fam_ok = fam_ok and not Cosmetics.items_of(f).is_empty()
	_check(fam_ok, "catalogue : les 5 familles ont des articles")
	var sillage_ok := true
	for it in Cosmetics.items_of(&"sillage"):
		var tg := str(it.get("target", ""))
		var a: Dictionary = it.get("assets", {})
		sillage_ok = sillage_ok and ((tg == "pas" and (a.has("step") or a.has("particle"))) or (tg == "esquive" and (a.has("wake") or a.has("burst"))))
	_check(sillage_ok, "catalogue : chaque Sillage déclare target pas|esquive, cohérent avec ses assets")
	var pend := _fresh(99999)
	var all_safe := true
	for it in real:
		var id := str(it.id)
		var r: StringName = pend.call(&"buy_cosmetic", id)
		if not Cosmetics.has_assets(it) and r != &"no_art":
			all_safe = false
			print("     vendu sans assets : ", id, " -> ", r)
	_check(all_safe and (pend.rubies == 99999 or pend.owned_cosmetics.size() > 0), "catalogue : article sans assets non achetable (no_art, rien débité)")
	pend.free()

	# --- Catalogue d'essai ---
	Cosmetics.data_override = _fake_catalogue()
	_check(Cosmetics.slot_of(Cosmetics.item("t_ciel")) == "ciel:terrasses" and Cosmetics.slot_of(Cosmetics.item("t_par")) == "parement:all", "emplacements « famille:cible »")
	_check(Cosmetics.slot_of(Cosmetics.item("t_pas")) == "sillage:pas" and Cosmetics.slot_of(Cosmetics.item("t_esq")) == "sillage:esquive", "Sillages : pas et esquive séparés")
	# L'emplacement vient du catalogue (target), pas des assets : un article « wake » déclaré « pas » reste « pas », sans cible = « pas ».
	var odd := {"id": "t_odd", "family": "sillage", "target": "pas", "assets": {"wake": "x"}}
	_check(Cosmetics.slot_of(odd) == "sillage:pas" and Cosmetics.slot_of({"family": "sillage", "assets": {"wake": "x"}}) == "sillage:pas", "Sillages : emplacement lu du catalogue, non déduit des assets")
	_check(Cosmetics.slot_of({"family": "sillage", "target": "esquive"}) == "sillage:esquive", "Sillages : target « esquive » respectée")
	_check(Cosmetics.has_assets(Cosmetics.item("t_par")) and Cosmetics.has_assets(Cosmetics.item("t_vei")), "assets dir+files / map+props résolus")
	_check(not Cosmetics.has_assets(Cosmetics.item("t_wait")) and not Cosmetics.has_assets(Cosmetics.item("t_missing")), "pending ou fichier absent : non livré")

	# --- spend_rubies / buy_cosmetic ---
	var p := _fresh(500)
	_check(not p.spend_rubies(501) and p.rubies == 500 and not p.stats.has("rubies_spent"), "spend_rubies : solde insuffisant refusé, rien débité")
	_check(not p.spend_rubies(0) and not p.spend_rubies(-5), "spend_rubies : montant <= 0 refusé")
	_check(p.spend_rubies(100) and p.rubies == 400 and int(p.stats.rubies_spent) == 100, "spend_rubies : débit et compteur rubies_spent")
	p.free()
	var q := _fresh(300)
	_check(q.buy_cosmetic("t_par") == &"poor" and q.rubies == 300 and q.owned_cosmetics.is_empty(), "buy_cosmetic : rubis insuffisants refusé, rien débité")
	_check(q.buy_cosmetic("t_pas") == &"ok" and q.rubies == 50 and q.is_cosmetic_owned("t_pas") and int(q.stats.rubies_spent) == 250, "buy_cosmetic : achat, débit, possession, compteur")
	_check(q.buy_cosmetic("t_pas") == &"owned" and q.rubies == 50, "buy_cosmetic : double achat refusé, rien débité")
	_check(q.buy_cosmetic("nimporte") == &"unknown", "buy_cosmetic : id inconnu refusé")
	q.rubies = 9999
	_check(q.buy_cosmetic("t_wait") == &"no_art" and q.buy_cosmetic("t_missing") == &"no_art" and q.rubies == 9999, "buy_cosmetic : article sans assets non achetable")
	_check(Cosmetics.equipped_item(&"sillage", "", q).is_empty(), "acheté : pas équipé")
	_check(not q.equip_cosmetic("parement:all", "t_par"), "équiper un article non possédé : refusé")
	_check(not q.equip_cosmetic("parement:all", "t_pas"), "équiper dans le mauvais emplacement : refusé")
	_check(q.equip_cosmetic("sillage:pas", "t_pas") and q.equipped_cosmetic("sillage:pas") == "t_pas", "équiper : Profile.equipped[\"sillage:pas\"]")
	_check(str(Cosmetics.equipped_item(&"sillage", "pas", q).get("id", "")) == "t_pas", "Cosmetics.equipped_item : article équipé et livré")
	_check(q.equip_cosmetic("sillage:pas", "") and Cosmetics.equipped_item(&"sillage", "pas", q).is_empty(), "retirer : retour au défaut")
	_check(q.buy_cosmetic("t_ciel") == &"ok" and q.equip_cosmetic("ciel:terrasses", "t_ciel"), "Ciel acheté et équipé pour son biome")
	_check(str(AmbianceManager.equipped_ciel("terrasses", 1, q).get("id", "")) == "t_ciel", "Ciel lu pour les Terrasses (étage 1)")
	_check(AmbianceManager.equipped_ciel("terrasses", 5, q).is_empty() and AmbianceManager.equipped_ciel("source", 1, q).is_empty(), "jamais de Ciel à l'étage 5 ni à La Source")
	_check(AmbianceManager.equipped_ciel("foret", 2, q).is_empty(), "Ciel d'un autre biome : profil de la carte")
	_check(AmbianceManager.ciel_profile_path(Cosmetics.item("t_ciel"), "terrasses_rizieres_hautes") == "res://data/ambiance/terrasses_noyees.tres", "profil du Ciel : repli sur le premier livré")

	# --- Garde-fou de luminance (0,42) ---
	_check(AmbianceManager.ciel_readable(load("res://data/ambiance/terrasses_noyees.tres") as AmbianceProfile), "profil réel : luminance des entités >= 0,42")
	var dark := AmbianceProfile.new()
	dark.ambient_color = Color(0.03, 0.03, 0.05)
	dark.ambient_low = Color(0.03, 0.03, 0.05)
	dark.fill_color = Color.BLACK
	dark.sun_energy = 0.0
	_check(not AmbianceManager.ciel_readable(dark), "Ciel trop sombre (fill noir) : refusé")

	# --- Panoplies : skins de plus du personnage ---
	var trophies := 0
	for e in Skins.all_skins():
		trophies += 0 if bool(e.shop) else 1
	var ardent := Skins.skins_of("ardent")
	_check(ardent.size() == 2 and str(ardent[1].id) == "t_pano" and Skins.is_panoplie(ardent[1]), "Skins.skins_of : trophée puis Panoplie (%d)" % ardent.size())
	_check(trophies == 11 and Skins.all_skins().size() == 12, "Skins.all_skins : 11 trophées + 1 Panoplie")
	_check(Skins.has_assets("ardent", "t_pano") and SkinShop.price_of("t_pano") == 300, "Panoplie livrée, prix du catalogue cosmétique")
	var r := _fresh(1000)
	_check(not r.set_selected_skin(&"ardent", "t_pano"), "Panoplie non possédée : pas équipable")
	_check(r.buy_skin("t_pano") == &"ok" and r.rubies == 700 and r.is_cosmetic_owned("t_pano") and not r.unlocked_skins.has(&"t_pano"), "buy_skin(Panoplie) -> buy_cosmetic (owned_cosmetics)")
	_check(Skins.is_unlocked(r, "t_pano") and r.set_selected_skin(&"ardent", "t_pano") and Skins.equipped("ardent", r) == "t_pano", "Panoplie possédée : équipée via selected_skin")
	_check(r.equipped_cosmetic("panoplie:ardent") == "t_pano" and Cosmetics.equipped_id("panoplie:ardent", r) == "t_pano", "Panoplie : emplacement « panoplie:ardent » = selected_skin")
	_check(Skins.resolve_frames("ardent", "", r) == "res://assets/sprites/characters/ardent/ardent.tres", "Panoplie : SpriteFrames déclarés (assets.frames)")
	_check(not r.set_selected_skin(&"rictus", "t_pano"), "Panoplie d'un autre personnage : refusée")
	_check(r.equip_cosmetic("panoplie:ardent", "") and Skins.equipped("ardent", r) == "", "retrait de la Panoplie")
	_check(Skins.evaluate(r, Skins.roster(), {"victory": true, "mode": "difficile", "character": "ardent"}).all(func(k): return String(k) != "skin:t_pano"), "Panoplie jamais débloquée par une run")

	# --- Migration v4 -> v5 sans perte ---
	var old := FileAccess.open(TMP, FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 4, "rubies": 777, "unlocked_skins": ["ardent_skin1"], "selected_skin": {"ardent": "ardent_skin1"},
		"stats": {"runs": 3, "victories": 1, "kills": 10, "play_time_s": 60.0, "best_time_s": {}, "rubies_spent": 250.0}, "history": []}))
	old.close()
	var m := _fresh()
	m.path = TMP
	m.load_profile()
	_check(m.rubies == 777 and m.unlocked_skins == [&"ardent_skin1"] and Skins.equipped("ardent", m) == "ardent_skin1", "v4 chargé : rubis, skin acheté et équipé conservés")
	_check(m.owned_cosmetics.is_empty() and m.equipped.is_empty() and int(m.stats.rubies_spent) == 250, "v4 chargé : aucun cosmétique, compteur rubies_spent gardé")
	m.write_enabled = true
	_check(m.buy_cosmetic("t_vei") == &"ok" and m.equip_cosmetic("veillee:all", "t_vei"), "v4 -> achat et équipement d'une Veillée")
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(TMP))
	_check(disk is Dictionary and int(disk.version) == 5 and (disk.owned_cosmetics as Array).has("t_vei") and str(disk.equipped.get("veillee:all", "")) == "t_vei", "écrit en v5 (owned_cosmetics, equipped)")
	var m2 := _fresh()
	m2.path = TMP
	m2.load_profile()
	_check(m2.rubies == 277 and m2.unlocked_skins == [&"ardent_skin1"] and m2.is_cosmetic_owned("t_vei") and m2.equipped_cosmetic("veillee:all") == "t_vei" \
		and Skins.equipped("ardent", m2) == "ardent_skin1" and int(m2.stats.rubies_spent) == 750, "v5 relu : tout conservé")
	m.free()
	m2.free()

	# --- Mode test : bac à sable (aucune écriture) ---
	var s := _fresh(900)
	s.path = TMP
	s.write_enabled = true
	s.save()
	var before := FileAccess.get_file_as_string(TMP)
	s.begin_sandbox()
	_check(s.buy_cosmetic("t_par") == &"ok" and s.equip_cosmetic("parement:all", "t_par") and s.spend_rubies(10), "bac à sable : achat, équipement, dépense en mémoire")
	_check(FileAccess.get_file_as_string(TMP) == before, "bac à sable : disque inchangé")
	s.end_sandbox()
	_check(s.rubies == 900 and s.owned_cosmetics.is_empty() and s.equipped.is_empty() and not s.stats.has("rubies_spent"), "sortie du mode test : profil d'avant")
	_check(FileAccess.get_file_as_string(TMP) == before, "après sortie : disque inchangé")
	s.free()
	_rm(TMP)

	# --- Override du mode test (équiper sans acheter) ---
	var naked := _fresh(0)
	TestMode.begin()
	Cosmetics.set_test_override("parement:all", "t_par")
	_check(str(Cosmetics.equipped_item(&"parement", "", naked).get("id", "")) == "t_par", "mode test : Parement forcé sans achat")
	_check(naked.owned_cosmetics.is_empty() and naked.equipped.is_empty(), "mode test : rien d'écrit au profil")
	# Parement : texture substituée, marges du kit DA conservées
	UiTheme.reset_cache()
	var base_sb := _da_margins("button_normal")
	_check(UiTheme.ui_texture_path(DA + "button_normal.png") == ALT_UI + "button_normal.png", "Parement : texture de même nom dans son dossier")
	_check(UiTheme.ui_texture_path(DA + "bar_fill_hp.png") == DA + "bar_fill_hp.png", "Parement : remplissages jamais substitués")
	_check(UiTheme.ui_texture_path(DA + "panel_9slice.png") == DA + "panel_9slice.png", "Parement : fichier absent -> kit par défaut")
	var sb := UiTheme.da_box("button_normal")
	_check(sb != null and sb.texture.resource_path == ALT_UI + "button_normal.png" and _sb_margins(sb) == base_sb, "Parement : da_box -> autre texture, mêmes marges 9-slices")
	TestMode.end()
	_check(Cosmetics.test_override.is_empty() and UiTheme.ui_texture_path(DA + "button_normal.png") == DA + "button_normal.png", "sortie du mode test : override oublié, thème rendu")
	naked.free()

	# --- Sillage : émetteur sous le joueur (profil autoload en bac à sable) ---
	Profile.begin_sandbox()
	Profile.rubies = 2000
	_check(Profile.buy_cosmetic("t_pas") == &"ok" and Profile.equip_cosmetic("sillage:pas", "t_pas"), "autoload (bac à sable) : Sillage acheté et équipé")
	var q_tier := Quality.tier
	Quality.tier = Quality.Tier.HIGH
	var pl := Node2D.new()
	pl.name = "FakePlayer"
	add_child(pl)
	var trail := CosmeticTrail.attach(pl)
	await _frames(1)
	_check(trail.enabled, "Sillage : émetteur actif")
	var peak := 0
	for i in 90:
		pl.global_position += Vector2(40, 0)
		await get_tree().process_frame
		peak = maxi(peak, trail.alive_count())
	_check(peak > 0 and peak <= CosmeticTrail.MAX_ALIVE, "Sillage : marques posées en marchant, au plus 8 vivantes (pic %d)" % peak)
	Quality.tier = Quality.Tier.LOW
	trail.refresh()
	_check(not trail.enabled and trail.alive_count() == 0, "Sillage : coupé en qualité Bas")
	Quality.tier = q_tier
	pl.queue_free()

	# --- Veillée : props autour du feu de l'écran titre ---
	_check(Profile.buy_cosmetic("t_vei") == &"ok" and Profile.equip_cosmetic("veillee:all", "t_vei"), "autoload (bac à sable) : Veillée équipée")
	var bg := MenuBackground.new()
	add_child(bg)
	bg.setup("cite_rouille")
	await _frames(2)
	_check(bg.map_id == "terrasses_noyees" and bg.veillee_nodes.size() == 3, "Veillée : carte et props (2 props + feu : %d)" % bg.veillee_nodes.size())
	Profile.equip_cosmetic("veillee:all", "")
	await _frames(1)
	_check(bg.map_id == "cite_rouille" and bg.veillee_nodes.is_empty(), "Veillée retirée : fond par défaut reconstruit")
	bg.queue_free()
	await _frames(2)

	# --- Écran Boutique ---
	var sp := _fresh(700)
	var scr := ShopScreen.new()
	scr.profile = sp
	scr.confirm_override = _confirm
	add_child(scr)
	await _frames(3)
	_check(scr.tab_buttons.size() == 5 and scr.family == &"panoplie", "écran : 5 onglets, Panoplies d'abord")
	_check(scr.cells.size() == 12, "onglet Panoplies : trophées + Panoplies (%d)" % scr.cells.size())
	scr.show_family(&"sillage")
	await _frames(2)
	_check(scr.cells.size() == 3, "onglet Sillages : 3 articles (%d)" % scr.cells.size())
	var wait := scr.find_child("Cosm_t_wait", true, false) as Button
	_check(wait != null and wait.get_meta(&"state") == ShopScreen.State.NO_ART and (wait.find_child("State", true, false) as Label).text == ShopScreen.SOON_TEXT, "article sans assets : « Bientôt »")
	wait.pressed.emit()
	await _frames(2)
	_check(_asked == 0 and sp.rubies == 700 and scr.toast_text.begins_with("Bientôt"), "« Bientôt » : pas de confirmation, rien débité")
	var pas := scr.find_child("Cosm_t_pas", true, false) as Button
	_check(pas.get_meta(&"state") == ShopScreen.State.BUYABLE, "article livré : achetable")
	pas.pressed.emit()
	await _frames(3)
	_check(_asked == 1 and sp.rubies == 450 and sp.is_cosmetic_owned("t_pas"), "achat confirmé : débité, possédé")
	(scr.find_child("Cosm_t_pas", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(sp.equipped_cosmetic("sillage:pas") == "t_pas" and (scr.find_child("Cosm_t_pas", true, false) as Button).get_meta(&"state") == ShopScreen.State.EQUIPPED, "appui sur un article possédé : équipé")
	scr.show_family(&"ciel")
	await _frames(2)
	var cl := scr.find_child("Cosm_t_ciel", true, false) as Button
	_check(cl.get_meta(&"state") == ShopScreen.State.POOR and (cl.find_child("State", true, false) as Label).text.begins_with("Il manque"), "rubis insuffisants (450 < 600) : « Il manque »")
	cl.pressed.emit()
	await _frames(2)
	_check(_asked == 1 and sp.rubies == 450 and scr.toast_text.begins_with("Il vous manque"), "insuffisant : pas de confirmation, rien débité")
	_check(scr.back_button.custom_minimum_size.y >= 88 and scr.tab_buttons[0].custom_minimum_size.y >= 64, "cibles tactiles (Retour >= 88 px, onglets)")
	scr.queue_free()
	sp.free()
	await _frames(2)

	Profile.end_sandbox()
	_check(not Profile.owned_cosmetics.has(&"t_pas"), "autoload : sortie du bac à sable, rien gardé")
	Cosmetics.data_override = null
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _da_margins(file: String) -> Array:
	var ns := {"left": 24, "top": 24, "right": 24, "bottom": 24}
	var jp := DA + file + ".json"
	if FileAccess.file_exists(jp):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(jp))
		if d is Dictionary:
			ns = (d as Dictionary).get("nine_slice", ns)
	return [float(ns.left), float(ns.top), float(ns.right), float(ns.bottom)]


func _sb_margins(sb: StyleBoxTexture) -> Array:
	return [sb.texture_margin_left, sb.texture_margin_top, sb.texture_margin_right, sb.texture_margin_bottom]
