class_name FloodGunnerBrain
extends RefCounted
## IA du Canonnier de crue (boss d'étage 3, Cité de rouille ; docs/Design_Boss_Raid.md §2.2). Même contrat que
## SmelterBrain / CraneBrain (duck typing : tick, owns_motion, clear, damage_taken_mult, is_invulnerable,
## boss_state_tag). Construit sur la boîte à outils scripts/enemies/raid/ : BossShield (rupture par KILL_ADDS),
## ShelterPylon (abris), BarrageEmitter (Mitraille), PriorityAdds (soutiers), SoftEnrage.
## Coups télégraphés face au joueur, dégâts à la frame d'impact (fin de l'armement BossPace). Sans sprite :
## silhouette provisoire (tripode en Polygon2D) ; les anims du .tres (auto/spell_a/spell_b/shell/shield/vent/
## trans_pN, voir art/tools/night/_raid_flood_gunner.txt) la remplacent sans toucher au code.
##
## Phases (PV ; seuils 70 / 35 %, définis ici : Balance.BOSS_PHASE_THRESHOLDS n'a pas d'entrée) :
## - P1 « Salve » : Culasse (rivet lourd) ; Pylônes x3 puis, 2,5 s plus tard, Mitraille balayante 5 s (éventail 120°).
## - Transition « Surchauffe » : bouclier KILL_ADDS 2 soutiers (+10 % PV du boss s'ils arrivent) ; purge 3 s.
## - P2 « Rafale » : Pylônes x4, Mitraille tournante (2 cônes de 60°, 45°/s, 6 s), Obus (casse un pylône une fois sur deux).
## - Transition « Chaudière crevée » : bouclier 3 soutiers (+8 %) ; purge 3 s.
## - P3 « Déluge de fer » : ancré (immobile, +20 % de dégâts reçus), Culasse x2 (±15°), Pylônes x3 / 10 s,
##   Mitraille continue (2 cônes de 60°, 20°/s, rechargement 2 s toutes les 8 s), Obus toutes les 5 s.
## Trace : à la mort les pylônes restent (abris contre les tireurs) jusqu'à la fin de leur vie.

enum S { CHASE, BREECH, PLANT, VOLLEY, SHELL, STAGGER }

const ID := &"flood_gunner"
const U := 64.0
const SODIUM := Color(1.0, 0.604, 0.235) ## #FF9A3C : seul accent émissif
const RUST := Color(0.55, 0.30, 0.20) ## silhouette provisoire, assez claire pour la nuit
const THRESHOLDS := [0.70, 0.35]
## Coefs de repli si Balance.BOSS_ATTACK_COEF n'a pas (encore) d'entrée flood_gunner.
const COEF := {&"breech": 1.0, &"pylon_drop": 0.8, &"shell": 1.6}
const AUTO_CD := 2.0
const SHIELD_BREECH_CD := 3.0 ## sous bouclier : Culasse seulement, toutes les 3 s
const BREECH_SPEED_U := 11.0
const BREECH_LEN_U := 8.0
const BREECH_W_U := 1.0
const BREECH_SPLIT := 0.262 ## 15° (P3 : deux rivets)
const WINDUP_MIN := 0.8 ## règle 1 : aucun télégraphe sous 0,8 s
const KEEP_DIST_U := 8.0 ## s'arrête à cette distance du joueur (artilleur)
const PLANT_COUNT := [3, 4, 3]
const PLANT_DIST_U := 5.0
const PLANT_SETTLE_S := 2.5 ## Pylônes -> Mitraille : délai garanti
const P3_PLANT_EVERY := 10.0
const VOLLEY_CD := 14.0
const VOLLEY_FIRST := 2.0
const SHELL_R_U := 3.0
const SHELL_WINDUP := 1.2
const SHELL_EVERY := [0.0, 8.0, 5.0]
const SHELL_FIRST := 3.5
const ANCHOR_TAKEN := 1.2 ## P3 : +20 % de dégâts reçus
const SHIELD_ADDS := [0, 2, 3]
const SHIELD_ADD_HP := [0.0, 0.07, 0.06]
const SHIELD_ADD_HEAL := [0.0, 0.10, 0.08]
const SHIELD_ADD_RING_U := 12.0 ## apparition loin du boss : le temps de les tuer (2 u/s)
const SHIELD_EXPOSED_S := 3.0 ## purge de vapeur

