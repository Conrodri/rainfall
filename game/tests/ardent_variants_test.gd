extends Node
## Test headless des 4 variantes de sorts d'Ardent (docs/Variantes_Sorts.md §2.1, lot 1).
## godot --headless --path game res://tests/ardent_variants_test.tscn  (sortie : RESULT: OK)
## Simulation déterministe : le temps avance par Player.tick / ZoneEffect.step / ArdentPhoenix.step, sans image rendue.

const VariantUnlocks := preload("res://scripts/save/variant_unlocks.gd")
const ZoneScript := preload("res://scripts/spells/zone_effect.gd")
const U := 64.0
const DT := 1.0 / 60.0
const LOADOUT := {1: &"roaming_embers", 2: &"flame_pillar", 3: &"meteor_rain", 4: &"phoenix"}


class FakeEnemy extends Node2D:
	var tier := 1
	var is_elite := false
	var active := true
	var radius_px := 0.0
	var taken: Array = []
	var statuses: Array = []

	func take_damage(amount: float, is_crit: bool = false, element: StringName = &"") -> void:
		taken.append(amount)
		Events.enemy_damaged.emit(self, amount, is_crit, element)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func is_slowed() -> bool:
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


class FakeProfile extends RefCounted:
	var unlocked_spells: Array = []
	var stats := {}

	func stat(key: String) -> float:
		return float(stats.get(key, 0.0))


var _fails: Array[String] = []
var _player: CharacterBody2D = null


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		print("ÉCHEC : ", what)
	else:
		print("  ok   ", what)


func _enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	return e


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()


func _new_player(loadout: Dictionary) -> CharacterBody2D:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	RunState.start_run(&"moyen", 1234)
	RunState.running = false
	RunState.level = 1
	RunState.counters = {}
	var cd := CharacterData.for_id(&"ardent", loadout)
	var p: CharacterBody2D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.character = cd
	add_child(p)
	p.global_position = Vector2.ZERO
	p.apply_stats({"crit_chance": -0.05}) # sans critique : dégâts déterministes
	p.hp = p.max_hp
	p.spells.manual_aim_enabled = false
	p.spells.rng.seed = 7
	_player = p
	return p


## Avance de `secs` s : joueur (kit, sorts) puis zones persistantes.
func _adv(secs: float) -> void:
	var n := int(round(secs / DT))
	var container: Node = _player.spells.effects_parent()
	for i in n:
		_player.tick(DT)
		for c in container.get_children():
			if c.is_queued_for_deletion():
				continue
			if c.get_script() == ZoneScript:
				c.step(DT)
			elif c is ArdentPhoenix:
				c.step(DT)


func _ready() -> void:
	await get_tree().process_frame
	await _test_substitution()
	await _test_embers()
	await _test_pillar()
	await _test_meteors()
	await _test_phoenix()
	await _test_counters()
	_test_unlock_rules()
	if _fails.is_empty():
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


func _test_substitution() -> void:
	print("Substitution")
	var base := CharacterData.for_id(&"ardent")
	_check(base.kit_script == null and base.loadout.is_empty(), "Ardent de base : aucun kit, aucun loadout")
	var cd := CharacterData.for_id(&"ardent", LOADOUT)
	for slot in LOADOUT:
		var s: SpellData = null
		for sp in cd.spells:
			if sp.slot == slot:
				s = sp
		_check(s != null and s.id == LOADOUT[slot], "slot %d : variante %s" % [slot, LOADOUT[slot]])
		_check(cd.variant_of(slot) == LOADOUT[slot], "variant_of(%d)" % slot)
		_check(s.behavior == SpellData.Behavior.KIT, "slot %d : comportement KIT" % slot)
	_check(cd.kit_script == ArdentVariantKit, "le kit de variantes est porté par CharacterData")
	_check(ArdentKit.variant(2, &"roaming_embers") == null, "variante au mauvais slot : null")
	_check(ArdentKit.variant(1, &"inconnue") == null, "variante inconnue : null")
	# les 4 variantes déclarées dans characters.json sont codées
	var chars: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var declared := 0
	for c in chars:
		if str(c.get("id", "")) != "ardent":
			continue
		for i in c["spells"].size():
			for v in c["spells"][i].get("variants", []):
				declared += 1
				_check(not v.has("todo_design") and v.has("unlock_rule"), "%s : sans todo_design, avec règle" % v["id"])
				_check(CharacterData.variant_spell(&"ardent", i + 1, StringName(v["id"]), true) != null, "%s : codée" % v["id"])
	_check(declared == 4, "4 variantes déclarées pour Ardent (%d)" % declared)
	var p := _new_player(LOADOUT)
	_check(p.kit is ArdentVariantKit, "le joueur reçoit le nœud ArdentVariantKit")
	_check(p.get_spell_cooldowns().size() == 4, "4 sorts actifs")
	await get_tree().process_frame


