class_name TestTools
extends RefCounted
## Outils du mode test (sans interface) : catalogue des monstres / boss / objets / personnages, invocation, retrait
## d'objets, niveau, changement de personnage et de skin. Le panneau (TestPanel) n'est qu'une façade ; les tests
## headless appellent ces fonctions directement. À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

const MAX_LEVEL := 100 ## niveau maximal proposé (les dégâts de base montent de 2,4 par niveau)
const SPAWN_RING_U := Vector2(5.0, 8.0) ## distance d'apparition autour du joueur (u)
const FINAL_BOSS_ID := &"rain_sower"
const QUALITY_ORDER: Array[StringName] = [&"legendaire", &"rare", &"peu_commun", &"commun"]
const QUALITY_NAMES := {&"commun": "Commun", &"peu_commun": "Peu commun", &"rare": "Rare", &"legendaire": "Légendaire"}
const QUALITY_COLORS := {&"commun": Color("DADDE2"), &"peu_commun": Color("7CD67C"), &"rare": Color("E36A5A"), &"legendaire": Color("F2B84B")}
const TIER_NAMES := {1: "Nuée", 2: "Tireur", 3: "Brute"}

static var _rng := RandomNumberGenerator.new()


# --- Catalogue des monstres -----------------------------------------------------

## Entrées invocables : {key, label, group, kind (&"tier" | &"mini" | &"boss" | &"final"), tier, variant, boss_id, sprite}.
## Groupes : « Monstres », « Mini-boss », « Boss d'étage », « Boss final ». Lus depuis data/fauna.json, data/floors.json,
## data/minibosses.json : un monstre ajouté aux données apparaît tout seul.
static func monster_catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_tier_entry(1, -1, "Nuée (tier 1)"))
	out.append(_tier_entry(2, Enemy.VARIANT_SHOOTER, "Tireur (tier 2)"))
	out.append(_tier_entry(2, Enemy.VARIANT_LEAPER, "Bondisseur (tier 2)"))
	out.append(_tier_entry(3, -1, "Brute (tier 3)"))
	var names := _boss_names()
	var seen := {}
	for fe in FloorPlan.floors():
		var biome := String(fe.get("name", fe.get("biome", "")))
		for m in fe.get("minis", []):
			var mid := StringName(m)
			if seen.has(mid):
				continue
			seen[mid] = true
			var label := String(MiniBossBrain.config(mid).get("name", names.get(String(mid), String(mid))))
			out.append({"key": "mini:%s" % mid, "label": label, "group": "Mini-boss", "sub": biome, "kind": &"mini", "tier": 4,
				"variant": -1, "boss_id": mid, "sprite": EnemyVisual.boss_available(mid)})
	for fe in FloorPlan.floors():
		var biome2 := String(fe.get("name", fe.get("biome", "")))
		for b in fe.get("floor_bosses", []):
			var bid := StringName(b)
			if seen.has(bid):
				continue
			seen[bid] = true
			var final := bool(fe.get("final", false))
			out.append({"key": "%s:%s" % ["final" if final else "boss", bid], "label": String(names.get(String(bid), String(bid))),
				"group": "Boss final" if final else "Boss d'étage", "sub": biome2, "kind": &"final" if final else &"boss", "tier": 4,
				"variant": -1, "boss_id": bid, "sprite": EnemyVisual.boss_available(bid)})
	return out


static func _tier_entry(tier: int, variant: int, label: String) -> Dictionary:
	return {"key": "tier:%d:%d" % [tier, variant], "label": label, "group": "Monstres", "sub": "", "kind": &"tier", "tier": tier,
		"variant": variant, "boss_id": &"", "sprite": true}


## id -> nom affiché : boss d'étage (data/floors.json, boss_names) et mini-boss (data/minibosses.json, name).
static func _boss_names() -> Dictionary:
	var out := {}
	var bn: Variant = FloorPlan.data().get("boss_names", {})
	if bn is Dictionary:
		for k in bn:
			if str(k) != "_doc":
				out[str(k)] = str(bn[k])
	return out


# --- Invocation -----------------------------------------------------------------

## Point d'apparition : anneau autour de `center` (joueur ou curseur).
static func spawn_point(center: Vector2) -> Vector2:
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(SPAWN_RING_U.x, SPAWN_RING_U.y) * Balance.UNIT_PX
	return center + Vector2.from_angle(a) * r


