class_name TestMutedInput
extends InputSource
## Mode test : source d'entrée « muette » posée par TestBubbles pendant le mode bulles (F2 / R3). Enveloppe la source réelle du
## joueur : déplacement nul, aucune action (sorts, esquive, interagir) ; la visée, le pointeur, le mode et l'appartenance des
## événements restent ceux de la source réelle. Hors core : installée via Players.set_input.
## À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

var inner: InputSource


func _init(source: InputSource = null) -> void:
	inner = source if source != null else InputSource.global_source()
	kind = inner.kind
	device = inner.device


func mode() -> int:
	return inner.mode()


func move_vector() -> Vector2:
	return Vector2.ZERO


func aim_vector() -> Vector2:
	return inner.aim_vector()


func is_pressed(_action: StringName) -> bool:
	return false


func just_pressed(_action: StringName) -> bool:
	return false


func just_released(_action: StringName) -> bool:
	return false


func pointer_world(canvas: CanvasItem) -> Variant:
	return inner.pointer_world(canvas)


func owns_event(event: InputEvent) -> bool:
	return inner.owns_event(event)


func poll() -> void:
	inner.poll()


func describe() -> String:
	return inner.describe()
