extends Node
## Combos de Rictus. Kit de base : « Fil, lame, saccade » (docs/Design_Rictus_v2.md §3.3) : Couteau ficelé -> demi-lunes
## (tours) -> Doublures autour du ficelé -> Saccade (arrachement 1,4 + 0,25/tour, retour qui traverse, doublures +30 %,
## sort 2 prêt). Variantes Éventail + Toupie : « L'étoile armée » conservée (docs/Design_Combos.md §5.1) : Doublures ->
## Éventail (charge) -> Toupie ; ordre inverse valide, Levée qui détone, scie de la Toupie sur le ficelé.
## godot --headless --path game res://tests/rictus_combos_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var active := true
	var pulled := Vector2.ZERO

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
		return false

	func push(offset_px: Vector2) -> void:
		pulled += offset_px

	func has_value(v: float) -> bool:
		for a in taken:
			if absf(float(a) - v) < 0.05:
				return true
		return false

	func count_of(v: float) -> int:
		var n := 0
		for a in taken:
			if absf(float(a) - v) < 0.05:
				n += 1
		return n

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


const U := 64.0
const BASE := 12.0
const DT := 1.0 / 60.0

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
		_player.tick(DT)


## Avance à la main (couteau puis kit) sans attendre de frame moteur.
func _drive(seconds: float, until := Callable()) -> void:
	for i in int(ceil(seconds * 60.0 - 0.0001)):
		_player.spells._remaining[1] = 99.0
		if _kit.knife != null and is_instance_valid(_kit.knife):
			_kit.knife.step(DT)
		_player.tick(DT)
		if until.is_valid() and bool(until.call()):
			break


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
	_player.spells.manual_aim_enabled = true
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.reset_dodge()
	_player._invuln = 0.0


func _make_player() -> void:
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as RictusKit
	_check("kit Rictus", _kit != null)


## Doublures autour du centre (0,5 u, 0) sans curseur : un pion éphémère sert de « paquet » (en headless la souris
## n'est pas à l'origine, donc pas de visée manuelle). Le pion est retiré ensuite.
func _decoys_east() -> void:
	_player.spells.manual_aim_enabled = false
	var pawn := _fake(Vector2(0.5 * U, 0))
	_check("Doublures lancées", _player.spells.cast(4))
	_land_decoys()
	pawn.remove_from_group("enemies")
	pawn.queue_free()
	_player.spells.manual_aim_enabled = true


