extends Node
## Boss d'étage 3 : le Sonneur (SonneurBrain, sprites C7c) sur la carte cite_rouille.
## godot --headless --path game res://tests/sonneur_boss_test.tscn  -> RESULT: OK
## Capture : sans --headless, images clés en temps réel : `--resolution 1280x720 -- capture shots=<dossier absolu>`.
## Vérifie :
## 1. IA SonneurBrain branchée, anims directionnelles (auto/spell_a/spell_b e,s,w,n), coefficients Balance ;
## 2. phase 1 : joueur placé tour à tour dans 8 directions (45°) : marteau / glas / boulons télégraphiés face
##    au joueur (visée = direction du joueur, orientation du sprite cohérente), au moins 6 octants ; dégâts à
##    la frame d'impact (décalage < 0,05 s, frame visible = frame d'impact) ; anneau du glas qui touche au
##    passage du front ; boulons (6 cercles disjoints, un sur le joueur) ; ni foudre ni vapeur ;
## 3. phase 2 sous 66 % : trans_p2, _p2, paratonnerre allumé, éclairs toutes les 5 s (frame 0 = dégâts),
##    glas double (second anneau 1,5 s après le premier) ;
## 4. phase 3 sous 33 % : trans_p3, _p3, 4 jets de vapeur qui tournent et brûlent, vapeur sur la
##    chaudière, +25 % de dégâts reçus ;
## 5. mort pendant la charge : l'orage continue (SonneurStorm frappe), puis disparaît avec la fin de la charge ;
##    tous les nœuds du Sonneur libérés.
## Sauvegarde de test seulement (jamais user://run_save.json).

const MAP := "res://scenes/stage/maps/cite_rouille.tscn"
const SAVE := "user://test_sonneur_boss.json"
const DIST_PX := 170.0 ## ~2,7 u : à portée du marteau, dans l'anneau du glas
const SLOT_S := 2.8
const P2_S := 14.0
const P3_S := 14.0
const STORM_S := 6.0

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
var _dir4_bad := 0
var _sync_n := 0
var _sync_bad := 0
var _anims_seen := {}
var _glas_t: Array[float] = []
var _bolts_ok := true
var _bolts_seen := 0
var _angle0 := 0.0
var _trans_checked := false
var _storm: Node = null
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
	var map := MAP
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map="): # autre carte (diagnostic de lisibilité) : map=foret_brume
			map = "res://scenes/stage/maps/%s.tscn" % a.substr(4)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(map))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 37)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _brain() -> SonneurBrain:
	return _boss.brain as SonneurBrain if _boss != null and _boss.brain is SonneurBrain else null


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
				(_main.get(&"stage") as StageManager).floor_boss = &"sonneur"
				_spawn()
		1: # phase 1 : 8 directions
			var slot_s := 2.0 if _capture else SLOT_S
			_place(mini(int(_t / slot_s), 7))
			_scan()
			_check_bolts()
			if _t > slot_s * 8.0:
				_end_p1()
		2:
			_place(int(_t / 3.0) % 8)
			_scan()
			_check_bolts()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				var a := String(_boss.visual.call(&"current_anim"))
				_check("phase 2 sous 66 % (transition, boss figé)", _brain().phase == 2 and _brain().state == SonneurBrain.S.STAGGER, "%d %d" % [_brain().phase, _brain().state])
				_check("phase 2 : anim de transition trans_p2", a == "trans_p2_s", a)
			if _t > P2_S:
				_end_p2()
		3:
			_place(int(_t / 3.0) % 8)
			_scan()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				var a := String(_boss.visual.call(&"current_anim"))
				_check("phase 3 sous 33 %", _brain().phase == 3, str(_brain().phase))
				_check("phase 3 : anim de transition trans_p3", a == "trans_p3_s", a)
				_angle0 = _brain().steam_angle()
			if _t > P3_S:
				_end_p3()
		4: # après la mort : orage tant que la charge continue
			var p := _player()
			p.global_position = _pillar.global_position + Vector2(64.0, 0.0)
			if p.hp < p.max_hp * 0.5:
				p.hp = p.max_hp
			if _t > STORM_S:
				_check("orage : la foudre continue après la mort", is_instance_valid(_storm) and int(_storm.get(&"strikes")) >= 1,
					str(_storm.get(&"strikes")) if is_instance_valid(_storm) else "pas d'orage")
				_pillar.charge = Balance.PILLAR_CHARGE_S
				_next(5)
		5:
			if _t > 0.6:
				_check("pilier terminé (charge finie, boss mort)", _pillar.state == Pillar.STATE_DONE, str(_pillar.state))
				_check("orage dissipé avec la fin de la charge", not is_instance_valid(_storm))
				var left: Array = []
				for n in _director().get_node(^"Enemies").get_children():
					if String(n.name).begins_with("Sonneur"):
						left.append(String(n.name))
				_check("mort : nœuds du Sonneur libérés", left.is_empty(), str(left))
				_finish()


