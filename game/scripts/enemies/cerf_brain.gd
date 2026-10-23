class_name CerfBrain
extends RefCounted
## IA du Cerf-Lanterne (boss d'étage 2, Forêt-brume ; sprites lot C7b). Créée par Enemy.activate_boss
## quand le skin du boss est « cerf », appelée par Enemy.tick (branche BOSS_TIER) à la place de l'IA
## générique. Toutes les attaques sont télégraphiées face au joueur (angle libre, 8 directions et plus ;
## le sprite prend la plus proche de ses 4 orientations e/s/w/n) et leurs dégâts tombent à la frame
## d'impact de l'anim (EnemyVisual.play_attack cale la frame d'impact sur la fin du télégraphe).
##
## Phases (PV, Enemy.boss_phase) : 1 > 66 % > 2 > 33 % > 3. Au passage : anim trans_pN (boss figé,
## coups en cours annulés), puis salve de feux follets en couronne ; visuels : variantes idle/walk_pN,
## brume au sol (ground_mist) dès la phase 2, lumière du boss menthe #9CF0C8 qui grandit (P2) puis
## vacille, lanternes mourantes (P3).
## Attaques :
## - coup de bois (auto, près) : cône court, anim auto_<dir> ; tir de follet (auto, loin) : projectile ;
## - charge lumineuse (spell_b, cabré) : ligne qui suit le joueur puis se fige, la lumière monte, ruée à
##   la frame d'impact ; traînée de follets au sol (brûlante en phase 3) ; enchaînée 2 fois dès la phase 2 ;
## - lanternes (spell_a) : feux follets qui dérivent vers le joueur, s'arrêtent, cercle d'alerte, explosent
##   (wisp_explode, dégâts à sa frame 2) ;
## - phase 3, bond spectral : vanish, cercle sous le joueur, réapparition dessus (dégâts à la frame 4).
## Dégâts : multiplicateurs de Enemy.damage dans Balance.BOSS_ATTACK_COEF[&"cerf"] (gore, charge, trail, wisp, leap).

enum S { CHASE, GORE, AUTO, CHARGE_WIND, CHARGE_DASH, WISPS, VANISH, REAPPEAR, STAGGER }
enum Spell { CHARGE, WISPS, LEAP }

