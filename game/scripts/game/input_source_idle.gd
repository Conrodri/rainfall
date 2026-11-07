class_name InputSourceIdle
extends InputSource
## Source d'entrée muette : un joueur de coop locale dont la manette est débranchée (CoopLocal). Aucun déplacement,
## aucun sort manuel ni esquive ; mode manette (visée automatique). `lost_device` garde la manette perdue pour la
## reconnexion. Aucune allocation.

var lost_device := -1


func _init(lost: int = -1) -> void:
	kind = Kind.PAD
	device = -1
	lost_device = lost


func mode() -> int:
	return Platform.InputMode.GAMEPAD


func move_vector() -> Vector2:
	return Vector2.ZERO


func aim_vector() -> Vector2:
	return Vector2.ZERO


func is_pressed(_action: StringName) -> bool:
	return false


func just_pressed(_action: StringName) -> bool:
	return false


func just_released(_action: StringName) -> bool:
	return false


func pointer_world(_canvas: CanvasItem) -> Variant:
	return null


func owns_event(_event: InputEvent) -> bool:
	return false


func describe() -> String:
	return "manette %d déconnectée" % lost_device
