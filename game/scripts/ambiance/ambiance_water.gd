class_name AmbianceWater
extends Node2D
## Eau et flaques (World z -18, §1.3, §2) à partir de la grille de la carte
## (data/maps/<map_id>.json) : cases « , » (eau peu profonde) et « ~ » (eau profonde, miroir),
## un quad par couche découpé en shader par le masque lissé (bords organiques) ; plus un calque de flaques du sol (masque
## `puddle_mask_1024`, Moyen et Haut). Shader `puddle.gdshader` : ciel reflété + ondulations
## (normal map : les lumières à bit 2 s'y reflètent) + miroir des entités en Haut + flash d'éclair.

const U := 64.0
const Z_WATER := -18
const VIEW_MARGIN := 256.0
const SHADER := preload("res://shaders/puddle.gdshader")
const SHADER_MIRROR := preload("res://shaders/puddle_mirror.gdshader") ## lit l'écran : Haut seulement
const MASK_WORLD := 8 ## = LightRig.MASK_GROUND : l'eau est du sol (pas de « fill » des entités)
const MASK_PUDDLES := 2
## Lisibilité praticable / bloquant (retour joueur 22/10/2026) : l'eau profonde « ~ » (bloquante) est nettement
## plus sombre et plus couvrante que l'eau peu profonde « , » (film clair sur le sol), et animée par les
## caustiques Codex `water_caustics_512` (sans normal map). Sa rive est tracée par StageMap._build_water_banks (même masque, shader water_bank).
const DEEP_TINT := Color(0.035, 0.07, 0.095) ## presque noir bleuté
const DEEP_ALPHA_BASE := 0.62 ## + water_reflect × DEEP_ALPHA_K, plafonné à DEEP_ALPHA_MAX
const DEEP_ALPHA_K := 0.15
const DEEP_ALPHA_MAX := 0.82
const DEEP_SKY_K := 0.3 ## part du reflet de ciel gardée sur l'eau profonde (le ciel l'éclaircissait comme une flaque)
const DEEP_CAUSTICS := 0.14 ## intensité des reflets mouvants (caustiques) sur l'eau profonde

var shallow_root: Node2D
var deep_root: Node2D
var ground: ColorRect
var shallow_rects := 0
var deep_rects := 0

var _shallow_mat: ShaderMaterial
var _deep_mat: ShaderMaterial
var _ground_mat: ShaderMaterial
var _off_a := Vector2.ZERO
var _off_b := Vector2.ZERO
var _sky_scroll := 0.0
var _flash := 0.0
var _flash_t := 0.0
## Crue visuelle (événement ambiant « flood », AmbientEvents) : canal alpha du masque de l'eau peu profonde = cases
## inondables ; le shader lit G + A × _flood_level (0 = carte d'origine, 0,5 = bord avancé d'une demi-case, 1 u).
var _flood_level := 0.0
var _flood_ready := false
var _grid := PackedStringArray()
var _cols := 0
var _rows := 0
var _origin := Vector2.ZERO
var _size := Vector2.ZERO
var _map_key := ""


func _ready() -> void:
	z_index = Z_WATER
	_shallow_mat = _new_mat(Color.html("#54707A"))
	_deep_mat = _new_mat(DEEP_TINT)
	_ground_mat = _new_mat(Color.html("#54707A"))
	_ground_mat.set_shader_parameter(&"mask_mode", 1)
	shallow_root = Node2D.new()
	shallow_root.name = "Shallow"
	add_child(shallow_root)
	deep_root = Node2D.new()
	deep_root.name = "Deep"
	add_child(deep_root)
	ground = ColorRect.new()
	ground.name = "GroundPuddles"
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.material = _ground_mat
	add_child(ground)


func _new_mat(tint: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"base_tint", tint)
	return m


