extends Node
## Boss final : le Semeur de pluie (RainSowerBrain) sur la carte la_source (repli : cite_rouille).
## godot --headless --path game res://tests/rain_sower_boss_test.tscn  -> RESULT: OK
## Capture : sans --headless, images clés en temps réel : `--resolution 1280x720 -- capture shots=<dossier absolu>`.
## Vérifie :
## 1. IA branchée, chemin du sprite enregistré (fauna.json), silhouette provisoire ou anims directionnelles,
##    dégâts de base ×32/28, PV ×2 (paratonnerre-mère), rayon 1,8 u, centre de l'arène = paratonnerre ;
## 2. entrée : le Semeur descend dans la colonne (≥ 2 s, aucun coup) ;
## 3. phase 1 : 8 directions : fouet / averse / vague face au joueur (≥ 6 octants), impacts calés ; averse
##    (cercles disjoints, un sur le joueur) ; le front de la vague touche dans le couloir ;
## 4. phase 2 sous 70 % : la crue monte (6 u), noyade dans le bassin, brume au bord (ralenti), débordement
##    télégraphié qui touche sur l'anneau, vague en éventail de 3 couloirs ;
## 5. phase 3 sous 35 % : glisse jusqu'au paratonnerre et s'y ancre (immobile, eau retirée, colonne), croix
##    de 4 lignes qui tourne et brûle, foudre toutes les 4 s, tourbillon au contact, Rafale (lignes fantômes
##    puis saut de 45°), +20 % de dégâts reçus ;
## 6. mort : mise en scène, nœuds libérés, paratonnerre terminé.
## Sauvegarde de test seulement (jamais user://run_save.json).

const MAP_SOURCE := "res://scenes/stage/maps/la_source.tscn"
const MAP_FALLBACK := "res://scenes/stage/maps/cite_rouille.tscn"
const SAVE := "user://test_rain_sower_boss.json"
const DIST_PX := 170.0
const SLOT_S := 3.0
const P2_S := 16.0
const P3_S := 16.0
const U := 64.0

var _capture := false
var _via_plan := false
var _main: Node
var _fails := 0
var _step := -1
var _t := 0.0
var _boss: Enemy = null
var _pillar: Pillar = null
var _anchor := Vector2.ZERO
var _slot := -1
var _ev_i := 0
var _hits := 0
var _octants := {}
var _kinds := {}
var _aim_n := 0
var _aim_bad := 0
var _dir4_bad := 0
var _sync_n := 0
var _sync_bad := 0
var _rain_ok := true
var _rain_seen := 0
var _lanes_max := 0
var _intro_attacks := 0
var _intro_s := 0.0
var _flood_max := 0.0
var _mist_far := false
var _angle0 := 0.0
var _angle0_t := 0.0
var _angle1 := 0.0
var _trans_checked := false
var _has_art := false
var _deaths0 := 0
var _shots_dir := ""
var _shot_n := 0
var _shot_t := 0.0
var _shot_seen := {}


func _ready() -> void:
	_capture = "capture" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			_shots_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(_shots_dir)
	# la Source passe par le plan de run (règles de la carte : paratonnerre-mère seul, setup_final) ;
	# map=<id> ou carte absente : carte imposée (map_scene, boss d'étage du pilier)
	var map := "" if ResourceLoader.exists(MAP_SOURCE) else MAP_FALLBACK
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map="):
			map = "res://scenes/stage/maps/%s.tscn" % a.substr(4)
	print("  carte : ", map if map != "" else "la_source (plan de run, étage 5)")
	_main = load("res://scenes/main.tscn").instantiate()
	if map != "":
		_main.set(&"map_scene", load(map))
	else:
		_via_plan = true
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 53)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _brain() -> RainSowerBrain:
	return _boss.brain as RainSowerBrain if _boss != null and _boss.brain is RainSowerBrain else null


