extends Node
## Capture du kit UI DA (lot UI-DA) : écran de coffre, menu principal, paramètres, récap de fin de run.
## godot --path game --write-movie <dossier>/f.png --fixed-fps 30 --resolution 1280x720 --quit-after 600 res://tests/capture_uida.tscn
## Chronologie (s) : 0-8 coffre (cartes visibles vers 5,5) ; 8-11 menu principal ; 11-14 paramètres ; 14-20 récap de fin.
## N'écrit ni le profil ni la sauvegarde réels ni les réglages.

const SAVE := "user://test_capture_uida.json"

var _t := 0.0
var _phase := 0
var _cur: Node
var _main: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Profile.write_enabled = false
	Profile.reset()
	GameSettings.cfg_path = "user://test_capture_uida_settings.cfg"
	GameSettings.set_value("gameplay", "help_shown", true) # pas d aide des commandes par-dessus le récap
	var ui: ChestUI = load("res://scenes/ui/chest/chest_ui.tscn").instantiate()
	_cur = ui
	add_child(ui)
	ui.open(&"large", 2, 0.0)


func _swap(path: String) -> void:
	get_tree().paused = false
	if is_instance_valid(_cur):
		_cur.queue_free()
	_cur = (load(path) as PackedScene).instantiate()
	add_child(_cur)


func _process(delta: float) -> void:
	_t += delta
	if _phase == 0 and _t >= 8.0:
		_phase = 1
		_swap("res://scenes/menu/title.tscn")
	elif _phase == 1 and _t >= 11.0:
		_phase = 2
		_swap("res://scenes/menu/settings.tscn")
	elif _phase == 2 and _t >= 14.0:
		_phase = 3
		get_tree().paused = false
		if is_instance_valid(_cur):
			_cur.queue_free()
		_main = load("res://scenes/main.tscn").instantiate()
		_main.set(&"run_seed", 4242)
		_main.set(&"save_path", SAVE)
		add_child(_main)
		await _main.game_ready
		_main.player.grant_invulnerability(1.0e6)
		RunState.stage = 3
		RunState.active_time_s = 642.0
		RunState.level = 18
		RunState.kills = 1204
		RunState.gold = 980.0
		for id in ["lentille_aiguisee", "sablier_fele", "tonique_vital"]:
			for k in 9:
				RunState.add_item(StringName(id))
		_main.pillars_done = 7
		_main.end_run(true)
