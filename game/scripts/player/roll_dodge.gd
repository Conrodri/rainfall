class_name RollDodge
extends DodgeMove
## Roulade (esquive par défaut, Balance.DODGE_*) : dash à vitesse constante, invulnérable toute sa durée,
## bloqué par les murs (glissement le long), aucune collision avec les monstres (masque monde seulement).
## Paramètres par kit : distance (`dodge_distance_u()` / CharacterData.dodge_distance_u), vitesse (`dodge_speed_u()`,
## Avare et Bourbe 10 u/s), charges (`dodge_charges()`, Vigie 3 petits dashs : une charge se régénère à la fois en
## `cooldown / charges` s), fantômes du sprite (`dodge_ghosts()`, teinte `dodge_ghost_color()`).
## Une roulade à plusieurs charges peut repartir pendant la précédente (nouvelle direction, enchaînement).

const GHOST_EVERY_S := 0.04
const GHOST_COLOR := Color(1.0, 0.72, 0.45, 0.5)

var charges := 1
var max_charges := 1
var charge_regen_left := 0.0
var left := 0.0
var total := Balance.DODGE_DURATION_S
var speed_px := Balance.DODGE_DISTANCE_U * Balance.UNIT_PX / Balance.DODGE_DURATION_S
var _ghost_t := 0.0


func setup(p: CharacterBody2D, k: Node) -> void:
	super.setup(p, k)
	max_charges = maxi(int(_hook_float(&"dodge_charges", 1.0)), 1)
	charges = max_charges


func can_start() -> bool:
	if max_charges > 1:
		return charges > 0
	return not active and cooldown_left <= 0.0


func distance_u() -> float:
	return player.dodge_distance_u()


func speed_u() -> float:
	return _hook_float(&"dodge_speed_u", Balance.DODGE_DISTANCE_U / Balance.DODGE_DURATION_S)


func start(d: Vector2) -> bool:
	if not can_start():
		return false
	if active: # enchaînement (charges) : la roulade en cours est reprise dans la nouvelle direction
		_on_end_hook()
	dir = _motion_dir(d)
	player.facing = dir
	start_pos = player.global_position
	var dist := maxf(distance_u(), 0.05)
	speed_px = maxf(speed_u(), 0.1) * Balance.UNIT_PX
	total = dist * Balance.UNIT_PX / speed_px
	left = total
	invuln_left = total
	active = true
	_ghost_t = 0.0
	if max_charges > 1:
		charges -= 1
		if charge_regen_left <= 0.0:
			charge_regen_left = charge_cooldown_s()
	else:
		cooldown_left = cooldown_total
	_play_sound()
	_on_start_hook(d)
	return true


## Recharge d'une charge (une à la fois) : la recharge totale répartie sur les charges.
func charge_cooldown_s() -> float:
	return cooldown_total / max_charges


func step(delta: float) -> void:
	if not active:
		return
	var s := minf(delta, left)
	left -= delta
	player.is_moving = true
	player.velocity = Vector2.ZERO
	_sweep(dir * speed_px * s)
	_ghost_t -= delta
	if _ghost_t <= 0.0 and _hook_bool(&"dodge_ghosts", true):
		_ghost_t = GHOST_EVERY_S
		var c := GHOST_COLOR
		if kit != null and kit.has_method(&"dodge_ghost_color"):
			c = kit.dodge_ghost_color()
		player.spawn_dodge_ghost(c)
	if left <= 0.0:
		active = false
		_on_end_hook()


func tick(delta: float) -> void:
	super.tick(delta)
	if max_charges > 1:
		if TestMode.cdr_full:
			charges = max_charges
			charge_regen_left = 0.0
		elif charges < max_charges:
			charge_regen_left -= delta
			if charge_regen_left <= 0.0:
				charges += 1
				charge_regen_left = charge_cooldown_s() if charges < max_charges else 0.0


func progress_left() -> float:
	return clampf(left / maxf(total, 0.001), 0.0, 1.0) if active else 0.0


func duration_s() -> float:
	return total


func ui_state() -> Dictionary:
	var d := super.ui_state()
	if max_charges > 1:
		d["charges"] = charges
		d["max_charges"] = max_charges
		d["remaining"] = charge_regen_left if charges < max_charges else 0.0
		d["total"] = charge_cooldown_s()
	return d


func reset() -> void:
	super.reset()
	left = 0.0
	charges = max_charges
	charge_regen_left = 0.0
