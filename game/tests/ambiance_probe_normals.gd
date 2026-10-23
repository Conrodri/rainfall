extends SceneTree
## Sonde : une AtlasTexture dont l'atlas est une CanvasTexture garde-t-elle sa normal map ?
## godot --path game --script res://tests/ambiance_probe_normals.gd

var _frames := 0


func _initialize() -> void:
	root.size = Vector2i(256, 64)
	var white := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var nrm := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	nrm.fill(Color(_env("NX", 1.0), _env("NY", 0.5), 0.5))
	var ct := CanvasTexture.new()
	ct.diffuse_texture = ImageTexture.create_from_image(white)
	ct.normal_texture = ImageTexture.create_from_image(nrm)
	var at := AtlasTexture.new()
	at.atlas = ct
	at.region = Rect2(0, 0, 16, 16)
	var cm := CanvasModulate.new()
	cm.color = Color(0.1, 0.1, 0.1)
	root.add_child(cm)
	var plain := ImageTexture.create_from_image(white)
	for i in 4:
		var s := Sprite2D.new()
		s.texture = [plain, ct, at, plain][i]
		s.position = Vector2(32 + i * 64, 32)
		root.add_child(s)
		var l := PointLight2D.new()
		var g := GradientTexture2D.new()
		g.width = 64
		g.height = 64
		var gr := Gradient.new()
		gr.set_color(0, Color.WHITE)
		gr.set_color(1, Color.WHITE)
		g.gradient = gr
		l.texture = g # texture blanche pleine (repli de sonde)
		l.position = s.position + Vector2(_env("LX", 60.0), _env("LY", 0.0))
		l.height = 8.0
		l.energy = 0.4
		root.add_child(l)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 10:
		var im := root.get_texture().get_image()
		for i in 3:
			print(["plain", "canvas_tex", "atlas_of_canvas_tex"][i], " ", im.get_pixel(32 + i * 64, 32))
		return true
	return false


func _env(k: String, d: float) -> float:
	return float(OS.get_environment(k)) if OS.has_environment(k) else d
