extends Node
## API publiques des boss (game/CONTRACTS.md « APIs publiques inter-systèmes », lot « API publiques boss »).
## godot --headless --path game res://tests/boss_api_test.tscn  -> RESULT: OK
## Vérifie :
## 1. Player.push : la poussée s'arrête sur un mur (jamais à travers), va au bout sans mur, s'additionne ;
##    poussées fortes / très rapides contre un mur fin et vers le bord de carte : le joueur reste en zone
##    praticable ; Player.move_swept (attirance, éjection hors d'un conteneur avec `ignore`) ;
## 2. Player.apply_slow : le plus fort l'emporte (jamais de produit), même source = rafraîchie, compatible avec
##    le statut &"slow" (-30 %), expiration, remove_slow, clear_slow ;
## 3. EnemyProjectilePool.kill_in_circle / kill_in_segment (rayon du projectile compris) ;
## 4. Enemy.add_damage_taken_mod / remove_damage_taken_mod : produit, durée, expiration, remise à zéro au pool ;
## 5. NavField.add_obstacle : un vrai monstre (Director) contourne l'obstacle puis, retiré, passe tout droit ;
##    cellules bloquées / libérées, find_path qui contourne.

const U := 64.0
const DT := 1.0 / 60.0
const ARENA := 1280.0

var _fails := 0
var _player ## script player.gd (sans class_name)
var _director: Director
var _map: Node2D


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok  " + label)
	else:
		_fails += 1
		print("  ÉCHEC  " + label + ("  (" + detail + ")" if detail != "" else ""))


