class_name HermitCedarBrain
extends RefCounted
## IA du Cèdre-Ermite (boss d'étage 2 alternatif, Forêt-brume ; docs/Design_Etages.md §5.2). Créée par
## Enemy.activate_boss quand le skin du boss est « hermit_cedar », appelée par Enemy.tick (branche BOSS_TIER).
## Même contrat que CerfBrain / RecluseBrain : coups télégraphiés face au joueur, dégâts à la frame d'impact
## (EnemyVisual.play_attack). Dégâts : Balance.BOSS_ATTACK_COEF[&"hermit_cedar"]. Seuils de phase 70 / 35 %.
## Sans sprites (lot Codex N2d, art/tools/night/requests_bosses2.md) : silhouette et racines dessinées
## provisoires (WeaverFx) ; chaque extra du .tres (root_spike, spore_cloud, stump) remplace son repli.
##
## Tréant de 3,6 u, tronc fendu sur une lanterne menthe #9CF0C8, bras-branches, lichen couleur de brume.
## - Phase 1 « L'ermite » (lent) : branche (auto, cône 90° de 3,2 u) ; Racines (spell_a : 4 lignes de 1 × 8 u
##   qui jaillissent autour du joueur, 1 s, une fois sur deux en CAGE « # » dont le centre est sûr — SURPRISE :
##   ne pas bouger sauve —, sinon en RÂTEAU de 4 lignes parallèles dont une passe sur lui) ; Spores (spell_b :
##   cercle de 4 u sur le joueur, 1 s, poison ; le nuage reste 2 s et réempoisonne qui y reste : punit
##   l'immobilité que la cage récompense).
## - Phase 2 (70 %) « Enraciné » : planté, immobile, la fente du tronc s'ouvre (lanterne exposée : +25 % de
##   dégâts reçus, fenêtre de burst) ; +50 % de vitesse d'attaque ; racines ×6 (cage hexagonale / râteau de 6) ;
##   vrille : si le joueur fuit hors de portée, une racine file du pied vers lui (ligne 1 × 10 u, 0,9 s).
## - Phase 3 (35 %) « Déraciné » : charge lente (ligne 3 × 12 u, 1,2 s) en semant des souches (obstacles 6 s) ;
##   SURPRISE : 0,6 s après la charge, chaque souche RÉPOND et lance une racine vers le joueur (1 × 5 u, 1 s).
## Trace : à sa mort il s'effondre en couronne de souches ; elles (et celles des charges) restent jusqu'à la fin de la charge du gros pilier.

enum S { CHASE, BRANCH, ROOTS, SPORES, CHARGE_WIND, CHARGE_DASH, TENDRIL, STAGGER }
enum Spell { ROOTS, SPORES, CHARGE }

