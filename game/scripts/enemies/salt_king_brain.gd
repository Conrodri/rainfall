class_name SaltKingBrain
extends RefCounted
## IA du Roi de sel (boss d'étage 4, Cryptes noyées ; docs/Design_Boss_Raid.md §0, §1 et §2.3), boss façon raid.
## Créée par Enemy.activate_boss quand le skin du boss est « salt_king », appelée par Enemy.tick (branche
## BOSS_TIER). Même contrat que les autres cerveaux de boss d'étage (CrystalMotherBrain, RecluseBrain) : coups
## armés par BossPace, dégâts à la frame d'impact, seuils de phase 70 / 35 %. Le cerveau possède le déplacement
## (owns_motion toujours vrai) : l'orientation du roi (`_face_angle`, rotation LENTE en P2) est celle du sprite ET celle
## du point faible dans son dos.
## Boîte à outils : BossShield (2 boucliers, rupture = UN coup d'ultime, garde-fou 20 s, fenêtre « éclaté » 3 s / +35 %),
## SaltSector (SafeSector + abri des stèles), SaltSteles, WeakPoint (couronne), SoftEnrage.
##
## - P1 « La cour » (100-70 %) : Sceptre (ligne 1 x 4 u, 1,8 s, coef 1,0) ; Procession (nef sèche de 90° qui tourne à
##   30°/s sur 9 u, 6 s, marée coef 0,4 par 0,5 s, recharge 16 s) ; Stèles (4 en croix à 3 u du joueur, 1,0 s, coef 1,2).
## - Transition 2 (70 %) : bouclier ULTIMATE_HIT ; croûte de sel ; Stèles toutes les 5 s + Larmes de sel (6 monstres de
##   tier 1) toutes les 8 s ; l'ultime éclate la croûte : roi éclaté 3 s (+35 %). Garde-fou 20 s.
## - P2 « Marée noire » (70-35 %) : Procession 60° / 40°/s / 7 s ; Stèles x6 ; Couronne = point faible 2 u DANS LE DOS
##   (arc 120°, 5 % des PV, dégâts x2) ; brisée : roi sonné 2 s, elle se reforme 10 s plus tard.
## - Transition 3 (35 %) : idem transition 2 (l'ultime doit toucher le roi, la couronne n'est pas là).
## - P3 « Noyade » (35-0 %) : ancré sur le trône (+20 % de dégâts reçus) ; Édit (anneau 1 -> 8 u toutes les 4 s, 1,0 s
##   de télégraphe, coef 1,4) ; Procession permanente (60° / 40°/s, répit de 2 s toutes les 8 s : « REFLUX ») ; Stèles x4
##   toutes les 6 s ; couronne en orbite à 2,5 u (60° exposés, tournent avec elle, point faible actif en permanence).
## Trace après la mort : la marée se retire, les stèles restent.
## Sans sprites (consigne art/tools/night/_raid_salt_king.txt) : silhouette et effets provisoires ; chaque extra du
## .tres (stele, throne, throne_rise, salt_crust, crust_burst, edict_ring, tear_drop) remplace son repli dès livré.

enum S { CHASE, AUTO, PROCESSION, STELES, EDICT, STUN, SHIELDED }

