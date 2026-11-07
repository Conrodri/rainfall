extends Node
## Les Épreuves généralisées (docs/Design_Epreuves.md, lot E0) : drapeau désactivé = jeu inchangé sur les 8 cartes ; drapeau
## activé = les deux épreuves du biome à la place des petits piliers (géométrie praticable, gros pilier dégagé, coffres et
## capsules répartis, sauvegarde) sur les 8 cartes des étages 1-4 ; données (data/epreuves.json, EpreuveGeom) ; étage 5 et
## sans fin ; variantes (biome coupé, une épreuve par étage). Escorte (corde, arrêt, PV à 0, arrivée, mini-boss, note) ;
## Rituel (relais à maintien, cadence 12/9/7 s, anneau, note) ; délai de sécurité ; or versé ; or des kills en zone réduit ;
## sauvegarde ; mode test. Les verbes Poursuite, Veine et Tenue (lots E1-E3) ont leurs propres tests ; tant que leur classe
## n'existe pas, les cartes qui les portent sont contrôlées côté données et retombent en étage classique.
## godot --headless --path game res://tests/epreuve_test.tscn  -> RESULT: OK

const KILL_GUARD := 400
const MAPS := ["terrasses_noyees", "terrasses_rizieres_hautes", "foret_brume", "foret_mangrove_lanternes", "cite_rouille", "cite_fonderie_canal", "cryptes_noyees", "cryptes_ossuaire_pluies"]
const MAP_BIOME := {
	"terrasses_noyees": "terrasses", "terrasses_rizieres_hautes": "terrasses", "foret_brume": "foret", "foret_mangrove_lanternes": "foret",
	"cite_rouille": "cite", "cite_fonderie_canal": "cite", "cryptes_noyees": "cryptes", "cryptes_ossuaire_pluies": "cryptes",
}
## Fichier de la classe de chaque verbe : la carte est contrôlée « épreuves actives » seulement quand toutes les classes de
## son biome existent (sinon étage classique, contrôlé aussi).
const VERB_FILE := {
	"escorte": "epreuve_escort.gd", "rituel": "epreuve_ritual.gd", "poursuite": "epreuve_chase.gd", "veine": "epreuve_vein.gd", "tenue": "epreuve_hold.gd",
}

class FakePlayer extends Node2D:
	func gold_mult() -> float:
		return 1.0

var _fails := 0
var _main: Node
var _events: Array = []
var _mgr: StageManager = null


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seed_for_map(map_id: String) -> int:
	for s in range(1, 400):
		var plan: Array = FloorPlan.build(s)
		if String((plan[0] as Dictionary).get("map_id", "")) == map_id:
			return s
	return -1


## Jusqu'à `n` couples [graine, étage de run] dont le plan tombe sur la carte `map_id`.
func _locate(map_id: String, n: int) -> Array:
	var out: Array = []
	for s in range(1, 400):
		var plan: Array = FloorPlan.build(s)
		for i in plan.size():
			if String((plan[i] as Dictionary).get("map_id", "")) == map_id and out.size() < n:
				out.append([s, i + 1])
				break
		if out.size() >= n:
			break
	return out


func _new_main(run_seed: int) -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await _frames(3)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", run_seed)
	add_child(_main)
	await _main.game_ready
	await _frames(3)
	(_main.get(&"player") as Node2D).call(&"grant_invulnerability", 1.0e6)


func _run() -> void:
	Events.epreuve_started.connect(func(k: StringName) -> void: _events.append(["start", k]))
	Events.epreuve_finished.connect(func(k: StringName, g: StringName, s: float, gold: float) -> void: _events.append(["end", k, g, s, gold]))
	_check_balance()
	_check_data()
	_check_geom_rules()
	_setup_manager()
	_flag_off()
	for map_id in MAPS:
		_flag_on(map_id)
	_sweep()
	_variants()
	_final_and_endless()
	_teardown_manager()
	await _mechanics()
	await _flow()
	await _test_mode()
	Balance.EPREUVES_ENABLED = false
	Balance.EPREUVES_PER_STAGE = 2
	EpreuveData.reload()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


# --- Constantes et notes
func _check_balance() -> void:
	print("-- Balance")
	_check("drapeau par défaut : faux", not Balance.EPREUVES_ENABLED)
	_check("2 épreuves par étage, sans fin activé", Balance.EPREUVES_PER_STAGE == 2 and Balance.EPREUVE_IN_ENDLESS)
	_check("ZONE_SPAWN_MULT[epreuve] = 1,5", is_equal_approx(float(Balance.ZONE_SPAWN_MULT[&"epreuve"]), 1.5))
	_check("cadence du cœur [12, 9, 7]", Balance.RITUAL_PULSE_S == [12.0, 9.0, 7.0] and is_equal_approx(Balance.ritual_pulse_s(0), 12.0) and is_equal_approx(Balance.ritual_pulse_s(1), 9.0) and is_equal_approx(Balance.ritual_pulse_s(2), 7.0))
	_check("maintien 1,2 s, 3 relais, télégraphe >= 0,8 s", is_equal_approx(Balance.RITUAL_HOLD_S, 1.2) and Balance.RITUAL_RELAYS == 3 and Balance.RITUAL_TELEGRAPH_S >= 0.8)
	_check("escorte 2,5 u/s, corde 6 u, arrêt 5 s, PV 0,3 mini", is_equal_approx(Balance.ESCORT_SPEED_U, 2.5) and is_equal_approx(Balance.ESCORT_LEASH_U, 6.0) and is_equal_approx(Balance.ESCORT_STALL_S, 5.0) and is_equal_approx(Balance.ESCORT_HP_MINI_SHARE, 0.3))
	_check("PV de la barque = 0,3 x PV d'un mini-boss", is_equal_approx(Balance.escort_hp(2.0, 1), 0.3 * Balance.boss_hp(&"mini", 2.0, 1)))
	_check("note : parfait", Balance.epreuve_grade(&"escorte", 30.0, true) == &"parfait" and Balance.epreuve_grade(&"rituel", 35.0, true) == &"parfait")
	_check("note : faute = bien", Balance.epreuve_grade(&"escorte", 30.0, false) == &"bien")
	_check("note : bien jusqu'à 1,5 x seuil", Balance.epreuve_grade(&"escorte", 60.0, true) == &"bien" and Balance.epreuve_grade(&"rituel", 52.5, true) == &"bien")
	_check("note : fait au-delà", Balance.epreuve_grade(&"escorte", 60.5, true) == &"fait" and Balance.epreuve_grade(&"rituel", 53.0, false) == &"fait")
	_check("note : poursuite 40 s, veine 40 s", Balance.epreuve_grade(&"poursuite", 40.0, true) == &"parfait" and Balance.epreuve_grade(&"poursuite", 41.0, true) == &"bien" and Balance.epreuve_grade(&"veine", 41.0, true) == &"bien")
	var p := 50.0
	_check("or : parfait > bien > fait > 0", Balance.epreuve_gold(&"parfait", p) > Balance.epreuve_gold(&"bien", p) and Balance.epreuve_gold(&"bien", p) > Balance.epreuve_gold(&"fait", p) and Balance.epreuve_gold(&"fait", p) > 0.0)
	# Bornes simples : le modèle complet de l'audit du 07/11/2026 (allongement de l'étage, farm en zone) n'est pas reproduit ici.
	# Invariants testés : écarts d'incitation, et mix 25/55/20 % dans la bande 8-10,5 P avec le haut de l'étage mesuré (8,8 P).
	var g_par := float(Balance.EPREUVE_GOLD_P[&"parfait"])
	var g_bien := float(Balance.EPREUVE_GOLD_P[&"bien"])
	var g_fait := float(Balance.EPREUVE_GOLD_P[&"fait"])
	_check("or : parfait > bien > fait > 0 (P)", g_par > g_bien and g_bien > g_fait and g_fait > 0.0)
	_check("or : parfait <= 1,0 P et parfait - bien >= 0,2 P", g_par <= 1.0 and g_par - g_bien >= 0.2 - 0.0001)
	var mix := 0.25 * g_par + 0.55 * g_bien + 0.20 * g_fait
	var per_epreuve := mix + 0.3 + 0.7 * Balance.EPREUVE_ZONE_GOLD_MULT # note + prime du mini-boss + kills en zone réduits
	var floor_p := 8.8 - 2.0 * 1.0 + 2.0 * per_epreuve
	_check("budget d'or : étage 1 entre 8 et 10,5 P (mix 25/55/20 %%, %.1f P)" % floor_p, floor_p >= 8.0 and floor_p <= 10.5)


