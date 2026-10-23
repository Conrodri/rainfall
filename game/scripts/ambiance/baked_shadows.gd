class_name BakedShadows
extends Node2D
## Ombres CUITES des éléments statiques de la carte (demande du joueur, 21/10/2026 : « baking
## d'ombres »). Remplace les ombres dynamiques du soleil (DirectionalLight2D + LightOccluder2D,
## re-projetées à chaque image) par UNE texture calculée une fois au chargement de l'étage :
##   1. rectangles d'obstacles de la carte (OccluderBuilder.shadow_rects : murs « # », eau exclue) ;
##   2. passage au repère LOGIQUE par une seule fonction, map_to_logical() (la migration iso
##      n'aura qu'à y composer Iso.map_xform(), docs/Design_Isometrique.md §1.2 et §2.7) ;
##   3. extrusion de chaque rectangle dans la direction du soleil de la carte (sun_dir_logical()),
##      en 3 niveaux (dégradé : pleine au pied du mur, plus légère au bout) ;
##   4. rastérisation CPU par lignes (polygones convexes) dans une image L8 sur-échantillonnée,
##      réduite puis floutée (bords doux selon `sun_shadow_smooth`), intérieur des murs effacé ;
##   5. affichage : un seul Sprite2D, shader multiplicatif non éclairé (shaders/baked_shadow.gdshader)
##      posé au-dessus du sol (z Z_GROUND + 1) et sous toutes les entités (z 0).
## Coût en jeu : 1 draw, une texture L8 de ~200 × 320 texels (≈ 60 Kio), aucun calcul par image.
## La longueur d'ombre suit D (profil) : re-cuisson en tâche de fond (WorkerThreadPool) quand elle
## varie de plus de REBAKE_DELTA_U ; la couleur et l'opacité, elles, sont de simples paramètres.
##
## Décalques `<f>_shadow.png` (props et murs livrés par Codex, art/briefs/STYLE.md « OPTIMISATION ET
## OMBRES CUITES ») : tout Sprite2D de la carte dont la texture a un voisin `<f>_shadow.png` reçoit
## un décalque multiplicatif (masque = alpha) dans le nœud « Decals », même transformation.

const TEXEL_PX := 16.0 ## taille d'un texel de la texture finale (px logiques)
const SUPERSAMPLE := 2 ## rastérisation à TEXEL_PX / 2 puis réduction (anticrénelage)
const MARGIN_PX := 256.0
const LEVELS := [[1.0, 0.55], [0.62, 0.8], [0.3, 1.0]] ## [fraction de la longueur, intensité]
const REBAKE_DELTA_U := 0.3
const UNIT_PX := 64.0
const SHADER := preload("res://shaders/baked_shadow.gdshader")

var sprite: Sprite2D
var decals: Node2D
var material_shadow: ShaderMaterial
var decal_material: ShaderMaterial ## partagé par tous les décalques (un seul lot de rendu)
var map: Node2D
var baked_length_u := -1.0
var baked_rotation_deg := 0.0
var bake_ms := 0.0 ## durée de la dernière cuisson (mesure)
var rect_count := 0
var texture_size := Vector2i.ZERO

var _task := -1
var _pending: Dictionary = {}
var _result: Image = null
var _result_bounds := Rect2()
var _mutex := Mutex.new()


func _init() -> void:
	name = "BakedShadows"
	z_index = AmbianceManager.Z_GROUND + 1
	material_shadow = ShaderMaterial.new()
	material_shadow.shader = SHADER
	decal_material = ShaderMaterial.new()
	decal_material.shader = SHADER
	decal_material.set_shader_parameter(&"mask_from_alpha", true)
	sprite = Sprite2D.new()
	sprite.name = "Layer"
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = material_shadow
	sprite.light_mask = 0
	add_child(sprite)
	decals = Node2D.new()
	decals.name = "Decals"
	add_child(decals)


# --- Repères (point unique de conversion pour la migration iso) -------------------------------

## Carte (M) -> logique (L) : transformation globale de la carte composée avec son repère de grille
## (StageMap.frame_of : Iso.map_xform() = Rot +45° en iso, identité sinon). shadow_rects est en repère
## carte ; tout le reste (soleil, extrusion, texture) est en repère logique.
static func map_to_logical(m: Node2D) -> Transform2D:
	return m.global_transform * StageMap.frame_of(m) if m != null else Transform2D.IDENTITY


## Direction (logique) dans laquelle le soleil projette les ombres. `sun_rotation_deg` est un angle
## ÉCRAN (§2.7 ; même convention que la DirectionalLight2D d'avant : 0 = ombre vers le bas de l'écran),
## converti en direction au sol par Iso.screen_to_logical_dir : à l'écran, l'ombre garde l'angle du profil
## (caméra iso commune à toutes les cartes). Les valeurs des profils restent à ressaisir au lot L3.
static func sun_dir_logical(rotation_deg: float) -> Vector2:
	return Iso.screen_to_logical_dir(Vector2.DOWN.rotated(deg_to_rad(rotation_deg)))


