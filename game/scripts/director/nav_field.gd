class_name NavField
extends RefCounted
## Champ de flux (flow field) partagé par tous les monstres d'une carte.
##
## - Grille de 1 u (64 px, bordure bloquée d'une cellule) dérivée des formes de collision de la carte (StaticBody2D couche 1) :
##   une cellule est bloquée si son centre est dans une forme. Hors des bornes = bloqué.
## - BFS 8 voisins (sans couper les coins) depuis la cellule du joueur, calculé dans un tampon
##   arrière et étalé sur plusieurs frames (BUDGET_PER_FRAME cellules), puis échangé ; relancé
##   quand le joueur change de cellule, au plus toutes les MIN_RECOMPUTE_S secondes.
## - Requête par monstre O(1) amortie : « prochaine cellule » et « ligne de vue vers la cible »
##   calculées paresseusement une fois par cellule et par version du champ. En ligne de vue, le
##   monstre fonce droit sur le joueur ; sinon il vise le centre de la cellule à 2 pas.
## - Résolution de pénétration cercle / rectangle via une liste de rectangles par cellule.
## - Repères (docs/Design_Isometrique.md §1.2) : la grille, `rects` et `bounds` sont en repère CARTE
##   (grille de la carte alignée sur les axes, tournée de 45° en iso) ; toutes les fonctions publiques
##   prennent et rendent des positions/directions en repère LOGIQUE global (to_map / from_map,
##   directions par basis_xform). Carte plate à l'origine : identité, aucun surcoût.
## - Obstacles DYNAMIQUES (add_obstacle / remove_obstacle : conteneurs de la Grue, blocs de cristal, cocons,
##   souches…) : cercles ou boîtes orientées en repère logique. Ils bloquent les cellules dont le centre est
##   dedans (compteur par cellule, les murs statiques restent), entrent dans l'index de résolution (resolve,
##   steer_walls_many, is_spawnable) et invalident LOCALEMENT le cache de direction ; le champ est relancé une
##   fois (BFS étalé comme un changement de cellule du joueur), jamais recalculé par image.
## - GROS CORPS (boss d'étage 1,4 u, mini-boss 1,1 u : rayon > INDEX_GROW) : steer_body() suit un champ propre à
##   la classe de rayon, calculé sur la grille DILATÉE du rayon (cellule bloquée si son centre est à moins de
##   rayon - BODY_SLACK d'un obstacle) : le chemin ne passe que là où le corps tient, et chaque cellule visée a
##   assez de dégagement (plus de coins rabotés ni de boss plantés contre un obstacle). Une couche par classe
##   (au plus MAX_BODY_LAYERS), créée à la première demande, relancée quand les sources du champ principal changent
##   (au plus toutes les BODY_MIN_RECOMPUTE_S), étalée sur les images où le champ principal ne calcule pas (pic par
##   image inchangé), mise en sommeil sans boss (BODY_IDLE_S). Les monstres normaux n'y touchent pas.

const CELL := 64.0
const INV_CELL := 1.0 / CELL
const UNREACHED := 1 << 30
const BUDGET_PER_FRAME := 900 ## cellules traitées par frame pendant un recalcul
const INDEX_GROW := 48.0 ## rayon max d'un monstre (T3 = 42 px) pour l'index rectangles -> cellules ;
## au-delà (boss), resolve() parcourt les 3×3 cellules voisines (64 + 48 ≥ rayon boss 90).
const SPAWN_CLEARANCE := 40.0

var bounds := Rect2() ## repère carte
var w := 0
var h := 0
var rects: Array[Rect2] = [] ## repère carte
var blocked := PackedByteArray()
var free_cells := PackedInt32Array()
var target_cell := -1 ## cellule source du champ courant
var version := 0 ## incrémentée à chaque champ terminé (0 = aucun champ)

var _origin := Vector2.ZERO
var _m2l := Transform2D.IDENTITY ## carte -> logique global
var _l2m := Transform2D.IDENTITY ## logique global -> carte
var _flat := true ## _m2l == identité : conversions sautées
var _cell_rects: Array[PackedInt32Array] = []
var _dist := PackedInt32Array()
var _back := PackedInt32Array()
var _queue := PackedInt32Array()
var _q_head := 0
var _job_target := -1
var _job_active := false
var _next := PackedInt32Array()
var _los := PackedByteArray()
var _stamp := PackedInt32Array()
var _aim := PackedVector2Array() ## direction mise en cache par cellule (ZERO = foncer droit)
var _near := PackedByteArray() ## 1 si un rectangle est à portée de résolution
# Voisins en décalage d'index (4 orthogonaux puis 4 diagonaux) ; composantes x et y séparées
# pour le test de coupe de coin.
var _off := PackedInt32Array()
var _offx := PackedInt32Array()
var _offy := PackedInt32Array()
var _coff := PackedInt32Array()
var _q_tail := 0
var _since_start := 0.0
const MIN_RECOMPUTE_S := 0.4 ## au plus 2,5 recalculs par seconde (la ligne de vue couvre les abords du joueur)
const DYN_STAMP_RING := 2 ## cellules autour d'un obstacle dynamique dont le cache de direction est invalidé
const DYN_BLOCK_MARGIN := 28.0 ## cellule bloquée si son centre est à moins de 28 px de l'obstacle : les bords
## d'un obstacle dynamique ne tombent pas sur la grille ; sans marge, un monstre suivant une rangée « libre »
## qui frôle l'obstacle bute dans son coin (direction parallèle à la normale de poussée).

var _dyn := {} ## id -> {c, r (> 0 : cercle), half, xf, inv} en repère logique
var _dyn_count := 0
var _dyn_block := PackedByteArray() ## nombre d'obstacles dynamiques dont la cellule a le centre dedans
var _static_blocked := PackedByteArray()
var _cell_dyn := {} ## cellule -> Array d'ids (index de résolution, rayon INDEX_GROW)
var _dirty := false ## obstacles changés : champ à relancer au prochain créneau (MIN_RECOMPUTE_S)

# --- Coop 1-4 (docs/multi/Archi_Reseau.md §1.2 ligne 7) : BFS MULTI-SOURCES, une source par joueur vivant.
# Une seule passe pour toutes les sources (même coût qu'en solo) ; chaque cellule retient la source qui l'a atteinte
# la première (`_root`) : la direction mène au joueur le plus proche À PIED, la ligne de vue se teste vers lui, et
# root_id_at() dit au Director quel joueur un monstre poursuit. Solo (une source) : chemin et résultats identiques,
# aucun tableau de racines écrit.
const MAX_SOURCES := 4
var source_cells := PackedInt32Array() ## cellules sources du champ courant (1 en solo)
var source_ids := PackedInt32Array() ## id de joueur (registre Players) de chaque source du champ courant
var _multi := false ## champ courant à plusieurs sources (_root valide)
## Source qui a atteint chaque cellule (champ courant, si _multi), codée cellule × 4 + indice de la source dans
## source_cells / source_ids (au plus 4) : cellule = v >> 2, joueur = source_ids[v & 3] sans recherche. -1 : aucune.
var _root := PackedInt32Array()
var _back_root := PackedInt32Array()
var _job_multi := false
var _job_cells := PackedInt32Array()
var _job_ids := PackedInt32Array()
var _want_cells := PackedInt32Array() ## tampon réutilisé (update_multi)

# --- Gros corps : un champ de flux par classe de rayon, sur la grille dilatée (voir l'en-tête et steer_body)
const BODY_SLACK := 16.0 ## dilatation = rayon - 16 px : tout passage où le corps tient garde une rangée de centres libres
const BODY_RADIUS_STEP := 8.0 ## classes de rayon arrondies à 8 px (1,1 u -> 72 px, 1,4 u -> 88 px)
const MAX_BODY_LAYERS := 3
const BODY_MIN_RECOMPUTE_S := 0.6
const BODY_BUDGET_PER_FRAME := 900 ## cellules par image, seulement quand le champ principal ne calcule pas
const BODY_IDLE_S := 3.0 ## couche non demandée depuis 3 s (aucun gros corps) : plus recalculée


