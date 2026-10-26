extends Node
## Boîte à outils des boss façon raid (docs/Design_Boss_Raid.md §1, lots RK1 + RK2).
## godot --headless --path game res://tests/raid_kit_test.tscn  -> RESULT: OK
## Chaque mécanique en isolation, temps piloté par le test (step manuels, aucun processus physique) :
## 1. contrats : constantes Balance, signaux Events, Enemy.aim_priority / walk_target, EnemyVisual.set_skin_frames,
##    EnemyProjectilePool.cull_circles / cull_shadows / count_from ;
## 2. BossShield : rupture par chaque condition (ORBS, ULTIMATE_HIT, TIMER, KILL_ADDS, WEAK_POINT, SOAK, INTERACT),
##    invulnérabilité (dégâts × 0), fenêtre exposée × 1,3, garde-fou sans fenêtre (25 s / 20 s ultime), coups
##    lourds qui fissurent sans compter, add arrivé = soin plafonné et rupture sans fenêtre ;
## 3. SoakZone réussie / ratée (éclat : pénalité plafonnée, jamais mortelle) ; SafeSector (bord <= 6,3 u/s, ticks
##    hors secteur seulement) ; FixateMark (verrouillage >= 0,8 s, point figé) ; WeakPoint gardé / exposé ;
## 4. ShelterPylon + BarrageEmitter : refus sans 2 pylônes, joueur abrité intact, joueur exposé touché, plafond de
##    160 projectiles vivants, pylône abîmé, Events.raid_barrage ;
## 5. SoftEnrage : horloge gelée sous bouclier, avertissement 75 s, enrage 90 s.

const U := 64.0
const DT := 1.0 / 60.0
const ARENA := 2400.0

var _fails := 0
var _player
var _director: Director
var _map: Node2D
var _boss: Enemy
var _pool: EnemyProjectilePool
var _ev := {} ## nom de signal -> Array des arguments reçus


class TestBrain extends RefCounted:
	var shield: BossShield
	func tick(_d: float, _p: Node2D, _pp: Vector2, _dir: Vector2, _dist: float, _pd: Vector2) -> Vector2:
		return Vector2.ZERO
	func owns_motion() -> bool:
		return true
	func clear() -> void:
		if shield != null:
			shield.clear()
	func is_invulnerable() -> bool:
		return shield != null and shield.is_invulnerable()
	func damage_taken_mult() -> float:
		return shield.damage_taken_mult() if shield != null else 1.0
	func boss_state_tag() -> Dictionary:
		return shield.state_tag() if shield != null else {}


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


func _on(sig: String, a = null, b = null, c = null) -> void:
	if not _ev.has(sig):
		_ev[sig] = []
	(_ev[sig] as Array).append([a, b, c])


func _count(sig: String) -> int:
	return (_ev.get(sig, []) as Array).size()


func _last(sig: String) -> Array:
	var l: Array = _ev.get(sig, [])
	return l[l.size() - 1] if not l.is_empty() else [null, null, null]


func _run() -> void:
	RunState.level = 1
	_map = Node2D.new()
	_map.name = &"RaidMap"
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
	_player.global_position = Vector2(-900, 0)
	await get_tree().process_frame
	_director.bind_map(_map)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_director.set_physics_process(false) # temps piloté par le test
	_player.set_physics_process(false)
	_pool = _director.get_node(^"EnemyProjectiles") as EnemyProjectilePool
	Events.boss_shield_changed.connect(func(b, a, k): _on("shield_changed", b, a, k))
	Events.boss_shield_progress.connect(func(b, d, t): _on("shield_progress", b, d, t))
	Events.raid_mechanic_failed.connect(func(b, k): _on("failed", b, k))
	Events.raid_barrage.connect(func(b, a): _on("barrage", b, a))

	_contract_checks()
	_new_boss()
	_shield_orbs()
	_shield_ultimate()
	_shield_timer()
	_shield_backstop()
	_shield_adds()
	_shield_weak_point()
	_shield_soak()
	_shield_interact()
	_soak_zone()
	_safe_sector()
	_fixate()
	_shelter_barrage()
	_barrage_cap()
	_soft_enrage()

	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _new_boss() -> void:
	_boss = _director.spawn_boss(&"etage", Vector2.ZERO) as Enemy
	if _boss.brain != null:
		_boss.brain.clear()
	var br := TestBrain.new()
	br.shield = BossShield.create(_boss)
	_boss.brain = br


