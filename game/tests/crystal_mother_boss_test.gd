extends Node
## Boss d'étage 4 : la Mère-Cristal (CrystalMotherBrain) ; carte des Cryptes.
## godot --headless --path game res://tests/crystal_mother_boss_test.tscn  -> RESULT: OK
## Capture : sans --headless : `--resolution 1280x720 -- capture shots=<dossier absolu>`.
## Vérifie :
## 1. IA branchée ; sprites : anims directionnelles si le .tres est livré, sinon silhouette provisoire
##    (CrystalMother_body) et chemin attendu (fauna.json) ; coefficients et seuils 70 / 35 % dans Balance ;
## 2. phase 1 : joueur dans 8 directions : éclat / stalactites / prisme face au joueur, impacts calés ;
##    stalactites : 6 cercles disjoints, le premier sur le joueur, chacun laisse un bloc ; les blocs
##    arrêtent les projectiles ennemis ; le prisme se divise en 2 lignes à ±30° sur un bloc ;
## 3. phase 2 sous 70 % : transition, cristaux de l'arène bus (RecluseGloom), blocs -> lampes (+15 % aux
##    monstres dedans, la Mère comprise) ; Reflet : ressort d'un bloc près du joueur ;
## 4. phase 3 sous 35 % : 8 éclats en orbite qui touchent, prisme en croix ;
## 5. mort pendant la charge : les blocs restent (trace), puis disparaissent avec la fin de la charge.
## Sauvegarde de test seulement (jamais user://run_save.json).

