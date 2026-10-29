extends Node
## Test headless d'Averse (docs/Design_Personnages.md §2.1) : stats, eau (pluie, kills, flaque), vitesse selon
## l'eau, 4 sorts (Behavior.KIT, effet à la frame d'impact), trempe, coûts et blocages, Crue proportionnelle,
## glissade (esquive au maintien qui consomme l'eau), rendu (anims, émission, lumières), partie réelle.
## godot --headless --path game res://tests/averse_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func is_slowed() -> bool:
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t

	func soaked() -> bool:
		for s in statuses:
			if s[0] == &"slow" and is_equal_approx(float(s[1]["pct"]), 0.3) and is_equal_approx(float(s[1]["duration"]), 4.0):
				return true
		return false


class FakeBody extends StaticBody2D:
	var taken: Array = []

	func _init(radius := 10.0) -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new()
		sh.radius = radius
		cs.shape = sh
		add_child(cs)

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass


const U := 64.0
const BASE := 12.0

var _fails := 0
var _player: CharacterBody2D
var _kit: Node
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


func _body(pos: Vector2, radius := 10.0) -> FakeBody:
	var b := FakeBody.new(radius)
	b.add_to_group("enemies")
	get_tree().root.add_child(b)
	b.global_position = pos
	_junk.append(b)
	return b


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Avance le joueur de `t` s (pas de 0,01 s), sort 1 suspendu sauf `auto`.
func _advance(t: float, auto := false) -> void:
	var n := roundi(t / 0.01)
	for i in n:
		if not auto:
			_player.spells._remaining[1] = 99.0
		_player.tick(0.01)
		for z in _kit.puddles: # zones pilotées par le test (pas de _process en boucle manuelle)
			if is_instance_valid(z):
				z.set_process(false)
				z.step(0.01)
	if not auto:
		_player.spells._remaining[1] = 0.0


func _reset(w: float = 50.0) -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.water = w
	_kit.dry_left = 0.0
	_kit._auto_budget = AverseKit.AUTO_BUDGET_START
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.reset_dodge()
	_player._invuln = 0.0


