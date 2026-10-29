class_name SecretBeacon
extends Node2D
## Pilier éteint (déclencheur « pillar ») : un petit pilier loin de la salle. Rester dans son cercle
## Balance.SECRET_PILLAR_CHARGE_S secondes (cumulées, la charge ne retombe pas) ouvre la porte. Même vocabulaire que les
## piliers de boss (sprite pillar_small, anneau de charge) mais sans boss ni zone. Visuel : sprite du petit pilier réutilisé.

signal charged
signal progressed(ratio: float)

const SPRITE_OFF := "res://assets/sprites/props/pillar_small_off.png"
const SPRITE_DONE := "res://assets/sprites/props/pillar_small_done.png"
const SPRITE_BASE_Y := 0.82

var charge_s := 0.0
var done := false
var _player: Node2D = null
var _sprite: Sprite2D = null
var _tick := 0.0


func _ready() -> void:
	_set_sprite(SPRITE_OFF)
	queue_redraw()


func radius_px() -> float:
	return Balance.SECRET_PILLAR_RADIUS_U * Balance.UNIT_PX


func ratio() -> float:
	return clampf(charge_s / Balance.SECRET_PILLAR_CHARGE_S, 0.0, 1.0)


func _process(delta: float) -> void:
	if done:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if _player == null or not RunState.running or _player.global_position.distance_to(global_position) > radius_px():
		return
	charge_s = minf(charge_s + delta, Balance.SECRET_PILLAR_CHARGE_S)
	progressed.emit(ratio())
	queue_redraw()
	if charge_s >= Balance.SECRET_PILLAR_CHARGE_S:
		complete(false)


## Charge terminée (aussi appelé par les tests). `silent` : restauration d'une sauvegarde.
func complete(silent: bool = false) -> void:
	if done:
		return
	done = true
	charge_s = Balance.SECRET_PILLAR_CHARGE_S
	_set_sprite(SPRITE_DONE)
	queue_redraw()
	if not silent:
		Audio.play(&"ui.spell_ready", global_position)
		charged.emit()


func restore_ratio(r: float) -> void:
	charge_s = clampf(r, 0.0, 1.0) * Balance.SECRET_PILLAR_CHARGE_S
	queue_redraw()


func _set_sprite(path: String) -> void:
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	var h := float(tex.get_height())
	_sprite.hframes = maxi(int(round(tex.get_width() / h)), 1)
	_sprite.scale = Iso.UNSQUASH * 0.8
	_sprite.offset = Vector2(0.0, -h * (SPRITE_BASE_Y - 0.5))
	add_child(_sprite)


func _draw() -> void:
	var r := radius_px()
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.75, 0.7, 0.55, 0.22 if not done else 0.1), 3.0)
	if not done and charge_s > 0.0:
		draw_arc(Vector2.ZERO, r, -PI * 0.5, -PI * 0.5 + TAU * ratio(), 48, Color(1.0, 0.82, 0.45, 0.85), 6.0)