## Images clés : premier passage par un moment lisible dans chaque phase, et toutes les 4 s.
func _shoot_keys(delta: float) -> void:
	var b := _brain()
	_shot_t += delta
	var key := ""
	var ph := b.phase if b != null else 4
	if b != null:
		match b.state:
			SonneurBrain.S.GLAS_WIND:
				if float(b.get(&"_t")) > 0.7:
					key = "glas_wind"
			SonneurBrain.S.BOLTS:
				if float(b.get(&"_t")) > 0.8:
					key = "bolts_fall"
			SonneurBrain.S.HAMMER:
				if float(b.get(&"_t")) > float(b.get(&"_dur")) * 0.7:
					key = "hammer"
			SonneurBrain.S.STAGGER:
				if float(b.get(&"_t")) > 0.35:
					key = "trans"
		if b.wave_count() > 0 and key == "":
			var w: Dictionary = (b.get(&"_waves") as Array)[0]
			if float(w["t"]) > 0.3:
				key = "glas_wave"
		if b.strike_count() > 0 and key == "":
			var s: Dictionary = (b.get(&"_strikes") as Array)[0]
			if float(s["t"]) > 0.75:
				key = "lightning_tele"
		if key == "":
			for f: Dictionary in b.get(&"_fx"):
				if is_instance_valid(f["node"]) and String((f["node"] as Node).name).contains("lightning") and (f["node"] as AnimatedSprite2D).animation == &"lightning":
					key = "lightning_hit"
	elif is_instance_valid(_storm) and _storm.get(&"_pending"):
		key = "storm"
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
	_check("boss d'étage = sonneur", StringName(_boss.get(&"_boss_sprite_id")) == &"sonneur")
	_check("IA SonneurBrain branchée", _boss.brain is SonneurBrain)
	_check("sprite Blender (pas de placeholder)", bool(_boss.visual.get(&"_boss_sprite")))
	var sf: SpriteFrames = EnemyVisual.boss_frames(&"sonneur")
	var missing: Array = []
	for base in ["auto", "spell_a", "spell_b"]:
		for d in ["e", "s", "w", "n"]:
			if sf == null or not sf.has_animation(StringName("%s_%s" % [base, d])):
				missing.append("%s_%s" % [base, d])
	for x in ["bolt", "lightning", "ground_lightning", "ground_scorch", "steam_vent", "ground_steam"]:
		if sf == null or not sf.has_animation(StringName(x)):
			missing.append(x)
	_check("anims directionnelles et extras du sonneur (C7c)", missing.is_empty(), str(missing))
	_check("coefficients dans Balance (foudre 2,5 = le plus lourd)", is_equal_approx(Balance.boss_attack_coef(&"sonneur", &"lightning"), 2.5)
		and is_equal_approx(Balance.boss_attack_coef(&"sonneur", &"glas"), 1.5) and is_equal_approx(Balance.boss_attack_coef(&"cerf", &"charge"), 1.6))
	_check("phase 1 : pas de paratonnerre ni de vapeur", _brain().jet_count() == 0)
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_anchor = _boss.position
	_next(1)


