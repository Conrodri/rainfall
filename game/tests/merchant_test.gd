extends Node
## Marchand de l'étage 3 : présent seulement à l'étage 3 (cartes A et B), 4 objets une par rareté, prix = petit coffre de
## l'étage x 1,5 / 2 / 2,5 / 4, achat unique par objet, or insuffisant refusé, placement, sauvegarde.
## godot --headless --path game res://tests/merchant_test.tscn   (sortie « RESULT: OK »)

const UNIT := 64.0

class FakePlayer extends Node2D:
	func gold_mult() -> float:
		return 1.0


var _fails := 0


func _ready() -> void:
	await _run()
	FloorPlan.force_variant = ""
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label)


func _run() -> void:
	var player := FakePlayer.new()
	player.add_to_group(&"player")
	add_child(player)
	var mgr := StageManager.new()
	add_child(mgr)

	# --- Équilibrage
	_check("étage du marchand = 3", Balance.MERCHANT_STAGE == 3)
	var mult: Dictionary = Balance.MERCHANT_PRICE_MULT
	_check("multiplicateurs 1,5 / 2 / 2,5 / 4", is_equal_approx(float(mult[&"commun"]), 1.5) and is_equal_approx(float(mult[&"peu_commun"]), 2.0) and is_equal_approx(float(mult[&"rare"]), 2.5) and is_equal_approx(float(mult[&"legendaire"]), 4.0))

	# --- Présence : étage 3 seulement, cartes A et B
	var maps_seen := {}
	for variant in ["A", "B"]:
		FloorPlan.force_variant = variant
		for s in 3:
			RunState.start_run(&"moyen", 500 + s)
			mgr.reset_run()
			for st in 5:
				RunState.stage = st + 1
				mgr.start_stage()
				if RunState.stage != 3:
					_check("pas de marchand à l'étage %d" % RunState.stage, mgr.merchant == null)
					continue
				maps_seen[mgr.map_id] = true
				var m := mgr.merchant
				_check("marchand à l'étage 3 (%s, seed %d)" % [mgr.map_id, 500 + s], m != null)
				if m == null:
					continue
				_check("interagissable", m.is_in_group(&"interactable") and m.is_in_group(&"merchants"))
				_check("4 objets", m.stock.size() == 4)
				var qs: Array = []
				var ids := {}
				for e: Dictionary in m.stock:
					qs.append(String(e["quality"]))
					ids[e["id"]] = true
					_check("qualité de l'objet = rareté de la ligne (%s)" % e["id"], str(ItemDB.get_item(e["id"]).get("quality", "")) == String(e["quality"]))
					_check("pas vendu au départ", not bool(e["sold"]))
				_check("une rareté chacun, dans l'ordre", qs == ["commun", "peu_commun", "rare", "legendaire"])
				_check("4 objets différents", ids.size() == 4)
				var pos := m.position
				_check("à >= 4 u du départ", pos.distance_to(mgr.map.get_player_start()) >= 4.0 * UNIT - 0.1)
				for p in mgr.pillars:
					_check("à >= 4 u d'un pilier", pos.distance_to(p.position) >= 4.0 * UNIT - 0.1)
				for c in mgr.chests:
					_check("à >= 4 u d'un coffre", pos.distance_to(c.position) >= 4.0 * UNIT - 0.1)
				for mk in mgr.map.get_event_markers():
					_check("à >= 6 u d'une case d'atelier", pos.distance_to(mgr.map.local_pos(mk)) >= 6.0 * UNIT - 0.1)
	_check("cartes A et B de l'étage 3 testées", maps_seen.size() == 2)
	FloorPlan.force_variant = ""

	# --- Sans fin : pas de marchand
	RunState.start_run(&"moyen", 11)
	mgr.reset_run()
	mgr.endless = true
	RunState.stage = 3
	mgr.start_stage()
	_check("mode sans fin : pas de marchand", mgr.merchant == null)
	mgr.endless = false

	# --- Déterminisme : mêmes objets et même place pour la même run
	RunState.start_run(&"moyen", 21)
	mgr.reset_run()
	RunState.stage = 3
	RunState.rng.seed = 7
	mgr.start_stage()
	var a: Dictionary = mgr.merchant.to_dict()
	RunState.rng.seed = 7
	mgr.start_stage()
	var b: Dictionary = mgr.merchant.to_dict()
	_check("même run = même marchand", a == b)

	# --- Ne consomme pas RunState.rng
	RunState.start_run(&"moyen", 21)
	mgr.reset_run()
	var st0: int = RunState.rng.state
	var r := RandomNumberGenerator.new()
	r.seed = 3
	Merchant.roll_stock(r)
	_check("roll_stock ne touche pas RunState.rng", RunState.rng.state == st0)

	# --- Prix : petit coffre de l'étage x multiplicateur, relu à l'achat
	RunState.start_run(&"moyen", 21)
	mgr.reset_run()
	RunState.stage = 3
	mgr.start_stage()
	var m3 := mgr.merchant
	var small := Chest.price_of(&"petit", RunState.floor_start_d, 3)
	for q in [&"commun", &"peu_commun", &"rare", &"legendaire"]:
		_check("prix %s = petit x %s" % [q, mult[q]], absf(m3.price_for(q) - small * float(mult[q])) < 0.001)
	_check("légendaire > rare > peu commun > commun", m3.price_for(&"legendaire") > m3.price_for(&"rare") and m3.price_for(&"rare") > m3.price_for(&"peu_commun") and m3.price_for(&"peu_commun") > m3.price_for(&"commun"))

	# --- Achat
	_check("hors de portée : pas d'interaction", not m3.can_interact())
	m3.global_position = Vector2.ZERO
	player.global_position = Vector2.ZERO
	_check("à portée : interaction", m3.can_interact())
	_check("interact() ouvre l'écran", m3.interact() and m3.is_open())
	var ui := m3._ui
	ui._lock = false
	RunState.gold = 0.0
	_check("or insuffisant : refus", not ui.buy(0))
	_check("rien d'acheté sans or", RunState.items.is_empty() and not bool(m3.stock[0]["sold"]))
	RunState.gold = small * 100.0
	var id0 := StringName(m3.stock[0]["id"])
	var gold0 := RunState.gold
	var cost0 := ui.price_of(0)
	_check("achat de l'objet commun", ui.buy(0))
	_check("or débité du prix commun", absf(gold0 - RunState.gold - cost0) < 0.01 and absf(cost0 - small * 1.5) < 0.01)
	_check("objet reçu", RunState.stacks(id0) == 1)
	_check("marqué vendu", bool(m3.stock[0]["sold"]) and m3.unsold_count() == 3)
	var gold1 := RunState.gold
	_check("deuxième achat du même objet refusé", not ui.buy(0))
	_check("or inchangé", RunState.gold == gold1 and RunState.stacks(id0) == 1)
	_check("achat légendaire", ui.buy(3) and bool(m3.stock[3]["sold"]))
	_check("compteur d'achats", float(RunState.counters.get("merchant.buys", 0.0)) == 2.0)
	ui.close_shop()
	await get_tree().process_frame
	_check("écran fermé, jeu relancé", not m3.is_open() and not get_tree().paused)

	# --- Sauvegarde : les objets vendus restent vendus
	var json: Dictionary = JSON.parse_string(JSON.stringify(mgr.to_dict()))
	mgr.from_dict(json)
	_check("marchand restauré", mgr.merchant != null and mgr.merchant.stock.size() == 4)
	if mgr.merchant != null:
		var sold: Array = []
		for e: Dictionary in mgr.merchant.stock:
			sold.append(bool(e["sold"]))
		_check("vendus conservés", sold == [true, false, false, true])
