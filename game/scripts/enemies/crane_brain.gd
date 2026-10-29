class_name CraneBrain
extends RefCounted
## IA de la Grue (boss d'étage 3, Cité de rouille ; docs/Design_Etages.md §5.3). Créée par Enemy.activate_boss
## quand le skin du boss est « crane », appelée par Enemy.tick (branche BOSS_TIER). Même contrat que
## SonneurBrain / RecluseBrain : coups télégraphiés face au joueur (le sprite prend la plus proche de ses
## 4 orientations e/s/w/n : auto/spell_a/spell_b_<dir>), dégâts à la frame d'impact (EnemyVisual.play_attack
## cale l'impact sur la fin du télégraphe). Dégâts : Balance.BOSS_ATTACK_COEF[&"crane"].
## Sans sprites (lot Codex à venir, art/tools/night/requests_bosses3.md#grue) : silhouette et effets dessinés
## provisoires (CraneFx) ; chaque extra du .tres (container, boom_shadow, arc, dust) remplace son repli.
##
## Automate-grue de 3,8 u sur chenilles, flèche articulée, crochet ; rouille et acier, lampe au sodium #FF9A3C.
## Phases (PV, Enemy.boss_phase ; seuils Balance.BOSS_PHASE_THRESHOLDS : 70 / 35 %) :
## - Phase 1 « Chantier » : crochet (auto, ligne 1 × 6 u) ; Lâcher de conteneur (spell_a : cercle de 3 u sur
##   le joueur, 1,2 s, coef 1,8 ; le conteneur tombe du ciel et RESTE 8 s comme obstacle de 2 u qui bloque le
##   joueur) ; Balayage de flèche (spell_b : ligne 1,5 × 14 u qui tourne de 90° en 1,5 s, télégraphe continu ;
##   un conteneur entre la Grue et le joueur l'ABRITE : la flèche cogne la tôle).
## - Phase 2 « Double levée » : 2 conteneurs à la fois (le second là où le joueur va), balayage plus rapide.
## - Phase 3 « Paratonnerre » : la Grue s'ancre (patins, immobile), dresse sa flèche et lâche un conteneur
##   en spirale toutes les 2,5 s. SURPRISE : la flèche dressée attire la foudre de l'orage (comme le Sonneur) :
##   toutes les 6 s, les conteneurs proches se relient par des arcs (télégraphe 1,2 s), puis l'éclair frappe
##   la flèche et les arcs claquent : les abris des phases 1-2 deviennent une cage électrique à lire.
## Trace (mort pendant la charge du gros pilier) : les conteneurs restent jusqu'à la fin de la charge (CraneYard).

enum S { CHASE, HOOK, DROP, SWEEP_WIND, SWEEP, STAGGER }
enum Spell { DROP, SWEEP }

