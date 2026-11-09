class_name MapPerfBench
extends Node
## Banc de performance par carte (mode test, bac à sable : rien n'est écrit au profil ni dans quality.cfg).
## Pour chaque carte réelle demandée, chaque palier de qualité (Bas / Moyen / Haut) et chaque charge de monstres
## (0, 80, 250 par défaut), avec l'événement d'ambiance forcé à D 7,5 : chauffe, puis mesure pendant `seconds` s du temps
## d'image (moyenne, p95, p99), du process et de la physique, du rendu (GPU / CPU), des draw calls et objets rendus, du
## nombre de nœuds, des lumières et occluders actifs et des bandes d'eau (ColorRect peu profond / profond).
## Le joueur reste immobile au départ, invulnérable (PV illimités du mode test), sort 1 automatique ; les monstres sont
## maintenus au nombre visé autour de lui (mélange T1 / T2 / T3 + 12 % d'élites, comme tests/perf_bench.gd).
## Sortie : user://perf_bench/bench_<date>.json + .txt (tableau et résumé lisible), exportables (zip, feuille de partage
## Android / explorateur sur PC, comme les journaux de run).
## Lancement : onglet Cartes du panneau de test (« Banc de perf »), ou tests/map_perf_bench.tscn (PC, rendu réel).
## À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

signal progress(text: String)
signal finished(result: Dictionary)
signal row_done(row: Dictionary) ## une configuration mesurée (lanceur PC : affichage au fil de l'eau)

const OUT_DIR := "user://perf_bench"
const AMBIENT_D := 7.5
const DEFAULT_COUNTS: Array[int] = [0, 80, 250]
const DEFAULT_TIERS: Array[int] = [0, 1, 2]
const MAX_FRAMES := 8192 ## tampon de temps d'image préalloué (10 s à 800 i/s)
const TOPUP_PER_FRAME := 8 ## pendant la mesure : remplacement des morts, au plus N apparitions par image
## Seuils de jugement (p95 du temps d'image, ms) : Haut 60 i/s, Moyen 45 i/s, Bas 30 i/s.
const P95_LIMIT_MS := {0: 33.4, 1: 22.3, 2: 16.7}
const OCCLUDER_LIMIT := 40 ## plafond d'occluders visibles (docs/Design_Variantes_B.md §8)
const B_SLOWER_TOL := 0.10 ## une B est signalée si son temps d'image dépasse celui de la A de plus de 10 %

var maps: Array[String] = [] ## vide = les 9 cartes du catalogue (TestMaps)
var tiers: Array[int] = DEFAULT_TIERS.duplicate()
var counts: Array[int] = DEFAULT_COUNTS.duplicate()
var seconds := 10.0
var warmup_s := 1.5
var load_wait_s := 1.0
var prewarm_s := 2.0
var restore_after := true ## remet la carte, la qualité, les triches et la vsync d'avant à la fin
var with_ui := true ## bandeau de progression et fenêtre de résultat (le test PC le coupe)
## Reprend aussitôt le menu pause s'il s'ouvre pendant le banc (perte de focus de la fenêtre :
## PauseMenu._notification). Sans cela, la mesure attend indéfiniment la reprise (le menu pause reste
## affiché, la boucle tourne sans vsync à 100 % d'un cœur) : c'étaient les « gels » du banc PC du
## 09/11/2026 (docs/Mesures_Perf_Android.md §7). Le lanceur PC l'active ; sur téléphone, le joueur reprend lui-même.
var resume_on_pause := false
var aborted := false
var result: Dictionary = {}
var json_path := ""
var txt_path := ""

var _rng := RandomNumberGenerator.new()
var _frame_ms := PackedFloat32Array()
var _proc_ms := PackedFloat32Array()
var _phys_ms := PackedFloat32Array()
var _dir_ms := PackedFloat32Array()
var _ui: CanvasLayer
var _ui_label: Label
var _ui_panel: PanelContainer
var _ui_text: Label
var _running := false