## Construit les surfaces d'eau d'une carte (StageMap + sa grille JSON).
func setup(map: Node2D, profile: AmbianceProfile) -> void:
	for root in [shallow_root, deep_root]:
		for c in (root as Node).get_children():
			c.queue_free()
	shallow_rects = 0
	deep_rects = 0
	_flood_level = 0.0
	_flood_ready = false
	_grid = PackedStringArray()
	var rip := AmbianceTextures.get_tex(&"ripple_normal_256")
	var sky: Texture2D = null
	if profile != null and profile.sky_texture != &"":
		sky = AmbianceTextures.get_tex(profile.sky_texture)
	var mask := AmbianceTextures.get_tex(&"puddle_mask_1024")
	var caustics := AmbianceTextures.get_tex(&"water_caustics_512")
	_deep_mat.set_shader_parameter(&"caustics", caustics)
	_deep_mat.set_shader_parameter(&"caustic_amount", DEEP_CAUSTICS if caustics != null else 0.0)
	for m in [_shallow_mat, _deep_mat, _ground_mat]:
		(m as ShaderMaterial).set_shader_parameter(&"ripples", rip)
		(m as ShaderMaterial).set_shader_parameter(&"has_ripples", rip != null)
		(m as ShaderMaterial).set_shader_parameter(&"sky", sky)
		(m as ShaderMaterial).set_shader_parameter(&"has_sky", sky != null)
	_ground_mat.set_shader_parameter(&"mask", mask)
	ground.set_meta(&"has_mask", mask != null)
	if map == null:
		return
	# tuiles iso de Codex : flaques et pierre humide déjà cuites dans le sol ; le calque plein écran
	# couvrirait aussi l'abîme hors carte
	if map is StageMap and (map as StageMap).is_iso():
		ground.set_meta(&"has_mask", false)
	# bandes d'eau en repère carte (grille tournée de 45° en iso, docs/Design_Isometrique.md §3 L3)
	shallow_root.global_transform = map.global_transform * StageMap.frame_of(map)
	deep_root.global_transform = map.global_transform * StageMap.frame_of(map)
	var g := grid_of(map)
	if g.is_empty():
		return
	var grid: PackedStringArray = g["grid"]
	var cell: float = g["cell_px"]
	var origin: Vector2 = g["origin"]
	# Bords organiques (31/10/2026) : UN quad par couche (eau peu profonde, eau profonde) couvrant la carte ;
	# le masque cuit et lissé de GroundSplat.bake_water_mask, déformé par le bruit du sol, découpe l'eau en shader.
	var cols := 0
	for row in grid:
		cols = maxi(cols, row.length())
	var rows := grid.size()
	var size := Vector2(cols, rows) * cell
	var tex := ImageTexture.create_from_image(GroundSplat.bake_water_mask(Array(grid), cols, rows))
	var key := String(map.get_meta(&"map_id", ""))
	_grid = grid
	_cols = cols
	_rows = rows
	_origin = origin
	_size = size
	_map_key = key
	var detail := 1 if int(Quality.get_setting(&"puddles")) >= 1 else 0
	GroundSplat.set_region(_shallow_mat, tex, Vector4(0.0, 1.0, 0.0, 0.0), size, key, detail)
	GroundSplat.set_region(_deep_mat, tex, Vector4(1.0, 0.0, 0.0, 0.0), size, key, detail)
	var has_shallow := false
	var has_deep := false
	for row in grid:
		has_shallow = has_shallow or row.contains(",")
		has_deep = has_deep or row.contains("~")
	if has_shallow:
		shallow_root.add_child(_region_rect(origin, size, _shallow_mat))
		shallow_rects = 1
	if has_deep:
		deep_root.add_child(_region_rect(origin, size, _deep_mat))
		deep_rects = 1


## Prépare la crue visuelle : `flags` = un octet par case de la grille (cols × rows, 255 = case inondable). Le masque
## de l'eau peu profonde est recuit une fois avec ces cases dans son canal alpha (même lissage cubique que
## GroundSplat.bake_water_mask) ; ensuite set_flood_level() ne change qu'un uniform (aucune allocation, aucun quad
## de plus). Retourne false sans grille. À appeler au chargement de l'étage (≈ 25 000 texels, une fois).
func prepare_flood(flags: PackedByteArray) -> bool:
	if _grid.is_empty() or flags.size() != _cols * _rows:
		return false
	var base := GroundSplat.bake_water_mask(Array(_grid), _cols, _rows)
	var data := base.get_data()
	var fl := Image.create_from_data(_cols, _rows, false, Image.FORMAT_L8, flags)
	fl.resize(base.get_width(), base.get_height(), Image.INTERPOLATE_CUBIC)
	var fd := fl.get_data()
	var n := mini(fd.size(), data.size() / 4)
	for i in n:
		data[i * 4 + 3] = fd[i]
	var img := Image.create_from_data(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8, data)
	var tex := ImageTexture.create_from_image(img)
	var detail := 1 if int(Quality.get_setting(&"puddles")) >= 1 else 0
	GroundSplat.set_region(_shallow_mat, tex, Vector4(0.0, 1.0, 0.0, 0.0), _size, _map_key, detail)
	if shallow_rects == 0: # carte sans « , » : la crue a besoin du calque d'eau peu profonde
		shallow_root.add_child(_region_rect(_origin, _size, _shallow_mat))
		shallow_rects = 1
	_flood_ready = true
	set_flood_level(_flood_level)
	return true