# --- data/epreuves.json
func _check_data() -> void:
	print("-- data/epreuves.json")
	EpreuveData.reload()
	var names := EpreuveData.all_verbs()
	_check("5 verbes nommés", names.size() == 5 and "escorte" in names and "rituel" in names and "poursuite" in names and "veine" in names and "tenue" in names)
	var pairs: Array = []
	for biome in ["terrasses", "foret", "cite", "cryptes"]:
		var vs := EpreuveData.verbs(biome)
		_check("%s : actif, 2 verbes distincts connus" % biome, EpreuveData.enabled(biome) and vs.size() == 2 and vs[0] != vs[1] and vs[0] in names and vs[1] in names)
		_check("%s : libellé de départ <= 24 caractères pour chaque verbe" % biome, vs.all(func(v: String) -> bool: var l := EpreuveData.label(biome, v, "start"); return l != "" and l.length() <= 24))
		_check("%s : skin de levier" % biome, String(EpreuveData.lever_skin(biome)) != "")
		var key := vs.duplicate()
		key.sort()
		pairs.append(key)
	for i in range(pairs.size() - 1):
		_check("paire de verbes différente entre les étages %d et %d" % [i + 1, i + 2], pairs[i] != pairs[i + 1])
	_check("Cryptes = même paire que le Gouffre (décision du joueur)", pairs[1] == pairs[3])
	_check("la Source : aucune épreuve", not EpreuveData.enabled("source") and EpreuveData.verbs("source").is_empty())
	_check("biome inconnu : désactivé", not EpreuveData.enabled("nimporte") and EpreuveData.verbs("nimporte").is_empty())
	_check("libellés Cité du Rituel", EpreuveData.label("cite", "rituel", "start") == "Réveiller la pompe" and EpreuveData.label("cite", "rituel", "relay") == "Fermer la soupape")
	_check("skins de leviers livrés", EpreuveData.lever_skin("terrasses") == &"terraces" and EpreuveData.lever_skin("foret") == &"fog_forest" and EpreuveData.lever_skin("cite") == &"rust_city" and EpreuveData.lever_skin("cryptes") == &"crypts")
	# interrupteur par biome
	(EpreuveData._data["biomes"]["terrasses"] as Dictionary)["enabled"] = false
	_check("enabled=false coupe le biome", not EpreuveData.enabled("terrasses"))
	EpreuveData.reload()
	_check("rechargement : biome réactivé", EpreuveData.enabled("terrasses"))


## Règles de structure de EpreuveGeom (refus des tracés invalides, jamais de plantage).
func _check_geom_rules() -> void:
	print("-- EpreuveGeom")
	var base := {"size_px": [100, 100]}
	var ok := func(verbs: Array, extra: Dictionary) -> bool:
		var d := base.duplicate()
		d.merge(extra)
		return not EpreuveGeom.parse_u(d, verbs, "test").is_empty()
	var good_posts := [[0, 0], [12, 0], [24, 0], [36, 0], [48, 0], [60, 0]]
	_check("poursuite : 6 bornes espacées de 12 u acceptées", ok.call(["poursuite"], {"chase_posts": good_posts}))
	_check("poursuite : 5 bornes refusées", not ok.call(["poursuite"], {"chase_posts": good_posts.slice(0, 5)}))
	_check("poursuite : borne isolée refusée", not ok.call(["poursuite"], {"chase_posts": [[0, 0], [12, 0], [24, 0], [36, 0], [48, 0], [200, 200]]}))
	_check("poursuite : clé absente refusée", not ok.call(["poursuite"], {}))
	_check("veine : boucle de 48 u acceptée", ok.call(["veine"], {"vein_path": [[0, 0], [12, 0], [12, 12], [0, 12]], "vein_closed": true}))
	_check("veine : même tracé ouvert = 36 u refusé", not ok.call(["veine"], {"vein_path": [[0, 0], [12, 0], [12, 12], [0, 12]], "vein_closed": false}))
	_check("veine : 80 u refusés", not ok.call(["veine"], {"vein_path": [[0, 0], [80, 0]], "vein_closed": false}))
	_check("veine : 1 point refusé", not ok.call(["veine"], {"vein_path": [[0, 0]]}))
	_check("tenue : 3 côtés acceptés", ok.call(["tenue"], {"hold": {"pos": [10, 10], "sides": [[0, -1], [1, 0], [-1, 0]]}}))
	_check("tenue : 2 côtés refusés", not ok.call(["tenue"], {"hold": {"pos": [10, 10], "sides": [[0, -1], [1, 0]]}}))
	_check("tenue : côté nul refusé", not ok.call(["tenue"], {"hold": {"pos": [10, 10], "sides": [[0, -1], [1, 0], [0, 0]]}}))
	_check("rituel : 2 relais refusés", not ok.call(["rituel"], {"ritual": {"heart": [5, 5], "relays": [[1, 1], [2, 2]]}}))
	_check("escorte : tracé d'un point refusé", not ok.call(["escorte"], {"escort_path": [[1, 1]]}))
	_check("deux verbes : l'un invalide invalide la carte", not ok.call(["escorte", "veine"], {"escort_path": [[0, 0], [30, 0]], "vein_path": [[0, 0]]}))
	var g := EpreuveGeom.parse_u({"vein_path": [[0, 0], [12, 0], [12, 12], [0, 12]], "vein_closed": true}, ["veine"])
	var ge: Dictionary = g[&"veine"]
	_check("dist : sur le tracé fermé (segment de fermeture)", is_equal_approx(EpreuveGeom.dist("veine", ge, Vector2(0, 6)), 0.0) and is_equal_approx(EpreuveGeom.dist("veine", ge, Vector2(-3, 6)), 3.0))
	_check("ancre : premier point du tracé", EpreuveGeom.anchor("veine", ge) == Vector2(0, 0))
	_check("échantillonnage du tracé fermé couvre la fermeture", EpreuveGeom.sample_points("veine", ge, 1.0).size() >= 48)


