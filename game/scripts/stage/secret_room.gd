class_name SecretRoom
extends Node2D
## Porte scellée (docs/Design_Zones_Secretes.md §3) : 2 plaques de pression qui restent enfoncées -> la porte
## `D` s'ouvre (collision `Door_<id>` coupée, NavField et occluders refaits) -> 2 gardiens nommés (brutes élites
## tier 3, affixes selon le biome) sortent après un télégraphe de 1 s, 1,5 s d'écart -> chacun lâche un
## reliquaire (coffre gratuit) à sa mort. Aucune interaction : tout se déclenche au passage du joueur.
## Posée par StageManager sur chaque carte dont la scène porte des marqueurs `secret_spawn` (cartes B).
## Visuels provisoires (glyphe de porte, cercle de télégraphe, nom flottant) en attendant les lots Codex S-A / S-B.

signal plate_pressed(secret_id: StringName, pressed_count: int, total: int)
signal opened(secret_id: StringName)
signal guardian_spawned(secret_id: StringName, guardian_name: String, enemy: Node2D)
signal guardian_killed(secret_id: StringName, guardian_name: String, dead_count: int, total: int)
signal completed(secret_id: StringName)

const UNIT := 64.0
const TELEGRAPH_S := 1.0 ## cercle rouge sous le gardien avant sa sortie
const GUARDIAN_GAP_S := 1.5 ## écart entre deux gardiens (lisse le pic de danger)
const TELEGRAPH_RADIUS := 2.5 * UNIT
const SPAWN_RETRY_S := 0.5 ## pool du Director plein : nouvel essai
const GUARDIAN_TIER := 3
## Affixes des gardiens par biome (Design_Zones_Secretes §3.1 ; cryptes : choix du développeur, non spécifié).
const AFFIXES := {
	&"terrasses": [&"slow", &"poison"], &"foret": [&"poison", &"burn"],
	&"cite": [&"burn", &"slow"], &"cryptes": [&"slow", &"poison"],
}
const COL_DOOR := Color(1.0, 0.82, 0.45, 0.9)
const COL_DOOR_DIM := Color(0.35, 0.32, 0.28, 0.9)
const COL_TELEGRAPH := Color(1.0, 0.2, 0.15, 0.55)

var secret_id: StringName = &""
var map: StageMap = null
var biome: StringName = &""
var plates: Array[SecretPlate] = []
var is_open := false
var guardian_defs: Array[Dictionary] = [] ## {pos (local carte), name}
var guardians: Array = [] ## Enemy | null par gardien
var dead: Array[bool] = []
var relics: Array[Node2D] = []
var relic_maker: Callable = Callable() ## (pos local) -> Node2D : coffre gratuit posé, ajouté à la carte
var door_pos := Vector2.ZERO
var door_size_px := Vector2(UNIT * 2.0, UNIT * 2.0)
var _map_rot := 0.0
var _spawn_at: Array[float] = [] ## minuteur d'apparition par gardien (< 0 : non armé / fait)
var _clock := 0.0
var _labels: Array = []


## `markers` : marqueurs `secret_spawn` de CE secret (rôles plate, guardian, door).
func setup(p_map: StageMap, p_id: StringName, markers: Array, p_biome: StringName, p_relic_maker: Callable) -> void:
	map = p_map
	secret_id = p_id
	biome = p_biome
	relic_maker = p_relic_maker
	z_index = 3
	name = "SecretRoom_%s" % String(p_id)
	_map_rot = map.map_xform().get_rotation()
	var plate_marks: Array = []
	var guard_marks: Array = []
	for m: Marker2D in markers:
		match String(m.get_meta(&"role", "")):
			"plate": plate_marks.append(m)
			"guardian": guard_marks.append(m)
			"door":
				door_pos = map.local_pos(m)
				var su: Vector2 = m.get_meta(&"size_u", Vector2(2, 2))
				door_size_px = su * UNIT
	var by_index := func(a: Marker2D, b: Marker2D) -> bool: return int(a.get_meta(&"index")) < int(b.get_meta(&"index"))
	plate_marks.sort_custom(by_index)
	guard_marks.sort_custom(by_index)
	for m: Marker2D in plate_marks:
		var pl := SecretPlate.new()
		pl.secret_id = secret_id
		pl.index = int(m.get_meta(&"index"))
		pl.position = map.local_pos(m)
		pl.rotation = _map_rot
		pl.pressed_changed.connect(_on_plate_pressed)
		add_child(pl)
		plates.append(pl)
	for m: Marker2D in guard_marks:
		guardian_defs.append({"pos": map.local_pos(m), "name": String(m.get_meta(&"guardian_name", "Gardien"))})
		guardians.append(null)
		dead.append(false)
		_spawn_at.append(-1.0)
	if not Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.connect(_on_enemy_killed)
	set_process(false)
	queue_redraw()


