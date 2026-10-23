extends Node
## TEMPORAIRE : captures 1920×1080 sRGB de la Flaque-miroir et de la Crue (retour joueur 23/10), supprimé ensuite.
## godot --path game --resolution 1920x1080 res://tests/_tmp_averse_cap.tscn -- --out=<dossier> [--ring]

var _main: Node
var _t := 0.0
var _step := 0
var _out := ""
var _ring := false


class Ring extends Node2D:
	var r := 0.0
	func _draw() -> void:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(1, 0.2, 0.9), 3.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		if a == "--ring":
			_ring = true
	RunState.character = &"averse"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	_main.set(&"save_path", "user://test_capture_averse_tmp.json")
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)


func _mark(z: Node) -> void:
	if not _ring or z == null:
		return
	var rg := Ring.new()
	rg.r = float(z.radius)
	z.add_child(rg)


func _shot(name: String) -> void:
	var p := "%s/%s%s.png" % [_out, name, "_ring" if _ring else ""]
	CaptureUtil.save_viewport(get_viewport(), p)
	print("SHOT ", p)


func _process(delta: float) -> void:
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	var p: Node2D = _main.player
	if _step == 0 and _t > 0.3:
		_step = 1
		p.grant_invulnerability(1.0e6)
		p.set(&"auto_cast_spells", false)
		p.kit.water = 100.0
		var d: Director = _main.director
		d.spawning_enabled = false
		var pp := p.global_position
		for i in 14:
			var v := Vector2.from_angle(TAU * i / 14.0) * (180.0 + 90.0 * (i % 3))
			d.spawn_enemy(1, pp + v)
	if _step == 1 and _t > 1.0:
		_step = 2
		p.spells.aim_override = p.global_position + Vector2(260, 60)
		p.spells.cast(3)
		p.spells.aim_override = null
	if _step == 2 and _t > 2.0:
		_step = 3
		_mark(p.kit.puddles[0] if not p.kit.puddles.is_empty() else null)
	if _step == 3 and _t > 2.1:
		_step = 4
		_shot("averse_flaque")
		p.kit.water = 100.0
		p.spells.cast(4)
	if _step == 4 and _t > 2.75:
		_step = 5
		for z in get_tree().get_nodes_in_group(&"zones"):
			pass
		_mark_crue(p)
	if _step == 5 and _t > 2.8:
		_step = 6
		_shot("averse_crue_a")
	if _step == 6 and _t > 3.0:
		_step = 7
		_shot("averse_crue_b")
	if _step == 7 and _t > 3.25:
		_step = 8
		_shot("averse_crue_c")
		get_tree().quit()


## La zone de la Crue = ZoneEffect au plus grand rayon autour du joueur.
func _mark_crue(p: Node2D) -> void:
	var best: Node = null
	for n in _all(get_tree().root):
		if n.get(&"radius") != null and n.get(&"spell") is SpellData and (n.get(&"spell") as SpellData).slot == 4:
			best = n
	_mark(best)


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out