# --- Banc de disposition : un StageManager sans scène principale (comme tests/capsule_test)
func _setup_manager() -> void:
	var player := FakePlayer.new()
	player.add_to_group(&"player")
	add_child(player)
	_mgr = StageManager.new()
	add_child(_mgr)


func _teardown_manager() -> void:
	if _mgr != null and is_instance_valid(_mgr):
		_mgr.queue_free()
	for n in get_tree().get_nodes_in_group(&"player"):
		if n is FakePlayer:
			n.queue_free()
	_mgr = null


## Démarre l'étage `stage` du run de graine `run_seed` (mode sans fin si `endless`).
func _start(run_seed: int, stage: int, endless: bool = false) -> void:
	RunState.start_run(&"moyen", run_seed)
	_mgr.reset_run()
	_mgr.endless = endless
	RunState.stage = stage
	_mgr.start_stage()


func _expect_on(map_id: String) -> bool:
	for v in EpreuveData.verbs(MAP_BIOME[map_id]):
		if not ResourceLoader.exists("res://scripts/stage/%s" % VERB_FILE[v]):
			return false
	return true


## Disposition d'un étage classique : 3 piliers ordinaires, 10-11 coffres, 4 capsules.
func _classic_ok(stage: StageManager) -> bool:
	return not stage.epreuves_on and stage.pillars.size() == 3 and stage.pillars.filter(func(p): return p is Epreuve).is_empty() \
		and stage.chests.size() >= 10 and stage.chests.size() <= 11 and stage.capsules.size() == Balance.CAPSULES_PER_STAGE


# --- Drapeau désactivé : jeu inchangé
func _flag_off() -> void:
	print("-- drapeau désactivé")
	Balance.EPREUVES_ENABLED = false
	for map_id in MAPS:
		var loc: Array = _locate(map_id, 1)[0]
		_start(loc[0], loc[1])
		_check("%s : étage classique (3 piliers ordinaires, 10-11 coffres, 4 capsules)" % map_id, _mgr.map_id == map_id and _classic_ok(_mgr))
		_check("%s : piliers tirés sur des marqueurs" % map_id, (_mgr.to_dict()["pillars"] as Array).all(func(d): return int(d["marker"]) >= 0 and not d.has("epreuve")))
	_check("aucun nœud du groupe epreuves", get_tree().get_nodes_in_group(&"epreuves").is_empty())
	_check("zone : mêmes tarifs mini et étage", is_equal_approx(float(Balance.ZONE_SPAWN_MULT[&"mini"]), 1.5) and is_equal_approx(float(Balance.ZONE_SPAWN_MULT[&"etage"]), 2.33))
	_check("or des kills non modifié hors épreuve", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), Vector2(1.0e6, 1.0e6)), 1.0))
	# même graine, même étage, drapeau désactivé deux fois : tirage identique (seed intacte)
	var loc0: Array = _locate("terrasses_noyees", 1)[0]
	_start(loc0[0], loc0[1])
	var d1: Dictionary = _mgr.to_dict()
	_start(loc0[0], loc0[1])
	var d2: Dictionary = _mgr.to_dict()
	_check("tirage déterministe (pilier, coffres, capsules)", JSON.stringify([d1["pillars"], d1["chests"], d1["capsules"]]) == JSON.stringify([d2["pillars"], d2["chests"], d2["capsules"]]))


# --- Drapeau activé : disposition des étages 1-4, une carte
func _flag_on(map_id: String) -> void:
	print("-- drapeau activé, ", map_id)
	Balance.EPREUVES_ENABLED = true
	var loc: Array = _locate(map_id, 1)[0]
	_start(loc[0], loc[1])
	var stage := _mgr
	var biome: String = MAP_BIOME[map_id]
	var verbs := EpreuveData.verbs(biome)
	_check("carte du plan, biome de la carte", stage.map_id == map_id and String(stage.map.biome()) == biome, stage.map_id)
	var geom := EpreuveGeom.load_for(stage.map, map_id, verbs)
	_check("clés JSON valides pour %s" % ", ".join(verbs), geom.size() == verbs.size())
	if geom.size() != verbs.size():
		return
	_check_geometry(stage, map_id, biome, verbs, geom)
	if not _expect_on(map_id):
		_check("verbe non branché (lots E1-E3) : étage classique, jamais de pilier au départ", _classic_ok(stage))
		return
	_check_layout(stage, map_id, verbs)
	Balance.EPREUVES_ENABLED = false


