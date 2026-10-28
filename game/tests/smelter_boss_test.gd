extends Node
## Boss d'étage 3 : le Fondeur (SmelterBrain) sur la carte cite_rouille.
## godot --headless --path game res://tests/smelter_boss_test.tscn  -> RESULT: OK
## Capture : sans --headless, images clés en temps réel : `--resolution 1280x720 -- capture shots=<dossier absolu>`.
## Vérifie :
## 1. IA SmelterBrain branchée ; sans sprite : silhouette provisoire (Smelter_body) et chemin attendu enregistré
##    dans data/fauna.json ; coefficients, seuils (70 / 35 %) et surchauffe (+25 % en P3) dans Balance ;
## 2. phase 1 : joueur dans 8 directions : louche (brûlure) / coulée / étincelles face au joueur (au moins
##    6 octants), dégâts à l'impact (décalage < 0,05 s) ; la coulée laisse une flaque qui brûle puis disparaît ;
## 3. phase 2 sous 70 % : transition, débordement : alerte puis anneau de métal à 5 u à 2 brèches (passage sûr) ;
## 4. phase 3 sous 35 % : coulées en croix (4 lignes), 2 jets de vapeur qui tournent, trempe (alerte, foudre
##    dans la fonte, tout le métal figé) ;
## 5. mort pendant la charge : le métal reste et brûle, puis disparaît avec la fin de la charge ; nœuds libérés.
## Sauvegarde de test seulement (jamais user://run_save.json).

const MAP := "res://scenes/stage/maps/cite_rouille.tscn"
const SAVE := "user://test_smelter_boss.json"
const DIST_PX := 160.0
const SLOT_S := 3.0
const P2_S := 14.0
const P3_S := 18.0
const KEEP_S := 2.0

var _capture := false
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
var _slag_hits := 0
var _octants := {}
var _kinds := {}
var _aim_n := 0
var _aim_bad := 0
var _sync_n := 0
var _sync_bad := 0
var _seen_pools := 0
var _burning := false
var _ring_ok := false
var _ring_seen := false
var _cross_seen := 0
var _steam_a0 := -1.0
var _steam_travel := 0.0
var _quench_cleared := false
var _trans_checked := false
var _slag: SmelterSlag = null
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
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(MAP))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 37)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1
		elif source != null and source is SmelterSlag:
			_slag_hits += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _brain() -> SmelterBrain:
	return _boss.brain as SmelterBrain if _boss != null and _boss.brain is SmelterBrain else null


func _physics_process(delta: float) -> void:
	if _step < 0 or _step == 99:
		return
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	_t += delta
	if _shots_dir != "" and _step in [1, 2, 3, 4]:
		_shoot_keys(delta)
	match _step:
		0:
			_director().spawning_enabled = false
			if _t > 1.6:
				for e in get_tree().get_nodes_in_group(&"enemies").duplicate():
					if e is Enemy and not e.is_boss:
						_director().release_enemy(e)
				RunState.stage = 3
				(_main.get(&"stage") as StageManager).floor_boss = &"smelter"
				_spawn()
		1:
			var slot_s := SLOT_S
			_place(mini(int(_t / slot_s), 7))
			_scan()
			if _t > slot_s * 8.0:
				_end_p1()
		2:
			_place(int(_t / 3.0) % 8)
			_scan()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 2 sous 70 % (transition, boss figé)", _brain().phase == 2 and _brain().state == SmelterBrain.S.STAGGER, "%d %d" % [_brain().phase, _brain().state])
			if _t > P2_S:
				_end_p2()
		3:
			_place(int(_t / 3.0) % 8)
			_scan()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 3 sous 35 % : surchauffe +25 %", _brain().phase == 3 and is_equal_approx(_brain().damage_taken_mult(), 1.25), str(_brain().damage_taken_mult()))
			if _t > P3_S:
				_end_p3()
		4:
			_player().global_position = _pillar.global_position + Vector2(64.0, 0.0)
			if _t > KEEP_S:
				_check("trace : le métal reste après la mort (charge en cours)", is_instance_valid(_slag) and _slag.is_kept() and _slag.metal_count() > 0,
					str(_slag.metal_count()) if is_instance_valid(_slag) else "libéré")
				_check("trace : le métal brûle encore le joueur", _slag_hits >= 1, str(_slag_hits))
				_pillar.charge = Balance.PILLAR_CHARGE_S
				_next(5)
		5:
			if _t > 1.0:
				_check("pilier terminé (charge finie, boss mort)", _pillar.state == Pillar.STATE_DONE, str(_pillar.state))
				_check("métal effacé avec la fin de la charge", not is_instance_valid(_slag))
				_check("mort : nœuds du Fondeur libérés", _leftovers().is_empty(), str(_leftovers()))
				_finish()


