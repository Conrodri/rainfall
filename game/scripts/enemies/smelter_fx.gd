class_name SmelterFx
extends Node2D
## Formes dessinées PROVISOIRES du Fondeur (boss d'étage 3, Cité de rouille) tant que ses sprites Blender
## (Codex, art/tools/night/requests_bosses3.md#fondeur) ne sont pas livrés : chaque usage essaie d'abord
## l'anim du .tres et ne retombe ici qu'en son absence (CLAUDE.md : formes en code = placeholders temporaires).
## Non éclairées (light_mask 0, matériau unshaded) ; accent unique : métal en fusion orange sodium #FF9A3C.

enum Kind { BODY, POOL, RING, PUFF }

const SODIUM := Color(1.0, 0.604, 0.235) ## #FF9A3C
const IRON := Color(0.52, 0.40, 0.33)
const TELE_FILL := EnemyTelegraph.FILL
const TELE_PROGRESS := EnemyTelegraph.PROGRESS

var kind := Kind.BODY
var color := IRON
var color2 := SODIUM
var size := 64.0 ## POOL : longueur ; RING : rayon médian ; PUFF : rayon
var width := 64.0 ## POOL : largeur ; RING : épaisseur de la bande
var gaps: Array = [] ## RING : angles des brèches (rad)
var gap_half := 0.4 ## RING : demi-angle d'une brèche
var tele := false ## RING : style d'alerte (rouge réservé) au lieu du métal
var progress := 0.0 ## BODY : flash de coup ; RING (alerte) : remplissage ; POOL : refroidissement (0 chaud .. 1 croûte)
var heat := 0.0 ## BODY : surchauffe (P3) ; POOL/RING : électrisé (éclair imminent)
var tilt := 0.0 ## BODY : creuset penché (0..1, coulée)


static func make(p_kind: Kind, p_color: Color, p_z: int = 0) -> SmelterFx:
	var f := SmelterFx.new()
	f.kind = p_kind
	f.color = p_color
	f.z_index = p_z
	f.light_mask = 0
	f.material = EnemyTelegraph.unshaded_material()
	return f


func _draw() -> void:
	match kind:
		Kind.BODY:
			_body()
		Kind.POOL:
			_pool()
		Kind.RING:
			_ring()
		Kind.PUFF:
			for i in 5:
				var a := TAU * i / 5.0 + size * 0.01
				draw_circle(Vector2.from_angle(a) * size * 0.45, size * 0.55, Color(color.r, color.g, color.b, 0.35))
			draw_circle(Vector2.ZERO, size * 0.5, Color(1, 1, 1, 0.3))


## Coulée au sol vers +x : bord de croûte sombre, cœur orange qui pâlit en refroidissant ; blanchit si électrisée.
func _pool() -> void:
	var w := width
	var hot := SODIUM.lerp(Color(0.45, 0.2, 0.1), clampf(progress, 0.0, 1.0) * 0.6)
	hot = hot.lerp(Color(1.0, 0.95, 0.8), clampf(heat, 0.0, 1.0))
	var crust := Color(0.16, 0.10, 0.08, 0.85)
	var pts := PackedVector2Array()
	var n := 10
	for i in n + 1: # bord supérieur ondulé
		var x := size * i / n
		pts.append(Vector2(x, -w * (0.5 - 0.08 * sin(i * 1.7))))
	for i in range(n, -1, -1):
		var x := size * i / n
		pts.append(Vector2(x, w * (0.5 - 0.08 * cos(i * 1.3))))
	draw_colored_polygon(pts, crust)
	var core := PackedVector2Array()
	for p in pts:
		core.append(Vector2(clampf(p.x, size * 0.04, size * 0.97), p.y * 0.62))
	draw_colored_polygon(core, Color(hot.r, hot.g, hot.b, 0.92))
	draw_line(Vector2(size * 0.05, 0.0), Vector2(size * 0.95, 0.0), Color(1.0, 0.9, 0.6, 0.6 + 0.4 * heat), maxf(w * 0.08, 2.0), true)


