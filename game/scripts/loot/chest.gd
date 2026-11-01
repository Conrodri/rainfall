class_name Chest
extends Area2D
## Coffre de la carte (contrat : game/CONTRACTS.md). setup(kind, stage) puis add_child.
## Ouverture : `interact()` appelé par le répartiteur unique du HUD (aucune lecture d'entrée ici).

signal opened(chest: Chest)
signal refused(chest: Chest) ## or insuffisant (hook pour le son)

const UI_SCENE := preload("res://scenes/ui/chest/chest_ui.tscn")
const SHOWCASE_ICON_PX := 51.2 ## 0,8 u
const SHOWCASE_SPACING_PX := 68.0
const SHOWCASE_Y := -330.0 ## au-dessus de l'étiquette de prix (repère local, avant l'étirement iso)
const SHOWCASE_FRAMES := "res://assets/sprites/chests/chest_small_vitrine/chest_small_vitrine.tres" ## vitrine : même socle que le petit coffre
const COLORS := {
	&"petit": Color(0.69, 0.54, 0.35),
	&"large": Color(0.29, 0.56, 0.89),
	&"legendaire": Color(1.0, 0.72, 0.11),
	&"boss": Color(0.78, 0.29, 0.87),
	&"guardian": Color(0.3, 0.85, 0.8),
}

## Sprites Blender (closed / open), 1 u = 64 px, pivot aux pieds (offset dans la scène).
const SPRITES := {
	&"petit": {"path": "res://assets/sprites/chests/chest_small/chest_small.tres", "scale": 0.7},
	&"large": {"path": "res://assets/sprites/chests/chest_large/chest_large.tres", "scale": 0.8},
	&"legendaire": {"path": "res://assets/sprites/chests/chest_legendary/chest_legendary.tres", "scale": 0.9},
	&"boss": {"path": "res://assets/sprites/chests/chest_legendary/chest_legendary.tres", "scale": 0.95},
	&"guardian": {"path": "res://assets/sprites/chests/chest_large/chest_large.tres", "scale": 0.85}, # reliquaire : grand coffre teinté
}

var kind: StringName = &"petit"
## Variante : &"showcase" = coffre à vitrine (3 objets visibles, on en choisit 1, prix x CHEST_SHOWCASE_PRICE_P) ; &"" = normal.
var variant: StringName = &""
var offer: Array = [] ## vitrine : ids des objets visibles, tirés à l'apparition (graine propre, voir StageManager)
var offer_quality: StringName = &"commun"
var _showcase_root: Node2D = null
var _frames_src: SpriteFrames = null
var stage := 1
var price := 0.0
## Coop : coffre réservé à un joueur (coffres de boss et reliquaires, un par joueur). -1 = coffre ordinaire (ouvert par qui
## paie). Le propriétaire est seul à pouvoir l'ouvrir tant qu'il est vivant ; s'il est spectateur, un allié l'ouvre pour lui
## et l'objet va au propriétaire.
var reserved_slot := -1
## Difficulté figée à l'apparition (début d'étage) : le prix ne monte plus avec le temps, seulement d'un étage à l'autre.
var _price_d := 1.0
var _player_inside := false
var _inside: Array = [] ## joueurs dans la zone (coop) ; _player_inside en est le reflet
var _opening := false
var _refresh := 0.0
var _light: LightRig.Handle = null
var _label_shake := 0.0 ## décalage horizontal de l'animation de refus (tween)
var _label_home := Vector2.ZERO ## position d'origine de l'étiquette de prix (scène)

@onready var _visual: EmissiveOverlay = $Visual
@onready var _label: Label = $PriceLabel


## `p_extra` : entrée de disposition du coffre (StageManager) : {"special": "showcase", "offer": [ids], "quality": q}.
func setup(p_kind: StringName, p_stage: int, p_extra: Dictionary = {}) -> void:
	kind = p_kind
	stage = p_stage
	_price_d = RunState.difficulty()
	variant = &""
	offer = []
	reserved_slot = int(p_extra.get("reserved_slot", reserved_slot))
	if StringName(String(p_extra.get("special", ""))) == &"showcase" and p_kind == &"petit":
		offer = (p_extra.get("offer", []) as Array).map(func(v): return str(v))
		offer_quality = StringName(String(p_extra.get("quality", "commun")))
		if not offer.is_empty():
			variant = &"showcase"
	if is_node_ready():
		_refresh_visual()
		_update_light()
		_refresh_showcase()


