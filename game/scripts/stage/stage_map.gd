class_name StageMap
extends Node2D
## Carte d'étage. Contrat pour les cartes dessinées à la main : garder
## - un nœud « Visual » (décor, remplaçable librement),
## - des StaticBody2D couche 1 pour les obstacles et les bords,
## - des Marker2D dans les groupes `chest_spawn` (>= 16) et `pillar_spawn` (>= 6),
## - un Marker2D dans le groupe `player_start`.
## Le StageManager ne lit que ces marqueurs : changer la carte ne touche pas au reste.
##
## Repères (docs/Design_Isometrique.md §1.2) : méta `projection` = "iso45" -> la grille (Visual,
## Obstacles, Markers) est tournée de +45° dans le repère logique de la carte (to_map / from_map) ;
## absente ou "flat" -> repère carte = repère logique (cartes de test, vues avec la caméra iso mais sans
## rotation). Les 3 étages (terrasses_noyees, foret_brume, cite_rouille) sont en iso. L'API publique (get_player_start,
## local_pos, get_bounds, get_walkable_ratio) est en repère LOGIQUE local à la carte.
## Rendu iso (P0-d) : la caméra écrase le plan logique ; le sol et les murs suivent la grille tournée,
## avec les tuiles iso de Codex (ISO_TILES), sol en losanges 4 u, murs `block_*`, remparts et falaises de
## bord, fond d'abîme ; sans elles, prismes Polygon2D de BLOCK_HEIGHT_U (repli). Murs triés en y avec
## les entités, en fondu devant le joueur.

const MAP_HALF_SIZE_PX := 1920.0 ## 60 u * 64 px / 2 (informatif, carte de test)
const UNIT_PX := 64.0
const WALK_SAMPLE_PX := 32.0

var _rects: Array[Rect2] = [] ## rectangles d'obstacles en repère carte (alignés sur les axes)
var _rects_ready := false
var _inv_xf := Transform2D.IDENTITY
var _blocks := {} ## Vector2i (case de la grille) -> Sprite2D du mur ou Polygon2D du prisme (cartes iso)
var _faded: Array[Vector2i] = [] ## cases dont le mur est en fondu
var _player: Node2D = null
var _tint := {} ## teintes du substitut de biome (ISO_FALLBACK), vide avec les vraies tuiles du biome
var _ground_overlap := 0 ## ISO_GROUND_OVERLAP du biome (px de texture)
var _biome := "" ## biome de data/maps/<id>.json
var _vis_grid: Array = [] ## grille visuelle (D -> #, : -> .), mise à jour à l'ouverture d'une porte scellée
var _door_cells := {} ## Vector2i -> id du secret (cases « D » de la grille JSON)
var _doors_open := {} ## id du secret -> true une fois la porte ouverte
signal secret_door_opened(secret_id: StringName)
var iso_dir_used := "" ## dossier des tuiles iso effectivement posées (tests : vraies tuiles ou substitut)

const PROJECTION_ISO := "iso45"
const Z_GROUND := -20 ## même valeur qu'AmbianceManager.Z_GROUND (sol sous toutes les entités)
const BLOCK_HEIGHT_U := 1.25 ## §2.4 : obstacles intérieurs plafonnés à 1,25 u (< personnage ~1,4 u)
const BLOCK_FADE_ALPHA := 0.4
## Couleurs des prismes provisoires : dessus clair, face gauche (côté soleil haut-gauche), face droite sombre.
const BLOCK_TOP := Color(0.42, 0.43, 0.42)
const BLOCK_LEFT := Color(0.30, 0.30, 0.31)
const BLOCK_RIGHT := Color(0.19, 0.19, 0.21)
## Cases devant le joueur (repère carte : +x = bas-droite, +y = bas-gauche de l'écran) testées pour le fondu.
const FADE_OFFSETS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 1), Vector2i(1, 2)]


## TileSet (tuiles Blender 256 px = 4 u) par biome de data/maps/<id>.json.
## Sources : 0-3 sols, 4 eau profonde, 5 eau peu profonde, 6 falaise.
const BIOME_TILESETS := {
	"terrasses": "res://assets/sprites/terrain/terraces/terraces.tres",
	"foret": "res://assets/sprites/terrain/fog_forest/fog_forest.tres",
	"cite": "res://assets/sprites/terrain/rust_city/rust_city.tres",
}
## Tuiles iso livrées (lot C1, docs/Design_Isometrique.md §4.2) par biome ; absentes -> ancien sol + prismes.
const ISO_TILES := {
	"terrasses": "res://assets/sprites/terrain/terraces/iso/",
	"foret": "res://assets/sprites/terrain/fog_forest/iso/", ## lot F2 (22/10/2026) : mêmes 41 noms que C1, voir art/blender/terrain/f2_report.md
	"cite": "res://assets/sprites/terrain/rust_city/iso/", ## lot F3 (22/10/2026) : mêmes 41 noms, voir art/blender/terrain/f3_validation.json
	"cryptes": "res://assets/sprites/terrain/crypts/iso/", ## lot F4 (à venir, art/tools/night/requests_floor45.md §1) : mêmes 41 noms
	"source": "res://assets/sprites/terrain/source/iso/", ## lot F5 (à venir, requests_floor45.md §3) : mêmes 41 noms
}
## Biome dont le lot iso n'est pas encore livré (pas de `ground_a..d` dans ISO_TILES) : tuiles d'un autre
## biome, teintées vers la palette du biome (docs/Design_Etages.md §3) en attendant Codex. Teintes en
## self_modulate (le fondu des murs garde modulate.a) ; `emission` recolore l'accent émissif des `_e`.
## Entrée : {"dir", "ground", "water", "wall", "void", "emission"}. Vide depuis la livraison de F2 (forêt) ;
## mécanisme gardé pour un biome futur (ex. cite en iso avant son lot).
## Cryptes (étage 4) et Source (étage 5) : tuiles des terrasses (pierre, accent cyan d'eau), assombries et
## refroidies (Design_Etages §3 : sol #2E3238, eau noire #0E1419, cristal #BFF4FF) jusqu'aux lots F4 / F5.
const ISO_FALLBACK := {
	"cryptes": {"dir": "res://assets/sprites/terrain/terraces/iso/", "ground": Color(0.76, 0.8, 0.86), "water": Color(0.36, 0.44, 0.52),
		"wall": Color(0.72, 0.76, 0.84), "void": Color(0.5, 0.56, 0.66), "emission": Color(0.9, 1.0, 1.0)},
	"source": {"dir": "res://assets/sprites/terrain/terraces/iso/", "ground": Color(0.82, 0.86, 0.92), "water": Color(0.6, 0.78, 0.95),
		"wall": Color(0.76, 0.8, 0.88), "void": Color(0.45, 0.5, 0.62), "emission": Color(0.95, 1.0, 1.0)},
}
## Recouvrement des tuiles de sol iso (px de texture, par biome) : le bord en losange des tuiles est
## antialiasé (alpha 78/196 sur 2 px) et laissait voir l'abîme (pointillés clairs en losange). La grille
## est resserrée de (2k, k) px et la couche agrandie d'autant : chaque tuile chevauche ses voisines de
## ~k px, sans toucher à l'emprise ni aux repères. Forêt (bords antialiasés sur les 4 arêtes) et cité
## (F3 : arêtes hautes antialiasées, par sécurité) ; terrasses (C1) : tuiles débordantes, aucun joint
## constaté (simulation 3 × 3 et capture du 22/10/2026), laissées à 0.
const ISO_GROUND_OVERLAP := {"foret": 4, "cite": 4, "cryptes": 4, "source": 4} ## F4 / F5 : par sécurité, comme F2-F3
const GROUND_VARIANTS := ["ground_a", "ground_b", "ground_c", "ground_d"]
const BLOCK_VARIANTS := ["block_a", "block_b", "block_c"]
const WATER_TILES := {",": "water_shallow", "~": "water_deep"}
## Case de VIDE des grilles au contour organique (tools/gen_maps.py, 28/10/2026) : hors carte, abîme. Ni sol ni
## tuile ; collision (rectangles de la scène) ; jamais d'apparition. Les cases « # » qui la bordent reçoivent les
## tuiles de bord (rempart côté nord / ouest, falaise côté sud / est) d'après le côté où se trouve le vide.
const VOID_CHAR := " "
const SHALLOW_TILE_ALPHA := 0.4 ## « , » praticable : film d'eau sur le sol (les tuiles livrées sont aussi sombres que « ~ »)
## Espace billboard d'un rendu iso (R = 90,51 px/u) : SPRITE_K × UNSQUASH.
const ISO_SCALE := Vector2(Iso.SPRITE_K, Iso.SPRITE_K * 2.0)
const BLOCK_FOOT_OFFSET := Vector2(0.0, -64.0) ## centre d'emprise (128, 192) d'un cadre 256 × 256
const CLIFF_FOOT_OFFSET := Vector2(0.0, 128.0) ## centre d'emprise (128, 64) d'un cadre 256 × 384
const VOID_SCALE := 0.5 ## rig TOP 128 px/u -> 64 px/u logiques
const VOID_MARGIN_PX := 2048.0
## Atténuation du fond : l'abîme reçoit les mêmes lumières que le sol et ressortait plus clair que le plateau.
const VOID_TINT := Color(0.6, 0.6, 0.65)
## Par biome (multiplie VOID_TINT) : la cité, nuit d'orage la plus sombre, gardait un abîme plus clair que
## son pavé (gris bleuté qui « flotte ») ; ramené sous la valeur du sol.
const VOID_TINT_BIOME := {"cite": Color(0.62, 0.62, 0.66), "cryptes": Color(0.6, 0.62, 0.68), "source": Color(0.66, 0.68, 0.76)}
const SRC_DEEP := 4
const SRC_SHALLOW := 5
const SRC_CLIFF := 6
## Sources 0-3, tirage stable par bloc de 4 u. La source 3 (herbe, pont…) détonne en carrés isolés : exclue.
const FLOOR_WEIGHTS := [0.65, 0.25, 0.1, 0.0]


