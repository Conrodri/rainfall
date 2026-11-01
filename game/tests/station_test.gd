extends Node
## Ateliers (docs/Ateliers_Chiffres.md §3-6) : Fondoir (fonte, remboursement, plafond de scories, Phénix consommé),
## Matrice (tirage de l'objet affiché, exclusions, paiement en scorie ou en objet, 3 usages), Alambic (3 -> 1, tags,
## jamais légendaire, 2 usages), Enclume (prix, croissance, tag Or, Faveur, 3 usages), aucune boucle infinie
## Fondoir <-> Matrice, sauvegarde aller-retour, panneau « Choisir un objet possédé ».
## godot --headless --path game res://tests/station_test.tscn  -> RESULT: OK

var _fails := 0
var _events: Array = []


func _check(label: String, cond: bool, detail: String = "") -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label, ("  (" + detail + ")") if detail != "" else "")


func _reset(stage := 3, d := 2.78) -> void:
	RunState.start_run(&"moyen", 20261101)
	RunState.stage = stage
	RunState.floor_start_d = d
	RunState.omen = &""
	RunState.gold = 0.0
	RunState.counters = {}


func _give(id: StringName, n := 1) -> void:
	for i in n:
		RunState.add_item(id)


func _p() -> float:
	return Balance.chest_price(&"petit", RunState.floor_start_d, RunState.stage)


func _ready() -> void:
	Events.station_used.connect(_on_station_used)
	_test_balance()
	_test_fondoir()
	_test_matrice()
	_test_alambic()
	_test_enclume()
	_test_no_loop()
	_test_save()
	await _test_picker()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _on_station_used(id: StringName, kind: StringName, given: Array, received: Array, gold: float) -> void:
	_events.append([id, kind, given, received, gold])


# --- Constantes et formules du doc -----------------------------------------------------------------

func _test_balance() -> void:
	_check("constantes du doc", Balance.FONDOIR_USES == 2 and Balance.SCRAP_CAP == 3 and Balance.MATRICE_USES == 3 and Balance.MATRICE_MAX_OWNED == 5
		and Balance.ALAMBIC_INPUT == 3 and Balance.ALAMBIC_USES == 2 and Balance.ENCLUME_USES == 3 and is_equal_approx(Balance.ENCLUME_PRICE_GROWTH, 1.4)
		and not Balance.ALAMBIC_ALLOW_LEGENDARY and Balance.STATION_COPY_EXCLUDED.has(&"phenix_de_poche"))
	# prix de l'Enclume du doc §6 : commun 1,25 P / peu commun 2,75 P / rare 6 P (P = 50, 108, 195, 560)
	for pair in [[50.0, 62.5, 137.5, 300.0], [108.0, 135.0, 297.0, 648.0], [195.0, 243.75, 536.25, 1170.0], [560.0, 700.0, 1540.0, 3360.0]]:
		var P: float = pair[0]
		var calc := [Balance.ENCLUME_PRICE_P[&"commun"] * P, Balance.ENCLUME_PRICE_P[&"peu_commun"] * P, Balance.ENCLUME_PRICE_P[&"rare"] * P]
		_check("prix Enclume à P=%.0f" % P, absf(calc[0] - pair[1]) < 0.01 and absf(calc[1] - pair[2]) < 0.01 and absf(calc[2] - pair[3]) < 0.01, str(calc))
	_reset(2, 1.75)
	var base := Balance.enclume_price(&"commun", 0, 1.75, 2)
	_check("usage k : x1,4^k", is_equal_approx(Balance.enclume_price(&"commun", 1, 1.75, 2), base * 1.4) and is_equal_approx(Balance.enclume_price(&"commun", 2, 1.75, 2), base * 1.96))
	_check("tag Or x1,5, Faveur x0,85", is_equal_approx(Balance.enclume_price(&"commun", 0, 1.75, 2, 0.85, ["Or"]), base * 0.85 * 1.5))
	_check("remboursement = part de P", is_equal_approx(Balance.fondoir_refund(&"rare", 1.75, 2), 1.2 * Balance.chest_price(&"petit", 1.75, 2)) and Balance.fondoir_refund(&"legendaire", 1.75, 2) == 0.0)
	# remboursement < prix d'acquisition à chaque étage (commun = 1 P, peu commun ~ 2,5 P, rare ~ 11 P)
	for stage in range(2, 5):
		var d := 1.0 + 0.9 * (stage - 1)
		var P: float = Balance.station_price_p(d, stage)
		_check("étage %d : fonte commun (0,3 P) < prix d'un commun (1 P)" % stage, Balance.fondoir_refund(&"commun", d, stage) < P)
		_check("étage %d : fonte peu commun (0,6 P) < 2,5 P" % stage, Balance.fondoir_refund(&"peu_commun", d, stage) < 2.5 * P)
		_check("étage %d : fonte rare (1,2 P) < 11 P" % stage, Balance.fondoir_refund(&"rare", d, stage) < 11.0 * P)


