class_name HpTrail
extends ColorRect
## Traîne blanche de la barre de vie (ressenti des coups reçus) : la portion perdue reste affichée
## en blanc puis se vide en DRAIN_S. Se branche sur n'importe quelle barre `Range` (ProgressBar,
## TextureProgressBar) remplie de gauche à droite, sans rien changer au code de la barre :
##   HpTrail.attach(bar)   (une ligne côté HUD, après la création de la barre)
## Le rectangle est un enfant de la barre, placé sous ses autres enfants (le texte reste lisible),
## et ne couvre que la partie vide entre la valeur courante et la valeur affichée par la traîne.

const HOLD_S := 0.12 ## la traîne reste pleine un instant avant de se vider (lecture du coup)
const DRAIN_S := 0.4
const TRAIL_COLOR := Color(1.0, 1.0, 1.0, 0.85)

var _bar: Range
var _shown := -1.0 ## valeur affichée par la traîne (unités de la barre)
var _last := 0.0 ## dernière valeur de la barre (la régénération émet à chaque image : seule une baisse est un coup)
var _from := 0.0
var _hold := 0.0
var _t := 1.0 ## avancement du vidage [0, 1]


static func attach(bar: Range) -> HpTrail:
	if bar == null:
		return null
	for c in bar.get_children():
		if c is HpTrail:
			return c
	var t := HpTrail.new()
	t.name = &"HpTrail"
	t._bar = bar
	bar.add_child(t)
	bar.move_child(t, 0) # sous le texte de la barre
	return t


func _ready() -> void:
	color = TRAIL_COLOR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _bar == null:
		_bar = get_parent() as Range
	if _bar == null:
		return
	_shown = _bar.value
	_last = _bar.value
	_bar.value_changed.connect(_on_value_changed)
	_layout()


## Valeur actuellement couverte par la traîne (tests).
func shown_value() -> float:
	return _shown


func _on_value_changed(v: float) -> void:
	var dropped := v < _last - 0.0001
	_last = v
	if v >= _shown:
		_shown = v # soin / régénération au-dessus de la traîne : elle suit sans délai
		_hold = 0.0
		_t = 1.0
	elif dropped:
		_from = _shown # nouveau coup (même en plein vidage) : la traîne repart de ce qu'elle affiche
		_hold = HOLD_S
		_t = 0.0
	_layout() # petite hausse (régénération) sous la traîne : le vidage continue vers la valeur courante


func _process(delta: float) -> void:
	if _bar == null:
		return
	if _t < 1.0:
		if _hold > 0.0:
			_hold -= delta
		else:
			_t = minf(_t + delta / DRAIN_S, 1.0)
			var k := 1.0 - (1.0 - _t) * (1.0 - _t) # ease-out : vidage vif puis ralenti
			_shown = lerpf(_from, _bar.value, k)
	else:
		_shown = _bar.value
	_layout()


func _layout() -> void:
	if _bar == null:
		return
	var span := maxf(_bar.max_value - _bar.min_value, 0.0001)
	var a := clampf((_bar.value - _bar.min_value) / span, 0.0, 1.0)
	var b := clampf((_shown - _bar.min_value) / span, 0.0, 1.0)
	visible = b > a + 0.0005
	if not visible:
		return
	var w := _bar.size.x
	position = Vector2(w * a, 0.0)
	size = Vector2(w * (b - a), _bar.size.y)
