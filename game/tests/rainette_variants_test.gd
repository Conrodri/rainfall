extends Node
## Test headless des variantes de sorts de Rainette (docs/Variantes_Sorts.md §2.6, CONTRACTS.md « Variantes de sorts ») :
## substitution, déclaration dans characters.json, règles de déblocage, puis en jeu : Croassement (anneau, recharge du Grand saut raccourcie
## par les T1 tués), Ricochet (second bond automatique), Bulle (soulèvement puis éclatement), Chœur des
## roseaux (bonds normaux, mini-flaques plafonnées), compteurs de déblocage.
## godot --headless --path game res://tests/rainette_variants_test.tscn  (scène : les autoloads doivent exister)

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var pushed := Vector2.ZERO
	var stunned := 0.0
	var radius_px := 20.0
	var tier := 2
	var hp := 100000.0
	var active := true
	var is_boss := false

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)
		hp -= amount
		if hp <= 0.0:
			active = false

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func push(v: Vector2) -> void:
		pushed += v

	func stun(s: float) -> void:
		stunned = maxf(stunned, s)

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


class FakeProfile extends RefCounted:
	var stats := {}
	var unlocked_spells: Array = []

	func stat(key: String) -> float:
		return float(stats.get(key, 0.0))


const VU := preload("res://scripts/save/variant_unlocks.gd")
const U := 64.0
const BASE := 12.0
const DT := 1.0 / 60.0
const LOADOUT := {1: &"rainette_croassement", 2: &"rainette_ricochet", 3: &"rainette_bulle", 4: &"rainette_choeur"}

var _fails := 0
var _player: CharacterBody2D
var _kit: RainetteKit
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