func _shield() -> BossShield:
	return (_boss.brain as TestBrain).shield


func _tick_shield(s: float) -> void:
	var n := int(round(s / DT))
	for i in n:
		_shield().tick(DT)


func _reset_player(pos: Vector2) -> void:
	_player.global_position = pos
	_player.dead = false
	_player.max_hp = 100.0
	_player.hp = 100.0
	_player._invuln = 0.0
	_player.shield = 0.0


# --- 1. Contrats
func _contract_checks() -> void:
	print("Contrats")
	_check("Balance raid", Balance.BOSS_SHIELD_BACKSTOP_S == 25.0 and Balance.BOSS_SHIELD_EXPOSED_MULT == 1.3
		and Balance.RAID_BARRAGE_COEF == 0.2 and Balance.BOSS_ENRAGE_WARN_S == 75.0 and Balance.RAID_BARRAGE_MAX_LIVE == 160)
	_check("boss_hp_mult / boss_shield_count", is_equal_approx(Balance.boss_hp_mult(&"salt_king"), 0.9)
		and Balance.boss_hp_mult(&"cerf") == 1.0 and Balance.boss_shield_count(&"flood_gunner") == 2 and Balance.boss_shield_count(&"cerf") == 1)
	for sig in [&"boss_shield_changed", &"boss_shield_progress", &"raid_mechanic_failed", &"raid_barrage"]:
		_check("Events.%s" % sig, Events.has_signal(sig))
	var e := _director.spawn_enemy(1, Vector2(600, 600))
	_check("Enemy.aim_priority = 1 à l'activation", e.aim_priority == 1.0 and e.walk_target == null)
	var ev := e.visual as EnemyVisual
	var sf := SpriteFrames.new()
	_check("set_skin_frames refuse sans anims du préfixe", not ev.set_skin_frames(sf, &"stoker_"))
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	for d in ["e", "s", "w", "n"]:
		sf.add_animation(StringName("stoker_run_" + d))
		sf.add_frame(StringName("stoker_run_" + d), tex)
	_check("set_skin_frames applique les anims stoker_", ev.set_skin_frames(sf, &"stoker_") and String(ev.current_anim()).begins_with("stoker_run_"),
		str(ev.current_anim()))
	e.take_damage(1e9)
	# pool : disques avec compte par cercle, ombres, comptage par source
	_pool.clear_all()
	var src := Node2D.new()
	add_child(src)
	_pool.fire(src, Vector2(100, 0), Vector2.ZERO, 1.0)
	_pool.fire(src, Vector2(300, 0), Vector2.ZERO, 1.0)
	_pool.fire(null, Vector2(400, 40), Vector2.ZERO, 1.0)
	_pool.fire(null, Vector2(900, 0), Vector2.ZERO, 1.0)
	_check("count_from", _pool.count_from(src) == 2)
	var counts := PackedInt32Array([0, 0])
	var n := _pool.cull_circles(PackedVector2Array([Vector2(110, 0), Vector2(1000, 1000)]), PackedFloat32Array([16.0, 16.0]), counts)
	_check("cull_circles (1 arrêté, compté par cercle)", n == 1 and counts[0] == 1 and counts[1] == 0, "%d %s" % [n, counts])
	var ns := _pool.cull_shadows(Vector2.ZERO, PackedVector2Array([Vector2(250, 0)]), 32.0, 6.0 * U)
	_check("cull_shadows (couloir derrière le pylône)", ns == 2 and _pool.active_count() == 1, "%d / %d" % [ns, _pool.active_count()])
	_pool.clear_all()
	src.queue_free()


