class_name ResourceGauge
extends Control
## Jauge générique de la ressource du personnage (contrat KitResource : kit.resource_state()), posée près des
## sorts par le HUD (PC : à gauche de la barre de sorts ; tactile : au-dessus de la grappe de sorts).
## Plaque de la DA (panel_small_9slice) ; nom + valeur ; jauge continue encadrée (bar_frame_xp) ou pastilles,
## à l'accent du personnage. Sans ressource (Ardent, Rictus) : invisible.
## Habillage Blender (lot Codex U1, assets/sprites/ui/resource_gauge/) : cadre 9-patch en fer (marges 12 / 8 px) sur son
## fond creux, remplissage gris teinté à l'accent (multiplication par modulate) + masque `_e` en surimpression,
## encoche du repère `mark`, pastilles vide / pleine (+ `_e`). Repli en formes de code si un fichier manque.

const BASE_SIZE := Vector2(250, 76) ## à ui_scale 1 (PC)
const MOBILE_SIZE := Vector2(330, 96) ## audit HUD § 4.2 : jauge de kit mobile
const DIM := 0.38 ## ressource bloquée : jauge éteinte
const BG := Color("#0B0907", 0.9) ## fond de jauge très sombre (audit H12)
const MIN_CONTRAST := 3.0 ## WCAG 1.4.11 : remplissage / fond
const MIN_FONT_PC := 18
const MIN_FONT_MOBILE := 26
const PULSE_HZ := 1.0 ## état plein : cadre qui pulse (alpha 0,35 -> 0,7)
const EDGE_LIGHT := Color("#E8E2D6")
const ART_DIR := "res://assets/sprites/ui/resource_gauge/"
const FRAME_M := Vector2(12, 8) ## marges 9-patch du cadre U1 (px source)
const FRAME_H := 48.0 ## hauteur source du cadre
const TEXT_GAP := 14.0 ## écart mini (à ui_scale 1) entre nom, taux et valeur sur la ligne de texte
const TRACK_GAP := 6.0 ## écart sous la ligne de texte avant la jauge
const MIN_TRACK := 16.0 ## hauteur mini de la jauge (cadre compris)
const E_ALPHA := 0.35 ## masque d'émission : surimpression (HUD non éclairé), plus forte en état exalté

static var _art := {}


## Texture du lot U1 (`<ART_DIR><name>.png`) ou null (repli en code). Partagée avec OverheadBars.
static func art(name: String) -> Texture2D:
	if not _art.has(name):
		var path := ART_DIR + name + ".png"
		_art[name] = load(path) if ResourceLoader.exists(path) else null
	return _art[name] as Texture2D

var state: Dictionary = {}
var ui_scale := 1.0
var _plate: StyleBox = null
var _frame: StyleBox = null
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_plate = UiTheme.da_box("panel_small_9slice", 0.5)
	_frame = UiTheme.da_box("bar_frame_xp")


## Luminance relative WCAG d'une couleur sRGB.
static func luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## Rapport de contraste WCAG entre deux couleurs (alpha ignoré).
static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Éclaircit `col` vers le blanc cassé jusqu'à atteindre `ratio`:1 sur `bg`.
static func lift(col: Color, bg: Color = BG, ratio: float = MIN_CONTRAST) -> Color:
	var c := Color(col.r, col.g, col.b, 1.0)
	var i := 0
	while contrast(c, bg) < ratio and i < 12:
		c = c.lerp(EDGE_LIGHT, 0.12)
		i += 1
	return Color(c.r, c.g, c.b, col.a)


## Taille de police minimale (px écran) : 18 PC / 26 mobile (contrat UX 23:30).
static func min_font() -> int:
	return MIN_FONT_MOBILE if Platform.is_mobile() else MIN_FONT_PC