## Ajoute un banc à la scène de jeu et le lance. `opts` : {maps, tiers, counts, seconds}. Retourne le nœud (null hors jeu).
static func launch(tree: SceneTree, opts: Dictionary = {}) -> MapPerfBench:
	var sm := tree.get_first_node_in_group(&"stage_manager")
	if sm == null or not TestMode.active:
		return null
	for n in tree.get_nodes_in_group(&"map_perf_bench"):
		if (n as MapPerfBench)._running:
			return null
	var b := MapPerfBench.new()
	b.name = "MapPerfBench"
	if opts.has("maps"):
		b.maps.assign(opts["maps"])
	if opts.has("tiers"):
		b.tiers.assign(opts["tiers"])
	if opts.has("counts"):
		b.counts.assign(opts["counts"])
	b.seconds = float(opts.get("seconds", b.seconds))
	sm.get_parent().add_child(b)
	b.run.call_deferred()
	return b


## Durée estimée d'un banc (s) : chargements + chauffes + mesures.
static func estimate_s(n_maps: int, n_tiers: int, n_counts: int, secs: float) -> float:
	return n_maps * (3.0 + 2.0 + n_tiers * (0.6 + n_counts * (1.5 + secs)))


func _ready() -> void:
	add_to_group(&"map_perf_bench")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7
	_frame_ms.resize(MAX_FRAMES)
	_proc_ms.resize(MAX_FRAMES)
	_phys_ms.resize(MAX_FRAMES)
	_dir_ms.resize(MAX_FRAMES)


func run() -> Dictionary:
	_running = true
	var tree := get_tree()
	var sm: StageManager = tree.get_first_node_in_group(&"stage_manager") as StageManager
	var director: Director = tree.get_first_node_in_group(&"director") as Director
	if sm == null or director == null:
		_running = false
		return {}
	if maps.is_empty():
		for e in TestMaps.catalog():
			maps.append(String(e.id))
	if with_ui:
		_build_ui()
	# état à rendre
	var saved := {
		"map": TestMode.map_id, "ambient": TestMode.ambient_d, "d": TestMode.d_value, "god": TestMode.god,
		"spawns": TestMode.spawns, "tier": Quality.tier, "auto": Quality.auto, "calibrated": Quality.calibrated,
		"persist": Quality.persist, "dyn": Quality.dynamic_degrade, "vsync": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps, "paused": tree.paused,
	}
	Quality.persist = false
	Quality.dynamic_degrade = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	tree.paused = false
	TestMode.set_flag(&"god", true)
	TestMode.set_flag(&"spawns", false)
	director.spawning_enabled = false
	director.waves_enabled = false
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var rows: Array = []
	var t_start := Time.get_ticks_msec()
	var total := maps.size() * tiers.size() * counts.size()
	var done := 0
	for id in maps:
		if aborted:
			break
		var entry := TestMaps.entry(id)
		if entry.is_empty() or not TestMaps.load_map(tree, id):
			push_warning("MapPerfBench : carte « %s » impossible à charger" % id)
			continue
		director.spawning_enabled = false
		TestMode.set_difficulty(AMBIENT_D)
		TestMode.set_ambient_d(AMBIENT_D)
		await _wait_s(load_wait_s)
		# préchauffe non mesurée : charge maximale (compilation des shaders des monstres, pool activé une fois)
		_say("%s : préchauffe" % id)
		var pre_t := Time.get_ticks_msec()
		var pl: Node2D = Players.all()[0] as Node2D if not Players.all().is_empty() else null
		while Time.get_ticks_msec() - pre_t < int(prewarm_s * 1000.0) and not aborted:
			_resume_pause_menu()
			_top_up(director, pl, counts.max() if not counts.is_empty() else 0, 60)
			await tree.process_frame
		director.despawn_all()
		for t in tiers:
			if aborted:
				break
			Quality.set_tier(t, true)
			await _wait_s(0.6)
			for n in counts:
				if aborted:
					break
				done += 1
				var label := "%d/%d  %s  %s  %d monstres" % [done, total, id, Quality.tier_name(t), n]
				_say(label)
				var row := await _measure_config(director, sm, n, label)
				row.merge({"map": id, "floor": int(entry.floor), "variant": String(entry.variant), "event": String(entry.event),
					"tier": Quality.tier_name(t), "tier_i": t, "n": n}, true)
				rows.append(row)
				row_done.emit(row)
				director.despawn_all()
	director.despawn_all()
	result = {
		"schema": 1, "date": Time.get_datetime_string_from_system(), "device": device_info(),
		"ambient_d": AMBIENT_D, "seconds": seconds, "aborted": aborted,
		"duration_s": (Time.get_ticks_msec() - t_start) / 1000.0, "rows": rows,
	}
	result["summary"] = summarize(rows)
	_write_files()
	# rendu de l'état d'avant
	TestMode.set_flag(&"god", bool(saved["god"]))
	TestMode.set_flag(&"spawns", bool(saved["spawns"]))
	TestMode.set_ambient_d(float(saved["ambient"]))
	TestMode.set_difficulty(float(saved["d"]))
	Quality.set_tier(int(saved["tier"]), false)
	Quality.auto = bool(saved["auto"])
	Quality.calibrated = bool(saved["calibrated"])
	Quality.persist = bool(saved["persist"])
	Quality.dynamic_degrade = bool(saved["dyn"])
	DisplayServer.window_set_vsync_mode(saved["vsync"])
	Engine.max_fps = int(saved["max_fps"])
	if restore_after and is_inside_tree():
		TestMaps.load_map(tree, String(saved["map"]))
		director.spawning_enabled = TestMode.spawns
		director.waves_enabled = TestMode.spawns
	_running = false
	if with_ui and is_inside_tree():
		_show_result()
	finished.emit(result)
	return result