func _leftovers() -> Array:
	var left: Array = []
	var roots: Array[Node] = [_director().get_node(^"Enemies")]
	var layer := AmbianceManager.telegraph_layer(get_tree())
	if layer != null:
		roots.append(layer)
	for r in roots:
		for n in r.get_children():
			if String(n.name).begins_with("Smelter") and not n.is_queued_for_deletion():
				left.append(String(n.name))
	return left


func _shoot_keys(delta: float) -> void:
	var b := _brain()
	_shot_t += delta
	var key := ""
	var ph := b.phase if b != null else 4
	if b != null:
		match b.state:
			SmelterBrain.S.POUR:
				if float(b.get(&"_t")) > 0.75:
					key = "pour"
			SmelterBrain.S.SPARKS:
				if float(b.get(&"_t")) > 0.5:
					key = "sparks"
			SmelterBrain.S.LADLE:
				if float(b.get(&"_t")) > float(b.get(&"_dur")) * 0.7:
					key = "ladle"
			SmelterBrain.S.STAGGER:
				if float(b.get(&"_t")) > 0.4:
					key = "trans"
		if key == "" and float(b.get(&"_overflow_t")) > 0.8:
			key = "overflow_warn"
		if key == "" and float(b.get(&"_quench_t")) > 0.8:
			key = "quench_warn"
		if key == "" and b.slag() != null and b.slag().ring_count() > 0:
			key = "ring"
		if key == "" and b.slag() != null and b.slag().pool_count() >= 2:
			key = "pools"
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
	_check("pilier activé", _pillar.activate())
	_boss = _pillar.get(&"_boss") as Enemy
	if _boss == null:
		_check("boss apparu", false)
		_finish()
		return
	_check("boss d'étage = smelter", StringName(_boss.get(&"_boss_sprite_id")) == &"smelter")
	_check("IA SmelterBrain branchée", _boss.brain is SmelterBrain)
	_check("chemin du sprite enregistré (fauna.json)", EnemyVisual.boss_path(&"smelter") == "res://assets/sprites/bosses/etage/smelter/smelter.tres", EnemyVisual.boss_path(&"smelter"))
	if bool(_boss.visual.get(&"_boss_sprite")):
		var sf: SpriteFrames = EnemyVisual.boss_frames(&"smelter")
		var missing: Array = []
		for base in ["auto", "spell_a", "spell_b"]:
			for d in ["e", "s", "w", "n"]:
				if not sf.has_animation(StringName("%s_%s" % [base, d])):
					missing.append("%s_%s" % [base, d])
		_check("anims directionnelles du fondeur", missing.is_empty(), str(missing))
	else:
		_check("sans sprite : silhouette provisoire dessinée", _boss.get_node_or_null(^"Smelter_body") != null)
	_check("coefficients dans Balance", is_equal_approx(Balance.boss_attack_coef(&"smelter", &"pour"), 1.5)
		and is_equal_approx(Balance.boss_attack_coef(&"smelter", &"pool"), 0.5) and is_equal_approx(Balance.boss_attack_coef(&"smelter", &"quench"), 1.6))
	_check("seuils de phase 70 / 35 %", Balance.boss_phase(&"etage", &"smelter", 0.71) == 1 and Balance.boss_phase(&"etage", &"smelter", 0.69) == 2 and Balance.boss_phase(&"etage", &"smelter", 0.34) == 3)
	_check("surchauffe : +25 % de dégâts reçus en P3 seulement", is_equal_approx(Balance.boss_damage_taken_mult(&"smelter", 1), 1.0) and is_equal_approx(Balance.boss_damage_taken_mult(&"smelter", 3), 1.25))
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_anchor = _boss.position
	_next(1)


