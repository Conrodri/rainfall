class_name WeaverFx
extends Node2D
## Formes dessinées PROVISOIRES des boss alternatifs de l'étage 2 (Forêt-brume) : la Tisseuse (`weaver`) et
## le Cèdre-Ermite (`hermit_cedar`), tant que leurs sprites Blender (lots Codex N2c / N2d,
## art/tools/night/requests_bosses2.md) ne sont pas livrés. Chaque usage essaie d'abord l'anim du .tres du
## boss et ne retombe ici qu'en son absence (CLAUDE.md : formes en code = placeholders temporaires).
## DA forêt : brume #B8C8C0, accent feu follet menthe #9CF0C8 ; corps jamais presque noirs (leçon du Sonneur).
## Non éclairées (light_mask 0, unshaded) : lisibles sous la canopée de l'aube bleue, comme les télégraphes.
## Un seul nœud par effet, redessiné seulement quand un paramètre change.

enum Kind { THREAD, WEB, COCOON, STUMP, ROOT, SPORES, BODY_WEAVER, BODY_CEDAR, SILK_DROP }

const MIST := Color(0.722, 0.784, 0.753) ## #B8C8C0
const MINT := Color(0.612, 0.941, 0.784) ## #9CF0C8
const VS := 2.0 ## Iso.UNSQUASH.y : le sol logique est écrasé de moitié à l'écran, les hauteurs se dessinent ×2

var kind := Kind.THREAD
var radius := 64.0 ## THREAD/ROOT/SILK_DROP : longueur ; WEB/COCOON/STUMP/SPORES : rayon (px logiques)
var width := 6.0
var color := Color.WHITE
var color2 := MINT ## liseré / lanterne
var progress := 0.0 ## BODY_* : flash de coup ; ROOT : jaillissement (0..1) ; COCOON : éclosion
var lift := 0.0 ## BODY_* : hauteur (px logiques, négatif = vers le haut)
var glow := 1.0 ## BODY_* : intensité de la lanterne ; THREAD/WEB : vibration (flash menthe)
var gaps: PackedFloat32Array = PackedFloat32Array() ## WEB : angles des brèches
var gap_half := 0.4 ## WEB : demi-ouverture d'une brèche (rad)
var seed_i := 0
var dir := Vector2.RIGHT ## ROOT : direction de la ligne (le nœud n'est pas tourné : épines verticales à l'écran)


static func make(p_kind: Kind, p_color: Color, p_z: int = 0) -> WeaverFx:
	var f := WeaverFx.new()
	f.kind = p_kind
	f.color = p_color
	f.z_index = p_z
	f.light_mask = 0
	f.material = EnemyTelegraph.unshaded_material()
	f.seed_i = randi() % 997
	return f


func set_glow(g: float) -> void:
	if absf(g - glow) > 0.02:
		glow = g
		queue_redraw()


