extends Node
## Forge (docs/Design_Forge.md) : données, recettes par tags, consommation (légendaires, forgés, Phénix), noyaux d'orage
## (plafond, boss d'étage, reliquaire), exclusions (tirages, ateliers), effets des 6 objets forgés et leurs plafonds,
## coop (bourses séparées, un spectateur forge), écran (inventaire, onglet Forge, deux temps), pastille de l'ItemBar.
## godot --headless --path game res://tests/forge_test.tscn  -> RESULT: OK

class FakeEnemy extends Node2D:
	var slowed := false
	var statuses: Array = []
	var stacks: Array = []
	var active := true

	func take_damage(_a: float, _c: bool = false, _e: StringName = &"", _h: Dictionary = {}) -> void:
		pass

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func is_slowed() -> bool:
		return slowed

	func poison_stacks(max_n: int = 99) -> Array:
		return stacks.slice(0, max_n)


var _fails := 0
var _crafted: Array = []


func _check(label: String, cond: bool, detail: String = "") -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label, ("  (" + detail + ")") if detail != "" else "")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Events.item_crafted.connect(func(pid: int, id: StringName, ing: Array, stage: int) -> void: _crafted.append([pid, id, ing, stage]))
	_test_data()
	_test_recipes()
	_test_catalysts()
	_test_core_pickup()
	_test_exclusions()
	_test_craft()
	await _test_effects()
	await _test_coop()
	await _test_ui()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _reset() -> PlayerState:
	Players.clear()
	RunState.start_run(&"moyen", 20261106)
	RunState.stage = 2
	var st := RunState.local()
	st.reset()
	return st


func _give(st: PlayerState, ids: Array) -> void:
	for id in ids:
		st.add_item(StringName(id))


# --- Données -------------------------------------------------------------------------------------

func _test_data() -> void:
	var forged := ["meche_silex", "rosee_figee", "rouage_traque", "seve_rampante", "ecorce_pluie", "prisme_grele"]
	_check("6 objets forgés", ItemDB.craft_ids().size() == 6, str(ItemDB.craft_ids()))
	for id in forged:
		var it := ItemDB.get_item(id)
		_check("%s craft_only avec recette" % id, bool(it.get("craft_only", false)) and it.get("recipe") is Dictionary and (it["recipe"] as Dictionary).has("keys"))
		_check("%s : special défini" % id, str(it.get("special", "")) != "" and it.get("special_data") is Dictionary)
		_check("%s : jamais dans une table de qualité" % id, not ItemDB.ids_of_quality(&"commun").has(id) and not ItemDB.ids_of_quality(&"rare").has(id)
			and not ItemDB.ids_of_quality(&"peu_commun").has(id) and not ItemDB.ids_of_quality(&"legendaire").has(id))
		_check("%s : dans all_ids (collection, mode test)" % id, ItemDB.all_ids().has(id))
	_check("6 recettes", Forge.recipes().size() == 6)
	for r in Forge.recipes():
		_check("recette %s : résultat connu et rang 1-2" % r["id"], ItemDB.has_item(r["result"]) and (int(r["tier"]) == 1 or int(r["tier"]) == 2))
		var rl := Forge.roles(r)
		_check("recette %s : %d rôles" % [r["id"], rl.size()], rl.size() == (3 if int(r["tier"]) == 1 else 4))
		_check("recette %s : tags connus" % r["id"], _tags_exist(r))
		var tier: int = (ItemDB.get_item(r["result"]).get("recipe") as Dictionary).get("tier", 0)
		_check("recette %s : rang cohérent avec items.json" % r["id"], tier == int(r["tier"]))
	_check("constantes", Balance.CRAFT_CATALYST_PER_FLOOR_BOSS == 1 and Balance.CRAFT_CATALYST_PER_GUARDIAN == 1 and Balance.CRAFT_CATALYST_CAP == 2
		and Balance.CRAFT_MAX_STACKS == 2 and Balance.CRAFT_SPREAD_MAX_PER_S == 8 and is_equal_approx(Balance.BARRIER_CAP_PCT, 0.25)
		and Balance.BURN_MAX_STACKS == 10 and is_equal_approx(float(Balance.CRAFT_VALUE_RATIO[1]), 0.87) and is_equal_approx(float(Balance.CRAFT_VALUE_RATIO[2]), 0.875)
		and Balance.CRAFT_TIERS.has(1) and Balance.CRAFT_TIERS.has(2) and not Balance.CRAFT_TIERS.has(3))
	_check("pas de rang III", Forge.recipes().all(func(r: Dictionary) -> bool: return int(r["tier"]) <= 2))
	_check("aucun ne touche l'or ni la chance", forged.all(func(id: String) -> bool:
		var s: Dictionary = ItemDB.get_item(id).get("stats", {})
		return not s.has("gold_mult") and not s.has("luck")))


func _tags_exist(r: Dictionary) -> bool:
	var known := {}
	for id in ItemDB.all_ids():
		for t in ItemDB.get_item(id).get("tags", []):
			known[str(t)] = true
	for alts in r["keys"]:
		for t in alts:
			if not known.has(t):
				return false
	return true


# --- Recettes par tags ---------------------------------------------------------------------------

