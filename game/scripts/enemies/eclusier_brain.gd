class_name EclusierBrain
extends RefCounted
## IA de l'Éclusier (boss d'étage 1, Terrasses noyées ; docs/Design_Boss_Cartes.md §3.1, sprites lot C7a).
## Créée par Enemy.activate_boss quand le skin du boss est « eclusier », appelée par Enemy.tick (branche BOSS_TIER).
## Même contrat que CerfBrain / RecluseBrain : coups télégraphiés face au joueur (le sprite prend la plus proche de
## ses 4 orientations : auto/spell_a/spell_b_<dir>), dégâts à la frame d'impact (EnemyVisual.play_attack cale
## l'impact sur la fin du télégraphe). Dégâts : Balance.BOSS_ATTACK_COEF[&"eclusier"]. Extras du .tres utilisés :
## wave (front de la vague), ground_wave (sillage mouillé), ground_geyser (bouillonnement pendant le télégraphe),
## geyser (jaillissement), ground_water (nappe de la phase 2), wheel (roue de vanne qui tourne, phase 3), anchored.
##
## Gardien de vanne de pierre et bronze (3,5 u), roue de vanne dans le dos, bras-portes ; accent cyan d'eau.
## Phases (PV, Balance.BOSS_PHASE_THRESHOLDS : 70 % / 35 %) ; transition = anim trans_pN (boss figé).
## - Phase 1 « Vanne fermée » : coup de vanne (auto, cône 90° de 3 u) ; Lâcher d'eau (spell_a : ligne 4 × 18 u,
##   télégraphe 1,2 s, vague à 10 u/s, pousse de 3 u en respectant les murs) ; Geysers (spell_b : 4 cercles de
##   2 u, un sur le joueur, trois à moins de 5 u, télégraphe 0,9 s).
## - Phase 2 « Montée des eaux » : la zone de charge se couvre d'eau ; 2 geysers permanents à 6 u du gros pilier
##   (jaillissent toutes les 4 s, télégraphe 0,9 s) ; Lâcher d'eau double (±30°).
## - Phase 3 « Rupture » : s'ancre (immobile jusqu'à la mort = fenêtre de DPS) ; la roue tourne : 4 bras de
##   3 × 14 u en croix toutes les 3 s (télégraphe 1 s) ; SURPRISE : la croix alterne « + » et « × » (la roue
##   s'emballe pendant le télégraphe et s'arrête sur le nouvel axe : la diagonale sûre change à chaque fois) ;
##   geysers toutes les 6 s.
## Trace après la mort : nappe et 2 geysers permanents jusqu'à la fin de la charge du gros pilier.

enum S { CHASE, GATE, WAVE_WIND, GEYSERS, STAGGER }
enum Spell { WAVE, GEYSERS }

