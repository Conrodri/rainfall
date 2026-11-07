extends Node
## Épreuve « Veine » (docs/Design_Epreuves.md §3.4 et §10) : boucle carrée de 48 u ; lancement par la source ; disque à
## 1,5 u/s ; charge seulement avec un joueur dedans et qui ne retombe jamais ; coop (prorata, plancher 0,25) ; geyser toutes
## les 6 s à 3 u devant le disque (télégraphe >= 0,8 s, un coup par joueur, « parfait » perdu) ; aller-retour sur un tracé
## ouvert ; charge 30 s -> mini-boss dans le disque ; validation de longueur ; délai de sécurité ; sauvegarde.
## godot --headless --path game res://tests/epreuve_vein_test.tscn  -> RESULT: OK

class FakePlayer extends Node2D:
	var dead := false

const KILL_GUARD := 600

var _fails := 0
var _main: Node
var _events: Array = []
var _fakes: Array[FakePlayer] = []
var _next_id := 190


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


func _new_main() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 1)
	add_child(_main)
	await _main.game_ready
	await _frames(3)
	(_main.get(&"player") as Node2D).call(&"grant_invulnerability", 1.0e6)


## Veine autonome posée dans la carte courante, sans physique propre (on la fait avancer par tick()).
func _spawn(pts: PackedVector2Array, closed: bool) -> EpreuveVein:
	var e := EpreuveVein.make(pts, closed)
	_next_id += 1
	e.setup(Pillar.Kind.SMALL, _next_id, false)
	(_main.stage as StageManager).map.add_child(e)
	e.set_physics_process(false)
	await _frames(1)
	return e


func _square(origin: Vector2, side_u: float) -> PackedVector2Array:
	var s := side_u * Balance.UNIT_PX
	return PackedVector2Array([origin, origin + Vector2(s, 0.0), origin + Vector2(s, s), origin + Vector2(0.0, s)])


func _kill_boss(e: EpreuveVein) -> void:
	var b := e.get(&"_boss") as Enemy
	if b != null:
		b.take_damage(1.0e9)
	await _frames(3)


func _run() -> void:
	Events.epreuve_started.connect(func(k: StringName) -> void: _events.append(["start", k]))
	Events.epreuve_finished.connect(func(k: StringName, g: StringName, s: float, gold: float) -> void: _events.append(["end", k, g, s, gold]))
	Balance.EPREUVES_ENABLED = false
	_check_static()
	await _new_main()
	await _basics()
	await _charge()
	await _coop()
	await _geysers()
	await _open_path()
	await _full_run()
	await _backstop()
	await _save()
	Players.clear()
	for f in _fakes:
		if is_instance_valid(f):
			f.queue_free()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


# --- Constantes locales et validation de longueur
func _check_static() -> void:
	print("-- constantes et longueur")
	_check("télégraphe du geyser >= 0,8 s", EpreuveVein.VEIN_GEYSER_TELEGRAPH_S >= 0.8)
	_check("rayon 6 u, vitesse 1,5 u/s, charge 30 s", EpreuveVein.VEIN_RADIUS_U == 6.0 and EpreuveVein.VEIN_SPEED_U == 1.5 and EpreuveVein.VEIN_CHARGE_S == 30.0)
	_check("geyser : 6 s, rayon 2 u, 3 u devant, coef 1,0", EpreuveVein.VEIN_GEYSER_EVERY_S == 6.0 and EpreuveVein.VEIN_GEYSER_RADIUS_U == 2.0 and EpreuveVein.VEIN_GEYSER_AHEAD_U == 3.0 and EpreuveVein.VEIN_GEYSER_COEF == 1.0)
	_check("note : cible 40 s, la veine n'est pas un verbe partagé", is_equal_approx(float(Balance.EPREUVE_TARGET_S[&"veine"]), 40.0))
	var u := Balance.UNIT_PX
	var sq := _square(Vector2.ZERO, 12.0)
	_check("boucle carrée : 48 u (fermeture comprise)", is_equal_approx(EpreuveVein.path_length_u(sq, true), 48.0))
	_check("tracé ouvert : 36 u (sans fermeture)", is_equal_approx(EpreuveVein.path_length_u(sq, false), 36.0))
	_check("48 u dans 40-70 u", EpreuveVein.length_in_range(sq, true))
	_check("36 u refusé", not EpreuveVein.length_in_range(sq, false))
	_check("120 u refusé", not EpreuveVein.length_in_range(_square(Vector2.ZERO, 30.0), true))
	_check("coins du Gouffre A (boucle de 40 u) acceptés", EpreuveVein.length_in_range(PackedVector2Array([Vector2(11, 21) * u, Vector2(21, 21) * u, Vector2(21, 31) * u, Vector2(11, 31) * u]), true))
	_check("galerie des Cryptes B (aller-retour de 53 u) acceptée", EpreuveVein.length_in_range(PackedVector2Array([Vector2(15, 67) * u, Vector2(17, 57) * u, Vector2(17, 45) * u, Vector2(15, 35) * u, Vector2(11, 27) * u, Vector2(11, 15) * u]), false))