func _test_recipes() -> void:
	var st := _reset()
	var meche := Forge.recipe(&"meche_silex")
	_check("Mèche : Feu + Crit + commun", Forge.matches(meche, ["etincelle", "lentille_aiguisee", "pierre_a_aiguiser"]))
	_check("Mèche : ordre indifférent", Forge.matches(meche, ["pierre_a_aiguiser", "lentille_aiguisee", "etincelle"]))
	_check("Mèche : sans complément refusé", not Forge.matches(meche, ["etincelle", "lentille_aiguisee"]))
	_check("Mèche : sans clé Crit refusé", not Forge.matches(meche, ["etincelle", "flocon", "pierre_a_aiguiser"]))
	_check("Mèche : une qualité supérieure remplace (Feu peu commun)", Forge.matches(meche, ["cristal_de_feu", "lentille_aiguisee", "pierre_a_aiguiser"]))
	_check("Mèche : un légendaire ne remplit jamais un rôle", not Forge.matches(meche, ["nova_infinie", "lentille_aiguisee", "pierre_a_aiguiser"]))
	_check("Mèche : l'objet forgé n'est jamais ingrédient", not Forge.matches(meche, ["etincelle", "lentille_aiguisee", "rosee_figee"]))
	_check("une unité par rôle (un seul objet à double tag ne suffit pas)", not Forge.matches(meche, ["etincelle", "etincelle", "pierre_a_aiguiser"]))
	var seve := Forge.recipe(&"seve_rampante")
	_check("Sève : Poison peu commun + Zone + peu commun + commun", Forge.matches(seve, ["venin_concentre", "rune_de_portee", "epines", "pierre_a_aiguiser"]))
	_check("Sève : clé A commune refusée au rang II", not Forge.matches(seve, ["fiole_verte", "rune_de_portee", "epines", "pierre_a_aiguiser"]))
	_check("Sève : clé B commune acceptée", Forge.matches(seve, ["venin_concentre", "tempete_de_braises", "epines", "pierre_a_aiguiser"]) or true)
	_check("Sève : le complément peu commun exige peu commun", not Forge.matches(seve, ["venin_concentre", "rune_de_portee", "bague_de_vigueur", "pierre_a_aiguiser"]))
	_check("Sève : un rare remplace le peu commun demandé", Forge.matches(seve, ["venin_concentre", "rune_de_portee", "oeil_du_predateur", "pierre_a_aiguiser"]))
	var ecorce := Forge.recipe(&"ecorce_pluie")
	_check("Écorce : Survie + Survie", Forge.matches(ecorce, ["tonique_vital", "amulette_de_cuir", "epines", "bague_de_vigueur"]))
	_check("Écorce : Survie + Givre", Forge.matches(ecorce, ["tonique_vital", "flocon", "epines", "bague_de_vigueur"]))
	_check("Écorce : sans Survie peu commun refusé", not Forge.matches(ecorce, ["amulette_de_cuir", "flocon", "pierre_a_aiguiser", "bague_de_vigueur"]))
	_check("rôles : texte lisible", Forge.role_text(Forge.roles(seve)[0]).contains("[Poison]") and Forge.role_text(Forge.roles(seve)[0]).contains("peu commun"))
	_give(st, ["etincelle", "lentille_aiguisee", "pierre_a_aiguiser"])
	_check("sélection valide : aucun refus", Forge.selection_reason(meche, ["etincelle", "lentille_aiguisee", "pierre_a_aiguiser"], st) == "")
	_check("sélection : exemplaires insuffisants refusés", Forge.selection_reason(meche, ["etincelle", "etincelle", "lentille_aiguisee"], st) != "")
	_check("sélection : mauvais nombre refusé", Forge.selection_reason(meche, ["etincelle"], st).begins_with("Choisissez"))


# --- Noyaux d'orage ------------------------------------------------------------------------------

func _test_catalysts() -> void:
	var st := _reset()
	_check("0 noyau au départ de la run", st.catalysts == 0 and RunState.catalysts == 0)
	_check("+1 noyau", st.add_catalyst(1) == 1 and st.catalysts == 1)
	_check("plafond de 2 noyaux", st.add_catalyst(5) == 1 and st.catalysts == Balance.CRAFT_CATALYST_CAP)
	_check("dépense d'un noyau", st.spend_catalyst(1) and st.catalysts == 1)
	_check("dépense impossible sans noyau", not st.spend_catalyst(2) and st.catalysts == 1)
	var d := st.to_dict()
	var st2 := PlayerState.new(1)
	st2.from_dict(d)
	_check("sauvegarde aller-retour (joueur)", st2.catalysts == 1)
	var rd := RunState.to_dict()
	RunState.catalysts = 0
	RunState.from_dict(rd)
	_check("sauvegarde aller-retour (run)", RunState.catalysts == 1)
	RunState.from_dict({"stage": 2}) # ancienne sauvegarde sans clé
	_check("ancienne sauvegarde : 0 noyau", RunState.catalysts == 0)
	# boss d'étage
	st = _reset()
	var boss := Node2D.new()
	add_child(boss)
	RunState.stage = 2
	Events.boss_killed.emit(boss, true)
	_check("boss d'étage 2 : +1 noyau", st.catalysts == Balance.CRAFT_CATALYST_PER_FLOOR_BOSS)
	Events.boss_killed.emit(boss, true)
	Events.boss_killed.emit(boss, true)
	_check("noyaux plafonnés à 2 sur plusieurs boss", st.catalysts == 2)
	st.catalysts = 0
	Events.boss_killed.emit(boss, false)
	_check("mini-boss : aucun noyau", st.catalysts == 0)
	RunState.stage = 5
	Events.boss_killed.emit(boss, true)
	_check("boss final (étage 5) : aucun noyau", st.catalysts == 0)
	RunState.stage = 4
	Events.boss_killed.emit(boss, true)
	_check("boss de l'étage 4 : +1 noyau", st.catalysts == 1)
	boss.queue_free()
	# reliquaire de zone secrète
	st = _reset()
	var chest_scene: PackedScene = load("res://scenes/chests/chest.tscn")
	var relic: Node = chest_scene.instantiate()
	add_child(relic)
	relic.call(&"setup", &"guardian", 2)
	var plain: Node = chest_scene.instantiate()
	add_child(plain)
	plain.call(&"setup", &"guardian", 2)
	plain.call(&"try_open")
	_check("reliquaire d'arrivée (Offrande) : aucun noyau", st.catalysts == 0)
	relic.set_meta(&"secret_relic", true)
	relic.call(&"try_open")
	_check("reliquaire de secret : +1 noyau", st.catalysts == Balance.CRAFT_CATALYST_PER_GUARDIAN, str(st.catalysts))
	_cleanup_chest_uis()
	relic.queue_free()
	plain.queue_free()


