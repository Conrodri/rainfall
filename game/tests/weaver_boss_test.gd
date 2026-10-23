extends Node
## Boss d'étage 2 alternatif : la Tisseuse (WeaverBrain), carte foret_brume.
## godot --headless --path game res://tests/weaver_boss_test.tscn  -> RESULT: OK
## Capture : sans --headless, `--resolution 1280x720 -- capture shots=<dossier absolu>` (images clés).
## Vérifie :
## 1. IA WeaverBrain branchée ; sprites si livrés (anims directionnelles), sinon silhouette provisoire
##    (Weaver_body) et chemin attendu enregistré dans data/fauna.json ; coefficients et seuils Balance ;
## 2. phase 1 (joueur sur 8 directions) : morsure, fils et descente face au joueur, impacts calés ; les fils
##    restent, ralentissent le joueur et arrêtent un projectile de monstre ; intouchable dans la canopée ;
## 3. phase 2 sous 70 % : transition, toile à 2 brèches ; toucher la toile -> elle tombe sur le point touché ;
## 4. phase 3 sous 35 % : couronne de cocons (obstacles) qui éclosent en tier 1, fils ×4 ;
## 5. mort pendant la charge : fils et toile restent, puis se dissipent avec la fin de la charge.

const MAP := "res://scenes/stage/maps/foret_brume.tscn"
const SAVE := "user://test_weaver_boss.json"
const DIST_PX := 170.0
const SLOT_S := 2.6
const P2_S := 14.0
const P3_S := 12.0

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
var _kinds := {}
var _octants := {}
var _aim_n := 0
var _aim_bad := 0
var _sync_n := 0
var _sync_bad := 0
var _canopy_ok := 0
var _canopy_bad := 0
var _threads_seen := 0
var _proj_test := false
var _blocked0 := 0
var _web_probe := false
var _touch_at := Vector2.ZERO
var _web_drop_ok := false
var _max_threads := 0
var _cocoons_seen := 0
var _hatched0 := 0
var _snare: WeaverSnare = null
var _trans_checked := false
var _has_art := false
var _shots_dir := ""
var _shot_n := 0
var _shot_t := 0.0
var _shot_seen := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			_shots_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(_shots_dir)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(MAP))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 23)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _brain() -> WeaverBrain:
	return _boss.brain as WeaverBrain if _boss != null and _boss.brain is WeaverBrain else null


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
				RunState.stage = 2
				(_main.get(&"stage") as StageManager).floor_boss = &"weaver"
				_spawn()
		1:
			_place(mini(int(_t / SLOT_S), 7))
			_scan()
			_probe_projectile()
			if _t > SLOT_S * 8.0 + 2.0:
				_end_p1()
		2:
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 2 sous 70 % (transition, boss figé)", _brain().phase == 2 and _brain().state == WeaverBrain.S.STAGGER, "%d %d" % [_brain().phase, _brain().state])
			var sn := _brain().snare()
			if _t > 2.5 and not _web_probe and sn != null and sn.has_web() and _brain().state == WeaverBrain.S.CHASE and not _boss.visual.call(&"is_attacking"):
				# le joueur marche sur un brin de la toile (loin des brèches)
				var w := sn.web()
				var gaps: PackedFloat32Array = w["gaps"]
				var a := gaps[0] + PI * 0.5
				_touch_at = (w["center"] as Vector2) + Vector2.from_angle(a) * float(w["r"])
				_web_probe = true
				_t = 2.5
			if _web_probe:
				var p := _player()
				p.global_position = _touch_at
				_heal()
			else:
				_place(int(_t / 3.0) % 8)
			_scan()
			if _t > P2_S:
				_end_p2()
		3:
			if not _trans_checked and (_brain().phase == 3 or _t > 3.0): # pas de transition dans la canopée
				_trans_checked = true
				_check("phase 3 sous 35 % (après la chute si elle était dans la canopée)", _brain().phase == 3, str(_brain().phase))
				_hatched0 = _brain().snare().hatched
			_place(int(_t / 3.0) % 8)
			_scan()
			var sn := _brain().snare()
			if sn != null:
				_cocoons_seen = maxi(_cocoons_seen, sn.obstacle_count(&"cocoon"))
			if _t > P3_S:
				_end_p3()
		31:
			var b := _brain()
			if b == null or not b.in_canopy():
				_kill()
				_next(4)
		4:
			_player().global_position = _pillar.global_position + Vector2(64.0, 0.0)
			if _t > 1.5:
				_check("trace : fils et toile restent après la mort (charge en cours)", is_instance_valid(_snare) and not _snare.boss_alive and _snare.has_web())
				_pillar.charge = Pillar.CHARGE_TIME
				_next(5)
		5:
			if _t > 0.6:
				_check("pilier terminé (charge finie, boss mort)", _pillar.state == Pillar.STATE_DONE, str(_pillar.state))
				_check("trace dissipée avec la fin de la charge", not is_instance_valid(_snare))
				_check("mort : nœuds de la Tisseuse libérés", _leftovers().is_empty(), str(_leftovers()))
				_finish()


