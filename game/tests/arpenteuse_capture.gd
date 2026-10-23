extends Node
## Capture de contrôle de l'Arpenteuse (debug seulement, modèle : capture_spell_fx.gd).
## godot --path game --write-movie <dossier>/arp.png --fixed-fps 30 --resolution 1280x720 res://tests/arpenteuse_capture.tscn
## Script (s) : 0,3 monstres ; 0,5-3,3 elle trace un carré (chaîne) ; 3,4 Boucle ; 3,6-5,0 marche ;
## 5,0 Piquet (visé en haut à droite) ; 5,1-6,6 balaie ; 6,7 Tendeur ; 8,2 fin.
## Imprime « CAST frame=<n> <sort> » pour retrouver les images autour d'un lancement.

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0
var _held: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.character = &"arpenteuse"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	_main.set(&"save_path", "user://test_capture_arpenteuse.json")
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)


func _cast(slot: int, label: String) -> void:
	var ok: bool = _main.player.spells.cast(slot)
	print("CAST frame=%d %s ok=%s anim=%s chain=%.1f u" % [_frame, label, ok, _main.player.action_anim(), _main.player.kit.chain_length() / 64.0])


func _hold(action: StringName) -> void:
	if _held != &"":
		Input.action_release(_held)
	_held = action
	if action != &"":
		Input.action_press(action)


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
			cam.zoom = Iso.camera_zoom(1.0)
		var d: Director = _main.director
		d.spawning_enabled = false
		var pp := p.global_position
		for v in [Vector2(130, 120), Vector2(190, 60), Vector2(90, 200), Vector2(-160, 40), Vector2(260, 220), Vector2(330, -60), Vector2(400, 40)]:
			d.spawn_enemy(1, pp + v)
	var seq := [[0.5, &"move_right"], [1.2, &"move_down"], [1.9, &"move_left"], [2.6, &"move_up"], [3.3, &""]]
	for s in seq:
		if _step == 1 and _t > float(s[0]) and _held != s[1] and (_t < float(s[0]) + 0.1):
			_hold(s[1])
	if _step == 1 and _t > 3.4:
		_step = 2
		_cast(2, "boucle")
	if _step == 2 and _t > 3.6:
		_step = 3
		_hold(&"move_right")
	if _step == 3 and _t > 5.0:
		_step = 4
		_hold(&"")
		p.spells.aim_override = p.global_position + Vector2(300, -120)
		_cast(3, "piquet")
		p.spells.aim_override = null
	if _step == 4 and _t > 5.1:
		_step = 5
		_hold(&"move_down")
	if _step == 5 and _t > 6.0:
		_step = 6
		_hold(&"move_left")
	if _step == 6 and _t > 6.7:
		_step = 7
		_hold(&"")
		_cast(4, "tendeur")
	if _step == 7 and _t > 8.2:
		get_tree().quit()
