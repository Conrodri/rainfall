extends Node2D
## Outil de revue (pas un test) : capture chaque VFX de test au pic de sa lumière, sous la vraie caméra iso,
## à côté d'Ardent pour l'échelle. Fenêtré (pas --headless) :
##   godot --path game res://tests/vfx_capture.tscn -- --keys=ardent/nova_ardente,morfil/fauche_lune --out=C:/chemin
## À RETIRER AVEC LE MODE TEST.

var _out := "user://vfx_capture"
var _keys: Array[String] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--keys="):
			for k in a.substr(7).split(",", false):
				_keys.append(k)
		elif a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var cm := CanvasModulate.new()
	cm.color = Color(0.32, 0.34, 0.42)
	add_child(cm)
	var cam := Camera2D.new()
	cam.zoom = Iso.camera_zoom()
	add_child(cam)
	cam.make_current()
	queue_redraw()
	_run.call_deferred()


func _draw() -> void:
	# Sol : fond sombre et grille de la carte (cases de 1 u tournées de 45°), repère logique.
	draw_rect(Rect2(-3000, -3000, 6000, 6000), Color(0.11, 0.12, 0.14))
	var x := Iso.map_xform()
	for i in range(-20, 21):
		var c := Color(0.2, 0.22, 0.26) if i != 0 else Color(0.35, 0.3, 0.25)
		draw_line(x * Vector2(i * 64, -1280), x * Vector2(i * 64, 1280), c, 2.0)
		draw_line(x * Vector2(-1280, i * 64), x * Vector2(1280, i * 64), c, 2.0)


func _hero() -> Node2D:
	var space := Node2D.new()
	space.scale = Iso.UNSQUASH
	space.position = Vector2(-150, 0)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = load("res://assets/sprites/characters/ardent/ardent.tres")
	spr.scale = Vector2.ONE * Iso.SPRITE_K
	spr.centered = true
	space.add_child(spr)
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, 0)
	if tex != null:
		spr.offset = Vector2(0, -tex.get_height() * 0.42)
	return space


func _run() -> void:
	add_child(_hero())
	for k in _keys:
		var meta := VfxTestPlayer.load_meta(k)
		var curve: Array = meta.get("light_curve", [1.0])
		var peak := 0
		for i in curve.size():
			if float(curve[i]) > float(curve[peak]):
				peak = i
		var fps := float(meta.get("fps", 15.0))
		var fx := VfxTestPlayer.spawn(self, k, Vector2(60, 0), Vector2(1, -0.4).normalized(), {"duration": 30.0})
		var wait := (maxi(peak, 4) + 0.5) / fps
		await get_tree().create_timer(wait).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
		img.save_png("%s/%s.png" % [_out, k.replace("/", "__")])
		print("capture ", k, " t=", snappedf(wait, 0.01))
		if is_instance_valid(fx):
			fx.queue_free()
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()