# --- Fondoir ---------------------------------------------------------------------------------------

func _test_fondoir() -> void:
	_reset()
	_events.clear()
	_give(&"lentille_aiguisee", 2)
	_give(&"cristal_de_feu")
	_give(&"coeur_du_chronomancien")
	var f := StationState.make(&"fondoir", 3)
	_check("Fondoir : 2 usages", f.uses_left() == 2 and not f.exhausted())
	var res := f.melt(null, &"lentille_aiguisee")
	_check("fondre un commun", bool(res.ok), str(res))
	_check("commun fondu : 1 exemplaire en moins", RunState.stacks(&"lentille_aiguisee") == 1)
	_check("commun fondu : +1 scorie blanche", RunState.scrap_of(&"commun") == 1 and RunState.scrap_total() == 1)
	_check("commun fondu : or = 0,3 P", is_equal_approx(RunState.gold, 0.3 * _p()), "%s vs %s" % [RunState.gold, 0.3 * _p()])
	_check("événement station_used", _events.size() == 1 and _events[0][0] == &"fondoir" and _events[0][1] == &"fondre" and float(_events[0][4]) > 0.0)
	_check("compteur de télémétrie", float(RunState.counters.get("station.fondoir_uses", 0.0)) == 1.0)
	var gold1 := RunState.gold
	res = f.melt(null, &"cristal_de_feu")
	_check("fondre un peu commun : or 0,6 P, scorie verte", bool(res.ok) and RunState.scrap_of(&"peu_commun") == 1 and is_equal_approx(RunState.gold - gold1, 0.6 * _p()))
	_check("Fondoir épuisé après 2 usages", f.exhausted() and not bool(f.melt(null, &"lentille_aiguisee").ok) and f.melt_reason(&"lentille_aiguisee") == "Fondoir épuisé")
	# légendaire refusé, objet absent refusé
	var f2 := StationState.make(&"fondoir", 3)
	_check("légendaire refusé", f2.melt_reason(&"coeur_du_chronomancien") == "Les légendaires ne fondent pas" and not bool(f2.melt(null, &"coeur_du_chronomancien").ok) and RunState.stacks(&"coeur_du_chronomancien") == 1)
	_check("objet non possédé refusé", f2.melt_reason(&"flocon") == "Objet non possédé")
	# plafond de scories : 3 au total, toutes qualités confondues
	_reset()
	_give(&"lentille_aiguisee", 3)
	_give(&"flocon", 1)
	RunState.add_scrap(&"peu_commun")
	RunState.add_scrap(&"rare")
	var f3 := StationState.make(&"fondoir", 3)
	_check("scorie n°3 acceptée", bool(f3.melt(null, &"lentille_aiguisee").ok) and RunState.scrap_total() == 3)
	var f4 := StationState.make(&"fondoir", 3)
	_check("4e scorie refusée : « Scories pleines (3/3) »", f4.melt_reason(&"flocon") == "Scories pleines (3/3)" and not bool(f4.melt(null, &"flocon").ok) and RunState.stacks(&"flocon") == 1 and RunState.scrap_total() == 3)
	_check("RunState.add_scrap refuse au plafond", not RunState.add_scrap(&"commun") and RunState.scrap_total() == Balance.SCRAP_CAP)
	# Phénix : consommé non fondable
	_reset()
	_give(&"phenix_de_poche")
	RunState.counters[ItemEffects.COUNTER_PHENIX] = 1.0
	var f5 := StationState.make(&"fondoir", 3)
	_check("Phénix consommé non fondable", f5.melt_reason(&"phenix_de_poche") == "Phénix déjà consommé" and not bool(f5.melt(null, &"phenix_de_poche").ok) and RunState.stacks(&"phenix_de_poche") == 1)
	_give(&"phenix_de_poche")
	_check("Phénix : un exemplaire non consommé se fond", f5.melt_reason(&"phenix_de_poche") == "" and bool(f5.melt(null, &"phenix_de_poche").ok))
	_check("... puis le dernier (consommé) ne se fond plus", f5.melt_reason(&"phenix_de_poche") == "Phénix déjà consommé")
	_check("rare fondu : scorie rouge, or 1,2 P", RunState.scrap_of(&"rare") == 1 and is_equal_approx(RunState.gold, 1.2 * _p()))
	# la fonte ne tient pas compte de la Faveur du marchand (prix brut)
	_reset()
	_give(&"faveur_du_marchand", 2)
	_give(&"lentille_aiguisee")
	var f6 := StationState.make(&"fondoir", 3)
	f6.melt(null, &"lentille_aiguisee")
	_check("remboursement indépendant de la Faveur", is_equal_approx(RunState.gold, 0.3 * _p()))


