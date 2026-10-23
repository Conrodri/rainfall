extends Node
## Test headless de Rictus (docs/Design_Personnages.md §2.6) : stats, 4 sorts, couteaux plantés (S6),
## Toupie (levée permise, invulnérable, sort 1 suspendu, vertige, +2 % PV), Doublures (S14 : provocation, explosion
## à 3 s, mort à 60 %), étoile (ultime puis Toupie), levée au-dessus des monstres, déblocage caché.
## godot --headless --path game res://tests/rictus_test.tscn  (scène : les autoloads doivent exister)

## Cible factice sans corps (zones, doublures) : mêmes signatures que player_test.
class FakeEnemy extends Node2D:
	var taken: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


## Cible factice avec corps en couche 3 (projectiles Area2D, et obstacle « monstre » pour la levée).
class FakeBody extends StaticBody2D:
	var taken: Array = []

	func _init(radius := 10.0) -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new()
		sh.radius = radius
		cs.shape = sh
		add_child(cs)

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)


const U := 64.0
const BASE := 12.0 ## Dégât_base niveau 1

var _fails := 0
var _player: CharacterBody2D
var _kit: Node
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


func _body(pos: Vector2, radius := 10.0, as_enemy := true) -> FakeBody:
	var b := FakeBody.new(radius)
	if as_enemy:
		b.add_to_group("enemies")
	get_tree().root.add_child(b)
	b.global_position = pos
	_junk.append(b)
	return b


## Doublures posées à la frame d'impact de `summon` (Player.play_action) : avance le joueur jusqu'à l'impact,
## sort 1 suspendu pour ne pas toucher les cibles factices. Retourne le temps écoulé.
func _land_decoys() -> float:
	var rem1: float = _player.spells._remaining[1]
	var t := 0.0
	while _kit.decoys_pending() and t < 1.0:
		_player.spells._remaining[1] = 99.0
		_player.tick(0.01)
		t += 0.01
	_player.spells._remaining[1] = rem1
	return t


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Remet tout à plat : cibles, doublures, couteaux, états, recharges.
func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	Decoy.clear_all()
	_kit.clear_transients()
	_kit.spin_left = 0.0
	_kit.stagger_left = 0.0
	_kit.lifting = false
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.apply_stats({"crit_chance": -0.05}) # crit désactivé : dégâts déterministes
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player._dodge_cd = 0.0
	_player._invuln = 0.0


