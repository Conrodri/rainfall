class_name FpsCounter
extends CanvasLayer
## Compteur d'images par seconde (Réglages > Affichage > « Afficher les FPS »).
## Un seul exemplaire, posé par App : visible au titre, en run et en mode test, au-dessus du HUD.
## Suit GameSettings.show_fps_live() (cache mémoire, pas de lecture disque) : cocher/décocher agit
## dans le quart de seconde. Caché = process désactivé, coût nul.

const LAYER_FPS := 110 ## au-dessus des écrans (App.UI_LAYER = 10) et du HUD
const REFRESH := 0.25 ## secondes entre deux mises à jour du texte
const MARGIN := 12.0 ## marge minimale, élargie par la zone sûre (encoche)

var label: Label
var _acc := 0.0


func _ready() -> void:
	layer = LAYER_FPS
	process_mode = Node.PROCESS_MODE_ALWAYS # continue pendant la pause
	label = Label.new()
	label.name = "FpsLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(label)
	_apply_margin()
	get_tree().root.size_changed.connect(_apply_margin)
	_sync(true)


## Bord haut-droit, décalé de l'encoche éventuelle (ratio et orientation quelconques).
func _apply_margin() -> void:
	var win := get_tree().root
	var ws := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var right := 0.0
	var top := 0.0
	if ws.x > 0.0 and ws.y > 0.0 and safe.size.x > 0.0:
		right = maxf(0.0, ws.x - safe.end.x)
		top = maxf(0.0, safe.position.y)
	var vp := Vector2(win.size)
	var k := vp.x / ws.x if ws.x > 0.0 else 1.0 # pixels fenêtre -> pixels logiques
	label.offset_right = -(MARGIN + right * k)
	label.offset_top = MARGIN + top * k


func _process(delta: float) -> void:
	_acc += delta
	if _acc < REFRESH:
		return
	_acc = 0.0
	_sync(false)


func _sync(force: bool) -> void:
	var on := GameSettings.show_fps_live()
	if on != label.visible or force:
		label.visible = on
	if on:
		label.text = "%d FPS" % Engine.get_frames_per_second()
