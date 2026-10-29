class_name JarBearerBrain
extends RefCounted
## IA de la Porteuse de jarres (boss d'étage 1, Terrasses noyées ; docs/Design_Etages.md §5.1). Créée par
## Enemy.activate_boss quand le skin du boss est « jar_bearer », appelée par Enemy.tick (branche BOSS_TIER). Même
## contrat que CerfBrain / RecluseBrain : coups télégraphiés face au joueur, dégâts à la frame d'impact,
## coefficients Balance.BOSS_ATTACK_COEF[&"jar_bearer"]. Sans sprites (lot Codex N1d,
## art/tools/night/requests_bosses1.md) : silhouette et effets dessinés provisoires (Floor1Fx, RecluseFx) ; chaque
## extra du .tres (jar, jar_shatter, mother_jar, puddle, orbit_jar) remplace son repli dès qu'il est livré.
##
## Esprit de lanterne de pierre de 3,0 u, foyer d'eau cyan, 6 jarres de terre sanglées sur le dos.
## Phases (PV, Balance.BOSS_PHASE_THRESHOLDS : 70 % / 35 %) ; transition = anim trans_pN (boss figé).
## - Phase 1 « Offrandes » : jet de jarre (auto : la jarre part à la frame d'impact, vol en cloche 0,75 s, éclate
##   en cercle de 1,5 u ; le point de chute est marqué dès l'armement) ; Pluie de jarres (spell_a : 5 cercles de
##   2 u allumés l'un après l'autre, chacun 1 s) — SURPRISE : la pluie ANTICIPE (les cercles suivent la course du
##   joueur, en spirale s'il est immobile) ; Jarre-mère (spell_b : posée près du joueur, obstacle cassable de
##   1 u qui explose après 3 s en anneau de 1,2 à 5 u : se coller à la jarre protège, la casser l'éteint).
## - Phase 2 « Vase » : chaque jarre brisée (coups, pluie, jarre-mère) laisse une flaque de vase qui ralentit ;
##   2 jarres-mères par lancer.
## - Phase 3 « Lévitation » : elle s'élève, 4 jarres tournent autour d'elle (télégraphe continu de l'orbite) ;
##   l'orbite RESPIRE (de 2,5 à 4,5 u, le liseré annonce le rayon visé) et change de sens à chaque expiration.
## Trace après la mort : les flaques de vase restent jusqu'à la fin de la charge du gros pilier.

enum S { CHASE, THROW, RAIN, MOTHER, STAGGER }
enum Spell { RAIN, MOTHER }

