@tool
class_name AmbianceProfile
extends Resource
## Ambiance lumineuse d'une carte (data/ambiance/<map_id>.tres). Valeurs : Direction §2-§3.
##
## Les champs exportés sont l'état du palier Calme (pivot D = 1,0). `tier_overrides` donne les
## changements par palier, CUMULATIFS dans l'ordre (Furieux hérite de Hostile). `evaluate(D)`
## interpole linéairement entre les pivots D = 1 / 2 / 3,25 / 5 / 7 (milieux des paliers) et
## gèle au-delà de 7 (§3.1). AmbianceManager lisse ensuite (demi-vie 2 s).
##
## Conventions : couleurs sRGB ; distances en u (1 u = 64 px) sauf mention ; `sun_rotation_deg`
## = DirectionalLight2D.rotation_degrees (310° = lumière venant du haut-gauche) ; angles de pluie
## en degrés depuis la verticale ; vitesses en u/s.

const TIER_ORDER: Array[StringName] = [&"Calme", &"Tendu", &"Hostile", &"Furieux", &"Cataclysme"]
const PIVOTS_D: Array[float] = [1.0, 2.0, 3.25, 5.0, 7.0]
## Garde-fou §1.1 (éclairage profond v2) : luminance linéaire effective reçue par les ENTITÉS
## (ambiante + ciel pondéré + fill des entités) >= 0,42 : monstres, joueur, pickups, coffres,
## piliers restent lisibles. Le fill (DirectionalLight2D sans ombre, bit 1 seulement) est remonté
## en premier : le sol garde son ambiante sombre.
const MIN_EFFECTIVE_LUMINANCE := 0.42
## Plancher du SOL (ambiante + ciel pondéré) : L* >= 22 pour un sol d'albédo 0,2 (§0 règle 4).
const MIN_GROUND_LUMINANCE := 0.20
## Plancher du sol SANS directionnelle (Bas) : ni ombres portées ni contraste d'étalonnage n'y
## assombrissent le sol au-delà de l'ambiante (en Haut, un sol ombré descend à 0,3 x 0,20 = 0,06
## puis l'étalonnage le creuse encore) : 0,16 reste 2,5 x plus clair qu'un sol ombré de Haut.
const MIN_GROUND_LUMINANCE_LOW := 0.16
## Part de la directionnelle comptée dans la luminance effective (surfaces à normal map : rasante).
const SUN_LUMINANCE_WEIGHT := 0.33

## Paramètres interpolés (tout le reste est structurel).
const PARAM_KEYS: Array[StringName] = [
	&"ambient_color", &"ambient_low", &"fill_color", &"fill_energy", &"fill_energy_low",
	&"sun_color", &"sun_energy", &"sun_rotation_deg", &"sun_height", &"sun_shadow_color", &"sun_shadow_length_u",
	&"sun_shadow_smooth",
	&"lift_color", &"lift_amount", &"gain_color", &"gain_amount", &"saturation", &"contrast", &"contrast_pivot",
	&"vignette_strength", &"vignette_radius", &"vignette_softness", &"vignette_color",
	&"rain_intensity", &"rain_angle_deg", &"rain_opacity", &"rain_speed_u", &"rain_length_u", &"rain_tint",
	&"rain_layers", &"rain_gusts", &"drops_amount", &"splash_rate", &"wind_mult",
	&"fog_low_color", &"fog_low_opacity", &"fog_low_speed", &"fog2_color", &"fog2_opacity", &"fog2_speed",
	&"fog_high_color", &"fog_high_opacity", &"fog_high_speed", &"puffs_count", &"puffs_opacity", &"puffs_color",
	&"cloud_opacity", &"cloud_speed_u", &"cloud_breathe", &"cloud_cover",
	&"rays_count", &"rays_opacity", &"rays_color", &"rays_rotation_deg",
	&"sky_reflect", &"puddle_reflect", &"water_reflect", &"ripple_hz", &"mirror_alpha",
	&"p1_amount", &"p2_amount", &"p3_amount",
	&"lightning_interval_min", &"lightning_interval_max", &"lightning_flash", &"lightning_double_chance",
	&"lightning_sun", &"lightning_bolt_chance", &"lightning_rays", &"horizon_interval_min", &"horizon_interval_max",
	&"lightning_sun_energy", &"map_lights_energy", &"map_lights_radius", &"player_light_scale", &"lamp_outage_scale",
	&"lights_energy",
]

@export var map_id: StringName = &""
@export var display_name: String = ""
@export_multiline var mood: String = "" ## récit lumineux (heure, ressenti), pour les humains

