class_name InteractButton
extends Control
## Bouton « Interagir » contextuel : grand, zone du pouce droit. Visible seulement quand le HUD a choisi une
## cible (le SEUL objet dont l'invite est affichée). Le doigt maintient l'action « interact » tant qu'il
## est posé (pression tenue, relâchée au relevé) : le HUD, unique répartiteur, décide quand appeler
## `interact()` (appui simple ou maintien de `hold_s`, anneau de progression dessiné ici).
## État désactivé (ex. pilier verrouillé) : grisé, raison écrite, l'appui ne fait rien.

signal pressed

const RING_COLOR := Color(1.0, 0.9, 0.45)

var label_text := ""
var enabled := true
var hold_s := 0.0 ## > 0 : maintien requis (anneau affiché)
var hold_progress := 0.0 ## 0..1
var _touch := -1
var _tween: Tween
var _shown := false


## Anneau de maintien réutilisable (invite clavier/manette du HUD) : fond + arc de progression.
class Ring extends Control:
	var progress := 0.0
	var ring_color := InteractButton.RING_COLOR

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_progress(p: float) -> void:
		p = clampf(p, 0.0, 1.0)
		if not is_equal_approx(p, progress):
			progress = p
			queue_redraw()

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5 - 4.0
		var c := size * 0.5
		draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 4.0)
		if progress > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, ring_color, 6.0)


func _ready() -> void:
	size = Vector2(400, 140)
	custom_minimum_size = size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	modulate.a = 0.0


## Appelé par le HUD à chaque frame : target = cible choisie (ou null). `st` = interact_state() de la cible
## ({enabled, label, hold_s}) ; vide : libellé de interact_label() (anciens interactables).
func update_target(target: Node, st: Dictionary = {}, progress: float = 0.0) -> void:
	if target == null:
		if _touch != -1:
			_release()
		if _shown:
			_shown = false
			_animate(false)
		return
	var txt := "Interagir"
	if st.has("label"):
		txt = str(st["label"])
	elif target.has_method("interact_label"):
		txt = str(target.interact_label())
	var en: bool = bool(st.get("enabled", true))
	var hs: float = float(st.get("hold_s", 0.0))
	if txt != label_text or en != enabled or not is_equal_approx(hs, hold_s) or not is_equal_approx(progress, hold_progress):
		label_text = txt
		enabled = en
		hold_s = hs
		hold_progress = progress
		queue_redraw()
	if not enabled and _touch != -1:
		_release()
	if not _shown:
		_shown = true
		_animate(true)


## Echelle de l'UI (1.0 = base 1080 px de large).
func apply_scale(s: float) -> void:
	custom_minimum_size = Vector2(400, 140) * s
	size = custom_minimum_size
	pivot_offset = size * 0.5
	queue_redraw()


## Zone de frappe invisible de HIT_PAD autour du bouton (audit E-06).
const HIT_PAD := 16.0


func _has_point(point: Vector2) -> bool:
	return Rect2(-Vector2(HIT_PAD, HIT_PAD), size + Vector2(HIT_PAD, HIT_PAD) * 2.0).has_point(point)


func is_shown() -> bool:
	return _shown


func _animate(show_it: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if show_it:
		visible = true
		scale = Vector2(0.6, 0.6)
		_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	else:
		_tween.tween_property(self, "modulate:a", 0.0, 0.1)
		_tween.chain().tween_callback(func() -> void: visible = false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch == -1:
			accept_event()
			if not enabled:
				return # grisé : aucun effet
			_touch = t.index
			if InputMap.has_action("interact"):
				Input.action_press("interact") # tenu tant que le doigt est posé (maintien du téléporteur)
			pressed.emit()
		elif not t.pressed and t.index == _touch:
			_release()
			accept_event()


func _release() -> void:
	_touch = -1
	if InputMap.has_action("interact"):
		Input.action_release("interact")


func _exit_tree() -> void:
	if _touch != -1:
		_release()


## Simule une pression brève (press maintenant, release à la frame suivante) : tests et accessibilité.
func trigger() -> void:
	if not InputMap.has_action("interact"):
		return
	Input.action_press("interact")
	pressed.emit()
	await get_tree().process_frame
	Input.action_release("interact")


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	if enabled:
		sb.bg_color = Color(0.15, 0.55, 0.25, 0.9)
		sb.border_color = Color(0.7, 1.0, 0.75)
	else:
		sb.bg_color = Color(0.22, 0.22, 0.24, 0.85)
		sb.border_color = Color(0.5, 0.5, 0.55)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(40)
	draw_style_box(sb, r)
	var k := size.y / 140.0
	var font := ThemeDB.fallback_font
	var txt_col := Color.WHITE if enabled else Color(0.75, 0.75, 0.78)
	var x0 := 16.0 * k
	var w := size.x - 32.0 * k
	if hold_s > 0.0 and enabled:
		# anneau de maintien à gauche (placeholder code, remplacé par l'asset Codex du brief §4.3)
		var rr := size.y * 0.3
		var c := Vector2(size.y * 0.5 + 8.0 * k, size.y * 0.5)
		draw_arc(c, rr, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 5.0 * k)
		if hold_progress > 0.0:
			draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * hold_progress, 40, RING_COLOR, 8.0 * k)
		x0 = size.y + 8.0 * k
		w = size.x - x0 - 16.0 * k
	var fs := int(38 * k)
	if not enabled and label_text.length() > 22:
		fs = int(30 * k) # raison longue (« Verrouillé — petits piliers 1/2 »)
	draw_string(font, Vector2(x0, size.y * 0.5 + 14 * k), label_text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, txt_col)
