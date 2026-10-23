extends Node
## Boss d'étage 3 : la Grue (CraneBrain) sur la carte cite_rouille.
## godot --headless --path game res://tests/crane_boss_test.tscn  -> RESULT: OK
## Capture : sans --headless, images clés en temps réel : `--resolution 1280x720 -- capture shots=<dossier absolu>`.
## Vérifie :
## 1. IA CraneBrain branchée ; sans sprite : silhouette provisoire (Crane_body) et chemin attendu enregistré dans
##    data/fauna.json ; coefficients et seuils (70 / 35 %) dans Balance ; abri : un conteneur coupe la flèche ;
## 2. phase 1 : joueur dans 8 directions : crochet / lâcher / balayage face au joueur (au moins 6 octants),
##    dégâts à l'impact (décalage < 0,05 s) ; le conteneur tombe sur le joueur, reste (StaticBody2D couche 1)
##    et disparaît après 8 s ; un seul conteneur par lâcher ;
## 3. phase 2 sous 70 % : transition (boss figé), 2 conteneurs par lâcher, disjoints ;
## 4. phase 3 sous 35 % : ancrée (immobile), conteneurs en spirale toutes les 2,5 s, arcs de tempête (alerte
##    puis décharge) entre conteneurs ;
## 5. mort pendant la charge : les conteneurs restent, puis s'effacent avec la fin de la charge ; nœuds libérés.
## Sauvegarde de test seulement (jamais user://run_save.json).

const MAP := "res://scenes/stage/maps/cite_rouille.tscn"
const SAVE := "user://test_crane_boss.json"
const DIST_PX := 180.0
const SLOT_S := 3.0
const P2_S := 14.0
const P3_S := 16.0
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
var _octants := {}
var _kinds := {}
var _aim_n := 0
var _aim_bad := 0
var _sync_n := 0
var _sync_bad := 0
var _max_pts := 0
var _pts_ok := true
var _seen_containers := 0
var _layer_ok := true
var _expired := false
var _trans_checked := false
var _yard: CraneYard = null
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
	_main.set(&"run_seed", 33)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _brain() -> CraneBrain:
	return _boss.brain as CraneBrain if _boss != null and _boss.brain is CraneBrain else null


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
				(_main.get(&"stage") as StageManager).floor_boss = &"crane"
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
				_check("phase 2 sous 70 % (transition, boss figé)", _brain().phase == 2 and _brain().state == CraneBrain.S.STAGGER, "%d %d" % [_brain().phase, _brain().state])
			if _t > P2_S:
				_end_p2()
		3:
			_place(int(_t / 3.0) % 8)
			_scan()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 3 sous 35 % : ancrée", _brain().phase == 3 and _brain().anchored, str(_brain().phase))
				_anchor = _boss.position
			if _t > P3_S:
				_end_p3()
		4:
			_player().global_position = _pillar.global_position + Vector2(64.0, 0.0)
			if _t > KEEP_S:
				_check("trace : les conteneurs restent après la mort (charge en cours)", is_instance_valid(_yard) and _yard.is_kept() and _yard.count() > 0,
					str(_yard.count()) if is_instance_valid(_yard) else "libéré")
				_pillar.charge = Pillar.CHARGE_TIME
				_next(5)
		5:
			if _t > 2.4:
				_check("pilier terminé (charge finie, boss mort)", _pillar.state == Pillar.STATE_DONE, str(_pillar.state))
				_check("conteneurs effacés avec la fin de la charge", not is_instance_valid(_yard))
				_check("mort : nœuds de la Grue libérés", _leftovers().is_empty(), str(_leftovers()))
				_finish()


func _leftovers() -> Array:
	var left: Array = []
	var roots: Array[Node] = [_director().get_node(^"Enemies")]
	var layer := AmbianceManager.telegraph_layer(get_tree())
	if layer != null:
		roots.append(layer)
	for r in roots:
		for n in r.get_children():
			if String(n.name).begins_with("Crane") and not n.is_queued_for_deletion():
				left.append(String(n.name))
	return left


