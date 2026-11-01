extends Node
## Boussole de rouille (docs/Ateliers_Chiffres.md §7) : tags proposés, garantie sur la carte A du premier tirage, 2 charges,
## petits et grands coffres seulement, charge conservée quand la qualité n'a pas le tag, relances normales, station, sauvegarde.
## godot --headless --path game res://tests/compass_test.tscn   (sortie « RESULT: OK »)

var _fails := 0


func _ready() -> void:
	_run()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	print("ok   " if ok else "FAIL ", msg)
	if not ok:
		_fails += 1


func _quiet(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", msg)


func _has_tag(id: String, tag: String) -> bool:
	return tag in ItemDB.get_item(id).get("tags", [])


func _first_with_tag(tag: String) -> StringName:
	for id in ItemDB.all_ids():
		if _has_tag(str(id), tag):
			return StringName(str(id))
	return &""


func _run() -> void:
	RunState.start_run(&"moyen", 77)
	# --- Constantes (docs/Ateliers_Chiffres.md §7)
	_check(Balance.BOUSSOLE_PRICE_P == 0.0, "Boussole gratuite")
	_check(Balance.BOUSSOLE_CHARGES == 2, "2 charges")
	_check(Balance.BOUSSOLE_TAGS_SHOWN == 6 and Balance.BOUSSOLE_TAGS_BUILD == 4, "6 tags dont 4 du build")
	_check(Balance.BOUSSOLE_CHEST_KINDS.size() == 2 and &"petit" in Balance.BOUSSOLE_CHEST_KINDS and &"large" in Balance.BOUSSOLE_CHEST_KINDS, "petits et grands coffres seulement")

	# --- Tags proposés : 4 du build (les plus présents) + 2 tirés
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	RunState.items = {_first_with_tag("Feu"): 3, _first_with_tag("Givre"): 2, _first_with_tag("Poison"): 1}
	var shown := CompassStation.tags_shown(RunState.items, rng)
	_check(shown.size() == 6, "6 tags proposés (%s)" % str(shown))
	var uniq := {}
	for t in shown:
		uniq[t] = true
	_check(uniq.size() == shown.size(), "tags tous différents")
	var top4: Array = shown.slice(0, 4)
	_check("Feu" in top4 and "Givre" in top4 and "Poison" in top4, "les tags du build sont dans les 4 premiers")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 5
	_check(CompassStation.tags_shown(RunState.items, rng2) == shown, "tirage seedé identique")
	RunState.items = {}
	_check(CompassStation.tags_shown(RunState.items, rng).size() == 6, "sans objet : 6 tags tirés")
	var all_ok := true
	for t in shown:
		var any := false
		for q in LootRoller.ORDER:
			any = any or LootRoller.tag_available(q, str(t))
		all_ok = all_ok and any
	_check(all_ok, "chaque tag proposé est porté par au moins un objet disponible")

	# --- Garantie sur la carte A, 2 charges, petit et grand
	var tag := "Survie"
	var wins := 0
	var misses := 0
	for kind in [&"petit", &"large"]:
		for seed in 150:
			RunState.start_run(&"moyen", 1000 + seed)
			RunState.compass_set(tag)
			var s := ChestSession.new(kind, 1, 50.0)
			s.start()
			var avail := LootRoller.tag_available(s.quality, tag)
			if s.compass_tag == tag:
				wins += 1
				_quiet(_has_tag(str(s.offered[0]), tag), "carte A sans tag : %s %s %s" % [kind, s.quality, str(s.offered)])
				_quiet(int(RunState.compass["charges"]) == 1, "charge non consommée : %s" % str(RunState.compass))
				_quiet(s.offered.size() == 2, "offre != 2")
			else:
				misses += 1
				_quiet(not avail and s.compass_missed == tag and int(RunState.compass["charges"]) == 2, "manque incohérent : %s %s %s" % [kind, s.quality, str(RunState.compass)])
	_check(wins > 20, "la garantie joue sur la plupart des tirages (%d gagnés, %d manques)" % [wins, misses])

	# Deux charges puis plus rien
	RunState.start_run(&"moyen", 31)
	RunState.compass_set("Survie")
	var used := 0
	for i in 12:
		var s2 := ChestSession.new(&"petit", 1, 50.0)
		s2.start()
		if s2.compass_tag != "":
			used += 1
	_check(used <= 2 and int(RunState.compass["charges"]) == 2 - used or used == 2, "au plus 2 usages (%d)" % used)
	if used == 2:
		_check(int(RunState.compass["charges"]) == 0 and String(RunState.compass["tag"]) == "", "tag effacé quand les charges sont épuisées")
		var s3 := ChestSession.new(&"petit", 1, 50.0)
		s3.start()
		_check(s3.compass_tag == "" and s3.compass_missed == "", "plus de garantie ensuite")

	# --- Exclusions : légendaire, boss, guardian ; charge intacte
	for kind in [&"legendaire", &"boss", &"guardian"]:
		RunState.start_run(&"moyen", 9)
		RunState.compass_set("Survie")
		var sx := ChestSession.new(kind, 1, 50.0)
		sx.start()
		_check(sx.compass_tag == "" and sx.compass_missed == "" and int(RunState.compass["charges"]) == 2, "coffre %s : Boussole sans effet, charges intactes" % kind)

	# --- Qualité sans le tag : charge conservée, la carte l'écrit
	RunState.start_run(&"moyen", 11)
	var absent := ""
	for t in CompassStation.catalog_tags():
		if not LootRoller.tag_available(&"commun", str(t)):
			absent = str(t)
			break
	if absent == "":
		print("note : tous les tags existent en commun (cas « tag indisponible » non exerçable)")
	else:
		RunState.compass_set(absent)
		var sm := ChestSession.new(&"petit", 1, 50.0)
		sm.quality = &"commun"
		sm._draw_first()
		_check(sm.compass_tag == "" and sm.compass_missed == absent and int(RunState.compass["charges"]) == 2, "tag %s absent en commun : charge non consommée" % absent)
		_check(sm.compass_note().contains(absent), "la carte l'écrit : « %s »" % sm.compass_note())
		_check(LootRoller.pick_pair_tagged(&"commun", {}, [], RunState.rng, absent).is_empty(), "pick_pair_tagged renvoie [] sans objet du tag")

	# --- Relances : tirage normal, aucune charge dépensée
	var rerolled := false
	for seed in 60:
		RunState.start_run(&"moyen", 2000 + seed)
		RunState.compass_set("Survie")
		var sr := ChestSession.new(&"petit", 1, 50.0)
		sr.start()
		if sr.compass_tag != "":
			var before: Dictionary = RunState.compass.duplicate()
			for k in 5:
				sr._draw()
			_check(RunState.compass == before and sr.compass_tag == "Survie", "relances : charges inchangées")
			rerolled = true
			break
	_check(rerolled, "une garantie a servi à tester les relances")

	# --- Station : un choix, définitif ; sauvegarde
	RunState.start_run(&"moyen", 5)
	var st := CompassStation.new()
	add_child(st)
	_check(st.is_in_group(&"interactable"), "station interagissable")
	_check(not st.can_interact(), "pas d'interaction sans joueur à portée")
	_check(st.choose("Feu") and RunState.compass == {"tag": "Feu", "charges": 2}, "choix : RunState.compass = Feu x2")
	_check(not st.choose("Givre") and String(RunState.compass["tag"]) == "Feu", "station épuisée : un seul choix")
	_check(not st.is_in_group(&"interactable"), "épuisée : retirée des interagissables")
	var st2 := CompassStation.new()
	add_child(st2)
	st2.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
	_check(st2.is_used and st2.chosen_tag == "Feu" and not st2.is_in_group(&"interactable"), "sauvegarde de la station")
	var d: Dictionary = JSON.parse_string(JSON.stringify(RunState.to_dict()))
	RunState.compass = {"tag": "", "charges": 0}
	RunState.from_dict(d)
	_check(RunState.compass == {"tag": "Feu", "charges": 2}, "sauvegarde de run : compass aller-retour")
	RunState.start_run(&"moyen", 6)
	_check(RunState.compass == {"tag": "", "charges": 0}, "nouvelle run : Boussole vide")

	# --- Panneau
	var pnl := CompassPanel.new()
	add_child(pnl)
	pnl.open(shown, {})
	var got: Array = []
	pnl.chosen.connect(func(t: String) -> void: got.append(t))
	_check(get_tree().paused, "panneau : jeu en pause")
	pnl.pick(str(shown[0]))
	_check(got.is_empty(), "verrou d'ouverture : aucun choix immédiat")
	pnl._lock = false
	pnl.pick("zzz")
	_check(got.is_empty(), "tag non proposé ignoré")
	pnl.pick(str(shown[0]))
	_check(got.size() == 1 and got[0] == shown[0] and not get_tree().paused, "choix transmis, jeu relancé")
