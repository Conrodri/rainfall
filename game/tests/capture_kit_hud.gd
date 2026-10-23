extends Node
## Capture de contrôle du socle commun (jauge de ressource du kit, pastilles de charges, portrait) :
## godot --path game --resolution 1920x1080 res://tests/capture_kit_hud.tscn -- --char=tocsin --out=<png>
## Téléphone : ajouter `--mobile` (et --resolution 2400x1080). Lance les sorts 2 et 3 vers la droite, puis
## enregistre l'image à 1,6 s et quitte. Debug seulement ; sauvegarde dans user://test_capture_kit_hud.json.

var _main: Node
var _t := 0.0
var _step := 0
var _out := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cid := "ardent"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--char="):
			cid = a.substr(7)
		elif a.begins_with("--out="):
			_out = a.substr(6)
	RunState.character = StringName(cid)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	_main.set(&"run_seed", 2024)
	_main.set(&"save_path", "user://test_capture_kit_hud.json")
	add_child(_main)


func _process(delta: float) -> void:
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud: Hud = _main.hud
	if Platform.is_mobile() and Platform.input_mode != Platform.InputMode.TOUCH:
		Platform.set_input_mode(Platform.InputMode.TOUCH)
	elif not Platform.is_mobile() and Platform.input_mode != Platform.InputMode.KBM:
		Platform.set_input_mode(Platform.InputMode.KBM)
	if hud.pause_menu.is_open:
		hud.pause_menu._close()
	var p: Node2D = _main.player
	if _step == 0 and _t > 0.4:
		_step = 1
		p.grant_invulnerability(1.0e6)
		RunState.gold = 120.0 # Avare : de quoi lire sa jauge
		p.spells.aim_override = p.global_position + Vector2(4 * 64, 0)
		p.spells.cast(2)
	elif _step == 1 and _t > 0.8:
		_step = 2
		p.spells.cast(3)
	elif _step == 2 and _t > 1.6:
		_step = 3
		if _out != "":
			CaptureUtil.save_viewport(get_viewport(), _out)
		print("CAPTURE ", _out, " res=", KitResource.of(p))
		get_tree().quit()
