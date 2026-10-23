extends Node
## Test headless de la hitbox de dégâts unifiée (PlayerHitbox) et de l'anneau de hitbox au sol (HitboxRing).
## - Source unique : Player.set_hitbox_u règle le rayon de DÉGÂTS lu par le contact des monstres (Enemy),
##   le pool de projectiles, les cerveaux de boss / mini-boss et les pièges.
## - À la limite : contact et projectile touchent à 0,5 u et pas à 0,45 u ; Bourbe (0,6 u) touché à vide, plus
##   avec 4 mottes dehors (0,45 u).
## - Anneau : taille exacte, suit le rayon, flash au coup, éclat orienté vers la source (projectile : point
##   d'impact), piège sans position = flash seul ; réglage « Cercle de collision du héros » (ex-« Afficher la hitbox ») (fichier injecté).
## godot --headless --path game res://tests/hitbox_test.tscn

const U := 64.0
const SETTINGS := "user://hitbox_test_settings.cfg"

var _fails := 0
var _player: CharacterBody2D
var _director: Node2D
var _pool: EnemyProjectilePool
var _damaged := 0


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


func _on_damaged(_amount: float, _source: Variant) -> void:
	_damaged += 1


func _spawn_player(id: StringName) -> void:
	RunState.character = id
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_player.global_position = Vector2.ZERO


func _ready_to_hit() -> void:
	_player._invuln = 0.0
	_player.dead = false
	_player.refresh_max_hp(true)


## Monstre de base réel à `gap` px au-delà de son propre rayon, dans la direction `dir` : une passe de tick.
func _contact_hits(gap: float, dir := Vector2.RIGHT) -> bool:
	_ready_to_hit()
	var e: Enemy = _director.spawn_enemy(1, Vector2(-40 * U, -40 * U))
	e.global_position = _player.global_position + dir.normalized() * (e.radius_px + gap)
	e._attack_cd = 0.0
	var n := _damaged
	e.tick(0.0001, _player, _player.global_position, Vector2.ZERO, Vector2.ZERO, false)
	e.global_position = Vector2(-60 * U, -60 * U) # hors jeu (Director arrêté)
	return _damaged > n


## Projectile ennemi immobile à `gap` px au-delà du rayon du projectile, une passe du pool.
func _projectile_hits(gap: float, dir := Vector2.RIGHT, source: Node2D = null) -> bool:
	_ready_to_hit()
	var pos := _player.global_position + dir.normalized() * (EnemyProjectilePool.RADIUS_PX + gap)
	_pool.fire(source, pos, Vector2.ZERO, 5.0)
	var n := _damaged
	_pool.update(0.0001, _player, _player.global_position)
	_pool.clear_all()
	return _damaged > n


