extends Node
## Registre des joueurs de la partie (autoload `Players`, coop 1-4 ; docs/multi/Archi_Reseau.md §2 ligne 2 et §3).
## Une entrée par joueur : id (emplacement 0-3, 0 = joueur 1), nœud du joueur, PlayerState (RunState.player_state(id)),
## source d'entrée (InputSource), activité (absence > Balance.MULTI_AFK_S). Vivant / spectateur : PlayerState.spectating
## et la propriété `dead` du nœud.
##
## Solo sans inscription : tant que personne n'est inscrit, le registre voit un joueur 1 IMPLICITE = premier nœud du
## groupe `player` (état RunState.local(), source globale). Les appels get_nodes_in_group(&"player") peuvent donc déjà
## passer par Players.local() / nearest() / alive() sans attendre que main.gd inscrive ses joueurs (étape 2).
##
## Performance : au plus 4 entrées, aucune allocation par appel dans nearest() ; all() et alive() remplissent un
## tableau interne réutilisé (ne pas le modifier ni le garder d'une image à l'autre : le copier si besoin).

class Entry:
	extends RefCounted
	var id := 0
	var node: Node2D
	var state: PlayerState
	var input: InputSource
	var last_active_s := 0.0 ## horloge de jeu (Players.clock_s) de la dernière entrée ou du dernier dégât infligé
	var is_local := true ## faux pour un joueur distant (réseau, étape en ligne)


var _entries: Array[Entry] = [] ## triées par id
var _buf: Array[Node2D] = [] ## tableau réutilisé par all() / alive()
var _implicit_node: Node2D
var _implicit_input: InputSource
## Horloge de jeu (s) : avance hors pause, sert à l'absence (AFK).
var clock_s := 0.0


func _ready() -> void:
	process_physics_priority = -100 # lecture des sources par appareil avant les joueurs


func _physics_process(_delta: float) -> void:
	for e in _entries:
		if e.input != null:
			e.input.poll()


func _process(delta: float) -> void:
	clock_s += delta


func _input(event: InputEvent) -> void:
	if _entries.is_empty() or event is InputEventMouseMotion:
		return
	for e in _entries:
		if e.input != null and e.input.owns_event(event):
			e.last_active_s = clock_s


# --- Inscription ------------------------------------------------------------------------
## Inscrit un joueur. `id` < 0 : premier emplacement libre. `state` null : RunState.player_state(id). `input` null :
## source globale (comportement solo actuel). Retourne l'id, ou -1 si la partie est pleine ou l'id déjà pris.
func register(node: Node2D, input: InputSource = null, id: int = -1, state: PlayerState = null, is_local: bool = true) -> int:
	if id < 0:
		id = _free_id()
	if id < 0 or id >= Balance.MULTI_MAX_PLAYERS or _index_of(id) >= 0:
		return -1
	var e := Entry.new()
	e.id = id
	e.node = node
	e.state = state if state != null else RunState.player_state(id)
	e.input = input if input != null else InputSource.global_source()
	e.last_active_s = clock_s
	e.is_local = is_local
	var at := 0
	while at < _entries.size() and _entries[at].id < id:
		at += 1
	_entries.insert(at, e)
	Events.party_changed.emit(_entries.size())
	return id


func unregister(id: int) -> void:
	var i := _index_of(id)
	if i < 0:
		return
	_entries.remove_at(i)
	Events.party_changed.emit(_entries.size())


## Vide le registre (fin de run, tests). Le joueur 1 implicite (groupe `player`) reprend la main.
func clear() -> void:
	if _entries.is_empty():
		return
	_entries.clear()
	Events.party_changed.emit(0)


## Remplace le nœud d'un joueur inscrit (nouvelle scène d'étage).
func set_node(id: int, node: Node2D) -> void:
	var e := entry(id)
	if e != null:
		e.node = node


func set_input(id: int, input: InputSource) -> void:
	var e := entry(id)
	if e != null and input != null:
		e.input = input


# --- Lecture ----------------------------------------------------------------------------
## Joueurs de la partie (inscrits ; 1 en solo sans inscription si un joueur existe, sinon 0).
func count() -> int:
	if not _entries.is_empty():
		return _entries.size()
	return 1 if _implicit() != null else 0


func entries() -> Array[Entry]:
	return _entries


func entry(id: int) -> Entry:
	var i := _index_of(id)
	return _entries[i] if i >= 0 else null


func by_id(id: int) -> Node2D:
	if _entries.is_empty():
		return _implicit() if id == 0 else null
	var e := entry(id)
	return e.node if e != null and is_instance_valid(e.node) else null


## Id du joueur porté par ce nœud (Events.NO_PLAYER si inconnu).
func id_of(node: Node) -> int:
	if node == null:
		return Events.NO_PLAYER
	if _entries.is_empty():
		return 0 if node == _implicit() else Events.NO_PLAYER
	for e in _entries:
		if e.node == node:
			return e.id
	return Events.NO_PLAYER


func state_of(id: int) -> PlayerState:
	if _entries.is_empty():
		return RunState.local() if id == 0 else null
	var e := entry(id)
	return e.state if e != null else null


func input_of(id: int) -> InputSource:
	if _entries.is_empty():
		if id != 0:
			return null
		if _implicit_input == null:
			_implicit_input = InputSource.global_source()
		return _implicit_input
	var e := entry(id)
	return e.input if e != null else null


