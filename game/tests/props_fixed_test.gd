extends Node
## Props fixes par carte (`props_fixed` du JSON, docs/Design_Variantes_B.md §7) :
## - les 4 cartes B ont 3 à 8 entrées, les cartes A et la Source aucune ;
## - chaque entrée : nom du contrat de sprites, emprise entièrement sur du sol (« . » ou « , »), jamais sur le
##   départ, un coffre, un pilier, un événement, la salle / porte / plaques / gardiens / déclencheurs du secret,
##   ni sur les repères d'épreuve (veine, poursuite, escorte, rituel, tenue) ; marge de 0,5 u entre la collision réelle
##   (data/prop_collision.json) et le centre d'un repère, 6 u autour d'un gros pilier (téléporteur) ;
## - deux props à collision ne se chevauchent pas ;
## - avec les collisions posées (élargies du rayon du joueur, 0,4 u), tout le sol atteignable du départ le reste, ainsi que
##   chaque repère (coffre, pilier, événement) : aucun passage coupé ;
## - code : `StageMap._build_props_fixed` pose sprite + collision (couche 1, sous Obstacles/Walls) pour un prop dont la
##   texture existe, et ignore sans rien poser une texture absente.
## godot --headless --path game res://tests/props_fixed_test.tscn  -> RESULT: OK

