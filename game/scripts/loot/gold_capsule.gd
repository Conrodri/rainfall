class_name GoldCapsule
extends Area2D
## Capsule d'argent gratuite (contrat : game/CONTRACTS.md, « Interaction »). setup(stage) puis add_child.
## Ouverture : `interact()` appelé par le HUD (joueur à portée), une seule fois. Verse l'or
## `Balance.capsule_gold(D, stage)` (D figé à l'apparition) × gold_mult, en jaillissement de pièces
## via le PickupManager (groupe `pickups`) ou, sans lui, directement dans RunState.

signal opened(capsule: GoldCapsule)

const SPRITES_PATH := "res://assets/sprites/props/gold_capsule/gold_capsule.tres"
const COIN_COUNT := 8
const BURST_MIN := 28.0
const BURST_MAX := 84.0
const LIGHT_PRESET := &"chest_petit"
const FLASH_PRESET := &"chest_open"
const GOLD_LIGHT := Color(1.0, 0.8, 0.3)

var stage := 1
var gold := 0.0 ## or de base (avant gold_mult)
var _price_d := 1.0
var _player_inside := false
var _opened := false
var _light: LightRig.Handle = null

@onready var _visual: EmissiveOverlay = $Visual


func setup(p_stage: int) -> void:
	stage = p_stage
	_price_d = RunState.difficulty()
	gold = Balance.capsule_gold(_price_d, stage)


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("gold_capsules")
	if gold <= 0.0:
		setup(RunState.stage)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_visual.set_frames(load(SPRITES_PATH) as SpriteFrames)
	_show_state(&"closed")
	_light = LightRig.attach(self, LIGHT_PRESET, {"color": GOLD_LIGHT, "energy": 1.2})


func _show_state(state: StringName) -> void:
	_visual.stop()
	_visual.animation = state
	_visual.frame = 0


func _on_body_entered(b: Node) -> void:
	if b.is_in_group("player"):
		_player_inside = true


func _on_body_exited(b: Node) -> void:
	if b.is_in_group("player"):
		_player_inside = false


## Or réellement crédité à l'ouverture (× gold_mult du joueur).
func expected_gold() -> float:
	var player := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	var mult := 1.0
	if player != null and player.has_method(&"gold_mult"):
		mult = maxf(float(player.call(&"gold_mult")), 0.0)
	return gold * mult


## Ouvre la capsule (une seule fois). Retourne false si déjà ouverte.
func open() -> bool:
	if _opened:
		return false
	_opened = true
	set_deferred(&"monitoring", false)
	if _light != null:
		_light.release()
		_light = null
	_drop_gold()
	Audio.play_ui(&"chest.open.petit")
	Audio.play_coin()
	LightRig.flash(global_position, FLASH_PRESET, 0.6)
	_show_state(&"open")
	# ouverte = éteinte (retour joueur, clarté) : plus de lueur dorée au sommet
	var em := _visual.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as CanvasItem
	if em != null:
		em.visible = false
	opened.emit(self)
	return true


func _drop_gold() -> void:
	var pm := get_tree().get_first_node_in_group(&"pickups")
	if pm != null and pm.has_method(&"drop"):
		# Les pièces portent l'or ; gold_mult est appliqué à leur ramassage par le PickupManager.
		var coin := gold / COIN_COUNT
		var origin := global_position + Vector2(0.0, -30.0)
		for i in COIN_COUNT:
			var a := (float(i) + RunState.rng.randf()) / COIN_COUNT * TAU
			pm.call(&"drop", origin + Vector2.from_angle(a) * RunState.rng.randf_range(BURST_MIN, BURST_MAX), 1, coin)
	else:
		RunState.add_gold(expected_gold())


## Contrat « Interaction » : joueur à portée et capsule pas encore ouverte.
func can_interact() -> bool:
	return _player_inside and not _opened


func is_opened() -> bool:
	return _opened


func interact_label() -> String:
	return "Ouvrir (+%d or)" % int(round(expected_gold()))


## Appelé par le répartiteur unique du HUD (la capsule ne lit plus l'entrée).
func interact() -> bool:
	return open()


func interact_state() -> Dictionary:
	return {"visible": can_interact(), "enabled": true, "label": interact_label(), "hold_s": 0.0}


func interact_priority() -> int:
	return 2
