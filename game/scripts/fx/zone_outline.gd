class_name ZoneOutline
extends Node2D
## Contour des zones persistantes au sol des JOUEURS (demande du joueur, 26/10/2026) : même système que les flaques
## de poison des mini-boss (MiniBossBrain.add_zone -> RecluseFx DISC : remplissage + liseré de 2 px, couche des
## télégraphes non éclairée, plan de sol logique que la caméra iso écrase en ellipse 2:1), via RecluseFx.draw_disc.
## Différences voulues : couleur du SORT (pas de vert/rouge), voile léger (le rouge des alertes ennemies reste seul),
## fondu d'entrée / de sortie et pulsation lente (coupée au palier Bas : Quality `zone_pulse`).
##
## Coût : le disque n'est redessiné que si le rayon change (set_radius / track_radius) ; fondu et pulsation passent
## par `modulate.a`, aucune allocation par image. Un seul _process par contour (quelques zones à la fois).
## Cycle de vie : `life` > 0 = fondu de sortie programmé à `life` s ; l'hôte qui quitte l'arbre déclenche `release()`
## (fondu de sortie sur place). Les tests lisent `alpha_now()`, `is_releasing()`.

const FADE_IN_S := 0.12
const FADE_OUT_S := 0.4
const WIDTH := 2.0 ## épaisseur du liseré (px logiques), comme les flaques ennemies
const FILL_ALPHA := 0.07 ## voile léger de la couleur du sort (flaques ennemies : 0,12)
const EDGE_ALPHA := 0.8
const EDGE_LIGHTEN := 0.15 ## liseré à peine éclairci (les flaques ennemies : 0,4) : la teinte du sort reste lisible
const PULSE_AMP := 0.14
const PULSE_HZ := 1.1
const Z := -1 ## sous les corps, comme les flaques ennemies
const NAME := &"ZoneOutline"
const CAP_STEPS := 10 ## segments par demi-cercle de la capsule

enum Shape { DISC, CAPSULE, BAND } ## disque ; capsule autour d'un segment (lignes) ; anneau (bande)

const STRONG_WIDTH := 4.0 ## contour appuyé (emphasize) : zones de contrôle à lire d'un coup d'oeil
const STRONG_FILL := 0.16
const STRONG_EDGE := 1.0
const HALO_COLOR := Color(0.04, 0.03, 0.05, 0.6) ## liseré sombre sous le contour : lisible sur sol clair comme sombre
const HALO_EXTRA := 3.0

var shape := Shape.DISC
var width := WIDTH
var fill_alpha := FILL_ALPHA
var edge_alpha := EDGE_ALPHA
var halo := false
var radius := 64.0 ## DISC : rayon ; BAND : rayon extérieur ; CAPSULE : demi-largeur de la bande
var inner := 0.0 ## BAND : rayon intérieur
var color := Color.WHITE
var life := 0.0 ## > 0 : durée de vie programmée (s) ; 0 = jusqu'à release()
var host: Node2D = null
var radius_source := Callable() ## facultatif : renvoie le rayon courant (px) ; interrogé chaque image
var _age := 0.0
var _follow := false ## dans la couche des télégraphes : suit l'hôte (coordonnées monde)
var _releasing := false
var _out_t := 0.0
var _pulse_on := true
var _phase := 0.0
var end_node: Node2D = null ## CAPSULE : extrémité mobile (sinon `end_point`, monde)
var end_point := Vector2.ZERO
var _end_local := Vector2.ZERO ## extrémité dessinée (repère du contour), pour ne redessiner qu'au changement
var _poly := PackedVector2Array() ## contour de capsule, tableau réutilisé


