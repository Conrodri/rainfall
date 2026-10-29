extends Node
## Combos et rythme des sorts (docs/Design_Combos.md, docs/Design_Feel_Sorts.md, 29/10/2026) :
## - infrastructure commune : coup de combo (teinte du chiffre), hook combo_ready exposé au HUD, table de cancel, buffer,
##   sort 1 différé pendant la récupération, poids du lancer (gel du corps, gel global, coupés par « mouvement réduit »)
## - Arpenteuse (AR-2 Tendeur -> Halage, AR-3 Trait -> Halage) : bonus seulement dans la fenêtre, ordre inverse sans bonus.
## Les combos d'Ardent et d'Averse sont couverts par tests/ardent_combos_test et tests/averse_combos_test.
## godot --headless --path game res://tests/combo_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var tints: Array = []
	var pushes: Array = []
	var held := false

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)
		tints.append(DamageNumbers.combo_tint)

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func push(v: Vector2) -> void:
		pushes.append(v)

	func is_slowed() -> bool:
		return false

	func is_imprisoned() -> bool:
		return held

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


const U := 64.0
const BASE := 12.0
const DT := 1.0 / 60.0

var _fails := 0
var _player: CharacterBody2D
var _kit: ArpenteuseKit
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


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _wait(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_player.tick(DT)


func _to_impact() -> void:
	var t := 0.0
	while _kit.has_pending() and t < 1.5:
		_player.tick(DT)
		t += DT


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.spells._input_buf.clear()
	_player.reset_dodge()
	_kit._last_head = Vector2.ZERO
	_kit._tick_t = 0.0
	_kit._idle_t = 0.0
	_kit.taut_left = 0.0
	_kit._taut_seg = PackedVector2Array()
	RunState.counters.clear()
	_player.tick(DT)


## Piquet planté à 5 u (la ligne du piquet porte les monstres), traîne rembobinée.
func _plant_and_idle() -> void:
	_reset()
	_player.spells.aim_override = Vector2(5 * U, 0)
	_player.spells.cast(3)
	_to_impact()
	_wait(2.5)
	_player.spells.aim_override = null


func _run() -> void:
	RunState.level = 1
	RunState.character = &"arpenteuse"
	RunState.loadout = {}
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as ArpenteuseKit

	print("Constantes")
	_check("INPUT_BUFFER_S = 0,133", _near(Balance.INPUT_BUFFER_S, 0.133, 0.0001))
	_check("PEG_IMMUNITY_S = 0,7", _near(ArpenteuseKit.PEG_IMMUNITY_S, 0.7, 0.0001))

	print("Coup de combo : chiffre en accent, teinte remise à zéro")
	_reset()
	var t1 := _fake(Vector2(2 * U, 0))
	var sp3: SpellData = _player.spells._spell_for(3)
	_player.spells.deal_damage(t1, sp3, {"combo": true})
	_player.spells.deal_damage(t1, sp3, {})
	_check("coup de combo : teinte d'accent posée pendant take_damage", t1.tints[0].a > 0.0 and t1.tints[0].is_equal_approx(_player.character.accent_color), str(t1.tints))
	_check("coup normal : aucune teinte", t1.tints[1].a == 0.0, str(t1.tints))
	_check("teinte remise à zéro après le coup", DamageNumbers.combo_tint.a == 0.0)

	print("Cancel : table du doc §3.1")
	_reset()
	_check("repos : tout est permis", _player.can_cancel_into(&"spell") and _player.can_cancel_into(&"auto") and _player.can_cancel_into(&"dodge"))
	_player.spells.aim_override = Vector2(3 * U, 0)
	_player.spells.cast(3) # sort 2-3 : Piquet
	_check("avant l'impact : aucun sort ne coupe", not _player.can_cancel_into(&"spell") and not _player.can_cancel_into(&"ult") and not _player.can_cancel_into(&"dodge"))
	_check("sort 1 : jamais pendant un sort 2-4 (différé)", not _player.can_cancel_into(&"auto"))
	_player._flush_action_impact()
	_check("impact + 0 f : rien ne coupe", not _player.can_cancel_into(&"spell") and not _player.can_cancel_into(&"dodge"))
	_player._since_impact = 1.0 / 60.0 * 2.0
	_check("impact + 2 f : l'esquive et l'ultime coupent, pas un sort", _player.can_cancel_into(&"dodge") and _player.can_cancel_into(&"ult") and not _player.can_cancel_into(&"spell"))
	_player._since_impact = 1.0 / 60.0 * 4.0
	_check("impact + 4 f : un sort 2-3 coupe", _player.can_cancel_into(&"spell"))
	_check("sort 1 : toujours différé pendant la récupération d'un sort 2-4", not _player.can_cancel_into(&"auto"))
	# ultime en cours
	_player._action_kind = &"ult"
	_player._since_impact = 1.0 / 60.0 * 5.0
	_check("ultime impact + 5 f : l'esquive ne coupe pas encore", not _player.can_cancel_into(&"dodge"))
	_player._since_impact = 1.0 / 60.0 * 6.0
	_check("ultime impact + 6 f : l'esquive coupe", _player.can_cancel_into(&"dodge"))
	_check("ultime impact + 6 f : un sort ne coupe pas encore", not _player.can_cancel_into(&"spell"))
	_player._since_impact = 1.0 / 60.0 * 12.0
	_check("ultime impact + 12 f : un sort coupe", _player.can_cancel_into(&"spell"))
	# sort 1 en cours : l'esquive coupe à toute frame, un sort après impact + 1 f
	_player._action_kind = &"auto"
	_player._since_impact = -1.0
	_check("sort 1 avant impact : l'esquive coupe, pas un sort", _player.can_cancel_into(&"dodge") and not _player.can_cancel_into(&"spell"))
	_player._since_impact = 1.0 / 60.0
	_check("sort 1 impact + 1 f : un sort coupe", _player.can_cancel_into(&"spell"))

	print("Buffer : un appui pendant la récupération part à la première frame permise, une fois")
	_reset()
	_player.spells.aim_override = Vector2(3 * U, 0)
	_player.spells.cast(3)
	_player._flush_action_impact()
	_player._since_impact = 0.0
	_player._action_left = 1.0
	_player._action_total = 1.0
	_player.spells._input_buf[2] = Balance.INPUT_BUFFER_S # appui déjà fait pendant la récupération
	_check("Halage (2) en attente, recharge prête", _player.spells._remaining[2] <= 0.0)
	var casts: Array = []
	_player.spells.spell_cast.connect(func(s: SpellData) -> void: casts.append(s.slot))
	_player.spells.tick(DT)
	_check("pas de lancer avant impact + 4 f", casts.is_empty(), str(casts))
	_player._since_impact = 4.0 / 60.0
	_player.spells.tick(DT)
	_check("lancer à la première frame permise", casts == [2], str(casts))
	_player.spells.tick(DT)
	_check("appui consommé : un seul lancer", casts == [2], str(casts))
	_reset()
	_player.spells._input_buf[3] = Balance.INPUT_BUFFER_S
	_player._action = &"cast"
	_player._action_kind = &"spell"
	_player._action_left = 1.0
	_player._since_impact = 0.0
	casts.clear()
	_player.spells._remaining[3] = 0.0
	for i in 12: # > 0,133 s sans fenêtre : l'appui expire
		_player.spells.tick(DT)
	_check("buffer expiré après 0,133 s", casts.is_empty() and not _player.spells._input_buf.has(3), str(casts))

	print("Auto différé : le sort 1 attend la fin de la récupération, sans être perdu")
	_reset()
	_player._action = &"cast"
	_player._action_kind = &"spell"
	_player._action_left = 0.3
	_player._since_impact = 0.1
	_check("auto bloquée pendant la récupération d'un sort 2-4", not _player.can_cancel_into(&"auto"))
	_player._action_left = 0.0
	_check("auto permise à la fin", _player.can_cancel_into(&"auto"))

	print("combo_ready exposé au HUD")
	_plant_and_idle()
	var cd: Array = _player.get_spell_cooldowns()
	_check("get_spell_cooldowns porte « combo »", cd.size() > 0 and (cd[0] as Dictionary).has("combo"))
	_kit.taut_left = ArpenteuseKit.TAUT_S
	_kit._probe_combo_t = -10.0
	_player.spells._poll_combo_ready()
	_check("Trait tendu : le bouton du Halage (2) est prêt", _player.spells.combo_ready(2))
	_check("sort 3 : pas de fenêtre", not _player.spells.combo_ready(3))
	_kit.taut_left = 0.0
	_kit._probe_combo_t = -10.0
	_player.spells._poll_combo_ready()
	_check("fenêtre fermée : le bouton cesse de pulser", not _player.spells.combo_ready(2))

	print("AR-2 : Tendeur -> Halage (+0,5 sur les emprisonnés, attraction nulle)")
	_plant_and_idle()
	var held := _fake(Vector2(3 * U, 0.6 * U))
	var free := _fake(Vector2(4 * U, -0.5 * U))
	held.held = true
	_kit._peg_hits[held.get_instance_id()] = 1.0e9
	_kit._peg_hits[free.get_instance_id()] = 1.0e9
	_check("Halage lancé", _player.spells.cast(2))
	_to_impact()
	_check("emprisonné : 3,5 + 0,5 = 4,0", _near(held.total(), 4.0 * BASE), str(held.taken))
	_check("emprisonné : teinte de combo", held.tints.size() > 0 and held.tints[0].a > 0.0)
	_check("emprisonné : aucune attraction", held.pushes.is_empty(), str(held.pushes))
	_check("libre : 3,5 seulement", _near(free.total(), 3.5 * BASE), str(free.taken))
	_check("libre : attiré vers la ligne", free.pushes.size() == 1)
	_check("libre : pas de teinte", free.tints.size() > 0 and free.tints[0].a == 0.0)

	print("AR-3 : Trait -> Halage (+0,5 sur le segment tendu seulement)")
	_plant_and_idle()
	var on_seg := _fake(Vector2(3 * U, 0.6 * U))
	var off_seg := _fake(Vector2(4.8 * U, 0.5 * U))
	_kit._peg_hits[on_seg.get_instance_id()] = 1.0e9
	_kit._peg_hits[off_seg.get_instance_id()] = 1.0e9
	_kit.on_dodge_end(Vector2(2.5 * U, 0), Vector2(3.5 * U, 0))
	_check("Halage lancé pendant le Trait tendu", _player.spells.cast(2))
	_to_impact()
	_check("sur le segment tendu : 4,0", _near(on_seg.total(), 4.0 * BASE), str(on_seg.taken))
	_check("hors du segment : 3,5", _near(off_seg.total(), 3.5 * BASE), str(off_seg.taken))
	_plant_and_idle()
	var late := _fake(Vector2(3 * U, 0.6 * U))
	_kit._peg_hits[late.get_instance_id()] = 1.0e9
	_kit.on_dodge_end(Vector2(2.5 * U, 0), Vector2(3.5 * U, 0))
	_wait(ArpenteuseKit.TAUT_S + 0.1)
	_kit._peg_hits[late.get_instance_id()] = 1.0e9
	_player.spells._remaining[2] = 0.0
	_player.spells.cast(2)
	_to_impact()
	_check("fenêtre fermée (Trait expiré) : 3,5, aucun bonus", _near(late.total(), 3.5 * BASE), str(late.taken))
	_plant_and_idle()
	var inv := _fake(Vector2(3 * U, 0.6 * U))
	_kit._peg_hits[inv.get_instance_id()] = 1.0e9
	_player.spells.cast(2)
	_to_impact()
	inv.taken.clear()
	_kit.on_dodge_end(Vector2(2.5 * U, 0), Vector2(3.5 * U, 0)) # ordre inverse : Halage puis Trait, pas de rétro-bonus
	_check("ordre inverse (Halage puis Trait) : le Halage déjà tiré n'a rien eu de plus", inv.taken.is_empty())

	print("Poids du lancer : gel du corps, gel global, mouvement réduit")
	_reset()
	var frames_before: float = _player.freeze_left()
	_player.apply_cast_feel(false, 0.5, 1, false, false)
	_check("sort moyen (f 0,5) : gel du corps 2 f", _near(_player.freeze_left(), 2.0 / 60.0, 0.0001), str(_player.freeze_left()))
	_player._freeze_left = 0.0
	_player.apply_cast_feel(true, 0.95, 12, false, false)
	_check("ultime : gel du corps 4 f", _near(_player.freeze_left(), 4.0 / 60.0, 0.0001), str(_player.freeze_left()))
	_check("ultime : gel global (time_scale réduit)", Engine.time_scale < 1.0, str(Engine.time_scale))
	await get_tree().create_timer(0.3, true, false, true).timeout
	_check("gel global levé", _near(Engine.time_scale, 1.0, 0.001), str(Engine.time_scale))
	_player._ult_freeze_at_ms = -100000
	_player._freeze_left = 0.0
	GameSettings.set_reduce_motion(true)
	_player.apply_cast_feel(true, 0.95, 12, false, false)
	_check("mouvement réduit : ni gel du corps ni gel global", _player.freeze_left() == 0.0 and _near(Engine.time_scale, 1.0, 0.001))
	GameSettings.set_reduce_motion(false)
	_check("sort léger (f 0,2) : aucun gel", (func() -> bool:
		_player._freeze_left = 0.0
		_player.apply_cast_feel(false, 0.2, 1, false, false)
		return _player.freeze_left() == 0.0).call())
	_check("hitstop joueur par force", Balance.player_hitstop_frames(0.5, false) == 2 and Balance.player_hitstop_frames(0.7, false) == 3 and Balance.player_hitstop_frames(0.9, false) == 4 and Balance.player_hitstop_frames(0.5, true) == 3)

	for j in _junk:
		if is_instance_valid(j):
			j.queue_free()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
