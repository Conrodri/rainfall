extends Node
## Retour joueur : un pickup aimanté ne doit jamais orbiter ni être « esquivé ».
## godot --headless --path game res://tests/pickup_chase_test.tscn  -> RESULT: OK
## Joueur factice qui fuit en zigzag à vitesse de roulade ; toutes les pièces/gemmes aimantées doivent
## être ramassées en moins de 1,5 s.

const RUN_SPEED := 900.0 ## px/s : au-dessus de la roulade

var _pm: PickupManager
var _player: Node2D
var _t := 0.0
var _fails := 0


func _ready() -> void:
	_player = Node2D.new()
	_player.add_to_group("player")
	add_child(_player)
	_pm = PickupManager.new()
	add_child(_pm)
	for i in 24:
		var a := TAU * i / 24.0
		_pm.drop(Vector2.from_angle(a) * 120.0, PickupManager.KIND_GOLD if i % 2 == 0 else PickupManager.KIND_XP, 1.0)


func _process(delta: float) -> void:
	_t += delta
	# zigzag : change de cap toutes les 0,2 s (le pire cas pour une poursuite à accélération)
	var dir := Vector2.from_angle(PI * 0.5 * int(_t / 0.2))
	_player.position += dir * RUN_SPEED * delta
	if _pm.active_count == 0 or _t > 1.5:
		var ok := _pm.active_count == 0
		print("  ", "ok  " if ok else "FAIL", " pickups aimantés tous ramassés en fuite (restants=%d, t=%.2f s)" % [_pm.active_count, _t])
		print("RESULT: ", "OK" if ok else "FAIL (1)")
		get_tree().quit(0 if ok else 1)
		set_process(false)
