extends Node
## Perf : 250 monstres (mix T1/T2/T3 + élites, D ≈ 3) autour d'un faux joueur qui tourne en rond.
## Phase A : terrain vide. Phase B : même scénario sur une vraie carte (champ de flux + murs).
## godot --headless --fixed-fps 60 --path game res://tests/enemies_perf.tscn
## Phase C : même carte, les 250 monstres blessés en continu -> 250 barres de vie (EnemyHealthBars,
## un seul nœud) ; mesure le coût des barres (mise à jour + _draw) en plus de la boucle du Director.
## Imprime le temps de frame moyen (mur) et le coût de la boucle du Director.

const N := 250
const WARMUP_FRAMES := 30
const MEASURE_FRAMES := 360 # 6 s simulées à 60 Hz
const BUDGET_MS := 1.3 # médiane par frame (robuste aux pics des autres processus) ; cible ~1 ms sur PC de dev ; Android bas de gamme ≈ ×5-8
const MAP := "res://scenes/stage/maps/foret_brume.tscn"
var _map_path := MAP ## `-- --map=cite_fonderie_canal` : autre carte de scenes/stage/maps (comparaison A / B)
const BARS_BUDGET_MS := 0.35 ## 250 barres affichées (pire cas)
const HIT_EVERY := 30 ## phase C : chaque monstre reprend un coup toutes les 30 frames (< 3 s)

var _director: Node2D
var _player: Node2D
var _fails := 0
var _bars: EnemyHealthBars
var _hit_all := false
var _bars_usec := 0
var _bars_max := 0
var _picto_max := 0 ## pictogrammes de statut dessinés (lot A11y-L1) : tous les monstres portent un gel léger en phase C


func _ready() -> void:
	RunState.active_time_s = 400.0 # D ≈ 3 : tous les tiers, élites possibles
	_player = load("res://tests/enemies_fake_player.gd").new()
	add_child(_player)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	add_child(_director)
	_bars = EnemyHealthBars.new()
	add_child(_bars)
	_run.call_deferred()


func _run() -> void:
	await get_tree().physics_frame
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var a := await _phase("A terrain vide", Vector2.ZERO, null)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			_map_path = "res://scenes/stage/maps/%s.tscn" % arg.trim_prefix("--map=")
	var map: Node2D = load(_map_path).instantiate()
	add_child(map)
	_director.despawn_all()
	_director.bind_map(map)
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var b := await _phase("B carte %s" % _map_path.get_file(), map.get_player_start(), _director.nav)
	var nodes2 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("Surcoût de la carte : %.3f ms" % (b - a))
	_director.despawn_all()
	_hit_all = true
	var c := await _phase("C carte + 250 barres de vie", map.get_player_start(), _director.nav)
	var bars_ms := _bars_usec / (float(MEASURE_FRAMES) * 1000.0)
	print("  Barres de vie : %.3f ms/frame (jusqu'à %d barres)" % [bars_ms, _bars_max])
	_check("barres de vie : %d affichées, %.3f ms < %.2f ms" % [_bars_max, bars_ms, BARS_BUDGET_MS], _bars_max == N and bars_ms < BARS_BUDGET_MS)
	_check("pictogrammes de statut dessinés en lot sur les barres de base (max %d)" % _picto_max, _picto_max > 0)
	_check("Director avec barres (C %.3f) ≈ sans (B %.3f)" % [c, b], c < b * 1.25 + 0.05)
	_check("aucune instanciation pendant les phases (%d -> %d)" % [nodes1, nodes2], nodes1 == nodes2 and nodes0 > 0)
	_check("budget %.1f ms, médiane (A %.3f, B %.3f)" % [BUDGET_MS, a, b], a < BUDGET_MS and b < BUDGET_MS)
	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails else 0)


func _phase(label: String, center: Vector2, nav: NavField) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var placed := 0
	while placed < N:
		var tier := 1
		var r := rng.randf()
		if r < 0.10:
			tier = 3
		elif r < 0.32:
			tier = 2
		var pos := center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(200.0, 1100.0)
		if nav and not nav.is_spawnable(pos):
			continue
		_director.spawn_enemy(tier, pos, rng.randf() < 0.12)
		placed += 1
	var frame_sum := 0
	var dir_sum := 0
	var per_frame := PackedInt64Array() # coût du Director par frame (médiane : robuste aux autres processus)
	var parts := PackedInt64Array([0, 0, 0, 0, 0, 0])
	var min_active := N
	var last := Time.get_ticks_usec()
	for f in WARMUP_FRAMES + MEASURE_FRAMES:
		var t := f / 60.0
		var target := center + Vector2(cos(t * 0.8), sin(t * 0.8)) * 260.0
		_player.global_position = nav.resolve(target, 26.0) if nav else target
		if _hit_all and f % HIT_EVERY == 0:
			for e in _director._active:
				e.take_damage(e.max_hp * 0.005)
				e.apply_status(&"slow", {"pct": 0.01, "duration": 2.0}) # statut -> pictogramme sur chaque barre de base
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		if f >= WARMUP_FRAMES:
			frame_sum += now - last
			dir_sum += _director.stat_tick_usec
			per_frame.append(_director.stat_tick_usec)
			for k in 6:
				parts[k] += _director.stat_breakdown_usec[k]
			min_active = mini(min_active, _director.active_count())
			if _hit_all:
				_bars_usec += _bars.stat_usec
				_bars_max = maxi(_bars_max, _bars.visible_count())
				_picto_max = maxi(_picto_max, _bars.picto_count())
		last = now
	var n := float(MEASURE_FRAMES) * 1000.0
	per_frame.sort()
	var dir_ms := per_frame[per_frame.size() / 2] / 1000.0
	print("== Phase %s : %d monstres, %d frames" % [label, min_active, MEASURE_FRAMES])
	print("  Frame moyenne (mur, headless) : %.3f ms" % (frame_sum / n))
	print("  Boucle Director : médiane %.3f ms, moyenne %.3f ms, p90 %.3f ms" % [
		dir_ms, dir_sum / n, per_frame[per_frame.size() * 9 / 10] / 1000.0])
	print("    grille+séparation+meute %.3f (grille %.3f, meute %.3f) | ticks %.3f | projectiles %.3f | champ de flux %.3f" % [
		parts[0] / n, parts[3] / n, parts[4] / n, parts[1] / n, parts[2] / n, parts[5] / n])
	_check("  250 monstres maintenus", min_active == N)
	return dir_ms


func _check(label: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])
