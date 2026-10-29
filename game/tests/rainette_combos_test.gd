extends Node
## Combos de Rainette (docs/Design_Combos.md §5.3) : Écrasement (Gluant -> Grand saut dans la flaque), Langue sur étourdi,
## ordre inverse sans bonus, Bond depuis le Gluant, compensation de base, Grand saut pendant le Chant = un seul impact (P5),
## combo_ready / auto_cast_ok.
## godot --headless --path game res://tests/rainette_combos_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var pushed := Vector2.ZERO
	var stunned := 0.0
	var radius_px := 20.0
	var tier := 2
	var hp := 100000.0
	var active := true
	var is_boss := false
	var is_elite := false

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)
		hp -= amount

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func push(v: Vector2) -> void:
		pushed += v

	func stun(s: float) -> void:
		stunned = maxf(stunned, s)

	func is_stunned() -> bool:
		return stunned > 0.0

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t

	func clear() -> void:
		taken.clear()
		pushed = Vector2.ZERO


const U := 64.0
const BASE := 12.0
const DT := 1.0 / 60.0

var _fails := 0
var _player: CharacterBody2D
var _kit: RainetteKit
var _junk: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _near(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _advance(seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		_player.spells._remaining[1] = 99.0
		_kit.locomote(Vector2.ZERO, DT)
		_player.tick(DT)
		for g in RainetteGoo.live:
			if is_instance_valid(g):
				g.step(DT)
		t += DT
	_player.spells._remaining[1] = 0.0


func _to_impact() -> void:
	var t := 0.0
	while _kit.has_pending() and t < 1.5:
		_player.spells._remaining[1] = 99.0
		_player.tick(DT)
		t += DT
	_player.spells._remaining[1] = 0.0


func _until_ground() -> void:
	var t := 0.0
	while _kit.state != RainetteKit.State.GROUND and t < 3.0:
		_advance(DT)
		t += DT


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.state = RainetteKit.State.GROUND
	_kit.state_left = 0.0
	_kit.hop_is_leap = false
	_kit.ult_left = 0.0
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.facing = Vector2.DOWN
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.reset_dodge()
	_player._invuln = 0.0


## Pose le Gluant à `at` (aucun monstre présent : pas d'éclaboussure).
func _make_goo(at: Vector2) -> RainetteGoo:
	_player.spells.aim_override = at
	_player.spells.cast(3)
	_to_impact()
	_player.spells._remaining[3] = 0.0
	return RainetteGoo.live[0] if not RainetteGoo.live.is_empty() else null


func _leap_to(at: Vector2) -> void:
	_player.spells.aim_override = at
	_player.spells.cast(2)
	_until_ground()


func _run() -> void:
	RunState.level = 1
	RunState.character = &"rainette"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit
	_check("kit Rainette", _kit is RainetteKit)

	print("Compensations de base")
	_check("LEAP 3,4 ; GOO_SPLASH 1,3 ; TONGUE 1,1", _near(RainetteKit.LEAP_COEF, 3.4) and _near(RainetteKit.GOO_SPLASH_COEF, 1.3) and _near(RainetteKit.TONGUE_COEF, 1.1))

	print("Écrasement : Gluant -> Grand saut dans la flaque")
	_reset()
	var goo := _make_goo(Vector2(220, 0))
	_check("flaque posée", goo != null and RainetteGoo.live.size() == 1)
	var glued := _fake(Vector2(300, 0))
	var outsider := _fake(Vector2(220, 180)) # dans le rayon du saut (3 u), hors de la flaque (2,5 u)
	var far := _fake(Vector2(0, 600))
	_check("combo_ready(2) : flaque à portée de saut", _kit.combo_ready(2) and not _kit.combo_ready(3))
	_leap_to(Vector2(220, 0))
	var expect_glued := (RainetteKit.LEAP_COEF + RainetteKit.CRUSH_ADD + RainetteKit.GOO_BURST_COEF) * BASE
	_check("collé : saut +0,3 puis éclat 1,2", _near(glued.total(), expect_glued), str(glued.taken))
	_check("collé étourdi 1,0 s", _near(glued.stunned, RainetteKit.CRUSH_STUN_S), str(glued.stunned))
	_check("hors flaque : saut seul, sans bonus", _near(outsider.total(), RainetteKit.LEAP_COEF * BASE) and outsider.taken.size() == 1, str(outsider.taken))
	_check("hors flaque étourdi 0,5 s", _near(outsider.stunned, RainetteKit.LEAP_STUN_S), str(outsider.stunned))
	_check("loin épargné", far.taken.is_empty())
	_check("flaque consommée", goo.is_ending() and not RainetteGoo.contains(Vector2(220, 0)))
	_check("plus de combo_ready(2) sans flaque", not _kit.combo_ready(2))

	print("Sans flaque : Grand saut nu")
	_reset()
	var lone := _fake(Vector2(220, 0))
	_leap_to(Vector2(220, 0))
	_check("coef 3,4, étourdi 0,5 s", _near(lone.total(), RainetteKit.LEAP_COEF * BASE) and _near(lone.stunned, 0.5), str(lone.taken))

	print("Ordre inverse : Grand saut -> Gluant")
	_reset()
	var pack := _fake(Vector2(220, 0))
	_leap_to(Vector2(220, 0))
	_check("saut : 3,4 sans bonus, étourdi 0,5 s", _near(pack.total(), RainetteKit.LEAP_COEF * BASE) and _near(pack.stunned, 0.5), str(pack.taken))
	pack.clear()
	_player.global_position = Vector2.ZERO
	_player.spells.aim_override = Vector2(220, 0)
	_player.spells.cast(3)
	_to_impact()
	_check("Gluant sur le paquet étourdi : éclaboussure 1,3 seule", _near(pack.total(), RainetteKit.GOO_SPLASH_COEF * BASE) and pack.taken.size() == 1, str(pack.taken))
	_check("la flaque reste (non consommée)", RainetteGoo.live.size() == 1 and not RainetteGoo.live[0].is_ending())

	print("Mini-flaque du Chœur : pas d'Écrasement")
	_reset()
	_kit._spawn_mini_goo(Vector2(220, 0))
	var minied := _fake(Vector2(220, 0))
	_leap_to(Vector2(220, 0))
	_check("saut nu sur mini-flaque", _near(minied.total(), RainetteKit.LEAP_COEF * BASE) and minied.taken.size() == 1, str(minied.taken))

	print("Langue sur étourdi / collé")
	_reset()
	var calm := _fake(Vector2(150, 0))
	_player.spells.cast(1)
	_to_impact()
	_check("cible calme : 1,1 sans traction supplémentaire", _near(calm.total(), RainetteKit.TONGUE_COEF * BASE) and calm.pushed.length() < 0.01, "%s %s" % [calm.taken, calm.pushed])
	_reset()
	var dazed := _fake(Vector2(150, 0))
	var dazed_line := _fake(Vector2(250, 0))
	dazed.stun(1.0)
	dazed_line.stun(1.0)
	_player.spells.cast(1)
	_to_impact()
	_check("cible principale étourdie : 1,6", _near(dazed.total(), RainetteKit.TONGUE_STUN_COEF * BASE), str(dazed.taken))
	_check("traction 0,75 u (0,5 u en plus)", _near(dazed.pushed.x, -(RainetteKit.TONGUE_STUN_PULL_U - RainetteKit.TONGUE_PULL_U) * U, 0.5), str(dazed.pushed))
	_check("reste de la ligne : coef de ligne inchangé", _near(dazed_line.total(), RainetteKit.TONGUE_LINE_COEF * BASE) and dazed_line.pushed.length() < 0.01, str(dazed_line.taken))
	_reset()
	var goo2 := _make_goo(Vector2(150, 0))
	var stuck := _fake(Vector2(150, 0))
	_player.spells.cast(1)
	_to_impact()
	_check("cible collée dans la flaque : 1,6", goo2 != null and _near(stuck.total(), RainetteKit.TONGUE_STUN_COEF * BASE), str(stuck.taken))

	print("Bond (esquive) depuis le Gluant")
	_reset()
	_check("hors flaque 3,5 u", _near(_kit.dodge_distance_u(), RainetteKit.BACK_HOP_U) and _near(_player.dodge_distance_u(), RainetteKit.BACK_HOP_U))
	_make_goo(Vector2(0, 0))
	_check("dans la flaque +50 %", _near(_kit.dodge_distance_u(), RainetteKit.BACK_HOP_U * 1.5) and _near(_player.dodge_distance_u(), RainetteKit.BACK_HOP_U * 1.5))

	print("auto_cast_ok(2)")
	_reset()
	_check("Gluant prêt : le saut part", _kit.auto_cast_ok(2))
	_player.spells._remaining[3] = 0.5
	_check("Gluant < 1 s, aucune flaque : le saut attend", not _kit.auto_cast_ok(2))
	_player.spells._remaining[3] = 4.0
	_check("Gluant loin : le saut part", _kit.auto_cast_ok(2))
	_player.spells._remaining[3] = 0.0
	_check("flaque posée avant le test", _make_goo(Vector2(150, 0)) != null)
	_player.spells._remaining[3] = 0.5
	_check("flaque posée : le saut part", _kit.auto_cast_ok(2))
	_check("autres slots jamais retenus", _kit.auto_cast_ok(3) and _kit.auto_cast_ok(4))

	print("P5 : Grand saut pendant le Chant = un seul impact")
	_reset()
	var singer := _fake(Vector2(220, 0))
	_kit._start_song()
	_leap_to(Vector2(220, 0))
	_check("un seul coup (celui du saut), pas de Chant par-dessus", singer.taken.size() == 1 and _near(singer.total(), RainetteKit.LEAP_COEF * BASE), str(singer.taken))

	_reset()
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
