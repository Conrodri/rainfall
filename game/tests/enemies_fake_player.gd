extends Node2D
## Faux joueur pour les tests ennemis : groupe `player`, enregistre coups et statuts reçus.

var hp := 100.0
var max_hp := 100.0
var hits := 0
var damage_taken := 0.0
var statuses: Array[StringName] = []
var last_source: Node = null


func _ready() -> void:
	add_to_group(&"player")


func take_damage(amount: float, source: Node = null) -> void:
	hits += 1
	damage_taken += amount
	last_source = source


func apply_status(status: StringName, _data: Dictionary) -> void:
	statuses.append(status)


func heal(_amount: float) -> void:
	pass
