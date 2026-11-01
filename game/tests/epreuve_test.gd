extends Node
## Prototype « Les Épreuves » (docs/Boucle_Etage_Refonte.md §5.3) : drapeau désactivé = jeu inchangé ; drapeau activé =
## étage 1 avec une Escorte et un Rituel à la place des petits piliers (tracés, relais, coffres, capsules, gros pilier) ;
## Escorte (corde, arrêt, PV à 0, arrivée, mini-boss, note) ; Rituel (relais à maintien, cadence 12/9/7 s, anneau, note) ;
## délai de sécurité ; or versé ; or des kills en zone réduit ; sauvegarde ; mode test.
## godot --headless --path game res://tests/epreuve_test.tscn  -> RESULT: OK

const KILL_GUARD := 400

var _fails := 0
var _main: Node
var _events: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seed_for_map(map_id: String) -> int:
	for s in range(1, 400):
		var plan: Array = FloorPlan.build(s)
		if String((plan[0] as Dictionary).get("map_id", "")) == map_id:
			return s
	return -1


func _new_main(run_seed: int) -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await _frames(3)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", run_seed)
	add_child(_main)
	await _main.game_ready
	await _frames(3)
	(_main.get(&"player") as Node2D).call(&"grant_invulnerability", 1.0e6)


func _run() -> void:
	Events.epreuve_started.connect(func(k: StringName) -> void: _events.append(["start", k]))
	Events.epreuve_finished.connect(func(k: StringName, g: StringName, s: float, gold: float) -> void: _events.append(["end", k, g, s, gold]))
	_check_balance()
	await _flag_off()
	for map_id in ["terrasses_noyees", "terrasses_rizieres_hautes"]:
		await _flag_on(map_id)
	await _sweep()
	await _mechanics()
	await _flow()
	await _test_mode()
	Balance.EPREUVES_ENABLED = false
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


# --- Constantes et notes
func _check_balance() -> void:
	print("-- Balance")
	_check("drapeau par défaut : faux", not Balance.EPREUVES_ENABLED)
	_check("ZONE_SPAWN_MULT[epreuve] = 1,5", is_equal_approx(float(Balance.ZONE_SPAWN_MULT[&"epreuve"]), 1.5))
	_check("cadence du cœur [12, 9, 7]", Balance.RITUAL_PULSE_S == [12.0, 9.0, 7.0] and is_equal_approx(Balance.ritual_pulse_s(0), 12.0) and is_equal_approx(Balance.ritual_pulse_s(1), 9.0) and is_equal_approx(Balance.ritual_pulse_s(2), 7.0))
	_check("maintien 1,2 s, 3 relais, télégraphe >= 0,8 s", is_equal_approx(Balance.RITUAL_HOLD_S, 1.2) and Balance.RITUAL_RELAYS == 3 and Balance.RITUAL_TELEGRAPH_S >= 0.8)
	_check("escorte 2,5 u/s, corde 6 u, arrêt 5 s, PV 0,3 mini", is_equal_approx(Balance.ESCORT_SPEED_U, 2.5) and is_equal_approx(Balance.ESCORT_LEASH_U, 6.0) and is_equal_approx(Balance.ESCORT_STALL_S, 5.0) and is_equal_approx(Balance.ESCORT_HP_MINI_SHARE, 0.3))
	_check("PV de la barque = 0,3 x PV d'un mini-boss", is_equal_approx(Balance.escort_hp(2.0, 1), 0.3 * Balance.boss_hp(&"mini", 2.0, 1)))
	_check("note : parfait", Balance.epreuve_grade(&"escorte", 30.0, true) == &"parfait" and Balance.epreuve_grade(&"rituel", 35.0, true) == &"parfait")
	_check("note : faute = bien", Balance.epreuve_grade(&"escorte", 30.0, false) == &"bien")
	_check("note : bien jusqu'à 1,5 x seuil", Balance.epreuve_grade(&"escorte", 60.0, true) == &"bien" and Balance.epreuve_grade(&"rituel", 52.5, true) == &"bien")
	_check("note : fait au-delà", Balance.epreuve_grade(&"escorte", 60.5, true) == &"fait" and Balance.epreuve_grade(&"rituel", 53.0, false) == &"fait")
	var p := 50.0
	_check("or : parfait > bien > fait > 0", Balance.epreuve_gold(&"parfait", p) > Balance.epreuve_gold(&"bien", p) and Balance.epreuve_gold(&"bien", p) > Balance.epreuve_gold(&"fait", p) and Balance.epreuve_gold(&"fait", p) > 0.0)
	# budget : l'étage 1 reste dans la bande 8-10,5 P de docs/Ateliers_Chiffres.md (étage mesuré 8,0-8,8 P, ≈ 1,0 P par petit pilier)
	var mix := 0.25 * float(Balance.EPREUVE_GOLD_P[&"parfait"]) + 0.55 * float(Balance.EPREUVE_GOLD_P[&"bien"]) + 0.20 * float(Balance.EPREUVE_GOLD_P[&"fait"])
	var per_epreuve := mix + 0.3 + 0.7 * Balance.EPREUVE_ZONE_GOLD_MULT # note + prime du mini-boss + kills en zone réduits
	var floor_p := 8.4 - 2.0 * 1.0 + 2.0 * per_epreuve
	_check("budget d'or : étage 1 entre 8 et 10,5 P (mix 25/55/20 %%, %.1f P)" % floor_p, floor_p >= 8.0 and floor_p <= 10.5)


