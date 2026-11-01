class_name ChestSession
extends RefCounted
## Logique d'une ouverture de coffre (sans UI) : dé, items, relances, choix. RNG = RunState.rng.
##
## Coop (étape 2, lot 3) : la session appartient à UN joueur (`state`, le payeur du coffre) : sa Chance, sa bourse (relance
## à l'or), sa Boussole, ses objets (non proposés en double, objet reçu) et ses relances gratuites (compteur par joueur).
## Aucun transfert d'or. `state` null -> `pending_state` (posé par Chest.try_open juste avant la création de l'UI, pour que
## ChestUI / ShowcaseUI, qui font `ChestSession.new(kind, stage, price)`, n'aient rien à changer), sinon le joueur 1.
##
## PAS DE PAUSE EN COOP : `ChestSession.is_blocking()` dit si l'ouverture d'un coffre (et d'un atelier, d'une vitrine, de la
## boussole) doit mettre l'arbre en pause. Vrai en solo (comportement inchangé), faux dès que la partie compte plusieurs
## joueurs : l'overlay « sacoche » du lot UI ne doit alors JAMAIS appeler get_tree().paused = true.

const MAX_FREE_REROLLS_PER_CHEST := 1
const MAX_FREE_REROLLS_PER_RUN := 3

## Joueur à qui revient la prochaine session créée sans état explicite (consommé par _init). Posé par Chest.try_open.
static var pending_state: PlayerState = null

var kind: StringName
var stage: int
var price: float ## prix de référence des relances à l'or
var quality: StringName = &"commun"
var die := 0
var rolls: Array = [] ## dés de tous les tirages de rareté (1 + Chance) ; `die` = le meilleur
var offered: Array = [] ## 2 ids (String)
var shown: Array = [] ## tous les ids déjà montrés pour ce coffre
var gold_rerolls := 0
var free_rerolls := 0
var rng: RandomNumberGenerator
## Boussole de rouille (docs/Ateliers_Chiffres.md §7) : tag garanti sur la carte A du premier tirage ("" = aucun) ;
## `compass_missed` = tag demandé mais absent de cette qualité (charge conservée, la carte l'écrit).
var compass_tag := ""
var compass_missed := ""
## Joueur propriétaire de la session (payeur du coffre, ou bénéficiaire d'un coffre réservé).
var state: PlayerState


func _init(p_kind: StringName, p_stage: int, p_price: float, p_rng: RandomNumberGenerator = null, p_state: PlayerState = null) -> void:
	kind = p_kind
	stage = p_stage
	rng = p_rng if p_rng != null else RunState.rng
	state = p_state if p_state != null else (pending_state if pending_state != null else RunState.local())
	pending_state = null
	# Coffre boss gratuit : les relances à l'or se basent sur le prix d'un grand coffre.
	price = p_price if p_price > 0.0 else Balance.chest_price(&"large", RunState.difficulty(), p_stage)


## Vrai si l'ouverture d'un coffre / atelier / vitrine / boussole doit mettre le jeu en pause : solo seulement.
## En coop (plusieurs joueurs inscrits) le jeu ne s'arrête jamais (docs/Design_Multijoueur.md §3).
static func is_blocking() -> bool:
	return Players.count() <= 1


## Compteur de relances gratuites de la run pour le joueur `slot` (méta sur RunState, remis à zéro quand la graine change).
## Sans argument : joueur 1 (comportement solo historique).
static func run_free_rerolls(slot: int = 0) -> int:
	var m: Variant = RunState.get_meta("loot_free_rerolls") if RunState.has_meta("loot_free_rerolls") else null
	if typeof(m) == TYPE_DICTIONARY and m.get("seed", 0) == RunState.rng.seed:
		var by: Variant = m.get("by")
		if by is Dictionary:
			return int((by as Dictionary).get(slot, 0))
		return int(m.get("n", 0)) if slot == 0 else 0
	return 0


