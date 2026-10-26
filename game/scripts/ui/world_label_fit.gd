extends RefCounted
## Étiquette du monde (Label enfant d'un nœud 2D, ex. prix d'un coffre) gardée lisible : entièrement dans la vue
## (bords ou zone sûre de l'écran) et hors des zones réservées du HUD (Hud.reserved_rects). Hors de la vue ou sans
## place dégagée : masquée. Appelé chaque image par le propriétaire de l'étiquette.

const EDGE := 8.0 ## marge au bord de la vue (px écran)
const GAP := 6.0 ## marge autour d'une zone réservée


## `home` : position locale d'origine de l'étiquette (dans son parent). Retourne true si elle est affichée.
static func fit(label: Control, home: Vector2) -> bool:
	var parent := label.get_parent() as CanvasItem
	if parent == null or not label.is_inside_tree():
		return true
	label.position = home
	var vp := label.get_viewport()
	var view := vp.get_visible_rect()
	var pxf := parent.get_global_transform_with_canvas()
	var box := _box(label)
	if not box.intersects(view):
		return false
	var safe := view.grow(-EDGE)
	var hud := label.get_tree().get_first_node_in_group(&"hud")
	var rects: Array = hud.call(&"reserved_rects") if hud != null and hud.has_method(&"reserved_rects") else []
	var shift := Vector2.ZERO
	for _pass in 4:
		box = _box(label, shift)
		shift += _clamp_shift(box, safe)
		box = _box(label, shift)
		var moved := false
		for r: Rect2 in rects:
			var rr := r.grow(GAP)
			if not rr.intersects(box):
				continue
			var best := Vector2.ZERO
			var best_len := INF
			for o: Vector2 in [Vector2(rr.end.x - box.position.x, 0.0), Vector2(-(box.end.x - rr.position.x), 0.0),
					Vector2(0.0, rr.end.y - box.position.y), Vector2(0.0, -(box.end.y - rr.position.y))]:
				if safe.encloses(Rect2(box.position + o, box.size)) and o.length() < best_len:
					best_len = o.length()
					best = o
			if best_len == INF:
				return false
			shift += best
			box = _box(label, shift)
			moved = true
		if not moved:
			break
	for r: Rect2 in rects:
		if r.intersects(box):
			return false
	label.position = home + pxf.affine_inverse().basis_xform(shift)
	return true


## Rect écran du texte (largeur = max(taille, minimum), centré), décalé de `shift` px écran.
static func _box(label: Control, shift := Vector2.ZERO) -> Rect2:
	var ms := label.get_minimum_size()
	var w := maxf(label.size.x, ms.x)
	var h := maxf(label.size.y, ms.y)
	var r := label.get_global_transform_with_canvas() * Rect2(Vector2((label.size.x - w) * 0.5, 0.0), Vector2(w, h))
	r.position += shift
	return r


static func _clamp_shift(box: Rect2, safe: Rect2) -> Vector2:
	var d := Vector2.ZERO
	if box.size.x > safe.size.x or box.size.y > safe.size.y:
		return d
	if box.position.x < safe.position.x:
		d.x = safe.position.x - box.position.x
	elif box.end.x > safe.end.x:
		d.x = safe.end.x - box.end.x
	if box.position.y < safe.position.y:
		d.y = safe.position.y - box.position.y
	elif box.end.y > safe.end.y:
		d.y = safe.end.y - box.end.y
	return d