# --- 2. Bouclier
func _arm(conds: Array, opts := {}) -> void:
	_boss.hp = _boss.max_hp * 0.6
	_ev.clear()
	_check("arm", _shield().arm(conds, opts))


func _shield_orbs() -> void:
	print("Bouclier : ORBS")
	_reset_player(Vector2(-900, 0))
	_arm([{"kind": &"orbs", "count": 3, "label": "CLOCHES"}])
	_check("invulnérable dès la transition", _boss.is_invulnerable() and _shield().damage_taken_mult() == 0.0)
	var hp0 := _boss.hp
	_boss.take_damage(500.0)
	_check("aucun dégât sous bouclier", _boss.hp == hp0)
	_check("Events.boss_shield_changed(true, orbs)", _count("shield_changed") == 1 and _last("shield_changed")[1] == true and _last("shield_changed")[2] == &"orbs")
	_check("pas d'attaque pendant la transition", not _shield().can_attack())
	_tick_shield(Balance.BOSS_SHIELD_TRANSITION_S + 0.05)
	var orbs: Array = _shield().objects.filter(func(o): return o is RaidOrb)
	_check("3 orbes jetées", orbs.size() == 3)
	for o in orbs:
		(o as RaidOrb).step(1.1)
	_check("orbes posées", orbs.all(func(o): return (o as RaidOrb).landed))
	_tick_shield(Balance.BOSS_SHIELD_SETUP_S)
	_check("ACTIVE, sort lent seulement", _shield().state == BossShield.State.ACTIVE and _shield().slow_only() and not _shield().can_attack())
	_tick_shield(Balance.BOSS_SHIELD_SLOW_SPELL_S + 0.05)
	_check("sort lent dû toutes les 4 s", _shield().take_slow_spell() and not _shield().take_slow_spell())
	var tag := _shield().state_tag()
	_check("tag de barre kind shield « CLOCHES 0/3 »", tag.get("kind") == &"shield" and String(tag.get("text")) == "CLOCHES 0/3", str(tag))
	for o in orbs:
		_player.global_position = (o as RaidOrb).global_position
		(o as RaidOrb).step(DT)
	_check("3 progrès émis", _count("shield_progress") == 3 and _last("shield_progress")[1] == 3)
	_tick_shield(DT)
	_check("rupture méritée", _shield().state == BossShield.State.BREAKING and _shield().rewarded and not _boss.is_invulnerable())
	_check("Events.boss_shield_changed(false)", _last("shield_changed")[1] == false)
	_tick_shield(Balance.BOSS_SHIELD_BREAK_S + 0.02)
	_check("fenêtre exposée × 1,3", _shield().is_exposed() and is_equal_approx(_shield().damage_taken_mult(), 1.3)
		and _shield().state_tag().get("kind") == &"exposed")
	hp0 = _boss.hp
	_boss.take_damage(100.0)
	_check("dégâts × 1,3 pendant la fenêtre", is_equal_approx(hp0 - _boss.hp, 130.0), str(hp0 - _boss.hp))
	_tick_shield(Balance.BOSS_SHIELD_EXPOSED_S + 0.02)
	_check("retour à la normale", _shield().state == BossShield.State.IDLE and _shield().damage_taken_mult() == 1.0 and _shield().can_attack())
	# chute d'orbe sur le joueur : coup du boss (pas de mort)
	_reset_player(Vector2(2000, 2000))
	var o2 := RaidOrb.throw(_boss.get_parent(), _boss, Vector2.ZERO, Vector2(2000, 2000), _player, Callable(), 5.0)
	o2.step(1.05)
	_check("chute d'orbe télégraphiée touche le joueur dessous", _player.hp < 100.0)
	o2.queue_free()


func _fake_spell(slot: int) -> SpellData:
	var s := SpellData.new()
	s.slot = slot
	return s


