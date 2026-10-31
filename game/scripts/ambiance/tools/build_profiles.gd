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
## sans écraser les retouches faites aux profils A) ; `--gouffre` ne génère que l'étage 2 (A et B), sans toucher aux autres .tres.
func _initialize() -> void:
	var profiles: Array = []
	var args := OS.get_cmdline_user_args()
	if "--gouffre" in args:
		# Étage 2 seulement (A puis B dérivée de A en mémoire) : ne touche à aucun .tres des autres biomes.
		var pa := _foret()
		profiles = [pa, _foret_b(pa.duplicate(true) as AmbianceProfile)]
	else:
		if not ("--b-only" in args):
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
	if pf != null:
		out.append(_foret_b(pf))
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


## Variante B « Les Galeries noyées » (docs/Design_Etage2_Grotte.md §5.2) : dérivée de A, sans puits de jour, plus profonde ;
## mycélium le long de la rivière « ~ ». `pf` = copie du profil A.
func _foret_b(pf: AmbianceProfile) -> AmbianceProfile:
	pf.map_id = &"foret_mangrove_lanternes"
	pf.display_name = "Les Galeries noyées"
	pf.mood = "Galeries profondes sans puits de jour : la rivière souterraine coule entre des rives de mycélium améthyste, un jour résiduel filtre de très loin."
	pf.ambient_color = _dim(pf.ambient_color, 0.92)
	pf.ambient_low = _dim(pf.ambient_low, 0.92)
	pf.sun_color = c("#E8D8C8")
	pf.sun_energy = 0.22
	pf.map_lights_energy = 1.2
	pf.fog_low_opacity = 0.10
	pf.p1_amount *= 1.5 # 3 nuées de spores
	pf.p2_amount = 0.0 # pas de poussière (pas de rai)
	pf.water_reflect = 0.8
	pf.ripple_hz = 0.35
	pf.cloud_opacity = 0.28
	pf.point_lights = [] # aucun puits de lumière
	var rules: Array[Dictionary] = []
	for r in pf.light_rules:
		var nr := (r as Dictionary).duplicate()
		if StringName(nr.get("preset", &"")) == &"mycelium_glow":
			nr["char"] = "~"
			nr["spacing_u"] = 12.0 # max inchangé (8) : même coût que la A
		rules.append(nr)
	pf.light_rules = rules
	pf.tier_overrides = _gouffre_tiers(pf)
	return pf


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


# --- Carte 2 : « Le Gouffre luisant » (docs/Design_Etage2_Grotte.md §5.1) --------
## Les valeurs de teinte du document sont exprimées dans la convention du générateur ; les .tres livrés des
## autres biomes en sont à 0,64-0,66 de ces valeurs (éclairage profond v2, ambiante sombre + fill) :
## même facteur ici pour que la grotte reste « profonde » comme les autres étages.
const GOUFFRE_DEEP := 0.66

