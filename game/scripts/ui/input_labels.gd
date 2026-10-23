extends RefCounted
## Libellés et icônes des liaisons d'entrée (lots A11y-L5 / L6, audit E-09 / E-10). Sans class_name :
## `const InputLabels := preload("res://scripts/ui/input_labels.gd")`. Platform y délègue action_label,
## action_prompt_parts et controls_help.
## - Clavier : la rangée des chiffres affiche le chiffre (sur AZERTY la traduction de disposition donnait
##   « & », « é », « " ») ; autres touches traduites selon la disposition, noms en français.
## - Manette : famille lue dans le nom du périphérique (Input.get_joy_name) : xbox (A/B/X/Y, icônes pad_a..y),
##   ps (Croix/Rond/Carré/Triangle), nintendo (B/A/Y/X à la même position que A/B/X/Y Xbox) et générique.
##   Hors Xbox : icônes positionnelles pad_btn_bottom/right/left/top. Gâchettes (axes) : pad_lt / pad_rt.

const FAMILIES := ["xbox", "ps", "nintendo", "generic"]
## bouton -> libellés [xbox, ps, nintendo, générique]
const PAD_NAMES := {
	JOY_BUTTON_A: ["A", "Croix", "B", "Bas"],
	JOY_BUTTON_B: ["B", "Rond", "A", "Droite"],
	JOY_BUTTON_X: ["X", "Carré", "Y", "Gauche"],
	JOY_BUTTON_Y: ["Y", "Triangle", "X", "Haut"],
	JOY_BUTTON_BACK: ["Back", "Create", "−", "Select"],
	JOY_BUTTON_GUIDE: ["Guide", "PS", "Home", "Guide"],
	JOY_BUTTON_START: ["Start", "Options", "+", "Start"],
	JOY_BUTTON_LEFT_STICK: ["L3", "L3", "L3", "L3"],
	JOY_BUTTON_RIGHT_STICK: ["R3", "R3", "R3", "R3"],
	JOY_BUTTON_LEFT_SHOULDER: ["LB", "L1", "L", "L1"],
	JOY_BUTTON_RIGHT_SHOULDER: ["RB", "R1", "R", "R1"],
	JOY_BUTTON_DPAD_UP: ["Flèche haut", "Flèche haut", "Flèche haut", "Flèche haut"],
	JOY_BUTTON_DPAD_DOWN: ["Flèche bas", "Flèche bas", "Flèche bas", "Flèche bas"],
	JOY_BUTTON_DPAD_LEFT: ["Flèche gauche", "Flèche gauche", "Flèche gauche", "Flèche gauche"],
	JOY_BUTTON_DPAD_RIGHT: ["Flèche droite", "Flèche droite", "Flèche droite", "Flèche droite"],
}
const TRIGGER_NAMES := {
	JOY_AXIS_TRIGGER_LEFT: ["LT", "L2", "ZL", "L2"],
	JOY_AXIS_TRIGGER_RIGHT: ["RT", "R2", "ZR", "R2"],
}
const FACE_XBOX_ICONS := {JOY_BUTTON_A: "pad_a", JOY_BUTTON_B: "pad_b", JOY_BUTTON_X: "pad_x", JOY_BUTTON_Y: "pad_y"}
const FACE_POS_ICONS := {JOY_BUTTON_A: "pad_btn_bottom", JOY_BUTTON_B: "pad_btn_right", JOY_BUTTON_X: "pad_btn_left",
	JOY_BUTTON_Y: "pad_btn_top"}
