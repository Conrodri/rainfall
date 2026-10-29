class_name SonneurBrain
extends RefCounted
## IA du Sonneur (boss d'étage 3, Cité rouillée ; sprites lot C7c). Créée par Enemy.activate_boss quand le
## skin du boss est « sonneur », appelée par Enemy.tick (branche BOSS_TIER) à la place de l'IA générique.
## Même contrat que CerfBrain : coups télégraphiés face au joueur (angle libre ; le sprite prend la plus
## proche de ses 4 orientations e/s/w/n : auto/spell_a/spell_b_<dir>), dégâts à la frame d'impact de
## l'anim (EnemyVisual.play_attack cale la frame d'impact sur la fin du télégraphe).
## Fiche : docs/Design_Boss_Cartes.md §3.3 ; dégâts : Balance.BOSS_ATTACK_COEF[&"sonneur"].
##
## Phases (PV, Enemy.boss_phase) : 1 > 66 % > 2 > 33 % > 3. Au passage : anim trans_pN (boss figé,
## coups en cours annulés) puis variantes idle/walk_pN.
## - Phase 1 « Carillon » : marteau (auto, cône 90° de 3 u), Glas (spell_a : anneau de choc qui part du
##   boss et court de 1 à 8 u ; à l'abri à plus de 8 u ou dans le disque de 1 u sous la cloche), Pluie de
##   boulons (spell_b : 6 cercles de 1 u autour du joueur, un sur lui ; boulons qui tombent du ciel).
## - Phase 2 « Foudre » : le paratonnerre crépite (lumière ambre) ; toutes les 5 s un éclair frappe un
##   cercle télégraphié 1 s sur le joueur (coef 2,5 : le coup le plus lourd) ; Glas double (second anneau
##   1,5 s après le premier).
## - Phase 3 « Chaudière rompue » : +25 % de dégâts reçus (damage_taken_mult), auto 1,6 s, recharges ×0,8 ;
##   4 jets de vapeur en croix (lignes 1 u × 6 u) qui tournent à 20°/s, visibles en permanence ; vapeur
##   sale sur la chaudière, foyer qui vacille. Après sa mort, la foudre continue toutes les 8 s tant que la
##   charge du gros pilier n'est pas finie (nœud SonneurStorm).

enum S { CHASE, HAMMER, GLAS_WIND, GLAS_ECHO, BOLTS, STAGGER }
enum Spell { GLAS, BOLTS }

