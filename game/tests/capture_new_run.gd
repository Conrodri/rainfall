extends Node
## Capture du lot D : Nouvelle run (sélection, fiche ouverte, infobulle de quête) puis Progression.
## PC     : godot --path game --write-movie <dossier>/pc.png --fixed-fps 30 res://tests/capture_new_run.tscn
## Mobile : idem avec `-- --mobile` (tactile, appui long simulé).
## 20:9   : PC avec `--resolution 2400x1080` (largeur logique ≈ 2400).
## Chronologie (s) : 1 sélection ; 2 fiche d'Ardent ; 3 infobulle de quête (variante grisée) ; 4 Progression ;
## 5,5 fiche de Tocsin (3e carte).

## Profil factice : la capture ne lit ni n'écrit le vrai profil.
class FakeProfile extends RefCounted:
	var rubies := 4820
	var unlocked_modes: Array = ["facile", "moyen"]
	var unlocked_spells: Array = ["spell:meteor_rain"]
	var last_mode := "moyen"
	var last_character := "ardent"
	var stats := {"runs": 37, "victories": 5, "kills": 18423, "play_time_s": 43200.0, "best_time_s": {"facile": 812.0}}

	func is_unlocked(key: StringName) -> bool:
		return String(key) in unlocked_spells

var _t := 0.0
var _step := 0
var _screen: Control


func _ready() -> void:
	_screen = load("res://scenes/menu/new_run.tscn").instantiate()
	_screen.set("profile", FakeProfile.new())
	add_child(_screen)


func _process(delta: float) -> void:
	_t += delta
	if Platform.is_mobile() and Platform.input_mode != Platform.InputMode.TOUCH:
		Platform.set_input_mode(Platform.InputMode.TOUCH)
	var nr := _screen as NewRunScreen
	if _step == 0 and _t > 1.2:
		_step = 1
		nr.cards[0].pressed.emit()
	elif _step == 1 and _t > 2.2:
		_step = 2
		var b: Button = null
		for row in nr.sheet.focus_rows():
			for o in row:
				if o.name == "Variant_meteor_rain":
					b = o
		if Platform.is_mobile():
			var ev := InputEventScreenTouch.new()
			ev.pressed = true
			ev.position = b.get_global_rect().get_center()
			b.gui_input.emit(ev) # appui long : l'infobulle sort après 0,45 s
		else:
			b.grab_focus()
	elif _step == 2 and _t > 3.2:
		_step = 3
		_screen.queue_free()
		_screen = load("res://scenes/menu/progress.tscn").instantiate()
		_screen.set("profile", FakeProfile.new())
		add_child(_screen)
	elif _step == 3 and _t > 4.3:
		_step = 4
		_screen.queue_free()
		_screen = load("res://scenes/menu/new_run.tscn").instantiate()
		_screen.set("profile", FakeProfile.new())
		add_child(_screen)
	elif _step == 4 and _t > 4.8:
		_step = 5
		var nr2 := _screen as NewRunScreen
		nr2.cards[2].pressed.emit() # Tocsin : buste + masque d'émission
	elif _step == 5 and _t > 5.8:
		get_tree().quit()