func _exit_tree() -> void:
	if Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.disconnect(_on_enemy_killed)
	for g in guardians: # gardien encore vivant à la fin de l'étage : nom retiré de l'élite recyclée
		if g != null and is_instance_valid(g) and (g as Node).has_meta(&"guardian_name"):
			(g as Node).remove_meta(&"guardian_name")


# --- État ------------------------------------------------------------------------
func pressed_count() -> int:
	var n := 0
	for p in plates:
		if p.pressed:
			n += 1
	return n


func dead_count() -> int:
	var n := 0
	for d in dead:
		if d:
			n += 1
	return n


func is_complete() -> bool:
	return is_open and dead_count() >= guardian_defs.size()


## Pour la ligne OBJECTIFS optionnelle (à brancher côté UI) : « Dalles  1/2 », « Gardiens  0/2 », "" une fois fini.
func objective_text() -> String:
	if is_complete():
		return ""
	if not is_open:
		return "Dalles  %d/%d" % [pressed_count(), plates.size()]
	return "Gardiens  %d/%d" % [dead_count(), guardian_defs.size()]


func status() -> Dictionary:
	return {"id": String(secret_id), "plates": pressed_count(), "plates_total": plates.size(), "open": is_open,
		"guardians_dead": dead_count(), "guardians_total": guardian_defs.size(), "complete": is_complete()}


# --- Plaques -> porte ----------------------------------------------------------------
func _on_plate_pressed(_plate: SecretPlate) -> void:
	plate_pressed.emit(secret_id, pressed_count(), plates.size())
	queue_redraw()
	if not is_open and pressed_count() >= plates.size():
		open_door()


## Ouvre la porte (aussi appelé directement par les tests). `silent` : restauration, gardiens non réveillés ici.
func open_door(silent: bool = false) -> void:
	if is_open:
		return
	is_open = true
	if not silent: # une fois par zone (le compteur est sauvegardé avec la run : pas de recompte à la reprise)
		RunState.add_counter("secret_zones")
	map.open_secret_door(secret_id)
	queue_redraw()
	_after_open.call_deferred(silent) # après le set_deferred de la collision de la porte


func _after_open(silent: bool) -> void:
	if not is_inside_tree():
		return
	var director := get_tree().get_first_node_in_group(&"director")
	if director != null and director.has_method(&"bind_map"):
		director.bind_map(map) # NavField refait sans la porte : la salle devient accessible
	var occs := get_tree().get_nodes_in_group(OccluderBuilder.OCCLUDER_GROUP)
	if not occs.is_empty():
		OccluderBuilder.build(map, (occs[0] as Node).get_parent() as Node2D) # l'ombre de la porte disparaît
	if not silent:
		opened.emit(secret_id)
		_arm_guardians(0.0)
	queue_redraw()


func _arm_guardians(start_delay: float) -> void:
	for i in guardian_defs.size():
		if not dead[i] and guardians[i] == null:
			_spawn_at[i] = _clock + start_delay + TELEGRAPH_S + float(i) * GUARDIAN_GAP_S
	set_process(true)


# --- Gardiens ------------------------------------------------------------------------
func _process(delta: float) -> void:
	_clock += delta
	var busy := false
	for i in guardian_defs.size():
		if _spawn_at[i] >= 0.0:
			busy = true
			if _clock >= _spawn_at[i]:
				if _spawn_guardian(i):
					_spawn_at[i] = -1.0
				else:
					_spawn_at[i] = _clock + SPAWN_RETRY_S
		var g: Variant = guardians[i]
		if g != null and i < _labels.size() and _labels[i] != null:
			busy = true
			if is_instance_valid(g):
				var lbl := _labels[i] as Label
				lbl.position = to_local((g as Node2D).global_position) + Vector2(-lbl.size.x * 0.5, -150.0) # sous la barre d'élite : nom + barre se lisent ensemble
	if busy:
		queue_redraw()
	else:
		set_process(false)