func _heal() -> void:
	var p := _player()
	if p.hp < p.max_hp * 0.5:
		p.hp = p.max_hp
		p.set(&"_invuln", 0.0)
		p.clear_statuses()


func _spawn() -> void:
	var sm: StageManager = _main.get(&"stage")
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
	_check("boss d'étage = weaver", StringName(_boss.get(&"_boss_sprite_id")) == &"weaver")
	_check("IA WeaverBrain branchée", _boss.brain is WeaverBrain)
	_check("chemin du sprite enregistré (fauna.json)", EnemyVisual.boss_path(&"weaver") == "res://assets/sprites/bosses/etage/weaver/weaver.tres", EnemyVisual.boss_path(&"weaver"))
	_has_art = bool(_boss.visual.get(&"_boss_sprite"))
	print("  art livré : ", _has_art)
	if _has_art:
		var sf: SpriteFrames = EnemyVisual.boss_frames(&"weaver")
		var missing: Array = []
		for base in ["auto", "spell_a", "spell_b"]:
			for d in ["e", "s", "w", "n"]:
				if not sf.has_animation(StringName("%s_%s" % [base, d])):
					missing.append("%s_%s" % [base, d])
		_check("anims directionnelles de la tisseuse", missing.is_empty(), str(missing))
		print("  extras : ", Array(sf.get_animation_names()).filter(func(n: String) -> bool: return not (n.begins_with("idle") or n.begins_with("walk") or n.begins_with("auto") or n.begins_with("spell"))))
	else:
		_check("sans sprite : silhouette provisoire dessinée", _boss.get_node_or_null(^"Weaver_body") != null)
	_check("coefficients dans Balance", is_equal_approx(Balance.boss_attack_coef(&"weaver", &"threads"), 1.2) and is_equal_approx(Balance.boss_attack_coef(&"weaver", &"drop"), 1.6))
	_check("seuils 70 / 35 %", Balance.boss_phase(&"etage", &"weaver", 0.69) == 2 and Balance.boss_phase(&"etage", &"weaver", 0.34) == 3 and Balance.boss_phase(&"etage", &"weaver", 0.71) == 1)
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_anchor = _boss.position
	_next(1)


func _place(slot: int) -> void:
	var b := _brain()
	if b == null:
		return
	var free: bool = b.state == WeaverBrain.S.CHASE and not _boss.visual.call(&"is_attacking")
	if slot != _slot and free:
		_slot = slot
	if free and _boss.position.distance_to(_anchor) > 40.0:
		_boss.position = _anchor
	var want := _anchor + Vector2.from_angle(maxi(_slot, 0) * TAU / 8.0) * DIST_PX
	var d := _director()
	if d.nav != null:
		want = d.nav.resolve(want, 26.0)
	_player().global_position = want
	_heal()