func _shield_ultimate() -> void:
	print("Bouclier : ULTIMATE_HIT")
	_reset_player(Vector2(-900, 0))
	_arm([{"kind": &"ultimate_hit"}])
	_check("garde-fou 20 s pour l'ultime", is_equal_approx(_shield().backstop_s, Balance.BOSS_SHIELD_BACKSTOP_ULT_S))
	_tick_shield(Balance.BOSS_SHIELD_TRANSITION_S + 0.05)
	var sh := _shield()
	sh._on_spell_hit(_fake_spell(2), _boss, 100.0)
	sh._on_spell_hit(_fake_spell(2), _boss, 100.0)
	sh._on_spell_hit(_fake_spell(3), _boss, 90.0)
	_check("coups lourds : fissures sans rupture (option coupée)", sh.cracks >= 2 and sh.is_invulnerable(), "cracks %d" % sh.cracks)
	sh._on_spell_hit(_fake_spell(ArdentKit.ULTIMATE_SLOT), _boss, 50.0)
	_tick_shield(DT)
	_check("l'ultime brise le bouclier", sh.state == BossShield.State.BREAKING and sh.rewarded)
	_tick_shield(Balance.BOSS_SHIELD_BREAK_S + Balance.BOSS_SHIELD_EXPOSED_S + 0.1)


func _shield_timer() -> void:
	print("Bouclier : TIMER")
	_arm([{"kind": &"timer", "s": 5.0}])
	_tick_shield(Balance.BOSS_SHIELD_TRANSITION_S + Balance.BOSS_SHIELD_SETUP_S + 0.05)
	_check("TIMER : le boss attaque pendant l'attente", _shield().can_attack() and not _shield().slow_only())
	_check("TIMER : texte « TENEZ 5 s »", String(_shield().state_tag().get("text")) == "TENEZ 5 s", str(_shield().state_tag()))
	_tick_shield(4.9)
	_check("TIMER : pas encore", _shield().is_invulnerable())
	_tick_shield(0.2)
	_check("TIMER : rupture après 5 s", _shield().state == BossShield.State.BREAKING and _shield().rewarded)
	_tick_shield(Balance.BOSS_SHIELD_BREAK_S + Balance.BOSS_SHIELD_EXPOSED_S + 0.1)


func _shield_backstop() -> void:
	print("Bouclier : garde-fou")
	_reset_player(Vector2(-2000, -2000))
	_arm([{"kind": &"orbs", "count": 3}])
	_tick_shield(Balance.BOSS_SHIELD_TRANSITION_S + 0.05)
	var orbs: Array = _shield().objects.duplicate()
	_tick_shield(Balance.BOSS_SHIELD_SETUP_S + Balance.BOSS_SHIELD_BACKSTOP_S - 0.5)
	_check("bouclier encore levé avant 25 s", _shield().is_invulnerable())
	_tick_shield(0.6)
	_check("garde-fou : le bouclier cède sans fenêtre", _shield().state == BossShield.State.BREAKING and not _shield().rewarded and _shield().by_backstop)
	_check("garde-fou : Events.raid_mechanic_failed(shield_backstop)", _count("failed") == 1 and _last("failed")[1] == &"shield_backstop")
	_check("garde-fou : orbes retirées", orbs.all(func(o): return not is_instance_valid(o) or (o as Node).is_queued_for_deletion()))
	_check("garde-fou : texte « LE BOUCLIER CÈDE »", String(_shield().state_tag().get("text")) == "LE BOUCLIER CÈDE")
	_tick_shield(Balance.BOSS_SHIELD_BREAK_S + 0.05)
	_check("garde-fou : aucune fenêtre", _shield().state == BossShield.State.IDLE and _shield().damage_taken_mult() == 1.0)