## Champ d'une classe de rayon. Cellule « dilatée » (blk) : son centre est à moins de `dil` d'un obstacle.
class BodyLayer:
	var radius := 0.0 ## rayon de classe (px)
	var dil := 0.0 ## rayon de dilatation (px)
	var escape := 2 ## autour d'une source (joueur collé à un mur), BFS permis dans les cellules dilatées jusqu'à cette distance
	var static_blk := PackedByteArray()
	## 1 si le coin haut-gauche de la cellule est à au moins `dil` de tout obstacle : une diagonale entre deux cellules
	## libres dont les deux orthogonales sont dilatées passe par ce coin (porte en diagonale juste assez large).
	var corner_ok := PackedByteArray()
	var dyn_cnt := PackedByteArray()
	var blk := PackedByteArray()
	var dist := PackedInt32Array()
	var back := PackedInt32Array()
	var queue := PackedInt32Array()
	var root := PackedInt32Array()
	var back_root := PackedInt32Array()
	var stamp := PackedInt32Array()
	var nxt := PackedInt32Array() ## cellule visée (-1 : foncer droit, -2 : repli sur le champ principal)
	var version := 0
	var multi := false
	var sources := PackedInt32Array()
	var src_ids := PackedInt32Array()
	var job_sources := PackedInt32Array()
	var job_ids := PackedInt32Array()
	var job_multi := false
	var job_active := false
	var q_head := 0
	var q_tail := 0
	var since := 1000.0
	var idle := 0.0
	var dirty := false

var _layers := {} ## classe (int) -> BodyLayer
var _layer_list: Array[BodyLayer] = []


## Construit la grille à partir des StaticBody2D (couche 1) sous `map` (déjà dans l'arbre).
func build_from_map(map: Node) -> void:
	rects.clear()
	_m2l = StageMap.frame_of(map)
	if map is Node2D:
		_m2l = (map as Node2D).global_transform * _m2l
	_l2m = _m2l.affine_inverse()
	_flat = _m2l.is_equal_approx(Transform2D.IDENTITY)
	_collect(map)
	_dyn.clear()
	_dyn_count = 0
	_cell_dyn.clear()
	_dirty = false
	_layers.clear()
	_layer_list.clear()
	if rects.is_empty():
		w = 0
		h = 0
		return
	bounds = rects[0]
	for r in rects:
		bounds = bounds.merge(r)
	# bruit flottant de la rotation iso (-2176.000244) : sinon floor/ceil ajoutent une rangée libre hors remparts
	var b_end := bounds.end.snapped(Vector2(0.01, 0.01))
	bounds.position = bounds.position.snapped(Vector2(0.01, 0.01))
	bounds.end = b_end
	# bordure d'une cellule bloquée : le BFS n'a aucun test de bornes
	_origin = (bounds.position / CELL).floor() * CELL - Vector2(CELL, CELL)
	w = int(ceil((bounds.end.x - _origin.x) / CELL)) + 1
	h = int(ceil((bounds.end.y - _origin.y) / CELL)) + 1
	var n := w * h
	blocked.resize(n)
	blocked.fill(0)
	for x in w:
		blocked[x] = 1
		blocked[(h - 1) * w + x] = 1
	for y in h:
		blocked[y * w] = 1
		blocked[y * w + w - 1] = 1
	_off = PackedInt32Array([1, -1, w, -w, w + 1, -w + 1, w - 1, -w - 1])
	_coff = PackedInt32Array([0, 0, 0, 0, w + 1, 1, w, 0]) # diagonale k : cellule dont le coin haut-gauche est franchi
	_offx = PackedInt32Array([1, -1, 0, 0, 1, 1, -1, -1])
	_offy = PackedInt32Array([0, 0, w, -w, w, -w, w, -w])
	_cell_rects.resize(n)
	for c in n:
		_cell_rects[c] = PackedInt32Array()
	for ri in rects.size():
		var r := rects[ri]
		# cellules bloquées : centre dans le rectangle
		var x0 := int(ceil((r.position.x - _origin.x) / CELL - 0.5))
		var x1 := int(floor((r.end.x - _origin.x) / CELL - 0.5))
		var y0 := int(ceil((r.position.y - _origin.y) / CELL - 0.5))
		var y1 := int(floor((r.end.y - _origin.y) / CELL - 0.5))
		for y in range(maxi(y0, 0), mini(y1, h - 1) + 1):
			for x in range(maxi(x0, 0), mini(x1, w - 1) + 1):
				blocked[y * w + x] = 1
		# index de résolution : rectangle élargi du rayon max
		var g := r.grow(INDEX_GROW)
		for y in range(maxi(int((g.position.y - _origin.y) / CELL), 0), mini(int((g.end.y - _origin.y) / CELL), h - 1) + 1):
			for x in range(maxi(int((g.position.x - _origin.x) / CELL), 0), mini(int((g.end.x - _origin.x) / CELL), w - 1) + 1):
				_cell_rects[y * w + x].append(ri)
	_static_blocked = blocked.duplicate()
	_dyn_block.resize(n)
	_dyn_block.fill(0)
	free_cells.clear()
	for c in n:
		if blocked[c] == 0:
			free_cells.append(c)
	_dist.resize(n)
	_dist.fill(UNREACHED)
	_back.resize(n)
	_queue.resize(n)
	_next.resize(n)
	_los.resize(n)
	_stamp.resize(n)
	_stamp.fill(0)
	_aim.resize(n)
	_near.resize(n)
	for c in n:
		_near[c] = 1 if not _cell_rects[c].is_empty() else 0
	version = 0
	target_cell = -1
	_job_active = false
	_multi = false
	_job_multi = false
	source_cells.clear()
	source_ids.clear()
	_root = PackedInt32Array()
	_back_root = PackedInt32Array()
	# zone accessible : une fois par carte, depuis le départ du joueur (StageMap) ; sans départ connu, l'appelant
	# peut lancer compute_reachable(p) lui-même (sinon toute cellule libre compte comme accessible)
	_reach = PackedByteArray()
	reach_cells = PackedInt32Array()
	reach_origin = Vector2.INF
	if map is StageMap and map.is_inside_tree():
		compute_reachable((map as StageMap).to_global((map as StageMap).get_player_start()))


func is_valid() -> bool:
	return w > 0


func _collect(node: Node) -> void:
	if node is StaticBody2D and ((node as StaticBody2D).collision_layer & 1) != 0:
		for ch in node.get_children():
			if ch is CollisionShape2D and not (ch as CollisionShape2D).disabled and (ch as CollisionShape2D).shape != null:
				var cs := ch as CollisionShape2D
				rects.append((_l2m * cs.global_transform) * cs.shape.get_rect())
	for ch in node.get_children():
		_collect(ch)


## Repère logique -> carte (et inverse).
func to_map(p: Vector2) -> Vector2:
	return p if _flat else _l2m * p


func from_map(p: Vector2) -> Vector2:
	return p if _flat else _m2l * p


## Cellule d'une position logique (-1 hors grille).
func cell_of(p: Vector2) -> int:
	return _cell_m(to_map(p))


## Centre (repère logique) d'une cellule.
func cell_center(c: int) -> Vector2:
	return from_map(_center_m(c))


func _cell_m(p: Vector2) -> int:
	var fx := (p.x - _origin.x) * INV_CELL
	var fy := (p.y - _origin.y) * INV_CELL
	if fx < 0.0 or fy < 0.0 or fx >= w or fy >= h:
		return -1
	return int(fy) * w + int(fx)


func _center_m(c: int) -> Vector2:
	return _origin + Vector2((c % w) + 0.5, (c / w) + 0.5) * CELL


# --- Champ (BFS incrémental)
## À appeler chaque frame : lance un recalcul si le joueur a changé de cellule, et avance le
## calcul en cours d'au plus BUDGET_PER_FRAME cellules.
## `player_id` : id du joueur source (registre Players ; 0 en solo), rendu par root_id_at().
func update(player_pos: Vector2, delta: float = 1.0 / 60.0, player_id: int = 0) -> void:
	if w == 0:
		return
	_since_start += delta
	if not _job_active and _since_start >= MIN_RECOMPUTE_S:
		var pm := to_map(player_pos)
		var pc := _cell_m(pm)
		if pc < 0:
			pc = _cell_m(_clamp_m(pm, 1.0))
		if pc >= 0 and (pc != target_cell or _dirty or _multi or (version > 0 and source_ids.size() == 1 and source_ids[0] != player_id)):
			_dirty = false
			_start(pc, player_id)
	if _job_active:
		_step(BUDGET_PER_FRAME)
	elif not _layer_list.is_empty():
		_update_layers(delta)


