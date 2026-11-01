extends Node
## Présages d'étage (docs/Ateliers_Chiffres.md §9) : données, plan de run déterministe (défi du jour), effets de chacun des 8
## présages sur les vrais systèmes (joueur, monstres, director, coffres, capsules), retrait à l'étage suivant, choix
## obligatoire en Difficile / « Ciel clair » en Moyen sur la vraie scène de jeu, sauvegarde, rubis, historique, panneau de test.
## godot --headless --path game res://tests/omen_test.tscn   (RESULT: OK)

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	print("ok   " if ok else "FAIL ", msg)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()


func _ready() -> void:
	_run.call_deferred()


func _near(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) <= eps


func _run() -> void:
	Platform.set_input_mode(Platform.InputMode.KBM)
	_test_data()
	_test_plan()
	_test_offer()
	_test_accessors()
	_test_save_and_rubies()
	await _test_systems()
	await _test_flow(&"difficile")
	await _test_flow(&"moyen")
	await _test_panel_and_history()
	RunState.start_run(&"moyen", 1)
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


# --- données --------------------------------------------------------------------------------------

func _test_data() -> void:
	var all := Omens.all()
	_check(all.size() == 8, "8 présages dans data/omens.json")
	var groups := {}
	for e in all:
		groups[e["group"]] = int(groups.get(e["group"], 0)) + 1
		_check(Omens.icon_of(StringName(e["id"])) != null, "%s : icône (repli sur un objet proche ou icône Codex)" % e["id"])
		_check(str(e["text"]) != "" and str(e["name"]) != "", "%s : nom et texte" % e["id"])
	_check(groups.get(&"combat", 0) == 4 and groups.get(&"butin", 0) == 4, "4 présages de combat + 4 de butin")
	var clear := Omens.get_omen(Balance.OMEN_CLEAR_ID)
	_check(not clear.is_empty() and Omens.icon_of(Balance.OMEN_CLEAR_ID) != null, "Ciel clair : entrée et icône")
	_check((Omens.get_omen(&"eveil_des_elites")["floors"] as Array) == [2, 3, 4], "Éveil : étages 2-4")
	_check((Omens.get_omen(&"maree")["effects_by_floor"] as Dictionary).has(2), "Marée : surcharge à l'étage 2")
	_check(Balance.OMEN_MANDATORY_MODES == [&"difficile"] and Balance.omen_mandatory(&"difficile") and not Balance.omen_mandatory(&"moyen")
		and not Balance.omen_mandatory(&"facile"), "obligatoire en Difficile seulement")
	_check(Balance.OMEN_RUBIES == 2 and Balance.omen_rubies(3) == 6 and Balance.omen_rubies(0) == 0, "OMEN_RUBIES = 2 par présage")


# --- plan de run ----------------------------------------------------------------------------------

func _test_plan() -> void:
	var ok_all := true
	var no_repeat := true
	var differs := false
	var first: Dictionary = Omens.plan(1)
	for seed_v in range(1, 301):
		var p: Dictionary = Omens.plan(seed_v)
		if p != Omens.plan(seed_v):
			ok_all = false
		if p != first:
			differs = true
		for g in Omens.GROUPS:
			var seen := {}
			for stage in range(2, 6):
				var id := StringName(str((p[stage] as Dictionary).get(g, "")))
				if id == &"" or not Omens.allowed_on(id, stage) or Omens.get_omen(id)["group"] != g:
					ok_all = false
				if seen.has(id):
					no_repeat = false
				seen[id] = true
	_check(ok_all, "plan : chaque étage 2-5 a un présage de combat et un de butin, permis à l'étage, stable pour une graine (300 graines)")
	_check(no_repeat, "plan : jamais le même présage proposé deux fois dans une run")
	_check(differs, "plan : varie selon la graine")
	# défi du jour : mêmes cartes pour tous (graine du date)
	var key := 20261101
	var seed_day := DailyChallenge.seed_for(key)
	var a := Omens.offer(3, seed_day, &"moyen").map(func(e): return e["id"])
	var b := Omens.offer(3, DailyChallenge.seed_for(key), &"moyen").map(func(e): return e["id"])
	var c := Omens.offer(3, DailyChallenge.seed_for(20261102), &"moyen").map(func(e): return e["id"])
	_check(a == b and a.size() == 3, "défi du jour : cartes identiques pour tous les joueurs du même jour")
	_check(a != c or Omens.plan(seed_day) != Omens.plan(DailyChallenge.seed_for(20261102)), "défi du jour : le lendemain, autres cartes")


