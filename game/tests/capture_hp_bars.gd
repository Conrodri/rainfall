extends Node
## Capture de contrôle des barres de PV (boss à phases + mini-boss + élites + monstres, statuts, coups).
## Debug seulement. godot --path game --write-movie <dossier>/hp.png --fixed-fps 60 --resolution 1280x720 res://tests/capture_hp_bars.tscn
## Chronologie (s) : 0,3 apparitions + statuts ; coups réguliers ; 1,6 seuil 70 % du boss (rupture) ;
## 2,6 critique ; 3,4 PV bas (< 25 %, pulsation) ; 4,2 fin. Imprime « MARK frame=<n> ... ».

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0
var _boss: Enemy
var _mini: Enemy
var _mobs: Array[Enemy] = []
var _hit_t := 0.0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 11)
	add_child(_main)


func _process(delta: float) -> void:
	_frame += 1
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	var d: Director = _main.director
	if _step == 0 and _t > 0.3:
		_step = 1
		_main.player.grant_invulnerability(1.0e6)
		_main.player.process_mode = Node.PROCESS_MODE_DISABLED
		var cam: Camera2D = _main.camera
		if cam != null:
			cam.zoom = Iso.camera_zoom(1.5)
		d.spawning_enabled = false
		d.despawn_all()
		var pp: Vector2 = _main.player.global_position
		(_main.get(&"stage") as StageManager).floor_boss = &"rain_sower"
		_boss = d.spawn_boss(&"etage", pp + Vector2(0, -260)) as Enemy
		var ids := MiniBossBrain.ids()
		if not ids.is_empty():
			d.set_meta(&"next_mini_id", String(ids[0]))
		_mini = d.spawn_boss(&"mini", pp + Vector2(300, 40)) as Enemy
		_mobs.append(d.spawn_enemy(1, pp + Vector2(-200, 60)))
		_mobs.append(d.spawn_enemy(1, pp + Vector2(-140, 150)))
		_mobs.append(d.spawn_enemy(2, pp + Vector2(-300, -40), true))
		_mobs.append(d.spawn_enemy(3, pp + Vector2(160, 190)))
		for m in _mobs:
			m.take_damage(m.max_hp * 0.35)
		_mobs[0].apply_status(&"burn", {"total": 3.0, "duration": 4.0})
		_mobs[1].apply_status(&"poison", {"total": 3.0, "duration": 4.0})
		_mobs[1].apply_status(&"slow", {"pct": 0.3, "duration": 4.0})
		_mobs[2].apply_status(&"burn", {"total": 3.0, "duration": 4.0})
		_mobs[2].apply_status(&"burn", {"total": 3.0, "duration": 4.0})
		_mobs[2].apply_status(&"slow", {"pct": 0.3, "duration": 4.0})
		_mobs[3].stun(3.0)
		print("MARK frame=%d spawn" % _frame)
	if _step >= 1 and _step < 9 and _frame % 6 == 0 and is_instance_valid(_boss) and is_instance_valid(_mini):
		print("TR frame=%d boss=%s mini=%s mini_state=%s" % [_frame, _boss.phase_transitioning(), _mini.phase_transitioning(),
			_mini.brain.get(&"state") if _mini.brain != null else -1])
	if _step >= 1 and _step < 9:
		if is_instance_valid(_boss) and _boss.active and _step == 1 and _t > 0.5:
			_step = 2
			_boss.apply_status(&"burn", {"total": 10.0, "duration": 4.0})
			_boss.apply_status(&"burn", {"total": 10.0, "duration": 4.0})
			_boss.apply_status(&"burn", {"total": 10.0, "duration": 4.0})
			_boss.apply_status(&"poison", {"total": 10.0, "duration": 3.0})
			_boss.apply_status(&"slow", {"pct": 0.3, "duration": 3.5})
			_mini.apply_status(&"poison", {"total": 5.0, "duration": 4.0})
			_mini.apply_status(&"slow", {"pct": 0.3, "duration": 4.0})
		_hit_t -= delta
		if _hit_t <= 0.0 and is_instance_valid(_boss) and _boss.active:
			_hit_t = 0.35
			_boss.take_damage(_boss.max_hp * 0.03, false, &"", {"source_pos": _boss.position + Vector2(0, 80)})
			if is_instance_valid(_mini) and _mini.active:
				_mini.take_damage(_mini.max_hp * 0.04)
			print("MARK frame=%d hit" % _frame)
		if _step == 2 and _t > 1.6:
			_step = 3
			_boss.hp = _boss.max_hp * 0.72
			_boss.take_damage(_boss.max_hp * 0.05, false)
			_mini.hp = _mini.max_hp * 0.52
			_mini.take_damage(_mini.max_hp * 0.05)
			print("MARK frame=%d break70" % _frame)
		if _step == 3 and _t > 2.6:
			_step = 4
			_boss.take_damage(_boss.max_hp * 0.14, true)
			print("MARK frame=%d crit" % _frame)
		if _step == 4 and _t > 3.4:
			_step = 5
			_boss.hp = _boss.max_hp * 0.30
			_boss.take_damage(_boss.max_hp * 0.10, false)
			print("MARK frame=%d low" % _frame)
		if _t > 4.4:
			_step = 9
			get_tree().quit()
