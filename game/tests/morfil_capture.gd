extends Node
## Capture de contrôle de Taliant : godot --path game --write-movie <dossier>/morfil.png --fixed-fps 30
##   --resolution 1280x720 res://tests/morfil_capture.tscn
## (s) : 0,3 monstres ; autos (cercle / estoc) ; 1,2 Fauche-lune ; 2,4 aiguisage bas -> Aiguisage ;
## 3,4 Lames jumelles ; 3,8-5,5 autos doublées ; 5,0 Iaï ; 6,5 fin. Imprime « CAST frame=<n> <sort> ».

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.character = &"morfil"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	_main.set(&"save_path", "user://test_capture_morfil.json")
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)


func _cast(slot: int, label: String, aim: Variant = null) -> void:
	var p: Node2D = _main.player
	p.spells.aim_override = aim
	var ok: bool = p.spells.cast(slot)
	p.spells.aim_override = null
	print("CAST frame=%d %s ok=%s anim=%s aiguisage=%.0f" % [_frame, label, ok, p.action_base(), p.kit.sharpness])


func _process(delta: float) -> void:
	_frame += 1
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	var p: Node2D = _main.player
	var pp := p.global_position
	if _step == 0 and _t > 0.3:
		_step = 1
		p.grant_invulnerability(8.0)
		p.set(&"auto_cast_spells", false)
		var cam: Camera2D = _main.camera
		if cam != null:
			cam.zoom = Iso.camera_zoom(1.25)
		var d: Director = _main.director
		d.spawning_enabled = false
		for v in [Vector2(90, 10), Vector2(-100, 40), Vector2(150, -90), Vector2(170, 80), Vector2(-120, -110), Vector2(40, 150), Vector2(200, 10)]:
			d.spawn_enemy(1, pp + v)
	if _step == 1 and _t > 1.2:
		_step = 2
		_cast(2, "fauche_lune", pp + Vector2(200, 0))
	if _step == 2 and _t > 2.4:
		_step = 3
		p.kit.sharpness = 35.0
		_cast(3, "aiguisage")
	if _step == 3 and _t > 3.4:
		_step = 4
		var d: Director = _main.director
		for v in [Vector2(110, 0), Vector2(-120, 60), Vector2(30, -130), Vector2(140, 100), Vector2(-60, 140)]:
			d.spawn_enemy(1, pp + v)
		_cast(4, "lames_jumelles")
	if _step == 4 and _t > 5.0:
		_step = 5
		p.dodge(Vector2.RIGHT)
		print("DODGE frame=%d iai" % _frame)
	if _step == 5 and _t > 6.5:
		get_tree().quit()
