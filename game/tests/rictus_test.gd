extends Node
## Test headless de Rictus (docs/Design_Rictus_v2.md option 1 « Le fil et la lame ») : stats, 4 sorts, Couteau ficelé
## (plantage, 10 ticks de scie en 5 s, fil cassé à 9 u, couteau au sol), Saccade (1,4 + 0,25 par tour, retour qui perce
## tout, sort 2 prêt dans la frame, non-boss tiré), Doublures lancées (autour du ficelé, 6 × 2,34 sur lui à la Saccade,
## provocation, minuteur, mort à 60 %), lancer automatique, boucle >= 1,3 s, levée, murs (StageMap.los), déblocage caché.
## godot --headless --path game res://tests/rictus_test.tscn  (scène : les autoloads doivent exister)

## Cible factice sans corps (zones, doublures) : mêmes signatures que player_test.
class FakeEnemy extends Node2D:
	var taken: Array = []
	var active := true
	var pulled := Vector2.ZERO

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
		return false

	func push(offset_px: Vector2) -> void:
		pulled += offset_px

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t

	func count_of(v: float) -> int:
		var n := 0
		for a in taken:
			if absf(float(a) - v) < 0.05:
				n += 1
		return n


## Cible factice avec corps en couche 3 (obstacle « monstre » pour la levée).
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
var _kit: RictusKit
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


func _body(pos: Vector2, radius := 10.0, as_enemy := true) -> FakeBody:
	var b := FakeBody.new(radius)
	if as_enemy:
		b.add_to_group("enemies")
	get_tree().root.add_child(b)
	b.global_position = pos
	_junk.append(b)
	return b


## Doublures posées à la frame d'impact de l'anim d'ultime : avance le joueur jusqu'à l'impact,
## sort 1 suspendu pour ne pas toucher les cibles factices. Retourne le temps écoulé.
func _land_decoys() -> float:
	var rem1: float = _player.spells._remaining[1]
	var t := 0.0
	while _kit.decoys_pending() and t < 1.0:
		_player.spells._remaining[1] = 99.0
		_player.tick(0.01)
		t += 0.01
	_player.spells._remaining[1] = rem1
	return t


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Fait avancer le monde à la main (le joueur ne tourne pas seul) : couteau puis kit, sort 1 suspendu.
## Rend le temps simulé ; s'arrête dès que `until` est vrai.
func _drive(seconds: float, until := Callable()) -> float:
	var t := 0.0
	var n := int(ceil(seconds * 60.0 - 0.0001))
	for i in n:
		_player.spells._remaining[1] = 99.0
		if _kit.knife != null and is_instance_valid(_kit.knife):
			_kit.knife.step(DT)
		_player.tick(DT)
		t += DT
		if until.is_valid() and bool(until.call()):
			break
	return t


## Remet tout à plat : cibles, doublures, couteau, états, recharges.
func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	Decoy.clear_all()
	_kit.clear_transients()
	_kit.spin_left = 0.0
	_kit.stagger_left = 0.0
	_kit.lifting = false
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
	RunState.counters.clear()


## Lance le couteau vers (x u, 0) et attend qu'il soit planté dans `target` (ou au sol).
func _throw_at(target: Node2D) -> void:
	_player.spells.aim_override = Vector2(target.global_position.x, 0.0)
	_player.spells.cast(2)
	_player.spells.aim_override = null
	_drive(1.0, func() -> bool: return _kit.kstate != RictusKit.K.FLYING)