func _init() -> void:
	add_to_group(&"stage_map") # le Director trouve la carte par ce groupe
	y_sort_enabled = true # coffres, piliers, blocs triés avec le joueur et les monstres sous Main/World


func _ready() -> void:
	var vis := get_node_or_null(^"Visual") as CanvasItem
	if vis != null:
		vis.z_index = Z_GROUND # sinon, trié en y à l'origine, le sol couvrirait la moitié nord des entités
	_build_ground()
	set_process(not _blocks.is_empty())


# --- Repères ------------------------------------------------------------------

func is_iso() -> bool:
	return String(get_meta(&"projection", "")) == PROJECTION_ISO


## Repère carte -> repère logique local : Rot(+45°) en iso, identité sinon.
func map_xform() -> Transform2D:
	return Iso.map_xform() if is_iso() else Transform2D.IDENTITY


## Même chose pour un nœud quelconque (carte de test sans script : identité).
static func frame_of(m: Node) -> Transform2D:
	return (m as StageMap).map_xform() if m is StageMap else Transform2D.IDENTITY


## Logique local -> carte.
func to_map(p: Vector2) -> Vector2:
	return map_xform().affine_inverse() * p


## Carte -> logique local.
func from_map(p: Vector2) -> Vector2:
	return map_xform() * p


## Peint le sol depuis la grille ASCII de la carte (cellule = 2 u).
## Carte iso avec tuiles livrées (ISO_TILES, lot C1, docs/Design_Isometrique.md §4.2) : _build_iso().
## Sinon (cartes plates, ou tuiles iso absentes) : « Ground » = sol plein à 256 px ; « Decor » = eau et
## falaises, à l'échelle 0,5 (1 tuile = 1 cellule), tournés avec Visual en iso ; murs iso en prismes.
func _build_ground() -> void:
	var ground := get_node_or_null(^"Visual/Ground") as TileMapLayer
	var cells := get_node_or_null(^"Visual/Decor") as TileMapLayer
	var id := String(get_meta(&"map_id", ""))
	var json_path := "res://data/maps/%s.json" % id
	if ground == null or cells == null or id == "" or not FileAccess.file_exists(json_path):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	var biome := String(data.get("biome", ""))
	_biome = biome
	var grid: Array = _visual_grid(data)
	var size_px := Vector2(data["size_px"][0], data["size_px"][1])
	var origin := -size_px * 0.5
	var iso_dir: String = ISO_TILES.get(biome, "") if is_iso() else ""
	_tint = {}
	if is_iso() and not (iso_dir != "" and _has_textures(iso_dir, GROUND_VARIANTS)) and ISO_FALLBACK.has(biome):
		_tint = ISO_FALLBACK[biome]
		iso_dir = String(_tint["dir"])
	if iso_dir != "" and _has_textures(iso_dir, GROUND_VARIANTS):
		_ground_overlap = int(ISO_GROUND_OVERLAP.get(biome, 0)) if _tint.is_empty() else 0
		_build_iso(grid, origin, size_px, iso_dir, ground, cells)
		_build_props(grid, origin, biome)
		return
	var ts_path: String = BIOME_TILESETS.get(biome, "")
	if ts_path == "" or not ResourceLoader.exists(ts_path):
		return
	var tile_set := load(ts_path) as TileSet
	ground.tile_set = tile_set
	ground.position = origin
	var tiles := Vector2i(ceili(size_px.x / 256.0), ceili(size_px.y / 256.0))
	for y in tiles.y:
		for x in tiles.x:
			ground.set_cell(Vector2i(x, y), _floor_source(x, y), Vector2i.ZERO)
	cells.tile_set = tile_set
	cells.position = origin
	cells.scale = Vector2(0.5, 0.5)
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			var src := -1
			match row[x]:
				"#": src = SRC_CLIFF
				"~": src = SRC_DEEP
				",": src = SRC_SHALLOW
			if src >= 0:
				cells.set_cell(Vector2i(x, y), src, Vector2i.ZERO)
	_build_outlines(grid, origin)
	if is_iso():
		_build_blocks(grid, origin, "")


# --- Tuiles iso (lot C1) ------------------------------------------------------