const ID := &"jar_bearer"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const CYAN := Color(0.369, 0.784, 1.0)
const VASE := Color(0.30, 0.33, 0.24)
## Par phase (index phase - 1)
const SPEED_MULT := [0.95, 1.0, 0.6]
const AUTO_CD := [1.9, 1.7, 1.6]
const SPELL_CD := [4.8, 4.4, 4.0]
const LIGHT_ENERGY := [2.8, 3.2, 4.0]
const LIGHT_RADIUS := [1.2, 1.35, 1.5]
const LIGHT_LIFT_U := 1.9
const FEET_ENERGY := [1.8, 2.2, 2.8]
const BODY_GAIN := Color(1.2, 1.22, 1.24)
const LEVITATE_U := 0.5
# Jet de jarre (auto)
const THROW_RANGE_U := 9.0
## Rythme (BossPace, Balance.BOSS_PACE_*) : jet de jarre = &"auto" ; pluie et jarre-mère = &"spell" (armement
## planté, récupération immobile ; la pluie la garde plantée jusqu'au dernier cercle).
const THROW_FLIGHT := 0.75
const THROW_R_U := 0.75 ## cercle de 1,5 u
const THROW_ARC_U := 2.2 ## hauteur de la cloche
# Pluie de jarres (spell_a)
const RAIN_COUNT := 5
const RAIN_R_U := 1.0
const RAIN_GAP_U := 0.5
const RAIN_STAGGER := 0.3
const RAIN_LEAD_U := 2.6 ## pas entre deux cercles le long de la course du joueur
const RAIN_DROP_U := 4.0 ## hauteur d'où tombe la jarre
# Jarre-mère (spell_b)
const MOTHER_FUSE := 3.0
const MOTHER_R_U := 0.5 ## obstacle de 1 u
const MOTHER_R0_U := 1.2 ## disque sûr contre la jarre
const MOTHER_R1_U := 5.0
const MOTHER_DIST_U := 2.6
const MOTHER_HP_FRAC := 0.03 ## PV d'une jarre-mère (part des PV max de la porteuse)
const MOTHER_COUNT := [1, 2, 2]
# Flaques de vase (P2+)
const PUDDLE_R_U := 1.0
const PUDDLE_LIFE := 7.0
const PUDDLE_MAX := 12
# Orbite (P3)
const ORBIT_JARS := 4
const ORBIT_R := Vector2(2.5, 4.5) ## u
const ORBIT_BREATH_S := 5.0
const ORBIT_SPEED := 1.22 ## 70°/s
const ORBIT_HIT_R_U := 0.55
const ORBIT_HIT_CD := 1.0
const ORBIT_BAND_U := 0.6

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = []
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var mothers_broken := 0
var mothers_blown := 0
var orbit_dir := 1.0
var orbit_flips := 0
var pace: BossPace ## armement planté, impact, récupération immobile (scripts/enemies/boss_pace.gd)

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.2
var _spell_cd := 2.4
var _cycle := 0
var _ppos := Vector2.ZERO
var _pvel := Vector2.ZERO ## vitesse lissée du joueur (px/s) : la pluie anticipe
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _feet: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = []
var _throws: Array[Dictionary] = [] ## {from, to, t, jar, tele, launched}
var _rain: Array[Dictionary] = [] ## {pos, t0, tele, jar, shown}
var _rain_hit := false
var _rain_logged := false
var _rain_wind := 1.0 ## armement de la pluie = télégraphe de chaque cercle (BossPace &"spell")
var _mothers: Array[Dictionary] = [] ## {body, t, ring}
var _orbit: Array[Dictionary] = [] ## {node, cd}
var _orbit_a := 0.0
var _orbit_t := 0.0
var _orbit_ring: RecluseFx = null
var _fx: Array[Dictionary] = []
var _body: Floor1Fx = null
var _hz: Floor1Hazards = null


func _init(enemy: Enemy) -> void:
	e = enemy
	vis = enemy.visual as EnemyVisual
	pace = BossPace.new(enemy)
	_rng.randomize()
	_frames = EnemyVisual.boss_frames(ID)
	if e._light != null:
		e._light.set_preset(&"boss_cerf")
		e._light.set_color(CYAN)
		e._light.position = Vector2(0.0, Iso.lift_logical(LIGHT_LIFT_U))
	_feet = LightRig.attach(e, &"boss_cerf_hooves", {"color": CYAN})
	if vis.body_sprite() != null:
		vis.body_sprite().self_modulate = BODY_GAIN
	else:
		_body = Floor1Fx.make(Floor1Fx.Kind.BODY_JAR_BEARER)
		_body.name = &"JarBearer_body"
		e.add_child(_body)
		vis.self_modulate = Color(1, 1, 1, 0)
	_hz = Floor1Hazards.create(e, _frames, "JarBearer")
	_apply_phase_look()


func clear() -> void:
	if pace != null:
		pace.cancel() # arrêt sur image en cours rendu (corps remis en pool)
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	if is_instance_valid(_hz):
		if killed:
			_hz.on_boss_dead()
		else:
			_hz.release()
	_hz = null
	for th in _throws:
		_free_keys(th, ["jar"])
	_throws.clear()
	for r in _rain:
		_free_keys(r, ["jar"])
	_rain.clear()
	for m in _mothers:
		_free_mother(m)
	_mothers.clear()
	for o in _orbit:
		_free_keys(o, ["node"])
	_orbit.clear()
	if is_instance_valid(_orbit_ring):
		_orbit_ring.queue_free()
	_orbit_ring = null
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	for t in _teles:
		if is_instance_valid(t):
			t.queue_free()
	_teles.clear()
	if is_instance_valid(_body):
		_body.queue_free()
	_body = null
	if _feet != null:
		_feet.release()
	_feet = null
	if vis != null and is_instance_valid(vis):
		vis.self_modulate = Color.WHITE
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


## Transition figée ; armement et récupération plantés (ni marche ni séparation de foule).
func owns_motion() -> bool:
	return state == S.STAGGER or pace.planted()