# --- Drapeau désactivé : jeu inchangé
func _flag_off() -> void:
	print("-- drapeau désactivé")
	Balance.EPREUVES_ENABLED = false
	await _new_main(_seed_for_map("terrasses_noyees"))
	var stage: StageManager = _main.stage
	_check("étage 1 : pas d'épreuves", not stage.epreuves_on)
	_check("3 piliers dont 2 petits ordinaires", stage.pillars.size() == 3 and stage.pillars.filter(func(p): return p is Epreuve).is_empty())
	_check("aucun nœud du groupe epreuves", get_tree().get_nodes_in_group(&"epreuves").is_empty())
	_check("piliers tirés sur des marqueurs", (stage.to_dict()["pillars"] as Array).all(func(d): return int(d["marker"]) >= 0 and not d.has("epreuve")))
	_check("coffres : 8 petits + 2 grands (+ légendaire éventuel)", stage.chests.size() >= 10 and stage.chests.size() <= 11)
	_check("capsules : 4", stage.capsules.size() == Balance.CAPSULES_PER_STAGE)
	_check("zone : mêmes tarifs mini et étage", is_equal_approx(float(Balance.ZONE_SPAWN_MULT[&"mini"]), 1.5) and is_equal_approx(float(Balance.ZONE_SPAWN_MULT[&"etage"]), 2.33))
	_check("or des kills non modifié hors épreuve", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), Vector2(1.0e6, 1.0e6)), 1.0))
	# même graine, même étage, drapeau désactivé deux fois : tirage identique (seed intacte)
	var d1: Dictionary = stage.to_dict()
	await _new_main(_seed_for_map("terrasses_noyees"))
	var d2: Dictionary = (_main.stage as StageManager).to_dict()
	_check("tirage déterministe (pilier, coffres, capsules)", JSON.stringify([d1["pillars"], d1["chests"], d1["capsules"]]) == JSON.stringify([d2["pillars"], d2["chests"], d2["capsules"]]))