func _test_offer() -> void:
	var d := Omens.offer(2, 42, &"difficile")
	_check(d.size() == 2 and d[0]["group"] == &"combat" and d[1]["group"] == &"butin", "Difficile : 2 cartes (combat, butin)")
	_check(not d.any(func(e): return e["id"] == String(Balance.OMEN_CLEAR_ID)), "Difficile : pas de Ciel clair")
	for m in [&"moyen", &"facile"]:
		var o := Omens.offer(2, 42, m)
		_check(o.size() == 3 and o[2]["id"] == String(Balance.OMEN_CLEAR_ID), "%s : 3 cartes dont Ciel clair en dernier" % m)
	_check(Omens.offer(1, 42, &"moyen").is_empty() and Omens.offer(6, 42, &"moyen").is_empty(), "étage 1 et sans fin : aucun présage")
	_check(Omens.floor_has_omen(2) and Omens.floor_has_omen(5) and not Omens.floor_has_omen(1) and not Omens.floor_has_omen(6), "étages 2 à 5")


# --- lecteurs d'effets (table 9.2) ----------------------------------------------------------------

func _force(id: StringName, stage: int) -> void:
	RunState.stage = stage
	RunState.omen = id


func _test_accessors() -> void:
	RunState.start_run(&"moyen", 11)
	_force(&"", 3)
	_check(Omens.damage_taken_total_mult() == 1.0 and Omens.chest_price_mult() == 1.0 and Omens.boss_chest_enabled() and Omens.arrival_chest() == &""
		and Omens.monster_hp_mult(3, true) == 1.0 and Omens.capsule_gold_mult() == 1.0 and Omens.kill_gold_mult() == 1.0, "sans présage : tout neutre")
	_force(&"pluie_de_cendres", 3)
	var st := {}
	Omens.adjust_player_stats(st)
	_check(_near(Omens.monster_damage_mult(), 1.25) and _near(float(st["damage_mult"]), 1.25) and not st.has("cooldown_mult"), "Pluie de cendres : monstres ×1,25, vos dégâts ×1,25")
	var st2 := {"damage_mult": 1.2}
	Omens.adjust_player_stats(st2)
	_check(_near(float(st2["damage_mult"]), 1.5), "Pluie de cendres : multiplicatif avec les objets (1,2 × 1,25)")
	_force(&"carapaces", 3)
	_check(_near(Omens.monster_hp_mult(2, false), 1.35) and _near(Omens.monster_hp_mult(3, false), 1.35) and Omens.monster_hp_mult(1, false) == 1.0
		and _near(Omens.monster_hp_mult(1, true), 1.35) and _near(Omens.player_max_hp_mult(), 1.15), "Carapaces : tireurs / bondisseurs / brutes / élites ×1,35, essaim inchangé, PV max ×1,15")
	_force(&"fievre", 3)
	var st3 := {}
	Omens.adjust_player_stats(st3)
	_check(_near(Omens.damage_taken_total_mult(), 1.2) and _near(float(st3["cooldown_mult"]), 0.77), "Fièvre : dégâts subis ×1,2, recharges ×0,77")
	var st4 := {"cooldown_mult": 0.4}
	Omens.adjust_player_stats(st4)
	_check(_near(float(st4["cooldown_mult"]), Balance.COOLDOWN_FLOOR), "Fièvre : le plancher COOLDOWN_FLOOR reste appliqué")
	_force(&"eveil_des_elites", 3)
	var D := 2.0
	var base := Balance.elite_chance(D)
	_check(_near(Omens.elite_chance(D), minf(base * 2.0, 0.4)) and Omens.elite_chance(D) > base and _near(Omens.elite_boss_damage_mult(), 1.15), "Éveil : chance d'élite ×2, +15 % contre élites et boss")
	_check(_near(Omens.elite_chance(40.0), 0.4), "Éveil : plafond 0,40 (OMEN_ELITE_CHANCE_CAP)")
	_check(Omens.wave_leader_chance(D) > Balance.wave_leader_chance(D) and Omens.wave_leader_chance(D) <= Balance.WAVE_LEADER_MAX, "Éveil : meneurs de vague plus fréquents (D=2)")
	_force(&"marche_noir", 3)
	_check(_near(Omens.chest_price_mult(), 1.3) and _near(Omens.capsule_gold_mult(), 2.0), "Marché noir : prix ×1,3, capsules ×2")
	_force(&"offrande", 3)
	_check(_near(Omens.kill_gold_mult(), 0.65) and Omens.arrival_chest() == &"guardian", "Offrande : or des monstres ×0,65, reliquaire d'arrivée")
	_force(&"usure", 3)
	_check(not Omens.boss_chest_enabled() and _near(Omens.chest_price_mult(), 0.8), "Usure : pas de coffre de boss, prix ×0,8")
	_force(&"maree", 3)
	_check(_near(Omens.director_credit_mult(), 1.25), "Marée étage 3 : crédits ×1,25")
	_force(&"maree", 2)
	_check(_near(Omens.director_credit_mult(), 1.15), "Marée étage 2 : crédits ×1,15 (effects_by_floor)")
	_force(Balance.OMEN_CLEAR_ID, 3)
	_check(Omens.damage_taken_total_mult() == 1.0 and Omens.chest_price_mult() == 1.0 and not Omens.is_active(), "Ciel clair : aucun effet")
	_force(&"", 1)


