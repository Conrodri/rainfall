class_name FloatingJoystick
extends Control
## Joystick flottant : apparait sous le pouce dans la zone de ce controle (moitie basse gauche de l'ecran),
## simule les actions move_* via Input.action_press(action, strength). Aucun lien direct avec le joueur.
##
## Audit E-03 / E-05 (lot A11y-L4) :
##   - dessin à `_origin` / `_knob` directement (coordonnées locales de _gui_input), textures livrées
##     ui/joystick/joystick_base.png (256) et joystick_knob.png (128), repli en formes si absentes ;
##   - anneau de repos à REST_ALPHA à l'endroit du dernier appui (affordance) ;
##   - zone gardée à safe.left + EDGE_GAP du bord gauche (geste Retour Android) et au-dessus de la barre de gestes
##     (apply_safe_area, appelée par le HUD) ;
##   - zone morte et taille réglables : GameSettings.stick_deadzone() ([accessibility] stick_deadzone, 0,10-0,35,
##     défaut 0,20, commune aux sticks) et GameSettings.joystick_scale() ([accessibility] joystick_scale, 0,8-1,5,
##     × MAX_RADIUS), relus à chaque nouvel appui (pas à chaque image).

const MAX_RADIUS := 130.0 ## rayon de course à la taille 1 (px logiques)
const KNOB_RADIUS := 52.0
const DEADZONE := 0.12 ## défaut de la zone morte
const DEADZONE_MAX := 0.4
const SIZE_MIN := 0.8
const SIZE_MAX := 1.4
const EDGE_GAP := 24.0 ## écart en plus de la zone sûre à gauche (geste Retour depuis le bord)
const REST_ALPHA := 0.35
const SETTINGS_SECTION := "accessibility"
const KEY_DEADZONE := "stick_deadzone" ## clés de GameSettings (lot Réglages)
const KEY_SIZE := "joystick_scale"
const TEX_BASE := "res://assets/sprites/ui/joystick/joystick_base.png"
const TEX_KNOB := "res://assets/sprites/ui/joystick/joystick_knob.png"
const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

var vector := Vector2.ZERO ## dernier vecteur envoye (lecture/tests)
var deadzone := DEADZONE
var size_factor := 1.0
var _touch := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _rest := Vector2(-1.0, -1.0) ## dernier point d'appui (anneau de repos) ; négatif = position par défaut
var _tex_base: Texture2D = null
var _tex_knob: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if ResourceLoader.exists(TEX_BASE):
		_tex_base = load(TEX_BASE) as Texture2D
	if ResourceLoader.exists(TEX_KNOB):
		_tex_knob = load(TEX_KNOB) as Texture2D
	reload_settings()
	resized.connect(queue_redraw)


## Relit zone morte et taille (GameSettings, section accessibility).
func reload_settings() -> void:
	deadzone = GameSettings.stick_deadzone()
	size_factor = GameSettings.joystick_scale()


## Rayon de course effectif (px logiques).
func radius() -> float:
	return MAX_RADIUS * size_factor


## Garde la zone du joystick hors du bord gauche (geste Retour) et de la barre de gestes du bas.
## `safe` = Platform.safe_margins() (px logiques).
func apply_safe_area(safe: Dictionary) -> void:
	offset_left = float(safe.get("left", 48.0)) + EDGE_GAP
	offset_bottom = -float(safe.get("bottom", 32.0))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch == -1:
			reload_settings()
			_touch = t.index
			_origin = t.position
			_knob = t.position
			_rest = t.position
			_apply(Vector2.ZERO)
			queue_redraw()
			accept_event()
		elif not t.pressed and t.index == _touch:
			release()
			accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch:
			var r := radius()
			var off := (d.position - _origin).limit_length(r)
			_knob = _origin + off
			_apply(off / r)
			queue_redraw()
			accept_event()


## Entree directe (tests / manette) : vecteur normalise dans le disque unite.
func set_vector(v: Vector2) -> void:
	_apply(v.limit_length(1.0))


## Zone morte puis remise à l'échelle : la course utile repart de 0 au bord de la zone morte.
func _apply(v: Vector2) -> void:
	var l := v.length()
	if l < deadzone or l <= 0.0:
		v = Vector2.ZERO
	elif deadzone > 0.0:
		v = v / l * clampf((l - deadzone) / (1.0 - deadzone), 0.0, 1.0)
	vector = v
	_set_action("move_left", maxf(-v.x, 0.0))
	_set_action("move_right", maxf(v.x, 0.0))
	_set_action("move_up", maxf(-v.y, 0.0))
	_set_action("move_down", maxf(v.y, 0.0))


static func _set_action(action: String, strength: float) -> void:
	if not InputMap.has_action(action):
		return
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func release() -> void:
	_touch = -1
	_apply(Vector2.ZERO)
	queue_redraw()


func is_active() -> bool:
	return _touch != -1


## Centre de l'anneau en coordonnées locales : sous le pouce pendant l'appui, sinon le dernier appui (ou un
## point par défaut au tiers bas de la zone).
func ring_center() -> Vector2:
	if _touch != -1:
		return _origin
	if _rest.x >= 0.0:
		return _rest
	var r := radius()
	return Vector2(minf(r + 40.0, size.x * 0.5), maxf(size.y - r - 40.0, size.y * 0.5))


func knob_center() -> Vector2:
	return _knob if _touch != -1 else ring_center()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_EXIT_TREE:
		if _touch != -1 or vector != Vector2.ZERO:
			release()


func _draw() -> void:
	var a := 1.0 if _touch != -1 else REST_ALPHA
	var o := ring_center()
	var k := knob_center()
	var r := radius()
	var kr := KNOB_RADIUS * size_factor
	if _tex_base != null:
		draw_texture_rect(_tex_base, Rect2(o - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, a))
	else:
		draw_circle(o, r, Color(1, 1, 1, 0.10 * a))
		draw_arc(o, r, 0.0, TAU, 48, Color(1, 1, 1, 0.35 * a), 4.0)
	if _tex_knob != null:
		draw_texture_rect(_tex_knob, Rect2(k - Vector2(kr, kr), Vector2(kr, kr) * 2.0), false, Color(1, 1, 1, a))
	else:
		draw_circle(k, kr, Color(1, 1, 1, 0.40 * a))
