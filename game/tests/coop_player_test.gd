extends Node
## Coop 1-4, étape 2 lot 1 (joueur, sorts, entrées) : deux joueurs inscrits dans Players avec deux sources d'entrée
## factices. Chacun bouge, vise, lance et esquive avec SA source ; dégâts, procs, niveau, or (Avare), kills et mort vont
## au bon PlayerState ; la mort en coop rend spectateur (sans l'ancien player_died) et la résurrection ramène le joueur.
## godot --headless --path game res://tests/coop_player_test.tscn

## Source d'entrée scriptée (comme une manette précise : mode GAMEPAD, ou KBM avec un pointeur fixe).
class FakeSource extends InputSource:
	var mv := Vector2.ZERO
	var aim := Vector2.ZERO
	var held := {}
	var just := {}
	var input_mode: int = Platform.InputMode.GAMEPAD
	var pointer: Variant = null

	func _init() -> void:
		kind = Kind.PAD
		device = 90

	func mode() -> int:
		return input_mode

	func move_vector() -> Vector2:
		return mv

	func aim_vector() -> Vector2:
		return aim

	func is_pressed(action: StringName) -> bool:
		return bool(held.get(action, false))

	func just_pressed(action: StringName) -> bool:
		return bool(just.get(action, false))

	func just_released(_action: StringName) -> bool:
		return false

	func pointer_world(_canvas: CanvasItem) -> Variant:
		return pointer if input_mode == Platform.InputMode.KBM else null

	func owns_event(_event: InputEvent) -> bool:
		return false


class FakeEnemy extends Node2D:
	var tier := 1
	var is_elite := false
	var hits: Array = [] ## dictionnaires `hit`
	var statuses: Array = []

	func take_damage(_amount: float, _is_crit: bool = false, _element: StringName = &"", hit: Dictionary = {}) -> void:
		hits.append(hit)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func is_slowed() -> bool:
		return false


class FakeInteractable extends Node2D:
	var by: Array = []

	func interact_state() -> Dictionary:
		return {"visible": true, "enabled": true, "label": "Test", "hold_s": 0.0}

	func interact(who: Node) -> bool:
		by.append(who)
		return true


