extends Node
## Base commune des tests de boss d'étage 1 (eclusier_boss_test, ox_herder_boss_test, jar_bearer_boss_test), même
## déroulé que recluse_boss_test : carte des Terrasses noyées, boss lancé par le gros pilier (RunState.stage = 1,
## StageManager.floor_boss = ID), joueur placé tour à tour dans 8 directions à DIST_PX du boss (le boss est
## ramené à son ancre entre deux coups), phases forcées par les PV (70 % / 35 %), mort pendant la charge (trace
## au sol), fin de charge (trace libérée, aucun nœud laissé). Les sous-classes donnent ID, PREFIX et les
## vérifications propres au boss (_on_spawned, _end_p1/2/3, _trace_ok, _shot_key).
## Capture : sans --headless, `--resolution 1280x720 -- capture shots=<dossier absolu>`.

const MAP := "res://scenes/stage/maps/terrasses_noyees.tscn"
const DIST_PX := 170.0
const SLOT_S := 2.8
const P2_S := 14.0
const P3_S := 16.0
const TRACE_S := 2.5

var ID := &""
var PREFIX := ""
var SAVE := "user://test_floor1_boss.json"
var AIM_KINDS: Array = [] ## coups dont la visée est vérifiée (face au joueur)

var _capture := false
var _main: Node
var _fails := 0
var _step := -1
var _t := 0.0
var _boss: Enemy = null
var _pillar: Pillar = null
var _anchor := Vector2.ZERO
var _slot := -1
var _slot_t0 := 0.0 ## instant où le joueur a pris son créneau actuel
var _ev_i := 0
var _hits := 0
var _kinds := {}
var _all_kinds := {}
var _octants := {}
var _aim_n := 0
var _aim_bad := 0
var _dir4_bad := 0
var _sync_n := 0
var _sync_bad := 0
var _anims_seen := {}
var _trans_checked := false
var _has_art := false
var _hz: Node = null
var _shots_dir := ""
var _shot_n := 0
var _shot_t := 0.0
var _shot_seen := {}


func _ready() -> void:
	_capture = "capture" in OS.get_cmdline_user_args()
	Profile.write_enabled = false # la mémoire des boss se note en mémoire seulement (jamais le vrai profil)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			_shots_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(_shots_dir)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(MAP))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 17)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func brain():
	return _boss.brain if _boss != null else null


func _physics_process(delta: float) -> void:
	if _step < 0 or _step == 99:
		return
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	_t += delta
	if _shots_dir != "" and _step in [1, 2, 3, 4]:
		_shoot(delta)
	match _step:
		0:
			_director().spawning_enabled = false
			if _t > 1.6:
				for e in get_tree().get_nodes_in_group(&"enemies").duplicate():
					if e is Enemy and not e.is_boss:
						_director().release_enemy(e)
				RunState.stage = 1
				(_main.get(&"stage") as StageManager).floor_boss = ID
				_spawn()
		1:
			# Créneaux parcourus un par un : avec BossPace (armement planté, récupération immobile, coups enchaînés)
			# le boss est rarement libre ; un créneau calé sur l'horloge en sautait plusieurs. Chaque direction est
			# tenue au moins slot_s, puis on passe à la suivante au premier instant libre du boss.
			var slot_s := 2.0 if _capture else SLOT_S
			_place(mini(_slot + 1, 7) if _slot < 0 or _t - _slot_t0 >= slot_s else _slot)
			_scan()
			_tick_phase(1)
			if (_slot >= 7 and _t - _slot_t0 > slot_s) or _t > slot_s * 16.0:
				_end_common_p1()
		2:
			_place(int(_t / 3.0) % 8)
			_scan()
			_watch_trans(2) # un coup en cours (ruée) peut retarder la transition d'une fraction de seconde
			_tick_phase(2)
			if _t > P2_S:
				_check_trans(2)
				_end_p2()
				if _has_art:
					_check("phase 2 : anims _p2", _has_prefix_p(2), str(_anims_seen.keys()))
				_kinds = {}
				_anims_seen = {}
				_boss.hp = _boss.max_hp * 0.3
				_boss.take_damage(1.0)
				_next(3)
		3:
			_place(int(_t / 3.0) % 8)
			_scan()
			_watch_trans(3)
			_tick_phase(3)
			if _t > P3_S:
				_check_trans(3)
				_end_p3()
				_check("impacts calés (tous les coups armés)", _sync_n >= 10 and _sync_bad == 0, "%d / %d" % [_sync_bad, _sync_n])
				_check("coups reçus par le joueur (total)", _hits >= 6, str(_hits))
				print("  %s : %d coups reçus, %d impacts vérifiés, coups %s" % [ID, _hits, _sync_n, str(_all_kinds)])
				_pillar.charge = 10.0
				_hz = brain().hazards()
				_boss.take_damage(_boss.hp + 1.0)
				_check("boss mort", not _boss.active)
				_check("mort : IA libérée", _boss.brain == null)
				_next(4)
		4:
			_player().global_position = _pillar.global_position + Vector2(64.0, 0.0)
			if _t > TRACE_S:
				_check("trace : les zones au sol restent après la mort (charge en cours)", is_instance_valid(_hz) and _trace_ok(_hz), "")
				_pillar.charge = Balance.PILLAR_CHARGE_S
				_next(5)
		5:
			if _t > 0.6:
				_check("pilier terminé (charge finie, boss mort)", _pillar.state == Pillar.STATE_DONE, str(_pillar.state))
				_check("trace libérée avec la fin de la charge", not is_instance_valid(_hz))
				_check("mort : nœuds du boss libérés", _leftovers().is_empty(), str(_leftovers()))
				_finish()


var _trans_seen := false
var _trans_anim_seen := false


