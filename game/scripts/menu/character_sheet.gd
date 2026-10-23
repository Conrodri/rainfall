class_name CharacterSheet
extends PanelContainer
## Fiche d'un personnage (Nouvelle run, §3.2 MISE À JOUR) : aperçu animé `idle_s`, nom, style,
## config, puis un bloc par sort : icône 96, nom, rôle, description, chiffres clés lus dans
## `SpellData` (ArdentKit) et, à côté, les variantes en icônes 72 (grisées + cadenas si verrouillées).
## Survol / focus / appui long sur une variante → infobulle (quête de déblocage ou description).
## Placeholder : icône de variante manquante = icône du sort de base désaturée (§7).

signal option_chosen(slot: int, spell_id: StringName)

const VariantUnlocks := preload("res://scripts/save/variant_unlocks.gd")

const ROLE_TEXT := {"auto": "Auto", "cd": "Recharge", "ultime": "Ultime"}
const LONG_PRESS_S := 0.45
const ICON_BASE := 84
const ICON_VARIANT := 60
const COL_ROLE := Color("#FFB347")
const COL_BODY := Color(0.9, 0.9, 0.93)
const COL_DIM := Color(0.62, 0.64, 0.68)
## Cadrage générique de l'aperçu animé : côté du disque, part de la hauteur remplie par le personnage,
## marge sous les pieds (fractions de la hauteur du disque). Aucune valeur par personnage.
const STAGE_SIDE := 112.0
const PREVIEW_FILL := 0.8
const PREVIEW_FOOT_MARGIN := 0.09
const PREVIEW_MAX_WIDTH := 0.96
const IDLE_ANIMS: Array[StringName] = [&"idle_s", &"idle_se", &"idle"]
## Boîte englobante des pixels opaques de l'animation idle, par SpriteFrames + animation (calculée une fois).
static var _bbox_cache: Dictionary = {}

var profile: Object
var tooltip: SpellTooltip
var character: Dictionary = {}
var locked := false
## slot (1-4) -> id du sort choisi pour la run (base par défaut).
var chosen: Dictionary = {}
var preview: AnimatedSprite2D
## Disque d'aperçu (parent de `preview`), carré STAGE_SIDE.
var preview_stage: Control
## Vrai si au moins une variante du personnage est débloquée (sinon la colonne de variantes est masquée).
var show_variants := false

var _content: VBoxContainer ## en-tête (aperçu, nom) puis un bloc par sort, dans un ScrollContainer (filet de sécurité)
var _scroll: ScrollContainer
var _rows: Array = [] ## par slot : {buttons: Array[Button], name: Label, role: Label, desc: Label, stats: Label, spell: Dictionary}
var _spell_data: Dictionary = {} ## id -> SpellData
var _press_token := 0
var _tween: Tween
var _fit_token := 0
## Échelle de texte appliquée par _fit_text() (1 = tailles nominales) : texte réduit avant de recourir au défilement.
var text_scale := 1.0
const TEXT_SCALES: Array[float] = [1.0, 0.95, 0.9] ## plancher 0,9 (audit M8) puis défilement ; jamais sous MIN_FONT
const ROW_FONTS := {"name": 28, "role": 24, "desc": 20, "stats": 20}


func _init() -> void:
	# Grand panneau DA (panel_9slice, comme le coffre et le récap) ; repli : plaque plate.
	var da := UiTheme.da_box("panel_9slice", 0.5)
	add_theme_stylebox_override("panel", da if da != null else CharacterCard.panel_box(Color("#1a1620"), CharacterCard.COL_BORDER, 2, 0.9, false))
	mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.follow_focus = true # manette / clavier : le bloc focalisé reste visible
	add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	_scroll.add_child(_content)
	resized.connect(_on_resized)


