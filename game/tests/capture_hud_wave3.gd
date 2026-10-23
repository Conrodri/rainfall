extends Node
## Capture de contrôle du HUD vague 3 : difficulté sous la minimap, boss + mini-boss empilés en haut au centre,
## barres au-dessus de la tête, taux de régénération (HUD + menu pause). Debug seulement.
## godot --path game res://tests/capture_hud_wave3.tscn -- --out=<dossier> [--size=2400x1080] [--mobile] [--char=averse]
## Écrit <dossier>/<tag>_hud.png (2,6 s) et <tag>_pause.png (3,4 s).

var _main: Node
var _t := 0.0
var _step := 0
var _out := "user://"
var _tag := "pc"
var _size := Vector2i.ZERO
var _enemies: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cid := "averse"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			_size = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--char="):
			cid = a.substr(7)
	RunState.character = StringName(cid)
	_tag = "%s_%s" % ["mobile" if Platform.is_mobile() else "pc", cid]
	if _size != Vector2i.ZERO:
		_tag += "_%dx%d" % [_size.x, _size.y]
	_main = load("res://scenes/main.tscn").instantiate()
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	_main.set(&"run_seed", 2024)
	add_child(_main)


func _process(delta: float) -> void:
	if _size != Vector2i.ZERO and get_window().size != _size:
		get_window().size = _size
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud: Hud = _main.hud
	if Platform.is_mobile() and Platform.input_mode != Platform.InputMode.TOUCH:
		Platform.set_input_mode(Platform.InputMode.TOUCH)
	if _step < 3 and hud.pause_menu.is_open:
		hud.pause_menu._close()
	if _step == 0 and _t > 0.5:
		_step = 1
		var p: Node2D = _main.player
		p.grant_invulnerability(1.0e6)
		p.set(&"hp", float(p.get(&"max_hp")) * 0.62)
		var d: Director = _main.director
		var pp: Vector2 = p.global_position
		d.spawn_boss(&"etage", pp + Vector2(560, -280))
		d.spawn_boss(&"mini", pp + Vector2(-480, 220))
		for i in 4:
			_enemies.append(d.spawn_enemy(1 + i % 3, pp + Vector2.from_angle(i * TAU / 4.0 + 0.4) * 360.0, false))
		RunState.difficulty_changed.emit(4.4, &"Furieux")
	if _step == 1 and _t > 2.6:
		_step = 2
		_shot("hud")
	if _step == 2 and _t > 2.9:
		_step = 3
		hud.pause_menu.open()
	if _step == 3 and _t > 3.4:
		_step = 4
		_shot("pause")
		get_tree().quit()


func _shot(what: String) -> void:
	var path := _out.path_join("%s_%s.png" % [_tag, what])
	var img := CaptureUtil.save_viewport(get_viewport(), path)
	print("capture : ", path, " ", img.get_size())