const ID := &"sonneur"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const RENDER_K := 64.0 / 48.301887 ## px logiques par px de rendu des extras C7c (ortho 5,3)
const AMBER := Color(1.0, 0.80, 0.52) ## accent unique C7c (foudre et foyer)
## Par phase (index phase - 1)
const SPEED_MULT := [1.0, 1.05, 1.15]
const AUTO_CD := [2.0, 2.0, 1.6]
const SPELL_CD := [4.6, 4.2, 3.4] ## délai entre deux sorts (glas et boulons alternés : ~9-10 s chacun ; P3 ×0,8)
## Foyer : le corps de fer sombre (albédo moyen ~40/255) disparaissait sur le sol de nuit (captures) ;
## lumière haute et large (preset boss_cerf teinté ambre), posée à mi-hauteur du corps, + une lumière basse au sol.
const LIGHT_ENERGY := [6.0, 6.5, 7.5]
const LIGHT_RADIUS := [1.3, 1.35, 1.5]
const LIGHT_LIFT_U := 1.6
const FEET_ENERGY := [2.0, 2.2, 2.8]
## Corps re-rendu clair au lot C7E (albédo moyen 37 -> 98/255, rim froid, foyer ambre) : le palliatif
## self_modulate ×1,7 (BODY_GAIN) est retiré ; clear() remet encore self_modulate à blanc par sûreté.
const ROD_ENERGY := [0.0, 2.2, 2.6]
# Marteau (auto)
const HAMMER_RANGE_U := 3.0
const HAMMER_HALF := 0.785 ## 90°
## Armements et récupérations : BossPace (Balance.BOSS_PACE_*) ; marteau = auto, glas et boulons = spell.
# Glas (spell_a)
const GLAS_ECHO_WIND := 1.0 ## P2+ : armement (anim cast_a) du second anneau, dans les GLAS_ECHO_S de l'écho
const GLAS_R0_U := 1.0 ## disque sûr sous la cloche
const GLAS_R1_U := 8.0
const GLAS_WAVE_S := 0.8
const GLAS_BAND_U := 0.9 ## épaisseur du front de l'onde
const GLAS_ECHO_S := 1.5 ## P2+ : second anneau 1,5 s après le premier
const GLAS_SPARKS := 26
const GLAS_RING_PX := 18.0 ## glas_wave (C7E) : rayon de l'anneau dessiné à la frame 0 (px de la cellule 256)
const GLAS_RING_STEP_PX := 15.0 ## … et gain par frame (mesuré : 18, 33, 48 … 123,5)
const GLAS_TELE_ALPHA := 0.6 ## disque de 8 u : alerte plus discrète (captures : l'écran virait au rouge et
## masquait les cercles de foudre et de boulons, posés par-dessus à pleine opacité)
# Pluie de boulons (spell_b)
const BOLT_COUNT := 6
const BOLT_R_U := 1.0
const BOLT_SPREAD_U := 6.0
const BOLT_GAP_U := 0.5 ## cercles d'un même sort jamais superposés
const BOLT_FALL_S := 0.45
const BOLT_FALL_H_U := 8.0
const BOLT_SCALE := 1.0 ## boulon C7E 64 px (~1,3 u à l'écran ; l'ancien 32 px était étiré ×1,7)
# Foudre (phase 2+)
const LIGHTNING_EVERY := [0.0, 5.0, 4.0]
const LIGHTNING_WINDUP := 1.0
const LIGHTNING_R_U := 1.5
const LIGHTNING_FIRST := 2.0 ## premier éclair après la transition
const SCORCH_LIFE := 7.0
const SCORCH_MAX := 14
# Vapeur (phase 3)
const STEAM_JETS := 4
const STEAM_LEN_U := 6.0
const STEAM_W_U := 1.0
const STEAM_TURN := 0.349 ## 20°/s
const STEAM_TICK := 0.5
const STEAM_PUFFS := [1.9, 3.1, 4.3, 5.4] ## u le long d'un jet
const STEAM_ALPHA := 0.55 ## télégraphe continu, plus discret qu'une alerte

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = [] ## journal des coups (tests) : kind, phase, anim, frame, expect, lag
var pace: BossPace ## rythme commun : armement planté, impact, récupération immobile
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT

var _t := 0.0
var _dur := 0.0
var _attack_cd := 1.4
var _spell_cd := 2.5
var _cycle := 0
var _echo_started := false
var _lightning_cd := 0.0
var _steam_angle := 0.0
var _steam_tick := 0.0
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _rod: LightRig.Handle = null
var _feet: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = [] ## télégraphes annexes (boulons, éclairs, jets)
var _bolts: Array[Dictionary] = [] ## {pos, tele, spr}
var _waves: Array[Dictionary] = [] ## {center, t, hit, sparks}
var _strikes: Array[Dictionary] = [] ## {pos, t, tele}
var _fx: Array[Dictionary] = [] ## {node, life, max}
var _scorch: Array[Node] = []
var _jets: Array[Dictionary] = [] ## {tele, puffs}
var _plumes: Array[AnimatedSprite2D] = []


func _init(enemy: Enemy) -> void:
	e = enemy
	vis = enemy.visual as EnemyVisual
	pace = BossPace.new(enemy)
	_rng.randomize()
	_frames = EnemyVisual.boss_frames(ID)
	if e._light != null:
		e._light.set_preset(&"boss_cerf") # 4 u, hauteur 96 : éclaire tout le corps (boss_sonneur_boiler, 2,5 u / 48, le laissait noir)
		e._light.set_color(AMBER)
		e._light.position = Vector2(0.0, Iso.lift_logical(LIGHT_LIFT_U))
	_feet = LightRig.attach(e, &"boss_cerf_hooves", {"color": AMBER})
	# zones centrées sur le boss (marteau, glas) au sol dans le monde, sous son corps (sur la couche des
	# télégraphes, le disque rouge de 8 u le recouvrait) ; libéré par clear()
	if is_instance_valid(e.telegraph):
		e.telegraph.set_in_world(true)
	_rod = LightRig.attach(e, &"boss_sonneur_rod", {"offset": Vector2(0.0, Iso.lift_logical(3.6)), "color": AMBER})
	_apply_phase_look()


