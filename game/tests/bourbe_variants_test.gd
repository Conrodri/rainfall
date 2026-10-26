extends Node
## Test headless des variantes de sorts de Bourbe (docs/Variantes_Sorts.md §2.8) : substitution par
## CharacterData.for_id, variantes déclarées dans characters.json = variantes codées, règles de déblocage,
## portée de la Gifle (2,6 u) et rayon de provocation par leurre (Decoy.provoke_range_u).
## L'équilibrage (±15 % du sort de base) se mesure au simulateur : art/tools/night/balance_sim.py --loadout=slot:id.
## godot --headless --path game res://tests/bourbe_variants_test.tscn

class FakeProfile extends RefCounted:
	var stats := {}
	var unlocked_spells: Array = []

	func stat(key: String) -> float:
		return float(stats.get(key, 0.0))


const VU := preload("res://scripts/save/variant_unlocks.gd")
const LOADOUT := {1: &"bourbe_crachat_de_vase", 2: &"bourbe_bouture", 3: &"bourbe_eclatement", 4: &"bourbe_maree_de_vase"}
const U := 64.0

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _run() -> void:
	print("Substitution")
	var base_cd := CharacterData.for_id(&"bourbe", {})
	_check("sans loadout : sorts de base", base_cd.spells.map(func(s): return String(s.id)) == ["gifle_de_vase", "detacher", "rappel", "bourbier"])
	var var_cd := CharacterData.for_id(&"bourbe", LOADOUT)
	_check("4 variantes substituées", var_cd.spells.map(func(s): return String(s.id)) == ["bourbe_crachat_de_vase", "bourbe_bouture", "bourbe_eclatement", "bourbe_maree_de_vase"], str(var_cd.spells.map(func(s): return s.id)))
	_check("slots conservés, slot 1 auto", var_cd.spells.map(func(s): return s.slot) == [1, 2, 3, 4] and var_cd.spells[0].is_auto)
	_check("variant_of", var_cd.variant_of(1) == &"bourbe_crachat_de_vase" and var_cd.variant_of(4) == &"bourbe_maree_de_vase")
	var mix := CharacterData.for_id(&"bourbe", {3: &"bourbe_eclatement"})
	_check("substitution partielle", mix.spells[0].id == &"gifle_de_vase" and mix.spells[2].id == &"bourbe_eclatement" and mix.spells[3].id == &"bourbier")
	_check("variante inconnue : sort de base", CharacterData.for_id(&"bourbe", {1: &"bourbe_fantome"}).spells[0].id == &"gifle_de_vase")
	_check("variant() inconnue = null", BourbeKit.variant(1, &"nope") == null and BourbeKit.variant(2, &"bourbe_eclatement") == null)

	print("characters.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var bj: Dictionary = {}
	for c in data:
		if c is Dictionary and str(c.get("id", "")) == "bourbe":
			bj = c
	var declared := {}
	var spells_json: Array = bj.get("spells", [])
	for i in spells_json.size():
		for v in spells_json[i].get("variants", []):
			declared[i + 1] = str(v.get("id", ""))
	_check("4 variantes déclarées (une par slot)", declared.size() == 4, str(declared))
	_check("ids déclarés = ids codés", declared.get(1) == "bourbe_crachat_de_vase" and declared.get(2) == "bourbe_bouture"
			and declared.get(3) == "bourbe_eclatement" and declared.get(4) == "bourbe_maree_de_vase", str(declared))
	var all_coded := true
	for slot in declared:
		all_coded = all_coded and BourbeKit.variant(int(slot), StringName(declared[slot])) != null
	_check("chaque variante déclarée est codée et chargeable", all_coded)
	var desc2: String = str(spells_json[1].get("desc", "")) if spells_json.size() > 1 else ""
	_check("desc de Détacher : modèle masse (plus de PV payés)", desc2.contains("PV max") and not desc2.contains("sous 50"), desc2)

	print("Déblocage")
	var chars: Array = data
	var prof := FakeProfile.new()
	var win := {"victory": true, "character": "bourbe", "mode": "moyen", "stage": 5}
	_check("Crachat : victoire avec Bourbe", VU.evaluate(prof, chars, win).has(&"spell:bourbe_crachat_de_vase"))
	_check("Crachat : défaite = non", not VU.evaluate(prof, chars, {"victory": false, "character": "bourbe", "stage": 2}).has(&"spell:bourbe_crachat_de_vase"))
	_check("Crachat : victoire d'un autre perso = non", not VU.evaluate(prof, chars, {"victory": true, "character": "ardent", "stage": 5}).has(&"spell:bourbe_crachat_de_vase"))
	var ctx := {"character": "bourbe", "stage": 1}
	for pair in [["bourbe_mottes_recalled", 200.0, "bourbe_bouture"], ["bourbe_rappel_hits", 800.0, "bourbe_eclatement"], ["bourbe_miniboss_4mottes", 3.0, "bourbe_maree_de_vase"]]:
		var key: String = pair[0]
		var need: float = pair[1]
		var vid: StringName = StringName("spell:" + str(pair[2]))
		prof.stats.clear()
		prof.stats[key] = need - 1.0
		_check("%s : %d = non" % [pair[2], int(need) - 1], not VU.evaluate(prof, chars, ctx).has(vid))
		prof.stats[key] = need
		_check("%s : %d = oui" % [pair[2], int(need)], VU.evaluate(prof, chars, ctx).has(vid))
	prof.unlocked_spells = [&"bourbe_bouture"]
	prof.stats["bourbe_mottes_recalled"] = 300.0
	_check("variante déjà possédée : pas ré-annoncée", not VU.evaluate(prof, chars, ctx).has(&"spell:bourbe_bouture"))

	print("Portée de la Gifle")
	_check("Gifle 2,6 u (portée, rayon, déclenchement)", is_equal_approx(BourbeKit.SLAP_RADIUS_U, 2.6)
			and is_equal_approx(base_cd.spells[0].radius_u, 2.6) and is_equal_approx(base_cd.spells[0].range_u, 2.6)
			and is_equal_approx(base_cd.spells[0].trigger_range_u, 2.6))

	print("Provocation par leurre")
	var d := Decoy.new()
	add_child(d)
	d.global_position = Vector2.ZERO
	var at := func(u: float) -> Decoy: return Decoy.nearest_to(Vector2(u * U, 0), Decoy.PROVOKE_RANGE_U * U)
	_check("leurre par défaut : 4 u", is_equal_approx(d.provoke_range_u, 4.0) and at.call(3.9) == d and at.call(4.2) == null)
	d.provoke_range_u = 5.0
	_check("leurre à 5 u : provoque à 4,9 u, pas à 5,2 u", at.call(4.9) == d and at.call(5.2) == null)
	var big := BourbeMotte.new()
	add_child(big)
	big.global_position = Vector2(100.0 * U, 0)
	big.provoke_range_u = 5.0
	big.lures_bosses = true
	_check("boss : lure à 5 u seulement si lures_bosses", Decoy.nearest_boss_lure(Vector2(104.9 * U, 0), Decoy.PROVOKE_RANGE_U * U) == big
			and Decoy.nearest_boss_lure(Vector2(105.2 * U, 0), Decoy.PROVOKE_RANGE_U * U) == null
			and Decoy.nearest_boss_lure(Vector2(3.0 * U, 0), Decoy.PROVOKE_RANGE_U * U) == null)
	d.queue_free()
	big.queue_free()
	await get_tree().process_frame
	_check("BIG_PROVOKE_U = 5", is_equal_approx(BourbeKit.BIG_PROVOKE_U, 5.0))

	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
