extends Node
## Combos de Bourbe (docs/Design_Combos.md §5.5) : Gifle transmise (soin 10 %, coup suivant x3, une fois par motte et par 2 s),
## éclat des mottes au Bourbier, plouf de garde au Rappel, Coulée (mottes à 4,8 u/s), audit P4 (la vase ne provoque pas les boss).
## Bonus dans la fenêtre seulement, ordre inverse valide, compensation de base.
## godot --headless --path game res://tests/bourbe_combos_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var radius_px := 16.0

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


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _advance(t: float) -> void:
	var n := int(ceil(t * 60.0))
	for i in n:
		_player.spells._remaining[1] = 99.0
		_player.tick(1.0 / 60.0)
		for m in _kit.mottes.duplicate():
			if is_instance_valid(m):
				m.step(1.0 / 60.0)
		if is_instance_valid(_kit.bog_zone):
			_kit.bog_zone.step(1.0 / 60.0)
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
	_player.reset_dodge()


## Pose une motte à `at` (Détacher visé), atterrie et au combat, sans cible (attaque retenue).
func _motte_at(at: Vector2) -> BourbeMotte:
	_player.spells._remaining[2] = 0.0
	_player.spells.aim_override = at
	_player.spells.cast(2)
	_advance(0.45)
	_player.spells.aim_override = null
	var m: BourbeMotte = _kit.mottes[_kit.mottes.size() - 1]
	m._attack_cd = 99.0
	return m


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
	_check("kit Bourbe", _kit != null)

	print("Compensations de base")
	_check("SLAP_COEF 0,85, contact 0,35, Bourbier 1,1", is_equal_approx(BourbeKit.SLAP_COEF, 0.85)
			and is_equal_approx(BourbeKit.MOTTE_CONTACT_COEF, 0.35) and is_equal_approx(BourbeKit.BOG_COEF, 1.1))
	_check("constantes de combo", is_equal_approx(BourbeKit.SLAP_FEED_HEAL, 0.1) and is_equal_approx(BourbeKit.SLAP_FEED_MULT, 3.0)
			and is_equal_approx(BourbeKit.SLAP_FEED_CD_S, 2.0) and is_equal_approx(BourbeKit.FLOW_TRAIL_MOTTE_SPEED_U, 4.8)
			and is_equal_approx(BourbeKit.RECALL_HOME_U, 1.0) and is_equal_approx(BourbeKit.BOG_MOTTE_BURST_COEF, 1.0))
	_check("sans motte : aucune fenêtre", not _kit.combo_ready(1) and not _kit.combo_ready(3) and not _kit.combo_ready(4))

	print("Audit P4 : les mottes ne provoquent pas les boss")
	_reset()
	var m0 := _motte_at(Vector2(3.0 * U, 0))
	_check("lures_bosses faux", m0.lures_bosses == false)
	_check("aucun leurre de boss", Decoy.nearest_boss_lure(m0.global_position, 20.0 * U) == null)
	_check("mais provoque les monstres ordinaires", Decoy.nearest_to(m0.global_position, 1.0 * U) == m0)

	print("Gifle transmise : Détacher -> Gifle")
	_reset()
	var m := _motte_at(Vector2(2.0 * U, 0))
	var foe := _fake(Vector2(2.4 * U, 0))
	foe.taken.clear()
	m.hp = 10.0
	_check("Gifle pulse (motte à portée à nourrir)", _kit.combo_ready(1))
	_check("Gifle lancée", _player.spells.cast(1))
	_check("la gifle touche à 0,85 x base", foe.has_value(BourbeKit.SLAP_COEF * BASE), str(foe.taken))
	_check("motte nourrie", m.fed)
	_check("soin 10 % des PV max de la motte", absf(m.hp - (10.0 + 0.1 * m.max_hp)) < 0.01, str(m.hp))
	_check("plus de pulsation sur la motte déjà nourrie", not _kit.combo_ready(1))
	foe.taken.clear()
	m._attack_cd = 0.0
	_advance(0.1)
	_check("premier coup de contact x3 (1,05 coef)", foe.has_value(3.0 * BourbeKit.MOTTE_CONTACT_COEF * BASE), str(foe.taken))
	_check("motte plus nourrie après le coup", not m.fed)
	_check("chiffre de combo : le coup nourri porte la méta combo, pas le coup normal", _kit.combo_hit(_kit.fed_contact_spell(m), null) and not _kit.combo_hit(_kit._contact_spell, null))
	foe.taken.clear()
	m._attack_cd = 0.0
	_advance(0.1)
	_check("coup suivant normal (0,35)", foe.has_value(BourbeKit.MOTTE_CONTACT_COEF * BASE) and not foe.has_value(3.0 * BourbeKit.MOTTE_CONTACT_COEF * BASE), str(foe.taken))
	_player.spells._remaining[1] = 0.0
	_player.spells.cast(1)
	_check("2 s de délai : pas de re-nourrissage immédiat", not m.fed)
	_advance(2.1)
	m._attack_cd = 99.0
	_player.spells._remaining[1] = 0.0
	_player.spells.cast(1)
	_check("après 2 s : nourrie de nouveau", m.fed)

	print("Gifle : motte hors de l'arc ou hors de portée")
	_reset()
	var back := _motte_at(Vector2(-2.0 * U, 0))
	var foe2 := _fake(Vector2(1.5 * U, 0))
	foe2.taken.clear()
	back.global_position = Vector2(-2.0 * U, 0)
	_player.spells.cast(1)
	_check("motte derrière (hors de l'arc 210 degres) : pas nourrie", not back.fed)
	_reset()
	var farm := _motte_at(Vector2(4.5 * U, 0))
	var foe3 := _fake(Vector2(1.5 * U, 0))
	foe3.taken.clear()
	_player.spells.cast(1)
	_check("motte hors de 2,6 u : pas nourrie", not farm.fed)

	print("Ordre inverse : Gifle -> Détacher (valide, sans bonus)")
	_reset()
	var foe4 := _fake(Vector2(1.5 * U, 0))
	_check("Gifle sans motte", _player.spells.cast(1))
	_check("0,85 x base, rien de plus", foe4.has_value(BourbeKit.SLAP_COEF * BASE) and foe4.taken.size() == 1, str(foe4.taken))
	var m4 := _motte_at(Vector2(1.5 * U, 0))
	_check("la motte lancée ensuite n'est pas nourrie", not m4.fed)
	_check("mais le plouf tombe sur le paquet giflé", foe4.has_value(BourbeKit.MOTTE_LAND_COEF * BASE), str(foe4.taken))

	print("Bourbier : chaque motte éclate (1,0) avant de fusionner")
	_reset()
	var ma := _motte_at(Vector2(3.0 * U, 0))
	var mb := _motte_at(Vector2(0, 3.0 * U))
	var fa := _fake(ma.global_position)
	var fb := _fake(mb.global_position)
	_check("Bourbier pulse avec 2 mottes", _kit.combo_ready(4))
	_player.spells._remaining[4] = 0.0
	_check("Bourbier lancé", _player.spells.cast(4))
	_advance(0.1)
	_check("éclat 1,0 x base sur chaque motte", fa.has_value(BourbeKit.BOG_MOTTE_BURST_COEF * BASE) and fb.has_value(BourbeKit.BOG_MOTTE_BURST_COEF * BASE), "%s %s" % [fa.taken, fb.taken])
	_check("éclat marqué combo", _kit.combo_hit(_kit._bog_burst, null))
	_check("mottes fusionnées", _kit.out_count() == 0)
	_reset()
	var fz := _fake(Vector2(3.0 * U, 0))
	_player.spells._remaining[4] = 0.0
	_player.spells.cast(4)
	_advance(0.1)
	_check("sans motte : pas d'éclat", not fz.has_value(BourbeKit.BOG_MOTTE_BURST_COEF * BASE), str(fz.taken))

	print("Rappel : plouf de garde (motte à 1 u ou moins)")
	_reset()
	var mg := _motte_at(Vector2(0.5 * U, 0))
	var fg := _fake(Vector2(0.9 * U, 0))
	fg.taken.clear()
	_check("Rappel pulse (motte contre Bourbe)", _kit.combo_ready(3))
	_player.spells._remaining[3] = 0.0
	_check("Rappel lancé", _player.spells.cast(3))
	_advance(0.1)
	_check("plouf de garde 1,4 x base", fg.has_value(BourbeKit.MOTTE_LAND_COEF * BASE), str(fg.taken))
	_check("plouf marqué combo", _kit.combo_hit(_kit._land_guard, null))
	_reset()
	var mf := _motte_at(Vector2(3.0 * U, 0))
	var ff := _fake(Vector2(3.0 * U, 0))
	ff.taken.clear()
	_check("motte loin : pas de pulsation du Rappel", not _kit.combo_ready(3))
	_player.spells._remaining[3] = 0.0
	_player.spells.cast(3)
	_advance(0.03)
	_check("motte loin : pas de plouf de garde", not ff.has_value(BourbeKit.MOTTE_LAND_COEF * BASE), str(ff.taken))
	_check("motte loin rappelée", mf.state == BourbeMotte.State.RECALL or mf.state == BourbeMotte.State.GONE)

	print("Coulée : mottes dans la traînée à 4,8 u/s")
	_reset()
	var mt := _motte_at(Vector2(1.5 * U, 0))
	_check("vitesse normale 3,8 u/s", absf(mt._speed_px() - BourbeKit.MOTTE_SPEED_U * U) < 0.5)
	_kit._spawn_mud_trail(Vector2.ZERO, Vector2(3.0 * U, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("motte dans la traînée : 4,8 u/s", mt.flow_left > 0.0 and absf(mt._speed_px() - 4.8 * U) < 0.5, "%s %s" % [mt.flow_left, mt._speed_px()])
	_advance(0.7)
	_check("hors de la traînée / après 0,5 s : vitesse normale", mt.flow_left <= 0.0 and absf(mt._speed_px() - BourbeKit.MOTTE_SPEED_U * U) < 0.5)
	var far_m := _motte_at(Vector2(1.5 * U, 4.0 * U))
	far_m.flow_left = 0.0
	_kit.boost_mottes_on_segment(Vector2.ZERO, Vector2(3.0 * U, 0), 0.4 * U)
	_check("motte loin de la traînée : pas d'accélération", far_m.flow_left <= 0.0)
	_check("la Coulée ne blesse personne (aucun dégât direct)", _kit.has_method(&"dodge_label") and _kit.dodge_label() == "Coulée")

	_reset()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