## Libère télégraphes, boulons, ondes, éclairs, vapeur (mort, retour au pool). Mort en phase 2+ alors que
## la charge du gros pilier continue : l'orage reste (SonneurStorm).
func clear() -> void:
	if pace != null:
		pace.cancel()
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	if killed and phase >= 2 and _frames != null:
		SonneurStorm.spawn(e, _frames)
	for w in _waves:
		_free_wave(w)
	_waves.clear()
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	for n in _scorch:
		if is_instance_valid(n):
			n.queue_free()
	_scorch.clear()
	for b in _bolts:
		if is_instance_valid(b.get("spr")):
			(b["spr"] as Node).queue_free()
	_bolts.clear()
	for j in _jets:
		for p in j["puffs"]:
			if is_instance_valid(p):
				(p as Node).queue_free()
	_jets.clear()
	for p in _plumes:
		if is_instance_valid(p):
			p.queue_free()
	_plumes.clear()
	_strikes.clear()
	for t in _teles:
		if is_instance_valid(t):
			t.queue_free()
	_teles.clear()
	if _rod != null:
		_rod.release()
	_rod = null
	if _feet != null:
		_feet.release()
	_feet = null
	if vis != null and is_instance_valid(vis) and vis.body_sprite() != null:
		vis.body_sprite().self_modulate = Color.WHITE
	if e != null and is_instance_valid(e) and is_instance_valid(e.telegraph):
		e.telegraph.modulate = Color.WHITE
		e.telegraph.set_in_world(false)
	if e != null and is_instance_valid(e) and e._light != null:
		e._light.set_energy(1.0)
		e._light.set_radius_mult(1.0)
		e._light.set_flicker_override(0.0)
		e._light.set_preset(&"boss")
		e._light.set_color(Color(0, 0, 0, 0))
		e._light.position = Vector2.ZERO


## Transition figée ; planté (armement, récupération) : ni marche ni poussée de foule.
func owns_motion() -> bool:
	return state == S.STAGGER or pace.planted()


## Super-armure le temps d'un coup (armement, récupération) : un recul le ferait glisser.
func ignores_knockback() -> bool:
	return pace.planted()


## Chaudière rompue (P3) : +25 % de dégâts reçus (Balance.BOSS_PHASE_DAMAGE_TAKEN), lu par Enemy.take_damage.
func damage_taken_mult() -> float:
	return Balance.boss_damage_taken_mult(ID, phase)


func wave_count() -> int:
	return _waves.size()


func strike_count() -> int:
	return _strikes.size()


func bolt_count() -> int:
	return _bolts.size()


func jet_count() -> int:
	return _jets.size()


func steam_angle() -> float:
	return _steam_angle


