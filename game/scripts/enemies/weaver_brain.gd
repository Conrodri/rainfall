class_name WeaverBrain
extends RefCounted
## IA de la Tisseuse (boss d'étage 2 alternatif, Forêt-brume ; docs/Design_Etages.md §5.2). Créée par
## Enemy.activate_boss quand le skin du boss est « weaver », appelée par Enemy.tick (branche BOSS_TIER).
## Même contrat que CerfBrain / RecluseBrain : coups télégraphiés face au joueur (angle libre ; le sprite prend
## la plus proche de ses 4 orientations e/s/w/n : auto/spell_a/spell_b_<dir>), dégâts à la frame d'impact
## (EnemyVisual.play_attack). Dégâts : Balance.BOSS_ATTACK_COEF[&"weaver"]. Seuils de phase 70 / 35 %.
## Sans sprites (lot Codex N2c, art/tools/night/requests_bosses2.md) : silhouette et fils dessinés
## provisoires (WeaverFx) ; chaque extra du .tres (thread, cocoon, ascend_s, drop_s, drop_dust) remplace son
## repli dès qu'il est livré.
##
## Araignée-sanctuaire de 3,3 u, pattes de bois, abdomen = lanterne fêlée menthe #9CF0C8 (l'accent du biome).
## - Phase 1 « Le métier » : morsure (auto, cône 63° de 2,6 u) ; Fils (spell_a : 3 lignes de 0,8 × 12 u en
##   éventail depuis elle, 1 s ; puis les fils RESTENT 5 s : ralentissent au contact, arrêtent les tirs des
##   monstres) ; Descente (spell_b : elle se hisse dans la canopée, intouchable ; sa lanterne glisse au sol
##   vers le joueur, cercle de 3 u qui suit puis se fige, chute 1,2 s).
## - Phase 2 (70 %) « La toile » : les fils se tendent en un anneau de 6 u autour d'elle, 2 brèches marquées
##   par des perles menthe. SURPRISE : la toile est son oreille : la toucher la fait vibrer (flash menthe) et
##   la Tisseuse TOMBE sur le point touché (même télégraphe que la descente). Passer par les brèches = silence.
## - Phase 3 (35 %) « La ponte » : 6 cocons en couronne autour du joueur (obstacles 1 u qui l'enferment),
##   éclosent en tier 1 après 3 s ; ponte reprise dans le cycle ; fils ×4 ; la lanterne fêlée vacille.
## Trace : fils et toile restent (ralentissent toujours) jusqu'à la fin de la charge du gros pilier.

enum S { CHASE, BITE, THREADS, ASCEND, HANG, DROP, COCOONS, STAGGER }
enum Spell { THREADS, DESCENT, COCOONS }

