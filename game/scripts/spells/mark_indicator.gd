class_name MarkIndicator
extends Node2D
## Debuff au-dessus de la tête d'un monstre marqué par un kit (is_marked) : sprite Codex blanc 48 px
## (assets/sprites/ui/debuff/mark_generic.png) teinté par l'accent du kit ; repli en code si le fichier manque.
## Passif : aucune boucle ici, SpellCaster._poll_marks (0,25 s) le crée, le teinte et le retire.

const GROUP := &"mark_indicators"
const NAME := &"MarkIndicator"
const SIZE_PX := 9.0
const ICON_PATH := "res://assets/sprites/ui/debuff/mark_generic.png"

static var _icon: Texture2D
static var _icon_tried := false
var _sprite: Sprite2D

var color := Color(1.0, 0.55, 0.12)


## Pose (ou retrouve) l'indicateur sur le monstre et le teinte.
static func show_on(e: Node2D, tint: Color) -> void:
	var m := e.get_node_or_null(NodePath(NAME)) as MarkIndicator
	if m == null or m.is_queued_for_deletion():
		m = MarkIndicator.new()
		m.name = NAME
		var r: float = float(e.get(&"radius_px")) if &"radius_px" in e else 24.0
		m.position = Vector2(0.0, -(r + 14.0))
		m.z_index = 20
		m.add_to_group(GROUP)
		e.add_child(m)
	if m.color != tint:
		m.color = tint
		m._apply_tint()


static func clear_on(e: Node) -> void:
	var m := e.get_node_or_null(NodePath(NAME))
	if m != null:
		m.queue_free()


static func clear_all(tree: SceneTree) -> void:
	for m in tree.get_nodes_in_group(GROUP):
		m.queue_free()


static func _load_icon() -> Texture2D:
	if not _icon_tried:
		_icon_tried = true
		if ResourceLoader.exists(ICON_PATH):
			_icon = load(ICON_PATH) as Texture2D
	return _icon


func _ready() -> void:
	var tex := _load_icon()
	if tex != null:
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		add_child(_sprite)
	_apply_tint()


func _apply_tint() -> void:
	if _sprite != null:
		_sprite.modulate = color
	else:
		queue_redraw()


func _draw() -> void:
	if _sprite != null:
		return
	var s := SIZE_PX
	draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s * 0.7, 0), Vector2(0, s), Vector2(-s * 0.7, 0)]), Color(color, 0.95))
	var c := s * 0.45
	draw_colored_polygon(PackedVector2Array([Vector2(0, -c), Vector2(c * 0.7, 0), Vector2(0, c), Vector2(-c * 0.7, 0)]), color.lerp(Color.WHITE, 0.6))