## Un pas d'IA. Retourne la vitesse de marche voulue (px/s logiques), appliquée par Enemy.
func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase:
		_enter_phase(ph)
	_update_waves(delta, player, ppos)
	_update_strikes(delta, player, ppos)
	_update_fx(delta)
	_update_steam(delta, player, ppos)
	_attack_cd -= delta
	_spell_cd -= delta
	_t += delta
	var pi := phase - 1
	if phase >= 2 and state != S.STAGGER:
		_lightning_cd -= delta
		if _lightning_cd <= 0.0:
			_lightning_cd = LIGHTNING_EVERY[pi]
			_start_strike(ppos)
	match state:
		S.STAGGER:
			if _t >= _dur:
				state = S.CHASE
			return Vector2.ZERO
		S.HAMMER:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_hammer(player, ppos)
			return Vector2.ZERO
		S.GLAS_WIND:
			e.telegraph.global_position = e.position
			e.telegraph.set_progress(_t / _dur)
			_rod_charge(_t / _dur)
			if _t >= _dur:
				_release_glas()
				if phase >= 2:
					pace.strike(&"spell", phase, false) # premier anneau : reste planté jusqu'à l'écho
					state = S.GLAS_ECHO
					_t = 0.0
					_dur = GLAS_ECHO_S
					_echo_started = false
					e.telegraph.show_circle(e.position, GLAS_R1_U * U)
				else:
					e.telegraph.hide_telegraph()
					pace.strike(&"spell", phase)
					state = S.CHASE
			return Vector2.ZERO
		S.GLAS_ECHO:
			e.telegraph.global_position = e.position
			e.telegraph.set_progress(_t / _dur)
			if not _echo_started and _t >= _dur - GLAS_ECHO_WIND:
				_echo_started = true
				_face(dir)
				vis.play_attack(&"cast_a", _dur - _t, Vector2.ZERO)
			if _t >= _dur:
				e.telegraph.hide_telegraph()
				_release_glas()
				pace.strike(&"spell", phase) # dernier anneau : récupération immobile
				state = S.CHASE
			return Vector2.ZERO
		S.BOLTS:
			_bolts_step()
			if _t >= _dur:
				_resolve_bolts(player, ppos)
			return Vector2.ZERO
	# --- CHASE
	if pace.recovering(): # récupération immobile : fenêtre de punition, aucun nouveau coup
		_face(dir)
		return Vector2.ZERO
	if vis.is_attacking(): # fin d'un coup (retour de fente) : planté, face au joueur
		_face(dir)
		return Vector2.ZERO
	if _spell_cd <= 0.0 and dist < (GLAS_R1_U + 3.0) * U:
		_start_spell(dir, ppos)
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < HAMMER_RANGE_U * U:
		_start_hammer(dir)
		return Vector2.ZERO
	if dist > HAMMER_RANGE_U * U * 0.75:
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
	_dur = 8.0 / ANIM_FPS + 0.15 # trans_pN : 8 frames
	_spell_cd = maxf(_spell_cd, _dur + 1.2)
	_attack_cd = maxf(_attack_cd, _dur + 0.4)
	_lightning_cd = _dur + LIGHTNING_FIRST
	_cycle = 0
	_apply_phase_look()
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.5, {"color": AMBER})
	if ph == 3:
		e._sfx(&"enemy.shockwave.heavy", 2.0, true) # porte de la chaudière arrachée
	events.append({"kind": &"phase", "phase": ph})


## Coup en cours annulé (changement de phase) : télégraphes masqués, boulons retirés.
func _cancel() -> void:
	pace.cancel()
	e.telegraph.hide_telegraph()
	for b in _bolts:
		if is_instance_valid(b.get("tele")):
			(b["tele"] as EnemyTelegraph).hide_telegraph()
		if is_instance_valid(b.get("spr")):
			(b["spr"] as Node).queue_free()
	_bolts.clear()
	_rod_charge(0.0)


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[pi])
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.3 if phase >= 3 else 0.0, 5.0)
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])
	if _rod != null:
		_rod.set_enabled(phase >= 2)
		_rod.set_energy(ROD_ENERGY[pi])
		_rod.set_flicker_override(0.45, 11.0) # arcs qui crépitent
	if phase >= 3:
		_build_steam()
		_build_plumes()


## Le paratonnerre se charge pendant l'armement du glas et des éclairs.
func _rod_charge(k: float) -> void:
	if _rod == null or phase < 2:
		return
	_rod.set_energy(ROD_ENERGY[phase - 1] * (1.0 + 1.2 * clampf(k, 0.0, 1.0)))


# --- Attaques --------------------------------------------------------------------

func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


