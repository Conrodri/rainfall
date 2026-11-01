class_name Omens
extends RefCounted
## Présages d'étage (docs/Ateliers_Chiffres.md §9, docs/Propositions_Boucle_Interactions.md §3.1).
## À l'arrivée sur les étages 2 à 5, le joueur choisit un mutateur (contrainte + compensation) actif jusqu'au téléporteur.
## Ce fichier : données (data/omens.json), plan d'une run (cartes proposées par étage, depuis la graine de run, sans toucher
## à RunState.rng), et lecteurs d'effets (multiplicateurs lus par le Director, Enemy, Player, SpellCaster, coffres, capsules).
## Le présage actif vit dans RunState.omen ; les constantes communes dans Balance (bloc « Présages »).
## Aucun présage ne crée de projectile ni d'effet par monstre ; les lecteurs sont des accès à un Dictionary en cache.

const DATA_PATH := "res://data/omens.json"
const ICON_DIR := "res://assets/sprites/icons/omens/" ## icônes Codex (art/tools/ui/_presages.txt), prioritaires si présentes
const ITEM_ICON_DIR := "res://assets/sprites/icons/items/" ## repli : icônes d'objets proches
const GROUPS: Array[StringName] = [&"combat", &"butin"]
const GROUP_NAMES := {&"combat": "COMBAT", &"butin": "BUTIN"}

static var _db: Dictionary = {} ## id (String) -> entrée normalisée
static var _order: Array[String] = []
static var _clear: Dictionary = {}
static var _loaded := false
static var _fx_id: StringName = &"?"
static var _fx_stage := -1
static var _fx: Dictionary = {}
static var _icon_cache := {}


# --- Données ---------------------------------------------------------------------------------

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	if not (parsed is Dictionary):
		push_warning("Omens : %s illisible." % DATA_PATH)
		return
	for o in (parsed as Dictionary).get("omens", []):
		if not (o is Dictionary):
			continue
		var e := _normalize(o)
		_db[e["id"]] = e
		_order.append(e["id"])
	var c: Variant = (parsed as Dictionary).get("clear", {})
	_clear = _normalize(c if c is Dictionary else {})
	if _clear["id"] == "":
		_clear["id"] = String(Balance.OMEN_CLEAR_ID)
		_clear["name"] = "Ciel clair"


static func _normalize(o: Dictionary) -> Dictionary:
	var floors: Array[int] = []
	for f in o.get("floors", []):
		floors.append(int(f))
	var by_floor := {}
	var src: Variant = o.get("effects_by_floor", {})
	if src is Dictionary:
		for k in src:
			by_floor[int(str(k))] = _fix_effects(src[k])
	return {
		"id": str(o.get("id", "")), "name": str(o.get("name", "")), "group": StringName(str(o.get("group", ""))),
		"floors": floors, "text": str(o.get("text", "")), "icon": str(o.get("icon", "")),
		"effects": _fix_effects(o.get("effects", {})), "effects_by_floor": by_floor,
	}


## Effets normalisés : `monster_hp_tiers` en entiers, le reste tel quel.
static func _fix_effects(src: Variant) -> Dictionary:
	var out := {}
	if not (src is Dictionary):
		return out
	for k in src:
		var v: Variant = src[k]
		if str(k) == "monster_hp_tiers" and v is Array:
			var tiers: Array[int] = []
			for t in v:
				tiers.append(int(t))
			v = tiers
		out[str(k)] = v
	return out


## Tous les présages (hors « Ciel clair »), dans l'ordre du fichier.
static func all() -> Array[Dictionary]:
	_load()
	var out: Array[Dictionary] = []
	for id in _order:
		out.append(_db[id])
	return out


## Entrée d'un présage (ou de « Ciel clair »), {} si inconnu / vide.
static func get_omen(id: StringName) -> Dictionary:
	_load()
	if id == &"":
		return {}
	if str(id) == str(_clear.get("id", "")):
		return _clear
	return _db.get(str(id), {})


static func omen_name(id: StringName) -> String:
	return str(get_omen(id).get("name", ""))


## Vrai si cet étage de run a un écran de présage (2 à 5).
static func floor_has_omen(stage: int) -> bool:
	return stage >= Balance.OMEN_FROM_FLOOR and stage <= Balance.OMEN_LAST_FLOOR