## Jauge pleine (pastilles toutes remplies, ou ratio >= 1) : cadre pulsé en plus du texte (deux canaux, H12).
static func is_full(st: Dictionary) -> bool:
	if st.is_empty() or bool(st.get("blocked", false)):
		return false
	var pips := int(st.get("pips", 0))
	if pips > 0:
		return int(st.get("filled", 0)) >= pips
	return float(st.get("ratio", 0.0)) >= 0.999


## Alpha du cadre d'état plein à l'instant `t` (s) : 0,35 -> 0,7 à 1 Hz.
static func pulse_alpha(t: float) -> float:
	if GameSettings.reduce_motion():
		return 0.525 # « Réduire les mouvements » : cadre fixe, sans pulsation
	return 0.525 + 0.175 * sin(t * TAU * PULSE_HZ)


func apply_scale(s: float) -> void:
	ui_scale = s
	_fit_size()
	queue_redraw()


## Polices de la ligne de texte (px) : nom + valeur, puis taux de régénération.
func _font_px() -> int:
	return maxi(int(19 * ui_scale), min_font())


func _regen_font_px() -> int:
	return maxi(int(15 * ui_scale), min_font())


## Taille nécessaire (px écran) : la base de la plateforme, agrandie si la ligne « NOM +x/s   valeur » ou sa hauteur de
## ligne ne tiennent pas (planchers 18 / 26 px) : le texte ne déborde jamais du cadre et reste séparé.
func required_size() -> Vector2:
	var k := ui_scale
	var base := (MOBILE_SIZE if Platform.is_mobile() else BASE_SIZE) * k
	var font := ThemeDB.fallback_font
	var fs := _font_px()
	var pad := _pad()
	var label := String(state.get("label", "")).to_upper()
	var text := String(state.get("text", ""))
	var w := pad.x * 2.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if state.has("regen"):
		w += TEXT_GAP * k + font.get_string_size(Hud.fmt_rate(float(state["regen"])), HORIZONTAL_ALIGNMENT_LEFT, -1, _regen_font_px()).x
	var vw := maxf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, font.get_string_size("888", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	w += TEXT_GAP * k + vw
	var h := pad.y + font.get_height(fs) + TRACK_GAP * k + MIN_TRACK * k + pad.y
	return Vector2(maxf(base.x, ceilf(w)), maxf(base.y, ceilf(h)))


## Marges du texte dans la plaque : 16 px de côté, verticalement trait du cadre + marge d'encre (UiTheme.v_margin).
func _pad() -> Vector2:
	return Vector2(16.0 * ui_scale, UiTheme.v_margin(_plate, _font_px()) if _plate != null else 10.0 * ui_scale)


## Bord intérieur visible de la plaque (pour la règle de marge verticale du test de débordement).
func _inner_frame() -> Rect2:
	var e := UiTheme.frame_edge(_plate)
	var gr := get_global_rect()
	return Rect2(gr.position + Vector2(0.0, e), gr.size - Vector2(0.0, 2.0 * e))


func _fit_size() -> void:
	custom_minimum_size = required_size()
	size = custom_minimum_size


## Textes dessinés (rects globaux) pour text_overflow_test : {text, size, rect, within}.
func text_rects() -> Array:
	var out: Array = []
	if state.is_empty():
		return out
	var k := ui_scale
	var g := get_global_rect().position
	var font := ThemeDB.fallback_font
	var fs := _font_px()
	var pad := _pad()
	var h := font.get_height(fs)
	var label := String(state.get("label", "")).to_upper()
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var own := get_global_rect()
	out.append({"text": label, "size": fs, "rect": Rect2(g + Vector2(pad.x, pad.y), Vector2(lw, h)), "within": own, "frame": _inner_frame()})
	if state.has("regen"):
		var rt := Hud.fmt_rate(float(state["regen"]))
		var rfs := _regen_font_px()
		var rw := font.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x
		out.append({"text": rt, "size": rfs, "rect": Rect2(g + Vector2(pad.x + lw + TEXT_GAP * k, pad.y), Vector2(rw, font.get_height(rfs))), "within": own, "frame": _inner_frame()})
	var text := String(state.get("text", ""))
	if text != "":
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		out.append({"text": text, "size": fs, "rect": Rect2(g + Vector2(size.x - pad.x - tw, pad.y), Vector2(tw, h)), "within": own, "frame": _inner_frame()})
	return out


## Nouvelle ressource ({} = aucune : masquée). Ne redessine que si elle a changé.
func set_state(d: Dictionary) -> void:
	visible = not d.is_empty()
	if d != state:
		state = d
		_fit_size()
		queue_redraw()


func _process(delta: float) -> void:
	if visible and (bool(state.get("boost", false)) or bool(state.get("warn", false)) or is_full(state)):
		_t += delta
		queue_redraw()


func _draw() -> void:
	if state.is_empty():
		return
	var k := ui_scale
	var rect := Rect2(Vector2.ZERO, size)
	if _plate != null:
		draw_style_box(_plate, rect)
	else:
		draw_rect(rect, Color(0.06, 0.06, 0.09, 0.8))
	var acc: Color = state.get("color", Color(1.0, 0.55, 0.2))
	var blocked := bool(state.get("blocked", false))
	var boost := bool(state.get("boost", false))
	var glow := 1.0 + (0.35 + 0.25 * sin(_t * 9.0) if boost else 0.0)
	var col := Color(acc.r * glow, acc.g * glow, acc.b * glow, 1.0)
	if blocked:
		col = Color(acc.r * DIM, acc.g * DIM, acc.b * DIM, 1.0)
	else:
		col = lift(col) # remplissage >= 3:1 sur le fond (H12)
	var pad := _pad()
	var font := ThemeDB.fallback_font
	var fs := _font_px()
	var label := String(state.get("label", "")).to_upper()
	var text := String(state.get("text", ""))
	var y_txt := pad.y + font.get_ascent(fs)
	draw_string_outline(font, Vector2(pad.x, y_txt), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(5 * k), Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(pad.x, y_txt), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.86, 0.84, 0.8))
	if state.has("regen"): # taux du hook kit.resource_regen_per_s() (KitResource.of) : « +X/s » après le nom
		var rfs := _regen_font_px()
		var rx := pad.x + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + TEXT_GAP * k
		var rt := Hud.fmt_rate(float(state["regen"]))
		draw_string_outline(font, Vector2(rx, y_txt), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, int(4 * k), Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(rx, y_txt), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, col.lerp(Color(0.86, 0.84, 0.8), 0.5))
	if text != "":
		var w := size.x - pad.x * 2.0
		draw_string_outline(font, Vector2(pad.x, y_txt), text, HORIZONTAL_ALIGNMENT_RIGHT, w, fs, int(5 * k), Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(pad.x, y_txt), text, HORIZONTAL_ALIGNMENT_RIGHT, w, fs, col.lerp(Color.WHITE, 0.35))
	var track_top := pad.y + font.get_height(fs) + TRACK_GAP * k
	var track := Rect2(Vector2(pad.x, track_top), Vector2(size.x - pad.x * 2.0, size.y - track_top - pad.y))
	var pips := int(state.get("pips", 0))
	if pips > 0:
		_draw_pips(track, pips, int(state.get("filled", 0)), float(state.get("ratio", 0.0)), col, k)
	else:
		_draw_bar(track, float(state.get("ratio", 0.0)), float(state.get("mark", -1.0)), col, k)
	if is_full(state): # état plein : cadre qui pulse (canal visuel en plus du texte « PRÊTE » / « +70 % »)
		draw_rect(rect.grow(-2.0 * k), Color(EDGE_LIGHT, pulse_alpha(_t)), false, maxf(2.0 * k, 1.0))
	if bool(state.get("warn", false)): # sort refusé faute de ressource : liseré rouge qui clignote
		var a := 0.8 if GameSettings.reduce_motion() or GameSettings.flash_scale() < 1.0 else 0.55 + 0.45 * sin(_t * 30.0) # 30 Hz : fixe si flashs réduits
		draw_rect(rect.grow(-2.0 * k), Color(1.0, 0.25, 0.2, a), false, maxf(3.0 * k, 1.0))