# --- Source, lancement, disque
func _basics() -> void:
	print("-- source, lancement, disque")
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var u := Balance.UNIT_PX
	var origin := stage.map.get_player_start()
	var pts := _square(origin, 12.0)
	var e := await _spawn(pts, true)
	var src: EpreuveVeinSource = e.source
	_check("prête, longueur 48 u, disque sur la source", e.state == Pillar.STATE_READY and is_equal_approx(e.length / u, 48.0) and e.position.distance_to(pts[0]) < 1.0)
	_check("le pilier n'est pas interactif, la source est dans le groupe interactable", not e.can_interact() and src.is_in_group(&"interactable"))
	player.global_position = src.global_position + Vector2(600.0, 600.0)
	_check("source : hors de portée, inactive", not src.can_interact() and not src.interact())
	player.global_position = src.global_position
	_check("source : à portée, invite « Suivre la veine »", src.can_interact() and String(src.interact_state()["label"]) == "Suivre la veine" and bool(src.interact_state()["visible"]))
	_events.clear()
	_check("source : interagir lance l'épreuve", src.interact() and e.is_running() and _events.size() == 1 and _events[0][0] == "start" and _events[0][1] == &"veine")
	_check("source : plus interactive une fois lancée", not src.can_interact())
	_check("charge nulle au départ", e.vein_charge == 0.0 and e.progress() == 0.0 and e.hits == 0 and e.clean)
	# disque : 1,5 u/s ; joueur loin pour ne rien charger
	var away := Vector2(0.0, 40.0 * u)
	var d0 := e.dist_along
	for i in 8: # 2 s
		player.global_position = e.global_position + away
		e.tick(0.25)
	_check("disque : 1,5 u/s (%.2f u en 2 s)" % ((e.dist_along - d0) / u), absf((e.dist_along - d0) / u - 3.0) < 0.01)
	_check("disque : global_position suit le disque", e.position.distance_to(e.point_at(e.dist_along)) < 0.01)
	_check("la source reste fixe", absf(src.global_position.distance_to(stage.map.to_global(pts[0]))) < 0.5)
	_check("hors du disque : pas de charge, secondes dehors comptées", e.vein_charge == 0.0 and absf(e.out_s - 2.0) < 0.01)
	# boucle : le disque revient au départ après 48 u
	e.advance(45.0 * u)
	_check("boucle : après 48 u le disque est revenu au départ (%.2f u)" % (e.dist_along / u), minf(e.dist_along, e.length - e.dist_along) / u < 0.01)
	_check("boucle : distance toujours dans [0, 48[ u", e.dist_along >= 0.0 and e.dist_along < e.length)
	e.queue_free()
	await _frames(1)


