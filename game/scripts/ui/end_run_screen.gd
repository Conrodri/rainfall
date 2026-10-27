class_name EndRunScreen
extends RunScreens
## Récap de fin de run (docs/Design_Menus.md §3.10), scène `scenes/ui/end_run.tscn`.
## Voile 85 %, titre selon l'issue, ligne d'infos, 4 tuiles (piliers, monstres, objets, or restant),
## compteur de rubis animé (1,2 s), ligne de déblocage, boutons « Rejouer » (gauche) / « Continuer »
## (principal, droite). Échap/B = Continuer, seulement après l'animation.
## Hérite de RunScreens pour garder `texts()` / `press(i)` (tests) ; style via UiTheme (lot A).
## Usage : var s := EndRunScreen.create(info); add_child(s); s.continue_pressed / s.replay_pressed.
## info : {victory, reason, character_name, mode, stage, active_time_s, level, pillars, kills,
##         items, gold, rubies, unlocks: Array[StringName], next_objective (optionnel : {title, text, progress},
##         sinon calculé depuis le Profil en lecture seule)}

signal continue_pressed
signal replay_pressed

const SCENE := "res://scenes/ui/end_run.tscn"
const COUNT_TIME_S := 1.2
const TICK_S := 0.09
const MAX_TICKS := 12
const COL_TITLE_WIN := UiTheme.COL_PRIMARY_TEXT
const COL_TITLE_LOSS := UiTheme.COL_BORDER
const COL_UNLOCK := UiTheme.COL_FOCUS
const COL_OUTLINE := UiTheme.COL_OUTLINE
const COL_TEXT := UiTheme.COL_TEXT
const COL_DIM := UiTheme.COL_MUTED
const TILE_SIZE := Vector2(280, 160)
const RUBY_ICONS := ["res://assets/sprites/ui/da/icon_ruby.png", "res://assets/sprites/ui/menu/ruby_large.png", "res://assets/sprites/ui/hud/icon_ruby.png"]
const STAT_ICON := "res://assets/sprites/ui/menu/stat_%s.png"
const STAT_ICON_FALLBACK := {"gold": "res://assets/sprites/ui/da/icon_gold.png", "pillar": "res://assets/sprites/ui/da/minimap_pillar.png",
	"kills": "res://assets/sprites/ui/da/minimap_boss.png", "items": "res://assets/sprites/ui/da/minimap_chest.png"}
const DA_RUBY := "res://assets/sprites/ui/da/icon_ruby.png"
const ITEM_ICON := "res://assets/sprites/icons/items/%s.png"
const RARITY_FRAME := "res://assets/sprites/icons/frame_%s.png"
const PANEL_DARK := "res://assets/sprites/ui/menu/panel_dark_9slice.png"
const UNLOCK_TEXTS := {&"mode:difficile": "Mode Difficile débloqué !"}

var info := {}
var animating := true
var shown_rubies := 0 ## valeur affichée du compteur (tests, capture)

var _content: VBoxContainer ## contenu défilant (au-dessus des boutons)
var _frame: PanelContainer
var _scroll: ScrollContainer
var _btn_row: HBoxContainer ## zone de boutons fixe, toujours visible en bas
var _variant_name: Label
var _variant_cells: Array[Button] = []
var _variant_caps: Array = [] ## [{holder: Control, slot: int}]
var _ruby_label: Label
var _continue_btn: Button
var _replay_btn: Button
var _ticks := 0
var _last_tick := -1.0


static func create(p_info: Dictionary) -> EndRunScreen:
	var s: EndRunScreen
	if ResourceLoader.exists(SCENE):
		s = (load(SCENE) as PackedScene).instantiate() as EndRunScreen
	if s == null:
		s = EndRunScreen.new()
	s.info = p_info
	return s


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER_SCREENS
	name = &"EndRunScreen"
	_build()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	if Platform.input_mode != Platform.InputMode.TOUCH:
		_continue_btn.grab_focus.call_deferred()
	_start_counter()