func _shield_adds() -> void:
	print("Bouclier : KILL_ADDS")
	_reset_player(Vector2(-900, 0))
	_arm([{"kind": &"kill_adds", "count": 2, "add_hp_frac": 0.07}])
	_tick_shield(Balance.BOSS_SHIELD_TRANSITION_S + 0.05)
	var pa := _shield().adds
	_check("2 adds sortis", pa != null and pa.alive() == 2)
	if pa == null or pa.alive() < 2:
		return
	var a0: Enemy = pa.adds[0]
	var a1: Enemy = pa.adds[1]
	_check("adds : priorité de visée 2, marchent vers le boss, aucun coup", a0.aim_priority == 2.0 and a0.walk_target == _boss and a0.damage == 0.0)
	_check("adds : PV = 7 % du boss", is_equal_approx(a0.max_hp, _boss.max_hp * 0.07))
	a0.take_damage(1e9)
	_check("add tué = progrès", _count("shield_progress") == 1 and pa.alive() == 1)
	_boss.hp = _boss.max_hp * 0.5
	a1.global_position = _boss.global_position + Vector2(10, 0)
	pa.step(DT)
	_check("add arrivé : boss soigné de 10 %", is_equal_approx(_boss.hp, _boss.max_hp * 0.6), "%f" % (_boss.hp / _boss.max_hp))
	_check("add arrivé : raid_mechanic_failed(add_reached)", _last("failed")[1] == &"add_reached")
	_tick_shield(DT)
	_check("tous tués ou consommés : rupture SANS fenêtre", _shield().state == BossShield.State.BREAKING and not _shield().rewarded)
	_tick_shield(Balance.BOSS_SHIELD_BREAK_S + 0.05)
	# plafond de soin : 20 % par groupe
	var p2 := PriorityAdds.create(_boss)
	p2.spawn(3, {"add_hp_frac": 0.05})
	_boss.hp = _boss.max_hp * 0.3
	for e in p2.adds.duplicate():
		(e as Enemy).global_position = _boss.global_position
	p2.step(DT)
	_check("soin des adds plafonné à 20 %", is_equal_approx(_boss.hp, _boss.max_hp * 0.5), "%f" % (_boss.hp / _boss.max_hp))
	p2.release()


func _shield_weak_point() -> void:
	print("Bouclier : WEAK_POINT")
	_arm([{"kind": &"weak_point", "points": 1, "offsets_u": [Vector2(-1.6, 0.0)]}])
	_tick_shield(Balance.BOSS_SHIELD_TRANSITION_S + 0.05)
	var wps: Array = _shield().objects.filter(func(o): return o is WeakPoint)
	_check("1 point faible", wps.size() == 1)
	if wps.is_empty():
		return
	var wp: WeakPoint = wps[0]
	wp.facing_angle = 0.0 # boss tourné vers +x : point au dos (-x)
	_reset_player(Vector2(600, 0)) # devant le boss : point gardé
	wp.step(DT)
	_check("point gardé (joueur devant) : hors du groupe enemies", not wp.exposed and not wp.is_in_group(&"enemies"))
	wp.take_damage(1e9)
	_check("point gardé : dégâts ignorés", not wp.broken)
	_reset_player(Vector2(-600, 40)) # dans le dos : exposé
	wp.step(DT)
	_check("point exposé : groupe enemies, couche 3, plus proche du joueur que le boss", wp.exposed and wp.is_in_group(&"enemies")
		and wp.collision_layer == WeakPoint.LAYER_ENEMIES and wp.global_position.distance_to(_player.global_position) < _boss.global_position.distance_to(_player.global_position))
	wp.take_damage(1e9)
	_tick_shield(DT)
	_check("point brisé : rupture méritée", _shield().state == BossShield.State.BREAKING and _shield().rewarded)
	_tick_shield(Balance.BOSS_SHIELD_BREAK_S + Balance.BOSS_SHIELD_EXPOSED_S + 0.1)
	# transfert × 2 hors bouclier
	var wp2 := WeakPoint.attach(_boss, Vector2(-1.6, 0.0))
	wp2.facing_angle = 0.0
	wp2.step(DT)
	var hp0 := _boss.hp
	wp2.take_damage(10.0)
	_check("transfert × 2 au boss", is_equal_approx(hp0 - _boss.hp, 20.0), str(hp0 - _boss.hp))
	wp2.release()


