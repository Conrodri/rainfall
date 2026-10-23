class_name RainSowerBrain
extends RefCounted
## IA du Semeur de pluie (boss final unique, étage 5 « La Source » ; docs/Design_Etages.md §4). Créée par
## Enemy.activate_boss quand le skin du boss est « rain_sower » (boss d'étage dont floor_boss = rain_sower,
## appelé par l'interaction sur le paratonnerre-mère), appelée par Enemy.tick (branche BOSS_TIER). Contrat
## CerfBrain / SonneurBrain : coups télégraphiés face au joueur, sprite en 4 orientations e/s/w/n
## (auto/spell_a/spell_b_<dir>), dégâts à la frame d'impact. Dégâts : Balance.BOSS_ATTACK_COEF[&"rain_sower"] ;
## dégâts de base 32 (Balance.BOSS_DMG_MULT, appliqué ici à l'activation ; PV ×2 par Pillar.setup_final) ;
## silhouette 4,5 u (rayon de collision 1,8 u). Sans sprites : silhouette et effets dessinés provisoires
## (RecluseFx), chaque extra du .tres (intro, rain_column, raindrop, splash, wave_front, flood_water,
## mist_band, lightning, ground_scorch, cross_beam) remplace son repli dès qu'il est livré.
##
## Le centre de l'arène = le paratonnerre-mère (gros pilier le plus proche du point d'apparition ; sinon
## méta `arena_center` du Director ; sinon le point d'apparition).
## Entrée : le Semeur descend dans la colonne de pluie (2,2 s, intouchable par ses coups, sans attaquer).
## Phases (PV, Enemy.boss_phase) : 1 > 70 % > 2 > 35 % > 3 (Balance.BOSS_PHASE_THRESHOLDS) ; transitions mises en scène (boss figé).
## - P1 « Averse » : fouet de chaîne (auto, ligne 1,2 × 5,5 u) ; Averse (spell_a : 6 cercles de 2 u autour
##   du joueur, un sur lui, gouttes qui tombent ; coef 1,3) ; Vague (spell_b : couloir de 2 × 14 u vers le
##   joueur, puis le front d'eau le parcourt à 14 u/s ; s'écarter du couloir ; coef 1,5).
## - Transition 2 « la crue monte » : l'eau du bassin monte jusqu'à 6 u autour du paratonnerre.
## - P2 « Crue » : bassin infranchissable (le joueur qui y entre est repoussé et se noie, 0,3 par 0,5 s),
##   anneau de brume au bord (au-delà de 15 u : ralenti) : l'arène rétrécit ; toutes les 7 s la crue
##   déborde (anneau de 3 u au bord de l'eau, 1,2 s, coef 1,2) ; Averse ×8 ; Vague en éventail de 3 couloirs.
## - Transition 3 « l'ancrage » : le Semeur glisse jusqu'au paratonnerre, l'eau reflue vers lui, la foudre
##   frappe le paratonnerre (colonne de lumière sur le boss pour toute la phase).
## - P3 « Orage » : ancré (immobile, +20 % de dégâts reçus = fenêtre de DPS) ; 4 lignes en croix (1 × 12 u,
##   22°/s, 0,45 par 0,5 s) ; foudre sur le joueur toutes les 4 s (cercle de 2 u, coef 2,5) ; tourbillon de
##   chaînes si on colle (disque de 3,5 u, 0,8 s, coef 1,1) ; Averse ×6. SURPRISE : toutes les 10 s,
##   « Rafale » : 4 lignes fantômes apparaissent à +45° (télégraphe 1 s), puis la croix y saute d'un coup.
## Mort : la pluie s'arrête (éclair, rayons de lumière dans le puits).

enum S { INTRO, CHASE, LASH, RAIN, WAVE_WIND, WAVE_RUN, WHIRL, STAGGER }
enum Spell { RAIN, WAVE }

const ID := &"rain_sower"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const RADIUS_U := 1.8
const DROP := Color(0.91, 0.97, 1.0) ## cœur-goutte de cristal blanc, accent unique
const WATER := Color(0.369, 0.784, 1.0) ## #5EC8FF : zone persistante (palette des télégraphes)
const BRONZE := Color(0.44, 0.38, 0.30) ## silhouette provisoire : bronze noirci relevé (lisible de nuit)
## Par phase (index phase - 1)
const SPEED_MULT := [1.0, 1.1, 0.0]
const AUTO_CD := [2.0, 1.8, 2.4]
const SPELL_CD := [4.4, 4.0, 5.5]
const LIGHT_ENERGY := [3.6, 4.2, 5.2]
const LIGHT_RADIUS := [1.5, 1.6, 1.9]
const LIGHT_LIFT_U := 2.4
const FEET_ENERGY := [2.4, 2.8, 3.4]
const HEART_ENERGY := [1.6, 2.2, 3.0]
const HEART_LIFT_U := 2.3
const BODY_GAIN := Color(1.3, 1.26, 1.2)
# Entrée
const INTRO_S := 2.2
const COLUMN_H_U := 10.0
# Fouet de chaîne (auto)
const LASH_LEN_U := 5.5
const LASH_W_U := 1.2
# Armements et récupérations : BossPace (Balance.BOSS_PACE_*) ; fouet = auto, averse et vague = sorts.
# Averse (spell_a)
const RAIN_COUNT := [6, 8, 6]
const RAIN_R_U := 1.0
const RAIN_SPREAD_U := 6.0
const RAIN_GAP_U := 0.5
const RAIN_FALL_S := 0.45
const RAIN_FALL_H_U := 9.0
# Vague (spell_b)
const WAVE_LEN_U := 14.0
const WAVE_W_U := 2.0
const WAVE_SPEED_U := 14.0
const WAVE_BAND_U := 1.2
const WAVE_FAN := [[0.0], [-0.42, 0.0, 0.42]] ## couloirs (rad) par phase 1, 2
# Crue (P2)
const FLOOD_R_U := 6.0
const FLOOD_RISE_S := 1.5
const DROWN_TICK := 0.5
const DROWN_PUSH_U := 3.5 ## u/s vers le bord
const MIST_R_U := 15.0
const MIST_W_U := 9.0
const MIST_TICK := 0.5
const SURGE_EVERY := 7.0
const SURGE_FIRST := 3.0
const SURGE_W_U := 3.0
const SURGE_WINDUP := 1.2
const SURGE_RUN_S := 0.3
# Ancrage et orage (P3)
const ANCHOR_S := 2.0
const ANCHOR_OFFSET_U := Vector2(0.0, 1.6) ## devant le paratonnerre (y logique = bas de l'écran) : jamais caché derrière lui
const CROSS_LINES := 4
const CROSS_LEN_U := 12.0
const CROSS_W_U := 1.0
const CROSS_TURN := 0.384 ## 22°/s
const CROSS_TICK := 0.5
const CROSS_ALPHA := 0.55
const GUST_EVERY := 10.0
const GUST_WARN_S := 1.0
const GUST_STEP := PI / 4.0
const LIGHTNING_EVERY := 4.0
const LIGHTNING_FIRST := 2.0
const LIGHTNING_WINDUP := 1.0
const LIGHTNING_R_U := 1.0
const WHIRL_R_U := 3.5
const WHIRL_WINDUP := 0.8 ## plancher propre (cercle de 3,5 u autour d'elle) au-dessus de l'auto BossPace
const SCORCH_LIFE := 6.0

