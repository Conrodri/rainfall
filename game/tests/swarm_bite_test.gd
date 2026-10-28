extends Node
## Test headless de la morsure de l'essaim (art/briefs/monsters_v2.md §5.1) : armement à l'allonge, coup
## SWARM_BITE_WINDUP_S plus tard, coup dans le vide si le joueur sort de l'allonge, au plus une morsure par
## CONTACT_INTERVAL (DPS immobile identique à l'ancien contact), anim d'attaque calée sur le coup.
## godot --headless --path game res://tests/swarm_bite_test.tscn

const U := 64.0
const DT := 1.0 / 60.0

var _fails := 0
var _director: Director
var _player: FakePlayer
var _pp := Vector2.ZERO


class FakePlayer extends Node2D:
	var hits := 0

	func take_damage(_amount: float, _source: Node = null) -> void:
		hits += 1


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _step(e: Enemy, pp: Vector2 = _pp) -> void:
	await get_tree().physics_frame
	e.tick(DT, _player, pp, Vector2.ZERO)


## Essaim posé à `dist_px` au-delà du contact, à l'est du joueur, prêt à mordre.
func _swarm(extra_px: float) -> Enemy:
	var e := _director.spawn_enemy(1, Vector2(-80 * U, -80 * U), false, [] as Array[StringName], 0)
	var contact := e.radius_px + Enemy.PLAYER_RADIUS_PX
	e.position = _pp + Vector2(contact + extra_px, 0.0)
	e._attack_cd = 0.0
	return e


func _run() -> void:
	RunState.level = 1
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	await get_tree().process_frame
	_director.process_mode = Node.PROCESS_MODE_DISABLED
	_player = FakePlayer.new()
	get_tree().root.add_child(_player)

	_check("constantes : fenêtre 0,35 s, allonge 0,25 u, pause 0,25 s", is_equal_approx(Enemy.BITE_IMPACT_GATE, 1.0 - 0.35) and is_equal_approx(Enemy.BITE_PAUSE_GATE, 0.40) and is_equal_approx(Enemy.BITE_REACH_PX, 0.25 * U))
	await _test_arm_and_hit()
	await _test_out_of_reach_never_arms()
	await _test_whiff()
	await _test_dps()

	_player.queue_free()
	_director.queue_free()
	await get_tree().process_frame
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _test_arm_and_hit() -> void:
	print("Armement à l'allonge puis coup")
	var e := _swarm(0.2 * U) # au-delà du contact, dans l'allonge
	var p0 := e.position
	var h0 := _player.hits
	await _step(e)
	_check("armé à _attack_cd = CONTACT_INTERVAL", absf(e._attack_cd - Enemy.CONTACT_INTERVAL) < 0.03, str(e._attack_cd))
	_check("aucun dégât à l'armement", _player.hits == h0)
	_check("anim de morsure jouée, calée sur le coup", String(e.visual.current_anim()).begins_with("attack_") and e.visual._timed_frame == 3 and absf(e.visual._sprite.speed_scale * Balance.SWARM_BITE_WINDUP_S - 3.0 / 12.0) < 0.02, "%s x%.2f" % [e.visual.current_anim(), e.visual._sprite.speed_scale])
	_check("teinte d'armement", e.visual._charge_mod != Color.WHITE)
	var frames := 1
	var moved := false
	while _player.hits == h0 and frames < 120:
		await _step(e)
		frames += 1
		moved = moved or e.position.distance_to(p0) > 0.01
	_check("immobile pendant l'armement", not moved, str(e.position - p0))
	_check("coup après %.2f s (attendu %.2f)" % [frames * DT, Balance.SWARM_BITE_WINDUP_S], _player.hits == h0 + 1 and absf(frames * DT - Balance.SWARM_BITE_WINDUP_S) <= 2.5 * DT)
	_check("teinte retirée au coup", e.visual._charge_mod == Color.WHITE)
	_check("petit recul", e.knockback_left().x > 0.0, str(e.knockback_left()))
	_director.release_enemy(e)


func _test_out_of_reach_never_arms() -> void:
	print("Hors allonge : pas d'armement")
	var e := _swarm(0.5 * U) # > allonge 0,25 u
	var h0 := _player.hits
	await _step(e)
	_check("pas armé hors allonge (_attack_cd reste <= 0)", e._attack_cd <= 0.0, str(e._attack_cd))
	_check("continue d'avancer", e.position.x < _pp.x + e.radius_px + Enemy.PLAYER_RADIUS_PX + 0.5 * U)
	_check("aucun dégât", _player.hits == h0)
	_director.release_enemy(e)


func _test_whiff() -> void:
	print("Coup dans le vide")
	var e := _swarm(0.1 * U)
	var h0 := _player.hits
	await _step(e)
	_check("armé", e._attack_cd > 0.9)
	# le joueur recule de 1 u pendant l'armement : hors allonge au moment du coup
	var gone := _pp + Vector2(-1.0 * U, 0.0)
	var frames := 1
	while e._attack_cd > Enemy.BITE_PAUSE_GATE - 0.02 and frames < 120:
		await _step(e, gone)
		frames += 1
	_check("morsure manquée : aucun dégât", _player.hits == h0)
	_check("pas de recul", e.knockback_left().length() < 0.01, str(e.knockback_left()))
	_check("teinte retirée", e.visual._charge_mod == Color.WHITE)
	_director.release_enemy(e)


func _test_dps() -> void:
	print("DPS joueur immobile = ancien contact (1 coup / CONTACT_INTERVAL)")
	var e := _swarm(0.0)
	var h0 := _player.hits
	for i in int(10.0 / DT):
		await _step(e)
	var n := _player.hits - h0
	_check("%d morsures en 10 s (10 attendues, 1 par seconde)" % n, n >= 9 and n <= 10, str(n))
	_director.release_enemy(e)