const ID := &"weaver"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const MINT := Color(0.612, 0.941, 0.784) ## #9CF0C8
const WOOD := Color(0.56, 0.52, 0.46) ## silhouette provisoire : bois clair usé (lisible sous l'aube bleue)
## Par phase (index phase - 1)
const SPEED_MULT := [1.0, 1.1, 1.15]
const AUTO_CD := [1.6, 1.45, 1.3]
const SPELL_CD := [4.2, 3.8, 3.4]
const SPELL_CYCLE := [[Spell.THREADS, Spell.DESCENT], [Spell.THREADS, Spell.DESCENT], [Spell.COCOONS, Spell.THREADS, Spell.DESCENT]]
const LIGHT_ENERGY := [1.6, 2.0, 1.7]
const LIGHT_RADIUS := [1.15, 1.3, 1.2]
const LIGHT_LIFT_U := 1.7
const FEET_ENERGY := [2.0, 2.4, 2.2]
const BODY_GAIN := Color(1.18, 1.2, 1.2)
# Morsure (auto)
const BITE_RANGE_U := 2.6
const BITE_HALF := 0.55
# Armements et récupérations : BossPace (Balance.BOSS_PACE_*) ; morsure = auto, fils et ponte = sorts,
# descente = bond (charge : la montée est l'armement planté, la chute la frame d'impact).
# Fils (spell_a)
const THREAD_COUNT := [3, 3, 4]
const THREAD_SPREAD := 0.36 ## rad entre deux fils
const THREAD_LEN_U := 12.0
const THREAD_W_U := 0.8
const THREAD_LIFE := 5.0
# Descente (spell_b)
const ASCEND_S := 0.55 ## plancher de la montée ; durée réelle = BossPace.windup(&"charge", phase) (armement planté)
const DROP_WINDUP := 1.2 ## télégraphe du cercle (règle de lisibilité : >= 0,8 s)
const DROP_TRACK := 0.55 ## part du télégraphe pendant laquelle le cercle suit le joueur
const DROP_FALL_S := 0.18
const DROP_R_U := 1.5 ## cercle de 3 u
const CANOPY_LIFT := -620.0 ## px logiques : hauteur de la canopée (silhouette provisoire)
const VIB_CD := 4.5 ## délai entre deux chutes déclenchées par la toile
# Toile (phase 2+)
const WEB_R_U := 6.0
const WEB_GAP_HALF := 0.3 ## ~3,6 u d'ouverture
# Cocons (phase 3)
const COCOON_COUNT := 6
const COCOON_RING_U := 2.6
const COCOON_R_U := 0.5 ## obstacles de 1 u
const COCOON_HATCH_S := 3.0
const COCOON_LIFE := 30.0

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = [] ## journal (tests) : kind, phase, anim, frame, expect, lag
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var drop_at := Vector2.ZERO
var web_drops := 0 ## chutes déclenchées par une vibration de la toile (tests)
var pace: BossPace ## armement planté, impact, récupération immobile (scripts/enemies/boss_pace.gd)

var _t := 0.0
var _ascend_s := ASCEND_S ## durée de la montée en cours (armement de la descente)
var _dur := 0.0
var _attack_cd := 1.3
var _spell_cd := 2.0
var _vib_cd := 0.0
var _cycle := 0
var _from_web := false
var _lift := 0.0
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _feet: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = []
var _thread_lines: Array[Dictionary] = [] ## {from, dir, len, tele}
var _fx: Array[Dictionary] = [] ## {node, life, max}
var _body: WeaverFx = null
var _silk: WeaverFx = null ## fil de descente (vers la canopée)
var _snare: WeaverSnare = null


func _init(enemy: Enemy) -> void:
	e = enemy
	vis = enemy.visual as EnemyVisual
	pace = BossPace.new(enemy)
	_rng.randomize()
	_frames = EnemyVisual.boss_frames(ID)
	if e._light != null:
		e._light.set_preset(&"boss_cerf")
		e._light.set_color(MINT)
		e._light.position = Vector2(0.0, Iso.lift_logical(LIGHT_LIFT_U))
	_feet = LightRig.attach(e, &"boss_cerf_hooves", {"color": MINT})
	if vis.body_sprite() != null:
		vis.body_sprite().self_modulate = BODY_GAIN
	else:
		_build_body()
	_snare = WeaverSnare.create(e, "Weaver")
	if _snare != null:
		_snare.frames = _frames
	_apply_phase_look()


func clear() -> void:
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	if is_instance_valid(_snare):
		if killed:
			_snare.on_boss_dead()
		else:
			_snare.release()
	_snare = null
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	for t in _teles:
		if is_instance_valid(t):
			t.queue_free()
	_teles.clear()
	_thread_lines.clear()
	if is_instance_valid(_body):
		_body.queue_free()
	_body = null
	if is_instance_valid(_silk):
		_silk.queue_free()
	_silk = null
	if _feet != null:
		_feet.release()
	_feet = null
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


func owns_motion() -> bool:
	return state in [S.ASCEND, S.HANG, S.DROP, S.STAGGER] or pace.planted()


## Super-armure pendant l'armement et la récupération (un recul ferait glisser le boss planté).
func ignores_knockback() -> bool:
	return pace.planted()


