extends Node
## Boss d'étage 4 : l'Anguille des profondeurs (DeepEelBrain) ; carte des Cryptes.
## godot --headless --path game res://tests/deep_eel_boss_test.tscn  -> RESULT: OK
## Capture : sans --headless : `--resolution 1920x1080 -- capture shots=<dossier absolu> [strong]` (CaptureUtil, sRGB ;
## `strong` = télégraphes renforcés forcés).
## Vérifie :
## 1. IA branchée ; sprites : anims directionnelles si le .tres est livré, sinon silhouette provisoire
##    (DeepEel_body) et chemin attendu (fauna.json) ; coefficients et seuils 70 / 35 % dans Balance ;
##    le sol s'effondre en lac d'eau noire ; plongée = dégâts reçus × 0,3 ;
## 2. phase 1 : joueur autour du lac dans 8 directions : morsure / émergence / décharge face au joueur,
##    impacts calés ; émergence = ligne depuis l'eau, puis échouée (dégâts pleins) et retour à l'eau ;
##    décharge en anneau (coller l'anguille est sûr), ralentit ; flaques projetées ;
## 3. phase 2 sous 70 % : crue (lac + 2 u), cristaux noyés (RecluseGloom limité), surgit d'une flaque ;
## 4. phase 3 sous 35 % : échouée sur l'anneau (immobile, +25 %), 2 fouets qui tournent et touchent,
##    eau vive (lac + flaques) ;
## 4b. lisibilité : en plongée lueur visible sous l'eau + barre « PLONGÉE — DÉGÂTS RÉDUITS » ; échouée = pose
##    échouée (idle_p3) + barre « ÉCHOUÉE — VULNÉRABLE » ;
## 5. mort pendant la charge : la crue reste (trace), puis se retire avec la fin de la charge.
## Sauvegarde de test seulement (jamais user://run_save.json).

const MAP_CRYPTS := "res://scenes/stage/maps/cryptes_noyees.tscn"
const MAP_FALLBACK := "res://scenes/stage/maps/cite_rouille.tscn"
const SAVE := "user://test_deep_eel_boss.json"
const U := 64.0
const SLOT_S := 3.4
const P2_S := 16.0
const P3_S := 14.0
const TRACE_S := 2.0

var _capture := false
var _main: Node
var _fails := 0
var _step := -1
var _t := 0.0
var _boss: Enemy = null
var _pillar: Pillar = null
var _slot := -1
var _ev_i := 0
var _hits := 0
var _octants := {}
var _kinds := {}
var _all_kinds := {}
var _aim_n := 0
var _aim_bad := 0
var _sync_n := 0
var _sync_bad := 0
var _stranded_mult := -1.0
var _sub_mult := -1.0
var _trans_checked := false
var _anchor := Vector2.ZERO
var _anchor_bad := 0.0
var _gloom: Node = null
var _has_art := false
var _puddle_t := 0.0
var _shots_dir := ""
var _shot_n := 0
var _shot_t := 0.0
var _shot_seen := {}
var _glow_seen := false
var _tag_dive_seen := false
var _tag_strand_seen := false
var _pose_strand_ok := false


func _ready() -> void:
	_capture = "capture" in OS.get_cmdline_user_args()
	if "strong" in OS.get_cmdline_user_args():
		EnemyTelegraph.strong_override = 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			_shots_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(_shots_dir)
	var map := MAP_CRYPTS if ResourceLoader.exists(MAP_CRYPTS) else MAP_FALLBACK
	print("  carte : ", map)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(map))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 47)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _brain() -> DeepEelBrain:
	return _boss.brain as DeepEelBrain if _boss != null and _boss.brain is DeepEelBrain else null