const ID := &"crane"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const SODIUM := Color(1.0, 0.604, 0.235) ## #FF9A3C, accent unique de la Cité
const RUST := Color(0.66, 0.40, 0.27) ## silhouette provisoire : rouille claire (lisible de nuit)
## Par phase (index phase - 1)
const SPEED_MULT := [1.0, 1.08, 0.0] ## P3 : ancrée
const AUTO_CD := [2.0, 1.8, 1.7]
const SPELL_CD := [4.4, 4.0, 3.6] ## lâcher et balayage alternés (P3 : balayage seul, la spirale lâche seule)
const LIGHT_ENERGY := [3.0, 3.4, 4.2]
const LIGHT_RADIUS := [1.3, 1.4, 1.55]
const LIGHT_LIFT_U := 2.2
const FEET_ENERGY := [2.0, 2.3, 2.8]
const BODY_GAIN := Color(1.6, 1.55, 1.5) ## albédo relevé de nuit si sprite livré (leçon du Sonneur)
const ROD_ENERGY := [0.0, 0.0, 2.4]
# Crochet (auto)
const HOOK_LEN_U := 6.0
const HOOK_W_U := 1.0
## Armements et récupérations : BossPace (Balance.BOSS_PACE_*) ; crochet = auto, lâcher et balayage = spell.
# Lâcher de conteneur (spell_a)
const DROP_WINDUP := 1.2 ## plancher du lâcher (spell : max(table, 1,2 s)) et durée des chutes en spirale (P3)
const DROP_R_U := 1.5 ## cercle de 3 u
const DROP_FALL_S := 0.45
const DROP_FALL_H_U := 9.0
const DROP_LEAD_S := 1.0 ## P2 : second conteneur là où le joueur sera
const DROP_GAP_U := 0.6
# Balayage de flèche (spell_b)
const SWEEP_WINDUP := 1.0 ## plancher de l'armement du balayage (spell)
const SWEEP_LEN_U := 14.0
const SWEEP_W_U := 1.5
const SWEEP_ARC := PI * 0.5
const SWEEP_S := [1.5, 1.3, 1.25]
const SWEEP_CONE_ALPHA := 0.25 ## quart de 14 u : alerte discrète (captures : le cône rouge plein masquait les conteneurs)
# Phase 3
const SPIRAL_EVERY := 2.5
const SPIRAL_R0_U := 3.0
const SPIRAL_STEP_U := 0.9
const SPIRAL_SPAN_U := 6.5
const SPIRAL_GOLDEN := 2.39996
const ARC_EVERY := 6.0
const ARC_FIRST_S := 3.0
const ARC_WARN := 1.2
const ARC_RANGE_U := 7.0
const ARC_W_U := 0.8
const ARC_MAX := 6
const ARC_SHOW_S := 0.35

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = [] ## journal des coups (tests) : kind, phase, anim, frame, expect, lag
var pace: BossPace ## armement planté, impact, récupération immobile (BossPace)
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var anchored := false
var shielded := 0 ## balayages arrêtés par un conteneur (tests)
var arcs_fired := 0

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.4
var _spell_cd := 2.4
var _cycle := 0
var _sweep_a0 := 0.0
var _sweep_s := 1.0
var _sweep_hit := false
var _sweep_clang := false
var _spiral_cd := 0.0
var _spiral_k := 0
var _arc_cd := 0.0
var _arc_t := -1.0 ## >= 0 : arcs en alerte
var _arc_fired := false
var _arc_links: Array = [] ## [[a, b], ...]
var _arc_nodes: Array[Node2D] = []
var _flash := 0.0
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _storm_frames: SpriteFrames = null ## foudre partagée avec le Sonneur (même orage)
var _feet: LightRig.Handle = null
var _rod: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = []
var _tele_next := 0
var _drops: Array[Dictionary] = [] ## {pts, t, dur, teles, falls, shadows, anim}
var _fx: Array[Dictionary] = [] ## {node, life, max}
var _boom: Node2D = null ## ombre de la flèche pendant le balayage
var _body: CraneFx = null ## silhouette provisoire (sans sprite)
var _yard: CraneYard = null


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
	_rod = LightRig.attach(e, &"boss_sonneur_rod", {"offset": Vector2(0.0, Iso.lift_logical(4.6)), "color": SODIUM})
	if vis.body_sprite() != null:
		vis.body_sprite().self_modulate = BODY_GAIN
	else:
		_build_body()
	if e.get_parent() != null:
		_yard = CraneYard.create(e.get_parent(), _frames)
		_yard.nav = e.nav # conteneurs = obstacles dynamiques (monstres et Grue les contournent)
	_apply_phase_look()


## Libère télégraphes, chutes, arcs, silhouette (mort, retour au pool). Mort pendant la charge du gros
## pilier : les conteneurs restent (CraneYard.keep_until_charge).
func clear() -> void:
	if pace != null:
		pace.cancel()
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	if is_instance_valid(_yard):
		if killed:
			_yard.keep_until_charge()
		else:
			_yard.release()
	_yard = null
	for d in _drops:
		_free_drop(d)
	_drops.clear()
	_clear_arcs()
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	if is_instance_valid(_boom):
		_boom.queue_free()
	_boom = null
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
	if _rod != null:
		_rod.release()
	_rod = null
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