func _start_hammer(dir: Vector2) -> void:
	_attack_cd = AUTO_CD[phase - 1]
	aim = dir
	_face(aim)
	state = S.HAMMER
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_cone(e.position, aim.angle(), HAMMER_RANGE_U * U, HAMMER_HALF, EnemyTelegraph.Weight.LIGHT)
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _resolve_hammer(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.brute_cone.heavy")
	var v := ppos - e.position
	if player != null and v.length() <= HAMMER_RANGE_U * U + PLAYER_R and absf(angle_difference(aim.angle(), v.angle())) <= HAMMER_HALF + 0.15:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"hammer"))
	_log(&"hammer", &"attack")
	pace.strike(&"auto", phase)
	state = S.CHASE


func _start_spell(dir: Vector2, ppos: Vector2) -> void:
	var sp: int = Spell.GLAS if _cycle % 2 == 0 else Spell.BOLTS
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	_t = 0.0
	match sp:
		Spell.GLAS:
			state = S.GLAS_WIND
			_dur = BossPace.windup(&"spell", phase)
			pace.wind(&"spell")
			vis.play_attack(&"cast_a", _dur, Vector2.ZERO) # la cloche bat sur place (pas de fente)
			e.telegraph.show_circle(e.position, GLAS_R1_U * U)
			e.telegraph.modulate = Color(1.0, 1.0, 1.0, GLAS_TELE_ALPHA)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)
		Spell.BOLTS:
			state = S.BOLTS
			_dur = BossPace.windup(&"spell", phase, BOLT_FALL_S)
			pace.wind(&"spell")
			vis.play_attack(&"cast_b", _dur, Vector2.ZERO)
			_place_bolts(ppos)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)


## Frappe de la cloche (frame d'impact de spell_a) : l'anneau part du boss.
func _release_glas() -> void:
	_log(&"glas", &"cast_a")
	_rod_charge(0.0)
	e._sfx(&"enemy.shockwave.heavy", 3.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.6, {"color": AMBER, "radius": 2.2})
	var sparks: Array = []
	var host := e.get_parent()
	if _frames != null and _frames.has_animation(&"glas_wave"):
		# anneau C7E vu de dessus (8 frames, rayon GLAS_RING_PX[0] + k × GLAS_RING_STEP_PX) : un sprite au sol
		# étiré à chaque pas pour que l'anneau dessiné tombe sur le front de l'onde (_place_sparks)
		var ring := _sprite(&"glas_wave", Vector2.ONE, Vector2.ZERO, -1, 2.0)
		ring.name = &"Sonneur_glas_wave"
		host.add_child(ring)
		ring.animation = &"glas_wave"
		ring.frame = 0
		sparks.append(ring)
	elif _frames != null and _frames.has_animation(&"ground_lightning"):
		for i in GLAS_SPARKS:
			var s := _sprite(&"ground_lightning", Vector2.ONE * 0.62 * RENDER_K, Vector2.ZERO, -1, 2.2)
			s.rotation = TAU * i / float(GLAS_SPARKS)
			s.speed_scale = 6.0 / ANIM_FPS / GLAS_WAVE_S # les 6 frames s'éteignent avec l'onde
			host.add_child(s)
			s.play(&"ground_lightning")
			sparks.append(s)
	var w := {"center": e.position, "t": 0.0, "hit": false, "sparks": sparks}
	_waves.append(w)
	_place_sparks(w, GLAS_R0_U * U)


func _place_sparks(w: Dictionary, r: float) -> void:
	var sp: Array = w["sparks"]
	var c: Vector2 = w["center"]
	if sp.size() == 1 and is_instance_valid(sp[0]) and (sp[0] as AnimatedSprite2D).animation == &"glas_wave":
		var ring := sp[0] as AnimatedSprite2D
		var k := clampf((r / U - GLAS_R0_U) / (GLAS_R1_U - GLAS_R0_U), 0.0, 1.0)
		var f := mini(int(k * 8.0), 7)
		ring.frame = f
		ring.position = c
		ring.scale = Vector2.ONE * (r / (GLAS_RING_PX + GLAS_RING_STEP_PX * f))
		return
	for i in sp.size():
		var s := sp[i] as Node2D
		if is_instance_valid(s):
			s.position = c + Vector2.from_angle(TAU * i / float(sp.size())) * r


