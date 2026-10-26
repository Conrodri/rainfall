extends Node
## Test headless de Vigie (docs/Design_Personnages.md §2.8, docs/fiches/vigie.md) : stats, Tension (marche,
## ancrage, vitesse d'attaque, jauge, sauvegarde), 4 sorts (Behavior.KIT, effet à la frame d'impact), Trait
## d'allonge qui perce, Fusée (lumière, exposition), Filet (emprisonne, boss ralenti, Tension pleine),
## Grêle (délai, ticks, ralentit, expose), lumières, partie réelle.
## godot --headless --path game res://tests/vigie_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var mods: Array = []
	var is_boss := false

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func add_damage_taken_mod(id: Variant, mult: float, duration: float = -1.0) -> void:
		mods.append([id, mult, duration])

	func is_slowed() -> bool:
		return false

	func has_status(st: StringName) -> bool:
		for s in statuses:
			if s[0] == st:
				return true
		return false

	func exposed() -> bool:
		for m in mods:
			if m[0] == VigieKit.EXPOSE_ID and is_equal_approx(float(m[1]), VigieKit.EXPOSE_MULT):
				return true
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


class FakeBody extends StaticBody2D:
	var taken: Array = []
	var statuses: Array = []

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

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])


const U := 64.0
const BASE := 12.0

var _fails := 0
var _player: CharacterBody2D
var _kit: VigieKit
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


## Avance le joueur de `t` s (pas de 0,01 s), sort 1 suspendu sauf `auto`, immobile sauf `moving`.
func _advance(t: float, auto := false, moving := false) -> void:
	var n := roundi(t / 0.01)
	for i in n:
		if not auto:
			_player.spells._remaining[1] = 99.0
		_player.is_moving = moving
		_player.tick(0.01)
		for z in _kit.hails: # zones pilotées par le test (pas de _process en boucle manuelle)
			if is_instance_valid(z):
				z.set_process(false)
				z.step(0.01)
		for f in _kit.flares:
			if is_instance_valid(f):
				f.set_process(false)
				f.step(0.01)
	if not auto:
		_player.spells._remaining[1] = 0.0


## Attend que les projectiles de flèches posées (fusée, filet) aient fini leur course.
func _wait_projectiles(max_frames := 90) -> void:
	for i in max_frames:
		if _player.spells.active_projectile_count() == 0:
			return
		await get_tree().physics_frame


func _reset(tension: float = 0.0) -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.set_tension(tension)
	_kit.still_t = 0.0
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
	_player._dodge_cd = 0.0
	_player._dodge_left = 0.0
	_player._invuln = 0.0


func _flush() -> void:
	var t := 0.0
	while _kit.has_pending() and t < 1.2:
		_advance(0.01)
		t += 0.01


