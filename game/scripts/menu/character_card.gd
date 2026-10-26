class_name CharacterCard
extends Button
## Carte de personnage de l'écran Nouvelle run : grande carte verticale façon carte de coffre
## (cadre DA `ui/cards/card_front.png`, mêmes zones que chest_ui) : le personnage (frame `idle_s`, agrandie)
## dans la fenêtre d'illustration sur fond sombre éclairé + vignette, nom dans le bandeau, titre et style en petit
## dans la zone de texte. Sélectionnée : échelle, liseré braise et lumière ; verrouillée : silhouette sombre.
## Contient aussi les petites fonctions partagées par les écrans du lot D (données, Profile, icônes).
## Portrait : `ui/portraits/<id>.png`, sinon `characters/<id>/portrait.png` (buste Blender, + `portrait_e.png`
## ajouté en lumière si livré), sinon 1re frame `idle_s` du SpriteFrames ; sans image : « ? ».
## Accent : un seul par personnage (Design_Personnages, accent émissif) : lueur du fond, liseré de sélection,
## titre. Champ optionnel `accent` de characters.json, sinon table ACCENTS, sinon braise.
## Cadenas = icône `ui/menu/icon_lock.png` si livrée, sinon libellé.

const CARD_SIZE := Vector2(274, 400) ## taille nominale (ratio du cadre 384 x 560) ; l'écran impose la taille réelle
const CARD_FRAME := "res://assets/sprites/ui/cards/card_front.png"
const SELECT_SCALE := 1.08
const CHARACTERS_PATH := "res://data/characters.json"
const PORTRAIT_DIR := "res://assets/sprites/ui/portraits/"
const CHAR_SPRITE_DIR := "res://assets/sprites/characters/"
## Accent émissif unique de chaque personnage (docs/Design_Personnages.md, « accent unique »).
const ACCENTS := {
	"ardent": "#FF8A3C", "tocsin": "#FF7A1F", "averse": "#5FD4E8", "arpenteuse": "#FF7A1F",
	"rainette": "#8DBBA8", "avare": "#F2C14E", "bourbe": "#8DBBA8", "rictus": "#9FC8C0",
}
const LOCK_ICON := "res://assets/sprites/ui/menu/icon_lock.png"
const LOCK_DESIGN_SIZE := 100.0 ## côté du cadenas placeholder, mis à l'échelle ensuite
const CHECK_ICON := "res://assets/sprites/ui/menu/icon_check.png"
const MIN_FONT := 18 ## plancher de tous les textes de l'écran (audit M7/M8)
const NAME_MIN_FONT := 24 ## nom de la carte (audit M7)
const FRAME_PATH := "res://assets/sprites/icons/frame_commun.png"
const COL_PANEL := Color("#2B3340")
const COL_BORDER := Color("#7C8898")
const COL_FOCUS := Color("#FFB347")
const COL_TEXT := Color("#FFE9A8")
const COL_OUTLINE := Color("#1a1620")
const COL_GREY := Color(0.62, 0.64, 0.68)
## Zones de card_front.png en fractions de la carte (mesurées, cf. chest_ui.gd).
const ZONE_ART := Rect2(0.128, 0.061, 0.784, 0.453)
const ZONE_BAND := Rect2(0.104, 0.561, 0.797, 0.068)
const ZONE_TEXT := Rect2(0.104, 0.661, 0.797, 0.277)

var data: Dictionary = {}
var locked := false
## Carte d'affichage seule (écran Progression) : ni focus, ni clic, toujours éclairée.
var display_only := false
var accent := COL_FOCUS
var selected := false:
	set = set_selected
## Échelle de base ; ×SELECT_SCALE si sélectionnée.
var base_scale := 1.0

var _art: Control
var _light: TextureRect
var _portrait: TextureRect
var _emit: TextureRect
var _bust := false ## portrait = buste rendu (remplit la fenêtre) plutôt qu'une frame d'animation
var _bar: ProgressBar
var _silhouette: Label
var _name_label: Label
var _title_label: Label
var _info_label: Label
var _lock_label: Label
var _lock_icon: Control ## TextureRect (icon_lock.png) ou cadenas placeholder en formes (make_lock_icon)
var _ember: Panel
var _diff: HBoxContainer ## pastilles de difficulté (coin haut droit de la fenêtre d'art)
var _tween: Tween
var _hover := false


