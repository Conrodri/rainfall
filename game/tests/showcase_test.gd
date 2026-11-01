extends Node
## Coffres à vitrine (docs/Boucle_Etage_Design.md §2.5) : 2 par étage parmi les petits coffres, 3 objets visibles de même
## qualité, prix x1,2, plafond de coffres spéciaux, tirage déterministe, achat, sauvegarde.
## godot --headless --path game res://tests/showcase_test.tscn   (sortie « RESULT: OK »)

class FakePlayer extends Node2D:
	func gold_mult() -> float:
		return 1.0


var _fails := 0


func _ready() -> void:
	await _run()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label)


func _showcases(mgr: StageManager) -> Array:
	var out: Array = []
	for c in mgr.chests:
		if is_instance_valid(c) and c.has_method(&"is_showcase") and c.is_showcase():
			out.append(c)
	return out


func _run() -> void:
	var player := FakePlayer.new()
	player.add_to_group(&"player")
	add_child(player)
	var mgr := StageManager.new()
	add_child(mgr)

	# --- Équilibrage
	_check("2 vitrines par étage", Balance.CHEST_SHOWCASE_PER_STAGE == 2)
	_check("3 objets visibles", Balance.CHEST_SHOWCASE_COUNT == 3)
	_check("prix x1,2", is_equal_approx(Balance.CHEST_SHOWCASE_PRICE_P, 1.2))
	_check("plafond de 2 coffres spéciaux par étage", Balance.CHEST_SPECIAL_MAX_PER_STAGE == 2)

	# --- Tirage sur plusieurs seeds, étages 1-4
	var total := 0
	for s in 4:
		RunState.start_run(&"moyen", 300 + s)
		mgr.reset_run()
		for st in 4:
			RunState.stage = st + 1
			mgr.start_stage()
			var vit := _showcases(mgr)
			total += vit.size()
			_check("étage %d (seed %d) : 2 vitrines" % [RunState.stage, 300 + s], vit.size() == 2)
			var specials := 0
			var seen := {}
			for c in vit:
				_check("vitrine = petit coffre", c.kind == &"petit")
				_check("3 objets", c.offer.size() == 3)
				var uniq := {}
				for id in c.offer:
					uniq[id] = true
					seen[id] = true
					_check("objet de même qualité que la vitrine", str(ItemDB.get_item(id).get("quality", "")) == str(c.offer_quality))
				_check("3 objets différents", uniq.size() == 3)
				_check("prix = petit x1,2", absf(c.current_price() - Chest.price_of(&"petit", c.get("_price_d"), c.stage) * 1.2) < 0.01)
				specials += 1
			_check("aucun objet en double entre vitrines", seen.size() == vit.size() * 3)
			var normal_price := 0.0
			for c in mgr.chests:
				if c.kind == &"petit" and not c.is_showcase():
					normal_price = c.current_price()
					break
			if normal_price > 0.0:
				_check("vitrine plus chère qu'un petit coffre normal", vit[0].current_price() > normal_price * 1.19)
			_check("plafond de coffres spéciaux respecté", specials <= Balance.CHEST_SPECIAL_MAX_PER_STAGE)
	_check("vitrines produites", total == 32)

	# --- Déterminisme (graine propre : mêmes offres pour la même run et le même étage)
	RunState.start_run(&"moyen", 42)
	mgr.reset_run()
	RunState.stage = 2
	RunState.rng.seed = 7
	mgr.start_stage()
	var a: Array = []
	for c in _showcases(mgr):
		a.append([c.position, c.offer])
	RunState.rng.seed = 7
	mgr.start_stage()
	var b: Array = []
	for c in _showcases(mgr):
		b.append([c.position, c.offer])
	_check("même run et même étage = mêmes vitrines", a == b and a.size() == 2)

	# --- Pas de consommation de RunState.rng par le tirage
	RunState.start_run(&"moyen", 42)
	mgr.reset_run()
	RunState.stage = 2
	var st0: int = RunState.rng.state
	mgr._assign_showcases([{"kind": "petit", "marker": 0}, {"kind": "petit", "marker": 1}, {"kind": "grand", "marker": 2}])
	_check("RunState.rng intact", RunState.rng.state == st0)

	# --- Plafond : une entrée déjà spéciale réduit le budget
	var entries: Array = [{"kind": "petit", "marker": 0, "special": "guardian"}, {"kind": "petit", "marker": 1}, {"kind": "petit", "marker": 2}, {"kind": "petit", "marker": 3}]
	mgr._assign_showcases(entries)
	var n_special := 0
	for e: Dictionary in entries:
		if String(e.get("special", "")) != "":
			n_special += 1
	_check("plafond : 2 spéciaux au plus (1 déjà là + 1 vitrine)", n_special == 2)
	var full: Array = [{"kind": "petit", "marker": 0, "special": "x"}, {"kind": "petit", "marker": 1, "special": "y"}, {"kind": "petit", "marker": 2}]
	mgr._assign_showcases(full)
	_check("plafond atteint : aucune vitrine ajoutée", String((full[2] as Dictionary).get("special", "")) == "")

	# --- Achat : or débité, 3 objets, un choisi
	RunState.start_run(&"moyen", 42)
	mgr.reset_run()
	RunState.stage = 1
	mgr.start_stage()
	var ch: Chest = _showcases(mgr)[0]
	var price := ch.current_price()
	RunState.gold = price - 1.0
	_check("or insuffisant : refus", not ch.try_open())
	_check("or inchangé après refus", absf(RunState.gold - (price - 1.0)) < 0.001)
	RunState.gold = price + 5.0
	_check("assez d'or : ouverture", ch.try_open())
	_check("or débité du prix vitrine", absf(RunState.gold - 5.0) < 0.01)
	var ui: ShowcaseUI = null
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n is ShowcaseUI:
			ui = n
	if ui == null:
		for n in get_children():
			if n is ShowcaseUI:
				ui = n
	_check("écran vitrine ouvert", ui != null)
	if ui != null:
		_check("3 objets proposés", ui.offered.size() == 3)
		var id := StringName(ui.offered[1])
		var before := RunState.stacks(id)
		ui._lock = false
		ui.take(1)
		_check("objet choisi ajouté", RunState.stacks(id) == before + 1)
		_check("un seul objet pris", RunState.items.size() == 1)

	# --- Sauvegarde : mêmes vitrines après aller-retour JSON
	RunState.start_run(&"moyen", 77)
	mgr.reset_run()
	RunState.stage = 3
	mgr.start_stage()
	var before_save: Array = []
	for c in _showcases(mgr):
		before_save.append(c.offer)
	var json: Dictionary = JSON.parse_string(JSON.stringify(mgr.to_dict()))
	mgr.from_dict(json)
	var after_save: Array = []
	for c in _showcases(mgr):
		after_save.append(c.offer)
	_check("vitrines identiques après sauvegarde", before_save.size() == 2 and before_save == after_save)
