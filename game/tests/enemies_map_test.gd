extends Node
## Monstres sur les 3 vraies cartes : 250 monstres apparus par le Director, 10 s simulées par
## carte, aucun ne doit finir dans un obstacle ni hors carte ; apparitions toujours valides.
## godot --headless --fixed-fps 60 --path game res://tests/enemies_map_test.tscn

const MAPS := [
	"res://scenes/stage/maps/foret_brume.tscn",
	"res://scenes/stage/maps/cite_rouille.tscn",
	"res://scenes/stage/maps/terrasses_noyees.tscn",
]
const FRAMES := 600 # 10 s à 60 Hz
const BUDGET_MS := 2.5 # médiane par frame, foule très dense (≈ 240 monstres au contact) : pire carte

var _fails := 0
var _director: Node2D
var _player: Node2D
var _stage: Node2D


func _ready() -> void:
	RunState.active_time_s = 400.0 # D ≈ 3 : tous les tiers et des élites
	_stage = Node2D.new()
	_stage.name = &"Stage"
	add_child(_stage)
	_player = load("res://tests/enemies_fake_player.gd").new()
	add_child(_player)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawn_ramp = false # test de charge à 250 : sans le plafond de mise en route (150 max)
	_director.waves_enabled = false
	add_child(_director)
	_run.call_deferred()


func _run() -> void:
	var worst_ms := 0.0
	for mi in MAPS.size():
		var path: String = MAPS[mi]
		for ch in _stage.get_children():
			ch.queue_free()
		_director.despawn_all()
		var map: Node2D = load(path).instantiate()
		_stage.add_child(map)
		var start: Vector2 = map.get_player_start()
		_player.global_position = start
		if mi == 0:
			_director.bind_map(map) # liaison explicite
		else:
			Events.floor_started.emit(mi + 1) # détection automatique
		await get_tree().physics_frame
		await get_tree().physics_frame
		var nav: NavField = _director.nav
		_check("%s : carte liée (%s)" % [path.get_file(), "explicite" if mi == 0 else "auto"], nav != null and _director.get_map() == map)
		if nav == null:
			continue

		# Points d'apparition : jamais dans un obstacle / hors carte
		var bad_spawn := 0
		var inf_spawn := 0
		for k in 1500:
			var p: Vector2 = _director._spawn_point(start)
			if p == Vector2.INF:
				inf_spawn += 1
			elif nav.is_inside_obstacle(p) or not nav.is_spawnable(p):
				bad_spawn += 1
		_check("  apparitions valides (%d invalides, %d sans point)" % [bad_spawn, inf_spawn], bad_spawn == 0 and inf_spawn < 150)

		# 10 s : le Director remplit jusqu'à 250, le joueur tourne autour du départ
		var dir_sum := 0
		var dir_n := 0
		var per_frame := PackedInt64Array() # médiane : robuste aux pics des autres processus (machine partagée)
		var nav_sum := 0
		var hits0: int = _player.hits
		var parts := PackedInt64Array([0, 0, 0, 0, 0, 0])
		for f in FRAMES:
			if _director.active_count() < 250:
				_director.credits = 1000.0
			var t := f / 60.0
			var target := start + Vector2(cos(t * 0.7), sin(t * 0.7)) * 220.0
			_player.global_position = nav.resolve(target, 26.0)
			await get_tree().physics_frame
			if _director.active_count() == 250:
				dir_sum += _director.stat_tick_usec
				per_frame.append(_director.stat_tick_usec)
				nav_sum += _director.stat_breakdown_usec[5]
				for k in 6:
					parts[k] += _director.stat_breakdown_usec[k]
				dir_n += 1
		var in_wall := 0
		var max_pen := 0.0
		var near := 0
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if nav.is_inside_obstacle(e.position):
				in_wall += 1
			max_pen = maxf(max_pen, _penetration(nav, e.position, e.radius_px))
			if e.position.distance_to(_player.global_position) < 4.0 * 64.0:
				near += 1
		per_frame.sort()
		var ms := per_frame[per_frame.size() / 2] / 1000.0 if not per_frame.is_empty() else 0.0
		worst_ms = maxf(worst_ms, ms)
		print("  Director médiane %.3f ms, moyenne %.3f ms (dont champ de flux %.3f ms) ; %d monstres ; %d à < 4 u du joueur ; coups %d ; pénétration max %.1f px" % [
			ms, dir_sum / maxf(dir_n, 1.0) / 1000.0, nav_sum / maxf(dir_n, 1.0) / 1000.0, _director.active_count(), near, _player.hits - hits0, max_pen])
		var dn := maxf(dir_n, 1.0) * 1000.0
		print("    séparation+grille+meute %.3f | ticks %.3f | projectiles %.3f | (grille %.3f, meute %.3f)" % [parts[0] / dn, parts[1] / dn, parts[2] / dn, parts[3] / dn, parts[4] / dn])
		_check("  250 monstres atteints", dir_n > 0)
		_check("  aucun monstre dans un obstacle (%d)" % in_wall, in_wall == 0)
		_check("  les monstres rejoignent le joueur (%d proches)" % near, near >= 20)
	# Référence : même foule, même joueur, sans carte (mesure du surcoût du champ de flux)
	var start2: Vector2 = _player.global_position
	_director.bind_map(null)
	var ref_sum := 0
	var ref_frames := PackedInt64Array()
	for f in 180:
		var t := f / 60.0
		_player.global_position = start2 + Vector2(cos(t * 0.7), sin(t * 0.7)) * 40.0
		await get_tree().physics_frame
		ref_sum += _director.stat_tick_usec
		ref_frames.append(_director.stat_tick_usec)
	ref_frames.sort()
	var ref_ms := ref_frames[ref_frames.size() / 2] / 1000.0
	print("Référence sans carte, même foule : %.3f ms -> surcoût carte ≈ %.3f ms (pire carte)" % [ref_ms, worst_ms - ref_ms])
	_check("budget %.1f ms tenu (pire carte %.3f ms)" % [BUDGET_MS, worst_ms], worst_ms < BUDGET_MS)
	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails else 0)


## Recouvrement max d'un cercle avec les obstacles (en px), pour information.
func _penetration(nav: NavField, p: Vector2, r: float) -> float:
	p = nav.to_map(p) # nav.rects est en repère carte (tourné de 45° sur une carte iso)
	var worst := 0.0
	for rect in nav.rects:
		var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
		worst = maxf(worst, r - p.distance_to(q))
	return worst


func _check(label: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])