## Remplit la fiche et la fait apparaître (fondu + glissement 0,18 s).
func open(c: Dictionary, is_locked: bool, animate := true) -> void:
	character = c
	locked = is_locked
	chosen.clear()
	_rows.clear()
	_spell_data = _load_spell_data(String(c.get("id", "")))
	for ch in _content.get_children():
		_content.remove_child(ch)
		ch.queue_free()
	_build_identity()
	if locked:
		_build_locked()
	else:
		_build_kit()
	if tooltip != null:
		tooltip.hide_tip()
	var was_visible := visible
	visible = true
	_scroll.scroll_vertical = 0
	_fit_text.call_deferred()
	if animate and is_inside_tree():
		if _tween != null:
			_tween.kill()
		modulate.a = 0.0
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(self, "modulate:a", 1.0, 0.18)
		if not was_visible: # fiche déjà affichée (changement de perso) : simple fondu, le panneau ne saute pas
			var y := position.y
			position.y = y + 24
			_tween.tween_property(self, "position:y", y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		modulate.a = 1.0


## Boutons d'options par slot (base puis variantes), pour le câblage du focus.
func focus_rows() -> Array:
	var out: Array = []
	for r in _rows:
		out.append(r.buttons)
	return out


func chosen_spells() -> Dictionary:
	return chosen.duplicate()


# --- Construction ------------------------------------------------------------

func _build_identity() -> void:
	# En-tête : petit aperçu animé (le grand rendu est sur la carte), nom, titre / style, prise en main.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	_content.add_child(head)
	var stage := Panel.new()
	stage.name = "PreviewStage"
	stage.custom_minimum_size = Vector2(STAGE_SIDE, STAGE_SIDE)
	stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER # carré : l'en-tête ne l'étire pas en ovale
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc := StyleBoxFlat.new()
	disc.bg_color = Color(0.06, 0.05, 0.08, 0.85)
	disc.set_corner_radius_all(int(STAGE_SIDE * 0.5))
	# Liseré de l'accent du personnage (un seul accent émissif par personnage).
	disc.border_color = COL_DIM.darkened(0.4) if locked else Color(CharacterCard.accent_color(character), 0.85)
	disc.set_border_width_all(2)
	disc.shadow_color = Color(CharacterCard.accent_color(character), 0.0 if locked else 0.35)
	disc.shadow_size = 10
	stage.add_theme_stylebox_override("panel", disc)
	head.add_child(stage)
	preview_stage = stage
	preview = null
	var sf_path := String(character.get("sprite_frames", ""))
	var sf: SpriteFrames = load(sf_path) if sf_path != "" and ResourceLoader.exists(sf_path) else null
	var anim := idle_anim(sf)
	if anim != &"":
		preview = AnimatedSprite2D.new()
		preview.name = "Preview"
		preview.sprite_frames = sf
		preview.centered = true
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if locked:
			preview.material = CharacterCard.grayscale_material(0.4)
		stage.add_child(preview)
		preview.play(anim)
		stage.resized.connect(_frame_preview)
		_frame_preview()
	else:
		var q := CharacterCard.make_label("?", 70, COL_DIM)
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stage.add_child(q)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	head.add_child(col)
	var nm := CharacterCard.make_label(String(character.get("name", "?")), 42, COL_DIM if locked else CharacterCard.COL_TEXT)
	nm.add_theme_font_override("font", UiTheme.title_font())
	col.add_child(nm)
	var title := String(character.get("title", ""))
	var style := String(character.get("style", ""))
	var sub_txt := ("%s · %s" % [title, style]) if title != "" else style
	var cfg_txt := String(character.get("config", ""))
	if cfg_txt != "":
		sub_txt += " · " + cfg_txt
	var sub := CharacterCard.make_label(sub_txt, 22, COL_DIM if locked else CharacterCard.accent_color(character).lerp(CharacterCard.COL_TEXT, 0.35), 4)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	var lvl := CharacterCard.difficulty_of(character)
	if lvl > 0:
		var drow := HBoxContainer.new()
		drow.name = "DifficultyRow"
		drow.add_theme_constant_override("separation", 10)
		drow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drow.add_child(CharacterCard.make_label("Difficulté", 22, COL_DIM, 4))
		drow.add_child(CharacterCard.make_difficulty_badge(lvl, 20.0, true, 22))
		col.add_child(drow)


# --- Cadrage de l'aperçu ----------------------------------------------------------

## Animation d'attente utilisée pour l'aperçu (direction s, sinon se), &"" si aucune.
static func idle_anim(sf: SpriteFrames) -> StringName:
	if sf == null:
		return &""
	for a in IDLE_ANIMS:
		if sf.has_animation(a) and sf.get_frame_count(a) > 0:
			return a
	return &""


## Boîte des pixels opaques (alpha > 0,1), union de toutes les frames de `anim` (le personnage respire :
## le cadre ne saute pas d'une frame à l'autre), en pixels de frame. Mise en cache par personnage.
## Image illisible (rendu factice en headless, export) : relecture du PNG source, sinon frame entière.
static func content_rect(sf: SpriteFrames, anim: StringName) -> Rect2:
	var key := "%s#%d::%s" % [sf.resource_path, sf.get_instance_id() if sf.resource_path == "" else 0, anim]
	if _bbox_cache.has(key):
		return _bbox_cache[key]
	var union := Rect2()
	var has := false
	var fsize := Vector2.ZERO
	var sources := {} ## chemin PNG -> Image (relecture du fichier, une seule fois)
	for i in sf.get_frame_count(anim):
		var tex := sf.get_frame_texture(anim, i)
		if tex == null:
			continue
		fsize = tex.get_size()
		var img := _frame_image(tex, sources)
		if img == null:
			continue
		var r := Rect2(img.get_used_rect())
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		union = r if not has else union.merge(r)
		has = true
	if not has:
		union = Rect2(Vector2.ZERO, fsize)
	_bbox_cache[key] = union
	return union


## Image (non compressée) de la frame : l'atlas entier est lu une seule fois (`sources`), puis découpé à la
## région de la frame (AtlasTexture.get_image échoue sur un atlas compressé).
static func _frame_image(tex: Texture2D, sources: Dictionary) -> Image:
	var base: Texture2D = (tex as AtlasTexture).atlas if tex is AtlasTexture else tex
	if base == null:
		return null
	var key: Variant = base.resource_path if base.resource_path != "" else base.get_instance_id()
	if not sources.has(key):
		var full: Image = base.get_image()
		if (full == null or full.is_empty()) and base.resource_path != "" and FileAccess.file_exists(base.resource_path):
			full = Image.load_from_file(ProjectSettings.globalize_path(base.resource_path))
		if full != null and not full.is_empty():
			if full.is_compressed():
				full = full.duplicate()
				full.decompress()
			if full.is_compressed() or full.detect_alpha() == Image.ALPHA_NONE:
				full = null
		else:
			full = null
		sources[key] = full
	var img: Image = sources[key]
	if img == null:
		return null
	if tex is AtlasTexture:
		var reg := Rect2i((tex as AtlasTexture).region).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		return img.get_region(reg) if reg.has_area() else null
	return img


## Échelle et position (sprite centré) qui posent `content` (pixels de frame `frame_size`) dans `box` :
## PREVIEW_FILL de la hauteur, centré en x, pieds à PREVIEW_FOOT_MARGIN du bas ; largeur bornée.
static func fit_transform(content: Rect2, frame_size: Vector2, box: Vector2) -> Dictionary:
	var k := PREVIEW_FILL * box.y / maxf(content.size.y, 1.0)
	k = minf(k, PREVIEW_MAX_WIDTH * box.x / maxf(content.size.x, 1.0))
	var half := frame_size * 0.5
	var pos := Vector2(box.x * 0.5 - (content.get_center().x - half.x) * k,
		box.y * (1.0 - PREVIEW_FOOT_MARGIN) - (content.end.y - half.y) * k)
	return {"scale": k, "position": pos}


func _frame_preview() -> void:
	if preview == null or preview_stage == null or preview.sprite_frames == null:
		return
	var box := preview_stage.size
	if box.x < 2.0 or box.y < 2.0:
		box = preview_stage.custom_minimum_size
	var anim := preview.animation
	var tex := preview.sprite_frames.get_frame_texture(anim, 0)
	if tex == null:
		return
	var t := fit_transform(content_rect(preview.sprite_frames, anim), tex.get_size(), box)
	preview.scale = Vector2.ONE * float(t.scale)
	preview.position = t.position


## Boîte opaque de l'aperçu dans le repère du disque (tests de cadrage) ; Rect2() sans aperçu.
func preview_content_rect() -> Rect2:
	if preview == null:
		return Rect2()
	var tex := preview.sprite_frames.get_frame_texture(preview.animation, 0)
	var c := content_rect(preview.sprite_frames, preview.animation)
	var k := preview.scale.x
	return Rect2(preview.position + (c.position - tex.get_size() * 0.5) * k, c.size * k)


func _build_locked() -> void:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	_content.add_child(v)
	v.add_child(CharacterCard.make_label("Personnage verrouillé", 44, CharacterCard.COL_TEXT))
	var obj := ""
	if bool(character.get("hidden", false)):
		obj = "Objectif caché"
	elif not bool(character.get("unlocked", false)):
		obj = "Objectif : " + String(character.get("unlock_text", ""))
	if obj != "":
		var l := CharacterCard.make_label(obj, 32, COL_ROLE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	v.add_child(CharacterCard.make_label("Bientôt disponible", 32, COL_DIM))
	if (character.get("spells", []) as Array).is_empty():
		v.add_child(CharacterCard.make_label("Kit dévoilé prochainement.", 26, COL_DIM))


func _build_kit() -> void:
	var grid := GridContainer.new()
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	var spells: Array = character.get("spells", [])
	if spells.is_empty():
		# Personnage ouvert dont le kit n'est pas encore décrit dans characters.json.
		var l := CharacterCard.make_label("Kit en préparation : les sorts apparaîtront ici.", 28, COL_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(l)
		return
	# Variantes masquées tant qu'aucune n'est débloquée (audit M8, divulgation progressive) : une seule ligne
	# de rappel ; dès qu'une variante du personnage est débloquée, toutes ses variantes apparaissent.
	show_variants = false
	var variant_count := 0
	for s in spells:
		for v in (s as Dictionary).get("variants", []):
			variant_count += 1
			if CharacterCard.is_variant_unlocked(profile, v):
				show_variants = true
	for i in spells.size():
		grid.add_child(_build_row(i + 1, spells[i]))
	# Choix mémorisé pour ce personnage (Profile.loadout), seulement les variantes encore débloquées.
	var saved := resolve_loadout(profile, character)
	for r in _rows:
		var slot: int = r.buttons[0].get_meta("slot")
		if saved.has(slot) and saved[slot] != chosen.get(slot, &""):
			chosen[slot] = saved[slot]
			_refresh_row(r)
	if not show_variants and variant_count > 0:
		var note := CharacterCard.make_label("%d variante%s de sorts à débloquer en jouant" % [variant_count, "s" if variant_count > 1 else ""], CharacterCard.MIN_FONT, COL_DIM, 4)
		note.name = "VariantsNote"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(note)


func _build_row(slot: int, spell: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rp := CharacterCard.panel_box(CharacterCard.COL_PANEL, Color(0.35, 0.38, 0.45), 1, 0.7)
	if rp is StyleBoxTexture:
		rp.content_margin_top = 3.0
		rp.content_margin_bottom = 3.0
	box.add_theme_stylebox_override("panel", rp)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	box.add_child(h)
	var row := {"spell": spell, "buttons": []}
	var base_id := StringName(spell.get("id", ""))
	var base_icon := ArdentKit.spell_icon(base_id)
	# Colonne gauche : sort de base (icône 96) puis, dessous, ses variantes (icônes 72).
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(left)
	var base_btn := _option_button(ICON_BASE, base_icon, false, null)
	base_btn.set_meta("slot", slot)
	base_btn.set_meta("option", spell)
	base_btn.set_meta("is_base", true)
	base_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(base_btn)
	row.buttons.append(base_btn)
	var vrow := HBoxContainer.new()
	vrow.alignment = BoxContainer.ALIGNMENT_CENTER
	vrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_theme_constant_override("separation", 2)
	h.add_child(txt)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	txt.add_child(head)
	row.name = CharacterCard.make_label("", 28)
	row.name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # nom long + rôle sur un panneau étroit : retour à la ligne
	row.name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.name.custom_minimum_size = Vector2(80, 0)
	head.add_child(row.name)
	# « role » facultatif dans characters.json (Averse : « 20 d'eau ») remplace le type par défaut (« Recharge »)
	row.role = CharacterCard.make_label(String(spell.get("role", ROLE_TEXT.get(String(spell.get("slot", "")), ""))), 24, COL_ROLE)
	row.role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(row.role)
	row.desc = CharacterCard.make_label("", 20, COL_BODY, 4)
	row.desc.add_theme_constant_override("line_spacing", 0)
	row.desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.desc.custom_minimum_size = Vector2(160, 0)
	txt.add_child(row.desc)
	row.stats = CharacterCard.make_label("", ROW_FONTS["stats"], COL_ROLE, 4)
	row.stats.add_theme_constant_override("line_spacing", 0)
	row.stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.stats.custom_minimum_size = Vector2(160, 0)
	txt.add_child(row.stats)
	h.add_child(vrow) # variantes à droite du texte

	var variants: Array = spell.get("variants", []) if show_variants else []
	for v in variants:
		var vid := StringName(v.get("id", ""))
		var vlocked := not CharacterCard.is_variant_unlocked(profile, v)
		var icon := ArdentKit.spell_icon(vid)
		var placeholder := icon == null
		if placeholder:
			icon = base_icon # placeholder : icône de base désaturée
		var b := _option_button(ICON_VARIANT, icon, vlocked or placeholder, v)
		b.set_meta("slot", slot)
		b.set_meta("option", v)
		b.set_meta("is_base", false)
		b.set_meta("locked", vlocked)
		b.name = "Variant_" + String(vid)
		vrow.add_child(b)
		row.buttons.append(b)
	chosen[slot] = base_id
	_refresh_row(row)
	_rows.append(row)
	return box


func _option_button(icon_size: int, icon: Texture2D, gray: bool, _variant: Variant) -> Button:
	var b := Button.new()
	var side := icon_size + 14
	b.custom_minimum_size = Vector2(side, side)
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("focus", CharacterCard.focus_box())
	var tr := TextureRect.new()
	tr.texture = icon
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = Vector2(icon_size, icon_size)
	tr.position = Vector2((side - icon_size) * 0.5, (side - icon_size) * 0.5)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gray:
		tr.material = CharacterCard.grayscale_material(0.5)
	b.add_child(tr)
	if icon == null:
		b.text = "?"
	b.pressed.connect(_on_option_pressed.bind(b))
	b.focus_entered.connect(_on_option_hover.bind(b))
	b.mouse_entered.connect(_on_option_hover.bind(b))
	b.focus_exited.connect(_on_option_unhover.bind(b))
	b.mouse_exited.connect(_on_option_unhover.bind(b))
	b.gui_input.connect(_on_option_input.bind(b))
	return b


func _refresh_row(row: Dictionary) -> void:
	var slot: int = row.buttons[0].get_meta("slot")
	var cur: StringName = chosen.get(slot, &"")
	var opt: Dictionary = row.spell
	for b in row.buttons:
		var o: Dictionary = b.get_meta("option")
		var is_cur := StringName(o.get("id", "")) == cur
		if is_cur:
			opt = o
		var border := CharacterCard.COL_FOCUS if is_cur else Color(0.35, 0.38, 0.45)
		var sb := CharacterCard.panel_box(Color("#1a1620"), border, 4 if is_cur else 1, 0.8, false)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		if bool(b.get_meta("locked", false)) and b.get_node_or_null("Lock") == null:
			_add_lock_badge(b)
	row.name.text = String(opt.get("name", ""))
	row.desc.text = String(opt.get("desc", ""))
	var sd: SpellData = _spell_data.get(StringName(opt.get("id", "")))
	row.stats.text = spell_stats_text(sd) if sd != null else ""
	row.stats.visible = row.stats.text != ""


## Cadenas sur une variante verrouillée : `ui/menu/icon_lock.png` (§7) ou libellé en attendant.
func _add_lock_badge(b: Button) -> void:
	var side := b.custom_minimum_size.x
	# Icône (ou placeholder en formes) dans le coin bas-droit ; plus de libellé « Verrou » en 16 px.
	var lk := CharacterCard.make_lock_icon(36.0, CharacterCard.COL_FOCUS)
	lk.name = "Lock"
	lk.position = Vector2(side - 38, side - 38)
	b.add_child(lk)


# --- Interaction ---------------------------------------------------------------

func _on_option_pressed(b: Button) -> void:
	var o: Dictionary = b.get_meta("option")
	var slot: int = b.get_meta("slot")
	if bool(b.get_meta("locked", false)):
		CharacterCard.play_ui(&"ui.click", -8.0, 0.7)
		_show_tip(b)
		return
	chosen[slot] = StringName(o.get("id", ""))
	for r in _rows:
		if r.buttons.has(b):
			_refresh_row(r)
	option_chosen.emit(slot, chosen[slot])
	if not bool(b.get_meta("is_base", false)):
		_show_tip(b)


func _on_option_hover(b: Button) -> void:
	if bool(b.get_meta("is_base", false)):
		if tooltip != null:
			tooltip.hide_tip()
		return
	_show_tip(b)


func _on_option_unhover(b: Button) -> void:
	if tooltip == null:
		return
	# Au focus clavier/manette, l'infobulle suit le focus ; à la souris elle suit le survol.
	if b.has_focus() and not _is_touch():
		return
	if _is_touch():
		return # tactile : reste affichée jusqu'au prochain appui
	tooltip.hide_tip(b)


func _on_option_input(ev: InputEvent, b: Button) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_press_token += 1
			var tok := _press_token
			if tooltip != null and tooltip.anchor_control != b:
				tooltip.hide_tip()
			get_tree().create_timer(LONG_PRESS_S, true).timeout.connect(func() -> void:
				if tok == _press_token and is_instance_valid(b):
					_show_tip(b))
		else:
			_press_token += 1


func _show_tip(b: Button) -> void:
	if tooltip == null or bool(b.get_meta("is_base", false)):
		return
	var o: Dictionary = b.get_meta("option")
	if bool(b.get_meta("locked", false)):
		tooltip.show_for(b, String(o.get("name", "")), "Quête de déblocage", variant_quest(profile, character, b.get_meta("slot"), o))
	else:
		var slot: int = b.get_meta("slot")
		var sel: bool = StringName(o.get("id", "")) == chosen.get(slot, &"")
		tooltip.show_for(b, String(o.get("name", "")), "Sélectionnée pour la run" if sel else "Débloquée · appuyer pour choisir", String(o.get("desc", "")))


static func _is_touch() -> bool:
	var loop := Engine.get_main_loop() as SceneTree
	var p := loop.root.get_node_or_null("Platform") if loop != null else null
	return p != null and bool(p.call("is_touch_mode"))


# --- Ajustement du texte ----------------------------------------------------------

## Réduit le texte des blocs de sorts (TEXT_SCALES) jusqu'à ce que la fiche tienne dans le panneau ; au-delà,
## le ScrollContainer prend le relais (défilement tactile / molette / focus manette). Les libellés retournent à
## la ligne (autowrap) : aucun texte ne dépasse horizontalement de son encart.
func _fit_text() -> void:
	_fit_token += 1
	var tok := _fit_token
	if _rows.is_empty() or not is_inside_tree():
		return
	for k in TEXT_SCALES:
		_apply_text_scale(k)
		await get_tree().process_frame
		await get_tree().process_frame
		if tok != _fit_token or not is_instance_valid(self) or _rows.is_empty():
			return
		if not needs_scroll():
			return


func _on_resized() -> void:
	if visible and not _rows.is_empty():
		_fit_text.call_deferred()


func _apply_text_scale(k: float) -> void:
	text_scale = k
	for r in _rows:
		for key in ROW_FONTS:
			var l: Label = r.get(key)
			if l != null:
				l.add_theme_font_size_override("font_size", maxi(int(round(ROW_FONTS[key] * k)), CharacterCard.MIN_FONT))


## Vrai si le contenu dépasse la hauteur visible (défilement nécessaire).
func needs_scroll() -> bool:
	return _content.get_combined_minimum_size().y > _scroll.size.y + 0.5


# --- Données des sorts -----------------------------------------------------------

func _load_spell_data(char_id: String) -> Dictionary:
	var out := {}
	if char_id == "ardent" or CharacterData.has_kit(StringName(char_id)):
		var cd := CharacterData.for_id(StringName(char_id))
		if cd != null: # kit en cours d'écriture (script invalide) : fiche sans chiffres plutôt qu'un plantage
			for s in cd.spells:
				out[s.id] = s
			# Chiffres des variantes codées par le kit (`variant`), sans warning pour celles qui ne le sont pas.
			var spells: Array = character.get("spells", [])
			for i in spells.size():
				for v in (spells[i] as Dictionary).get("variants", []):
					var vid := StringName(str(v.get("id", "")))
					var sd := CharacterData.variant_spell(StringName(char_id), i + 1, vid, true)
					if sd != null:
						out[vid] = sd
	return out


## Sorts à utiliser pour `c` : {slot (int) -> id}, base par défaut, remplacé par le choix mémorisé du profil
## (`get_loadout`) seulement si c'est une variante de ce slot encore débloquée. Profil factice toléré.
static func resolve_loadout(profile: Object, c: Dictionary) -> Dictionary:
	var out := {}
	var spells: Array = c.get("spells", []) if c.get("spells") is Array else []
	var saved: Dictionary = {}
	if profile != null and profile.has_method(&"get_loadout"):
		var d: Variant = profile.call(&"get_loadout", StringName(str(c.get("id", ""))))
		saved = d if d is Dictionary else {}
	for i in spells.size():
		var sp: Dictionary = spells[i]
		var slot := i + 1
		out[slot] = StringName(str(sp.get("id", "")))
		if not saved.has(slot):
			continue
		var want := StringName(str(saved[slot]))
		for v in sp.get("variants", []):
			if StringName(str(v.get("id", ""))) == want and CharacterCard.is_variant_unlocked(profile, v):
				out[slot] = want
	return out


## Texte de quête d'une variante verrouillée (unlock_text ou règle) + avancement d'un compteur (« 120 / 500 »).
static func variant_quest(profile: Object, c: Dictionary, slot: int, v: Dictionary) -> String:
	var spells: Array = c.get("spells", []) if c.get("spells") is Array else []
	var sp: Dictionary = spells[slot - 1] if slot >= 1 and slot <= spells.size() else {}
	var txt := VariantUnlocks.quest_text(c, sp, v)
	var pr := VariantUnlocks.progress(profile, sp, v)
	if not pr.is_empty() and float(pr.target) > 0.0:
		txt += "
Progression : %s / %s" % [CharacterCard.fmt_num(minf(float(pr.value), float(pr.target))), CharacterCard.fmt_num(float(pr.target))]
	return txt


## Chiffres clés tirés de SpellData (rien d'inventé : un champ absent ou nul n'est pas affiché).
static func spell_stats_text(sd: SpellData) -> String:
	var parts: Array[String] = []
	if sd.coef > 0.0: # jamais « Dégâts ×0 » (Aiguisage, utilitaires)
		parts.append("Dégâts ×%s" % CharacterCard.fmt_num(sd.coef))
	if sd.is_auto:
		parts.append("Tir toutes les %s s" % CharacterCard.fmt_num(sd.base_cooldown))
	elif sd.base_cooldown > 0.0:
		parts.append("Recharge %s s" % CharacterCard.fmt_num(sd.base_cooldown))
	if sd.behavior in [SpellData.Behavior.PROJECTILE, SpellData.Behavior.GROUND_ZONE, SpellData.Behavior.FAN]:
		parts.append("Portée %s u" % CharacterCard.fmt_num(sd.range_u))
	if sd.radius_u > 0.0:
		parts.append("Rayon %s u" % CharacterCard.fmt_num(sd.radius_u))
	if sd.duration > 0.0:
		parts.append("Durée %s s" % CharacterCard.fmt_num(sd.duration))
	if sd.pierce > 0:
		parts.append("Traverse %d" % sd.pierce)
	return " · ".join(parts)
