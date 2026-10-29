class_name RecluseBrain
extends RefCounted
## IA du Reclus (boss d'étage 4, Cryptes noyées ; docs/Design_Etages.md §5.4). Créée par Enemy.activate_boss
## quand le skin du boss est « recluse », appelée par Enemy.tick (branche BOSS_TIER). Même contrat que
## CerfBrain / SonneurBrain : coups télégraphiés face au joueur (angle libre ; le sprite prend la plus proche
## de ses 4 orientations e/s/w/n : auto/spell_a/spell_b_<dir>), dégâts à la frame d'impact
## (EnemyVisual.play_attack cale l'impact sur la fin du télégraphe). Dégâts : Balance.BOSS_ATTACK_COEF[&"recluse"].
## Sans sprites (lot Codex à venir, art/tools/night/requests_bosses45.md) : silhouette et effets dessinés
## provisoires (RecluseFx) ; chaque extra du .tres (bell_wave, prayer_glyph, prayer_burst, ray, silence_mark)
## remplace son repli dès qu'il est livré.
##
## Moine de pierre de 3,6 u, capuche vide, cristal blanc-cyan #BFF4FF dans la poitrine (seule lumière chaude…
## froide de l'arène avec le joueur), cloche de silence à la main.
## Phases (PV, Enemy.boss_phase) : 1 > 66 % > 2 > 33 % > 3 ; transition = anim trans_pN (boss figé).
## - Phase 1 « Vigile » : bâton (auto, cône 70° de 3,2 u) ; Cloche (spell_a : anneau de 1 à 8 u en 0,8 s,
##   télégraphe 1 s ; touché = sorts 2-4 coupés 2 s, « silence ») ; Prières (spell_b : 6 cercles de 2 u en
##   spirale autour du joueur, allumés l'un après l'autre, chacun 1 s ; un seul coup par lancer).
## - Phase 2 « Extinction » : les cristaux de l'arène s'éteignent par vagues (RecluseGloom, lumière de la
##   carte à 50 %, télégraphes inchangés) ; le cristal du Reclus brille plus fort ; cloche double.
## - Phase 3 « Lévitation » : le Reclus s'élève et ne bouge plus ; 4 rayons de cristal (1 × 14 u) tournent
##   à 20°/s (télégraphe continu, 0,45 par 0,5 s) ; SURPRISE : toutes les 8 s les rayons blanchissent 0,9 s
##   (carillon) puis repartent EN SENS INVERSE. Cloche et prières continuent, plus vite.
## Trace après la mort (phase 2+) : l'obscurité reste jusqu'à la fin de la charge du gros pilier.

enum S { CHASE, STAFF, BELL_WIND, BELL_ECHO, PRAYERS, STAGGER }
enum Spell { BELL, PRAYERS }