const ID := &"eclusier"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const CYAN := Color(0.369, 0.784, 1.0) ## #5EC8FF
## Par phase (index phase - 1)
const SPEED_MULT := [1.0, 1.05, 0.0] ## P3 : ancré
const AUTO_CD := [1.8, 1.7, 1.6]
const SPELL_CD := [4.8, 4.4, 6.0] ## lâcher d'eau et geysers alternés (~9-10 s chacun) ; P3 : geysers / 6 s
## Lumière : le corps (bois noir, bronze vert-de-gris) restait sombre la nuit : albédo relevé + lumière cyan
## d'eau à mi-corps + lumière basse aux pieds (leçon du Sonneur).
const LIGHT_ENERGY := [2.6, 3.2, 3.8]
const LIGHT_RADIUS := [1.2, 1.4, 1.5]
const LIGHT_LIFT_U := 1.8
const FEET_ENERGY := [2.0, 2.6, 3.0]
const BODY_GAIN := Color(1.3, 1.34, 1.36)
# Coup de vanne (auto)
const GATE_RANGE_U := 3.0
const GATE_HALF := 0.785 ## 90°
## Rythme (BossPace, Balance.BOSS_PACE_*) : coup de vanne = &"auto" ; lâcher d'eau = &"heavy" (vague de 18 u
## qui pousse) ; geysers = &"spell". Armement planté, récupération immobile après chaque coup.
# Lâcher d'eau (spell_a)
const WAVE_TRACK := 0.5 ## part du télégraphe pendant laquelle la ligne suit le joueur
const WAVE_W_U := 4.0
const WAVE_LEN_U := 18.0
const WAVE_SPEED_U := 10.0
const WAVE_BAND_U := 1.2 ## épaisseur du front qui touche
const WAVE_SPREAD := 0.5236 ## P2+ : ±30°
const WAVE_PUSH_U := 3.0
const WAVE_PUSH_S := 0.25 ## durée de la poussée (Player.push : murs respectés)
const WAVE_SRC_W := 284.0 ## extra `wave` : front de 284 px de long × 78 px d'épaisseur dans sa cellule 128 × 576
const WAVE_SRC_T := 78.0
# Geysers (spell_b)
const GEYSER_COUNT := 4
const GEYSER_R_U := 1.0 ## cercles de 2 u
const GEYSER_SPREAD_U := 5.0
const GEYSER_GAP_U := 0.5
const GEYSER_SRC_PX := 68.0 ## largeur du geyser dans sa cellule de 128
# Phase 2 : nappe et geysers permanents
const SPRING_DIST_U := 6.0
const SPRING_EVERY := 4.0
const SPRING_WIND := 0.9
const WATER_R_U := 9.0 ## Pillar.BIG_ZONE_RADIUS
const WATER_ALPHA := 0.5
# Phase 3 : croix de la roue
const CROSS_EVERY := 3.0
const CROSS_WIND := 1.0
const CROSS_LEN_U := 14.0
const CROSS_W_U := 3.0
const CROSS_FIRST_S := 1.2
const WHEEL_LIFT_U := 3.3

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = [] ## journal des coups (tests) : kind, phase, anim, frame, expect, lag
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var cross_angle := 0.0 ## 0 = « + », PI/4 = « × »
var crosses := 0
var pushes := 0
var pace: BossPace ## armement planté, impact, récupération immobile (scripts/enemies/boss_pace.gd)

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.4
var _spell_cd := 2.2
var _cycle := 0
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _feet: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = []
var _waves: Array[Dictionary] = [] ## {origin, dir, d, front, trail, cast}
var _wave_dirs: Array[Vector2] = []
var _wave_offsets: Array = [0.0] ## décalages angulaires des lignes (P2+ : ±30°)
var _wave_cast := {} ## lancer en cours : {hit} (un même lancer ne touche qu'une fois)
var _geysers: Array[Dictionary] = [] ## {pos, tele, pre}
var _cross_t := 0.0
var _cross_shown := false
var _wheel: AnimatedSprite2D = null
var _hz: Floor1Hazards = null
var _water: Polygon2D = null
var _fx: Array[Dictionary] = []


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
	_hz = Floor1Hazards.create(e, _frames, "Eclusier")
	_apply_phase_look()


## Libère vagues, geysers, roue, télégraphes (mort, retour au pool). Mort pendant la charge : la nappe et les
## geysers permanents restent (Floor1Hazards).
func clear() -> void:
	if pace != null:
		pace.cancel()
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	if is_instance_valid(_hz):
		if killed:
			_hz.on_boss_dead()
		else:
			_hz.release()
	_hz = null
	_water = null
	for w in _waves:
		for k in ["front", "trail"]:
			if is_instance_valid(w.get(k)):
				(w[k] as Node).queue_free()
	_waves.clear()
	for g in _geysers:
		if is_instance_valid(g.get("pre")):
			(g["pre"] as Node).queue_free()
	_geysers.clear()
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	for t in _teles:
		if is_instance_valid(t):
			t.queue_free()
	_teles.clear()
	if is_instance_valid(_wheel):
		_wheel.queue_free()
	_wheel = null
	if _feet != null:
		_feet.release()
	_feet = null
	if vis != null and is_instance_valid(vis) and vis.body_sprite() != null:
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


