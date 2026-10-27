class_name ItemBar
extends ScrollContainer
## Inventaire compact du HUD : une icône par item possédé (assets/sprites/icons/items/<id>.png sur
## un fond de sa couleur de qualité), badge « ×N » au-delà d'un exemplaire.
## Mis à jour sur RunState.item_added (ordre d'obtention).
## Deux dispositions : `wrap` (PC : plusieurs lignes sous les PV, MAX_ROWS lignes puis défilement)
## ou rangée unique défilante (tactile). Infobulle (nom, effet, exemplaires) au survol de la souris,
## ou par appui long en mode tactile.
## Badge et infobulle : éléments fonctionnels provisoires (rectangles), à habiller plus tard.

const ITEM_ICON := "res://assets/sprites/icons/items/%s.png"
const RARITY_FRAME := "res://assets/sprites/icons/frame_%s.png"
const QUALITY_COLORS := {
	&"commun": Color(0.78, 0.78, 0.8),
	&"peu_commun": Color(0.35, 0.82, 0.4),
	&"rare": Color(0.33, 0.6, 1.0),
	&"legendaire": Color(1.0, 0.65, 0.12),
}
## Fond de qualité DERRIÈRE l'icône (jamais de cadre par-dessus, retour joueur 26/10) : pastille sombre teintée
## de la couleur de qualité, bordure fine de cette couleur, hors de l'icône.
static func quality_backing(q: Variant, radius := 8) -> Panel:
	var col: Color = QUALITY_COLORS.get(StringName(str(q)), Color.WHITE)
	var p := Panel.new()
	p.name = "QualityBack"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.85)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return p


const LONG_PRESS_S := 0.45
const DRAG_CANCEL_PX := 18.0
const MAX_ROWS := 4 ## lignes max au clavier-souris / manette
const MAX_ROWS_TOUCH := 2 ## lignes max en tactile (moins de place sous les PV)

var wrap := true
var max_width := 400.0
var slot_px := 56.0
var gap := 6.0
var ui_scale := 1.0
var tooltip: PanelContainer
var tooltip_item: StringName = &"" ## item dont l'infobulle est affichée (tests)

var _content: Control
var _slots := {} ## item_id -> ItemSlot
var _order: Array[StringName] = []
var _tip_name: Label
var _tip_effect: Label
var _tip_count: Label
var _tip_rarity: Label ## mot de rareté en capitales sous le nom (« RARE »)
var _press_slot: ItemSlot = null
var _press_t := 0.0
var _press_pos := Vector2.ZERO
var _more: Button = null ## pastille « +N » (tactile : items hors de la rangée visible)
var overflow_count := 0 ## nombre d'items cachés derrière la pastille « +N » (tests)

signal overflow_pressed ## appui sur « +N » : ouvre l'onglet Items du menu pause


class ItemSlot extends Control:
	var item_id: StringName
	var count := 1
	var bar: ItemBar
	var frame: Panel ## fond de qualité (derrière l'icône)
	var icon: TextureRect
	var badge: Label
	var fallback: Label

	func _init(p_bar: ItemBar, id: StringName) -> void:
		bar = p_bar
		item_id = id
		mouse_filter = Control.MOUSE_FILTER_PASS # le défilement tactile reste possible
		var it := ItemDB.get_item(id)
		var q := str(it.get("quality", "commun"))
		frame = ItemBar.quality_backing(q)
		icon = _tex(ITEM_ICON % String(id))
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(frame)
		add_child(icon)
		if icon.texture == null: # icône absente : initiales (provisoire)
			fallback = Label.new()
			fallback.text = str(it.get("name", id)).left(2)
			fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(fallback)
		badge = Label.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.08, 0.88)
		sb.border_color = Color(1, 1, 1, 0.5)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		badge.add_theme_stylebox_override("normal", sb)
		add_child(badge)
		mouse_entered.connect(func() -> void: bar._hover(self, true))
		mouse_exited.connect(func() -> void: bar._hover(self, false))

	func _tex(path: String) -> TextureRect:
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
		return t

	func set_count(n: int) -> void:
		count = n
		badge.text = "×%d" % n
		badge.visible = n > 1

	func apply_size(px: float, s: float) -> void:
		size = Vector2(px, px)
		custom_minimum_size = size
		var inset := px * 0.14
		icon.offset_left = inset
		icon.offset_top = inset
		icon.offset_right = -inset
		icon.offset_bottom = -inset
		var fs := maxi(int(20.0 * s), HudMetrics.floor_px()) # plancher 18 px PC / 26 px mobile
		badge.add_theme_font_size_override("font_size", fs)
		badge.add_theme_constant_override("outline_size", 0)
		var bw := minf(fs * 2.6, px) # reste dans la case : aucun chevauchement avec la voisine
		var bh := maxf(fs * 1.3, badge.get_minimum_size().y)
		badge.size = Vector2(bw, bh)
		badge.position = Vector2(px - bw, px - bh)
		if fallback != null:
			fallback.add_theme_font_size_override("font_size", int(px * 0.35))

	func _gui_input(event: InputEvent) -> void:
		bar._slot_input(self, event)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content)
	_build_tooltip()
	_build_more()
	RunState.item_added.connect(_on_item_added)
	RunState.items_changed.connect(refresh) # retrait d'objets (mode test)
	refresh()