func setup(character: Dictionary, is_locked: bool) -> void:
	data = character
	locked = is_locked
	accent = accent_color(character)
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	focus_mode = Control.FOCUS_ALL
	text = ""
	name = "Card_" + String(character.get("id", ""))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	focus_entered.connect(_set_hover.bind(true))
	focus_exited.connect(_set_hover.bind(false))
	_build()
	_refresh_style()
	_fit()


## Taille réelle (l'écran la calcule selon la place) : tout le contenu est replacé sur les zones du cadre.
func set_card_size(sz: Vector2) -> void:
	custom_minimum_size = sz
	size = sz
	pivot_offset = sz * 0.5
	_fit()


## Carte inerte pour l'écran Progression (même DA que la sélection, sans focus ni clic).
func make_display_only() -> void:
	display_only = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_refresh_style()


## Carte d'affichage cliquable (écran Progression : ouvre les meilleures runs) : reste toujours éclairée mais
## reprend focus (clavier / manette) et clic / toucher.
func make_inspectable() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Barre de progression de l'objectif de déblocage (personnage verrouillé à objectif visible).
func set_objective_progress(v: float) -> void:
	if _bar == null:
		_bar = ProgressBar.new()
		_bar.name = "Objective"
		_bar.max_value = 1.0
		_bar.step = 0.0
		_bar.show_percentage = false
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.05, 0.04, 0.06, 0.9)
		bg.border_color = Color(0.35, 0.36, 0.4)
		bg.set_border_width_all(1)
		bg.set_corner_radius_all(3)
		var fg := StyleBoxFlat.new()
		fg.bg_color = accent.darkened(0.15)
		fg.set_corner_radius_all(3)
		_bar.add_theme_stylebox_override("background", bg)
		_bar.add_theme_stylebox_override("fill", fg)
		add_child(_bar)
	_bar.value = clampf(v, 0.0, 1.0)
	_fit()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var frame := TextureRect.new()
	if ResourceLoader.exists(CARD_FRAME):
		frame.texture = load(CARD_FRAME)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	# Fenêtre d'illustration : fond éclairé (lueur chaude au pied du personnage), personnage, vignette.
	_art = Control.new()
	_art.clip_contents = true
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.04, 0.06)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(back)
	_light = TextureRect.new()
	# Lueur de l'accent au pied du personnage (sobre : le fond reste sombre, seul l'accent émet).
	_light.texture = _radial(Color(accent, 0.0 if locked else 0.2), Vector2(0.5, 0.92), Vector2(0.95, 0.35))
	_light.set_anchors_preset(Control.PRESET_FULL_RECT)
	_light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_light.stretch_mode = TextureRect.STRETCH_SCALE
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_light)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pinfo := portrait_info(data)
	_portrait.texture = pinfo.tex
	_bust = pinfo.bust
	_art.add_child(_portrait)
	if pinfo.emit != null and not locked:
		# Masque d'émission du rendu (`portrait_e.png`) ajouté en lumière : l'accent ressort du métal sombre.
		_emit = TextureRect.new()
		_emit.texture = pinfo.emit
		_emit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_emit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_emit.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_emit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_emit.material = add
		_emit.modulate = Color(1, 1, 1, 0.55)
		_art.add_child(_emit)
	if _portrait.texture == null:
		_silhouette = make_label("?", 90, Color(0.3, 0.31, 0.36), 0)
		_silhouette.set_anchors_preset(Control.PRESET_FULL_RECT)
		_silhouette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_silhouette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_art.add_child(_silhouette)
	elif locked:
		_portrait.modulate = Color(0.03, 0.03, 0.05) # silhouette sombre
	var vg := TextureRect.new()
	vg.texture = _vignette(0.8)
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(vg)
	# Bandeau : nom ; zone de texte : titre puis style / prise en main.
	_name_label = make_label(String(data.get("name", "?")), 30, COL_GREY if locked else COL_TEXT, 4)
	_name_label.add_theme_font_override("font", UiTheme.title_font())
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.clip_text = true
	add_child(_name_label)
	var title := String(data.get("title", ""))
	var info := ""
	if not locked:
		info = String(data.get("style", "")) # la config (« 4 sorts ») est dans la fiche
	elif bool(data.get("hidden", false)):
		title = "Verrouillé"
		info = "Objectif caché"
	elif bool(data.get("unlocked", false)):
		title = "Verrouillé"
		info = "Bientôt disponible"
	else:
		title = "Verrouillé"
		info = String(data.get("unlock_text", ""))
	_title_label = make_label(title, 24, accent.lerp(COL_TEXT, 0.35) if not locked else COL_GREY, 4)
	_info_label = make_label(info.strip_edges(), 20, Color(0.88, 0.86, 0.82) if not locked else COL_GREY, 3)
	for l in [_title_label, _info_label]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("line_spacing", 0)
		add_child(l)
	if locked:
		# Cadenas : icon_lock.png si livrée, sinon placeholder en formes (brief art/tools/night/_uxmb.txt).
		_lock_icon = make_lock_icon(LOCK_DESIGN_SIZE, COL_GREY)
		add_child(_lock_icon)
	_diff = null
	if not locked and difficulty_of(data) > 0:
		_diff = make_difficulty_badge(difficulty_of(data), 16.0, false)
		_diff.tooltip_text = "Difficulté : " + String(DIFFICULTY_NAMES.get(difficulty_of(data), ""))
		add_child(_diff)
	# Liseré braise de la carte sélectionnée (style d'UI, pas un asset).
	_ember = Panel.new()
	_ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var eb := StyleBoxFlat.new()
	eb.draw_center = false
	eb.border_color = accent.lerp(Color.WHITE, 0.15)
	eb.set_border_width_all(4)
	eb.set_corner_radius_all(16)
	eb.shadow_color = Color(accent, 0.5)
	eb.shadow_size = 20
	_ember.add_theme_stylebox_override("panel", eb)
	_ember.visible = false
	add_child(_ember)
	resized.connect(_fit)