func _physics_process(delta: float) -> void:
	if _step < 0 or _step == 99:
		return
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	_t += delta
	_heal()
	if _shots_dir != "" and _step in [1, 2, 3, 4]:
		_shoot_keys(delta)
	var b := _brain()
	match _step:
		0:
			_director().spawning_enabled = false
			if _t > 1.6:
				for e in get_tree().get_nodes_in_group(&"enemies").duplicate():
					if e is Enemy and not e.is_boss:
						_director().release_enemy(e)
				RunState.stage = 4
				(_main.get(&"stage") as StageManager).floor_boss = &"deep_eel"
				_spawn()
		1:
			var slot_s := SLOT_S
			var slot := mini(int(_t / slot_s), 7)
			# pairs : au bord (morsure, coller = sûr) ; impairs : plus loin (anneau de décharge, émergence)
			_place(slot, 1.6 if slot % 2 == 0 else 4.2)
			_mults()
			_scan()
			if _t > slot_s * 8.0:
				_end_p1()
		2:
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 2 sous 70 % (transition)", b.phase == 2 and b.state == DeepEelBrain.S.STAGGER, "%d %d" % [b.phase, b.state])
				_check("phase 2 : cristaux noyés (RecluseGloom limité au lac)", b.gloom() != null and b.gloom().radius > 0.0)
			# loin du lac, une flaque près du joueur : elle doit en surgir
			var far := b.center + Vector2.from_angle(-PI * 0.5 + 0.6 * float(int(_t / 4.0) % 3 - 1)) * (b.pool_r + 7.0 * U)
			if _director().nav != null:
				far = _director().nav.resolve(far, 26.0)
			if not _armed(b):
				_player().global_position = far
			_puddle_t -= get_physics_process_delta_time()
			if _puddle_t <= 0.0:
				_puddle_t = 3.0
				b.add_puddle(_player().global_position + Vector2(0.0, 2.2 * U))
			_scan()
			if _t > P2_S:
				_end_p2()
		3:
			if not _trans_checked and _t > 1.5:
				_trans_checked = true
				_check("phase 3 sous 35 % : échouée, ancrée", b.phase == 3 and b.state != DeepEelBrain.S.STAGGER and b.whip_count() == 2, "%d %d %d" % [b.phase, b.state, b.whip_count()])
				_anchor = _boss.position
				_check("phase 3 : vulnérable (+25 %)", is_equal_approx(b.damage_taken_mult(), 1.25), str(b.damage_taken_mult()))
			if _trans_checked:
				_anchor_bad = maxf(_anchor_bad, _boss.position.distance_to(_anchor))
				if b.state == DeepEelBrain.S.LIVE_WATER and int(_kinds.get(&"live_water_hit", 0)) == 0:
					# tant que l'eau vive n'a pas touché : le joueur reste dans le lac pendant l'avertissement (sinon le
					# test dépendait du tirage du créneau : une seule eau vive en 14 s, joueur parfois sur la terre ferme)
					var c := _director().nav.resolve(b.center, 26.0) if _director().nav != null else b.center
					if b.in_water(c, 0.0):
						_player().global_position = c
				elif not _armed(b):
					# alterne : dans le lac (eau vive) et sur la terre ferme à portée des fouets
					var k := int(_t / 1.7) % 4
					var p: Vector2
					if k == 0:
						p = b.center
					else:
						p = _anchor + Vector2.from_angle(TAU * k / 4.0 + _t * 0.2) * 4.0 * U
					_player().global_position = _director().nav.resolve(p, 26.0) if _director().nav != null else p
			_scan()
			if _t > P3_S:
				_end_p3()
		4:
			_player().global_position = _pillar.global_position + Vector2(-64.0, 0.0)
			if _t > TRACE_S:
				var g := _gloom as RecluseGloom
				_check("trace : la crue reste après la mort (charge en cours)", is_instance_valid(g) and g.trace_count() >= 1, str(g.trace_count() if is_instance_valid(g) else -1))
				_pillar.charge = Balance.PILLAR_CHARGE_S
				_next(5)
		5:
			if _t > 0.6:
				_check("pilier terminé (charge finie, boss mort)", _pillar.state == Pillar.STATE_DONE, str(_pillar.state))
				_check("crue retirée avec la fin de la charge", not is_instance_valid(_gloom))
				_check("mort : nœuds de l'Anguille libérés", _leftovers().is_empty(), str(_leftovers()))
				_finish()


func _heal() -> void:
	var p := _player()
	if p != null and p.hp < p.max_hp * 0.5:
		p.hp = p.max_hp
		p.set(&"_invuln", 0.0)
		p.clear_statuses()


