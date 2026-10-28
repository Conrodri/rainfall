extends Node
## Boss d'étage 2 alternatif : le Cèdre-Ermite (HermitCedarBrain), carte foret_brume.
## godot --headless --path game res://tests/hermit_cedar_boss_test.tscn  -> RESULT: OK
## Capture : sans --headless, `--resolution 1280x720 -- capture shots=<dossier absolu>` (images clés).
## Vérifie :
## 1. IA HermitCedarBrain branchée ; sprites si livrés, sinon silhouette provisoire (Cedar_body) ; Balance ;
## 2. phase 1 (joueur immobile sur 8 directions) : branche face au joueur ; racines en cage (centre sûr : le
##    joueur immobile n'est jamais touché) et en râteau (une ligne sur lui) ; spores + poison, le nuage
##    réempoisonne qui y reste ; impacts calés ;
## 3. phase 2 sous 70 % : enraciné (immobile, +25 % de dégâts reçus), racines ×6, vrille si le joueur fuit ;
## 4. phase 3 sous 35 % : charge qui sème des souches (obstacles), les souches répondent par des racines ;
## 5. mort pendant la charge : les souches restent, puis se dissipent avec la fin de la charge.

const MAP := "res://scenes/stage/maps/foret_brume.tscn"
const SAVE := "user://test_hermit_cedar_boss.json"
const DIST_PX := 170.0
const SLOT_S := 3.2
const P2_S := 16.0
const P3_S := 16.0

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
var _cage := false
var _cage_casts := 0
var _rake_casts := 0
var _cage_hits := 0
var _rake_hits := 0
var _six := 0
var _rooted_pos := Vector2.ZERO
var _rooted_drift := 0.0
var _max_stumps := 0
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
	_main.set(&"run_seed", 29)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _brain() -> HermitCedarBrain:
	return _boss.brain as HermitCedarBrain if _boss != null and _boss.brain is HermitCedarBrain else null


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
				(_main.get(&"stage") as StageManager).floor_boss = &"hermit_cedar"
				_spawn()
		1:
			_place(mini(int(_t / SLOT_S), 7), DIST_PX)
			_scan()
			if _t > SLOT_S * 8.0:
				_end_p1()
		2:
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 2 sous 70 % (transition)", _brain().phase == 2 and _brain().state == HermitCedarBrain.S.STAGGER, "%d %d" % [_brain().phase, _brain().state])
				_rooted_pos = _boss.position
				_anchor = _boss.position
			if _t > 0.2:
				_rooted_drift = maxf(_rooted_drift, _boss.position.distance_to(_rooted_pos))
			# moitié du temps au contact, moitié loin (vrille)
			_place(int(_t / 3.0) % 8, DIST_PX if _t < P2_S * 0.5 else 7.5 * 64.0, false)
			_scan()
			if _t > P2_S:
				_end_p2()
		3:
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 3 sous 35 %", _brain().phase == 3, str(_brain().phase))
			_place(int(_t / 4.0) % 8, 5.0 * 64.0, false)
			_scan()
			var sn := _brain().snare()
			if sn != null:
				_max_stumps = maxi(_max_stumps, sn.obstacle_count(&"stump"))
			if _t > P3_S:
				_end_p3()
		31:
			if _brain() == null or _brain().state != HermitCedarBrain.S.CHARGE_DASH:
				_kill()
				_next(4)
		4:
			_player().global_position = _pillar.global_position + Vector2(64.0, 0.0)
			if _t > 1.5:
				_check("trace : les souches restent après la mort (charge en cours)", is_instance_valid(_snare) and not _snare.boss_alive and _snare.obstacle_count(&"stump") > 0)
				_pillar.charge = Balance.PILLAR_CHARGE_S
				_next(5)
		5:
			if _t > 0.6:
				_check("pilier terminé (charge finie, boss mort)", _pillar.state == Pillar.STATE_DONE, str(_pillar.state))
				_check("trace dissipée avec la fin de la charge", not is_instance_valid(_snare))
				_check("mort : nœuds du Cèdre libérés", _leftovers().is_empty(), str(_leftovers()))
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
	_check("boss d'étage = hermit_cedar", StringName(_boss.get(&"_boss_sprite_id")) == &"hermit_cedar")
	_check("IA HermitCedarBrain branchée", _boss.brain is HermitCedarBrain)
	_check("chemin du sprite enregistré (fauna.json)", EnemyVisual.boss_path(&"hermit_cedar") == "res://assets/sprites/bosses/etage/hermit_cedar/hermit_cedar.tres", EnemyVisual.boss_path(&"hermit_cedar"))
	_has_art = bool(_boss.visual.get(&"_boss_sprite"))
	print("  art livré : ", _has_art)
	if _has_art:
		var sf: SpriteFrames = EnemyVisual.boss_frames(&"hermit_cedar")
		var missing: Array = []
		for base in ["auto", "spell_a", "spell_b"]:
			for d in ["e", "s", "w", "n"]:
				if not sf.has_animation(StringName("%s_%s" % [base, d])):
					missing.append("%s_%s" % [base, d])
		_check("anims directionnelles du cèdre", missing.is_empty(), str(missing))
	else:
		_check("sans sprite : silhouette provisoire dessinée", _boss.get_node_or_null(^"Cedar_body") != null)
	_check("coefficients dans Balance", is_equal_approx(Balance.boss_attack_coef(&"hermit_cedar", &"roots"), 1.3) and is_equal_approx(Balance.boss_attack_coef(&"hermit_cedar", &"charge"), 1.8))
	_check("seuils 70 / 35 % et +25 % enraciné", Balance.boss_phase(&"etage", &"hermit_cedar", 0.69) == 2 and Balance.boss_phase(&"etage", &"hermit_cedar", 0.34) == 3
		and is_equal_approx(Balance.boss_damage_taken_mult(&"hermit_cedar", 2), 1.25))
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_anchor = _boss.position
	_next(1)


