extends Node
## Test headless des variantes de sorts de Rictus (docs/Variantes_Sorts.md §2.2, CONTRACTS.md « Variantes de sorts ») :
## substitution par CharacterData.for_id, lancer et dégâts de chacune (Main du Montreur, Lame-pendule, Pirouette,
## Rideau), compteurs de déblocage (couteaux ramassés, doublures expédiées) et règles de déblocage de characters.json.
## godot --headless --path game res://tests/rictus_variants_test.tscn  (scène : les autoloads doivent exister)

class FakeEnemy extends Node2D:
	var taken: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
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
const LOADOUT := {1: &"rictus_main_du_montreur", 2: &"rictus_lame_pendule", 3: &"rictus_pirouette", 4: &"rictus_rideau"}

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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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
	_kit.pirouette_left = 0.0
	_kit.guard_left = 0.0
	_kit.lifting = false
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.apply_stats({"crit_chance": -0.05}) # crit désactivé : dégâts déterministes
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player._dodge_cd = 0.0
	_player._invuln = 0.0
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	RunState.counters.clear()


## Doublures posées à la frame d'impact de l'anim d'ultime : avance le joueur jusqu'à l'impact (sort 1 suspendu).
func _land_decoys() -> void:
	var rem1: float = _player.spells._remaining[1]
	var t := 0.0
	while _kit.decoys_pending() and t < 1.0:
		_player.spells._remaining[1] = 99.0
		_player.tick(0.01)
		t += 0.01
	_player.spells._remaining[1] = rem1


