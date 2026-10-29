class_name OxHerderBrain
extends RefCounted
## IA du Bouvier (boss d'étage 1, Terrasses noyées ; docs/Design_Etages.md §5.1). Créée par Enemy.activate_boss
## quand le skin du boss est « ox_herder », appelée par Enemy.tick (branche BOSS_TIER). Même contrat que
## CerfBrain / RecluseBrain : coups télégraphiés face au joueur, dégâts à la frame d'impact, coefficients
## Balance.BOSS_ATTACK_COEF[&"ox_herder"]. Sans sprites (lot Codex N1c, art/tools/night/requests_bosses1.md) :
## silhouette et effets dessinés provisoires (Floor1Fx, RecluseFx) ; chaque extra du .tres (furrow, stomp_ring,
## mud_wave, dust_burst, bogged_s) remplace son repli dès qu'il est livré.
##
## Buffle d'eau de pierre de 3,4 u harnaché de bronze, cornes-ancres, naseaux d'eau cyan.
## Phases (PV, Balance.BOSS_PHASE_THRESHOLDS : 70 % / 35 %) ; transition = anim trans_pN (boss figé).
## - Phase 1 « Labour » : cornes (auto, cône 70° de 2,8 u) ; Charge (spell_a : ligne 2,5 × 16 u qui suit le joueur
##   puis se fige, télégraphe 1 s, ruée à 13 u/s ; laisse un SILLON d'eau qui ralentit) ; Piétinement (spell_b :
##   anneau de 2 à 6 u, télégraphe 1 s : coller la bête ou s'éloigner).
## - Phase 2 « Attelage » : double charge en V (la seconde jambe vise le joueur depuis la fin de la première,
##   télégraphe 0,8 s) ; sillons plus longs à vivre.
## - Phase 3 « Embourbé » : toutes les 14 s il s'ENFONCE (5,5 s ancré, dégâts reçus ×1,3 = fenêtre de burst) et
##   appelle 2 vagues de boue (lignes 1,4 × 11 u qui tournent, télégraphe continu, 0,4 par 0,5 s) ; SURPRISE : il
##   s'arrache de la boue d'un piétinement (anneau télégraphé 0,9 s) et enchaîne aussitôt une charge.
## Trace après la mort : les sillons et la mare de boue restent jusqu'à la fin de la charge du gros pilier.

enum S { CHASE, HORNS, CHARGE_WIND, CHARGE_DASH, STOMP_WIND, BOGGED, STAGGER }
enum Spell { CHARGE, STOMP }