# --- Matrice ---------------------------------------------------------------------------------------

func _test_matrice() -> void:
	_reset()
	# tirage : qualité de la table de l'étage, jamais légendaire, jamais le Phénix, déterministe
	var seen_q := {}
	var bad := 0
	for seed_i in range(1, 400):
		RunState.run_seed = seed_i
		for stage in [2, 3, 4]:
			var m := StationState.make(&"matrice", stage)
			var table: Dictionary = Balance.MATRICE_QUALITY_TABLE[stage]
			seen_q[[stage, m.quality]] = true
			if not table.has(m.quality) or m.quality == &"legendaire" or m.item_id == &"phenix_de_poche" or StationState.quality_of(m.item_id) != m.quality:
				bad += 1
	_check("Matrice : qualité dans la table de l'étage, hors légendaire et Phénix (%d écarts)" % bad, bad == 0)
	_check("Matrice étage 2 : jamais de rare", not seen_q.has([2, &"rare"]))
	_check("Matrice étage 4 : peut tirer du rare", seen_q.has([4, &"rare"]))
	RunState.run_seed = 77
	var a := StationState.make(&"matrice", 3)
	var b := StationState.make(&"matrice", 3)
	_check("tirage déterministe (graine, étage)", a.item_id == b.item_id and a.quality == b.quality)
	_check("le sel du mode test change le tirage", _salt_varies())
	# plafond de possession : jamais un objet possédé >= 5 fois
	_reset()
	_give(&"lentille_aiguisee", Balance.MATRICE_MAX_OWNED)
	_check("MATRICE_MAX_OWNED : objet à 5 exemplaires hors du tirage", not StationState.matrice_pool(&"commun").has("lentille_aiguisee") and StationState.matrice_pool(&"commun").has("sablier_fele"))
	_give(&"sablier_fele", Balance.MATRICE_MAX_OWNED - 1)
	_check("... à 4 exemplaires, encore tirable", StationState.matrice_pool(&"commun").has("sablier_fele"))
	_check("Phénix hors du tirage (copies exclues)", not StationState.matrice_pool(&"rare").has("phenix_de_poche"))
	# forge : en scorie, en objet, 3 usages
	_reset()
	var m := StationState.make(&"matrice", 3)
	m.item_id = &"sifflet_de_chasse"
	m.quality = &"commun"
	_events.clear()
	_check("sans scorie ni objet : refus écrit", m.forge_scrap_reason() == "Il faut 1 scorie blanche ou 1 objet commun" and not bool(m.forge(null, {"scrap": true}).ok))
	RunState.add_scrap(&"peu_commun")
	_check("une scorie d'une autre qualité ne paie pas", m.forge_scrap_reason() != "")
	RunState.add_scrap(&"commun")
	var r := m.forge(null, {"scrap": true})
	_check("forge payée en scorie", bool(r.ok) and RunState.stacks(&"sifflet_de_chasse") == 1 and RunState.scrap_of(&"commun") == 0 and RunState.scrap_of(&"peu_commun") == 1)
	_check("événement de forge", _events.size() == 1 and _events[0][0] == &"matrice" and _events[0][2] == [&"scorie_commun"] and _events[0][3] == [&"sifflet_de_chasse"])
	_give(&"botte_rapiecee")
	_check("objet non possédé refusé", m.forge_item_reason(&"cristal_de_feu") == "Objet non possédé")
	_give(&"cristal_de_feu")
	_check("objet de qualité différente refusé", m.forge_item_reason(&"cristal_de_feu") == "Il faut un objet commun")
	r = m.forge(null, {"item": &"botte_rapiecee"})
	_check("forge payée en objet", bool(r.ok) and RunState.stacks(&"botte_rapiecee") == 0 and RunState.stacks(&"sifflet_de_chasse") == 2)
	RunState.add_scrap(&"commun")
	r = m.forge(null, {"scrap": true})
	_check("3e forge permise, 4e refusée : Matrice épuisée", bool(r.ok) and m.exhausted() and RunState.stacks(&"sifflet_de_chasse") == 3 and m.forge_scrap_reason() == "Matrice épuisée")
	# plafond de stats : la carte l'écrit mais la forge reste permise
	_reset()
	var capm := StationState.make(&"matrice", 3)
	capm.item_id = &"botte_rapiecee"
	capm.quality = &"commun"
	var n := 0
	while not StationState.is_capped(&"botte_rapiecee") and n < 40:
		_give(&"botte_rapiecee")
		n += 1
	_check("Botte rapiécée atteint le plafond de vitesse (%d ex.)" % n, StationState.is_capped(&"botte_rapiecee") and n < 40)
	_check("carte : « plafond atteint »", capm.matrice_note() == "plafond atteint")