const ID := &"salt_king"
const U := 64.0
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const CRYSTAL := Color(0.749, 0.957, 1.0) ## #BFF4FF, accent unique du biome
const SALT := Color(0.72, 0.77, 0.80) ## silhouette provisoire : sel gris perle (lisible de nuit)
const BODY_GAIN := Color(1.15, 1.18, 1.22)
## Par phase (index phase - 1)
const THRESHOLDS_DEFAULT := [0.70, 0.35]
const SPEED_MULT := [1.0, 1.0, 0.0] ## ~2,0 u/s ; P3 ancré
const TURN_RATE := [9.0, 1.1, 3.0] ## rad/s : P2 lent (le dos du roi se contourne), P3 assis
const KEEP_U := 2.5
const COEF := {&"scepter": 1.0, &"procession": 0.4, &"stele": 1.2, &"edict": 1.4} ## repli si Balance.BOSS_ATTACK_COEF l'ignore
const DAMAGE_TAKEN := [1.0, 1.0, 1.2] ## P3 ancré sur le trône : +20 %
# Sceptre (auto)
const AUTO_CD := 1.8
const AUTO_LEN_U := 4.0
const AUTO_W_U := 1.0
const AUTO_REACH_U := 5.2
# Procession (sort A)
const PROC_CD := [16.0, 16.0, 0.0]
const PROC_R_U := 9.0
const PROC_DEG := [90.0, 60.0, 60.0]
const PROC_TURN := [30.0, 40.0, 40.0]
const PROC_DUR := [6.0, 7.0, 1.0e9]
const PROC_WINDUP := 1.2
const PROC_CAST_U := 13.0
# Stèles (sort B)
const STELE_CD := [11.0, 9.0, 6.0]
const STELE_COUNT := [4, 6, 4]
const STELE_RING_U := 3.0
const STELE_OUTER_U := 5.0
const STELE_CAST_U := 13.0
const STELE_MIN_RISE_S := 1.0
# Bouclier (transitions 2 et 3)
const SHIELD_STELE_EVERY := 5.0
const SHIELD_STELE_FIRST := 1.5
const TEARS_EVERY := 8.0
const TEARS_FIRST := 3.0
const TEARS_COUNT := 6
const TEARS_FALL_S := 0.8
const TEARS_MAX_ALIVE := 12
const EXPOSED_S := 3.0
const EXPOSED_MULT := 1.35
# Couronne
const CROWN_HP_FRAC := 0.05
const CROWN_BACK_U := Vector2(-2.0, 0.0)
const CROWN_ORBIT_U := Vector2(2.5, 0.0)
const CROWN_ARC_DEG := [120.0, 120.0, 60.0]
const CROWN_ORBIT_TURN := 0.8 ## rad/s (P3)
const CROWN_STUN_S := 2.0
const CROWN_REGROW_S := 10.0
# Édit (P3)
const EDICT_CD := 4.0
const EDICT_R0_U := 1.0
const EDICT_R1_U := 8.0
const EDICT_SPEED_U := 6.0
const EDICT_W_U := 1.0
const EDICT_ANIM_S := 4.0 / 12.0 ## edict_s : impact à la frame 4 (12 fps)
# Ambiance
const TIDE_SND_EVERY := 3.0
const COURT_SND_EVERY := 4.0

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = [] ## journal des coups (tests) : kind, phase, anim, frame, expect, lag
var pace: BossPace
var shield: BossShield
var enrage: SoftEnrage
var steles: SaltSteles
var sector: SaltSector = null
var crown: WeakPoint = null
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var anchored := false
var crown_breaks := 0
var crown_regrow := 0.0
var tears_spawned := 0
var edict_hits := 0
var auto_hits := 0
var sector_count := 0 ## processions lancées (tests)

var _t := 0.0
var _dur := 0.0
var _auto_cd := 1.4
var _proc_cd := 3.0
var _stele_cd := 6.0
var _edict_cd := 3.0
var _haz_stele := 0.0
var _haz_tears := 0.0
var _stun_left := 0.0
var _face_angle := 0.0
var _orbit := 0.0
var _turn_sign := 1.0
var _edict_anim := false
var _edict_hit := false
var _wave_r := -1.0 ## rayon (px) de l'anneau de l'Édit en cours, < 0 = aucun
var _wave_fx: Node2D = null
var _tide_snd := 0.0
var _court_snd := 0.0
var _was_respite := false
var _ppos := Vector2.ZERO
var _player: Node2D = null
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _teles: Array[EnemyTelegraph] = []
var _tears: Array[Dictionary] = [] ## {pos, t, node}
var _tear_mobs: Array[Enemy] = []
var _fx: Array[Dictionary] = [] ## {node, life, max}
var _body: RecluseFx = null
var _throne: Node2D = null
var _crust: AnimatedSprite2D = null
var _ring: RecluseFx = null


func _init(enemy: Enemy) -> void:
	e = enemy
	vis = enemy.visual as EnemyVisual
	pace = BossPace.new(enemy)
	_rng.randomize()
	_frames = EnemyVisual.boss_frames(ID)
	shield = BossShield.create(e)
	shield.state_changed.connect(_on_shield_state)
	shield.broken.connect(_on_shield_broken)
	enrage = SoftEnrage.create(e)
	steles = SaltSteles.create(e)
	_face_angle = e._facing
	if e._light != null:
		e._light.set_preset(&"boss_cerf")
		e._light.set_color(CRYSTAL)
		e._light.position = Vector2(0.0, Iso.lift_logical(2.0))
	if vis.body_sprite() != null:
		vis.body_sprite().self_modulate = BODY_GAIN
	else:
		_build_body()
	_apply_phase_look()