const KEY_NAMES := {
	KEY_SPACE: "Espace", KEY_ESCAPE: "Échap", KEY_ENTER: "Entrée", KEY_KP_ENTER: "Entrée (pavé)", KEY_TAB: "Tab",
	KEY_BACKSPACE: "Retour arr.", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_SHIFT: "Shift", KEY_CAPSLOCK: "Verr. maj",
	KEY_UP: "Haut", KEY_DOWN: "Bas", KEY_LEFT: "Gauche", KEY_RIGHT: "Droite", KEY_DELETE: "Suppr",
	KEY_INSERT: "Inser", KEY_HOME: "Début", KEY_END: "Fin", KEY_PAGEUP: "Page préc.", KEY_PAGEDOWN: "Page suiv.",
}
const ARROWS := [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]


# --- Famille de manette --------------------------------------------------------

## Famille d'après le nom du périphérique. Nom vide (aucune manette) : xbox (invites historiques).
static func family_of_name(joy_name: String) -> String:
	var n := joy_name.to_lower()
	if n.strip_edges() == "":
		return "xbox"
	for w in ["dualsense", "dualshock", "playstation", "ps3", "ps4", "ps5", "sony"]:
		if w in n:
			return "ps"
	for w in ["nintendo", "switch", "joy-con", "joycon", "pro controller"]:
		if w in n:
			return "nintendo"
	for w in ["xbox", "xinput", "microsoft", "x-box"]:
		if w in n:
			return "xbox"
	return "generic"


static func pad_family() -> String:
	var setup := _setup()
	if setup == null:
		return "xbox"
	var forced: String = setup.get(&"pad_family_override")
	if forced != "":
		return forced
	var dev: int = setup.get(&"last_pad_device")
	if dev < 0:
		var pads := Input.get_connected_joypads()
		dev = pads[0] if not pads.is_empty() else -1
	return family_of_name(Input.get_joy_name(dev) if dev >= 0 else "")


static func _setup() -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.root.get_node_or_null(^"InputSetup") if ml != null else null


static func _fi(fam: String) -> int:
	return maxi(FAMILIES.find(fam), 0)


# --- Libellés d'un événement ---------------------------------------------------

static func key_label(k: InputEventKey) -> String:
	var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	if code >= KEY_0 and code <= KEY_9:
		return char(code) # rangée des chiffres : le chiffre, quelle que soit la disposition (E-10)
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return "Pavé %d" % (code - KEY_KP_0)
	if code == KEY_SHIFT:
		return "Shift gauche" if k.location == KEY_LOCATION_LEFT else ("Shift droit" if k.location == KEY_LOCATION_RIGHT else "Shift")
	if KEY_NAMES.has(code):
		return KEY_NAMES[code]
	var loc: Key = KEY_NONE
	if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
		loc = DisplayServer.keyboard_get_keycode_from_physical(code) # vraie lettre selon la disposition (AZERTY…)
	var s := OS.get_keycode_string(loc if loc != KEY_NONE else code)
	return s.to_upper() if s.length() == 1 else s


static func mouse_label(b: int) -> String:
	match b:
		MOUSE_BUTTON_LEFT: return "Clic G"
		MOUSE_BUTTON_RIGHT: return "Clic D"
		MOUSE_BUTTON_MIDDLE: return "Molette"
		MOUSE_BUTTON_WHEEL_UP: return "Molette haut"
		MOUSE_BUTTON_WHEEL_DOWN: return "Molette bas"
		MOUSE_BUTTON_XBUTTON1: return "Souris 4"
		MOUSE_BUTTON_XBUTTON2: return "Souris 5"
	return "Souris %d" % b


static func pad_button_label(b: int, fam := "") -> String:
	var f := _fi(fam if fam != "" else pad_family())
	if PAD_NAMES.has(b):
		return PAD_NAMES[b][f]
	return "Bouton %d" % b


static func pad_label(ev: InputEvent, fam := "") -> String:
	if ev is InputEventJoypadButton:
		return pad_button_label((ev as InputEventJoypadButton).button_index, fam)
	if ev is InputEventJoypadMotion:
		var ax := (ev as InputEventJoypadMotion).axis
		if TRIGGER_NAMES.has(ax):
			return TRIGGER_NAMES[ax][_fi(fam if fam != "" else pad_family())]
		return "Axe %d" % ax
	return "?"