## Joueur immobile dans la direction `slot` (×45°) autour du point d'ancrage, déplacé entre deux coups.
func _place(slot: int) -> void:
	var b := _brain()
	if b == null:
		return
	if slot != _slot and b.state == SonneurBrain.S.CHASE and not _boss.visual.call(&"is_attacking"):
		_slot = slot
	if b.state == SonneurBrain.S.CHASE and not _boss.visual.call(&"is_attacking") and _boss.position.distance_to(_anchor) > 40.0:
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


## Boulons en vol : 6 cercles disjoints (écart >= 0,5 u), l'un sur le joueur.
func _check_bolts() -> void:
	var b := _brain()
	var bolts: Array = b.get(&"_bolts")
	if bolts.is_empty() or float(b.get(&"_t")) > 0.05:
		return
	_bolts_seen += 1
	if bolts.size() < 5:
		_bolts_ok = false
	var on_player := false
	for i in bolts.size():
		var pi: Vector2 = bolts[i]["pos"]
		if pi.distance_to(_player().global_position) < 40.0:
			on_player = true
		for j in range(i + 1, bolts.size()):
			if pi.distance_to(bolts[j]["pos"]) < (2.0 * SonneurBrain.BOLT_R_U + SonneurBrain.BOLT_GAP_U) * 64.0 - 0.5:
				_bolts_ok = false
	if not on_player:
		_bolts_ok = false


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
		if kind == &"phase":
			continue
		if kind == &"glas":
			_glas_t.append(_t)
		if int(ev.get("expect", -1)) >= 0:
			_sync_n += 1
			var f := int(ev["frame"])
			var k := int(ev["expect"])
			var lag := float(ev.get("lag", 0.0))
			if f < k - 1 or f > k or lag < -0.001 or lag > 0.05:
				_sync_bad += 1
				print("  %s : %s frame %d (attendu %d), décalage %.3f s" % [kind, ev["anim"], f, k, lag])
		if kind in [&"hammer", &"glas", &"bolts"] and ev.has("to"):
			var v: Vector2 = (ev["to"] as Vector2) - (ev["from"] as Vector2)
			var aim: Vector2 = ev["aim"]
			if kind == &"hammer" or _step == 1:
				_aim_n += 1
				if absf(angle_difference(aim.angle(), v.angle())) > 0.3:
					_aim_bad += 1
					print("  %s : visée %.0f°, joueur à %.0f°" % [kind, rad_to_deg(aim.angle()), rad_to_deg(v.angle())])
				_octants[posmod(roundi(v.angle() / (TAU / 8.0)), 8)] = true
			var exp4 := (0 if aim.x >= 0.0 else 2) if absf(aim.x) >= absf(aim.y) else (1 if aim.y > 0.0 else 3)
			var diag := absf(absf(aim.x) - absf(aim.y)) < 0.15
			if int(ev["dir4"]) != exp4 and not diag:
				_dir4_bad += 1
			var an := String(ev["anim"])
			if not diag and not an.ends_with("_" + EnemyVisual.BOSS_DIRS4[exp4]):
				_dir4_bad += 1
				print("  %s : anim %s pour une visée %s" % [kind, an, EnemyVisual.BOSS_DIRS4[exp4]])