func _test_embers() -> void:
	print("Braises errantes")
	_clear_enemies()
	var p := _new_player({1: &"roaming_embers"})
	var e := _enemy(Vector2(1.8 * U, 0.0)) # sur la trajectoire des orbes
	_adv(1.3)
	_check(p.kit.ring != null, "anneau d'orbes créé")
	_check(p.kit.ring.orb_positions().size() == 3, "3 orbes")
	_check(e.taken.size() >= 1, "l'orbe touche un monstre sur son passage (%d)" % e.taken.size())
	var coef := e.total() / maxf(e.taken.size(), 1) / 12.0
	_check(absf(coef - ArdentKit.EMBER_COEF) < 0.01, "coef par touche = %.2f (%.3f)" % [ArdentKit.EMBER_COEF, coef])
	var n1 := e.taken.size()
	_adv(1.2) # un tour de plus : immunité 0,4 s -> au plus 3 orbes × ~3 touches, jamais une touche par frame
	_check(e.taken.size() - n1 <= 3 * 4, "immunité par orbe (%d touches/1,2 s)" % (e.taken.size() - n1))
	# les 3 orbes sont à 1,8 u du joueur
	var ok := true
	for op in p.kit.ring.orb_positions():
		ok = ok and absf(op.distance_to(p.global_position) - 1.8 * U) < 1.0
	_check(ok, "orbes à 1,8 u du joueur")
	await get_tree().process_frame


func _test_pillar() -> void:
	print("Pilier de flamme")
	_clear_enemies()
	var p := _new_player({2: &"flame_pillar"})
	var pt := Vector2(4.0 * U, 0.0)
	var e := _enemy(pt)
	var far := _enemy(Vector2(-6.0 * U, 0.0))
	p.spells.aim_override = pt
	p.spells.manual_aim_enabled = true
	_check(p.spells.cast(2), "pilier lancé")
	_adv(0.2)
	_check(e.taken.is_empty(), "télégraphe 0,3 s : pas encore de dégâts")
	_adv(0.2)
	_check(e.taken.size() >= 1, "colonne posée : dégâts")
	_adv(2.4)
	var n := e.taken.size()
	_check(n >= 10 and n <= 11, "10-11 ticks en 2,5 s (%d)" % n)
	_check(absf(e.total() / n / 12.0 - ArdentKit.PILLAR_COEF) < 0.01, "coef par tick %.2f" % ArdentKit.PILLAR_COEF)
	var slows := e.statuses.filter(func(s): return s[0] == &"slow")
	_check(not slows.is_empty() and absf(float(slows[0][1]["pct"]) - 0.30) < 0.001, "ralentissement 30 % dans la colonne")
	_check(far.taken.is_empty(), "monstre hors colonne intact")
	_adv(0.5)
	var n2 := e.taken.size()
	_adv(0.5)
	_check(e.taken.size() == n2, "la colonne s'éteint après 2,5 s (%d -> %d)" % [n2, e.taken.size()])
	_check(p.spells.cooldown_remaining(2) > 0.0, "recharge lancée")
	await get_tree().process_frame