## Icône d'invite (assets/sprites/ui/prompts, sans extension) d'un événement de manette, « » sinon.
static func pad_icon(ev: InputEvent, fam := "") -> String:
	var f := fam if fam != "" else pad_family()
	if ev is InputEventJoypadButton:
		var b := (ev as InputEventJoypadButton).button_index
		if f == "xbox" and FACE_XBOX_ICONS.has(b):
			return FACE_XBOX_ICONS[b]
		if FACE_POS_ICONS.has(b):
			return FACE_POS_ICONS[b]
		if b == JOY_BUTTON_LEFT_SHOULDER:
			return "pad_lb"
		if b == JOY_BUTTON_RIGHT_SHOULDER:
			return "pad_rb"
	elif ev is InputEventJoypadMotion:
		match (ev as InputEventJoypadMotion).axis:
			JOY_AXIS_TRIGGER_LEFT: return "pad_lt"
			JOY_AXIS_TRIGGER_RIGHT: return "pad_rt"
	return ""


## Texte posé sur l'icône : lettre Xbox ou LB/RT courts ; rien sur les icônes positionnelles.
static func pad_caption(ev: InputEvent, fam := "") -> String:
	var icon := pad_icon(ev, fam)
	if icon.begins_with("pad_btn_"):
		return ""
	var t := pad_label(ev, fam)
	return t if t.length() <= 2 else ""


static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return key_label(ev)
	if ev is InputEventMouseButton:
		return mouse_label((ev as InputEventMouseButton).button_index)
	if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
		return pad_label(ev)
	return "?"


# --- Actions ---------------------------------------------------------------------

static func _is_pad_slot_event(ev: InputEvent) -> bool:
	if ev is InputEventJoypadButton:
		return true
	if ev is InputEventJoypadMotion:
		return TRIGGER_NAMES.has((ev as InputEventJoypadMotion).axis)
	return false


## Première liaison de l'action pour le périphérique (ordre des emplacements), null sinon.
static func first_event(action: StringName, pad: bool, with_mouse := false) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if pad and _is_pad_slot_event(ev):
			return ev
		if not pad and (ev is InputEventKey or (with_mouse and ev is InputEventMouseButton)):
			return ev
	return null


## Libellé de la première touche (clavier) ou du premier bouton / gâchette (manette).
static func action_label(action: StringName, pad: bool) -> String:
	var ev := first_event(action, pad)
	return event_label(ev) if ev != null else "?"


## Toutes les liaisons clavier-souris actives d'une action : « Shift gauche / Espace ».
static func all_labels(action: StringName, pad: bool) -> String:
	var out: PackedStringArray = []
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if (pad and _is_pad_slot_event(ev)) or (not pad and (ev is InputEventKey or ev is InputEventMouseButton)):
				var l := event_label(ev)
				if not (l in out):
					out.append(l)
	return " / ".join(out) if not out.is_empty() else "?"


## [{"kind": "mouse"|"key"|"pad", "button": int, "text": String, "icon": String, "caption": String}].
static func prompt_parts(action: StringName, pad: bool) -> Array:
	var out: Array = []
	if not InputMap.has_action(action):
		return out
	if pad:
		var pe := first_event(action, true)
		if pe != null:
			var b := (pe as InputEventJoypadButton).button_index if pe is InputEventJoypadButton else -1
			out.append({"kind": "pad", "button": b, "text": pad_label(pe), "icon": pad_icon(pe), "caption": pad_caption(pe)})
		return out
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton:
			var mb := (ev as InputEventMouseButton).button_index
			out.append({"kind": "mouse", "button": mb, "text": mouse_label(mb)})
			break
	var ke := first_event(action, false)
	if ke != null:
		out.append({"kind": "key", "button": 0, "text": key_label(ke), "caption": short_key_label(ke)})
	return out