func _armed(b: DeepEelBrain) -> bool:
	return b.state in [DeepEelBrain.S.BITE, DeepEelBrain.S.EMERGE_WIND, DeepEelBrain.S.DISCHARGE, DeepEelBrain.S.LIVE_WATER, DeepEelBrain.S.LUNGE]


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
	_check("pilier activé", _pillar.activate())
	_boss = _pillar.get(&"_boss") as Enemy
	if _boss == null:
		_check("boss apparu", false)
		_finish()
		return
	_check("boss d'étage = deep_eel", StringName(_boss.get(&"_boss_sprite_id")) == &"deep_eel")
	_check("IA DeepEelBrain branchée", _boss.brain is DeepEelBrain)
	_check("chemin du sprite enregistré (fauna.json)", EnemyVisual.boss_path(&"deep_eel") == "res://assets/sprites/bosses/etage/deep_eel/deep_eel.tres", EnemyVisual.boss_path(&"deep_eel"))
	_has_art = bool(_boss.visual.get(&"_boss_sprite"))
	if _has_art:
		var sf: SpriteFrames = EnemyVisual.boss_frames(&"deep_eel")
		var missing: Array = []
		for base in ["auto", "spell_a", "spell_b"]:
			for d in ["e", "s", "w", "n"]:
				if not sf.has_animation(StringName("%s_%s" % [base, d])):
					missing.append("%s_%s" % [base, d])
		_check("anims directionnelles de l'Anguille", missing.is_empty(), str(missing))
	else:
		_check("sans sprite : silhouette provisoire dessinée", _boss.get_node_or_null(^"DeepEel_body") != null)
	_check("coefficients dans Balance", is_equal_approx(Balance.boss_attack_coef(&"deep_eel", &"emergence"), 1.8)
		and is_equal_approx(Balance.boss_attack_coef(&"deep_eel", &"discharge"), 1.4) and is_equal_approx(Balance.boss_attack_coef(&"deep_eel", &"whip"), 0.5))
	_check("seuils 70 / 35 %", Balance.boss_phase(&"etage", &"deep_eel", 0.69) == 2 and Balance.boss_phase(&"etage", &"deep_eel", 0.34) == 3)
	var b := _brain()
	_check("le sol s'effondre : lac d'eau noire", _director().get_node(^"Enemies").get_node_or_null(^"DeepEel_pool") != null and is_equal_approx(b.pool_r, DeepEelBrain.POOL_R_U * U))
	print("  lac : %s (centre %s, pilier %s)" % [b.lake_source, b.center, _pillar.global_position])
	if b.lake_source == &"map":
		var nav := _director().nav
		_check("vrai lac : centre sur l'eau profonde de la carte", nav != null and nav.is_wall_at(b.center))
		_check("vrai lac : la rive côté pilier est à pied", nav != null and not nav.is_wall_at(b.center + (_pillar.global_position - b.center).normalized() * (b.pool_r + 0.6 * U)))
	_check("plongée après l'entrée en scène", b.submerged())
	_check("phase 1 : ni crue ni fouets", b.gloom() == null and b.whip_count() == 0)
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_next(1)


func _place(slot: int, out_u: float) -> void:
	var b := _brain()
	if b == null or _armed(b):
		return
	_slot = slot
	var a := _slot * TAU / 8.0
	if b.lake_source == &"map": # vrai lac de la carte : seule la rive côté pilier se fait à pied
		a = (_pillar.global_position - b.center).angle() + (float(_slot) - 3.5) * deg_to_rad(20.0)
	var want := b.center + Vector2.from_angle(a) * (b.pool_r + out_u * U)
	var d := _director()
	if d.nav != null and b.lake_source == &"map":
		var k := 0 # point dans l'eau profonde (mur de la carte) : ramené vers le pilier, sur la terre ferme
		while k < 12 and d.nav.is_wall_at(want):
			want = want.move_toward(_pillar.global_position, 0.5 * U)
			k += 1
	if d.nav != null:
		want = d.nav.resolve(want, 26.0)
	_player().global_position = want


func _mults() -> void:
	var b := _brain()
	var bar := _boss_bar()
	var t := float(b.get(&"_t"))
	if b.submerged():
		_sub_mult = b.damage_taken_mult()
		if t > 0.3:
			_glow_seen = _glow_seen or b.glow_shown()
			_tag_dive_seen = _tag_dive_seen or (bar != null and bar.state_tag_text() == DeepEelBrain.STATE_TAG_DIVE)
	elif b.state == DeepEelBrain.S.STRANDED:
		_stranded_mult = b.damage_taken_mult()
		if t > 0.1:
			_tag_strand_seen = _tag_strand_seen or (bar != null and bar.state_tag_text() == DeepEelBrain.STATE_TAG_STRANDED)
			var vis: EnemyVisual = _boss.visual
			_pose_strand_ok = _pose_strand_ok or (not _has_art) or (vis.pose_phase() == 3 and String(vis.current_anim()).begins_with("idle_p3"))


