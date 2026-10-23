extends Node
## Capture de contrôle de la description des sorts en jeu (SpellHint).
## PC     : godot --path game --write-movie <dossier>/pc.png --fixed-fps 30 res://tests/capture_spell_tip.tscn
##          (survol de la case du sort 3 dans la barre)
## Mobile : idem avec `-- --mobile` (appui long simulé sur le bouton tactile du sort 4, l'ultime).
## Chronologie (s) : 1 survol / appui ; 2,5 fin (bulle visible sur les dernières images).

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
	var mobile := Platform.is_mobile()
	if mobile and Platform.input_mode != Platform.InputMode.TOUCH:
		Platform.set_input_mode(Platform.InputMode.TOUCH)
	if not mobile and Platform.input_mode != Platform.InputMode.KBM:
		Platform.set_input_mode(Platform.InputMode.KBM)
	if hud.pause_menu.is_open:
		hud.pause_menu._close()
	if get_tree().paused:
		get_tree().paused = false
	if _step == 0 and _t > 0.5:
		_step = 1
		_main.player.grant_invulnerability(1.0e6)
	var vp := get_viewport()
	var ft := vp.get_final_transform()
	if _step == 1 and _t > 1.0:
		_step = 2
	# aperçu mobile sur PC : la vraie souris peut repasser en clavier-souris et annuler l'appui -> on le repose
	if _step == 2 and mobile and not hud.spell_buttons[2].is_held():
		if true:
			var t := InputEventScreenTouch.new()
			t.index = 5
			t.pressed = true
			t.position = ft * hud.spell_buttons[2].get_global_rect().get_center()
			vp.push_input(t)
	if _step == 2 and not mobile:
		var mm := InputEventMouseMotion.new()
		mm.position = ft * hud.bar_buttons[2].get_global_rect().get_center()
		vp.push_input(mm)
	if _step == 2 and (_t > 2.5 and hud.spell_hint.tip.visible or _t > 8.0):
		print("bulle visible : ", hud.spell_hint.tip.visible, " rect ", hud.spell_hint.tip.get_global_rect(), " ecran ", vp.get_visible_rect())
		print(hud.spell_hint.text_content())
		get_tree().quit()