const MAP_CRYPTS := "res://scenes/stage/maps/cryptes_noyees.tscn"
const MAP_FALLBACK := "res://scenes/stage/maps/cite_rouille.tscn"
const SAVE := "user://test_crystal_mother_boss.json"
const DIST_PX := 300.0
const SLOT_S := 2.8
const P2_S := 15.0
const P3_S := 14.0
const TRACE_S := 2.0

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
var _all_kinds := {}
var _aim_n := 0
var _aim_bad := 0
var _sync_n := 0
var _sync_bad := 0
var _anims_seen := {}
var _stals_ok := true
var _stals_seen := 0
var _trans_checked := false
var _gloom: Node = null
var _has_art := false
var _mob: Enemy = null
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
	var map := MAP_CRYPTS if ResourceLoader.exists(MAP_CRYPTS) else MAP_FALLBACK
	print("  carte : ", map)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(map))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 43)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _brain() -> CrystalMotherBrain:
	return _boss.brain as CrystalMotherBrain if _boss != null and _boss.brain is CrystalMotherBrain else null


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
				RunState.stage = 4
				(_main.get(&"stage") as StageManager).floor_boss = &"crystal_mother"
				_spawn()
		1:
			var slot_s := 2.2 if _capture else SLOT_S
			_place(mini(int(_t / slot_s), 7), DIST_PX)
			_scan()
			_check_stals()
			if _t > slot_s * 8.0:
				_end_p1()
		2:
			_place(int(_t / 3.0) % 8, DIST_PX)
			_scan()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 2 sous 70 % (transition, boss figé)", _brain().phase == 2 and _brain().state == CrystalMotherBrain.S.STAGGER, "%d %d" % [_brain().phase, _brain().state])
				_check("phase 2 : cristaux de l'arène bus (RecluseGloom)", _brain().gloom() != null)
				_lamp_checks()
			if _t > P2_S:
				_end_p2()
		3:
			var r := CrystalMotherBrain.ORBIT_R_U * 64.0 if int(_t / 3.0) % 2 == 0 else DIST_PX
			_place(int(_t / 1.5) % 8, r)
			_scan()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 3 sous 35 %", _brain().phase == 3, str(_brain().phase))
			if _t > P3_S:
				_end_p3()
		4:
			_player().global_position = _pillar.global_position + Vector2(64.0, 0.0)
			if _t > TRACE_S:
				var g := _gloom as RecluseGloom
				_check("trace : les blocs restent après la mort (charge en cours)", is_instance_valid(g) and g.trace_count() >= 1, str(g.trace_count() if is_instance_valid(g) else -1))
				_pillar.charge = Pillar.CHARGE_TIME
				_next(5)
		5:
			if _t > 0.6:
				_check("pilier terminé (charge finie, boss mort)", _pillar.state == Pillar.STATE_DONE, str(_pillar.state))
				_check("trace dissipée avec la fin de la charge", not is_instance_valid(_gloom))
				_check("mort : nœuds de la Mère libérés", _leftovers().is_empty(), str(_leftovers()))
				_finish()


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
	_check("boss d'étage = crystal_mother", StringName(_boss.get(&"_boss_sprite_id")) == &"crystal_mother")
	_check("IA CrystalMotherBrain branchée", _boss.brain is CrystalMotherBrain)
	_check("chemin du sprite enregistré (fauna.json)", EnemyVisual.boss_path(&"crystal_mother") == "res://assets/sprites/bosses/etage/crystal_mother/crystal_mother.tres", EnemyVisual.boss_path(&"crystal_mother"))
	_has_art = bool(_boss.visual.get(&"_boss_sprite"))
	if _has_art:
		var sf: SpriteFrames = EnemyVisual.boss_frames(&"crystal_mother")
		var missing: Array = []
		for base in ["auto", "spell_a", "spell_b"]:
			for d in ["e", "s", "w", "n"]:
				if not sf.has_animation(StringName("%s_%s" % [base, d])):
					missing.append("%s_%s" % [base, d])
		_check("anims directionnelles de la Mère", missing.is_empty(), str(missing))
	else:
		_check("sans sprite : silhouette provisoire dessinée", _boss.get_node_or_null(^"CrystalMother_body") != null)
	_check("coefficients dans Balance", is_equal_approx(Balance.boss_attack_coef(&"crystal_mother", &"stalactites"), 1.3)
		and is_equal_approx(Balance.boss_attack_coef(&"crystal_mother", &"prism"), 2.0) and is_equal_approx(Balance.boss_attack_coef(&"crystal_mother", &"shard"), 1.0))
	_check("seuils 70 / 35 %", Balance.boss_phase(&"etage", &"crystal_mother", 0.71) == 1 and Balance.boss_phase(&"etage", &"crystal_mother", 0.69) == 2
		and Balance.boss_phase(&"etage", &"crystal_mother", 0.34) == 3)
	_check("phase 1 : ni orbite ni obscurité", _brain().orbit_count() == 0 and _brain().gloom() == null)
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_anchor = _boss.position
	# réfraction : un projectile ennemi posé sur un bloc est arrêté ; un prisme qui croise un bloc se divise
	var b := _brain()
	var bp := _anchor + Vector2(0.0, -3.0 * 64.0)
	b.add_block(bp)
	_director().fire_projectile(_boss, bp, Vector2.ZERO, 1.0)
	var paths: Array[Dictionary] = b._prism_paths(_anchor, -PI * 0.5)
	var ok := paths.size() == 3 and (paths[0]["len"] as float) <= 3.0 * 64.0 + 0.5 and absf(absf(angle_difference(paths[1]["angle"], -PI * 0.5)) - CrystalMotherBrain.PRISM_SPLIT) < 0.01
	_check("prisme : divisé en 2 lignes à ±30° sur un bloc", ok, str(paths))
	var straight: Array[Dictionary] = b._prism_paths(_anchor, PI * 0.5)
	_check("prisme : droit sans bloc", straight.size() == 1 and is_equal_approx(straight[0]["len"], CrystalMotherBrain.PRISM_LEN_U * 64.0))
	_next(1)


