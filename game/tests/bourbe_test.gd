extends Node
## Test headless de Bourbe (docs/Design_Personnages.md §2.5) : stats, 4 sorts, masse (Détacher coûte 15 % des
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

	print("Personnage et rendu")
	_check("kit Bourbe (chargé par CharacterData.for_id)", _kit != null)
	_check("4 sorts / ids", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["gifle_de_vase", "detacher", "rappel", "bourbier"])
	_check("PV L1 = 150", _near(_player.max_hp, 150.0), str(_player.max_hp))
	_check("armure 10", _near(_player.armor(), 10.0))
	_check("régén 1,5", _near(_player.regen_per_s(), 1.5))
	_check("vitesse 3,6 u/s", _near(_player.move_speed(), 3.6 * U), str(_player.move_speed()))
	var shape := (_player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	var hb0 := shape.radius
	_check("roulade 2,5 u (CharacterData)", _near(_player.dodge_distance_u(), 2.5) and _near(_player.character.dodge_distance_u, 2.5))
	var follet := true
	for sp in BourbeKit.character().spells:
		follet = follet and String(sp.light_preset).begins_with("bourbe_") and LightRig.has_preset(sp.light_preset)
	_check("lumières des sorts : feu follet (presets présents)", follet)
	_check("preset motte présent", LightRig.has_preset(&"bourbe_motte"))
	var vis := _player.get_node("Visual") as AnimatedSprite2D
	if not ResourceLoader.exists(BourbeKit.SPRITE_FRAMES):
		_check("repli : Ardent teinté argile", vis.self_modulate.is_equal_approx(BourbeKit.PLACEHOLDER_TINT))

	print("Sort 1 : Gifle de vase")
	_reset()
	var front := _fake(Vector2(70, 0))
	var back := _fake(Vector2(-85, 0))
	var far := _fake(Vector2(140, 0))
	_check("gifle lancée", _player.spells.cast(1))
	_check("coef 1,0", _near(front.total(), BourbeKit.SLAP_COEF * BASE), str(front.taken))
	_check("rien derrière", back.taken.is_empty())
	_check("rien hors de 1,5 u", far.taken.is_empty())
	_check("anim d'action slap/attack", _player.action_base() in [&"slap", &"attack"], str(_player.action_base()))

	print("Sort 2 : Détacher")
	_reset()
	_player.spells.aim_override = Vector2(4 * U, 0)
	var near_land := _fake(Vector2(4 * U + 30, 0))
	_check("Détacher lancé", _player.spells.cast(2))
	_check("anim d'action throw/cast", _player.action_base() in [&"throw", &"cast"], str(_player.action_base()))
	_check("motte en attente de la frame d'impact", _kit.has_pending() and _kit.out_count() == 0)
	var t := 0.0
	while _kit.has_pending() and t < 1.0:
		_advance(1.0 / 60.0)
		t += 1.0 / 60.0
	_check("motte détachée à l'impact", _kit.out_count() == 1, str(_kit.out_count()))
	_check("impact avant 0,5 s", t < 0.5, str(t))
	_check("charges 3/4", _kit.charges == 3)
	_check("masse : PV max 150 -> 127,5 (15 %)", _near(_player.max_hp, 127.5), str(_player.max_hp))
	_check("PV actuels plafonnés au nouveau max (127,5)", _near(_player.hp, 127.5, 0.2), str(_player.hp))
	_check("hook de PV max (masse)", _kit.has_method(&"max_hp_mult"))
	_check("vitesse +0,15", _near(_player.move_speed(), 3.75 * U, 0.5), str(_player.move_speed() / U))
	_check("hitbox réduite", shape.radius < hb0, "%f < %f" % [shape.radius, hb0])
	var m: BourbeMotte = _kit.mottes[0]
	_check("motte = Decoy (provocation)", Decoy.live.has(m))
	_check("PV motte = 15 % de 150", _near(m.max_hp, 22.5))
	_advance(0.4)
	_check("motte atterrie au point visé", m.state == BourbeMotte.State.FIGHT and m.global_position.distance_to(Vector2(4 * U, 0)) < 4.0, str(m.global_position))
	_check("plouf à l'atterrissage (MOTTE_LAND_COEF)", near_land.taken.size() >= 1 and _near(near_land.taken[0], BourbeKit.MOTTE_LAND_COEF * BASE), str(near_land.taken))
	_advance(1.7)
	_check("coups de contact (MOTTE_CONTACT_COEF)", m.hits >= 2 and near_land.taken.has(BourbeKit.MOTTE_CONTACT_COEF * BASE), str(near_land.taken))

	print("Charges et plafond")
	for i in 3:
		_player.spells._remaining[2] = 0.0
		_player.spells.cast(2)
		_advance(0.4)
	_check("4 mottes dehors", _kit.out_count() == 4, str(_kit.out_count()))
	_check("4 mottes : PV max 60 (plancher 40 %), PV actuels plafonnés", _near(_player.max_hp, 60.0) and _player.hp <= 60.0 + 0.01, "%s / %s" % [_player.hp, _player.max_hp])
	_check("vitesse 4,2 à 4 mottes", _near(_player.move_speed(), 4.2 * U, 0.5), str(_player.move_speed() / U))
	_check("hitbox 0,45 u à 4 mottes", _near(shape.radius / hb0, 0.45 / 0.6, 0.01), str(shape.radius))
	_player.spells._remaining[2] = 0.0
	_check("Détacher bloqué à 4", _player.spells.is_slot_blocked(2))

	print("Sort 3 : Rappel")
	var line := _fake(Vector2(2 * U, 0))
	_player.spells._remaining[3] = 0.0
	_check("Rappel lancé", _player.spells.cast(3))
	_advance(0.6)
	_check("toutes recollées", _kit.out_count() == 0, str(_kit.out_count()))
	_check("PV max toujours 150", _near(_player.max_hp, 150.0), str(_player.max_hp))
	_check("recollées : PV actuels rendus", _player.hp > 140.0, str(_player.hp))
	var big := 0
	for a in line.taken:
		if _near(a, 1.5 * BASE):
			big += 1
	_check("traversée : coef 1,5 par motte", big >= 1, str(line.taken))
	_check("Rappel bloqué sans motte", _player.spells.is_slot_blocked(3))

	print("Motte écrasée")
	_reset()
	_player.spells.aim_override = Vector2(2 * U, 0)
	_player.spells.cast(2)
	_advance(0.6)
	m = _kit.mottes[0]
	m.take_damage(999.0)
	var hp_dead: float = _player.hp
	_check("motte morte", _kit.out_count() == 0 and _kit.mottes_died == 1)
	_check("hors de la provocation", not Decoy.live.has(m))
	_check("masse perdue : PV max encore réduits (127,5)", _near(_player.max_hp, 127.5), str(_player.max_hp))
	_advance(8.1)
	_check("masse rendue après 8 s", _near(_player.max_hp, 150.0), str(_player.max_hp))
	_check("vase perdue : rien n'est rendu (seule la régén remonte)", _player.hp <= hp_dead + _player.regen_per_s() * 8.2 + 0.5, "%s -> %s" % [hp_dead, _player.hp])

	print("Masse : Détacher jamais refusé à cause des PV")
	_reset()
	_player.spells.aim_override = Vector2(2 * U, 0)
	_player.hp = 0.2 * _player.max_hp
	_check("PV bas : Détacher permis", not _player.spells.is_slot_blocked(2) and _kit.can_detach())
	_check("Détacher lancé à PV bas", _player.spells.cast(2))
	_advance(0.5)
	_check("motte payée 15 % de masse, PV actuels >= 1", _kit.out_count() == 1 and _near(_player.max_hp, 127.5) and _player.hp >= 1.0, str(_player.hp))
	_player.heal(_player.max_hp)
	_player.spells._remaining[2] = 0.0
	_check("2e motte", _player.spells.cast(2))
	_advance(0.5)
	_check("2 mottes dehors, PV max 105", _kit.out_count() == 2 and _near(_player.max_hp, 105.0), str(_player.max_hp))
	var hurt: BourbeMotte = _kit.mottes[1]
	hurt.hp = hurt.max_hp * 0.5
	_check("recollage d'une motte à moitié : rend la moitié de la masse", _near(_kit.merge_mass(hurt), 0.075))

	print("Retour après 10 s")
	_reset()
	_player.spells.aim_override = Vector2(3 * U, 0)
	_player.spells.cast(2)
	_advance(0.6)
	_advance(BourbeKit.MOTTE_FIGHT_S)
	_advance(1.5)
	_check("motte revenue et recollée", _kit.out_count() == 0 and _kit.mottes_merged >= 1, str(_kit.out_count()))
	_check("PV max rendus", _near(_player.max_hp, 150.0))

	print("Sort 4 : Bourbier")
	_reset()
	_player.spells.aim_override = Vector2(3 * U, 0)
	_player.spells.cast(2)
	_advance(0.6)
	var inside := _fake(Vector2(3 * U, U))
	_check("Bourbier lancé", _player.spells.cast(4))
	_check("enfoncée : inciblable", _player.is_invulnerable() and _kit.is_sunk())
	_check("immobile", _near(_player.move_speed(), 0.0))
	_check("sorts et roulade bloqués", _player.spells.is_slot_blocked(1) and _player.spells.is_slot_blocked(2) and not _kit.can_dodge())
	_check("mottes fusionnées (vase rendue)", _kit.out_count() == 0 and _near(_player.max_hp, 150.0) and _player.hp > 148.0, str(_player.hp))
	_advance(0.5)
	_check("zone ouverte à l'impact", is_instance_valid(_kit.bog_zone))
	_advance(1.5)
	var dot := 0
	for a in inside.taken:
		if _near(a, BourbeKit.BOG_COEF * BASE):
			dot += 1
	_check("ticks BOG_COEF / 0,5 s", dot >= 3, str(inside.taken))
	var slowed := false
	for st in inside.statuses:
		slowed = slowed or (st[0] == &"slow" and _near(float(st[1]["pct"]), 0.5))
	_check("ralenti 50 %", slowed)
	_player.take_damage(50.0)
	_check("aucun dégât subi enfoncée", _near(_player.hp, 150.0, 1.0), str(_player.hp))
	_advance(2.1)
	_check("sortie : 2 mottes gratuites autour d'elle (audit 23/10)", _kit.out_count() == BourbeKit.RISE_FREE_MOTTES and not _kit.is_sunk(), str(_kit.out_count()))
	var free_ok := true
	for fm in _kit.mottes:
		free_ok = free_ok and fm.paid_hp == 0.0 and not fm.costed
	_check("gratuites : aucun PV payé", free_ok and _near(_player.hp, 150.0, 1.0), str(_player.hp))
	_advance(3.1)
	_check("toujours gratuites après 3 s (PV max 150)", _near(_player.max_hp, 150.0) and _player.hp > 148.0, str(_player.hp))

	print("Mort et étage")
	_kit._on_floor_started(2)
	_check("étage : mottes retirées, PV max 150", _kit.out_count() == 0 and _near(_player.max_hp, 150.0))
	_player.spells.aim_override = Vector2(2 * U, 0)
	_player.spells._remaining[2] = 0.0
	_player.spells.cast(2)
	_advance(0.6)
	var hp_out: float = _player.hp
	_kit._on_floor_started(3)
	_check("étage : la vase dehors rentre sans perte", _near(_player.hp, minf(hp_out + 22.5, 150.0), 1.0), "%s -> %s" % [hp_out, _player.hp])
	_player.spells.aim_override = Vector2(2 * U, 0)
	_player.spells._remaining[2] = 0.0
	_player.spells.cast(2)
	_advance(0.6)
	_kit._on_player_died()
	_check("mort : mottes retirées", _kit.out_count() == 0 and Decoy.live.is_empty())

	print("Équilibrage 22/10 : vase compacte, mottes qui provoquent les boss")
	_reset()
	_check("0 motte : −30 % de dégâts subis", is_equal_approx(_kit.damage_taken_mult(null), 1.0 - BourbeKit.COMPACT_REDUCTION))
	var lure := BourbeMotte.new()
	add_child(lure)
	lure.global_position = Vector2(50, 0)
	_check("motte : ne provoque plus les boss (audit 23/10)", not lure.lures_bosses and Decoy.nearest_boss_lure(Vector2.ZERO, Decoy.PROVOKE_RANGE_U * 64.0) == null)
	lure.queue_free()
	await get_tree().process_frame
	_reset()
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)
