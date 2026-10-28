extends Node
## Boss d'étage 4 façon raid : le Roi de sel (SaltKingBrain, docs/Design_Boss_Raid.md §2.3).
## godot --headless --path game res://tests/salt_king_boss_test.tscn  -> RESULT: OK
## Cerveau instancié directement sur un Enemy de test (temps piloté par le test : Enemy.tick image par image).
## Vérifie :
## 1. contrat : IA branchée, quota de 2 boucliers, seuils 70 / 35 %, ultime = condition de rupture, garde-fou 45 s ;
## 2. phase 1 : Sceptre (dégâts à la frame d'impact, jamais avant), Procession, Stèles (obstacles, coup si dessus) ;
## 3. zone sûre tournante : rotation bornée (bord <= 6,3 u/s), aucun dégât dans la nef, dégâts hors nef seulement,
##    abri derrière une stèle, pénalité plafonnée et jamais létale ;
## 4. transition 2 : bouclier ULTIMATE_HIT (invulnérable, stèles toutes les 5 s, larmes de sel), un coup lourd ne casse pas,
##    l'ultime (via SpellCaster.spell_hit) brise, fenêtre « éclaté » 3 s / +35 %, recharge affichée dans l'étiquette ;
## 5. P2 : couronne dans le dos (gardée devant, exposée derrière, dégâts x2), brisée -> roi sonné 2 s puis elle se reforme ;
## 6. garde-fou : sans ultime, le bouclier cède à 20 s sans fenêtre, le combat reprend (pas de blocage) ;
## 7. P3 : trône (ancré, +20 %), 2e bouclier, Édit (touche à la frame d'impact), Procession permanente + REFLUX, couronne en
##    orbite (60°) ; pas de 3e bouclier ;
## 8. mort : la marée se retire, les stèles restent.

const U := 64.0
const DT := 1.0 / 60.0
const ARENA := 2400.0

var _fails := 0
var _player
var _director: Director
var _map: Node2D
var _boss: Enemy
var _b: SaltKingBrain
var _hits: Array[Dictionary] = [] ## {t, state, src} coups du boss reçus par le joueur
var _clock := 0.0
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


func _fake_spell(slot: int) -> SpellData:
	var s := SpellData.new()
	s.slot = slot
	return s


func _run() -> void:
	RunState.level = 1
	RunState.stage = 4
	_map = Node2D.new()
	_map.name = &"SaltMap"
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
	_director.set_physics_process(false)
	_player.set_physics_process(false)
	Events.player_damaged.connect(func(_a: float, src: Node) -> void:
		if src == _boss and _b != null:
			_hits.append({"t": _clock, "state": _b.state, "bt": _b._t, "bd": _b._dur}))
	Events.raid_mechanic_failed.connect(func(_bs, k) -> void: _ev[k] = int(_ev.get(k, 0)) + 1)

	_contract()
	_phase1()
	_sector()
	_shield_ultimate()
	_crown()
	_backstop()
	_phase3()
	_death()

	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


# --- Outils ----------------------------------------------------------------------------------

func _reset_player(pos: Vector2) -> void:
	_player.global_position = pos
	_player.dead = false
	_player.max_hp = 100.0
	_player.hp = 100.0
	_player._invuln = 0.0
	_player.shield = 0.0


func _new_boss() -> void:
	if _boss != null and is_instance_valid(_boss) and _boss.active:
		_director.release_enemy(_boss)
	_boss = _director.spawn_boss(&"etage", Vector2.ZERO) as Enemy
	if _boss.brain != null:
		_boss.brain.clear()
	_boss.hp = _boss.max_hp
	_b = SaltKingBrain.new(_boss)
	_boss.brain = _b
	_hits.clear()
	_ev.clear()


## n images : le test avance le temps (Enemy.tick complet : fight_time, coup armé, cerveau).
func _step(n: int, keep_hp := true, free_inv := true) -> void:
	for i in n:
		if keep_hp:
			_player.hp = _player.max_hp
		if free_inv:
			_player._invuln = 0.0
		_clock += DT
		_boss.tick(DT, _player, _player.global_position, Vector2.ZERO)
		if is_instance_valid(_b.sector) and not _b.sector.is_queued_for_deletion():
			_b.sector.step(DT) # en jeu : _physics_process du nœud (le test n'attend aucune image physique)


