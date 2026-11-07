class_name EpreuveChasePost
extends Node2D
## Borne de la Poursuite (docs/Design_Epreuves.md §3.3) : champignon-lanterne au Gouffre, cristal éteint aux Cryptes.
## Objet purement visuel et fixe (enfant de l'EpreuveChase, qui bouge avec la lumière) : trois états, `idle` (éteinte),
## `lit` (la lumière est dessus), `done` (point marqué : reste allumée, accent émissif fixe). Placeholder : losange de 1 u
## teinté par le biome ; un seul nœud visuel (`Corps`) à échanger plus tard contre le sprite Codex (`_altar` pour la borne 0).

const STATE_IDLE := &"idle"
const STATE_LIT := &"lit"
const STATE_DONE := &"done"

var index := 0 ## rang dans l'itinéraire (0 = autel de départ)
var tint := Color(0.76, 0.48, 1.0) ## teinte du biome
var state: StringName = STATE_IDLE
var skin := "fog_forest" ## "fog_forest" | "crypts" : choisit les sprites Codex `chase_post_<skin>_<état>` (lot EP-B)
var _body: Polygon2D = null ## repli dessiné en code si les sprites manquent
var _sprite: Sprite2D = null


func _ready() -> void:
	_body = Polygon2D.new()
	_body.name = &"Corps"
	var s := 1.4 if index == 0 else 1.0
	_body.polygon = PackedVector2Array([Vector2(0.0, -34.0) * s, Vector2(32.0, 0.0) * s, Vector2(0.0, 20.0) * s, Vector2(-32.0, 0.0) * s])
	add_child(_body)
	_refresh()


func set_skin(s: String) -> void:
	if s == skin:
		return
	skin = s
	_refresh()


## Sprite Codex de l'état courant (l'autel pour la borne 0) ; null : repli en forme code.
func _state_tex() -> Texture2D:
	var st := "altar" if index == 0 else ("done" if state == STATE_DONE else ("lit" if state == STATE_LIT else "off"))
	return EpreuveSprites.tex(EpreuveSprites.PROPS_DIR, "chase_post_%s_%s.png" % [skin, st])


func set_tint(c: Color) -> void:
	tint = c
	_refresh()


func set_state(s: StringName) -> void:
	if s == state:
		return
	state = s
	_refresh()


func _refresh() -> void:
	if _body == null:
		return
	var tex := _state_tex()
	if tex != null:
		_body.visible = false
		if _sprite == null:
			_sprite = EpreuveSprites.make(tex, 0.80)
			_sprite.name = &"Sprite"
			add_child(_sprite)
		EpreuveSprites.set_tex(_sprite, tex, 0.80)
		# l'autel n'a qu'un sprite : on éclaire selon l'état
		_sprite.modulate = Color(1.25, 1.25, 1.25) if index == 0 and state != STATE_IDLE else Color.WHITE
		return
	_body.visible = true
	match state:
		STATE_DONE: # accent émissif fixe
			_body.color = Color(tint.r * 1.6, tint.g * 1.6, tint.b * 1.6, 1.0)
		STATE_LIT:
			_body.color = Color(tint.r * 1.2, tint.g * 1.2, tint.b * 1.2, 1.0)
		_:
			_body.color = Color(tint.r * 0.35, tint.g * 0.35, tint.b * 0.35, 0.9)
