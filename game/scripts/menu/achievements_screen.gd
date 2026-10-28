class_name AchievementsScreen
extends Control
## Écran « Succès » : grille de cartes (icône, nom, consigne, progression), verrouillé / débloqué, compteur global.
## Lecture seule ; chaque carte est focusable (clavier / manette) pour faire défiler. Données : data/achievements.json
## (Achievements) et `Profile`. Aucune position codée en dur : marges de la zone sûre, colonnes selon la largeur.

signal back_requested

const CARD_MIN_W := 440.0
const CARD_H := 132.0
const ICON_PX := 88.0
const GAP := 16.0
const COL_DIM := Color(0.62, 0.64, 0.68)
const COL_BODY := Color(0.9, 0.9, 0.93)
const COL_DONE := Color("#FFE9A8")

## Profil (autoload par défaut ; un objet factice peut être injecté avant _ready).
var profile: Object
var back_button: Button
var count_label: Label
var cards: Array[Button] = []

var _banner: PanelContainer
var _scroll: ScrollContainer
var _grid: GridContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if profile == null:
		profile = Profile
	add_child(CharacterCard.make_backdrop())
	var bn := CharacterCard.make_banner("Succès")
	_banner = bn.banner
	add_child(_banner)
	count_label = CharacterCard.make_label("", 36, UiTheme.COL_PRIMARY_TEXT, 6)
	count_label.name = "Count"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(count_label)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override(&"h_separation", int(GAP))
	_grid.add_theme_constant_override(&"v_separation", int(GAP))
	_scroll.add_child(_grid)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "Retour"
	back_button.custom_minimum_size = Vector2(300, 96)
	back_button.size = back_button.custom_minimum_size
	back_button.add_theme_font_size_override(&"font_size", 40)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	UiTheme.mark_back(back_button)
	add_child(back_button)
	UiTheme.apply(self)
	UiTheme.hook_sounds(self)
	resized.connect(_layout)
	refresh()
	_layout()
	if profile.has_signal(&"changed"):
		profile.connect(&"changed", refresh)
	if not Platform.is_touch_mode():
		back_button.grab_focus.call_deferred()


## Relit le profil et reconstruit la grille.
func refresh() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	cards.clear()
	var all := Achievements.all()
	count_label.text = "%d / %d débloqués" % [Achievements.unlocked_count(profile), all.size()]
	# Débloqués d'abord (ordre du fichier), puis les verrouillés.
	var ordered: Array = []
	for pass_unlocked in [true, false]:
		for a in all:
			if bool(profile.call(&"is_achievement_unlocked", str(a["id"]))) == pass_unlocked:
				ordered.append(a)
	for a in ordered:
		var card := _make_card(a)
		_grid.add_child(card)
		cards.append(card)
	_layout()


func _make_card(a: Dictionary) -> Button:
	var id := str(a["id"])
	var done := bool(profile.call(&"is_achievement_unlocked", id))
	var b := Button.new()
	b.name = "Card_" + id
	b.set_meta(&"achievement", id)
	b.custom_minimum_size = Vector2(CARD_MIN_W, CARD_H)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := CharacterCard.panel_box(Color("#3a3220") if done else Color("#2B3340"),
		CharacterCard.COL_FOCUS if done else CharacterCard.COL_BORDER, 2, 0.9)
	for st in [&"normal", &"hover", &"pressed", &"disabled"]:
		b.add_theme_stylebox_override(st, box)
	b.add_theme_stylebox_override(&"focus", CharacterCard.focus_box())
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.add_theme_constant_override(&"separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := TextureRect.new()
	ic.name = "Icon"
	ic.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ic.texture = Achievements.icon_of(a)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not done:
		ic.material = CharacterCard.grayscale_material(0.5)
		ic.modulate = Color(1, 1, 1, 0.85)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override(&"separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nm := CharacterCard.make_label(str(a["name"]), 28, COL_DONE if done else COL_DIM, 4)
	nm.name = "Name"
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	var ds := CharacterCard.make_label(str(a["desc"]), 21, COL_BODY if done else COL_DIM, 3)
	ds.name = "Desc"
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size.x = 10.0
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(ds)
	var pr := Achievements.progress(profile, a)
	if done:
		var when := str((profile.get("achievements") as Dictionary).get(id, "")).substr(0, 10)
		v.add_child(CharacterCard.make_label("Débloqué" + (" le " + when if when != "" else ""), 18, CharacterCard.COL_FOCUS, 3))
	elif not pr.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar := ProgressBar.new()
		bar.name = "Progress"
		bar.max_value = float(pr["max"])
		bar.value = float(pr["cur"])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(120, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		row.add_child(CharacterCard.make_label("%s / %s" % [group_thousands(int(pr["cur"])), group_thousands(int(pr["max"]))], 18, COL_DIM, 3))
		v.add_child(row)
	return b


static func group_thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return ("-" if n < 0 else "") + out


func _wire_focus() -> void:
	if back_button == null:
		return
	var cols := maxi(_grid.columns, 1)
	for i in cards.size():
		var c := cards[i]
		c.focus_neighbor_left = c.get_path_to(cards[i - 1]) if i % cols != 0 else c.get_path_to(c)
		c.focus_neighbor_right = c.get_path_to(cards[i + 1]) if i % cols != cols - 1 and i + 1 < cards.size() else c.get_path_to(c)
		c.focus_neighbor_top = c.get_path_to(cards[i - cols]) if i - cols >= 0 else c.get_path_to(c)
		c.focus_neighbor_bottom = c.get_path_to(cards[i + cols]) if i + cols < cards.size() else c.get_path_to(back_button)
	if not cards.is_empty():
		back_button.focus_neighbor_top = back_button.get_path_to(cards[0])
	back_button.focus_neighbor_left = back_button.get_path_to(back_button)
	back_button.focus_neighbor_right = back_button.get_path_to(back_button)
	back_button.focus_neighbor_bottom = back_button.get_path_to(back_button)


func _layout() -> void:
	if _banner == null:
		return
	var vs := size if size.x > 0 else get_viewport_rect().size
	var m := {"left": 48.0, "right": 48.0, "top": 32.0, "bottom": 32.0}
	var d: Dictionary = Platform.safe_margins()
	for k in m:
		m[k] = clampf(float(d.get(k, m[k])), m[k], 160.0)
	_banner.position = Vector2(m.left, 24)
	_banner.size = Vector2(520, maxf(92.0, _banner.get_combined_minimum_size().y))
	count_label.size = Vector2(560, 56)
	count_label.position = Vector2(vs.x - m.right - count_label.size.x, 24 + (_banner.size.y - count_label.size.y) * 0.5)
	back_button.position = Vector2(m.left, vs.y - m.bottom - back_button.size.y)
	var top: float = _banner.position.y + _banner.size.y + 16.0
	var w: float = vs.x - float(m.left) - float(m.right)
	var cols := clampi(int((w - 16.0 + GAP) / (CARD_MIN_W + GAP)), 1, 4)
	_grid.columns = cols
	var card_w := floorf((w - 16.0 - GAP * (cols - 1)) / cols)
	for c in cards:
		c.custom_minimum_size = Vector2(card_w, CARD_H)
	_scroll.position = Vector2(m.left, top)
	_scroll.size = Vector2(w, back_button.position.y - 16.0 - top)
	_wire_focus()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
