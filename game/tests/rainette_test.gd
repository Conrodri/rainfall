extends Node
## Test headless de Rainette (docs/Design_Personnages.md §2.3, kit complété) : stats, rendu, bonds (S11 :
## distance, arc, virage en l'air, par-dessus les monstres, immunité au contact en l'air), bonds sans limite (plus de souffle),
## Langue (ligne, cible principale, traction, avalé +1 %), Grand saut (6 u, coef 3,0, étourdissement, file en l'air),
## Gluant (éclaboussure, ralentissement, attraction, bond +50 %), Chant de crue (bonds ×2, atterrissages
## coef 2,8), bond arrière, anims d'action et frames d'impact, lumière, partie réelle.
## godot --headless --path game res://tests/rainette_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var pushed := Vector2.ZERO
	var stunned := 0.0
	var radius_px := 20.0
	var tier := 2
	var hp := 1000.0
	var active := true
	var is_boss := false
	var is_elite := false

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)
		hp -= amount
		if hp <= 0.0:
			active = false

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func push(v: Vector2) -> void:
		pushed += v

	func stun(s: float) -> void:
		stunned = maxf(stunned, s)

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


## Obstacle « monstre » en couche 3 : les bonds passent par-dessus.
class FakeBody extends StaticBody2D:
	func _init(radius := 20.0) -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new()
		sh.radius = radius
		cs.shape = sh
		add_child(cs)


const U := 64.0
const BASE := 12.0
const DT := 1.0 / 60.0

var _fails := 0
var _player: CharacterBody2D
var _kit: RainetteKit
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Avance la simulation : locomotion (consigne `dir`) + tick du joueur ; sort 1 suspendu sauf `auto`.
func _advance(seconds: float, dir := Vector2.ZERO, auto := false) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		if not auto:
			_player.spells._remaining[1] = 99.0
		_kit.locomote(dir, DT)
		_player.tick(DT)
		for g in RainetteGoo.live:
			if is_instance_valid(g):
				g.step(DT)
		t += DT
	if not auto:
		_player.spells._remaining[1] = 0.0


## Avance jusqu'à ce que le kit n'ait plus d'effet en attente (frame d'impact). Retourne le temps écoulé.
func _to_impact() -> float:
	var t := 0.0
	while _kit.has_pending() and t < 1.5:
		_player.spells._remaining[1] = 99.0 if _player.spells._remaining[1] <= 0.0 else _player.spells._remaining[1]
		_player.tick(DT)
		t += DT
	return t


func _until_ground(dir := Vector2.ZERO, cap := 3.0) -> float:
	var t := 0.0
	while _kit.state != RainetteKit.State.GROUND and t < cap:
		_advance(DT, dir)
		t += DT
	return t


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.state = RainetteKit.State.GROUND
	_kit.state_left = 0.0
	_kit.hop_is_leap = false
	_kit.ult_left = 0.0
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.facing = Vector2.DOWN
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.reset_dodge()
	_player._invuln = 0.0