## Transition de phase, armement, balayage, récupération et phase 3 (patins d'ancrage) : planté (ni marche ni séparation de foule).
func owns_motion() -> bool:
	return state == S.STAGGER or pace.planted() or anchored


## Super-armure le temps d'un coup (BossPace) ou en phase 3 (patins d'ancrage plantés) : un recul ferait glisser la Grue.
func ignores_knockback() -> bool:
	return pace.planted() or anchored


func damage_taken_mult() -> float:
	return Balance.boss_damage_taken_mult(ID, phase)


func yard() -> CraneYard:
	return _yard if is_instance_valid(_yard) else null


func container_count() -> int:
	return _yard.count() if is_instance_valid(_yard) else 0


func drop_count() -> int:
	return _drops.size()


func arc_count() -> int:
	return _arc_links.size()


func sweep_angle() -> float:
	return _sweep_a0 + _sweep_s * SWEEP_ARC * clampf(_t / _dur, 0.0, 1.0) if state == S.SWEEP else _sweep_a0


## Un pas d'IA. Retourne la vitesse de marche voulue (px/s logiques), appliquée par Enemy.
func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase:
		_enter_phase(ph)
	if not pace.planted(): # planté pendant un coup : dégagé d'un conteneur seulement après
		_unstick()
	_update_drops(delta, player, ppos)
	_update_arcs(delta, player, ppos)
	_update_fx(delta)
	_update_body(delta)
	_attack_cd -= delta
	_spell_cd -= delta
	_t += delta
	var pi := phase - 1
	if phase >= 3 and state != S.STAGGER:
		_spiral_cd -= delta
		if _spiral_cd <= 0.0:
			_spiral_cd = SPIRAL_EVERY
			_spiral_drop(ppos)
	match state:
		S.STAGGER:
			if _t >= _dur:
				state = S.CHASE
			return Vector2.ZERO
		S.HOOK:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_hook(player, ppos)
			return Vector2.ZERO
		S.DROP:
			if _t >= _dur: # le conteneur tombe (_update_drops) : impact puis récupération immobile
				pace.strike(&"spell", phase)
				state = S.CHASE
			return Vector2.ZERO
		S.SWEEP_WIND:
			e.telegraph.global_position = e.position
			var lt := _tele(0)
			lt.global_position = e.position
			lt.set_progress(_t / _dur)
			if _t >= _dur:
				_begin_sweep()
			return Vector2.ZERO
		S.SWEEP:
			_sweep_step(player, ppos)
			if _t >= _dur:
				_end_sweep()
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering(): # récupération immobile : fenêtre de punition, aucun nouveau coup
		_face(dir)
		return Vector2.ZERO
	if vis.is_attacking():
		_face(dir)
		return Vector2.ZERO
	if _spell_cd <= 0.0 and dist < (SWEEP_LEN_U - 1.0) * U:
		_start_spell(dir, ppos, player)
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < (HOOK_LEN_U - 0.5) * U:
		_start_hook(dir)
		return Vector2.ZERO
	if SPEED_MULT[pi] > 0.0 and dist > HOOK_LEN_U * U * 0.6:
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
	_dur = 8.0 / ANIM_FPS + 0.2 # trans_pN : 8 frames
	_spell_cd = maxf(_spell_cd, _dur + 1.0)
	_attack_cd = maxf(_attack_cd, _dur + 0.4)
	_cycle = 0
	if ph >= 3:
		anchored = true
		e.visual.set_action(&"idle") # plus de marche : le tick de l'ennemi ne la remettra pas (owns_motion)
		_spiral_cd = _dur + 0.6
		_arc_cd = _dur + ARC_FIRST_S
		e._sfx(&"enemy.shockwave.heavy", 2.0, true) # patins plantés dans le béton
	_apply_phase_look()
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.5, {"color": SODIUM, "radius": 1.6})
	events.append({"kind": &"phase", "phase": ph})


