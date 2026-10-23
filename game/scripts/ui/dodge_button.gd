class_name DodgeButton
extends SpellButton
## Case de la roulade (action `dodge`) : même rendu qu'une case de sort (cadre, recharge radiale,
## secondes restantes). Deux usages comme SpellButton :
##   - bouton tactile (interactive = true) près des sorts : simule l'action `dodge` ;
##   - barre clavier-souris / manette (interactive = false) : indicateur de recharge seul.
## Lit elle-même player.get_dodge_cooldown() (groupe `player`) : le HUD n'a qu'à la placer.
## Icône : assets/sprites/icons/spells/dodge.png (lot G, art/tools/night/_uxhud_icons.txt) ; sans elle, initiale « R ».
## Le nom reste dans `caption` (jamais dessiné en entier : SpellButton n'affiche que l'initiale).

const DODGE_ICON_ID := &"dodge"

var _player: Node = null


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
		# roulade interdite (Toupie de Rictus) : case grisée tant que la cause dure
		var gray := Color(0.45, 0.45, 0.5, 0.8) if bool(cd.get("blocked", false)) else Color.WHITE
		if modulate != gray:
			modulate = gray