func _physics_process(delta: float) -> void:
	if _step < 0 or _step == 99:
		return
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	_t += delta
	if _shots_dir != "" and _step in [1, 2, 3, 4, 5]:
		_shoot_keys(delta)
	match _step:
		0:
			_director().spawning_enabled = false
			if _via_plan and _t > 0.3:
				_via_plan = false
				RunState.stage = 5
				(_main.get(&"stage") as StageManager).start_stage()
				_t = 0.0
			if not _via_plan and _t > 1.6:
				for e in get_tree().get_nodes_in_group(&"enemies").duplicate():
					if e is Enemy and not e.is_boss:
						_director().release_enemy(e)
				RunState.stage = 5
				(_main.get(&"stage") as StageManager).floor_boss = &"rain_sower"
				_spawn()
		1: # entrée
			var b := _brain()
			_place_around(_anchor, 0, DIST_PX)
			_scan()
			if b.state == RainSowerBrain.S.INTRO:
				_intro_s = _t
			elif _t > 0.1:
				_check("entrée : colonne de pluie, aucun coup (≥ 2 s)", _intro_s >= 2.0 and _intro_attacks == 0, "%.2f s, %d coups" % [_intro_s, _intro_attacks])
				_next(2)
		2: # phase 1 : 8 directions
			var slot_s := SLOT_S
			_place(mini(int(_t / slot_s), 7))
			_scan()
			_check_rain()
			if _t > slot_s * 8.0:
				_end_p1()
		3: # phase 2 : crue
			var b := _brain()
			_flood_max = maxf(_flood_max, b.flood_r)
			_lanes_max = maxi(_lanes_max, b.lane_count())
			var c := b.center
			if _t < 4.0 or _t >= 8.0: # sur l'anneau, au bord de l'eau (zone de débordement)
				_place_at(c + Vector2.from_angle(int(_t / 2.0) * 0.8) * (RainSowerBrain.FLOOD_R_U + 1.4) * U)
			elif _t < 6.0: # dans le bassin
				_place_at(c + Vector2(0.6, 0.3) * U, false)
			else: # dans la brume du bord
				var p := _place_at(c + Vector2.from_angle(2.2) * (RainSowerBrain.MIST_R_U + 2.5) * U)
				if p.distance_to(c) > RainSowerBrain.MIST_R_U * U + 4.0:
					_mist_far = true
			if b.state == RainSowerBrain.S.CHASE and not _boss.visual.call(&"is_attacking") and _boss.position.distance_to(_anchor) > 40.0:
				_boss.position = _anchor
			_scan()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 2 sous 70 % (transition, boss figé)", b.phase == 2 and b.state == RainSowerBrain.S.STAGGER, "%d %d" % [b.phase, b.state])
			if _t > P2_S:
				_end_p2()
		4: # phase 3 : ancré
			var b := _brain()
			_scan()
			if b.state == RainSowerBrain.S.STAGGER:
				_place_around(b.anchor, 2, 5.0 * U)
			else:
				_anchor = b.anchor
				_place(int(_t / 2.5) % 8)
				if _angle0 == 0.0 and b.cross_count() > 0:
					_angle0 = b.cross_angle() + 0.0001
					_angle0_t = _t
				elif _angle0 != 0.0 and _angle1 == 0.0 and _t > _angle0_t + 1.5:
					_angle1 = b.cross_angle() + 0.0001
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 3 sous 35 % (ancrage, boss figé)", b.phase == 3 and b.state == RainSowerBrain.S.STAGGER, "%d %d" % [b.phase, b.state])
			if _t > P3_S:
				_end_p3()
		5:
			_place_at(_pillar.global_position + Vector2(5.0 * U, 0.0))
			if _t > 0.8:
				_check("mort : mise en scène (la pluie s'arrête)", RainSowerBrain.deaths == _deaths0 + 1, str(RainSowerBrain.deaths))
				_check("paratonnerre-mère terminé (boss mort)", _pillar.state == Pillar.STATE_DONE, str(_pillar.state))
				_check("mort : nœuds du Semeur libérés", _leftovers().is_empty(), str(_leftovers()))
				_finish()


