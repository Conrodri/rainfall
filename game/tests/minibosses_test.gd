extends Node
## Mini-boss pilotés par données : MiniBossBrain + MiniPatterns (data/minibosses.json).
## godot --headless --path game res://tests/minibosses_test.tscn  -> RESULT: OK
## Options (après --) : only=<biome|id>[,<id>…]  speed=<Engine.time_scale> (défaut 2)  map=<id>
##   capture shots=<dossier absolu> (sans --headless, temps réel) : image à 70 % de chaque télégraphe.
## Vérifie :
## 1. données : chaque mini des étages 1-4 de data/floors.json a une fiche, ≥ 1 auto + ≥ 2 sorts, types connus,
##    sorts télégraphiés ≥ 0,8 s (Balance), phase 2 qui change quelque chose, identité distincte (signature),
##    chemin d'art enregistré (fauna.json boss_sprites) ;
## 2. pour chaque mini : apparition (méta next_mini_id du petit pilier) -> MiniBossBrain, corps de repli si
##    l'art manque, lumières (principale + liseré) ; chaque motif forcé touche le joueur placé dans la zone,
##    dégâts dans la même frame que l'impact, impact armé calé sur la frame d'impact de l'anim (décalage
##    < 0,05 s) ; projectiles tirés à l'impact puis reçus ; invocations nées ;
## 3. phase 2 sous 50 % : transition (figé), lumière plus forte, sort d'entrée, motifs de phase 2 / surcharges p2 ;
## 4. mort : télégraphes, zones, nœuds et lumières libérés, visuel rendu intact (pool), cerveau détaché.
## Sauvegarde de test seulement (jamais user://run_save.json).

const SAVE := "user://test_minibosses.json"
const MAP_BY_BIOME := {"terrasses": "terrasses_noyees", "foret": "foret_brume", "cite": "cite_rouille", "cryptes": "cryptes_noyees"}
const TYPES := ["cone", "line", "charge", "projectile_fan", "ring", "circles", "summon", "leap", "beam", "burrow"]
const HURT_TYPES := ["cone", "line", "charge", "ring", "circles", "leap", "beam", "burrow"]
const DIST_U := 3.0
const PATTERN_TIMEOUT := 9.0
const PROJ_WAIT := 2.5
const U := 64.0
const FREE_AI_S := 3.5

var _main: Node
var _fails := 0
var _step := -1
var _t := 0.0
var _speed := 2.0
var _only: Array = []
var _queue: Array = [] ## [id, floor]
var _id: StringName = &""
var _boss: Enemy = null
var _b: MiniBossBrain = null
var _anchor := Vector2.ZERO
var _plist: Array = [] ## motifs à forcer dans la phase courante
var _pi := -1
var _pid: StringName = &""
var _ev0 := 0
var _hit_frames: Array[int] = []
var _proj_hit := false
var _sum0 := 0
var _after := 0.0
var _seen_active := false
var _shots_dir := ""
var _shot_done := {}
var _stats := {"minis": 0, "patterns": 0}


func _ready() -> void:
	var map := "terrasses_noyees"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			_only = a.substr(5).split(",")
		elif a.begins_with("speed="):
			_speed = float(a.substr(6))
		elif a.begins_with("shots="):
			_shots_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(_shots_dir)
		elif a.begins_with("map="):
			map = a.substr(4)
	if _shots_dir != "":
		_speed = 1.0
	if _only.size() == 1 and MAP_BY_BIOME.has(_only[0]):
		map = MAP_BY_BIOME[_only[0]]
	var path := "res://scenes/stage/maps/%s.tscn" % map
	if not ResourceLoader.exists(path):
		path = "res://scenes/stage/maps/terrasses_noyees.tscn"
	print("  carte : ", path)
	MiniBossBrain.reload()
	_check_data()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(path))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 77)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hit_frames.append(Engine.get_physics_frames()))
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


# --- 1. Données ------------------------------------------------------------------------------------

