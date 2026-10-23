class_name WaveIndicator
extends Node2D
## Annonce d'une vague du Director : flèche discrète au bord de l'écran, du côté de la vague,
## pendant Balance.WAVE_ANNOUNCE_S (apparition, pulsation, fondu). Coordonnées monde, sous
## AmbianceManager.telegraph_layer (ni éclairée, ni étalonnée) ; recalée chaque frame sur la caméra.
## Visuel : texture Blender `assets/sprites/ui/wave_arrow.png` (pointe vers +x) si livrée, sinon
## chevrons dessinés en code = PLACEHOLDER temporaire (à remplacer par l'asset Blender).

const ARROW_TEX := "res://assets/sprites/ui/wave_arrow.png"
const INSET_PX := 80.0 ## distance au bord de l'écran
const FADE_IN_S := 0.15
const FADE_OUT_S := 0.45
const COLOR := Color(1.0, 0.35, 0.22, 0.85)

var side := Vector2.RIGHT
var along := 0.0
var duration := 1.5
var life := 0.0
var _director: Director
var _tex: Texture2D = null


func setup(director: Director, wave_side: Vector2, wave_along: float, seconds: float) -> void:
	_director = director
	side = wave_side
	along = wave_along
	duration = seconds


func _ready() -> void:
	material = EnemyTelegraph.unshaded_material()
	light_mask = 0
	z_index = 50
	if ResourceLoader.exists(ARROW_TEX):
		_tex = load(ARROW_TEX) as Texture2D
	rotation = side.angle()
	_place()


func _process(delta: float) -> void:
	life += delta
	if life >= duration:
		queue_free()
		return
	_place()
	var a := minf(life / FADE_IN_S, 1.0) * minf((duration - life) / FADE_OUT_S, 1.0)
	modulate.a = a * (0.75 + 0.25 * sin(life * TAU * 3.0))


func _place() -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp else null
	var center := Vector2.ZERO
	if cam != null:
		center = cam.get_screen_center_position()
	elif is_instance_valid(_director):
		var pl := get_tree().get_first_node_in_group(&"player") as Node2D
		center = pl.global_position if pl else Vector2.ZERO
	var half: Vector2 = _director._spawn_half_extent() if is_instance_valid(_director) else Vector2(960, 540)
	var tangent := Vector2(-side.y, side.x)
	var edge_half := absf(tangent.x) * half.x + absf(tangent.y) * half.y
	var depth := absf(side.x) * half.x + absf(side.y) * half.y
	global_position = center + side * (depth - INSET_PX) + tangent * (along * (edge_half - INSET_PX * 2.0))


func _draw() -> void:
	if _tex != null:
		draw_texture(_tex, -_tex.get_size() * 0.5)
		return
	# PLACEHOLDER : deux chevrons pointant vers l'extérieur de l'écran (vers la vague)
	for i in 2:
		var x := -18.0 + i * 22.0
		var pts := PackedVector2Array([Vector2(x - 14, -26), Vector2(x + 14, 0), Vector2(x - 14, 26),
			Vector2(x - 24, 26), Vector2(x + 2, 0), Vector2(x - 24, -26)])
		draw_colored_polygon(pts, Color(COLOR, COLOR.a * (0.6 + 0.4 * i)))
