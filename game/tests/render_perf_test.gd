extends Node
## Budgets de rendu et des systèmes d'ambiance PAR PALIER (Haut, Moyen, Bas) sur une partie chargée :
## vraie scène de jeu (main.tscn), D ≈ 5, ~250 monstres autour du joueur, tous blessés (250 barres
## de vie affichées). Pour chaque palier : temps CPU / GPU de rendu (fenêtre seulement : en headless
## le rendu n'est pas mesuré) et coût par image des systèmes CPU mesurés en appel direct :
## AmbianceManager._process, LightRig._process, CreatureShadows._process, EnemyHealthBars._process.
##   godot --path game res://tests/render_perf_test.tscn -- --map=terrasses_noyees [--shots=C:/dossier]
##   godot --headless --path game res://tests/render_perf_test.tscn   (budgets CPU seulement)
## Les budgets de rendu sont calés sur un PC de dev (marge ×2) : ils détectent une régression
## (ex. HDR 2D rallumé en Moyen), pas la cible mobile.

const WARMUP := 90
const FRAMES := 180
const CALLS := 200
const N := 250
const D_TARGET := 5.0
const TIERS := [2, 1, 0]
## Budgets CPU des systèmes (ms par image, 250 monstres) : valables en headless comme en fenêtre.
const SYS_BUDGET_MS := {"ambiance": 0.3, "light_rig": 0.2, "creature_shadows": 0.15, "health_bars": 0.3} ## avant 22/10 : 0,21 / 0,12 / 0,26 / 0,17
## Budgets du CPU de rendu (ms) par palier : en Moyen et Bas le HDR 2D est coupé (≈ -1 ms mesuré).
const RENDER_CPU_BUDGET_MS := {2: 4.5, 1: 2.0, 0: 2.0} ## Moyen avec HDR 2D : 2,6 ms ; sans : 1,1 ms (PC de dev)

var map_id := "terrasses_noyees"
var shots_dir := ""
var _main: Node
var _rng := RandomNumberGenerator.new()
var _fail := PackedStringArray()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="): map_id = a.substr(6)
		elif a.begins_with("--shots="): shots_dir = a.substr(8)
	var headless := DisplayServer.get_name() == "headless"
	Quality.persist = false
	Quality.dynamic_degrade = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if not headless:
		get_window().size = Vector2i(1920, 1080)
	_rng.seed = 7
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 777)
	_main.set(&"map_scene", load("res://scenes/stage/maps/%s.tscn" % map_id))
	add_child(_main)
	await _main.game_ready
	var lo := 0.0
	var hi := 100000.0
	for i in 40:
		var mid := (lo + hi) * 0.5
		if Balance.difficulty(mid, RunState.stage, Balance.MODES[RunState.mode]) < D_TARGET:
			lo = mid
		else:
			hi = mid
	RunState.active_time_s = lo
	var player: Node2D = _main.player
	player.grant_invulnerability(1.0e6)
	player.set_physics_process(false) # immobile, sans sorts : les monstres restent blessés, non tués
	player.set_process(false)
	var director: Director = _main.director
	director.spawning_enabled = false
	var amb: AmbianceManager = _main.ambiance
	amb.set_difficulty(RunState.difficulty())
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for t in TIERS:
		Quality.set_tier(t, true)
		Quality.dynamic_degrade = false
		for i in WARMUP:
			_top_up(director, player)
			await get_tree().process_frame
		var gpu := 0.0
		var cpu := 0.0
		for i in FRAMES:
			_top_up(director, player)
			await get_tree().process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu /= FRAMES
		cpu /= FRAMES
		var sys := {
			"ambiance": _time_calls(func(): amb._process(1.0 / 60.0)),
			"light_rig": _time_calls(func(): amb.rig._process(1.0 / 60.0)),
			"creature_shadows": _time_calls(func(): amb.creature_shadows._process(1.0 / 60.0)),
			"health_bars": _time_calls(func(): _main.health_bars._process(0.0)),
		}
		var bars: int = _main.health_bars.visible_count() # delta 0 : les barres ne vieillissent pas
		print("RPERF | map=%s | tier=%s | hdr=%s | glow=%s | enemies=%d | bars=%d | cpu_render=%.3f ms | gpu=%.3f ms | ambiance=%.3f | light_rig=%.3f | creature_shadows=%.3f (n=%d) | health_bars=%.3f" % [
			map_id, Quality.tier_name(), get_tree().root.use_hdr_2d, amb.environment.glow_enabled, director.active_count(), bars,
			cpu, gpu, sys["ambiance"], sys["light_rig"], sys["creature_shadows"], amb.creature_shadows.count, sys["health_bars"]])
		if bars < 200:
			_fail.append("tier %d : %d barres de vie seulement (attendu ~250)" % [t, bars])
		if amb.creature_shadows.count < 200:
			_fail.append("tier %d : %d ombres de contact seulement" % [t, amb.creature_shadows.count])
		for k in SYS_BUDGET_MS:
			if float(sys[k]) > float(SYS_BUDGET_MS[k]):
				_fail.append("tier %d : %s %.3f ms > budget %.2f ms" % [t, k, sys[k], SYS_BUDGET_MS[k]])
		if not headless:
			if cpu > float(RENDER_CPU_BUDGET_MS[t]):
				_fail.append("tier %d : CPU de rendu %.3f ms > budget %.2f ms" % [t, cpu, RENDER_CPU_BUDGET_MS[t]])
			if (t < 2) == get_tree().root.use_hdr_2d:
				_fail.append("tier %d : HDR 2D %s (attendu : Haut seulement)" % [t, get_tree().root.use_hdr_2d])
			if shots_dir != "":
				await get_tree().process_frame
				var path := "%s/rperf_%s_t%d.png" % [shots_dir, map_id, t]
				_save_shot(path)
				print("capture : ", path)
	if _fail.is_empty():
		print("RESULT: OK")
	else:
		for f in _fail:
			print("ECHEC : ", f)
		print("RESULT: FAIL")
	get_tree().quit(0 if _fail.is_empty() else 1)


## Coût moyen (ms) d'un appel, sur CALLS appels consécutifs (après 10 appels de chauffe).
func _time_calls(f: Callable) -> float:
	for i in 10:
		f.call()
	var t0 := Time.get_ticks_usec()
	for i in CALLS:
		f.call()
	return (Time.get_ticks_usec() - t0) / 1000.0 / CALLS


## Maintient ~N monstres (mix T1/T2/T3 + élites) autour du joueur, chacun blessé (barre affichée).
func _top_up(director: Director, player: Node2D) -> void:
	var need := N - director.active_count()
	var tries := 0
	while need > 0 and tries < 400:
		tries += 1
		var pos := player.global_position + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(260.0, 1100.0)
		if director.nav and not director.nav.is_spawnable(pos):
			continue
		var r := _rng.randf()
		var e := director.spawn_enemy(3 if r < 0.1 else (2 if r < 0.32 else 1), pos, _rng.randf() < 0.12)
		need -= 1
		if e != null:
			e.take_damage(1.0)
	if Engine.get_process_frames() % 60 == 0: # garde les barres visibles (masquées 3 s après le dernier coup)
		for e in director.get_tree().get_nodes_in_group(&"enemies"):
			var en := e as Enemy
			if en != null and en.active and en.hp > 1.0:
				en.take_damage(0.01)


## Capture fidèle à l'écran : en HDR 2D la texture du viewport est linéaire (-> sRGB avant PNG).
func _save_shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if get_viewport().use_hdr_2d:
		img = preload("res://tests/perf_bench.gd").linear_to_srgb8(img)
	img.save_png(path)