## Super-armure le temps d'un coup : un recul ferait glisser le boss planté.
func ignores_knockback() -> bool:
	return pace.planted()


func damage_taken_mult() -> float:
	return Balance.boss_damage_taken_mult(ID, phase)


func hazards() -> Floor1Hazards:
	return _hz if is_instance_valid(_hz) else null


func wave_count() -> int:
	return _waves.size()


func geyser_count() -> int:
	return _geysers.size()


## Un pas d'IA. Retourne la vitesse de marche voulue (px/s logiques), appliquée par Enemy.
func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase:
		_enter_phase(ph)
	_update_waves(delta, player, ppos)
	_update_cross(delta, player, ppos)
	_update_fx(delta)
	_update_water(delta)
	_attack_cd -= delta
	_spell_cd -= delta
	_t += delta
	var pi := phase - 1
	match state:
		S.STAGGER:
			if _t >= _dur:
				state = S.CHASE
				if phase >= 3:
					_anchor()
			return Vector2.ZERO
		S.GATE:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_gate(player, ppos)
			return Vector2.ZERO
		S.WAVE_WIND:
			_track_wave(dir)
			if _t >= _dur:
				_release_waves()
			return Vector2.ZERO
		S.GEYSERS:
			for g in _geysers:
				(g["tele"] as EnemyTelegraph).set_progress(_t / _dur)
			if _t >= _dur:
				_burst_geysers(player, ppos)
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering() or vis.is_attacking(): # récupération immobile (fenêtre de punition), fin de fente
		_face(dir)
		return Vector2.ZERO
	if phase >= 3 and vis.body_sprite() != null and vis.current_anim() != &"anchored_s":
		vis.play_special(&"anchored")
	if _spell_cd <= 0.0 and dist < 16.0 * U:
		_start_spell(dir, ppos)
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < GATE_RANGE_U * U:
		_start_gate(dir)
		return Vector2.ZERO
	if SPEED_MULT[pi] > 0.0 and dist > GATE_RANGE_U * U * 0.75:
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
	LightRig.flash(e.global_position, &"boss_lightning", 0.6, {"color": CYAN, "radius": 1.6})
	if is_instance_valid(_hz):
		_hz.burst_fx(e.position, 1.4 * U, &"geyser", GEYSER_SRC_PX)
	if ph == 2:
		_flood()
	events.append({"kind": &"phase", "phase": ph})


func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	for t in _teles:
		if is_instance_valid(t):
			t.hide_telegraph()
	for g in _geysers:
		if is_instance_valid(g.get("pre")):
			(g["pre"] as Node).queue_free()
	_geysers.clear()
	_wave_dirs.clear()
	_cross_shown = false


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.1 if phase >= 3 else -1.0, 2.0)
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])


## Phase 3 : ancré au centre de sa position, la roue sort et tourne ; premier coup de croix après CROSS_FIRST_S.
func _anchor() -> void:
	vis.play_special(&"anchored")
	_cross_t = CROSS_EVERY - CROSS_WIND - CROSS_FIRST_S
	cross_angle = 0.0
	if _wheel == null and _frames != null and _frames.has_animation(&"wheel"):
		_wheel = Floor1Fx.sprite(_frames, &"wheel", "Eclusier_", 2.4)
		_wheel.scale = Floor1Fx.billboard(2.4 * U, 64.0)
		_wheel.position = Vector2(0.0, Iso.lift_logical(WHEEL_LIFT_U))
		e.add_child(_wheel)
		e.move_child(_wheel, 0) # derrière le corps : la roue dépasse des épaules
		_wheel.play(&"wheel")
	e._sfx(&"enemy.shockwave.heavy", 2.0, true)


