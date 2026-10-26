class_name UiTheme
extends RefCounted
## Thème et styles communs des menus (docs/Design_Menus.md §2.5, §7, §8 lot A).
## Tout le style passe ici : les StyleBox placeholders sont remplacés par les 9-slice §7 dès que
## les PNG existent (ResourceLoader.exists), sans toucher aux écrans.

const MENU_DIR := "res://assets/sprites/ui/menu/"
const DA_DIR := "res://assets/sprites/ui/da/" ## kit UI de la DA (lot U1) : 9-slice dont les marges sont lues dans le .json voisin
const COL_PANEL := Color("2B3340", 0.86)
const COL_PANEL_DARK := Color("1a1620", 0.9)
const COL_BORDER := Color("7C8898")
const COL_FOCUS := Color("FFB347")
const COL_PRIMARY := Color("C23B12")
const COL_PRIMARY_TEXT := Color("FFE9A8")
const COL_TEXT := Color("F2E6D0") ## texte clair chaud
const COL_OUTLINE := Color("1a1620")
const COL_MUTED := Color("A9B2BF")
const MIN_TOUCH := 88.0
const FONT_TITLE := 64
const FONT_BUTTON := 44
const FONT_BODY := 32
const FONT_CAPTION := 26

const DA_EDGE := 16.0 ## épaisseur visible (px) du trait des cadres DA : le reste de la marge 9-slice est du décor d'angle
const PAD_MIN := 4.0 ## marge verticale mini texte / cadre (px)
const PAD_RATIO := 0.15 ## ... ou 15 % de la taille de police

static var _theme: Theme = null
## Journal des sons joués par hook_sounds (ids), pour les tests. Borné à 64.
static var sound_log: Array[StringName] = []


## Facteur de réduction §2.1 : 1 sur mobile, clamp(min(fenêtre)/1080, 0,55, 1) sur PC.
static func scale() -> float:
	if Platform.is_mobile():
		return 1.0
	var win := Vector2(DisplayServer.window_get_size())
	return clampf(minf(win.x, win.y) / 1080.0, 0.55, 1.0)


# --- métriques de texte : point d'entrée unique (ne jamais dimensionner un cadre sur font_size seul) -------------

## Marge verticale mini entre la boîte de texte (ascent + descent réels) et le bord intérieur visible du cadre.
static func ink_pad(font_size: int) -> float:
	return ceilf(maxf(PAD_MIN, PAD_RATIO * float(font_size)))


## Hauteur réelle d'une ligne (ascent + descent de la police), arrondie au pixel supérieur.
static func line_height(font: Font, font_size: int, lines := 1) -> float:
	var f: Font = font if font != null else ThemeDB.fallback_font
	return ceilf(f.get_height(font_size)) * float(lines)


## Hauteur d'un cadre contenant `lines` lignes : lignes + marge d'encre de chaque côté + épaisseur du trait du cadre.
## `pad` < 0 = ink_pad(font_size). Ex. : text_box_height(font, 18, 1, 6.0) pour un cadre dont le trait fait 6 px.
static func text_box_height(font: Font, font_size: int, lines := 1, edge := 0.0, pad := -1.0) -> float:
	var p := ink_pad(font_size) if pad < 0.0 else pad
	return line_height(font, font_size, lines) + 2.0 * (edge + p)


## Épaisseur visible du trait d'un StyleBox (texture 9-slice DA : plafonnée à DA_EDGE, plat : largeur de bordure).
static func frame_edge(sb: StyleBox) -> float:
	if sb is StyleBoxTexture:
		var t := sb as StyleBoxTexture
		return minf(minf(t.texture_margin_top, t.texture_margin_bottom), DA_EDGE)
	if sb is StyleBoxFlat:
		var f := sb as StyleBoxFlat
		return float(mini(f.border_width_top, f.border_width_bottom))
	return 0.0


## Marge de contenu verticale minimale d'un StyleBox pour un texte de taille `font_size` (trait + marge d'encre).
static func v_margin(sb: StyleBox, font_size: int) -> float:
	return frame_edge(sb) + ink_pad(font_size)


