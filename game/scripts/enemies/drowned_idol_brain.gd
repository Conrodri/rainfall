class_name DrownedIdolBrain
extends RefCounted
## IA de l'Idole noyée (boss d'étage 1 façon raid, Terrasses noyées ; docs/Design_Boss_Raid.md §2.1).
## Créée par Enemy.activate_boss quand le skin du boss est « drowned_idol » (crochet à poser dans enemy.gd),
## appelée par Enemy.tick (branche BOSS_TIER). Boîte à outils : scripts/enemies/raid/ (BossShield + RaidOrb,
## FixateMark, SoftEnrage). Dégâts : Balance.BOSS_ATTACK_COEF[&"drowned_idol"]. Coups télégraphés face au joueur,
## dégâts à la frame d'impact (EnemyVisual.play_attack cale l'impact sur la fin du télégraphe).
##
## Statue votive agenouillée sur un socle de lotus (3,6 u), roue de prière, 3 cloches (+1 fêlée), eau cyan.
## Phases (Balance.BOSS_PHASE_THRESHOLDS : 70 % / 35 %) ; chaque passage de phase lève un bouclier d'eau
## (Balance.BOSS_SHIELDS : 2) rompu en ramassant les cloches jetées (3 puis 4), garde-fou 25 s sans fenêtre.
## - P1 « Offrande » : Paume (auto, cône 90° de 3 u) ; Carillon (3 anneaux de 3 / 6 / 9 u, épaisseur 0,8 u,
##   télégraphe commun puis 0,5 s d'écart : les couloirs entre anneaux sont sûrs) ; Chapelet (5 cercles de 2 u
##   du boss vers le joueur, le dernier sur lui, allumés toutes les 0,25 s).
## - Bouclier : seul le Chapelet, toutes les 4 s (BossShield.take_slow_spell) ; rupture = fenêtre sonnée 2,5 s, +30 %.
## - P2 « Mousson » : Carillon à 4 anneaux ; Digues (2 murets de terre 1 x 4 u, 8 s : bloquent le joueur ET
##   l'ombre d'une digue arrête les anneaux) ; Noria (fixation : 1 s de verrouillage, roue d'eau + pale de
##   8 u qui tourne de 180° en 2 s).
## - P3 « Crue de prière » : ancrée (immobile, +20 % de dégâts reçus), anneau continu toutes les 2,5 s (3 -> 9 u
##   en 1,2 s, télégraphe 0,9 s), Digues x3, Noria x2, Chapelet en spirale (6 cercles).
## Trace après la mort : les digues restent jusqu'à la fin de la charge du gros pilier (Floor1Hazards).
## v2 27/10/2026 (retour joueur : « trop simple à esquiver, quasi aucun impact ») : même dégâts, plus de pression.
## Toutes les valeurs de rythme/taille sont dans Balance.BOSS_PRESSURE[&"drowned_idol"] (docs §2.1) : recharges et
## armements raccourcis, anneaux décalés au hasard (le couloir de la fois d'avant ne sert plus), cercles de Chapelet
## en 3 files visant où le joueur VA, Noria plus rapide et plus nombreuse, anneau continu dès la P2. Attendre sous
## bouclier coûte : le garde-fou passe à 45 s, des anneaux supplémentaires partent toutes les 8 s sans progrès, et la
## chute au garde-fou soigne l'idole de 10 % et lâche une salve d'anneaux (BossShield.stall_pulse / backstop_reached).
##
## Placeholders : formes RecluseFx / EnemyTelegraph tant que le .tres (art/tools/night/_raid_drowned_idol.txt) n'est
## pas livré ; chaque extra (carillon_ring, dike, lotus_crack...) essaie d'abord l'anim du .tres.

enum S { CHASE, PALM, CARILLON, CHAPLET, DIKES, NORIA, STAGGER }
enum Spell { CARILLON, CHAPLET, DIKES, NORIA, SPIRAL }

const ID := &"drowned_idol"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const CYAN := Color(0.369, 0.784, 1.0) ## #5EC8FF : seul accent émissif
const BODY_GAIN := Color(1.3, 1.34, 1.36)
const SPEED_MULT := [1.0, 1.05, 0.0] ## P3 : ancrée
## Rythme, tailles et ordre des sorts : Balance.BOSS_PRESSURE[&"drowned_idol"] (v2 27/10/2026), lus par _k / _kp.
const LIGHT_ENERGY := [2.6, 3.2, 3.8]
const LIGHT_RADIUS := [1.2, 1.4, 1.5]
const LIGHT_LIFT_U := 1.8
# Carillon
const RING_SRC_R := 576.0 ## extra carillon_ring : cellule de 1152 px, rayon extérieur 576 px
const RING_FLASH_S := 0.4
# Chapelet
const CHAPLET_SIDE_RAD := 0.38 ## écart angulaire des files latérales (P2/P3)
const CHAPLET_MIN_FIRST_U := 1.5
# Digues
const DIKE_LIFE_S := 6.0 ## v2 27/10 : 6 s au lieu de 8 (abri moins durable)
const CRACKED_BELL_R_U := 8.0
const PADDY_SLOW := 0.8 ## rizière inondée sous une cloche tombée : -20 % de vitesse
const PADDY_R_U := 2.5 ## rayon autour de la cloche tombée où l'eau ralentit
const DIKE_LONG_U := 4.0
const DIKE_THICK_U := 1.0
const DIKE_SHADOW_PAD_U := 0.5 ## l'ombre d'abri : la ligne boss -> joueur doit croiser le muret élargi de 0,5 u
const DIKE_DIST_U := [4.0, 6.5] ## distance au boss des digues posées (bornée par celle du joueur)
const DIKE_SRC_PX := 256.0
# Noria
const NORIA_LOCK_MIN_S := 0.7
const NORIA_DISC_R_U := 1.5
# Anneau continu (P2 lent, P3 rapide) et impulsions d'attente sous bouclier
const P3_RING_FROM_U := 3.0
const P3_RING_TO_U := 9.0
const STALL_RING_GAP_S := 0.8 ## écart entre deux anneaux d'une même impulsion
const STALL_RING_MAX := 3

