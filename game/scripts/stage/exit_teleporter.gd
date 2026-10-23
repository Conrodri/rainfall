class_name ExitTeleporter
extends Area2D
## Téléporteur de sortie, actif une fois l'étage terminé. Utilisation : `interact()` (maintien de 0,6 s géré
## par le HUD) joueur dessus, jamais au contact : le joueur peut rester farmer sans être téléporté.

signal used

## Maintien (s) exigé sur l'action « interagir » avant de partir (audit Choix P4). Valeur dans
## Balance.UI_EXIT_HOLD_S ; alias conservé pour les appelants existants.
const EXIT_HOLD_S: float = preload("res://scripts/core/balance.gd").UI_EXIT_HOLD_S

var active := false
var _player_on := false
var _light: LightRig.Handle = null


func _init() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 << 1
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 80.0
	cs.shape = circle
	add_child(cs)
	visible = false


func _ready() -> void:
	add_to_group(&"interactable")
	body_entered.connect(func(b: Node) -> void: _player_on = _player_on or b.is_in_group(&"player"))
	body_exited.connect(func(b: Node) -> void: _player_on = _player_on and not b.is_in_group(&"player"))


func set_active(value: bool) -> void:
	active = value
	visible = value
	if value and _light == null:
		_light = LightRig.attach(self, &"teleporter")
	elif _light != null:
		_light.set_enabled(value)
	queue_redraw()


func use() -> bool:
	if not active:
		return false
	used.emit()
	return true


func _draw() -> void:
	draw_circle(Vector2.ZERO, 80.0, Color(0.5, 0.3, 1.0, 0.35))
	draw_arc(Vector2.ZERO, 80.0, 0.0, TAU, 48, Color(0.7, 0.5, 1.0), 5.0)


func can_interact() -> bool:
	return active and _player_on


func interact_label() -> String:
	return "Partir"


## Appelé par le répartiteur unique du HUD, une fois le maintien de EXIT_HOLD_S accompli.
func interact() -> bool:
	return use()


## Invite : maintien de 0,6 s (départ irréversible) + coffres encore fermés dans le libellé.
func interact_state() -> Dictionary:
	var left := 0
	if is_inside_tree():
		for c in get_tree().get_nodes_in_group(&"chests"):
			if c.has_method(&"is_opened") and not c.is_opened():
				left += 1
	var txt := "Partir"
	if left > 0:
		txt = "Partir — %d coffre%s restant%s" % [left, "s" if left > 1 else "", "s" if left > 1 else ""]
	return {"visible": can_interact(), "enabled": true, "label": txt, "hold_s": EXIT_HOLD_S}


func interact_priority() -> int:
	return 0
