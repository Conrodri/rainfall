extends Node
## Porte scellée des 8 cartes des étages 1-4 (A et B) (docs/Design_Zones_Secretes.md §3, docs/Design_Variantes_B.md) :
## - une SecretRoom par carte tirée avec secret, 2 plaques / 2 gardiens nommés / 1 porte ; porte fermée = salle inaccessible (NavField) ;
## - une plaque ne réagit qu'au joueur (un monstre dessus ne fait rien), reste enfoncée, ordre libre ;
## - 2e plaque : collision de porte coupée, bloc de mur retiré, salle accessible (NavField refait), télégraphe puis
##   2 gardiens élites tier 3 nommés (affixes du biome) ; mort -> 2 reliquaires ; secret terminé ;
## - sauvegarde / reprise : plaque enfoncée, porte ouverte, gardien mort conservés ;
## - étage 5 (la_source) : aucun secret ;
## - fréquence : au plus un secret par run (≈ 1/3), étage 1-4 seulement, déterministe par graine, sauvegardé.
## godot --headless --path game res://tests/secrets_test.tscn  -> RESULT: OK

const B_MAPS := ["terrasses_rizieres_hautes", "foret_mangrove_lanternes", "cite_fonderie_canal", "cryptes_ossuaire_pluies"]
const A_MAPS := ["terrasses_noyees", "foret_brume", "cite_rouille", "cryptes_noyees"]

var _fails := 0
var _fake_chest_script: GDScript
var _player: CharacterBody2D
var _director: Node2D
var _mgr: StageManager


func _ready() -> void:
	await _run()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, cond: bool, detail: String = "") -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label, ("  (" + detail + ")") if detail != "" else "")


func _make_chest() -> Node2D:
	var c := Node2D.new()
	c.set_script(_fake_chest_script)
	return c


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	_fake_chest_script = GDScript.new()
	_fake_chest_script.source_code = "extends Node2D\nvar kind\nvar stage\nfunc setup(k, s):\n\tkind = k\n\tstage = s\n"
	_fake_chest_script.reload()
	_player = CharacterBody2D.new()
	_player.collision_layer = 2
	_player.collision_mask = 0
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	cs.shape = circle
	_player.add_child(cs)
	_player.add_to_group(&"player")
	add_child(_player)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	add_child(_director)
	_director.spawning_enabled = false
	_mgr = StageManager.new()
	_mgr.chest_factory = _make_chest
	add_child(_mgr)
	await _frames(2)
	for id in A_MAPS + B_MAPS: # secrets sur les 8 cartes des étages 1-4 (A ajoutés le 29/10/2026)
		await _test_b(id)
	await _load_map("la_source")
	_check("la_source : aucun secret", _mgr.secrets.is_empty())
	await _test_save(B_MAPS[0])
	await _test_unarmed(B_MAPS[1])
	for id in [A_MAPS[1], B_MAPS[3]]:
		for trig in ["lever", "wall", "pillar"]:
			await _test_trigger(id, trig)
	await _test_trigger_save(A_MAPS[2])
	_test_frequency()
	_test_trigger_draw()
	_test_guardian_loot()
	await _test_plan_save()


func _load_map(id: String, armed: bool = true, trig: String = "plates") -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	RunState.start_run(&"moyen", 31)
	_mgr.reset_run()
	var fl := int(meta["floor"])
	(_mgr.floor_plan[fl - 1] as Dictionary)["map_id"] = id
	(_mgr.floor_plan[fl - 1] as Dictionary)["secret"] = armed and FloorPlan.map_has_secret(id)
	(_mgr.floor_plan[fl - 1] as Dictionary)["secret_trigger"] = trig
	RunState.stage = fl
	_mgr.start_stage()
	await _frames(2)
	_check("%s : carte chargée" % id, _mgr.map_id == id)


## Centre de la première case de la salle (repère local de la carte).
func _room_point(meta: Dictionary) -> Vector2:
	var c: Array = meta["secrets"][0]["room_cells"][0]
	var size_px := Vector2(meta["size_px"][0], meta["size_px"][1])
	return _mgr.map.from_map(Vector2((float(c[0]) + 0.5) * 128.0, (float(c[1]) + 0.5) * 128.0) - size_px * 0.5)


