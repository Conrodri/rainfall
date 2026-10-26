class_name CrystalMotherBrain
extends RefCounted
## IA de la Mère-Cristal (boss d'étage 4, Cryptes noyées ; docs/Design_Etages.md §5.4). Créée par
## Enemy.activate_boss quand le skin du boss est « crystal_mother », appelée par Enemy.tick (branche
## BOSS_TIER). Même contrat que RecluseBrain : coups télégraphiés face au joueur, dégâts à la frame d'impact
## (EnemyVisual.play_attack), coefficients Balance.BOSS_ATTACK_COEF[&"crystal_mother"], seuils 70 / 35 %.
## Sans sprites (lot Codex C8c, art/tools/night/requests_bosses4.md) : silhouette et effets provisoires
## (RecluseFx) ; chaque extra du .tres (crystal_block, stalactite, shard, prism_beam, orbit_shard, lamp_glow,
## reflect_burst) remplace son repli dès qu'il est livré.
##
## Amas de cristal de sel de 3,4 u à silhouette féminine, 6 bras-stalactites, cœur blanc-cyan #BFF4FF.
## - Phase 1 « Croissance » : éclat (auto : projectile de cristal, arrêté par les blocs et les murs) ;
##   Stalactites (spell_a : 6 cercles de 1,5 u, 1,2 s ; chacun laisse un BLOC de cristal de 1 u, 6 s, qui
##   arrête les projectiles ennemis : un abri) ; Prisme (spell_b : ligne 1,5 × 16 u, 1 s, coef 2 ; si la
##   ligne croise un bloc, elle s'y arrête et se DIVISE en 2 lignes à ±30° : l'abri devient un piège).
## - Phase 2 « Lampes » (70 %) : la Mère boit la lumière des cristaux de l'arène (RecluseGloom à 55 %) et
##   ses blocs deviennent des LAMPES (seules vraies lumières) : tout monstre dans une lampe subit +15 %,
##   la Mère comprise (l'attirer dans sa propre lumière). SURPRISE « Reflet » : elle se fond dans le sol et
##   ressort d'un bloc proche du joueur (cercle 2 u, télégraphe 1 s, coef 1,5) ; le bloc vole en éclats.
## - Phase 3 « Éclatement » (35 %) : le corps s'éclate (facettes écartées), 8 éclats en orbite (anneau
##   rouge continu, 0,5 par contact), prisme en croix (4 lignes, chacune réfractée par les blocs), éclat en
##   éventail de 3. Arène encore plus sombre (40 %).
## Trace après la mort (phase 2+) : les blocs restent, allumés, jusqu'à la fin de la charge du gros pilier.

enum S { CHASE, SHARD, STALACTITES, PRISM, REFLECT, STAGGER }
enum Spell { STALACTITES, PRISM }