func _spawn_guardian(i: int) -> bool:
	var director := get_tree().get_first_node_in_group(&"director")
	if director == null or not director.has_method(&"spawn_enemy"):
		return false
	var aff: Array[StringName] = []
	for a in AFFIXES.get(biome, [&"slow", &"poison"]):
		aff.append(a)
	var e: Node2D = director.spawn_enemy(GUARDIAN_TIER, map.to_global(guardian_defs[i]["pos"]), true, aff)
	if e == null:
		return false
	guardians[i] = e
	e.set_meta(&"guardian_name", guardian_defs[i]["name"])
	e.set_meta(&"secret_id", secret_id)
	while _labels.size() <= i:
		_labels.append(null)
	var lbl := Label.new()
	lbl.text = String(guardian_defs[i]["name"])
	lbl.add_theme_font_size_override(&"font_size", 26)
	lbl.add_theme_color_override(&"font_color", COL_DOOR)
	lbl.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override(&"outline_size", 6)
	lbl.scale = Vector2(1.0, 2.0) # espace logique écrasé par la caméra : texte rétabli (Iso.UNSQUASH)
	lbl.size = lbl.get_minimum_size()
	add_child(lbl)
	_labels[i] = lbl
	guardian_spawned.emit(secret_id, String(guardian_defs[i]["name"]), e)
	return true


func _on_enemy_killed(enemy: Node2D, _pos: Vector2, _tier: int, _elite: bool) -> void:
	var i := guardians.find(enemy)
	if i < 0 or dead[i]:
		return
	dead[i] = true
	if enemy.has_meta(&"guardian_name"):
		enemy.remove_meta(&"guardian_name")
	if i < _labels.size() and _labels[i] != null:
		(_labels[i] as Label).queue_free()
		_labels[i] = null
	_drop_relic(map.to_local(enemy.global_position))
	var pm := get_tree().get_first_node_in_group(&"pickups")
	var bonus := Balance.guardian_bonus_gold(RunState.difficulty(), GUARDIAN_TIER)
	if pm != null and pm.has_method(&"drop_bounty"):
		pm.call(&"drop_bounty", enemy.global_position, bonus)
	else:
		RunState.add_gold(bonus) # sans PickupManager (tests)
	guardian_killed.emit(secret_id, String(guardian_defs[i]["name"]), dead_count(), guardian_defs.size())
	if is_complete():
		completed.emit(secret_id)
	queue_redraw()


func _drop_relic(local_pos: Vector2) -> void:
	if not relic_maker.is_valid():
		return
	var r: Variant = relic_maker.call(local_pos)
	if r is Node2D:
		relics.append(r)


# --- Dessin provisoire --------------------------------------------------------------------
func _draw() -> void:
	if map == null:
		return
	if not is_open:
		draw_set_transform(door_pos, _map_rot)
		# glyphe : un cran par plaque, allumé une fois la plaque enfoncée
		var n := plates.size()
		for k in n:
			var lit: bool = plates[k].pressed
			var c := Vector2((float(k) - float(n - 1) * 0.5) * 36.0, 0.0)
			draw_circle(c, 11.0, COL_DOOR if lit else COL_DOOR_DIM)
		draw_set_transform(Vector2.ZERO, 0.0)
	for i in guardian_defs.size():
		if i < _spawn_at.size() and _spawn_at[i] >= 0.0 and guardians[i] == null:
			var left := _spawn_at[i] - _clock
			if left <= TELEGRAPH_S:
				var p: Vector2 = guardian_defs[i]["pos"]
				var k := clampf(1.0 - left / TELEGRAPH_S, 0.0, 1.0)
				draw_arc(p, TELEGRAPH_RADIUS, 0.0, TAU, 48, COL_TELEGRAPH, 6.0)
				draw_arc(p, TELEGRAPH_RADIUS * k, 0.0, TAU, 48, COL_TELEGRAPH, 4.0)


# --- Sauvegarde --------------------------------------------------------------------------
func to_dict() -> Dictionary:
	var pl: Array = []
	for p in plates:
		pl.append(p.pressed)
	var rel: Array = []
	for r in relics:
		if is_instance_valid(r) and not (r.has_method(&"is_opened") and r.call(&"is_opened")):
			rel.append([r.position.x, r.position.y])
	return {"id": String(secret_id), "plates": pl, "open": is_open, "dead": dead.duplicate(), "relics": rel}


func from_dict(d: Dictionary) -> void:
	var pl: Array = d.get("plates", [])
	for i in mini(pl.size(), plates.size()):
		if bool(pl[i]):
			plates[i].press(true)
	var dd: Array = d.get("dead", [])
	for i in mini(dd.size(), dead.size()):
		dead[i] = bool(dd[i])
	for xy in d.get("relics", []):
		_drop_relic(Vector2(float(xy[0]), float(xy[1])))
	if bool(d.get("open", false)):
		open_door(true)
		_arm_guardians(0.5) # gardiens vivants à la reprise : ils reviennent (PV pleins)
	queue_redraw()
