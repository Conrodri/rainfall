class_name Minimap
extends Control
## Minimap du HUD. Image de la carte construite UNE fois par étage (Image -> ImageTexture) depuis la
## grille ASCII de data/maps/<map_id>.json (méta map_id de la StageMap ; 1 cellule = 2 u = 128 px) :
## sol sombre, murs (#) clairs avec leur contour, eau (~ profonde, « , » peu profonde) bleue.
## Marqueurs relus au plus MARKER_HZ fois par seconde (aucune reconstruction d'image) : joueur
## (flèche), coffres non ouverts (couleur de rareté), piliers (état), téléporteur actif, boss vivants,
## capsules d'or (groupe `gold_capsules`, tant que can_interact() est vrai).
## Un clic / appui l'agrandit en plein écran, un second la referme.
## Le HUD la place via set_compact_rect(). Sans carte (tests, menus) : invisible.
## Cartes iso (StageMap.is_iso) : image + marqueurs passent par map_transform() = rotation 45° puis écrasement
## vertical 0,5 (losange orienté comme l écran), flèche du joueur en direction écran ; cartes plates inchangées.
## Redessin seulement si un marqueur a bougé. Habillage (lot U1) : minimap_frame/minimap_player/minimap_icons
## de assets/sprites/ui/da/ si livrés, sinon le dessin provisoire (formes) sert de repli.

signal expanded_changed(expanded: bool)

const MAPS_DIR := "res://data/maps/"
const UI_DIR := "res://assets/sprites/ui/da/" ## kit UI (lot U1) : minimap_frame (anneau), minimap_player, minimap_chest[_large|_legendary], minimap_pillar, minimap_teleporter, minimap_boss, minimap_capsule
const FRAME_FILL := 0.9 ## part du diamètre de l anneau occupée par la carte (l intérieur du cadre est transparent)
const CELL_PX := 128.0 ## 1 cellule de grille = 2 u
const IMG_K := 6 ## pixels d'image par cellule (contour fin d'1 px)
const MARKER_HZ := 10.0
const COL_FLOOR := Color(0.09, 0.1, 0.12)
const COL_WALL := Color(0.62, 0.63, 0.66)
const COL_WALL_EDGE := Color(0.93, 0.93, 0.96)
## Eau (cohérente avec le jeu, retour joueur 22/10/2026) : « ~ » profonde bloquante = bleu soutenu + liseré
## d'écume clair côté praticable (comme sa rive en jeu) ; « , » peu profonde praticable = sol à peine bleuté.
const COL_DEEP := Color(0.1, 0.24, 0.52)
const COL_DEEP_EDGE := Color(0.36, 0.5, 0.62) ## liseré d écume atténué (29/10/2026)
const COL_SHALLOW := Color(0.13, 0.19, 0.24)
const COL_BG := Color(0.0, 0.0, 0.0, 0.6)
const COL_BRONZE := Color(0.62, 0.45, 0.25, 0.85) ## liseré fin du losange
const COL_BORDER := Color(1.0, 1.0, 1.0, 0.35)
const COL_PLAYER := Color(1.0, 1.0, 1.0)
const COL_BOSS := Color(1.0, 0.15, 0.15)
const COL_TELEPORTER := Color(0.7, 0.45, 1.0)
const COL_GOLD := Color(1.0, 0.82, 0.2)
const PILLAR_COLORS := {
	&"locked": Color(0.45, 0.45, 0.5),
	&"ready": Color(1.0, 0.9, 0.3),
	&"active": Color(1.0, 0.45, 0.1),
	&"done": Color(0.35, 0.9, 0.45),
}
const CHEST_COLORS := { # même code couleur que Chest.COLORS (rareté)
	&"petit": Color(0.78, 0.6, 0.38),
	&"large": Color(0.29, 0.56, 0.89),
	&"legendaire": Color(1.0, 0.72, 0.11),
	&"boss": Color(0.78, 0.29, 0.87),
	&"guardian": Color(0.3, 0.85, 0.8),
}

static var _json_cache := {} ## map_id -> Dictionary
static var _tex_cache := {} ## chemin relatif -> Texture2D ou null (absente)

