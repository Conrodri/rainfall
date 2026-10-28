extends Node
## Étage 2 (Forêt-brume) jouable : boss d'étage Cerf-Lanterne et un mini-boss du biome.
## godot --headless --path game res://tests/floor2_boss_test.tscn  -> RESULT: OK
## Capture : sans --headless, avec `--write-movie <f>.avi --fixed-fps 30 --resolution 1280x720 -- capture`
## (le combat du cerf dure plus longtemps, aucune vérification bloquante).
## Pour chaque boss (bramble_queen, brood_mother puis le cerf, lancés par leur pilier) : sprite du biome, PV fixés au spawn
## (Balance.boss_hp), coups reçus par le joueur, coups subis par le boss, face au joueur pendant
## chaque coup (jamais l'anim « _s » quand le joueur est d'un autre côté : repli sur la posture
## orientée), tir et sorts à la frame d'impact, mort -> pilier terminé ; gros pilier -> fin d'étage
## (sortie active). Le joueur est placé tour à tour au nord, à l'est, à l'ouest et au sud du boss.
## Sauvegarde de test seulement (jamais user://run_save.json).

const MAP := "res://scenes/stage/maps/foret_brume.tscn"
const SAVE := "user://test_floor2_boss.json"
const SIDES := [Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)] ## n, e, w, s
const SIDE_S := 3.2 ## secondes par côté
const DIST_PX := 190.0 ## ~3 u : à portée de l'auto et du sort de zone, le boss reste planté

var _capture := false
var _main: Node
var _fails := 0
var _phase := -1
var _t := 0.0
var _boss: Enemy = null
var _pillar: Pillar = null
var _anchor := Vector2.ZERO ## position de départ du boss (le joueur tourne autour)
var _side := 0
var _hits := 0 ## coups du boss reçus par le joueur
var _boss_hurt := 0 ## coups du joueur reçus par le boss
var _att_frames := 0
var _bad_face := 0
var _back_frames := 0 ## anim « _s » jouée alors que le joueur n'est pas au sud
var _dirs_seen := {}
var _proj_n := 0
var _sync_n := 0
var _sync_bad := 0
var _prev_windup := 0
var _spell_sync_n := 0
var _spell_sync_bad := 0
var _frame_n := 0
var _frame_bad := 0
var _minis_done := 0


