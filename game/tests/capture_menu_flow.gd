extends Node
## Capture du parcours complet sur app.tscn (lot F) : titre (0-3 s), Nouvelle run (3-5 s), chargement,
## ~2 s de jeu, pause, retour au titre (Reprendre).
## godot --path game --write-movie <dossier>/f.png --fixed-fps 30 --quit-after 360 res://tests/capture_menu_flow.tscn
## Sauvegarde et profil de test : la vraie sauvegarde de l'utilisateur n'est pas touchée.

const APP_SCENE := preload("res://scenes/app.tscn")
const TEST_SAVE := "user://capture_menu_flow.json"

var app: App
var _t := 0.0
var _step := 0
var _play_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # tourne aussi pendant la pause
	Profile.write_enabled = false
	RunSave.delete(TEST_SAVE)
	app = APP_SCENE.instantiate() as App
	app.save_path = TEST_SAVE
	add_child(app)


func _process(delta: float) -> void:
	_t += delta
	match _step:
		0:
			if _t >= 3.0 and not app.busy and app.current is TitleScreen:
				(app.current as TitleScreen).main_button.pressed.emit()
				_step = 1
		1:
			if _t >= 5.0 and not app.busy and app.current is NewRunScreen:
				(app.current as NewRunScreen).start_button.pressed.emit()
				_step = 2
		2:
			if app.main != null and bool(app.main.get(&"is_ready")):
				_play_t += delta
				if _play_t >= 2.0:
					app.main.get(&"hud").get(&"pause_menu").open()
					_play_t = 0.0
					_step = 3
		3:
			_play_t += delta
			if _play_t >= 1.0:
				app.main.get(&"hud").get(&"pause_menu").save_quit_requested.emit()
				_step = 4
		4:
			if _t > 11.9:
				RunSave.delete(TEST_SAVE)