const ID := &"recluse"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const CRYSTAL := Color(0.749, 0.957, 1.0) ## #BFF4FF, accent unique du biome
const STONE := Color(0.50, 0.53, 0.56) ## silhouette provisoire : pierre de sel claire (lisible de nuit)
## Par phase (index phase - 1)
const SPEED_MULT := [1.0, 1.05, 0.0] ## P3 : lévite immobile
const AUTO_CD := [1.9, 1.7, 99.0]
const SPELL_CD := [4.6, 4.2, 3.6] ## cloche et prières alternées (~9 s chacune ; P3 plus vite)
## Lumière : le cristal de poitrine porte le boss (preset boss_cerf teinté cristal, posé à mi-corps) + une
## lumière basse aux pieds qui découpe la silhouette sur le sol noir des Cryptes (leçon du Sonneur).
const LIGHT_ENERGY := [3.2, 4.2, 4.8]
const LIGHT_RADIUS := [1.25, 1.45, 1.55]
const LIGHT_LIFT_U := 1.9
const FEET_ENERGY := [2.2, 2.8, 3.2]
const BODY_GAIN := Color(1.2, 1.22, 1.28) ## albédo de pierre relevé sous la nuit (rendu à 1 au retour au pool)
const LEVITATE_U := 0.6 ## P3 : hauteur de la silhouette provisoire (les sprites idle_p3 lévitent d'eux-mêmes)
# Bâton (auto)
const STAFF_RANGE_U := 3.2
const STAFF_HALF := 0.61 ## 70°
## Armements et récupérations : BossPace (Balance.BOSS_PACE_*) ; bâton = auto, cloche et prières = spell.
# Cloche (spell_a)
const BELL_ECHO_WIND := 1.0 ## P2+ : armement (anim cast_a) du second anneau, dans les BELL_ECHO_S de l'écho
const BELL_R0_U := 1.0 ## disque sûr sous la cloche
const BELL_R1_U := 8.0
const BELL_WAVE_S := 0.8
const BELL_BAND_U := 0.9
const BELL_ECHO_S := 1.4 ## P2+ : second anneau
const BELL_TELE_ALPHA := 0.6
const SILENCE_S := 2.0
# Prières (spell_b)
const PRAYER_WINDUP := 1.0 ## par cercle (télégraphe de chaque cercle ; le Reclus reste planté tout le lancer)
const PRAYER_COUNT := 6
const PRAYER_R_U := 1.0 ## cercles de 2 u
const PRAYER_GAP_U := 0.5
const PRAYER_STAGGER := 0.15 ## la spirale s'allume du centre vers l'extérieur
const PRAYER_SPIRAL_U := 2.7 ## rayon de la spirale (× √i)
const PRAYER_GOLDEN := 2.39996
# Rayons (phase 3)
const RAYS := 4
const RAY_LEN_U := 14.0
const RAY_W_U := 1.0
const RAY_TURN := 0.349 ## 20°/s
const RAY_TICK := 0.5
const RAY_ALPHA := 0.55
const RAY_REVERSE_EVERY := 8.0
const RAY_WARN_S := 0.9
const RAY_FIRST_S := 1.0

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = [] ## journal des coups (tests) : kind, phase, anim, frame, expect, lag
var pace: BossPace ## rythme commun : armement planté, impact, récupération immobile
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var silenced := 0 ## silences infligés (tests)
var ray_dir := 1.0 ## sens de rotation des rayons (P3)
var reversals := 0

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.4
var _spell_cd := 2.2
var _cycle := 0
var _echo_started := false
var _ray_angle := 0.0
var _ray_tick := 0.0
var _ray_rev_t := 0.0
var _ray_warned := false
var _prayer_hit := false
var _prayer_logged := false
var _flash := 0.0
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _feet: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = []
var _waves: Array[Dictionary] = [] ## {center, t, hit, ring}
var _prayers: Array[Dictionary] = [] ## {pos, t0, tele, glyph, done}
var _rays: Array[Dictionary] = [] ## {tele, beam}
var _fx: Array[Dictionary] = [] ## {node, life, max}
var _body: RecluseFx = null ## silhouette provisoire (sans sprite)
var _gloom: RecluseGloom = null


func _init(enemy: Enemy) -> void:
	e = enemy
	vis = enemy.visual as EnemyVisual
	pace = BossPace.new(enemy)
	_rng.randomize()
	_frames = EnemyVisual.boss_frames(ID)
	if e._light != null:
		e._light.set_preset(&"boss_cerf")
		e._light.set_color(CRYSTAL)
		e._light.position = Vector2(0.0, Iso.lift_logical(LIGHT_LIFT_U))
	_feet = LightRig.attach(e, &"boss_cerf_hooves", {"color": CRYSTAL})
	if vis.body_sprite() != null:
		vis.body_sprite().self_modulate = BODY_GAIN
	else:
		_build_body()
	_apply_phase_look()


