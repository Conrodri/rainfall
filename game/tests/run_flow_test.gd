extends Node
## Run complète automatique (plan item 6, docs/Design_Etages.md §2) : étages 1 -> 5 dans le vrai Main,
## en accéléré (temps actif avancé, piliers chargés d'un coup, boss tués par dégâts directs) :
## - chaque étage : carte et biome du plan (data/floors.json), carte iso, ambiance du profil, monstres qui
##   apparaissent, petits piliers (mini-boss du plan si livrés) -> gros pilier (boss d'étage) -> téléporteur ;
## - étage 5 (la Source) : paratonnerre-mère seul, boss final rain_sower appelé par l'interaction, pilier
##   terminé à sa mort -> téléporteur -> choix -> « Terminer la run » -> victoire (récap, rubis, sauvegarde
##   supprimée) ; FINAL_STAGE = FloorPlan.final_floor() ; 13 piliers terminés.
## godot --headless --path game res://tests/run_flow_test.tscn  -> RESULT: OK
## Sauvegarde de test seulement (jamais user://run_save.json) ; Profile n'écrit jamais en headless.

const SAVE := "user://test_run_flow.json"
const FLOOR_TIME_S := 240.0 ## temps actif ajouté par étage (≈ 4 min : difficulté réaliste)
const KILL_GUARD := 9000 ## frames max pour tuer un boss (phases, invulnérabilités de cerveau ; bouclier de raid ignoré = garde-fou de 45 s par phase)

var _main: Node
var _fails := 0
var _started: Array = []
var _won := [false, 0]


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_check("FINAL_STAGE = étage final de data/floors.json", StageManager.FINAL_STAGE == FloorPlan.final_floor() and FloorPlan.final_floor() == 5)
	_check("fauna.json cohérent avec floors.json", _fauna_consistent())
	Events.floor_started.connect(func(s: int) -> void: _started.append(s))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	_main.set(&"saves_in_headless", true)
	_main.set(&"run_seed", 2026)
	_main.run_ended.connect(func(v: bool, r: int) -> void: _won[0] = v; _won[1] = r)
	add_child(_main)
	await _main.game_ready
	await _frames(3)
	var stage: StageManager = _main.get(&"stage")
	var player: Node2D = _main.get(&"player")
	player.grant_invulnerability(99999.0)
	for floor_n in range(1, StageManager.FINAL_STAGE + 1):
		await _play_floor(stage, player, floor_n)
		if _fails > 0 and floor_n < StageManager.FINAL_STAGE and not stage.floor_cleared:
			break
		stage.teleporter.use()
		await _frames(4)
	# --- fin : choix victoire / sans fin -> Terminer
	var vs: RunScreens = _main.victory_screen
	_check("étage final : écran de choix", vs != null and RunState.stage == StageManager.FINAL_STAGE)
	if vs != null:
		vs.press(0)
		await _frames(3)
	_check("victoire : run terminée", _main.run_over and _won[0] and _main.end_screen != null)
	_check("victoire : rubis", int(_won[1]) > 0, str(_won[1]))
	_check("13 piliers terminés (4 × 3 + paratonnerre)", int(_main.pillars_done) == 13, str(_main.pillars_done))
	_check("sauvegarde supprimée à la fin", not FileAccess.file_exists(SAVE))
	_check("étages lancés 1..5", _started == [1, 2, 3, 4, 5], str(_started))
	print("run complète : %d ms, temps actif %.0f s, niveau %d, %d kills" % [Time.get_ticks_msec() - t0, RunState.active_time_s, RunState.level, RunState.kills])
	_finish()


