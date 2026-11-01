extends Node
## Coop 1-4, étape 2 lot 3 « Étage, loot et économie » (docs/multi/Design_Coop.md §1-2) :
##  - une mort de monstre crédite le même or (et la même XP) à chaque joueur ;
##  - un coffre payé par le joueur 2 donne l'objet au joueur 2, ni or ni objet ailleurs ; coffre réservé refusé aux autres ;
##  - pas de pause en coop (ChestSession.is_blocking) ;
##  - pilier : charge proportionnelle aux joueurs vivants dans la zone (plancher 0,25) ;
##  - téléporteur : compte à rebours de 15 s après le premier « interagir » ;
##  - résurrection au début de l'étage, anneau de départ ;
##  - coffre de boss : un par joueur, réservé ; reliquaires idem ;
##  - débordement de coffres à 4 joueurs : cases C d'abord, repli sans empilement, « posés / voulus » journalisé.
## godot --headless --path game res://tests/coop_stage_test.tscn  -> RESULT: OK

class FakePlayer extends Node2D:
	var dead := false


class FakeDirector extends Node:
	func spawn_boss(_kind: StringName, position: Vector2) -> Node2D:
		var b := Node2D.new()
		b.position = position
		add_child(b)
		return b

	func set_zone(_id: int, _center: Vector2, _radius: float, _active: bool, _kind: StringName = &"mini") -> void:
		pass


var _fails := 0
var _nodes: Array[FakePlayer] = []
var _fake_chest_script: GDScript
var _mgr: StageManager