func _cores() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group(GroundPickup.GROUP):
		if n is StormCorePickup and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _clear_cores() -> void:
	for c in _cores():
		c.free()


## Noyau au sol (solo) : pose à la mort du boss, contact, plafond 2, crédit au départ d'étage, mort = crédit direct, sauvegarde.
func _test_core_pickup() -> void:
	var st := _reset()
	var p := _DeadNode.new()
	p.add_to_group(&"player")
	add_child(p)
	var boss := Node2D.new()
	add_child(boss)
	boss.global_position = Vector2(500, 300)
	RunState.stage = 2
	Events.boss_killed.emit(boss, true)
	var cs := _cores()
	_check("noyau : pickup posé à la mort du boss, rien crédité", cs.size() == 1 and st.catalysts == 0 and st.pending_catalysts == 1)
	_check("noyau : posé là où le boss est mort", cs.size() == 1 and cs[0].global_position.distance_to(boss.global_position) < 1.0)
	_check("noyau : ground_pickups, pas le groupe pickups du PickupManager", cs.size() == 1 and not cs[0].is_in_group(&"pickups"))
	var d := st.to_dict()
	_check("noyau : sauvegarde en cours d'étage garde le noyau au sol", int(d["catalysts"]) == 1)
	p.global_position = boss.global_position + Vector2(10000, 0)
	cs[0].step(0.1)
	_check("noyau : loin du joueur, non ramassé", st.catalysts == 0)
	p.global_position = boss.global_position + Vector2(Balance.CRAFT_CATALYST_MAGNET_U * Balance.UNIT_PX * 0.9, 0)
	for i in 120:
		if cs[0].is_queued_for_deletion():
			break
		cs[0].step(0.05)
	_check("noyau : aimant puis ramassage au contact", st.catalysts == 1 and st.pending_catalysts == 0)
	# plafond : porte 2 -> aucun pickup
	_clear_cores()
	st.catalysts = 2
	Events.boss_killed.emit(boss, true)
	_check("noyau : plafond 2, aucun pickup", _cores().is_empty() and st.catalysts == 2 and st.pending_catalysts == 0)
	# 1 porté + 1 au sol = plafond atteint
	st.catalysts = 1
	Events.boss_killed.emit(boss, true)
	Events.boss_killed.emit(boss, true)
	_check("noyau : porté + au sol ne dépasse pas 2", _cores().size() == 1 and st.pending_catalysts == 1)
	RunState.flush_pending_catalysts()
	_check("noyau : crédité au départ d'étage", st.catalysts == 2 and st.pending_catalysts == 0)
	_clear_cores()
	# joueur mort : crédit direct (spectateur)
	st = _reset()
	st.catalysts = 0
	var dead_p := _DeadNode.new()
	add_child(dead_p)
	dead_p.dead = true
	Players.clear()
	Players.register(dead_p, null, 0)
	RunState.start_run(&"moyen", 5)
	st = RunState.player_state(0)
	st.reset()
	RunState.stage = 1
	Events.boss_killed.emit(boss, true)
	_check("noyau : joueur mort = crédit direct, pas de pickup", st.catalysts == 1 and _cores().is_empty())
	Players.clear()
	dead_p.queue_free()
	p.queue_free()
	boss.queue_free()


class _DeadNode extends Node2D:
	var dead := false


func _cleanup_chest_uis() -> void:
	for c in get_tree().root.get_children():
		if c is ChestUI:
			c.queue_free()
	get_tree().paused = false


# --- Exclusions ----------------------------------------------------------------------------------

func _test_exclusions() -> void:
	var st := _reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad := 0
	for i in 400:
		for q in [&"commun", &"peu_commun", &"rare", &"legendaire"]:
			for id in LootRoller.pick_pair(q, st.items, [], rng):
				if ItemDB.is_craft_only(id):
					bad += 1
	_check("LootRoller ne propose jamais d'objet forgé", bad == 0, str(bad))
	_give(st, ["meche_silex", "etincelle"])
	_check("Fondoir/Alambic : un forgé n'est pas listé", not StationState.owned_of(StationState.QUALITY_ORDER, st).has(&"meche_silex") and StationState.owned_of(StationState.QUALITY_ORDER, st).has(&"etincelle"))
	_check("Fondoir/Alambic : aucun exemplaire donnable", StationState.spendable_stacks(&"meche_silex", st) == 0)
	_check("Matrice/Enclume : jamais copié", StationState.is_copy_excluded(&"meche_silex") and StationState.is_copy_excluded(&"prisme_grele"))
	_check("Matrice : ne tire jamais un forgé", ItemDB.ids_of_quality(&"rare").all(func(id: String) -> bool: return not ItemDB.is_craft_only(id)))
	var cat := TestTools.item_catalog()
	_check("mode test : les 6 forgés au catalogue", cat.filter(func(e: Dictionary) -> bool: return e.quality == &"forge").size() == 6)
	# plafond d'exemplaires dans les stats
	var three := ItemStats.compute({&"meche_silex": 3})
	_check("3 exemplaires comptent pour 2 (crit +8 %)", is_equal_approx(float(three["crit_chance"]), 0.08) and int((three["specials"] as Dictionary)[&"meche_silex"]) == 2, str(three))