const ID := &"hermit_cedar"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const MINT := Color(0.612, 0.941, 0.784) ## #9CF0C8
const BARK := Color(0.43, 0.39, 0.33) ## silhouette provisoire : écorce gris-brun lichéneuse (jamais noire)
## Par phase (index phase - 1)
const SPEED_MULT := [0.8, 0.0, 0.9]
const AUTO_CD := [1.8, 1.2, 1.6] ## P2 : +50 % de vitesse d'attaque
const SPELL_CD := [4.4, 2.95, 3.8]
const SPELL_CYCLE := [[Spell.ROOTS, Spell.SPORES], [Spell.ROOTS, Spell.SPORES], [Spell.CHARGE, Spell.ROOTS, Spell.SPORES]]
const LIGHT_ENERGY := [1.5, 2.3, 1.7]
const LIGHT_RADIUS := [1.15, 1.4, 1.2]
const LIGHT_LIFT_U := 1.6 ## la lanterne est dans la fente du tronc
const FEET_ENERGY := [2.0, 2.6, 2.2]
const BODY_GAIN := Color(1.2, 1.2, 1.18)
# Branche (auto)
const BRANCH_RANGE_U := 3.2
const BRANCH_HALF := 0.785 ## 90°
# Armements et récupérations : BossPace (Balance.BOSS_PACE_*) ; branche et vrille = auto, racines et spores =
# sorts, charge (P3) = ruée (plancher de design CHARGE_WINDUP).
# Racines (spell_a)
const ROOT_LEN_U := 8.0
const ROOT_W_U := 1.0
const ROOT_CAGE_OFF_U := 1.35 ## demi-écart de la cage : carré central sûr de ~1,7 u
const ROOT_RAKE_GAP_U := 2.0
const ROOT_COUNT := [4, 6, 4]
const ROOT_SHOW_S := 0.7 ## racines visibles après l'impact
# Spores (spell_b)
const SPORE_R_U := 2.0 ## cercle de 4 u
const SPORE_LINGER := 2.0
const SPORE_REPOISON := 1.0
# Vrille (phase 2)
const TENDRIL_LEN_U := 10.0
const TENDRIL_W_U := 1.0
const TENDRIL_WINDUP := 0.9 ## plancher propre (ligne de 10 u) au-dessus de l'auto BossPace
# Charge (phase 3)
const CHARGE_LEN_U := 12.0
const CHARGE_W_U := 3.0
const CHARGE_WINDUP := 1.2 ## plancher de design (charge lente) au-dessus de la ruée BossPace
const CHARGE_SPEED_U := 8.0 ## lente : ~1,5 s de course
const STUMP_STEP_U := 2.0
const STUMP_R_U := 0.45
const STUMP_LIFE := 6.0
const ECHO_DELAY := 0.6
const ECHO_LEN_U := 5.0
const ECHO_W_U := 1.0
const ECHO_WINDUP := 1.0
const ECHO_REACH_U := 12.0 ## toutes les souches à moins de 12 u répondent (volée qui converge)
const DEATH_STUMPS := 5 ## trace : souches laissées à sa mort, autour du tronc
const DEATH_STUMP_RING_U := 2.2

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = []
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var anchor := Vector2.ZERO ## point d'enracinement (phase 2)
var echoes := 0 ## racines lancées par les souches (tests)
var pace: BossPace ## armement planté, impact, récupération immobile (scripts/enemies/boss_pace.gd)

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.4
var _spell_cd := 2.2
var _cycle := 0
var _root_cycle := 0
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _feet: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = []
var _roots: Array[Dictionary] = [] ## lignes de racines armées : {from, dir, len, w, tele, t0, wind, kind, coef}
var _clouds: Array[Dictionary] = [] ## nuages de spores : {pos, life, tick, node}
var _fx: Array[Dictionary] = []
var _body: WeaverFx = null
var _snare: WeaverSnare = null
var _dash_left := 0.0
var _dash_hit := false
var _stump_acc := 0.0
var _charge_stumps: Array[Vector2] = []
var _echo_t := -1.0
var _spore_at := Vector2.ZERO
var _roots_hit := false


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
	_snare = WeaverSnare.create(e, "Cedar")
	if _snare != null:
		_snare.frames = _frames
	_apply_phase_look()


func clear() -> void:
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	if is_instance_valid(_snare):
		if killed:
			# il s'effondre et ses racines restent : couronne de souches autour du tronc (trace)
			for k in DEATH_STUMPS:
				var p := e.position + Vector2.from_angle(TAU * k / DEATH_STUMPS + 0.4) * DEATH_STUMP_RING_U * U
				if e.nav == null or not e.nav.is_wall_at(p):
					_snare.add_obstacle(p, STUMP_R_U, STUMP_LIFE, &"stump")
			_snare.on_boss_dead()
		else:
			_snare.release()
	_snare = null
	for c in _clouds:
		if is_instance_valid(c.get("node")):
			(c["node"] as Node).queue_free()
	_clouds.clear()
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	for t in _teles:
		if is_instance_valid(t):
			t.queue_free()
	_teles.clear()
	_roots.clear()
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


## Enraciné (phase 2) : rien ne le déplace, pas même la séparation de la foule.
func owns_motion() -> bool:
	return state in [S.CHARGE_DASH, S.STAGGER] or phase == 2 or pace.planted()


## Super-armure pendant l'armement et la récupération (un recul ferait glisser le boss planté).
func ignores_knockback() -> bool:
	return pace.planted()


func damage_taken_mult() -> float:
	return Balance.boss_damage_taken_mult(ID, phase)


func is_rooted() -> bool:
	return phase == 2


func snare() -> WeaverSnare:
	return _snare if is_instance_valid(_snare) else null


func root_count() -> int:
	return _roots.size()


func cloud_count() -> int:
	return _clouds.size()


