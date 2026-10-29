class_name SmelterBrain
extends RefCounted
## IA du Fondeur (boss d'étage 3, Cité de rouille ; docs/Design_Etages.md §5.3). Créée par Enemy.activate_boss
## quand le skin du boss est « smelter », appelée par Enemy.tick (branche BOSS_TIER). Même contrat que
## SonneurBrain / CraneBrain : coups télégraphiés face au joueur (le sprite prend la plus proche de ses
## 4 orientations e/s/w/n : auto/spell_a/spell_b_<dir>), dégâts à la frame d'impact. Dégâts :
## Balance.BOSS_ATTACK_COEF[&"smelter"]. Sans sprites (art/tools/night/requests_bosses3.md#fondeur) :
## silhouette et métal dessinés provisoires (SmelterFx) ; chaque extra du .tres les remplace.
##
## Automate-forge trapu de 3,5 u, creuset ouvert à la place du torse, bras-louches ; fonte rouillée, métal
## en fusion orange sodium #FF9A3C (accent unique).
## Phases (PV ; seuils Balance.BOSS_PHASE_THRESHOLDS : 70 / 35 %) :
## - Phase 1 « Coulée » : louche (auto, cône 80° de 3 u, brûlure) ; Coulée (spell_a : ligne 2 × 12 u vers le
##   joueur, 1,0 s, coef 1,5 + brûlure ; le métal RESTE 5 s : 0,5 par 0,5 s + brûlure) ; Étincelles (spell_b :
##   6 projectiles en éventail).
## - Phase 2 « Débordement » : le creuset déborde toutes les 11 s : anneau de métal à 5 u autour du Fondeur,
##   2 brèches éclairées par des lampes au sodium (alerte 1,2 s, reste 6 s).
## - Phase 3 « Surchauffe » : +25 % de dégâts reçus, coulées en croix (4 lignes), 2 jets de vapeur qui
##   tournent (1 × 7 u). SURPRISE « Trempe » : toutes les 8 s l'orage s'en mêle : tout le métal au sol
##   blanchit et crépite (alerte 1,2 s), la foudre tombe dans la fonte et ÉLECTRISE toutes les flaques
##   (coef 1,6 si le joueur y est), puis la pluie fige le métal d'un coup dans un nuage de vapeur : l'arène
##   se vide… et le Fondeur recommence à la remplir.
## Trace (mort pendant la charge du gros pilier) : le métal reste et brûle jusqu'à la fin de la charge.

enum S { CHASE, LADLE, POUR, SPARKS, STAGGER }
enum Spell { POUR, SPARKS }

