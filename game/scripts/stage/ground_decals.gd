class_name GroundDecals
extends MultiMeshInstance2D
## Décalques de sol v2 (fissures, cailloux, flaques, mousse…) semés sur la carte, en repère carte sous Visual,
## au-dessus du GroundSplat : UN MultiMesh (un draw call), placé une fois au chargement, rien par image.
## Atlas `<dir>/decals.png` (contrat art/briefs/SOL_contrat.md : grille `cols` × `rows` de décalques vus de
## dessus, alpha), réglages dans data/maps/ground/biomes.json (`decals`). Inactif tant que l'atlas n'est pas
## livré. Tirage stable (hachage case + carte) ; zones par décalque (`zones` : "any", "wet", "wall", "open").
## Rien sur les murs, le vide, l'eau profonde, ni près des repères (départ, coffres, piliers, événements).

const SHADER := preload("res://shaders/ground_decals.gdshader")
const SHADER_E := preload("res://shaders/ground_decals_e.gdshader")

var count := 0


## `keep` : cases à laisser libres (repères). Retourne le nombre de décalques posés.
func setup(cfg: Dictionary, atlas: Texture2D, grid: Array, origin: Vector2, cell_px: float, seed_key: String, keep: Array[Vector2i]) -> int:
	name = "GroundDecals"
	var dc: Dictionary = cfg.get("decals", {})
	var cols := maxi(int(dc.get("cols", 4)), 1)
	var rows := maxi(int(dc.get("rows", 4)), 1)
	var n_cells := cols * rows
	var size_px := float(dc.get("size_u", 2.0)) * 64.0
	var density := clampf(float(dc.get("density", 0.2)), 0.0, 2.0)
	var zones: Array = dc.get("zones", [])
	var by_zone := {"any": [], "wet": [], "wall": [], "open": []}
	for i in n_cells:
		var z := String(zones[i]) if i < zones.size() else "any"
		(by_zone.get(z, by_zone["any"]) as Array).append(i)
	var picks: Array = [] # [position, rotation, échelle, index]
	var salt := hash(seed_key)
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			var ch := row[x]
			if ch != "." and ch != ",":
				continue
			var c := Vector2i(x, y)
			var skip := false
			for k in keep:
				if absi(k.x - c.x) <= 1 and absi(k.y - c.y) <= 1:
					skip = true
					break
			if skip:
				continue
			var h := absi(hash([x * 73856093, y * 19349663, salt]))
			var tries := int(density) + (1 if float(h % 1000) / 1000.0 < density - floorf(density) else 0)
			for t in tries:
				var hh := absi(hash([h, t, 911]))
				var zone := _zone(grid, x, y, ch)
				var pool: Array = by_zone[zone] if not (by_zone[zone] as Array).is_empty() else by_zone["any"]
				if pool.is_empty():
					continue
				var idx: int = pool[hh % pool.size()]
				var off := Vector2(float(hh % 97) / 97.0, float((hh / 97) % 89) / 89.0)
				var pos := origin + (Vector2(c) + off) * cell_px
				picks.append([pos, float(hh % 628) / 100.0, 0.75 + float((hh / 7) % 50) / 100.0, idx])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size_px
	mm.mesh = quad
	mm.instance_count = picks.size()
	for i in picks.size():
		var p: Array = picks[i]
		mm.set_instance_transform_2d(i, Transform2D(float(p[1]), Vector2.ONE * float(p[2]), 0.0, p[0]))
		mm.set_instance_custom_data(i, Color(float(p[3]), 0.85, float(i % 17) / 17.0, 0.0)) # index, alpha, phase de pulsation
	multimesh = mm
	texture = atlas
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"atlas_grid", Vector2(cols, rows))
	material = mat
	count = picks.size()
	return count


## Zone d'une case de sol : « wet » si l'eau est à côté (ou eau peu profonde), « wall » si un mur touche,
## « open » sinon.
static func _zone(grid: Array, x: int, y: int, ch: String) -> String:
	if ch == ",":
		return "wet"
	var wall := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var ny: int = y + d.y
		var nx: int = x + d.x
		if ny < 0 or ny >= grid.size() or nx < 0 or nx >= (grid[ny] as String).length():
			continue
		var n := (grid[ny] as String)[nx]
		if n == "~" or n == ",":
			return "wet"
		if n == "#":
			wall = true
	return "wall" if wall else "open"


## Émission (atlas `decals_e.png`, même grille) : enfant qui partage le MultiMesh, unshaded + additif
## (1 draw call de plus). `dc` = réglages `decals` du biome (`emission_energy`, `pulse_hz`).
func add_emission(tex: Texture2D, dc: Dictionary) -> MultiMeshInstance2D:
	var e := MultiMeshInstance2D.new()
	e.name = "Emission"
	e.multimesh = multimesh
	e.texture = tex
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_E
	mat.set_shader_parameter(&"atlas_grid", (material as ShaderMaterial).get_shader_parameter(&"atlas_grid"))
	mat.set_shader_parameter(&"energy", float(dc.get("emission_energy", 1.6)))
	mat.set_shader_parameter(&"pulse_hz", float(dc.get("pulse_hz", 0.0)))
	e.material = mat
	add_child(e)
	return e