func _run() -> void:
	RunState.level = 1
	GameSettings.cfg_path = SETTINGS # jamais le settings.cfg réel du joueur
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	Events.player_damaged.connect(_on_damaged)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	await get_tree().process_frame
	_director.process_mode = Node.PROCESS_MODE_DISABLED # les monstres ne bougent que par nos ticks
	_pool = _director.get_node(^"EnemyProjectiles") as EnemyProjectilePool
	await _spawn_player(&"ardent")
	var ring: HitboxRing = _player.hitbox_ring()

	print("Grammaire des formes (lot UX D) : la hitbox n'est ni un losange, ni un hexagone, ni une aura")
	_check("hitbox = anneau continu + 4 crans, forme unique parmi les sens",
			GroundShapes.shape_of(&"hitbox") == &"ring_ticks" and GroundShapes.shape_of(&"hitbox") != GroundShapes.shape_of(&"loot")
			and GroundShapes.shape_of(&"hitbox") != GroundShapes.shape_of(&"summon") and GroundShapes.shape_of(&"hitbox") != GroundShapes.shape_of(&"elite_burn"))
	_check("anneau toujours au rayon exact des dégâts (les crans sont à l'extérieur)", ring != null and _near(ring.radius_px(), _player.hit_radius_px(), 0.6) and HitboxRing.TICK_LEN_PX > 0.0)

	print("Source unique (Ardent, sans hitbox_u)")
	_check("hit_radius_px = 26 (référence)", _near(_player.hit_radius_px(), PlayerHitbox.BASE_PX), str(_player.hit_radius_px()))
	_check("PlayerHitbox / Enemy recopiés", _near(PlayerHitbox.radius_px, 26.0) and _near(Enemy.PLAYER_RADIUS_PX, 26.0))
	_player.set_hitbox_u(0.45)
	var r45 := 26.0 * 0.45 / 0.5
	_check("set_hitbox_u(0,45) -> 23,4 px", _near(_player.hit_radius_px(), r45), str(_player.hit_radius_px()))
	_check("Enemy.PLAYER_RADIUS_PX suit", _near(Enemy.PLAYER_RADIUS_PX, r45))
	var brains := {
		"CerfBrain": CerfBrain.PLAYER_R, "SonneurBrain": SonneurBrain.PLAYER_R, "RecluseBrain": RecluseBrain.PLAYER_R,
		"RainSowerBrain": RainSowerBrain.PLAYER_R, "WeaverBrain": WeaverBrain.PLAYER_R, "CraneBrain": CraneBrain.PLAYER_R,
		"CrystalMotherBrain": CrystalMotherBrain.PLAYER_R, "DeepEelBrain": DeepEelBrain.PLAYER_R,
		"EclusierBrain": EclusierBrain.PLAYER_R, "HermitCedarBrain": HermitCedarBrain.PLAYER_R,
		"JarBearerBrain": JarBearerBrain.PLAYER_R, "OxHerderBrain": OxHerderBrain.PLAYER_R,
		"SmelterBrain": SmelterBrain.PLAYER_R, "MiniBossBrain": MiniBossBrain.PLAYER_R, "MiniPatterns.PR": MiniPatterns.PR,
		"MiniHazards.PLAYER_HIT_R": MiniHazards.PLAYER_HIT_R, "Floor1Hazards": Floor1Hazards.PLAYER_R,
		"SmelterSlag": SmelterSlag.PLAYER_R, "WeaverSnare": WeaverSnare.PLAYER_R,
	}
	var bad := []
	for k in brains:
		if not _near(float(brains[k]), r45):
			bad.append("%s=%s" % [k, brains[k]])
	_check("boss, mini-boss et pièges suivent (%d)" % brains.size(), bad.is_empty(), str(bad))
	_check("Floor1Hazards.inside : marge par défaut = rayon joueur", Floor1Hazards.inside({"shape": &"circle", "pos": Vector2.ZERO, "r": 100.0}, Vector2(100.0 + r45 - 0.5, 0)) \
			and not Floor1Hazards.inside({"shape": &"circle", "pos": Vector2.ZERO, "r": 100.0}, Vector2(100.0 + r45 + 0.5, 0)))
	var shape := (_player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	_check("cercle de collision suit aussi (24 × 0,45 / 0,5)", _near(shape.radius, 21.6), str(shape.radius))

	print("Contact et projectile à la limite (gap 25 px : dans 26, hors de 23,4)")
	_player.set_hitbox_u(0.5)
	_check("contact : touché à 0,5 u", _contact_hits(25.0))
	_check("projectile : touché à 0,5 u", _projectile_hits(25.0))
	_player.set_hitbox_u(0.45)
	_check("contact : PAS touché à 0,45 u", not _contact_hits(25.0))
	_check("projectile : PAS touché à 0,45 u", not _projectile_hits(25.0))
	_check("contact franc toujours touché à 0,45 u", _contact_hits(20.0))

	print("Anneau de hitbox")
	_check("anneau présent, enfant du joueur, sous le corps", ring != null and ring.get_parent() == _player and ring.z_index < 0)
	_check("visible par défaut (réglage absent)", ring.visible and ring.enabled)
	ring._process(0.0)
	_check("rayon de l'anneau = rayon de dégâts (23,4)", _near(ring.radius_px(), r45), str(ring.radius_px()))
	_check("pic de la texture d'anneau au rayon exact", _near(ring.drawn_half_extent() * HitboxRing.RING_PEAK_PX / HitboxRing.TEX_HALF, r45))
	_player.set_hitbox_u(0.6)
	ring._process(0.0)
	_check("l'anneau suit set_hitbox_u (31,2)", _near(ring.radius_px(), 31.2), str(ring.radius_px()))
	ring._process(1.0)
	_check("au repos : ni flash ni éclat", ring.flash_left() == 0.0 and ring.arc_left() == 0.0)
	var src_dir := Vector2(-1.0, 0.6)
	_check("coup de contact depuis le sud-ouest", _contact_hits(5.0, src_dir))
	_check("flash de l'anneau (~0,25 s)", _near(ring.flash_left(), HitboxRing.FLASH_S, 0.02), str(ring.flash_left()))
	_check("éclat allumé", ring.arc_left() > 0.0)
	_check("éclat orienté vers la source", absf(angle_difference(ring.arc_angle(), src_dir.angle())) < 0.05, "%f vs %f" % [ring.arc_angle(), src_dir.angle()])
	ring._process(HitboxRing.FLASH_S + 0.01)
	_check("flash éteint après 0,25 s", ring.flash_left() == 0.0)
	_check("éclat encore en fondu", ring.arc_left() > 0.0)
	ring._process(1.0)
	_check("éclat estompé", ring.arc_left() == 0.0)
	var shooter: Enemy = _director.spawn_enemy(1, Vector2(10 * U, 0)) # tireur à l'est, projectile arrivé du nord
	_check("projectile touché (nord)", _projectile_hits(5.0, Vector2.UP, shooter))
	_check("éclat côté point d'impact (nord), pas côté tireur", absf(angle_difference(ring.arc_angle(), -PI / 2.0)) < 0.05, str(ring.arc_angle()))
	shooter.global_position = Vector2(-60 * U, -60 * U)
	ring._process(1.0)
	var hazard := Node2D.new() # piège : nœud sans position de combat (à l'origine)
	add_child(hazard)
	hazard.global_position = Vector2(3 * U, 3 * U)
	_ready_to_hit()
	_player.take_damage(5.0, hazard)
	_check("piège : flash de l'anneau", ring.flash_left() > 0.0)
	_check("piège : pas d'éclat orienté", ring.arc_left() == 0.0)
	hazard.queue_free()
	ring._process(1.0)
	var lvl: int = Quality.flashes_level
	Quality.flashes_level = 0
	_check("flashs coupés : éclat quand même (doux)", _contact_hits(5.0, Vector2.DOWN) and ring.arc_left() > 0.0 and ring._soft)
	Quality.flashes_level = lvl
	ring._process(1.0)

	print("Réglage « Cercle de collision du héros » (fichier injecté)")
	GameSettings.set_show_hitbox(get_tree(), false)
	_check("désactivé : anneau masqué à chaud", not ring.visible and not ring.enabled)
	_check("désactivé : relu", not GameSettings.show_hitbox())
	GameSettings.set_show_hitbox(get_tree(), true)
	_check("réactivé", ring.visible and GameSettings.show_hitbox())
	GameSettings.set_show_hitbox(get_tree(), false)
	GameSettings.reset_all(get_tree())
	_check("Réinitialiser : défaut affiché", ring.visible and GameSettings.show_hitbox())
	var panel_src := FileAccess.get_file_as_string("res://scripts/ui/settings_panel.gd")
	_check("ligne de réglage dans le menu", panel_src.contains("\"Cercle de collision du héros\""))

	print("Sortie du joueur")
	_player.queue_free()
	await get_tree().process_frame
	_check("rayon remis à la référence", _near(PlayerHitbox.radius_px, 26.0) and _near(Enemy.PLAYER_RADIUS_PX, 26.0))

	print("Bourbe : mottes dehors = moins de coups à la limite")
	await _spawn_player(&"bourbe")
	var kit := _player.kit as BourbeKit
	ring = _player.hitbox_ring()
	_check("Bourbe 0,6 u -> 31,2 px", _near(_player.hit_radius_px(), 31.2), str(_player.hit_radius_px()))
	_check("contact à 28 px : touché", _contact_hits(28.0))
	_check("projectile à 28 px : touché", _projectile_hits(28.0))
	_player.spells.aim_override = Vector2(-6 * U, 0) # mottes loin à l'ouest : elles ne provoquent pas le monstre de l'est
	for i in BourbeKit.MAX_MOTTES:
		_player.spells._remaining[2] = 0.0
		_player.spells.cast(2)
		for f in 30:
			_player.spells._remaining[1] = 99.0
			_player.tick(1.0 / 60.0)
			for m in kit.mottes.duplicate():
				if is_instance_valid(m):
					m.step(1.0 / 60.0)
	_check("4 mottes dehors", kit.out_count() == BourbeKit.MAX_MOTTES, str(kit.out_count()))
	_check("hitbox 0,45 u -> 23,4 px", _near(_player.hit_radius_px(), r45), str(_player.hit_radius_px()))
	_check("Enemy / PlayerHitbox suivent", _near(Enemy.PLAYER_RADIUS_PX, r45) and _near(PlayerHitbox.radius_px, r45))
	_check("contact à 28 px : PAS touché", not _contact_hits(28.0))
	_check("projectile à 28 px : PAS touché", not _projectile_hits(28.0))
	ring._process(0.0)
	_check("anneau rétréci avec les mottes", _near(ring.radius_px(), r45), str(ring.radius_px()))

	_player.queue_free()
	_director.queue_free()
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	GameSettings.cfg_path = GameSettings.PATH
	await get_tree().process_frame
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
