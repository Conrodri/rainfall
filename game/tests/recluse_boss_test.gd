extends Node
## Boss d'étage 4 : le Reclus (RecluseBrain) ; carte des Cryptes si livrée, sinon cite_rouille.
## godot --headless --path game res://tests/recluse_boss_test.tscn  -> RESULT: OK
## Capture : sans --headless, images clés en temps réel : `--resolution 1280x720 -- capture shots=<dossier absolu>`.
## Vérifie :
## 1. IA RecluseBrain branchée ; sprites : anims directionnelles si le .tres est livré, sinon silhouette
##    provisoire (Recluse_body) et chemin attendu enregistré dans data/fauna.json ; coefficients Balance ;
## 2. phase 1 : joueur dans 8 directions : bâton / cloche / prières face au joueur (au moins 6 octants), dégâts
##    à l'impact (décalage < 0,05 s ; frame d'impact si sprite) ; l'anneau de la cloche touche au passage du
##    front et coupe les sorts 2-4 au moins 2 s ; prières : cercles disjoints (≥ 0,5 u), le premier sur le
##    joueur, allumés en spirale ; ni rayons ni obscurité ;
## 3. phase 2 sous 66 % : transition (boss figé), obscurité (RecluseGloom), cloche double ;
## 4. phase 3 sous 33 % : immobile, 4 rayons qui tournent et brûlent, alerte puis inversion du sens ;
## 5. mort pendant la charge : l'obscurité reste, puis se dissipe avec la fin de la charge ; nœuds libérés.
## Sauvegarde de test seulement (jamais user://run_save.json).

const MAP_CRYPTS := "res://scenes/stage/maps/cryptes_noyees.tscn"
const MAP_FALLBACK := "res://scenes/stage/maps/cite_rouille.tscn"
const SAVE := "user://test_recluse_boss.json"
const DIST_PX := 170.0
const SLOT_S := 2.8
const P2_S := 14.0
const P3_S := 15.0
const GLOOM_S := 2.0

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
var _bell_t: Array[float] = []
var _prayers_ok := true
var _prayers_seen := 0
var _silence_ok := 0
var _silence_bad := 0
var _angle0 := 0.0
## Rotation cumulée des rayons (somme des |pas| d'une image à l'autre) : l'écart net début/fin dépend de
## l'instant d'échantillonnage (les rayons repartent en arrière après chaque inversion), pas le cumul.
var _ray_travel := 0.0
var _ray_prev := 0.0
var _ray_seen := false
var _rev0 := 0
var _dir0 := 1.0
var _trans_checked := false
var _gloom: Node = null
var _has_art := false
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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map="):
			map = "res://scenes/stage/maps/%s.tscn" % a.substr(4)
	print("  carte : ", map)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(map))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 41)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _brain() -> RecluseBrain:
	return _boss.brain as RecluseBrain if _boss != null and _boss.brain is RecluseBrain else null


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
				(_main.get(&"stage") as StageManager).floor_boss = &"recluse"
				_spawn()
		1:
			var slot_s := 2.0 if _capture else SLOT_S
			_place(mini(int(_t / slot_s), 7))
			_scan()
			_check_prayers()
			if _t > slot_s * 8.0:
				_end_p1()
		2:
			_place(int(_t / 3.0) % 8)
			_scan()
			_check_prayers()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 2 sous 66 % (transition, boss figé)", _brain().phase == 2 and _brain().state == RecluseBrain.S.STAGGER, "%d %d" % [_brain().phase, _brain().state])
				if _has_art:
					var a := String(_boss.visual.call(&"current_anim"))
					_check("phase 2 : anim de transition trans_p2", a == "trans_p2_s", a)
			if _t > P2_S:
				_end_p2()
		3:
			_place(int(_t / 3.0) % 8)
			_scan()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				_check("phase 3 sous 33 %", _brain().phase == 3, str(_brain().phase))
				_anchor = _boss.position
			if _brain().ray_count() > 0:
				var ra := _brain().ray_angle()
				if not _ray_seen:
					_ray_seen = true
					_angle0 = ra
					_dir0 = _brain().ray_dir
				else:
					_ray_travel += absf(angle_difference(_ray_prev, ra))
				_ray_prev = ra
			if _t > P3_S:
				_end_p3()
		4: # après la mort : obscurité tant que la charge continue
			var p := _player()
			p.global_position = _pillar.global_position + Vector2(64.0, 0.0)
			if _t > GLOOM_S:
				_check("trace : l'obscurité reste après la mort (charge en cours)", is_instance_valid(_gloom) and not bool(_gloom.get(&"boss_alive")))
				_pillar.charge = Balance.PILLAR_CHARGE_S
				_next(5)
		5:
			if _t > 0.6:
				_check("pilier terminé (charge finie, boss mort)", _pillar.state == Pillar.STATE_DONE, str(_pillar.state))
				_check("obscurité dissipée avec la fin de la charge", not is_instance_valid(_gloom))
				_check("mort : nœuds du Reclus libérés", _leftovers().is_empty(), str(_leftovers()))
				_finish()