func set_progress(p: float) -> void:
	if absf(p - progress) > 0.01:
		progress = p
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.THREAD: # fil de soie tendu vers +x : halo brumeux, âme claire, perles de rosée menthe
			var c := color.lerp(MINT, clampf(glow - 1.0, 0.0, 1.0))
			draw_line(Vector2.ZERO, Vector2(radius, 0.0), Color(c.r, c.g, c.b, c.a * 0.10), width * 1.6, true) # voile de soie
			for k in [-1.0, 0.0, 1.0]: # 3 brins tressés qui se croisent
				var pts := PackedVector2Array()
				var n2 := maxi(int(radius / 24.0), 2)
				for i in n2 + 1:
					var x := radius * i / n2
					pts.append(Vector2(x, k * width * 0.28 * sin(x * 0.045 + k * 1.7)))
				draw_polyline(pts, Color(c.r, c.g, c.b, c.a * (0.95 if k == 0.0 else 0.55)), 2.0 if k == 0.0 else 1.2, true)
			var n := int(radius / 40.0)
			for i in n: # perles de rosée menthe
				var x := (i + 0.5) * radius / n
				draw_circle(Vector2(x, 0.0), 2.6, Color(MINT.r, MINT.g, MINT.b, 0.85 * c.a))
		Kind.WEB: # anneau de fils à brèches, rayons d'ancrage vers l'intérieur
			var c := color.lerp(MINT, clampf(glow - 1.0, 0.0, 1.0))
			var segs := 72
			for i in segs:
				var a0 := TAU * i / segs
				var a1 := TAU * (i + 1) / segs
				if _in_gap((a0 + a1) * 0.5):
					continue
				for k in 3: # 3 brins concentriques
					var r := radius - width * 0.9 + k * width * 0.9
					draw_line(Vector2.from_angle(a0) * r, Vector2.from_angle(a1) * r, Color(c.r, c.g, c.b, c.a * (0.55 if k != 1 else 1.0)), 2.0 if k != 1 else 3.0, true)
				if i % 6 == 0:
					draw_line(Vector2.from_angle(a0) * (radius - width * 1.6), Vector2.from_angle(a0) * (radius + width * 1.6), Color(c.r, c.g, c.b, c.a * 0.6), 1.5, true)
			for g in gaps: # bornes lumineuses aux brèches : on lit le passage de loin
				for s in [-1.0, 1.0]:
					var p := Vector2.from_angle(g + s * gap_half) * radius
					draw_circle(p, 6.0, Color(MINT.r, MINT.g, MINT.b, 0.9 * c.a))
		Kind.COCOON: # cocon de soie gris-brume, cœur menthe qui pulse avant l'éclosion
			var r := radius
			var pts := PackedVector2Array()
			var hy := r * 1.1 * VS # cocon debout, un peu penché, qui palpite avant l'éclosion
			var sw := 1.0 + 0.08 * progress * sin(Time.get_ticks_msec() * 0.02)
			draw_circle(Vector2.ZERO, r * 0.95, Color(0.05, 0.07, 0.06, 0.45)) # ombre de contact
			for i in 20:
				var a := TAU * i / 20.0
				pts.append(Vector2(cos(a) * r * 0.62 * sw + sin(a) * r * 0.1, sin(a) * hy * 0.5 - hy * 0.5))
			draw_colored_polygon(pts, color.lerp(Color.WHITE, progress * 0.25))
			for k in 5: # soie enroulée
				var y := -hy * (0.12 + 0.18 * k)
				draw_line(Vector2(-r * 0.6, y + 4.0), Vector2(r * 0.6, y - 6.0), color.darkened(0.35), 1.5, true)
			draw_circle(Vector2(0.0, -hy * 0.5), r * (0.16 + 0.24 * progress), Color(MINT.r, MINT.g, MINT.b, 0.45 + 0.55 * progress))
			draw_line(Vector2(0.0, -hy), Vector2(r * 0.2, -hy - 16.0), Color(MIST.r, MIST.g, MIST.b, 0.8), 1.5, true) # fil d'attache
		Kind.STUMP: # souche fendue, sève menthe dans la fente
			var r := radius
			var h := r * 0.9 * VS
			draw_circle(Vector2.ZERO, r * 1.05, Color(0.05, 0.07, 0.06, 0.45)) # ombre de contact
			for s in [-1.0, 1.0]: # racines étalées
				draw_line(Vector2(s * r * 0.5, -2.0), Vector2(s * r * 1.15, r * 0.25), color.darkened(0.2), 5.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.8, 0.0), Vector2(r * 0.8, 0.0), Vector2(r * 0.7, -h * 0.85),
				Vector2(r * 0.25, -h), Vector2(-r * 0.3, -h * 0.9), Vector2(-r * 0.72, -h * 0.8)]), color)
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.72, -h * 0.8), Vector2(-r * 0.3, -h * 0.9), Vector2(r * 0.25, -h),
				Vector2(r * 0.7, -h * 0.85), Vector2(r * 0.1, -h * 0.68)]), color.lightened(0.2)) # coupe fraîche
			draw_line(Vector2(0.0, -h * 0.1), Vector2(r * 0.08, -h * 0.92), Color(MINT.r, MINT.g, MINT.b, 0.85), 3.0, true) # sève menthe
		Kind.ROOT: # racine qui jaillit le long de +x : épines qui montent avec `progress`
			var h := 34.0 * VS * clampf(progress, 0.0, 1.0)
			var n := maxi(int(radius / 30.0), 2)
			var side := dir.orthogonal() * width * 0.35
			draw_line(Vector2.ZERO, dir * radius, color.darkened(0.3), width * 0.45, true) # sol fendu
			for i in n:
				var b := dir * (i + 0.5) * radius / n + side * sin(float(i * 5 + seed_i))
				var hh := h * (0.55 + 0.45 * absf(sin(float(i * 7 + seed_i))))
				var tip := b + Vector2(dir.x * 6.0, -hh)
				draw_colored_polygon(PackedVector2Array([b - Vector2(9.0, 0.0), b + Vector2(9.0, 0.0), tip]), color)
				draw_line(b + Vector2(-2.0, -hh * 0.15), tip, color.lightened(0.25), 2.0, true)
				draw_line(b + Vector2(1.0, -hh * 0.2), b.lerp(tip, 0.8), Color(MINT.r, MINT.g, MINT.b, 0.5), 1.5, true)
		Kind.SPORES: # nuage de spores : bulles brume teintées menthe, densité = `glow`
			for i in 14:
				var a := float(i * 2.39996 + seed_i)
				var d := radius * sqrt(float(i) / 14.0) * 0.85
				var p := Vector2.from_angle(a) * d
				var br := radius * (0.28 + 0.1 * sin(a * 3.0))
				var c := MIST.lerp(MINT, 0.35 + 0.25 * sin(a))
				c.a = 0.22 * glow
				draw_circle(p, br, c)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(MINT.r, MINT.g, MINT.b, 0.45 * glow), 2.0, true)
		Kind.SILK_DROP: # fil vertical qui descend de la canopée (descente de la Tisseuse) ; radius = hauteur
			draw_line(Vector2(0.0, -radius), Vector2.ZERO, Color(MIST.r, MIST.g, MIST.b, 0.85), 2.0, true)
			draw_line(Vector2(0.0, -radius), Vector2.ZERO, Color(MINT.r, MINT.g, MINT.b, 0.25), 6.0, true)
		Kind.BODY_WEAVER:
			_body_weaver()
		Kind.BODY_CEDAR:
			_body_cedar()