static func _rescale_pip(holder: Control, pip: float) -> void:
	if holder == null or holder.get_child_count() == 0:
		return
	holder.custom_minimum_size = Vector2(pip, pip)
	var d := holder.get_child(0) as Control
	var side := pip * 0.72
	d.size = Vector2(side, side)
	d.pivot_offset = d.size * 0.5
	d.position = Vector2((pip - side) * 0.5, (pip - side) * 0.5)


## Vignette : bords noircis (dégradé radial transparent au centre), fondu normal.
static func _vignette(strength: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, strength)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.95)
	t.width = 256
	t.height = 256
	return t


static func _radial(col: Color, from: Vector2, to: Vector2) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([col, Color(col.r, col.g, col.b, col.a * 0.4), Color(col.r, col.g, col.b, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = from
	t.fill_to = to
	t.width = 256
	t.height = 256
	return t


func _zone(z: Rect2, pad := Vector2(0.02, 0.012)) -> Rect2:
	var r := Rect2(z.position * size, z.size * size)
	return r.grow_individual(-pad.x * size.x, -pad.y * size.y, -pad.x * size.x, -pad.y * size.y)


## Cale le contenu sur les zones du cadre ; polices réduites jusqu'à ce que tout tienne.
func _fit() -> void:
	if _art == null or size.x < 20.0 or size.y < 20.0:
		return
	var k := size.x / CARD_SIZE.x
	var art := _zone(ZONE_ART)
	_art.position = art.position
	_art.size = art.size
	if _bust:
		# Buste carré cadré par le bas : il remplit la largeur de la fenêtre, la tête en haut.
		var bs := maxf(art.size.x * 1.04, art.size.y)
		_portrait.size = Vector2(bs, bs)
		_portrait.position = Vector2((art.size.x - bs) * 0.5, art.size.y - bs)
	else:
		# Silhouette en pied (frame rognée) : 90 % de la hauteur de la fenêtre, posée en bas.
		var h := art.size.y * 0.9
		_portrait.size = Vector2(art.size.x, h)
		_portrait.position = Vector2(0, art.size.y - h - art.size.y * 0.02)
	if _emit != null:
		_emit.size = _portrait.size
		_emit.position = _portrait.position
	if _diff != null:
		var pip := clampf(14.0 * k, 9.0, 22.0)
		for hc in _diff.get_children():
			_rescale_pip(hc as Control, pip)
		_diff.add_theme_constant_override("separation", int(maxf(pip * 0.35, 2.0)))
		_diff.reset_size()
		_diff.position = art.position + Vector2(art.size.x - _diff.size.x - 6.0 * k, 6.0 * k)
	var band := _zone(ZONE_BAND, Vector2(0.02, 0.004))
	_name_label.position = band.position
	_name_label.size = band.size
	var font := _name_label.get_theme_font(&"font")
	# Nom : jamais sous 24 px (le libellé déborde un peu du bandeau plutôt que de rétrécir) ; trop long = points de suspension.
	var nfs := clampi(int(band.size.y * 0.78), NAME_MIN_FONT, 40)
	while nfs > NAME_MIN_FONT and font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > band.size.x:
		nfs -= 1
	_name_label.clip_text = false
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_font_size_override("font_size", nfs)
	# La ligne de Cinzel (1,36 em) peut dépasser le bandeau : un Label plus petit que sa ligne grandit vers le bas et le
	# nom descend sur le cadre. On le recentre sur le bandeau avec sa hauteur réelle.
	var name_h := maxf(band.size.y, UiTheme.line_height(font, nfs))
	_name_label.size = Vector2(band.size.x, name_h)
	_name_label.position = Vector2(band.position.x, band.get_center().y - name_h * 0.5)
	var tz := _zone(ZONE_TEXT)
	var bar_h := maxf(10.0, 14.0 * k) if _bar != null else 0.0
	if _bar != null:
		tz.size.y -= bar_h + 6.0 # la barre d'objectif prend le bas de la zone de texte
	var bf := _info_label.get_theme_font(&"font")
	# Titre + ligne de style ; si la ligne de style passerait sous 16 px (petites cartes, téléphone),
	# elle est retirée et seul le titre reste, lisible.
	# Plancher 18 px (MIN_FONT) : titre + ligne de style tant que la ligne de style tient à 18 px ou plus ;
	# sinon elle est retirée et le titre seul peut descendre jusqu'à 18 px.
	var fs0 := maxi(int(26.0 * k), MIN_FONT + 4)
	var fs := fs0
	var th := 0.0
	var show_info := _info_label.text != ""
	while true:
		th = bf.get_multiline_string_size(_title_label.text, HORIZONTAL_ALIGNMENT_CENTER, tz.size.x, fs).y
		if show_info:
			th += bf.get_multiline_string_size(_info_label.text, HORIZONTAL_ALIGNMENT_CENTER, tz.size.x, maxi(fs - 4, MIN_FONT)).y + 4.0
		if th <= tz.size.y:
			break
		if show_info:
			if fs - 1 < MIN_FONT + 4:
				show_info = false
				fs = fs0
				continue
			fs -= 1
		else:
			if fs <= MIN_FONT:
				break
			fs -= 1
	_info_label.visible = show_info
	_title_label.add_theme_font_size_override("font_size", fs)
	_info_label.add_theme_font_size_override("font_size", maxi(fs - 4, MIN_FONT))
	var title_h := bf.get_multiline_string_size(_title_label.text, HORIZONTAL_ALIGNMENT_CENTER, tz.size.x, fs).y
	_title_label.position = tz.position + Vector2(0, maxf((tz.size.y - th) * 0.5, 0.0))
	_title_label.size = Vector2(tz.size.x, title_h)
	_info_label.position = _title_label.position + Vector2(0, title_h + 4.0)
	_info_label.size = Vector2(tz.size.x, maxf(th - title_h - 4.0, 8.0))
	if _lock_icon != null:
		var ls := art.size.x * 0.3
		if _lock_icon is TextureRect:
			_lock_icon.size = Vector2(ls, ls)
		else:
			_lock_icon.scale = Vector2.ONE * (ls / LOCK_DESIGN_SIZE) # placeholder dessiné à LOCK_DESIGN_SIZE
		_lock_icon.position = art.position + Vector2((art.size.x - ls) * 0.5, art.size.y * 0.06)
	_ember.position = Vector2(-2, -2)
	_ember.size = size + Vector2(4, 4)
	if _bar != null:
		_bar.position = Vector2(tz.position.x + tz.size.x * 0.1, tz.end.y + 6.0)
		_bar.size = Vector2(tz.size.x * 0.8, bar_h)


func set_selected(v: bool) -> void:
	if v == selected and _tween != null:
		return
	selected = v
	_refresh_style()
	var target := Vector2.ONE * base_scale * (SELECT_SCALE if v else 1.0)
	z_index = 1 if v else 0
	if not is_inside_tree():
		scale = target
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", target, 0.12)


func set_base_scale(k: float) -> void:
	base_scale = k
	if _tween != null:
		_tween.kill()
	scale = Vector2.ONE * k * (SELECT_SCALE if selected else 1.0)


func _set_hover(v: bool) -> void:
	_hover = v
	_refresh_style()


func _refresh_style() -> void:
	var empty := StyleBoxEmpty.new() # tout le visuel est dans les enfants (cadre DA)
	for st in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(st, empty)
	add_theme_stylebox_override("focus", focus_box())
	if _ember != null:
		_ember.visible = selected
	if _light != null and not locked:
		_light.modulate = Color(1.6, 1.6, 1.6) if selected else Color.WHITE
	if _emit != null:
		_emit.modulate.a = 0.9 if selected else 0.55
	# éteinte : légèrement assombrie ; survol / focus / sélection : pleine lumière
	var lit := selected or _hover or display_only
	modulate = Color.WHITE if lit else Color(0.85, 0.84, 0.87) # 85 % (audit M7) : une carte non choisie ne paraît pas verrouillée


# --- Fond et bandeau communs aux écrans de menu (Nouvelle run, Progression) ----

## Fond non uni : dégradé radial brun sombre, lueur de braise en bas, vignette de l'ambiance multipliée par-dessus.
static func make_backdrop() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("#33211a"), Color("#17121a"), Color("#08070c")])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.05, 1.0)
	gt.width = 512
	gt.height = 512
	var layers: Array = [[gt, null], [_radial(Color(0.7, 0.28, 0.1, 0.2), Vector2(0.5, 1.05), Vector2(0.5, 0.5)), null]]
	layers.append([_vignette(0.9), null])
	for l in layers:
		var tr := TextureRect.new()
		tr.texture = l[0]
		tr.material = l[1]
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tr)
	return root