func _run() -> void:
	RunState.level = 1
	RunState.character = &"rictus"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false) # boucle pilotée par le test (pas d'auto-tir parasite)
	_kit = _player.kit

	print("Personnage et rendu")
	_check("kit Rictus", _kit is RictusKit)
	_check("4 sorts / ids", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["dagues_demi_lune", "couteau_ficele", "rictus_saccade", "doublures"])
	_check("PV L1 = 95", _near(_player.max_hp, 95.0), str(_player.max_hp))
	_check("armure 10", _near(_player.armor(), 10.0))
	_check("régén 0,6", _near(_player.regen_per_s(), 0.6))
	_check("vitesse 4,2 u/s", _near(_player.move_speed(), 4.2 * U), str(_player.move_speed()))
	var shape := (_player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	_check("hitbox 0,45 u", _near(shape.radius, 24.0 * 0.9), str(shape.radius))
	_check("Montreur (CompanionSprite) alpha 0,8", _kit.companion != null and _near(_kit.companion.self_modulate.a, 0.8))
	_check("Montreur à 1,4 u", _kit.companion != null and _kit.companion.position.y < Iso.lift_logical(1.3))
	_check("5 fils (StringRig)", _kit.strings != null and _kit.strings.lines.size() == 5)
	var steel := true
	for sp in RictusKit.character().spells:
		steel = steel and sp.light_preset == &"spell_steel"
	_check("lumière des sorts argent (jamais la braise d'Ardent)", steel)
	_check("fils fins et discrets", _kit.strings.lines[0].width <= 1.0 and _near(_kit.strings.lines[0].default_color.a, RictusKit.STRING_ALPHA))
	var vis := _player.get_node("Visual") as AnimatedSprite2D
	var companion_idx: int = _kit.companion.get_index()
	_check("ordre : pantin < fils < Montreur < projectiles", vis.get_index() < _kit.strings.get_index()
			and _kit.strings.get_index() < companion_idx and companion_idx < _player.get_node("SpellFX").get_index())
	if not ResourceLoader.exists(RictusKit.SPRITE_FRAMES):
		_check("repli : Ardent teinté", vis.self_modulate.is_equal_approx(RictusKit.PLACEHOLDER_TINT))
	_kit.strings.update_lines(0.1)
	_check("fils tracés entre deux points distincts", _kit.strings.lines[2].points[0].distance_to(_kit.strings.lines[2].points[2]) > 10.0)
	var cd := RictusKit.character()
	_check("sort 3 : recharge 3 s, la plus courte du jeu", _near(cd.spells[2].base_cooldown, 3.0) and _near(cd.spells[1].base_cooldown, 1.0))
	_check("coefs : couteau / Saccade / doublures", _near(cd.spells[1].coef, RictusKit.KNIFE_COEF) and _near(cd.spells[2].coef, RictusKit.SACCADE_COEF) and _near(cd.spells[3].coef, 1.8))
	_check("sort 1 : is_zone faux (audit P3)", not cd.spells[0].is_zone)

	print("Sort 1 : Dagues en demi-lune")
	_reset()
	print("Équilibrage 22/10 : garde du Montreur")
	_check("sans demi-lune : dégâts pleins", is_equal_approx(_kit.damage_taken_mult(null), 1.0))
	_kit.on_cast(_player.character.spells[0])
	_check("après une demi-lune : −30 %", is_equal_approx(_kit.damage_taken_mult(null), RictusKit.GUARD_TAKEN_MULT))
	_kit.tick(RictusKit.GUARD_S + 0.05)
	_check("garde finie", is_equal_approx(_kit.damage_taken_mult(null), 1.0))
	_check("sans ennemi : aucun coup, aucune recharge", not _player.spells.cast(1) and _player.get_spell_cooldowns()[0].remaining == 0.0)
	var front := _fake(Vector2(80, 0))
	var front2 := _fake(Vector2(60, 50))
	var back := _fake(Vector2(-80, 0))
	var far := _fake(Vector2(300, 0))
	_check("demi-lune lancée", _player.spells.cast(1))
	_check("coef 0,8 sur la cible", front.taken.size() == 1 and _near(front.total(), RictusKit.ARC_COEF * BASE), str(front.taken))
	_check("tout le demi-cercle", _near(front2.total(), RictusKit.ARC_COEF * BASE), str(front2.taken))
	_check("rien derrière", back.taken.is_empty())
	_check("rien hors de 3 u", far.taken.is_empty())
	_check("orientation vers la cible la plus proche", _player.facing.dot(front2.global_position.normalized()) > 0.99, str(_player.facing))

	print("Sort 2 : Couteau ficelé (plantage, scie, fil)")
	_reset()
	var tgt := _fake(Vector2(3.0 * U, 0))
	_check("couteau en main", _kit.knife_in_hand() and not _player.spells.is_slot_blocked(2))
	_check("Saccade grisée avec le couteau en main", _player.spells.is_slot_blocked(3) and bool(_player.get_spell_cooldowns()[2].blocked))
	_player.spells.aim_override = Vector2(500, 0)
	_check("couteau lancé", _player.spells.cast(2))
	_player.spells.aim_override = null
	_check("en vol : sort 2 grisé", _kit.kstate == RictusKit.K.FLYING and _player.spells.is_slot_blocked(2))
	_drive(1.0, func() -> bool: return _kit.kstate == RictusKit.K.PLANTED)
	_check("planté dans le premier monstre touché", _kit.kstate == RictusKit.K.PLANTED and _kit.ficele_enemy() == tgt)
	_check("impact du couteau", tgt.taken.size() == 1 and _near(tgt.taken[0], RictusKit.KNIFE_COEF * BASE), str(tgt.taken))
	_check("sort 2 grisé tant que le couteau n'est pas revenu", _player.spells.is_slot_blocked(2))
	_check("Saccade dispo (couteau planté)", not _player.spells.is_slot_blocked(3))
	_check("sort 2 jamais en fenêtre de combo, Saccade oui", not _kit.combo_ready(2) and _kit.combo_ready(3))
	_drive(6.0, func() -> bool: return _kit.kstate == RictusKit.K.GROUND)
	_check("5 s : 10 ticks de scie", tgt.count_of(RictusKit.SAW_COEF * BASE) == 10, str(tgt.taken))
	_check("couteau tombé au sol, fil disparu", _kit.kstate == RictusKit.K.GROUND and _kit.ficele_enemy() == null)
	_check("couteau au sol à l'endroit du monstre", _kit.knife != null and _kit.knife.global_position.distance_to(tgt.global_position) < 2.0)
	_check("couteau au sol : Saccade encore possible", not _player.spells.is_slot_blocked(3))
	# couteau au sol : Saccade sans dégât d'arrachement, retour, sort 2 prêt
	var before: int = tgt.taken.size()
	_check("Saccade sur couteau au sol", _player.spells.cast(3))
	_drive(2.0, func() -> bool: return _kit.knife_in_hand())
	_check("couteau rattrapé, sort 2 prêt", _kit.knife_in_hand() and _player.spells._remaining[2] == 0.0 and not _player.spells.is_slot_blocked(2))
	_check("pas de dégât d'arrachement au sol (seulement le retour 0,6)", tgt.count_of(RictusKit.SACCADE_COEF * BASE) == 0 and tgt.taken.size() == before + 1, str(tgt.taken))
	_check("Saccade de nouveau grisée (couteau en main)", _player.spells.is_slot_blocked(3))

	print("Couteau au sol : ramassage, perte, refabrication")
	_reset()
	var lost := _fake(Vector2(3.0 * U, 0))
	_throw_at(lost)
	_kit.knife.drop_at(Vector2(4.0 * U, 0))
	_check("tombé", _kit.kstate == RictusKit.K.GROUND)
	_player.global_position = Vector2(4.0 * U, 0)
	_drive(0.1, func() -> bool: return _kit.knife_in_hand())
	_check("marcher dessus le rattrape", _kit.knife_in_hand() and _player.spells._remaining[2] == 0.0)
	_throw_at(lost)
	_kit.knife.drop_at(Vector2(7.0 * U, 0))
	_player.global_position = Vector2.ZERO
	_drive(4.2)
	_check("4 s au sol : couteau disparu, perdu", _kit.kstate == RictusKit.K.LOST and _kit.knife == null and _player.spells.is_slot_blocked(2) and _player.spells.is_slot_blocked(3))
	_drive(2.0, func() -> bool: return _kit.knife_in_hand())
	_check("6 s après la chute : le Montreur en refait un", _kit.knife_in_hand() and not _player.spells.is_slot_blocked(2))

	print("Fil cassé : ficelé à plus de 9 u")
	_reset()
	var runner := _fake(Vector2(3.0 * U, 0))
	_throw_at(runner)
	_check("planté", _kit.kstate == RictusKit.K.PLANTED)
	runner.global_position = Vector2(9.5 * U, 0)
	_drive(0.6, func() -> bool: return _kit.kstate == RictusKit.K.GROUND)
	_check("fil cassé : couteau au sol, plus de ficelé", _kit.kstate == RictusKit.K.GROUND and _kit.ficele_enemy() == null)
	_check("tombé là où était le monstre", _kit.knife != null and _kit.knife.global_position.distance_to(runner.global_position) < 2.0)
	_reset()
	var dier := _fake(Vector2(3.0 * U, 0))
	_throw_at(dier)
	dier.active = false
	_drive(0.2, func() -> bool: return _kit.kstate == RictusKit.K.GROUND)
	_check("ficelé mort : couteau planté au sol au même endroit", _kit.kstate == RictusKit.K.GROUND and _kit.knife.global_position.distance_to(dier.global_position) < 2.0)

	print("Ciblage : boss d'abord, puis élite, puis le plus proche")
	_reset()
	var near_t := _fake(Vector2(2.0 * U, 0))
	var elite_t := _fake(Vector2(0, 5.0 * U))
	elite_t.set_meta(&"x", 1)
	_check("mobile : le plus proche (aucun élite)", _kit._pick_target(8.0 * U) == near_t)

	print("Sort 3 : Saccade (tours, arrachement, retour)")
	_reset()
	var tgt3 := _fake(Vector2(1.0 * U, 0))
	_throw_at(tgt3)
	_check("couteau planté", _kit.kstate == RictusKit.K.PLANTED)
	for i in 3:
		_player.spells._remaining[1] = 0.0
		_check("demi-lune %d sur le ficelé" % (i + 1), _player.spells.cast(1))
	_check("3 tours de fil", _kit.tours == 3, str(_kit.tours))
	_player.spells._remaining[1] = 0.0
	_player.spells.cast(1)
	_check("plafond de 3 tours", _kit.tours == RictusKit.TOUR_MAX)
	tgt3.taken.clear()
	_check("Saccade lancée", _player.spells.cast(3))
	_check("arrachement = coef + 3 tours", tgt3.taken.size() == 1 and _near(tgt3.taken[0], (RictusKit.SACCADE_COEF + 3.0 * RictusKit.SACCADE_TOUR_ADD) * BASE), str(tgt3.taken))
	_check("non-boss tiré vers Rictus (1,5 u, borné par la distance)", tgt3.pulled.x < -1.0, str(tgt3.pulled))
	_check("recharge 3 s", _near(_player.spells._remaining[3], 3.0, 0.05), str(_player.spells._remaining[3]))
	_check("couteau en retour", _kit.kstate == RictusKit.K.RETURNING)
	_drive(1.0, func() -> bool: return _kit.knife_in_hand())
	_check("rattrapé : sort 2 prêt dans la frame", _kit.knife_in_hand() and _player.spells._remaining[2] == 0.0)
	_check("le ficelé n'est pas touché une seconde fois par le retour", tgt3.taken.size() == 1, str(tgt3.taken))
	_check("tours remis à zéro", _kit.tours == 0)
	# boss ficelé : ne bouge pas
	_reset()
	var boss := _fake(Vector2(3.0 * U, 0))
	boss.add_to_group("bosses")
	_throw_at(boss)
	_player.spells.cast(3)
	_check("boss ficelé : jamais tiré", boss.pulled == Vector2.ZERO)

	print("Retour qui perce tout")
	_reset()
	var tgt4 := _fake(Vector2(5.0 * U, 0))
	_throw_at(tgt4)
	var r1 := _fake(Vector2(3.5 * U, 8))
	var r2 := _fake(Vector2(2.2 * U, -8))
	var r3 := _fake(Vector2(1.2 * U, 0))
	var off := _fake(Vector2(3.0 * U, 3.0 * U))
	_player.spells.cast(3)
	_drive(1.5, func() -> bool: return _kit.knife_in_hand())
	_check("3 monstres traversés = 3 × 0,6, une touche chacun", r1.count_of(0.6 * BASE) == 1 and r2.count_of(0.6 * BASE) == 1 and r3.count_of(0.6 * BASE) == 1,
			"%s %s %s" % [r1.taken, r2.taken, r3.taken])
	_check("hors ligne : rien", off.taken.is_empty())
	_check("rattrapé", _kit.knife_in_hand())

	print("Sort 4 : Les Doublures lancées")
	_reset()
	var ring_c := _fake(Vector2(5.0 * U, 0))
	_throw_at(ring_c)
	_check("ficelé en place", _kit.ficele_enemy() == ring_c)
	_player.spells.aim_override = Vector2(0, 6.0 * U) # PC : le curseur est ailleurs, les doublures vont quand même autour du ficelé
	_check("doublures lancées", _player.spells.cast(4))
	_player.spells.aim_override = null
	_check("pas encore posées (anim)", Decoy.live.is_empty() and _kit.decoys_pending())
	var t_land := _land_decoys()
	_check("posées à la frame d'impact", t_land > 0.05 and t_land < 0.6, str(t_land))
	_check("anim d'ultime throw_ult (M2b)", _kit.ult_action() == &"throw_ult", String(_kit.ult_action()))
	_check("6 doublures", Decoy.live.size() == 6, str(Decoy.live.size()))
	var around := true
	var cen := Vector2.ZERO
	for d in Decoy.live:
		around = around and _near(d.global_position.distance_to(ring_c.global_position), 1.2 * U, 1.0)
		cen += d.global_position
	_check("hexagone de 1,2 u autour du ficelé (pas du curseur, pas de Rictus)", around and (cen / 6.0).distance_to(ring_c.global_position) < 1.0)
	var d_any: Decoy = Decoy.live[0]
	_check("explosion : VFX double_burst (TOP), coef 1,8", d_any.explode_spell.vfx_frames == RictusKit.DOUBLE_BURST_FRAMES
			and _near(d_any.explode_spell.coef, 1.8) and d_any.flight_spell.vfx_frames == "")
	_check("PV = 20 % des PV max", _near(d_any.hp, 0.2 * 95.0))
	_check("Montreur absent des doublures", d_any.get_child_count() - int(GroundMarker.of(d_any) != null) == 1)
	for d in Decoy.live:
		d.facing = (d.global_position - ring_c.global_position).normalized()
	_check("combo_ready de la Saccade (ficelé + doublures)", _kit.combo_ready(3))
	ring_c.taken.clear()
	var hp_before: float = _player.hp
	_player.hp = 50.0
	_check("Saccade : tire tous les fils", _player.spells.cast(3))
	_check("toutes les doublures explosent d'un coup", Decoy.live.is_empty(), str(Decoy.live.size()))
	_check("6 × (1,8 × 1,3) sur le ficelé", ring_c.count_of(1.8 * 1.3 * BASE) == 6, str(ring_c.taken))
	_check("+2 % PV une seule fois", _near(_player.hp, 50.0 + 0.02 * 95.0, 0.01), str(_player.hp))
	hp_before += 0.0
	# sans ficelé : Saccade détone sans le +30 %, ordre inverse valide
	_reset()
	_player.spells.manual_aim_enabled = false # mobile : pas de curseur (en headless la souris n'est pas à l'origine)
	var pack := _fake(Vector2(3.0 * U, 0))
	_check("doublures sans ficelé (paquet à 3 u)", _player.spells.cast(4))
	_land_decoys()
	var dc := Vector2.ZERO
	for d in Decoy.live:
		dc += d.global_position
	_check("sans ficelé : autour du paquet visé", Decoy.live.size() == 6 and (dc / 6.0).distance_to(pack.global_position) < 2.0)
	_check("Saccade dispo couteau en main grâce aux doublures posées (clic droit = détonation)", not _player.spells.is_slot_blocked(3))
	for d in Decoy.live:
		d.life_s = 30.0
	pack.taken.clear()
	_throw_at(pack)
	pack.taken.clear()
	_player.spells.cast(3)
	_check("couteau planté APRES les doublures : +30 % (ficelé au moment de la Saccade)", pack.count_of(1.8 * 1.3 * BASE) >= 5, str(pack.taken))
	# couteau en main + doublures posées : la Saccade détone seulement (pas de +30 %, couteau gardé, sort 2 libre)
	_reset()
	_player.spells.manual_aim_enabled = false
	var pack2 := _fake(Vector2(3.0 * U, 0))
	_check("doublures posées, couteau en main", _player.spells.cast(4) and _kit.knife_in_hand())
	_land_decoys()
	pack2.taken.clear()
	_check("Saccade couteau en main : détonation", _player.spells.cast(3))
	_check("toutes les doublures explosent (couteau en main)", Decoy.live.is_empty(), str(Decoy.live.size()))
	_check("sans ficelé : pas de +30 %", pack2.count_of(1.8 * 1.3 * BASE) == 0 and pack2.count_of(1.8 * BASE) >= 5, str(pack2.taken))
	_check("couteau toujours en main, sort 2 libre", _kit.knife_in_hand() and not _player.spells.is_slot_blocked(2))
	_check("Saccade de nouveau grisée (plus de doublures, couteau en main)", _player.spells.is_slot_blocked(3))
	_reset()
	var lonely := _fake(Vector2(10.0 * U, 0)) # trop loin du paquet dense : repli sur Rictus
	_check("doublures sans cible à portée : autour de Rictus", _player.spells.cast(4))
	_player.spells.manual_aim_enabled = true
	_land_decoys()
	var rc := Vector2.ZERO
	for d in Decoy.live:
		rc += d.global_position
	_check("repli : autour de Rictus", Decoy.live.size() == 6 and (rc / 6.0).length() < 1.0)
	lonely.taken.clear()

	print("Doublures : provocation, minuteur, mort à 60 %")
	_reset()
	_player.spells.aim_override = Vector2(4.0 * U, 0)
	_check("doublures lancées au curseur (sans ficelé)", _player.spells.cast(4))
	_player.spells.aim_override = null
	_land_decoys()
	var east: Decoy = null
	for d in Decoy.live:
		if d.global_position.distance_to(Vector2(4.0 * U + 1.2 * U, 0)) < 1.0:
			east = d
	_check("première doublure vers l'extérieur, anneau 1,2 u autour du curseur", east != null)
	_check("face vers l'extérieur", east != null and east.facing.x > 0.99)
	for d in Decoy.live:
		d.life_s = 30.0 # provocation testée sans explosion
	var mob: Enemy = director.spawn_enemy(1, Vector2(200, 200))
	var mob_hp0: float = _player.hp
	var se: Decoy = Decoy.nearest_to(mob.position, 4.0 * U)
	var d0 := mob.position.distance_to(se.global_position)
	await _frames(150)
	_check("provocation : le monstre rejoint la doublure", mob.position.distance_to(se.global_position) < d0 * 0.5, "%s -> %s" % [d0, mob.position.distance_to(se.global_position)])
	_check("provocation : la doublure encaisse, pas Rictus", se.hp < se.max_hp and _near(_player.hp, mob_hp0), "%s / %s" % [se.hp, _player.hp])
	mob.deactivate()
	mob.remove_from_group(&"enemies")
	Decoy.clear_all()
	await get_tree().process_frame
	_player.spells._remaining[4] = 0.0
	_player.spells.aim_override = Vector2(4.0 * U, 0)
	_player.hp = 50.0
	_check("relance", _player.spells.cast(4))
	_player.spells.aim_override = null
	_land_decoys()
	_player.hp = 50.0
	var on_east := _fake(Vector2(4.0 * U + 1.2 * U, 0))
	for d in Decoy.live:
		_check("minuteur 3 s", _near(d.life_s, 3.0))
		break
	for d in Decoy.live.duplicate():
		d.step(2.9)
	_check("pas d'explosion avant 3 s", Decoy.live.size() == 6 and on_east.taken.is_empty())
	for d in Decoy.live.duplicate():
		d.step(0.11)
	_check("toutes explosent à 3 s", Decoy.live.is_empty())
	_check("6 explosions à 2,4 u : 6 × coef 1,8", on_east.taken.size() == 6 and _near(on_east.total(), 6.0 * RictusKit.DECOY_COEF * BASE, 0.05), "%s %s" % [on_east.total(), on_east.taken])
	_check("+2 % PV une seule fois", _near(_player.hp, 50.0 + 0.02 * 95.0, 0.01), str(_player.hp))
	_player.spells._remaining[4] = 0.0
	on_east.taken.clear()
	_player.spells.aim_override = Vector2(4.0 * U, 0)
	_player.spells.cast(4)
	_player.spells.aim_override = null
	_land_decoys()
	for d in Decoy.live:
		if d.global_position.distance_to(on_east.global_position) < 1.0:
			d.take_damage(1000.0)
	_check("doublure tuée : explosion 60 % (1,08)", on_east.taken.size() >= 1 and _near(on_east.taken[0], RictusKit.DECOY_DEATH_FRAC * RictusKit.DECOY_COEF * BASE), str(on_east.taken))
	_check("les autres restent", Decoy.live.size() == 5, str(Decoy.live.size()))

	print("Lancer automatique (mobile)")
	_reset()
	var a_t := _fake(Vector2(3.0 * U, 0))
	_check("Saccade auto : rien sans couteau planté", not _kit.auto_cast_ok(3))
	_check("couteau auto : en main, cible à portée", _kit.auto_cast_ok(2))
	_throw_at(a_t)
	_check("Saccade auto : attend (planté depuis moins de 2 s)", not _kit.auto_cast_ok(3))
	_drive(1.9)
	_check("toujours en attente à 1,9 s", not _kit.auto_cast_ok(3))
	_drive(0.2)
	_check("part à 2,0 s de pose", _kit.auto_cast_ok(3))
	_reset()
	a_t = _fake(Vector2(3.0 * U, 0))
	_throw_at(a_t)
	a_t.global_position = Vector2(8.7 * U, 0)
	_check("(b) ficelé au-delà de 8,5 u : part", _kit.auto_cast_ok(3))
	a_t.global_position = Vector2(3.0 * U, 0)
	_kit.tours = 3
	_check("(e) 3 tours enroulés : part", _kit.auto_cast_ok(3))
	_kit.tours = 0
	_check("sans doublure ni tour, tôt : attend", not _kit.auto_cast_ok(3))
	_kit.knife.drop_at(a_t.global_position)
	_check("(c) couteau au sol : part", _kit.auto_cast_ok(3))
	_reset()
	_check("ultime auto : rien à portée de 3 u, pas de ficelé", not _kit.auto_cast_ok(4))
	var near3 := _fake(Vector2(2.0 * U, 0))
	_check("ultime auto : monstre à moins de 3 u", _kit.auto_cast_ok(4))
	near3.global_position = Vector2(6.0 * U, 0)
	_check("ultime auto : pas un monstre isolé à 6 u", not _kit.auto_cast_ok(4))
	_throw_at(near3)
	_check("ultime auto : ficelé isolé = non", not _kit.auto_cast_ok(4))
	_fake(near3.global_position + Vector2(20, 0))
	_fake(near3.global_position + Vector2(-20, 10))
	_check("ultime auto : ficelé entouré de 3 monstres", _kit.auto_cast_ok(4))
	_player.spells.auto_cast_enabled = true
	_reset()
	var auto_foe := _fake(Vector2(4.0 * U, 0))
	auto_foe.taken.clear()
	_player.spells.tick(DT)
	_check("auto-cast : le sort 2 part seul", not _kit.knife_in_hand())
	_player.spells.auto_cast_enabled = false

	print("Boucle bornée (hâte extrême)")
	_reset()
	_player.apply_stats({"crit_chance": -0.05, "cooldown_mult": 0.35})
	_player.spells._totals[3] = _player.spells._cooldown_of(_player.character.spells[2])
	var loop_foe := _fake(Vector2(4.0 * U, 0))
	var casts2 := 0
	var t_loop := 0.0
	while t_loop < 10.0:
		_player.spells._remaining[1] = 99.0
		if _player.spells.cast(2):
			casts2 += 1
		if not _player.spells.is_slot_blocked(3):
			_player.spells.cast(3)
		t_loop += _drive(DT)
	_check("Saccade à 1,05 s au mieux", _near(_player.spells._cooldown_of(_player.character.spells[2]), 1.05, 0.02), str(_player.spells._cooldown_of(_player.character.spells[2])))
	_check("boucle bornée par la recharge de la Saccade et le vol (<= 10 en 10 s à 4 u)", casts2 >= 3 and casts2 <= 10, str(casts2))
	loop_foe.taken.clear()
	_player.apply_stats({"crit_chance": -0.05, "cooldown_mult": 1.0})

	print("Levée (roulade du Montreur)")
	_reset()
	var wall_of_mobs: Array = []
	for y in [-30, 0, 30]:
		wall_of_mobs.append(_body(Vector2(96, y), 20.0, false))
	await _frames(2)
	_player.set_physics_process(true)
	_check("levée lancée", _player.dodge(Vector2.RIGHT))
	_check("masque sans la couche 3", (_player.collision_mask & 4) == 0 and (_player.collision_mask & 1) == 1)
	_check("invulnérable", _player.is_invulnerable())
	_check("sorts suspendus pendant la levée", _player.spells.is_slot_blocked(1) and _player.spells.is_slot_blocked(4))
	await _frames(8)
	_check("pantin soulevé", vis.position.y < -5.0, str(vis.position.y))
	await _frames(14)
	_player.set_physics_process(false)
	_check("passe au-dessus des monstres : 3 u", _near(_player.global_position.x, 3.0 * U, 3.0), str(_player.global_position))
	_check("retombé", not _kit.lifting and _near(vis.position.y, 0.0, 0.5), str(vis.position.y))

	print("Nettoyage (étage) et déblocage caché")
	_reset()
	var clean := _fake(Vector2(3.0 * U, 0))
	_throw_at(clean)
	_player.spells.cast(4)
	Events.floor_started.emit(2)
	await get_tree().process_frame
	_check("changement d'étage : doublures disparues", Decoy.live.is_empty())
	_check("changement d'étage : couteau rendu en main, ficelé effacé", _kit.knife_in_hand() and _kit.ficele_enemy() == null and _kit.knife == null)
	var prof: Node = load("res://scripts/save/profile.gd").new()
	prof.write_enabled = false
	prof.path = "user://rictus_test_profile.json" # jamais écrit (write_enabled faux)
	prof.open_characters = [] # configuration de sortie : Rictus non ouvert par characters.json
	var u1: Array = prof.add_run_result({"mode": &"moyen", "close_kills": 150})
	_check("150 tués au contact : pas encore", not prof.is_character_unlocked(&"rictus") and u1.is_empty())
	var u2: Array = prof.add_run_result({"mode": &"moyen", "close_kills": 60})
	_check("200 cumulés : Rictus débloqué", prof.is_character_unlocked(&"rictus") and u2.has(&"character:rictus"), str(u2))
	prof.free()
	_reset()
	Events.emit_enemy_killed(null, Vector2(1.5 * U, 0), 1, false)
	Events.emit_enemy_killed(null, Vector2(5.0 * U, 0), 1, false)
	_check("compteur rictus.close_kills : un tué à 1,5 u, pas un à 5 u", _near(float(RunState.counters.get("rictus.close_kills", 0.0)), 1.0), str(RunState.counters))

	print("Murs : un monstre derrière un mur plein n'est pas touché (StageMap.los)")
	_reset()
	var map := (load("res://scenes/stage/maps/foret_brume.tscn") as PackedScene).instantiate() as StageMap
	add_child(map)
	await get_tree().physics_frame
	var grid: Array = map._vis_grid
	var size_px: Vector2 = map.get_meta(&"size_u") * StageMap.UNIT_PX
	var cell := StageMap.OUTLINE_CELL_PX
	var found := Vector2i(-1, -1)
	for y in grid.size():
		var row: String = grid[y]
		for x in range(1, row.length() - 4):
			if row.substr(x, 3) == "..." and row[x + 3] == "#":
				found = Vector2i(x, y)
				break
		if found.x >= 0:
			break
	_check("cellule test trouvée", found.x >= 0)
	var to_g := func(cx: float, cy: float) -> Vector2:
		return map.to_global(map.from_map(-size_px * 0.5 + Vector2(cx, cy) * cell))
	_player.global_position = to_g.call(found.x + 2.5, found.y + 0.5)
	var hidden := _fake(to_g.call(found.x + 3.1, found.y + 0.5)) # dans la case du mur, tout près du couteau
	var seen := _fake(to_g.call(found.x + 2.6, found.y + 0.5))
	var probe := RictusPendulum.recall_light(_player.spells, _player, null, to_g.call(found.x + 2.9, found.y + 0.5), 100.0, RictusKit.KNIFE_FRAMES)
	_check("couteau : le monstre derrière le mur n'est pas touché", probe._enemy_at(false) == seen, str(probe._enemy_at(false)))
	seen.global_position = to_g.call(found.x + 0.5, found.y + 0.5)
	_check("couteau : rien d'autre à portée", probe._enemy_at(false) == null)
	probe.queue_free()
	_kit.kstate = RictusKit.K.PLANTED # ficelé derrière un mur : la scie et l'arrachement ne passent pas
	_kit.ficele = hidden
	_kit._saw_tick()
	_check("scie : pas de coup à travers le mur", hidden.taken.is_empty(), str(hidden.taken))
	_kit.kstate = RictusKit.K.HAND
	_kit.ficele = null
	map.queue_free()
	await get_tree().process_frame

	_reset()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame

	print("Partie réelle (main.tscn) avec Rictus : fumée")
	RunState.character = &"rictus"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 777) # sauvegardes coupées en headless (main._saves_enabled)
	get_tree().root.add_child(main)
	await _frames(120)
	var mp: Node = main.get(&"player")
	_check("joueur de la partie = Rictus", mp != null and mp.get(&"kit") is RictusKit)
	if mp != null and mp.get(&"kit") is RictusKit:
		mp.spells.cast(2)
		await _frames(30)
		mp.spells.cast(4)
		await _frames(200)
		mp.spells.cast(3)
		await _frames(100)
		_check("partie toujours en cours après couteau, doublures, Saccade", not bool(mp.get(&"dead")) or bool(main.get(&"run_over")))
	main.queue_free()
	await get_tree().process_frame
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
