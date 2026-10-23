class_name AmbianceTextures
extends RefCounted
## Chemins documentés des textures d'ambiance rendues dans Blender (agent d'assets) et replis
## neutres minimaux. Aucune texture finale n'est dessinée ici : le repli sert seulement à ce que
## le système tourne (lumière ronde neutre, goutte = trait blanc) ou s'éteigne proprement.
##
## Noms : docs/Direction_Lumiere_Ambiance.md §6. Dossier : res://assets/sprites/ambiance/<nom>.png
## (consigne de l'orchestrateur) ; repli de recherche sur res://assets/ambience/ (nom du doc §6).
## Variantes : <nom>.png (1re), <nom>_2.png, <nom>_3.png… Textures de lumière et de particules en
## niveaux de gris sur alpha. Les « raccordables » doivent boucler (les shaders forcent repeat).

const DIRS: Array[String] = ["res://assets/sprites/ambiance/", "res://assets/ambience/"]

## id -> fallback (&"halo" | &"streak" | &"dot" | &"none"). L'id est le nom de fichier sans .png.
const CATALOG := {
	# Lumières (PointLight2D) — P0
	&"light_soft_256": &"halo",
	&"light_hard_256": &"halo",
	&"light_ring_256": &"halo",
	&"halo_soft_256": &"none",
	# Ombre de contact commune des créatures (rendu Blender à venir ; repli = disque doux neutre)
	&"shadow_blob_256": &"halo",
	# Pluie et eau — P0
	&"rain_sheet_512": &"none",
	&"drop_32": &"streak",
	&"splash_8x64": &"dot",
	&"ripple_8x64": &"none",
	&"ripple_normal_256": &"none",
	&"puddle_mask_1024": &"none",
	&"sky_sunset_256x64": &"none",
	&"sky_dawn_256x64": &"none",
	&"sky_storm_256x64": &"none",
	# Brume, nuages, rayons — P0/P1
	&"fog_tile_1024": &"none",
	&"fog_tile_1024_2": &"none",
	&"fog_puff_512": &"none",
	&"fog_volume_tile_1024": &"none",
	&"cloud_shadow_2048": &"none",
	&"canopy_shadow_2048": &"none",
	&"godray_512x1024": &"none",
	&"lightcone_256x512": &"none",
	&"vignette_1024": &"none",
	# Particules d'ambiance
	&"spark_16": &"dot",
	&"mote_16": &"dot",
	&"firefly_16": &"dot",
	&"leaf_pine_32": &"dot",
	&"leaf_cedar_32": &"dot",
	&"ash_16": &"dot",
	&"steam_puff_64": &"none",
	# Orage
	&"lightning_bolt_256x1024": &"none",
	&"horizon_glow_1024x256": &"none",
}

## Fichiers déjà livrés sous d'autres noms (chemins relatifs à DIRS[0]), essayés après le nom
## du doc. Les atlas sont lus en images carrées : nombre d'images = largeur / hauteur.
const ALIASES := {
	&"drop_32": ["rain/drop_03.png", "rain/drop_00.png"],
	&"splash_8x64": ["rain/splash_a.png"],
	&"ripple_8x64": ["rain/ripple.png"],
}

static var _cache: Dictionary = {}
static var _index: Dictionary = {} ## nom sans extension -> chemin (recherche récursive)
static var _indexed := false
static var _missing: Array[StringName] = []
static var _warned := false


## Chemin trouvé (premier dossier qui contient le fichier) ou "" si absent.
static func find_path(id: StringName) -> String:
	for d in DIRS:
		var p := d + String(id) + ".png"
		if ResourceLoader.exists(p):
			return p
	if not _indexed:
		_build_index()
	if _index.has(String(id)):
		return _index[String(id)]
	for a in ALIASES.get(id, []):
		var ap: String = DIRS[0] + String(a)
		if ResourceLoader.exists(ap):
			return ap
	return ""


## Nombre d'images d'un atlas horizontal à images carrées (splash, ripple).
static func frame_count(tex: Texture2D) -> int:
	if tex == null:
		return 1
	return maxi(roundi(float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)), 1)


static func _build_index() -> void:
	_indexed = true
	for d in DIRS:
		_scan(d, 0)


static func _scan(dir: String, depth: int) -> void:
	if depth > 3 or not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		if name.get_extension().to_lower() == "png":
			var key := name.get_basename()
			if not _index.has(key):
				_index[key] = dir + name
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + sub + "/", depth + 1)


static func exists(id: StringName) -> bool:
	return find_path(id) != ""


## Texture Blender si elle existe, sinon le repli neutre (null si le repli est &"none").
## Accepte aussi un id hors catalogue (masques par carte : fog_height_mask_<map_id>).
static func get_tex(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = null
	var p := find_path(id)
	if p != "":
		tex = load(p) as Texture2D
	if tex == null:
		if not _missing.has(id):
			_missing.append(id)
		tex = _fallback(CATALOG.get(id, &"none"))
	_cache[id] = tex
	return tex


## Vrai si la texture Blender est là (pas un repli).
static func is_real(id: StringName) -> bool:
	get_tex(id)
	return not _missing.has(id)


static func missing() -> Array[StringName]:
	return _missing


static func warn_missing_once() -> void:
	if _warned or _missing.is_empty():
		return
	_warned = true
	print("Ambiance : textures Blender absentes (replis neutres ou effet coupé) : ", _missing)


static func clear_cache() -> void:
	_cache.clear()
	_index.clear()
	_indexed = false
	_missing.clear()
	_warned = false


static func _fallback(kind: StringName) -> Texture2D:
	match kind:
		&"halo":
			# Repli minimal indispensable au fonctionnement d'une PointLight2D.
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 1))
			g.set_color(1, Color(1, 1, 1, 0))
			var t := GradientTexture2D.new()
			t.gradient = g
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(0.5, 0.0)
			t.width = 256
			t.height = 256
			return t
		&"streak":
			var img := Image.create(2, 24, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			return ImageTexture.create_from_image(img)
		&"dot":
			var img2 := Image.create(4, 4, false, Image.FORMAT_RGBA8)
			img2.fill(Color.WHITE)
			return ImageTexture.create_from_image(img2)
	return null
