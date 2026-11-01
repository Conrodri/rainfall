extends Node
## Contrats coop 1-4 (étape 1, docs/multi/Archi_Reseau.md §3) : registre Players, PlayerState, façade RunState solo,
## signaux Events avec identité du joueur, sources d'entrée par appareil.
## godot --headless --path game res://tests/players_registry_test.tscn  -> RESULT: OK

class FakePlayer extends Node2D:
	var dead := false


var _fails := 0
var _log: Array = []


func _ready() -> void:
	await get_tree().process_frame
	_solo_implicit()
	_facade_solo()
	_registry_four()
	_events_identity()
	_input_sources()
	_cleanup()
	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails else 0)


# --- Solo : joueur 1 implicite (groupe `player`) ----------------------------------------
func _solo_implicit() -> void:
	_check("aucun joueur : count 0", Players.count() == 0)
	_check("aucun joueur : party_count 1", RunState.party_count() == 1)
	var p := _fake(Vector2(100, 0))
	_check("implicite : count 1", Players.count() == 1)
	_check("implicite : local = nœud du groupe", Players.local() == p)
	_check("implicite : id 0", Players.id_of(p) == 0 and Players.local_id() == 0)
	_check("implicite : état = RunState.local()", Players.state_of(0) == RunState.local())
	_check("implicite : source globale", Players.input_of(0) != null and Players.input_of(0).kind == InputSource.Kind.GLOBAL)
	_check("implicite : nearest", Players.nearest(Vector2.ZERO) == p)
	_check("implicite : alive", Players.alive().size() == 1 and Players.alive_count() == 1)
	_check("implicite : n = 1", Players.party_size_for_scaling() == 1)
	p.dead = true
	_check("implicite mort : alive vide", Players.alive().is_empty() and Players.nearest(Vector2.ZERO) == null)
	_check("implicite mort : all garde le nœud", Players.all().size() == 1)
	p.dead = false
	p.remove_from_group(&"player")
	p.queue_free()


# --- Façade RunState (joueur 1) : chiffres et signaux solo inchangés ------------------
func _facade_solo() -> void:
	RunState.character = &"averse"
	RunState.loadout = {2: &"x"}
	RunState.start_run(&"moyen", 1234)
	var p1 := RunState.local()
	_check("start_run : un seul PlayerState", RunState.player_states.size() == 1 and RunState.player_states[0] == p1)
	_check("start_run : or 0, niveau 1, XP 0", RunState.gold == 0.0 and RunState.level == 1 and RunState.xp == 0.0)
	_check("start_run : personnage et sorts gardés", RunState.character == &"averse" and p1.loadout.get(2) == &"x")
	_check("party_size 1", RunState.party_size == 1)
	_check("D solo = Balance.difficulty sans n", RunState.difficulty() == Balance.difficulty(RunState.active_time_s, 1, Balance.MODES[&"moyen"]))
	var got := {"gold": [], "spent": [], "lv": [], "item": [], "xp": 0, "scrap": 0, "items_changed": 0}
	var c_gold := func(g: float) -> void: got["gold"].append(g)
	var c_spent := func(a: float) -> void: got["spent"].append(a)
	var c_lv := func(l: int) -> void: got["lv"].append(l)
	var c_item := func(i: StringName, n: int) -> void: got["item"].append([i, n])
	var c_xp := func(_x: float, _r: float) -> void: got["xp"] += 1
	var c_scrap := func() -> void: got["scrap"] += 1
	var c_ic := func() -> void: got["items_changed"] += 1
	RunState.gold_changed.connect(c_gold)
	RunState.gold_spent.connect(c_spent)
	RunState.level_up.connect(c_lv)
	RunState.item_added.connect(c_item)
	RunState.xp_changed.connect(c_xp)
	RunState.scrap_changed.connect(c_scrap)
	RunState.items_changed.connect(c_ic)
	RunState.add_gold(50.0)
	_check("add_gold : façade et PlayerState", RunState.gold == 50.0 and p1.gold == 50.0)
	_check("gold_changed relayé", got["gold"] == [50.0])
	_check("spend_gold refusé au-delà", not RunState.spend_gold(80.0) and RunState.gold == 50.0)
	_check("spend_gold", RunState.spend_gold(20.0) and is_equal_approx(RunState.gold, 30.0))
	_check("gold_spent relayé", got["spent"] == [20.0])
	RunState.add_xp(Balance.xp_required(1) + 0.5)
	_check("add_xp : niveau 2", RunState.level == 2 and p1.level == 2 and got["lv"] == [2] and got["xp"] == 1)
	RunState.add_item(&"trefle")
	RunState.add_item(&"trefle")
	_check("add_item : stacks 2", RunState.stacks(&"trefle") == 2 and p1.stacks(&"trefle") == 2)
	_check("items : même dictionnaire", RunState.items == p1.items and is_same(RunState.items, p1.items))
	_check("item_added relayé", got["item"] == [[&"trefle", 1], [&"trefle", 2]])
	_check("remove_item", RunState.remove_item(&"trefle") and RunState.stacks(&"trefle") == 1 and got["items_changed"] == 1)
	RunState.add_counter("t.kills", 3.0)
	_check("compteurs du joueur 1", float(RunState.counters.get("t.kills", 0.0)) == 3.0 and p1.counters == RunState.counters)
	RunState.compass_set("Or")
	_check("Boussole", RunState.compass_ready_for(&"petit") and p1.compass["charges"] == Balance.BOUSSOLE_CHARGES)
	_check("scories", RunState.add_scrap(&"commun") and RunState.scrap_total() == 1 and p1.scrap_of(&"commun") == 1 and got["scrap"] == 1)
	RunState.gold = 77.0
	_check("écriture directe RunState.gold", p1.gold == 77.0)
	RunState.add_party_gold(10.0)
	_check("or d'équipe solo = add_gold", RunState.gold == 87.0)
	RunState.add_party_xp(0.0)
	var d := RunState.to_dict()
	_check("sauvegarde solo : pas de clé players", not d.has("players"))
	_check("sauvegarde solo : clés historiques", d.get("gold") == 87.0 and d.get("level") == 2 and d.get("character") == "averse" and (d.get("items") as Dictionary).get("trefle") == 1)
	var gained := RunState.convert_gold_to_xp(13.0)
	_check("or -> XP (0,25 / or)", is_equal_approx(gained, 25.0) and RunState.gold == 0.0)
	RunState.from_dict(d)
	_check("relecture solo", RunState.gold == 87.0 and RunState.level == 2 and RunState.stacks(&"trefle") == 1 and RunState.player_states.size() == 1 and RunState.local() == p1)
	for pair in [[RunState.gold_changed, c_gold], [RunState.gold_spent, c_spent], [RunState.level_up, c_lv], [RunState.item_added, c_item], [RunState.xp_changed, c_xp], [RunState.scrap_changed, c_scrap], [RunState.items_changed, c_ic]]:
		(pair[0] as Signal).disconnect(pair[1])


