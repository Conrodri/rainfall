extends Node
## Combo « L'étoile armée » de Rictus (docs/Design_Combos.md §5.1) : Doublures -> Éventail (charge) -> Toupie ;
## bonus dans la fenêtre seulement, ordre inverse valide, compensation de base, Levée qui détone.
## godot --headless --path game res://tests/rictus_combos_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
		return false

	func has_value(v: float) -> bool:
		for a in taken:
			if absf(float(a) - v) < 0.05:
				return true
		return false


const U := 64.0
const BASE := 12.0

var _fails := 0
var _player: CharacterBody2D
var _kit: RictusKit
var _junk: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _land_decoys() -> void:
	var rem1: float = _player.spells._remaining[1]
	var t := 0.0
	while _kit.decoys_pending() and t < 1.0:
		_player.spells._remaining[1] = 99.0
		_player.tick(0.01)
		t += 0.01
	_player.spells._remaining[1] = rem1


## Avance de n images physiques, kit piloté à la main (le joueur ne tourne pas seul), sort 1 suspendu.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		_player.spells._remaining[1] = 99.0
		_player.tick(1.0 / 60.0)


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	Decoy.clear_all()
	_kit.clear_transients()
	_kit.spin_left = 0.0
	_kit.stagger_left = 0.0
	_kit.lifting = false
	_kit._fan_watch = 0.0
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.reset_dodge()
	_player._invuln = 0.0


