extends Node
## Test headless des variantes de sorts d'Averse (docs/Variantes_Sorts.md §2.4, CONTRACTS.md « Variantes de sorts ») :
## substitution par CharacterData.for_id, lancer et dégâts de chacune (Bruine, Geyser, Gouttière, Mousson), eau,
## compteurs de déblocage (trempés, eau de Flaque, Crues pleines), pas de boucle Mousson -> Mousson, règles
## de déblocage de characters.json.
## godot --headless --path game res://tests/averse_variants_test.tscn  (scène : les autoloads doivent exister)

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var is_boss := false
	var is_elite := false
	var visual: Node2D = null

	func _init() -> void:
		visual = Node2D.new()
		add_child(visual)

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

	func imprisoned_s() -> float:
		for s in statuses:
			if s[0] == &"imprisoned":
				return float(s[1]["duration"])
		return 0.0


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


## Profil factice : compteurs cumulés et variantes possédées.
class FakeProfile extends RefCounted:
	var stats := {}
	var unlocked_spells: Array = []

	func stat(key: String) -> float:
		return float(stats.get(key, 0.0))


const VU := preload("res://scripts/save/variant_unlocks.gd")
const U := 64.0
const BASE := 12.0 ## Dégât_base niveau 1
const LOADOUT := {1: &"averse_bruine", 2: &"averse_geyser", 3: &"averse_gouttiere", 4: &"averse_mousson"}

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


func _body(pos: Vector2) -> FakeBody:
	var b := FakeBody.new()
	b.add_to_group("enemies")
	get_tree().root.add_child(b)
	b.global_position = pos
	_junk.append(b)
	return b


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Avance le joueur de `t` s (pas de 0,01 s), sort 1 suspendu ; les zones et ruisseaux sont pilotés à la main.
func _advance(t: float) -> void:
	var n := roundi(t / 0.01)
	for i in n:
		_player.spells._remaining[1] = 99.0
		_player.tick(0.01)
		for z in _kit.puddles + _kit.monsoons + _kit.rivulets:
			if is_instance_valid(z):
				z.set_process(false)
				z.step(0.01)
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
	_kit._rain_mult = 0.0 # pas de pluie : les gains d'eau mesurés sont ceux des sorts
	_kit._rain_t = 99.0
	_kit._auto_budget = AverseKit.AUTO_BUDGET_START
	_kit._soaked_until.clear()
	_kit._lock_left = 0.0
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
	RunState.counters.clear()


func _counter(key: String) -> float:
	return float(RunState.counters.get(key, 0.0))