func _update_waves(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := _waves.size() - 1
	while i >= 0:
		var w: Dictionary = _waves[i]
		w["t"] = float(w["t"]) + delta
		var k := clampf(float(w["t"]) / GLAS_WAVE_S, 0.0, 1.0)
		var r := lerpf(GLAS_R0_U, GLAS_R1_U, k) * U
		_place_sparks(w, r)
		var d := (ppos - (w["center"] as Vector2)).length()
		if not w["hit"] and player != null and d > GLAS_R0_U * U and absf(d - r) <= GLAS_BAND_U * 0.5 * U + PLAYER_R:
			w["hit"] = true
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"glas"))
			events.append({"kind": &"glas_hit", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0, "r": r, "d": d})
		if k >= 1.0:
			_free_wave(w)
			_waves.remove_at(i)
		i -= 1


func _free_wave(w: Dictionary) -> void:
	for s in w["sparks"]:
		if is_instance_valid(s):
			(s as Node).queue_free()


# --- Pluie de boulons ------------------------------------------------------------

func _place_bolts(ppos: Vector2) -> void:
	var pts: Array[Vector2] = [_walkable(ppos)]
	var min_d := (2.0 * BOLT_R_U + BOLT_GAP_U) * U
	var tries := 0
	while pts.size() < BOLT_COUNT and tries < 80:
		tries += 1
		var p := ppos + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf_range(0.12, 1.0)) * BOLT_SPREAD_U * U
		p = _walkable(p)
		var ok := true
		for q in pts:
			if q.distance_to(p) < min_d:
				ok = false
				break
		if ok:
			pts.append(p)
	for i in pts.size():
		var tele := _tele(i)
		tele.show_circle(pts[i], BOLT_R_U * U)
		var spr: AnimatedSprite2D = null
		if _frames != null and _frames.has_animation(&"bolt"):
			spr = _sprite(&"bolt", Vector2.ONE * BOLT_SCALE * RENDER_K * Iso.UNSQUASH, Vector2.ZERO, 0, 1.0)
			spr.visible = false
			e.get_parent().add_child(spr)
			spr.position = pts[i]
			spr.play(&"bolt")
			spr.frame = i % 6
		_bolts.append({"pos": pts[i], "tele": tele, "spr": spr})


## Boulons qui tombent du ciel pendant la fin du télégraphe (touchent le sol à la frame d'impact de spell_b).
func _bolts_step() -> void:
	var k := clampf(_t / _dur, 0.0, 1.0)
	var fall := clampf((_t - (_dur - BOLT_FALL_S)) / BOLT_FALL_S, 0.0, 1.0)
	for b in _bolts:
		var tele := b["tele"] as EnemyTelegraph
		if is_instance_valid(tele):
			tele.set_progress(k)
		var spr := b.get("spr") as AnimatedSprite2D
		if is_instance_valid(spr):
			spr.visible = fall > 0.0
			spr.offset = Vector2(0.0, Iso.lift_logical(BOLT_FALL_H_U * (1.0 - fall * fall)) / spr.scale.y)


func _resolve_bolts(player: Node2D, ppos: Vector2) -> void:
	_log(&"bolts", &"cast_b")
	e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	var hit := false
	for b in _bolts:
		var pos: Vector2 = b["pos"]
		if is_instance_valid(b.get("tele")):
			(b["tele"] as EnemyTelegraph).hide_telegraph()
		var spr := b.get("spr") as AnimatedSprite2D
		if is_instance_valid(spr):
			spr.offset = Vector2.ZERO
			spr.stop()
			_fx.append({"node": spr, "life": 1.6, "max": 1.6})
		_scorch_at(pos, 0.75)
		LightRig.flash(pos, &"boss_lightning", 0.18, {"color": AMBER, "energy": 0.5, "radius": 0.5})
		# un même lancer ne touche qu'une fois
		if not hit and player != null and pos.distance_to(ppos) <= BOLT_R_U * U + PLAYER_R:
			hit = true
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"bolts"))
	_bolts.clear()
	pace.strike(&"spell", phase)
	state = S.CHASE


