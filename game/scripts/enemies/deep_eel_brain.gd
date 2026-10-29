class_name DeepEelBrain
extends RefCounted
## IA de l'Anguille des profondeurs (boss d'étage 4, Cryptes noyées ; docs/Design_Etages.md §5.4). Créée par
## Enemy.activate_boss quand le skin du boss est « deep_eel », appelée par Enemy.tick (branche BOSS_TIER).
## Même contrat que RecluseBrain : coups télégraphiés face au joueur, dégâts à la frame d'impact
## (EnemyVisual.play_attack), coefficients Balance.BOSS_ATTACK_COEF[&"deep_eel"], seuils 70 / 35 %.
## Sans sprites (lot Codex C8d, art/tools/night/requests_bosses4.md) : silhouette et effets provisoires
## (RecluseFx) ; chaque extra du .tres (black_pool, wake, emerge_splash, discharge_ring, puddle, whip)
## remplace son repli dès qu'il est livré.
##
## 3,8 u de long, écailles de sel, nageoires-lames, lueur interne blanc-cyan #BFF4FF. À son apparition le sol
## des cryptes s'effondre en un LAC D'EAU NOIRE (rayon 3,5 u) : elle y vit, plongée (dégâts reçus × 0,3,
## seule sa lueur se devine sous l'eau), et en surgit. Elle se déplace elle-même (owns_motion).
## - Phase 1 « Le lac » : morsure (auto : cône court au bord) ; Émergence (spell_a : ligne 2 × 14 u depuis
##   l'eau, 1,2 s, coef 1,8 ; elle s'abat au bout de la ligne et reste ÉCHOUÉE 1,4 s : la fenêtre de DPS,
##   puis rampe jusqu'à l'eau) ; Décharge (spell_b : anneau de 2,5 à 6 u autour d'elle, 1 s, coef 1,4 +
##   ralenti : SE COLLER à elle est sûr) ; chaque décharge projette 3 FLAQUES d'eau noire (9 s).
## - Phase 2 « Crue » (70 %) : le lac s'élargit de 2 u (bord qui recule), les cristaux noyés s'éteignent
##   (RecluseGloom limité au lac). SURPRISE : toute eau noire est la même eau : elle peut surgir d'une
##   FLAQUE près du joueur (bulles + télégraphe habituel) ; on croyait le lac loin.
## - Phase 3 « Échouée » (35 %) : elle s'échoue sur l'anneau, ancrée et vulnérable (+25 %), fouette avec
##   2 lignes tournantes (7 u, 40°/s, télégraphe continu, 0,5 par 0,5 s) ; sa décharge passe dans TOUTE
##   l'eau (lac + flaques en rouge, 1 s, coef 1,2 + ralenti) en alternance avec l'anneau ; morsure au contact.
## Trace après la mort (phase 2+) : la crue (lac élargi et flaques) reste jusqu'à la fin de la charge.
##
## Lisibilité (retour joueur 23/10 : « quasi invisible, retourne toujours dans l'eau puis dashe ») :
## - plongée : LUEUR cyan sous l'eau, ellipse allongée dans l'axe du corps (halo_soft_256, additive, unshaded :
##   lisible sur l'eau noire), sillage C8d atténué derrière elle, REMOUS (anneaux light_ring_256 qui s'élargissent)
##   tous les GLOW_RIPPLE_EVERY_U ; barre de boss « PLONGÉE — DÉGÂTS RÉDUITS » (boss_state_tag) ;
## - émergence : la lueur grossit et s'emballe pendant l'armement, la tête affleure (alpha qui monte) ;
## - échouée (P1-P2) : pose échouée en S (idle_p3, EnemyVisual.set_pose_phase), barre « ÉCHOUÉE — VULNÉRABLE ».

enum S { SWIM, SURFACE, BITE, EMERGE_WIND, LUNGE, STRANDED, RETURN, DISCHARGE, LIVE_WATER, ANCHORED, STAGGER }

const ID := &"deep_eel"
const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const ANIM_FPS := 12.0
const CRYSTAL := Color(0.749, 0.957, 1.0) ## #BFF4FF, lueur interne
const SCALES := Color(0.60, 0.65, 0.68) ## écailles de sel (lisibles de nuit)
const WATER := Color(0.02, 0.035, 0.05, 0.92) ## eau noire
const WATER_RIM := Color(0.749, 0.957, 1.0, 0.55)
## Par phase (index phase - 1)
const SWIM_U := [5.0, 6.5, 0.0]
const SPELL_CD := [4.2, 3.8, 3.4] ## émergence et décharge alternées (P3 : anneau et eau vive)
const BITE_CD := [1.8, 1.6, 1.4]
const LIGHT_ENERGY := [3.0, 3.6, 4.4]
const LIGHT_RADIUS := [1.2, 1.35, 1.5]
const LIGHT_SUBMERGED := 1.1 ## lueur sous l'eau : éclaire la rive autour d'elle (ex-0,35 : quasi invisible)
const LIGHT_LIFT_U := 1.2
const FEET_ENERGY := [2.0, 2.4, 3.0]
const BODY_GAIN := Color(1.0, 1.03, 1.06) ## ex-(1,2 ; 1,24 ; 1,3) : corps brûlé en blanc sous sa propre lumière
# Plongée : lueur sous l'eau, sillage, remous (repères posés dans le plan de sol logique : ellipses en iso)
const GLOW_LEN_U := 3.6 ## lueur : longueur dans l'axe du corps (3,8 u)
const GLOW_W_U := 1.5
const GLOW_COLOR := Color(0.62, 0.95, 1.0)
const GLOW_ALPHA := 0.85
const GLOW_WIND_GROW := 0.45 ## armement de l'émergence : la lueur grossit de 45 % et pulse de plus en plus vite
const GLOW_RIPPLE_EVERY_U := 0.9 ## un remous tous les 0,9 u nagés …
const GLOW_RIPPLE_IDLE_S := 0.7 ## … ou toutes les 0,7 s à l'arrêt
const RIPPLE_S := 0.9
const RIPPLE_R0_U := 0.45
const RIPPLE_R1_U := 1.2
const RIPPLE_PEAK_PX := 97.0 ## rayon du pic de light_ring_256 (HitboxRing.RING_PEAK_PX)
## Sillage C8d (wake, 2 u) : livré comme une plaque octogonale claire pleine + V en traits SOMBRES (invisibles sur
## l'eau noire) ; avec sa propre lumière il devenait une tache blanche sans direction. Masqué tant que la lueur
## (halo_soft_256) et les remous portent la position ; gardé en repli si le halo manque. À refaire (Codex).
const WAKE_SCALE := 1.5
const WAKE_ENERGY := 0.0
const WAKE_ALPHA := 0.3
const STATE_TAG_DIVE := "PLONGÉE — DÉGÂTS RÉDUITS"
const STATE_TAG_STRANDED := "ÉCHOUÉE — VULNÉRABLE"

