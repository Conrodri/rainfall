extends Node
## Paratonnerre dévié (docs/Ateliers_Chiffres.md §8) : gros pilier prêt, étages 2-4, boss d'étage élite avec affixe annoncé,
## PV x1,4 / 1,4 / 1,3, enrage retardé du même facteur, 2 coffres de boss. Exclus : étages 1 et 5, raids, boss final.
## Vraie scène de jeu (comme integration_test).
## godot --headless --path game res://tests/pillar_deviated_test.tscn   (sortie « RESULT: OK »)

var _fails := 0
var _main: Node


func _check(msg: String, ok: bool) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	await _run()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _big(stage: StageManager) -> Pillar:
	for p in stage.pillars:
		if p.kind == Pillar.Kind.BIG:
			return p
	return null


func _kind_count(stage: StageManager, kind: StringName) -> int:
	var n := 0
	for c in stage.chests:
		if is_instance_valid(c) and c.get("kind") == kind:
			n += 1
	return n


func _run() -> void:
	# --- Équilibrage
	_check("étages 2 à 4", Balance.PILLAR_DEVIATED_MIN_FLOOR == 2 and Balance.PILLAR_DEVIATED_MAX_FLOOR == 4)
	_check("PV x1,4 / 1,4 / 1,3", is_equal_approx(Balance.pillar_deviated_hp_mult(2), 1.4) and is_equal_approx(Balance.pillar_deviated_hp_mult(3), 1.4) and is_equal_approx(Balance.pillar_deviated_hp_mult(4), 1.3))
	_check("hors 2-4 : x1", Balance.pillar_deviated_hp_mult(1) == 1.0 and Balance.pillar_deviated_hp_mult(5) == 1.0)
	_check("retard d'enrage = facteur de PV", is_equal_approx(Balance.pillar_deviated_enrage_delay(2), 1.4) and is_equal_approx(Balance.pillar_deviated_enrage_delay(4), 1.3))
	_check("affixes burn / slow / poison", Balance.PILLAR_DEVIATED_AFFIXES == [&"burn", &"slow", &"poison"])
	_check("2 coffres de boss", Balance.PILLAR_DEVIATED_CHESTS == 2 and Balance.boss_chest_count(1, true) == 2 and Balance.boss_chest_count(1, false) == 1 and Balance.boss_chest_count(0, true) == 1)
	for r in [&"drowned_idol", &"flood_gunner", &"salt_king", &"rain_sower"]:
		_check("raid %s exclu" % r, r in Balance.PILLAR_DEVIATED_EXCLUDED)
	var t_enrage := Balance.BOSS_ENRAGE_AFTER_S * 1.2
	_check("enrage : sans retard à t=%.0f > 1, avec x1,4 = 1" % t_enrage, Balance.boss_enrage_mult(t_enrage) > 1.0 and Balance.boss_enrage_mult(t_enrage, 1.4) == 1.0)
	_check("enrage : même courbe, décalée", is_equal_approx(Balance.boss_enrage_mult(Balance.BOSS_ENRAGE_AFTER_S * 1.4 + 10.0, 1.4), Balance.boss_enrage_mult(Balance.BOSS_ENRAGE_AFTER_S + 10.0)))

	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 777)
	add_child(_main)
	await _main.game_ready
	await _frames(3)
	var stage: StageManager = _main.stage
	var director: Director = _main.director
	var player: Node2D = _main.player
	player.grant_invulnerability(1.0e6)

	var big := _big(stage)
	_check("gros pilier présent", big != null)
	if big == null:
		return
	big.unlock()
	_check("pilier prêt", big.state == Pillar.STATE_READY)

	# --- Fenêtre d'étages
	var saved_stage := RunState.stage
	var saved_boss := big.boss_id
	for s in [1, 2, 3, 4, 5]:
		RunState.stage = s
		var expected: bool = s >= 2 and s <= 4
		_check("étage %d : déviation %s" % [s, "proposée" if expected else "refusée"], big.can_deviate() == expected)
	RunState.stage = 2
	# Raids exclus
	for r in [&"drowned_idol", &"flood_gunner", &"salt_king", &"rain_sower"]:
		big.boss_id = r
		_check("raid %s : refusé" % r, not big.can_deviate())
	big.boss_id = saved_boss
	big.final_boss = true
	_check("boss final : refusé", not big.can_deviate())
	big.final_boss = false
	for p in stage.pillars:
		if p.kind == Pillar.Kind.SMALL:
			_check("petit pilier : refusé", not p.can_deviate())
			break
	_check("annonce stable (même affixe deux fois)", big.announced_affix() == big.announced_affix() and big.announced_affix() in Balance.PILLAR_DEVIATED_AFFIXES)
	var rs0: int = RunState.rng.state
	big.announced_affix()
	_check("annonce : RunState.rng intact", RunState.rng.state == rs0)

	# --- Référence : boss non dévié, même identité
	var ref := Pillar.new()
	stage.map.add_child(ref)
	ref.setup(Pillar.Kind.BIG, 98)
	ref.boss_id = saved_boss
	ref.position = big.position + Vector2(1500.0, 0.0)
	_check("référence activée", ref.activate())
	var ref_boss: Node2D = ref._boss
	_check("boss de référence", ref_boss != null)
	var base_hp := float(ref_boss.get(&"max_hp"))
	_check("boss de référence : pas élite, enrage normal", (ref_boss.get(&"affixes") as Array).is_empty() and float(ref_boss.get(&"enrage_delay_mult")) == 1.0)

	# --- Déviation à l'étage 2
	var affix := big.announced_affix()
	var ev: Array = []
	Events.pillar_deviated.connect(func(p: Node, a: StringName) -> void: ev.append([p, a]))
	_check("deviate() réussit", big.deviate())
	_check("signal pillar_deviated", ev.size() == 1 and ev[0][0] == big and ev[0][1] == affix)
	_check("pilier actif et dévié", big.state == Pillar.STATE_ACTIVE and big.deviated and big.deviated_affix == affix)
	_check("pas de seconde déviation", not big.can_deviate() and not big.deviate())
	var boss: Node2D = big._boss
	_check("boss apparu", boss != null)
	_check("PV x1,4", absf(float(boss.get(&"max_hp")) - base_hp * 1.4) < 1.0 and absf(float(boss.get(&"hp")) - float(boss.get(&"max_hp"))) < 0.01)
	_check("affixe annoncé = affixe appliqué", boss.get(&"affixes") == [affix])
	_check("enrage retardé x1,4", is_equal_approx(float(boss.get(&"enrage_delay_mult")), 1.4))
	_check("méta « deviated »", bool(boss.get_meta(&"deviated", false)))
	_check("le boss non dévié reste intact", float(ref_boss.get(&"enrage_delay_mult")) == 1.0 and (ref_boss.get(&"affixes") as Array).is_empty())
	# Sauvegarde du pilier : l'état dévié suit
	var back := Pillar.new()
	stage.map.add_child(back)
	back.setup(Pillar.Kind.BIG, 97)
	back.from_dict(JSON.parse_string(JSON.stringify(big.to_dict())))
	_check("sauvegarde : déviation conservée", back.deviated and back.deviated_affix == affix)
	back.queue_free()

	# --- Étage 4 : x1,3
	RunState.stage = 4
	var ref4 := Pillar.new() # référence à l'étage 4 (les PV de base dépendent de l'étage)
	stage.map.add_child(ref4)
	ref4.setup(Pillar.Kind.BIG, 95)
	ref4.boss_id = saved_boss
	ref4.position = big.position + Vector2(0.0, 1500.0)
	ref4.activate()
	var ref4_hp := float(ref4._boss.get(&"max_hp"))
	var fl4 := Pillar.new()
	stage.map.add_child(fl4)
	fl4.setup(Pillar.Kind.BIG, 96)
	fl4.boss_id = saved_boss
	fl4.position = big.position + Vector2(-1500.0, 0.0)
	_check("étage 4 : déviation", fl4.deviate())
	var b4: Node2D = fl4._boss
	_check("étage 4 : boss dévié", b4 != null and bool(b4.get_meta(&"deviated", false)))
	if b4 != null:
		_check("PV x1,3 (étage 4) sur la même base", absf(float(b4.get(&"max_hp")) / ref4_hp - 1.3) < 0.05)
		_check("enrage retardé x1,3", is_equal_approx(float(b4.get(&"enrage_delay_mult")), 1.3))

	# --- Coffres : 2 coffres de boss pour un pilier dévié, 1 sinon
	RunState.stage = 2
	var n0 := _kind_count(stage, &"boss")
	var made := stage.spawn_boss_chests(big)
	_check("pilier dévié : 2 coffres de boss", made.size() == Balance.boss_chest_count(1 if Omens.boss_chest_enabled() else 0, true) and _kind_count(stage, &"boss") - n0 == made.size())
	if Omens.boss_chest_enabled():
		_check("2 coffres écartés l'un de l'autre", made.size() == 2 and made[0].position.distance_to(made[1].position) > 64.0)
	var n1 := _kind_count(stage, &"boss")
	var made_ref := stage.spawn_boss_chests(ref)
	_check("pilier normal : 1 coffre de boss", made_ref.size() == (1 if Omens.boss_chest_enabled() else 0) and _kind_count(stage, &"boss") - n1 == made_ref.size())

	# --- Fin de combat : la mort du boss dévié + la charge posent bien les 2 coffres via le flux normal
	var done: Array = []
	big.finished.connect(func(p: Node) -> void: done.append(p))
	var n2 := _kind_count(stage, &"boss")
	big.charge = Balance.PILLAR_CHARGE_S
	big.boss_dead = true
	big._check_done()
	_check("pilier terminé", big.state == Pillar.STATE_DONE and done.size() == 1)
	_check("flux normal : coffres de boss posés par StageManager", _kind_count(stage, &"boss") - n2 == Balance.boss_chest_count(1 if Omens.boss_chest_enabled() else 0, true))

	RunState.stage = saved_stage
