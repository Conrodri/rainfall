class_name CraneFx
extends Node2D
## Formes dessinées PROVISOIRES de la Grue (boss d'étage 3, Cité de rouille) tant que ses sprites Blender
## (Codex, art/tools/night/requests_bosses3.md#grue) ne sont pas livrés : chaque usage essaie d'abord l'anim
## du .tres et ne retombe ici qu'en son absence (CLAUDE.md : formes en code = placeholders temporaires).
## Non éclairées (light_mask 0, matériau unshaded) : rouille claire lisible dans le crépuscule d'orage,
## un seul accent émissif, l'orange de lampe au sodium #FF9A3C.
## Hauteurs en y logique (Iso.lift_logical : la caméra écrase y de moitié).

enum Kind { BODY, CONTAINER, SHADOW, ARC, BOOM }

const SODIUM := Color(1.0, 0.604, 0.235) ## #FF9A3C
const RUST := Color(0.62, 0.36, 0.24)
const STEEL := Color(0.46, 0.44, 0.42)

var kind := Kind.BODY
var color := RUST
var color2 := SODIUM
var size := 64.0 ## CONTAINER/SHADOW : demi-côté (px) ; ARC/BOOM : longueur
var width := 8.0 ## ARC/BOOM : largeur
var lift := 0.0 ## CONTAINER : hauteur de chute (y logique, négatif = en l'air) ; BODY : bras levé (0..1)
var progress := 0.0 ## BODY : flash de coup (0..1) ; SHADOW : opacité
var lamp := 1.0 ## CONTAINER / BODY : intensité de la lampe au sodium (0..1)
var boom_angle := 0.0 ## BODY : direction de la flèche au sol (rad)
var anchored := false ## BODY : patins d'ancrage déployés, flèche dressée (P3)
var seed_i := 0 ## ARC : variante de zigzag


static func make(p_kind: Kind, p_color: Color, p_z: int = 0) -> CraneFx:
	var f := CraneFx.new()
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
		Kind.CONTAINER:
			_container()
		Kind.SHADOW:
			var c := Color(0.02, 0.02, 0.03, 0.55 * clampf(progress, 0.0, 1.0))
			draw_colored_polygon(_square(size * (0.6 + 0.4 * progress)), c)
		Kind.ARC: # arc électrique vers +x : zigzag ambre, cœur blanc
			var pts := PackedVector2Array()
			var n := 9
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_i
			for i in n + 1:
				var k := float(i) / n
				var j := 0.0 if i == 0 or i == n else rng.randf_range(-1.0, 1.0) * width
				pts.append(Vector2(size * k, j))
			draw_polyline(pts, Color(color.r, color.g, color.b, 0.55), width * 0.55, true)
			draw_polyline(pts, Color(1.0, 0.95, 0.85, 0.95), maxf(width * 0.16, 2.0), true)
		Kind.BOOM: # ombre de la flèche au sol vers +x (lisible sous le liseré rouge du télégraphe)
			draw_rect(Rect2(0.0, -width * 0.5, size, width), Color(color.r, color.g, color.b, 0.5))
			for i in int(size / 48.0):
				var x := 24.0 + i * 48.0
				draw_line(Vector2(x, -width * 0.5), Vector2(x + 24.0, width * 0.5), Color(0.1, 0.06, 0.04, 0.6), 3.0)
			draw_circle(Vector2(size, 0.0), width * 0.35, color2)


## Carré au sol de demi-côté h, tourné de 45° (aligné sur la grille iso de la carte).
func _square(h: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 4:
		out.append(Vector2.from_angle(TAU * i / 4.0) * h * 1.4142)
	return out


## Conteneur de fret rivé : boîte de 2 u au sol, 1,4 u de haut, posée en losange (grille iso).
func _container() -> void:
	var foot := _square(size)
	var hh := Iso.lift_logical(1.4) # négatif (vers le haut)
	var top := PackedVector2Array()
	for p in foot:
		top.append(p + Vector2(0.0, hh + lift))
	var base := PackedVector2Array()
	for p in foot:
		base.append(p + Vector2(0.0, lift))
	# faces vues par la caméra (vers le bas de l'écran) : sud-est (0->1) et sud-ouest (1->2)
	var shade := [color.darkened(0.25), color.darkened(0.45)]
	for f in 2:
		var a := base[f]
		var b := base[f + 1]
		draw_colored_polygon(PackedVector2Array([a, b, top[f + 1], top[f]]), shade[f])
		for r in 4: # nervures de tôle ondulée
			var k := (r + 1) / 5.0
			var p0 := a.lerp(b, k)
			draw_line(p0, p0 + Vector2(0.0, hh), (shade[f] as Color).darkened(0.35), 2.0)
	draw_colored_polygon(top, color.lightened(0.12))
	draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), color.lightened(0.35), 2.0, true)
	# lampe au sodium sur l'angle avant (clignote avant que le conteneur ne disparaisse)
	var lp := top[1] + Vector2(0.0, -4.0)
	draw_circle(lp, 7.0, Color(color2.r, color2.g, color2.b, 0.25 * lamp))
	draw_circle(lp, 3.5, Color(color2.r, color2.g, color2.b, clampf(0.3 + 0.7 * lamp, 0.0, 1.0)))


