extends Node
## Capture de contrôle de Vigie (modèle : averse_capture.gd), debug seulement :
## godot --path game --write-movie <dossier>/vigie.png --fixed-fps 30 --resolution 1280x720 res://tests/vigie_capture.tscn
## (s) : 0,3 monstres (traits auto) ; 1,0 Fusée (visée à droite) ; 2,0 Filet (bas-droite) ; 2,6 Trait d'allonge
## (Tension pleine après le filet) ; 3,4 Grêle sur le paquet ; 6,5 fin. Imprime « CAST frame=<n> <sort> ».

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.character = &"vigie"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	_main.set(&"save_path", "user://test_capture_vigie.json")
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)


func _cast(slot: int, label: String) -> void:
	var ok: bool = _main.player.spells.cast(slot)
	print("CAST frame=%d %s ok=%s anim=%s tension=%.2f" % [_frame, label, ok, _main.player.action_base(), _main.player.kit.tension])


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
		for v in [Vector2(220, -30), Vector2(280, 40), Vector2(330, -80), Vector2(380, 20), Vector2(-200, 120), Vector2(150, 250), Vector2(200, 300), Vector2(-260, -160)]:
			d.spawn_enemy(1, pp + v)
	if _step == 1 and _t > 1.0:
		_step = 2
		p.spells.aim_override = p.global_position + Vector2(300, 0)
		_cast(2, "fusee")
		p.spells.aim_override = null
	if _step == 2 and _t > 2.0:
		_step = 3
		p.spells.aim_override = p.global_position + Vector2(170, 260)
		_cast(3, "filet")
		p.spells.aim_override = null
	if _step == 3 and _t > 2.6:
		_step = 4
		p.kit.set_tension(1.0)
		p.spells._remaining[1] = 0.0
		_cast(1, "allonge")
	if _step == 4 and _t > 3.4:
		_step = 5
		p.spells.aim_override = p.global_position + Vector2(300, 0)
		_cast(4, "grele")
		p.spells.aim_override = null
	if _step == 5 and _t > 6.5:
		get_tree().quit()
