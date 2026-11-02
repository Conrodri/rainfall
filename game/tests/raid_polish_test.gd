extends Node
## Finitions des boss de raid : cerveau attaché par id (resolve_boss_id), clear_pose, ids audio du bouclier,
## boucles Audio.play_loop / stop_loop, pulsation d'ultime du HUD.
## godot --headless --path game res://tests/raid_polish_test.tscn  -> RESULT: OK

var _fails := 0
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


func _run() -> void:
	RunState.level = 1
	_map = Node2D.new()
	get_tree().root.add_child(_map)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	var pl := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(pl)
	await get_tree().process_frame
	_director.bind_map(_map)
	await get_tree().physics_frame
	_director.set_physics_process(false)
	pl.set_physics_process(false)

	print("Cerveau par boss_id")
	var want := {&"drowned_idol": "DrownedIdolBrain", &"flood_gunner": "FloodGunnerBrain", &"salt_king": "SaltKingBrain"}
	for id in want:
		_director.set_meta(&"next_boss_id", id)
		var b := _director.spawn_boss(&"etage", Vector2(900, 0)) as Enemy
		_check("%s : boss_id" % id, b.boss_id() == id, str(b.boss_id()))
		_check("%s : cerveau attaché" % id, b.brain != null and b.brain.get_script().resource_path.contains(String(id)))
		var shield: BossShield = b.brain.get(&"shield") if b.brain != null else null
		_check("%s : bouclier présent" % id, shield != null)
		b.brain.clear()
		b.queue_free()
	_director.remove_meta(&"next_boss_id")

	print("EnemyVisual.clear_pose")
	_check("clear_pose existe", EnemyVisual.new().has_method(&"clear_pose"))

	print("Ids audio du bouclier")
	var fake := Node2D.new()
	get_tree().root.add_child(fake)
	var sh := BossShield.create(fake)
	sh._resolve_sfx({"sfx_prefix": "demo"})
	_check("sfx_prefix -> up", sh._sfx_up == &"enemy.demo_shield_up.heavy", str(sh._sfx_up))
	_check("sfx_prefix -> break", sh._sfx_break == &"enemy.demo_shield_break.heavy", str(sh._sfx_break))
	_check("table : Idole", BossShield.SFX_BY_BOSS[&"drowned_idol"]["up"] == &"enemy.idol_shield_up.heavy")
	_check("table : Canonnier rupture générique", BossShield.SFX_BY_BOSS[&"flood_gunner"]["break"] == &"enemy.raid_shield_break.heavy")
	fake.queue_free()

	print("Audio.play_loop")
	var host := Node2D.new()
	get_tree().root.add_child(host)
	var miss := Audio.play_loop(&"zzz.n_existe_pas.loop", host)
	_check("son absent : {} (repli silencieux)", miss.is_empty())
	Audio.stop_loop(miss)
	var real := &""
	for cand in [&"enemy.shield_hum.loop", &"enemy.salt_king_tide.loop", &"amb.salt_court", &"ui.click"]:
		if Audio.bank != null and Audio.bank.has_sound(cand):
			real = cand
			break
	if real != &"":
		var h := Audio.play_loop(real, host)
		_check("boucle %s démarrée" % real, not h.is_empty())
		_check("compte de boucles = 1", Audio.active_loops() == 1)
		Audio.stop_loop(h)
		_check("stop_loop libère", Audio.active_loops() == 0)
		# Intervalle minimum du son : attendu sur l'horloge du pool de voix elle-même (et non un SceneTreeTimer,
		# qui suit les deltas d'images), avec un plafond d'images pour ne jamais bloquer.
		var gap := maxi(int(Audio.bank.get_def(real).get("min_interval_ms", 0)), 0) + 50
		var t0: int = Audio.game_pool.now_ms()
		var waited := 0
		while Audio.game_pool.now_ms() - t0 < gap and waited < 600:
			await get_tree().process_frame
			waited += 1
		var st: Dictionary = Audio.game_pool.stats
		var dropped0 := int(st.dropped)
		var h2 := Audio.play_loop(real, host)
		_check("2e boucle démarrée", not h2.is_empty(), "attente %d ms / %d images, voix actives %d, famille %s : %d, refusées +%d" % [
				Audio.game_pool.now_ms() - t0, waited, Audio.game_pool.active_total(), Audio.bank.get_def(real).get("family", "?"),
				Audio.game_pool.active_in_family(String(Audio.bank.get_def(real).get("family", ""))), int(st.dropped) - dropped0])
		host.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		_check("hôte libéré : boucle coupée", Audio.active_loops() == 0)
	else:
		print("  (aucun son existant pour tester la boucle réelle)")
		host.queue_free()

	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)
