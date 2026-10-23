extends Node
## Autoload Platform : détection de plateforme, mode d'entrée courant et couche abstraite
## (pubs, achats, quitter) pour que le reste du jeu ne teste jamais OS.has_feature directement.
##
## Mode d'entrée : bascule au dernier périphérique utilisé (toucher / clavier+souris / manette) et émet
## input_mode_changed. L'UI s'en sert pour afficher ou masquer les contrôles tactiles et les invites.
##
## Affichage : PC = paysage, hauteur logique fixe 1080 (stretch keep_height, cf. project.godot) ;
## mobile = paysage forcé (capteur paysage, décision du joueur), même base 1920×1080 keep_height que le PC.
## Aperçu mobile sur PC : lancer avec `-- --mobile` (fenêtre 960x540, tactile émulé) ; encoche simulée : `-- --mobile --safe=132,0,0,0`.

signal input_mode_changed(mode: int)
## Zone sûre modifiée (encoche passée de gauche à droite en paysage capteur, rotation, redimensionnement) :
## l'UI recalcule sa mise en page (Hud, SafeArea). Sondage toutes les SAFE_POLL_S sur mobile (E-04).
signal safe_area_changed
## Retour système (bouton / geste Retour Android, E-03). Le jeu ne quitte jamais sur Retour
## (application/config/quit_on_go_back = false) : Platform le traduit en Échap (pause en partie, retour dans les menus).
signal back_requested

enum InputMode { TOUCH, KBM, GAMEPAD }

const PC_BASE_SIZE := Vector2i(1920, 1080) ## demande du joueur : au moins 1920×1080 sur PC
const MOBILE_BASE_SIZE := Vector2i(1920, 1080)
const MOUSE_MOVE_THRESHOLD := 3.0 ## px de déplacement relatif pour compter comme usage de la souris
const AXIS_THRESHOLD := 0.5
const SAFE_POLL_S := 0.5 ## sondage de la zone sûre (la taille de la fenêtre ne change pas quand l'encoche change de côté)
const SAFE_MIN_SIDE := 48.0 ## marge minimale gauche / droite (px logiques, base 1080)
const SAFE_MIN_EDGE := 32.0 ## marge minimale haut / bas (barre de gestes)

var input_mode: int = InputMode.KBM
var mobile_preview := false ## simulation mobile sur PC (argument --mobile)
## Encoche simulée (tests, captures, aperçu `-- --mobile --safe=L,T,R,B`) en px logiques :
## {"left", "top", "right", "bottom"}. Vide = zone sûre réelle du système.
var safe_override: Dictionary = {}
var _safe_last: Dictionary = {}
var _safe_t := 0.0
var _synthetic_back := false ## vrai pendant l'injection d'Échap par handle_back() (ne change pas le mode d'entrée)

## Backends futurs (SDK de pubs, boutique). null = indisponible.
var ads_backend: Object = null
var purchases_backend: Object = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mobile_preview = "--mobile" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--safe="):
			var p := arg.trim_prefix("--safe=").split(",")
			if p.size() == 4:
				safe_override = {"left": float(p[0]), "top": float(p[1]), "right": float(p[2]), "bottom": float(p[3])}
	apply_display()
	_set_mode(InputMode.TOUCH if is_mobile() else InputMode.KBM, true)
	_safe_last = safe_margins()


func _process(delta: float) -> void:
	if not is_mobile() and safe_override.is_empty():
		return
	_safe_t += delta
	if _safe_t >= SAFE_POLL_S:
		_safe_t = 0.0
		check_safe_area()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	elif what == NOTIFICATION_WM_SIZE_CHANGED or what == NOTIFICATION_APPLICATION_RESUMED:
		check_safe_area()


## Relit la zone sûre ; émet safe_area_changed si une marge a bougé. Renvoie vrai si elle a changé.
func check_safe_area() -> bool:
	var m := safe_margins()
	if m == _safe_last:
		return false
	_safe_last = m
	safe_area_changed.emit()
	return true


## Simule une encoche (px logiques ; {} = zone sûre réelle). Émet safe_area_changed si les marges changent.
func set_safe_override(insets: Dictionary) -> void:
	safe_override = insets.duplicate()
	check_safe_area()


# --- Retour système (Android) -----------------------------------------------

