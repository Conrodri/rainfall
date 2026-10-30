extends Node
## Combos de Tocsin (docs/Design_Combos.md §5.2) : « La cloche sur le pilier » (Bras-pilier -> Tête-cloche : électrisés +50 %,
## le pilier sonne), « Le Coup qui fait sonner » (décharge 1,5, +2 ticks, bras au sol redressé), ramassage bridé (P7),
## Vapeur dans un pilier, ordre inverse sans bonus, compensations, combo_ready / auto_cast_ok / is_marked.
## godot --headless --path game res://tests/tocsin_combos_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var mods := {}

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func add_damage_taken_mod(id: Variant, mult: float, duration: float = -1.0) -> void:
		mods[id] = Vector2(mult, duration)

	func has_damage_taken_mod(id: Variant) -> bool:
		return mods.has(id)

	func is_slowed() -> bool:
		return false

	func last_slow_pct() -> float:
		for i in range(statuses.size() - 1, -1, -1):
			if statuses[i][0] == &"slow":
				return float(statuses[i][1]["pct"])
		return -1.0

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
var _kit: TocsinKit
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


func _fake(pos: Vector2, boss := false) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	if boss:
		e.add_to_group("bosses")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _sim(t: float) -> void:
	for i in int(ceil(t / DT)):
		_player.spells._remaining[1] = 99.0
		_player.tick(DT)
		for l in _kit.limbs.values():
			if is_instance_valid(l):
				l.set_physics_process(false)
				l.step(DT)


func _limb(key: StringName) -> TocsinLimb:
	var l: TocsinLimb = _kit.limbs.get(key)
	return l if l != null and is_instance_valid(l) else null


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.remove_from_group("bosses")
			j.queue_free()
	_junk.clear()
	_kit.regen_all()
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.is_moving = false
	_player.facing = Vector2.RIGHT
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_sim(0.5)


## Lance un bras sur (x u, 0) et avance jusqu'à la pose du pilier.
func _plant(x_u: float, key := &"arm_l") -> TocsinLimb:
	_player.spells.aim_override = Vector2(x_u * U, 0)
	_player.spells._remaining[2] = 0.0
	_player.spells.cast(2)
	var guard := 0.0
	while guard < 3.0:
		_sim(DT)
		guard += DT
		var l := _limb(key)
		if l != null and l.phase == TocsinLimb.Phase.PILLAR:
			return l
	return null


## Lance la Tête sur (x u, 0) et avance jusqu'à l'explosion (une entrée >= 8 x BASE chez `watch`) ; retourne la taille de
## `watch.taken` juste avant l'image de l'explosion.
func _throw_head(x_u: float, watch: FakeEnemy) -> int:
	_player.spells.aim_override = Vector2(x_u * U, 0)
	_player.spells._remaining[4] = 0.0
	_player.spells.cast(4)
	var prev := watch.taken.size()
	var guard := 0.0
	while guard < 4.0:
		prev = watch.taken.size()
		_sim(DT)
		guard += DT
		var hit_head := false
		for a in watch.taken.slice(prev):
			hit_head = hit_head or float(a) >= 8.0 * BASE
		if hit_head:
			break
	return prev