## Super-armure le temps d'un coup : un recul ferait glisser la porteuse plantée.
func ignores_knockback() -> bool:
	return pace.planted()


func damage_taken_mult() -> float:
	return Balance.boss_damage_taken_mult(ID, phase)


func hazards() -> Floor1Hazards:
	return _hz if is_instance_valid(_hz) else null


func mother_count() -> int:
	return _mothers.size()


func mothers() -> Array:
	var out: Array = []
	for m in _mothers:
		if is_instance_valid(m["body"]):
			out.append(m["body"])
	return out


func orbit_count() -> int:
	return _orbit.size()


func orbit_radius() -> float:
	return lerpf(ORBIT_R.x, ORBIT_R.y, 0.5 - 0.5 * cos(TAU * _orbit_t / (2.0 * ORBIT_BREATH_S))) * U


func rain_count() -> int:
	return _rain.size()


func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	if delta > 0.0:
		_pvel = _pvel.lerp((ppos - _ppos) / delta if _ppos != Vector2.ZERO else Vector2.ZERO, minf(1.0, delta * 6.0))
	_ppos = ppos
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase:
		_enter_phase(ph)
	_update_throws(delta, player, ppos)
	_update_rain(delta, player, ppos)
	_update_mothers(delta, player, ppos)
	_update_orbit(delta, player, ppos)
	_update_fx(delta)
	_update_body(delta)
	_attack_cd -= delta
	_spell_cd -= delta
	_t += delta
	var pi := phase - 1
	match state:
		S.STAGGER:
			if _t >= _dur:
				state = S.CHASE
				if phase >= 3:
					_build_orbit()
			return Vector2.ZERO
		S.THROW:
			if _t >= _dur:
				_release_throw()
			return Vector2.ZERO
		S.RAIN:
			if _rain.is_empty() or _t >= _dur:
				pace.strike(&"spell", phase) # dernier cercle tombé : récupération immobile
				state = S.CHASE
			return Vector2.ZERO
		S.MOTHER:
			if _t >= _dur:
				_place_mothers(ppos)
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering() or vis.is_attacking(): # récupération immobile (fenêtre de punition), fin de fente
		_face(dir)
		return Vector2.ZERO
	if _spell_cd <= 0.0 and dist < 12.0 * U:
		_start_spell(dir, ppos)
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < THROW_RANGE_U * U:
		_start_throw(dir, ppos)
		return Vector2.ZERO
	var keep := 4.5 * U # elle lance de loin : garde ses distances
	var go := path_dir if path_dir != Vector2.ZERO else dir
	if dist > keep * 1.4:
		_face(go)
		return go * e.speed_px * SPEED_MULT[pi]
	if dist < keep * 0.6:
		_face(dir)
		return -dir * e.speed_px * SPEED_MULT[pi] * 0.6
	_face(dir)
	return Vector2.ZERO


# --- Phases --------------------------------------------------------------------

func _enter_phase(ph: int) -> void:
	_cancel()
	phase = ph
	state = S.STAGGER
	_t = 0.0
	_dur = 8.0 / ANIM_FPS + 0.25
	_spell_cd = maxf(_spell_cd, _dur + 1.0)
	_attack_cd = maxf(_attack_cd, _dur + 0.4)
	_cycle = 0
	_apply_phase_look()
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.6, {"color": CYAN, "radius": 1.6})
	_shatter_fx(e.position, 1.2)
	events.append({"kind": &"phase", "phase": ph})


func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	for r in _rain:
		if is_instance_valid(r.get("tele")):
			(r["tele"] as EnemyTelegraph).hide_telegraph()
		_free_keys(r, ["jar"])
	_rain.clear()


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.08 if phase >= 3 else -1.0, 1.2)
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])
	if _body != null:
		_body.glow = 0.5 + 0.25 * phase
		_body.jars = 6 if phase < 3 else 2 # phase 3 : 4 jarres en orbite
		_body.queue_redraw()


func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


# --- Jet de jarre (auto) ---------------------------------------------------------------