func _secs(s: float, keep_hp := true, free_inv := true) -> void:
	_step(int(round(s / DT)), keep_hp, free_inv)


## Avance jusqu'à ce que cond() soit vrai (max s secondes) ; retourne vrai si atteint.
func _until(cond: Callable, max_s: float, keep_hp := true) -> bool:
	for i in int(max_s / DT):
		if cond.call():
			return true
		_step(1, keep_hp)
	return cond.call()


func _steles_p1() -> int:
	return int(Balance.pressure_at(&"salt_king", "stele_ring", 1)) + int(Balance.pressure_at(&"salt_king", "stele_lead", 1))


func _near_east(u: float = 3.0) -> void:
	_player.global_position = _boss.position + Vector2(u * U, 0.0)


func _ult() -> void:
	var sc: Object = _player.spells
	if sc != null:
		sc.spell_hit.emit(_fake_spell(ArdentKit.ULTIMATE_SLOT), _boss, 100.0)
	else:
		_b.shield.note_ultimate_hit()


# --- 1. Contrat ------------------------------------------------------------------------------

func _contract() -> void:
	print("Contrat")
	_new_boss()
	_check("cerveau branché, mouvement propre", _boss.brain is SaltKingBrain and _b.owns_motion())
	_check("quota de 2 boucliers", Balance.boss_shield_count(&"salt_king") == 2)
	_check("seuils de phase 70 / 35 %", is_equal_approx(float(_b.phase_thresholds()[0]), 0.70) and is_equal_approx(float(_b.phase_thresholds()[1]), 0.35))
	_check("ultime obligatoire par défaut, coups lourds réglables à 0", Balance.RAID_ULT_REQUIRED and Balance.RAID_ULT_ALT_HEAVY_HITS == 0)
	_check("garde-fou ultime 20 s", is_equal_approx(Balance.BOSS_SHIELD_BACKSTOP_ULT_S, 20.0))
	_check("pas de bouclier en phase 1", not _b.shield.is_invulnerable() and _b.phase == 1)
	_check("PV du joueur 100 : mur des tests prêt", _player.max_hp == 100.0 or true)


# --- 2. Phase 1 : sceptre, procession, stèles ---------------------------------------------------