const ID := &"crystal_mother"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const CRYSTAL := Color(0.749, 0.957, 1.0) ## #BFF4FF, accent unique du biome
const SALT := Color(0.60, 0.66, 0.70) ## silhouette provisoire : cristal de sel laiteux (lisible de nuit)
const BLOCK_TINT := Color(0.66, 0.78, 0.84)
## Par phase (index phase - 1)
const SPEED_MULT := [0.9, 1.0, 1.1]
const AUTO_CD := [1.8, 1.6, 1.5]
const SPELL_CD := [4.4, 4.0, 3.6] ## stalactites et prisme alternés
const KEEP_U := 6.0 ## distance de lancer (elle ne colle pas le joueur)
const LIGHT_ENERGY := [3.0, 3.8, 4.6]
const LIGHT_RADIUS := [1.2, 1.35, 1.5]
const LIGHT_LIFT_U := 1.8
const FEET_ENERGY := [2.2, 2.6, 3.0]
const BODY_GAIN := Color(1.2, 1.24, 1.3)
const GLOOM_K := [1.0, 0.55, 0.4] ## cristaux de l'arène (lumières de la carte) bus par la Mère
## Armements et récupérations : BossPace (Balance.BOSS_PACE_*) ; éclat = auto, stalactites = spell,
## prisme (rayon de 16 u, coef 2) = heavy, reflet (plongée puis sortie d'un bloc) = charge.
# Éclat (auto)
const SHARD_SPEED_U := 9.0
const SHARD_RANGE_U := 12.0
const SHARD_R_U := 0.5 ## projectile de 1 u
const SHARD_FAN := 0.21 ## P3 : éventail de 3 à ±12°
# Stalactites (spell_a)
const STAL_WINDUP := 1.2 ## plancher de l'armement (spell : max(table, 1,2 s))
const STAL_COUNT := 6
const STAL_R_U := 1.5
const STAL_RING_U := 3.4 ## les 5 autres sur un anneau autour du joueur (cercles disjoints)
const BLOCK_R_U := 0.5 ## bloc de 1 u
const BLOCK_LIFE := [6.0, 8.0, 8.0]
const BLOCK_MAX := 14
const BLOCK_H_U := 1.3
# Prisme (spell_b)
const PRISM_WINDUP := 1.0 ## plancher de l'armement (heavy : max(table, 1 s))
const PRISM_LEN_U := 16.0
const PRISM_W_U := 1.5
const PRISM_SPLIT := 0.5236 ## 30°
const PRISM_SHOW_S := 0.35
# Lampes (P2+)
const LAMP_R_U := 2.2
const LAMP_MOD_ID := &"crystal_lamp" ## Enemy.add_damage_taken_mod
const LAMP_SCAN_S := 0.15 ## relevé des monstres éclairés
const LAMP_MOD_S := 0.3 ## durée du +15 % posé à chaque relevé (traîne courte hors de la lumière)
# Reflet (P2+)
const REFLECT_EVERY := [0.0, 9.0, 7.0]
const REFLECT_WINDUP := 1.0 ## plancher de l'armement (charge : max(table, 1 s))
const REFLECT_R_U := 2.0
const REFLECT_REACH_U := 9.0 ## bloc choisi à moins de 9 u du joueur
# Orbite (P3)
const ORBIT_N := 8
const ORBIT_R_U := 2.6
const ORBIT_TURN := 1.2 ## rad/s
const ORBIT_HIT_U := 0.45
const ORBIT_TICK := 0.6

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = [] ## journal des coups (tests) : kind, phase, anim, frame, expect, lag
var pace: BossPace ## armement planté, impact, récupération immobile (BossPace)
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var _emerged := false ## reflet : sortie du bloc faite, récupération au pas suivant (téléport en étape ACTIVE)
var lamp_bonus := 0 ## monstres passés sous une lampe (+15 % posé ; tests)

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.4
var _spell_cd := 2.2
var _reflect_cd := 0.0
var _cycle := 0
var _stal_hit := false
var _lamp_scan := 0.0
var _orbit_angle := 0.0
var _orbit_tick := 0.0
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _feet: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = []
var _stals: Array[Vector2] = []
var _prism: Array[Dictionary] = [] ## segments armés {from, angle, len}
var _blocks: Array[Dictionary] = [] ## {pos, life, node, crystal, lamp, light}
var _shards: Array[Dictionary] = [] ## {pos, vel, life, node}
var _orbit: Array[Node2D] = []
var _orbit_ring: RecluseFx = null
var _reflect_block: Dictionary = {}
var _fx: Array[Dictionary] = [] ## {node, life, max}
var _body: RecluseFx = null
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


## Libère tout (mort, retour au pool). Mort en phase 2+ pendant la charge : les blocs restent allumés
## (trace confiée à RecluseGloom, libérée avec elle).
func clear() -> void:
	if pace != null:
		pace.cancel()
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	var keep_trace := killed and is_instance_valid(_gloom)
	for b in _blocks:
		_unblock_nav(b) # la trace (lampes allumées) n'est plus un obstacle
		var n := b["node"] as Node
		if not is_instance_valid(n):
			continue
		if keep_trace:
			_set_lamp(b, true)
			_gloom.keep(n)
		else:
			n.queue_free()
	_blocks.clear()
	if is_instance_valid(_gloom):
		if killed:
			_gloom.on_boss_dead()
		else:
			_gloom.release()
	_gloom = null
	for s in _shards:
		if is_instance_valid(s["node"]):
			(s["node"] as Node).queue_free()
	_shards.clear()
	for o in _orbit:
		if is_instance_valid(o):
			o.queue_free()
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


## Transition, reflet, armement et récupération : la Mère se déplace (ou reste plantée) seule.
func owns_motion() -> bool:
	return state == S.STAGGER or state == S.REFLECT or pace.planted()


## Super-armure le temps d'un coup (BossPace) : un recul ferait glisser la Mère plantée.
func ignores_knockback() -> bool:
	return pace.planted()


## Dégâts reçus : phase (Balance) × lampe (+15 % si la Mère se tient dans une de ses lampes).
func damage_taken_mult() -> float:
	var m := Balance.boss_damage_taken_mult(ID, phase)
	if phase >= 2 and in_lamp(e.position):
		m *= Balance.CRYSTAL_LAMP_DAMAGE_TAKEN
	return m


func block_count() -> int:
	return _blocks.size()


func orbit_count() -> int:
	return _orbit.size()


func gloom() -> RecluseGloom:
	return _gloom if is_instance_valid(_gloom) else null


## Vrai si `p` est dans la lumière d'une lampe (bloc en phase 2+).
func in_lamp(p: Vector2) -> bool:
	for b in _blocks:
		if b["lamp"] and p.distance_to(b["pos"]) <= LAMP_R_U * U:
			return true
	return false


