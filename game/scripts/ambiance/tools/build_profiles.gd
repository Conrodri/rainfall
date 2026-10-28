extends SceneTree
## Génère data/ambiance/<carte>.tres à partir des valeurs de docs/Direction_Lumiere_Ambiance.md
## (§2 cartes, §3.2 paramètres communs, §3.3 spécificités). Outil d'amorçage : une fois générés,
## les .tres font foi (édition dans l'inspecteur) ; relancer écrase les retouches.
##   godot --headless --path game --script res://scripts/ambiance/tools/build_profiles.gd
##
## Choix faits là où le document ne chiffre pas (signalés dans le rapport) :
## - opacité des ombres de nuages carte 1 (0,12 → 0,25) ; carte 3 : aucune (nuit d'orage) ;
## - brume du canal (carte 3) et vapeur des bassins (carte 1) : calques plein écran à la densité
##   indiquée, en attendant les masques par carte (`fog_height_mask_<carte>`) ;
## - positions des lanternes / lampes : règles automatiques sur la grille (light_rules) en
##   attendant des Marker2D `ambiance_light` posés dans les cartes.

const OUT := "res://data/ambiance/"
const U := 64.0


## Options (après `--`) : `--b-only` ne génère que les profils des variantes B (dérivés des .tres A déjà sur disque,
## sans écraser les retouches faites aux profils A).
func _initialize() -> void:
	var profiles: Array = []
	if not ("--b-only" in OS.get_cmdline_user_args()):
		profiles = [_terrasses(), _foret(), _cite()]
	profiles.append_array(_variants_b())
	for p in profiles:
		var path: String = OUT + String(p.map_id) + ".tres"
		var err := ResourceSaver.save(p, path)
		print("%s -> %s (%s)" % [p.map_id, path, error_string(err)])
	quit()