## Silhouette provisoire de la Grue : automate-grue de 3,8 u sur chenilles, cabine à lampe au sodium, mât,
## flèche articulée orientée vers boom_angle (dressée et ancrée en phase 3), crochet au bout du câble.
func _body() -> void:
	var u := Balance.UNIT_PX
	var w := 1.0 * u
	var rust := color.lerp(Color.WHITE, progress * 0.7)
	var dark := rust.darkened(0.35)
	var steel := STEEL.lerp(Color.WHITE, progress * 0.7)
	# chenilles
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 1.1, 0.0), Vector2(w * 1.1, 0.0), Vector2(w * 0.95, Iso.lift_logical(0.5)),
		Vector2(-w * 0.95, Iso.lift_logical(0.5))]), steel.darkened(0.3))
	for i in 6:
		var x := -w + i * w * 0.4
		draw_line(Vector2(x, 0.0), Vector2(x + w * 0.1, Iso.lift_logical(0.5)), steel.darkened(0.55), 2.0)
	if anchored: # patins d'ancrage déployés en croix
		for s in [-1.0, 1.0]:
			draw_line(Vector2(s * w * 0.8, Iso.lift_logical(0.3)), Vector2(s * w * 1.9, u * 0.15), steel, 6.0)
			draw_colored_polygon(Transform2D(0.0, Vector2(s * w * 1.9, u * 0.15)) * _square(u * 0.22), steel.darkened(0.2))
	# caisse-moteur et cabine
	var y0 := Iso.lift_logical(0.5)
	var y1 := Iso.lift_logical(1.8)
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.85, y0), Vector2(w * 0.85, y0), Vector2(w * 0.7, y1), Vector2(-w * 0.75, y1)]), rust)
	draw_line(Vector2(-w * 0.85, y0), Vector2(-w * 0.75, y1), rust.lightened(0.3), 3.0) # liseré haut-gauche
	var cab := Rect2(Vector2(-w * 0.15, Iso.lift_logical(2.5)), Vector2(w * 0.8, y1 - Iso.lift_logical(2.5)))
	draw_rect(cab, dark)
	var win := Color(SODIUM.r, SODIUM.g, SODIUM.b, clampf(0.45 + 0.55 * lamp, 0.0, 1.0))
	draw_rect(Rect2(cab.position + Vector2(w * 0.1, cab.size.y * 0.15), Vector2(w * 0.55, cab.size.y * 0.35)), win) # vitre éclairée
	# mât
	var mast_top := Vector2(-w * 0.35, Iso.lift_logical(3.8))
	draw_line(Vector2(-w * 0.35, y1), mast_top, steel, 12.0)
	draw_line(Vector2(-w * 0.55, y1), mast_top, steel.darkened(0.2), 3.0)
	draw_line(Vector2(-w * 0.15, y1), mast_top, steel.darkened(0.2), 3.0)
	# flèche : au sol vers boom_angle (projetée), levée de 1,2 u ; dressée quand ancrée
	var d := Vector2.from_angle(boom_angle)
	var reach := 3.2 * u if not anchored else 1.2 * u
	var tip := mast_top + d * reach + Vector2(0.0, Iso.lift_logical(-0.6 if not anchored else 1.6))
	var pivot := Vector2(-w * 0.35, Iso.lift_logical(3.0))
	draw_line(pivot, tip, rust.lightened(0.1), 14.0)
	for i in 5: # treillis
		var k0 := i / 5.0
		var k1 := (i + 0.5) / 5.0
		draw_line(pivot.lerp(tip, k0), mast_top.lerp(tip, k1), dark, 2.0)
	draw_line(mast_top, tip, steel.darkened(0.25), 2.0) # hauban
	# câble + crochet
	var hook := tip + Vector2(0.0, -Iso.lift_logical(0.9 + 0.5 * lift))
	draw_line(tip, hook, steel.darkened(0.4), 2.0)
	draw_arc(hook + Vector2(0.0, 6.0), 8.0, 0.2, PI + 0.6, 10, steel.lightened(0.2), 4.0)
	# lampe au sodium au sommet du mât (l'accent unique)
	draw_circle(mast_top, 9.0, Color(SODIUM.r, SODIUM.g, SODIUM.b, 0.3 * lamp))
	draw_circle(mast_top, 4.5, Color(SODIUM.r, SODIUM.g, SODIUM.b, clampf(0.4 + 0.6 * lamp, 0.0, 1.0)))
	draw_arc(Vector2.ZERO, w * 1.15, 0.0, TAU, 24, Color(SODIUM.r, SODIUM.g, SODIUM.b, 0.3), 2.0) # pied
