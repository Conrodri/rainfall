class_name FocusFollow
extends Node
## Focus visible cohérent pour les écrans de choix (cartes / boutons alignés) : aucune carte privilégiée.
##  - Souris : le contour suit le survol (la carte survolée prend le focus, il est rendu quand la souris la quitte) ;
##  - Tactile : aucun focus, donc aucun contour ;
##  - Manette : focus initial sur le premier contrôle, déplaçable partout, même style sur chacun ;
##  - Clavier : pas de focus au départ, la première touche de navigation / validation le pose sur le premier contrôle.
## Usage : FocusFollow.attach(host, controls) après avoir construit les contrôles (focus_mode = FOCUS_ALL).

var _host: Node = null
var _ctrls: Array[Control] = []
var _hover_focus: Control = null ## contrôle dont le focus vient du survol (relâché à la sortie du curseur)

const NAV_ACTIONS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_accept",
	&"ui_focus_next", &"ui_focus_prev"]


## Branche le comportement sur `ctrls` ; `host` porte le nœud (il doit vivre aussi longtemps que l'écran).
static func attach(host: Node, ctrls: Array) -> FocusFollow:
	var f := FocusFollow.new()
	f.name = "FocusFollow"
	f._host = host
	for c in ctrls:
		if c is Control:
			f._ctrls.append(c)
	host.add_child(f)
	f._wire()
	return f


func _wire() -> void:
	for c in _ctrls:
		c.mouse_entered.connect(_on_enter.bind(c))
		c.mouse_exited.connect(_on_exit.bind(c))
		c.focus_exited.connect(_on_focus_lost.bind(c))
	Platform.input_mode_changed.connect(_on_mode)
	if Platform.is_gamepad_mode():
		focus_first.call_deferred()


## Premier contrôle utilisable (focus manette / clavier).
func focus_first() -> void:
	if not _enabled():
		return
	for c in _ctrls:
		if is_instance_valid(c) and c.is_visible_in_tree() and not _disabled(c):
			c.grab_focus()
			return


## Vrai quand un focus posé d'office (sans geste du joueur) est acceptable : manette uniquement.
static func auto_focus_ok() -> bool:
	return Platform.is_gamepad_mode()


func _enabled() -> bool:
	return not Platform.is_touch_mode()


static func _disabled(c: Control) -> bool:
	return c is BaseButton and (c as BaseButton).disabled


func _focus_inside() -> bool:
	var fo := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return fo != null and _ctrls.has(fo)


func _on_enter(c: Control) -> void:
	if not _enabled() or _disabled(c) or not c.is_visible_in_tree():
		return
	if c.has_focus():
		return
	_hover_focus = c
	c.grab_focus()


func _on_exit(c: Control) -> void:
	if _hover_focus == c and c.has_focus():
		c.release_focus()
	if _hover_focus == c:
		_hover_focus = null


func _on_focus_lost(c: Control) -> void:
	if _hover_focus == c:
		_hover_focus = null


func _on_mode(mode: int) -> void:
	if mode == Platform.InputMode.TOUCH:
		var fo := get_viewport().gui_get_focus_owner()
		if fo != null and _ctrls.has(fo):
			fo.release_focus()
	elif mode == Platform.InputMode.GAMEPAD and not _focus_inside():
		focus_first()


func _input(event: InputEvent) -> void:
	if not _enabled() or _focus_inside() or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventMouse or event is InputEventScreenTouch:
		return
	for a in NAV_ACTIONS:
		if event.is_action(a):
			focus_first()
			get_viewport().set_input_as_handled()
			return