func _test_b(id: String) -> void:
	await _load_map(id)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	var map := _mgr.map
	_check("%s : une SecretRoom" % id, _mgr.secrets.size() == 1)
	if _mgr.secrets.size() != 1:
		return
	var room := _mgr.secrets[0]
	var sc: Dictionary = meta["secrets"][0]
	_check("%s : 2 plaques, 2 gardiens nommés" % id, room.plates.size() == 2 and room.guardian_defs.size() == 2)
	_check("%s : noms des gardiens" % id, room.guardian_defs[0]["name"] == sc["guardian_names"][0] and room.guardian_defs[1]["name"] == sc["guardian_names"][1])
	var nav: NavField = _director.nav
	var inside := map.to_global(_room_point(meta))
	_check("%s : salle scellée inaccessible porte fermée" % id, nav != null and not nav.is_reachable(inside))
	var door := map.get_node("Obstacles/Walls/Door_%s" % String(room.secret_id)) as CollisionShape2D
	_check("%s : collision de porte active" % id, door != null and not door.disabled)
	var dcell := Vector2i(int(sc["door_cells"][0][0]), int(sc["door_cells"][0][1]))
	_check("%s : bloc de porte dessiné" % id, map._blocks.has(dcell) or map.iso_dir_used == "")
	# plaque : un monstre dessus ne la déclenche pas
	var foe := CharacterBody2D.new()
	foe.collision_layer = 1 << 2
	foe.collision_mask = 0
	var fcs := CollisionShape2D.new()
	fcs.shape = CircleShape2D.new()
	foe.add_child(fcs)
	map.add_child(foe)
	foe.global_position = room.plates[0].global_position
	await _frames(3)
	_check("%s : un monstre n'enfonce pas la plaque" % id, not room.plates[0].pressed)
	foe.queue_free()
	# ligne OBJECTIFS et minimap : rien avant la 1re dalle (pas de spoiler), porte = mur tant que fermée
	var panel := ObjectivesPanel.new()
	panel.stage_manager = _mgr
	add_child(panel)
	panel.refresh()
	_check("%s : pas de ligne secrète avant la 1re dalle" % id, not panel.is_secret_shown())
	var mm := Minimap.new()
	add_child(mm)
	mm._bind_map(map)
	var dc: Vector2i = mm._secret_cells.keys()[0]
	_check("%s : minimap porte fermée = mur" % id, mm._vis_cell(dc.x, dc.y) == "#")
	var seen := {"plate": 0, "open": 0, "spawned": 0, "killed": 0, "done": 0}
	room.plate_pressed.connect(func(_i, _n, _t) -> void: seen["plate"] += 1)
	room.opened.connect(func(_i) -> void: seen["open"] += 1)
	room.guardian_spawned.connect(func(_i, _n, _e) -> void: seen["spawned"] += 1)
	room.guardian_killed.connect(func(_i, _n, _d, _t) -> void: seen["killed"] += 1)
	room.completed.connect(func(_i) -> void: seen["done"] += 1)
	# plaque 1, puis ailleurs, puis plaque 0 (ordre libre, état définitif)
	_player.global_position = room.plates[1].global_position
	await _frames(3)
	_check("%s : plaque 1 enfoncée" % id, room.plates[1].pressed and room.pressed_count() == 1 and not room.is_open)
	_check("%s : objectif Dalles 1/2" % id, room.objective_text() == "Dalles  1/2")
	panel.refresh()
	_check("%s : ligne secrète Dalles 1/2" % id, panel.is_secret_shown() and panel.secret_text() == "Dalles 1/2", panel.secret_text())
	_player.global_position = map.to_global(map.get_player_start())
	await _frames(3)
	_check("%s : la plaque reste enfoncée" % id, room.plates[1].pressed)
	_player.global_position = room.plates[0].global_position
	await _frames(4)
	_check("%s : 2 plaques -> porte ouverte" % id, room.is_open and seen["open"] == 1 and seen["plate"] == 2)
	_check("%s : compteur secret_zones = 1 (une fois par zone)" % id, int(RunState.counters.get("secret_zones", 0.0)) == 1, str(RunState.counters.get("secret_zones")))
	_check("%s : collision de porte coupée" % id, door.disabled)
	_check("%s : bloc de porte retiré" % id, not map._blocks.has(dcell))
	nav = _director.nav
	_check("%s : salle accessible porte ouverte (NavField refait)" % id, nav != null and nav.is_reachable(inside))
	_check("%s : objectif Gardiens 0/2" % id, room.objective_text() == "Gardiens  0/2")
	panel.refresh()
	_check("%s : ligne secrète Gardiens 0/2" % id, panel.secret_text() == "Gardiens 0/2", panel.secret_text())
	var floor_cells := 0
	for c: Vector2i in mm._secret_cells:
		if mm._vis_cell(c.x, c.y) == ".":
			floor_cells += 1
	_check("%s : minimap porte ouverte = sol (%d cases)" % [id, floor_cells], floor_cells == mm._secret_cells.size() and floor_cells > 1)
	var gold0 := RunState.gold
	# télégraphe 1 s + 2 gardiens espacés de 1,5 s
	await get_tree().create_timer(SecretRoom.TELEGRAPH_S + SecretRoom.GUARDIAN_GAP_S + 0.6).timeout
	_check("%s : 2 gardiens apparus" % id, seen["spawned"] == 2, str(seen))
	for i in 2:
		var g: Variant = room.guardians[i]
		_check("%s : gardien %d élite tier 3 nommé" % [id, i], g != null and g.is_elite and g.tier == 3 and g.get_meta(&"guardian_name", "") == sc["guardian_names"][i])
		if g != null:
			_check("%s : gardien %d accessible (hors mur)" % [id, i], nav.is_reachable(g.global_position))
			_check("%s : gardien %d affixes de biome" % [id, i], not g.affixes.is_empty() and g.affixes.size() <= 2)
	var chests0 := _mgr.chests.size()
	for i in 2:
		var g: Variant = room.guardians[i]
		if g != null:
			g.take_damage(1.0e9, false, &"test")
	await _frames(3)
	_check("%s : 2 gardiens tués" % id, room.dead_count() == 2 and seen["killed"] == 2 and seen["done"] == 1)
	_check("%s : prime d'or des gardiens" % id, RunState.gold > gold0, "%s -> %s" % [gold0, RunState.gold])
	panel.refresh()
	_check("%s : ligne secrète terminée" % id, panel.secret_text().begins_with("Salle secrète"), panel.secret_text())
	panel.queue_free()
	mm.queue_free()
	_check("%s : 2 reliquaires (coffres kind guardian)" % id, _mgr.chests.size() == chests0 + 2 and _mgr.chests.back().kind == &"guardian")
	_check("%s : secret terminé" % id, room.is_complete() and room.objective_text() == "" and _mgr.secret_status()[0]["complete"])


