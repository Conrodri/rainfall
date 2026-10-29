class_name SecretLever
extends Node2D
## Levier caché d'une salle secrète (déclencheur « lever », docs/Design_Variantes_B.md « Déclencheurs »). Posé dans un
## recoin de la carte (marqueur `lever`). S'actionne uniquement par l'action « interagir » (contrat Interaction, comme
## le téléporteur : jamais au contact) ; définitif pour l'étage. Sprites Codex `lever_<biome>_{off,on}` (+ `_e`
## émission, `_shadow` décalque cuit par BakedShadows), rendus iso 2,25 u / 128 px.

signal activated

const SPRITE_DIR := "res://assets/sprites/props/secret/"
const DEFAULT_BIOME := &"terraces"
const RENDER_PX_PER_U := 128.0 / 2.25 ## ortho_scale 2,25 u sur 128 px (art/tools/props/secret_lever_build.py)
const SPRITE_BASE_Y := 0.80 ## socle à 80 % de la hauteur de frame : posé sur la position

var used := false
## Biome (à fixer avant add_child) : choisit la déclinaison de sprites.
var biome: StringName = DEFAULT_BIOME
var _player: Node2D = null
var _sprite: Sprite2D = null


func _ready() -> void:
	add_to_group(&"interactable")
	_refresh_sprite()


func _player_node() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D if is_inside_tree() else null
	return _player


func player_near() -> bool:
	var p := _player_node()
	return p != null and p.global_position.distance_to(global_position) <= Balance.SECRET_LEVER_RANGE_U * Balance.UNIT_PX


func can_interact() -> bool:
	return not used and player_near()


func interact_label() -> String:
	return "Actionner"


func interact_state() -> Dictionary:
	return {"visible": can_interact(), "enabled": true, "label": interact_label(), "hold_s": 0.0}


func interact_priority() -> int:
	return 2


func interact() -> bool:
	if used or not player_near():
		return false
	pull(false)
	return true


## Abaisse le levier (définitif). `silent` : restauration d'une sauvegarde, aucun signal ni son.
func pull(silent: bool = false) -> void:
	if used:
		return
	used = true
	remove_from_group(&"interactable")
	_refresh_sprite()
	if not silent:
		Audio.play(&"chest.lock", global_position)
		activated.emit()


func _refresh_sprite() -> void:
	var state := "on" if used else "off"
	var path := RenderStyle.resolve("%slever_%s_%s.png" % [SPRITE_DIR, biome, state])
	if not ResourceLoader.exists(path):
		path = RenderStyle.resolve("%slever_%s_%s.png" % [SPRITE_DIR, DEFAULT_BIOME, state])
		if not ResourceLoader.exists(path):
			return
	if _sprite != null:
		_sprite.queue_free() # l'enfant d'émission (_e) dépend de la texture : on repart de zéro
	_sprite = Sprite2D.new()
	_sprite.name = &"Sprite"
	var tex := load(path) as Texture2D
	_sprite.texture = tex
	_sprite.scale = Iso.UNSQUASH * (64.0 / RENDER_PX_PER_U) # billboard iso, 64 px/u
	_sprite.offset = Vector2(0.0, -float(tex.get_height()) * (SPRITE_BASE_Y - 0.5))
	add_child(_sprite)
	NormalMaps.apply_to_sprite(_sprite)