# --- Registre : 4 joueurs factices ------------------------------------------------------
func _registry_four() -> void:
	var nodes: Array[FakePlayer] = []
	var pos := [Vector2(0, 0), Vector2(500, 0), Vector2(0, 300), Vector2(-400, -400)]
	for i in 4:
		nodes.append(_fake(pos[i]))
	var party_events: Array = []
	var c_party := func(n: int) -> void: party_events.append(n)
	Events.party_changed.connect(c_party)
	for i in 4:
		_check("inscription %d" % i, Players.register(nodes[i]) == i)
	var fifth := _fake(Vector2.ZERO)
	_check("5e joueur refusé", Players.register(fifth) == -1)
	nodes.append(fifth) # nettoyé avec les autres
	_check("party_changed 1..4", party_events == [1, 2, 3, 4])
	Events.party_changed.disconnect(c_party)
	_check("count 4", Players.count() == 4 and RunState.party_count() == 4)
	_check("local = joueur 1", Players.local() == nodes[0] and Players.local_id() == 0)
	_check("by_id / id_of", Players.by_id(2) == nodes[2] and Players.id_of(nodes[3]) == 3)
	_check("état du joueur 1 = façade", Players.state_of(0) == RunState.local())
	_check("états distincts", Players.state_of(1) != Players.state_of(0) and Players.state_of(3) == RunState.player_states[3])
	_check("nearest (480, 10) -> joueur 2", Players.nearest(Vector2(480, 10)) == nodes[1])
	_check("nearest (-300, -300) -> joueur 4", Players.nearest(Vector2(-300, -300)) == nodes[3])
	_check("alive 4", Players.alive().size() == 4 and Players.alive_count() == 4)
	nodes[1].dead = true
	_check("mort : alive 3", Players.alive().size() == 3 and not Players.is_alive(1))
	_check("mort : nearest l'ignore", Players.nearest(Vector2(480, 10)) != nodes[1])
	_check("mort : nearest(alive_only = false)", Players.nearest(Vector2(480, 10), false) == nodes[1])
	nodes[1].dead = false
	# Spectateurs, équipe anéantie, résurrection à l'étage suivant
	var spect: Array = []
	var res: Array = []
	var wiped := [0]
	var c_s := func(id: int) -> void: spect.append(id)
	var c_r := func(id: int) -> void: res.append(id)
	var c_w := func() -> void: wiped[0] += 1
	Events.player_spectating.connect(c_s)
	Events.player_resurrected.connect(c_r)
	Events.party_wiped.connect(c_w)
	Players.set_spectating(2)
	Players.set_spectating(2) # deux fois : un seul signal
	_check("spectateur : signal unique", spect == [2] and Players.state_of(2).spectating)
	_check("spectateur : hors des vivants", Players.alive_count() == 3 and Players.nearest(Vector2(0, 290)) != nodes[2])
	_check("pas d'anéantissement à 3 vivants", wiped[0] == 0)
	Players.set_spectating(0)
	Players.set_spectating(1)
	Players.set_spectating(3)
	_check("équipe anéantie : party_wiped une fois", wiped[0] == 1 and Players.alive().is_empty())
	Players.resurrect_all()
	_check("résurrection de tous", res == [0, 1, 2, 3] and Players.alive_count() == 4)
	Events.player_spectating.disconnect(c_s)
	Events.player_resurrected.disconnect(c_r)
	Events.party_wiped.disconnect(c_w)
	# n pour l'équilibrage et absence (AFK)
	_check("n = 4", Players.party_size_for_scaling() == 4)
	Players.clock_s += Balance.MULTI_AFK_S + 1.0
	_check("tous absents : n = 1 (plancher)", Players.party_size_for_scaling() == 1 and Players.is_afk(3))
	Players.note_activity(0)
	Players.note_activity(2)
	_check("2 actifs : n = 2", Players.party_size_for_scaling() == 2 and not Players.is_afk(2))
	for i in 4:
		Players.note_activity(i)
	# Run à 4 : niveau de départ 3, D de départ 1,9, or entier à chacun, XP entière à chacun
	RunState.start_run(&"moyen", 99)
	_check("run à 4 : niveau de départ 3", Players.state_of(0).level == 3 and Players.state_of(3).level == 3 and RunState.level == 3)
	_check("run à 4 : party_size 4", RunState.party_size == 4)
	_check("run à 4 : D = 1,9 à t 0", is_equal_approx(RunState.difficulty(), 1.9))
	RunState.add_party_gold(40.0)
	var each := 40.0 * Balance.coop_gold_mult(4)
	var all_gold := true
	for i in 4:
		all_gold = all_gold and is_equal_approx(Players.state_of(i).gold, each)
	_check("or d'équipe : montant entier à chacun", all_gold and is_equal_approx(RunState.gold, each))
	_check("dépense individuelle", Players.state_of(2).spend_gold(10.0) and is_equal_approx(Players.state_of(2).gold, each - 10.0) and is_equal_approx(Players.state_of(1).gold, each))
	RunState.add_party_xp(Balance.xp_required(3) + 0.1)
	_check("XP d'équipe : entière à chacun", Players.state_of(0).level == 4 and Players.state_of(3).level == 4)
	Players.state_of(1).add_item(&"trefle")
	_check("objets par joueur", Players.state_of(1).stacks(&"trefle") == 1 and RunState.stacks(&"trefle") == 0)
	var d := RunState.to_dict()
	_check("sauvegarde coop : 3 joueurs en plus", d.has("players") and (d["players"] as Array).size() == 3)
	RunState.from_dict(d)
	_check("relecture coop", RunState.player_states.size() == 4 and RunState.player_states[1].stacks(&"trefle") == 1 and RunState.local() == RunState.player_states[0])
	Players.unregister(3)
	_check("départ : count 3", Players.count() == 3 and Players.by_id(3) == null)
	Players.clear()
	for n in nodes:
		n.remove_from_group(&"player")
		n.queue_free()


