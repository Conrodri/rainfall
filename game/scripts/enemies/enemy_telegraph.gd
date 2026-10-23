class_name EnemyTelegraph
extends Node2D
## Zone rouge au sol annonçant une attaque (règle de lisibilité : sorts à zone ≥ 0,8 s).
## top_level : placée en coordonnées monde (peut viser la position du joueur).
## Dessinée une fois au début de l'incantation ; la progression est l'échelle d'un enfant
## pré-dessiné (un cône ou un disque réduit depuis l'origine), donc aucun redessin par frame.
## Rendu : déplacée sous AmbianceManager.telegraph_layer (ni éclairée, ni étalonnée, sans glow),
## matériau unshaded et light_mask 0 ; libérée avec son monstre.

enum Shape { NONE, CONE, CIRCLE, LINE }

static var _unshaded: CanvasItemMaterial = null

## Lisibilité (audit A-04, 22/10/2026) : remplissage 0,28 ; double liseré = trait sombre extérieur + liseré
## clair intérieur (>= 3:1 sur tous les sols, protanopie comprise : l'un des deux contraste toujours) ;
## anneau de progression (même double trait) qui grossit jusqu'au bord à l'impact. Sert aussi à RecluseFx / SmelterFx.
const FILL := Color(0.95, 0.10, 0.10, 0.28)
const PROGRESS := Color(0.95, 0.10, 0.10, 0.35)
const EDGE_OUTER := Color(0.04, 0.02, 0.02, 1.0) ## liseré sombre
const EDGE_INNER := Color(1.0, 0.886, 0.784, 1.0) ## #FFE2C8, liseré clair
const EDGE_OUTER_PX := 6.0 ## trait sombre (dépasse de 2 px de chaque côté du clair)
const EDGE_INNER_PX := 2.0
const EDGE := EDGE_INNER ## compat : ancien nom
const RING_STEPS := 32.0 ## l'anneau n'est redessiné que tous les 1/32 de progression

## Télégraphes renforcés (A11y-L9, réglage accessibility/strong_telegraphs, défaut false). Même grammaire de formes
## (GroundShapes : « bord plein épais + remplissage progressif ») : liseré plus épais, remplissage plus opaque, et une
## MINUTERIE de bord (trait jaune pâle épais qui parcourt le contour de 0 à 100 % jusqu'à l'impact) pour lire la durée.
const STRONG_OUTER_PX := 12.0
const STRONG_INNER_PX := 5.0
const STRONG_FILL := Color(0.95, 0.10, 0.10, 0.40)
const STRONG_PROGRESS := Color(0.95, 0.10, 0.10, 0.50)
const GAUGE_COLOR := Color(1.0, 0.97, 0.70, 1.0) ## minuterie (>= 3:1 sur le liseré sombre, protanopie comprise)
const GAUGE_OUTER_PX := 18.0
const GAUGE_INNER_PX := 10.0
const STRONG_REFRESH_MS := 1000 ## relecture du réglage au plus une fois par seconde (pas de lecture disque par attaque)
static var strong_override := -1 ## tests / captures : -1 = réglage du joueur, 0 = normal, 1 = renforcé
static var _strong := false
static var _strong_ms := -1000000

var _shape := Shape.NONE
## true : reste dans le monde (z -1 : sur le sol, sous les corps) au lieu de la couche des télégraphes.
## DÉFAUT GÉNÉRIQUE : vrai pour tout télégraphe de boss / mini-boss (hôte non-Enemy = cerveau, zone ou
## fabrique de boss ; hôte Enemy = is_boss, mis à jour à chaque activation par Enemy._common_activate) ;
## faux pour les monstres normaux (couche des télégraphes). Aucun appel boss par boss nécessaire.
var in_world := false
var _world_host: Node = null
var _radius := 0.0
var _half_angle := 0.0
var _fill: _Fill
var _ring: _Ring
var _ring_step := -1
var _strong_on := false ## mode figé à l'affichage (remplissage, liseré et minuterie cohérents pendant l'incantation)


func _ready() -> void:
	top_level = true
	z_index = -1
	visible = false
	light_mask = 0
	material = unshaded_material()
	add_to_group(&"enemy_telegraphs") # indicateurs hors écran (OffscreenCues)
	_fill = _Fill.new()
	_fill.light_mask = 0
	_fill.use_parent_material = true
	add_child(_fill)
	_ring = _Ring.new()
	_ring.light_mask = 0
	_ring.use_parent_material = true
	_ring.visible = false
	add_child(_ring)
	_move_to_layer.call_deferred()


## Réglage « Télégraphes renforcés » (mis en cache STRONG_REFRESH_MS ; strong_override pour les tests).
static func strong() -> bool:
	if strong_override >= 0:
		return strong_override == 1
	var now := Time.get_ticks_msec()
	if now - _strong_ms >= STRONG_REFRESH_MS:
		_strong_ms = now
		_strong = GameSettings.strong_telegraphs()
	return _strong


