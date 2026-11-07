class_name EpreuveHoldBell
extends Node2D
## Cloche d'alerte de la Tenue (docs/Design_Epreuves.md §3.5) : l'objet que les paquets de monstres visent (`walk_target`)
## et que le joueur doit défendre. Interactable (« interagir » seulement, jamais au contact) tant que la Tenue n'est pas
## lancée ; porte les PV (que `EpreuveHold` règle au lancement) et trois états : `off` (au repos), `ringing` (épreuve en
## cours), `dim` (PV à 0 : éteinte, elle ne casse pas, l'épreuve continue mais la note sera « fait »).
## Visuel : placeholder (trapèze 1,5 x 2,5 u en Polygon2D + barre de PV). L'échange contre le sprite Codex ne touche que
## le nœud `_body` (`_refresh_visual`).

signal dimmed ## PV tombés à 0 (une seule fois par épreuve)

const STATE_OFF := &"off"
const STATE_RINGING := &"ringing"
const STATE_DIM := &"dim"

const WIDTH_U := 1.5
const HEIGHT_U := 2.5
const COL_OFF := Color(0.45, 0.38, 0.30)
const COL_RINGING := Color(0.95, 0.72, 0.28)
const COL_DIM := Color(0.20, 0.18, 0.18)

var hold: Node = null ## EpreuveHold propriétaire (non typé : pas de dépendance circulaire de classes)
var state: StringName = STATE_OFF
var max_hp := 0.0
var hp := 0.0
var _body: Polygon2D = null ## repli code
var _sprite: Sprite2D = null
var skin := "rust_city" ## sprites `hold_bell_<skin>_{off,ringing,dim}` (lot EP-E)
var _t := 0.0


func _init() -> void:
	name = &"Cloche"


func _ready() -> void:
	add_to_group(&"interactable")
	var w := WIDTH_U * Balance.UNIT_PX
	var h := HEIGHT_U * Balance.UNIT_PX
	_body = Polygon2D.new()
	_body.name = &"Corps"
	_body.polygon = PackedVector2Array([Vector2(-w * 0.5, 0.0), Vector2(w * 0.5, 0.0), Vector2(w * 0.3, -h), Vector2(-w * 0.3, -h)])
	add_child(_body)
	_refresh_visual()


func _process(delta: float) -> void:
	if _sprite != null and state == STATE_RINGING:
		_t += delta
		_sprite.frame = int(_t * 8.0) % maxi(_sprite.hframes, 1) # 4 frames de battant à 8 fps
	elif state == STATE_RINGING and _body != null:
		_t += delta
		var k := 0.5 + 0.5 * sin(_t * 6.0)
		_body.color = COL_RINGING.lerp(Color(1.0, 0.95, 0.7), 0.25 * k)


## Règle les PV et passe en `ringing` (lancement de l'épreuve).
func arm(new_max_hp: float) -> void:
	max_hp = maxf(new_max_hp, 1.0)
	hp = max_hp
	set_state(STATE_RINGING)
	queue_redraw()


func set_state(s: StringName) -> void:
	if state == s:
		return
	state = s
	_refresh_visual()
	queue_redraw()


## Dégâts reçus (monstres au contact). À 0 PV : éteinte, jamais détruite.
func damage(amount: float) -> void:
	if amount <= 0.0 or state != STATE_RINGING:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		set_state(STATE_DIM)
		dimmed.emit()
	queue_redraw()


func hp_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0


func is_dim() -> bool:
	return state == STATE_DIM


## Reprise de sauvegarde : PV et état (sans signal).
func restore(saved_hp: float, saved_max: float, dim: bool, ringing: bool) -> void:
	max_hp = saved_max
	hp = saved_hp
	set_state(STATE_DIM if dim else (STATE_RINGING if ringing else STATE_OFF))
	queue_redraw()


func _refresh_visual() -> void:
	if _body == null:
		return
	var st := "ringing" if state == STATE_RINGING else ("dim" if state == STATE_DIM else "off")
	var tex := EpreuveSprites.tex(EpreuveSprites.PROPS_DIR, "hold_bell_%s_%s.png" % [skin, st])
	if tex != null:
		_body.visible = false
		var hf := 4 if state == STATE_RINGING else 1
		if _sprite == null:
			_sprite = EpreuveSprites.make(tex, 0.85, hf)
			_sprite.name = &"Sprite"
			add_child(_sprite)
		EpreuveSprites.set_tex(_sprite, tex, 0.85, hf)
		_sprite.frame = 0
		return
	_body.visible = true
	match state:
		STATE_RINGING:
			_body.color = COL_RINGING
		STATE_DIM:
			_body.color = COL_DIM
		_:
			_body.color = COL_OFF


# --- Interaction (contrat « Interaction mobile ») : seulement pour lancer l'épreuve
func _hold_ready() -> bool:
	return hold != null and is_instance_valid(hold) and hold.get(&"state") == Pillar.STATE_READY


func player_near() -> bool:
	return is_inside_tree() and CoopRules.any_within(global_position, Balance.SECRET_LEVER_RANGE_U * Balance.UNIT_PX, true)


func can_interact() -> bool:
	return _hold_ready() and player_near()


func interact_label() -> String:
	return String(hold.call(&"interact_label")) if hold != null and is_instance_valid(hold) else "Sonner la cloche"


func interact_state() -> Dictionary:
	return {"visible": can_interact(), "enabled": true, "label": interact_label(), "hold_s": 0.0}


func interact_priority() -> int:
	return 2


func interact(_who: Node = null) -> bool:
	if not can_interact():
		return false
	return bool(hold.call(&"activate"))


func _draw() -> void:
	if state == STATE_OFF or max_hp <= 0.0:
		return
	var w := 96.0
	var y := -HEIGHT_U * Balance.UNIT_PX - 18.0
	draw_rect(Rect2(-w * 0.5, y, w, 8.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w * 0.5, y, w * hp_ratio(), 8.0), Color(0.95, 0.75, 0.3) if state == STATE_RINGING else Color(0.5, 0.2, 0.2))