## Sol, eau, murs, bords et fond d'abîme d'une carte iso (§4.2) :
## - Ground : TileMapLayer iso DIAMOND_DOWN, tuiles 512×256 = 4 × 4 u (ground_a..d tirées par hachage
##   de bloc), Decor : 256×128 = 1 case (water_shallow « , », water_deep « ~ ») ; tous deux en espace
##   billboard (échelle ISO_SCALE, non tournés), donc hors de la rotation de Visual ;
## - fond : void_1024 répété (rig TOP, affiché à 0,5) autour de la carte, z −21 ;
## - murs « # » intérieurs : block_a..c, rangée nord : rampart_ne, colonne ouest : rampart_nw, coin nord :
##   rampart_corner_n (Sprite2D triés en y sous « Blocks », pied = centre d'emprise) ; rangée sud :
##   cliff_sw, colonne est : cliff_se, coins sud / ouest / est : cliff_corner_* (au niveau du sol, sous
##   « Edges », dessinés du fond vers l'avant). Texture absente -> prisme Polygon2D pour cette case.
func _build_iso(grid: Array, origin: Vector2, size_px: Vector2, dir: String, ground: TileMapLayer, cells: TileMapLayer) -> void:
	var vis := get_node(^"Visual") as Node2D
	var inv_vis := vis.transform.affine_inverse() # enfants de Visual ramenés en repère logique
	# sol : bloc (tx, ty) de 4 u -> cellule iso (tx, ty) ; centre du bloc (0, 0) aligné sur la carte
	iso_dir_used = dir
	var ov := _ground_overlap
	ground.tile_set = _iso_tileset(dir, GROUND_VARIANTS, Vector2i(512, 256), ov)
	var tiles := Vector2i(ceili(size_px.x / 256.0), ceili(size_px.y / 256.0))
	for y in tiles.y:
		for x in tiles.x:
			if _block_all_void(grid, x, y): # bloc de 4 u entièrement hors carte : pas de sol
				continue
			ground.set_cell(Vector2i(x, y), _variant(Vector2i(x, y), GROUND_VARIANTS.size()), Vector2i.ZERO)
	_place_billboard_layer(ground, inv_vis, from_map(origin + Vector2(128.0, 128.0)), 512.0 / float(512 - 2 * ov))
	ground.self_modulate = _tint.get("ground", Color.WHITE)
	_build_void_mask(grid, origin, dir, vis)
	cells.self_modulate = _tint.get("water", Color.WHITE)
	# eau : une tuile par case
	var water_names: Array = []
	for n in WATER_TILES.values():
		water_names.append(n)
	if _has_textures(dir, water_names):
		cells.tile_set = _iso_tileset(dir, water_names, Vector2i(256, 128))
		# eau peu profonde « , » (praticable) : tuile translucide, le sol reste visible dessous (lisibilité)
		var sh_src := cells.tile_set.get_source(water_names.find("water_shallow")) as TileSetAtlasSource
		sh_src.get_tile_data(Vector2i.ZERO, 0).modulate = Color(1.0, 1.0, 1.0, SHALLOW_TILE_ALPHA)
		for y in grid.size():
			var row: String = grid[y]
			for x in row.length():
				if WATER_TILES.has(row[x]):
					cells.set_cell(Vector2i(x, y), water_names.find(WATER_TILES[row[x]]), Vector2i.ZERO)
		_place_billboard_layer(cells, inv_vis, from_map(origin + Vector2(64.0, 64.0)))
	_build_void(dir, inv_vis)
	_build_outlines(grid, origin)
	_build_blocks(grid, origin, dir)


## --- Props de biome (crochet du lot F2p, forêt : cèdre géant, sanctuaires à lanterne, arches de racines,
## champignons, pierre levée, souche) ----------------------------------------------------------------------
## Dossier par biome ; inactif tant qu'il ne contient pas `props.json` (les rendus non iso déjà présents
## dans props/fog_forest/ ne sont donc jamais posés). Manifeste (art/tools/night/requests_floor2.md) :
## {"density": 0.05, "props": [{"name": "stump", "weight": 3, "foot": [128, 200], "px_per_u": 90.51,
##   "fade": false, "shadow_rig": "top"}, …]}
## - name : `<name>.png` (+ `_n`, `_e`, `_shadow` facultatifs, chargés par NormalMaps / BakedShadows) ;
## - foot : pixel du cadre posé au centre de la case (défaut : milieu bas à 85 %) ;
## - px_per_u : densité du rendu (défaut 90,51 = rig MAP des tuiles iso) ;
## - fade : grand prop (cèdre) en fondu quand le joueur passe derrière (comme les murs) ;
## - shadow_rig : "top" = décalque `_shadow` rig TOP 128 px/u (comme `block_*`), sinon pas de décalque.
## Décor NON bloquant, seulement sur les cases « . » libres, loin du départ et des emplacements de coffres /
## piliers / événements ; tirage stable (hachage de case). Un prop bloquant passe par la grille (« # »).
const BIOME_PROPS := {"foret": "res://assets/sprites/props/fog_forest/", "cite": "res://assets/sprites/props/rust_city/",
	"cryptes": "res://assets/sprites/props/crypts/", "source": "res://assets/sprites/props/source/"} ## F4p / F5p (requests_floor45.md)
const PROPS_CLEAR_CELLS := 2 ## cases (2 u) laissées libres autour des repères de la carte


func _build_props(grid: Array, origin: Vector2, biome: String) -> void:
	var dir: String = BIOME_PROPS.get(biome, "")
	if dir == "" or not FileAccess.file_exists(dir + "props.json"):
		return
	var man = JSON.parse_string(FileAccess.get_file_as_string(dir + "props.json"))
	if not man is Dictionary or not (man as Dictionary).get("props") is Array:
		return
	var list: Array = []
	var total := 0.0
	for pr in man["props"]:
		if pr is Dictionary and ResourceLoader.exists(dir + String(pr.get("name", "")) + ".png"):
			list.append(pr)
			total += maxf(float(pr.get("weight", 1.0)), 0.0)
	var root := get_node_or_null(^"Blocks")
	if root != null and man.get("fixed") is Array:
		_build_fixed_props(man["fixed"], origin, dir, root)
	if list.is_empty() or total <= 0.0 or root == null:
		return
	var density := clampf(float(man.get("density", 0.05)), 0.0, 0.5)
	var keep: Array[Vector2i] = [] # cases réservées (repères en u -> cases de 2 u)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % String(get_meta(&"map_id", ""))))
	if data is Dictionary:
		var cand: Dictionary = data.get("candidates", {})
		for k in cand:
			for xy in cand[k]:
				keep.append(Vector2i(int(xy[0]) / 2, int(xy[1]) / 2))
		var ps: Array = data.get("player_start_u", [])
		if ps.size() == 2:
			keep.append(Vector2i(int(ps[0]) / 2, int(ps[1]) / 2))
	var n := 0
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			if row[x] != ".":
				continue
			var c := Vector2i(x, y)
			var r := float(absi(hash([c.x * 83492791, c.y * 2654435761, 17])) % 10000) / 10000.0
			if r >= density or _near_any(c, keep):
				continue
			var pick := r / density * total
			var pr: Dictionary = list[0]
			for cand_pr in list:
				pr = cand_pr
				pick -= maxf(float(cand_pr.get("weight", 1.0)), 0.0)
				if pick < 0.0:
					break
			var tex: Texture2D = load(dir + String(pr["name"]) + ".png")
			var size := tex.get_size()
			var foot: Array = pr.get("foot", [size.x * 0.5, size.y * 0.85])
			var center := from_map(origin + (Vector2(c) + Vector2(0.5, 0.5)) * OUTLINE_CELL_PX)
			var spr := Sprite2D.new()
			spr.name = "P%d_%d" % [x, y]
			spr.texture = tex
			spr.scale = Iso.UNSQUASH * (UNIT_PX / float(pr.get("px_per_u", Iso.RENDER_PX_PER_U)))
			spr.offset = size * 0.5 - Vector2(float(foot[0]), float(foot[1]))
			spr.position = center
			NormalMaps.apply_to_sprite(spr)
			if String(pr.get("shadow_rig", "")) == "top":
				spr.set_meta(&"shadow_decal_local", Transform2D(deg_to_rad(Iso.MAP_YAW_DEG) if is_iso() else 0.0, Vector2(0.5, 0.5), 0.0, center))
			spr.set_meta(&"prop", true)
			root.add_child(spr)
			if bool(pr.get("fade", false)) and not _blocks.has(c):
				_blocks[c] = spr # fondu devant le joueur (_process)
			n += 1
	set_meta(&"props_count", n)