var e: Enemy
var vis: EnemyVisual
var events: Array[Dictionary] = []
var pace: BossPace
var shield: BossShield
var enrage: SoftEnrage
var pylons: ShelterPylon
var barrage: BarrageEmitter
var phase := 1
var state := S.CHASE
var aim := Vector2.RIGHT
var plants := 0 ## Pylônes posés (tests)
var shells := 0 ## Obus tombés (tests)
var shell_pylon_hits := 0 ## Obus tombés sur un pylône (tests)
var breech_shots := 0

var _t := 0.0
var _dur := 0.0
var _clock := 0.0
var _plant_t := -100.0
var _attack_cd := 1.4
var _volley_cd := VOLLEY_FIRST
var _pylon_cd := 0.0
var _shell_cd := 0.0
var _shell_n := 0
var _volley_base := 0.0
var _volley_sweep := false
var _in_volley := false
var _shell_at := Vector2.ZERO
var _shell_on_pylon := false
var _ppos := Vector2.ZERO
var _killed := false
var _body: Node2D = null
var _light_on := false


func _init(enemy: Enemy) -> void:
	e = enemy
	vis = enemy.visual as EnemyVisual
	pace = BossPace.new(enemy)
	shield = BossShield.create(e)
	enrage = SoftEnrage.create(e)
	var world := e.get_parent()
	if world != null:
		pylons = ShelterPylon.create(e)
		barrage = BarrageEmitter.create(e, pylons)
		barrage.ended.connect(_on_barrage_ended)
	if e._light != null:
		e._light.set_color(SODIUM)
		_light_on = true
	if vis.body_sprite() == null:
		_build_body()


func clear() -> void:
	_killed = e != null and is_instance_valid(e) and e.hp <= 0.0
	if pace != null:
		pace.cancel()
	if shield != null:
		shield.clear()
	if enrage != null:
		enrage.clear()
	if barrage != null and is_instance_valid(barrage):
		barrage.release()
	barrage = null
	if pylons != null and is_instance_valid(pylons):
		if not _killed:
			pylons.release()
		# mort : les pylônes restent (abris) jusqu'à la fin de leur vie, puis ils se libèrent seuls
	pylons = null
	if is_instance_valid(_body):
		_body.queue_free()
	_body = null
	if e != null and is_instance_valid(e):
		if is_instance_valid(e.telegraph):
			e.telegraph.hide_telegraph()
			e.telegraph.modulate = Color.WHITE
		if _light_on and e._light != null:
			e._light.set_color(Color(0, 0, 0, 0))


# --- Contrat boss (duck typing lu par Enemy) -------------------------------------------

func phase_thresholds() -> Array:
	return THRESHOLDS


func is_invulnerable() -> bool:
	return shield != null and shield.is_invulnerable()


func damage_taken_mult() -> float:
	var m := ANCHOR_TAKEN if phase >= 3 else 1.0
	return m * (shield.damage_taken_mult() if shield != null else 1.0)


func is_phase_transition() -> bool:
	return state == S.STAGGER


func owns_motion() -> bool:
	return state == S.STAGGER or pace.planted() or phase >= 3 or shield.is_busy() or _in_volley


func ignores_knockback() -> bool:
	return pace.planted() or phase >= 3 or shield.is_busy()


## Étiquette de barre : bouclier / exposé, sinon RECHARGE (P3), sinon enrage.
func boss_state_tag() -> Dictionary:
	var tag := shield.state_tag()
	if not tag.is_empty():
		return tag
	if _reloading():
		return {"text": "RECHARGE", "color": RaidFx.WARM, "kind": &"reload", "progress": _reload_progress()}
	return enrage.state_tag()


func _reloading() -> bool:
	if barrage == null or not barrage.is_firing() or barrage.reload_every_s <= 0.0:
		return false
	return fmod(barrage.t, barrage.reload_every_s + barrage.reload_s) >= barrage.reload_every_s


func _reload_progress() -> float:
	return clampf((fmod(barrage.t, barrage.reload_every_s + barrage.reload_s) - barrage.reload_every_s) / maxf(barrage.reload_s, 0.01), 0.0, 1.0)