static var deaths := 0 ## morts mises en scène (tests)

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = []
var phase := 1
var state := S.INTRO
var aim := Vector2.RIGHT
var center := Vector2.ZERO
var anchor := Vector2.ZERO ## point d'ancrage (P3) : juste devant le paratonnerre, pour rester lisible devant lui
var flood_r := 0.0 ## rayon courant de l'eau infranchissable (px logiques)
var gusts := 0
var pace: BossPace ## armement planté, impact, récupération immobile (scripts/enemies/boss_pace.gd)

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.0
var _spell_cd := 1.6
var _cycle := 0
var _stagger_from := Vector2.ZERO
var _flood_from := 0.0
var _flood_to := 0.0
var _drown_tick := 0.0
var _mist_tick := 0.0
var _surge_cd := 0.0
var _surge: Dictionary = {} ## {t, fx, hit, run}
var _cross_angle := 0.0
var _cross_tick := 0.0
var _gust_t := 0.0
var _lightning_cd := 0.0
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _feet: LightRig.Handle = null
var _heart: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = []
var _drops: Array[Dictionary] = [] ## {pos, tele, spr}
var _lanes: Array[Dictionary] = [] ## {angle, tele, front, hit}
var _wave_t := 0.0
var _wave_hit := false
var _strikes: Array[Dictionary] = [] ## {pos, t, tele}
var _cross: Array[Dictionary] = [] ## {tele, beam, ghost}
var _fx: Array[Dictionary] = [] ## {node, life, max}
var _body: RecluseFx = null
var _flood: Node2D = null
var _mist: Array[Node2D] = []
var _column: Node2D = null


func _init(enemy: Enemy) -> void:
	e = enemy
	vis = enemy.visual as EnemyVisual
	pace = BossPace.new(enemy)
	_rng.randomize()
	_frames = EnemyVisual.boss_frames(ID)
	# boss final : dégâts de base 32 (étage 28), silhouette 4,5 u ; ses PV ×2 viennent du paratonnerre-mère
	# (Pillar.setup_final). Un futur kind &"final" aurait ses propres bases dans Balance : pas remultiplié.
	if e.boss_kind == &"etage":
		e.damage *= Balance.boss_dmg_mult(ID)
	e.set_body_radius(RADIUS_U * U)
	vis.configure(e.tier, e.radius_px, true, e.variant, ID, false)
	center = _find_center()
	anchor = center + ANCHOR_OFFSET_U * U
	if e._light != null:
		e._light.set_preset(&"boss_cerf")
		e._light.set_color(DROP)
		e._light.position = Vector2(0.0, Iso.lift_logical(LIGHT_LIFT_U))
	_feet = LightRig.attach(e, &"boss_cerf_hooves", {"color": DROP})
	_heart = LightRig.attach(e, &"boss_sonneur_rod", {"offset": Vector2(0.0, Iso.lift_logical(HEART_LIFT_U)), "color": DROP})
	if vis.body_sprite() != null:
		vis.body_sprite().self_modulate = BODY_GAIN
	else:
		_build_body()
	_apply_phase_look()
	_start_intro()


func _find_center() -> Vector2:
	if e.is_inside_tree():
		var best: Node2D = null
		for p in e.get_tree().get_nodes_in_group(&"pillars"):
			if p is Pillar and (p as Pillar).kind == Pillar.Kind.BIG:
				var d := (p as Node2D).global_position.distance_to(e.global_position)
				if d < 8.0 * U and (best == null or d < best.global_position.distance_to(e.global_position)):
					best = p
		if best != null:
			return best.global_position
	if e.director != null and e.director.has_meta(&"arena_center"):
		return e.director.get_meta(&"arena_center")
	return e.position


