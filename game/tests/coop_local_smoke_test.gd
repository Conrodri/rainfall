extends Node
## Coop locale, fumée de bout en bout dans le VRAI Main (étape 2, intégration) : deux joueurs inscrits par
## `Main.party_setup` avec deux sources d'entrée factices (aucun écran de jonction : étape 4).
## - inscription avant RunState.start_run (party_size 2, niveau de départ coop), deux nœuds de joueur, une seule caméra ;
## - étage 1 joué en accéléré (déplacements scriptés, monstres, petits piliers puis gros pilier, boss tués) ;
## - Events.enemy_damaged_by porte le tireur ; pas de pause globale des écrans en coop ;
## - le joueur 2 meurt : spectateur (pas de player_died, pas de party_wiped), la run continue ;
## - téléporteur : compte à rebours coop, puis étage 2 où le joueur 2 est ressuscité ;
## - les deux joueurs tombent : party_wiped -> fin de run (défaite), récap avec le tableau d'équipe et party_n = 2.
## godot --headless --path game res://tests/coop_local_smoke_test.tscn  -> RESULT: OK

const SAVE := "user://test_coop_smoke.json"
const KILL_GUARD := 9000

## Source d'entrée scriptée (manette précise).
class FakeSource extends InputSource:
	var mv := Vector2.ZERO
	var aim := Vector2.ZERO
	var just := {}

	func _init(dev: int) -> void:
		kind = Kind.PAD
		device = dev

	func mode() -> int:
		return Platform.InputMode.GAMEPAD

	func move_vector() -> Vector2:
		return mv

	func aim_vector() -> Vector2:
		return aim

	func is_pressed(_action: StringName) -> bool:
		return false

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
var _legacy_died := 0
var _died_by: Array[int] = []
var _spectating: Array[int] = []
var _resurrected: Array[int] = []
var _wiped := 0
var _dmg_by := {} ## player_id -> nombre de coups (Events.enemy_damaged_by)
var _ended := [false, false, -1] ## [émis, victoire, rubis]


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Events.player_died.connect(func() -> void: _legacy_died += 1)
	Events.player_died_by.connect(func(id: int) -> void: _died_by.append(id))
	Events.player_spectating.connect(func(id: int) -> void: _spectating.append(id))
	Events.player_resurrected.connect(func(id: int) -> void: _resurrected.append(id))
	Events.party_wiped.connect(func() -> void: _wiped += 1)
	Events.enemy_damaged_by.connect(func(pid: int, _e: Node2D, _a: float, _c: bool, _el: StringName) -> void:
		_dmg_by[pid] = int(_dmg_by.get(pid, 0)) + 1)

	_src = [FakeSource.new(90), FakeSource.new(91)]
	# Ce test déroule les petits piliers à mini-boss ; les épreuves (actives par défaut) les remplacent : étage classique ici,
	# la coop avec épreuves est couverte par coop_stage_test et epreuve_test.
	Balance.EPREUVES_ENABLED = false
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 4242)
	var setup: Array[Dictionary] = [_main.party_entry(_src[0], &"ardent"), _main.party_entry(_src[1], &"averse")]
	_main.set(&"party_setup", setup)
	_main.run_ended.connect(func(v: bool, r: int) -> void: _ended[0] = true; _ended[1] = v; _ended[2] = r)
	add_child(_main)
	await _main.game_ready
	await _frames(3)

	print("Inscription")
	var players: Array = _main.get(&"players")
	_check("2 joueurs inscrits avant le jeu, 2 nœuds", Players.count() == 2 and players.size() == 2)
	var p0: Node2D = players[0]
	var p1: Node2D = players[1]
	_check("joueur 1 = Main.player, ids 0 et 1", p0 == _main.player and Players.by_id(0) == p0 and Players.by_id(1) == p1 and int(p1.get(&"player_id")) == 1)
	_check("sources par joueur", Players.input_of(0) == _src[0] and Players.input_of(1) == _src[1])
	_check("party_size 2 dès l'étage 1", RunState.party_size == 2, str(RunState.party_size))
	_check("personnages par emplacement", RunState.player_state(0).character == &"ardent" and RunState.player_state(1).character == &"averse")
	_check("niveau de départ coop", RunState.player_state(1).level == Balance.player_start_level(2) and RunState.local().level == Balance.player_start_level(2))
	var cam0 := p0.get_node_or_null(^"Camera2D") as Camera2D
	var cam1 := p1.get_node_or_null(^"Camera2D") as Camera2D
	_check("une seule caméra active (joueur 1)", cam0 != null and cam0.enabled and (cam1 == null or not cam1.enabled))

	print("Étage 1")
	var stage: StageManager = _main.get(&"stage")
	var director: Director = _main.get(&"director")
	for p in players:
		(p as Node2D).call(&"grant_invulnerability", 99999.0)
	# déplacements scriptés indépendants
	var a0 := p0.global_position
	var a1 := p1.global_position
	_src[0].mv = Vector2(1.0, 0.0)
	_src[1].mv = Vector2(-1.0, 0.0)
	await _frames(20)
	_src[0].mv = Vector2.ZERO
	_src[1].mv = Vector2.ZERO
	_check("chacun bouge avec sa source", p0.global_position.distance_to(a0) > 30.0 and p1.global_position.distance_to(a1) > 30.0 \
			and (p0.global_position - a0).dot(p1.global_position - a1) < 0.0)
	# monstres autour des deux joueurs, sort 1 automatique de chacun
	var total0 := director.spawned_total
	director.credits = 150.0
	director.wave_credits = 150.0
	director.trigger_wave()
	for i in 240:
		_note_activity()
		await get_tree().physics_frame
	_check("monstres apparus", director.spawned_total > total0, str(director.spawned_total - total0))
	_check("Events.enemy_damaged_by porte le tireur", _dmg_by.has(0) or _dmg_by.has(1), str(_dmg_by))
	for p: Pillar in stage.pillars:
		if p.kind == Pillar.Kind.SMALL:
			await _clear_pillar(p, players)
	var big: Pillar = stage.pillars.back()
	_check("gros pilier déverrouillé", big.state == Pillar.STATE_READY)
	await _clear_pillar(big, players)
	_check("étage 1 terminé, sortie ouverte", stage.floor_cleared and stage.teleporter.active)

	print("Mort du joueur 2 : spectateur")
	_kill(p1)
	await _frames(3)
	_check("joueur 2 spectateur", bool(p1.get(&"dead")) and RunState.player_state(1).spectating and not Players.is_alive(1) and _spectating == [1])
	_check("player_died_by(1) seul, sans player_died ni party_wiped", _died_by == [1] and _legacy_died == 0 and _wiped == 0)
	_check("la run continue", not _main.run_over)

	print("Téléporteur coop")
	_check("compte à rebours lancé", stage.teleporter.use() and stage.teleporter.countdown_left > 0.0)
	_check("pas encore parti", RunState.stage == 1)
	stage.teleporter.tick(Balance.COOP_TELEPORT_COUNTDOWN_S + 1.0)
	await _frames(4)
	_check("étage 2", RunState.stage == 2, str(RunState.stage))
	_check("joueur 2 ressuscité", _resurrected.has(1) and not bool(p1.get(&"dead")) and p1.visible and Players.is_alive(1) and not RunState.player_state(1).spectating)
	_check("party_size gardé à 2", RunState.party_size == 2, str(RunState.party_size))
	await _resolve_omen()

	print("Wipe : fin de run")
	for p in players:
		(p as Node2D).set(&"_invuln", 0.0)
	_kill(p0)
	await _frames(2)
	_check("joueur 1 spectateur, la run continue", RunState.local().spectating and _wiped == 0 and not _main.run_over)
	_kill(p1)
	await _frames(2)
	_check("party_wiped émis une fois", _wiped == 1 and _legacy_died == 0)
	var guard := 0
	while not _main.run_over and guard < 300:
		await _frames(1)
		guard += 1
	_check("fin de run (défaite)", _main.run_over and bool(_ended[0]) and not bool(_ended[1]))
	var es: Variant = _main.get(&"end_screen")
	_check("récap affiché", es != null)
	var info: Dictionary = _main.end_info(false, &"death")
	_check("récap : party_n 2 et tableau d'équipe", int(info.get("party_n", 0)) == 2 and (info.get("players", []) as Array).size() == 2, str(info.get("party_n")))
	_check("rubis = PartyRecap.rubies", int(_ended[2]) == int(_main.last_rubies))
	_finish()