## Props posés à un endroit fixe de la grille (manifeste `fixed` : [{"name", "pos_u": [x, y], "foot",
## "px_per_u", "fade", "shadow_rig"}], pos_u en u du repère carte comme les repères du JSON) : chapelles et
## cristal géant de la Source (requests_floor45.md §4). Décor non bloquant ; la collision vient de la grille.
func _build_fixed_props(fixed: Array, origin: Vector2, dir: String, root: Node) -> void:
	for pr in fixed:
		if not pr is Dictionary or not ResourceLoader.exists(dir + String(pr.get("name", "")) + ".png"):
			continue
		var pos: Array = pr.get("pos_u", [])
		if pos.size() != 2:
			continue
		var tex: Texture2D = load(dir + String(pr["name"]) + ".png")
		var size := tex.get_size()
		var foot: Array = pr.get("foot", [size.x * 0.5, size.y * 0.85])
		var center := from_map(origin + Vector2(float(pos[0]), float(pos[1])) * UNIT_PX)
		var spr := Sprite2D.new()
		spr.name = "F_%s_%d_%d" % [String(pr["name"]), int(pos[0]), int(pos[1])]
		spr.texture = tex
		spr.scale = Iso.UNSQUASH * (UNIT_PX / float(pr.get("px_per_u", Iso.RENDER_PX_PER_U)))
		spr.offset = size * 0.5 - Vector2(float(foot[0]), float(foot[1]))
		spr.position = center
		NormalMaps.apply_to_sprite(spr)
		if String(pr.get("shadow_rig", "")) == "top":
			spr.set_meta(&"shadow_decal_local", Transform2D(deg_to_rad(Iso.MAP_YAW_DEG) if is_iso() else 0.0, Vector2(0.5, 0.5), 0.0, center))
		spr.set_meta(&"prop", true)
		root.add_child(spr)
		var fc := Vector2i(int(pos[0]) / 2, int(pos[1]) / 2)
		if bool(pr.get("fade", false)) and not _blocks.has(fc):
			_blocks[fc] = spr


## Sprite posé au pied d'une source de lumière de règle d'ambiance (`light_rules`, ex. réverbères
## `steam_lamp` du canal de la Cité, lot F3P) : `<preset>_se` si l'eau est en ±y de la case (col de cygne
## le long de y), `<preset>_sw` sinon. Pied/échelle d'après art/blender/props/f3p_report.md. Rien si le
## sprite n'est pas livré dans le dossier de props du biome ; idempotent (nom par case).
const LIGHT_PROPS := {&"steam_lamp": {"foot": [128, 220], "fade": true, "shadow_rig": "top"}}

func add_light_prop(preset: StringName, cell: Vector2i, water_dir: Vector2i) -> Sprite2D:
	var spec: Dictionary = LIGHT_PROPS.get(preset, {})
	var dir: String = BIOME_PROPS.get(_biome, "")
	var root := get_node_or_null(^"Blocks")
	if spec.is_empty() or dir == "" or root == null:
		return null
	var pname := String(preset) + ("_se" if water_dir.y != 0 else "_sw")
	var node_name := "L_%s_%d_%d" % [pname, cell.x, cell.y]
	if root.has_node(node_name):
		return root.get_node(node_name) as Sprite2D
	if not ResourceLoader.exists(dir + pname + ".png"):
		return null
	var size_px := (get_meta(&"size_u", Vector2.ZERO) as Vector2) * UNIT_PX
	var center := from_map(-size_px * 0.5 + (Vector2(cell) + Vector2(0.5, 0.5)) * OUTLINE_CELL_PX)
	var tex: Texture2D = load(dir + pname + ".png")
	var foot: Array = spec["foot"]
	var spr := Sprite2D.new()
	spr.name = node_name
	spr.texture = tex
	spr.scale = Iso.UNSQUASH * (UNIT_PX / Iso.RENDER_PX_PER_U)
	spr.offset = tex.get_size() * 0.5 - Vector2(float(foot[0]), float(foot[1]))
	spr.position = center
	NormalMaps.apply_to_sprite(spr)
	if String(spec.get("shadow_rig", "")) == "top":
		spr.set_meta(&"shadow_decal_local", Transform2D(deg_to_rad(Iso.MAP_YAW_DEG) if is_iso() else 0.0, Vector2(0.5, 0.5), 0.0, center))
	spr.set_meta(&"prop", true)
	root.add_child(spr)
	if bool(spec.get("fade", false)) and not _blocks.has(cell):
		_blocks[cell] = spr
	return spr


static func _near_any(c: Vector2i, cells: Array[Vector2i]) -> bool:
	for kc in cells:
		if absi(kc.x - c.x) <= PROPS_CLEAR_CELLS and absi(kc.y - c.y) <= PROPS_CLEAR_CELLS:
			return true
	return false


## Pose une TileMapLayer iso en espace billboard (ISO_SCALE, sans rotation) sous Visual (tourné) :
## le centre de sa cellule (0, 0) tombe sur `center0` (repère logique local de la carte).
func _place_billboard_layer(layer: TileMapLayer, inv_vis: Transform2D, center0: Vector2, k: float = 1.0) -> void:
	var local := Transform2D(0.0, ISO_SCALE * k, 0.0, Vector2.ZERO)
	local.origin = center0 - local.basis_xform(layer.map_to_local(Vector2i.ZERO))
	layer.transform = inv_vis * local


## TileSet iso construit à l'exécution (une source par texture diffuse, éclairage plat), en cache.
## Le `<biome>_iso.tres` prévu au §4.2 pourra le remplacer sans toucher au reste.
static var _tileset_cache := {}


static func _iso_tileset(dir: String, names: Array, tile_size: Vector2i, overlap: int = 0) -> TileSet:
	var key := dir + ",".join(PackedStringArray(names)) + ":%d" % overlap
	if _tileset_cache.has(key):
		return _tileset_cache[key]
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = tile_size - Vector2i(2 * overlap, overlap) # pas de grille resserré : tuiles chevauchantes
	for i in names.size():
		var src := TileSetAtlasSource.new()
		src.texture = load(dir + String(names[i]) + ".png")
		src.texture_region_size = tile_size
		src.create_tile(Vector2i.ZERO)
		ts.add_source(src, i)
	_tileset_cache[key] = ts
	return ts


static func _has_textures(dir: String, names: Array) -> bool:
	for n in names:
		if not ResourceLoader.exists(dir + String(n) + ".png"):
			return false
	return true


## Variante stable et sans motif visible (hachage de la case, mélangé avec la taille de la carte).
func _variant(cell: Vector2i, n: int) -> int:
	var size_u := Vector2i(get_meta(&"size_u", Vector2.ZERO))
	return absi(hash([cell.x * 73856093, cell.y * 19349663, size_u.x, size_u.y])) % n


## Vrai si les 4 cases du bloc de sol (tx, ty) de 4 u sont du vide (ou hors grille).
func _block_all_void(grid: Array, tx: int, ty: int) -> bool:
	for dy in 2:
		for dx in 2:
			if not _is_void(grid, tx * 2 + dx, ty * 2 + dy):
				return false
	return true


