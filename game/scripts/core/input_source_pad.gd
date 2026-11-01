class_name InputSourcePad
extends InputSource
## Source d'entrée d'UNE manette (coop locale) : lit les liaisons manette de l'InputMap (remappages compris) sur le
## seul appareil `device`, sans toucher aux actions globales. État « juste pressé » calculé par poll(), appelé une
## fois par image de physique par Players. Aucune allocation par image (dictionnaires remplis à la construction).

## Actions suivies (gameplay + écran de coffre).
const TRACKED: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"aim_left", &"aim_right", &"aim_up", &"aim_down",
	&"spell_2", &"spell_3", &"spell_4", &"interact", &"dodge", &"pause",
	&"chest_pick_1", &"chest_pick_2", &"chest_reroll_free", &"chest_reroll_gold", &"chest_items",
]

var _buttons := {} ## action -> PackedInt32Array (JoyButton)
var _axes := {} ## action -> PackedFloat32Array [axe, signe, axe, signe…]
var _dz := {} ## action -> zone morte
var _cur := {} ## action -> bool (enfoncée à la dernière lecture)
var _prev := {} ## action -> bool (lecture d'avant)


func _init(pad_device: int = 0) -> void:
	kind = Kind.PAD
	device = pad_device
	_rebuild()
	if not InputSetup.bindings_changed.is_connected(_rebuild):
		InputSetup.bindings_changed.connect(_rebuild)


## Relit les liaisons manette de l'InputMap (remappage de l'écran Commandes).
func _rebuild() -> void:
	for action in TRACKED:
		var btn := PackedInt32Array()
		var ax := PackedFloat32Array()
		if InputMap.has_action(action):
			for ev in InputMap.action_get_events(action):
				if ev is InputEventJoypadButton:
					btn.append((ev as InputEventJoypadButton).button_index)
				elif ev is InputEventJoypadMotion:
					ax.append(float((ev as InputEventJoypadMotion).axis))
					ax.append(signf((ev as InputEventJoypadMotion).axis_value))
			_dz[action] = InputMap.action_get_deadzone(action)
		else:
			_dz[action] = 0.5
		_buttons[action] = btn
		_axes[action] = ax
		if not _cur.has(action):
			_cur[action] = false
			_prev[action] = false


## Force brute de l'action (0-1) sur cette manette, sans zone morte.
func strength(action: StringName) -> float:
	var s := 0.0
	var btn: PackedInt32Array = _buttons.get(action, PackedInt32Array())
	for b in btn:
		if Input.is_joy_button_pressed(device, b):
			return 1.0
	var ax: PackedFloat32Array = _axes.get(action, PackedFloat32Array())
	var i := 0
	while i + 1 < ax.size():
		s = maxf(s, clampf(Input.get_joy_axis(device, int(ax[i])) * ax[i + 1], 0.0, 1.0))
		i += 2
	return s


func _vector(neg_x: StringName, pos_x: StringName, neg_y: StringName, pos_y: StringName) -> Vector2:
	var raw := Vector2(strength(pos_x) - strength(neg_x), strength(pos_y) - strength(neg_y))
	var dz := (float(_dz.get(neg_x, 0.2)) + float(_dz.get(pos_x, 0.2)) + float(_dz.get(neg_y, 0.2)) + float(_dz.get(pos_y, 0.2))) * 0.25
	var length := raw.length()
	if length <= dz:
		return Vector2.ZERO
	# Même règle que Input.get_vector : zone morte circulaire puis remise à l'échelle, longueur <= 1.
	return raw * (minf(inverse_lerp(dz, 1.0, length), 1.0) / length)


func mode() -> int:
	return Platform.InputMode.GAMEPAD


func move_vector() -> Vector2:
	return _vector(&"move_left", &"move_right", &"move_up", &"move_down")


func aim_vector() -> Vector2:
	return _vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")


func is_pressed(action: StringName) -> bool:
	return strength(action) > float(_dz.get(action, 0.5))


func just_pressed(action: StringName) -> bool:
	return bool(_cur.get(action, false)) and not bool(_prev.get(action, false))


func just_released(action: StringName) -> bool:
	return not bool(_cur.get(action, false)) and bool(_prev.get(action, false))


## Pas de pointeur à la manette : la visée passe par aim_vector().
func pointer_world(_canvas: CanvasItem) -> Variant:
	return null


func owns_event(event: InputEvent) -> bool:
	return (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device == device


func poll() -> void:
	for action in TRACKED:
		_prev[action] = _cur[action]
		_cur[action] = is_pressed(action)