func _in_gap(a: float) -> bool:
	for g in gaps:
		if absf(angle_difference(a, g)) < gap_half:
			return true
	return false


## Silhouette provisoire de la Tisseuse : araignée-sanctuaire 3,3 u, 8 pattes de bois clair usé, abdomen
## = lanterne fêlée menthe (accent unique) ; `lift` : hissée dans la canopée.
func _body_weaver() -> void:
	var w := 1.15 * Balance.UNIT_PX
	var hb := -Iso.lift_logical(1.5) # hauteur du corps (sur ses pattes)
	var wood := color.lerp(Color.WHITE, progress * 0.7)
	draw_set_transform(Vector2(0.0, lift))
	for s in [-1.0, 1.0]:
		for k in 4: # pattes : genou haut, pointe au sol
			var a := deg_to_rad(-35.0 + k * 26.0)
			var hip := Vector2(s * w * 0.25, -hb * 0.95 + k * 4.0)
			var knee := Vector2(s * w * (0.9 + 0.12 * k), -hb * 1.55 + absf(a) * 10.0)
			var foot := Vector2(s * w * (1.35 + 0.1 * k), (k - 1.5) * w * 0.22)
			draw_line(hip, knee, wood, 7.0, true)
			draw_line(knee, foot, wood.darkened(0.15), 5.0, true)
			draw_circle(knee, 4.0, wood.lightened(0.2))
	draw_circle(Vector2(0.0, -hb * 1.0), w * 0.32, wood.lightened(0.08)) # céphalothorax
	for i in 4: # yeux menthe
		draw_circle(Vector2((i - 1.5) * w * 0.1, -hb * 1.0 - w * 0.12), 2.5, color2)
	var lc := color2
	lc.a = clampf(0.5 + 0.5 * glow, 0.0, 1.0)
	var ab := Vector2(0.0, -hb * 1.25 - w * 0.35)
	draw_circle(ab, w * 0.55, wood.darkened(0.1)) # abdomen : cage de lanterne
	draw_circle(ab, w * 0.42, lc)
	draw_line(ab + Vector2(-w * 0.2, -w * 0.4), ab + Vector2(w * 0.1, w * 0.4), wood.darkened(0.3), 3.0, true) # fêlure
	for k in 3:
		draw_arc(ab, w * (0.42 + 0.06 * k), -PI * 0.9, -PI * 0.1, 10, Color(wood.r, wood.g, wood.b, 0.9), 2.0)
	draw_set_transform(Vector2.ZERO)
	if lift < -4.0: # ombre portée au sol pendant la montée / la descente : on lit où elle tombera
		var k := clampf(-lift / 400.0, 0.0, 1.0)
		draw_circle(Vector2.ZERO, w * (1.2 - 0.6 * k), Color(0.05, 0.08, 0.07, 0.45 * (1.0 - k * 0.5)))
		draw_line(Vector2(0.0, lift - hb), Vector2(0.0, -2000.0), Color(MIST.r, MIST.g, MIST.b, 0.8), 2.0, true)
	draw_arc(Vector2.ZERO, w * 1.25, 0.0, TAU, 28, Color(lc.r, lc.g, lc.b, 0.3), 2.0)


