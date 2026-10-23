extends Node
## Capture de contrôle de Rainette (debug) : bonds, Langue auto, Gluant, Grand saut, Chant de crue.
## godot --path game --write-movie <dossier>/rainette.png --fixed-fps 30 --resolution 1280x720 res://tests/rainette_capture.tscn
## (s) : 0,3 monstres ; 0,4-1,3 bonds à droite (Langue auto) ; 1,5 Gluant ; 2,2 Grand saut ; 3,2 Chant de crue ;
## 3,5-5,4 bonds du chant à gauche ; 5,8 fin. Imprime « CAST frame=<n> ».

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.character = &"rainette"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	_main.set(&"save_path", "user://test_capture_rainette.json")
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)


func _cast(slot: int, label: String) -> void:
	var ok: bool = _main.player.spells.cast(slot)
	print("CAST frame=%d %s ok=%s anim=%s" % [_frame, label, ok, _main.player.action_anim()])


func _hold(action: StringName, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _process(delta: float) -> void:
	_frame += 1
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
		var cam: Camera2D = _main.camera
		if cam != null:
			cam.zoom = Iso.camera_zoom(1.3)
		var d: Director = _main.director
		d.spawning_enabled = false
		var pp := p.global_position
		for v in [Vector2(200, -60), Vector2(260, 40), Vector2(330, -20), Vector2(420, 60), Vector2(450, -50),
				Vector2(520, 10), Vector2(-150, 80), Vector2(380, 150)]:
			d.spawn_enemy(1, pp + v)
		_hold(&"move_right", true)
	if _step == 1 and _t > 1.3:
		_step = 2
		_hold(&"move_right", false)
	if _step == 2 and _t > 1.5:
		_step = 3
		p.spells.aim_override = p.global_position + Vector2(260, 0)
		_cast(3, "gluant")
		p.spells.aim_override = null
	if _step == 3 and _t > 2.2:
		_step = 4
		p.spells.aim_override = p.global_position + Vector2(300, 20)
		_cast(2, "grand_saut")
		p.spells.aim_override = null
	if _step == 4 and _t > 3.2:
		_step = 5
		_cast(4, "chant_de_crue")
	if _step == 5 and _t > 3.5:
		_step = 6
		_hold(&"move_left", true)
	if _step == 6 and _t > 5.4:
		_step = 7
		_hold(&"move_left", false)
	if _step == 7 and _t > 5.8:
		get_tree().quit()