## Bandeau de titre DA (header_banner) + titre en capitales espacées. Renvoie {banner, label}.
static func make_banner(txt: String) -> Dictionary:
	var banner := PanelContainer.new()
	banner.theme_type_variation = &"HeaderPanel"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.theme_type_variation = &"TitleLabel"
	l.text = txt.to_upper()
	l.add_theme_font_size_override("font_size", 46)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(l)
	return {"banner": banner, "label": l}


# --- Fonctions partagées (écrans Nouvelle run et Progression) ----------------

## Liste affichée : toutes les entrées de characters.json (cachées comprises, montrées « Objectif caché »).
static func load_characters() -> Array:
	var f := FileAccess.open(CHARACTERS_PATH, FileAccess.READ)
	if f == null:
		push_error("characters.json introuvable")
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Array else []


## Profile réel (autoload) ou objet de test injecté.
static func default_profile() -> Object:
	var loop := Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("Profile") if loop != null else null


## Lecture tolérante d'une propriété du profil (le lot B peut ne pas l'avoir encore).
static func pget(profile: Object, prop: String, fallback: Variant) -> Variant:
	if profile == null or not (prop in profile):
		return fallback
	var v: Variant = profile.get(prop)
	return fallback if v == null else v


static func _in_list(list: Variant, key: String) -> bool:
	if not (list is Array):
		return false
	for e in list:
		if String(e) == key:
			return true
	return false


