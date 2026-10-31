extends Node
## Audit des objets (31/10/2026) : non-régressions des bugs corrigés.
##  - Phénix de poche : la résurrection passe AVANT l'écran de fin (pas de player_died), consomme une charge, rend
##    50 % des PV, donne 2 s de répit, purge brûlure/poison, et fonctionne aussi en mode test (avant le « KO » qui
##    rendait les PV sans jamais consommer l'objet : la résurrection n'était jamais visible en test).
##  - Épines : tout coup direct déclenche la riposte, même venu d'un danger sans take_damage (scories, tempête, piège).
##  - Tempête de braises / Peste vivante : un monstre tué par le DERNIER tick de sa brûlure / de son poison meurt bien
##    « en brûlant » / « empoisonné » (le cumul était retiré avant le tick : pas d'explosion).
## godot --headless --path game res://tests/items_audit_test.tscn   (RESULT: OK)

const U := 64.0

class Hazard extends Node2D: ## source d'un coup sans take_damage (danger de terrain, scories de boss)
	pass

class Dummy extends Node2D:
	var taken := 0
	func take_damage(_a: float, _c: bool = false, _e: StringName = &"") -> void:
		taken += 1

var _fails := 0
var _player: CharacterBody2D
var _junk: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool) -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label)


func _spawn() -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
		await get_tree().process_frame
	RunState.character = &"ardent"
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_player.global_position = Vector2.ZERO
	_player.shield = 0.0


func _give(items: Dictionary) -> void:
	RunState.start_run(&"moyen", 4242)
	RunState.level = 1
	for id in items:
		for i in int(items[id]):
			RunState.add_item(StringName(id))
	_player.apply_stats(ItemStats.compute(RunState.items))
	_player.hp = _player.max_hp


func _lethal(src: Node = null) -> void:
	_player._invuln = 0.0
	_player.hp = 1.0
	_player.take_damage(50.0, src)


func _run() -> void:
	var deaths := [0]
	Events.player_died.connect(func() -> void: deaths[0] += 1)

	print("Phénix de poche : run normale")
	await _spawn()
	_give({"phenix_de_poche": 1})
	_player.apply_status(&"burn", {"hit": 200.0})
	_player.apply_status(&"poison", {"hit": 200.0})
	_check("brûlé et empoisonné avant la mort", _player.is_burning() and _player.poison_stacks() > 0)
	_lethal()
	_check("pas mort, pas d'écran de fin", not _player.dead and deaths[0] == 0)
	_check("PV à 50 %% (%.1f / %.1f)" % [_player.hp, _player.max_hp], absf(_player.hp - _player.max_hp * 0.5) < 0.01)
	_check("charge consommée", int(RunState.counters.get("phenix_used", 0)) == 1 and _player.item_fx.revives_left() == 0)
	_check("répit après la résurrection", _player.is_invulnerable() and _player._invuln >= 1.99)
	_check("brûlure et poison purgés", not _player.is_burning() and _player.poison_stacks() == 0)
	_player.take_damage(50.0) # pendant le répit : ignoré
	_check("coup ignoré pendant le répit", not _player.dead and absf(_player.hp - _player.max_hp * 0.5) < 0.01)
	_lethal()
	_check("plus de charge : mort et écran de fin", _player.dead and deaths[0] == 1)

	print("Phénix de poche : mode test (PV illimités coupés)")
	await _spawn()
	_give({"phenix_de_poche": 1})
	var was_active: bool = TestMode.active
	var was_god: bool = TestMode.god
	TestMode.active = true
	TestMode.god = false
	_lethal()
	_check("mode test : résurrection visible (PV à 50 %, charge consommée)",
		absf(_player.hp - _player.max_hp * 0.5) < 0.01 and int(RunState.counters.get("phenix_used", 0)) == 1)
	_lethal()
	_check("mode test sans charge : « KO » du mode test (PV pleins, pas de mort)", not _player.dead and _player.hp == _player.max_hp)
	TestMode.active = was_active
	TestMode.god = was_god
	_check("aucune mort annoncée en mode test", deaths[0] == 1)

	print("Phénix de poche : mort par DoT")
	await _spawn()
	_give({"phenix_de_poche": 1})
	_player._invuln = 0.0
	_player.hp = 0.5
	_player.apply_status(&"poison", {"hit": 5000.0})
	_player.tick(0.5)
	_check("DoT mortel : résurrection", not _player.dead and _player.hp > _player.max_hp * 0.4 and deaths[0] == 1)

	print("Épines : coup venu d'un danger sans take_damage")
	await _spawn()
	_give({"epines": 1})
	var hz := Hazard.new()
	get_tree().root.add_child(hz)
	_junk.append(hz)
	var foe := Dummy.new()
	foe.add_to_group("enemies")
	get_tree().root.add_child(foe)
	foe.global_position = Vector2(2.0 * U, 0.0)
	_junk.append(foe)
	_player._invuln = 0.0
	_player.take_damage(5.0, hz)
	_check("riposte sur un coup de danger", foe.taken == 1)
	_player.item_fx.tick(0.6)
	_player._invuln = 0.0
	_player.take_damage(5.0, null)
	_check("riposte sur un coup sans source", foe.taken == 2)
	foe.remove_from_group("enemies")

	print("Tempête de braises / Peste vivante : mort au dernier tick")
	var fake: Node2D = load("res://tests/enemies_fake_player.gd").new()
	get_tree().root.add_child(fake)
	_junk.append(fake)
	_player.remove_from_group("player")
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_junk.append(director)
	for status in [&"burn", &"poison"]:
		var e: Enemy = director.spawn_enemy(1, Vector2(30.0 * U, 0.0))
		e.hp = 1.0e6
		e.max_hp = 1.0e6
		var seen := []
		var cb := func(k: Node2D, _p: Vector2, _t: int, _el: bool) -> void:
			if k == e:
				seen.append(e.is_burning() if status == &"burn" else e.is_poisoned())
		Events.enemy_killed.connect(cb)
		e.apply_status(status, {"total": 100.0, "duration": 1.0})
		e._update_statuses(0.5) # 1er tick : survit
		_check("%s : 1er tick sans mort" % status, e.active)
		e.hp = 1.0
		e._update_statuses(0.5) # dernier tick : le cumul expire puis le tick tue
		Events.enemy_killed.disconnect(cb)
		_check("%s : tué par le dernier tick et encore marqué à sa mort (%s)" % [status, str(seen)], seen.size() == 1 and seen[0] == true)
		_check("%s : marqueur de dernier tick retombé" % status, not (e.is_burning() if status == &"burn" else e.is_poisoned()))

	for j in _junk:
		if is_instance_valid(j):
			j.queue_free()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
