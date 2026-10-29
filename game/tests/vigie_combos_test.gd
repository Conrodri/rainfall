extends Node
## Combos de Vigie (docs/Design_Combos.md §5.6) : Filet -> Fusée (x1,25, filet +0,5 s) -> Allonge (2,6, ravive la fusée),
## ordre inverse sans x1,25, Grêle sur cloués (x1,4), Tir de signal sur déjà cloués (x1,2), Repli x3 -> ancrage sans délai,
## compensations, combo_ready / auto_cast_ok / is_marked.
## godot --headless --path game res://tests/vigie_combos_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var mods := {}
	var _held_left := 0.0
	var is_boss := false

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])
		if status == &"imprisoned":
			_held_left = maxf(_held_left, float(data.get("duration", 1.0)))

	func add_damage_taken_mod(id: Variant, mult: float, duration: float = -1.0) -> void:
		mods[id] = Vector2(mult, duration)

	func has_damage_taken_mod(id: Variant) -> bool:
		return mods.has(id)

	func is_imprisoned() -> bool:
		return _held_left > 0.0

	func is_slowed() -> bool:
		return false

	func expose_mult() -> float:
		return float(mods[VigieKit.EXPOSE_ID].x) if mods.has(VigieKit.EXPOSE_ID) else 0.0

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t

	func last() -> float:
		return float(taken[taken.size() - 1]) if not taken.is_empty() else 0.0


const U := 64.0
const BASE := 12.0

var _fails := 0
var _player: CharacterBody2D
var _kit: VigieKit
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


func _advance(t: float, moving := false) -> void:
	var n := roundi(t / 0.01)
	for i in n:
		_player.spells._remaining[1] = 99.0
		_player.is_moving = moving
		_player.tick(0.01)
		for f in _kit.flares:
			if is_instance_valid(f):
				f.set_process(false)
				f.step(0.01)
	_player.spells._remaining[1] = 0.0


func _reset(tension := 0.0) -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.set_tension(tension)
	_kit.still_t = 0.0
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.reset_dodge()
	_player._invuln = 0.0


func _hit(e: Node, s: SpellData) -> float:
	return _player.spells.deal_damage(e, s, {})


