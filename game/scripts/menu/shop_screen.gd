class_name ShopScreen
extends Control
## Écran « Boutique » (accès : bouton du titre) : la boutique cosmétique, payée en rubis gagnés en jouant. Cosmétique
## uniquement : aucun achat en argent réel, aucun effet sur le jeu (docs/Boutique_Rubis.md). Un onglet par famille
## (Cosmetics.families : Panoplies, Ciels, Sillages, Parements, Veillées). Un carton par article : aperçu, nom, cible
## (personnage ou biome), prix, état. Toucher / clic / A sur un carton :
##   - possédé : l'équiper, ou le retirer s'il l'est déjà (retour à l'apparence par défaut) ;
##   - à vendre : confirmation (« Acheter ») puis Profile.buy_skin / Profile.buy_cosmetic ; l'article reste à équiper ;
##   - rubis insuffisants : message « Il manque N rubis » ; assets pas encore livrés : « Bientôt », non vendu.
## Onglet Panoplies : les skins de chaque personnage (Skins.all_skins : trophées de Difficile, achetables aussi au prix de
## data/shop.json, puis Panoplies du catalogue). Aperçu : `preview` du catalogue ou portrait du skin ; sinon un cadre vide
## au nom de la famille (placeholder, jamais un asset dessiné).
## Entrées : tactile et souris (onglets et cartons), manette / clavier (focus ; LB / RB ou Q / E changent d'onglet ; B /
## Échap = retour). Aucune position codée en dur : marges de la zone sûre, colonnes selon la largeur (1 ou 2).

signal back_requested

enum State { EQUIPPED, OWNED, BUYABLE, POOR, NO_ART }

const CELL_H := 224.0
const GAP := 16.0
const PORTRAIT := 168.0
const TAB_H := 72.0
const TAB_W_MAX := 260.0
const COL_DIM := Color(0.62, 0.64, 0.68)
const COL_BODY := Color(0.9, 0.9, 0.93)
const COL_OK := Color("#9BE29B")
const COL_BAD := Color("#FF8A70")
const COL_GOLD := Color("#FFE9A8")
const SOON_TEXT := "Bientôt"
const BIOME_NAMES := {"terrasses": "Terrasses noyées", "foret": "Forêt-brume", "cite": "Cité de rouille", "cryptes": "Cryptes noyées"}

## Profil (autoload par défaut ; un profil de test peut être injecté avant _ready).
var profile: Object
## Tests : remplace le dialogue de confirmation (Callable(titre, texte) -> bool).
var confirm_override := Callable()
var back_button: Button
var ruby_label: Label
var cells: Array[Button] = []
var tab_buttons: Array[Button] = []
var family: StringName = &"panoplie"
var columns := 1
var toast_text := ""
var dialog: ConfirmDialog = null

var _banner: PanelContainer
var _ruby_box: HBoxContainer
var _tabs_bar: HBoxContainer
var _hint: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _toast: Label
var _toast_tween: Tween
var _chars: Array = []
var _families: Array[StringName] = []
var _focus_id := ""
var _busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if profile == null:
		profile = Profile
	_chars = CharacterCard.sorted_by_difficulty(CharacterCard.load_characters())
	_families = Cosmetics.families()
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
	_tabs_bar = HBoxContainer.new()
	_tabs_bar.name = "Tabs"
	_tabs_bar.add_theme_constant_override(&"separation", 12)
	add_child(_tabs_bar)
	for fam in _families:
		var tb := Button.new()
		tb.name = "Tab_" + String(fam)
		tb.text = Cosmetics.family_name(fam)
		tb.toggle_mode = true
		tb.focus_mode = Control.FOCUS_ALL
		tb.clip_text = true
		tb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tb.custom_minimum_size = Vector2(160, TAB_H)
		tb.add_theme_font_size_override(&"font_size", 28)
		tb.pressed.connect(_on_tab_pressed.bind(fam))
		_tabs_bar.add_child(tb)
		tab_buttons.append(tb)
	_hint = CharacterCard.make_label("", 22, COL_DIM, 4)
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
	if not _families.has(family):
		family = _families[0]
	refresh()
	if profile.has_signal(&"changed"):
		profile.connect(&"changed", refresh)
	if not Platform.is_touch_mode():
		(cells[0] if not cells.is_empty() else back_button).grab_focus.call_deferred()


