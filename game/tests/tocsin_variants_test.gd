extends Node
## Test headless des variantes de sorts de Tocsin (docs/Variantes_Sorts.md §2.3, CONTRACTS.md « Variantes de sorts ») :
## substitution par CharacterData.for_id, lancer et dégâts de chacune (Vapeur, Bras-harpon avec traction, Jambes-ressorts
## avec saut LOB, Tête-fumigène), membres rendus (calques / pickups), compteurs de déblocage et règles de characters.json.
## godot --headless --path game res://tests/tocsin_variants_test.tscn  (scène : les autoloads doivent exister)

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var pushes: Array = []
	var held := false

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func is_slowed() -> bool:
		return false

	func is_imprisoned() -> bool:
		return held

	func push(v: Vector2) -> void:
		pushes.append(v)

	func has_status(s: StringName) -> bool:
		for st in statuses:
			if st[0] == s:
				return true
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


## Profil factice : compteurs cumulés et variantes possédées.
class FakeProfile extends RefCounted:
	var stats := {}
	var unlocked_spells: Array = []

	func stat(key: String) -> float:
		return float(stats.get(key, 0.0))


const VU := preload("res://scripts/save/variant_unlocks.gd")
const U := 64.0
const BASE := 12.0 ## Dégât_base niveau 1
const DT := 1.0 / 60.0
const LOADOUT := {1: &"tocsin_vapeur", 2: &"tocsin_bras_harpon", 3: &"tocsin_jambes_ressorts", 4: &"tocsin_tete_fumigene"}

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


func _fake(pos: Vector2, boss := false) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	if boss:
		e.add_to_group("bosses")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


## Avance la simulation de `t` s : joueur (états, recharges, actions) et membres en jeu ; sort 1 tenu si `hold1`.
func _sim(t: float, hold1 := true) -> void:
	var n := int(ceil(t / DT))
	for i in n:
		if hold1:
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
			j.remove_from_group("bosses")
			j.queue_free()
	_junk.clear()
	_kit.regen_all()
	_kit._pull = {}
	_kit._jump = {}
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.is_moving = false
	_player.facing = Vector2.RIGHT
	_player.apply_stats({"crit_chance": -0.05}) # crit désactivé : dégâts déterministes
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player._dodge_cd = 0.0
	_player._invuln = 0.0
	RunState.counters.clear()
	_sim(0.5) # fin des anims d'action précédentes


func _spawn_player() -> void:
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false) # boucle pilotée par le test
	_kit = _player.kit as TocsinKit


func _free_player() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.remove_from_group("bosses")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_player.queue_free()
	await get_tree().process_frame