func _wait_s(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0) and not aborted:
		_resume_pause_menu()
		await get_tree().process_frame


## resume_on_pause : relance « Reprendre » (compte à rebours compris) sur un menu pause ouvert.
func _resume_pause_menu() -> void:
	if not resume_on_pause or not get_tree().paused:
		return
	var pm := get_tree().get_first_node_in_group(&"pause_menu")
	if pm != null and bool(pm.get(&"is_open")) and not bool(pm.get(&"counting_down")) and pm.has_method(&"_on_resume"):
		print("MapPerfBench : menu pause ouvert pendant le banc (perte de focus ?) : reprise automatique")
		pm.call(&"_on_resume")


## Une configuration (carte, palier, N) : chauffe puis mesure. Aucune allocation dans la boucle de mesure.
func _measure_config(director: Director, sm: StageManager, n: int, label: String) -> Dictionary:
	var tree := get_tree()
	var player: Node2D = null
	if not Players.all().is_empty():
		player = Players.all()[0] as Node2D
	if player != null and sm.map != null:
		player.global_position = sm.map.to_global(sm.map.get_player_start())
	director.despawn_all()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(warmup_s * 1000.0) and not aborted:
		_resume_pause_menu()
		_top_up(director, player, n, 400)
		await tree.process_frame
	var vp := get_viewport().get_viewport_rid()
	var acc := {"gpu": 0.0, "cpu": 0.0, "draw": 0.0, "obj": 0.0, "enemies": 0.0}
	var draw_max := 0.0
	var frames := 0
	var t_end := Time.get_ticks_usec() + int(seconds * 1.0e6)
	var last := Time.get_ticks_usec()
	var shown := 0
	while Time.get_ticks_usec() < t_end and frames < MAX_FRAMES and not aborted:
		if tree.paused: # panneau ou menu ouvert pendant le banc : images non comptées, fenêtre prolongée
			_resume_pause_menu()
			await tree.process_frame
			var now_p := Time.get_ticks_usec()
			t_end += now_p - last
			last = now_p
			continue
		_top_up(director, player, n, TOPUP_PER_FRAME)
		await tree.process_frame
		var now := Time.get_ticks_usec()
		_frame_ms[frames] = (now - last) / 1000.0
		last = now
		# moniteurs Godot : pic de la seconde écoulée (Main::iteration), pas la valeur de l'image
		_proc_ms[frames] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_phys_ms[frames] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_dir_ms[frames] = director.stat_tick_usec / 1000.0 # coût physique du Director (monstres), image par image
		acc["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		acc["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		var dc := float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		acc["draw"] += dc
		draw_max = maxf(draw_max, dc)
		acc["obj"] += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		acc["enemies"] += director.active_count()
		frames += 1
		var left := int((t_end - now) / 1000000)
		if left != shown and _ui_label != null:
			shown = left
			_ui_label.text = "Banc de perf : %s  (%d s)" % [label, left]
	var row := {"frames": frames}
	if frames == 0:
		return row
	var fr := frames as float
	var wall_s := 0.0
	for i in frames:
		wall_s += _frame_ms[i]
	row["fps"] = snappedf(fr / maxf(wall_s / 1000.0, 1e-6), 0.1)
	row.merge(_stats("frame", _frame_ms, frames))
	row.merge(_stats("process_peak", _proc_ms, frames))
	row.merge(_stats("physics_peak", _phys_ms, frames))
	row.merge(_stats("director", _dir_ms, frames))
	row["gpu_ms"] = snappedf(acc["gpu"] / fr, 0.001)
	row["cpu_render_ms"] = snappedf(acc["cpu"] / fr, 0.001)
	row["draw_calls"] = snappedf(acc["draw"] / fr, 0.1)
	row["draw_calls_max"] = draw_max
	row["objects"] = snappedf(acc["obj"] / fr, 0.1)
	row["enemies"] = snappedf(acc["enemies"] / fr, 0.1)
	row.merge(scene_counts(tree), true)
	return row


## Moyenne, p95, p99 et maximum des `n` premières valeurs (copie triée hors boucle de mesure).
static func _stats(prefix: String, buf: PackedFloat32Array, n: int) -> Dictionary:
	var s := buf.slice(0, n)
	s.sort()
	var sum := 0.0
	for v in s:
		sum += v
	return {
		prefix + "_avg_ms": snappedf(sum / n, 0.001),
		prefix + "_p95_ms": snappedf(s[mini(int(ceil(0.95 * n)) - 1, n - 1)], 0.001),
		prefix + "_p99_ms": snappedf(s[mini(int(ceil(0.99 * n)) - 1, n - 1)], 0.001),
		prefix + "_max_ms": snappedf(s[n - 1], 0.001),
	}


## Maintient `n` monstres autour du joueur (au plus `budget` apparitions par appel).
func _top_up(director: Director, player: Node2D, n: int, budget: int) -> void:
	if player == null:
		return
	var need := mini(n - director.active_count(), budget)
	var tries := 0
	while need > 0 and tries < budget * 4:
		tries += 1
		var pos := player.global_position + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(260.0, 1100.0)
		if director.nav != null and not director.nav.is_spawnable(pos):
			continue
		var r := _rng.randf()
		if director.spawn_enemy(3 if r < 0.1 else (2 if r < 0.32 else 1), pos, _rng.randf() < 0.12) == null:
			break
		need -= 1


## Comptes de la scène (hors boucle de mesure) : nœuds, lumières visibles / ombrées, occluders, eau, événement.
static func scene_counts(tree: SceneTree) -> Dictionary:
	var lights := 0
	var shadowed := 0
	var occ := 0
	var stack: Array[Node] = [tree.root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is Light2D:
			var li := nd as Light2D
			if li.enabled and li.is_visible_in_tree():
				lights += 1
				if li.shadow_enabled:
					shadowed += 1
		elif nd is LightOccluder2D:
			if (nd as CanvasItem).is_visible_in_tree():
				occ += 1
		stack.append_array(nd.get_children())
	var out := {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "lights": lights, "shadowed": shadowed,
		"occluders": occ, "water_shallow": 0, "water_deep": 0, "events_active": 0, "rig_lights": 0,
		"vram_mib": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
	}
	var amb := tree.get_first_node_in_group(&"ambiance_manager") as AmbianceManager
	if amb != null:
		if amb.water != null:
			out["water_shallow"] = amb.water.shallow_rects
			out["water_deep"] = amb.water.deep_rects
		if amb.events != null:
			out["events_active"] = amb.events.active_count()
		if amb.rig != null:
			out["rig_lights"] = amb.rig.active_light_count()
	# surface d'eau de la grille (cases « , » et « ~ ») : chaque couche est UN quad plein carte découpé en shader,
	# le coût suit donc la surface couverte (remplissage), pas le nombre de quads
	var sm := tree.get_first_node_in_group(&"stage_manager") as StageManager
	if sm != null and sm.map != null:
		var g := AmbianceWater.grid_of(sm.map)
		var sh := 0
		var dp := 0
		for row in g.get("grid", PackedStringArray()):
			sh += (row as String).count(",")
			dp += (row as String).count("~")
		out["water_cells_shallow"] = sh
		out["water_cells_deep"] = dp
	return out


static func device_info() -> Dictionary:
	var ws := DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i.ZERO
	return {
		"os": OS.get_name(), "model": OS.get_model_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(), "renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"godot": Engine.get_version_info().get("string", ""), "window": [ws.x, ws.y], "display": DisplayServer.get_name(),
		"cpu": OS.get_processor_name(), "cores": OS.get_processor_count(),
	}


## Résumé : par carte et palier, la charge la plus lourde (p95 contre le seuil du palier) ; écarts B / A par étage.
static func summarize(rows: Array) -> Dictionary:
	var verdicts: Array = []
	var by_key := {}
	for r in rows:
		var rd := r as Dictionary
		if int(rd.get("frames", 0)) == 0:
			continue
		by_key["%s|%s|%d" % [rd.map, rd.tier, rd.n]] = rd
		var lim: float = P95_LIMIT_MS.get(int(rd.tier_i), 16.7)
		if int(rd.n) == _max_n(rows):
			verdicts.append({"map": rd.map, "tier": rd.tier, "n": rd.n, "p95_ms": rd.frame_p95_ms, "limit_ms": lim,
				"ok": float(rd.frame_p95_ms) <= lim})
	var ab: Array = []
	for r in rows:
		var rd := r as Dictionary
		if String(rd.get("variant", "")) != "B" or int(rd.get("frames", 0)) == 0:
			continue
		var a_id := ""
		for r2 in rows:
			if int((r2 as Dictionary).get("floor", 0)) == int(rd.floor) and String((r2 as Dictionary).get("variant", "")) == "A":
				a_id = String((r2 as Dictionary).map)
				break
		var ra: Dictionary = by_key.get("%s|%s|%d" % [a_id, rd.tier, rd.n], {})
		if ra.is_empty():
			continue
		ab.append({"floor": rd.floor, "b": rd.map, "a": a_id, "tier": rd.tier, "n": rd.n,
			"frame_avg_b_over_a": snappedf(float(rd.frame_avg_ms) / maxf(float(ra.frame_avg_ms), 0.001), 0.01),
			"p95_b_ms": rd.frame_p95_ms, "p95_a_ms": ra.frame_p95_ms,
			"occluders_b": rd.occluders, "occluders_a": ra.occluders, "deep_b": rd.water_deep, "deep_a": ra.water_deep,
			"draw_b": rd.draw_calls, "draw_a": ra.draw_calls,
			"deep_cells_b": int(rd.get("water_cells_deep", 0)), "deep_cells_a": int(ra.get("water_cells_deep", 0)),
			"flags": _ab_flags(rd, ra)})
	# alertes globales : occluders au-dessus du plafond, B plus coûteuses que leur A
	var alerts: Array = []
	for r in rows:
		var rd := r as Dictionary
		if int(rd.get("frames", 0)) > 0 and int(rd.get("occluders", 0)) > OCCLUDER_LIMIT and int(rd.n) == _max_n(rows):
			alerts.append("%s %s : %d occluders (plafond %d)" % [rd.map, rd.tier, rd.occluders, OCCLUDER_LIMIT])
	for x in ab:
		if not (x.flags as Array).is_empty() and int(x.n) == _max_n(rows):
			alerts.append("étage %d %s %s N=%d : %s" % [x.floor, x.b, x.tier, x.n, ", ".join(PackedStringArray(x.flags))])
	return {"verdicts": verdicts, "b_vs_a": ab, "alerts": alerts}


## Écarts notables d'une B contre la A du même étage (même palier, même N).
static func _ab_flags(b: Dictionary, a: Dictionary) -> Array:
	var f: Array = []
	if float(b.frame_avg_ms) > float(a.frame_avg_ms) * (1.0 + B_SLOWER_TOL):
		f.append("temps moyen +%d %%" % roundi((float(b.frame_avg_ms) / maxf(float(a.frame_avg_ms), 0.001) - 1.0) * 100.0))
	if float(b.frame_p95_ms) > float(a.frame_p95_ms) * (1.0 + B_SLOWER_TOL):
		f.append("p95 %.1f contre %.1f ms" % [b.frame_p95_ms, a.frame_p95_ms])
	if int(b.get("water_cells_deep", 0)) > int(a.get("water_cells_deep", 0)):
		f.append("eau profonde %d cases contre %d" % [b.get("water_cells_deep", 0), a.get("water_cells_deep", 0)])
	if int(b.get("occluders", 0)) > OCCLUDER_LIMIT:
		f.append("occluders %d > %d" % [b.occluders, OCCLUDER_LIMIT])
	return f


static func _max_n(rows: Array) -> int:
	var m := 0
	for r in rows:
		m = maxi(m, int((r as Dictionary).get("n", 0)))
	return m


## Tableau texte (une ligne par configuration) + résumé lisible.
static func to_text(res: Dictionary) -> String:
	var lines: Array[String] = []
	var dev: Dictionary = res.get("device", {})
	lines.append("Banc de perf Rainfall, %s, %s %s, GPU %s, fenêtre %s, D d'ambiance %s, %s s par mesure%s" % [
		res.get("date", ""), dev.get("os", ""), dev.get("model", ""), dev.get("gpu", ""), str(dev.get("window", "")),
		str(res.get("ambient_d", "")).replace(".", ","), str(res.get("seconds", "")), " (ARRÊTÉ)" if res.get("aborted", false) else ""])
	lines.append("")
	lines.append("%-26s %-5s %4s | %6s %6s %6s %6s | %6s %6s | %6s %6s | %6s %5s %6s | %5s %3s %3s %3s | %3s %3s %4s %4s" % [
		"carte", "qual", "N", "i/s", "moy", "p95", "p99", "proc^", "phys^", "dir", "p95", "gpu", "draw", "objets", "noeud", "lum", "omb", "occ", "eau", "~", "c,", "c~"])
	for r in res.get("rows", []):
		var rd := r as Dictionary
		if int(rd.get("frames", 0)) == 0:
			continue
		lines.append("%-26s %-5s %4d | %6.0f %6.2f %6.2f %6.2f | %6.2f %6.2f | %6.2f %6.2f | %6.2f %5.0f %6.0f | %5d %3d %3d %3d | %3d %3d %4d %4d" % [
			rd.map, rd.tier, rd.n, rd.fps, rd.frame_avg_ms, rd.frame_p95_ms, rd.frame_p99_ms, rd.process_peak_avg_ms, rd.physics_peak_avg_ms,
			rd.director_avg_ms, rd.director_p95_ms, rd.gpu_ms, rd.draw_calls, rd.objects, rd.nodes, rd.lights, rd.shadowed, rd.occluders,
			rd.water_shallow, rd.water_deep, int(rd.get("water_cells_shallow", 0)), int(rd.get("water_cells_deep", 0))])
	lines.append("")
	lines.append("Temps d'image en ms (moy, p95, p99) ; proc^ / phys^ = pic par seconde de _process / physique (moniteurs Godot), dir = physique du Director (monstres) par image ; gpu = rendu GPU mesuré ; lum / omb = lumières visibles / ombrées ; occ = occluders ; eau / ~ = calques d'eau peu profonde / profonde (un quad plein carte chacun) ; c, / c~ = cases d'eau de la grille (surface couverte).")
	lines.append("Seuils p95 : Haut <= 16,7 ms (60 i/s), Moyen <= 22,3 ms (45 i/s), Bas <= 33,4 ms (30 i/s).")
	var sm: Dictionary = res.get("summary", {})
	lines.append("")
	lines.append("RÉSUMÉ (charge maximale) :")
	for v in sm.get("verdicts", []):
		lines.append("  %s %-26s %-5s N=%d : p95 %.2f ms (seuil %.1f)" % ["OK  " if v.ok else "LENT", v.map, v.tier, v.n, v.p95_ms, v.limit_ms])
	if not (sm.get("b_vs_a", []) as Array).is_empty():
		lines.append("")
		lines.append("VARIANTES B CONTRE A (même étage, même palier, même N) :")
		for x in sm.get("b_vs_a", []):
			lines.append("  étage %d %-5s N=%3d : temps moyen B/A x%.2f (p95 %.2f contre %.2f ms), occluders %d contre %d, eau profonde %d contre %d cases, draw %.0f contre %.0f" % [
				x.floor, x.tier, x.n, x.frame_avg_b_over_a, x.p95_b_ms, x.p95_a_ms, x.occluders_b, x.occluders_a, x.deep_cells_b, x.deep_cells_a, x.draw_b, x.draw_a])
	lines.append("")
	lines.append("ALERTES (charge maximale) : %d" % (sm.get("alerts", []) as Array).size())
	for al in sm.get("alerts", []):
		lines.append("  " + String(al))
	return "\n".join(lines) + "\n"


## Résumé court pour l'écran du téléphone.
static func short_text(res: Dictionary) -> String:
	var lines: Array[String] = []
	var bad := 0
	for v in res.get("summary", {}).get("verdicts", []):
		if not v.ok:
			bad += 1
	var dev: Dictionary = res.get("device", {})
	lines.append("%s : %d configurations en %.0f s%s" % [dev.get("model", dev.get("os", "")), (res.get("rows", []) as Array).size(), float(res.get("duration_s", 0.0)), " (arrêté)" if res.get("aborted", false) else ""])
	lines.append("%d au-dessus du seuil p95 (charge maximale)." % bad)
	for al in res.get("summary", {}).get("alerts", []):
		lines.append("ALERTE " + String(al))
	for v in res.get("summary", {}).get("verdicts", []):
		lines.append("%s %s %s : p95 %.1f ms / %.1f" % ["OK" if v.ok else "LENT", v.map, v.tier, v.p95_ms, v.limit_ms])
	return "\n".join(lines)


func _write_files() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var stamp := Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "-")
	json_path = OUT_DIR.path_join("bench_%s.json" % stamp)
	txt_path = OUT_DIR.path_join("bench_%s.txt" % stamp)
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(result, " "))
		f.close()
	var t := FileAccess.open(txt_path, FileAccess.WRITE)
	if t != null:
		t.store_string(to_text(result))
		t.close()
	result["json_path"] = ProjectSettings.globalize_path(json_path)
	result["txt_path"] = ProjectSettings.globalize_path(txt_path)