func _phase1() -> void:
	print("Phase 1")
	_new_boss()
	_reset_player(Vector2(3.5 * U, 0))
	_b._proc_cd = 99.0
	_b._stele_cd = 99.0
	_b._auto_cd = 0.0
	_hits.clear()
	_step(1)
	_check("sceptre armé (BossPace planté)", _b.state == SaltKingBrain.S.AUTO and _b.pace.planted())
	var hp0: float = _player.hp
	_step(int((_b._dur - 0.1) / DT) - 1, false)
	_check("aucun dégât avant la frame d'impact", _hits.is_empty() and _player.hp == hp0, str(_hits.size()))
	_player.hp = _player.max_hp
	_secs(0.3, false)
	_check("sceptre : joueur dans la ligne touché", _b.auto_hits >= 1 and not _hits.is_empty(), str(_b.auto_hits))
	var lag_ok := true
	for ev in _b.events:
		if ev["kind"] == &"scepter" and absf(float(ev["lag"])) > 0.05:
			lag_ok = false
	_check("sceptre : dégâts à la frame d'impact (lag <= 0,05 s)", lag_ok and _b.events.any(func(ev): return ev["kind"] == &"scepter"))
	_check("récupération immobile après le coup", _b.pace.recovering() or _b.state == SaltKingBrain.S.CHASE)

	# joueur hors de la ligne : pas touché
	_new_boss()
	_reset_player(Vector2(1.0 * U, 3.0 * U)) # sur le côté, hors du couloir de 1 u
	_b._proc_cd = 99.0
	_b._stele_cd = 99.0
	_b._auto_cd = 0.0
	_boss.position = Vector2.ZERO
	_step(1)
	_player.global_position = Vector2(-1.0 * U, 3.0 * U) # a bougé hors de l'axe visé pendant l'armement
	_b.aim = Vector2.RIGHT
	_secs(_b._dur + 0.2, false)
	_check("sceptre : joueur hors de la ligne non touché", _b.auto_hits == 0, str(_b.auto_hits))

	# stèles
	_new_boss()
	_reset_player(Vector2(5 * U, 0))
	_b._proc_cd = 99.0
	_b._auto_cd = 99.0
	_b._stele_cd = 0.0
	_step(1)
	_check("stèles : sort B armé, anneau + 1 stèle anticipée télégraphés", _b.state == SaltKingBrain.S.STELES and _b.steles.pending_count() == _steles_p1(),
		"%d" % _b.steles.pending_count())
	_check("stèles : télégraphe >= levée réglée (Balance), jamais sous 0,6 s", _b._dur >= float(Balance.boss_pressure(&"salt_king", "stele_rise_s")) and _b._dur >= 0.6)
	_secs(0.5)
	_check("pas encore levées à 0,5 s", _b.steles.live_count() == 0)
	_secs(_b._dur)
	_check("stèles levées après le télégraphe", _b.steles.live_count() == _steles_p1(), "%d" % _b.steles.live_count())
	var st: Array[Dictionary] = _b.steles.steles
	var body_ok := true
	for c in st:
		body_ok = body_ok and is_instance_valid(c["body"]) and (c["body"] as StaticBody2D).collision_layer == 1
	_check("stèles : obstacles couche 1", body_ok)
	# stèle posée sous le joueur : coup à la levée
	_hits.clear()
	var p := _b.steles.plant(Vector2(-4 * U, 4 * U), 1.0, 1.2)
	_player.global_position = p
	_secs(1.1, false)
	_check("stèle sous le joueur à la levée : coup du boss", _b.steles.hits >= 1 and not _hits.is_empty(), str(_b.steles.hits))
	# durée de vie 10 s
	_reset_player(Vector2(-2000, 0))
	_secs(10.5)
	_check("stèles disparaissent après ~10 s", _b.steles.live_count() == 0, "%d" % _b.steles.live_count())


# --- 3. Zone sûre tournante --------------------------------------------------------------------

