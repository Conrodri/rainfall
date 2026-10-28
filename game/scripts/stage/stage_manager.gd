class_name StageManager
extends Node2D
## Gère un étage : charge la carte, tire (RunState.rng) la position des coffres et piliers,
## suit la progression des piliers, pose le coffre du boss, active la sortie, enchaîne les étages.
##
## Utilisation : ajouter ce nœud à la scène de jeu puis appeler `start_stage()`.
## Cartes : plan de run `floor_plan` (FloorPlan, data/floors.json : étage -> biome, variante de carte, boss
## d'étage, mini-boss ; tiré depuis RunState.run_seed sans toucher à RunState.rng) ; la carte vient des JSON
## de `data/maps/` (scene, draw_rules ; `floor_boss` du JSON = repli). 5 étages (FINAL_STAGE = la Source,
## boss final), puis sans fin : étage n -> étage ((n-1) % 5) + 1, autre variante. `reset_run()` à chaque
## nouvelle run. Pour les tests, `map_scene` impose une carte unique (boss d'étage `&"etage"`).
##
## Node2D trié en y (docs/Design_Isometrique.md §2.3) : placé sous Main/World à l'origine, il garde la
## chaîne de tri CanvasItem World -> StageManager -> StageMap -> coffres, piliers, blocs intacte.

func _init() -> void:
	add_to_group(&"stage_manager") # Audio et autres systèmes trouvent l'étage par ce groupe
	y_sort_enabled = true


signal stage_started(stage: int)
signal victory_choice_requested(stage: int) ## étage de fin atteint : UI -> finish_run() ou continue_endless()
signal run_won

const FINAL_STAGE := 5 ## = FloorPlan.final_floor() (data/floors.json, entrée `final`) ; vérifié par run_flow_test
const SMALL_PILLARS := 2
## 300 px (audit Choix P1) : rayons 96 (coffre) + 80 (téléporteur) + 2 x 24 (joueur) + 76 de marge, pour que les
## deux zones d'interaction ne se chevauchent plus à côté du coffre du boss.
const TELEPORTER_OFFSET := Vector2(0.0, 300.0)
## Directions de repli (rotation de TELEPORTER_OFFSET) si le point droit est hors de la zone accessible.
const TELEPORTER_FALLBACK_ANGLES: Array[float] = [PI / 2.0, -PI / 2.0, PI / 4.0, -PI / 4.0, PI * 0.75, -PI * 0.75, PI]
const MAPS_DIR := "res://data/maps"
const UNIT := 64.0
const STRICT_TRIES := 40 ## tirages de piliers avec toutes les règles
const RELAXED_TRIES := 10 ## puis sans la règle de sol praticable
const CAPSULE_OBSTACLE_DIST_U := 4.0 ## distance mini aux coffres, piliers, téléporteur et départ joueur
const CAPSULE_SPACING_U := 6.0 ## distance mini entre deux capsules
const CAPSULE_SPACING_RELAXED_U := [4.0, 2.0] ## repli si la carte est trop étroite pour 10 capsules
const CAPSULE_WALK_RADIUS := 48.0 ## px : repli sans grille, disque entièrement praticable
const DEFAULT_RULES := {
	"small_chests": 8, "large_chests": 2, "legendary_chance": 0.25,
	"min_pillar_distance_u": 18.0, "big_pillar_min_spawn_distance_u": 20.0,
	"pillar_walkable_ratio_min": 0.7, "pillar_wall_clearance_u": 3.0, "pillar_zone_radius_u": {"small": 7.0, "big": 9.0},
	"legendary_chest_min_spawn_distance_u": 24.0,
}

## Optionnel : impose cette carte unique (tests). Sinon les cartes de MAPS_DIR sont utilisées.
@export var map_scene: PackedScene = null
@export var chest_scene_path := "res://scenes/chests/chest.tscn"
@export var capsule_scene_path := "res://scenes/loot/gold_capsule.tscn"

## Optionnel : Callable() -> Node2D (doit exposer setup(kind, stage)). Sert aux tests.
var chest_factory: Callable = Callable()

