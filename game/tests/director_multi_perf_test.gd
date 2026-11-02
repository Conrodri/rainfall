extends Node
## Coop 1-4, lot « Director, monstres et boss » (docs/multi/Archi_Reseau.md §1.2 lignes 7-8).
## godot --headless --fixed-fps 60 --path game res://tests/director_multi_perf_test.tscn  -> RESULT: OK
##
## 1. Performance : 250 monstres sur une vraie carte (champ de flux + murs), boucle du Director en solo (un joueur,
##    chemin historique) puis à 4 joueurs dispersés (BFS multi-sources, cibles, projectiles contre 4 hitbox) ;
##    mesures alternées solo / coop groupé / coop dispersé (×2), médianes. Critères : surcoût du code coop (4 joueurs
##    groupés, même charge de jeu que le solo) < solo × 1,15 ; 4 joueurs dispersés < solo × 1,30 (charge de jeu
##    comprise : 4 mêlées au lieu d'une, plus de monstres en marche ; mesuré ≈ × 1,21 le 02/11/2026).
## 2. Comportements : solo strictement historique (aucune cible posée, Enemy.coop faux), cibles réparties entre les
##    joueurs avec inertie, spectateur ignoré, champ à 4 sources, PV de boss figés à l'apparition × (1 + 0,3 (n - 1)),
##    tueur transmis (hit["by"] -> Events.enemy_killed_by), projectile qui touche un joueur non visé, spawn jamais
##    dans le champ de vision d'un autre joueur.

const N := 250
const WARMUP_FRAMES := 30
const MEASURE_FRAMES := 300
const RATIO_MAX := 1.15
const RATIO_SPREAD_MAX := 1.30 ## dispersés : surcoût du code + charge de jeu (plus de monstres en marche)
## Monstres posés à 200-900 px du départ : dans le rayon de simulation pleine (LOD) du joueur solo comme des 4 joueurs
## (même charge de ticks dans les deux modes : on mesure le surcoût de la coop, pas plus de monstres à l'écran).
const RING_MAX_PX := 900.0
const MAP := "res://scenes/stage/maps/foret_brume.tscn"
## Joueurs dispersés autour du départ (px logiques) : tous à l'écran d'une caméra partagée, aucun superposé.
const OFFSETS: Array[Vector2] = [Vector2(-520, -300), Vector2(520, -300), Vector2(-520, 300), Vector2(520, 300)]

var _director: Director
var _map: Node2D
var _center := Vector2.ZERO
var _players: Array[Node2D] = []
var _anchors: Array[Vector2] = []
var _fails := 0
var _killers: Array[int] = []
var _stacked := false ## coop groupé : les 4 joueurs suivent la trajectoire du joueur solo (même charge de jeu)


func _ready() -> void:
	RunState.active_time_s = 400.0 # D ≈ 3 : tous les tiers, élites possibles
	Players.clear()
	for i in 4:
		var p: Node2D = load("res://tests/enemies_fake_player.gd").new()
		p.name = "FakePlayer%d" % i
		add_child(p)
		_players.append(p)
		if i > 0:
			p.remove_from_group(&"player") # solo : un seul joueur dans le groupe (joueur 1 implicite)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	add_child(_director)
	_map = load(MAP).instantiate()
	add_child(_map)
	Events.enemy_killed_by.connect(func(pid: int, _e: Node2D, _p: Vector2, _t: int, _el: bool) -> void: _killers.append(pid))
	_run.call_deferred()


