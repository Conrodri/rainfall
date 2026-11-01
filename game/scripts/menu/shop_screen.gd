class_name ShopScreen
extends Control
## Écran « Boutique » (accès : bouton du titre) : les skins de personnage, payables en rubis. Cosmétique uniquement : aucun
## achat en argent réel, aucun effet sur le jeu. Un carton par skin (un par personnage jouable) : aperçu (portrait du skin),
## nom, prix, état. Toucher / clic / A sur un carton :
##   - acheté ou débloqué par sa condition (victoire en Difficile, Skins.rule_of) : l'équiper, ou le retirer s'il l'est déjà ;
##   - à vendre : confirmation (« Acheter ») puis Profile.buy_skin ; le skin reste à équiper (pas d'équipement automatique) ;
##   - rubis insuffisants : message « Il manque N rubis » ; rendu pas encore livré : rien (non vendu).
## Les deux voies (condition ou achat) coexistent. Prix : data/shop.json (SkinShop). Solde de rubis en haut à droite.
## Aucune position codée en dur : marges de la zone sûre, colonnes selon la largeur (1 ou 2).

signal back_requested

enum State { EQUIPPED, OWNED, BUYABLE, POOR, NO_ART }

const CELL_H := 224.0
const GAP := 16.0
const PORTRAIT := 168.0
const COL_DIM := Color(0.62, 0.64, 0.68)
const COL_BODY := Color(0.9, 0.9, 0.93)
const COL_OK := Color("#9BE29B")
const COL_BAD := Color("#FF8A70")
const COL_GOLD := Color("#FFE9A8")

## Profil (autoload par défaut ; un profil de test peut être injecté avant _ready).
var profile: Object
## Tests : remplace le dialogue de confirmation (Callable(titre, texte) -> bool).
var confirm_override := Callable()
var back_button: Button
var ruby_label: Label
var cells: Array[Button] = []
var columns := 1
var toast_text := ""
var dialog: ConfirmDialog = null

var _banner: PanelContainer
var _ruby_box: HBoxContainer
var _hint: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _toast: Label
var _toast_tween: Tween
var _chars: Array = []
var _focus_id := ""
var _busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if profile == null:
		profile = Profile
	_chars = CharacterCard.sorted_by_difficulty(CharacterCard.load_characters())
	add_child(CharacterCard.make_backdrop())
	var bn := CharacterCard.make_banner("Boutique")
	_banner = bn.banner
	add_child(_banner)
	_ruby_box = HBoxContainer.new()
	_ruby_box.name = "Rubies"
	_ruby_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ruby_box.add_theme_constant_override(&"separation", 12)
	_ruby_box.add_child(_ruby_icon(56.0))
	ruby_label = CharacterCard.make_label("0", 44, COL_GOLD, 7)
	ruby_label.name = "RubyCount"
	ruby_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ruby_box.add_child(ruby_label)
	add_child(_ruby_box)
	_hint = CharacterCard.make_label("Skins cosmétiques, payés en rubis. Aucun avantage en jeu. Un skin se débloque aussi en gagnant en Difficile.", 22, COL_DIM, 4)
	_hint.name = "Hint"
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_hint)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
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
	_toast = CharacterCard.make_label("", 32, COL_GOLD, 7)
	_toast.name = "Toast"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tp := StyleBoxFlat.new()
	tp.bg_color = Color("#2B3340", 0.92)
	tp.set_corner_radius_all(12)
	tp.content_margin_left = 28
	tp.content_margin_right = 28
	tp.content_margin_top = 10
	tp.content_margin_bottom = 12
	_toast.add_theme_stylebox_override(&"normal", tp)
	_toast.z_index = 10
	add_child(_toast)
	UiTheme.apply(self)
	UiTheme.hook_sounds(self)
	resized.connect(_layout)
	refresh()
	if profile.has_signal(&"changed"):
		profile.connect(&"changed", refresh)
	if not Platform.is_touch_mode():
		(cells[0] if not cells.is_empty() else back_button).grab_focus.call_deferred()


# --- Données (statiques : testables sans interface) -------------------------------------------------------------------

## État d'un skin pour ce profil (voir State).
static func state_of(profile_obj: Object, entry: Dictionary) -> State:
	var sid := str(entry.id)
	var cid := str(entry.character.get("id", ""))
	if Skins.is_unlocked(profile_obj, sid):
		return State.EQUIPPED if Skins.equipped(cid, profile_obj) == sid else State.OWNED
	if not Skins.has_assets(cid, sid):
		return State.NO_ART
	return State.BUYABLE if int(profile_obj.get("rubies")) >= SkinShop.price_of(sid) else State.POOR


