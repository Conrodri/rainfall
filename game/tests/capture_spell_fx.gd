extends Node
## Capture de contrôle des anims d'action et des VFX de sorts (debug seulement).
## Ardent : godot --path game --write-movie <dossier>/ardent.png --fixed-fps 30 --resolution 1280x720 res://tests/capture_spell_fx.tscn
## Rictus : idem avec « -- rictus » en fin de ligne.
## Ardent (s) : 0,3 monstres ; 0,8 Nova ardente ; 2,0 Cendres (visée à droite) ; 3,6 Brasier ; 5,6 fin.
## Rictus (s) : 0,3 monstres au contact (demi-lunes auto) ; 1,2 Éventail ; 1,8 Doublures (visée à droite) ;
## 2,4 Toupie (étoile) ; 4,6 fin.
## Imprime « CAST frame=<n> <sort> » pour retrouver les images autour d'un lancement.

var _main: Node
var _t := 0.0
var _step := 0
var _frame := 0
var _cid: StringName = &"ardent"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # quitte même si une fenêtre (montée de niveau) met le jeu en pause
	if OS.get_cmdline_user_args().has("rictus"):
		_cid = &"rictus"
	RunState.character = _cid
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 7)
	_main.set(&"save_path", "user://test_capture_spell_fx.json") # jamais la vraie sauvegarde de run
	_main.process_mode = Node.PROCESS_MODE_PAUSABLE # le jeu garde sa pause normale
	add_child(_main)


func _cast(slot: int, label: String) -> void:
	var ok: bool = _main.player.spells.cast(slot)
	print("CAST frame=%d %s ok=%s anim=%s" % [_frame, label, ok, _main.player.action_anim()])


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
		p.set(&"auto_cast_spells", false) # option d'accessibilité éventuelle : seuls les sorts lancés ici
		var cam: Camera2D = _main.camera
		if cam != null:
			cam.zoom = Iso.camera_zoom(1.15 if _cid == &"ardent" else 1.6)
		var d: Director = _main.director
		d.spawning_enabled = false
		var pp := p.global_position
		if _cid == &"ardent":
			for v in [Vector2(150, -40), Vector2(-170, 60), Vector2(60, 180), Vector2(330, 20), Vector2(380, 120)]:
				d.spawn_enemy(1, pp + v)
		else:
			for v in [Vector2(110, 0), Vector2(-120, 30), Vector2(40, 130)]:
				d.spawn_enemy(1, pp + v)
	if _cid == &"ardent":
		if _step == 1 and _t > 0.8:
			_step = 2
			_cast(2, "nova_ardente")
		if _step == 2 and _t > 2.0:
			_step = 3
			p.spells.aim_override = p.global_position + Vector2(260, 40)
			_cast(3, "cendres")
			p.spells.aim_override = null
		if _step == 3 and _t > 3.6:
			_step = 4
			_cast(4, "brasier")
		if _step == 4 and _t > 5.6:
			get_tree().quit()
	else:
		if _step == 1 and _t > 1.2:
			_step = 2
			p.spells.aim_override = p.global_position + Vector2(300, -60)
			_cast(2, "eventail")
			p.spells.aim_override = null
		if _step == 2 and _t > 1.8:
			_step = 3
			p.spells.aim_override = p.global_position + Vector2(300, 0)
			_cast(4, "doublures")
			p.spells.aim_override = null
		if _step == 3 and _t > 2.4:
			_step = 4
			_cast(3, "toupie") # au milieu des doublures : l'étoile
		if _step == 4 and _t > 4.6:
			get_tree().quit()