func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase and state != S.CHARGE_DASH:
		_enter_phase(ph)
	if phase == 2:
		e.position = anchor
	_update_roots(delta, player, ppos)
	_update_clouds(delta, player, ppos)
	_update_echo(delta, ppos)
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
			return Vector2.ZERO
		S.BRANCH:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_branch(player, ppos)
			return Vector2.ZERO
		S.ROOTS:
			if _t >= _dur: # les racines jaillissent ce pas-ci (_update_roots, même durée d'armement)
				pace.strike(&"spell", phase)
				state = S.CHASE
			return Vector2.ZERO
		S.SPORES:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_release_spores(player, ppos)
			return Vector2.ZERO
		S.TENDRIL:
			if _t >= _dur: # la vrille jaillit ce pas-ci (_update_roots)
				pace.strike(&"auto", phase)
				state = S.CHASE
			return Vector2.ZERO
		S.CHARGE_WIND:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				pace.act()
				state = S.CHARGE_DASH
				_t = 0.0
				_dash_left = CHARGE_LEN_U * U
				_dash_hit = false
				_stump_acc = STUMP_STEP_U * U * 0.5
				_charge_stumps.clear()
				_log(&"charge", &"cast_a")
				e._sfx(&"enemy.shockwave.heavy", 0.0, true)
			return Vector2.ZERO
		S.CHARGE_DASH:
			_dash_step(delta, player, ppos)
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering(): # récupération immobile : fenêtre de punition
		_face(dir)
		return Vector2.ZERO
	if vis.is_attacking():
		_face(dir)
		return Vector2.ZERO
	if _spell_cd <= 0.0 and dist < (ROOT_LEN_U + 6.0) * U:
		_start_spell(dir, ppos)
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < BRANCH_RANGE_U * U:
		_start_branch(dir)
		return Vector2.ZERO
	if phase == 2:
		if _attack_cd <= 0.0 and dist < (TENDRIL_LEN_U + 1.0) * U:
			_start_tendril(dir)
			return Vector2.ZERO
		_face(dir)
		vis.set_action(&"idle")
		return Vector2.ZERO
	if SPEED_MULT[pi] > 0.0 and dist > BRANCH_RANGE_U * U * 0.75:
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
	_dur = 8.0 / ANIM_FPS + 0.25
	_spell_cd = maxf(_spell_cd, _dur + 1.0)
	_attack_cd = maxf(_attack_cd, _dur + 0.4)
	_cycle = 0
	if ph == 2:
		anchor = e.position # il s'enracine là où il est
	_apply_phase_look()
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	LightRig.flash(e.global_position, &"boss_cerf", 0.6, {"color": MINT, "radius": 1.6})
	_burst_roots_fx(e.position, 8 if ph == 2 else 5) # racines qui s'enfoncent (P2) / s'arrachent (P3)
	events.append({"kind": &"phase", "phase": ph})


func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	for r in _roots:
		if is_instance_valid(r.get("tele")):
			(r["tele"] as EnemyTelegraph).hide_telegraph()
	_roots.clear()


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.15 if phase >= 3 else -1.0, 2.0)
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])
	if _body != null:
		_body.glow = [0.7, 1.8, 1.0][pi] # P2 : fente grande ouverte sur la lanterne
		_body.queue_redraw()


# --- Branche (auto) / vrille ---------------------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func _start_branch(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.BRANCH
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_cone(e.position, aim.angle(), BRANCH_RANGE_U * U, BRANCH_HALF, EnemyTelegraph.Weight.LIGHT)
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _resolve_branch(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.brute_cone.heavy")
	var v := ppos - e.position
	if player != null and v.length() <= BRANCH_RANGE_U * U + PLAYER_R and absf(angle_difference(aim.angle(), v.angle())) <= BRANCH_HALF + 0.15:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"branch"))
	_log(&"branch", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


## Phase 2 : le joueur fuit l'enraciné -> une racine file du pied vers lui.
func _start_tendril(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1] * 1.6
	aim = dir
	_face(aim)
	state = S.TENDRIL
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase, TENDRIL_WINDUP)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	var from := e.position + aim * e.radius_px * 0.5
	_arm_root(from, aim, _ray_len(from, aim, TENDRIL_LEN_U * U), TENDRIL_W_U * U, _dur, &"tendril", &"tendril")
	e._sfx(&"telegraph.warn_light.light", -2.0)


# --- Sorts ---------------------------------------------------------------------------