## Intouchable dans la canopée (la lanterne au sol montre où elle est).
func damage_taken_mult() -> float:
	if state == S.HANG or (state == S.ASCEND and _t > _ascend_s * 0.5):
		return 0.0
	return Balance.boss_damage_taken_mult(ID, phase)


func in_canopy() -> bool:
	return state == S.HANG or (state == S.ASCEND and _t > _ascend_s * 0.5)


func snare() -> WeaverSnare:
	return _snare if is_instance_valid(_snare) else null


## Un pas d'IA. Retourne la vitesse de marche voulue (px/s logiques), appliquée par Enemy.
func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase and not (state in [S.ASCEND, S.HANG, S.DROP]): # jamais en l'air : la chute finit d'abord
		_enter_phase(ph)
	_update_fx(delta)
	_update_body(delta)
	_attack_cd -= delta
	_spell_cd -= delta
	_vib_cd -= delta
	_t += delta
	var pi := phase - 1
	match state:
		S.STAGGER:
			if _t >= _dur:
				state = S.CHASE
				if phase == 3:
					_start_cocoons(ppos) # la ponte ouvre la phase 3
			return Vector2.ZERO
		S.BITE:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_bite(player, ppos)
			return Vector2.ZERO
		S.THREADS:
			_place_thread_teles(_t / _dur)
			if _t >= _dur:
				_release_threads(player, ppos)
			return Vector2.ZERO
		S.ASCEND:
			_lift = lerpf(0.0, CANOPY_LIFT, clampf(_t / _ascend_s, 0.0, 1.0))
			_set_hidden(clampf(_t / _ascend_s, 0.0, 1.0))
			if _t >= _ascend_s:
				pace.act() # la lanterne glisse vers le point de chute : mouvement propre
				state = S.HANG
				_t = 0.0
				_dur = DROP_WINDUP - DROP_FALL_S
				e.telegraph.modulate = Color.WHITE
				e.telegraph.show_circle(drop_at, DROP_R_U * U)
				e._sfx(&"telegraph.boss.heavy", 0.0, true)
			return Vector2.ZERO
		S.HANG:
			# la lanterne glisse sous la canopée vers le point de chute (le boss, invisible, la suit)
			if not _from_web and _t <= DROP_WINDUP * DROP_TRACK:
				drop_at = _walkable(ppos)
			e.telegraph.global_position = drop_at
			e.telegraph.set_progress(_t / DROP_WINDUP)
			var to := drop_at - e.position
			var step := minf(to.length(), 14.0 * U * delta)
			if to.length() > 0.5:
				e.position += to.normalized() * step
			if _t >= _dur:
				e.position = drop_at
				state = S.DROP
				_t = 0.0
				_dur = DROP_FALL_S
				var sp := vis.play_special(&"drop")
				if sp > 0.0:
					_dur = maxf(DROP_FALL_S, minf(sp * 0.5, 0.5))
			return Vector2.ZERO
		S.DROP:
			e.telegraph.set_progress((DROP_WINDUP - DROP_FALL_S + _t) / DROP_WINDUP)
			_lift = lerpf(CANOPY_LIFT, 0.0, clampf(_t / _dur, 0.0, 1.0))
			_set_hidden(1.0 - clampf(_t / _dur * 2.0, 0.0, 1.0))
			if _t >= _dur:
				_land(player, ppos)
			return Vector2.ZERO
		S.COCOONS:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_lay_cocoons()
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering(): # récupération immobile : fenêtre de punition
		_face(dir)
		return Vector2.ZERO
	if vis.is_attacking():
		_face(dir)
		return Vector2.ZERO
	# SURPRISE (P2+) : la toile vibre -> elle tombe sur le point touché
	if is_instance_valid(_snare) and not _snare.web_touches.is_empty():
		var p: Vector2 = _snare.web_touches.pop_back()
		_snare.web_touches.clear()
		if phase >= 2 and _vib_cd <= 0.0:
			_vib_cd = VIB_CD
			_start_descent(p, true)
			return Vector2.ZERO
	if _spell_cd <= 0.0 and dist < (THREAD_LEN_U + 2.0) * U:
		_start_spell(dir, ppos)
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < BITE_RANGE_U * U:
		_start_bite(dir)
		return Vector2.ZERO
	if dist > BITE_RANGE_U * U * 0.7:
		var go := path_dir if path_dir != Vector2.ZERO else dir
		_face(go)
		return go * e.speed_px * SPEED_MULT[pi]
	_face(dir)
	return Vector2.ZERO