func _place(slot: int, r: float) -> void:
	var b := _brain()
	if b == null:
		return
	var p := _player()
	if p.hp < p.max_hp * 0.5:
		p.hp = p.max_hp
		p.set(&"_invuln", 0.0)
		p.clear_statuses()
	if slot != _slot and b.state == CrystalMotherBrain.S.CHASE and not _boss.visual.call(&"is_attacking"):
		_slot = slot
	var want := _boss.position + Vector2.from_angle(maxi(_slot, 0) * TAU / 8.0) * r
	if b.state == CrystalMotherBrain.S.CHASE and not _boss.visual.call(&"is_attacking"):
		want = _anchor + Vector2.from_angle(maxi(_slot, 0) * TAU / 8.0) * r
		if _step != 2: # P2 : elle peut rester sur un bloc (Reflet)
			_boss.position = _anchor
	else:
		return # le joueur ne bouge pas pendant un coup armé
	var d := _director()
	if d.nav != null:
		want = d.nav.resolve(want, 26.0)
	p.global_position = want


## Stalactites posées : 6 cercles disjoints, le premier sur le joueur.
func _check_stals() -> void:
	var b := _brain()
	var st: Array = b.get(&"_stals")
	if st.is_empty() or b.state != CrystalMotherBrain.S.STALACTITES or float(b.get(&"_t")) > 0.05:
		return
	_stals_seen += 1
	if st.size() < 4:
		_stals_ok = false
		print("  stalactites : %d cercles" % st.size())
	if (st[0] as Vector2).distance_to(_player().global_position) > 40.0:
		_stals_ok = false
		print("  stalactites : premier cercle à %.0f px du joueur" % (st[0] as Vector2).distance_to(_player().global_position))
	for i in st.size():
		for j in range(i + 1, st.size()):
			if (st[i] as Vector2).distance_to(st[j]) < 2.0 * CrystalMotherBrain.STAL_R_U * 64.0:
				_stals_ok = false
				print("  stalactites : %d-%d à %.0f px" % [i, j, (st[i] as Vector2).distance_to(st[j])])


func _lamp_checks() -> void:
	var b := _brain()
	_check("phase 2 : blocs devenus lampes", int(_kinds.get(&"lamp", 0)) >= 1 or b.block_count() == 0, str(_kinds))
	b.add_block(_boss.position)
	_check("lampe : la Mère dans sa lumière subit +15 %", is_equal_approx(b.damage_taken_mult(), Balance.CRYSTAL_LAMP_DAMAGE_TAKEN), str(b.damage_taken_mult()))
	var lp := _anchor + Vector2(-4.0 * 64.0, 4.0 * 64.0)
	b.add_block(lp)
	_mob = _director().spawn_enemy(1, lp + Vector2(30.0, 0.0))
	if _mob != null:
		_mob.max_hp = 1000.0
		_mob.hp = 1000.0
		b.refresh_lamp_mods() # relevé des monstres éclairés (sinon tous les LAMP_SCAN_S)
		_mob.take_damage(100.0)
		_check("lampe : un monstre dedans subit +15 %", absf(_mob.hp - (1000.0 - 115.0)) < 0.5 and b.lamp_bonus >= 1, "%.1f" % _mob.hp)
		_director().release_enemy(_mob)
	else:
		_check("monstre de test", false)


func _scan() -> void:
	var b := _brain()
	if b == null:
		return
	_anims_seen[String(_boss.visual.call(&"current_anim"))] = true
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
		if kind in [&"shard", &"stalactites", &"prism"] and ev.has("to") and _step == 1:
			var v: Vector2 = (ev["to"] as Vector2) - (ev["from"] as Vector2)
			var aim: Vector2 = ev["aim"]
			_aim_n += 1
			if absf(angle_difference(aim.angle(), v.angle())) > 0.3:
				_aim_bad += 1
				print("  %s : visée %.0f°, joueur à %.0f°" % [kind, rad_to_deg(aim.angle()), rad_to_deg(v.angle())])
			_octants[posmod(roundi(v.angle() / (TAU / 8.0)), 8)] = true


