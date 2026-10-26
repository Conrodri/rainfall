extends Node
## Test headless des variantes de sorts d'Avare (docs/Variantes_Sorts.md, CONTRACTS.md « Variantes de sorts ») :
## chaque variante se charge (substitution par CharacterData.for_id, déclaration dans characters.json), sa règle de
## déblocage fonctionne (compteurs avare.*, boss d'étage 2, victoire), le joueur les porte, et la variante de l'auto
## (Coffre-bélier) frappe bien en ligne. Les ratios de DPS (±15 % du sort de base) se mesurent au simulateur :
## godot --headless --path game res://tests/balance_sim_run.tscn -- --chars=avare --seeds=3 --loadout=1:avare_coffre_belier
## godot --headless --path game res://tests/avare_variants_test.tscn  (scène : les autoloads doivent exister)

class FakeEnemy extends Node2D:
	var taken: Array = []
	var radius_px := 16.0

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


class FakeProfile extends RefCounted:
	var stats := {}
	var unlocked_spells: Array = []

	func stat(key: String) -> float:
		return float(stats.get(key, 0.0))


const VU := preload("res://scripts/save/variant_unlocks.gd")
const U := 64.0
const LOADOUT := {1: &"avare_coffre_belier", 2: &"avare_piece_truquee", 3: &"avare_saisie", 4: &"avare_tresor_enterre"}
const BASE_IDS := ["avare_coup_de_coffre", "avare_poignee_de_pieces", "avare_rancon", "avare_faillite"]

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