## Libère télégraphes, ondes, prières, rayons, silhouette (mort, retour au pool). Mort en phase 2+ alors
## que la charge du gros pilier continue : l'obscurité reste (RecluseGloom).
func clear() -> void:
	if pace != null:
		pace.cancel()
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	if is_instance_valid(_gloom):
		if killed:
			_gloom.on_boss_dead()
		else:
			_gloom.release()
	_gloom = null
	for w in _waves:
		if is_instance_valid(w.get("ring")):
			(w["ring"] as Node).queue_free()
	_waves.clear()
	for p in _prayers:
		if is_instance_valid(p.get("glyph")):
			(p["glyph"] as Node).queue_free()
	_prayers.clear()
	for r in _rays:
		if is_instance_valid(r.get("beam")):
			(r["beam"] as Node).queue_free()
	_rays.clear()
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


## Transition figée ; planté (armement, récupération) : ni marche ni poussée de foule.
func owns_motion() -> bool:
	return state == S.STAGGER or pace.planted()


## Super-armure le temps d'un coup (armement, récupération) : un recul le ferait glisser.
func ignores_knockback() -> bool:
	return pace.planted()


func damage_taken_mult() -> float:
	return Balance.boss_damage_taken_mult(ID, phase)


func wave_count() -> int:
	return _waves.size()


func prayer_count() -> int:
	return _prayers.size()


func ray_count() -> int:
	return _rays.size()


func ray_angle() -> float:
	return _ray_angle


func gloom() -> RecluseGloom:
	return _gloom if is_instance_valid(_gloom) else null


## Un pas d'IA. Retourne la vitesse de marche voulue (px/s logiques), appliquée par Enemy.
func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase:
		_enter_phase(ph)
	_update_waves(delta, player, ppos)
	_update_prayers(delta, player, ppos)
	_update_rays(delta, player, ppos)
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
					_build_rays()
			return Vector2.ZERO
		S.STAFF:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_staff(player, ppos)
			return Vector2.ZERO
		S.BELL_WIND:
			e.telegraph.global_position = e.position
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_release_bell()
				if phase >= 2:
					pace.strike(&"spell", phase, false) # premier anneau : reste planté jusqu'à l'écho
					state = S.BELL_ECHO
					_t = 0.0
					_dur = BELL_ECHO_S
					_echo_started = false
					e.telegraph.show_circle(e.position, BELL_R1_U * U)
				else:
					e.telegraph.hide_telegraph()
					pace.strike(&"spell", phase)
					state = S.CHASE
			return Vector2.ZERO
		S.BELL_ECHO:
			e.telegraph.global_position = e.position
			e.telegraph.set_progress(_t / _dur)
			if not _echo_started and _t >= _dur - BELL_ECHO_WIND:
				_echo_started = true
				_face(dir)
				vis.play_attack(&"cast_a", _dur - _t, Vector2.ZERO)
			if _t >= _dur:
				e.telegraph.hide_telegraph()
				_release_bell()
				pace.strike(&"spell", phase) # dernier anneau : récupération immobile
				state = S.CHASE
			return Vector2.ZERO
		S.PRAYERS:
			if _prayers.is_empty(): # dernier cercle tombé : récupération immobile
				pace.strike(&"spell", phase)
				state = S.CHASE
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering(): # récupération immobile : fenêtre de punition, aucun nouveau coup
		_face(dir)
		return Vector2.ZERO
	if vis.is_attacking():
		_face(dir)
		return Vector2.ZERO
	if _spell_cd <= 0.0 and dist < (BELL_R1_U + 3.0) * U:
		_start_spell(dir, ppos)
		return Vector2.ZERO
	if phase < 3 and _attack_cd <= 0.0 and dist < STAFF_RANGE_U * U:
		_start_staff(dir)
		return Vector2.ZERO
	if SPEED_MULT[pi] > 0.0 and dist > STAFF_RANGE_U * U * 0.75:
		var go := path_dir if path_dir != Vector2.ZERO else dir
		_face(go)
		return go * e.speed_px * SPEED_MULT[pi]
	_face(dir)
	return Vector2.ZERO


# --- Phases --------------------------------------------------------------------