# --- Foudre (phase 2+) ------------------------------------------------------------

func _start_strike(ppos: Vector2) -> void:
	var pos := _walkable(ppos)
	var tele := _tele(BOLT_COUNT + (_strikes.size() % 3))
	tele.show_circle(pos, LIGHTNING_R_U * U, EnemyTelegraph.Weight.DEADLY)
	_strikes.append({"pos": pos, "t": 0.0, "tele": tele})
	e._sfx(&"telegraph.warn_heavy.heavy", -2.0, true)


func _update_strikes(delta: float, player: Node2D, ppos: Vector2) -> void:
	var i := _strikes.size() - 1
	while i >= 0:
		var s: Dictionary = _strikes[i]
		s["t"] = float(s["t"]) + delta
		var k := float(s["t"]) / LIGHTNING_WINDUP
		var tele := s["tele"] as EnemyTelegraph
		if is_instance_valid(tele):
			tele.set_progress(k)
		_rod_charge(k)
		if k >= 1.0:
			if is_instance_valid(tele):
				tele.hide_telegraph()
			var pos: Vector2 = s["pos"]
			var bolt := strike_fx(e.get_parent(), _frames, pos, _fx)
			e._sfx(&"amb.thunder_close", 0.0, true)
			if player != null and pos.distance_to(ppos) <= LIGHTNING_R_U * U + PLAYER_R:
				e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"lightning"))
			events.append({"kind": &"lightning", "phase": phase, "anim": bolt.animation if bolt != null else &"",
				"frame": bolt.frame if bolt != null else 0, "expect": 0, "lag": 0.0})
			_rod_charge(0.0)
			_strikes.remove_at(i)
		i -= 1


## Impact d'un éclair : colonne (lightning, 4 variantes), éclat au sol (ground_lightning), brûlure
## (ground_scorch) et flash. Les dégâts tombent sur la frame 0 de la colonne. Retourne la colonne.
static func strike_fx(host: Node, frames: SpriteFrames, pos: Vector2, fx: Array) -> AnimatedSprite2D:
	LightRig.flash(pos, &"boss_lightning", 0.4, {"color": AMBER.lightened(0.4)})
	if frames == null or host == null:
		return null
	var ring := _sprite_static(frames, &"ground_lightning", Vector2.ONE * (2.0 * LIGHTNING_R_U * U / 102.0), Vector2.ZERO, -1, 2.6)
	host.add_child(ring)
	ring.position = pos
	ring.play(&"ground_lightning")
	fx.append({"node": ring, "life": 0.7, "max": 0.7})
	# colonne C7E : cellule 128×768 pleine hauteur (64 px/u, ~12 u), pied 5 px au-dessus du bas de la cellule
	var col := _sprite_static(frames, &"lightning", Vector2.ONE * Iso.UNSQUASH, Vector2(0.0, -379.0), 0, 3.0)
	host.add_child(col)
	col.position = pos
	col.play(&"lightning")
	col.frame = 0
	fx.append({"node": col, "life": 0.45, "max": 0.45})
	var sc := _sprite_static(frames, &"ground_scorch", Vector2.ONE * 1.5 * RENDER_K, Vector2.ZERO, -2, 1.2)
	host.add_child(sc)
	sc.position = pos
	sc.animation = &"ground_scorch"
	sc.frame = randi() % maxi(frames.get_frame_count(&"ground_scorch"), 1)
	fx.append({"node": sc, "life": SCORCH_LIFE, "max": 1.5})
	return col


func _scorch_at(pos: Vector2, size: float) -> void:
	if _frames == null or not _frames.has_animation(&"ground_scorch"):
		return
	while _scorch.size() >= SCORCH_MAX:
		var old: Node = _scorch.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var sc := _sprite(&"ground_scorch", Vector2.ONE * size * RENDER_K, Vector2.ZERO, -2, 1.0)
	e.get_parent().add_child(sc)
	sc.position = pos
	sc.animation = &"ground_scorch"
	sc.frame = _rng.randi() % 4
	_fx.append({"node": sc, "life": SCORCH_LIFE * 0.6, "max": 1.5})


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