# --- Variantes B (docs/Design_Variantes_B.md §2.5, 3.5, 4.5, 5.5) : copie du profil A + deltas d'heure ------------
## Les valeurs du document sont « relatives au profil livré » : appliquées en rapports sur les valeurs du .tres A.
func _variants_b() -> Array:
	var out: Array = []
	var pa := _load_a("terrasses_noyees")
	if pa != null: # 18 h 10 : soleil plus rasant, ombres de murets plus longues, brume de rizière
		pa.map_id = &"terrasses_rizieres_hautes"
		pa.display_name = "Rizières hautes"
		pa.mood = "Fin d'après-midi tardive (18 h 10), soleil rasant qui éclaire les escaliers de biais ; brume de rizière dans les paliers bas."
		pa.sun_rotation_deg -= 5.0
		pa.sun_height *= 0.11 / 0.15
		pa.sun_energy *= 0.45 / 0.50
		pa.sun_shadow_length_u *= 3.7 / 3.2
		pa.sun_color = c("#FFC890")
		pa.rays_count += 1.0
		pa.fog_low_opacity += 0.02
		out.append(pa)
	var pf := _load_a("foret_brume")
	if pf != null: # 4 h 40 : avant l'aube, plus bleu, les lanternes guident ; lanternes sur les bords du chenal « ~ »
		pf.map_id = &"foret_mangrove_lanternes"
		pf.display_name = "Mangrove des lanternes"
		pf.mood = "Avant l'aube (4 h 40), plus bleu que la forêt-brume ; les lanternes sur pilotis guident le long du chenal."
		pf.ambient_color = _dim(pf.ambient_color, 0.95)
		pf.ambient_low = _dim(pf.ambient_low, 0.95)
		pf.sun_energy *= 0.36 / 0.42
		pf.map_lights_energy *= 1.15
		pf.fog_low_opacity += 0.02
		var rules: Array[Dictionary] = []
		for r in pf.light_rules:
			var nr := (r as Dictionary).duplicate()
			if StringName(nr.get("preset", &"")) == &"shrine_lantern":
				nr["char"] = "~"
				nr["spacing_u"] = 12.0 # max inchangé (8) : même coût que la A
			rules.append(nr)
		pf.light_rules = rules
		out.append(pf)
	var pc := _load_a("cite_rouille")
	if pc != null: # 20 h : nuit tombée, la fonderie éclaire ; 4 creusets (24 lumières au plus, comme la A)
		pc.map_id = &"cite_fonderie_canal"
		pc.display_name = "Fonderie du canal"
		pc.mood = "Nuit tombée (20 h) : la fonderie éclaire à la place du ciel, creusets orange dans la cour."
		pc.ambient_color = _dim(pc.ambient_color, 0.96)
		pc.ambient_low = _dim(pc.ambient_low, 0.96)
		pc.sun_energy *= 0.34 / 0.40
		pc.sun_shadow_length_u *= 1.4 / 1.8
		var crules: Array[Dictionary] = []
		for r in pc.light_rules:
			var nr := (r as Dictionary).duplicate()
			if StringName(nr.get("preset", &"")) == &"steam_lamp":
				nr["max"] = 20
			crules.append(nr)
		pc.light_rules = crules
		var pls: Array[Dictionary] = [] # cloche d'alerte au centre de la cour (32;32) ; creusets en cases (16,12) (12,15) (19,16) (15,19)
		pls.append({"pos_u": Vector2(32, 32), "preset": &"alarm_bell"})
		for cell in [Vector2(16, 12), Vector2(12, 15), Vector2(19, 16), Vector2(15, 19)]:
			pls.append({"pos_u": cell * 2.0 + Vector2.ONE, "preset": &"steam_lamp", "energy": 1.3})
		pc.point_lights = pls
		out.append(pc)
	var py := _load_a("cryptes_noyees")
	if py != null: # pas de soleil : le puits de lumière (colonne froide) et sa pluie
		py.map_id = &"cryptes_ossuaire_pluies"
		py.display_name = "Ossuaire des pluies"
		py.mood = "Cryptes sous un puits de lumière : une colonne froide, la seule lumière du jour, et la pluie de la ville qui tombe dedans."
		var pls2: Array[Dictionary] = []
		for l in py.point_lights:
			pls2.append(l)
		pls2.append({"pos_u": Vector2(24, 37), "preset": &"crystal_vein", "energy": 1.6})
		py.point_lights = pls2
		py.rain_intensity = 0.15
		py.drops_amount *= 1.3
		out.append(py)
	return out


func _load_a(id: String) -> AmbianceProfile:
	var src := load(OUT + id + ".tres") as AmbianceProfile
	if src == null:
		push_warning("build_profiles : profil A « %s » introuvable, variante B ignorée." % id)
		return null
	return src.duplicate(true) as AmbianceProfile


static func _dim(col: Color, k: float) -> Color:
	return Color(col.r * k, col.g * k, col.b * k, col.a)


static func c(hex: String, a: float = 1.0) -> Color:
	var col := Color.html(hex)
	col.a = a
	return col


## Vitesse (u/s) dans une direction écran en degrés (0 = droite, 90 = bas).
static func v(speed: float, deg: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(deg)) * speed