## Libère tout (mort, retour au pool). Mort : la marée se retire, les stèles restent (trace), la cour est dissoute.
func clear() -> void:
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	if pace != null:
		pace.cancel()
	if shield != null:
		shield.clear()
	if enrage != null:
		enrage.clear()
	if is_instance_valid(sector):
		sector.release()
	sector = null
	if is_instance_valid(steles):
		if killed:
			steles.make_permanent()
		else:
			steles.release()
	if is_instance_valid(crown):
		crown.release()
	crown = null
	for t in _tears:
		if is_instance_valid(t["node"]):
			(t["node"] as Node).queue_free()
	_tears.clear()
	_tear_mobs.clear()
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	for n in [_wave_fx, _crust, _ring]:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_wave_fx = null
	_crust = null
	_ring = null
	if is_instance_valid(_throne) and not killed: # mort : le trône reste en décor
		_throne.queue_free()
	_throne = null
	for t in _teles:
		if is_instance_valid(t):
			t.queue_free()
	_teles.clear()
	if is_instance_valid(_body):
		_body.queue_free()
	_body = null
	if killed:
		_snd(&"enemy.salt_king_death.heavy")
	if vis != null and is_instance_valid(vis):
		vis.self_modulate = Color.WHITE
		vis.modulate = Color.WHITE
		if vis.body_sprite() != null:
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


# --- Contrat de cerveau (duck typing d'Enemy) ----------------------------------------------

## Le cerveau déplace le roi lui-même (marche, ancrage, orientation lente).
func owns_motion() -> bool:
	return true


## Super-armure : planté sur un coup, sous bouclier ou ancré, un recul ferait glisser le roi.
func ignores_knockback() -> bool:
	return anchored or pace.planted() or shield.is_busy()


func phase_thresholds() -> Array:
	return Balance.BOSS_PHASE_THRESHOLDS.get(ID, THRESHOLDS_DEFAULT)


func is_phase_transition() -> bool:
	return shield.state == BossShield.State.TRANSITION


func is_invulnerable() -> bool:
	return shield.is_invulnerable()


## Dégâts reçus : phase (P3 ancré +20 %) x bouclier (0 sous bouclier, +35 % fenêtre « éclaté »).
func damage_taken_mult() -> float:
	return float(DAMAGE_TAKEN[clampi(phase - 1, 0, 2)]) * shield.damage_taken_mult()


## Étiquette de la barre de boss : bouclier (avec la recharge restante de l'ultime), REFLUX, enrage.
func boss_state_tag() -> Dictionary:
	var tag := shield.state_tag()
	if not tag.is_empty():
		if tag.get("kind", &"") == &"shield" and shield.primary_kind() == &"ultimate_hit" and shield.is_invulnerable():
			var cd := ultimate_cooldown_left()
			if cd > 0.5:
				tag["text"] = "%s (%d s)" % [tag["text"], ceili(cd)]
		return tag
	if phase >= 3 and is_instance_valid(sector) and sector.in_respite():
		return {"text": "REFLUX", "color": RaidFx.CYAN, "kind": &"reflux", "progress": 0.0}
	return enrage.state_tag()


## Recharge restante (s) de l'ultime du joueur (0 si prêt ou inconnu) : affichée sur la croûte.
func ultimate_cooldown_left() -> float:
	var pl := RaidKit.player_of(e)
	var sc: Object = pl.get(&"spells") if pl != null else null
	if sc != null and sc.has_method(&"cooldown_remaining"):
		return float(sc.cooldown_remaining(ArdentKit.ULTIMATE_SLOT))
	return 0.0


func steles_node() -> SaltSteles:
	return steles


func tide_live() -> bool:
	return is_instance_valid(sector) and sector.is_live()


func crown_node() -> WeakPoint:
	return crown if is_instance_valid(crown) else null


# --- Tick ------------------------------------------------------------------------------------

