extends AmbientEffect
## « Eau qui monte » : les cases praticables voisines de l'eau (`from` : "," eau peu profonde, "~" canal) se couvrent
## d'un film d'eau peu profonde qui avance de `extend_u` (défaut 1 u) en `rise_s` secondes. VISUEL SEULEMENT : la
## grille de la carte ne change pas, donc le jeu (Averse « dans l'eau », MinibossBrain.in_water, RaidKit.in_shallow,
## surfaces des pas) continue de lire les cases d'origine. Toujours rendu comme de l'eau peu profonde (praticable),
## même autour du canal profond : un film clair sur une case où l'on marche ne ment pas sur la collision.
## Coût : masque recuit une fois au chargement (AmbianceWater.prepare_flood), puis un uniform par image pendant la
## montée, rien ensuite.
## Paramètres : "from" ("," défaut), "region_u" [x0, y0, x1, y1] en u du repère carte (optionnel, défaut toute la
## carte), "extend_u" (1,0), "rise_s" (12).

const WALKABLE := ".CPGES" ## sol et repères de la grille (jamais mur, vide, porte, salle secrète ni eau)

var flags := PackedByteArray()
var flood_cells := 0 ## nombre de cases inondables (tests)
var level := 0.0
var _target := 0.0
var _rate := 0.0


func setup() -> void:
	var g := AmbianceWater.grid_of(map)
	if g.is_empty():
		return
	var grid: PackedStringArray = g["grid"]
	var rows := grid.size()
	var cols := 0
	for r in grid:
		cols = maxi(cols, r.length())
	var cell_u := float(g["cell_px"]) / U
	var src := String(def.get("from", ","))
	var region: Variant = def.get("region_u", null)
	var rect := Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6)
	if region is Array and (region as Array).size() == 4:
		rect = Rect2(float(region[0]), float(region[1]), float(region[2]) - float(region[0]), float(region[3]) - float(region[1]))
	flags.resize(cols * rows)
	flags.fill(0)
	flood_cells = 0
	for y in rows:
		var row: String = grid[y]
		for x in row.length():
			if not WALKABLE.contains(row[x]):
				continue
			if not rect.has_point(Vector2((x + 0.5) * cell_u, (y + 0.5) * cell_u)):
				continue
			if _touches(grid, x, y, src):
				flags[y * cols + x] = 255
				flood_cells += 1
	_target = 0.5 * clampf(float(def.get("extend_u", 1.0)) / cell_u * 2.0, 0.0, 2.0)
	_rate = _target / maxf(float(def.get("rise_s", 12.0)), 0.1)
	if flood_cells > 0 and mgr != null and mgr.water != null:
		mgr.water.prepare_flood(flags)


static func _touches(grid: PackedStringArray, x: int, y: int, ch: String) -> bool:
	for dy in [-1, 0, 1]:
		var ny: int = y + dy
		if ny < 0 or ny >= grid.size():
			continue
		var r: String = grid[ny]
		for dx in [-1, 0, 1]:
			var nx: int = x + dx
			if (dx != 0 or dy != 0) and nx >= 0 and nx < r.length() and r[nx] == ch:
				return true
	return false


## Case inondée à l'instant (visuel) ? `cell` = case de la grille (2 u). Point de contrat si le jeu veut un jour
## suivre la crue (non branché : la crue est un décor).
func is_flooded_cell(cell: Vector2i) -> bool:
	var g := AmbianceWater.grid_of(map)
	if g.is_empty() or level <= 0.0:
		return false
	var cols := 0
	for r in (g["grid"] as PackedStringArray):
		cols = maxi(cols, r.length())
	var i := cell.y * cols + cell.x
	return i >= 0 and i < flags.size() and flags[i] > 0


func start() -> void:
	if mgr == null or mgr.water == null:
		return
	if flood_cells > 0 and not mgr.water.flood_ready(): # eau rebâtie depuis setup() (nouveau profil) : masque refait
		mgr.water.prepare_flood(flags)
	level = mgr.water.flood_level()


## Eau rebâtie (nouveau bind de la même carte) : masque préparé à nouveau, niveau gardé (pas de saut visuel).
func refresh() -> void:
	if mgr != null and mgr.water != null and flood_cells > 0 and not mgr.water.flood_ready():
		mgr.water.prepare_flood(flags)
	if mgr != null and mgr.water != null:
		mgr.water.set_flood_level(level)


func process(delta: float) -> void:
	if level >= _target or flood_cells == 0:
		return
	level = minf(level + _rate * delta, _target)
	mgr.water.set_flood_level(level)


func stop() -> void:
	level = 0.0
	if mgr != null and is_instance_valid(mgr) and mgr.water != null:
		mgr.water.set_flood_level(0.0)


func describe() -> Dictionary:
	var d := super.describe()
	d["cells"] = flood_cells
	d["level"] = level
	d["target"] = _target
	return d