## Coop : comme update() avec plusieurs sources (positions logiques des joueurs vivants, `count` premières entrées
## de `positions`, `ids` = leur id dans le registre Players). Relance quand l'ensemble des cellules sources change.
## count = 1 : strictement update() (solo inchangé). count = 0 : le champ courant est gardé.
func update_multi(positions: PackedVector2Array, ids: PackedInt32Array, count: int, delta: float = 1.0 / 60.0) -> void:
	if w == 0 or count <= 0:
		return
	if count == 1:
		update(positions[0], delta, ids[0])
		return
	_since_start += delta
	if not _job_active and _since_start >= MIN_RECOMPUTE_S:
		count = mini(count, MAX_SOURCES)
		_want_cells.resize(count)
		var changed := _dirty or not _multi or source_cells.size() != count
		for k in count:
			var pm := to_map(positions[k])
			var pc := _cell_m(pm)
			if pc < 0:
				pc = _cell_m(_clamp_m(pm, 1.0))
			_want_cells[k] = pc
			if not changed and (pc != source_cells[k] or ids[k] != source_ids[k]):
				changed = true
		if changed:
			_dirty = false
			_start_multi(_want_cells, ids, count)
	if _job_active:
		_step(BUDGET_PER_FRAME)
	elif not _layer_list.is_empty():
		_update_layers(delta)


## Calcule tout le champ immédiatement (liaison de carte, tests).
func compute_now(player_pos: Vector2, player_id: int = 0) -> void:
	var pc := _cell_m(_clamp_m(to_map(player_pos), 1.0))
	if pc < 0:
		return
	_dirty = false
	_start(pc, player_id)
	_step(1 << 30)
	_compute_layers_now()


## compute_now à plusieurs sources (liaison de carte en coop, tests).
func compute_now_multi(positions: PackedVector2Array, ids: PackedInt32Array, count: int) -> void:
	if w == 0 or count <= 0:
		return
	if count == 1:
		compute_now(positions[0], ids[0])
		return
	count = mini(count, MAX_SOURCES)
	_want_cells.resize(count)
	for k in count:
		_want_cells[k] = _cell_m(_clamp_m(to_map(positions[k]), 1.0))
	_dirty = false
	_start_multi(_want_cells, ids, count)
	_step(1 << 30)
	_compute_layers_now()


func _start(pc: int, player_id: int = 0) -> void:
	_back.fill(UNREACHED)
	_back[pc] = 0 # la source peut être bloquée (joueur collé à un mur) : on en sort quand même
	_queue[0] = pc
	_q_head = 0
	_q_tail = 1
	_job_target = pc
	_job_multi = false
	_job_cells.resize(1)
	_job_cells[0] = pc
	_job_ids.resize(1)
	_job_ids[0] = player_id
	_job_active = true
	_since_start = 0.0


func _start_multi(cells: PackedInt32Array, ids: PackedInt32Array, count: int) -> void:
	if _back_root.size() != w * h:
		_back_root.resize(w * h)
		_root.resize(w * h)
		_root.fill(-1)
	_back.fill(UNREACHED)
	_back_root.fill(-1)
	_job_cells.resize(0)
	_job_ids.resize(0)
	_q_head = 0
	_q_tail = 0
	for k in count:
		var pc := cells[k]
		if pc < 0:
			continue
		_job_cells.append(pc)
		_job_ids.append(ids[k])
		if _back[pc] == 0:
			continue # deux joueurs dans la même cellule : une seule source (la première)
		_back[pc] = 0
		_back_root[pc] = pc * 4 + (_job_cells.size() - 1)
		_queue[_q_tail] = pc
		_q_tail += 1
	if _q_tail == 0:
		return
	_job_target = _job_cells[0]
	_job_multi = true
	_job_active = true
	_since_start = 0.0


func _step(budget: int) -> void:
	var done := 0
	var off := _off
	var offx := _offx
	var offy := _offy
	var multi := _job_multi
	while _q_head < _q_tail and done < budget:
		var c := _queue[_q_head]
		_q_head += 1
		done += 1
		var nd := _back[c] + 1
		for k in 8:
			var nc := c + off[k]
			if blocked[nc] != 0 or _back[nc] != UNREACHED:
				continue
			if k >= 4 and (blocked[c + offx[k]] != 0 or blocked[c + offy[k]] != 0):
				continue # pas de coupe de coin
			_back[nc] = nd
			if multi:
				_back_root[nc] = _back_root[c]
			_queue[_q_tail] = nc
			_q_tail += 1
	if _q_head >= _q_tail:
		var tmp := _dist
		_dist = _back
		_back = tmp
		if multi:
			var tr := _root
			_root = _back_root
			_back_root = tr
		_multi = multi
		source_cells.resize(_job_cells.size()) # copie sans allocation (au plus 4 entrées)
		source_ids.resize(_job_ids.size())
		for k in _job_cells.size():
			source_cells[k] = _job_cells[k]
			source_ids[k] = _job_ids[k]
		target_cell = _job_target
		version += 1
		_job_active = false


## Id du joueur (registre Players) que le champ courant mène vers `pos` : la source la plus proche à pied.
## Solo : l'id de l'unique source. -1 sans champ, hors grille ou cellule non atteinte. O(1) + au plus 4 comparaisons.
## `radius` > INDEX_GROW (gros corps) : la source que rejoint le champ de sa classe (steer_body), s'il est prêt.
func root_id_at(pos: Vector2, radius: float = 0.0) -> int:
	if version == 0 or source_ids.is_empty():
		return -1
	if not _multi:
		return source_ids[0]
	if radius > INDEX_GROW:
		var L := _body_layer(radius)
		if L != null and L.version > 0 and L.multi:
			var lc := cell_of(pos)
			if lc < 0:
				return -1
			var bc := lc if L.dist[lc] != UNREACHED else _body_best(L, lc, 2)
			if bc < 0 or L.root[bc] < 0:
				return -1
			return L.src_ids[L.root[bc] & 3]
	var c := cell_of(pos)
	if c < 0 or _dist[c] == UNREACHED:
		return -1
	var rc := _root[c]
	return source_ids[rc & 3] if rc >= 0 else -1


## Nombre de sources du champ courant (0 sans champ).
func source_count() -> int:
	return source_cells.size() if version > 0 else 0


## Direction de déplacement (unitaire) vers le joueur pour un corps en `pos`.
## Renvoie Vector2.ZERO si le monstre doit foncer droit (ligne de vue, pas de champ, hors grille).
## Mise en cache par cellule et par version du champ : coût O(1) par monstre.
func steer(pos: Vector2) -> Vector2:
	if version == 0:
		return Vector2.ZERO
	if not _flat:
		pos = _l2m * pos
	var fx := (pos.x - _origin.x) * INV_CELL
	var fy := (pos.y - _origin.y) * INV_CELL
	if fx < 0.0 or fy < 0.0 or fx >= w or fy >= h:
		return Vector2.ZERO
	var c := int(fy) * w + int(fx)
	if _stamp[c] != version:
		_fill(c)
	return _aim[c] if _flat else _m2l.basis_xform(_aim[c])


## steer() en lot (Director) : out[i] = steer(pos[i]) pour i = start, start + 2… < n. Un seul appel
## par frame au lieu d'un par monstre (même résultat, coût d'appel GDScript économisé).
func steer_many(pos: PackedVector2Array, out: PackedVector2Array, start: int, n: int) -> void:
	if version == 0:
		for i in range(start, n, 2):
			out[i] = Vector2.ZERO
		return
	var ox := _origin.x
	var oy := _origin.y
	var fw := float(w)
	var fh := float(h)
	for i in range(start, n, 2):
		var p := pos[i] if _flat else _l2m * pos[i]
		var fx := (p.x - ox) * INV_CELL
		var fy := (p.y - oy) * INV_CELL
		if fx < 0.0 or fy < 0.0 or fx >= fw or fy >= fh:
			out[i] = Vector2.ZERO
			continue
		var c := int(fy) * w + int(fx)
		if _stamp[c] != version:
			_fill(c)
		out[i] = _aim[c] if _flat else _m2l.basis_xform(_aim[c])


## steer_many + murs proches, en une passe (Director, une fois par frame) : out[i] = steer(pos[i]) pour
## i = start, start + 2… ; walls[i] (TOUS les i < n) = 1 si la cellule de pos[i] a un rectangle à portée de
## résolution (INDEX_GROW), 0 sinon (resolve() rendrait p tel quel : appel épargné). Hors grille = 1.
## Les positions datent du début de la frame : un corps qui sort d'une cellule « libre » est encore à
## >= INDEX_GROW - pas (~7 px) de tout mur ; sa pénétration transitoire reste celle de la résolution
## une frame sur deux (corrigée à la suivante).
func steer_walls_many(pos: PackedVector2Array, out: PackedVector2Array, walls: PackedByteArray, start: int, n: int) -> void:
	if w == 0:
		walls.fill(0)
		for i in range(start, n, 2):
			out[i] = Vector2.ZERO
		return
	var ox := _origin.x
	var oy := _origin.y
	var fw := float(w)
	var fh := float(h)
	var has_field := version != 0
	for i in n:
		var p := pos[i] if _flat else _l2m * pos[i]
		var fx := (p.x - ox) * INV_CELL
		var fy := (p.y - oy) * INV_CELL
		var mine := (i & 1) == start
		if fx < 0.0 or fy < 0.0 or fx >= fw or fy >= fh:
			walls[i] = 1
			if mine:
				out[i] = Vector2.ZERO
			continue
		var c := int(fy) * w + int(fx)
		walls[i] = _near[c]
		if mine:
			if not has_field:
				out[i] = Vector2.ZERO
				continue
			if _stamp[c] != version:
				_fill(c)
			out[i] = _aim[c] if _flat else _m2l.basis_xform(_aim[c])