func _draw_bar(r: Rect2, ratio: float, mark: float, col: Color, k: float) -> void:
	if art("frame") != null and art("frame_bg") != null and art("fill") != null:
		_draw_bar_art(r.grow_individual(4.0 * k, 3.0 * k, 4.0 * k, 3.0 * k), ratio, mark, col, k)
		return
	var inner := r.grow_individual(-4.0 * k, -3.0 * k, -4.0 * k, -3.0 * k)
	draw_rect(inner, BG)
	if ratio > 0.0:
		var fill := Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y))
		draw_rect(fill, col)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, maxf(2.0 * k, 1.0))), col.lerp(Color.WHITE, 0.45)) # liseré haut
	_draw_ticks(inner, k)
	for m: Variant in state.get("marks", []): # repères secondaires, plus discrets
		var xm := inner.position.x + inner.size.x * clampf(float(m), 0.0, 1.0)
		draw_line(Vector2(xm, inner.position.y), Vector2(xm, inner.end.y), Color(1, 1, 1, 0.35), maxf(1.5 * k, 1.0))
	if mark > 0.0 and mark < 1.0:
		var x := inner.position.x + inner.size.x * mark
		draw_line(Vector2(x, inner.position.y - 2.0 * k), Vector2(x, inner.end.y + 2.0 * k), Color(1, 1, 1, 0.75), maxf(2.0 * k, 1.0))
	if _frame != null:
		draw_style_box(_frame, r.grow_individual(4.0 * k, 3.0 * k, 4.0 * k, 3.0 * k))


