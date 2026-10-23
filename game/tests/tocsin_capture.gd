extends Node
## Capture de contrôle de Tocsin (debug seulement), modèle capture_spell_fx :
## godot --path game --write-movie <dossier>/tocsin.png --fixed-fps 30 --resolution 1280x720 res://tests/tocsin_capture.tscn
## (s) 0,3 paquet de monstres à droite ; 0,8 bras G ; 1,05 bras D (deux paquets) ; 2,0 Tête-cloche sur les paquets ;
## 3,4 nouveau paquet ; 3,9 bras ; 4,9 Coups de botte dans le paquet emprisonné (quilles) ; 6,2 fin.
## Imprime « CAST frame=<n> » et l'état des prisonniers (vrais monstres : position tenue, attaques suspendues).

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RunState.character = &"tocsin"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	_main.set(&"save_path", "user://test_capture_tocsin.json")
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)


func _cast(slot: int, label: String, aim: Variant) -> void:
	var p: Node2D = _main.player
	p.spells.aim_override = aim
	var ok: bool = p.spells.cast(slot)
	p.spells.aim_override = null
	print("CAST frame=%d %s ok=%s anim=%s" % [_frame, label, ok, p.action_anim()])


func _pack(center: Vector2, n: int, tier := 1) -> void:
	var d: Director = _main.director
	for i in n:
		d.spawn_enemy(tier, center + Vector2.from_angle(i * 2.4) * (30.0 + 18.0 * i))


func _process(delta: float) -> void:
	_frame += 1
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	var p: Node2D = _main.player
	var pp := p.global_position
	if _step == 0 and _t > 0.3:
		_step = 1
		p.grant_invulnerability(1.0e6)
		p.set(&"auto_cast_spells", false)
		var cam: Camera2D = _main.camera
		if cam != null:
			cam.zoom = Iso.camera_zoom(1.7)
		_main.director.spawning_enabled = false
		_pack(pp + Vector2(300, -150), 2, 3) # brutes : survivent au bras, emprisonnées
		_pack(pp + Vector2(330, 150), 4, 2)
	if _step == 1 and _t > 0.8:
		_step = 2
		_cast(2, "bras_g", pp + Vector2(400, -200))
	if _step == 2 and _t > 1.05:
		_step = 3
		_cast(2, "bras_d", pp + Vector2(400, 180))
	if _step == 3 and _t > 2.0:
		_step = 4
		var kit: TocsinKit = p.kit
		var held := 0
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if kit.is_captured(e):
				held += 1
		print("PRISONNIERS %d (arms=%d legs=%d)" % [held, kit.arms(), kit.legs()])
		_cast(4, "tete_cloche", pp + Vector2(150, 0))
	if _step == 4 and _t > 3.4:
		_step = 5
		_pack(pp + Vector2(-300, 60), 3, 2)
	if _step == 5 and _t > 3.9:
		_step = 6
		p.kit.regen_all() # démo : membres revenus
		_cast(2, "bras_g2", pp + Vector2(-400, 60))
	if _step == 6 and _t > 4.9:
		_step = 7
		_cast(3, "botte", pp + Vector2(-400, 60))
	if _step == 7 and _t > 6.2:
		get_tree().quit()
