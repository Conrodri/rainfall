extends Node
## Étage 4 (Cryptes noyées) : ses trois boss d'étage (Reclus, Mère-Cristal, Anguille des profondeurs).
## godot --headless --path game res://tests/floor4_boss_test.tscn  -> RESULT: OK
## Pour chaque boss : roster (data/floors.json, fauna.json : chemin du sprite + IA enregistrée), apparition par le
## Director avec floor_boss = id (IA propre branchée, PV de Balance), combat réel ~9 s joueur à ~4 u : coups
## reçus par le joueur, coups du joueur reçus par le boss ; mort -> Events.boss_killed, IA libérée, aucun
## nœud du boss laissé (sans charge en cours, pas de trace). Sauvegarde de test seulement.

const MAP := "res://scenes/stage/maps/cryptes_noyees.tscn"
const SAVE := "user://test_floor4_boss.json"
const BOSSES := [&"recluse", &"crystal_mother", &"deep_eel"]
const PREFIX := {&"recluse": "Recluse", &"crystal_mother": "CrystalMother", &"deep_eel": "DeepEel"}
const BRAINS := {&"recluse": "RecluseBrain", &"crystal_mother": "CrystalMotherBrain", &"deep_eel": "DeepEelBrain"}
const FIGHT_S := 9.0
## Plafond : au-delà de FIGHT_S, le combat continue jusqu'au premier coup reçu ET porté (exigence inchangée : >= 1).
## Les tirs de la Mère-Cristal sont visés et le joueur tourne à 2 u/s : seule une volée de stalactites (anneau à angle
## aléatoire, `_rng.randomize()`) le touche en 9 s, ~1 fois sur 3 aucune (sonde 22/10/2026, rayon joueur 26 px inchangé).
const FIGHT_MAX_S := 30.0

var _main: Node
var _fails := 0
var _step := -1
var _t := 0.0
var _i := 0
var _boss: Enemy = null
var _hits := 0
var _hurt := 0
var _killed := 0
var _origin := Vector2.ZERO


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(MAP))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 44)
	add_child(_main)
	Events.player_damaged.connect(func(_a: float, source: Node) -> void:
		if _boss != null and source == _boss:
			_hits += 1)
	Events.enemy_damaged.connect(func(enemy: Node2D, _a: float, _c: bool, _el: StringName) -> void:
		if _boss != null and enemy == _boss:
			_hurt += 1)
	Events.boss_killed.connect(func(_b: Variant = null, _x: Variant = null) -> void: _killed += 1)
	_main.game_ready.connect(func() -> void: _step = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


func _physics_process(delta: float) -> void:
	if _step < 0 or _step == 99:
		return
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	_t += delta
	var p := _player()
	if p != null and p.hp < p.max_hp * 0.5:
		p.hp = p.max_hp
		p.set(&"_invuln", 0.0)
		p.clear_statuses()
	match _step:
		0:
			_director().spawning_enabled = false
			if _t > 1.6:
				for e in get_tree().get_nodes_in_group(&"enemies").duplicate():
					if e is Enemy and not e.is_boss:
						_director().release_enemy(e)
				RunState.stage = 4
				_roster()
				_origin = p.global_position
				_spawn()
		1:
			# le joueur tourne autour du boss à ~4 u (l'Anguille : autour de son lac)
			var c := _boss.position
			if _boss.brain is DeepEelBrain:
				c = (_boss.brain as DeepEelBrain).center
			var r := 4.0 * 64.0 + (float((_boss.brain as DeepEelBrain).pool_r) if _boss.brain is DeepEelBrain else 0.0)
			var want := c + Vector2.from_angle(_t * 0.5) * r
			p.global_position = _director().nav.resolve(want, 26.0) if _director().nav != null else want
			if _t > FIGHT_S and ((_hits >= 1 and _hurt >= 1) or _t > FIGHT_MAX_S):
				_end_fight()
		2:
			if _t > 0.6:
				var id: StringName = BOSSES[_i]
				_check("%s : aucun nœud laissé après la mort" % id, _leftovers(PREFIX[id]).is_empty(), str(_leftovers(PREFIX[id])))
				_i += 1
				if _i >= BOSSES.size():
					_finish()
				else:
					_spawn()


func _roster() -> void:
	var fl: Dictionary = {}
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/floors.json"))
	for f in (data["floors"] as Array):
		if int(f["floor"]) == 4:
			fl = f
	_check("floors.json : étage 4 = cryptes, 4 boss d'étage (Roi de sel : raid)", fl.get("biome", "") == "cryptes" and (fl["floor_bosses"] as Array) == ["recluse", "crystal_mother", "deep_eel", "salt_king"], str(fl))
	for id in BOSSES:
		var cfg := EnemyVisual.boss_cfg(id)
		var brain := String(cfg.get("brain", ""))
		_check("%s : fauna.json (sprite + IA enregistrés)" % id, EnemyVisual.boss_path(id) != "" and brain != "" and ResourceLoader.exists("res://" + brain), "%s %s" % [EnemyVisual.boss_path(id), brain])


func _spawn() -> void:
	var id: StringName = BOSSES[_i]
	(_main.get(&"stage") as StageManager).floor_boss = id
	var pos := _origin + Vector2(0.0, 5.0 * 64.0)
	if _director().nav != null:
		pos = _director().nav.resolve(pos, 40.0)
	_boss = _director().spawn_boss(&"etage", pos) as Enemy
	_hits = 0
	_hurt = 0
	_killed = 0
	_check("%s : apparu, IA %s branchée" % [id, BRAINS[id]], _boss != null and StringName(_boss.get(&"_boss_sprite_id")) == id
		and _boss.brain != null and (_boss.brain.get_script() as Script).get_global_name() == BRAINS[id], str(_boss.brain))
	_check("%s : PV de Balance" % id, is_equal_approx(_boss.max_hp, Balance.boss_hp(&"etage", RunState.difficulty(), RunState.stage)), "%.0f" % _boss.max_hp)
	_next(1)


func _end_fight() -> void:
	var id: StringName = BOSSES[_i]
	_check("%s : coups reçus par le joueur" % id, _hits >= 1, str(_hits))
	_check("%s : coups du joueur reçus par le boss" % id, _hurt >= 1, str(_hurt))
	_boss.take_damage((_boss.hp + 1.0) / float(_boss.brain.damage_taken_mult())) # Anguille plongée : × 0,3
	_check("%s : mort -> boss_killed, IA libérée" % id, not _boss.active and _boss.brain == null and _killed >= 1, "%s %s %d" % [_boss.active, _boss.brain, _killed])
	print("  %s : %d coups reçus, %d coups portés en %.1f s" % [id, _hits, _hurt, _t])
	_next(2)


func _leftovers(prefix: String) -> Array:
	var left: Array = []
	var roots: Array[Node] = [_director().get_node(^"Enemies")]
	var layer := AmbianceManager.telegraph_layer(get_tree())
	if layer != null:
		roots.append(layer)
	for r in roots:
		for n in r.get_children():
			if String(n.name).begins_with(prefix) and not n.is_queued_for_deletion():
				left.append(String(n.name))
	return left


func _next(step: int) -> void:
	_step = step
	_t = 0.0


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _finish() -> void:
	_step = 99
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
