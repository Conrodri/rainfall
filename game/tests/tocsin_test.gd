extends Node
## Test headless de Tocsin (docs/Design_Personnages.md §1) : stats, calques (T5), 4 sorts, charges séquentielles,
## membres au sol ramassables, Surchauffe (jambes jamais lancées : 23/10/2026), anims de lancer et frame d'impact,
## lumières, régénération, changement d'étage. Bras-pilier et ramassage immédiat : voir aussi tocsin_pillar_test.
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
	_player.reset_dodge()
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
	_check("4 sorts / ids", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["tocsin_rivets_rougis", "tocsin_bras_pilier", "tocsin_coup_de_tocsin", "tocsin_tete_cloche"])
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
	_kit.present[&"arm_r"] = false
	_kit._refresh_state()
	_check("Surchauffe : +24 % à 2 membres", _near(Balance.attack_interval(s1.base_cooldown, 0.0), 0.6 / 1.24, 0.001), str(s1.base_cooldown))
	_player.is_moving = true
	_check("en marche : pas d'anim attack (le corps marche)", _kit.action_for(s1) == &"")
	_player.is_moving = false

	print("Sort 2 : Bras-pilier")
	_reset()
	var a1 := _fake(Vector2(5.0 * U, 0))
	var a2 := _fake(Vector2(5.5 * U, 60))
	var far := _fake(Vector2(5.0 * U, 4.0 * U))
	_player.spells.aim_override = Vector2(5.0 * U, 0)
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
	_sim(0.3)
	var pil := _limb(&"arm_l")
	_check("en vol (lob)", pil != null and pil.phase == TocsinLimb.Phase.FLY)
	_sim(0.5)
	pil = _limb(&"arm_l")
	_check("planté au point visé (5 u)", pil != null and pil.phase == TocsinLimb.Phase.PILLAR and _near(pil.global_position.x, 5.0 * U, 6.0))
	_check("premier tick à la pose", a1.taken.size() == 1 and _near(a1.taken[0], TocsinKit.PILLAR_COEF * BASE), str(a1.taken))
	_check("hors zone intact", far.taken.is_empty())
	_sim(1.0)
	_check("ticks réguliers (0,5 s)", a1.taken.size() >= 3 and a1.taken.size() <= 4, str(a1.taken.size()))
	_check("ralentissement de décharge", a2.statuses.has(&"slow"))
	_check("second bras : dernière charge", _player.spells.cast(2))
	_sim(0.3)
	_check("0 charge : recharge affichée (8 s - écoulé)", _player.spells._remaining[2] > 5.0 and _player.spells._remaining[2] < 8.0, str(_player.spells._remaining[2]))
	_check("deux bras lancés : vitesse inchangée (4,0)", _near(_player.move_speed(), 4.0 * U))
	_check("sort 3 jamais bloqué", not _player.spells.is_slot_blocked(3))
	_sim(16.0)
	_check("recharge : les bras reviennent d'eux-mêmes", _kit.present[&"arm_r"] and _kit.present[&"arm_l"])
	_player.spells.aim_override = null

	print("Sort 3 : Coup de tocsin")
	_reset()
	var t1 := _fake(Vector2(2.0 * U, 0))
	var t2 := _fake(Vector2(0, 2.5 * U))
	var t3 := _fake(Vector2(4.0 * U, 0))
	_check("coup lancé", _player.spells.cast(3))
	_check("coef 2,5 dans 3 u", t1.taken.size() == 1 and _near(t1.taken[0], TocsinKit.TOLL_COEF * BASE) and t2.taken.size() == 1, str(t1.taken))
	_check("hors de 3 u : rien", t3.taken.is_empty())
	_check("recharge 7 s", _near(_player.spells._remaining[3], 7.0, 0.1), str(_player.spells._remaining[3]))
	_check("aucun membre perdu, vitesse 4,0", _kit.absent_count() == 0 and _near(_player.move_speed(), 4.0 * U))

	print("Sort 4 : Tête-cloche")
	_reset()
	var free_t := _fake(Vector2(4.0 * U, 1.0 * U))
	_player.spells.aim_override = Vector2(4.0 * U, 0)
	var before_f := free_t.total()
	_check("tête lancée", _player.spells.cast(4))
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
	_check("1 000 % sur une cible", _near(free_t.total() - before_f, TocsinKit.HEAD_COEF * BASE), str(free_t.taken))
	_check("tête jamais ramassable", _limb(&"head") == null)
	_check("recharge 22 s", _player.spells._remaining[4] > 20.0, str(_player.spells._remaining[4]))
	_sim(21.0)
	_check("la tête repousse", _kit.has_head() and _near(_kit._spell_of(1).range_u, 8.0))

	print("Étage, mort")
	_reset()
	_player.spells.aim_override = Vector2(10 * U, 0)
	_player.spells.cast(2)
	_player.spells.cast(2)
	_sim(0.6)
	Events.floor_started.emit(2)
	_check("changement d'étage : membres régénérés", _kit.absent_count() == 0 and _kit.limbs.is_empty())
	await get_tree().process_frame
	_check("aucun membre libéré gardé dans `limbs`", _kit.limbs.values().all(func(l): return is_instance_valid(l)))
	_check("recharges remises à zéro", _near(_player.spells._remaining[2], 0.0))
	_player.spells.aim_override = null

	print("Socle commun : charges, ressource, sauvegarde")
	_reset()
	_player.spells.aim_override = Vector2(10 * U, 0)
	_player.spells.cast(2)
	_sim(0.6)
	var cd2: Dictionary = _player.get_spell_cooldowns().filter(func(c): return c.slot == 2)[0]
	_check("pastilles de charges du bouton (bras : 1/2)", cd2["charges"] == Vector2i(1, 2), str(cd2["charges"]))
	var res := _kit.resource_state()
	_check("ressource KitResource : 2/3 membres lancés présents", res["id"] == &"limbs" and res["pips"] == 3 and res["filled"] == 2)
	var st := _kit.save_state()
	var rl := float(_kit.recharge_left[2])
	_kit.regen_all()
	_kit.load_state(JSON.parse_string(JSON.stringify(st))) # aller-retour JSON comme RunSave
	_check("reprise : bras gauche absent et en recharge", not _kit.present[&"arm_l"] and (_kit.queue[2] as Array) == [&"arm_l"] and _near(float(_kit.recharge_left[2]), rl, 0.01))
	_check("reprise : aucun membre en jeu", _kit.limbs.is_empty())
	_sim(rl + 0.2)
	_check("reprise : le bras repousse", _kit.present[&"arm_l"])
	_player.spells.aim_override = null

	print("Auto-cast et jambes (23/10/2026)")
	_reset()
	_check("auto-cast : jamais retenu", _kit.auto_cast_ok(2) and _kit.auto_cast_ok(3) and _kit.auto_cast_ok(4))
	_check("jambes toujours là, locomotion marche", _kit.legs() == 2 and _kit.locomotion() == &"walk")
	_check("rivets perforants", _player.character.spells[0].pierce == TocsinKit.RIVET_PIERCE)
	_reset()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