## Retour Android (bouton ou geste) = Échap : en partie, ouvre la pause (en pause : Reprendre, dans un
## sous-panneau : revient au menu pause) ; dans les menus, Retour / Annuler (ui_cancel). Jamais de sortie brutale.
func handle_back() -> void:
	back_requested.emit()
	if not is_inside_tree():
		return
	var root := get_tree().root
	_synthetic_back = true
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = pressed
		root.push_input(ev)
	# Pause remappée hors d'Échap (remappage L5) : envoyer aussi l'action elle-même.
	var probe := InputEventKey.new()
	probe.physical_keycode = KEY_ESCAPE
	probe.pressed = true
	if InputMap.has_action(&"pause") and not InputMap.event_is_action(probe, &"pause"):
		for pressed in [true, false]:
			var a := InputEventAction.new()
			a.action = &"pause"
			a.pressed = pressed
			root.push_input(a)
	_synthetic_back = false


# --- Plateforme -----------------------------------------------------------

func is_mobile() -> bool:
	return mobile_preview or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func is_ios() -> bool:
	return OS.has_feature("ios")


func is_android() -> bool:
	return OS.has_feature("android")


func is_pc() -> bool:
	return not is_mobile()


## Écran tactile disponible (mobile, ou PC/portable à écran tactile).
func has_touch() -> bool:
	return is_mobile() or DisplayServer.is_touchscreen_available()


## Pas de bouton « Quitter » sur iOS (les apps iOS ne se ferment pas elles-mêmes).
func can_quit() -> bool:
	return not is_ios()


func quit_game() -> void:
	if can_quit():
		get_tree().quit()


# --- Affichage ------------------------------------------------------------

## Mobile : paysage 1080 de haut, comme le PC. PC : paysage 1080 de haut (largeur selon la fenêtre) ;
## fenêtre maximisée si l'écran ne peut pas contenir 1920×1080 (barre des tâches, bordures).
func apply_display() -> void:
	var win := get_tree().root
	if is_mobile():
		win.content_scale_size = MOBILE_BASE_SIZE
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		if mobile_preview and not OS.has_feature("mobile"):
			win.size = Vector2i(960, 540)
	else:
		win.content_scale_size = PC_BASE_SIZE
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		if DisplayServer.get_name() != "headless" and win.mode == Window.MODE_WINDOWED:
			var usable := DisplayServer.screen_get_usable_rect(win.current_screen).size
			if usable.x < PC_BASE_SIZE.x or usable.y < PC_BASE_SIZE.y:
				win.mode = Window.MODE_MAXIMIZED
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	# Sur PC la souris ne doit pas simuler des toucher (sinon un clic active le joystick tactile).
	Input.emulate_touch_from_mouse = mobile_preview


## Taille logique visible (utile à l'UI et aux tests).
func logical_size() -> Vector2:
	return get_viewport().get_visible_rect().size


# --- Mode d'entrée ----------------------------------------------------------

func is_touch_mode() -> bool:
	return input_mode == InputMode.TOUCH


func is_gamepad_mode() -> bool:
	return input_mode == InputMode.GAMEPAD


func is_kbm_mode() -> bool:
	return input_mode == InputMode.KBM


func mode_name() -> String:
	return ["touch", "kbm", "gamepad"][input_mode]


## Force un mode (tests, réglages). Émet input_mode_changed si le mode change.
func set_input_mode(mode: int) -> void:
	_set_mode(mode, false)


func _set_mode(mode: int, force: bool) -> void:
	var changed := mode != input_mode
	input_mode = mode
	var input_setup := get_node_or_null("/root/InputSetup")
	if input_setup != null:
		input_setup.set_pointer_bindings(mode != InputMode.TOUCH)
	if changed and not force:
		input_mode_changed.emit(mode)


func _input(event: InputEvent) -> void:
	if _synthetic_back or event.device == InputEvent.DEVICE_ID_EMULATION:
		return # souris émulée par un toucher (ou l'inverse) : ne dit rien du périphérique réel
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_mode(InputMode.TOUCH, false)
	elif event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			_set_mode(InputMode.GAMEPAD, false)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > AXIS_THRESHOLD:
			_set_mode(InputMode.GAMEPAD, false)
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			_set_mode(InputMode.KBM, false)
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_set_mode(InputMode.KBM, false)
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > MOUSE_MOVE_THRESHOLD:
			_set_mode(InputMode.KBM, false)


# --- Invites d'interaction ------------------------------------------------

## Libellé de la touche/bouton « interagir » pour le mode courant : « E », « A »...
func interact_key_label() -> String:
	return action_label(&"interact")


## Libellés et icônes : scripts/ui/input_labels.gd (lots A11y-L5/L6 : chiffres AZERTY, famille de manette,
## gâchettes, aide générée à partir des liaisons remappées).
const InputLabels := preload("res://scripts/ui/input_labels.gd")