## Joueur local principal (caméra, HUD) : premier joueur local inscrit, ou le joueur 1 implicite.
func local() -> Node2D:
	if _entries.is_empty():
		return _implicit()
	for e in _entries:
		if e.is_local and is_instance_valid(e.node):
			return e.node
	return null


func local_id() -> int:
	if _entries.is_empty():
		return 0
	for e in _entries:
		if e.is_local:
			return e.id
	return Events.NO_PLAYER


## Tous les nœuds de joueurs valides (tableau interne réutilisé).
func all() -> Array[Node2D]:
	_buf.clear()
	if _entries.is_empty():
		var p := _implicit()
		if p != null:
			_buf.append(p)
		return _buf
	for e in _entries:
		if is_instance_valid(e.node):
			_buf.append(e.node)
	return _buf


func is_alive(id: int) -> bool:
	if _entries.is_empty():
		var p := _implicit()
		return id == 0 and p != null and not _node_dead(p) and not RunState.local().spectating
	var e := entry(id)
	return e != null and is_instance_valid(e.node) and not e.state.spectating and not _node_dead(e.node)


## Joueurs vivants (ni spectateurs ni morts), tableau interne réutilisé.
func alive() -> Array[Node2D]:
	_buf.clear()
	if _entries.is_empty():
		var p := _implicit()
		if p != null and not _node_dead(p) and not RunState.local().spectating:
			_buf.append(p)
		return _buf
	for e in _entries:
		if is_instance_valid(e.node) and not e.state.spectating and not _node_dead(e.node):
			_buf.append(e.node)
	return _buf


func alive_count() -> int:
	if _entries.is_empty():
		return 1 if is_alive(0) else 0
	var n := 0
	for e in _entries:
		if is_instance_valid(e.node) and not e.state.spectating and not _node_dead(e.node):
			n += 1
	return n


## Joueur le plus proche de `pos` (vivants seulement par défaut), ou null. Aucune allocation.
func nearest(pos: Vector2, alive_only: bool = true) -> Node2D:
	if _entries.is_empty():
		var p := _implicit()
		if p == null or (alive_only and (_node_dead(p) or RunState.local().spectating)):
			return null
		return p
	var best: Node2D = null
	var best_d := INF
	for e in _entries:
		if not is_instance_valid(e.node):
			continue
		if alive_only and (e.state.spectating or _node_dead(e.node)):
			continue
		var d := pos.distance_squared_to(e.node.global_position)
		if d < best_d:
			best_d = d
			best = e.node
	return best


# --- Absence (AFK) ----------------------------------------------------------------------
## Activité hors entrées (dégât infligé…) : repousse l'absence du joueur.
func note_activity(id: int) -> void:
	var e := entry(id)
	if e != null:
		e.last_active_s = clock_s


func is_afk(id: int) -> bool:
	var e := entry(id)
	return e != null and clock_s - e.last_active_s > Balance.MULTI_AFK_S


## n pour l'équilibrage (Balance.difficulty, crédits, coffres) : joueurs inscrits non absents, au moins 1.
## Lu au début de chaque étage (RunState.begin_floor -> RunState.party_size). Un joueur absent depuis plus de
## Balance.MULTI_AFK_S est retiré ; il revient au recalcul suivant dès qu'il rejoue.
func party_size_for_scaling() -> int:
	if _entries.size() <= 1:
		return 1
	var n := 0
	for e in _entries:
		if not is_afk(e.id):
			n += 1
	return maxi(n, 1)


# --- Mort et résurrection (décision du joueur, 01/11/2026) ------------------------------
## Le joueur `id` meurt : spectateur jusqu'au début de l'étage suivant. Si plus personne n'est vivant : party_wiped.
func set_spectating(id: int) -> void:
	var st := state_of(id)
	if st == null or st.spectating:
		return
	st.spectating = true
	Events.player_spectating.emit(id)
	if alive_count() == 0:
		Events.party_wiped.emit()


## Début d'étage : tous les spectateurs reviennent (PV Balance.MULTI_RESURRECT_HP_PCT, à appliquer par l'appelant).
func resurrect_all() -> void:
	if _entries.is_empty():
		if RunState.local().spectating:
			RunState.local().spectating = false
			Events.player_resurrected.emit(0)
		return
	for e in _entries:
		if e.state.spectating:
			e.state.spectating = false
			Events.player_resurrected.emit(e.id)


# --- Interne ----------------------------------------------------------------------------
func _implicit() -> Node2D:
	if is_instance_valid(_implicit_node) and _implicit_node.is_inside_tree() and _implicit_node.is_in_group(&"player"):
		return _implicit_node
	_implicit_node = null
	if not is_inside_tree():
		return null
	var n := get_tree().get_first_node_in_group(&"player")
	if n is Node2D:
		_implicit_node = n
	return _implicit_node


static func _node_dead(n: Node) -> bool:
	return bool(n.get(&"dead")) if &"dead" in n else false


func _index_of(id: int) -> int:
	for i in _entries.size():
		if _entries[i].id == id:
			return i
	return -1


func _free_id() -> int:
	for id in Balance.MULTI_MAX_PLAYERS:
		if _index_of(id) < 0:
			return id
	return -1
