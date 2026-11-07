class_name ForgePanel
extends VBoxContainer
## Onglet « Forge » de l'inventaire (docs/Design_Forge.md). Trois étapes, un appui chacune :
##  1. liste des recettes (carnet complet ; les recettes réalisables en tête, mises en avant) ;
##  2. choix des ingrédients : ItemPicker multi, pré-rempli avec les objets les moins utiles (Forge.auto_fill) ;
##  3. confirmation : « Vous perdez : … » en rouge, « Vous gagnez : … » en vert, bouton Forger.
## Souris / tactile : un clic ou un appui ; clavier et manette : focus + A / Entrée ; B / Échap : étape précédente
## (PauseMenu appelle back()). Tout est par joueur : l'état est celui du joueur local (LocalState), un spectateur forge aussi.
## Le cadre « forgé » cuivré est un PLACEHOLDER en code (Palette.FORGE_COLOR) : le vrai cadre est un asset Codex.

signal crafted(item_id: StringName)

const ITEM_ICON := "res://assets/sprites/icons/items/%s.png"
const COL_LOSE := Color(1.0, 0.45, 0.4)
const COL_GAIN := Color(0.55, 0.95, 0.6)
const COL_COPPER := Palette.FORGE_COLOR

var state: PlayerState ## null = joueur local au moment de l'affichage
var step := &"list" ## list | confirm (le sélecteur est un ItemPicker modal)
var recipe_buttons: Dictionary = {} ## id de recette -> Button (tests)
var confirm_button: Button = null
var status_label: Label = null
var picker: ItemPicker = null

var _s := 1.0
var _head: Label
var _core_row: HBoxContainer ## icônes des noyaux d'orage (pleine = porté, estompée = libre)
const CORE_ICON := "res://assets/sprites/icons/storm_core.png"
const FRAME_DIR := "res://assets/sprites/ui/forge/" ## lot UX-E : cartes de recette et de gain (9-slice Codex)
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _detail: Label
var _confirm_box: VBoxContainer
var _pending_recipe: Dictionary = {}
var _pending_ids: Array[StringName] = []


func _init() -> void:
	name = "ForgePanel"
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()


func _build() -> void:
	_head = Label.new()
	_head.name = "Head"
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_head)
	_core_row = HBoxContainer.new()
	_core_row.name = "CoreRow"
	_core_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_core_row.add_theme_constant_override("separation", 8)
	add_child(_core_row)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.follow_focus = true
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_list_scroll.add_child(_list)
	_detail = Label.new()
	_detail.name = "Detail"
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	add_child(_detail)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	_confirm_box = VBoxContainer.new()
	_confirm_box.name = "Confirm"
	_confirm_box.add_theme_constant_override("separation", 10)
	_confirm_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_confirm_box.visible = false
	add_child(_confirm_box)


## Échelle de l'interface (PauseMenu._scale) : polices et tailles des lignes.
func set_ui_scale(s: float, width: float, height: float) -> void:
	_s = s
	custom_minimum_size = Vector2(width, height)
	_head.add_theme_font_size_override("font_size", _fs(26))
	_detail.add_theme_font_size_override("font_size", _fs(24))
	status_label.add_theme_font_size_override("font_size", _fs(24))
	for b in recipe_buttons.values():
		(b as Button).custom_minimum_size.y = 128.0 * s
		(b as Button).add_theme_font_size_override("font_size", _fs(26))
		_fit_recipe_icon(b as Button)


func _fs(base: int) -> int:
	return maxi(int(base * _s), HudMetrics.floor_px())


func _st() -> PlayerState:
	return state if state != null else LocalState.state()


# --- Étape 1 : liste des recettes ----------------------------------------------------------------

## Reconstruit la liste (noyaux, recettes réalisables en tête). Revient à l'étape « liste ».
func refresh() -> void:
	_show_step(&"list")
	var st := _st()
	_head.text = "Noyaux d'orage : %d/%d" % [st.catalysts, Balance.CRAFT_CATALYST_CAP]
	_head.add_theme_color_override("font_color", COL_COPPER if st.catalysts > 0 else UiTheme.COL_MUTED)
	_refresh_cores(st.catalysts)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	recipe_buttons.clear()
	var ordered: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for r in Forge.recipes(): # réalisables d'abord, l'ordre du fichier est gardé dans chaque groupe
		if Forge.can_craft(r, st):
			ordered.append(r)
		else:
			rest.append(r)
	ordered.append_array(rest)
	var first: Button = null
	for r in ordered:
		var b := _make_recipe_button(r, st)
		_list.add_child(b)
		recipe_buttons[r["id"]] = b
		if first == null:
			first = b
	_wire_focus()
	status_label.text = ""
	_detail.text = "Un noyau d'orage s'obtient en vainquant un boss d'étage ou en ouvrant un reliquaire secret."
	set_ui_scale(_s, custom_minimum_size.x, custom_minimum_size.y)