static func format_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return ("-" if n < 0 else "") + out


# --- Interface ----------------------------------------------------------------------------------------------------------

func _ruby_icon(px: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "RubyIcon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(px, px)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for p in TitleScreen.RUBY_PATHS:
		if ResourceLoader.exists(p):
			icon.texture = load(p) as Texture2D
			break
	return icon


func refresh() -> void:
	if _grid == null:
		return
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.queue_free()
	cells.clear()
	ruby_label.text = format_int(int(profile.get("rubies")))
	for e in Skins.all_skins(_chars):
		var cell := _skin_cell(e)
		_grid.add_child(cell)
		cells.append(cell)
	_layout()
	if _focus_id != "":
		for c in cells:
			if c.name == _focus_id and not Platform.is_touch_mode():
				c.grab_focus.call_deferred()
		_focus_id = ""


func _skin_cell(e: Dictionary) -> Button:
	var c: Dictionary = e.character
	var sk: Dictionary = e.skin
	var cid := str(c.get("id", ""))
	var sid := str(e.id)
	var st := state_of(profile, e)
	var price := SkinShop.price_of(sid)
	var b := Button.new()
	b.name = "Skin_" + sid
	b.clip_contents = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.add_theme_stylebox_override(&"normal", CharacterCard.panel_box())
	b.tooltip_text = "%s — %s\n%s" % [str(c.get("name", "")), str(sk.get("name", "")), str(sk.get("desc", ""))]
	b.set_meta(&"skin_id", sid)
	b.set_meta(&"state", st)
	b.set_meta(&"price", price)
	b.pressed.connect(_on_cell_pressed.bind(sid))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	b.add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(h)
	# Aperçu : portrait du skin ; rendu pas livré = portrait par défaut assombri.
	var pi: Dictionary = Skins.portrait_info(cid, sid)
	if not bool(pi.exists):
		pi = CharacterCard.portrait_info(c, "-")
	var pr := TextureRect.new()
	pr.name = "Portrait"
	pr.texture = pi.tex
	pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pr.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if st == State.NO_ART:
		pr.modulate = Color(0.45, 0.45, 0.5)
	h.add_child(pr)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(_line("Character", str(c.get("name", "")), 20, COL_DIM, 1))
	v.add_child(_line("Name", str(sk.get("name", sid)), 30, CharacterCard.COL_TEXT, 1))
	v.add_child(_line("Desc", str(sk.get("desc", "")), 17, COL_DIM, 2))
	match st:
		State.EQUIPPED:
			v.add_child(_line("State", "Équipé · appuyer pour retirer", 24, COL_OK, 1))
		State.OWNED:
			v.add_child(_line("State", "Possédé · Équiper", 24, CharacterCard.COL_FOCUS, 1))
		State.NO_ART:
			v.add_child(_line("State", "Rendu à venir", 22, COL_DIM, 1))
		_:
			var row := HBoxContainer.new()
			row.name = "Price"
			row.add_theme_constant_override(&"separation", 8)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(_ruby_icon(34.0))
			var ok := st == State.BUYABLE
			var pl := CharacterCard.make_label(format_int(price), 30, COL_GOLD if ok else COL_BAD, 5)
			pl.name = "PriceText"
			pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(pl)
			var act := _line("State", "Acheter" if ok else "Il manque %s" % format_int(price - int(profile.get("rubies"))), 22,
				CharacterCard.COL_FOCUS if ok else COL_BAD, 1)
			row.add_child(act)
			v.add_child(row)
			v.add_child(_line("Condition", "Ou : " + Skins.quest_text(c, sk), 16, COL_DIM, 1))
	return b


func _line(nm: String, txt: String, fs: int, col: Color, lines: int) -> Label:
	var l := CharacterCard.make_label(txt, fs, col, 3)
	l.name = nm
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 10.0
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- Actions ---------------------------------------------------------------------------------------------------------------

func _entry_of(sid: String) -> Dictionary:
	for e in Skins.all_skins(_chars):
		if str(e.id) == sid:
			return e
	return {}


## Appui sur un carton : équiper / retirer, acheter (après confirmation) ou expliquer pourquoi c'est impossible.
func _on_cell_pressed(sid: String) -> void:
	if _busy:
		return
	var e := _entry_of(sid)
	if e.is_empty():
		return
	var cid := str(e.character.get("id", ""))
	_focus_id = "Skin_" + sid
	CharacterCard.play_ui(&"ui.click", -6.0, 1.0)
	match state_of(profile, e):
		State.EQUIPPED:
			profile.call(&"set_selected_skin", StringName(cid), "")
			if not profile.has_signal(&"changed"):
				refresh()
		State.OWNED:
			profile.call(&"set_selected_skin", StringName(cid), sid)
			if not profile.has_signal(&"changed"):
				refresh()
		State.BUYABLE:
			await _buy_flow(e)
		State.POOR:
			show_toast("Il vous manque %s rubis." % format_int(SkinShop.price_of(sid) - int(profile.get("rubies"))))
		State.NO_ART:
			show_toast("Ce skin n'est pas encore disponible.")


func _buy_flow(e: Dictionary) -> void:
	_busy = true
	var sid := str(e.id)
	var price := SkinShop.price_of(sid)
	var left := int(profile.get("rubies")) - price
	var title := "Acheter « %s » ?" % str(e.skin.get("name", sid))
	var line := "%s · %s rubis.\nIl vous en restera %s. Achat cosmétique, définitif." % [str(e.character.get("name", "")), format_int(price), format_int(left)]
	var yes := false
	if confirm_override.is_valid():
		yes = bool(await confirm_override.call(title, line))
	else:
		dialog = ConfirmDialog.new()
		add_child(dialog)
		var sig: Signal = dialog.ask(title, line, "Annuler", "Acheter")
		if dialog._destructive != null:
			UiTheme.primary(dialog._destructive) # un achat n'est pas destructif : bouton principal
		yes = bool(await sig)
		dialog = null
	_busy = false
	if not yes or not is_inside_tree():
		return
	var res: StringName = profile.call(&"buy_skin", sid)
	if res == &"ok":
		CharacterCard.play_ui(&"ui.item_pick", -4.0, 1.0)
		show_toast("Skin acquis : %s. Appuyez dessus pour l'équiper." % str(e.skin.get("name", sid)))
	elif res == &"poor":
		show_toast("Il vous manque %s rubis." % format_int(price - int(profile.get("rubies"))))
	elif res == &"owned":
		show_toast("Vous possédez déjà ce skin.")
	else:
		show_toast("Achat impossible.")
	if not profile.has_signal(&"changed"):
		refresh()


func show_toast(text: String) -> void:
	toast_text = text
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_layout()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


# --- Disposition et focus ---------------------------------------------------------------------------------------------------

func _wire_focus() -> void:
	if back_button == null:
		return
	var cols := maxi(columns, 1)
	for i in cells.size():
		var c := cells[i]
		c.focus_neighbor_left = c.get_path_to(cells[i - 1] if i % cols != 0 else c)
		c.focus_neighbor_right = c.get_path_to(cells[i + 1] if i % cols != cols - 1 and i + 1 < cells.size() else c)
		c.focus_neighbor_top = c.get_path_to(cells[i - cols] if i - cols >= 0 else c)
		c.focus_neighbor_bottom = c.get_path_to(cells[i + cols] if i + cols < cells.size() else back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(cells[cells.size() - 1] if not cells.is_empty() else back_button)
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
	var w: float = vs.x - float(m.left) - float(m.right)
	_banner.position = Vector2(m.left, 24)
	_banner.size = Vector2(520, maxf(92.0, _banner.get_combined_minimum_size().y))
	_ruby_box.reset_size()
	_ruby_box.position = Vector2(vs.x - m.right - _ruby_box.size.x, 24 + (_banner.size.y - _ruby_box.size.y) * 0.5)
	back_button.position = Vector2(m.left, vs.y - m.bottom - back_button.size.y)
	var y: float = _banner.position.y + _banner.size.y + 10.0
	_hint.position = Vector2(m.left, y)
	_hint.size = Vector2(w, 32)
	y += 38.0
	_scroll.position = Vector2(m.left, y)
	_scroll.size = Vector2(w, back_button.position.y - 16.0 - y)
	var gw := maxf(w - 16.0, 200.0)
	var cols := 2 if gw >= 760.0 else 1
	columns = cols
	_grid.columns = cols
	var cell_w := floorf((gw - GAP * (cols - 1)) / cols)
	for c in cells:
		c.custom_minimum_size = Vector2(cell_w, CELL_H)
	_grid.custom_minimum_size.x = gw
	_toast.reset_size()
	_toast.position = Vector2((vs.x - _toast.size.x) * 0.5, vs.y - m.bottom - _toast.size.y - 8.0)
	_wire_focus()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and dialog == null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
