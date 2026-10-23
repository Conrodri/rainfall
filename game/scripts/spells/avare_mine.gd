class_name AvareMine
extends Node2D
## Coffre-mine du Trésor enterré (variante de la Faillite, docs/Variantes_Sorts.md §2.7) : posé aux pieds d'Avare,
## détone à FUSE_S ou dès que TRIGGER_POINTS points de monstres (élite 2, T3 et boss 3, sinon 1) sont à <= TRIGGER_U
## (jamais avant ARM_S). La détonation et le remboursement sont faits par le kit (`detonate_mine`).
## Placeholder visuel : coffre carré + cercle de télégraphe doré qui se remplit en FUSE_S.

const FUSE_S := 3.0
const ARM_S := 0.8
const TRIGGER_U := 2.0
const TRIGGER_POINTS := 6
const GOLD := Color("#F2C14E")

var kit: Object = null ## AvareKit
var spell: SpellData = null
var buried := 0.0 ## or enterré (rendu en pièces à la détonation)
var power := 0.0 ## puissance de l'or d'AVANT l'enterrement
var radius_px := 320.0
var age := 0.0
var detonated := false
var detonation_cause := &"" ## &"fuse" ou &"crush" (tests)


func _physics_process(delta: float) -> void:
	if detonated:
		return
	age += delta
	queue_redraw()
	if age >= FUSE_S:
		_boom(&"fuse")
	elif age >= ARM_S and crush_points() >= TRIGGER_POINTS:
		_boom(&"crush")


## Points de monstres écrasants à <= TRIGGER_U du coffre.
func crush_points() -> int:
	var pts := 0
	var r := TRIGGER_U * Balance.UNIT_PX
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and e.has_method(&"take_damage") and (e as Node2D).global_position.distance_to(global_position) <= r:
			pts += point_value(e)
	return pts


static func point_value(e: Node) -> int:
	var tier := int(e.get(&"tier")) if "tier" in e else 1
	if ("is_boss" in e and bool(e.get(&"is_boss"))) or tier >= 3:
		return 3
	if "is_elite" in e and bool(e.get(&"is_elite")):
		return 2
	return 1


func _boom(cause: StringName) -> void:
	detonated = true
	detonation_cause = cause
	if kit != null and kit.has_method(&"detonate_mine"):
		kit.detonate_mine(self)
	queue_free()


func _draw() -> void:
	var k := clampf(age / FUSE_S, 0.0, 1.0)
	GroundShapes.draw_dotted_circle(self, radius_px, Color(GOLD, 0.35), 48, 2.0)
	draw_arc(Vector2.ZERO, radius_px * k, 0.0, TAU, 64, Color(GOLD, 0.75), 3.0)
	draw_rect(Rect2(-14, -12, 28, 24), Color("#3A2E22"))
	draw_rect(Rect2(-14, -12, 28, 24), GOLD, false, 2.0)
	draw_circle(Vector2(0, 0), 3.0 + 2.0 * sin(age * 12.0 * (1.0 + k * 2.0)) * sin(age * 12.0 * (1.0 + k * 2.0)), GOLD)
