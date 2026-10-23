extends Node
## Capture de contrôle de Bourbe (debug) : godot --path game --write-movie <dossier>/bourbe.png --fixed-fps 30
##   --resolution 1280x720 res://tests/bourbe_capture.tscn
## (s) : 0,3 monstres ; 0,6-1,5 Détacher ×3 (gifles auto) ; 3,0 Rappel ; 4,0 Bourbier ; 8,0 sortie ; 9,5 fin.
## Imprime « CAST frame=<n> <sort> ».

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.character = &"bourbe"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	_main.set(&"save_path", "user://test_capture_bourbe.json")
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)


func _cast(slot: int, label: String, aim: Variant = null) -> void:
	var p: Node2D = _main.player
	p.spells.aim_override = aim
	var ok: bool = p.spells.cast(slot)
	p.spells.aim_override = null
	print("CAST frame=%d %s ok=%s anim=%s hp=%.1f/%.1f" % [_frame, label, ok, p.action_base(), p.hp, p.max_hp])


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
		p.grant_invulnerability(3.0) # pas pendant le Bourbier : on veut voir l'invulnérabilité du kit
		p.set(&"auto_cast_spells", false)
		var cam: Camera2D = _main.camera
		if cam != null:
			cam.zoom = Iso.camera_zoom(1.25)
		var d: Director = _main.director
		d.spawning_enabled = false
		for v in [Vector2(80, 10), Vector2(-90, 40), Vector2(240, -60), Vector2(270, 40), Vector2(-220, -120), Vector2(40, 230), Vector2(300, 160)]:
			d.spawn_enemy(1, pp + v)
	if _step == 1 and _t > 0.6:
		_step = 2
		_cast(2, "detacher_1", pp + Vector2(260, -40))
	if _step == 2 and _t > 1.1:
		_step = 3
		_cast(2, "detacher_2", pp + Vector2(-220, -110))
	if _step == 3 and _t > 1.6:
		_step = 4
		_cast(2, "detacher_3", pp + Vector2(60, 230))
	if _step == 4 and _t > 3.0:
		_step = 5
		_cast(3, "rappel")
	if _step == 5 and _t > 4.0:
		_step = 6
		var d: Director = _main.director
		for v in [Vector2(150, 0), Vector2(-160, 60), Vector2(30, -170), Vector2(200, 120)]:
			d.spawn_enemy(1, pp + v)
		_cast(4, "bourbier")
	if _step == 6 and _t > 9.5:
		get_tree().quit()
