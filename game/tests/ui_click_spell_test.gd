extends Node
## godot --headless --path game res://tests/ui_click_spell_test.tscn
## L'appui qui ferme une UI en pause (choix d'item, coffre, menu) ne lance pas de sort ; l'appui suivant, si.

var _fails := 0
var _player: CharacterBody2D


func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	_player = load("res://scenes/player/player.tscn").instantiate()
	get_tree().root.add_child(_player)
	await _frames(3)
	var sc: SpellCaster = _player.spells
	sc.set_cooldown(2, 0.0, 1.0)
	# appui qui ferme l'UI : pause pendant plusieurs images, reprise, appui dans la même image
	get_tree().paused = true
	await get_tree().create_timer(0.1, true).timeout
	get_tree().paused = false
	Input.action_press(&"spell_2")
	sc.tick(0.0) # même image physique que l'appui (just_pressed)
	Input.action_release(&"spell_2")
	_check(sc.cooldown_remaining(2) <= 0.0, "appui de reprise après pause : pas de sort")
	await _frames(3)
	Input.action_press(&"spell_2")
	sc.tick(0.0) # même image physique que l'appui (just_pressed)
	Input.action_release(&"spell_2")
	_check(sc.cooldown_remaining(2) > 0.0, "appui suivant en jeu : sort lancé")
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(1 if _fails else 0)
