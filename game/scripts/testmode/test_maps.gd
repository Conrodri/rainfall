class_name TestMaps
extends RefCounted
## Mode test : chargement d'une carte réelle (data/maps) à la place de l'arène plate, pour vérifier à l'œil les variantes B,
## les props fixes (`props_fixed`), les événements d'ambiance, les secrets et les Épreuves de chaque biome. Passe par le
## chemin normal : `FloorPlan.test_map` (comme `--force-map`), plan de run reconstruit, `StageManager.start_stage()`.
## Sandbox inchangé : TestMode.active reste vrai, Profile.begin_sandbox() n'a pas bougé (rien n'est écrit au profil).
## À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

const MAPS_DIR := "res://data/maps"


## Cartes réelles jouables, triées par étage puis variante : [{id, floor, biome, variant, label, secret, event, final}].
static func catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in FloorPlan.floors():
		var fe := f as Dictionary
		var n := int(fe.get("floor", 0))
		var maps: Array = fe.get("maps", [])
		for i in maps.size():
			var id := String(maps[i])
			if not FloorPlan.map_exists(id):
				continue
			var variant := ""
			if maps.size() > 1 and i < 2:
				variant = "AB"[i]
			var ev := AmbientEvents.read_event(id)
			out.append({
				"id": id, "floor": n, "biome": String(fe.get("biome", "")), "variant": variant,
				"label": "Étage %d%s : %s" % [n, " " + variant if variant != "" else "", String(fe.get("name", id))],
				"secret": FloorPlan.map_has_secret(id), "event": String(ev.get("name", "")),
				"final": bool(fe.get("final", false)),
			})
	return out


static func entry(id: String) -> Dictionary:
	for e in catalog():
		if String(e.id) == id:
			return e
	return {}


static func _stage_manager(tree: SceneTree) -> StageManager:
	return tree.get_first_node_in_group(&"stage_manager") as StageManager


## Charge la carte `id` ("" ou "test_arena" = retour à l'arène plate). Retourne faux si l'id est inconnu ou si la scène de
## jeu n'est pas là. Les monstres et projectiles de l'étage quitté sont retirés ; le joueur est reposé au départ.
static func load_map(tree: SceneTree, id: String) -> bool:
	var sm := _stage_manager(tree)
	if sm == null or not TestMode.active:
		return false
	var real := id != "" and id != "test_arena"
	var e := entry(id) if real else {}
	if real and e.is_empty():
		push_warning("TestMaps : carte inconnue « %s »" % id)
		return false
	TestTools.clean(tree)
	TestMode.save_plan()
	TestMode.map_id = id if real else ""
	if real:
		FloorPlan.test_map = id
		FloorPlan.force_secret = int(e.floor) if TestMode.map_secret else 0
		FloorPlan.force_trigger = TestMode.map_trigger
		RunState.stage = int(e.floor)
		sm.bare_arena = false
		sm.reset_run()
	else:
		FloorPlan.test_map = ""
		RunState.stage = 1
		sm.bare_arena = true
	sm.start_stage()
	TestMode.changed.emit()
	return true


## Repère de la carte courante : position globale du premier prop fixe visé par l'événement d'ambiance (puits, noria,
## creusets), sinon le centre du départ. Retourne {name, pos} ou {} sans carte.
static func landmark(tree: SceneTree) -> Dictionary:
	var sm := _stage_manager(tree)
	if sm == null or sm.map == null:
		return {}
	var ev := AmbientEvents.read_event(sm.map_id)
	var blocks := sm.map.get_node_or_null(^"Blocks")
	for d in ev.get("effects", []):
		if not (d is Dictionary) or not (d as Dictionary).has("prop") or blocks == null:
			continue
		var prefix := "FP_%s_" % String((d as Dictionary)["prop"])
		for c in blocks.get_children():
			if c is Sprite2D and String(c.name).begins_with(prefix):
				return {"name": String((d as Dictionary)["prop"]), "pos": (c as Sprite2D).global_position}
	return {}


## Téléporte les joueurs près du repère (zone accessible la plus proche). Retourne le nom du repère, "" s'il n'y en a pas.
static func teleport_to_landmark(tree: SceneTree) -> String:
	var sm := _stage_manager(tree)
	var lm := landmark(tree)
	if sm == null or lm.is_empty():
		return ""
	var local := sm.reachable_local(sm.map.to_local(lm.pos as Vector2))
	var target := sm.map.to_global(local)
	var i := 0
	for p in Players.all():
		(p as Node2D).global_position = target + Vector2.from_angle(float(i) * 1.7) * 48.0 * minf(float(i), 1.0)
		i += 1
	return String(lm.name)