## Jauge continue habillée (U1) : fond creux, remplissage teinté rogné au ratio, `_e`, repères, encoche, cadre.
func _draw_bar_art(fr: Rect2, ratio: float, mark: float, col: Color, k: float) -> void:
	var kf := fr.size.y / FRAME_H
	HpBarStyle.nine_patch(self, art("frame_bg"), fr, FRAME_M, kf)
	var inner := fr.grow_individual(-FRAME_M.x * kf, -FRAME_M.y * kf, -FRAME_M.x * kf, -FRAME_M.y * kf)
	var rt := clampf(ratio, 0.0, 1.0)
	if rt > 0.0:
		var fl := art("fill")
		var dst := Rect2(inner.position, Vector2(inner.size.x * rt, inner.size.y))
		var src := Rect2(Vector2.ZERO, Vector2(fl.get_width() * rt, fl.get_height()))
		draw_texture_rect_region(fl, dst, src, col)
		var fe := art("fill_e")
		if fe != null:
			var ea := E_ALPHA * (1.8 if bool(state.get("boost", false)) else 1.0)
			draw_texture_rect_region(fe, dst, Rect2(src.position, Vector2(fe.get_width() * rt, fe.get_height())), Color(col.lerp(Color.WHITE, 0.3), ea))
	_draw_ticks(inner, k)
	for m: Variant in state.get("marks", []): # repères secondaires, plus discrets
		var xm := inner.position.x + inner.size.x * clampf(float(m), 0.0, 1.0)
		draw_line(Vector2(xm, inner.position.y), Vector2(xm, inner.end.y), Color(1, 1, 1, 0.3), maxf(1.5 * k, 1.0))
	if mark > 0.0 and mark < 1.0:
		var x := inner.position.x + inner.size.x * mark
		var nt := art("notch")
		if nt != null:
			var nw := inner.size.y * 0.5
			draw_texture_rect(nt, Rect2(Vector2(x - nw * 0.5, inner.position.y), Vector2(nw, inner.size.y)), false)
		else:
			draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(1, 1, 1, 0.75), maxf(2.0 * k, 1.0))
	HpBarStyle.nine_patch(self, art("frame"), fr, FRAME_M, kf)