## Force la relecture du réglage (le panneau de réglages peut l'appeler après la bascule).
static func refresh_strong() -> void:
	_strong_ms = -1000000


static func outer_px() -> float:
	return STRONG_OUTER_PX if strong() else EDGE_OUTER_PX


static func inner_px() -> float:
	return STRONG_INNER_PX if strong() else EDGE_INNER_PX


static func fill_color() -> Color:
	return STRONG_FILL if strong() else FILL


static func progress_color() -> Color:
	return STRONG_PROGRESS if strong() else PROGRESS


## Le télégraphe est-il affiché en ce moment ? (forme active et visible)
func is_showing() -> bool:
	return _shape != Shape.NONE and visible


## Rayon / longueur de la forme affichée (indicateurs hors écran).
func extent() -> float:
	return _radius


func is_strong() -> bool:
	return _strong_on


static func unshaded_material() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


## Passe sous la couche des télégraphes (coordonnées monde conservées : la couche suit la caméra).
func _move_to_layer() -> void:
	if not is_inside_tree():
		return
	if not in_world and is_boss_owned(get_parent()):
		in_world = true
	if in_world:
		return
	var layer := AmbianceManager.telegraph_layer(get_tree())
	var host := get_parent()
	if layer == null or host == layer:
		return
	_world_host = host
	reparent(layer, false)
	if host != null and not host.tree_exiting.is_connected(queue_free):
		host.tree_exiting.connect(queue_free)


## Un télégraphe appartient-il à un boss ? Hôte Enemy : is_boss (mini-boss compris) ; hôte CanvasLayer
## (déjà sur la couche) : non ; tout autre hôte (scène d'étage, cerveau, zone de boss) : oui, car seuls les
## cerveaux de boss et leurs zones créent des EnemyTelegraph hors d'un Enemy.
static func is_boss_owned(host: Node) -> bool:
	if host == null or host is CanvasLayer:
		return false
	if host is Enemy:
		return (host as Enemy).is_boss
	return true


## Bascule monde / couche des télégraphes (voir in_world). `host` : nœud du monde qui l'accueille
## (défaut : l'hôte d'origine, avant le passage sur la couche).
func set_in_world(on: bool, host: Node = null) -> void:
	if on == in_world and not (on and host != null):
		return
	in_world = on
	if not is_inside_tree():
		return
	if on:
		var h := host if host != null else _world_host
		if h != null and is_instance_valid(h) and get_parent() != h:
			reparent(h, false)
	else:
		_move_to_layer()


func show_cone(origin: Vector2, angle: float, radius: float, half_angle: float) -> void:
	_show(Shape.CONE, origin, angle, radius, half_angle)


func show_circle(center: Vector2, radius: float) -> void:
	_show(Shape.CIRCLE, center, 0.0, radius, 0.0)


## Ligne (charge) : rectangle de `length` px vers `angle`, `width` px de large, depuis `origin`.
## La largeur passe par le paramètre half_angle (réutilisé).
func show_line(origin: Vector2, angle: float, length: float, width: float) -> void:
	_show(Shape.LINE, origin, angle, length, width)


func _show(shape: Shape, pos: Vector2, angle: float, radius: float, half_angle: float) -> void:
	_shape = shape
	global_position = pos
	rotation = angle
	_radius = radius
	_half_angle = half_angle
	_strong_on = strong()
	_fill.strong_on = _strong_on
	_fill.setup(shape, radius, half_angle)
	_fill.scale = Vector2.ZERO
	_ring.setup(shape, radius, half_angle, _strong_on)
	_ring_step = -1
	_ring.visible = false
	visible = true
	queue_redraw()


func set_progress(p: float) -> void:
	var k := clampf(p, 0.0, 1.0)
	_fill.scale = Vector2(k, 1.0) if _shape == Shape.LINE else Vector2(k, k)
	var step := int(k * RING_STEPS)
	if step != _ring_step and _ring != null:
		_ring_step = step
		_ring.visible = (step > 0 or _strong_on) and _shape != Shape.NONE
		_ring.set_k(float(step) / RING_STEPS)


func hide_telegraph() -> void:
	_shape = Shape.NONE
	visible = false


func _draw() -> void:
	var prev := strong_override
	strong_override = 1 if _strong_on else 0 # liseré / remplissage du mode figé à l'affichage
	_draw_shape()
	strong_override = prev


func _draw_shape() -> void:
	match _shape:
		Shape.CIRCLE:
			draw_circle(Vector2.ZERO, _radius, fill_color())
		Shape.CONE:
			draw_colored_polygon(cone_points(_radius, _half_angle), fill_color())
		Shape.LINE:
			draw_rect(Rect2(0.0, -_half_angle * 0.5, _radius, _half_angle), fill_color())
	edge_shape(self, _shape, _radius, _half_angle, 1.0)


