class_name GroundSplat
extends Polygon2D
## Sol v2 (refonte du 31/10/2026, retour joueur : « le sol fait très tiles rectangulaires »).
## Remplace, pour les cartes iso, la TileMapLayer « Ground » (losanges 4 u de 4 variantes, motifs uniques
## et bords sombres répétés tous les 4 u : la grille se lisait) par UN quad en repère carte, sous Visual,
## dessiné par shaders/ground_splat_<palier>.gdshader :
##   - 4 matières vues de dessus et tuilables (data/maps/ground/biomes.json, contrat art/briefs/SOL_contrat.md),
##   - un masque de carte cuit au chargement depuis la grille (sol / humidité / murs / eau peu profonde),
##     lissé, donc sans bord de case,
##   - un bruit tuilable basse fréquence cuit une fois par session (taches, variation macro).
## Collision, navigation, minimap, rives, ombres cuites, secrets : inchangés (ils lisent la grille JSON
## ou les StaticBody2D, jamais ce nœud). Un draw call, coût CPU nul par image ; le palier de qualité
## (Quality) choisit la variante du shader (2 / 4 matières, anti-répétition).

const CONFIG_PATH := "res://data/maps/ground/biomes.json"
const SHADERS := {
	0: "res://shaders/ground_splat_low.gdshader",
	1: "res://shaders/ground_splat_medium.gdshader",
	2: "res://shaders/ground_splat_high.gdshader",
}
const MASK_K := 4 ## texels du masque par case de la grille (case = 2 u)
const NOISE_PX := 256 ## bruit tuilable 256², deux canaux
const NOISE_PERIOD_U := 40.0 ## une période de bruit = 40 u (taches de quelques u, bien plus grandes qu'une case)
const WET_RADIUS := 2 ## cases : rayon de l'humidité autour de l'eau
const WALL_RADIUS := 1 ## cases : rayon de la matière « pied de mur »

static var _config: Dictionary = {}
static var _noise_tex: ImageTexture = null

var biome := ""
var mask_image: Image = null ## masque cuit (tests, captures)
var layer_paths: Array[String] = [] ## textures effectivement chargées, matières 0..3
var quality_tier := -1


