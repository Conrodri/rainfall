class_name CompassBadge
extends PanelContainer
## Rappel discret de la Boussole de rouille dans le HUD : icône du tag + « Tag ×N » (charges restantes), sous le rappel du
## présage. Caché sans charge. Aucun visuel nouveau : l'icône est celle du premier objet du catalogue portant ce tag
## (icônes d'objets existantes). Le HUD le place (place()) et lui donne l'échelle (set_ui_scale()).

const BASE_WIDTH := 300.0
const ITEM_ICON := "res://assets/sprites/icons/items/%s.png"

var ui_scale := 1.0
var tag := ""
var charges := 0

var _icon: TextureRect
var _label: Label
var _style: StyleBoxFlat
static var _icon_cache := {}


func _init() -> void:
	name = &"CompassBadge"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.03, 0.05, 0.09, 0.62)
	_style.border_color = Color(0.55, 0.85, 1.0, 0.35)
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", _style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)
	set_ui_scale(1.0)


func set_ui_scale(s: float) -> void:
	ui_scale = s
	_style.content_margin_left = 10.0 * s
	_style.content_margin_right = 12.0 * s
	_style.content_margin_top = 4.0 * s
	_style.content_margin_bottom = 4.0 * s
	_icon.custom_minimum_size = Vector2(40, 40) * s
	_label.add_theme_font_size_override("font_size", int(24 * s))
	(_icon.get_parent() as HBoxContainer).add_theme_constant_override("separation", int(10 * s))


## Relit la Boussole du joueur local (PlayerState.compass) ; renvoie vrai si l'affichage a changé (le HUD replace alors la colonne).
func refresh() -> bool:
	var cp: Dictionary = LocalState.state().compass
	var t := String(cp.get("tag", ""))
	var c := int(cp.get("charges", 0))
	if c <= 0 or t == "":
		t = ""
		c = 0
	if t == tag and c == charges:
		return false
	tag = t
	charges = c
	visible = c > 0
	if visible:
		_label.text = "Boussole : %s ×%d" % [tag, charges]
		_icon.texture = icon_for_tag(tag)
		_icon.visible = _icon.texture != null
		tooltip_text = "Boussole de rouille : les %d prochains petits ou grands coffres portent le tag %s." % [charges, tag]
	reset_size()
	return true


## Icône d'un tag : celle du premier objet (ordre du catalogue) qui le porte, null si aucun.
static func icon_for_tag(t: String) -> Texture2D:
	if _icon_cache.has(t):
		return _icon_cache[t]
	var tex: Texture2D = null
	for id in ItemDB.all_ids():
		if t in ItemDB.get_item(str(id)).get("tags", []):
			var path := ITEM_ICON % str(id)
			if ResourceLoader.exists(path):
				tex = load(path) as Texture2D
				break
	_icon_cache[t] = tex
	return tex


func text() -> String:
	return _label.text


## Coin haut-droit en `top_right` (px du viewport), largeur bornée par `max_width`.
func place(top_right: Vector2, max_width: float) -> void:
	reset_size()
	var w := minf(maxf(size.x, BASE_WIDTH * ui_scale * 0.6), max_width)
	position = Vector2(top_right.x - w, top_right.y)
