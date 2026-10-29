class_name DodgeButton
extends SpellButton
## Case de l'esquive (action `dodge`) : même rendu qu'une case de sort (cadre, recharge radiale,
## secondes restantes, pastilles de charges). Deux usages comme SpellButton :
##   - bouton tactile (interactive = true) près des sorts : presse l'action `dodge` au toucher et la relâche au
##     lever du doigt (esquive au maintien : Glissade d'Averse ; un tap reste vu par is_action_just_pressed) ;
##   - barre clavier-souris / manette (interactive = false) : indicateur de recharge seul.
## Lit elle-même player.get_dodge_cooldown() (groupe `player`) : le HUD n'a qu'à la placer. Libellé et initiale
## par personnage (`label` de l'état : Roulade, Éclat, Glissade, Levée, Vapeur, Trait, Bond, Râfle, Coulée, Repli, Iaï).
## Icône : assets/sprites/icons/spells/dodge.png (lot G, art/tools/night/_uxhud_icons.txt) ; sans elle, l'initiale.

const DODGE_ICON_ID := &"dodge"
const CHARGE_COLOR := Color(1.0, 0.23, 0.31) ## pastilles de charges (Repli de Vigie)

var _player: Node = null
var _label := ""
var _press_pf := -1 ## image physique du toucher (relâcher différé si trop tôt pour is_action_just_pressed)


func setup(_spell_slot: int, size_px: float = 150.0) -> void:
	super.setup(0, size_px)
	slot = 0
	action = &"dodge"
	set_spell(DODGE_ICON_ID, "Roulade")


func _process(delta: float) -> void:
	super._process(delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
		if _player == null:
			return
	if _player.has_method(&"get_dodge_cooldown"):
		var cd: Dictionary = _player.get_dodge_cooldown()
		set_cooldown(float(cd.get("remaining", 0.0)), float(cd.get("total", 0.0)))
		var lbl := str(cd.get("label", ""))
		if lbl != "" and lbl != _label:
			_label = lbl
			caption = lbl
			queue_redraw()
		var mc := int(cd.get("max_charges", 0))
		set_charges(int(cd.get("charges", -1)) if mc > 1 else -1, mc if mc > 1 else 0, CHARGE_COLOR)
		# esquive interdite (vertige de Rictus, Averse sans eau) : case grisée tant que la cause dure
		var gray := Color(0.45, 0.45, 0.5, 0.8) if bool(cd.get("blocked", false)) else Color.WHITE
		if modulate != gray:
			modulate = gray


## Tactile : l'action reste pressée tant que le doigt est posé (maintien lu par les esquives au maintien) ; le
## relâcher est différé de 2 images s'il suit le toucher de trop près (tap vu par is_action_just_pressed).
func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch == -1:
			_touch = t.index
			_press_t = 0.0
			_press_pos = t.position
			_drifted = false
			_long = false
			_held = true
			_press_pf = Engine.get_physics_frames()
			if InputMap.has_action(action):
				Input.action_press(action)
			queue_redraw()
			accept_event()
			return
		elif not t.pressed and t.index == _touch:
			_touch = -1
			_held = false
			_long = false
			_release_hold()
			queue_redraw()
			accept_event()
			return
	super._gui_input(event)


func _release_hold() -> void:
	if not InputMap.has_action(action):
		return
	if _press_pf >= 0 and Engine.get_physics_frames() < _press_pf + 2:
		_tap_frame = _press_pf # relâché par SpellButton._process deux images après le toucher
		_tap_pframe = Engine.get_process_frames()
	else:
		Input.action_release(action)
	_press_pf = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		if _touch != -1 and InputMap.has_action(action):
			Input.action_release(action)
		_press_pf = -1
	super._notification(what)
