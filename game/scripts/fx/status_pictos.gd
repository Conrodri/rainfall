class_name StatusPictos
extends RefCounted
## Pictogrammes de statut (16 px) des barres de vie des monstres de BASE (lot UX A11y-L1, WCAG 1.4.1 : la couleur
## ne porte plus seule le statut). UN SEUL atlas (5 cases de 16 px) partagé par toutes les barres : EnemyHealthBars
## les dessine en lot (draw_texture_rect_region, même texture = lot de dessin), aucun nœud par monstre.
## Silhouettes distinctes (lisibles sans couleur) : brûlure = flamme pointue, poison = bulles, gel = astérisque à
## 6 branches, étourdi = étoile à 4 pointes, emprisonné = cage. Cases blanches à contour sombre : la teinte vient de
## la couleur de dessin (palette daltonienne comprise).
## PLACEHOLDER temporaire généré en code ; remplacé par `assets/sprites/ui/hp_bars/status_mono_<id>.png` (blanc + contour
## sombre, 32²) dès que le lot Codex UXA11Y (art/tools/night/_uxa11y.txt) les livre.

const CELL := 16
const SUPER := 3 ## sur-échantillonnage du placeholder
const IDS: Array[StringName] = [&"burn", &"poison", &"frost", &"stun", &"imprisoned"] ## = HpBarStyle.STATUS_ORDER

static var _atlas: Texture2D = null


## Atlas 5×1 de cases CELL² (index = position dans IDS).
static func atlas() -> Texture2D:
	if _atlas == null:
		_atlas = ImageTexture.create_from_image(_build())
	return _atlas


static func clear_cache() -> void:
	_atlas = null


static func region(index: int) -> Rect2:
	return Rect2(index * CELL, 0, CELL, CELL)


## Vrai si TOUS les pictogrammes viennent d'assets livrés (sinon placeholder de code).
static func is_real() -> bool:
	for id in IDS:
		if HpBarStyle.tex("status_mono_" + String(id)) == null:
			return false
	return true


static func _build() -> Image:
	var atlas_img := Image.create(CELL * IDS.size(), CELL, false, Image.FORMAT_RGBA8)
	var real := is_real()
	for i in IDS.size():
		var cell: Image
		if real:
			cell = HpBarStyle.tex("status_mono_" + String(IDS[i])).get_image()
			cell.convert(Image.FORMAT_RGBA8)
			cell.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
		else:
			cell = _bake(IDS[i])
		atlas_img.blit_rect(cell, Rect2i(0, 0, CELL, CELL), Vector2i(i * CELL, 0))
	return atlas_img


## Case placeholder : remplissage blanc, contour sombre d'un pixel, glyphe centré avec marge.
static func _bake(id: StringName) -> Image:
	var n := CELL * SUPER
	var mask := PackedByteArray()
	mask.resize(n * n)
	for sy in n:
		for sx in n:
			var u := Vector2((sx + 0.5) / n * 2.0 - 1.0, (sy + 0.5) / n * 2.0 - 1.0) / 0.78
			mask[sy * n + sx] = 1 if _inside(id, u) else 0
	var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	for y in CELL:
		for x in CELL:
			var fill := 0
			var ring := 0
			for j in SUPER:
				for i in SUPER:
					var sx := x * SUPER + i
					var sy := y * SUPER + j
					if mask[sy * n + sx] == 1:
						fill += 1
					if _dilated(mask, n, sx, sy):
						ring += 1
			var total := float(SUPER * SUPER)
			var a := float(ring) / total
			if a <= 0.0:
				continue
			var v := float(fill) / maxf(float(ring), 1.0) # part du blanc dans la zone couverte
			img.set_pixel(x, y, Color(v, v, v, a))
	return img


static func _dilated(mask: PackedByteArray, n: int, sx: int, sy: int) -> bool:
	for dy in range(-SUPER, SUPER + 1, SUPER):
		for dx in range(-SUPER, SUPER + 1, SUPER):
			var x := sx + dx
			var y := sy + dy
			if x >= 0 and y >= 0 and x < n and y < n and mask[y * n + x] == 1:
				return true
	return false


const _FLAME := [Vector2(0.1, -1.0), Vector2(0.62, -0.3), Vector2(0.82, 0.3), Vector2(0.46, 0.92), Vector2(-0.46, 0.92),
		Vector2(-0.82, 0.3), Vector2(-0.52, -0.25), Vector2(-0.2, 0.05)]
const _STAR := [Vector2(0, -1), Vector2(0.28, -0.28), Vector2(1, 0), Vector2(0.28, 0.28), Vector2(0, 1), Vector2(-0.28, 0.28),
		Vector2(-1, 0), Vector2(-0.28, -0.28)]


## Le point `u` (repère [-1, 1], y vers le bas) est-il dans le glyphe `id` ?
static func _inside(id: StringName, u: Vector2) -> bool:
	match id:
		&"burn":
			return Geometry2D.is_point_in_polygon(u, PackedVector2Array(_FLAME))
		&"poison":
			return u.distance_to(Vector2(-0.2, 0.2)) < 0.55 or u.distance_to(Vector2(0.5, -0.4)) < 0.3 \
					or u.distance_to(Vector2(0.45, 0.5)) < 0.25
		&"frost":
			for k in 3:
				var d := Vector2.from_angle(PI * 0.5 + k * PI / 3.0)
				var along := u.dot(d)
				if absf(along) <= 1.0 and absf(u.cross(d)) < 0.15:
					return true
			return false
		&"stun":
			return Geometry2D.is_point_in_polygon(u, PackedVector2Array(_STAR))
		&"imprisoned":
			var ax := absf(u.x)
			var ay := absf(u.y)
			if ax > 0.92 or ay > 0.92:
				return false
			return ax > 0.72 or ay > 0.72 or ax < 0.1 or absf(ax - 0.4) < 0.1
	return false
