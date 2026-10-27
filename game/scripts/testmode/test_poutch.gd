class_name TestPoutch
extends Node2D
## Poutch (mode test) : compteur de dégâts qui suit un mannequin d'entraînement (Enemy.test_dummy : immobile, n'attaque pas,
## ne meurt jamais, mais reçoit tout : dégâts, critiques, statuts, ciblage automatique). Affiche au-dessus de lui le DPS
## sur 5 s glissantes et le total cumulé. Se libère tout seul quand le mannequin est retiré.
## À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

const WINDOW_S := 5.0
const REFRESH_S := 0.1
const TYPE_NAMES := {&"normal": "Normal", &"elite": "Élite", &"boss": "Boss"}

var enemy: Enemy
var poutch_type: StringName = &"normal"
var total := 0.0
var hit_count := 0

var _t := 0.0
var _first_t := -1.0
var _log: Array[Vector2] = [] ## (temps, dégâts) des coups des WINDOW_S dernières secondes
var _label: Label
var _next_refresh := 0.0


func _ready() -> void:
	add_to_group(&"poutchs")
	name = "Poutch"
	z_index = 200
	z_as_relative = false
	_label = Label.new()
	_label.scale = Iso.UNSQUASH # billboard : texte net malgré l'écrasement de la caméra
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.theme = UiTheme.theme()
	_label.add_theme_font_size_override(&"font_size", 26)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 8)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	Events.enemy_damaged.connect(_on_damaged)
	_refresh()


func _exit_tree() -> void:
	if Events.enemy_damaged.is_connected(_on_damaged):
		Events.enemy_damaged.disconnect(_on_damaged)


func _process(delta: float) -> void:
	if not is_instance_valid(enemy) or not enemy.active or not enemy.test_dummy:
		queue_free()
		return
	_t += delta
	position = enemy.position
	_next_refresh -= delta
	if _next_refresh <= 0.0:
		_next_refresh = REFRESH_S
		_refresh()


func _on_damaged(e: Node2D, amount: float, _crit: bool, _element: StringName) -> void:
	if e != enemy:
		return
	if _first_t < 0.0:
		_first_t = _t
	total += amount
	hit_count += 1
	_log.append(Vector2(_t, amount))


## Remise à zéro du compteur.
func reset() -> void:
	total = 0.0
	hit_count = 0
	_first_t = -1.0
	_log.clear()
	_refresh()


## Dégâts par seconde sur les WINDOW_S dernières secondes (fenêtre plus courte tant que le combat est plus récent).
func dps() -> float:
	var cut := _t - WINDOW_S
	while not _log.is_empty() and _log[0].x < cut:
		_log.pop_front()
	if _first_t < 0.0 or _log.is_empty():
		return 0.0
	var sum := 0.0
	for h in _log:
		sum += h.y
	return sum / clampf(_t - _first_t, 0.5, WINDOW_S)


func _refresh() -> void:
	if _label == null or not is_instance_valid(enemy):
		return
	_label.text = "POUTCH · %s\nDPS (5 s) : %s\nTotal : %s" % [TYPE_NAMES.get(poutch_type, ""), _fmt(dps()), _fmt(total)]
	_label.size = _label.get_combined_minimum_size()
	# espace billboard (px à 64 px/u, vers le haut = négatif) : au-dessus de la silhouette, proportionnel au rayon
	var lift := enemy.radius_px * 6.0 + 20.0
	_label.position = Vector2(-_label.size.x * 0.5, -lift - _label.size.y)


static func _fmt(v: float) -> String:
	if v >= 1.0e6:
		return "%.2f M" % (v / 1.0e6)
	if v >= 10000.0:
		return "%.1f k" % (v / 1000.0)
	return str(int(round(v)))