func tick(delta: float, player: Node2D, ppos: Vector2, dir: Vector2, dist: float, path_dir: Vector2) -> Vector2:
	_ppos = ppos
	_clock += delta
	pace.tick(delta)
	enrage.tick(delta, shield.freezes_enrage()) # APRÈS Enemy.fight_time += delta (Enemy.tick le fait avant)
	shield.tick(delta)
	var ph := _phase_for(e.hp / maxf(e.max_hp, 1.0))
	if ph > phase:
		_enter_phase(ph)
	_attack_cd -= delta
	_volley_cd -= delta
	_pylon_cd -= delta
	_shell_cd -= delta
	_t += delta
	_update_volley()
	match state:
		S.STAGGER:
			if _t >= _dur and shield.state != BossShield.State.TRANSITION:
				state = S.CHASE
			return Vector2.ZERO
		S.BREECH:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_breech()
			return Vector2.ZERO
		S.PLANT:
			if _t >= _dur:
				_resolve_plant()
			return Vector2.ZERO
		S.SHELL:
			e.telegraph.set_progress(_t / _dur)
			if _t >= _dur:
				_resolve_shell(player)
			return Vector2.ZERO
		S.VOLLEY:
			_face(dir)
			if barrage == null or not barrage.is_busy():
				_end_volley()
			return Vector2.ZERO
	if pace.recovering():
		_face(dir)
		return Vector2.ZERO
	if vis.is_attacking():
		_face(dir)
		return Vector2.ZERO
	if shield.is_busy():
		_face(dir)
		if shield.state == BossShield.State.ACTIVE and _attack_cd <= 0.0:
			_start_breech(dir) # seul coup permis sous bouclier
		return Vector2.ZERO
	if _try_spells(dir, ppos):
		return Vector2.ZERO
	if _attack_cd <= 0.0 and dist < (BREECH_LEN_U + 2.0) * U:
		_start_breech(dir)
		return Vector2.ZERO
	if phase < 3 and dist > KEEP_DIST_U * U:
		var go := path_dir if path_dir != Vector2.ZERO else dir
		_face(go)
		return go * e.speed_px
	_face(dir)
	return Vector2.ZERO


# --- Phases ----------------------------------------------------------------------------

func _phase_for(frac: float) -> int:
	return 3 if frac <= float(THRESHOLDS[1]) else (2 if frac <= float(THRESHOLDS[0]) else 1)


func _enter_phase(ph: int) -> void:
	var prev := phase
	phase = ph
	pace.cancel()
	e.telegraph.hide_telegraph()
	e.telegraph.modulate = Color.WHITE
	if barrage != null and barrage.is_busy():
		barrage.stop()
	_in_volley = false
	state = S.STAGGER
	_t = 0.0
	_dur = 8.0 / 12.0 + 0.2
	if BossShield.should_arm(prev, ph, shield.armed_count, ID):
		var n: int = SHIELD_ADDS[ph - 1]
		shield.arm([{"kind": &"kill_adds", "count": n, "add_hp_frac": SHIELD_ADD_HP[ph - 1],
			"heal_frac": SHIELD_ADD_HEAL[ph - 1], "walk_u": 2.0, "ring_u": SHIELD_ADD_RING_U, "prefix": &"stoker_",
			"label": "SOUTIERS"}], {"exposed_s": SHIELD_EXPOSED_S})
		e._sfx(&"enemy.gunner_shield_up.heavy", 2.0, true)
	if ph >= 3:
		e._sfx(&"enemy.gunner_anchor.heavy", 2.0, true)
	e._sfx(&"telegraph.boss.heavy", 2.0, true)
	_volley_cd = maxf(_volley_cd, _dur + 3.0)
	_attack_cd = maxf(_attack_cd, _dur + 0.6)
	_shell_cd = _dur + SHELL_FIRST if ph >= 2 else 99.0
	_pylon_cd = _dur + 1.0
	events.append({"kind": &"phase", "phase": ph})


func _face(d: Vector2) -> void:
	if d.length_squared() > 0.0001:
		e._facing = d.angle()
		vis.set_facing(e._facing)


# --- Culasse (auto) ----------------------------------------------------------------------

func _coef(k: StringName) -> float:
	return float((Balance.BOSS_ATTACK_COEF.get(ID, COEF) as Dictionary).get(k, COEF.get(k, 1.0)))