func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	_player = player
	pace.tick(delta)
	shield.tick(delta)
	enrage.tick(delta, shield.freezes_enrage())
	steles.step(delta)
	_update_crown(delta)
	_update_wave(delta, player, ppos)
	_update_tears(delta)
	_update_fx(delta)
	_update_sounds(delta)
	_update_body(delta)
	_t += delta
	var ph := _phase_of(e.hp / maxf(e.max_hp, 1.0))
	if ph > phase:
		_enter_phase(ph)
	_turn_face(delta, dir)
	if shield.is_busy():
		return _tick_shield(delta)
	_auto_cd -= delta
	_proc_cd -= delta
	_stele_cd -= delta
	_edict_cd -= delta
	if phase >= 3 and not is_instance_valid(sector) and not _in_windup():
		_spawn_sector(true)
	match state:
		S.STUN:
			_stun_left -= delta
			if _stun_left <= 0.0:
				state = S.CHASE
				vis.set_action(&"idle")
			return Vector2.ZERO
		S.AUTO:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_release_auto(player, ppos)
			return Vector2.ZERO
		S.PROCESSION:
			if _t >= _dur:
				_log(&"procession", &"cast_a")
				pace.strike(&"spell", phase)
				state = S.CHASE
			return Vector2.ZERO
		S.STELES:
			if _t >= _dur:
				_log(&"steles", &"cast_b")
				pace.strike(&"spell", phase)
				state = S.CHASE
			return Vector2.ZERO
		S.EDICT:
			_tick_edict(delta)
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering() or vis.is_attacking():
		return Vector2.ZERO
	if phase >= 3:
		if _stele_cd <= 0.0 and dist < STELE_CAST_U * U:
			_start_steles(dir)
		elif _edict_cd <= 0.0:
			_start_edict()
		return Vector2.ZERO
	if _proc_cd <= 0.0 and dist < PROC_CAST_U * U:
		_start_procession(dir)
	elif _stele_cd <= 0.0 and dist < STELE_CAST_U * U:
		_start_steles(dir)
	elif _auto_cd <= 0.0 and dist < AUTO_REACH_U * U:
		_start_auto(dir)
	else:
		_walk(delta, dir, dist, path_dir)
	return Vector2.ZERO


func _in_windup() -> bool:
	return state == S.PROCESSION or state == S.STUN


func _phase_of(frac: float) -> int:
	var th := phase_thresholds()
	return 3 if frac <= float(th[1]) else (2 if frac <= float(th[0]) else 1)


func _walk(delta: float, dir: Vector2, dist: float, path_dir: Vector2) -> void:
	var pi := phase - 1
	if dist > KEEP_U * U and SPEED_MULT[pi] > 0.0:
		var go := path_dir if path_dir != Vector2.ZERO else dir
		var sm := 1.0 - e._slow_pct if e._slow_left > 0.0 else 1.0
		e._move_to(e.position + go * e.speed_px * float(SPEED_MULT[pi]) * sm * delta)
		vis.set_action(&"run")
	else:
		vis.set_action(&"idle")


## Orientation du roi : rotation bornée vers le joueur (P2 lente : son dos se contourne).
func _turn_face(delta: float, dir: Vector2) -> void:
	if dir.length_squared() < 0.0001:
		return
	var rate := float(TURN_RATE[clampi(phase - 1, 0, 2)])
	var target := dir.angle()
	var step := clampf(angle_difference(_face_angle, target), -rate * delta, rate * delta)
	if absf(step) < 0.0001:
		return
	_face_angle = wrapf(_face_angle + step, -PI, PI)
	e._facing = _face_angle
	vis.set_facing(_face_angle)


func _coef(k: StringName) -> float:
	if Balance.BOSS_ATTACK_COEF.has(ID):
		return Balance.boss_attack_coef(ID, k)
	return float(COEF.get(k, 1.0))


# --- Phases et boucliers ----------------------------------------------------------------------

func _enter_phase(ph: int) -> void:
	var prev := phase
	_cancel_attacks()
	phase = ph
	state = S.CHASE
	vis.set_phase(ph)
	if is_instance_valid(sector): # la marée se retire (la Procession repart au bon palier)
		sector.release()
		sector = null
	_release_crown()
	crown_regrow = 0.0
	if ph >= 3:
		anchored = true
		_build_throne()
	_apply_phase_look()
	events.append({"kind": &"phase", "phase": ph})
	if BossShield.should_arm(prev, ph, shield.armed_count, ID):
		shield.arm([{"kind": &"ultimate_hit", "hits": 1, "label": "FRAPPEZ AVEC L'ULTIME"}],
			{"exposed_s": EXPOSED_S, "exposed_mult": EXPOSED_MULT})
	else: # quota de boucliers atteint (ou phase sautée) : simple transition
		_after_shield()
	_snd(&"enemy.salt_king_throne.heavy" if ph >= 3 else &"enemy.salt_king_crust.heavy")