## Un projectile de monstre tiré à travers un fil posé doit s'arrêter dessus.
func _probe_projectile() -> void:
	var sn := _brain().snare()
	if _proj_test or sn == null or sn.thread_count() == 0:
		return
	var th: Dictionary = (sn.get(&"_threads") as Array)[0]
	var a: Vector2 = th["a"]
	var b: Vector2 = th["b"]
	var mid := a.lerp(b, 0.5)
	var nrm := (b - a).normalized().orthogonal()
	_proj_test = true
	_blocked0 = sn.blocked
	_director().fire_projectile(_boss, mid + nrm * 90.0, -nrm * 300.0, 1.0)


func _scan() -> void:
	var b := _brain()
	if b == null:
		return
	if b.in_canopy():
		var m := b.damage_taken_mult()
		if m == 0.0:
			_canopy_ok += 1
		else:
			_canopy_bad += 1
	var sn := b.snare()
	if sn != null:
		_max_threads = maxi(_max_threads, sn.thread_count())
	while _ev_i < b.events.size():
		var ev: Dictionary = b.events[_ev_i]
		_ev_i += 1
		var kind := StringName(ev["kind"])
		_kinds[kind] = int(_kinds.get(kind, 0)) + 1
		if kind == &"web_vibration" and _web_probe:
			_web_drop_ok = (ev["at"] as Vector2).distance_to(_touch_at) < 1.6 * 64.0
		if ev.has("lag") and ev.has("to"):
			_sync_n += 1
			var f := int(ev["frame"])
			var k := int(ev["expect"])
			var lag := float(ev["lag"])
			if lag < -0.001 or lag > 0.05 or (k >= 0 and (f < k - 1 or f > k)):
				_sync_bad += 1
				print("  %s : %s frame %d (attendu %d), décalage %.3f s" % [kind, ev["anim"], f, k, lag])
		if kind in [&"bite", &"threads"] and ev.has("to") and _step == 1:
			var v: Vector2 = (ev["to"] as Vector2) - (ev["from"] as Vector2)
			var aim: Vector2 = ev["aim"]
			_aim_n += 1
			if absf(angle_difference(aim.angle(), v.angle())) > 0.3:
				_aim_bad += 1
				print("  %s : visée %.0f°, joueur à %.0f°" % [kind, rad_to_deg(aim.angle()), rad_to_deg(v.angle())])
			_octants[posmod(roundi(v.angle() / (TAU / 8.0)), 8)] = true


func _end_p1() -> void:
	var sn := _brain().snare()
	_check("phase 1 : morsure", int(_kinds.get(&"bite", 0)) >= 2, str(_kinds))
	_check("phase 1 : fils", int(_kinds.get(&"threads", 0)) >= 1, str(_kinds))
	_check("phase 1 : descente (chute)", int(_kinds.get(&"drop", 0)) >= 1, str(_kinds))
	_check("phase 1 : la chute touche le joueur", int(_kinds.get(&"drop_hit", 0)) >= 1, str(_kinds))
	_check("intouchable dans la canopée", _canopy_ok > 0 and _canopy_bad == 0, "ok=%d bad=%d" % [_canopy_ok, _canopy_bad])
	_check("les fils restent au sol", _max_threads >= 3, str(_max_threads))
	_check("les fils ralentissent le joueur", sn != null and sn.slowed >= 1, str(sn.slowed if sn != null else -1))
	_check("les fils arrêtent les projectiles des monstres", _proj_test and sn != null and sn.blocked > _blocked0, "%d -> %d" % [_blocked0, sn.blocked if sn != null else -1])
	_check("phase 1 : pas de toile ni de cocons", sn != null and not sn.has_web() and sn.obstacle_count() == 0)
	_check("coups télégraphiés face au joueur", _aim_n >= 4 and _aim_bad == 0, "%d / %d" % [_aim_bad, _aim_n])
	_check("8 directions : au moins 5 octants visés", _octants.size() >= 5, str(_octants.keys()))
	_check("phase 1 : coups reçus par le joueur", _hits >= 3, str(_hits))
	_kinds = {}
	_boss.hp = _boss.max_hp * 0.66
	_boss.take_damage(1.0)
	_next(2)