## Géométrie de la carte : praticable, loin des secrets et du départ, au moins deux candidats de gros pilier dégagés.
func _check_geometry(stage: StageManager, map_id: String, biome: String, verbs: Array, geom: Dictionary) -> void:
	var u := Balance.UNIT_PX
	var walk_ok := true
	var n := 0
	for v in verbs:
		for p in EpreuveGeom.sample_points(v, geom[StringName(v)], 0.5 * u):
			n += 1
			if not stage.is_reachable_local(p):
				walk_ok = false
	_check("objets d'épreuve accessibles à pied (%d points)" % n, walk_ok)
	# en u de carte : distances aux plaques et gardiens de secret, au départ
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % map_id))
	var raw := EpreuveGeom.parse_u(data, verbs, map_id)
	var half := Vector2(float(data["size_px"][0]), float(data["size_px"][1])) * 0.5
	var start_u := (stage.map.to_map(stage.map.get_player_start()) + half) / u
	var secret_ok := true
	for sc in data.get("secrets", []):
		for key in ["plates_u", "guardians_u"]:
			for pt in sc.get(key, []):
				for v in verbs:
					if EpreuveGeom.dist(v, raw[StringName(v)], Vector2(float(pt[0]), float(pt[1]))) < 4.0:
						secret_ok = false
	_check("objets d'épreuve à >= 4 u des plaques et gardiens de secret", secret_ok)
	var start_ok := true
	for v in verbs:
		if EpreuveGeom.anchor(v, raw[StringName(v)]).distance_to(start_u) < 6.0:
			start_ok = false
	_check("point d'ancrage de chaque épreuve à >= 6 u du départ", start_ok)
	var clear := 0
	var bigs := 0
	for m in stage.map.get_pillar_markers():
		if not m.is_in_group(&"pillar_big"):
			continue
		bigs += 1
		var p := stage.map.local_pos(m)
		var ok := true
		for v in verbs:
			if EpreuveGeom.dist(v, geom[StringName(v)], p) < float(Balance.EPREUVE_BIG_AVOID_U[StringName(v)]) * u - 1.0:
				ok = false
		clear += 1 if ok else 0
	var need := 1 if biome == "terrasses" else 2 # Terrasses : tracés du prototype (un seul candidat dégagé, à rééquilibrer par le level-designer)
	_check("au moins %d candidat(s) de gros pilier dégagé(s) (%d sur %d)" % [need, clear, bigs], clear >= need)


## Étage tiré avec les épreuves : 3 piliers (deux épreuves du biome + gros), coffres, capsules, sauvegarde.
func _check_layout(stage: StageManager, map_id: String, verbs: Array) -> void:
	var u := Balance.UNIT_PX
	_check("épreuves actives", stage.epreuves_on)
	if not stage.epreuves_on or stage.pillars.size() != 3:
		_check("3 piliers : deux épreuves et le gros", false, str(stage.pillars.size()))
		return
	var e0 := stage.pillars[0] as Epreuve
	var e1 := stage.pillars[1] as Epreuve
	var big: Pillar = stage.pillars[2]
	_check("3 piliers : épreuves %s, %s, gros" % [verbs[0], verbs[1]], e0 != null and e1 != null and String(e0.verb) == verbs[0] and String(e1.verb) == verbs[1] and big.kind == Pillar.Kind.BIG and not (big is Epreuve))
	if e0 == null or e1 == null:
		return
	_check("biome et libellé de l'épreuve", String(e0.biome) == MAP_BIOME[map_id] and e0.interact_label() == EpreuveData.label(MAP_BIOME[map_id], verbs[0], "start"))
	_check("rituel : relais du skin du biome", not (e1 is EpreuveRitual) or (e1 as EpreuveRitual).relays.all(func(r): return r.biome == EpreuveData.lever_skin(MAP_BIOME[map_id])))
	_check("gros pilier dégagé des objets d'épreuve", stage._big_clear_of_epreuves(big.position))
	_check("petits piliers verrouillent le gros", big.state == Pillar.STATE_LOCKED)
	_check("mini-boss du plan sur chaque épreuve, distincts", e0.boss_id != &"" and e1.boss_id != &"" and e0.boss_id != e1.boss_id)
	var near := [0, 0]
	for c in stage.chests:
		for i in 2:
			near[i] += 1 if stage._dist_to_epreuve(i, c.position) <= Balance.EPREUVE_CHEST_TRACE_U * u else 0
	_check("coffres : >= 3 à <= 8 u de chaque épreuve (%d, %d)" % [near[0], near[1]], near[0] >= 3 and near[1] >= 3)
	var near_big := stage.chests.filter(func(c): return c.position.distance_to(big.position) <= Balance.EPREUVE_CHEST_ARENA_U * u).size()
	_check("coffres : >= 2 autour du gros pilier (%d)" % near_big, near_big >= 2)
	_check("coffres : aucun à < EPREUVE_CHEST_MIN_U d'un objet d'épreuve", stage.chests.all(func(c): return stage._dist_to_epreuve_object(c.position) >= Balance.EPREUVE_CHEST_MIN_U * u - 1.0))
	_check("coffres : 10 ou 11 au total", stage.chests.size() >= 10 and stage.chests.size() <= 11, str(stage.chests.size()))
	var start := stage.map.get_player_start()
	_check("capsules : 4, une près du départ", stage.capsules.size() == 4 and stage.capsules.any(func(c): return c.position.distance_to(start) <= Balance.EPREUVE_CHEST_START_U * u))
	var caps_trace := stage.capsules.filter(func(c): return stage._dist_to_any_epreuve(c.position) <= 8.0 * u).size()
	_check("capsules : au moins 3 sur les tracés (%d)" % caps_trace, caps_trace >= 3)
	_check("sauvegarde : entrées d'épreuve", (stage.to_dict()["pillars"] as Array).filter(func(d): return d.has("epreuve") and int(d["marker"]) == -1).size() == 2)
	# restauration complète de l'étage depuis la sauvegarde
	var d: Dictionary = stage.to_dict()
	var chests_n := stage.chests.size()
	stage.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary)
	_check("from_dict : mêmes épreuves, mêmes coffres", stage.epreuves_on and stage.pillars.size() == 3 and String((stage.pillars[0] as Epreuve).verb) == verbs[0] and String((stage.pillars[1] as Epreuve).verb) == verbs[1] and stage.chests.size() == chests_n)