func _end_p1() -> void:
	_check("phase 1 : éclats", int(_kinds.get(&"shard", 0)) >= 2, str(_kinds))
	_check("phase 1 : stalactites", int(_kinds.get(&"stalactites", 0)) >= 1 and int(_kinds.get(&"stal_hit", 0)) >= 1, str(_kinds))
	_check("stalactites : 6 cercles disjoints, le premier sur le joueur", _stals_seen >= 1 and _stals_ok, "vus=%d" % _stals_seen)
	_check("stalactites : chaque cercle laisse un bloc", int(_kinds.get(&"block", 0)) >= 4, str(_kinds))
	_check("phase 1 : prisme", int(_kinds.get(&"prism", 0)) >= 1, str(_kinds))
	_check("blocs : projectile ennemi arrêté", int(_kinds.get(&"projectile_blocked", 0)) >= 1 or int(_kinds.get(&"shard_blocked", 0)) >= 1, str(_kinds))
	_check("phase 1 : ni lampes ni orbite", int(_kinds.get(&"lamp", 0)) == 0 and _brain().orbit_count() == 0, str(_kinds))
	_check("coups télégraphiés face au joueur", _aim_n >= 6 and _aim_bad == 0, "%d / %d" % [_aim_bad, _aim_n])
	_check("8 directions : au moins 6 octants visés", _octants.size() >= 6, str(_octants.keys()))
	_check("phase 1 : coups reçus par le joueur", _hits >= 3, str(_hits))
	_kinds = {}
	_boss.hp = _boss.max_hp * 0.68
	_boss.take_damage(1.0)
	_next(2)


func _end_p2() -> void:
	_check("phase 2 : Reflet (ressort d'un bloc)", int(_kinds.get(&"reflect", 0)) >= 1, str(_kinds))
	_check("phase 2 : les nouveaux blocs sont des lampes", int(_kinds.get(&"lamp", 0)) >= 2, str(_kinds))
	var g := _brain().gloom()
	if g != null:
		print("  pénombre : %d lumières de carte baissées" % g.dimmed)
	_kinds = {}
	_boss.hp = _boss.max_hp * 0.3
	_boss.take_damage(1.0)
	_next(3)


func _end_p3() -> void:
	var b := _brain()
	_check("phase 3 : 8 éclats en orbite", b.orbit_count() == CrystalMotherBrain.ORBIT_N, str(b.orbit_count()))
	_check("phase 3 : l'orbite touche", int(_kinds.get(&"orbit_hit", 0)) >= 1, str(_kinds))
	_check("phase 3 : prisme en croix", int(_kinds.get(&"prism_cross", 0)) >= 1, str(_kinds))
	_check("impacts calés (tous les coups)", _sync_n >= 10 and _sync_bad == 0, "%d / %d" % [_sync_bad, _sync_n])
	_check("coups reçus par le joueur (total)", _hits >= 6, str(_hits))
	print("  mère : %d coups reçus, %d impacts vérifiés, événements %s" % [_hits, _sync_n, str(_all_kinds)])
	_pillar.charge = 10.0
	_gloom = b.gloom()
	_boss.take_damage(_boss.hp + 1.0)
	_check("mère morte", not _boss.active)
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
			if String(n.name).begins_with("CrystalMother") and not n.is_queued_for_deletion():
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
			CrystalMotherBrain.S.STALACTITES:
				if t > 0.9:
					key = "stalactites"
			CrystalMotherBrain.S.PRISM:
				if t > 0.75:
					key = "prism"
			CrystalMotherBrain.S.REFLECT:
				if t > 0.6:
					key = "reflect"
			CrystalMotherBrain.S.SHARD:
				if t > float(b.get(&"_dur")) * 0.7:
					key = "shard"
			CrystalMotherBrain.S.STAGGER:
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