func _exit_tree() -> void:
	SpellTooltip.set_user_bubble(&"item_tip", false)
	if RunState.item_added.is_connected(_on_item_added):
		RunState.item_added.disconnect(_on_item_added)
	if RunState.items_changed.is_connected(refresh):
		RunState.items_changed.disconnect(refresh)


func _build_tooltip() -> void:
	tooltip = PanelContainer.new()
	tooltip.top_level = true # hors du découpage du défilement
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.z_index = 50
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.94)
	sb.border_color = Color(1, 1, 1, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	tooltip.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(v)
	_tip_name = Label.new()
	_tip_effect = Label.new()
	_tip_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_count = Label.new()
	_tip_count.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_tip_rarity = Label.new() # rareté écrite (Audit_Choix P11 : la couleur seule ne suffit pas)
	_tip_rarity.name = "Rarity"
	for l in [_tip_name, _tip_rarity, _tip_effect, _tip_count]:
		(l as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	tooltip.visible = false
	add_child(tooltip)


## Reconstruit toutes les cases depuis RunState.items (début de run, restauration).
func refresh() -> void:
	for id in _order:
		(_slots[id] as Node).queue_free()
	_slots.clear()
	_order.clear()
	for id in RunState.items:
		_add_or_update(StringName(id), int(RunState.items[id]))
	relayout()


func slot_count() -> int:
	return _order.size()


func get_slot(id: StringName) -> Control:
	return _slots.get(id)


func _on_item_added(item_id: StringName, stacks: int) -> void:
	_add_or_update(item_id, stacks)
	relayout()


func _add_or_update(id: StringName, n: int) -> void:
	var s: ItemSlot = _slots.get(id)
	if s == null:
		s = ItemSlot.new(self, id)
		_content.add_child(s)
		_slots[id] = s
		_order.append(id)
	s.set_count(n)
	if tooltip_item == id:
		_fill_tooltip(s)


## Dimensions : wrap (PC) ou rangée défilante (tactile). Appelé par le HUD à chaque mise en page.
func configure(p_wrap: bool, p_max_width: float, p_slot_px: float, s: float) -> void:
	wrap = p_wrap
	max_width = p_max_width
	slot_px = p_slot_px
	ui_scale = s
	gap = roundf(6.0 * s)
	relayout()


func relayout() -> void:
	if _content == null:
		return
	var n := _order.size()
	var step := slot_px + gap
	var cols := maxi(1, int(floor((max_width + gap) / step)))
	var max_rows := MAX_ROWS if wrap else MAX_ROWS_TOUCH
	# grille à retour à la ligne dans une zone bornée ; au-delà de max_rows lignes, la dernière case devient « +N »
	var shown := n
	overflow_count = 0
	if n > cols * max_rows and cols * max_rows >= 2:
		shown = cols * max_rows - 1
		overflow_count = n - shown
	for i in n:
		var sl: ItemSlot = _slots[_order[i]]
		sl.apply_size(slot_px, ui_scale)
		sl.visible = i < shown
		sl.position = Vector2((i % cols) * step, (i / cols) * step)
	var cells := shown + (1 if overflow_count > 0 else 0)
	var rows := int(ceil(float(cells) / float(cols)))
	var content := Vector2(mini(cells, cols) * step - gap, rows * step - gap) if n > 0 else Vector2.ZERO
	_layout_more(shown, step, cols)
	_content.custom_minimum_size = content
	_content.size = content
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size = Vector2(minf(content.x, max_width), content.y)
	visible = n > 0
	size = custom_minimum_size


## Rectangles écran des cases visibles et de la pastille « +N » (tests, zones réservées).
func cell_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for id in _order:
		var sl: ItemSlot = _slots[id]
		if sl.visible:
			out.append(sl.get_global_rect())
	if _more != null and _more.visible:
		out.append(_more.get_global_rect())
	return out


# --- Pastille « +N » ---------------------------------------------------------

func _build_more() -> void:
	_more = Button.new()
	_more.name = "More"
	_more.focus_mode = Control.FOCUS_NONE
	_more.mouse_filter = Control.MOUSE_FILTER_STOP
	_more.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	sb.border_color = Color(0.96, 0.76, 0.31, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	for st in ["normal", "hover", "pressed", "focus"]:
		_more.add_theme_stylebox_override(st, sb)
	_more.add_theme_color_override("font_color", Color(0.96, 0.9, 0.7))
	_more.add_theme_color_override("font_hover_color", Color.WHITE)
	_more.add_theme_color_override("font_pressed_color", Color.WHITE)
	_more.pressed.connect(_on_more_pressed)
	_content.add_child(_more)


func _layout_more(shown: int, step: float, cols: int) -> void:
	if _more == null:
		return
	_more.visible = overflow_count > 0
	if overflow_count <= 0:
		return
	_more.text = "+%d" % overflow_count
	_more.size = Vector2(slot_px, slot_px)
	_more.custom_minimum_size = _more.size
	_more.position = Vector2((shown % cols) * step, (shown / cols) * step)
	_more.add_theme_font_size_override("font_size", maxi(int(30.0 * ui_scale), HudMetrics.floor_px() + 4)) # plancher 18 PC / 26 mobile


## Ouvre le menu pause (onglet Items) ; appel tolérant : l'ouverture directe de l'onglet dépend du menu.
func _on_more_pressed() -> void:
	overflow_pressed.emit()
	var n: Node = self
	while n != null and not (n is Hud):
		n = n.get_parent()
	if n == null:
		return
	var pm: Variant = (n as Hud).pause_menu
	if pm != null and is_instance_valid(pm):
		if pm.has_method("open_items"):
			pm.call("open_items")
		elif pm.has_method("open"):
			pm.call("open")


# --- Infobulle ---------------------------------------------------------------

func _hover(slot: ItemSlot, on: bool) -> void:
	if Platform.input_mode == Platform.InputMode.TOUCH:
		return
	if on:
		show_tooltip(slot.item_id)
	elif tooltip_item == slot.item_id:
		hide_tooltip()


func _slot_input(slot: ItemSlot, event: InputEvent) -> void:
	if Platform.input_mode != Platform.InputMode.TOUCH:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_press_slot = slot
			_press_t = 0.0
			_press_pos = mb.global_position
		else:
			_press_slot = null
			hide_tooltip()
	var mm := event as InputEventMouseMotion
	if mm != null and _press_slot != null and mm.global_position.distance_to(_press_pos) > DRAG_CANCEL_PX:
		_press_slot = null # défilement : pas d'infobulle
		hide_tooltip()


func _process(delta: float) -> void:
	if _press_slot == null:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_press_slot = null
		hide_tooltip()
		return
	_press_t += delta
	if _press_t >= LONG_PRESS_S and tooltip_item != _press_slot.item_id:
		show_tooltip(_press_slot.item_id)


func show_tooltip(id: StringName) -> void:
	var slot: ItemSlot = _slots.get(id)
	if slot == null:
		return
	if SpellTooltip.other_user_bubble_open(&"item_tip"): # arbitre des bulles : la première ouverte garde la main
		return
	SpellTooltip.set_user_bubble(&"item_tip", true)
	tooltip_item = id
	_fill_tooltip(slot)
	tooltip.visible = true
	tooltip.reset_size()
	_place_tooltip.call_deferred(slot)


## Mot de rareté d'une qualité d'item (« Peu commun »…), partagé avec l'écran Objets du menu pause.
static func rarity_word(q: StringName) -> String:
	return str(PauseMenu.QUALITY_WORDS.get(q, "Commun"))


## Texte de la ligne de rareté de l'infobulle affichée (tests).
func tooltip_rarity_text() -> String:
	return _tip_rarity.text if tooltip.visible else ""


func hide_tooltip() -> void:
	SpellTooltip.set_user_bubble(&"item_tip", false)
	tooltip_item = &""
	tooltip.visible = false


func _fill_tooltip(slot: ItemSlot) -> void:
	var it := ItemDB.get_item(slot.item_id)
	var s := ui_scale
	var q := StringName(str(it.get("quality", "commun")))
	var qc: Color = QUALITY_COLORS.get(q, Color.WHITE)
	_tip_name.text = str(it.get("name", slot.item_id))
	_tip_name.add_theme_color_override("font_color", qc)
	_tip_rarity.text = rarity_word(q).to_upper()
	_tip_rarity.add_theme_color_override("font_color", qc)
	_tip_rarity.add_theme_font_size_override("font_size", maxi(int(22 * s), HudMetrics.floor_px()))
	_tip_effect.text = str(it.get("effect_text", ""))
	_tip_count.text = "Exemplaires : %d" % slot.count
	_tip_name.add_theme_font_size_override("font_size", int(30 * s))
	_tip_effect.add_theme_font_size_override("font_size", maxi(int(26 * s), HudMetrics.floor_px()))
	_tip_count.add_theme_font_size_override("font_size", maxi(int(22 * s), HudMetrics.floor_px()))
	_tip_effect.custom_minimum_size.x = 420.0 * s


## Sous la case (ou au-dessus si la place manque), bornée à l'écran.
func _place_tooltip(slot: ItemSlot) -> void:
	if not is_instance_valid(slot) or not tooltip.visible:
		return
	tooltip.reset_size()
	var vp := get_viewport_rect().size
	var r := slot.get_global_rect()
	var ts := tooltip.size
	var p := Vector2(r.position.x, r.end.y + 8.0)
	if p.y + ts.y > vp.y:
		p.y = r.position.y - ts.y - 8.0
	p.x = clampf(p.x, 4.0, maxf(4.0, vp.x - ts.x - 4.0))
	p.y = clampf(p.y, 4.0, maxf(4.0, vp.y - ts.y - 4.0))
	tooltip.global_position = p