## Coup en cours annulé (changement de phase) ; les conteneurs déjà télégraphiés tombent quand même.
func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	if _teles.size() > 0 and is_instance_valid(_teles[0]):
		_teles[0].hide_telegraph()
	if is_instance_valid(_boom):
		_boom.queue_free()
	_boom = null


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.2 if phase >= 3 else -1.0, 9.0)
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])
	if _rod != null:
		_rod.set_enabled(phase >= 3)
		_rod.set_energy(ROD_ENERGY[pi])
		_rod.set_flicker_override(0.45, 11.0)
	if _body != null:
		_body.anchored = anchored
		_body.queue_redraw()


# --- Crochet (auto) ------------------------------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func _start_hook(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.HOOK
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_line(e.position, aim.angle(), HOOK_LEN_U * U, HOOK_W_U * U, EnemyTelegraph.Weight.LIGHT)
	if _body != null:
		_body.boom_angle = aim.angle()
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _resolve_hook(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.brute_cone.heavy")
	if player != null and _in_line(ppos, e.position, aim, HOOK_LEN_U * U, HOOK_W_U * U):
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"hook"))
	_log(&"hook", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


func _in_line(p: Vector2, from: Vector2, d: Vector2, length: float, w: float) -> bool:
	var v := p - from
	var along := v.dot(d)
	return along >= 0.0 and along <= length + PLAYER_R and absf(v.cross(d)) <= w * 0.5 + PLAYER_R


# --- Sorts -------------------------------------------------------------------------

func _start_spell(dir: Vector2, ppos: Vector2, player: Node2D) -> void:
	var sp: int = Spell.SWEEP if phase >= 3 or _cycle % 2 == 1 else Spell.DROP
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	_t = 0.0
	match sp:
		Spell.DROP:
			state = S.DROP
			_dur = BossPace.windup(&"spell", phase, DROP_WINDUP)
			pace.wind(&"spell")
			vis.play_attack(&"cast_a", _dur, Vector2.ZERO) # la flèche pivote, le crochet lâche
			var pts: Array[Vector2] = [_walkable(ppos)]
			if phase >= 2:
				pts.append(_lead_point(ppos, player, pts[0]))
			_add_drop(pts, true, _dur)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)
		Spell.SWEEP:
			state = S.SWEEP_WIND
			_dur = BossPace.windup(&"spell", phase, SWEEP_WINDUP)
			pace.wind(&"spell")
			_sweep_s = 1.0 if _rng.randf() < 0.5 else -1.0
			_sweep_a0 = aim.angle() - _sweep_s * SWEEP_ARC * 0.5 # le joueur est au milieu du quart balayé
			_sweep_hit = false
			_sweep_clang = false
			vis.play_attack(&"cast_b", _dur, Vector2.ZERO)
			e.telegraph.show_cone(e.position, aim.angle(), SWEEP_LEN_U * U, SWEEP_ARC * 0.5)
			e.telegraph.modulate = Color(1.0, 1.0, 1.0, SWEEP_CONE_ALPHA)
			var lt := _tele(0)
			lt.show_line(e.position, _sweep_a0, SWEEP_LEN_U * U, SWEEP_W_U * U)
			if _body != null:
				_body.boom_angle = _sweep_a0
			e._sfx(&"telegraph.boss.heavy", 0.0, true)


## Second conteneur de la phase 2 : là où le joueur va (vitesse × DROP_LEAD_S), sinon à côté ; jamais
## superposé au premier.
func _lead_point(ppos: Vector2, player: Node2D, first: Vector2) -> Vector2:
	var v: Vector2 = player.get(&"velocity") if player != null and player.get(&"velocity") is Vector2 else Vector2.ZERO
	var off := v * DROP_LEAD_S
	var min_d := (2.0 * DROP_R_U + DROP_GAP_U) * U
	if off.length() < min_d:
		off = (off.normalized() if off.length() > 1.0 else Vector2.from_angle(_rng.randf() * TAU)) * min_d
	off = off.limit_length(5.0 * U)
	var p := _walkable(ppos + off)
	if p.distance_to(first) < min_d:
		p = _walkable(first + (p - first).normalized() * min_d) if p != first else _walkable(first + Vector2.RIGHT * min_d)
	return p


# --- Conteneurs ----------------------------------------------------------------------