func _salt_varies() -> bool:
	var ids := {}
	for salt in range(1, 40):
		var m := StationState.make(&"matrice", 3)
		m.draw_matrice(salt)
		ids[m.item_id] = true
	return ids.size() > 3


# --- Alambic ---------------------------------------------------------------------------------------

func _test_alambic() -> void:
	_reset()
	_events.clear()
	_give(&"etincelle", 3)
	var al := StationState.make(&"alambic", 3)
	_check("Alambic : 2 usages", al.uses_left() == 2)
	_check("2 objets : refus écrit", al.distill_reason([&"etincelle", &"etincelle"]) == "Il faut 3 objets (2/3)")
	var r := al.distill(null, [&"etincelle", &"etincelle", &"etincelle"], RandomNumberGenerator.new())
	_check("3 communs Feu -> 1 peu commun Feu (Cristal de feu)", bool(r.ok) and r.item == &"cristal_de_feu" and RunState.stacks(&"etincelle") == 0 and RunState.stacks(&"cristal_de_feu") == 1, str(r))
	_check("événement de distillation", _events.size() == 1 and _events[0][1] == &"distiller" and _events[0][2].size() == 3)
	# 3 peu communs Auto -> rare Auto (Rafale d'acier, seul rare Auto)
	_give(&"lame_jumelle", 3)
	r = al.distill(null, [&"lame_jumelle", &"lame_jumelle", &"lame_jumelle"], RandomNumberGenerator.new())
	_check("3 peu communs Auto -> rare Auto", bool(r.ok) and r.item == &"rafale_d_acier", str(r))
	_check("Alambic épuisé après 2 usages", al.exhausted() and al.distill_reason([&"etincelle", &"etincelle", &"etincelle"]) == "Alambic épuisé")
	# exemplaires insuffisants / qualités mixtes / rares refusés (jamais de légendaire)
	_reset()
	_give(&"etincelle", 2)
	_give(&"cristal_de_feu")
	_give(&"chronometre_brise", 3)
	var a2 := StationState.make(&"alambic", 3)
	_check("exemplaires insuffisants", a2.distill_reason([&"etincelle", &"etincelle", &"etincelle"]) == "Pas assez d'exemplaires")
	_check("qualités mixtes refusées", a2.distill_reason([&"etincelle", &"etincelle", &"cristal_de_feu"]) == "Il faut 3 objets de même qualité")
	_check("3 rares refusés : pas de légendaire", a2.distill_reason([&"chronometre_brise", &"chronometre_brise", &"chronometre_brise"]) == "Pas de légendaire par l'alambic")
	_check("objet non possédé refusé", a2.distill_reason([&"flocon", &"flocon", &"flocon"]) == "Objet non possédé")
	# résultat toujours de la qualité du dessus (jamais légendaire), guidé par les tags, sur 200 tirages
	var ok_all := true
	for i in 200:
		_reset()
		_give(&"antidote", 3)
		var al2 := StationState.make(&"alambic", 3)
		var rng := RandomNumberGenerator.new()
		rng.seed = i + 1
		var rr := al2.distill(null, [&"antidote", &"antidote", &"antidote"], rng)
		var got := StringName(str(rr.get("item", "")))
		if not bool(rr.ok) or StationState.quality_of(got) != &"peu_commun" or not (StationState.tags_of(got) as Array).has("Survie"):
			ok_all = false
	_check("200 distillations : toujours un peu commun du tag Survie", ok_all)
	# l'objet plafonné n'est jamais proposé
	_reset()
	_give(&"sifflet_de_chasse")
	var guard := 0
	while not StationState.is_capped(&"carquois_affute") and guard < 40:
		_give(&"carquois_affute")
		guard += 1
	if StationState.is_capped(&"carquois_affute"):
		_check("objet plafonné exclu du résultat", not StationState.result_pool([&"sifflet_de_chasse"], &"peu_commun").has("carquois_affute"))
	else:
		_check("Carquois affûté plafonnable (sinon test à adapter)", false)
	# Phénix consommé non donnable
	_reset()
	_give(&"phenix_de_poche")
	RunState.counters[ItemEffects.COUNTER_PHENIX] = 1.0
	_check("Phénix consommé non donnable à l'Alambic", StationState.make(&"alambic", 3).distill_reason([&"phenix_de_poche", &"phenix_de_poche", &"phenix_de_poche"]) != "")