## Double liseré (sombre dessous, clair dessus) du contour de la forme réduite à `k` (1 = bord).
static func edge_shape(ci: CanvasItem, shape: int, radius: float, half_angle: float, k: float) -> void:
	match shape:
		Shape.CIRCLE:
			edge_arc(ci, Vector2.ZERO, radius * k, 0.0, TAU, 48)
		Shape.CONE:
			edge_polyline(ci, cone_points(radius * k, half_angle))
		Shape.LINE:
			var r := Rect2(0.0, -half_angle * 0.5, radius * k, half_angle)
			var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
				Vector2(r.position.x, r.end.y), r.position])
			edge_polyline(ci, pts)


static func edge_polyline(ci: CanvasItem, pts: PackedVector2Array) -> void:
	ci.draw_polyline(pts, EDGE_OUTER, outer_px())
	ci.draw_polyline(pts, EDGE_INNER, inner_px())


static func edge_arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, pts: int = 48) -> void:
	ci.draw_arc(c, r, a0, a1, pts, EDGE_OUTER, outer_px())
	ci.draw_arc(c, r, a0, a1, pts, EDGE_INNER, inner_px())


## Minuterie de bord (mode renforcé) : contour parcouru à `k` (0..1) depuis le haut (cercle), depuis un bord de l'arc
## (cône) ou le long des deux grands côtés (ligne). Trait sombre + trait jaune pâle épais.
static func gauge_shape(ci: CanvasItem, shape: int, radius: float, half_angle: float, k: float) -> void:
	if k <= 0.0:
		return
	match shape:
		Shape.CIRCLE:
			var a0 := -PI * 0.5
			var n := maxi(4, int(48.0 * k))
			ci.draw_arc(Vector2.ZERO, radius, a0, a0 + TAU * k, n, EDGE_OUTER, GAUGE_OUTER_PX)
			ci.draw_arc(Vector2.ZERO, radius, a0, a0 + TAU * k, n, GAUGE_COLOR, GAUGE_INNER_PX)
		Shape.CONE:
			var n2 := maxi(3, int(16.0 * k))
			var a1 := -half_angle + 2.0 * half_angle * k
			ci.draw_arc(Vector2.ZERO, radius, -half_angle, a1, n2, EDGE_OUTER, GAUGE_OUTER_PX)
			ci.draw_arc(Vector2.ZERO, radius, -half_angle, a1, n2, GAUGE_COLOR, GAUGE_INNER_PX)
		Shape.LINE:
			for y: float in [-half_angle * 0.5, half_angle * 0.5]:
				ci.draw_line(Vector2(0.0, y), Vector2(radius * k, y), EDGE_OUTER, GAUGE_OUTER_PX)
				ci.draw_line(Vector2(0.0, y), Vector2(radius * k, y), GAUGE_COLOR, GAUGE_INNER_PX)


## Luminance relative WCAG (sRGB) et contraste entre deux couleurs opaques.
static func luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func cone_points(r: float, half_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	const STEPS := 10
	for i in STEPS + 1:
		pts.append(Vector2.from_angle(-half_angle + 2.0 * half_angle * i / STEPS) * r)
	pts.append(Vector2.ZERO)
	return pts


class _Fill extends Node2D:
	var _shape := 0
	var _radius := 0.0
	var _half := 0.0

	func setup(shape: int, radius: float, half_angle: float) -> void:
		_shape = shape
		_radius = radius
		_half = half_angle
		queue_redraw()

	var strong_on := false

	func _draw() -> void:
		var col := EnemyTelegraph.STRONG_PROGRESS if strong_on else EnemyTelegraph.PROGRESS
		if _shape == EnemyTelegraph.Shape.CIRCLE:
			draw_circle(Vector2.ZERO, _radius, col)
		elif _shape == EnemyTelegraph.Shape.CONE:
			draw_colored_polygon(EnemyTelegraph.cone_points(_radius, _half), col)
		elif _shape == EnemyTelegraph.Shape.LINE:
			draw_rect(Rect2(0.0, -_half * 0.5, _radius, _half), col)


## Anneau de progression : contour de la forme à l'échelle k, double liseré (redessiné par paliers).
class _Ring extends Node2D:
	var _shape := 0
	var _radius := 0.0
	var _half := 0.0
	var _k := 0.0
	var _gauge := false

	func setup(shape: int, radius: float, half_angle: float, gauge := false) -> void:
		_shape = shape
		_radius = radius
		_half = half_angle
		_k = 0.0
		_gauge = gauge

	func set_k(k: float) -> void:
		_k = k
		queue_redraw()

	func _draw() -> void:
		var prev := EnemyTelegraph.strong_override
		EnemyTelegraph.strong_override = 1 if _gauge else 0
		if _k > 0.0:
			EnemyTelegraph.edge_shape(self, _shape, _radius, _half, _k)
		EnemyTelegraph.strong_override = prev
		if _gauge:
			EnemyTelegraph.gauge_shape(self, _shape, _radius, _half, _k)