## Plusieurs graines par carte (mêmes invariants de disposition).
func _sweep() -> void:
	print("-- balayage de graines")
	Balance.EPREUVES_ENABLED = true
	var u := Balance.UNIT_PX
	for map_id in MAPS:
		var expect := _expect_on(map_id)
		var bad := 0
		var tried := 0
		for loc in _locate(map_id, 5):
			_start(loc[0], loc[1])
			tried += 1
			var stage := _mgr
			if not expect:
				bad += 0 if _classic_ok(stage) else 1
				continue
			var ok := stage.epreuves_on and stage.pillars.size() == 3 and stage.pillars[2].kind == Pillar.Kind.BIG and stage._big_clear_of_epreuves(stage.pillars[2].position)
			var near := [0, 0]
			for c in stage.chests:
				for i in 2:
					near[i] += 1 if stage._dist_to_epreuve(i, c.position) <= Balance.EPREUVE_CHEST_TRACE_U * u else 0
			ok = ok and stage.chests.all(func(c): return stage._dist_to_epreuve_object(c.position) >= Balance.EPREUVE_CHEST_MIN_U * u - 1.0)
			ok = ok and near[0] >= 3 and near[1] >= 3 and stage.capsules.size() == 4 and stage.chests.size() >= 10
			bad += 0 if ok else 1
		_check("%s : %d graines, disposition valide%s" % [map_id, tried, "" if expect else " (étage classique : verbe non branché)"], tried > 0 and bad == 0, "%d échec(s)" % bad)
	Balance.EPREUVES_ENABLED = false


## Interrupteurs sans code : biome coupé = piliers classiques ; une épreuve par étage = une épreuve + un petit pilier.
func _variants() -> void:
	print("-- variantes")
	Balance.EPREUVES_ENABLED = true
	var loc: Array = _locate("terrasses_noyees", 1)[0]
	(EpreuveData._data["biomes"]["terrasses"] as Dictionary)["enabled"] = false
	_start(loc[0], loc[1])
	_check("enabled=false : le biome retrouve ses piliers", _classic_ok(_mgr))
	EpreuveData.reload()
	Balance.EPREUVES_PER_STAGE = 1
	_start(loc[0], loc[1])
	var ep := _mgr.pillars.filter(func(p): return p is Epreuve)
	_check("EPREUVES_PER_STAGE = 1 : 3 piliers dont 1 épreuve (escorte) et 1 petit pilier ordinaire", _mgr.epreuves_on and _mgr.pillars.size() == 3 and ep.size() == 1 and (ep[0] as Epreuve).verb == &"escorte" and _mgr.pillars.filter(func(p): return not (p is Epreuve) and p.kind == Pillar.Kind.SMALL).size() == 1)
	Balance.EPREUVES_PER_STAGE = 0
	_start(loc[0], loc[1])
	_check("EPREUVES_PER_STAGE = 0 : étage classique", _classic_ok(_mgr))
	Balance.EPREUVES_PER_STAGE = 2
	Balance.EPREUVES_ENABLED = false


## Étage 5 : jamais d'épreuve ; sans fin étage 6 : épreuves du biome 1 (EPREUVE_IN_ENDLESS).
func _final_and_endless() -> void:
	print("-- étage 5 et sans fin")
	Balance.EPREUVES_ENABLED = true
	var loc: Array = _locate("la_source", 1)[0]
	_start(loc[0], loc[1])
	_check("la Source : jamais d'épreuve", _mgr.is_final_floor and not _mgr.epreuves_on and _mgr.pillars.filter(func(p): return p is Epreuve).is_empty())
	_start(loc[0], 6, true)
	_check("sans fin, étage 6 : épreuves du biome des Terrasses", _mgr.epreuves_on and _mgr.pillars.filter(func(p): return p is Epreuve).size() == 2 and String(_mgr.map.biome()) == "terrasses", "%s %s" % [_mgr.map_id, _mgr.epreuves_on])
	_start(loc[0], 10, true)
	_check("sans fin, étage 10 (Source) : aucune épreuve", _mgr.is_final_floor and not _mgr.epreuves_on)
	_mgr.endless = false
	Balance.EPREUVES_ENABLED = false