# Lac
const POOL_R_U := 3.5
const POOL_SHIFT_U := 1.0 ## centre décalé du pilier (vers l'apparition)
const FLOOD_ADD_U := 2.0
const FLOOD_S := 2.5
const GLOOM_K := 0.35 ## cristaux noyés
const RIM_IN_U := 0.4 ## point d'émergence : juste dedans du bord
## Rythme (BossPace, Balance.BOSS_PACE_*) : morsure = &"auto" ; émergence = &"charge" (armement planté dans
## l'eau, bond, échouage = récupération STRAND_S) ; décharge et eau vive = &"spell". La nage n'est pas un coup ;
## après un coup elle reste en surface, immobile, le temps de sa récupération, puis replonge.
# Morsure (auto)
const BITE_RANGE_U := 2.8
const BITE_HALF := 0.7
const SURFACE_S := 0.9
# Émergence (spell_a)
const EMERGE_LEN_U := 14.0
const EMERGE_W_U := 2.0
const LUNGE_S := 0.3
const STRAND_S := [1.4, 1.2, 1.0] ## échouée = récupération immobile de l'émergence (>= BossPace &"charge")
const RETURN_U := 9.0
const ROUTE_REACH_U := 1.5 ## retour à l'eau : le chemin (NavField.find_path) s'arrête à 1,5 u de l'eau visée
const LAKE_REACH_U := 7.0 ## vrai lac de la carte retenu si sa rive est à <= zone de charge + 7 u du pilier
const LAKE_PATH_SLACK := 1.6 ## … et joignable à pied (chemin <= 1,6 × la distance droite + 2 u)
const LAKE_CENTER_IN_U := 0.5 ## centre du disque juste dans l'eau profonde : il chevauche la rive (moitié à pied)
# Décharge (spell_b)
const DISCHARGE_R0_U := 2.5
const DISCHARGE_R1_U := 6.0
const PUDDLES_PER := 3
const PUDDLE_R_U := 1.0
const PUDDLE_LIFE := 9.0
const PUDDLE_MAX := 8
const PUDDLE_REACH_U := 6.0 ## P2+ : flaque à moins de 6 u du joueur, s'il est loin du lac
# Phase 3
const WHIPS := 2
const WHIP_LEN_U := 7.0
const WHIP_W_U := 1.2
const WHIP_TURN := 0.70 ## 40°/s
const WHIP_TICK := 0.5
const WHIP_ALPHA := 0.55

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = [] ## journal des coups (tests)
var phase := 1
var state := S.SWIM
var aim := Vector2.RIGHT
var center := Vector2.ZERO ## centre du lac
var pool_r := POOL_R_U * U ## rayon courant (px)
var emerge_from_puddle := 0 ## émergences sorties d'une flaque (tests)
var slowed := 0
var pace: BossPace ## armement planté, impact, récupération immobile (scripts/enemies/boss_pace.gd)

var _t := 0.0
var _dur := 0.0
var _spell_cd := 1.6
var _bite_cd := 0.8
var _cycle := 0
var _flood_t := -1.0
var _origin := Vector2.ZERO ## point d'émergence (lac ou flaque)
var _lunge_to := Vector2.ZERO
var _return_to := Vector2.ZERO
var _route := PackedVector2Array() ## points de passage du retour à l'eau (contourne les murs)
var _route_i := 0
var lake_source := &"pillar" ## &"map" : lac posé sur le vrai lac (~) de la carte ; &"pillar" : près du pilier
var _emerge_len := EMERGE_LEN_U * U
var _emerge := 0.0 ## sortie du corps (0 plongée .. 1 arche)
var _whip_angle := 0.0
var _whip_tick := 0.0
var _ppos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _frames: SpriteFrames = null
var _feet: LightRig.Handle = null
var _teles: Array[EnemyTelegraph] = []
var _pool: Node2D = null
var _wake: Node2D = null
var _ring: RecluseFx = null ## télégraphe en anneau de la décharge
var _live: Array[RecluseFx] = [] ## télégraphes de l'eau vive (lac + flaques)
var _puddles: Array[Dictionary] = [] ## {pos, life, node}
var _whips: Array[Dictionary] = [] ## {tele, beam}
var _fx: Array[Dictionary] = []
var _body: RecluseFx = null
var _gloom: RecluseGloom = null
var _glow: Sprite2D = null ## lueur sous l'eau (plongée, armement de l'émergence)
var _ripple_t := 0.0
var _ripple_d := 0.0
var _last_pos := Vector2.ZERO
var _clock := 0.0


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
	center = _pick_lake_center()
	_build_pool()
	_build_wake()
	_build_glow()
	# entrée en scène : le sol s'effondre, elle jaillit puis plonge
	e.position = center
	_emerge = 1.0
	_splash(center, 1.6)
	e._sfx(&"enemy.shockwave.heavy", 3.0, true)
	LightRig.flash(center, &"boss_lightning", 0.5, {"color": CRYSTAL, "radius": 1.8})
	_dive()
	_apply_phase_look()


## Libère tout. Mort en phase 2+ pendant la charge : la crue (lac, flaques) reste, confiée à RecluseGloom.
func clear() -> void:
	if pace != null:
		pace.cancel() # arrêt sur image en cours rendu (corps remis en pool)
	var killed := e != null and is_instance_valid(e) and e.hp <= 0.0
	var keep_trace := killed and is_instance_valid(_gloom)
	if keep_trace:
		_gloom.keep(_pool)
		for p in _puddles:
			_gloom.keep(p["node"])
	else:
		if is_instance_valid(_pool):
			_pool.queue_free()
		for p in _puddles:
			if is_instance_valid(p["node"]):
				(p["node"] as Node).queue_free()
	_pool = null
	_puddles.clear()
	if is_instance_valid(_gloom):
		if killed:
			_gloom.on_boss_dead()
		else:
			_gloom.release()
	_gloom = null
	for n in [_wake, _ring, _body, _glow]:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_wake = null
	_glow = null
	_ring = null
	_body = null
	for l in _live:
		if is_instance_valid(l):
			l.queue_free()
	_live.clear()
	for w in _whips:
		if is_instance_valid(w.get("beam")):
			(w["beam"] as Node).queue_free()
	_whips.clear()
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	for t in _teles:
		if is_instance_valid(t):
			t.queue_free()
	_teles.clear()
	if _feet != null:
		_feet.release()
	_feet = null
	if vis != null and is_instance_valid(vis):
		vis.self_modulate = Color.WHITE
		vis.modulate = Color.WHITE
		vis.scale = Vector2.ONE
		vis.set_pose_phase(0)
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