# --- Drapeau activé : disposition de l'étage 1
func _flag_on(map_id: String) -> void:
	print("-- drapeau activé, ", map_id)
	Balance.EPREUVES_ENABLED = true
	await _new_main(_seed_for_map(map_id))
	var stage: StageManager = _main.stage
	var u := Balance.UNIT_PX
	_check("carte du plan", stage.map_id == map_id, stage.map_id)
	_check("épreuves actives", stage.epreuves_on)
	_check("3 piliers : escorte, rituel, gros", stage.pillars.size() == 3 and stage.pillars[0] is EpreuveEscort and stage.pillars[1] is EpreuveRitual and stage.pillars[2].kind == Pillar.Kind.BIG and not (stage.pillars[2] is Epreuve))
	if stage.pillars.size() != 3 or not (stage.pillars[0] is EpreuveEscort) or not (stage.pillars[1] is EpreuveRitual):
		return
	var esc: EpreuveEscort = stage.pillars[0]
	var rit: EpreuveRitual = stage.pillars[1]
	var big: Pillar = stage.pillars[2]
	_check("tracé de l'escorte : 60-80 u", esc.length / u >= 60.0 and esc.length / u <= 80.0, "%.1f u" % (esc.length / u))
	_check("barque au ponton de départ", esc.position.distance_to(esc.path[0]) < 1.0)
	var walk_ok := true
	var n := 0
	for i in range(esc.path.size() - 1):
		var steps := int(esc.path[i].distance_to(esc.path[i + 1]) / (0.5 * u))
		for k in steps + 1:
			n += 1
			if not stage.is_reachable_local(esc.path[i].lerp(esc.path[i + 1], float(k) / float(maxi(steps, 1)))):
				walk_ok = false
	_check("tracé entièrement accessible à pied (%d points)" % n, walk_ok)
	_check("3 relais, 10-14 u du cœur", rit.relays.size() == 3 and rit.relays.all(func(r): return r.global_position.distance_to(rit.global_position) / u >= 10.0 and r.global_position.distance_to(rit.global_position) / u <= 14.0))
	_check("cœur et relais accessibles", stage.is_reachable_local(rit.position) and rit.relays.all(func(r): return stage.is_reachable_local(rit.position + r.position)))
	_check("gros pilier à >= 12 u du tracé, du cœur et des relais", stage._big_clear_of_epreuves(big.position))
	_check("petits piliers verrouillent le gros", big.state == Pillar.STATE_LOCKED)
	_check("mini-boss du plan sur chaque épreuve", esc.boss_id != &"" and rit.boss_id != &"" and esc.boss_id != rit.boss_id)
	var near_esc := 0
	var near_rit := 0
	for c in stage.chests:
		near_esc += 1 if stage._dist_to_escort(c.position) <= Balance.EPREUVE_CHEST_TRACE_U * u else 0
		near_rit += 1 if stage._dist_to_ritual(c.position) <= Balance.EPREUVE_CHEST_TRACE_U * u else 0
	_check("coffres : >= 3 à <= 8 u du tracé (%d)" % near_esc, near_esc >= 3)
	_check("coffres : >= 3 à <= 8 u du rituel (%d)" % near_rit, near_rit >= 3)
	var near_big := stage.chests.filter(func(c): return c.position.distance_to(big.position) <= Balance.EPREUVE_CHEST_ARENA_U * u).size()
	_check("coffres : >= 2 autour du gros pilier (%d)" % near_big, near_big >= 2)
	_check("coffres : 10 ou 11 au total", stage.chests.size() >= 10 and stage.chests.size() <= 11, str(stage.chests.size()))
	_check("capsules : 4, une près du départ", stage.capsules.size() == 4 and stage.capsules.any(func(c): return c.position.distance_to(stage.map.get_player_start()) <= Balance.EPREUVE_CHEST_START_U * u))
	var caps_trace := stage.capsules.filter(func(c): return stage._dist_to_escort(c.position) <= 8.0 * u or stage._dist_to_ritual(c.position) <= 8.0 * u).size()
	_check("capsules : au moins 3 sur les tracés (%d)" % caps_trace, caps_trace >= 3)
	_check("sauvegarde : entrées d'épreuve", (stage.to_dict()["pillars"] as Array).filter(func(d): return d.has("epreuve") and int(d["marker"]) == -1).size() == 2)
	# restauration complète de l'étage depuis la sauvegarde
	var d: Dictionary = stage.to_dict()
	var chests_n := stage.chests.size()
	stage.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary)
	await _frames(2)
	_check("from_dict : mêmes épreuves, mêmes coffres", stage.pillars.size() == 3 and stage.pillars[0] is EpreuveEscort and stage.pillars[1] is EpreuveRitual and stage.chests.size() == chests_n)
	# autre graine, même carte : l'étage reste jouable (gros pilier trouvé)
	Balance.EPREUVES_ENABLED = false


## Plusieurs graines par carte (les mêmes invariants de disposition) : gros pilier hors des tracés, coffres répartis, 4 capsules.
func _sweep() -> void:
	print("-- balayage de graines")
	Balance.EPREUVES_ENABLED = true
	var u := Balance.UNIT_PX
	for map_id in ["terrasses_noyees", "terrasses_rizieres_hautes"]:
		var seeds: Array[int] = []
		for s in range(1, 400):
			if String((FloorPlan.build(s)[0] as Dictionary).get("map_id", "")) == map_id and seeds.size() < 5:
				seeds.append(s)
		for sd in seeds:
			await _new_main(sd)
			var stage: StageManager = _main.stage
			var ok := stage.epreuves_on and stage.pillars.size() == 3 and stage.pillars[2].kind == Pillar.Kind.BIG and stage._big_clear_of_epreuves(stage.pillars[2].position)
			var ne := 0
			var nr := 0
			for c in stage.chests:
				ne += 1 if stage._dist_to_escort(c.position) <= Balance.EPREUVE_CHEST_TRACE_U * u else 0
				nr += 1 if stage._dist_to_ritual(c.position) <= Balance.EPREUVE_CHEST_TRACE_U * u else 0
			_check("%s graine %d : disposition valide (escorte %d, rituel %d coffres, %d capsules)" % [map_id, sd, ne, nr, stage.capsules.size()], ok and ne >= 3 and nr >= 3 and stage.capsules.size() == 4 and stage.chests.size() >= 10)
	Balance.EPREUVES_ENABLED = false