func _run() -> void:
	RunState.level = 1
	RunState.character = &"vigie"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as VigieKit

	print("Personnage et rendu")
	_check("kit Vigie", _kit != null)
	_check("chargée par CharacterData.for_id", CharacterData.for_id(&"vigie").kit_script == VigieKit)
	_check("4 sorts / ids", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["vigie_trait", "vigie_fusee", "vigie_filet", "vigie_grele"])
	_check("PV L1 = 90", _near(_player.max_hp, 90.0), str(_player.max_hp))
	_check("armure 0", _near(_player.armor(), 0.0))
	_check("régén 1", _near(_player.regen_per_s(), 1.0))
	_reset()
	_check("vitesse 4,2 u/s", _near(_player.move_speed(), 4.2 * U, 0.1), str(_player.move_speed()))
	var lights_ok := true
	for sp in VigieKit.character().spells + [VigieKit.make_allonge(), VigieKit.make_net_burst()]:
		lights_ok = lights_ok and String(sp.light_preset).begins_with("vigie_") and LightRig.has_preset(sp.light_preset)
		lights_ok = lights_ok and sp.behavior == SpellData.Behavior.KIT
	lights_ok = lights_ok and LightRig.has_preset(&"vigie_tension")
	_check("lumières vigie_* (rouge de détresse, jamais la braise), Behavior.KIT", lights_ok)
	var tinted := 0
	for h in LightRig._requests:
		if h.get_target() == _player and h.color_override.a > 0.0:
			tinted += 1
	_check("lumières du joueur teintées (pluie + mèche rouge)", tinted == 2, str(tinted))
	var cd := VigieKit.character()
	_check("frames d'impact déclarées (draw 4, flare 3, net 2, volley 4)", cd.action_impact_frames.get(&"draw") == 4 and cd.action_impact_frames.get(&"volley") == 4)
	_check("flèches : asset VG2 ou repli lame (jamais la braise)", cd.spells[0].projectile_frames != "" and ResourceLoader.exists(cd.spells[0].projectile_frames))
	_check("characters.json : entrée vigie (sorts, difficulté)", _json_entry_ok())

	print("Tension")
	_reset(0.0)
	_advance(1.5, false, true)
	_check("en marche : TENSION_MOVING_S pour la remplir", _near(_kit.tension, 1.5 / VigieKit.TENSION_MOVING_S, 0.02), str(_kit.tension))
	_reset(0.0)
	_advance(0.1)
	_check("immobile < 0,15 s : pas encore ancrée", not _kit.is_anchored())
	_advance(0.6)
	_check("ancrée : remplissage ×3", _kit.is_anchored() and _kit.tension > 0.5, str(_kit.tension))
	_advance(0.6)
	_check("pleine en ~1 s ancrée", _kit.is_full())
	var rs := KitResource.of(_player)
	_check("jauge KitResource « Tension », PRÊTE qui pulse", rs.get("id") == &"tension" and rs.get("text") == "PRÊTE" and rs.get("boost") == true, str(rs))
	_reset(0.0)
	_player.apply_stats({"crit_chance": -0.05, "attack_speed": 0.5})
	_advance(1.0, false, true)
	_check("vitesse d'attaque +50 % : remplissage ×1,5", _near(_kit.tension, 1.5 / VigieKit.TENSION_MOVING_S, 0.02), str(_kit.tension))
	_player.apply_stats({"crit_chance": -0.05, "attack_speed": 0.0})
	_kit.set_tension(0.42)
	var sv := _kit.save_state()
	_kit.set_tension(0.0)
	_kit.load_state(sv)
	_check("sauvegarde de la Tension", _near(_kit.tension, 0.42))

	print("Sort 1 : Trait")
	_reset(0.0)
	_check("sans ennemi : rien, pas de recharge", not _player.spells.cast(1) and _player.get_spell_cooldowns()[0].remaining == 0.0)
	var b1 := _body(Vector2(3 * U, 0))
	var b2 := _body(Vector2(5 * U, 0))
	var b3 := _body(Vector2(7 * U, 0))
	_check("trait lancé", _player.spells.cast(1))
	_check("anim d'action attack", _player.action_base() == &"attack", str(_player.action_base()))
	_check("tir en attente de la frame d'impact", _kit.has_pending() and _player.spells.active_projectile_count() == 0)
	_flush()
	_check("projectile parti à l'impact", _player.spells.active_projectile_count() == 1)
	await _frames(40)
	_check("coef 0,8, traverse 1 monstre (2 cibles, pas la 3e)", b1.taken.size() == 1 and _near(b1.taken[0], VigieKit.TRAIT_COEF * BASE, 0.05) and b2.taken.size() == 1 and b3.taken.is_empty(), "%s %s %s" % [b1.taken, b2.taken, b3.taken])

	print("Trait d'allonge (Tension pleine)")
	_reset(1.0)
	var line: Array = []
	for i in 4:
		line.append(_body(Vector2((2 + 2 * i) * U, 0)))
	_check("allonge lancée", _player.spells.cast(1))
	_check("Tension vidée au lancement", _near(_kit.tension, 0.0))
	var base_ok: bool = _player.action_base() == &"draw" or _player.action_base() == &"attack"
	_check("anim draw (ou attack en repli)", base_ok, str(_player.action_base()))
	_flush()
	await _frames(45)
	var all_hit := true
	for b in line:
		all_hit = all_hit and b.taken.size() == 1 and _near(b.taken[0], VigieKit.ALLONGE_COEF * BASE, 0.05)
	_check("perce toute la ligne à 2,0 (4 cibles jusqu'à 8 u)", all_hit, str(line.map(func(b): return b.taken)))
	_reset(0.0)
	_body(Vector2(11 * U, 0))
	_check("Trait normal : rien au-delà de 9 u", not _player.spells.cast(1))
	_kit.set_tension(1.0)
	_check("allonge : portée 12 u", _player.spells.cast(1))

	print("Sort 2 : Fusée de détresse")
	_reset()
	_player.spells.aim_override = Vector2(4 * U, 0)
	var lit := _fake(Vector2(5.5 * U, 0)) # 1,5 u de la fusée
	var dark := _fake(Vector2(4 * U, 4 * U)) # hors lumière (4 u)
	_check("fusée lancée", _player.spells.cast(2))
	_check("recharge 8 s", _near(_player.get_spell_cooldowns()[1].total, 8.0, 0.01))
	_flush()
	await _wait_projectiles()
	_check("fusée plantée au point visé", _kit.flares.size() == 1 and (_kit.flares[0] as Node2D).global_position.distance_to(Vector2(4 * U, 0)) < 0.5 * U, str(_kit.flares.map(func(f): return f.global_position)))
	_advance(0.3)
	_check("monstre dans la lumière : exposé (EXPOSE_MULT)", lit.exposed(), str(lit.mods))
	_check("monstre hors lumière : rien", not dark.exposed())
	_check("la fusée ne blesse pas (lumière seulement)", lit.taken.is_empty())
	_advance(5.2)
	_check("fusée éteinte après 5 s", _kit.flares.is_empty() or (_kit.flares[0] as VigieFlare).is_ending())
	_reset()
	var first := _body(Vector2(3 * U, 0))
	_player.spells.aim_override = Vector2(8 * U, 0)
	_player.spells.cast(2)
	_flush()
	await _wait_projectiles()
	_check("flèche-fusée : coef 1,2 au premier monstre, fusée plantée sur lui", first.taken.size() == 1 and _near(first.taken[0], VigieKit.FUSEE_COEF * BASE, 0.05) and _kit.flares.size() == 1 and (_kit.flares[0] as Node2D).global_position.distance_to(first.global_position) < 0.6 * U, str(first.taken))

	print("Sort 3 : Filet lesté")
	_reset(0.0)
	_player.spells.aim_override = Vector2(5 * U, 0)
	var n1 := _fake(Vector2(5 * U, 1.5 * U))
	var n2 := _fake(Vector2(6.5 * U, 0))
	var far := _fake(Vector2(5 * U, 4 * U))
	var boss := _fake(Vector2(4 * U, -1 * U))
	boss.is_boss = true
	_check("filet lancé", _player.spells.cast(3))
	_flush()
	await _wait_projectiles()
	_check("emprisonnés 1,5 s dans 3 u", n1.has_status(&"imprisoned") and n2.has_status(&"imprisoned") and not far.has_status(&"imprisoned"))
	_check("boss : ralenti, jamais emprisonné", boss.has_status(&"slow") and not boss.has_status(&"imprisoned"))
	_check("ouverture du filet coef 1,2", n1.taken.size() == 1 and _near(n1.taken[0], VigieKit.NET_COEF * BASE, 0.05), str(n1.taken))
	_check("Tension pleine après le filet", _kit.is_full())
	_kit.set_tension(0.2)
	_check("auto-cast : filet permis Tension basse", _kit.auto_cast_ok(3))
	_kit.set_tension(0.8)
	_check("auto-cast : filet gardé Tension haute", not _kit.auto_cast_ok(3))

	print("Filet : cercle de zone lisible pendant l'emprisonnement")
	_reset()
	_kit.open_net(Vector2(5 * U, 0))
	var nz: ZoneOutline = null
	for o in get_tree().get_nodes_in_group(&"zone_outlines"):
		if o is ZoneOutline and is_instance_valid(o.host) and o.host.name == "NetZone":
			nz = o
	_check("filet : ZoneOutline posé (rayon 3 u, durée = emprisonnement)", nz != null and _near(nz.radius, VigieKit.NET_RADIUS_U * U, 1.0) and _near(nz.life, VigieKit.NET_HOLD_S, 0.001))
	if nz != null:
		nz.step(0.5)
		_check("filet : contour épais, opaque, voile net, liseré sombre", nz.width >= 4.0 and nz.edge_alpha >= 0.9 and nz.fill_alpha >= 0.12 and nz.halo and nz.alpha_now() >= 0.8, str(nz.alpha_now()))
	print("Sort 4 : Grêle")
	_reset()
	_player.spells.aim_override = Vector2(6 * U, 0)
	var h1 := _fake(Vector2(6 * U, 2 * U))
	var h2 := _fake(Vector2(6 * U, 6 * U))
	_check("grêle lancée", _player.spells.cast(4))
	_check("recharge 20 s", _near(_player.get_spell_cooldowns()[3].total, 20.0, 0.01))
	_flush()
	_check("volée au ciel : rien tout de suite", _kit.hails.is_empty() and h1.taken.is_empty())
	_advance(0.5)
	_check("pluie tombée après 0,45 s au point visé", _kit.hails.size() == 1 and (_kit.hails[0] as Node2D).global_position.distance_to(Vector2(6 * U, 0)) < 2.0)
	var hz: ZoneOutline = ZoneOutline.of(_kit.hails[0])
	_check("grêle : contour ZoneOutline ambre appuyé (rayon 4,5 u, trait >= 4, alpha >= 0,9)", hz != null and hz.color.is_equal_approx(Color(VigieKit.ZONE_COLOR.r, VigieKit.ZONE_COLOR.g, VigieKit.ZONE_COLOR.b, 1.0)) and hz.halo and hz.width >= 4.0 and hz.edge_alpha >= 0.9 and _near(hz.radius, VigieKit.HAIL_RADIUS_U * U, 1.0))
	_check("grêle : couleur de contour de Vigie, pas le rouge de l'accent", ZoneOutline.color_for(VigieKit.character().spells[3]) == VigieKit.ZONE_COLOR and VigieKit.ZONE_COLOR != VigieKit.ACCENT)
	_advance(2.6)
	_check("≈ 11 volées à 0,7 sur la cible dedans", h1.taken.size() >= 10 and h1.taken.size() <= 12 and _near(h1.taken[0], VigieKit.GRELE_COEF * BASE, 0.05), "%d %s" % [h1.taken.size(), h1.taken.slice(0, 1)])
	_check("dedans : ralenti et exposé", h1.has_status(&"slow") and h1.exposed())
	_check("dehors : intact", h2.taken.is_empty() and not h2.exposed())
	_reset()
	_body(Vector2(20 * U, 0))
	_player.spells.aim_override = Vector2(30 * U, 0)
	_player.spells.cast(4)
	_flush()
	_advance(0.5)
	_check("portée limitée à 10 u", _kit.hails.size() == 1 and _near((_kit.hails[0] as Node2D).global_position.x, 10 * U, 2.0), str((_kit.hails[0] as Node2D).global_position if not _kit.hails.is_empty() else null))

	print("Nettoyage")
	_kit.plant_flare(Vector2.ZERO)
	Events.floor_started.emit(2)
	_check("changement d'étage : fusées et grêle retirées, Tension gardée", _kit.flares.is_empty() and _kit.hails.is_empty())
	_reset()
	_player.spells.aim_override = null

	print("Partie réelle (main.tscn) avec Vigie : fumée")
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame
	RunState.character = &"vigie"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 777)
	main.set(&"save_path", "user://test_vigie_run.json")
	get_tree().root.add_child(main)
	await _frames(120)
	var mp: Node = main.get(&"player")
	_check("joueur de la partie = Vigie", mp != null and mp.get(&"kit") is VigieKit)
	if mp != null and mp.get(&"kit") is VigieKit:
		mp.spells.cast(2)
		mp.spells.cast(3)
		await _frames(30)
		mp.spells.cast(4)
		await _frames(120)
		_check("partie toujours en cours après les 4 sorts", not bool(mp.get(&"dead")) or bool(main.get(&"run_over")))
	main.queue_free()
	await get_tree().process_frame
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _json_entry_ok() -> bool:
	var f := FileAccess.open("res://data/characters.json", FileAccess.READ)
	if f == null:
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Array):
		return false
	for c in d:
		if c is Dictionary and c.get("id") == "vigie":
			return (c.get("spells", []) as Array).size() == 4 and int(c.get("difficulty", 0)) == 1 and bool(c.get("unlocked", false))
	return false