func _make_recipe_button(r: Dictionary, st: PlayerState) -> Button:
	var it := ItemDB.get_item(r["result"])
	var ok := Forge.can_craft(r, st)
	var why := Forge.blocked_reason(r, st)
	var b := Button.new()
	b.name = "Recipe_%s" % r["id"]
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var parts: Array[String] = []
	for role in Forge.roles(r):
		parts.append(Forge.role_text(role))
	var state_txt := "Réalisable maintenant" if ok else (why if why != "" else "Ingrédients manquants")
	b.text = "%s  ·  Rang %s\n%s\n%s" % [str(it.get("name", r["result"])), "I" if int(r["tier"]) == 1 else "II",
		" + ".join(parts), state_txt]
	b.tooltip_text = "%s\n%s" % [str(it.get("effect_text", "")), str(r.get("hint", ""))]
	var fg := Color.WHITE if ok else Color(0.8, 0.8, 0.82)
	for k in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		b.add_theme_color_override(k, fg)
	var tex_sb := UiTheme.da_box("forge_recipe_9slice" if ok else "forge_recipe_9slice_off", 1.0, 0, FRAME_DIR)
	for sname in ["normal", "hover", "pressed", "focus", "disabled"]:
		if tex_sb != null: # carte cuivrée Codex ; le focus garde sa bordure de code (système de focus)
			if sname == "focus":
				var fb := StyleBoxFlat.new()
				fb.draw_center = false
				fb.border_color = UiTheme.COL_FOCUS
				fb.set_border_width_all(7)
				fb.set_corner_radius_all(6)
				fb.content_margin_left = 16
				fb.content_margin_right = 16
				fb.content_margin_top = 12
				fb.content_margin_bottom = 12
				b.add_theme_stylebox_override(sname, fb)
				continue
			var tb := tex_sb.duplicate() as StyleBoxTexture
			if sname == "hover" or sname == "pressed":
				tb.modulate_color = Color(1.18, 1.18, 1.18)
			tb.content_margin_left = 16
			tb.content_margin_right = 16
			tb.content_margin_top = 12
			tb.content_margin_bottom = 12
			b.add_theme_stylebox_override(sname, tb)
			continue
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.20, 0.12, 0.07, 0.96) if ok else Color(0.11, 0.10, 0.14, 0.94)
		if sname == "hover" or sname == "pressed":
			sb.bg_color = sb.bg_color.lightened(0.1)
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(6 if ok else 3)
		sb.border_color = COL_COPPER if ok else COL_COPPER.darkened(0.55)
		if sname == "focus":
			sb.border_color = UiTheme.COL_FOCUS
			sb.set_border_width_all(7)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override(sname, sb)
	var icon_box := _icon_box(r["result"], 96.0)
	icon_box.name = "RecipeIcon"
	icon_box.anchor_top = 0.5
	icon_box.anchor_bottom = 0.5
	icon_box.modulate = Color.WHITE if ok else Color(1, 1, 1, 0.6)
	b.add_child(icon_box)
	var role_tags: Array = []
	for role in Forge.roles(r):
		role_tags.append_array(role["tags"])
	var tag_row := TagIcons.row(role_tags, 36.0, Color(0.85, 0.92, 1.0) if ok else Color(0.65, 0.68, 0.74)) # lot UX-G
	if tag_row.get_child_count() > 0:
		tag_row.anchor_left = 1.0
		tag_row.anchor_right = 1.0
		tag_row.anchor_top = 0.5
		tag_row.anchor_bottom = 0.5
		tag_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		tag_row.grow_vertical = Control.GROW_DIRECTION_BOTH
		b.add_child(tag_row)
	else:
		tag_row.free()
	b.pressed.connect(_on_recipe_pressed.bind(r["id"]))
	var show := func() -> void:
		_detail.text = "%s\n%s" % [str(it.get("effect_text", "")), str(r.get("hint", ""))]
	b.focus_entered.connect(show)
	b.mouse_entered.connect(show)
	return b