func _ready() -> void:
	_label_home = _label.position
	add_to_group("chests")
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_visual()
	_update_light()
	_refresh_showcase()


func is_showcase() -> bool:
	return variant == &"showcase" and not offer.is_empty()


## Vitrine : les objets flottent au-dessus du coffre (icônes d'objets existantes, 0,8 u, en éventail sans recouvrement).
func _refresh_showcase() -> void:
	if _showcase_root != null:
		_showcase_root.queue_free()
		_showcase_root = null
	if not is_showcase():
		return
	_showcase_root = Node2D.new()
	_showcase_root.name = &"Showcase"
	add_child(_showcase_root)
	var n := offer.size()
	for i in n:
		var id: String = offer[i]
		var tex := load(ChestUI.ITEM_ICON % id) as Texture2D if ResourceLoader.exists(ChestUI.ITEM_ICON % id) else null
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		var k: float = SHOWCASE_ICON_PX / float(tex.get_width())
		s.scale = Iso.UNSQUASH * k # billboard : l'icône reste carrée à l'écran
		var t := float(i) - float(n - 1) * 0.5
		s.position = Vector2(t * SHOWCASE_SPACING_PX, SHOWCASE_Y - absf(t) * 14.0)
		_showcase_root.add_child(s)
	_visual.modulate = Color(0.8, 0.95, 1.0) # vitre : teinte froide sur le sprite du petit coffre


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
	return kind == &"boss" or kind == &"guardian"


func current_price() -> float:
	if is_free():
		return 0.0
	return price_of(kind, _price_d, stage) * (Balance.CHEST_SHOWCASE_PRICE_P if is_showcase() else 1.0)


## Prix d'un coffre ordinaire : base du type, D et étage, Faveur du marchand et Présages (Marché noir / Usure) compris.
## Source unique du « prix d'un coffre » (marchand de l'étage 3 et ateliers s'y réfèrent : y brancher les remises).
static func price_of(p_kind: StringName, d: float, p_stage: int) -> float:
	return Balance.chest_price(p_kind, d, p_stage) * ItemEffects.chest_price_mult() * Omens.chest_price_mult()


func _process(delta: float) -> void:
	if _opening:
		return
	# prix accroché au-dessus du coffre (texte du monde : ne glisse jamais vers le bord de l'écran ni sur le HUD)
	_label.position = _label_home + Vector2(_label_shake, 0.0)
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_refresh_price()


func _refresh_visual() -> void:
	var cfg: Dictionary = SPRITES.get(kind, SPRITES[&"petit"])
	var frames_path: String = cfg["path"]
	if variant == &"showcase" and ResourceLoader.exists(SHOWCASE_FRAMES): # dôme de verre fêlé (lot Codex), sinon petit coffre
		frames_path = SHOWCASE_FRAMES
	var frames := load(frames_path) as SpriteFrames
	if frames != _frames_src:
		_frames_src = frames
		_visual.set_frames(frames)
	_visual.scale = Iso.UNSQUASH * float(cfg["scale"]) # billboard (sprite ancien, 64 px/u)
	# le coffre de boss reprend la teinte violette du placeholder
	_visual.modulate = Color.WHITE if not (kind == &"boss" or kind == &"guardian") else Color(1, 1, 1).lerp(COLORS[kind], 0.55)
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
		_label.modulate = COLORS[kind].lightened(0.4)
	else:
		var missing := missing_gold()
		# trop cher : le manque est écrit (SC 1.4.1, pas la couleur seule)
		# une seule ligne : « Il manque N or » est déjà écrit dans l'invite d'interaction (2 lignes en 32 px masquaient le coffre)
		_label.text = "%d or" % int(ceil(price)) if missing <= 0 else "%d or (-%d)" % [int(ceil(price)), missing]
		_label.modulate = Color(1, 0.9, 0.4) if missing <= 0 else Color(1, 0.45, 0.4)


func _on_body_entered(b: Node) -> void:
	CoopRules.track_enter(_inside, b)
	_player_inside = not _inside.is_empty()


func _on_body_exited(b: Node) -> void:
	CoopRules.track_exit(_inside, b)
	_player_inside = not _inside.is_empty()