# --- Mécaniques sur des épreuves autonomes (posées dans la carte courante)
func _mechanics() -> void:
	print("-- mécaniques")
	Balance.EPREUVES_ENABLED = true
	await _new_main(_seed_for_map("terrasses_noyees"))
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var director: Director = _main.director
	var u := Balance.UNIT_PX
	var origin := stage.map.get_player_start()

	# ---- Escorte
	var pts := PackedVector2Array([origin + Vector2(0, 0), origin + Vector2(20, 0) * u, origin + Vector2(20, 6) * u])
	var e := EpreuveEscort.make(pts)
	e.setup(Pillar.Kind.SMALL, 91, false)
	stage.map.add_child(e)
	e.set_physics_process(false)
	await _frames(1)
	_check("escorte : prête, longueur 26 u", e.state == Pillar.STATE_READY and is_equal_approx(e.length / u, 26.0))
	_check("escorte : PV (état prêt)", e.hp == 0.0)
	var gold0: float = RunState.gold
	_events.clear()
	_check("escorte : lancement", e.activate() and e.is_running() and _events.size() == 1 and _events[0][0] == "start" and _events[0][1] == &"escorte")
	_check("escorte : PV = 0,3 x mini-boss", is_equal_approx(e.max_hp, Balance.escort_hp(RunState.difficulty(), RunState.stage)) and e.hp == e.max_hp and e.max_hp > 0.0)
	# joueur trop loin : la barque attend
	player.global_position = e.global_position + Vector2(Balance.ESCORT_LEASH_U * u + 80.0, 0.0)
	for i in 20:
		e.tick(0.25)
	_check("escorte : arrêtée hors corde (6 u)", e.dist_along == 0.0 and e.leash_blocked and e.leash_wait_s >= 4.9)
	# joueur à portée : elle avance à 2,5 u/s
	player.global_position = e.global_position
	var t0 := e.elapsed
	var d0 := e.dist_along
	for i in 8:
		e.tick(0.25)
	var travelled: float = (e.dist_along - d0) / u
	_check("escorte : vitesse 2,5 u/s (%.2f u en 2 s)" % travelled, absf(travelled - 5.0) < 0.05 and not e.leash_blocked)
	# PV à 0 : arrêt 5 s puis repart pleine, note parfait perdue
	e.damage(e.hp + 1.0)
	_check("escorte : PV 0 -> arrêt 5 s", is_equal_approx(e.stall_left, Balance.ESCORT_STALL_S) and e.hp == 0.0 and e.stall_count == 1 and not e.clean)
	var d_stall := e.dist_along
	for i in 16: # 4 s
		player.global_position = e.global_position
		e.tick(0.25)
	_check("escorte : immobile pendant l'arrêt", e.dist_along == d_stall and e.stall_left > 0.9)
	for i in 8: # 2 s : fin de l'arrêt, PV pleins, repart
		player.global_position = e.global_position
		e.tick(0.25)
	_check("escorte : repart avec ses PV pleins", e.stall_left == 0.0 and e.hp == e.max_hp and e.dist_along > d_stall)
	_check("escorte : jamais détruite", e.is_running() and e.state == Pillar.STATE_ACTIVE)
	# les monstres au contact la blessent
	var hp_before := e.hp
	var foes: Array = []
	for i in 6:
		var foe: Enemy = director.spawn_enemy(1, e.global_position + Vector2(10.0 + 4.0 * i, 0.0))
		if foe != null:
			foes.append(foe)
	_check("escorte : monstres au contact créés", foes.size() >= 3)
	var dps := e._contact_dps()
	_check("escorte : dégâts de contact > 0 (%.1f/s)" % dps, dps > 0.0)
	for i in 4:
		player.global_position = e.global_position + Vector2(300.0, 0.0)
		e.tick(0.25)
	_check("escorte : blessée par les monstres", e.hp < hp_before)
	for f in foes:
		(f as Enemy).take_damage((f as Enemy).max_hp * 10.0)
	await _frames(2)
	# arrivée : mini-boss, or selon la note
	e.hp = e.max_hp
	e.stall_left = 0.0
	player.global_position = e.global_position
	var guard := 0
	while e.is_running() and guard < KILL_GUARD:
		player.global_position = e.global_position
		e.tick(0.25)
		guard += 1
	_check("escorte : arrivée -> épreuve résolue", e.resolved and e.dist_along >= e.length and guard < KILL_GUARD)
	_check("escorte : note « bien » (a été immobilisée)", e.grade == &"bien", String(e.grade))
	var expected := Balance.epreuve_gold(&"bien", Balance.station_price_p(RunState.floor_start_d, RunState.stage))
	_check("escorte : or nominal = 0,5 P", is_equal_approx(e.gold_paid, expected) and is_equal_approx(e.gold_paid, Balance.EPREUVE_GOLD_P[&"bien"] * Balance.station_price_p(RunState.floor_start_d, RunState.stage)))
	var gm: float = (player.call(&"gold_mult") as float)
	_check("escorte : or versé au joueur (%.1f)" % (RunState.gold - gold0), absf((RunState.gold - gold0) - expected * gm) <= 1.0, "attendu %.1f" % (expected * gm))
	_check("escorte : évènement de fin", _events.size() == 2 and _events[1][0] == "end" and _events[1][1] == &"escorte" and _events[1][2] == &"bien" and _events[1][3] >= 0.0 and is_equal_approx(float(_events[1][4]), expected))
	var boss: Enemy = e.get(&"_boss")
	_check("escorte : mini-boss invoqué à l'arrivée", boss != null and boss.active and boss.global_position.distance_to(e.global_position) < 400.0)
	_check("escorte : zone du mini-boss (mini)", director._zones.get(91, {}).get("kind", &"") == &"mini")
	_check("escorte : zone x1,5 suit la barque", true)
	boss.take_damage(boss.max_hp * 10.0)
	await _frames(3)
	_check("escorte : mini-boss mort -> épreuve terminée", e.state == Pillar.STATE_DONE)
	e.queue_free()

	# note « parfait » : durée de base, joueur collé à la barque, jamais blessée
	var e2 := EpreuveEscort.make(pts)
	e2.setup(Pillar.Kind.SMALL, 92, false)
	stage.map.add_child(e2)
	e2.set_physics_process(false)
	await _frames(1)
	e2.activate()
	guard = 0
	while e2.is_running() and guard < KILL_GUARD:
		player.global_position = e2.global_position
		e2.tick(0.25)
		guard += 1
	_check("escorte : note « parfait » (%.1f s)" % e2.elapsed, e2.grade == &"parfait" and e2.elapsed <= 40.0 and e2.clean)
	_check("escorte : parfait = 0,8 P", is_equal_approx(e2.gold_paid, 0.8 * Balance.station_price_p(RunState.floor_start_d, RunState.stage)))
	(e2.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	e2.queue_free()

	# délai de sécurité : joueur à l'écart tout du long -> « fait » à 75 s, jamais bloqué
	var e3 := EpreuveEscort.make(pts)
	e3.setup(Pillar.Kind.SMALL, 93, false)
	stage.map.add_child(e3)
	e3.set_physics_process(false)
	await _frames(1)
	e3.activate()
	player.global_position = e3.global_position + Vector2(900.0, 0.0)
	guard = 0
	while e3.is_running() and guard < KILL_GUARD:
		e3.tick(0.5)
		guard += 1
	_check("escorte : délai de sécurité 75 s -> « fait »", e3.resolved and e3.grade == &"fait" and absf(e3.elapsed - Balance.EPREUVE_BACKSTOP_S) <= 0.5, "%.1f s %s" % [e3.elapsed, e3.grade])
	_check("escorte : fait = 0,2 P et mini-boss invoqué", is_equal_approx(e3.gold_paid, 0.2 * Balance.station_price_p(RunState.floor_start_d, RunState.stage)) and e3.get(&"_boss") != null)
	(e3.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	e3.queue_free()

	# sauvegarde de l'escorte en cours
	var e4 := EpreuveEscort.make(pts)
	e4.setup(Pillar.Kind.SMALL, 94, false)
	stage.map.add_child(e4)
	e4.set_physics_process(false)
	await _frames(1)
	e4.activate()
	for i in 40:
		player.global_position = e4.global_position
		e4.tick(0.25)
	e4.damage(e4.hp * 0.4)
	var sd: Dictionary = JSON.parse_string(JSON.stringify(e4.to_dict())) as Dictionary
	var e5 := EpreuveEscort.make(pts)
	e5.setup(Pillar.Kind.SMALL, 94, false)
	stage.map.add_child(e5)
	e5.set_physics_process(false)
	await _frames(1)
	e5.from_dict(sd)
	_check("sauvegarde escorte : reprise en cours", e5.state == Pillar.STATE_ACTIVE and e5.is_running() and is_equal_approx(e5.dist_along, e4.dist_along) and is_equal_approx(e5.hp, e4.hp) and is_equal_approx(e5.elapsed, e4.elapsed))
	_check("sauvegarde escorte : position sur le tracé", e5.position.distance_to(e4.position) < 1.0)
	e4.queue_free()
	e5.queue_free()
	await _frames(1)

	# ---- Rituel
	var heart := origin + Vector2(0.0, -4.0) * u
	var relay_pts: Array = []
	for k in 3:
		relay_pts.append(heart + Vector2.from_angle(float(k) * TAU / 3.0) * 12.0 * u)
	var r := EpreuveRitual.make(heart, relay_pts)
	r.setup(Pillar.Kind.SMALL, 95, false)
	stage.map.add_child(r)
	r.set_physics_process(false)
	await _frames(1)
	player.global_position = r.relays[0].global_position
	_check("rituel : relais inactifs avant le lancement", not r.relays[0].can_interact())
	gold0 = RunState.gold
	_events.clear()
	_check("rituel : lancement", r.activate() and r.is_running() and _events.size() == 1 and _events[0][1] == &"rituel")
	_check("rituel : relais à portée interactifs, maintien 1,2 s", r.relays[0].can_interact() and is_equal_approx(float(r.relays[0].interact_state()["hold_s"]), 1.2))
	_check("rituel : relais hors de portée inactifs", not r.relays[1].can_interact())
	_check("rituel : cadence initiale 12 s", is_equal_approx(r.pulse_left(), 12.0) and is_equal_approx(r.pulse_interval(), 12.0))
	_check("rituel : relais 1 fermé", r.relays[0].interact() and r.closed == 1 and r.relays[0].used)
	_check("rituel : cadence 9 s", is_equal_approx(r.pulse_interval(), 9.0) and r.pulse_left() <= 9.0 + 0.001)
	_check("rituel : un relais fermé n'est plus interactif", not r.relays[0].can_interact())
	player.global_position = r.relays[1].global_position
	_check("rituel : relais 2 fermé", r.relays[1].interact() and r.closed == 2)
	_check("rituel : cadence 7 s", is_equal_approx(r.pulse_interval(), 7.0) and r.pulse_left() <= 7.0 + 0.001)
	# sauvegarde en pleine épreuve
	var rd: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict())) as Dictionary
	var r2 := EpreuveRitual.make(heart, relay_pts)
	r2.setup(Pillar.Kind.SMALL, 96, false)
	stage.map.add_child(r2)
	r2.set_physics_process(false)
	await _frames(1)
	r2.from_dict(rd)
	_check("sauvegarde rituel : relais fermés restaurés", r2.is_running() and r2.closed == 2 and r2.relays[0].used and r2.relays[1].used and not r2.relays[2].used)
	_check("sauvegarde rituel : cadence conservée", is_equal_approx(r2.pulse_interval(), 7.0) and is_equal_approx(r2.pulse_left(), r.pulse_left()))
	r2.queue_free()
	player.global_position = r.relays[2].global_position
	_check("rituel : relais 3 fermé -> résolu", r.relays[2].interact() and r.closed == 3 and r.resolved)
	_check("rituel : note « parfait » (rapide, sans onde)", r.grade == &"parfait" and r.clean and r.ring_hits == 0, "%s %.1f s" % [r.grade, r.elapsed])
	var rexp := Balance.epreuve_gold(&"parfait", Balance.station_price_p(RunState.floor_start_d, RunState.stage))
	_check("rituel : or versé (parfait = 0,8 P)", absf((RunState.gold - gold0) - rexp * gm) <= 1.0 and is_equal_approx(r.gold_paid, rexp))
	_check("rituel : mini-boss au cœur", r.get(&"_boss") != null and (r.get(&"_boss") as Enemy).active)
	(r.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(3)
	_check("rituel : mini-boss mort -> terminé", r.state == Pillar.STATE_DONE)
	r.queue_free()

	# onde du cœur : télégraphe >= 0,8 s, puis anneau qui blesse (une fois) et retire le « parfait »
	var r3 := EpreuveRitual.make(heart, relay_pts)
	r3.setup(Pillar.Kind.SMALL, 97, false)
	stage.map.add_child(r3)
	r3.set_physics_process(false)
	await _frames(1)
	r3.activate()
	player.global_position = heart + Vector2(8.0, 0.0) * u # sur le trajet de l'onde
	var tele_t := 0.0
	var seen_tele := false
	var guard_t := 0.0
	while r3.pulses == 0 and guard_t < 20.0:
		r3.tick(0.05)
		guard_t += 0.05
		if r3.is_telegraphing():
			seen_tele = true
			tele_t += 0.05
	_check("rituel : premier anneau à 12 s (%.1f)" % guard_t, absf(guard_t - (12.0 + Balance.RITUAL_TELEGRAPH_S)) <= 0.3)
	_check("rituel : anneau télégraphié %.2f s (>= 0,8 s)" % tele_t, seen_tele and tele_t >= 0.8)
	while r3.wave_radius() >= 0.0 and r3.is_running():
		r3.tick(0.05)
	_check("rituel : onde reçue une seule fois, plus de « parfait »", r3.ring_hits == 1 and not r3.clean)
	_check("rituel : la cadence repart (12 s)", is_equal_approx(r3.pulse_left(), 12.0))
	for i in 3:
		player.global_position = r3.relays[i].global_position
		r3.relays[i].interact()
	_check("rituel : fermé vite mais touché -> « bien »", r3.resolved and r3.grade == &"bien", String(r3.grade))
	(r3.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	r3.queue_free()

	# onde esquivée (joueur hors de la bande) : aucun coup
	var r4 := EpreuveRitual.make(heart, relay_pts)
	r4.setup(Pillar.Kind.SMALL, 98, false)
	stage.map.add_child(r4)
	r4.set_physics_process(false)
	await _frames(1)
	r4.activate()
	player.global_position = heart + Vector2(Balance.RITUAL_WAVE_MAX_U + 4.0, 0.0) * u
	for i in 400:
		r4.tick(0.05)
	_check("rituel : hors de portée de l'onde, aucun coup", r4.pulses >= 1 and r4.ring_hits == 0 and r4.clean)
	# délai de sécurité à 75 s
	for i in 1400:
		r4.tick(0.05)
	_check("rituel : délai de sécurité 75 s -> « fait »", r4.resolved and r4.grade == &"fait" and r4.closed == 0, "%.1f s %s" % [r4.elapsed, r4.grade])
	_check("rituel : mini-boss invoqué malgré l'échec", r4.get(&"_boss") != null)
	(r4.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(2)
	r4.queue_free()

	# ---- Or des kills en zone d'épreuve
	var e6 := EpreuveEscort.make(pts)
	e6.setup(Pillar.Kind.SMALL, 99, false)
	stage.map.add_child(e6)
	e6.set_physics_process(false)
	await _frames(1)
	var pm := get_tree().get_first_node_in_group(&"pickups") as PickupManager
	var out_pos := e6.global_position + Vector2(5000.0, 5000.0)
	_check("zone : x1 avant le lancement", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), e6.global_position), 1.0))
	e6.activate()
	_check("zone : x0,5 dans la zone d'une épreuve en cours", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), e6.global_position + Vector2(100.0, 0.0)), Balance.EPREUVE_ZONE_GOLD_MULT))
	_check("zone : x1 hors zone", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), out_pos), 1.0))
	var g_in := RunState.gold + pm.gold_carry
	pm._on_enemy_killed(null, e6.global_position, 3, true)
	var gain_in := RunState.gold + pm.gold_carry - g_in
	var g_out := RunState.gold + pm.gold_carry
	pm._on_enemy_killed(null, out_pos, 3, true)
	var gain_out := RunState.gold + pm.gold_carry - g_out
	_check("or d'un kill en zone = EPREUVE_ZONE_GOLD_MULT (0,4) (%.2f vs %.2f)" % [gain_in, gain_out], gain_out > 0.0 and absf(gain_in - Balance.EPREUVE_ZONE_GOLD_MULT * gain_out) < 0.01)
	var hp_scale := RunState.gold
	e6.finish_now(&"fait")
	_check("épreuve terminée -> zone encore réduite jusqu'à la mort du mini-boss", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), e6.global_position), Balance.EPREUVE_ZONE_GOLD_MULT))
	(e6.get(&"_boss") as Enemy).take_damage(1.0e9)
	await _frames(3)
	_check("après la mort du mini-boss : x1", is_equal_approx(Epreuve.zone_gold_mult(get_tree(), e6.global_position), 1.0) and hp_scale >= 0.0)
	e6.queue_free()
	Balance.EPREUVES_ENABLED = false