const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
## Par phase (index phase - 1)
const SPEED_MULT := [1.0, 1.1, 1.25]
const AUTO_CD := [1.6, 1.4, 1.2]
const SPELL_CD := [4.2, 3.6, 3.0]
const SPELL_CYCLE := [[Spell.CHARGE, Spell.WISPS], [Spell.CHARGE, Spell.WISPS], [Spell.LEAP, Spell.CHARGE, Spell.WISPS]]
## Lumière (preset boss_cerf, menthe) : le corps en bois noir disparaissait sur le sol sombre (captures) ;
## + une lumière basse aux sabots (boss_cerf_hooves) qui découpe la silhouette sur le sol.
const LIGHT_ENERGY := [2.3, 2.6, 2.0] ## relevé le 22/10 (corps quasi noir de nuit, avec BODY_GAIN)
const LIGHT_RADIUS := [1.15, 1.35, 1.2]
const HOOVES_ENERGY := [2.2, 2.6, 1.8]
const MIST_ALPHA := [0.0, 0.9, 0.65]
## Bois et os quasi noirs sous la nuit (captures 22/10 après C7D : albédo opaque moyen ~60/255, contre ~98 pour
## le Sonneur re-rendu en C7E) : albédo relevé par self_modulate du corps (le flash de coup passe par modulate),
## rendu à 1 au retour au pool. PROVISOIRE : à retirer quand le re-rendu cel (lot cel_bosses_f23) éclaircit le corps.
const BODY_GAIN := Color(1.85, 1.9, 1.8)
## Armements et récupérations : BossPace (Balance.BOSS_PACE_*, catégories auto / spell / charge).
# Coup de bois (auto, près)
const GORE_RANGE_U := 2.6
const GORE_HALF := 0.62
# Tir de follet (auto, loin)
const SHOOT_RANGE_U := 8.0
const SHOOT_LINE_U := 3.0
const SHOOT_LINE_W_U := 0.5
# Charge lumineuse
const CHAIN_WINDUP := 0.8 ## seconde charge enchaînée (>= Balance.BOSS_PACE_COMBO_GAP_S, ligne au sol)
const CHARGE_CHAIN := [0, 1, 1] ## charges supplémentaires enchaînées
const CHARGE_TRACK := 0.55 ## part du télégraphe pendant laquelle la ligne suit le joueur
const CHARGE_LEN_U := [7.0, 8.0, 9.0]
const CHARGE_W_U := 1.7
const CHARGE_BACK := 0.6 ## la ligne commence 0,6 rayon derrière le centre (sous le corps)
const CHARGE_SPEED_U := 15.0
const CHARGE_LIGHT_BOOST := 1.8 ## énergie de lumière ajoutée au sommet de l'armement
const TRAIL_STEP_U := 0.8
const TRAIL_LIFE := [1.2, 1.6, 3.0]
const TRAIL_HURT_PHASE := 3
const TRAIL_R_U := 0.55
const TRAIL_HIT_CD := 0.6
const TRAIL_MAX := 40
# Feux follets
const WISP_COUNT := [3, 5, 6]
const WISP_BURST := [0, 4, 6] ## couronne libérée à l'entrée de la phase
const WISP_SPEED_U := 2.8
const WISP_TURN := 2.2 ## rad/s
const WISP_SEEK_S := 2.6
const WISP_TRIGGER_U := 1.0
const WISP_ARM_S := 0.85
const WISP_R_U := 1.25
const WISP_MAX := 14
const WISP_HOVER_U := 0.9
const WISP_BOLT_SCALE := 1.6 ## follet tiré (wisp_bolt 64×32, C7D) : ~1,5 u de long à l'écran
const WISP_IMPACT_FRAME := 2 ## wisp_explode : expansion maximale
# Bond spectral (phase 3)
const LEAP_R_U := 2.6
const LEAP_TRACK := 0.5
const REAPPEAR_IMPACT_FRAME := 4 ## reappear : corps formé

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = [] ## journal des coups (tests) : kind, phase, anim, frame, expect, lag
var pace: BossPace ## rythme commun : armement planté, impact, récupération immobile
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT ## direction logique visée (télégraphe et sprite)

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.4
var _spell_cd := 2.5
var _cycle := 0
var _chain_left := 0
var _dash_left := 0.0
var _dash_hit := false
var _trail_acc := 0.0
var _trail_hit_cd := 0.0
var _leap_to := Vector2.ZERO
var _ppos := Vector2.ZERO ## position du joueur à ce pas (journal)
var _leap_total := 1.0
var _frames: SpriteFrames = null
var _mist: AnimatedSprite2D = null
var _hooves: LightRig.Handle = null
var _wisps: Array[Dictionary] = []
var _trails: Array[Dictionary] = []
var _antlers: AnimatedSprite2D = null ## lanternes allumées pendant l'armement de la charge (C7D)


func _init(enemy: Enemy) -> void:
	e = enemy
	vis = enemy.visual as EnemyVisual
	pace = BossPace.new(enemy)
	_frames = EnemyVisual.boss_frames(&"cerf")
	if e._light != null:
		e._light.set_preset(&"boss_cerf")
	_hooves = LightRig.attach(e, &"boss_cerf_hooves")
	if vis.body_sprite() != null:
		vis.body_sprite().self_modulate = BODY_GAIN
	_build_antlers()
	_apply_phase_look()


## Libère follets, traînées, brume (mort, retour au pool).
func clear() -> void:
	if pace != null:
		pace.cancel()
	for w in _wisps:
		_free_wisp(w)
	_wisps.clear()
	for tr in _trails:
		if is_instance_valid(tr["node"]):
			(tr["node"] as Node).queue_free()
	_trails.clear()
	if is_instance_valid(_mist):
		_mist.queue_free()
	_mist = null
	if _hooves != null:
		_hooves.release()
	_hooves = null
	if is_instance_valid(_antlers):
		_antlers.queue_free()
	_antlers = null
	if vis != null and is_instance_valid(vis) and vis.body_sprite() != null:
		vis.body_sprite().self_modulate = Color.WHITE
	if e != null and is_instance_valid(e) and e._light != null:
		e._light.set_energy(1.0)
		e._light.set_radius_mult(1.0)
		e._light.set_flicker_override(0.0)