var _fails := 0
var _p: Array = [] ## deux joueurs
var _src: Array = [] ## deux sources
var _legacy_died := 0
var _died_by: Array = []
var _wiped := 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	RunState.start_run(&"moyen", 1234)
	Players.clear()
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	for i in 2:
		var st := RunState.player_state(i)
		st.reset()
		st.character = &"ardent"
		st.loadout = {}
		var s := FakeSource.new()
		var p: CharacterBody2D = scene.instantiate()
		p.player_id = i
		_check("inscription joueur %d" % (i + 1), Players.register(p, s, i) == i)
		get_tree().root.add_child(p)
		p.global_position = Vector2(0.0, 0.0) if i == 0 else Vector2(64.0, 0.0)
		p.apply_stats({"crit_chance": -0.05})
		_p.append(p)
		_src.append(s)
	await get_tree().process_frame
	var p0: CharacterBody2D = _p[0]
	var p1: CharacterBody2D = _p[1]
	var s0: FakeSource = _src[0]
	var s1: FakeSource = _src[1]
	var st0 := RunState.player_state(0)
	var st1 := RunState.player_state(1)

	print("Identité")
	_check("Players.count() == 2", Players.count() == 2)
	_check("état du joueur 2 = player_state(1)", p1.player_state() == st1 and p0.player_state() == st0 and st0 == RunState.local())
	_check("source du joueur 2 = la sienne", p1.input_source() == s1 and p0.input_source() == s0)
	_check("SpellCaster connaît son joueur", p1.spells.player_id() == 1 and p0.spells.player_id() == 0)

	print("Kills attribués (Events.enemy_killed_by)")
	Events.emit_enemy_killed(null, Vector2(32.0, 0.0), 1, false, 1)
	_check("tué par le joueur 2 : close_kills du joueur 2 seul", p1.close_kills == 1 and p0.close_kills == 0, "%d %d" % [p0.close_kills, p1.close_kills])
	Events.emit_enemy_killed(null, Vector2(32.0, 0.0), 1, false)
	_check("auteur inconnu en coop : personne", p1.close_kills == 1 and p0.close_kills == 0)

	print("Déplacement indépendant")
	var a0 := p0.global_position
	var a1 := p1.global_position
	s0.mv = Vector2(1.0, 0.0)
	s1.mv = Vector2(0.0, 1.0)
	await _frames(6)
	s0.mv = Vector2.ZERO
	s1.mv = Vector2.ZERO
	var d0 := p0.global_position - a0
	var d1 := p1.global_position - a1
	_check("joueur 1 va à droite", d0.x > 20.0 and absf(d0.y) < 1.0, str(d0))
	_check("joueur 2 va en bas", d1.y > 20.0 and absf(d1.x) < 1.0, str(d1))

	print("Visée indépendante")
	s0.aim = Vector2(1.0, 0.0)
	s1.aim = Vector2(0.0, -1.0)
	var r := 500.0
	var aim0: Variant = p0.spells.get_manual_aim_point(r)
	var aim1: Variant = p1.spells.get_manual_aim_point(r)
	_check("visée stick joueur 1", aim0 is Vector2 and ((aim0 as Vector2) - p0.global_position).normalized().dot(Iso.screen_to_logical_dir(s0.aim).normalized()) > 0.99, str(aim0))
	_check("visée stick joueur 2", aim1 is Vector2 and ((aim1 as Vector2) - p1.global_position).normalized().dot(Iso.screen_to_logical_dir(s1.aim).normalized()) > 0.99, str(aim1))
	s1.input_mode = Platform.InputMode.KBM
	s1.pointer = Vector2(777.0, -333.0)
	aim1 = p1.spells.get_manual_aim_point(r)
	_check("visée curseur du joueur 2 (source KBM)", aim1 is Vector2 and (aim1 as Vector2).is_equal_approx(Vector2(777.0, -333.0)), str(aim1))
	aim0 = p0.spells.get_manual_aim_point(r)
	_check("le curseur du joueur 2 ne vise pas pour le joueur 1", aim0 is Vector2 and not (aim0 as Vector2).is_equal_approx(Vector2(777.0, -333.0)))
	s1.input_mode = Platform.InputMode.GAMEPAD
	s0.aim = Vector2.ZERO
	s1.aim = Vector2.ZERO

	print("Sorts indépendants")
	p0.spells.set_cooldown(2, 0.0, 1.0)
	p1.spells.set_cooldown(2, 0.0, 1.0)
	s1.just[&"spell_2"] = true
	await _frames(2)
	s1.just.erase(&"spell_2")
	_check("sort 2 lancé par le joueur 2", p1.spells.cooldown_remaining(2) > 0.0, str(p1.spells.cooldown_remaining(2)))
	_check("sort 2 du joueur 1 intact", p0.spells.cooldown_remaining(2) <= 0.0, str(p0.spells.cooldown_remaining(2)))

	print("Esquive indépendante")
	await _frames(30) # fin de l'anim du sort (l'esquive attend une fenêtre d'annulation)
	p0.reset_dodge()
	p1.reset_dodge()
	s0.just[&"dodge"] = true
	await _frames(1)
	s0.just.erase(&"dodge")
	var cd0: Dictionary = p0.get_dodge_cooldown()
	var cd1: Dictionary = p1.get_dodge_cooldown()
	_check("esquive du joueur 1", p0.is_dodging() or float(cd0.get("remaining", 0.0)) > 0.0, str(cd0))
	_check("pas d'esquive du joueur 2", not p1.is_dodging() and float(cd1.get("remaining", 0.0)) <= 0.0, str(cd1))
	await _frames(40)

	print("Dégâts et procs attribués")
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = p1.global_position + Vector2(100.0, 0.0)
	p1.apply_stats({"crit_chance": -0.05, "procs": [{"chance": 1.0, "status": &"burn", "data": {"base_fraction": 0.5}}]})
	var dd0 := st0.damage_dealt
	var dd1 := st1.damage_dealt
	var spell: SpellData = p1.spells.character.spells[0]
	var h1 := {} # rempli sur place par deal_damage (cible factice : take_damage à 3 arguments)
	var amount: float = p1.spells.deal_damage(e, spell, h1)
	_check("coup du joueur 2 : hit[\"by\"] == 1", int(h1.get("by", -9)) == 1, str(h1))
	_check("brûlure du proc attribuée au joueur 2", not e.statuses.is_empty() and int((e.statuses[-1][1] as Dictionary).get("by", -9)) == 1, str(e.statuses))
	_check("dégâts infligés au PlayerState du joueur 2", amount > 0.0 and is_equal_approx(st1.damage_dealt - dd1, amount) and is_equal_approx(st0.damage_dealt, dd0), "%f %f" % [st1.damage_dealt, st0.damage_dealt])
	var h0 := {}
	p0.spells.deal_damage(e, p0.spells.character.spells[0], h0)
	_check("coup du joueur 1 : hit[\"by\"] == 0", int(h0.get("by", -9)) == 0, str(h0))
	p1.apply_stats({"crit_chance": -0.05})
	e.queue_free()

	print("Niveau par joueur")
	var max0: float = p0.max_hp
	var max1: float = p1.max_hp
	st1.add_xp(Balance.xp_required(1) + Balance.xp_required(2) + 1.0)
	_check("joueur 2 niveau 3, joueur 1 niveau 1", st1.level == 3 and st0.level == 1, "%d %d" % [st0.level, st1.level])
	_check("PV max du joueur 2 montent seuls", p1.max_hp > max1 and is_equal_approx(p0.max_hp, max0), "%f %f" % [p0.max_hp, p1.max_hp])
	var base1: float = p1.spells.compute_damage(spell, null, false)
	var base0: float = p0.spells.compute_damage(p0.spells.character.spells[0], null, false)
	_check("dégâts suivent le niveau du joueur 2", base1 > base0, "%f %f" % [base0, base1])

	print("Or d'Avare (bourse du joueur 2)")
	_check("joueur 2 passe à Avare", p1.switch_character(&"avare"))
	_check("personnage écrit dans le PlayerState du joueur 2", st1.character == &"avare" and st0.character == &"ardent")
	st0.gold = 0.0
	st1.gold = 1000.0
	p0._invuln = 0.0 # répits (montée de niveau, coups précédents) levés pour les coups de test
	p1._invuln = 0.0
	var power: float = p1.kit.gold_power()
	_check("puissance de l'or lue dans la bourse du joueur 2", power > AvareKit.GOLD_POWER_FLOOR, str(power))
	p0.take_damage(5.0)
	_check("coup sur le joueur 1 : la bourse d'Avare ne saigne pas", is_equal_approx(st1.gold, 1000.0), str(st1.gold))
	p1.take_damage(5.0)
	_check("coup sur Avare : sa bourse saigne, pas celle du joueur 1", st1.gold < 1000.0 and is_equal_approx(st0.gold, 0.0), "%f %f" % [st0.gold, st1.gold])

	print("Interaction par joueur")
	var it := FakeInteractable.new()
	it.add_to_group("interactable")
	get_tree().root.add_child(it)
	it.global_position = p1.global_position + Vector2(10.0, 0.0)
	p0.interaction.enabled = true
	p1.interaction.enabled = true
	await _frames(2)
	_check("cible proposée au joueur 2", p1.interaction.target == it)
	s1.just[&"interact"] = true
	await _frames(1)
	s1.just.erase(&"interact")
	_check("interact(joueur 2) appelé une fois", it.by.size() == 1 and it.by[0] == p1, str(it.by))
	p0.interaction.enabled = false
	p1.interaction.enabled = false
	it.queue_free()

	print("Mort en coop : spectateur")
	Events.player_died.connect(func() -> void: _legacy_died += 1)
	Events.player_died_by.connect(func(id: int) -> void: _died_by.append(id))
	Events.party_wiped.connect(func() -> void: _wiped += 1)
	p0._invuln = 0.0
	p0.hp = 1.0
	p0.take_damage(500.0)
	_check("joueur 1 mort et spectateur", p0.dead and st0.spectating and not p0.visible and p0.collision_layer == 0)
	_check("player_died_by(0) seul, sans l'ancien player_died", _died_by == [0] and _legacy_died == 0, "%s %d" % [str(_died_by), _legacy_died])
	_check("pas de party_wiped (joueur 2 vivant)", _wiped == 0 and Players.alive_count() == 1)
	var a2 := p0.global_position
	s0.mv = Vector2(1.0, 0.0)
	await _frames(4)
	s0.mv = Vector2.ZERO
	_check("spectateur immobile", p0.global_position.is_equal_approx(a2))
	Players.resurrect_all()
	_check("résurrection : vivant, visible, PV pleins, couche 2", not p0.dead and p0.visible and not st0.spectating and is_equal_approx(p0.hp, p0.max_hp) and p0.collision_layer == 2)
	_check("répit après résurrection", p0.is_invulnerable())

	Players.clear()
	for p in _p:
		p.queue_free()
	RunState.start_run(&"moyen", 1)
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
