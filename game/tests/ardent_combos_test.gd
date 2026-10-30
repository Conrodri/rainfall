extends Node
## Test headless des combos d'Ardent (docs/Design_Combos.md §3) : marque braise, Nova +30 %, Cendres +1 s,
## Brasier +1,0 par marqué et flambée de Cendres, Éclat qui marque au départ, combo_ready, aide d'auto-cast.
## godot --headless --path game res://tests/ardent_combos_test.tscn  (sortie : RESULT: OK)

const ZoneScript := preload("res://scripts/spells/zone_effect.gd")
const U := 64.0
const DT := 1.0 / 60.0


class FakeEnemy extends Node2D:
	var tier := 1
	var is_elite := false
	var active := true
	var radius_px := 0.0
	var taken: Array = []

	func take_damage(amount: float, is_crit: bool = false, element: StringName = &"") -> void:
		taken.append(amount)
		Events.enemy_damaged.emit(self, amount, is_crit, element)

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


var _fails: Array[String] = []
var _player: CharacterBody2D = null
var _kit: ArdentBaseKit = null


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		print("ÉCHEC : ", what)
	else:
		print("  ok   ", what)


func _near(a: float, b: float, eps := 0.001) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func _enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	return e


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies") # queue_free ne retire du groupe qu'en fin d'image
		e.queue_free()


func _new_player(loadout := {}) -> CharacterBody2D:
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
	_kit = p.kit
	return p


func _adv(secs: float) -> void:
	var n := int(round(secs / DT))
	var container: Node = _player.spells.effects_parent()
	for i in n:
		_player.tick(DT)
		_player.dodge_step(DT)
		for c in container.get_children():
			if not c.is_queued_for_deletion() and c.get_script() == ZoneScript:
				c.step(DT)


func _cast(slot: int) -> bool:
	_player.spells._remaining[slot] = 0.0
	var ok: bool = _player.spells.cast(slot)
	_player.spells.flush_pending()
	return ok


func _zones(sid: StringName) -> Array:
	var out: Array = []
	for c in _player.spells.effects_parent().get_children():
		if c.get_script() == ZoneScript and not c.is_queued_for_deletion() and (c.spell as SpellData).id == sid:
			out.append(c)
	return out


func _ready() -> void:
	await get_tree().process_frame
	await _test_base_node()
	await _test_nova()
	await _test_ash_extend()
	await _test_brasier()
	await _test_blink()
	await _test_ready_and_aid()
	await _test_variants()
	if _fails.is_empty():
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


func _test_base_node() -> void:
	print("Nœud de base")
	var p := _new_player()
	_check(p.kit is ArdentBaseKit and not (p.kit is ArdentVariantKit), "Ardent de base : ArdentBaseKit")
	_check(p.spells.defers_effects(), "effets différés à la frame d'impact (comme sans kit)")
	var nova: SpellData = p.character.spells[1]
	var ash: SpellData = p.character.spells[2]
	_check(p.action_base_for(p.character.spells[0]) == &"attack" and p.action_base_for(nova) == &"cast" \
		and p.action_base_for(p.character.spells[3]) == &"cast_ult", "bases d'anim inchangées")
	_check(_near(nova.coef, 2.3) and _near(p.character.spells[3].coef, 7.4), "Nova 2,3 et Brasier 7,4")
	_check(int(p.character.action_impact_frames[&"cast"]) == 2, "Nova/Cendres : impact à la frame 2")
	_check(ash.id == &"cendres", "slot 3 = Cendres")
	_check(CharacterData.for_id(&"ardent", {2: &"flame_pillar"}).kit_script == ArdentVariantKit, "variante : ArdentVariantKit")
	_check(ArdentVariantKit.new() is ArdentBaseKit, "ArdentVariantKit hérite d'ArdentBaseKit")
	await get_tree().process_frame