# --- Enclume ---------------------------------------------------------------------------------------

func _test_enclume() -> void:
	_reset(3, 2.78)
	_events.clear()
	_give(&"sifflet_de_chasse")
	_give(&"cristal_de_feu")
	_give(&"faveur_du_marchand")
	_give(&"phenix_de_poche")
	_give(&"coeur_du_chronomancien")
	var en := StationState.make(&"enclume", 3)
	var P := _p()
	var mult := ItemEffects.chest_price_mult()
	_check("prix commun = 1,25 P x Faveur", is_equal_approx(en.enclume_price(&"sifflet_de_chasse"), 1.25 * P * mult))
	_check("prix peu commun = 2,75 P", is_equal_approx(en.enclume_price(&"cristal_de_feu"), 2.75 * P * mult))
	_check("tag Or : Faveur x1,5", is_equal_approx(en.enclume_price(&"faveur_du_marchand"), 6.0 * P * mult * 1.5))
	_check("Phénix exclu des copies", en.enclume_reason(&"phenix_de_poche") == "Cet objet ne se copie pas")
	_check("légendaire refusé", en.enclume_reason(&"coeur_du_chronomancien") == "Les légendaires ne se forgent pas")
	_check("objet absent refusé", en.enclume_reason(&"flocon") == "Objet non possédé")
	var price := en.enclume_price(&"sifflet_de_chasse")
	_check("or insuffisant : « Il manque N or »", en.enclume_reason(&"sifflet_de_chasse") == "Il manque %d or" % int(ceil(price)) and not bool(en.forge_copy(null, &"sifflet_de_chasse").ok))
	RunState.gold = 100000.0
	var g0 := RunState.gold
	var r := en.forge_copy(null, &"sifflet_de_chasse")
	_check("forge d'un exemplaire", bool(r.ok) and RunState.stacks(&"sifflet_de_chasse") == 2)
	_check("or dépensé = prix", is_equal_approx(g0 - RunState.gold, price))
	_check("événement : or négatif", _events.size() == 1 and _events[0][0] == &"enclume" and is_equal_approx(float(_events[0][4]), -price))
	_check("2e usage : prix x1,4", is_equal_approx(en.enclume_price(&"sifflet_de_chasse"), price * 1.4))
	en.forge_copy(null, &"sifflet_de_chasse")
	_check("3e usage : prix x1,96", is_equal_approx(en.enclume_price(&"sifflet_de_chasse"), price * 1.96))
	en.forge_copy(null, &"sifflet_de_chasse")
	_check("Enclume épuisée après 3 usages", en.exhausted() and en.enclume_reason(&"sifflet_de_chasse") == "Enclume épuisée" and RunState.stacks(&"sifflet_de_chasse") == 4)
	# plafond de stats
	_reset(3, 2.78)
	RunState.gold = 100000.0
	var guard := 0
	while not StationState.is_capped(&"botte_rapiecee") and guard < 40:
		_give(&"botte_rapiecee")
		guard += 1
	_check("objet plafonné : carte grisée « Plafond atteint »", StationState.make(&"enclume", 3).enclume_reason(&"botte_rapiecee") == "Plafond atteint")
	# présage de prix (Marché noir / Usure) : multiplicateur partagé avec les coffres
	_reset(3, 2.78)
	_give(&"sifflet_de_chasse")
	var plain := StationState.make(&"enclume", 3).enclume_price(&"sifflet_de_chasse")
	_check("price_mult = Faveur x présage", is_equal_approx(StationState.price_mult(), ItemEffects.chest_price_mult() * Omens.chest_price_mult()) and plain > 0.0)
	# or infini du mode test : l'achat passe sans solde
	_reset(3, 2.78)
	_give(&"sifflet_de_chasse")
	TestMode.inf_gold = true
	_check("or infini : forge sans solde", StationState.make(&"enclume", 3).enclume_reason(&"sifflet_de_chasse") == "")
	TestMode.inf_gold = false