## Mode test (TestMode) : carte « arène de test » seule (data/maps/test_arena.json), sans coffre, pilier, capsule ni
## téléporteur. Posé par Main avant start_stage().
var bare_arena := false
var endless := false
var floor_cleared := false
var map: StageMap = null
var map_id := ""
var floor_boss := &"etage"
var pillars: Array[Pillar] = []
var chests: Array[Node2D] = []
var capsules: Array[Node2D] = [] ## capsules d'argent de l'étage (Balance.CAPSULES_PER_STAGE)
var teleporter: ExitTeleporter = null
var map_order: Array = [] ## obsolète (ancienne rotation) : toujours vide, gardé pour les anciennes sauvegardes
var floor_plan: Array = [] ## FloorPlan.build(RunState.run_seed) : étages 1..FINAL_STAGE
var floor_minis: Array = [] ## mini-boss du plan pour l'étage courant (petit pilier i -> floor_minis[i])
var is_final_floor := false ## étage de la Source (boss final, gros pilier unique)
var rules := DEFAULT_RULES.duplicate(true)
var _catalog: Array = []
var _own_nav: NavField = null ## zone accessible sans Director (tests) : grille construite ici
var _own_nav_map: Node = null
var _layout := {} ## {"chests": [{kind, marker}], "pillars": [{kind, marker}]}


func reset_run() -> void:
	map_order.clear()
	floor_plan = FloorPlan.build(RunState.run_seed)
	endless = false


## Entrée du plan pour l'étage de run `stage` (sans fin : tirée à la demande).
func plan_entry(stage: int) -> Dictionary:
	if floor_plan.is_empty():
		floor_plan = FloorPlan.build(RunState.run_seed)
	return FloorPlan.entry_for_stage(floor_plan, stage, RunState.run_seed)


## Limites de la carte courante (pour la caméra).
func get_bounds() -> Rect2:
	return map.get_bounds() if map != null else Rect2()


## Démarre l'étage RunState.stage. `layout` non vide = restauration (voir to_dict).
func start_stage(layout: Dictionary = {}) -> void:
	_clear_stage()
	floor_cleared = false
	var entry := _entry_for_stage(RunState.stage)
	rules = DEFAULT_RULES.duplicate(true)
	rules.merge(entry["rules"], true)
	floor_boss = StringName(entry["floor_boss"])
	floor_minis = entry.get("minis", [])
	is_final_floor = bool(entry.get("final", false))
	map = (entry["scene"] as PackedScene).instantiate() as StageMap
	map_id = String(entry["id"])
	add_child(map)
	var director := get_tree().get_first_node_in_group(&"director")
	if director and director.has_method(&"bind_map"):
		director.bind_map(map)
	if bare_arena:
		_layout = {}
		var tp := get_tree().get_first_node_in_group(&"player") as Node2D
		if tp != null:
			tp.global_position = map.to_global(map.get_player_start())
		Events.floor_started.emit(RunState.stage)
		stage_started.emit(RunState.stage)
		return
	var chest_markers := map.get_chest_markers()
	var pillar_markers := map.get_pillar_markers()
	if layout.is_empty():
		layout = _roll_layout(chest_markers, pillar_markers)
	if not layout.has("capsules"): # tirage après coffres et piliers : ne change pas leur seed
		layout["capsules"] = _roll_capsules(layout, chest_markers, pillar_markers)
	_layout = layout
	var stage := RunState.stage

	for ci in (layout["chests"] as Array).size():
		var c: Dictionary = layout["chests"][ci]
		if bool(c.get("opened", false)): # sauvegarde : coffre déjà ouvert (et payé) avant la reprise
			continue
		var chest := _make_chest()
		if chest == null:
			continue
		chest.set_meta(&"layout_index", ci)
		chest.position = reachable_local(map.local_pos(chest_markers[int(c["marker"])]))
		map.add_child(chest)
		if chest.has_method(&"setup"):
			chest.call(&"setup", StringName(c["kind"]), stage)
		chests.append(chest)

	var zone_id := 1
	var n_small := 0
	for p: Dictionary in layout["pillars"]:
		if int(p["kind"]) != Pillar.Kind.BIG:
			n_small += 1
	var small_i := 0
	for p: Dictionary in layout["pillars"]:
		var pillar := Pillar.new()
		pillar.position = reachable_local(map.local_pos(pillar_markers[int(p["marker"])]))
		var is_big := int(p["kind"]) == Pillar.Kind.BIG
		pillar.setup(Pillar.Kind.BIG if is_big else Pillar.Kind.SMALL, zone_id, is_big and n_small > 0)
		if is_big:
			pillar.boss_id = floor_boss
			if is_final_floor: # la Source : paratonnerre-mère, boss final, zone sur tout l'anneau
				pillar.setup_final(float(rules.get("final_zone_radius_u", 22.0)) * UNIT, _final_hp_mult())
		else:
			if small_i < floor_minis.size():
				pillar.boss_id = StringName(floor_minis[small_i])
			small_i += 1
		pillar.finished.connect(_on_pillar_finished)
		map.add_child(pillar)
		pillars.append(pillar)
		zone_id += 1

	teleporter = ExitTeleporter.new()
	teleporter.used.connect(request_exit)
	map.add_child(teleporter)
	if is_final_floor and not pillars.is_empty():
		var col := SourceColumn.new() # colonne de pluie (placeholder tant que le VFX Codex n'est pas livré)
		col.position = pillars[pillars.size() - 1].position
		map.add_child(col)

	for xy in layout["capsules"]:
		var capsule := _make_capsule()
		if capsule == null:
			break
		var saved_xy := Vector2(float(xy[0]), float(xy[1]))
		capsule.set_meta(&"saved_xy", saved_xy) # position brute : reconversion d'une sauvegarde plate (from_dict)
		capsule.position = reachable_local(saved_xy) # sauvegarde d'avant le filtre : rabattue
		map.add_child(capsule)
		if capsule.has_method(&"setup"):
			capsule.call(&"setup", stage)
		capsules.append(capsule)

	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null:
		player.global_position = map.to_global(map.get_player_start())
	Events.floor_started.emit(stage)
	stage_started.emit(stage)


