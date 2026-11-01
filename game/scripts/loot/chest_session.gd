class_name ChestSession
extends RefCounted
## Logique d'une ouverture de coffre (sans UI) : dé, items, relances, choix. RNG = RunState.rng.

const MAX_FREE_REROLLS_PER_CHEST := 1
const MAX_FREE_REROLLS_PER_RUN := 3

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


func _init(p_kind: StringName, p_stage: int, p_price: float, p_rng: RandomNumberGenerator = null) -> void:
	kind = p_kind
	stage = p_stage
	rng = p_rng if p_rng != null else RunState.rng
	# Coffre boss gratuit : les relances à l'or se basent sur le prix d'un grand coffre.
	price = p_price if p_price > 0.0 else Balance.chest_price(&"large", RunState.difficulty(), p_stage)


## Compteur de relances gratuites de la run (méta sur RunState, remis à zéro quand la graine change).
static func run_free_rerolls() -> int:
	var m: Variant = RunState.get_meta("loot_free_rerolls") if RunState.has_meta("loot_free_rerolls") else null
	if typeof(m) == TYPE_DICTIONARY and m.get("seed", 0) == RunState.rng.seed:
		return int(m.get("n", 0))
	return 0


static func _set_run_free_rerolls(n: int) -> void:
	RunState.set_meta("loot_free_rerolls", {"seed": RunState.rng.seed, "n": n})


static func reset_run_counters() -> void:
	_set_run_free_rerolls(0)


## Lance le d100 (Chance = stat `luck` des items possédés) puis tire les 2 items.
func start() -> void:
	var stats := ItemStats.compute(RunState.items)
	var res := LootRoller.roll_quality(kind, rng, roundi(stats.get("luck", 0.0)))
	quality = res["quality"]
	die = res["die"]
	rolls = res.get("rolls", [die])
	_draw_first()


## Premier tirage : garantie de la Boussole si une charge attend (petit ou grand coffre), sinon tirage normal.
## Les relances (`_draw`) tirent toujours normalement.
func _draw_first() -> void:
	if RunState.compass_ready_for(kind):
		var tag := String(RunState.compass.get("tag", ""))
		var pair := LootRoller.pick_pair_tagged(quality, RunState.items, shown, rng, tag)
		if not pair.is_empty():
			offered = pair
			compass_tag = tag
			RunState.compass_consume()
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
	offered = LootRoller.pick_pair(quality, RunState.items, shown, rng)
	for id in offered:
		if not (id in shown):
			shown.append(id)


func gold_reroll_price() -> float:
	if ItemEffects.free_gold_reroll(stage, gold_rerolls): # Faveur du marchand : première relance de l'étage
		return 0.0
	return Balance.gold_reroll_price(price, gold_rerolls)


func can_gold_reroll() -> bool:
	return RunState.gold >= gold_reroll_price()


func do_gold_reroll() -> bool:
	if not RunState.spend_gold(gold_reroll_price()):
		return false
	if ItemEffects.free_gold_reroll(stage, gold_rerolls):
		ItemEffects.consume_free_gold_reroll(stage)
	gold_rerolls += 1
	_draw()
	return true


func can_free_reroll() -> bool:
	return free_rerolls < MAX_FREE_REROLLS_PER_CHEST and run_free_rerolls() < MAX_FREE_REROLLS_PER_RUN


## Relance gratuite (1 par coffre, 3 par run). true si elle a eu lieu.
func do_free_reroll() -> bool:
	if not can_free_reroll():
		return false
	free_rerolls += 1
	_set_run_free_rerolls(run_free_rerolls() + 1)
	_draw()
	return true


## Valide le choix de l'item `index` (0/1) : RunState, signal, stats du joueur.
func choose(tree: SceneTree, index: int) -> void:
	if offered.is_empty():
		return
	var id := StringName(offered[clampi(index, 0, offered.size() - 1)])
	RunState.add_item(id)
	Events.item_chosen.emit(id)
	var player := tree.get_first_node_in_group("player")
	if player != null and player.has_method("apply_stats"):
		player.apply_stats(ItemStats.compute(RunState.items))