const ID := &"smelter"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const SODIUM := Color(1.0, 0.604, 0.235) ## #FF9A3C
const IRON := Color(0.56, 0.43, 0.35) ## silhouette provisoire : fonte rouillée claire (lisible de nuit)
const SPEED_MULT := [1.0, 1.06, 1.12]
const AUTO_CD := [2.0, 1.8, 1.6]
const SPELL_CD := [4.2, 3.8, 3.3] ## coulée et étincelles alternées
const LIGHT_ENERGY := [3.4, 3.8, 4.8]
const LIGHT_RADIUS := [1.3, 1.4, 1.6]
const LIGHT_LIFT_U := 2.4 ## la bouche du creuset éclaire le haut du corps
const FEET_ENERGY := [2.0, 2.3, 2.9]
const BODY_GAIN := Color(1.6, 1.55, 1.5)
# Louche (auto)
const LADLE_RANGE_U := 3.0
const LADLE_HALF := 0.70 ## 80°
## Armements et récupérations : BossPace (Balance.BOSS_PACE_*) ; louche = auto, coulée et étincelles = spell.
# Coulée (spell_a)
const POUR_WINDUP := 1.0 ## plancher de l'armement de la coulée (spell : max(table, 1 s))
const POUR_LEN_U := 12.0
const POUR_W_U := 2.0
const POUR_START_U := 1.0 ## part du bord du creuset
const POOL_LIFE := 5.0
const POOL_TICK := 0.5
# Étincelles (spell_b)
const SPARK_COUNT := 6
const SPARK_SPREAD := 0.24 ## rad entre deux étincelles (éventail de ~70°)
const SPARK_SPEED_U := 7.0
const SPARK_TELE_U := 8.0
# Débordement (phase 2+)
const OVERFLOW_EVERY := [0.0, 11.0, 13.0]
const OVERFLOW_FIRST := 1.2
const OVERFLOW_WARN := 1.2
const OVERFLOW_LIFE := 6.0
const RING_R_U := 5.0
const RING_BAND_U := 1.2
const GAP_HALF := 0.45 ## ~2,2 u de passage à 5 u
# Vapeur (phase 3)
const STEAM_JETS := 2
const STEAM_LEN_U := 7.0
const STEAM_W_U := 1.0
const STEAM_TURN := 0.436 ## 25°/s
const STEAM_TICK := 0.5
const STEAM_ALPHA := 0.55
# Trempe (phase 3)
const QUENCH_EVERY := 8.0
const QUENCH_FIRST := 3.5
const QUENCH_WARN := 1.2
const QUENCH_TELES := 8

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = []
var pace: BossPace ## armement planté, impact, récupération immobile (BossPace)
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var quenches := 0
var burns := 0 ## brûlures appliquées au joueur (tests)

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.4
var _spell_cd := 2.4
var _cycle := 0
var _pool_tick := 0.0
var _overflow_cd := 0.0
var _overflow_t := -1.0 ## >= 0 : anneau en alerte
var _overflow_c := Vector2.ZERO
var _overflow_gaps: Array = []
var _warn_ring: SmelterFx = null
var _quench_cd := 0.0
var _quench_t := -1.0
var _quench_pos := Vector2.ZERO
var _steam_angle := 0.0
var _steam_tick := 0.0
var _jets: Array[Dictionary] = [] ## {tele, puffs}
var _pour_angles: Array[float] = []
var _body_tilt := 0.0 ## creuset penché au débordement (silhouette provisoire)
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _storm_frames: SpriteFrames = null
var _feet: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = []
var _fx: Array[Dictionary] = []
var _body: SmelterFx = null
var _slag: SmelterSlag = null


func _init(enemy: Enemy) -> void:
	e = enemy
	vis = enemy.visual as EnemyVisual
	pace = BossPace.new(enemy)
	_rng.randomize()
	_frames = EnemyVisual.boss_frames(ID)
	_storm_frames = EnemyVisual.boss_frames(&"sonneur")
	if e._light != null:
		e._light.set_preset(&"boss_cerf")
		e._light.set_color(SODIUM)
		e._light.position = Vector2(0.0, Iso.lift_logical(LIGHT_LIFT_U))
	_feet = LightRig.attach(e, &"boss_cerf_hooves", {"color": SODIUM})
	if vis.body_sprite() != null:
		vis.body_sprite().self_modulate = BODY_GAIN
	else:
		_build_body()
	if e.get_parent() != null:
		_slag = SmelterSlag.create(e.get_parent(), _frames)
	_apply_phase_look()


func clear() -> void:
	if pace != null:
		pace.cancel()
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	if is_instance_valid(_slag):
		if killed:
			_slag.keep_until_charge(e.damage * Balance.boss_attack_coef(ID, &"pool"))
		else:
			_slag.release()
	_slag = null
	for j in _jets:
		for p in j["puffs"]:
			if is_instance_valid(p):
				(p as Node).queue_free()
	_jets.clear()
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	if is_instance_valid(_warn_ring):
		_warn_ring.queue_free()
	_warn_ring = null
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


## Transition de phase, armement et récupération : planté (ni marche ni séparation de foule).
func owns_motion() -> bool:
	return state == S.STAGGER or pace.planted()


## Super-armure le temps d'un coup (BossPace) : un recul ferait glisser le Fondeur planté.
func ignores_knockback() -> bool:
	return pace.planted()