# --- Cartes
func _entry_for_stage(stage: int) -> Dictionary:
	if bare_arena:
		return {"id": "test_arena", "scene": load(TestMode.ARENA_SCENE), "floor_boss": "etage", "rules": {}, "minis": [], "final": false}
	if map_scene != null:
		return {"id": "test", "scene": map_scene, "floor_boss": "etage", "rules": {}}
	if _catalog.is_empty():
		_catalog = _load_catalog()
	assert(not _catalog.is_empty(), "Aucune carte dans %s" % MAPS_DIR)
	var plan := plan_entry(stage)
	var floor_n := FloorPlan.floor_of_stage(stage)
	var cat := {}
	for c: Dictionary in _catalog: # carte du plan, sinon une carte de cet étage, sinon rotation du catalogue
		if c["id"] == String(plan.get("map_id", "")):
			cat = c
			break
	if cat.is_empty():
		for c: Dictionary in _catalog:
			if int(c["floor"]) == floor_n:
				cat = c
				break
	if cat.is_empty():
		push_warning("StageManager : aucune carte pour l'étage %d, repli sur le catalogue." % stage)
		cat = _catalog[(maxi(stage, 1) - 1) % _catalog.size()]
	var out := cat.duplicate()
	var rules_in: Dictionary = (cat["rules"] as Dictionary).duplicate(true)
	rules_in.merge(FloorPlan.floor_entry(floor_n).get("draw_rules_override", {}), true)
	out["rules"] = rules_in
	if String(plan.get("floor_boss", "")) != "":
		out["floor_boss"] = plan["floor_boss"]
	out["minis"] = plan.get("minis", [])
	out["final"] = bool(plan.get("final", false))
	return out


## Multiplicateur de PV du boss final : source unique Balance.FINAL_BOSS_HP_MULT (la clé final_boss_hp_mult de
## data/floors.json a été retirée le 28/10/2026 : le mode test ne la lisait pas).
func _final_hp_mult() -> float:
	return Balance.FINAL_BOSS_HP_MULT


func _small_pillar_count() -> int:
	return maxi(int(rules.get("small_pillars", SMALL_PILLARS)), 0)


