class_name OverlayMode
extends RefCounted
## Compteur d'overlays NON BLOQUANTS ouverts (coop : choix d'objet « sacoche », vitrine, Boussole, ateliers).
## En coop le jeu ne s'arrête jamais (ChestSession.is_blocking() faux) : pendant qu'un overlay est ouvert, le joueur
## continue de bouger ; ses sorts 2-4 doivent alors passer en ciblage automatique (la souris sert aux cartes).
## Lecture pour le lanceur de sorts : `if OverlayMode.is_open(): viser automatiquement`. Solo : toujours faux (l'arbre
## est en pause pendant les écrans, rien ne tourne).

static var _open := 0


static func is_open() -> bool:
	return _open > 0


static func enter() -> void:
	_open += 1


static func leave() -> void:
	_open = maxi(_open - 1, 0)


## Tests / changement de scène : remet le compteur à zéro.
static func reset() -> void:
	_open = 0