func _start_spell(dir: Vector2, ppos: Vector2) -> void:
	var cyc: Array = SPELL_CYCLE[phase - 1]
	var sp: int = cyc[_cycle % cyc.size()]
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	_t = 0.0
	match sp:
		Spell.ROOTS:
			_start_roots(ppos)
		Spell.SPORES:
			state = S.SPORES
			_dur = BossPace.windup(&"spell", phase)
			pace.wind(&"spell")
			_spore_at = _walkable(ppos)
			vis.play_attack(&"cast_b", _dur, Vector2.ZERO)
			e.telegraph.modulate = Color.WHITE
			e.telegraph.show_circle(_spore_at, SPORE_R_U * U)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)
		Spell.CHARGE:
			state = S.CHARGE_WIND
			_dur = BossPace.windup(&"charge", phase, CHARGE_WINDUP)
			pace.wind(&"charge")
			aim = dir
			vis.play_attack(&"cast_a", _dur, aim) # il s'arrache du sol, branches en avant
			e.telegraph.modulate = Color.WHITE
			e.telegraph.show_line(e.position - aim * e.radius_px * 0.5, aim.angle(), CHARGE_LEN_U * U + e.radius_px * 0.5, CHARGE_W_U * U)
			e._sfx(&"telegraph.boss.heavy", 2.0, true)


# --- Racines ---------------------------------------------------------------------------

## Cage « # » (centre sûr) ou râteau (lignes parallèles, une sur le joueur), alternés. P2 : 6 lignes
## (cage hexagonale : 3 orientations à 60°).
func _start_roots(ppos: Vector2) -> void:
	state = S.ROOTS
	_dur = BossPace.windup(&"spell", phase)
	pace.wind(&"spell")
	vis.play_attack(&"cast_a", _dur, Vector2.ZERO)
	_roots_hit = false
	var n: int = ROOT_COUNT[phase - 1]
	var cage := _root_cycle % 2 == 0
	_root_cycle += 1
	var c := ppos
	var base := _rng.randf() * PI
	var lines: Array = [] # [centre, angle]
	if cage:
		var orients := int(n / 2.0)
		for k in orients:
			var a := base + PI * k / orients
			var nrm := Vector2.from_angle(a + PI * 0.5)
			for s in [-1.0, 1.0]:
				lines.append([c + nrm * s * ROOT_CAGE_OFF_U * U, a])
	else:
		var a := (ppos - e.position).angle() + PI * 0.5 # en travers de l'axe boss -> joueur
		var nrm := Vector2.from_angle(a + PI * 0.5)
		var first := -_rng.randi_range(0, n - 1) # le joueur est sur une des lignes, au hasard
		for k in n:
			lines.append([c + nrm * (first + k) * ROOT_RAKE_GAP_U * U, a])
	for l in lines:
		var d := Vector2.from_angle(float(l[1]))
		var from: Vector2 = (l[0] as Vector2) - d * ROOT_LEN_U * 0.5 * U
		_arm_root(from, d, ROOT_LEN_U * U, ROOT_W_U * U, _dur, &"roots", &"roots")
	events.append({"kind": &"roots_cast", "phase": phase, "cage": cage, "n": lines.size(), "center": c})
	e._sfx(&"telegraph.boss.heavy", 0.0, true)


func _arm_root(from: Vector2, d: Vector2, len: float, w: float, wind: float, kind: StringName, coef: StringName) -> void:
	var tele := _free_tele()
	tele.modulate = Color.WHITE
	tele.show_line(from, d.angle(), len, w)
	_roots.append({"from": from, "dir": d, "len": len, "w": w, "tele": tele, "t": 0.0, "wind": wind, "kind": kind, "coef": coef})


func _update_roots(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := 0
	var logged := {}
	while i < _roots.size():
		var r: Dictionary = _roots[i]
		r["t"] = float(r["t"]) + delta
		var tele := r["tele"] as EnemyTelegraph
		tele.set_progress(float(r["t"]) / float(r["wind"]))
		if float(r["t"]) < float(r["wind"]):
			i += 1
			continue
		tele.hide_telegraph()
		var kind: StringName = r["kind"]
		var from: Vector2 = r["from"]
		var to: Vector2 = from + (r["dir"] as Vector2) * float(r["len"])
		_root_fx(from, r["dir"], float(r["len"]), float(r["w"]))
		var touch := player != null and WeaverSnare._seg_dist(ppos, from, to) <= float(r["w"]) * 0.5 + PLAYER_R
		if kind == &"roots":
			if not logged.has(kind):
				logged[kind] = true
				_log(&"roots", &"cast_a")
				e._sfx(&"enemy.shockwave.heavy", 0.0, true)
			if touch and not _roots_hit: # un lancer ne touche qu'une fois
				_roots_hit = true
				e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"roots"))
				events.append({"kind": &"roots_hit", "phase": phase})
		else:
			if kind == &"tendril":
				_log(&"tendril", &"attack")
			else:
				events.append({"kind": kind, "phase": phase})
			e._sfx(&"enemy.brute_cone.heavy", -2.0)
			if touch:
				e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, r["coef"]))
				events.append({"kind": StringName(String(kind) + "_hit"), "phase": phase})
		_roots.remove_at(i)


