extends Node
## Capture de la foudre en chaîne (SANS --headless) : 10 monstres sur une ligne courbe, proc forcé, 3 exemplaires.
## godot --path game res://tests/_chain_capture.tscn -- --out=<dossier>
class Dummy extends Node2D:
	func take_damage(_a: float, _c: bool = false, _e: StringName = &"") -> void:
		pass
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 22.0, Color(0.55, 0.2, 0.2))

var _out := ""

func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): _out = a.substr(6)
	get_window().size = Vector2i(1280, 720)
	var cam := Camera2D.new()
	cam.zoom = Iso.camera_zoom(1.6)
	add_child(cam)
	RunState.character = &"ardent"
	RunState.start_run(&"moyen", 5)
	for i in 3:
		RunState.add_item(&"eclair_en_bouteille")
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(p)
	await _f(3)
	p.set_physics_process(false)
	p.apply_stats(ItemStats.compute(RunState.items))
	var first: Node2D = null
	for i in 10:
		var d := Dummy.new()
		d.add_to_group("enemies")
		add_child(d)
		d.global_position = Vector2(-380.0 + 85.0 * i, 140.0 * sin(float(i) * 0.55))
		if i == 0: first = d
	await _f(3)
	p.spells._lightning(first, 100.0, p.procs[0]["data"])
	for k in 4:
		await get_tree().create_timer(0.07).timeout
		await _f(1)
		get_viewport().get_texture().get_image().save_png("%s/chain_%d.png" % [_out, k])
	print("live_arcs=", ChainLightningFx._inst.live_arcs if ChainLightningFx._inst else -1)
	get_tree().quit()
