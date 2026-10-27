extends Node
## État de la run en cours (sera sérialisé par la sauvegarde). Seule source de vérité pour
## temps actif, étage, mode, or, XP, niveau et items possédés.

signal gold_changed(gold: float)
signal xp_changed(xp: float, required: float)
signal level_up(level: int)
signal item_added(item_id: StringName, stacks: int)
## Retrait d'objets (mode test : RunState.remove_item / clear_items) : la barre d'objets se reconstruit.
signal items_changed
signal difficulty_changed(D: float, tier_name: StringName)

var mode: StringName = &"moyen"
var stage := 1
var active_time_s := 0.0 ## seulement le jeu actif : pause, coffres et pubs ne comptent pas
var running := false
var gold := 0.0
var xp := 0.0
var level := 1
var items := {} ## item_id (StringName) -> nombre d'exemplaires
var rng := RandomNumberGenerator.new()
var character: StringName = &"ardent" ## personnage choisi à l'écran Nouvelle run
## Sorts choisis pour la run (fiche Nouvelle run) : slot (int 1-4) -> id du sort (base ou variante). Posé par App
## avant main.gd comme `character` (non remis à zéro par start_run) ; lu par CharacterData.for_id ; sauvegardé.
var loadout := {}
## Compteurs génériques de la run (RunState.add_counter) : cumulés au profil en fin de run (Profile.add_stat).
var counters := {}
## Boss tués pendant la run : [{id, floor_boss}] (règles de déblocage `boss_kill` des variantes).
var bosses_killed: Array = []
var kills := 0
var run_seed := 0
var _last_tier: StringName = &""
var floor_start_d := 1.0 ## D au début de l'étage (prix des coffres)
## Remplacé (Alignement RoR2) : monster_gold_budget, réserve d'or des monstres par étage (supprimée).



func start_run(new_mode: StringName = &"moyen", run_seed: int = 0) -> void:
	mode = new_mode
	stage = 1
	active_time_s = 0.0
	gold = 0.0
	xp = 0.0
	level = 1
	items.clear()
	kills = 0
	counters = {}
	bosses_killed = []
	self.run_seed = run_seed if run_seed != 0 else randi()
	rng.seed = self.run_seed
	_last_tier = &""
	running = true
	begin_floor()


## Début d'étage : fige le D de l'étage (prix des coffres).
func begin_floor() -> void:
	floor_start_d = difficulty()


func _ready() -> void:
	begin_floor() # D d'étage valide même sans start_run (tests)
	Events.enemy_killed.connect(func(_e, _p, _t, _el) -> void: if running: kills += 1)
	Events.boss_killed.connect(_on_boss_killed)


## Ajoute `n` au compteur générique `key` de la run (ex. "ardent.eclat_kills") : versé dans Profile.stats en fin
## de run, lu par les règles `{"type": "counter", "key", "value"}` des variantes de sorts.
func add_counter(key: String, n: float = 1.0) -> void:
	if key != "" and n != 0.0:
		counters[key] = float(counters.get(key, 0.0)) + n


func _on_boss_killed(boss: Node2D, is_floor_boss: bool) -> void:
	if not running or boss == null:
		return
	kills += 1 # les boss comptent dans « Monstres tués » (décision du joueur, 26/10/2026)
	var bid := String(boss.call(&"boss_id")) if boss.has_method(&"boss_id") else ""
	if bid != "":
		bosses_killed.append({"id": bid, "floor_boss": is_floor_boss})


## loadout normalisé {slot int -> StringName} depuis une config / sauvegarde (clés texte ou entières).
static func normalize_loadout(d: Variant) -> Dictionary:
	var out := {}
	if d is Dictionary:
		for k in d:
			var slot := int(str(k))
			var id := str(d[k])
			if slot >= 1 and slot <= 4 and id != "":
				out[slot] = StringName(id)
	return out


func _process(delta: float) -> void:
	# get_tree().paused fige ce nœud : le temps actif ne compte pas pendant la pause.
	if not running:
		return
	if TestMode.active and TestMode.freeze_time:
		return # mode test : minuterie arrêtée, la difficulté vient du réglage D
	active_time_s += delta
	var D := difficulty()
	var tier_name := Balance.difficulty_tier_name(D)
	difficulty_changed.emit(D, tier_name)
	if tier_name != _last_tier:
		_last_tier = tier_name
		Events.difficulty_tier_changed.emit(tier_name, D)


func difficulty() -> float:
	if TestMode.active:
		return TestMode.d_value # mode test : D imposée depuis le panneau
	return Balance.difficulty(active_time_s, stage, Balance.MODES[mode])


