extends Node
## Ambiance lumineuse : profils, interpolation en D, application et transitions, occluders sur
## une vraie carte, eau, sources de la carte, budgets de lumières par palier, garde-fous des
## éclairs, masques d'émission (plus de normal maps), règle de décision de Quality.
## godot --headless --path game res://tests/ambiance_test.tscn

const MAPS := ["terrasses_noyees", "foret_brume", "cite_rouille"]
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	Quality.persist = false
	Quality.dynamic_degrade = false
	_test_profiles()
	_test_quality_rule()
	await _test_manager()
	_test_emission_maps()
	print("missing textures: ", AmbianceTextures.missing())
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _test_profiles() -> void:
	for id in MAPS:
		var p := AmbianceManager.load_profile(StringName(id))
		_check(p != null, "profil %s chargé" % id)
		if p == null:
			continue
		_check(p.map_id == StringName(id), "map_id %s" % id)
		var base := p.base_params()
		var e1 := p.evaluate(1.0)
		_check(e1[&"rain_intensity"] == base[&"rain_intensity"], "%s : D=1 = état Calme" % id)
		var cat := p.params_for_tier(&"Cataclysme")
		var e9 := p.evaluate(9.0)
		_check(is_equal_approx(float(e9[&"rain_intensity"]), float(cat[&"rain_intensity"])), "%s : gelé au-delà de D=7" % id)
		var prev := -1.0
		for i in 61:
			var D := 1.0 + i * 0.1
			var e := p.evaluate(D)
			var r := float(e[&"rain_intensity"])
			_check(r >= prev - 1e-5, "%s : pluie croissante en D (%.1f)" % [id, D])
			prev = r
			_check(float(e[&"rain_opacity"]) <= 0.1201, "%s : pluie <= 12 %% (D=%.1f)" % [id, D])
			# §0 règle 6 : chaque calque <= 15 % ; la somme plein écran est plafonnée à 15 % par
			# fog_scroll.gdshader (la carte 1 dépasse à Hostile : brume des bassins masquée dans le doc).
			_check(float(e[&"fog_low_opacity"]) <= 0.1501 and float(e[&"fog_high_opacity"]) <= 0.1501, "%s : brume <= 15 %% (D=%.1f)" % [id, D])
			for sun_on in [true, false]:
				var amb: Color = e[&"ambient_color"] if sun_on else e[&"ambient_low"]
				var sc: Color = e[&"sun_color"]
				var se := float(e[&"sun_energy"])
				# v2 : sol >= 0,20 (ambiante + ciel), entités >= 0,42 (+ fill) ; sans fill, l'ambiante porte tout.
				var g := AmbianceProfile.guard_ambient(amb, sc, se, sun_on)
				var ground := AmbianceProfile.ground_luminance(g, sc, se, sun_on)
				var floor_lum := AmbianceProfile.ground_floor(sun_on)
				_check(ground >= floor_lum - 0.002, "%s : sol >= %.2f (D=%.1f, soleil %s) : %.3f" % [id, floor_lum, D, sun_on, ground])
				_check(ground <= 0.36, "%s : sol sombre (<= 0,36) (D=%.1f, soleil %s) : %.3f" % [id, D, sun_on, ground])
				if not sun_on: # Bas : l'ambiante basse ne doit pas être plus claire que l'ambiante de jour
					_check(AmbianceProfile.luminance(amb) <= AmbianceProfile.luminance(e[&"ambient_color"]) + 0.002, "%s : ambient_low <= ambient_color (D=%.1f)" % [id, D])
				var fc: Color = e[&"fill_color"]
				var fe := AmbianceProfile.guard_fill(g, sc, se, sun_on, fc, float(e[&"fill_energy"] if sun_on else e[&"fill_energy_low"]))
				var eff := AmbianceProfile.entity_luminance(g, sc, se, sun_on, fc, fe)
				_check(eff >= AmbianceProfile.MIN_EFFECTIVE_LUMINANCE - 0.002, "%s : entités >= 0,42 (D=%.1f, soleil %s) : %.3f" % [id, D, sun_on, eff])
				_check(fe <= 0.9, "%s : fill raisonnable (<= 0,9) (D=%.1f, soleil %s) : %.2f" % [id, D, sun_on, fe])
				_check(AmbianceProfile.luminance(fc) < 0.6 and fc.b >= fc.r, "%s : fill froid et désaturé (D=%.1f)" % [id, D])
				var g_all := AmbianceProfile.guard_ambient(amb, sc, se, sun_on, AmbianceProfile.MIN_EFFECTIVE_LUMINANCE)
				_check(AmbianceProfile.ground_luminance(g_all, sc, se, sun_on) >= AmbianceProfile.MIN_EFFECTIVE_LUMINANCE - 0.002, "%s : repli sans fill >= 0,42 (D=%.1f)" % [id, D])
		# Interpolation au milieu de deux pivots
		var mid := p.evaluate(1.5)
		var a := float(p.params_for_tier(&"Calme")[&"rain_intensity"])
		var b := float(p.params_for_tier(&"Tendu")[&"rain_intensity"])
		_check(is_equal_approx(float(mid[&"rain_intensity"]), (a + b) * 0.5), "%s : interpolation linéaire entre pivots" % id)


