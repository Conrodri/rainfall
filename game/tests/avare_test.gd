extends Node
## Test headless d'Avare (docs/Design_Personnages.md §2.4) : stats, 4 sorts, puissance de l'or, coûts et pièces
## qui retombent (valeur exacte, pas d'or créé), Rançon (étourdissement, marque, prime), Faillite (coef selon l'or
## dépensé, moitié rendue), saignement d'or au coup subi, roulade 2,5 u, anims d'action et frames d'impact.
## godot --headless --path game res://tests/avare_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var stunned := 0.0

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
		return false

	func stun(s: float) -> void:
		stunned = maxf(stunned, s)

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


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


const U := 64.0
const BASE := 12.0

var _fails := 0
var _player: CharacterBody2D
var _kit: Node
var _junk: Array = []
const TEST_PROFILE := "user://test_avare_profile.json" ## profil injecté (jamais le vrai user://profile.json)
var _old_profile_path := ""
var _old_profile_write := false


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


## Avance le joueur jusqu'à la frame d'impact (sort 1 suspendu). Retourne le temps écoulé.
func _to_impact() -> float:
	var t := 0.0
	while _kit.has_pending() and t < 1.5:
		_player.spells._remaining[1] = 99.0
		_player.tick(0.01)
		t += 0.01
	return t


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.apply_stats({"crit_chance": -0.05}) # crit désactivé : dégâts déterministes
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.reset_dodge()
	_player._invuln = 0.0
	RunState.gold = 0.0


## Toutes les pièces de l'Avare sont des ressources de joueur et restent au sol (pas d'expiration).
func _coins_persist(label: String, secs: float) -> void:
	var n: int = _kit.coins.size()
	var ok := n > 0
	for g: GroundPickup in _kit.coins.duplicate():
		ok = ok and is_inf(g.life_s) and bool(g.get_meta(AvareKit.PLAYER_RESOURCE_META, false)) and GroundPickup.PLAYER_RESOURCE
		ok = ok and not g.is_in_group(&"pickups") # jamais aspirées par le ramassage automatique
	var far: Vector2 = _player.global_position
	_player.global_position = Vector2(99999, 99999) # loin : aucun ramassage
	for i in int(secs * 10.0):
		for g: GroundPickup in _kit.coins.duplicate():
			if is_instance_valid(g):
				g.step(0.1)
	_player.global_position = far
	_check(label, ok and _kit.coins.size() == n, "%d -> %d" % [n, _kit.coins.size()])