## L'anguille se déplace elle-même (nage sous l'eau, bonds, retour au lac) ; ses coups sont plantés (BossPace :
## e.position n'est jamais touchée pendant l'armement ni la récupération).
func owns_motion() -> bool:
	return true


## Jamais de recul (Enemy._direct_hit) : elle se déplace seule (owns_motion), souvent dans l'eau du vrai lac
## (et super-armure pendant ses coups, pace.planted()).
func ignores_knockback() -> bool:
	return true


func submerged() -> bool:
	return state == S.SWIM


func damage_taken_mult() -> float:
	var m := Balance.boss_damage_taken_mult(ID, phase)
	if submerged():
		m *= Balance.EEL_SUBMERGED_DAMAGE_TAKEN
	return m


## Étiquette d'état pour la barre de boss (BossHealthBar, duck typing) : {text, color, kind} ; {} = rien.
## kind &"guarded" (plongée : dégâts reçus réduits) ou &"exposed" (échouée : fenêtre de dégâts).
func boss_state_tag() -> Dictionary:
	if submerged():
		return {"text": STATE_TAG_DIVE, "color": GLOW_COLOR, "kind": &"guarded"}
	if state == S.STRANDED or (phase >= 3 and state != S.STAGGER):
		return {"text": STATE_TAG_STRANDED, "color": Color(1.0, 0.80, 0.45), "kind": &"exposed"}
	return {}


## Lueur sous l'eau affichée (tests) : visible et assez opaque.
func glow_shown() -> bool:
	return is_instance_valid(_glow) and _glow.visible and _glow.modulate.a >= 0.3


func puddle_count() -> int:
	return _puddles.size()


func whip_count() -> int:
	return _whips.size()


func whip_angle() -> float:
	return _whip_angle


func gloom() -> RecluseGloom:
	return _gloom if is_instance_valid(_gloom) else null


## Vrai si `p` est dans l'eau noire (lac ou flaque).
func in_water(p: Vector2, margin := 0.0) -> bool:
	if p.distance_to(center) <= pool_r + margin:
		return true
	for pd in _puddles:
		if p.distance_to(pd["pos"]) <= PUDDLE_R_U * U + margin:
			return true
	return false


## Pose une flaque (tests, décharge).
func add_puddle(p: Vector2) -> void:
	_add_puddle(p)


## Un pas d'IA. Le retour (vitesse) est ignoré : owns_motion.
func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, _path_dir: Vector2) -> Vector2:
	_ppos = ppos
	_clock += delta
	pace.tick(delta)
	var ph: int = e.boss_phase()
	if ph > phase:
		_enter_phase(ph)
	_update_flood(delta)
	_update_puddles(delta)
	_update_whips(delta, player, ppos)
	_update_fx(delta)
	_spell_cd -= delta
	_bite_cd -= delta
	_t += delta
	var pi := phase - 1
	var to_p := ppos - e.position
	match state:
		S.STAGGER:
			_emerge_to(1.0 if phase >= 3 else 0.6, delta)
			if phase >= 3: # glisse vers l'anneau où elle s'échoue (chemin qui contourne les murs)
				_follow_route(RETURN_U * U, delta)
			if _t >= _dur:
				if phase >= 3:
					e.position = _return_to
					_build_whips()
					state = S.ANCHORED
				else:
					_dive()
		S.SWIM:
			_emerge_to(0.0, delta)
			var target := _rim_toward(ppos)
			if not in_water(e.position, 0.1 * U): # plongée dans une flaque : toute l'eau est la même, elle passe
				_splash(e.position, 0.5)             # sous le sol et ressort au bord du lac (ni lueur ni remous sur la terre)
				e.position = target
				_last_pos = target
				to_p = ppos - e.position # visée de la morsure depuis le nouveau point
			e.position = e.position.move_toward(target, SWIM_U[pi] * U * delta)
			_update_ripples(delta)
			if to_p.length_squared() > 1.0:
				_face(to_p)
			var at_rim := e.position.distance_to(target) < 0.3 * U
			if _spell_cd <= 0.0 and (at_rim or _t > 2.5):
				_start_spell(ppos)
			elif at_rim and _bite_cd <= 0.0 and dist < BITE_RANGE_U * U + 0.5 * U:
				_surface()
				_start_bite(to_p)
		S.SURFACE:
			_emerge_to(0.6, delta)
			_face(to_p)
			if pace.recovering(): # récupération immobile en surface (fenêtre de punition), puis plongée
				pass
			elif _spell_cd <= 0.0:
				_start_spell(ppos)
			elif _bite_cd <= 0.0 and dist < BITE_RANGE_U * U + 0.5 * U:
				_start_bite(to_p)
			elif _t >= _dur:
				_dive()
		S.BITE:
			_emerge_to(0.8, delta)
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_bite(player, ppos)
		S.EMERGE_WIND:
			e.telegraph.global_position = _origin
			e.telegraph.set_progress(_t / _dur)
			_emerge_to(0.15 + 0.3 * clampf(_t / _dur, 0.0, 1.0), delta) # la tête affleure pendant l'armement
			if fmod(_t, 0.3) < delta: # bulles qui montent au point d'émergence
				_splash(_origin, 0.4)
			if _t >= _dur:
				_release_emergence(player, ppos)
		S.LUNGE:
			_emerge = 1.0
			e.position = _origin.lerp(_lunge_to, clampf(_t / LUNGE_S, 0.0, 1.0))
			if _t >= LUNGE_S:
				e.position = _lunge_to
				_splash(_lunge_to, 1.0)
				state = S.STRANDED
				_t = 0.0
				_dur = STRAND_S[pi]
				vis.set_pose_phase(3) # pose échouée en S (idle_p3) : hors de l'eau, sans ambiguïté
				vis.set_action(&"idle")
				pace.strike(&"charge", phase, true, _dur) # arrêt net : échouée = récupération immobile
		S.STRANDED: # échouée : vulnérable, la fenêtre de DPS
			_emerge = 1.0
			_face(to_p)
			if _t >= _dur:
				state = S.RETURN
				_t = 0.0
				_return_to = _nearest_water(e.position)
				_route_to(_return_to)
		S.RETURN: # rampe jusqu'à l'eau en contournant murs et obstacles (NavField.find_path)
			_emerge_to(0.8, delta)
			_face(_route_dir())
			if _follow_route(RETURN_U * U, delta):
				_splash(e.position, 0.8)
				_dive()
		S.DISCHARGE:
			_emerge_to(0.6, delta)
			_face(to_p)
			if is_instance_valid(_ring):
				_ring.global_position = e.position
				_ring.set_param(_ring.radius, -1.0, _t / _dur)
			if _t >= _dur:
				_release_discharge(player, ppos)
		S.LIVE_WATER:
			_emerge = 1.0
			for l in _live:
				if is_instance_valid(l):
					l.set_param(l.radius, -1.0, _t / _dur)
			if _t >= _dur:
				_release_live_water(player, ppos)
		S.ANCHORED:
			_emerge = 1.0
			_face(to_p)
			if not pace.recovering(): # pendant la récupération : pose de fin de coup tenue, aucun nouveau coup
				vis.set_action(&"idle")
				if _spell_cd <= 0.0:
					_start_spell(ppos)
				elif _bite_cd <= 0.0 and dist < BITE_RANGE_U * U + 0.3 * U:
					_start_bite(to_p)
	_update_visual(delta)
	return Vector2.ZERO