func _on_shield_state(s: int) -> void:
	match s:
		BossShield.State.TRANSITION:
			pace.cancel()
			_cancel_attacks()
			state = S.SHIELDED
			if is_instance_valid(sector):
				sector.release()
				sector = null
			_release_crown()
		BossShield.State.SETUP:
			vis.play_special(&"shield")
			_show_crust()
			_snd(&"enemy.salt_king_crust.heavy")
		BossShield.State.ACTIVE:
			_haz_stele = SHIELD_STELE_FIRST
			_haz_tears = TEARS_FIRST
			_court_snd = 0.0
		BossShield.State.BREAKING:
			_hide_crust()
			vis.play_special(&"crack")
			var burst := not shield.by_backstop
			_snd(&"enemy.salt_king_crust_burst.heavy" if burst else &"enemy.salt_king_crust_crack.light")
			_fx_at(&"crust_burst", e.position, 0.6, 1.2)
		BossShield.State.EXPOSED:
			vis.play_special(&"stun")
		BossShield.State.IDLE:
			_after_shield()


func _on_shield_broken(rewarded: bool) -> void:
	events.append({"kind": &"shield_broken", "phase": phase, "rewarded": rewarded, "backstop": shield.by_backstop})


## Fin d'un bouclier (ou transition sans bouclier) : la couronne revient, les cadences repartent.
func _after_shield() -> void:
	state = S.CHASE
	_auto_cd = maxf(_auto_cd, 1.0)
	_proc_cd = maxf(_proc_cd, 3.0)
	_stele_cd = maxf(_stele_cd, 2.5)
	_edict_cd = maxf(_edict_cd, 2.0)
	vis.set_action(&"idle")
	if phase >= 2:
		_spawn_crown()
	if phase >= 3:
		_spawn_sector(true)


func _tick_shield(delta: float) -> Vector2:
	state = S.SHIELDED
	if shield.state == BossShield.State.ACTIVE:
		_haz_stele -= delta
		_haz_tears -= delta
		if _haz_stele <= 0.0:
			_haz_stele = SHIELD_STELE_EVERY
			_plant_steles(int(STELE_COUNT[0]), STELE_MIN_RISE_S)
		if _haz_tears <= 0.0:
			_haz_tears = TEARS_EVERY
			_drop_tears()
	return Vector2.ZERO


func _cancel_attacks() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	for t in _teles:
		if is_instance_valid(t):
			t.hide_telegraph()
	_edict_anim = false
	_wave_r = -1.0
	if is_instance_valid(_wave_fx):
		_wave_fx.queue_free()
	_wave_fx = null


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy([2.4, 3.2, 3.8][pi])
		e._light.set_radius_mult([1.1, 1.3, 1.5][pi])
		e._light.set_flicker_override(0.12 if phase >= 3 else -1.0, 2.0)
	if _body != null:
		_body.glow = 0.4 + 0.3 * phase
		_body.inner = 1.0 if phase >= 2 else 0.0
		_body.queue_redraw()


# --- Sceptre (auto) -------------------------------------------------------------------------

func _start_auto(dir: Vector2) -> void:
	_auto_cd = AUTO_CD
	aim = dir
	state = S.AUTO
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color(1, 1, 1, 0.8)
	e.telegraph.show_line(e.position, aim.angle(), AUTO_LEN_U * U, AUTO_W_U * U)
	_snd(&"enemy.salt_king_scepter.medium", -3.0)