func _boss_bar() -> BossHealthBar:
	var hud = _main.get(&"hud")
	if hud == null or hud.boss_bars == null:
		return null
	var bars: Array[Node] = hud.boss_bars.find_children("*", "BossHealthBar", true, false)
	return bars[0] as BossHealthBar if not bars.is_empty() else null


func _scan() -> void:
	var b := _brain()
	if b == null:
		return
	while _ev_i < b.events.size():
		var ev: Dictionary = b.events[_ev_i]
		_ev_i += 1
		var kind := StringName(ev["kind"])
		_kinds[kind] = int(_kinds.get(kind, 0)) + 1
		_all_kinds[kind] = int(_all_kinds.get(kind, 0)) + 1
		if ev.has("lag") and ev.has("to"):
			_sync_n += 1
			var f := int(ev["frame"])
			var k := int(ev["expect"])
			var lag := float(ev["lag"])
			if lag < -0.001 or lag > 0.05 or (k >= 0 and (f < k - 1 or f > k)):
				_sync_bad += 1
				print("  %s : %s frame %d (attendu %d), décalage %.3f s" % [kind, ev["anim"], f, k, lag])
		if kind in [&"bite", &"emergence", &"discharge"] and ev.has("to") and _step == 1:
			var v: Vector2 = (ev["to"] as Vector2) - (ev["from"] as Vector2)
			var aim: Vector2 = ev["aim"]
			_aim_n += 1
			if v.length() > 20.0 and absf(angle_difference(aim.angle(), v.angle())) > 0.3:
				_aim_bad += 1
				print("  %s : visée %.0f°, joueur à %.0f°" % [kind, rad_to_deg(aim.angle()), rad_to_deg(v.angle())])
			_octants[posmod(roundi(((ev["to"] as Vector2) - b.center).angle() / (TAU / 8.0)), 8)] = true


func _end_p1() -> void:
	var b := _brain()
	_check("phase 1 : morsure au bord", int(_kinds.get(&"bite", 0)) >= 1, str(_kinds))
	_check("phase 1 : émergence (ligne depuis l'eau) qui touche", int(_kinds.get(&"emergence", 0)) >= 1 and int(_kinds.get(&"emergence_hit", 0)) >= 1, str(_kinds))
	_check("phase 1 : décharge en anneau qui touche et ralentit", int(_kinds.get(&"discharge", 0)) >= 1 and int(_kinds.get(&"discharge_hit", 0)) >= 1 and b.slowed >= 1, str(_kinds))
	_check("décharge : flaques d'eau noire projetées", int(_kinds.get(&"puddle", 0)) >= 1, str(_kinds))
	_check("plongée : dégâts reçus × 0,3", is_equal_approx(_sub_mult, Balance.EEL_SUBMERGED_DAMAGE_TAKEN), str(_sub_mult))
	_check("échouée après l'émergence : dégâts pleins", is_equal_approx(_stranded_mult, 1.0), str(_stranded_mult))
	_check("plongée lisible : lueur sous l'eau", _glow_seen)
	_check("barre de boss : « %s »" % DeepEelBrain.STATE_TAG_DIVE, _tag_dive_seen)
	_check("barre de boss : « %s »" % DeepEelBrain.STATE_TAG_STRANDED, _tag_strand_seen)
	_check("échouée : pose échouée (idle_p3) hors de l'eau", _pose_strand_ok)
	_check("phase 1 : ni crue ni fouets", b.gloom() == null and b.whip_count() == 0 and is_equal_approx(b.pool_r, DeepEelBrain.POOL_R_U * U))
	_check("coups télégraphiés face au joueur", _aim_n >= 4 and _aim_bad == 0, "%d / %d" % [_aim_bad, _aim_n])
	var min_oct := 3 if _brain() != null and _brain().lake_source == &"map" else 5 # vrai lac : rive sur ~150°
	_check("8 directions : au moins %d octants" % min_oct, _octants.size() >= min_oct, str(_octants.keys()))
	_check("phase 1 : coups reçus par le joueur", _hits >= 3, str(_hits))
	# coller l'anguille pendant la décharge est sûr (anneau intérieur)
	var e := _boss
	var inside := e.position + Vector2(DeepEelBrain.DISCHARGE_R0_U * U * 0.4, 0.0)
	var outside := e.position + Vector2((DeepEelBrain.DISCHARGE_R0_U + DeepEelBrain.DISCHARGE_R1_U) * 0.5 * U, 0.0)
	var n0 := int(_kinds.get(&"discharge_hit", 0))
	b.set(&"_ppos", inside)
	b.call(&"_release_discharge", _player(), inside)
	var n1 := b.events.filter(func(x: Dictionary) -> bool: return x["kind"] == &"discharge_hit").size()
	b.call(&"_release_discharge", _player(), outside)
	var n2 := b.events.filter(func(x: Dictionary) -> bool: return x["kind"] == &"discharge_hit").size()
	_check("décharge : sûr collé à elle, touché dans l'anneau", n2 == n1 + 1, "%d %d %d" % [n0, n1, n2])
	_ev_i = b.events.size() # coups provoqués par le test : hors du contrôle de calage
	_kinds = {}
	_boss.hp = _boss.max_hp * 0.68
	_boss.take_damage(1.0)
	_next(2)


