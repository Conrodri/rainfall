extends Node
## Tenue (docs/Design_Epreuves.md §3.5, lot E3) : cloche (PV = 0,5 x mini-boss, 3 états), annonce 2 s puis paquet de 4 à 10 u
## du côté annoncé avec `walk_target` = cloche, interception à <= 3 u, contact -> PV, 0 PV -> éteinte et note « fait »,
## 40 s -> mini-boss par le dernier côté, notes aux PV (>= 70 % parfait), plafond de vivants, coop x1,3/1,6/1,9, sauvegarde.
## godot --headless --path game res://tests/epreuve_hold_test.tscn  -> RESULT: OK

const STEP := 0.25

var _fails := 0
var _main: Node
var _events: Array = []
var _stage: StageManager
var _director: Director
var _player: Node2D
var _origin := Vector2.ZERO
var _sides := [Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
var _next_id := 200


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


func _run() -> void:
	Events.epreuve_started.connect(func(k: StringName) -> void: _events.append(["start", k]))
	Events.epreuve_finished.connect(func(k: StringName, g: StringName, s: float, gold: float) -> void: _events.append(["end", k, g, s, gold]))
	_check_constants()
	await _setup_stage()
	await _interaction_and_start()
	await _packets_and_lures()
	await _contact_and_dim()
	await _grades()
	await _coop()
	await _cap()
	await _save()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


# --- Constantes, PV et note
func _check_constants() -> void:
	print("-- constantes")
	var d := 2.0
	var mini := Balance.boss_hp(&"mini", d, 1)
	_check("PV de la cloche = 0,5 x mini-boss", is_equal_approx(Balance.hold_hp(d, 1, 1), 0.5 * mini))
	_check("PV x 1,3 / 1,6 / 1,9 à 2 / 3 / 4 joueurs", is_equal_approx(Balance.hold_hp(d, 1, 2) / Balance.hold_hp(d, 1, 1), 1.3) and is_equal_approx(Balance.hold_hp(d, 1, 3) / Balance.hold_hp(d, 1, 1), 1.6) and is_equal_approx(Balance.hold_hp(d, 1, 4) / Balance.hold_hp(d, 1, 1), 1.9))
	_check("PV croissants avec D, suivent boss_hp(mini) à l'étage", Balance.hold_hp(3.0, 1) > Balance.hold_hp(2.0, 1) and is_equal_approx(Balance.hold_hp(2.0, 3), 0.5 * Balance.boss_hp(&"mini", 2.0, 3)))
	_check("note aux PV : 1,0 / 0,7 parfait", Balance.epreuve_grade_hold(1.0) == &"parfait" and Balance.epreuve_grade_hold(0.7) == &"parfait")
	_check("note aux PV : 0,69 / 0,01 bien", Balance.epreuve_grade_hold(0.69) == &"bien" and Balance.epreuve_grade_hold(0.01) == &"bien")
	_check("note aux PV : 0 fait", Balance.epreuve_grade_hold(0.0) == &"fait")
	_check("5 paquets (t = 0, 8, 16, 24, 32)", EpreuveHold.packet_count() == 5)
	_check("cible de durée tenue = 40 s", is_equal_approx(float(Balance.EPREUVE_TARGET_S[&"tenue"]), 40.0) and is_equal_approx(Balance.HOLD_DURATION_S, 40.0))
	_check("annonce >= 0,8 s", Balance.HOLD_ANNOUNCE_S >= 0.8)


# --- Mise en place
func _new_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await _frames(3)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	add_child(_main)
	await _main.game_ready
	await _frames(3)
	_stage = _main.stage
	_director = _main.director
	_player = _main.player
	_player.call(&"grant_invulnerability", 1.0e6)
	_origin = _stage.map.get_player_start()


func _setup_stage() -> void:
	print("-- mise en place")
	await _new_main()
	_check("étage et director prêts", _stage != null and _director != null and _player != null)


func _new_hold(dx := 0.0, dy := -6.0) -> EpreuveHold:
	var h := EpreuveHold.make(_origin + Vector2(dx, dy) * Balance.UNIT_PX, _sides)
	h.biome = &"cite" # libellé d'invite lu dans data/epreuves.json
	_next_id += 1
	h.setup(Pillar.Kind.SMALL, _next_id, false)
	_stage.map.add_child(h)
	h.set_physics_process(false)
	await _frames(1)
	return h


func _far(h: EpreuveHold) -> void:
	_player.global_position = h.global_position + Vector2(60.0, 60.0) * Balance.UNIT_PX


func _tick(h: EpreuveHold, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001 and h.state == Pillar.STATE_ACTIVE:
		h.tick(STEP)
		t += STEP


func _clear_foes() -> void:
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e != null and e.active and not e.is_boss:
			e.take_damage(e.max_hp * 100.0)


func _kill_boss(h: EpreuveHold) -> void:
	var b := h.get(&"_boss") as Enemy
	if b != null and b.active:
		b.take_damage(b.max_hp * 100.0)
	await _frames(3)


func _packet_foes(h: EpreuveHold) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in h._lured:
		out.append(e)
	return out


# --- Interaction et lancement
func _interaction_and_start() -> void:
	print("-- interaction et lancement")
	var h := await _new_hold()
	_far(h)
	var u := Balance.UNIT_PX
	_check("prête : cloche au repos (off), sans PV", h.state == Pillar.STATE_READY and h.bell.state == EpreuveHoldBell.STATE_OFF and h.bell.hp == 0.0)
	_check("3 côtés unitaires", h.sides.size() == 3 and h.sides.all(func(s: Vector2) -> bool: return is_equal_approx(s.length(), 1.0)))
	_check("zone de monstres 12 u", is_equal_approx(h.zone_radius(), 12.0 * u))
	_check("libellé « Sonner la cloche »", h.interact_label() == "Sonner la cloche" and h.bell.interact_label() == "Sonner la cloche")
	_check("cloche hors de portée : pas d'invite", not h.bell.can_interact())
	_player.global_position = h.bell.global_position
	_check("cloche à portée : interactable ; le pilier ne l'est pas", h.bell.can_interact() and not h.can_interact())
	var st := h.bell.interact_state()
	_check("invite : visible, maintien 0", bool(st["visible"]) and is_zero_approx(float(st["hold_s"])))
	_events.clear()
	_check("interagir lance l'épreuve", h.bell.interact() and h.is_running() and _events.size() == 1 and _events[0][0] == "start" and _events[0][1] == &"tenue")
	_check("cloche sonne (ringing), PV pleins = 0,5 x mini-boss", h.bell.state == EpreuveHoldBell.STATE_RINGING and is_equal_approx(h.bell.max_hp, Balance.hold_hp(RunState.difficulty(), RunState.stage, 1)) and h.bell.hp == h.bell.max_hp and h.bell.max_hp > 0.0)
	_check("plus d'invite une fois lancée", not h.bell.can_interact() and not h.bell.interact())
	_check("ordre : 5 paquets, 3 côtés présents, jamais deux fois le même d'affilée", _order_ok(h))
	h.free()
	await _frames(1)


func _order_ok(h: EpreuveHold) -> bool:
	if h.order.size() != 5:
		return false
	for s in 3:
		if not h.order.has(s):
			return false
	for i in range(1, h.order.size()):
		if h.order[i] == h.order[i - 1]:
			return false
	return true


# --- Paquets et interception
func _packets_and_lures() -> void:
	print("-- paquets et interception")
	var h := await _new_hold()
	_far(h)
	var u := Balance.UNIT_PX
	h.activate()
	var side0: int = h.order[0]
	h.tick(STEP)
	_check("t = 0 : côté annoncé, aucun monstre encore", h._announcing and h.packets_spawned == 0 and _packet_foes(h).is_empty())
	_check("côté annoncé = ordre[0]", h.last_side.is_equal_approx(h.sides[side0]))
	_tick(h, 1.25) # t = 1,5
	_check("t = 1,5 s : toujours l'annonce", h._announcing and h.packets_spawned == 0)
	_tick(h, 0.75) # t = 2,25
	_check("t = 2,25 s : paquet de 4 apparu", h.packets_spawned == 1 and h.monsters_spawned == 4 and _packet_foes(h).size() == 4, "%d/%d" % [h.packets_spawned, h.monsters_spawned])
	var foes := _packet_foes(h)
	var expected := h.side_point(side0, Balance.HOLD_SPAWN_DIST_U)
	var near_ok := _director.nav == null or _director.nav.is_reachable(expected)
	var spawn_ok := true
	var target_ok := true
	for e in foes:
		if near_ok and e.global_position.distance_to(expected) > 2.5 * u:
			spawn_ok = false
		target_ok = target_ok and e.walk_target == h.bell
	_check("paquet à 10 u du côté annoncé (sol praticable)", spawn_ok, "attendu %s" % str(expected))
	_check("chaque monstre marche sur la cloche (walk_target)", target_ok)
	# interception : joueur à 2 u du monstre 0 (côté extérieur)
	var e0 := foes[0]
	var tangent := (h.side_point(side0, 1.0) - h.global_position).normalized().orthogonal()
	_player.global_position = e0.global_position - tangent * 2.0 * u
	h.tick(STEP)
	var consistent := true
	var freed := 0
	for e in foes:
		var close := _player.global_position.distance_to(e.global_position) <= Balance.HOLD_LURE_BREAK_U * u
		if close:
			freed += 1
		if close != (e.walk_target == null):
			consistent = false
	_check("monstre à <= 3 u du joueur : walk_target retiré", e0.walk_target == null and freed >= 1)
	_check("seuls les monstres à <= 3 u sont libérés", consistent)
	_check("compteur d'interceptions", h.intercepted == freed, "%d vs %d" % [h.intercepted, freed])
	_far(h)
	_clear_foes()
	# les paquets suivent le calendrier : t = 8 -> annonce, t = 10 -> paquet 2
	_tick(h, 5.0) # t = 7,5 + ...
	var before := h.packets_spawned
	_tick(h, 3.0) # ~ t = 10,5
	_check("paquet 2 à t = 10 s", h.packets_spawned == before + 1 and h.packets_spawned == 2, "%d" % h.packets_spawned)
	_clear_foes()
	h.finish_now(&"bien")
	await _kill_boss(h)
	h.free()
	await _frames(1)


# --- Contact, extinction, mini-boss
func _contact_and_dim() -> void:
	print("-- contact, extinction et mini-boss")
	var h := await _new_hold()
	_far(h)
	var u := Balance.UNIT_PX
	var gold0: float = RunState.gold
	h.activate()
	var max_hp := h.bell.max_hp
	# monstres à portée de contact : la cloche perd des PV (monstres loin : rien)
	_check("rien au contact : PV intacts", h._contact_dps() == 0.0)
	var foes: Array[Enemy] = []
	for i in 6:
		var e := _director.spawn_enemy(1, h.bell.global_position + Vector2(10.0 + 3.0 * i, 0.0))
		if e != null:
			foes.append(e)
	_check("monstres au contact créés", foes.size() >= 4)
	var dps := h._contact_dps()
	_check("dégâts de contact > 0 (%.1f/s)" % dps, dps > 0.0)
	_tick(h, 1.0)
	_check("la cloche perd des PV au contact", h.bell.hp < max_hp and h.hits > 0)
	_check("cloche encore allumée", h.bell.state == EpreuveHoldBell.STATE_RINGING and h.is_running())
	for e in foes:
		e.take_damage(e.max_hp * 100.0)
	await _frames(2)
	# 0 PV : éteinte, l'épreuve continue
	h.bell.damage(h.bell.hp + 1.0)
	_check("0 PV : cloche éteinte (dim), PV à 0", h.bell.state == EpreuveHoldBell.STATE_DIM and h.bell.hp == 0.0 and h.is_bell_dim())
	_check("0 PV : l'épreuve continue, « parfait » perdu", h.is_running() and not h.clean)
	_tick(h, 10.0)
	_check("éteinte : plus de dégâts, épreuve toujours en cours", h.is_running() and h.bell.hp == 0.0 and h.packets_spawned >= 2)
	_clear_foes()
	# fin à 40 s : mini-boss par le dernier côté annoncé
	_events.clear()
	var guard := 0
	while h.is_running() and guard < 400:
		h.tick(STEP)
		guard += 1
	_check("40 s : épreuve résolue", h.resolved and absf(h.elapsed - 40.0) <= STEP + 0.01, "%.2f" % h.elapsed)
	_check("5 paquets au total", h.packets_spawned == 5, str(h.packets_spawned))
	_check("note « fait » (cloche éteinte)", h.grade == &"fait", String(h.grade))
	var price := Balance.station_price_p(RunState.floor_start_d, RunState.stage)
	_check("or « fait » = 0,5 P", is_equal_approx(h.gold_paid, 0.5 * price))
	_check("évènement de fin (tenue, fait)", _events.size() == 1 and _events[0][0] == "end" and _events[0][1] == &"tenue" and _events[0][2] == &"fait")
	_check("or versé au joueur", RunState.gold > gold0)
	var boss := h.get(&"_boss") as Enemy
	_check("mini-boss invoqué", boss != null and boss.active)
	if boss != null:
		var exp_pos := h.side_point(h.order[h.order.size() - 1], Balance.HOLD_SPAWN_DIST_U)
		var reach := _director.nav == null or _director.nav.is_reachable(exp_pos)
		_check("mini-boss par le dernier côté annoncé (10 u)", not reach or boss.global_position.distance_to(exp_pos) <= 2.0 * u, "%s vs %s" % [str(boss.global_position), str(exp_pos)])
	_check("cloche : plus d'invite après la fin, restée éteinte", h.bell.state == EpreuveHoldBell.STATE_DIM and not h.bell.can_interact())
	_check("zone du mini-boss", true)
	await _kill_boss(h)
	_check("mini-boss mort -> épreuve terminée", h.state == Pillar.STATE_DONE)
	h.free()
	await _frames(1)


# --- Notes aux PV et durée fixe
func _grades() -> void:
	print("-- notes")
	var price := Balance.station_price_p(RunState.floor_start_d, RunState.stage)
	for case in [[1.0, &"parfait", 1.5], [0.7, &"parfait", 1.5], [0.69, &"bien", 1.0], [0.05, &"bien", 1.0]]:
		var h := await _new_hold()
		_far(h)
		h.activate()
		h.bell.hp = h.bell.max_hp * float(case[0])
		_tick(h, 45.0)
		_check("PV %d %% -> %s (%.1f P)" % [roundi(float(case[0]) * 100.0), case[1], case[2]], h.resolved and h.grade == case[1] and is_equal_approx(h.gold_paid, float(case[2]) * price), String(h.grade))
		_check("durée fixe 40 s (note indépendante du temps)", absf(h.elapsed - 40.0) <= STEP + 0.01)
		_clear_foes()
		await _kill_boss(h)
		h.free()
		await _frames(1)
	# terminer plus tôt (mode test) : note imposée, mini-boss quand même
	var h2 := await _new_hold()
	_far(h2)
	h2.activate()
	_tick(h2, 5.0)
	h2.finish_now(&"bien")
	_check("finish_now : note imposée, mini-boss invoqué", h2.resolved and h2.grade == &"bien" and h2.get(&"_boss") != null)
	_check("progression 0..1", h2.progress() >= 0.0 and h2.progress() <= 1.0)
	_clear_foes()
	await _kill_boss(h2)
	h2.free()
	await _frames(1)


# --- Coop : PV de la cloche, paquets inchangés
func _coop() -> void:
	print("-- coop")
	for n in [1, 2, 3, 4]:
		var h := await _new_hold()
		_far(h)
		h.party_override = n
		h.activate()
		var solo := Balance.hold_hp(RunState.difficulty(), RunState.stage, 1) # D dérive avec le temps : tolérance
		var mult := h.bell.max_hp / solo
		_check("%d joueur(s) : PV x %.1f" % [n, 1.0 + 0.3 * (n - 1)], absf(mult - (1.0 + 0.3 * (n - 1))) <= 0.02, "x%.3f" % mult)
		if n == 4:
			_tick(h, 2.5)
			_check("4 joueurs : paquet inchangé (4 monstres)", h.monsters_spawned == 4, str(h.monsters_spawned))
		_clear_foes()
		h.finish_now(&"fait")
		await _kill_boss(h)
		h.free()
		await _frames(1)


# --- Plafond de vivants
func _cap() -> void:
	print("-- plafond de vivants")
	var h := await _new_hold()
	_far(h)
	h.activate()
	h.order = [0, 1, 0, 1, 2]
	var spawned: Array[Enemy] = []
	while true:
		var e := _director.spawn_enemy(1, h.global_position + Vector2(25.0 * Balance.UNIT_PX, 0.0))
		if e == null:
			break
		spawned.append(e)
	_check("pool rempli", spawned.size() > 100)
	var made := h._spawn_packet(0)
	_check("pool vide : paquet vide, sans erreur", made == 0 and h.packets_spawned == 1)
	for i in 2:
		spawned[i].take_damage(spawned[i].max_hp * 100.0)
	await _frames(2)
	made = h._spawn_packet(1)
	_check("2 places libres : paquet réduit à 2 (jamais plus)", made == 2, str(made))
	_clear_foes()
	await _frames(2)
	made = h._spawn_packet(1)
	_check("pool libre : paquet complet de 4", made == 4, str(made))
	_clear_foes()
	h.finish_now(&"fait")
	await _kill_boss(h)
	h.free()
	await _frames(1)


# --- Sauvegarde
func _save() -> void:
	print("-- sauvegarde")
	var h := await _new_hold()
	_far(h)
	h.activate()
	_tick(h, 20.0)
	h.bell.damage(h.bell.max_hp * 0.35)
	var d: Dictionary = JSON.parse_string(JSON.stringify(h.to_dict())) as Dictionary
	var e: Dictionary = d["epreuve"]
	_check("sauvegarde : champs t / hp / order / next_i / dim / last_side", e.has("t") and e.has("hp") and e.has("order") and e.has("next_i") and e.has("dim") and e.has("last_side") and String(e["verb"]) == "tenue")
	var h2 := await _new_hold()
	h2.from_dict(d)
	_check("reprise : en cours, même temps", h2.state == Pillar.STATE_ACTIVE and h2.is_running() and is_equal_approx(h2.elapsed, h.elapsed))
	_check("reprise : PV, état de la cloche", is_equal_approx(h2.bell.hp, h.bell.hp) and is_equal_approx(h2.bell.max_hp, h.bell.max_hp) and h2.bell.state == EpreuveHoldBell.STATE_RINGING)
	_check("reprise : ordre, paquet suivant, dernier côté", h2.order == h.order and h2.next_i == h.next_i and h2.last_side.is_equal_approx(h.last_side))
	_far(h2)
	var guard := 0
	while h2.is_running() and guard < 400:
		h2.tick(STEP)
		guard += 1
	_check("reprise : l'épreuve va au bout (bien, mini-boss)", h2.resolved and h2.grade == &"bien" and h2.get(&"_boss") != null, String(h2.grade))
	# éteinte puis sauvegardée
	var h3 := await _new_hold()
	_far(h3)
	h3.activate()
	h3.bell.damage(h3.bell.hp + 1.0)
	var d3: Dictionary = JSON.parse_string(JSON.stringify(h3.to_dict())) as Dictionary
	var h4 := await _new_hold()
	h4.from_dict(d3)
	_check("reprise : cloche éteinte restaurée", h4.is_bell_dim() and h4.bell.hp == 0.0 and not h4.clean)
	# résolue (mini-boss à relancer) : le côté d'arrivée est conservé
	var d2: Dictionary = JSON.parse_string(JSON.stringify(h2.to_dict())) as Dictionary
	var h5 := await _new_hold()
	h5.from_dict(d2)
	_check("reprise après résolution : dernier côté conservé", h5.last_side.is_equal_approx(h2.last_side))
	_clear_foes()
	for x in [h, h2, h3, h4, h5]:
		await _kill_boss(x)
		x.free()
	await _frames(1)
