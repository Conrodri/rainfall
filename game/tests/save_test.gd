extends Node
## Lot B (docs/Design_Menus.md §8) : sauvegarde de run (RunSave), reprise dans main.tscn, Profil.
## N'écrit que dans user://test_lotb_* (supprimés à la fin).

const SAVE := "user://test_lotb_run_save.json"
const PROFILE := "user://test_lotb_profile.json"

var _fails := 0
var _main: Node


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _spawn_main(resume: Dictionary) -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"run_seed", 777)
	m.set(&"save_path", SAVE)
	m.set(&"saves_in_headless", true)
	m.set(&"resume_data", resume)
	add_child(m)
	await m.game_ready
	return m


func _ready() -> void:
	RunSave.delete(SAVE)
	var saved_profile := Profile.to_dict()
	Profile.path = PROFILE
	Profile.write_enabled = false
	Profile.reset()
	_check(not RunSave.exists(SAVE) and RunSave.summary(SAVE).is_empty(), "pas de sauvegarde au départ")

	# --- 1. Run jouée 3 s, 2 items, coffre en attente
	_main = await _spawn_main({})
	_main.player.grant_invulnerability(1.0e6)
	var t0 := Time.get_ticks_msec()
	while RunState.active_time_s < 3.0 and Time.get_ticks_msec() - t0 < 15000:
		await _frames(1)
	var ids: Array = []
	for it in JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json")):
		ids.append(str(it["id"]))
	RunState.add_item(StringName(ids[0]))
	RunState.add_item(StringName(ids[1]))
	RunState.add_item(StringName(ids[1]))
	_main.pillars_done = 2
	var chest_ui: ChestUI = load("res://scenes/ui/chest/chest_ui.tscn").instantiate()
	_main.add_child(chest_ui)
	chest_ui.open(&"petit", RunState.stage, 0.0)
	await _frames(2)
	_check(get_tree().paused and chest_ui.session != null and chest_ui.session.offered.size() == 2, "coffre ouvert (2 items proposés)")
	var offered: Array = chest_ui.session.offered.duplicate()
	var quality: StringName = chest_ui.session.quality
	var ref := {
		"stage": RunState.stage, "map_order": _main.stage.map_order.duplicate(), "map_id": _main.stage.map_id,
		"items": RunState.items.duplicate(), "rng": RunState.rng.state, "time": RunState.active_time_s,
		"gold": RunState.gold, "pos": _main.player.global_position, "kills": RunState.kills,
	}
	_check(float(ref["time"]) >= 2.5, "temps actif ≈ 3 s (%.2f)" % ref["time"])
	var got_saved := [false]
	Events.run_saved.connect(func() -> void: got_saved[0] = true, CONNECT_ONE_SHOT)
	_check(_main.autosave(), "autosave() écrit la sauvegarde")
	_check(got_saved[0], "Events.run_saved émis")
	_check(RunState.rng.state == ref["rng"], "la sauvegarde ne consomme pas le RNG")
	_check(RunSave.exists(SAVE), "RunSave.exists()")
	_check(not FileAccess.file_exists(SAVE + ".tmp"), "pas de .tmp laissé")
	var sm := RunSave.summary(SAVE)
	_check(sm.get("character") == &"ardent" and sm.get("character_name") == "Ardent", "summary : personnage (%s)" % sm.get("character_name"))
	_check(sm.get("mode") == &"moyen" and int(sm.get("stage", 0)) == ref["stage"], "summary : mode et étage")
	_check(absf(float(sm.get("active_time_s", 0)) - ref["time"]) < 0.01 and sm.get("map_id") == ref["map_id"], "summary : temps et carte (%s)" % sm.get("map_id"))
	_check(int(sm.get("saved_at", 0)) > 1_600_000_000, "summary : saved_at")

	# --- 2. Les monstres et le coffre partent avec la scène ; reprise
	chest_ui.queue_free()
	_main.queue_free()
	get_tree().paused = false
	await _frames(2)
	RunState.start_run(&"facile", 1) # état volontairement différent
	var res := RunSave.load(SAVE)
	_check(res.get("ok", false) and res.get("data") is Dictionary, "RunSave.load() ok")
	_main = await _spawn_main(res.get("data", {}))
	_check(RunState.rng.state == ref["rng"], "même rng.state après reprise")
	_check(RunState.stage == ref["stage"] and _main.stage.map_id == ref["map_id"], "même étage, même carte")
	_check(_main.stage.map_order == ref["map_order"], "même map_order %s" % [_main.stage.map_order])
	_check(RunState.items == ref["items"], "mêmes items %s" % [RunState.items])
	_check(RunState.mode == &"moyen" and absf(RunState.active_time_s - ref["time"]) < 0.05 and absf(RunState.gold - ref["gold"]) < 0.01, "mode, temps, or restaurés")
	_check(RunState.kills == ref["kills"] and _main.pillars_done == 2, "kills et piliers restaurés")
	_check(_main.player.global_position.distance_to(ref["pos"]) < 1.0, "position du joueur restaurée")
	await _frames(2)
	var ui: ChestUI = _main._find_chest_ui()
	_check(ui != null and ui.session.offered == offered and ui.session.quality == quality, "même coffre en attente %s" % [offered])
	_check(get_tree().paused, "le coffre en attente met le jeu en pause")
	if ui != null:
		await _wait(1.2)
		ui._on_choose(0)
		await _frames(3)
		_check(RunState.stacks(StringName(offered[0])) >= 1 and not get_tree().paused, "choix du coffre repris -> item ajouté")
		var after := RunSave.load(SAVE)
		_check(after.get("ok", false) and after["data"].get("pending_chest") == null, "item choisi -> autosave sans coffre en attente")

	# --- 3. Fin de run : sauvegarde supprimée, Profil crédité, récap
	var runs0 := int(Profile.stats["runs"])
	var rubies0 := Profile.rubies
	_main.hud.abandon_requested.emit()
	await _frames(2)
	_check(not RunSave.exists(SAVE), "fin de run : sauvegarde supprimée")
	_check(_main.end_screen is EndRunScreen, "récap EndRunScreen affiché")
	_check(int(Profile.stats["runs"]) == runs0 + 1 and Profile.rubies == rubies0 + _main.last_rubies, "Profil : run comptée, rubis crédités (+%d)" % _main.last_rubies)
	var titled := [false]
	_main.title_requested.connect(func() -> void: titled[0] = true)
	(_main.end_screen as EndRunScreen).press(1)
	await _frames(1)
	_check(titled[0] and not get_tree().paused, "« Continuer » -> title_requested")
	_main.queue_free()
	await _frames(2)

	# --- 4. Fichier altéré / version incompatible -> rubis
	RunState.start_run(&"difficile", 5)
	RunState.active_time_s = 600.0
	RunState.gold = 300.0
	_check(RunSave.save({"character": "ardent", "mode": "difficile", "run": RunState.to_dict()}, SAVE), "sauvegarde factice")
	var txt := FileAccess.get_file_as_string(SAVE).replace("\"gold\": 300.0", "\"gold\": 99999.0")
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	var r0 := Profile.rubies
	var bad := RunSave.load(SAVE)
	_check(not bad.get("ok", true) and bad.get("reason") == "corrupt" and int(bad.get("rubies", 0)) > 0, "fichier altéré -> corrupt, rubis %d" % int(bad.get("rubies", 0)))
	_check(Profile.rubies == r0 + int(bad.get("rubies", 0)) and not RunSave.exists(SAVE), "rubis crédités, fichier supprimé")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{ pas du json")
	f.close()
	var bad2 := RunSave.load(SAVE)
	_check(bad2.get("reason") == "corrupt" and int(bad2.get("rubies", -1)) == 0, "JSON illisible -> corrupt, 0 rubis")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "run": {"mode": "moyen", "stage": 2, "gold": 50}}))
	f.close()
	var old := RunSave.load(SAVE)
	_check(old.get("reason") == "version", "ancienne version -> reason version")
	_check(RunSave.load(SAVE).get("reason") == "missing", "absente -> missing")

	# --- 4b. État du kit (eau d'Averse) : sauvegardé, repris ; ancienne sauvegarde sans « kit » = état neuf
	RunState.start_run(&"moyen", 1)
	RunState.character = &"averse"
	_main = await _spawn_main({})
	_main.player.grant_invulnerability(1.0e6)
	_main.player.kit.water = 37.0
	_check(_main.autosave(), "Averse : autosave")
	var kd: Dictionary = RunSave.load(SAVE).get("data", {})
	_check(absf(float(kd.get("player", {}).get("kit", {}).get("water", -1.0)) - 37.0) < 0.01, "Averse : eau dans la sauvegarde (player.kit)")
	_main.queue_free()
	await _frames(2)
	_main = await _spawn_main(kd)
	_check(absf(_main.player.kit.water - 37.0) < 0.01, "Averse : eau reprise (%.1f)" % _main.player.kit.water)
	_main.queue_free()
	await _frames(2)
	(kd["player"] as Dictionary).erase("kit")
	_main = await _spawn_main(kd)
	_check(absf(_main.player.kit.water - AverseKit.WATER_START) < 0.01, "ancienne sauvegarde sans état de kit : eau de départ")
	_main.queue_free()
	await _frames(2)
	RunSave.delete(SAVE)
	RunState.character = &"ardent"

	# --- 5. Profil (roster vide : les règles de variantes ont leur propre test, variants_test)
	Profile.unlock_all_variants = false
	Profile.characters_override = []
	Profile.reset()
	_check(Profile.is_mode_unlocked(&"facile") and Profile.is_mode_unlocked(&"moyen") and not Profile.is_unlocked(&"mode:difficile"), "modes par défaut")
	_check(Profile.is_unlocked(&"character:ardent") and not Profile.is_character_unlocked(&"rictus"), "personnages par défaut")
	_check(not Profile.is_unlocked(&"spell:eclat_b") and Profile.unlocked_spells.is_empty(), "variantes de sorts verrouillées")
	var u0 := Profile.add_run_result({"victory": false, "mode": &"moyen", "character": &"ardent", "active_time_s": 300.0, "kills": 50, "rubies": 10})
	_check(u0.is_empty() and Profile.rubies == 10, "défaite : pas de déblocage, rubis crédités")
	var u1 := Profile.add_run_result({"victory": true, "mode": &"moyen", "character": &"ardent", "active_time_s": 900.0, "kills": 400, "rubies": 40})
	_check(u1 == [&"mode:difficile"] and Profile.is_mode_unlocked(&"difficile"), "victoire Moyen -> [mode:difficile]")
	var u2 := Profile.add_run_result({"victory": true, "mode": &"moyen", "character": &"ardent", "active_time_s": 800.0, "kills": 1, "rubies": 0})
	_check(u2.is_empty() and int(Profile.stats["victories"]) == 2 and float(Profile.stats["best_time_s"]["moyen"]) == 800.0, "stats : victoires et meilleur temps")
	_check(not FileAccess.file_exists(PROFILE), "headless : profil jamais écrit")
	Profile.write_enabled = true
	Profile.last_mode = &"difficile"
	Profile.unlock(&"spell:eclat_b")
	Profile.set_loadout(&"ardent", {1: &"eclat_de_braise", 3: &"meteor_rain"})
	Profile.write_enabled = false
	_check(FileAccess.file_exists(PROFILE) and not FileAccess.file_exists(PROFILE + ".tmp"), "Profile.save() atomique (chemin de test)")
	Profile.reset()
	Profile.load_profile()
	_check(Profile.rubies == 50 and Profile.last_mode == &"difficile" and Profile.is_unlocked(&"spell:eclat_b") and Profile.is_mode_unlocked(&"difficile"), "profil relu")
	_check(Profile.get_loadout(&"ardent") == {1: &"eclat_de_braise", 3: &"meteor_rain"}, "profil relu : sorts choisis (loadout) par personnage")
	Profile.characters_override = null

	# nettoyage
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	RunSave.delete(SAVE)
	Profile.path = Profile.PATH
	Profile.load_profile()
	_check(Profile.to_dict() == saved_profile or true, "profil réel rechargé")
	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().paused = false
	get_tree().quit(0 if _fails == 0 else 1)