## Pendant la ruée, la disparition et la transition de phase, le Cerf se déplace (ou reste figé) seul ;
## planté (armement, récupération) : ni marche ni poussée de foule.
func owns_motion() -> bool:
	return state in [S.CHARGE_DASH, S.VANISH, S.REAPPEAR, S.STAGGER] or pace.planted()


## Super-armure le temps d'un coup (armement, récupération) : un recul le ferait glisser.
func ignores_knockback() -> bool:
	return pace.planted()


func wisp_count() -> int:
	return _wisps.size()


func trail_count() -> int:
	return _trails.size()


## Un pas d'IA. Retourne la vitesse de marche voulue (px/s logiques), appliquée par Enemy.
func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	pace.tick(delta)
	_update_wisps(delta, player, ppos)
	_update_trails(delta, player, ppos)
	var ph: int = e.boss_phase()
	if ph > phase:
		_enter_phase(ph)
	_attack_cd -= delta
	_spell_cd -= delta
	_t += delta
	var pi := phase - 1
	match state:
		S.STAGGER:
			if _t >= _dur:
				_release_wisps(WISP_BURST[pi], dir, true)
				state = S.CHASE
			return Vector2.ZERO
		S.GORE:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_gore(player, ppos)
			return Vector2.ZERO
		S.AUTO:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				e.telegraph.hide_telegraph()
				var to := ppos - e.position
				_shoot_wisp(to.normalized() if to.length_squared() > 0.01 else aim)
				_log(&"auto", &"attack")
				pace.strike(&"auto", phase)
				state = S.CHASE
			return Vector2.ZERO
		S.CHARGE_WIND:
			_charge_windup(dir)
			return Vector2.ZERO
		S.CHARGE_DASH:
			_dash_step(delta, player, ppos)
			return Vector2.ZERO
		S.WISPS:
			var k := clampf(_t / _dur, 0.0, 1.0)
			_light_boost(0.8 * k)
			if _t >= _dur:
				_log(&"wisps", &"cast_a")
				_release_wisps(WISP_COUNT[pi], aim, false)
				_light_boost(0.0)
				pace.strike(&"spell", phase)
				state = S.CHASE
			return Vector2.ZERO
		S.VANISH:
			if _t <= _dur * LEAP_TRACK:
				_leap_to = _walkable(ppos)
				e.telegraph.global_position = _leap_to
			e.telegraph.set_progress(_t / _leap_total)
			if _t >= _dur:
				pace.act() # téléport : seul déplacement du bond
				e.position = _leap_to
				vis.play_special(&"reappear")
				state = S.REAPPEAR
				_t = 0.0
				_dur = REAPPEAR_IMPACT_FRAME / ANIM_FPS
			return Vector2.ZERO
		S.REAPPEAR:
			e.telegraph.set_progress((_leap_total - _dur + _t) / _leap_total)
			if _t >= _dur:
				e.telegraph.hide_telegraph()
				e._sfx(&"enemy.shockwave.heavy", 2.0, true)
				LightRig.flash(e.global_position, &"boss_cerf", 0.35)
				if player != null and _leap_to.distance_to(ppos) <= LEAP_R_U * U + PLAYER_R:
					e._hit_player(player, e.damage * Balance.boss_attack_coef(&"cerf", &"leap"))
				_log(&"leap", &"reappear", REAPPEAR_IMPACT_FRAME)
				pace.strike(&"charge", phase) # réception : arrêt net, récupération immobile
				state = S.CHASE
				_attack_cd = maxf(_attack_cd, 0.6)
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering(): # récupération immobile : fenêtre de punition, aucun nouveau coup
		_face(dir)
		return Vector2.ZERO
	if vis.is_attacking(): # fin d'un coup (retour de fente) : planté, face au joueur
		_face(dir)
		return Vector2.ZERO
	if _spell_cd <= 0.0:
		_start_spell(dir, ppos, path_dir == Vector2.ZERO)
		return Vector2.ZERO
	if _attack_cd <= 0.0:
		if dist < GORE_RANGE_U * U:
			_start_gore(dir)
			return Vector2.ZERO
		if dist < SHOOT_RANGE_U * U and path_dir == Vector2.ZERO:
			_start_auto(dir)
			return Vector2.ZERO
	if dist > e.radius_px + 2.0 * U:
		var go := path_dir if path_dir != Vector2.ZERO else dir
		return go * e.speed_px * SPEED_MULT[pi]
	_face(dir)
	return Vector2.ZERO


