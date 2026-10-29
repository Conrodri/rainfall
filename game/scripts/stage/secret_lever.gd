class_name SecretLever
extends Node2D
## Levier caché d'une salle secrète (déclencheur « lever », docs/Design_Variantes_B.md « Déclencheurs »). Posé dans un
## recoin de la carte (marqueur `lever`). S'actionne uniquement par l'action « interagir » (contrat Interaction, comme
## le téléporteur : jamais au contact) ; définitif pour l'étage. Visuel provisoire (socle + manche dessinés en code)
## en attendant le lot Codex art/tools/props/_secret_lever.txt.

signal activated

var used := false
var _player: Node2D = null


func _ready() -> void:
	add_to_group(&"interactable")
	queue_redraw()


func _player_node() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D if is_inside_tree() else null
	return _player


func player_near() -> bool:
	var p := _player_node()
	return p != null and p.global_position.distance_to(global_position) <= Balance.SECRET_LEVER_RANGE_U * Balance.UNIT_PX


func can_interact() -> bool:
	return not used and player_near()


func interact_label() -> String:
	return "Actionner"


func interact_state() -> Dictionary:
	return {"visible": can_interact(), "enabled": true, "label": interact_label(), "hold_s": 0.0}


func interact_priority() -> int:
	return 2


func interact() -> bool:
	if used or not player_near():
		return false
	pull(false)
	return true


## Abaisse le levier (définitif). `silent` : restauration d'une sauvegarde, aucun signal ni son.
func pull(silent: bool = false) -> void:
	if used:
		return
	used = true
	remove_from_group(&"interactable")
	queue_redraw()
	if not silent:
		Audio.play(&"chest.lock", global_position)
		activated.emit()


func _draw() -> void:
	# placeholder : socle de pierre, manche levé (armé) ou abaissé (utilisé)
	draw_rect(Rect2(-22.0, -8.0, 44.0, 16.0), Color(0.3, 0.28, 0.25))
	draw_rect(Rect2(-22.0, -8.0, 44.0, 16.0), Color(0.6, 0.55, 0.45), false, 3.0)
	var tip := Vector2(-18.0, -6.0) if used else Vector2(12.0, -46.0)
	draw_line(Vector2(0.0, -4.0), tip, Color(0.75, 0.7, 0.6), 6.0)
	draw_circle(tip, 8.0, Color(0.35, 0.35, 0.3) if used else Color(1.0, 0.82, 0.45))