func _is_void(grid: Array, x: int, y: int) -> bool:
	if y < 0 or y >= grid.size():
		return true
	var row: String = grid[y]
	return x < 0 or x >= row.length() or row[x] == VOID_CHAR


## Masque du vide des cartes au contour organique : les tuiles de sol (4 u) qui chevauchent la découpe sont
## recouvertes case par case (losanges de 2 u) par la texture de l'abîme, aux mêmes échelle et repère que le
## fond (_build_void) pour que le raccord soit invisible. Un seul Polygon2D (rectangles de cases fusionnés),
## sous Visual juste au-dessus du sol, sous l'eau, les rives et les falaises.
func _build_void_mask(grid: Array, origin: Vector2, dir: String, vis: Node2D) -> void:
	if not ResourceLoader.exists(dir + "void_1024.png"):
		return
	var cells := _cell_rects(grid, VOID_CHAR)
	if cells.is_empty():
		return
	var b := get_bounds().grow(VOID_MARGIN_PX)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var polys: Array = []
	var s := OUTLINE_CELL_PX
	for r: Rect2i in cells:
		var p0 := origin + Vector2(r.position) * s
		var idx := PackedInt32Array()
		for c in [p0, p0 + Vector2(r.size.x * s, 0.0), p0 + Vector2(r.size.x * s, r.size.y * s), p0 + Vector2(0.0, r.size.y * s)]:
			idx.append(pts.size())
			pts.append(c)
			uvs.append((vis.transform * c - b.position) / VOID_SCALE) # pixel de void_1024 sous ce coin (repère du fond)
		polys.append(idx)
	var poly := Polygon2D.new()
	poly.name = "VoidMask"
	poly.texture = load(dir + "void_1024.png")
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	poly.polygon = pts
	poly.uv = uvs
	poly.polygons = polys
	poly.self_modulate = VOID_TINT * (_tint.get("void", Color.WHITE) as Color) * (VOID_TINT_BIOME.get(_biome, Color.WHITE) as Color)
	vis.add_child(poly)
	var ground := vis.get_node_or_null(^"Ground")
	if ground != null:
		vis.move_child(poly, ground.get_index() + 1)


## Rectangles (en cases) couvrant toutes les cases `ch` de la grille, fusion gloutonne (même règle que
## tools/gen_maps.py rects()).
func _cell_rects(grid: Array, ch: String) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var h := grid.size()
	var used := {}
	for y in h:
		var row: String = grid[y]
		for x in row.length():
			if row[x] != ch or used.has(Vector2i(x, y)):
				continue
			var x2 := x
			while x2 + 1 < row.length() and row[x2 + 1] == ch and not used.has(Vector2i(x2 + 1, y)):
				x2 += 1
			var y2 := y
			while y2 + 1 < h:
				var ok := true
				var nrow: String = grid[y2 + 1]
				for i in range(x, x2 + 1):
					if i >= nrow.length() or nrow[i] != ch or used.has(Vector2i(i, y2 + 1)):
						ok = false
						break
				if not ok:
					break
				y2 += 1
			for yy in range(y, y2 + 1):
				for xx in range(x, x2 + 1):
					used[Vector2i(xx, yy)] = true
			out.append(Rect2i(x, y, x2 - x + 1, y2 - y + 1))
	return out


## Fond d'abîme (void_1024, rig TOP : 1024 px = 8 u, affiché à 0,5) répété sur la boîte englobante
## de la carte élargie de VOID_MARGIN_PX : les coins du losange montrent l'abîme. Un seul sprite.
func _build_void(dir: String, inv_vis: Transform2D) -> void:
	if not ResourceLoader.exists(dir + "void_1024.png"):
		return
	var b := get_bounds().grow(VOID_MARGIN_PX)
	var spr := Sprite2D.new()
	spr.name = "Void"
	spr.texture = load(dir + "void_1024.png")
	spr.centered = false
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect = Rect2(Vector2.ZERO, b.size / VOID_SCALE)
	spr.z_index = -1 # Visual est à Z_GROUND : fond à Z_GROUND − 1
	spr.self_modulate = VOID_TINT * (_tint.get("void", Color.WHITE) as Color) * (VOID_TINT_BIOME.get(_biome, Color.WHITE) as Color)
	var vis := get_node(^"Visual")
	vis.add_child(spr)
	vis.move_child(spr, 0)
	spr.transform = inv_vis * Transform2D(0.0, Vector2(VOID_SCALE, VOID_SCALE), 0.0, b.position)


## Contour des cases infranchissables (retour joueur : on se bloque sans voir le mur).
## Trace les bords entre une case de mur « # » et une case praticable : trait sombre large puis trait
## clair, pour rester lisible sur tous les sols. L'eau profonde « ~ » a sa propre rive (_build_water_banks).
## Segments des murs rangés par case : ceux d'un mur en fondu sont masqués (_refresh_outline).
const OUTLINE_CELL_PX := 128.0
const OUTLINE_WALL := Color(1.0, 0.85, 0.55, 0.85)
const OUTLINE_SHADOW := Color(0.0, 0.0, 0.0, 0.55)

var _outline: Node2D = null
var _outline_cells := {} ## Vector2i -> PackedVector2Array (segments de mur de la case)
var _outline_walls := PackedVector2Array()


func _build_outlines(grid: Array, origin: Vector2) -> void:
	_outline_cells.clear()
	var h := grid.size()
	for y in h:
		var row: String = grid[y]
		for x in row.length():
			if row[x] != "#":
				continue
			var segs := _wall_segments(grid, origin, x, y)
			if not segs.is_empty():
				_outline_cells[Vector2i(x, y)] = segs
	_outline = Node2D.new()
	_outline.name = "WallOutline"
	get_node(^"Visual").add_child(_outline)
	_outline.draw.connect(func() -> void:
		if _outline_walls.is_empty():
			return
		_outline.draw_multiline(_outline_walls, OUTLINE_SHADOW, 9.0, true)
		_outline.draw_multiline(_outline_walls, OUTLINE_WALL, 4.0, true))
	_refresh_outline()
	_build_water_banks(grid, origin)


## Segments de contour d'une case de mur (arêtes qui touchent une case non solide).
func _wall_segments(grid: Array, origin: Vector2, x: int, y: int) -> PackedVector2Array:
	var segs := PackedVector2Array()
	var row: String = grid[y]
	var p := origin + Vector2(x, y) * OUTLINE_CELL_PX
	var s := OUTLINE_CELL_PX
	if y > 0 and not _solid(grid, x, y - 1):
		segs.append_array([p, p + Vector2(s, 0)])
	if y < grid.size() - 1 and not _solid(grid, x, y + 1):
		segs.append_array([p + Vector2(0, s), p + Vector2(s, s)])
	if x > 0 and not _solid(grid, x - 1, y):
		segs.append_array([p, p + Vector2(0, s)])
	if x < row.length() - 1 and not _solid(grid, x + 1, y):
		segs.append_array([p + Vector2(s, 0), p + Vector2(s, s)])
	return segs