## Icône du résultat à gauche de la ligne : place réservée par la marge gauche des styles, taille suivant l'échelle.
func _fit_recipe_icon(b: Button) -> void:
	var box := b.get_node_or_null("RecipeIcon") as Control
	if box == null:
		return
	var px := 96.0 * _s
	box.offset_left = 14.0 * _s
	box.offset_right = 14.0 * _s + px
	box.offset_top = -px * 0.5
	box.offset_bottom = px * 0.5
	var tags := b.get_node_or_null("TagIcons") as Control
	var tags_w := 0.0
	if tags != null: # pictos d'étiquettes à droite de la ligne (lot UX-G) : marge droite réservée
		var n := tags.get_child_count()
		tags_w = (n * 40.0 - 4.0) * _s
		for c in tags.get_children():
			(c as Control).custom_minimum_size = Vector2(36.0, 36.0) * _s
		tags.offset_right = -14.0 * _s
		tags.offset_left = -14.0 * _s - tags_w
	for sname in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := b.get_theme_stylebox(sname)
		if sb is StyleBoxFlat or sb is StyleBoxTexture:
			sb.content_margin_left = 28.0 * _s + px
			sb.content_margin_right = 16.0 + (tags_w + 14.0 * _s if tags != null else 0.0)


## Icône d'objet dans son fond (cadre cuivré « forgé » pour un objet forgé, sinon fond de qualité), `px` à l'échelle 1.
## Sans icône livrée : initiales. Le contrôle suit son offset (à placer par l'appelant) et ignore la souris.
func _icon_box(id: StringName, px: float) -> Control:
	var it := ItemDB.get_item(id)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2.ONE * px * _s
	holder.add_child(ItemBar.quality_backing(it.get("quality", "commun")))
	var path := ITEM_ICON % id
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path) as Texture2D
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		holder.add_child(t)
	else:
		var f := Label.new()
		f.text = str(it.get("name", id)).left(2)
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		f.add_theme_font_size_override("font_size", _fs(int(px * 0.4)))
		holder.add_child(f)
	return holder


