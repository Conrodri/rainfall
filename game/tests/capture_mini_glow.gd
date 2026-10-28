extends Node
## Captures + mesures de luminance des mini-boss / boss dans une vraie run (fenêtré, pas headless) :
## godot --path game --resolution 1280x720 res://tests/capture_mini_glow.tscn [-- --tag=avant]
## PNG dans art/tools/night/_mini_glow_captures/<tag>_<id>.png ; luminance de l'écart (avec boss - sans boss)
## sur un carré de 360 px autour du boss, part de pixels brûlés (un canal >= 0,97).

const OUT := "res://../art/tools/night/_mini_glow_captures/"
const SAVE := "user://test_capture_mini_glow.json"
const CASES := {
	1: [["iron_heron", &"mini"], ["frost_bear", &"mini"]],
	2: [["lantern_owl", &"mini"], ["mist_wolf", &"mini"]],
	3: [["grinder", &"mini"], ["steam_hound", &"mini"]],
	4: [["ossuary_bearer", &"mini"], ["blind_swarm", &"mini"], ["salt_golem", &"mini"], ["blind_lamplighter", &"mini"], ["sarcophagus_crab", &"mini"], ["recluse", &"etage"]],
}

var _main: Node
var _tag := "run"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 45)
	add_child(_main)
	await _main.game_ready
	var stage: StageManager = _main.get(&"stage")
	var player: Node2D = _main.get(&"player")
	player.grant_invulnerability(99999.0)
	var lines: PackedStringArray = []
	var only := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = int(a.substr(7))
	for floor_n in [1, 2, 3, 4]:
		if only > 0 and floor_n < only:
			continue
		if floor_n > 1:
			RunState.stage = floor_n - 1
			RunState.active_time_s = 30.0
			stage.floor_cleared = true
			stage.request_exit()
			await _wait(1.5)
		var spot := _cell(stage.map, Vector2i(14, 12))
		for c in CASES[floor_n]:
			player.global_position = spot
			await _wait(1.5)
			var bg := _grab()
			var b := TestTools.spawn_boss(get_tree(), StringName(c[0]), c[1], spot + Vector2(0, 120)) as Enemy
			if b == null:
				lines.append("%s : spawn KO" % c[0])
				continue
			b.max_hp = 1.0e7
			b.hp = 1.0e7
			if b.brain != null and "ai_enabled" in b.brain:
				b.brain.ai_enabled = false
			_experiment(b)
			player.global_position = spot
			player.process_mode = Node.PROCESS_MODE_DISABLED # pas de tir : aucun flash de coup sur la capture
			await _wait(2.0)
			var img := _grab()
			var sp := b.get_global_transform_with_canvas().origin
			var m := _measure(bg, img, sp - Vector2(0, 70))
			lines.append("F%d %-18s lum=%.3f burnt=%.3f px=%d  light=%.2f" % [floor_n, c[0], m.x, m.y, int(m.z), (b._light.energy if b._light != null and "energy" in b._light else -1.0)])
			img.save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [_tag, c[0]]))
			player.process_mode = Node.PROCESS_MODE_INHERIT
			b.take_damage(1.0e9)
			await _wait(1.5)
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "%s_mesures.txt" % _tag), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()


## Interrupteurs de diagnostic : --exp=nogain,nolight,noemis,norim (retirent un facteur de brillance).
func _experiment(b: Enemy) -> void:
	var ex := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--exp="):
			ex = a.substr(6)
	if "nogain" in ex:
		b.visual.modulate = Color.WHITE
	if "nolight" in ex and b._light != null:
		b._light.set_enabled(false)
	if "noemis" in ex:
		var em := b.visual.get_node_or_null("Emission")
		if em != null:
			em.visible = false
	if "norim" in ex:
		var o := b.visual.get_node_or_null("MiniOutline")
		if o != null:
			o.visible = false
		if b.brain != null and "_rim" in b.brain and b.brain._rim != null:
			b.brain._rim.set_enabled(false)


func _grab() -> Image:
	var img := get_viewport().get_texture().get_image()
	if get_viewport().use_hdr_2d:
		img = load("res://tests/perf_bench.gd").linear_to_srgb8(img)
	img.convert(Image.FORMAT_RGBA8)
	return img


## (luminance moyenne, part brûlée, nb pixels) des pixels qui diffèrent du fond autour de `c`.
func _measure(bg: Image, img: Image, c: Vector2) -> Vector3:
	var sum := 0.0
	var burnt := 0
	var n := 0
	var r := Rect2i(Vector2i(c) - Vector2i(180, 180), Vector2i(360, 360)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var a := img.get_pixel(x, y)
			var d := bg.get_pixel(x, y)
			if absf(a.r - d.r) + absf(a.g - d.g) + absf(a.b - d.b) < 0.12:
				continue
			n += 1
			sum += a.r * 0.2126 + a.g * 0.7152 + a.b * 0.0722
			if maxf(a.r, maxf(a.g, a.b)) >= 0.97:
				burnt += 1
	return Vector3(sum / maxf(n, 1), float(burnt) / maxf(n, 1), n)


func _cell(map: StageMap, c: Vector2i) -> Vector2:
	var size_u: Vector2 = map.get_meta(&"size_u", Vector2.ZERO)
	return map.to_global(map.from_map((Vector2(c) * 2.0 + Vector2.ONE - size_u * 0.5) * 64.0))


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout
