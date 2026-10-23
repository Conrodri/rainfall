class_name FloorCard
extends CanvasLayer
## Carton de transition d'étage (docs/ux/Audit_Menus.md §3.3) : fondu au noir, « ÉTAGE N », « Biome »
## (FloorPlan.display_name), astuce (data/tips.json), « +N XP (or converti) », puis fondu vers le jeu.
## Posé par Main à stage_started (n > 1). Au-dessus du HUD et de la pause (couche 140), sous les dialogues.
## Pendant FLOOR_CARD_S : RunState.running = false (la difficulté ne monte pas) et le joueur est invulnérable.
## Aucun tirage dans RunState.rng (la reprise de sauvegarde reste identique) : l'astuce dépend de l'étage.

signal finished

const TIPS_PATH := "res://data/tips.json"
const LAYER := 140

var stage_n := 1
var _bg: ColorRect
var _root: Control
var _title: Label
var _biome: Label
var _tip: Label
var _xp: Label
var _hint: Label
var _t := 0.0
var _hold_s := Balance.FLOOR_CARD_S
var _out_t := -1.0 ## >= 0 : fondu de sortie en cours
var _done := false
var _player: Node = null


## Carton pour l'étage `n` ; `player` reçoit l'invulnérabilité (peut être null).
static func create(n: int, player: Node = null) -> FloorCard:
	var c := FloorCard.new()
	c.stage_n = n
	c._player = player
	return c


## Astuce de l'étage `n` (déterministe, sans RNG de run).
static func tip_for(n: int) -> String:
	var tips: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIPS_PATH)) if FileAccess.file_exists(TIPS_PATH) else null
	if not (tips is Array) or (tips as Array).is_empty():
		return ""
	var a: Array = tips
	return String(a[posmod(n * 5 + RunState.run_seed, a.size())])


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(14 * UiTheme.scale()))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	var full := FloorPlan.display_name(stage_n) # « Étage 3 · Cité de rouille »
	var parts := full.split(" · ", true, 1)
	_title = _label(box, ("ÉTAGE %d" % stage_n), 64, UiTheme.COL_PRIMARY_TEXT)
	_biome = _label(box, parts[1] if parts.size() > 1 else "", 40, UiTheme.COL_TEXT)
	_biome.visible = parts.size() > 1
	_tip = _label(box, tip_for(stage_n), 28, UiTheme.COL_MUTED)
	_tip.custom_minimum_size.x = 1100.0 * UiTheme.scale()
	_xp = _label(box, "", 34, Color(0.55, 0.9, 1.0))
	_xp.visible = false
	_hint = _label(box, "", 22, UiTheme.COL_MUTED)
	_hint.text = "Toucher ou [Entrée] pour continuer"
	_hint.modulate.a = 0.0
	_root.modulate.a = 0.0
	# le carton existe dès le début : le jeu est figé en état « transition »
	RunState.running = false
	if _player != null and is_instance_valid(_player) and _player.has_method(&"grant_invulnerability"):
		_player.grant_invulnerability(Balance.FLOOR_CARD_S + Balance.FLOOR_FADE_IN_S)


func _label(parent: Node, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", int(size * UiTheme.scale()))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", UiTheme.COL_OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


## Ligne « +N XP (or converti) » (ou « Or perdu : N ») : Main la fournit via Events.gold_converted.
func set_conversion(gold: float, xp: float) -> void:
	if _xp == null:
		return
	_xp.text = "+%d XP (or converti)" % int(round(xp)) if xp >= 1.0 else "Or perdu : %d" % int(gold)
	_xp.visible = true


## Texte affiché (tests) : [titre, biome, astuce, xp].
func texts() -> Array:
	return [_title.text, _biome.text, _tip.text, _xp.text]


func is_done() -> bool:
	return _done


## Passe le carton (après FLOOR_CARD_SKIP_AFTER_S).
func skip() -> void:
	if _out_t < 0.0 and _t >= Balance.FLOOR_CARD_SKIP_AFTER_S:
		_hold_s = _t


func _unhandled_input(ev: InputEvent) -> void:
	var press := false
	if ev is InputEventScreenTouch or ev is InputEventMouseButton:
		press = (ev as InputEvent).is_pressed()
	elif ev is InputEventKey or ev is InputEventJoypadButton:
		press = ev.is_pressed() and not ev.is_echo() and (ev.is_action_pressed(&"ui_accept") or ev.is_action_pressed(&"interact"))
	if press:
		skip()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _done:
		return
	if _out_t < 0.0:
		_t += delta
		var fin := minf(_t / maxf(Balance.FLOOR_FADE_OUT_S, 0.001), 1.0)
		_root.modulate.a = fin
		_hint.modulate.a = clampf((_t - Balance.FLOOR_CARD_SKIP_AFTER_S) / 0.3, 0.0, 1.0) * 0.8
		if _t >= _hold_s:
			_out_t = 0.0
			RunState.running = true # le temps actif reprend, le joueur garde sa protection d'arrivée
			if _player != null and is_instance_valid(_player) and _player.has_method(&"grant_invulnerability"):
				_player.grant_invulnerability(Balance.FLOOR_ARRIVAL_INVULN_S)
	else:
		_out_t += delta
		_root.modulate.a = 1.0 - clampf(_out_t / maxf(Balance.FLOOR_FADE_IN_S, 0.001), 0.0, 1.0)
		if _out_t >= Balance.FLOOR_FADE_IN_S:
			_finish()


func _finish() -> void:
	_done = true
	finished.emit()
	queue_free()