# --- Phases --------------------------------------------------------------------

func _enter_phase(ph: int) -> void:
	_cancel()
	phase = ph
	state = S.STAGGER
	_t = 0.0
	_dur = 8.0 / ANIM_FPS + 0.15 # trans_pN : 8 frames
	_spell_cd = maxf(_spell_cd, _dur + 1.0)
	_attack_cd = maxf(_attack_cd, _dur + 0.4)
	_cycle = 0
	_apply_phase_look()
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_cerf", 0.5)
	events.append({"kind": &"phase", "phase": ph})


## Coup en cours annulé (changement de phase) : télégraphe masqué, lumière rendue, ruée stoppée.
func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	_chain_left = 0
	_dash_left = 0.0
	_light_boost(0.0)
	_sync_antlers(false)


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.22 if phase >= 3 else 0.0, 7.0)
	if _hooves != null:
		_hooves.set_energy(HOOVES_ENERGY[pi])
	var a: float = MIST_ALPHA[pi]
	if a <= 0.0:
		if is_instance_valid(_mist):
			_mist.visible = false
		return
	if not is_instance_valid(_mist):
		var body := vis.body_sprite()
		if body == null or _frames == null or not _frames.has_animation(&"ground_mist"):
			return
		_mist = AnimatedSprite2D.new()
		_mist.name = &"CerfMist"
		EmissiveOverlay.apply(_mist, _frames, 0.8)
		_mist.scale = body.scale * 1.15
		_mist.offset = body.offset
		_mist.z_index = -1 # brume au sol, sous le corps et les entités
		vis.add_child(_mist)
		_mist.play(&"ground_mist")
	_mist.visible = true
	_mist.modulate = Color(1.0, 1.0, 1.0, a)


# --- Attaques --------------------------------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func _start_gore(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.GORE
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.show_cone(e.position, aim.angle(), GORE_RANGE_U * U, GORE_HALF)
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _resolve_gore(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.brute_cone.heavy")
	var v := ppos - e.position
	if player != null and v.length() <= GORE_RANGE_U * U + PLAYER_R and absf(angle_difference(aim.angle(), v.angle())) <= GORE_HALF + 0.15:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(&"cerf", &"gore"))
	_log(&"gore", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


func _start_auto(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.AUTO
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase, vis.attack_impact_time(&"attack"))
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.show_line(e.position, aim.angle(), SHOOT_LINE_U * U, SHOOT_LINE_W_U * U)
	e._sfx(&"telegraph.warn_light.light", -6.0)


func _start_spell(dir: Vector2, ppos: Vector2, has_los: bool) -> void:
	var cyc: Array = SPELL_CYCLE[phase - 1]
	var sp: int = cyc[_cycle % cyc.size()]
	_cycle += 1
	if sp == Spell.CHARGE and not has_los:
		sp = Spell.WISPS # un mur entre eux : la ruée finirait dans le mur
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.5)
	match sp:
		Spell.CHARGE:
			_chain_left = CHARGE_CHAIN[phase - 1]
			_start_charge(dir, BossPace.windup(&"charge", phase))
		Spell.WISPS:
			aim = dir
			_face(aim)
			state = S.WISPS
			_t = 0.0
			_dur = BossPace.windup(&"spell", phase)
			pace.wind(&"spell")
			vis.play_attack(&"cast_a", _dur, aim)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)
		Spell.LEAP:
			state = S.VANISH
			_t = 0.0
			_dur = vis.play_special(&"vanish")
			if _dur <= 0.0:
				_dur = 8.0 / ANIM_FPS
			# armement total (disparition + réapparition jusqu'à l'impact) >= celui d'un bond ; vanish reste tenu
			_dur = maxf(_dur, BossPace.windup(&"charge", phase) - REAPPEAR_IMPACT_FRAME / ANIM_FPS)
			pace.wind(&"charge")
			_leap_total = _dur + REAPPEAR_IMPACT_FRAME / ANIM_FPS
			_leap_to = _walkable(ppos)
			e.telegraph.show_circle(_leap_to, LEAP_R_U * U)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)


func _start_charge(dir: Vector2, windup: float) -> void:
	aim = dir
	_face(aim)
	state = S.CHARGE_WIND
	_t = 0.0
	_dur = windup
	pace.wind(&"charge")
	vis.play_attack(&"cast_b", _dur, aim)
	e.telegraph.show_line(_line_origin(), aim.angle(), CHARGE_LEN_U[phase - 1] * U + e.radius_px * CHARGE_BACK, CHARGE_W_U * U)
	e._sfx(&"telegraph.boss.heavy", 0.0, true)