func _root_fx(from: Vector2, d: Vector2, len: float, w: float) -> void:
	var n: Node2D
	var an := _first_anim(["root_spike", "roots", "root_line", "root_burst"])
	if an != &"":
		var s := _sprite(an, Vector2.ONE, Vector2.ZERO, 0, 2.0)
		s.centered = false
		var tex := _frames.get_frame_texture(an, 0)
		var tw := float(tex.get_width()) if tex != null else 512.0
		var th := float(tex.get_height()) if tex != null else 128.0
		s.offset = Vector2(0.0, -th * 0.5)
		s.scale = Vector2(len / tw, w / th) # extra « sol » : 1 u = 64 px, vu de dessus
		s.play(an)
		n = s
	else:
		var f := WeaverFx.make(WeaverFx.Kind.ROOT, BARK.lightened(0.05), 0)
		f.radius = len
		f.width = w * 0.5
		f.dir = d
		f.progress = 1.0
		n = f
	n.name = &"Cedar_root"
	e.get_parent().add_child(n)
	n.position = from
	if not (n is WeaverFx):
		n.rotation = d.angle()
	_fx.append({"node": n, "life": ROOT_SHOW_S, "max": ROOT_SHOW_S})


func _burst_roots_fx(c: Vector2, n: int) -> void:
	for k in n:
		var d := Vector2.from_angle(TAU * k / n + _rng.randf() * 0.3)
		_root_fx(c + d * e.radius_px * 0.6, d, 2.2 * U, 0.6 * U)


# --- Spores ----------------------------------------------------------------------------

func _release_spores(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	_log(&"spores", &"cast_b")
	e._sfx(&"enemy.shockwave.heavy", -3.0, true)
	var node: Node2D
	var an := _first_anim(["spore_cloud", "spores"])
	if an != &"":
		var s := _sprite(an, Vector2.ONE * (SPORE_R_U * 2.0 * U / _cell_w(an, 256.0)), Vector2.ZERO, 1, 1.6) # sol : la cellule = le cercle
		s.play(an)
		node = s
	else:
		var f := WeaverFx.make(WeaverFx.Kind.SPORES, WeaverFx.MIST, 1)
		f.radius = SPORE_R_U * U
		node = f
	node.name = &"Cedar_spores"
	e.get_parent().add_child(node)
	node.position = _spore_at
	_clouds.append({"pos": _spore_at, "life": SPORE_LINGER, "tick": SPORE_REPOISON, "node": node})
	if player != null and _spore_at.distance_to(ppos) <= SPORE_R_U * U + PLAYER_R:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"spores"))
		_poison(player)
		events.append({"kind": &"spores_hit", "phase": phase})
	pace.strike(&"spell", phase)
	state = S.CHASE


func _poison(player: Node2D) -> void:
	if player.has_method(&"apply_status"):
		player.apply_status(&"poison", {"hit": e.damage * Balance.boss_attack_coef(ID, &"spore_poison"), "source": e})
		events.append({"kind": &"poison", "phase": phase})


