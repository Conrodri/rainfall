class_name MorfilTwinBlade
extends Node2D
## PLACEHOLDER (à remplacer par les anims `<base>_dual_<dir>` du lot Codex SA1) : le second katana des
## Lames jumelles de Taliant, un fil de sève tenu dans la main gauche. Trait fin, accent unique, sans remplissage.

## Repère : enfant du sprite du joueur (px de la frame, ~90 px/u comme le sprite d'Ardent).
const LENGTH_PX := 82.0
const HAND_PX := Vector2(-22.0, -52.0) ## main gauche (écran), à mi-hauteur de l'arbre
const WIDTH_PX := 2.0
const FLASH_S := 0.12

var color := Color("#CDEB6E")
var facing := Vector2.DOWN
var fade := 1.0
var _flash := 0.0


func flash() -> void:
	_flash = FLASH_S


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var screen := Iso.to_screen_dir(facing) if facing != Vector2.ZERO else Vector2.DOWN
	var side := Vector2(-screen.y, screen.x)
	var hand := HAND_PX + side * 10.0
	var tip := hand + (screen * 0.7 + Vector2(0, -0.5)).normalized() * LENGTH_PX
	var k := 1.0 + 1.6 * (_flash / FLASH_S)
	var c := Color(color.r * 1.4 * k, color.g * 1.4 * k, color.b * 1.4 * k, 0.85 * fade)
	draw_line(hand, tip, c, WIDTH_PX, true)
	draw_line(hand, hand - (tip - hand).normalized() * 16.0, Color(0.2, 0.17, 0.14, fade), WIDTH_PX + 2.0, true)
