class_name AmbianceManager
extends Node2D
## Ambiance lumineuse d'un étage (scène de jeu). Instancier scenes/ambiance/ambiance_manager.tscn
## comme enfant direct de la scène de jeu, à l'origine. Tout le reste est automatique :
## - à `Events.floor_started`, retrouve la StageMap, charge data/ambiance/<map_id>.tres, génère
##   les occluders, l'eau, les sources de la carte, et lance la mesure auto de Quality ;
## - suit `RunState.difficulty_changed` : paramètres continus en D (pivots §3.1), lissés
##   (demi-vie 2 s) ; éclairs planifiés par le profil ;
## - se reconfigure à chaud sur `Quality.quality_changed`.
##
## Éclairage profond v2 (docs/Direction_Lumiere_Ambiance.md « Éclairage profond v2 ») : ambiante
## sombre, sol au bit 8 (MASK_GROUND) éclairé par le soleil et les lumières ponctuelles seulement,
## entités au bit 1 relevées par un « fill » plat sans ombre (lisibilité garantie par
## AmbianceProfile.guard_fill), ombres directionnelles longues et nettes, glow réservé aux émissions.
##
## Chaîne de rendu (Direction §1.3). World (canvas racine, CanvasModulate, lumières) :
##   z -20 sol de la carte (imposé au nœud « Visual » de la StageMap si enforce_ground_z),
##   z -18 eau/flaques, -16 nuages, -14 brume basse, -12 éclaboussures, 0 entités, 10 projectiles,
##   20 brume haute, 25 particules d'ambiance, 30 pluie, 32 rayons.
## CanvasLayers : 4 étalonnage (LAYER_GRADE) ; 5 télégraphes / zones / chiffres de dégâts
##   (LAYER_UNGRADED, suit la caméra, ni éclairé ni étalonné ni glow) ; 6 flash d'éclair ;
##   >= 10 HUD et menus (HUD_MIN_LAYER). Le glow ne touche que les couches <= 4.
##
## API publique : apply_profile(map_id), bind_map(map), set_difficulty(D), strike_lightning(),
## spawn_rays(), set_ultimate_warmth(), outage_random_lamp(), telegraph_layer(tree) (statique),
## current_params(), view_rect(). Signaux : profile_applied, lightning_struck, thunder,
## thunder_rumble, shake_requested.

signal profile_applied(map_id: StringName)
signal lightning_struck(world_pos: Vector2, intensity: float, gameplay: bool)
signal thunder(intensity: float, delay_s: float)
signal thunder_rumble(intensity: float)
signal shake_requested(amplitude_px: float, hz: float, duration_s: float)

const PROFILES_DIR := "res://data/ambiance/"
const U := 64.0
const LAYER_GRADE := 4
const LAYER_UNGRADED := 5
const LAYER_FLASH := 6
const HUD_MIN_LAYER := 10
const Z_GROUND := -20
const UNGRADED_GROUP := &"ambiance_ungraded_world"
const LIGHT_MARKER_GROUP := &"ambiance_light"
const SMOOTH_HALF_LIFE_S := 2.0 ## §3.1
## DirectionalLight2D.max_distance = rayon (px) autour du centre de la caméra dans lequel les occluders
## projettent ; ce n'est PAS une longueur d'ombre (une ombre directionnelle 2D est infinie). Demi-diagonale
## 1080p (1101 px) + marge : tout occluder visible projette.
const SUN_SHADOW_CULL_PX := 1400.0
## Ombres cuites : facteur d'opacité appliqué à sun_shadow_color.a (calé en capture pour garder la
## profondeur de l'ombre dynamique d'avant, qui n'ôtait que la part du soleil), et opacité des
## ombres de contact des créatures.
const BAKED_ALPHA_MULT := 1.0
const CONTACT_SHADOW_ALPHA := 0.6
const EVAL_INTERVAL := 0.25
const LIGHT_FADE_S := 10.0 ## §3.1 : fondus discrets de 10 s (lanternes, lucioles)
const WARM_COLOR := Color(1.0, 0.839, 0.69) # #FFD6B0 (Brasier, §4.2)
const GRADING_SHADER := preload("res://shaders/grading.gdshader")
const VIGNETTE_SHADER := preload("res://shaders/vignette_mul.gdshader")
## Paliers LDR (HDR 2D coupé) : part de la directionnelle à laquelle la conversion linéaire -> sRGB
## est exacte (surfaces à normal map : rasante), et correction des lumières ponctuelles (en LDR le
## dégradé de la texture s'ajoute en sRGB : cœur plus dur, queue plus claire). Calés en capture
## (perf_bench --calib, Haut HDR contre Moyen LDR).
const LDR_SUN_REF := 1.0
const LDR_POINT_ENERGY := 0.5
const LDR_POINT_RADIUS := 1.0