# --- Vapeur (phase 3) ---------------------------------------------------------------

func _build_steam() -> void:
	if not _jets.is_empty():
		return
	for j in STEAM_JETS:
		var tele := _tele(BOLT_COUNT + 3 + j)
		tele.set_in_world(true, e.get_parent()) # jets issus du boss : sous son corps, comme le glas
		tele.show_line(e.position, 0.0, STEAM_LEN_U * U, STEAM_W_U * U)
		tele.set_progress(1.0)
		tele.modulate = Color(1.0, 1.0, 1.0, STEAM_ALPHA)
		var puffs: Array = []
		if _frames != null and _frames.has_animation(&"steam_jet"):
			# jet C7E vu de dessus, 384×64 = 6 u × 1 u (64 px/u), origine au bord gauche (côté boss) :
			# un seul sprite au sol tourné avec le jet (« puffs » = [ce sprite], placé par _place_jets)
			var jet := _sprite(&"steam_jet", Vector2(1.0, 1.4), Vector2(192.0, 0.0), -1, 1.0) # un peu épaissi : lisible sous le trait rouge
			e.get_parent().add_child(jet)
			jet.play(&"steam_jet")
			jet.frame = j * 2
			puffs.append(jet)
		elif _frames != null and _frames.has_animation(&"steam_vent"):
			for k in STEAM_PUFFS.size():
				# jet de vapeur 64x384 : panache utile y 163-224, pied à 224
				var p := _sprite(&"steam_vent", Vector2(3.4, 2.6) * RENDER_K * Iso.UNSQUASH, Vector2(0.0, -32.0), 0, 1.0)
				e.get_parent().add_child(p)
				p.play(&"steam_vent")
				p.frame = (j * 2 + k) % 8
				puffs.append(p)
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
		if puffs.size() == 1 and is_instance_valid(puffs[0]) and (puffs[0] as AnimatedSprite2D).animation == &"steam_jet":
			var jet := puffs[0] as Node2D
			jet.position = e.position
			jet.rotation = a
			continue
		for k in puffs.size():
			if is_instance_valid(puffs[k]):
				(puffs[k] as Node2D).position = e.position + Vector2.from_angle(a) * STEAM_PUFFS[k] * U


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
		var perp := absf(v.cross(d))
		if along >= 0.0 and along <= STEAM_LEN_U * U + PLAYER_R and perp <= STEAM_W_U * 0.5 * U + PLAYER_R:
			_steam_tick = STEAM_TICK
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"steam"))
			events.append({"kind": &"steam", "phase": phase, "anim": &"", "frame": -1, "expect": -1, "lag": 0.0})
			return


## Vapeur sale qui fuit de la chaudière ouverte (P3), sur le corps.
func _build_plumes() -> void:
	if not _plumes.is_empty() or _frames == null or not _frames.has_animation(&"ground_steam"):
		return
	for i in 2:
		var p := _sprite(&"ground_steam", Vector2(2.6, 2.2) * RENDER_K * Iso.UNSQUASH, Vector2(0.0, -32.0), 1, 1.0)
		p.name = &"SonneurPlume"
		p.position = Vector2((i * 2 - 1) * 0.55 * U, Iso.lift_logical(1.9))
		p.modulate = Color(1.0, 1.0, 1.0, 0.85)
		vis.add_child(p)
		p.play(&"ground_steam")
		p.frame = i * 4
		_plumes.append(p)


# --- Outils ------------------------------------------------------------------------

func _sprite(anim: StringName, sc: Vector2, off: Vector2, z: int, energy: float) -> AnimatedSprite2D:
	return _sprite_static(_frames, anim, sc, off, z, energy)


static func _sprite_static(frames: SpriteFrames, anim: StringName, sc: Vector2, off: Vector2, z: int, energy: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = StringName("Sonneur_" + String(anim))
	EmissiveOverlay.apply(s, frames, energy)
	s.animation = anim
	s.scale = sc
	s.offset = off
	s.z_index = z
	return s


## Télégraphe annexe n° i (créé à la demande, libéré avec l'IA).
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