# --- Carte 1 -----------------------------------------------------------------
func _terrasses() -> AmbianceProfile:
	var p := AmbianceProfile.new()
	p.map_id = &"terrasses_noyees"
	p.display_name = "Terrasses noyées"
	p.mood = "Fin d'après-midi (17 h 40), soleil sous les nuages après l'averse ; bruine rétro-éclairée. Quand D monte, les nuages reviennent et le soleil se noie (§2.1, §3.3)."
	p.ambient_color = c("#C9C1B0")
	p.ambient_low = c("#C9C1B0")
	p.sun_rotation_deg = 310.0
	p.sun_color = c("#FFD9A8")
	p.sun_energy = 0.55
	p.sun_height = 0.25
	p.sun_shadow_color = c("#2E3B3A", 0.55)
	p.sun_shadow_length_u = 2.0
	p.sun_shadow_filter = 1
	p.lift_color = c("#2F3D3B"); p.lift_amount = 0.18
	p.gain_color = c("#FFE3B5"); p.gain_amount = 0.22
	p.saturation = 1.05; p.contrast = 1.08; p.contrast_pivot = 0.45
	p.vignette_strength = 0.22; p.vignette_radius = 0.78; p.vignette_softness = 0.45; p.vignette_color = c("#1E2A2C")
	p.rain_intensity = 0.25; p.rain_angle_deg = 10.0; p.rain_opacity = 0.05; p.rain_speed_u = 9.0; p.rain_length_u = 0.25
	p.rain_tint = c("#FFE8C8"); p.rain_layers = 1.0; p.rain_gusts = 0.0
	p.drops_amount = 120.0; p.splash_rate = 60.0; p.wind_mult = 1.0
	p.fog_low_color = c("#C8D4CC"); p.fog_low_opacity = 0.08; p.fog_low_speed = v(0.25, 45.0)
	p.fog2_color = c("#D6DCD2"); p.fog2_opacity = 0.04; p.fog2_speed = v(0.12, 45.0)
	p.fog_high_color = c("#E2E4DA"); p.fog_high_opacity = 0.03; p.fog_high_speed = v(0.4, 45.0)
	p.puffs_count = 0.0
	p.cloud_texture = &"cloud_shadow_2048"; p.cloud_opacity = 0.12; p.cloud_speed_u = v(0.08, 40.0); p.cloud_cover = 0.3
	p.rays_count = 4.0; p.rays_opacity = 0.13; p.rays_color = c("#FFE3B5"); p.rays_rotation_deg = 310.0
	p.sky_texture = &"sky_sunset_256x64"; p.sky_reflect = 0.35; p.puddle_reflect = 0.6; p.water_reflect = 0.6
	p.ripple_hz = 0.5; p.mirror_alpha = 0.25
	p.particle_defs = [
		{"name": "aiguilles de pin", "texture": &"leaf_pine_32", "behavior": &"fall", "color": c("#FFFFFF"), "size_u": Vector2(0.2, 0.35), "speed_u": 1.5, "drift_u": 0.6, "spin_dps": 90.0, "alpha": 0.8, "additive": false},
		{"name": "moucherons", "texture": &"mote_16", "behavior": &"drift", "color": c("#E8E4D0"), "size_u": Vector2(0.05, 0.08), "speed_u": 0.3, "alpha": 0.4, "additive": false},
	]
	p.p1_amount = 12.0; p.p2_amount = 30.0
	p.light_rules = [
		{"preset": &"sun_glint", "char": "~", "edge": false, "spacing_u": 10.0, "max": 8, "max_tier": &"Tendu"},
		{"preset": &"lantern_stone", "char": "#", "edge": true, "spacing_u": 14.0, "max": 10, "min_tier": &"Hostile"},
	]
	p.tier_overrides = {
		&"Tendu": {&"sun_color": c("#F3D0A6"), &"sun_energy": 0.50, &"ambient_color": c("#C2BDB0"), &"ambient_low": c("#C2BDB0"),
			&"rays_count": 2.5, &"rays_opacity": 0.08, &"sun_shadow_length_u": 1.6, &"rain_intensity": 0.35, &"rain_angle_deg": 12.0,
			&"rain_tint": c("#F0E2CC"), &"rain_opacity": 0.07, &"splash_rate": 84.0, &"cloud_cover": 0.5, &"cloud_speed_u": v(0.12, 40.0),
			&"cloud_opacity": 0.15, &"contrast": 1.10, &"saturation": 1.03, &"vignette_strength": 0.24, &"wind_mult": 1.3},
		&"Hostile": {&"sun_color": c("#D8CDB8"), &"sun_energy": 0.40, &"ambient_color": c("#B4B8B0"), &"ambient_low": c("#B4B8B0"),
			&"rays_count": 0.0, &"rays_opacity": 0.0, &"sun_shadow_length_u": 1.0, &"fog_low_opacity": 0.12, &"rain_intensity": 0.5,
			&"rain_angle_deg": 14.0, &"rain_length_u": 0.35, &"rain_tint": c("#D8DCD4"), &"rain_opacity": 0.09, &"splash_rate": 114.0,
			&"cloud_cover": 0.7, &"cloud_speed_u": v(0.2, 40.0), &"cloud_opacity": 0.19, &"contrast": 1.12, &"saturation": 1.0,
			&"vignette_strength": 0.27, &"wind_mult": 1.8, &"p2_amount": 0.0, &"player_light_scale": 1.05},
		&"Furieux": {&"sun_color": c("#B8C2BC"), &"sun_energy": 0.32, &"ambient_color": c("#A4ACA8"), &"ambient_low": c("#A4ACA8"),
			&"sun_shadow_length_u": 0.6, &"rain_intensity": 0.65, &"rain_angle_deg": 17.0, &"rain_tint": c("#C8D0D0"), &"rain_opacity": 0.11,
			&"splash_rate": 144.0, &"cloud_cover": 0.9, &"cloud_speed_u": v(0.35, 40.0), &"cloud_opacity": 0.22, &"contrast": 1.14,
			&"saturation": 0.97, &"vignette_strength": 0.30, &"wind_mult": 2.5, &"map_lights_energy": 1.29, &"player_light_scale": 1.10,
			&"lightning_interval_min": 12.0, &"lightning_interval_max": 25.0, &"lightning_flash": 0.7},
		&"Cataclysme": {&"sun_color": c("#A8B4B8"), &"sun_energy": 0.28, &"ambient_color": c("#98A2A0"), &"ambient_low": c("#98A2A0"),
			&"sun_shadow_length_u": 0.4, &"fog_low_opacity": 0.14, &"rain_intensity": 0.8, &"rain_angle_deg": 20.0, &"rain_layers": 2.0,
			&"rain_tint": c("#C0C8CC"), &"rain_opacity": 0.12, &"splash_rate": 180.0, &"cloud_cover": 1.0, &"cloud_speed_u": v(0.5, 40.0),
			&"cloud_opacity": 0.25, &"contrast": 1.16, &"saturation": 0.95, &"vignette_strength": 0.32, &"wind_mult": 3.2,
			&"player_light_scale": 1.15, &"lightning_interval_min": 6.0, &"lightning_interval_max": 14.0, &"lightning_flash": 1.0,
			&"lightning_double_chance": 0.3},
	}
	return p