func _fake(pos: Vector2, p_tier := 2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.tier = p_tier
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _advance(seconds: float, dir := Vector2.ZERO) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		_player.spells._remaining[1] = 99.0 # sort 1 suspendu : seuls les sorts lancés à la main frappent
		_kit.locomote(dir, DT)
		_player.tick(DT)
		for g in RainetteGoo.live:
			if is_instance_valid(g):
				g.step(DT)
		for b in RainetteBubble.live:
			if is_instance_valid(b):
				b.step(DT)
		t += DT
	_player.spells._remaining[1] = 0.0


func _to_impact() -> void:
	var t := 0.0
	while _kit.has_pending() and t < 1.5:
		_player.spells._remaining[1] = 99.0 if _player.spells._remaining[1] <= 0.0 else _player.spells._remaining[1]
		_player.tick(DT)
		t += DT


func _until_ground(cap := 3.0) -> void:
	var t := 0.0
	while _kit.state != RainetteKit.State.GROUND and t < cap:
		_advance(DT)
		t += DT


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.state = RainetteKit.State.GROUND
	_kit.state_left = 0.0
	_kit.hop_is_leap = false
	_kit.ult_left = 0.0
	_kit.choir = false
	_kit.ric_chains = 0
	_kit.croak_cd_gain = 0.0
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
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
	RunState.counters.clear()


func _run() -> void:
	# --- substitution (sans joueur) ---------------------------------------------------------------
	print("Substitution")
	var base_cd := CharacterData.for_id(&"rainette", {})
	_check("sans loadout : sorts de base", base_cd.spells.map(func(s): return String(s.id)) == ["rainette_langue", "rainette_grand_saut", "rainette_gluant", "rainette_chant_de_crue"])
	var var_cd := CharacterData.for_id(&"rainette", LOADOUT)
	_check("4 variantes substituées", var_cd.spells.map(func(s): return String(s.id)) == ["rainette_croassement", "rainette_ricochet", "rainette_bulle", "rainette_choeur"], str(var_cd.spells.map(func(s): return s.id)))
	_check("slots conservés, slot 1 auto", var_cd.spells.map(func(s): return s.slot) == [1, 2, 3, 4] and var_cd.spells[0].is_auto)
	_check("variant_of(slot)", var_cd.variant_of(1) == &"rainette_croassement" and var_cd.variant_of(4) == &"rainette_choeur")
	_check("variante inconnue : sort de base", CharacterData.for_id(&"rainette", {2: &"rainette_fantome"}).spells[1].id == &"rainette_grand_saut")
	_check("variant() inconnue = null", RainetteKit.variant(1, &"nope") == null and RainetteKit.variant(2, &"rainette_bulle") == null)

	# --- characters.json ---------------------------------------------------------------------------
	print("characters.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var rj: Dictionary = {}
	for c in data:
		if c is Dictionary and str(c.get("id", "")) == "rainette":
			rj = c
	var declared := {}
	var spells_json: Array = rj.get("spells", [])
	for i in spells_json.size():
		for v in spells_json[i].get("variants", []):
			declared[i + 1] = str(v.get("id", ""))
	_check("4 variantes déclarées (une par slot)", declared.size() == 4, str(declared))
	_check("ids déclarés = ids codés", declared.get(1) == "rainette_croassement" and declared.get(2) == "rainette_ricochet"
			and declared.get(3) == "rainette_bulle" and declared.get(4) == "rainette_choeur", str(declared))
	var all_coded := true
	for slot in declared:
		all_coded = all_coded and RainetteKit.variant(int(slot), StringName(declared[slot])) != null
	_check("chaque variante déclarée est codée", all_coded)

	# --- règles de déblocage -----------------------------------------------------------------------
	print("Déblocage")
	var chars: Array = data
	var prof := FakeProfile.new()
	var win := {"victory": true, "character": "rainette", "mode": "moyen", "stage": 5}
	_check("Croassement : victoire avec Rainette", VU.evaluate(prof, chars, win).has(&"spell:rainette_croassement"))
	_check("Croassement : victoire d'un autre", not VU.evaluate(prof, chars, {"victory": true, "character": "rictus", "stage": 5}).has(&"spell:rainette_croassement"))
	prof.stats["rainette.leap_stuns"] = 299.0
	_check("Ricochet : 299 étourdis = non", not VU.evaluate(prof, chars, {"character": "rainette", "stage": 1}).has(&"spell:rainette_ricochet"))
	prof.stats["rainette.leap_stuns"] = 300.0
	_check("Ricochet : 300 étourdis", VU.evaluate(prof, chars, {"character": "rainette", "stage": 1}).has(&"spell:rainette_ricochet"))
	prof.stats["rainette.glued"] = 599.0
	_check("Bulle : 599 collés = non", not VU.evaluate(prof, chars, {"character": "rainette", "stage": 1}).has(&"spell:rainette_bulle"))
	prof.stats["rainette.glued"] = 600.0
	_check("Bulle : 600 collés", VU.evaluate(prof, chars, {"character": "rainette", "stage": 1}).has(&"spell:rainette_bulle"))
	prof.stats["rainette.swallowed"] = 199.0
	_check("Chœur : 199 avalés = non", not VU.evaluate(prof, chars, {"character": "rainette", "stage": 1}).has(&"spell:rainette_choeur"))
	prof.stats["rainette.swallowed"] = 200.0
	_check("Chœur : 200 avalés", VU.evaluate(prof, chars, {"character": "rainette", "stage": 1}).has(&"spell:rainette_choeur"))
	prof.unlocked_spells = [&"rainette_choeur"]
	_check("variante déjà possédée : pas ré-annoncée", not VU.evaluate(prof, chars, {"character": "rainette", "stage": 1}).has(&"spell:rainette_choeur"))

	# --- en jeu ------------------------------------------------------------------------------------
	RunState.level = 1
	RunState.character = &"rainette"
	RunState.loadout = LOADOUT.duplicate()
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit
	print("Joueur avec variantes")
	_check("kit Rainette", _kit is RainetteKit)
	_check("sorts du joueur = variantes", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["rainette_croassement", "rainette_ricochet", "rainette_bulle", "rainette_choeur"], str(_player.get_spell_cooldowns().map(func(c): return c.id)))
	_check("variant_of côté nœud", _player.character.variant_of(3) == &"rainette_bulle")

	print("Sort 1 : Croassement")
	_reset()
	_check("sans ennemi : rien, pas de recharge", not _player.spells.cast(1) and _player.get_spell_cooldowns()[0].remaining == 0.0)
	var far := _fake(Vector2(3.0 * U, 0))
	_check("ennemi à 3 u : rien", not _player.spells.cast(1))
	far.global_position = Vector2(2.0 * U, 0)
	var edge := _fake(Vector2(0, 2.4 * U))
	var out := _fake(Vector2(0, -2.8 * U))
	_check("ennemi à 2 u : lancé", _player.spells.cast(1))
	_to_impact()
	_check("anneau coef 1,2 sur 360 °", _near(far.total(), RainetteKit.CROAK_COEF * BASE, 0.05) and _near(edge.total(), RainetteKit.CROAK_COEF * BASE, 0.05), "%s %s" % [far.taken, edge.taken])
	_check("hors anneau (2,8 u) : intact", out.taken.is_empty())
	_check("pas de recharge rendue sans kill", _kit.croak_cd_gain == 0.0)
	_reset()
	_player.spells._remaining[2] = 5.0
	var small := _fake(Vector2(1.0 * U, 0), 1)
	small.hp = 1.0
	var small2 := _fake(Vector2(-1.0 * U, 0), 1)
	small2.hp = 1.0
	var brute := _fake(Vector2(0, 1.0 * U), 2)
	brute.hp = 1.0
	_check("lancé", _player.spells.cast(1))
	_to_impact()
	_check("2 T1 tués : Grand saut -0,5 s (le T2 tué n'en rend pas)", _near(_kit.croak_cd_gain, 0.5) and _player.spells._remaining[2] <= 4.5 + 0.001, str(_kit.croak_cd_gain))
	_reset()
	_player.spells._remaining[2] = 5.0
	for i in 8:
		var sm := _fake(Vector2(1.0 * U, 0.2 * U * i), 1)
		sm.hp = 1.0
	_player.spells.cast(1)
	_to_impact()
	_check("gain plafonné à 1 s par croassement", _near(_kit.croak_cd_gain, 1.0) and _player.spells._remaining[2] <= 4.0 + 0.001, str(_kit.croak_cd_gain))

	print("Sort 2 : Ricochet")
	_reset()
	var e1 := _fake(Vector2(3.0 * U, 0))
	var e2 := _fake(Vector2(6.5 * U, 0))
	_player.spells.aim_override = Vector2(3.0 * U, 0)
	_check("Ricochet lancé", _player.spells.cast(2))
	_advance(0.06 + 0.35 + 0.05) # accroupie courte + bond
	_check("premier atterrissage : coef 1,9, étourdit 0,3 s", _near(e1.total(), 1.9 * BASE, 0.05) and _near(e1.stunned, 0.3), "%s %s" % [e1.taken, e1.stunned])
	_check("premier bond de 3 u vers la visée", _near(_player.global_position.x, 3.0 * U, 6.0), str(_player.global_position))
	_player.spells.aim_override = Vector2(6.5 * U, 0) # le second bond reprend la visée du moment (curseur)
	_advance(1.0)
	_until_ground()
	_check("second bond lancé tout seul (sans 2e appui)", _kit.ric_chains == 1, str(_kit.ric_chains))
	_check("second atterrissage : coef 1,9 plus loin", _near(e2.total(), 1.9 * BASE, 0.05), str(e2.taken))
	_check("pas de 3e bond", _kit.state == RainetteKit.State.GROUND and _kit._queued_leap == null)
	_check("recharge 7 s", _near(_player.get_spell_cooldowns()[1].total, 7.0, 0.01), str(_player.get_spell_cooldowns()[1]))
	_check("Ricochet ne compte pas pour le déblocage", not RunState.counters.has("rainette.leap_stuns"))
	_reset()
	_kit._leap_spell = RainetteKit.character().spells[1]
	var st1 := _fake(Vector2(60, 0))
	var st2 := _fake(Vector2(0, 60))
	var boss := _fake(Vector2(-60, 0))
	boss.is_boss = true
	_kit._leap_impact(Vector2.ZERO)
	_check("Grand saut : 2 étourdis hors boss comptés", _near(float(RunState.counters.get("rainette.leap_stuns", 0.0)), 2.0), str(RunState.counters))
	_check("étourdissement 0,5 s de base conservé", _near(st1.stunned, 0.5) and _near(st2.stunned, 0.5))

	print("Sort 3 : Bulle")
	_reset()
	var b1 := _fake(Vector2(4.0 * U, 0))
	var b2 := _fake(Vector2(4.0 * U, 1.5 * U))
	var bb := _fake(Vector2(4.0 * U, -1.0 * U))
	bb.is_boss = true
	var bfar := _fake(Vector2(4.0 * U, 3.2 * U))
	_player.spells.aim_override = Vector2(4.0 * U, 0)
	_check("Bulle lancée", _player.spells.cast(3))
	_to_impact()
	_check("une bulle posée", RainetteBubble.live.size() == 1)
	var bub: RainetteBubble = RainetteBubble.live[0]
	_check("2 monstres soulevés, le boss ralenti, le lointain ignoré",
			bub.caught == 2 and b1.statuses.any(func(s): return s[0] == &"imprisoned") and bb.statuses.any(func(s): return s[0] == &"slow" and _near(float(s[1]["pct"]), 0.4))
			and bfar.statuses.is_empty(), "%d" % bub.caught)
	_check("aucune flaque", RainetteGoo.live.is_empty())
	_advance(1.0)
	_check("attirés vers le centre pendant l'attente", b2.global_position.y < 1.5 * U - 5.0, str(b2.global_position))
	_check("pas de dégât avant l'éclatement", b1.taken.is_empty() and b2.taken.is_empty())
	_advance(0.6)
	await get_tree().process_frame
	_check("éclatement coef 1,4", _near(b1.total(), 1.4 * BASE, 0.05) and _near(b2.total(), 1.4 * BASE, 0.05), "%s %s" % [b1.taken, b2.taken])
	_check("le boss est touché aussi (zone 2 u)", _near(bb.total(), 1.4 * BASE, 0.05), str(bb.taken))
	_check("hors zone : intact", bfar.taken.is_empty())
	_check("la bulle disparaît", RainetteBubble.live.is_empty())
	_check("recharge 8 s", _near(_player.get_spell_cooldowns()[2].total, 8.0, 0.01))

	print("Sort 4 : Chœur des roseaux")
	_reset()
	_check("Chœur lancé", _player.spells.cast(4))
	_to_impact()
	_check("8 s, mode Chœur", _kit.is_singing() and _kit.choir and _near(_kit.ult_left, 8.0, 0.3), str(_kit.ult_left))
	var crowd := _fake(Vector2(2.5 * U + 40, 0))
	_kit.locomote(Vector2.RIGHT, DT)
	_check("bonds NORMAUX (2,5 u, pas x2)", _near(_kit.hop_speed_px * _kit.hop_air_total, 2.5 * U, 1.0), str(_kit.hop_speed_px * _kit.hop_air_total))
	_until_ground()
	_check("atterrissage : coef 1,8 dans 2,5 u", _near(crowd.total(), 1.8 * BASE, 0.05), str(crowd.taken))
	var minis := RainetteGoo.live.filter(func(g): return g.mini)
	_check("mini-flaque 1,5 u posée, sans attraction", minis.size() == 1 and _near(minis[0].radius, 1.5 * U) and minis[0].pull_px_s == 0.0 and _near(minis[0].duration, 2.0))
	for i in 14:
		_kit._spawn_mini_goo(Vector2(i * 40.0, 300.0))
	await get_tree().process_frame
	_check("mini-flaques plafonnées à 10", RainetteGoo.live.filter(func(g): return g.mini).size() <= RainetteKit.CHOEUR_GOO_MAX)
	_check("les mini-flaques ne comptent pas pour la Bulle", _near(float(RunState.counters.get("rainette.glued", 0.0)), 0.0))
	_advance(8.0)
	await get_tree().process_frame
	_check("fin du Chœur au bout de 8 s", not _kit.is_singing() and not _kit.choir)
	_reset()
	_player.spells.cast(4)
	_to_impact()
	_kit.clear_transients()
	_check("étage suivant : mode Chœur éteint", not _kit.choir and _kit.ult_left <= 0.0)

	print("Compteurs de déblocage")
	_reset()
	var gz := RainetteGoo.new()
	gz.setup(Vector2.ZERO, 3.0 * U, 5.0, 0.4, 0.0, RainetteKit.character().spells[2])
	get_tree().root.add_child(gz)
	_junk.append(gz)
	_fake(Vector2(50, 0))
	_fake(Vector2(0, 50))
	gz.step(DT)
	gz.step(DT)
	_check("Gluant : 2 monstres collés, comptés une seule fois", _near(float(RunState.counters.get("rainette.glued", 0.0)), 2.0), str(RunState.counters))
	_reset()
	var t1 := _fake(Vector2(40, 0), 1)
	t1.hp = 0.0
	_kit._check_swallow(t1)
	_check("Langue : T1 avalé compté (rainette.swallowed)", _near(float(RunState.counters.get("rainette.swallowed", 0.0)), 1.0))

	RunState.loadout = {}
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