# --- Construction ---------------------------------------------------------------

func _label(text: String, size: int, color := COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", maxi(size, HudMetrics.floor_px())) # plancher 18 px PC / 26 px mobile
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", COL_OUTLINE)
	l.add_theme_constant_override("outline_size", 8)
	l.set_meta(&"base_size", size)
	return l


func _icon(paths: Array, px: int) -> TextureRect:
	for p in paths:
		if p != "" and ResourceLoader.exists(p):
			var t := TextureRect.new()
			t.texture = load(p) as Texture2D
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.custom_minimum_size = Vector2(px, px)
			t.set_meta(&"base_px", px)
			return t
	return null


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_frame = PanelContainer.new() # grand panneau DA
	center.add_child(_frame)
	var outer := VBoxContainer.new() # [contenu défilant | boutons fixes]
	outer.set_meta(&"sep", 20)
	_frame.add_child(outer)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_box = _content

	var victory := bool(info.get("victory", false))
	var reason := StringName(str(info.get("reason", "victory" if victory else "death")))
	var title := "Victoire !" if victory else ("Run abandonnée" if reason == &"abandon" else "Vous êtes tombé")
	var banner := PanelContainer.new() # bandeau de titre (header_banner)
	banner.theme_type_variation = &"HeaderPanel"
	_content.add_child(banner)
	var tl := _label(title, 64, COL_TITLE_WIN if victory else COL_TITLE_LOSS)
	tl.add_theme_font_override("font", UiTheme.title_font())
	banner.add_child(tl)
	_labels.append(tl)
	_add(_label(info_line(info), 36, COL_DIM))
	_content.add_child(HSeparator.new())
	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.set_meta(&"sep", 24)
	_content.add_child(tiles)
	tiles.add_child(_tile("pillar", "Piliers", int(info.get("pillars", 0))))
	tiles.add_child(_tile("kills", "Monstres", int(info.get("kills", 0))))
	tiles.add_child(_tile("items", "Objets", int(info.get("items", 0))))
	tiles.add_child(_tile("gold", "Or restant", int(info.get("gold", 0))))

	var ruby_row := HBoxContainer.new()
	ruby_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ruby_row.set_meta(&"sep", 20)
	_content.add_child(ruby_row)
	var ri := _icon(RUBY_ICONS, 64)
	if ri != null:
		ruby_row.add_child(ri)
	_ruby_label = _label(ruby_text(0), 56, COL_TITLE_WIN)
	_labels.append(_ruby_label)
	ruby_row.add_child(_ruby_label)
	var mode := StringName(str(info.get("mode", "moyen")))
	if mode != &"moyen" and Balance.RUBY_MODE_MULT.has(mode):
		ruby_row.add_child(_label("(×%s %s)" % [_fr_num(Balance.RUBY_MODE_MULT[mode]), RunSave.mode_name(mode)], 32, COL_DIM))

	var detail := ruby_breakdown(info)
	if detail != "":
		var dl := _label(detail, 26, COL_DIM)
		dl.name = "RubyDetail"
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.set_meta(&"base", Vector2(1000, 0))
		dl.custom_minimum_size = Vector2(1000, 0)
		_add(dl)

	_add_items_strip()
	# déblocages sous les stats et les objets de la run (demande du joueur, 27/10/2026)
	if not (info.get("unlocks", []) as Array).is_empty():
		_content.add_child(HSeparator.new())
	var variant_keys: Array[StringName] = []
	for u0 in info.get("unlocks", []):
		if String(u0).begins_with("spell:"):
			variant_keys.append(StringName(u0))
	_add_variants_block(variant_keys)
	var item_keys: Array[StringName] = []
	for u1 in info.get("unlocks", []):
		if String(u1).begins_with("item:"):
			item_keys.append(StringName(u1))
	_add_new_items_block(item_keys)

	for u in info.get("unlocks", []):
		var key := StringName(u)
		if String(key).begins_with("spell:") or String(key).begins_with("item:"):
			continue # regroupées dans UN bloc compact (évite de pousser les boutons hors écran)
		var urow := HBoxContainer.new()
		urow.alignment = BoxContainer.ALIGNMENT_CENTER
		urow.set_meta(&"sep", 16)
		_content.add_child(urow)
		var up := unlock_icon_path(key)
		var uic := _icon([up], 72) if up != "" else null
		if uic != null:
			uic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			urow.add_child(uic)
		var ul := _label(unlock_text(key), 40, COL_UNLOCK)
		urow.add_child(ul)
		_labels.append(ul)

	_add_next_objective()
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.set_meta(&"sep", 48)
	_btn_row = buttons
	_frame.get_child(0).add_child(buttons) # hors du défilement : toujours visibles
	_replay_btn = Button.new()
	_replay_btn.text = "Rejouer"
	_replay_btn.set_meta(&"base", Vector2(620, 120))
	_replay_btn.pressed.connect(_on_replay)
	buttons.add_child(_replay_btn)
	_continue_btn = Button.new()
	_continue_btn.text = "Continuer"
	_continue_btn.set_meta(&"base", Vector2(720, 120))
	_continue_btn.pressed.connect(_on_continue)
	buttons.add_child(_continue_btn)
	UiTheme.primary(_continue_btn)
	_buttons = [_replay_btn, _continue_btn]
	if not _variant_cells.is_empty():
		_replay_btn.focus_neighbor_top = _replay_btn.get_path_to(_variant_cells[0])
		_continue_btn.focus_neighbor_top = _continue_btn.get_path_to(_variant_cells[_variant_cells.size() - 1])
	_replay_btn.focus_neighbor_right = _replay_btn.get_path_to(_continue_btn)
	_continue_btn.focus_neighbor_left = _continue_btn.get_path_to(_replay_btn)
	UiTheme.apply(_root)
	UiTheme.hook_sounds(_root)


## Tuile sombre : panel_dark_9slice.png (§7) s'il existe, sinon placeholder §2.5 aux couleurs UiTheme.
func _dark_panel() -> StyleBox:
	var da := UiTheme.da_box("panel_small_9slice", 0.5)
	if da != null:
		return da
	if ResourceLoader.exists(PANEL_DARK):
		var t := StyleBoxTexture.new()
		t.texture = load(PANEL_DARK) as Texture2D
		t.set_texture_margin_all(32)
		t.set_content_margin_all(16)
		return t
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.COL_PANEL_DARK
	sb.border_color = UiTheme.COL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	return sb


## « Prochain objectif » : titre + condition, et une barre de progression si elle est connue.
func _add_next_objective() -> void:
	var obj: Dictionary
	if info.has("next_objective") and info["next_objective"] is Dictionary:
		obj = info["next_objective"]
	else:
		obj = next_objective(Profile, CharacterCard.load_characters())
	if obj.is_empty():
		return
	var box := VBoxContainer.new()
	box.name = "NextObjective"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_meta(&"sep", 6)
	_content.add_child(box)
	var head := _label("Prochain objectif : %s" % str(obj.get("title", "")), 32, COL_UNLOCK)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.set_meta(&"base", Vector2(1000, 0))
	head.custom_minimum_size = Vector2(1000, 0)
	box.add_child(head)
	_labels.append(head)
	var txt := str(obj.get("text", ""))
	if txt != "":
		var tl := _label(txt, 26, COL_DIM)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.set_meta(&"base", Vector2(1000, 0))
		tl.custom_minimum_size = Vector2(1000, 0)
		box.add_child(tl)
		_labels.append(tl)
	var prog := float(obj.get("progress", -1.0))
	if prog >= 0.0:
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = clampf(prog, 0.0, 1.0)
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_meta(&"base", Vector2(520, 14))
		bar.custom_minimum_size = Vector2(520, 14)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.05, 0.04, 0.06, 0.9)
		bg.border_color = COL_DIM
		bg.set_border_width_all(1)
		bg.set_corner_radius_all(4)
		var fg := StyleBoxFlat.new()
		fg.bg_color = COL_UNLOCK
		fg.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fg)
		box.add_child(bar)