## Coop : steer_walls_many + racines, en une passe. roots[i] (TOUS les i < n) = id du joueur (registre Players) que
## le champ rejoint depuis pos[i], -1 si cellule non atteinte, hors grille ou champ à une seule source (le Director
## n'en a alors pas besoin). Même coût que steer_walls_many à une lecture de tableau près par monstre.
func steer_walls_roots_many(pos: PackedVector2Array, out: PackedVector2Array, walls: PackedByteArray, roots: PackedInt32Array, start: int, n: int) -> void:
	if w == 0 or not _multi or version == 0:
		roots.fill(-1)
		steer_walls_many(pos, out, walls, start, n)
		return
	var ox := _origin.x
	var oy := _origin.y
	var fw := float(w)
	var fh := float(h)
	for i in n:
		var p := pos[i] if _flat else _l2m * pos[i]
		var fx := (p.x - ox) * INV_CELL
		var fy := (p.y - oy) * INV_CELL
		var mine := (i & 1) == start
		if fx < 0.0 or fy < 0.0 or fx >= fw or fy >= fh:
			walls[i] = 1
			roots[i] = -1
			if mine:
				out[i] = Vector2.ZERO
			continue
		var c := int(fy) * w + int(fx)
		walls[i] = _near[c]
		var rc := _root[c] if _dist[c] != UNREACHED else -1
		roots[i] = source_ids[rc & 3] if rc >= 0 else -1
		if mine:
			if _stamp[c] != version:
				_fill(c)
			out[i] = _aim[c] if _flat else _m2l.basis_xform(_aim[c])


func _fill(c: int) -> void:
	_stamp[c] = version
	var best := -1
	var best_d := _dist[c]
	# source(s) du champ : distance 0 (une source peut être bloquée : joueur collé à un mur). Solo : target_cell.
	for k in 8:
		var nc := c + _off[k]
		if blocked[nc] != 0 and _dist[nc] != 0:
			continue
		if k >= 4 and (blocked[c + _offx[k]] != 0 or blocked[c + _offy[k]] != 0):
			continue
		if _dist[nc] < best_d:
			best_d = _dist[nc]
			best = nc
	_next[c] = best
	var src := target_cell
	if _multi and _dist[c] != UNREACHED:
		src = _root[c] >> 2 # ligne de vue vers le joueur que ce chemin rejoint
	_los[c] = 1 if _line_clear(c, src) else 0
	_aim[c] = Vector2.ZERO
	if _dist[c] == 0 or _dist[c] == UNREACHED or _los[c] != 0 or best < 0:
		return
	var aim := best # vise 2 cellules plus loin sur le chemin : trajectoire plus lisse
	if _dist[best] != 0:
		if _stamp[best] != version:
			_fill(best)
		if _next[best] >= 0:
			aim = _next[best]
	_aim[c] = (_center_m(aim) - _center_m(c)).normalized()


## Ligne de vue entre centres de cellules (échantillonnage tous les 1/2 cellule).
func _line_clear(a: int, b: int) -> bool:
	var pa := _center_m(a)
	var pb := _center_m(b)
	var steps := int(pa.distance_to(pb) / (CELL * 0.5))
	if steps > 40:
		return false # loin : on suit le champ, ça coûte moins cher qu'un long lancer
	for s in range(1, steps):
		var c := _cell_m(pa.lerp(pb, float(s) / steps))
		if c < 0 or blocked[c] != 0:
			return false
	return true


# --- Gros corps (boss d'étage, mini-boss)
## Direction (unitaire, repère logique) pour un corps de rayon `radius` en `pos` : comme steer(), mais sur le champ
## de sa classe de rayon (grille dilatée : le chemin ne passe que là où le corps tient). Vector2.ZERO = foncer droit
## (ligne de vue « épaisse » libre, ou sur la source). Corps <= INDEX_GROW, couche pas encore prête, ou corps sans
## aucune cellule du champ à 2 cases (enfermé) : steer(pos). Vise le centre de la cellule à 2 pas depuis la position
## réelle (pas depuis le centre de la cellule) : le corps glisse le long des murs au lieu de s'y planter.
## Coût : O(1) amorti (cache par cellule et par version de la couche) ; une couche est créée à la première demande.
func steer_body(pos: Vector2, radius: float) -> Vector2:
	if radius <= INDEX_GROW or w == 0:
		return steer(pos)
	var L := _body_layer(radius)
	if L == null or L.version == 0:
		return steer(pos)
	var pm := to_map(pos)
	var c := _cell_m(pm)
	if c < 0 or not _interior(c):
		return steer(pos)
	if L.stamp[c] != L.version:
		_fill_body(L, c)
	var a := L.nxt[c]
	if a == -1:
		return Vector2.ZERO
	if a < 0:
		return steer(pos)
	var d := _center_m(a) - pm
	if d.length_squared() < 4.0:
		return Vector2.ZERO
	d = d.normalized()
	return d if _flat else _m2l.basis_xform(d)


## Vrai si un corps de rayon `radius` tient en `p` d'après la grille dilatée de sa classe (cellule libre, accessible).
## Corps <= INDEX_GROW : is_reachable(p).
func is_body_free(p: Vector2, radius: float) -> bool:
	if radius <= INDEX_GROW or w == 0:
		return is_reachable(p)
	var L := _body_layer(radius)
	var c := cell_of(p)
	return c >= 0 and L.blk[c] == 0 and blocked[c] == 0 and (_reach.is_empty() or _reach[c] != 0)


## Point d'apparition d'un gros corps près de `p` : `p` s'il y tient (is_body_free), sinon le centre de la cellule
## libre de la grille dilatée et accessible la plus proche (anneaux jusqu'à `max_ring`), sinon nearest_reachable(p).
## Jamais dans un mur, jamais dans une poche fermée. Ponctuel (apparition d'un boss).
func body_spawn_point(p: Vector2, radius: float, max_ring: int = 6) -> Vector2:
	if w == 0:
		return p
	if radius <= INDEX_GROW:
		return nearest_reachable(p)
	if is_body_free(p, radius):
		return p
	var L := _body_layer(radius)
	var pm := _clamp_m(to_map(p), 1.0)
	var c := _cell_m(pm)
	if c < 0:
		return nearest_reachable(p)
	var cx := c % w
	var cy := c / w
	var best := -1
	var best_d := INF
	var found_ring := -1
	for r in range(1, max_ring + 1):
		if found_ring >= 0 and r > found_ring + 1: # l'anneau suivant peut encore être plus proche en euclidien
			break
		for y in range(cy - r, cy + r + 1):
			if y < 0 or y >= h:
				continue
			var step := 1 if (y == cy - r or y == cy + r) else 2 * r
			var x := cx - r
			while x <= cx + r:
				if x >= 0 and x < w:
					var nc := y * w + x
					if L.blk[nc] == 0 and blocked[nc] == 0 and (_reach.is_empty() or _reach[nc] != 0):
						var d := _center_m(nc).distance_squared_to(pm)
						if d < best_d:
							best_d = d
							best = nc
							if found_ring < 0:
								found_ring = r
				x += step
	return from_map(_center_m(best)) if best >= 0 else nearest_reachable(p)


func _interior(c: int) -> bool:
	var x := c % w
	var y := c / w
	return x > 0 and y > 0 and x < w - 1 and y < h - 1


## Couche de la classe de `radius` (créée à la demande ; au-delà de MAX_BODY_LAYERS : la classe existante la plus
## proche par excès, sinon la plus grande). Rend null sans grille.
func _body_layer(radius: float) -> BodyLayer:
	if w == 0:
		return null
	var key := roundi(radius / BODY_RADIUS_STEP)
	var L: BodyLayer = _layers.get(key)
	if L != null:
		L.idle = 0.0
		return L
	if _layer_list.size() >= MAX_BODY_LAYERS:
		var best: BodyLayer = null # la plus petite classe qui couvre le rayon, sinon la plus grande
		for o in _layer_list:
			if best == null:
				best = o
			elif best.radius < radius:
				if o.radius > best.radius:
					best = o
			elif o.radius >= radius and o.radius < best.radius:
				best = o
		best.idle = 0.0
		return best
	L = _make_layer(float(key) * BODY_RADIUS_STEP)
	_layers[key] = L
	_layer_list.append(L)
	if version > 0: # champ principal prêt : la couche se calcule sur les prochaines images (repli sur steer d'ici là)
		_start_body(L)
	return L