func _shield_soak() -> void:
	print("Bouclier : SOAK")
	_reset_player(Vector2(-2000, 0))
	_arm([{"kind": &"soak", "zones": 1, "positions": [Vector2(-500, 0)]}])
	_tick_shield(Balance.BOSS_SHIELD_TRANSITION_S + 0.05)
	var zs: Array = _shield().objects.filter(func(o): return o is SoakZone)
	_check("1 zone à absorber", zs.size() == 1)
	if zs.is_empty():
		return
	var z: SoakZone = zs[0]
	_player.global_position = Vector2(-500, 30)
	for i in int(1.0 / DT):
		z.step(DT)
	_player.global_position = Vector2(-2000, 0)
	for i in int(0.5 / DT):
		z.step(DT)
	_check("la jauge se vide à mi-vitesse dehors", z.fill > 0.4 and z.fill < 0.6, str(z.fill))
	_player.global_position = Vector2(-500, 30)
	for i in int(1.0 / DT):
		z.step(DT)
	_tick_shield(DT)
	_check("zone remplie : rupture", z.done and _shield().state == BossShield.State.BREAKING and _shield().rewarded)
	_tick_shield(Balance.BOSS_SHIELD_BREAK_S + Balance.BOSS_SHIELD_EXPOSED_S + 0.1)


func _shield_interact() -> void:
	print("Bouclier : INTERACT")
	_reset_player(Vector2(-2000, 0))
	_arm([{"kind": &"interact", "props": 2, "positions": [Vector2(0, 600), Vector2(0, -600)]}])
	_tick_shield(Balance.BOSS_SHIELD_TRANSITION_S + 0.05)
	var props: Array = _shield().objects.filter(func(o): return o is RaidProp)
	_check("2 props, groupe interactable", props.size() == 2 and props.all(func(p): return (p as Node).is_in_group(&"interactable")))
	if props.size() < 2:
		return
	var p0: RaidProp = props[0]
	_check("invite cachée hors de portée", not bool(p0.interact_state()["visible"]))
	_player.global_position = p0.global_position + Vector2(20, 0)
	var st := p0.interact_state()
	_check("invite : maintien 0,6 s, priorité 2", bool(st["visible"]) and is_equal_approx(float(st["hold_s"]), 0.6) and p0.interact_priority() == 2)
	p0.interact()
	(props[1] as RaidProp).interact()
	_tick_shield(DT)
	_check("2 props actionnés : rupture", _shield().state == BossShield.State.BREAKING and _shield().rewarded)
	_tick_shield(Balance.BOSS_SHIELD_BREAK_S + Balance.BOSS_SHIELD_EXPOSED_S + 0.1)


# --- 3. Terrain
func _soak_zone() -> void:
	print("SoakZone")
	_ev.clear()
	_reset_player(Vector2(-2000, 0))
	var z := SoakZone.spawn(_boss, Vector2(800, 0), {"life_s": 4.0, "fail": &"burst"})
	for i in int(4.05 / DT):
		z.step(DT)
	_check("ratée à life_s", z.is_failed)
	_reset_player(Vector2(850, 0))
	_player.hp = 5.0
	_boss.damage = 10000.0
	for i in int(1.05 / DT):
		z.step(DT)
	_check("éclat : pénalité non létale (joueur à 1 PV, vivant)", not _player.dead and _player.hp >= 1.0, "hp %f" % _player.hp)
	_check("éclat : raid_mechanic_failed(soak)", _last("failed")[1] == &"soak")
	var z2 := SoakZone.spawn(_boss, Vector2(800, 0), {"life_s": 4.0, "fail": &"burst"})
	_reset_player(Vector2(-2000, 0))
	for i in int(4.05 / DT):
		z2.step(DT)
	_reset_player(Vector2(850, 0))
	for i in int(1.05 / DT):
		z2.step(DT)
	_check("éclat : plafonné à 40 % des PV max", _player.hp >= 59.9, "hp %f" % _player.hp)
	_boss.damage = Balance.boss_damage(&"etage", RunState.difficulty())