@export var enforce_ground_z := true ## place le nœud « Visual » de la carte à z -20
@export var auto_bind := true ## se branche seul sur Events.floor_started / RunState

var profile: AmbianceProfile = null
var map: Node2D = null
var difficulty := 1.0
var tier_name: StringName = &"Calme"

var world_env: WorldEnvironment
var environment: Environment
var canvas_modulate: CanvasModulate
var sun: DirectionalLight2D
var fill: DirectionalLight2D ## fill des entités (v2), bit 1 seulement
var occluders: Node2D
## Banc de comparaison : rétablit l'ancienne ombre dynamique du soleil et masque la couche cuite.
var debug_dynamic_sun := false
var baked_shadows: BakedShadows ## ombres cuites du décor (remplacent les ombres dynamiques du soleil)
var creature_shadows: CreatureShadows ## ombres de contact de toutes les créatures (1 draw)
var rig: LightRig
var water: AmbianceWater
var fog: AmbianceFog
var weather: AmbianceWeather
var lightning: AmbianceLightning
var grade_layer: CanvasLayer
var grade_rect: ColorRect
var ungraded_layer: CanvasLayer
var flash_layer: CanvasLayer

var _target: Dictionary = {}
var _current: Dictionary = {}
var _eval_t := 0.0
var _map_lights: Array = [] ## [{handle, def}]
var _warmth := 0.0
var _warmth_target := 0.0
var _warmth_color := WARM_COLOR ## teinte de l'ultime en cours (CharacterData.ultimate_grade_color())
var _grade_mat: ShaderMaterial
var _vignette_mat: ShaderMaterial
var _bell: LightRig.Handle = null
var _bell_t := -1.0
var _measured := false
var _lights_tier: StringName = &""
var _smooth_f: Array = [] ## clés lissées (_smooth_current), classées par type
var _smooth_c: Array = []
var _smooth_v: Array = []
var _smooth_step: Array = []
var _smooth_shape := -1
var _ldr_dirty := true ## matériaux d'ambiance à (re)marquer LDR / HDR (_apply_ldr_uniform)
## true quand le HDR 2D est coupé (Moyen, Bas) : lu par les sous-systèmes (ldr_alpha côté CPU).
static var ldr_mode := false
var _smooth_src := -1


# --- Statique ---------------------------------------------------------------

## CanvasLayer des télégraphes, zones et chiffres de dégâts (non éclairé, non étalonné, sans
## glow, suit la caméra). Null si aucun AmbianceManager n'est dans l'arbre.
static func telegraph_layer(tree: SceneTree) -> CanvasLayer:
	var n := tree.get_first_node_in_group(UNGRADED_GROUP)
	return n as CanvasLayer


static func find(tree: SceneTree) -> AmbianceManager:
	return tree.get_first_node_in_group(&"ambiance_manager") as AmbianceManager


static func load_profile(map_id: StringName) -> AmbianceProfile:
	var path := PROFILES_DIR + String(map_id) + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AmbianceProfile


# --- Construction -------------------------------------------------------------

func _ready() -> void:
	add_to_group(&"ambiance_manager")
	_build()
	Quality.quality_changed.connect(_on_quality)
	_on_quality(Quality.tier)
	if auto_bind:
		var ev := get_node_or_null(^"/root/Events")
		if ev != null and ev.has_signal(&"floor_started"):
			ev.connect(&"floor_started", _on_floor_started)
		var rs := get_node_or_null(^"/root/RunState")
		if rs != null and rs.has_signal(&"difficulty_changed"):
			rs.connect(&"difficulty_changed", _on_difficulty_changed)
		_auto_bind.call_deferred()