func _watch_trans(p: int) -> void:
	if _t > 2.5 or brain() == null:
		return
	# transition = état STAGGER du cerveau (Enemy.phase_transitioning) : owns_motion() est aussi vrai pendant les
	# coups plantés (BossPace), il ne suffit plus à reconnaître la transition
	if brain().phase == p and _boss.phase_transitioning():
		_trans_seen = true
		if String(_boss.visual.call(&"current_anim")) == "trans_p%d_s" % p:
			_trans_anim_seen = true


func _check_trans(p: int) -> void:
	_check("phase %d sous %d %% : transition (boss figé) dans les 2,5 s" % [p, 70 if p == 2 else 35], _trans_seen and brain().phase == p, str(brain().phase))
	if _has_art:
		_check("phase %d : anim de transition trans_p%d" % [p, p], _trans_anim_seen)
	_trans_seen = false
	_trans_anim_seen = false


# --- Points d'extension -------------------------------------------------------------

func _on_spawned() -> void:
	pass


func _tick_phase(_p: int) -> void:
	pass


func _end_p1() -> void:
	pass


func _end_p2() -> void:
	pass


func _end_p3() -> void:
	pass


func _trace_ok(_h: Node) -> bool:
	return true


func _shot_key() -> String:
	return ""


# --- Déroulé -------------------------------------------------------------------------

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
	_check("boss d'étage = %s" % ID, _boss.boss_id() == ID, str(_boss.boss_id()))
	_check("mémoire des boss : Profile retient %s pour l'étage 1" % ID, Profile.last_boss_of_floor(1) == ID, str(Profile.last_floor_boss))
	_check("chemin du sprite enregistré", EnemyVisual.boss_path(ID) == "res://assets/sprites/bosses/etage/%s/%s.tres" % [ID, ID], EnemyVisual.boss_path(ID))
	_check("seuils de phase 70 / 35 %", Balance.boss_phase(&"etage", ID, 0.71) == 1 and Balance.boss_phase(&"etage", ID, 0.69) == 2 and Balance.boss_phase(&"etage", ID, 0.34) == 3)
	_has_art = bool(_boss.visual.get(&"_boss_sprite"))
	print("  sprites livrés : ", _has_art)
	_on_spawned()
	_boss.max_hp = 1.0e7
	_boss.hp = 1.0e7
	_anchor = _boss.position
	_next(1)


func _place(slot: int) -> void:
	var b = brain()
	if b == null:
		return
	var idle: bool = not b.owns_motion() and int(b.state) == 0 and not _boss.visual.call(&"is_attacking")
	if slot != _slot and idle:
		_slot = slot
		_slot_t0 = _t
	if idle and _boss.position.distance_to(_anchor) > 40.0:
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
	var b = brain()
	if b == null:
		return
	_anims_seen[String(_boss.visual.call(&"current_anim"))] = true
	var evs: Array = b.events
	while _ev_i < evs.size():
		var ev: Dictionary = evs[_ev_i]
		_ev_i += 1
		var kind := StringName(ev["kind"])
		_kinds[kind] = int(_kinds.get(kind, 0)) + 1
		_all_kinds[kind] = int(_all_kinds.get(kind, 0)) + 1
		if kind == &"phase" or not ev.has("to"):
			continue
		_sync_n += 1
		var f := int(ev["frame"])
		var k := int(ev["expect"])
		var lag := float(ev["lag"])
		if lag < -0.001 or lag > 0.05 or (k >= 0 and (f < k - 1 or f > k)):
			_sync_bad += 1
			print("  %s : %s frame %d (attendu %d), décalage %.3f s" % [kind, ev["anim"], f, k, lag])
		if kind in AIM_KINDS:
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
			if _has_art and not diag and an != "" and not an.ends_with("_" + EnemyVisual.BOSS_DIRS4[exp4]):
				_dir4_bad += 1
				print("  %s : anim %s pour une visée %s" % [kind, an, EnemyVisual.BOSS_DIRS4[exp4]])


func _end_common_p1() -> void:
	_end_p1()
	_check("coups télégraphés face au joueur", _aim_n >= 6 and _aim_bad == 0, "%d / %d" % [_aim_bad, _aim_n])
	_cov("8 directions : au moins 6 octants visés", _octants.size() >= 6, str(_octants.keys()))
	_check("orientation du boss = visée (4 côtés)", _dir4_bad == 0, str(_dir4_bad))
	if _has_art:
		_check("phase 1 : anims _p1", _has_prefix_p(1), str(_anims_seen.keys()))
	_check("phase 1 : coups reçus par le joueur", _hits >= 3, str(_hits))
	_kinds = {}
	_anims_seen = {}
	_boss.hp = _boss.max_hp * 0.6
	_boss.take_damage(1.0)
	_next(2)


func _leftovers() -> Array:
	var left: Array = []
	var roots: Array[Node] = [_director().get_node(^"Enemies")]
	var layer := AmbianceManager.telegraph_layer(get_tree())
	if layer != null:
		roots.append(layer)
	for r in roots:
		for n in r.get_children():
			if String(n.name).begins_with(PREFIX) and not n.is_queued_for_deletion():
				left.append(String(n.name))
	return left


func _shoot(delta: float) -> void:
	_shot_t += delta
	var b = brain()
	var ph: int = b.phase if b != null else 4
	var key := _shot_key() if b != null else ""
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


## Vérif de couverture (dépend du nombre de coups vus) : en mode capture, créneaux raccourcis à 2 s → simple info.
func _cov(label: String, cond: bool, detail: String = "") -> void:
	if _capture and not cond:
		print("  info ", label, " (mode capture, créneaux courts)  ", detail)
	else:
		_check(label, cond, detail)