const ID := &"ox_herder"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const CYAN := Color(0.369, 0.784, 1.0)
const MUD := Color(0.36, 0.27, 0.18)
const WATER := Color(0.20, 0.42, 0.50)
## Par phase (index phase - 1)
const SPEED_MULT := [1.15, 1.25, 1.3]
const AUTO_CD := [1.7, 1.55, 1.4]
const SPELL_CD := [4.6, 4.2, 3.8] ## charge et piétinement alternés (~9 s chacun)
const LIGHT_ENERGY := [2.4, 3.0, 3.4]
const LIGHT_RADIUS := [1.2, 1.35, 1.45]
const LIGHT_LIFT_U := 1.3
const FEET_ENERGY := [2.0, 2.4, 2.8]
const BODY_GAIN := Color(1.2, 1.22, 1.22)
# Cornes (auto)
const HORNS_RANGE_U := 2.8
const HORNS_HALF := 0.61 ## 70°
## Rythme (BossPace, Balance.BOSS_PACE_*) : cornes = &"auto" ; charge = &"charge" (armement planté, ruée, arrêt
## net puis récupération) ; piétinement = &"spell". Embourbé (P3) : ancré, sa propre fenêtre de punition.
# Charge (spell_a)
const CHAIN_WINDUP := 0.8 ## seconde jambe du V / charge après l'arrachement (plancher &"charge" : 0,8 s)
const CHARGE_TRACK := 0.55
const CHARGE_LEN_U := 16.0
const CHARGE_W_U := 2.5
const CHARGE_SPEED_U := 13.0
const CHARGE_CHAIN := [0, 1, 1] ## jambes supplémentaires (P2+ : V)
# Sillons (trace)
const FURROW_W_U := 1.6
const FURROW_LIFE := [8.0, 12.0, 16.0]
const FURROW_MAX := 10
const FURROW_SLOW_MULT := 0.8 ## sillon d'eau : -20 % (Design_Etages §5.1), Player.apply_slow
const FURROW_SRC := Vector2(512.0, 64.0) ## extra `furrow` (sol) : 8 u × 1 u vers +x
# Piétinement (spell_b)
const STOMP_R0_U := 2.0 ## disque sûr contre la bête
const STOMP_R1_U := 6.0
const TEAR_WINDUP := 0.9 ## plancher de l'arrachement (BossPace.windup(&"spell", 3) = 0,85)
# Embourbé (phase 3)
const BOG_EVERY := 14.0
const BOG_FIRST_S := 0.6
const BOG_S := 5.5
const MUD_WARN_S := 1.0
const MUD_LINES := 2
const MUD_LEN_U := 11.0
const MUD_W_U := 1.4
const MUD_TURN := 0.52 ## 30°/s
const MUD_TICK := 0.5
const MUD_ALPHA := 0.55
const MUD_POOL_R_U := 2.4
const SINK_PX := 10.0

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = []
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var bogs := 0
var tears := 0
var dashes := 0

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.4
var _spell_cd := 2.2
var _cycle := 0
var _chain_left := 0
var _dash_left := 0.0
var _dash_hit := false
var _dash_from := Vector2.ZERO
var _horns_bogged_t := -1.0 ## embourbé : coup de cornes armé (s avant l'impact, < 0 : aucun)
var _horns_wind := 0.6 ## durée d'armement du coup de cornes en cours
var pace: BossPace ## armement planté, impact, récupération immobile (scripts/enemies/boss_pace.gd)
var _tear := false ## piétinement d'arrachement (sortie de la boue)
var _bog_t := 0.0
var _mud_angle := 0.0
var _mud_tick := 0.0
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _feet: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = []
var _ring_tele: RecluseFx = null
var _mud: Array[Dictionary] = [] ## {tele, beam}
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
		_body = Floor1Fx.make(Floor1Fx.Kind.BODY_OX)
		_body.name = &"OxHerder_body"
		e.add_child(_body)
		vis.self_modulate = Color(1, 1, 1, 0) # hexagone de repli masqué
	_hz = Floor1Hazards.create(e, _frames, "OxHerder")
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
	_clear_mud()
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	for t in _teles:
		if is_instance_valid(t):
			t.queue_free()
	_teles.clear()
	if is_instance_valid(_ring_tele):
		_ring_tele.queue_free()
	_ring_tele = null
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


## Pendant la ruée et la transition, le Bouvier se déplace (ou reste figé) seul ; armement, récupération et
## enlisement plantés (ni marche ni séparation de foule).
func owns_motion() -> bool:
	return state == S.STAGGER or state == S.CHARGE_DASH or state == S.BOGGED or pace.planted()


## Super-armure le temps d'un coup (et ancré dans la boue) : un recul ferait glisser le boss planté.
func ignores_knockback() -> bool:
	return pace.planted() or state == S.BOGGED


## Embourbé : fenêtre de burst (Balance.BOSS_ANCHOR_DAMAGE_TAKEN).
func damage_taken_mult() -> float:
	var m := Balance.boss_damage_taken_mult(ID, phase)
	if state == S.BOGGED:
		m *= float(Balance.BOSS_ANCHOR_DAMAGE_TAKEN.get(ID, 1.0))
	return m


func hazards() -> Floor1Hazards:
	return _hz if is_instance_valid(_hz) else null


func furrow_count() -> int:
	return _hz.count(&"furrow") if is_instance_valid(_hz) else 0


func mud_count() -> int:
	return _mud.size()