func _start_breech(dir: Vector2) -> void:
	_attack_cd = SHIELD_BREECH_CD if shield.is_busy() else AUTO_CD
	aim = dir
	_face(aim)
	state = S.BREECH
	_t = 0.0
	_dur = BossPace.windup(&"auto", phase, WINDUP_MIN)
	pace.wind(&"auto")
	vis.play_attack(&"attack", _dur, aim)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_line(e.position, aim.angle(), BREECH_LEN_U * U, BREECH_W_U * U)
	e._sfx(&"telegraph.warn_light.light", -4.0)


func _resolve_breech() -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.gunner_breech.medium", 0.0, true)
	var dmg := e.current_damage() * _coef(&"breech")
	var angles: Array[float] = [aim.angle()]
	if phase >= 3 and not shield.is_busy():
		angles = [aim.angle() - BREECH_SPLIT, aim.angle() + BREECH_SPLIT]
	for a in angles:
		var d := Vector2.from_angle(a)
		if e.director != null and e.director.has_method(&"fire_projectile"):
			e.director.fire_projectile(e, e.position + d * e.radius_px, d * BREECH_SPEED_U * U, dmg)
	breech_shots += 1
	events.append({"kind": &"breech", "phase": phase, "shots": angles.size()})
	pace.strike(&"auto", phase)
	state = S.CHASE


# --- Sorts ---------------------------------------------------------------------------------

func _pylon_total() -> int:
	return pylons.pylons.size() if pylons != null else 0


func _pylon_live() -> int:
	return pylons.live_count() if pylons != null else 0


## Choisit le sort dû ; vrai si un sort démarre. Mitraille : toujours après des pylônes debout depuis >= 2,5 s.
func _try_spells(dir: Vector2, ppos: Vector2) -> bool:
	if pylons == null or barrage == null:
		return false
	if phase >= 2 and _shell_cd <= 0.0:
		_start_shell(dir, ppos)
		return true
	if phase < 3:
		if _volley_cd <= 0.0:
			if _pylon_live() >= Balance.RAID_BARRAGE_MIN_PYLONS and _clock - _plant_t >= PLANT_SETTLE_S:
				_start_volley(dir)
				return true
			if _pylon_total() < Balance.RAID_BARRAGE_MIN_PYLONS:
				_start_plant(dir)
				return true
		return false
	# P3 : pylônes toutes les 10 s (ou tout de suite s'il n'en reste pas assez), Mitraille continue
	if _pylon_cd <= 0.0 or _pylon_total() < Balance.RAID_BARRAGE_MIN_PYLONS:
		_start_plant(dir)
		return true
	if not barrage.is_busy() and _volley_cd <= 0.0 and _pylon_live() >= Balance.RAID_BARRAGE_MIN_PYLONS \
			and _clock - _plant_t >= PLANT_SETTLE_S:
		_start_volley(dir)
		return false # la Mitraille continue ne bloque pas le boss
	return false


func _start_plant(dir: Vector2) -> void:
	aim = dir
	_face(aim)
	state = S.PLANT
	_t = 0.0
	_dur = BossPace.windup(&"spell", phase, WINDUP_MIN)
	pace.wind(&"spell")
	vis.play_attack(&"cast_a", _dur, Vector2.ZERO)
	e._sfx(&"enemy.gunner_pylon_plant.medium", 0.0, true)


func _resolve_plant() -> void:
	var n: int = PLANT_COUNT[phase - 1]
	pylons.plant_around(_ppos, n, PLANT_DIST_U, randf() * TAU)
	plants += n
	_plant_t = _clock
	_pylon_cd = P3_PLANT_EVERY
	events.append({"kind": &"plant", "phase": phase, "count": n})
	pace.strike(&"spell", phase)
	state = S.CHASE


func _volley_opts() -> Dictionary:
	match phase:
		1:
			return {"rate": 24.0, "duration_s": 5.0, "arc_deg": 120.0, "cones": 1, "turn_deg_s": 0.0, "speed_u": 9.0}
		2:
			return {"rate": 24.0, "duration_s": 6.0, "arc_deg": 60.0, "cones": 2, "turn_deg_s": 45.0, "speed_u": 9.0}
	return {"rate": 24.0, "duration_s": 100000.0, "arc_deg": 60.0, "cones": 2, "turn_deg_s": 20.0, "speed_u": 9.0,
		"reload_every_s": 8.0, "reload_s": 2.0}