# --- Phases --------------------------------------------------------------------

func _enter_phase(ph: int) -> void:
	_cancel()
	phase = ph
	state = S.STAGGER
	_t = 0.0
	_dur = 8.0 / ANIM_FPS + 0.25 # trans_pN : 8 frames
	_spell_cd = maxf(_spell_cd, _dur + 1.0)
	_bite_cd = maxf(_bite_cd, _dur + 0.4)
	_cycle = 0
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.6, {"color": CRYSTAL, "radius": 1.6})
	_splash(e.position, 1.4)
	if ph == 2: # crue : le lac s'élargit, les cristaux noyés s'éteignent
		_flood_t = 0.0
		if _gloom == null:
			_gloom = RecluseGloom.create_with(e, {"dim_k": GLOOM_K, "center": center, "radius": (POOL_R_U + FLOOD_ADD_U + 3.0) * U, "name": "DeepEel_gloom"})
		events.append({"kind": &"flood", "phase": ph})
		e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	if ph >= 3: # s'échoue sur l'anneau, côté joueur
		if _flood_t >= 0.0 and _flood_t < FLOOD_S:
			_flood_t = FLOOD_S
			_update_flood(0.0)
		var d := (_ppos - center)
		d = d.normalized() if d.length_squared() > 1.0 else Vector2.RIGHT
		_return_to = _walkable(center + d * pool_r)
		_route_to(_return_to)
		events.append({"kind": &"stranded", "phase": ph})
	_apply_phase_look()
	events.append({"kind": &"phase", "phase": ph})


func _cancel() -> void:
	pace.cancel()
	vis.set_pose_phase(0)
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	if is_instance_valid(_ring):
		_ring.visible = false
	for l in _live:
		if is_instance_valid(l):
			l.queue_free()
	_live.clear()


func _apply_phase_look() -> void:
	var pi := phase - 1
	if e._light != null:
		e._light.set_radius_mult(LIGHT_RADIUS[pi])
		e._light.set_flicker_override(0.12 if phase >= 3 else -1.0, 1.8)
	if _feet != null:
		_feet.set_energy(FEET_ENERGY[pi])
	if _body != null:
		_body.glow = 0.6 + 0.2 * phase


# --- Lac, flaques -----------------------------------------------------------------------

func _build_pool() -> void:
	if _frames != null and _frames.has_animation(&"black_pool"):
		var s := _sprite(&"black_pool", Vector2.ONE, Vector2.ZERO, -2, 1.2)
		s.play(&"black_pool")
		_pool = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.DISC, WATER, -2)
		f.color2 = WATER_RIM
		f.width = 4.0
		_pool = f
	_pool.name = &"DeepEel_pool"
	e.get_parent().add_child(_pool)
	_pool.position = center
	_set_pool_visual()


func _set_pool_visual() -> void:
	if not is_instance_valid(_pool):
		return
	if _pool is RecluseFx:
		(_pool as RecluseFx).set_param(pool_r)
	else:
		_pool.scale = Vector2.ONE * (pool_r / 448.0) # black_pool : disque de 448 px de rayon (cellule 896)


func _update_flood(delta: float) -> void:
	if _flood_t < 0.0 or _flood_t > FLOOD_S:
		return
	_flood_t += delta
	var k := clampf(_flood_t / FLOOD_S, 0.0, 1.0)
	pool_r = (POOL_R_U + FLOOD_ADD_U * k * k * (3.0 - 2.0 * k)) * U
	_set_pool_visual()
	if _flood_t > FLOOD_S:
		_flood_t = FLOOD_S + 1.0 # fini


func _add_puddle(p: Vector2) -> void:
	if _puddles.size() >= PUDDLE_MAX:
		var old: Dictionary = _puddles.pop_front()
		if is_instance_valid(old["node"]):
			(old["node"] as Node).queue_free()
	var n: Node2D
	if _frames != null and _frames.has_animation(&"puddle"):
		var s := _sprite(&"puddle", Vector2.ONE, Vector2.ZERO, -2, 1.2)
		s.play(&"puddle")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.DISC, WATER, -2)
		f.radius = PUDDLE_R_U * U
		f.color2 = WATER_RIM
		f.width = 3.0
		n = f
	n.name = &"DeepEel_puddle"
	e.get_parent().add_child(n)
	n.position = p
	_puddles.append({"pos": p, "life": PUDDLE_LIFE, "node": n})
	events.append({"kind": &"puddle", "phase": phase})


