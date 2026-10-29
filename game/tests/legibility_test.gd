extends Node
## Lisibilité des attaques (passe du 28/10/2026) : écrasement à l'armement, étirement + éclat à l'impact, retour à
## l'échelle de repos, plafond de monstres animés, flashs réduits, interruption sans impact, plafond de télégraphes
## au sol des brutes (jamais d'attaque armée sans télégraphe).
## godot --headless --path game res://tests/legibility_test.tscn

const U := 64.0
const DT := 1.0 / 60.0

var _fails := 0
var _director: Director
var _player: FakePlayer


class FakePlayer extends Node2D:
	var hits := 0

	func take_damage(_amount: float, _source: Node = null) -> void:
		hits += 1


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _frames(n: int) -> void: ## ~n images à 60 Hz, en temps réel (le rendu headless tourne plus vite que 60 Hz)
	await get_tree().create_timer(float(n) / 60.0).timeout


func _run() -> void:
	RunState.level = 1
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	await get_tree().process_frame
	_director.process_mode = Node.PROCESS_MODE_DISABLED
	_player = FakePlayer.new()
	get_tree().root.add_child(_player)
	Quality.flashes_level = 2

	await _test_squash_and_impact()
	await _test_interrupt()
	await _test_cap()
	await _test_reduced_flashes()
	await _test_ground_cap()

	_player.queue_free()
	_director.queue_free()
	await get_tree().process_frame
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _swarm(pos := Vector2(900, 900)) -> Enemy:
	var e := _director.spawn_enemy(1, pos, false, [] as Array[StringName], 0)
	e.visual.process_mode = Node.PROCESS_MODE_ALWAYS # le Director est désactivé dans ce test
	return e


func _test_squash_and_impact() -> void:
	print("Armement : écrasement ; impact : étirement puis retour")
	var e := _swarm()
	var v: EnemyVisual = e.visual
	v.set_facing(PI * 0.5) # face (s) : axe vertical
	var base := v._base_scale
	v.set_charge(1)
	_check("process allumé, monstre compté", v.is_processing() and v._fx_on)
	await _frames(20)
	var sc := v._sprite.scale
	_check("face : hauteur écrasée de ~%d %%" % int(Balance.ARM_SQUASH * 100), sc.y < base.y * (1.0 - Balance.ARM_SQUASH * 0.8) and sc.x > base.x, "%s vs %s" % [sc, base])
	v.set_charge(0)
	await _frames(2)
	_check("impact : étirement vertical > repos", v._sprite.scale.y > base.y * 1.03, "%s" % v._sprite.scale)
	_check("impact : éclat chaud", v._sprite.modulate.a > 1.0 and v._sprite.modulate.r < 1.5, str(v._sprite.modulate))
	await get_tree().create_timer(Balance.IMPACT_S + 0.15).timeout
	_check("retour à l'échelle de repos", v._sprite.scale.is_equal_approx(base), "%s vs %s" % [v._sprite.scale, base])
	_check("process éteint, compteur rendu", not v.is_processing() and not v._fx_on)
	_check("teinte rendue à blanc", v._sprite.modulate == Color.WHITE)
	v.set_facing(0.0) # profil (e) : axe horizontal
	v.set_charge(1)
	await _frames(20)
	_check("profil : largeur écrasée", v._sprite.scale.x < base.x * (1.0 - Balance.ARM_SQUASH * 0.8) and v._sprite.scale.y > base.y, str(v._sprite.scale))
	v.clear_charge()
	_director.release_enemy(e)


func _test_interrupt() -> void:
	print("Interruption : pas d'impact, échelle et teinte rendues")
	var e := _swarm()
	var v: EnemyVisual = e.visual
	var base := v._base_scale
	v.set_charge(2)
	await _frames(10)
	v.clear_charge()
	_check("échelle de repos", v._sprite.scale.is_equal_approx(base))
	_check("pas d'impact après interruption", v._fx_state == 0 and not v.is_processing() and v._sprite.modulate == Color.WHITE)
	e._cancel_windup()
	_director.release_enemy(e)
	var live0 := EnemyVisual._fx_live
	_check("compteur d'animation revenu à zéro", live0 == 0, str(live0))


