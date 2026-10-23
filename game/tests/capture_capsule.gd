extends Node
## Capture de contrôle d'une capsule d'argent en jeu (fermée, puis ouverte).
## godot --path game --write-movie <dossier>/caps.png --fixed-fps 30 --quit-after 150 res://tests/capture_capsule.tscn

var _main: Node
var _t := 0.0
var _step := 0
var _cap: GoldCapsule


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 2024)
	add_child(_main)


func _process(delta: float) -> void:
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	if _main.hud.pause_menu.is_open:
		_main.hud.pause_menu._close() # pause automatique (fenêtre sans focus au lancement)
	if _step == 0:
		_step = 1
		_main.player.grant_invulnerability(1.0e6)
		var best := INF
		for c in get_tree().get_nodes_in_group(&"gold_capsules"):
			var d: float = c.global_position.distance_to(_main.player.global_position)
			if d < best:
				best = d
				_cap = c
		_main.player.global_position = _cap.global_position + Vector2(-210, 150)
		print("capsules: ", get_tree().get_nodes_in_group(&"gold_capsules").size(), " proche à ", best)
	if _step == 1 and _t > 1.5:
		_step = 2
		_main.player.global_position = _cap.global_position + Vector2(-40, 40)
	if _step == 2 and _t > 2.5:
		_step = 3
		print("interactable: ", _cap.can_interact(), " ", _cap.interact_label())
		Input.action_press("interact")
	if _step == 3 and _t > 2.6:
		Input.action_release("interact")
		_step = 4
	if _step == 4 and _t > 4.6:
		print("or: ", RunState.gold, " ouverte: ", _cap.is_opened())
		get_tree().quit()