var e: Enemy
var vis: EnemyVisual
var shield: BossShield
var enrage: SoftEnrage
var pace: BossPace ## armement planté, impact, récupération immobile (scripts/enemies/boss_pace.gd)
var events: Array[Dictionary] = [] ## journal des coups (tests) : kind, phase, anim, frame, expect, lag
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var anchored := false
var ring_hits := 0 ## tests : anneaux qui ont touché le joueur
var rings_blocked := 0 ## tests : anneaux arrêtés par l'ombre d'une digue

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.4
var _spell_cd := 2.2
var _cycle := 0
var _clock := 0.0
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _teles: Array[EnemyTelegraph] = [] ## télégraphes du coup armé (paume)
var _rings: Array[Dictionary] = [] ## Carillon : {r, tele, fire_at, fired, manual}
var _circles: Array[Dictionary] = [] ## Chapelet : {pos, show_at, fire_at, tele, shown, manual}
var _dike_plan: Array[Dictionary] = [] ## Digues télégraphiées : {rect, tele}
var _dikes: Array[Dictionary] = [] ## Digues levées : {rect, node, zone}
var _noria: Array[Dictionary] = [] ## {mark, a0, lock_at, tele, locked}
var _cring: Array[Dictionary] = [] ## P3 : anneaux mobiles {r, node, hit}
var _cring_t := 0.0
var _ring_reverse := true
var _cring_tele: RecluseFx = null
var _stall: Array[Dictionary] = [] ## anneaux d'attente à venir {t, tele} (impulsions sous bouclier)
var _pvel := Vector2.ZERO ## vitesse lissée du joueur (px/s), pour viser où il va
var _pprev := Vector2.INF
var ring_jitter_scale := 1.0 ## tests : 0 = anneaux du Carillon sans décalage aléatoire
var ring_every_fired := 0 ## tests : anneaux continus lâchés
var stall_rings := 0 ## tests : anneaux d'attente lâchés
var _fx: Array[Dictionary] = []
var _hz: Floor1Hazards = null
var _lotus: Node2D = null


func _init(enemy: Enemy) -> void:
	e = enemy
	vis = enemy.visual as EnemyVisual
	pace = BossPace.new(enemy)
	_rng.randomize()
	_frames = EnemyVisual.boss_frames(ID)
	shield = BossShield.create(enemy)
	shield.state_changed.connect(_on_shield_state)
	shield.progressed.connect(_on_shield_progress)
	shield.stall_pulse.connect(_on_stall_pulse)
	shield.backstop_reached.connect(_on_backstop)
	enrage = SoftEnrage.create(enemy)
	if e._light != null:
		e._light.set_preset(&"boss_cerf")
		e._light.set_color(CYAN)
		e._light.position = Vector2(0.0, Iso.lift_logical(LIGHT_LIFT_U))
	if vis.body_sprite() != null:
		vis.body_sprite().self_modulate = BODY_GAIN
	_hz = Floor1Hazards.create(e, _frames, "Idol")
	_apply_phase_look()


## Libère boucliers, télégraphes, anneaux, roues, FX (mort, retour au pool). Mort pendant la charge du gros pilier :
## les digues restent (Floor1Hazards, trace).
func clear() -> void:
	if pace != null:
		pace.cancel()
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	if killed:
		Audio.play(&"enemy.idol_death.heavy", e.global_position)
	if shield != null:
		shield.clear()
	if enrage != null:
		enrage.clear()
	if is_instance_valid(_hz):
		if killed:
			for d in _dikes:
				var z: Variant = d.get("zone")
				if z is Dictionary:
					(z as Dictionary)["life"] = -1.0 # la digue reste jusqu'à la fin de la charge
			_hz.on_boss_dead()
		else:
			_hz.release()
	_hz = null
	_dikes.clear()
	_free_attack_nodes()
	for m in _noria:
		_free_noria(m)
	_noria.clear()
	for r in _cring:
		if is_instance_valid(r.get("node")):
			(r["node"] as Node).queue_free()
	_cring.clear()
	_free_stall()
	if is_instance_valid(_cring_tele):
		_cring_tele.queue_free()
	_cring_tele = null
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	if is_instance_valid(_lotus):
		_lotus.queue_free()
	_lotus = null
	for t in _teles:
		if is_instance_valid(t):
			t.queue_free()
	_teles.clear()
	if vis != null and is_instance_valid(vis) and vis.body_sprite() != null:
		vis.body_sprite().self_modulate = Color.WHITE
	if e != null and is_instance_valid(e) and is_instance_valid(e.telegraph):
		e.telegraph.modulate = Color.WHITE
	if e != null and is_instance_valid(e) and e._light != null:
		e._light.set_energy(1.0)
		e._light.set_radius_mult(1.0)
		e._light.set_flicker_override(-1.0)
		e._light.set_preset(&"boss")
		e._light.set_color(Color(0, 0, 0, 0))
		e._light.position = Vector2.ZERO


# --- Réglages de pression (Balance.BOSS_PRESSURE) -------------------------------------------

static func _k(key: String) -> Variant:
	return Balance.boss_pressure(ID, key)


static func _kp(key: String, phase: int) -> Variant:
	return Balance.pressure_at(ID, key, phase)


func palm_range_u() -> float:
	return float(_k("palm_range_u"))


func palm_half() -> float:
	return float(_k("palm_half"))


func ring_thick_u() -> float:
	return float(_k("ring_thick_u"))


func chaplet_r_u() -> float:
	return float(_k("chaplet_r_u"))


func noria_blade_u() -> float:
	return float(_k("noria_blade_u"))


func noria_width_u() -> float:
	return float(_k("noria_width_u"))


## Armement d'un sort : durée BossPace de la catégorie × le coefficient de l'idole, jamais sous le plancher (0,65 s).
func _windup(cat: StringName) -> float:
	var mult := 1.0
	if cat == &"heavy":
		mult = float(_k("windup_heavy_mult"))
	elif cat == &"spell":
		mult = float(_k("windup_spell_mult"))
	return maxf(BossPace.windup(cat, phase) * mult, float(_k("windup_floor_s")))


## Où sera le joueur dans `secs` (vitesse lissée), ramené sur le terrain praticable.
func _lead(ppos: Vector2, secs: float) -> Vector2:
	var v := _pvel.limit_length(6.0 * U)
	return _walkable(ppos + v * secs)


# --- Contrat Enemy (duck typing) ------------------------------------------------------

