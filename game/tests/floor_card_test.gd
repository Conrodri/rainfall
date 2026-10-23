extends Node
## Carton de transition d'étage (lot M-C, docs/ux/Audit_Menus.md §3.3) sur la vraie scène de jeu.
## godot --headless --path game res://tests/floor_card_test.tscn

var _fails := 0
var _main: Node


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


## Attend `sec` secondes de temps de jeu (somme des delta de _process, comme le carton). Un SceneTreeTimer
## compte autrement quand une image est longue (génération de l'étage suivant, machine chargée) : le
## carton prenait alors 0,4-0,6 s de retard sur le minuteur et les vérifications tombaient trop tôt.
func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()


func _ready() -> void:
	Platform.set_input_mode(Platform.InputMode.KBM)
	_check(is_equal_approx(Balance.FLOOR_CARD_S, 2.2), "Balance.FLOOR_CARD_S = 2,2 s")
	_check(FloorCard.tip_for(2) != "", "une astuce existe pour l'étage 2")
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 777)
	add_child(_main)
	await _main.game_ready
	await _wait(0.2)
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	_check(_main.floor_card == null, "pas de carton à l'étage 1")
	_check(RunState.running, "le temps court à l'étage 1")

	stage.next_stage()
	var card: FloorCard = _main.floor_card
	_check(card != null and RunState.stage == 2, "next_stage -> carton de l'étage 2")
	if card != null:
		var t: Array = card.texts()
		var expected := FloorPlan.display_name(2)
		_check(String(t[0]) == "ÉTAGE 2" and expected.ends_with(String(t[1])) and String(t[1]) != "", "titre et biome = FloorPlan.display_name (%s / %s)" % [t[0], t[1]])
		_check(String(t[2]) != "", "astuce affichée")
	_check(not RunState.running, "RunState.running == false pendant le carton")
	_check(player.has_method(&"is_invulnerable") and player.is_invulnerable(), "joueur invulnérable pendant le carton")
	_check(player.global_position.distance_to(stage.map.to_global(stage.map.get_player_start())) < 200.0, "joueur posé au départ de l'étage")
	await _wait(1.0)
	_check(not RunState.running and is_instance_valid(card), "toujours figé à 1 s")
	await _wait(Balance.FLOOR_CARD_S + Balance.FLOOR_FADE_IN_S - 1.0 + 0.5)
	_check(RunState.running, "le temps repart après le carton")
	_check(not is_instance_valid(_main.floor_card), "carton retiré")
	_check(player.is_invulnerable(), "protection d'arrivée (1,5 s) active")

	# passer le carton : pas avant 0,8 s, ensuite oui
	stage.floor_cleared = true
	stage.next_stage()
	card = _main.floor_card
	card.skip()
	_check(not card.is_done() and not RunState.running, "skip refusé avant 0,8 s")
	await _wait(Balance.FLOOR_CARD_SKIP_AFTER_S + 0.1)
	card.skip()
	await _wait(Balance.FLOOR_FADE_IN_S + 0.4)
	_check(RunState.running and not is_instance_valid(_main.floor_card), "carton passé après 0,8 s")

	# sauvegarde : un carton en cours ne change pas les données
	var save: Dictionary = _main.build_save_data()
	_check(int((save.get("run", {}) as Dictionary).get("stage", 0)) == 3, "sauvegarde cohérente à l'étage 3")

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