func _place(slot: int) -> void:
	var b := _brain()
	if b == null:
		return
	if slot != _slot and b.state == SmelterBrain.S.CHASE and not _boss.visual.call(&"is_attacking"):
		_slot = slot
	if b.state == SmelterBrain.S.CHASE and not _boss.visual.call(&"is_attacking") and _boss.position.distance_to(_anchor) > 40.0:
		_boss.position = _anchor
	var want := _anchor + Vector2.from_angle(maxi(_slot, 0) * TAU / 8.0) * DIST_PX
	var d := _director()
	if d.nav != null:
		want = d.nav.resolve(want, 26.0)
	var p := _player()
	p.global_position = want
	if p.hp < p.max_hp * 0.5:
		p.hp = p.max_hp
		p.set(&"_invuln", 0.0)
		p.clear_statuses()


func _scan() -> void:
	var b := _brain()
	if b == null:
		return
	if _player().has_method(&"is_burning") and _player().is_burning():
		_burning = true
	var s := b.slag()
	if s != null:
		_seen_pools = maxi(_seen_pools, s.pool_count())
		if s.ring_count() > 0 and not _ring_seen:
			_ring_seen = true
			var r: Dictionary = s.rings[0]
			var c: Vector2 = r["c"]
			var g: Array = r["gaps"]
			var rr := float(r["r"])
			# passage sûr au centre d'une brèche ; métal à mi-chemin entre les deux brèches
			var mid := (float(g[0]) + angle_difference(float(g[0]), float(g[1])) * 0.5)
			_ring_ok = g.size() == 2 and not SmelterSlag.in_ring(r, c + Vector2.from_angle(float(g[0])) * rr) \
				and not SmelterSlag.in_ring(r, c + Vector2.from_angle(float(g[1])) * rr) \
				and SmelterSlag.in_ring(r, c + Vector2.from_angle(mid) * rr) \
				and not SmelterSlag.in_ring(r, c + Vector2.from_angle(mid) * (rr + 1.6 * 64.0))
	if b.state == SmelterBrain.S.POUR:
		_cross_seen = maxi(_cross_seen, (b.get(&"_pour_angles") as Array).size())
	if b.jet_count() > 0:
		var a := b.steam_angle()
		if _steam_a0 >= 0.0:
			_steam_travel += absf(angle_difference(_steam_a0, a))
		_steam_a0 = a
	while _ev_i < b.events.size():
		var ev: Dictionary = b.events[_ev_i]
		_ev_i += 1
		var kind := StringName(ev["kind"])
		_kinds[kind] = int(_kinds.get(kind, 0)) + 1
		if kind == &"quench" and int(ev.get("puffs", 0)) > 0 and s != null and s.pool_count() == 0:
			_quench_cleared = true
		if ev.has("lag") and ev.has("to"):
			_sync_n += 1
			var lag := float(ev["lag"])
			var f := int(ev["frame"])
			var k := int(ev["expect"])
			if lag < -0.001 or lag > 0.05 or (k >= 0 and (f < k - 1 or f > k)):
				_sync_bad += 1
				print("  %s : %s frame %d (attendu %d), décalage %.3f s" % [kind, ev["anim"], f, k, lag])
		if kind in [&"ladle", &"pour", &"sparks"] and ev.has("to") and _step == 1:
			var v: Vector2 = (ev["to"] as Vector2) - (ev["from"] as Vector2)
			var aim: Vector2 = ev["aim"]
			_aim_n += 1
			if absf(angle_difference(aim.angle(), v.angle())) > 0.3:
				_aim_bad += 1
				print("  %s : visée %.0f°, joueur à %.0f°" % [kind, rad_to_deg(aim.angle()), rad_to_deg(v.angle())])
			_octants[posmod(roundi(v.angle() / (TAU / 8.0)), 8)] = true


