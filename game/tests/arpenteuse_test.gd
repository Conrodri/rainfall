extends Node
## Test headless de l'Arpenteuse (docs/Design_Personnages.md §2.2, kit ArpenteuseKit) : stats, rendu (AR1/AR2),
## chaîne au sol (pose, plafond 14 u, rembobinage à l'arrêt, ticks de dégâts, ralentissement), Boucle (polygone,
## attraction, chaîne consommée, minimum), Piquet (ligne tendue, immunité, arrachage), Tendeur (claque, traîne,
## étourdit, rembobine), anims d'action et frames d'impact, lumières, nettoyage, partie réelle.
## godot --headless --path game res://tests/arpenteuse_test.tscn

## Cible factice : enregistre coups, statuts et poussées.
class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var pushes: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func push(v: Vector2) -> void:
		pushes.append(v)

	func is_slowed() -> bool:
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t

	func has_status(s: StringName) -> bool:
		for st in statuses:
			if st[0] == s:
				return true
		return false


const U := 64.0
const BASE := 12.0 ## Dégât_base niveau 1
const DT := 1.0 / 60.0

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


## Déplace le joueur en ligne droite jusqu'à `to` à `speed_u` u/s, en faisant tourner sa boucle.
func _walk(to: Vector2, speed_u := 4.2) -> void:
	var from := _player.global_position
	var d := from.distance_to(to)
	var n := maxi(int(ceil(d / (speed_u * U * DT))), 1)
	for i in n:
		_player.global_position = from.lerp(to, float(i + 1) / n)
		_player.tick(DT)


func _wait(seconds: float) -> void:
	var n := int(round(seconds / DT))
	for i in n:
		_player.tick(DT)


## Avance jusqu'à la frame d'impact du sort lancé. Retourne le temps écoulé.
func _to_impact() -> float:
	var t := 0.0
	while _kit.has_pending() and t < 1.5:
		_player.tick(DT)
		t += DT
	return t


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
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
	_kit.clear_transients()
	_kit._last_head = Vector2.ZERO
	_kit._tick_t = 0.0
	_kit._idle_t = 0.0
	_kit.chain_hits = 0
	_player.tick(DT)


