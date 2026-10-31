extends Node
## Bouclier ULTIMATE_HIT du Roi de sel : l'ultime (slot 4, base ET variantes) de CHAQUE personnage doit le briser, quelle que
## soit la façon dont le kit inflige ses dégâts (marquage commun SpellCaster.last_hit_ult). Rictus : doublures détonées par la Saccade > 2 s après la pose (counts_as_ultimate).
## godot --headless --path game res://tests/ultimate_shield_test.tscn  -> RESULT: OK

const U := 64.0
const DT := 1.0 / 60.0
const ARENA := 2400.0
const SKIP := []
const CASE_MAX_S := 6.0

var _fails := 0
var _player
var _director: Director
var _map: Node2D
var _boss: Enemy
var _b: SaltKingBrain


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok  " + label)
	else:
		_fails += 1
		print("  ÉCHEC  " + label + ("  (" + detail + ")" if detail != "" else ""))


func _wall(center: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	b.add_child(cs)
	b.position = center
	_map.add_child(b)


func _slot4_ids(cid: StringName) -> Array:
	var ids: Array = [&""] # &"" = sort de base
	var script := CharacterData.kit_script_of(cid)
	if cid == &"ardent":
		script = ArdentKit
	if script == null:
		return ids
	var consts: Dictionary = script.get_script_constant_map()
	for key in consts:
		var v: Variant = consts[key]
		if v is StringName and CharacterData.variant_spell(cid, 4, v, true) != null and not ids.has(v):
			ids.append(v)
	return ids


func _new_player(cid: StringName, vid: StringName) -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
		await get_tree().process_frame
	RunState.character = cid
	RunState.loadout = {} if vid == &"" else {"4": String(vid)}
	RunState.level = 1
	RunState.gold = 100000
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	_player.global_position = Vector2(3.0 * U, 0.0)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_player.max_hp = 1e9
	_player.hp = 1e9
	_player.spells.aim_override = Vector2.ZERO


func _new_boss() -> void:
	if _boss != null and is_instance_valid(_boss) and _boss.active:
		_director.release_enemy(_boss)
	_boss = _director.spawn_boss(&"etage", Vector2.ZERO) as Enemy
	if _boss.brain != null:
		_boss.brain.clear()
	_boss.hp = _boss.max_hp
	_b = SaltKingBrain.new(_boss)
	_boss.brain = _b


func _frame(keep := true) -> void:
	await get_tree().physics_frame
	if keep:
		_player.hp = _player.max_hp
		_player._invuln = 1.0
	_player.tick(DT)
	_boss.tick(DT, _player, _player.global_position, Vector2.ZERO)


func _until(cond: Callable, max_s: float) -> bool:
	for i in int(max_s / DT):
		if cond.call():
			return true
		await _frame()
	return cond.call()


func _prep_ult() -> void:
	# ressources des kits : lame aiguisée (Taliant), charge, etc. ; recharges à zéro
	_player.spells.set_cooldown(4, 0.0, 1.0)
	if _player.kit != null:
		if _player.kit.has_method(&"chain_length"): # Arpenteuse : la Tendeur / le Cerceau veulent une chaîne posée (>= 2 u) -> la tracer en marchant
			for i in 24:
				_player.global_position = Vector2(1.5 * U, (6.0 - 6.0 * float(i) / 23.0) * U)
				await _frame()
		if "sharpness" in _player.kit:
			_player.kit.sharpness = 100.0
		if _player.kit.has_method(&"fill_for_test"):
			_player.kit.fill_for_test()


func _run() -> void:
	RunState.stage = 4
	_map = Node2D.new()
	_map.name = &"SaltMap"
	get_tree().root.add_child(_map)
	_wall(Vector2(0, -ARENA), Vector2(ARENA * 2 + 128, 128))
	_wall(Vector2(0, ARENA), Vector2(ARENA * 2 + 128, 128))
	_wall(Vector2(-ARENA, 0), Vector2(128, ARENA * 2 + 128))
	_wall(Vector2(ARENA, 0), Vector2(128, ARENA * 2 + 128))
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	await get_tree().process_frame
	_director.bind_map(_map)
	await get_tree().physics_frame
	_director.set_physics_process(false)

	var chars: Array = []
	for c in (JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json")) as Array):
		chars.append(StringName(str(c["id"])))
	for cid in chars:
		if SKIP.has(cid):
			continue
		for vid in _slot4_ids(cid):
			await _case(cid, vid)
	await _rearm()
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _case(cid: StringName, vid: StringName) -> void:
	var tag := "%s/%s" % [cid, "base" if vid == &"" else String(vid)]
	await _new_player(cid, vid)
	_new_boss()
	_player.global_position = Vector2(3.0 * U, 0.0)
	_boss.hp = _boss.max_hp * 0.69
	await _frame()
	if not await _until(func(): return _b.shield.state == BossShield.State.ACTIVE, 4.0):
		_check(tag + " : bouclier actif", false, str(_b.shield.state))
		return
	_player.spells.aim_override = _boss.global_position
	await _prep_ult()
	var ok: bool = _player.spells.cast(4)
	if cid == &"rictus":
		# Rictus : l'ultime pose des doublures ; la Saccade les détone plus de 2 s après (hors fenêtre ULT_MARK_S)
		await _frames_run(0.6)
		_player.spells._ult_left = 0.0
		for d in Decoy.live:
			d.life_s = 30.0
		await _frames_run(2.2)
		_player.spells._ult_left = 0.0
		_check(tag + " : doublures posées", not Decoy.live.is_empty())
		_player.spells._remaining[1] = 99.0
		_player.kit.set(&"kstate", 1)
		if vid == &"":
			_check(tag + " : détonation par la Saccade", _player.kit._detonate_decoys(false) > 0)
		else:
			for d in Decoy.live.duplicate():
				d.explode(d.explode_spell)
	if not ok:
		_check(tag + " : ultime lancé", false, "cast refusé")
		return
	var broke := await _until(func(): return _b.shield.state == BossShield.State.BREAKING or _b.shield.state == BossShield.State.EXPOSED, CASE_MAX_S)
	_check(tag + " : l'ultime brise la croûte", broke and not _b.shield.by_backstop, "état %s" % str(_b.shield.state))


func _frames_run(sec: float) -> void:
	for i in int(sec / DT):
		await _frame()


## Une seule croûte par transition : après rupture (ou garde-fou), pas de nouvel arm tant que le seuil suivant n'est pas franchi.
func _rearm() -> void:
	print("Pas de ré-armement")
	await _new_player(&"ardent", &"")
	for by_backstop in [false, true]:
		_new_boss()
		_player.global_position = Vector2(3.0 * U, 0.0)
		_boss.hp = _boss.max_hp * 0.69
		await _frame()
		await _until(func(): return _b.shield.state == BossShield.State.ACTIVE, 4.0)
		if by_backstop:
			await _until(func(): return _b.shield.state == BossShield.State.BREAKING, 60.0)
		else:
			_b.shield.note_ultimate_hit()
			await _frame()
		var armed := _b.shield.armed_count
		_boss.hp = _boss.max_hp * 0.69 # PV maintenus au-dessus du seuil de 35 %
		for i in int(32.0 / DT):
			await _frame()
			_boss.hp = maxf(_boss.hp, _boss.max_hp * 0.5)
		_check("%s : aucun nouvel arm pendant 30 s (armed_count %d)" % ["garde-fou" if by_backstop else "rupture", armed],
			_b.shield.armed_count == armed and _b.phase == 2 and not _boss.is_invulnerable(), "armed %d phase %d" % [_b.shield.armed_count, _b.phase])