## Transition figée : bouclier en transition, ou transition sans bouclier (S.STAGGER).
func is_phase_transition() -> bool:
	return state == S.STAGGER or shield.state == BossShield.State.TRANSITION


func owns_motion() -> bool:
	return state == S.STAGGER or pace.planted() or shield.is_busy()


## Super-armure le temps d'un coup : un recul ferait glisser le boss planté.
func ignores_knockback() -> bool:
	return pace.planted() or shield.is_busy()


func is_invulnerable() -> bool:
	return shield.is_invulnerable()


func damage_taken_mult() -> float:
	return Balance.boss_damage_taken_mult(ID, phase) * shield.damage_taken_mult()


## Étiquette de la barre de boss : bouclier / fenêtre exposée, sinon enrage doux.
func boss_state_tag() -> Dictionary:
	var tag := shield.state_tag()
	if not tag.is_empty():
		return tag
	return enrage.state_tag()


func dike_count() -> int:
	return _live_dikes().size()


# --- Tick ---------------------------------------------------------------------------------

## Un pas d'IA. Retourne la vitesse de marche voulue (px/s logiques), appliquée par Enemy.
func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	if _pprev != Vector2.INF and delta > 0.0:
		_pvel = _pvel.lerp((ppos - _pprev) / delta, minf(delta * 8.0, 1.0))
	_pprev = ppos
	_ppos = ppos
	_clock += delta
	pace.tick(delta)
	shield.tick(delta)
	enrage.tick(delta, shield.freezes_enrage()) # après Enemy.fight_time += delta : horloge = temps vulnérable
	var ph: int = e.boss_phase()
	if ph > phase:
		_enter_phase(ph)
	_update_rings(player, ppos)
	_update_circles(player, ppos)
	_update_noria(player, ppos)
	_update_cring(delta, player, ppos)
	_update_stall(delta)
	_update_fx(delta)
	_update_paddy(player)
	_attack_cd -= delta
	_spell_cd -= delta
	_t += delta
	var pi := phase - 1
	match state:
		S.STAGGER:
			if _t >= _dur:
				state = S.CHASE
			return Vector2.ZERO
		S.PALM:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_palm(player, ppos)
			return Vector2.ZERO
		S.CARILLON:
			_progress_rings()
			if _t >= _dur:
				_resolve_carillon(player, ppos)
			return Vector2.ZERO
		S.CHAPLET:
			if _t >= _dur:
				_resolve_chaplet(player, ppos)
			return Vector2.ZERO
		S.DIKES:
			for d in _dike_plan:
				(d["tele"] as EnemyTelegraph).set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_dikes(player, ppos)
			return Vector2.ZERO
		S.NORIA:
			if _t >= _dur:
				_resolve_noria()
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering() or vis.is_attacking():
		_face(dir)
		return Vector2.ZERO
	if shield.is_busy():
		_face(dir)
		# Sous bouclier actif : seul le Chapelet, au rythme de BossShield (BOSS_SHIELD_SLOW_SPELL_S).
		if shield.state == BossShield.State.ACTIVE and shield.take_slow_spell() and dist < 16.0 * U:
			_start_spell(dir, ppos, Spell.CHAPLET)
		return Vector2.ZERO
	if phase >= 3 and not anchored:
		_anchor()
	if _spell_cd <= 0.0 and dist < 16.0 * U:
		_start_spell(dir, ppos)
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < palm_range_u() * U:
		_start_palm(dir)
		return Vector2.ZERO
	if SPEED_MULT[pi] > 0.0 and dist > palm_range_u() * U * 0.75:
		var go := path_dir if path_dir != Vector2.ZERO else dir
		_face(go)
		return go * e.speed_px * SPEED_MULT[pi]
	_face(dir)
	return Vector2.ZERO


# --- Phases et bouclier ---------------------------------------------------------------------

func _enter_phase(ph: int) -> void:
	var prev := phase
	_cancel()
	phase = ph
	_t = 0.0
	_cycle = 0
	_apply_phase_look()
	events.append({"kind": &"phase", "phase": ph})
	if BossShield.should_arm(prev, ph, shield.armed_count, ID):
		var n := 3 if shield.armed_count == 0 else 4
		shield.arm([{"kind": &"orbs", "count": n, "throw_r_u": 6.0 if n == 3 else 7.0,
			"radii_u": [] if n == 3 else [7.0, 7.0, 7.0, CRACKED_BELL_R_U], # 4e cloche = la fêlée de la nuque, la plus loin
			"spread_deg": 240.0 if n == 3 else 270.0, "label": "CLOCHES"}],
			{"backstop_s": float(_k("shield_backstop_s")), "stall_every_s": float(_k("shield_stall_every_s")),
			"backstop_heal_frac": Balance.RAID_STALL_HEAL_FRAC, "slow_spell_s": float(_k("shield_slow_spell_s"))})
		state = S.CHASE # le bouclier tient la transition (is_phase_transition)
	else:
		state = S.STAGGER
		_dur = 8.0 / 12.0 + 0.25 # trans_pN : 8 frames à 12 i/s
		e._sfx(&"telegraph.boss.heavy", 2.0, true)
	_spell_cd = maxf(_spell_cd, 1.5)
	_attack_cd = maxf(_attack_cd, 1.0)


func _on_shield_state(s: int) -> void:
	match s:
		BossShield.State.TRANSITION:
			_cancel()
			e._sfx(&"telegraph.boss.heavy", 2.0, true)
			LightRig.flash(e.global_position, &"boss_lightning", 0.6, {"color": CYAN, "radius": 1.6})
		BossShield.State.SETUP:
			_pose(&"throw")
			Audio.play(&"enemy.idol_bell_throw.medium", e.global_position)
		BossShield.State.ACTIVE:
			_pose(&"shield")
		BossShield.State.BREAKING:
			_pose(&"stun")
			_burst_fx()
		BossShield.State.EXPOSED:
			Audio.play(&"enemy.idol_stun.loop", e.global_position)
		BossShield.State.IDLE:
			_pose_clear()
			_spell_cd = maxf(_spell_cd, 1.2)
			_attack_cd = maxf(_attack_cd, 0.8)
			if phase >= 3 and not anchored:
				_anchor()