func _start_volley(dir: Vector2) -> void:
	aim = dir
	_face(aim)
	_volley_base = dir.angle()
	_volley_sweep = phase == 1
	if not barrage.start(_volley_base, _volley_opts()):
		_volley_cd = 1.0
		return
	_volley_cd = 99.0 # relancé par _on_barrage_ended
	events.append({"kind": &"volley", "phase": phase})
	if phase < 3:
		_in_volley = true
		state = S.VOLLEY
		_t = 0.0
		pace.wind(&"spell")
		vis.play_attack(&"cast_b", barrage.telegraph_s, aim)
		e._sfx(&"enemy.gunner_volley_warn.heavy", 0.0, true)


## P1 : l'éventail balaie ±30° autour de la visée de départ (période de la salve).
func _update_volley() -> void:
	if barrage == null or not _volley_sweep or not barrage.is_busy():
		return
	barrage.aim = _volley_base + deg_to_rad(30.0) * sin(TAU * barrage.t / 5.0)


func _on_barrage_ended(_b: BarrageEmitter) -> void:
	_volley_cd = VOLLEY_CD if phase < 3 else 1.0
	_volley_sweep = false


func _end_volley() -> void:
	_in_volley = false
	pace.strike(&"spell", phase)
	state = S.CHASE


func _start_shell(dir: Vector2, ppos: Vector2) -> void:
	_shell_n += 1
	_shell_cd = SHELL_EVERY[phase - 1]
	_attack_cd = maxf(_attack_cd, 0.6)
	aim = dir
	_face(aim)
	_shell_on_pylon = false
	_shell_at = ppos
	# une fois sur deux, vise le pylône le plus proche du joueur (change d'abri)
	if _shell_n % 2 == 0 and pylons != null:
		var best := INF
		for p in pylons.positions():
			var d := p.distance_to(ppos)
			if d < best:
				best = d
				_shell_at = p
				_shell_on_pylon = true
	state = S.SHELL
	_t = 0.0
	_dur = BossPace.windup(&"spell", phase, SHELL_WINDUP)
	pace.wind(&"spell")
	vis.play_attack(&"cast_b", _dur, Vector2.ZERO)
	e.telegraph.modulate = Color.WHITE
	e.telegraph.show_circle(_shell_at, SHELL_R_U * U)
	e._sfx(&"enemy.gunner_shell_whistle.medium", 0.0, true)


func _resolve_shell(player: Node2D) -> void:
	e.telegraph.hide_telegraph()
	e._sfx(&"enemy.gunner_shell.heavy", 2.0, true)
	shells += 1
	if player != null and player.global_position.distance_to(_shell_at) <= SHELL_R_U * U + PlayerHitbox.radius_px:
		e._hit_player(player, e.damage * _coef(&"shell"))
		events.append({"kind": &"shell_hit", "phase": phase})
	if pylons != null:
		var before := pylons.pylons.size()
		pylons.damage_at(_shell_at, 1.0e9, SHELL_R_U * U)
		if pylons.pylons.size() < before:
			shell_pylon_hits += 1
	events.append({"kind": &"shell", "phase": phase, "on_pylon": _shell_on_pylon})
	pace.strike(&"spell", phase)
	state = S.CHASE


# --- Visuel provisoire -----------------------------------------------------------------------

func _build_body() -> void:
	_body = Node2D.new()
	_body.name = &"FloodGunner_body"
	e.add_child(_body)
	_body.position = Vector2(0.0, -1.2 * U * Iso.UNSQUASH.y)
	var legs := Polygon2D.new()
	legs.color = RUST
	legs.polygon = _poly([Vector2(-1.8, 1.0), Vector2(0, -0.6), Vector2(1.8, 1.0), Vector2(0, 0.4)])
	_body.add_child(legs)
	var drum := Polygon2D.new()
	drum.color = RUST.lightened(0.15)
	drum.polygon = _poly([Vector2(-0.9, -1.4), Vector2(0.9, -1.4), Vector2(1.0, 0.1), Vector2(-1.0, 0.1)])
	_body.add_child(drum)
	var eye := Polygon2D.new()
	eye.color = SODIUM
	eye.polygon = _poly([Vector2(-0.25, -1.1), Vector2(0.25, -1.1), Vector2(0.25, -0.7), Vector2(-0.25, -0.7)])
	_body.add_child(eye)


static func _poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append((p as Vector2) * U)
	return out