func _build() -> void:
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	environment = Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = LAYER_GRADE
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	add_child(world_env)
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "CanvasModulate"
	add_child(canvas_modulate)
	sun = DirectionalLight2D.new()
	sun.name = "Sun"
	sun.blend_mode = Light2D.BLEND_MODE_ADD
	sun.range_z_min = LightRig.RANGE_Z_MIN
	sun.range_z_max = LightRig.RANGE_Z_MAX
	sun.range_item_cull_mask = LightRig.MASK_LIT | LightRig.MASK_PUDDLES
	sun.shadow_item_cull_mask = LightRig.MASK_WORLD
	sun.shadow_filter_smooth = 1.0
	add_child(sun)
	# Fill des entités (v2) : lumière plate sans ombre, bit 1 seulement (le sol est au bit 8 :
	# il reste dans l'ambiante sombre, les monstres et interactables restent lisibles).
	fill = DirectionalLight2D.new()
	fill.name = "EntityFill"
	fill.blend_mode = Light2D.BLEND_MODE_ADD
	fill.height = 1.0
	fill.range_z_min = LightRig.RANGE_Z_MIN
	fill.range_z_max = LightRig.RANGE_Z_MAX
	fill.range_item_cull_mask = LightRig.MASK_WORLD
	fill.shadow_enabled = false
	add_child(fill)
	occluders = Node2D.new()
	occluders.name = "Occluders"
	add_child(occluders)
	baked_shadows = BakedShadows.new()
	add_child(baked_shadows)
	creature_shadows = CreatureShadows.new()
	add_child(creature_shadows)
	rig = LightRig.new()
	rig.name = "LightRig"
	add_child(rig)
	water = AmbianceWater.new()
	water.name = "Water"
	add_child(water)
	fog = AmbianceFog.new()
	fog.name = "Fog"
	add_child(fog)
	weather = AmbianceWeather.new()
	weather.name = "Weather"
	add_child(weather)

	grade_layer = CanvasLayer.new()
	grade_layer.name = "GradeLayer"
	grade_layer.layer = LAYER_GRADE
	add_child(grade_layer)
	grade_rect = ColorRect.new()
	grade_rect.name = "Grade"
	grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade_layer.add_child(grade_rect)
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = GRADING_SHADER
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = VIGNETTE_SHADER

	ungraded_layer = CanvasLayer.new()
	ungraded_layer.name = "TelegraphLayer"
	ungraded_layer.layer = LAYER_UNGRADED
	ungraded_layer.follow_viewport_enabled = true
	ungraded_layer.add_to_group(UNGRADED_GROUP)
	add_child(ungraded_layer)

	flash_layer = CanvasLayer.new()
	flash_layer.name = "FlashLayer"
	flash_layer.layer = LAYER_FLASH
	add_child(flash_layer)
	var fr := ColorRect.new()
	fr.name = "Flash"
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fr.material = add
	fr.visible = false
	flash_layer.add_child(fr)
	lightning = AmbianceLightning.new()
	lightning.name = "Lightning"
	lightning.mgr = self
	lightning.flash_rect = fr
	lightning.bolt = _flash_sprite("Bolt", &"lightning_bolt_256x1024")
	lightning.horizon = _flash_sprite("Horizon", &"horizon_glow_1024x256")
	add_child(lightning)
	lightning.struck.connect(func(p, i, g): lightning_struck.emit(p, i, g))
	lightning.thunder.connect(func(i, d): thunder.emit(i, d))
	lightning.thunder_rumble.connect(func(i): thunder_rumble.emit(i))
	lightning.shake_requested.connect(func(a, h, d): shake_requested.emit(a, h, d))


func _flash_sprite(nm: String, tex_id: StringName) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = nm
	s.texture = AmbianceTextures.get_tex(tex_id)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.visible = false
	flash_layer.add_child(s)
	return s


# --- Branchement automatique ---------------------------------------------------

func _on_floor_started(_stage: int) -> void:
	_auto_bind.call_deferred()


func _on_difficulty_changed(D: float, tier: StringName) -> void:
	difficulty = D
	tier_name = tier


func _auto_bind() -> void:
	var rs := get_node_or_null(^"/root/RunState")
	if rs != null and rs.has_method(&"difficulty"):
		difficulty = float(rs.call(&"difficulty"))
	var root := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	var m := _find_stage_map(root)
	if m != null and m != map:
		bind_map(m)


static func _find_stage_map(n: Node) -> Node2D:
	if n == null:
		return null
	if n is StageMap:
		return n as Node2D
	for c in n.get_children():
		var r := _find_stage_map(c)
		if r != null:
			return r
	return null


## Branche une carte : profil (méta `map_id`), occluders, eau, sources ponctuelles.
func bind_map(m: Node2D, instant: bool = true) -> bool:
	map = m
	if m != null:
		var vis := m.get_node_or_null(^"Visual") as CanvasItem
		if vis != null:
			if enforce_ground_z:
				vis.z_index = Z_GROUND
			_mask_ground(vis)
	# méta `ambiance_id` : profil d'une autre carte (arène du mode test, qui emprunte celui des terrasses)
	var id := StringName(m.get_meta(&"ambiance_id", m.get_meta(&"map_id", &""))) if m != null else &""
	var ok := apply_profile(id, instant)
	_rebuild_map_dependent()
	if not _measured:
		_measured = true
		Quality.begin_auto_measure()
	return ok


## Sol et décor de la carte (nœud « Visual » et descendants) : bit 1 -> bit 8 (LightRig.MASK_GROUND).
## Les lumières ponctuelles et le soleil éclairent les deux bits ; le fill des entités, le bit 1 seul.
## Les éléments déjà non éclairés (light_mask 0) ne sont pas touchés.
static func _mask_ground(n: Node) -> void:
	if n is CanvasItem:
		var ci := n as CanvasItem
		if ci.light_mask & LightRig.MASK_WORLD:
			ci.light_mask = (ci.light_mask & ~LightRig.MASK_WORLD) | LightRig.MASK_GROUND
	for c in n.get_children():
		_mask_ground(c)