## Forme courte posée DANS le cadre de touche (KeyPrompt) : « Maj » au lieu de « Shift gauche », etc.
const SHORT_KEY_NAMES := {
	KEY_SHIFT: "Maj", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_CAPSLOCK: "Verr", KEY_BACKSPACE: "Retour",
	KEY_KP_ENTER: "Entrée", KEY_PAGEUP: "PgPréc", KEY_PAGEDOWN: "PgSuiv", KEY_ESCAPE: "Échap",
}


static func short_key_label(k: InputEventKey) -> String:
	var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return "P%d" % (code - KEY_KP_0)
	return SHORT_KEY_NAMES.get(code, key_label(k))


## Déplacement au clavier : « ZQSD / flèches » (AZERTY), « WASD / flèches » (QWERTY), selon les liaisons.
static func movement_text() -> String:
	var rows: Array = [[], []] # emplacement 0, emplacement 1
	var codes: Array = [[], []]
	for a in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		var keys: Array = []
		if InputMap.has_action(a):
			for ev in InputMap.action_get_events(a):
				if ev is InputEventKey:
					keys.append(ev)
		for i in 2:
			if i < keys.size():
				rows[i].append(key_label(keys[i]))
				var k := keys[i] as InputEventKey
				codes[i].append(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	var parts: PackedStringArray = []
	for i in 2:
		if rows[i].size() != 4:
			continue
		if codes[i] == ARROWS:
			parts.append("flèches")
			continue
		var all_short := true
		for l in rows[i]:
			all_short = all_short and (l as String).length() == 1
		parts.append(("".join(PackedStringArray(rows[i]))) if all_short else " ".join(PackedStringArray(rows[i])))
	return " / ".join(parts) if not parts.is_empty() else "?"


## Aide « Commandes » d'un mode d'entrée (0 tactile, 1 clavier-souris, 2 manette), construite à partir des
## liaisons courantes (remappage compris) : lignes [action, touches].
static func controls_help(mode: int) -> Array:
	match mode:
		2:
			return [
				["Déplacement", "Stick gauche / croix"],
				["Visée des sorts 2-4", "Stick droit (sinon ennemi le plus proche)"],
				["Sort 1", "Automatique"],
				["Sorts 2 / 3 / 4", "%s / %s / %s" % [action_label(&"spell_2", true), action_label(&"spell_3", true), action_label(&"spell_4", true)]],
				["Roulade (invulnérable)", all_labels(&"dodge", true)],
				["Interagir", all_labels(&"interact", true)],
				["Pause", pad_button_label(JOY_BUTTON_START)],
			]
		0:
			return [
				["Déplacement", "Joystick (moitié basse de l'écran)"],
				["Sort 1", "Automatique"],
				["Sorts 2 / 3 / 4", "Boutons en bas à droite (visée automatique)"],
				["Roulade (invulnérable)", "Bouton Roulade près des sorts (direction du joystick)"],
				["Interagir", "Bouton qui apparaît près d'un coffre ou du téléporteur"],
				["Pause", "Appui long sur le bouton pause"],
			]
	var hint := func(a: StringName) -> String:
		var parts := prompt_parts(a, false)
		var t: PackedStringArray = []
		for p in parts:
			t.append(p["text"])
		return " / ".join(t) if not t.is_empty() else "?"
	return [
		["Déplacement", movement_text()],
		["Visée des sorts 2-4", "Souris (curseur)"],
		["Sort 1", "Automatique"],
		["Sorts 2 / 3 / 4", "%s  ·  %s  ·  %s" % [hint.call(&"spell_2"), hint.call(&"spell_3"), hint.call(&"spell_4")]],
		["Roulade (invulnérable)", "%s (déplacement, sinon curseur)" % all_labels(&"dodge", false)],
		["Interagir", all_labels(&"interact", false)],
		["Pause", "Échap"],
	]