## Encoches sombres tous les 10 % (la jauge continue se lit « graduée »).
func _draw_ticks(inner: Rect2, k: float) -> void:
	for i in range(1, 10):
		var x := inner.position.x + inner.size.x * i * 0.1
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color("#0B0907", 0.8), maxf(1.0, k))


## Pastilles pleines ; la suivante se remplit de `ratio` (recharge en cours : Bourbe).
func _draw_pips(r: Rect2, n: int, filled: int, ratio: float, col: Color, k: float) -> void:
	var pe := art("pip_empty")
	var pf := art("pip_full")
	if pe != null and pf != null: # pastilles habillées (U1)
		var side := minf(r.size.y * 1.05, r.size.x / (n * 1.18))
		var step := (r.size.x - side) / maxf(n - 1, 1)
		var pfe := art("pip_full_e")
		for i in n:
			var pr := Rect2(Vector2(r.position.x + step * i, r.position.y + (r.size.y - side) * 0.5), Vector2(side, side))
			var pc := pr.get_center()
			if i < filled:
				draw_texture_rect(pf, pr, false, _pip_full_col(col))
				if pfe != null:
					draw_texture_rect(pfe, pr, false, Color(col.lerp(Color.WHITE, 0.3), E_ALPHA))
				draw_arc(pc, side * 0.5, 0.0, TAU, 24, Color(EDGE_LIGHT, 0.9), maxf(2.0 * k, 1.0)) # liseré clair (H11)
			else:
				draw_texture_rect(pe, pr, false)
				_dashed_ring(pc, side * 0.5, Color(EDGE_LIGHT, 0.7), maxf(2.0 * k, 1.0)) # vide : contour pointillé
				if i == filled and ratio > 0.0 and ratio < 1.0: # recharge : la pastille se remplit par le bas
					var h := side * ratio
					draw_texture_rect_region(pf, Rect2(Vector2(pr.position.x, pr.end.y - h), Vector2(side, h)),
						Rect2(Vector2(0.0, pf.get_height() * (1.0 - ratio)), Vector2(pf.get_width(), pf.get_height() * ratio)), Color(col, 0.6))
		return
	var rad := minf(r.size.y * 0.42, r.size.x / (n * 2.6))
	var gap := (r.size.x - rad * 2.0) / maxf(n - 1, 1)
	var cy := r.position.y + r.size.y * 0.5
	for i in n:
		var p := Vector2(r.position.x + rad + gap * i, cy)
		draw_circle(p, rad + 2.0 * k, Color(0, 0, 0, 0.9))
		draw_circle(p, rad, BG)
		if i < filled:
			draw_circle(p, rad * 0.86, _pip_full_col(col))
			draw_circle(p - Vector2(rad, rad) * 0.25, rad * 0.22, col.lerp(Color.WHITE, 0.5))
			draw_arc(p, rad, 0.0, TAU, 24, Color(EDGE_LIGHT, 0.9), maxf(2.0 * k, 1.0)) # liseré clair
		else:
			if i == filled and ratio > 0.0 and ratio < 1.0:
				draw_arc(p, rad * 0.6, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, col, rad * 0.36)
			_dashed_ring(p, rad, Color(EDGE_LIGHT, 0.7), maxf(2.0 * k, 1.0)) # vide : contour pointillé


## Pastille pleine : accent x1,3 (borné), relevée à >= 3:1 sur le fond (états plein / vide distincts, H11).
func _pip_full_col(col: Color) -> Color:
	return lift(Color(minf(col.r * 1.3, 1.0), minf(col.g * 1.3, 1.0), minf(col.b * 1.3, 1.0), 1.0))


## Cercle pointillé (8 tirets) : « vide » lisible sans la couleur.
func _dashed_ring(c: Vector2, rad: float, col: Color, w: float) -> void:
	for j in 8:
		var a0 := TAU * j / 8.0
		draw_arc(c, rad, a0, a0 + TAU / 16.0, 6, col, w)