## Niveau de la crue : 0 = rives d'origine ; 0,5 = cases inondables couvertes jusqu'à leur centre (+1 u).
func set_flood_level(k: float) -> void:
	_flood_level = maxf(k, 0.0)
	if _flood_ready:
		_shallow_mat.set_shader_parameter(&"region_chan", Vector4(0.0, 1.0, 0.0, _flood_level))


func flood_level() -> float:
	return _flood_level if _flood_ready else 0.0


func flood_ready() -> bool:
	return _flood_ready


func _region_rect(origin: Vector2, size: Vector2, mat: ShaderMaterial) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = origin
	r.size = size
	r.material = mat
	return r


## Grille de la carte : {grid, cell_px, origin (coin haut-gauche, espace local de la carte)}.
static func grid_of(map: Node2D) -> Dictionary:
	var id := String(map.get_meta(&"map_id", ""))
	var path := "res://data/maps/%s.json" % id
	if id == "" or not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not data.has("grid"):
		return {}
	var unit := float(data.get("unit_px", 64))
	var cell := float(data.get("grid_cell_u", 2)) * unit
	var size_u: Array = data.get("size_u", [0, 0])
	return {"grid": PackedStringArray(data["grid"]), "cell_px": cell, "origin": -Vector2(float(size_u[0]), float(size_u[1])) * unit * 0.5}


## Remplissage blanc à l'éclair (§3.4 : alpha 0,5, 80 ms puis 300 ms de décroissance).
func flash() -> void:
	_flash_t = 0.0
	_flash = 0.5


func update_water(view: Rect2, p: Dictionary, delta: float) -> void:
	var mode := int(Quality.get_setting(&"puddles"))
	var hz := float(p[&"ripple_hz"])
	_off_a += Vector2(0.6, 1.0) * 40.0 * hz * delta
	_off_b -= Vector2(1.0, 0.4) * 30.0 * hz * delta
	_sky_scroll += 0.05 * U / 4096.0 * delta # défile avec les nuages (0,05 u/s)
	if _flash > 0.0:
		_flash_t += delta
		_flash = 0.5 if _flash_t < 0.08 else 0.5 * maxf(0.0, 1.0 - (_flash_t - 0.08) / 0.3)
	var mask := MASK_WORLD | (MASK_PUDDLES if mode >= 1 else 0)
	var sh: Shader = SHADER_MIRROR if mode >= 2 else SHADER
	var mirror_uv := 0.8 * U / maxf(view.size.y, 1.0)
	for m in [_shallow_mat, _deep_mat, _ground_mat]:
		var sm := m as ShaderMaterial
		if sm.shader != sh:
			sm.shader = sh # les paramètres sont conservés (mêmes uniforms)
		sm.set_shader_parameter(&"mode", mode)
		sm.set_shader_parameter(&"offset_a", _off_a)
		sm.set_shader_parameter(&"offset_b", _off_b)
		sm.set_shader_parameter(&"sky_amount", float(p[&"sky_reflect"]))
		sm.set_shader_parameter(&"sky_scroll", _sky_scroll)
		sm.set_shader_parameter(&"mirror_alpha", float(p[&"mirror_alpha"]))
		sm.set_shader_parameter(&"mirror_offset_uv", mirror_uv)
		sm.set_shader_parameter(&"flash", _flash)
		sm.set_shader_parameter(&"warp_detail", 1 if mode >= 1 else 0)
	_shallow_mat.set_shader_parameter(&"strength", clampf(float(p[&"puddle_reflect"]) * 0.6, 0.0, 0.8))
	_deep_mat.set_shader_parameter(&"strength", minf(DEEP_ALPHA_BASE + float(p[&"water_reflect"]) * DEEP_ALPHA_K, DEEP_ALPHA_MAX))
	_deep_mat.set_shader_parameter(&"sky_amount", float(p[&"sky_reflect"]) * DEEP_SKY_K)
	_ground_mat.set_shader_parameter(&"strength", clampf(float(p[&"puddle_reflect"]) * 0.5, 0.0, 0.6))
	for root in [shallow_root, deep_root]:
		for c in (root as Node).get_children():
			(c as CanvasItem).light_mask = mask
	ground.light_mask = mask
	ground.visible = mode >= 1 and bool(ground.get_meta(&"has_mask", false))
	if ground.visible:
		var r := view.grow(VIEW_MARGIN)
		ground.position = r.position - global_position
		ground.size = r.size