## Anneau (bande size ± width/2) interrompu par les brèches ; style alerte ou métal en fusion.
func _ring() -> void:
	var r := size
	var segs := _segments()
	for s in segs:
		var a0: float = s[0]
		var a1: float = s[1]
		var pts := maxi(int((a1 - a0) * 24.0), 4)
		if tele:
			draw_arc(Vector2.ZERO, r, a0, a1, pts, TELE_FILL, width)
			var w_fill := width * clampf(progress, 0.0, 1.0)
			if w_fill > 0.5:
				draw_arc(Vector2.ZERO, r - width * 0.5 + w_fill * 0.5, a0, a1, pts, TELE_PROGRESS, w_fill)
			EnemyTelegraph.edge_arc(self, Vector2.ZERO, r + width * 0.5, a0, a1, pts)
			EnemyTelegraph.edge_arc(self, Vector2.ZERO, r - width * 0.5, a0, a1, pts)
			if w_fill > 0.5 and w_fill < width - 1.0:
				EnemyTelegraph.edge_arc(self, Vector2.ZERO, r - width * 0.5 + w_fill, a0, a1, pts) # anneau de progression
		else:
			var hot := SODIUM.lerp(Color(1.0, 0.95, 0.8), clampf(heat, 0.0, 1.0))
			draw_arc(Vector2.ZERO, r, a0, a1, pts, Color(0.16, 0.10, 0.08, 0.85), width)
			draw_arc(Vector2.ZERO, r, a0, a1, pts, Color(hot.r, hot.g, hot.b, 0.9), width * 0.6)
			draw_arc(Vector2.ZERO, r, a0, a1, pts, Color(1.0, 0.9, 0.6, 0.7), maxf(width * 0.08, 2.0))


func _segments() -> Array:
	if gaps.is_empty():
		return [[0.0, TAU]]
	var gs: Array = []
	for g in gaps:
		gs.append(fposmod(float(g), TAU))
	gs.sort()
	var out: Array = []
	for i in gs.size():
		var a0: float = gs[i] + gap_half
		var a1: float = (gs[(i + 1) % gs.size()] if i + 1 < gs.size() else gs[0] + TAU) - gap_half
		if a1 > a0:
			out.append([a0, a1])
	return out


## Silhouette provisoire du Fondeur : automate-forge trapu (3,5 u), creuset ouvert à la place du torse
## (métal orange, seul accent), bras-louches, cheminée ; surchauffe = fonte rougie, creuset blanc.
func _body() -> void:
	var u := Balance.UNIT_PX
	var w := 1.0 * u
	var iron := color.lerp(Color(0.85, 0.35, 0.2), clampf(heat, 0.0, 1.0) * 0.45).lerp(Color.WHITE, progress * 0.7)
	var dark := iron.darkened(0.35)
	# jambes courtes
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(s * w * 0.25, 0.0), Vector2(s * w * 0.75, 0.0),
			Vector2(s * w * 0.65, Iso.lift_logical(1.0)), Vector2(s * w * 0.3, Iso.lift_logical(1.0))]), dark)
	# bassin + creuset (bol évasé)
	var yb := Iso.lift_logical(1.0)
	var yt := Iso.lift_logical(2.7)
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.7, yb), Vector2(w * 0.7, yb), Vector2(w * 1.05, yt), Vector2(-w * 1.05, yt)]), iron)
	draw_line(Vector2(-w * 0.7, yb), Vector2(-w * 1.05, yt), iron.lightened(0.35), 3.0) # liseré haut-gauche
	for i in 3: # cerclages rivetés
		var y := lerpf(yb, yt, (i + 1) / 4.0)
		var hw := lerpf(0.7, 1.05, (i + 1) / 4.0) * w
		draw_line(Vector2(-hw, y), Vector2(hw, y), dark, 3.0)
	# bouche du creuset (ellipse vue en iso), penchée vers l'avant pendant la coulée
	var mouth := Vector2(0.0, yt + tilt * u * 0.2)
	var hot := SODIUM.lerp(Color(1.0, 0.97, 0.85), clampf(heat, 0.0, 1.0) * 0.8)
	draw_set_transform(mouth, -0.25 * tilt, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, w * 1.0, dark)
	draw_circle(Vector2.ZERO, w * 0.85, hot)
	draw_circle(Vector2(-w * 0.2, -w * 0.1), w * 0.35, Color(1.0, 0.95, 0.75, 0.8))
	draw_set_transform(Vector2.ZERO)
	# cheminée (évent arrière)
	draw_rect(Rect2(Vector2(w * 0.45, Iso.lift_logical(3.5)), Vector2(w * 0.3, yt - Iso.lift_logical(3.5))), dark)
	# bras-louches
	for s in [-1.0, 1.0]:
		var sh := Vector2(s * w * 1.0, Iso.lift_logical(2.3))
		var hand := Vector2(s * w * 1.6, Iso.lift_logical(1.2 + 0.6 * tilt))
		draw_line(sh, hand, iron.darkened(0.15), 8.0)
		draw_set_transform(hand + Vector2(0.0, 6.0), 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, w * 0.32, dark)
		draw_circle(Vector2.ZERO, w * 0.2, Color(hot.r, hot.g, hot.b, 0.85))
		draw_set_transform(Vector2.ZERO)
	draw_arc(Vector2.ZERO, w * 1.1, 0.0, TAU, 24, Color(SODIUM.r, SODIUM.g, SODIUM.b, 0.35), 2.0) # pied