func _run() -> void:
	# --- substitution (sans joueur) ---------------------------------------------------------------
	print("Substitution")
	var base_cd := CharacterData.for_id(&"averse", {})
	_check("sans loadout : sorts de base", base_cd.spells.map(func(s): return String(s.id)) == ["goutte_lame", "vague", "flaque_miroir", "crue"])
	_check("sans loadout : variant_of vide", base_cd.variant_of(1) == &"" and base_cd.variant_of(4) == &"")
	var var_cd := CharacterData.for_id(&"averse", LOADOUT)
	_check("4 variantes substituées (ids)", var_cd.spells.map(func(s): return String(s.id)) == ["averse_bruine", "averse_geyser", "averse_gouttiere", "averse_mousson"], str(var_cd.spells.map(func(s): return s.id)))
	_check("slots conservés", var_cd.spells.map(func(s): return s.slot) == [1, 2, 3, 4])
	_check("variant_of(slot)", var_cd.variant_of(1) == &"averse_bruine" and var_cd.variant_of(2) == &"averse_geyser"
			and var_cd.variant_of(3) == &"averse_gouttiere" and var_cd.variant_of(4) == &"averse_mousson")
	_check("slot 1 reste auto, Behavior.KIT partout", var_cd.spells[0].is_auto and var_cd.spells.all(func(s): return s.behavior == SpellData.Behavior.KIT))
	var mix_cd := CharacterData.for_id(&"averse", {3: &"averse_gouttiere"})
	_check("substitution partielle : seul le slot 3", mix_cd.spells[0].id == &"goutte_lame" and mix_cd.spells[2].id == &"averse_gouttiere" and mix_cd.spells[3].id == &"crue")
	_check("variante inconnue : sort de base", CharacterData.for_id(&"averse", {1: &"averse_fantome"}).spells[0].id == &"goutte_lame")
	_check("variant() inconnue = null", AverseKit.variant(1, &"nope") == null and AverseKit.variant(2, &"averse_bruine") == null)
	_check("variant_spell (fiche) rend un nouveau SpellData",
			CharacterData.variant_spell(&"averse", 2, &"averse_geyser", true) != CharacterData.variant_spell(&"averse", 2, &"averse_geyser", true))
	var bru := var_cd.spells[0]
	_check("Bruine : 3 gouttes, éventail 30°, 7 u, sans traversée, proc 0,6",
			bru.count == 3 and _near(bru.spread_deg, 30.0) and _near(bru.range_u, 7.0) and bru.pierce == 0 and _near(bru.proc_coef, 0.6))
	var gey := var_cd.spells[1]
	_check("Geyser : coef 3,5, rayon 2 u, portée 6 u, sans recharge", _near(gey.coef, 3.5) and _near(gey.radius_u, 2.0) and _near(gey.range_u, 6.0) and gey.base_cooldown == 0.0)
	var gou := var_cd.spells[2]
	_check("Gouttière : recharge 5 s, 6 s, tick 0,5 s", _near(gou.base_cooldown, 5.0) and _near(gou.duration, 6.0) and _near(gou.tick, 0.5))
	var mou := var_cd.spells[3]
	_check("Mousson : rayon 5 u, 6 s, recharge de la Crue", _near(mou.radius_u, 5.0) and _near(mou.duration, 6.0) and _near(mou.base_cooldown, AverseKit.CRUE_CD))

	# --- characters.json ---------------------------------------------------------------------------
	print("characters.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var ch_json: Dictionary = {}
	for c in data:
		if c is Dictionary and str(c.get("id", "")) == "averse":
			ch_json = c
	var declared := {}
	var spells_json: Array = ch_json.get("spells", [])
	for i in spells_json.size():
		for v in spells_json[i].get("variants", []):
			declared[i + 1] = str(v.get("id", ""))
	_check("4 variantes déclarées (une par slot)", declared.size() == 4, str(declared))
	_check("ids déclarés = ids codés", declared.get(1) == "averse_bruine" and declared.get(2) == "averse_geyser"
			and declared.get(3) == "averse_gouttiere" and declared.get(4) == "averse_mousson", str(declared))
	var all_coded := true
	for slot in declared:
		all_coded = all_coded and AverseKit.variant(int(slot), StringName(declared[slot])) != null
	_check("chaque variante déclarée est codée", all_coded)

	# --- règles de déblocage -----------------------------------------------------------------------
	print("Déblocage")
	var chars: Array = data
	var prof := FakeProfile.new()
	var win := {"victory": true, "character": "averse", "mode": "moyen", "stage": 5}
	_check("Bruine : victoire avec Averse", VU.evaluate(prof, chars, win).has(&"spell:averse_bruine"))
	_check("Bruine : pas de victoire", not VU.evaluate(prof, chars, {"victory": false, "character": "averse", "stage": 2}).has(&"spell:averse_bruine"))
	_check("Bruine : victoire d'un autre personnage", not VU.evaluate(prof, chars, {"victory": true, "character": "rictus", "stage": 5}).has(&"spell:averse_bruine"))
	prof.stats["averse.soaked"] = 999.0
	_check("Geyser : 999 trempés = non", not VU.evaluate(prof, chars, {"character": "averse", "stage": 1}).has(&"spell:averse_geyser"))
	prof.stats["averse.soaked"] = 1000.0
	_check("Geyser : 1 000 trempés", VU.evaluate(prof, chars, {"character": "averse", "stage": 1}).has(&"spell:averse_geyser"))
	prof.stats["averse.puddle_water"] = 1499.0
	_check("Gouttière : 1 499 d'eau = non", not VU.evaluate(prof, chars, {"character": "averse", "stage": 1}).has(&"spell:averse_gouttiere"))
	prof.stats["averse.puddle_water"] = 1500.0
	_check("Gouttière : 1 500 d'eau", VU.evaluate(prof, chars, {"character": "averse", "stage": 1}).has(&"spell:averse_gouttiere"))
	prof.stats["averse.full_crues"] = 4.0
	_check("Mousson : 4 Crues pleines = non", not VU.evaluate(prof, chars, {"character": "averse", "stage": 1}).has(&"spell:averse_mousson"))
	prof.stats["averse.full_crues"] = 5.0
	_check("Mousson : 5 Crues pleines", VU.evaluate(prof, chars, {"character": "averse", "stage": 1}).has(&"spell:averse_mousson"))
	prof.unlocked_spells = [&"averse_mousson"]
	_check("variante déjà possédée : pas ré-annoncée", not VU.evaluate(prof, chars, {"character": "averse", "stage": 1}).has(&"spell:averse_mousson"))

	# --- en jeu : joueur avec les 4 variantes ------------------------------------------------------
	RunState.level = 1
	RunState.character = &"averse"
	RunState.loadout = LOADOUT.duplicate()
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false) # boucle pilotée par le test
	_kit = _player.kit
	print("Joueur avec variantes")
	_check("kit Averse", _kit is AverseKit)
	_check("sorts du joueur = variantes", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["averse_bruine", "averse_geyser", "averse_gouttiere", "averse_mousson"], str(_player.get_spell_cooldowns().map(func(c): return c.id)))
	_check("variant_of côté nœud", _player.character.variant_of(3) == &"averse_gouttiere")

	print("Sort 1 : Bruine")
	_reset()
	_check("sans ennemi : rien, pas de recharge", not _player.spells.cast(1) and _player.get_spell_cooldowns()[0].remaining == 0.0)
	var b0 := _body(Vector2(3.0 * U, -0.8 * U))
	var b1 := _body(Vector2(3.0 * U, 0.0))
	var b2 := _body(Vector2(3.0 * U, 0.8 * U))
	_check("salve lancée", _player.spells.cast(1))
	_check("tir en attente de la frame d'impact", _kit.has_pending() and _player.spells.active_projectile_count() == 0)
	_kit.flush_pending()
	_check("3 gouttes en vol", _player.spells.active_projectile_count() == 3, str(_player.spells.active_projectile_count()))
	var dirs: Array = []
	var coef_ok := true
	for p in _player.spells._pool:
		if p.active:
			dirs.append(snappedf(rad_to_deg(p.direction.angle()), 0.1))
			coef_ok = coef_ok and _near(p.spell.coef, AverseKit.BRUINE_COEF_MIN + 0.5 * AverseKit.BRUINE_COEF_WATER, 0.001) and p.hits_left == 1
	dirs.sort()
	_check("éventail -15° / 0° / +15°", dirs.size() == 3 and _near(float(dirs[0]), -15.0, 0.2) and _near(float(dirs[1]), 0.0, 0.2) and _near(float(dirs[2]), 15.0, 0.2), str(dirs))
	_check("coef 0,30 + 0,15 × eau (0,375 à 50), 1 seul coup chacune", coef_ok)
	await _frames(40)
	var each := (AverseKit.BRUINE_COEF_MIN + 0.5 * AverseKit.BRUINE_COEF_WATER) * BASE
	_check("chaque cible touchée une fois", b0.taken.size() == 1 and b1.taken.size() == 1 and b2.taken.size() == 1, "%s %s %s" % [b0.taken, b1.taken, b2.taken])
	_check("dégâts = coef × base", b1.taken.size() == 1 and _near(b1.taken[0], each, 0.05), str(b1.taken))
	_check("eau : 3 touches plafonnées à +1,0 par salve", _near(_kit.water, 51.0, 0.01), str(_kit.water))
	_reset()
	var shot := AverseKit.variant(1, AverseKit.V_BRUINE)
	shot.set_meta(&"volley", {"gain": 0.0, "big": false})
	var normal := _fake(Vector2(500, 500))
	var elite := _fake(Vector2(500, 600))
	elite.is_elite = true
	for i in 3:
		_kit.on_spell_hit(shot, normal, 1.0)
	_check("salve en foule : +1,0 (×2 la Goutte-lame), pas plus", _near(_kit.water, 51.0, 0.01), str(_kit.water))
	_kit.on_spell_hit(shot, elite, 1.0)
	_check("élite touchée : bonus +BIG_HIT_WATER, une fois par salve", _near(_kit.water, 51.0 + AverseKit.BIG_HIT_WATER, 0.01), str(_kit.water))
	_kit.on_spell_hit(shot, elite, 1.0)
	_check("élite touchée une 2e fois dans la salve : rien de plus", _near(_kit.water, 51.0 + AverseKit.BIG_HIT_WATER, 0.01), str(_kit.water))
	var solo := AverseKit.variant(1, AverseKit.V_BRUINE)
	solo.set_meta(&"volley", {"gain": 0.0, "big": false})
	_reset()
	_kit.on_spell_hit(solo, normal, 1.0)
	_check("cible unique : +HIT_WATER (×1)", _near(_kit.water, 50.0 + AverseKit.HIT_WATER, 0.01), str(_kit.water))

	print("Sort 2 : Geyser")
	_reset(10.0)
	_check("bloqué sous 20 d'eau", _player.spells.is_slot_blocked(2) and not _player.spells.cast(2))
	_reset(60.0)
	var center := _fake(Vector2(3.0 * U, 0))
	var edge := _fake(Vector2(3.0 * U + 1.5 * U, 0)) # dans les 2 u
	var outside := _fake(Vector2(3.0 * U + 3.0 * U, 0))
	var boss := _fake(Vector2(3.0 * U, 1.0 * U))
	boss.is_boss = true
	_player.spells.aim_override = Vector2(3.0 * U, 0)
	_check("geyser lancé", _player.spells.cast(2))
	_check("20 d'eau payées au lancement", _near(_kit.water, 40.0, 0.01), str(_kit.water))
	_check("verrou anti-spam juste après", _kit.is_cast_locked() and _player.spells.is_slot_blocked(2))
	_check("anim d'action wave", _kit.action_for(_player.character.spells[1]) == &"wave")
	_kit.flush_pending()
	_check("télégraphe en cours : pas encore de dégâts", _kit.has_delayed() and center.taken.is_empty())
	_kit.flush_delayed()
	_check("coef 3,5 au centre", center.taken.size() == 1 and _near(center.total(), AverseKit.GEYSER_COEF * BASE, 0.05), str(center.taken))
	_check("rayon 2 u : bord touché, au-delà non", edge.taken.size() == 1 and outside.taken.is_empty(), "%s %s" % [edge.taken, outside.taken])
	_check("trempés (slow 30 % 4 s)", center.soaked() and edge.soaked() and not outside.soaked())
	_check("projetés 0,8 s (imprisoned)", _near(center.imprisoned_s(), 0.8) and _near(edge.imprisoned_s(), 0.8) and outside.imprisoned_s() == 0.0)
	_check("boss : dégâts et trempe, mais pas projeté", boss.taken.size() == 1 and boss.soaked() and boss.imprisoned_s() == 0.0)
	_check("2 monstres en l'air (le boss reste au sol)", _kit.lifted_count() == 2, str(_kit.lifted_count()))
	_check("compteur averse.soaked : 3 trempés (boss compris)", _near(_counter("averse.soaked"), 3.0), str(RunState.counters))
	_advance(0.4)
	_check("sommet de l'arc : Visual soulevé de lift_logical(1 u)", _near(center.visual.position.y, Iso.lift_logical(1.0), 4.0) and boss.visual.position.y == 0.0, str(center.visual.position.y))
	_advance(0.5)
	_check("retombé à 0,8 s : Visual au sol, plus rien en l'air", _near(center.visual.position.y, 0.0, 0.01) and _kit.lifted_count() == 0, str(center.visual.position.y))
	# re-trempe d'un monstre déjà trempé : pas recompté ; après la fin de la trempe : recompté
	_kit._geyser_burst(_player.character.spells[1], Vector2(3.0 * U, 0), 2.0 * U, null)
	_check("compteur : monstre déjà trempé non recompté", _near(_counter("averse.soaked"), 3.0), str(RunState.counters))
	_advance(4.2)
	_kit._geyser_burst(_player.character.spells[1], Vector2(3.0 * U, 0), 2.0 * U, null)
	_check("compteur : trempe expirée, recomptée", _near(_counter("averse.soaked"), 6.0), str(RunState.counters))
	_kit.clear_transients()
	_check("clear_transients repose les Visual", _near(center.visual.position.y, 0.0, 0.01) and _kit.lifted_count() == 0)
	_reset(60.0)
	var near6 := _fake(Vector2(6.0 * U, 0))
	var far8 := _fake(Vector2(8.5 * U, 0))
	_player.spells.aim_override = Vector2(10.0 * U, 0)
	_check("visée lointaine", _player.spells.cast(2))
	_kit.flush_pending()
	_kit.flush_delayed()
	_check("point visé limité à 6 u", near6.taken.size() == 1 and far8.taken.is_empty(), "%s %s" % [near6.taken, far8.taken])

	print("Sort 3 : Gouttière")
	_reset(30.0)
	var on_line := _fake(Vector2(3.0 * U, 0.3 * U))
	var side_e := _fake(Vector2(3.0 * U, 1.3 * U))
	var past := _fake(Vector2(7.0 * U, 0))
	_player.spells.aim_override = Vector2(5.0 * U, 0)
	_check("gouttière lancée", _player.spells.cast(3))
	_check("18 d'eau payées", _near(_kit.water, 12.0, 0.01), str(_kit.water))
	_check("recharge 5 s", _near(_player.spells._remaining[3], AverseKit.PUDDLE_CD, 0.3), str(_player.spells._remaining[3]))
	_check("anim d'action cast", _kit.action_for(_player.character.spells[2]) == &"cast")
	_kit.flush_pending()
	_check("un ruisseau posé", _kit.rivulets.size() == 1)
	var rv: AverseRivulet = _kit.rivulets[0]
	_check("ligne 6 u × 1 u depuis Averse vers le point visé", rv.contains(Vector2(5.9 * U, 0)) and not rv.contains(Vector2(6.5 * U, 0)) and rv.contains(Vector2(2.0 * U, 0.4 * U)) and not rv.contains(Vector2(2.0 * U, 1.2 * U)) and not rv.contains(Vector2(-0.5 * U, 0)))
	_check("premier tick : coef de la Gouttière sur la ligne seulement", on_line.taken.size() == 1 and _near(on_line.total(), AverseKit.GOUTTIERE_COEF * BASE, 0.05) and side_e.taken.is_empty() and past.taken.is_empty(), str(on_line.taken))
	_advance(0.55)
	_check("DoT toutes les 0,5 s", on_line.taken.size() == 2, str(on_line.taken))
	_check("trempe sur le ruisseau", on_line.soaked() and not side_e.soaked())
	_check("Averse sur le ruisseau (in_rivulet)", _kit.in_rivulet)
	var w1: float = _kit.water
	_advance(1.0)
	_check("sur le ruisseau : +PUDDLE_GAIN_PER_S d'eau/s", _near(_kit.water - w1, AverseKit.PUDDLE_GAIN_PER_S, 0.15), str(_kit.water - w1))
	_check("la Gouttière ne compte pas pour averse.puddle_water", _counter("averse.puddle_water") == 0.0)
	_kit.water = 100.0
	var spd: float = _kit.speed_mult()
	_check("vitesse ×1,25 sur le ruisseau (3,4 -> 4,25 u/s, amphore pleine)", _near(_player.move_speed(), 3.4 * 1.25 * U, 0.5) and _near(spd, 3.4 / 4.4 * 1.25, 0.001), str(_player.move_speed()))
	_player.global_position = Vector2(0, 5.0 * U)
	_advance(0.05)
	_check("hors du ruisseau : vitesse normale", not _kit.in_rivulet and _near(_player.move_speed(), 3.4 * U, 0.5))
	_player.global_position = Vector2.ZERO
	_check("auto-cast : pas de 2e gouttière tant qu'une vit", not _kit.auto_cast_ok(3))
	_kit.water = 60.0
	_player.spells._remaining[3] = 0.0
	_player.spells.aim_override = Vector2(0, 5.0 * U)
	_check("2e gouttière", _player.spells.cast(3))
	_kit.flush_pending()
	_kit._lock_left = 0.0
	_player.spells._remaining[3] = 0.0
	_check("3e gouttière", _player.spells.cast(3))
	_kit.flush_pending()
	_check("2 gouttières au plus (la plus ancienne s'assèche)", _kit.rivulets.size() == 2, str(_kit.rivulets.size()))
	_advance(6.5)
	_check("fin à 6 s", _kit.rivulets.is_empty() or _kit.rivulets.all(func(r): return not is_instance_valid(r) or r.is_ending()))

	print("Compteur : eau gagnée en Flaque-miroir")
	_reset(20.0)
	var base_puddle := AverseKit.character().spells[2]
	_kit.spawn_puddle(base_puddle, Vector2.ZERO)
	_advance(1.0)
	_check("averse.puddle_water = eau réellement gagnée", _near(_counter("averse.puddle_water"), AverseKit.PUDDLE_GAIN_PER_S, 0.15), str(RunState.counters))
	_kit.water = 100.0
	var pw: float = _counter("averse.puddle_water")
	_advance(1.0)
	_check("amphore pleine : rien de recompté", _near(_counter("averse.puddle_water"), pw, 0.001))

	print("Sort 4 : Mousson")
	_reset(100.0)
	var m_near := _fake(Vector2(2.0 * U, 0))
	var m_far := _fake(Vector2(6.0 * U, 0))
	_check("mousson lancée", _player.spells.cast(4))
	_check("vide toute l'amphore", _near(_kit.water, 0.0, 0.01), str(_kit.water))
	_check("anim d'action crue", _kit.action_for(_player.character.spells[3]) == &"crue")
	_check("recharge de la Crue", _near(_player.spells._remaining[4], AverseKit.CRUE_CD, 0.5), str(_player.spells._remaining[4]))
	_kit.flush_pending()
	_check("une zone attachée de 5 u", _kit.monsoons.size() == 1 and _near(float(_kit.monsoons[0].radius), 5.0 * U, 0.5))
	var per_tick: float = AverseKit.crue_coef(100.0) * AverseKit.MOUSSON_TOTAL_MULT / (AverseKit.MOUSSON_LIFE_S / AverseKit.MOUSSON_TICK_S + 1.0) * BASE
	_check("premier tick = total / (ticks + 1)", m_near.taken.size() == 1 and _near(m_near.taken[0], per_tick, 0.05) and m_far.taken.is_empty(), str(m_near.taken))
	_player.global_position = Vector2(10.0 * U, 0)
	_advance(0.05)
	_check("la zone suit Averse", _kit.monsoons[0].global_position.distance_to(_player.global_position) < 1.0)
	_player.global_position = Vector2.ZERO
	_advance(0.05)
	_kit._rain_mult = 1.0
	_advance(6.0)
	var total: float = m_near.total()
	# ticks +20 % sur trempés (AV-1) : borne haute x(CRUE_SOAK_MULT + 0,05)
	_check("dégâts totaux ≈ crue_coef(eau) × base sur 6 s (à ±10 %)", total >= AverseKit.crue_coef(100.0) * AverseKit.MOUSSON_TOTAL_MULT * BASE * 0.9 and total <= AverseKit.crue_coef(100.0) * AverseKit.MOUSSON_TOTAL_MULT * BASE * (AverseKit.CRUE_SOAK_MULT + 0.05), "%s / %s" % [total, AverseKit.crue_coef(100.0) * BASE])
	_check("trempe sur la zone", m_near.soaked())
	_check("eau rendue : ~18 d'eau + pluie, sous le seuil de relance (40)", _kit.water > 14.0 and _kit.water < AverseKit.CRUE_MIN, str(_kit.water))
	_check("pas de boucle Mousson -> Mousson : bloquée (eau) et en recharge", not _player.spells.cast(4) and _player.spells._remaining[4] > 0.0)
	_check("Mousson ne compte pas comme Crue pleine", _counter("averse.full_crues") == 0.0)
	_reset(40.0)
	_check("Mousson dès 40 d'eau", _kit.slot_affordable(4) and _player.spells.cast(4))
	_kit.flush_pending()
	_check("40 d'eau : zone posée", _kit.monsoons.size() == 1)

	print("Compteur : Crues pleines")
	_reset(100.0)
	var crue_spell := AverseKit.character().spells[3]
	_kit._crue(crue_spell, 98.9)
	_check("98,9 d'eau : pas une Crue pleine", _counter("averse.full_crues") == 0.0)
	_kit._crue(crue_spell, 99.0)
	_kit._crue(crue_spell, 100.0)
	_check("≥ 99 d'eau : +1 chacune", _near(_counter("averse.full_crues"), 2.0), str(RunState.counters))
	_check("la Crue laisse sa Flaque-miroir de base (jamais la Gouttière)", _kit.puddles.size() >= 1 and _kit.puddles[0].spell.id == &"flaque_miroir", str(_kit.puddles[0].spell.id if not _kit.puddles.is_empty() else "aucune"))

	_reset()
	_kit.clear_transients()
	for j in _junk:
		if is_instance_valid(j):
			j.queue_free()
	if _fails == 0:
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