## Charge et applique le profil d'une carte. `instant` : sans transition (début d'étage) ; sinon
## les paramètres glissent vers la nouvelle carte (demi-vie 2 s). Retourne false si le profil
## n'existe pas (l'ambiance garde l'état neutre).
func apply_profile(map_id: StringName, instant: bool = true) -> bool:
	var p := load_profile(map_id)
	if p == null:
		push_warning("AmbianceManager : pas de profil pour la carte « %s »" % map_id)
		return false
	profile = p
	_target = p.evaluate(difficulty)
	if instant or _current.is_empty():
		_current = _target.duplicate()
		_smooth_shape = -1 # nouveau profil : clés reclassées
	weather.setup(p)
	_ldr_dirty = true
	fog.setup(p, _map_rect())
	water.setup(map, p)
	lightning.reset_schedule()
	_push(0.0)
	AmbianceTextures.warn_missing_once()
	profile_applied.emit(map_id)
	return true


func _rebuild_map_dependent() -> void:
	if map != null and not _current.is_empty() and bool(Quality.get_setting(&"baked_shadows")):
		if baked_shadows.map != map:
			var q := _current.duplicate()
			baked_shadows.bake(map, q)
	elif map == null:
		baked_shadows.bake(null, {})
	if map != null and StringName(Quality.get_setting(&"occluders")) != &"none":
		OccluderBuilder.build(map, occluders)
	else:
		OccluderBuilder.clear(occluders)
	_build_map_lights()


func _map_rect() -> Rect2:
	if map == null:
		return Rect2()
	if map is StageMap: # boîte englobante logique (losange en iso)
		var b := (map as StageMap).get_bounds()
		return Rect2(map.to_global(b.position), b.size)
	var size_u: Vector2 = map.get_meta(&"size_u", Vector2.ZERO)
	var size := size_u * U
	return Rect2(map.to_global(-size * 0.5), size)


## Sources ponctuelles de la carte : Marker2D du groupe `ambiance_light` (méta `light_preset`,
## `min_tier`, `max_tier`), puis `point_lights` et `light_rules` du profil.
func _build_map_lights() -> void:
	for ml in _map_lights:
		(ml["handle"] as LightRig.Handle).release()
	_map_lights.clear()
	_bell = null
	if map == null or profile == null:
		return
	var defs: Array = []
	for n in get_tree().get_nodes_in_group(LIGHT_MARKER_GROUP):
		if n is Node2D and map.is_ancestor_of(n):
			defs.append({"global": (n as Node2D).global_position, "preset": StringName(n.get_meta(&"light_preset", &"lantern_stone")),
				"min_tier": n.get_meta(&"min_tier", &"Calme"), "max_tier": n.get_meta(&"max_tier", &"Cataclysme")})
	var size_u: Vector2 = map.get_meta(&"size_u", Vector2.ZERO)
	for l in profile.point_lights:
		var d: Dictionary = l.duplicate()
		# pos_u en repère carte (grille) -> logique par StageMap.frame_of (Rot +45° en iso)
		d["global"] = map.to_global(StageMap.frame_of(map) * (((l.get("pos_u", Vector2.ZERO) as Vector2) - size_u * 0.5) * U))
		defs.append(d)
	defs.append_array(_rule_lights())
	for d in defs:
		var h := LightRig.attach_at(d["global"], StringName(d["preset"]), {"energy": float(d.get("energy", 1.0)), "fade": LIGHT_FADE_S})
		h.current_energy = 0.0
		_map_lights.append({"handle": h, "def": d})
		if map is StageMap and d.has("cell"): # sprite de la source (réverbère F3P) si livré
			(map as StageMap).add_light_prop(StringName(d["preset"]), d["cell"], d.get("water_dir", Vector2i.ZERO))
		if StringName(d["preset"]) == &"alarm_bell":
			_bell = h
	_update_map_lights_tier()


func _rule_lights() -> Array:
	var out: Array = []
	var g := AmbianceWater.grid_of(map)
	if g.is_empty():
		return out
	var grid: PackedStringArray = g["grid"]
	var cell: float = g["cell_px"]
	var origin: Vector2 = g["origin"]
	for rule in profile.light_rules:
		var ch := String(rule.get("char", "#"))
		var edge := bool(rule.get("edge", false))
		var spacing := float(rule.get("spacing_u", 8.0)) * U
		var mx := int(rule.get("max", 8))
		var picked: Array[Vector2] = []
		var picked_cell: Array[Vector2i] = [] # case de grille + direction de l'eau (réverbères posés par StageMap)
		var picked_dir: Array[Vector2i] = []
		for y in grid.size():
			for x in grid[y].length():
				if picked.size() >= mx:
					break
				var c := grid[y][x]
				var ok := false
				var wdir := Vector2i.ZERO
				if edge:
					if c != "#" and c != "~" and c != StageMap.VOID_CHAR and c != ch: # jamais sur le vide hors carte
						for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							var nx: int = x + dv.x
							var ny: int = y + dv.y
							if ny >= 0 and ny < grid.size() and nx >= 0 and nx < grid[ny].length() and grid[ny][nx] == ch:
								ok = true
								wdir = dv
				else:
					ok = c == ch
				if not ok:
					continue
				var local := origin + Vector2((x + 0.5) * cell, (y + 0.5) * cell)
				var far := true
				for q in picked:
					if q.distance_to(local) < spacing:
						far = false
						break
				if far:
					picked.append(local)
					picked_cell.append(Vector2i(x, y))
					picked_dir.append(wdir)
		for i in picked.size():
			var q := picked[i]
			var d: Dictionary = rule.duplicate()
			d["global"] = map.to_global(StageMap.frame_of(map) * q) # case de grille (repère carte) -> logique
			d["cell"] = picked_cell[i]
			d["water_dir"] = picked_dir[i]
			out.append(d)
	return out