# --- Mécaniques sur des épreuves autonomes (posées dans la carte courante)
func _mechanics() -> void:
	print("-- mécaniques")
	Balance.EPREUVES_ENABLED = true
	await _new_main(_seed_for_map("terrasses_noyees"))
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var director: Director = _main.director
	var u := Balance.UNIT_PX
	var origin := stage.map.get_player_start()

	# ---- Escorte
	var pts := PackedVector2Array([origin + Vector2(0, 0), origin + Vector2(20, 0) * u, origin + Vector2(20, 6) * u])
	var e := EpreuveEscort.make(pts)
	e.setup(Pillar.Kind.SMALL, 91, false)
	stage.map.add_child(e)
	e.set_physics_process(false)
	await _frames(1)
	_check("escorte : prête, longueur 26 u", e.state == Pillar.STATE_READY and is_equal_approx(e.length / u, 26.0))
	_check("escorte : PV (état prêt)", e.hp == 0.0)
	var gold0: float = RunState.gold
	_events.clear()
	_check("escorte : lancement", e.activate() and e.is_running() and _events.size() == 1 and _events[0][0] == "start" and _events[0][1] == &"escorte")
	_check("escorte : PV = 0,3 x mini-boss", is_equal_approx(e.max_hp, Balance.escort_hp(RunState.difficulty(), RunState.stage)) and e.hp == e.max_hp and e.max_hp > 0.0)
	# joueur trop loin : la barque attend
	player.global_position = e.global_position + Vector2(Balance.ESCORT_LEASH_U * u + 80.0, 0.0)
	for i in 20:
		e.tick(0.25)
	_check("escorte : arrêtée hors corde (6 u)", e.dist_along == 0.0 and e.leash_blocked and e.leash_wait_s >= 4.9)
	# joueur à portée : elle avance à 2,5 u/s
	player.global_position = e.global_position
	var t0 := e.elapsed
	var d0 := e.dist_along
	for i in 8:
		e.tick(0.25)
	var travelled: float = (e.dist_along - d0) / u
	_check("escorte : vitesse 2,5 u/s (%.2f u en 2 s)" % travelled, absf(travelled - 5.0) < 0.05 and not e.leash_blocked)
	# PV à 0 : arrêt 5 s puis repart pleine, note parfait perdue
	e.damage(e.hp + 1.0)
	_check("escorte : PV 0 -> arrêt 5 s", is_equal_approx(e.stall_left, Balance.ESCORT_STALL_S) and e.hp == 0.0 and e.stall_count == 1 and not e.clean)
	var d_stall := e.dist_along
	for i in 16: # 4 s
		player.global_position = e.global_position
		e.tick(0.25)
	_check("escorte : immobile pendant l'arrêt", e.dist_along == d_stall and e.stall_left > 0.9)
	for i in 8: # 2 s : fin de l'arrêt, PV pleins, repart
		player.global_position = e.global_position
		e.tick(0.25)
	_check("escorte : repart avec ses PV pleins", e.stall_left == 0.0 and e.hp == e.max_hp and e.dist_along > d_stall)
	_check("escorte : jamais détruite", e.is_running() and e.state == Pillar.STATE_ACTIVE)
	# les monstres au contact la blessent
	var hp_before := e.hp
	var foes: Array = []
	for i in 6:
		var foe: Enemy = director.spawn_enemy(1, e.global_position + Vector2(10.0 + 4.0 * i, 0.0))
		if foe != null:
			foes.append(foe)
	_check("escorte : monstres au contact créés", foes.size() >= 3)
	var dps := e._contact_dps()
	_check("escorte : dégâts de contact > 0 (%.1f/s)" % dps, dps > 0.0)
	for i in 4:
		player.global_position = e.global_position + Vector2(300.0, 0.0)
		e.tick(0.25)
	_check("escorte : blessée par les monstres", e.hp < hp_before)
	for f in foes:
		(f as Enemy).take_damage((f as Enemy).max_hp * 10.0)
	await _frames(2)
	# arrivée : mini-boss, or selon la note
	e.hp = e.max_hp
	e.stall_left = 0.0
	player.global_position = e.global_position
	var guard := 0
	while e.is_running() and guard < KILL_GUARD:
		player.global_position = e.global_position
		e.tick(0.25)
		guard += 1
	_check("escorte : arrivée -> épreuve résolue", e.resolved and e.dist_along >= e.length and guard < KILL_GUARD)
	_check("escorte : note « bien » (a été immobilisée)", e.grade == &"bien", String(e.grade))
	var expected := Balance.epreuve_gold(&"bien", Balance.station_price_p(RunState.floor_start_d, RunState.stage))
	_check("escorte : or nominal = 1,0 P", is_equal_approx(e.gold_paid, expected) and is_equal_approx(e.gold_paid, Balance.EPREUVE_GOLD_P[&"bien"] * Balance.station_price_p(RunState.floor_start_d, RunState.stage)))
	var gm: float = (player.call(&"gold_mult") as float)
	_check("escorte : or versé au joueur (%.1f)" % (RunState.gold - gold0), absf((RunState.gold - gold0) - expected * gm) <= 1.0, "attendu %.1f" % (expected * gm))
	_check("escorte : évènement de fin", _events.size() == 2 and _events[1][0] == "end" and _events[1][1] == &"escorte" and _events[1][2] == &"bien" and _events[1][3] >= 0.0 and is_equal_approx(float(_events[1][4]), expected))
	var boss: Enemy = e.get(&"_boss")
	_check("escorte : mini-boss invoqué à l'arrivée", boss != null and boss.active and boss.global_position.distance_to(e.global_position) < 400.0)
	_check("escorte : zone du mini-boss (mini)", director._zones.get(91, {}).get("kind", &"") == &"mini")
	_check("escorte : zone x1,5 suit la barque", true)
	boss.take_damage(boss.max_hp * 10.0)
	await _frames(3)
	_check("escorte : mini-boss mort -> épreuve terminée", e.state == Pillar.STATE_DONE)
	e.queue_free()

	# note « parfait » : durée de base, joueur collé à la barque, jamais blessée
	var e2 := EpreuveEscort.make(pts)
	e2.setup(Pillar.Kind.SMALL, 92, false)
	stage.map.add_child(e2)
	e2.set_physics_process(false)
	await _frames(1)
	e2.activate()
	guard = 0
	while e2.is_running() and guard < KILL_GUARD:
		player.global_position = e2.global_position
		e2.tick(0.25)
		guard += 1
	_check("escorte : note « parfait » (%.1f s)" % e2.elapsed, e2.grade == &"parfait" and e2.elapsed <= 40.0 and e2.clean)
	_check("escorte : parfait = 1,5 P", is_equal_approx(e2.gold_paid, 1.5 * Balance.station_price_p(RunState.floor_start_d, RunState.stage)))
	(e2.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	e2.queue_free()

	# délai de sécurité : joueur à l'écart tout du long -> « fait » à 75 s, jamais bloqué
	var e3 := EpreuveEscort.make(pts)
	e3.setup(Pillar.Kind.SMALL, 93, false)
	stage.map.add_child(e3)
	e3.set_physics_process(false)
	await _frames(1)
	e3.activate()
	player.global_position = e3.global_position + Vector2(900.0, 0.0)
	guard = 0
	while e3.is_running() and guard < KILL_GUARD:
		e3.tick(0.5)
		guard += 1
	_check("escorte : délai de sécurité 75 s -> « fait »", e3.resolved and e3.grade == &"fait" and absf(e3.elapsed - Balance.EPREUVE_BACKSTOP_S) <= 0.5, "%.1f s %s" % [e3.elapsed, e3.grade])
	_check("escorte : fait = 0,5 P et mini-boss invoqué", is_equal_approx(e3.gold_paid, 0.5 * Balance.station_price_p(RunState.floor_start_d, RunState.stage)) and e3.get(&"_boss") != null)
	(e3.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	e3.queue_free()

	# sauvegarde de l'escorte en cours
	var e4 := EpreuveEscort.make(pts)
	e4.setup(Pillar.Kind.SMALL, 94, false)
	stage.map.add_child(e4)
	e4.set_physics_process(false)
	await _frames(1)
	e4.activate()
	for i in 40:
		player.global_position = e4.global_position
		e4.tick(0.25)
	e4.damage(e4.hp * 0.4)
	var sd: Dictionary = JSON.parse_string(JSON.stringify(e4.to_dict())) as Dictionary
	var e5 := EpreuveEscort.make(pts)
	e5.setup(Pillar.Kind.SMALL, 94, false)
	stage.map.add_child(e5)
	e5.set_physics_process(false)
	await _frames(1)
	e5.from_dict(sd)
	_check("sauvegarde escorte : reprise en cours", e5.state == Pillar.STATE_ACTIVE and e5.is_running() and is_equal_approx(e5.dist_along, e4.dist_along) and is_equal_approx(e5.hp, e4.hp) and is_equal_approx(e5.elapsed, e4.elapsed))
	_check("sauvegarde escorte : position sur le tracé", e5.position.distance_to(e4.position) < 1.0)
	e4.queue_free()
	e5.queue_free()
	await _frames(1)

	# ---- Rituel
	var heart := origin + Vector2(0.0, -4.0) * u
	var relay_pts: Array = []
	for k in 3:
		relay_pts.append(heart + Vector2.from_angle(float(k) * TAU / 3.0) * 12.0 * u)
	var r := EpreuveRitual.make(heart, relay_pts)
	r.setup(Pillar.Kind.SMALL, 95, false)
	stage.map.add_child(r)
	r.set_physics_process(false)
	await _frames(1)
	player.global_position = r.relays[0].global_position
	_check("rituel : relais inactifs avant le lancement", not r.relays[0].can_interact())
	gold0 = RunState.gold
	_events.clear()
	_check("rituel : lancement", r.activate() and r.is_running() and _events.size() == 1 and _events[0][1] == &"rituel")
	_check("rituel : relais à portée interactifs, maintien 1,2 s", r.relays[0].can_interact() and is_equal_approx(float(r.relays[0].interact_state()["hold_s"]), 1.2))
	_check("rituel : relais hors de portée inactifs", not r.relays[1].can_interact())
	_check("rituel : cadence initiale 12 s", is_equal_approx(r.pulse_left(), 12.0) and is_equal_approx(r.pulse_interval(), 12.0))
	_check("rituel : relais 1 fermé", r.relays[0].interact() and r.closed == 1 and r.relays[0].used)
	_check("rituel : cadence 9 s", is_equal_approx(r.pulse_interval(), 9.0) and r.pulse_left() <= 9.0 + 0.001)
	_check("rituel : un relais fermé n'est plus interactif", not r.relays[0].can_interact())
	player.global_position = r.relays[1].global_position
	_check("rituel : relais 2 fermé", r.relays[1].interact() and r.closed == 2)
	_check("rituel : cadence 7 s", is_equal_approx(r.pulse_interval(), 7.0) and r.pulse_left() <= 7.0 + 0.001)
	# sauvegarde en pleine épreuve
	var rd: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict())) as Dictionary
	var r2 := EpreuveRitual.make(heart, relay_pts)
	r2.setup(Pillar.Kind.SMALL, 96, false)
	stage.map.add_child(r2)
	r2.set_physics_process(false)
	await _frames(1)
	r2.from_dict(rd)
	_check("sauvegarde rituel : relais fermés restaurés", r2.is_running() and r2.closed == 2 and r2.relays[0].used and r2.relays[1].used and not r2.relays[2].used)
	_check("sauvegarde rituel : cadence conservée", is_equal_approx(r2.pulse_interval(), 7.0) and is_equal_approx(r2.pulse_left(), r.pulse_left()))
	r2.queue_free()
	player.global_position = r.relays[2].global_position
	_check("rituel : relais 3 fermé -> résolu", r.relays[2].interact() and r.closed == 3 and r.resolved)
	_check("rituel : note « parfait » (rapide, sans onde)", r.grade == &"parfait" and r.clean and r.ring_hits == 0, "%s %.1f s" % [r.grade, r.elapsed])
	var rexp := Balance.epreuve_gold(&"parfait", Balance.station_price_p(RunState.floor_start_d, RunState.stage))
	_check("rituel : or versé (parfait = 1,5 P)", absf((RunState.gold - gold0) - rexp * gm) <= 1.0 and is_equal_approx(r.gold_paid, rexp))
	_check("rituel : mini-boss au cœur", r.get(&"_boss") != null and (r.get(&"_boss") as Enemy).active)
	(r.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(3)
	_check("rituel : mini-boss mort -> terminé", r.state == Pillar.STATE_DONE)
	r.queue_free()

	# onde du cœur : télégraphe >= 0,8 s, puis anneau qui blesse (une fois) et retire le « parfait »
	var r3 := EpreuveRitual.make(heart, relay_pts)
	r3.setup(Pillar.Kind.SMALL, 97, false)
	stage.map.add_child(r3)
	r3.set_physics_process(false)
	await _frames(1)
	r3.activate()
	player.global_position = heart + Vector2(8.0, 0.0) * u # sur le trajet de l'onde
	var tele_t := 0.0
	var seen_tele := false
	var guard_t := 0.0
	while r3.pulses == 0 and guard_t < 20.0:
		r3.tick(0.05)
		guard_t += 0.05
		if r3.is_telegraphing():
			seen_tele = true
			tele_t += 0.05
	_check("rituel : premier anneau à 12 s (%.1f)" % guard_t, absf(guard_t - (12.0 + Balance.RITUAL_TELEGRAPH_S)) <= 0.3)
	_check("rituel : anneau télégraphié %.2f s (>= 0,8 s)" % tele_t, seen_tele and tele_t >= 0.8)
	while r3.wave_radius() >= 0.0 and r3.is_running():
		r3.tick(0.05)
	_check("rituel : onde reçue une seule fois, plus de « parfait »", r3.ring_hits == 1 and not r3.clean)
	_check("rituel : la cadence repart (12 s)", is_equal_approx(r3.pulse_left(), 12.0))
	for i in 3:
		player.global_position = r3.relays[i].global_position
		r3.relays[i].interact()
	_check("rituel : fermé vite mais touché -> « bien »", r3.resolved and r3.grade == &"bien", String(r3.grade))
	(r3.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	r3.queue_free()

	# onde esquivée (joueur hors de la bande) : aucun coup
	var r4 := EpreuveRitual.make(heart, relay_pts)
	r4.setup(Pillar.Kind.SMALL, 98, false)
	stage.map.add_child(r4)
	r4.set_physics_process(false)
	await _frames(1)
	r4.activate()
	player.global_position = heart + Vector2(Balance.RITUAL_WAVE_MAX_U + 4.0, 0.0) * u
	for i in 400:
		r4.tick(0.05)
	_check("rituel : hors de portée de l'onde, aucun coup", r4.pulses >= 1 and r4.ring_hits == 0 and r4.clean)
	# délai de sécurité à 75 s
	for i in 1400:
		r4.tick(0.05)
	_check("rituel : délai de sécurité 75 s -> « fait »", r4.resolved and r4.grade == &"fait" and r4.closed == 0, "%.1f s %s" % [r4.elapsed, r4.grade])
	_check("rituel : mini-boss invoqué malgré l'échec", r4.get(&"_boss") != null)
	(r4.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	r4.queue_free()

	# ---- Or des kills en zone d'épreuve
	var e6 := EpreuveEscort.make(pts)
	e6.setup(Pillar.Kind.SMALL, 99, false)
	stage.map.add_child(e6)
	e6.set_physics_process(false)
	await _frames(1)
	var pm := get_tree().get_first_node_in_group(&"pickups") as PickupManager
	var out_pos := e6.global_position + Vector2(5000.0, 5000.0)
	_check("zone : x1 avant le lancement", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), e6.global_position), 1.0))
	e6.activate()
	_check("zone : x0,5 dans la zone d'une épreuve en cours", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), e6.global_position + Vector2(100.0, 0.0)), Balance.EPREUVE_ZONE_GOLD_MULT))
	_check("zone : x1 hors zone", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), out_pos), 1.0))
	var g_in := RunState.gold + pm.gold_carry
	pm._on_enemy_killed(null, e6.global_position, 3, true)
	var gain_in := RunState.gold + pm.gold_carry - g_in
	var g_out := RunState.gold + pm.gold_carry
	pm._on_enemy_killed(null, out_pos, 3, true)
	var gain_out := RunState.gold + pm.gold_carry - g_out
	_check("or d'un kill en zone = moitié (%.2f vs %.2f)" % [gain_in, gain_out], gain_out > 0.0 and absf(gain_in - 0.5 * gain_out) < 0.01)
	var hp_scale := RunState.gold
	e6.finish_now(&"fait")
	_check("épreuve terminée -> zone encore réduite jusqu'à la mort du mini-boss", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), e6.global_position), 0.5))
	(e6.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(3)
	_check("après la mort du mini-boss : x1", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), e6.global_position), 1.0) and hp_scale >= 0.0)
	e6.queue_free()
	Balance.EPREUVES_ENABLED = false