# --- API ---------------------------------------------------------------------------------------

## Cuisson synchrone (chargement de l'étage). `p` = paramètres courants du profil (evaluate()).
func bake(m: Node2D, p: Dictionary) -> void:
	map = m
	_cancel_task()
	_build_decals()
	if m == null:
		sprite.texture = null
		return
	var job := _job(m, p)
	var t0 := Time.get_ticks_usec()
	var img := _rasterize(job)
	bake_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_apply(img, job["bounds"])
	baked_length_u = job["length_u"]
	baked_rotation_deg = job["rotation_deg"]
	update_params(p, 1.0)


## Paramètres par image (couleur, opacité) ; relance une cuisson de fond si la longueur a bougé.
func update_params(p: Dictionary, tier_strength: float) -> void:
	var sc: Color = p.get(&"sun_shadow_color", Color(0.1, 0.1, 0.12, 0.5))
	var len_u := float(p.get(&"sun_shadow_length_u", 0.0))
	sprite.visible = len_u > 0.01 and sprite.texture != null
	material_shadow.set_shader_parameter(&"shadow_color", sc)
	material_shadow.set_shader_parameter(&"strength", tier_strength)
	decal_material.set_shader_parameter(&"shadow_color", sc)
	decal_material.set_shader_parameter(&"strength", tier_strength)
	if map == null or not is_instance_valid(map):
		return
	var rot := float(p.get(&"sun_rotation_deg", baked_rotation_deg))
	if len_u > 0.01 and (absf(len_u - baked_length_u) > REBAKE_DELTA_U or absf(rot - baked_rotation_deg) > 2.0):
		_rebake_async(p)


## Résumé pour les bancs de mesure.
func describe() -> String:
	return "%d rects, %dx%d texels, %.1f ms, L=%.2f u" % [rect_count, texture_size.x, texture_size.y, bake_ms, baked_length_u]


func is_baking() -> bool:
	return _task >= 0


func _process(_delta: float) -> void:
	if _task < 0:
		return
	if not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_mutex.lock()
	var img := _result
	var b := _result_bounds
	_result = null
	_mutex.unlock()
	if img != null:
		_apply(img, b)
		baked_length_u = _pending["length_u"]
		baked_rotation_deg = _pending["rotation_deg"]


func _exit_tree() -> void:
	_cancel_task()


# --- Cuisson -----------------------------------------------------------------------------------

