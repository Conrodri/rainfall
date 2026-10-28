class_name OccluderBuilder
extends RefCounted
## Génère des LightOccluder2D à partir des rectangles d'obstacles d'une StageMap (mêmes règles
## que StageMap._gather_rects : CollisionShape2D rectangulaires des StaticBody2D).
##
## L'eau profonde et le vide hors carte (StageMap.VOID_CHAR) sont aussi des obstacles de collision, mais ils
## ne doivent pas projeter d'ombre : si data/maps/<map_id>.json existe, un rectangle dont la majorité des cases
## de la grille est « ~ » ou vide est ignoré. Le bord de carte (murs « # » qui touchent le vide : remparts et
## falaises du contour organique, 28/10/2026) n'en projette pas non plus : les lumières sont toutes à l'intérieur,
## son ombre tomberait sur l'abîme. Un rectangle fait uniquement de bord, d'eau et de vide est ignoré. Les rectangles adjacents de même hauteur/largeur ne sont pas fusionnés
## (35 occluders au plus sur les cartes actuelles : coût négligeable).
## Repère (docs/Design_Isometrique.md §2.7) : rectangles en repère CARTE (StageMap.frame_of : Rot +45°
## en iso), occluders posés sous un parent qui porte cette rotation -> losanges au sol.

const MAPS_DIR := "res://data/maps/"
const OCCLUDER_GROUP := &"ambiance_occluder"
const DYNAMIC_GROUP := &"ambiance_dynamic_occluder"


## Rectangles (repère carte, alignés sur les axes) qui doivent projeter une ombre.
static func shadow_rects(map: Node2D) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	_gather(map, map, rects)
	var grid := _load_grid(map)
	if grid.is_empty():
		return rects
	var out: Array[Rect2] = []
	for r in rects:
		if not _no_shadow(r, grid):
			out.append(r)
	return out


## Construit (ou reconstruit) les occluders sous `parent`, alignés sur la carte.
## Retourne le nombre d'occluders créés.
static func build(map: Node2D, parent: Node2D, light_mask: int = 1) -> int:
	clear(parent)
	if map == null:
		return 0
	parent.global_transform = map.global_transform * StageMap.frame_of(map)
	var n := 0
	for r in shadow_rects(map):
		var poly := OccluderPolygon2D.new()
		poly.closed = true
		poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
		poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		var occ := LightOccluder2D.new()
		occ.name = "Occ%d" % n
		occ.occluder = poly
		occ.occluder_light_mask = light_mask
		occ.add_to_group(OCCLUDER_GROUP)
		parent.add_child(occ)
		n += 1
	return n


static func clear(parent: Node) -> void:
	for c in parent.get_children():
		if c is LightOccluder2D:
			parent.remove_child(c)
			c.queue_free()


static func _gather(map: Node2D, n: Node, out: Array[Rect2]) -> void:
	var inv := StageMap.frame_of(map).affine_inverse()
	if n is StaticBody2D:
		for c in n.get_children():
			var cs := c as CollisionShape2D
			if cs != null and cs.shape is RectangleShape2D and not cs.disabled:
				var sz: Vector2 = (cs.shape as RectangleShape2D).size
				var xf := inv * _local_xf(map, cs)
				var ext := Vector2(absf(xf.x.x) * sz.x + absf(xf.y.x) * sz.y, absf(xf.x.y) * sz.x + absf(xf.y.y) * sz.y)
				out.append(Rect2(xf.origin - ext * 0.5, ext))
	for c in n.get_children():
		_gather(map, c, out)


static func _local_xf(map: Node2D, n: Node2D) -> Transform2D:
	var xf := Transform2D.IDENTITY
	var cur: Node = n
	while cur != null and cur != map:
		if cur is Node2D:
			xf = (cur as Node2D).transform * xf
		cur = cur.get_parent()
	return xf


## {grid: PackedStringArray, cell_px: float, origin: Vector2 (coin haut-gauche en local)}
static func _load_grid(map: Node2D) -> Dictionary:
	var id := String(map.get_meta(&"map_id", ""))
	if id == "" or not FileAccess.file_exists(MAPS_DIR + id + ".json"):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(MAPS_DIR + id + ".json"))
	if typeof(data) != TYPE_DICTIONARY or not data.has("grid"):
		return {}
	var unit := float(data.get("unit_px", 64))
	var cell := float(data.get("grid_cell_u", 2)) * unit
	var size_u: Array = data.get("size_u", [0, 0])
	var origin := -Vector2(float(size_u[0]), float(size_u[1])) * unit * 0.5
	return {"grid": PackedStringArray(data["grid"]), "cell_px": cell, "origin": origin}


## Vrai si le rectangle est majoritairement eau / vide, ou entièrement fait de bord de carte, d'eau et de vide.
static func _no_shadow(r: Rect2, g: Dictionary) -> bool:
	var grid: PackedStringArray = g["grid"]
	var cell: float = g["cell_px"]
	var origin: Vector2 = g["origin"]
	var water := 0
	var rim := 0
	var total := 0
	var y := r.position.y + cell * 0.5
	while y < r.end.y:
		var x := r.position.x + cell * 0.5
		while x < r.end.x:
			var gx := int(floor((x - origin.x) / cell))
			var gy := int(floor((y - origin.y) / cell))
			if gy >= 0 and gy < grid.size() and gx >= 0 and gx < grid[gy].length():
				total += 1
				if grid[gy][gx] == "~" or grid[gy][gx] == StageMap.VOID_CHAR:
					water += 1
				elif grid[gy][gx] == "#" and _touches_void(grid, gx, gy):
					rim += 1
			x += cell
		y += cell
	return total > 0 and (water * 2 > total or water + rim == total)


## Case « # » dont un des 8 voisins est du vide (ou hors grille) : rempart ou falaise du contour.
static func _touches_void(grid: PackedStringArray, x: int, y: int) -> bool:
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if ny < 0 or ny >= grid.size() or nx < 0 or nx >= grid[ny].length() or grid[ny][nx] == StageMap.VOID_CHAR:
				return true
	return false


## Occluder dynamique attaché à une entité (boss, coffre, pilier), Direction §5 : boss dès le
## palier Moyen ; coffres et piliers en Haut ; jamais sur les monstres. `kind` : &"boss",
## &"chest", &"pillar". Le nœud créé suit le palier automatiquement (voir refresh_dynamic()).
static func attach_dynamic(node: Node2D, radius_px: float, kind: StringName) -> LightOccluder2D:
	var occ := node.get_node_or_null(^"AmbianceOccluder") as LightOccluder2D
	if occ == null:
		occ = LightOccluder2D.new()
		occ.name = "AmbianceOccluder"
		node.add_child(occ)
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(Vector2.from_angle(TAU * i / 8.0) * radius_px)
	var poly := OccluderPolygon2D.new()
	poly.polygon = pts
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder = poly
	occ.set_meta(&"kind", kind)
	occ.add_to_group(DYNAMIC_GROUP)
	occ.visible = dynamic_allowed(kind)
	return occ


static func dynamic_allowed(kind: StringName) -> bool:
	match StringName(Quality.get_setting(&"occluders")):
		&"all":
			return true
		&"obstacles":
			return kind == &"boss"
	return false


## Réapplique le palier à tous les occluders dynamiques (appelé par AmbianceManager).
static func refresh_dynamic(tree: SceneTree) -> void:
	for o in tree.get_nodes_in_group(DYNAMIC_GROUP):
		(o as CanvasItem).visible = dynamic_allowed(StringName(o.get_meta(&"kind", &"")))