func clear() -> void:
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	if killed:
		_death_fx()
	for d in _drops:
		if is_instance_valid(d.get("spr")):
			(d["spr"] as Node).queue_free()
	_drops.clear()
	for l in _lanes:
		if is_instance_valid(l.get("front")):
			(l["front"] as Node).queue_free()
	_lanes.clear()
	for c in _cross:
		for k in ["beam"]:
			if is_instance_valid(c.get(k)):
				(c[k] as Node).queue_free()
	_cross.clear()
	if not _surge.is_empty() and is_instance_valid(_surge.get("fx")):
		(_surge["fx"] as Node).queue_free()
	_surge = {}
	_strikes.clear()
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	for m in _mist:
		if is_instance_valid(m):
			m.queue_free()
	_mist.clear()
	for n in [_flood, _column, _body]:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_flood = null
	_column = null
	_body = null
	for t in _teles:
		if is_instance_valid(t):
			t.queue_free()
	_teles.clear()
	for h in [_feet, _heart]:
		if h != null:
			(h as LightRig.Handle).release()
	_feet = null
	_heart = null
	if vis != null and is_instance_valid(vis):
		vis.self_modulate = Color.WHITE
		if vis.body_sprite() != null:
			vis.body_sprite().self_modulate = Color.WHITE
	if e != null and is_instance_valid(e):
		if is_instance_valid(e.telegraph):
			e.telegraph.modulate = Color.WHITE
		if e._light != null:
			e._light.set_energy(1.0)
			e._light.set_radius_mult(1.0)
			e._light.set_flicker_override(-1.0)
			e._light.set_preset(&"boss")
			e._light.set_color(Color(0, 0, 0, 0))
			e._light.position = Vector2.ZERO


func owns_motion() -> bool:
	return state == S.STAGGER or state == S.INTRO or pace.planted()


## Super-armure pendant l'armement et la récupération (un recul ferait glisser le boss planté).
func ignores_knockback() -> bool:
	return pace.planted()


func damage_taken_mult() -> float:
	return Balance.boss_damage_taken_mult(ID, phase)


func drop_count() -> int:
	return _drops.size()


func lane_count() -> int:
	return _lanes.size()


func strike_count() -> int:
	return _strikes.size()


func cross_count() -> int:
	return _cross.size()


func cross_angle() -> float:
	return _cross_angle


## Un pas d'IA. Retourne la vitesse de marche voulue (px/s logiques), appliquée par Enemy.
func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase and state != S.INTRO:
		_enter_phase(ph)
	_update_waves(delta, player, ppos)
	_update_strikes(delta, player, ppos)
	_update_flood(delta, player, ppos)
	_update_surge(delta, player, ppos)
	_update_cross(delta, player, ppos)
	_update_fx(delta)
	_update_body(delta)
	_attack_cd -= delta
	_spell_cd -= delta
	_t += delta
	var pi := phase - 1
	if phase >= 3 and state != S.STAGGER:
		_lightning_cd -= delta
		if _lightning_cd <= 0.0:
			_lightning_cd = LIGHTNING_EVERY
			_start_strike(ppos)
	match state:
		S.INTRO:
			_intro_step()
			return Vector2.ZERO
		S.STAGGER:
			_stagger_step()
			return Vector2.ZERO
		S.LASH:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_lash(player, ppos)
			return Vector2.ZERO
		S.WHIRL:
			e.telegraph.global_position = e.position
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_whirl(player, ppos)
			return Vector2.ZERO
		S.RAIN:
			_drops_step()
			if _t >= _dur:
				_resolve_rain(player, ppos)
			return Vector2.ZERO
		S.WAVE_WIND:
			for l in _lanes:
				(l["tele"] as EnemyTelegraph).set_progress(_t / _dur)
			if _t >= _dur:
				_release_wave()
			return Vector2.ZERO
		S.WAVE_RUN:
			if _lanes.is_empty():
				state = S.CHASE
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering(): # récupération immobile : fenêtre de punition
		_face(dir)
		return Vector2.ZERO
	if vis.is_attacking():
		_face(dir)
		return Vector2.ZERO
	if _spell_cd <= 0.0 and dist < (WAVE_LEN_U + 2.0) * U:
		_start_spell(dir, ppos)
		return Vector2.ZERO
	if phase >= 3:
		if _attack_cd <= 0.0 and dist < WHIRL_R_U * U + PLAYER_R:
			_start_whirl(dir)
		else:
			_face(dir)
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < (LASH_LEN_U - 0.5) * U:
		_start_lash(dir)
		return Vector2.ZERO
	if dist > LASH_LEN_U * U * 0.6:
		var go := path_dir if path_dir != Vector2.ZERO else dir
		_face(go)
		return go * e.speed_px * SPEED_MULT[pi]
	_face(dir)
	return Vector2.ZERO


# --- Entrée -------------------------------------------------------------------------

func _start_intro() -> void:
	state = S.INTRO
	_t = 0.0
	var special := vis.play_special(&"intro")
	_dur = maxf(INTRO_S, special)
	_column = _make_column(e.position, 1.0)
	LightRig.flash(e.global_position, &"boss_lightning", 0.9, {"color": DROP, "radius": 3.0})
	e._sfx(&"amb.thunder_close", 2.0, true)
	events.append({"kind": &"intro", "phase": 1})


func _intro_step() -> void:
	var k := clampf(_t / _dur, 0.0, 1.0)
	if is_instance_valid(_column):
		_column.modulate.a = 1.0 - k * k
	if _body != null: # la silhouette provisoire descend dans la colonne
		_body.lift = Iso.lift_logical(3.0) * (1.0 - smoothstep(0.0, 0.8, k))
		_body.queue_redraw()
	if _t >= _dur:
		if is_instance_valid(_column):
			_column.queue_free()
		_column = null
		state = S.CHASE
		_attack_cd = 0.8
		_spell_cd = 1.2
		e._sfx(&"enemy.shockwave.heavy", 2.0, true)
		_ring_fx(e.position, 3.0 * U, 0.5, DROP)


# --- Phases --------------------------------------------------------------------------