## La ligne de charge part de sous le corps (captures : partie du centre logique, elle semblait naître devant le cerf).
func _line_origin() -> Vector2:
	return e.position - aim * e.radius_px * CHARGE_BACK


## Armement de la charge : la ligne suit le joueur (CHARGE_TRACK) puis se fige ; la lumière monte.
func _charge_windup(dir: Vector2) -> void:
	var k := clampf(_t / _dur, 0.0, 1.0)
	if k < CHARGE_TRACK and dir.length_squared() > 0.0001:
		aim = dir
		e.telegraph.rotation = aim.angle()
		vis.set_strike_dir(aim) # fente d'armement dans l'axe de la ligne
	_face(aim)
	e.telegraph.global_position = _line_origin()
	e.telegraph.set_progress(k)
	_light_boost(CHARGE_LIGHT_BOOST * k * k)
	_sync_antlers(true)
	if _t >= _dur:
		_sync_antlers(false)
		_log(&"charge", &"cast_b")
		pace.act()
		state = S.CHARGE_DASH
		_t = 0.0
		_dash_left = CHARGE_LEN_U[phase - 1] * U
		_dash_hit = false
		_trail_acc = TRAIL_STEP_U * U # une traînée dès le départ
		e._sfx(&"enemy.shockwave.heavy", 0.0, true)


func _dash_step(delta: float, player: Node2D, ppos: Vector2) -> void:
	var step := minf(CHARGE_SPEED_U * U * delta, _dash_left)
	_dash_left -= step
	var want := e.position + aim * step
	var p := e.nav.resolve(want, e.radius_px) if e.nav else want
	var blocked := p.distance_squared_to(want) > 4.0
	var moved := p.distance_to(e.position)
	e.position = p
	_face(aim)
	vis.set_action(&"dash") # charge_<dir> (C7D), repli walk_pN
	_trail_acc += moved
	if _trail_acc >= TRAIL_STEP_U * U:
		_trail_acc = 0.0
		_drop_trail(e.position)
	if not _dash_hit and player != null and e.position.distance_to(ppos) <= e.radius_px + PLAYER_R:
		_dash_hit = true
		e._hit_player(player, e.damage * Balance.boss_attack_coef(&"cerf", &"charge"))
	if _dash_left <= 0.0 or blocked:
		e.telegraph.hide_telegraph()
		_light_boost(0.0)
		if _chain_left > 0:
			_chain_left -= 1
			pace.strike(&"charge", phase, false) # arrêt net, replanté pour la charge suivante
			var to := ppos - e.position
			_start_charge(to.normalized() if to.length_squared() > 1.0 else aim, CHAIN_WINDUP)
		else:
			pace.strike(&"charge", phase) # arrêt net en fin de course, récupération immobile
			state = S.CHASE
			_attack_cd = maxf(_attack_cd, 0.5)


## Énergie de la lumière du boss : base de la phase + boost (armement de la charge, lanternes).
func _light_boost(b: float) -> void:
	if e._light == null:
		return
	var pi := phase - 1
	e._light.set_energy(LIGHT_ENERGY[pi] + b)
	e._light.set_radius_mult(LIGHT_RADIUS[pi] * (1.0 + 0.35 * b))


## Point praticable le plus proche (nav), pour la réapparition.
func _walkable(p: Vector2) -> Vector2:
	return e.nav.resolve(p, e.radius_px) if e.nav else p


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


# --- Lanternes de charge et follet tiré (lot C7D) --------------------------------

## Calque additif des lanternes (antlers_charge_<dir>, émission seule) posé sur le corps : mêmes échelle
## et pivot, frame recopiée de spell_b_<dir> pendant l'armement.
func _build_antlers() -> void:
	var body := vis.body_sprite()
	if body == null or _frames == null or not _frames.has_animation(&"antlers_charge_s"):
		return
	_antlers = AnimatedSprite2D.new()
	_antlers.name = &"CerfAntlersCharge"
	_antlers.sprite_frames = _frames
	_antlers.animation = &"antlers_charge_s"
	_antlers.centered = body.centered
	_antlers.offset = body.offset
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_antlers.material = mat
	_antlers.visible = false
	body.add_child(_antlers)


