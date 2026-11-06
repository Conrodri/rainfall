class_name PlayerState
extends RefCounted
## État d'un joueur pendant la run (coop 1-4, docs/multi/Archi_Reseau.md §2 ligne 1, docs/Design_Multijoueur.md §4).
## Ce qui est propre à chaque joueur : bourse, XP et niveau (XP entière à chacun), objets, personnage, sorts choisis,
## compteurs personnels, Boussole de rouille, scories, état spectateur.
## L'état global de la run (étage, temps actif, mode, D, graine, présages, boss tués, kills) reste dans RunState.
## En solo, le joueur 1 est RunState.local() : la façade RunState.gold / .items / ... lit et écrit ce même objet.
##
## Or (décision du joueur, 01/11/2026) : chaque gain d'or est crédité EN ENTIER à chaque joueur de la partie (morts
## compris), multiplié par Balance.coop_gold_mult(n) ; chacun dépense sa bourse comme il veut, aucun transfert.
## Voir RunState.add_party_gold().

signal gold_changed(gold: float)
signal xp_changed(xp: float, required: float)
signal level_up(level: int)
signal item_added(item_id: StringName, stacks: int)
signal items_changed
signal gold_spent(amount: float)
signal scrap_changed
signal catalysts_changed(count: int)

## Emplacement du joueur dans la partie (0 = joueur 1, 1-3 = joueurs 2 à 4). Clé du registre Players.
var slot := 0
var gold := 0.0
var xp := 0.0
var level := 1
var items := {} ## item_id (StringName) -> nombre d'exemplaires
var character: StringName = &"ardent"
## Sorts choisis : slot (int 1-4) -> id du sort (base ou variante). Non remis à zéro par reset() (posé avant la run).
var loadout := {}
## Compteurs génériques du joueur (RunState.add_counter) : cumulés à son profil en fin de run.
var counters := {}
## Boussole de rouille : {tag, charges} (docs/Ateliers_Chiffres.md §7).
var compass := {"tag": "", "charges": 0}
## Scories des ateliers : qualité -> nombre, au plus Balance.SCRAP_CAP au total.
var scrap := {}
## Noyaux d'orage portés (catalyseur de la Forge, docs/Design_Forge.md) : au plus Balance.CRAFT_CATALYST_CAP, par joueur.
var catalysts := 0
## Mort en coop : spectateur jusqu'au début de l'étage suivant (Players.set_spectating / resurrect_all).
var spectating := false
## Dégâts infligés pendant la run (participation aux rubis en multi, Balance.ruby_participation).
var damage_dealt := 0.0


func _init(p_slot: int = 0) -> void:
	slot = p_slot


## Remise à zéro de début de run (personnage et sorts conservés). `start_level` : Balance.player_start_level(n).
func reset(start_level: int = 1) -> void:
	gold = 0.0
	xp = 0.0
	level = maxi(start_level, 1)
	items.clear()
	counters = {}
	compass = {"tag": "", "charges": 0}
	scrap = {}
	catalysts = 0
	spectating = false
	damage_dealt = 0.0


# --- Noyaux d'orage (Forge) -------------------------------------------------------------
## +n noyaux, plafonnés à Balance.CRAFT_CATALYST_CAP. Retourne le nombre réellement ajouté.
func add_catalyst(n: int = 1) -> int:
	var before := catalysts
	catalysts = clampi(catalysts + n, 0, Balance.CRAFT_CATALYST_CAP)
	if catalysts != before:
		catalysts_changed.emit(catalysts)
	return catalysts - before


## Dépense `n` noyaux ; faux s'il n'y en a pas assez (rien n'est débité).
func spend_catalyst(n: int = 1) -> bool:
	if catalysts < n:
		return false
	catalysts -= n
	catalysts_changed.emit(catalysts)
	return true


# --- Or ---------------------------------------------------------------------------------
func add_gold(amount: float) -> void:
	gold += amount
	gold_changed.emit(gold)


## Débite la bourse ; faux si elle ne suffit pas. Or infini du mode test : toujours vrai, rien n'est débité.
func spend_gold(amount: float) -> bool:
	if TestMode.inf_gold:
		return true
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	gold_spent.emit(amount)
	return true


## Fin d'étage : bourse + `extra_gold` -> XP (Balance.gold_to_xp), or = 0. Retourne l'XP gagnée.
func convert_gold_to_xp(extra_gold: float, D: float) -> float:
	var total := gold + maxf(extra_gold, 0.0)
	var gained := Balance.gold_to_xp(total, D)
	if gold != 0.0:
		gold = 0.0
		gold_changed.emit(gold)
	if gained > 0.0:
		add_xp(gained)
	return gained