## Frame d'impact : le joueur dans la ligne de 1 x 4 u est touché.
func _release_auto(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	var rel := ppos - e.position
	var along := rel.dot(aim)
	if along >= -PLAYER_R and along <= AUTO_LEN_U * U + PLAYER_R and absf(rel.cross(aim)) <= AUTO_W_U * 0.5 * U + PLAYER_R:
		auto_hits += 1
		e._hit_player(player, e.damage * _coef(&"scepter"))
	_log(&"scepter", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


# --- Procession (sort A) --------------------------------------------------------------------

func _start_procession(dir: Vector2) -> void:
	var pi := phase - 1
	_proc_cd = float(PROC_CD[pi])
	aim = dir
	state = S.PROCESSION
	_t = 0.0
	_dur = BossPace.windup(&"spell", phase, PROC_WINDUP)
	pace.wind(&"spell")
	vis.play_attack(&"cast_a", _dur, Vector2.ZERO)
	_spawn_sector(false)
	sector_count += 1
	_snd(&"enemy.salt_king_procession_warn.heavy")


## Marée de sel sur toute la zone de charge (9 u) sauf la nef sèche. `permanent` : P3 (jamais de fin).
func _spawn_sector(permanent: bool) -> void:
	if is_instance_valid(sector):
		sector.release()
	var pi := phase - 1
	_turn_sign = -_turn_sign if _turn_sign != 0.0 and not permanent else 1.0
	var start := (_ppos - e.global_position).angle()
	sector = SaltSector.spawn_salt(e, e.global_position, {
		"radius_u": PROC_R_U, "sector_deg": PROC_DEG[pi], "turn_deg_s": float(PROC_TURN[pi]) * _turn_sign,
		"duration_s": PROC_DUR[pi] if not permanent else PROC_DUR[2], "tele_s": PROC_WINDUP,
		"angle": start}, steles)
	_tide_snd = 0.0
	_was_respite = false


# --- Stèles (sort B) ------------------------------------------------------------------------

func _start_steles(dir: Vector2) -> void:
	var pi := phase - 1
	_stele_cd = float(STELE_CD[pi])
	aim = dir
	state = S.STELES
	_t = 0.0
	_dur = BossPace.windup(&"spell", phase, STELE_MIN_RISE_S)
	pace.wind(&"spell")
	vis.play_attack(&"cast_b", _dur, dir)
	_plant_steles(int(STELE_COUNT[pi]), _dur)
	_snd(&"telegraph.boss.heavy")


## `count` stèles autour du joueur : croix à 3 u (4 premières), les suivantes à 5 u sur la diagonale.
func _plant_steles(count: int, rise_s: float) -> void:
	var base := _rng.randf() * TAU
	for k in count:
		var p: Vector2
		if k < 4:
			p = _ppos + Vector2.from_angle(base + k * PI * 0.5) * STELE_RING_U * U
		else:
			p = _ppos + Vector2.from_angle(base + PI * 0.25 + (k - 4) * PI) * STELE_OUTER_U * U
		if p.distance_to(e.position) < 1.4 * U: # jamais sous le roi
			continue
		steles.plant(p, maxf(rise_s, STELE_MIN_RISE_S), _coef(&"stele"))


# --- Larmes de sel (sous bouclier) ----------------------------------------------------------

func _drop_tears() -> void:
	var alive: Array[Enemy] = []
	for m in _tear_mobs:
		if is_instance_valid(m) and m.active:
			alive.append(m)
	_tear_mobs = alive
	var room := TEARS_MAX_ALIVE - _tear_mobs.size()
	for i in mini(TEARS_COUNT, room):
		var p := _ppos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(3.0, 7.0) * U
		p = RaidKit.place(e, p)
		var n: Node2D = null
		if _frames != null and _frames.has_animation(&"tear_drop"):
			n = _sprite(&"tear_drop", Iso.UNSQUASH * Iso.SPRITE_K, 10, 1.6)
			n.play(&"tear_drop")
		else:
			n = RecluseFx.make(RecluseFx.Kind.STREAK, Color(SALT, 0.9), 10)
			(n as RecluseFx).radius = 3.0 * U
			(n as RecluseFx).width = 6.0
		n.name = &"SaltKing_tear"
		e.get_parent().add_child(n)
		n.position = p
		_tears.append({"pos": p, "t": TEARS_FALL_S, "node": n})
	_snd(&"enemy.salt_king_tears.medium")


func _update_tears(delta: float) -> void:
	var i := _tears.size() - 1
	while i >= 0:
		var t: Dictionary = _tears[i]
		t["t"] = float(t["t"]) - delta
		if float(t["t"]) <= 0.0:
			var d := RaidKit.director_of(e)
			if d != null:
				var m := d.spawn_enemy(1, t["pos"]) as Enemy
				if m != null:
					_tear_mobs.append(m)
					tears_spawned += 1
			if is_instance_valid(t["node"]):
				(t["node"] as Node).queue_free()
			_tears.remove_at(i)
		i -= 1


# --- Couronne (point faible) ---------------------------------------------------------------------

func _spawn_crown() -> void:
	if is_instance_valid(crown) or phase < 2 or shield.is_busy():
		return
	var pi := phase - 1
	crown = WeakPoint.attach(e, CROWN_BACK_U if phase < 3 else CROWN_ORBIT_U, CROWN_HP_FRAC, float(CROWN_ARC_DEG[pi]), _on_crown_broken)
	crown.facing_angle = _crown_angle()
	crown.step(0.0)


func _crown_angle() -> float:
	return _face_angle if phase < 3 else _orbit


func _update_crown(delta: float) -> void:
	if crown_regrow > 0.0 and not shield.is_busy():
		crown_regrow -= delta
		if crown_regrow <= 0.0:
			_spawn_crown()
	if phase >= 3:
		_orbit = wrapf(_orbit + CROWN_ORBIT_TURN * delta, -PI, PI)
	if is_instance_valid(crown):
		crown.facing_angle = _crown_angle()
		crown.step(0.0)


func _on_crown_broken(_w: Node) -> void:
	crown = null
	crown_breaks += 1
	crown_regrow = CROWN_REGROW_S
	_snd(&"enemy.salt_king_crown_break.medium")
	_fx_at(&"crown_break", e.position, 0.6, 1.0)
	events.append({"kind": &"crown_break", "phase": phase})
	if not shield.is_busy():
		_start_stun(CROWN_STUN_S)


func _release_crown() -> void:
	if is_instance_valid(crown):
		crown.release()
	crown = null


func _start_stun(s: float) -> void:
	_cancel_attacks()
	state = S.STUN
	_stun_left = s
	vis.play_special(&"stun")


# --- Édit (P3) ----------------------------------------------------------------------------

func _start_edict() -> void:
	_edict_cd = EDICT_CD
	state = S.EDICT
	_t = 0.0
	_dur = BossPace.windup(&"heavy", phase, 1.0)
	_edict_anim = false
	_edict_hit = false
	pace.wind(&"heavy")
	e.telegraph.modulate = Color(1, 1, 1, 0.85)
	e.telegraph.show_circle(e.position, EDICT_R1_U * U)
	_snd(&"telegraph.boss.heavy", 0.0)


func _tick_edict(_delta: float) -> void:
	e.telegraph.set_progress(_t / _dur)
	if not _edict_anim and _t >= _dur - EDICT_ANIM_S:
		_edict_anim = true
		vis.play_special(&"edict")
	if _t >= _dur:
		e.telegraph.hide_telegraph()
		e.telegraph.modulate = Color.WHITE
		_wave_r = EDICT_R0_U * U
		_edict_hit = false
		_make_wave_fx()
		_log(&"edict", &"edict")
		_snd(&"enemy.salt_king_edict.heavy")
		pace.strike(&"heavy", phase)
		state = S.CHASE


## Anneau 1 -> 8 u : touche une fois le joueur qu'il traverse.
func _update_wave(delta: float, player: Node2D, ppos: Vector2) -> void:
	if _wave_r < 0.0:
		return
	_wave_r += EDICT_SPEED_U * U * delta
	if not _edict_hit and player != null:
		var d := ppos.distance_to(e.position)
		if d <= EDICT_R1_U * U + PLAYER_R and absf(d - _wave_r) <= EDICT_W_U * 0.5 * U + PLAYER_R: # au-delà de 8 u : à l'abri
			_edict_hit = true
			edict_hits += 1
			e._hit_player(player, e.damage * _coef(&"edict"))
	if is_instance_valid(_wave_fx):
		_wave_fx.position = e.position
		if _wave_fx is RecluseFx:
			(_wave_fx as RecluseFx).set_param(_wave_r)
		else:
			_wave_fx.scale = Vector2.ONE * (_wave_r / (EDICT_R1_U * U)) * Vector2(1.0, Iso.UNSQUASH.y)
	if _wave_r >= EDICT_R1_U * U + PLAYER_R:
		_wave_r = -1.0
		if is_instance_valid(_wave_fx):
			_wave_fx.queue_free()
		_wave_fx = null


func _make_wave_fx() -> void:
	if is_instance_valid(_wave_fx):
		_wave_fx.queue_free()
	if _frames != null and _frames.has_animation(&"edict_ring"):
		var s := AnimatedSprite2D.new()
		s.sprite_frames = _frames
		s.animation = &"edict_ring"
		s.light_mask = 0
		s.material = EnemyTelegraph.unshaded_material()
		s.z_index = 5
		s.play(&"edict_ring")
		_wave_fx = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.RING, Color(SALT, 0.9), 5)
		f.width = EDICT_W_U * U * 0.5
		f.color2 = CRYSTAL
		f.radius = EDICT_R0_U * U
		_wave_fx = f
	_wave_fx.name = &"SaltKing_edict"
	e.get_parent().add_child(_wave_fx)
	_wave_fx.position = e.position


# --- Effets et décor (provisoires tant que le .tres n'est pas livré) ------------------------------

func _build_body() -> void:
	_body = RecluseFx.make(RecluseFx.Kind.BODY_MOTHER, SALT, 0)
	_body.name = &"SaltKing_body"
	_body.color2 = CRYSTAL
	e.add_child(_body)
	vis.self_modulate = Color(1, 1, 1, 0) # hexagone de repli masqué


func _update_body(_delta: float) -> void:
	if _body == null:
		return
	var fl := 1.0 if e.is_flashing() else 0.0
	if absf(fl - _body.progress) > 0.01:
		_body.progress = fl
		_body.queue_redraw()
	_body.position = vis.position


## Trône de sel monté du lac (P3) : sprite `throne` / `throne_rise` du .tres, sinon disque provisoire.
func _build_throne() -> void:
	if is_instance_valid(_throne):
		return
	if _frames != null and _frames.has_animation(&"throne"):
		var s := _sprite(&"throne", Iso.UNSQUASH * Iso.SPRITE_K, -1, 1.4)
		var tex := _frames.get_frame_texture(&"throne", 0)
		if tex != null:
			s.offset = Vector2(0.0, -tex.get_height() * 0.5)
		s.play(&"throne")
		_throne = s
		_fx_at(&"throne_rise", e.position, 1.0, 1.0)
	else:
		var f := RecluseFx.make(RecluseFx.Kind.DISC, Color(SALT, 0.5), -1)
		f.radius = 1.6 * U
		f.color2 = CRYSTAL
		f.width = 3.0
		_throne = f
	_throne.name = &"SaltKing_throne"
	e.get_parent().add_child(_throne)
	_throne.position = e.position


func _show_crust() -> void:
	if is_instance_valid(_crust) or _frames == null or not _frames.has_animation(&"salt_crust"):
		return
	_crust = _sprite(&"salt_crust", Iso.UNSQUASH * Iso.SPRITE_K, 4, 1.4)
	var tex := _frames.get_frame_texture(&"salt_crust", 0)
	if tex != null:
		_crust.offset = Vector2(0.0, -tex.get_height() * 0.5)
	_crust.pause()
	e.add_child(_crust)


func _hide_crust() -> void:
	if is_instance_valid(_crust):
		_crust.queue_free()
	_crust = null


## Éclat posé au sol / billboard (crust_burst, throne_rise, crown_break) : sprite du .tres, sinon colonne de lumière.
func _fx_at(anim: StringName, pos: Vector2, life: float, size_u: float) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(anim):
		var s := _sprite(anim, Iso.UNSQUASH * Iso.SPRITE_K, 6, 2.0)
		var tex := _frames.get_frame_texture(anim, 0)
		if tex != null:
			s.offset = Vector2(0.0, -tex.get_height() * 0.5)
		s.play(anim)
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.COLUMN, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.7), 6)
		f.radius = -Iso.lift_logical(2.0 * size_u)
		f.width = 1.2 * size_u * U
		f.color2 = Color(1, 1, 1, 0.95)
		n = f
	n.name = StringName("SaltKing_" + String(anim))
	e.get_parent().add_child(n)
	n.position = pos
	_fx.append({"node": n, "life": life, "max": life})


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
	if is_instance_valid(_crust): # croûte : 3 états (intacte, fissurée, prête à céder) x 6 frames
		var st := 0 if shield.cracks <= 0 else (1 if shield.cracks < 3 else 2)
		_crust.frame = mini(st * 6 + int(_t * 8.0) % 6, _crust.sprite_frames.get_frame_count(&"salt_crust") - 1)


func _update_sounds(delta: float) -> void:
	if tide_live():
		_tide_snd -= delta
		if _tide_snd <= 0.0:
			_tide_snd = TIDE_SND_EVERY
			_snd(&"enemy.salt_king_tide.loop", -4.0)
		var rest := sector.in_respite()
		if rest and not _was_respite:
			_snd(&"enemy.salt_king_reflux.medium")
		_was_respite = rest
	if shield.state == BossShield.State.ACTIVE:
		_court_snd -= delta
		if _court_snd <= 0.0:
			_court_snd = COURT_SND_EVERY
			_snd(&"amb.salt_court", -6.0)


# --- Outils ---------------------------------------------------------------------------------

func _snd(id: StringName, vol_db := 0.0) -> void:
	if e != null and is_instance_valid(e):
		Audio.play(id, e.global_position, vol_db)


func _sprite(anim: StringName, sc: Vector2, z: int, energy: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = StringName("SaltKing_" + String(anim))
	EmissiveOverlay.apply(s, _frames, energy)
	s.animation = anim
	s.scale = sc
	s.z_index = z
	return s


## Journal d'impact (voir RecluseBrain._log).
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