func _run() -> void:
	RunState.level = 1
	RunState.character = &"rictus"
	RunState.loadout = {}
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	await _make_player()

	print("Constantes et compensation (kit de base)")
	_check("DECOY_COEF 1,8 (2,2 -> 1,8 : compensation du monocible)", is_equal_approx(RictusKit.DECOY_COEF, 1.8))
	_check("détonation +30 %, Levée 2,4 u", is_equal_approx(RictusKit.DECOY_FICELE_MULT, 1.3) and is_equal_approx(RictusKit.LIFT_DETONATE_U, 2.4))
	_check("sans cible ni doublure : aucune fenêtre", not _kit.combo_ready(2) and not _kit.combo_ready(3))

	print("Fil, lame, saccade : séquence complète sur un ficelé")
	_reset()
	var boss := _fake(Vector2(1.5 * U, 0))
	boss.add_to_group("bosses")
	_player.spells.aim_override = Vector2(500, 0)
	_check("1. Couteau ficelé", _player.spells.cast(2))
	_player.spells.aim_override = null
	_drive(1.0, func() -> bool: return _kit.ficele_enemy() == boss)
	_check("fenêtre ouverte : la Saccade pulse", _kit.combo_ready(3))
	for i in 3:
		_player.spells._remaining[1] = 0.0
		_player.spells.cast(1)
	_check("2. trois demi-lunes : 3 tours", _kit.tours == 3, str(_kit.tours))
	_player.spells.manual_aim_enabled = false
	_check("3. Doublures autour du ficelé", _player.spells.cast(4))
	_land_decoys()
	_player.spells.manual_aim_enabled = true
	_check("6 doublures posées", Decoy.live.size() == 6)
	var total0: float = boss.total()
	boss.taken.clear()
	var combo_hits := [0]
	_player.spells.spell_hit.connect(func(sp: SpellData, _e: Node, _a: float) -> void:
		if sp.has_meta(&"combo"):
			combo_hits[0] += 1)
	_check("4. Saccade", _player.spells.cast(3))
	_check("arrachement (3 tours) + 6 doublures x1,3 (doublures ficelées)", boss.count_of((RictusKit.SACCADE_COEF + 3.0 * RictusKit.SACCADE_TOUR_ADD) * BASE) == 1 and boss.count_of(1.8 * 1.3 * BASE) == 6, str(boss.taken))
	_check("boss : jamais tiré", boss.pulled == Vector2.ZERO)
	_check("les 6 détonations portent la méta combo (couleur d'accent)", combo_hits[0] == 6, str(combo_hits[0]))
	_drive(1.5, func() -> bool: return _kit.knife_in_hand())
	_check("5. sort 2 prêt aussitôt (boucle fermée)", _kit.knife_in_hand() and not _player.spells.is_slot_blocked(2))
	_check("gain de la fenêtre : la séquence vaut bien plus que le sort 2 seul", boss.total() + total0 > 4.0 * 2.0 * BASE, str(boss.total() + total0))

	print("Détonation sans ficelé : pas de bonus, pas de couleur de combo")
	_reset()
	var foe := _fake(Vector2(1.0 * U, 0))
	_decoys_east()
	var det_before := Decoy.live.size()
	var plain: SpellData = Decoy.live[0].explode_spell
	_check("doublures posées sans ficelé", det_before == 6 and not _kit.combo_hit(plain, null))
	_check("Saccade grisée (couteau en main) : ordre inverse = rien", _player.spells.is_slot_blocked(3) and not _player.spells.cast(3))
	foe.global_position = Vector2(0.5 * U, 0)
	_player.spells.aim_override = Vector2(500, 0)
	_player.spells.cast(2)
	_player.spells.aim_override = null
	_drive(1.0, func() -> bool: return _kit.kstate != RictusKit.K.FLYING)
	foe.taken.clear()
	_check("Saccade après coup : lancée", _player.spells.cast(3))
	_check("doublures déjà posées détonées avec le +30 % (cible ficelée au moment de la Saccade)", foe.count_of(1.8 * 1.3 * BASE) >= 1 and Decoy.live.is_empty(), str(foe.taken))

	print("Levée : détone les doublures proches (kit de base)")
	_reset()
	_decoys_east()
	var lift_foe := _fake(Vector2(1.7 * U, 0))
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
	_check("doublures proches de l'atterrissage détonées avant 3 s", lift_foe.has_value(RictusKit.DECOY_COEF * BASE), str(lift_foe.taken))
	_check("les doublures lointaines restent", Decoy.live.size() >= 1 and Decoy.live.size() < 6, str(Decoy.live.size()))
	var only_blasts := true
	for a in lift_foe.taken:
		only_blasts = only_blasts and absf(float(a) - RictusKit.DECOY_COEF * BASE) < 0.05
	_check("l'esquive elle-même ne blesse rien (que des explosions)", only_blasts, str(lift_foe.taken))

	_reset()
	_player.queue_free()
	await get_tree().process_frame

	# --- variantes Éventail + Toupie : l'étoile armée --------------------------------------------------------
	RunState.loadout = {2: &"rictus_eventail", 3: &"rictus_toupie"}
	await _make_player()
	print("Variantes Éventail + Toupie")
	_check("sorts équipés", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["dagues_demi_lune", "rictus_eventail", "rictus_toupie", "doublures"])
	_check("le sort 2 (Éventail) n'exige pas de couteau en main", not _player.spells.is_slot_blocked(2) and not _player.spells.is_slot_blocked(3))
	_check("charge +0,7 / vol 1,6", is_equal_approx(RictusKit.DECOY_CHARGE_ADD, 0.7) and is_equal_approx(RictusKit.FLIGHT_CHARGED_COEF, 1.6))
	_check("sans doublure : aucune fenêtre", not _kit.combo_ready(2) and not _kit.combo_ready(3))

	print("Doublures -> Éventail : charge")
	_reset()
	_decoys_east()
	_check("6 doublures, aucune chargée", Decoy.live.size() == 6 and _kit.charged_decoys() == 0)
	_check("Éventail pulse (doublures à charger)", _kit.combo_ready(2) and not _kit.combo_ready(3))
	_player.spells.aim_override = Vector2(500, 0)
	_check("Éventail lancé vers l'est", _player.spells.cast(2))
	await _frames(40)
	_player.spells.aim_override = null
	var n_ch := _kit.charged_decoys()
	_check("2-3 doublures chargées par la salve", n_ch >= 2 and n_ch <= RictusKit.CHARGE_MAX_PER_SALVE, str(n_ch))
	var east: Decoy = null
	var plain_d: Decoy = null
	for d in Decoy.live:
		if d.global_position.x > 1.0 * U and absf(d.global_position.y) < 8.0:
			east = d
		if d.charged <= 0.0:
			plain_d = d
	_check("la doublure est (sur la trajectoire) est chargée", east != null and east.charged > 0.0)
	_check("Toupie pulse (doublure chargée)", _kit.combo_ready(3))
	_check("une charge par doublure (pas de double charge)", east != null and not east.charge())
	_check("explosion chargée : DECOY_COEF + 0,7, méta combo", east != null and is_equal_approx(east.explode_spell.coef, RictusKit.DECOY_COEF + RictusKit.DECOY_CHARGE_ADD)
			and _kit.combo_hit(east.explode_spell, null))
	_check("vol chargé : 1,6", east != null and is_equal_approx(east.flight_spell.coef, RictusKit.FLIGHT_CHARGED_COEF))
	_check("doublure normale : 1,8 / vol 1,2, pas de combo", plain_d != null and is_equal_approx(plain_d.explode_spell.coef, RictusKit.DECOY_COEF)
			and is_equal_approx(plain_d.flight_spell.coef, RictusKit.FLIGHT_COEF) and not _kit.combo_hit(plain_d.explode_spell, null))
	_check("le sort partagé du kit reste intact (copie par doublure)", plain_d != null and east != null and plain_d.explode_spell != east.explode_spell)
	var foe_c := _fake(east.global_position)
	var foe_p := _fake(plain_d.global_position)
	east.explode(east.explode_spell)
	plain_d.explode(plain_d.explode_spell)
	await _frames(3)
	_check("explosion chargée = 2,5 x base", foe_c.has_value((RictusKit.DECOY_COEF + RictusKit.DECOY_CHARGE_ADD) * BASE), str(foe_c.taken))
	_check("explosion normale = 1,8 x base", foe_p.has_value(RictusKit.DECOY_COEF * BASE), str(foe_p.taken))

	print("Éventail -> Toupie : vol chargé 1,6 puis explosion chargée")
	_reset()
	_decoys_east()
	_player.spells.aim_override = Vector2(500, 0)
	_player.spells.cast(2)
	await _frames(40)
	_player.spells.aim_override = null
	var path_foe := _fake(Vector2(3.6 * U, 0))
	_check("Toupie lancée", _player.spells.cast(3))
	await _frames(40)
	_check("vol chargé : 1,6 x base", path_foe.has_value(RictusKit.FLIGHT_CHARGED_COEF * BASE), str(path_foe.taken))
	_check("explosion chargée : 2,5 x base", path_foe.has_value((RictusKit.DECOY_COEF + RictusKit.DECOY_CHARGE_ADD) * BASE), str(path_foe.taken))
	_check("pas de vol normal sur la doublure chargée", not path_foe.has_value(RictusKit.FLIGHT_COEF * BASE), str(path_foe.taken))

	print("Ordre inverse : Toupie -> Doublures (valide, sans bonus)")
	_reset()
	_check("Toupie d'abord", _player.spells.cast(3))
	_decoys_east() # pendant la toupie : percutées dès la pose
	var rev_foe := _fake(Vector2(3.6 * U, 0))
	await _frames(40)
	_check("doublures expédiées sans charge : vol 1,2", rev_foe.has_value(RictusKit.FLIGHT_COEF * BASE), str(rev_foe.taken))
	_check("aucun vol à 1,6 (pas chargées)", not rev_foe.has_value(RictusKit.FLIGHT_CHARGED_COEF * BASE))

	print("Toupie : un tick de scie par tick sur le ficelé")
	_reset()
	_player.queue_free()
	await get_tree().process_frame
	RunState.loadout = {3: &"rictus_toupie"} # Couteau ficelé + Toupie : pas de Saccade, le Montreur rappelle seul
	await _make_player()
	var rope := _fake(Vector2(2.0 * U, 0))
	_player.spells.aim_override = Vector2(500, 0)
	_player.spells.cast(2)
	_player.spells.aim_override = null
	_drive(1.0, func() -> bool: return _kit.ficele_enemy() == rope)
	_check("ficelé", _kit.ficele_enemy() == rope)
	rope.taken.clear()
	_player.spells.cast(3)
	var saw_hits := rope.count_of(RictusKit.SAW_COEF * BASE)
	_check("tick de Toupie initial = un tick de scie (0,4)", saw_hits == 1, str(rope.taken))
	_drive(2.6)
	_check("10 ticks de Toupie = 10 ticks de scie + 5 de la fenêtre normale", rope.count_of(RictusKit.SAW_COEF * BASE) >= 10, str(rope.count_of(RictusKit.SAW_COEF * BASE)))
	if _kit.knife != null and is_instance_valid(_kit.knife):
		_kit.knife.drop_at(rope.global_position)
	_drive(2.0, func() -> bool: return _kit.knife_in_hand())
	_check("sans Saccade : le Montreur rappelle le couteau seul", _kit.knife_in_hand())

	RunState.loadout = {}
	_reset()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