func _run() -> void:
	# --- substitution (sans joueur) ---------------------------------------------------------------
	print("Substitution")
	var base_cd := CharacterData.for_id(&"tocsin", {})
	_check("sans loadout : sorts de base", base_cd.spells.map(func(s): return String(s.id)) == ["tocsin_rivets_rougis", "tocsin_bras_grappins", "tocsin_coups_de_botte", "tocsin_tete_cloche"])
	_check("sans loadout : variant_of vide", base_cd.variant_of(1) == &"" and base_cd.variant_of(4) == &"")
	var var_cd := CharacterData.for_id(&"tocsin", LOADOUT)
	_check("4 variantes substituées (ids)", var_cd.spells.map(func(s): return String(s.id)) == ["tocsin_vapeur", "tocsin_bras_harpon", "tocsin_jambes_ressorts", "tocsin_tete_fumigene"], str(var_cd.spells.map(func(s): return s.id)))
	_check("slots conservés", var_cd.spells.map(func(s): return s.slot) == [1, 2, 3, 4])
	_check("variant_of(slot)", var_cd.variant_of(1) == &"tocsin_vapeur" and var_cd.variant_of(2) == &"tocsin_bras_harpon"
			and var_cd.variant_of(3) == &"tocsin_jambes_ressorts" and var_cd.variant_of(4) == &"tocsin_tete_fumigene")
	_check("slot 1 reste auto", var_cd.spells[0].is_auto)
	var mix_cd := CharacterData.for_id(&"tocsin", {3: &"tocsin_jambes_ressorts"})
	_check("substitution partielle : seul le slot 3", mix_cd.spells[0].id == &"tocsin_rivets_rougis" and mix_cd.spells[2].id == &"tocsin_jambes_ressorts" and mix_cd.spells[3].id == &"tocsin_tete_cloche")
	_check("variante inconnue : sort de base", CharacterData.for_id(&"tocsin", {1: &"tocsin_fantome"}).spells[0].id == &"tocsin_rivets_rougis")
	_check("variant() inconnue / mauvais slot = null", TocsinKit.variant(1, &"nope") == null and TocsinKit.variant(2, &"tocsin_vapeur") == null)
	_check("variant_spell (fiche) rend un nouveau SpellData",
			CharacterData.variant_spell(&"tocsin", 2, &"tocsin_bras_harpon", true) != CharacterData.variant_spell(&"tocsin", 2, &"tocsin_bras_harpon", true))

	# --- characters.json ---------------------------------------------------------------------------
	print("characters.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var tocsin_json: Dictionary = {}
	for c in data:
		if c is Dictionary and str(c.get("id", "")) == "tocsin":
			tocsin_json = c
	var declared := {}
	var spells_json: Array = tocsin_json.get("spells", [])
	for i in spells_json.size():
		for v in spells_json[i].get("variants", []):
			declared[i + 1] = str(v.get("id", ""))
	_check("4 variantes déclarées (une par slot)", declared.size() == 4, str(declared))
	_check("ids déclarés = ids codés", declared.get(1) == "tocsin_vapeur" and declared.get(2) == "tocsin_bras_harpon"
			and declared.get(3) == "tocsin_jambes_ressorts" and declared.get(4) == "tocsin_tete_fumigene", str(declared))
	var all_coded := true
	for slot in declared:
		all_coded = all_coded and TocsinKit.variant(int(slot), StringName(declared[slot])) != null
	_check("chaque variante déclarée est codée", all_coded)

	# --- règles de déblocage -----------------------------------------------------------------------
	print("Déblocage")
	var chars: Array = data
	var prof := FakeProfile.new()
	var win := {"victory": true, "character": "tocsin", "mode": "moyen", "stage": 5}
	_check("Vapeur : victoire avec Tocsin", VU.evaluate(prof, chars, win).has(&"spell:tocsin_vapeur"))
	_check("Vapeur : pas de victoire", not VU.evaluate(prof, chars, {"victory": false, "character": "tocsin", "stage": 2}).has(&"spell:tocsin_vapeur"))
	_check("Vapeur : victoire d'un autre personnage", not VU.evaluate(prof, chars, {"victory": true, "character": "rictus", "stage": 5}).has(&"spell:tocsin_vapeur"))
	prof.stats["tocsin.imprisoned"] = 399.0
	_check("Bras-harpon : 399 emprisonnés = non", not VU.evaluate(prof, chars, {"character": "tocsin", "stage": 1}).has(&"spell:tocsin_bras_harpon"))
	prof.stats["tocsin.imprisoned"] = 400.0
	_check("Bras-harpon : 400 emprisonnés", VU.evaluate(prof, chars, {"character": "tocsin", "stage": 1}).has(&"spell:tocsin_bras_harpon"))
	prof.stats["tocsin.pushed"] = 299.0
	_check("Jambes-ressorts : 299 poussés = non", not VU.evaluate(prof, chars, {"character": "tocsin", "stage": 1}).has(&"spell:tocsin_jambes_ressorts"))
	prof.stats["tocsin.pushed"] = 300.0
	_check("Jambes-ressorts : 300 poussés", VU.evaluate(prof, chars, {"character": "tocsin", "stage": 1}).has(&"spell:tocsin_jambes_ressorts"))
	_check("Tête-fumigène : aucun boss sans tête = non", not VU.evaluate(prof, chars, {"character": "tocsin", "stage": 1}).has(&"spell:tocsin_tete_fumigene"))
	prof.stats["tocsin.headless_boss_kills"] = 1.0
	_check("Tête-fumigène : 1 boss d'étage sans tête", VU.evaluate(prof, chars, {"character": "tocsin", "stage": 1}).has(&"spell:tocsin_tete_fumigene"))
	prof.unlocked_spells = [&"tocsin_tete_fumigene"]
	_check("variante déjà possédée : pas ré-annoncée", not VU.evaluate(prof, chars, {"character": "tocsin", "stage": 1}).has(&"spell:tocsin_tete_fumigene"))

	# --- en jeu : joueur avec les 4 variantes ------------------------------------------------------
	RunState.level = 1
	RunState.character = &"tocsin"
	RunState.loadout = LOADOUT.duplicate()
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	await _spawn_player()
	print("Joueur avec variantes")
	_check("kit Tocsin", _kit != null)
	_check("sorts du joueur = variantes", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["tocsin_vapeur", "tocsin_bras_harpon", "tocsin_jambes_ressorts", "tocsin_tete_fumigene"], str(_player.get_spell_cooldowns().map(func(c): return c.id)))
	_check("variant_of côté nœud", _player.character.variant_of(3) == &"tocsin_jambes_ressorts")
	_check("sort 1 Vapeur : portée 3 u", _near(_kit._spell_of(1).range_u, 3.0), str(_kit._spell_of(1).range_u))

	print("Sort 1 : Vapeur")
	_reset()
	var s1: SpellData = _kit._spell_of(1)
	_player.spells._remaining[1] = 0.0
	_check("sans ennemi : rien", not _player.spells.cast(1) and _player.spells._remaining[1] == 0.0)
	var in_cone := _fake(Vector2(2.0 * U, 0))
	var in_edge := _fake(Vector2(2.0 * U, 0.8 * U)) # 21,8° : dans les 30°
	var out_angle := _fake(Vector2(2.0 * U, 1.5 * U)) # 36,9° : hors cône
	var too_far := _fake(Vector2(3.6 * U, 0)) # au-delà de 3 u
	var behind := _fake(Vector2(-2.5 * U, 0))
	_check("vapeur lancée", _player.spells.cast(1))
	_check("coef 0,55 dans le cône", in_cone.taken.size() == 1 and _near(in_cone.total(), TocsinKit.VAPEUR_COEF * BASE), str(in_cone.taken))
	_check("bord du cône touché", in_edge.taken.size() == 1)
	_check("hors angle / hors portée / derrière : rien", out_angle.taken.is_empty() and too_far.taken.is_empty() and behind.taken.is_empty())
	_check("ralentissement 20 % 0,6 s", in_cone.statuses.size() == 1 and in_cone.statuses[0][0] == &"slow"
			and _near(float(in_cone.statuses[0][1]["pct"]), 0.2) and _near(float(in_cone.statuses[0][1]["duration"]), 0.6))
	_check("recharge 0,6 s", _near(_player.spells._remaining[1], 0.6, 0.02), str(_player.spells._remaining[1]))
	_check("anim d'action attack à l'arrêt", _kit.action_for(s1) == &"attack" or _player.action_base() != &"")
	_kit.present[&"head"] = false
	_kit._refresh_state()
	_check("sans tête : anneau de 2 u", _near(s1.range_u, 2.0), str(s1.range_u))
	for e in [in_cone, in_edge, out_angle, too_far, behind]:
		e.taken.clear()
	behind.global_position = Vector2(-1.5 * U, 0)
	out_angle.global_position = Vector2(0, 2.6 * U)
	_player.spells._remaining[1] = 0.0
	_check("vapeur sans tête", _player.spells.cast(1))
	_check("anneau 360° : derrière touché", behind.taken.size() == 1 and _near(behind.total(), TocsinKit.VAPEUR_COEF * BASE))
	_check("anneau : hors de 2 u rien", out_angle.taken.is_empty() and too_far.taken.is_empty())
	_check("Surchauffe : cadence +12 % (1 membre absent)", _near(Balance.attack_interval(s1.base_cooldown, 0.0), 0.6 / 1.12, 0.002), str(s1.base_cooldown))

	print("Sort 2 : Bras-harpon")
	_reset()
	var first := _fake(Vector2(4.0 * U, 0))
	var second := _fake(Vector2(6.0 * U, 0))
	var wave_victim := _fake(Vector2(3.2 * U, 0.9 * U)) # près du point d'arrivée
	_player.spells.aim_override = Vector2(10 * U, 0)
	_check("harpon lancé", _player.spells.cast(2))
	_check("anim throw_arm_l", _player.action_base() == &"throw_arm_l", String(_player.action_base()))
	_check("bras gauche détaché, 1 charge", not _kit.present[&"arm_l"] and _kit.charges(2) == 1)
	_check("recharge 8 s", _near(_player.spells._remaining[2], 8.0, 0.1), str(_player.spells._remaining[2]))
	var hooked_seen := false
	var pulled_seen := false
	for i in 90:
		_sim(DT)
		var hl := _limb(&"arm_l")
		if hl != null and hl.phase == TocsinLimb.Phase.HOOKED:
			hooked_seen = true
		pulled_seen = pulled_seen or _kit.is_pulling()
		if hooked_seen and not _kit.is_pulling() and pulled_seen:
			break
	_check("harpon planté sur le premier monstre", hooked_seen)
	_check("coef 1,8 au premier seulement", first.taken.size() == 1 and _near(first.total(), 1.8 * BASE) and second.taken.is_empty(), "%s %s" % [first.taken, second.taken])
	_check("Tocsin tiré vers la cible", pulled_seen)
	_check("arrêt à 1 u de la cible", _near(_player.global_position.x, 3.0 * U, 6.0), str(_player.global_position))
	_check("onde d'arrivée : voisin repoussé, sans dégâts", not wave_victim.pushes.is_empty() and wave_victim.taken.is_empty(), str(wave_victim.pushes))
	_check("cible ralentie 40 %", first.has_status(&"slow") and _near(float(first.statuses[0][1]["pct"]), 0.4))
	_check("jambes jamais bloquées (ressorts)", not _kit.blocks_slot(3))
	_sim(2.6)
	var gl := _limb(&"arm_l")
	_check("après 2,5 s : le harpon tombe au sol (ramassable)", gl != null and gl.phase == TocsinLimb.Phase.GROUND and gl.pickup != null)
	var rim: Variant = null
	if gl != null:
		rim = gl.sprite != null
	_check("membre rendu (sprite ou repli dessiné)", gl != null and rim != null)

	print("Sort 2 : harpon sur un boss et un mur")
	_reset()
	var boss := _fake(Vector2(5.0 * U, 0), true)
	_player.spells.aim_override = Vector2(10 * U, 0)
	_check("harpon sur un boss", _player.spells.cast(2))
	for i in 120:
		_sim(DT)
		if boss.taken.size() > 0 and not _kit.is_pulling():
			break
	_check("boss touché et pas ralenti", boss.taken.size() == 1 and not boss.has_status(&"slow"), str(boss.statuses))
	_check("Tocsin tiré jusqu'au boss", _player.global_position.x > 3.5 * U, str(_player.global_position))
	_reset()
	_player.spells.aim_override = Vector2(10 * U, 0)
	_check("harpon dans le vide", _player.spells.cast(2))
	_sim(1.2)
	var miss := _limb(&"arm_l")
	_check("rien touché : retombe au sol à 8 u", miss != null and miss.phase == TocsinLimb.Phase.GROUND and _near(miss.global_position.x, 8.0 * U, 12.0), str(miss.global_position if miss else null))
	_check("pas de traction dans le vide", not _kit.is_pulling() and _near(_player.global_position.x, 0.0, 1.0))

	print("Sort 3 : Jambes-ressorts")
	_reset()
	_kit.present[&"arm_l"] = false
	_kit.present[&"arm_r"] = false
	_kit._refresh_state()
	_check("sans bras : toujours lançable", not _kit.blocks_slot(3))
	var target := _fake(Vector2(4.0 * U, 0))
	var near_t := _fake(Vector2(4.0 * U, 1.0 * U))
	var far_t := _fake(Vector2(4.0 * U, 3.0 * U))
	var prisoner := _fake(Vector2(3.4 * U, -0.8 * U))
	prisoner.held = true
	var arm_holder := TocsinLimb.new() # bras factice qui tient le prisonnier
	arm_holder.kit = _kit
	arm_holder.caster = _player.spells
	arm_holder.captured.append({"e": prisoner, "off": Vector2.ZERO, "pos": prisoner.global_position})
	add_child(arm_holder)
	_kit.limbs[&"arm_r"] = arm_holder
	_player.spells.aim_override = Vector2(4.0 * U, 0)
	_check("saut lancé", _player.spells.cast(3))
	_check("saut en cours, jambe gauche partie", _kit.is_jumping() and not _kit.present[&"leg_l"] and _kit.legs() == 1)
	_check("recharge 9 s", _near(_player.spells._remaining[3], 9.0, 0.1), str(_player.spells._remaining[3]))
	var y0 := (_player.get_node("Visual") as Node2D).position.y
	_sim(0.25)
	var lifted := (_player.get_node("Visual") as Node2D).position.y < y0 - 20.0
	_check("en l'air : corps levé (arc), invulnérable, immobile", lifted and _player.is_invulnerable() and _near(_player.move_speed(), 0.0))
	_check("pas de roulade en vol", not _kit.can_dodge())
	_sim(0.4)
	_check("atterri à 4 u", not _kit.is_jumping() and _near(_player.global_position.x, 4.0 * U, 6.0), str(_player.global_position))
	_check("corps reposé", _near((_player.get_node("Visual") as Node2D).position.y, y0, 0.01))
	_check("coef 3,0 au centre", target.taken.size() == 1 and _near(target.total(), 3.0 * BASE), str(target.taken))
	_check("disque 2 u : voisin touché, lointain non", near_t.taken.size() == 1 and far_t.taken.is_empty())
	_check("poussée radiale du voisin", not near_t.pushes.is_empty() and (near_t.pushes[0] as Vector2).y > 0.0, str(near_t.pushes))
	_check("prisonnier libéré et poussé ×1,5", prisoner.pushes.size() == 1 and not arm_holder.holds(prisoner), str(prisoner.pushes))
	var plain: Vector2 = near_t.pushes[0] if not near_t.pushes.is_empty() else Vector2.ZERO
	_check("poussée 2 u × masse (Fake : masse 1)", _near(plain.length(), 2.0 * U, 1.0), str(plain.length()))
	var leg := _limb(&"leg_l")
	_check("la jambe reste au décollage (pickup)", leg != null and leg.phase == TocsinLimb.Phase.GROUND and leg.pickup != null and _near(leg.global_position.x, 0.0, 2.0))
	if _kit.layers != null:
		_check("calque jambe caché pendant la recharge", not _kit.layers.is_shown(&"leg_l"))
	_check("locomotion : cloche-pied", _kit.locomotion() == &"hop")
	arm_holder.queue_free()
	_kit.limbs.erase(&"arm_r")

	print("Sort 4 : Tête-fumigène")
	_reset()
	var centre := _fake(Vector2(5.0 * U, 0))
	var jailed := _fake(Vector2(5.0 * U, 1.0 * U))
	var edge_out := _fake(Vector2(5.0 * U, 5.0 * U)) # hors des 4 u
	var smoke_boss := _fake(Vector2(6.0 * U, -1.0 * U), true)
	_player.spells.aim_override = Vector2(5.0 * U, 0)
	_check("tête lancée", _player.spells.cast(4))
	_check("tête partie, recharge 22 s", not _kit.has_head() and _near(_player.spells._remaining[4], 22.0, 0.1), str(_player.spells._remaining[4]))
	_sim(1.6) # lancer (frame d impact) + vol 0,9 s + tintement 0,3 s
	var hl := _limb(&"head")
	_check("la tête reste au sol : zone de fumée", hl != null and hl.phase == TocsinLimb.Phase.SMOKE, str(hl.phase if hl else null))
	_check("étourdissement d'entrée (imprisoned 1 s)", centre.has_status(&"imprisoned") and edge_out.statuses.is_empty())
	_check("boss : ralenti 40 %, pas étourdi", smoke_boss.has_status(&"slow") and not smoke_boss.has_status(&"imprisoned"))
	_check("aucun dégât à l'arrivée", centre.taken.is_empty())
	jailed.held = true
	_sim(1.0) # ticks à 0,5 et 1,0 s
	_check("2 ticks en 1 s", centre.taken.size() == 2 and _near(centre.total(), 2.0 * TocsinKit.FUMI_COEF * BASE, 0.05), str(centre.taken))
	_check("+50 % sur l'emprisonné", _near(jailed.total(), 2.0 * 1.5 * TocsinKit.FUMI_COEF * BASE, 0.05), str(jailed.total()))
	_check("hors zone : rien", edge_out.taken.is_empty())
	_sim(4.2)
	_check("10 ticks au total (5 s)", centre.taken.size() == 10 and _near(centre.total(), 10.0 * TocsinKit.FUMI_COEF * BASE, 0.1), str(centre.taken.size()))
	_check("la zone s'éteint", _limb(&"head") == null or not is_instance_valid(_limb(&"head")) or _limb(&"head").is_queued_for_deletion())
	_check("ralentissement 50 % rafraîchi", centre.has_status(&"slow"))
	_check("boss sans bonus +30 %", smoke_boss.taken.size() == 10 and _near(smoke_boss.total(), 10.0 * TocsinKit.FUMI_COEF * BASE, 0.1), str(smoke_boss.total()))
	_check("tête revenue seulement à la fin de la recharge", not _kit.has_head())

	await _free_player()
	RunState.loadout = {}

	# --- compteurs de déblocage (kit de base) --------------------------------------------------------
	print("Compteurs")
	RunState.character = &"tocsin"
	await _spawn_player()
	_check("kit de base : Bras-grappins", _kit._spell_of(2).id == &"tocsin_bras_grappins")
	_reset()
	var a1 := _fake(Vector2(3.0 * U, 0))
	_player.spells.aim_override = Vector2(10 * U, 0)
	_check("bras-grappin lancé", _player.spells.cast(2))
	_sim(0.8)
	_check("tocsin.imprisoned +1 par monstre emprisonné", _near(float(RunState.counters.get("tocsin.imprisoned", 0.0)), 1.0), str(RunState.counters))
	_reset()
	var b1 := _fake(Vector2(2.0 * U, 0))
	_player.spells.aim_override = Vector2(10 * U, 0)
	_check("coup de botte lancé", _player.spells.cast(3))
	_sim(0.6)
	_check("tocsin.pushed +1 par monstre poussé", _near(float(RunState.counters.get("tocsin.pushed", 0.0)), 1.0) and not b1.pushes.is_empty(), str(RunState.counters))
	_reset()
	_kit._on_boss_killed(null, true)
	_check("boss d'étage avec la tête : pas de compteur", not RunState.counters.has("tocsin.headless_boss_kills"))
	_kit._on_boss_killed(null, false)
	_kit.present[&"head"] = false
	_kit._refresh_state()
	_kit._on_boss_killed(null, false)
	_check("mini-boss sans tête : pas de compteur", not RunState.counters.has("tocsin.headless_boss_kills"))
	_kit._on_boss_killed(null, true)
	_check("boss d'étage sans tête : tocsin.headless_boss_kills +1", _near(float(RunState.counters.get("tocsin.headless_boss_kills", 0.0)), 1.0), str(RunState.counters))
	_reset()

	# --- nettoyage --------------------------------------------------------------------------------
	RunState.counters.clear()
	await _free_player()
	director.queue_free()
	await get_tree().process_frame
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