func _run() -> void:
	await get_tree().physics_frame
	_center = _map.get_player_start()
	_director.bind_map(_map)
	var nav := _director.nav
	for i in 4:
		_anchors.append(nav.nearest_reachable(_center + OFFSETS[i]) if nav else _center + OFFSETS[i])
	_park_extra_players()

	# --- Performance : alterné solo / coop / solo / coop -------------------------------------------------------
	# coop groupé : 4 joueurs sur la trajectoire du solo -> même charge de jeu, l'écart = surcoût du code coop ;
	# coop dispersé : en plus, plus de monstres en marche (répartis sur 4 cibles au lieu d'une mêlée unique).
	var solo := PackedFloat64Array()
	var grouped := PackedFloat64Array()
	var coop := PackedFloat64Array()
	for round_i in 2:
		_set_coop(false)
		solo.append(await _phase("solo", round_i == 0))
		_stacked = true
		_set_coop(true)
		grouped.append(await _phase("coop 4 joueurs groupés", false))
		_stacked = false
		_set_coop(true)
		coop.append(await _phase("coop 4 joueurs dispersés", round_i == 0))
	var s := (solo[0] + solo[1]) * 0.5
	var g := (grouped[0] + grouped[1]) * 0.5
	var c := (coop[0] + coop[1]) * 0.5
	print("Boucle Director : solo %.3f ms, coop groupé %.3f ms (×%.2f), coop dispersé %.3f ms (×%.2f)" % [
		s, g, g / maxf(s, 0.001), c, c / maxf(s, 0.001)])
	_check("perf : surcoût du code coop (groupé %.3f ms) < solo (%.3f ms) × %.2f" % [g, s, RATIO_MAX], g < s * RATIO_MAX)
	_check("perf : coop dispersé, charge comprise (%.3f ms) < solo (%.3f ms) × %.2f" % [c, s, RATIO_SPREAD_MAX], c < s * RATIO_SPREAD_MAX)

	# --- Comportements ------------------------------------------------------------------------------------------
	await _spectator_ignored()
	await _boss_hp_frozen()
	await _kill_attribution()
	await _projectile_any_player()
	await _spawn_out_of_sight()

	Players.clear()
	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails else 0)


## Coop : les 4 joueurs inscrits dans le registre ; solo : registre vide, joueur 1 implicite (groupe `player`).
func _set_coop(on: bool) -> void:
	Players.clear()
	for i in 4:
		RunState.player_state(i).spectating = false
	if on:
		for i in 4:
			Players.register(_players[i], null, i)
	_park_extra_players()


## Hors coop, les joueurs 2-4 sont loin de tout (ils ne jouent pas) ; en coop, à leur ancre.
func _park_extra_players() -> void:
	var on := Players.count() > 1
	for i in range(1, 4):
		_players[i].global_position = _anchors[i] if on else Vector2(-100000, -100000)
	_players[0].global_position = _anchors[0] if on else _center
	if on and _stacked:
		for i in 4:
			_players[i].global_position = _center + Vector2(i * 12.0, 0.0)


func _spawn_wave(rng: RandomNumberGenerator) -> void:
	var nav := _director.nav
	var placed := 0
	while placed < N:
		var tier := 1
		var r := rng.randf()
		if r < 0.10:
			tier = 3
		elif r < 0.32:
			tier = 2
		var pos := _center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(200.0, RING_MAX_PX)
		if nav and not nav.is_spawnable(pos):
			continue
		_director.spawn_enemy(tier, pos, rng.randf() < 0.12)
		placed += 1


func _move_players(f: int) -> void:
	var nav := _director.nav
	var t := f / 60.0
	if Players.count() <= 1:
		var target := _center + Vector2(cos(t * 0.8), sin(t * 0.8)) * 260.0
		_players[0].global_position = nav.resolve(target, 26.0) if nav else target
		return
	if _stacked:
		var base := _center + Vector2(cos(t * 0.8), sin(t * 0.8)) * 260.0
		for i in 4:
			var tg := base + Vector2(i * 12.0, 0.0)
			_players[i].global_position = nav.resolve(tg, 26.0) if nav else tg
		return
	for i in 4:
		var target := _anchors[i] + Vector2(cos(t * 0.8 + i), sin(t * 0.8 + i)) * 200.0
		_players[i].global_position = nav.resolve(target, 26.0) if nav else target


