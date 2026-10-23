extends Node
## Déclare les actions d'entrée au démarrage (évite d'éditer [input] dans project.godot à plusieurs).
## - Clavier : physical_keycode uniquement (position physique des touches, indépendante de la disposition).
##   Sur AZERTY, Z/Q/S/D tombent donc sur les touches physiques W/A/S/D : le même mapping couvre ZQSD, WASD et QWERTY.
## - Manette : stick gauche = déplacement, stick droit = visée (aim_*), gâchettes/boutons = sorts 2-4, LB = roulade.
## - Souris : clic gauche = sort 2, clic droit = sort 3, clic molette = sort 4 (la rotation de la molette n'est plus
##   liée par défaut : un défilement involontaire lançait l'ultime, audit E-02 ; elle reste assignable). Ces liaisons
##   ne sont actives qu'hors mode tactile (Platform les bascule) pour qu'un toucher émulé en souris ne lance pas de sort.
## Mobile : joystick flottant et boutons tactiles, gérés par l'UI.
##
## Remappage (audit E-01, lot A11y-L5) : chaque action de REMAP_ACTIONS a des emplacements par périphérique
## (« kbm » : SLOTS_KBM, « pad » : SLOTS_PAD). Les surcharges du joueur sont dans settings.cfg, section [input],
## clé « <action>.<kbm|pad> » = tableau d'événements sérialisés (serialize_event), via GameSettings.get_value /
## set_value (rien n'est écrit en headless sur le vrai fichier ; tests : GameSettings.cfg_path injecté puis
## load_overrides()). Les liaisons fixes (sticks, pause Échap/Start, P) ne se remappent pas.
## Conflit : la touche prise à une autre action du même groupe (« jeu » ou « coffre ») lui est échangée.

signal bindings_changed

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"spell_2": [KEY_1, KEY_J],
	"spell_3": [KEY_2, KEY_K],
	"spell_4": [KEY_3, KEY_L], ## R retiré (3 emplacements clavier-souris : clic molette, 3, L)
	"interact": [KEY_E], ## Espace est passé à la roulade
	"dodge": [KEY_SHIFT, KEY_SPACE], ## Shift gauche (KEY_LOCATION_LEFT) + Espace
	"pause": [KEY_ESCAPE, KEY_P],
}
const ACTIONS := KEYS ## compat (anciens appels)

const JOY_BUTTONS := {
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"spell_2": [JOY_BUTTON_X],
	"spell_3": [JOY_BUTTON_B],
	"spell_4": [JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER],
	"interact": [JOY_BUTTON_A],
	"dodge": [JOY_BUTTON_LEFT_SHOULDER], ## LB : B et LT sont déjà pris par le sort 3
	"pause": [JOY_BUTTON_START],
}
## action -> [axe, signe]
const JOY_AXES := {
	"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	"move_up": [[JOY_AXIS_LEFT_Y, -1.0]],
	"move_down": [[JOY_AXIS_LEFT_Y, 1.0]],
	"aim_left": [[JOY_AXIS_RIGHT_X, -1.0]],
	"aim_right": [[JOY_AXIS_RIGHT_X, 1.0]],
	"aim_up": [[JOY_AXIS_RIGHT_Y, -1.0]],
	"aim_down": [[JOY_AXIS_RIGHT_Y, 1.0]],
	"spell_2": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"spell_3": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
}
const AIM_ACTIONS := ["aim_left", "aim_right", "aim_up", "aim_down"]
## action -> boutons souris (liaisons « pointeur », hors mode tactile)
const MOUSE_BUTTONS := {
	"spell_2": [MOUSE_BUTTON_LEFT],
	"spell_3": [MOUSE_BUTTON_RIGHT],
	"spell_4": [MOUSE_BUTTON_MIDDLE],
}

