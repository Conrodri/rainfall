class_name DifficultyBanner
extends Control
## Bandeau de difficulté façon Risk of Rain : un rectangle par palier (nom écrit dedans, couleur du palier), largeur
## proportionnelle à l'étendue en D du palier ; le bandeau glisse vers la gauche quand D monte, un repère fixe
## (à ~1/3 depuis la gauche) marque la difficulté actuelle. Le dernier palier (Cataclysme) s'étend sans fin.
## Les paliers viennent de `Balance.DIFFICULTY_TIERS`. Textures facultatives (livrées par Codex, lot 57) dans
## `res://assets/sprites/ui/difficulty/banner/` : `seg_<id>.png` (tuilable en largeur, étirée en hauteur),
## `marker.png` (repère, centré sur son axe vertical), `frame.png` (cadre étiré 9-slice, marge `FRAME_MARGIN`) ;
## à défaut : rectangles colorés en code (placeholder).

const TEX_DIR := "res://assets/sprites/ui/difficulty/banner/"
const PX_PER_D_EM := 8.5 ## largeur d'1 D en hauteurs de police : Tendu (0,35 D) reste assez large pour son nom
const MARKER_X := 0.34 ## position du repère, en fraction de la largeur
const SMOOTH_RATE := 5.0 ## lissage exponentiel du défilement (1/s)
const SNAP_D := 1.5 ## écart au-delà duquel le défilement saute (changement de D du mode test, nouvel étage)
const PAST_DIM := 0.55 ## les paliers non courants sont assombris
const FRAME_MARGIN := 12
const COL_TEXT := Color(0.91, 0.886, 0.839)
const COL_BG := Color(0.043, 0.035, 0.027, 0.95)
const COL_LINE := Color(0.05, 0.04, 0.03, 0.9)
const COL_FRAME := Color(0.29, 0.26, 0.235, 0.95)

var font_size := 18
var _target := 1.0
var _shown := 1.0
var _seen := false
var _seg_tex := {}
var _marker_tex: Texture2D
var _frame_tex: Texture2D


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "DifficultyBanner"


func _ready() -> void:
	for t in Balance.DIFFICULTY_TIERS:
		var tex := _load_tex("seg_%s.png" % t["id"])
		if tex != null:
			_seg_tex[t["id"]] = tex
	_marker_tex = _load_tex("marker.png")
	_frame_tex = _load_tex("frame.png")


static func _load_tex(file: String) -> Texture2D:
	var path := TEX_DIR + file
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Taille de police et dimensions du bandeau (appelé par le HUD à chaque changement d'échelle).
func configure(font_px: int, width: float) -> void:
	font_size = font_px
	var h := ceilf(font_px * 1.55)
	custom_minimum_size = Vector2(width, h)
	size = custom_minimum_size
	queue_redraw()


func set_difficulty(D: float) -> void:
	_target = D
	if not _seen or absf(D - _shown) > SNAP_D:
		_shown = D
		_seen = true
	queue_redraw()


func current_name() -> StringName:
	return Balance.difficulty_tier_name(_target)


## D affiché (suit D avec un lissage) ; utile aux tests.
func shown_d() -> float:
	return _shown


func _process(delta: float) -> void:
	if not is_visible_in_tree() or is_equal_approx(_shown, _target):
		return
	_shown = lerpf(_shown, _target, 1.0 - exp(-SMOOTH_RATE * delta))
	if absf(_shown - _target) < 0.0002:
		_shown = _target
	queue_redraw()


func _x_of(d: float) -> float:
	return size.x * MARKER_X + (d - _shown) * font_size * PX_PER_D_EM


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	var font: Font = get_theme_font(&"font", &"Label")
	var cur := Balance.difficulty_tier_index(_shown)
	var tiers: Array[Dictionary] = Balance.DIFFICULTY_TIERS
	for i in tiers.size():
		var t: Dictionary = tiers[i]
		var d0: float = float(t["from"])
		var x0 := _x_of(d0)
		var x1 := _x_of(float(tiers[i + 1]["from"])) if i + 1 < tiers.size() else w + 4.0
		if i == 0:
			x0 = minf(x0, -4.0) # le premier palier remplit tout le côté gauche
		var vx0 := clampf(x0, 0.0, w)
		var vx1 := clampf(x1, 0.0, w)
		if vx1 - vx0 < 1.0:
			continue
		var col: Color = t["color"]
		var shade := Color.WHITE if i == cur else Color(PAST_DIM, PAST_DIM, PAST_DIM, 1.0)
		var seg := Rect2(x0, 0.0, x1 - x0, h)
		var tex: Texture2D = _seg_tex.get(t["id"])
		if tex != null:
			draw_texture_rect(tex, seg, true, shade)
		else:
			draw_rect(seg, col * shade) # placeholder : aplat de la couleur du palier
			draw_rect(Rect2(x0, 0.0, x1 - x0, h * 0.28), Color(1, 1, 1, 0.14 if i == cur else 0.07))
		draw_rect(Rect2(x0, 0.0, 2.0, h), COL_LINE) # séparation entre deux paliers
		# nom centré dans la partie visible ; omis si le rectangle est trop étroit (sauf palier courant)
		var label := String(t["name"])
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var mx := w * MARKER_X
		var lx0 := vx0
		var lx1 := vx1
		if i == cur: # palier courant : le nom se range d'un côté du repère (devant si ça tient, sinon derrière)
			if vx1 - (mx + 4.0) >= tw + 6.0:
				lx0 = mx + 4.0
			elif mx - 4.0 - vx0 >= tw + 6.0:
				lx1 = mx - 4.0
		if lx1 - lx0 >= tw + 8.0 or i == cur:
			var tx := (lx0 + lx1) * 0.5 - tw * 0.5
			var ty := h * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
			draw_string_outline(font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.9))
			draw_string(font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COL_TEXT)
	if _frame_tex != null:
		draw_texture_rect(_frame_tex, Rect2(Vector2.ZERO, size), false) # cadre posé sur le bord
	else:
		draw_rect(Rect2(Vector2.ZERO, size), COL_FRAME, false, 3.0)
	_draw_marker(w, h)


func _draw_marker(w: float, h: float) -> void:
	var mx := w * MARKER_X
	if _marker_tex != null:
		var ms := Vector2(_marker_tex.get_width(), _marker_tex.get_height()) * (h * 1.3 / maxf(_marker_tex.get_height(), 1.0))
		draw_texture_rect(_marker_tex, Rect2(Vector2(mx - ms.x * 0.5, (h - ms.y) * 0.5), ms), false)
		return
	var c := COL_TEXT
	draw_line(Vector2(mx, 0.0), Vector2(mx, h), Color(c, 0.6), 2.0)
	var a := minf(h * 0.3, 10.0)
	draw_colored_polygon(PackedVector2Array([Vector2(mx - a, 0.0), Vector2(mx + a, 0.0), Vector2(mx, a * 1.2)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(mx - a, h), Vector2(mx + a, h), Vector2(mx, h - a * 1.2)]), c)