## Une mesure : 250 monstres (même graine dans les deux modes), médiane du coût de la boucle du Director.
func _phase(label: String, with_checks: bool) -> float:
	_director.despawn_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_spawn_wave(rng)
	var per_frame := PackedInt64Array()
	var parts := PackedInt64Array([0, 0, 0, 0, 0, 0])
	var min_active := N
	var prev := {}
	var switches := 0
	var reversals := 0
	var before := {}
	var counted := 0
	var far := 0
	var far_n := 0
	for f in WARMUP_FRAMES + MEASURE_FRAMES:
		_move_players(f)
		await get_tree().physics_frame
		if f < WARMUP_FRAMES:
			continue
		per_frame.append(_director.stat_tick_usec)
		for k in 6:
			parts[k] += _director.stat_breakdown_usec[k]
		min_active = mini(min_active, _director.active_count())
		if f % 30 == 0: # monstres hors du rayon de simulation pleine (LOD) du joueur le plus proche
			far += _far_count()
			far_n += 1
		if with_checks and f % 6 == 0: # inertie : changements de cible relevés toutes les 6 images
			for e in _director._active:
				var id := e.get_instance_id()
				if prev.has(id) and prev[id] != e.target_id:
					switches += 1
					if before.get(id, -2) == e.target_id: # retour à la cible d'avant : va-et-vient
						reversals += 1
					before[id] = prev[id]
				prev[id] = e.target_id
			counted += 1
	per_frame.sort()
	var ms := per_frame[per_frame.size() / 2] / 1000.0
	var n := float(MEASURE_FRAMES) * 1000.0
	print("== %s : %d monstres, médiane %.3f ms, p90 %.3f ms" % [label, min_active, ms, per_frame[per_frame.size() * 9 / 10] / 1000.0])
	print("    grille+séparation+meute %.3f | ticks %.3f | projectiles %.3f | champ de flux %.3f | hors LOD %.1f" % [
		parts[0] / n, parts[1] / n, parts[2] / n, parts[5] / n, float(far) / maxf(far_n, 1)])
	if with_checks:
		_check("%s : 250 monstres maintenus" % label, min_active == N)
		var targets := {}
		for e in _director._active:
			targets[e.target_id] = int(targets.get(e.target_id, 0)) + 1
		if Players.count() <= 1:
			_check("solo : chemin historique (Enemy.coop faux, aucune cible posée)", not Enemy.coop and targets.size() == 1 and targets.has(-1))
		else:
			print("    cibles : %s ; changements de cible : %d (dont %d retours) sur %d relevés" % [str(targets), switches, reversals, counted])
			_check("coop : Enemy.coop et 4 vivants partagés", Enemy.coop and Enemy.coop_count == 4)
			_check("coop : champ de flux à 4 sources", _director.nav != null and _director.nav.source_count() == 4)
			_check("coop : monstres répartis sur au moins 3 joueurs", targets.size() >= 3 and not targets.has(-1))
			# suivre le plus proche à pied quand les joueurs bougent est voulu ; le défaut, c'est le va-et-vient A -> B -> A
			var secs := float(N) * (float(counted) * 6.0 / 60.0)
			var per_s := float(switches) / secs
			var back_s := float(reversals) / secs
			_check("coop : inertie (%.3f changement de cible par monstre et par s < 0,35)" % per_s, per_s < 0.35)
			_check("coop : pas de va-et-vient (%.3f retour par monstre et par s < 0,05)" % back_s, back_s < 0.05)
	return ms


func _far_count() -> int:
	var half := _director._spawn_half_extent().length() + Director.LOD_MARGIN_PX
	var coop := Players.count() > 1
	var n := 0
	for e in _director._active:
		var best := INF
		for i in (4 if coop else 1):
			best = minf(best, e.position.distance_to(_players[i].global_position))
		if best > half:
			n += 1
	return n


func _spectator_ignored() -> void:
	_set_coop(true)
	_director.despawn_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_spawn_wave(rng)
	for f in 20:
		_move_players(f)
		await get_tree().physics_frame
	Players.set_spectating(3)
	for f in 20:
		_move_players(20 + f)
		await get_tree().physics_frame
	var on3 := 0
	for e in _director._active:
		if e.target_id == 3:
			on3 += 1
	_check("spectateur : plus aucun monstre ne le poursuit (%d)" % on3, on3 == 0)
	_check("spectateur : retiré des joueurs vivants partagés (%d)" % Enemy.coop_count, Enemy.coop_count == 3)
	RunState.player_state(3).spectating = false