# --- XP ---------------------------------------------------------------------------------
func add_xp(amount: float) -> void:
	xp += amount
	while xp >= Balance.xp_required(level):
		xp -= Balance.xp_required(level)
		level += 1
		level_up.emit(level)
	xp_changed.emit(xp, Balance.xp_required(level))


# --- Objets -----------------------------------------------------------------------------
func add_item(item_id: StringName) -> void:
	items[item_id] = items.get(item_id, 0) + 1
	item_added.emit(item_id, items[item_id])


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


func clear_items() -> void:
	items.clear()
	items_changed.emit()


func stacks(item_id: StringName) -> int:
	return items.get(item_id, 0)


# --- Compteurs, Boussole, scories -------------------------------------------------------
func add_counter(key: String, n: float = 1.0) -> void:
	if key != "" and n != 0.0:
		counters[key] = float(counters.get(key, 0.0)) + n


func compass_set(tag: String, charges: int = -1) -> void:
	compass = {"tag": tag, "charges": Balance.BOUSSOLE_CHARGES if charges < 0 else charges}


func compass_ready_for(kind: StringName) -> bool:
	return int(compass.get("charges", 0)) > 0 and String(compass.get("tag", "")) != "" and kind in Balance.BOUSSOLE_CHEST_KINDS


func compass_consume() -> void:
	compass["charges"] = maxi(int(compass.get("charges", 0)) - 1, 0)
	if int(compass["charges"]) == 0:
		compass["tag"] = ""


func scrap_of(quality: StringName) -> int:
	return int(scrap.get(quality, 0))


func scrap_total() -> int:
	var n := 0
	for q in scrap:
		n += int(scrap[q])
	return n


func add_scrap(quality: StringName) -> bool:
	if scrap_total() >= Balance.SCRAP_CAP:
		return false
	scrap[quality] = scrap_of(quality) + 1
	scrap_changed.emit()
	return true


func spend_scrap(quality: StringName) -> bool:
	if scrap_of(quality) <= 0:
		return false
	scrap[quality] = scrap_of(quality) - 1
	if scrap_of(quality) <= 0:
		scrap.erase(quality)
	scrap_changed.emit()
	return true


# --- Sauvegarde -------------------------------------------------------------------------
## Champs propres au joueur, mêmes clés que l'ancienne sauvegarde solo (RunState.to_dict les met au premier niveau
## pour le joueur 1 : format solo inchangé).
func to_dict() -> Dictionary:
	var it := {}
	for k in items:
		it[String(k)] = items[k]
	var lo := {}
	for k in loadout:
		lo[str(k)] = String(loadout[k])
	var sc := {}
	for q in scrap:
		if int(scrap[q]) > 0:
			sc[String(q)] = int(scrap[q])
	return {
		"gold": gold, "xp": xp, "level": level, "items": it, "character": String(character),
		"loadout": lo, "counters": counters.duplicate(), "compass": compass.duplicate(), "scrap": sc,
		"spectating": spectating, "damage_dealt": damage_dealt, "catalysts": catalysts,
	}


## Relit les champs du joueur (clés absentes : valeurs neutres, anciennes sauvegardes acceptées).
## `migrate` : Callable(StringName) -> StringName des objets retirés (RunState.migrate_item_id).
func from_dict(d: Dictionary, migrate: Callable = Callable()) -> void:
	gold = float(d.get("gold", 0.0))
	xp = float(d.get("xp", 0.0))
	level = int(d.get("level", 1))
	items.clear()
	var it: Variant = d.get("items", {})
	if it is Dictionary:
		for k in it:
			var mid := StringName(k)
			if migrate.is_valid():
				mid = migrate.call(mid)
			items[mid] = items.get(mid, 0) + int(it[k])
	character = StringName(d.get("character", "ardent"))
	loadout = RunState.normalize_loadout(d.get("loadout", {}))
	counters = (d.get("counters", {}) as Dictionary).duplicate() if d.get("counters") is Dictionary else {}
	var cp: Variant = d.get("compass")
	compass = {"tag": String((cp as Dictionary).get("tag", "")), "charges": int((cp as Dictionary).get("charges", 0))} if cp is Dictionary else {"tag": "", "charges": 0}
	scrap = {}
	var sd: Variant = d.get("scrap", {})
	if sd is Dictionary:
		for q in sd:
			if int(sd[q]) > 0:
				scrap[StringName(q)] = int(sd[q])
	spectating = bool(d.get("spectating", false))
	damage_dealt = float(d.get("damage_dealt", 0.0))
	catalysts = clampi(int(d.get("catalysts", 0)), 0, Balance.CRAFT_CATALYST_CAP)