# --- Phases ------------------------------------------------------------------------

func _enter_phase(ph: int) -> void:
	_cancel()
	phase = ph
	state = S.STAGGER
	_t = 0.0
	_dur = 8.0 / ANIM_FPS + 0.25 # trans_pN : 8 frames
	_spell_cd = maxf(_spell_cd, _dur + 1.2)
	_attack_cd = maxf(_attack_cd, _dur + 0.4)
	_cycle = 0
	_apply_phase_look()
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_cerf", 0.6, {"color": MINT, "radius": 1.6})
	if ph == 2 and is_instance_valid(_snare) and not _snare.has_web():
		# la toile se tend autour d'elle ; brèches de part et d'autre de l'axe vers le joueur
		var a := (_ppos - e.position).angle() + PI * 0.5 + _rng.randf_range(-0.4, 0.4)
		_snare.set_web(e.position, WEB_R_U, PackedFloat32Array([a, a + PI]), WEB_GAP_HALF)
		_snare.pulse_web(1.0)
		e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	events.append({"kind": &"phase", "phase": ph})


func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	for l in _thread_lines:
		if is_instance_valid(l.get("tele")):
			(l["tele"] as EnemyTelegraph).hide_telegraph()
	_thread_lines.clear()
	_lift = 0.0
	_set_hidden(0.0)
	_show_silk(false)


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.22 if phase >= 3 else -1.0, 5.0) # P3 : la lanterne fêlée vacille
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])
	if _body != null:
		_body.glow = 0.7 + 0.15 * phase


# --- Morsure (auto) --------------------------------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func _start_bite(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.BITE
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_cone(e.position, aim.angle(), BITE_RANGE_U * U, BITE_HALF, EnemyTelegraph.Weight.LIGHT)
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _resolve_bite(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.brute_cone.heavy")
	var v := ppos - e.position
	if player != null and v.length() <= BITE_RANGE_U * U + PLAYER_R and absf(angle_difference(aim.angle(), v.angle())) <= BITE_HALF + 0.15:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"bite"))
	_log(&"bite", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


# --- Sorts ---------------------------------------------------------------------------

func _start_spell(dir: Vector2, ppos: Vector2) -> void:
	var cyc: Array = SPELL_CYCLE[phase - 1]
	var sp: int = cyc[_cycle % cyc.size()]
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	match sp:
		Spell.THREADS:
			_start_threads(dir)
		Spell.DESCENT:
			_start_descent(ppos, false)
		Spell.COCOONS:
			_start_cocoons(ppos)


# --- Fils ----------------------------------------------------------------------------

func _start_threads(dir: Vector2) -> void:
	state = S.THREADS
	_t = 0.0
	_dur = BossPace.windup(&"spell", phase)
	pace.wind(&"spell")
	aim = dir
	vis.play_attack(&"cast_a", _dur, aim)
	_thread_lines.clear()
	var n: int = THREAD_COUNT[phase - 1]
	for k in n:
		var a := aim.angle() + (k - (n - 1) * 0.5) * THREAD_SPREAD
		var d := Vector2.from_angle(a)
		var from := e.position + d * e.radius_px * 0.4
		var len := _ray_len(from, d, THREAD_LEN_U * U)
		var tele := _tele(k)
		tele.modulate = Color.WHITE
		tele.show_line(from, a, len, THREAD_W_U * U)
		_thread_lines.append({"from": from, "dir": d, "len": len, "tele": tele})
	e._sfx(&"telegraph.boss.heavy", 0.0, true)


func _place_thread_teles(p: float) -> void:
	for l in _thread_lines:
		var t := l["tele"] as EnemyTelegraph
		if is_instance_valid(t):
			t.set_progress(p)


func _release_threads(player: Node2D, ppos: Vector2) -> void:
	_log(&"threads", &"cast_a")
	e._sfx(&"enemy.shockwave.heavy", -2.0, true)
	var hit := false
	for l in _thread_lines:
		var t := l["tele"] as EnemyTelegraph
		if is_instance_valid(t):
			t.hide_telegraph()
		var from: Vector2 = l["from"]
		var to: Vector2 = from + (l["dir"] as Vector2) * float(l["len"])
		if not hit and player != null and WeaverSnare._seg_dist(ppos, from, to) <= THREAD_W_U * 0.5 * U + PLAYER_R:
			hit = true
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"threads"))
			events.append({"kind": &"thread_hit", "phase": phase})
		if is_instance_valid(_snare):
			_snare.add_thread(from, to, THREAD_W_U, THREAD_LIFE)
	_thread_lines.clear()
	if is_instance_valid(_snare):
		_snare.pulse_web(0.6)
	pace.strike(&"spell", phase)
	state = S.CHASE


