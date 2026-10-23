extends Node
## Capture de contrôle d'Averse (modèle : capture_spell_fx.gd), debug seulement :
## godot --path game --write-movie <dossier>/averse.png --fixed-fps 30 --resolution 1280x720 res://tests/averse_capture.tscn
## (s) : 0,3 monstres (gouttes auto) ; 1,2 Vague (visée à droite) ; 2,4 Flaque-miroir (visée en bas-droite) ;
## 4,0 Crue à 100 d'eau ; 6,0 fin. Imprime « CAST frame=<n> <sort> ».

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.character = &"averse"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	_main.set(&"save_path", "user://test_capture_averse.json")
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)


func _cast(slot: int, label: String) -> void:
	var ok: bool = _main.player.spells.cast(slot)
	print("CAST frame=%d %s ok=%s anim=%s water=%.0f" % [_frame, label, ok, _main.player.action_anim(), _main.player.kit.water])


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
		p.kit.water = 100.0
		var cam: Camera2D = _main.camera
		if cam != null:
			cam.zoom = Iso.camera_zoom(1.3)
		var d: Director = _main.director
		d.spawning_enabled = false
		var pp := p.global_position
		for v in [Vector2(200, -30), Vector2(260, 60), Vector2(330, -80), Vector2(-200, 120), Vector2(150, 250), Vector2(-260, -160)]:
			d.spawn_enemy(1, pp + v)
	if _step == 1 and _t > 1.2:
		_step = 2
		p.spells.aim_override = p.global_position + Vector2(300, 0)
		_cast(2, "vague")
		p.spells.aim_override = null
	if _step == 2 and _t > 2.4:
		_step = 3
		p.spells.aim_override = p.global_position + Vector2(160, 200)
		_cast(3, "flaque_miroir")
		p.spells.aim_override = null
	if _step == 3 and _t > 4.0:
		_step = 4
		p.kit.water = 100.0
		_cast(4, "crue")
	if _step == 4 and _t > 6.0:
		get_tree().quit()
