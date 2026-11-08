extends Node
## Événements ambiants par carte (`ambient_event.effects` des 9 cartes, AmbientEvents, docs/Design_Variantes_B.md §7) :
## - chaque carte jouable a un événement nommé et des effets de types connus ; gen_maps.py et les JSON concordent ;
## - aucun effet avant son seuil (rien de créé : ni nœud, ni lumière), démarrage au seuil, idempotent (un seul start
##   tant que D reste au-dessus), paliers supérieurs (Furieux, Cataclysme) seulement à leur D ;
## - effets visibles : crue (uniform du masque d'eau), creusets (masque _e orange + lueur), cristaux (vague),
##   puits voilés, bouffées de vent (wind_mult restauré), colonne de pluie épaissie, pluie locale bornée au puits,
##   noria (repli sans SpriteFrames, besoin d'asset signalé) ;
## - redescente sous le seuil et changement d'étage : tout est rétabli et libéré ;
## - Bas : effets réduits (moins de gouttes, pas d'éclaboussures ni de traînées de vent).
## godot --headless --path game res://tests/ambient_events_test.tscn  -> RESULT: OK

const MAPS := ["terrasses_noyees", "foret_brume", "cite_rouille", "cryptes_noyees", "la_source",
	"terrasses_rizieres_hautes", "foret_mangrove_lanternes", "cite_fonderie_canal", "cryptes_ossuaire_pluies"]

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	Quality.set_tier(Quality.Tier.HIGH, true)
	# Comme la scène de jeu (tonnerre piloté par AmbianceManager.thunder, non branché ici) : pas de grondement de
	# secours sur Events.lightning_struck, sinon un tonnerre joue encore à la sortie du test (flux non libéré).
	Audio.thunder_driven = true
	for id in MAPS:
		await _test_map(id)
	await _test_floor_change()
	await _test_quality_low()
	print("RESULT: ", "OK" if _fails == 0 else "FAILED (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _new_mgr() -> AmbianceManager:
	var mgr: AmbianceManager = load("res://scenes/ambiance/ambiance_manager.tscn").instantiate()
	mgr.auto_bind = false
	mgr.cosmetic_sky = false
	add_child(mgr)
	return mgr


func _new_map(id: String) -> Node2D:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	var map: Node2D = load(String(d["scene"])).instantiate()
	add_child(map)
	move_child(map, 0)
	if id == "la_source": # posée par StageManager à l'étage final (pas de StageManager ici)
		var col := SourceColumn.new()
		map.add_child(col)
	return map


func _run(mgr: AmbianceManager, D: float, seconds: float, dt: float = 0.1) -> void:
	mgr.set_difficulty(D)
	var n := int(ceil(seconds / dt))
	for i in n:
		mgr._process(dt)


func _free(mgr: AmbianceManager, map: Node2D) -> void:
	mgr.queue_free()
	map.queue_free()
	LightRig.clear_all()
	await get_tree().process_frame


func _test_map(id: String) -> void:
	var raw: Dictionary = AmbientEvents.read_event(id)
	_check(not raw.is_empty() and String(raw.get("name", "")) != "", "%s : ambient_event nommé" % id)
	var mgr := _new_mgr()
	var map := _new_map(id)
	_check(mgr.bind_map(map), "%s : bind" % id)
	var ev := mgr.events
	_check(ev.event_name == String(raw.get("name", "")), "%s : événement lu (« %s »)" % [id, ev.event_name])
	_check(not ev.effects.is_empty(), "%s : au moins un effet reconnu" % id)
	_check(ev.unknown_types.is_empty(), "%s : types d'effets inconnus %s" % [id, ev.unknown_types])
	var min_thr := 99.0
	for fx in ev.effects:
		min_thr = minf(min_thr, fx.threshold)
		_check(fx.threshold >= ev.threshold - 0.001, "%s : %s jamais avant le seuil de l'événement" % [id, fx.type])

	# Avant le seuil : rien d'actif, rien de créé.
	var req0 := LightRig.request_count()
	var kids0 := ev.get_child_count()
	_run(mgr, min_thr - 0.05, 3.0)
	_check(ev.active_count() == 0 and not mgr.event_active(), "%s : aucun effet sous le seuil (D=%.2f)" % [id, min_thr - 0.05])
	_check(LightRig.request_count() == req0 and ev.get_child_count() == kids0, "%s : aucun coût sous le seuil" % id)
	for fx in ev.effects:
		_check(fx.start_count == 0, "%s : %s pas démarré sous le seuil" % [id, fx.type])

	# Au seuil de l'événement : seuls les effets de ce seuil démarrent, une fois.
	_run(mgr, ev.threshold, 2.0)
	_check(mgr.event_active(), "%s : événement actif au seuil" % id)
	for fx in ev.effects:
		var want := fx.threshold <= ev.threshold + 0.001
		_check(fx.active == want, "%s : %s %s au seuil %.1f" % [id, fx.type, "actif" if want else "inactif", ev.threshold])
		_check(fx.start_count == (1 if want else 0), "%s : %s démarré %d fois (idempotence)" % [id, fx.type, fx.start_count])

	# Cataclysme : tous actifs, toujours un seul démarrage chacun.
	_run(mgr, 7.5, 20.0)
	for fx in ev.effects:
		_check(fx.active and fx.start_count == 1, "%s : %s actif à Cataclysme (%d démarrages)" % [id, fx.type, fx.start_count])
		_check_effect(id, mgr, fx)

	# Redescente : tout est rétabli.
	_run(mgr, 1.0, 1.0)
	_check(ev.active_count() == 0, "%s : tout s'arrête sous le seuil" % id)
	_check(is_zero_approx(mgr.water.flood_level()), "%s : crue retirée" % id)
	_check(is_zero_approx(mgr.gust_level) and is_equal_approx(mgr.shaft_ray_target, 1.0), "%s : vent et rais rétablis" % id)
	for fx in ev.effects:
		if fx.type == "prop_pulse":
			_check(int(fx.describe()["lights"]) == 0 and int(fx.describe()["emissions"]) == 0, "%s : lueurs libérées, masques _e rétablis" % id)
			for s in fx.fixed_props(String(fx.def.get("prop", ""))):
				var em := AmbientEffect.emission_of(s)
				_check(em == null or em.self_modulate.r <= em.self_modulate.b * 1.5, "%s : masque _e plus orange (%s)" % [id, em.self_modulate if em != null else Color()])
		if fx.type == "local_rain":
			_check(fx.get(&"root") == null, "%s : pluie locale libérée" % id)
	await _free(mgr, map)


func _check_effect(id: String, mgr: AmbianceManager, fx: AmbientEffect) -> void:
	var d := fx.describe()
	match fx.type:
		"flood":
			_check(int(d["cells"]) > 0, "%s : cases inondables (%d)" % [id, int(d["cells"])])
			_check(mgr.water.flood_ready(), "%s : masque de crue prêt" % id)
			_check(mgr.water.flood_level() > 0.3, "%s : la crue monte (%.2f)" % [id, mgr.water.flood_level()])
			var chan: Vector4 = mgr.water._shallow_mat.get_shader_parameter(&"region_chan")
			_check(chan.w > 0.3 and is_equal_approx(chan.y, 1.0), "%s : uniform du masque (%s)" % [id, chan])
			# Cohérence : le jeu lit toujours la grille d'origine (visuel seulement).
			var g := AmbianceWater.grid_of(mgr.map)
			var commas := 0
			for r in (g["grid"] as PackedStringArray):
				commas += r.count(",")
			var orig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
			var c0 := 0
			for r in orig["grid"]:
				c0 += String(r).count(",")
			_check(commas == c0, "%s : grille de jeu inchangée" % id)
		"decor_lightning":
			var lz: Variant = fx
			lz.set(&"_wait", 0.0)
			var before := int(lz.get(&"strikes"))
			mgr.lightning._last_event = -100.0
			mgr._process(0.1)
			var covered := bool(lz.call(&"profile_covers"))
			_check(covered or int(lz.get(&"strikes")) == before + 1, "%s : éclair de décor (profil %s)" % [id, "couvre" if covered else "ne couvre pas"])
			# Profil sans orage à ce palier : l'effet frappe bien lui-même.
			mgr.current_params()[&"lightning_interval_max"] = 0.0
			lz.set(&"_wait", 0.0)
			mgr.lightning._last_event = -100.0
			mgr.lightning._history.clear()
			var b2 := int(lz.get(&"strikes"))
			lz.call(&"process", 0.1)
			_check(int(lz.get(&"strikes")) == b2 + 1, "%s : éclair imposé quand le profil n'en planifie pas" % id)
		"prop_pulse":
			_check(int(d["props"]) > 0 and int(d["emissions"]) > 0, "%s : creusets et masques _e (%d / %d)" % [id, int(d["props"]), int(d["emissions"])])
			_check(int(d["lights"]) == int(d["props"]), "%s : une lueur par creuset" % id)
			var em := AmbientEffect.emission_of((fx.get(&"sprites") as Array)[0])
			_check(em != null and em.self_modulate.r > em.self_modulate.b * 2.0, "%s : masque _e orange (%s)" % [id, em.self_modulate if em != null else Color()])
		"light_waves":
			_check(int(d["lights"]) > 0, "%s : cristaux (lumières %d, props %d)" % [id, int(d["lights"]), int(d["props"])])
			fx.call(&"force_wave")
			var lo := 1.0
			for i in 40:
				mgr._process(0.1)
				lo = minf(lo, float(fx.get(&"min_mult")))
			_check(lo < 0.5, "%s : un cristal s'éteint dans la vague (x%.2f)" % [id, lo])
		"shaft_veil":
			var n := 0
			for ml in mgr.map_lights():
				var p := StringName(ml["def"]["preset"])
				var h: LightRig.Handle = ml["handle"]
				if p == &"light_shaft":
					n += 1
					_check(is_equal_approx(h.energy_mult, float(ml["def"].get("energy", 1.0)) * 0.4), "%s : puits voilé x0,4" % id)
				elif p == &"mycelium_glow":
					_check(is_equal_approx(h.energy_mult, float(ml["def"].get("energy", 1.0)) * 1.35), "%s : mycélium x1,35" % id)
			_check(n == 3, "%s : 3 puits (%d)" % [id, n])
			_check(mgr._ray_k < 0.6, "%s : rai voilé (%.2f)" % [id, mgr._ray_k])
			_check(AmbianceProfile.luminance(mgr.canvas_modulate.color) > 0.08, "%s : jamais d'obscurité" % id)
		"gusts":
			fx.call(&"force_gust")
			var peak := 0.0
			var wind_seen := 0.0
			var push_seen := 0.0
			var wind_base := float(mgr.current_params()[&"wind_mult"])
			for i in 60:
				mgr._process(0.1)
				peak = maxf(peak, mgr.gust_level)
				wind_seen = maxf(wind_seen, float(mgr.current_params()[&"wind_mult"]))
				push_seen = maxf(push_seen, mgr.weather.gust_push().length())
			_check(peak > 0.9 and int(fx.get(&"gusts")) >= 1, "%s : une bouffée (pic %.2f)" % [id, peak])
			_check(push_seen > 0.0, "%s : spores poussées par le vent" % id)
			_check(absf(wind_seen - wind_base) < 0.05, "%s : wind_mult du profil restauré après _push" % id)
			_check(bool(d["streaks"]), "%s : traînées de vent en Haut" % id)
		"rain_column":
			_check(bool(d["found"]) and float(d["k"]) > 0.5, "%s : colonne épaissie (k %.2f)" % [id, float(d["k"])])
			var col := mgr.map.get_node_or_null(^"SourceColumn") as Node2D
			_check(col != null and col.scale.x > 1.2, "%s : largeur de la colonne (%.2f)" % [id, col.scale.x if col != null else 0.0])
		"local_rain":
			_check(bool(d["anchor"]) and int(d["drops"]) == 96, "%s : pluie locale (Haut : %d gouttes)" % [id, int(d["drops"])])
			_check(bool(d["splashes"]), "%s : éclaboussures en Haut" % id)
			var anchor: Node2D = fx.get(&"anchor")
			var b: Rect2 = fx.call(&"bounds")
			var r := float(fx.call(&"radius_px"))
			var h := float(fx.call(&"height_px"))
			_check(b.size.x > 0.0 and b.size.x <= 2.0 * r + 1.0, "%s : largeur bornée (%.0f <= %.0f px)" % [id, b.size.x, 2.0 * r])
			_check(absf(b.get_center().x - anchor.global_position.x) < 1.0, "%s : centrée sur la margelle" % id)
			_check(b.end.y <= anchor.global_position.y + r + 1.0 and b.position.y >= anchor.global_position.y - 2.0 * h - 2.0 * r - 1.0, "%s : hauteur bornée au puits (%s)" % [id, b])
			# Rien ailleurs : la pluie globale du profil ne change pas.
			_check(is_equal_approx(float(mgr.current_params()[&"rain_intensity"]), float(mgr.target_params()[&"rain_intensity"])), "%s : pluie globale inchangée" % id)
		"prop_anim":
			if bool(d["asset"]):
				_check(int(d["animated"]) > 0, "%s : roue animée" % id)
			else:
				_check(int(d["animated"]) == 0, "%s : sans SpriteFrames, aucune animation en code" % id)
				_check(not fx.missing.is_empty(), "%s : besoin d'asset signalé" % id)
				print("NOTE : %s, asset manquant : %s" % [id, ", ".join(fx.missing)])
				for s in fx.fixed_props("noria"):
					_check(is_equal_approx(s.rotation, 0.0) and s.self_modulate.a > 0.99, "%s : sprite statique intact" % id)


## Changement d'étage : la pluie locale de l'Ossuaire est libérée, la crue retirée, la carte suivante repart à zéro.
func _test_floor_change() -> void:
	var mgr := _new_mgr()
	var map := _new_map("cryptes_ossuaire_pluies")
	mgr.bind_map(map)
	_run(mgr, 7.0, 10.0)
	var rain: AmbientEffect = mgr.events.find("local_rain")
	var root: Node2D = rain.get(&"root")
	_check(root != null and is_instance_valid(root), "étage : pluie locale posée")
	_check(mgr.water.flood_level() > 0.0, "étage : crue en cours")
	var map2 := _new_map("terrasses_noyees")
	mgr.bind_map(map2)
	_check(not rain.active and rain.get(&"root") == null, "étage : ancienne pluie locale arrêtée")
	_check(mgr.events.event_name == "Bassins débordants" and mgr.events.find("local_rain") == null, "étage : événement de la nouvelle carte")
	_check(is_zero_approx(mgr.water.flood_level()), "étage : crue repartie de zéro")
	mgr.set_difficulty(1.0) # la frame qui suit ne doit pas redémarrer la crue de la nouvelle carte
	await get_tree().process_frame
	_check(not is_instance_valid(root), "étage : nœuds de la pluie locale libérés")
	mgr.events.tick(0.1, 7.0)
	_check(mgr.events.active_count() == 1, "étage : nouvelle carte démarrée")
	map.queue_free()
	# Carte retirée sans nouveau bind (fin de partie) : coupure propre au tick suivant.
	map2.queue_free()
	await get_tree().process_frame
	mgr.events.tick(0.1, 7.0)
	_check(mgr.events.effects.is_empty() and mgr.events.event_name == "", "étage : carte libérée -> événements vidés")
	await _free(mgr, Node2D.new())


## Bas : moins de gouttes, pas d'éclaboussures, pas de traînées de vent ; bascule à chaud.
func _test_quality_low() -> void:
	var mgr := _new_mgr()
	var map := _new_map("cryptes_ossuaire_pluies")
	mgr.bind_map(map)
	_run(mgr, 3.0, 2.0)
	var rain: AmbientEffect = mgr.events.find("local_rain")
	var hi := int(rain.describe()["drops"])
	Quality.set_tier(Quality.Tier.LOW, true)
	_run(mgr, 3.0, 1.0)
	var d := rain.describe()
	_check(rain.active and int(d["drops"]) < hi and int(d["drops"]) == 24, "Bas : gouttes réduites (%d < %d)" % [int(d["drops"]), hi])
	_check(not bool(d["splashes"]), "Bas : pas d'éclaboussures locales")
	_check(rain.start_count == 1, "Bas : pas de redémarrage compté")
	await _free(mgr, map)
	mgr = _new_mgr()
	map = _new_map("foret_mangrove_lanternes")
	mgr.bind_map(map)
	_run(mgr, 3.0, 1.0)
	_check(not bool(mgr.events.find("gusts").describe()["streaks"]), "Bas : pas de traînées de vent")
	await _free(mgr, map)
	Quality.set_tier(Quality.Tier.HIGH, true)