# --- Descente ------------------------------------------------------------------------

## Elle se hisse (spell_b : bond vers la canopée), puis tombe sur `target` (le joueur, ou le point de la
## toile qui a vibré : alors le cercle ne suit pas).
func _start_descent(target: Vector2, from_web: bool) -> void:
	_from_web = from_web
	drop_at = _walkable(target)
	aim = (drop_at - e.position).normalized() if drop_at.distance_squared_to(e.position) > 1.0 else aim
	_face(aim)
	state = S.ASCEND
	_t = 0.0
	_ascend_s = BossPace.windup(&"charge", phase, ASCEND_S)
	_dur = _ascend_s
	pace.wind(&"charge")
	if vis.play_special(&"ascend") <= 0.0:
		vis.play_attack(&"cast_b", _ascend_s, Vector2.ZERO)
	e.telegraph.hide_telegraph()
	_show_silk(true)
	e._sfx(&"telegraph.warn_light.light", 0.0, true)
	if from_web:
		web_drops += 1
		events.append({"kind": &"web_vibration", "phase": phase, "at": drop_at})
		if is_instance_valid(_snare):
			_snare.pulse_web(1.0)


func _land(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	_lift = 0.0
	_set_hidden(0.0)
	_show_silk(false)
	e._sfx(&"enemy.shockwave.heavy", 3.0, true)
	LightRig.flash(e.global_position, &"boss_cerf", 0.4, {"color": MINT, "radius": 1.4})
	_dust(e.position)
	if player != null and drop_at.distance_to(ppos) <= DROP_R_U * U + PLAYER_R:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"drop"))
		events.append({"kind": &"drop_hit", "phase": phase})
	_log(&"drop", &"", -1)
	if is_instance_valid(_snare):
		_snare.pulse_web(1.0)
	pace.strike(&"charge", phase) # chute : arrêt net, récupération au sol
	state = S.CHASE
	_attack_cd = maxf(_attack_cd, 0.5)


func _set_hidden(k: float) -> void:
	if _body != null:
		_body.lift = _lift
		_body.queue_redraw()
	elif vis != null:
		vis.modulate.a = 1.0 - clampf(k, 0.0, 1.0)


func _show_silk(on: bool) -> void:
	if on and not is_instance_valid(_silk):
		_silk = WeaverFx.make(WeaverFx.Kind.SILK_DROP, WeaverFx.MIST, 1)
		_silk.name = &"Weaver_silk"
		_silk.radius = 1400.0
		e.add_child(_silk)
	elif not on and is_instance_valid(_silk):
		_silk.queue_free()
		_silk = null