## Jouable ET débloqué (v1 : seul Ardent).
static func is_character_locked(profile: Object, c: Dictionary) -> bool:
	if not bool(c.get("playable", false)):
		return true
	if bool(c.get("unlocked", false)):
		return false
	var id := String(c.get("id", ""))
	if profile != null and profile.has_method("is_character_unlocked"):
		return not bool(profile.call("is_character_unlocked", StringName(id)))
	return not _in_list(pget(profile, "unlocked_characters", null), id)


## Facile et Moyen toujours ouverts ; Difficile selon le profil (§0).
static func is_mode_unlocked(profile: Object, mode: StringName) -> bool:
	if mode != &"difficile":
		return true
	if profile == null:
		return false
	if profile.has_method("is_mode_unlocked"):
		return bool(profile.call("is_mode_unlocked", mode))
	var list: Variant = pget(profile, "unlocked_modes", null)
	if list is Array:
		return _in_list(list, String(mode))
	return false


## Variante de sort : `Profile.is_unlocked(&"spell:<id>")` seulement si le profil gère
## `unlocked_spells` (lot B) ; sinon tout est verrouillé sauf les sorts de base (§3.2).
static func is_variant_unlocked(profile: Object, variant: Dictionary) -> bool:
	if profile == null or not ("unlocked_spells" in profile) or not profile.has_method("is_unlocked"):
		return false
	var key := String(variant.get("unlock_key", "spell:" + String(variant.get("id", ""))))
	return bool(profile.call("is_unlocked", StringName(key)))