## Vrai si ce présage peut être proposé à cet étage.
static func allowed_on(id: StringName, stage: int) -> bool:
	var e := get_omen(id)
	return not e.is_empty() and id != Balance.OMEN_CLEAR_ID and (e["floors"] as Array).has(stage)


# --- Plan de run (déterministe) -------------------------------------------------------------------

## Cartes proposées sur toute la run : {étage -> {&"combat": id, &"butin": id}}. Fonction pure de la graine de run, sans
## RunState.rng (la reprise de sauvegarde reste identique) : deux joueurs de la même graine (défi du jour) voient les
## mêmes cartes. Un présage proposé à un étage n'est plus proposé ensuite (donc jamais choisi deux fois) ; les étages
## les plus contraints (le moins de candidats) sont tirés d'abord, pour que chaque groupe tienne sur les 4 étages.
static func plan(run_seed: int) -> Dictionary:
	_load()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("omens:%d" % run_seed)
	var out := {}
	for stage in range(Balance.OMEN_FROM_FLOOR, Balance.OMEN_LAST_FLOOR + 1):
		out[stage] = {}
	for g in GROUPS:
		var floors: Array[int] = []
		for stage in range(Balance.OMEN_FROM_FLOOR, Balance.OMEN_LAST_FLOOR + 1):
			floors.append(stage)
		floors.sort_custom(func(a: int, b: int) -> bool:
			var ca := _candidates(g, a).size()
			var cb := _candidates(g, b).size()
			return ca < cb or (ca == cb and a < b))
		var used: Array[String] = []
		for stage in floors:
			var pool: Array[String] = []
			for id in _candidates(g, stage):
				if not used.has(id):
					pool.append(id)
			if pool.is_empty(): # ne devrait pas arriver avec les données livrées : repli sans exclusion
				pool = _candidates(g, stage)
			if pool.is_empty():
				continue
			var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
			used.append(pick)
			(out[stage] as Dictionary)[g] = pick
	return out


static func _candidates(group: StringName, stage: int) -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		var e: Dictionary = _db[id]
		if e["group"] == group and (e["floors"] as Array).has(stage):
			out.append(id)
	return out