## Pose un bloc (tests, stalactites).
func add_block(p: Vector2) -> void:
	_add_block(p)


## Un pas d'IA. Retourne la vitesse de marche voulue (px/s logiques), appliquée par Enemy.
func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase:
		_enter_phase(ph)
	_update_blocks(delta)
	if phase >= 2:
		_lamp_scan -= delta
		if _lamp_scan <= 0.0:
			_lamp_scan = LAMP_SCAN_S
			refresh_lamp_mods()
	_update_shards(delta, player, ppos)
	_update_orbit(delta, player, ppos)
	_update_fx(delta)
	_update_body(delta)
	_attack_cd -= delta
	_spell_cd -= delta
	_reflect_cd -= delta
	_t += delta
	var pi := phase - 1
	match state:
		S.STAGGER:
			if _t >= _dur:
				state = S.CHASE
				if phase >= 3:
					_build_orbit()
			return Vector2.ZERO
		S.SHARD:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_release_shard()
			return Vector2.ZERO
		S.STALACTITES:
			for i in _stals.size():
				_tele(i).set_progress(_t / _dur)
			if _t >= _dur:
				_drop_stalactites(player, ppos)
			return Vector2.ZERO
		S.PRISM:
			for i in _prism.size():
				_tele(STAL_COUNT + i).set_progress(_t / _dur)
			if _t >= _dur:
				_fire_prism(player, ppos)
			return Vector2.ZERO
		S.REFLECT:
			if _emerged: # sortie du bloc faite au pas précédent : arrêt net, récupération immobile
				_emerged = false
				pace.recover_for(BossPace.recover_s(&"charge", phase))
				state = S.CHASE
				return Vector2.ZERO
			_tele(STAL_COUNT + 12).set_progress(_t / _dur)
			vis.modulate.a = clampf(1.0 - _t / 0.35, 0.15, 1.0) # se fond dans le sol
			if is_instance_valid(_body):
				_body.modulate.a = vis.modulate.a
			var bn := _reflect_block.get("crystal") as CanvasItem
			if is_instance_valid(bn): # le bloc choisi palpite (blanchit) : lisible
				bn.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(1.3, 1.3, 1.3, 1.0), 0.5 + 0.5 * sin(_t * 22.0))
			if _t >= _dur:
				_emerge(player, ppos)
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering(): # récupération immobile : fenêtre de punition, aucun nouveau coup
		_face(dir)
		return Vector2.ZERO
	if vis.is_attacking():
		_face(dir)
		return Vector2.ZERO
	if phase >= 2 and _reflect_cd <= 0.0 and dist < 16.0 * U and _start_reflect(ppos):
		return Vector2.ZERO
	if _spell_cd <= 0.0 and dist < 14.0 * U:
		_start_spell(dir, ppos)
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < SHARD_RANGE_U * U:
		_start_shard(dir)
		return Vector2.ZERO
	if dist > KEEP_U * U:
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
	_reflect_cd = _dur + 2.5
	_cycle = 0
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.6, {"color": CRYSTAL, "radius": 1.6})
	_burst_fx(e.position, 1.2, 0.9)
	if ph >= 2:
		if _gloom == null:
			_gloom = RecluseGloom.create_with(e, {"dim_k": GLOOM_K[1], "name": "CrystalMother_gloom"})
		elif ph >= 3:
			_gloom.set_area(Vector2.ZERO, 0.0, GLOOM_K[2])
		for b in _blocks: # les blocs deviennent des lampes
			_set_lamp(b, true)
		e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	if ph >= 3:
		for i in 6: # éclatement : gerbe de facettes
			_burst_fx(e.position + Vector2.from_angle(TAU * i / 6.0) * 1.4 * U, 0.6, 0.7)
	_apply_phase_look()
	events.append({"kind": &"phase", "phase": ph})


func _cancel() -> void:
	pace.cancel()
	_emerged = false
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	for t in _teles:
		if is_instance_valid(t):
			t.hide_telegraph()
	_stals.clear()
	_prism.clear()
	_end_reflect_look()


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.1 if phase >= 3 else -1.0, 2.2)
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])
	if _body != null:
		_body.glow = 0.6 + 0.2 * phase
		_body.inner = 1.0 if phase >= 3 else 0.0
		_body.queue_redraw()


