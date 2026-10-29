class_name SlideDodge
extends DodgeMove
## Glissade (esquive d'Averse, docs/Design_Esquives.md §Averse) : esquive AU MAINTIEN. Le kit paie la ressource
## (eau) ; tant que le bouton est tenu et que le kit accepte le drain, elle glisse à `slide_speed_u` u/s, dirigée en
## continu par le joystick (virage SLIDE_TURN_DEG_S max), cap gardé sans entrée. Relâcher, réservoir vide ou mur de
## face = fin. Invulnérable SLIDE_IFRAME_S au départ seulement ; pendant la glisse, les coups de contact sont ignorés
## par le kit (`ignores_hit`), les projectiles et zones touchent. Recharge = verrou court SLIDE_RELAUNCH_S.
##
## Hooks du kit : `slide_speed_u()`, `slide_can_start()`, `slide_begin()` (paie le départ), `slide_drain(delta) -> bool`
## (faux = réservoir vide : arrêt), `slide_end(stopped_by_wall)`, `slide_trail(from, to)` (trace d'eau au sol).

const SLIDE_IFRAME_S := 0.15
const SLIDE_MIN_S := 0.15 ## un tap donne au moins ce temps de glisse (coup sec)
const SLIDE_RELAUNCH_S := 0.5 ## verrou après l'arrêt : pas de spam d'i-frames
const SLIDE_TURN_DEG_S := 200.0
const WALL_STOP_DOT := -0.7 ## normale de collision contre le cap : mur de face, la glisse bute

var elapsed := 0.0
var released := false


func kind() -> StringName:
	return KIND_SLIDE


func label() -> String:
	if kit != null and kit.has_method(&"dodge_label"):
		return str(kit.dodge_label())
	return "Glissade"


func is_hold() -> bool:
	return true


func can_start() -> bool:
	if active or cooldown_left > 0.0:
		return false
	return _hook_bool(&"slide_can_start", true)


func speed_u() -> float:
	return _hook_float(&"slide_speed_u", 9.0)


## Durée à l'infini (tenue) : pour l'UI, la durée minimale.
func duration_s() -> float:
	return SLIDE_MIN_S


func distance_u() -> float:
	return speed_u() * SLIDE_MIN_S


func start(d: Vector2) -> bool:
	if not can_start():
		return false
	if kit != null and kit.has_method(&"slide_begin") and not bool(kit.slide_begin()):
		return false
	dir = _motion_dir(d)
	player.facing = dir
	start_pos = player.global_position
	active = true
	released = false
	elapsed = 0.0
	invuln_left = SLIDE_IFRAME_S
	_play_sound()
	_on_start_hook(d)
	return true


func release() -> void:
	released = true


func step(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	player.is_moving = true
	player.velocity = Vector2.ZERO
	# virage continu vers le joystick ; sans entrée, cap gardé
	var want := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if want.length_squared() > 0.0001:
		var max_turn := deg_to_rad(SLIDE_TURN_DEG_S) * delta
		dir = dir.rotated(clampf(dir.angle_to(want.normalized()), -max_turn, max_turn)).normalized()
		player.facing = dir
	var from := player.global_position
	var col := _sweep(dir * speed_u() * Balance.UNIT_PX * delta)
	if kit != null and kit.has_method(&"slide_trail"):
		kit.slide_trail(from, player.global_position)
	var wall := col != null and col.get_normal().dot(dir) < WALL_STOP_DOT
	var dry := kit != null and kit.has_method(&"slide_drain") and not bool(kit.slide_drain(delta))
	if wall or dry or (released and elapsed >= SLIDE_MIN_S):
		_stop(wall)


func _stop(by_wall: bool) -> void:
	active = false
	cooldown_left = SLIDE_RELAUNCH_S
	if kit != null and kit.has_method(&"slide_end"):
		kit.slide_end(by_wall)
	_on_end_hook()


func progress_left() -> float:
	return 1.0 if active else 0.0


func ui_state() -> Dictionary:
	var d := super.ui_state()
	d["total"] = SLIDE_RELAUNCH_S
	return d


func reset() -> void:
	if active:
		_stop(false)
	super.reset()