## Ligne « icône + texte » de la liste « Vous perdez ».
func _lose_row(row_name: String, text: String, icon: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = row_name
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", int(12 * _s))
	h.add_child(icon)
	var l := _label(text, 28, COL_LOSE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


func _wire_focus() -> void:
	var btns: Array = recipe_buttons.values()
	for i in btns.size():
		var b: Button = btns[i]
		b.focus_neighbor_left = NodePath(".")
		b.focus_neighbor_right = NodePath(".")
		b.focus_neighbor_top = b.get_path_to(btns[i - 1]) if i > 0 else NodePath(".")
		b.focus_neighbor_bottom = b.get_path_to(btns[i + 1]) if i + 1 < btns.size() else NodePath(".")


## Premier bouton de recette (focus clavier / manette à l'ouverture de l'onglet).
func first_button() -> Control:
	for b in recipe_buttons.values():
		return b
	return null


func say(msg: String, ok := false) -> void:
	status_label.text = msg
	status_label.add_theme_color_override("font_color", COL_GAIN if ok else COL_LOSE)


# --- Étape 2 : choix des ingrédients -------------------------------------------------------------

func _on_recipe_pressed(rid: StringName) -> void:
	open_recipe(rid)


## Ouvre le sélecteur d'ingrédients de la recette `rid` (public : tests). Refus écrit si noyau / ingrédients manquent.
func open_recipe(rid: StringName) -> void:
	var r := Forge.recipe(rid)
	var st := _st()
	var why := Forge.blocked_reason(r, st)
	if why != "":
		say(why)
		return
	var fill := Forge.auto_fill(r, st)
	if fill.is_empty():
		say("Il vous manque des ingrédients pour cette recette.")
		return
	var entries := _entries_for(r, st)
	var keys: Array = []
	var taken := {}
	for id in fill: # clé d'entrée du premier exemplaire libre de chaque objet pré-rempli
		for e in entries:
			if e["id"] == id and not taken.has(e["key"]):
				taken[e["key"]] = true
				keys.append(e["key"])
				break
	var n := Forge.roles(r).size()
	picker = ItemPicker.open(self, {
		"title": "Forger : %s" % str(ItemDB.get_item(r["result"]).get("name", r["result"])),
		"subtitle": "Choisissez %d objets. Les moins utiles sont déjà proposés." % n,
		"entries": entries, "multi": n, "preselect": keys, "layer": 110, "state": st,
		"confirm_label": "Continuer", "ready_text": "Prêt : vérifiez ce que vous perdez à l'étape suivante.",
		"validate": func(chosen: Array) -> String:
			return Forge.selection_reason(r, chosen.map(func(e: Dictionary) -> StringName: return e["id"]), st),
	})
	picker.picked.connect(func(chosen: Array) -> void:
		var ids: Array[StringName] = []
		for e in chosen:
			ids.append(StringName(str(e["id"])))
		show_confirm(r, ids))


## Cartes du sélecteur : un exemplaire par carte (jusqu'au nombre de rôles), seulement les objets qui peuvent servir.
func _entries_for(r: Dictionary, st: PlayerState) -> Array:
	var out: Array = []
	var rl := Forge.roles(r)
	var ids: Array = st.items.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ua := Forge.usefulness(StringName(a), st)
		var ub := Forge.usefulness(StringName(b), st)
		return ua < ub if ua != ub else str(a) < str(b))
	for raw in ids:
		var id := StringName(raw)
		var avail := Forge.spendable(id, st)
		if avail <= 0:
			continue
		var uses: Array[String] = []
		for role in rl:
			if Forge.fits(id, role):
				var t := ("Clé " + "/".join((role["tags"] as Array).map(func(x: Variant) -> String: return "[%s]" % str(x)))) if bool(role["key"]) else "Quelconque"
				if not uses.has(t):
					uses.append(t)
		if uses.is_empty():
			continue
		for k in mini(avail, rl.size()):
			out.append({"key": "%s#%d" % [id, k], "id": id, "line": " · ".join(uses), "enabled": true, "reason": "", "count": st.stacks(id)})
	return out


# --- Étape 3 : confirmation ----------------------------------------------------------------------

## Écran « Vous perdez / Vous gagnez » (public : tests).
func show_confirm(r: Dictionary, ids: Array[StringName]) -> void:
	_pending_recipe = r
	_pending_ids = ids
	_show_step(&"confirm")
	for c in _confirm_box.get_children():
		_confirm_box.remove_child(c)
		c.queue_free()
	var res := ItemDB.get_item(r["result"])
	_confirm_box.add_child(_label("Forger : %s" % str(res.get("name", r["result"])), 34, COL_COPPER))
	var lose := _label("Vous perdez :", 30, COL_LOSE)
	lose.name = "LoseTitle"
	_confirm_box.add_child(lose)
	var counts := {}
	for id in ids:
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		var txt := "%s%s" % [str(ItemDB.get_item(id).get("name", id)), " ×%d" % counts[id] if int(counts[id]) > 1 else ""]
		_confirm_box.add_child(_lose_row("Lose_%s" % id, txt, _icon_box(id, 64.0)))
	_confirm_box.add_child(_lose_row("Lose_core", "1 noyau d'orage", _core_icon(64.0)))
	var gain := _label("Vous gagnez :", 30, COL_GAIN)
	gain.name = "GainTitle"
	_confirm_box.add_child(gain)
	_confirm_box.add_child(_gain_card(res, r["result"]))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_confirm_box.add_child(row)
	confirm_button = Button.new()
	confirm_button.name = "ForgeButton"
	confirm_button.text = "Forger"
	confirm_button.custom_minimum_size = Vector2(240 * _s, UiTheme.MIN_TOUCH * _s)
	confirm_button.pressed.connect(do_craft)
	UiTheme.primary(confirm_button)
	row.add_child(confirm_button)
	var change := Button.new()
	change.name = "ChangeButton"
	change.text = "Changer les objets"
	change.custom_minimum_size = Vector2(300 * _s, UiTheme.MIN_TOUCH * _s)
	change.pressed.connect(func() -> void: open_recipe(_pending_recipe["id"]))
	row.add_child(change)
	var back_b := Button.new()
	back_b.name = "BackButton"
	back_b.text = "Annuler"
	back_b.custom_minimum_size = Vector2(200 * _s, UiTheme.MIN_TOUCH * _s)
	back_b.pressed.connect(back)
	UiTheme.mark_back(back_b)
	row.add_child(back_b)
	if Platform.input_mode != Platform.InputMode.TOUCH:
		confirm_button.grab_focus.call_deferred()


## Carte du gain : icône (ou initiales), nom, effet, dans le cadre cuivré « forgé » (placeholder).
func _gain_card(res: Dictionary, id: StringName) -> Control:
	var p := PanelContainer.new()
	p.name = "GainCard"
	var gain_sb: StyleBox = UiTheme.da_box("forge_gain_9slice", 1.0, 0, FRAME_DIR)
	if gain_sb != null:
		gain_sb.set_content_margin_all(18)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.20, 0.12, 0.07, 0.96)
		sb.border_color = COL_COPPER
		sb.set_border_width_all(6)
		sb.set_corner_radius_all(14)
		sb.set_content_margin_all(12)
		gain_sb = sb
	p.add_theme_stylebox_override("panel", gain_sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(88, 88) * _s
	var path := ITEM_ICON % id
	if ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D
	if icon.texture != null and ResourceLoader.exists(ItemBar.FORGE_FRAME): # fond cuivré « forgé » derrière l'icône
		var back := TextureRect.new()
		back.name = "ForgeBack"
		back.texture = load(ItemBar.FORGE_FRAME) as Texture2D
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.custom_minimum_size = icon.custom_minimum_size
		back.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		h.add_child(back)
	else:
		h.add_child(icon)
	if icon.texture == null: # icône absente : initiales
		icon.queue_free()
		var f := _label(str(res.get("name", id)).left(2), 40, COL_COPPER)
		f.custom_minimum_size = Vector2(88, 88) * _s
		f.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(f)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nm := _label("%s  ·  Forgé" % str(res.get("name", id)), 28, COL_COPPER)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(nm)
	var fx := _label(str(res.get("effect_text", "")), 22, COL_GAIN)
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(fx)
	return p


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", _fs(size))
	l.add_theme_color_override("font_color", color)
	return l


## Forge pour de bon (bouton « Forger » de la confirmation). Retourne le résultat de Forge.craft.
func do_craft() -> Dictionary:
	var res := Forge.craft(get_tree(), _pending_recipe.get("id", &""), _pending_ids, _st())
	if bool(res["ok"]):
		var item: StringName = res["item"]
		Audio.play_ui(&"forge_craft")
		refresh()
		say("Forgé : %s" % str(ItemDB.get_item(item).get("name", item)), true)
		crafted.emit(item)
	else:
		say(str(res["reason"]))
		_show_step(&"list")
	return res


## Icône du noyau d'orage (ligne « Vous perdez ») ; initiale si l'asset manque.
func _core_icon(px: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2.ONE * px * _s
	if ResourceLoader.exists(CORE_ICON):
		var t := TextureRect.new()
		t.texture = load(CORE_ICON) as Texture2D
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(t)
	return holder


## Une icône de noyau par emplacement (Balance.CRAFT_CATALYST_CAP) : pleine si portée, estompée sinon.
func _refresh_cores(owned: int) -> void:
	for c in _core_row.get_children():
		_core_row.remove_child(c)
		c.queue_free()
	var tex := load(CORE_ICON) as Texture2D if ResourceLoader.exists(CORE_ICON) else null
	for i in Balance.CRAFT_CATALYST_CAP:
		var full := i < owned
		if tex == null: # repli texte si l'icône manque
			var l := Label.new()
			l.text = "●" if full else "○"
			_core_row.add_child(l)
			continue
		var r := TextureRect.new()
		r.name = "Core%d" % i
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2.ONE * 48.0 * _s
		r.modulate = Color.WHITE if full else Color(1, 1, 1, 0.28)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_core_row.add_child(r)


func _show_step(s: StringName) -> void:
	step = s
	var list_on := s == &"list"
	_head.visible = list_on
	_core_row.visible = list_on
	_list_scroll.visible = list_on
	_detail.visible = list_on
	_confirm_box.visible = s == &"confirm"


## B / Échap : revient à la liste depuis la confirmation. Vrai si la touche a été consommée ici.
func back() -> bool:
	if step == &"confirm":
		var keep := status_label.text
		refresh()
		status_label.text = keep
		var f := first_button()
		if f != null and Platform.input_mode != Platform.InputMode.TOUCH:
			f.grab_focus.call_deferred()
		return true
	return false
