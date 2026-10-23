extends Node
## Rythme des coups de boss (BossPace, retour joueur 22/10/2026 : « ils frappent en marchant »).
## godot --headless --path game res://tests/boss_pace_test.tscn  -> RESULT: OK
## Vérification générique, pour CHAQUE boss d'étage et CHAQUE mini-boss : combat contre un joueur invulnérable
## placé tour à tour au contact, à mi-distance et loin ; à chaque pas d'IA :
## 1. pendant l'armement et la récupération (BossPace WIND / RECOVER) la position du boss ne bouge pas
##    (ruées, bonds et téléports en ACTIVE exclus : ils gardent leur mouvement pendant l'action) ;
## 2. au moins un armement et une récupération vus, et chaque récupération >= Balance.BOSS_PACE_RECOVER_MIN_S ;
## 3. l'auto de boss d'étage arme >= 0,5 s, celle d'un mini-boss >= 0,45 s, un sort >= 0,8 s (table Balance).
## Arène fermée sans carte (pas d'eau : l'Anguille reste en surface simulée ; les mécaniques de carte ont leurs tests).

const U := 64.0
const ARENA := 1280.0
const FLOOR_BOSSES := [&"cerf", &"sonneur", &"recluse", &"rain_sower", &"crane", &"smelter", &"crystal_mother",
	&"deep_eel", &"weaver", &"hermit_cedar", &"eclusier", &"ox_herder", &"jar_bearer"]
const SEGMENTS_U := [2.0, 5.0, 3.0, 8.0, 2.5] ## distances successives du joueur (u)
const SEGMENT_S := 2.4
const EPS_PX := 0.01

var _fails := 0
var _player
var _director: Director
var _map: Node2D


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok  " + label)
	else:
		_fails += 1
		print("  ÉCHEC  " + label + ("  (" + detail + ")" if detail != "" else ""))


func _wall(parent: Node, center: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	b.add_child(cs)
	b.position = center
	parent.add_child(b)


func _run() -> void:
	RunState.level = 1
	_map = Node2D.new()
	_map.name = &"BossPaceMap"
	get_tree().root.add_child(_map)
	_wall(_map, Vector2(0, -ARENA), Vector2(ARENA * 2 + 128, 128))
	_wall(_map, Vector2(0, ARENA), Vector2(ARENA * 2 + 128, 128))
	_wall(_map, Vector2(-ARENA, 0), Vector2(128, ARENA * 2 + 128))
	_wall(_map, Vector2(ARENA, 0), Vector2(128, ARENA * 2 + 128))
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	_player.global_position = Vector2(0, 300)
	await get_tree().process_frame
	_director.bind_map(_map)
	for i in 2:
		await get_tree().physics_frame
	_player.grant_invulnerability(1.0e6)
	_player.set_physics_process(false) # joueur immobile, placé par le test

	_check("tables Balance : auto d'étage >= 0,5 s, auto de mini >= 0,45 s, sort >= 0,8 s",
		BossPace.windup(&"auto", 3) >= 0.5 and BossPace.windup(&"mini_auto", 2) >= 0.45 and BossPace.windup(&"spell", 3) >= 0.8)
	_check("phase 1 plus lente que la phase 3", BossPace.windup(&"spell", 1) > BossPace.windup(&"spell", 3) and BossPace.recover_s(&"spell", 1) > BossPace.recover_s(&"spell", 3))

	for id: StringName in FLOOR_BOSSES:
		await _fight(&"etage", id)
	var minis: Dictionary = MiniBossBrain.data().get("minis", {})
	for id: String in minis.keys():
		await _fight(&"mini", StringName(id))

	_map.queue_free()
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _fight(kind: StringName, id: StringName) -> void:
	_director.despawn_all()
	for m in [&"next_boss_id", &"next_mini_id"]:
		if _director.has_meta(m):
			_director.remove_meta(m)
	_director.set_meta(&"next_boss_id" if kind == &"etage" else &"next_mini_id", id)
	var b := _director.spawn_boss(kind, Vector2.ZERO) as Enemy
	await get_tree().physics_frame
	var pace: BossPace = b.brain.get(&"pace") if b.brain != null else null
	_check("%s : cerveau avec BossPace" % id, pace != null, str(b.brain))
	if pace == null:
		return
	b.max_hp = 1.0e9 # pas de changement de phase : on mesure le rythme, pas les transitions
	b.hp = 1.0e9
	var moved := 0
	var worst := 0.0
	var worst_stage := &""
	var frames := 0
	var min_rec := 99.0
	var prev_pos := b.position
	var prev_planted := pace.planted()
	var prev_rec := pace.recover_count
	var ang := 0.7
	for seg_u: float in SEGMENTS_U:
		ang += 2.1
		var at := b.position + Vector2.from_angle(ang) * (seg_u * U + b.radius_px)
		at = at.clamp(Vector2(-ARENA + 160, -ARENA + 160), Vector2(ARENA - 160, ARENA - 160))
		_player.global_position = at
		var t := 0.0
		while t < SEGMENT_S:
			await get_tree().physics_frame
			t += 1.0 / 60.0
			frames += 1
			if not b.active:
				break
			var planted := pace.planted()
			var d := b.position.distance_to(prev_pos)
			if prev_planted and planted and d > EPS_PX:
				moved += 1
				if d > worst:
					worst = d
					worst_stage = pace.stage_name()
			if pace.recover_count != prev_rec:
				prev_rec = pace.recover_count
				min_rec = minf(min_rec, pace.last_recover)
			prev_pos = b.position
			prev_planted = planted
	_check("%s : immobile pendant armement et récupération" % id, moved == 0,
		"%d pas sur %d ont bougé, pire %.2f px en %s" % [moved, frames, worst, worst_stage])
	_check("%s : armements (%d) et récupérations (%d) vus" % [id, pace.wind_count, pace.recover_count],
		pace.wind_count >= 1 and pace.recover_count >= 1)
	if pace.recover_count >= 1:
		_check("%s : récupération lisible (min %.2f s)" % [id, min_rec], min_rec >= Balance.BOSS_PACE_RECOVER_MIN_S - 0.001)