## Les sources factices n'émettent pas d'événements : activité notée à la main (sinon absence > MULTI_AFK_S).
func _note_activity() -> void:
	Players.note_activity(0)
	Players.note_activity(1)


func _kill(p: Node2D) -> void:
	p.set(&"_invuln", 0.0)
	p.set(&"hp", 1.0)
	p.call(&"take_damage", float(p.get(&"max_hp")) * 10.0, null)


func _clear_pillar(p: Pillar, players: Array) -> void:
	for pl in players:
		(pl as Node2D).global_position = p.global_position + Vector2(24, 24)
		p._on_body_entered(pl)
	var ok := p.can_interact() and p.activate()
	var boss: Enemy = p.get(&"_boss")
	_check("pilier %s : boss apparu" % ("gros" if p.kind == Pillar.Kind.BIG else "petit"), ok and boss != null and boss.active)
	if boss == null:
		return
	if p.kind == Pillar.Kind.BIG:
		for i in 95:
			p.tick(1.0)
	var guard := 0
	while boss.active and guard < KILL_GUARD:
		_note_activity()
		for pl in players:
			(pl as Node2D).set(&"hp", (pl as Node2D).get(&"max_hp"))
		if boss.hp > 0.0:
			boss.take_damage(boss.max_hp * 0.2, false, &"", {"by": 1})
		await get_tree().physics_frame
		guard += 1
	await _frames(2)
	_check("boss tué, pilier terminé", not boss.active and p.state == Pillar.STATE_DONE, "guard %d, état %s" % [guard, p.state])


## Présage de l'étage 2 : en coop, l'écran ne met PAS le jeu en pause.
func _resolve_omen() -> void:
	if not RunState.omen_pending:
		return
	var guard := 0
	while _main.omen_screen == null and guard < 900:
		if is_instance_valid(_main.floor_card):
			_main.floor_card.skip()
		await _frames(1)
		guard += 1
	_check("écran de présage", _main.omen_screen != null)
	_check("coop : présage sans pause globale", not get_tree().paused)
	if _main.omen_screen != null:
		_main.omen_screen.choose(0)
	await _frames(2)


func _finish() -> void:
	Balance.EPREUVES_ENABLED = true
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().paused = false
	get_tree().quit(0 if _fails == 0 else 1)
