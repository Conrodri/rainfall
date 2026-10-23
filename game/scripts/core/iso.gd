class_name Iso
extends RefCounted
## Caméra isométrique dimétrique 2:1 (docs/Design_Isometrique.md §1.6, contrat orchestrateur).
## Le jeu reste dans un plan de sol logique carré (64 px/u partout, axes alignés sur l'écran) ;
## seule la caméra écrase la hauteur de moitié (zoom non uniforme). La grille des cartes est tournée de 45°.
## Règle « billboard » : tout visuel non plat au sol vit sous un nœud d'échelle UNSQUASH (échelle nette uniforme).

const ELEVATION_DEG := 30.0
const MAP_YAW_DEG := 45.0
const SQUASH := 0.5 ## sin 30° : écrasement vertical du sol à l'écran
const HEIGHT_K := 0.8660254 ## cos 30° : une hauteur de h u mesure 0,866 h de son équivalent au sol
const SCREEN_PX_PER_U := 72.0 ## figé au portail de la phase 0 (64 / 72 / 80 comparés)
const RENDER_PX_PER_U := 90.50967 ## 64·√2 : densité des assets iso rendus dans Blender
const UNSQUASH := Vector2(1.0, 2.0) ## espace billboard : compense l'écrasement de la caméra
const SPRITE_K := 0.70710678 ## 64 / RENDER_PX_PER_U : échelle d'un sprite iso dans l'espace billboard


## Zoom de la Camera2D : (s/64, s/128) × mult.
static func camera_zoom(mult := 1.0) -> Vector2:
	var z := SCREEN_PX_PER_U / Balance.UNIT_PX * mult
	return Vector2(z, z * SQUASH)


## Repère carte -> logique : rotation de +45°.
static func map_xform() -> Transform2D:
	return Transform2D(deg_to_rad(MAP_YAW_DEG), Vector2.ZERO)


## Direction logique au sol -> direction vue à l'écran (non normalisée).
static func to_screen_dir(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * SQUASH)


## Direction écran (stick droit) -> direction logique au sol, normalisée.
static func screen_to_logical_dir(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y / SQUASH).normalized()


## Angle affiché d'une direction au sol (pour tourner un sprite : projectile, flèche ; jamais pour choisir une anim).
static func screen_angle(v_logical: Vector2) -> float:
	return to_screen_dir(v_logical).angle()


## Hauteur de h u en espace billboard (px, vers le haut = négatif) : −h × cos 30° × 64.
static func lift_px(h_u: float) -> float:
	return -h_u * HEIGHT_K * Balance.UNIT_PX


## Hauteur de h u exprimée en y logique (px) : −h × cos 30° × 64 / sin 30°.
static func lift_logical(h_u: float) -> float:
	return lift_px(h_u) / SQUASH