func _end_p2() -> void:
	var sn := _brain().snare()
	_check("phase 2 : toile tendue", sn != null and sn.has_web())
	if sn != null and sn.has_web():
		var w := sn.web()
		_check("toile : anneau de 6 u à 2 brèches", is_equal_approx(float(w["r"]), 6.0 * 64.0) and (w["gaps"] as PackedFloat32Array).size() == 2)
	_check("SURPRISE : toucher la toile la fait tomber sur le point touché", _web_drop_ok and _brain().web_drops >= 1, "drops=%d" % _brain().web_drops)
	_check("phase 2 : chute sur la vibration", int(_kinds.get(&"drop", 0)) >= 1, str(_kinds))
	_kinds = {}
	_boss.hp = _boss.max_hp * 0.3
	_boss.take_damage(1.0)
	_next(3)


func _end_p3() -> void:
	var sn := _brain().snare()
	_check("phase 3 : ponte de cocons (couronne)", int(_kinds.get(&"cocoons", 0)) >= 1 and _cocoons_seen >= 4, "%s, %d cocons" % [str(_kinds), _cocoons_seen])
	_check("phase 3 : les cocons éclosent en tier 1", sn != null and sn.hatched > _hatched0, str(sn.hatched if sn != null else -1))
	_check("phase 3 : fils ×4", _max_threads >= 4, str(_max_threads))
	_check("impacts calés (tous les coups)", _sync_n >= 6 and _sync_bad == 0, "%d / %d" % [_sync_bad, _sync_n])
	_check("coups reçus par le joueur (total)", _hits >= 5, str(_hits))
	print("  tisseuse : %d coups reçus, %d impacts vérifiés, %d chutes de toile, %d éclos, %d tirs arrêtés" % [_hits, _sync_n, _brain().web_drops, sn.hatched, sn.blocked])
	_pillar.charge = 10.0
	_snare = sn
	_next(31)


## Mise à mort une fois la Tisseuse au sol (intouchable dans la canopée).
func _kill() -> void:
	_boss.take_damage(_boss.hp + 1.0)
	_check("tisseuse morte", not _boss.active)
	_check("mort : IA libérée", _boss.brain == null)
	for e in get_tree().get_nodes_in_group(&"enemies").duplicate():
		if e is Enemy and not e.is_boss:
			_director().release_enemy(e)
	_next(4)


func _leftovers() -> Array:
	var left: Array = []
	for n in _director().get_node(^"Enemies").get_children():
		if String(n.name).begins_with("Weaver") and not n.is_queued_for_deletion():
			left.append(String(n.name))
	return left


func _shoot_keys(delta: float) -> void:
	var b := _brain()
	_shot_t += delta
	var key := ""
	var ph := b.phase if b != null else 4
	if b != null:
		match b.state:
			WeaverBrain.S.THREADS:
				if float(b.get(&"_t")) > 0.75:
					key = "threads"
			WeaverBrain.S.HANG:
				if float(b.get(&"_t")) > 0.5:
					key = "hang"
			WeaverBrain.S.BITE:
				if float(b.get(&"_t")) > float(b.get(&"_dur")) * 0.7:
					key = "bite"
			WeaverBrain.S.STAGGER:
				if float(b.get(&"_t")) > 0.5:
					key = "trans"
			WeaverBrain.S.CHASE:
				if b.snare() != null and b.snare().obstacle_count(&"cocoon") > 0:
					key = "cocoons"
				elif b.snare() != null and b.snare().thread_count() > 0:
					key = "threads_left"
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