func _make_layer(radius: float) -> BodyLayer:
	var L := BodyLayer.new()
	L.radius = radius
	L.dil = maxf(radius - BODY_SLACK, INDEX_GROW)
	L.escape = int(ceil(L.dil / CELL)) + 1
	var n := w * h
	L.static_blk = _static_blocked.duplicate()
	var d2 := L.dil * L.dil
	for r in rects:
		var g := r.grow(L.dil)
		var x0 := maxi(int(ceil((g.position.x - _origin.x) / CELL - 0.5)), 0)
		var x1 := mini(int(floor((g.end.x - _origin.x) / CELL - 0.5)), w - 1)
		var y0 := maxi(int(ceil((g.position.y - _origin.y) / CELL - 0.5)), 0)
		var y1 := mini(int(floor((g.end.y - _origin.y) / CELL - 0.5)), h - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var c := y * w + x
				if L.static_blk[c] != 0:
					continue
				var p := _center_m(c)
				var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
				if p.distance_squared_to(q) < d2:
					L.static_blk[c] = 1
	L.corner_ok.resize(n)
	L.corner_ok.fill(1)
	for r in rects:
		var g := r.grow(L.dil)
		var x0 := maxi(int(ceil((g.position.x - _origin.x) / CELL)), 0)
		var x1 := mini(int(floor((g.end.x - _origin.x) / CELL)), w - 1)
		var y0 := maxi(int(ceil((g.position.y - _origin.y) / CELL)), 0)
		var y1 := mini(int(floor((g.end.y - _origin.y) / CELL)), h - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var c := y * w + x
				if L.corner_ok[c] == 0:
					continue
				var p := _origin + Vector2(x, y) * CELL
				var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
				if p.distance_squared_to(q) < d2:
					L.corner_ok[c] = 0
	L.dyn_cnt.resize(n)
	L.dyn_cnt.fill(0)
	L.blk = L.static_blk.duplicate()
	L.dist.resize(n)
	L.dist.fill(UNREACHED)
	L.back.resize(n)
	L.queue.resize(n)
	L.stamp.resize(n)
	L.stamp.fill(-1)
	L.nxt.resize(n)
	for id in _dyn:
		var o: Dictionary = _dyn[id]
		if not bool(o.get("small", false)):
			_stamp_dyn_layer(L, o, 1)
	L.dirty = false
	return L


## Obstacle dynamique dans une couche : cellules dont le centre est à moins de `dil` de l'obstacle.
func _stamp_dyn_layer(L: BodyLayer, o: Dictionary, sgn: int) -> void:
	var bound := float(o["r"]) if float(o["r"]) > 0.0 else (o["half"] as Vector2).length()
	var k := 1.0 if _flat else maxf(_l2m.x.length(), _l2m.y.length())
	var cm := to_map(o["c"])
	var ext := bound * k + L.dil + CELL
	var x0 := maxi(int(floor((cm.x - ext - _origin.x) * INV_CELL)), 0)
	var x1 := mini(int(floor((cm.x + ext - _origin.x) * INV_CELL)), w - 1)
	var y0 := maxi(int(floor((cm.y - ext - _origin.y) * INV_CELL)), 0)
	var y1 := mini(int(floor((cm.y + ext - _origin.y) * INV_CELL)), h - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := y * w + x
			if _in_dyn(o, from_map(_center_m(c)), L.dil / k):
				L.dyn_cnt[c] = clampi(L.dyn_cnt[c] + sgn, 0, 255)
				L.blk[c] = 1 if (L.static_blk[c] != 0 or L.dyn_cnt[c] > 0) else 0
	var g := DYN_STAMP_RING
	for y in range(maxi(y0 - g, 0), mini(y1 + g, h - 1) + 1):
		for x in range(maxi(x0 - g, 0), mini(x1 + g, w - 1) + 1):
			L.stamp[y * w + x] = -1
	L.dirty = true


## Appelé par update() / update_multi() aux images où le champ principal ne calcule pas : relance une couche quand
## les sources du champ principal ont changé (ou un obstacle), au plus toutes les BODY_MIN_RECOMPUTE_S, et avance
## un seul calcul de couche d'au plus BODY_BUDGET_PER_FRAME cellules (pic par image = celui du champ principal).
func _update_layers(delta: float) -> void:
	var budget := BODY_BUDGET_PER_FRAME
	for L in _layer_list:
		L.idle += delta
		L.since += delta
		if L.idle > BODY_IDLE_S:
			continue
		if not L.job_active and version > 0 and L.since >= BODY_MIN_RECOMPUTE_S and (L.dirty or _sources_changed(L)):
			_start_body(L)
		if L.job_active and budget > 0:
			budget -= _step_body(L, budget)


func _sources_changed(L: BodyLayer) -> bool:
	if L.version == 0 or L.sources.size() != source_cells.size() or L.multi != _multi:
		return true
	for k in source_cells.size():
		if L.sources[k] != source_cells[k] or L.src_ids[k] != source_ids[k]:
			return true
	return false


## Calcul immédiat de toutes les couches (compute_now : liaison de carte, tests).
func _compute_layers_now() -> void:
	for L in _layer_list:
		_start_body(L)
		_step_body(L, 1 << 30)


func _start_body(L: BodyLayer) -> void:
	var n := w * h
	L.back.fill(UNREACHED)
	L.job_multi = _multi
	if _multi and L.back_root.size() != n:
		L.back_root.resize(n)
		L.root.resize(n)
		L.root.fill(-1)
	if _multi:
		L.back_root.fill(-1)
	L.job_sources.resize(source_cells.size())
	L.job_ids.resize(source_ids.size())
	L.q_head = 0
	L.q_tail = 0
	for k in source_cells.size():
		var pc := source_cells[k]
		L.job_sources[k] = pc
		L.job_ids[k] = source_ids[k]
		if pc < 0 or L.back[pc] == 0:
			continue
		L.back[pc] = 0
		if _multi:
			L.back_root[pc] = pc * 4 + k
		L.queue[L.q_tail] = pc
		L.q_tail += 1
	L.job_active = L.q_tail > 0
	L.since = 0.0
	L.dirty = false


## BFS 8 voisins de la couche : cellules de vrai mur (`blocked`) jamais franchies ; cellules dilatées seulement à
## moins de `escape` pas d'une source (joueur collé à un mur) ; diagonale refusée si elle coupe un coin de vrai mur, ou
## si ses deux cellules orthogonales sont dilatées et que le coin franchi n'a pas `dil` de dégagement (corner_ok). Rend
## le nombre de cellules traitées.
func _step_body(L: BodyLayer, budget: int) -> int:
	var done := 0
	var off := _off
	var offx := _offx
	var offy := _offy
	var blk := L.blk
	var back := L.back
	var queue := L.queue
	var esc := L.escape
	var corner := L.corner_ok
	var coff := _coff
	var multi := L.job_multi
	var head := L.q_head
	var tail := L.q_tail
	while head < tail and done < budget:
		var c := queue[head]
		head += 1
		done += 1
		var nd := back[c] + 1
		var loose := nd <= esc
		for k in 8:
			var nc := c + off[k]
			if back[nc] != UNREACHED or blocked[nc] != 0:
				continue
			if blk[nc] != 0 and not loose:
				continue
			if k >= 4:
				var ox := c + offx[k]
				var oy := c + offy[k]
				if blocked[ox] != 0 or blocked[oy] != 0:
					continue
				if not loose and blk[ox] != 0 and blk[oy] != 0 and corner[c + coff[k]] == 0:
					continue
			back[nc] = nd
			if multi:
				L.back_root[nc] = L.back_root[c]
			queue[tail] = nc
			tail += 1
	L.q_head = head
	L.q_tail = tail
	L.back = back # tableaux compactés passés par référence : réaffectation sans copie (sûreté)
	L.queue = queue
	if head >= tail:
		var tmp := L.dist
		L.dist = L.back
		L.back = tmp
		if multi:
			var tr := L.root
			L.root = L.back_root
			L.back_root = tr
		L.multi = multi
		L.sources.resize(L.job_sources.size())
		L.src_ids.resize(L.job_ids.size())
		for k in L.job_sources.size():
			L.sources[k] = L.job_sources[k]
			L.src_ids[k] = L.job_ids[k]
		L.version += 1
		L.job_active = false
	return done


## Voisin de plus petite distance (transition permise par le BFS) ; cellule non atteinte (corps collé à un mur, dans
## une cellule dilatée) : anneau de 2 si l'anneau de 1 n'a rien. -1 si rien.
func _body_best(L: BodyLayer, c: int, ring: int) -> int:
	var best := -1
	var best_d := L.dist[c]
	for k in 8:
		var nc := c + _off[k]
		var dn := L.dist[nc]
		if dn >= best_d:
			continue
		if k >= 4 and (blocked[c + _offx[k]] != 0 or blocked[c + _offy[k]] != 0):
			continue
		best = nc
		best_d = dn
	if best >= 0 or ring < 2 or L.dist[c] != UNREACHED:
		return best
	var cx := c % w
	var cy := c / w
	for dy in range(-2, 3):
		var y := cy + dy
		if y < 0 or y >= h:
			continue
		for dx in range(-2, 3):
			if absi(dx) < 2 and absi(dy) < 2:
				continue
			var x := cx + dx
			if x < 0 or x >= w:
				continue
			var nc := y * w + x
			if L.dist[nc] < best_d and _line_clear_cells(c, nc):
				best = nc
				best_d = L.dist[nc]
	return best


## Aucune cellule de vrai mur entre deux centres (échantillons tous les 1/2 cellule).
func _line_clear_cells(a: int, b: int) -> bool:
	var pa := _center_m(a)
	var pb := _center_m(b)
	var steps := int(pa.distance_to(pb) / (CELL * 0.5))
	for s in range(1, steps):
		var c := _cell_m(pa.lerp(pb, float(s) / steps))
		if c < 0 or blocked[c] != 0:
			return false
	return true


func _fill_body(L: BodyLayer, c: int) -> void:
	L.stamp[c] = L.version
	var d := L.dist[c]
	if d == 0:
		L.nxt[c] = -1
		return
	var best := _body_best(L, c, 2)
	if best < 0:
		L.nxt[c] = -2 # enfermé (aucune cellule du champ à 2 cases) : champ principal
		return
	var src := L.sources[0] if not L.sources.is_empty() else -1
	if L.multi:
		var rc := L.root[c] if d != UNREACHED else L.root[best]
		if rc >= 0:
			src = rc >> 2
	if src >= 0 and _line_clear_body(L, c, src):
		L.nxt[c] = -1
		return
	if d == UNREACHED or L.dist[best] == 0:
		L.nxt[c] = best # vise directement la cellule libre (ou la source)
		return
	var nb := _body_best(L, best, 1) # vise 2 cellules plus loin : trajectoire plus lisse
	L.nxt[c] = nb if nb >= 0 else best


## Ligne de vue « épaisse » : aucune cellule de vrai mur ni cellule dilatée entre les centres, sauf les cellules
## dilatées aux abords de la source (escape : joueur collé à un mur, le corps finit en glissant).
func _line_clear_body(L: BodyLayer, a: int, b: int) -> bool:
	var pa := _center_m(a)
	var pb := _center_m(b)
	var steps := int(pa.distance_to(pb) / (CELL * 0.5))
	if steps > 40:
		return false
	var bx := b % w
	var by := b / w
	for s in range(1, steps):
		var c := _cell_m(pa.lerp(pb, float(s) / steps))
		if c < 0 or blocked[c] != 0:
			return false
		if L.blk[c] != 0 and maxi(absi(c % w - bx), absi(c / w - by)) > L.escape:
			return false
	return true


# --- Collisions et apparitions
## Sort un cercle des rectangles d'obstacle et le garde dans les bornes de la carte.
func resolve(p: Vector2, radius: float) -> Vector2:
	# chemin chaud (250 monstres × image) en ligne : cellule sans rectangle proche -> p rendu tel quel
	var q := p if _flat else _l2m * p
	var fx := (q.x - _origin.x) * INV_CELL
	var fy := (q.y - _origin.y) * INV_CELL
	if radius <= INDEX_GROW and fx >= 0.0 and fy >= 0.0 and fx < w and fy < h:
		var c := int(fy) * w + int(fx)
		if _near[c] == 0:
			return p
		var r := _push_out(q, radius, _cell_rects[c])
		var out := r if _flat else _m2l * r
		if _dyn_count > 0 and _cell_dyn.has(c):
			out = _push_out_dyn(out, radius, _cell_dyn[c])
		return out
	var m := _resolve_m(q, radius)
	var out2 := m if _flat else _m2l * m
	if _dyn_count > 0:
		out2 = _push_out_dyn(out2, radius, _dyn.keys())
	return out2


func _resolve_m(p: Vector2, radius: float) -> Vector2:
	var fx := (p.x - _origin.x) * INV_CELL
	var fy := (p.y - _origin.y) * INV_CELL
	if fx < 0.0 or fy < 0.0 or fx >= w or fy >= h:
		return _clamp_m(p, radius)
	var c := int(fy) * w + int(fx)
	if radius > INDEX_GROW: # gros corps (boss) : cellules voisines aussi
		for dy in [-w, 0, w]:
			for dx in [-1, 0, 1]:
				var nc: int = c + dy + dx
				if nc >= 0 and nc < _near.size() and _near[nc] != 0:
					p = _push_out(p, radius, _cell_rects[nc])
		return _clamp_m(p, radius)
	if _near[c] == 0:
		return p
	return _push_out(p, radius, _cell_rects[c])


func _push_out(p: Vector2, radius: float, list: PackedInt32Array) -> Vector2:
	for i in list.size():
		var r := rects[list[i]]
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var d := p - q
		var d2 := d.length_squared()
		if d2 >= radius * radius:
			continue
		if d2 > 0.0001:
			p = q + d / sqrt(d2) * radius
		else: # centre dans le rectangle : sortie par le bord le plus proche
			var left := p.x - r.position.x
			var right := r.end.x - p.x
			var top := p.y - r.position.y
			var bottom := r.end.y - p.y
			var m := minf(minf(left, right), minf(top, bottom))
			if m == left:
				p.x = r.position.x - radius
			elif m == right:
				p.x = r.end.x + radius
			elif m == top:
				p.y = r.position.y - radius
			else:
				p.y = r.end.y + radius
	return p


## Garde un cercle (position logique) dans le rectangle de la carte.
func clamp_to_bounds(p: Vector2, radius: float) -> Vector2:
	return from_map(_clamp_m(to_map(p), radius))


func _clamp_m(p: Vector2, radius: float) -> Vector2:
	return Vector2(
		clampf(p.x, bounds.position.x + radius, bounds.end.x - radius),
		clampf(p.y, bounds.position.y + radius, bounds.end.y - radius))


## Vrai si un corps de rayon `clearance` peut apparaître en `p` : dans la carte, cellule libre,
## aucun recouvrement d'obstacle, et atteignable par le champ courant (s'il existe).
func is_spawnable(p: Vector2, clearance: float = SPAWN_CLEARANCE) -> bool:
	p = to_map(p)
	var c := _cell_m(p)
	if c < 0 or blocked[c] != 0:
		return false
	if not bounds.grow(-clearance).has_point(p):
		return false
	if version > 0 and _dist[c] == UNREACHED:
		return false
	if not _reach.is_empty() and _reach[c] == 0: # poche fermée (murs en cercle, île d'eau profonde)
		return false
	var list := _cell_rects[c]
	for i in list.size():
		var r := rects[list[i]]
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		if p.distance_squared_to(q) < clearance * clearance:
			return false
	if _dyn_count > 0 and _cell_dyn.has(c):
		var pl := from_map(p)
		for id in _cell_dyn[c]:
			if _in_dyn(_dyn[id], pl, clearance):
				return false
	return true


## Test rapide (une lecture) : cellule bloquée ou hors grille. Utilisé par les projectiles.
func is_blocked_at(p: Vector2) -> bool:
	if not _flat:
		p = _l2m * p
	var fx := (p.x - _origin.x) * INV_CELL
	var fy := (p.y - _origin.y) * INV_CELL
	if fx < 0.0 or fy < 0.0 or fx >= w or fy >= h:
		return true
	return blocked[int(fy) * w + int(fx)] != 0


## Comme is_blocked_at mais murs STATIQUES de la carte seulement (placement d'un piège, d'un cocon : on ne
## refuse pas une case parce qu'un obstacle dynamique voisin la bloque).
func is_wall_at(p: Vector2) -> bool:
	if not _flat:
		p = _l2m * p
	var fx := (p.x - _origin.x) * INV_CELL
	var fy := (p.y - _origin.y) * INV_CELL
	if fx < 0.0 or fy < 0.0 or fx >= w or fy >= h:
		return true
	var c := int(fy) * w + int(fx)
	return (_static_blocked[c] if _static_blocked.size() > c else blocked[c]) != 0


## Vrai si le point est dans un obstacle (centre dans un rectangle) ou hors de la carte.
func is_inside_obstacle(p: Vector2) -> bool:
	p = to_map(p)
	if not bounds.has_point(p):
		return true
	var c := _cell_m(p)
	if c < 0:
		return true
	var list := _cell_rects[c]
	for i in list.size():
		if rects[list[i]].has_point(p):
			return true
	if _dyn_count > 0 and _cell_dyn.has(c):
		var pl := from_map(p)
		for id in _cell_dyn[c]:
			if _in_dyn(_dyn[id], pl, 0.0):
				return true
	return false


# --- Zone accessible (API publique : tout placement d'objet, de monstre ou de boss passe par là)
## Cellules joignables À PIED depuis le départ du joueur, calculées UNE fois par carte (build_from_map ->
## compute_reachable) : remplissage 4 voisins sur `blocked` (murs statiques, eau profonde « ~ » = rectangles
## de collision de la carte, obstacles dynamiques présents au calcul). 4 voisins = 8 voisins sans coupe de coin
## (règle du champ de flux et de la physique du joueur). Une poche fermée (murs en cercle, îlot entouré d'eau
## profonde) n'est jamais accessible : coffres, piliers, capsules, téléporteur, monstres et boss n'y vont pas.
## Obstacles dynamiques posés ENSUITE (cocons, conteneurs, blocs de cristal : temporaires, combats de boss) :
## pas de recalcul (une poche qu'ils fermeraient redevient libre à leur retrait) ; les requêtes refusent en plus
## les cellules qu'ils bloquent au moment de l'appel. Un changement DURABLE de la géométrie doit rappeler
## compute_reachable(). Requêtes O(1) (nearest_reachable : recherche en anneaux bornée, ponctuelle).
var _reach := PackedByteArray() ## 1 = cellule accessible ; vide = pas de calcul (toute cellule libre compte)
var reach_cells := PackedInt32Array() ## cellules accessibles (tirage uniforme O(1))
var reach_origin := Vector2.INF ## point de départ du dernier calcul (logique) ; INF = aucun calcul


## (Re)calcule la zone accessible depuis `from` (position logique globale, en général le départ du joueur).
## Départ dans un mur : la cellule libre la plus proche. Rend le nombre de cellules accessibles.
func compute_reachable(from: Vector2) -> int:
	_reach = PackedByteArray()
	reach_cells = PackedInt32Array()
	reach_origin = Vector2.INF
	if w == 0:
		return 0
	var n := w * h
	var sc := _cell_m(_clamp_m(to_map(from), 1.0))
	if sc < 0:
		return 0
	if blocked[sc] != 0:
		sc = _nearest_cell(sc, 32, false)
		if sc < 0:
			return 0
	_reach.resize(n)
	_reach.fill(0)
	_reach[sc] = 1
	reach_cells.append(sc)
	var head := 0
	var ortho := PackedInt32Array([1, -1, w, -w])
	while head < reach_cells.size():
		var c := reach_cells[head]
		head += 1
		for k in 4:
			var nc := c + ortho[k] # bordure bloquée : aucun test de bornes
			if blocked[nc] == 0 and _reach[nc] == 0:
				_reach[nc] = 1
				reach_cells.append(nc)
	reach_origin = from
	return reach_cells.size()


func has_reachability() -> bool:
	return not _reach.is_empty()


## Vrai si `p` (logique global) est sur une cellule accessible à pied et libre en ce moment (murs, eau profonde,
## obstacles dynamiques). Sans calcul : cellule libre. Hors grille : faux. O(1).
func is_reachable(p: Vector2) -> bool:
	var c := cell_of(p)
	if c < 0 or blocked[c] != 0:
		return false
	return _reach.is_empty() or _reach[c] != 0


## Vrai si `p` est sur une cellule de SOL libre (pas un mur) mais hors de la zone accessible : poche fermée.
## Un point dans un mur rend faux (resolve() l'en sort, du côté le plus proche). O(1).
func is_enclosed(p: Vector2) -> bool:
	if _reach.is_empty():
		return false
	var c := cell_of(p)
	return c >= 0 and _static_blocked[c] == 0 and _reach[c] == 0


## Point accessible le plus proche de `p` : `p` lui-même s'il l'est, sinon le centre de la cellule accessible
## la plus proche (anneaux jusqu'à `max_ring` cellules ; au-delà : `p` inchangé). Repère logique global.
func nearest_reachable(p: Vector2, max_ring: int = 48) -> Vector2:
	if w == 0 or is_reachable(p):
		return p
	var c := _cell_m(_clamp_m(to_map(p), 1.0))
	if c < 0:
		return p
	var best := _nearest_cell(c, max_ring, true, to_map(p))
	return from_map(_center_m(best)) if best >= 0 else p


## Centre d'une cellule accessible tirée au hasard (`rng`), libre d'obstacle dynamique ; Vector2.INF si aucune.
func random_reachable_point(rng: RandomNumberGenerator) -> Vector2:
	var cells := reach_cells if not _reach.is_empty() else free_cells
	if w == 0 or cells.is_empty():
		return Vector2.INF
	for k in 8:
		var c := cells[rng.randi_range(0, cells.size() - 1)]
		if blocked[c] == 0:
			return from_map(_center_m(c))
	return Vector2.INF


## Cellule la plus proche de `c` (anneaux de Chebyshev) : libre (`need_reach` faux) ou accessible et libre
## (`need_reach` vrai). Distance au point `pm` (repère carte), centre de `c` par défaut. -1 si rien.
func _nearest_cell(c: int, max_ring: int, need_reach: bool, pm: Vector2 = Vector2.INF) -> int:
	if pm == Vector2.INF:
		pm = _center_m(c)
	var cx := c % w
	var cy := c / w
	var best := -1
	var best_d := INF
	var found_ring := -1
	for r in range(1, max_ring + 1):
		if found_ring >= 0 and r > found_ring + 1: # l'anneau suivant peut encore être plus proche en euclidien
			break
		for y in range(cy - r, cy + r + 1):
			if y < 0 or y >= h:
				continue
			var edge := y == cy - r or y == cy + r
			var step := 1 if edge else 2 * r
			var x := cx - r
			while x <= cx + r:
				if x >= 0 and x < w:
					var nc := y * w + x
					if blocked[nc] == 0 and (not need_reach or _reach.is_empty() or _reach[nc] != 0):
						var d := _center_m(nc).distance_squared_to(pm)
						if d < best_d:
							best_d = d
							best = nc
							if found_ring < 0:
								found_ring = r
				x += step
	return best


# --- Obstacles dynamiques (API publique, docs : game/CONTRACTS.md « APIs publiques inter-systèmes »)
## Pose (ou remplace) l'obstacle `id` (clé quelconque : StringName, instance_id…). `shape` en repère LOGIQUE :
## Rect2 (boîte alignée), {center: Vector2, radius: float} (cercle) ou {center, half: Vector2, rot: float}
## (boîte orientée, rot en rad) ; clé optionnelle `small_only: true` dans le Dictionary : les gros corps (rayon >
## INDEX_GROW : boss) ne sont pas repoussés (blocs de la Mère-Cristal, qu'elle doit pouvoir enjamber).
## Les monstres le contournent (champ relancé au prochain créneau, cache local
## invalidé tout de suite) et resolve() les en sort ; les projectiles ennemis s'arrêtent sur ses cellules.
## Ne bloque PAS le joueur (physique) : un StaticBody2D couche 1 s'en charge si voulu. Faux sans grille.
func add_obstacle(id: Variant, shape: Variant) -> bool:
	if w == 0:
		return false
	var o := {}
	if shape is Rect2:
		var rc := shape as Rect2
		o = _make_box(rc.get_center(), rc.size * 0.5, 0.0)
	elif shape is Dictionary:
		var d := shape as Dictionary
		var c: Vector2 = d.get("center", Vector2.ZERO)
		if d.has("radius"):
			o = {"c": c, "r": maxf(float(d["radius"]), 1.0)}
		else:
			o = _make_box(c, d.get("half", Vector2(CELL, CELL) * 0.5), float(d.get("rot", 0.0)))
		o["small"] = bool(d.get("small_only", false))
	else:
		push_warning("NavField.add_obstacle : forme inconnue (Rect2 ou Dictionary attendu)")
		return false
	if _dyn.has(id):
		remove_obstacle(id)
	_dyn[id] = o
	_dyn_count += 1
	_stamp_dyn(id, o, 1)
	return true


## Raccourcis : cercle / boîte orientée (repère logique).
func add_circle_obstacle(id: Variant, center: Vector2, radius: float, small_only: bool = false) -> bool:
	return add_obstacle(id, {"center": center, "radius": radius, "small_only": small_only})


func add_box_obstacle(id: Variant, center: Vector2, half: Vector2, rot: float = 0.0) -> bool:
	return add_obstacle(id, {"center": center, "half": half, "rot": rot})


## Retire l'obstacle `id` (sans effet s'il n'existe pas). Retourne vrai s'il existait.
func remove_obstacle(id: Variant) -> bool:
	if not _dyn.has(id):
		return false
	var o: Dictionary = _dyn[id]
	_stamp_dyn(id, o, -1)
	_dyn.erase(id)
	_dyn_count -= 1
	return true


func has_obstacle(id: Variant) -> bool:
	return _dyn.has(id)


func obstacle_count() -> int:
	return _dyn_count


## Vrai si le point (logique) est dans un obstacle dynamique, à `margin` px près.
func in_dynamic_obstacle(p: Vector2, margin: float = 0.0) -> bool:
	for o in _dyn.values():
		if _in_dyn(o, p, margin):
			return true
	return false


func _make_box(c: Vector2, half: Vector2, rot: float) -> Dictionary:
	var xf := Transform2D(rot, c)
	return {"c": c, "r": 0.0, "half": Vector2(absf(half.x), absf(half.y)), "xf": xf, "inv": xf.affine_inverse()}


func _in_dyn(o: Dictionary, p: Vector2, margin: float) -> bool:
	var r := float(o["r"])
	if r > 0.0:
		return p.distance_squared_to(o["c"]) < (r + margin) * (r + margin)
	var lp: Vector2 = (o["inv"] as Transform2D) * p
	var hh: Vector2 = o["half"]
	if absf(lp.x) <= hh.x and absf(lp.y) <= hh.y:
		return true
	var q := Vector2(clampf(lp.x, -hh.x, hh.x), clampf(lp.y, -hh.y, hh.y))
	return lp.distance_squared_to(q) < margin * margin


## Marque (sgn 1) / démarque (-1) les cellules d'un obstacle : blocage (centre dedans), index de résolution,
## cache de direction local ; demande une relance du champ.
func _stamp_dyn(id: Variant, o: Dictionary, sgn: int) -> void:
	var bound := float(o["r"]) if float(o["r"]) > 0.0 else (o["half"] as Vector2).length()
	var k := 1.0 if _flat else maxf(_l2m.x.length(), _l2m.y.length())
	var cm := to_map(o["c"])
	var ext := bound * k + INDEX_GROW + CELL
	var x0 := maxi(int(floor((cm.x - ext - _origin.x) * INV_CELL)), 0)
	var x1 := mini(int(floor((cm.x + ext - _origin.x) * INV_CELL)), w - 1)
	var y0 := maxi(int(floor((cm.y - ext - _origin.y) * INV_CELL)), 0)
	var y1 := mini(int(floor((cm.y + ext - _origin.y) * INV_CELL)), h - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := y * w + x
			var cl := from_map(_center_m(c))
			# index de résolution : la cellule (demi-diagonale 0,71 CELL) touche l'obstacle grossi de INDEX_GROW
			if _in_dyn(o, cl, (INDEX_GROW + CELL * 0.71) / k):
				if sgn > 0:
					if not _cell_dyn.has(c):
						_cell_dyn[c] = []
					(_cell_dyn[c] as Array).append(id)
				elif _cell_dyn.has(c):
					var lst: Array = _cell_dyn[c]
					lst.erase(id)
					if lst.is_empty():
						_cell_dyn.erase(c)
				_near[c] = 1 if (not _cell_rects[c].is_empty() or _cell_dyn.has(c)) else 0
			if _in_dyn(o, cl, DYN_BLOCK_MARGIN / k):
				_dyn_block[c] = clampi(_dyn_block[c] + sgn, 0, 255)
				blocked[c] = 1 if (_static_blocked[c] != 0 or _dyn_block[c] > 0) else 0
	if not bool(o.get("small", false)): # « small_only » : les gros corps l'enjambent
		for L in _layer_list:
			_stamp_dyn_layer(L, o, sgn)
	# cache de direction invalidé autour : les cellules voisines re-choisissent leur pas au prochain steer
	var g := DYN_STAMP_RING
	for y in range(maxi(y0 - g, 0), mini(y1 + g, h - 1) + 1):
		for x in range(maxi(x0 - g, 0), mini(x1 + g, w - 1) + 1):
			_stamp[y * w + x] = -1
	_dirty = true


## Sort un cercle (repère logique) des obstacles dynamiques `ids`.
func _push_out_dyn(p: Vector2, radius: float, ids: Array) -> Vector2:
	for id in ids:
		var o: Dictionary = _dyn[id]
		if radius > INDEX_GROW and o.get("small", false):
			continue
		var r := float(o["r"])
		if r > 0.0:
			var c: Vector2 = o["c"]
			var d := p - c
			var rr := r + radius
			var d2 := d.length_squared()
			if d2 < rr * rr:
				p = c + (d / sqrt(d2) if d2 > 0.0001 else Vector2.RIGHT) * rr
			continue
		var lp: Vector2 = (o["inv"] as Transform2D) * p
		var hh: Vector2 = o["half"]
		var q := Vector2(clampf(lp.x, -hh.x, hh.x), clampf(lp.y, -hh.y, hh.y))
		var dd := lp - q
		var dd2 := dd.length_squared()
		if dd2 >= radius * radius:
			continue
		if dd2 > 0.0001:
			lp = q + dd / sqrt(dd2) * radius
		elif hh.x - absf(lp.x) < hh.y - absf(lp.y):
			lp.x = (1.0 if lp.x >= 0.0 else -1.0) * (hh.x + radius)
		else:
			lp.y = (1.0 if lp.y >= 0.0 else -1.0) * (hh.y + radius)
		p = (o["xf"] as Transform2D) * lp
	return p


# --- Chemin ponctuel (hors champ du joueur)
## Chemin de `from` vers `to` (positions logiques) qui contourne murs et obstacles dynamiques : BFS 8 voisins
## (sans coupe de coin) depuis la cellule de `from` (qui peut être bloquée), arrêté à la première cellule libre
## à moins de `reach_px` de `to` (cible dans l'eau ou un mur : on s'arrête au bord) ou après `max_cells`
## cellules (on garde alors la plus proche de `to`). Rend les points de passage (centres de cellules réduits par
## ligne de vue) puis `to`. Vide sans grille. Coût ponctuel (BFS borné) : à appeler au début d'un trajet
## (retour à l'eau de l'Anguille), jamais par image.
func find_path(from: Vector2, to: Vector2, reach_px: float = CELL, max_cells: int = 4096) -> PackedVector2Array:
	var out := PackedVector2Array()
	if w == 0:
		return out
	var fm := to_map(from)
	var tm := to_map(to)
	var sc := _cell_m(_clamp_m(fm, 1.0))
	if sc < 0:
		return out
	var n := w * h
	var parent := PackedInt32Array()
	parent.resize(n)
	parent.fill(-2)
	parent[sc] = -1
	var q := PackedInt32Array([sc])
	var head := 0
	var best := sc
	var best_d := _center_m(sc).distance_squared_to(tm)
	var reach2 := reach_px * reach_px
	var found := best_d <= reach2
	while head < q.size() and head < max_cells and not found:
		var c := q[head]
		head += 1
		for k in 8:
			var nc := c + _off[k]
			if nc < 0 or nc >= n or blocked[nc] != 0 or parent[nc] != -2:
				continue
			if k >= 4 and (blocked[c + _offx[k]] != 0 or blocked[c + _offy[k]] != 0):
				continue
			parent[nc] = c
			q.append(nc)
			var d2 := _center_m(nc).distance_squared_to(tm)
			if d2 < best_d:
				best_d = d2
				best = nc
				if d2 <= reach2:
					found = true
					break
	var cells := PackedInt32Array()
	var c2 := best
	while c2 >= 0:
		cells.append(c2)
		c2 = parent[c2]
	cells.reverse()
	# réduction par ligne de vue : un point gardé quand la cellule suivante n'est plus visible du dernier gardé
	var keep := 0
	for i in range(1, cells.size()):
		if not _line_clear(cells[keep], cells[i]):
			keep = i - 1
			out.append(from_map(_center_m(cells[keep])))
	if cells.size() > 1:
		out.append(from_map(_center_m(cells[cells.size() - 1])))
	out.append(to)
	return out