## Sauvegarde / reprise : plaque 0 enfoncée, puis porte ouverte + un gardien mort + reliquaire.
func _test_save(id: String) -> void:
	await _load_map(id)
	var room := _mgr.secrets[0]
	_player.global_position = room.plates[0].global_position
	await _frames(3)
	var d := _mgr.to_dict()
	_check("sauvegarde : bloc secrets", (d["secrets"] as Array).size() == 1 and d["secrets"][0]["plates"] == [true, false] and not d["secrets"][0]["open"])
	_mgr.from_dict(JSON.parse_string(JSON.stringify(d))) # aller-retour JSON comme user://run_save.json
	await _frames(3)
	room = _mgr.secrets[0]
	_check("reprise : plaque 0 enfoncée, 1 non", room.plates[0].pressed and not room.plates[1].pressed and not room.is_open)
	_player.global_position = room.plates[1].global_position
	await _frames(4)
	_check("reprise : 2e plaque -> porte ouverte", room.is_open)
	await get_tree().create_timer(SecretRoom.TELEGRAPH_S + 0.4).timeout
	var g: Variant = room.guardians[0]
	_check("reprise : gardien 0 apparu", g != null)
	if g != null:
		g.take_damage(1.0e9, false, &"test")
	await _frames(3)
	var d2 := _mgr.to_dict()
	_check("sauvegarde : porte ouverte, gardien 0 mort, 1 reliquaire", d2["secrets"][0]["open"] and d2["secrets"][0]["dead"] == [true, false] and (d2["secrets"][0]["relics"] as Array).size() == 1)
	_mgr.from_dict(JSON.parse_string(JSON.stringify(d2)))
	await _frames(4)
	room = _mgr.secrets[0]
	var door := _mgr.map.get_node("Obstacles/Walls/Door_%s" % String(room.secret_id)) as CollisionShape2D
	_check("reprise : porte ouverte", room.is_open and door.disabled and room.plates[0].pressed and room.plates[1].pressed)
	_check("reprise : gardien 0 mort, reliquaire rendu", room.dead[0] and not room.dead[1] and room.relics.size() == 1)
	await get_tree().create_timer(3.8).timeout
	_check("reprise : le gardien vivant revient", room.guardians[1] != null)