## Bloc « Nouveaux objets débloqués » : une icône cadrée par objet (qualité en couleur) et leurs noms dessous.
func _add_new_items_block(keys: Array[StringName]) -> void:
	if keys.is_empty():
		return
	var box := VBoxContainer.new()
	box.name = "NewItems"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_meta(&"sep", 10)
	_content.add_child(box)
	var head := _label("Nouveaux objets débloqués", 40, COL_UNLOCK)
	head.name = "ItemsTitle"
	box.add_child(head)
	_labels.append(head)
	var flow := HFlowContainer.new()
	flow.name = "NewItemRow"
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.custom_minimum_size.x = 900.0
	flow.set_meta(&"sep", 10)
	box.add_child(flow)
	var names: Array[String] = []
	for k in keys:
		var id := String(k).substr(5)
		var it := ItemDB.get_item(id)
		names.append(str(it.get("name", id)))
		var cell := Control.new()
		cell.name = "NewItem_" + id
		cell.custom_minimum_size = Vector2(76, 76)
		cell.set_meta(&"base", Vector2(76, 76))
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(cell)
		cell.add_child(ItemBar.quality_backing(it.get("quality", "commun"), 6))
		for path in [ITEM_ICON % id]:
			if ResourceLoader.exists(path):
				var tr := TextureRect.new()
				tr.texture = load(path) as Texture2D
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.set_anchors_preset(Control.PRESET_FULL_RECT)
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cell.add_child(tr)
	var nl := _label(", ".join(names), 30, COL_TEXT)
	nl.name = "NewItemNames"
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.set_meta(&"base", Vector2(1000, 0))
	nl.custom_minimum_size = Vector2(1000, 0)
	box.add_child(nl)
	_labels.append(nl)


