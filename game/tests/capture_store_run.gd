extends Node
## Captures store 1920x1080 dans une vraie run (SANS --headless : le rendu demande une fenêtre).
## Aucun panneau de test : seuls l'invulnérabilité et la mise en scène (monstres, sorts, objets) sont forcés ici.
## godot --path game res://tests/capture_store_run.tscn -- --out=<fichier.png> --scene=<horde|boss|forge|coop>
##   [--force-map=<id>] [--char=<id>] [--floor=<n>] [--seed=<n>]
## Voir docs/store/README.md pour les commandes exactes de chaque image.

class FakeSource extends InputSource:
	func _init(dev: int) -> void:
		kind = Kind.PAD
		device = dev

	func mode() -> int:
		return Platform.InputMode.GAMEPAD

	func move_vector() -> Vector2:
		return Vector2.ZERO

	func aim_vector() -> Vector2:
		return Vector2.ZERO

	func is_pressed(_action: StringName) -> bool:
		return false

	func just_pressed(_action: StringName) -> bool:
		return false

	func just_released(_action: StringName) -> bool:
		return false

	func pointer_world(_canvas: CanvasItem) -> Variant:
		return null

	func owns_event(_event: InputEvent) -> bool:
		return false


var _out := "user://store.png"
var _scene := "horde"
var _char := &"ardent"
var _floor := 1
var _seed := 5
var _main: Node


func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return def


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_out = _arg("out", _out)
	_scene = _arg("scene", _scene)
	_char = StringName(_arg("char", "ardent"))
	_floor = int(_arg("floor", "1"))
	_seed = int(_arg("seed", "5"))
	Platform.set_input_mode(Platform.InputMode.KBM)
	_run.call_deferred()


func _ring(d: Director, center: Vector2, n: int, r0: float, r1: float, elite_every: int) -> void:
	for i in n:
		var a := TAU * float(i) / float(n) + float(i % 3) * 0.37
		var r := lerpf(r0, r1, float((i * 7) % 11) / 10.0)
		d.spawn_enemy(1 + (i % 3), center + Vector2.from_angle(a) * r, elite_every > 0 and i % elite_every == 0)


func _run() -> void:
	get_window().size = Vector2i(1920, 1080)
	RunState.character = _char
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", _seed)
	_main.set(&"save_path", "user://test_capture_store.json")
	if _scene == "coop":
		var chars: Array[StringName] = [&"ardent", &"averse", &"tocsin", &"vigie"]
		var setup: Array[Dictionary] = []
		for i in clampi(int(_arg("players", "2")), 2, 4):
			setup.append(_main.party_entry(FakeSource.new(i), chars[i]))
		_main.set(&"party_setup", setup)
	add_child(_main)
	await _main.game_ready
	await _f(3)
	var stage: StageManager = _main.get(&"stage")
	while RunState.stage < _floor:
		stage.floor_cleared = true
		stage.teleporter.set_active(true)
		stage.teleporter.used.emit()
		await _f(10)
		# carton d'étage puis choix du présage : on l'écarte (aucun présage), jeu relancé
		for i in 60:
			await get_tree().create_timer(0.25).timeout
			var om = _main.get(&"omen_screen")
			if om != null and is_instance_valid(om):
				(om as OmenScreen).chosen.emit(StringName())
				await _f(3)
				get_tree().paused = false
				break
	await get_tree().create_timer(4.5).timeout
	print("carte ", stage.map_id)
	var p: Node2D = _main.player
	for pl in _main.get(&"players"):
		pl.grant_invulnerability(1.0e6)
	var d: Director = _main.director
	d.spawning_enabled = false
	var hud = _main.get(&"hud")
	_items()
	await _f(5)
	match _scene:
		"horde", "coop":
			await _horde(d, p)
		"boss":
			await _boss(d, p)
		"forge":
			await _forge(hud)
		"raid", "final":
			await _boss_by_id(d, p)
		"chest":
			await _chest(p)
		"endrun":
			await _end_run()
		"landmark":
			await _landmark(d, p)
	await _f(8)
	var img := CaptureUtil.save_viewport(get_viewport(), _out)
	print("SAVED ", _out, " ", img.get_size() if img else "null")
	get_tree().quit()


func _items() -> void:
	var ids := ItemDB.all_ids()
	for k in [1, 5, 12, 20, 33, 41, 47, 3, 8, 15, 22]:
		var id := StringName(ids[k % ids.size()])
		if not ItemDB.get_item(id).get("craft_only", false):
			RunState.add_item(id)