func _run() -> void:
	RunState.level = 1
	RunState.character = &"arpenteuse"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false) # boucle pilotée par le test
	_kit = _player.kit

	print("Personnage, données et rendu")
	_check("kit Arpenteuse", _kit is ArpenteuseKit)
	var ids: Array = _player.get_spell_cooldowns().map(func(c): return String(c.id))
	_check("4 sorts / ids", ids == ["arpenteuse_chaine", "arpenteuse_boucle", "arpenteuse_piquet", "arpenteuse_tendeur"], str(ids))
	_check("PV L1 = 85", _near(_player.max_hp, 85.0), str(_player.max_hp))
	_check("armure 0", _near(_player.armor(), 0.0))
	_check("régén 1,0", _near(_player.regen_per_s(), 1.0))
	_check("vitesse 4,2 u/s", _near(_player.move_speed(), 4.2 * U), str(_player.move_speed()))
	RunState.level = 3
	_check("PV L3 = 85 + 2 × 25", _near(_player.character.max_hp_at(3), 135.0))
	RunState.level = 1
	var copper := true
	for sp in ArpenteuseKit.character().spells:
		copper = copper and String(sp.light_preset).begins_with("arpenteuse_") and LightRig.has_preset(sp.light_preset)
		_check("icône " + String(sp.id), ArdentKit.spell_icon(sp.id) != null)
	_check("lumières cuivre propres (jamais la braise d'Ardent)", copper)
	var pc: Variant = LightRig.get_preset(&"arpenteuse_chain").get("color", Color.BLACK)
	_check("preset cuivre #FF7A1F", (pc if pc is Color else Color(str(pc))).is_equal_approx(Color("#FF7A1F")), str(pc))
	var vis := _player.get_node("Visual") as AnimatedSprite2D
	_check("SpriteFrames AR1 branchées", vis.sprite_frames != null and vis.sprite_frames.has_animation(&"loop_s") and vis.sprite_frames.has_animation(&"whip_ne"))
	_check("chaîne : planche AR2 chargée", _kit.line != null and _kit.line.has_sheet and _kit.line.base.material is ShaderMaterial)
	_check("chaîne au sol (z sous les personnages)", _kit.fx_root.z_index < 0)

	print("Sort 1 : Chaîne (traîne)")
	_reset()
	_check("slot 1 jamais lancé par SpellCaster", not _player.spells.cast(1))
	_walk(Vector2(5 * U, 0))
	_check("5 u parcourus = 5 u de chaîne", _near(_kit.chain_length(), 5 * U, 2.0), str(_kit.chain_length() / U))
	_check("ressource = longueur / 14", _near(float(_kit.resource_state()["ratio"]), 5.0 / 14.0, 0.01) and _kit.resource_state()["id"] == &"chain")
	_walk(Vector2(5 * U, 12 * U))
	_check("plafond 14 u", _near(_kit.chain_length(), 14 * U, 2.0), str(_kit.chain_length() / U))
	_check("la queue suit le trajet (plus de point d'origine)", _kit.chain_points()[0].distance_to(Vector2.ZERO) > U)
	_check("ligne tracée sur la polyligne", _kit.line.base.points.size() >= 2 and _kit.line.visible)
	_wait(0.5)
	_check("arrêt bref : chaîne gardée", _near(_kit.chain_length(), 14 * U, 2.0))
	_wait(1.1)
	_check("immobile : le touret rembobine (≈ 4 u/s)", _kit.chain_length() < 12.0 * U and _kit.chain_length() > 8.0 * U, str(_kit.chain_length() / U))
	_wait(4.0)
	_check("immobile assez longtemps : plus de chaîne", _kit.chain_length() < 0.1 * U, str(_kit.chain_length() / U))

	_reset()
	var on := _fake(Vector2(3 * U, 10))
	var off := _fake(Vector2(3 * U, 1.5 * U))
	_kit._tick_t = -10.0 # pas de tick pendant la pose
	_walk(Vector2(6 * U, 0))
	_kit._tick_t = 0.0
	_wait(0.45)
	_check("pas de tick avant 0,5 s", on.taken.is_empty())
	_wait(0.1)
	_check("tick : coef 1,0 sur la chaîne", on.taken.size() == 1 and _near(on.total(), ArpenteuseKit.CHAIN_COEF * BASE), str(on.taken))
	_check("ralentit 35 %", on.has_status(&"slow") and _near(float(on.statuses[0][1]["pct"]), ArpenteuseKit.CHAIN_SLOW_PCT))
	_check("rien hors de la chaîne", off.taken.is_empty())
	_kit._idle_t = -99.0 # garde la chaîne (pas de rembobinage)
	_wait(0.5)
	_check("2 ticks : un monstre de base (18 PV) tombe", _near(on.total(), 2.0 * ArpenteuseKit.CHAIN_COEF * BASE), str(on.taken))
	_player.apply_stats({"crit_chance": -0.05, "attack_speed": 1.0})
	var n0: int = on.taken.size()
	_wait(0.55)
	_check("vitesse d'attaque : ticks plus rapides", on.taken.size() - n0 == 2, str(on.taken.size() - n0))

	print("Sort 2 : Halage (zone le long de la chaîne, chaîne conservée)")
	_reset()
	_walk(Vector2(2 * U, 0))
	_check("chaîne < 3 u : Boucle refusée, aucune recharge", not _player.spells.cast(2) and _player.spells._remaining[2] == 0.0)
	_reset()
	_kit._tick_t = -99.0
	_walk(Vector2(4 * U, 0))
	_walk(Vector2(4 * U, 4 * U))
	_walk(Vector2(0, 4 * U))
	var inside := _fake(Vector2(3.2 * U, 2 * U))
	var edge := _fake(Vector2(4 * U + 8, 2 * U))
	var outside := _fake(Vector2(8 * U, 2 * U))
	var _center := _fake(Vector2(2 * U, 2 * U))
	var len_before: float = _kit.chain_length()
	_check("Boucle lancée", _player.spells.cast(2))
	_check("anim d'action loop", String(_player.action_anim()).begins_with("loop"), str(_player.action_anim()))
	_check("effet en attente de la frame d'impact", _kit.has_pending() and inside.taken.is_empty())
	var ti := _to_impact()
	_check("impact à la frame 2 (≈ 0,17 s)", ti > 0.1 and ti < 0.25, str(ti))
	_check("à 0,8 u de la chaîne : coef 3,5", _near(inside.total(), ArpenteuseKit.BOUCLE_COEF * BASE), str(inside.taken))
	_check("sur la chaîne : touché", _near(edge.total(), ArpenteuseKit.BOUCLE_COEF * BASE), str(edge.taken))
	_check("au centre du U (2 u de la chaîne) et au loin : rien", outside.taken.is_empty() and _center.taken.is_empty())
	_check("attraction vers la chaîne (≤ 1,5 u)", edge.pushes.size() == 1 and edge.pushes[0].x < 0.0 and edge.pushes[0].length() <= 1.5 * U + 0.1, str(edge.pushes))
	_check("chaîne conservée", len_before > 11 * U and _near(_kit.chain_length(), len_before, 2.0), str(_kit.chain_length()))
	_check("recharge 6 s", _near(_player.spells._remaining[2], 6.0 - ti, 0.05), str(_player.spells._remaining[2]))
	_check("contour rendu (LoopFlare)", _kit.fx_root.get_node_or_null(^"LoopFlare") != null)

	print("Sort 3 : Piquet")
	_reset()
	var mid := _fake(Vector2(3 * U, 0))
	_player.spells.aim_override = Vector2(20 * U, 0)
	_check("Piquet lancé", _player.spells.cast(3))
	_check("anim d'action plant", String(_player.action_anim()).begins_with("plant"))
	_to_impact()
	_check("piquet à 6 u max", _kit.peg_active() and _near(_kit.peg_pos.x, 6 * U, 1.0), str(_kit.peg_pos))
	_check("piquet rendu (peg AR2)", _kit._peg_sprite != null and String(_kit._peg_sprite.animation).begins_with("peg_"))
	_player.tick(DT)
	_check("ligne tendue : coef 1,0", mid.taken.size() == 1 and _near(mid.taken[0], 1.0 * BASE), str(mid.taken))
	_wait(0.3)
	_check("immunité 0,5 s par monstre", mid.taken.size() == 1, str(mid.taken))
	_wait(ArpenteuseKit.PEG_IMMUNITY_S - 0.3 + 0.05)
	_check("puis nouveau coup", mid.taken.size() == 2, str(mid.taken))
	_wait(4.6)
	_check("piquet fini après 5 s", not _kit.peg_active())
	_reset()
	_player.spells.aim_override = Vector2(4 * U, 0)
	_player.spells.cast(3)
	_to_impact()
	_walk(Vector2(-7 * U, 0), 8.0)
	_check("trop loin (> 10 u) : piquet arraché", not _kit.peg_active())

	print("Sort 4 : Tendeur")
	_reset()
	_check("sans chaîne ni piquet : refusé", not _player.spells.cast(4))
	_kit._tick_t = -99.0
	_walk(Vector2(8 * U, 0))
	var near_link := _fake(Vector2(2 * U, 0.8 * U))
	var far_link := _fake(Vector2(2 * U, 2.0 * U))
	_check("Tendeur lancé", _player.spells.cast(4))
	_check("anim d'action whip", String(_player.action_anim()).begins_with("whip"))
	# Lot « ressenti » 30/10 : la frame d'impact du whip passe de 2 à 4 (smear avant, pose d'extension tenue 1,87 f) ; impact = 4 × 0,933 / 14 = 0,267 s.
	var tw := _to_impact()
	_check("impact à la frame 4 (whip : 8 frames, pose tenue, 4 frames courtes avant ≈ 0,27 s)", tw > 0.22 and tw < 0.32, str(tw))
	_check("claque : coef 10 à 1 u de la chaîne", _near(near_link.total(), 10.0 * BASE), str(near_link.taken))
	_check("rien au-delà de 1 u", far_link.taken.is_empty())
	_check("chaîne qui claque (planche snap)", _kit.line.sheet == &"snap" and _kit.is_rewinding())
	_wait(ArpenteuseKit.SNAP_S + 0.02)
	_check("traîné jusqu'à elle (reste à 1 u)", near_link.pushes.size() == 1 and _near((near_link.global_position + near_link.pushes[0]).distance_to(_player.global_position), U, 1.0), str(near_link.pushes))
	_check("étourdi 1 s (imprisoned)", near_link.has_status(&"imprisoned"))
	_check("chaîne conservée (pas de rembobinage)", _kit.chain_length() > 7.0 * U and not _kit.is_rewinding() and _kit.line.sheet == &"tile", str(_kit.chain_length()))
	_check("recharge 20 s", _player.spells._remaining[4] > 19.0)
	_reset()
	_player.spells.aim_override = Vector2(5 * U, 0)
	_player.spells.cast(3)
	_to_impact()
	_kit._tick_t = -99.0
	var on_peg := _fake(Vector2(2.5 * U, 0.9 * U))
	_kit._peg_hits[on_peg.get_instance_id()] = 1.0e9 # pas de coup de ligne : on isole le Tendeur
	_check("Tendeur avec seulement le piquet", _player.spells.cast(4))
	_to_impact()
	_check("la ligne du piquet claque aussi", _near(on_peg.total(), 10.0 * BASE), str(on_peg.taken))

	print("Nettoyage")
	_reset()
	_walk(Vector2(6 * U, 0))
	_player.spells.aim_override = Vector2(3 * U, 3 * U)
	_player.spells.cast(3)
	_to_impact()
	Events.floor_started.emit(2)
	await get_tree().process_frame
	_check("changement d'étage : chaîne et piquet coupés", _kit.chain_length() < 1.0 and not _kit.peg_active())
	_player.global_position = Vector2(60 * U, 0)
	_player.tick(DT)
	_check("saut de position : pas de segment géant", _kit.chain_length() < U)

	print("Statut `imprisoned` (Enemy, partagé avec Tocsin)")
	var real: Enemy = director.spawn_enemy(1, Vector2(20 * U, 0))
	real.apply_status(&"imprisoned", {"duration": ArpenteuseKit.TENDEUR_STUN_S})
	var p0 := real.global_position
	real.tick(0.1, _player, _player.global_position, Vector2.ZERO)
	_check("emprisonné : ne marche pas, ralenti", real.is_imprisoned() and real.is_slowed() and real.global_position.is_equal_approx(p0))
	real.push(Vector2(U, 0))
	real.tick(0.1, _player, _player.global_position, Vector2.ZERO)
	_check("emprisonné : traîné par un recul", real.global_position.x > p0.x + 1.0, str(real.global_position - p0))
	real.release_imprison(0.4, 2.0)
	_check("libéré : ralentissement de sortie", not real.is_imprisoned() and real.is_slowed())
	real.tick(1.5, _player, _player.global_position, Vector2.ZERO)
	real.apply_status(&"imprisoned", {"duration": 0.2})
	real.tick(0.3, _player, _player.global_position, Vector2.ZERO)
	_check("fin d'emprisonnement seule", not real.is_imprisoned())

	_reset()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame

	print("Partie réelle (main.tscn) avec l'Arpenteuse : fumée")
	RunState.character = &"arpenteuse"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 777)
	get_tree().root.add_child(main)
	await get_tree().create_timer(1.5).timeout
	var mp: Node = main.get(&"player")
	_check("joueur de la partie = Arpenteuse", mp != null and mp.get(&"kit") is ArpenteuseKit)
	if mp != null and mp.get(&"kit") is ArpenteuseKit:
		mp.spells.cast(3)
		mp.spells.cast(4)
		await get_tree().create_timer(1.5).timeout
		_check("partie toujours en cours", not bool(mp.get(&"dead")) or bool(main.get(&"run_over")))
	main.queue_free()
	await get_tree().process_frame
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