func _test_nova() -> void:
	print("A-1 Nova sur marqués")
	_clear_enemies()
	var p := _new_player()
	var dmg := Balance.player_base_damage(RunState.level)
	var m := _enemy(Vector2(1.0 * U, 0))
	var n := _enemy(Vector2(-1.0 * U, 0))
	_kit.add_mark(m)
	_check(_kit.is_marked(m) and not _kit.is_marked(n), "marque posée sur un seul")
	_check(_kit.combo_ready(2), "combo_ready(Nova) : un marqué à portée")
	_check(_cast(2), "Nova lancée")
	_check(_near(n.total(), 2.3 * dmg), "non marqué : 2,3 x base")
	_check(_near(m.total(), 2.3 * dmg * 1.3), "marqué : +30 %")
	_check(not _kit.is_marked(m), "marque consommée")
	_check(not _kit.combo_ready(2), "combo_ready retombe")
	# hors fenêtre : 1,5 s
	var o := _enemy(Vector2(0, 1.0 * U))
	_kit.add_mark(o)
	_adv(1.6)
	_check(not _kit.is_marked(o), "marque expirée après 1,5 s")
	_cast(2)
	_check(_near(o.total(), 2.3 * dmg), "hors fenêtre : pas de bonus")
	# rafraîchie, prolongée, plafonnée à 3 s
	var q := _enemy(Vector2(0, -1.0 * U))
	_kit.add_mark(q)
	_adv(1.0)
	_kit.add_mark(q)
	_check(_near(_kit.mark_left(q), 1.5, 0.02), "rafraîchie à chaque pose")
	for i in 6:
		_kit.extend_mark(q)
	_check(_near(_kit.mark_left(q), 3.0, 0.02), "plafond de 3 s")
	_adv(2.9)
	_check(_kit.is_marked(q), "encore marqué à 2,9 s")
	_adv(0.2)
	_check(not _kit.is_marked(q), "expirée à 3 s")
	# marque jamais héritée d'un monstre recyclé
	var r := _enemy(Vector2(3 * U, 0))
	_kit.add_mark(r)
	Events.enemy_killed.emit(r, r.global_position, 1, false)
	_check(not _kit.is_marked(r), "mort : marque effacée (pool)")
	# Éclat de braise sur marqué : +0,6 s
	var s_e := _enemy(Vector2(2 * U, 2 * U))
	_kit.add_mark(s_e)
	var before := _kit.mark_left(s_e)
	_kit.on_spell_hit(p.character.spells[0], s_e, 1.0)
	_check(_near(_kit.mark_left(s_e) - before, 0.6, 0.02), "Éclat de braise : +0,6 s")
	await get_tree().process_frame


func _test_ash_extend() -> void:
	print("A-1 Cendres : tick marque, +1 s une fois")
	_clear_enemies()
	_new_player()
	var a := _enemy(Vector2(1.0 * U, 0))
	var b := _enemy(Vector2(1.0 * U, 0.7 * U))
	_check(_cast(3), "Cendres lancées")
	var zs := _zones(&"cendres")
	_check(zs.size() == 1, "une zone de Cendres")
	_check(_kit.is_marked(a) and _kit.is_marked(b), "chaque tick de Cendres marque")
	var z: Node = zs[0]
	_check(_near(float(z.duration), 5.0), "Cendres 5 s")
	_check(_cast(2), "Nova sur les marqués")
	_check(_near(float(z.duration), 6.0), "Cendres +1 s (une fois pour deux marqués consommés)")
	_adv(0.6) # nouveau tick : remarqués
	_check(_kit.is_marked(a), "la Cendres remarque")
	_cast(2)
	_check(_near(float(z.duration), 6.0), "pas de seconde prolongation de la même Cendres")
	await get_tree().process_frame


func _test_brasier() -> void:
	print("A-2 Brasier : +1,0 par marqué")
	_clear_enemies()
	_new_player()
	var dmg := Balance.player_base_damage(RunState.level)
	var m := _enemy(Vector2(1.0 * U, 0))
	var n := _enemy(Vector2(-1.0 * U, 0))
	_kit.add_mark(m)
	_check(_cast(4), "Brasier lancé")
	_check(_near(n.total(), 7.4 * dmg), "non marqué : 7,4 x base")
	_check(_near(m.total(), 8.4 * dmg), "marqué : 8,4 x base")
	await get_tree().process_frame
	print("A-2 flambée de Cendres")
	_clear_enemies()
	_new_player()
	var a := _enemy(Vector2(2.0 * U, 0))
	_check(_cast(3), "Cendres posée")
	var z: Node = _zones(&"cendres")[0]
	_check(_kit.is_marked(a), "monstre marqué dans la Cendres")
	var b4: int = a.taken.size()
	_check(_cast(4), "Brasier à 6 u de la Cendres")
	await get_tree().process_frame # la flambée part en différé
	_check(_zones(&"ash_flare").size() == 1, "flambée apparue")
	var flare_hit := 0.0
	for i in range(b4 + 1, a.taken.size()): # [b4] = Brasier, ensuite flambée
		flare_hit += a.taken[i]
	_check(_near(flare_hit, 2.0 * dmg), "flambée : 2,0 x base sur le monstre (%s)" % str(a.taken))
	z.step(DT)
	_check(z.is_ending() or z.is_queued_for_deletion(), "Cendres éteinte par la flambée")
	await get_tree().process_frame