## Surchauffe (P3) : +25 % de dégâts reçus (Balance.BOSS_PHASE_DAMAGE_TAKEN).
func damage_taken_mult() -> float:
	return Balance.boss_damage_taken_mult(ID, phase)


func slag() -> SmelterSlag:
	return _slag if is_instance_valid(_slag) else null


func jet_count() -> int:
	return _jets.size()


func steam_angle() -> float:
	return _steam_angle


func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase:
		_enter_phase(ph)
	_update_metal(delta, player, ppos)
	_update_overflow(delta)
	_update_quench(delta, player, ppos)
	_update_steam(delta, player, ppos)
	_update_fx(delta)
	_update_body()
	_attack_cd -= delta
	_spell_cd -= delta
	_t += delta
	var pi := phase - 1
	match state:
		S.STAGGER:
			if _t >= _dur:
				state = S.CHASE
				if phase >= 3:
					_build_steam()
			return Vector2.ZERO
		S.LADLE:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_ladle(player, ppos)
			return Vector2.ZERO
		S.POUR:
			for i in _pour_angles.size():
				var tl := _tele(i)
				tl.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_pour(player, ppos)
			return Vector2.ZERO
		S.SPARKS:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_sparks()
			return Vector2.ZERO
	if pace.recovering(): # récupération immobile : fenêtre de punition, aucun nouveau coup
		_face(dir)
		return Vector2.ZERO
	if vis.is_attacking():
		_face(dir)
		return Vector2.ZERO
	if _spell_cd <= 0.0 and dist < (POUR_LEN_U - 1.0) * U:
		_start_spell(dir, ppos)
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < LADLE_RANGE_U * U:
		_start_ladle(dir)
		return Vector2.ZERO
	if dist > LADLE_RANGE_U * U * 0.7:
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
	_dur = 8.0 / ANIM_FPS + 0.2
	_spell_cd = maxf(_spell_cd, _dur + 1.0)
	_attack_cd = maxf(_attack_cd, _dur + 0.4)
	_cycle = 0
	if ph == 2:
		_overflow_cd = _dur + OVERFLOW_FIRST # le creuset déborde en sortant de la transition
	if ph >= 3:
		_quench_cd = _dur + QUENCH_FIRST
		e._sfx(&"enemy.shockwave.heavy", 2.0, true)
	_apply_phase_look()
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.5, {"color": SODIUM, "radius": 1.6})
	events.append({"kind": &"phase", "phase": ph})


func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	for i in mini(_teles.size(), 4):
		if is_instance_valid(_teles[i]):
			_teles[i].hide_telegraph()
	_pour_angles.clear()


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.25 if phase >= 3 else 0.1, 7.0) # le métal du creuset bouillonne
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])
	if _body != null:
		_body.heat = 1.0 if phase >= 3 else 0.0
		_body.queue_redraw()