func _test_cap() -> void:
	print("Plafond de monstres animés")
	var list: Array[Enemy] = []
	for i in Balance.TELEGRAPH_FX_MAX + 12:
		var e := _swarm(Vector2(i * 70.0, 2000.0))
		e.visual.set_charge(1)
		list.append(e)
	_check("animés <= %d (%d)" % [Balance.TELEGRAPH_FX_MAX, EnemyVisual._fx_live], EnemyVisual._fx_live == Balance.TELEGRAPH_FX_MAX)
	_check("les autres gardent la teinte statique", list[-1].visual._charge_mod == EnemyVisual.CHARGE_MODS[1] and not list[-1].visual.is_processing())
	for e in list:
		_director.release_enemy(e)
	_check("désactivation rend tous les compteurs", EnemyVisual._fx_live == 0, str(EnemyVisual._fx_live))


func _test_reduced_flashes() -> void:
	print("Flashs réduits : pas de clignotement ni d'éclat, écrasement gardé")
	Quality.flashes_level = 0
	var e := _swarm()
	var v: EnemyVisual = e.visual
	var base := v._base_scale
	v.set_facing(PI * 0.5)
	v.set_charge(1, true)
	await _frames(20)
	_check("teinte d'armement fixe", v._sprite.modulate == EnemyVisual.CHARGE_MODS[1], str(v._sprite.modulate))
	_check("écrasement gardé", v._sprite.scale.y < base.y)
	v.set_charge(0)
	await _frames(2)
	_check("pas d'éclat d'impact", v._sprite.modulate == Color.WHITE, str(v._sprite.modulate))
	_check("étirement gardé", v._sprite.scale.y > base.y)
	v.clear_charge()
	_director.release_enemy(e)
	Quality.flashes_level = 2
	e = _swarm()
	v = e.visual
	v.set_charge(1, true)
	var seen := {}
	for i in 30:
		await get_tree().process_frame
		seen[snappedf(v._sprite.modulate.a, 0.05)] = true
	_check("flashs complets : la teinte clignote (%d valeurs d'alpha)" % seen.size(), seen.size() >= 3)
	v.clear_charge()
	_director.release_enemy(e)


func _test_ground_cap() -> void:
	print("Plafond de télégraphes au sol (brutes)")
	var pp := Vector2.ZERO
	var brutes: Array[Enemy] = []
	for i in 24:
		var e := _director.spawn_enemy(3, Vector2(60.0 + i * 3.0, 40.0 + i * 2.0), false, [] as Array[StringName], 0)
		e._attack_cd = 0.0
		e._spell_cd = 0.0
		brutes.append(e)
	var peak := 0
	var naked := 0
	var light_drawn := 0
	for f in 90:
		await get_tree().physics_frame
		for e in brutes:
			if e.active:
				e.tick(DT, _player, pp, Vector2.ZERO)
		peak = maxi(peak, Enemy.ground_telegraphs())
		for e in brutes:
			if e._windup == Enemy.Windup.SHOCK: # coup lourd : zone au sol ; le cône léger n'en a plus (anticipation du corps)
				if not e.telegraph.is_showing():
					naked += 1
			elif e._windup == Enemy.Windup.CONE and e.telegraph.is_showing():
				light_drawn += 1
	_check("pic de télégraphes au sol %d <= %d" % [peak, Balance.TELEGRAPH_GROUND_MAX], peak <= Balance.TELEGRAPH_GROUND_MAX and peak > 0)
	_check("aucune attaque armée sans télégraphe", naked == 0, str(naked))
	_check("cône léger : pas de zone au sol (réglage normal)", light_drawn == 0, str(light_drawn))
	for e in brutes:
		_director.release_enemy(e)
	_check("compteur revenu à zéro", Enemy.ground_telegraphs() == 0, str(Enemy.ground_telegraphs()))
