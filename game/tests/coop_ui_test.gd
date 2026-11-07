extends Node
## Coop 1-4, lot 4 « UI, télémétrie, sauvegarde, ambiance » : teinte d'équipe, état du joueur local, alliés sur la
## minimap / les flèches / les barres, VFX alliés, chiffres filtrés, overlay sans pause, bilan de fin de run, journal,
## sauvegarde coop, mode test. Solo inchangé.
## godot --headless --path game res://tests/coop_ui_test.tscn  -> RESULT: OK

class FakePlayer extends Node2D:
	var dead := false
	var hp := 80.0
	var max_hp := 100.0
	var spells: Object = null


var _fails := 0
var _fakes: Array[FakePlayer] = []


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	await _frames(2)
	_palette()
	await _solo()
	await _coop()
	_cleanup()
	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails else 0)


func _fake(p: Vector2, in_player_group := false) -> FakePlayer:
	var f := FakePlayer.new()
	f.position = p
	add_child(f)
	if in_player_group:
		f.add_to_group(&"player")
	_fakes.append(f)
	return f


# --- Teinte d'équipe : 4 couleurs lisibles dans chaque mode daltonien -------------------------------
func _palette() -> void:
	for m in 4:
		var cols: Array[Color] = []
		for s in 4:
			cols.append(Palette.team_color(s, m))
		var worst := 99.0
		for i in 4:
			for j in range(i + 1, 4):
				var d := Vector3(cols[i].r - cols[j].r, cols[i].g - cols[j].g, cols[i].b - cols[j].b).length()
				worst = minf(worst, d)
		_check(worst > 0.25, "mode %d : 4 teintes d'équipe distinctes (écart RVB min %.2f)" % [m, worst])
	_check(Palette.team_color(9) == Palette.team_color(3) and Palette.team_color(-4) == Palette.team_color(0), "slot hors bornes : borné")
	_check(Palette.team_glyph(0) == "1" and Palette.team_glyph(3) == "4", "numéros 1 à 4")
	_check(is_equal_approx(Palette.ally_vfx_alpha(false), 0.55) and is_equal_approx(Palette.ally_vfx_alpha(true), 0.35), "alpha des VFX alliés 0,55 / 0,35")
	var e := Color("#FFC84D") # COL_ELITE d'OffscreenCues ~ ambre : le joueur 2 s'en distingue par le numéro, pas seulement la teinte
	_check(Palette.team_color(0, 0) != e, "joueur 1 : ivoire, pas l'ambre des élites")


# --- Solo : tout est comme avant -------------------------------------------------------------------
func _solo() -> void:
	Players.clear()
	var p := _fake(Vector2(200, 200), true)
	_check(LocalState.state() == RunState.local(), "solo : LocalState.state() = RunState.local()")
	_check(LocalState.slot() == 0 and not LocalState.is_coop() and LocalState.node() == p, "solo : slot 0, pas coop, nœud = joueur")
	_check(is_equal_approx(AllyFx.alpha_for(0), 1.0) and is_equal_approx(AllyFx.alpha_for(2), 1.0) and is_equal_approx(AllyFx.alpha_for(-1), 1.0), "solo : VFX jamais atténués")
	_check(DamageNumbers.shows_for(0) and DamageNumbers.shows_for(1) and DamageNumbers.shows_for(Events.NO_PLAYER), "solo : tous les chiffres visibles")
	_check(RunSave.allowed(), "solo : sauvegarde de run permise")
	var path := "user://_coop_ui_test_save.json"
	_check(RunSave.save({"a": 1}, path), "solo : RunSave.save écrit")
	RunSave.delete(path)
	_check(PartyRecap.n() == 1 and is_equal_approx(PartyRecap.participation(), 1.0), "solo : n = 1, participation 1")
	_check(PartyRecap.rubies(10.0, &"moyen", 3, true, 1000.0) == Balance.run_rubies(10.0, &"moyen", 3, true, 1000.0), "solo : rubis identiques à Balance.run_rubies")
	var rows := PartyRecap.summary()
	_check(rows.size() == 1 and int(rows[0]["slot"]) == 0 and is_equal_approx(float(rows[0]["participation"]), 1.0), "solo : une ligne de bilan")
	var log_rows: Array = RunLog._players_array()
	_check(log_rows.size() == 1 and int(log_rows[0]["slot"]) == 0 and log_rows[0].has("damage") and log_rows[0].has("deaths"), "solo : journal, players[] à un joueur")
	_check(TestTools.target_ids() == [0] and TestTools.player_of(get_tree()) == p, "solo : mode test cible le joueur 1")
	# Écran de coffre : solo = pause (comportement historique)
	var ui: ChestUI = load("res://scenes/ui/chest/chest_ui.tscn").instantiate()
	add_child(ui)
	ui.open(&"petit", 1, 10.0)
	await _frames(2)
	_check(get_tree().paused and not ui.non_blocking and not OverlayMode.is_open(), "solo : le coffre met l'arbre en pause, pas d'overlay")
	ui.queue_free()
	get_tree().paused = false
	await _frames(2)
	p.remove_from_group(&"player")


