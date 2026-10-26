extends Node
## Test headless de Bourbe (motte en vol) (docs/Design_Personnages.md §2.5) : stats, 4 sorts, masse (Détacher coûte 15 % des
## PV max en PV ACTUELS, PV max intacts, jamais mortel, relance après soin : retour joueur 22/10/2026),
## Détacher (charges, cloche, plouf, combat, retour), Rappel (traversée, recollage = PV rendus), motte écrasée
## (vase perdue), Bourbier (inciblable, zone, ralentissement, fusion, sortie à 4 mottes gratuites), anims, lumière.
## godot --headless --path game res://tests/bourbe_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var radius_px := 16.0

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func is_slowed() -> bool:
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


const U := 64.0
const BASE := 12.0

var _fails := 0
var _player: CharacterBody2D
var _kit: BourbeKit
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


## Avance joueur + mottes de `t` s (pas de 1/60), sort 1 suspendu.
func _advance(t: float, auto := false) -> void:
	var n := int(ceil(t * 60.0))
	for i in n:
		if not auto:
			_player.spells._remaining[1] = 99.0
		_player.tick(1.0 / 60.0)
		for m in _kit.mottes.duplicate():
			if is_instance_valid(m):
				m.step(1.0 / 60.0)
		if is_instance_valid(_kit.bog_zone): # zones pilotées à la main (pas de _process ici)
			_kit.bog_zone.step(1.0 / 60.0)
	if not auto:
		_player.spells._remaining[1] = 0.0


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.sunk_left = 0.0
	_kit.clear_transients()
	_kit.charges = BourbeKit.MAX_MOTTES
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.refresh_max_hp(true)
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player._invuln = 0.0
	_player._dodge_cd = 0.0


func _run() -> void:
	RunState.level = 1
	RunState.character = &"bourbe"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as BourbeKit
	var plouf := BourbeKit.MOTTE_LAND_COEF * BASE

	print("Motte détruite en vol : plouf à l'endroit où elle meurt")
	_reset()
	var near := _fake(Vector2(1.0 * U, 0))
	var m := _throw_and_wait_flight(Vector2(3.0 * U, 0))
	_check("motte en vol (FLY, en l'air)", m != null and m.state == BourbeMotte.State.FLY and m.airborne)
	_advance(0.05)
	_check("en vol : intouchable (tirs et provocation)", Decoy.hit_by(m.global_position, 4.0) == null and Decoy.nearest_to(m.global_position, 640.0) == null)
	m.take_damage(9999.0)
	_check("en vol : les dégâts reçus ne la tuent pas", m.state == BourbeMotte.State.FLY)
	m.die()
	_check("plouf appliqué à sa mort en vol", _has_hit(near, plouf), str(near.taken))
	_check("motte retirée", m.state == BourbeMotte.State.GONE and _kit.out_count() == 0)

	print("Auto déclenchée pendant le vol")
	_reset()
	var close := _fake(Vector2(1.5 * U, 0)) # dans la portée de la Gifle : l'auto part pendant le vol
	var far := _fake(Vector2(3.0 * U, 0)) # sous la zone d'atterrissage, hors Gifle (2,6 u)
	m = _throw_and_wait_flight(Vector2(3.0 * U, 0))
	_player.spells._remaining[1] = 0.0
	_advance(0.5, true) # auto active : Gifle pendant que la motte vole puis se bat
	_check("la Gifle a bien frappé pendant le vol", close.taken.size() >= 1)
	_check("la motte a atterri (FIGHT) et son plouf a touché", m.state == BourbeMotte.State.FIGHT and _has_hit(far, plouf), "%s %s" % [m.state, far.taken])
	_check("un seul plouf", _count_hits(far, plouf) == 1, str(far.taken))

	print("Rappel pendant le vol")
	_reset()
	var tgt := _fake(Vector2(1.0 * U, 0))
	m = _throw_and_wait_flight(Vector2(3.0 * U, 0))
	_advance(0.05)
	_kit._recall_all()
	_check("plouf appliqué au rappel en vol", _has_hit(tgt, plouf), str(tgt.taken))
	_check("la motte rentre (RECALL)", m.state == BourbeMotte.State.RECALL)

	print("Recollée en vol (Bourbier)")
	_reset()
	var tgt2 := _fake(Vector2(1.0 * U, 0))
	m = _throw_and_wait_flight(Vector2(3.0 * U, 0))
	_advance(0.05)
	m.merge()
	_check("plouf appliqué au recollage en vol", _has_hit(tgt2, plouf), str(tgt2.taken))

	_reset()
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## Lance une motte vers `aim` et avance jusqu'à ce qu'elle soit en vol (impact de l'anim passé).
func _throw_and_wait_flight(aim: Vector2) -> BourbeMotte:
	_player.spells.aim_override = aim
	_player.spells._remaining[2] = 0.0
	_player.spells.cast(2)
	for i in 120:
		_advance(1.0 / 60.0)
		if _kit.out_count() > 0:
			return _kit.mottes[0]
	return null


func _has_hit(e: FakeEnemy, amount: float) -> bool:
	return _count_hits(e, amount) > 0


func _count_hits(e: FakeEnemy, amount: float) -> int:
	var n := 0
	for a in e.taken:
		if _near(a, amount, 0.05):
			n += 1
	return n
