class_name TestLoopTools
extends RefCounted
## Outils du mode test pour la boucle d'étage : Boussole de rouille, coffre à vitrine, marchand de l'étage 3, Paratonnerre
## dévié (docs/Ateliers_Chiffres.md §7-8, docs/Boucle_Etage_Design.md §2.5). Sans interface : le panneau (test_panel.gd,
## section « Boucle d'étage ») appelle ces fonctions. Tout passe par les vrais nœuds et le vrai flux (prix, écrans, tirages).

const RING_U := Vector2(2.5, 4.0) ## distance d'apparition autour du joueur (u) : à portée d'interaction
const CHEST_SCENE := "res://scenes/chests/chest.tscn"

static var _rng := RandomNumberGenerator.new()


static func _context(tree: SceneTree) -> Dictionary:
	var player := tree.get_first_node_in_group(&"player") as Node2D
	var sm := tree.get_first_node_in_group(&"stage_manager")
	if player == null or sm == null or sm.get(&"map") == null:
		return {}
	return {"player": player, "sm": sm, "map": sm.get(&"map")}


static func _spot(player: Node2D, center: Variant) -> Vector2:
	if center is Vector2:
		return center
	return player.global_position + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(RING_U.x, RING_U.y) * Balance.UNIT_PX


## Coffre à vitrine près du joueur : 3 objets tirés maintenant (qualité `petit`, graine de présentation), prix x1,2.
static func spawn_showcase(tree: SceneTree, center: Variant = null) -> Chest:
	var ctx := _context(tree)
	if ctx.is_empty() or not ResourceLoader.exists(CHEST_SCENE):
		return null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var q: StringName = LootRoller.roll_quality(&"petit", rng, 0)["quality"]
	var ids: Array = LootRoller.pick_n(q, RunState.items, [], rng, Balance.CHEST_SHOWCASE_COUNT)
	var chest := (load(CHEST_SCENE) as PackedScene).instantiate() as Chest
	(ctx["map"] as Node).add_child(chest)
	chest.global_position = _spot(ctx["player"], center)
	chest.setup(&"petit", RunState.stage, {"special": "showcase", "offer": ids, "quality": String(q)})
	return chest


## Marchand de l'étage 3 près du joueur (stock tiré à neuf : un objet par rareté).
static func spawn_merchant(tree: SceneTree, center: Variant = null) -> Merchant:
	var ctx := _context(tree)
	if ctx.is_empty():
		return null
	remove_merchants(tree)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var m := Merchant.new()
	(ctx["map"] as Node).add_child(m)
	m.global_position = _spot(ctx["player"], center)
	m.setup(Merchant.roll_stock(rng), Balance.MERCHANT_STAGE)
	return m


static func remove_merchants(tree: SceneTree) -> int:
	var n := 0
	for m in tree.get_nodes_in_group(&"merchants"):
		m.queue_free()
		n += 1
	return n


## Station Boussole de rouille près du joueur (utilisable une fois : « Orienter la boussole »).
static func spawn_compass(tree: SceneTree, center: Variant = null) -> CompassStation:
	var ctx := _context(tree)
	if ctx.is_empty():
		return null
	var c := CompassStation.new()
	c.biome = (ctx["map"] as StageMap).biome() if ctx["map"] is StageMap else &"terraces"
	(ctx["map"] as Node).add_child(c)
	c.global_position = _spot(ctx["player"], center)
	return c


## Donne la garantie de la Boussole sans passer par la station : `tag` sur les BOUSSOLE_CHARGES prochains coffres.
static func give_compass(tag: String) -> void:
	RunState.compass_set(tag)


## Gros pilier près du joueur (prêt). Le panneau « Dévier la foudre » s'affiche à 2,3 u sous lui ; à sa mort, le boss pose
## ses coffres de boss (1, ou 2 si dévié) comme en jeu. Le mode test lève la limite des étages 2-4 (Pillar.can_deviate).
static func spawn_pillar(tree: SceneTree, center: Variant = null) -> Pillar:
	var ctx := _context(tree)
	if ctx.is_empty():
		return null
	var p := Pillar.new()
	p.setup(Pillar.Kind.BIG, 99, false)
	(ctx["map"] as Node).add_child(p)
	p.global_position = _spot(ctx["player"], center) + Vector2(0.0, -2.0 * Balance.UNIT_PX)
	var sm: Node = ctx["sm"]
	p.finished.connect(func(pl: Pillar) -> void: sm.call(&"spawn_boss_chests", pl))
	return p


static func clear_pillars(tree: SceneTree) -> int:
	var n := 0
	for p in tree.get_nodes_in_group(&"pillars"):
		p.queue_free()
		n += 1
	return n


## Déviation d'un boss déjà invoqué (tables du plus proche étage 2-4 de la run, affixe tiré au hasard).
static func deviate(boss: Node2D) -> void:
	var f := clampi(FloorPlan.floor_of_stage(RunState.stage), Balance.PILLAR_DEVIATED_MIN_FLOOR, Balance.PILLAR_DEVIATED_MAX_FLOOR)
	var affixes: Array[StringName] = Balance.PILLAR_DEVIATED_AFFIXES
	var affix := affixes[_rng.randi_range(0, affixes.size() - 1)]
	Pillar.apply_deviation(boss, affix, Balance.pillar_deviated_hp_mult(f), Balance.pillar_deviated_enrage_delay(f))
