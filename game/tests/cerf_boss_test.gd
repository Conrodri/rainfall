extends Node
## Boss d'étage 2 : le Cerf-Lanterne (CerfBrain, sprites C7b) sur la carte foret_brume.
## godot --headless --path game res://tests/cerf_boss_test.tscn  -> RESULT: OK
## Capture : sans --headless, `--write-movie <dossier>/cerf.png --fixed-fps 30 --resolution 1280x720 -- capture`,
## ou images clés en temps réel (bien plus rapide) : `--resolution 1280x720 -- capture shots=<dossier absolu>`.
## Vérifie :
## 1. IA CerfBrain branchée, lumière menthe, anims directionnelles (auto/spell_a/spell_b e,s,w,n) ;
## 2. phase 1 : joueur placé tour à tour dans 8 directions (45°) : coups de bois / tirs / charges et
##    lanternes télégraphiés face au joueur (visée = direction du joueur, orientation du sprite cohérente),
##    au moins 6 octants couverts ; dégâts à la frame d'impact (décalage du coup armé < 0,05 s, frame
##    visible = frame d'impact attendue) ; feux follets lâchés puis explosés (wisp_explode frame 2) ;
## 3. phase 2 sous 66 % : anim trans_p2, variantes _p2, brume au sol, couronne de follets, charges enchaînées ;
## 4. phase 3 sous 33 % : trans_p3, _p3, bond spectral (vanish -> reappear, dégâts à la frame 4) ;
## 5. coups reçus par le joueur ; mort : follets, traînées et brume libérés.
## Sauvegarde de test seulement (jamais user://run_save.json).

const MAP := "res://scenes/stage/maps/foret_brume.tscn"
const SAVE := "user://test_cerf_boss.json"
const DIST_PX := 250.0 ## ~3,9 u : hors du coup de bois, à portée du tir, de la charge et des follets
const SLOT_S := 2.6 ## secondes par direction (8 directions en phase 1)
const P2_S := 13.0
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
var _octants := {}
var _kinds := {}
var _auto_n := 0
var _auto_skin := 0 ## tirs habillés du follet wisp_bolt (C7D)
var _charge_anim := false ## ruée jouée avec charge_<dir> (C7D)
var _antlers_lit := false ## calque antlers_charge_<dir> visible pendant l'armement (C7D)
var _aim_n := 0
var _aim_bad := 0
var _dir4_bad := 0
var _sync_n := 0
var _sync_bad := 0
var _anims_seen := {}
var _chain := 0
var _last_charge_t := -10.0
var _burst_ok := false
var _trans_checked := false
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
	_main.set(&"run_seed", 31)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _brain() -> CerfBrain:
	return _boss.brain if _boss != null else null


func _physics_process(delta: float) -> void:
	if _step < 0 or _step == 99:
		return
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	_t += delta
	if _shots_dir != "" and _step in [1, 2, 3]:
		_shoot_keys(delta)
	match _step:
		0:
			_director().spawning_enabled = false
			if _t > 1.6:
				for e in get_tree().get_nodes_in_group(&"enemies").duplicate():
					if e is Enemy and not e.is_boss:
						_director().release_enemy(e)
				RunState.stage = 2
				(_main.get(&"stage") as StageManager).floor_boss = &"cerf_lanterne"
				_spawn()
		1: # phase 1 : 8 directions
			# même durée en capture qu'en headless : les comptes de la phase 1 (charges, 6 octants) supposent
			# 8 × SLOT_S s de combat (un combat raccourci à 8 × 1,5 s faisait échouer 2 vérifications en capture)
			var slot := mini(int(_t / SLOT_S), 7)
			_place(slot)
			_scan()
			if _t > SLOT_S * 8.0:
				_end_p1()
		2: # phase 2
			_place(int(_t / 3.0) % 8)
			_scan()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				var a := String(_boss.visual.call(&"current_anim"))
				_check("phase 2 sous 66 % (transition, boss figé)", _brain().phase == 2 and _brain().state == CerfBrain.S.STAGGER, "%d %d" % [_brain().phase, _brain().state])
				_check("phase 2 : anim de transition trans_p2", a == "trans_p2_s", a)
			if not _burst_ok and _brain().wisp_count() >= CerfBrain.WISP_BURST[1] and _brain().state != CerfBrain.S.STAGGER:
				_burst_ok = true
			if _t > P2_S:
				_end_p2()
		3: # phase 3
			_place(int(_t / 3.0) % 8)
			_scan()
			if not _trans_checked and _t > 0.2:
				_trans_checked = true
				var a := String(_boss.visual.call(&"current_anim"))
				_check("phase 3 sous 33 %", _brain().phase == 3, str(_brain().phase))
				_check("phase 3 : anim de transition trans_p3", a == "trans_p3_s", a)
			if _t > P3_S:
				_end_p3()
		4: # après la mort : nœuds libérés
			if _t > 0.3:
				var left := 0
				for n in _director().get_node(^"Enemies").get_children():
					if String(n.name).begins_with("CerfWisp") or String(n.name).begins_with("CerfTrail"):
						left += 1
				_check("mort : follets et traînées libérés", left == 0, str(left))
				_finish()