## Carte B dont le secret n'est pas tiré : salle scellée, aucune SecretRoom, ni plaque, ni gardien, ni ligne d'objectif.
func _test_unarmed(id: String) -> void:
	await _load_map(id, false)
	_check("%s non tiré : aucune SecretRoom" % id, _mgr.secrets.is_empty() and _mgr.secret_status().is_empty())
	var panel := ObjectivesPanel.new()
	panel.stage_manager = _mgr
	add_child(panel)
	panel.refresh()
	_check("%s non tiré : aucune ligne secrète" % id, not panel.is_secret_shown())
	panel.queue_free()
	var mm := Minimap.new()
	add_child(mm)
	mm._bind_map(_mgr.map)
	var dc: Vector2i = mm._secret_cells.keys()[0]
	_check("%s non tiré : minimap porte = mur" % id, mm._vis_cell(dc.x, dc.y) == "#")
	mm.queue_free()
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	var door := _mgr.map.get_node("Obstacles/Walls/Door_%s" % String(meta["secrets"][0]["id"])) as CollisionShape2D
	_check("%s non tiré : porte pleine" % id, door != null and not door.disabled)
	var d := _mgr.to_dict()
	_check("%s non tiré : sauvegarde sans secret" % id, (d["secrets"] as Array).is_empty())


func _test_frequency() -> void:
	FloorPlan.force_secret = -1
	var n := 3000
	var with_secret := 0
	var per_floor := {1: 0, 2: 0, 3: 0, 4: 0}
	var multi := 0
	var on_five := 0
	var cand_floor := 0
	for s in n:
		var plan := FloorPlan.build(s * 7919 + 13, {})
		var count := 0
		for e: Dictionary in plan:
			if bool(e["secret"]):
				count += 1
				if int(e["floor"]) >= 5 or bool(e["final"]):
					on_five += 1
				elif per_floor.has(int(e["floor"])):
					per_floor[int(e["floor"])] += 1
				_check("secret seulement sur une carte à secret (seed %d)" % s, FloorPlan.map_has_secret(String(e["map_id"])))
		if count > 1:
			multi += 1
		with_secret += mini(count, 1)
		if FloorPlan.secret_floor(plan) != 0:
			cand_floor += 1
		if s < 50: # déterminisme
			var again := FloorPlan.build(s * 7919 + 13, {})
			_check("plan déterministe (seed %d)" % s, FloorPlan.secret_floor(again) == FloorPlan.secret_floor(plan))
	var freq := float(with_secret) / float(n)
	print("secrets : fréquence %.3f sur %d graines, par étage %s" % [freq, n, per_floor])
	_check("fréquence ≈ 1/3 (%.3f)" % freq, absf(freq - 1.0 / 3.0) <= 0.03)
	_check("jamais 2 secrets dans une run", multi == 0)
	_check("jamais d'étage 5", on_five == 0)
	_check("les 4 étages sont tirés", per_floor[1] > 0 and per_floor[2] > 0 and per_floor[3] > 0 and per_floor[4] > 0, str(per_floor))
	# option de test
	FloorPlan.force_variant = "B"
	FloorPlan.force_secret = 3
	_check("force_secret=3 -> étage 3", FloorPlan.secret_floor(FloorPlan.build(5, {})) == 3)
	FloorPlan.force_secret = 5
	_check("force_secret=5 -> aucun (jamais l'étage 5)", FloorPlan.secret_floor(FloorPlan.build(5, {})) == 0)
	FloorPlan.force_secret = 0
	_check("force_secret=0 -> aucun", FloorPlan.secret_floor(FloorPlan.build(5, {})) == 0)
	FloorPlan.force_secret = -1
	FloorPlan.force_variant = ""
	# sans fin : jamais de secret au-delà du plan
	var plan1 := FloorPlan.build(77, {})
	for st in range(6, 16):
		_check("sans fin étage %d : pas de secret" % st, not bool(FloorPlan.entry_for_stage(plan1, st, 77, {}).get("secret", false)))