# --- Charge : seulement dedans, ne retombe jamais
func _charge() -> void:
	print("-- charge")
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var u := Balance.UNIT_PX
	var e := await _spawn(_square(stage.map.get_player_start(), 12.0), true)
	e.activate()
	for i in 16: # 4 s dans le disque
		player.global_position = e.global_position
		e.tick(0.25)
	_check("dedans : charge ≈ 4 s (%.2f)" % e.vein_charge, absf(e.vein_charge - 4.0) < 0.01)
	_check("progression 4/30", absf(e.progress() - 4.0 / 30.0) < 0.001)
	var c1 := e.vein_charge
	for i in 12: # 3 s dehors
		player.global_position = e.global_position + Vector2(0.0, 40.0 * u)
		e.tick(0.25)
	_check("dehors : la charge ne bouge pas et ne retombe jamais", e.vein_charge == c1, "%.2f" % e.vein_charge)
	# bord du disque : 5,9 u dedans, 6,2 u dehors
	player.global_position = e.global_position + Vector2(0.0, 5.9 * u)
	var c2 := e.vein_charge
	e.tick(0.25)
	_check("à 5,9 u du centre : dans le disque", e.vein_charge > c2)
	player.global_position = e.global_position + Vector2(0.0, 6.3 * u)
	c2 = e.vein_charge
	e.tick(0.25)
	_check("à 6,3 u du centre : hors du disque", e.vein_charge == c2)
	e.queue_free()
	await _frames(1)


## Place les joueurs (le vrai puis les faux) : ceux dont l'indice est dans `inside` au centre du disque, les autres très loin.
func _place_players(e: EpreuveVein, inside: Array) -> void:
	var all: Array = [_main.player] + _fakes
	for i in all.size():
		(all[i] as Node2D).global_position = e.global_position + (Vector2.ZERO if inside.has(i) else Vector2(0.0, 60.0 * Balance.UNIT_PX))


# --- Coop : prorata des vivants dedans, plancher
func _coop() -> void:
	print("-- coop")
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var u := Balance.UNIT_PX
	Players.clear()
	Players.register(player)
	for i in 3:
		var f := FakePlayer.new()
		add_child(f)
		_fakes.append(f)
		Players.register(f)
	_check("4 joueurs vivants", Players.alive_count() == 4)
	var e := await _spawn(_square(stage.map.get_player_start(), 12.0), true)
	e.activate()
	_place_players(e, [0])
	_check("1 dedans sur 4 : taux 0,25 (plancher)", is_equal_approx(e.vein_rate(), Balance.COOP_CHARGE_FLOOR))
	_place_players(e, [0, 1])
	_check("2 dedans sur 4 : taux 0,5", is_equal_approx(e.vein_rate(), 0.5))
	_place_players(e, [0, 1, 2, 3])
	_check("4 dedans sur 4 : taux 1", is_equal_approx(e.vein_rate(), 1.0))
	_place_players(e, [])
	_check("0 dedans : taux 0", e.vein_rate() == 0.0)
	_place_players(e, [0, 1])
	var c0 := e.vein_charge
	for i in 8: # 2 s à 0,5
		_place_players(e, [0, 1])
		e.tick(0.25)
	_check("2 dedans sur 4 pendant 2 s : +1 s de charge (%.2f)" % (e.vein_charge - c0), absf((e.vein_charge - c0) - 1.0) < 0.01)
	# un joueur mort ne compte pas
	_fakes[2].dead = true
	_fakes[1].dead = true
	_check("2 morts : seuls les 2 vivants comptent", Players.alive_count() == 2)
	_place_players(e, [0])
	_check("1 vivant dedans sur 2 vivants : 0,5", is_equal_approx(e.vein_rate(), 0.5))
	_fakes[2].dead = false
	_fakes[1].dead = false
	e.queue_free()
	await _frames(1)
	# géyser en coop : un coup par joueur et par geyser
	var e2 := await _spawn(_square(stage.map.get_player_start(), 12.0), true)
	e2.activate()
	for i in 24: # 6 s : le geyser est annoncé
		_place_players(e2, [])
		e2.tick(0.25)
	var gp: Vector2 = stage.map.to_global(e2.geyser_pos())
	player.global_position = gp
	_fakes[0].global_position = gp
	_fakes[1].global_position = gp + Vector2(30.0, 0.0)
	_fakes[2].global_position = gp + Vector2(0.0, 6.0 * u)
	_check("geyser annoncé", e2.geyser_phase() == EpreuveVein.GEY_TELEGRAPH)
	for i in 8: # télégraphe puis éruption (plusieurs pas)
		e2.tick(0.25)
	_check("3 joueurs dans le cercle : 3 coups, un par joueur (%d)" % e2.hits, e2.hits == 3)
	_check("geyser reçu : « parfait » perdu", not e2.clean)
	e2.queue_free()
	await _frames(1)
	Players.clear()