# --- Carte 2 -----------------------------------------------------------------
func _foret() -> AmbianceProfile:
	var p := AmbianceProfile.new()
	p.map_id = &"foret_brume"
	p.display_name = "Forêt-brume"
	p.mood = "Aube brumeuse (5 h 10), heure bleue sous la canopée ; lanternes vert pâle, lucioles. Quand D monte, l'aube ne vient jamais (§2.2, §3.3)."
	p.ambient_color = c("#8FA3A8")
	p.ambient_low = c("#A6B8BC")
	p.sun_rotation_deg = 315.0
	p.sun_color = c("#C2E6E0")
	p.sun_energy = 0.45
	p.sun_height = 0.8
	p.sun_shadow_color = c("#1C2A33", 0.5)
	p.sun_shadow_length_u = 0.0 # aube diffuse : aucune ombre, la canopée en multiply la remplace
	p.lift_color = c("#1C2A33"); p.lift_amount = 0.25
	p.gain_color = c("#D8F2E8"); p.gain_amount = 0.15
	p.saturation = 0.92; p.contrast = 0.96; p.contrast_pivot = 0.45
	p.vignette_strength = 0.30; p.vignette_radius = 0.72; p.vignette_softness = 0.55; p.vignette_color = c("#0E1A1E")
	p.rain_intensity = 0.35; p.rain_angle_deg = 6.0; p.rain_opacity = 0.07; p.rain_speed_u = 7.0; p.rain_length_u = 0.35
	p.rain_tint = c("#C8DCD8"); p.rain_layers = 1.0
	p.drops_amount = 80.0; p.splash_rate = 45.0
	p.fog_low_color = c("#B8C8C0"); p.fog_low_opacity = 0.10; p.fog_low_speed = v(0.18, 160.0) # « vers bas-gauche »
	p.fog2_color = c("#C4D2CC"); p.fog2_opacity = 0.0
	p.fog_high_color = c("#CFDCD4"); p.fog_high_opacity = 0.05; p.fog_high_speed = v(0.3, 160.0)
	p.puffs_count = 10.0; p.puffs_opacity = 0.07; p.puffs_color = c("#C4D2CC")
	p.cloud_texture = &"canopy_shadow_2048"; p.cloud_opacity = 0.25; p.cloud_speed_u = v(0.08, 20.0); p.cloud_breathe = 0.02; p.cloud_cover = 0.3
	p.rays_count = 0.0
	p.sky_texture = &"sky_dawn_256x64"; p.sky_reflect = 0.25; p.puddle_reflect = 0.4; p.water_reflect = 0.8
	p.ripple_hz = 0.3; p.mirror_alpha = 0.25
	p.particle_defs = [
		{"name": "lucioles", "texture": &"firefly_16", "behavior": &"firefly", "color": c("#B8FF8A"), "size_u": Vector2(0.12, 0.2), "speed_u": 0.4, "alpha": 0.9, "additive": true, "lifetime": 2.5},
		{"name": "spores", "texture": &"mote_16", "behavior": &"rise", "color": c("#DDE8D8"), "size_u": Vector2(0.05, 0.05), "speed_u": 0.2, "alpha": 0.25, "additive": false},
		{"name": "feuilles de cèdre", "texture": &"leaf_cedar_32", "behavior": &"fall", "color": c("#FFFFFF"), "size_u": Vector2(0.2, 0.35), "speed_u": 1.2, "drift_u": 0.4, "spin_dps": 70.0, "alpha": 0.8, "additive": false},
	]
	p.p1_amount = 48.0; p.p2_amount = 40.0; p.p3_amount = 8.0
	p.light_rules = [
		{"preset": &"shrine_lantern", "char": "#", "edge": true, "spacing_u": 16.0, "max": 8},
	]
	p.tier_overrides = {
		&"Tendu": {&"sun_color": c("#B8DCDA"), &"ambient_color": c("#8C9EA6"), &"fog_low_opacity": 0.11, &"puffs_count": 12.0,
			&"cloud_speed_u": v(0.12, 20.0), &"rain_intensity": 0.45, &"rain_angle_deg": 7.0, &"drops_amount": 100.0, &"rain_opacity": 0.08,
			&"splash_rate": 63.0, &"map_lights_energy": 1.11, &"contrast": 0.98, &"saturation": 0.90, &"vignette_strength": 0.32, &"wind_mult": 1.3,
			&"cloud_cover": 0.5},
		&"Hostile": {&"sun_color": c("#A8CCD0"), &"sun_energy": 0.42, &"ambient_color": c("#889AA6"), &"fog_low_opacity": 0.13, &"puffs_count": 14.0,
			&"p1_amount": 24.0, &"cloud_opacity": 0.30, &"cloud_speed_u": v(0.2, 20.0), &"rain_intensity": 0.6, &"rain_angle_deg": 9.0,
			&"drops_amount": 130.0, &"rain_opacity": 0.09, &"splash_rate": 85.0, &"map_lights_energy": 1.33, &"contrast": 1.0, &"saturation": 0.87,
			&"vignette_strength": 0.35, &"wind_mult": 1.8, &"cloud_cover": 0.7, &"player_light_scale": 1.05},
		&"Furieux": {&"sun_color": c("#98B8C4"), &"sun_energy": 0.40, &"ambient_color": c("#8494A4"), &"fog_low_opacity": 0.15, &"puffs_count": 18.0,
			&"p1_amount": 0.0, &"map_lights_energy": 1.56, &"map_lights_radius": 1.14, &"cloud_opacity": 0.32, &"cloud_speed_u": v(0.35, 20.0),
			&"cloud_breathe": 0.04, &"rain_intensity": 0.75, &"rain_angle_deg": 12.0, &"drops_amount": 160.0, &"rain_opacity": 0.11,
			&"splash_rate": 108.0, &"contrast": 1.02, &"saturation": 0.84, &"vignette_strength": 0.38, &"wind_mult": 2.5, &"cloud_cover": 0.9,
			&"player_light_scale": 1.10, &"lightning_interval_min": 12.0, &"lightning_interval_max": 25.0, &"lightning_flash": 0.5,
			&"lightning_sun_energy": 1.2, &"lightning_bolt_chance": 0.0},
		&"Cataclysme": {&"sun_color": c("#8CA8BC"), &"ambient_color": c("#8494A4"), &"puffs_count": 22.0, &"map_lights_radius": 1.29,
			&"cloud_opacity": 0.35, &"cloud_speed_u": v(0.5, 20.0), &"rain_intensity": 0.9, &"rain_angle_deg": 15.0, &"drops_amount": 200.0,
			&"rain_opacity": 0.12, &"splash_rate": 135.0, &"contrast": 1.04, &"saturation": 0.82, &"vignette_strength": 0.40, &"wind_mult": 3.2,
			&"cloud_cover": 1.0, &"player_light_scale": 1.15, &"lightning_interval_min": 8.0, &"lightning_interval_max": 16.0,
			&"lightning_flash": 0.8, &"lightning_double_chance": 0.3},
	}
	return p