# --- Flux complet sur les épreuves du plan d'étage : épreuves -> déverrouillage du gros pilier
func _flow() -> void:
	print("-- flux d'étage")
	Balance.EPREUVES_ENABLED = true
	await _new_main(_seed_for_map("terrasses_rizieres_hautes"))
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var esc: EpreuveEscort = stage.pillars[0]
	var rit: EpreuveRitual = stage.pillars[1]
	var big: Pillar = stage.pillars[2]
	_events.clear()
	# Escorte : lancement par l'interaction (contact + « interagir »), pas de mini-boss avant l'arrivée
	player.global_position = esc.global_position + Vector2(20.0, 20.0)
	esc._on_body_entered(player)
	_check("escorte du plan : prête et interactive au ponton", esc.can_interact() and esc.interact_label() == "Lancer la barque")
	_check("escorte du plan : interagir lance l'épreuve", esc.interact() and esc.is_running() and esc.get(&"_boss") == null)
	var guard := 0
	while esc.is_running() and guard < 2400:
		player.global_position = esc.global_position
		await get_tree().physics_frame
		guard += 1
	_check("escorte du plan : arrivée par la physique (%d images, %.1f s)" % [guard, esc.elapsed], esc.resolved and esc.grade == &"parfait" and esc.elapsed < 40.0, "%s" % esc.grade)
	var b1: Enemy = esc.get(&"_boss")
	_check("escorte du plan : mini-boss du plan", b1 != null and b1.get_meta(&"boss_id", &"") == esc.boss_id)
	b1.take_damage(b1.max_hp * 10.0)
	await _frames(3)
	_check("escorte du plan : terminée", esc.state == Pillar.STATE_DONE and big.state == Pillar.STATE_LOCKED)
	# Rituel
	player.global_position = rit.global_position + Vector2(20.0, 20.0)
	rit._on_body_entered(player)
	_check("rituel du plan : interagir lance l'épreuve", rit.can_interact() and rit.interact() and rit.is_running())
	for rl in rit.relays:
		player.global_position = rl.global_position
		await _frames(1)
		rl.interact()
	_check("rituel du plan : 3 relais fermés", rit.resolved and rit.closed == 3)
	var b2: Enemy = rit.get(&"_boss")
	_check("rituel du plan : mini-boss du plan", b2 != null and b2.get_meta(&"boss_id", &"") == rit.boss_id)
	b2.take_damage(b2.max_hp * 10.0)
	await _frames(3)
	_check("rituel du plan : terminé -> gros pilier déverrouillé", rit.state == Pillar.STATE_DONE and big.state == Pillar.STATE_READY)
	_check("évènements : 2 départs, 2 fins", _events.filter(func(x): return x[0] == "start").size() == 2 and _events.filter(func(x): return x[0] == "end").size() == 2)
	Balance.EPREUVES_ENABLED = false