func _end_p2() -> void:
	var b := _brain()
	_check("phase 2 : crue (lac + 2 u)", is_equal_approx(b.pool_r, (DeepEelBrain.POOL_R_U + DeepEelBrain.FLOOD_ADD_U) * U), "%.0f" % b.pool_r)
	_check("phase 2 SURPRISE : surgit d'une flaque près du joueur", b.emerge_from_puddle >= 1, str(_kinds))
	var g := b.gloom()
	if g != null:
		print("  crue : %d lumières de carte noyées" % g.dimmed)
	_kinds = {}
	_boss.hp = _boss.max_hp * 0.3
	_boss.take_damage(1.0)
	_next(3)


func _end_p3() -> void:
	var b := _brain()
	_check("phase 3 : ancrée (immobile)", _anchor_bad < 4.0, "%.1f px" % _anchor_bad)
	_check("phase 3 : les fouets touchent", int(_kinds.get(&"whip_hit", 0)) >= 1, str(_kinds))
	_check("phase 3 : eau vive (lac + flaques)", int(_kinds.get(&"live_water", 0)) >= 1 and int(_kinds.get(&"live_water_hit", 0)) >= 1, str(_kinds))
	_check("impacts calés (tous les coups)", _sync_n >= 8 and _sync_bad == 0, "%d / %d" % [_sync_bad, _sync_n])
	_check("coups reçus par le joueur (total)", _hits >= 6, str(_hits))
	print("  anguille : %d coups reçus, %d impacts vérifiés, événements %s" % [_hits, _sync_n, str(_all_kinds)])
	_pillar.charge = 10.0
	_gloom = b.gloom()
	_boss.take_damage(_boss.hp + 1.0)
	_check("anguille morte", not _boss.active)
	_check("mort : IA libérée", _boss.brain == null)
	_next(4)


func _leftovers() -> Array:
	var left: Array = []
	var roots: Array[Node] = [_director().get_node(^"Enemies")]
	var layer := AmbianceManager.telegraph_layer(get_tree())
	if layer != null:
		roots.append(layer)
	for r in roots:
		for n in r.get_children():
			if String(n.name).begins_with("DeepEel") and not n.is_queued_for_deletion():
				left.append(String(n.name))
	return left


func _shoot_keys(delta: float) -> void:
	var b := _brain()
	_shot_t += delta
	var key := ""
	var ph := b.phase if b != null else 4
	if b != null:
		var t := float(b.get(&"_t"))
		match b.state:
			DeepEelBrain.S.EMERGE_WIND:
				if t > 0.9:
					key = "emerge"
			DeepEelBrain.S.STRANDED:
				if t > 0.3:
					key = "stranded"
			DeepEelBrain.S.DISCHARGE:
				if t > 0.75:
					key = "discharge"
			DeepEelBrain.S.LIVE_WATER:
				if t > 0.75:
					key = "live_water"
			DeepEelBrain.S.BITE:
				if t > float(b.get(&"_dur")) * 0.7:
					key = "bite"
			DeepEelBrain.S.SWIM:
				if t > 0.8:
					key = "swim"
			DeepEelBrain.S.STAGGER:
				if t > 0.4:
					key = "trans"
	var name := ""
	if key != "" and not _shot_seen.has("%d_%s" % [ph, key]):
		_shot_seen["%d_%s" % [ph, key]] = true
		name = "p%d_%s" % [ph, key]
	elif _shot_t > 3.0:
		name = "p%d_t%02d" % [ph, int(_t)]
	if name == "":
		return
	_shot_t = 0.0
	_shot_n += 1
	CaptureUtil.save_viewport(get_viewport(), "%s/%02d_%s.png" % [_shots_dir, _shot_n, name])


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