## Export volontaire : zip des fichiers du banc (dernier résultat ou tous), présenté comme les journaux de run
## (feuille de partage Android, explorateur Windows, app Fichiers iOS). Retourne {ok, abs_path, where}.
static func export_results(only: PackedStringArray = PackedStringArray()) -> Dictionary:
	var files := only
	if files.is_empty() and DirAccess.dir_exists_absolute(OUT_DIR):
		for fn in DirAccess.get_files_at(OUT_DIR):
			if fn.begins_with("bench_") and (fn.ends_with(".json") or fn.ends_with(".txt")):
				files.append(OUT_DIR.path_join(fn))
	if files.is_empty():
		return {"ok": false, "where": "Aucun résultat de banc pour l'instant."}
	var out_dir := "user://exports"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var stamp := Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "-")
	var path := out_dir.path_join("rainfall_banc_perf_%s.zip" % stamp)
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		return {"ok": false, "where": "Impossible de créer le fichier d'export."}
	for p in files:
		zip.start_file(p.get_file())
		zip.write_file(FileAccess.get_file_as_bytes(p))
		zip.close_file()
	zip.close()
	var abs_path := ProjectSettings.globalize_path(path)
	var res := {"ok": true, "abs_path": abs_path, "where": "Fichier créé :\n%s" % RunLogExport.breakable(abs_path)}
	match OS.get_name():
		"Android":
			if RunLogExport._android_share(abs_path):
				res["where"] = "Choisis où envoyer le fichier dans la fenêtre de partage."
			else:
				var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
				if docs != "":
					var dst := docs.path_join("Rainfall")
					DirAccess.make_dir_recursive_absolute(dst)
					dst = dst.path_join(abs_path.get_file())
					if DirAccess.copy_absolute(abs_path, dst) == OK:
						res["abs_path"] = dst
						res["where"] = "Fichier copié dans Documents/Rainfall :\n%s" % RunLogExport.breakable(dst)
		"iOS":
			pass
		_:
			if DisplayServer.get_name() != "headless":
				OS.shell_show_in_file_manager(abs_path, true)
	return res