# --- Carte 3 -----------------------------------------------------------------
func _cite() -> AmbianceProfile:
	var p := AmbianceProfile.new()
	p.map_id = &"cite_rouille"
	p.display_name = "Cité de rouille"
	p.mood = "Crépuscule d'orage (19 h 30), nuit qui tombe sur le canal ; lampes à vapeur orange, rideaux de pluie, éclairs. La plus sombre : garde-fous stricts (§2.3, §3.3)."
	p.ambient_color = c("#9A9CA8")
	p.ambient_low = c("#ACAEBC")
	p.sun_rotation_deg = 320.0
	p.sun_color = c("#B9BCD6")
	p.sun_energy = 0.40
	p.sun_height = 0.6
	p.sun_shadow_color = c("#15181F", 0.5)
	p.sun_shadow_length_u = 0.6
	p.sun_shadow_filter = 2
	p.lift_color = c("#141826"); p.lift_amount = 0.30
	p.gain_color = c("#FFD2A0"); p.gain_amount = 0.12
	p.saturation = 0.88; p.contrast = 1.12; p.contrast_pivot = 0.40
	p.vignette_strength = 0.34; p.vignette_radius = 0.70; p.vignette_softness = 0.5; p.vignette_color = c("#0A0C14")
	p.rain_intensity = 0.45; p.rain_angle_deg = 18.0; p.rain_opacity = 0.08; p.rain_speed_u = 12.0; p.rain_length_u = 0.5
	p.rain_tint = c("#C0C8E0"); p.rain_layers = 1.0; p.rain_gusts = 0.4
	p.drops_amount = 0.0; p.splash_rate = 90.0
	p.fog_low_color = c("#9FA8B8"); p.fog_low_opacity = 0.06; p.fog_low_speed = v(0.3, 90.0) # brume du canal, vers le sud
	p.fog2_opacity = 0.0
	p.fog_high_color = c("#A8B0C0"); p.fog_high_opacity = 0.04; p.fog_high_speed = v(1.2, 215.0)
	p.puffs_count = 6.0; p.puffs_opacity = 0.09; p.puffs_color = c("#B8B2A8") # vapeur des cuves
	p.cloud_opacity = 0.0; p.cloud_cover = 0.3
	p.rays_count = 0.0
	p.sky_texture = &"sky_storm_256x64"; p.sky_reflect = 0.30; p.puddle_reflect = 0.4; p.water_reflect = 1.0
	p.ripple_hz = 0.8; p.mirror_alpha = 0.30
	p.particle_defs = [
		{"name": "cendres et rouille", "texture": &"ash_16", "behavior": &"wind", "color": c("#8A6A48"), "size_u": Vector2(0.08, 0.14), "speed_u": 1.2, "alpha": 0.5, "additive": false},
	]
	p.p1_amount = 25.0
	p.lightning_sun_energy = 1.6
	p.light_rules = [
		{"preset": &"steam_lamp", "char": "~", "edge": true, "spacing_u": 8.0, "max": 24},
	]
	p.point_lights = [{"pos_u": Vector2(24, 77), "preset": &"alarm_bell"}]
	p.tier_overrides = {
		&"Tendu": {&"sun_color": c("#B0B4D0"), &"ambient_color": c("#9698A6"), &"rain_intensity": 0.6, &"rain_angle_deg": 19.0,
			&"rain_opacity": 0.09, &"rain_layers": 2.0, &"splash_rate": 120.0, &"p1_amount": 30.0, &"contrast": 1.14, &"saturation": 0.86,
			&"wind_mult": 1.3, &"horizon_interval_min": 30.0, &"horizon_interval_max": 60.0, &"cloud_cover": 0.5},
		&"Hostile": {&"sun_color": c("#A6AACC"), &"sun_energy": 0.42, &"ambient_color": c("#9294A4"), &"rain_intensity": 0.75,
			&"rain_angle_deg": 21.0, &"rain_opacity": 0.10, &"splash_rate": 160.0, &"lightning_interval_min": 25.0, &"lightning_interval_max": 40.0,
			&"lightning_flash": 0.4, &"lightning_rays": 1.5, &"puffs_opacity": 0.11, &"p1_amount": 40.0, &"fog_low_opacity": 0.08,
			&"map_lights_energy": 1.2, &"contrast": 1.16, &"saturation": 0.83, &"wind_mult": 1.8, &"cloud_cover": 0.7, &"player_light_scale": 1.05},
		&"Furieux": {&"sun_color": c("#9CA2C8"), &"sun_energy": 0.45, &"ambient_color": c("#8E90A0"), &"rain_intensity": 0.9,
			&"rain_angle_deg": 23.0, &"rain_opacity": 0.11, &"splash_rate": 200.0, &"lightning_interval_min": 10.0, &"lightning_interval_max": 20.0,
			&"lightning_flash": 1.0, &"puffs_opacity": 0.13, &"p1_amount": 60.0, &"fog_low_opacity": 0.10, &"map_lights_energy": 1.4,
			&"contrast": 1.18, &"saturation": 0.80, &"wind_mult": 2.5, &"cloud_cover": 0.9, &"player_light_scale": 1.10},
		&"Cataclysme": {&"sun_color": c("#949CC8"), &"ambient_color": c("#8C8E9C"), &"rain_intensity": 1.0, &"rain_angle_deg": 25.0,
			&"rain_opacity": 0.12, &"rain_gusts": 0.5, &"splash_rate": 220.0, &"lightning_interval_min": 6.0, &"lightning_interval_max": 12.0,
			&"lightning_double_chance": 0.3, &"lamp_outage_scale": 0.35, &"puffs_opacity": 0.14, &"puffs_count": 8.0, &"p1_amount": 80.0,
			&"fog_low_opacity": 0.12, &"contrast": 1.20, &"saturation": 0.78, &"wind_mult": 3.2, &"cloud_cover": 1.0,
			&"puddle_reflect": 0.6, &"player_light_scale": 1.15},
	}
	return p
