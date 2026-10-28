extends Node
## Capture de contrôle du panneau d'objectifs et du texte « +N XP (or converti) ».
## PC : godot --path game --resolution 1920x1080 --write-movie <dossier>/pc.png --fixed-fps 30 res://tests/capture_objectives.tscn
## Chronologie (s) : 0,5 gros pilier actif (boss vivant, charge qui monte) ; 2,5 boss tué + charge pleine
## (« Activer le téléporteur ») ; 3,5 étage suivant (conversion de l'or) ; 4,5 fin.

var _main: Node
var _t := 0.0
var _step := 0
var _big: Pillar


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 2024)
	add_child(_main)


func _process(delta: float) -> void:
	if _main == null or not bool(_main.get(&"is_ready")):
		return
	_t += delta
	var hud: Hud = _main.hud
	var stage: StageManager = _main.stage
	if hud.pause_menu.is_open:
		hud.pause_menu._close() # pause automatique (fenêtre sans focus au lancement)
	if _step == 0 and _t > 0.5:
		_step = 1
		_main.player.grant_invulnerability(1.0e6)
		for p in stage.pillars:
			if p.kind == Pillar.Kind.SMALL:
				p.activate()
				p.boss_dead = true
				p._check_done()
			else:
				_big = p
		_main.player.global_position = _big.global_position + Vector2(-120, 60)
		_big.activate()
		_big.charge = Balance.PILLAR_CHARGE_S * 0.4
	if _step == 1 and _t > 2.5:
		_step = 2
		_big.charge = Balance.PILLAR_CHARGE_S
		if _big._boss != null:
			_big._boss.take_damage(1.0e9)
	if _step == 2 and _t > 3.5:
		_step = 3
		RunState.add_gold(420.0)
		stage.next_stage()
	if _step == 3 and _t > 4.5:
		get_tree().quit()
