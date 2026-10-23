class_name Floor1Fx
extends Node2D
## Formes dessinées PROVISOIRES des boss d'étage 1 sans sprites (Bouvier, Porteuse de jarres) tant que leurs
## planches Blender (Codex, art/tools/night/requests_bosses1.md) ne sont pas livrées : chaque usage essaie d'abord
## l'anim du .tres du boss et ne retombe ici qu'en son absence (CLAUDE.md : formes en code = placeholders
## temporaires). Les corps sont éclairés (lumière de la carte, comme un sprite) mais leurs couleurs restent
## claires (leçon du Sonneur : jamais un corps presque noir la nuit) ; l'accent cyan d'eau #5EC8FF est en
## émission (unshaded) via `glow`. Un seul nœud par effet, redessiné seulement quand un paramètre change.
## Outils communs des cerveaux d'étage 1 : sprite() (extra d'un .tres avec émission), billboard().

enum Kind { BODY_OX, BODY_JAR_BEARER, JAR }

const CYAN := Color(0.369, 0.784, 1.0) ## #5EC8FF : accent émissif du biome (eau, lanternes de pierre)
const STONE := Color(0.56, 0.57, 0.52) ## pierre moussue claire (albédo ≥ 90/255)
const BRONZE := Color(0.46, 0.60, 0.52) ## bronze vert-de-gris
const CLAY := Color(0.66, 0.50, 0.38) ## terre cuite des jarres

var kind := Kind.BODY_OX
var color := STONE
var color2 := BRONZE
var progress := 0.0 ## flash de coup (0..1)
var lift := 0.0 ## lévitation (px logiques, négatif = vers le haut)
var glow := 1.0 ## intensité de l'accent cyan
var facing := 0.0 ## BODY_OX : angle logique (cornes vers la cible)
var jars := 6 ## BODY_JAR_BEARER : jarres encore sur le dos
var scale_u := 1.0 ## JAR : diamètre (u)
var cracks := 0.0 ## JAR : fissures (0..1)


static func make(p_kind: Kind, p_z: int = 0) -> Floor1Fx:
	var f := Floor1Fx.new()
	f.kind = p_kind
	f.z_index = p_z
	# sans normal map, la lumière 2D forte du boss (énergie 2,4-4) brûlait la silhouette en blanc :
	# le placeholder garde ses couleurs (albédo ≥ 90/255) sous l'étalonnage de la carte, l'accent cyan se lit seul
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	f.material = m
	return f


## Extra animé d'un .tres de boss (émission comprise). Nom du nœud préfixé (`prefix`) pour les tests de fuite.
static func sprite(frames: SpriteFrames, anim: StringName, prefix: String, energy := 2.0, z := 0) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = StringName(prefix + String(anim))
	EmissiveOverlay.apply(s, frames, energy)
	s.animation = anim
	s.z_index = z
	return s


## Échelle d'un extra « billboard » (rendu iso) de `src_px` de large qui doit couvrir `want_px` logiques au sol.
static func billboard(want_px: float, src_px: float) -> Vector2:
	return Vector2.ONE * (want_px / maxf(src_px, 1.0)) * Iso.UNSQUASH


func set_flash(f: float) -> void:
	if absf(f - progress) > 0.01:
		progress = f
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.BODY_OX:
			_body_ox()
		Kind.BODY_JAR_BEARER:
			_body_jar_bearer()
		Kind.JAR:
			_jar(Vector2.ZERO, scale_u * Balance.UNIT_PX * 0.5, color.lerp(Color.WHITE, progress * 0.6))