static func portrait_texture(c: Dictionary) -> Texture2D:
	return portrait_info(c).tex


## {tex, emit, bust} : buste `ui/portraits/<id>.png` ou `characters/<id>/portrait.png` (+ `portrait_e.png`),
## sinon 1re frame `idle_s` (bust = false), sinon tex = null.
## `skin_id` : "" = skin équipé du profil (s'il a un portrait livré), "-" = jamais de skin, sinon ce skin.
static func portrait_info(c: Dictionary, skin_id := "") -> Dictionary:
	var id := String(c.get("id", ""))
	var sid := skin_id if skin_id != "" else Skins.equipped(id)
	if sid != "" and sid != "-":
		var sp := Skins.portrait_info(id, sid)
		if bool(sp.exists):
			return sp
	var sf_path := String(c.get("sprite_frames", ""))
	var candidates: Array = []
	if id != "":
		candidates.append([PORTRAIT_DIR + id + ".png", PORTRAIT_DIR + id + "_e.png"])
		var dirs: Array[String] = []
		if sf_path != "":
			dirs.append(sf_path.get_base_dir() + "/")
		if not dirs.has(CHAR_SPRITE_DIR + id + "/"):
			dirs.append(CHAR_SPRITE_DIR + id + "/")
		for d in dirs:
			candidates.append([d + "portrait.png", d + "portrait_e.png"])
	for cand in candidates:
		if ResourceLoader.exists(cand[0]):
			return {"tex": load(cand[0]), "emit": load(cand[1]) if ResourceLoader.exists(cand[1]) else null, "bust": true}
	if sf_path != "" and ResourceLoader.exists(sf_path):
		var sf := load(sf_path) as SpriteFrames
		if sf != null and sf.has_animation(&"idle_s") and sf.get_frame_count(&"idle_s") > 0:
			return {"tex": _crop_to_content(sf.get_frame_texture(&"idle_s", 0)), "emit": null, "bust": false}
	return {"tex": null, "emit": null, "bust": false}