func _run() -> void:
	RunState.level = 1
	RunState.character = &"tocsin"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as TocsinKit
	_check("kit Tocsin", _kit != null)

	print("Compensations de base")
	_check("HEAD 9,0 ; TOLL 2,3 ; PILLAR 0,7", _near(TocsinKit.HEAD_COEF, 9.0) and _near(TocsinKit.TOLL_COEF, 2.3) and _near(TocsinKit.PILLAR_COEF, 0.7))

	print("Électrisé : chaque tick du pilier pose l'étiquette")
	_reset()
	var inside := _fake(Vector2(2.0 * U, 20))
	var outside := _fake(Vector2(2.0 * U, 4.0 * U))
	var pil := _plant(2.0)
	_check("pilier planté", pil != null)
	_check("dans la zone : électrisé (1,0 / 0,6 s)", inside.mods.has(TocsinKit.CHARGE_TAG) and _near(inside.mods[TocsinKit.CHARGE_TAG].y, 0.6) and _near(inside.mods[TocsinKit.CHARGE_TAG].x, 1.0), str(inside.mods))
	_check("hors zone : rien", outside.mods.is_empty())
	_check("is_marked suit l'étiquette", _kit.is_marked(inside) and not _kit.is_marked(outside))

	print("La cloche sur le pilier : Tête sur électrisés")
	_sim(1.0)
	var boss := _fake(Vector2(2.0 * U, -20), true)
	_sim(0.3) # le boss est électrisé à son tour
	_check("combo_ready(4) : pilier en décharge à portée", _kit.combo_ready(4))
	var prev := _throw_head(2.0, inside)
	var new_hits: Array = inside.taken.slice(prev)
	var ring_expect: float = minf(TocsinKit.PILLAR_COEF * float(TocsinKit.PILLAR_TICKS - prev), TocsinKit.PILLAR_RING_CAP)
	_check("électrisé : Tête x1,5", new_hits.size() >= 1 and _near(float(new_hits[0]), TocsinKit.HEAD_COEF * (1.0 + TocsinKit.HEAD_CHARGE_ADD) * BASE, 0.05), str(new_hits))
	_check("le pilier sonne : décharge = PILLAR_COEF x ticks restants (plafond 5,0)", new_hits.size() >= 2 and ring_expect > 0.0 and _near(float(new_hits[1]) / BASE, ring_expect, 0.05), "%s attendu %s" % [new_hits, ring_expect])
	_check("boss électrisé : +30 % et +50 % additifs (1,8)", boss.taken.size() >= 1 and _near(float(boss.taken[boss.taken.size() - 2]) if boss.taken.size() >= 2 else 0.0, TocsinKit.HEAD_COEF * (1.0 + TocsinKit.HEAD_BOSS_ADD + TocsinKit.HEAD_CHARGE_ADD) * BASE, 0.05), str(boss.taken))
	pil = _limb(&"arm_l")
	_check("le bras tombe, ramassable", pil != null and pil.phase == TocsinLimb.Phase.GROUND and pil.pickup != null)
	_sim(1.0)
	var after: int = inside.taken.size()
	_sim(1.0)
	_check("plus aucun tick de pilier ensuite", inside.taken.size() == after)

	print("Tête hors pilier : coup nu")
	_reset()
	var lone := _fake(Vector2(3.0 * U, 0))
	var p2 := _throw_head(3.0, lone)
	var lone_hits: Array = lone.taken.slice(p2)
	_check("Tête x1,0 sans étiquette", lone_hits.size() == 1 and _near(float(lone_hits[0]), TocsinKit.HEAD_COEF * BASE, 0.05), str(lone_hits))
	_check("pas de combo_hit sans étiquette", not _kit.combo_hit(_kit._spell_of(4), lone))

	print("Ordre inverse : Tête puis Bras-pilier")
	_reset()
	var seq := _fake(Vector2(2.0 * U, 20))
	var ph := _throw_head(2.0, seq)
	var seq_hits: Array = seq.taken.slice(ph)
	_check("Tête d'abord : coup nu", seq_hits.size() == 1 and _near(float(seq_hits[0]), TocsinKit.HEAD_COEF * BASE, 0.05), str(seq_hits))
	var p3 := _plant(2.0)
	_check("puis le pilier décharge normalement", p3 != null and seq.taken.size() >= 2 and _near(float(seq.taken[seq.taken.size() - 1]), TocsinKit.PILLAR_COEF * BASE, 0.05))

	print("Le Coup qui fait sonner le pilier")
	_reset()
	var t1 := _fake(Vector2(2.0 * U, 20))
	var p4 := _plant(2.0)
	_check("pilier posé à 2 u", p4 != null)
	_sim(0.6)
	_check("combo_ready(3) : pilier dans l'onde", _kit.combo_ready(3))
	var n0 := t1.taken.size()
	_player.spells._remaining[3] = 0.0
	_player.spells.cast(3)
	var toll_hits: Array = t1.taken.slice(n0)
	_check("Coup : onde 2,3 + décharge 1,5 du pilier", toll_hits.size() == 2 and _near(float(toll_hits[0]), TocsinKit.TOLL_COEF * BASE, 0.05) and _near(float(toll_hits[1]), TocsinKit.PILLAR_RING_COEF * BASE, 0.05), str(toll_hits))
	_check("+2 ticks (12 au total)", p4._max_ticks == TocsinKit.PILLAR_TICKS + TocsinKit.PILLAR_RING_TICKS, str(p4._max_ticks))
	var n1 := t1.taken.size()
	_player.spells._remaining[3] = 0.0
	_player.spells.cast(3)
	_check("un second Coup ne prolonge plus (mais décharge encore)", p4._max_ticks == 12 and t1.taken.size() == n1 + 2)
	var t_end := 0.0
	while p4.phase == TocsinLimb.Phase.PILLAR and t_end < 8.0:
		_sim(DT)
		t_end += DT
	_check("pilier fini ensuite au sol", p4.phase == TocsinLimb.Phase.GROUND and p4.pickup != null, str(p4.phase))

	print("Coup sur un bras au sol : il se redresse 2 s")
	_kit.recharge_left[2] = 30.0 # recharge loin de finir : le bras ne part pas en braises pendant le test
	_player.spells._remaining[3] = 0.0
	var n2 := t1.taken.size()
	_player.spells.cast(3)
	_check("redressé en pilier de 4 ticks, sans pickup", p4.phase == TocsinLimb.Phase.PILLAR and p4._max_ticks == TocsinKit.PILLAR_RISE_TICKS and p4.pickup == null)
	_sim(2.2)
	var risen: Array = t1.taken.slice(n2 + 1) # onde du Coup, puis les ticks du bras redressé
	_check("4 ticks de 0,7", risen.size() >= TocsinKit.PILLAR_RISE_TICKS and _near(float(risen[risen.size() - 1]), TocsinKit.PILLAR_COEF * BASE, 0.05), str(risen))
	_check("retombe au sol, ramassable", p4.phase == TocsinLimb.Phase.GROUND and p4.pickup != null, str(p4.phase))

	print("Ramassage bridé (audit P7)")
	_reset()
	var a1 := _plant(3.0, &"arm_l")
	_player.spells._remaining[2] = 0.0
	_player.spells.aim_override = Vector2(5.0 * U, 0)
	_player.spells.cast(2) # le bras droit part aussi : 0 charge
	_check("0 charge en main", _kit.charges(2) == 0)
	_sim(5.8) # le bras gauche finit sa décharge et tombe
	a1 = _limb(&"arm_l")
	var remaining := float(_kit.recharge_left[2])
	_check("bras gauche au sol", a1 != null and a1.phase == TocsinLimb.Phase.GROUND and a1.pickup != null)
	if a1 != null and a1.pickup != null:
		_player.global_position = a1.global_position
		a1.pickup.step(DT)
		var expect := remaining * (1.0 - TocsinKit.PICKUP_CD_REFUND)
		_check("bras revenu dans la frame", bool(_kit.present[&"arm_l"]) and _kit.charges(2) == 1)
		_check("lancer suivant après 50 % de la recharge restante", _near(float(_player.spells._remaining[2]), expect, 0.1), "%s attendu %s" % [_player.spells._remaining[2], expect])
		_check("pas de jeu en boucle : le verrou ne dépasse pas la recharge", float(_player.spells._remaining[2]) <= TocsinKit.PILLAR_CD_S * TocsinKit.PICKUP_CD_REFUND + 0.05)

	print("Vapeur dans un pilier")
	_reset()
	var s1 := _fake(Vector2(2.0 * U, 20))
	var p5 := _plant(2.0)
	_check("électrisé", s1.mods.has(TocsinKit.CHARGE_TAG))
	_player.global_position = p5.global_position
	s1.statuses.clear()
	_kit._steam_burst(Vector2.RIGHT)
	_check("dans le pilier : électrisé ralenti à 50 %", _near(s1.last_slow_pct(), TocsinKit.STEAM_CHARGED_SLOW_PCT), str(s1.last_slow_pct()))
	_player.global_position = Vector2(-4.0 * U, 0)
	s1.global_position = _player.global_position + Vector2(20, 0)
	s1.statuses.clear()
	_kit._steam_burst(Vector2.RIGHT)
	_check("hors pilier : 30 %", _near(s1.last_slow_pct(), TocsinKit.STEAM_SLOW_PCT), str(s1.last_slow_pct()))
	_check("l'esquive ne fait aucun dégât", s1.taken.size() >= 1 and _near(float(s1.taken[s1.taken.size() - 1]), TocsinKit.PILLAR_COEF * BASE, 0.05))

	print("auto_cast_ok(4)")
	_reset()
	_check("aucun pilier : la Tête part", _kit.auto_cast_ok(4))
	var p6 := _plant(3.0)
	_sim(0.4)
	_check("pilier vide : la Tête attend", p6 != null and not _kit.auto_cast_ok(4))
	_fake(Vector2(3.0 * U, 10))
	_fake(Vector2(3.0 * U, -10))
	_sim(0.4)
	_check("pilier avec 2 monstres : la Tête part", _kit.auto_cast_ok(4))
	_check("autres slots jamais retenus", _kit.auto_cast_ok(2) and _kit.auto_cast_ok(3))

	print("Fenêtres sans pilier")
	_reset()
	_check("combo_ready faux sans pilier", not _kit.combo_ready(3) and not _kit.combo_ready(4) and not _kit.combo_ready(2))

	_reset()
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