func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase and state != S.CHARGE_DASH:
		_enter_phase(ph)
	_update_fx(delta)
	_update_body()
	_attack_cd -= delta
	_spell_cd -= delta
	_t += delta
	if phase >= 3 and state != S.STAGGER and state != S.BOGGED:
		_bog_t += delta
	var pi := phase - 1
	match state:
		S.STAGGER:
			if _t >= _dur:
				state = S.CHASE
			return Vector2.ZERO
		S.HORNS:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_horns(player, ppos)
			return Vector2.ZERO
		S.CHARGE_WIND:
			_track_charge(dir)
			if _t >= _dur:
				_launch()
			return Vector2.ZERO
		S.CHARGE_DASH:
			_dash_step(delta, player, ppos)
			return Vector2.ZERO
		S.STOMP_WIND:
			_place_ring_tele(_t / _dur)
			if _t >= _dur:
				_resolve_stomp(player, ppos)
			return Vector2.ZERO
		S.BOGGED:
			_update_bog(delta, player, ppos)
			if _attack_cd <= 0.0 and dist < HORNS_RANGE_U * U and not vis.is_attacking():
				_start_horns(dir, true) # embourbé, il encorne encore qui colle : on tape de côté
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering() or vis.is_attacking(): # récupération immobile (fenêtre de punition), fin de fente
		_face(dir)
		return Vector2.ZERO
	if phase >= 3 and _bog_t >= BOG_EVERY:
		_start_bog()
		return Vector2.ZERO
	if _spell_cd <= 0.0 and dist < (CHARGE_LEN_U - 1.0) * U:
		_start_spell(dir)
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < HORNS_RANGE_U * U:
		_start_horns(dir)
		return Vector2.ZERO
	if dist > HORNS_RANGE_U * U * 0.75:
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
	_dur = 8.0 / ANIM_FPS + 0.25
	_spell_cd = maxf(_spell_cd, _dur + 1.0)
	_attack_cd = maxf(_attack_cd, _dur + 0.4)
	_cycle = 0
	_apply_phase_look()
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.5, {"color": CYAN, "radius": 1.4})
	_dust(e.position, 2.0)
	if ph >= 3:
		_bog_t = BOG_EVERY - BOG_FIRST_S # il s'enfonce juste après la transition
	events.append({"kind": &"phase", "phase": ph})


func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	for t in _teles:
		if is_instance_valid(t):
			t.hide_telegraph()
	if is_instance_valid(_ring_tele):
		_ring_tele.visible = false
	_chain_left = 0
	_clear_mud()


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])
	if _body != null:
		_body.glow = 0.5 + 0.25 * phase
		_body.queue_redraw()


func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


# --- Cornes (auto) -------------------------------------------------------------------

func _start_horns(dir: Vector2, bogged := false) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	_horns_wind = BossPace.windup(&"auto", phase)
	if not bogged:
		state = S.HORNS
		_t = 0.0
		_dur = _horns_wind
		pace.wind(&"auto")
	vis.play_attack(&"attack", _horns_wind, aim)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_cone(e.position, aim.angle(), HORNS_RANGE_U * U, HORNS_HALF, EnemyTelegraph.Weight.LIGHT)
	e._sfx(&"telegraph.warn_light.light", -4.0)
	if bogged:
		_horns_bogged_t = _horns_wind


func _resolve_horns(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.brute_cone.heavy")
	var v := ppos - e.position
	if player != null and v.length() <= HORNS_RANGE_U * U + PLAYER_R and absf(angle_difference(aim.angle(), v.angle())) <= HORNS_HALF + 0.15:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"horns"))
	_log(&"horns", &"attack")
	if state == S.HORNS:
		pace.strike(&"auto", phase)
		state = S.CHASE
	else:
		pace.impact(&"auto") # embourbé : déjà ancré, simple arrêt sur image


# --- Charge --------------------------------------------------------------------------

func _start_spell(dir: Vector2) -> void:
	var sp: int = Spell.CHARGE if _cycle % 2 == 0 else Spell.STOMP
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	match sp:
		Spell.CHARGE:
			_chain_left = CHARGE_CHAIN[phase - 1]
			_start_charge(dir, BossPace.windup(&"charge", phase))
		Spell.STOMP:
			_start_stomp(BossPace.windup(&"spell", phase))


func _start_charge(dir: Vector2, windup: float) -> void:
	state = S.CHARGE_WIND
	_t = 0.0
	_dur = windup
	pace.wind(&"charge")
	aim = dir
	_face(aim)
	vis.play_attack(&"cast_a", _dur, aim) # gratte le sol, tête baissée ; la ruée part à la frame d'impact
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_line(e.position, aim.angle(), CHARGE_LEN_U * U, CHARGE_W_U * U)
	e._sfx(&"telegraph.boss.heavy", 0.0, true)


func _track_charge(dir: Vector2) -> void:
	if _t < _dur * CHARGE_TRACK:
		aim = dir
		_face(aim)
		vis.set_strike_dir(aim)
	e.telegraph.global_position = e.position
	e.telegraph.rotation = aim.angle()
	e.telegraph.set_progress(_t / _dur)


