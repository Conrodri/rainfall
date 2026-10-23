extends Node
## Capture de contrôle du ressenti des coups reçus (flash rouge, vignette, chiffre rouge, traîne de la
## barre de vie, secousse) et de l'ours mini-boss tourné vers le joueur (posture + fente à l'impact).
## Debug seulement, sauvegarde de test (jamais user://run_save.json) :
## godot --path game --write-movie <dossier>/hurt.png --fixed-fps 30 --resolution 1280x720 --quit-after 330 res://tests/capture_hurt_feel.tscn
## Imprime « HURT frame=<n> amount=… » à chaque coup reçu pour retrouver les images.

const MAP := "res://scenes/stage/maps/terrasses_noyees.tscn"
const SAVE := "user://test_capture_hurt_feel.json"

var _main: Node
var _t := -1.0
var _frame := 0
var _bear: Enemy = null


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(MAP))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 11)
	add_child(_main)
	Events.player_damaged.connect(func(amount: float, _s: Node) -> void:
		print("HURT frame=%d amount=%.1f" % [_frame, amount]))
	_main.game_ready.connect(func() -> void:
		_t = 0.0
		var hud: Node = _main.get(&"hud")
		var pm: Node = hud.get(&"pause_menu") if hud != null else null
		if pm != null and pm.has_signal(&"opened"):
			pm.opened.connect(func() -> void: pm.call_deferred(&"_close")))


func _process(_delta: float) -> void:
	_frame += 1


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var d: Director = _main.get(&"director")
	var p: Node2D = _main.get(&"player")
	d.spawning_enabled = false
	if _bear == null and _t > 1.6:
		for e in get_tree().get_nodes_in_group(&"enemies").duplicate():
			if e is Enemy and not e.is_boss:
				d.release_enemy(e)
		var cam: Camera2D = _main.get(&"camera")
		if cam != null:
			cam.zoom = Iso.camera_zoom(1.5)
		var sm: StageManager = _main.get(&"stage")
		sm.floor_boss = &"eclusier"
		EnemyVisual._mini_count = 0 # frost_bear
		_bear = d.spawn_boss(&"mini", p.global_position + Vector2(-120.0, 200.0)) as Enemy
		_bear.max_hp = 1.0e7
		_bear.hp = 1.0e7
	if p.hp < p.max_hp * 0.35: # jamais de mort pendant la capture
		p.hp = p.max_hp
	if _t > 10.5 and FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