func _update_map_lights_tier() -> void:
	var idx := AmbianceProfile.tier_index(tier_name)
	for ml in _map_lights:
		var h: LightRig.Handle = ml["handle"]
		var on := AmbianceProfile.tier_in_range(idx, ml["def"])
		h.set_energy(float((ml["def"] as Dictionary).get("energy", 1.0)) if on else 0.0)


## Nombre de sources de la carte (tests).
func map_light_count() -> int:
	return _map_lights.size()


## Sources ponctuelles de la carte, en lecture : copie de la liste de {handle: LightRig.Handle,
## def: Dictionary (global, preset, energy, min_tier, max_tier…)}. Les handles sont partagés (on peut
## régler énergie/fondu/panne, pas les libérer) ; la liste est reconstruite à chaque chargement de carte.
func map_lights() -> Array:
	return _map_lights.duplicate()


## Vrai si la source `def` est allumée au palier courant (min_tier..max_tier).
func map_light_on(def: Dictionary) -> bool:
	return AmbianceProfile.tier_in_range(AmbianceProfile.tier_index(tier_name), def)


# --- Qualité ----------------------------------------------------------------

func _on_quality(_t: int) -> void:
	var glow := bool(Quality.get_setting(&"glow"))
	world_env.environment = environment if (glow or bool(Quality.get_setting(&"hdr_2d"))) else null
	environment.glow_enabled = glow
	if glow:
		var levels: Array = Quality.get_setting(&"glow_levels")
		for i in 7:
			environment.set_glow_level(i, levels.has(i + 1))
		environment.glow_intensity = float(Quality.get_setting(&"glow_intensity"))
		environment.glow_bloom = float(Quality.get_setting(&"glow_bloom"))
		var hdr := bool(Quality.get_setting(&"hdr_2d"))
		var thr: Variant = Quality.get_setting(&"glow_threshold_ldr")
		environment.glow_hdr_threshold = float(Quality.get_setting(&"glow_threshold")) if hdr or thr == null else float(thr)
		environment.glow_normalized = Quality.tier == Quality.Tier.MEDIUM
	grade_rect.material = _vignette_mat if StringName(Quality.get_setting(&"grading")) == &"vignette" else _grade_mat
	var vt := AmbianceTextures.get_tex(&"vignette_1024")
	_vignette_mat.set_shader_parameter(&"vignette_tex", vt)
	_vignette_mat.set_shader_parameter(&"use_tex", vt != null)
	sun.visible = bool(Quality.get_setting(&"sun"))
	fill.visible = bool(Quality.get_setting(&"entity_fill"))
	if is_node_ready() and weather.is_node_ready():
		weather.on_quality()
	if map != null:
		_rebuild_map_dependent()
	OccluderBuilder.refresh_dynamic(get_tree())
	_ldr_dirty = true
	_push(0.0)


# --- Boucle -------------------------------------------------------------------

func set_difficulty(D: float, tier: StringName = &"") -> void:
	difficulty = D
	tier_name = tier if tier != &"" else _tier_for(D)


static func _tier_for(D: float) -> StringName:
	if D < 1.5: return &"Calme"
	if D < 2.5: return &"Tendu"
	if D < 4.0: return &"Hostile"
	if D < 6.0: return &"Furieux"
	return &"Cataclysme"


func current_params() -> Dictionary:
	return _current


func target_params() -> Dictionary:
	return _target


func view_rect() -> Rect2:
	var vp := get_viewport()
	var xf := vp.get_canvas_transform().affine_inverse()
	return Rect2(xf.origin, vp.get_visible_rect().size * xf.get_scale())