# --- Données (statiques : testables sans interface) -------------------------------------------------------------------

## État d'un skin (entrée de Skins.all_skins : trophée ou Panoplie) pour ce profil.
static func state_of(profile_obj: Object, entry: Dictionary) -> State:
	var sid := str(entry.id)
	var cid := str(entry.character.get("id", ""))
	if Skins.is_unlocked(profile_obj, sid):
		return State.EQUIPPED if Skins.equipped(cid, profile_obj) == sid else State.OWNED
	if not Skins.has_assets(cid, sid):
		return State.NO_ART
	return State.BUYABLE if int(profile_obj.get("rubies")) >= SkinShop.price_of(sid) else State.POOR


## État d'un article du catalogue (hors Panoplie) pour ce profil.
static func cosmetic_state(profile_obj: Object, it: Dictionary) -> State:
	var id := str(it.get("id", ""))
	if Cosmetics.is_owned(profile_obj, id):
		var on: String = str(profile_obj.call(&"equipped_cosmetic", Cosmetics.slot_of(it))) if profile_obj.has_method(&"equipped_cosmetic") else ""
		return State.EQUIPPED if on == id else State.OWNED
	if not Cosmetics.has_assets(it):
		return State.NO_ART
	return State.BUYABLE if int(profile_obj.get("rubies")) >= Cosmetics.price_of(id) else State.POOR


static func format_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return ("-" if n < 0 else "") + out


## Nom affiché de la cible d'un article : personnage, biome, ou rien (famille globale).
func target_label(it: Dictionary) -> String:
	var t := Cosmetics.target_of(it)
	match Cosmetics.family_of(it):
		&"ciel":
			return str(BIOME_NAMES.get(t, t.capitalize()))
		&"sillage":
			return "Esquive" if t == Cosmetics.SILLAGE_DODGE else "Pas"
		&"panoplie":
			for c in _chars:
				if c is Dictionary and str(c.get("id", "")) == t:
					return str(c.get("name", t))
			return t
	return ""


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


## Change d'onglet (famille). Sans effet si la famille n'existe pas.
func show_family(fam: StringName) -> void:
	if not _families.has(fam):
		return
	family = fam
	refresh()
	if not Platform.is_touch_mode():
		(cells[0] if not cells.is_empty() else tab_buttons[_families.find(family)]).grab_focus.call_deferred()


func _on_tab_pressed(fam: StringName) -> void:
	CharacterCard.play_ui(&"ui.click", -6.0, 1.0)
	family = fam
	refresh()


func refresh() -> void:
	if _grid == null:
		return
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.queue_free()
	cells.clear()
	ruby_label.text = format_int(int(profile.get("rubies")))
	for i in tab_buttons.size():
		tab_buttons[i].set_pressed_no_signal(_families[i] == family)
	var desc := Cosmetics.family_desc(family)
	_hint.text = (desc + " " if desc != "" else "") + "Cosmétique, payé en rubis : aucun avantage en jeu."
	if family == &"panoplie":
		for e in Skins.all_skins(_chars):
			var cell := _skin_cell(e)
			_grid.add_child(cell)
			cells.append(cell)
	else:
		for it in Cosmetics.items_of(family):
			var cell := _cosmetic_cell(it)
			_grid.add_child(cell)
			cells.append(cell)
	_layout()
	if _focus_id != "":
		for c in cells:
			if c.name == _focus_id and not Platform.is_touch_mode():
				c.grab_focus.call_deferred()
		_focus_id = ""