func _place(slot: int, dist: float, pin_boss := true) -> void:
	var b := _brain()
	if b == null:
		return
	var free: bool = b.state == HermitCedarBrain.S.CHASE and not _boss.visual.call(&"is_attacking") and b.root_count() == 0
	if slot != _slot and free:
		_slot = slot
	if pin_boss and free and _boss.position.distance_to(_anchor) > 40.0:
		_boss.position = _anchor
	var c := _anchor if pin_boss else _boss.position
	var want := c + Vector2.from_angle(maxi(_slot, 0) * TAU / 8.0) * dist
	if not free and _slot >= 0 and not pin_boss:
		return # joueur immobile pendant les sorts
	var d := _director()
	if d.nav != null:
		want = d.nav.resolve(want, 26.0)
	if free or pin_boss:
		_player().global_position = want
	_heal()


func _scan() -> void:
	var b := _brain()
	if b == null:
		return
	var sn := b.snare()
	if sn != null:
		_max_stumps = maxi(_max_stumps, sn.obstacle_count(&"stump"))
	while _ev_i < b.events.size():
		var ev: Dictionary = b.events[_ev_i]
		_ev_i += 1
		var kind := StringName(ev["kind"])
		_kinds[kind] = int(_kinds.get(kind, 0)) + 1
		match kind:
			&"roots_cast":
				_cage = bool(ev["cage"])
				if _cage:
					_cage_casts += 1
				else:
					_rake_casts += 1
				if int(ev["n"]) == 6:
					_six += 1
			&"roots_hit":
				if _cage:
					_cage_hits += 1
				else:
					_rake_hits += 1
		if ev.has("lag") and ev.has("to"):
			_sync_n += 1
			var f := int(ev["frame"])
			var k := int(ev["expect"])
			var lag := float(ev["lag"])
			if lag < -0.001 or lag > 0.05 or (k >= 0 and (f < k - 1 or f > k)):
				_sync_bad += 1
				print("  %s : %s frame %d (attendu %d), décalage %.3f s" % [kind, ev["anim"], f, k, lag])
		if kind == &"branch" and ev.has("to"):
			var v: Vector2 = (ev["to"] as Vector2) - (ev["from"] as Vector2)
			var aim: Vector2 = ev["aim"]
			_aim_n += 1
			if absf(angle_difference(aim.angle(), v.angle())) > 0.3:
				_aim_bad += 1
			_octants[posmod(roundi(v.angle() / (TAU / 8.0)), 8)] = true