# --- Interface (bandeau pendant la mesure, fenêtre de résultat) ---------------------------

func _say(text: String) -> void:
	progress.emit(text)
	print("BANC | ", text)
	if _ui_label != null:
		_ui_label.text = "Banc de perf : " + text


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 120
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.theme()
	_ui.add_child(root)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 24.0
	bar.offset_top = 16.0
	bar.offset_right = -24.0
	root.add_child(bar)
	_ui_label = Label.new()
	_ui_label.add_theme_font_size_override(&"font_size", 28)
	_ui_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_ui_label.add_theme_constant_override(&"outline_size", 8)
	_ui_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_label.text = "Banc de perf : préparation…"
	bar.add_child(_ui_label)
	var stop := Button.new()
	stop.text = "Arrêter le banc"
	stop.custom_minimum_size = Vector2(0, 76)
	stop.add_theme_font_size_override(&"font_size", 26)
	stop.pressed.connect(func() -> void:
		aborted = true
		_ui_label.text = "Banc de perf : arrêt après la mesure en cours…")
	bar.add_child(stop)


func _show_result() -> void:
	if _ui == null:
		_build_ui()
	_ui_label.get_parent().visible = false
	var root := _ui.get_child(0) as Control
	_ui_panel = PanelContainer.new()
	_ui_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_panel.offset_left = 120
	_ui_panel.offset_right = -120
	_ui_panel.offset_top = 60
	_ui_panel.offset_bottom = -60
	root.add_child(_ui_panel)
	var v := VBoxContainer.new()
	_ui_panel.add_child(v)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_ui_text = Label.new()
	_ui_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_text.add_theme_font_size_override(&"font_size", 24)
	_ui_text.text = short_text(result) + "\n\nFichiers :\n" + RunLogExport.breakable(String(result.get("txt_path", ""))) + "\n" + RunLogExport.breakable(String(result.get("json_path", "")))
	scroll.add_child(_ui_text)
	var row := HBoxContainer.new()
	v.add_child(row)
	var ex := Button.new()
	ex.text = "Exporter le résultat"
	ex.custom_minimum_size = Vector2(0, 76)
	ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ex.pressed.connect(func() -> void:
		var r := export_results(PackedStringArray([json_path, txt_path]))
		_ui_text.text += "\n\n" + String(r.get("where", "")))
	row.add_child(ex)
	var close := Button.new()
	close.text = "Fermer"
	close.custom_minimum_size = Vector2(0, 76)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(queue_free)
	row.add_child(close)
	ex.grab_focus.call_deferred()