# --- Events : identité du joueur, signaux historiques intacts ----------------------------
func _events_identity() -> void:
	var legacy: Array = []
	var by: Array = []
	var c_l := func(_e: Node2D, _p: Vector2, tier: int, _el: bool) -> void: legacy.append(tier)
	var c_b := func(pid: int, _e: Node2D, _p: Vector2, tier: int, _el: bool) -> void: by.append([pid, tier])
	Events.enemy_killed.connect(c_l)
	Events.enemy_killed_by.connect(c_b)
	Events.emit_enemy_killed(null, Vector2.ZERO, 2, false, 3)
	Events.emit_enemy_killed(null, Vector2.ZERO, 1, false)
	_check("enemy_killed historique", legacy == [2, 1])
	_check("enemy_killed_by avec tueur", by == [[3, 2], [Events.NO_PLAYER, 1]])
	Events.enemy_killed.disconnect(c_l)
	Events.enemy_killed_by.disconnect(c_b)
	var dmg: Array = []
	var c_d := func(pid: int, amount: float, _s: Node) -> void: dmg.append([pid, amount])
	Events.player_damaged_by.connect(c_d)
	Events.emit_player_damaged(5.0, null, 1)
	_check("player_damaged_by", dmg == [[1, 5.0]])
	Events.player_damaged_by.disconnect(c_d)
	var picks: Array = []
	var c_p := func(pid: int, kind: StringName, amount: float) -> void: picks.append([pid, kind, amount])
	Events.pickup_collected_by.connect(c_p)
	Events.emit_pickup_collected(&"gold", 3.0)
	_check("pickup_collected_by (joueur 1 par défaut)", picks == [[0, &"gold", 3.0]])
	Events.pickup_collected_by.disconnect(c_p)
	var chosen: Array = []
	var c_c := func(pid: int, item: StringName) -> void: chosen.append([pid, item])
	Events.item_chosen_by.connect(c_c)
	Events.emit_item_chosen(&"trefle", 2)
	_check("item_chosen_by", chosen == [[2, &"trefle"]])
	Events.item_chosen_by.disconnect(c_c)