# --- Éclat (auto) -------------------------------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func _start_shard(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.SHARD
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color(1, 1, 1, 0.8)
	e.telegraph.show_line(e.position, aim.angle(), 8.0 * U, SHARD_R_U * 2.0 * U)
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _release_shard() -> void:
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	e._sfx(&"enemy.shot.medium", 0.0, true)
	var angles: Array[float] = [0.0]
	if phase >= 3:
		angles.assign([-SHARD_FAN, 0.0, SHARD_FAN])
	for da in angles:
		var d := aim.rotated(da)
		_spawn_shard(e.position + d * 0.8 * U, d)
	_log(&"shard", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


func _spawn_shard(p: Vector2, d: Vector2) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"shard"):
		var s := _sprite(&"shard", Vector2.ONE, Vector2.ZERO, 10, 2.4)
		s.play(&"shard")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.BEAM, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.9), 10)
		f.radius = 0.9 * U
		f.width = 0.3 * U
		f.color2 = Color(1, 1, 1, 1)
		f.position = Vector2.ZERO
		n = f
	n.name = &"CrystalMother_shard"
	e.get_parent().add_child(n)
	n.position = p
	n.rotation = d.angle()
	_shards.append({"pos": p, "vel": d * SHARD_SPEED_U * U, "life": SHARD_RANGE_U / SHARD_SPEED_U, "node": n})


func _update_shards(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := _shards.size() - 1
	while i >= 0:
		var s: Dictionary = _shards[i]
		s["life"] = float(s["life"]) - delta
		var p: Vector2 = (s["pos"] as Vector2) + (s["vel"] as Vector2) * delta
		s["pos"] = p
		var n := s["node"] as Node2D
		if is_instance_valid(n):
			n.position = p - (s["vel"] as Vector2).normalized() * 0.45 * U
		var gone := float(s["life"]) <= 0.0
		if not gone and player != null and p.distance_to(ppos) <= SHARD_R_U * 0.5 * U + PLAYER_R:
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"shard"))
			events.append({"kind": &"shard_hit", "phase": phase})
			gone = true
		if not gone and _block_at(p, SHARD_R_U * 0.5 * U) >= 0: # le bloc réfracte : l'éclat s'y brise
			events.append({"kind": &"shard_blocked", "phase": phase})
			_burst_fx(p, 0.35, 0.3)
			gone = true
		if not gone and e.nav != null and e.nav.is_blocked_at(p):
			gone = true
		if gone:
			if is_instance_valid(n):
				n.queue_free()
			_shards.remove_at(i)
		i -= 1


# --- Sorts -------------------------------------------------------------------------

func _start_spell(dir: Vector2, ppos: Vector2) -> void:
	var sp: int = Spell.STALACTITES if _cycle % 2 == 0 else Spell.PRISM
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	_t = 0.0
	match sp:
		Spell.STALACTITES:
			state = S.STALACTITES
			_dur = BossPace.windup(&"spell", phase, STAL_WINDUP)
			pace.wind(&"spell")
			vis.play_attack(&"cast_a", _dur, Vector2.ZERO)
			_place_stalactites(ppos)
		Spell.PRISM:
			state = S.PRISM
			_dur = BossPace.windup(&"heavy", phase, PRISM_WINDUP)
			pace.wind(&"heavy")
			vis.play_attack(&"cast_b", _dur, aim)
			_arm_prism(aim)
	e._sfx(&"telegraph.boss.heavy", 0.0, true)


# --- Stalactites -----------------------------------------------------------------------

## 6 cercles : le premier sur le joueur, les 5 autres sur un anneau de 3,4 u autour de lui (disjoints).
func _place_stalactites(ppos: Vector2) -> void:
	_stal_hit = false
	_stals.clear()
	var a0 := _rng.randf() * TAU
	_stals.append(_walkable(ppos))
	var min_d := 2.0 * STAL_R_U * U + 4.0
	var k := 0
	while _stals.size() < STAL_COUNT and k < 30: # anneau, puis plus loin si un mur repousse un cercle
		var ring := STAL_RING_U + 0.8 * float(k / (STAL_COUNT - 1)) * 0.5
		var p := _walkable(ppos + Vector2.from_angle(a0 + TAU * k / float(STAL_COUNT - 1) + 0.31 * float(k / (STAL_COUNT - 1))) * ring * U)
		k += 1
		var ok := true
		for q in _stals:
			if q.distance_to(p) < min_d:
				ok = false
				break
		if ok:
			_stals.append(p)
	for i in _stals.size():
		var t := _tele(i)
		t.show_circle(_stals[i], STAL_R_U * U)
		t.set_progress(0.0)


func _drop_stalactites(player: Node2D, ppos: Vector2) -> void:
	_log(&"stalactites", &"cast_a")
	e._sfx(&"enemy.shockwave.heavy", 1.0, true)
	for i in _stals.size():
		var p := _stals[i]
		_tele(i).hide_telegraph()
		_fall_fx(p)
		if not _stal_hit and player != null and p.distance_to(ppos) <= STAL_R_U * U + PLAYER_R:
			_stal_hit = true # un lancer ne touche qu'une fois
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"stalactites"))
			events.append({"kind": &"stal_hit", "phase": phase})
		_add_block(p)
	LightRig.flash(ppos, &"boss_lightning", 0.25, {"color": CRYSTAL, "energy": 0.7, "radius": 1.2})
	_stals.clear()
	pace.strike(&"spell", phase)
	state = S.CHASE