func _run() -> void:
	RunState.level = 1
	RunState.character = &"rainette"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit

	print("Personnage et rendu")
	_check("kit Rainette", _kit is RainetteKit)
	_check("4 sorts / ids", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["rainette_langue", "rainette_grand_saut", "rainette_gluant", "rainette_chant_de_crue"])
	_check("PV L1 = 90", _near(_player.max_hp, 90.0), str(_player.max_hp))
	_check("armure 10", _near(_player.armor(), 10.0))
	_check("régén 1,2", _near(_player.regen_per_s(), 1.2))
	_check("vitesse nominale 5,5 u/s", _near(_player.move_speed(), 5.5 * U, 0.1), str(_player.move_speed()))
	var shape := (_player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	_check("hitbox 0,45 u", _near(shape.radius, 24.0 * 0.9), str(shape.radius))
	var vis := _player.get_node("Visual") as AnimatedSprite2D
	_check("rainette.tres branché (RA1)", vis.sprite_frames != null and vis.sprite_frames.has_animation(&"jump_s") and vis.sprite_frames.has_animation(&"belch_ne"))
	var jade := true
	for sp in RainetteKit.character().spells:
		jade = jade and sp.light_preset == RainetteKit.LIGHT
	_check("lumière des sorts jade (jamais la braise)", jade and LightRig.has_preset(RainetteKit.LIGHT) and LightRig.has_preset(RainetteKit.LIGHT_SAC))
	_check("icônes des 4 sorts livrées", RainetteKit.character().spells.all(func(sp): return ArdentKit.spell_icon(sp.id) != null))
	_check("ombre de contact ; plus de pastilles de souffle", _player.get_node_or_null("RainetteShadow") != null and _player.get_node_or_null("RainetteBreath") == null)
	_check("aucune ressource exposée au HUD", not _kit.has_method(&"resource_state") and KitResource.of(_player).is_empty())
	_check("passif sans icône au HUD", not bool(RainetteKit.passive_info().get("hud", true)))

	print("Bonds (S11)")
	_reset()
	_kit.locomote(Vector2.RIGHT, DT)
	_check("joystick poussé = bond lancé", _kit.is_airborne())
	_advance(RainetteKit.HOP_AIR_S * 0.5, Vector2.RIGHT)
	_check("bond droit sans correction", absf(_player.global_position.y) < 0.5, str(_player.global_position))
	_check("sprite soulevé à mi-bond", vis.position.y < Iso.lift_logical(0.4), str(vis.position.y))
	_check("anim jump en l'air", String(vis.animation).begins_with("jump_") or _kit.visual_anim(&"idle_e") == &"jump_e")
	_until_ground()
	_check("bond de 2,5 u", _near(_player.global_position.x, 2.5 * U, 3.0), str(_player.global_position))
	_check("au sol : sprite reposé", _near(vis.position.y, 0.0, 0.5))
	_reset()
	_kit.locomote(Vector2.RIGHT, DT)
	_advance(0.2, Vector2.UP)
	_check("virage en l'air : le bond se corrige vers le joystick (jamais d'un coup)", _kit.hop_dir.y < -0.3 and _kit.hop_dir.x > 0.2, str(_kit.hop_dir))
	_until_ground()
	_reset()
	var wall_of_mobs: Array = []
	for i in 3:
		var b := FakeBody.new(26.0)
		get_tree().root.add_child(b)
		b.global_position = Vector2(60 + 30 * i, 0)
		_junk.append(b)
		wall_of_mobs.append(b)
	await _frames(2)
	_kit.locomote(Vector2.RIGHT, DT)
	_until_ground()
	_check("par-dessus les monstres", _player.global_position.x > 2.3 * U, str(_player.global_position))
	_reset()
	var biter := _fake(Vector2(30, 0))
	var shooter := _fake(Vector2(400, 0))
	_kit.locomote(Vector2.LEFT, DT)
	_player.global_position = Vector2.ZERO
	var hp0: float = _player.hp
	_player.take_damage(10.0, biter)
	_check("en l'air : contact ignoré", _near(_player.hp, hp0))
	_player.apply_status(&"burn", {"hit": 10.0, "source": biter}) # Enemy.apply_affixes_to : affixe d'élite au contact
	_check("en l'air : affixe d'élite au contact ignoré", not _player.is_burning())
	_player.take_damage(10.0, shooter)
	_check("en l'air : projectile touche", _player.hp < hp0)
	_until_ground()
	_player._invuln = 0.0
	_player.global_position = Vector2.ZERO
	hp0 = _player.hp
	_player.take_damage(10.0, biter)
	_check("au sol : contact touche", _player.hp < hp0)

	print("Bonds sans limite")
	_reset()
	var ok_chain := true
	var h0 := _kit.hop_count
	for i in 14:
		_kit.locomote(Vector2.RIGHT, DT)
		var cap := 0
		while _kit.state != RainetteKit.State.GROUND and cap < 120:
			_advance(DT)
			cap += 1
		ok_chain = ok_chain and _kit.state == RainetteKit.State.GROUND
	_check("14 bonds d'affilée : jamais bloquée, aucune pause", ok_chain and _kit.hop_count - h0 == 14, str(_kit.hop_count - h0))
	_check("aucun sort suspendu", not _kit.blocks_slot(1) and not _kit.blocks_slot(2) and not _kit.blocks_slot(3) and not _kit.blocks_slot(4))
	_check("lumière du joueur jade pâle (CharacterData.light_color)", _player.character.light_color.is_equal_approx(RainetteKit.PLAYER_LIGHT_TINT) and _player._light.color_override.is_equal_approx(RainetteKit.PLAYER_LIGHT_TINT))

	print("Sort 1 : Langue")
	_reset()
	_check("sans ennemi : rien", not _player.spells.cast(1))
	var tgt := _fake(Vector2(90, 0))
	var on_line := _fake(Vector2(180, 15))
	var off_line := _fake(Vector2(100, 120))
	var beyond := _fake(Vector2(4.5 * U + 40, 0))
	_check("Langue lancée", _player.spells.cast(1))
	_check("anim attack orientée", String(_player.action_anim()).begins_with("attack_e"), str(_player.action_anim()))
	var t_imp := _to_impact()
	_check("impact à la frame 3 de attack (0,25 s)", _near(t_imp, 0.25, 0.04), str(t_imp))
	_check("cible principale (la plus proche) : gros coup 1,15", _near(tgt.total(), RainetteKit.TONGUE_COEF * BASE), str(tgt.taken))
	_check("fouet de 4,5 u : le reste de la ligne prend le coup réduit 0,9", _near(on_line.total(), RainetteKit.TONGUE_LINE_COEF * BASE), str(on_line.taken))
	_check("rien hors de la ligne / au-delà de 4,5 u", off_line.taken.is_empty() and beyond.taken.is_empty())
	_check("VFX langue (RA1)", is_instance_valid(_kit.last_tongue) and _kit.last_tongue.get_child_count() > 0)
	_reset()
	var near_a := _fake(Vector2(90, 0))
	var elite_b := _fake(Vector2(180, 10))
	elite_b.is_elite = true
	var boss_c := _fake(Vector2(250, -10))
	boss_c.is_boss = true
	_player.spells.cast(1)
	_to_impact()
	_check("boss sur la ligne = cible principale (même derrière les autres)", _near(boss_c.total(), RainetteKit.TONGUE_COEF * BASE) and _near(near_a.total(), RainetteKit.TONGUE_LINE_COEF * BASE) and _near(elite_b.total(), RainetteKit.TONGUE_LINE_COEF * BASE), "%s %s %s" % [boss_c.taken, near_a.taken, elite_b.taken])
	_reset()
	var elite_only := _fake(Vector2(120, 0))
	var closer := _fake(Vector2(60, 5))
	elite_only.is_elite = true
	_player.spells.cast(1)
	_to_impact()
	_check("sans boss : l'élite prime sur le plus proche", _near(elite_only.total(), RainetteKit.TONGUE_COEF * BASE) and _near(closer.total(), RainetteKit.TONGUE_LINE_COEF * BASE))
	_reset()
	var lone := _fake(Vector2(100, 0))
	_player.spells.cast(1)
	_to_impact()
	_check("monocible : une cible seule prend le coup principal TONGUE_COEF", _near(lone.total(), RainetteKit.TONGUE_COEF * BASE))
	_reset()
	var snack := _fake(Vector2(150, 0))
	snack.tier = 1
	snack.hp = 5.0
	_player.hp = 50.0
	_player.spells.cast(1)
	_to_impact()
	_check("T1 tué par la Langue : avalé +1 % PV", _kit.swallowed == 1 and _player.hp >= 50.0 + 0.9 - 0.01, str(_player.hp))

	print("Sort 2 : Grand saut")
	_reset()
	var victim := _fake(Vector2(320, 40))
	var bystander := _fake(Vector2(0, 300))
	_player.spells.aim_override = Vector2(320, 0)
	_check("Grand saut lancé", _player.spells.cast(2))
	_check("accroupie d'abord", _kit.state == RainetteKit.State.CROUCH and _kit.visual_anim(&"idle_e").begins_with("crouch_"))
	_until_ground()
	_check("6 u max, au point visé", _near(_player.global_position.x, 320.0, 4.0), str(_player.global_position))
	_check("atterrissage coef 3,8", _near(victim.total(), RainetteKit.LEAP_COEF * BASE), str(victim.taken))
	_check("étourdi 0,5 s", _near(victim.stunned, 0.5))
	_check("hors zone épargné", bystander.taken.is_empty())
	_reset()
	_player.spells.aim_override = Vector2(900, 0)
	_player.spells.cast(2)
	_until_ground()
	_check("portée plafonnée à 6 u", _near(_player.global_position.x, 6.0 * U, 4.0), str(_player.global_position))
	_reset()
	_kit.locomote(Vector2.DOWN, DT)
	_player.spells.aim_override = Vector2(0, -300)
	_check("pressé en plein bond : accepté", _player.spells.cast(2))
	var l0 := _kit.landings
	_until_ground()
	_check("…puis part à l'atterrissage", _kit.landings == l0 + 2 and _player.global_position.y < -150.0, "%d %s" % [_kit.landings - l0, _player.global_position])

	print("Sort 3 : Gluant")
	_reset()
	var stuck := _fake(Vector2(200, 30))
	var stuck2 := _fake(Vector2(260, -40))
	_player.spells.aim_override = Vector2(220, 0)
	_check("Gluant lancé", _player.spells.cast(3))
	_check("anim spit", String(_player.action_anim()).begins_with("spit_"), str(_player.action_anim()))
	_to_impact()
	_check("flaque posée", RainetteGoo.live.size() == 1)
	_check("éclaboussure coef 1,4", _near(stuck.total(), RainetteKit.GOO_SPLASH_COEF * BASE), str(stuck.taken))
	_advance(0.5)
	var slowed := stuck.statuses.any(func(s): return s[0] == &"slow" and _near(float(s[1]["pct"]), 0.4))
	_check("ralentit 40 %", slowed)
	_check("attirés vers le centre (paquet)", stuck.pushed.y < -1.0 and stuck2.pushed.x < -1.0, "%s %s" % [stuck.pushed, stuck2.pushed])
	_player.global_position = Vector2(220, 0)
	_kit.locomote(Vector2.LEFT, DT)
	_check("bond depuis la flaque +50 %", _near(_kit.hop_speed_px * _kit.hop_air_total, 2.5 * U * 1.5, 1.0), str(_kit.hop_speed_px * _kit.hop_air_total))
	_until_ground()
	_advance(RainetteKit.GOO_DURATION_S + 0.8)
	await get_tree().process_frame
	_check("flaque dissipée après 5 s", RainetteGoo.live.is_empty())

	print("Sort 4 : Chant de crue")
	_reset()
	_check("Chant de crue lancé", _player.spells.cast(4))
	_check("anim belch", String(_player.action_anim()).begins_with("belch_"), str(_player.action_anim()))
	_to_impact()
	_check("4 s de chant", _kit.is_singing() and _near(_kit.ult_left, 4.0, 0.3))
	var crowd := _fake(Vector2(5.0 * U + 60, 0))
	_kit.locomote(Vector2.RIGHT, DT)
	_check("bonds ×2", _near(_kit.hop_speed_px * _kit.hop_air_total, 5.0 * U, 1.0))
	_until_ground()
	_check("atterrissage : coef 3,6 dans 3 u", _near(crowd.total(), RainetteKit.ULT_LAND_COEF * BASE), str(crowd.taken))
	_advance(4.0)
	_check("fin du chant", not _kit.is_singing())

	print("Bond arrière (roulade)")
	_reset()
	_player.facing = Vector2.RIGHT
	_check("bond arrière lancé", _player.dodge(Vector2.RIGHT))
	_check("recule en gardant la menace en face", _kit.dodge_motion_dir(Vector2.RIGHT).is_equal_approx(Vector2.LEFT) and _player.facing.is_equal_approx(Vector2.RIGHT))
	var x0: float = _player.global_position.x
	_player.dodge_step(0.05)
	_check("le bond arrière part vers l'arrière (hook dodge_motion_dir)", _player.global_position.x < x0 - 1.0, str(_player.global_position.x - x0))
	_player.reset_dodge()
	_reset()
	_player.spells.aim_override = Vector2(300, 0)
	_player.spells.cast(2)
	_advance(0.2)
	_check("pas de roulade pendant le Grand saut", not _kit.can_dodge())
	_until_ground()

	print("Mort")
	_reset()
	_player._damage_hp(9999.0)
	await get_tree().process_frame
	_check("anim death", String(vis.animation).begins_with("death_"), str(vis.animation))
	_reset()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame

	print("Partie réelle (main.tscn) avec Rainette : fumée")
	RunState.character = &"rainette"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 778)
	get_tree().root.add_child(main)
	await _frames(120)
	var mp: Node = main.get(&"player")
	_check("joueur de la partie = Rainette", mp != null and mp.get(&"kit") is RainetteKit)
	if mp != null and mp.get(&"kit") is RainetteKit:
		mp.spells.cast(4)
		mp.spells.cast(3)
		mp.spells.cast(2)
		await _frames(240)
		_check("partie toujours en cours", not bool(mp.get(&"dead")) or bool(main.get(&"run_over")))
	main.queue_free()
	await get_tree().process_frame
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