func _enter_phase(ph: int) -> void:
	_cancel()
	phase = ph
	state = S.STAGGER
	_t = 0.0
	_dur = 8.0 / ANIM_FPS + 0.25 # trans_pN : 8 frames
	_spell_cd = maxf(_spell_cd, _dur + 1.0)
	_attack_cd = maxf(_attack_cd, _dur + 0.4)
	_cycle = 0
	_apply_phase_look()
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.6, {"color": CRYSTAL, "radius": 1.6})
	_burst_fx(e.position, 1.0, 0.9)
	if ph == 2 and _gloom == null:
		_gloom = RecluseGloom.create(e) # les cristaux de l'arène s'éteignent
		e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	events.append({"kind": &"phase", "phase": ph})


func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	for p in _prayers:
		if is_instance_valid(p.get("tele")):
			(p["tele"] as EnemyTelegraph).hide_telegraph()
		if is_instance_valid(p.get("glyph")):
			(p["glyph"] as Node).queue_free()
	_prayers.clear()


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.12 if phase >= 3 else -1.0, 1.4)
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])
	if _body != null:
		_body.glow = 0.6 + 0.2 * phase


# --- Bâton (auto) ------------------------------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func _start_staff(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.STAFF
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_cone(e.position, aim.angle(), STAFF_RANGE_U * U, STAFF_HALF, EnemyTelegraph.Weight.LIGHT)
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _resolve_staff(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.brute_cone.heavy")
	var v := ppos - e.position
	if player != null and v.length() <= STAFF_RANGE_U * U + PLAYER_R and absf(angle_difference(aim.angle(), v.angle())) <= STAFF_HALF + 0.15:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"staff"))
	_log(&"staff", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


# --- Sorts -------------------------------------------------------------------------

func _start_spell(dir: Vector2, ppos: Vector2) -> void:
	var sp: int = Spell.BELL if _cycle % 2 == 0 else Spell.PRAYERS
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	_t = 0.0
	match sp:
		Spell.BELL:
			state = S.BELL_WIND
			_dur = BossPace.windup(&"spell", phase)
			pace.wind(&"spell")
			vis.play_attack(&"cast_a", _dur, Vector2.ZERO) # la cloche sonne sur place
			e.telegraph.show_circle(e.position, BELL_R1_U * U)
			e.telegraph.modulate = Color(1.0, 1.0, 1.0, BELL_TELE_ALPHA)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)
		Spell.PRAYERS:
			state = S.PRAYERS
			_dur = PRAYER_WINDUP
			pace.wind(&"spell")
			vis.play_attack(&"cast_b", _dur, Vector2.ZERO) # impact calé sur le premier cercle
			_place_prayers(ppos)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)


# --- Cloche ------------------------------------------------------------------------

## Frappe de la cloche (frame d'impact de spell_a) : l'anneau part du boss.
func _release_bell() -> void:
	_log(&"bell", &"cast_a")
	e._sfx(&"enemy.shockwave.heavy", 3.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.5, {"color": CRYSTAL, "radius": 2.0})
	var ring: Node2D = null
	if _frames != null and _frames.has_animation(&"bell_wave"):
		var s := _sprite(&"bell_wave", Vector2.ONE, Vector2.ZERO, -1, 2.4)
		s.speed_scale = _frames.get_frame_count(&"bell_wave") / ANIM_FPS / BELL_WAVE_S
		e.get_parent().add_child(s)
		s.play(&"bell_wave")
		ring = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.RING, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.85), 0)
		f.name = &"Recluse_bell"
		f.width = 0.45 * U
		f.color2 = Color(1, 1, 1, 0.9)
		RecluseFx.add_to_tele_layer(f, e.get_parent())
		ring = f
	var w := {"center": e.position, "t": 0.0, "hit": false, "ring": ring}
	_waves.append(w)
	_place_ring(w, BELL_R0_U * U)


func _place_ring(w: Dictionary, r: float) -> void:
	var ring := w["ring"] as Node2D
	if not is_instance_valid(ring):
		return
	ring.global_position = w["center"]
	if ring is RecluseFx:
		(ring as RecluseFx).set_param(r)
	else:
		ring.scale = Vector2.ONE * (r / 124.0) # bell_wave : anneau de rayon 124 px dans sa cellule de 256