func _sync_antlers(on: bool) -> void:
	if not is_instance_valid(_antlers):
		return
	var body := vis.body_sprite()
	var anim := String(body.animation) if body != null else ""
	if not on or not anim.begins_with("spell_b_"):
		_antlers.visible = false
		return
	var n := StringName("antlers_charge_" + anim.substr(8))
	if not _frames.has_animation(n):
		_antlers.visible = false
		return
	_antlers.offset = body.offset
	if _antlers.animation != n:
		_antlers.animation = n
	_antlers.frame = mini(body.frame, _frames.get_frame_count(n) - 1)
	_antlers.visible = true


## Tir de follet (auto, loin) : projectile du pool habillé de wisp_bolt (repli : disque générique).
func _shoot_wisp(d: Vector2) -> void:
	if _frames == null or not _frames.has_animation(&"wisp_bolt") or e.director == null:
		e._shoot(d)
		return
	e._sfx(&"enemy.shot.medium")
	var p: Node2D = e.director.fire_projectile(e, e.position + d * e.radius_px, d * Enemy.PROJECTILE_SPEED_U * U, e.current_damage())
	if p == null:
		return
	var body := vis.body_sprite()
	var k: float = absf(body.scale.x) if body != null else 1.0
	var holder := Node2D.new() # espace billboard : rotation à l'écran, sans écrasement du sol
	holder.name = &"CerfWispBolt"
	holder.scale = Iso.UNSQUASH
	holder.position = Vector2(0.0, Iso.lift_logical(WISP_HOVER_U))
	var spr := AnimatedSprite2D.new()
	EmissiveOverlay.apply(spr, _frames, 2.5)
	spr.scale = Vector2.ONE * k * WISP_BOLT_SCALE
	spr.rotation = Iso.screen_angle(d)
	holder.add_child(spr)
	EnemyProjectilePool.set_skin(p, holder)
	spr.play(&"wisp_bolt")


# --- Feux follets -----------------------------------------------------------------

func _release_wisps(n: int, toward: Vector2, ring: bool) -> void:
	if _frames == null or not _frames.has_animation(&"wisp"):
		return
	var host := e.get_parent()
	var body := vis.body_sprite()
	var sc: Vector2 = body.scale if body != null else Vector2(1.4, 2.8)
	var base := toward.angle() if toward.length_squared() > 0.0001 else 0.0
	for i in n:
		if _wisps.size() >= WISP_MAX:
			_free_wisp(_wisps.pop_front())
		var a := base + (TAU * i / float(n) if ring else (i - (n - 1) * 0.5) * 0.45)
		var v := Vector2.from_angle(a)
		var node := Node2D.new()
		node.name = &"CerfWisp"
		var spr := AnimatedSprite2D.new()
		EmissiveOverlay.apply(spr, _frames, 2.5)
		spr.scale = sc
		spr.position = Vector2(0.0, Iso.lift_logical(WISP_HOVER_U))
		node.add_child(spr)
		host.add_child(node)
		spr.play(&"wisp")
		spr.frame = i % 6
		var pos := e.position + v * e.radius_px * 0.6
		node.position = pos
		var light := LightRig.attach(node, &"boss_cerf_hooves")
		_wisps.append({"node": node, "spr": spr, "pos": pos, "vel": v, "state": 0, "t": 0.0, "tele": null,
			"light": light, "hit": false})


