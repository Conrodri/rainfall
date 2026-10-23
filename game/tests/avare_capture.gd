extends Node
## Capture de contrôle d'Avare (debug seulement), modèle capture_spell_fx.gd :
## godot --path game --write-movie <dossier>/avare.png --fixed-fps 30 --resolution 1280x720 res://tests/avare_capture.tscn
## (s) : 0,3 monstres au contact + 4 P d'or (coups de coffre auto) ; 1,2 Poignée (visée à droite) ; 2,2 Rançon ;
## 3,0 coup subi (l'or saigne) ; 3,8 Faillite ; 11,5 fin (les pièces restent au sol : retour joueur 22/10).
## Bulle de tutoriel de la bourse vers 1,5 s (profil injecté, jamais écrit). Imprime « CAST frame=<n> <sort> ».

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Profile.path = "user://test_capture_avare_profile.json" # profil injecté : jamais le vrai
	Profile.write_enabled = false
	Profile.load_profile()
	RunState.character = &"avare"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 11)
	_main.set(&"save_path", "user://test_capture_avare.json") # jamais la vraie sauvegarde de run
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_main)


func _cast(slot: int, label: String) -> void:
	var ok: bool = _main.player.spells.cast(slot)
	print("CAST frame=%d %s ok=%s anim=%s gold=%.1f" % [_frame, label, ok, _main.player.action_anim(), RunState.gold])


func _process(delta: float) -> void:
	_frame += 1
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	var p: Node2D = _main.player
	if _step == 0 and _t > 0.3:
		_step = 1
		p.grant_invulnerability(1.0e6)
		p.set(&"auto_cast_spells", false)
		RunState.gold = 4.0 * AvareKit.price_unit()
		var cam: Camera2D = _main.camera
		if cam != null:
			cam.zoom = Iso.camera_zoom(1.3)
		var d: Director = _main.director
		d.spawning_enabled = false
		var pp := p.global_position
		for v in [Vector2(110, 0), Vector2(-120, 30), Vector2(40, 130), Vector2(330, -40), Vector2(360, 30), Vector2(-60, -200), Vector2(200, 160)]:
			d.spawn_enemy(1, pp + v)
	if _step == 1 and _t > 1.2:
		_step = 2
		p.spells.aim_override = p.global_position + Vector2(320, -10)
		_cast(2, "poignee_de_pieces")
		p.spells.aim_override = null
	if _step == 2 and _t > 2.2:
		_step = 3
		_cast(3, "rancon")
	if _step == 3 and _t > 3.0:
		_step = 4
		p.set(&"_invuln", 0.0)
		p.take_damage(5.0, null)
		p.grant_invulnerability(1.0e6)
		print("HIT frame=%d gold=%.1f coins=%d" % [_frame, RunState.gold, p.kit.coins.size()])
	if _step == 4 and _t > 3.8:
		_step = 5
		var d: Director = _main.director
		for v in [Vector2(150, 0), Vector2(-160, 40), Vector2(60, 170), Vector2(-40, -150)]:
			d.spawn_enemy(1, p.global_position + v)
		_cast(4, "faillite")
	if _step == 5 and _t > 11.5:
		print("END frame=%d coins=%d ground=%.1f gold=%.1f" % [_frame, p.kit.coins.size(), p.kit.ground_gold(), RunState.gold])
		get_tree().quit()
