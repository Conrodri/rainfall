extends Node
## Capture de contrôle de Grésille en mode test (SANS --headless), debug seulement :
## godot --path game res://tests/gresille_capture.tscn -- --out=<dossier>
## Un cliché par sort (Arc, arcs sur les chargés, Décharge, Mise à la terre, Orage, sillage) puis les deux variantes
## (Paratonnerre, Bouteille de Leyde) : <dossier>/gresille_<nom>.png. Monstres figés (freeze_ai), joueur invulnérable.
## Se termine seul (minuterie de sécurité de 150 s) ; la pause sur perte de focus est levée à chaque image.

var _out := ""
var _main: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	Platform.set_input_mode(Platform.InputMode.KBM)
	get_tree().create_timer(150.0, true, false, true).timeout.connect(func() -> void:
		print("capture : minuterie de sécurité")
		get_tree().quit(2))
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _main == null:
		return
	var hud: Variant = _main.get(&"hud")
	if hud != null and hud.pause_menu != null and hud.pause_menu.is_open and not hud.pause_menu.counting_down:
		hud.pause_menu.resume() # PauseMenu.resume() : perte de focus de la fenêtre
	if get_tree().paused and (hud == null or not hud.pause_menu.is_open):
		get_tree().paused = false


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(name: String) -> void:
	await get_tree().process_frame
	if _out != "":
		CaptureUtil.save_viewport(get_viewport(), "%s/gresille_%s.png" % [_out, name])
	print("shot ", name)


func _cast(p: Node2D, slot: int, aim: Variant = null) -> void:
	p.spells.aim_override = aim
	var ok: bool = p.spells.cast(slot)
	p.spells.aim_override = null
	print("CAST slot=%d ok=%s" % [slot, ok])


func _charge(kit: GresilleKit, e: Node, n: int) -> void:
	for i in n:
		kit.apply_static(e, false)


func _run() -> void:
	TestMode.begin()
	RunState.character = &"gresille"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 11)
	add_child(_main)
	await _main.game_ready
	await _wait(0.5)
	TestMode.set_flag(&"god", true)
	TestMode.set_flag(&"cdr_full", true)
	TestMode.set_flag(&"freeze_ai", true)
	var p: Node2D = _main.player
	var kit: GresilleKit = p.kit as GresilleKit
	var d: Director = _main.director
	d.spawning_enabled = false
	p.set(&"auto_cast_spells", false)
	var pp := p.global_position
	var offs := [Vector2(200, -20), Vector2(260, 70), Vector2(330, -90), Vector2(430, 10), Vector2(300, 190),
			Vector2(-210, 100), Vector2(-300, -120), Vector2(120, 260), Vector2(520, 150), Vector2(180, -170)]
	var mobs: Array = []
	for o in offs:
		mobs.append(d.spawn_enemy(3, pp + o))
	await _wait(0.8)
	await _shot("00_base")

	_cast(p, 1)
	await _wait(0.2)
	await _shot("01_arc")
	await _wait(0.6)

	for i in mobs.size():
		var e: Node = mobs[i]
		if is_instance_valid(e):
			_charge(kit, e, 5 if i < 3 else (4 if i < 5 else 3))
	await _wait(0.7)
	await _shot("02_crawl")

	_cast(p, 2)
	await _wait(0.12)
	await _shot("03_decharge")
	await _wait(0.8)

	_cast(p, 3)
	await _wait(0.9)
	await _shot("04_terre")
	await _wait(5.0)

	for e in mobs:
		if is_instance_valid(e):
			_charge(kit, e, 4)
	_cast(p, 4)
	await _wait(0.6)
	await _shot("05_orage_a")
	await _wait(1.2)
	await _shot("05_orage_b")
	await _wait(2.0)

	p.dodge(Vector2(1, 0))
	await _wait(0.25)
	await _shot("06_sillage")
	await _wait(1.0)

	# Variantes
	p.character.spells[2] = GresilleKit.variant(3, GresilleKit.V_PARATONNERRE)
	_cast(p, 3, p.global_position + Vector2(300, 0))
	await _wait(0.2)
	await _shot("07_tige")
	await _wait(0.75)
	await _shot("07_tige_telegraphe")
	await _wait(0.25)
	await _shot("07_tige_foudre")
	await _wait(5.0)

	p.character.spells[3] = GresilleKit.variant(4, GresilleKit.V_LEYDE)
	for e in mobs:
		if is_instance_valid(e):
			_charge(kit, e, 4)
	_cast(p, 4, p.global_position + Vector2(300, 60))
	await _wait(0.4)
	await _shot("08_leyde_vol")
	await _wait(0.5)
	await _shot("08_leyde_eclat")
	await _wait(0.3)
	await _shot("08_leyde_anneau")
	await _wait(0.5)

	print("capture terminée")
	get_tree().quit()