@export_group("Ambiance et directionnelle")
@export var ambient_color: Color = Color(0.6, 0.6, 0.6) ## CanvasModulate
@export var ambient_low: Color = Color(0.65, 0.65, 0.65) ## CanvasModulate en Bas (sans directionnelle)
## Fill des entités (v2) : lumière plate, sans ombre, qui n'atteint que le bit 1 (entités, pas le
## sol) ; garde les monstres lisibles pendant que le sol s'enfonce dans l'ombre. Couleur froide et
## désaturée (le joueur reste la seule source chaude).
@export var fill_color: Color = Color(0.72, 0.78, 0.84)
@export var fill_energy: float = 0.35
@export var fill_energy_low: float = 0.5 ## en Bas (sans directionnelle)
@export var sun_color: Color = Color.WHITE
@export var sun_energy: float = 0.4
@export var sun_rotation_deg: float = 315.0
@export var sun_height: float = 0.6
@export var sun_shadow_color: Color = Color(0.1, 0.1, 0.12, 0.5)
@export var sun_shadow_length_u: float = 1.0 ## 0 = pas d'ombre directionnelle sur cette carte
@export var sun_shadow_smooth: float = 1.0 ## DirectionalLight2D.shadow_filter_smooth (0,5 net ; 3 diffus)
@export_enum("None", "PCF5", "PCF13") var sun_shadow_filter: int = 1

@export_group("Étalonnage")
@export var lift_color: Color = Color(0.2, 0.2, 0.2) ## teinte des ombres
@export var lift_amount: float = 0.0
@export var gain_color: Color = Color(1, 1, 1) ## teinte des hautes lumières
@export var gain_amount: float = 0.0
@export var saturation: float = 1.0
@export var contrast: float = 1.0
@export var contrast_pivot: float = 0.45
@export var vignette_strength: float = 0.25
@export var vignette_radius: float = 0.75
@export var vignette_softness: float = 0.5
@export var vignette_color: Color = Color(0.1, 0.1, 0.12)

@export_group("Pluie")
@export var rain_intensity: float = 0.3 ## 0..1 (partagé avec l'audio)
@export var rain_angle_deg: float = 10.0
@export var rain_opacity: float = 0.05 ## <= 0,12 (§0 règle 5)
@export var rain_speed_u: float = 9.0
@export var rain_length_u: float = 0.25
@export var rain_tint: Color = Color(0.85, 0.9, 1.0)
@export var rain_layers: float = 1.0 ## 1 ou 2 couches (le palier de qualité plafonne)
@export var rain_gusts: float = 0.0 ## amplitude des rafales (0,4 = ±40 %)
@export var drops_amount: float = 0.0 ## gouttes individuelles (particules, Haut)
@export var splash_rate: float = 60.0 ## éclaboussures / s (plafonnées par le palier)
@export var wind_mult: float = 1.0 ## multiplie les dérives (brume, particules)

@export_group("Brumes")
@export var fog_low_color: Color = Color(0.8, 0.83, 0.8)
@export var fog_low_opacity: float = 0.08
@export var fog_low_speed: Vector2 = Vector2(0.18, 0.18)
@export var fog2_color: Color = Color(0.84, 0.86, 0.82)
@export var fog2_opacity: float = 0.04
@export var fog2_speed: Vector2 = Vector2(0.1, 0.03)
@export var fog_high_color: Color = Color(0.88, 0.89, 0.85)
@export var fog_high_opacity: float = 0.03
@export var fog_high_speed: Vector2 = Vector2(0.3, 0.1)
@export var puffs_count: float = 0.0 ## nappes de brume (sprites fog_puff_512)
@export var puffs_opacity: float = 0.07
@export var puffs_color: Color = Color(0.77, 0.82, 0.8)

@export_group("Nuages / canopée")
@export var cloud_texture: StringName = &"cloud_shadow_2048"
@export var cloud_opacity: float = 0.0 ## multiply (0,25 = 25 %)
@export var cloud_speed_u: Vector2 = Vector2(0.08, 0.03)
@export var cloud_breathe: float = 0.0 ## respiration d'échelle (0,02 = ±2 %, période 9 s)
@export var cloud_cover: float = 0.3 ## pilote les rayons (coupés au-dessus de 0,6)

@export_group("Rayons de lumière")
@export var rays_count: float = 0.0
@export var rays_opacity: float = 0.0
@export var rays_color: Color = Color(1.0, 0.89, 0.71)
@export var rays_rotation_deg: float = 310.0

@export_group("Eau et flaques")
@export var sky_texture: StringName = &""
@export var sky_reflect: float = 0.3 ## gradient de ciel reflété
@export var puddle_reflect: float = 0.4 ## flaques « , »
@export var water_reflect: float = 0.3 ## eau profonde « ~ »
@export var ripple_hz: float = 0.5
@export var mirror_alpha: float = 0.25 ## miroir des entités (Haut)