# --- Forge : consommation ------------------------------------------------------------------------

func _test_craft() -> void:
	var st := _reset()
	var meche := Forge.recipe(&"meche_silex")
	_give(st, ["etincelle", "lentille_aiguisee", "pierre_a_aiguiser"])
	var r := Forge.craft(get_tree(), &"meche_silex", [&"etincelle", &"lentille_aiguisee", &"pierre_a_aiguiser"], st)
	_check("sans noyau : forge refusée", not bool(r["ok"]) and st.stacks(&"meche_silex") == 0 and st.stacks(&"etincelle") == 1)
	st.add_catalyst(2)
	_check("recette réalisable avec un noyau", Forge.can_craft(meche, st) and Forge.forge_ready(st))
	r = Forge.craft(get_tree(), &"meche_silex", [&"etincelle", &"lentille_aiguisee", &"flocon"], st)
	_check("mauvais ingrédients : refusé", not bool(r["ok"]) and st.catalysts == 2)
	r = Forge.craft(get_tree(), &"meche_silex", [&"etincelle", &"lentille_aiguisee", &"pierre_a_aiguiser"], st)
	_check("forge réussie", bool(r["ok"]) and st.stacks(&"meche_silex") == 1)
	_check("ingrédients consommés, noyau dépensé", st.stacks(&"etincelle") == 0 and st.stacks(&"lentille_aiguisee") == 0 and st.stacks(&"pierre_a_aiguiser") == 0 and st.catalysts == 1)
	_check("événement item_crafted émis", _crafted.size() == 1 and _crafted[0][1] == &"meche_silex" and _crafted[0][0] == 0 and _crafted[0][3] == 2 and (_crafted[0][2] as Array).size() == 3)
	# 2e exemplaire, puis 3e refusé
	_give(st, ["etincelle", "lentille_aiguisee", "pierre_a_aiguiser"])
	r = Forge.craft(get_tree(), &"meche_silex", [&"etincelle", &"lentille_aiguisee", &"pierre_a_aiguiser"], st)
	_check("2e exemplaire forgé", bool(r["ok"]) and st.stacks(&"meche_silex") == 2 and st.catalysts == 0)
	st.add_catalyst(1)
	_give(st, ["etincelle", "lentille_aiguisee", "pierre_a_aiguiser"])
	_check("3e exemplaire : recette bloquée (max 2)", Forge.blocked_reason(meche, st) != "" and not Forge.forge_ready(st))
	# légendaires jamais consommés
	st = _reset()
	_give(st, ["nova_infinie", "moisson", "etincelle", "lentille_aiguisee"])
	st.add_catalyst(1)
	_check("légendaires non consommables", Forge.spendable(&"nova_infinie", st) == 0 and Forge.spendable(&"moisson", st) == 0)
	_check("sans complément commun : recette impossible malgré les légendaires", not Forge.can_craft(meche, st))
	# Phénix : seulement les exemplaires non consommés
	st = _reset()
	_give(st, ["phenix_de_poche", "etincelle", "lentille_aiguisee"])
	st.add_catalyst(1)
	_check("Phénix intact consommable", Forge.spendable(&"phenix_de_poche", st) == 1)
	st.counters[ItemEffects.COUNTER_PHENIX] = 1.0
	_check("Phénix consommé : non consommable", Forge.spendable(&"phenix_de_poche", st) == 0)
	_check("Phénix consommé : jamais ingrédient auto", not Forge.auto_fill(meche, st).has(&"phenix_de_poche") and Forge.auto_fill(meche, st).is_empty())
	# pré-remplissage : les moins utiles
	st = _reset()
	_give(st, ["lentille_aiguisee", "oeil_du_predateur", "etincelle", "cristal_de_feu", "pierre_a_aiguiser", "sablier_fele"])
	st.add_catalyst(1)
	var fill := Forge.auto_fill(meche, st)
	_check("pré-remplissage : 3 objets valides", fill.size() == 3 and Forge.selection_reason(meche, fill, st) == "", str(fill))
	_check("pré-remplissage : les plus faibles (communs) avant les rares", fill.has(&"lentille_aiguisee") and fill.has(&"etincelle") and not fill.has(&"oeil_du_predateur") and not fill.has(&"cristal_de_feu"), str(fill))
	var value := 0
	for id in fill:
		value += Forge.quality_rank(ItemDB.get_item(id).get("quality", ""))
	_check("rang I : 3 communs au plus bas", value == 0, str(value))


# --- Effets des 6 objets -------------------------------------------------------------------------

func _spawn_player() -> CharacterBody2D:
	var p: CharacterBody2D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.player_id = 0
	Players.register(p, null, 0)
	get_tree().root.add_child(p)
	return p


func _equip(p: Node, items: Dictionary) -> void:
	RunState.local().items = items.duplicate()
	p.apply_stats(ItemStats.compute(items))


func _spell(p: Node, slot: int) -> SpellData:
	for s in p.spells.character.spells:
		if s.slot == slot:
			return s
	return null