func _test_save_and_rubies() -> void:
	RunState.start_run(&"difficile", 5)
	RunState.stage = 3
	RunState.set_omen(&"fievre")
	RunState.stage = 4
	RunState.set_omen(Balance.OMEN_CLEAR_ID)
	RunState.stage = 5
	RunState.set_omen(&"offrande")
	RunState.omen_pending = true
	_check(RunState.omens_accepted() == 2 and Balance.omen_rubies(RunState.omens_accepted()) == 4, "rubis : Ciel clair ne compte pas (2 présages acceptés = 4)")
	var d := JSON.parse_string(JSON.stringify(RunState.to_dict())) as Dictionary
	RunState.start_run(&"moyen", 9)
	_check(RunState.omen == &"" and RunState.omens_taken.is_empty(), "start_run remet les présages à zéro")
	RunState.from_dict(d)
	_check(RunState.omen == &"offrande" and RunState.omen_pending and RunState.omens_taken == {3: "fievre", 4: "ciel_clair", 5: "offrande"}, "sauvegarde : présage actif, choix en attente et choix par étage rechargés")
	RunState.from_dict({"mode": "moyen", "stage": 3})
	_check(RunState.omen == &"" and not RunState.omen_pending, "ancienne sauvegarde sans présage : neutre")
	_check(RunState.omens_taken_text() == {}, "texte vide sans choix")


# --- systèmes : joueur, monstres, director, coffres, capsules ------------------------------------