func _update_waves(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := _waves.size() - 1
	while i >= 0:
		var w: Dictionary = _waves[i]
		w["t"] = float(w["t"]) + delta
		var k := clampf(float(w["t"]) / BELL_WAVE_S, 0.0, 1.0)
		var r := lerpf(BELL_R0_U, BELL_R1_U, k) * U
		_place_ring(w, r)
		var ring := w["ring"] as CanvasItem
		if is_instance_valid(ring):
			ring.modulate.a = 1.0 - k * k * 0.7
		var d := (ppos - (w["center"] as Vector2)).length()
		if not w["hit"] and player != null and d > BELL_R0_U * U and absf(d - r) <= BELL_BAND_U * 0.5 * U + PLAYER_R:
			w["hit"] = true
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"bell"))
			_silence(player)
			events.append({"kind": &"bell_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0, "r": r, "d": d})
		if k >= 1.0:
			if is_instance_valid(ring):
				ring.queue_free()
			_waves.remove_at(i)
		i -= 1


## Silence : les sorts à recharge (2-4) repartent pour au moins SILENCE_S s (la recharge en cours n'est
## jamais raccourcie) ; marque de cristal autour du joueur le temps du silence.
## Contrat : `SpellCaster.silence(s)`.
func _silence(player: Node2D) -> void:
	var sc: Variant = player.get(&"spells")
	if sc == null or not (sc is Object) or not (sc as Object).has_method(&"silence"):
		return
	(sc as Object).call(&"silence", SILENCE_S)
	silenced += 1
	e._sfx(&"telegraph.warn_light.light", 2.0, true)
	var mark: Node2D
	if _frames != null and _frames.has_animation(&"silence_mark"):
		var s2 := _sprite(&"silence_mark", Vector2.ONE, Vector2.ZERO, 1, 2.0)
		s2.play(&"silence_mark")
		mark = s2
	else:
		var f := RecluseFx.make(RecluseFx.Kind.RING, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.9), 2)
		f.width = 5.0
		f.radius = 0.75 * U
		mark = f
	mark.name = &"Recluse_silence"
	player.add_child(mark)
	_fx.append({"node": mark, "life": SILENCE_S, "max": 0.6})
	events.append({"kind": &"silence", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})


# --- Prières -----------------------------------------------------------------------

## 6 cercles en spirale dorée autour du joueur (le premier sur lui), espacés d'au moins 0,5 u, allumés
## du centre vers l'extérieur toutes les PRAYER_STAGGER s.
func _place_prayers(ppos: Vector2) -> void:
	_prayer_hit = false
	_prayer_logged = false
	var a0 := _rng.randf() * TAU
	var min_d := (2.0 * PRAYER_R_U + PRAYER_GAP_U) * U
	var pts: Array[Vector2] = []
	var i := 0
	while pts.size() < PRAYER_COUNT and i < PRAYER_COUNT * 3:
		var p := ppos + Vector2.from_angle(a0 + i * PRAYER_GOLDEN) * PRAYER_SPIRAL_U * sqrt(float(i)) * U
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
		var tele := _tele(k)
		tele.hide_telegraph()
		var glyph: Node2D = null
		if _frames != null and _frames.has_animation(&"prayer_glyph"):
			var s := _sprite(&"prayer_glyph", Vector2.ONE * (PRAYER_R_U * U / 64.0), Vector2.ZERO, -1, 2.0)
			s.visible = false
			e.get_parent().add_child(s)
			s.position = pts[k]
			s.play(&"prayer_glyph")
			glyph = s
		_prayers.append({"pos": pts[k], "t0": -k * PRAYER_STAGGER, "tele": tele, "glyph": glyph, "shown": false})
	_dur = PRAYER_WINDUP + (pts.size() - 1) * PRAYER_STAGGER


func _update_prayers(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := 0
	while i < _prayers.size():
		var p: Dictionary = _prayers[i]
		p["t0"] = float(p["t0"]) + delta
		var t := float(p["t0"])
		var tele := p["tele"] as EnemyTelegraph
		if t >= 0.0 and not p["shown"]:
			p["shown"] = true
			tele.show_circle(p["pos"], PRAYER_R_U * U)
			if is_instance_valid(p.get("glyph")):
				(p["glyph"] as Node2D).visible = true
			e._sfx(&"telegraph.warn_light.light", -6.0)
		if p["shown"]:
			tele.set_progress(t / PRAYER_WINDUP)
		if t >= PRAYER_WINDUP:
			tele.hide_telegraph()
			_detonate_prayer(p, player, ppos)
			if is_instance_valid(p.get("glyph")):
				(p["glyph"] as Node).queue_free()
			_prayers.remove_at(i)
			continue
		i += 1


func _detonate_prayer(p: Dictionary, player: Node2D, ppos: Vector2) -> void:
	var pos: Vector2 = p["pos"]
	if not _prayer_logged: # premier cercle du lancer : le seul calé sur la frame d'impact de spell_b
		_prayer_logged = true
		_log(&"prayers", &"cast_b")
	e._sfx(&"enemy.shockwave.heavy", -3.0, true)
	LightRig.flash(pos, &"boss_lightning", 0.18, {"color": CRYSTAL, "energy": 0.6, "radius": 0.6})
	_burst_fx(pos, PRAYER_R_U, 0.5)
	if not _prayer_hit and player != null and pos.distance_to(ppos) <= PRAYER_R_U * U + PLAYER_R:
		_prayer_hit = true # un même lancer ne touche qu'une fois
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"prayers"))
		events.append({"kind": &"prayer_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})


## Éclat de cristal au sol (impact des prières, transitions) : prayer_burst du .tres, sinon colonne dessinée.
func _burst_fx(pos: Vector2, r_u: float, life: float) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"prayer_burst"):
		var s := _sprite(&"prayer_burst", Iso.UNSQUASH * Iso.SPRITE_K * r_u, Vector2(0.0, -192.0), 0, 2.6)
		s.play(&"prayer_burst")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.COLUMN, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.75), 0)
		f.radius = -Iso.lift_logical(2.4 * r_u)
		f.width = 1.4 * r_u * U
		f.color2 = Color(1, 1, 1, 0.95)
		n = f
	n.name = &"Recluse_burst"
	e.get_parent().add_child(n)
	n.position = pos
	_fx.append({"node": n, "life": life, "max": life})


