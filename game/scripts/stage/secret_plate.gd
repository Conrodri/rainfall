class_name SecretPlate
extends Area2D
## Plaque de pression d'une porte scellée (docs/Design_Zones_Secretes.md §3.1) : décalque au sol de 2 × 2 u,
## déclenchée par le simple passage du joueur (jamais par un monstre : masque 2 seulement), état `pressed`
## DÉFINITIF pour l'étage, aucune interaction. Visuel provisoire (losange dessiné en code) en attendant le lot
## Codex S-A (dalle de vanne, pierre à rune, plaque rivetée, plaque d'os).

signal pressed_changed(plate: SecretPlate)

const SIZE_PX := 128.0 ## 2 u
const COL_ARMED := Color(0.78, 0.7, 0.45, 0.55)
const COL_PRESSED := Color(0.32, 0.3, 0.26, 0.8)
const COL_EDGE := Color(1.0, 0.9, 0.55, 0.9)
const COL_EDGE_PRESSED := Color(0.5, 0.46, 0.38, 0.9)

var secret_id := &""
var index := 0
var pressed := false


func _init() -> void:
	collision_layer = 0
	collision_mask = 1 << 1 # joueur uniquement
	monitoring = true
	monitorable = false
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(SIZE_PX, SIZE_PX) * 0.8
	cs.shape = sh
	add_child(cs)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# joueur déjà dessus à l'armement (apparition, reprise de sauvegarde) : détecté au premier tour physique
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	set_physics_process(false)
	if not pressed:
		for b in get_overlapping_bodies():
			_on_body_entered(b)


func _on_body_entered(b: Node) -> void:
	if pressed or not b.is_in_group(&"player"):
		return
	press()


## Enfonce la plaque (définitif). `silent` : restauration d'une sauvegarde, sans signal.
func press(silent: bool = false) -> void:
	if pressed:
		return
	pressed = true
	queue_redraw()
	if not silent:
		pressed_changed.emit(self)


func _draw() -> void:
	var h := SIZE_PX * 0.5
	var pts := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	draw_colored_polygon(pts, COL_PRESSED if pressed else COL_ARMED)
	pts.append(pts[0])
	draw_polyline(pts, COL_EDGE_PRESSED if pressed else COL_EDGE, 5.0)
	if not pressed:
		draw_circle(Vector2.ZERO, 14.0, COL_EDGE)