func _test_systems() -> void:
	RunState.start_run(&"moyen", 21)
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	var dir: Director = load("res://scenes/enemies/director.tscn").instantiate()
	dir.enemy_pool_size = 12
	dir.spawn_ramp = false
	dir.waves_enabled = false
	add_child(dir)
	await _frames(2)
	dir.set_physics_process(false)
	dir.set_process(false)

	# joueur : PV max, dégâts subis, dégâts infligés, recharges
	var hp0: float = player.max_hp
	_check(hp0 > 0.0 and float(player.stat(&"damage_mult")) <= 0.0, "joueur : base sans présage")
	RunState.stage = 3
	RunState.set_omen(&"carapaces", false)
	_check(_near(player.max_hp, hp0 * 1.15, 0.01), "Carapaces : PV max ×1,15 (%.1f -> %.1f)" % [hp0, player.max_hp])
	RunState.set_omen(&"pluie_de_cendres", false)
	_check(_near(player.max_hp, hp0, 0.01) and _near(float(player.stat(&"damage_mult")), 1.25), "Pluie de cendres : vos dégâts ×1,25 (PV max rendus)")
	player.set(&"hp", player.max_hp)
	RunState.set_omen(&"", false)
	player.set(&"hp", player.max_hp)
	player.set(&"_invuln", 0.0)
	player.take_damage(10.0, null)
	var lost_base: float = player.max_hp - float(player.hp)
	RunState.set_omen(&"pluie_de_cendres", false)
	player.set(&"hp", player.max_hp)
	player.set(&"_invuln", 0.0)
	player.take_damage(10.0, null)
	var lost_ash: float = player.max_hp - float(player.hp)
	_check(lost_base > 0.0 and _near(lost_ash / lost_base, 1.25, 0.01), "Pluie de cendres : coup reçu ×1,25 (%.2f -> %.2f)" % [lost_base, lost_ash])
	RunState.set_omen(&"fievre", false)
	player.set(&"hp", player.max_hp)
	player.set(&"_invuln", 0.0)
	player.take_damage(10.0, null)
	var lost_fev: float = player.max_hp - float(player.hp)
	_check(_near(lost_fev / lost_base, 1.2, 0.01) and _near(float(player.stat(&"cooldown_mult")), 0.77), "Fièvre : coup reçu ×1,2 et recharges ×0,77")
	# plafond de coup appliqué après le multiplicateur
	player.set(&"hp", player.max_hp)
	player.set(&"_invuln", 0.0)
	player.take_damage(player.max_hp * 5.0, null)
	_check(_near(player.max_hp - float(player.hp), player.max_hp * Balance.MAX_HIT_FRACTION, 0.5), "plafond de coup (%d %%) appliqué après le multiplicateur" % int(Balance.MAX_HIT_FRACTION * 100.0))
	RunState.set_omen(&"", false)
	_check(float(player.stat(&"cooldown_mult")) <= 0.0 and float(player.stat(&"damage_mult")) <= 0.0, "présage retiré : stats du joueur rendues")

	# monstres : PV à l'apparition
	RunState.stage = 3
	RunState.set_omen(&"", false)
	var e_base: Enemy = dir.spawn_enemy(2, Vector2(500, 500))
	var e_base_brute: Enemy = dir.spawn_enemy(3, Vector2(600, 500))
	var e_base_swarm: Enemy = dir.spawn_enemy(1, Vector2(700, 500))
	var hp2: float = e_base.max_hp
	var hp3: float = e_base_brute.max_hp
	var hp1: float = e_base_swarm.max_hp
	RunState.set_omen(&"carapaces", false)
	var e2: Enemy = dir.spawn_enemy(2, Vector2(500, 600))
	var e3: Enemy = dir.spawn_enemy(3, Vector2(600, 600))
	var e1: Enemy = dir.spawn_enemy(1, Vector2(700, 600))
	var e1e: Enemy = dir.spawn_enemy(1, Vector2(800, 600), true)
	RunState.set_omen(&"", false)
	var e1e0: Enemy = dir.spawn_enemy(1, Vector2(900, 600), true)
	_check(_near(e2.max_hp / hp2, 1.35, 0.001) and _near(e3.max_hp / hp3, 1.35, 0.001) and _near(e1.max_hp / hp1, 1.0, 0.001), "Carapaces : tireur et brute ×1,35, essaim inchangé")
	_check(_near(e1e.max_hp / e1e0.max_hp, 1.35, 0.001), "Carapaces : élite ×1,35")

	# dégâts du joueur contre élites / boss (SpellCaster.compute_damage)
	RunState.set_omen(&"eveil_des_elites", false)
	var caster: SpellCaster = player.spells
	var spell: SpellData = caster.character.spells[0]
	var normal_hit := caster.compute_damage(spell, e1, false)
	var elite_hit := caster.compute_damage(spell, e1e, false)
	RunState.set_omen(&"", false)
	var normal_ref := caster.compute_damage(spell, e1, false)
	var elite_ref := caster.compute_damage(spell, e1e, false)
	_check(_near(normal_hit, normal_ref, 0.001) and elite_ref > 0.0 and _near(elite_hit / elite_ref, 1.15, 0.001), "Éveil des élites : +15 % contre élites, rien contre un monstre ordinaire")

	# director : crédits et élites
	dir._free.clear() # rien ne peut apparaître : on lit les crédits cumulés
	RunState.set_omen(&"", false)
	dir.credits = 0.0
	dir._update_spawning(1.0, Vector2.ZERO)
	var c0: float = dir.credits
	RunState.stage = 3
	RunState.set_omen(&"maree", false)
	dir.credits = 0.0
	dir._update_spawning(1.0, Vector2.ZERO)
	_check(c0 > 0.0 and _near(dir.credits / c0, 1.25, 0.001), "Marée : le director gagne 25 % de crédits en plus (étage 3)")
	RunState.stage = 2
	RunState.set_omen(&"", false)
	dir.credits = 0.0
	dir._update_spawning(1.0, Vector2.ZERO)
	var c2: float = dir.credits
	RunState.set_omen(&"maree", false)
	dir.credits = 0.0
	dir._update_spawning(1.0, Vector2.ZERO)
	_check(c2 > 0.0 and _near(dir.credits / c2, 1.15, 0.001), "Marée : +15 % à l'étage 2")
	RunState.set_omen(&"", false)

	# coffres, capsules : prix et or
	var chest: Chest = load("res://scenes/chests/chest.tscn").instantiate()
	add_child(chest)
	chest.setup(&"petit", 3)
	var p0 := chest.current_price()
	RunState.stage = 3
	RunState.set_omen(&"marche_noir", false)
	_check(p0 > 0.0 and _near(chest.current_price() / p0, 1.3, 0.001), "Marché noir : coffre ×1,3")
	RunState.set_omen(&"usure", false)
	_check(_near(chest.current_price() / p0, 0.8, 0.001), "Usure : coffre ×0,8")
	RunState.set_omen(&"", false)
	_check(_near(chest.current_price(), p0), "retrait : prix rendu")
	var boss_chest: Chest = load("res://scenes/chests/chest.tscn").instantiate()
	add_child(boss_chest)
	boss_chest.setup(&"boss", 3)
	RunState.set_omen(&"marche_noir", false)
	_check(boss_chest.current_price() == 0.0, "coffre de boss : toujours gratuit")
	RunState.set_omen(&"", false)
	var cap: GoldCapsule = load("res://scenes/loot/gold_capsule.tscn").instantiate()
	add_child(cap)
	cap.setup(3)
	await _frames(1)
	var g0 := cap.expected_gold()
	RunState.set_omen(&"marche_noir", false)
	_check(g0 > 0.0 and _near(cap.expected_gold() / g0, 2.0, 0.001), "Marché noir : capsule d'argent ×2")
	RunState.set_omen(&"", false)

	# prime de monstre
	var pm: PickupManager = load("res://scenes/pickups/pickup_manager.tscn").instantiate()
	add_child(pm)
	await _frames(1)
	RunState.stage = 3
	RunState.gold = 0.0
	pm.gold_carry = 0.0
	for k in 200: # la prime est créditée par pièces entières (reste reporté) : on compare des totaux
		Events.enemy_killed.emit(e1, Vector2.ZERO, 3, true)
	var gold_base := RunState.gold + pm.gold_carry
	RunState.gold = 0.0
	pm.gold_carry = 0.0
	RunState.set_omen(&"offrande", false)
	for k in 200:
		Events.enemy_killed.emit(e1, Vector2.ZERO, 3, true)
	_check(gold_base > 20.0 and _near((RunState.gold + pm.gold_carry) / gold_base, 0.65, 0.01), "Offrande : prime des monstres ×0,65 (%.1f -> %.1f)" % [gold_base, RunState.gold + pm.gold_carry])
	RunState.set_omen(&"", false)

	# retrait à l'étage suivant
	RunState.stage = 3
	RunState.set_omen(&"pluie_de_cendres", false)
	_check(float(player.stat(&"damage_mult")) > 1.0, "avant le téléporteur : présage actif")
	RunState.stage += 1
	RunState.begin_floor() # = StageManager.next_stage
	_check(RunState.omen == &"" and RunState.omen_pending and Omens.monster_damage_mult() == 1.0 and float(player.stat(&"damage_mult")) <= 0.0,
		"étage suivant : présage retiré (stats rendues) et nouveau choix en attente")
	RunState.stage = 6
	RunState.begin_floor()
	_check(not RunState.omen_pending, "sans fin (étage 6) : pas de choix")
	RunState.stage = 1
	RunState.begin_floor()
	_check(not RunState.omen_pending, "étage 1 : pas de choix")

	player.queue_free()
	dir.queue_free()
	chest.queue_free()
	boss_chest.queue_free()
	cap.queue_free()
	pm.queue_free()
	await _frames(2)