func _update_puddles(delta: float) -> void:
	var i := _puddles.size() - 1
	while i >= 0:
		var p: Dictionary = _puddles[i]
		p["life"] = float(p["life"]) - delta
		var n := p["node"] as CanvasItem
		if is_instance_valid(n):
			n.modulate.a = clampf(float(p["life"]) / 1.0, 0.0, 1.0)
		if float(p["life"]) <= 0.0:
			if is_instance_valid(n):
				n.queue_free()
			_puddles.remove_at(i)
		i -= 1


## Point d'émergence vers `p` : juste dedans du bord du lac.
func _rim_toward(p: Vector2) -> Vector2:
	var d := p - center
	if d.length() <= pool_r - RIM_IN_U * U:
		return p # le joueur est dans l'eau : elle vient sous lui
	return center + d.normalized() * (pool_r - RIM_IN_U * U)


func _nearest_water(p: Vector2) -> Vector2:
	var best := _rim_toward(p)
	var bd := p.distance_to(best)
	for pd in _puddles:
		var q: Vector2 = pd["pos"]
		if p.distance_to(q) < bd:
			bd = p.distance_to(q)
			best = q
	return best


# --- Plongée / surface ------------------------------------------------------------------

func _dive() -> void:
	state = S.SWIM
	_t = 0.0
	vis.set_pose_phase(0)
	_last_pos = e.position
	e.telegraph.hide_telegraph()
	if e._light != null:
		e._light.set_energy(LIGHT_SUBMERGED)


func _surface() -> void:
	state = S.SURFACE
	_t = 0.0
	_dur = SURFACE_S
	_splash(e.position, 0.6)
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[phase - 1])


func _emerge_to(target: float, delta: float) -> void:
	_emerge = move_toward(_emerge, target, delta * 4.0)


func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


# --- Morsure (auto) ----------------------------------------------------------------------

func _start_bite(dir: Vector2) -> void:
	_bite_cd = BITE_CD[phase - 1]
	aim = dir.normalized() if dir.length_squared() > 0.01 else aim
	_face(aim)
	state = S.BITE
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase)
	pace.wind(&"auto")
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[phase - 1])
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
		events.append({"kind": &"bite_hit", "phase": phase})
	_log(&"bite", &"attack")
	pace.strike(&"auto", phase)
	if phase >= 3:
		state = S.ANCHORED
	else:
		_hold_surface(SURFACE_S * 0.6)


## Après un coup (P1-P2) : reste en surface, immobile, au moins le temps de la récupération, puis replonge.
func _hold_surface(min_s: float) -> void:
	state = S.SURFACE
	_t = 0.0
	_dur = maxf(min_s, pace.recover_left)


# --- Sorts -------------------------------------------------------------------------------

func _start_spell(ppos: Vector2) -> void:
	var a := _cycle % 2 == 0
	_cycle += 1
	_spell_cd = SPELL_CD[phase - 1]
	_bite_cd = maxf(_bite_cd, 0.6)
	_t = 0.0
	if phase >= 3:
		if a:
			_start_discharge()
		else:
			_start_live_water()
	elif a:
		_start_emergence(ppos)
	else:
		_start_discharge()
	e._sfx(&"telegraph.boss.heavy", 0.0, true)


# --- Émergence ----------------------------------------------------------------------------

func _start_emergence(ppos: Vector2) -> void:
	_origin = e.position
	if phase >= 2: # SURPRISE : une flaque près du joueur, s'il est loin du lac
		var best := -1
		var bd := PUDDLE_REACH_U * U
		var lake_d := ppos.distance_to(_rim_toward(ppos))
		for i in _puddles.size():
			var d := ppos.distance_to(_puddles[i]["pos"])
			if d < bd and d < lake_d - 1.0 * U and d > 1.2 * U:
				bd = d
				best = i
		if best >= 0:
			_origin = _puddles[best]["pos"]
			_puddles[best]["life"] = maxf(float(_puddles[best]["life"]), BossPace.windup(&"charge", phase) + LUNGE_S + 0.5)
			e.position = _origin # tout est la même eau : elle y passe sous le sol
			emerge_from_puddle += 1
			events.append({"kind": &"puddle_emerge", "phase": phase})
	var v := ppos - _origin
	aim = v.normalized() if v.length_squared() > 1.0 else Vector2.from_angle(e._facing)
	_face(aim)
	state = S.EMERGE_WIND
	_dur = BossPace.windup(&"charge", phase)
	pace.wind(&"charge")
	vis.play_attack(&"cast_a", _dur, aim)
	e.telegraph.modulate = Color.WHITE
	_lunge_to = _lunge_end() # un mur coupe la ligne : télégraphe, coup et bond s'y arrêtent
	_emerge_len = maxf(_origin.distance_to(_lunge_to), 1.0 * U)
	e.telegraph.show_line(_origin, aim.angle(), _emerge_len, EMERGE_W_U * U)
	_splash(_origin, 0.6)


func _release_emergence(player: Node2D, ppos: Vector2) -> void:
	e.telegraph.hide_telegraph()
	_log(&"emergence", &"cast_a")
	e._sfx(&"enemy.shockwave.heavy", 3.0, true)
	LightRig.flash(_origin, &"boss_lightning", 0.35, {"color": CRYSTAL, "radius": 1.6})
	_splash(_origin, 1.2)
	var v := ppos - _origin
	if player != null and v.dot(aim) >= -PLAYER_R and v.dot(aim) <= _emerge_len + PLAYER_R and absf(v.cross(aim)) <= EMERGE_W_U * 0.5 * U + PLAYER_R:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"emergence"))
		events.append({"kind": &"emergence_hit", "phase": phase})
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[phase - 1])
	pace.impact(&"charge")
	pace.act() # bond : seul mouvement pendant l'action
	state = S.LUNGE
	_t = 0.0


## Bout du bond : la ligne entière, sauf si un mur la coupe (elle s'échoue au pied du mur, sans le traverser).
func _lunge_end() -> Vector2:
	var end := _origin + aim * EMERGE_LEN_U * U
	if e.nav != null:
		var step := 0.5 * U
		var d := 1.0 * U
		while d <= EMERGE_LEN_U * U:
			var q := _origin + aim * d
			if e.nav.is_blocked_at(q) and not in_water(q): # l'eau du vrai lac est « bloquée » pour les marcheurs
				end = _origin + aim * maxf(d - 0.8 * U, 1.0 * U)
				break
			d += step
	return _walkable(end)


# --- Décharge -----------------------------------------------------------------------------