## Le tirage est mémorisé dans le plan sauvegardé : aller-retour JSON identique, étage armé conservé.
func _test_plan_save() -> void:
	FloorPlan.force_variant = "B"
	FloorPlan.force_secret = 2
	RunState.start_run(&"moyen", 31)
	_mgr.reset_run()
	FloorPlan.force_secret = -1 # la reprise ne doit pas dépendre de l'option de test
	FloorPlan.force_variant = ""
	RunState.stage = 2
	_mgr.start_stage()
	await _frames(2)
	_check("plan : secret armé à l'étage 2", _mgr.secrets.size() == 1)
	var d := _mgr.to_dict()
	_mgr.from_dict(JSON.parse_string(JSON.stringify(d)))
	await _frames(2)
	_check("reprise : secret toujours armé à l'étage 2", _mgr.secrets.size() == 1 and FloorPlan.secret_floor(_mgr.floor_plan) == 2)
	RunState.stage = 1
	_mgr.start_stage()
	await _frames(2)
	_check("étage 1 : aucun secret", _mgr.secrets.is_empty())


## Table de butin des reliquaires (kind guardian) : jamais Commun, Rare ≈ 12 %, jamais Légendaire (sous le coffre de boss).
func _test_guardian_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var n := 5000
	var cnt := {&"commun": 0, &"peu_commun": 0, &"rare": 0, &"legendaire": 0}
	for i in n:
		cnt[LootRoller.roll_quality(&"guardian", rng)["quality"]] += 1
	var rare := float(cnt[&"rare"]) / n
	print("reliquaire : ", cnt, " rare %.3f" % rare)
	_check("reliquaire : jamais Commun", cnt[&"commun"] == 0)
	_check("reliquaire : jamais Légendaire", cnt[&"legendaire"] == 0)
	_check("reliquaire : Rare ≈ 12 %% (%.3f)" % rare, absf(rare - 0.12) <= 0.02)
	_check("reliquaire : Rare sous le coffre de boss", float(Balance.CHEST_QUALITY_TABLE[&"guardian"][&"rare"]) <= float(Balance.CHEST_QUALITY_TABLE[&"boss"][&"rare"]))
	_check("reliquaire : table à 100", int(Balance.CHEST_QUALITY_TABLE[&"guardian"].values().reduce(func(a, b): return a + b)) == 100)
	var ch := Chest.new()
	_check("reliquaire : gratuit", (func() -> bool:
		ch.kind = &"guardian"
		return ch.is_free()).call())
	ch.free()