func _shoot_keys(delta: float) -> void:
	var b := _brain()
	_shot_t += delta
	var key := ""
	var ph := b.phase if b != null else 4
	if b != null:
		match b.state:
			CraneBrain.S.DROP:
				if float(b.get(&"_t")) > 1.0:
					key = "drop"
			CraneBrain.S.SWEEP:
				if float(b.get(&"_t")) > 0.5:
					key = "sweep"
			CraneBrain.S.HOOK:
				if float(b.get(&"_t")) > float(b.get(&"_dur")) * 0.7:
					key = "hook"
			CraneBrain.S.STAGGER:
				if float(b.get(&"_t")) > 0.4:
					key = "trans"
		if key == "" and float(b.get(&"_arc_t")) > 0.8:
			key = "arc_warn"
		if key == "" and b.container_count() >= 3:
			key = "yard"
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
	_check("boss d'étage = crane", StringName(_boss.get(&"_boss_sprite_id")) == &"crane")
	_check("IA CraneBrain branchée", _boss.brain is CraneBrain)
	_check("chemin du sprite enregistré (fauna.json)", EnemyVisual.boss_path(&"crane") == "res://assets/sprites/bosses/etage/crane/crane.tres", EnemyVisual.boss_path(&"crane"))
	if bool(_boss.visual.get(&"_boss_sprite")):
		var sf: SpriteFrames = EnemyVisual.boss_frames(&"crane")
		var missing: Array = []
		for base in ["auto", "spell_a", "spell_b"]:
			for d in ["e", "s", "w", "n"]:
				if not sf.has_animation(StringName("%s_%s" % [base, d])):
					missing.append("%s_%s" % [base, d])
		_check("anims directionnelles de la grue", missing.is_empty(), str(missing))
	else:
		_check("sans sprite : silhouette provisoire dessinée", _boss.get_node_or_null(^"Crane_body") != null)
	_check("coefficients dans Balance", is_equal_approx(Balance.boss_attack_coef(&"crane", &"container"), 1.8)
		and is_equal_approx(Balance.boss_attack_coef(&"crane", &"sweep"), 1.4) and is_equal_approx(Balance.boss_attack_coef(&"crane", &"arc"), 1.3))
	_check("seuils de phase 70 / 35 %", Balance.boss_phase(&"etage", &"crane", 0.71) == 1 and Balance.boss_phase(&"etage", &"crane", 0.69) == 2 and Balance.boss_phase(&"etage", &"crane", 0.34) == 3)
	# abri : un conteneur entre la grue et le joueur coupe la flèche, pas à côté
	var y := _brain().yard()
	var c := y.drop(_boss.position + Vector2(3.0 * 64.0, 0.0), 0.0)
	_check("abri : le conteneur coupe la ligne de la flèche", y.blocks_line(_boss.position, _boss.position + Vector2(6.0 * 64.0, 0.0))
		and not y.blocks_line(_boss.position, _boss.position + Vector2(0.0, 6.0 * 64.0)))
	_check("conteneur = obstacle de la couche « world »", (c["body"] as StaticBody2D).collision_layer == 1)
	y.containers.erase(c)
	(c["body"] as Node).queue_free()
	(c["light"] as LightRig.Handle).release()
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_anchor = _boss.position
	_next(1)


func _place(slot: int) -> void:
	var b := _brain()
	if b == null:
		return
	if slot != _slot and b.state == CraneBrain.S.CHASE and not _boss.visual.call(&"is_attacking"):
		_slot = slot
	if b.state == CraneBrain.S.CHASE and not _boss.visual.call(&"is_attacking") and _boss.position.distance_to(_anchor) > 40.0 and not b.anchored:
		_boss.position = _anchor
	var want := _anchor + Vector2.from_angle(maxi(_slot, 0) * TAU / 8.0) * DIST_PX
	var d := _director()
	if d.nav != null:
		want = d.nav.resolve(want, 26.0)
	var y := b.yard()
	if y != null:
		var c := y.inside(want, 26.0)
		if not c.is_empty():
			want = y.push_out(c, want, 30.0)
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
	var y := b.yard()
	if y != null:
		_seen_containers = maxi(_seen_containers, y.count())
		for c in y.containers:
			if (c["body"] as StaticBody2D).collision_layer != 1:
				_layer_ok = false
	var drops: Array = b.get(&"_drops")
	for dr in drops:
		var pts: Array = dr["pts"]
		if bool(dr["anim"]):
			_max_pts = maxi(_max_pts, pts.size())
			if b.phase == 1 and pts.size() != 1:
				_pts_ok = false
			if pts.size() == 2 and (pts[0] as Vector2).distance_to(pts[1]) < 2.0 * CraneBrain.DROP_R_U * 64.0:
				_pts_ok = false
	while _ev_i < b.events.size():
		var ev: Dictionary = b.events[_ev_i]
		_ev_i += 1
		var kind := StringName(ev["kind"])
		_kinds[kind] = int(_kinds.get(kind, 0)) + 1
		if ev.has("lag") and ev.has("to"):
			_sync_n += 1
			var lag := float(ev["lag"])
			var f := int(ev["frame"])
			var k := int(ev["expect"])
			if lag < -0.001 or lag > 0.05 or (k >= 0 and (f < k - 1 or f > k)):
				_sync_bad += 1
				print("  %s : %s frame %d (attendu %d), décalage %.3f s" % [kind, ev["anim"], f, k, lag])
		if kind in [&"hook", &"drop", &"sweep"] and ev.has("to") and _step == 1:
			var v: Vector2 = (ev["to"] as Vector2) - (ev["from"] as Vector2)
			var aim: Vector2 = ev["aim"]
			_aim_n += 1
			if absf(angle_difference(aim.angle(), v.angle())) > 0.3:
				_aim_bad += 1
				print("  %s : visée %.0f°, joueur à %.0f°" % [kind, rad_to_deg(aim.angle()), rad_to_deg(v.angle())])
			_octants[posmod(roundi(v.angle() / (TAU / 8.0)), 8)] = true