func _process(delta: float) -> void:
	if profile == null:
		return
	_eval_t += delta
	if _eval_t >= EVAL_INTERVAL:
		_eval_t = 0.0
		_target = profile.evaluate(difficulty)
	var k := 1.0 - pow(0.5, delta / SMOOTH_HALF_LIFE_S)
	_smooth_current(k) # intervalles : pas de lissage
	if tier_name != _lights_tier:
		_lights_tier = tier_name
		_update_map_lights_tier()
	_warmth = move_toward(_warmth, _warmth_target, delta / 0.5)
	if _bell_t >= 0.0:
		_bell_t += delta
		if _bell_t > 0.3 and _bell != null:
			_bell.set_energy(1.0)
			_bell_t = -1.0
	_push(delta)


## Lissage de _current vers _target EN PLACE (perf : ~0,1 ms/image avec lerp_params, qui alloue un
## Dictionary de ~80 clés et teste chaque clé par type). Clés classées une fois par forme de cible :
## flottants, couleurs, Vector2, puis le reste (sauts immédiats, comme lerp_params(.., step_at = 0)).
func _smooth_current(k: float) -> void:
	if _current.is_empty():
		return
	if _smooth_shape != _target.size() or _smooth_src != _current.size():
		_classify_smooth_keys()
	var c := _current
	var t := _target
	for key in _smooth_f:
		c[key] = lerpf(c[key], t[key], k)
	for key in _smooth_c:
		c[key] = (c[key] as Color).lerp(t[key], k)
	for key in _smooth_v:
		c[key] = (c[key] as Vector2).lerp(t[key], k)
	for key in _smooth_step:
		c[key] = t[key]


func _classify_smooth_keys() -> void:
	_smooth_f.clear()
	_smooth_c.clear()
	_smooth_v.clear()
	_smooth_step.clear()
	for key in _current:
		if not _target.has(key):
			continue
		var a: Variant = _current[key]
		var b: Variant = _target[key]
		var ta := typeof(a)
		var tb := typeof(b)
		if key in AmbianceProfile.STEP_KEYS:
			_smooth_step.append(key)
		elif (ta == TYPE_FLOAT or ta == TYPE_INT) and (tb == TYPE_FLOAT or tb == TYPE_INT):
			_current[key] = float(a)
			_smooth_f.append(key)
		elif ta == TYPE_COLOR and tb == TYPE_COLOR:
			_smooth_c.append(key)
		elif ta == TYPE_VECTOR2 and tb == TYPE_VECTOR2:
			_smooth_v.append(key)
		else:
			_smooth_step.append(key)
	_smooth_shape = _target.size()
	_smooth_src = _current.size()


## Équivalent LDR d'une lumière additive calée en linéaire : couleur sRGB (et énergie) qu'il faut
## AJOUTER à une base `base_s` (sRGB) pour obtenir, à la part `ref` de la lumière (normal map, pente),
## la même valeur encodée que le mélange linéaire base_l + couleur_l × énergie × ref.
## Retourne [Color (canaux <= 1), énergie].
static func ldr_light(base_l: Color, base_s: Color, c: Color, e: float, ref: float) -> Array:
	var tot := _add_light_l(base_l, c, e * ref).linear_to_srgb()
	var r := maxf(tot.r - base_s.r, 0.0) / ref
	var g := maxf(tot.g - base_s.g, 0.0) / ref
	var b := maxf(tot.b - base_s.b, 0.0) / ref
	var m := maxf(maxf(r, g), maxf(b, 1.0e-4))
	if m <= 1.0:
		return [Color(r, g, b, 1.0), 1.0]
	return [Color(r / m, g / m, b / m, 1.0), m]


## Opacité sRGB équivalente (LDR) d'un voile clair de couleur `c` (sRGB) posé avec l'opacité `a`
## en mélange linéaire, sur le fond de référence sRGB 0,12 (même formule que
## shaders/ldr_blend.gdshaderinc). Identité hors LDR.
static func ldr_alpha(a: float, c: Color) -> float:
	var cs := maxf(maxf(c.r, c.g), c.b)
	if not ldr_mode or cs <= 0.14 or a <= 0.0:
		return a
	var tot := pow(lerpf(0.0094, pow(cs, 2.2), a), 1.0 / 2.2)
	return lerpf(a, clampf((tot - 0.12) / (cs - 0.12), a, 1.0), 0.5) # LDR_VEIL_K du shader


## Marque LDR / HDR tous les ShaderMaterial de l'eau, de la brume et de la météo (uniform `ldr` de
## shaders/ldr_blend.gdshaderinc ; sans effet sur les shaders qui ne l'ont pas).
func _apply_ldr_uniform() -> void:
	for n in [water, fog, weather]:
		_set_ldr_rec(n)


func _set_ldr_rec(n: Node) -> void:
	if n is CanvasItem:
		var m := (n as CanvasItem).material as ShaderMaterial
		if m != null:
			m.set_shader_parameter(&"ldr", ldr_mode)
	for c in n.get_children():
		_set_ldr_rec(c)