func _check_data() -> void:
	var floors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/floors.json"))
	var sigs := {}
	for f: Dictionary in floors["floors"]:
		var fl := int(f["floor"])
		if fl > 4:
			continue
		for m in f["minis"]:
			var id := StringName(m)
			if not _only.is_empty() and not (String(f["biome"]) in _only or String(id) in _only):
				continue
			_queue.append([id, fl])
			_check("%s : fiche data/minibosses.json" % id, MiniBossBrain.has_config(id))
			if not MiniBossBrain.has_config(id):
				continue
			var c := MiniBossBrain.config(id)
			var autos := 0
			var spells := 0
			var sig: Array = []
			var p2 := false
			var ok_types := true
			var ok_wind := true
			for p: Dictionary in c.get("patterns", []):
				if not String(p.get("type", "")) in TYPES:
					ok_types = false
				if bool(p.get("auto", false)):
					autos += 1
				elif int(p.get("phase", 1)) == 1:
					spells += 1
				if not bool(p.get("auto", false)) and Balance.mini_windup(float(p.get("windup", 0.0)), false) < 0.8:
					ok_wind = false
				if int(p.get("phase", 1)) == 2 or p.has("p2"):
					p2 = true
				sig.append("%s/%s/%.2f" % [p.get("type"), p.get("anim"), float(p.get("coef", 0.0))])
			var ph2: Dictionary = c.get("phase2", {})
			p2 = p2 or float(ph2.get("speed_mult", 1.0)) > 1.0 or String(ph2.get("on_enter", "")) != ""
			sig.sort()
			var key := ",".join(sig)
			_check("%s : 1 auto + 2 sorts au moins" % id, autos >= 1 and spells >= 2, "autos=%d sorts=%d" % [autos, spells])
			_check("%s : types de motifs connus" % id, ok_types)
			_check("%s : sorts télégraphiés >= 0,8 s" % id, ok_wind)
			_check("%s : phase 2 qui change le combat" % id, p2)
			_check("%s : identité distincte (signature de motifs)" % id, not sigs.has(key), str(sigs.get(key, "")))
			sigs[key] = id
			_check("%s : chemin d'art enregistré (fauna.json boss_sprites)" % id, EnemyVisual.boss_path(id) != "")
			_check("%s : lumières (couleur ou preset + liseré)" % id, (c.get("light", {}) as Dictionary).has("rim"))


# --- 2-4. Combats ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _step < 0 or _step == 99:
		return
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	_t += delta
	var p := _player()
	if p != null:
		p.hp = p.max_hp
		p.set(&"_invuln", 0.0)
	match _step:
		0: # mise en place : pas de foule
			_director().spawning_enabled = false
			if _t > 1.2:
				Engine.time_scale = _speed
				_clear_enemies()
				_anchor = p.global_position
				_next_mini()
		1: # motifs
			_run_pattern(delta)
		2: # passage en phase 2
			p.global_position = _anchor
			if _t > 0.12 and not _seen_active:
				_seen_active = true
				_check("%s : phase 2 sous 50 %% (transition, figé)" % _id, _b.phase == 2 and _b.state == MiniBossBrain.S.STAGGER,
					"phase=%d état=%d" % [_b.phase, _b.state])
				var en: Array = (_b.cfg.get("light", {}) as Dictionary).get("energy", [1.3, 1.7])
				_check("%s : lumière de phase 2" % _id, absf(_b.light_abs_energy() - float(en[1])) < 0.01, "%.2f" % _b.light_abs_energy())
				var has_ev := false
				for ev in _b.events:
					has_ev = has_ev or ev["kind"] == &"phase"
				_check("%s : événement de phase" % _id, has_ev)
			if _t > 0.3 and not _b.busy():
				var oe := StringName((_b.cfg.get("phase2", {}) as Dictionary).get("on_enter", ""))
				if oe != &"":
					var fired := false
					for ev in _b.events:
						fired = fired or (ev["pattern"] == oe and ev["phase"] == 2)
					_check("%s : sort d'entrée de phase 2 (%s)" % [_id, oe], fired)
				_plist = []
				for pp: Dictionary in _b.patterns():
					if int(pp.get("phase", 1)) == 2 or pp.has("p2"):
						_plist.append(StringName(pp["id"]))
				_pi = -1
				_step = 1
				_next_pattern()
		4: # IA libre
			p.global_position = _anchor
			if not _b.cur.is_empty():
				_seen_active = true
			if _t > FREE_AI_S and not _b.busy():
				_check("%s : IA libre : attaque seule" % _id, _seen_active and not _b.events.is_empty(), "évts=%d" % _b.events.size())
				_start_forced()
		3: # mort et nettoyage
			if _t > 0.15:
				_check("%s : cerveau détaché" % _id, _boss.brain == null)
				_check("%s : nœuds libérés (télégraphes, zones, œufs)" % _id, _b.live_node_count() == 0 and _b.zone_count() == 0 and _b.egg_count() == 0,
					"nœuds=%d zones=%d" % [_b.live_node_count(), _b.zone_count()])
				_check("%s : télégraphe masqué" % _id, not _boss.telegraph.visible)
				var v := _boss.visual
				_check("%s : visuel rendu intact (pool)" % _id, v.modulate == Color.WHITE and v.scale == Vector2.ONE and v.visible)
				_clear_enemies()
				_next_mini()