# --- parcours sur la vraie scène de jeu -----------------------------------------------------------

func _test_flow(mode: StringName) -> void:
	print("-- parcours en ", mode)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_mode", mode)
	main.set(&"run_seed", 303)
	add_child(main)
	await main.game_ready
	await _frames(3)
	var stage: StageManager = main.stage
	_check(RunState.mode == mode and not RunState.omen_pending and main.omen_screen == null, "%s : étage 1 sans présage" % mode)
	stage.next_stage()
	_check(RunState.stage == 2 and RunState.omen_pending, "%s : étage 2, choix en attente" % mode)
	var guard := 0
	while main.omen_screen == null and guard < 900:
		var fc: FloorCard = main.floor_card
		if is_instance_valid(fc):
			fc.skip()
		await _frames(1)
		guard += 1
	var scr: OmenScreen = main.omen_screen
	_check(scr != null and get_tree().paused, "%s : écran de présage ouvert, jeu en pause (après le carton d'étage)" % mode)
	if scr == null:
		main.queue_free()
		await _frames(2)
		return
	var ids := scr.card_ids()
	var expect := Omens.offer(2, 303, mode)
	_check(ids.size() == (2 if mode == &"difficile" else 3), "%s : %d cartes" % [mode, ids.size()])
	_check(ids.has(Balance.OMEN_CLEAR_ID) == (mode != &"difficile"), "%s : Ciel clair %s" % [mode, "absent (choix obligatoire)" if mode == &"difficile" else "proposé"])
	_check(ids.size() == expect.size() and str(ids[0]) == expect[0]["id"], "%s : cartes = Omens.offer (graine de run)" % mode)
	_check(scr.card_text(0).contains(str(expect[0]["name"])), "%s : carte 1 = nom + texte (%s)" % [mode, scr.card_text(0).substr(0, 40)])
	var b0: Button = scr.card_button(0)
	_check(b0 != null and b0.size.y >= UiTheme.MIN_TOUCH, "%s : carte au moins aussi haute que la cible tactile" % mode)
	var before := scr
	if mode == &"difficile":
		await _wait(0.6)
		b0.pressed.emit() # un vrai appui (cartes cliquables) après le délai d'entrée
	else:
		scr.choose(ids.size() - 1) # Ciel clair
	await _frames(3)
	var pick: StringName = ids[0] if mode == &"difficile" else ids[ids.size() - 1]
	_check(RunState.omen == pick and not RunState.omen_pending and main.omen_screen == null and not get_tree().paused, "%s : choix appliqué, jeu repris (%s)" % [mode, RunState.omen])
	_check(not is_instance_valid(before) or before.is_queued_for_deletion(), "%s : écran retiré" % mode)
	_check(RunState.omens_taken.get(2, "") == String(pick), "%s : choix noté pour l'historique" % mode)
	var hud: Node = main.hud
	var badge: OmenBadge = hud.omen_badge
	if mode == &"difficile":
		_check(badge.visible and badge.name_text() == str(Omens.get_omen(pick)["name"]) and badge.is_open(), "HUD : rappel du présage visible et déplié juste après le choix")
		_check(badge.detail_text() == str(Omens.get_omen(pick)["text"]) and badge.tooltip_text != "", "HUD : détail = texte du présage, infobulle posée")
		await _wait(OmenBadge.OPEN_ON_CHOICE_S + 0.3)
		_check(not badge.is_open(), "HUD : rappel replié après quelques secondes")
		# reliquaire d'Offrande (si tiré) : posé à l'arrivée ; sinon on le force
		main.player.set(&"hp", main.player.max_hp)
		RunState.set_omen(&"offrande", false)
		await _frames(2)
		_check(is_instance_valid(stage.omen_chest) and stage.omen_chest.kind == &"guardian" and stage.omen_chest.current_price() == 0.0, "Offrande : reliquaire gratuit (table guardian) posé à l'arrivée")
		var sd := stage.to_dict()
		_check(sd.has("omen_chest"), "Offrande : reliquaire fermé sauvegardé")
		RunState.set_omen(&"", false)
		await _frames(2)
		_check(not is_instance_valid(stage.omen_chest), "Offrande retirée : reliquaire libéré")
		RunState.set_omen(pick, false)
	else:
		_check(not badge.visible and RunState.omen == Balance.OMEN_CLEAR_ID, "Ciel clair : aucun rappel au HUD, aucun effet")
		_check(RunState.omens_accepted() == 0, "Ciel clair : pas de rubis de présage")
	# étage suivant : le présage cesse, nouveau choix
	stage.next_stage()
	_check(RunState.stage == 3 and RunState.omen == &"" and RunState.omen_pending, "%s : étage 3, présage de l'étage 2 retiré, nouveau choix" % mode)
	await _frames(2)
	_check(not hud.omen_badge.visible, "%s : rappel masqué au changement d'étage" % mode)
	# autosave pendant l'attente du choix, puis reprise : l'écran revient
	var save: Dictionary = main.build_save_data()
	_check(bool(save["run"]["omen_pending"]), "%s : sauvegarde faite avant le choix garde l'attente" % mode)
	get_tree().paused = false
	main.queue_free()
	await _frames(3)
	var resumed: Node = load("res://scenes/main.tscn").instantiate()
	resumed.set(&"resume_data", JSON.parse_string(JSON.stringify(save)))
	add_child(resumed)
	await resumed.game_ready
	await _frames(3)
	_check(resumed.omen_screen != null and RunState.omen_pending and get_tree().paused, "%s : reprise avant le choix : l'écran de présage est rouvert" % mode)
	if resumed.omen_screen != null:
		resumed.omen_screen.choose(0)
	await _frames(3)
	_check(RunState.omen != &"" and not get_tree().paused, "%s : choix après reprise" % mode)
	get_tree().paused = false
	resumed.queue_free()
	await _frames(3)