var expanded := false
var map_texture: ImageTexture = null
var map_image: Image = null ## image source (tests)
var build_count := 0 ## nombre de constructions d'image (tests : une par étage)
var iso := false ## carte isométrique : losange (rotation 45° puis écrasement vertical 0,5), comme l'écran de jeu
var redraw_count := 0 ## nombre de _draw (tests : pas de redessin inutile)

var _map: Node2D = null
var _grid: Array = [] ## grille du JSON de la carte courante
var _secret_cells := {} ## Vector2i -> id du secret (porte « D » et sol scellé « : » de sa salle)
var _secrets_open := {} ## id du secret -> true une fois la porte ouverte (dessinés comme sol), sinon comme mur
var _frame := Transform2D.IDENTITY ## repère carte -> logique local de la carte (StageMap.frame_of)
var _sig := -1 ## signature des marqueurs au dernier dessin
var _grid_size := Vector2i.ZERO
var _compact := Rect2()
var _tick := 0.0
var _player_pos := Vector2.ZERO ## positions déjà converties en 0..1 dans la carte
var _player_dir := Vector2.DOWN
var _has_player := false
var _chests: Array = [] ## [Vector2 uv, Color]
var _pillars: Array = []
var _bosses: PackedVector2Array = PackedVector2Array()
var _teleporter := Vector2(-1.0, -1.0)
var _gold: PackedVector2Array = PackedVector2Array()
var jam_left := 0.0 ## brouillage restant (s) : set_jammed
var _jam_seed := 0