# --- Coop : 3 joueurs -------------------------------------------------------------------------------
func _coop() -> void:
	Players.clear()
	var p0 := _fake(Vector2(0, 0))
	var p1 := _fake(Vector2(5000, 0)) # loin, hors écran
	var p2 := _fake(Vector2(-5000, 300))
	Players.register(p0, null, 0)
	Players.register(p1, null, 1)
	Players.register(p2, null, 2)
	Players.state_of(1).reset()
	_check(Players.count() == 3 and LocalState.is_coop(), "coop : 3 joueurs inscrits")
	_check(LocalState.state() == Players.state_of(0) and LocalState.node() == p0, "coop : l'état local est celui du joueur local")

	# VFX alliés
	_check(is_equal_approx(AllyFx.alpha_for(0), 1.0), "coop : mes VFX à 100 %")
	_check(is_equal_approx(AllyFx.alpha_for(1), 0.55), "coop : VFX d'un allié à 0,55")
	_check(is_equal_approx(AllyFx.alpha_for(Events.NO_PLAYER), 1.0), "coop : propriétaire inconnu à 100 %")
	var tier_before: int = Quality.tier
	Quality.tier = Quality.Tier.LOW
	_check(is_equal_approx(AllyFx.alpha_for(1), 0.35), "coop, qualité Basse : VFX d'un allié à 0,35")
	Quality.tier = tier_before
	var probe := Node2D.new()
	add_child(probe)
	AllyFx.apply(probe, 2)
	_check(is_equal_approx(probe.modulate.a, 0.55), "AllyFx.apply : alpha du nœud allié")
	probe.queue_free()

	# Chiffres de dégâts : alliés masqués par défaut
	_check(DamageNumbers.shows_for(0) and not DamageNumbers.shows_for(1) and DamageNumbers.shows_for(Events.NO_PLAYER), "coop : chiffres alliés masqués, les miens et l'environnement visibles")

	# Flèches hors écran : alliés, tombé, spectateur
	var screen := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var cues := load("res://scripts/ui/offscreen_cues.gd")
	var targets: Array[Dictionary] = cues.collect_targets(get_tree(), screen)
	var kinds := {}
	for t in targets:
		kinds[int(t["slot"])] = int(t["kind"])
	_check(kinds.size() == 2 and not kinds.has(0), "flèches : deux alliés, jamais le joueur local")
	_check(kinds.get(1) == cues.Kind.ALLY and kinds.get(2) == cues.Kind.ALLY, "flèches : alliés vivants = Kind.ALLY")
	p1.dead = true
	targets = cues.collect_targets(get_tree(), screen)
	_check(int(targets[0]["kind"]) == cues.Kind.ALLY_DOWN and int(targets[0]["slot"]) == 1, "flèches : allié tombé en tête (au-dessus du boss)")
	Players.state_of(1).spectating = true
	targets = cues.collect_targets(get_tree(), screen)
	var has_spec := false
	for t in targets:
		has_spec = has_spec or (int(t["slot"]) == 1 and int(t["kind"]) == cues.Kind.ALLY_SPECTATOR)
	_check(has_spec, "flèches : allié spectateur = Kind.ALLY_SPECTATOR")
	Players.state_of(1).spectating = false
	p1.dead = false
	_check(cues.COOP_MAX_CUES == 8 and cues.MAX_CUES == 6, "flèches : 6 en solo, 8 en coop")

	# Barres de PV alliés : un allié visible à l'écran
	p1.position = Vector2(300, 200)
	var bars := AllyBars.new()
	add_child(bars)
	await _frames(4)
	bars.queue_redraw()
	await _frames(2)
	_check(bars.bars.size() == 1 and int(bars.bars[0]["slot"]) == 1, "barres alliées : une barre, celle du joueur 2 (%d)" % bars.bars.size())
	bars.queue_free()
	p1.position = Vector2(5000, 0)

	# Bilan de fin de run : participation aux dégâts
	RunState.party_size = 4
	Players.state_of(0).damage_dealt = 300.0
	Players.state_of(1).damage_dealt = 100.0
	Players.state_of(2).damage_dealt = 0.0
	_check(is_equal_approx(PartyRecap.team_damage(), 400.0), "bilan : dégâts d'équipe 400")
	_check(is_equal_approx(PartyRecap.participation(2), 0.0) and is_equal_approx(PartyRecap.participation(0), 1.0), "bilan : participation 0 (aucun dégât) et 1")
	_check(PartyRecap.rubies(10.0, &"moyen", 3, true, 0.0, 2) == 0, "bilan : 0 rubis sans participation")
	_check(PartyRecap.rubies(10.0, &"moyen", 3, true, 0.0, 0) == Balance.run_rubies(10.0, &"moyen", 3, true, 0.0, 4, 1.0), "bilan : rubis complets à participation 1, n = 4")
	var rows := PartyRecap.summary()
	_check(rows.size() == 3 and is_equal_approx(float(rows[0]["damage_share"]), 0.75), "bilan : tableau de 3 joueurs, part 75 %")
	var ruby_txt := EndRunScreen.ruby_breakdown({"mode": "moyen", "active_time_s": 600.0, "party_n": 4, "participation": 0.5})
	_check(ruby_txt.contains("Participation ×0,5"), "récap : « Participation ×0,5 » (%s)" % ruby_txt)
	RunState.party_size = 1
	var log_rows: Array = RunLog._players_array()
	_check(log_rows.size() == 3 and int(log_rows[1]["slot"]) == 1 and is_equal_approx(float(log_rows[0]["damage_share"]), 0.75), "journal : players[] à 3 joueurs avec parts de dégâts")

	# Sauvegarde : aucune en coop
	_check(not RunSave.allowed() and not RunSave.save({"a": 1}, "user://_coop_ui_test_save.json"), "coop : RunSave.save refuse d'écrire")
	_check(not FileAccess.file_exists("user://_coop_ui_test_save.json"), "coop : aucun fichier de sauvegarde créé")

	# Mode test : joueur 1 par défaut, tous sur demande
	_check(TestTools.target_ids() == [0], "mode test : joueur 1 par défaut")
	TestTools.all_players = true
	_check(TestTools.target_ids() == [0, 1, 2], "mode test : tous les joueurs sur demande")
	var iid: StringName = ItemDB.ids_of_quality(&"commun")[0]
	TestTools.add_item(get_tree(), iid)
	_check(Players.state_of(0).stacks(iid) == 1 and Players.state_of(1).stacks(iid) == 1 and Players.state_of(2).stacks(iid) == 1, "mode test : objet ajouté à tous")
	TestTools.all_players = false
	TestTools.add_item(get_tree(), iid)
	_check(Players.state_of(0).stacks(iid) == 2 and Players.state_of(1).stacks(iid) == 1, "mode test : objet au joueur 1 seulement")
	TestTools.clear_items(get_tree())
	Players.state_of(1).clear_items()
	Players.state_of(2).clear_items()

	# Écran de coffre : coop = overlay, aucune pause, objets du propriétaire
	Players.state_of(1).add_gold(500.0)
	ChestSession.pending_state = Players.state_of(1)
	var ui: ChestUI = load("res://scenes/ui/chest/chest_ui.tscn").instantiate()
	add_child(ui)
	ui.open(&"petit", 1, 10.0)
	await _frames(3)
	_check(not get_tree().paused, "coop : le coffre ne met PAS l'arbre en pause")
	_check(ui.non_blocking and OverlayMode.is_open(), "coop : overlay non bloquant déclaré (OverlayMode.is_open)")
	_check(ui.session != null and ui.session.state == Players.state_of(1) and ui._owner() == Players.state_of(1), "coop : la session appartient au joueur 2")
	ui.set_collapsed(true)
	_check(ui.collapsed and ui._pill != null and ui._pill.visible and not ui._margin.visible, "coop : overlay replié en pastille")
	ui.set_collapsed(false)
	_check(not ui.collapsed and ui._margin.visible, "coop : overlay déplié")
	_check(is_equal_approx(ui._dim.color.a, 0.0), "coop : fond transparent")
	ui.queue_free()
	await _frames(2)
	_check(not OverlayMode.is_open(), "coop : OverlayMode libéré à la fermeture")
	_check(not get_tree().paused, "coop : toujours pas de pause après fermeture")

	# HUD : branché sur l'état du joueur local
	var hud := Hud.new()
	add_child(hud)
	await _frames(3)
	_check(hud._state == Players.state_of(0), "HUD : branché sur le PlayerState du joueur local")
	_check(hud.ally_bars != null and hud.ally_bars.get_parent() != null, "HUD : barres alliées présentes")
	Players.state_of(0).add_gold(25.0)
	_check(hud._gold_label.text.contains("25"), "HUD : l'or du joueur local s'affiche (%s)" % hud._gold_label.text)
	Players.state_of(1).add_gold(7000.0)
	_check(not hud._gold_label.text.contains("7000"), "HUD : l'or d'un allié ne s'affiche pas")
	# compteur de noyaux d'orage dans la plaque de chaque joueur : visible à 1, masqué à 0
	var cp: CoopPlates = hud.coop_plates
	cp.queue_redraw()
	await _frames(2)
	_check(cp.core_rects.is_empty(), "plaques : pas de compteur de noyaux à 0 noyau")
	Players.state_of(1).add_catalyst(1)
	cp.queue_redraw()
	await _frames(2)
	_check(cp.core_rects.has(1) and not cp.core_rects.has(0), "plaques : compteur de noyaux sur la plaque du joueur 2 seulement")
	if cp.core_rects.has(1):
		var plate_r := Rect2()
		for pl in cp.plates:
			if int(pl["slot"]) == 1:
				plate_r = pl["rect"]
		_check(plate_r.encloses(cp.core_rects[1]), "plaques : compteur de noyaux dans sa plaque")
	Players.state_of(1).spend_catalyst(1)
	cp.queue_redraw()
	await _frames(2)
	_check(not cp.core_rects.has(1), "plaques : compteur masqué quand le noyau est dépensé")
	hud.queue_free()


func _cleanup() -> void:
	Players.clear()
	TestTools.all_players = false
	RunState.party_size = 1
	OverlayMode.reset()
	get_tree().paused = false
	for f in _fakes:
		if is_instance_valid(f):
			f.queue_free()