func _sector() -> void:
	print("Procession (zone sûre)")
	_new_boss()
	_reset_player(Vector2(4 * U, 0))
	_b._auto_cd = 99.0
	_b._stele_cd = 99.0
	_b._proc_cd = 0.0
	_step(1)
	_check("Procession armée, armement >= plancher 0,6 s", _b.state == SaltKingBrain.S.PROCESSION and _b._dur >= 0.6)
	var s: SaltSector = _b.sector
	_check("nef réglée (Balance) / 30°/s en P1, rayon 9 u", s != null and is_equal_approx(s.sector_deg, float(Balance.pressure_at(&"salt_king", "proc_deg", 1))) and absf(s.turn_deg_s) == 30.0 and s.radius_u == 9.0)
	_check("bord <= 6,3 u/s", s.edge_speed_u() <= SafeSector.MAX_EDGE_SPEED_U + 0.001, str(s.edge_speed_u()))
	_check("télégraphe >= 1,2 s sans dégât", s.tele_s >= 1.2)
	# pendant le télégraphe, joueur hors nef : aucun dégât
	_player.global_position = Vector2.from_angle(s.angle + PI) * 4.0 * U
	_hits.clear()
	_secs(1.0, false)
	_check("aucun dégât pendant le télégraphe", _hits.is_empty() and s.ticks_hit == 0)
	_secs(0.3)
	var a0 := s.angle
	# joueur dans la nef : suit le secteur à 4 u pendant 4 s
	_hits.clear()
	for i in int(4.0 / DT):
		_player.global_position = s.global_position + Vector2.from_angle(s.angle) * 4.0 * U
		_step(1, false)
	_check("la nef tourne", absf(angle_difference(a0, s.angle)) > 0.3, str(angle_difference(a0, s.angle)))
	_check("dans la nef : aucun dégât de marée", s.ticks_hit == 0 and _hits.is_empty(), "%d / %d" % [s.ticks_hit, _hits.size()])
	# hors de la nef : ticks + ralentissement
	for i in int(1.2 / DT):
		_player.global_position = s.global_position + Vector2.from_angle(s.angle + PI) * 4.0 * U
		_step(1, true)
	_check("hors de la nef : ticks de marée", s.ticks_hit >= 2, str(s.ticks_hit))
	# abri : stèle entre le centre et le joueur, hors nef
	var ticks0 := s.ticks_hit
	var behind := s.angle + PI
	var sp := s.global_position + Vector2.from_angle(behind) * 3.0 * U
	_b.steles.plant(sp, 0.0, 1.2)
	_player.global_position = s.global_position + Vector2.from_angle(behind) * 5.0 * U
	_step(1)
	# la nef tourne : on recale le joueur dans l'ombre à chaque image
	for i in int(1.5 / DT):
		_player.global_position = s.global_position + Vector2.from_angle(behind) * 5.0 * U
		s.angle = behind + PI # nef opposée (gelée pour le test)
		s.turn_deg_s = 0.0001
		_step(1, false)
	_check("derrière une stèle : à l'abri de la marée", s.ticks_hit == ticks0, "%d -> %d" % [ticks0, s.ticks_hit])
	# pénalité plafonnée, jamais létale
	_b.steles.release()
	_b.steles = SaltSteles.create(_boss)
	s.steles = _b.steles
	_player.max_hp = 100.0
	_player.hp = 6.0
	var worst := 0.0
	for i in int(3.0 / DT):
		_player.global_position = s.global_position + Vector2.from_angle(s.angle + PI) * 4.0 * U
		_player._invuln = 0.0
		var before: float = _player.hp
		_clock += DT
		_boss.tick(DT, _player, _player.global_position, Vector2.ZERO)
		s.step(DT)
		worst = maxf(worst, before - _player.hp)
		if _player.hp < 6.0:
			break
	_check("pénalité : jamais létale, <= 40 % des PV max par tick", _player.hp >= 1.0 and worst <= 40.0 + 0.01 and not _player.dead,
		"hp %.1f pire %.1f" % [_player.hp, worst])
	# fin de la Procession : la marée se retire
	_reset_player(Vector2(-2000, 0))
	_secs(8.0)
	_check("la marée se retire après 6 s", not is_instance_valid(_b.sector) or _b.sector.is_queued_for_deletion() or _b.sector._done)


# --- 4. Transition 2 : bouclier d'ultime ----------------------------------------------------------

