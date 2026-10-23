extends Node
## Banc de partie chargée AVEC RENDU (pas headless) : vraie scène de jeu (main.tscn) sur une carte
## imposée, D ≈ 5, ~250 monstres maintenus autour du joueur (invulnérable, immobile, sort 1 auto),
## palier de qualité imposé. Mesure : temps GPU / CPU de rendu, process + physique, draw calls,
## objets, lumières actives / ombrées, occluders, couche d'ombres cuites, mémoire vidéo / textures.
##   godot --path game res://tests/perf_bench.tscn -- --map=cite_rouille --tier=2 --shot=C:/x.png
## Une ligne « BENCH | ... » est imprimée pour être agrégée par un script.

const WARMUP := 120
const FRAMES := 360
const N := 250
const D_TARGET := 5.0

var map_id := "cite_rouille"
var tier := 2
var shot_path := ""
var _main: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="): map_id = a.substr(6)
		elif a.begins_with("--tier="): tier = int(a.substr(7))
		elif a.begins_with("--shot="): shot_path = a.substr(7)
		elif a.begins_with("--hdr="): Quality.hdr_override = int(a.substr(6)) # 0 / 1 : HDR 2D forcé (comparaison LDR)
	Quality.persist = false
	Quality.dynamic_degrade = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(1920, 1080)
	_rng.seed = 7
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 777)
	_main.set(&"map_scene", load("res://scenes/stage/maps/%s.tscn" % map_id))
	add_child(_main)
	await _main.game_ready
	Quality.set_tier(tier, true)
	Quality.dynamic_degrade = false
	# D ≈ 5 : temps actif équivalent (recherche par dichotomie sur la formule de Balance)
	var lo := 0.0
	var hi := 100000.0
	for i in 40:
		var mid := (lo + hi) * 0.5
		if Balance.difficulty(mid, RunState.stage, Balance.MODES[RunState.mode]) < D_TARGET:
			lo = mid
		else:
			hi = mid
	RunState.active_time_s = lo
	var player: Node2D = _main.player
	player.grant_invulnerability(1.0e6)
	if "--calib" in OS.get_cmdline_user_args():
		await _calib(player)
		return
	var director: Director = _main.director
	director.spawning_enabled = false
	_main.ambiance.set_difficulty(RunState.difficulty())
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for i in WARMUP:
		_top_up(director, player)
		_experiments()
		await get_tree().process_frame
	var vp := get_viewport().get_viewport_rid()
	var acc := {"gpu": 0.0, "cpu": 0.0, "proc": 0.0, "phys": 0.0, "draw": 0.0, "obj": 0.0, "enemies": 0.0}
	var t0 := Time.get_ticks_usec()
	for i in FRAMES:
		_top_up(director, player)
		_experiments()
		await get_tree().process_frame
		acc["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		acc["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		acc["proc"] += Performance.get_monitor(Performance.TIME_PROCESS)
		acc["phys"] += director.stat_tick_usec / 1000.0
		acc["draw"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		acc["obj"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		acc["enemies"] += director.active_count()
	var wall := (Time.get_ticks_usec() - t0) / 1000.0 / FRAMES
	for k in acc:
		acc[k] /= FRAMES
	var lights := 0
	var shadowed := 0
	for l in _all(get_tree().root, "Light2D"):
		var li := l as Light2D
		if li.is_visible_in_tree() and li.enabled:
			lights += 1
			if li.shadow_enabled:
				shadowed += 1
	var occ := 0
	for o in _all(get_tree().root, "LightOccluder2D"):
		if (o as CanvasItem).is_visible_in_tree():
			occ += 1
	var baked: Variant = _main.ambiance.get(&"baked_shadows")
	var baked_info := "-"
	if baked != null and baked is Node and (baked as Node).has_method(&"describe"):
		baked_info = String((baked as Node).call(&"describe"))
	var vmem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var tmem := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	print("BENCH | map=%s | tier=%s | D=%.2f | enemies=%.0f | frame=%.2f ms | gpu=%.3f ms | cpu_render=%.3f ms | process_mon=%.3f | director=%.3f ms | draw_calls=%.0f | objects=%.0f | lights=%d | shadowed=%d | occluders=%d | baked=%s | vram=%.1f MiB | tex=%.1f MiB" % [
		map_id, Quality.tier_name(), RunState.difficulty(), acc["enemies"], wall, acc["gpu"], acc["cpu"], acc["proc"], acc["phys"],
		acc["draw"], acc["obj"], lights, shadowed, occ, baked_info, vmem, tmem])
	if "--diag" in OS.get_cmdline_user_args():
		diag()
	if shot_path != "":
		await get_tree().process_frame
		save_shot(get_viewport(), shot_path)
		print("capture : ", shot_path)
	get_tree().quit()


## Capture fidèle à l'écran : en HDR 2D la texture du viewport est linéaire (-> sRGB avant PNG).
static func save_shot(vp: Viewport, path: String) -> void:
	var img := vp.get_texture().get_image()
	if vp.use_hdr_2d:
		img = linear_to_srgb8(img)
	img.save_png(path)


## Conversion linéaire (HDR 2D) -> sRGB 8 bits en flottant : Image.linear_to_srgb() exige du 8 bits
## et passer par RGBA8 avant la courbe écrase les sombres (tout ce qui est < sRGB 13 tombe à 0).
static func linear_to_srgb8(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBF)
	var f := img.get_data().to_float32_array()
	var out := PackedByteArray()
	out.resize(f.size())
	for i in f.size():
		var v := clampf(f[i], 0.0, 1.0)
		v = v * 12.92 if v <= 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055
		out[i] = int(v * 255.0 + 0.5)
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGB8, out)


## Maintient ~N monstres (mix T1/T2/T3 + élites) autour du joueur.
func _top_up(director: Director, player: Node2D) -> void:
	var need := N - director.active_count()
	var tries := 0
	while need > 0 and tries < 400:
		tries += 1
		var pos := player.global_position + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(260.0, 1100.0)
		if director.nav and not director.nav.is_spawnable(pos):
			continue
		var r := _rng.randf()
		director.spawn_enemy(3 if r < 0.1 else (2 if r < 0.32 else 1), pos, _rng.randf() < 0.12)
		need -= 1


func _all(n: Node, cls: String) -> Array:
	var out := []
	if n.is_class(cls):
		out.append(n)
	for c in n.get_children():
		out.append_array(_all(c, cls))
	return out


## --diag : nombre de CanvasItem visibles par classe et par parent (repère les sources d'objets).
func diag() -> void:
	var by_cls := {}
	var by_parent := {}
	for n in _all(get_tree().root, "CanvasItem"):
		var ci := n as CanvasItem
		if not ci.is_visible_in_tree():
			continue
		var k := ci.get_class() + ":" + String(ci.get_script().resource_path.get_file() if ci.get_script() else "")
		by_cls[k] = int(by_cls.get(k, 0)) + 1
		var pk := String(ci.get_parent().name)
		by_parent[pk] = int(by_parent.get(pk, 0)) + 1
	print("DIAG classes : ", by_cls)
	var arr := []
	for k in by_parent:
		arr.append([by_parent[k], k])
	arr.sort()
	arr.reverse()
	print("DIAG parents : ", arr.slice(0, 15))


## --x=shadows,hdr,occ,emissive,lights : coupe un poste pour mesurer son coût (diagnostic).
func _experiments() -> void:
	var xs := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--x="): xs = a.substr(4)
	if xs == "":
		return
	if "hdr" in xs:
		get_tree().root.use_hdr_2d = false
	for l in _all(get_tree().root, "Light2D"):
		if "shadows" in xs:
			(l as Light2D).shadow_enabled = false
		if "lights" in xs and l is PointLight2D:
			(l as Light2D).enabled = false
	if "occ" in xs:
		for o in _all(get_tree().root, "LightOccluder2D"):
			(o as CanvasItem).visible = false
	if "emissive" in xs:
		for s in _all(get_tree().root, "AnimatedSprite2D"):
			if s.get_script() == null and s.material is ShaderMaterial and s.get_parent() is AnimatedSprite2D:
				(s as CanvasItem).visible = false
	if "glow" in xs:
		_main.ambiance.environment.glow_enabled = false
	if "noenv" in xs:
		_main.ambiance.world_env.environment = null
	if "screen" in xs:
		for c in _all(get_tree().root, "CanvasItem"):
			var m := (c as CanvasItem).material as ShaderMaterial
			if m != null and m.shader != null and "hint_screen_texture" in m.shader.code:
				(c as CanvasItem).visible = false
	for key in ["particles:GPUParticles2D", "colorrect:ColorRect", "sprite2d:Sprite2D", "labels:Label", "tilemap:TileMapLayer"]:
		var kv: PackedStringArray = key.split(":")
		if kv[0] in xs:
			for c in _all(get_tree().root, kv[1]):
				(c as CanvasItem).visible = false
	for nm in ["Water", "Fog", "Weather", "Lightning"]:
		if nm.to_lower() in xs:
			var n: Node = _main.ambiance.find_child(nm, false, false)
			if n == null:
				for c in _main.ambiance.get_children():
					if c.name.to_lower().begins_with(nm.to_lower()):
						n = c
			if n is CanvasItem:
				(n as CanvasItem).visible = false
			elif n != null:
				for c in n.get_children():
					if c is CanvasItem: (c as CanvasItem).visible = false
	if "enemies" in xs:
		(_main.director.get_node(^"Enemies") as CanvasItem).visible = false
	for root in [_main, _main.ambiance]:
		for c in root.get_children():
			if ("h_" + String(c.name)) in xs:
				if c is CanvasItem: (c as CanvasItem).visible = false
				elif c is CanvasLayer: (c as CanvasLayer).visible = false
	if "listnames" in xs and Engine.get_process_frames() % 200 == 0:
		print("MAIN: ", _main.get_children().map(func(c): return c.name + ":" + c.get_class()))
		print("AMB: ", _main.ambiance.get_children().map(func(c): return c.name + ":" + c.get_class()))
	if "dynsun" in xs: # référence : ancienne ombre dynamique du soleil (pour caler la couche cuite)
		_main.ambiance.debug_dynamic_sun = true
		for o in _main.ambiance.occluders.get_children():
			(o as CanvasItem).visible = true
		if _main.ambiance.occluders.get_child_count() == 0:
			OccluderBuilder.build(_main.ambiance.map, _main.ambiance.occluders)
	if "nobake" in xs:
		_main.ambiance.baked_shadows.visible = false
	if "calm" in xs:
		_main.ambiance.set_difficulty(1.0)


## --calib : capture de calage des ombres (sans monstres ni HUD), joueur posé au sud-est d'un mur.
func _calib(player: Node2D) -> void:
	_main.director.spawning_enabled = false
	_main.director.despawn_all()
	(_main.get_node(^"Hud") as CanvasLayer).visible = false
	var map: Node2D = _main.ambiance.map
	var best := Rect2()
	var best_d := INF
	for r in OccluderBuilder.shadow_rects(map):
		if r.size.x < 200 and r.size.y < 200:
			continue
		var d := r.get_center().length()
		if d < best_d:
			best_d = d
			best = r
	player.set_physics_process(false)
	player.global_position = map.to_global(best.end + Vector2(260, 160))
	_main.ambiance.set_difficulty(RunState.difficulty())
	for i in 90:
		_experiments()
		await get_tree().process_frame
	if shot_path != "":
		save_shot(get_viewport(), shot_path)
		print("capture : ", shot_path)
	var bs: BakedShadows = _main.ambiance.baked_shadows
	print("CALIB | ", bs.describe(), " vis=", bs.is_visible_in_tree(), " spr=", bs.sprite.visible, " pos=", bs.sprite.global_position, " scale=", bs.sprite.scale, " z=", bs.z_index, " col=", bs.material_shadow.get_shader_parameter(&"shadow_color"), " k=", bs.material_shadow.get_shader_parameter(&"strength"), " sun_sh=", _main.ambiance.sun.shadow_enabled, " sunvis=", _main.ambiance.sun.visible, " occ=", _main.ambiance.occluders.get_child_count())
	bs.sprite.texture.get_image().save_png(shot_path.get_basename() + "_mask.png")
	get_tree().quit()