const SLOTS_KBM := 3 ## Principal · Secondaire · Tertiaire (souris + 2 touches pour les sorts)
const SLOTS_PAD := 2
const SECTION := "input"
## Actions remappables, dans l'ordre de l'écran Commandes : [action, libellé, groupe, pad remappable].
## Déplacement à la manette : stick fixe (la croix reste liée par défaut, non affichée).
const REMAP_ACTIONS := [
	[&"move_up", "Haut", "jeu", false],
	[&"move_down", "Bas", "jeu", false],
	[&"move_left", "Gauche", "jeu", false],
	[&"move_right", "Droite", "jeu", false],
	[&"spell_2", "Sort 2", "jeu", true],
	[&"spell_3", "Sort 3", "jeu", true],
	[&"spell_4", "Sort 4", "jeu", true],
	[&"dodge", "Roulade", "jeu", true],
	[&"interact", "Interagir", "jeu", true],
	[&"chest_pick_1", "Coffre : objet 1", "coffre", true],
	[&"chest_pick_2", "Coffre : objet 2", "coffre", true],
	[&"chest_reroll_ad", "Coffre : relance gratuite", "coffre", true],
	[&"chest_reroll_gold", "Coffre : relance à l'or", "coffre", true],
	[&"chest_items", "Coffre : mes objets", "coffre", true],
]
## Touches jamais assignables : Échap, P et Start (pause / annulation de l'écoute, toujours actifs).
const RESERVED_KEYS := [KEY_ESCAPE, KEY_P] ## P = pause (liaison fixe)
const RESERVED_PAD := [JOY_BUTTON_START]

## Manette débranchée (audit E-11) : PauseMenu ouvre la pause avec « Manette déconnectée » si l'on jouait au pad.
signal pad_disconnected(device: int)

var last_pad_device := -1 ## dernière manette utilisée (famille des invites, InputLabels.pad_family)
var pad_family_override := "" ## tests / réglage futur : « xbox », « ps », « nintendo », « generic »
var _pointer_bound := false
var _defaults := {} ## action -> {"kbm": [InputEvent], "pad": [InputEvent], "fixed": [InputEvent]}
var _binds := {} ## action -> {"kbm": [...], "pad": [...]} (liaisons courantes)


func _enter_tree() -> void:
	_build_defaults()
	for action in _defaults:
		_binds[action] = {"kbm": _dup(_defaults[action]["kbm"]), "pad": _dup(_defaults[action]["pad"])}
	if not (GameSettings.cfg_path == GameSettings.PATH and DisplayServer.get_name() == "headless"):
		_read_overrides()
	for action in _defaults:
		_apply(action)
	apply_stick_deadzone()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


## Zone morte des sticks (A11y-L9, audit A-14) : GameSettings.stick_deadzone() (0,10-0,35, défaut 0,20) appliquée
## aux actions move_* et aim_* ; relue au plus une fois par seconde (la bascule du panneau s'applique sans appel).
const DEADZONE_POLL_S := 1.0
var stick_deadzone := -1.0
var _dz_poll := 0.0


func apply_stick_deadzone() -> void:
	stick_deadzone = GameSettings.stick_deadzone()
	for action in ["move_left", "move_right", "move_up", "move_down"] + AIM_ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, stick_deadzone)


func _process(delta: float) -> void:
	_dz_poll += delta
	if _dz_poll < DEADZONE_POLL_S:
		return
	_dz_poll = 0.0
	if not is_equal_approx(GameSettings.stick_deadzone(), stick_deadzone):
		apply_stick_deadzone()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.device >= 0 and event.device != last_pad_device:
			if event is InputEventJoypadButton or absf((event as InputEventJoypadMotion).axis_value) > 0.5:
				last_pad_device = event.device


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	if device == last_pad_device:
		var pads := Input.get_connected_joypads()
		last_pad_device = pads[0] if not pads.is_empty() else -1
	pad_disconnected.emit(device)