## Relève les marges de contenu verticales d'un StyleBox au minimum requis par `font_size`. Renvoie le StyleBox.
static func pad_box(sb: StyleBox, font_size: int) -> StyleBox:
	if sb == null:
		return null
	var m := v_margin(sb, font_size)
	sb.content_margin_top = maxf(sb.content_margin_top, m)
	sb.content_margin_bottom = maxf(sb.content_margin_bottom, m)
	return sb


static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Force la reconstruction (après livraison d'assets, ou pour les tests).
static func reset_cache() -> void:
	_theme = null
	_body_font = null


## Pose le thème sur `root` et impose la taille tactile minimale (88 px) aux boutons et curseurs.
static func apply(root: Control) -> void:
	if root == null:
		return
	root.theme = theme()
	_enforce_sizes(root)


static func _enforce_sizes(n: Node) -> void:
	for c in n.get_children():
		if c is BaseButton or c is Slider:
			var ctl := c as Control
			var m := ctl.custom_minimum_size
			ctl.custom_minimum_size = Vector2(m.x, maxf(m.y, MIN_TOUCH))
		_enforce_sizes(c)


## Focus -> ui.hover, appui -> ui.click sur tous les BaseButton descendants (idempotent).
static func hook_sounds(root: Node) -> void:
	if root == null:
		return
	if root is BaseButton:
		var b := root as BaseButton
		if not b.has_meta(&"ui_sounds"):
			b.set_meta(&"ui_sounds", true)
			b.focus_entered.connect(_on_focus)
			b.pressed.connect(_on_pressed.bind(b))
	for c in root.get_children():
		hook_sounds(c)


static func _play(id: StringName, vol := 0.0, pitch := 1.0) -> void:
	sound_log.append(id)
	if sound_log.size() > 64:
		sound_log.pop_front()
	Audio.play_ui(id, vol, pitch)


static func _on_focus() -> void:
	_play(&"ui.hover")


static func _on_pressed(b: BaseButton) -> void:
	if b.has_meta(&"ui_back"):
		_play(&"ui.click", -6.0, 0.85)
	elif b.has_meta(&"ui_confirm"):
		_play(&"ui.item_pick")
	else:
		_play(&"ui.click")


## Marque un bouton « Retour » (son plus grave). À appeler avant ou après hook_sounds.
static func mark_back(b: BaseButton) -> void:
	b.set_meta(&"ui_back", true)


## Marque une validation importante (Commencer, Reprendre) : son ui.item_pick.
static func mark_confirm(b: BaseButton) -> void:
	b.set_meta(&"ui_confirm", true)


static func primary(btn: BaseButton) -> void:
	if btn == null:
		return
	_override_button(btn, _btn_styles(true))
	for c in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		btn.add_theme_color_override(c, COL_PRIMARY_TEXT)
	if btn.has_method(&"refresh_subtitle"):
		btn.call(&"refresh_subtitle")


static func destructive(btn: BaseButton) -> void:
	if btn == null:
		return
	var st := _btn_styles(&"danger")
	for k in st:
		var s := st[k] as StyleBox
		if s is StyleBoxFlat and k != &"focus":
			(s as StyleBoxFlat).border_color = Color("FF6A3D")
	_override_button(btn, st)
	for c in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		btn.add_theme_color_override(c, Color.WHITE)
	if btn.has_method(&"refresh_subtitle"):
		btn.call(&"refresh_subtitle")


static func _override_button(btn: BaseButton, st: Dictionary) -> void:
	for k in st:
		btn.add_theme_stylebox_override(k, st[k])


# --- construction du thème -------------------------------------------------------------------

static func _exists(file: String) -> bool:
	return ResourceLoader.exists(MENU_DIR + file)


static func _tex_box(file: String, margin: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(MENU_DIR + file)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


static func _flat(bg: Color, border: Color, bw: int, radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


static func _focus_box() -> StyleBox:
	if _exists("focus_frame_9slice.png"):
		return _tex_box("focus_frame_9slice.png", 20)
	var sb := _flat(Color(0, 0, 0, 0), COL_FOCUS, 4)
	sb.draw_center = false
	return sb


## StyleBoxTexture 9-slice du kit DA : marges d'étirement et marges de contenu lues dans <nom>.json
## (nine_slice / content_insets), marges verticales relevées à trait + ink_pad(font_size). null si la texture manque. Les passes émissives (_e) ne sont pas utilisées.
static func da_box(file: String, content_scale := 1.0, font_size := -1) -> StyleBoxTexture:
	var path := DA_DIR + file + ".png"
	if not ResourceLoader.exists(path):
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	var ns := {"left": 24, "top": 24, "right": 24, "bottom": 24}
	var ci := {"left": 24, "top": 16, "right": 24, "bottom": 16}
	var jp := DA_DIR + file + ".json"
	if FileAccess.file_exists(jp):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(jp))
		if d is Dictionary:
			ns = (d as Dictionary).get("nine_slice", ns)
			ci = (d as Dictionary).get("content_insets", ns)
	sb.texture_margin_left = float(ns["left"])
	sb.texture_margin_top = float(ns["top"])
	sb.texture_margin_right = float(ns["right"])
	sb.texture_margin_bottom = float(ns["bottom"])
	sb.content_margin_left = float(ci["left"]) * content_scale
	sb.content_margin_top = float(ci["top"]) * content_scale
	sb.content_margin_right = float(ci["right"]) * content_scale
	sb.content_margin_bottom = float(ci["bottom"]) * content_scale
	if font_size < 0: # défaut : cadre de texte (26 px) ; les cadres de barres ne portent pas de texte
		font_size = 0 if file.begins_with("bar_") else FONT_CAPTION
	if font_size > 0:
		pad_box(sb, font_size) # content_scale ne ramène jamais le texte sur le trait du cadre
	return sb


## Styles d'un bouton : normal, hover, pressed, disabled, focus. kind : &"normal", &"primary" ou &"danger".
static func _btn_styles(primary_style: Variant) -> Dictionary:
	var kind: StringName = &"primary" if (primary_style is bool and primary_style) else &"normal"
	if primary_style is StringName:
		kind = primary_style
	var d := {}
	var files: Array = {
		&"normal": ["button_normal", "button_hover", "button_pressed", "button_disabled"],
		&"primary": ["button_primary", "button_primary_hover", "button_primary_pressed", "button_disabled"],
		&"danger": ["button_danger", "button_danger", "button_pressed", "button_disabled"],
	}[kind]
	var names := [&"normal", &"hover", &"pressed", &"disabled"]
	var ok := true
	for i in 4:
		var sb := da_box(files[i])
		if sb == null:
			ok = false
			break
		d[names[i]] = sb
	if not ok:
		d.clear()
		if kind == &"primary":
			d[&"normal"] = _flat(COL_PRIMARY, COL_PRIMARY_TEXT.darkened(0.2), 2)
			d[&"hover"] = _flat(COL_PRIMARY.lightened(0.12), COL_PRIMARY_TEXT, 2)
			d[&"pressed"] = _flat(COL_PRIMARY.darkened(0.2), COL_PRIMARY_TEXT, 2)
			d[&"disabled"] = _flat(COL_PRIMARY.darkened(0.3), COL_BORDER, 2)
		else:
			d[&"normal"] = _flat(COL_PANEL, COL_BORDER, 2)
			d[&"hover"] = _flat(Color("343E4E", 0.92), COL_BORDER.lightened(0.2), 2)
			d[&"pressed"] = _flat(Color("1f2630", 0.95), COL_BORDER, 2)
			d[&"disabled"] = _flat(Color(COL_PANEL, 0.6), COL_BORDER.darkened(0.3), 2)
	for k in d:
		pad_box(d[k] as StyleBox, FONT_BUTTON) # le texte du bouton ne touche jamais le trait du cadre
	d[&"focus"] = _focus_box()
	return d


## Polices (SIL OFL, assets/fonts/<police>/OFL.txt). Un seul point d'entrée : tout le jeu passe par le thème.
## Titres = TitleLabel / title_font() ; texte courant = police par défaut du thème (chiffres tabulaires pour le HUD).
const FONT_TITLE_FILE := "res://assets/fonts/cinzel/Cinzel-Variable.ttf"
const FONT_BODY_FILE := "res://assets/fonts/alegreyasans/AlegreyaSans-Medium.ttf"
## Finalistes écartés (23/10/2026, re-téléchargeables depuis github.com/google/fonts/ofl/) : Marcellus SC + Barlow Semi Condensed
## Medium (titres trop fins, texte neutre) ; Metamorphous + Fira Sans Condensed Medium (titres en bas de casse fantaisistes).
## Pour les captures comparatives : chemins imposés (vide = valeurs ci-dessus).
static var override_title_file := ""
static var override_body_file := ""
static var override_title_weight := 0
static var _body_font: Font = null


static func _load_font(path: String) -> FontFile:
	if ResourceLoader.exists(path):
		var f := load(path) as FontFile
		if f != null:
			return f
	return null


## Police du texte courant : chiffres tabulaires et alignés sur la ligne de base (colonnes de HUD stables), repli sur la police Godot.
static func body_font() -> Font:
	if _body_font == null:
		var base := _load_font(override_body_file if override_body_file != "" else FONT_BODY_FILE)
		if base == null:
			return ThemeDB.fallback_font
		var fv := FontVariation.new()
		fv.base_font = base
		fv.opentype_features = {"tnum": 1, "lnum": 1}
		_body_font = fv
	return _body_font


## Police des titres : capitales gravées espacées. Repli sur la police du thème si le fichier manque.
static func title_font() -> Font:
	var fv := FontVariation.new()
	var base := _load_font(override_title_file if override_title_file != "" else FONT_TITLE_FILE)
	fv.base_font = base if base != null else body_font()
	fv.spacing_glyph = 4
	if base != null:
		fv.variation_opentype = {"wght": override_title_weight if override_title_weight > 0 else 700}
	return fv


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY
	t.default_font = body_font()
	ThemeDB.fallback_font = body_font() # HUD, barres, tout contrôle sans thème explicite

	# Boutons
	var st := _btn_styles(false)
	for k in st:
		t.set_stylebox(k, &"Button", st[k])
		t.set_stylebox(k, &"CheckButton", st[k])
	t.set_font_size(&"font_size", &"Button", FONT_BUTTON)
	t.set_color(&"font_color", &"Button", COL_TEXT)
	t.set_color(&"font_hover_color", &"Button", Color.WHITE)
	t.set_color(&"font_pressed_color", &"Button", COL_PRIMARY_TEXT)
	t.set_color(&"font_focus_color", &"Button", Color.WHITE)
	t.set_color(&"font_disabled_color", &"Button", Color(COL_TEXT, 0.45))
	t.set_color(&"font_outline_color", &"Button", COL_OUTLINE)
	t.set_constant(&"outline_size", &"Button", 6)

	# Labels : contour #1a1620 sur fond animé
	t.set_font_size(&"font_size", &"Label", FONT_BODY)
	t.set_color(&"font_color", &"Label", COL_TEXT)
	t.set_color(&"font_outline_color", &"Label", COL_OUTLINE)
	t.set_constant(&"outline_size", &"Label", 6)

	# Panneaux
	var panel: StyleBox = da_box("panel_9slice")
	if panel == null:
		var p := _flat(COL_PANEL, COL_BORDER, 2)
		p.content_margin_left = 32
		p.content_margin_right = 32
		p.content_margin_top = 28
		p.content_margin_bottom = 28
		panel = p
	pad_box(panel, FONT_BODY)
	t.set_stylebox(&"panel", &"PanelContainer", panel)
	t.set_stylebox(&"panel", &"Panel", panel)
	# variations : petit panneau, bandeau de titre, plaque de chrono
	for v in [[&"SmallPanel", "panel_small_9slice", FONT_BODY], [&"HeaderPanel", "header_banner", FONT_TITLE], [&"TimerPlate", "timer_plate", 40]]:
		var vb := da_box(v[1], 1.0, int(v[2]))
		if vb != null:
			t.set_type_variation(v[0], &"PanelContainer")
			t.set_stylebox(&"panel", v[0], vb)
	# variations de bouton : principal (accent orange) et danger (accent rouge)
	for v in [[&"PrimaryButton", &"primary"], [&"DangerButton", &"danger"]]:
		t.set_type_variation(v[0], &"Button")
		var bs := _btn_styles(v[1])
		for k in bs:
			t.set_stylebox(k, v[0], bs[k])
		t.set_color(&"font_color", v[0], COL_PRIMARY_TEXT)
		t.set_color(&"font_hover_color", v[0], Color.WHITE)
		t.set_color(&"font_pressed_color", v[0], COL_PRIMARY_TEXT)
		t.set_color(&"font_focus_color", v[0], Color.WHITE)
	# titres : capitales espacées
	t.set_type_variation(&"TitleLabel", &"Label")
	t.set_font(&"font", &"TitleLabel", title_font())
	t.set_font_size(&"font_size", &"TitleLabel", FONT_TITLE)
	t.set_color(&"font_color", &"TitleLabel", COL_PRIMARY_TEXT)
	# séparateurs
	var dv := ResourceLoader.exists(DA_DIR + "divider.png")
	if dv:
		var ds := StyleBoxTexture.new()
		ds.texture = load(DA_DIR + "divider.png")
		ds.texture_margin_left = 40.0
		ds.texture_margin_right = 40.0
		ds.content_margin_top = 12.0
		ds.content_margin_bottom = 12.0
		t.set_stylebox(&"separator", &"HSeparator", ds)
		t.set_constant(&"separation", &"HSeparator", 24)

	# Curseurs
	if _exists("slider_track.png"):
		var ts := StyleBoxTexture.new()
		ts.texture = load(MENU_DIR + "slider_track.png")
		t.set_stylebox(&"slider", &"HSlider", ts)
	else:
		var track := _flat(Color("141922", 0.95), COL_BORDER, 2, 8)
		track.content_margin_top = 12
		track.content_margin_bottom = 12
		t.set_stylebox(&"slider", &"HSlider", track)
	if _exists("slider_fill.png"):
		var fs := StyleBoxTexture.new()
		fs.texture = load(MENU_DIR + "slider_fill.png")
		t.set_stylebox(&"grabber_area", &"HSlider", fs)
		t.set_stylebox(&"grabber_area_highlight", &"HSlider", fs)
	else:
		var fill := _flat(Color("FF7A1F"), Color("FF7A1F"), 0, 8)
		fill.content_margin_top = 12
		fill.content_margin_bottom = 12
		t.set_stylebox(&"grabber_area", &"HSlider", fill)
		t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	var grab: Texture2D = load(MENU_DIR + "slider_grab.png") if _exists("slider_grab.png") else _grad_tex(64, 64, Color("FFE9A8"), true)
	for n in [&"grabber", &"grabber_highlight", &"grabber_disabled"]:
		t.set_icon(n, &"HSlider", grab)
	t.set_stylebox(&"focus", &"HSlider", _focus_box())

	# Interrupteurs : blocs unis tant que toggle_on/off.png manquent
	var on: Texture2D = load(MENU_DIR + "toggle_on.png") if _exists("toggle_on.png") else _grad_tex(160, 88, COL_FOCUS, false)
	var off: Texture2D = load(MENU_DIR + "toggle_off.png") if _exists("toggle_off.png") else _grad_tex(160, 88, Color("3a4150"), false)
	for n in [&"checked", &"checked_disabled", &"checked_mirrored"]:
		t.set_icon(n, &"CheckButton", on)
	for n in [&"unchecked", &"unchecked_disabled", &"unchecked_mirrored"]:
		t.set_icon(n, &"CheckButton", off)
	t.set_font_size(&"font_size", &"CheckButton", FONT_BODY + 4)
	t.set_color(&"font_color", &"CheckButton", COL_TEXT)
	t.set_constant(&"h_separation", &"CheckButton", 24)

	# Barre de progression, espacements
	t.set_stylebox(&"background", &"ProgressBar", _flat(Color("141922", 0.95), COL_BORDER, 2, 8))
	t.set_stylebox(&"fill", &"ProgressBar", _flat(Color("FF7A1F"), Color("FF7A1F"), 0, 8))
	t.set_font_size(&"font_size", &"ProgressBar", FONT_CAPTION)
	t.set_constant(&"separation", &"VBoxContainer", 16)
	t.set_constant(&"separation", &"HBoxContainer", 16)
	return t


## Texture dégradée (placeholder de poignée / interrupteur, remplacée par les PNG §7).
static func _grad_tex(w: int, h: int, col: Color, radial: bool) -> GradientTexture2D:
	var g := Gradient.new()
	if radial:
		g.colors = PackedColorArray([col, col, Color(col, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 0.92, 1.0])
	else:
		g.colors = PackedColorArray([col, col])
		g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = w
	gt.height = h
	if radial:
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
	return gt