func _test_quality_rule() -> void:
	_check(Quality.decide_tier(Quality.Tier.HIGH, 40.0, 14.0) == Quality.Tier.MEDIUM, "Haut à 40 i/s -> Moyen")
	_check(Quality.decide_tier(Quality.Tier.MEDIUM, 60.0, 3.0) == Quality.Tier.HIGH, "Moyen avec marge GPU -> Haut")
	_check(Quality.decide_tier(Quality.Tier.MEDIUM, 59.0, 12.0) == Quality.Tier.MEDIUM, "Moyen sans marge -> Moyen")
	_check(Quality.decide_tier(Quality.Tier.LOW, 20.0, 30.0) == Quality.Tier.LOW, "Bas reste Bas")
	_check(Quality.decide_tier(Quality.Tier.LOW, 31.0, 20.0) == Quality.Tier.LOW, "Bas à 31 i/s tient sa cible")
	for t in 3:
		var s: Dictionary = Quality.settings_for(t)
		var caps: Dictionary = s[&"light_caps"]
		_check(int(s[&"max_lights"]) == [8, 16, 32][t], "budget total palier %d" % t)


func _test_manager() -> void:
	Quality.set_tier(Quality.Tier.HIGH, true)
	var mgr: AmbianceManager = load("res://scenes/ambiance/ambiance_manager.tscn").instantiate()
	mgr.auto_bind = false
	add_child(mgr)
	var map: Node2D = load("res://scenes/stage/maps/cite_rouille.tscn").instantiate()
	add_child(map)
	move_child(map, 0)
	_check(mgr.bind_map(map), "bind_map cite_rouille")
	_check(mgr.profile != null and mgr.profile.map_id == &"cite_rouille", "profil appliqué")
	var vis := map.get_node(^"Visual") as CanvasItem
	_check(vis.z_index == AmbianceManager.Z_GROUND, "sol de la carte à z -20")

	# Occluders générés depuis les obstacles (eau profonde exclue)
	var all_rects: Array[Rect2] = []
	OccluderBuilder._gather(map, map, all_rects)
	var shadow := OccluderBuilder.shadow_rects(map)
	var n_occ := 0
	for c in mgr.occluders.get_children():
		if c is LightOccluder2D and not c.is_queued_for_deletion():
			n_occ += 1
			var poly := (c as LightOccluder2D).occluder.polygon
			_check(poly.size() == 4, "occluder rectangulaire")
	print("cite_rouille : %d rectangles d'obstacles, %d occluders (eau exclue : %d)" % [all_rects.size(), n_occ, all_rects.size() - shadow.size()])
	_check(n_occ == shadow.size() and n_occ > 0, "un occluder par rectangle d'ombre")
	_check(shadow.size() < all_rects.size(), "le canal (eau profonde) ne projette pas d'ombre")
	_check(mgr.water.deep_rects > 0 and mgr.water.shallow_rects > 0, "eau profonde et ponts générés depuis la grille")
	_check(mgr.map_light_count() >= 10, "lampes à vapeur placées (%d)" % mgr.map_light_count())

	# Paramètres poussés sur les nœuds
	mgr.set_difficulty(1.0)
	mgr._process(0.016)
	var amb := mgr.canvas_modulate.color
	_check(amb.is_equal_approx(AmbianceProfile.guard_ambient(mgr.profile.ambient_color, mgr.profile.sun_color, mgr.profile.sun_energy, true)), "CanvasModulate = ambiante de la carte")
	_check(AmbianceProfile.luminance(amb) < 0.3, "ambiante sombre (v2) : %.3f" % AmbianceProfile.luminance(amb))
	_check(mgr.fill.visible and mgr.fill.energy > 0.3 and mgr.fill.range_item_cull_mask == LightRig.MASK_WORLD and not mgr.fill.shadow_enabled, "fill des entités (bit 1, sans ombre) : %.2f" % mgr.fill.energy)
	_check((vis.light_mask & LightRig.MASK_GROUND) != 0 and (vis.light_mask & LightRig.MASK_WORLD) == 0, "sol au bit 8 (hors fill)")
	var ground_tml := map.get_node_or_null(^"Visual/Ground") as CanvasItem
	_check(ground_tml == null or (ground_tml.light_mask & LightRig.MASK_WORLD) == 0, "tuiles du sol au bit 8")
	_check((mgr.sun.range_item_cull_mask & LightRig.MASK_GROUND) != 0 and (mgr.sun.range_item_cull_mask & LightRig.MASK_WORLD) != 0, "soleil : sol + entités")
	# Perf 21/10 : ombres du décor CUITES (une texture, un draw) à la place des ombres dynamiques du soleil
	var bs := mgr.baked_shadows
	_check(not mgr.sun.shadow_enabled, "plus d'ombre dynamique du soleil (cuite)")
	_check(bs.visible and bs.sprite.visible and bs.sprite.texture != null and bs.rect_count == shadow.size(), "ombres du décor cuites en Haut (%s)" % bs.describe())
	var bimg := bs.sprite.texture.get_image() if bs.sprite.texture != null else null
	var lit := 0
	if bimg != null:
		for y in range(0, bimg.get_height(), 2):
			for x in range(0, bimg.get_width(), 2):
				if bimg.get_pixel(x, y).r > 0.5:
					lit += 1
	_check(lit > 50, "masque d'ombre cuit non vide (%d texels sombres)" % lit)
	_check(bs.bake_ms < 250.0, "cuisson rapide (%.1f ms)" % bs.bake_ms)
	_check(mgr.creature_shadows.visible and mgr.creature_shadows.multimesh != null, "ombres de contact des créatures (1 MultiMesh)")
	_check(mgr.environment.glow_hdr_threshold >= 1.15, "glow réservé aux émissions (seuil %.2f)" % mgr.environment.glow_hdr_threshold)
	_check(is_equal_approx(mgr.sun.rotation_degrees, 320.0) or is_equal_approx(fposmod(mgr.sun.rotation_degrees, 360.0), 320.0), "directionnelle à 320°")
	_check(mgr.environment.glow_enabled and mgr.world_env.environment != null, "glow actif en Haut")
	_check(mgr.environment.background_canvas_max_layer == AmbianceManager.LAYER_GRADE, "glow limité aux couches <= 4")
	_check(AmbianceManager.telegraph_layer(get_tree()) == mgr.ungraded_layer, "couche des télégraphes exposée")
	_check(mgr.ungraded_layer.layer == 5 and mgr.ungraded_layer.follow_viewport_enabled, "couche 5 qui suit la caméra")

	# Orage qui monte : transition lissée vers Cataclysme
	var r0 := float(mgr.current_params()[&"rain_intensity"])
	mgr.set_difficulty(7.0)
	mgr._eval_t = 10.0
	mgr._process(0.1)
	var r1 := float(mgr.current_params()[&"rain_intensity"])
	var rt := float(mgr.target_params()[&"rain_intensity"])
	_check(r1 > r0 and r1 < rt, "transition douce (%.3f -> %.3f -> %.3f)" % [r0, r1, rt])
	for i in 200:
		mgr._process(0.1)
	var r2 := float(mgr.current_params()[&"rain_intensity"])
	_check(absf(r2 - rt) < 0.01, "convergence vers la cible en 20 s (%.3f / %.3f)" % [r2, rt])
	_check(mgr.tier_name == &"Cataclysme", "palier Cataclysme")

	# Éclairs : garde-fous (>= 4 s d'écart, <= 3 par 10 s), flash <= 0,6
	var p := mgr.current_params()
	var ok1 := mgr.lightning.strike_decor(p)
	var ok2 := mgr.lightning.strike_decor(p)
	_check(ok1 and not ok2, "pas deux éclairs à moins de 4 s")
	mgr.lightning._process(0.016)
	_check(mgr.lightning.flash_alpha() > 0.0 and mgr.lightning.flash_alpha() <= 0.6001, "flash <= 0,60 (%.2f)" % mgr.lightning.flash_alpha())
	var strikes := 1
	for i in 600: # 60 s simulées à Cataclysme (6-12 s entre éclairs)
		mgr.lightning._process(0.1)
		_check(mgr.lightning.flashes_last_10s() <= 3, "<= 3 flashs par 10 s")
	_check(mgr.lightning._history.size() >= 4, "éclairs planifiés à Cataclysme (%d)" % mgr.lightning._history.size())
	Quality.set_flashes_level(1)
	_check(is_equal_approx(Quality.flash_mult(), 0.25), "option flashs réduits = ×0,25")
	Quality.set_flashes_level(2)

	# Changement de carte en douceur
	var map2: Node2D = load("res://scenes/stage/maps/terrasses_noyees.tscn").instantiate()
	map.queue_free()
	add_child(map2)
	move_child(map2, 0)
	await get_tree().process_frame
	var before: Color = mgr.current_params()[&"ambient_color"]
	mgr.bind_map(map2, false)
	mgr._process(0.1)
	var after: Color = mgr.current_params()[&"ambient_color"]
	var tgt: Color = mgr.target_params()[&"ambient_color"]
	_check(not after.is_equal_approx(tgt) and not after.is_equal_approx(before), "transition de carte lissée")
	_check(mgr.profile.map_id == &"terrasses_noyees", "profil terrasses appliqué")
	print("terrasses_noyees : %d occluders" % _count_occ(mgr))
	_check(_count_occ(mgr) > 0, "occluders terrasses")

	await _test_budgets(mgr)
	mgr.queue_free()
	map2.queue_free()
	LightRig.clear_all()
	await get_tree().process_frame