func _run() -> void:
	RunState.level = 1
	RunState.character = &"rictus"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as RictusKit
	_check("kit Rictus", _kit != null)

	print("Constantes et compensation")
	_check("DECOY_COEF 2,2 (-8 % sans combo)", is_equal_approx(RictusKit.DECOY_COEF, 2.2) and RictusKit.DECOY_COEF / 2.4 < 0.93)
	_check("charge +0,7 / vol 1,6 / Levée 2,4 u", is_equal_approx(RictusKit.DECOY_CHARGE_ADD, 0.7)
			and is_equal_approx(RictusKit.FLIGHT_CHARGED_COEF, 1.6) and is_equal_approx(RictusKit.LIFT_DETONATE_U, 2.4))
	_check("sans doublure : aucune fenêtre", not _kit.combo_ready(2) and not _kit.combo_ready(3))

	print("Doublures -> Éventail : charge")
	_reset()
	_player.spells.aim_override = Vector2(500, 0)
	_check("Doublures lancées", _player.spells.cast(4))
	_land_decoys()
	_check("6 doublures, aucune chargée", Decoy.live.size() == 6 and _kit.charged_decoys() == 0)
	_check("Éventail pulse (doublures à charger)", _kit.combo_ready(2) and not _kit.combo_ready(3))
	_check("Éventail lancé vers l'est", _player.spells.cast(2))
	await _frames(40)
	var n_ch := _kit.charged_decoys()
	_check("2-3 doublures chargées par la salve", n_ch >= 2 and n_ch <= RictusKit.CHARGE_MAX_PER_SALVE, str(n_ch))
	var east: Decoy = null
	var plain: Decoy = null
	for d in Decoy.live:
		if d.global_position.x > 1.0 * U and absf(d.global_position.y) < 8.0:
			east = d
		if d.charged <= 0.0:
			plain = d
	_check("la doublure est (sur la trajectoire) est chargée", east != null and east.charged > 0.0)
	_check("Toupie pulse (doublure chargée)", _kit.combo_ready(3))
	_check("une charge par doublure (pas de double charge)", east != null and not east.charge())
	_check("explosion chargée : DECOY_COEF + 0,7, méta combo", east != null and is_equal_approx(east.explode_spell.coef, RictusKit.DECOY_COEF + RictusKit.DECOY_CHARGE_ADD)
			and _kit.combo_hit(east.explode_spell, null))
	_check("vol chargé : 1,6", east != null and is_equal_approx(east.flight_spell.coef, RictusKit.FLIGHT_CHARGED_COEF))
	_check("doublure normale : 2,2 / vol 1,2, pas de combo", plain != null and is_equal_approx(plain.explode_spell.coef, RictusKit.DECOY_COEF)
			and is_equal_approx(plain.flight_spell.coef, RictusKit.FLIGHT_COEF) and not _kit.combo_hit(plain.explode_spell, null))
	_check("le sort partagé du kit reste intact (copie par doublure)", plain != null and east != null and plain.explode_spell != east.explode_spell)

	print("Fenêtre : bonus seulement sur une doublure chargée")
	var foe_c := _fake(east.global_position)
	var foe_p := _fake(plain.global_position)
	east.explode(east.explode_spell)
	plain.explode(plain.explode_spell)
	await _frames(3)
	_check("explosion chargée = 2,9 x base", foe_c.has_value((RictusKit.DECOY_COEF + RictusKit.DECOY_CHARGE_ADD) * BASE), str(foe_c.taken))
	_check("explosion normale = 2,2 x base", foe_p.has_value(RictusKit.DECOY_COEF * BASE), str(foe_p.taken))
	_check("doublure explosée : plus de charge possible", not east.charge())

	print("Éventail -> Toupie : vol chargé 1,6 puis explosion chargée")
	_reset()
	_player.spells.aim_override = Vector2(500, 0)
	_player.spells.cast(4)
	_land_decoys()
	_player.spells._remaining[2] = 0.0
	_player.spells.cast(2)
	await _frames(40)
	var path_foe := _fake(Vector2(3.0 * U, 0))
	_check("Toupie lancée", _player.spells.cast(3))
	await _frames(40)
	_check("vol chargé : 1,6 x base", path_foe.has_value(RictusKit.FLIGHT_CHARGED_COEF * BASE), str(path_foe.taken))
	_check("explosion chargée : 2,9 x base", path_foe.has_value((RictusKit.DECOY_COEF + RictusKit.DECOY_CHARGE_ADD) * BASE), str(path_foe.taken))
	_check("pas de vol normal sur la doublure chargée", not path_foe.has_value(RictusKit.FLIGHT_COEF * BASE), str(path_foe.taken))

	print("Ordre inverse : Toupie -> Doublures (valide, sans bonus)")
	_reset()
	_player.spells.aim_override = Vector2(500, 0)
	var rev_foe := _fake(Vector2(3.0 * U, 0))
	_check("Toupie d'abord", _player.spells.cast(3))
	_check("puis Doublures pendant la toupie", _player.spells.cast(4))
	_land_decoys()
	await _frames(40)
	_check("doublures expédiées sans charge : vol 1,2", rev_foe.has_value(RictusKit.FLIGHT_COEF * BASE), str(rev_foe.taken))
	_check("aucun vol à 1,6 (pas chargées)", not rev_foe.has_value(RictusKit.FLIGHT_CHARGED_COEF * BASE))

	print("Levée : détone les doublures proches")
	_reset()
	_player.spells.aim_override = Vector2(500, 0)
	_player.spells.cast(4)
	_land_decoys()
	var lift_foe := _fake(Vector2(1.2 * U, 0))
	_player.spells._remaining[1] = 99.0
	_player.set_physics_process(true)
	_check("Levée lancée", _player.dodge(Vector2.RIGHT))
	var t := 0
	await get_tree().physics_frame
	while (_kit.lifting or t < 3) and t < 80:
		await get_tree().physics_frame
		t += 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player.set_physics_process(false)
	_check("doublure à moins de 2,4 u de l'atterrissage détonée avant 3 s", lift_foe.has_value(RictusKit.DECOY_COEF * BASE), str(lift_foe.taken))
	_check("les doublures lointaines restent", Decoy.live.size() >= 2 and Decoy.live.size() < 6, str(Decoy.live.size()))
	_check("l'esquive elle-même ne blesse rien (une seule explosion sur l'ennemi)", lift_foe.taken.size() == 1, str(lift_foe.taken))

	_reset()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
