class_name GroundShapes
extends RefCounted
## Grammaire commune des formes au sol (docs/ux/Audit_HUD.md §4.5 + Audit_Entrees_Accessibilite.md §3.2, lots UX D / L1).
## Chaque sens a sa FORME (la couleur ne porte jamais seule le sens) ; les formes sont dessinées dans le plan de sol
## LOGIQUE (la caméra iso 2:1 les écrase à l'écran : un carré tourné de 45° donne un vrai losange).
##
##   sens                      forme                               couleur         mouvement
##   hitbox du joueur          anneau continu fin + 4 crans        blanc bleuté    fixe (éclat au coup)
##   butin / ressource         losange à 8 tirets                  or chaud        pulsation lente
##   invocation alliée         hexagone plein                      vert menthe     fixe
##   zone de sort alliée       cercle de points fins               accent du kit   fondu
##                             (zones persistantes : contour plein fin ZoneOutline, couleur du sort, voile léger, sans rouge)
##   aura d'élite (affixe)     brûlure = anneau plein, poison = anneau en pointillé court, gel = double anneau
##   télégraphe ennemi         bord plein épais + remplissage progressif (enemy_telegraph.gd), seule forme « pleine » épaisse
##
## Les textures du butin et de l'invocation sont des PLACEHOLDERS générés en code (cache statique, une fois) tant que
## le lot Codex UXA11Y (art/tools/night/_uxa11y.txt) n'a pas livré `assets/sprites/ui/shapes/<nom>.png`.

const SHAPE_DIR := "res://assets/sprites/ui/shapes/"
const TEX_PX := 128
const PEAK_PX := 51.2 ## rayon du tracé dans la texture 128² (= demi-largeur × RING_AT de GroundMarker)
const STROKE_PX := 3.2

const GRAMMAR := {
	&"hitbox": {"shape": &"ring_ticks", "color": Color(0.84, 0.92, 1.0), "motion": &"fixed"},
	&"loot": {"shape": &"diamond_dashed", "color": Color(0.949, 0.757, 0.306), "motion": &"pulse"},
	&"summon": {"shape": &"hexagon", "color": Color(0.58, 0.95, 0.78), "motion": &"fixed"},
	&"zone": {"shape": &"dotted_circle", "color": Color(1, 1, 1), "motion": &"fade"},
	&"elite_burn": {"shape": &"ring_solid", "color": Color(1.0, 0.55, 0.10), "motion": &"fixed"},
	&"elite_poison": {"shape": &"ring_dotted", "color": Color(0.35, 0.90, 0.30), "motion": &"fixed"},
	&"elite_frost": {"shape": &"ring_double", "color": Color(0.30, 0.65, 1.0), "motion": &"fixed"},
}

static var _tex: Dictionary = {}


## Forme (id) d'un sens de la grammaire.
static func shape_of(sense: StringName) -> StringName:
	return (GRAMMAR.get(sense, {}) as Dictionary).get("shape", &"")


static func color_of(sense: StringName) -> Color:
	return (GRAMMAR.get(sense, {}) as Dictionary).get("color", Color.WHITE)


## Texture 128² blanche (alpha = tracé) d'une forme au sol : `diamond_dashed` ou `hexagon`. Livrée par Codex si
## présente (`SHAPE_DIR<shape>.png`), sinon générée en code (placeholder). Même rayon de tracé dans les deux cas.
static func texture(shape: StringName) -> Texture2D:
	if _tex.has(shape):
		return _tex[shape]
	var path := SHAPE_DIR + String(shape) + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	if t == null:
		t = ImageTexture.create_from_image(_bake(shape))
	_tex[shape] = t
	return t


## Vrai si la texture de `shape` vient d'un asset livré (sinon placeholder de code).
static func is_real(shape: StringName) -> bool:
	return ResourceLoader.exists(SHAPE_DIR + String(shape) + ".png")


static func clear_cache() -> void:
	_tex.clear()


static func _poly(shape: StringName) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := Vector2(TEX_PX * 0.5, TEX_PX * 0.5)
	if shape == &"diamond_dashed":
		for a in [0.0, 90.0, 180.0, 270.0]:
			pts.append(c + Vector2.from_angle(deg_to_rad(a)) * PEAK_PX)
	else: # hexagone, sommets à gauche / à droite
		for k in 6:
			pts.append(c + Vector2.from_angle(deg_to_rad(60.0 * k)) * PEAK_PX)
	return pts


static func _bake(shape: StringName) -> Image:
	var img := Image.create(TEX_PX, TEX_PX, false, Image.FORMAT_RGBA8)
	var pts := _poly(shape)
	var n := pts.size()
	var dashed := shape == &"diamond_dashed"
	var half := STROKE_PX * 0.5
	for y in TEX_PX:
		for x in TEX_PX:
			var p := Vector2(x + 0.5, y + 0.5)
			var best := 1e9
			for i in n:
				var a := pts[i]
				var b := pts[(i + 1) % n]
				var ab := b - a
				var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				if dashed: # 2 tirets par côté : trous au milieu et aux sommets
					var in_dash := (t > 0.07 and t < 0.43) or (t > 0.57 and t < 0.93)
					if not in_dash:
						continue
				best = minf(best, (p - (a + ab * t)).length())
			var cov := clampf(half + 0.5 - best, 0.0, 1.0)
			if cov > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, cov))
	return img


# --- Dessin direct (hitbox, auras, zones) : plan de sol logique -----------------------------------------------

## 4 crans cardinaux courts à l'extérieur d'un anneau de rayon r.
static func draw_ticks(ci: CanvasItem, r: float, col: Color, width := 2.0, length := 7.0) -> void:
	for k in 4:
		var d := Vector2.from_angle(k * PI * 0.5)
		ci.draw_line(d * (r - 1.0), d * (r + length), col, width, true)


## Cercle de points fins (bord de zone alliée), `n` points de rayon `dot_r`.
static func draw_dotted_circle(ci: CanvasItem, r: float, col: Color, n := 28, dot_r := 2.2) -> void:
	for k in n:
		ci.draw_circle(Vector2.from_angle(TAU * k / n) * r, dot_r, col)


## Anneau en pointillé court : `n` arcs de longueur angulaire `fill` (0..1 d'un pas).
static func draw_dashed_ring(ci: CanvasItem, r: float, col: Color, width: float, n := 14, fill := 0.5) -> void:
	var step := TAU / n
	for k in n:
		ci.draw_arc(Vector2.ZERO, r, k * step, k * step + step * fill, 4, col, width, true)