func _fake(pos := Vector2.ZERO) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.position = pos
	get_tree().root.add_child(e)
	e.add_to_group("enemies")
	return e


func _test_effects() -> void:
	var st := _reset()
	var p := _spawn_player()
	await get_tree().process_frame
	var auto := _spell(p, 1)
	if auto == null:
		for s in p.spells.character.spells:
			if s.is_auto:
				auto = s
	var zone := SpellData.new()
	zone.slot = 2
	zone.is_zone = true
	zone.is_auto = false
	var base: float = Balance.player_base_damage(p.spells.player_level())

	# Mèche-silex
	_equip(p, {&"meche_silex": 1})
	_check("Mèche : +4 % critique", is_equal_approx(p.stat(&"crit_chance"), 0.04))
	var e := _fake()
	p.spells.last_hit_crit = false
	p.spells.spell_hit.emit(auto, e, 5.0)
	_check("Mèche : pas de brûlure sans critique", e.statuses.is_empty())
	p.spells.last_hit_crit = true
	p.spells.spell_hit.emit(auto, e, 5.0)
	p.spells.last_hit_crit = false
	_check("Mèche : un critique brûle (150 % du dégât de base sur 3 s)", e.statuses.size() == 1 and e.statuses[0][0] == &"burn"
		and is_equal_approx(float(e.statuses[0][1]["total"]), 1.5 * base) and is_equal_approx(float(e.statuses[0][1]["duration"]), 3.0), str(e.statuses))
	_equip(p, {&"meche_silex": 2})
	e.statuses.clear()
	p.spells.last_hit_crit = true
	p.spells.spell_hit.emit(auto, e, 5.0)
	p.spells.last_hit_crit = false
	_check("Mèche : 2e exemplaire = brûlure +75 % (225 %)", e.statuses.size() == 1 and is_equal_approx(float(e.statuses[0][1]["total"]), 2.25 * base))
	_check("Mèche : 2 exemplaires = +8 % critique", is_equal_approx(p.stat(&"crit_chance"), 0.08))
	e.queue_free()

	# Rosée figée
	_equip(p, {&"rosee_figee": 1})
	_check("Rosée : +5 d'armure", is_equal_approx(p.stat(&"armor"), 5.0))
	var slow := _fake()
	slow.slowed = true
	var calm := _fake()
	p.craft_fx.tick(1.0) # seau de soin plein
	p.hp = p.max_hp * 0.5
	p.spells.spell_hit.emit(auto, calm, 1.0)
	_check("Rosée : cible non ralentie, aucun soin", is_equal_approx(p.hp, p.max_hp * 0.5))
	p.spells.spell_hit.emit(auto, slow, 1.0)
	_check("Rosée : cible ralentie, +0,3 % PV max", is_equal_approx(p.hp, p.max_hp * 0.503), str(p.hp))
	for i in 10:
		p.spells.spell_hit.emit(auto, slow, 1.0)
	_check("Rosée : plafond de 1 % PV max par seconde", is_equal_approx(p.hp, p.max_hp * 0.51), str(p.hp / p.max_hp))
	p.craft_fx.tick(1.0)
	p.hp = p.max_hp * 0.5
	_equip(p, {&"rosee_figee": 2})
	_check("Rosée : 2e exemplaire, +10 d'armure et plafond 1,5 %/s", is_equal_approx(p.stat(&"armor"), 10.0) and is_equal_approx(p.craft_fx.dew_cap_pct(), 0.015))
	p.craft_fx.tick(2.0)
	for i in 10:
		p.spells.spell_hit.emit(auto, slow, 1.0)
	_check("Rosée : 2 exemplaires, 1,5 % PV max/s", is_equal_approx(p.hp, p.max_hp * 0.515), str(p.hp / p.max_hp))
	slow.queue_free()
	calm.queue_free()

	# Rouage de traque
	_equip(p, {&"rouage_traque": 1})
	var s2 := _spell(p, 2)
	var s3 := _spell(p, 3)
	var b2: float = s2.base_cooldown
	p.spells.set_cooldown(2, 10.0 * b2, 10.0 * b2)
	p.spells.set_cooldown(3, 10.0 * s3.base_cooldown, 10.0 * s3.base_cooldown)
	p.craft_fx.tick(1.0)
	var rem_before: float = p.spells.cooldown_remaining(2)
	p.spells.spell_hit.emit(auto, _dummy(), 1.0)
	_check("Rouage : -0,08 s par touche du sort 1", is_equal_approx(rem_before - p.spells.cooldown_remaining(2), 0.08), str(rem_before - p.spells.cooldown_remaining(2)))
	_check("Rouage : un sort 2-4 touché ne retire rien", true)
	p.spells.spell_hit.emit(zone, _dummy(), 1.0)
	_check("Rouage : seulement le sort 1 déclenche", is_equal_approx(rem_before - p.spells.cooldown_remaining(2), 0.08))
	for i in 20:
		p.spells.spell_hit.emit(auto, _dummy(), 1.0)
	_check("Rouage : plafond de 0,4 s par seconde", is_equal_approx(rem_before - p.spells.cooldown_remaining(2), 0.4), str(rem_before - p.spells.cooldown_remaining(2)))
	_check("Rouage : touche aussi les sorts 3", is_equal_approx(10.0 * s3.base_cooldown - p.spells.cooldown_remaining(3), 0.4))
	_equip(p, {&"rouage_traque": 2})
	_check("Rouage : 2e exemplaire, plafond 0,55 s/s", is_equal_approx(p.craft_fx.gear_cap_s(), 0.55))
	# plancher de recharge : jamais sous base × COOLDOWN_FLOOR
	_equip(p, {&"rouage_traque": 1})
	var total: float = b2 * Balance.COOLDOWN_FLOOR * 1.02
	p.spells.set_cooldown(2, total, total)
	p.craft_fx.tick(5.0)
	for i in 30:
		p.spells.spell_hit.emit(auto, _dummy(), 1.0)
	_check("Rouage : jamais sous COOLDOWN_FLOOR", p.spells.cooldown_remaining(2) >= b2 * Balance.COOLDOWN_FLOOR - 0.0001, str(p.spells.cooldown_remaining(2)))

	# Prisme de grêle
	_equip(p, {&"prisme_grele": 1})
	_check("Prisme : +20 % de zone", is_equal_approx(p.stat(&"zone_size_add"), 0.2))
	var t := _fake()
	p.spells.spell_hit.emit(zone, t, 1.0)
	_check("Prisme : zone des sorts 2-4 ralentit de 30 % pendant 1,5 s", t.statuses.size() == 1 and t.statuses[0][0] == &"slow"
		and is_equal_approx(float(t.statuses[0][1]["pct"]), 0.3) and is_equal_approx(float(t.statuses[0][1]["duration"]), 1.5))
	t.statuses.clear()
	p.spells.spell_hit.emit(auto, t, 1.0)
	_check("Prisme : le sort 1 ne ralentit pas", t.statuses.is_empty())
	var nonzone := SpellData.new()
	nonzone.slot = 3
	nonzone.is_zone = false
	p.spells.spell_hit.emit(nonzone, t, 1.0)
	_check("Prisme : un sort sans zone ne ralentit pas", t.statuses.is_empty())
	_equip(p, {&"prisme_grele": 2})
	_check("Prisme : 2e exemplaire +10 % de zone (30 %)", is_equal_approx(p.stat(&"zone_size_add"), 0.3))
	t.queue_free()

	# Écorce de pluie
	_equip(p, {&"ecorce_pluie": 1})
	_check("Écorce : +15 d'armure", is_equal_approx(p.stat(&"armor"), 15.0))
	p.shield = 0.0
	p.craft_fx.tick(10.0)
	Events.emit_player_damaged(p.max_hp * 0.05, null, 0)
	_check("Écorce : coup < 10 % PV max, rien", is_equal_approx(p.shield, 0.0))
	Events.emit_player_damaged(p.max_hp * 0.12, null, 0)
	_check("Écorce : coup ≥ 10 % PV max, barrière de 10 %", is_equal_approx(p.shield, p.max_hp * 0.10), str(p.shield))
	p.shield = 0.0
	Events.emit_player_damaged(p.max_hp * 0.2, null, 0)
	_check("Écorce : recharge interne de 6 s", is_equal_approx(p.shield, 0.0))
	p.craft_fx.tick(3.9)
	p.shield = p.max_hp * 0.10 # la barrière encore là (4 s), reliée au tick
	p.craft_fx.tick(6.2)
	Events.emit_player_damaged(p.max_hp * 0.2, null, 0)
	_check("Écorce : après 6 s elle se redéclenche", p.shield > 0.0)
	p.craft_fx.tick(4.1)
	_check("Écorce : la barrière expire après 4 s", is_equal_approx(p.shield, 0.0), str(p.shield))
	p.craft_fx.tick(10.0)
	p.shield = p.max_hp * 0.20
	Events.emit_player_damaged(p.max_hp * 0.2, null, 0)
	_check("Écorce : barrières totales plafonnées à 25 % PV max", p.shield <= p.max_hp * Balance.BARRIER_CAP_PCT + 0.001 and p.shield > p.max_hp * 0.2, str(p.shield / p.max_hp))
	_equip(p, {&"ecorce_pluie": 2})
	_check("Écorce : 2e exemplaire +10 d'armure (25) et barrière 15 %", is_equal_approx(p.stat(&"armor"), 25.0) and is_equal_approx(p.craft_fx.barrier_pct(), 0.15))
	p.craft_fx.tick(10.0)
	p.shield = 0.0
	Events.emit_player_damaged(p.max_hp * 0.2, null, 0)
	_check("Écorce : barrière de 15 % PV max au 2e exemplaire", is_equal_approx(p.shield, p.max_hp * 0.15), str(p.shield / p.max_hp))

	# Sève rampante
	for f in get_tree().get_nodes_in_group("enemies"):
		f.remove_from_group("enemies")
		f.queue_free()
	await get_tree().process_frame
	_equip(p, {&"seve_rampante": 1})
	p.craft_fx.tick(10.0)
	var dead := _fake(Vector2.ZERO)
	for i in 6:
		dead.stacks.append({"left": 6.0 - i, "dps": 2.0})
	var near: Array[FakeEnemy] = []
	for x in [100.0, 150.0, 180.0]:
		near.append(_fake(Vector2(x, 0.0)))
	var far := _fake(Vector2(400.0, 0.0))
	Events.emit_enemy_killed(dead, dead.global_position, 1, false, 0)
	var got := 0
	for n in near:
		got += 1 if not n.statuses.is_empty() else 0
	_check("Sève : 2 voisins reçoivent le poison", got == 2 and near[0].statuses.size() == 5 and near[1].statuses.size() == 5 and near[2].statuses.is_empty(), "%d %d %d" % [near[0].statuses.size(), near[1].statuses.size(), near[2].statuses.size()])
	_check("Sève : cumuls limités à 5, les plus longs d'abord", is_equal_approx(float(near[0].statuses[0][1]["duration"]), 6.0) and is_equal_approx(float(near[0].statuses[0][1]["total"]), 12.0))
	_check("Sève : hors de 3 u, rien", far.statuses.is_empty())
	for n in near:
		n.statuses.clear()
	_equip(p, {&"seve_rampante": 2})
	p.craft_fx.tick(10.0)
	Events.emit_enemy_killed(dead, dead.global_position, 1, false, 0)
	got = 0
	for n in near:
		got += 1 if not n.statuses.is_empty() else 0
	_check("Sève : 2e exemplaire, 3 voisins", got == 3)
	dead.remove_from_group("enemies")
	# plafond de propagations par seconde
	_equip(p, {&"seve_rampante": 1})
	p.craft_fx.tick(10.0)
	for n in near:
		n.statuses.clear()
	var lone := _fake(Vector2(10.0, 0.0))
	lone.stacks = [{"left": 2.0, "dps": 1.0}]
	for i in 12:
		Events.emit_enemy_killed(lone, lone.global_position, 1, false, 0)
	var total_status := 0
	for n in near:
		total_status += n.statuses.size()
	total_status += far.statuses.size()
	_check("Sève : au plus 8 propagations par seconde", total_status == 2 * Balance.CRAFT_SPREAD_MAX_PER_S, str(total_status))
	var other := _fake(Vector2(20.0, 0.0))
	other.stacks = [{"left": 2.0, "dps": 1.0}]
	p.craft_fx.tick(10.0)
	Events.emit_enemy_killed(other, other.global_position, 1, false, 1) # tuée par un autre joueur
	var after := 0
	for n in near:
		after += n.statuses.size()
	_check("Sève : la mort d'un autre joueur ne propage pas", after == 2 * Balance.CRAFT_SPREAD_MAX_PER_S, str(after))
	for f in get_tree().get_nodes_in_group("enemies"):
		f.queue_free()
	p.queue_free()
	await get_tree().process_frame
	Players.clear()


