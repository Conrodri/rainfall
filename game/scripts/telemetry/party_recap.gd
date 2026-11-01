class_name PartyRecap
extends RefCounted
## Bilan de fin de run pour 1 à 4 joueurs : n pour l'équilibrage, participation aux rubis, tableau des joueurs
## (récap, journal de run). Fonctions statiques sans état : lisent le registre Players et les PlayerState.
## Solo : n = 1, participation = 1, un seul joueur -> mêmes rubis que Balance.run_rubies historique.
##
## Branchement dans main.gd (réservé à l'orchestrateur) : remplacer
##   Balance.run_rubies(RunState.active_time_s / 60.0, RunState.mode, pillars_done, victory, RunState.gold)
## par
##   PartyRecap.rubies(RunState.active_time_s / 60.0, RunState.mode, pillars_done, victory, LocalState.state().gold)
## et ajouter "players": PartyRecap.summary() ainsi que "party_n" / "participation" (PartyRecap.n(), PartyRecap.participation())
## aux infos du récap (EndRunScreen.info) pour afficher le tableau d'équipe.


## n pour les rubis : joueurs de la partie (chiffre figé au début du dernier étage, absents exclus), au moins 1.
static func n() -> int:
	return maxi(mini(RunState.party_size, Balance.MULTI_MAX_PLAYERS), 1)


## Dégâts infligés par toute l'équipe (somme des PlayerState inscrits).
static func team_damage() -> float:
	var total := 0.0
	for e in Players.entries():
		total += e.state.damage_dealt
	if Players.entries().is_empty():
		total = RunState.local().damage_dealt
	return total


## Participation (0-1) du joueur `slot` aux rubis de fin de run (-1 : le joueur local) ; 1 en solo.
static func participation(slot: int = -1) -> float:
	var st := LocalState.state() if slot < 0 else Players.state_of(slot)
	if st == null:
		return 1.0
	return Balance.ruby_participation(st.damage_dealt, team_damage(), n())


## Rubis de fin de run du joueur `slot` (-1 : le local) : Balance.run_rubies avec n et la participation.
## `gold_left` : bourse du joueur. Solo : identique à Balance.run_rubies(…, 1, 1.0).
static func rubies(active_minutes: float, mode: StringName, pillars_done: int, victory: bool, gold_left: float, slot: int = -1) -> int:
	return Balance.run_rubies(active_minutes, mode, pillars_done, victory, gold_left, n(), participation(slot))


## Une ligne par joueur : {slot, character, level, items, gold, damage, damage_share (0-1), participation, spectating}.
## Solo : une seule ligne (le joueur 1).
static func summary() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var total := maxf(team_damage(), 0.0001)
	var states: Array[PlayerState] = []
	if Players.entries().is_empty():
		states.append(RunState.local())
	else:
		for e in Players.entries():
			states.append(e.state)
	for st in states:
		var count := 0
		for k in st.items:
			count += int(st.items[k])
		out.append({
			"slot": st.slot, "character": String(st.character), "level": st.level, "items": count, "gold": int(st.gold),
			"damage": st.damage_dealt, "damage_share": clampf(st.damage_dealt / total, 0.0, 1.0),
			"participation": Balance.ruby_participation(st.damage_dealt, team_damage(), n()), "spectating": st.spectating,
		})
	return out