func _run() -> void:
	# --- substitution (sans joueur) ---------------------------------------------------------------
	print("Substitution")
	var base_cd := CharacterData.for_id(&"rictus", {})
	_check("sans loadout : sorts de base", base_cd.spells.map(func(s): return String(s.id)) == ["dagues_demi_lune", "eventail", "toupie", "doublures"])
	_check("sans loadout : variant_of vide", base_cd.variant_of(1) == &"" and base_cd.variant_of(4) == &"")
	var var_cd := CharacterData.for_id(&"rictus", LOADOUT)
	_check("4 variantes substituées (ids)", var_cd.spells.map(func(s): return String(s.id)) == ["rictus_main_du_montreur", "rictus_lame_pendule", "rictus_pirouette", "rictus_rideau"], str(var_cd.spells.map(func(s): return s.id)))
	_check("slots conservés", var_cd.spells.map(func(s): return s.slot) == [1, 2, 3, 4])
	_check("variant_of(slot)", var_cd.variant_of(1) == &"rictus_main_du_montreur" and var_cd.variant_of(2) == &"rictus_lame_pendule"
			and var_cd.variant_of(3) == &"rictus_pirouette" and var_cd.variant_of(4) == &"rictus_rideau")
	_check("slot 1 reste auto", var_cd.spells[0].is_auto)
	var mix_cd := CharacterData.for_id(&"rictus", {3: &"rictus_pirouette"})
	_check("substitution partielle : seul le slot 3", mix_cd.spells[0].id == &"dagues_demi_lune" and mix_cd.spells[2].id == &"rictus_pirouette" and mix_cd.spells[3].id == &"doublures")
	_check("variante inconnue : sort de base", CharacterData.for_id(&"rictus", {1: &"rictus_fantome"}).spells[0].id == &"dagues_demi_lune")
	_check("variant() inconnue = null", RictusKit.variant(1, &"nope") == null and RictusKit.variant(2, &"rictus_pirouette") == null)
	_check("variant_spell (fiche) rend un nouveau SpellData",
			CharacterData.variant_spell(&"rictus", 2, &"rictus_lame_pendule", true) != CharacterData.variant_spell(&"rictus", 2, &"rictus_lame_pendule", true))

	# --- characters.json ---------------------------------------------------------------------------
	print("characters.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var rictus_json: Dictionary = {}
	for c in data:
		if c is Dictionary and str(c.get("id", "")) == "rictus":
			rictus_json = c
	var declared := {}
	var spells_json: Array = rictus_json.get("spells", [])
	for i in spells_json.size():
		for v in spells_json[i].get("variants", []):
			declared[i + 1] = str(v.get("id", ""))
	_check("4 variantes déclarées (une par slot)", declared.size() == 4, str(declared))
	_check("ids déclarés = ids codés", declared.get(1) == "rictus_main_du_montreur" and declared.get(2) == "rictus_lame_pendule"
			and declared.get(3) == "rictus_pirouette" and declared.get(4) == "rictus_rideau", str(declared))
	var all_coded := true
	for slot in declared:
		all_coded = all_coded and RictusKit.variant(int(slot), StringName(declared[slot])) != null
	_check("chaque variante déclarée est codée", all_coded)

	# --- règles de déblocage -----------------------------------------------------------------------
	print("Déblocage")
	var chars: Array = data
	var prof := FakeProfile.new()
	var win := {"victory": true, "character": "rictus", "mode": "moyen", "stage": 5}
	_check("Main : victoire avec Rictus", VU.evaluate(prof, chars, win).has(&"spell:rictus_main_du_montreur"))
	_check("Main : pas de victoire", not VU.evaluate(prof, chars, {"victory": false, "character": "rictus", "stage": 2}).has(&"spell:rictus_main_du_montreur"))
	_check("Main : victoire d'un autre personnage", not VU.evaluate(prof, chars, {"victory": true, "character": "tocsin", "stage": 5}).has(&"spell:rictus_main_du_montreur"))
	prof.stats["rictus.knives_picked"] = 149.0
	_check("Lame-pendule : 149 couteaux = non", not VU.evaluate(prof, chars, {"character": "rictus", "stage": 1}).has(&"spell:rictus_lame_pendule"))
	prof.stats["rictus.knives_picked"] = 150.0
	_check("Lame-pendule : 150 couteaux", VU.evaluate(prof, chars, {"character": "rictus", "stage": 1}).has(&"spell:rictus_lame_pendule"))
	prof.stats["rictus.doubles_launched"] = 29.0
	_check("Pirouette : 29 doublures = non", not VU.evaluate(prof, chars, {"character": "rictus", "stage": 1}).has(&"spell:rictus_pirouette"))
	prof.stats["rictus.doubles_launched"] = 30.0
	_check("Pirouette : 30 doublures", VU.evaluate(prof, chars, {"character": "rictus", "stage": 1}).has(&"spell:rictus_pirouette"))
	_check("Rideau : étage 2 = non", not VU.evaluate(prof, chars, {"character": "rictus", "stage": 2}).has(&"spell:rictus_rideau"))
	_check("Rideau : étage 3 atteint (même sans victoire)", VU.evaluate(prof, chars, {"victory": false, "character": "rictus", "stage": 3}).has(&"spell:rictus_rideau"))
	_check("Rideau : étage 3 avec un autre personnage = non", not VU.evaluate(prof, chars, {"character": "ardent", "stage": 3}).has(&"spell:rictus_rideau"))
	prof.unlocked_spells = [&"rictus_rideau"]
	_check("variante déjà possédée : pas ré-annoncée", not VU.evaluate(prof, chars, {"character": "rictus", "stage": 3}).has(&"spell:rictus_rideau"))

	# --- en jeu : joueur avec les 4 variantes ------------------------------------------------------
	RunState.level = 1
	RunState.character = &"rictus"
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
	_check("kit Rictus", _kit is RictusKit)
	_check("sorts du joueur = variantes", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["rictus_main_du_montreur", "rictus_lame_pendule", "rictus_pirouette", "rictus_rideau"], str(_player.get_spell_cooldowns().map(func(c): return c.id)))
	_check("variant_of côté nœud", _player.character.variant_of(2) == &"rictus_lame_pendule")

	print("Sort 1 : Main du Montreur")
	_reset()
	_check("sans ennemi : rien", not _player.spells.cast(1) and _player.get_spell_cooldowns()[0].remaining == 0.0)
	var far := _fake(Vector2(5.0 * U, 0)) # hors des 4 u
	_check("ennemi à 5 u : rien", not _player.spells.cast(1))
	far.global_position = Vector2(3.0 * U, 0)
	var neighbor := _fake(Vector2(3.0 * U, 0.8 * U)) # dans le disque de 1,4 u du paquet
	var outsider := _fake(Vector2(3.0 * U, 2.5 * U)) # hors disque
	_check("claquement lancé", _player.spells.cast(1))
	_check("coef 0,8 au centre", far.taken.size() == 1 and _near(far.total(), RictusKit.MAIN_COEF * BASE), str(far.taken))
	_check("disque de 1,4 u", neighbor.taken.size() == 1 and outsider.taken.is_empty(), "%s %s" % [neighbor.taken, outsider.taken])
	_check("à 3 u : pas de garde", is_equal_approx(_kit.damage_taken_mult(null), 1.0))
	_check("recharge 0,6 s", _near(_player.spells._remaining[1], 0.6, 0.02), str(_player.spells._remaining[1]))
	_reset()
	var near_e := _fake(Vector2(1.0 * U, 0))
	_check("claquement près de Rictus", _player.spells.cast(1))
	_check("à ≤ 1,5 u : garde −30 %", is_equal_approx(_kit.damage_taken_mult(null), RictusKit.GUARD_TAKEN_MULT) and _near(near_e.total(), RictusKit.MAIN_COEF * BASE))
	_kit.tick(RictusKit.GUARD_S + 0.05)
	_check("garde finie", is_equal_approx(_kit.damage_taken_mult(null), 1.0))
	_check("anim d'action slash", _kit.action_for(_player.character.spells[0]) == &"slash")

	print("Sort 2 : Lame-pendule")
	_reset()
	var line := _fake(Vector2(3.0 * U, 0)) # sur la ligne
	var beyond := _fake(Vector2(6.0 * U, 0)) # sur la ligne aussi (perce tout)
	var side := _fake(Vector2(3.0 * U, 3.0 * U)) # hors ligne
	_player.spells.aim_override = Vector2(500, 0)
	_check("pendule lancé", _player.spells.cast(2))
	_check("un pendule en vol", _kit.pendulums.size() == 1)
	_check("recharge 6 s", _near(_player.spells._remaining[2], RictusKit.PENDULE_CD, 0.05), str(_player.spells._remaining[2]))
	await _frames(100) # 7 u à 14 u/s + retour : ~1 s
	_check("aller + retour : 2 × 2,5 sur la ligne proche", line.taken.size() == 2 and _near(line.total(), 2.0 * RictusKit.PENDULE_COEF * BASE), str(line.taken))
	_check("perce tout : cible lointaine touchée 2 fois", beyond.taken.size() == 2, str(beyond.taken))
	_check("hors ligne : rien", side.taken.is_empty())
	_check("rattrapé : plus de pendule", _kit.pendulums.is_empty())
	_player.spells.aim_override = null

	print("Compteur : couteaux ramassés")
	_reset()
	_kit._collect_knife(2, {"refunded": 0.0})
	_kit._collect_knife(2, {"refunded": 0.0})
	_check("rictus.knives_picked +1 par couteau", _near(float(RunState.counters.get("rictus.knives_picked", 0.0)), 2.0), str(RunState.counters))

	print("Sort 4 : Rideau")
	_reset()
	_player.spells.aim_override = Vector2(500, 0)
	_check("rideau lancé", _player.spells.cast(4))
	_land_decoys()
	_check("6 doublures", Decoy.live.size() == 6, str(Decoy.live.size()))
	var line_ok := true
	var ys: Array = []
	for d in Decoy.live:
		line_ok = line_ok and _near(d.global_position.x, 2.0 * U, 0.5) and d.facing.x > 0.99
		ys.append(snappedf(d.global_position.y, 1.0))
	ys.sort()
	_check("ligne perpendiculaire à 2 u devant, dos à Rictus", line_ok, str(ys))
	_check("espacées de 1 u", ys.size() == 6 and _near(float(ys[1]) - float(ys[0]), U, 1.0) and _near(float(ys[5]) - float(ys[0]), 5.0 * U, 1.0), str(ys))
	var d0: Decoy = Decoy.live[0]
	_check("PV = 30 % des PV max", _near(d0.max_hp, 0.3 * _player.max_hp), str(d0.max_hp))
	_check("vie 6 s", _near(d0.life_s, 6.0), str(d0.life_s))
	_check("recharge 20 s", _near(_player.spells._remaining[4], 20.0, 0.5), str(_player.spells._remaining[4]))
	for d in Decoy.live:
		d.life_s = 30.0
	# Explosion à 6 s : rayon 2 u, coef 2,5 ; une cible près d'une extrémité prend 2,5 × le nombre de doublures dans 2 u
	var victim := _fake(Vector2(2.0 * U, 2.5 * U))
	var in_range := 0
	for d in Decoy.live:
		if d.global_position.distance_to(victim.global_position) <= 2.0 * U:
			in_range += 1
	for d in Decoy.live.duplicate():
		d.life_s = 6.0
		d.step(5.9)
	_check("pas d'explosion avant 6 s", Decoy.live.size() == 6 and victim.taken.is_empty())
	for d in Decoy.live.duplicate():
		d.step(0.11)
	_check("toutes explosent à 6 s", Decoy.live.is_empty())
	_check("explosion coef 2,5 par doublure à 2 u", in_range >= 1 and _near(victim.total(), in_range * RictusKit.RIDEAU_COEF * BASE, 0.05), "%s dans %d" % [victim.taken, in_range])

	print("Sort 3 : Pirouette")
	_reset()
	_player.spells._remaining[4] = 0.0
	_player.spells.aim_override = Vector2(500, 0)
	_player.spells.cast(4)
	_land_decoys()
	_player.spells.aim_override = null
	for d in Decoy.live:
		d.life_s = 30.0
	var hit_e := _fake(Vector2(1.5 * U, 0.2 * U)) # dans les 2,2 u
	var out_e := _fake(Vector2(0, 3.0 * U)) # hors de 2,2 u
	_check("pirouette lancée", _player.spells.cast(3))
	_check("en pirouette (0,6 s)", _kit.pirouette_left > 0.5)
	_check("invulnérable", _player.is_invulnerable())
	_check("immobile (vitesse nulle)", _near(_player.move_speed(), 0.0), str(_player.move_speed()))
	_check("pas de vertige, roulade permise", _kit.can_dodge() and not _kit.is_staggered())
	_check("sort 1 non suspendu", not _player.spells.is_slot_blocked(1) and not _kit.blocks_slot(1) and not _kit.blocks_slot(3))
	_check("pas d'impact avant 0,3 s", hit_e.taken.is_empty())
	_check("anim spin", String(_kit.visual_anim(&"idle_s")).begins_with("spin") or not ResourceLoader.exists(RictusKit.SPRITE_FRAMES))
	_kit.tick(0.31)
	_check("impact à 0,3 s : coef 4,0", hit_e.taken.size() == 1 and _near(hit_e.total(), RictusKit.PIROUETTE_COEF * BASE), str(hit_e.taken))
	_check("rayon 2,2 u", out_e.taken.is_empty())
	var launched := 0
	var same_dir := true
	for d in Decoy.live:
		if d.pushed:
			launched += 1
			same_dir = same_dir and d.facing.x > 0.99
	_check("doublures percutées dans le rayon (2 sur 6), toutes vers l'avant", launched == 2 and same_dir, "%d" % launched)
	_check("compteur rictus.doubles_launched +2", _near(float(RunState.counters.get("rictus.doubles_launched", 0.0)), 2.0), str(RunState.counters))
	_kit.tick(0.31)
	_check("fin de pirouette sans vertige", _kit.pirouette_left <= 0.0 and not _kit.is_staggered())
	_check("vitesse normale", _near(_player.move_speed(), 4.2 * U), str(_player.move_speed()))
	_check("recharge 8 s", _near(_player.spells._remaining[3], 8.0, 0.1), str(_player.spells._remaining[3]))
	_check("une seule frappe", hit_e.taken.size() == 1)

	# --- nettoyage --------------------------------------------------------------------------------
	RunState.loadout = {}
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	Decoy.clear_all()
	_kit.clear_transients()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