func add_gold(amount: float) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: float) -> bool:
	if TestMode.inf_gold:
		return true # mode test : or infini, rien n'est débité
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func add_xp(amount: float) -> void:
	xp += amount
	while xp >= Balance.xp_required(level):
		xp -= Balance.xp_required(level)
		level += 1
		level_up.emit(level)
	xp_changed.emit(xp, Balance.xp_required(level))


## Changement d'étage : tout l'or (bourse + `extra_gold`, les pièces restées au sol) devient de l'XP
## au taux Balance.gold_to_xp (D de l'étage qui se termine), puis or = 0. Retourne l'XP gagnée.
func convert_gold_to_xp(extra_gold: float = 0.0) -> float:
	var total := gold + maxf(extra_gold, 0.0)
	var gained := Balance.gold_to_xp(total, difficulty())
	if gold != 0.0:
		gold = 0.0
		gold_changed.emit(gold)
	if gained > 0.0:
		add_xp(gained)
	return gained


func add_item(item_id: StringName) -> void:
	items[item_id] = items.get(item_id, 0) + 1
	item_added.emit(item_id, items[item_id])


## Retire un exemplaire de l'objet (mode test). Retourne faux s'il n'est pas possédé. Le dernier exemplaire retire
## l'entrée. L'appelant recalcule les stats du joueur (Player.apply_stats(ItemStats.compute(items))).
func remove_item(item_id: StringName) -> bool:
	var n: int = items.get(item_id, 0)
	if n <= 0:
		return false
	if n == 1:
		items.erase(item_id)
	else:
		items[item_id] = n - 1
	items_changed.emit()
	return true


## Retire tous les objets (mode test).
func clear_items() -> void:
	items.clear()
	items_changed.emit()


## Items retirés du jeu -> remplaçant pour les anciennes sauvegardes (ramassage automatique, 22/10/2026 :
## plus d'aimant). Aimant de poche (+40 % rayon, +10 % XP) -> Éclat d'expérience (+10 % XP) ;
## Aimant d'âme (rare, tag Or) -> Faveur du marchand (rare, tag Or).
const ITEM_MIGRATION := {&"aimant_de_poche": &"eclat_d_experience", &"aimant_d_ame": &"faveur_du_marchand"}


static func migrate_item_id(item_id: StringName) -> StringName:
	return ITEM_MIGRATION.get(item_id, item_id)


func stacks(item_id: StringName) -> int:
	return items.get(item_id, 0)


## Sauvegarde de run (docs/Design_Menus.md §6.1) : état sérialisable en JSON.
func to_dict() -> Dictionary:
	var it := {}
	for k in items:
		it[String(k)] = items[k]
	return {
		"mode": String(mode), "stage": stage, "active_time_s": active_time_s, "gold": gold, "xp": xp,
		"level": level, "items": it, "kills": kills, "character": String(character),
		"seed": run_seed, "rng_state": str(rng.state),
		"floor_start_d": floor_start_d,
		"loadout": _loadout_dict(), "counters": counters.duplicate(), "bosses_killed": bosses_killed.duplicate(true),
	}


func _loadout_dict() -> Dictionary:
	var out := {}
	for k in loadout:
		out[str(k)] = String(loadout[k])
	return out


func from_dict(d: Dictionary) -> void:
	mode = StringName(d.get("mode", "moyen"))
	stage = int(d.get("stage", 1))
	active_time_s = float(d.get("active_time_s", 0.0))
	gold = float(d.get("gold", 0.0))
	xp = float(d.get("xp", 0.0))
	level = int(d.get("level", 1))
	items.clear()
	var it: Dictionary = d.get("items", {})
	for k in it:
		var mid := migrate_item_id(StringName(k)) # items retirés (aimants) -> remplaçant
		items[mid] = items.get(mid, 0) + int(it[k])
	kills = int(d.get("kills", 0))
	character = StringName(d.get("character", "ardent"))
	run_seed = int(d.get("seed", 0))
	rng.seed = run_seed
	rng.state = int(String(d.get("rng_state", str(rng.state))))
	_last_tier = &""
	floor_start_d = float(d.get("floor_start_d", difficulty()))
	# Ancienne clé "monster_gold_budget" (réserve supprimée) ignorée.
	loadout = normalize_loadout(d.get("loadout", {})) # absente (ancienne sauvegarde) = sorts de base
	counters = (d.get("counters", {}) as Dictionary).duplicate() if d.get("counters") is Dictionary else {}
	bosses_killed = (d.get("bosses_killed", []) as Array).duplicate(true) if d.get("bosses_killed") is Array else []
	running = true
	gold_changed.emit(gold)
	xp_changed.emit(xp, Balance.xp_required(level))