## Configuration du biome (vide si inconnu).
static func config_for(biome_id: String) -> Dictionary:
	if _config.is_empty() and FileAccess.file_exists(CONFIG_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if d is Dictionary:
			_config = d
	var c = _config.get(biome_id, {})
	return c if c is Dictionary else {}


## Chemin de la texture de la matière `i` du biome : fichier livré (dir + file), sinon repli provisoire.
static func layer_path(cfg: Dictionary, i: int) -> String:
	var layers: Array = cfg.get("layers", [])
	if i >= layers.size():
		return ""
	var l: Dictionary = layers[i]
	var p := String(cfg.get("dir", "")) + String(l.get("file", ""))
	if ResourceLoader.exists(p):
		return p
	var fb := String(l.get("fallback", ""))
	return fb if fb != "" and ResourceLoader.exists(fb) else ""


## Vrai si le biome a au moins ses matières 0 et 1 (sinon la carte garde l'ancien sol en tuiles).
static func available(biome_id: String) -> bool:
	var cfg := config_for(biome_id)
	return not cfg.is_empty() and layer_path(cfg, 0) != "" and layer_path(cfg, 1) != ""


## Construit le sol d'une carte : `grid` = grille visuelle (StageMap._visual_grid), `origin` = coin haut-gauche
## de la grille en px carte, `cell_px` = côté d'une case. `seed_key` décorrèle le bruit d'une carte à l'autre.
func setup(biome_id: String, grid: Array, origin: Vector2, cell_px: float, seed_key: String) -> void:
	name = "GroundSplat"
	biome = biome_id
	var cfg := config_for(biome_id)
	var rows := grid.size()
	var cols := 0
	for r in grid:
		cols = maxi(cols, (r as String).length())
	var size := Vector2(cols, rows) * cell_px
	polygon = PackedVector2Array([origin, origin + Vector2(size.x, 0.0), origin + size, origin + Vector2(0.0, size.y)])
	mask_image = bake_mask(grid, cols, rows)
	var mat := ShaderMaterial.new()
	mat.set_shader_parameter(&"mask_tex", ImageTexture.create_from_image(mask_image))
	mat.set_shader_parameter(&"noise_tex", noise_texture())
	mat.set_shader_parameter(&"map_origin", origin)
	mat.set_shader_parameter(&"map_inv_size", Vector2(1.0 / size.x, 1.0 / size.y))
	mat.set_shader_parameter(&"noise_inv_px", 1.0 / (NOISE_PERIOD_U * 64.0))
	var h := absi(hash(seed_key))
	mat.set_shader_parameter(&"noise_offset", Vector2(float(h % 997) / 997.0, float((h / 997) % 991) / 991.0))
	var inv := Vector4.ONE / 256.0
	layer_paths.clear()
	var layers: Array = cfg.get("layers", [])
	for i in 4:
		var p := layer_path(cfg, i)
		if p == "": # matière absente : on réutilise la 0 (mélange sans effet visible)
			p = layer_path(cfg, 0)
		layer_paths.append(p)
		mat.set_shader_parameter(StringName("tex%d" % i), load(p))
		var l: Dictionary = layers[i] if i < layers.size() else {}
		inv[i] = 1.0 / (float(l.get("size_u", 4.0)) * 64.0)
		mat.set_shader_parameter(StringName("tint%d" % i), _vec3(l.get("tint", [1.0, 1.0, 1.0])))
	mat.set_shader_parameter(&"layer_inv_px", inv)
	for k in ["patch_cover", "macro_value", "macro_tint_amount", "edge_ao", "shallow_alpha"]:
		if cfg.has(k):
			mat.set_shader_parameter(StringName(k), float(cfg[k]))
	for k in ["macro_tint", "shallow_tint"]:
		if cfg.has(k):
			mat.set_shader_parameter(StringName(k), _vec3(cfg[k]))
	material = mat
	_apply_quality()
	if not Quality.quality_changed.is_connected(_on_quality):
		Quality.quality_changed.connect(_on_quality)


func _on_quality(_t: int) -> void:
	_apply_quality()


func _apply_quality() -> void:
	var t := clampi(int(Quality.tier), 0, 2)
	if t == quality_tier and (material as ShaderMaterial).shader != null:
		return
	quality_tier = t
	(material as ShaderMaterial).shader = load(SHADERS[t])


static func _vec3(a) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ONE


## Masque RGBA8 (MASK_K texels par case) : R sol (hors vide « espace »), G humidité (eau « ~ » / « , » et
## alentours, décroissante sur WET_RADIUS cases), B pied de mur (« # », WALL_RADIUS), A eau peu profonde « , ».
## Valeurs par case puis agrandissement cubique (C++) : bords lissés, aucun créneau de case.
static func bake_mask(grid: Array, cols: int, rows: int) -> Image:
	var data := PackedByteArray()
	data.resize(cols * rows * 4)
	var wet := PackedFloat32Array()
	wet.resize(cols * rows)
	var wall := PackedFloat32Array()
	wall.resize(cols * rows)
	for y in rows:
		var row: String = grid[y]
		for x in cols:
			var ch := row[x] if x < row.length() else " "
			if ch == "~" or ch == ",":
				_splat(wet, cols, rows, x, y, WET_RADIUS)
			elif ch == "#":
				_splat(wall, cols, rows, x, y, WALL_RADIUS)
	for y in rows:
		var row: String = grid[y]
		for x in cols:
			var ch := row[x] if x < row.length() else " "
			var i := (y * cols + x) * 4
			data[i] = 0 if ch == " " else 255
			data[i + 1] = int(clampf(wet[y * cols + x], 0.0, 1.0) * 255.0)
			data[i + 2] = int(clampf(wall[y * cols + x], 0.0, 1.0) * 255.0)
			data[i + 3] = 255 if ch == "," else 0
	var img := Image.create_from_data(cols, rows, false, Image.FORMAT_RGBA8, data)
	img.resize(cols * MASK_K, rows * MASK_K, Image.INTERPOLATE_CUBIC)
	return img


## --- Eau à bords organiques (31/10/2026) ---------------------------------------------------------------
## Masque RGBA8 de l'eau, même résolution et même agrandissement cubique que bake_mask : R eau profonde « ~ »,
## G eau peu profonde « , », B sol praticable (ni « ~ » ni mur ni vide), A = 1. Un mur « # » / « D » voisin d'une
## case d'eau en prend la valeur (l'eau finit sous le mur, pas devant) ; le vide « espace » reste sec.
## Les shaders d'eau et de rive (puddle_common.gdshaderinc, water_bank.gdshader) seuillent ce masque lissé à 0,5
## avec le bruit du sol : bord sinueux, rien par image.
const WATER_SOLIDS := "#D"
const WARP_PERIOD_DIV := 6.0 ## le bruit de bord tourne 6 fois plus vite que celui du sol (taches de ~1,5 case)

static var _water_cache_key := -1
static var _water_cache: Image = null


static func bake_water_mask(grid: Array, cols: int, rows: int) -> Image:
	var key := hash(grid) ^ (cols * 7919 + rows)
	if key == _water_cache_key and _water_cache != null:
		return _water_cache
	var data := PackedByteArray()
	data.resize(cols * rows * 4)
	for y in rows:
		var row: String = grid[y]
		for x in cols:
			var ch := row[x] if x < row.length() else " "
			var deep := 0
			var shallow := 0
			var walk := 0
			if ch == "~":
				deep = 255
			elif ch == ",":
				shallow = 255
				walk = 255
			elif WATER_SOLIDS.contains(ch):
				for o in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var nx: int = x + o.x
					var ny: int = y + o.y
					if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
						continue
					var nrow: String = grid[ny]
					var nch := nrow[nx] if nx < nrow.length() else " "
					if nch == "~":
						deep = 255
					elif nch == ",":
						shallow = 255
			elif ch != " ":
				walk = 255
			var i := (y * cols + x) * 4
			data[i] = deep
			data[i + 1] = shallow
			data[i + 2] = walk
			data[i + 3] = 255
	var img := Image.create_from_data(cols, rows, false, Image.FORMAT_RGBA8, data)
	img.resize(cols * MASK_K, rows * MASK_K, Image.INTERPOLATE_CUBIC)
	_water_cache_key = key
	_water_cache = img
	return img


## Renseigne les uniforms « region » (puddle_common.gdshaderinc / water_bank.gdshader) d'un matériau :
## masque `tex` (couvre `size` px, coin haut-gauche = origine locale du quad), canal `chan`, bruit du sol décalé par carte.
static func set_region(mat: ShaderMaterial, tex: Texture2D, chan: Vector4, size: Vector2, seed_key: String, detail: int) -> void:
	mat.set_shader_parameter(&"use_region", true)
	mat.set_shader_parameter(&"region_tex", tex)
	mat.set_shader_parameter(&"region_chan", chan)
	mat.set_shader_parameter(&"region_inv_size", Vector2(1.0 / size.x, 1.0 / size.y))
	mat.set_shader_parameter(&"warp_tex", noise_texture())
	mat.set_shader_parameter(&"warp_inv_px", WARP_PERIOD_DIV / (NOISE_PERIOD_U * 64.0))
	var h := absi(hash(seed_key + "_eau"))
	mat.set_shader_parameter(&"warp_offset", Vector2(float(h % 997) / 997.0, float((h / 997) % 991) / 991.0))
	mat.set_shader_parameter(&"warp_detail", detail)


## Ajoute une influence décroissante (1 au centre, ~0 à r + 1 cases) autour de (cx, cy), en gardant le max.
static func _splat(buf: PackedFloat32Array, cols: int, rows: int, cx: int, cy: int, r: int) -> void:
	for dy in range(-r, r + 1):
		var y := cy + dy
		if y < 0 or y >= rows:
			continue
		for dx in range(-r, r + 1):
			var x := cx + dx
			if x < 0 or x >= cols:
				continue
			var v := 1.0 - sqrt(float(dx * dx + dy * dy)) / float(r + 1)
			var i := y * cols + x
			if v > buf[i]:
				buf[i] = v


## Bruit tuilable deux canaux (R macro, G taches), cuit une fois par session.
static func noise_texture() -> ImageTexture:
	if _noise_tex != null:
		return _noise_tex
	var a := _noise_image(7331, 3.0)
	var b := _noise_image(1913, 5.0)
	var da := a.get_data()
	var db := b.get_data()
	var out := PackedByteArray()
	out.resize(NOISE_PX * NOISE_PX * 2)
	for i in NOISE_PX * NOISE_PX:
		out[i * 2] = da[i]
		out[i * 2 + 1] = db[i]
	_noise_tex = ImageTexture.create_from_image(Image.create_from_data(NOISE_PX, NOISE_PX, false, Image.FORMAT_RG8, out))
	return _noise_tex


static func _noise_image(seed_v: int, freq_periods: float) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	n.frequency = freq_periods / float(NOISE_PX)
	var img := n.get_seamless_image(NOISE_PX, NOISE_PX, false, false, 0.1, true)
	img.convert(Image.FORMAT_L8)
	return img
