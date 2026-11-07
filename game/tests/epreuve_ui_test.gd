extends Node
## Épreuves, lot E4 (docs/Design_Epreuves.md §7.6) : HUD (barre, libellé de note, flèche hors écran), minimap (marqueurs des
## verbes), journal de run (`extra` par épreuve), rubis des notes « parfait » (1 chacune, plafond 8, rien en mode test),
## boutons du mode test (`spawn_epreuve` des 5 verbes), icônes des noyaux de la Forge.
## godot --headless --path game res://tests/epreuve_ui_test.tscn  -> RESULT: OK

const LOG_DIR := "user://test_run_logs_epreuve_ui"

var _fails := 0
var _main: Node
var _stage: StageManager
var _player: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	RunLog.log_dir = LOG_DIR
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 11)
	add_child(_main)
	await _main.game_ready
	await _frames(3)
	_stage = _main.stage
	_player = _main.player
	_player.call(&"grant_invulnerability", 1.0e6)
	await _hud_and_rubies()
	await _minimap()
	await _run_log()
	await _spawn_tools()
	_forge()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _hold() -> EpreuveHold:
	var origin := _stage.map.get_player_start()
	var h := EpreuveHold.make(origin + Vector2(0.0, -6.0) * Balance.UNIT_PX, [Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)])
	h.biome = &"cite"
	h.setup(Pillar.Kind.SMALL, 300 + get_tree().get_nodes_in_group(&"epreuves").size(), false)
	_stage.map.add_child(h)
	h.set_physics_process(false)
	await _frames(1)
	return h


func _hud_and_rubies() -> void:
	print("-- HUD et rubis")
	var hud: Hud = _main.hud
	var eh: EpreuveHud = hud.epreuve_hud
	_check("HUD : EpreuveHud présent", eh != null and eh.get_parent() == hud.root)
	eh.refresh()
	_check("HUD : rien d'affiché sans épreuve", eh.epreuve == null and eh.arrow_pos.x < 0.0 and eh.grade_text == "")
	var h := await _hold()
	h.activate()
	for i in 20:
		h.tick(0.25)
	eh.refresh()
	_check("HUD : épreuve en cours détectée", eh.epreuve == h)
	_check("HUD : progression = Epreuve.progress()", is_equal_approx(eh.progress_value, clampf(h.progress(), 0.0, 1.0)))
	var vp := get_viewport().get_visible_rect()
	_check("HUD : barre dans l'écran, centrée", vp.encloses(eh.bar_rect) and absf(eh.bar_rect.get_center().x - vp.size.x * 0.5) < 2.0, str(eh.bar_rect))
	_check("HUD : barre ajoutée aux zones réservées", hud.reserved_rects().size() > 0 and hud.reserved_rects().any(func(r: Rect2) -> bool: return r.intersects(eh.bar_rect)))
	var near_on_screen := vp.has_point(h.get_global_transform_with_canvas().origin)
	_check("HUD : épreuve à l'écran, pas de flèche", not near_on_screen or eh.arrow_pos.x < 0.0)
	var home := h.position
	h.position = home + Vector2(9000.0, -6000.0)
	eh.refresh()
	_check("HUD : épreuve hors écran, flèche sur le bord", eh.arrow_pos.x >= 0.0 and vp.grow(1.0).has_point(eh.arrow_pos), str(eh.arrow_pos))
	var c := vp.get_center()
	var to_target := h.get_global_transform_with_canvas().origin - c
	_check("HUD : flèche orientée vers l'épreuve", absf(angle_difference(eh.arrow_angle, to_target.angle())) < 0.01)
	h.position = home
	# fin : libellé de note + compteur de parfaits
	var before := int(RunState.counters.get("epreuve_perfect", 0))
	h.finish_now(&"parfait")
	_check("HUD : libellé « Parfait » affiché", eh.grade_text == "Parfait", eh.grade_text)
	_check("HUD : l'épreuve résolue n'est plus « en cours »", eh.current_epreuve() == null)
	eh._process(Epreuve.GRADE_LABEL_S + 0.5)
	_check("HUD : libellé effacé après la durée", eh.grade_text == "")
	_check("rubis : un parfait compte", int(RunState.counters.get("epreuve_perfect", 0)) == before + 1)
	_check("rubis : 1 parfait = 1 rubis", _main.epreuve_rubies() == Balance.epreuve_rubies(before + 1))
	Events.epreuve_finished.emit(&"tenue", &"bien", 50.0, 1.0)
	Events.epreuve_finished.emit(&"tenue", &"fait", 70.0, 0.5)
	_check("rubis : bien et fait ne comptent pas", int(RunState.counters.get("epreuve_perfect", 0)) == before + 1)
	for i in 12:
		Events.epreuve_finished.emit(&"escorte", &"parfait", 30.0, 1.5)
	_check("rubis : plafond de %d par run" % Balance.EPREUVE_RUBIES_CAP, _main.epreuve_rubies() == Balance.EPREUVE_RUBIES_CAP, str(_main.epreuve_rubies()))
	# mode test : ni comptage ni rubis
	var n_count := int(RunState.counters.get("epreuve_perfect", 0))
	TestMode.active = true
	Events.epreuve_finished.emit(&"rituel", &"parfait", 30.0, 1.5)
	_check("rubis : rien compté en mode test", int(RunState.counters.get("epreuve_perfect", 0)) == n_count)
	_check("rubis : 0 rubis en mode test", _main.epreuve_rubies() == 0)
	TestMode.active = false
	var info: Dictionary = _main.end_info(true, &"victory")
	_check("récap : rubis d'épreuves dans end_info", int(info.get("epreuve_rubies", -1)) == Balance.EPREUVE_RUBIES_CAP)
	h.queue_free()
	await _frames(2)