func _safe_sector() -> void:
	print("SafeSector")
	_reset_player(Vector2(0, 0))
	var s := SafeSector.spawn(_boss, Vector2.ZERO, {"turn_deg_s": 80.0, "radius_u": 9.0, "duration_s": 6.0})
	_check("bord <= 6,3 u/s (rotation bornée)", s.edge_speed_u() <= SafeSector.MAX_EDGE_SPEED_U + 0.001, str(s.edge_speed_u()))
	_check("télégraphe >= 1,2 s", s.tele_s >= 1.2)
	var a0 := s.angle
	# le joueur suit le secteur à 4 u : aucun tick
	for i in int(4.0 / DT):
		_player._invuln = 0.0
		_player.global_position = Vector2.from_angle(s.angle) * 4.0 * U
		s.step(DT)
	_check("le secteur tourne", absf(angle_difference(a0, s.angle)) > 0.5)
	_check("dans le secteur : aucun tick", s.ticks_hit == 0 and _player.hp == 100.0)
	for i in int(1.0 / DT):
		_player._invuln = 0.0
		_player.global_position = Vector2.from_angle(s.angle + PI) * 4.0 * U
		s.step(DT)
	_check("hors du secteur : ticks + ralentissement", s.ticks_hit >= 1 and _player.hp < 100.0)
	s.queue_free()


func _fixate() -> void:
	print("FixateMark")
	_reset_player(Vector2(500, 300))
	var m := FixateMark.spawn(_boss, _player.global_position, {"lock_s": 0.3, "duration_s": 2.0, "radius_u": 2.0, "coef": 0.2})
	_check("verrouillage >= 0,8 s", m.lock_s >= 0.8)
	var pt := m.point
	_player.global_position = Vector2(-1500, 0)
	for i in int(0.7 / DT):
		m.step(DT)
	_check("pas encore figé à 0,7 s", not m.is_locked)
	for i in int(0.2 / DT):
		m.step(DT)
	_check("figé après 0,8 s, point inchangé", m.is_locked and m.point == pt)
	_reset_player(pt)
	for i in int(0.6 / DT):
		_player._invuln = 0.0
		m.step(DT)
	_check("joueur sur le point : touché", m.hits >= 1 and _player.hp < 100.0)
	m.queue_free()


func _step_barrage(b: BarrageEmitter, sp: ShelterPylon, s: float, keep_hp := false) -> void:
	for i in int(s / DT):
		b.step(DT)
		sp.step(DT)
		_pool.update(DT, _player, _player.global_position, _director.nav)
		if keep_hp:
			_player._invuln = 0.0


func _shelter_barrage() -> void:
	print("ShelterPylon + BarrageEmitter")
	_ev.clear()
	_pool.clear_all()
	_boss.global_position = Vector2.ZERO
	_reset_player(Vector2(-1800, -1800))
	var sp := ShelterPylon.create(_boss)
	var b := BarrageEmitter.create(_boss, sp)
	_check("barrage refusé sans 2 pylônes debout", not b.start(0.0))
	sp.plant(Vector2(300, 0))
	sp.plant(Vector2(0, 400))
	_check("pylônes en chute (0,9 s)", sp.live_count() == 0 and sp.pylons.size() == 2)
	for i in int(1.0 / DT):
		sp.step(DT)
	_check("pylônes posés : corps couche 1 + obstacle NavField", sp.live_count() == 2 and (sp.pylons[0]["body"] as StaticBody2D).collision_layer == 1
		and (_director.nav == null or _director.nav.obstacle_count() >= 2))
	var shelter := Vector2(500, 0)
	var open := Vector2(500, 180)
	_check("abri par ligne de vue", sp.shelters(shelter, Vector2.ZERO) and not sp.shelters(open, Vector2.ZERO))
	_check("barrage accepté avec 2 pylônes", b.start(0.0, {"arc_deg": 60.0, "rate": 30.0, "duration_s": 4.0}))
	_check("Events.raid_barrage(true) + télégraphe 1,5 s", _count("barrage") == 1 and _last("barrage")[1] == true and b.telegraph_s >= 1.5)
	_check("ombres dessinées pendant le barrage", sp.shadows_shown())
	_reset_player(shelter)
	_step_barrage(b, sp, 1.5, true)
	_check("aucun tir pendant le télégraphe", b.fired_total == 0)
	_step_barrage(b, sp, 2.0, true)
	_check("abrité derrière le pylône : aucun dégât", _player.hp == 100.0 and b.fired_total > 40, "hp %f, tirs %d" % [_player.hp, b.fired_total])
	_check("pylône abîmé par le barrage", sp.blocked_total > 0)
	_player.global_position = open
	_step_barrage(b, sp, 2.1, true)
	_check("hors abri : touché", _player.hp < 100.0, "hp %f" % _player.hp)
	_check("fin du barrage : Events.raid_barrage(false), ombres coupées", not b.is_busy() and _last("barrage")[1] == false and not sp.shadows_shown())
	_pool.clear_all()
	b.release()
	sp.release()


