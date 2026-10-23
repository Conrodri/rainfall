class_name VigieTelegraph
extends Node2D
## Télégraphe du Tir de signal de Vigie (variante, VigieKit) : cercle rouge qui se referme sur le point d'impact
## pendant `life` s. PLACEHOLDER dessiné en code (anneau pointillé + remplissage qui monte), à remplacer par le
## télégraphe commun rendu dans Blender. Décor seulement : l'impact réel part du kit.

var radius := 224.0
var life := 1.2
var color := Color("#FF3A4F")
var _t := 0.0


func setup(at: Vector2, radius_px: float, life_s: float, col: Color) -> void:
	global_position = at
	radius = radius_px
	life = life_s
	color = col
	z_index = -1


func _ready() -> void:
	queue_redraw()


func step(delta: float) -> void: ## public pour les tests sans boucle de rendu
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func _draw() -> void:
	var k := clampf(_t / maxf(life, 0.01), 0.0, 1.0)
	var closing := radius * (1.6 - 0.6 * k) # le cercle extérieur se referme sur le rayon réel
	draw_circle(Vector2.ZERO, radius * k, Color(color.r, color.g, color.b, 0.08 + 0.14 * k))
	GroundShapes.draw_dashed_ring(self, radius, Color(color.r, color.g, color.b, 0.55 + 0.4 * k), 2.4, 18, 0.55)
	draw_arc(Vector2.ZERO, closing, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.7 * (1.0 - k) + 0.2), 2.0)