# --- panneau de test, historique -------------------------------------------------------------------

func _test_panel_and_history() -> void:
	var ProfileScript := preload("res://scripts/save/profile.gd")
	var p: Node = ProfileScript.new()
	p.write_enabled = false
	p.unlock_all_variants = false
	p.add_run_result({"victory": false, "mode": "moyen", "character": "ardent", "active_time_s": 600.0, "kills": 10, "rubies": 5, "stage": 3,
		"level": 4, "gold": 5, "difficulty": 2.0, "items": {}, "loadout": {}, "counters": {}, "bosses_killed": [], "reason": "death",
		"omens": {"2": "fievre", "3": "ciel_clair"}})
	p.add_run_result({"victory": false, "mode": "moyen", "character": "ardent", "active_time_s": 100.0, "kills": 1, "rubies": 0, "stage": 1,
		"level": 1, "gold": 0, "difficulty": 1.0, "items": {}, "loadout": {}, "counters": {}, "bosses_killed": [], "reason": "death"})
	_check(p.history[0].get("omens", {}) == {"2": "fievre", "3": "ciel_clair"}, "historique : présage choisi par étage")
	_check(not p.history[1].has("omens"), "historique : champ optionnel, absent sans présage")
	var d: Dictionary = JSON.parse_string(JSON.stringify(p.to_dict()))
	var q: Node = ProfileScript.new()
	q.write_enabled = false
	q._apply_dict(d)
	_check(int(d.version) == 4 and q.history[0].get("omens", {}) == {"2": "fievre", "3": "ciel_clair"} and not q.history[1].has("omens"), "historique : aller-retour, même version de sauvegarde (4)")
	p.free()
	q.free()
	_check(EndRunScreen.ruby_breakdown({"mode": "moyen", "omen_rubies": 4}).contains("Présages +4"), "récap : « Présages +N » dans le détail des rubis")
	# panneau du mode test : le choix d'un présage se force sans rien écrire
	TestMode.begin()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await main.game_ready
	await _frames(5)
	_check(RunState.omen == &"" and not RunState.omen_pending and main.omen_screen == null, "mode test : aucun présage par défaut, aucun écran")
	var panel: TestPanel = _find_panel(main)
	_check(panel != null, "mode test : panneau présent")
	if panel != null:
		panel._select_tab(&"cheats")
		var btn: Button = panel._body.find_child("Omen_fievre", true, false) as Button
		_check(btn != null, "mode test : bouton « Fièvre » dans l'onglet Triches")
		if btn != null:
			btn.pressed.emit()
			await _frames(2)
			_check(RunState.omen == &"fievre" and Omens.is_active() and RunState.omens_taken.is_empty(), "mode test : présage forcé, rien noté pour l'historique")
	RunState.set_omen(&"", false)
	main.queue_free()
	await _frames(3)
	TestMode.end()


func _find_panel(n: Node) -> TestPanel:
	if n is TestPanel:
		return n
	for c in n.get_children():
		var r := _find_panel(c)
		if r != null:
			return r
	return null