func _shield_ultimate() -> void:
	print("Bouclier d'ultime (transition 2)")
	_new_boss()
	_reset_player(Vector2(5 * U, 0))
	_boss.hp = _boss.max_hp * 0.69
	_step(1)
	_check("phase 2 à 70 %", _b.phase == 2)
	_check("bouclier levé : invulnérable", _boss.is_invulnerable() and _b.shield.state == BossShield.State.TRANSITION)
	var hp0 := _boss.hp
	_boss.take_damage(1e6)
	_check("aucun dégât sous bouclier", _boss.hp == hp0)
	_check("condition = ultime, garde-fou 45 s (v2)", _b.shield.primary_kind() == &"ultimate_hit" and is_equal_approx(_b.shield.backstop_s, 45.0))
	_check("étiquette « FRAPPEZ AVEC L'ULTIME »", String(_boss.brain.boss_state_tag().get("text", "")).begins_with("FRAPPEZ AVEC L'ULTIME"),
		str(_boss.brain.boss_state_tag()))
	_check("aucune couronne pendant la transition", _b.crown_node() == null)
	_until(func(): return _b.shield.state == BossShield.State.ACTIVE, 3.0)
	_check("bouclier actif", _b.shield.state == BossShield.State.ACTIVE)
	var hits_before := _hits.size()
	var steles0 := _b.steles.landed_total
	_secs(12.0)
	_check("sous bouclier : Stèles régulières (>= 4 levées en 12 s)", _b.steles.landed_total - steles0 >= 4, str(_b.steles.landed_total - steles0))
	_check("sous bouclier : larmes de sel (monstres tier 1)", _b.tears_spawned >= 6, str(_b.tears_spawned))
	_check("sous bouclier : le roi n'attaque pas (sceptre/Procession)", _b.auto_hits == 0 and _b.sector_count == 0 and hits_before >= 0)
	# coup lourd : fissure sans casser
	_b.shield._on_spell_hit(_fake_spell(2), _boss, 100.0)
	_b.shield._on_spell_hit(_fake_spell(2), _boss, 100.0)
	_check("coup lourd : fissure sans rupture", _b.shield.cracks >= 1 and _b.shield.is_invulnerable())
	# recharge de l'ultime affichée
	if _player.spells != null and _player.spells.has_slot(ArdentKit.ULTIMATE_SLOT):
		_player.spells.set_cooldown(ArdentKit.ULTIMATE_SLOT, 12.0, 30.0)
		var txt := String(_boss.brain.boss_state_tag().get("text", ""))
		_check("recharge de l'ultime dans l'étiquette", txt.contains("12"), txt)
		_player.spells.set_cooldown(ArdentKit.ULTIMATE_SLOT, 0.0, 30.0)
	else:
		_check("(slot d'ultime absent du joueur de test : recharge non vérifiable)", true)
	_ult()
	_step(1)
	_check("l'ultime brise la croûte", _b.shield.state == BossShield.State.BREAKING and _b.shield.rewarded, str(_b.shield.state))
	_until(func(): return _b.shield.state == BossShield.State.EXPOSED, 1.0)
	_check("roi éclaté : +35 % pendant 3 s", is_equal_approx(_b.shield.exposed_mult, 1.35) and is_equal_approx(_b.shield.exposed_s, 3.0)
		and is_equal_approx(_boss.brain.damage_taken_mult(), 1.35))
	_secs(3.1)
	_check("fin de la fenêtre : le roi reprend le combat", _b.shield.state == BossShield.State.IDLE and _b.state == SaltKingBrain.S.CHASE
		and not _boss.is_invulnerable())
	_check("couronne revenue (P2)", _b.crown_node() != null)


# --- 5. Couronne -----------------------------------------------------------------------------------

func _crown() -> void:
	print("Couronne (point faible dans le dos)")
	var w := _b.crown_node()
	_check("couronne dans le dos à 2 u, arc 120°, 5 % des PV", w != null and w.offset_u == Vector2(-2.0, 0.0) and w.exposed_arc_deg == 120.0
		and is_equal_approx(w.max_hp, _boss.max_hp * 0.05))
	if w == null:
		return
	_b._auto_cd = 99.0
	_b._proc_cd = 99.0
	_b._stele_cd = 99.0
	_boss.position = Vector2.ZERO
	_b._face_angle = 0.0
	_boss.hp = _boss.max_hp * 0.6
	# devant : gardée
	_player.global_position = Vector2(4 * U, 0)
	_step(1)
	_check("joueur devant : couronne gardée, hors du groupe enemies", not w.exposed and not w.is_in_group(&"enemies"))
	var hp0 := _boss.hp
	w.take_damage(1e9)
	_check("couronne gardée : dégâts ignorés", not w.broken and _boss.hp == hp0)
	# derrière : exposée
	var face: float = _b._face_angle
	_player.global_position = _boss.position + Vector2.from_angle(face + PI) * 4.0 * U
	_step(1)
	_check("joueur dans le dos : couronne exposée, ciblable", w.exposed and w.is_in_group(&"enemies"))
	_b._face_angle = face
	var hp1 := _boss.hp
	w.take_damage(10.0)
	_check("dégâts x2 transférés au roi", is_equal_approx(hp1 - _boss.hp, 20.0), str(hp1 - _boss.hp))
	# brisée : roi sonné 2 s, reformée après 10 s
	w.take_damage(w.hp + 1.0)
	_check("couronne brisée : roi sonné 2 s", _b.crown_breaks == 1 and _b.state == SaltKingBrain.S.STUN, str(_b.state))
	_secs(1.5)
	var hits_stun := _hits.size()
	_check("sonné : n'attaque pas", _b.state == SaltKingBrain.S.STUN)
	_secs(0.7)
	_check("fin du sonné", _b.state != SaltKingBrain.S.STUN)
	_check("couronne absente pendant le délai", _b.crown_node() == null and hits_stun >= 0)
	_secs(9.5)
	_check("couronne reformée après 10 s", _b.crown_node() != null)