func _new_cell(nm: String) -> Array:
	var b := Button.new()
	b.name = nm
	b.clip_contents = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.add_theme_stylebox_override(&"normal", CharacterCard.panel_box())
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
	return [b, h]


## Aperçu : texture (portrait, preview) ou, à défaut, cadre vide au nom de la famille (placeholder, pas un asset).
func _preview(tex: Texture2D, dim: bool) -> Control:
	if tex == null:
		var ph := PanelContainer.new()
		ph.name = "Portrait"
		ph.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
		ph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ph.add_theme_stylebox_override(&"panel", CharacterCard.panel_box(Color("#141922"), Color("#3a4150"), 2, 0.9, false))
		var l := CharacterCard.make_label(Cosmetics.family_name(family), 20, COL_DIM, 3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ph.add_child(l)
		return ph
	var pr := TextureRect.new()
	pr.name = "Portrait"
	pr.texture = tex
	pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pr.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if dim:
		pr.modulate = Color(0.45, 0.45, 0.5)
	return pr


func _texts(h: HBoxContainer) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	return v


## Ligne d'état commune : Équipé / Possédé / Bientôt / prix (+ « Acheter » ou « Il manque N »).
func _state_line(v: VBoxContainer, st: State, price: int) -> void:
	match st:
		State.EQUIPPED:
			v.add_child(_line("State", "Équipé · appuyer pour retirer", 24, COL_OK, 1))
		State.OWNED:
			v.add_child(_line("State", "Possédé · Équiper", 24, CharacterCard.COL_FOCUS, 1))
		State.NO_ART:
			var row := HBoxContainer.new()
			row.name = "Price"
			row.add_theme_constant_override(&"separation", 8)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(_ruby_icon(30.0))
			var pl := CharacterCard.make_label(format_int(price), 26, COL_DIM, 5)
			pl.name = "PriceText"
			pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(pl)
			row.add_child(_line("State", SOON_TEXT, 22, COL_DIM, 1))
			v.add_child(row)
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


func _skin_cell(e: Dictionary) -> Button:
	var c: Dictionary = e.character
	var sk: Dictionary = e.skin
	var cid := str(c.get("id", ""))
	var sid := str(e.id)
	var st := state_of(profile, e)
	var price := SkinShop.price_of(sid)
	var parts := _new_cell("Skin_" + sid)
	var b: Button = parts[0]
	var h: HBoxContainer = parts[1]
	b.tooltip_text = "%s — %s\n%s" % [str(c.get("name", "")), str(sk.get("name", "")), str(sk.get("desc", ""))]
	b.set_meta(&"skin_id", sid)
	b.set_meta(&"state", st)
	b.set_meta(&"price", price)
	b.pressed.connect(_on_cell_pressed.bind(sid))
	# Aperçu : portrait du skin (ou preview du catalogue) ; rendu pas livré = portrait par défaut assombri.
	var pi: Dictionary = Skins.portrait_info(cid, sid)
	var tex: Texture2D = pi.tex if bool(pi.exists) else null
	if tex == null and bool(e.get("shop", false)):
		var pp := Cosmetics.preview_path(Cosmetics.item(sid))
		tex = load(pp) as Texture2D if pp != "" else null
	var dim := false
	if tex == null:
		tex = CharacterCard.portrait_info(c, "-").tex
		dim = true
	h.add_child(_preview(tex, dim or st == State.NO_ART))
	var v := _texts(h)
	v.add_child(_line("Character", str(c.get("name", "")), 20, COL_DIM, 1))
	v.add_child(_line("Name", str(sk.get("name", sid)), 30, CharacterCard.COL_TEXT, 1))
	v.add_child(_line("Desc", str(sk.get("desc", "")), 17, COL_DIM, 2))
	_state_line(v, st, price)
	if (st == State.BUYABLE or st == State.POOR) and not bool(e.get("shop", false)):
		v.add_child(_line("Condition", "Ou : " + Skins.quest_text(c, sk), 16, COL_DIM, 1))
	return b


func _cosmetic_cell(it: Dictionary) -> Button:
	var id := str(it.get("id", ""))
	var st := cosmetic_state(profile, it)
	var price := Cosmetics.price_of(id)
	var parts := _new_cell("Cosm_" + id)
	var b: Button = parts[0]
	var h: HBoxContainer = parts[1]
	b.tooltip_text = "%s\n%s" % [str(it.get("name", id)), str(it.get("desc", ""))]
	b.set_meta(&"cosmetic_id", id)
	b.set_meta(&"state", st)
	b.set_meta(&"price", price)
	b.pressed.connect(_on_cosmetic_pressed.bind(id))
	var pp := Cosmetics.preview_path(it)
	h.add_child(_preview(load(pp) as Texture2D if pp != "" else null, st == State.NO_ART))
	var v := _texts(h)
	var tl := target_label(it)
	if tl != "":
		v.add_child(_line("Target", tl, 20, COL_DIM, 1))
	v.add_child(_line("Name", str(it.get("name", id)), 30, CharacterCard.COL_TEXT, 1))
	v.add_child(_line("Desc", str(it.get("desc", "")), 17, COL_DIM, 2))
	_state_line(v, st, price)
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


## Appui sur un carton de skin : équiper / retirer, acheter (après confirmation) ou expliquer pourquoi c'est impossible.
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
			_after_change()
		State.OWNED:
			profile.call(&"set_selected_skin", StringName(cid), sid)
			_after_change()
		State.BUYABLE:
			await _buy_flow(sid, str(e.skin.get("name", sid)), str(e.character.get("name", "")), SkinShop.price_of(sid), true)
		State.POOR:
			show_toast("Il vous manque %s rubis." % format_int(SkinShop.price_of(sid) - int(profile.get("rubies"))))
		State.NO_ART:
			show_toast("Bientôt : ce skin n'est pas encore disponible.")


## Appui sur un carton d'article (Ciel, Sillage, Parement, Veillée).
func _on_cosmetic_pressed(id: String) -> void:
	if _busy:
		return
	var it := Cosmetics.item(id)
	if it.is_empty():
		return
	_focus_id = "Cosm_" + id
	CharacterCard.play_ui(&"ui.click", -6.0, 1.0)
	var sk := Cosmetics.slot_of(it)
	match cosmetic_state(profile, it):
		State.EQUIPPED:
			profile.call(&"equip_cosmetic", sk, "")
			_applied(it)
		State.OWNED:
			profile.call(&"equip_cosmetic", sk, id)
			_applied(it)
		State.BUYABLE:
			await _buy_flow(id, str(it.get("name", id)), target_label(it), Cosmetics.price_of(id), false)
		State.POOR:
			show_toast("Il vous manque %s rubis." % format_int(Cosmetics.price_of(id) - int(profile.get("rubies"))))
		State.NO_ART:
			show_toast("Bientôt : cet article n'est pas encore disponible.")


## Effet immédiat d'un équipement là où il se voit depuis le menu (le Parement habille la boutique elle-même).
func _applied(it: Dictionary) -> void:
	if Cosmetics.family_of(it) == &"parement" and profile == Profile:
		UiTheme.refresh_parement()
	_after_change()


func _after_change() -> void:
	if not profile.has_signal(&"changed"):
		refresh()


func _buy_flow(id: String, nm: String, sub: String, price: int, is_skin: bool) -> void:
	_busy = true
	var left := int(profile.get("rubies")) - price
	var title := "Acheter « %s » ?" % nm
	var line := "%s%s rubis.\nIl vous en restera %s. Achat cosmétique, définitif." % [(sub + " · ") if sub != "" else "", format_int(price), format_int(left)]
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
	var res: StringName = profile.call(&"buy_skin" if is_skin else &"buy_cosmetic", id)
	if res == &"ok":
		CharacterCard.play_ui(&"ui.item_pick", -4.0, 1.0)
		show_toast("%s acquis : %s. Appuyez dessus pour l'équiper." % ["Skin" if is_skin else "Article", nm])
	elif res == &"poor":
		show_toast("Il vous manque %s rubis." % format_int(price - int(profile.get("rubies"))))
	elif res == &"owned":
		show_toast("Vous le possédez déjà.")
	elif res == &"no_art":
		show_toast("Bientôt : pas encore disponible.")
	else:
		show_toast("Achat impossible.")
	_after_change()


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
	if back_button == null or tab_buttons.is_empty():
		return
	var cols := maxi(columns, 1)
	var tab_btn: Button = tab_buttons[maxi(_families.find(family), 0)]
	for i in tab_buttons.size():
		var tb := tab_buttons[i]
		tb.focus_neighbor_left = tb.get_path_to(tab_buttons[i - 1] if i > 0 else tb)
		tb.focus_neighbor_right = tb.get_path_to(tab_buttons[i + 1] if i + 1 < tab_buttons.size() else tb)
		tb.focus_neighbor_top = tb.get_path_to(tb)
		tb.focus_neighbor_bottom = tb.get_path_to(cells[0] if not cells.is_empty() else back_button)
	for i in cells.size():
		var c := cells[i]
		c.focus_neighbor_left = c.get_path_to(cells[i - 1] if i % cols != 0 else c)
		c.focus_neighbor_right = c.get_path_to(cells[i + 1] if i % cols != cols - 1 and i + 1 < cells.size() else c)
		c.focus_neighbor_top = c.get_path_to(cells[i - cols] if i - cols >= 0 else tab_btn)
		c.focus_neighbor_bottom = c.get_path_to(cells[i + cols] if i + cols < cells.size() else back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(cells[cells.size() - 1] if not cells.is_empty() else tab_btn)
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
	_banner.size = Vector2(minf(520.0, w * 0.45), maxf(92.0, _banner.get_combined_minimum_size().y))
	_ruby_box.reset_size()
	_ruby_box.position = Vector2(vs.x - m.right - _ruby_box.size.x, 24 + (_banner.size.y - _ruby_box.size.y) * 0.5)
	back_button.position = Vector2(m.left, vs.y - m.bottom - back_button.size.y)
	var y: float = _banner.position.y + _banner.size.y + 12.0
	# Onglets : largeur partagée selon l'écran (paysage étroit compris), jamais au-delà de TAB_W_MAX.
	var n := maxi(tab_buttons.size(), 1)
	var tab_w := clampf((w - 12.0 * (n - 1)) / n, 120.0, TAB_W_MAX)
	for tb in tab_buttons:
		tb.custom_minimum_size = Vector2(tab_w, TAB_H)
	_tabs_bar.position = Vector2(m.left, y)
	_tabs_bar.reset_size()
	y += _tabs_bar.size.y + 8.0
	_hint.position = Vector2(m.left, y)
	_hint.size = Vector2(w, 32)
	y += 38.0
	_scroll.position = Vector2(m.left, y)
	_scroll.size = Vector2(w, maxf(back_button.position.y - 16.0 - y, 120.0))
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
	if not is_visible_in_tree() or dialog != null:
		return
	var step := 0
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		step = -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1
	elif event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_Q or event.physical_keycode == KEY_E):
		step = -1 if event.physical_keycode == KEY_Q else 1
	if step != 0 and not _families.is_empty():
		get_viewport().set_input_as_handled()
		CharacterCard.play_ui(&"ui.click", -6.0, 1.0)
		var i := (maxi(_families.find(family), 0) + step + _families.size()) % _families.size()
		show_family(_families[i])
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