func _end_p1() -> void:
	_check("phase 1 : louche + brûlure", int(_kinds.get(&"ladle", 0)) >= 2 and _brain().burns >= 1 and _burning, "%s burns=%d" % [str(_kinds), _brain().burns])
	_check("phase 1 : coulée (touche à l'impact)", int(_kinds.get(&"pour", 0)) >= 1 and int(_kinds.get(&"pour_hit", 0)) >= 1, str(_kinds))
	_check("phase 1 : la coulée reste et brûle (flaque)", _seen_pools >= 1 and int(_kinds.get(&"pool", 0)) >= 1, "%d %s" % [_seen_pools, str(_kinds)])
	_check("phase 1 : étincelles", int(_kinds.get(&"sparks", 0)) >= 1, str(_kinds))
	_check("phase 1 : ni anneau ni trempe", int(_kinds.get(&"overflow", 0)) == 0 and int(_kinds.get(&"quench", 0)) == 0, str(_kinds))
	_check("phase 1 : une seule coulée à la fois", _cross_seen == 1, str(_cross_seen))
	_check("coups télégraphés face au joueur", _aim_n >= 6 and _aim_bad == 0, "%d / %d" % [_aim_bad, _aim_n])
	_check("8 directions : au moins 6 octants visés", _octants.size() >= 6, str(_octants.keys()))
	_check("phase 1 : coups reçus par le joueur", _hits >= 3, str(_hits))
	var oldest := 0.0
	for q in _brain().slag().pools:
		oldest = maxf(oldest, float(q["max"]) - float(q["life"]))
	_check("flaques : 5 s puis disparition", oldest <= SmelterBrain.POOL_LIFE + 0.05, "%.2f" % oldest)
	print("  P1 : %s, flaques au plus %d" % [str(_kinds), _seen_pools])
	_kinds = {}
	_cross_seen = 0
	_boss.hp = _boss.max_hp * 0.6
	_boss.take_damage(1.0)
	_next(2)


func _end_p2() -> void:
	_check("phase 2 : débordement (alerte puis anneau)", int(_kinds.get(&"overflow_warn", 0)) >= 1 and int(_kinds.get(&"overflow", 0)) >= 1, str(_kinds))
	_check("anneau à 5 u : 2 brèches sûres, métal ailleurs, rien au-delà", _ring_seen and _ring_ok)
	print("  P2 : %s" % str(_kinds))
	_kinds = {}
	_cross_seen = 0
	_boss.hp = _boss.max_hp * 0.3
	_boss.take_damage(1.0)
	_next(3)


func _end_p3() -> void:
	var b := _brain()
	_check("phase 3 : coulées en croix (4 lignes)", _cross_seen == 4, str(_cross_seen))
	_check("phase 3 : 2 jets de vapeur qui tournent", b.jet_count() == 2 and _steam_travel >= SmelterBrain.STEAM_TURN * 3.0, "%d jets, %.2f rad" % [b.jet_count(), _steam_travel])
	_check("phase 3 : trempe (alerte, foudre, métal figé)", int(_kinds.get(&"quench_warn", 0)) >= 1 and int(_kinds.get(&"quench", 0)) >= 1 and b.quenches >= 1 and _quench_cleared, str(_kinds))
	_check("impacts calés (tous les coups)", _sync_n >= 10 and _sync_bad == 0, "%d / %d" % [_sync_bad, _sync_n])
	_check("coups reçus par le joueur (total)", _hits >= 6, str(_hits))
	print("  P3 : %s ; fondeur : %d coups reçus, %d impacts vérifiés, octants %s" % [str(_kinds), _hits, _sync_n, str(_octants.keys())])
	_pillar.charge = 10.0
	_slag = b.slag()
	# une coulée sous le joueur pour vérifier la trace
	var pp := _pillar.global_position + Vector2(64.0, 0.0)
	_slag.add_pool(pp - Vector2(3.0 * 64.0, 0.0), 0.0, 6.0 * 64.0, 2.0 * 64.0, 5.0)
	_boss.take_damage(_boss.hp + 1.0)
	_check("fondeur mort", not _boss.active)
	_check("mort : IA libérée", _boss.brain == null)
	_next(4)


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
