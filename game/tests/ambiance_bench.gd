extends Node
## Banc de coût de l'ambiance AVEC RENDU (pas headless) : carte réelle + 250 sprites éclairés,
## mesure sans puis avec AmbianceManager (palier Haut, D réglable), vsync coupée.
##   godot --path game res://tests/ambiance_bench.tscn -- --map=cite_rouille --d=5.0 --tier=2
## Les textures Blender absentes sont remplacées ICI SEULEMENT par du bruit généré (jamais livré)
## pour que les shaders de pluie, brume, nuages et flaques tournent et coûtent leur vrai prix.

const WARMUP := 90
const FRAMES := 400
const SPRITES := 250

var map_id := "cite_rouille"
var D := 5.0
var tier := 2
var shot_path := ""
var _results := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="): map_id = a.substr(6)
		elif a.begins_with("--d="): D = float(a.substr(4))
		elif a.begins_with("--tier="): tier = int(a.substr(7))
		elif a.begins_with("--shot="): shot_path = a.substr(7)
	Quality.persist = false
	Quality.dynamic_degrade = false
	Quality.set_tier(tier, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(1920, 1080)
	await _inject_placeholders()
	var map: Node2D = load("res://scenes/stage/maps/%s.tscn" % map_id).instantiate()
	add_child(map)
	var cam := Camera2D.new()
	add_child(cam)
	var start: Vector2 = map.to_global(map.get_player_start())
	cam.global_position = start
	cam.make_current()
	_spawn_sprites(start)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await _measure("sans ambiance")
	var mgr: AmbianceManager = load("res://scenes/ambiance/ambiance_manager.tscn").instantiate()
	mgr.auto_bind = false
	add_child(mgr)
	mgr.set_difficulty(D)
	mgr.bind_map(map)
	_attach_gameplay_lights(start)
	await _measure("avec ambiance (%s, D=%.2f, %s)" % [map_id, D, Quality.tier_name()])
	var base: Dictionary = _results["sans ambiance"]
	for k in _results:
		var r: Dictionary = _results[k]
		print("%-45s GPU %.3f ms | CPU rendu %.3f ms | image %.3f ms | %.0f i/s" % [k, r["gpu"], r["cpu"], r["proc"], r["fps"]])
	var amb: Dictionary = _results.values()[-1]
	print("COUT AMBIANCE : GPU +%.3f ms, CPU rendu +%.3f ms, image (horloge) +%.3f ms ; lumières actives %d, ombres %d, occluders %d" % [
		amb["gpu"] - base["gpu"], amb["cpu"] - base["cpu"], amb["proc"] - base["proc"],
		mgr.rig.active_light_count(), mgr.rig.shadowed_light_count(), mgr.occluders.get_child_count()])
	if shot_path != "":
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("capture : ", shot_path)
	get_tree().quit()


func _measure(label: String) -> void:
	for i in WARMUP:
		await get_tree().process_frame
	var vp := get_viewport().get_viewport_rid()
	var gpu := 0.0
	var cpu := 0.0
	var t0 := Time.get_ticks_usec()
	for i in FRAMES:
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)

	var dt := float(Time.get_ticks_usec() - t0) / 1e6
	_results[label] = {"gpu": gpu / FRAMES, "cpu": cpu / FRAMES, "proc": dt * 1000.0 / FRAMES, "fps": FRAMES / dt}


func _spawn_sprites(center: Vector2) -> void:
	var tex: Texture2D = null
	for p in ["res://assets/sprites/bosses/etage/cerf/auto.png", "res://icon.svg"]:
		if ResourceLoader.exists(p):
			tex = load(p)
			break
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in SPRITES:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * 0.35
		s.global_position = center + Vector2(rng.randf_range(-900, 900), rng.randf_range(-500, 500))
		add_child(s)


func _attach_gameplay_lights(center: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var spec := {&"player": 1, &"elite_burn": 4, &"elite_slow": 4, &"chest_petit": 3, &"chest_legendaire": 1, &"pillar_active": 2, &"boss": 1, &"ember": 3, &"nova": 3, &"coin": 80}
	for preset in spec:
		for i in int(spec[preset]):
			var n := Node2D.new()
			add_child(n)
			n.global_position = center + (Vector2.ZERO if preset == &"player" else Vector2(rng.randf_range(-850, 850), rng.randf_range(-480, 480)))
			LightRig.attach(n, preset)


func _inject_placeholders() -> void:
	var ids := [&"rain_sheet_512", &"fog_tile_1024", &"fog_tile_1024_2", &"fog_volume_tile_1024", &"cloud_shadow_2048",
		&"canopy_shadow_2048", &"ripple_normal_256", &"puddle_mask_1024", &"sky_storm_256x64", &"sky_sunset_256x64", &"sky_dawn_256x64",
		&"fog_puff_512", &"godray_512x1024", &"ash_16", &"mote_16", &"leaf_pine_32", &"firefly_16", &"leaf_cedar_32"]
	for id in ids:
		if AmbianceTextures.exists(id):
			continue
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.noise = FastNoiseLite.new()
		await nt.changed
		AmbianceTextures._cache[id] = nt
	print("placeholders de banc injectés pour les textures absentes")