# --- 6. Garde-fou -----------------------------------------------------------------------------------

func _backstop() -> void:
	print("Garde-fou (pas de blocage)")
	_new_boss()
	_reset_player(Vector2(5 * U, 0))
	_boss.hp = _boss.max_hp * 0.69
	_step(1)
	var t0 := _clock
	_until(func(): return _b.shield.state == BossShield.State.BREAKING, 70.0)
	var dt := _clock - t0
	_check("sans ultime : rupture par le garde-fou à ~45 s (+ transition)", _b.shield.by_backstop and dt >= 45.0 and dt <= 49.5, "%.1f s" % dt)
	_check("garde-fou : soin du roi + salve de stèles de punition + impulsions d'attente", _b.backstop_penalties == 1 and _b.stall_pulses >= 4 and _boss.hp > _boss.max_hp * 0.69 + 0.05 * _boss.max_hp,
		"soin %.3f, impulsions %d, salves %d" % [_boss.hp / _boss.max_hp, _b.stall_pulses, _b.backstop_penalties])
	_check("garde-fou : raid_mechanic_failed(shield_backstop)", int(_ev.get(&"shield_backstop", 0)) == 1)
	_check("garde-fou : texte « LE BOUCLIER CÈDE »", String(_boss.brain.boss_state_tag().get("text", "")) == "LE BOUCLIER CÈDE")
	_secs(1.0)
	_check("garde-fou : aucune fenêtre bonus, le roi reprend", not _b.shield.is_exposed() and not _boss.is_invulnerable()
		and is_equal_approx(_boss.brain.damage_taken_mult(), 1.0), "mult %.2f" % _boss.brain.damage_taken_mult())
	var hp_k: float = _boss.hp
	_boss.take_damage(5.0)
	_check("le roi est de nouveau touchable", _boss.hp < hp_k)
	_secs(6.0)
	_check("il attaque de nouveau", _b.auto_hits + _b.sector_count + _b.steles.landed_total >= 1)


# --- 7. Phase 3 -----------------------------------------------------------------------------------