# --- Geysers : cadence, position, télégraphe, esquive
func _geysers() -> void:
	print("-- geysers")
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var u := Balance.UNIT_PX
	var far := Vector2(0.0, 60.0 * u)
	var e := await _spawn(_square(stage.map.get_player_start(), 12.0), true)
	e.activate()
	for i in 23: # 5,75 s
		player.global_position = e.global_position + far
		e.tick(0.25)
	_check("pas de geyser avant 6 s", e.geyser_phase() == EpreuveVein.GEY_NONE and e.pulses == 0)
	player.global_position = e.global_position + far
	e.tick(0.25)
	_check("geyser annoncé à 6 s", e.geyser_phase() == EpreuveVein.GEY_TELEGRAPH)
	var expected := e.point_at(e.dist_along + 3.0 * u)
	_check("sur le tracé, 3 u devant le disque", e.geyser_pos().distance_to(expected) < 2.0, "%s vs %s" % [e.geyser_pos(), expected])
	_check("géométrie : à 3 u du centre sur un segment droit", absf(e.geyser_pos().distance_to(e.position) / u - 3.0) < 0.2)
	# esquive : dans le cercle pendant le télégraphe, dehors à l'éruption
	var gp: Vector2 = stage.map.to_global(e.geyser_pos())
	player.global_position = gp
	e.tick(0.25)
	e.tick(0.25)
	_check("télégraphe : aucun coup", e.hits == 0 and e.geyser_phase() == EpreuveVein.GEY_TELEGRAPH)
	player.global_position = gp + Vector2(3.0 * u, 0.0)
	for i in 6:
		e.tick(0.25)
	_check("sorti avant l'éruption : aucun coup, 1 geyser émis", e.hits == 0 and e.clean and e.pulses == 1)
	_check("l'éruption est finie, prochain geyser dans 6 s", e.geyser_phase() == EpreuveVein.GEY_NONE and e.geyser_left() > 4.0)
	# deuxième geyser : joueur dessus -> un coup, une fois
	for i in 40:
		player.global_position = e.global_position + far
		e.tick(0.25)
		if e.geyser_phase() == EpreuveVein.GEY_TELEGRAPH:
			break
	_check("deuxième geyser annoncé", e.geyser_phase() == EpreuveVein.GEY_TELEGRAPH)
	gp = stage.map.to_global(e.geyser_pos())
	player.global_position = gp
	for i in 8:
		e.tick(0.25)
	_check("joueur dans le cercle à l'éruption : 1 coup (pas un par pas)", e.hits == 1 and not e.clean, "hits=%d" % e.hits)
	_check("dégât de geyser > 0 (coup de mini-boss)", e.geyser_damage() > 0.0 and is_equal_approx(e.geyser_damage(), Balance.ritual_ring_damage(RunState.difficulty())))
	e.queue_free()
	await _frames(1)