# --- Aucune boucle infinie Fondoir <-> Matrice ----------------------------------------------------

func _test_no_loop() -> void:
	_reset(3, 2.78)
	_give(&"lentille_aiguisee", 3)
	_give(&"sablier_fele", 3)
	_give(&"antidote", 2)
	var f := StationState.make(&"fondoir", 3)
	var m := StationState.make(&"matrice", 3)
	m.item_id = &"lentille_aiguisee"
	m.quality = &"commun"
	var ops := 0
	var gold_before := RunState.gold
	var guard := 0
	var moved := true
	while moved and guard < 100:
		guard += 1
		moved = false
		for id in [&"sablier_fele", &"antidote", &"lentille_aiguisee"]:
			if f.melt_reason(id) == "":
				f.melt(null, id)
				ops += 1
				moved = true
				break
		if m.forge_scrap_reason() == "":
			m.forge(null, {"scrap": true})
			ops += 1
			moved = true
	_check("Fondoir <-> Matrice : s'arrête (%d tours, %d opérations)" % [guard, ops], guard < 100 and ops <= Balance.FONDOIR_USES + Balance.MATRICE_USES)
	_check("... l'or gagné reste sous 2 fontes de commun", RunState.gold - gold_before <= 2.0 * Balance.FONDOIR_REFUND_P[&"commun"] * _p() + 0.001)
	_check("... Fondoir ou Matrice épuisé, ou plus de scorie", f.exhausted() or m.exhausted() or RunState.scrap_total() == 0)
	# fonte -> forge -> refonte d'un objet forgé : chaque cycle gagne <= 0,3 P et le Fondoir n'a que 2 usages
	_reset(3, 2.78)
	_give(&"lentille_aiguisee", 1)
	var f2 := StationState.make(&"fondoir", 3)
	var m2 := StationState.make(&"matrice", 3)
	m2.item_id = &"lentille_aiguisee"
	m2.quality = &"commun"
	var cycles := 0
	while f2.melt_reason(&"lentille_aiguisee") == "" and cycles < 10:
		f2.melt(null, &"lentille_aiguisee")
		m2.forge(null, {"scrap": true})
		cycles += 1
	_check("cycle fonte/forge : 2 cycles au plus, +0,6 P au plus (%d)" % cycles, cycles == 2 and RunState.gold <= 0.6 * _p() + 0.001)


# --- Sauvegarde ------------------------------------------------------------------------------------

func _test_save() -> void:
	_reset(3, 2.78)
	RunState.add_scrap(&"commun")
	RunState.add_scrap(&"rare")
	var d := RunState.to_dict()
	RunState.scrap = {}
	RunState.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check("scories : aller-retour de sauvegarde", RunState.scrap_of(&"commun") == 1 and RunState.scrap_of(&"rare") == 1 and RunState.scrap_total() == 2)
	var legacy := RunState.to_dict()
	legacy.erase("scrap")
	RunState.from_dict(legacy)
	_check("ancienne sauvegarde : aucune scorie", RunState.scrap_total() == 0)
	var m := StationState.make(&"matrice", 3)
	m.uses_done = 2
	var m2 := StationState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	_check("état de la Matrice : aller-retour", m2.kind == &"matrice" and m2.uses_done == 2 and m2.item_id == m.item_id and m2.quality == m.quality and m2.uses_left() == 1)
	var st := Station.new()
	st.setup(m)
	var arr := StationSpawner.to_dict([st])
	_check("StationSpawner.to_dict", arr.size() == 1 and arr[0].kind == "matrice" and arr[0].has("x"))
	st.free()


