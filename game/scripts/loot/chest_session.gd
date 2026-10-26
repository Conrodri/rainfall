class_name ChestSession
extends RefCounted
## Logique d'une ouverture de coffre (sans UI) : dé, items, relances, choix. RNG = RunState.rng.

const MAX_AD_REROLLS_PER_CHEST := 1
const MAX_AD_REROLLS_PER_RUN := 3

var kind: StringName
var stage: int
var price: float ## prix de référence des relances à l'or
var quality: StringName = &"commun"
var die := 0
var offered: Array = [] ## 2 ids (String)
var shown: Array = [] ## tous les ids déjà montrés pour ce coffre
var gold_rerolls := 0
var ad_rerolls := 0
var rng: RandomNumberGenerator


func _init(p_kind: StringName, p_stage: int, p_price: float, p_rng: RandomNumberGenerator = null) -> void:
	kind = p_kind
	stage = p_stage
	rng = p_rng if p_rng != null else RunState.rng
	# Coffre boss gratuit : les relances à l'or se basent sur le prix d'un grand coffre.
	price = p_price if p_price > 0.0 else Balance.chest_price(&"large", RunState.difficulty(), p_stage)


## Compteur de relances pub de la run (méta sur RunState, remis à zéro quand la graine change).
static func run_ad_rerolls() -> int:
	var m: Variant = RunState.get_meta("loot_ad_rerolls") if RunState.has_meta("loot_ad_rerolls") else null
	if typeof(m) == TYPE_DICTIONARY and m.get("seed", 0) == RunState.rng.seed:
		return int(m.get("n", 0))
	return 0


static func _set_run_ad_rerolls(n: int) -> void:
	RunState.set_meta("loot_ad_rerolls", {"seed": RunState.rng.seed, "n": n})


static func reset_run_counters() -> void:
	_set_run_ad_rerolls(0)


## Lance le d100 (Chance = stat `luck` des items possédés) puis tire les 2 items.
func start() -> void:
	var stats := ItemStats.compute(RunState.items)
	var res := LootRoller.roll_quality(kind, rng, roundi(stats.get("luck", 0.0)))
	quality = res["quality"]
	die = res["die"]
	_apply_de_pipe()
	_draw()


## Dé pipé : le premier petit coffre de chaque étage est au moins Peu commun (étage retenu dans RunState.counters,
## donc sauvegardé avec la run).
func _apply_de_pipe() -> void:
	if kind != &"petit" or RunState.stacks(&"de_pipe") <= 0 or int(RunState.counters.get("de_pipe_stage", 0)) == stage:
		return
	RunState.counters["de_pipe_stage"] = stage
	var min_q := StringName(str(ItemEffects.data_of(&"de_pipe").get("min_quality", "peu_commun")))
	if LootRoller.quality_rank(quality) < LootRoller.quality_rank(min_q):
		quality = min_q
		die = LootRoller.die_range(kind, min_q).x


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


func can_ad_reroll() -> bool:
	return ad_rerolls < MAX_AD_REROLLS_PER_CHEST and run_ad_rerolls() < MAX_AD_REROLLS_PER_RUN and AdHook.is_available()


## true si la relance a eu lieu (pub affichée sauf relance gratuite : AdHook.is_free()).
func do_ad_reroll() -> bool:
	if not can_ad_reroll():
		return false
	var ok := true
	if not AdHook.is_free():
		var res := {"ok": false}
		AdHook.show_rewarded(func(success: bool): res["ok"] = success)
		ok = res["ok"]
	if not ok:
		return false
	ad_rerolls += 1
	_set_run_ad_rerolls(run_ad_rerolls() + 1)
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