func _boss_hp_frozen() -> void:
	_director.despawn_all()
	_set_coop(false)
	await get_tree().physics_frame
	var b1 := _director.spawn_boss(&"mini", _center) as Enemy
	var hp1 := b1.max_hp
	_check("boss solo : n à l'apparition = 1", b1.party_n_at_spawn == 1)
	_director.release_enemy(b1)
	_set_coop(true)
	await get_tree().physics_frame
	var b4 := _director.spawn_boss(&"mini", _center) as Enemy
	var ratio := b4.max_hp / hp1
	_check("boss coop : PV × %.2f (attendu %.2f)" % [ratio, Balance.boss_party_hp_mult(&"mini", 4)], absf(ratio - Balance.boss_party_hp_mult(&"mini", 4)) < 0.001 and b4.party_n_at_spawn == 4)
	Players.set_spectating(2)
	await get_tree().physics_frame
	_check("boss coop : PV figés après une mort", b4.max_hp == hp1 * ratio)
	RunState.player_state(2).spectating = false
	# cible de boss : gardée Balance.COOP_BOSS_RETARGET_S, remplacée tout de suite si elle meurt
	await get_tree().physics_frame
	var t0 := b4.target_id
	_check("boss coop : une cible vivante", t0 >= 0 and t0 < 4)
	Players.set_spectating(t0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("boss coop : cible morte remplacée (%d -> %d)" % [t0, b4.target_id], b4.target_id != t0 and b4.target_id >= 0)
	RunState.player_state(t0).spectating = false
	_director.release_enemy(b4)


func _kill_attribution() -> void:
	_director.despawn_all()
	_killers.clear()
	var e := _director.spawn_enemy(1, _center + Vector2(900, 0))
	e.take_damage(e.max_hp * 0.1, false, &"", {"by": 1})
	e.take_damage(e.max_hp * 10.0, false, &"", {"by": 2})
	var e2 := _director.spawn_enemy(1, _center + Vector2(-900, 0))
	e2.apply_status(&"burn", {"total": e2.max_hp * 10.0, "duration": 1.0, "by": 3})
	for f in 40:
		await get_tree().physics_frame
		if not e2.active:
			break
	var e3 := _director.spawn_enemy(1, _center + Vector2(0, 900))
	e3.take_damage(e3.max_hp * 10.0)
	_check("tueur transmis : %s (attendu [2, 3, -1])" % str(_killers), _killers == [2, 3, Events.NO_PLAYER])


func _projectile_any_player() -> void:
	_set_coop(true)
	_director.despawn_all()
	await get_tree().physics_frame
	var before: Array[int] = []
	for p in _players:
		before.append(p.hits)
	var target: Node2D = _players[3]
	var from := target.global_position + Vector2(-120, 0)
	_director.fire_projectile(null, from, Vector2(600, 0), 5.0)
	for f in 30:
		await get_tree().physics_frame
	_check("projectile ennemi : touche le joueur 4 (pas le joueur 1)", _players[3].hits > before[3] and _players[0].hits == before[0])


func _spawn_out_of_sight() -> void:
	_set_coop(true)
	_director.despawn_all()
	_director.spawn_ramp = false
	_director.waves_enabled = false
	_director.credits = 400.0 # banque pleine : on teste les points d'apparition, pas le débit
	_director.spawning_enabled = true
	var half: Vector2 = _director._spawn_half_extent() # champ de vision (écran), sans la marge d'apparition
	var box := Rect2(-half, half * 2.0)
	var known := {}
	var seen := 0
	var near := [0, 0, 0, 0]
	for f in 60:
		await get_tree().physics_frame
		for e in _director._active: # nouvelles apparitions : position relevée à l'image où elles apparaissent
			var id := e.get_instance_id()
			if known.has(id):
				continue
			known[id] = true
			var best := 0
			var best_d := INF
			for i in 4:
				if box.has_point(e.position - _players[i].global_position):
					seen += 1
				var d := e.position.distance_squared_to(_players[i].global_position)
				if d < best_d:
					best_d = d
					best = i
			near[best] += 1
	_director.spawning_enabled = false
	print("    spawn coop : %d apparitions, plus proche joueur : %s" % [known.size(), str(near)])
	_check("spawn coop : des apparitions (%d)" % known.size(), known.size() > 10)
	_check("spawn coop : aucune dans le champ de vision d'un joueur (%d)" % seen, seen == 0)
	_check("spawn coop : autour de plusieurs joueurs", near.count(0) <= 1)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])
