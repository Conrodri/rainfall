extends Node
## Test headless du joueur et du kit d'Ardent.
## godot --headless --path game res://tests/player_test.tscn  (scène : les autoloads doivent exister)

class FakeEnemy extends Node2D:
	var tier := 1
	var is_elite := false
	var taken: Array = []
	var statuses: Array = []

	func take_damage(amount: float, is_crit: bool = false, element: StringName = &"") -> void:
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


var _fails := 0
var _player: CharacterBody2D


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


func _enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	return e


func _reset() -> void:
	_player.apply_stats({"crit_chance": -0.05}) # crit désactivé : dégâts déterministes
	_player.hp = _player.max_hp
	_player.shield = 0.0
	_player.clear_statuses()
	_player.dead = false
	_player.tick(1.0)


func _run() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	RunState.level = 1

	print("Instanciation")
	_check("groupe player", _player.is_in_group("player"))
	_check("couche 2", _player.collision_layer == 2)
	_check("PV L1 = 100", _near(_player.max_hp, 100.0) and _near(_player.hp, 100.0))
	_check("4 cooldowns", _player.get_spell_cooldowns().size() == 4)
	_check("vitesse 256 px/s", _near(_player.move_speed(), 256.0))

	print("Tir auto (Éclat de braise)")
	_reset()
	var e1 := _enemy(Vector2(300, 0))
	_player.tick(0.1)
	_check("tir différé à la frame d'impact (attack, frame 2)", _player.spells.active_projectile_count() == 0)
	_player.tick(0.2) # frame 2 à 12 i/s = 0,17 s : le projectile part
	var n: int = _player.spells.active_projectile_count()
	_check("un projectile tiré", n == 1, str(n))
	var cds: Array = _player.get_spell_cooldowns()
	_check("cooldown slot 1 ~0.6 s", _near(cds[0].total, 0.6) and cds[0].remaining > 0.0, str(cds[0]))
	_check("pas de re-tir pendant le cooldown", _player.spells.cast(1) == false)
	# Le projectile avance bien (physique de l'Area2D simulée sur quelques frames)
	var proj: Node = null
	for p in _player.spells._pool:
		if p.active:
			proj = p
	var x0: float = proj.global_position.x
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("projectile avance vers la cible", proj.global_position.x > x0 + 1.0)
	_check("projectile en couche 4", proj.collision_layer == 8 and proj.collision_mask == 4)
	proj._on_hit(e1)
	_check("dégât coef 0.8 x 12 = 9.6", e1.taken.size() == 1 and _near(e1.taken[0], 9.6), str(e1.taken))
	proj._on_hit(e1)
	_check("pas de double touche", e1.taken.size() == 1)

	print("Nova / zones")
	_reset()
	var e2 := _enemy(Vector2(100, 0))
	var far := _enemy(Vector2(2000, 0))
	_check("nova lancée", _player.spells.cast(2))
	_player.spells.flush_pending()
	_check("nova 2,5 x 12 = 30 sur proche", _near(e2.total(), ArdentKit.NOVA_COEF * 12.0), str(e2.taken))
	_check("nova épargne le lointain", far.taken.is_empty())
	_check("nova en recharge", _player.spells.cast(2) == false)
	_player.apply_stats({"crit_chance": -0.05, "zone_damage_add": 0.5, "cooldown_mult": 0.5})
	_check("cast cendres (slot 3)", _player.spells.cast(3))
	_player.spells.flush_pending()
	var cd3: Dictionary = _player.get_spell_cooldowns()[2]
	_check("recharge ×0,5 : 8 s -> 4 s", _near(cd3.total, 4.0), str(cd3))

	print("apply_stats")
	_reset()
	var e3 := _enemy(Vector2(50, 0))
	_player.spells._remaining[4] = 0.0
	_player.apply_stats({"crit_chance": -0.05, "damage_add": 0.5, "damage_mult": 2.0, "zone_damage_add": 0.1})
	_player.spells.cast(4)
	_player.spells.flush_pending()
	# 8 x 12 x (1+0.5+0.1) x 2 = 307,2 (Brasier 10 -> 8, équilibrage 22/10)
	_check("brasier formule", _near(e3.total(), ArdentKit.BRASIER_COEF * 12.0 * 1.6 * 2.0), str(e3.taken))
	_player.apply_stats({"max_hp_pct": 0.5, "move_speed": 0.5, "pickup_radius_mult": 0.5})
	_check("PV max +50 %", _near(_player.max_hp, 150.0), str(_player.max_hp))
	_check("vitesse plafonnée +35 %", _near(_player.move_speed(), Balance.PLAYER_SPEED_U * 1.35 * 64.0))
	_check("rayon de ramassage", _near(_player.pickup_radius, 240.0))
	_player.apply_stats({"max_hp_pct": 0.05, "max_hp_flat": 15.0})
	_check("PV max +5 % +15", _near(_player.max_hp, 120.0), str(_player.max_hp))

	print("take_damage")
	_player.apply_stats({})
	_player.hp = _player.max_hp
	_player.tick(1.0)
	_player.take_damage(1000.0)
	_check("plafond monstre 25 %", _near(_player.hp, 75.0), str(_player.hp))
	_player.take_damage(10.0)
	_check("invulnérabilité après coup", _near(_player.hp, 75.0))
	_player.tick(1.0)
	_player.hp = 100.0
	var boss := Node2D.new()
	boss.add_to_group("bosses")
	get_tree().root.add_child(boss)
	_player.take_damage(1000.0, boss)
	_check("plafond boss 40 %", _near(_player.hp, 60.0), str(_player.hp))
	_player.hp = 100.0
	_player.tick(1.0)
	_player.apply_stats({"armor": 100.0, "damage_taken_reduction": 0.2})
	_player.take_damage(20.0)
	_check("armure 50 % + réduction 20 %", _near(_player.hp, 100.0 - 8.0), str(_player.hp))
	_player.tick(1.0)
	_player.hp = 100.0
	_player.apply_stats({})
	_player.add_shield(15.0)
	_player.take_damage(20.0)
	_check("bouclier absorbe", _near(_player.hp, 95.0) and _near(_player.shield, 0.0), str(_player.hp))
	_player.tick(1.0)
	_player.hp = 100.0
	_player.apply_stats({"dodge": 5.0})
	var dodged := 0
	for i in 400:
		_player.tick(1.0)
		var before: float = _player.hp
		_player.take_damage(1.0)
		if _player.hp == before:
			dodged += 1
		_player.hp = 100.0
	_check("esquive plafonnée à 75 %", dodged > 250 and dodged < 340, str(dodged))

	print("Statuts")
	_reset()
	_player.apply_status(&"burn", {"hit": 40.0})
	var hp0: float = _player.hp
	for i in 31:
		_player.tick(0.1)
	# perte = 10 de brûlure moins la régénération sur 3,1 s
	_check("brûlure 25 % du coup sur 3 s = 10", _near(hp0 - _player.hp, 10.0 - _player.regen_per_s() * 3.1, 2.0) , str(hp0 - _player.hp))
	_reset()
	for i in 7:
		_player.apply_status(&"poison", {"hit": 100.0})
	_check("poison max 5 cumuls", _player.poison_stacks() == 5)
	_check("poison coupe 50 % de la regen", _near(_player.regen_per_s(), Balance.player_regen(1) * 0.5))
	_reset()
	_player.apply_status(&"slow", {})
	_check("ralentissement -30 %", _near(_player.slow_mult(), 0.7))
	for i in 16:
		_player.tick(0.1)
	_check("fin du ralentissement", _near(_player.slow_mult(), 1.0))
	_player.apply_status(&"slow", {})
	_check("immunité 2 s", _near(_player.slow_mult(), 1.0))
	for i in 21:
		_player.tick(0.1)
	_player.apply_status(&"slow", {})
	_check("ralentissable à nouveau", _near(_player.slow_mult(), 0.7))
	_player.heal(5.0)

	print("Procs / foudre")
	_reset()
	var a := _enemy(Vector2(500, 0))
	var b := _enemy(Vector2(520, 0))
	var c := _enemy(Vector2(540, 0))
	_player.apply_stats({"crit_chance": -0.05, "procs": [
		{"status": &"burn", "chance": 1.0, "data": {"hit_fraction": 1.0, "duration": 3.0}},
		{"status": &"lightning", "chance": 1.0, "data": {"targets": 3, "damage_fraction": 0.5}}]})
	_player.spells.deal_damage(a, _player.character.spells[0])
	# total = 100 % du coup (0,8 × 12) sur 3 s
	_check("proc brûlure transmis", a.statuses.size() == 1 and a.statuses[0][0] == &"burn" and _near(a.statuses[0][1].get("total", 0.0), 9.6), str(a.statuses))
	_check("foudre : autres cibles à 50 %", _near(b.total(), 4.8) and _near(c.total(), 4.8), str(b.taken))

	print("Roulade")
	_reset()
	_player.tick(Balance.DODGE_COOLDOWN_S) # recharge vide
	_player.global_position = Vector2.ZERO
	await get_tree().physics_frame
	var start: Vector2 = _player.global_position
	_check("roulade lancée", _player.dodge(Vector2.RIGHT))
	_check("invulnérable pendant la roulade", _player.is_dodging() and _player.is_invulnerable())
	var hp_d: float = _player.hp
	_player.take_damage(30.0)
	_player.apply_status(&"burn", {"hit": 40.0})
	_check("ni dégât ni statut pendant la roulade", _near(_player.hp, hp_d) and not _player.is_burning(), str(_player.hp))
	_check("pas de seconde roulade pendant la première", not _player.dodge(Vector2.LEFT))
	for i in 24:
		await get_tree().physics_frame
	var dist: float = _player.global_position.distance_to(start)
	var want: float = Balance.DODGE_DISTANCE_U * Balance.UNIT_PX
	_check("distance ~%.0f px (3 u)" % want, _near(dist, want, 2.0), str(dist))
	_check("vulnérable après la roulade", not _player.is_dodging() and not _player.is_invulnerable())
	var dcd: Dictionary = _player.get_dodge_cooldown()
	_check("recharge 3 s en cours", _near(dcd.total, 3.0) and dcd.remaining > 2.0 and dcd.remaining < 3.0, str(dcd))
	_check("refus pendant la recharge", not _player.dodge(Vector2.LEFT))
	_player.tick(3.0)
	_check("recharge terminée", _near(_player.get_dodge_cooldown().remaining, 0.0))
	Platform.set_input_mode(Platform.InputMode.GAMEPAD)
	_player.facing = Vector2.UP
	_check("sans déplacement : vers l'avant", _player.dodge_direction().is_equal_approx(Vector2.UP))
	# mur à x = 100 (le joueur a un rayon de 24 px) : la roulade s'arrête contre lui
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var ws := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 600)
	ws.shape = rect
	wall.add_child(ws)
	get_tree().root.add_child(wall)
	wall.global_position = Vector2(120, 0)
	_player.global_position = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("roulade vers le mur", _player.dodge(Vector2.RIGHT))
	for i in 24:
		await get_tree().physics_frame
	var px: float = _player.global_position.x
	_check("bloquée par le mur (x = %.1f)" % px, px > 50.0 and px <= 100.0 - 24.0 + 1.0, str(px))
	wall.queue_free()

	print("Mort et signaux")
	_reset()
	var died := [false]
	Events.player_died.connect(func(): died[0] = true)
	_player.apply_stats({})
	_player.hp = 5.0
	_player.tick(1.0)
	_player.take_damage(50.0)
	_check("mort + Events.player_died", _player.dead and died[0])

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