func _run() -> void:
	RunState.level = 1
	RunState.character = &"averse"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit

	print("Personnage et rendu")
	_check("kit Averse", _kit is AverseKit)
	_check("4 sorts / ids", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["goutte_lame", "vague", "flaque_miroir", "crue"])
	_check("PV L1 = 90", _near(_player.max_hp, 90.0), str(_player.max_hp))
	_check("armure 0", _near(_player.armor(), 0.0))
	_check("régén 1", _near(_player.regen_per_s(), 1.0))
	_reset(0.0)
	_check("vitesse 4,4 u/s à vide", _near(_player.move_speed(), 4.4 * U, 0.1), str(_player.move_speed()))
	_kit.water = 100.0
	_check("vitesse 3,4 u/s pleine", _near(_player.move_speed(), 3.4 * U, 0.1), str(_player.move_speed()))
	_kit.water = 50.0
	_check("vitesse 3,9 u/s à moitié", _near(_player.move_speed(), 3.9 * U, 0.1), str(_player.move_speed()))
	var vis := _player.get_node("Visual") as AnimatedSprite2D
	_check("sprites AV1 chargés", vis.sprite_frames != null and vis.sprite_frames.has_animation(&"wave_s") and vis.sprite_frames.has_animation(&"crue_ne"))
	var lights_ok := true
	for sp in AverseKit.character().spells:
		lights_ok = lights_ok and String(sp.light_preset).begins_with("averse_") and LightRig.has_preset(sp.light_preset)
		lights_ok = lights_ok and sp.behavior == SpellData.Behavior.KIT and sp.element == &"frost"
	_check("lumières averse_* (jamais la braise), Behavior.KIT", lights_ok)
	var tinted := 0
	for h in LightRig._requests:
		if h.get_target() == _player and h.color_override.a > 0.0:
			tinted += 1
	_check("lumières du joueur en pluie froide (plus de braise)", tinted == 2, str(tinted))
	_kit.add_water(-100.0)
	var e0: int = _kit._emission_step
	_kit.add_water(100.0)
	_check("niveau d'eau = énergie du masque _e", e0 == 0 and _kit._emission_step == AverseKit.EMISSION_STEPS, "%d %d" % [e0, _kit._emission_step])
	var assets_ok := true
	for path in [AverseKit.GOUTTE_FRAMES, AverseKit.WAVE_FRAMES, AverseKit.PUDDLE_FRAMES, AverseKit.CRUE_FRAMES]:
		assets_ok = assets_ok and ResourceLoader.exists(path)
	_check("VFX AV2 présents", assets_ok)

	print("Eau")
	_reset(0.0)
	_advance(1.0)
	_check("pluie : +2,5/s (sans ambiance : pluie moyenne)", _near(_kit.water, 2.5, 0.05), str(_kit.water))
	Events.enemy_killed.emit(null, Vector2(9999, 0), 1, false)
	_check("+0,9 par monstre tué", _near(_kit.water, 2.5 + AverseKit.KILL_GAIN, 0.05), str(_kit.water))
	_advance(0.5)
	_check("taux d'eau exposé (resource_regen_per_s, KitResource regen)", _kit.resource_regen_per_s() > 1.0 and float(KitResource.of(_player).get("regen", -1.0)) == _kit.resource_regen_per_s(), str(_kit.resource_regen_per_s()))
	_check("« +N » flottant pour un gain hors pluie", get_tree().get_nodes_in_group(&"averse_water_text").size() >= 1)
	_kit.add_water(500.0)
	_check("plafond 100", _near(_kit.water, 100.0))
	_kit._rain_mult = 0.0
	_reset(10.0)
	_kit._rain_mult = 0.0
	_kit._rain_t = 99.0
	_advance(1.0)
	_check("sans pluie (Cryptes) : pas de gain passif", _near(_kit.water, 10.0, 0.01), str(_kit.water))
	_kit._rain_t = 0.0

	print("Sort 1 : Goutte-lame")
	_reset(50.0)
	_check("sans ennemi : rien, pas de recharge", not _player.spells.cast(1) and _player.get_spell_cooldowns()[0].remaining == 0.0)
	var tgt := _body(Vector2(192, 0))
	_check("goutte lancée", _player.spells.cast(1))
	_check("anim d'action attack", String(_player.action_anim()).begins_with("attack"), str(_player.action_anim()))
	_check("tir en attente de la frame d'impact", _kit.has_pending() and _player.spells.active_projectile_count() == 0)
	var t := 0.0
	while _kit.has_pending() and t < 1.0:
		_advance(0.01)
		t += 0.01
	_check("impact à la frame 3 (12 i/s : 0,25 s)", _near(t, 0.25, 0.03), str(t))
	_check("projectile parti à l'impact", _player.spells.active_projectile_count() == 1)
	await _frames(30)
	_check("coef 0,75 + 0,4 × eau (0,95 à 50)", tgt.taken.size() == 1 and _near(tgt.taken[0], (AverseKit.GOUTTE_COEF_MIN + 0.5 * AverseKit.GOUTTE_COEF_WATER) * BASE, 0.05), str(tgt.taken))

	print("Sort 2 : Vague")
	_reset(10.0)
	_check("bloquée sous 20 d'eau", _player.spells.is_slot_blocked(2) and not _player.spells.cast(2))
	var cds0: Dictionary = _player.get_spell_cooldowns()[1]
	_check("bouton : pas assez d'eau (affordable faux, texte)", cds0.get("affordable") == false and String(cds0.get("cost", {}).get("lack", "")) == "pas assez d'eau", str(cds0))
	_reset(60.0)
	var front := _fake(Vector2(200, 0))
	var edge := _fake(Vector2(250, 120)) # ~25° : dans le cône de 60°
	var side := _fake(Vector2(0, 200))
	var far := _fake(Vector2(400, 0))
	_player.spells.aim_override = Vector2(500, 0)
	_check("vague lancée", _player.spells.cast(2))
	_check("20 d'eau payées au lancement", _near(_kit.water, 40.0, 0.01), str(_kit.water))
	_check("verrou anti-spam juste après (effet pas parti)", _kit.is_cast_locked() and _player.spells.is_slot_blocked(2))
	_check("anim d'action wave", String(_player.action_anim()).begins_with("wave"), str(_player.action_anim()))
	_check("rien avant l'impact", front.taken.is_empty())
	_advance(0.3)
	_check("coef 3,5 devant", _near(front.total(), AverseKit.WAVE_COEF * BASE, 0.05), str(front.taken))
	_check("bord du cône touché", edge.taken.size() == 1)
	_check("rien sur le côté ni au-delà de 5 u", side.taken.is_empty() and far.taken.is_empty())
	_check("trempé (slow 30 % 4 s)", front.soaked())
	var cone_vfx := false
	for c in _player.get_node("SpellFX").get_children():
		cone_vfx = cone_vfx or c.name.begins_with("WaveCone")
	_check("cône rendu (wave_cone_<dir>)", cone_vfx)
	_check("aucune recharge : Vague relançable dès l'effet parti", _player.spells._remaining[2] == 0.0 and not _player.spells.is_slot_blocked(2) and _player.spells.cast(2))
	_check("coût affiché : 20 d'eau", String(_player.get_spell_cooldowns()[1].get("cost", {}).get("cost", "")) == "20 d'eau")
	_advance(0.3)

	print("À sec")
	_reset(20.0)
	_player.spells.aim_override = Vector2(500, 0)
	_check("vague qui vide l'amphore", _player.spells.cast(2) and _kit.water < AverseKit.DRY_BELOW)
	_check("à sec : DRY_LOCK_S, jauge éteinte « À SEC »", _near(_kit.dry_left, AverseKit.DRY_LOCK_S) and bool(_kit.resource_state()["blocked"]) and _kit.resource_state()["text"] == "À SEC")
	_advance(1.0)
	_kit.gain_water(5.0)
	_check("à sec : aucun gain (pluie, kills…)", _near(_kit.water, 0.0, 0.01), str(_kit.water))
	_advance(1.5)
	_check("après DRY_LOCK_S : la pluie reprend", _kit.water > 0.5 and _kit.dry_left == 0.0, str(_kit.water))

	print("Sort 3 : Flaque-miroir")
	_reset(30.0)
	var inside := _fake(Vector2(300, 0))
	_kit._rain_mult = 1.0
	_player.spells.aim_override = Vector2(300, 0)
	_check("flaque lancée", _player.spells.cast(3))
	_check("18 d'eau payées", _near(_kit.water, 12.0, 0.01), str(_kit.water))
	_check("Flaque : seule à garder une recharge (5 s)", _near(_player.spells._remaining[3], AverseKit.PUDDLE_CD, 0.3), str(_player.spells._remaining[3]))
	_check("anim d'action cast", String(_player.action_anim()).begins_with("cast"), str(_player.action_anim()))
	_advance(0.2)
	_check("flaque posée au point visé", _kit.puddles.size() == 1 and _kit.puddles[0].global_position.distance_to(Vector2(300, 0)) < 1.0)
	_check("premier tick (coef de la Flaque)", _near(inside.total(), AverseKit.PUDDLE_COEF * BASE, 0.05), str(inside.taken))
	_advance(0.3)
	_check("trempe dans la flaque", inside.soaked())
	_check("bloquée sous 18 d'eau", not _kit.slot_affordable(3) and _player.spells.is_slot_blocked(3))
	_player.global_position = Vector2(300, 0)
	var w0: float = _kit.water
	_advance(1.0)
	_check("dans sa flaque : +PUDDLE_GAIN_PER_S en plus de la pluie", _near(_kit.water - w0, 2.5 + AverseKit.PUDDLE_GAIN_PER_S, 0.15), str(_kit.water - w0))
	_advance(5.5)
	_check("ticks 0,5 / 0,5 s sur 6 s", inside.taken.size() >= 12 and inside.taken.size() <= 14, str(inside.taken.size()))

	print("Sort 4 : Crue")
	_reset(30.0)
	_check("bloquée sous 40 d'eau", _player.spells.is_slot_blocked(4))
	_reset(100.0)
	var near_e := _fake(Vector2(100, 0))
	var ring := _fake(Vector2(6.8 * U, 0))
	var out := _fake(Vector2(7.4 * U, 0))
	_check("crue lancée", _player.spells.cast(4))
	_check("toute l'eau vidée", _near(_kit.water, 0.0, 0.01))
	_check("anim d'action crue", String(_player.action_anim()).begins_with("crue"), str(_player.action_anim()))
	_check("vitesse 4,4 u/s dès l'amphore vide", _near(_player.move_speed(), 4.4 * U, 0.2))
	_advance(0.5)
	_check("coef 9 à 100 d'eau", not near_e.taken.is_empty() and _near(near_e.taken[0], 9.0 * BASE, 0.1), str(near_e.taken))
	_check("Crue : jamais « à sec »", _kit.dry_left == 0.0)
	_check("rayon 7 u à 100 d'eau", ring.taken.size() == 1 and out.taken.is_empty())
	_check("trempe", near_e.soaked())
	_check("laisse une Flaque-miroir", _kit.puddles.size() == 1)
	_check("coef et rayon à 40 d'eau : 3,0 / 5,8 u", _near(_kit.crue_coef(40.0), 2.998, 0.01) and _near(_kit.crue_radius_u(40.0), 5.8))
	_check("rendement croissant : coef/eau à 100 > à 40", _kit.crue_coef(100.0) / 100.0 > _kit.crue_coef(40.0) / 40.0 * 1.15)
	_check("Crue : recharge CRUE_CD (12 s)", _near(_player.spells._remaining[4], AverseKit.CRUE_CD, 0.8), str(_player.spells._remaining[4]))
	_kit.puddles[0].queue_free()
	_kit.puddles.clear()
	_reset(100.0)
	_player.spells.aim_override = Vector2(200, 0)
	for i in 3:
		_kit.spawn_puddle(_player.character.spells[2], Vector2(100 * i, 0))
	await _frames(1)
	var live := 0
	for z in _kit.puddles:
		if is_instance_valid(z) and not z.is_queued_for_deletion():
			live += 1
	_check("2 flaques au plus (la plus ancienne s'assèche)", live == AverseKit.PUDDLE_MAX, str(live))

	print("Glissade (esquive au maintien, consomme l'eau)")
	_reset(50.0)
	_check("esquive = SlideDodge", _player.dodge_move() is SlideDodge, str(_player.dodge_move()))
	_check("glissade lancée", _player.dodge(Vector2.RIGHT))
	_check("départ : -SLIDE_START_COST d'eau", _near(_kit.water, 50.0 - AverseKit.SLIDE_START_COST, 0.01), str(_kit.water))
	_check("invulnérable au départ (0,15 s)", _player.is_invulnerable() and _near(_player.dodge_move().invuln_left, SlideDodge.SLIDE_IFRAME_S, 0.001))
	_check("en glisse (sliding)", _kit.sliding and _player.is_dodging())
	var w1: float = _kit.water
	for i in 30: # 0,25 s tenue
		_player.dodge_step(1.0 / 120.0)
		_player.tick(1.0 / 120.0)
	_check("drain SLIDE_DRAIN_PER_S (moins la pluie)", _near(w1 - _kit.water, (AverseKit.SLIDE_DRAIN_PER_S - AverseKit.RAIN_GAIN_PER_S) * 0.25, 0.6), str(w1 - _kit.water))
	_check("9 u/s", _near(_player.global_position.x, AverseKit.SLIDE_SPEED_U * U * 0.25, 2.0), str(_player.global_position.x / U))
	_check("plus invulnérable en glisse", not _player.is_invulnerable())
	_player.dodge_release()
	_player.dodge_step(1.0 / 120.0)
	_check("relâcher = fin", not _player.is_dodging() and not _kit.sliding)
	_check("amphore < 80 : pas de freinage", _kit.stumble_left <= 0.0)
	_check("verrou de relance", not _player.dodge(Vector2.RIGHT))
	_player.reset_dodge()
	_reset(5.0)
	_check("sans l'eau du départ : refusée", not _player.dodge(Vector2.RIGHT) and not _kit.can_dodge())
	_reset(12.0)
	_check("part à 12 d'eau", _player.dodge(Vector2.RIGHT))
	for i in 240:
		if not _player.is_dodging():
			break
		_player.dodge_step(1.0 / 120.0)
		_player.tick(1.0 / 120.0)
	_check("réservoir vide = arrêt", not _player.is_dodging() and _kit.water <= 0.1, str(_kit.water))
	_player.reset_dodge()
	_reset(100.0) # 100 - 10 au départ - drain mini 0,15 s = 86 > STUMBLE_WATER
	_player.dodge(Vector2.RIGHT)
	_player.dodge_release()
	for i in 30:
		_player.dodge_step(1.0 / 120.0)
		_player.tick(1.0 / 120.0)
	_check("amphore ≥ 80 : freine mal (anim stumble, ×0,6)", _kit.stumble_left > 0.0 and String(_kit.visual_anim(&"idle_e")).begins_with("stumble") and _player.move_speed() < 3.6 * U * 0.61)
	_player.reset_dodge()

	print("Mort")
	_reset(50.0)
	_player.spells.aim_override = Vector2(300, 0)
	_player.spells.cast(3)
	Events.player_died.emit()
	_check("effets en attente annulés", not _kit.has_pending())

	_reset()
	print("Auto-cast : budget d'eau, la Crue reste lançable")
	_kit.water = 60.0
	_kit._auto_budget = 0.0
	_check("budget vide : la Vague attend (l'eau va à la Crue)", not _kit.auto_cast_ok(2) and _kit.auto_cast_ok(1))
	_kit.gain_water(40.0)
	_check("eau gagnée : 60 % au budget", _near(_kit._auto_budget, 24.0, 0.01) and _kit.auto_cast_ok(2), str(_kit._auto_budget))
	_kit.water = 50.0
	_check("Crue : pas sous AUTO_CRUE_AT sans foule", not _kit.auto_cast_ok(4))
	_kit.water = AverseKit.AUTO_CRUE_AT
	_check("Crue auto à AUTO_CRUE_AT (avant le trébuchement)", _kit.auto_cast_ok(4))
	_kit.water = 45.0
	for i in AverseKit.AUTO_CRUE_CROWD:
		_fake(Vector2(60 + 10 * i, 0))
	_check("Crue auto dès 40 face à une foule", _kit.auto_cast_ok(4))
	_reset(50.0)
	var big := _fake(Vector2(300, 0))
	var wb: float = _kit.water
	if &"is_elite" in big:
		big.set(&"is_elite", true)
	else:
		big.add_to_group(&"bosses")
	_kit.on_spell_hit(_player.character.spells[0], big, 1.0)
	_check("goutte sur élite/boss : +BIG_HIT_WATER eau", is_equal_approx(_kit.water, wb + AverseKit.BIG_HIT_WATER))
	var small := _fake(Vector2(300, 50))
	wb = _kit.water
	_kit.on_spell_hit(_player.character.spells[0], small, 1.0)
	_check("goutte sur un monstre : +0,5 eau", is_equal_approx(_kit.water, wb + AverseKit.HIT_WATER))
	big.queue_free()
	_reset()

	print("Combat simulé (auto-cast, vrai monstre élite T3, 25 s) : l'ultime est atteignable")
	_reset(50.0)
	var casts := {}
	_player.spells.spell_cast.connect(func(sp: SpellData) -> void: casts[sp.slot] = int(casts.get(sp.slot, 0)) + 1)
	_player.grant_invulnerability(1.0e6)
	_player.auto_cast_spells = true
	_player.spells.manual_aim_enabled = false
	_player.set_physics_process(true)
	var elite: Node2D = director.spawn_enemy(3, Vector2(4.0 * U, 0.0), true)
	if elite != null and &"max_hp" in elite:
		elite.set(&"max_hp", 1.0e9)
		elite.set(&"hp", 1.0e9)
	var wmin := 100.0
	Engine.time_scale = 4.0
	for i in 25 * 60 / 4:
		await get_tree().physics_frame
		wmin = minf(wmin, _kit.water)
	Engine.time_scale = 1.0
	_player.set_physics_process(false)
	_player.auto_cast_spells = false
	print("    lancers ", casts, " eau min %.0f fin %.0f" % [wmin, _kit.water])
	_check("élite présente", elite != null)
	_check("Crue lancée au moins une fois (auto)", int(casts.get(4, 0)) >= 1, str(casts))
	_check("Vagues lancées sans recharge, sans vider l'amphore bêtement", int(casts.get(2, 0)) >= 2 and wmin >= 0.0, str(casts))
	if elite != null and is_instance_valid(elite):
		elite.queue_free()
	_reset()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame

	print("Partie réelle (main.tscn) avec Averse : fumée")
	RunState.character = &"averse"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 777)
	get_tree().root.add_child(main)
	await _frames(120)
	var mp: Node = main.get(&"player")
	_check("joueur de la partie = Averse", mp != null and mp.get(&"kit") is AverseKit)
	if mp != null and mp.get(&"kit") is AverseKit:
		var k: AverseKit = mp.kit
		k.water = 100.0
		mp.spells.cast(2)
		mp.spells.cast(3)
		await _frames(30)
		mp.spells.cast(4)
		await _frames(120)
		_check("pluie lue sur la carte (0,5-1,5 ou sec)", k.rain_mult() == 0.0 or (k.rain_mult() >= 0.5 and k.rain_mult() <= 1.5), str(k.rain_mult()))
		_check("partie toujours en cours après Crue", not bool(mp.get(&"dead")) or bool(main.get(&"run_over")))
	main.queue_free()
	await get_tree().process_frame
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
