extends Node
## Boss d'étage 1 façon raid : l'Idole noyée (DrownedIdolBrain, docs/Design_Boss_Raid.md §2.1).
## godot --headless --path game res://tests/drowned_idol_boss_test.tscn  -> RESULT: OK
## Cerveau branché à la main sur un Enemy de test (le crochet d'instanciation dans enemy.gd est hors lot) ; temps
## piloté : un tick du cerveau par image physique. Vérifie : contrats Balance ; phase 1 (paume, carillon : couloirs
## sûrs et anneau qui touche, chapelet : dernier cercle sur le joueur) à la frame d'impact ; murets-abris contre les
## anneaux ; digues (télégraphe, expiration) ; noria (verrouillage, disque, pale) ; bouclier de la transition 2 (3
## cloches, un seul sort lent, rupture, fenêtre +30 %) et de la transition 3 (4 cloches), P3 ancrée + 20 % +
## anneau continu ; garde-fou 25 s sans fenêtre, enrage gelé, aucun blocage ; pénalité plafonnée.

const DT := 1.0 / 60.0
const U := 64.0
const ARENA := 2400.0
const ID := &"drowned_idol"

var _fails := 0
var _player
var _director: Director
var _map: Node2D
var _boss: Enemy
var _brain: DrownedIdolBrain
var _hits: Array[float] = []
var _ev := {}


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok  " + label)
	else:
		_fails += 1
		print("  ÉCHEC  " + label + ("  (" + detail + ")" if detail != "" else ""))