func _leftovers() -> Array:
	var left: Array = []
	var roots: Array[Node] = [_director().get_node(^"Enemies")]
	var layer := AmbianceManager.telegraph_layer(get_tree())
	if layer != null:
		roots.append(layer)
	for r in roots:
		for n in r.get_children():
			if String(n.name).begins_with("RainSower") and not n.is_queued_for_deletion():
				left.append(String(n.name))
	return left


func _shoot_keys(delta: float) -> void:
	var b := _brain()
	_shot_t += delta
	var key := ""
	var ph := (b.phase if b.state != RainSowerBrain.S.INTRO else 0) if b != null else 4
	if b != null:
		match b.state:
			RainSowerBrain.S.INTRO:
				if float(b.get(&"_t")) > 0.6:
					key = "intro"
			RainSowerBrain.S.RAIN:
				if float(b.get(&"_t")) > 0.75:
					key = "rain"
			RainSowerBrain.S.WAVE_WIND:
				if float(b.get(&"_t")) > 0.7:
					key = "wave_wind"
			RainSowerBrain.S.WAVE_RUN:
				if float(b.get(&"_wave_t")) > 0.3:
					key = "wave_run"
			RainSowerBrain.S.LASH, RainSowerBrain.S.WHIRL:
				if float(b.get(&"_t")) > float(b.get(&"_dur")) * 0.7:
					key = "auto"
			RainSowerBrain.S.STAGGER:
				if float(b.get(&"_t")) > float(b.get(&"_dur")) * 0.6:
					key = "trans"
		if key == "" and not (b.get(&"_surge") as Dictionary).is_empty() and float((b.get(&"_surge") as Dictionary)["t"]) > 0.9:
			key = "surge"
		if key == "" and b.cross_count() > 0 and float(b.get(&"_gust_t")) > RainSowerBrain.GUST_EVERY - 0.4:
			key = "gust_warn"
		if key == "" and b.strike_count() > 0 and float((b.get(&"_strikes") as Array)[0]["t"]) > 0.8:
			key = "lightning_tele"
	var name := ""
	if key != "" and not _shot_seen.has("%d_%s" % [ph, key]):
		_shot_seen["%d_%s" % [ph, key]] = true
		name = "p%d_%s" % [ph, key]
	elif _shot_t > 4.0:
		name = "p%d_t%02d" % [ph, int(_t)]
	if name == "":
		return
	_shot_t = 0.0
	_shot_n += 1
	var img := get_viewport().get_texture().get_image()
	if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
	img.save_png("%s/%02d_%s.png" % [_shots_dir, _shot_n, name])


