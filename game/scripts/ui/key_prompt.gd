class_name KeyPrompt
extends HBoxContainer
## Invite de touche d'une action pour le mode d'entrée courant, avec les icônes rendues dans Blender
## (assets/sprites/ui/prompts) : souris (mouse_left/right/wheel), touche (key_1x1 / key_2x1 + texte posé
## en jeu), manette (pad_a/b/x/y… + lettre). Sans icône livrée : texte seul (Platform.action_hint).
## set_action() puis refresh() à chaque changement de mode d'entrée.

const DIR := "res://assets/sprites/ui/prompts/"
const MOUSE_ICONS := {MOUSE_BUTTON_LEFT: "mouse_left", MOUSE_BUTTON_RIGHT: "mouse_right",
	MOUSE_BUTTON_MIDDLE: "mouse_wheel", MOUSE_BUTTON_WHEEL_UP: "mouse_wheel", MOUSE_BUTTON_WHEEL_DOWN: "mouse_wheel"}
const PAD_ICONS := {JOY_BUTTON_A: "pad_a", JOY_BUTTON_B: "pad_b", JOY_BUTTON_X: "pad_x", JOY_BUTTON_Y: "pad_y",
	JOY_BUTTON_LEFT_SHOULDER: "pad_lb", JOY_BUTTON_RIGHT_SHOULDER: "pad_rb"}

var action: StringName = &""
var fixed_text := "" ## texte imposé (ex. « Auto » pour le sort 1)
var height := 44.0
const KEY_FACE_TOP := 0.30 ## face claire de key_1x1 / key_2x1 (fractions de la hauteur : biseau au-dessus, tranche au-dessous)
const KEY_FACE_BOTTOM := 0.86


static func _tex(file_name: String) -> Texture2D:
	var p := DIR + file_name + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER


func set_action(a: StringName, text := "") -> void:
	action = a
	fixed_text = text
	refresh()


func set_height(h: float) -> void:
	if not is_equal_approx(h, height):
		height = h
		refresh()


## Texte équivalent (tests, accessibilité).
func text() -> String:
	if _is_blank():
		return ""
	return fixed_text if fixed_text != "" else Platform.action_hint(action)


func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	add_theme_constant_override("separation", int(height * 0.15))
	if _is_blank():
		_add_spacer()
		return
	if fixed_text != "" or action == &"":
		_add_label(fixed_text)
		return
	var parts := Platform.action_prompt_parts(action)
	for i in parts.size():
		var part: Dictionary = parts[i]
		var kind: String = part["kind"]
		var txt: String = part["text"]
		var tex: Texture2D = null
		var cap := ""
		match kind:
			"mouse":
				tex = _tex(MOUSE_ICONS.get(int(part["button"]), ""))
			"pad":
				# icône selon la famille de manette (positionnelle hors Xbox) et gâchettes LT/RT (lot A11y-L6)
				var icon: String = part.get("icon", PAD_ICONS.get(int(part["button"]), ""))
				tex = _tex(icon) if icon != "" else null
				cap = part.get("caption", txt if txt.length() <= 2 else "")
			"key":
				cap = String(part.get("caption", txt)) # forme courte (« Maj ») : le cadre de touche ne déborde pas
				tex = _tex("key_1x1" if cap.length() <= 1 else "key_2x1")
		if tex == null:
			_add_label(txt)
		else:
			_add_icon(tex, cap, kind == "key")
		if i < parts.size() - 1:
			_add_label("/")


func _add_icon(tex: Texture2D, caption: String, dark_text := true) -> void:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(height * tex.get_width() / float(tex.get_height()), height)
	add_child(r)
	if caption != "":
		var l := Label.new()
		l.text = caption
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.anchor_top = KEY_FACE_TOP # la légende tient sur la face claire de la touche, pas sur son biseau ni sa tranche
		l.anchor_bottom = KEY_FACE_BOTTOM
		l.offset_top = 0.0
		l.offset_bottom = 0.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fs := maxi(int(height * (KEY_FACE_BOTTOM - KEY_FACE_TOP) * 0.7), HudMetrics.floor_px()) # ligne <= 70 % de la face : marge d'encre >= 15 %
		var inner := r.custom_minimum_size.x * 0.8 # zone utile du cadre (biseau exclu)
		var font := r.get_theme_font(&"font", &"Label") # police du thème de l'invite (repli : police par défaut)
		if font != null:
			var tw := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if tw > inner: # légende trop large : plus petite, jamais sous le plancher HudMetrics...
				fs = maxi(int(fs * inner / tw), mini(fs, HudMetrics.floor_px()))
				tw = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if tw > inner: # ... sinon le cadre grandit (étiré en largeur)
				r.stretch_mode = TextureRect.STRETCH_SCALE
				r.custom_minimum_size.x = tw / 0.8
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12) if dark_text else Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.6) if dark_text else Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 2)
		r.add_child(l)


## Sort 1 (automatique) : aucune touche ne le lance, l'étiquette « AUTO » est déjà dans son rond (audit H4).
func _is_blank() -> bool:
	return action == &"spell_1" or fixed_text == "Auto"


## Colonne vide de même hauteur que les autres invites (l'alignement des sorts ne bouge pas).
func _add_spacer() -> void:
	var sp := Control.new()
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.custom_minimum_size = Vector2(height, height)
	add_child(sp)


func _add_label(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", int(height * 0.62))
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