func _play_floor(stage: StageManager, player: Node2D, floor_n: int) -> void:
	var plan := stage.plan_entry(floor_n)
	_check("étage %d : carte du plan %s" % [floor_n, plan.get("map_id")], RunState.stage == floor_n and stage.map_id == String(plan.get("map_id", "")) and stage.map.is_iso(), "%d %s" % [RunState.stage, stage.map_id])
	_check("étage %d : biome %s" % [floor_n, plan.get("biome")], EnemyVisual.current_biome() == StringName(plan.get("biome", "")), str(EnemyVisual.current_biome()))
	var amb: AmbianceManager = _main.get(&"ambiance")
	_check("étage %d : ambiance" % floor_n, amb.profile != null and String(amb.profile.map_id) == stage.map_id)
	RunState.active_time_s += FLOOR_TIME_S
	# quelques secondes de jeu : le Director fait apparaître des monstres
	var director: Director = _main.get(&"director")
	player.global_position = stage.map.to_global(stage.map.get_player_start())
	var total0 := director.spawned_total
	director.credits = 150.0
	director.wave_credits = 150.0
	director.trigger_wave()
	await _frames(45)
	_check("étage %d : monstres" % floor_n, director.spawned_total > total0, str(director.spawned_total - total0))
	var final := stage.is_final_floor
	_check("étage %d : piliers (%s)" % [floor_n, "1 final" if final else "2 + 1"], stage.pillars.size() == (1 if final else 3) and (stage.pillars.back() as Pillar).final_boss == final)
	for p: Pillar in stage.pillars:
		if p.kind == Pillar.Kind.SMALL:
			await _clear_pillar(p, player, director, floor_n)
	var big: Pillar = stage.pillars.back()
	_check("étage %d : gros pilier déverrouillé" % floor_n, big.state == Pillar.STATE_READY)
	await _clear_pillar(big, player, director, floor_n)
	_check("étage %d : terminé, sortie ouverte" % floor_n, stage.floor_cleared and stage.teleporter.active)


func _clear_pillar(p: Pillar, player: Node2D, director: Director, floor_n: int) -> void:
	player.global_position = p.global_position + Vector2(24, 24)
	p._on_body_entered(player)
	var ok := p.can_interact() and p.activate()
	var boss: Enemy = p.get(&"_boss")
	var label := "étage %d : %s %s" % [floor_n, "paratonnerre" if p.final_boss else ("gros" if p.kind == Pillar.Kind.BIG else "petit"), String(boss.get(&"_boss_sprite_id")) if boss != null else "?"]
	_check(label + " : boss apparu", ok and boss != null and boss.active)
	if boss == null:
		return
	if p.kind == Pillar.Kind.BIG and not p.final_boss:
		_check(label + " : boss du plan", boss.get_meta(&"boss_id", &"") == (get_parent_stage().floor_boss))
		for i in 95: # charge accélérée (le joueur est dans la zone)
			p.tick(1.0)
	if p.final_boss:
		_check(label + " : rain_sower final", boss.get_meta(&"boss_id", &"") == &"rain_sower" and bool(boss.get_meta(&"final_boss", false)))
	var guard := 0
	while boss.active and guard < KILL_GUARD:
		player.set(&"hp", player.get(&"max_hp")) # le flux ne teste pas la survie : les boss de raid pressent un joueur immobile (DoT compris)
		if boss.hp > 0.0:
			boss.take_damage(boss.max_hp * 0.2)
		await get_tree().physics_frame
		guard += 1
	await _frames(2)
	_check(label + " : boss tué, pilier terminé", not boss.active and p.state == Pillar.STATE_DONE, "guard %d, état %s" % [guard, p.state])


func get_parent_stage() -> StageManager:
	return _main.get(&"stage")


## data/fauna.json garde la faune (sprites) ; ses listes de roster doivent rester celles de floors.json.
func _fauna_consistent() -> bool:
	var ok := true
	for f: Dictionary in FloorPlan.floors():
		var bd := EnemyVisual.biome_data(StringName(f["biome"]))
		if bd.is_empty() or int(bd.get("floor", -1)) != int(f["floor"]) or bd.get("floor_bosses", []) != f.get("floor_bosses", []) \
				or (bd.get("minis", []) as Array).duplicate().map(func(x): return String(x)) != (f.get("minis", []) as Array).map(func(x): return String(x)):
			print("  incohérence fauna/floors : ", f["biome"])
			ok = false
		if EnemyVisual.biome_for_floor(int(f["floor"])) != StringName(f["biome"]):
			ok = false
	return ok


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
