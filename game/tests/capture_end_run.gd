extends Node
## Capture du récap de fin de run (victoire, compteur de rubis en cours à 0,6 s) sur la vraie scène de jeu.
## godot --path game --write-movie <dossier>/end.png --fixed-fps 30 res://tests/capture_end_run.tscn [-- --mobile]
## N'écrit ni le profil réel ni la sauvegarde réelle (chemins de test, écriture du profil coupée).

const SAVE := "user://test_capture_end_run.json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Profile.write_enabled = false
	Profile.reset()
	if Platform.is_mobile():
		get_window().size = Vector2i(1200, 540) # 20:9 (téléphone), base logique 2400×1080
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"run_seed", 4242)
	m.set(&"save_path", SAVE)
	add_child(m)
	await m.game_ready
	m.player.grant_invulnerability(1.0e6)
	for i in 50:
		await get_tree().process_frame
	RunState.stage = 3
	RunState.active_time_s = 642.0
	RunState.level = 18
	RunState.kills = 1204
	RunState.gold = 980.0
	for id in ["lentille_aiguisee", "sablier_fele", "tonique_vital"]:
		for k in 9:
			RunState.add_item(StringName(id))
	m.pillars_done = 7
	m.end_run(true)
	for i in 18: # 0,6 s à 30 i/s
		await get_tree().process_frame
	RunSave.delete(SAVE)
	get_tree().quit()