func _run() -> void:
	_old_profile_path = Profile.path
	_old_profile_write = Profile.write_enabled
	Profile.path = TEST_PROFILE
	Profile.write_enabled = true
	if FileAccess.file_exists(TEST_PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))
	Profile.load_profile()
	RunState.level = 1
	RunState.character = &"avare"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	var pm := PickupManager.new()
	get_tree().root.add_child(pm)
	if not pm.is_in_group(&"pickups"):
		pm.add_to_group(&"pickups")
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit
	var P: float = AvareKit.price_unit()

	print("Personnage et rendu")
	_check("kit Avare", _kit is AvareKit)
	_check("4 sorts / ids", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["avare_coup_de_coffre", "avare_poignee_de_pieces", "avare_rancon", "avare_faillite"])
	_check("PV L1 = 120", _near(_player.max_hp, 120.0), str(_player.max_hp))
	_check("armure 30", _near(_player.armor(), AvareKit.ARMOR) and _near(AvareKit.ARMOR, 30.0))
	_check("régén 0,8", _near(_player.regen_per_s(), 0.8))
	_check("vitesse 3,8 u/s", _near(_player.move_speed(), 3.8 * U), str(_player.move_speed()))
	var vis := _player.get_node("Visual") as AnimatedSprite2D
	_check("sprites AA1 branchés (swing_s, slam_s, ult_s)", vis.sprite_frames != null and vis.sprite_frames.has_animation(&"swing_s")
			and vis.sprite_frames.has_animation(&"slam_s") and vis.sprite_frames.has_animation(&"ult_s"))
	var gold_light := true
	for sp in AvareKit.character().spells:
		gold_light = gold_light and sp.light_preset == &"avare_gold"
	_check("lumière des sorts : l'or (preset avare_gold)", gold_light and LightRig.has_preset(&"avare_gold"))
	_check("lueur dorée attachée à Avare", _kit._glow != null)
	for icon in ["avare_coup_de_coffre", "avare_poignee_de_pieces", "avare_rancon", "avare_faillite"]:
		_check("icône " + icon, ArdentKit.spell_icon(StringName(icon)) != null)

	print("Puissance de l'or")
	_reset()
	print("Équilibrage 22/10 : coffre-bouclier")
	_check("hors frappe : dégâts pleins", is_equal_approx(_kit.damage_taken_mult(null), 1.0))
	_kit.on_cast(_player.character.spells[0])
	_check("après un Coup de coffre : −45 %", is_equal_approx(_kit.damage_taken_mult(null), AvareKit.GUARD_TAKEN_MULT))
	_reset()
	_check("bourse vide : plancher", _near(_kit.damage_add(null, null), AvareKit.GOLD_POWER_FLOOR))
	RunState.gold = 3.0 * P
	_check("3 P : plafond %d %%" % roundi(AvareKit.GOLD_POWER_CAP * 100.0), _near(_kit.damage_add(null, null), AvareKit.GOLD_POWER_CAP), str(_kit.damage_add(null, null)))
	RunState.gold = 10.0 * P
	_check("plafond de puissance", _near(_kit.damage_add(null, null), AvareKit.GOLD_POWER_CAP))
	_check("changement d'étage : garde la moitié de la bourse (hook floor_gold_kept)", _near(_kit.floor_gold_kept(10.0 * P), 5.0 * P))
	_check("jauge de ressource pleine", _near(float(_kit.resource_state()["ratio"]), 1.0) and _kit.resource_state()["text"] == "+%d %% dégâts" % int(round(AvareKit.GOLD_POWER_CAP * 100.0)))
	var rs: Dictionary = _kit.resource_state()
	_check("jauge explicite : « Bourse », +X % dégâts, un repère par P", rs["label"] == "Bourse" and String(rs["text"]).ends_with("dégâts")
			and (rs["marks"] as Array).size() == ceili(AvareKit.GOLD_POWER_CAP / AvareKit.GOLD_POWER_PER_P) - 1, str(rs))
	var descs := {}
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json")):
		if c["id"] == "avare":
			for sp in c["spells"]:
				descs[sp["id"]] = String(sp["desc"]).to_lower()
	_check("descriptions : la bourse expliquée (dégâts, remplissage, pièces qui restent au sol)",
			descs.get("avare_coup_de_coffre", "").contains("bourse") and descs.get("avare_coup_de_coffre", "").contains("dégâts")
			and descs.get("avare_poignee_de_pieces", "").contains("reste au sol") and descs.get("avare_faillite", "").contains("restent au sol")
			and descs.get("avare_rancon", "").contains("bourse"))

	print("Sort 1 : Coup de coffre")
	_reset()
	_check("sans ennemi : aucun coup, aucune recharge", not _player.spells.cast(1) and _player.get_spell_cooldowns()[0].remaining == 0.0)
	var front := _fake(Vector2(100, 0))
	var side := _fake(Vector2(60, 70))
	var back := _fake(Vector2(-110, 0))
	var far := _fake(Vector2(200, 0))
	_check("coup lancé", _player.spells.cast(1))
	_check("anim d'action swing", _player.action_base() == &"swing" and String(_player.action_anim()).begins_with("swing_"), str(_player.action_anim()))
	_check("rien avant la frame d'impact", front.taken.is_empty())
	var t_imp := _to_impact()
	_check("impact à la frame 2 (≈ 0,17 s)", t_imp > 0.1 and t_imp < 0.3, str(t_imp))
	_check("coef du Coup de coffre sur la cible (plancher)", front.taken.size() == 1 and _near(front.total(), BASE * AvareKit.SWING_COEF * (1.0 + AvareKit.GOLD_POWER_FLOOR)), str(front.taken))
	_check("tout l'arc (150°)", _near(side.total(), BASE * AvareKit.SWING_COEF * (1.0 + AvareKit.GOLD_POWER_FLOOR)), str(side.taken))
	_check("rien derrière", back.taken.is_empty())
	_check("rien hors de 2 u", far.taken.is_empty())
	_check("recharge 0,8 s", _near(_player.spells._totals[1], 0.8, 0.02))
	_reset()
	RunState.gold = 2.0 * P
	front = _fake(Vector2(100, 0))
	_player.spells.cast(1)
	_to_impact()
	_check("or 2 P : coef × 1,30", _near(front.total(), BASE * AvareKit.SWING_COEF * 1.3, 0.05), str(front.taken))

	print("Sort 2 : Poignée de pièces")
	_reset()
	_check("bourse vide : jamais grisé, jauge marquée fauchée", not _player.spells.is_slot_blocked(2) and _kit.is_broke() and _kit.resource_state()["blocked"])
	RunState.gold = 1000.0
	var cost: float = maxf(20.0, 0.1 * P)
	var target := _body(Vector2(128, 0), 10.0)
	_player.spells.aim_override = Vector2(500, 0)
	_check("poignée lancée", _player.spells.cast(2))
	_check("5 pièces", _player.spells.active_projectile_count() == 5, str(_player.spells.active_projectile_count()))
	_check("coût payé (2 % de l'or)", _near(RunState.gold, 1000.0 - cost, 0.01), str(RunState.gold))
	_check("anim d'action throw", _player.action_base() == &"throw")
	await _frames(40) # 6 u à 13 u/s ≈ 0,46 s
	var pw := AvareKit.gold_power_for(1000.0 - cost)
	_check("pièce centrale : coef COINS_COEF × or", target.taken.size() >= 1 and _near(target.taken[0], AvareKit.COINS_COEF * BASE * (1.0 + pw), 0.05), str(target.taken))
	_check("5 pièces retombées", _kit.coins.size() == 5, str(_kit.coins.size()))
	_check("80 % du coût au sol", _near(_kit.ground_gold(), 0.8 * cost, 0.01), str(_kit.ground_gold()))
	_check("recharge 5 s", _near(_player.spells._remaining[2], 5.0, 0.6), str(_player.spells._remaining[2]))
	if _kit.coins.size() > 0:
		var g: GroundPickup = _kit.coins[0]
		var before := RunState.gold
		_player.global_position = g.global_position
		g.step(0.01)
		_check("ramasser une pièce rend sa valeur exacte (pas de gold_mult)", _near(RunState.gold - before, 0.8 * cost / 5.0, 0.001), str(RunState.gold - before))
		_check("pièce ramassée disparaît", _kit.coins.size() == 4 or g.is_queued_for_deletion())
	_coins_persist("Poignée : pièces encore au sol après 60 s (jusqu'au ramassage)", 60.0)
	_reset()
	RunState.gold = 1000.0
	var blocker := _body(Vector2(100, 0), 14.0)
	var blocker2 := _body(Vector2(170, 0), 14.0) # traverse 1 : la pièce s'arrête sur le second
	_player.spells.aim_override = Vector2(500, 0)
	_player.spells.cast(2)
	await _frames(20)
	var near_coin := false
	for g2 in _kit.coins:
		if is_instance_valid(g2) and absf(g2.global_position.x - 170.0) < 40.0:
			near_coin = true
	_check("une pièce arrêtée sur un monstre retombe à ses pieds", blocker2.taken.size() >= 1 and near_coin)

	print("Sort 3 : Rançon")
	_reset()
	var r1 := _fake(Vector2(120, 0))
	var r2 := _fake(Vector2(0, -150))
	var rfar := _fake(Vector2(260, 0))
	_check("rançon lancée", _player.spells.cast(3))
	_check("anim d'action slam", _player.action_base() == &"slam")
	t_imp = _to_impact()
	_check("impact à la frame 3 (≈ 0,25 s)", t_imp > 0.18 and t_imp < 0.4, str(t_imp))
	_check("coef Rançon (2,4)", _near(r1.total(), AvareKit.RANSOM_COEF * BASE * (1.0 + AvareKit.GOLD_POWER_FLOOR)), str(r1.taken))
	_check("zone 3 u", _near(r2.total(), AvareKit.RANSOM_COEF * BASE * (1.0 + AvareKit.GOLD_POWER_FLOOR)) and rfar.taken.is_empty())
	_check("étourdissement 0,5 s", _near(r1.stunned, 0.5))
	_check("marque 4 s", _kit.is_marked(r1) and _kit.is_marked(r2) and not _kit.is_marked(rfar))
	pm.sweep()
	var g_r := RunState.gold # ramassage automatique (22/10/2026) : prime créditée à la mort (+ fraction reportée)
	Events.enemy_killed.emit(r1, r1.global_position, 1, false)
	var bonus: float = RunState.gold - g_r + pm.sweep()["gold"]
	var base_gold := Balance.monster_gold(RunState.difficulty(), 1.0) # prime normale (PickupManager)
	_check("monstre marqué : prime × 1,5", _near(bonus, 1.5 * base_gold, 0.001), "%s / %s" % [bonus, base_gold])
	g_r = RunState.gold
	Events.enemy_killed.emit(rfar, rfar.global_position, 1, false)
	var plain: float = RunState.gold - g_r + pm.sweep()["gold"]
	_check("non marqué : prime normale seulement", _near(plain, base_gold, 0.001), str(plain))
	for i in 450:
		_kit.tick(0.01)
	_check("marque expirée après 4 s", not _kit.is_marked(r2))
	var probe := Enemy.new()
	_check("Enemy.stun existe (gel)", probe.has_method(&"stun") and probe.has_method(&"is_stunned"))
	probe.free()

	print("Sort 4 : Faillite")
	_reset()
	RunState.gold = 8.0 * P
	var f1 := _fake(Vector2(150, 0))
	var f2 := _fake(Vector2(0, 300))
	var ffar := _fake(Vector2(400, 0))
	_check("faillite lancée", _player.spells.cast(4))
	_check("anim d'action ult", _player.action_base() == &"ult")
	_check("or intact avant l'impact", _near(RunState.gold, 8.0 * P))
	t_imp = _to_impact()
	_check("impact à la frame 5 (≈ 0,42 s)", t_imp > 0.3 and t_imp < 0.6, str(t_imp))
	var spent: float = _kit.last_ruin.get("spent", 0.0)
	_check("50 % de l'or dépensé", _near(spent, floorf(4.0 * P), 0.01) and _near(RunState.gold, 8.0 * P - spent, 0.01), str(_kit.last_ruin))
	_check("coef base + 4 × min(1, 4 P / 4 P)", _near(_kit.last_ruin.get("coef", 0.0), AvareKit.ruin_coef(spent)) and AvareKit.ruin_coef(4.0 * P) == AvareKit.RUIN_BASE_COEF + AvareKit.RUIN_BONUS_COEF)
	_check("dégâts avec la puissance d'avant (+70 %)", _near(f1.total(), AvareKit.ruin_coef(spent) * BASE * (1.0 + AvareKit.GOLD_POWER_CAP), 0.1), str(f1.taken))
	_check("rayon 5 u", f2.taken.size() == 1 and ffar.taken.is_empty())
	_check("moitié de l'or dépensé au sol", _near(_kit.ground_gold(), spent * 0.5, 0.01) and _kit.coins.size() == 10, "%s %d" % [_kit.ground_gold(), _kit.coins.size()])
	_check("aucun or créé (bourse + sol ≤ avant)", RunState.gold + _kit.ground_gold() <= 8.0 * P + 0.001)
	_coins_persist("Faillite : pièces encore au sol après 60 s (jusqu'au ramassage)", 60.0)
	var g_floor: float = RunState.gold
	var on_ground: float = _kit.ground_gold()
	var kept: float = _kit.floor_gold_kept(RunState.gold)
	_check("changement d'étage : les pièces au sol rentrent dans la bourse avant la part gardée",
			_near(RunState.gold, g_floor + on_ground, 0.01) and _near(kept, 0.5 * (g_floor + on_ground), 0.01) and _kit.ground_gold() == 0.0,
			"%s %s %s" % [RunState.gold, kept, _kit.ground_gold()])
	_reset()
	var f0 := _fake(Vector2(100, 0))
	_player.spells.cast(4)
	_to_impact()
	_check("bourse vide : coef de base", _near(f0.total(), AvareKit.RUIN_BASE_COEF * BASE * (1.0 + AvareKit.GOLD_POWER_FLOOR), 0.05), str(f0.taken))

	print("Malus : l'or saigne")
	_reset()
	RunState.gold = 100.0
	_player.take_damage(10.0, null)
	_check("coup subi : 3 % de l'or perdu", _near(RunState.gold, 97.0, 0.001), str(RunState.gold))
	_check("3 pièces de 1 or, sans expiration", _kit.coins.size() == 3 and _near(_kit.ground_gold(), 3.0, 0.001) and is_inf(_kit.coins[0].life_s))
	var c0: GroundPickup = _kit.coins[0]
	_player.global_position = c0.global_position
	c0.step(0.1)
	_check("pas ramassable tout de suite (0,35 s)", is_instance_valid(c0) and not c0.is_queued_for_deletion())
	c0.step(0.3)
	_check("puis ramassable", _near(RunState.gold, 98.0, 0.001), str(RunState.gold))
	_coins_persist("pièces saignées encore au sol après 60 s", 60.0)

	print("Plafond de pièces au sol")
	_reset()
	RunState.gold = 0.0
	for i in AvareKit.MAX_GROUND_COINS + 5:
		_kit.drop_coin(Vector2(300 + i, 300), 2.0, AvareKit.COIN_LIFE_S)
	_check("au plus 40 pièces ; les plus anciennes rentrent dans la bourse (rien perdu)",
			_kit.coins.size() == AvareKit.MAX_GROUND_COINS and _near(RunState.gold, 10.0, 0.001) and _near(_kit.ground_gold(), 80.0, 0.001),
			"%d %s" % [_kit.coins.size(), RunState.gold])

	print("Tutoriel de la bourse (une fois par profil)")
	_reset()
	if FileAccess.file_exists(TEST_PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))
	Profile.load_profile()
	_check("profil neuf : bulle pas encore vue", not _kit.tip_seen())
	var tip: AvarePurseTip = _kit.show_tip()
	await get_tree().process_frame
	_check("bulle affichée, non bloquante (pas de pause, souris ignorée)", tip != null and is_instance_valid(tip)
			and not get_tree().paused and tip.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("bulle : explique dégâts, remplissage, pièces au sol, étage", tip != null and tip.text_content().contains("dégâts")
			and tip.text_content().contains("remplit") and tip.text_content().contains("restent au sol") and tip.text_content().contains("moitié"))
	_check("vue : enregistrée dans le profil injecté", _kit.tip_seen() and FileAccess.file_exists(TEST_PROFILE)
			and FileAccess.get_file_as_string(TEST_PROFILE).contains(String(AvareKit.TIP_KEY)))
	Profile.load_profile()
	_check("relue du profil : plus jamais affichée", _kit.tip_seen() and _kit.show_tip() == null)
	if tip != null and is_instance_valid(tip):
		tip.t = AvarePurseTip.LIFE_S
		await get_tree().process_frame
		await get_tree().process_frame
	_check("bulle libérée après sa durée", tip == null or not is_instance_valid(tip))

	print("Roulade lourde 2,5 u")
	_reset()
	_check("roulade lancée", _player.dodge(Vector2.RIGHT))
	var t := 0.0
	while _player.is_dodging() and t < 1.0:
		_player.dodge_step(1.0 / 120.0)
		_player.tick(1.0 / 120.0)
		t += 1.0 / 120.0
	_check("distance ≈ 2,5 u", absf(_player.global_position.x - 2.5 * U) <= 0.15 * U, str(_player.global_position.x / U))

	_reset()
	_player.queue_free()
	director.queue_free()
	pm.queue_free()
	await get_tree().process_frame

	print("Partie réelle (main.tscn) avec Avare : fumée")
	RunState.character = &"avare"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 778)
	get_tree().root.add_child(main)
	await _frames(120)
	var mp: Node = main.get(&"player")
	_check("joueur de la partie = Avare", mp != null and mp.get(&"kit") is AvareKit)
	if mp != null and mp.get(&"kit") is AvareKit:
		RunState.gold = 300.0
		mp.spells.cast(2)
		mp.spells.cast(3)
		await _frames(30)
		mp.spells.cast(4)
		await _frames(200)
		_check("partie toujours en cours après Faillite", not bool(mp.get(&"dead")) or bool(main.get(&"run_over")))
	main.queue_free()
	await get_tree().process_frame
	RunState.character = &"ardent"
	RunState.gold = 0.0
	if FileAccess.file_exists(TEST_PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))
	Profile.path = _old_profile_path
	Profile.write_enabled = _old_profile_write
	Profile.load_profile()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
