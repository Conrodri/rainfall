class_name FadeLayer
extends CanvasLayer
## Fondu au noir plein écran §2.4 (layer 200, actif pendant la pause).
## `await fade.fade_out(0.18)` puis changer d'écran puis `await fade.fade_in(0.18)`.

var _rect: ColorRect
var _tween: Tween


func _init() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


## Alpha courant du noir (0 = transparent).
func alpha() -> float:
	return _rect.modulate.a


## Assombrit l'écran ; bloque les clics pendant et après le fondu.
func fade_out(duration := 0.18) -> Signal:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return _go(1.0, duration)


## Éclaircit l'écran ; rend les clics à la fin.
func fade_in(duration := 0.18) -> Signal:
	var s := _go(0.0, duration)
	s.connect(func() -> void: _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE, CONNECT_ONE_SHOT)
	return s


func _go(target: float, duration: float) -> Signal:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", target, maxf(duration, 0.0))
	return _tween.finished