func _end_p1() -> void:
	_check("phase 1 : branche", int(_kinds.get(&"branch", 0)) >= 2, str(_kinds))
	_check("phase 1 : branche face au joueur", _aim_n >= 2 and _aim_bad == 0, "%d / %d" % [_aim_bad, _aim_n])
	_check("phase 1 : racines en cage et en râteau", _cage_casts >= 1 and _rake_casts >= 1, "cage %d râteau %d" % [_cage_casts, _rake_casts])
	_check("SURPRISE : cage, centre sûr (joueur immobile jamais touché)", _cage_hits == 0, str(_cage_hits))
	_check("râteau : une ligne sur le joueur", _rake_hits >= 1, str(_rake_hits))
	_check("phase 1 : spores et poison", int(_kinds.get(&"spores_hit", 0)) >= 1 and int(_kinds.get(&"poison", 0)) >= 2, str(_kinds))
	_check("phase 1 : coups reçus par le joueur", _hits >= 3, str(_hits))
	_kinds = {}
	_boss.hp = _boss.max_hp * 0.66
	_boss.take_damage(1.0)
	_next(2)


func _end_p2() -> void:
	var b := _brain()
	_check("phase 2 : enraciné (immobile)", _rooted_drift < 2.0, "%.1f px" % _rooted_drift)
	_check("phase 2 : +25 % de dégâts reçus", is_equal_approx(b.damage_taken_mult(), 1.25), str(b.damage_taken_mult()))
	_check("phase 2 : racines ×6", _six >= 1, str(_six))
	_check("phase 2 : vrille vers le joueur qui fuit", int(_kinds.get(&"tendril", 0)) >= 1, str(_kinds))
	_kinds = {}
	_boss.hp = _boss.max_hp * 0.3
	_boss.take_damage(1.0)
	_next(3)


func _end_p3() -> void:
	var b := _brain()
	_check("phase 3 : charge", int(_kinds.get(&"charge", 0)) >= 1, str(_kinds))
	_check("phase 3 : souches semées (obstacles)", _max_stumps >= 2, str(_max_stumps))
	_check("SURPRISE : les souches répondent par des racines", b.echoes >= 1 and int(_kinds.get(&"echo", 0)) >= 1, "echoes=%d %s" % [b.echoes, str(_kinds)])
	_check("impacts calés (tous les coups)", _sync_n >= 6 and _sync_bad == 0, "%d / %d" % [_sync_bad, _sync_n])
	_check("coups reçus par le joueur (total)", _hits >= 5, str(_hits))
	print("  cèdre : %d coups reçus, %d impacts vérifiés, cage %d / râteau %d, %d souches max, %d échos" % [_hits, _sync_n, _cage_casts, _rake_casts, _max_stumps, b.echoes])
	_pillar.charge = 10.0
	_snare = b.snare()
	_next(31)


func _kill() -> void:
	_boss.take_damage(_boss.hp + 1.0)
	_check("cèdre mort", not _boss.active)
	_check("mort : IA libérée", _boss.brain == null)


func _leftovers() -> Array:
	var left: Array = []
	for n in _director().get_node(^"Enemies").get_children():
		if String(n.name).begins_with("Cedar") and not n.is_queued_for_deletion():
			left.append(String(n.name))
	return left


func _shoot_keys(delta: float) -> void:
	var b := _brain()
	_shot_t += delta
	var key := ""
	var ph := b.phase if b != null else 4
	if b != null:
		if b.root_count() > 0 and float((b.get(&"_roots") as Array)[0]["t"]) > 0.7:
			key = "roots"
		match b.state:
			HermitCedarBrain.S.SPORES:
				if float(b.get(&"_t")) > 0.75:
					key = "spores"
			HermitCedarBrain.S.CHARGE_WIND:
				if float(b.get(&"_t")) > 0.9:
					key = "charge"
			HermitCedarBrain.S.BRANCH:
				if float(b.get(&"_t")) > float(b.get(&"_dur")) * 0.7:
					key = "branch"
			HermitCedarBrain.S.STAGGER:
				if float(b.get(&"_t")) > 0.5:
					key = "trans"
		if key == "" and b.cloud_count() > 0:
			key = "cloud"
		if key == "" and b.echoes > 0 and b.root_count() > 0:
			key = "echo"
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
