extends Node
## État de la run en cours (sera sérialisé par la sauvegarde). Seule source de vérité pour
## temps actif, étage, mode, or, XP, niveau et items possédés.
##
## Coop 1-4 (étape 1 « Contrats », docs/multi/Archi_Reseau.md §3) : ce qui est propre à un joueur (or, XP, niveau,
## objets, personnage, sorts, compteurs, Boussole, scories) vit dans un PlayerState par joueur (`player_states`).
## RunState garde l'état global (étage, temps actif, mode, D, graine, présages, boss tués, kills) et expose une
## FAÇADE vers le joueur 1 (`local()`) : RunState.gold, .xp, .level, .items, .character, .loadout, .counters, .compass,
## .scrap et les méthodes add_gold, spend_gold, add_xp, add_item, stacks… lisent et écrivent ce PlayerState, et les
## signaux gold_changed, xp_changed, level_up, item_added, items_changed, gold_spent, scrap_changed relaient les siens.
## En solo, tout se comporte exactement comme avant. Les appels par joueur passent par RunState.player_state(slot)
## ou Players.state_of(id) (étape 2).

signal gold_changed(gold: float)
signal xp_changed(xp: float, required: float)
signal level_up(level: int)
signal item_added(item_id: StringName, stacks: int)
## Retrait d'objets (mode test : RunState.remove_item / clear_items) : la barre d'objets se reconstruit.
signal items_changed
signal difficulty_changed(D: float, tier_name: StringName)
## Or réellement débité par spend_gold (coffres, relances, kits) ; jamais émis en or infini (mode test).
## Écouté par le journal de run (or dépensé par étage).
signal gold_spent(amount: float)
## Scories des ateliers (Fondoir -> Matrice) : pastilles du HUD.
signal scrap_changed

var mode: StringName = &"moyen"
var stage := 1
var active_time_s := 0.0 ## seulement le jeu actif : pause, coffres et pubs ne comptent pas
var running := false
var rng := RandomNumberGenerator.new()

## --- Joueurs (coop) ---
## Un PlayerState par emplacement de joueur ; [0] = joueur 1 (façade solo), jamais remplacé.
var player_states: Array[PlayerState] = []
var _p1: PlayerState
## n de la partie pour l'équilibrage (joueurs actifs, Players.party_size_for_scaling), figé au début de chaque étage
## (begin_floor) : difficulty() le passe à Balance.difficulty. 1 en solo (chiffres inchangés).
var party_size := 1

## --- Façade du joueur 1 (lecture et écriture vont à local()) ---
var gold: float:
	get: return _p1.gold
	set(v): _p1.gold = v
var xp: float:
	get: return _p1.xp
	set(v): _p1.xp = v
var level: int:
	get: return _p1.level
	set(v): _p1.level = v
## item_id (StringName) -> nombre d'exemplaires
var items: Dictionary:
	get: return _p1.items
	set(v): _p1.items = v
## personnage choisi à l'écran Nouvelle run
var character: StringName:
	get: return _p1.character
	set(v): _p1.character = v
## Sorts choisis pour la run (fiche Nouvelle run) : slot (int 1-4) -> id du sort (base ou variante). Posé par App
## avant main.gd comme `character` (non remis à zéro par start_run) ; lu par CharacterData.for_id ; sauvegardé.
var loadout: Dictionary:
	get: return _p1.loadout
	set(v): _p1.loadout = v
## Compteurs génériques de la run (RunState.add_counter) : cumulés au profil en fin de run (Profile.add_stat).
var counters: Dictionary:
	get: return _p1.counters
	set(v): _p1.counters = v