@export_group("Particules d'ambiance")
## Jusqu'à 3 systèmes : {"name", "texture": id, "behavior": fall|drift|firefly|rise|wind,
## "color": Color, "size_u": Vector2(min, max), "speed_u": float, "alpha": float,
## "additive": bool, "hframes": int}. Quantité (palier Haut) : p1_amount, p2_amount, p3_amount.
@export var particle_defs: Array[Dictionary] = []
@export var p1_amount: float = 0.0
@export var p2_amount: float = 0.0
@export var p3_amount: float = 0.0

@export_group("Orage")
@export var lightning_interval_min: float = 0.0 ## s ; 0 = pas d'éclair
@export var lightning_interval_max: float = 0.0
@export var lightning_flash: float = 0.0 ## intensité (× 0,60 d'alpha de base, §3.4)
@export var lightning_double_chance: float = 0.0
@export var lightning_sun: float = 1.0 ## > 0,5 : la directionnelle réagit au flash
@export var lightning_sun_energy: float = 1.6 ## énergie de la directionnelle pendant le flash
@export var lightning_bolt_chance: float = 0.5
@export var lightning_rays: float = 0.0 ## rayons à l'éclair (carte 3)
@export var horizon_interval_min: float = 0.0 ## lueurs d'horizon (carte 3, Tendu)
@export var horizon_interval_max: float = 0.0

@export_group("Sources de la carte")
## [{"pos_u": Vector2 (origine haut-gauche de la carte, en u), "preset": StringName,
##   "energy": float opt., "min_tier": StringName opt., "max_tier": StringName opt.}]
@export var point_lights: Array[Dictionary] = []
## Placement automatique en attendant des Marker2D (groupe `ambiance_light`) :
## [{"preset", "char": "~" | "," | "E" | "#", "edge": bool (cases sol voisines), "spacing_u",
##   "max", "min_tier", "max_tier"}]
@export var light_rules: Array[Dictionary] = []
@export var map_lights_energy: float = 1.0
@export var map_lights_radius: float = 1.0
@export var player_light_scale: float = 1.0
## v2 : multiplie l'énergie de TOUTES les lumières de gameplay (joueur, piliers, coffres, sorts, boss,
## élites) sur cette carte. Une flaque de lumière = lumière × albédo du sol : un sol sombre (cité :
## albédo ~0,08) demande plus d'énergie qu'un sol clair (terrasses ~0,14) pour la même flaque.
@export var lights_energy: float = 1.0
@export var lamp_outage_scale: float = 1.0 ## multiplie l'intervalle entre extinctions des lampes

@export_group("Paliers de difficulté")
## {&"Tendu": {&"sun_energy": 0.5, …}, &"Hostile": {…}, …} (cumulatif).
@export var tier_overrides: Dictionary = {}

var _pivot_cache: Array = []


func base_params() -> Dictionary:
	var d := {}
	for k in PARAM_KEYS:
		d[k] = get(k)
	return d


## État au pivot d'un palier (surcharges cumulatives).
func params_for_tier(tier_name: StringName) -> Dictionary:
	var d := base_params()
	var idx := maxi(TIER_ORDER.find(tier_name), 0)
	for i in idx + 1:
		var o: Dictionary = tier_overrides.get(TIER_ORDER[i], tier_overrides.get(String(TIER_ORDER[i]), {}))
		for k in o:
			var key := StringName(k)
			if d.has(key):
				d[key] = o[k]
			else:
				push_warning("AmbianceProfile %s : clé de surcharge inconnue « %s » (%s)" % [map_id, k, TIER_ORDER[i]])
	return d


## Paramètres continus en D (§3.1) : interpolation linéaire entre pivots, gelés au-delà de 7.
func evaluate(D: float) -> Dictionary:
	if _pivot_cache.is_empty():
		for t in TIER_ORDER:
			_pivot_cache.append(params_for_tier(t))
	if D <= PIVOTS_D[0]:
		return (_pivot_cache[0] as Dictionary).duplicate()
	for i in range(PIVOTS_D.size() - 1):
		if D <= PIVOTS_D[i + 1]:
			var u := (D - PIVOTS_D[i]) / (PIVOTS_D[i + 1] - PIVOTS_D[i])
			return lerp_params(_pivot_cache[i], _pivot_cache[i + 1], u)
	return (_pivot_cache[-1] as Dictionary).duplicate()


## À appeler après avoir modifié le profil en code (les pivots sont mis en cache).
func invalidate() -> void:
	_pivot_cache.clear()


## Sources ponctuelles actives à ce palier.
func lights_for_tier(tier_name: StringName, defs: Array = point_lights) -> Array:
	var idx := maxi(TIER_ORDER.find(tier_name), 0)
	var out: Array = []
	for l in defs:
		if tier_in_range(idx, l):
			out.append(l)
	return out


