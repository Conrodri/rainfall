extends Node
## Test headless des variantes de sorts d'Arpenteuse (docs/Variantes_Sorts.md §2.5, CONTRACTS.md « Variantes de sorts ») :
## substitution par CharacterData.for_id, Chaîne lestée, Nœud, Jalons, Cerceau, compteurs (arpenteuse.boucle_hits /
## piquet_hits) et règles de déblocage de characters.json.
## godot --headless --path game res://tests/arpenteuse_variants_test.tscn  (scène : les autoloads doivent exister)

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

	func status_data(s: StringName) -> Dictionary:
		for st in statuses:
			if st[0] == s:
				return st[1]
		return {}


class FakeProfile extends RefCounted:
	var stats := {}
	var unlocked_spells: Array = []

	func stat(key: String) -> float:
		return float(stats.get(key, 0.0))


const VU := preload("res://scripts/save/variant_unlocks.gd")
const U := 64.0
const BASE := 12.0 ## Dégât_base niveau 1
const DT := 1.0 / 60.0
const LOADOUT := {1: &"arpenteuse_chaine_lestee", 2: &"arpenteuse_noeud", 3: &"arpenteuse_jalons", 4: &"arpenteuse_cerceau"}

var _fails := 0
var _player: CharacterBody2D
var _kit: ArpenteuseKit
var _junk: Array = []
var _director: Node2D


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


func _fake(pos: Vector2, boss := false) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	if boss:
		e.add_to_group("bosses")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _walk(to: Vector2, speed_u := 4.2) -> void:
	var from := _player.global_position
	var n := maxi(int(ceil(from.distance_to(to) / (speed_u * U * DT))), 1)
	for i in n:
		_player.global_position = from.lerp(to, float(i + 1) / n)
		_player.tick(DT)