func _next_mini() -> void:
	if _queue.is_empty():
		_finish()
		return
	var q: Array = _queue.pop_front()
	_id = q[0]
	RunState.stage = int(q[1])
	var d := _director()
	var p := _player()
	p.global_position = _anchor
	var pos := _anchor + Vector2(DIST_U * U, 0.0)
	if d.nav != null:
		pos = d.nav.resolve(pos, 70.0)
	d.set_meta(&"next_mini_id", _id)
	_boss = d.spawn_boss(&"mini", pos) as Enemy
	d.remove_meta(&"next_mini_id")
	_b = _boss.brain as MiniBossBrain if _boss != null and _boss.brain is MiniBossBrain else null
	_stats["minis"] += 1
	print("— %s (étage %d)" % [_id, q[1]])
	_check("%s : MiniBossBrain branché" % _id, _b != null and _b.mini_id == _id)
	if _b == null:
		_next_mini.call_deferred()
		return
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_b.ai_enabled = false
	if not EnemyVisual.boss_available(_id):
		var want := StringName((_b.cfg.get("fallback", {}) as Dictionary).get("sprite", ""))
		_check("%s : art absent -> corps de repli %s" % [_id, want], _b.fallback_sprite != &"" and
			(not EnemyVisual.boss_available(want) or _boss.visual.body_sprite() != null), str(_b.fallback_sprite))
	else:
		_check("%s : art livré (sans repli)" % _id, _b.fallback_sprite == &"" and _boss.visual.body_sprite() != null)
	_check("%s : liseré de lumière" % _id, _b.get(&"_rim") != null)
	_check_passives()
	_b.ai_enabled = true # quelques secondes d'IA libre : le mini choisit et lance ses coups seul
	_step = 4
	_t = 0.0
	_seen_active = false


func _start_forced() -> void:
	_b.ai_enabled = false
	_plist = []
	for pp: Dictionary in _b.patterns():
		if int(pp.get("phase", 1)) == 1:
			_plist.append(StringName(pp["id"]))
	_pi = -1
	_step = 1
	_next_pattern()


## Gardes : réduction de face (et pas de dos), peau de pierre.
func _check_passives() -> void:
	for ps: Dictionary in _b.get(&"_passives"):
		match String(ps.get("type", "")):
			"front_guard":
				_boss._facing = 0.0
				_b.ppos = _boss.position + Vector2(2.0 * U, 0.0)
				var front := _b.damage_taken_mult()
				_b.ppos = _boss.position - Vector2(2.0 * U, 0.0)
				var back := _b.damage_taken_mult()
				_check("%s : garde de face (%.2f) / dos (%.2f)" % [_id, front, back], front < 0.99 and back > 0.99)
			"flat_guard":
				_check("%s : peau de pierre" % _id, _b.damage_taken_mult() < 0.99)


func _next_pattern() -> void:
	_pi += 1
	if _pi >= _plist.size():
		if _b.phase == 1:
			_boss.hp = _boss.max_hp * 0.45
			_boss.take_damage(1.0)
			_step = 2
			_t = 0.0
			_seen_active = false
			return
		_step = 3
		_t = 0.0
		_boss.take_damage(_boss.hp * 10.0 + 10.0) # mort : retour au pool
		return
	_pid = _plist[_pi]
	# invocations du motif précédent (raise_dead…) retirées : un de leurs coups donnait au joueur ses frames
	# d'invulnérabilité juste avant l'impact du motif suivant (coup du boss absorbé, test instable)
	_clear_enemies()
	_ev0 = _b.events.size()
	_hit_frames.clear()
	_proj_hit = false
	_sum0 = _b.summoned_total
	_after = 0.0
	_seen_active = false
	_t = 0.0
	_player().global_position = _anchor
	_b.force(_pid)
	_stats["patterns"] += 1