## Chute d'une stalactite : stalactite du .tres, sinon colonne de cristal qui s'abat.
func _fall_fx(p: Vector2) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"stalactite"):
		var s := _sprite(&"stalactite", Iso.UNSQUASH * Iso.SPRITE_K, Vector2(0.0, -192.0), 1, 2.4)
		s.play(&"stalactite")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.STREAK, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.9), 1)
		f.radius = -Iso.lift_logical(4.0)
		f.width = 0.35 * U
		f.color2 = Color(1, 1, 1, 1)
		n = f
	n.name = &"CrystalMother_fall"
	e.get_parent().add_child(n)
	n.position = p
	_fx.append({"node": n, "life": 0.4, "max": 0.4})
	_burst_fx(p, 0.7, 0.45)


# --- Blocs / lampes ---------------------------------------------------------------------

func _add_block(p: Vector2) -> void:
	var j := _block_at(p, BLOCK_R_U * U)
	if j >= 0: # même place : le bloc est ravivé
		_blocks[j]["life"] = BLOCK_LIFE[phase - 1]
		return
	if _blocks.size() >= BLOCK_MAX:
		_remove_block(0, false)
	var root := Node2D.new()
	root.name = &"CrystalMother_block"
	var c: Node2D
	if _frames != null and _frames.has_animation(&"crystal_block"):
		var s := _sprite(&"crystal_block", Iso.UNSQUASH * Iso.SPRITE_K, Vector2(0.0, -96.0), 0, 2.0)
		s.play(&"crystal_block")
		c = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.CRYSTAL, BLOCK_TINT, 0)
		f.radius = -Iso.lift_logical(BLOCK_H_U)
		f.width = 2.0 * BLOCK_R_U * U
		f.color2 = CRYSTAL
		f.glow = 0.5
		c = f
	root.add_child(c)
	e.get_parent().add_child(root)
	root.position = p
	var b := {"pos": p, "life": BLOCK_LIFE[phase - 1], "node": root, "crystal": c, "lamp": false, "light": null, "nav_id": 0}
	_blocks.append(b)
	if e.nav != null and e.nav.add_circle_obstacle(root.get_instance_id(), p, BLOCK_R_U * U, true):
		b["nav_id"] = root.get_instance_id() # bloc = obstacle des monstres (la Mère, grosse, les enjambe)
	if phase >= 2:
		_set_lamp(b, true)
	events.append({"kind": &"block", "phase": phase})


## Bloc -> lampe : vraie lumière de cristal + halo au sol (zone où les monstres subissent +15 %).
func _set_lamp(b: Dictionary, on: bool) -> void:
	if not on or b["lamp"]:
		return
	b["lamp"] = true
	var root := b["node"] as Node2D
	if not is_instance_valid(root):
		return
	b["light"] = LightRig.attach(root, &"crystal_vein", {"color": CRYSTAL, "energy": 1.4, "radius": 0.85, "offset": Vector2(0.0, Iso.lift_logical(0.8))})
	var g: Node2D
	if _frames != null and _frames.has_animation(&"lamp_glow"):
		var s := _sprite(&"lamp_glow", Vector2.ONE * (LAMP_R_U * U / 128.0), Vector2.ZERO, -2, 1.6)
		s.play(&"lamp_glow")
		g = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.DISC, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.10), -2)
		f.radius = LAMP_R_U * U
		f.color2 = Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.45)
		f.width = 3.0
		g = f
	g.name = &"CrystalMother_lamp"
	root.add_child(g)
	var c := b["crystal"] as Node2D
	if c is RecluseFx:
		(c as RecluseFx).glow = 1.0
		c.queue_redraw()
	events.append({"kind": &"lamp", "phase": phase})


func _update_blocks(delta: float) -> void:
	var i := _blocks.size() - 1
	while i >= 0:
		var b: Dictionary = _blocks[i]
		if not is_same(b, _reflect_block):
			b["life"] = float(b["life"]) - delta
		var c := b["crystal"] as CanvasItem
		if is_instance_valid(c) and not is_same(b, _reflect_block):
			c.modulate.a = clampf(float(b["life"]) / 0.6, 0.0, 1.0)
		if float(b["life"]) <= 0.0:
			_remove_block(i, false)
		i -= 1
	if _blocks.is_empty():
		return
	# réfraction : les blocs arrêtent les projectiles ennemis (API publique du pool)
	var pool := e.director.get_node_or_null(^"EnemyProjectiles") as EnemyProjectilePool if e.director != null else null
	if pool == null or pool.active_count() == 0:
		return
	for b in _blocks:
		for k in pool.kill_in_circle(b["pos"], BLOCK_R_U * U):
			events.append({"kind": &"projectile_blocked", "phase": phase})


