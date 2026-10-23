class_name AvarePurseTip
extends Control
## Bulle de tutoriel de la bourse d'Avare (retour joueur 22/10/2026 : « la bourse n'est pas expliquée »).
## Courte, NON bloquante (jamais de pause, mouse_filter ignore), affichée une fois par profil par AvareKit
## (Profile.objective_progress(AvareKit.TIP_KEY)). Posée au-dessus de la jauge « Bourse » du HUD quand elle est
## visible (ResourceGauge de Hud), sinon en bas au centre. Masquée pendant les pauses ; fondu, puis libérée.
## Plaque de la DA (panel_small_9slice) ; aucun asset dessiné en code.

const LIFE_S := 11.0
const FADE_IN_S := 0.3
const FADE_OUT_S := 0.8
const WIDTH_PX := 560.0 ## à ui_scale 1
const GAP_PX := 14.0
const YIELD_FADE_S := 0.15 ## fondu quand une bulle prioritaire s'ouvre
## Tailles de police [PC, mobile] à ui_scale 1, passées par HudMetrics.font (plancher 18 px PC / 26 px mobile).
const TITLE_FONT := [22, 30]
const BODY_FONT := HudMetrics.T4_SMALL
const TITLE := "La bourse d'Avare"
const LINES := [
	"Ton or est ta force : +15 % de dégâts par prix d'un petit coffre en poche (jusqu'à +30 %).",
	"Elle se remplit avec l'or des monstres (ramassé tout seul) et tes pièces tombées : elles restent au sol, marche dessus pour les reprendre.",
	"Acheter un coffre la vide ; à l'étage suivant, tu en gardes la moitié.",
]

var hud: Node = null
var accent := Color("#F2C14E")
var ui_scale := 1.0
var t := 0.0
var _panel: PanelContainer = null
var _yield_k := 0.0 ## 0 = visible, 1 = effacée au profit d'une bulle prioritaire
var _w := 1.0 ## échelle de largeur : suit la police réelle (plancher mobile) pour garder ~le même nombre de mots par ligne
var _body_px := 18


## Crée la bulle dans sa propre CanvasLayer (au-dessus du HUD) et la renvoie.
static func spawn(tree: SceneTree, p_accent: Color) -> AvarePurseTip:
	var layer := CanvasLayer.new()
	layer.name = "AvarePurseTipLayer"
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var tip := AvarePurseTip.new()
	tip.accent = p_accent
	tip.hud = _find_hud(tree.root)
	if tip.hud != null:
		tip.ui_scale = float(tip.hud.get(&"ui_scale")) if &"ui_scale" in tip.hud else 1.0
	layer.add_child(tip)
	(tree.current_scene if tree.current_scene != null else tree.root).add_child(layer)
	tip.tree_exited.connect(layer.queue_free)
	return tip


static func _find_hud(root: Node) -> Node:
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n is Hud:
			return n
	return null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate.a = 0.0


func _ready() -> void:
	var k := maxf(ui_scale, 0.5)
	_body_px = HudMetrics.font(BODY_FONT, k)
	_w = maxf(k, _body_px / float(BODY_FONT[0]))
	k = _w
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBox = UiTheme.da_box("panel_small_9slice", 0.5)
	if box == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.04, 0.045, 0.06, 0.92)
		flat.border_color = Color(accent, 0.8)
		flat.set_border_width_all(2)
		box = flat
	box = box.duplicate()
	box.content_margin_left = 22.0 * k
	box.content_margin_right = 22.0 * k
	box.content_margin_top = 14.0 * k
	box.content_margin_bottom = 16.0 * k
	_panel.add_theme_stylebox_override(&"panel", box)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override(&"separation", int(6 * k))
	_panel.add_child(v)
	var title := _label(TITLE.to_upper(), HudMetrics.font(TITLE_FONT, maxf(ui_scale, 0.5)), accent.lerp(Color.WHITE, 0.15))
	var tf := UiTheme.title_font()
	if tf != null:
		title.add_theme_font_override(&"font", tf)
	v.add_child(title)
	for line: String in LINES:
		v.add_child(_label("• " + line, _body_px, Color(0.88, 0.86, 0.82)))
	_panel.custom_minimum_size = Vector2(WIDTH_PX * k, 0.0)
	_place()


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2((WIDTH_PX - 44.0) * _w, 0.0)
	l.add_theme_font_size_override(&"font_size", fs)
	l.add_theme_color_override(&"font_color", col)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override(&"outline_size", maxi(int(fs * 0.22), 2))
	return l


## Jauge « Bourse » visible du HUD (barre de sorts au clavier-souris, grappe tactile), sinon null.
func _gauge() -> Control:
	if hud == null or not is_instance_valid(hud):
		return null
	for key: StringName in [&"bar_gauge", &"touch_gauge"]:
		var g: Variant = hud.get(key) if key in hud else null
		if g is Control and (g as Control).is_visible_in_tree():
			return g
	return null


func _place() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	var sz := _panel.get_combined_minimum_size()
	var pos := Vector2((vp.x - sz.x) * 0.5, vp.y - sz.y - 300.0 * ui_scale)
	var g := _gauge()
	if g != null:
		var r := g.get_global_rect()
		pos = Vector2(r.position.x, r.position.y - sz.y - GAP_PX * ui_scale)
	pos.x = clampf(pos.x, 16.0, maxf(vp.x - sz.x - 16.0, 16.0))
	pos.y = clampf(pos.y, 16.0, maxf(vp.y - sz.y - 16.0, 16.0))
	_panel.position = pos
	_panel.size = sz


func _process(delta: float) -> void:
	var paused := get_tree().paused
	visible = not paused
	if paused:
		return
	# arbitre des bulles (H5) : une bulle demandée par le joueur (sort, item) prime ; le tutoriel
	# s'efface (fondu 0,15 s), son minuteur s'arrête, puis il reprend.
	var yield_now := SpellTooltip.user_bubble_open()
	_yield_k = move_toward(_yield_k, 1.0 if yield_now else 0.0, delta / YIELD_FADE_S)
	if not yield_now:
		t += delta
	modulate.a = clampf(t / FADE_IN_S, 0.0, 1.0) * clampf((LIFE_S - t) / FADE_OUT_S, 0.0, 1.0) * (1.0 - _yield_k)
	visible = _yield_k < 1.0
	_place()
	if t >= LIFE_S:
		queue_free()


## Texte complet (tests, accessibilité).
func text_content() -> String:
	return TITLE + "\n" + "\n".join(LINES)
