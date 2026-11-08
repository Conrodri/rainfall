extends Node
## Capture de contrôle des visuels d'état (StatusFx). Debug seulement.
## godot --path game --write-movie <dossier>/st.png --fixed-fps 60 --resolution 1280x720 res://tests/capture_status_fx.tscn
## Rangée de monstres immobiles (Poutch) autour du joueur, de gauche à droite : empoisonné, en feu, trempé, électrisé
## (coup de foudre toutes les 0,4 s), étourdi (toutes les 0,9 s) ; un mini-boss trempé et en feu au-dessus.
## Imprime « STATE frame=<n> » quand tout est posé ; fin à 3,5 s.

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0
var _row: Array[Enemy] = []
var _boss: Enemy = null
var _zap_t := 0.0
var _stun_t := 0.0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	add_child(_main)


func _process(delta: float) -> void:
	_frame += 1
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	if _step == 0 and _t > 0.3:
		_step = 1
		_main.player.grant_invulnerability(1.0e6)
		var cam: Camera2D = _main.camera
		if cam != null:
			cam.zoom = Iso.camera_zoom(1.8)
		var d: Director = _main.director
		d.spawning_enabled = false
		d.despawn_all()
		var pp: Vector2 = _main.player.global_position
		var tiers := [1, 3, 2, 3, 1]
		for i in 5:
			var e := d.spawn_enemy(tiers[i], pp + Vector2(-280.0 + 140.0 * i, 150.0))
			e.test_dummy = true
			_row.append(e)
		_boss = d.spawn_boss(&"mini", pp + Vector2(0.0, -260.0)) as Enemy
		if _boss != null:
			_boss.test_dummy = true
	if _step >= 1:
		_keep_states(delta)
	if _step == 1 and _t > 0.6:
		_step = 2
		print("STATE frame=%d" % _frame)
	if _t > 3.5:
		get_tree().quit()


func _keep_states(delta: float) -> void:
	_zap_t -= delta
	_stun_t -= delta
	var e: Enemy
	e = _row[0]
	if not e.is_poisoned():
		e.apply_status(&"poison", {"total": 1.0, "duration": 4.0})
	e = _row[1]
	if not e.is_burning():
		e.apply_status(&"burn", {"total": 1.0, "duration": 3.0})
	e = _row[2]
	StatusFx.wet(e, 1.0)
	if _zap_t <= 0.0:
		_zap_t = 0.4
		_row[3].take_damage(1.0, false, &"lightning")
	if _stun_t <= 0.0:
		_stun_t = 0.9
		_row[4].test_dummy = false
		_row[4].stun(0.8)
	if _boss != null and _boss.active:
		StatusFx.wet(_boss, 1.0)
		if not _boss.is_burning():
			_boss.apply_status(&"burn", {"total": 1.0, "duration": 3.0})