func _leftovers() -> Array:
	var left: Array = []
	var roots: Array[Node] = [_director().get_node(^"Enemies")]
	var layer := AmbianceManager.telegraph_layer(get_tree())
	if layer != null:
		roots.append(layer)
	for r in roots:
		for n in r.get_children():
			if String(n.name).begins_with("Recluse") and not n.is_queued_for_deletion():
				left.append(String(n.name))
	return left


func _shoot_keys(delta: float) -> void:
	var b := _brain()
	_shot_t += delta
	var key := ""
	var ph := b.phase if b != null else 4
	if b != null:
		match b.state:
			RecluseBrain.S.BELL_WIND:
				if float(b.get(&"_t")) > 0.7:
					key = "bell_wind"
			RecluseBrain.S.PRAYERS:
				if float(b.get(&"_t")) > 0.9:
					key = "prayers"
			RecluseBrain.S.STAFF:
				if float(b.get(&"_t")) > float(b.get(&"_dur")) * 0.7:
					key = "staff"
			RecluseBrain.S.STAGGER:
				if float(b.get(&"_t")) > 0.4:
					key = "trans"
		if b.wave_count() > 0 and key == "":
			var w: Dictionary = (b.get(&"_waves") as Array)[0]
			if float(w["t"]) > 0.35:
				key = "bell_wave"
		if key == "" and b.ray_count() > 0 and bool(b.get(&"_ray_warned")):
			key = "ray_warn"
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
	_check("boss d'étage = recluse", StringName(_boss.get(&"_boss_sprite_id")) == &"recluse")
	_check("IA RecluseBrain branchée", _boss.brain is RecluseBrain)
	_check("chemin du sprite enregistré (fauna.json)", EnemyVisual.boss_path(&"recluse") == "res://assets/sprites/bosses/etage/recluse/recluse.tres", EnemyVisual.boss_path(&"recluse"))
	_has_art = bool(_boss.visual.get(&"_boss_sprite"))
	if _has_art:
		var sf: SpriteFrames = EnemyVisual.boss_frames(&"recluse")
		var missing: Array = []
		for base in ["auto", "spell_a", "spell_b"]:
			for d in ["e", "s", "w", "n"]:
				if not sf.has_animation(StringName("%s_%s" % [base, d])):
					missing.append("%s_%s" % [base, d])
		_check("anims directionnelles du reclus", missing.is_empty(), str(missing))
	else:
		_check("sans sprite : silhouette provisoire dessinée", _boss.get_node_or_null(^"Recluse_body") != null)
	_check("coefficients dans Balance", is_equal_approx(Balance.boss_attack_coef(&"recluse", &"bell"), 1.5)
		and is_equal_approx(Balance.boss_attack_coef(&"recluse", &"prayers"), 1.3) and is_equal_approx(Balance.boss_attack_coef(&"recluse", &"rays"), 0.45))
	_check("phase 1 : ni rayons ni obscurité", _brain().ray_count() == 0 and _brain().gloom() == null)
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_anchor = _boss.position
	_next(1)


func _place(slot: int) -> void:
	var b := _brain()
	if b == null:
		return
	if slot != _slot and b.state == RecluseBrain.S.CHASE and not _boss.visual.call(&"is_attacking"):
		_slot = slot
	if b.state == RecluseBrain.S.CHASE and not _boss.visual.call(&"is_attacking") and _boss.position.distance_to(_anchor) > 40.0:
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


## Prières posées : cercles disjoints (≥ 0,5 u), le premier sur le joueur.
func _check_prayers() -> void:
	var b := _brain()
	var pr: Array = b.get(&"_prayers")
	if pr.is_empty() or b.state != RecluseBrain.S.PRAYERS or float(b.get(&"_t")) > 0.05:
		return
	_prayers_seen += 1
	if pr.size() < 4:
		_prayers_ok = false
	if (pr[0]["pos"] as Vector2).distance_to(_player().global_position) > 40.0:
		_prayers_ok = false
	for i in pr.size():
		for j in range(i + 1, pr.size()):
			if (pr[i]["pos"] as Vector2).distance_to(pr[j]["pos"]) < (2.0 * RecluseBrain.PRAYER_R_U + RecluseBrain.PRAYER_GAP_U) * 64.0 - 0.5:
				_prayers_ok = false
		if i > 0 and float(pr[i]["t0"]) >= float(pr[i - 1]["t0"]): # spirale : allumés l'un après l'autre
			_prayers_ok = false


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
		if kind == &"bell":
			_bell_t.append(_t)
		if kind == &"silence":
			var worst := 99.0
			for c in _player().get_spell_cooldowns():
				if not c["auto"]:
					worst = minf(worst, float(c["remaining"]))
			if worst >= RecluseBrain.SILENCE_S - 0.05:
				_silence_ok += 1
			else:
				_silence_bad += 1
				print("  silence : recharge restante %.2f s" % worst)
		if ev.has("lag") and ev.has("to"):
			_sync_n += 1
			var f := int(ev["frame"])
			var k := int(ev["expect"])
			var lag := float(ev["lag"])
			if lag < -0.001 or lag > 0.05 or (k >= 0 and (f < k - 1 or f > k)):
				_sync_bad += 1
				print("  %s : %s frame %d (attendu %d), décalage %.3f s" % [kind, ev["anim"], f, k, lag])
		if kind in [&"staff", &"bell", &"prayers"] and ev.has("to"):
			var v: Vector2 = (ev["to"] as Vector2) - (ev["from"] as Vector2)
			var aim: Vector2 = ev["aim"]
			if kind == &"staff" or _step == 1:
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
			if _has_art and not diag and not an.ends_with("_" + EnemyVisual.BOSS_DIRS4[exp4]):
				_dir4_bad += 1
				print("  %s : anim %s pour une visée %s" % [kind, an, EnemyVisual.BOSS_DIRS4[exp4]])


