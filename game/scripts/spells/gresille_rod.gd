class_name GresilleRod
extends Node2D
## Tige du Paratonnerre (variante de la Mise à la terre, docs/fiches/gresille.md §12.2) : plantée au point visé, elle
## attire la foudre toutes les `tick_s` secondes pendant `life` s. Le nœud ne fait que le décompte et le visuel ; le coup de
## foudre lui-même est le rappel `on_strike(position)` fourni par le kit (dégâts, Statique, sons).
## Rendu : PLACEHOLDER (tige dessinée en code + anneau lilas qui grossit 0,8 s avant chaque coup), en attendant le prop
## `rod_planted` (à produire par Codex : icônes et props manquants listés dans le rapport).

const ACCENT := Color("#B9A6FF")
const TELEGRAPH_S := 0.8
const ROD_HEIGHT_PX := 64.0

var life := 6.0
var tick_s := 1.0
var radius_px := 128.0
var strikes := 0 ## coups déjà tombés
var ended := false
var _on_strike := Callable()
var _age := 0.0
var _tick_t := 0.0
var _strikes_left := 0
var _body: Node2D = null


func setup(at: Vector2, life_s: float, tick: float, r_px: float, on_strike: Callable) -> void:
	global_position = at
	life = life_s
	tick_s = maxf(tick, 0.05)
	radius_px = r_px
	_on_strike = on_strike
	_strikes_left = maxi(roundi(life / tick_s), 1)
	z_index = -1
	_body = Node2D.new() # la tige se dresse : espace billboard
	_body.scale = Iso.UNSQUASH
	_body.z_index = 2
	_body.draw.connect(_draw_body)
	add_child(_body)
	queue_redraw()


## Avance de `delta` (public : tests sans boucle de rendu).
func step(delta: float) -> void:
	if ended:
		return
	_age += delta
	_tick_t += delta
	while _tick_t >= tick_s - 0.0001 and _strikes_left > 0:
		_tick_t -= tick_s
		_strikes_left -= 1
		strikes += 1
		if _on_strike.is_valid():
			_on_strike.call(global_position)
	if _strikes_left <= 0 or _age >= life + 0.1:
		ended = true
		queue_free()
	else:
		queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func _draw() -> void:
	var phase := _tick_t / tick_s
	var start := 1.0 - TELEGRAPH_S / tick_s
	if phase > start:
		var k := (phase - start) / (1.0 - start)
		draw_circle(Vector2.ZERO, radius_px * k, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.10 + 0.12 * k))
		draw_arc(Vector2.ZERO, radius_px * k, 0.0, TAU, 48, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7), 2.0)
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 16, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6), 2.0) # pied de la tige


func _draw_body() -> void:
	_body.draw_line(Vector2.ZERO, Vector2(0.0, -ROD_HEIGHT_PX), Color("#7C6A52"), 4.0)
	_body.draw_circle(Vector2(0.0, -ROD_HEIGHT_PX), 5.0, ACCENT)
	_body.draw_line(Vector2(-6.0, -ROD_HEIGHT_PX * 0.45), Vector2(6.0, -ROD_HEIGHT_PX * 0.45), Color("#CFC8DA"), 3.0)