func _run_pattern(delta: float) -> void:
	var p := _player()
	var running := not _b.cur.is_empty() and StringName(_b.cur.get("id", "")) == _pid
	if running:
		_seen_active = true
		if _b.state == MiniBossBrain.S.WIND:
			p.global_position = _b.harm_point() # le joueur reste dans la zone visée
			_shoot_key()
	var typ := String(_b.pattern(_pid).get("type", ""))
	if _b.phase >= 2:
		typ = String(_b._merged(_b.pattern(_pid)).get("type", typ))
	var done := _seen_active and not running and not _b.busy()
	if done and typ in ["projectile_fan", "summon"]:
		_after += delta
		var wait_ok := (typ == "projectile_fan" and not _hit_frames.is_empty()) or (typ == "summon" and _b.summoned_total > _sum0)
		if not wait_ok and _after < PROJ_WAIT:
			return
	if not done and _t < PATTERN_TIMEOUT:
		return
	_shoot_after()
	_verify(typ, done)
	_next_pattern()


func _verify(typ: String, done: bool) -> void:
	var label := "%s.%s (p%d, %s)" % [_id, _pid, _b.phase, typ]
	if not done:
		_check(label + " : terminé", false, "délai dépassé")
		return
	var evs: Array = _b.events.slice(_ev0).filter(func(ev: Dictionary) -> bool: return ev["pattern"] == _pid)
	_check(label + " : impact journalisé", not evs.is_empty())
	var lag_ok := true
	var lags := []
	for ev: Dictionary in evs:
		if ev["armed"] and _boss.visual.body_sprite() != null:
			lags.append("%.3f" % float(ev["lag"]))
			if float(ev["lag"]) < -0.001 or float(ev["lag"]) > 0.05:
				lag_ok = false
	_check(label + " : impact calé sur la frame d'impact de l'anim", lag_ok, str(lags))
	if typ in HURT_TYPES:
		var same := false
		for ev: Dictionary in evs:
			if ev["hit"] and int(ev["frame"]) in _hit_frames:
				same = true
		_check(label + " : touche le joueur à la frame d'impact", same, "évts=%s coups=%s" % [_summary(evs), str(_hit_frames)])
	elif typ == "projectile_fan":
		var spawned := 0
		for ev: Dictionary in evs:
			spawned += int(ev.get("spawned", 0))
		_check(label + " : projectiles tirés à l'impact puis reçus", spawned > 0 and not _hit_frames.is_empty(),
			"tirés=%d coups=%d" % [spawned, _hit_frames.size()])
	elif typ == "summon":
		_check(label + " : invocations nées", _b.summoned_total > _sum0, "nées=%d" % (_b.summoned_total - _sum0))


func _summary(evs: Array) -> String:
	var s := []
	for ev: Dictionary in evs:
		s.append("%s:%s@%d" % [ev["kind"], "x" if ev["hit"] else "-", ev["frame"]])
	return ",".join(s)


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group(&"enemies").duplicate():
		if e is Enemy and not e.is_boss:
			_director().release_enemy(e)


func _shoot_key() -> void:
	if _shots_dir == "" or _b.t < float(_b.cur.get("_wind", 1.0)) * 0.7:
		return
	var key := "%s_p%d_%s" % [_id, _b.phase, _pid]
	if _shot_done.has(key):
		return
	_shot_done[key] = true
	var img := get_viewport().get_texture().get_image()
	if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
	img.save_png("%s/%s.png" % [_shots_dir, key])


## Capture (shots=) juste après le motif : traces au sol, obstacles, projectiles spéciaux encore visibles.
func _shoot_after() -> void:
	if _shots_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
	img.save_png("%s/%s_p%d_%s_after.png" % [_shots_dir, _id, _b.phase, _pid])


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _finish() -> void:
	_step = 99
	Engine.time_scale = 1.0
	print("  %d mini-boss, %d motifs forcés" % [_stats["minis"], _stats["patterns"]])
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