func _build_defaults() -> void:
	var dz := {}
	for action in KEYS:
		_def(action)
		dz[StringName(action)] = 0.2
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			if key == KEY_SHIFT:
				ev.location = KEY_LOCATION_LEFT
			_slot_or_fixed(action, ev)
	for action in MOUSE_BUTTONS:
		var arr: Array = _defaults[StringName(action)]["kbm"]
		var at := 0
		for b in MOUSE_BUTTONS[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = b
			arr.insert(at, ev) # souris en emplacement principal
			at += 1
	for action in AIM_ACTIONS:
		_def(action)
		dz[StringName(action)] = 0.25
	for action in JOY_BUTTONS:
		_def(action)
		for b in JOY_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = b
			_slot_or_fixed(action, ev)
	for action in JOY_AXES:
		_def(action)
		if not dz.has(StringName(action)):
			dz[StringName(action)] = 0.25 if action.begins_with("aim") else 0.2
		for pair in JOY_AXES[action]:
			var ev := InputEventJoypadMotion.new()
			ev.axis = pair[0]
			ev.axis_value = pair[1]
			var trig: bool = pair[0] == JOY_AXIS_TRIGGER_LEFT or pair[0] == JOY_AXIS_TRIGGER_RIGHT
			if trig and is_remappable(action):
				_defaults[StringName(action)]["pad"].append(ev)
			else:
				_defaults[StringName(action)]["fixed"].append(ev)
	var chest: Dictionary = ChestUI.ACTION_DEFAULTS
	for action in chest:
		_def(action)
		dz[StringName(action)] = 0.5
		for k in chest[action]["keys"]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			_defaults[StringName(action)]["kbm"].append(ev)
		for b in chest[action]["pad"]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			_defaults[StringName(action)]["pad"].append(jb)
	for action in _defaults:
		if not InputMap.has_action(action):
			InputMap.add_action(action, dz.get(action, 0.2))


func _def(action: StringName) -> void:
	if not _defaults.has(action):
		_defaults[action] = {"kbm": [], "pad": [], "fixed": []}


## Événement de liaison par défaut : emplacement remappable ou liaison fixe (pause, sticks).
func _slot_or_fixed(action: StringName, ev: InputEvent) -> void:
	var dev := device_of(ev)
	if is_remappable(action) and (dev == "kbm" or pad_remappable(action)):
		_defaults[action][dev].append(ev)
	else:
		_defaults[action]["fixed"].append(ev)


static func _dup(arr: Array) -> Array:
	var out: Array = []
	for ev in arr:
		out.append((ev as InputEvent).duplicate())
	return out


## Reconstruit l'action dans l'InputMap : clavier-souris (souris seulement si les liaisons pointeur sont
## actives), manette, puis liaisons fixes.
func _apply(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_erase_events(action)
	var b: Dictionary = _binds.get(action, {"kbm": [], "pad": []})
	for ev in b["kbm"]:
		if ev is InputEventMouseButton and not _pointer_bound:
			continue
		InputMap.action_add_event(action, ev)
	for ev in b["pad"]:
		InputMap.action_add_event(action, ev)
	for ev in _defaults[action]["fixed"]:
		InputMap.action_add_event(action, ev)


## Active/désactive les liaisons souris des sorts (appelé par Platform selon le mode d'entrée).
func set_pointer_bindings(enabled: bool) -> void:
	if enabled == _pointer_bound:
		return
	_pointer_bound = enabled
	for action in _binds:
		for ev in _binds[action]["kbm"]:
			if ev is InputEventMouseButton:
				_apply(action)
				break


func pointer_bound() -> bool:
	return _pointer_bound


# --- Remappage ---------------------------------------------------------------

static func is_remappable(action: StringName) -> bool:
	for r in REMAP_ACTIONS:
		if r[0] == action:
			return true
	return false


static func pad_remappable(action: StringName) -> bool:
	for r in REMAP_ACTIONS:
		if r[0] == action:
			return r[3]
	return false


static func group_of(action: StringName) -> String:
	for r in REMAP_ACTIONS:
		if r[0] == action:
			return r[2]
	return ""


static func action_title(action: StringName) -> String:
	for r in REMAP_ACTIONS:
		if r[0] == action:
			return r[1]
	return str(action)


static func slot_count(device: String) -> int:
	return SLOTS_KBM if device == "kbm" else SLOTS_PAD


## « kbm » (touche, bouton de souris), « pad » (bouton, axe de manette) ou « ».
static func device_of(ev: InputEvent) -> String:
	if ev is InputEventKey or ev is InputEventMouseButton:
		return "kbm"
	if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
		return "pad"
	return ""


## Liaisons courantes d'une action pour un périphérique (copies, emplacement 0 = principal).
func bindings(action: StringName, device: String) -> Array:
	if not _binds.has(action):
		return []
	return _dup(_binds[action][device])


func default_bindings(action: StringName, device: String) -> Array:
	if not _defaults.has(action):
		return []
	return _dup(_defaults[action][device])


func is_default(action: StringName, device := "") -> bool:
	for d in (["kbm", "pad"] if device == "" else [device]):
		if _ser_list(_binds[action][d]) != _ser_list(_defaults[action][d]):
			return false
	return true


## Événement acceptable pour un emplacement du périphérique (écoute de l'écran Commandes).
static func is_bindable(ev: InputEvent, device: String) -> bool:
	if device_of(ev) != device:
		return false
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return code != KEY_NONE and not (code in RESERVED_KEYS)
	if ev is InputEventJoypadButton:
		return not ((ev as InputEventJoypadButton).button_index in RESERVED_PAD)
	if ev is InputEventJoypadMotion:
		var ax := (ev as InputEventJoypadMotion).axis
		return ax == JOY_AXIS_TRIGGER_LEFT or ax == JOY_AXIS_TRIGGER_RIGHT
	return ev is InputEventMouseButton


## Copie normalisée d'un événement capté (touche physique, axe signé, sans état « pressé »).
static func normalized(ev: InputEvent) -> InputEvent:
	return deserialize_event(serialize_event(ev))


## Assigne `ev` à l'emplacement `slot` de l'action. Conflit dans le même groupe : la touche est échangée
## (l'autre action reçoit l'ancienne liaison de cet emplacement, ou la perd si l'emplacement était vide).
## Retourne l'action dépossédée (ou &"") ; sauvegarde les surcharges.
func rebind(action: StringName, device: String, slot: int, ev: InputEvent) -> StringName:
	if not is_remappable(action) or not is_bindable(ev, device) or slot < 0 or slot >= slot_count(device):
		return &""
	if device == "pad" and not pad_remappable(action):
		return &""
	var nev := normalized(ev)
	var key := serialize_event(nev)
	var mine: Array = _binds[action][device]
	var old: InputEvent = mine[slot] if slot < mine.size() else null
	# déjà sur cette action (autre emplacement) : simple échange d'emplacements
	for i in mine.size():
		if serialize_event(mine[i]) == key:
			if i == slot:
				return &""
			if old != null:
				mine[i] = old
			else:
				mine.remove_at(i)
			break
	var swapped: StringName = &""
	var grp := group_of(action)
	for other in _binds:
		if other == action or group_of(other) != grp:
			continue
		var arr: Array = _binds[other][device]
		for i in arr.size():
			if serialize_event(arr[i]) == key:
				if old != null:
					arr[i] = old.duplicate()
				else:
					arr.remove_at(i)
				swapped = other
				break
		if swapped != &"":
			break
	mine = _binds[action][device]
	if slot < mine.size():
		mine[slot] = nev
	else:
		mine.append(nev)
	_apply(action)
	if swapped != &"":
		_apply(swapped)
		_save(swapped)
	_save(action)
	bindings_changed.emit()
	return swapped


## Retire la liaison d'un emplacement (l'action garde au moins une liaison par périphérique).
func clear_slot(action: StringName, device: String, slot: int) -> bool:
	if not _binds.has(action):
		return false
	var arr: Array = _binds[action][device]
	if slot >= arr.size() or arr.size() <= 1:
		return false
	arr.remove_at(slot)
	_apply(action)
	_save(action)
	bindings_changed.emit()
	return true


## Remet une action (ou toutes si action == &"") aux liaisons par défaut et efface ses surcharges.
func reset(action: StringName = &"", device := "") -> void:
	var list: Array = [action] if action != &"" else _binds.keys()
	for a in list:
		if not _binds.has(a):
			continue
		for d in (["kbm", "pad"] if device == "" else [device]):
			_binds[a][d] = _dup(_defaults[a][d])
		_apply(a)
		_save(a)
	bindings_changed.emit()


## Relit les surcharges [input] (tests : après avoir injecté GameSettings.cfg_path).
func load_overrides() -> void:
	for action in _defaults:
		_binds[action] = {"kbm": _dup(_defaults[action]["kbm"]), "pad": _dup(_defaults[action]["pad"])}
	_read_overrides()
	for action in _defaults:
		_apply(action)
	bindings_changed.emit()


func _read_overrides() -> void:
	for r in REMAP_ACTIONS:
		var action: StringName = r[0]
		for d in ["kbm", "pad"]:
			var raw: Variant = GameSettings.get_value(SECTION, "%s.%s" % [action, d], "")
			if not (raw is Array or raw is PackedStringArray):
				continue
			var arr: Array = []
			for s in raw:
				var ev := deserialize_event(str(s))
				if ev != null and is_bindable(ev, d) and arr.size() < slot_count(d):
					arr.append(ev)
			if not arr.is_empty():
				_binds[action][d] = arr


func _save(action: StringName) -> void:
	if not is_remappable(action):
		return
	for d in ["kbm", "pad"]:
		var k := "%s.%s" % [action, d]
		var cur := _ser_list(_binds[action][d])
		if cur == _ser_list(_defaults[action][d]):
			if str(GameSettings.get_value(SECTION, k, "")) != "":
				GameSettings.set_value(SECTION, k, null) # null efface la clé
		else:
			GameSettings.set_value(SECTION, k, cur)


static func _ser_list(arr: Array) -> Array:
	var out: Array = []
	for ev in arr:
		out.append(serialize_event(ev))
	return out


## « k:<physical_keycode>[:<location>] », « m:<bouton> », « jb:<bouton> », « ja:<axe>:<+|-> ».
static func serialize_event(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return "k:%d:%d" % [code, k.location] if k.location != KEY_LOCATION_UNSPECIFIED else "k:%d" % code
	if ev is InputEventMouseButton:
		return "m:%d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventJoypadButton:
		return "jb:%d" % (ev as InputEventJoypadButton).button_index
	if ev is InputEventJoypadMotion:
		var jm := ev as InputEventJoypadMotion
		return "ja:%d:%s" % [jm.axis, "-" if jm.axis_value < 0.0 else "+"]
	return ""


static func deserialize_event(s: String) -> InputEvent:
	var p := s.split(":")
	if p.size() < 2 or not p[1].is_valid_int():
		return null
	match p[0]:
		"k":
			var ev := InputEventKey.new()
			ev.physical_keycode = int(p[1]) as Key
			if p.size() > 2 and p[2].is_valid_int():
				ev.location = int(p[2]) as KeyLocation
			return ev
		"m":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(p[1]) as MouseButton
			return mb
		"jb":
			var jb := InputEventJoypadButton.new()
			jb.button_index = int(p[1]) as JoyButton
			return jb
		"ja":
			var jm := InputEventJoypadMotion.new()
			jm.axis = int(p[1]) as JoyAxis
			jm.axis_value = -1.0 if p.size() > 2 and p[2] == "-" else 1.0
			return jm
	return null
