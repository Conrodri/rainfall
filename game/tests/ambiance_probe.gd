extends SceneTree
## Sonde de capacités du renderer (rendu réel, pas headless) :
## godot --path game --script res://tests/ambiance_probe.gd

var _frames := 0
var _img_tex: ImageTexture


func _initialize() -> void:
	root.size = Vector2i(256, 128)
	root.use_hdr_2d = true
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_img_tex = ImageTexture.create_from_image(img)
	var cm := CanvasModulate.new()
	cm.color = Color(0.25, 0.25, 0.25)
	root.add_child(cm)
	# A : sprite normal (affecté par CanvasModulate)
	_spr(Vector2(20, 20), null)
	# B : sprite unshaded
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_spr(Vector2(60, 20), m)
	# C : sprite HDR (self_modulate 4.0) unshaded, pour le glow
	var s := _spr(Vector2(200, 64), m)
	s.self_modulate = Color(4, 4, 4)
	# D : shader qui écrit 3.0
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; render_mode unshaded; void fragment(){ COLOR = vec4(3.0,3.0,3.0,1.0); }"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_spr(Vector2(100, 20), sm)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	we.environment = env
	root.add_child(we)


func _spr(p: Vector2, mat: Material) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _img_tex
	s.position = p
	s.material = mat
	root.add_child(s)
	return s


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 10:
		var im := root.get_texture().get_image()
		print("method=", RenderingServer.get_current_rendering_method(), " driver=", RenderingServer.get_current_rendering_driver_name(), " fmt=", im.get_format())
		print("A normal ", im.get_pixel(20, 20))
		print("B unshaded ", im.get_pixel(60, 20))
		print("D shader3 ", im.get_pixel(100, 20))
		print("C hdr center ", im.get_pixel(200, 64), " halo+14 ", im.get_pixel(214, 64), " halo+24 ", im.get_pixel(224, 64))
		print("bg far ", im.get_pixel(150, 120))
		return true
	return false