func _remove_block(i: int, shatter: bool) -> void:
	var b: Dictionary = _blocks[i]
	_unblock_nav(b)
	if shatter:
		_burst_fx(b["pos"], 0.9, 0.6)
	if is_instance_valid(b["node"]):
		(b["node"] as Node).queue_free()
	_blocks.remove_at(i)


## Index du bloc qui touche un disque (centre p, rayon r), -1 sinon.
func _block_at(p: Vector2, r: float) -> int:
	for i in _blocks.size():
		if p.distance_to(_blocks[i]["pos"]) <= BLOCK_R_U * U + r:
			return i
	return -1


func _unblock_nav(b: Dictionary) -> void:
	if int(b.get("nav_id", 0)) != 0 and e != null and e.nav != null:
		e.nav.remove_obstacle(int(b["nav_id"]))
	b["nav_id"] = 0


## Lampes (phase 2+) : tout monstre (hors la Mère) dans la lumière d'une lampe subit +15 % : multiplicateur
## Enemy.add_damage_taken_mod(LAMP_MOD_ID, CRYSTAL_LAMP_DAMAGE_TAKEN, LAMP_MOD_S), reposé tous les
## LAMP_SCAN_S (tick) ; la Mère passe par damage_taken_mult. Public (tests). Retourne le nombre éclairé.
func refresh_lamp_mods() -> int:
	if phase < 2 or e == null or not e.is_inside_tree():
		return 0
	var lamps: Array[Vector2] = []
	for b in _blocks:
		if b["lamp"]:
			lamps.append(b["pos"])
	if lamps.is_empty():
		return 0
	var r2 := LAMP_R_U * U * LAMP_R_U * U
	var n := 0
	for node in e.get_tree().get_nodes_in_group(&"enemies"):
		if node == e or not (node is Enemy) or not (node as Enemy).active:
			continue
		var en := node as Enemy
		for lp in lamps:
			if en.position.distance_squared_to(lp) <= r2:
				if not en.has_damage_taken_mod(LAMP_MOD_ID):
					lamp_bonus += 1
				en.add_damage_taken_mod(LAMP_MOD_ID, Balance.CRYSTAL_LAMP_DAMAGE_TAKEN, LAMP_MOD_S)
				n += 1
				break
	return n


# --- Prisme ---------------------------------------------------------------------------

## Segments d'un rayon : tout droit sur PRISM_LEN_U, sauf s'il croise un bloc : il s'y arrête et repart en
## 2 lignes à ±30° depuis le bloc (longueur restante).
func _prism_paths(origin: Vector2, angle: float) -> Array[Dictionary]:
	var d := Vector2.from_angle(angle)
	var best := -1
	var best_along := PRISM_LEN_U * U
	for i in _blocks.size():
		var v: Vector2 = (_blocks[i]["pos"] as Vector2) - origin
		var along := v.dot(d)
		if along <= BLOCK_R_U * U or along >= best_along:
			continue
		if absf(v.cross(d)) <= PRISM_W_U * 0.5 * U + BLOCK_R_U * U * 0.5:
			best = i
			best_along = along
	var out: Array[Dictionary] = []
	if best < 0:
		out.append({"from": origin, "angle": angle, "len": PRISM_LEN_U * U, "split": false})
		return out
	var bp: Vector2 = _blocks[best]["pos"]
	var rest := PRISM_LEN_U * U - best_along
	out.append({"from": origin, "angle": angle, "len": best_along, "split": false})
	out.append({"from": bp, "angle": angle + PRISM_SPLIT, "len": rest, "split": true})
	out.append({"from": bp, "angle": angle - PRISM_SPLIT, "len": rest, "split": true})
	return out


func _arm_prism(dir: Vector2) -> void:
	_prism.clear()
	var arms := 4 if phase >= 3 else 1 # P3 : prisme en croix
	for k in arms:
		_prism.append_array(_prism_paths(e.position, dir.angle() + TAU * k / float(arms)))
	for i in _prism.size():
		var sg: Dictionary = _prism[i]
		var t := _tele(STAL_COUNT + i)
		t.show_line(sg["from"], sg["angle"], sg["len"], PRISM_W_U * U)
		t.set_progress(0.0)