func _count_occ(mgr: AmbianceManager) -> int:
	var n := 0
	for c in mgr.occluders.get_children():
		if c is LightOccluder2D and not c.is_queued_for_deletion():
			n += 1
	return n


func _test_budgets(mgr: AmbianceManager) -> void:
	var spawn := {&"player": 1, &"coin": 60, &"gem": 40, &"ruby": 3, &"elite_burn": 8, &"elite_poison": 6, &"chest_petit": 6,
		&"chest_legendaire": 1, &"pillar_active": 2, &"pillar_ready": 1, &"boss": 2, &"nova": 4, &"ember": 6, &"brasier": 1}
	var holder := Node2D.new()
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var view := mgr.view_rect()
	var player_h: LightRig.Handle = null
	for preset in spawn:
		for i in int(spawn[preset]):
			var n := Node2D.new()
			holder.add_child(n)
			n.global_position = view.position + Vector2(rng.randf() * view.size.x, rng.randf() * view.size.y)
			var h := LightRig.attach(n, preset)
			if preset == &"player":
				player_h = h
	for t in [Quality.Tier.LOW, Quality.Tier.MEDIUM, Quality.Tier.HIGH]:
		Quality.set_tier(t, true)
		mgr.rig.reassign()
		var s: Dictionary = Quality.settings_for(t)
		var active := mgr.rig.active_light_count()
		var by_cat := mgr.rig.count_by_category()
		print("palier %s : %d lumières (budget %d), ombres %d, par catégorie %s, pool %d" % [Quality.tier_name(t), active, s[&"max_lights"], mgr.rig.shadowed_light_count(), by_cat, mgr.rig.pool_size()])
		_check(active <= int(s[&"max_lights"]), "budget total respecté (%s)" % Quality.tier_name(t))
		_check(mgr.rig.pool_size() <= int(s[&"max_lights"]), "pool <= budget (%s)" % Quality.tier_name(t))
		var caps: Dictionary = s[&"light_caps"]
		for c in by_cat:
			_check(int(by_cat[c]) <= int(caps.get(c, 0)), "plafond %s respecté (%s)" % [c, Quality.tier_name(t)])
		_check(player_h.light != null and player_h.light.visible, "le joueur est toujours éclairé (%s)" % Quality.tier_name(t))
		_check(mgr.rig.shadowed_light_count() <= int(s[&"shadow_lights"]), "ombres <= %d (%s)" % [s[&"shadow_lights"], Quality.tier_name(t)])
		if int(s[&"shadow_lights"]) > 0:
			_check(player_h.light.shadow_enabled, "le joueur projette des ombres (%s)" % Quality.tier_name(t))
			_check((player_h.light.range_item_cull_mask & LightRig.MASK_GROUND) != 0, "lumière du joueur : éclaire le sol (%s)" % Quality.tier_name(t))
			mgr._push(0.0)
			_check(mgr.fill.visible and mgr.fill.energy > 0.0, "fill des entités actif (%s)" % Quality.tier_name(t))
			_check(mgr.sun.shadow_enabled == bool(s[&"sun_shadows"]), "ombres du soleil selon le palier (%s)" % Quality.tier_name(t))
		_check(int(by_cat.get(&"pickup", 0)) <= int(caps.get(&"pickup", 0)), "pickups sans lumière sauf rubis (%s)" % Quality.tier_name(t))
		_check(mgr.weather.ambient_capacity() <= int(s[&"ambient_particles_max"]), "particules d'ambiance <= plafond (%s)" % Quality.tier_name(t))
	# Libération automatique à la sortie de l'arbre
	var before := LightRig.request_count()
	holder.queue_free()
	await get_tree().process_frame
	mgr.rig.reassign()
	_check(LightRig.request_count() < before, "demandes libérées quand les nœuds quittent l'arbre")
	# Éclat ponctuel qui se libère seul
	var f := LightRig.flash(view.get_center(), &"meteor_impact", 0.2)
	mgr.rig.reassign()
	for i in 20:
		mgr.rig._update_lights(0.016)
	_check(f.released, "flash libéré après sa durée")
	Quality.set_tier(Quality.Tier.HIGH, true)