func _test_meteors() -> void:
	print("Pluie de météores")
	_clear_enemies()
	var p := _new_player({3: &"meteor_rain"})
	var pt := Vector2(5.0 * U, 0.0)
	# grille dense dans le disque de 3 u : chaque impact (1 u) touche plusieurs monstres
	var foes: Array[FakeEnemy] = []
	for ix in range(-4, 5):
		for iy in range(-4, 5):
			foes.append(_enemy(pt + Vector2(ix, iy) * 0.5 * U))
	p.spells.aim_override = pt
	p.spells.manual_aim_enabled = true
	_check(p.spells.cast(3), "pluie lancée")
	_adv(0.7)
	_check(foes.all(func(f): return f.taken.is_empty()), "chaque impact est télégraphié 0,8 s : rien avant")
	_adv(2.4)
	var hit := foes.filter(func(f): return not f.taken.is_empty())
	_check(hit.size() >= 10, "les impacts touchent des monstres (%d)" % hit.size())
	var per_hit := 0.0
	for f in foes:
		for a in f.taken:
			per_hit = a
	_check(absf(per_hit / 12.0 - ArdentKit.METEOR_COEF) < 0.01, "coef par impact %.1f" % ArdentKit.METEOR_COEF)
	var total_hits := 0
	for f in foes:
		total_hits += f.taken.size()
	var cd: float = p.spells.cooldown_remaining(3)
	_check(cd > 4.0 and cd < 6.0, "recharge 8 s en cours (%.1f)" % cd)
	await get_tree().process_frame


func _test_phoenix() -> void:
	print("Phénix")
	_clear_enemies()
	var p := _new_player({4: &"phoenix"})
	var pack: Array[FakeEnemy] = []
	for i in 5:
		pack.append(_enemy(Vector2(5.0 * U, 0.0) + Vector2(i * 0.4 * U, (i % 2) * 0.3 * U)))
	_check(p.spells.cast(4), "phénix invoqué")
	var ph: ArdentPhoenix = p.kit.phoenix
	_check(ph != null and is_instance_valid(ph), "un phénix existe")
	_adv(0.4) # le phénix pique au bout de 0,5 s
	_adv(2.0)
	_check(ph.dives >= 1, "il pique (%d)" % ph.dives)
	var dmg := 0.0
	var burned := 0
	for f in pack:
		dmg += f.total()
		for st in f.statuses:
			if st[0] == &"burn":
				burned += 1
	_check(dmg > 0.0, "dégâts de piqué (%.1f)" % dmg)
	_check(burned > 0, "brûlure 2 s appliquée (%d)" % burned)
	var first: float = 0.0
	for f in pack:
		if not f.taken.is_empty():
			first = f.taken[0]
			break
	_check(absf(first / 12.0 - ArdentKit.PHOENIX_COEF) < 0.01, "coef par piqué %.1f" % ArdentKit.PHOENIX_COEF)
	# un seul phénix : relancer consume l'ancien
	p.spells.set_cooldown(4, 0.0, 20.0)
	_check(p.spells.cast(4), "relance")
	_check(ph.exploded, "l'ancien se consume")
	var ph2: ArdentPhoenix = p.kit.phoenix
	_check(ph2 != ph and not ph2.exploded, "un nouveau phénix")
	# explosion à 12 s : zone de 3 u, coef 2,0
	var victim := _enemy(ph2.global_position + Vector2(U, 0.0))
	ph2.life_left = 0.05
	_adv(0.2)
	_check(ph2.exploded, "il explose à la fin")
	var burst := 0.0
	for a in victim.taken:
		burst = maxf(burst, a)
	_check(absf(burst / 12.0 - ArdentKit.PHOENIX_BURST_COEF) < 0.01, "explosion coef %.1f (%.1f)" % [ArdentKit.PHOENIX_BURST_COEF, burst / 12.0])
	# mort du joueur : il se consume
	p.spells.set_cooldown(4, 0.0, 20.0)
	p.spells.cast(4)
	var ph3: ArdentPhoenix = p.kit.phoenix
	Events.player_died.emit()
	_check(ph3.exploded, "mort d'Ardent : le phénix se consume")
	await get_tree().process_frame


