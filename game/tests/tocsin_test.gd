extends Node
## Test headless de Tocsin (docs/Design_Personnages.md §1) : stats, calques (T5), 4 sorts, charges séquentielles,
## membres au sol ramassables, emprisonnement, poussée, explosion confinée, Surchauffe, table d'états (§1.4),
## anims de lancer et frame d'impact, lumières, régénération, changement d'étage.
## godot --headless --path game res://tests/tocsin_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, _data: Dictionary) -> void:
		statuses.append(status)

	func is_slowed() -> bool:
		return false

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
const BASE := 12.0 ## Dégât_base niveau 1
const DT := 1.0 / 60.0

var _fails := 0
var _player: CharacterBody2D
var _kit: TocsinKit
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


## Avance la simulation de `t` s : joueur (états, recharges, actions) et membres en jeu ; sort 1 tenu.
func _sim(t: float) -> void:
	var n := int(ceil(t / DT))
	for i in n:
		_player.spells._remaining[1] = 99.0
		_player.tick(DT)
		for l in _kit.limbs.values():
			if is_instance_valid(l):
				l.set_physics_process(false)
				l.step(DT)


func _limb(key: StringName) -> TocsinLimb:
	var l: TocsinLimb = _kit.limbs.get(key)
	return l if l != null and is_instance_valid(l) else null


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.regen_all()
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.is_moving = false
	_player.facing = Vector2.DOWN
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player._dodge_cd = 0.0
	_player._invuln = 0.0
	_sim(0.5) # fin des anims d'action précédentes