func _add_drop(pts: Array[Vector2], anim: bool, dur := DROP_WINDUP) -> void:
	var teles: Array = []
	var falls: Array = []
	var shadows: Array = []
	for p in pts:
		var tl := _tele_any()
		tl.show_circle(p, DROP_R_U * U)
		teles.append(tl)
		var sh := CraneFx.make(CraneFx.Kind.SHADOW, Color.BLACK, -1)
		sh.name = &"Crane_shadow"
		sh.size = CraneYard.HALF_U * U
		e.get_parent().add_child(sh)
		sh.position = p
		shadows.append(sh)
		var fall: Node2D
		if _frames != null and _frames.has_animation(&"container"):
			var s := _sprite(&"container", Vector2.ONE * Iso.SPRITE_K * Iso.UNSQUASH, Vector2(0.0, -96.0), 2, 1.6)
			fall = s
		else:
			var f := CraneFx.make(CraneFx.Kind.CONTAINER, RUST.darkened(0.1), 2)
			f.size = CraneYard.HALF_U * U
			fall = f
		fall.name = &"Crane_fall"
		fall.visible = false
		e.get_parent().add_child(fall)
		fall.position = p
		falls.append(fall)
	_drops.append({"pts": pts, "t": 0.0, "dur": dur, "teles": teles, "falls": falls, "shadows": shadows, "anim": anim})