func _start_discharge() -> void:
	state = S.DISCHARGE
	_dur = BossPace.windup(&"spell", phase)
	pace.wind(&"spell")
	aim = (_ppos - e.position).normalized() if (_ppos - e.position).length_squared() > 1.0 else aim
	_face(aim)
	if e._light != null:
		e._light.set_energy(LIGHT_ENERGY[phase - 1])
	vis.play_attack(&"cast_b", _dur, Vector2.ZERO) # la décharge part d'elle, sur place
	if not is_instance_valid(_ring):
		_ring = RecluseFx.make(RecluseFx.Kind.RING_TELE, Color.RED, 0)
		_ring.name = &"DeepEel_discharge_tele"
		RecluseFx.add_to_tele_layer(_ring, e.get_parent())
	_ring.inner = DISCHARGE_R0_U * U
	_ring.radius = DISCHARGE_R1_U * U
	_ring.progress = 0.0
	_ring.visible = true
	_ring.global_position = e.position
	_ring.queue_redraw()


func _release_discharge(player: Node2D, ppos: Vector2) -> void:
	if is_instance_valid(_ring):
		_ring.visible = false
	_log(&"discharge", &"cast_b")
	e._sfx(&"enemy.shockwave.heavy", 2.0, true)
	LightRig.flash(e.global_position, &"boss_lightning", 0.4, {"color": CRYSTAL, "radius": 2.2})
	_discharge_fx(e.position)
	var d := ppos.distance_to(e.position)
	if player != null and d >= DISCHARGE_R0_U * U - PLAYER_R * 0.5 and d <= DISCHARGE_R1_U * U + PLAYER_R:
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"discharge"))
		_slow(player)
		events.append({"kind": &"discharge_hit", "phase": phase})
	# la décharge projette des flaques d'eau noire hors du lac
	var a0 := _rng.randf() * TAU
	for k in PUDDLES_PER:
		var p := e.position + Vector2.from_angle(a0 + TAU * k / float(PUDDLES_PER)) * _rng.randf_range(4.0, 5.5) * U
		if p.distance_to(center) > pool_r + PUDDLE_R_U * U:
			_add_puddle(_walkable(p))
	pace.strike(&"spell", phase)
	if phase >= 3:
		state = S.ANCHORED
	else:
		_hold_surface(0.0)


func _discharge_fx(p: Vector2) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"discharge_ring"):
		var s := _sprite(&"discharge_ring", Vector2.ONE * (DISCHARGE_R1_U * U / 124.0), Vector2.ZERO, -1, 2.6)
		s.play(&"discharge_ring")
		e.get_parent().add_child(s)
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.RING, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.85), 0)
		f.radius = (DISCHARGE_R0_U + DISCHARGE_R1_U) * 0.5 * U
		f.width = (DISCHARGE_R1_U - DISCHARGE_R0_U) * U * 0.35
		f.color2 = Color(1, 1, 1, 0.9)
		RecluseFx.add_to_tele_layer(f, e.get_parent())
		n = f
	n.name = &"DeepEel_discharge"
	n.global_position = p
	_fx.append({"node": n, "life": 0.35, "max": 0.35})


func _slow(player: Node2D) -> void:
	if player.has_method(&"apply_status"):
		player.apply_status(&"slow", {"hit": 0.0, "source": e})
		slowed += 1


# --- Eau vive (P3) -------------------------------------------------------------------------

## Toute l'eau noire s'électrise : lac et flaques en rouge (remplissage), 1 s.
func _start_live_water() -> void:
	state = S.LIVE_WATER
	_dur = BossPace.windup(&"spell", phase)
	pace.wind(&"spell")
	vis.play_attack(&"cast_b", _dur, Vector2.ZERO)
	var zones: Array[Dictionary] = [{"pos": center, "r": pool_r}]
	for p in _puddles:
		zones.append({"pos": p["pos"], "r": PUDDLE_R_U * U})
	for z in zones:
		var f := RecluseFx.make(RecluseFx.Kind.RING_TELE, Color.RED, 0)
		f.name = &"DeepEel_live_tele"
		f.inner = 0.0
		f.radius = float(z["r"])
		RecluseFx.add_to_tele_layer(f, e.get_parent())
		f.global_position = z["pos"]
		_live.append(f)
	events.append({"kind": &"live_warn", "phase": phase})


func _release_live_water(player: Node2D, ppos: Vector2) -> void:
	_log(&"live_water", &"cast_b")
	e._sfx(&"enemy.shockwave.heavy", 2.0, true)
	for l in _live:
		if is_instance_valid(l):
			_discharge_fx(l.global_position)
			l.queue_free()
	_live.clear()
	LightRig.flash(center, &"boss_lightning", 0.4, {"color": CRYSTAL, "radius": 2.4})
	if player != null and in_water(ppos, PLAYER_R * 0.5):
		e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"live_water"))
		_slow(player)
		events.append({"kind": &"live_water_hit", "phase": phase})
	pace.strike(&"spell", phase)
	state = S.ANCHORED


# --- Fouets (P3) ---------------------------------------------------------------------------

func _build_whips() -> void:
	if not _whips.is_empty():
		return
	_whip_angle = (_ppos - e.position).angle() + PI * 0.5 # jamais sur le joueur à l'échouage
	for j in WHIPS:
		var tele := _tele(j)
		tele.show_line(e.position, 0.0, WHIP_LEN_U * U, WHIP_W_U * U)
		tele.set_progress(1.0)
		tele.modulate = Color(1.0, 1.0, 1.0, WHIP_ALPHA)
		var beam: Node2D
		if _frames != null and _frames.has_animation(&"whip"):
			var s := _sprite(&"whip", Vector2(WHIP_LEN_U * U / 448.0, WHIP_W_U * U / 77.0), Vector2(224.0, 0.0), 0, 2.2)
			s.play(&"whip")
			e.get_parent().add_child(s)
			beam = s
		else:
			var f := RecluseFx.make(RecluseFx.Kind.BEAM, Color(SCALES.r, SCALES.g, SCALES.b, 0.55), 0)
			f.radius = WHIP_LEN_U * U
			f.width = WHIP_W_U * U * 0.5
			f.color2 = Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.9)
			RecluseFx.add_to_tele_layer(f, e.get_parent())
			beam = f
		beam.name = &"DeepEel_whip"
		_whips.append({"tele": tele, "beam": beam})
	events.append({"kind": &"whips", "phase": phase})