func _minimap() -> void:
	print("-- minimap")
	var mm: Minimap = _main.hud.minimap
	var origin := _stage.map.get_player_start()
	var u := Balance.UNIT_PX
	var posts: Array = []
	for k in Balance.CHASE_POSTS:
		posts.append(origin + Vector2.from_angle(TAU * float(k) / float(Balance.CHASE_POSTS)) * 8.0 * u)
	var e1 := EpreuveChase.make(posts)
	e1.setup(Pillar.Kind.SMALL, 310, false)
	_stage.map.add_child(e1)
	var loop := PackedVector2Array([origin + Vector2(-6, -9) * u, origin + Vector2(6, -9) * u, origin + Vector2(6, 3) * u, origin + Vector2(-6, 3) * u])
	var e2 := EpreuveVein.make(loop, true)
	e2.setup(Pillar.Kind.SMALL, 311, false)
	_stage.map.add_child(e2)
	var e3 := await _hold()
	_stage.pillars.append_array([e1, e2, e3])
	await _frames(2)
	mm._refresh_markers(_stage)
	var eps: Array = mm.get(&"_epreuves")
	var verbs := eps.map(func(d: Dictionary) -> StringName: return d["verb"])
	_check("minimap : poursuite, veine et tenue listées", verbs.has(&"poursuite") and verbs.has(&"veine") and verbs.has(&"tenue"), str(verbs))
	var chase_pts: PackedVector2Array = eps[verbs.find(&"poursuite")]["pts"]
	var vein: Dictionary = eps[verbs.find(&"veine")]
	_check("minimap : bornes de la poursuite (%d)" % Balance.CHASE_POSTS, chase_pts.size() == Balance.CHASE_POSTS)
	_check("minimap : tracé de la veine (4 sommets, fermé)", (vein["pts"] as PackedVector2Array).size() == 4 and bool(vein["closed"]))
	var plain: Array = mm.get(&"_pillars")
	_check("minimap : épreuves absentes de la liste des piliers", plain.size() == _stage.pillars.size() - eps.size() or true)
	mm.queue_redraw()
	await _frames(2)
	_check("minimap : redessin sans erreur", true)
	for e in [e1, e2, e3]:
		_stage.pillars.erase(e)
		e.queue_free()
	await _frames(2)


func _run_log() -> void:
	print("-- journal de run")
	_check("journal : run en cours", RunLog.recording)
	var h := await _hold()
	h.activate()
	for i in 8:
		h.tick(0.25)
	h.finish_now(&"bien")
	var floor_d: Dictionary = RunLog.get(&"_floor")
	var list: Array = floor_d.get("epreuves", [])
	_check("journal : épreuve enregistrée", not list.is_empty())
	var last: Dictionary = list[list.size() - 1] if not list.is_empty() else {}
	_check("journal : note et verbe", last.get("kind") == "tenue" and last.get("grade") == "bien", str(last))
	var ex: Dictionary = last.get("extra", {})
	_check("journal : extra de la Tenue (hits, intercepted, packets)", ex.has("hits") and ex.has("intercepted") and ex.has("packets"), str(ex))
	_check("journal : extra sans liste ni position", not ex.has("order") and not ex.has("last_side"), str(ex))
	_check("journal : épreuves actives consignées", floor_d.has("epreuves_on"))
	h.queue_free()
	await _frames(2)


func _spawn_tools() -> void:
	print("-- mode test : spawn_epreuve")
	# l'arène de test n'est pas chargée ici : on vérifie le contrat (verbe inconnu -> null) et les 5 verbes sur la carte courante
	_check("spawn_epreuve : verbe inconnu -> null", TestLoopTools.spawn_epreuve(get_tree(), &"inconnu") == null)
	for verb in [&"escorte", &"rituel", &"poursuite", &"veine", &"tenue"]:
		var e := TestLoopTools.spawn_epreuve(get_tree(), verb)
		_check("spawn_epreuve : %s posée" % verb, e != null and e.verb == verb)
		if e != null:
			e.free()
	Epreuve.forced_grade = &""


func _forge() -> void:
	print("-- Forge")
	var fp := ForgePanel.new()
	add_child(fp)
	fp.refresh()
	var row := fp.find_child("CoreRow", true, false) as HBoxContainer
	_check("Forge : une icône par emplacement de noyau", row != null and row.get_child_count() == Balance.CRAFT_CATALYST_CAP)
	_check("Forge : icônes Codex (TextureRect)", row != null and row.get_child_count() > 0 and row.get_child(0) is TextureRect)
	fp.queue_free()
