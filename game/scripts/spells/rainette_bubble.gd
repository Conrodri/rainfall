class_name RainetteBubble
extends Node2D
## Bulle de Rainette (variante du Gluant, docs/Variantes_Sorts.md §2.6) : gobe les non-boss du point visé
## (statut `imprisoned`, soulevés, attirés vers le centre), ralentit les boss, puis éclate : coup de zone.
## Visuel : placeholder dessiné (bulle translucide jade) en attendant `goo_bubble` (lot Codex).

static var live: Array[RainetteBubble] = []

const LIFT_U := 0.8
const RISE_S := 0.2 ## montée des monstres
const FILL := Color(0.55, 0.73, 0.66, 0.16)

var caster: SpellCaster = null
var spell: SpellData = null
var catch_px := 160.0
var burst_px := 128.0
var life := 1.5
var pull_px_s := 42.0
var boss_slow := 0.4
var held: Array = [] ## {e, y0}
var burst_done := false
var caught := 0 ## monstres soulevés (tests)
var _t := 0.0


func setup(p_caster: SpellCaster, s: SpellData, catch_radius_px: float, burst_radius_px: float, hold_s: float,
		p_pull_px_s: float, p_boss_slow: float) -> void:
	caster = p_caster
	spell = s
	catch_px = catch_radius_px
	burst_px = burst_radius_px
	life = hold_s
	pull_px_s = p_pull_px_s
	boss_slow = p_boss_slow


func _ready() -> void:
	z_index = 1
	live.append(self)


func _exit_tree() -> void:
	live.erase(self)
	_release()


static func clear_all() -> void:
	for b in live.duplicate():
		if is_instance_valid(b):
			b.queue_free()
	live.clear()


## Gobe les monstres du point d'éclatement (appelé par le kit une fois la bulle posée).
func capture() -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or (e as Node2D).global_position.distance_to(global_position) > catch_px:
			continue
		if e.get(&"is_boss") == true:
			if e.has_method(&"apply_status"):
				e.apply_status(&"slow", {"pct": boss_slow, "duration": life})
			continue
		if e.has_method(&"imprison"):
			e.imprison(life + 0.1)
		elif e.has_method(&"apply_status"):
			e.apply_status(&"imprisoned", {"duration": life + 0.1})
		var vis: Variant = e.get(&"visual")
		held.append({"e": e, "y0": (vis as Node2D).position.y if vis is Node2D else 0.0})
		caught += 1


func _physics_process(delta: float) -> void:
	step(delta)


## Public pour les tests sans boucle physique.
func step(delta: float) -> void:
	if burst_done:
		return
	_t += delta
	var h := LIFT_U * clampf(_t / RISE_S, 0.0, 1.0)
	for d in held:
		var e: Variant = d["e"]
		if not is_instance_valid(e) or (&"active" in e and not bool(e.get(&"active"))):
			continue
		var pos: Vector2 = (e as Node2D).global_position
		var np := pos.move_toward(global_position, pull_px_s * delta)
		if e.has_method(&"hold_at"):
			e.hold_at(np)
		else:
			(e as Node2D).global_position = np
		var vis: Variant = e.get(&"visual")
		if vis is Node2D:
			(vis as Node2D).position.y = float(d["y0"]) + Iso.lift_logical(h)
	queue_redraw()
	if _t >= life:
		_burst()


func _burst() -> void:
	burst_done = true
	if caster != null and is_instance_valid(caster):
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e is Node2D and is_instance_valid(e) and (e as Node2D).global_position.distance_to(global_position) <= burst_px:
				caster.deal_damage(e, spell, {"source_pos": global_position})
	LightRig.flash(global_position, &"rainette_jade", 0.3)
	Audio.play(&"status.poison.light", global_position, -2.0, 1.3)
	_release()
	queue_free()


func _release() -> void:
	for d in held:
		var e: Variant = d["e"]
		if is_instance_valid(e):
			var vis: Variant = e.get(&"visual")
			if vis is Node2D:
				(vis as Node2D).position.y = float(d["y0"])
			if e.has_method(&"release_imprison"):
				e.release_imprison()
	held.clear()


func _draw() -> void:
	if burst_done:
		return
	var k := clampf(_t / 0.25, 0.0, 1.0)
	var r := catch_px * (0.6 + 0.4 * k) * (1.0 + 0.1 * sin(_t * 9.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r, FILL)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.55, 0.73, 0.66, 0.6), 2.0)