func _wall(parent: Node, center: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	b.add_child(cs)
	b.position = center
	parent.add_child(b)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	RunState.level = 1
	# arène carrée fermée + un mur vertical pour la poussée (x 200..264, y -300..300)
	_map = Node2D.new()
	_map.name = &"BossApiMap"
	get_tree().root.add_child(_map)
	_wall(_map, Vector2(0, -ARENA), Vector2(ARENA * 2 + 128, 128))
	_wall(_map, Vector2(0, ARENA), Vector2(ARENA * 2 + 128, 128))
	_wall(_map, Vector2(-ARENA, 0), Vector2(128, ARENA * 2 + 128))
	_wall(_map, Vector2(ARENA, 0), Vector2(128, ARENA * 2 + 128))
	_wall(_map, Vector2(232, 0), Vector2(64, 600))
	_wall(_map, Vector2(-400, 0), Vector2(8, 400)) # mur FIN (8 px : aucune case du NavField bloquée)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	_player.global_position = Vector2(100, 0)
	await get_tree().process_frame
	_director.bind_map(_map)
	await _frames(2)
	_player.grant_invulnerability(1000.0)

	await _push_checks()
	_player.set_physics_process(false) # suite pilotée par le test (tick manuel)
	_slow_checks()
	await _projectile_checks()
	await _damage_mod_checks()
	await _obstacle_checks()

	if _fails == 0:
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


# --- 1. Poussée --------------------------------------------------------------------------

func _push_checks() -> void:
	print("Poussée (Player.push)")
	var r := 24.0
	var cs := _player.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if cs != null and cs.shape is CircleShape2D:
		r = (cs.shape as CircleShape2D).radius
	_player.global_position = Vector2(100, 0)
	_check("poussée acceptée", _player.push(Vector2.RIGHT, 5.0, 0.2))
	_check("is_pushed pendant la poussée", _player.is_pushed())
	await _frames(30)
	var x: float = _player.global_position.x
	_check("bloquée par le mur (jamais à travers)", x <= 200.0 - r + 2.0 and x > 150.0, "x = %.1f, bord du mur 200, rayon %.0f" % [x, r])
	_check("poussée finie", not _player.is_pushed())
	# sans mur : distance complète (2 u vers la gauche) ; impulsion en px (strength < 0)
	var x0: float = _player.global_position.x
	_player.push(Vector2.LEFT, 2.0, 0.15)
	await _frames(20)
	_check("sans mur : 2 u parcourues", absf((x0 - _player.global_position.x) - 2.0 * U) < 3.0, "%.1f px" % (x0 - _player.global_position.x))
	var y0: float = _player.global_position.y
	_player.push(Vector2(0, 96), -1.0, 0.1)
	_player.push(Vector2(0, 32), -1.0, 0.1) # s'additionne
	await _frames(20)
	_check("impulsion en px, poussées additionnées", absf((_player.global_position.y - y0) - 128.0) < 3.0, "%.1f px" % (_player.global_position.y - y0))
	var y1: float = _player.global_position.y
	_player.push(Vector2(0, -40), -1.0, 0.0)
	_check("poussée immédiate (durée 0)", absf((y1 - _player.global_position.y) - 40.0) < 1.0)
	# poussées fortes : mur fin et bord de carte -> le joueur reste en zone praticable
	var nav := _director.nav
	_player.global_position = Vector2(-300, 0)
	_player.push(Vector2.LEFT, 20.0, 0.0)
	_check("poussée immédiate de 20 u contre un mur fin : arrêtée", _player.global_position.x > -400.0 + 4.0 + r - 2.0, str(_player.global_position))
	_player.global_position = Vector2(-300, 0)
	_player.push(Vector2.LEFT, 30.0, 0.1) # 320 px par image
	await _frames(12)
	_check("poussée très rapide (320 px / image) contre un mur fin : arrêtée", _player.global_position.x > -400.0 + 4.0 + r - 2.0, str(_player.global_position))
	_player.global_position = Vector2(-900, -900)
	_player.push(Vector2(-1, -1), 60.0, 0.05)
	await _frames(8)
	var pp: Vector2 = _player.global_position
	_check("poussée forte vers le coin de la carte : reste dedans, hors des murs", pp.x > -ARENA + 64.0 + r - 2.0 and pp.y > -ARENA + 64.0 + r - 2.0 and nav != null and not nav.is_wall_at(pp), str(pp))
	_player.global_position = Vector2(-900, -900)
	_player.move_swept(Vector2(-4000, 0))
	_check("move_swept (attirance) hors carte : bloqué au mur", _player.global_position.x > -ARENA + 64.0 + r - 2.0 and not nav.is_wall_at(_player.global_position), str(_player.global_position))
	# éjection hors d'un corps qui l'englobe (conteneur de la Grue) : traverse CE corps seulement
	var box := StaticBody2D.new()
	box.collision_layer = 1
	var bcs := CollisionShape2D.new()
	var brs := RectangleShape2D.new()
	brs.size = Vector2(128, 128)
	bcs.shape = brs
	box.add_child(bcs)
	box.position = Vector2(-700, 300)
	_map.add_child(box)
	await _frames(2)
	_player.global_position = Vector2(-700, 300)
	var moved: Vector2 = _player.move_swept(Vector2(0, 64.0 + r + 4.0), [box])
	_check("move_swept(ignore) : éjecté hors du conteneur", absf(moved.y - (64.0 + r + 4.0)) < 1.0, str(moved))
	box.queue_free()
	_player.global_position = Vector2(100, 0)
	await _frames(2)


# --- 2. Ralentissement -------------------------------------------------------------------

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01 * maxf(absf(b), 1.0)


func _slow_checks() -> void:
	print("Ralentissement paramétré (Player.apply_slow)")
	_player.clear_statuses()
	var base: float = _player.move_speed()
	_check("aucun ralentissement au départ", not _player.is_slowed() and _near(_player.slow_mult(), 1.0))
	_player.apply_slow(0.8, 1.0, &"furrow")
	_check("-20 % (Bouvier)", _near(_player.move_speed(), base * 0.8), "%.1f / %.1f" % [_player.move_speed(), base])
	_player.apply_slow(0.6, 0.5, &"web")
	_check("-40 % (Tisseuse) : le plus fort l'emporte (pas 0,48)", _near(_player.slow_mult(), 0.6), str(_player.slow_mult()))
	for i in 36: # 0,6 s
		_player.tick(DT)
	_check("la toile expire, le sillon reste", _near(_player.slow_mult(), 0.8), str(_player.slow_mult()))
	_player.apply_status(&"slow", {"hit": 0.0})
	_check("statut &\"slow\" (-30 %) compatible : plus fort que -20 %", _near(_player.slow_mult(), 0.7), str(_player.slow_mult()))
	_player.apply_slow(0.9, 5.0, &"furrow")
	_check("même source : rafraîchie (0,9), le statut garde -30 %", _near(_player.slow_mult(), 0.7) and _player.is_slowed())
	_player.clear_statuses()
	_player.apply_slow(0.9, 5.0, &"furrow")
	_check("même source remplacée (0,9)", _near(_player.slow_mult(), 0.9), str(_player.slow_mult()))
	_player.apply_slow(0.2, 1.0, &"deep")
	_check("plancher SLOW_FLOOR (0,5)", _near(_player.slow_mult(), _player.SLOW_FLOOR), str(_player.slow_mult()))
	_player.remove_slow(&"deep")
	_check("remove_slow", _near(_player.slow_mult(), 0.9))
	var node_src := Node.new()
	_player.apply_slow(0.75, 1.0, node_src)
	_check("source = nœud", _near(_player.slow_mult(), 0.75))
	node_src.free()
	_player.clear_slow()
	_check("clear_slow purge tout", not _player.is_slowed() and _near(_player.move_speed(), base))
	for i in 130: # immunité de 2 s du statut écoulée
		_player.tick(DT)


# --- 3. Projectiles ----------------------------------------------------------------------

func _projectile_checks() -> void:
	print("Projectiles ennemis (kill_in_circle / kill_in_segment)")
	var pool := _director.get_node(^"EnemyProjectiles") as EnemyProjectilePool
	pool.clear_all()
	var c := Vector2(-700, -700)
	pool.fire(null, c, Vector2.ZERO, 1.0)
	pool.fire(null, c + Vector2(25, 0), Vector2.ZERO, 1.0) # touche (25 <= 20 + rayon 9)
	pool.fire(null, c + Vector2(40, 0), Vector2.ZERO, 1.0) # hors du cercle
	pool.fire(null, Vector2(-700, 700), Vector2.ZERO, 1.0)
	_check("4 projectiles actifs", pool.active_count() == 4, str(pool.active_count()))
	_check("kill_in_circle : 2 arrêtés", pool.kill_in_circle(c, 20.0) == 2)
	_check("le 3e reste", pool.active_count() == 2)
	_check("kill_in_segment hors de portée : 0", pool.kill_in_segment(Vector2(-800, 600), Vector2(-600, 600), 20.0) == 0)
	_check("kill_in_segment : 1 arrêté (largeur + rayon)", pool.kill_in_segment(Vector2(-800, 685), Vector2(-600, 685), 20.0) == 1)
	_check("cull_segments (plusieurs fils) toujours là", pool.cull_segments(PackedVector2Array([c, c + Vector2(100, 0)]), 8.0) == 1)
	_check("pool vide", pool.active_count() == 0)
	await _frames(1)


# --- 4. Modificateur de dégâts reçus -----------------------------------------------------

func _damage_mod_checks() -> void:
	print("Dégâts reçus externes (Enemy.add_damage_taken_mod)")
	var e := _director.spawn_enemy(1, Vector2(-900, -900))
	_check("monstre de test", e != null)
	if e == null:
		return
	e.max_hp = 10000.0
	e.hp = 10000.0
	e.take_damage(100.0)
	_check("sans modificateur : 100", absf(e.hp - 9900.0) < 0.01)
	e.add_damage_taken_mod(&"lamp", 1.15, 0.3)
	e.take_damage(100.0)
	_check("lampe : +15 %", absf(e.hp - 9785.0) < 0.01, str(e.hp))
	e.add_damage_taken_mod(&"mark", 2.0)
	_check("produit des modificateurs (2,3)", _near(e.damage_taken_mod(), 2.3) and e.has_damage_taken_mod(&"lamp"))
	await _frames(30) # 0,5 s : la lampe expire (tick du Director)
	_check("expiration du modificateur temporaire", not e.has_damage_taken_mod(&"lamp") and _near(e.damage_taken_mod(), 2.0), str(e.damage_taken_mod()))
	e.remove_damage_taken_mod(&"mark")
	_check("remove_damage_taken_mod", _near(e.damage_taken_mod(), 1.0) and not e.has_damage_taken_mod(&"mark"))
	e.add_damage_taken_mod(&"mark", 3.0)
	_director.release_enemy(e)
	var e2 := _director.spawn_enemy(1, Vector2(-900, -900))
	_check("remis à zéro au retour du pool", e2 != null and _near(e2.damage_taken_mod(), 1.0))
	if e2 != null:
		_director.release_enemy(e2)


# --- 5. Obstacle dynamique ---------------------------------------------------------------

func _obstacle_checks() -> void:
	print("Obstacle dynamique (NavField.add_obstacle)")
	var nav := _director.nav
	_check("champ de la carte", nav != null)
	if nav == null:
		return
	_player.global_position = Vector2(700, 500)
	nav.compute_now(_player.global_position)
	var box := {"center": Vector2(0, 500), "half": Vector2(64, 340), "rot": 0.0} # mur de x -64..64, y 160..840
	_check("cellule libre avant", not nav.is_blocked_at(Vector2(0, 500)))
	_check("add_obstacle", nav.add_obstacle(&"test_wall", box) and nav.has_obstacle(&"test_wall") and nav.obstacle_count() == 1)
	_check("cellules bloquées", nav.is_blocked_at(Vector2(0, 500)) and nav.is_blocked_at(Vector2(0, 250)))
	_check("resolve sort du mur", not nav.in_dynamic_obstacle(nav.resolve(Vector2(10, 500), 20.0), 19.0))
	_check("is_spawnable faux dedans", not nav.is_spawnable(Vector2(0, 500)))
	var path := nav.find_path(Vector2(-700, 500), Vector2(700, 500))
	var through := false
	for p in path:
		through = through or nav.in_dynamic_obstacle(p, 8.0)
	_check("find_path contourne (%d points)" % path.size(), path.size() >= 2 and not through and path[path.size() - 1] == Vector2(700, 500))
	# un vrai monstre (Director) doit faire le tour
	var res := await _walk_monster(Vector2(-700, 500))
	_check("monstre arrivé de l'autre côté", res["passed"], str(res))
	_check("contourné (jamais à travers : passage à x = 0 hors de y 160..840)", res["passed"] and not res["through"], str(res))
	_check("remove_obstacle", nav.remove_obstacle(&"test_wall") and not nav.has_obstacle(&"test_wall") and not nav.is_blocked_at(Vector2(0, 500)))
	var res2 := await _walk_monster(Vector2(-700, 500))
	_check("obstacle retiré : passe tout droit", res2["passed"] and res2["through"], str(res2))
	_check("murs statiques intacts", nav.is_blocked_at(Vector2(232, 0)))


## Lâche un monstre de tier 1 en `from` et suit son passage de x < 0 à x > 0 (joueur à droite, invulnérable).
func _walk_monster(from: Vector2) -> Dictionary:
	var e := _director.spawn_enemy(1, from)
	var out := {"passed": false, "through": false, "cross_y": NAN, "t": 0.0}
	if e == null:
		return out
	var prev := e.position
	var t := 0.0
	while t < 16.0:
		await get_tree().physics_frame
		t += DT
		if not e.active:
			break
		var p := e.position
		if prev.x < 0.0 and p.x >= 0.0:
			var y := lerpf(prev.y, p.y, (0.0 - prev.x) / maxf(p.x - prev.x, 0.001))
			out["cross_y"] = y
			out["through"] = y > 160.0 + 8.0 and y < 840.0 - 8.0
		prev = p
		if OS.has_environment("BOSS_API_DEBUG") and int(t / DT) % 30 == 0:
			print("    t=%.1f p=%s steer=%s v=%d" % [t, p, _director.nav.steer(p), _director.nav.version])
		if p.x > 200.0:
			out["passed"] = true
			break
	out["t"] = t
	if e.active:
		_director.release_enemy(e)
	return out