func _spawn() -> void:
	var sm: StageManager = _main.get(&"stage")
	_pillar = null
	for p: Pillar in sm.pillars:
		if p.kind == Pillar.Kind.BIG and p.state != Pillar.STATE_DONE:
			_pillar = p
			break
	if _pillar == null:
		_check("gros pilier présent", false)
		_finish()
		return
	_pillar.unlock()
	_deaths0 = RainSowerBrain.deaths
	var D := RunState.difficulty()
	_check("paratonnerre activé", _pillar.activate())
	_boss = _pillar.get(&"_boss") as Enemy
	if _boss == null:
		_check("boss apparu", false)
		_finish()
		return
	var b := _brain()
	_check("boss = rain_sower", StringName(_boss.get(&"_boss_sprite_id")) == &"rain_sower")
	_check("IA RainSowerBrain branchée", b != null)
	if b == null:
		_finish()
		return
	_check("chemin du sprite enregistré (fauna.json)", EnemyVisual.boss_path(&"rain_sower") == "res://assets/sprites/bosses/etage/rain_sower/rain_sower.tres", EnemyVisual.boss_path(&"rain_sower"))
	_has_art = bool(_boss.visual.get(&"_boss_sprite"))
	if _has_art:
		var sf: SpriteFrames = EnemyVisual.boss_frames(&"rain_sower")
		var missing: Array = []
		for base in ["auto", "spell_a", "spell_b"]:
			for d in ["e", "s", "w", "n"]:
				if not sf.has_animation(StringName("%s_%s" % [base, d])):
					missing.append("%s_%s" % [base, d])
		_check("anims directionnelles du semeur", missing.is_empty(), str(missing))
	else:
		_check("sans sprite : silhouette provisoire dessinée", _boss.get_node_or_null(^"RainSower_body") != null)
	var dmg_k := _boss.damage / Balance.boss_damage(&"etage", D)
	_check("dégâts de base 32 (×32/28)", absf(dmg_k - 32.0 / 28.0) < 0.02, "%.3f" % dmg_k)
	var hp_k := _boss.max_hp / Balance.boss_hp(&"etage", D, RunState.stage)
	print("  PV : %.0f (×%.2f d'un boss d'étage)" % [_boss.max_hp, hp_k])
	if _pillar.final_boss:
		_check("PV ×2 (paratonnerre-mère, une seule fois)", absf(hp_k - 2.0) < 0.05, "%.3f" % hp_k)
	_check("silhouette 4,5 u : rayon 1,8 u", is_equal_approx(_boss.radius_px, 1.8 * U), str(_boss.radius_px))
	_check("centre de l'arène = paratonnerre", b.center.distance_to(_pillar.global_position) < 1.0, str(b.center))
	_check("coefficients dans Balance (foudre 2,5)", is_equal_approx(Balance.boss_attack_coef(&"rain_sower", &"lightning"), 2.5)
		and is_equal_approx(Balance.boss_attack_coef(&"rain_sower", &"wave"), 1.5) and is_equal_approx(Balance.boss_damage_taken_mult(&"rain_sower", 3), 1.2))
	_check("entrée en cours", b.state == RainSowerBrain.S.INTRO and _director().get_node(^"Enemies").get_node_or_null(^"RainSower_column") != null)
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_anchor = _boss.position
	_next(1)


func _place_at(want: Vector2, resolve := true) -> Vector2:
	var d := _director()
	if resolve and d.nav != null:
		want = d.nav.resolve(want, 26.0)
	var p := _player()
	p.global_position = want
	if p.hp < p.max_hp * 0.5:
		p.hp = p.max_hp
		p.set(&"_invuln", 0.0)
		p.clear_statuses()
	return want


func _place_around(c: Vector2, slot: int, r: float) -> void:
	_place_at(c + Vector2.from_angle(slot * TAU / 8.0) * r)


func _place(slot: int) -> void:
	var b := _brain()
	if b == null:
		return
	if slot != _slot and b.state == RainSowerBrain.S.CHASE and not _boss.visual.call(&"is_attacking"):
		_slot = slot
	if b.phase < 3 and b.state == RainSowerBrain.S.CHASE and not _boss.visual.call(&"is_attacking") and _boss.position.distance_to(_anchor) > 40.0:
		_boss.position = _anchor
	_place_around(_anchor, maxi(_slot, 0), DIST_PX)


func _check_rain() -> void:
	var b := _brain()
	var drops: Array = b.get(&"_drops")
	if drops.is_empty() or float(b.get(&"_t")) > 0.05:
		return
	_rain_seen += 1
	if drops.size() < 5:
		_rain_ok = false
	var on_player := false
	for i in drops.size():
		var pi: Vector2 = drops[i]["pos"]
		if pi.distance_to(_player().global_position) < 40.0:
			on_player = true
		for j in range(i + 1, drops.size()):
			if pi.distance_to(drops[j]["pos"]) < (2.0 * RainSowerBrain.RAIN_R_U + RainSowerBrain.RAIN_GAP_U) * U - 0.5:
				_rain_ok = false
	if not on_player:
		_rain_ok = false