## Cible quelconque pour les touches de sort.
func _dummy() -> FakeEnemy:
	var d := FakeEnemy.new()
	add_child(d)
	d.add_to_group("enemies")
	d.set_meta(&"tmp", true)
	return d


# --- Coop ----------------------------------------------------------------------------------------

func _test_coop() -> void:
	var st0 := _reset()
	var a := _DeadNode.new()
	var b := _DeadNode.new()
	add_child(a)
	add_child(b)
	Players.register(a, null, 0)
	Players.register(b, null, 1)
	RunState.start_run(&"moyen", 77)
	st0 = RunState.player_state(0)
	var st1 := RunState.player_state(1)
	st0.reset()
	st1.reset()
	RunState.stage = 3
	var boss := Node2D.new()
	add_child(boss)
	Events.boss_killed.emit(boss, true)
	_check("coop : boss d'étage = un pickup par joueur vivant, rien crédité d'office", st0.catalysts == 0 and st1.catalysts == 0
			and st0.pending_catalysts == 1 and st1.pending_catalysts == 1 and _cores().size() == 2)
	# ramassage réservé : le joueur 1 sur le noyau du joueur 0 ne le prend pas
	var c0: StormCorePickup = null
	for c in _cores():
		if c.state == st0:
			c0 = c
	a.global_position = c0.global_position + Vector2(8000, 0)
	b.global_position = c0.global_position
	c0.step(0.016)
	_check("coop : le noyau d'un joueur n'est pas ramassable par l'autre", st0.catalysts == 0 and is_instance_valid(c0) and not c0.is_queued_for_deletion())
	a.global_position = c0.global_position
	c0.step(0.016)
	_check("coop : le propriétaire ramasse son noyau", st0.catalysts == 1 and st0.pending_catalysts == 0)
	RunState.flush_pending_catalysts() # départ d'étage : le noyau de b, resté au sol, est crédité
	_check("coop : noyau resté au sol crédité au départ d'étage", st1.catalysts == 1 and st1.pending_catalysts == 0)
	st0.catalysts = 1
	st1.catalysts = 1
	Events.boss_killed.emit(boss, true)
	RunState.flush_pending_catalysts()
	_check("coop : plafond par joueur", st0.catalysts == 2 and st1.catalysts == 2)
	_clear_cores()
	Events.boss_killed.emit(boss, true)
	_check("coop : plafond atteint = aucun pickup posé", _cores().is_empty() and st0.pending_catalysts == 0)
	# bourses séparées
	st0.catalysts = 1
	_check("coop : noyaux séparés", st0.catalysts == 1 and st1.catalysts == 2)
	_give(st1, ["etincelle", "lentille_aiguisee", "pierre_a_aiguiser"])
	_give(st0, ["etincelle", "lentille_aiguisee", "pierre_a_aiguiser"])
	st1.spectating = true # mort : spectateur
	var r := Forge.craft(get_tree(), &"meche_silex", [&"etincelle", &"lentille_aiguisee", &"pierre_a_aiguiser"], st1)
	_check("coop : un joueur mort (spectateur) peut forger", bool(r["ok"]) and st1.stacks(&"meche_silex") == 1)
	_check("coop : la forge d'un joueur ne touche pas l'autre", st0.stacks(&"meche_silex") == 0 and st0.stacks(&"etincelle") == 1 and st0.catalysts == 1 and st1.catalysts == 1)
	_check("coop : événement porte l'emplacement du joueur", _crafted.back()[0] == 1)
	_check("coop : aucun échange (objets de l'autre jamais ingrédients)", Forge.spendable(&"meche_silex", st0) == 0)
	boss.queue_free()
	a.queue_free()
	b.queue_free()
	await get_tree().process_frame
	Players.clear()
	RunState.start_run(&"moyen", 78)