## Grille du JSON pour le rendu : porte scellée « D » dessinée comme un mur, sol scellé « : » comme du sol.
## Mémorise les cases de porte (`_door_cells`) et la grille résultante (`_vis_grid`).
func _visual_grid(data: Dictionary) -> Array:
	var out: Array = []
	_door_cells.clear()
	var secrets: Array = data.get("secrets", [])
	for sc: Dictionary in secrets:
		for c in sc.get("door_cells", []):
			_door_cells[Vector2i(int(c[0]), int(c[1]))] = StringName(sc["id"])
	for row in data["grid"]:
		out.append(String(row).replace("D", "#").replace(":", "."))
	_vis_grid = out
	return out


## Ouvre la porte scellée `secret_id` : collision `Door_<id>` coupée, blocs retirés, contours et occluders refaits.
## Le NavField (Director.bind_map) est relancé par l'appelant (SecretRoom), qui sait quand les monstres sortent.
func open_secret_door(secret_id: StringName) -> void:
	if _doors_open.has(secret_id):
		return
	_doors_open[secret_id] = true
	var cs := get_node_or_null("Obstacles/Walls/Door_%s" % String(secret_id)) as CollisionShape2D
	if cs != null:
		cs.set_deferred(&"disabled", true)
	_rects_ready = false
	var size_px: Vector2 = get_meta(&"size_u", Vector2.ZERO) * UNIT_PX
	var origin := -size_px * 0.5
	var touched: Array[Vector2i] = []
	for cell: Vector2i in _door_cells:
		if _door_cells[cell] != secret_id:
			continue
		touched.append(cell)
		if _vis_grid.size() > cell.y:
			var row: String = _vis_grid[cell.y]
			_vis_grid[cell.y] = row.substr(0, cell.x) + "." + row.substr(cell.x + 1)
		if _blocks.has(cell):
			var b: Variant = _blocks[cell]
			_blocks.erase(cell)
			if is_instance_valid(b):
				(b as Node).queue_free()
		_faded.erase(cell)
		_outline_cells.erase(cell)
	for cell in touched: # les murs voisins gagnent l'arête côté porte
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + d
			if n.y < 0 or n.y >= _vis_grid.size() or n.x < 0 or n.x >= (_vis_grid[n.y] as String).length():
				continue
			if (_vis_grid[n.y] as String)[n.x] == "#":
				var segs := _wall_segments(_vis_grid, origin, n.x, n.y)
				if segs.is_empty():
					_outline_cells.erase(n)
				else:
					_outline_cells[n] = segs
	_refresh_outline()
	secret_door_opened.emit(secret_id)


## Rive de l'eau profonde « ~ » (retour joueur 22/10/2026 : « bleu clair praticable, bleu foncé non » ne se
## lisait pas d'un coup d'œil). Règle unique : ce qui bloque a un BORD. Sur chaque arête entre « ~ » et une case
## praticable (sol « . », eau peu profonde « , », repères) : encre cel #181210 côté sol, liseré d'écume clair
## côté eau, ombre portée de la berge qui s'estompe dans l'eau. L'eau peu profonde n'a aucun bord (sol mouillé).
## Une seule passe de dessin au chargement (aucun redessin par image). Texture d'écume Codex (lot WT1,
## SHORE_FOAM_TEX) si livrée, sinon traits provisoires en code.
const BANK_Z := 3 ## relatif à Visual (Z_GROUND -20) : -17, au-dessus de l'eau d'AmbianceWater (-18), sous les nuages (-16)
const BANK_INK := Color(0.094, 0.071, 0.063, 1.0) ## #181210, encre cel (art/briefs/STYLE_cel.md)
const BANK_FOAM := Color(0.5, 0.58, 0.64, 0.4) ## repli en traits : écume discrète (le blanc cru jurait avec la DA sombre, 29/10/2026)
const BANK_FOAM_TINT := Color(0.52, 0.6, 0.66, 0.42) ## teinte de la texture d'écume : grise-bleutée, alpha bas
const BANK_SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const BANK_INK_PX := 7.0
const BANK_FOAM_PX := 7.0
const BANK_SHADOW_PX := 34.0 ## ombre de berge (px carte) qui s'estompe vers le centre de l'eau
## Bande d'écume Codex (lot WT1, art/tools/night/_wt1.txt) : 256×32 raccordable en x, vue de dessus ; arête de la
## case à y = SHORE_FOAM_EDGE_PX (au-dessus : lèvre de berge côté sol ; en dessous : écume qui se fond dans l'eau).
const SHORE_FOAM_TEX := "res://assets/sprites/terrain/shore/shore_foam_256x32.png"
const SHORE_FOAM_EDGE_PX := 8.0

var water_bank: Node2D = null ## nœud « WaterBank » sous Visual (tests, captures)
var _bank_sides: Array = [] ## [[normale vers l'eau (Vector2), segments fusionnés (PackedVector2Array)], …]


func _build_water_banks(grid: Array, origin: Vector2) -> void:
	# côtés N, S, O, E de la case d'eau ; un tableau par côté (une arête fusionnée garde son côté)
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var sides: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	var s := OUTLINE_CELL_PX
	var h := grid.size()
	for y in h:
		var row: String = grid[y]
		for x in row.length():
			if row[x] != "~":
				continue
			var p := origin + Vector2(x, y) * s
			for i in 4:
				var nx := x + dirs[i].x
				var ny := y + dirs[i].y
				if ny < 0 or ny >= h or nx < 0 or nx >= (grid[ny] as String).length() or _solid(grid, nx, ny):
					continue
				match i:
					0: sides[i].append_array([p, p + Vector2(s, 0)])
					1: sides[i].append_array([p + Vector2(0, s), p + Vector2(s, s)])
					2: sides[i].append_array([p, p + Vector2(0, s)])
					3: sides[i].append_array([p + Vector2(s, 0), p + Vector2(s, s)])
	_bank_sides.clear()
	for i in 4:
		if not sides[i].is_empty():
			_bank_sides.append([-Vector2(dirs[i]), _merge_segments(sides[i])])
	if _bank_sides.is_empty():
		return
	water_bank = Node2D.new()
	water_bank.name = "WaterBank"
	water_bank.z_index = BANK_Z
	get_node(^"Visual").add_child(water_bank)
	water_bank.draw.connect(_draw_water_bank)
	water_bank.queue_redraw()


func _draw_water_bank() -> void:
	var tex: Texture2D = load(SHORE_FOAM_TEX) as Texture2D if ResourceLoader.exists(SHORE_FOAM_TEX) else null
	var clear := Color(BANK_SHADOW, 0.0)
	var ink := PackedVector2Array()
	var foam := PackedVector2Array()
	for side in _bank_sides:
		var inward: Vector2 = side[0]
		var segs: PackedVector2Array = side[1]
		for k in range(0, segs.size() - 1, 2):
			var a := segs[k]
			var b := segs[k + 1]
			var along := (b - a).normalized()
			water_bank.draw_polygon(PackedVector2Array([a, b, b + inward * BANK_SHADOW_PX, a + inward * BANK_SHADOW_PX]),
				PackedColorArray([BANK_SHADOW, BANK_SHADOW, clear, clear]))
			if tex != null:
				# repère local : x le long de l'arête, y vers l'eau ; bande répétée en x
				water_bank.draw_set_transform_matrix(Transform2D(along, inward, a))
				water_bank.draw_texture_rect(tex, Rect2(0.0, -SHORE_FOAM_EDGE_PX, a.distance_to(b), float(tex.get_height())), true, BANK_FOAM_TINT)
				water_bank.draw_set_transform_matrix(Transform2D.IDENTITY)
				continue
			# prolongés d'une demi-épaisseur : coins de la rive fermés (entrants et saillants)
			var ei := along * BANK_INK_PX * 0.5
			var ef := along * BANK_FOAM_PX * 0.5
			var oi := -inward * BANK_INK_PX * 0.5
			var of := inward * (BANK_FOAM_PX * 0.5 + 1.0)
			ink.append_array([a - ei + oi, b + ei + oi])
			foam.append_array([a - ef + of, b + ef + of])
	if not foam.is_empty():
		water_bank.draw_multiline(foam, BANK_FOAM, BANK_FOAM_PX, true)
	if not ink.is_empty():
		water_bank.draw_multiline(ink, BANK_INK, BANK_INK_PX, true)