func _enter_phase(ph: int) -> void:
	_cancel()
	phase = ph
	state = S.STAGGER
	_t = 0.0
	_cycle = 0
	_stagger_from = e.position
	if ph == 2:
		_dur = maxf(FLOOD_RISE_S, 8.0 / ANIM_FPS + 0.3)
		_flood_from = 0.0
		_flood_to = FLOOD_R_U * U
		_build_flood()
		_build_mist()
		_surge_cd = _dur + SURGE_FIRST
		e._sfx(&"enemy.shockwave.heavy", 2.0, true)
	else:
		_dur = ANCHOR_S
		_flood_from = flood_r
		_flood_to = 0.0 # l'eau reflue vers le paratonnerre
		_surge_cd = 999.0
		_lightning_cd = _dur + LIGHTNING_FIRST
	_spell_cd = maxf(_spell_cd, _dur + 1.2)
	_attack_cd = maxf(_attack_cd, _dur + 0.6)
	_apply_phase_look()
	e._sfx(&"telegraph.boss.heavy", 3.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.7, {"color": DROP, "radius": 2.4})
	var am := AmbianceManager.find(e.get_tree()) if e.is_inside_tree() else null
	if am != null:
		am.strike_lightning(e.global_position, 0.3, true)
	events.append({"kind": &"phase", "phase": ph})


func _stagger_step() -> void:
	var k := clampf(_t / _dur, 0.0, 1.0)
	flood_r = lerpf(_flood_from, _flood_to, smoothstep(0.0, 1.0, k))
	if phase >= 3: # glisse jusqu'au paratonnerre
		e.position = _stagger_from.lerp(anchor, smoothstep(0.0, 1.0, k))
	if _t >= _dur:
		state = S.CHASE
		if phase >= 3:
			e.position = anchor
			flood_r = 0.0
			if is_instance_valid(_flood):
				_flood.visible = false
			_strike_rod()
			_build_cross()


## L'ancrage : la foudre frappe le paratonnerre (le boss), la colonne de lumière s'installe pour la phase 3.
func _strike_rod() -> void:
	_lightning_fx(e.position, 2.0)
	if not is_instance_valid(_column):
		_column = _make_column(e.position, 0.38)
		_column.z_index = -1 # derrière le boss (captures : la colonne au-dessus effaçait la silhouette)
	e._sfx(&"amb.thunder_close", 3.0, true)
	var am := AmbianceManager.find(e.get_tree()) if e.is_inside_tree() else null
	if am != null:
		am.strike_lightning(e.global_position, 0.5, true)
	events.append({"kind": &"anchor", "phase": phase})


func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	for d in _drops:
		if is_instance_valid(d.get("tele")):
			(d["tele"] as EnemyTelegraph).hide_telegraph()
		if is_instance_valid(d.get("spr")):
			(d["spr"] as Node).queue_free()
	_drops.clear()
	for l in _lanes:
		if is_instance_valid(l.get("tele")):
			(l["tele"] as EnemyTelegraph).hide_telegraph()
		if is_instance_valid(l.get("front")):
			(l["front"] as Node).queue_free()
	_lanes.clear()
	if not _surge.is_empty() and is_instance_valid(_surge.get("fx")):
		(_surge["fx"] as Node).queue_free()
	_surge = {}


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.2 if phase >= 3 else -1.0, 7.0)
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])
	if _heart != null:
		_heart.set_energy(HEART_ENERGY[pi])
	if _body != null:
		_body.glow = 0.5 + 0.25 * phase


# --- Fouet / tourbillon (auto) -----------------------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func _start_lash(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.LASH
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_line(e.position, aim.angle(), LASH_LEN_U * U, LASH_W_U * U)
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _resolve_lash(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.brute_cone.heavy")
	var v := ppos - e.position
	var along := v.dot(aim)
	if player != null and along >= -PLAYER_R and along <= LASH_LEN_U * U + PLAYER_R and absf(v.cross(aim)) <= LASH_W_U * 0.5 * U + PLAYER_R:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"lash"))
	_log(&"lash", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


func _start_whirl(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.WHIRL
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase, WHIRL_WINDUP)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, Vector2.ZERO)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_circle(e.position, WHIRL_R_U * U)
	e._sfx(&"telegraph.warn_light.light", 0.0, true)


func _resolve_whirl(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	_ring_fx(e.position, WHIRL_R_U * U, 0.35, BRONZE.lightened(0.5))
	if player != null and ppos.distance_to(e.position) <= WHIRL_R_U * U + PLAYER_R:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"whirl"))
	_log(&"whirl", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


# --- Sorts --------------------------------------------------------------------------------

func _start_spell(dir: Vector2, ppos: Vector2) -> void:
	var sp: int = Spell.RAIN if phase >= 3 or _cycle % 2 == 0 else Spell.WAVE
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	_t = 0.0
	match sp:
		Spell.RAIN:
			state = S.RAIN
			_dur = BossPace.windup(&"spell", phase)
			pace.wind(&"spell")
			vis.play_attack(&"cast_a", _dur, Vector2.ZERO)
			_place_drops(ppos)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)
		Spell.WAVE:
			state = S.WAVE_WIND
			_dur = BossPace.windup(&"spell", phase)
			pace.wind(&"spell")
			vis.play_attack(&"cast_b", _dur, aim)
			_place_lanes(aim)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)


# --- Averse ----------------------------------------------------------------------------------