## Fiche JSON d'une carte (cache), {} si absente.
static func map_json(map_id: String) -> Dictionary:
	if map_id.is_empty():
		return {}
	if _json_cache.has(map_id):
		return _json_cache[map_id]
	var path := MAPS_DIR + map_id + ".json"
	var out := {}
	if FileAccess.file_exists(path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary:
			out = d
	_json_cache[map_id] = out
	return out


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	add_to_group(&"minimap") # brouillage par les mini-boss (MiniBossBrain.jam_minimap -> set_jammed)


## API publique : brouille la minimap `duration` s (cri de la Nuée aveugle) : carte voilée de neige, marqueurs
## masqués sauf le joueur. Un nouvel appel prolonge (jamais raccourcit). 0 = lève le brouillage.
func set_jammed(duration: float) -> void:
	jam_left = 0.0 if duration <= 0.0 else maxf(jam_left, duration)
	_sig = -1
	queue_redraw()


func is_jammed() -> bool:
	return jam_left > 0.0


## Rectangle (coordonnées du parent) de la minimap repliée.
func set_compact_rect(r: Rect2) -> void:
	_compact = r
	if not expanded:
		position = r.position
		size = r.size


func get_compact_rect() -> Rect2:
	return _compact


func set_expanded(on: bool) -> void:
	if on == expanded:
		return
	expanded = on
	if on:
		move_to_front() # au-dessus des autres éléments du HUD
		var vp := get_viewport_rect().size
		position = Vector2.ZERO
		size = vp
	else:
		position = _compact.position
		size = _compact.size
	queue_redraw()
	expanded_changed.emit(on)


func _gui_input(event: InputEvent) -> void:
	# souris (PC) ; sur mobile le toucher émule la souris (emulate_mouse_from_touch)
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		set_expanded(not expanded)
		accept_event()


func _process(delta: float) -> void:
	if jam_left > 0.0:
		jam_left = maxf(jam_left - delta, 0.0)
		if jam_left <= 0.0:
			_sig = -1
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0 / MARKER_HZ
	if jam_left > 0.0:
		_jam_seed += 1 # neige qui grésille à MARKER_HZ (redessin forcé par la signature)
	var sm := get_tree().get_first_node_in_group(&"stage_manager")
	var m: Node2D = sm.get(&"map") as Node2D if sm != null else null
	if m != _map or (m != null and not is_instance_valid(_map)):
		_bind_map(m)
	if _map == null or map_texture == null:
		if visible:
			visible = false
			if expanded:
				set_expanded(false)
		return
	visible = true
	if expanded and size != get_viewport_rect().size:
		size = get_viewport_rect().size
	_refresh_markers(sm)
	# redessin seulement si un marqueur, la taille ou l'état a changé (pas de redraw inutile à l'arrêt)
	var sig := hash([_has_player, _player_pos, _player_dir, _chests, _pillars, _bosses, _teleporter, _gold, expanded, size, _jam_seed if jam_left > 0.0 else -1])
	if sig != _sig:
		_sig = sig
		queue_redraw()


## Construit l'image de la carte (une seule fois par étage).
func _bind_map(m: Node2D) -> void:
	if is_instance_valid(_map) and _map is StageMap and (_map as StageMap).secret_door_opened.is_connected(_on_secret_door_opened):
		(_map as StageMap).secret_door_opened.disconnect(_on_secret_door_opened)
	_map = m
	map_texture = null
	_secrets_open.clear()
	_secret_cells.clear()
	_sig = -1
	_frame = StageMap.frame_of(m) if m != null else Transform2D.IDENTITY
	iso = m is StageMap and (m as StageMap).is_iso()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if iso else CanvasItem.TEXTURE_FILTER_NEAREST # image tournée : pas de crénelage
	if m == null:
		return
	var data := map_json(String(m.get_meta(&"map_id", "")))
	var grid: Array = data.get("grid", [])
	if grid.is_empty():
		return
	var h := grid.size()
	var w := 0
	for row in grid:
		w = maxi(w, String(row).length())
	_grid_size = Vector2i(w, h)
	_grid = grid
	_index_secret_cells(data)
	if m is StageMap:
		(m as StageMap).secret_door_opened.connect(_on_secret_door_opened)
	_build_image()


## Cases de la salle scellée (porte « D » + sol « : » joint par proximité) -> id du secret.
func _index_secret_cells(data: Dictionary) -> void:
	for sc: Dictionary in data.get("secrets", []):
		var id := StringName(sc["id"])
		var queue: Array[Vector2i] = []
		for c in sc.get("door_cells", []):
			var v := Vector2i(int(c[0]), int(c[1]))
			_secret_cells[v] = id
			queue.append(v)
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = cur + d
				if not _secret_cells.has(n) and _raw_cell(n.x, n.y) == ":":
					_secret_cells[n] = id
					queue.append(n)


func _raw_cell(x: int, y: int) -> String:
	return _cell(_grid, x, y)


func _on_secret_door_opened(secret_id: StringName) -> void:
	_secrets_open[secret_id] = true
	_build_image()
	_sig = -1


## Case vue par la minimap : porte scellée et salle scellée = mur tant que la porte est fermée, sol après ouverture.
func _vis_cell(x: int, y: int) -> String:
	var c := _raw_cell(x, y)
	if c != "D" and c != ":":
		return c
	var id: Variant = _secret_cells.get(Vector2i(x, y), null)
	if id != null and _secrets_open.has(id):
		return "."
	return "#" if id != null or c == "D" else "."


func _build_image() -> void:
	var grid := _grid
	var w := _grid_size.x
	var h := _grid_size.y
	var img := Image.create(w * IMG_K, h * IMG_K, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # hors carte (StageMap.VOID_CHAR) : transparent
	for y in h:
		for x in w:
			var c := _vis_cell(x, y)
			var r := Rect2i(x * IMG_K, y * IMG_K, IMG_K, IMG_K)
			if c == "#":
				img.fill_rect(r, COL_WALL)
				# contour : bord de la cellule de mur qui touche une cellule non-mur
				if _vis_cell(x - 1, y) != "#":
					img.fill_rect(Rect2i(r.position.x, r.position.y, 1, IMG_K), COL_WALL_EDGE)
				if _vis_cell(x + 1, y) != "#":
					img.fill_rect(Rect2i(r.end.x - 1, r.position.y, 1, IMG_K), COL_WALL_EDGE)
				if _vis_cell(x, y - 1) != "#":
					img.fill_rect(Rect2i(r.position.x, r.position.y, IMG_K, 1), COL_WALL_EDGE)
				if _vis_cell(x, y + 1) != "#":
					img.fill_rect(Rect2i(r.position.x, r.end.y - 1, IMG_K, 1), COL_WALL_EDGE)
			elif c == "~":
				img.fill_rect(r, COL_DEEP)
				# écume : bord qui touche une cellule praticable (ni mur ni eau profonde)
				if not _vis_cell(x - 1, y) in ["#", "~", StageMap.VOID_CHAR]:
					img.fill_rect(Rect2i(r.position.x, r.position.y, 1, IMG_K), COL_DEEP_EDGE)
				if not _vis_cell(x + 1, y) in ["#", "~", StageMap.VOID_CHAR]:
					img.fill_rect(Rect2i(r.end.x - 1, r.position.y, 1, IMG_K), COL_DEEP_EDGE)
				if not _vis_cell(x, y - 1) in ["#", "~", StageMap.VOID_CHAR]:
					img.fill_rect(Rect2i(r.position.x, r.position.y, IMG_K, 1), COL_DEEP_EDGE)
				if not _vis_cell(x, y + 1) in ["#", "~", StageMap.VOID_CHAR]:
					img.fill_rect(Rect2i(r.position.x, r.end.y - 1, IMG_K, 1), COL_DEEP_EDGE)
			elif c == ",":
				img.fill_rect(r, COL_SHALLOW)
			elif c != StageMap.VOID_CHAR:
				img.fill_rect(r, COL_FLOOR)
	map_image = img
	map_texture = ImageTexture.create_from_image(img)
	build_count += 1


## Hors grille = mur (les cellules « # » du pourtour ne reçoivent pas de contour extérieur).
static func _cell(grid: Array, x: int, y: int) -> String:
	if y < 0 or y >= grid.size():
		return "#"
	var row := String(grid[y])
	if x < 0 or x >= row.length():
		return "#"
	return row[x]


## Position globale -> coordonnées 0..1 dans la grille (origine de la carte au centre).
## Carte iso : le point local (repère logique) est d'abord ramené en repère carte (grille tournée de 45°).
func _uv(global_pos: Vector2) -> Vector2:
	var half := Vector2(_grid_size) * CELL_PX * 0.5
	var l := _frame.affine_inverse() * _map.to_local(global_pos) + half
	return l / (half * 2.0)


func _refresh_markers(sm: Node) -> void:
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	_has_player = p != null
	if p != null:
		_player_pos = _uv(p.global_position)
		var f: Variant = p.get(&"facing")
		if f is Vector2 and (f as Vector2).length_squared() > 0.0:
			_player_dir = f
	_chests.clear()
	for c in sm.get(&"chests"):
		if is_instance_valid(c) and c.is_inside_tree():
			if c.has_method(&"is_opened") and c.is_opened(): # ouverture commencée (Chest)
				continue
			_chests.append([_uv(c.global_position), CHEST_COLORS.get(c.get(&"kind"), Color.WHITE), c.get(&"kind")])
	_pillars.clear()
	for pl in sm.get(&"pillars"):
		if is_instance_valid(pl) and pl.is_inside_tree():
			_pillars.append([_uv(pl.global_position), PILLAR_COLORS.get(pl.get(&"state"), Color.WHITE)])
	_bosses.clear()
	for b in get_tree().get_nodes_in_group(&"bosses"):
		if b is Node2D and bool(b.get(&"active")) and (b as Node2D).is_inside_tree():
			_bosses.append(_uv((b as Node2D).global_position))
	_gold.clear()
	for g in get_tree().get_nodes_in_group(&"gold_capsules"):
		if g is Node2D and g.has_method(&"can_interact") and g.can_interact():
			_gold.append(_uv((g as Node2D).global_position))
	_teleporter = Vector2(-1.0, -1.0)
	var tp: Node2D = sm.get(&"teleporter") as Node2D
	if tp != null and is_instance_valid(tp) and bool(tp.get(&"active")):
		_teleporter = _uv(tp.global_position)


## Matrice uv (0..1 dans la grille) -> pixels du contrôle. Carte plate : grille ajustée en conservant
## les proportions. Carte iso : mêmes étapes que la caméra de jeu (grille -> logique par Rot(+45°) puis
## écrasement vertical Iso.SQUASH), le losange obtenu est ajusté et centré dans la zone disponible.
func map_transform() -> Transform2D:
	if _grid_size == Vector2i.ZERO:
		return Transform2D.IDENTITY
	var area := Rect2(Vector2.ZERO, size)
	if expanded:
		area = area.grow(-minf(size.x, size.y) * 0.05)
	var pad := maxf(4.0, size.y * 0.03)
	area = area.grow(-pad)
	if false: # ancien cadre rond retiré
		area = Rect2(area.get_center(), Vector2.ZERO).grow(_frame_side() * 0.5 * FRAME_FILL * (1.0 if iso else 0.72))
	var gs := Vector2(_grid_size)
	# uv -> cellules, origine au centre de la carte
	var t := Transform2D(Vector2(gs.x, 0.0), Vector2(0.0, gs.y), -gs * 0.5)
	if iso:
		var squash := Transform2D(Vector2(1.0, 0.0), Vector2(0.0, Iso.SQUASH), Vector2.ZERO)
		t = squash * Iso.map_xform() * t
	var b := Rect2(t * Vector2.ZERO, Vector2.ZERO)
	for c in [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		b = b.expand(t * c)
	var k := minf(area.size.x / b.size.x, area.size.y / b.size.y)
	var fit := Transform2D(Vector2(k, 0.0), Vector2(0.0, k), area.get_center() - b.get_center() * k)
	return fit * t


## Position uv (0..1) -> pixel du contrôle.
func uv_to_screen(uv: Vector2) -> Vector2:
	return map_transform() * uv


## Rectangle englobant de la carte affichée dans le contrôle (le losange en iso).
func map_rect() -> Rect2:
	if _grid_size == Vector2i.ZERO:
		return Rect2()
	var t := map_transform()
	var r := Rect2(t * Vector2.ZERO, Vector2.ZERO)
	for c in [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		r = r.expand(t * c)
	return r


## Texture d'UI livrée (lot U1, assets/sprites/ui/da/), null si absente : le dessin provisoire sert alors.
## Côté (px, échelle 1) de la minimap repliée.
static func compact_px() -> float:
	return 380.0 # losange seul : +45 % (264 -> 380), retour joueur « trop petite »


static func ui_texture(rel: String) -> Texture2D:
	if _tex_cache.has(rel):
		return _tex_cache[rel]
	var tex: Texture2D = null
	var path := UI_DIR + rel
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[rel] = tex
	return tex


## Icône de marqueur centrée en `q`, côté `side` px ; false si la texture n'est pas livrée.
func _draw_icon(name: String, q: Vector2, side: float, tint := Color.WHITE) -> bool:
	var tex := ui_texture("minimap_%s.png" % name)
	if tex == null:
		return false
	draw_texture_rect(tex, Rect2(q - Vector2(side, side) * 0.5, Vector2(side, side)), false, tint)
	return true


## Côté du carré qui porte l'anneau (minimap_frame) : tout le contrôle replié, 90 % une fois agrandi.
func _frame_side() -> float:
	return minf(size.x, size.y) * (0.9 if expanded else 1.0) - maxf(4.0, size.y * 0.03) * 2.0


func _draw() -> void:
	if map_texture == null:
		return
	redraw_count += 1
	var xf := map_transform()
	var mr := map_rect()
	if expanded:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var frame := mr.grow(maxf(3.0, mr.size.y * 0.02))
	var frame_tex: Texture2D = null # pas de cadre rond (décision du joueur) : carte en losange seule, liseré bronze fin
	if frame_tex != null:
		var fr := _frame_side() * 0.5 * FRAME_FILL
		draw_circle(mr.get_center(), fr, COL_BG)
	elif iso:
		pass # hors carte transparent : la carte organique se découpe seule (plus de losange de fond ni de liseré)
	else:
		draw_rect(frame, COL_BG)
		draw_rect(frame, COL_BORDER, false, 2.0)
	# image de la carte : le carré uv (0..1) passe par la même matrice que les marqueurs
	draw_set_transform_matrix(xf)
	draw_texture_rect(map_texture, Rect2(0.0, 0.0, 1.0, 1.0), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var jammed := jam_left > 0.0
	if jammed:
		_draw_jam(xf)
	if frame_tex != null:
		var fs := _frame_side()
		draw_texture_rect(frame_tex, Rect2(mr.get_center() - Vector2(fs, fs) * 0.5, Vector2(fs, fs)), false)
	var u := maxf(mr.size.y, mr.size.x) / 50.0 ## taille de marqueur relative à la carte affichée
	u = clampf(u, 3.0, 14.0)
	for c in ([] if jammed else _chests):
		var q := xf * (c[0] as Vector2)
		var ck: StringName = c[2] if c.size() > 2 else &"petit"
		var cname := "chest_legendary" if (ck == &"legendaire" or ck == &"boss") else ("chest_large" if (ck == &"large" or ck == &"guardian") else "chest")
		if not _draw_icon(cname, q, u * 2.6):
			draw_rect(Rect2(q - Vector2(u, u) * 0.6, Vector2(u, u) * 1.2), c[1])
	for g in (PackedVector2Array() if jammed else _gold):
		var q := xf * (g as Vector2)
		if not _draw_icon("capsule", q, u * 2.0):
			draw_circle(q, u * 0.55, COL_GOLD)
	for pl in ([] if jammed else _pillars):
		var q := xf * (pl[0] as Vector2)
		if _draw_icon("pillar", q, u * 2.6):
			draw_circle(q + Vector2(0, u * 1.5), u * 0.5, pl[1]) # état du pilier : pastille sous l icône (l icône reste lisible)
			continue
		var d := u * 1.1
		var poly := PackedVector2Array([q + Vector2(0, -d), q + Vector2(d, 0), q + Vector2(0, d), q + Vector2(-d, 0)])
		draw_colored_polygon(poly, pl[1])
		poly.append(poly[0])
		draw_polyline(poly, Color(0, 0, 0, 0.8), 1.0)
	if _teleporter.x >= 0.0 and not jammed:
		var q := xf * _teleporter
		if not _draw_icon("teleporter", q, u * 3.2):
			draw_circle(q, u * 1.1, COL_TELEPORTER)
			draw_arc(q, u * 1.6, 0.0, TAU, 20, COL_TELEPORTER, 1.5)
	for b in (PackedVector2Array() if jammed else _bosses):
		var q := xf * (b as Vector2)
		if not _draw_icon("boss", q, u * 3.0):
			draw_circle(q, u * 1.3, Color(0, 0, 0, 0.85))
			draw_circle(q, u, COL_BOSS)
	if _has_player:
		var q := xf * _player_pos
		var dir := player_screen_dir()
		var ptex := ui_texture("minimap_player.png")
		if ptex != null:
			# flèche orientée vers le haut au repos : tournée dans la direction écran du joueur
			draw_set_transform(q, dir.angle() + PI * 0.5, Vector2.ONE)
			var side := u * 3.4
			draw_texture_rect(ptex, Rect2(Vector2(side, side) * -0.5, Vector2(side, side)), false)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			return
		var side_v := dir.orthogonal()
		var a := u * 1.6
		var tri := PackedVector2Array([q + dir * a, q - dir * a * 0.6 + side_v * a * 0.7, q - dir * a * 0.6 - side_v * a * 0.7])
		draw_colored_polygon(tri, COL_PLAYER)
		tri.append(tri[0])
		draw_polyline(tri, Color(0, 0, 0, 0.9), 1.0)


## Brouillage (set_jammed) : voile sombre + neige grise qui grésille + bandes de balayage, dans le repère de la
## carte (losange en iso). Repli visuel sobre, tiré au hasard à chaque redessin (MARKER_HZ).
func _draw_jam(xf: Transform2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _jam_seed * 7919 + 13
	draw_set_transform_matrix(xf)
	draw_rect(Rect2(0.0, 0.0, 1.0, 1.0), Color(0.05, 0.06, 0.08, 0.78))
	var n := 34
	var c := 1.0 / float(n)
	for i in 260:
		var g := rng.randf_range(0.35, 0.95)
		draw_rect(Rect2(float(rng.randi() % n) * c, float(rng.randi() % n) * c, c, c), Color(g, g, g * 1.04, rng.randf_range(0.25, 0.7)))
	for k in 2: # bandes de balayage
		var y := fposmod(float(_jam_seed) * 0.037 + k * 0.5, 1.0)
		draw_rect(Rect2(0.0, y, 1.0, 0.035), Color(0.8, 0.85, 0.9, 0.22))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Direction du joueur telle qu'elle apparaît sur la minimap (en iso : direction écran, y écrasé).
func player_screen_dir() -> Vector2:
	var d := _player_dir.normalized()
	if iso:
		d = Iso.to_screen_dir(d).normalized()
	return d