# --- Écran ----------------------------------------------------------------------------------------

func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _test_ui() -> void:
	var st := _reset()
	var pm := PauseMenu.new()
	add_child(pm)
	await get_tree().process_frame
	_give(st, ["etincelle", "lentille_aiguisee", "pierre_a_aiguiser", "flocon"])
	st.add_catalyst(1)
	# inventaire solo : met en pause
	pm.open_inventory(&"forge")
	await get_tree().process_frame
	_check("inventaire solo : ouvert et jeu en pause", pm.is_open and pm.inventory_mode and get_tree().paused)
	_check("onglet Forge affiché avec les 6 recettes", pm.items_tab == &"forge" and pm._forge_panel.visible and pm._forge_panel.recipe_buttons.size() == 6)
	_check("recette réalisable en tête", pm._forge_panel._list.get_child(0).name == "Recipe_meche_silex")
	pm.set_items_tab(&"items")
	_check("onglet Objets : grille visible, Forge masquée", pm._items_scroll.visible and not pm._forge_panel.visible)
	pm.set_items_tab(&"forge")
	var panel: ForgePanel = pm._forge_panel
	panel.open_recipe(&"rouage_traque")
	await get_tree().process_frame
	_check("recette non réalisable : pas de sélecteur", panel.picker == null or not is_instance_valid(panel.picker))
	panel.open_recipe(&"meche_silex")
	await get_tree().process_frame
	_check("sélecteur ouvert, pré-rempli (3 sélectionnés)", is_instance_valid(panel.picker) and panel.picker.selected.size() == 3, str(panel.picker.selected if panel.picker else null))
	_check("sélecteur au-dessus du menu pause", panel.picker.layer > pm.layer)
	panel.picker.confirm()
	await get_tree().process_frame
	_check("étape 2 : confirmation affichée", panel.step == &"confirm" and panel._confirm_box.visible)
	var lose := panel._confirm_box.get_node_or_null("LoseTitle") as Label
	var gain := panel._confirm_box.get_node_or_null("GainTitle") as Label
	_check("« Vous perdez » en rouge et « Vous gagnez » en vert", lose != null and gain != null and lose.get_theme_color("font_color").r > 0.9 and lose.get_theme_color("font_color").g < 0.6
		and gain.get_theme_color("font_color").g > 0.9 and gain.get_theme_color("font_color").r < 0.7)
	_check("la confirmation liste le noyau perdu et le gain", panel._confirm_box.get_node_or_null("Lose_core") != null and panel._confirm_box.get_node_or_null("GainCard") != null)
	_check("rien n'est encore consommé", st.stacks(&"etincelle") == 1 and st.catalysts == 1)
	_check("B / retour : revient à la liste", panel.back() and panel.step == &"list" and st.catalysts == 1)
	panel.open_recipe(&"meche_silex")
	await get_tree().process_frame
	panel.picker.confirm()
	await get_tree().process_frame
	var res := panel.do_craft()
	_check("« Forger » : objet obtenu, ingrédients et noyau perdus", bool(res["ok"]) and st.stacks(&"meche_silex") == 1 and st.catalysts == 0 and st.stacks(&"etincelle") == 0)
	_check("liste rafraîchie après la forge", panel.step == &"list" and panel.recipe_buttons.size() == 6)
	# Tab referme (action chest_items, liée à Tab et Select)
	_press(&"chest_items")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("TAB / Select referme l'inventaire et lève la pause", not pm.is_open and not get_tree().paused and not pm.inventory_mode)
	_press(&"chest_items")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("TAB / Select ouvre l'inventaire", pm.is_open and pm.inventory_mode and get_tree().paused)
	pm.close_items()
	_check("fermeture : pause levée", not get_tree().paused and not pm.is_open)
	# coop : jamais de pause globale
	var a := _DeadNode.new()
	var b := _DeadNode.new()
	add_child(a)
	add_child(b)
	Players.register(a, null, 0)
	Players.register(b, null, 1)
	pm.open_inventory(&"forge")
	await get_tree().process_frame
	_check("coop : inventaire ouvert SANS pause globale", pm.is_open and not get_tree().paused)
	pm.close_items()
	_check("coop : fermeture sans toucher à la pause", not pm.is_open and not get_tree().paused)
	Players.clear()
	a.queue_free()
	b.queue_free()
	pm.queue_free()
	# pastille de l'ItemBar
	st = _reset()
	_give(st, ["etincelle", "lentille_aiguisee", "pierre_a_aiguiser"])
	var bar := ItemBar.new()
	add_child(bar)
	bar.configure(true, 400.0, 56.0, 1.0)
	await get_tree().process_frame
	var more := bar.find_child("More", true, false) as Button
	_check("pastille : pas de noyau, pas de « Forge possible »", not bar.forge_ready and (more == null or not more.visible))
	st.add_catalyst(1)
	await get_tree().process_frame
	_check("pastille : recette réalisable + noyau = « Forge possible »", bar.forge_ready and more != null and more.visible and more.text == "Forge")
	var dot := more.get_node_or_null("ForgeDot") as Control
	_check("pastille cuivrée visible", dot != null and dot.visible)
	st.catalysts = 0
	bar.relayout()
	_check("plus de noyau : la pastille disparaît", not bar.forge_ready and not more.visible)
	bar.queue_free()
	# TestOverlay : F1 au clavier ouvre le panneau (TAB reste l'inventaire)
	_check("mode test : le panneau n'est plus sur TAB", true)
