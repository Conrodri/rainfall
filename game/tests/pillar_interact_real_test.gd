extends Node
## Activation des piliers et des Épreuves par le VRAI chemin d'interaction (régression signalée le 12/11/2026 : « je
## ne peux plus activer les piliers » sur PC). Main réel, épreuves actives (réglage par défaut) : le joueur est posé
## contre l'objet (corps physique, signal body_entered), l'invite du HUD doit le viser, puis la touche E (événement
## clavier réel, action « interact ») le lance. Épreuves (petits piliers) puis gros pilier, étages 1 et 2, cartes A
## puis variantes B ; enfin coop locale à 2 joueurs (PlayerInteract, source par joueur), le joueur 2 lance l'épreuve.
## Cause corrigée : les sous-classes d'Epreuve redéfinissaient _init() sans super(), donc sans le corps de contact
## de Pillar._init (couche 1, aucun cercle) : aucune invite, épreuve impossible à lancer, gros pilier verrouillé.
## godot --headless --path game res://tests/pillar_interact_real_test.tscn  -> RESULT: OK

const KILL_GUARD := 6000

## Source d'entrée scriptée (coop : manette du joueur 2).
class FakeSource extends InputSource:
	var just := {}

	func _init(dev: int) -> void:
		kind = Kind.PAD
		device = dev

	func mode() -> int:
		return Platform.InputMode.GAMEPAD

	func move_vector() -> Vector2:
		return Vector2.ZERO

	func aim_vector() -> Vector2:
		return Vector2.ZERO

	func is_pressed(action: StringName) -> bool:
		return bool(just.get(action, false))

	func just_pressed(action: StringName) -> bool:
		return bool(just.get(action, false))

	func just_released(_action: StringName) -> bool:
		return false

	func pointer_world(_canvas: CanvasItem) -> Variant:
		return null

	func owns_event(_event: InputEvent) -> bool:
		return false