func _unpause(hud) -> void:
	if hud != null and hud.pause_menu.is_open and not hud.pause_menu.inventory_mode:
		hud.pause_menu._close()


func _horde(d: Director, p: Node2D) -> void:
	var cam: Camera2D = _main.camera
	if cam != null:
		cam.zoom = Iso.camera_zoom(1.0)
	var pp := p.global_position
	_ring(d, pp, 30, 330.0, 560.0, 9)
	_ring(d, pp, 26, 560.0, 860.0, 0)
	await _f(20)
	for step in 4:
		for s in [2, 3, 4]:
			p.spells.cast(s)
		await get_tree().create_timer(0.5).timeout
		_ring(d, pp, 8, 360.0, 760.0, 0)
		_unpause(_main.get(&"hud"))
	await get_tree().create_timer(0.25).timeout
	_unpause(_main.get(&"hud"))


func _boss(d: Director, p: Node2D) -> void:
	var cam: Camera2D = _main.camera
	if cam != null:
		cam.zoom = Iso.camera_zoom(0.75)
	var pp := p.global_position
	var b := d.spawn_boss(&"etage", pp + Vector2(330, 170))
	_ring(d, pp, 12, 300.0, 600.0, 0)
	for i in 6:
		await get_tree().create_timer(0.6).timeout
		for s in [2, 3, 4]:
			p.spells.cast(s)
		if is_instance_valid(b) and b.has_method(&"take_damage"):
			b.take_damage(b.max_hp * 0.05)
		_unpause(_main.get(&"hud"))


## Boss de raid (--boss=drowned_idol|flood_gunner|salt_king) ou boss final (--scene=final, étage 5, rain_sower).
func _boss_by_id(d: Director, p: Node2D) -> void:
	var cam: Camera2D = _main.camera
	if cam != null:
		cam.zoom = Iso.camera_zoom(0.7)
	var pp := p.global_position
	var def_id := "rain_sower" if _scene == "final" else "drowned_idol"
	var kind: StringName = &"final" if _scene == "final" else &"etage"
	var b := TestTools.spawn_boss(get_tree(), StringName(_arg("boss", def_id)), kind, pp + Vector2(0, -330))
	_ring(d, pp, 8, 320.0, 600.0, 0)
	for i in 8:
		await get_tree().create_timer(0.6).timeout
		for s in [2, 3, 4]:
			p.spells.cast(s)
		if is_instance_valid(b) and b.has_method(&"take_damage") and i < 3:
			b.take_damage(b.max_hp * 0.04)
		_unpause(_main.get(&"hud"))


## Ouverture d'un coffre (choix d'objet) : vrai flux Chest -> ChestUI.
func _chest(p: Node2D) -> void:
	RunState.add_gold(5000.0)
	var c := TestTools.spawn_chest(get_tree(), StringName(_arg("chest", "large")), null) as Chest
	await _f(10)
	c.try_open(p)
	await get_tree().create_timer(2.5).timeout


## Récap de victoire (EndRunScreen) avec médaillons d'épreuves ; le profil n'est pas touché (end_run non appelé).
func _end_run() -> void:
	var info: Dictionary = _main.end_info(true, &"victory")
	info["epreuve_grades"] = [&"parfait", &"parfait", &"bien", &"parfait", &"fait"]
	info["rubies"] = 42
	info["epreuve_rubies"] = 3
	info["kills"] = 1873
	info["unlocks"] = []
	RunState.running = false
	var scr := EndRunScreen.create(info)
	_main.add_child(scr)
	await get_tree().create_timer(3.0).timeout


## Repère d'une variante B (prop fixe : noria, puits...) : téléporte le joueur dessus, horde légère autour.
func _landmark(d: Director, p: Node2D) -> void:
	var cam: Camera2D = _main.camera
	if cam != null:
		cam.zoom = Iso.camera_zoom(0.85)
	print("repere ", TestMaps.teleport_to_landmark(get_tree()))
	await get_tree().create_timer(1.5).timeout
	var pp := p.global_position
	_ring(d, pp, 10, 380.0, 700.0, 0)
	await _f(30)
	for s in [2, 3]:
		p.spells.cast(s)
	await get_tree().create_timer(0.6).timeout
	_unpause(_main.get(&"hud"))


func _forge(hud) -> void:
	for id in ["etincelle", "lentille_aiguisee", "pierre_a_aiguiser", "flocon", "pierre_a_aiguiser"]:
		RunState.add_item(StringName(id))
	var st := RunState.local()
	if st != null:
		st.add_catalyst(1)
	await _f(5)
	hud.pause_menu.open_inventory(&"forge")
	await _f(10)
