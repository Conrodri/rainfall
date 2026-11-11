extends Node
## Non-régression R1 (audit roster 11/11) : un tir rejoué à coef réduit (écho de Couronne, tout multiplicateur appliqué
## à `s.coef` en amont) doit garder ce coef réduit. Goutte-lame et Bruine (Averse) puis ligne de la Langue (Rainette)
## ne réécrivent plus le coef avec une constante.
## godot --headless --path game res://tests/coef_echo_test.tscn

const ECHO := 0.5

var _fails := 0
var _player: CharacterBody2D
var _junk: Array = []


class FakeEnemy extends Node2D:
	var is_boss := false
	var is_elite := false

	func take_damage(_a: float, _c: bool = false, _e: StringName = &"") -> void:
		pass

	func apply_status(_s: StringName, _d: Dictionary) -> void:
		pass


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _near(a: float, b: float, tol: float = 0.0001) -> bool:
	return absf(a - b) <= tol


func _spawn(character: StringName) -> void:
	RunState.level = 1
	RunState.character = character
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)


func _enemy_near() -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = Vector2(200, 0)
	_junk.append(e)
	return e


## Coefs des projectiles actifs du caster après vidage des tirs en attente.
func _shot_coefs(kit: AverseKit) -> Array:
	kit.flush_pending()
	var out: Array = []
	for p in _player.spells._pool:
		if p.active and p.spell != null:
			out.append(p.spell.coef)
	return out


func _clear_shots() -> void:
	for p in _player.spells._pool:
		p.active = false


func _run() -> void:
	await _spawn(&"averse")
	var kit: AverseKit = _player.kit
	_check("kit Averse", kit != null)
	_enemy_near()
	kit.water = 100.0
	var base_goutte: SpellData = _player.character.spells[0]

	print("Goutte-lame")
	var nominal := kit._spell(&"goutte_lame", "Goutte-lame", 1, AverseKit.GOUTTE_COEF_MIN, AverseKit.GOUTTE_CD)
	_check("cast nominal", kit.cast_spell(nominal, null))
	var full: Array = _shot_coefs(kit)
	_clear_shots()
	var expect_full := AverseKit.GOUTTE_COEF_MIN + AverseKit.GOUTTE_COEF_WATER * kit.water_ratio()
	_check("tir nominal = formule d'eau", full.size() == 1 and _near(full[0], expect_full), str(full))
	var echo := base_goutte.duplicate() as SpellData
	echo.coef = base_goutte.coef * ECHO
	_check("cast écho", kit.cast_spell(echo, null))
	var half: Array = _shot_coefs(kit)
	_clear_shots()
	_check("écho = %s x nominal" % ECHO, half.size() == 1 and full.size() == 1 and _near(half[0], full[0] * ECHO), "%s vs %s" % [half, full])

	print("Bruine")
	var bru := kit._spell(AverseKit.V_BRUINE, "Bruine", 1, AverseKit.BRUINE_COEF_MIN, AverseKit.GOUTTE_CD)
	bru.count = 3
	bru.spread_deg = 30.0
	_check("cast Bruine nominale", kit.cast_spell(bru, null))
	var bfull: Array = _shot_coefs(kit)
	_clear_shots()
	var bru_echo := bru.duplicate() as SpellData
	bru_echo.coef = bru.coef * ECHO
	_check("cast Bruine écho", kit.cast_spell(bru_echo, null))
	var bhalf: Array = _shot_coefs(kit)
	_clear_shots()
	_check("Bruine écho = %s x nominal" % ECHO, not bfull.is_empty() and bhalf.size() == bfull.size() and _near(bhalf[0], bfull[0] * ECHO), "%s vs %s" % [bhalf, bfull])

	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_player.queue_free()
	await get_tree().process_frame

	await _spawn(&"rainette")
	var rk: RainetteKit = _player.kit
	_check("kit Rainette", rk != null)
	print("Langue (ligne)")
	var tongue := _player.character.spells[0].duplicate() as SpellData
	var line := rk._tongue_line_spell(tongue)
	_check("ligne nominale = TONGUE_LINE_COEF", _near(line.coef, RainetteKit.TONGUE_LINE_COEF, 0.001), str(line.coef))
	tongue.coef *= ECHO
	var line_half := rk._tongue_line_spell(tongue)
	_check("ligne écho = %s x nominal (même objet sort)" % ECHO, _near(line_half.coef, RainetteKit.TONGUE_LINE_COEF * ECHO, 0.001), str(line_half.coef))

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