static func _add_light_l(base_l: Color, c: Color, e: float) -> Color:
	var cl := c.srgb_to_linear()
	return Color(base_l.r + cl.r * e, base_l.g + cl.g * e, base_l.b + cl.b * e, 1.0)


## Applique les paramètres courants aux nœuds (public pour les tests : _push(0)).
func _push(delta: float) -> void:
	if _current.is_empty():
		return
	var p := _current
	var view := view_rect()
	var sun_on := sun.visible
	var fill_on := fill.visible
	var amb: Color = p[&"ambient_color"] if sun_on else p[&"ambient_low"]
	var sun_c: Color = p[&"sun_color"]
	var sun_e := float(p[&"sun_energy"])
	# Garde-fous v2 : le sol ne descend pas sous ground_floor (0,20 avec soleil, 0,16 sans) ; les
	# entités reçoivent en plus le fill, remonté jusqu'à MIN_EFFECTIVE_LUMINANCE. Sans fill (coupé),
	# l'ambiante porte tout.
	amb = AmbianceProfile.guard_ambient(amb, sun_c, sun_e, sun_on,
		-1.0 if fill_on else AmbianceProfile.MIN_EFFECTIVE_LUMINANCE)
	if _warmth > 0.0:
		amb = amb.lerp(_warmth_color, 0.08 * _warmth)
	canvas_modulate.color = amb
	var fill_c: Color = p[&"fill_color"]
	var fill_e := float(p[&"fill_energy"] if sun_on else p[&"fill_energy_low"])
	fill_e = AmbianceProfile.guard_fill(amb, sun_c, sun_e, sun_on, fill_c, fill_e) if fill_on else 0.0
	# Paliers LDR (HDR 2D coupé, Moyen / Bas) : le profil est calé pour un mélange LINÉAIRE ; en LDR
	# les lumières s'additionnent en sRGB et délavent le sol éclairé. On convertit soleil et fill en
	# la couleur sRGB qui donne la même somme encodée (voir ldr_light()).
	var ldr := not get_tree().root.use_hdr_2d
	if ldr != ldr_mode or _ldr_dirty:
		ldr_mode = ldr
		_ldr_dirty = false
		_apply_ldr_uniform()
	var sun_out := Color(sun_c, 1.0)
	var sun_out_e := sun_e
	if ldr:
		var amb_l := amb.srgb_to_linear()
		var lit_l := amb_l
		var lit_s := amb
		if sun_on:
			var s := ldr_light(amb_l, amb, sun_c, sun_e, LDR_SUN_REF)
			sun_out = s[0]
			sun_out_e = s[1]
			lit_l = _add_light_l(amb_l, sun_c, sun_e * LDR_SUN_REF)
			lit_s = Color(amb.r + sun_out.r * sun_out_e * LDR_SUN_REF, amb.g + sun_out.g * sun_out_e * LDR_SUN_REF, amb.b + sun_out.b * sun_out_e * LDR_SUN_REF)
		if fill_on and fill_e > 0.0:
			var f := ldr_light(lit_l, lit_s, fill_c, fill_e, 1.0)
			fill_c = f[0]
			fill_e = f[1]
	fill.color = fill_c
	fill.energy = fill_e
	if not lightning.sun_busy():
		sun.color = sun_out
		sun.energy = sun_out_e
		sun.rotation_degrees = float(p[&"sun_rotation_deg"])
		sun.height = float(p[&"sun_height"])
		# `sun_shadow_length_u` > 0 = la carte projette des ombres directionnelles (longues : rasant) ;
		# la valeur module l'opacité de l'ombre (plafond à 2 u : 2 u et plus = ombre pleine).
		var len_u := float(p[&"sun_shadow_length_u"])
		# Ombres du décor CUITES (BakedShadows) : la directionnelle ne projette plus d'ombre
		# dynamique sauf palier qui la demande explicitement (sun_shadows, aucun par défaut).
		sun.shadow_enabled = (bool(Quality.get_setting(&"sun_shadows")) or debug_dynamic_sun) and len_u > 0.01
		sun.max_distance = SUN_SHADOW_CULL_PX
		var sc: Color = p[&"sun_shadow_color"]
		sc.a *= clampf(len_u / 2.0, 0.0, 1.0)
		sun.shadow_color = sc
		sun.shadow_filter_smooth = float(p[&"sun_shadow_smooth"])
		if profile != null:
			sun.shadow_filter = profile.sun_shadow_filter as Light2D.ShadowFilter
	var le := float(p[&"lights_energy"]) * (LDR_POINT_ENERGY if ldr else 1.0)
	var lr := LDR_POINT_RADIUS if ldr else 1.0
	LightRig.category_scale[&"player"] = Vector2(float(p[&"player_light_scale"]) * lr, le)
	for cat in [&"pillar", &"chest", &"boss", &"spell", &"elite", &"event", &"pickup"]:
		LightRig.category_scale[cat] = Vector2(lr, le)
	LightRig.category_scale[&"decor"] = Vector2(float(p[&"map_lights_radius"]) * lr, float(p[&"map_lights_energy"]) * le)
	LightRig.outage_scale = float(p[&"lamp_outage_scale"])
	_push_shadows(p)
	_push_grade(p, view)
	var player_pos := view.get_center()
	var pl := get_tree().get_first_node_in_group(&"player") as Node2D
	if pl != null:
		player_pos = pl.global_position
	water.update_water(view, p, delta)
	fog.update_fog(view, p, delta, player_pos)
	weather.update_weather(view, p, delta)