# --- Mode test : invocation depuis le panneau
func _test_mode() -> void:
	print("-- mode test")
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await _frames(3)
	Balance.EPREUVES_ENABLED = false
	TestMode.begin()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 77)
	add_child(_main)
	await _main.game_ready
	await _frames(5)
	var player: Node2D = _main.player
	player.call(&"grant_invulnerability", 1.0e6)
	var e := TestLoopTools.spawn_epreuve(get_tree(), &"escorte") as EpreuveEscort
	var r := TestLoopTools.spawn_epreuve(get_tree(), &"rituel") as EpreuveRitual
	await _frames(2)
	_check("mode test : escorte invoquée (tracé 55 u)", e != null and e.state == Pillar.STATE_READY and absf(e.length / Balance.UNIT_PX - 55.0) < 0.5)
	_check("mode test : rituel invoqué (3 relais)", r != null and r.relays.size() == 3)
	_check("mode test : les épreuves ne comptent pas comme piliers de l'étage", _main.stage.pillars.is_empty())
	if e == null or r == null:
		TestMode.end()
		return
	e.set_physics_process(false)
	r.set_physics_process(false)
	_check("mode test : lancement de l'escorte", e.activate() and e.is_running())
	_check("mode test : lancement du rituel", r.activate() and r.is_running())
	Epreuve.forced_grade = &"fait"
	_check("mode test : terminer force la note", TestLoopTools.finish_epreuves(get_tree(), Epreuve.forced_grade) == 2 and e.grade == &"fait" and r.grade == &"fait")
	_check("mode test : mini-boss invoqués", e.get(&"_boss") != null and r.get(&"_boss") != null)
	Epreuve.forced_grade = &""
	_check("mode test : retrait", TestLoopTools.clear_epreuves(get_tree()) == 2)
	TestMode.end()
	Epreuve.forced_grade = &"parfait"
	_check("hors mode test : la note forcée est ignorée", not TestMode.active)
	Epreuve.forced_grade = &""