func _update_whips(delta: float, player: Node2D, ppos: Vector2) -> void:
	if _whips.is_empty():
		return
	_whip_angle = wrapf(_whip_angle + WHIP_TURN * delta, 0.0, TAU)
	for j in _whips.size():
		var a := _whip_angle + TAU * j / float(WHIPS)
		for k in ["tele", "beam"]:
			var n := _whips[j][k] as Node2D
			if is_instance_valid(n):
				n.global_position = e.position
				n.rotation = a
	_whip_tick -= delta
	if _whip_tick > 0.0 or player == null or state == S.STAGGER:
		return
	var v := ppos - e.position
	for j in WHIPS:
		var d := Vector2.from_angle(_whip_angle + TAU * j / float(WHIPS))
		var along := v.dot(d)
		if along >= 0.0 and along <= WHIP_LEN_U * U + PLAYER_R and absf(v.cross(d)) <= WHIP_W_U * 0.5 * U + PLAYER_R:
			_whip_tick = WHIP_TICK
			e._hit_player(player, e.damage * Balance.boss_attack_coef(ID, &"whip"))
			events.append({"kind": &"whip_hit", "phase": phase})
			return


# --- Visuel -----------------------------------------------------------------------------------

func _build_body() -> void:
	_body = RecluseFx.make(RecluseFx.Kind.BODY_EEL, SCALES, 0)
	_body.name = &"DeepEel_body"
	_body.color2 = CRYSTAL
	_body.radius = 3.8 * U * 0.8
	_body.width = 0.5 * U
	e.add_child(_body)
	vis.self_modulate = Color(1, 1, 1, 0) # hexagone de repli masqué (la silhouette le remplace)


func _build_wake() -> void:
	if _frames != null and _frames.has_animation(&"wake"):
		var s := _sprite(&"wake", Vector2.ONE * WAKE_SCALE, Vector2(-32.0, 0.0), -1, WAKE_ENERGY)
		s.play(&"wake")
		_wake = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.WAKE, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.45), -1)
		f.radius = 0.9 * U
		f.color2 = CRYSTAL
		f.glow = 1.0
		_wake = f
	_wake.name = &"DeepEel_wake"
	e.get_parent().add_child(_wake)


func _update_visual(_delta: float) -> void:
	var sub := _emerge < 0.05
	# sprite livré : visible hors de l'eau seulement ; repli : arche dessinée (sortie = _emerge)
	if vis.body_sprite() != null:
		vis.modulate.a = clampf(_emerge * 1.6, 0.0, 1.0)
	if _body != null:
		var fl := 1.0 if e.is_flashing() else 0.0
		if absf(_body.inner - _emerge) > 0.01 or absf(fl - _body.progress) > 0.01:
			_body.inner = _emerge
			_body.progress = fl
			_body.queue_redraw()
		_body.position = vis.position
		_body.scale.x = -1.0 if cos(e._facing) < 0.0 else 1.0
	if is_instance_valid(_wake):
		_wake.visible = _emerge < 0.7 and not (_wake is AnimatedSprite2D and is_instance_valid(_glow))
		_wake.global_position = e.position
		_wake.rotation = e._facing
		if _wake is AnimatedSprite2D: # sillage C8d : plaque claire atténuée (la lueur porte la position)
			_wake.modulate.a = WAKE_ALPHA if sub else WAKE_ALPHA * 0.5
		else:
			_wake.modulate.a = 1.0 if sub else 0.5
	_update_glow()


## Lueur sous l'eau : halo_soft_256 (rendu Blender livré, AmbianceTextures) étiré dans l'axe du corps, additif et
## unshaded (échappe à l'étalonnage de nuit). Repère de position en plongée, pas une forme de la grammaire
## GroundShapes (aucun tracé : une lueur diffuse, comme le halo de GroundMarker).
func _build_glow() -> void:
	var tex := AmbianceTextures.get_tex(&"halo_soft_256")
	if tex == null:
		return
	_glow = Sprite2D.new()
	_glow.name = &"DeepEel_glow"
	_glow.texture = tex
	_glow.material = _add_mat()
	_glow.z_index = -1
	_glow.light_mask = 0
	e.get_parent().add_child(_glow)
	_glow.position = e.position


static var _mat_add: CanvasItemMaterial = null


static func _add_mat() -> CanvasItemMaterial:
	if _mat_add == null:
		_mat_add = CanvasItemMaterial.new()
		_mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_mat_add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _mat_add


func _update_glow() -> void:
	if not is_instance_valid(_glow):
		return
	var wind := state == S.EMERGE_WIND
	var under := 1.0 if wind else 1.0 - clampf(_emerge / 0.6, 0.0, 1.0)
	_glow.visible = under > 0.02
	if not _glow.visible:
		return
	var k := clampf(_t / maxf(_dur, 0.01), 0.0, 1.0) if wind else 0.0
	var hz := lerpf(1.1, 5.0, k)
	var pulse := 0.85 + 0.15 * sin(_clock * TAU * hz)
	var grow := 1.0 + GLOW_WIND_GROW * k
	_glow.position = _origin if wind else e.position
	_glow.rotation = e._facing
	var tw := float(_glow.texture.get_width())
	_glow.scale = Vector2(GLOW_LEN_U, GLOW_W_U) * U / tw * grow
	var a := clampf(GLOW_ALPHA * under * pulse + 0.15 * k, 0.0, 1.0)
	_glow.modulate = Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, a)


## Remous en plongée : un anneau qui s'élargit et s'efface tous les GLOW_RIPPLE_EVERY_U nagés (ou à l'arrêt).
func _update_ripples(delta: float) -> void:
	_ripple_d += e.position.distance_to(_last_pos)
	_last_pos = e.position
	_ripple_t -= delta
	if _ripple_d < GLOW_RIPPLE_EVERY_U * U and _ripple_t > 0.0:
		return
	_ripple_d = 0.0
	_ripple_t = GLOW_RIPPLE_IDLE_S
	var tex := AmbianceTextures.get_tex(&"light_ring_256")
	if tex == null:
		return
	var r := Sprite2D.new()
	r.name = &"DeepEel_ripple"
	r.texture = tex
	r.material = _add_mat()
	r.z_index = -1
	r.light_mask = 0
	r.modulate = Color(0.75, 0.97, 1.0, 0.7)
	e.get_parent().add_child(r)
	r.position = e.position - Vector2.from_angle(e._facing) * 0.6 * U # derrière la tête
	r.scale = Vector2.ONE * RIPPLE_R0_U * U / RIPPLE_PEAK_PX
	_fx.append({"node": r, "life": RIPPLE_S, "max": RIPPLE_S, "a0": 0.7,
		"r0": RIPPLE_R0_U * U / RIPPLE_PEAK_PX, "r1": RIPPLE_R1_U * U / RIPPLE_PEAK_PX})