## Tout ce dont la rastérisation a besoin, calculé sur le thread principal (accès à l'arbre).
func _job(m: Node2D, p: Dictionary) -> Dictionary:
	var xf := map_to_logical(m)
	var polys: Array[PackedVector2Array] = []
	var bounds := Rect2()
	var first := true
	for r in OccluderBuilder.shadow_rects(m):
		var poly := xf * PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		polys.append(poly)
		for v in poly:
			if first:
				bounds = Rect2(v, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(v)
	var len_u := float(p.get(&"sun_shadow_length_u", 0.0))
	var rot := float(p.get(&"sun_rotation_deg", 315.0))
	rect_count = polys.size()
	return {
		"polys": polys,
		"bounds": bounds.grow(MARGIN_PX + len_u * UNIT_PX),
		"dir": sun_dir_logical(rot),
		"length_u": len_u,
		"rotation_deg": rot,
		"smooth": float(p.get(&"sun_shadow_smooth", 1.0)),
	}


func _rebake_async(p: Dictionary) -> void:
	if _task >= 0:
		return # une cuisson à la fois ; la suivante partira à la prochaine mise à jour
	_pending = _job(map, p)
	var job := _pending
	_task = WorkerThreadPool.add_task(func() -> void:
		var img := BakedShadows._rasterize(job)
		_mutex.lock()
		_result = img
		_result_bounds = job["bounds"]
		_mutex.unlock(), false, "BakedShadows")


func _cancel_task() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_result = null


func _apply(img: Image, bounds: Rect2) -> void:
	if img == null:
		sprite.texture = null
		return
	texture_size = img.get_size()
	var tex := sprite.texture as ImageTexture
	if tex != null and tex.get_size() == Vector2(img.get_size()) and tex.get_format() == img.get_format():
		tex.update(img)
	else:
		sprite.texture = ImageTexture.create_from_image(img)
	# Le Sprite2D vit dans le repère logique (enfant d'AmbianceManager, sans transformation).
	sprite.global_position = bounds.position
	sprite.scale = Vector2(bounds.size.x / img.get_width(), bounds.size.y / img.get_height())


## Rastérise le masque d'ombre (thread-safe : aucune référence à l'arbre).
static func _rasterize(job: Dictionary) -> Image:
	var polys: Array[PackedVector2Array] = job["polys"]
	var bounds: Rect2 = job["bounds"]
	if polys.is_empty() or float(job["length_u"]) <= 0.01:
		return null
	var s := TEXEL_PX / SUPERSAMPLE
	var w := maxi(2, int(ceil(bounds.size.x / TEXEL_PX)) * SUPERSAMPLE)
	var h := maxi(2, int(ceil(bounds.size.y / TEXEL_PX)) * SUPERSAMPLE)
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	var dir: Vector2 = job["dir"]
	var len_px := float(job["length_u"]) * UNIT_PX
	var origin := bounds.position
	# Niveaux du plus long (le plus clair) au plus court (le plus sombre) : chaque passe écrase la
	# précédente avec une valeur plus forte -> équivaut à un maximum, même entre murs différents.
	for lv in LEVELS:
		var off: Vector2 = dir * len_px * float(lv[0])
		var c := Color(float(lv[1]), float(lv[1]), float(lv[1]))
		for poly in polys:
			var pts := PackedVector2Array()
			for v in poly:
				pts.append((v - origin) / s)
				pts.append((v + off - origin) / s)
			_fill_convex(img, Geometry2D.convex_hull(pts), c)
	# Le dessus des murs reste éclairé (l'ombre part du pied).
	for poly in polys:
		var pts2 := PackedVector2Array()
		for v in poly:
			pts2.append((v - origin) / s)
		_fill_convex(img, Geometry2D.convex_hull(pts2), Color.BLACK)
	# Réduction (moyenne 2 × 2) puis flou : demi-tailles successives et remontée bilinéaire.
	var fw := w / SUPERSAMPLE
	var fh := h / SUPERSAMPLE
	img.resize(fw, fh, Image.INTERPOLATE_BILINEAR)
	var smooth := float(job["smooth"])
	var halvings := 1 if smooth < 1.2 else (2 if smooth < 2.5 else 3)
	for i in halvings:
		img.resize(maxi(2, img.get_width() / 2), maxi(2, img.get_height() / 2), Image.INTERPOLATE_BILINEAR)
	img.resize(fw, fh, Image.INTERPOLATE_CUBIC)
	return img


## Remplit un polygone convexe (coordonnées en échantillons) ligne par ligne.
static func _fill_convex(img: Image, hull: PackedVector2Array, c: Color) -> void:
	var n := hull.size()
	if n < 3:
		return
	var y0 := 1.0e9
	var y1 := -1.0e9
	for v in hull:
		y0 = minf(y0, v.y)
		y1 = maxf(y1, v.y)
	var h := img.get_height()
	var w := img.get_width()
	var ya := clampi(int(ceil(y0 - 0.5)), 0, h)
	var yb := clampi(int(floor(y1 - 0.5)), -1, h - 1)
	for y in range(ya, yb + 1):
		var yc := y + 0.5
		var xmin := 1.0e9
		var xmax := -1.0e9
		for i in n:
			var a := hull[i]
			var b := hull[(i + 1) % n]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				var x := a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x)
				xmin = minf(xmin, x)
				xmax = maxf(xmax, x)
		if xmax < xmin:
			continue
		var xa := clampi(int(ceil(xmin - 0.5)), 0, w)
		var xb := clampi(int(floor(xmax - 0.5)), -1, w - 1)
		if xb >= xa:
			img.fill_rect(Rect2i(xa, y, xb - xa + 1, 1), c)


# --- Décalques <f>_shadow.png (props) ----------------------------------------------------------

func _build_decals() -> void:
	for c in decals.get_children():
		decals.remove_child(c)
		c.queue_free()
	if map == null:
		return
	_scan_decals(map)


func _scan_decals(n: Node) -> void:
	var spr := n as Sprite2D
	if spr != null and spr.texture != null:
		var path := spr.texture.resource_path
		if spr.texture is CanvasTexture:
			var d := (spr.texture as CanvasTexture).diffuse_texture
			path = d.resource_path if d != null else ""
		if path != "":
			var sp := path.get_basename() + "_shadow.png"
			if ResourceLoader.exists(sp) and spr.has_meta(&"shadow_decal_local") and map != null:
				# murs iso (StageMap) : décalque rig TOP, repère carte à 0,5, centré sur l'emprise
				var top := Sprite2D.new()
				top.texture = load(sp)
				top.light_mask = 0
				top.material = decal_material
				decals.add_child(top)
				top.global_transform = map.global_transform * (spr.get_meta(&"shadow_decal_local") as Transform2D)
			elif ResourceLoader.exists(sp):
				var dec := Sprite2D.new()
				dec.texture = load(sp)
				dec.centered = spr.centered
				dec.offset = spr.offset
				dec.flip_h = spr.flip_h
				dec.flip_v = spr.flip_v
				dec.region_enabled = spr.region_enabled
				dec.region_rect = spr.region_rect
				dec.hframes = spr.hframes
				dec.vframes = spr.vframes
				dec.frame = spr.frame
				dec.light_mask = 0
				dec.material = decal_material
				decals.add_child(dec)
				dec.global_transform = spr.global_transform
	for c in n.get_children():
		_scan_decals(c)