func _end_p1() -> void:
	_check("phase 1 : bâton", int(_kinds.get(&"staff", 0)) >= 2, str(_kinds))
	_check("phase 1 : cloche", int(_kinds.get(&"bell", 0)) >= 1, str(_kinds))
	_check("phase 1 : l'anneau de la cloche touche au passage du front", int(_kinds.get(&"bell_hit", 0)) >= 1, str(_kinds))
	_check("cloche : silence (sorts 2-4 coupés ≥ 2 s)", _silence_ok >= 1 and _silence_bad == 0, "ok=%d bad=%d" % [_silence_ok, _silence_bad])
	_check("phase 1 : prières", int(_kinds.get(&"prayers", 0)) >= 1 and int(_kinds.get(&"prayer_hit", 0)) >= 1, str(_kinds))
	_check("prières : spirale de cercles disjoints, le premier sur le joueur", _prayers_seen >= 1 and _prayers_ok, "vus=%d" % _prayers_seen)
	_check("phase 1 : ni rayons ni obscurité", int(_kinds.get(&"ray", 0)) == 0 and _brain().gloom() == null, str(_kinds))
	_check("coups télégraphiés face au joueur", _aim_n >= 6 and _aim_bad == 0, "%d / %d" % [_aim_bad, _aim_n])
	_check("8 directions : au moins 6 octants visés", _octants.size() >= 6, str(_octants.keys()))
	_check("orientation du boss = visée (4 côtés)", _dir4_bad == 0, str(_dir4_bad))
	if _has_art:
		_check("phase 1 : anims _p1", _has_prefix_p(1), str(_anims_seen.keys()))
	_check("phase 1 : coups reçus par le joueur", _hits >= 3, str(_hits))
	_kinds = {}
	_anims_seen = {}
	_bell_t.clear()
	_boss.hp = _boss.max_hp * 0.62
	_boss.take_damage(1.0)
	_next(2)


func _end_p2() -> void:
	var g := _brain().gloom()
	_check("phase 2 : obscurité (cristaux de l'arène éteints)", g != null, "")
	if g != null:
		print("  obscurité : %d lumières de carte baissées" % g.dimmed)
	var echo := false
	for i in range(1, _bell_t.size()):
		if absf(_bell_t[i] - _bell_t[i - 1] - RecluseBrain.BELL_ECHO_S) < 0.1:
			echo = true
	_check("phase 2 : cloche double", echo, str(_bell_t))
	if _has_art:
		_check("phase 2 : anims _p2", _has_prefix_p(2), str(_anims_seen.keys()))
	_kinds = {}
	_anims_seen = {}
	_boss.hp = _boss.max_hp * 0.3
	_boss.take_damage(1.0)
	_next(3)


func _end_p3() -> void:
	var b := _brain()
	_check("phase 3 : immobile (lévite)", _boss.position.distance_to(_anchor) < 4.0, "%.1f px" % _boss.position.distance_to(_anchor))
	_check("phase 3 : 4 rayons", b.ray_count() == 4, str(b.ray_count()))
	_check("phase 3 : les rayons tournent (>= 3 s à 20°/s)", _ray_travel >= RecluseBrain.RAY_TURN * 3.0, "%.2f rad parcourus (%.2f -> %.2f)" % [_ray_travel, _angle0, b.ray_angle()])
	_check("phase 3 : les rayons brûlent", int(_kinds.get(&"ray", 0)) >= 1, str(_kinds))
	_check("phase 3 : alerte puis inversion du sens", int(_kinds.get(&"ray_warn", 0)) >= 1 and b.reversals >= 1 and b.ray_dir != _dir0 or b.reversals >= 2, "rev=%d" % b.reversals)
	if _has_art:
		_check("phase 3 : anims _p3", _has_prefix_p(3), str(_anims_seen.keys()))
	_check("impacts calés (tous les coups)", _sync_n >= 10 and _sync_bad == 0, "%d / %d" % [_sync_bad, _sync_n])
	_check("coups reçus par le joueur (total)", _hits >= 6, str(_hits))
	print("  reclus : %d coups reçus, %d impacts vérifiés, %d silences, octants %s" % [_hits, _sync_n, _silence_ok, str(_octants.keys())])
	_pillar.charge = 10.0
	_gloom = b.gloom()
	_boss.take_damage(_boss.hp + 1.0)
	_check("reclus mort", not _boss.active)
	_check("mort : IA libérée", _boss.brain == null)
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
