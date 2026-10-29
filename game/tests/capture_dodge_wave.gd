extends Node
## Capture de contrôle : roulade d'Ardent (fantômes) et annonce de vague du Director (flèche au bord).
## godot --path game --write-movie <dossier>/f.png --fixed-fps 30 res://tests/capture_dodge_wave.tscn
## Chronologie (s) : 0,5 vague déclenchée ; 0,8 roulade par l'action `dodge` (+ move_right) ;
## 2,0 et 3,0 roulades directes (recharge remise à zéro pour la capture) ; 4,5 fin.

var _main: Node
var _t := 0.0
var _step := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = load("res://scenes/main.tscn").instantiate()
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	_main.set(&"run_seed", 2024)
	add_child(_main)


func _process(delta: float) -> void:
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud: Hud = _main.hud
	if hud.pause_menu.is_open:
		hud.pause_menu._close()
	var p: Node = _main.player
	var d: Director = _main.director
	if _step == 0 and _t > 0.5:
		_step = 1
		p.grant_invulnerability(1.0e6)
		d.wave_credits = 60.0
		print("vague : ", d.trigger_wave(), " côté ", d.last_wave_side)
	elif _step == 1 and _t > 0.8:
		_step = 2
		Input.action_press(&"move_right")
		Input.action_press(&"dodge")
	elif _step == 2 and _t > 0.9:
		_step = 3
		Input.action_release(&"dodge")
		Input.action_release(&"move_right")
		print("roulade par l'action : ", p.get_dodge_cooldown())
	elif _step == 3 and _t > 2.0:
		_step = 4
		p.reset_dodge()
		p.dodge(Vector2(-1, -0.4))
	elif _step == 4 and _t > 3.0:
		_step = 5
		p.reset_dodge()
		p.dodge(Vector2.DOWN)
	elif _step == 5 and _t > 4.5:
		get_tree().quit()