# --- Coup de vanne (auto) ------------------------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func _start_gate(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.GATE
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_cone(e.position, aim.angle(), GATE_RANGE_U * U, GATE_HALF)
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _resolve_gate(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.brute_cone.heavy")
	var v := ppos - e.position
	if player != null and v.length() <= GATE_RANGE_U * U + PLAYER_R and absf(angle_difference(aim.angle(), v.angle())) <= GATE_HALF + 0.15:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"gate"))
	_log(&"gate", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


# --- Sorts -------------------------------------------------------------------------

func _start_spell(dir: Vector2, ppos: Vector2) -> void:
	var sp: int = Spell.GEYSERS if phase >= 3 or _cycle % 2 == 1 else Spell.WAVE
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	_t = 0.0
	match sp:
		Spell.WAVE:
			state = S.WAVE_WIND
			_dur = BossPace.windup(&"heavy", phase)
			pace.wind(&"heavy")
			vis.play_attack(&"cast_a", _dur, aim)
			_wave_dirs.clear()
			_wave_offsets = [0.0] if phase < 2 else [-WAVE_SPREAD, WAVE_SPREAD]
			for o in _wave_offsets:
				_wave_dirs.append(aim.rotated(o))
			_track_wave(dir, true)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)
		Spell.GEYSERS:
			state = S.GEYSERS
			_dur = BossPace.windup(&"spell", phase)
			pace.wind(&"spell")
			vis.play_attack(&"cast_b", _dur, Vector2.ZERO) # frappe le sol sur place
			_place_geysers(ppos)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)


# --- Lâcher d'eau --------------------------------------------------------------------

## La ligne suit le joueur pendant WAVE_TRACK du télégraphe, puis se fige (on lit l'axe, on s'écarte).
func _track_wave(dir: Vector2, first := false) -> void:
	if first or _t < _dur * WAVE_TRACK:
		aim = dir
		_face(aim)
		vis.set_strike_dir(aim)
		for i in _wave_dirs.size():
			_wave_dirs[i] = aim.rotated(_wave_offsets[i])
	for i in _wave_dirs.size():
		var t := _tele(i)
		if first:
			t.show_line(e.position, _wave_dirs[i].angle(), WAVE_LEN_U * U, WAVE_W_U * U)
		t.global_position = e.position
		t.rotation = _wave_dirs[i].angle()
		t.set_progress(_t / _dur)


## Frame d'impact de spell_a : la vanne s'ouvre, une vague par ligne part du boss.
func _release_waves() -> void:
	for i in _wave_dirs.size():
		_tele(i).hide_telegraph()
	_log(&"wave", &"cast_a")
	e._sfx(&"enemy.shockwave.heavy", 3.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.35, {"color": CYAN, "radius": 1.6})
	_wave_cast = {"hit": false}
	for d in _wave_dirs:
		var w := {"origin": e.position, "dir": d, "d": 0.0, "cast": _wave_cast, "front": null, "trail": null}
		if _frames != null and _frames.has_animation(&"wave"):
			var s := Floor1Fx.sprite(_frames, &"wave", "Eclusier_", 2.0)
			s.rotation = d.angle() # long axe du front perpendiculaire au trajet
			s.scale = Vector2(WAVE_BAND_U * U / WAVE_SRC_T, WAVE_W_U * U / WAVE_SRC_W)
			e.get_parent().add_child(s)
			s.play(&"wave")
			w["front"] = s
			if _frames.has_animation(&"ground_wave"):
				var tr := Floor1Fx.sprite(_frames, &"ground_wave", "Eclusier_", 1.2, -1)
				tr.rotation = d.angle() - PI * 0.5
				e.get_parent().add_child(tr)
				tr.play(&"ground_wave")
				w["trail"] = tr
		else:
			var f := RecluseFx.make(RecluseFx.Kind.WAVE, Color(CYAN.r * 0.5, CYAN.g * 0.6, CYAN.b * 0.7, 0.75), 0)
			f.radius = WAVE_W_U * 0.5 * U
			f.width = WAVE_BAND_U * U
			f.color2 = Color(0.85, 0.97, 1.0, 0.9)
			f.name = &"Eclusier_wave"
			f.rotation = d.angle()
			e.get_parent().add_child(f)
			w["front"] = f
		_waves.append(w)
		_place_wave(w)
	_wave_dirs.clear()
	pace.strike(&"heavy", phase)
	state = S.CHASE