func _check(label: String, cond: bool, detail: String = "") -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label, ("  (" + detail + ")") if detail != "" else "")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	_cleanup()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _fake(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.position = pos
	p.add_to_group(&"player")
	add_child(p)
	_nodes.append(p)
	return p


func _cleanup() -> void:
	Players.clear()
	for n in _nodes:
		if is_instance_valid(n):
			n.remove_from_group(&"player")
			n.queue_free()
	_nodes.clear()


func _run() -> void:
	_fake_chest_script = GDScript.new()
	_fake_chest_script.source_code = "extends Node2D\nvar kind\nvar stage\nvar reserved_slot = -1\nfunc setup(k, s, _c = null):\n\tkind = k\n\tstage = s\n"
	_fake_chest_script.reload()
	await get_tree().process_frame
	_check("solo : le jeu se met en pause (is_blocking)", ChestSession.is_blocking())

	# --- 3 joueurs
	for i in 3:
		_fake(Vector2(100.0 * i, 0.0))
		Players.register(_nodes[i])
	RunState.start_run(&"moyen", 4242)
	_check("3 joueurs inscrits, party_size 3", Players.count() == 3 and RunState.party_size == 3)
	_check("coop : pas de pause (is_blocking faux)", not ChestSession.is_blocking())
	await _test_kill_gold()
	await _test_chest_payer()
	await _test_pillar_rate()

	# --- 4 joueurs : étage, téléporteur, résurrection, coffres de boss, débordement
	_fake(Vector2(300.0, 0.0))
	Players.register(_nodes[3])
	RunState.start_run(&"moyen", 4243)
	_check("4 joueurs, party_size 4", Players.count() == 4 and RunState.party_size == 4)
	var director := FakeDirector.new()
	director.add_to_group(&"director")
	add_child(director)
	_mgr = StageManager.new()
	_mgr.chest_factory = func() -> Node2D:
		var c := Node2D.new()
		c.set_script(_fake_chest_script)
		return c
	add_child(_mgr)
	await _frames(2)
	await _test_stage_start()
	await _test_teleporter()
	await _test_boss_chests()
	await _test_overflow()


# --- Or et XP -------------------------------------------------------------------------------
func _test_kill_gold() -> void:
	var pm := PickupManager.new()
	add_child(pm)
	await _frames(1)
	var before: Array[float] = []
	var xp_before: Array[float] = []
	for i in 3:
		before.append(Players.state_of(i).gold)
		xp_before.append(Players.state_of(i).xp + 1000.0 * Players.state_of(i).level)
	for k in 12:
		Events.enemy_killed.emit(null, Vector2(50.0, 50.0), 3, false)
	var gains: Array[float] = []
	var xps: Array[float] = []
	for i in 3:
		gains.append(Players.state_of(i).gold - before[i])
		xps.append(Players.state_of(i).xp + 1000.0 * Players.state_of(i).level - xp_before[i])
	_check("kill : or > 0", gains[0] > 0.0, str(gains))
	_check("kill : même or pour chaque joueur", is_equal_approx(gains[0], gains[1]) and is_equal_approx(gains[1], gains[2]), str(gains))
	_check("kill : même XP pour chaque joueur", xps[0] > 0.0 and is_equal_approx(xps[0], xps[1]) and is_equal_approx(xps[1], xps[2]), str(xps))
	_check("kill : or entier (pièces)", is_equal_approx(gains[0], roundf(gains[0])))
	# prime directe : montant × coop_gold_mult(n)
	var b2 := Players.state_of(1).gold
	pm._carry_coop.clear()
	pm.gold_carry = 0.0
	pm.drop_bounty(Vector2.ZERO, 100.0)
	var want := floorf(100.0 * Balance.coop_gold_mult(3) + 0.0001)
	_check("prime 100 : +%d à chacun (coop_gold_mult)" % int(want), is_equal_approx(Players.state_of(1).gold - b2, want), str(Players.state_of(1).gold - b2))
	pm.queue_free()
	await _frames(1)


# --- Coffre : payeur = bénéficiaire ----------------------------------------------------------
func _test_chest_payer() -> void:
	var st1 := Players.state_of(0)
	var st2 := Players.state_of(1)
	var st3 := Players.state_of(2)
	# session directe : l'objet va dans le PlayerState du propriétaire
	var items_before := [st1.items.duplicate(), st3.items.duplicate()]
	var session := ChestSession.new(&"petit", 1, 40.0, null, st2)
	session.start()
	_check("session : propriétaire = joueur 2", session.state == st2)
	_check("session : deux propositions", session.offered.size() == 2)
	var picked := StringName(session.offered[0])
	var got: Array = []
	var c_by := func(slot: int, id: StringName) -> void: got.append([slot, id])
	Events.item_chosen_by.connect(c_by)
	session.choose(get_tree(), 0)
	Events.item_chosen_by.disconnect(c_by)
	_check("coffre payé par J2 : objet chez J2", st2.stacks(picked) == 1)
	_check("coffre payé par J2 : rien chez J1 et J3", st1.items == items_before[0] and st3.items == items_before[1])
	_check("item_chosen_by identifie J2", got == [[1, picked]], str(got))
	# vrai coffre : or dépensé par le payeur seulement, coffre réservé refusé aux autres
	var chest: Chest = (load("res://scenes/chests/chest.tscn") as PackedScene).instantiate()
	chest.position = Vector2(2000.0, 2000.0)
	add_child(chest)
	chest.setup(&"petit", 1)
	chest.reserved_slot = 1
	await _frames(1)
	st1.gold = 5000.0
	st2.gold = 5000.0
	st3.gold = 5000.0
	_check("coffre réservé J2 : refusé à J1", not chest.try_open(_nodes[0]) and st1.gold == 5000.0 and st3.gold == 5000.0)
	var price := chest.current_price()
	_check("coffre réservé J2 : ouvert par J2", chest.try_open(_nodes[1]))
	_check("or dépensé par J2 seulement", is_equal_approx(st2.gold, 5000.0 - price) and st1.gold == 5000.0 and st3.gold == 5000.0, str(st2.gold))
	_check("coop : le jeu n'est pas en pause pendant l'ouverture", not get_tree().paused)
	for c in get_children():
		if c.has_meta(&"owner_slot"):
			_check("UI de coffre portant owner_slot = 1", int(c.get_meta(&"owner_slot")) == 1)
			c.queue_free()
	await _frames(2)
	if is_instance_valid(chest):
		chest.queue_free()
	# propriétaire spectateur : un allié ouvre à sa place
	var chest2: Chest = (load("res://scenes/chests/chest.tscn") as PackedScene).instantiate()
	chest2.position = Vector2(2400.0, 2000.0)
	add_child(chest2)
	chest2.setup(&"boss", 1)
	chest2.reserved_slot = 2
	await _frames(1)
	Players.set_spectating(2)
	_check("coffre d'un spectateur : un allié l'ouvre", chest2.try_open(_nodes[0]))
	for c in get_children():
		if c.has_meta(&"owner_slot"):
			_check("coffre du spectateur : l'objet va au propriétaire (J3)", int(c.get_meta(&"owner_slot")) == 2)
			c.queue_free()
	await _frames(2)
	if is_instance_valid(chest2):
		chest2.queue_free()
	Players.resurrect_all()
	_check("résurrection : J3 revient", not st3.spectating)


# --- Pilier : charge proportionnelle ---------------------------------------------------------
func _test_pillar_rate() -> void:
	var pillar := Pillar.new()
	add_child(pillar)
	pillar.setup(Pillar.Kind.BIG, 1)
	pillar.global_position = Vector2(-3000.0, -3000.0)
	var r := pillar.zone_radius()
	_nodes[0].global_position = pillar.global_position + Vector2(r * 0.3, 0.0)
	_nodes[1].global_position = pillar.global_position + Vector2(r * 3.0, 0.0)
	_nodes[2].global_position = pillar.global_position + Vector2(-r * 4.0, 0.0)
	_check("pilier : 1 joueur sur 3 -> 1/3", is_equal_approx(pillar.charge_rate(), 1.0 / 3.0), str(pillar.charge_rate()))
	_nodes[1].global_position = pillar.global_position + Vector2(0.0, r * 0.5)
	_check("pilier : 2 joueurs sur 3 -> 2/3", is_equal_approx(pillar.charge_rate(), 2.0 / 3.0), str(pillar.charge_rate()))
	_nodes[2].global_position = pillar.global_position + Vector2(-r * 0.5, 0.0)
	_check("pilier : tous dans la zone -> 1", is_equal_approx(pillar.charge_rate(), 1.0))
	for n in _nodes:
		n.global_position = pillar.global_position + Vector2(r * 5.0, 0.0)
	_check("pilier : personne dans la zone -> 0", pillar.charge_rate() == 0.0)
	_nodes[0].global_position = pillar.global_position
	_nodes[1].dead = true
	_nodes[2].dead = true
	pillar.player_in_zone = true # reflet tenu par Pillar.tick (zone lue sur les joueurs vivants)
	_check("pilier : seul joueur vivant dans la zone -> 1", pillar.charge_rate() == 1.0)
	pillar.player_in_zone = false
	_nodes[1].dead = false
	_nodes[2].dead = false
	# plancher 0,25 : 1 joueur sur 4 vivants -> 0,25
	var p4 := _fake(Vector2(pillar.global_position.x + r * 5.0, pillar.global_position.y))
	Players.register(p4)
	_check("pilier : 1 joueur sur 4 -> plancher 0,25", is_equal_approx(pillar.charge_rate(), 0.25), str(pillar.charge_rate()))
	Players.unregister(Players.id_of(p4))
	p4.remove_from_group(&"player")
	_nodes.erase(p4)
	p4.queue_free()
	pillar.queue_free()
	for i in 3:
		_nodes[i].global_position = Vector2(100.0 * i, 0.0)
	await _frames(1)


# --- Début d'étage : résurrection, anneau ----------------------------------------------------
func _test_stage_start() -> void:
	RunState.stage = 1
	Players.set_spectating(1)
	Players.set_spectating(3)
	_check("avant l'étage : 2 spectateurs", Players.alive_count() == 2)
	var res: Array = []
	var c_r := func(id: int) -> void: res.append(id)
	Events.player_resurrected.connect(c_r)
	_mgr.reset_run()
	_mgr.start_stage()
	Events.player_resurrected.disconnect(c_r)
	await _frames(1)
	_check("début d'étage : tous ressuscités", Players.alive_count() == 4 and res == [1, 3], str(res))
	var start := _mgr.map.to_global(_mgr.map.get_player_start())
	var seen: Array[Vector2] = []
	var ok := true
	for n in _nodes:
		ok = ok and n.global_position.distance_to(start) <= 4.0 * 64.0
		for s in seen:
			ok = ok and s.distance_to(n.global_position) > 8.0
		seen.append(n.global_position)
	_check("anneau de départ : quatre points distincts près du départ", ok, str(seen))


# --- Téléporteur : compte à rebours ----------------------------------------------------------
func _test_teleporter() -> void:
	var tp := _mgr.teleporter
	_check("téléporteur présent", tp != null)
	if tp == null:
		return
	tp.set_active(true)
	var used := [0]
	var started := [0.0]
	var c_u := func() -> void: used[0] += 1
	var c_s := func(s: float) -> void: started[0] = s
	tp.used.connect(c_u)
	tp.countdown_started.connect(c_s)
	_check("coop : le premier interagir lance le compte", tp.use() and is_equal_approx(tp.countdown_left, CoopRules.TELEPORT_COUNTDOWN_S) and started[0] == 15.0)
	_check("coop : pas de départ immédiat", used[0] == 0)
	_check("coop : deuxième interagir sans effet", not tp.use())
	tp.tick(14.0)
	_check("coop : 1 s restante, pas encore parti", used[0] == 0 and tp.countdown_left > 0.9 and tp.countdown_left < 1.1)
	tp.tick(1.5)
	_check("coop : départ à zéro", used[0] == 1 and tp.countdown_left == 0.0)
	# équipe entière à terre : le compte s'annule
	tp.use()
	for i in 4:
		Players.set_spectating(i)
	tp.tick(0.1)
	_check("équipe à terre : compte annulé", tp.countdown_left == 0.0 and used[0] == 1)
	Players.resurrect_all()
	tp.used.disconnect(c_u)
	tp.countdown_started.disconnect(c_s)
	tp.set_active(false)


# --- Coffres de boss et reliquaires ----------------------------------------------------------
func _test_boss_chests() -> void:
	var pillar := Pillar.new()
	_mgr.map.add_child(pillar)
	pillar.setup(Pillar.Kind.BIG, 1)
	pillar.position = _mgr.map.get_player_start() + Vector2(300.0, 0.0)
	var n_base := Balance.boss_chest_count(1 if Omens.boss_chest_enabled() else 0, pillar.deviated)
	var made := _mgr.spawn_boss_chests(pillar)
	_check("coffres de boss : un par joueur et par coffre de base", made.size() == n_base * 4, "%d vs %d" % [made.size(), n_base * 4])
	var count := {0: 0, 1: 0, 2: 0, 3: 0}
	for c in made:
		var s := int(c.reserved_slot)
		if count.has(s):
			count[s] += 1
	_check("coffres de boss : chacun réservé, %d par joueur" % n_base, count[0] == n_base and count[1] == n_base and count[2] == n_base and count[3] == n_base, str(count))
	var dmin := INF
	for i in made.size():
		for j in range(i + 1, made.size()):
			dmin = minf(dmin, made[i].position.distance_to(made[j].position))
	_check("coffres de boss : pas d'empilement", made.size() < 2 or dmin > 30.0, str(dmin))
	pillar.queue_free()
	for c in made:
		_mgr.chests.erase(c)
		c.queue_free()
	var relic := _mgr._make_relic(_mgr.map.get_player_start() + Vector2(600.0, 300.0))
	var relics: Array = _mgr.chests.filter(func(c) -> bool: return c.kind == &"guardian")
	_check("reliquaires : un par joueur", relic != null and relics.size() == 4, str(relics.size()))
	var slots := {}
	for c in relics:
		slots[int(c.reserved_slot)] = true
	_check("reliquaires : emplacements 0-3 distincts", slots.size() == 4)


# --- Débordement de coffres à 4 joueurs ------------------------------------------------------
func _test_overflow() -> void:
	var total_wanted := 0
	var total_placed := 0
	for seed_i in [3, 11, 29]:
		RunState.start_run(&"moyen", seed_i)
		_mgr.reset_run()
		for stage in range(1, 6):
			RunState.stage = stage
			RunState.begin_floor()
			_mgr.start_stage()
			await _frames(1)
			var rep: Dictionary = _mgr.chest_report
			var tag := "graine %d étage %d" % [seed_i, stage]
			_check("%s : rapport de coffres rempli" % tag, not rep.is_empty() and int(rep["n"]) == 4, str(rep))
			if rep.is_empty():
				continue
			var small := 0
			var large := 0
			var pos: Array[Vector2] = []
			for c in _mgr.chests:
				if c.kind == &"petit":
					small += 1
				elif c.kind == &"large":
					large += 1
				if c.kind == &"petit" or c.kind == &"large" or c.kind == &"legendaire":
					pos.append(c.position)
			var dmin := INF
			for i in pos.size():
				for j in range(i + 1, pos.size()):
					dmin = minf(dmin, pos[i].distance_to(pos[j]))
			var ok_ground := true
			for p in pos:
				ok_ground = ok_ground and _mgr.is_reachable_local(p)
			_check("%s : coffres posés = rapport (%d)" % [tag, int(rep["placed"])], pos.size() >= int(rep["placed"]) and int(rep["placed"]) >= int(rep["markers"]), str(rep))
			_check("%s : jamais empilés (%.0f px)" % [tag, dmin], pos.size() < 2 or dmin > 40.0)
			_check("%s : sur terrain praticable" % tag, ok_ground)
			_check("%s : repli posé >= 0 et <= demandé" % tag, int(rep["overflow_placed"]) >= 0 and int(rep["overflow_placed"]) <= int(rep["overflow_wanted"]))
			total_wanted += int(rep["wanted"])
			total_placed += int(rep["placed"])
			print("coffres posés %d/%d (cases C %d, repli %d/%d) %s" % [rep["placed"], rep["wanted"], rep["markers"], rep["overflow_placed"], rep["overflow_wanted"], tag])
	print("Total coop n=4 : %d posés sur %d voulus." % [total_placed, total_wanted])
	_check("débordement : au moins 90 %% des coffres voulus posés", total_placed >= int(0.9 * total_wanted), "%d/%d" % [total_placed, total_wanted])