# --- Louche (auto) ------------------------------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func _start_ladle(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.LADLE
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_cone(e.position, aim.angle(), LADLE_RANGE_U * U, LADLE_HALF, EnemyTelegraph.Weight.LIGHT)
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _resolve_ladle(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.brute_cone.heavy")
	var v := ppos - e.position
	if player != null and v.length() <= LADLE_RANGE_U * U + PLAYER_R and absf(angle_difference(aim.angle(), v.angle())) <= LADLE_HALF + 0.15:
		var dmg := e.damage * Balance.boss_attack_coef(ID, &"ladle")
		e._hit_player(player, dmg)
		_burn(player, dmg)
	_splash(e.position + aim * LADLE_RANGE_U * 0.6 * U, 0.9)
	_log(&"ladle", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


func _burn(player: Node2D, hit: float) -> void:
	if player != null and player.has_method(&"apply_status"):
		player.apply_status(&"burn", {"hit": hit, "source": e})
		burns += 1


# --- Sorts -------------------------------------------------------------------------

func _start_spell(dir: Vector2, ppos: Vector2) -> void:
	var sp: int = Spell.POUR if _cycle % 2 == 0 else Spell.SPARKS
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	_t = 0.0
	match sp:
		Spell.POUR:
			state = S.POUR
			_dur = BossPace.windup(&"spell", phase, POUR_WINDUP)
			pace.wind(&"spell")
			vis.play_attack(&"cast_a", _dur, Vector2.ZERO) # le creuset bascule
			_pour_angles.clear()
			var n := 4 if phase >= 3 else 1
			for i in n:
				_pour_angles.append(aim.angle() + TAU * i / float(n))
			for i in _pour_angles.size():
				var d := Vector2.from_angle(_pour_angles[i])
				_tele(i).show_line(e.position + d * POUR_START_U * U, _pour_angles[i], POUR_LEN_U * U, POUR_W_U * U)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)
		Spell.SPARKS:
			state = S.SPARKS
			_dur = BossPace.windup(&"spell", phase)
			pace.wind(&"spell")
			vis.play_attack(&"cast_b", _dur, aim)
			e.telegraph.modulate = Color(1.0, 1.0, 1.0, 0.6)
			e.telegraph.show_cone(e.position, aim.angle(), SPARK_TELE_U * U, SPARK_SPREAD * (SPARK_COUNT - 1) * 0.5 + 0.08, EnemyTelegraph.Weight.LIGHT)
			e._sfx(&"telegraph.warn_light.light", 0.0, true)


func _resolve_pour(player: Node2D, ppos: Vector2) -> void:
	_log(&"pour", &"cast_a")
	e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	var hit := false
	for i in _pour_angles.size():
		_tele(i).hide_telegraph()
		var a := _pour_angles[i]
		var d := Vector2.from_angle(a)
		var start := e.position + d * POUR_START_U * U
		var length := _pour_len(start, d)
		if is_instance_valid(_slag):
			_slag.add_pool(start, a, length, POUR_W_U * U, POOL_LIFE)
		_splash(start + d * length * 0.5, 1.2)
		LightRig.flash(start + d * length * 0.5, &"boss_lightning", 0.25, {"color": SODIUM, "energy": 0.6, "radius": 1.2})
		if not hit and player != null:
			var v := ppos - start
			var along := v.dot(d)
			if along >= -PLAYER_R and along <= length + PLAYER_R and absf(v.cross(d)) <= POUR_W_U * 0.5 * U + PLAYER_R:
				hit = true
				var dmg := e.damage * Balance.boss_attack_coef(ID, &"pour")
				e._hit_player(player, dmg)
				_burn(player, dmg)
				events.append({"kind": &"pour_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	_pool_tick = maxf(_pool_tick, POOL_TICK) # pas de double peine sur l'impact
	_pour_angles.clear()
	pace.strike(&"spell", phase)
	state = S.CHASE


## La coulée s'arrête au premier mur (pas de métal dans les murs).
func _pour_len(start: Vector2, d: Vector2) -> float:
	if e.nav == null:
		return POUR_LEN_U * U
	var step := 0.5 * U
	var l := step
	while l <= POUR_LEN_U * U:
		var p := start + d * l
		if e.nav.resolve(p, 8.0).distance_to(p) > 4.0:
			return maxf(l - step, 2.0 * U)
		l += step
	return POUR_LEN_U * U


func _resolve_sparks() -> void:
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	_log(&"sparks", &"cast_b")
	e._sfx(&"enemy.shot.medium", 2.0, true)
	var dmg := e.damage * Balance.boss_attack_coef(ID, &"sparks")
	for i in SPARK_COUNT:
		var a := aim.angle() + (i - (SPARK_COUNT - 1) * 0.5) * SPARK_SPREAD
		var d := Vector2.from_angle(a)
		if e.director != null and e.director.has_method(&"fire_projectile"):
			e.director.fire_projectile(e, e.position + d * e.radius_px, d * SPARK_SPEED_U * U, dmg)
	LightRig.flash(e.global_position + aim * e.radius_px, &"boss_lightning", 0.15, {"color": SODIUM, "energy": 0.5, "radius": 0.8})
	pace.strike(&"spell", phase)
	state = S.CHASE


# --- Métal au sol --------------------------------------------------------------------

func _update_metal(delta: float, player: Node2D, ppos: Vector2) -> void:
	_pool_tick -= delta
	if _pool_tick > 0.0 or player == null or not is_instance_valid(_slag) or state == S.STAGGER:
		return
	if _slag.in_metal(ppos):
		_pool_tick = POOL_TICK
		var dmg := e.damage * Balance.boss_attack_coef(ID, &"pool")
		e._hit_player(player, dmg)
		_burn(player, dmg)
		events.append({"kind": &"pool", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})


# --- Débordement (phase 2+) ------------------------------------------------------------

func _update_overflow(delta: float) -> void:
	if phase < 2:
		return
	if _overflow_t < 0.0:
		if state == S.STAGGER:
			return
		_overflow_cd -= delta
		if _overflow_cd <= 0.0:
			_overflow_warn()
		return
	_overflow_t += delta
	if is_instance_valid(_warn_ring):
		_warn_ring.progress = _overflow_t / OVERFLOW_WARN
		_warn_ring.queue_redraw()
	if _overflow_t >= OVERFLOW_WARN:
		_overflow_t = -1.0
		_overflow_cd = OVERFLOW_EVERY[phase - 1]
		if is_instance_valid(_warn_ring):
			_warn_ring.queue_free()
		_warn_ring = null
		if is_instance_valid(_slag):
			_slag.add_ring(_overflow_c, RING_R_U * U, RING_BAND_U * U, _overflow_gaps, GAP_HALF, OVERFLOW_LIFE)
		e._sfx(&"enemy.shockwave.heavy", 1.0, true)
		LightRig.flash(_overflow_c, &"boss_lightning", 0.35, {"color": SODIUM, "radius": 2.2})
		events.append({"kind": &"overflow", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})


## Alerte d'anneau (bande rouge interrompue aux brèches) ; une brèche côté joueur, l'autre à l'opposé ±.
func _overflow_warn() -> void:
	_overflow_t = 0.0
	_overflow_c = e.position
	var g1 := (_ppos - e.position).angle() + _rng.randf_range(-1.2, 1.2)
	_overflow_gaps = [g1, g1 + PI + _rng.randf_range(-0.7, 0.7)]
	_warn_ring = SmelterFx.make(SmelterFx.Kind.RING, SODIUM, 0)
	_warn_ring.name = &"Smelter_ring_warn"
	_warn_ring.tele = true
	_warn_ring.size = RING_R_U * U
	_warn_ring.width = RING_BAND_U * U
	_warn_ring.gaps = _overflow_gaps
	_warn_ring.gap_half = GAP_HALF
	RecluseFx.add_to_tele_layer(_warn_ring, e.get_parent())
	_warn_ring.global_position = _overflow_c
	_body_tilt = 1.0
	e._sfx(&"telegraph.boss.heavy", 0.0, true)
	events.append({"kind": &"overflow_warn", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})



# --- Trempe (phase 3, surprise) ---------------------------------------------------------

func _update_quench(delta: float, player: Node2D, ppos: Vector2) -> void:
	if phase < 3:
		return
	if _quench_t < 0.0:
		if state == S.STAGGER:
			return
		_quench_cd -= delta
		if _quench_cd <= 0.0:
			if not is_instance_valid(_slag) or _slag.metal_count() == 0:
				_quench_cd = 1.0 # pas de métal : l'orage attend
				return
			_quench_warn()
		return
	_quench_t += delta
	var k := clampf(_quench_t / QUENCH_WARN, 0.0, 1.0)
	var blink := 1.0 if fmod(_quench_t, 0.18) < 0.09 else 0.35
	if is_instance_valid(_slag):
		_slag.electrify(k * blink)
		for i in mini(_slag.pools.size(), QUENCH_TELES):
			_tele(4 + i).set_progress(k)
	_tele(4 + QUENCH_TELES).set_progress(k)
	if _quench_t >= QUENCH_WARN:
		_quench_fire(player, ppos)


func _quench_warn() -> void:
	_quench_t = 0.0
	# l'éclair vise la flaque la plus récente (sinon l'anneau)
	if not _slag.pools.is_empty():
		var q: Dictionary = _slag.pools[_slag.pools.size() - 1]
		_quench_pos = (q["a"] as Vector2) + Vector2.from_angle(float(q["ang"])) * float(q["len"]) * 0.5
	else:
		var r: Dictionary = _slag.rings[0]
		_quench_pos = (r["c"] as Vector2) + Vector2.from_angle(float(r["gaps"][0]) + PI * 0.5) * float(r["r"])
	for i in mini(_slag.pools.size(), QUENCH_TELES):
		var q: Dictionary = _slag.pools[i]
		_tele(4 + i).show_line(q["a"], float(q["ang"]), float(q["len"]), float(q["w"]))
	_tele(4 + QUENCH_TELES).show_circle(_quench_pos, 1.5 * U)
	e._sfx(&"telegraph.warn_heavy.heavy", 2.0, true)
	events.append({"kind": &"quench_warn", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0, "metal": _slag.metal_count()})


func _quench_fire(player: Node2D, ppos: Vector2) -> void:
	_quench_t = -1.0
	_quench_cd = QUENCH_EVERY - QUENCH_WARN
	quenches += 1
	for i in QUENCH_TELES + 1:
		if _teles.size() > 4 + i and is_instance_valid(_teles[4 + i]):
			_teles[4 + i].hide_telegraph()
	SonneurBrain.strike_fx(e.get_parent(), _storm_frames, _quench_pos, _fx)
	e._sfx(&"amb.thunder_close", 2.0, true)
	var hit := false
	if player != null and is_instance_valid(_slag):
		hit = _slag.in_metal(ppos) or ppos.distance_to(_quench_pos) <= 1.5 * U + PLAYER_R
	if hit:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"quench"))
	var n := 0
	if is_instance_valid(_slag):
		_slag.electrify(0.0)
		n = _slag.quench(e.get_parent(), _fx).size()
	e._sfx(&"enemy.shockwave.heavy", 0.0, true) # sifflement de la trempe
	_pool_tick = POOL_TICK
	events.append({"kind": &"quench", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0, "hit": hit, "puffs": n})


# --- Vapeur (phase 3) ---------------------------------------------------------------

func _build_steam() -> void:
	if not _jets.is_empty():
		return
	for j in STEAM_JETS:
		var tele := _tele(4 + QUENCH_TELES + 1 + j)
		tele.show_line(e.position, 0.0, STEAM_LEN_U * U, STEAM_W_U * U)
		tele.set_progress(1.0)
		tele.modulate = Color(1.0, 1.0, 1.0, STEAM_ALPHA)
		var puffs: Array = []
		if _storm_frames != null and _storm_frames.has_animation(&"steam_vent"):
			for k in 4:
				var p := AnimatedSprite2D.new()
				p.name = &"Smelter_steam"
				EmissiveOverlay.apply(p, _storm_frames, 1.0)
				p.animation = &"steam_vent"
				p.scale = Vector2(3.4, 2.6) * (64.0 / 48.301887) * Iso.UNSQUASH
				p.offset = Vector2(0.0, -32.0)
				e.get_parent().add_child(p)
				p.play(&"steam_vent")
				p.frame = (j * 3 + k) % 8
				puffs.append(p)
		else:
			var f := RecluseFx.make(RecluseFx.Kind.BEAM, Color(0.88, 0.88, 0.92, 0.35), 0)
			f.name = &"Smelter_steam"
			f.radius = STEAM_LEN_U * U
			f.width = STEAM_W_U * U * 0.8
			f.color2 = Color(1, 1, 1, 0.7)
			RecluseFx.add_to_tele_layer(f, e.get_parent())
			puffs.append(f)
		_jets.append({"tele": tele, "puffs": puffs})
	_place_jets()


func _place_jets() -> void:
	for j in _jets.size():
		var a := _steam_angle + TAU * j / float(STEAM_JETS)
		var tele := _jets[j]["tele"] as EnemyTelegraph
		if is_instance_valid(tele):
			tele.global_position = e.position
			tele.rotation = a
		var puffs: Array = _jets[j]["puffs"]
		for k in puffs.size():
			var p := puffs[k] as Node2D
			if not is_instance_valid(p):
				continue
			if p is RecluseFx:
				p.global_position = e.position
				p.rotation = a
			else:
				p.global_position = e.position + Vector2.from_angle(a) * (1.8 + 1.6 * k) * U


func _update_steam(delta: float, player: Node2D, ppos: Vector2) -> void:
	if _jets.is_empty():
		return
	_steam_angle = wrapf(_steam_angle + STEAM_TURN * delta, 0.0, TAU)
	_place_jets()
	_steam_tick -= delta
	if _steam_tick > 0.0 or player == null or state == S.STAGGER:
		return
	var v := ppos - e.position
	for j in STEAM_JETS:
		var d := Vector2.from_angle(_steam_angle + TAU * j / float(STEAM_JETS))
		var along := v.dot(d)
		if along >= 0.0 and along <= STEAM_LEN_U * U + PLAYER_R and absf(v.cross(d)) <= STEAM_W_U * 0.5 * U + PLAYER_R:
			_steam_tick = STEAM_TICK
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"steam"))
			events.append({"kind": &"steam", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			return


# --- Silhouette provisoire, effets ---------------------------------------------------------

func _build_body() -> void:
	_body = SmelterFx.make(SmelterFx.Kind.BODY, IRON, 0)
	_body.name = &"Smelter_body"
	e.add_child(_body)
	vis.self_modulate = Color(1, 1, 1, 0)


func _update_body() -> void:
	if _body == null:
		return
	var fl := 1.0 if e.is_flashing() else 0.0
	var tilt := 0.0
	if state == S.POUR:
		tilt = clampf(_t / maxf(_dur, 0.01), 0.0, 1.0)
	elif _body_tilt > 0.0:
		_body_tilt = maxf(_body_tilt - 0.03, 0.0)
		tilt = _body_tilt
	var heat := 1.0 if phase >= 3 else 0.0
	if _quench_t >= 0.0:
		heat = 1.0 if fmod(_quench_t, 0.18) < 0.09 else 0.4
	if absf(fl - _body.progress) > 0.01 or absf(tilt - _body.tilt) > 0.02 or absf(heat - _body.heat) > 0.01:
		_body.progress = fl
		_body.tilt = tilt
		_body.heat = heat
		_body.queue_redraw()
	_body.position = vis.position


## Gerbe de métal (impact de louche ou de coulée).
func _splash(p: Vector2, r_u: float) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"splash"):
		var s := AnimatedSprite2D.new()
		s.name = &"Smelter_splash"
		EmissiveOverlay.apply(s, _frames, 2.2)
		s.animation = &"splash"
		s.scale = Vector2.ONE * r_u * Iso.UNSQUASH * 0.5
		s.offset = Vector2(0.0, -96.0)
		s.play(&"splash")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.RING, Color(SODIUM.r, SODIUM.g, SODIUM.b, 0.85), 0)
		f.name = &"Smelter_splash"
		f.width = 0.25 * U
		f.radius = r_u * U
		f.color2 = Color(1.0, 0.95, 0.8, 0.9)
		n = f
	e.get_parent().add_child(n)
	n.position = p
	_fx.append({"node": n, "life": 0.45, "max": 0.45})


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

## Télégraphes annexes : 0-3 coulées ; 4..4+QUENCH_TELES trempe ; au-delà : jets de vapeur.
func _tele(i: int) -> EnemyTelegraph:
	while _teles.size() <= i:
		var t := EnemyTelegraph.new()
		e.get_parent().add_child(t)
		_teles.append(t)
	var tele := _teles[i]
	tele.modulate = Color.WHITE
	return tele


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