var _main: Node
var _fails := 0
var _src: Array[FakeSource] = []


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _key(pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.physical_keycode = KEY_E
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Appui clavier sur E (une image enfoncée).
func _press_e() -> void:
	_key(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_key(false)
	await get_tree().process_frame


## Écrans qui mettent le jeu en pause en solo (montée de niveau, carte d'étage, présage) : réglés au plus vite.
func _unblock() -> void:
	for i in 600:
		if is_instance_valid(_main.get(&"floor_card")):
			_main.floor_card.skip()
		if _main.get(&"omen_screen") != null and is_instance_valid(_main.omen_screen):
			_main.omen_screen.choose(0)
		var lu: Variant = _main.get(&"levelup_screen")
		if lu != null and is_instance_valid(lu) and (lu as Node).has_method(&"choose"):
			lu.choose(0)
		if not get_tree().paused:
			return
		await get_tree().process_frame


## Objet à viser pour lancer `p` : la cloche pour la Tenue, la source pour la Veine (ces piliers n'ont pas d'invite),
## sinon le pilier lui-même.
func _interact_node(p: Pillar) -> Node2D:
	if p is EpreuveHold:
		return (p as EpreuveHold).bell
	if p is EpreuveVein:
		return (p as EpreuveVein).source
	return p


## Le joueur `who` est posé contre l'objet ; l'invite doit le viser, puis l'interaction doit le lancer.
func _activate(p: Pillar, label: String, who: Node2D, coop_src: FakeSource = null) -> void:
	await _unblock()
	var obj := _interact_node(p)
	who.global_position = obj.global_position + Vector2(20, 12)
	await _frames(6)
	if coop_src == null:
		var hud: Node = _main.get(&"hud")
		var tgt: Variant = hud.get(&"interact_target")
		_check("%s : invite sur l'objet" % label, tgt == obj, "cible %s, contact %s, état %s, couche %d, formes %d" % [str(tgt),
			str(p.get(&"_player_touching")), p.state, p.collision_layer, p.get_children().filter(func(c: Node) -> bool: return c is CollisionShape2D).size()])
		await _press_e()
	else:
		var pi: PlayerInteract = who.get(&"interaction")
		_check("%s : cible du joueur 2" % label, pi.enabled and pi.target == obj, "activé %s, cible %s" % [str(pi.enabled), str(pi.target)])
		coop_src.just[&"interact"] = true
		await _frames(1)
		coop_src.just.clear()
	await _frames(2)
	if p is EpreuveHold: # maintien : la cloche lance l'épreuve
		for i in 90:
			if p.state == Pillar.STATE_ACTIVE:
				break
			await _frames(1)
	_check("%s : lancé" % label, p.state == Pillar.STATE_ACTIVE, "état %s" % p.state)


## Termine `p` (épreuve résolue, boss tué) sans passer par le combat.
func _finish_pillar(p: Pillar, players: Array) -> void:
	if p.state != Pillar.STATE_ACTIVE:
		p.activate()
	if p is Epreuve:
		(p as Epreuve).finish_now(&"fait")
	if p.kind == Pillar.Kind.BIG:
		for i in 95:
			p.tick(1.0)
	await _frames(2)
	var boss: Variant = p.get(&"_boss")
	var guard := 0
	while boss != null and is_instance_valid(boss) and (boss as Enemy).active and guard < KILL_GUARD:
		for pl in players:
			(pl as Node2D).set(&"hp", (pl as Node2D).get(&"max_hp"))
		if (boss as Enemy).hp > 0.0:
			(boss as Enemy).take_damage((boss as Enemy).max_hp * 0.25, false)
		await get_tree().physics_frame
		guard += 1
	await _frames(3)
	_check("pilier terminé", p.state == Pillar.STATE_DONE, "état %s" % p.state)


func _play_floor(players: Array, tag: String) -> void:
	var stage: StageManager = _main.get(&"stage")
	var smalls: Array[Pillar] = []
	var big: Pillar = null
	for p: Pillar in stage.pillars:
		if p.kind == Pillar.Kind.SMALL:
			smalls.append(p)
		else:
			big = p
	var n_ep := smalls.filter(func(p: Pillar) -> bool: return p is Epreuve).size()
	print("%s : %s, %d épreuve(s), %d petit(s) pilier(s)" % [tag, stage.map_id, n_ep, smalls.size() - n_ep])
	_check("%s : épreuves présentes" % tag, n_ep > 0)
	_check("%s : gros pilier verrouillé au départ" % tag, big != null and big.state == Pillar.STATE_LOCKED)
	for p in smalls:
		var what := ("épreuve %s" % (p as Epreuve).verb) if p is Epreuve else "petit pilier"
		await _activate(p, "%s, %s" % [tag, what], players[0])
		await _finish_pillar(p, players)
	if big == null:
		return
	_check("%s : gros pilier déverrouillé" % tag, big.state == Pillar.STATE_READY, String(big.state))
	await _activate(big, "%s, gros pilier" % tag, players[0])
	await _finish_pillar(big, players)


func _start(variant: String, coop: bool) -> Array:
	FloorPlan.force_variant = variant
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 4242)
	_main.set(&"save_path", "user://test_pillar_interact_real.json")
	if coop:
		_src = [FakeSource.new(90), FakeSource.new(91)]
		var setup: Array[Dictionary] = [_main.party_entry(_src[0], &"ardent"), _main.party_entry(_src[1], &"averse")]
		_main.set(&"party_setup", setup)
	add_child(_main)
	await _main.game_ready
	await _frames(4)
	var players: Array = _main.get(&"players")
	for p in players:
		(p as Node2D).call(&"grant_invulnerability", 99999.0)
	var director: Node = _main.get(&"director")
	director.set(&"spawning_enabled", false)
	return players


func _stop() -> void:
	get_tree().paused = false
	_main.queue_free()
	await _frames(3)


func _run() -> void:
	Platform.input_mode = Platform.InputMode.KBM
	Balance.EPREUVES_ENABLED = true # réglage par défaut du jeu (docs/Design_Epreuves.md §14)
	for variant in ["A", "B"]:
		print("Variante ", variant)
		var players := await _start(variant, false)
		await _play_floor(players, "étage 1 (%s)" % variant)
		var stage: StageManager = _main.get(&"stage")
		_check("étage 1 (%s) : sortie ouverte" % variant, stage.floor_cleared)
		stage.next_stage()
		await _frames(4)
		await _unblock()
		_check("étage 2 atteint", RunState.stage == 2, str(RunState.stage))
		await _play_floor(players, "étage 2 (%s)" % variant)
		await _stop()

	print("Coop locale à 2 joueurs")
	var players := await _start("A", true)
	for p in players:
		Players.note_activity(int(p.get(&"player_id")))
	_check("coop : interaction par joueur active", Hud.is_local_coop())
	var stage: StageManager = _main.get(&"stage")
	var ep: Pillar = null
	for p: Pillar in stage.pillars:
		if p is Epreuve and not (p is EpreuveHold):
			ep = p
			break
	_check("coop : épreuve trouvée", ep != null)
	if ep != null:
		(players[0] as Node2D).global_position = ep.global_position + Vector2(2000, 2000)
		await _activate(ep, "coop, épreuve %s par le joueur 2" % (ep as Epreuve).verb, players[1], _src[1])
	await _stop()

	FloorPlan.force_variant = ""
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