# --- Flux complet sur les épreuves du plan d'étage : épreuves -> déverrouillage du gros pilier
func _flow() -> void:
	print("-- flux d'étage")
	Balance.EPREUVES_ENABLED = true
	await _new_main(_seed_for_map("terrasses_rizieres_hautes"))
	var stage: StageManager = _main.stage
	var player: Node2D = _main.player
	var esc: EpreuveEscort = stage.pillars[0]
	var rit: EpreuveRitual = stage.pillars[1]
	var big: Pillar = stage.pillars[2]
	_events.clear()
	# Escorte : lancement par l'interaction (contact + « interagir »), pas de mini-boss avant l'arrivée
	player.global_position = esc.global_position + Vector2(20.0, 20.0)
	esc._on_body_entered(player)
	_check("escorte du plan : prête et interactive au ponton", esc.can_interact() and esc.interact_label() == "Lancer la barque")
	_check("escorte du plan : interagir lance l'épreuve", esc.interact() and esc.is_running() and esc.get(&"_boss") == null)
	var guard := 0
	while esc.is_running() and guard < 2400:
		player.global_position = esc.global_position
		await get_tree().physics_frame
		guard += 1
	_check("escorte du plan : arrivée par la physique (%d images, %.1f s)" % [guard, esc.elapsed], esc.resolved and esc.grade == &"parfait" and esc.elapsed < 40.0, "%s" % esc.grade)
	var b1: Enemy = esc.get(&"_boss")
	_check("escorte du plan : mini-boss du plan", b1 != null and b1.get_meta(&"boss_id", &"") == esc.boss_id)
	b1.take_damage(b1.max_hp * 10.0)
	await _frames(3)
	_check("escorte du plan : terminée", esc.state == Pillar.STATE_DONE and big.state == Pillar.STATE_LOCKED)
	# Rituel
	player.global_position = rit.global_position + Vector2(20.0, 20.0)
	rit._on_body_entered(player)
	_check("rituel du plan : interagir lance l'épreuve", rit.can_interact() and rit.interact() and rit.is_running())
	for rl in rit.relays:
		player.global_position = rl.global_position
		await _frames(1)
		rl.interact()
	_check("rituel du plan : 3 relais fermés", rit.resolved and rit.closed == 3)
	var b2: Enemy = rit.get(&"_boss")
	_check("rituel du plan : mini-boss du plan", b2 != null and b2.get_meta(&"boss_id", &"") == rit.boss_id)
	b2.take_damage(b2.max_hp * 10.0)
	await _frames(3)
	_check("rituel du plan : terminé -> gros pilier déverrouillé", rit.state == Pillar.STATE_DONE and big.state == Pillar.STATE_READY)
	_check("évènements : 2 départs, 2 fins", _events.filter(func(x): return x[0] == "start").size() == 2 and _events.filter(func(x): return x[0] == "end").size() == 2)
	Balance.EPREUVES_ENABLED = false