# --- Rayons (phase 3) ----------------------------------------------------------------

func _build_rays() -> void:
	if not _rays.is_empty():
		return
	_ray_rev_t = -RAY_FIRST_S
	for j in RAYS:
		var tele := _tele(PRAYER_COUNT + j)
		tele.show_line(e.position, 0.0, RAY_LEN_U * U, RAY_W_U * U)
		tele.set_progress(1.0)
		tele.modulate = Color(1.0, 1.0, 1.0, RAY_ALPHA)
		var beam: Node2D
		if _frames != null and _frames.has_animation(&"ray"):
			var s := _sprite(&"ray", Vector2(RAY_LEN_U * U / 896.0, RAY_W_U * U / 64.0), Vector2(448.0, 0.0), 0, 2.6)
			s.play(&"ray")
			e.get_parent().add_child(s)
			beam = s
		else:
			var f := RecluseFx.make(RecluseFx.Kind.BEAM, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.32), 0)
			f.radius = RAY_LEN_U * U
			f.width = RAY_W_U * U * 0.7
			f.color2 = Color(1, 1, 1, 0.85)
			RecluseFx.add_to_tele_layer(f, e.get_parent())
			beam = f
		beam.name = &"Recluse_ray"
		_rays.append({"tele": tele, "beam": beam})
	_place_rays()