func _place_drops(ppos: Vector2) -> void:
	var n: int = RAIN_COUNT[phase - 1]
	var pts: Array[Vector2] = [_walkable(ppos)]
	var min_d := (2.0 * RAIN_R_U + RAIN_GAP_U) * U
	var tries := 0
	while pts.size() < n and tries < 120:
		tries += 1
		var p := ppos + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf_range(0.12, 1.0)) * RAIN_SPREAD_U * U
		p = _walkable(p)
		if flood_r > 0.0 and p.distance_to(center) < flood_r: # pas de goutte dans l'eau profonde (illisible)
			continue
		var ok := true
		for q in pts:
			if q.distance_to(p) < min_d:
				ok = false
				break
		if ok:
			pts.append(p)
	for i in pts.size():
		var tele := _tele(i)
		tele.show_circle(pts[i], RAIN_R_U * U)
		var spr: Node2D
		if _frames != null and _frames.has_animation(&"raindrop"):
			var s := _sprite(&"raindrop", Iso.UNSQUASH * Iso.SPRITE_K, Vector2(0.0, -128.0), 0, 2.0)
			s.play(&"raindrop")
			spr = s
		else:
			var f := RecluseFx.make(RecluseFx.Kind.STREAK, Color(DROP.r, DROP.g, DROP.b, 0.85), 0)
			f.radius = -Iso.lift_logical(1.6)
			f.width = 7.0
			f.color2 = Color.WHITE
			spr = f
		spr.name = &"RainSower_drop"
		spr.visible = false
		e.get_parent().add_child(spr)
		spr.position = pts[i]
		_drops.append({"pos": pts[i], "tele": tele, "spr": spr})


## Gouttes qui tombent pendant la fin du télégraphe (touchent le sol à la frame d'impact de spell_a).
func _drops_step() -> void:
	var k := clampf(_t / _dur, 0.0, 1.0)
	var fall := clampf((_t - (_dur - RAIN_FALL_S)) / RAIN_FALL_S, 0.0, 1.0)
	for d in _drops:
		var tele := d["tele"] as EnemyTelegraph
		if is_instance_valid(tele):
			tele.set_progress(k)
		var spr := d.get("spr") as Node2D
		if is_instance_valid(spr):
			spr.visible = fall > 0.0
			spr.position = (d["pos"] as Vector2) + Vector2(0.0, Iso.lift_logical(RAIN_FALL_H_U * (1.0 - fall * fall)))


func _resolve_rain(player: Node2D, ppos: Vector2) -> void:
	_log(&"rain", &"cast_a")
	e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	var hit := false
	for d in _drops:
		var pos: Vector2 = d["pos"]
		if is_instance_valid(d.get("tele")):
			(d["tele"] as EnemyTelegraph).hide_telegraph()
		if is_instance_valid(d.get("spr")):
			(d["spr"] as Node).queue_free()
		_splash(pos)
		if not hit and player != null and pos.distance_to(ppos) <= RAIN_R_U * U + PLAYER_R:
			hit = true
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"rain"))
	_drops.clear()
	pace.strike(&"spell", phase)
	state = S.CHASE


func _splash(pos: Vector2) -> void:
	if _frames != null and _frames.has_animation(&"splash"):
		var s := _sprite(&"splash", Vector2.ONE * (RAIN_R_U * U / 64.0), Vector2.ZERO, -1, 1.6)
		e.get_parent().add_child(s)
		s.position = pos
		s.play(&"splash")
		_fx.append({"node": s, "life": 0.6, "max": 0.6})
	else:
		_ring_fx(pos, RAIN_R_U * U, 0.4, DROP)
	LightRig.flash(pos, &"boss_lightning", 0.15, {"color": DROP, "energy": 0.4, "radius": 0.5})


# --- Vague ------------------------------------------------------------------------------------

func _place_lanes(dir: Vector2) -> void:
	_wave_hit = false
	var fan: Array = WAVE_FAN[mini(phase - 1, 1)]
	for i in fan.size():
		var a: float = dir.angle() + float(fan[i])
		var tele := _tele(10 + i)
		tele.show_line(e.position, a, WAVE_LEN_U * U, WAVE_W_U * U)
		_lanes.append({"angle": a, "tele": tele, "front": null, "origin": e.position})


## Frame d'impact de spell_b : les fronts d'eau partent du boss et parcourent leur couloir.
func _release_wave() -> void:
	_log(&"wave", &"cast_b")
	e._sfx(&"enemy.shockwave.heavy", 2.0, true)
	_wave_t = 0.0
	for l in _lanes:
		var front: Node2D
		if _frames != null and _frames.has_animation(&"wave_front"):
			var s := _sprite(&"wave_front", Vector2.ONE * (WAVE_W_U * U / 128.0), Vector2.ZERO, 0, 1.8)
			s.play(&"wave_front")
			e.get_parent().add_child(s)
			front = s
		else:
			var f := RecluseFx.make(RecluseFx.Kind.WAVE, Color(WATER.r, WATER.g, WATER.b, 0.75), 0)
			f.radius = WAVE_W_U * 0.5 * U
			f.width = 1.2 * U
			f.color2 = Color(0.95, 1.0, 1.0, 0.95)
			RecluseFx.add_to_tele_layer(f, e.get_parent())
			front = f
		front.name = &"RainSower_wave"
		front.rotation = float(l["angle"])
		front.global_position = l["origin"]
		l["front"] = front
	pace.strike(&"spell", phase) # le front part : le boss reste planté (récupération) pendant la course de l'eau
	state = S.WAVE_RUN