func _ready() -> void:
	_capture = "capture" in OS.get_cmdline_user_args()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(MAP))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 23)
	add_child(_main)
	Events.player_damaged.connect(func(_amount: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	Events.enemy_damaged.connect(func(e: Node, _amount: float, _crit: bool, _el: StringName) -> void:
		if _boss != null and e == _boss:
			_boss_hurt += 1)
	_main.game_ready.connect(func() -> void: _phase = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _stage() -> StageManager:
	return _main.get(&"stage")


## Joueur invulnérable aux morts du test : PV remis au plein, sans statut.
func _reset_player() -> void:
	var p := _player()
	p.hp = p.max_hp
	p.set(&"_invuln", 0.0)
	p.clear_statuses()


func _physics_process(delta: float) -> void:
	if _phase < 0:
		return
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	_t += delta
	var d := _director()
	match _phase:
		0: # fin de la protection d'arrivée ; étage 2, biome du Cerf
			d.spawning_enabled = false
			if _t > 1.6:
				for e in d.get_tree().get_nodes_in_group(&"enemies").duplicate():
					if e is Enemy and not e.is_boss:
						d.release_enemy(e)
				RunState.stage = 2
				_stage().floor_boss = &"cerf_lanterne" # carte forcée par la scène : boss du biome (data/maps/foret_brume.json)
				EnemyVisual._mini_count = 0 # premier mini-boss du biome du Cerf = bramble_queen
				_start_fight(Pillar.Kind.SMALL)
		1, 2: # combat (1 = mini, 2 = étage)
			_fight_step(delta)
			if _t > SIDE_S * SIDES.size() + (12.0 if _capture and _phase == 2 else 0.0):
				_end_fight()


## Lance le pilier du type voulu ; le boss apparaît à côté du pilier.
func _start_fight(kind: Pillar.Kind) -> void:
	var sm := _stage()
	_pillar = null
	for p: Pillar in sm.pillars:
		if p.kind == kind and p.state != Pillar.STATE_DONE:
			_pillar = p
			break
	if _pillar == null:
		_check("pilier %s présent" % ("petit" if kind == Pillar.Kind.SMALL else "gros"), false)
		_finish()
		return
	if kind == Pillar.Kind.BIG:
		_pillar.unlock()
	var D := RunState.difficulty()
	_check("pilier activé", _pillar.activate())
	_boss = _pillar.get(&"_boss") as Enemy
	if _boss == null:
		_check("boss apparu", false)
		_finish()
		return
	var is_floor := kind == Pillar.Kind.BIG
	var bk := &"etage" if is_floor else &"mini"
	var sid := StringName(_boss.get(&"_boss_sprite_id"))
	if is_floor:
		_check("boss d'étage 2 = cerf (sprite)", sid == &"cerf", str(sid))
	else:
		_check("mini-boss du biome (bramble_queen / brood_mother)", sid in [&"bramble_queen", &"brood_mother"], str(sid))
	_check("%s : sprite Blender (pas de placeholder)" % sid, bool(_boss.visual.get(&"_boss_sprite")))
	var want := Balance.boss_hp(bk, D, 2)
	_check("%s : PV fixés au spawn (Balance.boss_hp)" % sid, absf(_boss.max_hp - want) < 0.01 * want and _boss.hp == _boss.max_hp,
		"%.0f / attendu %.0f" % [_boss.max_hp, want])
	_check("%s : dégâts Balance.boss_damage" % sid, is_equal_approx(_boss.damage, Balance.boss_damage(bk, D)))
	print("  %s : PV %.0f, dégâts %.1f, rayon %.1f u" % [sid, _boss.max_hp, _boss.damage, _boss.radius_px / 64.0])
	_boss.max_hp = 1.0e7 # le combat ne doit pas finir avant la fin des vérifications
	_boss.hp = 1.0e7
	_anchor = _boss.position
	_side = -1
	_hits = 0
	_boss_hurt = 0
	_att_frames = 0
	_bad_face = 0
	_back_frames = 0
	_dirs_seen = {}
	_sync_n = 0
	_sync_bad = 0
	_spell_sync_n = 0
	_spell_sync_bad = 0
	_frame_n = 0
	_frame_bad = 0
	_proj_n = _shot_count()
	_prev_windup = 0
	_next(2 if is_floor else 1)


## Tirs en vol : pool du directeur + tirs spéciaux des mini-boss (statut transmis, rebonds : MiniHazards).
func _shot_count() -> int:
	var n := _director().projectile_count()
	var br = _boss.brain if is_instance_valid(_boss) else null
	if br is MiniBossBrain and br.hazards != null and is_instance_valid(br.hazards):
		n += br.hazards.shots.size()
	return n


func _fight_step(_delta: float) -> void:
	var p := _player()
	var d := _director()
	var side := mini(int(_t / SIDE_S), SIDES.size() - 1)
	if side != _side:
		_side = side
		_boss.position = _anchor # chaque côté part du même point (le boss suit le joueur sinon)
	var want: Vector2 = _boss.position + (SIDES[side] as Vector2) * DIST_PX
	if d.nav != null:
		want = d.nav.resolve(want, 26.0)
	p.global_position = want # joueur immobile (aucune entrée en headless)
	if p.hp < p.max_hp * 0.5:
		_reset_player()
	var vis: EnemyVisual = _boss.visual
	# tir automatique : le projectile naît à la frame d'impact
	var pn := _shot_count()
	if pn > _proj_n and vis.is_attacking():
		_sync_n += 1
		var lag := float(vis.get(&"_strike_t")) - float(vis.get(&"_strike_impact"))
		if lag < -0.001 or lag > 0.05:
			_sync_bad += 1
			print("  tir hors impact : %.3f s" % lag)
	_proj_n = pn
	# sorts (zone / cible) : les dégâts tombent à la frame d'impact de l'anim
	var w := int(_boss.get(&"_windup"))
	if _prev_windup in [Enemy.Windup.SLAM, Enemy.Windup.STRIKE] and w == Enemy.Windup.NONE:
		_spell_sync_n += 1
		var lag2 := float(vis.get(&"_strike_t")) - float(vis.get(&"_strike_impact"))
		if lag2 < -0.001 or lag2 > 0.05:
			_spell_sync_bad += 1
			print("  sort hors impact : %.3f s" % lag2)
		# frame visible = frame d'impact de l'anim (clé "impact" de BOSS_SPRITES, sinon moitié)
		var spr0 := vis.get(&"_sprite") as AnimatedSprite2D
		if spr0 != null and not String(spr0.animation).begins_with("walk_") and not String(spr0.animation).begins_with("run_"):
			var act := &"cast_a" if _prev_windup == Enemy.Windup.SLAM else &"cast_b"
			var cfg: Dictionary = vis.get(&"_boss_cfg")
			var frac: float = (cfg.get("impact", {}) as Dictionary).get(act, EnemyVisual.BOSS_IMPACT_FRAC)
			var k := roundi(spr0.sprite_frames.get_frame_count(spr0.animation) * frac)
			_frame_n += 1
			if spr0.frame < k - 1 or spr0.frame > k:
				_frame_bad += 1
				print("  %s : frame %d à l'impact (attendu %d)" % [spr0.animation, spr0.frame, k])
	_prev_windup = w
	# face au joueur pendant le coup
	if vis.is_attacking() and float(vis.get(&"_strike_t")) <= float(vis.get(&"_strike_impact")):
		var v := p.global_position - _boss.position
		if _boss.brain != null: # Cerf : la visée se fige en fin de télégraphe (lisibilité) ; le sprite suit la visée
			v = _boss.brain.aim
		var exp4 := (0 if v.x >= 0.0 else 2) if absf(v.x) >= absf(v.y) else (1 if v.y > 0.0 else 3)
		var diag := absf(absf(v.x) - absf(v.y)) < 0.15 * v.length() # quasi diagonale : les deux côtés valent
		_att_frames += 1
		var got := vis.facing_dir4()
		_dirs_seen[got] = int(_dirs_seen.get(got, 0)) + 1
		if got != exp4 and not diag:
			_bad_face += 1
		var spr := vis.get(&"_sprite") as AnimatedSprite2D
		if spr != null and exp4 != 1 and not diag and String(spr.animation).ends_with("_s"):
			_back_frames += 1


func _end_fight() -> void:
	var sid := StringName(_boss.get(&"_boss_sprite_id"))
	var is_floor := _phase == 2
	_check("%s : au moins 3 coups reçus par le joueur" % sid, _hits >= 3, "coups=%d" % _hits)
	_check("%s : touché par les sorts du joueur" % sid, _boss_hurt > 0, "coups=%d" % _boss_hurt)
	_check("%s : tourné vers le joueur pendant ses coups" % sid, _att_frames > 0 and _bad_face * 10 <= _att_frames,
		"images=%d mauvaises=%d dirs=%s" % [_att_frames, _bad_face, str(_dirs_seen)])
	_check("%s : vu dans au moins 3 directions" % sid, _dirs_seen.size() >= 3, str(_dirs_seen))
	_check("%s : jamais l'anim de face quand le joueur est derrière" % sid, _back_frames == 0, "images=%d" % _back_frames)
	_check("%s : tir auto à la frame d'impact" % sid, _sync_n > 0 and _sync_bad == 0, "tirs=%d hors=%d" % [_sync_n, _sync_bad])
	if _boss.brain != null: # Cerf (CerfBrain) : journal d'impact de l'IA (charge, lanternes, follets, bond)
		for ev: Dictionary in _boss.brain.events:
			if StringName(ev["kind"]) in [&"charge", &"wisps", &"wisp_boom", &"leap"] and int(ev.get("expect", -1)) >= 0:
				_spell_sync_n += 1
				var f := int(ev["frame"])
				var lag := float(ev.get("lag", 0.0))
				if f < int(ev["expect"]) - 1 or f > int(ev["expect"]) or lag < -0.001 or lag > 0.05:
					_spell_sync_bad += 1
	if _boss.brain is MiniBossBrain: # mini-boss piloté par données : impacts armés de son journal (attaque de base / sorts)
		for ev: Dictionary in _boss.brain.events:
			if ev.get("armed", false):
				var mlag := float(ev.get("lag", 0.0))
				var bad := mlag < -0.001 or mlag > 0.05
				if ev.get("auto", false):
					_sync_n += 1
					_sync_bad += 1 if bad else 0
				else:
					_spell_sync_n += 1
					_spell_sync_bad += 1 if bad else 0
	_check("%s : sorts à la frame d'impact" % sid, _spell_sync_n > 0 and _spell_sync_bad == 0,
		"sorts=%d hors=%d" % [_spell_sync_n, _spell_sync_bad])
	if _frame_n > 0:
		_check("%s : frame d'impact visible au moment des dégâts" % sid, _frame_bad == 0, "%d / %d" % [_frame_bad, _frame_n])
	var pm: Node = _main.get(&"pickups")
	var drops_before := int(pm.get(&"active_count")) if pm != null else 0
	if is_floor:
		_pillar.charge = Balance.PILLAR_CHARGE_S # zone de charge terminée : seule la mort du boss manque
	_boss.take_damage(_boss.hp * 10.0 + 1.0) # ×10 : gardes des mini-boss (MiniBossBrain, réduction plancher 0,3)
	_check("%s : mort" % sid, not _boss.active)
	_check("%s : pilier terminé à sa mort" % sid, _pillar.state == Pillar.STATE_DONE, str(_pillar.state))
	if pm != null:
		_check("%s : prime (or + XP) au sol" % sid, int(pm.get(&"active_count")) > drops_before)
	if not is_floor:
		_boss = null
		_minis_done += 1
		_start_fight(Pillar.Kind.SMALL if _minis_done < 2 else Pillar.Kind.BIG) # les 2 mini-boss du biome, puis le cerf
		return
	var sm := _stage()
	_check("fin d'étage 2 : floor_cleared", sm.floor_cleared)
	_check("fin d'étage 2 : sortie active", sm.teleporter != null and sm.teleporter.active)
	_boss = null
	_finish()


func _next(phase: int) -> void:
	_phase = phase
	_t = 0.0


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _finish() -> void:
	_phase = 99
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
