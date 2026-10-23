class_name SafeArea
extends MarginContainer
## Conteneur qui applique la zone sûre (Platform.safe_margins() : 48/32 px au minimum, encoches mobiles).
## Se met à jour au redimensionnement de la fenêtre, au changement de mode d'entrée et quand la zone sûre change
## sans redimensionnement (encoche passée de gauche à droite en paysage capteur : Platform.safe_area_changed).


func _ready() -> void:
	get_viewport().size_changed.connect(apply_margins)
	Platform.input_mode_changed.connect(_on_mode)
	Platform.safe_area_changed.connect(apply_margins)
	apply_margins()


func _on_mode(_m: int) -> void:
	apply_margins()


func apply_margins() -> void:
	var m: Dictionary = Platform.safe_margins()
	add_theme_constant_override(&"margin_left", int(m["left"]))
	add_theme_constant_override(&"margin_top", int(m["top"]))
	add_theme_constant_override(&"margin_right", int(m["right"]))
	add_theme_constant_override(&"margin_bottom", int(m["bottom"]))