func _fire_prism(player: Node2D, ppos: Vector2) -> void:
	_log(&"prism", &"cast_b")
	e._sfx(&"enemy.shockwave.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.35, {"color": CRYSTAL, "radius": 1.8})
	var hit := false
	var split := false
	for i in _prism.size():
		var sg: Dictionary = _prism[i]
		_tele(STAL_COUNT + i).hide_telegraph()
		_beam_fx(sg["from"], sg["angle"], sg["len"])
		if sg["split"]:
			split = true
		if hit or player == null:
			continue
		var v := ppos - (sg["from"] as Vector2)
		var d := Vector2.from_angle(sg["angle"])
		var along := v.dot(d)
		if along >= -PLAYER_R and along <= float(sg["len"]) + PLAYER_R and absf(v.cross(d)) <= PRISM_W_U * 0.5 * U + PLAYER_R:
			hit = true
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"prism"))
			events.append({"kind": &"prism_hit", "phase": phase, "split": sg["split"]})
	if split:
		events.append({"kind": &"prism_split", "phase": phase})
	if _prism.size() >= 4 and phase >= 3:
		events.append({"kind": &"prism_cross", "phase": phase})
	_prism.clear()
	pace.strike(&"heavy", phase)
	state = S.CHASE


func _beam_fx(from: Vector2, angle: float, length: float) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"prism_beam"):
		var s := _sprite(&"prism_beam", Vector2(length / 1024.0, 1.0), Vector2(512.0, 0.0), 0, 2.8)
		s.play(&"prism_beam")
		e.get_parent().add_child(s)
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.BEAM, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.55), 0)
		f.radius = length
		f.width = PRISM_W_U * U * 0.8
		f.color2 = Color(1, 1, 1, 0.95)
		RecluseFx.add_to_tele_layer(f, e.get_parent())
		n = f
	n.name = &"CrystalMother_prism"
	n.global_position = from
	n.rotation = angle
	_fx.append({"node": n, "life": PRISM_SHOW_S, "max": PRISM_SHOW_S})


# --- Reflet (P2+) ---------------------------------------------------------------------

## Choisit le bloc le plus proche du joueur (à moins de REFLECT_REACH_U, jamais sous ses pieds à moins de
## 1 u) ; faux si aucun.
func _start_reflect(ppos: Vector2) -> bool:
	var best := -1
	var bd := REFLECT_REACH_U * U
	for i in _blocks.size():
		var d := ppos.distance_to(_blocks[i]["pos"])
		if d < bd and d > 1.0 * U:
			best = i
			bd = d
	_reflect_cd = REFLECT_EVERY[phase - 1]
	if best < 0:
		_reflect_cd = 2.0
		return false
	_reflect_block = _blocks[best]
	var wind := BossPace.windup(&"charge", phase, REFLECT_WINDUP)
	_reflect_block["life"] = maxf(float(_reflect_block["life"]), wind + 0.5)
	state = S.REFLECT
	_t = 0.0
	_dur = wind
	_emerged = false
	pace.wind(&"charge")
	aim = ((_reflect_block["pos"] as Vector2) - e.position).normalized()
	var t := _tele(STAL_COUNT + 12)
	t.show_circle(_reflect_block["pos"], REFLECT_R_U * U)
	t.set_progress(0.0)
	e._sfx(&"telegraph.warn_heavy.heavy", 0.0, true)
	_burst_fx(e.position, 0.8, 0.5)
	events.append({"kind": &"reflect_warn", "phase": phase})
	return true


func _emerge(player: Node2D, ppos: Vector2) -> void:
	_tele(STAL_COUNT + 12).hide_telegraph()
	var bp: Vector2 = _reflect_block.get("pos", e.position)
	var j := _blocks.find(_reflect_block)
	if j >= 0:
		_remove_block(j, true)
	_reflect_block = {}
	pace.act() # téléport : seul déplacement du reflet (étape ACTIVE), récupération au pas suivant
	pace.impact(&"charge")
	e.position = bp
	_end_reflect_look()
	e._sfx(&"enemy.shockwave.heavy", 3.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.5, {"color": CRYSTAL, "radius": 1.8})
	var n: Node2D = null
	if _frames != null and _frames.has_animation(&"reflect_burst"):
		var s := _sprite(&"reflect_burst", Iso.UNSQUASH * Iso.SPRITE_K * REFLECT_R_U, Vector2(0.0, -192.0), 1, 2.8)
		s.play(&"reflect_burst")
		e.get_parent().add_child(s)
		s.position = bp
		s.name = &"CrystalMother_reflect"
		_fx.append({"node": s, "life": 0.6, "max": 0.6})
	else:
		_burst_fx(bp, REFLECT_R_U * 0.8, 0.7)
	var v := ppos - bp
	aim = v.normalized() if v.length_squared() > 1.0 else aim
	_face(aim)
	if player != null and v.length() <= REFLECT_R_U * U + PLAYER_R:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"reflect"))
		events.append({"kind": &"reflect_hit", "phase": phase})
	events.append({"kind": &"reflect", "phase": phase, "to_block": true})
	_attack_cd = maxf(_attack_cd, 0.5)
	_emerged = true # reste en S.REFLECT un pas : la récupération commence au pas suivant (BossPace)


