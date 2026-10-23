class_name AverseWaterText
extends Node2D
## « +N » d'eau flottant au-dessus d'Averse (gains hors pluie : gouttes qui touchent, kills, flaque, eau de carte),
## cumulés par AverseKit sur POPUP_WINDOW_S. Espace billboard (Iso.UNSQUASH), non éclairé, comme DamageNumbers ;
## légèrement décalé à gauche de la tête pour ne pas se mêler aux dégâts reçus (rouges, au-dessus de la tête).
## Placeholder texte (police système) : aucune planche à demander tant que DamageNumbers garde sa police.

const LIFETIME := 0.8
const RISE_PX := 46.0
const HEAD_PX := 84.0 ## hauteur d'apparition au-dessus des pieds (px billboard)
const SIDE_PX := -46.0
const FONT_PX := 22
const FONT_PX_MOBILE := 26 ## audit HUD lot C : aucun texte sous 26 px sur mobile
const MAX_ALIVE := 4 ## au-delà, le plus ancien disparaît (jamais de nuée de chiffres)

var _age := 0.0
var _label: Label


## Affiche « +amount » au-dessus de `who` (joueur). Retourne le nœud (tests), null si rien à montrer.
static func pop(who: Node2D, amount: int, col: Color) -> AverseWaterText:
	if who == null or amount <= 0 or not who.is_inside_tree():
		return null
	var alive: Array = who.get_tree().get_nodes_in_group(&"averse_water_text")
	while alive.size() >= MAX_ALIVE:
		(alive.pop_front() as Node).queue_free()
	var t := AverseWaterText.new()
	t.add_to_group(&"averse_water_text")
	who.add_child(t)
	t.setup(amount, col)
	return t


func setup(amount: int, col: Color) -> void:
	top_level = true
	z_index = 100
	light_mask = 0
	scale = Iso.UNSQUASH
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_label = Label.new()
	_label.text = "+%d" % amount
	_label.use_parent_material = true
	_label.light_mask = 0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", font_px())
	_label.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.25))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.85))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_place()


## Taille de police effective (22 PC, 26 mobile).
static func font_px() -> int:
	return FONT_PX_MOBILE if Platform.is_mobile() else FONT_PX


func text() -> String:
	return _label.text if _label != null else ""


func _place() -> void:
	var p := get_parent() as Node2D
	if p == null:
		return
	var gp := p.global_position
	# nœud à l'échelle UNSQUASH : la position monde reste logique, le décalage vertical est en px billboard
	global_position = Vector2(gp.x + SIDE_PX, gp.y - (HEAD_PX + RISE_PX * (_age / LIFETIME)) / Iso.UNSQUASH.y)
	_label.position = Vector2(-_label.size.x * 0.5, -_label.size.y)
	modulate.a = clampf(1.0 - (_age / LIFETIME - 0.6) / 0.4, 0.0, 1.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_place()