## Fait apparaître `count` fois l'entrée du catalogue. `elite` : monstres de base seulement. `center` : autour de ce point
## (le joueur par défaut). Retourne les monstres créés (peut être plus court si le pool est plein).
static func spawn(tree: SceneTree, entry: Dictionary, count: int, elite: bool, center: Variant = null) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var director := tree.get_first_node_in_group(&"director")
	var player := tree.get_first_node_in_group(&"player") as Node2D
	if director == null or player == null or entry.is_empty():
		return out
	var c: Vector2 = center if center is Vector2 else player.global_position
	var kind: StringName = entry.get("kind", &"tier")
	if kind == &"tier":
		for i in clampi(count, 1, 250):
			var e: Variant = director.call(&"spawn_enemy", int(entry.tier), spawn_point(c), elite, [] as Array[StringName], int(entry.variant))
			if e is Node2D:
				out.append(e)
		return out
	# boss : un seul à la fois par appel de bouton, `count` si demandé (pool de 3 puis instanciation à chaud)
	for i in clampi(count, 1, 5):
		var b := spawn_boss(tree, StringName(entry.boss_id), kind, spawn_point(c) if i > 0 else c + Vector2(0, -7.0 * Balance.UNIT_PX))
		if b != null:
			out.append(b)
	return out


## Boss ou mini-boss par id, comme un pilier le ferait (Pillar.activate) : le plan de run est contourné
## (StageManager.floor_boss, méta next_boss_id / next_mini_id du Director), sprite livré ou non.
static func spawn_boss(tree: SceneTree, boss_id: StringName, kind: StringName, pos: Vector2) -> Node2D:
	var director := tree.get_first_node_in_group(&"director")
	if director == null:
		return null
	var mini := kind == &"mini"
	var sm := tree.get_first_node_in_group(&"stage_manager")
	if sm != null:
		sm.set(&"floor_boss", boss_id if not mini else sm.get(&"floor_boss"))
	director.set_meta(&"next_boss_id", boss_id)
	if mini:
		director.set_meta(&"next_mini_id", boss_id)
	var b: Variant = director.call(&"spawn_boss", &"mini" if mini else &"etage", pos)
	if director.has_meta(&"next_mini_id"):
		director.remove_meta(&"next_mini_id")
	if not (b is Node2D):
		return null
	(b as Node2D).set_meta(&"boss_id", boss_id)
	if kind == &"final":
		(b as Node2D).set_meta(&"final_boss", true)
		var mult := final_hp_mult()
		(b as Node2D).set(&"max_hp", float((b as Node2D).get(&"max_hp")) * mult)
		(b as Node2D).set(&"hp", float((b as Node2D).get(&"max_hp")))
	return b


## PV du boss final par rapport à un boss d'étage (comme StageManager._final_hp_mult).
static func final_hp_mult() -> float:
	var hp: Dictionary = Balance.BOSS_BASE_HP
	if float(hp.get(&"final", 0.0)) > 0.0 and float(hp.get(&"etage", 0.0)) > 0.0:
		return float(hp[&"final"]) / float(hp[&"etage"])
	return 2.0


## Tue tous les monstres vivants (récompenses, événements de mort : comme au combat). Retourne leur nombre.
static func kill_all(tree: SceneTree) -> int:
	var n := 0
	for e in tree.get_nodes_in_group(&"enemies").duplicate():
		if e is Enemy and (e as Enemy).active:
			(e as Enemy).take_damage(1.0e15, false, &"", {})
			n += 1
	return n


## Retire tous les monstres et projectiles sans mort ni récompense. Retourne le nombre de monstres retirés.
static func clean(tree: SceneTree) -> int:
	var director := tree.get_first_node_in_group(&"director")
	if director == null:
		return 0
	var n: int = int(director.call(&"active_count")) + int(director.call(&"boss_count"))
	director.call(&"despawn_all")
	return n


# --- Dégâts de base à la difficulté D ---------------------------------------------

