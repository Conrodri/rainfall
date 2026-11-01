class_name InputSourceKbm
extends InputSource
## Source d'entrée clavier-souris SEULE (coop locale : le joueur au clavier ne lit pas les manettes des autres).
## Lit les liaisons clavier (touches physiques) et souris de l'InputMap et de l'écran Commandes, sans les actions
## globales. État « juste pressé » calculé par poll(), appelé une fois par image de physique par Players.

var _keys := {} ## action -> PackedInt32Array (physical_keycode, ou keycode à défaut)
var _mouse := {} ## action -> PackedInt32Array (MouseButton)
var _cur := {}
var _prev := {}


func _init() -> void:
	kind = Kind.KBM
	_rebuild()
	if not InputSetup.bindings_changed.is_connected(_rebuild):
		InputSetup.bindings_changed.connect(_rebuild)


func _rebuild() -> void:
	for action in InputSourcePad.TRACKED:
		var keys := PackedInt32Array()
		var mouse := PackedInt32Array()
		var evs: Array = InputMap.action_get_events(action) if InputMap.has_action(action) else []
		# Les boutons de souris ne sont dans l'InputMap qu'hors mode tactile : on prend aussi les liaisons de l'écran
		# Commandes, un joueur au clavier-souris a toujours sa souris.
		evs.append_array(InputSetup.bindings(action, "kbm"))
		for ev in evs:
			if ev is InputEventKey:
				var k := ev as InputEventKey
				var code := int(k.physical_keycode) if k.physical_keycode != KEY_NONE else int(k.keycode)
				if code != KEY_NONE and not keys.has(code):
					keys.append(code)
			elif ev is InputEventMouseButton:
				var b := int((ev as InputEventMouseButton).button_index)
				if not mouse.has(b):
					mouse.append(b)
		_keys[action] = keys
		_mouse[action] = mouse
		if not _cur.has(action):
			_cur[action] = false
			_prev[action] = false


func mode() -> int:
	return Platform.InputMode.KBM


func is_pressed(action: StringName) -> bool:
	var keys: PackedInt32Array = _keys.get(action, PackedInt32Array())
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return true
	var mouse: PackedInt32Array = _mouse.get(action, PackedInt32Array())
	for b in mouse:
		if Input.is_mouse_button_pressed(b):
			return true
	return false


func move_vector() -> Vector2:
	var v := Vector2(
		(1.0 if is_pressed(&"move_right") else 0.0) - (1.0 if is_pressed(&"move_left") else 0.0),
		(1.0 if is_pressed(&"move_down") else 0.0) - (1.0 if is_pressed(&"move_up") else 0.0))
	return v.limit_length(1.0)


func aim_vector() -> Vector2:
	return Vector2.ZERO


func just_pressed(action: StringName) -> bool:
	return bool(_cur.get(action, false)) and not bool(_prev.get(action, false))


func just_released(action: StringName) -> bool:
	return not bool(_cur.get(action, false)) and bool(_prev.get(action, false))


func pointer_world(canvas: CanvasItem) -> Variant:
	if canvas != null and canvas.is_inside_tree():
		return canvas.get_global_mouse_position()
	return null


func owns_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion


func poll() -> void:
	for action in InputSourcePad.TRACKED:
		_prev[action] = _cur[action]
		_cur[action] = is_pressed(action)