## Images clés : à chaque premier passage par un moment lisible (armement de charge, follets armés,
## transition, disparition, ruée) dans chaque phase, et toutes les 4 s.
func _shoot_keys(delta: float) -> void:
	var b := _brain()
	if b == null:
		return
	_shot_t += delta
	var key := ""
	match b.state:
		CerfBrain.S.CHARGE_WIND:
			if float(b.get(&"_t")) > float(b.get(&"_dur")) * 0.75:
				key = "charge_wind"
		CerfBrain.S.CHARGE_DASH:
			key = "charge_dash"
		CerfBrain.S.STAGGER:
			if float(b.get(&"_t")) > 0.3:
				key = "trans"
		CerfBrain.S.VANISH:
			if float(b.get(&"_t")) > 0.4:
				key = "vanish"
		CerfBrain.S.REAPPEAR:
			key = "reappear"
		CerfBrain.S.GORE:
			key = "gore"
	for w in b.get(&"_wisps"):
		if int(w["state"]) == 1:
			key = "wisps_armed"
	var name := ""
	if key != "" and not _shot_seen.has("%d_%s" % [b.phase, key]):
		_shot_seen["%d_%s" % [b.phase, key]] = true
		name = "p%d_%s" % [b.phase, key]
	elif _shot_t > 4.0:
		name = "p%d_t%02d" % [b.phase, int(_t)]
	if name == "":
		return
	_shot_t = 0.0
	_shot_n += 1
	var img := get_viewport().get_texture().get_image()
	if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false): # texture HDR 2D linéaire -> sRGB
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
	_check("boss d'étage = cerf", StringName(_boss.get(&"_boss_sprite_id")) == &"cerf")
	_check("IA CerfBrain branchée", _boss.brain is CerfBrain)
	var sf: SpriteFrames = EnemyVisual.boss_frames(&"cerf")
	var missing: Array = []
	for base in ["auto", "spell_a", "spell_b"]:
		for d in ["e", "s", "w", "n"]:
			if sf == null or not sf.has_animation(StringName("%s_%s" % [base, d])):
				missing.append("%s_%s" % [base, d])
	_check("anims directionnelles du cerf (C7b)", missing.is_empty(), str(missing))
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_anchor = _boss.position
	_next(1)


## Joueur immobile dans la direction `slot` (×45°) autour du point d'ancrage ; le boss y est ramené
## entre ses coups (une ruée l'emmène loin).
func _place(slot: int) -> void:
	var b := _brain()
	if b == null:
		return
	# le joueur ne change de place qu'entre deux coups (la visée se fige pendant le télégraphe)
	if slot != _slot and b.state == CerfBrain.S.CHASE and not _boss.visual.call(&"is_attacking"):
		_slot = slot
	if b.state == CerfBrain.S.CHASE and not _boss.visual.call(&"is_attacking") and _boss.position.distance_to(_anchor) > 40.0:
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


## Lit les nouveaux événements du journal de l'IA.
func _scan() -> void:
	var b := _brain()
	if b == null:
		return
	var a := String(_boss.visual.call(&"current_anim"))
	_anims_seen[a] = true
	if b.state == CerfBrain.S.CHARGE_DASH and a.begins_with("charge_"):
		_charge_anim = true
	if b.state == CerfBrain.S.CHARGE_WIND and is_instance_valid(b.get(&"_antlers")) and (b.get(&"_antlers") as CanvasItem).visible:
		_antlers_lit = true
	while _ev_i < b.events.size():
		var ev: Dictionary = b.events[_ev_i]
		_ev_i += 1
		var kind := StringName(ev["kind"])
		_kinds[kind] = int(_kinds.get(kind, 0)) + 1
		if kind == &"auto":
			_auto_n += 1
			if get_tree().root.find_child("CerfWispBolt", true, false) != null:
				_auto_skin += 1
		if kind == &"phase":
			continue
		# dégâts à la frame d'impact
		if int(ev.get("expect", -1)) >= 0:
			_sync_n += 1
			var f := int(ev["frame"])
			var k := int(ev["expect"])
			var lag := float(ev.get("lag", 0.0))
			if f < k - 1 or f > k or lag < -0.001 or lag > 0.05:
				_sync_bad += 1
				print("  %s : %s frame %d (attendu %d), décalage %.3f s" % [kind, ev["anim"], f, k, lag])
		if kind == &"charge":
			if _t - _last_charge_t < 2.2:
				_chain += 1
			_last_charge_t = _t
		# visée face au joueur
		if kind in [&"charge", &"gore", &"auto", &"wisps"]:
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
			var an := String(ev["anim"])
			if not diag and kind != &"wisps" and not an.ends_with("_" + EnemyVisual.BOSS_DIRS4[exp4]):
				_dir4_bad += 1
				print("  %s : anim %s pour une visée %s" % [kind, an, EnemyVisual.BOSS_DIRS4[exp4]])