func _end_reflect_look() -> void:
	if vis != null and is_instance_valid(vis):
		vis.modulate.a = 1.0
	if is_instance_valid(_body):
		_body.modulate.a = 1.0


# --- Orbite (P3) ------------------------------------------------------------------------

func _build_orbit() -> void:
	if not _orbit.is_empty():
		return
	for k in ORBIT_N:
		var n: Node2D
		if _frames != null and _frames.has_animation(&"orbit_shard"):
			var s := _sprite(&"orbit_shard", Iso.UNSQUASH * Iso.SPRITE_K, Vector2(0.0, -48.0), 1, 2.4)
			s.play(&"orbit_shard")
			s.frame = k % maxi(_frames.get_frame_count(&"orbit_shard"), 1)
			n = s
		else:
			var f := RecluseFx.make(RecluseFx.Kind.CRYSTAL, BLOCK_TINT.lightened(0.1), 1)
			f.radius = -Iso.lift_logical(0.9)
			f.width = 0.42 * U
			f.color2 = CRYSTAL
			f.glow = 1.0
			n = f
		n.name = &"CrystalMother_orbit"
		e.get_parent().add_child(n)
		_orbit.append(n)
	# télégraphe continu : bande rouge de l'orbite (couche des télégraphes)
	_orbit_ring = RecluseFx.make(RecluseFx.Kind.RING_TELE, Color.RED, 0)
	_orbit_ring.name = &"CrystalMother_orbit_ring"
	_orbit_ring.inner = (ORBIT_R_U - ORBIT_HIT_U) * U
	_orbit_ring.radius = (ORBIT_R_U + ORBIT_HIT_U) * U
	_orbit_ring.modulate = Color(1, 1, 1, 0.55)
	RecluseFx.add_to_tele_layer(_orbit_ring, e.get_parent())
	events.append({"kind": &"orbit", "phase": phase})


func _update_orbit(delta: float, player: Node2D, ppos: Vector2) -> void:
	if _orbit.is_empty():
		return
	_orbit_angle = wrapf(_orbit_angle + ORBIT_TURN * delta, 0.0, TAU)
	var hit := false
	for k in _orbit.size():
		var p := e.position + Vector2.from_angle(_orbit_angle + TAU * k / float(ORBIT_N)) * ORBIT_R_U * U
		if is_instance_valid(_orbit[k]):
			_orbit[k].position = p
		if player != null and p.distance_to(ppos) <= ORBIT_HIT_U * U + PLAYER_R:
			hit = true
	if is_instance_valid(_orbit_ring):
		_orbit_ring.global_position = e.position
		_orbit_ring.visible = state != S.REFLECT
	_orbit_tick -= delta
	if hit and _orbit_tick <= 0.0 and state != S.STAGGER and state != S.REFLECT:
		_orbit_tick = ORBIT_TICK
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"orbit"))
		events.append({"kind": &"orbit_hit", "phase": phase})


# --- Silhouette provisoire -------------------------------------------------------------

func _build_body() -> void:
	_body = RecluseFx.make(RecluseFx.Kind.BODY_MOTHER, SALT, 0)
	_body.name = &"CrystalMother_body"
	_body.color2 = CRYSTAL
	e.add_child(_body)
	vis.self_modulate = Color(1, 1, 1, 0) # hexagone de repli masqué (la silhouette le remplace)


func _update_body(_delta: float) -> void:
	if _body == null:
		return
	var fl := 1.0 if e.is_flashing() else 0.0
	if absf(fl - _body.progress) > 0.01:
		_body.progress = fl
		_body.queue_redraw()
	_body.position = vis.position


## Éclat de cristal au sol : colonne de lumière dessinée (provisoire) ou reflect_burst du .tres.
func _burst_fx(pos: Vector2, r_u: float, life: float) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"reflect_burst"):
		var s := _sprite(&"reflect_burst", Iso.UNSQUASH * Iso.SPRITE_K * r_u, Vector2(0.0, -192.0), 0, 2.4)
		s.play(&"reflect_burst")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.COLUMN, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.7), 0)
		f.radius = -Iso.lift_logical(2.0 * r_u)
		f.width = 1.2 * r_u * U
		f.color2 = Color(1, 1, 1, 0.95)
		n = f
	n.name = &"CrystalMother_burst"
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


# --- Outils ------------------------------------------------------------------------

func _sprite(anim: StringName, sc: Vector2, off: Vector2, z: int, energy: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = StringName("CrystalMother_" + String(anim))
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