## Pose un contour sous `p_host`. `p_life` : durée de la zone (s), 0 = jusqu'à la libération de l'hôte.
static func attach(p_host: Node2D, p_radius_px: float, p_color: Color, p_life := 0.0, p_shape := Shape.DISC) -> ZoneOutline:
	if p_host == null or not p_host.is_inside_tree():
		return null
	var f := ZoneOutline.new()
	f.name = NAME
	f.shape = p_shape
	f.host = p_host
	f.radius = p_radius_px
	f.color = Color(p_color.r, p_color.g, p_color.b, 1.0)
	f.life = p_life
	f.z_index = Z
	f.light_mask = 0
	f.material = EnemyTelegraph.unshaded_material()
	f.modulate.a = 0.0
	f._phase = fposmod(p_host.global_position.x * 0.013 + p_host.global_position.y * 0.007, 1.0) # zones voisines déphasées
	var layer: CanvasLayer = AmbianceManager.telegraph_layer(p_host.get_tree())
	if layer != null:
		layer.add_child(f)
		f.global_position = p_host.global_position
		f._follow = true
		p_host.tree_exiting.connect(f.release, CONNECT_ONE_SHOT)
	else:
		p_host.add_child(f) # repli (tests, scène sans ambiance, aperçu de la fiche) : local à l'hôte, libéré avec lui
		f.z_as_relative = false # sinon le z de l'hôte (-1) s'ajoute : le contour passait sous le sol et le VFX
	return f


## Contour en capsule (lignes : piquet, jalons) de demi-largeur `half_w_px` entre `p_host` et `p_end` (nœud mobile) ou
## `p_end_point` (monde, si `p_end` est null).
static func attach_capsule(p_host: Node2D, half_w_px: float, p_color: Color, p_life := 0.0, p_end: Node2D = null, p_end_point := Vector2.ZERO) -> ZoneOutline:
	var f := attach(p_host, half_w_px, p_color, p_life, Shape.CAPSULE)
	if f != null:
		f.end_node = p_end
		f.end_point = p_end_point
		f._sync_end()
	return f


## Contour en anneau (bande entre `r_in` et `r_out`) centré sur `p_host` (Cerceau).
static func attach_band(p_host: Node2D, r_out: float, r_in: float, p_color: Color, p_life := 0.0) -> ZoneOutline:
	var f := attach(p_host, r_out, p_color, p_life, Shape.BAND)
	if f != null:
		f.inner = r_in
		f.queue_redraw()
	return f


## Contour appuyé (Filet lesté, Grêle) : trait épais, voile plus net, liseré sombre. Renvoie `self`.
func emphasize() -> ZoneOutline:
	width = STRONG_WIDTH
	fill_alpha = STRONG_FILL
	edge_alpha = STRONG_EDGE
	halo = true
	queue_redraw()
	return self


## Contour d'un hôte (null sans contour).
static func of(p_host: Node) -> ZoneOutline:
	if p_host == null:
		return null
	for c in p_host.get_children():
		if c is ZoneOutline:
			return c
	var tree := p_host.get_tree()
	if tree != null:
		for n in tree.get_nodes_in_group(&"zone_outlines"):
			if n is ZoneOutline and (n as ZoneOutline).host == p_host:
				return n
	return null


## Couleur du contour d'un sort : champ du sort, sinon couleur du sort, sinon accent du personnage.
static func color_for(spell: SpellData, caster: Object = null) -> Color:
	if spell != null:
		if spell.zone_outline_color.a > 0.0:
			return spell.zone_outline_color
		if spell.color.a > 0.0:
			return spell.color
	if caster != null:
		var pl: Variant = caster.get(&"player")
		if pl is Object and (pl as Object).get(&"character") != null:
			var ch: Variant = (pl as Object).get(&"character")
			if ch is Object and (ch as Object).get(&"accent_color") != null:
				return (ch as Object).get(&"accent_color")
	return Color(0.9, 0.9, 0.9)


func _ready() -> void:
	add_to_group(&"zone_outlines")
	_pulse_on = bool(Quality.get_setting(&"zone_pulse"))
	if not Quality.quality_changed.is_connected(_on_quality):
		Quality.quality_changed.connect(_on_quality)
	queue_redraw()


func _on_quality(_t: int) -> void:
	_pulse_on = bool(Quality.get_setting(&"zone_pulse"))