## Buffle d'eau de pierre (3,4 u), harnais de bronze, cornes-ancres. Corps vu de 3/4 : masse basse et large,
## bosse d'épaules, tête baissée du côté de `facing` (gauche/droite selon le signe de cos).
func _body_ox() -> void:
	var u := Balance.UNIT_PX
	var h := -Iso.lift_logical(2.2) # le dos (le buffle est long, pas haut)
	var s := 1.0 if cos(facing) >= 0.0 else -1.0
	var stone := color.lerp(Color.WHITE, progress * 0.7)
	var bronze := color2.lerp(Color.WHITE, progress * 0.5)
	draw_set_transform(Vector2(0.0, lift))
	# pattes (4 piliers de pierre)
	for x in [-1.05, -0.55, 0.5, 0.95]:
		draw_rect(Rect2(Vector2(x * u * s - u * 0.16, -h * 0.42), Vector2(u * 0.32, h * 0.42)), stone.darkened(0.18))
	# corps : bloc anguleux + bosse d'épaules
	draw_colored_polygon(PackedVector2Array([Vector2(-1.3 * u * s, -h * 0.38), Vector2(1.05 * u * s, -h * 0.4),
		Vector2(1.15 * u * s, -h * 0.82), Vector2(0.55 * u * s, -h), Vector2(-0.5 * u * s, -h * 0.9),
		Vector2(-1.35 * u * s, -h * 0.72)]), stone)
	# harnais de bronze : sangle + collier
	draw_line(Vector2(0.2 * u * s, -h * 0.4), Vector2(0.45 * u * s, -h * 0.98), bronze, u * 0.16)
	draw_line(Vector2(-0.6 * u * s, -h * 0.4), Vector2(-0.5 * u * s, -h * 0.9), bronze, u * 0.1)
	# tête baissée + cornes-ancres (crochets recourbés vers le haut)
	var hx := 1.45 * u * s
	var hy := -h * 0.55
	draw_colored_polygon(PackedVector2Array([Vector2(1.0 * u * s, -h * 0.82), Vector2(hx + 0.25 * u * s, hy - h * 0.05),
		Vector2(hx + 0.2 * u * s, hy + h * 0.2), Vector2(1.0 * u * s, -h * 0.45)]), stone.darkened(0.08))
	for k in [-1.0, 1.0]:
		var base := Vector2(hx - 0.05 * u * s, hy - h * 0.12 + k * u * 0.08)
		var tip := base + Vector2(0.15 * u * s, -h * 0.35)
		draw_line(base, base + Vector2(-0.45 * u * s, -h * 0.05), bronze, u * 0.12) # hampe
		draw_line(base + Vector2(-0.45 * u * s, -h * 0.05), tip + Vector2(-0.7 * u * s, 0.0), bronze, u * 0.1) # crochet
	# yeux / naseaux d'eau (accent cyan)
	var cy := CYAN
	cy.a = clampf(0.55 + 0.45 * glow, 0.0, 1.0)
	draw_circle(Vector2(hx + 0.1 * u * s, hy - h * 0.02), u * 0.07, cy)
	draw_circle(Vector2(-0.1 * u * s, -h * 0.92), u * 0.09, cy) # anneau du harnais
	draw_arc(Vector2.ZERO, u * 1.4, 0.0, TAU, 28, Color(cy.r, cy.g, cy.b, 0.3), 2.0) # pied
	draw_set_transform(Vector2.ZERO)


## Esprit de lanterne de pierre (3,0 u) : toit de pagode, foyer cyan, 6 jarres sanglées sur le dos.
func _body_jar_bearer() -> void:
	var u := Balance.UNIT_PX
	var h := -Iso.lift_logical(3.0)
	var stone := color.lerp(Color.WHITE, progress * 0.7)
	draw_set_transform(Vector2(0.0, lift))
	# jarres du dos (derrière le corps)
	for i in jars:
		var col := i % 3
		var row := int(i / 3.0)
		_jar(Vector2((col - 1) * u * 0.55, -h * (0.55 + 0.22 * row)), u * 0.26, CLAY.lerp(Color.WHITE, progress * 0.5))
	# socle + fût
	draw_colored_polygon(PackedVector2Array([Vector2(-0.75 * u, 0.0), Vector2(0.75 * u, 0.0), Vector2(0.5 * u, -h * 0.18),
		Vector2(-0.5 * u, -h * 0.18)]), stone.darkened(0.12))
	draw_rect(Rect2(Vector2(-0.28 * u, -h * 0.5), Vector2(0.56 * u, h * 0.32)), stone)
	# chambre du feu (cyan) + toit
	draw_rect(Rect2(Vector2(-0.55 * u, -h * 0.74), Vector2(1.1 * u, h * 0.24)), stone.lightened(0.05))
	var cy := CYAN
	cy.a = clampf(0.5 + 0.5 * glow, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-0.3 * u, -h * 0.71), Vector2(0.6 * u, h * 0.17)), cy)
	draw_colored_polygon(PackedVector2Array([Vector2(-0.95 * u, -h * 0.74), Vector2(0.95 * u, -h * 0.74),
		Vector2(0.25 * u, -h * 0.92), Vector2(0.0, -h), Vector2(-0.25 * u, -h * 0.92)]), color2.lerp(Color.WHITE, progress * 0.5))
	draw_arc(Vector2.ZERO, u * 0.95, 0.0, TAU, 24, Color(cy.r, cy.g, cy.b, 0.35), 2.0)
	draw_set_transform(Vector2.ZERO)


## Jarre (vue de 3/4) : panse ronde, col, liseré d'eau cyan ; fissures si `cracks`.
func _jar(c: Vector2, r: float, clay: Color) -> void:
	draw_circle(c, r, clay)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.35, clay.lightened(0.18))
	draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 1.35), Vector2(r * 0.8, r * 0.45)), clay.darkened(0.15))
	var cy := CYAN
	cy.a = clampf(0.45 + 0.4 * glow, 0.0, 1.0)
	draw_line(c + Vector2(-r * 0.4, -r * 1.3), c + Vector2(r * 0.4, -r * 1.3), cy, maxf(r * 0.18, 2.0))
	if cracks > 0.05:
		var dk := Color(0.1, 0.07, 0.05, 0.9)
		draw_line(c + Vector2(-r * 0.2, -r * 0.8), c + Vector2(r * 0.1, 0.0), dk, 2.0)
		if cracks > 0.4:
			draw_line(c + Vector2(r * 0.1, 0.0), c + Vector2(-r * 0.3, r * 0.6), dk, 2.0)
			draw_line(c + Vector2(r * 0.1, 0.0), c + Vector2(r * 0.6, r * 0.2), dk, 2.0)
		if cracks > 0.7:
			draw_line(c + Vector2(-r * 0.6, -r * 0.2), c + Vector2(r * 0.3, -r * 0.5), dk, 2.0)
