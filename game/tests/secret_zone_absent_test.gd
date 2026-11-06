extends Node
## Zone cachée absente quand le secret n'est pas tiré (demande du joueur 06/11/2026) : sur les 8 cartes des étages 1-4,
## sans secret l'emplacement est du mur plein (grille visuelle, aucune porte teintée, collision pleine), aucune SecretRoom,
## aucun nœud de plaque / gardien / reliquaire ; avec secret (force-secret) la salle est construite comme avant.
## godot --headless --path game res://tests/secret_zone_absent_test.tscn  -> RESULT: OK

const MAPS := ["terrasses_noyees", "terrasses_rizieres_hautes", "foret_brume", "foret_mangrove_lanternes",
	"cite_rouille", "cite_fonderie_canal", "cryptes_noyees", "cryptes_ossuaire_pluies"]

var _fails := 0
var _mgr: StageManager
var _director: Node2D


func _ready() -> void:
	await _run()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, cond: bool, detail: String = "") -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label, ("  (" + detail + ")") if detail != "" else "")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var p := CharacterBody2D.new()
	p.add_to_group(&"player")
	add_child(p)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	add_child(_director)
	_director.spawning_enabled = false
	_mgr = StageManager.new()
	add_child(_mgr)
	await _frames(2)
	for id: String in MAPS:
		await _check_map(id, false)
		await _check_map(id, true)
	var meta5: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/la_source.json"))
	_check("la_source : pas de clé secrets", (meta5.get("secrets", []) as Array).is_empty())


func _check_map(id: String, armed: bool) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	RunState.start_run(&"moyen", 31)
	_mgr.reset_run()
	var fl := int(meta["floor"])
	(_mgr.floor_plan[fl - 1] as Dictionary)["map_id"] = id
	(_mgr.floor_plan[fl - 1] as Dictionary)["secret"] = armed
	(_mgr.floor_plan[fl - 1] as Dictionary)["secret_trigger"] = "plates"
	RunState.stage = fl
	_mgr.start_stage()
	await _frames(2)
	var tag := "%s %s" % [id, "secret" if armed else "sans secret"]
	var map := _mgr.map
	_check("%s : carte chargée" % tag, _mgr.map_id == id)
	var sc: Dictionary = meta["secrets"][0]
	var vg: Array = map._vis_grid
	var sealed := map.get_node_or_null("Obstacles/Walls/SealedRoom_%s" % String(sc["id"]))
	if armed:
		_check("%s : une SecretRoom" % tag, _mgr.secrets.size() == 1)
		_check("%s : pas de collision de comblement" % tag, sealed == null)
		for c in sc["room_cells"]:
			_check("%s : sol de salle visible" % tag, String(vg[int(c[1])])[int(c[0])] == ".")
		return
	_check("%s : aucune SecretRoom" % tag, _mgr.secrets.is_empty())
	_check("%s : collision de comblement" % tag, sealed != null)
	for c in sc["room_cells"] + sc["door_cells"]:
		_check("%s : case %s = mur plein" % [tag, str(c)], String(vg[int(c[1])])[int(c[0])] == "#")
	for row: String in vg:
		_check("%s : plus de ':' ni 'D' visuel" % tag, not row.contains(":") and not row.contains("D"))
	_check("%s : aucune porte teintée" % tag, map._door_cells.is_empty())
	_check("%s : aucun bloc de mur de porte" % tag, map.door_blocks(StringName(sc["id"])).is_empty())
	for n in map.get_children():
		var scr := n.get_script() as Script
		_check("%s : nœud secret absent (%s)" % [tag, n.name], scr == null or not scr.resource_path.contains("secret_"))
	var c0: Array = sc["room_cells"][0]
	var size_px := Vector2(meta["size_px"][0], meta["size_px"][1])
	var pt := map.from_map(Vector2((float(c0[0]) + 0.5) * 128.0, (float(c0[1]) + 0.5) * 128.0) - size_px * 0.5)
	_check("%s : salle inaccessible" % tag, not _mgr.is_reachable_local(pt))
