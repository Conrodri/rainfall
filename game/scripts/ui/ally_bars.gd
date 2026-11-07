class_name AllyBars
extends Control
## Barres de PV des ALLIÉS au-dessus de leur tête (coop 1-4, docs/multi/Design_Coop.md §4.1) : petite barre, contour et
## numéro à la teinte d'équipe (Palette.team_color / team_glyph : la couleur ne porte jamais seule le sens). Une seule
## passe de _draw, en coordonnées écran (transform de canevas de la caméra), comme OverheadBars. Le joueur local n'y est
## pas (il a OverheadBars). Un allié spectateur n'a pas de barre (la flèche hors écran et la minimap le signalent).
## Solo : aucun allié, le contrôle ne dessine rien et ne traite rien.

const BAR_W := 76.0 ## px écran à ui_scale 1
const BAR_H := 7.0
const GLYPH_PX := 15
const MARGIN := 10.0 ## entre le haut visible du sprite et la barre
const MOBILE_K := 1.25
const COL_BLOCK := Color(0.035, 0.03, 0.028, 0.72)
const UPDATE_HZ := 30.0

var ui_scale := 1.0
var enabled := true
var bars: Array[Dictionary] = [] ## [{slot, rect, frac}] posées au dernier dessin (tests)

var _font: Font = ThemeDB.fallback_font
var _heads := {} ## instance_id du nœud -> {key: SpriteFrames, off: Vector2}
var _acc := 0.0


func _init() -> void:
	name = "AllyBars"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not enabled or Players.count() <= 1:
		if not bars.is_empty():
			bars.clear()
			queue_redraw()
		return
	_acc += delta
	if _acc < 1.0 / UPDATE_HZ:
		return
	_acc = 0.0
	queue_redraw()


func _head_of(p: Node2D) -> Vector2:
	var id := p.get_instance_id()
	var spr := p.get_node_or_null(^"Visual") as AnimatedSprite2D
	var key: Object = spr.sprite_frames if spr != null else p
	var h: Dictionary = _heads.get(id, {})
	if h.is_empty() or h["key"] != key:
		h = {"key": key, "off": OverheadBars.head_offset(p)}
		_heads[id] = h
	return h["off"]


func _draw() -> void:
	bars.clear()
	if not enabled or Players.count() <= 1:
		return
	var s := ui_scale * (MOBILE_K if Platform.is_mobile() else 1.0)
	var xf := get_viewport().get_canvas_transform()
	var local_id := Players.local_id()
	var screen := Rect2(Vector2.ZERO, get_viewport_rect().size).grow(40.0 * s)
	for e in Players.entries():
		if e.id == local_id or not is_instance_valid(e.node) or not e.node.is_inside_tree():
			continue
		if e.state.spectating or e.node.get(&"dead") == true:
			continue
		var top: Vector2 = xf * (e.node.global_position + _head_of(e.node))
		if not screen.has_point(top):
			continue
		var w := BAR_W * s
		var h := BAR_H * s
		var r := Rect2(Vector2(top.x - w * 0.5, top.y - MARGIN * s - h), Vector2(w, h))
		var hp_v: Variant = e.node.get(&"hp")
		var max_v: Variant = e.node.get(&"max_hp")
		var frac := clampf((float(hp_v) if hp_v != null else 0.0) / maxf(float(max_v) if max_v != null else 1.0, 1.0), 0.0, 1.0)
		var tint := Palette.team_color(e.id)
		draw_rect(r.grow(2.0 * s), COL_BLOCK)
		draw_rect(r, Color(HpBarStyle.COL_BG, 0.92))
		var hc := Palette.hp() if frac > HpBarStyle.LOW_HP_FRAC else Palette.hp_low()
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), hc)
		draw_rect(r.grow(2.0 * s), tint, false, maxf(1.5, 1.5 * s)) # liseré à la teinte d'équipe
		var fs := maxi(int(GLYPH_PX * s), 12)
		var gp := Vector2(r.position.x - fs * 0.85, r.end.y + fs * 0.1)
		draw_string_outline(_font, gp, Palette.team_glyph(e.id), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
		draw_string(_font, gp, Palette.team_glyph(e.id), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tint)
		bars.append({"slot": e.id, "rect": r, "frac": frac})