func _wall(parent: Node, center: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	b.add_child(cs)
	b.position = center
	parent.add_child(b)


func _on(sig: String, a = null, b = null) -> void:
	if not _ev.has(sig):
		_ev[sig] = []
	(_ev[sig] as Array).append([a, b])


func _count(sig: String) -> int:
	return (_ev.get(sig, []) as Array).size()


func _run() -> void:
	RunState.level = 1
	Engine.physics_ticks_per_second = 240 # delta = time_scale / 240 = 1/60 : nœuds de la boîte et cerveau restent en phase
	Engine.time_scale = 4.0
	_map = Node2D.new()
	_map.name = &"IdolMap"
	get_tree().root.add_child(_map)
	_wall(_map, Vector2(0, -ARENA), Vector2(ARENA * 2 + 128, 128))
	_wall(_map, Vector2(0, ARENA), Vector2(ARENA * 2 + 128, 128))
	_wall(_map, Vector2(-ARENA, 0), Vector2(128, ARENA * 2 + 128))
	_wall(_map, Vector2(ARENA, 0), Vector2(128, ARENA * 2 + 128))
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	_player.global_position = Vector2(900, 0)
	await get_tree().process_frame
	_director.bind_map(_map)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_director.set_physics_process(false)
	_player.set_physics_process(false)
	Events.player_damaged.connect(func(a, _s): _hits.append(a))
	Events.raid_mechanic_failed.connect(func(_b, k): _on("failed", k))
	Events.boss_shield_changed.connect(func(_b, a, k): _on("shield", a, k))

	_contracts()
	await _new_boss()
	await _phase1_palm()
	await _phase1_carillon()
	await _phase1_chaplet()
	await _shelter()
	await _dikes()
	await _noria()
	await _shield_one()
	await _phase3_and_shield_two()
	await _backstop()
	await _penalty_cap()
	_cleanup()

	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


# --- Outils ---------------------------------------------------------------------------------

func _frame() -> void:
	await get_tree().physics_frame
	_player._invuln = 0.0 # chaque coup compte
	if _boss == null or not is_instance_valid(_boss):
		return
	_boss.fight_time += DT
	_boss.visual.boss_tick(DT)
	var pp: Vector2 = _player.global_position
	var to := pp - _boss.position
	var dir := to.normalized() if to.length_squared() > 0.0001 else Vector2.RIGHT
	_brain.tick(DT, _player, pp, dir, to.length(), dir)


func _adv(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		await _frame()


func _until(cond: Callable, max_s: float) -> bool:
	for i in int(round(max_s / DT)):
		if cond.call():
			return true
		await _frame()
	return cond.call()


func _new_boss() -> void:
	if _brain != null:
		_brain.clear()
	if _boss == null or not is_instance_valid(_boss) or not _boss.active:
		_boss = _director.spawn_boss(&"etage", Vector2.ZERO) as Enemy
	if _boss.brain != null and _boss.brain != _brain:
		_boss.brain.clear()
	_boss._boss_sprite_id = ID
	_boss.position = Vector2.ZERO
	_boss.hp = _boss.max_hp
	_boss.fight_time = 0.0
	_boss.damage = 10.0
	_brain = DrownedIdolBrain.new(_boss)
	_boss.brain = _brain
	_brain.ring_jitter_scale = 0.0 # anneaux du Carillon à leurs rayons nominaux (le hasard est testé à part)
	_brain._spell_cd = 999.0
	_brain._attack_cd = 999.0
	_hits.clear()
	_ev.clear()
	_player.dead = false
	_player.max_hp = 1e6
	_player.hp = 1e6
	_player.shield = 0.0
	await get_tree().physics_frame


func _place(p: Vector2) -> void:
	_player.global_position = p
	_hits.clear()


func _events(kind: StringName) -> Array:
	return _brain.events.filter(func(ev): return ev["kind"] == kind)


func _lag_ok(kind: StringName) -> bool:
	var evs := _events(kind)
	if evs.is_empty():
		return false
	for ev in evs:
		var lag := float(ev["lag"])
		if lag < -0.001 or lag > 0.05:
			print("    %s : décalage %.3f s" % [kind, lag])
			return false
	return true


# --- 1. Contrats ----------------------------------------------------------------------------

func _contracts() -> void:
	print("Contrats")
	for k in [&"palm", &"carillon", &"chaplet", &"bell_drop", &"dike", &"noria", &"ring_p3"]:
		_check("coef %s" % k, Balance.boss_attack_coef(ID, k) > 0.0)
	_check("seuils 70 / 35 %", Balance.boss_phase(&"etage", ID, 0.71) == 1 and Balance.boss_phase(&"etage", ID, 0.70) == 2
		and Balance.boss_phase(&"etage", ID, 0.36) == 2 and Balance.boss_phase(&"etage", ID, 0.35) == 3)
	_check("P3 : +20 % de dégâts reçus", is_equal_approx(Balance.boss_damage_taken_mult(ID, 3), 1.2) and Balance.boss_damage_taken_mult(ID, 2) == 1.0)
	_check("PV x 0,7 (audit runs 31/10/2026, était 0,9), 2 boucliers", is_equal_approx(Balance.boss_hp_mult(ID), 0.7) and Balance.boss_shield_count(ID) == 2)
	_check("garde-fou 25 s (défaut) ; Idole v2 : 45 s, impulsion toutes les 8 s, soin 10 %", Balance.BOSS_SHIELD_BACKSTOP_S == 25.0
		and float(Balance.boss_pressure(ID, "shield_backstop_s")) == 45.0 and float(Balance.boss_pressure(ID, "shield_stall_every_s")) == 8.0
		and Balance.RAID_STALL_HEAL_FRAC == 0.10)
	_check("v2 : coefs de dégâts inchangés", Balance.boss_attack_coef(ID, &"palm") == 1.0 and Balance.boss_attack_coef(ID, &"carillon") == 1.2
		and Balance.boss_attack_coef(ID, &"chaplet") == 1.3 and Balance.boss_attack_coef(ID, &"noria") == 0.5 and Balance.boss_attack_coef(ID, &"ring_p3") == 1.0)


# --- 2. Phase 1 ---------------------------------------------------------------------------

func _phase1_palm() -> void:
	print("Phase 1 : paume")
	_check("IA branchée, interface complète", _boss.brain is DrownedIdolBrain and _brain.has_method(&"is_invulnerable")
		and _brain.has_method(&"damage_taken_mult") and _brain.has_method(&"boss_state_tag") and _brain.has_method(&"is_phase_transition")
		and _brain.pace is BossPace)
	_place(Vector2(2.0 * U, 0.0))
	_brain._attack_cd = 0.0
	await _adv(1.5)
	_check("paume : touche à la frame d'impact", _events(&"palm").size() == 1 and _events(&"palm_hit").size() == 1 and _lag_ok(&"palm"),
		str(_brain.events.size()))
	_check("paume : un seul coup", _hits.size() == 1)
	_check("tag de barre vide hors bouclier", _brain.boss_state_tag().is_empty() and not _brain.is_invulnerable() and not _brain.is_phase_transition())


func _phase1_carillon() -> void:
	print("Phase 1 : carillon")
	await _new_boss()
	# v2 : 4 anneaux de 1,0 u d'épaisseur (bandes 1,5-2,5 / 3,5-4,5 / 5,5-6,5 / 7,5-8,5 u) ; couloir sûr à 3,0 u
	_place(Vector2(3.0 * U, 0.0))
	_brain.debug_cast(DrownedIdolBrain.Spell.CARILLON, _player.global_position)
	_check("carillon : télégraphe >= 1,0 s", _brain._dur >= 1.0, str(_brain._dur))
	await _adv(4.0)
	var rings := _events(&"ring")
	_check("carillon : 4 anneaux", rings.size() == 4, str(rings.size()))
	_check("carillon : couloir sûr", _hits.is_empty() and _events(&"ring_hit").is_empty(), str(_hits))
	_check("carillon : 0,35 s entre deux anneaux", rings.size() == 4 and absf(float(rings[1]["at"]) - float(rings[0]["at"]) - 0.35) < 0.04
		and absf(float(rings[2]["at"]) - float(rings[1]["at"]) - 0.35) < 0.04)
	_check("carillon : lag d'impact", _lag_ok(&"carillon"))
	_check("carillon : rayons 2,5 / 4,5 / 6,5 / 8,5 u", is_equal_approx(float(rings[0]["r"]), 2.5 * U) and is_equal_approx(float(rings[3]["r"]), 8.5 * U))
	# dans la bande de l'anneau de 4,5 u (3,5 -> 4,5 u)
	_brain.events.clear()
	_place(Vector2(4.0 * U, 0.0))
	_brain.debug_cast(DrownedIdolBrain.Spell.CARILLON, _player.global_position)
	await _adv(4.0)
	_check("carillon : l'anneau touche dans sa bande", _events(&"ring_hit").size() == 1 and _hits.size() == 1, str(_hits))
	# au pied du boss (< 2,2 u) : sûr
	_brain.events.clear()
	_place(Vector2(1.0 * U, 0.0))
	_brain.debug_cast(DrownedIdolBrain.Spell.CARILLON, _player.global_position)
	await _adv(4.0)
	_check("carillon : sûr au pied du boss", _hits.is_empty())
	# décalage aléatoire (couloir imprévisible) : deux Carillons de la P2 ne tombent pas aux mêmes rayons
	await _new_boss()
	_brain.ring_jitter_scale = 1.0
	_brain.phase = 2
	_place(Vector2(-2000.0, -2000.0))
	var firsts: Array[float] = []
	for i in 6:
		_brain.events.clear()
		_brain.debug_cast(DrownedIdolBrain.Spell.CARILLON, _player.global_position)
		await _adv(4.5)
		var rs := _events(&"ring")
		if rs.size() == 5:
			firsts.append(minf(float(rs[0]["r"]), float(rs[4]["r"])))
	_check("carillon P2 : 5 anneaux, rayons décalés d'un lancer à l'autre", firsts.size() >= 5 and (firsts.max() - firsts.min()) > 0.3 * U, str(firsts))


func _phase1_chaplet() -> void:
	print("Phase 1 : chapelet")
	await _new_boss()
	_place(Vector2(6.0 * U, 0.0))
	_brain.debug_cast(DrownedIdolBrain.Spell.CHAPLET, _player.global_position)
	var cs: Array = _brain._circles
	_check("chapelet v2 : 7 cercles en file + 1 sur la position du joueur, le dernier sur lui", cs.size() == 8 and (cs[7]["pos"] as Vector2).distance_to(_player.global_position) < 2.0)
	var disjoint := true
	for i in range(1, cs.size() - 1):
		if (cs[i]["pos"] as Vector2).distance_to(cs[i - 1]["pos"]) < 0.7 * U:
			disjoint = false
	_check("chapelet : cercles du boss vers le joueur", disjoint)
	await _adv(3.5)
	_check("chapelet : le cercle sur le joueur touche (cercles voisins qui se chevauchent : 4 coups au plus)",
		_events(&"chaplet_hit").size() >= 1 and _hits.size() <= 4, str(_hits))
	_check("chapelet : lag d'impact", _lag_ok(&"chaplet"))
	_check("chapelet : plus aucun cercle", _brain._circles.is_empty())
	# le joueur qui bouge à temps n'est pas touché
	await _new_boss()
	_place(Vector2(6.0 * U, 0.0))
	_brain.debug_cast(DrownedIdolBrain.Spell.CHAPLET, _player.global_position)
	await _adv(0.5)
	_place(Vector2(6.0 * U, 6.0 * U))
	await _adv(3.0)
	_check("chapelet : esquivé en bougeant", _hits.is_empty(), str(_hits))


# --- 3. Phase 2 : abris, digues, noria -------------------------------------------------------

func _shelter() -> void:
	print("Phase 2 : le muret-abri arrête les anneaux")
	await _new_boss()
	_brain.phase = 2
	# anneau de 7,4 u : bande 6,4 -> 7,4 ; joueur à 6,9 u
	_place(Vector2(6.9 * U, 0.0))
	_brain.debug_add_dike(Vector2(4.0 * U, 0.0), false) # muret vertical entre le boss et le joueur
	_check("digue posée", _brain.dike_count() == 1)
	_check("ombre derrière le muret, pas à côté", _brain.sheltered(Vector2.ZERO, Vector2(6.9 * U, 0.0))
		and not _brain.sheltered(Vector2.ZERO, Vector2(6.9 * U, 8.0 * U)))
	_brain.debug_cast(DrownedIdolBrain.Spell.CARILLON, _player.global_position)
	await _adv(4.5)
	_check("carillon à 5 anneaux en P2", _events(&"ring").size() == 5, str(_events(&"ring").size()))
	_check("anneaux arrêtés par le muret", _brain.rings_blocked >= 1 and _hits.is_empty() and _events(&"ring_hit").is_empty(),
		"bloqués %d, coups %s" % [_brain.rings_blocked, str(_hits)])
	# sans le muret le même anneau touche
	_brain._dikes.clear()
	_place(Vector2(6.9 * U, 0.0))
	_brain.debug_cast(DrownedIdolBrain.Spell.CARILLON, _player.global_position)
	await _adv(4.5)
	_check("sans muret l'anneau touche", _events(&"ring_hit").size() >= 1, str(_hits))


func _dikes() -> void:
	print("Phase 2 : digues")
	await _new_boss()
	_brain.phase = 2
	_place(Vector2(6.0 * U, 0.0))
	_brain.debug_cast(DrownedIdolBrain.Spell.DIKES, _player.global_position)
	var plan: Array = _brain._dike_plan
	_check("digues télégraphées : 2 murets 1 x 4 u", plan.size() == 2 and _brain._dur >= 0.65)
	_check("muret de 1 x 4 u", plan.size() == 2 and absf(maxf((plan[0]["rect"] as Rect2).size.x, (plan[0]["rect"] as Rect2).size.y) - 4.0 * U) < 0.5
		and absf(minf((plan[0]["rect"] as Rect2).size.x, (plan[0]["rect"] as Rect2).size.y) - 1.0 * U) < 0.5)
	# un joueur sous le premier muret au moment où il jaillit prend le coup (coef 0,6)
	if plan.size() == 2:
		_place((plan[0]["rect"] as Rect2).get_center())
	await _adv(2.0)
	_check("digues levées", _brain.dike_count() == 2 and _events(&"dikes").size() == 1 and _lag_ok(&"dikes"))
	_check("muret qui jaillit sous le joueur : coup", _events(&"dike_hit").size() == 1 and _hits.size() == 1)
	var nav_ok := _boss.nav == null or _boss.nav.obstacle_count() >= 2
	_check("obstacles de navigation posés", nav_ok)
	await _adv(DrownedIdolBrain.DIKE_LIFE_S + 1.5)
	_check("digues expirées après %.0f s" % DrownedIdolBrain.DIKE_LIFE_S, _brain.dike_count() == 0)
	if _boss.nav != null:
		_check("obstacles de navigation retirés", _boss.nav.obstacle_count() == 0, str(_boss.nav.obstacle_count()))


func _noria() -> void:
	print("Phase 2 : noria")
	await _new_boss()
	_brain.phase = 2
	_place(Vector2(5.0 * U, 2.0 * U))
	_brain.debug_cast(DrownedIdolBrain.Spell.NORIA, _player.global_position)
	_check("noria v2 : 2 fixations en P2, verrouillage >= 0,7 s", _brain._noria.size() == 2 and _brain._dur >= 0.7
		and (_brain._noria[0]["mark"] as FixateMark).lock_s >= 0.7)
	var mark := _brain._noria[0]["mark"] as FixateMark
	var pt := mark.point
	await _until(func(): return mark.is_locked, 3.0)
	_check("noria : point figé au verrouillage", mark.is_locked and mark.point.distance_to(pt) < 0.5)
	await _adv(2.6)
	_check("noria : le joueur resté sur place est touché", _events(&"noria_hit").size() >= 1 and _lag_ok(&"noria"), str(_hits.size()))
	_check("noria : plafond de coups (4 ticks max par roue)", _hits.size() <= 10, str(_hits.size()))
	# parti avant le verrouillage : rien
	await _new_boss()
	_brain.phase = 2
	_place(Vector2(5.0 * U, 2.0 * U))
	_brain.debug_cast(DrownedIdolBrain.Spell.NORIA, _player.global_position)
	await _adv(0.4)
	_place(Vector2(5.0 * U, 22.0 * U))
	await _adv(4.0)
	_check("noria : on ne reste pas où l'on était", _hits.is_empty(), str(_hits))
	# la pale : joueur sur son bras au 1er tick (angle a0 + balayage de 270° en 1,5 s, 1er tick à 0,4 s)
	await _new_boss()
	_brain.phase = 2
	_place(Vector2(5.0 * U, 2.0 * U))
	_brain.debug_cast(DrownedIdolBrain.Spell.NORIA, _player.global_position)
	var ent: Dictionary = _brain._noria[0]
	var m2 := ent["mark"] as FixateMark
	await _until(func(): return m2.is_locked, 3.0)
	var sweep := float(Balance.boss_pressure(ID, "noria_sweep_rad")) * float(Balance.boss_pressure(ID, "noria_tick_s")) / float(Balance.boss_pressure(ID, "noria_turn_s"))
	_place(m2.point + Vector2.from_angle(float(ent["a0"]) + sweep) * 5.0 * U)
	await _adv(0.7)
	_check("noria : la pale touche à 5 u du centre", _events(&"noria_hit").size() >= 1, str(_hits.size()))
	await _adv(3.0)


# --- 4. Boucliers --------------------------------------------------------------------------------

func _orbs() -> Array:
	return _brain.shield.objects.filter(func(o): return is_instance_valid(o) and o is RaidOrb)


func _collect(orbs: Array) -> void:
	for o in orbs:
		if is_instance_valid(o):
			_place((o as RaidOrb).global_position)
			await _adv(0.3)


func _shield_one() -> void:
	print("Transition 2 : 3 cloches")
	await _new_boss()
	_place(Vector2(3.0 * U, 0.0))
	var hp0 := _boss.max_hp * 0.69
	_boss.hp = hp0
	await _adv(0.2)
	_check("phase 2, bouclier levé (1/2)", _brain.phase == 2 and _brain.shield.armed_count == 1 and _brain.is_invulnerable())
	_check("transition : boss figé", _brain.is_phase_transition() and _brain.owns_motion())
	_boss.take_damage(500.0)
	_check("aucun dégât sous bouclier", _boss.hp == hp0)
	_check("tag « CLOCHES 0/3 » kind shield", String(_brain.boss_state_tag().get("text", "")) == "CLOCHES 0/3"
		and _brain.boss_state_tag().get("kind") == &"shield", str(_brain.boss_state_tag()))
	await _until(func(): return _brain.shield.state == BossShield.State.ACTIVE, 4.0)
	var orbs := _orbs()
	_check("3 cloches jetées", orbs.size() == 3)
	_check("pas de transition une fois la mise en place finie", not _brain.is_phase_transition())
	# un seul sort lent (chapelet) toutes les 4 s, aucun autre sort
	_brain._attack_cd = 0.0
	_brain._spell_cd = 0.0
	await _adv(Balance.BOSS_SHIELD_SLOW_SPELL_S + 2.5)
	_check("sous bouclier : chapelet seulement", _events(&"chaplet").size() >= 1 and _events(&"palm").is_empty()
		and _events(&"carillon").is_empty() and _events(&"dikes").is_empty() and _events(&"noria").is_empty(),
		str(_brain.events.map(func(ev): return ev["kind"])))
	_check("sous bouclier : encore invulnérable", _brain.is_invulnerable())
	await _collect(orbs)
	_check("3 cloches ramassées : rupture méritée", _brain.shield.state == BossShield.State.BREAKING or _brain.shield.is_exposed(),
		str(_brain.shield.state))
	_check("cloches rendues (3 progrès)", _events(&"bell").size() == 3)
	await _until(func(): return _brain.shield.is_exposed(), 1.0)
	_check("fenêtre sonnée +30 %", _brain.shield.is_exposed() and is_equal_approx(_brain.damage_taken_mult(), 1.3)
		and _brain.boss_state_tag().get("kind") == &"exposed")
	var h1 := _boss.hp
	_boss.take_damage(100.0)
	_check("dégâts x 1,3 pendant la fenêtre", is_equal_approx(h1 - _boss.hp, 130.0), str(h1 - _boss.hp))
	await _until(func(): return _brain.shield.state == BossShield.State.IDLE, 4.0)
	_check("retour à la normale", _brain.shield.state == BossShield.State.IDLE and not _brain.is_invulnerable()
		and is_equal_approx(_brain.damage_taken_mult(), 1.0))
	_brain.events.clear()
	_brain._attack_cd = 0.0
	_brain._spell_cd = 0.0
	await _adv(3.0)
	_check("le boss rattaque après le bouclier", _brain.events.size() > 0)


func _phase3_and_shield_two() -> void:
	print("Transition 3 : 4 cloches, P3 ancrée")
	_boss.hp = _boss.max_hp * 0.34
	_place(Vector2(3.0 * U, 0.0))
	await _adv(0.2)
	_check("phase 3, 2e bouclier", _brain.phase == 3 and _brain.shield.armed_count == 2 and _brain.is_invulnerable())
	await _until(func(): return _brain.shield.state == BossShield.State.ACTIVE, 4.0)
	var orbs := _orbs()
	_check("4 cloches jetées", orbs.size() == 4)
	await _collect(orbs)
	await _until(func(): return _brain.shield.state == BossShield.State.IDLE, 5.0)
	_check("4 cloches : rupture, retour à la normale", not _brain.is_invulnerable() and _brain.shield.state == BossShield.State.IDLE
		and _events(&"bell").size() == 4)
	# P3 : ancrée, +20 %, anneau continu
	_check("P3 : dégâts reçus x 1,2", is_equal_approx(_brain.damage_taken_mult(), 1.2))
	_brain.events.clear()
	_boss.hp = _boss.max_hp * 0.3
	var p0 := _boss.position
	_place(Vector2(6.0 * U, 0.0))
	_brain._spell_cd = 999.0
	_brain._attack_cd = 999.0
	var vel := Vector2.ZERO
	for i in int(round(10.0 / DT)):
		await _frame()
		vel = _brain.tick(0.0, _player, _player.global_position, Vector2.RIGHT, 6.0 * U, Vector2.RIGHT)
	_check("P3 : ancrée (immobile)", _brain.anchored and vel == Vector2.ZERO and _boss.position.distance_to(p0) < 1.0)
	_check("P3 v2 : un anneau toutes les 1,1 s", _events(&"ring_p3").size() >= 7, str(_events(&"ring_p3").size()))
	_check("P3 : l'anneau continu touche en terrain nu", _brain.ring_hits >= 1, str(_brain.ring_hits))
	# P3 : digues x3, noria x2, spirale x6
	_place(Vector2(6.0 * U, 0.0))
	_brain.debug_cast(DrownedIdolBrain.Spell.DIKES, _player.global_position)
	_check("P3 : 3 digues", _brain._dike_plan.size() == 3)
	await _adv(2.0)
	_check("P3 : 3 digues levées", _brain.dike_count() == 3)
	_place(Vector2(6.0 * U, 6.0 * U))
	_brain.debug_cast(DrownedIdolBrain.Spell.NORIA, _player.global_position)
	_check("P3 v2 : 3 roues", _brain._noria.size() == 3)
	await _adv(5.0)
	_place(Vector2(6.0 * U, 0.0))
	_brain.debug_cast(DrownedIdolBrain.Spell.SPIRAL, _player.global_position)
	_check("P3 v2 : chapelet en spirale de 9 cercles", _brain._circles.size() == 9)
	await _adv(4.0)
	# mort : les digues restent (pas de gros pilier en test : tout est libéré proprement)
	_boss.take_damage(1e9)
	await get_tree().physics_frame
	_brain.clear()
	await _adv(0.5)


func _backstop() -> void:
	print("Attendre sous bouclier coûte : impulsions, garde-fou 45 s (soin + salve), enrage gelé")
	var back_s := float(Balance.boss_pressure(ID, "shield_backstop_s"))
	await _new_boss()
	_place(Vector2(-2000.0, -2000.0)) # joueur passif, hors de portée : on regarde ce que fait le boss
	_boss.hp = _boss.max_hp * 0.69
	await _adv(0.2)
	_check("bouclier levé", _brain.is_invulnerable())
	var hp_wait := _boss.hp
	await _adv(Balance.BOSS_SHIELD_TRANSITION_S + Balance.BOSS_SHIELD_SETUP_S + 9.5)
	_check("impulsion d'attente après 8 s sans cloche : anneaux supplémentaires", _events(&"stall").size() >= 1 and _brain.stall_rings >= 1,
		"%d impulsions, %d anneaux" % [_events(&"stall").size(), _brain.stall_rings])
	await _adv(back_s - 9.5 - 1.0)
	_check("encore levé avant 45 s (attendre ne suffit pas à 25 s)", _brain.is_invulnerable())
	_check("n-ième impulsion = n anneaux (3 au plus)", _events(&"stall").size() >= 4 and _brain.stall_rings >= 1 + 2 + 3, "%d impulsions, %d anneaux" % [_events(&"stall").size(), _brain.stall_rings])
	var rings_before := _brain.stall_rings
	await _until(func(): return not _brain.is_invulnerable(), 4.0)
	_check("garde-fou : le bouclier cède", not _brain.is_invulnerable() and _count("failed") >= 1 and (_ev["failed"] as Array)[0][0] == &"shield_backstop")
	_check("garde-fou : sans fenêtre", _brain.shield.by_backstop and not _brain.shield.rewarded)
	_check("garde-fou : l'idole se soigne de 10 % de ses PV max", _boss.hp >= hp_wait + _boss.max_hp * 0.10 - 1.0, "%f" % ((_boss.hp - hp_wait) / _boss.max_hp))
	_check("garde-fou : salve finale annoncée", _events(&"backstop_penalty").size() == 1)
	await _until(func(): return _brain.shield.state == BossShield.State.IDLE, 2.0)
	await _adv(2.5)
	_check("garde-fou : 3 anneaux supplémentaires lâchés", _brain.stall_rings >= rings_before + 3, "%d -> %d" % [rings_before, _brain.stall_rings])
	_check("garde-fou : retour à la normale (x 1,0)", is_equal_approx(_brain.damage_taken_mult(), 1.0))
	_check("enrage gelé sous bouclier", _boss.fight_time < 5.0 and _brain.enrage.frozen_s > 40.0,
		"fight_time %.1f gelé %.1f" % [_boss.fight_time, _brain.enrage.frozen_s])
	_brain.events.clear()
	_place(Vector2(3.0 * U, 0.0))
	_brain._attack_cd = 0.0
	_brain._spell_cd = 0.0
	await _adv(6.0)
	_check("pas de blocage : le combat reprend", _brain.events.size() > 0)
	# une cloche ramassée relance l'attente : le joueur actif n'est pas puni
	await _new_boss()
	_place(Vector2(-2000.0, -2000.0))
	_boss.hp = _boss.max_hp * 0.69
	await _until(func(): return _brain.shield.state == BossShield.State.ACTIVE, 4.0)
	var orbs := _orbs()
	await _adv(6.0)
	_place((orbs[0] as RaidOrb).global_position)
	await _adv(0.4)
	_place(Vector2(-2000.0, -2000.0))
	await _adv(6.0)
	_check("cloche ramassée : pas d'impulsion 6 s plus tard (l'attente repart de zéro)", _events(&"stall").is_empty(), str(_events(&"stall").size()))
	await _adv(3.0)
	_check("... mais elle revient si le joueur se remet à attendre", _events(&"stall").size() >= 1)


func _penalty_cap() -> void:
	print("Dégâts plafonnés")
	await _new_boss()
	_boss.damage = 1e7
	_player.max_hp = 100.0
	_player.hp = 100.0
	_place(Vector2(5.6 * U, 0.0))
	_brain.debug_cast(DrownedIdolBrain.Spell.CARILLON, _player.global_position)
	await _adv(3.5)
	_check("un coup énorme est plafonné à 40 % des PV", _hits.size() == 1 and _hits[0] <= 100.0 * Balance.MAX_HIT_FRACTION_BOSS + 0.01
		and _player.hp > 0.0, str(_hits))


func _cleanup() -> void:
	if _brain != null:
		_brain.clear()
	if _boss != null and is_instance_valid(_boss):
		_boss.brain = null