func _run() -> void:
	RunState.level = 1
	RunState.character = &"rictus"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false) # boucle pilotée par le test (pas d'auto-tir parasite)
	_kit = _player.kit

	print("Personnage et rendu")
	_check("kit Rictus", _kit is RictusKit)
	_check("4 sorts / ids", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["dagues_demi_lune", "eventail", "toupie", "doublures"])
	_check("PV L1 = 95", _near(_player.max_hp, 95.0), str(_player.max_hp))
	_check("armure 10", _near(_player.armor(), 10.0))
	_check("régén 0,6", _near(_player.regen_per_s(), 0.6))
	_check("vitesse 4,2 u/s", _near(_player.move_speed(), 4.2 * U), str(_player.move_speed()))
	var shape := (_player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	_check("hitbox 0,45 u", _near(shape.radius, 24.0 * 0.9), str(shape.radius))
	_check("Montreur (CompanionSprite) alpha 0,8", _kit.companion != null and _near(_kit.companion.self_modulate.a, 0.8))
	_check("Montreur à 1,4 u", _kit.companion != null and _kit.companion.position.y < Iso.lift_logical(1.3))
	_check("5 fils (StringRig)", _kit.strings != null and _kit.strings.lines.size() == 5)
	var steel := true
	for sp in RictusKit.character().spells:
		steel = steel and sp.light_preset == &"spell_steel"
	_check("lumière des sorts argent (jamais la braise d'Ardent)", steel)
	_check("fils fins et discrets", _kit.strings.lines[0].width <= 1.0 and _near(_kit.strings.lines[0].default_color.a, RictusKit.STRING_ALPHA))
	var vis := _player.get_node("Visual") as AnimatedSprite2D
	var companion_idx: int = _kit.companion.get_index()
	_check("ordre : pantin < fils < Montreur < projectiles", vis.get_index() < _kit.strings.get_index()
			and _kit.strings.get_index() < companion_idx and companion_idx < _player.get_node("SpellFX").get_index())
	if not ResourceLoader.exists(RictusKit.SPRITE_FRAMES):
		_check("repli : Ardent teinté", vis.self_modulate.is_equal_approx(RictusKit.PLACEHOLDER_TINT))
	_kit.strings.update_lines(0.1)
	_check("fils tracés entre deux points distincts", _kit.strings.lines[2].points[0].distance_to(_kit.strings.lines[2].points[2]) > 10.0)

	print("Sort 1 : Dagues en demi-lune")
	_reset()
	print("Équilibrage 22/10 : garde du Montreur")
	_check("sans demi-lune : dégâts pleins", is_equal_approx(_kit.damage_taken_mult(null), 1.0))
	_kit.on_cast(_player.character.spells[0])
	_check("après une demi-lune : −30 %", is_equal_approx(_kit.damage_taken_mult(null), RictusKit.GUARD_TAKEN_MULT))
	_kit.tick(RictusKit.GUARD_S + 0.05)
	_check("garde finie", is_equal_approx(_kit.damage_taken_mult(null), 1.0))
	_check("sans ennemi : aucun coup, aucune recharge", not _player.spells.cast(1) and _player.get_spell_cooldowns()[0].remaining == 0.0)
	var front := _fake(Vector2(80, 0))
	var front2 := _fake(Vector2(60, 50))
	var back := _fake(Vector2(-80, 0))
	var far := _fake(Vector2(300, 0))
	_check("demi-lune lancée", _player.spells.cast(1))
	_check("coef 0,8 sur la cible", front.taken.size() == 1 and _near(front.total(), RictusKit.ARC_COEF * BASE), str(front.taken))
	_check("tout le demi-cercle", _near(front2.total(), RictusKit.ARC_COEF * BASE), str(front2.taken))
	_check("rien derrière", back.taken.is_empty())
	_check("rien hors de 1,8 u", far.taken.is_empty())
	_check("orientation vers la cible la plus proche", _player.facing.dot(front2.global_position.normalized()) > 0.99, str(_player.facing))

	print("Sort 2 : Éventail et couteaux plantés (S6)")
	_reset()
	var wall_free_target := _body(Vector2(128, 0), 10.0)
	_player.spells.aim_override = Vector2(500, 0)
	_check("éventail lancé", _player.spells.cast(2))
	_check("5 couteaux", _player.spells.active_projectile_count() == 5, str(_player.spells.active_projectile_count()))
	await _frames(45) # 7 u à 14 u/s = 0,5 s
	_check("couteau central : coef 1,6", wall_free_target.taken.size() == 1 and _near(wall_free_target.taken[0], RictusKit.FAN_COEF * BASE), str(wall_free_target.taken))
	_check("5 couteaux plantés en fin de course", _kit.knives.size() == 5, str(_kit.knives.size()))
	var rem0: float = _player.spells._remaining[2]
	_check("Éventail en recharge (6 s)", _near(rem0, 6.0, 0.05), str(rem0))
	if _kit.knives.size() > 0:
		_player.global_position = _kit.knives[0].global_position
		await _frames(2)
		_check("ramasser un couteau rend 1 s", _near(_player.spells._remaining[2], rem0 - 1.0, 0.02), str(_player.spells._remaining[2]))
		_check("couteau ramassé disparaît", _kit.knives.size() == 4, str(_kit.knives.size()))
		for k in _kit.knives.duplicate():
			_player.global_position = k.global_position
			await _frames(2)
		_check("5 couteaux = 5 s rendues au plus", _near(_player.spells._remaining[2], rem0 - 5.0, 0.05), str(_player.spells._remaining[2]))
	_player.spells.aim_override = null

	print("Sort 3 : Toupie")
	_reset()
	var close := _fake(Vector2(40, 0))
	_player.hp = 50.0
	_check("toupie lancée", _player.spells.cast(3))
	_check("en toupie", _kit.is_spinning())
	_check("premier tick 0,7", _near(close.total(), RictusKit.TOUPIE_COEF * BASE), str(close.taken))
	_check("levée permise en toupie", _kit.can_dodge())
	_check("bouton de roulade actif", not bool(_player.get_dodge_cooldown().get("blocked", false)))
	_check("invulnérable en toupie", _player.is_invulnerable())
	_check("sort 1 suspendu", _player.spells.is_slot_blocked(1) and not _player.spells.cast(1))
	_check("sort 2 autorisé", not _player.spells.is_slot_blocked(2))
	_check("vitesse 4,8 u/s", _near(_player.move_speed(), 4.8 * U), str(_player.move_speed()))
	_check("inertie 0,3 s", _near(_kit.inertia_s(), 0.3))
	_player.apply_status(&"slow", {})
	_check("immunité aux ralentissements", not _player.is_slowed())
	_check("hitbox 0,5 u en toupie", _near(shape.radius, 24.0))
	# M2b : spin = 1 direction (bras écartés), jouée quelle que soit l'orientation ; M3 : traînée additive
	_player.facing = Vector2.DOWN
	_player.tick(0.0)
	var spin_anim: StringName = _kit.visual_anim(&"idle_s")
	_check("anim spin en toupie (toute orientation)", String(spin_anim).begins_with("spin"), String(spin_anim))
	var blur_ok: bool = not ResourceLoader.exists(RictusKit.SPIN_BLUR_FRAMES) or (_kit.spin_blur != null and _kit.spin_blur.visible)
	_check("spin_blur visible en toupie", blur_ok)
	for i in 50:
		_player.tick(0.05)
	_player.tick(0.001)
	# (la demi-lune reprend dès la fin de la toupie : on ne compte que les ticks de 0,7)
	var spin_hits := close.taken.filter(func(a): return _near(a, RictusKit.TOUPIE_COEF * BASE))
	_check("10 ticks = 7,0", spin_hits.size() == 10, str(close.taken))
	_check("fin de toupie", not _kit.is_spinning())
	_check("fils tendus : +2 % PV", _player.hp >= 50.0 + 0.02 * 95.0 - 0.01, str(_player.hp))
	_check("spin_blur caché hors toupie", _kit.spin_blur == null or not _kit.spin_blur.visible)
	_check("vertige : vitesse 2,1", _kit.is_staggered() and _near(_player.move_speed(), 2.1 * U), str(_player.move_speed()))
	_check("vertige : pas de roulade", not _player.dodge(Vector2.RIGHT))
	_player.tick(0.31)
	_check("après le vertige : roulade permise", _kit.can_dodge() and not _kit.is_staggered())

	print("Sort 4 : Les Doublures (S14)")
	_reset()
	_player.spells.aim_override = Vector2(500, 0)
	_check("doublures lancées", _player.spells.cast(4))
	_check("pas encore posées (anim summon)", Decoy.live.is_empty() and _kit.decoys_pending())
	var t_land := _land_decoys()
	_check("posées à la frame d'impact de summon", t_land > 0.05 and t_land < 0.6, str(t_land))
	_check("6 doublures", Decoy.live.size() == 6, str(Decoy.live.size()))
	_check("anim d'ultime throw_ult (M2b)", _kit.ult_action() == &"throw_ult", String(_kit.ult_action()))
	var d_any: Decoy = Decoy.live[0]
	_check("explosion : VFX double_burst (TOP)", d_any.explode_spell.vfx_frames == RictusKit.DOUBLE_BURST_FRAMES
			and _near(d_any.explode_spell.vfx_floor_aspect, 1.0) and d_any.flight_spell.vfx_frames == "")
	var east: Decoy = null
	for d in Decoy.live:
		if d.global_position.distance_to(Vector2(1.2 * U, 0)) < 1.0:
			east = d
	_check("première vers la visée, anneau 1,2 u", east != null)
	_check("PV = 20 % des PV max", east != null and _near(east.hp, 0.2 * 95.0))
	_check("face vers l'extérieur", east != null and east.facing.x > 0.99)
	_check("Montreur absent des doublures", east != null and east.get_child_count() - int(GroundMarker.of(east) != null) == 1)
	for d in Decoy.live:
		d.life_s = 30.0 # provocation testée sans explosion
	# Monstre à 3,3 u de la doublure sud-est et 4,4 u de Rictus : il doit la viser
	var se_pos := Vector2(1.2 * U, 0).rotated(TAU / 6.0)
	var mob: Enemy = director.spawn_enemy(1, Vector2(200, 200))
	var mob_hp0: float = _player.hp
	var se: Decoy = Decoy.nearest_to(se_pos, 4.0)
	var d0 := mob.position.distance_to(se.global_position)
	await _frames(150)
	_check("provocation : le monstre rejoint la doublure", mob.position.distance_to(se.global_position) < d0 * 0.5, "%s -> %s" % [d0, mob.position.distance_to(se.global_position)])
	_check("provocation : la doublure encaisse, pas Rictus", se.hp < se.max_hp and _near(_player.hp, mob_hp0), "%s / %s" % [se.hp, _player.hp])
	mob.deactivate()
	mob.remove_from_group(&"enemies")
	# Explosion au minuteur (3 s) : un monstre sur la doublure est
	Decoy.clear_all()
	await get_tree().process_frame
	_player.spells._remaining[4] = 0.0
	_player.hp = 50.0
	_check("relance", _player.spells.cast(4))
	_land_decoys()
	_player.hp = 50.0
	var on_east := _fake(Vector2(1.2 * U, 0))
	for d in Decoy.live:
		_check("minuteur 3 s", _near(d.life_s, 3.0))
		break
	for d in Decoy.live.duplicate():
		d.step(2.9)
	_check("pas d'explosion avant 3 s", Decoy.live.size() == 6 and on_east.taken.is_empty())
	for d in Decoy.live.duplicate():
		d.step(0.11)
	_check("toutes explosent à 3 s", Decoy.live.is_empty())
	_check("3 explosions à 2 u : 3 × 3,0", _near(on_east.total(), 3.0 * RictusKit.DECOY_COEF * BASE, 0.05), "%s %s" % [on_east.total(), on_east.taken])
	_check("+2 % PV une seule fois", _near(_player.hp, 50.0 + 0.02 * 95.0, 0.01), str(_player.hp))
	# Doublure tuée : explosion immédiate à 60 %
	_player.spells._remaining[4] = 0.0
	on_east.taken.clear()
	_player.spells.cast(4)
	_land_decoys()
	for d in Decoy.live:
		if d.global_position.distance_to(on_east.global_position) < 1.0:
			d.take_damage(1000.0)
	_check("doublure tuée : explosion 60 % (1,8)", on_east.taken.size() >= 1 and _near(on_east.taken[0], RictusKit.DECOY_DEATH_FRAC * RictusKit.DECOY_COEF * BASE), str(on_east.taken))
	_check("les autres restent", Decoy.live.size() == 5, str(Decoy.live.size()))

	print("L'étoile : Doublures puis Toupie")
	_reset()
	_player.spells.aim_override = Vector2(500, 0)
	_player.spells.cast(4)
	_land_decoys()
	var in_path := _fake(Vector2(3.0 * U, 0)) # sur la trajectoire de la doublure est, après 1,8 u de vol
	var decoys := Decoy.live.duplicate()
	_check("toupie au milieu", _player.spells.cast(3))
	var pushed := 0
	for d in decoys:
		if d.pushed and d.flying:
			pushed += 1
	_check("les 6 doublures percutées d'un coup", pushed == 6, str(pushed))
	_check("une seule poussée par doublure", not decoys[0].push())
	await _frames(20)
	var far_ok := true
	for d in decoys:
		if is_instance_valid(d) and d.flown_px > 4.0 * U + 1.0:
			far_ok = false
	_check("vol limité à 4 u", far_ok)
	await _frames(25) # 4 u à 10 u/s = 0,4 s
	_check("toutes explosent (impact ou bout de course)", Decoy.live.is_empty(), str(Decoy.live.size()))
	_check("monstre traversé : 1,0 puis explosion 2,5", in_path.taken.size() >= 2 and _near(in_path.taken[0], 1.0 * BASE)
			and in_path.taken.has(RictusKit.DECOY_COEF * BASE), str(in_path.taken))

	print("Levée (roulade du Montreur)")
	_reset()
	var wall_of_mobs: Array = []
	for y in [-30, 0, 30]:
		wall_of_mobs.append(_body(Vector2(96, y), 20.0, false))
	await _frames(2)
	_player.set_physics_process(true)
	_check("levée lancée", _player.dodge(Vector2.RIGHT))
	_check("masque sans la couche 3", (_player.collision_mask & 4) == 0 and (_player.collision_mask & 1) == 1)
	_check("invulnérable", _player.is_invulnerable())
	_check("sorts suspendus pendant la levée", _player.spells.is_slot_blocked(1) and _player.spells.is_slot_blocked(4))
	await _frames(8)
	_check("pantin soulevé", vis.position.y < -5.0, str(vis.position.y))
	await _frames(14)
	_player.set_physics_process(false)
	_check("passe au-dessus des monstres : 3 u", _near(_player.global_position.x, 3.0 * U, 3.0), str(_player.global_position))
	_check("retombé", not _kit.lifting and _near(vis.position.y, 0.0, 0.5), str(vis.position.y))

	print("Nettoyage (étage) et déblocage caché")
	_reset()
	_player.spells.cast(4)
	Events.floor_started.emit(2)
	await get_tree().process_frame
	_check("changement d'étage : doublures disparues", Decoy.live.is_empty())
	var prof: Node = load("res://scripts/save/profile.gd").new()
	prof.write_enabled = false
	prof.path = "user://rictus_test_profile.json" # jamais écrit (write_enabled faux)
	prof.open_characters = [] # configuration de sortie : Rictus non ouvert par characters.json
	var u1: Array = prof.add_run_result({"mode": &"moyen", "close_kills": 150})
	_check("150 tués au contact : pas encore", not prof.is_character_unlocked(&"rictus") and u1.is_empty())
	var u2: Array = prof.add_run_result({"mode": &"moyen", "close_kills": 60})
	_check("200 cumulés : Rictus débloqué", prof.is_character_unlocked(&"rictus") and u2.has(&"character:rictus"), str(u2))
	prof.free()

	_reset()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame

	print("Partie réelle (main.tscn) avec Rictus : fumée")
	RunState.character = &"rictus"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 777) # sauvegardes coupées en headless (main._saves_enabled)
	get_tree().root.add_child(main)
	await _frames(120)
	var mp: Node = main.get(&"player")
	_check("joueur de la partie = Rictus", mp != null and mp.get(&"kit") is RictusKit)
	if mp != null and mp.get(&"kit") is RictusKit:
		mp.spells.cast(4)
		mp.spells.cast(3)
		await _frames(200)
		_check("partie toujours en cours après étoile", not bool(mp.get(&"dead")) or bool(main.get(&"run_over")))
	main.queue_free()
	await get_tree().process_frame
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
