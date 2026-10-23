extends Control
## Icône du passif (ou de la ressource) du personnage, posée près des sorts par le HUD. Elle ouvre l'infobulle de
## passif (SpellHint) : survol de la souris (PC), appui long de LONG_PRESS_S (tactile, comme les boutons de sort),
## touche Select / Retour maintenue (manette). Aucun clic n'est intercepté hors tactile (la souris vise).
## Texte : `passive_info()` du kit du personnage (contrat KitResource.passive, CONTRACTS.md « Kits »).
## Icône : game/assets/sprites/ui/icons/passives/<icon>.png (brief Codex art/tools/ui/_passive_icons.txt) ;
## absente = pastille à l'initiale du passif (placeholder en code).

const ICON_DIR := "res://assets/sprites/ui/icons/passives/"
const LONG_PRESS_S := 0.6 ## comme SpellButton.LONG_PRESS_S
const LONG_DRIFT_PX := 12.0
const BASE_PX := 72.0 ## côté à ui_scale 1 (PC)
const MOBILE_PX := 96.0 ## tactile : zone de frappe confortable
const FONT_MIN_PC := 18
const FONT_MIN_MOBILE := 26

static var _tex_cache := {}

var char_id: StringName = &""
var info: Dictionary = {}
var accent := Color(1.0, 0.78, 0.35)
var ui_scale := 1.0
var _icon: Texture2D = null
var _touch := -1
var _press_t := 0.0
var _press_pos := Vector2.ZERO
var _drifted := false
var _long := false


## Texte du passif d'un personnage ({name, icon, intro, fills, drains, tiers, desc, hud}), {} si inconnu.
## Kit sans `passive_info` : repli sur la description de sa ressource (jamais vide pour un personnage connu).
static func info_for(cid: StringName) -> Dictionary:
	var script := CharacterData.kit_script_of(cid)
	if script != null:
		for m in script.get_script_method_list():
			if StringName(m.get("name", "")) == &"passive_info":
				var d: Variant = script.call(&"passive_info")
				if d is Dictionary and not (d as Dictionary).is_empty():
					return d
	return {}


## Icône du passif décrit par `info` (clé « icon »), null si le fichier Codex n'est pas livré.
static func icon_for(info: Dictionary) -> Texture2D:
	var n := String(info.get("icon", ""))
	return _tex(n) if n != "" else null


static func _tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		var path := ICON_DIR + name + ".png"
		_tex_cache[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex_cache[name]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Personnage joué : charge son passif ; `hud` faux (Ardent) = badge masqué.
func set_character(cid: StringName, col: Color) -> void:
	char_id = cid
	accent = col
	info = info_for(cid)
	_icon = _tex(String(info.get("icon", ""))) if not info.is_empty() else null
	visible = bool(info.get("hud", false))
	queue_redraw()


func apply_scale(s: float) -> void:
	ui_scale = s
	var px := (MOBILE_PX if Platform.is_mobile() else BASE_PX) * s
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	queue_redraw()


## Tactile : seul mode où le badge reçoit les touches (appui long). Ailleurs la souris reste libre de viser.
func sync_input_mode() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if Platform.input_mode == Platform.InputMode.TOUCH else Control.MOUSE_FILTER_IGNORE


func is_long_pressed() -> bool:
	return _long and _touch != -1


func _process(delta: float) -> void:
	if _touch != -1 and not _long and not _drifted:
		_press_t += delta
		if _press_t >= LONG_PRESS_S:
			_long = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch:
		if (event as InputEventScreenDrag).position.distance_to(_press_pos) >= LONG_DRIFT_PX:
			_drifted = true
			_long = false
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch == -1:
			_touch = t.index
			_press_t = 0.0
			_press_pos = t.position
			_drifted = false
			_long = false
			accept_event()
		elif not t.pressed and t.index == _touch:
			_touch = -1
			_long = false
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		_touch = -1
		_long = false


static func _font_floor() -> int:
	return FONT_MIN_MOBILE if Platform.is_mobile() else FONT_MIN_PC


func _draw() -> void:
	if info.is_empty():
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	var font := ThemeDB.fallback_font
	draw_circle(c, r, Color(0.08, 0.09, 0.13, 0.9))
	draw_arc(c, r, 0.0, TAU, 48, accent, maxf(3.0 * ui_scale, 2.0))
	if _icon != null:
		var side := r * 1.5
		draw_texture_rect(_icon, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false)
	else:
		var name_s := String(info.get("name", "?")).strip_edges()
		var ini := name_s.substr(0, 1).to_upper() if name_s != "" else "?"
		var fi := maxi(int(r * 1.1), _font_floor())
		draw_string_outline(font, c + Vector2(-r, fi * 0.34), ini, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fi, 6, Color(0, 0, 0, 0.9))
		draw_string(font, c + Vector2(-r, fi * 0.34), ini, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fi, accent.lightened(0.35))
	# pastille « ? » : l'icône est une aide, pas un bouton de sort
	var qr := r * 0.36
	var qc := c + Vector2(r * 0.72, -r * 0.72)
	draw_circle(qc, qr + 1.5, Color(0, 0, 0, 0.9))
	draw_circle(qc, qr, Color(0.91, 0.886, 0.839))
	var fq := maxi(int(qr * 1.5), 12)
	draw_string(font, qc + Vector2(-qr, fq * 0.34), "?", HORIZONTAL_ALIGNMENT_CENTER, qr * 2.0, fq, Color(0.08, 0.09, 0.13))
	if Platform.input_mode == Platform.InputMode.GAMEPAD:
		var fl := _font_floor()
		var label := "SELECT"
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fl).x
		var p := Vector2(c.x - w * 0.5, size.y + fl * 0.9)
		draw_string_outline(font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fl, 5, Color(0, 0, 0, 0.9))
		draw_string(font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fl, Color(0.91, 0.886, 0.839))