## Boss tués pendant la run : [{id, floor_boss}] (règles de déblocage `boss_kill` des variantes).
var bosses_killed: Array = []
var kills := 0
var run_seed := 0
var _last_tier: StringName = &""
var floor_start_d := 1.0 ## D au début de l'étage (prix des coffres)
## Présage d'étage (scripts/omens/omens.gd) : id du présage actif (&"" = aucun, Balance.OMEN_CLEAR_ID = refusé), vrai tant
## que le joueur n'a pas choisi à l'arrivée, et choix par étage {étage (int) -> id (texte)} (rubis, historique, sauvegarde).
var omen: StringName = &""
var omen_pending := false
var omens_taken := {}
## Boussole de rouille (docs/Ateliers_Chiffres.md §7) : {tag, charges}. Une charge garantit un objet du tag sur la carte A
## du prochain petit ou grand coffre (1er tirage) ; survit au changement d'étage ; sauvegardée.
var compass: Dictionary:
	get: return _p1.compass
	set(v): _p1.compass = v
## Scories des ateliers (docs/Ateliers_Chiffres.md §3) : qualité (commun | peu_commun | rare) -> nombre, au plus
## Balance.SCRAP_CAP au total. Survivent au changement d'étage ; sauvegardées.
var scrap: Dictionary:
	get: return _p1.scrap
	set(v): _p1.scrap = v


func _init() -> void:
	_p1 = PlayerState.new(0)
	player_states.append(_p1)
	_p1.gold_changed.connect(gold_changed.emit)
	_p1.xp_changed.connect(xp_changed.emit)
	_p1.level_up.connect(level_up.emit)
	_p1.item_added.connect(item_added.emit)
	_p1.items_changed.connect(items_changed.emit)
	_p1.gold_spent.connect(gold_spent.emit)
	_p1.scrap_changed.connect(scrap_changed.emit)


## PlayerState du joueur 1 (joueur local en solo et en coop locale) : cible de la façade.
func local() -> PlayerState:
	return _p1


## PlayerState de l'emplacement `slot` (0-3), créé à la demande (remis à zéro, personnage par défaut).
func player_state(slot: int) -> PlayerState:
	slot = clampi(slot, 0, Balance.MULTI_MAX_PLAYERS - 1)
	while player_states.size() <= slot:
		player_states.append(PlayerState.new(player_states.size()))
	return player_states[slot]


## Joueurs de la partie (registre Players ; 1 en solo, même sans joueur enregistré).
func party_count() -> int:
	var reg := get_node_or_null(^"/root/Players")
	return maxi(int(reg.call(&"count")), 1) if reg != null else 1


## Or versé à l'équipe (kills, capsules, primes, piliers…) : chaque joueur de la partie, morts compris, reçoit
## `amount` × Balance.coop_gold_mult(n) dans sa propre bourse (décision du joueur, 01/11/2026 : pas de partage).
## n = 1 : identique à add_gold(amount).
func add_party_gold(amount: float) -> void:
	var n := party_count()
	var each := amount * Balance.coop_gold_mult(n)
	for i in n:
		player_state(i).add_gold(each)


## XP versée à l'équipe : entière pour chaque joueur (docs/multi/Scaling_Multi.md §2.1). n = 1 : add_xp(amount).
func add_party_xp(amount: float) -> void:
	for i in party_count():
		player_state(i).add_xp(amount)
## Remplacé (Alignement RoR2) : monster_gold_budget, réserve d'or des monstres par étage (supprimée).



func start_run(new_mode: StringName = &"moyen", run_seed: int = 0) -> void:
	mode = new_mode
	stage = 1
	active_time_s = 0.0
	# Joueurs de la partie : bourse, XP, objets, compteurs, Boussole et scories à zéro (personnage et sorts gardés) ;
	# niveau de départ Balance.player_start_level(n) (1 en solo).
	var n := party_count()
	var start_level := Balance.player_start_level(n)
	if player_states.size() > n:
		player_states.resize(n) # emplacements d'une partie précédente plus nombreuse
	for i in n:
		player_state(i).reset(start_level)
	kills = 0
	bosses_killed = []
	omen = &""
	omen_pending = false
	omens_taken = {}
	self.run_seed = run_seed if run_seed != 0 else randi()
	rng.seed = self.run_seed
	_last_tier = &""
	running = true
	begin_floor()