func _test_counters() -> void:
	print("Compteurs de déblocage")
	_clear_enemies()
	var p := _new_player({})
	p = _new_player({}) # ArdentKit.variant_a() a branché le hook pendant le 1er for_id
	await get_tree().process_frame
	var tr := p.get_node_or_null("ArdentTracker")
	_check(tr is ArdentTracker, "tracker installé sur l'Ardent de base")
	_check(p.kit == null, "…sans faire de l'Ardent de base un personnage à kit")
	# Nova sur 16 monstres : un grand lancer
	for i in 16:
		_enemy(Vector2.from_angle(TAU * i / 16.0) * 1.5 * U)
	p.spells.manual_aim_enabled = false
	_check(p.spells.cast(2), "nova lancée")
	p.spells.flush_pending()
	await get_tree().process_frame
	_check(float(RunState.counters.get("ardent.nova_big_casts", 0.0)) == 1.0, "nova sur 16 monstres : ardent.nova_big_casts = 1 (%s)" % str(RunState.counters))
	# petite nova : pas de compteur
	_clear_enemies()
	await get_tree().process_frame
	for i in 5:
		_enemy(Vector2.from_angle(TAU * i / 5.0) * 1.5 * U)
	p.spells.set_cooldown(2, 0.0, 6.0)
	p.spells.cast(2)
	p.spells.flush_pending()
	await get_tree().process_frame
	_check(float(RunState.counters.get("ardent.nova_big_casts", 0.0)) == 1.0, "nova sur 5 monstres : pas de compteur")
	# Cendres : un kill dans la zone compte, un kill hors zone non
	_clear_enemies()
	await get_tree().process_frame
	var target := _enemy(Vector2(3.0 * U, 0.0))
	p.spells.set_cooldown(3, 0.0, 8.0)
	_check(p.spells.cast(3), "cendres lancées")
	p.spells.flush_pending()
	await get_tree().process_frame
	Events.enemy_killed.emit(target, target.global_position, 1, false)
	Events.enemy_killed.emit(target, Vector2(-8.0 * U, 0.0), 1, false)
	_check(float(RunState.counters.get("ardent.cendres_kills", 0.0)) == 1.0, "1 kill dans les cendres compté, 1 hors zone non (%s)" % str(RunState.counters))
	# boss d'étage 2
	var boss := Node2D.new()
	add_child(boss)
	RunState.stage = 1
	Events.boss_killed.emit(boss, true)
	_check(not RunState.counters.has("ardent.floor2_boss_kills"), "boss d'étage 1 : pas de compteur")
	RunState.stage = 2
	Events.boss_killed.emit(boss, false)
	_check(not RunState.counters.has("ardent.floor2_boss_kills"), "mini-boss à l'étage 2 : pas de compteur")
	Events.boss_killed.emit(boss, true)
	_check(float(RunState.counters.get("ardent.floor2_boss_kills", 0.0)) == 1.0, "boss d'étage 2 : compteur")
	boss.queue_free()


func _test_unlock_rules() -> void:
	print("Déblocage évalué")
	var chars: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var pr := FakeProfile.new()
	var none := VariantUnlocks.evaluate(pr, chars, {"victory": false, "character": "ardent", "stage": 1})
	_check(not none.has(&"spell:roaming_embers") and not none.has(&"spell:flame_pillar"), "run perdue sans compteur : rien")
	var won := VariantUnlocks.evaluate(pr, chars, {"victory": true, "character": "ardent", "stage": 5})
	_check(won.has(&"spell:roaming_embers"), "victoire avec Ardent : Braises errantes")
	var other := VariantUnlocks.evaluate(pr, chars, {"victory": true, "character": "rictus", "stage": 5})
	_check(not other.has(&"spell:roaming_embers"), "victoire avec un autre personnage : non")
	pr.stats["ardent.nova_big_casts"] = 1.0
	_check(VariantUnlocks.evaluate(pr, chars, {}).has(&"spell:flame_pillar"), "1 grande Nova : Pilier de flamme")
	pr.stats["ardent.cendres_kills"] = 299.0
	_check(not VariantUnlocks.evaluate(pr, chars, {}).has(&"spell:meteor_rain"), "299 kills : Pluie verrouillée")
	pr.stats["ardent.cendres_kills"] = 300.0
	_check(VariantUnlocks.evaluate(pr, chars, {}).has(&"spell:meteor_rain"), "300 kills : Pluie de météores")
	pr.stats["ardent.floor2_boss_kills"] = 1.0
	_check(VariantUnlocks.evaluate(pr, chars, {}).has(&"spell:phoenix"), "boss d'étage 2 : Phénix")
	pr.unlocked_spells = ["phoenix"]
	_check(not VariantUnlocks.evaluate(pr, chars, {}).has(&"spell:phoenix"), "déjà possédée : non rendue")