# --- Panneau « Choisir un objet possédé » ----------------------------------------------------------

func _validate_not_two(sel: Array) -> String:
	return "non" if sel[0]["key"] == 2 else ""


func _test_picker() -> void:
	_reset(3, 2.78)
	_give(&"lentille_aiguisee", 2)
	_give(&"cristal_de_feu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	var was := get_tree().paused
	var out := {"picked": [], "closed": 0}
	var list := [
		{"key": 0, "id": &"lentille_aiguisee", "enabled": true, "line": "Fondre : +1 or"},
		{"key": 1, "id": &"cristal_de_feu", "enabled": false, "reason": "Refusé pour le test", "line": ""},
		{"key": 2, "id": &"lentille_aiguisee", "enabled": true, "line": "Fondre : +1 or"},
	]
	var p := ItemPicker.open(self, {"title": "Test", "entries": list})
	p.picked.connect(func(e: Array) -> void: out["picked"] = e)
	p.closed.connect(func() -> void: out["closed"] += 1)
	await get_tree().process_frame
	_check("panneau : jeu en pause", get_tree().paused)
	_check("panneau : une carte par entrée", p.buttons.size() == 3)
	_check("panneau : carte refusée = raison écrite", (p.buttons[1].get_meta(&"line") as Label).text == "Refusé pour le test")
	p.press(1)
	_check("carte refusée : ne choisit rien, raison au pied", out["picked"].is_empty() and p.status_label.text == "Refusé pour le test" and out["closed"] == 0)
	p.press(0)
	_check("un appui choisit (mode simple) et ferme", out["picked"].size() == 1 and out["picked"][0]["key"] == 0 and out["closed"] == 1)
	await get_tree().process_frame
	_check("pause restaurée à la fermeture", get_tree().paused == was)
	# multi : sélection, validation, annulation
	out["picked"] = []
	var p2 := ItemPicker.open(self, {"title": "Multi", "entries": list, "multi": 2, "confirm_label": "Distiller", "validate": _validate_not_two})
	p2.picked.connect(func(e: Array) -> void: out["picked"] = e)
	await get_tree().process_frame
	_check("multi : bouton grisé tant que la sélection est incomplète", p2.confirm_button.disabled and p2.count_label.text == "0/2")
	p2.press(0)
	_check("multi : compteur 1/2", p2.count_label.text == "1/2" and p2.confirm_button.disabled)
	p2.press(1)
	_check("multi : carte refusée non sélectionnée", p2.selected == [0])
	p2.press(0)
	_check("multi : un 2e appui désélectionne", p2.selected.is_empty())
	p2.press(2)
	p2.press(0)
	_check("multi : 2/2 mais validateur refuse -> bouton grisé, raison écrite", p2.count_label.text == "2/2" and p2.confirm_button.disabled and p2.status_label.text == "non")
	p2.confirm()
	_check("multi : confirm() refusé ne ferme pas", out["picked"].is_empty())
	p2.cancel()
	await get_tree().process_frame
	_check("annulation : rien choisi, pause restaurée", out["picked"].is_empty() and get_tree().paused == was)
	var p3 := ItemPicker.open(self, {"title": "OK", "entries": list, "multi": 2, "confirm_label": "Go"})
	p3.picked.connect(func(e: Array) -> void: out["picked"] = e)
	await get_tree().process_frame
	p3.press(0)
	p3.press(2)
	_check("multi : bouton actif à 2/2", not p3.confirm_button.disabled)
	p3.confirm()
	_check("multi : confirmation renvoie les 2 entrées", out["picked"].size() == 2)
	await get_tree().process_frame
	var p4 := ItemPicker.open(self, {"title": "Vide", "entries": [], "empty_text": "Aucun objet"})
	await get_tree().process_frame
	_check("liste vide : panneau ouvert sans carte", p4.buttons.is_empty())
	p4.cancel()
	await get_tree().process_frame
	_check("pause restaurée (fin)", get_tree().paused == was)