## Frame d'animation rognée à son contenu (le personnage occupe une petite part de sa frame) ;
## sans image lisible (rendu factice en headless) : frame telle quelle.
static func _crop_to_content(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	if img.is_compressed():
		img.decompress()
	var r := img.get_used_rect()
	if r.size.x < 4 or r.size.y < 4 or r.size == img.get_size():
		return tex
	var at := AtlasTexture.new()
	if tex is AtlasTexture:
		at.atlas = (tex as AtlasTexture).atlas
		at.region = Rect2((tex as AtlasTexture).region.position + Vector2(r.position), Vector2(r.size))
	else:
		at.atlas = tex
		at.region = Rect2(r)
	return at


## Accent émissif unique du personnage (`accent` de characters.json, sinon ACCENTS, sinon braise).
static func accent_color(c: Dictionary) -> Color:
	var a := String(c.get("accent", ACCENTS.get(String(c.get("id", "")), "")))
	return Color.from_string(a, COL_FOCUS) if a != "" else COL_FOCUS


## Difficulté de prise en main (`difficulty` de characters.json : 1 débutant, 2 intermédiaire, 3 expert ; 0 = absente).
const DIFFICULTY_NAMES := {1: "Débutant", 2: "Intermédiaire", 3: "Expert"}
const DIFFICULTY_COLORS := {1: Color("#9BE29B"), 2: Color("#FFB347"), 3: Color("#FF6A4D")}


static func difficulty_of(c: Dictionary) -> int:
	var v: Variant = c.get("difficulty", 0)
	if v is String: # tolère "debutant" / "intermediaire" / "expert"
		var s := (v as String).to_lower()
		return 1 if s.begins_with("d") else (2 if s.begins_with("i") else (3 if s.begins_with("e") else 0))
	return clampi(int(v), 0, 3)


## Liste triée du plus facile au plus dur (`difficulty` de characters.json), ordre d'origine conservé à difficulté
## égale (tri stable). Une difficulté absente (0) passe en dernier. Verrouillés et cachés suivent la même règle.
static func sorted_by_difficulty(list: Array) -> Array:
	var idx: Array = []
	for i in list.size():
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool:
		var da := difficulty_of(list[a]) if list[a] is Dictionary else 0
		var db := difficulty_of(list[b]) if list[b] is Dictionary else 0
		da = da if da > 0 else 99
		db = db if db > 0 else 99
		return da < db if da != db else a < b)
	var out: Array = []
	for i in idx:
		out.append(list[i])
	return out


## Pastilles de difficulté (3 losanges : pleins jusqu'au niveau) + libellé optionnel. Style d'UI (placeholder
## jusqu'à une icône DA `ui/menu/difficulty_pip.png`), pas un asset de jeu.
static func make_difficulty_badge(level: int, pip: float, with_label: bool, font_size := 22) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = "Difficulty"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", int(maxf(pip * 0.35, 2.0)))
	h.set_meta(&"level", level)
	var col: Color = DIFFICULTY_COLORS.get(level, COL_GREY)
	for i in 3:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(pip, pip)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var d := Panel.new()
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if i < level else Color(0.1, 0.09, 0.12, 0.9)
		sb.border_color = col.darkened(0.35) if i < level else Color(0.45, 0.46, 0.5)
		sb.set_border_width_all(maxi(1, int(pip / 9.0)))
		d.add_theme_stylebox_override("panel", sb)
		var side := pip * 0.72
		d.size = Vector2(side, side)
		d.pivot_offset = d.size * 0.5
		d.position = Vector2((pip - side) * 0.5, (pip - side) * 0.5)
		d.rotation = PI / 4.0 # losange
		holder.add_child(d)
		h.add_child(holder)
	if with_label:
		var l := make_label(DIFFICULTY_NAMES.get(level, ""), font_size, col, 4)
		l.name = "DifficultyLabel"
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
	return h


static var _gray_shader: Shader


## Désaturation d'état d'UI (verrouillé). Effet système, pas un asset.
static func grayscale_material(brightness := 0.55) -> ShaderMaterial:
	if _gray_shader == null:
		_gray_shader = Shader.new()
		_gray_shader.code = "shader_type canvas_item;\nuniform float brightness = 0.55;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat g = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(vec3(g * brightness), c.a);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = _gray_shader
	m.set_shader_parameter("brightness", brightness)
	return m