func _update_wisps(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := _wisps.size() - 1
	while i >= 0:
		var w: Dictionary = _wisps[i]
		w["t"] = float(w["t"]) + delta
		var t: float = w["t"]
		match int(w["state"]):
			0: # dérive vers le joueur
				var pos: Vector2 = w["pos"]
				var vel: Vector2 = w["vel"]
				var want := (ppos - pos)
				if want.length_squared() > 1.0:
					var turn := clampf(angle_difference(vel.angle(), want.angle()), -WISP_TURN * delta, WISP_TURN * delta)
					vel = vel.rotated(turn)
				pos += vel * WISP_SPEED_U * U * delta
				w["pos"] = pos
				w["vel"] = vel
				if t >= WISP_SEEK_S or pos.distance_to(ppos) <= WISP_TRIGGER_U * U:
					w["state"] = 1
					w["t"] = 0.0
					var tele := EnemyTelegraph.new()
					e.get_parent().add_child(tele)
					tele.show_circle(pos, WISP_R_U * U)
					w["tele"] = tele
					e._sfx(&"telegraph.warn_light.light", -4.0)
			1: # arrêté : cercle d'alerte
				var tele := w["tele"] as EnemyTelegraph
				if is_instance_valid(tele):
					tele.set_progress(t / WISP_ARM_S)
				if t >= WISP_ARM_S:
					w["state"] = 2
					w["t"] = 0.0
					if is_instance_valid(tele):
						tele.queue_free()
					w["tele"] = null
					(w["spr"] as AnimatedSprite2D).play(&"wisp_explode")
			2: # explosion : dégâts quand la frame d'expansion maximale s'affiche (lue sur le sprite : reste
				# calé même si l'image ralentit ; garde-fou en temps si l'anim ne tourne pas)
				var spr := w["spr"] as AnimatedSprite2D
				if not w["hit"] and (spr.frame >= WISP_IMPACT_FRAME or t >= WISP_IMPACT_FRAME / ANIM_FPS + 0.3):
					w["hit"] = true
					var pos: Vector2 = w["pos"]
					if player != null and pos.distance_to(ppos) <= WISP_R_U * U + PLAYER_R:
						e._hit_player(player, e.damage * Balance.boss_attack_coef(&"cerf", &"wisp"))
					e._sfx(&"enemy.shockwave.heavy", -6.0)
					events.append({"kind": &"wisp_boom", "phase": phase, "anim": spr.animation, "frame": spr.frame,
						"expect": WISP_IMPACT_FRAME, "lag": 0.0})
				if w["hit"] and (not spr.is_playing() or t >= 8.0 / ANIM_FPS + 0.6):
					_free_wisp(w)
					_wisps.remove_at(i)
					i -= 1
					continue
		(w["node"] as Node2D).position = w["pos"]
		i -= 1


func _free_wisp(w: Dictionary) -> void:
	if w.get("light") != null:
		(w["light"] as LightRig.Handle).release()
	if is_instance_valid(w.get("tele")):
		(w["tele"] as Node).queue_free()
	if is_instance_valid(w.get("node")):
		(w["node"] as Node).queue_free()


# --- Traînée de la charge -----------------------------------------------------------

func _drop_trail(pos: Vector2) -> void:
	if _frames == null or not _frames.has_animation(&"ground_wisp_trail"):
		return
	if _trails.size() >= TRAIL_MAX:
		var old: Dictionary = _trails.pop_front()
		if is_instance_valid(old["node"]):
			(old["node"] as Node).queue_free()
	var body := vis.body_sprite()
	var spr := AnimatedSprite2D.new()
	spr.name = &"CerfTrail"
	EmissiveOverlay.apply(spr, _frames, 1.6)
	spr.scale = (body.scale if body != null else Vector2(1.4, 2.8)) * 0.9
	spr.offset = Vector2(0.0, -14.0) # pied du follet (ligne 46 de la frame 64) sur le point
	spr.z_index = -1
	e.get_parent().add_child(spr)
	spr.position = pos
	spr.play(&"ground_wisp_trail")
	spr.frame = _trails.size() % 6
	_trails.append({"node": spr, "pos": pos, "life": TRAIL_LIFE[phase - 1], "max": TRAIL_LIFE[phase - 1]})


func _update_trails(delta: float, player: Node2D, ppos: Vector2) -> void:
	_trail_hit_cd -= delta
	var hurt := phase >= TRAIL_HURT_PHASE
	var i := _trails.size() - 1
	while i >= 0:
		var tr: Dictionary = _trails[i]
		tr["life"] = float(tr["life"]) - delta
		var node := tr["node"] as CanvasItem
		if float(tr["life"]) <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_trails.remove_at(i)
			i -= 1
			continue
		node.modulate.a = clampf(float(tr["life"]) / minf(0.6, float(tr["max"])), 0.0, 1.0)
		if hurt and _trail_hit_cd <= 0.0 and player != null and (tr["pos"] as Vector2).distance_to(ppos) <= TRAIL_R_U * U + PLAYER_R:
			_trail_hit_cd = TRAIL_HIT_CD
			e._hit_player(player, e.damage * Balance.boss_attack_coef(&"cerf", &"trail"))
		i -= 1