## Joueur qui agit : `who` si fourni (répartiteur d'interaction par joueur), sinon le plus proche dans la zone.
func _actor(who: Node = null) -> Node2D:
	if who is Node2D and is_instance_valid(who):
		return who as Node2D
	var n := CoopRules.nearest_in(_inside, global_position)
	return n if n != null else CoopRules.actor_for(null, global_position)


## Bourse qui paie (celle de l'acteur).
func _payer_state(who: Node = null) -> PlayerState:
	return CoopRules.state_of(_actor(who))


## Joueur à qui l'objet est destiné : le propriétaire d'un coffre réservé, sinon celui qui paie.
func _beneficiary_state(who: Node = null) -> PlayerState:
	if reserved_slot >= 0:
		var st := Players.state_of(reserved_slot)
		if st != null:
			return st
	return _payer_state(who)


## Faux si ce coffre réservé revient à un autre joueur encore vivant (il ne peut pas l'ouvrir à sa place).
func _may_open(actor: Node) -> bool:
	if reserved_slot < 0:
		return true
	if Players.id_of(actor) == reserved_slot:
		return true
	return not Players.is_alive(reserved_slot) # propriétaire spectateur : un allié l'ouvre pour lui


## Dépense l'or (sauf boss) puis lance l'UI. Retourne false si fonds insuffisants ou coffre d'un autre joueur.
## `who` : joueur qui ouvre (null = le plus proche dans la zone, le joueur local en solo).
func try_open(who: Node = null) -> bool:
	if _opening:
		return false
	var actor := _actor(who)
	if not _may_open(actor):
		_shake_label()
		refused.emit(self)
		return false
	price = current_price()
	if not is_free() and not _payer_state(actor).spend_gold(price):
		_shake_label()
		refused.emit(self)
		return false
	ChestSession.pending_state = _beneficiary_state(actor) # lu par ChestSession._init (ChestUI / ShowcaseUI)
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
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	if is_showcase():
		var sui := ShowcaseUI.new()
		host.add_child(sui)
		sui.finished.connect(_on_ui_finished)
		sui.set_meta(&"owner_slot", _beneficiary_state(actor).slot)
		sui.open_pick(stage, price, offer, offer_quality, self)
		ChestSession.pending_state = null
		opened.emit(self)
		return true
	var ui := UI_SCENE.instantiate()
	host.add_child(ui)
	ui.finished.connect(_on_ui_finished)
	ui.set_meta(&"owner_slot", _beneficiary_state(actor).slot) # coop : joueur à qui revient l'objet (pour l'overlay UI)
	ui.open(kind, stage, price, self)
	ChestSession.pending_state = null
	opened.emit(self)
	return true


func _shake_label() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_label_shake", 10.0, 0.04)
	tw.tween_property(self, "_label_shake", -10.0, 0.08)
	tw.tween_property(self, "_label_shake", 0.0, 0.04)


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
		if reserved_slot >= 0 and Players.count() > 1:
			return "Ouvrir (coffre du joueur %d)" % (reserved_slot + 1)
		return "Ouvrir"
	return ("Vitrine — %d or" if is_showcase() else "Ouvrir — %d or") % int(ceil(current_price()))


## Contrat « Interaction » : l'unique répartiteur (HUD) appelle interact() sur la cible affichée par l'invite.
## `who` : joueur qui interagit (répartiteur par joueur de la coop locale) ; null = le plus proche dans la zone.
func interact(who: Node = null) -> bool:
	return try_open(who)


## Or manquant (0 si le coffre est gratuit ou payable) pour `who` (null = joueur le plus proche dans la zone).
func missing_gold(who: Node = null) -> int:
	if is_free():
		return 0
	return maxi(int(ceil(current_price() - _payer_state(who).gold)), 0)


## Etat de l'invite : refus d'achat écrit en toutes lettres (pas seulement une couleur). Reste « enabled » :
## l'appui déclenche le refus (secousse + signal `refused`).
func interact_state() -> Dictionary:
	var missing := missing_gold()
	var txt := interact_label() if missing <= 0 else "Il manque %d or" % missing
	var enabled := true
	if reserved_slot >= 0 and not _may_open(_actor()):
		txt = "Coffre du joueur %d" % (reserved_slot + 1)
		enabled = false
	return {"visible": can_interact(), "enabled": enabled, "label": txt, "hold_s": 0.0}


func interact_priority() -> int:
	return 3