func _update_drops(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := _drops.size() - 1
	while i >= 0:
		var d: Dictionary = _drops[i]
		d["t"] = float(d["t"]) + delta
		var dur := float(d["dur"])
		var k := clampf(float(d["t"]) / dur, 0.0, 1.0)
		var fall := clampf((float(d["t"]) - (dur - DROP_FALL_S)) / DROP_FALL_S, 0.0, 1.0)
		for tl in d["teles"]:
			if is_instance_valid(tl):
				(tl as EnemyTelegraph).set_progress(k)
		for sh in d["shadows"]:
			if is_instance_valid(sh):
				(sh as CraneFx).progress = k
				(sh as CraneFx).queue_redraw()
		for f in d["falls"]:
			if is_instance_valid(f):
				var n := f as Node2D
				n.visible = fall > 0.0
				var h := Iso.lift_logical(DROP_FALL_H_U * (1.0 - fall * fall))
				if n is CraneFx:
					(n as CraneFx).lift = h
					n.queue_redraw()
				elif n is AnimatedSprite2D:
					(n as AnimatedSprite2D).offset = Vector2(0.0, -96.0 + h / n.scale.y)
		if k >= 1.0:
			_resolve_drop(d, player, ppos)
			_free_drop(d)
			_drops.remove_at(i)
		i -= 1


## Impact : dégâts dans le cercle (un seul coup par lâcher), conteneur posé (obstacle), joueur poussé
## hors de la tôle s'il était dessous.
func _resolve_drop(d: Dictionary, player: Node2D, ppos: Vector2) -> void:
	if bool(d["anim"]):
		_log(&"drop", &"cast_a")
	else:
		events.append({"kind": &"spiral", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	var hit := false
	for p: Vector2 in d["pts"]:
		var rot := (_rng.randf() - 0.5) * 0.3
		if is_instance_valid(_yard):
			_yard.drop(p, rot)
		_dust(p)
		LightRig.flash(p, &"boss_lightning", 0.2, {"color": SODIUM, "energy": 0.5, "radius": 0.6})
		if not hit and player != null and p.distance_to(ppos) <= DROP_R_U * U + PLAYER_R:
			hit = true
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"container"))
			events.append({"kind": &"container_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	if player != null and is_instance_valid(_yard):
		var c := _yard.inside(player.global_position, PLAYER_R * 0.5)
		if not c.is_empty():
			# éjecté hors du conteneur tombé sur lui : déplacement balayé qui traverse ce seul conteneur (il est DANS
			# le corps), jamais un mur ni un autre conteneur
			var out := _yard.push_out(c, player.global_position, PLAYER_R + 4.0) - player.global_position
			if player.has_method(&"move_swept"):
				player.move_swept(out, [c["body"]])
			else:
				player.global_position = _walkable(player.global_position + out)


func _free_drop(d: Dictionary) -> void:
	for tl in d["teles"]:
		if is_instance_valid(tl):
			(tl as EnemyTelegraph).hide_telegraph()
	for f in d["falls"]:
		if is_instance_valid(f):
			(f as Node).queue_free()
	for sh in d["shadows"]:
		if is_instance_valid(sh):
			(sh as Node).queue_free()


## Phase 3 : un conteneur en spirale autour de la Grue ancrée ; un sur trois sur le joueur.
func _spiral_drop(ppos: Vector2) -> void:
	_spiral_k += 1
	var p: Vector2
	if _spiral_k % 3 == 0:
		p = ppos
	else:
		var r := SPIRAL_R0_U + fmod(_spiral_k * SPIRAL_STEP_U, SPIRAL_SPAN_U)
		p = e.position + Vector2.from_angle(_spiral_k * SPIRAL_GOLDEN) * r * U
	var pts: Array[Vector2] = [_walkable(p)]
	_add_drop(pts, false)
	e._sfx(&"telegraph.warn_heavy.heavy", -4.0, true)


func _dust(p: Vector2) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"dust"):
		var s := _sprite(&"dust", Vector2.ONE, Vector2.ZERO, -1, 1.0)
		s.play(&"dust")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.RING, Color(0.75, 0.62, 0.5, 0.7), -1)
		f.width = 0.3 * U
		f.radius = DROP_R_U * U
		f.color2 = Color(SODIUM.r, SODIUM.g, SODIUM.b, 0.8)
		n = f
	n.name = &"Crane_dust"
	e.get_parent().add_child(n)
	n.position = p
	_fx.append({"node": n, "life": 0.5, "max": 0.5})


func _unstick() -> void:
	if not is_instance_valid(_yard):
		return
	var c := _yard.inside(e.position, e.radius_px * 0.6)
	if not c.is_empty():
		e.position = _yard.push_out(c, e.position, e.radius_px * 0.6 + 2.0)


# --- Balayage de flèche ------------------------------------------------------------------

func _begin_sweep() -> void:
	state = S.SWEEP
	_t = 0.0
	_dur = SWEEP_S[phase - 1]
	_log(&"sweep", &"cast_b")
	pace.impact(&"spell") # la flèche part : arrêt sur image ; la Grue reste plantée (WIND) pendant le balayage
	e._sfx(&"enemy.brute_cone.heavy", 2.0, true)
	if _frames != null and _frames.has_animation(&"boom_shadow"):
		var s := _sprite(&"boom_shadow", Vector2(SWEEP_LEN_U * U / 896.0, SWEEP_W_U * U / 96.0), Vector2(448.0, 0.0), -1, 1.4)
		s.play(&"boom_shadow")
		_boom = s
		e.get_parent().add_child(s)
	else:
		var f := CraneFx.make(CraneFx.Kind.BOOM, Color(0.16, 0.12, 0.10), -1)
		f.size = SWEEP_LEN_U * U
		f.width = SWEEP_W_U * U
		f.color2 = SODIUM
		RecluseFx.add_to_tele_layer(f, e.get_parent())
		_boom = f
	_boom.name = &"Crane_boom"
	_sweep_step(null, _ppos)


func _sweep_step(player: Node2D, ppos: Vector2) -> void:
	var a := sweep_angle()
	var d := Vector2.from_angle(a)
	var lt := _tele(0)
	lt.global_position = e.position
	lt.rotation = a
	lt.set_progress(1.0)
	if is_instance_valid(_boom):
		_boom.global_position = e.position
		_boom.rotation = a
	if _body != null:
		_body.boom_angle = a
	if player == null or _sweep_hit:
		return
	if _in_line(ppos, e.position, d, SWEEP_LEN_U * U, SWEEP_W_U * U):
		if is_instance_valid(_yard) and _yard.blocks_line(e.position + d * e.radius_px, ppos - d * PLAYER_R):
			if not _sweep_clang:
				_sweep_clang = true
				shielded += 1
				e._sfx(&"enemy.brute_cone.heavy", 3.0, true) # la flèche cogne la tôle
				LightRig.flash(ppos - d * 1.2 * U, &"boss_lightning", 0.15, {"color": SODIUM, "energy": 0.6, "radius": 0.5})
				events.append({"kind": &"shielded", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			return
		_sweep_hit = true
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"sweep"))
		events.append({"kind": &"sweep_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})


func _end_sweep() -> void:
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	_tele(0).hide_telegraph()
	if is_instance_valid(_boom):
		_boom.queue_free()
	_boom = null
	pace.recover_for(BossPace.recover_s(&"spell", phase)) # flèche au bout de sa course : fenêtre de punition
	state = S.CHASE


# --- Arc de tempête (phase 3) -------------------------------------------------------------

func _update_arcs(delta: float, player: Node2D, ppos: Vector2) -> void:
	if phase < 3 or state == S.STAGGER and _arc_t < 0.0:
		return
	if _arc_t < 0.0:
		_arc_cd -= delta
		if _arc_cd <= 0.0:
			_arc_warn()
		return
	_arc_t += delta
	var k := _arc_t / ARC_WARN
	if _rod != null:
		_rod.set_energy(ROD_ENERGY[2] * (1.0 + 1.5 * clampf(k, 0.0, 1.0)))
	if k < 1.0:
		for j in _arc_links.size():
			var tl := _tele(1 + j)
			tl.set_progress(k)
		var flick := 0.25 + 0.35 * (1.0 if fmod(_arc_t, 0.16) < 0.08 else 0.0)
		for n in _arc_nodes:
			if is_instance_valid(n):
				n.modulate.a = flick
		return
	if not _arc_fired: # éclair sur la flèche dressée, arcs pleins
		_arc_fired = true
		_arc_fire(player, ppos)
	if _arc_t >= ARC_WARN + ARC_SHOW_S:
		_clear_arcs()
		_arc_t = -1.0
		_arc_cd = ARC_EVERY - ARC_WARN - ARC_SHOW_S
		if _rod != null:
			_rod.set_energy(ROD_ENERGY[2])


## Alerte : chaque conteneur se relie au plus proche voisin (conteneur ou flèche) à moins de ARC_RANGE_U.
func _arc_warn() -> void:
	var nodes: Array[Vector2] = [e.position]
	if is_instance_valid(_yard):
		for c in _yard.containers:
			nodes.append(c["pos"])
	_arc_links.clear()
	var seen := {}
	for i in range(1, nodes.size()):
		var best := -1
		var bd := ARC_RANGE_U * U
		for j in nodes.size():
			if j != i and nodes[i].distance_to(nodes[j]) <= bd:
				bd = nodes[i].distance_to(nodes[j])
				best = j
		if best < 0:
			continue
		var key := "%d_%d" % [mini(i, best), maxi(i, best)]
		if seen.has(key):
			continue
		seen[key] = true
		_arc_links.append([nodes[best], nodes[i]])
		if _arc_links.size() >= ARC_MAX:
			break
	if _arc_links.is_empty():
		_arc_cd = 1.0 # aucun conducteur : on réessaie bientôt
		return
	_arc_t = 0.0
	_arc_fired = false
	for j in _arc_links.size():
		var a: Vector2 = _arc_links[j][0]
		var b: Vector2 = _arc_links[j][1]
		var tl := _tele(1 + j)
		tl.show_line(a, (b - a).angle(), a.distance_to(b), ARC_W_U * U)
		var n: Node2D
		if _frames != null and _frames.has_animation(&"arc"):
			var s := _sprite(&"arc", Vector2(a.distance_to(b) / 448.0, 1.0), Vector2(224.0, 0.0), 1, 2.6)
			s.play(&"arc")
			e.get_parent().add_child(s)
			n = s
		else:
			var f := CraneFx.make(CraneFx.Kind.ARC, SODIUM, 1)
			f.size = a.distance_to(b)
			f.width = 0.35 * U
			f.seed_i = _rng.randi()
			RecluseFx.add_to_tele_layer(f, e.get_parent())
			n = f
		n.name = &"Crane_arc"
		n.global_position = a
		n.rotation = (b - a).angle()
		n.modulate.a = 0.3
		_arc_nodes.append(n)
	e._sfx(&"telegraph.warn_heavy.heavy", 0.0, true)
	events.append({"kind": &"arc_warn", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0, "links": _arc_links.size()})


func _arc_fire(player: Node2D, ppos: Vector2) -> void:
	arcs_fired += 1
	for j in _arc_links.size():
		_tele(1 + j).hide_telegraph()
	for n in _arc_nodes:
		if is_instance_valid(n):
			n.modulate.a = 1.0
			if n is CraneFx:
				(n as CraneFx).seed_i += 1
				n.queue_redraw()
	SonneurBrain.strike_fx(e.get_parent(), _storm_frames, e.position + Vector2(0.0, -2.0), _fx)
	e._sfx(&"amb.thunder_close", 2.0, true)
	var hit := false
	if player != null:
		for l in _arc_links:
			var a: Vector2 = l[0]
			var b: Vector2 = l[1]
			if _seg_dist(ppos, a, b) <= ARC_W_U * 0.5 * U + PLAYER_R:
				hit = true
				break
	if hit:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"arc"))
	events.append({"kind": &"arc", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0, "hit": hit})


func _clear_arcs() -> void:
	for j in _arc_links.size():
		if _teles.size() > 1 + j and is_instance_valid(_teles[1 + j]):
			_teles[1 + j].hide_telegraph()
	for n in _arc_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_arc_nodes.clear()
	_arc_links.clear()


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Silhouette provisoire, effets ---------------------------------------------------------

func _build_body() -> void:
	_body = CraneFx.make(CraneFx.Kind.BODY, RUST, 0)
	_body.name = &"Crane_body"
	e.add_child(_body)
	vis.self_modulate = Color(1, 1, 1, 0) # hexagone de repli masqué (la silhouette le remplace)


func _update_body(_delta: float) -> void:
	if _body == null:
		return
	var fl := 1.0 if e.is_flashing() else 0.0
	var lift := 1.0 if state == S.HOOK else 0.0
	var lamp := 1.0
	if _arc_t >= 0.0:
		lamp = 1.0 if fmod(_arc_t, 0.16) < 0.08 else 0.3
	if absf(fl - _body.progress) > 0.01 or absf(lift - _body.lift) > 0.01 or absf(lamp - _body.lamp) > 0.01 or state in [S.SWEEP, S.SWEEP_WIND, S.HOOK]:
		_body.progress = fl
		_body.lift = lift
		_body.lamp = lamp
		_body.queue_redraw()
	if state == S.CHASE and not vis.is_attacking() and absf(angle_difference(_body.boom_angle, e._facing)) > 0.01:
		_body.boom_angle = lerp_angle(_body.boom_angle, e._facing, 0.15)
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
			if n is RecluseFx and n.name == &"Crane_dust":
				(n as RecluseFx).set_param(DROP_R_U * U * (1.0 + 0.6 * (1.0 - float(f["life"]) / float(f["max"]))))
		i -= 1


# --- Outils ------------------------------------------------------------------------

func _sprite(anim: StringName, sc: Vector2, off: Vector2, z: int, energy: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = StringName("Crane_" + String(anim))
	EmissiveOverlay.apply(s, _frames, energy)
	s.animation = anim
	s.scale = sc
	s.offset = off
	s.z_index = z
	return s


## Télégraphe annexe n° i (0 : flèche ; 1.. : arcs ; au-delà : conteneurs, en anneau).
func _tele(i: int) -> EnemyTelegraph:
	while _teles.size() <= i:
		var t := EnemyTelegraph.new()
		e.get_parent().add_child(t)
		_teles.append(t)
	var tele := _teles[i]
	tele.modulate = Color.WHITE
	return tele


## Télégraphe de conteneur : pris dans un anneau de 6 au-delà des arcs (chutes qui se chevauchent).
func _tele_any() -> EnemyTelegraph:
	_tele_next = (_tele_next + 1) % 6
	return _tele(1 + ARC_MAX + _tele_next)


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
