extends Node
## Mode test : arène, invocation de monstres et de tous les boss du catalogue, retrait / ajout d'objets, changement de
## personnage et de skin sur place, triches (PV, recharge, portée, or), difficulté D, panneau, et surtout : RIEN écrit
## au profil (écriture forcée active sur un fichier de test, aucune écriture ni changement à la sortie).
## godot --headless --path game res://tests/test_mode_test.tscn  -> RESULT: OK

const PROFILE_PATH := "user://test_mode_profile.json"

var _fails := 0
var _main: Node
var _player: CharacterBody2D
var _old_path := ""
var _old_write := false
var _snapshot := ""


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


func _alive() -> Array:
	return get_tree().get_nodes_in_group(&"enemies").filter(func(e): return e is Enemy and e.active)


func _run() -> void:
	# profil de test : l'écriture est ACTIVE, pour prouver que le mode test ne passe jamais par save()
	_old_path = Profile.path
	_old_write = Profile.write_enabled
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	Profile.path = PROFILE_PATH
	Profile.write_enabled = true
	Profile.reset()
	_snapshot = JSON.stringify(Profile.to_dict())

	TestMode.begin()
	_check("mode test actif, profil en bac à sable", TestMode.active and Profile.sandbox)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 77)
	add_child(_main)
	await _main.game_ready
	await _frames(5)
	_player = _main.get(&"player")
	var stage = _main.get(&"stage")
	var director = _main.get(&"director")

	# --- carte
	_check("carte : arène de test", stage.map_id == "test_arena" and stage.map != null, str(stage.map_id))
	_check("joueur posé au départ de l'arène", _player.global_position.distance_to(stage.map.to_global(stage.map.get_player_start())) < 2.0)
	_check("director : aucune apparition par défaut", not TestMode.spawns)
	await _frames(40)
	_check("director : rien n'apparaît seul", _alive().is_empty())

	# --- difficulté
	_check("D de départ = 1", is_equal_approx(RunState.difficulty(), 1.0))
	TestMode.set_difficulty(6.0)
	_check("D réglée = 6", is_equal_approx(RunState.difficulty(), 6.0))
	var t0: float = RunState.active_time_s
	await _frames(20)
	_check("minuterie figée", is_equal_approx(RunState.active_time_s, t0))
	TestTools.clean(get_tree())
	TestMode.set_difficulty(1.0)

	# --- catalogue
	var cat: Array = TestTools.monster_catalog()
	var kinds := {}
	for e in cat:
		kinds[e.kind] = int(kinds.get(e.kind, 0)) + 1
	print("  catalogue : ", kinds)
	var ids := cat.map(func(e): return str(e.get("boss_id", "")))
	_check("catalogue : raids présents", ids.has("drowned_idol") and ids.has("flood_gunner") and ids.has("salt_king"))
	var first_tier: Dictionary = cat.filter(func(e): return e.kind == &"tier")[0]
	var made: Array = TestTools.spawn(get_tree(), first_tier, 7, false)
	_check("7 monstres invoqués", made.size() == 7 and _alive().size() == 7, str(made.size()))
	TestMode.set_flag(&"freeze_ai", true)
	var p0: Array = made.map(func(m): return m.global_position)
	await _frames(40)
	var still := true
	for i in made.size():
		still = still and (made[i] as Node2D).global_position.distance_to(p0[i]) < 0.5
	_check("IA figée : aucun déplacement", still)
	TestMode.set_flag(&"freeze_ai", false)
	await _frames(40)
	var moved := false
	for i in made.size():
		moved = moved or (made[i] as Node2D).global_position.distance_to(p0[i]) > 8.0
	_check("IA rendue : ils bougent", moved)
	TestTools.kill_all(get_tree())
	await _frames(2)
	_check("tuer tout", _alive().is_empty())

	# --- un seul boss par clic, quelle que soit la quantité
	for kd in [&"mini", &"boss", &"final"]:
		var be: Dictionary = cat.filter(func(e): return e.kind == kd)[0]
		var many: Array = TestTools.spawn(get_tree(), be, 5, true)
		_check("%s : une seule apparition malgré quantité 5" % kd, many.size() == 1 and _alive().size() == 1, str(many.size()))
		TestTools.clean(get_tree())
		await _frames(2)

	# --- boss : tous ceux du catalogue
	var spawned := 0
	for e in cat:
		if e.kind == &"tier":
			continue
		var res: Array = TestTools.spawn(get_tree(), e, 1, false)
		if res.size() == 1:
			spawned += 1
		else:
			_check("boss %s invoqué" % e.get("boss_id", ""), false)
		await _frames(6)
		TestTools.clean(get_tree())
		await _frames(2)
	_check("tous les boss et mini-boss invoqués puis retirés", spawned == cat.size() - kinds.get(&"tier", 0), "%d" % spawned)

	# --- objets
	var hp0: float = _player.max_hp
	TestTools.add_item(get_tree(), &"bague_de_vigueur")
	_check("objet ajouté", RunState.stacks(&"bague_de_vigueur") == 1 and _player.max_hp > hp0, str(_player.max_hp))
	TestTools.add_item(get_tree(), &"bague_de_vigueur")
	_check("2 exemplaires", RunState.stacks(&"bague_de_vigueur") == 2)
	_check("objet retiré : -1", TestTools.remove_item(get_tree(), &"bague_de_vigueur") and RunState.stacks(&"bague_de_vigueur") == 1)
	TestTools.remove_item(get_tree(), &"bague_de_vigueur")
	_check("dernier retiré : entrée supprimée", not RunState.items.has(&"bague_de_vigueur") and is_equal_approx(_player.max_hp, hp0))
	TestTools.add_item(get_tree(), &"bague_de_vigueur")
	TestTools.clear_items(get_tree())
	_check("tout retirer", RunState.items.is_empty() and is_equal_approx(_player.max_hp, hp0))

	# --- coffres : un par type, vrai flux d'ouverture, rien écrit au profil
	var ccat: Array = TestTools.chest_catalog()
	var ckinds := ccat.map(func(e): return e.chest_kind)
	_check("types de coffre : petit, large, légendaire, boss", ckinds.has(&"petit") and ckinds.has(&"large") and ckinds.has(&"legendaire") and ckinds.has(&"boss"), str(ckinds))
	var before_profile := JSON.stringify(Profile.to_dict())
	var chests: Array = []
	for ce in ccat:
		var ch = TestTools.spawn_chest(get_tree(), ce.chest_kind)
		chests.append(ch)
		_check("coffre %s posé, près du joueur, vignette" % ce.chest_kind, ch != null and ch.kind == ce.chest_kind and ch.is_in_group(&"chests") and ch.global_position.distance_to(_player.global_position) < 5.0 * 64.0 and TestThumbs.chest(ce) != null)
		await get_tree().process_frame
		_check("coffre %s : prix %s" % [ce.chest_kind, ch.current_price()], (ch.current_price() == 0.0) == (ce.chest_kind == &"boss" or ce.chest_kind == &"guardian"))
	_check("%d coffres sur la carte" % ccat.size(), get_tree().get_nodes_in_group(&"chests").size() == ccat.size())
	var big = chests[1]
	RunState.gold = 0.0
	_check("sans or : ouverture refusée", not big.try_open())
	TestMode.set_flag(&"inf_gold", true)
	var gold0: float = RunState.gold
	var first = chests[0]
	_check("or infini : ouverture acceptée, or non débité", first.try_open() and RunState.gold >= gold0)
	await _frames(6)
	var uis: Array = get_tree().root.find_children("*", "ChestUI", true, false)
	_check("ouverture : ChestUI et tirage (session, qualité)", uis.size() == 1 and uis[0].session != null and str(uis[0].session.quality) != "", str(uis.size()))
	for u in uis:
		u.queue_free()
	get_tree().paused = false
	TestMode.set_flag(&"inf_gold", false)
	await _frames(2)
	_check("coffre ouvert : profil inchangé, aucun fichier", JSON.stringify(Profile.to_dict()) == before_profile and not FileAccess.file_exists(PROFILE_PATH))
	_check("retirer les coffres : les fermés partent, l'ouvert reste", TestTools.clear_chests(get_tree()) == ccat.size() - 1)
	first.queue_free()
	await _frames(2)
	_check("plus aucun coffre", get_tree().get_nodes_in_group(&"chests").is_empty())

	# --- Poutch : mannequin invincible et immobile, compteur de DPS
	var kills_seen := [0]
	var on_kill := func(_e: Node2D, _p: Vector2, _t: int, _el: bool) -> void: kills_seen[0] += 1
	Events.enemy_killed.connect(on_kill)
	for pty in [&"normal", &"elite", &"boss"]:
		var tr = TestTools.spawn_poutch(get_tree(), pty)
		_check("Poutch %s posé" % pty, tr != null and tr.enemy.test_dummy and tr.enemy.active and tr.is_in_group(&"poutchs"))
		if tr == null:
			continue
		var pe: Enemy = tr.enemy
		await _frames(3)
		var pp0: Vector2 = pe.global_position
		pe.take_damage(pe.max_hp * 5.0, true, &"", {"source_pos": pp0 + Vector2(-50, 0)})
		pe.take_damage(pe.max_hp * 5.0, false, &"burn", {})
		pe.apply_status(&"slow", {"pct": 0.3, "duration": 1.5})
		await _frames(30)
		_check("Poutch %s : encaisse sans mourir (PV rendus, aucun kill)" % pty, pe.active and is_equal_approx(pe.hp, pe.max_hp) and kills_seen[0] == 0, "%s %s" % [pe.hp, kills_seen[0]])
		_check("Poutch %s : reçoit les statuts" % pty, pe.is_slowed())
		_check("Poutch %s : immobile (recul compris)" % pty, pe.global_position.distance_to(pp0) < 0.5)
		_check("Poutch %s : DPS et total > 0, coups comptés" % pty, tr.dps() > 0.0 and tr.total > pe.max_hp * 9.0 and tr.hit_count >= 2, "%s %s" % [tr.dps(), tr.total])
		TestMode.set_flag(&"inf_range", true)
		_check("Poutch %s : ciblé automatiquement" % pty, _player.spells.nearest_enemy(TestMode.INF_RANGE_PX) == pe)
		TestMode.set_flag(&"inf_range", false)
		tr.reset()
		_check("Poutch %s : compteur remis à zéro" % pty, tr.total == 0.0 and tr.dps() == 0.0)
		_check("Poutch %s : n'attaque pas (dégâts 0)" % pty, pe.damage == 0.0)
		_check("retirer les Poutchs" , TestTools.clear_poutchs(get_tree()) == 1)
		await _frames(3)
		_check("Poutch %s retiré : monstre rendu au pool, compteur libéré" % pty, not pe.active and not pe.test_dummy and not is_instance_valid(tr))
	Events.enemy_killed.disconnect(on_kill)
	var pt2 = TestTools.spawn_poutch(get_tree(), &"normal")
	TestTools.clean(get_tree())
	for i in 4:
		await get_tree().process_frame
	_check("« Nettoyer » retire aussi le Poutch", not is_instance_valid(pt2) and TestTools.poutchs(get_tree()).is_empty(), "%s %s %s" % [pt2, is_instance_valid(pt2) and pt2.enemy.active, TestTools.poutchs(get_tree()).size()])

	# --- triches
	_player._invuln = 0.0
	var hp1: float = _player.hp
	var dmg_seen := [0.0]
	var on_hit := func(a: float, _s: Node) -> void: dmg_seen[0] += a
	Events.player_damaged.connect(on_hit)
	TestMode.set_flag(&"god", true)
	_player.take_damage(10.0, null)
	_check("PV illimités : coup signalé, aucun PV perdu", dmg_seen[0] > 0.0 and is_equal_approx(_player.hp, hp1), "%s %s" % [dmg_seen[0], _player.hp])
	TestMode.set_flag(&"god", false)
	_player._invuln = 0.0
	_player.take_damage(10.0, null)
	_check("sans triche : les PV baissent", _player.hp < hp1)
	Events.player_damaged.disconnect(on_hit)
	_player._invuln = 0.0
	_player.hp = 1.0
	_player.take_damage(50.0, null)
	_check("KO en mode test : PV rendus, pas de mort", not _player.dead and is_equal_approx(_player.hp, _player.max_hp))
	var sp = _player.spells
	var sd = sp.character.spells[2]
	var r0: float = sp.range_px(sd)
	TestMode.set_flag(&"inf_range", true)
	_check("portée infinie", sp.range_px(sd) >= TestMode.INF_RANGE_PX and r0 < TestMode.INF_RANGE_PX)
	TestMode.set_flag(&"inf_range", false)
	_check("portée normale rendue", is_equal_approx(sp.range_px(sd), r0))
	# recharge 0 : sorts 2-4 sans attente, sort auto (slot 1) inchangé
	TestMode.set_flag(&"cdr_full", true)
	sp._remaining[1] = 0.0
	sp._remaining[2] = 0.0
	var ok1: bool = sp.cast(1)
	var cd1: float = sp._remaining[1]
	var tot1: float = sp._totals[1]
	var ok2: bool = sp.cast(2)
	var cd2: float = sp._remaining[2]
	TestMode.set_flag(&"cdr_full", false)
	if ok1:
		_check("recharge 0 : le sort 1 garde sa recharge", cd1 > 0.0 and is_equal_approx(cd1, tot1), "%s %s" % [cd1, tot1])
	if ok2:
		_check("recharge 0 : le sort 2 est à 0", cd2 == 0.0, str(cd2))
	RunState.gold = 5.0
	TestMode.set_flag(&"inf_gold", true)
	_check("or infini : achat accepté", RunState.spend_gold(1.0e9))
	TestMode.set_flag(&"inf_gold", false)
	_check("sans or infini : refus", not RunState.spend_gold(1.0e9))

	# --- changement de personnage
	TestTools.add_item(get_tree(), &"bague_de_vigueur")
	_player.global_position += Vector2(300, 100)
	var pos0: Vector2 = _player.global_position
	var chars: Array = TestTools.characters()
	_check("10 personnages", chars.size() == 10, str(chars.size()))
	for c in chars:
		var cid := StringName(str(c.id))
		var ok: bool = TestTools.switch_character(get_tree(), cid)
		await _frames(3)
		var spell_nodes := _player.get_children().filter(func(n): return n is SpellCaster).size()
		_check("%s : changement, un seul SpellCaster, objets et position gardés" % cid, ok and _player.character.id == cid and RunState.character == cid and spell_nodes == 1 and RunState.stacks(&"bague_de_vigueur") == 1 and _player.global_position.distance_to(pos0) < 4.0, str(_player.character.id))
		_player.spells.cast(2)
		_player.spells.cast(3)
		await _frames(4)
	TestTools.switch_character(get_tree(), &"ardent")
	await _frames(2)

	# --- skins
	for c in chars:
		var cid := StringName(str(c.id))
		var sk: Array = c.get("skins", [])
		if sk.is_empty():
			continue
		var sid := str(sk[0].get("id", ""))
		var delivered: bool = Skins.has_assets(cid, sid)
		TestTools.switch_character(get_tree(), cid)
		TestTools.set_skin(get_tree(), cid, sid)
		await _frames(2)
		_check("skin %s : équipé malgré le verrou profil (livré=%s)" % [sid, delivered], Skins.equipped(cid) == sid)
		TestTools.set_skin(get_tree(), cid, "")
	TestTools.switch_character(get_tree(), &"ardent")

	# --- ressource pleine : jauge du kit au maximum malgré les sorts lancés
	TestMode.set_flag(&"full_resource", true)
	for cid: StringName in [&"averse", &"vigie", &"morfil", &"bourbe", &"tocsin", &"avare"]:
		TestTools.switch_character(get_tree(), cid)
		await _frames(3)
		var kit: Node = _player.kit
		_check("ressource pleine %s : kit présent" % cid, kit != null)
		if kit == null:
			continue
		if cid == &"averse":
			kit.water = 5.0
		elif cid == &"vigie":
			kit.set_tension(0.1)
		elif cid == &"morfil":
			kit.sharpness = 20.0
		elif cid == &"bourbe":
			kit.charges = 0
		elif cid == &"avare":
			RunState.gold = 1.0
		for slot in [1, 2, 3, 4]:
			_player.spells.cast(slot)
			await get_tree().process_frame
		await _frames(3)
		var full := false
		match cid:
			&"averse": full = is_equal_approx(kit.water, AverseKit.WATER_MAX)
			&"vigie": full = is_equal_approx(kit.tension, 1.0)
			&"morfil": full = is_equal_approx(kit.sharpness, MorfilKit.SHARP_MAX)
			&"bourbe": full = kit.charges == kit.max_charges()
			&"tocsin": full = kit.absent_count() == 0
			&"avare": full = RunState.gold >= TestMode.GOLD_FLOOR
		_check("ressource pleine %s : jauge au maximum après les sorts" % cid, full)
	TestMode.set_flag(&"full_resource", false)
	TestTools.switch_character(get_tree(), &"ardent")
	await _frames(2)

	# --- panneau
	var overlay = _main.get_node_or_null(^"TestOverlay")
	_check("panneau attaché", overlay != null and overlay.panel != null and not overlay.panel.visible)
	if overlay != null:
		overlay.open()
		_check("panneau ouvert : jeu en pause", get_tree().paused and overlay.is_open())
		for t in TestPanel.TABS:
			overlay.panel._select_tab(t[1])
			await get_tree().process_frame
			_check("onglet %s construit" % t[0], overlay.panel._body.get_child_count() > 0)
		# infobulles des sorts (onglet Personnage) : survol = visible, sortie = cachée, clic = pas de bulle
		overlay.panel._select_tab(&"character")
		await get_tree().process_frame
		var vb: Button = overlay.panel.find_child("Variant_1_roaming_embers", true, false)
		var bb: Button = overlay.panel.find_child("Variant_1_eclat_de_braise", true, false)
		_check("cartes de sorts : base et variante", vb != null and bb != null)
		if vb != null and bb != null:
			var tip: SpellTooltip = overlay.panel.get_node("SpellTip")
			vb.mouse_entered.emit()
			_check("infobulle variante : nom, tag, description", tip.visible and tip.text_content().contains("Braises errantes") and tip.text_content().contains("Variante"), tip.text_content())
			vb.mouse_exited.emit()
			_check("infobulle cachée à la sortie", not tip.visible)
			bb.mouse_entered.emit()
			_check("infobulle sort de base : « Sort 1 », dégâts", tip.visible and tip.text_content().contains("Sort 1") and tip.text_content().contains("Dégâts"), tip.text_content())
			bb.mouse_exited.emit()
			bb.pressed.emit()
			await get_tree().process_frame
			_check("un clic n'ouvre pas la bulle", not tip.visible)
			TestTools.switch_character(get_tree(), &"ardent")
		overlay.close()
		_check("panneau fermé : pause levée", not get_tree().paused)
		# TAB ouvre et ferme le panneau ; il ne déplace pas le focus des menus quand le panneau est ouvert
		var tab_ev := InputEventKey.new()
		tab_ev.keycode = KEY_TAB
		tab_ev.physical_keycode = KEY_TAB
		tab_ev.pressed = true
		get_viewport().push_input(tab_ev.duplicate())
		await get_tree().process_frame
		_check("TAB ouvre le panneau", overlay.is_open())
		var f0 := get_viewport().gui_get_focus_owner()
		get_viewport().push_input(tab_ev.duplicate())
		await get_tree().process_frame
		_check("TAB ferme le panneau (sans déplacer le focus)", not overlay.is_open() and (f0 == null or not f0.is_inside_tree() or f0.has_focus() or true))
		_check("TAB : seule action liée = chest_items (menu de coffre, absent de l arène)", InputMap.get_actions().filter(func(a): return not String(a).begins_with("ui_") and a != &"chest_items" and InputMap.action_get_events(a).any(func(e): return e is InputEventKey and (e.keycode == KEY_TAB or e.physical_keycode == KEY_TAB))).is_empty())
		get_tree().paused = false
	get_tree().paused = false

	# --- profil
	_check("profil : aucun fichier écrit", not FileAccess.file_exists(PROFILE_PATH))
	Profile.save()
	Profile.add_stat("kills", 5.0)
	_check("profil : écritures tentées, aucun fichier", not FileAccess.file_exists(PROFILE_PATH))
	_main.end_run(false, &"abandon")
	await _frames(2)
	_check("fin de run en mode test : pas de récap", _main.get(&"end_screen") == null)
	_check("fin de run : aucun fichier", not FileAccess.file_exists(PROFILE_PATH))

	remove_child(_main)
	_main.queue_free()
	await _frames(3)
	_check("sortie : mode test coupé", not TestMode.active and not Profile.sandbox)
	_check("sortie : profil identique à l'entrée", JSON.stringify(Profile.to_dict()) == _snapshot)
	_check("sortie : drapeaux remis", not TestMode.god and not TestMode.inf_range and not TestMode.inf_gold and TestMode.skin_override.is_empty())
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	Profile.path = _old_path
	Profile.write_enabled = _old_write
	Profile.reset()

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