func action_label(action: StringName) -> String:
	return InputLabels.action_label(action, input_mode == InputMode.GAMEPAD)


## Libellé court d'une action pour le mode courant, souris comprise : « Clic G / 1 » (clavier-souris),
## « X » (manette), « » (tactile : les boutons suffisent).
func action_hint(action: StringName) -> String:
	if input_mode == InputMode.TOUCH or not InputMap.has_action(action):
		return ""
	var key := action_label(action)
	if input_mode == InputMode.GAMEPAD:
		return key
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton:
			var m := _mouse_button_name((ev as InputEventMouseButton).button_index)
			return m if key == "?" else "%s / %s" % [m, key]
	return key


## Éléments d'invite d'une action pour le mode courant (icônes ui/prompts) :
## [{"kind": "mouse"|"key"|"pad", "button": int, "text": String, "icon"?: String, "caption"?: String}].
## Manette : premier bouton OU gâchette (LT/RT), icône selon la famille de manette. Vide en mode tactile.
func action_prompt_parts(action: StringName) -> Array:
	if input_mode == InputMode.TOUCH:
		return []
	return InputLabels.prompt_parts(action, input_mode == InputMode.GAMEPAD)


static func _mouse_button_name(b: int) -> String:
	return InputLabels.mouse_label(b)


## Aide « Commandes » du mode d'entrée courant (menu pause, aide de démarrage) : lignes [action, touches],
## construites à partir des liaisons courantes (remappage compris).
func controls_help() -> Array:
	return InputLabels.controls_help(input_mode)


static func _joy_button_name(b: int) -> String:
	return InputLabels.pad_button_label(b)


## « [E] Partir » (clavier), « [A] Partir » (manette). Vide en mode tactile (le bouton géant suffit).
func interact_prompt(label: String) -> String:
	if input_mode == InputMode.TOUCH:
		return label
	return "[%s] %s" % [interact_key_label(), label]


# --- Pubs / achats (stubs) ----------------------------------------------------

## Pubs : jamais sur PC ; sur mobile seulement si un backend est branché.
func ads_available() -> bool:
	return is_mobile() and ads_backend != null


## Demande une pub récompensée. callback(rewarded: bool). Sans backend : échec immédiat.
func show_rewarded_ad(callback: Callable) -> void:
	if ads_available() and ads_backend.has_method("show_rewarded"):
		ads_backend.show_rewarded(callback)
	elif callback.is_valid():
		callback.call(false)


func purchases_available() -> bool:
	return purchases_backend != null


## Lance un achat intégré. callback(success: bool). Sans backend : échec immédiat.
func purchase(sku: String, callback: Callable) -> void:
	if purchases_available() and purchases_backend.has_method("purchase"):
		purchases_backend.purchase(sku, callback)
	elif callback.is_valid():
		callback.call(false)


## Marges de zone sûre en px logiques (base 1080 de haut) : max(encoche, 48) côtés, max(encoche, 32) haut/bas.
## Encoche simulée (safe_override) prioritaire sur la zone sûre du système.
func safe_margins() -> Dictionary:
	if not safe_override.is_empty():
		return {"left": maxf(float(safe_override.get("left", 0.0)), SAFE_MIN_SIDE),
			"top": maxf(float(safe_override.get("top", 0.0)), SAFE_MIN_EDGE),
			"right": maxf(float(safe_override.get("right", 0.0)), SAFE_MIN_SIDE),
			"bottom": maxf(float(safe_override.get("bottom", 0.0)), SAFE_MIN_EDGE)}
	var win := Vector2(DisplayServer.window_get_size())
	var k := 1080.0 / maxf(win.y, 1.0)
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var l := 0.0
	var t := 0.0
	var r := 0.0
	var b := 0.0
	if safe.size.x > 0.0 and is_mobile():
		# La zone sûre est en coordonnées d'écran globales (multi-écran sur PC) : la ramener à l'écran courant.
		var screen := Rect2(Vector2(DisplayServer.screen_get_position()), Vector2(DisplayServer.screen_get_size()))
		l = maxf(safe.position.x - screen.position.x, 0.0) * k
		t = maxf(safe.position.y - screen.position.y, 0.0) * k
		r = maxf(screen.end.x - safe.end.x, 0.0) * k
		b = maxf(screen.end.y - safe.end.y, 0.0) * k
	return {"left": maxf(l, SAFE_MIN_SIDE), "top": maxf(t, SAFE_MIN_EDGE), "right": maxf(r, SAFE_MIN_SIDE), "bottom": maxf(b, SAFE_MIN_EDGE)}