func _end_p1() -> void:
	_check("phase 1 : marteau", int(_kinds.get(&"hammer", 0)) >= 2, str(_kinds))
	_check("phase 1 : glas", int(_kinds.get(&"glas", 0)) >= 1, str(_kinds))
	_check("phase 1 : l'anneau du glas touche au passage du front", int(_kinds.get(&"glas_hit", 0)) >= 1, str(_kinds))
	_check("phase 1 : pluie de boulons", int(_kinds.get(&"bolts", 0)) >= 1, str(_kinds))
	_check("boulons : cercles disjoints, un sur le joueur", _bolts_seen >= 1 and _bolts_ok, "vus=%d" % _bolts_seen)
	_check("phase 1 : ni foudre ni vapeur", int(_kinds.get(&"lightning", 0)) == 0 and int(_kinds.get(&"steam", 0)) == 0, str(_kinds))
	_check("coups télégraphiés face au joueur", _aim_n >= 6 and _aim_bad == 0, "%d / %d" % [_aim_bad, _aim_n])
	_check("8 directions : au moins 6 octants visés", _octants.size() >= 6, str(_octants.keys()))
	_check("orientation du sprite = visée (4 côtés)", _dir4_bad == 0, str(_dir4_bad))
	_check("phase 1 : anims _p1", _has_prefix_p(1), str(_anims_seen.keys()))
	_check("phase 1 : coups reçus par le joueur", _hits >= 3, str(_hits))
	_kinds = {}
	_anims_seen = {}
	_glas_t.clear()
	_boss.hp = _boss.max_hp * 0.62
	_boss.take_damage(1.0)
	_next(2)


func _end_p2() -> void:
	var rod: LightRig.Handle = _brain().get(&"_rod")
	_check("phase 2 : paratonnerre allumé", rod != null and rod.enabled)
	_check("phase 2 : éclairs toutes les 5 s", int(_kinds.get(&"lightning", 0)) >= 2, str(_kinds))
	var echo := false
	for i in range(1, _glas_t.size()):
		if absf(_glas_t[i] - _glas_t[i - 1] - SonneurBrain.GLAS_ECHO_S) < 0.1:
			echo = true
	_check("phase 2 : glas double (second anneau 1,5 s après)", echo, str(_glas_t))
	_check("phase 2 : anims _p2", _has_prefix_p(2), str(_anims_seen.keys()))
	_kinds = {}
	_anims_seen = {}
	_boss.hp = _boss.max_hp * 0.3
	_boss.take_damage(1.0)
	_next(3)


func _end_p3() -> void:
	var b := _brain()
	_check("phase 3 : 4 jets de vapeur", b.jet_count() == 4, str(b.jet_count()))
	_check("phase 3 : les jets tournent", absf(angle_difference(b.steam_angle(), _angle0)) > 0.5, "%.2f -> %.2f" % [_angle0, b.steam_angle()])
	_check("phase 3 : la vapeur brûle", int(_kinds.get(&"steam", 0)) >= 1, str(_kinds))
	_check("phase 3 : vapeur sur la chaudière", _boss.visual.get_node_or_null(^"SonneurPlume") != null)
	_check("phase 3 : anims _p3", _has_prefix_p(3), str(_anims_seen.keys()))
	var hp0 := _boss.hp
	_boss.take_damage(100.0)
	_check("phase 3 : +25 % de dégâts reçus", is_equal_approx(hp0 - _boss.hp, 125.0), "%.1f" % (hp0 - _boss.hp))
	_check("dégâts à la frame d'impact (tous les coups)", _sync_n >= 10 and _sync_bad == 0, "%d / %d" % [_sync_bad, _sync_n])
	_check("coups reçus par le joueur (total)", _hits >= 6, str(_hits))
	print("  sonneur : %d coups reçus, %d impacts vérifiés, octants %s" % [_hits, _sync_n, str(_octants.keys())])
	_pillar.charge = 10.0 # charge en cours : l'orage doit rester
	_boss.take_damage(_boss.hp + 1.0)
	_check("sonneur mort", not _boss.active)
	_check("mort : IA libérée", _boss.brain == null)
	_storm = _director().get_node(^"Enemies").get_node_or_null(^"SonneurStorm")
	_check("mort pendant la charge : orage laissé", _storm != null)
	_next(4)


func _has_prefix_p(p: int) -> bool:
	for a in _anims_seen:
		if String(a).begins_with("idle_p%d" % p) or String(a).begins_with("walk_p%d" % p):
			return true
	return false


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