## Ouvre la porte par un déclencheur autre que les plaques : même salle, mêmes gardiens, mêmes reliquaires.
func _test_trigger(id: String, trig: String) -> void:
	await _load_map(id, true, trig)
	var tag := "%s/%s" % [id, trig]
	_check("%s : une SecretRoom au bon déclencheur" % tag, _mgr.secrets.size() == 1 and _mgr.secrets[0].trigger == StringName(trig))
	if _mgr.secrets.size() != 1:
		return
	var room := _mgr.secrets[0]
	var map := _mgr.map
	_check("%s : aucune plaque" % tag, room.plates.is_empty())
	var panel := ObjectivesPanel.new()
	panel.stage_manager = _mgr
	add_child(panel)
	panel.refresh()
	_check("%s : pas de ligne avant la 1re interaction" % tag, not panel.is_secret_shown())
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	var door := map.get_node("Obstacles/Walls/Door_%s" % String(room.secret_id)) as CollisionShape2D
	_check("%s : porte fermée" % tag, not room.is_open and door != null and not door.disabled)
	match trig:
		"lever":
			_check("%s : levier posé" % tag, room.lever != null and room.lever.is_in_group(&"interactable"))
			_player.global_position = map.to_global(map.get_player_start())
			await _frames(2)
			_check("%s : levier hors de portée : pas d'interaction" % tag, not room.lever.can_interact() and not room.lever.interact())
			_player.global_position = room.lever.global_position # au contact seulement : rien ne se passe sans « interagir »
			await _frames(3)
			_check("%s : pas d'ouverture au contact" % tag, not room.is_open and room.lever.can_interact())
			_check("%s : invite du levier" % tag, bool(room.lever.interact_state()["visible"]) and room.lever.interact_state()["label"] == "Actionner")
			_check("%s : interagir -> levier tiré" % tag, room.lever.interact() and room.lever.used)
		"wall":
			var w: SecretWall = room.wall
			_check("%s : mur fissuré posé, couche ennemis" % tag, w != null and w.collision_layer == 4 and w.is_in_group(&"secret_wall"))
			_check("%s : PV du mur = %.1f s de dégâts de référence" % [tag, Balance.SECRET_WALL_SECONDS], absf(w.hp_max - SecretWall.hp_for_level(RunState.level)) < 0.01)
			var stub := GDScript.new() # lanceur factice : un coup de projectile vaut 7 PV (chemin Projectile._on_hit)
			stub.source_code = "extends RefCounted
func compute_damage(_s, _e, _c):
	return 7.0
"
			stub.reload()
			var proj: Area2D = load("res://scenes/spells/projectile.tscn").instantiate()
			add_child(proj)
			proj.caster = stub.new()
			proj.spell = SpellData.new()
			proj.active = true
			proj.hits_left = 2
			proj.call(&"_on_hit", w)
			_check("%s : un projectile entame le mur" % tag, absf(w.hp_max - w.hp - 7.0) < 0.01 and proj.hits_left == 1)
			proj.call(&"_on_hit", w)
			_check("%s : un même projectile ne frappe pas deux fois" % tag, absf(w.hp_max - w.hp - 7.0) < 0.01)
			proj.queue_free()
			w.hp = w.hp_max
			w.take_hit(w.hp_max * 0.4)
			panel.refresh()
			_check("%s : ligne « Mur fissuré 40 %% »" % tag, panel.is_secret_shown() and panel.secret_text() == "Mur fissuré 40 %", panel.secret_text())
			_check("%s : toujours fermée à 40 %%" % tag, not room.is_open)
			w.take_hit(w.hp_max)
		"pillar":
			var b: SecretBeacon = room.beacon
			_check("%s : pilier éteint posé" % tag, b != null)
			_player.global_position = map.to_global(map.get_player_start())
			RunState.running = true
			await _frames(3)
			_check("%s : hors du cercle, aucune charge" % tag, b.charge_s == 0.0)
			_player.global_position = b.global_position
			await _frames(30)
			panel.refresh()
			_check("%s : charge en cours (ligne « Pilier »)" % tag, b.charge_s > 0.0 and panel.is_secret_shown() and panel.secret_text().begins_with("Pilier "), panel.secret_text())
			b.charge_s = Balance.SECRET_PILLAR_CHARGE_S - 0.05 # abrège l'attente : le dernier tour de charge reste réel
			await _frames(6)
			RunState.running = false
	await _frames(4)
	_check("%s : porte ouverte" % tag, room.is_open and door.disabled and int(RunState.counters.get("secret_zones", 0.0)) == 1)
	var nav: NavField = _director.nav
	var inside := map.to_global(_room_point(meta))
	_check("%s : salle accessible porte ouverte" % tag, nav != null and nav.is_reachable(inside))
	await get_tree().create_timer(SecretRoom.TELEGRAPH_S + SecretRoom.GUARDIAN_GAP_S + 0.6).timeout
	_check("%s : 2 gardiens apparus" % tag, room.guardians[0] != null and room.guardians[1] != null)
	var chests0 := _mgr.chests.size()
	for i in 2:
		if room.guardians[i] != null:
			room.guardians[i].take_damage(1.0e9, false, &"test")
	await _frames(3)
	_check("%s : secret terminé, 2 reliquaires" % tag, room.is_complete() and _mgr.chests.size() == chests0 + 2 and _mgr.chests.back().kind == &"guardian")
	panel.queue_free()