func _scan() -> void:
	var b := _brain()
	if b == null:
		return
	while _ev_i < b.events.size():
		var ev: Dictionary = b.events[_ev_i]
		_ev_i += 1
		var kind := StringName(ev["kind"])
		_kinds[kind] = int(_kinds.get(kind, 0)) + 1
		if _step == 1 and kind not in [&"intro", &"phase"]:
			_intro_attacks += 1
		if not ev.has("to"):
			continue
		_sync_n += 1
		var f := int(ev["frame"])
		var k := int(ev["expect"])
		var lag := float(ev["lag"])
		if lag < -0.001 or lag > 0.05 or (k >= 0 and (f < k - 1 or f > k)):
			_sync_bad += 1
			print("  %s : %s frame %d (attendu %d), décalage %.3f s" % [kind, ev["anim"], f, k, lag])
		if kind in [&"lash", &"rain", &"wave"] and _step == 2:
			var v: Vector2 = (ev["to"] as Vector2) - (ev["from"] as Vector2)
			var aim: Vector2 = ev["aim"]
			_aim_n += 1
			if absf(angle_difference(aim.angle(), v.angle())) > 0.3:
				_aim_bad += 1
				print("  %s : visée %.0f°, joueur à %.0f°" % [kind, rad_to_deg(aim.angle()), rad_to_deg(v.angle())])
			_octants[posmod(roundi(v.angle() / (TAU / 8.0)), 8)] = true
			var exp4 := (0 if aim.x >= 0.0 else 2) if absf(aim.x) >= absf(aim.y) else (1 if aim.y > 0.0 else 3)
			var diag := absf(absf(aim.x) - absf(aim.y)) < 0.15
			if int(ev["dir4"]) != exp4 and not diag:
				_dir4_bad += 1
			if _has_art and not diag and not String(ev["anim"]).ends_with("_" + EnemyVisual.BOSS_DIRS4[exp4]):
				_dir4_bad += 1


func _end_p1() -> void:
	var b := _brain()
	_check("phase 1 : fouet de chaîne", int(_kinds.get(&"lash", 0)) >= 2, str(_kinds))
	_check("phase 1 : averse", int(_kinds.get(&"rain", 0)) >= 1, str(_kinds))
	_check("averse : cercles disjoints, un sur le joueur", _rain_seen >= 1 and _rain_ok, "vus=%d" % _rain_seen)
	_check("phase 1 : vague (le front touche dans le couloir)", int(_kinds.get(&"wave", 0)) >= 1 and int(_kinds.get(&"wave_hit", 0)) >= 1, str(_kinds))
	_check("phase 1 : ni crue ni orage", b.flood_r == 0.0 and b.cross_count() == 0 and int(_kinds.get(&"lightning", 0)) == 0, str(_kinds))
	_check("coups télégraphiés face au joueur", _aim_n >= 6 and _aim_bad == 0, "%d / %d" % [_aim_bad, _aim_n])
	_check("8 directions : au moins 6 octants visés", _octants.size() >= 6, str(_octants.keys()))
	_check("orientation du boss = visée (4 côtés)", _dir4_bad == 0, str(_dir4_bad))
	_check("phase 1 : coups reçus par le joueur", _hits >= 3, str(_hits))
	_kinds = {}
	# seuils du design (70 / 35 %, Balance.BOSS_PHASE_THRESHOLDS), distincts des 66 / 33 % des autres boss
	_check("seuils de phase 70 / 35 % (Balance)", Balance.boss_phase(&"etage", &"rain_sower", 0.71) == 1
		and Balance.boss_phase(&"etage", &"rain_sower", 0.70) == 2 and Balance.boss_phase(&"etage", &"rain_sower", 0.36) == 2
		and Balance.boss_phase(&"etage", &"rain_sower", 0.35) == 3 and Balance.boss_phase(&"etage", &"cerf", 0.69) == 1
		and Balance.boss_phase(&"etage", &"cerf", 0.34) == 2)
	_boss.hp = _boss.max_hp * 0.69 # sous 70 % mais au-dessus de 66 % : seule la règle du Semeur bascule
	_boss.take_damage(1.0)
	_check("phase 2 dès 69 % des PV", _boss.boss_phase() == 2, str(_boss.boss_phase()))
	_next(3)