func set_band(r_out: float, r_in: float) -> void:
	if absf(r_out - radius) > 0.5 or absf(r_in - inner) > 0.5:
		radius = r_out
		inner = r_in
		queue_redraw()


func _sync_end() -> void:
	var e := end_node.global_position if is_instance_valid(end_node) else end_point
	var l := e - global_position
	if l.distance_squared_to(_end_local) > 0.25 or _poly.is_empty():
		_end_local = l
		_build_capsule()
		queue_redraw()


## Contour fermé de la capsule dans `_poly` (taille fixe, remplie en place : aucune allocation après la première).
func _build_capsule() -> void:
	var n := 2 * (CAP_STEPS + 1)
	if _poly.size() != n + 1:
		_poly.resize(n + 1)
	var d := _end_local
	var ang := d.angle() if d.length_squared() > 0.01 else 0.0
	for i in CAP_STEPS + 1: # demi-cercle côté extrémité
		var a := ang - PI * 0.5 + PI * float(i) / CAP_STEPS
		_poly[i] = d + Vector2.from_angle(a) * radius
	for i in CAP_STEPS + 1: # demi-cercle côté hôte
		var a2 := ang + PI * 0.5 + PI * float(i) / CAP_STEPS
		_poly[CAP_STEPS + 1 + i] = Vector2.from_angle(a2) * radius
	_poly[n] = _poly[0]


func set_radius(r: float) -> void:
	if absf(r - radius) > 0.5:
		radius = r
		queue_redraw()


## Fondu de sortie sur place (hôte libéré, zone close). Idempotent.
func release() -> void:
	if _releasing:
		return
	_releasing = true
	_follow = false
	_out_t = 0.0


func is_releasing() -> bool:
	return _releasing


func alpha_now() -> float:
	return modulate.a


## Avance d'une image (public pour les tests sans boucle de rendu).
func step(delta: float) -> void:
	_age += delta
	if _follow:
		if is_instance_valid(host):
			if global_position != host.global_position:
				global_position = host.global_position
		elif not _releasing:
			release()
	if radius_source.is_valid():
		set_radius(float(radius_source.call()))
	if shape == Shape.CAPSULE:
		_sync_end()
	if life > 0.0 and not _releasing and _age >= life - FADE_OUT_S:
		release()
	var a := clampf(_age / FADE_IN_S, 0.0, 1.0)
	if _releasing:
		_out_t += delta
		a = minf(a, clampf(1.0 - _out_t / FADE_OUT_S, 0.0, 1.0))
		if _out_t >= FADE_OUT_S:
			queue_free()
	elif _pulse_on:
		a *= 1.0 - PULSE_AMP * 0.5 * (1.0 + sin(TAU * (_age * PULSE_HZ + _phase)))
	modulate.a = a


func _process(delta: float) -> void:
	step(delta)


func _draw() -> void:
	var edge := Color(color.r, color.g, color.b, 1.0).lightened(EDGE_LIGHTEN)
	edge.a = edge_alpha
	var fill := Color(color.r, color.g, color.b, fill_alpha)
	match shape:
		Shape.CAPSULE:
			if _poly.size() > 3:
				draw_colored_polygon(_poly, fill)
				if halo:
					draw_polyline(_poly, HALO_COLOR, width + HALO_EXTRA, true)
				draw_polyline(_poly, edge, width, true)
		Shape.BAND:
			var mid := (radius + inner) * 0.5
			draw_arc(Vector2.ZERO, mid, 0.0, TAU, 72, fill, maxf(radius - inner, 1.0))
			if halo:
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, HALO_COLOR, width + HALO_EXTRA, true)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, edge, width, true)
			if inner > 1.0:
				if halo:
					draw_arc(Vector2.ZERO, inner, 0.0, TAU, 72, HALO_COLOR, width + HALO_EXTRA, true)
				draw_arc(Vector2.ZERO, inner, 0.0, TAU, 72, edge, width, true)
		_:
			if halo:
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, HALO_COLOR, width + HALO_EXTRA, true)
			RecluseFx.draw_disc(self, radius, fill, edge, width)