## Début d'étage : fige le D de l'étage (prix des coffres) ; le présage de l'étage d'avant cesse, celui du nouvel étage
## attend le choix du joueur (étages 2 à 5, jamais en mode test : le panneau de test le règle).
func begin_floor() -> void:
	party_size = _party_size_for_scaling()
	floor_start_d = difficulty()
	var had := omen != &""
	omen = &""
	omen_pending = Omens.floor_has_omen(stage) and not TestMode.active
	if had:
		Events.omen_changed.emit(&"", stage)


## Pose le présage actif (choix du joueur, ou mode test avec record = false). &"" le retire.
func set_omen(id: StringName, record := true) -> void:
	omen = id
	omen_pending = false
	if record and id != &"":
		omens_taken[stage] = String(id)
	Events.omen_changed.emit(id, stage)


## Présages acceptés dans la run (hors « Ciel clair »).
func omens_accepted() -> int:
	return Omens.accepted_count(omens_taken)


## Choix par étage en clés texte (historique du profil) : {"2": "fievre", ...}.
func omens_taken_text() -> Dictionary:
	var out := {}
	for k in omens_taken:
		out[str(k)] = str(omens_taken[k])
	return out


## n pour l'équilibrage, lu au registre Players (1 sans registre ou en solo).
func _party_size_for_scaling() -> int:
	var reg := get_node_or_null(^"/root/Players")
	return maxi(int(reg.call(&"party_size_for_scaling")), 1) if reg != null else 1


## Boussole de rouille : choisit le tag et recharge (remplace l'ancien tag et ses charges restantes).
func compass_set(tag: String, charges: int = -1) -> void:
	_p1.compass_set(tag, charges)


## Vrai si une charge est disponible pour un coffre de ce type (`Balance.BOUSSOLE_CHEST_KINDS`).
func compass_ready_for(kind: StringName) -> bool:
	return _p1.compass_ready_for(kind)


func compass_consume() -> void:
	_p1.compass_consume()


func _ready() -> void:
	begin_floor() # D d'étage valide même sans start_run (tests)
	Events.enemy_killed.connect(func(_e, _p, _t, _el) -> void: if running: kills += 1)
	Events.boss_killed.connect(_on_boss_killed)


## Ajoute `n` au compteur générique `key` de la run (ex. "ardent.eclat_kills") : versé dans Profile.stats en fin
## de run, lu par les règles `{"type": "counter", "key", "value"}` des variantes de sorts.
func add_counter(key: String, n: float = 1.0) -> void:
	_p1.add_counter(key, n)


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
	return Balance.difficulty(active_time_s, stage, Balance.MODES[mode], party_size)


## Façade : bourse du joueur 1. L'or gagné par l'équipe passera par add_party_gold (étape 2).
func add_gold(amount: float) -> void:
	_p1.add_gold(amount)


func spend_gold(amount: float) -> bool:
	return _p1.spend_gold(amount) # mode test : or infini, rien n'est débité


func add_xp(amount: float) -> void:
	_p1.add_xp(amount)


## Changement d'étage : tout l'or (bourse + `extra_gold`, les pièces restées au sol) devient de l'XP
## au taux Balance.gold_to_xp (D de l'étage qui se termine), puis or = 0. Retourne l'XP gagnée.
func convert_gold_to_xp(extra_gold: float = 0.0) -> float:
	return _p1.convert_gold_to_xp(extra_gold, difficulty())


func add_item(item_id: StringName) -> void:
	_p1.add_item(item_id)


## Retire un exemplaire de l'objet (mode test). Retourne faux s'il n'est pas possédé. Le dernier exemplaire retire
## l'entrée. L'appelant recalcule les stats du joueur (Player.apply_stats(ItemStats.compute(items))).
func remove_item(item_id: StringName) -> bool:
	return _p1.remove_item(item_id)


## Retire tous les objets (mode test).
func clear_items() -> void:
	_p1.clear_items()


## Items retirés du jeu -> remplaçant pour les anciennes sauvegardes (ramassage automatique, 22/10/2026 :
## plus d'aimant). Aimant de poche (+40 % rayon, +10 % XP) -> Éclat d'expérience (+10 % XP) ;
## Aimant d'âme (rare, tag Or) -> Faveur du marchand (rare, tag Or).
const ITEM_MIGRATION := {&"aimant_de_poche": &"eclat_d_experience", &"aimant_d_ame": &"faveur_du_marchand"}