func _splash(p: Vector2, r_u: float) -> void:
	var n: Node2D
	if _frames != null and _frames.has_animation(&"emerge_splash"):
		var s := _sprite(&"emerge_splash", Iso.UNSQUASH * Iso.SPRITE_K * r_u, Vector2(0.0, -192.0), 1, 1.8)
		s.play(&"emerge_splash")
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.RING, Color(CRYSTAL.r, CRYSTAL.g, CRYSTAL.b, 0.6), 0)
		f.radius = r_u * U
		f.width = 4.0
		f.color2 = Color(0.9, 0.97, 1.0, 0.8)
		n = f
	n.name = &"DeepEel_splash"
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
			var k := clampf(float(f["life"]) / float(f["max"]), 0.0, 1.0)
			n.modulate.a = k * float(f.get("a0", 1.0))
			if f.has("r1"): # remous : l'anneau s'élargit
				(n as Node2D).scale = Vector2.ONE * lerpf(float(f["r1"]), float(f["r0"]), k)
		i -= 1


# --- Outils ------------------------------------------------------------------------

func _sprite(anim: StringName, sc: Vector2, off: Vector2, z: int, energy: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = StringName("DeepEel_" + String(anim))
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


# --- Trajets et lac ----------------------------------------------------------------------

## Trajet vers `to` qui contourne murs et obstacles dynamiques (NavField.find_path, BFS ponctuel) ; sans
## champ : ligne droite.
func _route_to(to: Vector2) -> void:
	_route = e.nav.find_path(e.position, to, ROUTE_REACH_U * U) if e.nav != null else PackedVector2Array()
	if _route.is_empty():
		_route = PackedVector2Array([to])
	_route_i = 0


## Avance le long du trajet à `speed_px` ; vrai à l'arrivée (dernier point atteint).
func _follow_route(speed_px: float, delta: float) -> bool:
	var budget := speed_px * delta
	while _route_i < _route.size():
		var wp := _route[_route_i]
		var d := e.position.distance_to(wp)
		if d > budget:
			e.position = e.position.move_toward(wp, budget)
			return false
		e.position = wp
		budget -= d
		_route_i += 1
	return true


func _route_dir() -> Vector2:
	return _route[_route_i] - e.position if _route_i < _route.size() else Vector2.ZERO


## Centre du lac : sur le VRAI lac de la carte (cases « ~ » de data/maps/<id>.json) si sa rive est assez près de
## la zone de charge (pilier = position d'apparition, rive <= BIG_ZONE_RADIUS + LAKE_REACH_U) et joignable à pied
## depuis le pilier (NavField.find_path) ; le disque (l'effondrement) est alors centré sur la rive, juste dans
## l'eau profonde : le vrai lac le prolonge côté eau, sa moitié côté pilier se joue à pied (morsures au bord).
## Sinon (carte sans lac, lac trop loin ou muré, arène de test) : près du pilier, comme avant.
func _pick_lake_center() -> Vector2:
	var fallback := _walkable(e.position + Vector2(POOL_SHIFT_U * U, 0.0))
	var shore := _map_lake_shore(e.position)
	if shore.is_empty():
		lake_source = &"pillar"
		return fallback
	lake_source = &"map"
	var s: Vector2 = shore["shore"]
	var dir_in: Vector2 = shore["dir_in"]
	return s + dir_in * LAKE_CENTER_IN_U * U


## {shore: point de rive le plus proche du pilier (logique, repère du parent), dir_in: vers l'eau}, vide sinon.
func _map_lake_shore(pillar: Vector2) -> Dictionary:
	var dir_node: Node = e.director
	if dir_node == null or not dir_node.has_method(&"get_map") or e.nav == null:
		return {}
	var map := dir_node.call(&"get_map") as Node2D
	if map == null or not is_instance_valid(map) or not map.has_meta(&"map_id"):
		return {}
	var path := "res://data/maps/%s.json" % String(map.get_meta(&"map_id"))
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not (data as Dictionary).has("grid"):
		return {}
	var grid: Array = data["grid"]
	var gcu := float(data.get("grid_cell_u", 2))
	var size_u := Vector2(data["size_u"][0], data["size_u"][1]) if data.has("size_u") else Vector2.ZERO
	var host := e.get_parent() as Node2D
	var best_d := INF
	var best := Vector2.ZERO
	var best_in := Vector2.ZERO
	for y in grid.size():
		var row := String(grid[y])
		for x in row.length():
			if row[x] != "~":
				continue
			var pm := (Vector2(x + 0.5, y + 0.5) * gcu - size_u * 0.5) * U # repère carte, origine au centre
			var lp: Vector2 = map.call(&"from_map", pm) if map.has_method(&"from_map") else pm
			var g: Vector2 = map.global_transform * lp
			var p: Vector2 = host.to_local(g) if host != null else g
			var d := p.distance_to(pillar)
			if d < best_d:
				best_d = d
				best = p
				best_in = (p - pillar).normalized() if d > 1.0 else Vector2.RIGHT
	if best_d == INF:
		return {}
	var shore := best - best_in * gcu * 0.5 * U # bord de la case d'eau profonde côté pilier
	var straight := pillar.distance_to(shore)
	if straight > Pillar.BIG_ZONE_RADIUS + LAKE_REACH_U * U:
		return {}
	var route := e.nav.find_path(pillar, shore, ROUTE_REACH_U * U)
	if route.size() < 1:
		return {}
	var last := route[route.size() - 2] if route.size() >= 2 else pillar
	if last.distance_to(shore) > ROUTE_REACH_U * U + 8.0:
		return {} # muré : le chemin n'atteint pas la rive
	var walked := 0.0
	var prev := pillar
	for q in route:
		walked += prev.distance_to(q)
		prev = q
	if walked > straight * LAKE_PATH_SLACK + 2.0 * U:
		return {}
	return {"shore": shore, "dir_in": best_in}


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