func _wait(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_player.tick(DT)


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
			j.remove_from_group("bosses")
			j.queue_free()
	_junk.clear()
	_player.global_position = Vector2.ZERO
	_kit.clear_transients() # après la téléportation : chaîne coupée au point d'arrivée
	_player.velocity = Vector2.ZERO
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player._dodge_cd = 0.0
	_kit._last_head = Vector2.ZERO
	_kit._tick_t = -999.0 # pas de tick de chaîne parasite
	_kit._idle_t = -999.0 # pas de rembobinage
	_kit._probe_t = -1.0
	RunState.counters.clear()
	_player.tick(DT)


func _spawn_player(loadout: Dictionary) -> void:
	RunState.level = 1
	RunState.character = &"arpenteuse"
	RunState.loadout = loadout.duplicate()
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as ArpenteuseKit


func _drop_player() -> void:
	_reset()
	_player.queue_free()
	await get_tree().process_frame


func _run() -> void:
	# --- substitution (sans joueur) ---------------------------------------------------------------
	print("Substitution")
	var base_cd := CharacterData.for_id(&"arpenteuse", {})
	_check("sans loadout : sorts de base", base_cd.spells.map(func(s): return String(s.id)) == ["arpenteuse_chaine", "arpenteuse_boucle", "arpenteuse_piquet", "arpenteuse_tendeur"])
	var var_cd := CharacterData.for_id(&"arpenteuse", LOADOUT)
	_check("4 variantes substituées", var_cd.spells.map(func(s): return String(s.id)) == ["arpenteuse_chaine_lestee", "arpenteuse_noeud", "arpenteuse_jalons", "arpenteuse_cerceau"], str(var_cd.spells.map(func(s): return s.id)))
	_check("slots conservés, sort 1 auto", var_cd.spells.map(func(s): return s.slot) == [1, 2, 3, 4] and var_cd.spells[0].is_auto)
	_check("variant_of", var_cd.variant_of(2) == &"arpenteuse_noeud" and base_cd.variant_of(2) == &"")
	_check("variante inconnue : sort de base", CharacterData.for_id(&"arpenteuse", {2: &"arpenteuse_fantome"}).spells[1].id == &"arpenteuse_boucle")
	_check("variant() inconnue = null", ArpenteuseKit.variant(1, &"nope") == null and ArpenteuseKit.variant(2, &"arpenteuse_cerceau") == null)

	# --- characters.json / déblocage --------------------------------------------------------------
	print("characters.json et déblocage")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var declared := {}
	for c in data:
		if c is Dictionary and str(c.get("id", "")) == "arpenteuse":
			var spells_json: Array = c.get("spells", [])
			for i in spells_json.size():
				for v in spells_json[i].get("variants", []):
					declared[i + 1] = str(v.get("id", ""))
	_check("4 variantes déclarées, ids = ids codés", declared.size() == 4 and declared.get(1) == "arpenteuse_chaine_lestee" and declared.get(2) == "arpenteuse_noeud"
			and declared.get(3) == "arpenteuse_jalons" and declared.get(4) == "arpenteuse_cerceau", str(declared))
	var all_coded := true
	for slot in declared:
		all_coded = all_coded and ArpenteuseKit.variant(int(slot), StringName(declared[slot])) != null
	_check("chaque variante déclarée est codée", all_coded)
	var prof := FakeProfile.new()
	_check("Chaîne lestée : victoire", VU.evaluate(prof, data, {"victory": true, "character": "arpenteuse", "stage": 5}).has(&"spell:arpenteuse_chaine_lestee"))
	_check("Chaîne lestée : défaite = non", not VU.evaluate(prof, data, {"victory": false, "character": "arpenteuse", "stage": 3}).has(&"spell:arpenteuse_chaine_lestee"))
	prof.stats["arpenteuse.boucle_hits"] = 499.0
	_check("Nœud : 499 = non", not VU.evaluate(prof, data, {"character": "arpenteuse", "stage": 1}).has(&"spell:arpenteuse_noeud"))
	prof.stats["arpenteuse.boucle_hits"] = 500.0
	_check("Nœud : 500", VU.evaluate(prof, data, {"character": "arpenteuse", "stage": 1}).has(&"spell:arpenteuse_noeud"))
	prof.stats["arpenteuse.piquet_hits"] = 799.0
	_check("Jalons : 799 = non", not VU.evaluate(prof, data, {"character": "arpenteuse", "stage": 1}).has(&"spell:arpenteuse_jalons"))
	prof.stats["arpenteuse.piquet_hits"] = 800.0
	_check("Jalons : 800", VU.evaluate(prof, data, {"character": "arpenteuse", "stage": 1}).has(&"spell:arpenteuse_jalons"))
	_check("Cerceau : étage 2 = non", not VU.evaluate(prof, data, {"character": "arpenteuse", "stage": 2}).has(&"spell:arpenteuse_cerceau"))
	_check("Cerceau : étage 3", VU.evaluate(prof, data, {"character": "arpenteuse", "stage": 3}).has(&"spell:arpenteuse_cerceau"))
	_check("Cerceau : autre personnage = non", not VU.evaluate(prof, data, {"character": "rictus", "stage": 3}).has(&"spell:arpenteuse_cerceau"))

	# --- en jeu : 4 variantes ---------------------------------------------------------------------
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	await _spawn_player(LOADOUT)
	print("Joueur avec variantes")
	_check("kit Arpenteuse", _kit != null)
	_check("sorts du joueur = variantes", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["arpenteuse_chaine_lestee", "arpenteuse_noeud", "arpenteuse_jalons", "arpenteuse_cerceau"])

	print("Sort 1 : Chaîne lestée")
	_reset()
	_walk(Vector2(10 * U, 0))
	_check("plafond 7 u", _near(_kit.chain_length(), 7 * U, 2.0), str(_kit.chain_length() / U))
	_check("ressource = longueur / 7", _near(float(_kit.resource_state()["ratio"]), 1.0, 0.01))
	_kit._tick_t = 0.0
	var on := _fake(Vector2(7 * U, 10))
	var off := _fake(Vector2(7 * U, 0.55 * U)) # hors de la demi-largeur 0,3 u
	_wait(0.55)
	_check("tick : coef 2,0", on.taken.size() == 1 and _near(on.total(), 2.0 * BASE), str(on.taken))
	_check("ralentit 50 %", on.has_status(&"slow") and _near(float(on.status_data(&"slow")["pct"]), 0.5))
	_check("rien hors de la chaîne", off.taken.is_empty())
	_kit._idle_t = 0.0
	_wait(1.0 + ArpenteuseKit.CHAIN_IDLE_S)
	_check("rembobinage 8 u/s (plus rapide que 4)", _kit.chain_length() < 3.2 * U, str(_kit.chain_length() / U))

	print("Sort 2 : Nœud")
	_reset()
	_walk(Vector2(3 * U, 0))
	_check("chaîne < 4 u : refusé, sans recharge", not _player.spells.cast(2) and _player.spells._remaining[2] == 0.0)
	_reset()
	_walk(Vector2(7 * U, 0))
	# chaîne lestée : 7 u, de x = 0 à 7 u ; queue = x 0 à 4 u, centroïde ≈ (2 u ; 0)
	var in1 := _fake(Vector2(1.5 * U, 0.8 * U))
	var in2 := _fake(Vector2(2.4 * U, -0.9 * U))
	var boss := _fake(Vector2(2.0 * U, 0.2 * U), true)
	var far_on_chain := _fake(Vector2(6.5 * U, 0.0)) # sur la chaîne mais hors du nœud
	var out := _fake(Vector2(2.0 * U, 2.6 * U))
	var len0: float = _kit.chain_length()
	_check("auto-cast : monstres pris -> ok", _kit.auto_cast_ok(2))
	_check("Nœud lancé", _player.spells.cast(2))
	_check("anim loop", String(_player.action_anim()).begins_with("loop"))
	var ti := _to_impact()
	_check("impact (≈ 0,17 s)", ti > 0.1 and ti < 0.25, str(ti))
	_check("4 u consommés", _near(len0 - _kit.chain_length(), 4 * U, 3.0), str((len0 - _kit.chain_length()) / U))
	_check("se resserre 0,25 s : rien encore", in1.taken.is_empty() and _kit.knot_left > 0.0)
	_wait(0.3)
	_check("disque 2 u : coef 3,5, emprisonné 1 s", _near(in1.total(), 3.5 * BASE) and _near(in2.total(), 3.5 * BASE)
			and in1.has_status(&"imprisoned") and _near(float(in1.status_data(&"imprisoned")["duration"]), 1.0), str(in1.taken))
	_check("aucune attraction", in1.pushes.is_empty())
	_check("boss : touché, ralenti 40 %, pas emprisonné", boss.taken.size() == 1 and boss.has_status(&"slow") and not boss.has_status(&"imprisoned")
			and _near(float(boss.status_data(&"slow")["pct"]), 0.4))
	_check("hors du nœud : rien", far_on_chain.taken.is_empty() and out.taken.is_empty())
	_check("recharge 6 s", _near(_player.spells._remaining[2], 6.0 - ti - 0.3, 0.1), str(_player.spells._remaining[2]))
	_reset()
	_walk(Vector2(7 * U, 0))
	_kit._probe_t = -1.0
	_check("auto-cast sans monstre : non", not _kit.auto_cast_ok(2))

	print("Sort 3 : Jalons")
	_reset()
	var mid := _fake(Vector2(6 * U + 8, 3 * U))
	_player.spells.aim_override = Vector2(20 * U, 0)
	_check("1re pression : piquet A lancé", _player.spells.cast(3))
	_to_impact()
	_check("A à 6 u max", _near(_kit.jal_a.x, 6 * U, 1.0) and _kit.jal_stage == 1, str(_kit.jal_a))
	_player.tick(DT)
	_check("sort encore prêt pour la 2e pression", _player.spells._remaining[3] == 0.0 and not _kit.jal_line)
	_check("2e pression trop tôt (< 0,6 s) : refusée", not _player.spells.cast(3))
	_wait(0.6)
	_player.spells.aim_override = Vector2(6 * U, 6 * U)
	_check("2e pression : piquet B", _player.spells.cast(3))
	_to_impact()
	_check("ligne A-B tendue, B à 6 u de A", _kit.jal_line and _near(_kit.jal_b.distance_to(_kit.jal_a), 6 * U, 2.0), str(_kit.jal_b))
	_check("recharge 8 s après B", _player.spells._remaining[3] > 7.5, str(_player.spells._remaining[3]))
	_kit._jal_hits.clear()
	_player.tick(DT)
	_check("ligne : coef 1,0 au passage", mid.taken.size() >= 1 and _near(mid.taken[0], BASE), str(mid.taken))
	var n0 := mid.taken.size()
	_wait(0.3)
	_check("immunité 0,5 s", mid.taken.size() == n0)
	_wait(0.25)
	_check("puis nouveau coup", mid.taken.size() == n0 + 1)
	_walk(Vector2(-10 * U, 0), 6.0)
	_player.tick(DT)
	_check("indépendante de sa position (piquets restent)", _kit.jal_line and not _kit.peg_active())
	_wait(5.0)
	_check("ligne finie après 6 s", not _kit.jal_line)
	_check("compteur piquet_hits : seul le Piquet de base compte", float(RunState.counters.get("arpenteuse.piquet_hits", 0.0)) == 0.0)
	_reset()
	_player.spells.aim_override = Vector2(4 * U, 0)
	_player.spells.cast(3)
	_to_impact()
	_wait(3.1)
	_check("sans 2e pression : B à 4 u de A", _kit.jal_line and _near(_kit.jal_b.distance_to(_kit.jal_a), 4 * U, 2.0), str(_kit.jal_b.distance_to(_kit.jal_a) / U))
	_check("recharge 8 s après la pose auto de B", _player.spells._remaining[3] > 7.5, str(_player.spells._remaining[3]))
	_reset()
	_player.spells.aim_override = Vector2(4 * U, 0)
	_player.spells.cast(3)
	_to_impact()
	_wait(0.7)
	_player.spells.aim_override = Vector2(4 * U + 10, 0) # B trop près : fil allongé à 6 u
	_player.spells.cast(3)
	_to_impact()
	_check("B trop près : fil allongé à 6 u", _near(_kit.jal_b.distance_to(_kit.jal_a), 6 * U, 2.0), str(_kit.jal_b.distance_to(_kit.jal_a) / U))
	var old_a: Vector2 = _kit.jal_a
	_player.spells._remaining[3] = 0.0
	_player.spells.aim_override = Vector2(-4 * U, 0)
	_check("un nouveau jalon remplace l'ancien", _player.spells.cast(3) and not _kit.jal_line)
	_to_impact()
	_check("nouveau A planté ailleurs", _kit.jal_a.distance_to(old_a) > U)

	print("Sort 4 : Cerceau")
	_reset()
	_check("sans chaîne ni piquet : refusé", not _player.spells.cast(4))
	_walk(Vector2(3 * U, 0))
	var c0 := _player.global_position
	var r_in := _fake(c0 + Vector2(3 * U, 0))
	var r_edge := _fake(c0 + Vector2(0, 3.4 * U))
	var r_out := _fake(c0 + Vector2(5 * U, 0))
	var r_inner := _fake(c0 + Vector2(1.0 * U, 0))
	_check("Cerceau lancé (chaîne ≥ 2 u)", _player.spells.cast(4))
	_check("anim whip", String(_player.action_anim()).begins_with("whip"))
	_to_impact()
	_check("anneau en cours 4 s", _kit.ring_left > 3.7, str(_kit.ring_left))
	_check("anneau rendu (41 points)", _kit.line.base.points.size() == ArpenteuseKit.CERCEAU_POINTS + 1, str(_kit.line.base.points.size()))
	_check("recharge 20 s", _player.spells._remaining[4] > 19.0)
	_check("Nœud refusé pendant le Cerceau", not _player.spells.cast(2))
	_wait(4.1)
	_check("anneau fini", _kit.ring_left <= 0.0)
	var n_in := r_in.taken.size()
	_check("7-8 coups dans la bande (1 par 0,5 s)", n_in >= 7 and n_in <= 8, str(n_in))
	_check("coef 1,15 par coup", _near(r_in.total(), float(n_in) * ArpenteuseKit.CERCEAU_COEF * BASE), str(r_in.taken))
	_check("bande 2,5-3,5 u : bord touché", r_edge.taken.size() == n_in)
	_check("hors bande (5 u et 1 u) : rien", r_out.taken.is_empty() and r_inner.taken.is_empty())
	_check("la chaîne retombe pleine (7 u)", _near(_kit.chain_length(), 7 * U, 0.7 * U), str(_kit.chain_length() / U))
	_reset()
	_walk(Vector2(3 * U, 0))
	var grass := _fake(Vector2(3 * U, 0.1 * U)) # sur la chaîne, au sol : pas de tick de sort 1 pendant l'anneau
	_kit._tick_t = 0.0
	_player.spells.cast(4)
	_to_impact()
	var before := grass.taken.size()
	_wait(1.0)
	_check("pendant l'anneau : la chaîne au sol ne frappe plus", grass.taken.size() == before, str(grass.taken))
	await _drop_player()

	# --- base : compteurs, Tendeur sur la ligne des Jalons ------------------------------------------
	await _spawn_player({3: &"arpenteuse_jalons"})
	print("Base : Halage et compteurs")
	_reset()
	_walk(Vector2(4 * U, 0))
	_walk(Vector2(4 * U, 4 * U))
	var h1 := _fake(Vector2(5 * U, 2 * U))
	var h2 := _fake(Vector2(3.5 * U, 2 * U))
	_check("Halage de base lancé", _player.spells.cast(2))
	_to_impact()
	_check("compteur arpenteuse.boucle_hits = monstres pris", float(RunState.counters.get("arpenteuse.boucle_hits", 0.0)) >= 1.0 and h1.taken.size() + h2.taken.size() >= 1, str(RunState.counters))
	print("Tendeur sur la ligne des Jalons")
	_reset()
	_player.spells.aim_override = Vector2(4 * U, 0)
	_player.spells.cast(3)
	_to_impact()
	_wait(0.7)
	_player.spells.aim_override = Vector2(4 * U, 6 * U)
	_player.spells.cast(3)
	_to_impact()
	var tl := _fake(Vector2(4 * U + 20, 3 * U))
	_kit._jal_hits[tl.get_instance_id()] = 1.0e9 # pas de coup de ligne : on isole le Tendeur
	_check("Tendeur avec seulement la ligne A-B", _player.spells.cast(4))
	_to_impact()
	_check("claque aussi sur la ligne A-B", _near(tl.total(), 10.0 * BASE), str(tl.taken))
	await _drop_player()
	await _spawn_player({})
	print("Base : Piquet compte ses coups")
	_reset()
	var pk := _fake(Vector2(3 * U, 0))
	_player.spells.aim_override = Vector2(6 * U, 0)
	_player.spells.cast(3)
	_to_impact()
	_player.tick(DT)
	_check("compteur arpenteuse.piquet_hits", float(RunState.counters.get("arpenteuse.piquet_hits", 0.0)) == 1.0 and pk.taken.size() == 1, str(RunState.counters))
	await _drop_player()
	_director.queue_free()
	await get_tree().process_frame
	RunState.loadout = {}
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
