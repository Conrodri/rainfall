extends Node
## Tests du loot et des stats d'items.
## godot --headless --path game res://tests/loot_test.tscn   (RESULT: OK ; scène car autoloads requis)

var _fails := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("ok   ", label)
	else:
		_fails += 1
		print("FAIL ", label, " ", detail)


func _near(label: String, got: float, want: float, tol: float) -> void:
	_check(label, absf(got - want) <= tol, "got %f want %f (+-%f)" % [got, want, tol])


func _ready() -> void:
	ItemDB.reload()
	_check("items.json chargé (48 items, aimants retirés)", ItemDB.all_ids().size() == 48, str(ItemDB.all_ids().size()))
	_test_distribution()
	_test_luck()
	_test_pair_exclusion()
	_test_item_stats()
	_test_session()
	print("RESULT: ", "OK" if _fails == 0 else "FAILED (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _test_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var n := 100000
	for kind in Balance.CHEST_QUALITY_TABLE:
		var counts := {}
		for i in n:
			var q: StringName = LootRoller.roll_quality(kind, rng)["quality"]
			counts[q] = counts.get(q, 0) + 1
		var table: Dictionary = Balance.CHEST_QUALITY_TABLE[kind]
		for q in LootRoller.ORDER:
			var want: float = float(table.get(q, 0)) / 100.0
			_near("d100 %s/%s" % [kind, q], float(counts.get(q, 0)) / n, want, 0.01)


func _test_luck() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rare_plus := 0
	var n := 20000
	for i in n:
		if LootRoller.quality_rank(LootRoller.roll_quality(&"petit", rng, 3)["quality"]) >= 2:
			rare_plus += 1
	# P(max de 4 d100 >= 99) = 1 - 0.98^4
	_near("Chance +3 : Rare petit coffre", float(rare_plus) / n, 1.0 - pow(0.98, 4), 0.006)


func _test_pair_exclusion() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var table: Array = ItemDB.ids_of_quality(&"rare")
	var ok := true
	var distinct := true
	for i in 500:
		var shown: Array = []
		var first := LootRoller.pick_pair(&"rare", {}, shown, rng)
		shown.append_array(first)
		var second := LootRoller.pick_pair(&"rare", {}, shown, rng)
		if first[0] == first[1] or second[0] == second[1]:
			distinct = false
		for id in second:
			if id in first:
				ok = false
	_check("paire : 2 items distincts", distinct)
	_check("relance : items montrés exclus", ok)
	# Table trop petite : 10 exclus sur 11 -> complète sans planter, reste distinct
	var excl := table.slice(0, table.size() - 1)
	var p := LootRoller.pick_pair(&"rare", {}, excl, rng)
	_check("table réduite : 2 items, 1 frais", p.size() == 2 and p[0] == table[table.size() - 1] and p[0] != p[1])
	# Tout exclu : doublons autorisés mais 2 items renvoyés
	var p2 := LootRoller.pick_pair(&"rare", {}, table, rng)
	_check("tout exclu : 2 items quand même", p2.size() == 2)
	# Poids : possédé x0.6
	var owned_id: String = table[0]
	var cnt := 0
	var m := 30000
	for i in m:
		if LootRoller.pick_pair(&"rare", {owned_id: 1}, [], rng)[0] == owned_id:
			cnt += 1
	var w_owned := 0.6
	var others := 0.0
	for id in table:
		if id != owned_id:
			others += LootRoller.item_weight(id, {owned_id: 1}, LootRoller.build_tags({owned_id: 1}))
	var expect := LootRoller.item_weight(owned_id, {owned_id: 1}, LootRoller.build_tags({owned_id: 1}))
	expect /= (expect + others)
	_near("poids possédé/tag (1er tirage)", float(cnt) / m, expect, 0.01)
	_check("poids possédé < 1", LootRoller.item_weight(owned_id, {owned_id: 1}, {}) == w_owned)


func _test_item_stats() -> void:
	var s := ItemStats.compute({&"pierre_a_aiguiser": 3})
	_near("linéaire x3 : damage_add", s["damage_add"], 0.30, 1e-6)
	s = ItemStats.compute({&"antidote": 3})
	_near("hyperbolique x3 (k = a = 0.25)", s["dot_taken_reduction"], 1.0 - 1.0 / (1.0 + 0.25 * 3), 1e-6)
	var s1 := ItemStats.compute({&"antidote": 1})
	_near("hyperbolique x1 = 20 %", s1["dot_taken_reduction"], 0.2, 1e-6)
	_near("Pavois x1 : blocage 13 % (Tougher Times)", ItemStats.compute({&"pavois_fele": 1})["dodge"], 0.15 / 1.15, 1e-6)
	# Armure du colosse : PV linéaires, réduction hyperbolique, dégâts ×0,9ⁿ (stat_stack)
	s = ItemStats.compute({&"armure_du_colosse": 2})
	_near("colosse x2 : PV +100 %", s["max_hp_pct"], 1.0, 1e-6)
	_near("colosse x2 : réduction H", s["damage_taken_reduction"], 1.0 - 1.0 / 1.5, 1e-6)
	_near("colosse x2 : dégâts ×0,81", s["damage_mult"], 0.81, 1e-6)
	s = ItemStats.compute({&"botte_rapiecee": 10})
	_near("plafond move_speed", s["move_speed"], Balance.MOVE_SPEED_BONUS_CAP, 1e-6)
	# Recharge multiplicative (Alien Head) entre items
	s = ItemStats.compute({&"sablier_fele": 2, &"chronometre_brise": 1})
	_near("recharge 0,92² × 0,75", s["cooldown_mult"], 0.92 * 0.92 * 0.75, 1e-6)
	_near("cooldown effectif plancher 25 %", Balance.effective_cooldown(8.0, 0.1), 2.0, 1e-6)
	# Bug corrigé : Faveur du marchand donne bien de la Chance (stack linéaire entier)
	_near("Faveur x2 : Chance 2", ItemStats.compute({&"faveur_du_marchand": 2})["luck"], 2.0, 1e-6)
	# Stat [premier, suivants] : Cœur de glace +50 % puis +25 %
	_near("Cœur de glace x3 : +100 %", ItemStats.compute({&"coeur_de_glace": 3})["slowed_target_damage_add"], 1.0, 1e-6)
	# Œil du prédateur : +5 % de crit une seule fois, ×2 + 0,5 n
	s = ItemStats.compute({&"oeil_du_predateur": 3})
	_near("Œil x3 : crit +5 % (fixe)", s["crit_chance"], 0.05, 1e-6)
	_near("Œil x3 : crit_mult_add 1,5", s["crit_mult_add"], 1.5, 1e-6)
	_near("plafond XP +100 %", ItemStats.compute({&"eclat_d_experience": 15})["xp_mult"], 1.0, 1e-6)
	# procs et specials
	var burn_id := ""
	var special_id := ""
	for id in ItemDB.all_ids():
		var it := ItemDB.get_item(id)
		if burn_id == "" and not it["procs"].is_empty() and it["procs"][0]["status"] == "burn":
			burn_id = id
		if special_id == "" and it.get("special") != null and it["stack"] == "L":
			special_id = id
	if burn_id != "":
		var c: float = ItemDB.get_item(burn_id)["procs"][0]["chance"]
		s = ItemStats.compute({StringName(burn_id): 2})
		_check("proc burn agrégé (1 entrée)", s["procs"].size() == 1 and s["procs"][0]["status"] == &"burn")
		_near("proc burn chance x2 linéaire", s["procs"][0]["chance"], 2.0 * c, 1e-6)
	# Bug corrigé : deux items aux procs identiques ne fusionnent plus leurs chances
	s = ItemStats.compute({&"etincelle": 1, &"cristal_de_feu": 1})
	_check("procs distincts par item", s["procs"].size() == 2, str(s["procs"]))
	# Clés `_stack` des données : Givre durée 2 s + 2 s, Venin 300 % n, Éclair 3 + 2 cibles
	s = ItemStats.compute({&"givre": 3})
	_near("Givre x3 : 6 s", s["procs"][0]["data"]["duration"], 6.0, 1e-6)
	_check("Givre : clé _stack retirée", not s["procs"][0]["data"].has("duration_stack"))
	_near("Venin x2 : 600 %", ItemStats.compute({&"venin_concentre": 2})["procs"][0]["data"]["hit_fraction"], 6.0, 1e-6)
	_near("Éclair x2 : 5 cibles", ItemStats.compute({&"eclair_en_bouteille": 2})["procs"][0]["data"]["targets"], 5.0, 1e-6)
	_near("Flocon x1 : chance H 13 %", ItemStats.compute({&"flocon": 1})["procs"][0]["chance"], 0.15 / 1.15, 1e-6)
	if special_id != "":
		s = ItemStats.compute({StringName(special_id): 2})
		var sp := StringName(ItemDB.get_item(special_id)["special"])
		_check("special -> stacks", s["specials"].get(sp, 0) == 2, str(s["specials"]))
	_check("items vides", ItemStats.compute({}).get("procs") == [] and ItemStats.compute({})["specials"] == {})


func _test_session() -> void:
	RunState.start_run(&"moyen", 4242)
	ChestSession.reset_run_counters()
	var sess := ChestSession.new(&"petit", 1, 150.0)
	sess.start()
	_check("session : 2 items", sess.offered.size() == 2)
	var before := sess.offered.duplicate()
	var q := sess.quality
	_check("pub : relance ok", sess.do_ad_reroll())
	_check("pub : 2e relance sur le même coffre refusée", not sess.do_ad_reroll())
	for id in sess.offered:
		_check("relance pub : item nouveau", not (id in before))
	_check("relance : même qualité", ItemDB.get_item(sess.offered[0])["quality"] == str(q))
	_check("or : pas assez", not sess.do_gold_reroll())
	RunState.add_gold(10000.0)
	var g := RunState.gold
	var price := sess.gold_reroll_price()
	_near("prix relance or = 0.6 x prix", price, 90.0, 1e-6)
	_check("or : relance ok", sess.do_gold_reroll() and absf(g - RunState.gold - 90.0) < 1e-6)
	_near("prix suivant x1.5", sess.gold_reroll_price(), 135.0, 1e-6)
	for id in sess.offered:
		_check("relance or : pas de doublon avec montrés", sess.shown.count(id) == 1)
	# plafond run : 3
	var done := 1
	for i in 4:
		var s2 := ChestSession.new(&"petit", 1, 150.0)
		s2.start()
		if s2.do_ad_reroll():
			done += 1
	_check("plafond 3 pubs / run", done == 3, str(done))
	sess.choose(get_tree(), 0)
	_check("choix -> RunState.add_item", RunState.stacks(StringName(sess.offered[0])) >= 1)