func _place_rays() -> void:
	for j in _rays.size():
		var a := _ray_angle + TAU * j / float(RAYS)
		var tele := _rays[j]["tele"] as EnemyTelegraph
		if is_instance_valid(tele):
			tele.global_position = e.position
			tele.rotation = a
		var b := _rays[j]["beam"] as Node2D
		if is_instance_valid(b):
			b.global_position = e.position
			b.rotation = a


func _update_rays(delta: float, player: Node2D, ppos: Vector2) -> void:
	if _rays.is_empty():
		return
	_ray_rev_t += delta
	# surprise lisible : blanchiment + carillon, puis inversion du sens
	var warn := _ray_rev_t >= RAY_REVERSE_EVERY - RAY_WARN_S
	if warn and not _ray_warned:
		_ray_warned = true
		e._sfx(&"telegraph.warn_heavy.heavy", 0.0, true)
		events.append({"kind": &"ray_warn", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	if _ray_rev_t >= RAY_REVERSE_EVERY:
		_ray_rev_t = 0.0
		_ray_warned = false
		ray_dir = -ray_dir
		reversals += 1
		LightRig.flash(e.global_position, &"boss_lightning", 0.3, {"color": CRYSTAL, "radius": 1.4})
	# alerte : clignotement à 6 Hz (rayon un peu plus clair, liseré rouge plus opaque) ; jamais une barre
	# pleine qui masquerait le joueur (captures)
	var pulse := (1.0 if fmod(_ray_rev_t, 0.17) < 0.085 else 0.0) if warn else 0.0
	for r in _rays:
		var b := r["beam"] as CanvasItem
		if is_instance_valid(b):
			b.modulate = Color(1.0, 1.0, 1.0, 1.0 + 0.8 * pulse)
		var tl := r["tele"] as CanvasItem
		if is_instance_valid(tl):
			tl.modulate = Color(1.0, 1.0, 1.0, RAY_ALPHA + 0.3 * pulse)
	if not warn: # les rayons s'immobilisent pendant l'alerte (on lit le blanchiment, puis le sens change)
		_ray_angle = wrapf(_ray_angle + RAY_TURN * ray_dir * delta, 0.0, TAU)
	_place_rays()
	_ray_tick -= delta
	if _ray_tick > 0.0 or player == null or state == S.STAGGER:
		return
	var v := ppos - e.position
	for j in RAYS:
		var d := Vector2.from_angle(_ray_angle + TAU * j / float(RAYS))
		var along := v.dot(d)
		var perp := absf(v.cross(d))
		if along >= 0.0 and along <= RAY_LEN_U * U + PLAYER_R and perp <= RAY_W_U * 0.5 * U + PLAYER_R:
			_ray_tick = RAY_TICK
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"rays"))
			events.append({"kind": &"ray", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			return


# --- Silhouette provisoire -------------------------------------------------------------

func _build_body() -> void:
	_body = RecluseFx.make(RecluseFx.Kind.BODY_RECLUSE, STONE, 0)
	_body.name = &"Recluse_body"
	_body.color2 = CRYSTAL
	e.add_child(_body)
	vis.self_modulate = Color(1, 1, 1, 0) # hexagone de repli masqué (la silhouette le remplace)


func _update_body(delta: float) -> void:
	if _body == null:
		return
	var fl := 1.0 if e.is_flashing() else 0.0
	var target_lift := Iso.lift_logical(LEVITATE_U) * (1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.003)) if phase >= 3 and state != S.STAGGER else 0.0
	var nl := move_toward(_body.lift, target_lift, 60.0 * delta)
	if absf(fl - _body.progress) > 0.01 or absf(nl - _body.lift) > 0.5:
		_body.progress = fl
		_body.lift = nl
		_body.queue_redraw()
	_body.position = vis.position # suit la fente des coups


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

func _sprite(anim: StringName, sc: Vector2, off: Vector2, z: int, energy: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = StringName("Recluse_" + String(anim))
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


## Journal d'impact : anim visible, sa frame, la frame d'impact attendue et le décalage du coup armé
## (sans sprite : anim vide, expect -1, seul le décalage compte).
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