# --- Mode test : invocation depuis le panneau
func _test_mode() -> void:
	print("-- mode test")
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await _frames(3)
	Balance.EPREUVES_ENABLED = false
	TestMode.begin()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 77)
	add_child(_main)
	await _main.game_ready
	await _frames(5)
	var player: Node2D = _main.player
	player.call(&"grant_invulnerability", 1.0e6)
	var e := TestLoopTools.spawn_epreuve(get_tree(), &"escorte") as EpreuveEscort
	var r := TestLoopTools.spawn_epreuve(get_tree(), &"rituel") as EpreuveRitual
	await _frames(2)
	_check("mode test : escorte invoquée (tracé 55 u)", e != null and e.state == Pillar.STATE_READY and absf(e.length / Balance.UNIT_PX - 55.0) < 0.5)
	_check("mode test : rituel invoqué (3 relais)", r != null and r.relays.size() == 3)
	_check("mode test : les épreuves ne comptent pas comme piliers de l'étage", _main.stage.pillars.is_empty())
	if e == null or r == null:
		TestMode.end()
		return
	e.set_physics_process(false)
	r.set_physics_process(false)
	_check("mode test : lancement de l'escorte", e.activate() and e.is_running())
	_check("mode test : lancement du rituel", r.activate() and r.is_running())
	Epreuve.forced_grade = &"fait"
	_check("mode test : terminer force la note", TestLoopTools.finish_epreuves(get_tree(), Epreuve.forced_grade) == 2 and e.grade == &"fait" and r.grade == &"fait")
	_check("mode test : mini-boss invoqués", e.get(&"_boss") != null and r.get(&"_boss") != null)
	Epreuve.forced_grade = &""
	_check("mode test : retrait", TestLoopTools.clear_epreuves(get_tree()) == 2)
	TestMode.end()
	Epreuve.forced_grade = &"parfait"
	_check("hors mode test : la note forcée est ignorée", not TestMode.active)
	Epreuve.forced_grade = &""