func _run() -> void:
	# --- substitution (sans joueur) ---------------------------------------------------------------
	print("Substitution")
	var base_cd := CharacterData.for_id(&"avare", {})
	_check("sans loadout : sorts de base", base_cd.spells.map(func(s): return String(s.id)) == BASE_IDS, str(base_cd.spells.map(func(s): return s.id)))
	_check("auto de base : portée 2,6 u", _near(base_cd.spells[0].radius_u, 2.6) and _near(base_cd.spells[0].range_u, 2.6))
	var var_cd := CharacterData.for_id(&"avare", LOADOUT)
	_check("4 variantes substituées (ids)", var_cd.spells.map(func(s): return String(s.id)) == ["avare_coffre_belier", "avare_piece_truquee", "avare_saisie", "avare_tresor_enterre"], str(var_cd.spells.map(func(s): return s.id)))
	_check("slots conservés, slot 1 auto", var_cd.spells.map(func(s): return s.slot) == [1, 2, 3, 4] and var_cd.spells[0].is_auto)
	_check("variant_of(slot)", var_cd.variant_of(1) == &"avare_coffre_belier" and var_cd.variant_of(4) == &"avare_tresor_enterre")
	var mix_cd := CharacterData.for_id(&"avare", {3: &"avare_saisie"})
	_check("substitution partielle : seul le slot 3", mix_cd.spells[0].id == &"avare_coup_de_coffre" and mix_cd.spells[2].id == &"avare_saisie" and mix_cd.spells[3].id == &"avare_faillite")
	_check("variante inconnue : sort de base", CharacterData.for_id(&"avare", {1: &"avare_fantome"}).spells[0].id == &"avare_coup_de_coffre")
	_check("variante sur le mauvais slot = null", AvareKit.variant(2, &"avare_coffre_belier") == null and AvareKit.variant(1, &"nope") == null)
	for slot in LOADOUT:
		var sd := AvareKit.variant(int(slot), LOADOUT[slot])
		_check("variant(%d) chargée, coef > 0, recharge > 0" % slot, sd != null and sd.coef > 0.0 and sd.base_cooldown > 0.0)
	# garde-fou d'équilibrage : coefficients ajustés au simulateur (±15 % du sort de base), à ne changer qu'avec une nouvelle mesure
	_check("coefs mesurés au simulateur", _near(AvareKit.RAM_COEF, 0.9) and _near(AvareKit.TRICK_COEF, 1.5)
			and _near(AvareKit.GRAB_COEF, 2.0) and _near(AvareKit.BURIED_BASE_COEF, 4.0))

	# --- characters.json ---------------------------------------------------------------------------
	print("characters.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var entry: Dictionary = {}
	for c in data:
		if c is Dictionary and str(c.get("id", "")) == "avare":
			entry = c
	var declared := {}
	var spells_json: Array = entry.get("spells", [])
	for i in spells_json.size():
		for v in spells_json[i].get("variants", []):
			declared[i + 1] = str(v.get("id", ""))
			_check("%s : nom, description et condition présents" % v.get("id", ""),
					str(v.get("name", "")) != "" and str(v.get("desc", "")) != "" and str(v.get("unlock_text", "")) != "" and v.has("unlock_rule"))
	_check("4 variantes déclarées (une par slot)", declared.size() == 4, str(declared))
	_check("ids déclarés = ids codés", declared.get(1) == "avare_coffre_belier" and declared.get(2) == "avare_piece_truquee"
			and declared.get(3) == "avare_saisie" and declared.get(4) == "avare_tresor_enterre", str(declared))
	var all_coded := true
	for slot in declared:
		all_coded = all_coded and AvareKit.variant(int(slot), StringName(declared[slot])) != null
	_check("chaque variante déclarée est codée", all_coded)

	# --- règles de déblocage -----------------------------------------------------------------------
	print("Déblocage")
	var chars: Array = data
	var prof := FakeProfile.new()
	_check("Bélier : victoire avec Avare", VU.evaluate(prof, chars, {"victory": true, "character": "avare", "mode": "moyen", "stage": 5}).has(&"spell:avare_coffre_belier"))
	_check("Bélier : victoire d'un autre = non", not VU.evaluate(prof, chars, {"victory": true, "character": "rictus", "stage": 5}).has(&"spell:avare_coffre_belier"))
	_check("Bélier : défaite = non", not VU.evaluate(prof, chars, {"victory": false, "character": "avare", "stage": 3}).has(&"spell:avare_coffre_belier"))
	prof.stats["avare.coins_picked"] = 499.0
	_check("Pièce truquée : 499 pièces = non", not VU.evaluate(prof, chars, {"character": "avare", "stage": 1}).has(&"spell:avare_piece_truquee"))
	prof.stats["avare.coins_picked"] = 500.0
	_check("Pièce truquée : 500 pièces", VU.evaluate(prof, chars, {"character": "avare", "stage": 1}).has(&"spell:avare_piece_truquee"))
	prof.stats["avare.ransom_gold"] = 1999.0
	_check("Saisie : 1 999 or de primes = non", not VU.evaluate(prof, chars, {"character": "avare", "stage": 1}).has(&"spell:avare_saisie"))
	prof.stats["avare.ransom_gold"] = 2000.0
	_check("Saisie : 2 000 or de primes", VU.evaluate(prof, chars, {"character": "avare", "stage": 1}).has(&"spell:avare_saisie"))
	_check("Trésor : boss de l'étage 2 non tué = non", not VU.evaluate(prof, chars, {"character": "avare", "stage": 2}).has(&"spell:avare_tresor_enterre"))
	prof.stats["avare.floor2_boss_kills"] = 1.0
	_check("Trésor : boss de l'étage 2 tué", VU.evaluate(prof, chars, {"character": "avare", "stage": 3}).has(&"spell:avare_tresor_enterre"))
	prof.unlocked_spells = [&"avare_saisie"]
	_check("variante déjà possédée : pas ré-annoncée", not VU.evaluate(prof, chars, {"character": "avare", "stage": 1}).has(&"spell:avare_saisie"))

	# --- en jeu : joueur avec les 4 variantes ------------------------------------------------------
	RunState.level = 1
	RunState.character = &"avare"
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
	_check("kit Avare", _kit is AvareKit)
	_check("sorts du joueur = variantes", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["avare_coffre_belier", "avare_piece_truquee", "avare_saisie", "avare_tresor_enterre"], str(_player.get_spell_cooldowns().map(func(c): return c.id)))

	print("Sort 1 : Coffre-bélier")
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_player.apply_stats({"crit_chance": -0.05})
	var front := _fake(Vector2(3.0 * U, 0)) # dans la ligne de 3,5 u
	var far := _fake(Vector2(5.0 * U, 0)) # hors portée
	var cast_ok: bool = _player.spells.cast(1)
	await get_tree().physics_frame
	_check("bélier en attente de la frame d'impact", cast_ok and _kit.has_pending())
	_kit._on_action_impact(&"swing") # frame d'impact de l'anim de balayage
	_check("cible dans la ligne touchée", not front.taken.is_empty(), str(front.taken))
	_check("cible hors portée intacte", far.taken.is_empty(), str(far.taken))

	# --- nettoyage --------------------------------------------------------------------------------
	RunState.loadout = {}
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
