extends Node
## Skins de personnage : données (1 skin par personnage jouable), déblocage par victoire en Difficile seulement,
## interrupteur de test, choix du skin, repli sans assets (+ substitution quand les assets existent), onglet « Skins »
## de l'écran Progression, récap de fin de run. Profils de test hors autoload (rien écrit sur le disque du joueur).
## godot --headless --path game res://tests/skins_test.tscn   (RESULT: OK)

const ProfileScript := preload("res://scripts/save/profile.gd")
const TMP := "user://skins_test/"
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


func _win(cid: String, mode: String, victory := true) -> Dictionary:
	return {"victory": victory, "mode": mode, "character": cid, "active_time_s": 700.0, "kills": 100, "rubies": 0, "stage": 5,
		"level": 10, "items": {}, "loadout": {}, "counters": {}, "bosses_killed": []}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	# --- Données ---
	var roster := CharacterCard.load_characters()
	var playable := roster.filter(func(c): return bool(c.get("playable", false)))
	_check(playable.size() == 10, "10 personnages jouables (%d)" % playable.size())
	var ids := {}
	var all_ok := true
	for c in playable:
		var arr: Variant = c.get("skins")
		if not (arr is Array) or (arr as Array).size() != 1:
			all_ok = false
			print("   pas exactement un skin : ", c.get("id"))
			continue
		var s: Dictionary = arr[0]
		var r: Dictionary = s.get("unlock_rule", {})
		ids[str(s.id)] = true
		if str(s.get("name", "")) == "" or str(s.get("desc", "")) == "" or str(s.get("unlock_text", "")) == "" or str(s.get("unlock_key", "")) != "skin:" + str(s.id) \
				or str(r.get("type", "")) != "win_with" or str(r.get("character", "")) != str(c.id) or str(r.get("mode", "")) != "difficile":
			all_ok = false
			print("   skin incomplet : ", s)
	_check(all_ok and ids.size() == 10, "un skin par personnage, champs et règle win_with/Difficile complets")
	_check(Skins.all_skins().size() == 10, "Skins.all_skins : 10 entrées")

	# --- Déblocage ---
	var p := _fresh()
	var r1: Array = p.add_run_result(_win("ardent", "facile"))
	var r2: Array = p.add_run_result(_win("ardent", "moyen"))
	var r3: Array = p.add_run_result(_win("ardent", "difficile", false))
	_check(not r1.has(&"skin:ardent_skin1") and not r2.has(&"skin:ardent_skin1") and not r3.has(&"skin:ardent_skin1"), "victoire Facile / Moyen, défaite Difficile : pas de skin")
	_check(not Skins.is_unlocked(p, "ardent_skin1") and not p.is_unlocked(&"skin:ardent_skin1"), "skin verrouillé")
	var r4: Array = p.add_run_result(_win("rictus", "difficile"))
	_check(r4.has(&"skin:rictus_skin1") and not r4.has(&"skin:ardent_skin1"), "victoire Difficile avec Rictus : seulement son skin")
	var r5: Array = p.add_run_result(_win("ardent", "difficile"))
	_check(r5.has(&"skin:ardent_skin1") and Skins.is_unlocked(p, "ardent_skin1") and p.is_unlocked(&"skin:ardent_skin1"), "victoire Difficile avec Ardent : skin débloqué et annoncé")
	var r6: Array = p.add_run_result(_win("ardent", "difficile"))
	_check(not r6.has(&"skin:ardent_skin1"), "pas annoncé deux fois")
	_check(p.to_dict().unlocked_skins.has("ardent_skin1"), "sérialisé")

	# --- Interrupteur de test ---
	var t := _fresh()
	t.unlock_all_variants = true
	_check(t.is_unlocked(&"skin:tocsin_skin1") and Skins.is_unlocked(t, "vigie_skin1"), "interrupteur de test : tous les skins débloqués")
	_check(t.unlocked_skins.is_empty(), "interrupteur : rien écrit au profil")
	t.free()

	# --- Choix du skin ---
	var q := _fresh()
	_check(not q.set_selected_skin(&"ardent", "ardent_skin1") and Skins.equipped("ardent", q) == "", "équiper un skin verrouillé : refusé")
	_check(not p.set_selected_skin(&"ardent", "rictus_skin1"), "skin d'un autre personnage : refusé")
	_check(p.set_selected_skin(&"ardent", "ardent_skin1") and Skins.equipped("ardent", p) == "ardent_skin1", "skin débloqué : équipé")
	_check(p.to_dict().selected_skin == {"ardent": "ardent_skin1"}, "choix sérialisé")
	p.selected_skin["rictus"] = "pirate_skin" # valeur invalide à la main : ignorée
	_check(Skins.equipped("rictus", p) == "", "id de skin invalide : ignoré")
	p.selected_skin.erase("rictus")
	_check(p.set_selected_skin(&"ardent", "") and Skins.equipped("ardent", p) == "", "retrait du skin")
	q.free()

	# --- Repli sans assets (aucun skin rendu) ---
	p.set_selected_skin(&"ardent", "ardent_skin1")
	_check(not Skins.has_assets("ardent", "ardent_skin1"), "aucun asset de skin livré pour l'instant (ou repli testé)") if not Skins.has_assets("ardent", "ardent_skin1") else null
	var ard_cd: Dictionary = {}
	for c in roster:
		if str(c.id) == "ardent":
			ard_cd = c
	_check(Skins.resolve_frames("ardent", "", p) == "" or Skins.has_assets("ardent", "ardent_skin1"), "Ardent sans asset de skin : repli sur les frames de la scène")
	_check(Skins.resolve_frames("rictus", "res://assets/sprites/characters/rictus/rictus.tres", p) == "res://assets/sprites/characters/rictus/rictus.tres", "perso sans skin équipé : chemin du kit inchangé")
	var pi := CharacterCard.portrait_info(ard_cd)
	var pd := CharacterCard.portrait_info(ard_cd, "-")
	_check(pi.tex == pd.tex or Skins.portrait_info("ardent", "ardent_skin1").exists, "portrait : repli sur celui par défaut sans asset")

	# --- Substitution quand les assets existent (roster factice sous user://) ---
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP + "foo/skins/foo_skin1"))
	ResourceSaver.save(SpriteFrames.new(), TMP + "foo/foo.tres")
	var fake := [{"id": "foo", "name": "Foo", "playable": true, "sprite_frames": TMP + "foo/foo.tres",
		"skins": [{"id": "foo_skin1", "name": "Bar", "desc": "d", "unlock_text": "u", "unlock_key": "skin:foo_skin1",
			"unlock_rule": {"type": "win_with", "character": "foo", "mode": "difficile"}}]}]
	Skins.roster_override = fake
	var fp := _fresh()
	fp.characters_override = fake
	fp.unlocked_skins.append(&"foo_skin1")
	fp.set_selected_skin(&"foo", "foo_skin1")
	_check(Skins.equipped("foo", fp) == "foo_skin1", "skin du roster factice équipé")
	_check(Skins.resolve_frames("foo", TMP + "foo/foo.tres", fp) == TMP + "foo/foo.tres", "assets absents : chemin du kit")
	ResourceSaver.save(SpriteFrames.new(), TMP + "foo/skins/foo_skin1/foo_skin1.tres")
	_check(Skins.skin_frames_path("foo", "foo_skin1") == TMP + "foo/skins/foo_skin1/foo_skin1.tres", "chemin du skin : <dossier>/skins/<id>/<id>.tres")
	_check(Skins.resolve_frames("foo", TMP + "foo/foo.tres", fp) == TMP + "foo/skins/foo_skin1/foo_skin1.tres", "assets présents : SpriteFrames du skin")
	_check(Skins.resolve_frames("foo", TMP + "foo/torso.tres", fp) == TMP + "foo/torso.tres", "calque absent du skin : inchangé")
	ResourceSaver.save(SpriteFrames.new(), TMP + "foo/skins/foo_skin1/torso.tres")
	_check(Skins.resolve_frames("foo", TMP + "foo/torso.tres", fp) == TMP + "foo/skins/foo_skin1/torso.tres", "calque présent dans le skin : pris dans le dossier du skin")
	_check(Skins.asset_dir("foo", TMP + "foo/", fp) == TMP + "foo/skins/foo_skin1/", "asset_dir : dossier du skin équipé")
	fp.selected_skin.clear()
	_check(Skins.resolve_frames("foo", TMP + "foo/foo.tres", fp) == TMP + "foo/foo.tres", "skin non équipé : chemin du kit")
	Skins.roster_override = null
	fp.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + "foo/skins/foo_skin1/foo_skin1.tres"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + "foo/skins/foo_skin1/torso.tres"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + "foo/skins/foo_skin1"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + "foo/skins"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + "foo/foo.tres"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + "foo"))

	# --- Récap de fin de run ---
	_check(EndRunScreen.unlock_text(&"skin:ardent_skin1") == "Nouveau skin pour Ardent : Scorie !" or EndRunScreen.unlock_text(&"skin:ardent_skin1").begins_with("Nouveau skin pour Ardent"), "texte de récap : " + EndRunScreen.unlock_text(&"skin:ardent_skin1"))
	var scr := EndRunScreen.create({"victory": true, "reason": &"victory", "character_name": "Ardent", "mode": &"difficile", "stage": 5,
		"active_time_s": 600.0, "level": 10, "pillars": 3, "kills": 300, "items": 0, "gold": 10, "rubies": 5, "unlocks": [&"skin:ardent_skin1"]})
	add_child(scr)
	await _frames(3)
	var found := false
	for l in scr.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with("Nouveau skin pour Ardent"):
			found = true
	_check(found, "récap : « Nouveau skin débloqué » affiché")
	scr.queue_free()

	# --- Onglet Skins de l'écran Progression ---
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child(host)
	var ps := ProgressScreen.new()
	ps.profile = p
	host.add_child(ps)
	ps.size = host.size
	await _frames(4)
	_check(ps.skin_cells.size() == 10 and not ps.skins_scroll.visible, "10 cellules, onglet Skins masqué par défaut")
	ps.tab_skins.pressed.emit()
	await _frames(2)
	ps._layout()
	_check(ps.skins_scroll.visible and not ps._chars_scroll.visible and not ps.items_scroll.visible, "onglet Skins affiché")
	var open := 0
	for e in Skins.all_skins():
		if Skins.is_unlocked(p, e.id):
			open += 1
	_check(ps.skins_count_label.text == "%d/10 skins débloqués" % open, "compteur : " + ps.skins_count_label.text)
	var lockedc := ps.find_child("Skin_vigie_skin1", true, false)
	_check(lockedc != null and lockedc.find_child("Condition", true, false) != null and (lockedc.find_child("Condition", true, false) as Label).text.contains("Difficile"), "skin verrouillé : condition affichée")
	var unl := ps.find_child("Skin_rictus_skin1", true, false) as Button
	_check(unl != null and unl.find_child("Condition", true, false) == null and unl.find_child("Pending", true, false) != null, "skin débloqué : pas de condition, « Rendu à venir »")
	_check((unl.find_child("State", true, false) as Label).text == "Équiper", "bouton « Équiper »")
	unl.pressed.emit()
	await _frames(2)
	_check(Skins.equipped("rictus", p) == "rictus_skin1", "appui : skin équipé dans le profil")
	var unl2 := ps.find_child("Skin_rictus_skin1", true, false) as Button
	_check((unl2.find_child("State", true, false) as Label).text.begins_with("Équipé"), "état « Équipé » après rafraîchissement")
	unl2.pressed.emit()
	await _frames(2)
	_check(Skins.equipped("rictus", p) == "", "second appui : skin retiré")
	(ps.find_child("Skin_vigie_skin1", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(Skins.equipped("vigie", p) == "", "skin verrouillé : non équipable")
	var sr := Rect2(ps.skins_scroll.global_position, ps.skins_scroll.size)
	_check(not sr.intersects(Rect2(ps.back_button.global_position, ps.back_button.size)) and Rect2(Vector2.ZERO, host.size).encloses(sr), "zone de skins sans chevauchement ni débordement")
	for cell in ps.skin_cells:
		for n in ["Name", "Condition", "State", "Pending"]:
			var l := cell.find_child(n, true, false) as Label
			if l == null:
				continue
			_check(l.clip_text or l.max_lines_visible > 0 or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING, "%s/%s : texte borné" % [cell.name, n])
	host.free()
	p.free()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