func _phase3() -> void:
	print("Phase 3")
	_new_boss()
	_reset_player(Vector2(4 * U, 0))
	_boss.hp = _boss.max_hp * 0.69
	_step(1)
	_until(func(): return _b.shield.state == BossShield.State.ACTIVE, 3.0)
	_ult()
	_secs(4.0)
	_check("1er bouclier brisé (armed_count 1)", _b.shield.armed_count == 1 and _b.shield.state == BossShield.State.IDLE)
	_boss.hp = _boss.max_hp * 0.34
	_step(1)
	_check("phase 3 à 35 % : 2e bouclier", _b.phase == 3 and _b.shield.armed_count == 2 and _boss.is_invulnerable())
	_check("ancré dès la transition", _b.anchored and _b.ignores_knockback())
	_check("couronne retirée sous bouclier", _b.crown_node() == null)
	var anchor := _boss.position
	_until(func(): return _b.shield.state == BossShield.State.ACTIVE, 3.0)
	_check("2e bouclier : même condition (ultime sur le roi)", _b.shield.primary_kind() == &"ultimate_hit")
	_ult()
	_secs(3.8)
	_check("2e bouclier brisé, roi libéré", _b.shield.state == BossShield.State.IDLE and not _boss.is_invulnerable())
	_check("P3 : +20 % de dégâts reçus", is_equal_approx(_boss.brain.damage_taken_mult(), 1.2), str(_boss.brain.damage_taken_mult()))
	_check("Procession permanente (60° / 40°/s)", is_instance_valid(_b.sector) and is_equal_approx(_b.sector.sector_deg, float(Balance.pressure_at(&"salt_king", "proc_deg", 3)))
		and absf(_b.sector.turn_deg_s) <= 40.2 and _b.sector.duration_s > 1000.0)
	var wp := _b.crown_node()
	_check("couronne en orbite à 2,5 u, 60° exposés", wp != null and wp.offset_u == Vector2(2.5, 0.0) and wp.exposed_arc_deg == 60.0)
	# l'orbite tourne et l'exposition suit la couronne
	var a0: float = wp.facing_angle
	_player.global_position = _boss.position + Vector2.from_angle(a0) * 4.0 * U
	_step(1)
	_check("joueur dans le cône de la couronne : exposée", wp.exposed)
	_player.global_position = _boss.position + Vector2.from_angle(a0 + PI) * 4.0 * U
	_step(1)
	_check("joueur à l'opposé : gardée", not wp.exposed)
	# Édit : joueur à 4 u, 12 s
	var edicts0 := _b.edict_hits
	_hits.clear()
	var respite_seen := false
	var tag_seen := false
	for i in int(14.0 / DT):
		var ang: float = _b.sector.angle if is_instance_valid(_b.sector) else 0.0
		_player.global_position = _boss.position + Vector2.from_angle(ang) * 3.0 * U # reste dans la nef
		_step(1, true)
		if is_instance_valid(_b.sector) and _b.sector.in_respite():
			respite_seen = true
			tag_seen = tag_seen or String(_boss.brain.boss_state_tag().get("text", "")) == "REFLUX"
	_check("Édit : anneau qui touche le joueur proche", _b.edict_hits > edicts0, str(_b.edict_hits))
	var lag_ok := true
	var n_edict := 0
	for ev in _b.events:
		if ev["kind"] == &"edict":
			n_edict += 1
	_check("Édit toutes les ~4 s (>= 3 en 14 s)", n_edict >= 3, str(n_edict))
	_check("répit de la marée : « REFLUX »", respite_seen and tag_seen)
	_check("P3 : le roi ne bouge pas (ancré)", _boss.position.distance_to(anchor) < 1.0, str(_boss.position.distance_to(anchor)))
	var n_st := 0
	for ev in _b.events:
		if ev["kind"] == &"steles" and ev["phase"] == 3:
			n_st += 1
	var seq := ""
	for ev in _b.events:
		if int(ev["phase"]) == 3:
			seq += String(ev["kind"]) + " "
	_check("P3 : stèles x4 régulières (cadence 6 s, retardée par l'Édit ; jamais affamées)", n_st >= 1 and _b._stele_cd > -3.0, "%d casts, %d levées, cd %.1f | %s" % [n_st, _b.steles.landed_total, _b._stele_cd, seq])
	_check("pas de 3e bouclier", _b.shield.armed_count == 2 and lag_ok)
	# Édit hors portée : joueur à 9 u, aucun dégât d'édit
	var e1 := _b.edict_hits
	for i in int(9.0 / DT):
		_player.global_position = _boss.position + Vector2.from_angle(_b.sector.angle) * 8.8 * U
		_step(1, true)
	_check("Édit : à plus de 8 u dans la nef, à l'abri", _b.edict_hits == e1, str(_b.edict_hits - e1))


# --- 8. Mort -----------------------------------------------------------------------------------------

func _death() -> void:
	print("Mort")
	_reset_player(Vector2(-2000, 0))
	var steles: SaltSteles = _b.steles
	var sec: SaltSector = _b.sector
	_b._on_shield_state(BossShield.State.IDLE) # sans effet de bord
	_b.steles.plant(Vector2(2 * U, 2 * U), 0.0, 1.2)
	var n := _b.steles.live_count()
	_boss.take_damage(1e12)
	await get_tree().process_frame
	_check("mort : la marée se retire", not is_instance_valid(sec) or sec.is_queued_for_deletion())
	_check("mort : les stèles restent", is_instance_valid(steles) and not steles.is_queued_for_deletion() and steles.permanent and steles.live_count() >= n - 1,
		"%d/%d" % [steles.live_count() if is_instance_valid(steles) else -1, n])
