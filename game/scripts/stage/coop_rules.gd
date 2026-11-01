class_name CoopRules
extends RefCounted
## Règles coop de l'étage, de la boucle de butin et des interactables (étape 2, lot 3 ; docs/Design_Multijoueur.md §3-4,
## docs/multi/Design_Coop.md §1.3-1.4 et §2). Aides statiques sans état, partagées par les objets d'étage :
## qui interagit, qui est dans une zone, quel PlayerState paie. En solo (un seul joueur) chaque fonction rend ce que
## faisaient les anciens appels `get_first_node_in_group(&"player")` / `RunState.*`.

## Plancher de la vitesse de charge d'un gros pilier quand au moins un joueur est dans la zone (Design_Coop §1.3).
## À migrer dans Balance (COOP_CHARGE_FLOOR) par l'orchestrateur ; ici faute d'accès à scripts/core.
const CHARGE_FLOOR := 0.25
## Compte à rebours du téléporteur de sortie en coop (s) après le premier « interagir » (Design_Coop §1.4, option C
## sans veto). À migrer dans Balance (COOP_TELEPORT_COUNTDOWN_S).
const TELEPORT_COUNTDOWN_S := 15.0


## Vrai si la partie compte plusieurs joueurs (pas de pause, quotas par joueur, etc.).
static func is_coop() -> bool:
	return Players.count() > 1


## Nombre de joueurs de la partie pour l'équilibrage (figé au début de l'étage, RunState.party_size).
static func party_n() -> int:
	return maxi(RunState.party_size, 1)


## Joueur qui agit : `who` s'il est valide, sinon le joueur vivant le plus proche de `at` (dans `radius_px` si > 0),
## sinon le joueur local. Null seulement sans aucun joueur.
static func actor_for(who: Node, at: Vector2, radius_px: float = 0.0) -> Node2D:
	if who is Node2D and is_instance_valid(who):
		return who as Node2D
	var p := Players.nearest(at, true)
	if p != null and (radius_px <= 0.0 or p.global_position.distance_to(at) <= radius_px):
		return p
	return Players.local()


## PlayerState du joueur porté par `node` (joueur local si inconnu ou null).
static func state_of(node: Node) -> PlayerState:
	if node != null:
		var id := Players.id_of(node)
		if id != Events.NO_PLAYER:
			var st := Players.state_of(id)
			if st != null:
				return st
	return RunState.local()


## Emplacement (0-3) du joueur porté par `node` (0 si inconnu).
static func slot_of(node: Node) -> int:
	return state_of(node).slot


## Un joueur (vivant, ou n'importe lequel si `alive_only` est faux) est à moins de `radius_px` de `at`.
static func any_within(at: Vector2, radius_px: float, alive_only: bool = true) -> bool:
	var list: Array[Node2D] = Players.alive() if alive_only else Players.all()
	for p in list:
		if p.global_position.distance_to(at) <= radius_px:
			return true
	return false


## Nombre de joueurs vivants à moins de `radius_px` de `at`.
static func alive_within(at: Vector2, radius_px: float) -> int:
	var n := 0
	for p in Players.alive():
		if p.global_position.distance_to(at) <= radius_px:
			n += 1
	return n


## Joueur le plus proche de `at` parmi ceux qui sont à moins de `radius_px` (vivants), ou null.
static func nearest_within(at: Vector2, radius_px: float) -> Node2D:
	var p := Players.nearest(at, true)
	if p != null and p.global_position.distance_to(at) <= radius_px:
		return p
	return null


## Suivi d'un ensemble de joueurs dans une zone Area2D (corps entrés) : à appeler depuis body_entered / body_exited.
static func track_enter(list: Array, b: Node) -> void:
	if b.is_in_group(&"player") and not list.has(b):
		list.append(b)


static func track_exit(list: Array, b: Node) -> void:
	list.erase(b)


## Retire de la liste les corps libérés (à appeler avant de lire la liste).
static func prune(list: Array) -> void:
	var i := list.size() - 1
	while i >= 0:
		if not is_instance_valid(list[i]):
			list.remove_at(i)
		i -= 1


## Vrai si au moins un joueur VIVANT de la liste est dans la zone.
static func any_alive_in(list: Array) -> bool:
	prune(list)
	for b in list:
		var id := Players.id_of(b)
		if id != Events.NO_PLAYER and not Players.is_alive(id):
			continue
		return true
	return false


## Joueur de la liste le plus proche de `at` (vivant de préférence), ou null.
static func nearest_in(list: Array, at: Vector2) -> Node2D:
	prune(list)
	var best: Node2D = null
	var best_d := INF
	for b in list:
		var n := b as Node2D
		if n == null:
			continue
		var id := Players.id_of(n)
		if id != Events.NO_PLAYER and not Players.is_alive(id):
			continue
		var d := n.global_position.distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = n
	return best


## Multiplicateur propre à un joueur (méthode `gold_mult()` / `xp_mult()` de son nœud, 1 + bonus) ; 1 si absente.
static func mult_of(node: Node, key: StringName) -> float:
	if node != null and is_instance_valid(node) and node.has_method(key):
		return maxf(float(node.call(key)), 0.0)
	return 1.0


## Crédite `base` or à CHAQUE joueur de la partie, morts compris (bourses individuelles, jamais de partage ni de transfert) :
## base × Balance.coop_gold_mult(n) × gold_mult() du joueur (les bonus d'or d'un objet ou d'un kit reviennent à son
## propriétaire). Solo : RunState.add_party_gold(base × gold_mult du joueur 1), identique à l'ancien add_gold.
static func credit_party_gold(base: float, apply_mult: bool = true) -> void:
	if base <= 0.0:
		return
	if Players.count() <= 1:
		RunState.add_party_gold(base * (mult_of(Players.local(), &"gold_mult") if apply_mult else 1.0))
		return
	var k := Balance.coop_gold_mult(Players.count())
	for e in Players.entries():
		e.state.add_gold(base * k * (mult_of(e.node, &"gold_mult") if apply_mult else 1.0))