func _test_emission_maps() -> void:
	# Plus de normal maps (22/10/2026) : textures diffuses gardées telles quelles, seul l'enfant _e s'ajoute.
	var path := "res://assets/sprites/bosses/etage/cerf/auto.png"
	if not ResourceLoader.exists(path):
		print("émission : asset de référence absent, test sauté")
		return
	_check(not ResourceLoader.exists(path.get_basename() + "_n.png"), "aucune normal map livrée (%s_n.png)" % path.get_basename().get_file())
	var tex := load(path) as Texture2D
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, 32, 32)
	var sf := SpriteFrames.new()
	sf.add_frame(&"default", at)
	sf.add_frame(&"default", tex)
	var spr := Sprite2D.new()
	spr.texture = tex
	add_child(spr)
	NormalMaps.apply_to_sprite(spr)
	var has_e := ResourceLoader.exists(NormalMaps.emission_path(path))
	_check(spr.texture == tex, "apply_to_sprite : texture diffuse gardée")
	_check((spr.get_node_or_null(^"Emission") != null) == has_e, "enfant d'émission si _e.png existe")
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = sf
	add_child(anim)
	NormalMaps.apply_to_animated(anim)
	_check(anim.sprite_frames == sf and (anim.get_node_or_null(^"Emission") != null) == has_e, "apply_to_animated : frames gardées, émission")
	if has_e:
		var ea := NormalMaps.emission_texture(at) as AtlasTexture
		# _e pleine taille ou à demi-résolution (art/tools/halve_emission.py) : région × échelle = région du diffus.
		var es := NormalMaps.emission_scale(at)
		_check(ea != null and Rect2(ea.region.position * es, ea.region.size * es).is_equal_approx(at.region)
			and (es.is_equal_approx(Vector2.ONE) or (es.x > 1.9 and es.x < 2.1)),
			"émission d'une AtlasTexture : même région (échelle %s)" % es)
	spr.queue_free()
	anim.queue_free()