func _update_clouds(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := _clouds.size() - 1
	while i >= 0:
		var c: Dictionary = _clouds[i]
		c["life"] = float(c["life"]) - delta
		c["tick"] = float(c["tick"]) - delta
		var n := c["node"] as CanvasItem
		if is_instance_valid(n):
			n.modulate.a = clampf(float(c["life"]) / 0.6, 0.0, 1.0)
		if float(c["tick"]) <= 0.0 and float(c["life"]) > 0.0:
			c["tick"] = SPORE_REPOISON
			if player != null and (c["pos"] as Vector2).distance_to(ppos) <= SPORE_R_U * U + PLAYER_R:
				_poison(player) # rester dans le nuage réempoisonne (poison ~6 s au total)
		if float(c["life"]) <= 0.0:
			if is_instance_valid(n):
				n.queue_free()
			_clouds.remove_at(i)
		i -= 1


# --- Charge (phase 3) -------------------------------------------------------------------

func _dash_step(delta: float, player: Node2D, ppos: Vector2) -> void:
	var step := minf(CHARGE_SPEED_U * U * delta, _dash_left)
	_dash_left -= step
	var want := e.position + aim * step
	var p := e.nav.resolve(want, e.radius_px) if e.nav else want
	var blocked := p.distance_squared_to(want) > 4.0
	var moved := p.distance_to(e.position)
	e.position = p
	_face(aim)
	vis.set_action(&"run")
	e.telegraph.global_position = e.position - aim * e.radius_px * 0.5
	_stump_acc += moved
	if _stump_acc >= STUMP_STEP_U * U:
		_stump_acc = 0.0
		var sp := e.position - aim * (e.radius_px + STUMP_R_U * U + 4.0) # derrière lui
		if is_instance_valid(_snare) and (e.nav == null or not e.nav.is_wall_at(sp)):
			_snare.add_obstacle(sp, STUMP_R_U, STUMP_LIFE, &"stump")
			_charge_stumps.append(sp)
	if not _dash_hit and player != null:
		var v := ppos - e.position
		var perp := absf(v.cross(aim))
		if perp <= CHARGE_W_U * 0.5 * U + PLAYER_R and v.dot(aim) > -e.radius_px and v.dot(aim) < e.radius_px + PLAYER_R:
			_dash_hit = true
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"charge"))
			events.append({"kind": &"charge_hit", "phase": phase})
	if _dash_left <= 0.0 or blocked:
		e.telegraph.hide_telegraph()
		e._sfx(&"enemy.shockwave.heavy", 2.0, true)
		LightRig.flash(e.global_position, &"boss_cerf", 0.35, {"color": MINT})
		pace.strike(&"charge", phase) # fin de course : arrêt net, récupération immobile
		state = S.CHASE
		_attack_cd = maxf(_attack_cd, 0.8)
		if not _charge_stumps.is_empty():
			_echo_t = ECHO_DELAY


## SURPRISE : les souches de la charge répondent, chacune lance une racine vers le joueur.
func _update_echo(delta: float, ppos: Vector2) -> void:
	if _echo_t < 0.0:
		return
	_echo_t -= delta
	if _echo_t > 0.0:
		return
	_echo_t = -1.0
	var alive: Array[Vector2] = []
	if is_instance_valid(_snare):
		alive = _snare.obstacle_positions(&"stump")
	for sp in _charge_stumps:
		if not alive.has(sp):
			continue
		var d := ppos - sp
		if d.length() < 1.0 or d.length() > ECHO_REACH_U * U:
			continue
		_arm_root(sp, d.normalized(), ECHO_LEN_U * U, ECHO_W_U * U, ECHO_WINDUP, &"echo", &"echo")
		echoes += 1
	_charge_stumps.clear()
	if echoes > 0:
		e._sfx(&"telegraph.warn_heavy.heavy", 0.0, true)


# --- Silhouette provisoire ---------------------------------------------------------------

func _build_body() -> void:
	_body = WeaverFx.make(WeaverFx.Kind.BODY_CEDAR, BARK, 0)
	_body.name = &"Cedar_body"
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
			n.modulate.a = clampf(float(f["life"]) / float(f["max"]) * 1.5, 0.0, 1.0)
			if n is WeaverFx:
				(n as WeaverFx).set_progress(clampf((float(f["max"]) - float(f["life"])) / 0.12, 0.0, 1.0))
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
	s.name = StringName("Cedar_" + String(anim))
	EmissiveOverlay.apply(s, _frames, energy)
	s.animation = anim
	s.scale = sc
	s.offset = off
	s.z_index = z
	return s


## Télégraphe libre du pool (les racines armées en gardent un chacune jusqu'à l'impact).
func _free_tele() -> EnemyTelegraph:
	for t in _teles:
		var used := false
		for r in _roots:
			if r["tele"] == t:
				used = true
				break
		if not used:
			return t
	var nt := EnemyTelegraph.new()
	e.get_parent().add_child(nt)
	_teles.append(nt)
	return nt


## Largeur de la cellule d'un extra (échelle adaptée à la planche livrée).
func _cell_w(anim: StringName, fallback: float) -> float:
	var tex := _frames.get_frame_texture(anim, 0) if _frames != null else null
	return float(tex.get_width()) if tex != null else fallback


func _walkable(p: Vector2) -> Vector2:
	return e.nav.resolve(p, PLAYER_R) if e.nav else p


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
