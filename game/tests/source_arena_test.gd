extends Node
## Étage 5 : la Source (arène du boss final, docs/Design_Etages.md §4), dans une vraie run :
## 1. étage 4 -> téléporteur -> étage 5 = la_source iso ; plan : rain_sower ; coffres 6 + 2 + 1 légendaire ;
##    un seul pilier (paratonnerre-mère), prêt d'emblée, « Appeler la Source », pas de petit pilier ;
##    ambiance la_source (colonne de lumière), colonne de pluie (SourceColumn), biome source ;
## 2. le boss final n'apparaît QUE par l'interaction : boss rain_sower (méta boss_id, final_boss), PV ×2 ;
##    zone de charge de 22 u, pression du gros pilier (×2,33, kind `etage` côté Director) ;
## 3. charge complète mais boss vivant : pilier pas terminé ; mort du boss -> pilier terminé, coffre du boss,
##    téléporteur actif ; sauvegarde / reprise pendant le combat : pilier remis « prêt » (boss non sauvegardé) ;
## 4. téléporteur -> choix victoire / sans fin -> sans fin : étage 6 = biome 1 ; étage 10 = la Source sans choix.
## godot --headless --path game res://tests/source_arena_test.tscn  -> RESULT: OK

const SAVE := "user://test_source_arena.json"

var _main: Node
var _fails := 0


