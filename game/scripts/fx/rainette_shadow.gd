class_name RainetteShadow
extends Node2D
## Ombre de contact de Rainette (fiche §2.3 : « en l'air : ombre au sol + lift_px », elle est la seule chose
## en l'air parmi 250 monstres). Enfant du joueur, au sol (repère logique : le disque devient une ellipse iso).
## Texture RA2 `effects/shadow/shadow.png` (rig TOP) si livrée ; sinon disque sombre dessiné (placeholder).
## Visible seulement en l'air ; rétrécit et s'éclaircit avec la hauteur.

const RADIUS_U := 0.35
const ALPHA := 0.45
const MIN_H := 0.02

var height_u := 0.0
var _sprite: Sprite2D = null


func _ready() -> void:
	z_index = -1
	if ResourceLoader.exists(RainetteKit.SHADOW_TEX):
		_sprite = Sprite2D.new()
		_sprite.texture = load(RainetteKit.SHADOW_TEX) as Texture2D
		var k := RADIUS_U * Balance.UNIT_PX / RainetteKit.SHADOW_RADIUS_PX
		_sprite.scale = Vector2(k, k)
		add_child(_sprite)
	visible = false


func set_height(h_u: float) -> void:
	if is_equal_approx(h_u, height_u) and visible == (h_u > MIN_H):
		return
	height_u = h_u
	visible = h_u > MIN_H
	var s := clampf(1.0 - 0.3 * h_u, 0.55, 1.0)
	scale = Vector2(s, s)
	modulate.a = clampf(1.0 - 0.35 * h_u, 0.4, 1.0)
	queue_redraw()


func _draw() -> void:
	if _sprite != null:
		return
	var r := RADIUS_U * Balance.UNIT_PX
	draw_circle(Vector2.ZERO, r, Color(0.02, 0.03, 0.03, ALPHA * 0.6))
	draw_circle(Vector2.ZERO, r * 0.65, Color(0.02, 0.03, 0.03, ALPHA * 0.5))