## Recompose les segments de murs sans ceux des cases en fondu, puis redessine (au changement seulement).
func _refresh_outline() -> void:
	if _outline == null:
		return
	_outline_walls = PackedVector2Array()
	for cell in _outline_cells:
		if not _faded.has(cell):
			_outline_walls.append_array(_outline_cells[cell])
	_outline_walls = _merge_segments(_outline_walls)
	_outline.queue_redraw()


## Fusionne les segments alignés et jointifs (un segment par case au départ) : les extrémités
## antialiasées de deux segments superposées doublaient l'alpha à chaque jointure (pointillés clairs
## le long des murs et de l'eau, visibles surtout sur les terrasses).
static func _merge_segments(segs: PackedVector2Array) -> PackedVector2Array:
	var rows := {} # Vector2(axe, coordonnée fixe) -> [[a, b], …]
	for i in range(0, segs.size() - 1, 2):
		var p := segs[i]
		var q := segs[i + 1]
		var horiz := is_equal_approx(p.y, q.y)
		var key := Vector2(0.0 if horiz else 1.0, p.y if horiz else p.x)
		var a := minf(p.x, q.x) if horiz else minf(p.y, q.y)
		var b := maxf(p.x, q.x) if horiz else maxf(p.y, q.y)
		if not rows.has(key):
			rows[key] = []
		(rows[key] as Array).append(Vector2(a, b))
	var out := PackedVector2Array()
	for key: Vector2 in rows:
		var iv: Array = rows[key]
		iv.sort_custom(func(u: Vector2, v: Vector2) -> bool: return u.x < v.x)
		var cur: Vector2 = iv[0]
		for k in range(1, iv.size() + 1):
			var nxt: Vector2 = iv[k] if k < iv.size() else Vector2(INF, INF)
			if k < iv.size() and nxt.x <= cur.y + 0.01:
				cur.y = maxf(cur.y, nxt.y)
				continue
			if key.x == 0.0:
				out.append_array([Vector2(cur.x, key.y), Vector2(cur.y, key.y)])
			else:
				out.append_array([Vector2(key.y, cur.x), Vector2(key.y, cur.y)])
			cur = nxt
	return out


## Murs des cartes iso (une entrée de _blocks par case « # », trié en y sous « Blocks ») : sprites des
## tuiles iso si `dir` les fournit (voir _build_iso), sinon prismes provisoires (§2.2, phase 0).
func _build_blocks(grid: Array, origin: Vector2, dir: String) -> void:
	var root := Node2D.new()
	root.name = "Blocks"
	root.y_sort_enabled = true
	add_child(root)
	var edges: Node2D = null
	var edge_list: Array = [] # [y logique, Sprite2D] : bords au sol, dessinés du fond vers l'avant
	var s := OUTLINE_CELL_PX
	var h := grid.size()
	for y in h:
		var row: String = grid[y]
		var w := row.length()
		for x in w:
			if row[x] != "#":
				continue
			var cell := Vector2i(x, y)
			var center := from_map(origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * s)
			var tex := _wall_texture(grid, cell) if dir != "" else ""
			if tex != "" and ResourceLoader.exists(dir + tex + ".png"):
				var spr := Sprite2D.new()
				spr.name = "B%d_%d" % [x, y]
				spr.texture = load(dir + tex + ".png")
				spr.scale = ISO_SCALE
				NormalMaps.apply_to_sprite(spr) # enfant d'émission si _e
				if not _tint.is_empty(): # substitut de biome (ISO_FALLBACK) : diffus et accent émissif recolorés
					spr.self_modulate = _tint["wall"]
					for em in spr.get_children():
						if em is CanvasItem:
							(em as CanvasItem).self_modulate = _tint["emission"]
				if tex.begins_with("cliff"):
					spr.offset = CLIFF_FOOT_OFFSET
					if edges == null:
						edges = Node2D.new()
						edges.name = "Edges"
						var vis := get_node(^"Visual") as Node2D
						vis.add_child(edges)
						edges.transform = vis.transform.affine_inverse()
					spr.position = center
					edge_list.append([center.y, spr])
					continue
				spr.offset = BLOCK_FOOT_OFFSET
				spr.position = center
				if _door_cells.has(cell): # porte scellée : teinte chaude pour se lire comme un passage, sans ombre cuite
					spr.self_modulate = spr.self_modulate * Color(1.0, 0.84, 0.62)
				elif tex.begins_with("block"): # décalque d'ombre (rig TOP, repère carte, 0,5) posé par BakedShadows
					spr.set_meta(&"shadow_decal_local", Transform2D(deg_to_rad(Iso.MAP_YAW_DEG) if is_iso() else 0.0, Vector2(0.5, 0.5), 0.0, center))
				root.add_child(spr)
				_blocks[cell] = spr
			else:
				var poly := _prism(origin, x, y, grid)
				poly.position = center
				root.add_child(poly)
				_blocks[cell] = poly
	edge_list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for e in edge_list:
		edges.add_child(e[1])


## Tuile d'une case « # » : bord de carte ou mur intérieur, d'après le côté où se trouve le vide (case VOID_CHAR
## ou hors grille). Repère carte : vide au nord (y − 1) = arête haut-droite (rempart NE), à l'ouest (x − 1) =
## haut-gauche (rempart NW), au sud = bas-gauche (falaise SW), à l'est = bas-droite (falaise SE) ; deux côtés =
## pointe (coins). Sur l'ancien anneau rectangulaire, le résultat est le même que par position dans la grille.
func _wall_texture(grid: Array, c: Vector2i) -> String:
	var n := _is_void(grid, c.x, c.y - 1)
	var s := _is_void(grid, c.x, c.y + 1)
	var w := _is_void(grid, c.x - 1, c.y)
	var e := _is_void(grid, c.x + 1, c.y)
	if n and w:
		return "rampart_corner_n"
	if n and e:
		return "cliff_corner_e"
	if s and w:
		return "cliff_corner_w"
	if s and e:
		return "cliff_corner_s"
	if n:
		return "rampart_ne"
	if w:
		return "rampart_nw"
	if s:
		return "cliff_sw"
	if e:
		return "cliff_se"
	return BLOCK_VARIANTS[_variant(c, BLOCK_VARIANTS.size())]


