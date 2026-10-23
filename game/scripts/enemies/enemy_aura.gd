class_name EnemyAura
extends Node2D
## Aura colorée des élites (un anneau par affixe), dessinée sous le visuel. Indépendante du
## visuel : reste en place quand le placeholder est remplacé par un sprite.
## Lot UX A11y-L1 / D : la couleur ne porte plus seule le sens (WCAG 1.4.1). Motif par affixe (GroundShapes) :
## brûlure = anneau plein, poison = anneau en pointillé court, gel (slow) = double anneau. Couleurs via CvdPalette
## (mode daltonien lu en lecture seule). Remplissage léger : l'aura n'est pas une zone de sort.

const AFFIX_COLORS := {
	&"burn": Color(1.0, 0.55, 0.10, 0.85),
	&"slow": Color(0.30, 0.65, 1.0, 0.85),
	&"poison": Color(0.35, 0.90, 0.30, 0.85),
}
const FILL_ALPHA := 0.08
const WIDTH := 3.0

var _affixes: Array[StringName] = []
var _radius := 20.0


func set_affixes(affixes: Array[StringName], radius_px: float) -> void:
	_affixes = affixes.duplicate()
	_radius = radius_px
	visible = not _affixes.is_empty()
	queue_redraw()


## Affixes affichés (tests).
func affixes() -> Array[StringName]:
	return _affixes


## Motif d'un affixe : &"solid" | &"dotted" | &"double" (jamais deux affixes avec le même motif).
static func pattern_of(affix: StringName) -> StringName:
	match affix:
		&"poison":
			return &"dotted"
		&"slow":
			return &"double"
	return &"solid"


func _draw() -> void:
	for i in _affixes.size():
		var c := CvdPalette.affix(_affixes[i])
		var r := _radius + 5.0 + 8.0 * i
		draw_circle(Vector2.ZERO, r, Color(c, FILL_ALPHA))
		match pattern_of(_affixes[i]):
			&"dotted":
				GroundShapes.draw_dashed_ring(self, r, c, WIDTH, 14, 0.5)
			&"double":
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c, WIDTH * 0.7, true)
				draw_arc(Vector2.ZERO, r - 4.5, 0.0, TAU, 32, c, WIDTH * 0.7, true)
			_:
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c, WIDTH, true)