func _start_throw(dir: Vector2, ppos: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.THROW
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	var to := _walkable(ppos)
	var tele := _tele(_free_tele_index())
	tele.show_circle(to, THROW_R_U * U, EnemyTelegraph.Weight.LIGHT)
	_throws.append({"from": e.position, "to": to, "t": -_dur, "wind": _dur, "jar": null, "tele": tele, "launched": false})
	e._sfx(&"telegraph.warn_light.light", -4.0)


## Frame d'impact de l'auto : la jarre quitte la main et part en cloche vers le point marqué.
func _release_throw() -> void:
	_log(&"throw", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE
	for th in _throws:
		if not th["launched"]:
			th["launched"] = true
			th["from"] = e.position
			th["jar"] = _jar_node(0.8)


func _update_throws(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := _throws.size() - 1
	while i >= 0:
		var th: Dictionary = _throws[i]
		th["t"] = float(th["t"]) + delta
		var t := float(th["t"])
		var tele := th["tele"] as EnemyTelegraph
		var wind := float(th["wind"])
		tele.set_progress((t + wind) / (THROW_FLIGHT + wind))
		var jar := th["jar"] as Node2D
		if is_instance_valid(jar):
			var k := clampf(t / THROW_FLIGHT, 0.0, 1.0)
			jar.global_position = (th["from"] as Vector2).lerp(th["to"], k)
			jar.position.y += Iso.lift_logical(THROW_ARC_U * 4.0 * k * (1.0 - k) + 1.0 * (1.0 - k))
		if th["launched"] and t >= THROW_FLIGHT:
			tele.hide_telegraph()
			_free_keys(th, ["jar"])
			_break_jar(th["to"], THROW_R_U)
			if player != null and (th["to"] as Vector2).distance_to(ppos) <= THROW_R_U * U + PLAYER_R:
				e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"jar"))
				events.append({"kind": &"jar_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			_throws.remove_at(i)
		elif not th["launched"] and state != S.THROW: # armement annulé (transition)
			tele.hide_telegraph()
			_throws.remove_at(i)
		i -= 1


# --- Sorts ---------------------------------------------------------------------------

func _start_spell(dir: Vector2, ppos: Vector2) -> void:
	var sp: int = Spell.RAIN if _cycle % 2 == 0 else Spell.MOTHER
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	_t = 0.0
	match sp:
		Spell.RAIN:
			state = S.RAIN
			_rain_wind = BossPace.windup(&"spell", phase)
			pace.wind(&"spell")
			vis.play_attack(&"cast_a", _rain_wind, Vector2.ZERO) # lance les jarres au ciel ; impact = 1er cercle
			_place_rain(ppos)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)
		Spell.MOTHER:
			state = S.MOTHER
			_dur = BossPace.windup(&"spell", phase)
			pace.wind(&"spell")
			vis.play_attack(&"cast_b", _dur, aim) # décroche la grande jarre et la pose
			e._sfx(&"telegraph.boss.heavy", 0.0, true)


# --- Pluie de jarres -------------------------------------------------------------------

## 5 cercles : le premier sur le joueur, les suivants le long de sa course (anticipation), en spirale s'il
## est immobile ; jamais chevauchants (écart ≥ 0,5 u).
func _place_rain(ppos: Vector2) -> void:
	_rain_hit = false
	_rain_logged = false
	var min_d := (2.0 * RAIN_R_U + RAIN_GAP_U) * U
	var moving := _pvel.length() > 0.8 * U
	var d := _pvel.normalized() if moving else Vector2.from_angle(_rng.randf() * TAU)
	var pts: Array[Vector2] = [_walkable(ppos)]
	var i := 1
	while pts.size() < RAIN_COUNT and i < RAIN_COUNT * 4:
		var p: Vector2
		if moving:
			p = ppos + d * RAIN_LEAD_U * U * i + d.orthogonal() * (RAIN_LEAD_U * 0.35 * U) * (1.0 if i % 2 == 0 else -1.0)
		else:
			p = ppos + Vector2.from_angle(d.angle() + i * 2.39996) * 2.7 * sqrt(float(i)) * U
		p = _walkable(p)
		i += 1
		var ok := true
		for q in pts:
			if q.distance_to(p) < min_d:
				ok = false
				break
		if ok:
			pts.append(p)
	for k in pts.size():
		var tele := _tele(_free_tele_index())
		tele.hide_telegraph()
		_rain.append({"pos": pts[k], "t0": -k * RAIN_STAGGER, "tele": tele, "jar": null, "shown": false})
	_dur = _rain_wind + (pts.size() - 1) * RAIN_STAGGER + 0.1


func _update_rain(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := 0
	while i < _rain.size():
		var r: Dictionary = _rain[i]
		r["t0"] = float(r["t0"]) + delta
		var t := float(r["t0"])
		var tele := r["tele"] as EnemyTelegraph
		if t >= 0.0 and not r["shown"]:
			r["shown"] = true
			tele.show_circle(r["pos"], RAIN_R_U * U)
			r["jar"] = _jar_node(1.0)
			e._sfx(&"telegraph.warn_light.light", -6.0)
		if r["shown"]:
			tele.set_progress(t / _rain_wind)
			var jar := r["jar"] as Node2D
			if is_instance_valid(jar): # la jarre tombe du ciel pendant le télégraphe (accélère)
				var k := clampf(t / _rain_wind, 0.0, 1.0)
				jar.global_position = r["pos"]
				jar.position.y += Iso.lift_logical(RAIN_DROP_U * (1.0 - k * k))
				jar.modulate.a = clampf(k * 3.0, 0.0, 1.0)
		if t >= _rain_wind:
			tele.hide_telegraph()
			_free_keys(r, ["jar"])
			var pos: Vector2 = r["pos"]
			if not _rain_logged:
				_rain_logged = true
				_log(&"rain", &"cast_a")
			_break_jar(pos, RAIN_R_U)
			e._sfx(&"enemy.shockwave.heavy", -4.0, true)
			if not _rain_hit and player != null and pos.distance_to(ppos) <= RAIN_R_U * U + PLAYER_R:
				_rain_hit = true # un même lancer ne touche qu'une fois
				e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"rain"))
				events.append({"kind": &"rain_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			_rain.remove_at(i)
			continue
		i += 1


# --- Jarre-mère ------------------------------------------------------------------------

func _place_mothers(ppos: Vector2) -> void:
	_log(&"mother", &"cast_b")
	pace.strike(&"spell", phase)
	state = S.CHASE
	var n: int = MOTHER_COUNT[phase - 1]
	var base := (e.position - ppos).angle() # entre le joueur et la porteuse, puis de part et d'autre
	for k in n:
		var a := base + (0.0 if n == 1 else (k - 0.5) * 1.6)
		var p := _walkable(ppos + Vector2.from_angle(a) * MOTHER_DIST_U * U)
		var body := JarBearerJar.spawn(e.get_parent(), p, maxf(e.max_hp * MOTHER_HP_FRAC, 1.0), _frames, MOTHER_R_U * U)
		body.block(e.nav) # obstacle réel : bloque le joueur, contourné par les monstres (NavField)
		var ring := RecluseFx.make(RecluseFx.Kind.RING_TELE, Color.WHITE, 0)
		ring.name = &"JarBearer_ring"
		RecluseFx.add_to_tele_layer(ring, e.get_parent())
		ring.global_position = p
		ring.set_param(MOTHER_R1_U * U, MOTHER_R0_U * U, 0.0)
		var glow := LightRig.attach(body, &"boss_cerf_hooves", {"color": CYAN})
		_mothers.append({"body": body, "t": 0.0, "ring": ring, "pos": p, "light": glow})
	e._sfx(&"enemy.shockwave.heavy", -2.0, true)


func _update_mothers(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := _mothers.size() - 1
	while i >= 0:
		var m: Dictionary = _mothers[i]
		m["t"] = float(m["t"]) + delta
		var body := m["body"] as JarBearerJar
		var ring := m["ring"] as RecluseFx
		var pos: Vector2 = m["pos"]
		if not is_instance_valid(body) or body.broken: # cassée à temps : s'éteint sans exploser
			mothers_broken += 1
			events.append({"kind": &"mother_broken", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			_break_jar(pos, MOTHER_R_U * 2.0)
			_free_mother(m)
			_mothers.remove_at(i)
			i -= 1
			continue
		var k := float(m["t"]) / MOTHER_FUSE
		if is_instance_valid(ring):
			ring.set_param(MOTHER_R1_U * U, MOTHER_R0_U * U, k)
			ring.modulate.a = 0.75 + 0.25 * (1.0 if k > 0.75 and fmod(float(m["t"]), 0.2) < 0.1 else 0.0)
		if k >= 1.0:
			mothers_blown += 1
			e._sfx(&"enemy.shockwave.heavy", 3.0, true)
			LightRig.flash(pos, &"boss_lightning", 0.3, {"color": CYAN, "radius": 1.4})
			_break_jar(pos, MOTHER_R1_U * 0.4)
			_ring_fx(pos)
			var d := ppos.distance_to(pos)
			if player != null and d >= MOTHER_R0_U * U - PLAYER_R * 0.5 and d <= MOTHER_R1_U * U + PLAYER_R:
				e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"mother"))
				events.append({"kind": &"mother_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			events.append({"kind": &"mother_blast", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			_free_mother(m)
			_mothers.remove_at(i)
		i -= 1


func _free_mother(m: Dictionary) -> void:
	var body := m.get("body") as JarBearerJar
	if is_instance_valid(body):
		body.retire()
		body.queue_free()
	if is_instance_valid(m.get("ring")):
		(m["ring"] as Node).queue_free()
	var l := m.get("light") as LightRig.Handle
	if l != null:
		l.release()
	m["light"] = null


func _ring_fx(pos: Vector2) -> void:
	var f := RecluseFx.make(RecluseFx.Kind.BAND, Color(CYAN.r, CYAN.g, CYAN.b, 0.35), 0)
	f.radius = MOTHER_R1_U * U
	f.inner = MOTHER_R0_U * U
	f.width = 3.0
	f.color2 = Color(0.9, 0.97, 1.0, 0.7)
	f.name = &"JarBearer_blast"
	RecluseFx.add_to_tele_layer(f, e.get_parent())
	f.global_position = pos
	_fx.append({"node": f, "life": 0.45, "max": 0.45})


# --- Orbite (phase 3) ----------------------------------------------------------------------

func _build_orbit() -> void:
	if not _orbit.is_empty():
		return
	_orbit_t = 0.0
	for j in ORBIT_JARS:
		var n := _jar_node(1.1)
		n.name = &"JarBearer_orbit"
		_orbit.append({"node": n, "cd": 0.0})
	_orbit_ring = RecluseFx.make(RecluseFx.Kind.RING_TELE, Color.WHITE, 0)
	_orbit_ring.name = &"JarBearer_orbit_ring"
	RecluseFx.add_to_tele_layer(_orbit_ring, e.get_parent())
	_orbit_ring.modulate = Color(1, 1, 1, 0.55)
	e._sfx(&"telegraph.warn_heavy.heavy", 0.0, true)


func _update_orbit(delta: float, player: Node2D, ppos: Vector2) -> void:
	if _orbit.is_empty():
		return
	var before := fmod(_orbit_t, 2.0 * ORBIT_BREATH_S)
	_orbit_t += delta
	if fmod(_orbit_t, 2.0 * ORBIT_BREATH_S) < before: # fin d'une expiration : sens inversé
		orbit_dir = -orbit_dir
		orbit_flips += 1
		e._sfx(&"telegraph.warn_light.light", 0.0, true)
	_orbit_a = wrapf(_orbit_a + ORBIT_SPEED * orbit_dir * delta, 0.0, TAU)
	var r := orbit_radius()
	if is_instance_valid(_orbit_ring): # télégraphe continu : la bande de l'orbite (rayon courant)
		_orbit_ring.global_position = e.position
		_orbit_ring.set_param(r + ORBIT_BAND_U * 0.5 * U, maxf(r - ORBIT_BAND_U * 0.5 * U, 0.0), 1.0)
	for j in _orbit.size():
		var o: Dictionary = _orbit[j]
		o["cd"] = float(o["cd"]) - delta
		var p := e.position + Vector2.from_angle(_orbit_a + TAU * j / float(ORBIT_JARS)) * r
		var n := o["node"] as Node2D
		if is_instance_valid(n):
			n.global_position = p
			n.position.y += Iso.lift_logical(0.9)
		if player != null and float(o["cd"]) <= 0.0 and p.distance_to(ppos) <= ORBIT_HIT_R_U * U + PLAYER_R and state != S.STAGGER:
			for q in _orbit:
				q["cd"] = ORBIT_HIT_CD # un coup par seconde au plus, toutes jarres confondues
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"orbit"))
			events.append({"kind": &"orbit_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})


# --- Jarres et vase -------------------------------------------------------------------------

## Jarre volante (extra `jar` du .tres, sinon jarre dessinée), sous le conteneur des monstres.
func _jar_node(size_u: float) -> Node2D:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"jar"):
		var s := Floor1Fx.sprite(_frames, &"jar", "JarBearer_", 2.0)
		s.scale = Floor1Fx.billboard(size_u * U, 64.0)
		s.play(&"jar")
		n = s
	else:
		var f := Floor1Fx.make(Floor1Fx.Kind.JAR, 1)
		f.color = Floor1Fx.CLAY
		f.scale_u = size_u
		n = f
	n.name = &"JarBearer_jar"
	e.get_parent().add_child(n)
	n.global_position = e.position
	return n


## Jarre qui éclate en `pos` : éclats (extra `jar_shatter`), et dès la phase 2 une flaque de vase (trace).
func _break_jar(pos: Vector2, r_u: float) -> void:
	_shatter_fx(pos, r_u)
	if phase < 2 or not is_instance_valid(_hz):
		return
	if _hz.count(&"puddle") >= PUDDLE_MAX:
		for z in _hz.zones:
			if z["kind"] == &"puddle":
				z["kind"] = &"puddle_drying"
				z["life"] = float(z["age"]) + 0.3
				break
	var n: Node2D
	if _frames != null and _frames.has_animation(&"puddle"):
		var s := Floor1Fx.sprite(_frames, &"puddle", "JarBearer_", 0.8, -1)
		s.scale = Vector2.ONE * (PUDDLE_R_U * U / 64.0)
		s.play(&"puddle")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.DISC, Color(VASE.r, VASE.g, VASE.b, 0.55), -1)
		f.radius = PUDDLE_R_U * U
		f.width = 2.0
		f.color2 = Color(CYAN.r * 0.6, CYAN.g * 0.6, CYAN.b * 0.6, 0.6)
		n = f
	n.name = &"JarBearer_puddle"
	_hz.add_child(n)
	n.global_position = pos
	_hz.add_zone({"kind": &"puddle", "shape": &"circle", "pos": pos, "r": PUDDLE_R_U * U, "life": PUDDLE_LIFE,
		"slow": true, "trace": true, "node": n})


func _shatter_fx(pos: Vector2, r_u: float) -> void:
	if is_instance_valid(_hz):
		_hz.burst_fx(pos, maxf(r_u, 0.6) * U, &"jar_shatter", 96.0)


# --- Silhouette provisoire -------------------------------------------------------------

func _update_body(delta: float) -> void:
	if _body == null:
		return
	var fl := 1.0 if e.is_flashing() else 0.0
	var target := Iso.lift_logical(LEVITATE_U) * (1.0 + 0.2 * sin(Time.get_ticks_msec() * 0.003)) if phase >= 3 and state != S.STAGGER else 0.0
	var nl := move_toward(_body.lift, target, 60.0 * delta)
	if absf(fl - _body.progress) > 0.01 or absf(nl - _body.lift) > 0.5:
		_body.progress = fl
		_body.lift = nl
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


# --- Outils ------------------------------------------------------------------------

func _free_keys(d: Dictionary, keys: Array) -> void:
	for k in keys:
		if is_instance_valid(d.get(k)):
			(d[k] as Node).queue_free()
		d[k] = null


## Télégraphe libre (caché) du pool, sinon un nouveau.
func _free_tele_index() -> int:
	var used := {}
	for th in _throws:
		used[th["tele"]] = true
	for r in _rain:
		used[r["tele"]] = true
	for i in _teles.size():
		if not used.has(_teles[i]):
			return i
	return _teles.size()


func _tele(i: int) -> EnemyTelegraph:
	while _teles.size() <= i:
		var t := EnemyTelegraph.new()
		t.name = &"JarBearer_tele"
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
			expect = roundi(sf.get_frame_count(anim) * vis.boss_impact_frac(action))
	events.append({"kind": kind, "phase": phase, "anim": anim, "frame": vis.current_frame(), "expect": expect,
		"lag": lag, "aim": aim, "dir4": vis.facing_dir4(), "from": e.position, "to": _ppos})