func _update_waves(delta: float, player: Node2D, ppos: Vector2) -> void:
	if state != S.WAVE_RUN or _lanes.is_empty():
		return
	_wave_t += delta
	var run := _wave_t * WAVE_SPEED_U * U
	var done := run >= WAVE_LEN_U * U
	for l in _lanes:
		var d := Vector2.from_angle(float(l["angle"]))
		var o: Vector2 = l["origin"]
		var front := l["front"] as Node2D
		if is_instance_valid(front):
			front.global_position = o + d * minf(run, WAVE_LEN_U * U)
			front.modulate.a = 1.0 - clampf(run / (WAVE_LEN_U * U) - 0.8, 0.0, 0.2) * 5.0
		var v := ppos - o
		var along := v.dot(d)
		if not _wave_hit and player != null and absf(v.cross(d)) <= WAVE_W_U * 0.5 * U + PLAYER_R \
				and along >= 0.0 and absf(along - run) <= WAVE_BAND_U * 0.5 * U + PLAYER_R:
			_wave_hit = true # un même lancer ne touche qu'une fois
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"wave"))
			events.append({"kind": &"wave_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	if done:
		for l in _lanes:
			if is_instance_valid(l.get("tele")):
				(l["tele"] as EnemyTelegraph).hide_telegraph()
			if is_instance_valid(l.get("front")):
				(l["front"] as Node).queue_free()
		_lanes.clear()
	else:
		for l in _lanes: # le couloir s'efface derrière le front
			var tele := l["tele"] as EnemyTelegraph
			if is_instance_valid(tele):
				tele.modulate.a = 1.0 - 0.6 * clampf(run / (WAVE_LEN_U * U), 0.0, 1.0)


# --- Crue (P2) ------------------------------------------------------------------------------------

func _build_flood() -> void:
	if is_instance_valid(_flood):
		_flood.visible = true
		return
	if _frames != null and _frames.has_animation(&"flood_water"):
		var s := _sprite(&"flood_water", Vector2.ONE, Vector2.ZERO, -2, 1.4)
		s.play(&"flood_water")
		e.get_parent().add_child(s)
		_flood = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.DISC, Color(0.10, 0.30, 0.44, 0.72), -2)
		f.color2 = Color(WATER.r, WATER.g, WATER.b, 0.9)
		f.width = 7.0
		e.get_parent().add_child(f)
		_flood = f
	_flood.name = &"RainSower_flood"
	_flood.global_position = center
	_set_flood_visual(0.0)


func _set_flood_visual(r: float) -> void:
	if not is_instance_valid(_flood):
		return
	_flood.visible = r > 2.0
	if _flood is RecluseFx:
		(_flood as RecluseFx).set_param(r)
	else:
		_flood.scale = Vector2.ONE * (r / 448.0) # flood_water : disque de 448 px de rayon dans sa cellule de 896


func _build_mist() -> void:
	if not _mist.is_empty():
		return
	if _frames != null and _frames.has_animation(&"mist_band"):
		for i in 20:
			var s := _sprite(&"mist_band", Vector2.ONE * 1.6, Vector2.ZERO, -1, 0.0)
			s.play(&"mist_band")
			s.frame = i % 6
			e.get_parent().add_child(s)
			s.global_position = center + Vector2.from_angle(TAU * i / 20.0) * (MIST_R_U + 2.0) * U
			s.modulate = Color(1, 1, 1, 0.8)
			_mist.append(s)
	else:
		var f := RecluseFx.make(RecluseFx.Kind.BAND, Color(0.76, 0.86, 0.83, 0.26), -1)
		f.inner = MIST_R_U * U
		f.radius = (MIST_R_U + MIST_W_U) * U
		f.color2 = Color(0.86, 0.95, 0.92, 0.7)
		f.width = 3.0
		e.get_parent().add_child(f)
		f.global_position = center
		_mist.append(f)
	for m in _mist:
		m.name = &"RainSower_mist"


func _update_flood(delta: float, player: Node2D, ppos: Vector2) -> void:
	_set_flood_visual(flood_r)
	if player == null or phase < 2:
		return
	# bassin infranchissable : repoussé vers le bord, noyade par 0,5 s
	_drown_tick -= delta
	var v := ppos - center
	var d := v.length()
	if flood_r > 0.0 and d < flood_r - PLAYER_R * 0.5:
		var out := v / d if d > 1.0 else Vector2.RIGHT
		if player.has_method(&"move_swept"): # déplacement balayé (Player) : jamais à travers un mur
			player.move_swept(out * DROWN_PUSH_U * U * delta)
		else:
			var np := ppos + out * DROWN_PUSH_U * U * delta
			player.global_position = e.nav.resolve(np, PLAYER_R) if e.nav else np
		if _drown_tick <= 0.0:
			_drown_tick = DROWN_TICK
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"drown"))
			events.append({"kind": &"drown", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	# brume du bord : ralenti
	_mist_tick -= delta
	if d > MIST_R_U * U and _mist_tick <= 0.0:
		_mist_tick = MIST_TICK
		if player.has_method(&"apply_status"):
			player.apply_status(&"slow", {"hit": 0.0, "source": e})
		events.append({"kind": &"mist", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})


## Débordement (P2) : anneau de SURGE_W_U au bord de l'eau, télégraphe SURGE_WINDUP, puis la vague
## d'eau court sur l'anneau (SURGE_RUN_S) ; un seul coup.
func _update_surge(delta: float, player: Node2D, ppos: Vector2) -> void:
	if phase != 2 or state == S.STAGGER:
		return
	if _surge.is_empty():
		_surge_cd -= delta
		if _surge_cd <= 0.0:
			_surge_cd = SURGE_EVERY
			var f := RecluseFx.make(RecluseFx.Kind.RING_TELE, Color.RED, 0)
			f.name = &"RainSower_surge"
			RecluseFx.add_to_tele_layer(f, e.get_parent())
			f.global_position = center
			f.inner = flood_r
			f.set_param(flood_r + SURGE_W_U * U, flood_r, 0.0)
			_surge = {"t": 0.0, "fx": f, "hit": false}
			e._sfx(&"telegraph.warn_heavy.heavy", 0.0, true)
		return
	_surge["t"] = float(_surge["t"]) + delta
	var t := float(_surge["t"])
	var fv: Variant = _surge.get("fx")
	var f: RecluseFx = fv as RecluseFx if is_instance_valid(fv) else null
	if t < SURGE_WINDUP:
		if is_instance_valid(f):
			f.set_param(flood_r + SURGE_W_U * U, flood_r, t / SURGE_WINDUP)
		return
	if not _surge.has("run"):
		_surge["run"] = true
		e._sfx(&"enemy.shockwave.heavy", 1.0, true)
		_ring_fx(center, flood_r + SURGE_W_U * U, 0.45, WATER)
		events.append({"kind": &"surge", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
		var d := ppos.distance_to(center)
		if player != null and d >= flood_r - PLAYER_R and d <= flood_r + SURGE_W_U * U + PLAYER_R:
			_surge["hit"] = true
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"surge"))
			events.append({"kind": &"surge_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
		if is_instance_valid(f):
			f.queue_free()
	if t >= SURGE_WINDUP + SURGE_RUN_S:
		_surge = {}


# --- Orage (P3) ----------------------------------------------------------------------------

func _build_cross() -> void:
	if not _cross.is_empty():
		return
	_gust_t = 0.0
	for j in CROSS_LINES:
		var tele := _tele(20 + j)
		tele.show_line(e.position, 0.0, CROSS_LEN_U * U, CROSS_W_U * U)
		tele.set_progress(1.0)
		tele.modulate = Color(1.0, 1.0, 1.0, CROSS_ALPHA)
		var ghost := _tele(24 + j)
		ghost.hide_telegraph()
		var beam: Node2D
		if _frames != null and _frames.has_animation(&"cross_beam"):
			var s := _sprite(&"cross_beam", Vector2(CROSS_LEN_U * U / 832.0, CROSS_W_U * U / 64.0), Vector2(416.0, 0.0), 0, 2.4)
			s.play(&"cross_beam")
			e.get_parent().add_child(s)
			beam = s
		else:
			var f := RecluseFx.make(RecluseFx.Kind.BEAM, Color(DROP.r, DROP.g, DROP.b, 0.3), 0)
			f.radius = CROSS_LEN_U * U
			f.width = CROSS_W_U * U * 0.7
			f.color2 = Color(1, 1, 1, 0.85)
			RecluseFx.add_to_tele_layer(f, e.get_parent())
			beam = f
		beam.name = &"RainSower_cross"
		_cross.append({"tele": tele, "ghost": ghost, "beam": beam})
	_place_cross()


func _place_cross() -> void:
	for j in _cross.size():
		var a := _cross_angle + TAU * j / float(CROSS_LINES)
		for k in ["tele", "beam"]:
			var n := _cross[j][k] as Node2D
			if is_instance_valid(n):
				n.global_position = e.position
				n.rotation = a


func _update_cross(delta: float, player: Node2D, ppos: Vector2) -> void:
	if _cross.is_empty():
		return
	_cross_angle = wrapf(_cross_angle + CROSS_TURN * delta, 0.0, TAU)
	# Rafale : lignes fantômes à +45° pendant GUST_WARN_S, puis la croix y saute
	_gust_t += delta
	var warn_t := _gust_t - (GUST_EVERY - GUST_WARN_S)
	for j in _cross.size():
		var ghost := _cross[j]["ghost"] as EnemyTelegraph
		if warn_t >= 0.0:
			var a := _cross_angle + GUST_STEP + TAU * j / float(CROSS_LINES)
			if not ghost.visible:
				ghost.show_line(e.position, a, CROSS_LEN_U * U, CROSS_W_U * U)
			ghost.global_position = e.position
			ghost.rotation = a
			ghost.set_progress(warn_t / GUST_WARN_S)
	if warn_t >= 0.0 and warn_t - delta < 0.0:
		e._sfx(&"telegraph.warn_heavy.heavy", 2.0, true)
		events.append({"kind": &"gust_warn", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	if _gust_t >= GUST_EVERY:
		_gust_t = 0.0
		_cross_angle = wrapf(_cross_angle + GUST_STEP, 0.0, TAU)
		gusts += 1
		for c in _cross:
			(c["ghost"] as EnemyTelegraph).hide_telegraph()
		LightRig.flash(e.global_position, &"boss_lightning", 0.3, {"color": DROP, "radius": 1.8})
		e._sfx(&"enemy.shockwave.heavy", 2.0, true)
		_cross_tick = 0.0 # la croix qui saute frappe tout de suite (elle a été annoncée)
		events.append({"kind": &"gust", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	_place_cross()
	_cross_tick -= delta
	if _cross_tick > 0.0 or player == null or state == S.STAGGER:
		return
	var v := ppos - e.position
	for j in CROSS_LINES:
		var d := Vector2.from_angle(_cross_angle + TAU * j / float(CROSS_LINES))
		var along := v.dot(d)
		if along >= 0.0 and along <= CROSS_LEN_U * U + PLAYER_R and absf(v.cross(d)) <= CROSS_W_U * 0.5 * U + PLAYER_R:
			_cross_tick = CROSS_TICK
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"cross"))
			events.append({"kind": &"cross", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			return


func _start_strike(ppos: Vector2) -> void:
	var pos := _walkable(ppos)
	var tele := _tele(30 + (_strikes.size() % 3))
	tele.show_circle(pos, LIGHTNING_R_U * U)
	_strikes.append({"pos": pos, "t": 0.0, "tele": tele})
	e._sfx(&"telegraph.warn_heavy.heavy", -2.0, true)


func _update_strikes(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := _strikes.size() - 1
	while i >= 0:
		var s: Dictionary = _strikes[i]
		s["t"] = float(s["t"]) + delta
		var k := float(s["t"]) / LIGHTNING_WINDUP
		var tele := s["tele"] as EnemyTelegraph
		if is_instance_valid(tele):
			tele.set_progress(k)
		if _heart != null:
			_heart.set_energy(HEART_ENERGY[phase - 1] * (1.0 + clampf(k, 0.0, 1.0)))
		if k >= 1.0:
			if is_instance_valid(tele):
				tele.hide_telegraph()
			var pos: Vector2 = s["pos"]
			_lightning_fx(pos, 1.0)
			e._sfx(&"amb.thunder_close", 0.0, true)
			if player != null and pos.distance_to(ppos) <= LIGHTNING_R_U * U + PLAYER_R:
				e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"lightning"))
			events.append({"kind": &"lightning", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			if _heart != null:
				_heart.set_energy(HEART_ENERGY[phase - 1])
			_strikes.remove_at(i)
		i -= 1


## Éclair : colonne (lightning du .tres, sinon colonne dessinée), brûlure au sol, flash.
func _lightning_fx(pos: Vector2, size: float) -> void:
	LightRig.flash(pos, &"boss_lightning", 0.35, {"color": DROP})
	var col: Node2D
	if _frames != null and _frames.has_animation(&"lightning"):
		var s := _sprite(&"lightning", Iso.UNSQUASH * Iso.SPRITE_K * Vector2(size, 1.0), Vector2(0.0, -384.0), 1, 3.0)
		s.play(&"lightning")
		s.frame = _rng.randi() % maxi(_frames.get_frame_count(&"lightning"), 1)
		col = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.COLUMN, Color(1.0, 1.0, 1.0, 0.9), 1)
		f.radius = -Iso.lift_logical(9.0)
		f.width = 0.7 * U * size
		f.color2 = Color(0.85, 0.95, 1.0, 1.0)
		col = f
	col.name = &"RainSower_lightning"
	e.get_parent().add_child(col)
	col.position = pos
	_fx.append({"node": col, "life": 0.4, "max": 0.4})
	var sc: Node2D
	if _frames != null and _frames.has_animation(&"ground_scorch"):
		var s2 := _sprite(&"ground_scorch", Vector2.ONE * size, Vector2.ZERO, -2, 1.2)
		s2.frame = _rng.randi() % maxi(_frames.get_frame_count(&"ground_scorch"), 1)
		sc = s2
	else:
		var f2 := RecluseFx.make(RecluseFx.Kind.DISC, Color(0.03, 0.03, 0.04, 0.55), -2)
		f2.radius = LIGHTNING_R_U * U * 0.8 * size
		f2.color2 = Color(DROP.r, DROP.g, DROP.b, 0.5)
		f2.width = 2.0
		sc = f2
	sc.name = &"RainSower_scorch"
	e.get_parent().add_child(sc)
	sc.position = pos
	_fx.append({"node": sc, "life": SCORCH_LIFE, "max": 1.5})


# --- Effets ----------------------------------------------------------------------------------

func _make_column(pos: Vector2, alpha: float) -> Node2D:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"rain_column"):
		var s := _sprite(&"rain_column", Iso.UNSQUASH * Iso.SPRITE_K, Vector2(0.0, -512.0), 1, 2.0)
		s.play(&"rain_column")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.COLUMN, Color(DROP.r, DROP.g, DROP.b, 0.45), 1)
		f.radius = -Iso.lift_logical(COLUMN_H_U)
		f.width = 2.6 * U
		f.color2 = Color(1, 1, 1, 0.6)
		n = f
	n.name = &"RainSower_column"
	n.modulate.a = alpha
	e.get_parent().add_child(n)
	n.position = pos
	return n


func _ring_fx(pos: Vector2, r: float, life: float, c: Color) -> void:
	var f := RecluseFx.make(RecluseFx.Kind.RING, Color(c.r, c.g, c.b, 0.8), -1)
	f.name = &"RainSower_ring"
	f.radius = r
	f.width = 0.3 * U
	f.color2 = Color(1, 1, 1, 0.8)
	e.get_parent().add_child(f)
	f.position = pos
	_fx.append({"node": f, "life": life, "max": life})


## Mort : la pluie s'arrête. Éclair final, rayons de lumière dans le puits (AmbianceManager).
func _death_fx() -> void:
	deaths += 1
	LightRig.flash(e.global_position, &"boss_lightning", 1.4, {"color": DROP, "radius": 4.0})
	e._sfx(&"amb.thunder_close", 4.0, true)
	var am := AmbianceManager.find(e.get_tree()) if e.is_inside_tree() else null
	if am != null:
		am.strike_lightning(e.global_position, 0.55, true)
		am.spawn_rays(e.global_position, 4, 0.3, 8.0)


func _build_body() -> void:
	_body = RecluseFx.make(RecluseFx.Kind.BODY_SOWER, BRONZE, 0)
	_body.name = &"RainSower_body"
	_body.color2 = DROP
	e.add_child(_body)
	vis.self_modulate = Color(1, 1, 1, 0)


func _update_body(_delta: float) -> void:
	var beat := LightRig.heartbeat(Time.get_ticks_msec() / 1000.0 * (0.8 + 0.3 * phase))
	if _heart != null and _strikes.is_empty():
		_heart.set_energy(HEART_ENERGY[phase - 1] * beat)
	if _body == null:
		return
	var fl := 1.0 if e.is_flashing() else 0.0
	var g := (0.5 + 0.25 * phase) * beat
	if absf(fl - _body.progress) > 0.01 or absf(g - _body.glow) > 0.05:
		_body.progress = fl
		_body.glow = g
		_body.queue_redraw()
	_body.position = vis.position


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
	if is_instance_valid(_column) and phase >= 3 and state != S.INTRO:
		_column.position = e.position


# --- Outils ------------------------------------------------------------------------------------

func _sprite(anim: StringName, sc: Vector2, off: Vector2, z: int, energy: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = StringName("RainSower_" + String(anim))
	EmissiveOverlay.apply(s, _frames, energy)
	s.animation = anim
	s.scale = sc
	s.offset = off
	s.z_index = z
	return s


func _tele(i: int) -> EnemyTelegraph:
	while _teles.size() <= i:
		var t := EnemyTelegraph.new()
		e.get_parent().add_child(t)
		_teles.append(t)
	var tele := _teles[i]
	tele.modulate = Color.WHITE
	return tele


func _walkable(p: Vector2) -> Vector2:
	return e.nav.resolve(p, PLAYER_R) if e.nav else p


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
