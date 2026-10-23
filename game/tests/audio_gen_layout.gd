extends Node
## Outil : génère res://default_bus_layout.tres à partir des bus créés par l'autoload Audio.
func _ready() -> void:
	await get_tree().process_frame
	var lay := AudioServer.generate_bus_layout()
	print("SAVE ", ResourceSaver.save(lay, "res://default_bus_layout.tres"), " buses=", AudioServer.bus_count)
	get_tree().quit()