func _run() -> void:
	RunState.level = 1
	RunState.character = &"vigie"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as VigieKit
	_check("kit Vigie", _kit != null)

	print("Compensations de base")
	_check("ALLONGE 1,8 ; FUSEE 1,1 ; GRELE 0,64", _near(VigieKit.ALLONGE_COEF, 1.8) and _near(VigieKit.FUSEE_COEF, 1.1) and _near(VigieKit.GRELE_COEF, 0.64))

	print("Filet -> Fusée : exposition x1,25 et filet +0,5 s")
	_reset()
	var at := Vector2(5 * U, 0)
	var held1 := _fake(at + Vector2(10, 0))
	var held2 := _fake(at + Vector2(1.5 * U, 0))
	var lit_free := _fake(at + Vector2(0, 2.2 * U)) # dans la lumière (3 u), jamais cloué
	_check("aucune fenêtre avant le filet", not _kit.combo_ready(2) and not _kit.combo_ready(4))
	_kit.open_net(at)
	_check("filet : cloués 1,5 s", _near(held1._held_left, VigieKit.NET_HOLD_S) and _near(held2._held_left, VigieKit.NET_HOLD_S))
	_check("combo_ready : Fusée et Grêle pulsent, pas les autres", _kit.combo_ready(2) and _kit.combo_ready(4) and not _kit.combo_ready(3))
	var fl := _kit.plant_flare(held1.global_position) as VigieFlare
	_check("fusée posée sur un cloué : filet +0,5 s", _near(held1._held_left, VigieKit.NET_HOLD_S + VigieKit.NET_FLARE_EXTEND_S) and _near(held2._held_left, VigieKit.NET_HOLD_S + VigieKit.NET_FLARE_EXTEND_S), "%s %s" % [held1._held_left, held2._held_left])
	_check("cloués mémorisés par la fusée", fl.netted.has(held1.get_instance_id()) and fl.netted.has(held2.get_instance_id()) and not fl.netted.has(lit_free.get_instance_id()))
	_advance(0.3)
	_check("cloué sous la fusée : x1,25", _near(held1.expose_mult(), VigieKit.NET_FLARE_EXPOSE) and _near(held2.expose_mult(), VigieKit.NET_FLARE_EXPOSE), "%s" % held1.mods)
	_check("exposé non cloué : x1,1 comme avant", _near(lit_free.expose_mult(), VigieKit.EXPOSE_MULT))
	held2._held_left = 0.0 # le filet lâche
	_advance(0.3)
	_check("filet lâché : retour à x1,1", _near(held2.expose_mult(), VigieKit.EXPOSE_MULT), str(held2.expose_mult()))

	print("... -> Allonge sur exposé")
	var al := _kit.allonge_spell
	_check("allonge existe", al != null)
	var plain := _fake(Vector2(0, 6 * U))
	_check("sur exposé : 2,6", _near(_hit(held1, al), VigieKit.ALLONGE_EXPOSED_COEF * BASE, 0.05), str(held1.taken))
	_check("hors lumière : 1,8", _near(_hit(plain, al), VigieKit.ALLONGE_COEF * BASE, 0.05), str(plain.taken))
	_check("combo_hit seulement sur exposé", _kit.combo_hit(al, held1) and not _kit.combo_hit(al, plain))
	_check("la fusée est ravivée de 1 s", _near(fl.life, VigieKit.FLARE_LIFE_S + VigieKit.FLARE_REVIVE_S, 0.01), str(fl.life))
	_hit(held1, al) # même trait / même instant : pas de seconde avivée
	_check("une avivée par trait (250 ms)", _near(fl.life, VigieKit.FLARE_LIFE_S + VigieKit.FLARE_REVIVE_S, 0.01), str(fl.life))
	fl.life = 6.5
	await get_tree().create_timer(0.3).timeout
	_hit(held1, al)
	_check("plafond de vie 7 s", _near(fl.life, VigieKit.FLARE_MAX_LIFE_S, 0.01), str(fl.life))

	print("Ordre inverse : Fusée -> Filet")
	_reset()
	var rv1 := _fake(at + Vector2(10, 0))
	var rfl := _kit.plant_flare(at) as VigieFlare
	_advance(0.3)
	_check("exposé x1,1 sous la fusée", _near(rv1.expose_mult(), VigieKit.EXPOSE_MULT))
	_kit.open_net(at)
	_advance(0.3)
	_check("cloué après : toujours x1,1 (pas de x1,25)", rv1.is_imprisoned() and rfl.netted.is_empty() and _near(rv1.expose_mult(), VigieKit.EXPOSE_MULT), str(rv1.expose_mult()))
	_check("filet non prolongé", _near(rv1._held_left, VigieKit.NET_HOLD_S))
	_check("l'Allonge profite quand même de l'exposition", _near(_hit(rv1, al), VigieKit.ALLONGE_EXPOSED_COEF * BASE, 0.05))

	print("Fusée qui ne s'arrête pas sur un cloué")
	_reset()
	var far_held := _fake(at + Vector2(2.5 * U, 0))
	far_held.apply_status(&"imprisoned", {"duration": 1.5})
	var f3 := _kit.plant_flare(at) as VigieFlare
	_check("cloué à 2,5 u du point d'arrêt : pas d'effet", f3.netted.is_empty() and _near(far_held._held_left, 1.5))

	print("Grêle sur cloués")
	_reset()
	var hail := _kit._spell_of(4)
	var nailed := _fake(Vector2(3 * U, 0))
	nailed._held_left = 1.0
	var free := _fake(Vector2(3 * U, 3 * U))
	var hn := _hit(nailed, hail)
	var hf := _hit(free, hail)
	_check("cloué : x1,4", _near(hn, VigieKit.GRELE_COEF * VigieKit.HAIL_NETTED_MULT * BASE, 0.05), str(hn))
	_check("libre : coef nu", _near(hf, VigieKit.GRELE_COEF * BASE, 0.05), str(hf))

	print("Tir de signal : seulement les déjà cloués")
	_reset()
	var sig := VigieKit.variant(4, VigieKit.V_SIGNAL)
	_check("variante Signal", sig != null)
	if sig != null:
		var pre := _fake(at)
		pre._held_left = 0.5
		var fresh := _fake(at + Vector2(30, 0))
		_kit.signal_impact(sig, at)
		_check("déjà cloué : x1,2", _near(pre.last(), VigieKit.SIGNAL_COEF * VigieKit.SIGNAL_NETTED_MULT * BASE, 0.1), str(pre.taken))
		_check("cloué par le signal lui-même : coef nu", _near(fresh.last(), VigieKit.SIGNAL_COEF * BASE, 0.1), str(fresh.taken))

	print("Repli x3 -> Allonge sans délai d'ancrage")
	_reset()
	_kit.clear_transients()
	_advance(0.05, true) # en marche : pas ancrée
	_check("en marche : non ancrée", not _kit.is_anchored())
	var t0 := _kit.tension
	_kit.on_dodge_end(Vector2.ZERO, Vector2.ZERO)
	_advance(0.1, true)
	_kit.on_dodge_end(Vector2.ZERO, Vector2.ZERO)
	_check("après 2 replis : non ancrée", not _kit.is_anchored())
	_advance(0.1, true)
	_kit.on_dodge_end(Vector2.ZERO, Vector2.ZERO)
	_check("après le 3e : ancrée sans délai (still_t = 0)", _kit.is_anchored() and _kit.still_t < VigieKit.ANCHOR_DELAY_S)
	_check("Tension +24 % pour les 3", _near(_kit.tension - t0, 3.0 * VigieKit.DODGE_TENSION_GAIN, 0.2))
	_advance(VigieKit.ANCHOR_FREE_S + 0.1, true)
	_check("0,5 s plus tard : retour à la règle normale", not _kit.is_anchored())
	_kit.on_dodge_end(Vector2.ZERO, Vector2.ZERO)
	_advance(1.2, true)
	_kit.on_dodge_end(Vector2.ZERO, Vector2.ZERO)
	_advance(0.1, true)
	_kit.on_dodge_end(Vector2.ZERO, Vector2.ZERO)
	_check("série interrompue (> 1 s) : pas d'ancrage gratuit", not _kit.is_anchored())

	print("auto_cast_ok(2) et is_marked")
	_reset(0.2)
	_player.spells._remaining[3] = 0.3
	_check("Filet dans 0,3 s, Tension basse : la Fusée attend", not _kit.auto_cast_ok(2))
	_player.spells._remaining[3] = 0.0
	_check("Filet prêt : la Fusée part", _kit.auto_cast_ok(2))
	_player.spells._remaining[3] = 0.3
	_kit.set_tension(0.9)
	_check("Tension haute : la Fusée part", _kit.auto_cast_ok(2))
	_kit.set_tension(0.2)
	_kit.open_net(at)
	_check("filet déjà posé : la Fusée part", _kit.auto_cast_ok(2))
	var m1 := _fake(Vector2(0, 5 * U))
	var m2 := _fake(Vector2(0, -5 * U))
	m1._held_left = 1.0
	m2.add_damage_taken_mod(VigieKit.EXPOSE_ID, 1.1, 0.3)
	var m3 := _fake(Vector2(5 * U, 5 * U))
	_check("is_marked : cloués et exposés", _kit.is_marked(m1) and _kit.is_marked(m2) and not _kit.is_marked(m3))

	_reset()
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
