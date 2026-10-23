class_name Chest
extends Area2D
## Coffre de la carte (contrat : game/CONTRACTS.md). setup(kind, stage) puis add_child.
## Ouverture : `interact()` appelé par le répartiteur unique du HUD (aucune lecture d'entrée ici).

signal opened(chest: Chest)
signal refused(chest: Chest) ## or insuffisant (hook pour le son)

const UI_SCENE := preload("res://scenes/ui/chest/chest_ui.tscn")
const COLORS := {
	&"petit": Color(0.69, 0.54, 0.35),
	&"large": Color(0.29, 0.56, 0.89),
	&"legendaire": Color(1.0, 0.72, 0.11),
	&"boss": Color(0.78, 0.29, 0.87),
}

## Sprites Blender (closed / open), 1 u = 64 px, pivot aux pieds (offset dans la scène).
const SPRITES := {
	&"petit": {"path": "res://assets/sprites/chests/chest_small/chest_small.tres", "scale": 0.7},
	&"large": {"path": "res://assets/sprites/chests/chest_large/chest_large.tres", "scale": 0.8},
	&"legendaire": {"path": "res://assets/sprites/chests/chest_legendary/chest_legendary.tres", "scale": 0.9},
	&"boss": {"path": "res://assets/sprites/chests/chest_legendary/chest_legendary.tres", "scale": 0.95},
}

var kind: StringName = &"petit"
var _frames_src: SpriteFrames = null
var stage := 1
var price := 0.0
## Difficulté figée à l'apparition (début d'étage) : le prix ne monte plus avec le temps, seulement d'un étage à l'autre.
var _price_d := 1.0
var _player_inside := false
var _opening := false
var _refresh := 0.0
var _light: LightRig.Handle = null

@onready var _visual: EmissiveOverlay = $Visual
@onready var _label: Label = $PriceLabel


func setup(p_kind: StringName, p_stage: int) -> void:
	kind = p_kind
	stage = p_stage
	_price_d = RunState.difficulty()
	if is_node_ready():
		_refresh_visual()
		_update_light()


func _ready() -> void:
	add_to_group("chests")
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_visual()
	_update_light()


## Lumière du coffre selon sa rareté (preset chest_<kind>), libérée à l'ouverture.
func _update_light() -> void:
	if _opening:
		return
	var preset := StringName("chest_%s" % kind)
	if _light == null:
		_light = LightRig.attach(self, preset)
	else:
		_light.set_preset(preset)


func is_free() -> bool:
	return kind == &"boss"


func current_price() -> float:
	if is_free():
		return 0.0
	return Balance.chest_price(kind, _price_d, stage)


func _process(delta: float) -> void:
	if _opening:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_refresh_price()


func _refresh_visual() -> void:
	var cfg: Dictionary = SPRITES.get(kind, SPRITES[&"petit"])
	var frames := load(cfg["path"]) as SpriteFrames
	if frames != _frames_src:
		_frames_src = frames
		_visual.set_frames(frames)
	_visual.scale = Iso.UNSQUASH * float(cfg["scale"]) # billboard (sprite ancien, 64 px/u)
	# le coffre de boss reprend la teinte violette du placeholder
	_visual.modulate = Color.WHITE if kind != &"boss" else Color(1, 1, 1).lerp(COLORS[&"boss"], 0.55)
	_show_state(&"open" if _opening else &"closed")
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	_refresh_price()


func _show_state(state: StringName) -> void:
	_visual.stop()
	_visual.animation = state
	_visual.frame = 0


func _refresh_price() -> void:
	price = current_price()
	if is_free():
		_label.text = "GRATUIT"
		_label.modulate = COLORS[&"boss"].lightened(0.4)
	else:
		var missing := missing_gold()
		# trop cher : le manque est écrit (SC 1.4.1, pas la couleur seule)
		# une seule ligne : « Il manque N or » est déjà écrit dans l'invite d'interaction (2 lignes en 32 px masquaient le coffre)
		_label.text = "%d or" % int(ceil(price)) if missing <= 0 else "%d or (-%d)" % [int(ceil(price)), missing]
		_label.modulate = Color(1, 0.9, 0.4) if missing <= 0 else Color(1, 0.45, 0.4)


func _on_body_entered(b: Node) -> void:
	if b.is_in_group("player"):
		_player_inside = true


func _on_body_exited(b: Node) -> void:
	if b.is_in_group("player"):
		_player_inside = false


## Dépense l'or (sauf boss) puis lance l'UI. Retourne false si fonds insuffisants.
func try_open() -> bool:
	if _opening:
		return false
	price = current_price()
	if not is_free() and not RunState.spend_gold(price):
		_shake_label()
		refused.emit(self)
		return false
	_opening = true
	if _light != null:
		_light.release()
		_light = null
	LightRig.flash(global_position, &"chest_open", 0.8)
	if kind == &"legendaire":
		var am := AmbianceManager.find(get_tree())
		if am != null:
			am.spawn_rays(global_position, 2, 0.18, 4.0)
	_show_state(&"open")
	set_process(false)
	monitoring = false
	var ui := UI_SCENE.instantiate()
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	host.add_child(ui)
	ui.finished.connect(_on_ui_finished)
	ui.open(kind, stage, price, self)
	opened.emit(self)
	return true


func _shake_label() -> void:
	var tw := create_tween()
	tw.tween_property(_label, "position:x", _label.position.x + 10.0, 0.04)
	tw.tween_property(_label, "position:x", _label.position.x - 10.0, 0.08)
	tw.tween_property(_label, "position:x", _label.position.x, 0.04)


func _on_ui_finished() -> void:
	queue_free()


## Vrai dès que l'ouverture a commencé (or dépensé) : la sauvegarde ne le recrée pas.
func is_opened() -> bool:
	return _opening


## Contrat « Interaction » : vrai si le joueur est à portée et le coffre pas encore ouvert
## (vrai même si l'or manque : le bouton affiche le prix, l'ouverture est alors refusée).
func can_interact() -> bool:
	return _player_inside and not _opening


func interact_label() -> String:
	if is_free():
		return "Ouvrir"
	return "Ouvrir — %d or" % int(ceil(current_price()))


## Contrat « Interaction » : l'unique répartiteur (HUD) appelle interact() sur la cible affichée par l'invite.
func interact() -> bool:
	return try_open()


## Or manquant (0 si le coffre est gratuit ou payable).
func missing_gold() -> int:
	if is_free():
		return 0
	return maxi(int(ceil(current_price() - RunState.gold)), 0)


## Etat de l'invite : refus d'achat écrit en toutes lettres (pas seulement une couleur). Reste « enabled » :
## l'appui déclenche le refus (secousse + signal `refused`).
func interact_state() -> Dictionary:
	var missing := missing_gold()
	var txt := interact_label() if missing <= 0 else "Il manque %d or" % missing
	return {"visible": can_interact(), "enabled": true, "label": txt, "hold_s": 0.0}


func interact_priority() -> int:
	return 3