func _end_p1() -> void:
	_check("phase 1 : charges lumineuses", int(_kinds.get(&"charge", 0)) >= 2, str(_kinds))
	_check("phase 1 : lanternes (follets lâchés)", int(_kinds.get(&"wisps", 0)) >= 1, str(_kinds))
	_check("phase 1 : follets explosés", int(_kinds.get(&"wisp_boom", 0)) >= 2, str(_kinds))
	_check("phase 1 : tirs ou coups de bois", int(_kinds.get(&"auto", 0)) + int(_kinds.get(&"gore", 0)) >= 2, str(_kinds))
	_check("C7D : ruée jouée avec charge_<dir>", _charge_anim, str(_anims_seen.keys()))
	_check("C7D : lanternes antlers_charge allumées pendant l'armement", _antlers_lit)
	print("  cerf P1 : %d tirs de follet, %d habillés wisp_bolt" % [_auto_n, _auto_skin])
	_check("C7D : tirs habillés du follet wisp_bolt", _auto_n == 0 or _auto_skin == _auto_n, "%d/%d" % [_auto_skin, _auto_n])
	_check("coups télégraphés face au joueur", _aim_n >= 6 and _aim_bad == 0, "%d / %d" % [_aim_bad, _aim_n])
	_check("8 directions : au moins 6 octants visés", _octants.size() >= 6, str(_octants.keys()))
	_check("orientation du sprite = visée (4 côtés)", _dir4_bad == 0, str(_dir4_bad))
	_check("phase 1 : anims _p1", _anims_seen.has("idle_p1_s") or _anims_seen.has("walk_p1_e") or _anims_seen.has("walk_p1_w") or _anims_seen.has("walk_p1_n") or _anims_seen.has("walk_p1_s"), str(_anims_seen.keys()))
	_check("phase 1 : pas de brume au sol", _boss.visual.get_node_or_null(^"CerfMist") == null or not (_boss.visual.get_node(^"CerfMist") as CanvasItem).visible)
	_check("phase 1 : coups reçus par le joueur", _hits >= 3, str(_hits))
	# --- phase 2
	_kinds = {}
	_anims_seen = {}
	_chain = 0
	_boss.hp = _boss.max_hp * 0.62
	_boss.take_damage(1.0)
	_next(2)


func _end_p2() -> void:
	var mist := _boss.visual.get_node_or_null(^"CerfMist") as CanvasItem
	_check("phase 2 : brume au sol visible", mist != null and mist.visible)
	_check("phase 2 : couronne de follets à l'entrée", _burst_ok)
	_check("phase 2 : anims _p2", _has_prefix_p(2), str(_anims_seen.keys()))
	_check("phase 2 : charges enchaînées", _chain >= 1, "enchaînements=%d %s" % [_chain, str(_kinds)])
	# --- phase 3
	_kinds = {}
	_anims_seen = {}
	_boss.hp = _boss.max_hp * 0.3
	_boss.take_damage(1.0)
	_next(3)


func _end_p3() -> void:
	_check("phase 3 : bond spectral (vanish -> reappear)", int(_kinds.get(&"leap", 0)) >= 1, str(_kinds))
	_check("phase 3 : anims vanish et reappear jouées", _anims_seen.has("vanish_s") and _anims_seen.has("reappear_s"), str(_anims_seen.keys()))
	_check("phase 3 : anims _p3", _has_prefix_p(3), str(_anims_seen.keys()))
	_check("dégâts à la frame d'impact (tous les coups)", _sync_n >= 10 and _sync_bad == 0, "%d / %d" % [_sync_bad, _sync_n])
	_check("coups reçus par le joueur (total)", _hits >= 6, str(_hits))
	print("  cerf : %d coups reçus, %d impacts vérifiés, octants %s" % [_hits, _sync_n, str(_octants.keys())])
	_pillar.charge = Balance.PILLAR_CHARGE_S
	_boss.take_damage(_boss.hp + 1.0)
	_check("cerf mort", not _boss.active)
	_check("mort : IA libérée", _boss.brain == null)
	_check("pilier terminé", _pillar.state == Pillar.STATE_DONE)
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