func _run() -> void:
	RunState.level = 1
	RunState.character = &"tocsin"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as TocsinKit

	print("Personnage et rendu")
	_check("kit Tocsin", _kit != null)
	_check("4 sorts / ids", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["tocsin_rivets_rougis", "tocsin_bras_grappins", "tocsin_coups_de_botte", "tocsin_tete_cloche"])
	_check("PV L1 = 130", _near(_player.max_hp, 130.0), str(_player.max_hp))
	_check("armure 20", _near(_player.armor(), 20.0))
	_check("régén 0,8", _near(_player.regen_per_s(), 0.8))
	_check("vitesse 4,0 u/s", _near(_player.move_speed(), 4.0 * U), str(_player.move_speed()))
	var shape := (_player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	_check("hitbox 0,5 u", _near(shape.radius, 24.0), str(shape.radius))
	var vis := _player.get_node("Visual") as AnimatedSprite2D
	var layered := TocsinLayers.available(TocsinKit.ASSET_DIR)
	if layered:
		_check("calques T5 : 6 calques sous le torse", _kit.layers != null and _kit.layers.sprites.size() == 6, str(_kit.layers.sprites.size() if _kit.layers else -1))
		_check("torse : anims walk/throw", vis.sprite_frames.has_animation(&"walk_s") and vis.sprite_frames.has_animation(&"throw_arm_l_s"))
		_check("vapeur de cou cachée avec la tête", not _kit.layers.is_shown(&"neck_steam") and _kit.layers.is_shown(&"head"))
		_check("ordre de profondeur chargé", _kit.layers.orders.size() == 8)
	else:
		_check("repli : un seul sprite", _kit.layers == null)
	var lights_ok := true
	for sp in TocsinKit.character().spells:
		lights_ok = lights_ok and String(sp.light_preset).begins_with("tocsin_") and not LightRig.get_preset(sp.light_preset).is_empty()
	_check("lumières des sorts : presets tocsin_* (foyer), jamais ceux d'Ardent", lights_ok)
	var icons_ok := true
	for sp in TocsinKit.character().spells:
		icons_ok = icons_ok and ArdentKit.spell_icon(sp.id) != null
	_check("icônes de sorts (lot T4)", icons_ok)

	print("Sort 1 : Rivets rougis")
	_reset()
	var body := FakeBody.new(10.0)
	body.add_to_group("enemies")
	get_tree().root.add_child(body)
	_junk.append(body)
	body.global_position = Vector2(150, 0)
	_player.spells._remaining[1] = 0.0
	_check("rivet tiré", _player.spells.cast(1))
	_check("anim attack à l'arrêt", _player.action_base() == &"attack", String(_player.action_base()))
	for i in 40:
		await get_tree().physics_frame
		if not body.taken.is_empty():
			break
	_check("coef 0,8", body.taken.size() == 1 and _near(body.taken[0], 0.8 * BASE), str(body.taken))
	var s1: SpellData = _kit._spell_of(1)
	_check("cadence 0,6 s", _near(Balance.attack_interval(s1.base_cooldown, 0.0), 0.6, 0.001))
	_kit.present[&"arm_l"] = false
	_kit.present[&"leg_l"] = false
	_kit._refresh_state()
	_check("Surchauffe : +24 % à 2 membres", _near(Balance.attack_interval(s1.base_cooldown, 0.0), 0.6 / 1.24, 0.001), str(s1.base_cooldown))
	_player.is_moving = true
	_check("en marche : pas d'anim attack (le corps marche)", _kit.action_for(s1) == &"")
	_player.is_moving = false

	print("Sort 2 : Bras-grappins")
	_reset()
	var a1 := _fake(Vector2(3.0 * U, 0))
	var a2 := _fake(Vector2(5.0 * U, 10))
	var far := _fake(Vector2(5.0 * U, 2.0 * U))
	_player.spells.aim_override = Vector2(10 * U, 0)
	_check("bras lancé", _player.spells.cast(2))
	_check("anim throw_arm_l", _player.action_base() == &"throw_arm_l", String(_player.action_base()))
	_check("bras gauche détaché, 1 charge", not _kit.present[&"arm_l"] and _kit.charges(2) == 1)
	_check("pas encore parti (frame d'impact)", _limb(&"arm_l") == null)
	var t_imp := 0.0
	while _limb(&"arm_l") == null and t_imp < 1.0:
		_sim(DT)
		t_imp += DT
	_check("parti à la frame d'impact", t_imp > 0.05 and t_imp < 0.5, str(t_imp))
	_check("charge restante : sort prêt", _near(_player.spells._remaining[2], 0.0))
	_sim(0.5)
	_check("180 % au passage", a1.taken.size() == 1 and _near(a1.taken[0], TocsinKit.ARM_COEF * BASE), str(a1.taken))
	_check("deuxième cible accrochée", a2.taken.size() == 1 and _kit.is_captured(a2))
	_check("hors couloir intact", far.taken.is_empty())
	_sim(0.8)
	var arm := _limb(&"arm_l")
	_check("pince plantée", arm != null and arm.phase == TocsinLimb.Phase.CLAMP, str(arm.phase if arm else -1))
	var drop := Vector2(2.0 * U, 0)
	_check("paquet déposé 2 u devant", arm != null and arm.global_position.distance_to(drop) < 8.0, str(arm.global_position if arm else Vector2.ZERO))
	_check("prisonniers tenus sur 1 u", a1.global_position.distance_to(drop) <= U and a2.global_position.distance_to(drop) <= U,
			"%s %s" % [a1.global_position, a2.global_position])
	a1.global_position += Vector2(200, 0) # le monde tente de le déplacer
	_sim(DT)
	_check("emprisonné : la position est tenue", a1.global_position.distance_to(drop) <= U)
	_check("second bras : dernière charge", _player.spells.cast(2))
	_sim(0.3)
	_check("0 charge : recharge affichée (8 s - écoulé)", _player.spells._remaining[2] > 5.0 and _player.spells._remaining[2] < 8.0, str(_player.spells._remaining[2]))
	_check("sans bras : jambes bloquées", _player.spells.is_slot_blocked(3) and not _player.spells.cast(3))
	_check("sans bras : vitesse inchangée (4,0)", _near(_player.move_speed(), 4.0 * U))
	_sim(2.6)
	_check("fin de pince : prisonnier libéré", not _kit.is_captured(a1))
	arm = _limb(&"arm_l")
	_check("bras au sol", arm != null and arm.phase == TocsinLimb.Phase.GROUND and arm.pickup != null)
	if arm != null and arm.pickup != null:
		var rl_before := float(_kit.recharge_left[2])
		_player.global_position = arm.global_position
		arm.pickup._t = TocsinKit.PICKUP_DELAY_S # délai de pose écoulé
		arm.pickup.step(DT)
		_sim(DT)
		_check("ramassé : recharge restante x0,5 (23/10), pas de charge immédiate", _near(float(_kit.recharge_left[2]), rl_before * TocsinKit.PICKUP_CD_REFUND, 0.1) and not _kit.present[&"arm_l"], "%s -> %s" % [rl_before, _kit.recharge_left[2]])
	_player.global_position = Vector2.ZERO
	_sim(16.0)
	_check("recharge : les bras reviennent d'eux-mêmes", _kit.present[&"arm_r"] and _kit.present[&"arm_l"] and _limb(&"arm_r") == null)
	_player.spells.aim_override = null

	print("Sort 3 : Coups de botte")
	_reset()
	var l1 := _fake(Vector2(2.0 * U, 0))
	_player.spells.aim_override = Vector2(10 * U, 0)
	_check("jambe lancée", _player.spells.cast(3))
	_check("anim throw_leg_l", _player.action_base() == &"throw_leg_l", String(_player.action_base()))
	_sim(0.7)
	_check("300 %", l1.taken.size() == 1 and _near(l1.taken[0], 3.0 * BASE), str(l1.taken))
	var leg := _limb(&"leg_l")
	_check("jambe au sol au bout du couloir (5 u)", leg != null and leg.phase == TocsinLimb.Phase.GROUND and _near(leg.global_position.x, 5.0 * U, 6.0),
			str(leg.global_position if leg else Vector2.ZERO))
	_check("cloche-pied : 2,0 u/s", _kit.locomotion() == &"hop" and _near(_player.move_speed(), 2.0 * U))
	_check("roulade 1,5 u", _near(_kit.dodge_distance_u(), 1.5))
	_player.is_moving = true
	var hop := _kit.visual_anim(&"run_s")
	_check("anim hop_r (jambe droite restante)", not layered or String(hop).begins_with("hop_r"), String(hop))
	_player.is_moving = false
	_check("deuxième jambe", _player.spells.cast(3))
	_sim(0.3)
	_check("2 bras 0 jambe : marche sur les mains 2,4 u/s", _kit.locomotion() == &"handwalk" and _near(_player.move_speed(), 2.4 * U))
	_check("transition fall jouée", not layered or String(_kit.visual_anim(&"idle_s")).begins_with("fall") or _kit._fall_left == 0.0)
	_kit.present[&"arm_l"] = false
	_kit._refresh_state()
	_check("1 bras : rampe 1,4 u/s, hitbox 0,45", _kit.locomotion() == &"crawl" and _near(_player.move_speed(), 1.4 * U) and _near(shape.radius, 24.0 * 0.9))
	_kit.present[&"arm_r"] = false
	_kit._refresh_state()
	_check("tonneau 2,0 u/s, roulade 2 u", _kit.locomotion() == &"roll" and _near(_player.move_speed(), 2.0 * U) and _near(_kit.dodge_distance_u(), 2.0))
	_check("tonneau : anim roll", not layered or String(_kit.visual_anim(&"idle_s")).begins_with("roll"), String(_kit.visual_anim(&"idle_s")))
	_check("Surchauffe à 4 membres : +48 %", _near(Balance.attack_interval(_kit._spell_of(1).base_cooldown, 0.0), 0.6 / 1.48, 0.001))
	_player.spells.aim_override = null

	print("Sort 4 : Tête-cloche et explosion confinée")
	_reset()
	var free_t := _fake(Vector2(4.0 * U, 1.0 * U))
	var pris := _fake(Vector2(3.0 * U, 0))
	_player.spells.aim_override = Vector2(10 * U, 0)
	_player.spells.cast(2) # bras : emprisonne `pris`
	_sim(1.3)
	_check("prisonnier en place", _kit.is_captured(pris))
	_player.spells.aim_override = Vector2(2.0 * U, 0) # la tête vise le paquet
	var before_p := pris.total()
	var before_f := free_t.total()
	_check("tête lancée (sans bras requis)", _player.spells.cast(4))
	_check("anim throw_head", _player.action_base() == &"throw_head")
	var t_head := 0.0
	while _limb(&"head") == null and t_head < 1.0:
		_sim(DT)
		t_head += DT
	_check("tête partie à la frame d'impact (3)", t_head > 0.05 and t_head < 0.6, str(t_head))
	_sim(0.2)
	var head := _limb(&"head")
	_check("tête en vol (lob, hauteur)", head != null and head.phase == TocsinLimb.Phase.FLY and head.sprite.position.y < -20.0)
	_check("sans tête : rivets 5 u, bras 4 u", _near(_kit._spell_of(1).range_u, 5.0) and _near(_kit._spell_of(2).range_u, 4.0))
	if layered:
		_check("sans tête : vapeur de cou visible", _kit.layers.is_shown(&"neck_steam") and not _kit.layers.is_shown(&"head"))
	_sim(0.75)
	_check("tintement avant l'explosion", head != null and is_instance_valid(head) and head.phase == TocsinLimb.Phase.RING)
	_sim(0.4)
	_check("1 200 % sur une cible libre", _near(free_t.total() - before_f, TocsinKit.HEAD_COEF * BASE), str(free_t.taken))
	_check("+50 % sur l'emprisonné (1 800 %)", _near(pris.total() - before_p, TocsinKit.HEAD_COEF * (1.0 + TocsinKit.HEAD_PRISONER_BONUS) * BASE), str(pris.taken))
	_check("prisonnier libéré par l'explosion", not _kit.is_captured(pris))
	_check("tête jamais ramassable", _limb(&"head") == null)
	_check("recharge 22 s", _player.spells._remaining[4] > 20.0, str(_player.spells._remaining[4]))
	_sim(21.0)
	_check("la tête repousse", _kit.has_head() and _near(_kit._spell_of(1).range_u, 8.0))

	print("Étage, mort")
	_reset()
	_player.spells.aim_override = Vector2(10 * U, 0)
	_player.spells.cast(2)
	_player.spells.cast(3)
	_sim(0.6)
	Events.floor_started.emit(2)
	_check("changement d'étage : membres régénérés", _kit.absent_count() == 0 and _kit.limbs.is_empty())
	await get_tree().process_frame
	_check("aucun membre libéré gardé dans `limbs`", _kit.limbs.values().all(func(l): return is_instance_valid(l)))
	_check("recharges remises à zéro", _near(_player.spells._remaining[2], 0.0) and _near(_player.spells._remaining[3], 0.0))
	_player.spells.aim_override = null

	print("Socle commun : charges, ressource, sauvegarde")
	_reset()
	_player.spells.aim_override = Vector2(10 * U, 0)
	_player.spells.cast(2)
	_sim(0.6)
	var cd2: Dictionary = _player.get_spell_cooldowns().filter(func(c): return c.slot == 2)[0]
	_check("pastilles de charges du bouton (bras : 1/2)", cd2["charges"] == Vector2i(1, 2), str(cd2["charges"]))
	var res := _kit.resource_state()
	_check("ressource KitResource : 4/5 membres", res["id"] == &"limbs" and res["pips"] == 5 and res["filled"] == 4)
	var st := _kit.save_state()
	var rl := float(_kit.recharge_left[2])
	_kit.regen_all()
	_kit.load_state(JSON.parse_string(JSON.stringify(st))) # aller-retour JSON comme RunSave
	_check("reprise : bras gauche absent et en recharge", not _kit.present[&"arm_l"] and (_kit.queue[2] as Array) == [&"arm_l"] and _near(float(_kit.recharge_left[2]), rl, 0.01))
	_check("reprise : aucun membre en jeu", _kit.limbs.is_empty())
	_sim(rl + 0.2)
	_check("reprise : le bras repousse", _kit.present[&"arm_l"])
	_player.spells.aim_override = null

	print("Équilibrage 22/10 : auto-cast (un bras gardé pour les bottes)")
	_reset()
	_check("tous membres : bras permis", _kit.auto_cast_ok(2) and _kit.auto_cast_ok(3))
	_kit.present[&"arm_l"] = false
	_check("dernier bras gardé tant qu'une jambe est là", not _kit.auto_cast_ok(2))
	_kit.present[&"leg_l"] = false
	_check("une botte à la fois", not _kit.auto_cast_ok(3))
	_kit.present[&"leg_r"] = false
	_check("sans jambe : le dernier bras peut partir", _kit.auto_cast_ok(2))
	_check("rivets perforants", _player.character.spells[0].pierce == TocsinKit.RIVET_PIERCE)
	_reset()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