## Silhouette provisoire du Cèdre-Ermite : tréant 3,6 u, écorce gris-brun lichéneuse, tronc fendu sur une
## lanterne menthe, bras-branches ; `glow` = ouverture de la fente (enraciné : lanterne exposée).
func _body_cedar() -> void:
	var h := -Iso.lift_logical(3.6)
	var w := 0.95 * Balance.UNIT_PX
	var bark := color.lerp(Color.WHITE, progress * 0.7)
	draw_set_transform(Vector2(0.0, lift))
	for s in [-1.0, 1.0]: # racines-pieds
		draw_line(Vector2(s * w * 0.3, -h * 0.05), Vector2(s * w * 1.25, h * 0.02), bark.darkened(0.2), 9.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.75, 0.0), Vector2(w * 0.75, 0.0), Vector2(w * 0.55, -h * 0.55),
		Vector2(w * 0.7, -h * 0.82), Vector2(w * 0.2, -h), Vector2(-w * 0.35, -h * 0.94), Vector2(-w * 0.62, -h * 0.7)]), bark)
	for s in [-1.0, 1.0]: # bras-branches
		var sh := Vector2(s * w * 0.55, -h * 0.68)
		var el := Vector2(s * w * 1.35, -h * 0.55)
		draw_line(sh, el, bark.darkened(0.1), 10.0, true)
		draw_line(el, el + Vector2(s * w * 0.35, h * 0.18), bark.darkened(0.15), 6.0, true)
		draw_line(el, el + Vector2(s * w * 0.4, -h * 0.12), bark.darkened(0.15), 5.0, true)
	for k in 5: # lichen brume
		draw_circle(Vector2(sin(k * 2.1) * w * 0.4, -h * (0.2 + 0.15 * k)), 5.0, Color(MIST.r, MIST.g, MIST.b, 0.55))
	var open := clampf(glow, 0.3, 2.0) # fente du tronc : plus large quand il est enraciné
	var cy := -h * 0.45
	var lc := color2
	lc.a = clampf(0.45 + 0.35 * glow, 0.0, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, cy - w * 0.55), Vector2(w * 0.13 * open, cy), Vector2(0.0, cy + w * 0.5),
		Vector2(-w * 0.13 * open, cy)]), Color(0.05, 0.06, 0.05))
	draw_circle(Vector2(0.0, cy), w * 0.1 * (0.6 + 0.4 * open), lc)
	draw_set_transform(Vector2.ZERO)
	draw_arc(Vector2.ZERO, w * 1.1, 0.0, TAU, 28, Color(lc.r, lc.g, lc.b, 0.3), 2.0)
