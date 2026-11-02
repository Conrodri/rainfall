class_name PlayerRef
extends RefCounted
## Accès « par joueur » pour le code du joueur, des sorts et des kits (coop 1-4, docs/multi/Archi_Reseau.md §3).
## Un kit, un sort ou un objet posé par un joueur ne lit jamais RunState.gold / .level / .items ni Input
## directement : il passe par ces fonctions avec SON joueur. En solo (joueur 1 seul, inscrit ou non dans Players),
## l'état est RunState.local() et la source d'entrée la source globale : comportement strictement identique.
## Tolère un `player` factice (tests) : sans `player_id`, c'est le joueur 1.


## Emplacement du joueur (0 = joueur 1) ; 0 si `p` n'en porte pas.
static func id_of(p: Object) -> int:
	if p != null and is_instance_valid(p) and &"player_id" in p:
		return int(p.get(&"player_id"))
	return 0


## PlayerState du joueur (or, XP, niveau, objets, compteurs). Jamais null.
static func state_of(p: Object) -> PlayerState:
	return state_for_id(id_of(p))


static func state_for_id(id: int) -> PlayerState:
	var st: PlayerState = Players.state_of(id) if id >= 0 else null
	if st == null:
		st = RunState.player_state(maxi(id, 0)) # pas (encore) inscrit : même emplacement que Players.register
	return st


## Source d'entrée du joueur. Jamais null (repli : source globale, comportement solo).
static func input_of(p: Object) -> InputSource:
	var src: InputSource = Players.input_of(id_of(p))
	if src == null:
		src = _global()
	return src


## Vrai si un signal « jumeau » (Events.*_by) concerne ce joueur : son propre id, ou un auteur inconnu
## (Events.NO_PLAYER : environnement, émetteur pas encore migré) tant que la partie ne compte qu'un joueur.
static func owns(p: Object, event_player_id: int) -> bool:
	if event_player_id == id_of(p):
		return true
	return event_player_id == Events.NO_PLAYER and Players.count() <= 1


## Vrai en coop (plus d'un joueur dans la partie).
static func is_coop() -> bool:
	return Players.count() > 1


static var _global_src: InputSource = null


static func _global() -> InputSource:
	if _global_src == null:
		_global_src = InputSource.global_source()
	return _global_src