# --- Sources d'entrée -------------------------------------------------------------------
func _input_sources() -> void:
	var g := InputSource.global_source()
	_check("source globale = Input", g.move_vector() == Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down") and g.mode() == Platform.input_mode)
	Input.action_press(&"move_right")
	_check("source globale : action injectée (tactile, bots)", g.move_vector().x > 0.9 and g.is_pressed(&"move_right"))
	Input.action_release(&"move_right")
	_check("tactile : mode TOUCH, pas de pointeur", InputSource.touch_source().mode() == Platform.InputMode.TOUCH and InputSource.touch_source().pointer_world(null) == null)
	var pad := InputSource.pad_source(0)
	_check("manette : genre et appareil", pad.kind == InputSource.Kind.PAD and pad.device == 0 and pad.mode() == Platform.InputMode.GAMEPAD)
	_check("manette absente : aucun mouvement", pad.move_vector() == Vector2.ZERO and pad.aim_vector() == Vector2.ZERO and not pad.is_pressed(&"spell_2"))
	pad.poll()
	_check("manette absente : rien de juste pressé", not pad.just_pressed(&"interact"))
	var ev0 := InputEventJoypadButton.new()
	ev0.device = 0
	var ev1 := InputEventJoypadButton.new()
	ev1.device = 1
	_check("manette : événements de son appareil seulement", pad.owns_event(ev0) and not pad.owns_event(ev1) and not pad.owns_event(InputEventKey.new()))
	_check("manette : liaisons lues (sort 2 = X)", (pad.get(&"_buttons") as Dictionary).get(&"spell_2", PackedInt32Array()).has(JOY_BUTTON_X))
	var kbm := InputSource.kbm_source()
	_check("clavier : genre, mode, événements", kbm.kind == InputSource.Kind.KBM and kbm.mode() == Platform.InputMode.KBM and kbm.owns_event(InputEventKey.new()) and not kbm.owns_event(ev0))
	_check("clavier : liaisons lues (haut = W, sort 2 = clic gauche)", (kbm.get(&"_keys") as Dictionary).get(&"move_up", PackedInt32Array()).has(KEY_W) and (kbm.get(&"_mouse") as Dictionary).get(&"spell_2", PackedInt32Array()).has(MOUSE_BUTTON_LEFT))
	_check("clavier au repos : aucun mouvement", kbm.move_vector() == Vector2.ZERO and kbm.aim_vector() == Vector2.ZERO)
	# Inscription avec une source par appareil : Players la lit à chaque image de physique.
	var p := _fake(Vector2.ZERO)
	_check("inscription avec manette", Players.register(p, pad) == 0 and Players.input_of(0) == pad)
	Players.clear()
	p.remove_from_group(&"player")
	p.queue_free()


func _cleanup() -> void:
	Players.clear()
	Players.clock_s = 0.0
	RunState.player_states.resize(1)
	RunState.character = &"ardent"
	RunState.loadout = {}
	RunState.start_run(&"moyen", 1)
	RunState.running = false
	_check("nettoyage : solo", Players.count() == 0 and RunState.party_count() == 1 and RunState.player_states.size() == 1)


func _fake(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.position = pos
	add_child(p)
	p.add_to_group(&"player")
	return p


func _check(label: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])
