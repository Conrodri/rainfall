class_name EpreuveVeinSource
extends Node2D
## Source de la Veine (docs/Design_Epreuves.md §3.4) : le prop interactif fixe, au départ du tracé, qui lance l'épreuve
## (« interagir » seulement, jamais au contact). L'épreuve (EpreuveVein) se déplace avec le disque ; la source, elle, reste
## en place : EpreuveVein la recale à chaque pas. Visuel : un seul nœud `Visuel` (losange provisoire), à échanger contre
## les sprites Codex `vein_source_<skin>_{off,on}` sans toucher au reste.

const SIZE_PX := 64.0 ## emprise provisoire 1 u

var epreuve: Node = null ## EpreuveVein propriétaire (non typé : pas de dépendance circulaire de classes)
var tint := Color(0.76, 0.48, 1.0)
var _visual: Polygon2D = null


func _ready() -> void:
	add_to_group(&"interactable")
	_visual = Polygon2D.new()
	_visual.name = &"Visuel"
	var h := SIZE_PX * 0.5
	_visual.polygon = PackedVector2Array([Vector2(0, -h * 1.4), Vector2(h, 0), Vector2(0, h * 0.7), Vector2(-h, 0)])
	add_child(_visual)
	refresh()


## Recale la teinte et l'état visuel (éteinte avant le lancement, allumée ensuite).
func refresh() -> void:
	if _visual == null:
		return
	var idle: bool = epreuve != null and is_instance_valid(epreuve) and epreuve.state == Pillar.STATE_READY
	_visual.color = tint.darkened(0.45) if idle else tint


func _range_px() -> float:
	return Balance.SECRET_LEVER_RANGE_U * Balance.UNIT_PX


func player_near() -> bool:
	return is_inside_tree() and CoopRules.nearest_within(global_position, _range_px()) != null


func can_interact() -> bool:
	return epreuve != null and is_instance_valid(epreuve) and epreuve.state == Pillar.STATE_READY and player_near()


func interact_label() -> String:
	return String(epreuve.call(&"interact_label")) if epreuve != null and is_instance_valid(epreuve) else "Suivre la veine"


func interact_state() -> Dictionary:
	return {"visible": can_interact(), "enabled": true, "label": interact_label(), "hold_s": 0.0}


func interact_priority() -> int:
	return 2


func interact(_who: Node = null) -> bool:
	if not can_interact():
		return false
	var ok: bool = epreuve.call(&"activate")
	refresh()
	return ok