static func _set_run_free_rerolls(n: int, slot: int = 0) -> void:
	var by := {}
	var m: Variant = RunState.get_meta("loot_free_rerolls") if RunState.has_meta("loot_free_rerolls") else null
	if typeof(m) == TYPE_DICTIONARY and m.get("seed", 0) == RunState.rng.seed and m.get("by") is Dictionary:
		by = (m["by"] as Dictionary).duplicate()
	by[slot] = n
	RunState.set_meta("loot_free_rerolls", {"seed": RunState.rng.seed, "n": int(by.get(0, 0)), "by": by})


static func reset_run_counters() -> void:
	RunState.set_meta("loot_free_rerolls", {"seed": RunState.rng.seed, "n": 0, "by": {}})


## Relances gratuites restantes de CE joueur pour la run (3 - déjà prises) : à afficher à la place du compteur statique.
func run_free_left() -> int:
	return maxi(MAX_FREE_REROLLS_PER_RUN - run_free_rerolls(state.slot), 0)


## Lance le d100 (Chance = stat `luck` des items possédés) puis tire les 2 items.
func start() -> void:
	var stats := ItemStats.compute(state.items)
	var res := LootRoller.roll_quality(kind, rng, roundi(stats.get("luck", 0.0)))
	quality = res["quality"]
	die = res["die"]
	rolls = res.get("rolls", [die])
	_draw_first()


## Premier tirage : garantie de la Boussole si une charge attend (petit ou grand coffre), sinon tirage normal.
## Les relances (`_draw`) tirent toujours normalement.
func _draw_first() -> void:
	if state.compass_ready_for(kind):
		var tag := String(state.compass.get("tag", ""))
		var pair := LootRoller.pick_pair_tagged(quality, state.items, shown, rng, tag)
		if not pair.is_empty():
			offered = pair
			compass_tag = tag
			state.compass_consume()
			for id in offered:
				if not (id in shown):
					shown.append(id)
			return
		compass_missed = tag
	_draw()


## Ligne de la Boussole pour l'écran de coffre ("" si elle n'a pas joué).
func compass_note() -> String:
	if compass_tag != "":
		return "Boussole : %s" % compass_tag
	if compass_missed != "":
		return "Boussole : pas de %s ici (charge gardée)" % compass_missed
	return ""


## Rareté de chaque jet (une roue par jet).
func roll_qualities() -> Array:
	var out: Array = []
	for d in rolls:
		out.append(LootRoller.quality_from_die(kind, int(d)))
	return out


func _draw() -> void:
	offered = LootRoller.pick_pair(quality, state.items, shown, rng)
	for id in offered:
		if not (id in shown):
			shown.append(id)


func gold_reroll_price() -> float:
	if ItemEffects.free_gold_reroll(stage, gold_rerolls): # Faveur du marchand : première relance de l'étage
		return 0.0
	return Balance.gold_reroll_price(price, gold_rerolls)


func can_gold_reroll() -> bool:
	return state.gold >= gold_reroll_price()


func do_gold_reroll() -> bool:
	if not state.spend_gold(gold_reroll_price()):
		return false
	if ItemEffects.free_gold_reroll(stage, gold_rerolls):
		ItemEffects.consume_free_gold_reroll(stage)
	gold_rerolls += 1
	_draw()
	return true


func can_free_reroll() -> bool:
	return free_rerolls < MAX_FREE_REROLLS_PER_CHEST and run_free_rerolls(state.slot) < MAX_FREE_REROLLS_PER_RUN


## Relance gratuite (1 par coffre, 3 par run et par joueur). true si elle a eu lieu.
func do_free_reroll() -> bool:
	if not can_free_reroll():
		return false
	free_rerolls += 1
	_set_run_free_rerolls(run_free_rerolls(state.slot) + 1, state.slot)
	_draw()
	return true


## Valide le choix de l'item `index` (0/1) : PlayerState du propriétaire, signaux, stats de SON joueur.
func choose(tree: SceneTree, index: int) -> void:
	if offered.is_empty():
		return
	var id := StringName(offered[clampi(index, 0, offered.size() - 1)])
	state.add_item(id)
	Events.item_chosen.emit(id)
	Events.item_chosen_by.emit(state.slot, id)
	var player: Node = Players.by_id(state.slot)
	if player == null:
		player = tree.get_first_node_in_group("player")
	if player != null and player.has_method("apply_stats"):
		player.apply_stats(ItemStats.compute(state.items))