func _test_blink() -> void:
	print("A-3 Éclat : marque au départ, aucun dégât")
	_clear_enemies()
	var p := _new_player()
	var start := _enemy(Vector2(0.8 * U, 0))
	var far := _enemy(Vector2(6 * U, 0))
	var arrival := _enemy(Vector2(0, 3.0 * U))
	_check(p.dodge(Vector2.DOWN), "Éclat lancé vers le bas")
	_adv(0.4)
	_check(p.global_position.y > 2.0 * U, "Ardent a bondi (y=%d)" % int(p.global_position.y))
	_check(_kit.is_marked(start), "monstre au départ : marqué")
	_check(not _kit.is_marked(far) and not _kit.is_marked(arrival), "ni le lointain, ni l'arrivée")
	_check(start.taken.is_empty() and far.taken.is_empty() and arrival.taken.is_empty(), "aucun dégât direct")
	await get_tree().process_frame


func _test_ready_and_aid() -> void:
	print("Bouton pulsé et aide d'auto-cast")
	_clear_enemies()
	_new_player()
	var a := _enemy(Vector2(4.0 * U, 0))
	var b := _enemy(Vector2(0, 4.2 * U))
	_kit.add_mark(a)
	_check(not _kit.combo_ready(2), "marqué à 4 u : le bouton ne pulse pas (3,5 u)")
	_check(_kit.auto_cast_ok(2), "un seul marqué : pas de retard")
	_kit.add_mark(b)
	_check(not _kit.auto_cast_ok(2), "2 marqués à 3,5-4,5 u : la Nova auto attend")
	_adv(0.3)
	_check(not _kit.auto_cast_ok(2), "…toujours à 0,3 s")
	_adv(0.3)
	_check(_kit.auto_cast_ok(2), "…part après 0,5 s au plus")
	_check(_kit.auto_cast_ok(1) and _kit.auto_cast_ok(3), "autres sorts jamais retenus")
	a.global_position = Vector2(2.0 * U, 0)
	_kit.add_mark(a)
	_check(_kit.combo_ready(2), "marqué à 2 u : le bouton pulse")
	_check(not _kit.combo_ready(4), "Brasier : sans Cendres active, pas de pulsation")
	_check(_cast(3), "Cendres")
	_check(_kit.combo_ready(4), "Brasier : Cendres active avec marqué à portée")
	await get_tree().process_frame


func _test_variants() -> void:
	print("Variantes")
	_clear_enemies()
	_new_player({2: &"flame_pillar", 3: &"meteor_rain", 4: &"phoenix", 1: &"roaming_embers"})
	_check(_kit is ArdentVariantKit, "kit de variantes")
	var m := _enemy(Vector2(3.0 * U, 0))
	var n := _enemy(Vector2(3.0 * U, 0.3 * U))
	var s3: SpellData = _player.character.spells[2]
	var s4: SpellData = _player.character.spells[3]
	_kit.add_mark(m)
	_check(_kit.combo_ready(2), "Pilier : combo_ready avec marqué à portée")
	_check(_cast(2), "Pilier lancé")
	_adv(0.5)
	_check(m.taken.size() >= 1 and n.taken.size() >= 1, "Pilier a frappé")
	_check(_near(m.taken[0] / n.taken[0], 1.3), "premier tick du Pilier sur marqué : +30 %")
	_check(m.taken.size() < 2 or _near(m.taken[1], n.taken[1]), "ticks suivants sans bonus (marque consommée)")
	var x := _enemy(Vector2(0, 5 * U))
	_kit.on_spell_hit(s3, x, 1.0)
	_check(_kit.is_marked(x), "impact de Pluie de météores : marque")
	_kit.consume_mark(x)
	_kit.on_spell_hit(s4, x, 1.0)
	_check(_kit.is_marked(x), "piqué du Phénix : marque")
	var orb: SpellData = _player.character.spells[0]
	var before := _kit.mark_left(x)
	_kit.on_spell_hit(orb, x, 1.0)
	_check(_near(_kit.mark_left(x) - before, 0.6, 0.02), "orbe des Braises errantes : +0,6 s")
	await get_tree().process_frame
