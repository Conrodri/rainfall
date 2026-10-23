class_name ArdentTelegraph
extends Node2D
## Télégraphe au sol d'un effet différé d'Ardent (Pilier de flamme 0,3 s, impacts de la Pluie de météores 0,8 s).
## PLACEHOLDER dessiné en code (assets/sprites/vfx/telegraph_circle existe pour un remplacement, brief _ardv.txt) :
## anneau en pointillé court + remplissage qui monte ; `fall` ajoute le trait du météore qui descend.
## Décor seulement : l'effet réel part du kit (ArdentVariantKit), pas de ce nœud.

var radius := 64.0
var life := 0.8
var fall := false
var color := Color(1.0, 0.55, 0.2)
var _t := 0.0


func _ready() -> void:
	z_index = -1
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / maxf(life, 0.01), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * k, Color(color.r, color.g, color.b, 0.10 + 0.14 * k))
	GroundShapes.draw_dashed_ring(self, radius, Color(color.r, color.g, color.b, 0.55 + 0.4 * k), 2.4, 18, 0.55)
	if fall and k > 0.55:
		var f := (k - 0.55) / 0.45
		var top := Iso.lift_logical(7.0 * (1.0 - f))
		draw_line(Vector2(0.0, top), Vector2(0.0, top + Iso.lift_logical(-1.4)), Color(1.0, 0.8, 0.4, 0.9), 3.0)
