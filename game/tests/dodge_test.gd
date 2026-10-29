extends Node
## Test headless des esquives par personnage (docs/Design_Esquives.md) : genre, distance, invulnérabilité, recharge,
## charges (Vigie), maintien et eau (Averse), murs jamais traversés (Éclat d'Ardent, roulade), mode test (recharge 0).
## godot --headless --path game res://tests/dodge_test.tscn  -> RESULT: OK

const U := 64.0
const DT := 1.0 / 120.0

## id -> [genre, distance u, invulnérabilité s, recharge s, charges]
const EXPECT := {
	&"ardent": [&"blink", 3.0, 0.20, 3.0, 1],
	&"rictus": [&"roll", 3.0, 0.25, 3.0, 1],
	&"tocsin": [&"roll", 3.0, 0.25, 3.0, 1],
	&"arpenteuse": [&"roll", 3.0, 0.25, 3.0, 1],
	&"rainette": [&"roll", 3.5, 3.5 / 12.0, 3.0, 1], # 3,5 u à 12 u/s : 0,29 s (inchangé)
	&"avare": [&"roll", 2.5, 0.25, 3.0, 1],
	&"bourbe": [&"roll", 3.0, 0.30, 3.0, 1],
	&"vigie": [&"roll", 1.0, 1.0 / 12.0, 1.0, 3],
	&"morfil": [&"roll", 3.0, 0.25, 3.0, 1],
}