func _end_p2() -> void:
	_check("phase 2 : la crue monte (6 u)", absf(_flood_max - RainSowerBrain.FLOOD_R_U * U) < 1.0, "%.0f px" % _flood_max)
	_check("phase 2 : noyade dans le bassin", int(_kinds.get(&"drown", 0)) >= 2, str(_kinds))
	if _mist_far:
		_check("phase 2 : brume du bord (ralenti)", int(_kinds.get(&"mist", 0)) >= 1, str(_kinds))
	else:
		print("  (brume non vérifiée : bord de l'arène hors carte)")
	_check("phase 2 : débordement télégraphié qui touche", int(_kinds.get(&"surge", 0)) >= 1 and int(_kinds.get(&"surge_hit", 0)) >= 1, str(_kinds))
	_check("phase 2 : vague en éventail (3 couloirs)", _lanes_max == 3, str(_lanes_max))
	_kinds = {}
	_boss.hp = _boss.max_hp * 0.345 # sous 35 % mais au-dessus de 33 %
	_boss.take_damage(1.0)
	_check("phase 3 dès 34,5 % des PV", _boss.boss_phase() == 3, str(_boss.boss_phase()))
	_next(4)


func _end_p3() -> void:
	var b := _brain()
	_check("phase 3 : ancré devant le paratonnerre", _boss.position.distance_to(b.anchor) < 8.0 and b.anchor.distance_to(b.center) < 2.0 * U, "%.1f px" % _boss.position.distance_to(b.anchor))
	_check("phase 3 : l'eau a reflué, colonne sur le boss", b.flood_r == 0.0 and _director().get_node(^"Enemies").get_node_or_null(^"RainSower_column") != null)
	_check("phase 3 : l'ancrage frappe le paratonnerre", int(_kinds.get(&"anchor", 0)) == 1, str(_kinds))
	_check("phase 3 : croix de 4 lignes", b.cross_count() == 4, str(b.cross_count()))
	_check("phase 3 : la croix tourne", absf(angle_difference(_angle1, _angle0)) > 0.3, "%.2f -> %.2f" % [_angle0, _angle1])
	_check("phase 3 : la croix brûle", int(_kinds.get(&"cross", 0)) >= 1, str(_kinds))
	_check("phase 3 : foudre toutes les 4 s", int(_kinds.get(&"lightning", 0)) >= 2, str(_kinds))
	_check("phase 3 : tourbillon au contact", int(_kinds.get(&"whirl", 0)) >= 1, str(_kinds))
	_check("phase 3 : Rafale (lignes fantômes puis saut)", int(_kinds.get(&"gust_warn", 0)) >= 1 and b.gusts >= 1, str(_kinds))
	var hp0 := _boss.hp
	_boss.take_damage(100.0)
	_check("phase 3 : +20 % de dégâts reçus", is_equal_approx(hp0 - _boss.hp, 120.0), "%.1f" % (hp0 - _boss.hp))
	_check("impacts calés (tous les coups)", _sync_n >= 10 and _sync_bad == 0, "%d / %d" % [_sync_bad, _sync_n])
	_check("coups reçus par le joueur (total)", _hits >= 8, str(_hits))
	print("  semeur : %d coups reçus, %d impacts vérifiés, octants %s" % [_hits, _sync_n, str(_octants.keys())])
	_boss.take_damage(_boss.hp + 1.0)
	_check("semeur mort", not _boss.active)
	_check("mort : IA libérée", _boss.brain == null)
	_next(5)


func _next(step: int) -> void:
	_step = step
	_trans_checked = false
	_t = 0.0


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _finish() -> void:
	_step = 99
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