# --- Tracé ouvert : aller-retour
func _open_path() -> void:
	print("-- tracé ouvert")
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var u := Balance.UNIT_PX
	var o := stage.map.get_player_start()
	var pts := PackedVector2Array([o, o + Vector2(8.0, 0.0) * u])
	var e := await _spawn(pts, false)
	_check("ouvert : longueur 8 u, pas de fermeture", not e.closed and is_equal_approx(e.length / u, 8.0))
	e.activate()
	player.global_position = e.global_position + Vector2(0.0, 60.0 * u)
	e.advance(10.0 * u)
	_check("rebond au bout : 6 u, sens inversé", is_equal_approx(e.dist_along / u, 6.0) and e.dir == -1, "%.2f u dir %d" % [e.dist_along / u, e.dir])
	e.advance(10.0 * u)
	_check("rebond au départ : 4 u, sens normal", is_equal_approx(e.dist_along / u, 4.0) and e.dir == 1, "%.2f u dir %d" % [e.dist_along / u, e.dir])
	e.dist_along = 7.0 * u
	e.dir = 1
	e.advance(0.0)
	var ahead := e.point_ahead(3.0 * u)
	_check("geyser devant au bout : rebondit (x = 6 u)", absf((ahead - pts[0]).x / u - 6.0) < 0.01, "%s" % ahead)
	_check("aller-retour : jamais de saut de position", e.position.distance_to(e.point_at(e.dist_along)) < 0.01)
	e.queue_free()
	await _frames(1)


# --- Charge pleine : mini-boss dans le disque, note, or
func _full_run() -> void:
	print("-- charge pleine")
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var u := Balance.UNIT_PX
	var gold0: float = RunState.gold
	var e := await _spawn(_square(stage.map.get_player_start(), 12.0), true)
	_events.clear()
	e.activate()
	var guard := 0
	while e.is_running() and guard < KILL_GUARD:
		# le disque porte le joueur vers le geyser : il se tient 2,5 u derrière le centre dès qu'un geyser est annoncé
		var at := e.global_position
		if e.geyser_phase() != EpreuveVein.GEY_NONE:
			var gdir: Vector2 = (stage.map.to_global(e.geyser_pos()) - e.global_position).normalized()
			at = e.global_position - gdir * 2.5 * u
		player.global_position = at
		e.tick(0.25)
		guard += 1
	_check("30 s dedans -> épreuve résolue (%.1f s)" % e.elapsed, e.resolved and guard < KILL_GUARD and absf(e.elapsed - 30.0) <= 0.5)
	_check("geysers esquivés en restant dans le disque : aucun coup", e.hits == 0 and e.clean and e.pulses >= 4, "hits=%d pulses=%d" % [e.hits, e.pulses])
	_check("note « parfait »", e.grade == &"parfait", String(e.grade))
	var expected := Balance.epreuve_gold(&"parfait", Balance.station_price_p(RunState.floor_start_d, RunState.stage))
	var gm: float = (player.call(&"gold_mult") as float)
	_check("or : parfait = 1,5 P versé", is_equal_approx(e.gold_paid, expected) and absf((RunState.gold - gold0) - expected * gm) <= 1.0)
	_check("évènement de fin (veine, parfait)", _events.size() == 2 and _events[1][0] == "end" and _events[1][1] == &"veine" and _events[1][2] == &"parfait")
	var boss := e.get(&"_boss") as Enemy
	_check("mini-boss invoqué dans le disque", boss != null and boss.active and boss.global_position.distance_to(e.global_position) <= e.disc_radius())
	_check("zone du mini-boss", (_main.director as Director)._zones.get(e.zone_id, {}).get("kind", &"") == &"mini")
	var d_stop := e.dist_along
	for i in 8:
		e.tick(0.25)
	_check("le disque s'arrête une fois résolu", e.dist_along == d_stop)
	await _kill_boss(e)
	_check("mini-boss mort -> épreuve terminée", e.state == Pillar.STATE_DONE)
	e.queue_free()
	await _frames(1)
	# note « bien » : un geyser reçu
	var e2 := await _spawn(_square(stage.map.get_player_start(), 12.0), true)
	e2.activate()
	e2.clean = false
	e2.vein_charge = 29.0
	player.global_position = e2.global_position
	for i in 8:
		player.global_position = e2.global_position
		e2.tick(0.25)
		if not e2.is_running():
			break
	_check("faute + charge pleine : note « bien »", e2.resolved and e2.grade == &"bien", String(e2.grade))
	await _kill_boss(e2)
	e2.queue_free()
	await _frames(1)
	# note « fait » forcée par le mode test ; termine l'épreuve sans charge
	var e3 := await _spawn(_square(stage.map.get_player_start(), 12.0), true)
	e3.activate()
	e3.finish_now(&"fait")
	_check("finish_now(fait) : résolue, note fait, mini-boss présent", e3.resolved and e3.grade == &"fait" and e3.get(&"_boss") != null)
	await _kill_boss(e3)
	e3.queue_free()
	await _frames(1)


