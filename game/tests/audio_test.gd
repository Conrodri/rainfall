extends Node
## Tests du système audio : sounds.json, fichiers manquants, plafond de voix, puissance des coups,
## agrégation, pas/surface, pièces, réglages persistés, ducking, pause.
## godot --headless --path game res://tests/audio_test.tscn

const SynthFallback := preload("res://scripts/audio/synth_fallback.gd")
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)
	else:
		print("ok:   ", msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _ready() -> void:
	await get_tree().process_frame
	var A := Audio
	# 1) sounds.json
	_check(A.bank.load_ok, "sounds.json chargé")
	_check(A.bank.families.has("impacts") and A.bank.sounds.has("hit.light") and A.bank.maps.has("foret_brume"), "familles, sons et cartes présents")
	for b in ["Master", "Music", "SFX", "Spells", "Impacts", "Footsteps", "UI", "Ambience"]:
		_check(AudioServer.get_bus_index(b) != -1, "bus " + b)
	_check(AudioServer.get_bus_effect_count(0) >= 2, "compresseur + limiteur sur Master")

	# 2) fichiers manquants : aucun crash
	A.bank.clear_overrides()
	var r1 := A.play(&"hit.light", Vector2.ZERO)
	var r2 := A.play(&"n.existe.pas")
	A.play_hit(&"inconnu", 50.0, true, Vector2(10, 10))
	A.flush_hits()
	A.footstep(&"player", Vector2.ZERO)
	A.thunder(0.0)
	A.start_map("foret_brume")
	A.start_map("carte_inexistante")
	A.play_chest_sequence(&"legendaire")
	A.play_coin()
	_check(not r2, "id inconnu -> false sans crash")
	_check(true, "aucun crash avec sons manquants (hit.light joué=%s)" % r1)

	# 3) classification light/medium/heavy relative au Dégât_base
	var cfg: Dictionary = A.bank.config.get("hit_power", {})
	var base := Balance.player_base_damage(1)
	_check(A.classify_hit(base * 0.8, base, false, cfg).name == "light", "0,8x base = light")
	_check(A.classify_hit(base * 2.0, base, false, cfg).name == "medium", "2x base = medium")
	_check(A.classify_hit(base * 5.0, base, false, cfg).name == "heavy", "5x base = heavy")
	_check(A.classify_hit(base * 0.8, base, true, cfg).name == "medium", "crit relève light -> medium")
	_check(A.classify_hit(base * 2.0, base, true, cfg).name == "heavy", "crit relève medium -> heavy")
	var base10 := Balance.player_base_damage(10)
	_check(A.classify_hit(30.0, base10, false, cfg).name == "light", "30 dégâts au niveau 10 = light (relatif)")
	_check(A.classify_hit(50.0, base, false, cfg).name == "heavy", "50 dégâts au niveau 1 = heavy")
	var lo := A.classify_hit(base * 0.5, base, false, cfg)
	var hi := A.classify_hit(base * 6.0, base, false, cfg)
	_check(hi.pitch < lo.pitch and hi.vol_db > lo.vol_db, "coup lourd : plus grave et plus fort")

	# 4) plafond de voix sous 300 événements par image
	var ting := SynthFallback.make_ting(440.0, 1.5)
	for id in ["hit.light", "hit.medium", "hit.heavy", "death.t1", "death.t2", "death.t3", "death.elite", "spell.cast", "step.generic", "step.monster", "step.player"]:
		A.bank.set_override(StringName(id), [ting])
	var t := [0]
	A.game_pool.clock_ms = func() -> int:
		t[0] += 80
		return t[0]
	var ids := ["hit.light", "hit.medium", "hit.heavy", "death.t1", "death.t2", "death.t3", "spell.cast"]
	var worst_total := 0
	var worst_inst := 0
	var worst_imp := 0
	var worst_spl := 0
	var worst_stp := 0
	for i in 300:
		A.play(StringName(ids[i % ids.size()]), Vector2(i % 17 * 20, i % 11 * 20))
		A.footstep(&"monster_t1", Vector2(i % 13 * 15, 0), &"stone")
		worst_imp = maxi(worst_imp, A.game_pool.active_in_family("impacts"))
		worst_spl = maxi(worst_spl, A.game_pool.active_in_family("spells"))
		worst_stp = maxi(worst_stp, A.game_pool.active_in_family("footsteps_monster"))
		worst_total = maxi(worst_total, A.game_pool.active_total())
		for id in ids:
			worst_inst = maxi(worst_inst, A.game_pool.active_of_sound(StringName(id)))
	_check(worst_imp <= int(A.game_pool.family_caps["impacts"]) and worst_imp > 0, "famille impacts <= plafond (%d/%d)" % [worst_imp, A.game_pool.family_caps["impacts"]])
	_check(worst_spl <= int(A.game_pool.family_caps["spells"]), "famille spells <= plafond (%d)" % worst_spl)
	_check(worst_stp <= int(A.game_pool.family_caps["footsteps_monster"]), "pas monstres <= plafond (%d)" % worst_stp)
	_check(worst_total <= A.game_pool.voices.size(), "total <= voix du pool (%d/%d)" % [worst_total, A.game_pool.voices.size()])
	_check(worst_inst <= 3, "instances simultanées d'un même son <= 3 (%d)" % worst_inst)
	_check(A.game_pool.stats.stolen > 0, "vol de voix utilisé (%d)" % A.game_pool.stats.stolen)
	# priorité : un son moins prioritaire ne vole pas un son plus prioritaire
	A.game_pool.stop_all()
	for i in 12:
		t[0] += 500
		A.play(&"death.elite", Vector2(i * 5, 0))
	var elite_n := A.game_pool.active_of_sound(&"death.elite")
	for i in 5:
		t[0] += 500
		A.play(&"hit.light", Vector2.ZERO)
	_check(elite_n >= 1 and A.game_pool.active_of_sound(&"death.elite") == elite_n, "priorité basse ne vole pas l'élite (%d)" % elite_n)

	# 5) agrégation : 300 enemy_damaged -> peu de sons
	A.game_pool.stop_all()
	var dummy := Node2D.new()
	add_child(dummy)
	for i in 300:
		dummy.global_position = Vector2(i * 37 % 1500, i * 53 % 900)
		Events.enemy_damaged.emit(dummy, 12.0 + i % 40, i % 9 == 0, &"")
	A.flush_hits()
	var st: Dictionary = A.last_flush_stats()
	_check(st.events == 300, "300 événements reçus")
	_check(st.played <= 4, "sons de coups joués par image <= 4 (%d)" % st.played)
	for i in 300:
		Events.enemy_killed.emit(dummy, Vector2(i * 31 % 1200, i * 47 % 800), 1 + i % 3, i % 20 == 0)
	A.flush_hits()
	_check(A.game_pool.active_total() <= A.game_pool.voices.size(), "morts agrégées sans dépasser le pool")

	# 6) pas et surface
	A.start_map("foret_brume")
	var grid: Array = A._map_grid
	var water := Vector2.INF
	for y in grid.size():
		var x := String(grid[y]).find("~")
		if x != -1:
			var cu := float(A._map_info.get("grid_cell_u", 2))
			var sz: Array = A._map_info.get("size_u")
			water = Vector2(((x + 0.5) * cu - float(sz[0]) * 0.5) * 64.0, ((y + 0.5) * cu - float(sz[1]) * 0.5) * 64.0)
			break
	_check(is_finite(water.x) and A.surface_at(water) == &"water", "surface water déduite de la grille")
	_check(A.surface_at(Vector2(99999, 99999)) == &"dirt", "hors carte -> surface par défaut de la carte (dirt, fichiers step_*_dirt)")
	A.start_map("cite_rouille")
	_check(A.surface_at(Vector2(32, 32)) in [&"metal", &"water"], "carte Cité : sol métal")

	# 7) pièces en chaîne pentatonique
	A.play_coin()
	A.play_coin()
	var step_a := A.coin_chain_step()
	for i in 20:
		A.play_coin()
	_check(step_a >= 1 and A.coin_chain_step() == 12, "chaîne de pièces monte puis plafonne à 12")

	# 8) réglages persistés
	# fichier injecté : le settings.cfg réel du joueur n'est ni lu ni écrit
	var real_path: String = A.settings_path
	A.settings_path = "user://test_audio_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(A.settings_path))
	var real_existed := FileAccess.file_exists(A.SETTINGS_PATH)
	var real_mtime := FileAccess.get_modified_time(A.SETTINGS_PATH) if real_existed else 0
	var old_music := A.get_volume("music")
	A.set_volume("music", 0.37)
	A.save_settings()
	A.load_settings()
	_check(absf(A.get_volume("music") - 0.37) < 0.001, "volume musique persisté dans settings.cfg")
	var mi := AudioServer.get_bus_index("Music")
	A.set_volume("music", 0.37)
	_check(AudioServer.get_bus_volume_db(mi) < -3.0, "bus Music réglé (%.1f dB)" % AudioServer.get_bus_volume_db(mi))
	A.set_volume("music", old_music)
	A.save_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(A.settings_path))
	A.settings_path = real_path
	A.save_settings() # chemin réel en headless : ignoré
	_check(FileAccess.file_exists(A.SETTINGS_PATH) == real_existed and (not real_existed or FileAccess.get_modified_time(A.SETTINGS_PATH) == real_mtime), "headless : settings.cfg du joueur inchangé")

	# 9) ducking (laisse retomber celui du coffre légendaire de la section 2)
	await _wait(3.5)
	A.duck(9.0, 0.15, 0.03, 0.2)
	await _wait(0.12)
	_check(A.current_duck_db() < -3.0, "ducking appliqué (%.1f dB)" % A.current_duck_db())
	await _wait(0.9)
	_check(absf(A.current_duck_db()) < 0.5, "ducking relâché")
	A.duck_event(&"boss")
	await _wait(0.2)
	_check(A.current_duck_db() < -2.0, "duck_event(boss) actif")
	await _wait(3.5)

	# 10) pause : SFX de jeu suspendus, UI continue, musique baissée
	_check(A.game_pool.process_mode == Node.PROCESS_MODE_PAUSABLE and A.ui_pool.process_mode == Node.PROCESS_MODE_ALWAYS, "pools : jeu pausable, UI toujours actif")
	var db_normal := AudioServer.get_bus_volume_db(mi)
	get_tree().paused = true
	await _wait(0.5)
	var db_paused := AudioServer.get_bus_volume_db(mi)
	A.play_ui(&"pickup.coin")
	get_tree().paused = false
	await _wait(0.5)
	_check(db_paused < db_normal - 4.0, "musique baissée en pause (%.1f -> %.1f dB)" % [db_normal, db_paused])
	_check(AudioServer.get_bus_volume_db(mi) > db_paused + 4.0, "musique rétablie à la reprise")

	# 11) tonnerre
	A.thunder_after(0.0, 0.5)
	A.thunder(3.0)
	_check(true, "tonnerre sans crash")

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