func _dust(pos: Vector2) -> void:
	var n: Node2D
	var an := _first_anim(["drop_dust", "dust", "land_dust"])
	if an != &"":
		var tex := _frames.get_frame_texture(an, 0)
		var s := _sprite(an, Vector2.ONE * (DROP_R_U * 2.0 * U / (float(tex.get_width()) if tex != null else 192.0)), Vector2.ZERO, 0, 2.0) # sol : la cellule = le cercle
		s.play(an)
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.RING, Color(WeaverFx.MIST.r, WeaverFx.MIST.g, WeaverFx.MIST.b, 0.8), 0)
		f.radius = DROP_R_U * U
		f.width = 0.3 * U
		f.color2 = Color(MINT.r, MINT.g, MINT.b, 0.9)
		n = f
	n.name = &"Weaver_dust"
	e.get_parent().add_child(n)
	n.position = pos
	_fx.append({"node": n, "life": 0.6, "max": 0.6})


# --- Cocons (phase 3) ------------------------------------------------------------------

var _lay_special := false ## ponte jouée par l'anim spéciale lay_s (sans coup armé)


func _start_cocoons(ppos: Vector2) -> void:
	state = S.COCOONS
	_t = 0.0
	_dur = BossPace.windup(&"spell", phase)
	pace.wind(&"spell")
	aim = (ppos - e.position).normalized() if ppos.distance_squared_to(e.position) > 1.0 else aim
	_face(aim)
	_lay_special = vis.play_special(&"lay") > 0.0
	if not _lay_special:
		vis.play_attack(&"cast_a", _dur, Vector2.ZERO)
	e.telegraph.modulate = Color(1, 1, 1, 0.55)
	e.telegraph.show_circle(ppos, COCOON_RING_U * U + COCOON_R_U * U)
	drop_at = ppos
	e._sfx(&"telegraph.boss.heavy", 0.0, true)


## Couronne de 6 cocons autour du joueur (posée sur le point visé au début de la ponte).
func _lay_cocoons() -> void:
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	var c := drop_at
	var a0 := _rng.randf() * TAU
	var n := 0
	for k in COCOON_COUNT:
		var p := c + Vector2.from_angle(a0 + TAU * k / COCOON_COUNT) * COCOON_RING_U * U
		if e.nav != null and e.nav.is_wall_at(p):
			continue
		if is_instance_valid(_snare):
			_snare.add_obstacle(p, COCOON_R_U, COCOON_LIFE, &"cocoon", COCOON_HATCH_S)
			n += 1
	_log(&"cocoons", &"lay" if _lay_special else &"cast_a") # anim spéciale lay : pas de coup armé à caler
	events[events.size() - 1]["count"] = n
	e._sfx(&"enemy.shockwave.heavy", -2.0, true)
	pace.strike(&"spell", phase)
	state = S.CHASE


# --- Silhouette provisoire ---------------------------------------------------------------

func _build_body() -> void:
	_body = WeaverFx.make(WeaverFx.Kind.BODY_WEAVER, WOOD, 0)
	_body.name = &"Weaver_body"
	_body.color2 = MINT
	e.add_child(_body)
	vis.self_modulate = Color(1, 1, 1, 0)


func _update_body(_delta: float) -> void:
	if _body == null:
		return
	var fl := 1.0 if e.is_flashing() else 0.0
	if absf(fl - _body.progress) > 0.01:
		_body.progress = fl
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

func _first_anim(cands: Array) -> StringName:
	if _frames == null:
		return &""
	for c in cands:
		if _frames.has_animation(StringName(c)):
			return StringName(c)
	return &""


func _sprite(anim: StringName, sc: Vector2, off: Vector2, z: int, energy: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = StringName("Weaver_" + String(anim))
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
	return e.nav.resolve(p, e.radius_px) if e.nav else p


## Longueur libre d'une ligne (les fils s'accrochent au premier mur).
func _ray_len(from: Vector2, d: Vector2, max_len: float) -> float:
	if e.nav == null:
		return max_len
	var l := 0.0
	while l < max_len:
		if e.nav.is_blocked_at(from + d * (l + 16.0)):
			return maxf(l, 2.0 * U)
		l += 16.0
	return max_len


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