## Bloc unique « Nouvelles variantes débloquées » : une rangée d'icônes (variante, sinon sort de base désaturé),
## touche du slot dessous (« Auto » pour le slot 1), nom en infobulle / au focus.
func _add_variants_block(keys: Array[StringName]) -> void:
	if keys.is_empty():
		return
	var box := VBoxContainer.new()
	box.name = "NewVariants"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_meta(&"sep", 10)
	_content.add_child(box)
	var head := _label("Nouvelles variantes débloquées", 40, COL_UNLOCK)
	head.name = "VariantsTitle"
	box.add_child(head)
	_labels.append(head)
	var flow := HFlowContainer.new()
	flow.name = "VariantRow"
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.set_meta(&"sep", 24)
	flow.add_theme_constant_override("v_separation", 12)
	box.add_child(flow)
	var first_name := ""
	for k in keys:
		var vi := variant_info(k)
		var full := str(vi.name) if str(vi.character) == "" else "%s : %s" % [vi.character, vi.name]
		if first_name == "":
			first_name = full
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.set_meta(&"sep", 4)
		flow.add_child(cell)
		var b := Button.new()
		b.name = "Variant_" + String(k).get_slice(":", 1)
		b.flat = true
		b.tooltip_text = full
		b.set_meta(&"base", Vector2(96, 96))
		b.set_meta(&"square", true) # cible >= 88 px dans les deux sens
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tex := vi.icon as Texture2D
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			if bool(vi.placeholder):
				tr.modulate = Color(0.5, 0.5, 0.5, 0.9) # icône de base désaturée en attendant celle de la variante
			b.add_child(tr)
		else:
			b.text = str(vi.name).left(2) # aucune icône : initiales (provisoire)
		b.focus_entered.connect(_show_variant_name.bind(full))
		b.mouse_entered.connect(_show_variant_name.bind(full))
		b.pressed.connect(_show_variant_name.bind(full))
		cell.add_child(b)
		_variant_cells.append(b)
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(holder)
		_variant_caps.append({"holder": holder, "slot": int(vi.slot)})
	_variant_name = _label(first_name, 30, COL_TEXT)
	_variant_name.name = "VariantName"
	box.add_child(_variant_name)
	_labels.append(_variant_name)
	_refresh_variant_keys()
	if not Platform.input_mode_changed.is_connected(_refresh_variant_keys_mode):
		Platform.input_mode_changed.connect(_refresh_variant_keys_mode)