# --- Délai de sécurité
func _backstop() -> void:
	print("-- délai de sécurité")
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var u := Balance.UNIT_PX
	var e := await _spawn(_square(stage.map.get_player_start(), 12.0), true)
	e.activate()
	var guard := 0
	while e.is_running() and guard < KILL_GUARD:
		player.global_position = e.global_position + Vector2(0.0, 60.0 * u)
		e.tick(0.5)
		guard += 1
	_check("joueur absent : « fait » à 75 s, jamais bloqué", e.resolved and e.grade == &"fait" and absf(e.elapsed - Balance.EPREUVE_BACKSTOP_S) <= 0.5, "%.1f s %s" % [e.elapsed, e.grade])
	_check("mini-boss invoqué quand même", e.get(&"_boss") != null)
	await _kill_boss(e)
	e.queue_free()
	await _frames(1)


# --- Sauvegarde en pleine épreuve
func _save() -> void:
	print("-- sauvegarde")
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var u := Balance.UNIT_PX
	var pts := _square(stage.map.get_player_start(), 12.0)
	var e := await _spawn(pts, true)
	e.activate()
	for i in 48: # 12 s dedans : un geyser a été émis
		player.global_position = e.global_position
		e.tick(0.25)
	e.hits = 1
	var sd: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict())) as Dictionary
	_check("dict : champs de la veine", (sd["epreuve"] as Dictionary).has("dist") and (sd["epreuve"] as Dictionary).has("dir") and (sd["epreuve"] as Dictionary).has("charge") and (sd["epreuve"] as Dictionary).has("hits") and (sd["epreuve"] as Dictionary).has("geyser_left"))
	var e2 := EpreuveVein.make(pts, true)
	e2.setup(Pillar.Kind.SMALL, e.zone_id, false)
	stage.map.add_child(e2)
	e2.set_physics_process(false)
	await _frames(1)
	e2.from_dict(sd)
	_check("reprise : en cours", e2.state == Pillar.STATE_ACTIVE and e2.is_running())
	_check("reprise : disque, charge, coups, temps", is_equal_approx(e2.dist_along, e.dist_along) and is_equal_approx(e2.vein_charge, e.vein_charge) and e2.hits == 1 and is_equal_approx(e2.elapsed, e.elapsed) and e2.dir == e.dir)
	_check("reprise : position du disque et source fixe", e2.position.distance_to(e.position) < 1.0 and absf(e2.source.global_position.distance_to(stage.map.to_global(pts[0]))) < 0.5)
	_check("reprise : cadence des geysers conservée", is_equal_approx(e2.geyser_left(), e.geyser_left()))
	# la reprise continue à charger
	var c := e2.vein_charge
	player.global_position = e2.global_position
	e2.tick(0.25)
	_check("reprise : la charge reprend", e2.vein_charge > c)
	# épreuve résolue avec mini-boss déjà invoqué : revient à « prête » sans rejouer l'épreuve
	e.finish_now(&"bien")
	var rd: Dictionary = JSON.parse_string(JSON.stringify(e.to_dict())) as Dictionary
	var e3 := EpreuveVein.make(pts, true)
	e3.setup(Pillar.Kind.SMALL, 901, false)
	stage.map.add_child(e3)
	e3.set_physics_process(false)
	await _frames(1)
	e3.from_dict(rd)
	_check("reprise après résolution : mini-boss à relancer sans épreuve", e3.resolved and e3.state == Pillar.STATE_READY)
	await _kill_boss(e)
	e.queue_free()
	e2.queue_free()
	e3.queue_free()
	await _frames(1)