func _place_wave(w: Dictionary) -> void:
	var o: Vector2 = w["origin"]
	var d: Vector2 = w["dir"]
	var dist := float(w["d"])
	var front := w["front"] as Node2D
	if is_instance_valid(front):
		front.global_position = o + d * dist
	var tr := w["trail"] as Node2D
	if is_instance_valid(tr):
		tr.global_position = o + d * dist * 0.5
		tr.scale = Vector2(WAVE_W_U * U / WAVE_SRC_T, maxf(dist, 1.0) / WAVE_SRC_W)


func _update_waves(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := _waves.size() - 1
	while i >= 0:
		var w: Dictionary = _waves[i]
		w["d"] = float(w["d"]) + WAVE_SPEED_U * U * delta
		var dist := float(w["d"])
		_place_wave(w)
		var k := clampf(dist / (WAVE_LEN_U * U), 0.0, 1.0)
		for key in ["front", "trail"]:
			var n := w[key] as CanvasItem
			if is_instance_valid(n):
				n.modulate.a = 1.0 - k * k * (0.6 if key == "front" else 0.9)
		var cast: Dictionary = w["cast"]
		if not cast["hit"] and player != null:
			var v: Vector2 = ppos - (w["origin"] as Vector2)
			var along := v.dot(w["dir"])
			if absf(along - dist) <= WAVE_BAND_U * 0.5 * U + PLAYER_R and absf(v.cross(w["dir"])) <= WAVE_W_U * 0.5 * U + PLAYER_R:
				cast["hit"] = true
				e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"wave"))
				if player.is_in_group(&"player") and player.has_method(&"push"):
					if player.push(w["dir"] as Vector2, WAVE_PUSH_U, WAVE_PUSH_S):
						pushes += 1
				events.append({"kind": &"wave_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
		if dist >= WAVE_LEN_U * U:
			for key in ["front", "trail"]:
				if is_instance_valid(w[key]):
					(w[key] as Node).queue_free()
			_waves.remove_at(i)
		i -= 1


# --- Geysers -------------------------------------------------------------------------

## 4 cercles de 2 u : le premier sur le joueur, trois à moins de 5 u, jamais chevauchants (écart ≥ 0,5 u).
func _place_geysers(ppos: Vector2) -> void:
	var min_d := (2.0 * GEYSER_R_U + GEYSER_GAP_U) * U
	var pts: Array[Vector2] = [_walkable(ppos)]
	var tries := 0
	while pts.size() < GEYSER_COUNT and tries < 40:
		tries += 1
		var p := ppos + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(min_d, GEYSER_SPREAD_U * U)
		p = _walkable(p)
		var ok := true
		for q in pts:
			if q.distance_to(p) < min_d:
				ok = false
				break
		if ok:
			pts.append(p)
	for k in pts.size():
		var tele := _tele(2 + k)
		tele.show_circle(pts[k], GEYSER_R_U * U)
		var pre: Node2D = null
		if _frames != null and _frames.has_animation(&"ground_geyser"):
			var s := Floor1Fx.sprite(_frames, &"ground_geyser", "Eclusier_", 1.6, -1)
			s.scale = Floor1Fx.billboard(GEYSER_R_U * 2.0 * U * 0.8, GEYSER_SRC_PX)
			s.offset = Vector2(0.0, -18.0)
			e.get_parent().add_child(s)
			s.global_position = pts[k]
			s.play(&"ground_geyser")
			pre = s
		_geysers.append({"pos": pts[k], "tele": tele, "pre": pre})


func _burst_geysers(player: Node2D, ppos: Vector2) -> void:
	_log(&"geysers", &"cast_b")
	e._sfx(&"enemy.shockwave.heavy", 2.0, true)
	var hit := false
	for g in _geysers:
		(g["tele"] as EnemyTelegraph).hide_telegraph()
		if is_instance_valid(g.get("pre")):
			(g["pre"] as Node).queue_free()
		var pos: Vector2 = g["pos"]
		if is_instance_valid(_hz):
			_hz.burst_fx(pos, GEYSER_R_U * U, &"geyser", GEYSER_SRC_PX)
		LightRig.flash(pos, &"boss_lightning", 0.18, {"color": CYAN, "energy": 0.6, "radius": 0.6})
		if not hit and player != null and pos.distance_to(ppos) <= GEYSER_R_U * U + PLAYER_R:
			hit = true # un même lancer ne touche qu'une fois
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"geyser"))
			events.append({"kind": &"geyser_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	_geysers.clear()
	pace.strike(&"spell", phase)
	state = S.CHASE


# --- Phase 2 : montée des eaux ------------------------------------------------------------

func _big_pillar() -> Pillar:
	if not e.is_inside_tree():
		return null
	var best: Pillar = null
	for p in e.get_tree().get_nodes_in_group(&"pillars"):
		if p is Pillar and (p as Pillar).kind == Pillar.Kind.BIG and (p as Pillar).state == Pillar.STATE_ACTIVE:
			if best == null or (p as Pillar).global_position.distance_to(e.position) < best.global_position.distance_to(e.position):
				best = p
	return best


## Nappe d'eau sur la zone de charge + 2 geysers permanents à 6 u du gros pilier (de part et d'autre, en travers
## de l'axe boss -> pilier pour ne jamais tomber sur le boss).
func _flood() -> void:
	if not is_instance_valid(_hz):
		return
	var pl := _big_pillar()
	var c := pl.global_position if pl != null else e.position
	var r := (pl.zone_radius() if pl != null else WATER_R_U * U)
	_water = Polygon2D.new()
	_water.name = &"Eclusier_water"
	var pts := PackedVector2Array()
	for i in 48:
		pts.append(Vector2.from_angle(TAU * i / 48.0) * r)
	_water.polygon = pts
	_water.z_index = -1
	var tex: Texture2D = _frames.get_frame_texture(&"ground_water", 0) if _frames != null and _frames.has_animation(&"ground_water") else null
	if tex is AtlasTexture:
		tex = (tex as AtlasTexture).atlas # bande entière en motif répété (4 tuiles d'eau)
	if tex != null:
		_water.texture = tex
		_water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_water.color = Color(1, 1, 1, 1)
	else:
		_water.color = Color(CYAN.r * 0.4, CYAN.g * 0.5, CYAN.b * 0.6, 1.0)
	_water.modulate.a = 0.0
	_hz.add_child(_water)
	_water.global_position = c
	_hz.add_zone({"kind": &"water", "shape": &"none", "pos": c, "node": _water, "trace": true, "alpha": WATER_ALPHA})
	var axis := (c - e.position)
	axis = axis.normalized().orthogonal() if axis.length_squared() > 1.0 else Vector2.UP
	for s in [-1.0, 1.0]:
		var p := _walkable(c + axis * s * SPRING_DIST_U * U)
		var pre: Node2D = null
		if _frames != null and _frames.has_animation(&"ground_geyser"):
			var sp := Floor1Fx.sprite(_frames, &"ground_geyser", "Eclusier_", 1.4, -1)
			sp.scale = Floor1Fx.billboard(GEYSER_R_U * 2.0 * U * 0.8, GEYSER_SRC_PX)
			sp.offset = Vector2(0.0, -18.0)
			_hz.add_child(sp)
			sp.global_position = p
			sp.play(&"ground_geyser")
			pre = sp
		else:
			var f := RecluseFx.make(RecluseFx.Kind.DISC, Color(CYAN.r, CYAN.g, CYAN.b, 0.25), -1)
			f.radius = GEYSER_R_U * U * 0.7
			f.width = 2.0
			f.name = &"Eclusier_spring"
			_hz.add_child(f)
			f.global_position = p
			pre = f
		_hz.add_zone({"kind": &"spring", "shape": &"circle", "pos": p, "r": GEYSER_R_U * U, "pulse": SPRING_EVERY,
			"wind": SPRING_WIND, "pulse_t": 1.0 if s < 0.0 else 3.0, "dmg": e.damage * Balance.boss_attack_coef(ID, &"spring"),
			"trace": true, "node": pre, "burst": &"geyser", "burst_px": GEYSER_SRC_PX})


func _update_water(delta: float) -> void:
	if not is_instance_valid(_water):
		return
	_water.modulate.a = move_toward(_water.modulate.a, WATER_ALPHA, delta * 0.6)
	_water.texture_offset += Vector2(9.0, 4.0) * delta # courant lent


# --- Phase 3 : la roue ------------------------------------------------------------------

func _update_cross(delta: float, player: Node2D, ppos: Vector2) -> void:
	if phase < 3 or state == S.STAGGER:
		return
	_cross_t += delta
	var wind_from := CROSS_EVERY - CROSS_WIND
	if is_instance_valid(_wheel):
		_wheel.speed_scale = 3.5 if _cross_t >= wind_from else 0.6 # la roue s'emballe pendant le télégraphe
	if _cross_t >= wind_from:
		if not _cross_shown:
			_cross_shown = true
			for j in 4:
				var t := _tele(8 + j)
				t.show_line(e.position, cross_angle + j * PI * 0.5, CROSS_LEN_U * U, CROSS_W_U * U)
			e._sfx(&"telegraph.warn_heavy.heavy", 0.0, true)
			events.append({"kind": &"cross_warn", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0, "angle": cross_angle})
		for j in 4:
			_tele(8 + j).set_progress((_cross_t - wind_from) / CROSS_WIND)
	if _cross_t < CROSS_EVERY:
		return
	_cross_t = 0.0
	_cross_shown = false
	crosses += 1
	pace.impact(&"heavy") # ancré : arrêt sur image et secousse, sans récupération (la croix tourne seule)
	e._sfx(&"enemy.shockwave.heavy", 3.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.3, {"color": CYAN, "radius": 1.8})
	var hit := false
	var v := ppos - e.position
	for j in 4:
		_tele(8 + j).hide_telegraph()
		var d := Vector2.from_angle(cross_angle + j * PI * 0.5)
		_cross_fx(d)
		var along := v.dot(d)
		if not hit and player != null and along >= 0.0 and along <= CROSS_LEN_U * U + PLAYER_R and absf(v.cross(d)) <= CROSS_W_U * 0.5 * U + PLAYER_R:
			hit = true
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"cross"))
			events.append({"kind": &"cross_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
	events.append({"kind": &"cross", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0, "angle": cross_angle})
	cross_angle = PI * 0.25 if cross_angle < 0.1 else 0.0 # « + » puis « × »


## Jet d'eau le long d'un bras de la croix (sillage `ground_wave`, sinon rayon dessiné), 0,5 s.
func _cross_fx(d: Vector2) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"ground_wave"):
		var s := Floor1Fx.sprite(_frames, &"ground_wave", "Eclusier_", 1.8, -1)
		s.rotation = d.angle() - PI * 0.5
		s.scale = Vector2(CROSS_W_U * U / WAVE_SRC_T, CROSS_LEN_U * U / WAVE_SRC_W)
		s.play(&"ground_wave")
		n = s
		e.get_parent().add_child(n)
		n.global_position = e.position + d * CROSS_LEN_U * U * 0.5
	else:
		var f := RecluseFx.make(RecluseFx.Kind.BEAM, Color(CYAN.r, CYAN.g, CYAN.b, 0.4), 0)
		f.radius = CROSS_LEN_U * U
		f.width = CROSS_W_U * U * 0.8
		f.name = &"Eclusier_jet"
		f.rotation = d.angle()
		e.get_parent().add_child(f)
		f.global_position = e.position
		n = f
	_fx.append({"node": n, "life": 0.5, "max": 0.5})


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

func _tele(i: int) -> EnemyTelegraph:
	while _teles.size() <= i:
		var t := EnemyTelegraph.new()
		t.name = &"Eclusier_tele"
		e.get_parent().add_child(t)
		_teles.append(t)
	var tele := _teles[i]
	tele.modulate = Color.WHITE
	return tele


func _walkable(p: Vector2) -> Vector2:
	return e.nav.resolve(p, PLAYER_R) if e.nav else p


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