func _exit_tree() -> void:
	if Platform.input_mode_changed.is_connected(_refresh_variant_keys_mode):
		Platform.input_mode_changed.disconnect(_refresh_variant_keys_mode)


func _show_variant_name(full: String) -> void:
	if _variant_name != null:
		_variant_name.text = full


func _refresh_variant_keys_mode(_m: int) -> void:
	_refresh_variant_keys()


## Touche attribuée au slot selon le mode d'entrée : « Auto » (slot 1), invite de touche (clavier-souris,
## manette), « Sort N » en tactile (pas de touche).
func _refresh_variant_keys() -> void:
	for d in _variant_caps:
		var holder := d.holder as Control
		if not is_instance_valid(holder):
			continue
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
		holder.add_child(variant_key_widget(int(d.slot), 26))


## Widget de la touche d'un slot : Label (« Auto », « Sort N ») ou KeyPrompt.
static func variant_key_widget(slot: int, px: int) -> Control:
	var txt := ""
	if slot == 1:
		txt = "Auto"
	elif slot > 1:
		var kp := KeyPrompt.new()
		kp.set_height(float(maxi(px + 8, HudMetrics.floor_px() + 10)))
		kp.set_action(StringName("spell_%d" % slot))
		if kp.text() != "":
			return kp
		kp.queue_free()
		txt = "Sort %d" % slot
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", maxi(px, HudMetrics.floor_px()))
	l.add_theme_color_override("font_color", COL_DIM)
	l.add_theme_color_override("font_outline_color", COL_OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	return l


## Infos d'une clé « spell:<id> » : {name, character, slot (1-4, 0 inconnu), icon (variante, sinon sort de base), placeholder}.
static func variant_info(key: StringName) -> Dictionary:
	var s := String(key)
	var id := s.substr(s.find(":") + 1)
	for c in CharacterCard.load_characters():
		var spells: Array = c.get("spells", []) if c.get("spells") is Array else []
		for i in spells.size():
			var sp: Dictionary = spells[i]
			for v in sp.get("variants", []):
				if str(v.get("id", "")) == id or str(v.get("unlock_key", "")) == s:
					var icon := ArdentKit.spell_icon(StringName(str(v.get("id", id))))
					var ph := icon == null
					if ph:
						icon = ArdentKit.spell_icon(StringName(str(sp.get("id", ""))))
					return {"name": str(v.get("name", _humanize(id))), "character": str(c.get("name", "")),
						"slot": i + 1, "icon": icon, "placeholder": ph}
	return {"name": _humanize(id), "character": "", "slot": 0, "icon": null, "placeholder": true}


## Objets ramassés : icône dans son cadre de rareté + nombre d'exemplaires (RunState.items à la fin de la run).
func _add_items_strip() -> void:
	if RunState.items.is_empty():
		return
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.custom_minimum_size.x = 900.0
	flow.set_meta(&"sep", 10)
	_content.add_child(flow)
	for id in RunState.items:
		var it := ItemDB.get_item(String(id))
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(76, 76)
		cell.set_meta(&"base", Vector2(76, 76))
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(cell)
		cell.add_child(ItemBar.quality_backing(it.get("quality", "commun"), 6))
		for path in [ITEM_ICON % String(id)]:
			if ResourceLoader.exists(path):
				var tr := TextureRect.new()
				tr.texture = load(path) as Texture2D
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.set_anchors_preset(Control.PRESET_FULL_RECT)
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cell.add_child(tr)
		var n := int(RunState.items[id])
		if n > 1:
			var cl := Label.new()
			cl.text = "×%d" % n
			cl.add_theme_font_size_override("font_size", maxi(22, HudMetrics.floor_px()))
			cl.add_theme_color_override("font_color", COL_TEXT)
			cl.add_theme_color_override("font_outline_color", COL_OUTLINE)
			cl.add_theme_constant_override("outline_size", 6)
			cl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			cl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			cl.grow_vertical = Control.GROW_DIRECTION_BEGIN
			cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(cl)


func _add(l: Label) -> void:
	_content.add_child(l)
	_labels.append(l)


func _tile(icon_id: String, caption: String, value: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = TILE_SIZE
	p.set_meta(&"base", TILE_SIZE)
	p.add_theme_stylebox_override(&"panel", _dark_panel())
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var ic := _icon([STAT_ICON % icon_id, STAT_ICON_FALLBACK.get(icon_id, "")], 56)
	if ic != null:
		row.add_child(ic)
	var val := _label(group_thousands(value), 56)
	row.add_child(val)
	var cap := _label(caption, UiTheme.FONT_CAPTION, COL_DIM)
	v.add_child(cap)
	_labels.append(cap)
	_labels.append(val)
	return p


## Réduction §2.1 : UiTheme.scale() (fenêtre PC très petite), sinon 1.
func _apply_layout() -> void:
	if _content == null:
		return
	var s := UiTheme.scale()
	if s <= 0.0:
		s = 1.0
	_content.add_theme_constant_override("separation", int(28 * s))
	_scale_tree(_frame, s)
	_fit()
	_fit.call_deferred()


## Borne la hauteur du panneau à l'écran (zone sûre incluse) : le contenu défile, les boutons restent en bas.
func _fit() -> void:
	if _frame == null or _btn_row == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var safe: Dictionary = Platform.safe_margins()
	var margin := 24.0
	var avail := vp.y - float(safe.get("top", 0.0)) - float(safe.get("bottom", 0.0)) - 2.0 * margin
	var outer := _frame.get_child(0) as VBoxContainer
	var sb := _frame.get_theme_stylebox(&"panel")
	var pad := (sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM)) if sb != null else 0.0
	var need := _content.get_combined_minimum_size().y + _btn_row.get_combined_minimum_size().y \
		+ float(outer.get_theme_constant(&"separation")) + pad
	_frame.custom_minimum_size.y = minf(need, maxf(avail, 200.0))


func _scale_tree(n: Node, s: float) -> void:
	for c in n.get_children():
		if c is Label and c.has_meta(&"base_size"):
			# réduction §2.1, jamais sous le plancher de lisibilité (18 px PC / 26 px mobile, HudMetrics)
			c.add_theme_font_size_override("font_size", maxi(int(int(c.get_meta(&"base_size")) * s), HudMetrics.floor_px()))
		elif c is TextureRect and c.has_meta(&"base_px"):
			c.custom_minimum_size = Vector2.ONE * float(c.get_meta(&"base_px")) * s
		elif c is Control and c.has_meta(&"base"):
			c.custom_minimum_size = (c.get_meta(&"base") as Vector2) * s
			if c is Button:
				c.custom_minimum_size.y = maxf(c.custom_minimum_size.y, UiTheme.MIN_TOUCH) # taille tactile
				if c.has_meta(&"square"):
					c.custom_minimum_size.x = maxf(c.custom_minimum_size.x, UiTheme.MIN_TOUCH)
				c.add_theme_font_size_override("font_size", int(UiTheme.FONT_BUTTON * s))
		if c is BoxContainer and c.has_meta(&"sep"):
			c.add_theme_constant_override("separation", int(int(c.get_meta(&"sep")) * s))
		_scale_tree(c, s)


# --- Textes ---------------------------------------------------------------------

## « Ardent · Moyen · Étage 3 · 10:42 · niveau 18 »
static func info_line(d: Dictionary) -> String:
	var t := int(float(d.get("active_time_s", 0.0)))
	return "%s · %s · Étage %d · %02d:%02d · niveau %d" % [
		str(d.get("character_name", "Ardent")), RunSave.mode_name(StringName(str(d.get("mode", "moyen")))),
		int(d.get("stage", 1)), t / 60, t % 60, int(d.get("level", 1))]


static func ruby_text(n: int) -> String:
	return "Rubis gagnés : %d" % n


## Détail des rubis (mêmes termes que Balance.run_rubies) : « Temps +12 · Piliers +56 · Victoire +25 · Or +1 ».
## Termes nuls omis ; "" si tout est nul.
static func ruby_breakdown(d: Dictionary) -> String:
	var mode := StringName(str(d.get("mode", "moyen")))
	var mult := float(Balance.RUBY_MODE_MULT.get(mode, 1.0))
	var minutes := float(d.get("active_time_s", 0.0)) / 60.0
	var parts: Array[String] = []
	var t := int(floor(1.2 * minutes * mult))
	if t > 0:
		parts.append("Temps +%d" % t)
	var p := 8 * int(d.get("pillars", 0))
	if p > 0:
		parts.append("Piliers +%d" % p)
	if bool(d.get("victory", false)):
		parts.append("Victoire +25")
	var g := mini(int(float(d.get("gold", 0)) / 500.0), 20)
	if g > 0:
		parts.append("Or +%d" % g)
	return " · ".join(parts)


## Prochain objectif de déblocage (lecture seule du profil) : {title, text, progress} ou {} ; progress -1 = inconnu.
## Ordre : mode Difficile s'il est fermé, puis le personnage verrouillé visible le plus avancé.
static func next_objective(profile: Object, characters: Array) -> Dictionary:
	if profile != null and not CharacterCard.is_mode_unlocked(profile, &"difficile"):
		return {"title": "Mode Difficile", "text": "Terminez une run en Moyen.", "progress": -1.0}
	var best := {}
	var best_p := -1.0
	for c in characters:
		if not (c is Dictionary) or bool(c.get("hidden", false)) or bool(c.get("unlocked", false)):
			continue
		if not bool(c.get("playable", false)) or not CharacterCard.is_character_locked(profile, c):
			continue
		var p := 0.0
		if profile != null and profile.has_method("objective_progress"):
			p = clampf(float(profile.call("objective_progress", StringName(str(c.get("id", ""))))), 0.0, 1.0)
		if p > best_p:
			best_p = p
			best = {"title": str(c.get("name", "?")), "text": str(c.get("unlock_text", "")), "progress": p}
	return best


## Clé de déblocage ("mode:<id>", "character:<id>", "spell:<id>") -> texte lisible ; jamais l'id brut.
static func unlock_text(key: StringName) -> String:
	if UNLOCK_TEXTS.has(key):
		return UNLOCK_TEXTS[key]
	var s := String(key)
	var i := s.find(":")
	var kind := s.substr(0, i) if i >= 0 else "character"
	var id := s.substr(i + 1) if i >= 0 else s
	match kind:
		"mode":
			return "Mode %s débloqué !" % RunSave.mode_name(StringName(id))
		"character":
			var c := _character(id)
			return "Nouveau personnage : %s !" % (str(c.get("name", "")) if not c.is_empty() else _humanize(id))
		"item":
			return "Nouvel objet : %s !" % str(ItemDB.get_item(id).get("name", _humanize(id)))
		"skin":
			for c in CharacterCard.load_characters():
				var sk := Skins.skin_of_dict(c)
				if str(sk.get("id", "")) == id:
					return "Nouveau skin pour %s : %s !" % [str(c.get("name", "")), str(sk.get("name", ""))]
			return "Nouveau skin : %s !" % _humanize(id)
		"spell":
			for c in CharacterCard.load_characters():
				for sp in c.get("spells", []):
					for v in sp.get("variants", []):
						if str(v.get("id", "")) == id or str(v.get("unlock_key", "")) == s:
							return "Nouvelle variante pour %s : %s !" % [str(c.get("name", "")), str(v.get("name", ""))]
			return "Nouvelle variante de sort : %s !" % _humanize(id)
	return "Nouveau déblocage : %s !" % _humanize(id)


## Icône d'un déblocage : portrait du personnage, icône de la variante de sort ; "" sinon.
static func unlock_icon_path(key: StringName) -> String:
	var s := String(key)
	var i := s.find(":")
	var kind := s.substr(0, i) if i >= 0 else "character"
	var id := s.substr(i + 1) if i >= 0 else s
	if kind == "character":
		var c := _character(id)
		if not c.is_empty():
			var t: Texture2D = CharacterCard.portrait_info(c).tex
			if t != null and t.resource_path != "":
				return t.resource_path
	elif kind == "skin":
		for c in CharacterCard.load_characters():
			if str(Skins.skin_of_dict(c).get("id", "")) == id:
				var t3: Texture2D = CharacterCard.portrait_info(c, id).tex
				if t3 != null and t3.resource_path != "":
					return t3.resource_path
	elif kind == "spell":
		var t2 := ArdentKit.spell_icon(StringName(id))
		if t2 != null:
			return t2.resource_path
	return ""


static func _character(id: String) -> Dictionary:
	for c in CharacterCard.load_characters():
		if c is Dictionary and str(c.get("id", "")) == id:
			return c
	return {}


## « roaming_embers » -> « Roaming embers » (repli : jamais de « type:id »).
static func _humanize(id: String) -> String:
	var t := id.replace("_", " ").strip_edges()
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else "?"


## 1204 -> « 1 204 » (espace fine insécable).
static func group_thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func _fr_num(x: float) -> String:
	return ("%.1f" % x).replace(".", ",")


## Libellés (tests) : le compteur de rubis est rendu à sa valeur finale.
func texts() -> Array:
	var out := super.texts()
	if _ruby_label != null:
		var i := out.find(_ruby_label.text)
		if i >= 0:
			out[i] = ruby_text(int(info.get("rubies", 0)))
	return out


# --- Compteur de rubis ------------------------------------------------------------

func _start_counter() -> void:
	var target := int(info.get("rubies", 0))
	if bool(info.get("victory", false)):
		Audio.play_ui(&"ui.level_up")
	var tw := create_tween()
	tw.tween_method(_set_counter, 0.0, float(target), COUNT_TIME_S)
	tw.finished.connect(func() -> void:
		_set_counter(float(target))
		animating = false)


func _set_counter(v: float) -> void:
	var n := int(round(v))
	if n == shown_rubies and _ruby_label.text == ruby_text(n):
		return
	if n > shown_rubies and _ticks < MAX_TICKS:
		var now := Time.get_ticks_msec() / 1000.0
		if _last_tick < 0.0 or now - _last_tick >= TICK_S:
			_last_tick = now
			_ticks += 1
			Audio.play_ui(&"pickup.ruby")
	shown_rubies = n
	_ruby_label.text = ruby_text(n)


func _unhandled_input(event: InputEvent) -> void:
	if not animating and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_continue()


func _on_continue() -> void:
	continue_pressed.emit()


func _on_replay() -> void:
	replay_pressed.emit()


## Manette : le stick droit fait défiler le contenu quand il dépasse l'écran (les boutons restent fixes).
func _process(delta: float) -> void:
	if _scroll == null:
		return
	var a := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(a) > 0.3:
		_scroll.scroll_vertical += int(a * 900.0 * delta)
