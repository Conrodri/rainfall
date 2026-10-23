class_name Haptics
extends RefCounted
## Haptique (audit A-11, lot L7) : module STATIQUE, sans autoload. Une seule porte d'entrée : Haptics.pulse(kind).
## - Téléphone (mode tactile sur Android/iOS) : Input.vibrate_handheld(ms, amplitude).
## - Manette (mode manette) : Input.start_joy_vibration(device, faible, fort, s).
## - Clavier-souris : RIEN, même si une manette est branchée (elle n'est pas utilisée).
## - Réglage « Vibrations » : GameSettings.haptics() (lecture seule) ; curseur facultatif [gameplay] haptics_strength (0-1, défaut 1).
## - Plafond : au plus 1 impulsion toutes les MIN_GAP_MS (la mort passe toujours) et MAX_PER_S par seconde glissante.
## Branchements : Player.take_damage/_damage_hp/_on_level_up, BossPace.impact, coffre légendaire via Events.chest_opened
## (connect_events(), appelé une fois par Player._ready). Tests : sinks et horloge injectables (reset()).

enum Kind { HURT, HURT_BIG, BOSS_IMPACT, LEGENDARY, LEVEL_UP, DEATH }

const MIN_GAP_MS := 80
const MAX_PER_S := 6
const BIG_HIT_FRACTION := 0.15 ## dégât >= 15 % des PV max : gros dégât
const DOUBLE_GAP_S := 0.07
## Mobile : [ms, amplitude] ; manette : [faible, fort, s] ; double : deux impulsions (niveau, coffre légendaire).
const TABLE := {
	Kind.HURT: {"ms": 30, "amp": 0.5, "weak": 0.3, "strong": 0.2, "s": 0.12},
	Kind.HURT_BIG: {"ms": 60, "amp": 0.9, "weak": 0.5, "strong": 0.7, "s": 0.2},
	Kind.BOSS_IMPACT: {"ms": 40, "amp": 0.6, "weak": 0.1, "strong": 0.5, "s": 0.14},
	Kind.LEGENDARY: {"ms": 40, "amp": 0.7, "weak": 0.4, "strong": 0.4, "s": 0.25, "double": true},
	Kind.LEVEL_UP: {"ms": 40, "amp": 0.7, "weak": 0.4, "strong": 0.4, "s": 0.25, "double": true},
	Kind.DEATH: {"ms": 120, "amp": 1.0, "weak": 0.6, "strong": 0.9, "s": 0.35},
}

# --- Injection (tests) ---
static var mode_override := -1 ## -1 = Platform.input_mode ; sinon Platform.InputMode
static var mobile_override := -1 ## -1 = Platform.is_mobile() ; 0 / 1
static var now_ms_override := -1
static var handheld_sink := Callable() ## (ms: int, amp: float)
static var joy_sink := Callable() ## (device: int, weak: float, strong: float, s: float)

static var _last_ms := -1000000
static var _recent: Array[int] = []
static var _connected := false


static func reset() -> void:
	mode_override = -1
	mobile_override = -1
	now_ms_override = -1
	handheld_sink = Callable()
	joy_sink = Callable()
	_last_ms = -1000000
	_recent.clear()


## Écoute les signaux d'Events (coffre légendaire). Idempotent.
static func connect_events() -> void:
	if _connected:
		return
	var ev := _autoload(&"Events")
	if ev == null:
		return
	ev.chest_opened.connect(_on_chest_opened)
	_connected = true


static func _on_chest_opened(_chest: Node, quality: StringName, _offered: Array) -> void:
	if quality == &"legendaire":
		pulse(Kind.LEGENDARY)


## Dégât subi (après mitigation) : gros dégât si >= BIG_HIT_FRACTION des PV max.
static func hurt(amount: float, max_hp: float) -> void:
	pulse(Kind.HURT_BIG if max_hp > 0.0 and amount >= max_hp * BIG_HIT_FRACTION else Kind.HURT)


## Retourne vrai si une vibration a été émise.
static func pulse(kind: int) -> bool:
	if not TABLE.has(kind) or not GameSettings.haptics():
		return false
	var mode := _mode()
	var pad := mode == 2 # Platform.InputMode.GAMEPAD
	var phone := mode == 0 and _is_mobile() # TOUCH
	if not pad and not phone:
		return false # clavier-souris : jamais
	var now := _now()
	if kind != Kind.DEATH and now - _last_ms < MIN_GAP_MS:
		return false
	while not _recent.is_empty() and now - _recent[0] >= 1000:
		_recent.pop_front()
	if kind != Kind.DEATH and _recent.size() >= MAX_PER_S:
		return false
	_last_ms = now
	_recent.append(now)
	var k := clampf(float(GameSettings.get_value("gameplay", "haptics_strength", 1.0)), 0.0, 1.0)
	if k <= 0.0:
		return false
	var d: Dictionary = TABLE[kind]
	_fire(d, k, pad)
	if d.get("double", false):
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and now_ms_override < 0:
			tree.create_timer(DOUBLE_GAP_S).timeout.connect(_fire.bind(d, k, pad))
		else:
			_fire(d, k, pad) # tests : pas d'attente
	return true


static func _fire(d: Dictionary, k: float, pad: bool) -> void:
	if pad:
		var w := clampf(float(d["weak"]) * k, 0.0, 1.0)
		var s := clampf(float(d["strong"]) * k, 0.0, 1.0)
		var dev := 0
		var pads := Input.get_connected_joypads()
		if not pads.is_empty():
			dev = pads[0]
		if joy_sink.is_valid():
			joy_sink.call(dev, w, s, float(d["s"]))
		elif not pads.is_empty():
			Input.start_joy_vibration(dev, w, s, float(d["s"]))
	else:
		var a := clampf(float(d["amp"]) * k, 0.0, 1.0)
		if handheld_sink.is_valid():
			handheld_sink.call(int(d["ms"]), a)
		else:
			Input.vibrate_handheld(int(d["ms"]), a)


static func _now() -> int:
	return now_ms_override if now_ms_override >= 0 else Time.get_ticks_msec()


static func _is_mobile() -> bool:
	if mobile_override >= 0:
		return mobile_override == 1
	var p := _autoload(&"Platform")
	return p != null and p.is_mobile()


static func _mode() -> int:
	if mode_override >= 0:
		return mode_override
	var p := _autoload(&"Platform")
	return 1 if p == null else int(p.input_mode)


static func _autoload(n: StringName) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(NodePath(n)) if tree != null else null