const B_MAPS := {
	"terrasses_rizieres_hautes": ["noria", "scarecrow", "stone_stairs"],
	"foret_mangrove_lanternes": ["pontoon", "firefly_cage", "fallen_altar"],
	"cite_fonderie_canal": ["crucible", "rails", "minecart"],
	"cryptes_ossuaire_pluies": ["well_rim", "crypt_stairs"],
}
const A_MAPS := ["terrasses_noyees", "foret_brume", "cite_rouille", "cryptes_noyees", "la_source"]
const SIZES := {
	"noria": Vector2i(2, 2), "scarecrow": Vector2i(1, 1), "stone_stairs": Vector2i(1, 2),
	"pontoon": Vector2i(1, 2), "firefly_cage": Vector2i(1, 1), "fallen_altar": Vector2i(2, 1),
	"crucible": Vector2i(2, 2), "rails": Vector2i(1, 2), "minecart": Vector2i(1, 1),
	"well_rim": Vector2i(2, 2), "crypt_stairs": Vector2i(1, 2),
}
## Props à collision (data/prop_collision.json) ; pontoon et rails sont traversables.
const MARKER_CLEAR_U := 0.5 ## u libres entre la collision et le centre d'une case de repère (coffre, pilier, événement...)
const BIG_CLEAR_U := 6.0 ## u libres autour du gros pilier (arène du téléporteur)
const BODY_U := 0.4 ## rayon du joueur : une case est « bloquée » si la collision élargie de cette marge la touche
const COLLIDES := ["noria", "scarecrow", "stone_stairs", "crypt_stairs", "firefly_cage", "fallen_altar", "crucible", "minecart", "well_rim"]

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	for id in B_MAPS:
		_test_b_map(id, B_MAPS[id])
	for id in A_MAPS:
		var d: Dictionary = _load(id)
		_check(not d.has("props_fixed"), "%s : une carte A / finale ne doit pas avoir de props_fixed" % id)
	_test_code_path()
	print("RESULT: ", "OK" if _fails == 0 else "FAILED (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _load(id: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	return d if d is Dictionary else {}


static func _cell(p: Array) -> Vector2i:
	return Vector2i(int(p[0]) / 2, int(p[1]) / 2)


## Cases réservées : [gros piliers, autres repères].
func _reserved(d: Dictionary) -> Array:
	var big: Array[Vector2i] = []
	var other: Array[Vector2i] = []
	var cand: Dictionary = d["candidates"]
	for p in cand["big_pillars"]:
		big.append(_cell(p))
	for k in ["chests", "small_pillars", "events"]:
		for p in cand[k]:
			other.append(_cell(p))
	other.append(_cell(d["player_start_u"]))
	for sc: Dictionary in d.get("secrets", []):
		for k in ["plates_u", "guardians_u"]:
			for p in sc.get(k, []):
				other.append(_cell(p))
		for k in ["door_cells", "room_cells"]:
			for p in sc.get(k, []):
				other.append(Vector2i(int(p[0]), int(p[1])))
		for v in (sc.get("trigger_spots", {}) as Dictionary).values():
			for p in v:
				other.append(_cell(p))
	for k in ["vein_path", "chase_posts", "escort_path"]:
		for p in d.get(k, []):
			other.append(_cell(p))
	if d.has("ritual"):
		other.append(_cell(d["ritual"]["heart"]))
		for p in d["ritual"]["relays"]:
			other.append(_cell(p))
	if d.has("hold"):
		other.append(_cell(d["hold"]["pos"]))
	return [big, other]


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _is_floor(g: Array, c: Vector2i) -> bool:
	if c.y < 0 or c.y >= g.size():
		return false
	var row: String = g[c.y]
	return c.x >= 0 and c.x < row.length() and (row[c.x] == "." or row[c.x] == ",")


## Case praticable pour la connexité : tout sauf mur, eau profonde, porte scellée, salle scellée et vide.
static func _is_walk(g: Array, c: Vector2i) -> bool:
	if c.y < 0 or c.y >= g.size():
		return false
	var row: String = g[c.y]
	return c.x >= 0 and c.x < row.length() and not "#~D: ".contains(row[c.x])


static func _reach(g: Array, start: Vector2i, blocked: Dictionary) -> Dictionary:
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + off
			if seen.has(n) or blocked.has(n) or not _is_walk(g, n):
				continue
			seen[n] = true
			stack.append(n)
	return seen


func _test_b_map(id: String, names: Array) -> void:
	var d := _load(id)
	var list: Array = d.get("props_fixed", [])
	_check(list.size() >= 3 and list.size() <= 8, "%s : %d props_fixed (3 à 8 attendus)" % [id, list.size()])
	var g: Array = d["grid"]
	var res := _reserved(d)
	var big: Array[Vector2i] = res[0]
	var other: Array[Vector2i] = res[1]
	var footprints: Array = [] # [name, Array[Vector2i]]
	var blocked := {}
	var used := {}
	for pr in list:
		var pname := String(pr.get("name", ""))
		_check(names.has(pname), "%s : nom hors contrat « %s »" % [id, pname])
		_check(SIZES.has(pname) and Vector2i(int(pr["size"][0]), int(pr["size"][1])) == SIZES.get(pname, Vector2i.ZERO), "%s/%s : taille hors contrat" % [id, pname])
		var coll: bool = not PropCollision.rects_px(pname).is_empty()
		_check(coll == COLLIDES.has(pname), "%s/%s : collision %s (contrat %s)" % [id, pname, coll, COLLIDES.has(pname)])
		var cell := Vector2i(int(pr["cell"][0]), int(pr["cell"][1]))
		var sz := Vector2i(int(pr["size"][0]), int(pr["size"][1]))
		var cells: Array[Vector2i] = []
		for j in sz.y:
			for i in sz.x:
				cells.append(cell + Vector2i(i, j))
		used[pname] = true
		var rects := _rects_u(pr)
		for c in cells:
			_check(_is_floor(g, c), "%s/%s : case %s hors du sol" % [id, pname, c])
			for o in other:
				_check(_cheb(c, o) > 0, "%s/%s : case %s sur un repère %s" % [id, pname, c, o])
			for b in big:
				_check(_cheb(c, b) > 1, "%s/%s : case %s trop près du gros pilier %s (téléporteur)" % [id, pname, c, b])
		for ru in rects: # la collision réelle (bas visible), pas l'emprise entière
			_check(Rect2(Vector2(cell) * 2.0, Vector2(sz) * 2.0).grow(0.4).encloses(ru), "%s/%s : collision %s hors de l'emprise (0,4 u de tolérance)" % [id, pname, ru])
			for o in other:
				_check(not ru.grow(MARKER_CLEAR_U).has_point((Vector2(o) + Vector2(0.5, 0.5)) * 2.0), "%s/%s : collision %s contre le repère %s" % [id, pname, ru, o])
			for b in big:
				_check(not ru.grow(BIG_CLEAR_U).has_point((Vector2(b) + Vector2(0.5, 0.5)) * 2.0), "%s/%s : collision %s trop près du gros pilier %s" % [id, pname, ru, b])
			var lo := ((ru.position - Vector2(BODY_U, BODY_U)) / 2.0).floor()
			var hi := ((ru.end + Vector2(BODY_U, BODY_U)) / 2.0).floor()
			for cy in range(int(lo.y), int(hi.y) + 1):
				for cx in range(int(lo.x), int(hi.x) + 1):
					if ru.grow(BODY_U).intersects(Rect2((Vector2(cx, cy) + Vector2(0.5, 0.5)) * 2.0 - Vector2(0.5, 0.5), Vector2.ONE)):
						blocked[Vector2i(cx, cy)] = true # le centre (1 u) de la case ne passe plus
		if coll:
			for prev in footprints:
				if prev[2]:
					for c in cells:
						_check(not (prev[1] as Array).has(c), "%s/%s : chevauche %s en %s" % [id, pname, prev[0], c])
		footprints.append([pname, cells, coll])
	for n in names:
		_check(used.has(n), "%s : aucun « %s » placé" % [id, n])
	# connexité : le sol atteignable du départ ne perd que les cases bloquées, repères compris
	var start := _cell(d["player_start_u"])
	var base := _reach(g, start, {})
	var after := _reach(g, start, blocked)
	for c in base:
		if not blocked.has(c):
			_check(after.has(c), "%s : case %s coupée du départ par les props" % [id, c])
	var cand: Dictionary = d["candidates"]
	for k in ["chests", "small_pillars", "big_pillars", "events"]:
		for p in cand[k]:
			_check(after.has(_cell(p)), "%s : repère %s %s coupé du départ" % [id, k, p])


## Rectangles de collision du prop placé, en u de la grille (origine = coin haut-gauche de la carte).
func _rects_u(pr: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var center := (Vector2(float(pr["cell"][0]), float(pr["cell"][1])) + Vector2(float(pr["size"][0]), float(pr["size"][1])) * 0.5) * 2.0
	for r in PropCollision.rects_px(String(pr["name"]), bool(pr.get("flip", false))):
		out.append(Rect2(center + r.position / Balance.UNIT_PX, r.size / Balance.UNIT_PX))
	return out


## Pose réelle : texture existante (well_rim, broken_column des cryptes) -> sprite + collision d'après la table ;
## « collision »: « none » -> sprite sans collision ; texture absente -> rien.
func _test_code_path() -> void:
	var meta := _load("cryptes_ossuaire_pluies")
	var map := (load(meta["scene"]) as PackedScene).instantiate() as StageMap
	add_child(map)
	var walls := map.get_node("Obstacles/Walls") as StaticBody2D
	var before := walls.get_child_count()
	var origin := -Vector2(meta["size_px"][0], meta["size_px"][1]) * 0.5
	map._build_props_fixed([
		{"name": "well_rim", "cell": [10, 20], "size": [2, 2]},
		{"name": "broken_column", "cell": [14, 26], "size": [1, 1], "flip": true},
		{"name": "stalagmite", "cell": [16, 26], "size": [1, 1], "collision": "none"},
		{"name": "sprite_inexistant", "cell": [12, 24], "size": [1, 1]},
	], origin, "cryptes")
	var blocks := map.get_node("Blocks")
	_check(blocks.has_node("FP_well_rim_10_20"), "sprite du prop à texture existante non posé")
	_check(blocks.has_node("FP_broken_column_14_26"), "sprite miroir non posé")
	_check(blocks.has_node("FP_stalagmite_16_26") and not walls.has_node("FP_stalagmite_16_26"), "collision none : sprite sans forme attendu")
	_check(not blocks.has_node("FP_sprite_inexistant_12_24"), "texture absente : sprite posé")
	_check(walls.get_child_count() == before + 2, "collisions ajoutées %d != 2 (none et texture absente ignorés)" % (walls.get_child_count() - before))
	_check(walls.has_node("FP_well_rim_10_20") and (walls.get_node("FP_well_rim_10_20") as CollisionShape2D).shape is RectangleShape2D, "collision du prop absente")
	_check(walls.collision_layer == 1, "couche de collision != 1")
	var spr := blocks.get_node("FP_broken_column_14_26") as Sprite2D
	_check(spr.flip_h, "flip non appliqué")
	_check(spr.has_meta(&"shadow_decal_local"), "ombre cuite (rig top) non reliée")
	# le centre du sprite = centre de l'emprise (10,20) 2x2 -> case (11,21) en coins
	var c := map.from_map(origin + Vector2(11.0, 21.0) * StageMap.OUTLINE_CELL_PX)
	_check((blocks.get_node("FP_well_rim_10_20") as Sprite2D).position.is_equal_approx(c), "position du prop hors du centre de l'emprise")
	map.queue_free()
