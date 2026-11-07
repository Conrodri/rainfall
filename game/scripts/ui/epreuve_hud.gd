class_name EpreuveHud
extends Control
## HUD des épreuves (docs/Design_Epreuves.md §7.6) : barre de progression de l'épreuve en cours (Epreuve.progress()), libellé
## de note « Parfait / Bien / Fait » pendant GRADE_SHOW_S après la fin, et flèche au bord de l'écran vers l'épreuve quand elle
## est hors champ. Aucune position codée en dur : tout dérive du viewport, de l'échelle du HUD (HudMetrics) et des marges
## sûres (Platform.safe_margins) ; PC, mobile et manette partagent le même rendu (aucune entrée).
## Formes et textes en code = PLACEHOLDER (la barre pourra être remplacée par un cadre Codex sans toucher à la logique).
## Instancié par Hud (`epreuve_hud`), au-dessus de la minimap ; ne capte aucune entrée.

const GRADE_SHOW_S := 2.0
const UPDATE_HZ := 10.0
const BAR_W := 420.0 ## à 1080 px de haut
const BAR_H := 14.0
const ARROW_PX := 44.0
const MARGIN_PX := 16.0
const COL_BAR_BG := Color(0.0, 0.0, 0.0, 0.62)
const COL_BAR := Color(0.95, 0.78, 0.35)
const VERB_COLORS := {
	&"escorte": Color(0.45, 0.8, 0.95), &"rituel": Color(0.85, 0.55, 1.0), &"poursuite": Color(1.0, 0.75, 0.3),
	&"veine": Color(0.76, 0.48, 1.0), &"tenue": Color(0.95, 0.6, 0.35),
}

var hud: Node = null ## Hud (boss_bars pour se placer sous la barre de boss) ; null en test
var scale_override := -1.0 ## tests / captures
var epreuve: Epreuve = null ## épreuve affichée (en cours)
var progress_value := 0.0 ## 0..1 (lecture des tests)
var bar_rect := Rect2() ## rectangle écran de la barre (tests)
var arrow_pos := Vector2(-1.0, -1.0) ## position écran de la flèche, (-1, -1) si l'épreuve est à l'écran
var arrow_angle := 0.0
var grade_text := "" ## libellé de note affiché, "" sinon
var _grade: StringName = &""
var _grade_t := 0.0
var _grade_verb: StringName = &""
var _acc := 0.0


func _ready() -> void:
	name = "EpreuveHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Events.epreuve_finished.connect(_on_finished)


func bind(h: Node) -> void:
	hud = h


func _on_finished(kind: StringName, g: StringName, _elapsed: float, _gold: float) -> void:
	if not Epreuve.GRADE_NAMES.has(g):
		return
	_grade = g
	_grade_verb = kind
	_grade_t = GRADE_SHOW_S
	grade_text = String(Epreuve.GRADE_NAMES[g])
	refresh()


func _process(delta: float) -> void:
	_grade_t = maxf(_grade_t - delta, 0.0)
	if _grade_t <= 0.0 and grade_text != "":
		grade_text = ""
		queue_redraw()
	_acc += delta
	if _acc < 1.0 / UPDATE_HZ:
		return
	_acc = 0.0
	refresh()


## Épreuve en cours (la plus avancée si deux tournent), null sinon.
func current_epreuve() -> Epreuve:
	var best: Epreuve = null
	if not is_inside_tree():
		return null
	for n in get_tree().get_nodes_in_group(&"epreuves"):
		var e := n as Epreuve
		if e != null and e.is_inside_tree() and e.is_running() and (best == null or e.progress() > best.progress()):
			best = e
	return best


func _scale() -> float:
	if scale_override > 0.0:
		return scale_override
	var vp := get_viewport_rect().size
	var s := HudMetrics.geometry_scale(vp) if vp.y > 0.0 else 1.0
	return s * (HudMetrics.MOBILE_K * 0.8 if HudMetrics.is_mobile() else 1.0)


func _font_scale() -> float:
	return scale_override if scale_override > 0.0 else HudMetrics.geometry_scale(get_viewport_rect().size)