func _barrage_cap() -> void:
	print("Plafond de projectiles")
	_reset_player(Vector2(-1800, 1800))
	var b := BarrageEmitter.create(_boss)
	b.start(0.0, {"rate": 400.0, "duration_s": 3.0, "arc_deg": 360.0, "range_u": 40.0, "speed_u": 1.0})
	var peak := 0
	for i in int(4.6 / DT):
		b.step(DT)
		_pool.update(DT, _player, _player.global_position, null)
		peak = maxi(peak, _pool.count_from(b))
	_check("<= 160 projectiles vivants", peak <= Balance.RAID_BARRAGE_MAX_LIVE and peak >= 150 and b.peak_live <= 160, "pic %d" % peak)
	_check("pool jamais épuisé", _pool.free_count() + _pool.active_count() >= Director.PROJECTILE_POOL)
	_pool.clear_all()
	b.release()
	# coût par image : 160 projectiles + 6 pylônes (disques + ombres) + émission, mesuré sur 120 images
	var sp := ShelterPylon.create(_boss)
	for k in 6:
		sp.plant(Vector2.from_angle(TAU * k / 6.0) * 5.0 * U, 0.0)
	var b2 := BarrageEmitter.create(_boss, sp)
	b2.start(0.0, {"rate": 400.0, "duration_s": 10.0, "arc_deg": 360.0, "range_u": 40.0, "speed_u": 0.5, "telegraph_s": 1.5})
	for i in int(2.2 / DT):
		b2.step(DT)
	var t0 := Time.get_ticks_usec()
	var frames := 120
	for i in frames:
		b2.step(DT)
		sp.step(DT)
		_pool.update(DT, _player, _player.global_position, _director.nav)
	var us := float(Time.get_ticks_usec() - t0) / frames
	print("    coût moyen par image : %.0f µs (%d projectiles, %d pylônes)" % [us, _pool.active_count(), sp.live_count()])
	_check("perf : < 1,5 ms par image (160 projectiles + 6 pylônes)", us < 1500.0 and sp.live_count() >= 5, "%.0f µs" % us)
	_pool.clear_all()
	b2.release()
	sp.release()


# --- 5. Enrage
func _soft_enrage() -> void:
	print("SoftEnrage")
	_boss.fight_time = 0.0
	var en := SoftEnrage.create(_boss)
	_arm([{"kind": &"timer", "s": 200.0}], {"backstop_s": 300.0})
	for i in int(120.0 / 0.1):
		_boss.fight_time += 0.1 # Enemy.tick avant brain.tick
		_shield().tick(0.1)
		en.tick(0.1, _shield().freezes_enrage())
	_check("enrage gelé sous bouclier", en.vulnerable_s == 0.0 and _boss.fight_time == 0.0 and _boss.current_damage() == _boss.damage)
	_shield().clear()
	for i in int(76.0 / 0.1):
		_boss.fight_time += 0.1
		en.tick(0.1, _shield().freezes_enrage())
	_check("avertissement à 75 s", en.is_warned and not en.is_enraged and en.state_tag().get("kind") == &"enrage_warn")
	for i in int(20.0 / 0.1):
		_boss.fight_time += 0.1
		en.tick(0.1, false)
	_check("enrage à 90 s (temps vulnérable)", en.is_enraged and _boss.current_damage() > _boss.damage and is_equal_approx(_boss.fight_time, en.vulnerable_s))
	en.clear()