var _fails := 0
var _player: CharacterBody2D
var _junk: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _near(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _spawn(cid: StringName) -> void:
	if _player != null:
		_player.queue_free()
	RunState.character = cid
	RunState.loadout = {}
	RunState.level = 1
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	_player.character = null
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_player.reset_dodge()


## Joue l'esquive pas à pas jusqu'à sa fin : {dist_u (signé sur x), invuln_s, elapsed_s}.
func _play(max_s := 2.0) -> Dictionary:
	var x0 := _player.global_position.x
	var inv := 0.0
	var t := 0.0
	while _player.is_dodging() and t < max_s:
		_player.dodge_step(DT)
		_player.tick(DT)
		if _player.is_invulnerable():
			inv += DT
		t += DT
	while _player.is_invulnerable() and t < max_s: # invulnérabilité qui dépasse l'esquive (reformation d'Ardent)
		_player.tick(DT)
		inv += DT
		t += DT
	return {"dist_u": (_player.global_position.x - x0) / U, "invuln_s": inv, "elapsed_s": t}


func _wall(at_x_u: float) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(0.5 * U, 6.0 * U)
	cs.shape = sh
	b.add_child(cs)
	get_tree().root.add_child(b)
	b.global_position = Vector2(at_x_u * U, 0)
	_junk.append(b)
	return b


func _clear_junk() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.queue_free()
	_junk.clear()


func _run() -> void:
	for cid: StringName in EXPECT:
		var e: Array = EXPECT[cid]
		await _spawn(cid)
		print("%s : %s" % [cid, e[0]])
		var dm: DodgeMove = _player.dodge_move()
		_check("genre %s" % e[0], dm != null and dm.kind() == e[0], str(dm.kind() if dm != null else "null"))
		_check("libellé propre", dm.label() != "" and dm.label() != "Roulade", dm.label())
		var dir := Vector2.RIGHT
		_check("esquive lancée", _player.dodge(dir))
		var r := _play()
		var want_dist: float = e[1] * (-1.0 if cid == &"rainette" or cid == &"vigie" else 1.0) # recul sans entrée
		_check("distance %.2f u" % want_dist, _near(r["dist_u"], want_dist, 0.08), "%.3f u" % r["dist_u"])
		_check("invulnérabilité %.3f s" % e[2], _near(r["invuln_s"], e[2], DT * 1.5), "%.3f s" % r["invuln_s"])
		var cd: Dictionary = _player.get_dodge_cooldown()
		if int(e[4]) > 1:
			_check("charges %d max" % int(e[4]), int(cd["max_charges"]) == int(e[4]) and int(cd["charges"]) == int(e[4]) - 1, str(cd))
			_check("recharge d'une charge %.1f s" % e[3], _near(float(cd["remaining"]), e[3] - r["elapsed_s"], DT * 2.0), str(cd["remaining"]))
		else:
			_check("recharge %.1f s" % e[3], _near(float(cd["total"]), e[3]) and _near(float(cd["remaining"]), e[3] - r["elapsed_s"], DT * 2.0), str(cd))
			_check("refusée en recharge", not _player.dodge(dir))
		_check("plus en esquive", not _player.is_dodging())

	print("Vigie : 3 petits dashs enchaînables, Tension")
	await _spawn(&"vigie")
	var vk: Node = _player.kit
	vk.set_tension(0.0)
	var x0 := _player.global_position.x
	for i in 3:
		_check("dash %d lancé" % (i + 1), _player.dodge(Vector2.RIGHT))
		_play()
	_check("3 u en tout (recul)", _near((_player.global_position.x - x0) / U, -3.0, 0.1), str((_player.global_position.x - x0) / U))
	_check("4e refusé (0 charge)", not _player.dodge(Vector2.RIGHT))
	_check("+0,24 de Tension (plus la Tension gagnée en marchant)", vk.tension >= 3.0 * VigieKit.DODGE_TENSION_GAIN - 0.001 and vk.tension < 3.0 * VigieKit.DODGE_TENSION_GAIN + 0.2, str(vk.tension))
	_player.tick(1.05)
	_check("1 charge après 1 s", int(_player.get_dodge_cooldown()["charges"]) == 1, str(_player.get_dodge_cooldown()))
	_player.tick(1.0)
	_check("2 charges après 2 s", int(_player.get_dodge_cooldown()["charges"]) == 2)
	var chained: bool = _player.dodge(Vector2.RIGHT)
	_player.dodge_step(DT)
	_check("enchaînement : relance pendant un dash", chained and _player.is_dodging() and _player.dodge(Vector2.LEFT))
	_play()
	_player.reset_dodge()
	_check("reset : charges pleines", int(_player.get_dodge_cooldown()["charges"]) == 3)

	print("Ardent : Éclat, jamais à travers un mur")
	await _spawn(&"ardent")
	_wall(2.0) # mur de 1,75 à 2,25 u
	await get_tree().physics_frame
	_player.global_position = Vector2.ZERO
	_check("éclat lancé", _player.dodge(Vector2.RIGHT))
	_play()
	_check("arrêté devant le mur (0,9 u < x < 1,75 u)", _player.global_position.x < 1.75 * U and _player.global_position.x > 0.9 * U, "%.2f u" % (_player.global_position.x / U))
	_check("recharge consommée quand même", float(_player.get_dodge_cooldown()["remaining"]) > 2.0)
	_check("opacité rendue", _near(_player.get_node("Visual").modulate.a, 1.0))
	_clear_junk()
	await get_tree().physics_frame
	_player.reset_dodge()
	_player.global_position = Vector2.ZERO
	_check("relance après reset", _player.dodge(Vector2.LEFT))
	var rl := _play()
	_check("3 u vers la gauche", _near(rl["dist_u"], -3.0, 0.05), str(rl["dist_u"]))
	_check("dispersion : immobile, déplacement permis en reformation", not _player.dodge_move().allows_move())

	print("Roulade : mur (Rictus, levée)")
	await _spawn(&"rictus")
	_wall(2.0)
	await get_tree().physics_frame
	_player.global_position = Vector2.ZERO
	_player.dodge(Vector2.RIGHT)
	_play()
	_check("levée arrêtée devant le mur", _player.global_position.x < 1.75 * U and _player.global_position.x > 0.9 * U, "%.2f u" % (_player.global_position.x / U))
	_check("masque de collision rendu", _player.collision_mask == 1)
	_clear_junk()

	print("Averse : Glissade au maintien, contact ignoré, eau")
	await _spawn(&"averse")
	var ak: Node = _player.kit
	ak.water = 60.0
	_check("SlideDodge, maintien", _player.dodge_move() is SlideDodge and _player.dodge_move().is_hold())
	_check("lancée", _player.dodge(Vector2.RIGHT))
	var src := Node2D.new()
	src.set(&"radius_px", 20.0)
	get_tree().root.add_child(src)
	src.global_position = _player.global_position + Vector2(30, 0)
	_junk.append(src)
	var hp0: float = _player.hp
	for i in 24: # 0,2 s : l'invulnérabilité de départ est passée
		_player.dodge_step(DT)
		_player.tick(DT)
	_check("plus invulnérable", not _player.is_invulnerable())
	src.global_position = _player.global_position + Vector2(30, 0)
	_player.take_damage(10.0, src)
	_check("coup de contact ignoré en glisse", _near(_player.hp, hp0), str(_player.hp))
	var far := Node2D.new()
	get_tree().root.add_child(far)
	far.global_position = _player.global_position + Vector2(400, 0)
	_junk.append(far)
	_player.take_damage(10.0, far)
	_check("coup à distance (projectile) encaissé", _player.hp < hp0, str(_player.hp))
	_check("eau consommée", ak.water < 60.0 - AverseKit.SLIDE_START_COST, str(ak.water))
	_player.dodge_release()
	_player.dodge_step(DT)
	_check("relâcher = fin", not _player.is_dodging())
	_player.tick(1.0)
	_player.global_position = Vector2.ZERO
	_wall(1.0)
	await get_tree().physics_frame
	_player.global_position = Vector2.ZERO
	_player.dodge(Vector2.RIGHT)
	for i in 60:
		if not _player.is_dodging():
			break
		_player.dodge_step(DT)
		_player.tick(DT)
	_check("mur de face : la glisse bute et s'arrête", not _player.is_dodging() and _player.global_position.x < 0.8 * U, "%.2f u" % (_player.global_position.x / U))
	_clear_junk()

	print("Mode test : recharge 0")
	await _spawn(&"avare")
	TestMode.set_flag(&"cdr_full", true)
	_player.dodge(Vector2.RIGHT)
	_play()
	_check("roulade relançable tout de suite", _player.dodge(Vector2.RIGHT))
	_play()
	TestMode.set_flag(&"cdr_full", false)
	await _spawn(&"vigie")
	TestMode.set_flag(&"cdr_full", true)
	for i in 3:
		_player.dodge(Vector2.RIGHT)
		_play()
	_player.tick(DT)
	_check("charges pleines en mode test", int(_player.get_dodge_cooldown()["charges"]) == 3 and _player.dodge(Vector2.RIGHT))
	_play()
	TestMode.set_flag(&"cdr_full", false)

	print("Changement de personnage : esquive refaite")
	await _spawn(&"ardent")
	_check("Ardent : Éclat", _player.dodge_move() is BlinkDodge)
	_player.switch_character(&"averse")
	_check("-> Averse : Glissade", _player.dodge_move() is SlideDodge)
	_player.switch_character(&"vigie")
	_check("-> Vigie : 3 charges", int(_player.get_dodge_cooldown()["max_charges"]) == 3)

	_player.queue_free()
	_clear_junk()
	await get_tree().process_frame
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