## Cartes de l'écran d'arrivée : présage de combat, présage de butin, puis « Ciel clair » hors Difficile.
## Retourne des entrées get_omen() (vide si cet étage n'a pas de présage).
static func offer(stage: int, run_seed: int, mode: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not floor_has_omen(stage):
		return out
	var p: Dictionary = (plan(run_seed) as Dictionary).get(stage, {})
	for g in GROUPS:
		if p.has(g):
			out.append(get_omen(StringName(p[g])))
	if not Balance.omen_mandatory(mode):
		out.append(get_omen(Balance.OMEN_CLEAR_ID))
	return out


# --- Présage actif -----------------------------------------------------------------------------------

## Effets du présage actif à l'étage courant (Dictionary vide = aucun). Mis en cache : appel bon marché.
static func effects() -> Dictionary:
	var id: StringName = RunState.omen
	if id == _fx_id and RunState.stage == _fx_stage:
		return _fx
	_load()
	_fx_id = id
	_fx_stage = RunState.stage
	_fx = {}
	var e: Dictionary = _db.get(str(id), {})
	if not e.is_empty():
		_fx = (e["effects"] as Dictionary).duplicate()
		var over: Dictionary = (e["effects_by_floor"] as Dictionary).get(RunState.stage, {})
		_fx.merge(over, true)
	return _fx


static func is_active() -> bool:
	return RunState.omen != &"" and RunState.omen != Balance.OMEN_CLEAR_ID


static func _f(key: String) -> float:
	return float(effects().get(key, 1.0))


static func monster_damage_mult() -> float: ## Enemy / Player.take_damage : dégâts des monstres et boss
	return _f("monster_damage_mult")


static func player_damage_mult() -> float: ## Player.apply_stats : dégâts infligés (facteur de damage_mult)
	return _f("player_damage_mult")


static func player_max_hp_mult() -> float: ## Player._recompute : PV max
	return _f("player_max_hp_mult")


static func player_damage_taken_mult() -> float: ## Player.take_damage : dégâts subis
	return _f("player_damage_taken_mult")


## Produit des multiplicateurs appliqués aux coups reçus (monstres/boss × dégâts subis), avant le plafond de coup.
static func damage_taken_total_mult() -> float:
	return monster_damage_mult() * player_damage_taken_mult()


static func cooldown_mult() -> float: ## Player.apply_stats : recharges (plancher COOLDOWN_FLOOR appliqué par l'appelant)
	return _f("cooldown_mult")


static func elite_boss_damage_mult() -> float: ## SpellCaster.compute_damage : élites, mini-boss, boss
	return _f("elite_boss_damage_mult")


static func chest_price_mult() -> float: ## Chest.current_price, relance à l'or (via le prix), Enclume (ateliers)
	return _f("chest_price_mult")


static func capsule_gold_mult() -> float: ## GoldCapsule
	return _f("capsule_gold_mult")


static func kill_gold_mult() -> float: ## PickupManager (primes des monstres, pas des boss)
	return _f("kill_gold_mult")


static func director_credit_mult() -> float: ## Director : crédits par seconde
	return _f("director_credit_mult")


## Coffre de boss de base posé à la fin de l'étage (faux avec Usure).
static func boss_chest_enabled() -> bool:
	return bool(effects().get("boss_chest", true))


## Table du coffre gratuit posé à l'arrivée (&"guardian" avec Offrande), &"" sinon.
static func arrival_chest() -> StringName:
	return StringName(str(effects().get("arrival_chest", "")))


## PV des monstres à l'apparition : facteur selon le tier (essaim 1, tireur / bondisseur 2, brute 3) et l'élite.
static func monster_hp_mult(tier: int, elite: bool) -> float:
	var fx := effects()
	if fx.is_empty() or not fx.has("monster_hp_mult"):
		return 1.0
	var m := float(fx["monster_hp_mult"])
	if elite and bool(fx.get("monster_hp_elites", false)):
		return m
	var tiers: Variant = fx.get("monster_hp_tiers", [])
	return m if tiers is Array and (tiers as Array).has(tier) else 1.0


## Chance d'élite : celle de Balance × `elite_chance_mult`, plafonnée à OMEN_ELITE_CHANCE_CAP (jamais sous la valeur de base).
static func elite_chance(D: float) -> float:
	var base := Balance.elite_chance(D)
	var m := _f("elite_chance_mult")
	if m == 1.0:
		return base
	return maxf(base, minf(base * m, Balance.OMEN_ELITE_CHANCE_CAP))


## Chance qu'une vague soit menée par une élite, avec la chance d'élite du présage.
static func wave_leader_chance(D: float) -> float:
	if _f("elite_chance_mult") == 1.0:
		return Balance.wave_leader_chance(D)
	return clampf(Balance.WAVE_LEADER_BASE + 2.0 * elite_chance(D), 0.0, Balance.WAVE_LEADER_MAX)


## Recharge des stats du joueur : applique damage_mult (Pluie de cendres) et cooldown_mult (Fièvre) sur une copie de stats.
## Sans présage actif, `stats` est rendu intact.
static func adjust_player_stats(stats: Dictionary) -> void:
	var dm := player_damage_mult()
	if dm != 1.0:
		var cur := float(stats.get("damage_mult", 0.0))
		stats["damage_mult"] = (cur if cur > 0.0 else 1.0) * dm
	var cm := cooldown_mult()
	if cm != 1.0:
		var base := float(stats.get("cooldown_mult", 0.0))
		stats["cooldown_mult"] = maxf((base if base > 0.0 else 1.0) * cm, Balance.COOLDOWN_FLOOR)


# --- Présentation -------------------------------------------------------------------------------------

## Icône d'un présage : lot Codex (icons/omens/<id>.png) sinon icône d'objet proche (champ `icon`), sinon null.
static func icon_of(id: StringName) -> Texture2D:
	var key := str(id)
	if _icon_cache.has(key):
		return _icon_cache[key]
	var tex: Texture2D = null
	for path in [ICON_DIR + key + ".png", ITEM_ICON_DIR + str(get_omen(id).get("icon", "")) + ".png"]:
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			break
	_icon_cache[key] = tex
	return tex


## Texte court de l'infobulle du HUD : « Nom — effet ».
static func tooltip(id: StringName) -> String:
	var e := get_omen(id)
	if e.is_empty():
		return ""
	return "%s\n%s" % [e["name"], e["text"]]


## Présages acceptés dans la run (hors « Ciel clair »), pour les rubis.
static func accepted_count(taken: Dictionary) -> int:
	var n := 0
	for st in taken:
		if str(taken[st]) != "" and str(taken[st]) != str(Balance.OMEN_CLEAR_ID):
			n += 1
	return n