func _end_p1() -> void:
	var b := _brain()
	_check("phase 1 : crochet", int(_kinds.get(&"hook", 0)) >= 2, str(_kinds))
	_check("phase 1 : lâcher de conteneur (touche le joueur dessous)", int(_kinds.get(&"drop", 0)) >= 1 and int(_kinds.get(&"container_hit", 0)) >= 1, str(_kinds))
	_check("phase 1 : un conteneur par lâcher", _pts_ok and _max_pts == 1, str(_max_pts))
	_check("phase 1 : balayage de flèche (touche ou abri)", int(_kinds.get(&"sweep", 0)) >= 1 and int(_kinds.get(&"sweep_hit", 0)) + int(_kinds.get(&"shielded", 0)) >= 1, str(_kinds))
	_check("conteneurs posés (obstacles couche 1)", _seen_containers >= 1 and _layer_ok, str(_seen_containers))
	_check("phase 1 : ni spirale ni arcs", int(_kinds.get(&"spiral", 0)) == 0 and int(_kinds.get(&"arc", 0)) == 0, str(_kinds))
	_check("coups télégraphés face au joueur", _aim_n >= 6 and _aim_bad == 0, "%d / %d" % [_aim_bad, _aim_n])
	_check("8 directions : au moins 6 octants visés", _octants.size() >= 6, str(_octants.keys()))
	_check("phase 1 : coups reçus par le joueur", _hits >= 3, str(_hits))
	# durée de vie : aucun conteneur ne dépasse 8 s
	var old := 0.0
	for c in b.yard().containers:
		old = maxf(old, CraneYard.LIFE - float(c["life"]))
	_check("conteneurs : 8 s puis disparition", old <= CraneYard.LIFE + 0.05, "%.2f s" % old)
	print("  P1 : %s, %d conteneurs vus au plus, abris %d" % [str(_kinds), _seen_containers, b.shielded])
	_kinds = {}
	_max_pts = 0
	_boss.hp = _boss.max_hp * 0.6
	_boss.take_damage(1.0)
	_next(2)


func _end_p2() -> void:
	_check("phase 2 : deux conteneurs par lâcher, disjoints", _max_pts == 2 and _pts_ok, "max %d ok %s" % [_max_pts, str(_pts_ok)])
	_check("phase 2 : lâcher et balayage", int(_kinds.get(&"drop", 0)) >= 1 and int(_kinds.get(&"sweep", 0)) >= 1, str(_kinds))
	print("  P2 : %s" % str(_kinds))
	_kinds = {}
	_boss.hp = _boss.max_hp * 0.3
	_boss.take_damage(1.0)
	_next(3)


func _end_p3() -> void:
	var b := _brain()
	_check("phase 3 : immobile (ancrée)", _boss.position.distance_to(_anchor) < 4.0, "%.1f px" % _boss.position.distance_to(_anchor))
	_check("phase 3 : conteneurs en spirale (toutes les 2,5 s)", int(_kinds.get(&"spiral", 0)) >= 4, str(_kinds))
	_check("phase 3 : arcs de tempête (alerte puis décharge)", int(_kinds.get(&"arc_warn", 0)) >= 1 and int(_kinds.get(&"arc", 0)) >= 1 and b.arcs_fired >= 1, str(_kinds))
	_check("phase 3 : balayage continue", int(_kinds.get(&"sweep", 0)) >= 1, str(_kinds))
	_check("impacts calés (tous les coups)", _sync_n >= 10 and _sync_bad == 0, "%d / %d" % [_sync_bad, _sync_n])
	_check("coups reçus par le joueur (total)", _hits >= 6, str(_hits))
	print("  P3 : %s ; grue : %d coups reçus, %d impacts vérifiés, octants %s" % [str(_kinds), _hits, _sync_n, str(_octants.keys())])
	_pillar.charge = 10.0
	_yard = b.yard()
	_boss.take_damage(_boss.hp + 1.0)
	_check("grue morte", not _boss.active)
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