func _launch() -> void:
	e.telegraph.hide_telegraph()
	_log(&"charge", &"cast_a")
	e._sfx(&"enemy.shockwave.heavy", 1.0, true)
	state = S.CHARGE_DASH
	pace.act()
	_dash_left = CHARGE_LEN_U / CHARGE_SPEED_U
	_dash_hit = false
	_dash_from = e.position
	dashes += 1
	vis.set_action(&"run")
	_dust(e.position, 1.4)


func _dash_step(delta: float, player: Node2D, ppos: Vector2) -> void:
	_dash_left -= delta
	var want := e.position + aim * CHARGE_SPEED_U * U * delta
	var p := e.nav.resolve(want, e.radius_px) if e.nav else want
	var blocked := p.distance_squared_to(want) > 4.0
	e.position = p
	_face(aim)
	vis.set_action(&"run")
	if not _dash_hit and player != null:
		var v := ppos - e.position
		if v.length() <= maxf(CHARGE_W_U * 0.5 * U, e.radius_px) + PLAYER_R:
			_dash_hit = true
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"charge"))
			events.append({"kind": &"charge_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	if _dash_left > 0.0 and not blocked:
		return
	_furrow(_dash_from, e.position)
	if blocked:
		_dust(e.position, 1.6)
		e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	if _chain_left > 0:
		_chain_left -= 1
		pace.strike(&"charge", phase, false) # arrêt net, planté le temps du nouvel armement
		var to := ppos - e.position
		_start_charge(to.normalized() if to.length_squared() > 1.0 else aim, CHAIN_WINDUP) # V : seconde jambe
		events.append({"kind": &"chain", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
		return
	state = S.CHASE
	vis.set_action(&"idle")
	pace.strike(&"charge", phase) # arrêt net en fin de course, récupération immobile


## Sillon d'eau laissé par la ruée : ralentit (statut slow du joueur), reste après la mort (trace).
func _furrow(a: Vector2, b: Vector2) -> void:
	if not is_instance_valid(_hz):
		return
	var v := b - a
	var len := v.length()
	if len < 0.5 * U:
		return
	var d := v / len
	if _hz.count(&"furrow") >= FURROW_MAX: # le plus ancien se referme
		for z in _hz.zones:
			if z["kind"] == &"furrow":
				z["kind"] = &"furrow_closing"
				z["life"] = float(z["age"]) + 0.3
				break
	var n: Node2D
	if _frames != null and _frames.has_animation(&"furrow"):
		var s := Floor1Fx.sprite(_frames, &"furrow", "OxHerder_", 1.2, -1)
		s.centered = false
		s.offset = Vector2(0.0, -FURROW_SRC.y * 0.5)
		s.scale = Vector2(len / FURROW_SRC.x, FURROW_W_U * U / FURROW_SRC.y)
		s.play(&"furrow")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.BEAM, Color(WATER.r, WATER.g, WATER.b, 0.55), -1)
		f.radius = len
		f.width = FURROW_W_U * U
		f.color2 = Color(CYAN.r, CYAN.g, CYAN.b, 0.5)
		n = f
	n.name = &"OxHerder_furrow"
	n.rotation = d.angle()
	_hz.add_child(n)
	n.global_position = a
	_hz.add_zone({"kind": &"furrow", "shape": &"line", "pos": a, "dir": d, "len": len, "r": FURROW_W_U * 0.5 * U,
		"life": FURROW_LIFE[phase - 1], "slow": true, "slow_mult": FURROW_SLOW_MULT, "trace": true, "node": n})


# --- Piétinement ---------------------------------------------------------------------

func _start_stomp(windup: float) -> void:
	state = S.STOMP_WIND
	_t = 0.0
	_dur = windup
	pace.wind(&"spell")
	vis.play_attack(&"cast_b", _dur, Vector2.ZERO) # se cabre sur place
	if _ring_tele == null:
		_ring_tele = RecluseFx.make(RecluseFx.Kind.RING_TELE, Color.WHITE, 0)
		_ring_tele.name = &"OxHerder_ring"
		RecluseFx.add_to_tele_layer(_ring_tele, e.get_parent())
	_ring_tele.visible = true
	_place_ring_tele(0.0)
	e._sfx(&"telegraph.boss.heavy", 0.0, true)


func _place_ring_tele(p: float) -> void:
	if not is_instance_valid(_ring_tele):
		return
	_ring_tele.global_position = e.position
	_ring_tele.set_param(STOMP_R1_U * U, STOMP_R0_U * U, clampf(p, 0.0, 1.0))


func _resolve_stomp(player: Node2D, ppos: Vector2) -> void:
	if is_instance_valid(_ring_tele):
		_ring_tele.visible = false
	_log(&"tear" if _tear else &"stomp", &"cast_b")
	e._sfx(&"enemy.shockwave.heavy", 3.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.25, {"color": CYAN, "radius": 1.4})
	_shock_fx()
	var d := ppos.distance_to(e.position)
	if player != null and d >= STOMP_R0_U * U - PLAYER_R * 0.5 and d <= STOMP_R1_U * U + PLAYER_R:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"tear" if _tear else &"stomp"))
		events.append({"kind": &"stomp_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	if _tear: # arraché de la boue : charge aussitôt (planté le temps de son armement)
		_tear = false
		_chain_left = 0
		pace.strike(&"spell", phase, false)
		var to := ppos - e.position
		_start_charge(to.normalized() if to.length_squared() > 1.0 else aim, CHAIN_WINDUP)
		return
	pace.strike(&"spell", phase)
	state = S.CHASE


## Onde de choc du piétinement : extra `stomp_ring` (sol, anneau de rayon 124 px) étiré à 6 u, sinon anneau dessiné.
func _shock_fx() -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"stomp_ring"):
		var s := Floor1Fx.sprite(_frames, &"stomp_ring", "OxHerder_", 2.0, -1)
		s.scale = Vector2.ONE * (STOMP_R1_U * U / 124.0)
		s.play(&"stomp_ring")
		n = s
		e.get_parent().add_child(n)
	else:
		var f := RecluseFx.make(RecluseFx.Kind.BAND, Color(MUD.r * 1.6, MUD.g * 1.6, MUD.b * 1.6, 0.45), 0)
		f.radius = STOMP_R1_U * U
		f.inner = STOMP_R0_U * U
		f.width = 3.0
		f.color2 = Color(CYAN.r, CYAN.g, CYAN.b, 0.6)
		f.name = &"OxHerder_shock"
		RecluseFx.add_to_tele_layer(f, e.get_parent())
		n = f
	n.global_position = e.position
	_fx.append({"node": n, "life": 0.45, "max": 0.45})
	_dust(e.position, 2.2)


func _dust(pos: Vector2, r_u: float) -> void:
	if is_instance_valid(_hz):
		_hz.burst_fx(pos, r_u * U, &"dust_burst", 128.0)


# --- Embourbé (phase 3) -----------------------------------------------------------------

func _start_bog() -> void:
	state = S.BOGGED
	_t = 0.0
	_bog_t = 0.0
	bogs += 1
	_mud_angle = (_ppos - e.position).angle() + PI * 0.5 # les vagues partent de travers : le joueur a le temps
	_mud_tick = MUD_WARN_S
	vis.play_special(&"bogged")
	e._sfx(&"telegraph.warn_heavy.heavy", 0.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.4, {"color": CYAN, "radius": 1.2})
	for j in MUD_LINES:
		var tele := _tele(1 + j)
		tele.show_line(e.position, 0.0, MUD_LEN_U * U, MUD_W_U * U)
		tele.set_progress(0.0)
		tele.modulate = Color(1, 1, 1, 0.85)
		var beam: Node2D
		if _frames != null and _frames.has_animation(&"mud_wave"):
			var s := Floor1Fx.sprite(_frames, &"mud_wave", "OxHerder_", 1.0, 0)
			s.centered = false
			s.offset = Vector2(0.0, -48.0)
			s.scale = Vector2(MUD_LEN_U * U / 704.0, MUD_W_U * U / 96.0)
			s.play(&"mud_wave")
			e.get_parent().add_child(s)
			beam = s
		else:
			var f := RecluseFx.make(RecluseFx.Kind.BEAM, Color(MUD.r * 1.5, MUD.g * 1.5, MUD.b * 1.5, 0.6), 0)
			f.radius = MUD_LEN_U * U
			f.width = MUD_W_U * U * 0.8
			f.color2 = Color(0.75, 0.6, 0.4, 0.8)
			RecluseFx.add_to_tele_layer(f, e.get_parent())
			beam = f
		beam.name = &"OxHerder_mud"
		beam.visible = false
		_mud.append({"tele": tele, "beam": beam})
	_place_mud()
	if is_instance_valid(_hz): # mare de boue autour de lui (ralentit, reste après la mort)
		var pool := RecluseFx.make(RecluseFx.Kind.DISC, Color(MUD.r, MUD.g, MUD.b, 0.5), -1)
		pool.radius = MUD_POOL_R_U * U
		pool.width = 2.0
		pool.color2 = Color(MUD.r * 1.6, MUD.g * 1.6, MUD.b * 1.6, 0.6)
		pool.name = &"OxHerder_pool"
		_hz.add_child(pool)
		pool.global_position = e.position
		_hz.add_zone({"kind": &"pool", "shape": &"circle", "pos": e.position, "r": MUD_POOL_R_U * U, "life": 30.0,
			"slow": true, "trace": true, "node": pool})
	events.append({"kind": &"bog", "phase": phase, "anim": vis.current_anim(), "frame": -1, "expect": -1, "lag": 0.0})


func _place_mud() -> void:
	for j in _mud.size():
		var a := _mud_angle + TAU * j / float(MUD_LINES)
		for k in ["tele", "beam"]:
			var n := _mud[j][k] as Node2D
			if is_instance_valid(n):
				n.global_position = e.position
				n.rotation = a


func _update_bog(delta: float, player: Node2D, ppos: Vector2) -> void:
	if _horns_bogged_t >= 0.0:
		_horns_bogged_t -= delta
		e.telegraph.set_progress(1.0 - _horns_bogged_t / _horns_wind)
		if _horns_bogged_t < 0.0:
			_resolve_horns(player, ppos)
	if not vis.is_attacking() and vis.body_sprite() != null and vis.current_anim() != &"bogged_s":
		vis.play_special(&"bogged") # pose tenue (rejouée après un coup de cornes)
	var warn := _t < MUD_WARN_S
	if not warn:
		_mud_angle = wrapf(_mud_angle + MUD_TURN * delta, 0.0, TAU)
	for m in _mud:
		var tele := m["tele"] as EnemyTelegraph
		tele.set_progress(minf(_t / MUD_WARN_S, 1.0))
		if not warn:
			tele.modulate = Color(1, 1, 1, MUD_ALPHA)
		var b := m["beam"] as CanvasItem
		if is_instance_valid(b):
			b.visible = not warn
	_place_mud()
	if not warn and player != null:
		_mud_tick -= delta
		if _mud_tick <= 0.0:
			var v := ppos - e.position
			for j in MUD_LINES:
				var d := Vector2.from_angle(_mud_angle + TAU * j / float(MUD_LINES))
				var along := v.dot(d)
				if along >= 0.0 and along <= MUD_LEN_U * U + PLAYER_R and absf(v.cross(d)) <= MUD_W_U * 0.5 * U + PLAYER_R:
					_mud_tick = MUD_TICK
					e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"mud"))
					events.append({"kind": &"mud", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
					break
	if _t >= BOG_S and _horns_bogged_t < 0.0:
		_clear_mud()
		e.telegraph.hide_telegraph()
		tears += 1
		_tear = true
		_spell_cd = maxf(_spell_cd, 2.5)
		_start_stomp(BossPace.windup(&"spell", phase, TEAR_WINDUP)) # SURPRISE : il s'arrache de la boue


func _clear_mud() -> void:
	for m in _mud:
		if is_instance_valid(m.get("beam")):
			(m["beam"] as Node).queue_free()
		if is_instance_valid(m.get("tele")):
			(m["tele"] as EnemyTelegraph).hide_telegraph()
			(m["tele"] as EnemyTelegraph).modulate = Color.WHITE
	_mud.clear()


# --- Silhouette provisoire -------------------------------------------------------------

func _update_body() -> void:
	if _body == null:
		return
	var fl := 1.0 if e.is_flashing() else 0.0
	var sink := SINK_PX if state == S.BOGGED else 0.0
	if absf(fl - _body.progress) > 0.01 or absf(sink - _body.lift) > 0.5 or absf(angle_difference(_body.facing, e._facing)) > 0.2:
		_body.progress = fl
		_body.lift = sink
		_body.facing = e._facing
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


func _tele(i: int) -> EnemyTelegraph:
	while _teles.size() <= i:
		var t := EnemyTelegraph.new()
		t.name = &"OxHerder_tele"
		e.get_parent().add_child(t)
		_teles.append(t)
	return _teles[i]


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