static func tier_in_range(idx: int, def: Dictionary) -> bool:
	var mn := TIER_ORDER.find(StringName(def.get("min_tier", &"Calme")))
	var mx := TIER_ORDER.find(StringName(def.get("max_tier", &"Cataclysme")))
	return idx >= maxi(mn, 0) and (mx < 0 or idx <= mx)


static func tier_index(tier_name: StringName) -> int:
	return maxi(TIER_ORDER.find(tier_name), 0)


## Intervalles d'évènements (0 = coupé) : jamais interpolés, sinon le passage 0 -> 30 s donnait des
## intervalles quasi nuls et la lueur d'horizon se relançait à chaque image (bande claire en haut de
## l'écran). Ils basculent d'un palier à l'autre à `step_at` (mi-chemin entre pivots ; 0 = tout de suite).
const STEP_KEYS: Array[StringName] = [
	&"lightning_interval_min", &"lightning_interval_max", &"horizon_interval_min", &"horizon_interval_max",
]


static func lerp_params(a: Dictionary, b: Dictionary, t: float, step_at := 0.5) -> Dictionary:
	var d := {}
	for k in a:
		var bv: Variant = b.get(k, a[k])
		d[k] = (bv if t >= step_at else a[k]) if k in STEP_KEYS else lerp_param(a[k], bv, t)
	return d


## Interpolation générique (float, Color, Vector2) ; les autres types basculent à mi-chemin.
static func lerp_param(a: Variant, b: Variant, t: float) -> Variant:
	if typeof(a) == TYPE_INT and typeof(b) == TYPE_FLOAT or typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_INT:
		return lerpf(float(a), float(b), t)
	if typeof(a) != typeof(b):
		return b if t >= 0.5 else a
	match typeof(a):
		TYPE_FLOAT, TYPE_INT:
			return lerpf(float(a), float(b), t)
		TYPE_COLOR:
			return (a as Color).lerp(b as Color, t)
		TYPE_VECTOR2:
			return (a as Vector2).lerp(b as Vector2, t)
	return b if t >= 0.5 else a


## Luminance relative en linéaire d'une couleur sRGB (§1.1).
static func luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## Luminance effective reçue par le sol (ambiante + ciel pondéré).
static func ground_luminance(ambient: Color, sun_color: Color, sun_energy: float, sun_on: bool) -> float:
	return luminance(ambient) + (luminance(sun_color) * sun_energy * SUN_LUMINANCE_WEIGHT if sun_on else 0.0)


## Plancher du sol selon le rendu de la directionnelle (0,20 avec, 0,16 sans : Bas).
static func ground_floor(sun_on: bool) -> float:
	return MIN_GROUND_LUMINANCE if sun_on else MIN_GROUND_LUMINANCE_LOW


## Garde-fou du SOL : remonte l'ambiante (en conservant sa teinte) jusqu'à ground_floor(sun_on)
## (ou `floor_lum` si >= 0). `sun_on` = la directionnelle est rendue (Moyen/Haut). Sans fill (Bas sans
## fill), passer floor_lum = MIN_EFFECTIVE_LUMINANCE : l'ambiante porte seule la lisibilité.
static func guard_ambient(ambient: Color, sun_color: Color, sun_energy: float, sun_on: bool, floor_lum: float = -1.0) -> Color:
	var sun_part := luminance(sun_color) * sun_energy * SUN_LUMINANCE_WEIGHT if sun_on else 0.0
	var need := (ground_floor(sun_on) if floor_lum < 0.0 else floor_lum) - sun_part
	var have := luminance(ambient)
	if have >= need - 0.0005 or have <= 0.0:
		return ambient
	var lin := ambient.srgb_to_linear()
	var k := need / have
	lin = Color(minf(lin.r * k, 1.0), minf(lin.g * k, 1.0), minf(lin.b * k, 1.0), ambient.a)
	return lin.linear_to_srgb()


## Garde-fou des ENTITÉS : énergie du fill nécessaire pour que ambiante + ciel + fill atteigne
## MIN_EFFECTIVE_LUMINANCE (jamais moins que `fill_energy` demandé).
static func guard_fill(ambient: Color, sun_color: Color, sun_energy: float, sun_on: bool, fill_color: Color, fill_energy: float) -> float:
	var fl := luminance(fill_color)
	if fl <= 0.0:
		return fill_energy
	var need := MIN_EFFECTIVE_LUMINANCE - ground_luminance(ambient, sun_color, sun_energy, sun_on)
	return maxf(fill_energy, need / fl)


## Luminance effective reçue par les entités (après les deux garde-fous), pour les tests.
static func entity_luminance(ambient: Color, sun_color: Color, sun_energy: float, sun_on: bool, fill_color: Color, fill_energy: float) -> float:
	return ground_luminance(ambient, sun_color, sun_energy, sun_on) + luminance(fill_color) * fill_energy