func _foret() -> AmbianceProfile:
	var p := AmbianceProfile.new()
	p.map_id = &"foret_brume"
	p.display_name = "Le Gouffre"
	p.mood = "Gouffre karstique sous les rizières, midi dehors : trois puits de jour blanc-chaud tombent dans la grande salle, le reste est éclairé par le mycélium améthyste des fissures."
	p.ambient_color = _dim(c("#A89686"), GOUFFRE_DEEP)
	# Le document propose #B8A898 en palier Bas, mais les tests de profil imposent ambient_low <= ambient_color (le garde-fou du
	# sol relève déjà l'ambiante sans directionnelle) : comme les autres biomes, ambient_low = ambient_color.
	p.ambient_low = p.ambient_color
	# Fill des entités : gris légèrement violet (froid, désaturé, lisible) à la place de l ancien fill cyan, qui verdissait les monstres sur l ocre.
	p.fill_color = c("#B2ADB8"); p.fill_energy = 0.42; p.fill_energy_low = 0.52
	p.sun_rotation_deg = 315.0
	p.sun_color = c("#FFE2B8")
	p.sun_energy = 0.30
	p.sun_height = 0.95
	p.sun_shadow_color = c("#140C08", 0.5)
	p.sun_shadow_length_u = 0.5 # quasi zénithale : petites ombres cuites (le document dit 0 ; 0,5 garde l'ancrage des props)
	p.sun_shadow_smooth = 3.0; p.sun_shadow_filter = 2
	p.lift_color = c("#1E1410"); p.lift_amount = 0.25
	p.gain_color = c("#FFD9B0"); p.gain_amount = 0.12
	p.saturation = 1.02; p.contrast = 1.10; p.contrast_pivot = 0.42
	p.vignette_strength = 0.34; p.vignette_radius = 0.70; p.vignette_softness = 0.55; p.vignette_color = c("#140C08")
	p.rain_intensity = 0.0; p.rain_angle_deg = 6.0; p.rain_opacity = 0.0; p.rain_speed_u = 7.0; p.rain_length_u = 0.35
	p.rain_tint = c("#C8DCD8"); p.rain_layers = 0.0
	p.drops_amount = 60.0; p.splash_rate = 0.0
	p.wind_mult = 0.6
	p.fog_low_color = c("#8C7E78"); p.fog_low_opacity = 0.08; p.fog_low_speed = v(0.1, 160.0)
	p.fog2_color = c("#9A8A84"); p.fog2_opacity = 0.0
	p.fog_high_color = c("#9A8A84"); p.fog_high_opacity = 0.0; p.fog_high_speed = v(0.1, 160.0)
	p.puffs_count = 6.0; p.puffs_opacity = 0.06; p.puffs_color = c("#9A8A84")
	# Voûte fixe : ombres de stalactites en multiply (texture Codex ; absente = calque coupé, pas de repli feuillu).
	p.cloud_texture = &"cave_ceiling_2048"; p.cloud_opacity = 0.22; p.cloud_speed_u = Vector2.ZERO; p.cloud_breathe = 0.0; p.cloud_cover = 0.0
	p.rays_count = 0.0
	p.sky_texture = &""; p.sky_reflect = 0.0; p.puddle_reflect = 0.45; p.water_reflect = 0.7
	p.ripple_hz = 0.2; p.mirror_alpha = 0.25
	p.particle_defs = [
		{"name": "spores", "texture": &"mote_16", "behavior": &"drift", "color": c("#C27BFF"), "size_u": Vector2(0.06, 0.10), "speed_u": 0.15, "alpha": 0.55, "additive": true, "lifetime": 5.0},
		{"name": "poussière", "texture": &"mote_16", "behavior": &"rise", "color": c("#FFE2B8"), "size_u": Vector2(0.05, 0.05), "speed_u": 0.08, "alpha": 0.3, "additive": false},
		{"name": "gouttes de voûte", "texture": &"drop_32", "behavior": &"fall", "color": c("#C8D8D4"), "size_u": Vector2(0.12, 0.22), "speed_u": 2.5, "spin_dps": 0.0, "alpha": 0.6, "additive": false},
	]
	p.p1_amount = 36.0; p.p2_amount = 30.0; p.p3_amount = 40.0
	p.lights_energy = 1.4
	p.map_lights_energy = 1.0
	# Mycélium le long des fissures (remplace les lanternes) ; puits de jour sur les 3 gros piliers possibles.
	p.light_rules = [
		{"preset": &"mycelium_glow", "char": "#", "edge": true, "spacing_u": 14.0, "max": 8},
	]
	p.point_lights = [
		{"pos_u": Vector2(31, 27), "preset": &"light_shaft"},
		{"pos_u": Vector2(57, 23), "preset": &"light_shaft"},
		{"pos_u": Vector2(31, 53), "preset": &"light_shaft"},
	]
	p.tier_overrides = _gouffre_tiers(p)
	return p


## Paliers du Gouffre (§5.1) : Tendu spores ×1,5 ; Hostile lumières 1,2 + gouttes 90 ; Furieux lumières 1,35, ambiante +4 %
## (événement « Puits voilés » côté AmbianceManager) ; Cataclysme gouttes 130, vent 1,2. `pf` = profil déjà réglé (ambiante de base).
static func _gouffre_tiers(pf: AmbianceProfile) -> Dictionary:
	var sp := pf.p1_amount
	var le := pf.lights_energy
	var mle := pf.map_lights_energy
	var amb := pf.ambient_color
	var low := pf.ambient_low
	var up := func(col: Color) -> Color: return Color(minf(col.r * 1.04, 1.0), minf(col.g * 1.04, 1.0), minf(col.b * 1.04, 1.0), col.a)
	return {
		&"Tendu": {&"p1_amount": sp * 1.5},
		&"Hostile": {&"p1_amount": sp * 1.5, &"map_lights_energy": maxf(mle, 1.2), &"drops_amount": 90.0, &"lights_energy": le * 1.04},
		&"Furieux": {&"map_lights_energy": maxf(mle, 1.35), &"ambient_color": up.call(amb), &"ambient_low": up.call(low), &"lights_energy": le * 1.07},
		&"Cataclysme": {&"drops_amount": 130.0, &"wind_mult": 1.2, &"lights_energy": le * 1.1},
	}


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