static func migrate_item_id(item_id: StringName) -> StringName:
	return ITEM_MIGRATION.get(item_id, item_id)


func stacks(item_id: StringName) -> int:
	return _p1.items.get(item_id, 0)


# --- Scories (ateliers) ---------------------------------------------------------------
func scrap_of(quality: StringName) -> int:
	return _p1.scrap_of(quality)


func scrap_total() -> int:
	return _p1.scrap_total()


## +1 scorie de la qualité ; faux si le plafond Balance.SCRAP_CAP est atteint (rien n'est ajouté).
func add_scrap(quality: StringName) -> bool:
	return _p1.add_scrap(quality)


## Dépense 1 scorie de la qualité ; faux s'il n'y en a pas.
func spend_scrap(quality: StringName) -> bool:
	return _p1.spend_scrap(quality)


## Sauvegarde de run (docs/Design_Menus.md §6.1) : état sérialisable en JSON.
func to_dict() -> Dictionary:
	var it := {}
	for k in items:
		it[String(k)] = items[k]
	var d := {
		"mode": String(mode), "stage": stage, "active_time_s": active_time_s, "gold": gold, "xp": xp,
		"level": level, "items": it, "kills": kills, "character": String(character),
		"seed": run_seed, "rng_state": str(rng.state),
		"floor_start_d": floor_start_d,
		"loadout": _loadout_dict(), "counters": counters.duplicate(), "bosses_killed": bosses_killed.duplicate(true),
		"omen": String(omen), "omen_pending": omen_pending, "omens_taken": omens_taken_text(),
		"compass": compass.duplicate(),
		"scrap": _scrap_dict(),
	}
	if player_states.size() > 1: # coop : joueurs 2 à 4 (PlayerState.to_dict) ; le joueur 1 reste au premier niveau
		var extra: Array = []
		for i in range(1, player_states.size()):
			extra.append(player_states[i].to_dict())
		d["players"] = extra
	return d


func _scrap_dict() -> Dictionary:
	var out := {}
	for q in scrap:
		if int(scrap[q]) > 0:
			out[String(q)] = int(scrap[q])
	return out


func _loadout_dict() -> Dictionary:
	var out := {}
	for k in loadout:
		out[str(k)] = String(loadout[k])
	return out


func from_dict(d: Dictionary) -> void:
	party_size = _party_size_for_scaling()
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
	var cp: Variant = d.get("compass")
	compass = {"tag": String((cp as Dictionary).get("tag", "")), "charges": int((cp as Dictionary).get("charges", 0))} if cp is Dictionary else {"tag": "", "charges": 0}
	scrap = {}
	var sd: Variant = d.get("scrap", {}) # absente (ancienne sauvegarde) = aucune scorie
	if sd is Dictionary:
		for q in sd:
			if int(sd[q]) > 0:
				scrap[StringName(q)] = int(sd[q])
	# Coop : joueurs 2 à 4 (clé absente = solo, les emplacements en trop sont retirés).
	var extra: Variant = d.get("players", [])
	var n_extra: int = (extra as Array).size() if extra is Array else 0
	player_states.resize(1 + n_extra)
	for i in n_extra:
		var ps := PlayerState.new(i + 1)
		var pd: Variant = (extra as Array)[i]
		ps.from_dict(pd if pd is Dictionary else {}, Callable(self, &"migrate_item_id"))
		player_states[i + 1] = ps
	scrap_changed.emit()
	omen = StringName(str(d.get("omen", ""))) # absent des anciennes sauvegardes : aucun présage
	omen_pending = bool(d.get("omen_pending", false))
	omens_taken = {}
	var ot: Variant = d.get("omens_taken", {})
	if ot is Dictionary:
		for k in ot:
			omens_taken[int(str(k))] = str(ot[k])
	running = true
	gold_changed.emit(gold)
	xp_changed.emit(xp, Balance.xp_required(level))