## Cadenas : `ui/menu/icon_lock.png` si livrée (TextureRect `sz` x `sz`), sinon placeholder en formes (corps + anse)
## de côté `sz`. PLACEHOLDER temporaire : l'icône finale vient de Codex (art/tools/night/_uxmb.txt).
static func make_lock_icon(sz: float, col := COL_GREY) -> Control:
	if ResourceLoader.exists(LOCK_ICON):
		var tr := TextureRect.new()
		tr.texture = load(LOCK_ICON)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(sz, sz)
		tr.size = Vector2(sz, sz)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var h := Control.new()
	h.name = "LockShape"
	h.custom_minimum_size = Vector2(sz, sz)
	h.size = Vector2(sz, sz)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = col
	bs.set_corner_radius_all(int(sz * 0.08))
	body.add_theme_stylebox_override("panel", bs)
	body.position = Vector2(0.2, 0.46) * sz
	body.size = Vector2(0.6, 0.46) * sz
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(body)
	var shackle := Line2D.new()
	var pts := PackedVector2Array([Vector2(0.3, 0.5) * sz])
	for a in range(0, 9):
		var ang := PI + PI * a / 8.0
		pts.append(Vector2(0.5 + 0.2 * cos(ang), 0.46 + 0.22 * sin(ang)) * sz)
	pts.append(Vector2(0.7, 0.5) * sz)
	shackle.points = pts
	shackle.width = maxf(sz * 0.1, 2.0)
	shackle.default_color = col
	shackle.antialiased = true
	h.add_child(shackle)
	return h


## Coche (mode choisi) : `ui/menu/icon_check.png` si livrée, sinon tracé en 3 points (placeholder).
static func make_check_icon(sz: float, col := Color.WHITE) -> Control:
	if ResourceLoader.exists(CHECK_ICON):
		var tr := TextureRect.new()
		tr.texture = load(CHECK_ICON)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(sz, sz)
		tr.size = Vector2(sz, sz)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var h := Control.new()
	h.name = "CheckShape"
	h.custom_minimum_size = Vector2(sz, sz)
	h.size = Vector2(sz, sz)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Line2D.new()
	l.points = PackedVector2Array([Vector2(0.14, 0.54) * sz, Vector2(0.38, 0.78) * sz, Vector2(0.86, 0.24) * sz])
	l.width = maxf(sz * 0.16, 3.0)
	l.default_color = col
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.antialiased = true
	h.add_child(l)
	return h


static func make_label(txt: String, font_size: int, color := COL_TEXT, outline := 6) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", COL_OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## StyleBox placeholder §2.5 (remplacé par les 9-slice de UiTheme quand ils existeront).
## Plaque des cartes : plaque DA (ui/da/panel_small_9slice, comme le HUD, le coffre et le récap) teintée selon l'état
## (sélection : orangé ; verrouillée : assombrie). Repli : boîte plate. `use_da` = false pour les petites vignettes.
static func panel_box(bg := COL_PANEL, border := COL_BORDER, border_w := 2, alpha := 0.86, use_da := true) -> StyleBox:
	var da := UiTheme.da_box("panel_small_9slice", 0.5) if use_da else null
	if da != null:
		var tint := Color.WHITE
		if border == COL_FOCUS or border == Color("#FFB347"):
			tint = Color(1.6, 1.2, 0.8)
		elif bg == Color("#C23B12"):
			tint = Color(1.8, 0.95, 0.75)
		elif bg.v < COL_PANEL.v - 0.05:
			tint = Color(0.62, 0.62, 0.68)
		elif bg.v > COL_PANEL.v + 0.05:
			tint = Color(1.25, 1.25, 1.3)
		da.modulate_color = tint
		da.content_margin_left = maxf(da.content_margin_left, 16.0)
		da.content_margin_right = maxf(da.content_margin_right, 16.0)
		da.content_margin_top = maxf(da.content_margin_top, 12.0)
		da.content_margin_bottom = maxf(da.content_margin_bottom, 12.0)
		return da
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg, alpha)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


static func focus_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = COL_FOCUS
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	sb.expand_margin_left = 4
	sb.expand_margin_right = 4
	sb.expand_margin_top = 4
	sb.expand_margin_bottom = 4
	return sb


static func play_ui(id: StringName, db := 0.0, pitch := 1.0) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	var audio := loop.root.get_node_or_null("Audio") if loop != null else null
	if audio != null and audio.has_method("play_ui"):
		audio.call("play_ui", id, db, pitch)


static func fmt_num(v: float) -> String:
	var s := ("%d" % int(v)) if is_equal_approx(v, round(v)) else String.num(v, 2)
	return s.replace(".", ",")