## Une cloche rendue : le son monte avec le compte, un trait d'eau lumineux monte de la cloche ramassée.
func _on_shield_progress(done: int, total: int) -> void:
	Audio.play(&"enemy.idol_bell_ring.medium", e.global_position, 0.0, 0.88 + 0.12 * float(mini(done, total) - 1))
	var col := RecluseFx.make(RecluseFx.Kind.COLUMN, Color(CYAN.r, CYAN.g, CYAN.b, 0.55), 1)
	col.radius = 3.0 * U
	col.width = 0.5 * U
	e.get_parent().add_child(col)
	col.global_position = e.global_position
	_fx.append({"node": col, "life": 0.6, "max": 0.6})
	events.append({"kind": &"bell", "phase": phase, "done": done, "total": total})


## Rizières : une cloche tombée dans l'eau peu profonde (« , ») ralentit de 20 % le joueur qui patauge à moins de
## PADDY_R_U d'elle (lecture du terrain, docs/Design_Boss_Raid.md §2). Sans eau sur la carte : aucun effet.
func _update_paddy(player: Node2D) -> void:
	if player == null or not is_instance_valid(player) or not shield.is_invulnerable() or not player.has_method(&"apply_slow"):
		return
	var wet: bool = false
	for o in shield.objects:
		if is_instance_valid(o) and o is RaidOrb and (o as RaidOrb).landed 				and (o as RaidOrb).global_position.distance_to(player.global_position) <= PADDY_R_U * RaidKit.U 				and RaidKit.in_shallow(e, (o as RaidOrb).global_position):
			wet = true
			break
	if wet and RaidKit.in_shallow(e, player.global_position):
		player.apply_slow(PADDY_SLOW, 0.3, self)


func _burst_fx() -> void:
	LightRig.flash(e.global_position, &"boss_lightning", 0.4, {"color": CYAN, "radius": 1.8})


## Poses tenues du .tres (shield_s, throw_s, stun_s) : seulement si EnemyVisual sait les relâcher (crochet clear_pose).
func _pose(name: StringName) -> void:
	if vis != null and vis.has_method(&"clear_pose"):
		vis.play_special(name)


func _pose_clear() -> void:
	if vis != null and vis.has_method(&"clear_pose"):
		vis.call(&"clear_pose")
	if vis != null:
		vis.set_action(&"idle")


func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	for t in _teles:
		if is_instance_valid(t):
			t.hide_telegraph()
	_free_attack_nodes()
	_cring_t = 0.0
	if is_instance_valid(_cring_tele):
		_cring_tele.queue_free()
	_cring_tele = null
	state = S.CHASE


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.1 if phase >= 3 else -1.0, 2.0)


## P3 : le socle se fend, l'idole s'ancre jusqu'à la mort (SPEED_MULT 0) ; +20 % de dégâts reçus (Balance).
func _anchor() -> void:
	anchored = true
	e._sfx(&"enemy.idol_anchor.heavy", 2.0, true)
	if _lotus == null and _frames != null and _frames.has_animation(&"lotus_crack"):
		var s := Floor1Fx.sprite(_frames, &"lotus_crack", "Idol_", 1.6, -1)
		s.scale = Vector2.ONE * (3.6 * U / 256.0)
		e.add_child(s)
		s.play(&"lotus_crack")
		_lotus = s