## Recalcule l'état affiché (appelable directement par les tests).
func refresh() -> void:
	epreuve = current_epreuve()
	progress_value = clampf(epreuve.progress(), 0.0, 1.0) if epreuve != null else 0.0
	var screen := Rect2(Vector2.ZERO, size if size.x > 1.0 else get_viewport_rect().size)
	var s := _scale()
	var safe: Dictionary = Platform.safe_margins()
	var top := float(safe.get("top", 0.0)) + 96.0 * s
	if hud != null and is_instance_valid(hud) and hud.get(&"boss_bars") != null:
		var bb := hud.get(&"boss_bars") as Control
		if bb != null and bb.visible:
			top = maxf(top, bb.get_global_rect().end.y + 12.0 * s)
	var w := minf(BAR_W * s, screen.size.x * 0.5)
	bar_rect = Rect2(screen.size.x * 0.5 - w * 0.5, top, w, BAR_H * s)
	arrow_pos = Vector2(-1.0, -1.0)
	if epreuve != null:
		var sp := epreuve.get_global_transform_with_canvas().origin
		if not screen.has_point(sp):
			var px := ARROW_PX * s
			var inner := screen.grow(-(px * 0.5 + MARGIN_PX * s))
			inner.position.x += float(safe.get("left", 0.0))
			inner.size.x -= float(safe.get("left", 0.0)) + float(safe.get("right", 0.0))
			inner.position.y += float(safe.get("top", 0.0))
			inner.size.y -= float(safe.get("top", 0.0)) + float(safe.get("bottom", 0.0))
			var c := screen.get_center()
			var dir := sp - c
			var k := INF # facteur pour atteindre le bord du rectangle intérieur le long de `dir`
			var half := inner.size * 0.5
			if absf(dir.x) > 0.001:
				k = minf(k, half.x / absf(dir.x))
			if absf(dir.y) > 0.001:
				k = minf(k, half.y / absf(dir.y))
			arrow_pos = inner.get_center() + dir * k
			arrow_angle = dir.angle()
	queue_redraw()


func _draw() -> void:
	var s := _scale()
	var font := ThemeDB.fallback_font
	if epreuve != null:
		var col: Color = VERB_COLORS.get(epreuve.verb, COL_BAR)
		var fs := HudMetrics.font(HudMetrics.T3_GAUGE, _font_scale())
		draw_rect(bar_rect.grow(3.0 * s), COL_BAR_BG)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * progress_value, bar_rect.size.y)), col)
		draw_rect(bar_rect.grow(3.0 * s), Color(1, 1, 1, 0.35), false, 1.0)
		var title := "%s  %d %%" % [EpreuveData.verb_name(String(epreuve.verb)), roundi(progress_value * 100.0)]
		var tp := Vector2(bar_rect.position.x, bar_rect.position.y - 8.0 * s)
		draw_string_outline(font, tp, title, HORIZONTAL_ALIGNMENT_CENTER, bar_rect.size.x, fs, HudMetrics.OUTLINE_T3, Color(0, 0, 0, 0.9))
		draw_string(font, tp, title, HORIZONTAL_ALIGNMENT_CENTER, bar_rect.size.x, fs, Color(1, 1, 1))
	if grade_text != "" and _grade_t > 0.0:
		var gc: Color = Epreuve.GRADE_COLORS.get(_grade, Color.WHITE)
		gc.a = clampf(_grade_t / 0.5, 0.0, 1.0)
		var gfs := HudMetrics.font(HudMetrics.T2_TIME, _font_scale())
		var gp := Vector2(bar_rect.position.x, bar_rect.position.y + bar_rect.size.y + 12.0 * s + float(gfs))
		var ol := Color(0, 0, 0, gc.a * 0.9)
		draw_string_outline(font, gp, grade_text, HORIZONTAL_ALIGNMENT_CENTER, bar_rect.size.x, gfs, HudMetrics.OUTLINE_T1, ol)
		draw_string(font, gp, grade_text, HORIZONTAL_ALIGNMENT_CENTER, bar_rect.size.x, gfs, gc)
	if arrow_pos.x >= 0.0 and epreuve != null:
		var px2 := ARROW_PX * s
		var ac: Color = VERB_COLORS.get(epreuve.verb, COL_BAR)
		var d := Vector2.from_angle(arrow_angle)
		var o := d.orthogonal()
		var tri := PackedVector2Array([arrow_pos + d * px2 * 0.5, arrow_pos - d * px2 * 0.4 + o * px2 * 0.4, arrow_pos - d * px2 * 0.4 - o * px2 * 0.4])
		draw_colored_polygon(tri, ac)
		tri.append(tri[0])
		draw_polyline(tri, Color(0, 0, 0, 0.9), 2.0)
