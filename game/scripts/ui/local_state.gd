class_name LocalState
extends RefCounted
## Accès à l'état du joueur LOCAL pour l'interface (coop 1-4, docs/multi/Archi_Reseau.md §3).
## HUD, barre d'objets, menu pause, infobulles et récap lisent l'or, les objets, le niveau et le personnage de CE
## joueur, jamais ceux d'un autre. En solo (et en coop locale, joueur 1 = local) c'est RunState.local() : comportement
## inchangé. En ligne, le joueur local d'un client est un autre emplacement, d'où ce passage unique par le registre.


## PlayerState du joueur local (jamais null : repli sur le joueur 1).
static func state() -> PlayerState:
	var st := Players.state_of(Players.local_id())
	return st if st != null else RunState.local()


## Emplacement (0-3) du joueur local.
static func slot() -> int:
	return state().slot


## Nœud du joueur local (null si absent).
static func node() -> Node2D:
	return Players.local()


## Vrai si la partie compte plus d'un joueur (UI de coop : plaques alliées, flèches, chiffres filtrés).
static func is_coop() -> bool:
	return Players.count() > 1