# --- Paume (auto) ---------------------------------------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func _start_palm(dir: Vector2) -> void:
	_attack_cd = float(_kp("auto_cd", phase))
	aim = dir
	_face(aim)
	state = S.PALM
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_cone(e.position, aim.angle(), palm_range_u() * U, palm_half(), EnemyTelegraph.Weight.LIGHT)
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _resolve_palm(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	Audio.play(&"enemy.idol_palm.medium", e.global_position)
	var v := ppos - e.position
	if player != null and v.length() <= palm_range_u() * U + PLAYER_R and absf(angle_difference(aim.angle(), v.angle())) <= palm_half() + 0.15:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"palm"))
		events.append({"kind": &"palm_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	_log(&"palm", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


# --- Sorts ------------------------------------------------------------------------------------

## `forced` : sort imposé (Chapelet sous bouclier, tests) ; sinon le suivant du cycle de la phase.
func _start_spell(dir: Vector2, ppos: Vector2, forced := -1) -> void:
	var cyc: Array = _kp("cycles", phase)
	var sp: int = forced if forced >= 0 else int(cyc[_cycle % cyc.size()])
	if forced < 0:
		_cycle += 1
	_spell_cd = float(_kp("spell_cd", phase))
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	_t = 0.0
	match sp:
		Spell.CARILLON:
			state = S.CARILLON
			_dur = _windup(&"heavy")
			pace.wind(&"heavy")
			vis.play_attack(&"cast_a", _dur, aim)
			_plan_rings()
			Audio.play(&"enemy.idol_carillon_warn.heavy", e.global_position)
		Spell.CHAPLET, Spell.SPIRAL:
			state = S.CHAPLET
			_dur = _windup(&"spell")
			pace.wind(&"spell")
			vis.play_attack(&"cast_b", _dur, aim)
			_plan_circles(ppos, sp == Spell.SPIRAL)
		Spell.DIKES:
			state = S.DIKES
			_dur = _windup(&"spell")
			pace.wind(&"spell")
			vis.play_attack(&"cast_b", _dur, aim)
			_plan_dikes(ppos, 3 if phase >= 3 else 2)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)
		Spell.NORIA:
			state = S.NORIA
			_dur = maxf(_windup(&"spell"), NORIA_LOCK_MIN_S)
			pace.wind(&"spell")
			vis.play_attack(&"cast_b", _dur, aim)
			_plan_noria(ppos, int(_kp("noria_count", phase)))
			e._sfx(&"telegraph.boss.heavy", 0.0, true)


# --- Carillon -----------------------------------------------------------------------------

func _plan_rings() -> void:
	var radii: Array = _kp("ring_radii", phase)
	# Décalage commun au Carillon : la position du couloir change à chaque lancer (lire le télégraphe, pas la mémoire).
	var jitter := (_rng.randf_range(-1.0, 1.0) * float(_k("ring_jitter_u")) if phase >= 2 else _rng.randf_range(-0.5, 0.5)) * ring_jitter_scale
	_ring_reverse = phase >= 2 and not _ring_reverse # P2/P3 : un Carillon sur deux part de l'extérieur
	var n := radii.size()
	for i in n:
		var r := maxf((float(radii[i]) + jitter) * U, (ring_thick_u() + 0.4) * U)
		var tele := RecluseFx.make(RecluseFx.Kind.RING_TELE, Color.WHITE, -1)
		tele.name = &"Idol_ring_tele"
		tele.inner = maxf(r - ring_thick_u() * U, 0.0)
		tele.radius = r
		e.get_parent().add_child(tele)
		tele.global_position = e.position
		_rings.append({"r": r, "tele": tele, "origin": e.position, "fire_at": INF, "fired": false,
			"idx": (n - 1 - i) if _ring_reverse else i})


func _progress_rings() -> void:
	for r in _rings:
		if not r["fired"] and is_instance_valid(r["tele"]):
			(r["tele"] as RecluseFx).set_param(float(r["r"]), -1.0, _t / _dur)


## Frame d'impact du Carillon : le premier anneau part, les autres toutes les ring_step_s.
func _resolve_carillon(player: Node2D, ppos: Vector2) -> void:
	_log(&"carillon", &"cast_a")
	for r in _rings:
		if r["fired"]:
			continue
		r["fire_at"] = _clock + float(_k("ring_step_s")) * float(r["idx"])
	for r in _rings:
		if int(r["idx"]) == 0 and not r["fired"]:
			_fire_ring(r, player, ppos)
	pace.strike(&"heavy", phase)
	state = S.CHASE


func _update_rings(player: Node2D, ppos: Vector2) -> void:
	var i := _rings.size() - 1
	while i >= 0:
		var r: Dictionary = _rings[i]
		if r["fired"]:
			_rings.remove_at(i)
		elif _clock >= float(r["fire_at"]):
			_fire_ring(r, player, ppos)
			_rings.remove_at(i)
		i -= 1


func _fire_ring(r: Dictionary, player: Node2D, ppos: Vector2) -> void:
	r["fired"] = true
	if is_instance_valid(r["tele"]):
		(r["tele"] as Node).queue_free()
	var rad := float(r["r"])
	var origin: Vector2 = r["origin"]
	Audio.play(&"enemy.idol_carillon.heavy", origin, 0.0, 0.85 + 0.1 * float(r["idx"]))
	_ring_flash(origin, rad)
	if player != null:
		var d := ppos.distance_to(origin)
		if d <= rad + PLAYER_R * 0.5 and d >= rad - ring_thick_u() * U - PLAYER_R * 0.5:
			if sheltered(origin, ppos):
				rings_blocked += 1
				events.append({"kind": &"ring_blocked", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			else:
				ring_hits += 1
				e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"carillon"))
				events.append({"kind": &"ring_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0, "r": rad})
	events.append({"kind": &"ring", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0, "r": rad, "at": _clock})


func _ring_flash(origin: Vector2, rad: float) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"carillon_ring"):
		var s := Floor1Fx.sprite(_frames, &"carillon_ring", "Idol_", 2.2, 0)
		s.scale = Vector2.ONE * (rad / RING_SRC_R)
		s.play(&"carillon_ring")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.BAND, Color(CYAN.r, CYAN.g, CYAN.b, 0.5), 0)
		f.radius = rad
		f.inner = maxf(rad - ring_thick_u() * U, 0.0)
		f.width = 3.0
		f.name = &"Idol_ring"
		n = f
	e.get_parent().add_child(n)
	n.global_position = origin
	_fx.append({"node": n, "life": RING_FLASH_S, "max": RING_FLASH_S})


# --- Chapelet ---------------------------------------------------------------------------

func _plan_circles(ppos: Vector2, spiral: bool) -> void:
	var step := float(_k("chaplet_step_s"))
	var lead := _lead(ppos, float(_k("lead_s"))) # le bout de la file vise où le joueur VA
	var base := (lead - e.position).angle()
	var dist := maxf(lead.distance_to(e.position), CHAPLET_MIN_FIRST_U * U * 2.0)
	var n: int = int(_k("spiral_count")) if spiral else int(_k("chaplet_count"))
	var lines: int = 1 if spiral or shield.is_busy() else int(_kp("chaplet_lines", phase))
	var k_all := 0
	for ln in lines:
		var off := 0.0 if lines == 1 else (float(ln) - float(lines - 1) * 0.5) * CHAPLET_SIDE_RAD * 2.0 / maxf(float(lines - 1), 1.0)
		for k in n:
			var pos: Vector2
			if spiral:
				pos = e.position + Vector2.from_angle(base + 0.9 * float(k)) * (2.0 + 1.4 * float(k)) * U
			else:
				pos = e.position + Vector2.from_angle(base + off) * dist * float(k + 1) / float(n)
			_add_circle(_walkable(pos), k, step, spiral)
			k_all += 1
	if not spiral:
		_add_circle(_walkable(ppos), n, step, false) # et un cercle sur sa position actuelle : rester planté coûte


func _add_circle(pos: Vector2, k: int, step: float, spiral: bool) -> void:
	var tele := EnemyTelegraph.new()
	tele.name = &"Idol_chaplet_tele"
	e.get_parent().add_child(tele)
	_circles.append({"pos": pos, "k": k, "show_at": _clock + step * float(k),
		"fire_at": _clock + _dur + step * float(k), "tele": tele, "shown": false, "fired": false, "spiral": spiral})


## Frame d'impact : le premier cercle éclate, les autres s'enchaînent toutes les chaplet_step_s.
func _resolve_chaplet(player: Node2D, ppos: Vector2) -> void:
	_log(&"spiral" if not _circles.is_empty() and bool(_circles[0]["spiral"]) else &"chaplet", &"cast_b")
	for c in _circles:
		if int(c["k"]) == 0 and not c["fired"]:
			_fire_circle(c, player, ppos)
	pace.strike(&"spell", phase)
	state = S.CHASE
	if shield.state == BossShield.State.ACTIVE:
		_pose(&"shield")


func _update_circles(player: Node2D, ppos: Vector2) -> void:
	var i := _circles.size() - 1
	while i >= 0:
		var c: Dictionary = _circles[i]
		if c["fired"]:
			_circles.remove_at(i)
			i -= 1
			continue
		var tele := c["tele"] as EnemyTelegraph
		if not c["shown"] and _clock >= float(c["show_at"]) and is_instance_valid(tele):
			c["shown"] = true
			tele.show_circle(c["pos"], chaplet_r_u() * U)
			Audio.play(&"enemy.idol_chaplet.light", c["pos"], -3.0, 0.9 + 0.08 * float(c["k"]))
		if c["shown"] and is_instance_valid(tele):
			tele.set_progress((_clock - float(c["show_at"])) / maxf(float(c["fire_at"]) - float(c["show_at"]), 0.01))
		if int(c["k"]) > 0 and _clock >= float(c["fire_at"]):
			_fire_circle(c, player, ppos)
			_circles.remove_at(i)
		i -= 1


func _fire_circle(c: Dictionary, player: Node2D, ppos: Vector2) -> void:
	c["fired"] = true
	if is_instance_valid(c["tele"]):
		(c["tele"] as Node).queue_free()
	var pos: Vector2 = c["pos"]
	LightRig.flash(pos, &"boss_lightning", 0.18, {"color": CYAN, "energy": 0.6, "radius": 0.7})
	var f := RecluseFx.make(RecluseFx.Kind.DISC, Color(CYAN.r, CYAN.g, CYAN.b, 0.35), 0)
	f.radius = chaplet_r_u() * U
	f.name = &"Idol_chaplet"
	e.get_parent().add_child(f)
	f.global_position = pos
	_fx.append({"node": f, "life": 0.35, "max": 0.35})
	if player != null and pos.distance_to(ppos) <= chaplet_r_u() * U + PLAYER_R:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"chaplet"))
		events.append({"kind": &"chaplet_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})


# --- Digues ----------------------------------------------------------------------------------

## Murets de 1 x 4 u alignés sur un axe du monde (le billboard du .tres n'est pas orientable), posés à 4-6,5 u du
## boss de part et d'autre de l'axe boss -> joueur, perpendiculaires au rayon (ils font de l'ombre au Carillon).
func _plan_dikes(ppos: Vector2, count: int) -> void:
	var to := ppos - e.position
	var base := to.angle()
	var d := clampf(to.length(), float(DIKE_DIST_U[0]) * U, float(DIKE_DIST_U[1]) * U)
	var offsets: Array = [-0.7, 0.7] if count == 2 else [-0.95, 0.0, 0.95]
	for o in offsets:
		var c := _walkable(e.position + Vector2.from_angle(base + o) * d)
		var radial := c - e.position
		var horizontal := absf(radial.y) >= absf(radial.x) # muret en travers du rayon
		var half := Vector2(DIKE_LONG_U, DIKE_THICK_U) * 0.5 * U if horizontal else Vector2(DIKE_THICK_U, DIKE_LONG_U) * 0.5 * U
		var rect := Rect2(c - half, half * 2.0)
		var tele := EnemyTelegraph.new()
		tele.name = &"Idol_dike_tele"
		e.get_parent().add_child(tele)
		var along := Vector2.RIGHT if horizontal else Vector2.DOWN
		tele.show_line(c - along * DIKE_LONG_U * 0.5 * U, along.angle(), DIKE_LONG_U * U, DIKE_THICK_U * U)
		_dike_plan.append({"rect": rect, "tele": tele, "horizontal": horizontal})


func _resolve_dikes(player: Node2D, ppos: Vector2) -> void:
	_log(&"dikes", &"cast_b")
	Audio.play(&"enemy.idol_dike.medium", e.global_position)
	for d in _dike_plan:
		if is_instance_valid(d["tele"]):
			(d["tele"] as Node).queue_free()
		var rect: Rect2 = d["rect"]
		_raise_dike(rect, bool(d["horizontal"]))
		var inflated := rect.grow(PLAYER_R * 0.5)
		if player != null and inflated.has_point(ppos):
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"dike")) # sous le muret qui jaillit
			events.append({"kind": &"dike_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	_dike_plan.clear()
	pace.strike(&"spell", phase)
	state = S.CHASE


## Dike : nœud (corps statique couche 1 qui bloque le joueur, obstacle NavField, visuel) enregistré comme zone
## `trace` de Floor1Hazards (durée DIKE_LIFE_S, fondu final).
func _raise_dike(rect: Rect2, horizontal: bool) -> void:
	var node := _IdolDike.new()
	node.name = &"Idol_dike"
	node.nav = e.nav
	node.oid = "idol_dike_%d_%d" % [e.get_instance_id(), Engine.get_physics_frames() + _dikes.size()]
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	cs.shape = rs
	body.add_child(cs)
	node.add_child(body)
	if _frames != null and _frames.has_animation(&"dike") and horizontal:
		var s := Floor1Fx.sprite(_frames, &"dike", "Idol_", 1.6, 0)
		s.scale = Floor1Fx.billboard(DIKE_LONG_U * U, DIKE_SRC_PX)
		node.add_child(s)
		s.play(&"dike")
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([-rect.size * 0.5, Vector2(rect.size.x, -rect.size.y) * 0.5,
			rect.size * 0.5, Vector2(-rect.size.x, rect.size.y) * 0.5])
		poly.color = Color(0.45, 0.38, 0.28)
		node.add_child(poly)
	(e.get_parent()).add_child(node)
	node.global_position = rect.get_center()
	if e.nav != null:
		e.nav.add_box_obstacle(node.oid, rect.get_center(), rect.size * 0.5)
	var entry := {"rect": rect, "node": node, "zone": null}
	if is_instance_valid(_hz):
		entry["zone"] = _hz.add_zone({"kind": &"dike", "shape": &"none", "pos": rect.get_center(), "node": node,
			"life": DIKE_LIFE_S, "trace": true})
	_dikes.append(entry)


func _live_dikes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i := _dikes.size() - 1
	while i >= 0:
		var n: Variant = _dikes[i]["node"]
		if not is_instance_valid(n) or (n as Node).is_queued_for_deletion():
			_dikes.remove_at(i)
		i -= 1
	for d in _dikes:
		out.append(d)
	return out


## L'ombre d'une digue : la ligne `origin` -> `p` croise un muret (élargi de DIKE_SHADOW_PAD_U) : les anneaux sont
## arrêtés. Vrai aussi pour un test avec une digue posée à la main (tests).
func sheltered(origin: Vector2, p: Vector2) -> bool:
	for d in _live_dikes():
		var rect: Rect2 = (d["rect"] as Rect2).grow(DIKE_SHADOW_PAD_U * U)
		if _segment_hits_rect(origin, p, rect):
			return true
	return false


static func _segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		var da := d.x if axis == 0 else d.y
		var aa := a.x if axis == 0 else a.y
		var lo := r.position.x if axis == 0 else r.position.y
		var hi := (r.position.x + r.size.x) if axis == 0 else (r.position.y + r.size.y)
		if absf(da) < 0.00001:
			if aa < lo or aa > hi:
				return false
		else:
			var ta := (lo - aa) / da
			var tb := (hi - aa) / da
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return false
	return true


## Tests : pose une digue sans passer par le sort.
func debug_add_dike(center: Vector2, horizontal := true) -> void:
	var half := Vector2(DIKE_LONG_U, DIKE_THICK_U) * 0.5 * U if horizontal else Vector2(DIKE_THICK_U, DIKE_LONG_U) * 0.5 * U
	_raise_dike(Rect2(center - half, half * 2.0), horizontal)


## Tests : lance un sort tout de suite (état CHASE hors bouclier).
func debug_cast(sp: int, ppos: Vector2) -> void:
	_start_spell((ppos - e.position).normalized(), ppos, sp)
	_spell_cd = 999.0 # un seul sort : le cycle ne reprend pas tout seul
	_attack_cd = maxf(_attack_cd, 999.0)


# --- Noria ----------------------------------------------------------------------------------

func _plan_noria(ppos: Vector2, count: int) -> void:
	for k in count:
		var at := ppos
		if k > 0:
			at = _walkable(ppos + Vector2.from_angle(_rng.randf() * TAU) * 4.0 * U)
		var mark := FixateMark.spawn(e, at, {"lock_s": _dur, "duration_s": float(_k("noria_turn_s")), "radius_u": NORIA_DISC_R_U,
			"tick_s": float(_k("noria_tick_s")), "coef": 0.0, "mode": &"none"})
		var entry := {"mark": mark, "a0": (e.position - mark.point).angle() - PI * 0.5, "lock_at": INF, "tele": null,
			"locked": false}
		mark.locked.connect(_on_noria_locked.bind(entry))
		mark.fired.connect(_on_noria_fired.bind(entry))
		mark.finished.connect(_on_noria_done.bind(entry))
		_noria.append(entry)


func _resolve_noria() -> void:
	_log(&"noria", &"cast_b")
	Audio.play(&"enemy.idol_noria.loop", e.global_position)
	pace.strike(&"spell", phase)
	state = S.CHASE


func _on_noria_locked(_m: FixateMark, entry: Dictionary) -> void:
	entry["locked"] = true
	entry["lock_at"] = _clock
	var mark := entry["mark"] as FixateMark
	var tele := EnemyTelegraph.new()
	tele.name = &"Idol_noria_tele"
	e.get_parent().add_child(tele)
	tele.show_line(mark.point, float(entry["a0"]), noria_blade_u() * U, noria_width_u() * U)
	tele.set_progress(1.0)
	entry["tele"] = tele


func _blade_angle(entry: Dictionary) -> float:
	var k := clampf((_clock - float(entry["lock_at"])) / float(_k("noria_turn_s")), 0.0, 1.0)
	return float(entry["a0"]) + float(_k("noria_sweep_rad")) * k


func _on_noria_fired(_m: FixateMark, entry: Dictionary) -> void:
	var pl := RaidKit.player_of(e)
	if pl == null:
		return
	var mark := entry["mark"] as FixateMark
	var v := pl.global_position - mark.point
	var hit := v.length() <= NORIA_DISC_R_U * U + PLAYER_R
	if not hit:
		var d := Vector2.from_angle(_blade_angle(entry))
		var along := v.dot(d)
		hit = along >= 0.0 and along <= noria_blade_u() * U + PLAYER_R and absf(v.cross(d)) <= noria_width_u() * 0.5 * U + PLAYER_R
	if hit:
		e._hit_player(pl, e.damage * Balance.boss_attack_coef(ID, &"noria"))
		events.append({"kind": &"noria_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})


func _on_noria_done(_m: FixateMark, entry: Dictionary) -> void:
	_free_noria(entry)
	_noria.erase(entry)


func _free_noria(entry: Dictionary) -> void:
	if is_instance_valid(entry.get("tele")):
		(entry["tele"] as Node).queue_free()
	var m: Variant = entry.get("mark")
	if is_instance_valid(m):
		(m as Node).queue_free()
	entry["tele"] = null


func _update_noria(_player: Node2D, _ppos: Vector2) -> void:
	for entry in _noria:
		var tele := entry.get("tele") as EnemyTelegraph
		if entry["locked"] and is_instance_valid(tele):
			var mark := entry["mark"] as FixateMark
			if is_instance_valid(mark):
				tele.global_position = mark.point
			tele.rotation = _blade_angle(entry)


# --- Phase 3 : anneau continu -------------------------------------------------------------

func _update_cring(delta: float, player: Node2D, ppos: Vector2) -> void:
	var every := float(_kp("ring_every_s", phase))
	var wind_s := float(_k("ring_wind_s"))
	if every > 0.0 and not shield.is_busy() and shield.state == BossShield.State.IDLE and state != S.STAGGER:
		_cring_t += delta
		var wind_from := every - wind_s
		if _cring_t >= wind_from:
			if not is_instance_valid(_cring_tele):
				_cring_tele = RecluseFx.make(RecluseFx.Kind.RING_TELE, Color.WHITE, -1)
				_cring_tele.name = &"Idol_cring_tele"
				_cring_tele.inner = (P3_RING_FROM_U - ring_thick_u()) * U
				_cring_tele.radius = P3_RING_FROM_U * U
				e.get_parent().add_child(_cring_tele)
				_cring_tele.global_position = e.position
				Audio.play(&"enemy.idol_carillon_warn.heavy", e.global_position, -3.0)
			_cring_tele.set_param(P3_RING_FROM_U * U, -1.0, (_cring_t - wind_from) / wind_s)
		if _cring_t >= every:
			_cring_t = 0.0
			if is_instance_valid(_cring_tele):
				_cring_tele.queue_free()
			_cring_tele = null
			_launch_cring()
			ring_every_fired += 1
			events.append({"kind": &"ring_p3", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	var speed := (P3_RING_TO_U - P3_RING_FROM_U) * U / float(_k("ring_sweep_s"))
	var i := _cring.size() - 1
	while i >= 0:
		var r: Dictionary = _cring[i]
		var origin: Vector2 = r["origin"]
		r["r"] = float(r["r"]) + speed * delta
		var rad := float(r["r"])
		var node := r["node"] as RecluseFx
		if is_instance_valid(node):
			node.set_param(rad)
		if not r["hit"] and player != null:
			var d := ppos.distance_to(origin)
			if d <= rad + PLAYER_R * 0.5 and d >= rad - ring_thick_u() * U - PLAYER_R * 0.5:
				if sheltered(origin, ppos):
					rings_blocked += 1
				else:
					r["hit"] = true
					ring_hits += 1
					e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"ring_p3"))
					events.append({"kind": &"ring_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0, "r": rad})
		if rad >= P3_RING_TO_U * U:
			if is_instance_valid(node):
				node.queue_free()
			_cring.remove_at(i)
		i -= 1


## Un anneau mobile part de l'idole (3 -> 9 u). Sert à l'anneau continu et aux impulsions d'attente.
func _launch_cring() -> void:
	var f := RecluseFx.make(RecluseFx.Kind.RING, Color(CYAN.r, CYAN.g, CYAN.b, 0.7), 0)
	f.name = &"Idol_cring"
	f.width = ring_thick_u() * U
	f.radius = P3_RING_FROM_U * U
	e.get_parent().add_child(f)
	f.global_position = e.position
	_cring.append({"r": P3_RING_FROM_U * U, "node": f, "hit": false, "origin": e.position})
	Audio.play(&"enemy.idol_carillon.heavy", e.global_position)


# --- Attendre sous bouclier coûte -------------------------------------------------------------

## Impulsion d'attente (aucune cloche ramassée depuis shield_stall_every_s) : n anneaux (3 au plus) à 0,8 s d'écart.
func _on_stall_pulse(n: int) -> void:
	for i in mini(n, STALL_RING_MAX):
		_queue_stall_ring(STALL_RING_GAP_S * float(i))
	events.append({"kind": &"stall", "phase": phase, "n": n})


## Garde-fou : l'idole s'est soignée (BossShield) ; salve finale de STALL_RING_MAX anneaux serrés avant la chute.
func _on_backstop() -> void:
	for i in STALL_RING_MAX:
		_queue_stall_ring(0.6 * float(i))
	events.append({"kind": &"backstop_penalty", "phase": phase})


func _queue_stall_ring(delay: float) -> void:
	var wind_s := float(_k("ring_wind_s"))
	var tele := RecluseFx.make(RecluseFx.Kind.RING_TELE, Color.WHITE, -1)
	tele.name = &"Idol_stall_tele"
	tele.inner = (P3_RING_FROM_U - ring_thick_u()) * U
	tele.radius = P3_RING_FROM_U * U
	e.get_parent().add_child(tele)
	tele.global_position = e.position
	_stall.append({"left": delay + wind_s, "wind": wind_s, "tele": tele})
	Audio.play(&"enemy.idol_carillon_warn.heavy", e.global_position, -3.0)


func _update_stall(delta: float) -> void:
	var i := _stall.size() - 1
	while i >= 0:
		var st: Dictionary = _stall[i]
		st["left"] = float(st["left"]) - delta
		var tele := st["tele"] as RecluseFx
		if is_instance_valid(tele):
			tele.set_param(P3_RING_FROM_U * U, -1.0, clampf(1.0 - float(st["left"]) / float(st["wind"]), 0.0, 1.0))
		if float(st["left"]) <= 0.0:
			if is_instance_valid(tele):
				tele.queue_free()
			_launch_cring()
			stall_rings += 1
			_stall.remove_at(i)
		i -= 1


func _free_stall() -> void:
	for st in _stall:
		if is_instance_valid(st.get("tele")):
			(st["tele"] as Node).queue_free()
	_stall.clear()


# --- Outils ------------------------------------------------------------------------------------

func _free_attack_nodes() -> void:
	for r in _rings:
		if is_instance_valid(r.get("tele")):
			(r["tele"] as Node).queue_free()
	_rings.clear()
	for c in _circles:
		if is_instance_valid(c.get("tele")):
			(c["tele"] as Node).queue_free()
	_circles.clear()
	for d in _dike_plan:
		if is_instance_valid(d.get("tele")):
			(d["tele"] as Node).queue_free()
	_dike_plan.clear()


func _update_fx(delta: float) -> void:
	var i := _fx.size() - 1
	while i >= 0:
		var f: Dictionary = _fx[i]
		f["life"] = float(f["life"]) - delta
		var n := f["node"] as CanvasItem
		if not is_instance_valid(n) or float(f["life"]) <= 0.0:
			if is_instance_valid(n):
				n.queue_free()
			_fx.remove_at(i)
		else:
			n.modulate.a = clampf(float(f["life"]) / float(f["max"]), 0.0, 1.0)
		i -= 1


func _walkable(p: Vector2) -> Vector2:
	return e.nav.resolve(p, PLAYER_R) if e.nav else p


## Journal d'impact : anim visible, sa frame, la frame d'impact attendue et le décalage du coup armé.
func _log(kind: StringName, action: StringName, expect := -1) -> void:
	var anim := vis.current_anim()
	var lag := 0.0
	if action in EnemyVisual.BOSS_ATTACK_BASES:
		lag = vis.strike_lag()
		var sf := vis.body_sprite().sprite_frames if vis.body_sprite() != null else null
		if sf != null and sf.has_animation(anim):
			var frac := vis.boss_impact_frac(action)
			expect = roundi(sf.get_frame_count(anim) * frac)
	events.append({"kind": kind, "phase": phase, "anim": anim, "frame": vis.current_frame(), "expect": expect,
		"lag": lag, "aim": aim, "dir4": vis.facing_dir4(), "from": e.position, "to": _ppos})


## Muret de terre : libère son obstacle NavField en quittant l'arbre (expiration, fin de charge, retour au pool).
class _IdolDike extends Node2D:
	var nav: NavField = null
	var oid := ""

	func _exit_tree() -> void:
		if nav != null and oid != "":
			nav.remove_obstacle(oid)