## {hp, damage} d'une entrée du catalogue à la difficulté `d` (formules de Balance, avant armure du joueur et plafond de
## coup). `elite` : monstres de base. Boss : PV et dégâts de l'étage `RunState.stage`, multiplicateur propre au boss compris.
static func base_stats(entry: Dictionary, d: float, elite := false) -> Dictionary:
	var kind: StringName = entry.get("kind", &"tier")
	if kind == &"tier":
		var st: Dictionary = Balance.TIER_STATS[int(entry.tier)]
		var hp := Balance.monster_hp(float(st["hp"]), d)
		var dmg := Balance.monster_damage(float(st["dmg"]), d)
		if elite:
			hp *= Balance.ELITE_HP
			dmg *= Balance.ELITE_DMG
		return {"hp": hp, "damage": dmg}
	var k: StringName = &"mini" if kind == &"mini" else &"etage"
	var hp_b := Balance.boss_hp(k, d, RunState.stage) * Balance.boss_hp_mult(StringName(entry.boss_id))
	if kind == &"final":
		hp_b *= final_hp_mult()
	return {"hp": hp_b, "damage": Balance.boss_damage(k, d)}


# --- Objets -----------------------------------------------------------------------

## Tous les objets de data/items.json (y compris verrouillés), par rareté (légendaire d'abord) : [{id, name, quality, effect}].
static func item_catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q in QUALITY_ORDER:
		for id in ItemDB.ids_of_quality(q):
			var it := ItemDB.get_item(id)
			out.append({"id": StringName(id), "name": str(it.get("name", id)), "quality": q, "effect": str(it.get("effect_text", ""))})
	return out


## +1 exemplaire (chemin officiel : RunState.add_item puis recalcul des stats et des effets du joueur).
static func add_item(tree: SceneTree, id: StringName) -> void:
	if not ItemDB.has_item(id):
		return
	RunState.add_item(id)
	apply_items(tree)


## −1 exemplaire. Retourne faux s'il n'y en avait pas.
static func remove_item(tree: SceneTree, id: StringName) -> bool:
	var ok := RunState.remove_item(id)
	if ok:
		apply_items(tree)
	return ok


static func clear_items(tree: SceneTree) -> void:
	RunState.clear_items()
	apply_items(tree)


## Recalcule les stats du joueur depuis RunState.items (ItemStats.compute -> Player.apply_stats -> ItemEffects.refresh).
static func apply_items(tree: SceneTree) -> void:
	var player := tree.get_first_node_in_group(&"player")
	if player != null and player.has_method(&"apply_stats"):
		player.call(&"apply_stats", ItemStats.compute(RunState.items))


# --- Personnage, skin, niveau -------------------------------------------------------

## Personnages jouables de data/characters.json : [{id, name, title, skins [{id, name}], spells [...]}] (sans condition de déblocage).
static func characters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in Skins.roster():
		if c is Dictionary and bool(c.get("playable", true)):
			out.append(c)
	return out


## Le personnage change sur place (Player.switch_character) avec ses variantes de sorts `loadout` {slot: id}.
static func switch_character(tree: SceneTree, cid: StringName, loadout: Dictionary = {}) -> bool:
	var player := tree.get_first_node_in_group(&"player")
	return player != null and bool(player.call(&"switch_character", cid, loadout))


## Apparence d'un personnage ("" = défaut, sinon id de skin), appliquée tout de suite si c'est le personnage joué.
## Sans condition de déblocage, sans toucher au profil. Retourne faux si le skin n'est pas livré (.tres absent) :
## le choix est mémorisé mais rien ne change à l'écran.
static func set_skin(tree: SceneTree, cid: StringName, skin_id: String, loadout: Dictionary = {}) -> bool:
	TestMode.set_skin(cid, skin_id)
	var delivered := skin_id == "" or Skins.has_assets(cid, skin_id)
	if RunState.character == cid:
		switch_character(tree, cid, loadout) # le kit relit aussi le dossier du skin (Tocsin : calques)
	return delivered


## Niveau du joueur (1..MAX_LEVEL) : XP remise à zéro, PV max et dégâts de base recalculés (signal level_up).
static func set_level(n: int) -> int:
	var lv := clampi(n, 1, MAX_LEVEL)
	RunState.level = lv
	RunState.xp = 0.0
	RunState.xp_changed.emit(0.0, Balance.xp_required(lv))
	RunState.level_up.emit(lv)
	return lv


## Soigne le joueur et rend toutes les recharges de sorts.
static func restore_player(tree: SceneTree) -> void:
	var player := tree.get_first_node_in_group(&"player")
	if player == null:
		return
	player.call(&"heal", float(player.get(&"max_hp")))
	var sp: Variant = player.get(&"spells")
	if sp is SpellCaster:
		for c: Dictionary in (sp as SpellCaster).get_spell_cooldowns():
			(sp as SpellCaster).set_cooldown(int(c["slot"]), 0.0, float(c["total"]))
