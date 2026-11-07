extends Node
## Poursuite (docs/Design_Epreuves.md §3.3, lot E1) : 6 bornes synthétiques en anneau de 12 u ; lancement ; la lumière saute
## toutes les 8 s vers une borne à 9-17 u (jamais la précédente) ; vacillement 1,5 s avant le saut ; point si un joueur est
## à <= 2 u avant le saut (borne « done »), sinon raté (`clean` faux) ; 5 points -> résolu, mini-boss sous la lumière ;
## coop (cible x 0,92) ; global_position = borne allumée ; délai de sécurité ; sauvegarde.
## godot --headless --path game res://tests/epreuve_chase_test.tscn  -> RESULT: OK

const KILL_GUARD := 800

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


func _ring(center: Vector2, n: int, r_u: float) -> Array:
	var out: Array = []
	for k in n:
		out.append(center + Vector2.from_angle(float(k) * TAU / float(n)) * r_u * Balance.UNIT_PX)
	return out


func _spawn(stage: StageManager, pts: Array, id: int) -> EpreuveChase:
	var e := EpreuveChase.make(pts)
	e.setup(Pillar.Kind.SMALL, id, false)
	stage.map.add_child(e)
	e.set_physics_process(false)
	await _frames(1)
	return e


func _run() -> void:
	Events.epreuve_started.connect(func(k: StringName) -> void: _events.append(["start", k]))
	Events.epreuve_finished.connect(func(k: StringName, g: StringName, s: float, gold: float) -> void: _events.append(["end", k, g, s, gold]))
	Balance.EPREUVES_ENABLED = true
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	add_child(_main)
	await _main.game_ready
	await _frames(3)
	var player: Node2D = _main.player
	player.call(&"grant_invulnerability", 1.0e6)
	var stage: StageManager = _main.stage
	var u := Balance.UNIT_PX
	var origin: Vector2 = stage.map.get_player_start()
	var far := Vector2(4000.0, 4000.0)
	var pts := _ring(origin, 6, 12.0)

	print("-- constantes (Balance)")
	_check("6 bornes, 8 s, 5 points, [9, 17] u, portée 2 u, vacillement 1,5 s", Balance.CHASE_POSTS == 6 and is_equal_approx(Balance.CHASE_JUMP_S, 8.0) and Balance.CHASE_POINTS == 5 and is_equal_approx(Balance.CHASE_JUMP_MIN_U, 9.0) and is_equal_approx(Balance.CHASE_JUMP_MAX_U, 17.0) and is_equal_approx(Balance.CHASE_REACH_U, 2.0) and is_equal_approx(Balance.CHASE_WARN_S, 1.5))
	_check("cible « parfait » 45 s", is_equal_approx(float(Balance.EPREUVE_TARGET_S[&"poursuite"]), 45.0))

	print("-- lancement et saut raté")
	var e := await _spawn(stage, pts, 191)
	_check("prête : 6 bornes, position = autel", e.state == Pillar.STATE_READY and e.posts.size() == 6 and e.position.distance_to(pts[0]) < 0.01 and e.verb == &"poursuite")
	e.biome = &"foret"
	_check("libellé du Gouffre (data/epreuves.json)", e.interact_label() == "Réveiller le follet")
	e.biome = &"cryptes"
	_check("libellé des Cryptes (data/epreuves.json)", e.interact_label() == "Éveiller l'éclat")
	e.biome = &""
	_check("bornes fixes (position locale relative)", e.posts[3].global_position.distance_to(e.get_parent().to_global(pts[3])) < 0.5)
	player.global_position = far
	var gold0: float = RunState.gold
	_events.clear()
	_check("lancement", e.activate() and e.is_running() and _events.size() == 1 and _events[0] == ["start", &"poursuite"])
	_check("lumière sur l'autel, 8 s avant le saut", e.lit == 0 and is_equal_approx(e.jump_left, 8.0) and e.points == 0)
	_check("borne 0 allumée (état)", e.posts[0].state == EpreuveChasePost.STATE_LIT)
	for i in 25: # 6,25 s
		e.tick(0.25)
	_check("pas de vacillement avant 6,5 s", not e.is_warning() and e.lit == 0)
	for i in 5: # 7,5 s
		e.tick(0.25)
	_check("vacillement dans les 1,5 s avant le saut", e.is_warning() and e.lit == 0)
	var jumps: Array = []
	e.jumped.connect(func(a: int, b: int) -> void: jumps.append([a, b]))
	for i in 3: # 8,25 s
		e.tick(0.25)
	_check("saut à 8 s vers une borne voisine", jumps.size() == 1 and jumps[0][0] == 0 and e.lit == jumps[0][1] and e.lit != 0, str(jumps))
	var dist_u: float = (pts[0] as Vector2).distance_to(pts[e.lit] as Vector2) / u
	_check("portée du saut 9-17 u (%.1f u)" % dist_u, dist_u >= 9.0 and dist_u <= 17.0)
	_check("borne ratée : misses 1, plus de parfait", e.misses == 1 and not e.clean and e.points == 0)
	_check("global_position = borne allumée", e.position.distance_to(pts[e.lit]) < 0.01)
	_check("autre borne inchangée dans le monde", e.posts[3].global_position.distance_to(e.get_parent().to_global(pts[3])) < 0.5)
	_check("compteur du saut remis à 8 s", e.jump_left > 7.5 and not e.is_warning())
	var first_lit := e.lit

	print("-- point marqué")
	player.global_position = e.global_position + Vector2(1.5 * u, 0.0)
	e.tick(0.1)
	_check("joueur à <= 2 u : 1 point, borne « done »", e.points == 1 and e.done_posts.has(first_lit) and e.posts[first_lit].state == EpreuveChasePost.STATE_DONE)
	var pts_before := e.points
	e.tick(0.5)
	_check("un seul point par borne allumée", e.points == pts_before)
	# la lumière saute quand même à 8 s, jamais vers la borne quittée ni une borne « done »
	player.global_position = far
	var guard := 0
	while e.lit == first_lit and guard < 100:
		e.tick(0.25)
		guard += 1
	_check("saut malgré le point marqué, pas de faute en plus", e.lit != first_lit and e.misses == 1 and e.points == 1)
	_check("jamais la borne qu'elle vient de quitter", e.lit != e.prev and e.prev == first_lit)
	_check("borne « done » reste allumée", e.posts[first_lit].state == EpreuveChasePost.STATE_DONE)
	_check("progression 1/5", is_equal_approx(e.progress(), 0.2))

	print("-- 5 points : résolution")
	guard = 0
	while e.is_running() and guard < KILL_GUARD:
		player.global_position = e.global_position
		e.tick(0.25)
		guard += 1
	_check("5 points -> résolu", e.resolved and e.points == 5 and guard < KILL_GUARD)
	_check("note « bien » (une borne ratée)", e.grade == &"bien", String(e.grade))
	var expected := Balance.epreuve_gold(&"bien", Balance.station_price_p(RunState.floor_start_d, RunState.stage))
	_check("or versé (bien)", is_equal_approx(e.gold_paid, expected) and absf((RunState.gold - gold0) - expected * (player.call(&"gold_mult") as float)) <= 1.0)
	_check("évènement de fin", _events.size() == 2 and _events[1][0] == "end" and _events[1][1] == &"poursuite" and _events[1][2] == &"bien")
	var boss: Enemy = e.get(&"_boss")
	_check("mini-boss sous la lumière", boss != null and boss.active and boss.global_position.distance_to(e.global_position) < 400.0)
	_check("lumière fixée", e.posts[e.lit].state != EpreuveChasePost.STATE_IDLE)
	var lit_final := e.lit
	for i in 40: # la lumière ne bouge plus
		e.tick(0.25)
	_check("la lumière reste fixée après la résolution", e.lit == lit_final and e.state == Pillar.STATE_ACTIVE)
	boss.take_damage(boss.max_hp * 10.0)
	await _frames(3)
	_check("mini-boss mort -> terminé", e.state == Pillar.STATE_DONE)
	e.queue_free()

	print("-- note parfait et coop")
	var e2 := await _spawn(stage, pts, 192)
	e2.activate()
	guard = 0
	while e2.is_running() and guard < KILL_GUARD:
		player.global_position = e2.global_position
		e2.tick(0.25)
		guard += 1
	_check("parfait : joueur sur chaque borne (%.1f s)" % e2.elapsed, e2.grade == &"parfait" and e2.clean and e2.misses == 0 and e2.elapsed <= 45.0)
	_check("parfait = 1,5 P", is_equal_approx(e2.gold_paid, 1.5 * Balance.station_price_p(RunState.floor_start_d, RunState.stage)))
	# cible x 0,92 à 2 joueurs : 42 s est parfait en solo, plus à deux (42 / 0,92 = 45,7 s)
	e2.elapsed = 42.0
	e2.clean = true
	RunState.party_size = 1
	var solo := e2.compute_grade()
	RunState.party_size = 2
	var duo := e2.compute_grade()
	RunState.party_size = 1
	_check("coop : 42 s parfait en solo, bien à 2 (cible x 0,92)", solo == &"parfait" and duo == &"bien", "%s / %s" % [solo, duo])
	_check("coop : multiplicateur 0,92", is_equal_approx(Balance.epreuve_target_party_mult(2), 0.92))
	(e2.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	e2.queue_free()

	print("-- choix du saut")
	# anneau de 12 u : voisins à 12 u, bornes à 20,8 et 24 u hors portée
	var e3 := await _spawn(stage, pts, 193)
	e3.activate()
	player.global_position = far
	var seen: Array = []
	e3.jumped.connect(func(a: int, b: int) -> void: seen.append([a, b]))
	for i in 150: # 37,5 s : 4 sauts
		e3.tick(0.25)
	var ok_dist := true
	var ok_prev := true
	for k in seen.size():
		var d: float = pts[seen[k][0]].distance_to(pts[seen[k][1]]) / u
		if d < 9.0 or d > 17.0:
			ok_dist = false
		if k > 0 and seen[k][1] == seen[k - 1][0]:
			ok_prev = false
	_check("%d sauts, tous à 9-17 u" % seen.size(), seen.size() == 4 and ok_dist, str(seen))
	_check("jamais un retour immédiat sur la borne quittée", ok_prev, str(seen))
	e3.finish_now(&"fait")
	(e3.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	e3.queue_free()
	# sans candidat dans la portée : la plus proche
	var e3b := await _spawn(stage, [origin, origin + Vector2(30.0, 0.0) * u, origin + Vector2(60.0, 0.0) * u], 194)
	e3b.activate()
	_check("sans candidat : la plus proche", e3b.pick_next() == 1)
	e3b.finish_now(&"fait")
	(e3b.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	e3b.queue_free()

	print("-- délai de sécurité")
	var e4 := await _spawn(stage, pts, 195)
	e4.activate()
	player.global_position = far
	guard = 0
	while e4.is_running() and guard < KILL_GUARD:
		e4.tick(0.5)
		guard += 1
	_check("75 s sans aucun point -> « fait »", e4.resolved and e4.grade == &"fait" and absf(e4.elapsed - Balance.EPREUVE_BACKSTOP_S) <= 0.5 and e4.points == 0, "%.1f s %s" % [e4.elapsed, e4.grade])
	_check("mini-boss invoqué quand même", e4.get(&"_boss") != null)
	(e4.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	e4.queue_free()

	print("-- sauvegarde")
	var e5 := await _spawn(stage, pts, 196)
	e5.activate()
	player.global_position = e5.global_position
	e5.tick(0.1) # point sur l'autel
	player.global_position = far
	for i in 80: # 20 s : un saut marqué, un saut raté
		e5.tick(0.25)
	var sd: Dictionary = JSON.parse_string(JSON.stringify(e5.to_dict())) as Dictionary
	var e6 := await _spawn(stage, pts, 196)
	e6.from_dict(sd)
	_check("reprise en cours", e6.state == Pillar.STATE_ACTIVE and e6.is_running() and e6.lit == e5.lit and e6.prev == e5.prev)
	_check("reprise : points, ratés, compteur, bornes marquées", e6.points == e5.points and e6.misses == e5.misses and is_equal_approx(e6.jump_left, e5.jump_left) and e6.done_posts == e5.done_posts and is_equal_approx(e6.elapsed, e5.elapsed))
	_check("reprise : position = borne allumée, bornes marquées allumées", e6.position.distance_to(pts[e5.lit]) < 0.01 and e6.posts[0].state == EpreuveChasePost.STATE_DONE and not e6.clean, "pos %s vs %s ; p0 %s ; clean %s ; lit %d" % [e6.position, pts[e5.lit], e6.posts[0].state, e6.clean, e5.lit])
	e6.tick(0.25)
	_check("reprise : l'épreuve continue", e6.is_running() and e6.elapsed > e5.elapsed)
	e5.queue_free()
	e6.queue_free()
	await _frames(1)

	Balance.EPREUVES_ENABLED = false
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