func _load_catalog() -> Array:
	var out: Array = []
	var files := DirAccess.get_files_at(MAPS_DIR)
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [MAPS_DIR, f]))
		if data is Dictionary and bool(data.get("test_only", false)):
			continue # arène du mode test : jamais tirée dans une run
		if not (data is Dictionary) or not data.has("scene"):
			push_warning("Carte ignorée : %s" % f)
			continue
		out.append({
			"id": data.get("id", f.get_basename()), "scene": load(data["scene"]),
			"floor_boss": data.get("floor_boss", "etage"), "rules": data.get("draw_rules", {}),
			"floor": int(data.get("floor", 99)),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["floor"] < b["floor"])
	return out


# --- Tirage
## Tirage seedé : légendaire (25 %), coffres, puis piliers (règles du JSON, essais bornés).
func _roll_layout(chest_markers: Array[Marker2D], pillar_markers: Array[Marker2D]) -> Dictionary:
	var rng := RunState.rng
	var start := map.get_player_start()
	var legendary := rng.randf() < float(rules["legendary_chance"])
	var kinds: Array[String] = []
	for i in int(rules["small_chests"]):
		kinds.append("petit")
	for i in int(rules["large_chests"]):
		kinds.append("large")
	assert(chest_markers.size() >= kinds.size() + 1, "Carte : pas assez de chest_spawn")

	var order := _shuffled_indices(chest_markers.size(), rng)
	# repères hors de la zone accessible (poche fermée) écartés APRÈS le mélange : seed inchangée quand tout
	# est accessible ; s'il n'en reste pas assez, gardés en dernier (rabattus à la pose par reachable_local)
	var shut: Array = order.filter(func(i: int) -> bool: return not is_reachable_local(map.local_pos(chest_markers[i])))
	if not shut.is_empty():
		push_warning("StageManager : %d repère(s) de coffre hors zone accessible sur %s." % [shut.size(), map_id])
		order = order.filter(func(i: int) -> bool: return not shut.has(i)) + shut
	var out_chests: Array = []
	if legendary:
		var min_d := float(rules["legendary_chest_min_spawn_distance_u"]) * UNIT
		var pick := -1
		for i in order.size():
			if map.local_pos(chest_markers[order[i]]).distance_to(start) >= min_d:
				pick = i
				break
		if pick >= 0:
			out_chests.append({"kind": "legendaire", "marker": order[pick]})
			order.remove_at(pick)
		else:
			push_warning("StageManager : aucun coffre légendaire à >= %.0f u du départ, ignoré." % (min_d / UNIT))
	for i in kinds.size():
		out_chests.append({"kind": kinds[i], "marker": order[i]})

	return {"chests": out_chests, "pillars": _roll_pillars(pillar_markers, start, rng)}


func _roll_pillars(markers: Array[Marker2D], start: Vector2, rng: RandomNumberGenerator) -> Array:
	assert(markers.size() >= _small_pillar_count() + 1, "Carte : pas assez de pillar_spawn")
	var smalls: Array = []
	var bigs: Array = []
	for i in markers.size():
		if markers[i].is_in_group(&"pillar_small"):
			smalls.append(i)
		if markers[i].is_in_group(&"pillar_big"):
			bigs.append(i)
	if smalls.is_empty() and bigs.is_empty(): # carte sans sous-groupes : tout sert à tout
		for i in markers.size():
			smalls.append(i)
			bigs.append(i)
	var pos: Array[Vector2] = []
	for m in markers:
		pos.append(map.local_pos(m))
	# repères hors zone accessible : écartés tant qu'il en reste assez (sinon rabattus à la pose)
	var open := func(i: int) -> bool: return is_reachable_local(pos[i])
	var smalls_ok := smalls.filter(open)
	var bigs_ok := bigs.filter(open)
	if smalls_ok.size() != smalls.size() or bigs_ok.size() != bigs.size():
		push_warning("StageManager : repère(s) de pilier hors zone accessible sur %s." % map_id)
		if not bigs_ok.is_empty() and smalls_ok.size() >= _small_pillar_count():
			smalls = smalls_ok
			bigs = bigs_ok

	for attempt in STRICT_TRIES + RELAXED_TRIES + 1:
		var level := 0 if attempt < STRICT_TRIES else (1 if attempt < STRICT_TRIES + RELAXED_TRIES else 2)
		var res := _try_pillars(smalls, bigs, pos, start, rng, level)
		if not res.is_empty():
			if level > 0:
				push_warning("StageManager : règles de piliers assouplies (niveau %d) sur %s." % [level, map_id])
			return res
	return [] # inatteignable : le niveau 2 réussit dès qu'il y a 3 marqueurs distincts


## level 0 : toutes les règles ; 1 : sans le sol praticable (le dégagement autour du pilier reste) ;
## 2 : sans aucune contrainte.
func _try_pillars(smalls: Array, bigs: Array, pos: Array[Vector2], start: Vector2, rng: RandomNumberGenerator, level: int) -> Array:
	var radii: Dictionary = rules["pillar_zone_radius_u"]
	var min_dist := float(rules["min_pillar_distance_u"]) * UNIT
	var big_min := float(rules["big_pillar_min_spawn_distance_u"]) * UNIT
	var walk_min := float(rules["pillar_walkable_ratio_min"])
	# retour joueur : pas de pilier collé à un mur, le disque de dégagement doit être entièrement libre
	var clear_r := float(rules.get("pillar_wall_clearance_u", 0.0)) * UNIT
	var clear := func(p: Vector2) -> bool: return level >= 2 or clear_r <= 0.0 or map.get_walkable_ratio(p, clear_r) >= 0.999
	var chosen: Array = []
	var big := -1
	for i in _shuffled_array(bigs, rng):
		if level < 2 and pos[i].distance_to(start) < big_min:
			continue
		if level == 0 and map.get_walkable_ratio(pos[i], float(radii["big"]) * UNIT) < walk_min:
			continue
		if not clear.call(pos[i]):
			continue
		big = i
		break
	if big < 0:
		return []
	var picked: Array = [big]
	var n_small := _small_pillar_count()
	for i in _shuffled_array(smalls, rng):
		if picked.size() > n_small:
			break
		if i == big:
			continue
		var ok := true
		if level < 2:
			for j in picked:
				if pos[i].distance_to(pos[j]) < min_dist:
					ok = false
					break
		if ok and level == 0 and map.get_walkable_ratio(pos[i], float(radii["small"]) * UNIT) < walk_min:
			ok = false
		if ok and not clear.call(pos[i]):
			ok = false
		if ok:
			picked.append(i)
	if picked.size() < n_small + 1:
		return []
	for k in range(1, picked.size()):
		chosen.append({"kind": int(Pillar.Kind.SMALL), "marker": picked[k]})
	chosen.append({"kind": int(Pillar.Kind.BIG), "marker": big})
	return chosen


## Capsules d'argent : CAPSULES_PER_STAGE points tirés (RunState.rng) sur les cases « . » de la grille
## data/maps/<id>.json (sans grille : points au sol libre des collisions), à >= 4 u des coffres, piliers,
## téléporteur (position future, sous le gros pilier) et départ joueur, et >= 6 u entre elles.
## Retourne [[x, y], ...] en espace local de la carte.
func _roll_capsules(layout: Dictionary, chest_markers: Array[Marker2D], pillar_markers: Array[Marker2D]) -> Array:
	var rng := RunState.rng
	var avoid: Array[Vector2] = [map.get_player_start()]
	for c: Dictionary in layout["chests"]:
		avoid.append(map.local_pos(chest_markers[int(c["marker"])]))
	for p: Dictionary in layout["pillars"]:
		var pp := map.local_pos(pillar_markers[int(p["marker"])])
		avoid.append(pp)
		if int(p["kind"]) == Pillar.Kind.BIG:
			avoid.append(teleporter_local(pp))
	var cands := _capsule_candidates(rng)
	var order := _shuffled_indices(cands.size(), rng)
	var wanted := Balance.CAPSULES_PER_STAGE
	var picked: Array[Vector2] = []
	var spacings: Array = [CAPSULE_SPACING_U]
	spacings.append_array(CAPSULE_SPACING_RELAXED_U)
	for spacing_u in spacings:
		var obstacle := CAPSULE_OBSTACLE_DIST_U * UNIT
		var spacing := float(spacing_u) * UNIT
		for i in order:
			if picked.size() >= wanted:
				break
			var pos: Vector2 = cands[i]
			if picked.has(pos):
				continue
			var ok := true
			for a in avoid:
				if pos.distance_to(a) < obstacle:
					ok = false
					break
			if ok:
				for q in picked:
					if pos.distance_to(q) < spacing:
						ok = false
						break
			if ok:
				picked.append(pos)
		if picked.size() >= wanted:
			break
		if spacing_u != spacings.back():
			push_warning("StageManager : %d/%d capsules sur %s, espacement assoupli." % [picked.size(), wanted, map_id])
	if picked.size() < wanted:
		push_warning("StageManager : seulement %d/%d capsules sur %s." % [picked.size(), wanted, map_id])
	var out: Array = []
	for pos in picked:
		out.append([pos.x, pos.y])
	return out


## Points praticables de la carte (espace local logique) : centres des cases « . » de la grille JSON
## (repère carte, ramenés en logique par StageMap.from_map),
## sinon (cartes de test sans grille) points tirés au hasard hors des collisions.
func _capsule_candidates(rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	# méta de la scène d'abord : une carte imposée (map_scene, map_id « test ») garde sa grille
	var path := "%s/%s.json" % [MAPS_DIR, String(map.get_meta(&"map_id", map_id))]
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.has("grid") and data.has("size_px"):
			var cell := float(data.get("grid_cell_u", 2)) * UNIT
			var origin := -Vector2(float(data["size_px"][0]), float(data["size_px"][1])) * 0.5
			var grid: Array = data["grid"]
			for y in grid.size():
				var row: String = grid[y]
				for x in row.length():
					if row[x] == ".":
						var p := map.from_map(origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell)
						if is_reachable_local(p): # case « . » d'une poche fermée (murs en cercle) : jamais
							out.append(p)
			return out
	# tirage dans le rectangle de la carte en repère carte (la boîte englobante logique d'une carte iso
	# déborde du losange : ses coins n'ont aucun obstacle et seraient « praticables »)
	var b := map.get_map_rect().grow(-3.0 * UNIT)
	for i in 600:
		var pos := map.from_map(Vector2(rng.randf_range(b.position.x, b.end.x), rng.randf_range(b.position.y, b.end.y))).snappedf(8.0)
		if map.get_walkable_ratio(pos, CAPSULE_WALK_RADIUS) >= 0.999 and is_reachable_local(pos):
			out.append(pos)
	return out


# --- Zone accessible (NavField.compute_reachable, depuis le départ du joueur, une fois par carte)
## Grille de la carte courante : celle du Director (liée par bind_map) sinon une grille propre (tests sans
## Director). null sans carte ou sans collisions.
func reach_field() -> NavField:
	if map == null:
		return null
	var d := get_tree().get_first_node_in_group(&"director") if is_inside_tree() else null
	var nv: Variant = d.get(&"nav") if d != null and &"nav" in d else null
	if nv is NavField and (nv as NavField).has_reachability() and d.call(&"get_map") == map:
		return nv
	if _own_nav == null or _own_nav_map != map:
		_own_nav_map = map
		_own_nav = null
		if map.is_inside_tree():
			var nf := NavField.new()
			nf.build_from_map(map)
			if nf.is_valid():
				_own_nav = nf
	return _own_nav


## Vrai si le point (repère local de la carte) est accessible à pied depuis le départ (sans grille : vrai).
func is_reachable_local(p: Vector2) -> bool:
	var nf := reach_field()
	return nf == null or nf.is_reachable(map.to_global(p))


## Point (repère local de la carte) rabattu dans la zone accessible : inchangé s'il y est déjà, sinon le
## centre de la cellule accessible la plus proche (repère placé à la main dans une poche fermée, dans un mur).
func reachable_local(p: Vector2) -> Vector2:
	var nf := reach_field()
	if nf == null:
		return p
	var g := map.to_global(p)
	return p if nf.is_reachable(g) else map.to_local(nf.nearest_reachable(g))


## Position du téléporteur (sous le gros pilier), rabattue dans la zone accessible.
## Garde la distance de TELEPORTER_OFFSET : si le point droit est inaccessible, essaie d'autres directions
## (même distance) avant de se rabattre sur la cellule accessible la plus proche.
func teleporter_local(pillar_pos: Vector2) -> Vector2:
	var straight := pillar_pos + TELEPORTER_OFFSET
	if is_reachable_local(straight):
		return straight
	for a in TELEPORTER_FALLBACK_ANGLES:
		var c := pillar_pos + TELEPORTER_OFFSET.rotated(a)
		if is_reachable_local(c):
			return c
	return reachable_local(straight)


func _shuffled_array(src: Array, rng: RandomNumberGenerator) -> Array:
	var a := src.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a


func _shuffled_indices(n: int, rng: RandomNumberGenerator) -> Array:
	return _shuffled_array(range(n), rng)


func _make_chest() -> Node2D:
	if chest_factory.is_valid():
		return chest_factory.call() as Node2D
	if ResourceLoader.exists(chest_scene_path):
		return (load(chest_scene_path) as PackedScene).instantiate() as Node2D
	push_warning("StageManager : %s introuvable (coffre non posé)." % chest_scene_path)
	return null


func _make_capsule() -> Node2D:
	if ResourceLoader.exists(capsule_scene_path):
		return (load(capsule_scene_path) as PackedScene).instantiate() as Node2D
	push_warning("StageManager : %s introuvable (capsules non posées)." % capsule_scene_path)
	return null


func _on_pillar_finished(pillar: Pillar) -> void:
	if pillar.kind == Pillar.Kind.SMALL:
		var all_done := true
		for p in pillars:
			if p.kind == Pillar.Kind.SMALL and p.state != Pillar.STATE_DONE:
				all_done = false
		if all_done:
			for p in pillars:
				p.unlock()
		return
	# Gros pilier terminé : coffre du boss gratuit, étage terminé, sortie ouverte.
	var chest := _make_chest()
	if chest != null:
		chest.position = pillar.position
		map.add_child(chest)
		if chest.has_method(&"setup"):
			chest.call(&"setup", &"boss", RunState.stage)
		chests.append(chest)
	floor_cleared = true
	teleporter.position = teleporter_local(pillar.position)
	teleporter.set_active(true)
	Events.floor_cleared.emit(RunState.stage)


## Sortie utilisée : choix de fin à l'étage final, sinon étage suivant.
func request_exit() -> void:
	if not floor_cleared:
		return
	if RunState.stage >= FINAL_STAGE and not endless:
		victory_choice_requested.emit(RunState.stage)
	else:
		next_stage()


func finish_run() -> void:
	run_won.emit()


func continue_endless() -> void:
	endless = true
	next_stage()


func next_stage() -> void:
	# Comme Risk of Rain : l'or restant (bourse + pièces au sol) devient de l'XP, au D de l'étage qui finit,
	# avant le changement d'étage (une sauvegarde faite au démarrage du nouvel étage voit déjà or = 0).
	var ground := _sweep_ground_pickups()
	var ground_gold: float = ground["gold"]
	var ground_xp: float = ground["xp"]
	var gold_before := RunState.gold + ground_gold
	if ground_xp > 0.0: # gemmes non ramassées : acquises (la carte qui les portait disparaît)
		RunState.add_xp(ground_xp)
	# hook de kit : part de la bourse gardée hors conversion (Avare : l'or est sa puissance)
	var kept := _kit_kept_gold()
	if kept > 0.0:
		RunState.spend_gold(kept)
	var xp_gained := RunState.convert_gold_to_xp(ground_gold)
	RunState.stage += 1
	RunState.begin_floor()
	if kept > 0.0:
		RunState.add_gold(kept) # avant start_stage : la sauvegarde de début d'étage la voit
	gold_before -= kept
	start_stage()
	if gold_before > 0.0:
		Events.gold_converted.emit(gold_before, xp_gained)


## Or de la bourse que le kit du joueur garde au changement d'étage (`floor_gold_kept(or) -> float`), 0 sinon.
func _kit_kept_gold() -> float:
	var player := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	var kit: Variant = player.get(&"kit") if player != null and &"kit" in player else null
	if kit == null or not (kit as Object).has_method(&"floor_gold_kept"):
		return 0.0
	return clampf(float(kit.floor_gold_kept(RunState.gold)), 0.0, RunState.gold)


## Retire du sol les pickups restants (PickupManager, groupe `pickups`) et renvoie leur valeur {gold, xp}.
func _sweep_ground_pickups() -> Dictionary:
	var out := {"gold": 0.0, "xp": 0.0}
	var pm := get_tree().get_first_node_in_group(&"pickups") as PickupManager if is_inside_tree() else null
	return pm.sweep() if pm != null else out


func _clear_stage() -> void:
	var director := get_tree().get_first_node_in_group(&"director") if is_inside_tree() else null
	if director and director.has_method(&"despawn_all"):
		director.despawn_all()
	if map != null:
		map.queue_free()
		remove_child(map)
	map = null
	pillars.clear()
	chests.clear()
	capsules.clear() # libérées avec la carte
	teleporter = null


# --- Sauvegarde
func to_dict() -> Dictionary:
	var ps: Array = []
	for i in pillars.size():
		var d := pillars[i].to_dict()
		d["marker"] = _layout["pillars"][i]["marker"]
		ps.append(d)
	var caps: Array = [] # seules les capsules encore fermées sont sauvegardées
	for c in capsules:
		if is_instance_valid(c) and not (c.has_method(&"is_opened") and c.call(&"is_opened")):
			caps.append([c.position.x, c.position.y])
	return {
		"stage": RunState.stage, "endless": endless, "floor_cleared": floor_cleared,
		"map_order": map_order, "floor_plan": floor_plan, "chests": _chests_state(), "pillars": ps, "capsules": caps,
		"projection": String(map.get_meta(&"projection", "flat")) if map != null else "flat",
	}


## Disposition des coffres avec `opened` : un coffre ouvert est libéré après son choix d'objet
## (ou en cours d'ouverture), il ne doit pas réapparaître fermé à la reprise.
func _chests_state() -> Array:
	var out: Array = []
	for c: Dictionary in _layout.get("chests", []):
		var e := c.duplicate()
		e["opened"] = true
		out.append(e)
	for chest in chests:
		if is_instance_valid(chest) and chest.has_meta(&"layout_index") and not (chest.has_method(&"is_opened") and chest.call(&"is_opened")):
			out[int(chest.get_meta(&"layout_index"))]["opened"] = false
	return out


## Reconstruit l'étage sauvegardé (même carte, même disposition) et restaure les piliers.
func from_dict(d: Dictionary) -> void:
	RunState.stage = int(d.get("stage", 1))
	endless = bool(d.get("endless", false))
	map_order = [] # ancienne rotation (étages 1-3 = mêmes cartes que le plan) : ignorée
	floor_plan = []
	for e in d.get("floor_plan", []):
		if e is Dictionary:
			floor_plan.append(FloorPlan.normalize(e))
	if floor_plan.is_empty(): # sauvegarde d'avant le plan : recalculé à l'identique depuis la seed
		floor_plan = FloorPlan.build(RunState.run_seed)
	var lp: Array = []
	for p: Dictionary in d["pillars"]:
		lp.append({"kind": int(p["kind"]), "marker": int(p["marker"])})
	var layout := {"chests": d["chests"], "pillars": lp}
	if d.has("capsules"): # anciennes sauvegardes : tirage neuf
		layout["capsules"] = d["capsules"]
	start_stage(layout)
	# Carte passée en iso depuis la sauvegarde (foret_brume, 22/10/2026) : les positions sauvegardées
	# (capsules, joueur) sont en repère carte = logique de l'ancienne carte plate -> ramenées par from_map.
	# Sauvegardes sans `projection` : seule terrasses_noyees était iso à l'époque.
	var saved_proj := String(d.get("projection", "iso45" if map_id == "terrasses_noyees" else "flat"))
	if map != null and map.is_iso() and saved_proj != StageMap.PROJECTION_ISO:
		for c in capsules: # depuis la position brute (repère carte), pas celle déjà rabattue en repère logique
			c.position = reachable_local(map.from_map(c.get_meta(&"saved_xy", c.position)))
		call_deferred(&"_convert_legacy_player") # Main pose la position du joueur juste après from_dict
	for i in pillars.size():
		pillars[i].from_dict(d["pillars"][i])
	if bool(d.get("floor_cleared", false)):
		floor_cleared = true
		teleporter.position = teleporter_local(pillars[pillars.size() - 1].position)
		teleporter.set_active(true)


## Reprise d'une sauvegarde faite sur l'ancienne carte plate : joueur ramené du repère carte au logique.
func _convert_legacy_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D if is_inside_tree() else null
	if player == null or map == null:
		return
	player.global_position = map.to_global(map.from_map(map.to_local(player.global_position)))