## Prisme provisoire d'une case « # » (repli sans texture), relatif au centre logique de la case.
## Faces visibles seulement : le dessus, et les faces avant (+x carte = bas-droite, +y carte = bas-gauche)
## quand la case voisine n'est pas un mur.
func _prism(origin: Vector2, x: int, y: int, grid: Array) -> Polygon2D:
	var xf := map_xform()
	var lift := Vector2(0.0, Iso.lift_logical(BLOCK_HEIGHT_U))
	var s := OUTLINE_CELL_PX
	var row: String = grid[y]
	var c0 := origin + Vector2(x, y) * s
	var center := xf * (c0 + Vector2(s, s) * 0.5)
	# coins du carré de carte -> logique, relatifs au centre : N, E, S, W du losange
	var n := xf * c0 - center
	var e := xf * (c0 + Vector2(s, 0)) - center
	var so := xf * (c0 + Vector2(s, s)) - center
	var w := xf * (c0 + Vector2(0, s)) - center
	var pts := PackedVector2Array([n + lift, e + lift, so + lift, w + lift])
	var cols := PackedColorArray([BLOCK_TOP, BLOCK_TOP, BLOCK_TOP, BLOCK_TOP])
	var polys: Array = [PackedInt32Array([0, 1, 2, 3])]
	var open_y := y + 1 >= grid.size() or (grid[y + 1] as String)[x] != "#"
	var open_x := x + 1 >= row.length() or row[x + 1] != "#"
	if open_y: # face bas-gauche (W -> S)
		polys.append(PackedInt32Array([pts.size(), pts.size() + 1, pts.size() + 2, pts.size() + 3]))
		pts.append_array([w, so, so + lift, w + lift])
		cols.append_array([BLOCK_LEFT, BLOCK_LEFT, BLOCK_LEFT, BLOCK_LEFT])
	if open_x: # face bas-droite (S -> E)
		polys.append(PackedInt32Array([pts.size(), pts.size() + 1, pts.size() + 2, pts.size() + 3]))
		pts.append_array([so, e, e + lift, so + lift])
		cols.append_array([BLOCK_RIGHT, BLOCK_RIGHT, BLOCK_RIGHT, BLOCK_RIGHT])
	var poly := Polygon2D.new()
	poly.name = "B%d_%d" % [x, y]
	poly.polygon = pts
	poly.polygons = polys
	poly.vertex_colors = cols
	return poly


## Fondu (§2.4) : les murs juste devant le joueur (y logique plus grand, cases voisines côté
## caméra) passent à BLOCK_FADE_ALPHA, et leur contour au sol est masqué ; 7 cases testées par image.
func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	var want: Array[Vector2i] = []
	if _player != null:
		var lp := to_local(_player.global_position)
		var size_px := (get_meta(&"size_u", Vector2.ZERO) as Vector2) * UNIT_PX
		var cell := Vector2i(((to_map(lp) + size_px * 0.5) / OUTLINE_CELL_PX).floor())
		for off in FADE_OFFSETS:
			var b := _blocks.get(cell + off) as Node2D
			if b != null and b.position.y > lp.y:
				want.append(cell + off)
	if want == _faded:
		return
	for c in _faded:
		if not want.has(c) and is_instance_valid(_blocks.get(c)):
			(_blocks[c] as CanvasItem).modulate.a = 1.0
	for c in want:
		(_blocks[c] as CanvasItem).modulate.a = BLOCK_FADE_ALPHA
	_faded = want
	_refresh_outline()


func _solid(grid: Array, x: int, y: int) -> bool:
	var c := (grid[y] as String)[x]
	return c == "#" or c == "~" or c == VOID_CHAR


func _floor_source(x: int, y: int) -> int:
	var r := float(hash(Vector2i(x, y) + Vector2i(get_meta(&"size_u", Vector2.ZERO))) % 1000) / 1000.0
	for i in FLOOR_WEIGHTS.size():
		r -= FLOOR_WEIGHTS[i]
		if r < 0.0:
			return i
	return 0


## Biome de data/maps/<id>.json (lu au chargement du sol).
func biome() -> StringName:
	return StringName(_biome)


func get_player_start() -> Vector2:
	var m := _markers(&"player_start")
	return local_pos(m[0]) if not m.is_empty() else Vector2.ZERO


func get_chest_markers() -> Array[Marker2D]:
	return _markers(&"chest_spawn")


func get_pillar_markers() -> Array[Marker2D]:
	return _markers(&"pillar_spawn")


## Marqueurs de ce sous-arbre uniquement, triés par chemin (ordre stable pour la seed).
func _markers(group: StringName) -> Array[Marker2D]:
	var out: Array[Marker2D] = []
	if not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group(group):
		if n is Marker2D and is_ancestor_of(n):
			out.append(n)
	out.sort_custom(func(a: Marker2D, b: Marker2D) -> bool: return str(get_path_to(a)) < str(get_path_to(b)))
	return out


## Rectangle de la carte en repère carte (centré sur l'origine).
## Lit la méta `size_u` (en u) ; repli sur la taille en px de la carte de test.
func get_map_rect() -> Rect2:
	var size_px := Vector2(MAP_HALF_SIZE_PX, MAP_HALF_SIZE_PX) * 2.0
	if has_meta(&"size_u"):
		size_px = (get_meta(&"size_u") as Vector2) * UNIT_PX
	return Rect2(-size_px * 0.5, size_px)


## Limites de la carte (repère logique local) pour la caméra : boîte englobante du losange en iso
## (les coins montrent le fond, §2.4), le rectangle lui-même sinon.
func get_bounds() -> Rect2:
	return map_xform() * get_map_rect()


## Position locale (à la carte) d'un marqueur.
func local_pos(m: Node2D) -> Vector2:
	return to_local(m.global_position)


## Part (0..1) du disque (centre `pos` local logique, `radius` px) qui n'est dans aucun rectangle
## de CollisionShape2D (obstacles, eau profonde, murs) des StaticBody2D de la carte.
## Un disque est invariant par rotation : échantillonné directement en repère carte.
func get_walkable_ratio(pos: Vector2, radius: float) -> float:
	if not _rects_ready:
		_collect_rects()
	pos = to_map(pos)
	var total := 0
	var free := 0
	var step := WALK_SAMPLE_PX
	var y := -radius
	while y <= radius:
		var x := -radius
		while x <= radius:
			if x * x + y * y <= radius * radius:
				total += 1
				var p := pos + Vector2(x, y)
				var blocked := false
				for r in _rects:
					if r.has_point(p):
						blocked = true
						break
				if not blocked:
					free += 1
			x += step
		y += step
	return float(free) / float(maxi(total, 1))


func _collect_rects() -> void:
	_rects_ready = true
	_rects.clear()
	_inv_xf = map_xform().affine_inverse()
	_gather_rects(self)


func _gather_rects(n: Node) -> void:
	if n is StaticBody2D:
		for c in n.get_children():
			var cs := c as CollisionShape2D
			if cs != null and cs.shape is RectangleShape2D and not cs.disabled:
				var sz: Vector2 = (cs.shape as RectangleShape2D).size
				var xf: Transform2D = _inv_xf * _local_xf(cs) # repère carte : rectangle de nouveau aligné
				var ext := Vector2(absf(xf.x.x) * sz.x + absf(xf.y.x) * sz.y, absf(xf.x.y) * sz.x + absf(xf.y.y) * sz.y)
				_rects.append(Rect2(xf.origin - ext * 0.5, ext))
	for c in n.get_children():
		_gather_rects(c)


## Transform d'un nœud relatif à la carte (sans dépendre de l'arbre).
func _local_xf(n: Node2D) -> Transform2D:
	var xf := Transform2D.IDENTITY
	var cur: Node = n
	while cur != null and cur != self:
		if cur is Node2D:
			xf = (cur as Node2D).transform * xf
		cur = cur.get_parent()
	return xf


## Marqueurs `secret_spawn` de la carte (plaques, gardiens, porte), toutes portes scellées confondues.
func get_secret_markers() -> Array[Marker2D]:
	return _markers(&"secret_spawn")