## Sauvegarde / reprise de chaque déclencheur : avancement conservé, déclencheur inchangé.
func _test_trigger_save(id: String) -> void:
	await _load_map(id, true, "wall")
	var room := _mgr.secrets[0]
	room.wall.take_hit(room.wall.hp_max * 0.5)
	var d := _mgr.to_dict()
	_check("sauvegarde mur : déclencheur et avancement", d["secrets"][0]["trigger"] == "wall" and absf(float(d["secrets"][0]["progress"]) - 0.5) < 0.01)
	_mgr.from_dict(JSON.parse_string(JSON.stringify(d)))
	await _frames(3)
	room = _mgr.secrets[0]
	_check("reprise mur : fissure à 50 %", room.trigger == &"wall" and absf(room.wall.ratio() - 0.5) < 0.01 and not room.is_open)
	await _load_map(id, true, "pillar")
	room = _mgr.secrets[0]
	room.beacon.charge_s = 3.0
	d = _mgr.to_dict()
	_mgr.from_dict(JSON.parse_string(JSON.stringify(d)))
	await _frames(3)
	room = _mgr.secrets[0]
	_check("reprise pilier : 3/6 s", room.trigger == &"pillar" and absf(room.beacon.charge_s - 3.0) < 0.01)
	await _load_map(id, true, "lever")
	room = _mgr.secrets[0]
	room.lever.pull(false)
	await _frames(3)
	d = _mgr.to_dict()
	_mgr.from_dict(JSON.parse_string(JSON.stringify(d)))
	await _frames(4)
	room = _mgr.secrets[0]
	_check("reprise levier : tiré, porte ouverte", room.trigger == &"lever" and room.lever.used and room.is_open)


## Tirage du déclencheur : déterministe par graine, les 4 types sortent, l'option de test l'impose.
func _test_trigger_draw() -> void:
	FloorPlan.force_secret = -1
	var count := {}
	for sd in 600:
		var plan := FloorPlan.build(sd * 131 + 7, {})
		var again := FloorPlan.build(sd * 131 + 7, {})
		var f := FloorPlan.secret_floor(plan)
		_check("déclencheur déterministe (seed %d)" % sd, f == FloorPlan.secret_floor(again) and (f == 0 or FloorPlan.trigger_of(plan[f - 1]) == FloorPlan.trigger_of(again[f - 1])))
		if f > 0:
			var t := FloorPlan.trigger_of(plan[f - 1])
			count[t] = int(count.get(t, 0)) + 1
	print("déclencheurs : ", count)
	for t in Balance.SECRET_TRIGGERS:
		_check("déclencheur %s tiré" % t, int(count.get(t, 0)) > 20, str(count))
	FloorPlan.force_secret = 2
	for t in Balance.SECRET_TRIGGERS:
		FloorPlan.force_trigger = t
		var plan := FloorPlan.build(11, {})
		_check("--force-trigger=%s" % t, FloorPlan.secret_floor(plan) == 2 and FloorPlan.trigger_of(plan[1]) == t)
	FloorPlan.force_trigger = &""
	FloorPlan.force_secret = -1