## Ombres cuites + ombres de contact : couleur / opacité du profil (alpha modulé par la longueur,
## comme l'ancienne ombre du soleil) et facteur du palier.
func _push_shadows(p: Dictionary) -> void:
	var on := bool(Quality.get_setting(&"baked_shadows")) and not debug_dynamic_sun
	var k := float(Quality.get_setting(&"baked_shadow_strength"))
	var len_u := float(p[&"sun_shadow_length_u"])
	var sc: Color = p[&"sun_shadow_color"]
	var q := p.duplicate()
	q[&"sun_shadow_length_u"] = len_u if on else 0.0
	sc.a *= clampf(len_u / 2.0, 0.0, 1.0) * BAKED_ALPHA_MULT
	q[&"sun_shadow_color"] = sc
	baked_shadows.visible = on
	if on:
		baked_shadows.update_params(q, k)
	var cs: Color = p[&"sun_shadow_color"]
	cs.a = CONTACT_SHADOW_ALPHA
	creature_shadows.visible = bool(Quality.get_setting(&"contact_shadows"))
	creature_shadows.set_tint(cs, 1.0)


func _push_grade(p: Dictionary, view: Rect2) -> void:
	var m := grade_rect.material as ShaderMaterial
	var aspect := view.size.x / maxf(view.size.y, 1.0)
	for k in [&"vignette_strength", &"vignette_radius", &"vignette_softness"]:
		m.set_shader_parameter(k, float(p[k]))
	m.set_shader_parameter(&"vignette_color", p[&"vignette_color"])
	m.set_shader_parameter(&"aspect", aspect)
	if m == _grade_mat:
		m.set_shader_parameter(&"linear_input", get_viewport().use_hdr_2d)
		m.set_shader_parameter(&"lift_color", p[&"lift_color"])
		m.set_shader_parameter(&"lift_amount", float(p[&"lift_amount"]))
		m.set_shader_parameter(&"gain_color", p[&"gain_color"])
		m.set_shader_parameter(&"gain_amount", float(p[&"gain_amount"]))
		m.set_shader_parameter(&"contrast", float(p[&"contrast"]))
		m.set_shader_parameter(&"contrast_pivot", float(p[&"contrast_pivot"]))
		m.set_shader_parameter(&"saturation", float(p[&"saturation"]))


# --- API gameplay -------------------------------------------------------------

## Foudre de gameplay (Sonneur phase 2 : alpha 0,35 ; pilier terminé : 0,5 + tonnerre immédiat).
func strike_lightning(world_pos: Vector2 = Vector2.INF, alpha: float = 0.35, immediate_thunder: bool = false) -> void:
	lightning.strike_gameplay(world_pos, alpha, immediate_thunder)
	if world_pos != Vector2.INF:
		LightRig.flash(world_pos, &"boss_lightning", 0.2)


## Rayons ponctuels (pilier terminé carte 2 : 2 rayons, 0,18, 6 s ; coffre légendaire ; éclair).
func spawn_rays(world_pos: Vector2, count: int = 2, alpha: float = 0.18, duration: float = 6.0, color: Color = Color.html("#F4F8FF"), rotation_deg: float = 88.0) -> int:
	return fog.spawn_event_rays(world_pos, count, alpha, duration, color, rotation_deg)


## Ultime : le CanvasModulate vire de 8 % vers la teinte du personnage (Ardent « Brasier » : #FFD6B0, §4.2).
func set_ultimate_warmth(active: bool, tint: Color = WARM_COLOR) -> void:
	_warmth_target = 1.0 if active else 0.0
	if active:
		_warmth_color = tint


## Surtension : éteint 120 ms une lampe à vapeur visible (appelé par l'orage).
func outage_random_lamp(ms: float = 120.0) -> void:
	var view := view_rect()
	var cands: Array = []
	for ml in _map_lights:
		var d: Dictionary = ml["def"]
		if StringName(d["preset"]) == &"steam_lamp" and view.has_point(d["global"]):
			cands.append(ml["handle"])
	if not cands.is_empty():
		(cands.pick_random() as LightRig.Handle).outage(ms)


func _on_lightning_bell() -> void:
	if _bell != null:
		_bell.set_energy(4.0) # 0,2 -> 0,8 pendant 300 ms (§2.3)
		_bell_t = 0.0