func _ready() -> void:
	_main = _new_main({})
	await _main.game_ready
	await _frames(3)
	var stage: StageManager = _main.get(&"stage")
	var player: Node2D = _main.get(&"player")
	player.grant_invulnerability(9999.0)
	_check("plan : étage 5 = la_source / rain_sower", stage.plan_entry(5).get("map_id") == "la_source" and stage.plan_entry(5).get("floor_boss") == "rain_sower", str(stage.plan_entry(5)))
	RunState.stage = 4
	stage.floor_cleared = true
	stage.request_exit()
	await _frames(8)
	_check("étage 5 = la_source", RunState.stage == 5 and stage.map_id == "la_source" and stage.is_final_floor, "%d %s" % [RunState.stage, stage.map_id])
	_check("la Source iso", stage.map.is_iso())
	_check("biome source", EnemyVisual.current_biome() == &"source", str(EnemyVisual.current_biome()))
	var amb: AmbianceManager = _main.get(&"ambiance")
	_check("ambiance la_source", amb.profile != null and amb.profile.map_id == &"la_source")
	_check("lumières (colonne + cristaux)", amb.map_light_count() >= 6, str(amb.map_light_count()))
	_check("colonne de pluie posée", stage.map.get_node_or_null(^"SourceColumn") != null)
	_check("1 seul pilier", stage.pillars.size() == 1)
	var rod: Pillar = stage.pillars[0]
	_check("paratonnerre-mère : gros pilier prêt, boss final", rod.kind == Pillar.Kind.BIG and rod.state == Pillar.STATE_READY and rod.final_boss and rod.boss_id == &"rain_sower")
	_check("« Appeler la Source »", rod.interact_label() == "Appeler la Source")
	_check("zone de 22 u", is_equal_approx(rod.zone_radius(), 22.0 * 64.0))
	var kinds := {}
	for c in stage.chests:
		kinds[c.kind] = int(kinds.get(c.kind, 0)) + 1
	_check("coffres 6 + 2 + 1 légendaire " + str(kinds), kinds.get(&"petit", 0) == 6 and kinds.get(&"large", 0) == 2 and kinds.get(&"legendaire", 0) == 1)

	# --- 60-90 s de libre : aucun boss tant que le paratonnerre n'est pas appelé
	var director: Director = _main.get(&"director")
	for i in 30:
		await get_tree().physics_frame
	_check("pas de boss avant l'interaction", director.boss_count() == 0, str(director.boss_count()))
	# interaction : à portée seulement
	player.global_position = rod.global_position + Vector2(300, 0)
	await _frames(2)
	_check("hors portée : pas interactif", not rod.can_interact())
	player.global_position = rod.global_position + Vector2(20, 20)
	rod._on_body_entered(player)
	_check("à portée : interactif", rod.can_interact())
	var hp_etage := Balance.boss_hp(&"etage", RunState.difficulty(), RunState.stage)
	_check("interaction -> boss", rod.activate() and director.boss_count() == 1)
	var boss: Enemy = rod.get(&"_boss")
	_check("boss rain_sower (méta, sprite id)", boss != null and boss.get_meta(&"boss_id", &"") == &"rain_sower" and boss.get(&"_boss_sprite_id") == &"rain_sower", str(boss.get(&"_boss_sprite_id")) if boss != null else "null")
	_check("boss final marqué", boss != null and bool(boss.get_meta(&"final_boss", false)))
	# Attente périmée (×2 de l'ancien floors.json) : la source unique est Balance.FINAL_BOSS_HP_MULT (audit du 31/10/2026).
	var hp_final := hp_etage * Balance.FINAL_BOSS_HP_MULT * Balance.boss_hp_mode_mult(&"etage", RunState.mode)
	_check("PV × FINAL_BOSS_HP_MULT du boss d'étage", boss != null and absf(boss.max_hp - hp_final) < hp_final * 0.05, "%.0f vs %.0f" % [boss.max_hp if boss else 0.0, hp_final])
	await _frames(2)
	var z: Dictionary = director._zones.get(rod.zone_id, {})
	_check("zone Director : 22 u, gros pilier (×2,33)", bool(z.get("active", false)) and is_equal_approx(float(z.get("radius", 0.0)), 22.0 * 64.0) and z.get("kind") == &"etage", str(z))
	# charge complète, boss vivant : pas terminé
	for i in 100:
		rod.tick(1.0)
	_check("chargé mais boss vivant : pas terminé", rod.is_charged() and rod.state == Pillar.STATE_ACTIVE and not stage.floor_cleared)

	# --- sauvegarde pendant le combat -> reprise : paratonnerre « prêt », boss rappelable
	_check("sauvegarde écrite", _main.autosave())
	var doc := RunSave.load(SAVE)
	_main.queue_free()
	await _frames(3)
	LightRig.clear_all()
	_main = _new_main(doc.get("data", {}))
	await _main.game_ready
	await _frames(3)
	stage = _main.get(&"stage")
	director = _main.get(&"director")
	player = _main.get(&"player")
	player.grant_invulnerability(9999.0)
	rod = stage.pillars[0]
	_check("reprise : la Source, paratonnerre prêt et final", stage.map_id == "la_source" and rod.state == Pillar.STATE_READY and rod.final_boss and stage.pillars.size() == 1)
	player.global_position = rod.global_position + Vector2(20, 20)
	rod._on_body_entered(player)
	_check("reprise : rappel du boss", rod.activate() and director.boss_count() == 1)
	boss = rod.get(&"_boss")
	# mort du boss -> pilier terminé (même sans charge complète)
	var guard := 0
	while boss != null and boss.active and guard < 600:
		boss.take_damage(boss.max_hp * 0.25)
		await get_tree().physics_frame
		guard += 1
	await _frames(3)
	_check("boss final mort", boss != null and not boss.active, str(guard))
	_check("mort du boss -> paratonnerre terminé", rod.state == Pillar.STATE_DONE and stage.floor_cleared and stage.teleporter.active)
	var boss_chest := false
	for c in stage.chests:
		if is_instance_valid(c) and c.kind == &"boss":
			boss_chest = true
	_check("coffre du boss", boss_chest)

	# --- téléporteur : choix victoire / sans fin
	stage.teleporter.use()
	await _frames(2)
	var vs: RunScreens = _main.victory_screen
	_check("choix victoire / sans fin", vs != null and get_tree().paused)
	if vs != null:
		vs.press(1)
		await _frames(5)
	_check("sans fin -> étage 6 = étage 1 (terrasses)", stage.endless and RunState.stage == 6 and FloorPlan.playable_maps(1).has(stage.map_id) and not get_tree().paused, "%d %s" % [RunState.stage, stage.map_id])
	RunState.stage = 9
	stage.floor_cleared = true
	stage.request_exit()
	await _frames(5)
	_check("étage 10 = la Source", RunState.stage == 10 and stage.map_id == "la_source" and stage.is_final_floor)
	rod = stage.pillars[0]
	stage.floor_cleared = true
	stage.request_exit()
	await _frames(3)
	_check("sans fin : la Source sans écran de choix -> étage 11", RunState.stage == 11 and _main.victory_screen == null, str(RunState.stage))
	_finish()


func _new_main(resume: Dictionary) -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"save_path", SAVE)
	m.set(&"saves_in_headless", true)
	m.set(&"run_seed", 51)
	if not resume.is_empty():
		m.set(&"resume_data", resume)
	add_child(m)
	return m


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok  ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _finish() -> void:
	get_tree().paused = false
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
