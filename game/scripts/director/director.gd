class_name Director
extends Node2D
## Director de spawn (Maths §3) + gestionnaire unique des monstres actifs.
## À placer dans la scène de jeu sous le nom `Director` (position quelconque : les monstres sont
## dans un conteneur trié en y, en coordonnées monde ; le Director reste à l'origine sous Main/World). Groupe `director`.
##
## Performance (cible : 250 monstres, Android bas de gamme) :
## - pools préchauffés dans _ready (monstres, boss, projectiles) : aucune instanciation en jeu ;
## - une seule boucle _physics_process pour tous les monstres (pas de callback par nœud) ;
## - séparation par grille spatiale à listes chaînées (PackedInt32Array, zéro allocation),
##   mise à jour d'un quart des monstres par frame ; Meute évaluée en 15 tranches ;
## - pas de physique de déplacement : simple intégration de position ;
## - LOD : monstres hors écran simulés une frame sur deux (pas de 2 × delta) ;
## - obstacles : NavField (champ de flux BFS étalé sur plusieurs frames + pénétration cercle/rect).
##
## Carte : appeler bind_map(map) au début de chaque étage (après add_child de la carte). À défaut,
## le Director la détecte seul (toutes les 30 frames tant qu'il n'en a pas, et à Events.floor_started) :
## groupe `stage_map` s'il existe, sinon premier nœud dont le script est `StageMap` (profondeur ≤ 4).
## Une carte libérée est oubliée automatiquement (retour à la poursuite directe).

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")

const BOSS_POOL := 3
const PROJECTILE_POOL := 220
const MAX_SPAWNS_PER_FRAME := 6
const SPAWN_TRIES := 10 ## tirages sur le bord de l'écran avant le repli par cellules libres
const SPAWN_FALLBACK_TRIES := 40
## Mise en route de début de run (Balance.director_ramp / director_alive_cap) ; coupée par les tests de débit.
@export var spawn_ramp := true
const CREDIT_BANK_MAX := 1000.0 ## report des crédits au plafond, borné (évite un flot infini)
const SPAWN_MARGIN_PX := 96.0
## Caméra iso (docs/Design_Isometrique.md §6.2) : un monstre dont les pieds sont juste sous le bord bas
## reste visible (son sprite monte de Iso.lift_logical(h) en y logique). Marge du bas = hauteur visible
## d'un monstre de base (≈ 2 u : +3,5 u en y logique) ; les bords haut et côtés gardent SPAWN_MARGIN_PX.
const SPAWN_SPRITE_HEIGHT_U := 2.0
const RECYCLE_FACTOR := 1.6 ## au-delà de cette distance (× demi-diagonale d'apparition), le monstre est replacé
const LOD_MARGIN_PX := 128.0 ## au-delà de l'écran + cette marge : simulation à demi-cadence
const SEP_CELL_PX := 96.0
const GRID_DIM := 48 ## fenêtre 48×48 cellules centrée sur le joueur (≈ 4600 px)
const SEP_STRENGTH_PX := 220.0
const SEP_MAX_NEIGHBORS := 8
const SEP_PHASES := 4 ## séparation recalculée pour 1/4 des monstres par frame
const PACK_RADIUS_PX := 3.0 * 64.0 ## « 3 m » = 3 u
const PACK_MIN_ALLIES := 5
const PACK_SLICES := 15

@export var spawning_enabled := true
@export var enemy_pool_size := Balance.MAX_ENEMIES
## Vagues (Balance.WAVE_*) : faux = tout en flux continu (ancien comportement).
@export var waves_enabled := true

## Vague lancée : `side` = normale du bord d'écran (UP/RIGHT/DOWN/LEFT), `count` = monstres en file.
signal wave_started(side: Vector2, count: int)

const WAVE_SPAWNS_PER_FRAME := 10
const WAVE_DEPTH_PX := 160.0 ## profondeur d'étalement d'une vague au-delà du bord d'écran
const WAVE_SIDES: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const WAVE_SOUND := &"telegraph.warn_heavy.heavy" ## grave et bref : joué plus bas et moins fort
const WAVE_SOUND_DB := -6.0
const WAVE_SOUND_PITCH := 0.7

var credits := 0.0 ## banque du flux continu
var wave_credits := 0.0 ## banque des vagues
var wave_timer := 0.0 ## secondes avant la prochaine vague
var wave_count := 0 ## vagues lancées depuis le début (tests, statistiques)
var spawned_total := 0 ## monstres apparus depuis le début (tests, statistiques)
var last_wave_side := Vector2.ZERO
var last_wave_positions := PackedVector2Array() ## points d'apparition de la dernière vague (tests)
var _wave_queue: Array[Dictionary] = [] ## {tier, elite, variant, cost} en attente d'apparition
var _wave_along := 0.0 ## centre de la vague le long du bord, dans [-1, 1]
var stat_tick_usec := 0 ## coût de la dernière frame physique du Director (µs), pour les tests
var stat_breakdown_usec := PackedInt64Array([0, 0, 0, 0, 0, 0]) ## grille+meute+séparation, ticks, projectiles, dont grille, dont meute, champ de flux
var nav: NavField = null ## champ de flux de la carte liée (lecture seule pour les autres systèmes)

var _container: Node2D
var _projectiles: EnemyProjectilePool
var corpses: CorpsePool ## cadavres des monstres de base (anim death des sprites v2)
var _free: Array[Enemy] = []
var _active: Array[Enemy] = [] ## monstres hors boss (comptent pour le plafond)
var _free_bosses: Array[Enemy] = []
var _bosses: Array[Enemy] = []
var _zones := {} ## id -> {center: Vector2, radius: float, active: bool, kind: StringName}
var _rng := RandomNumberGenerator.new()
var _player: Node2D
var _next_tier := 0
var _next_elite := false
var _frame := 0
var _map: Node2D = null
var _detect_now := false

# Grille de séparation (snapshot par frame)
var _snap: Array[Enemy] = []
var _pos := PackedVector2Array()
var _rad := PackedFloat32Array()
var _tier := PackedInt32Array() ## tier par index du snapshot (Meute : évite un accès objet par voisin)
var _roster := 0 ## incrémenté à chaque apparition / retour au pool (snapshot, rayons et tiers à relire)
var _grid_roster := -1
var _sep := PackedVector2Array()
var _cell_of := PackedInt32Array()
var _next := PackedInt32Array()
var _head := PackedInt32Array()
var _steer := PackedVector2Array() ## direction de champ par index du snapshot (1/2 recalculée par frame)
var _walls := PackedByteArray() ## 1 = mur à portée de résolution (NavField.walls_many), 0 = resolve épargné


func _ready() -> void:
	add_to_group(&"director")
	_rng.seed = hash(RunState.rng.seed) ^ 0x5eed
	_container = Node2D.new()
	_container.name = &"Enemies"
	_container.y_sort_enabled = true # trié avec le joueur et la carte sous Main/World (le Director reste à l'origine)
	add_child(_container)
	# chaîne de tri CanvasItem : le Director doit être trié lui aussi pour que ses monstres se mêlent à
	# World (joueur, coffres, blocs) ; ses autres enfants (projectiles, impacts) restent au-dessus par z.
	y_sort_enabled = true
	corpses = CorpsePool.new()
	corpses.name = &"Corpses"
	add_child(corpses)
	_projectiles = EnemyProjectilePool.new()
	_projectiles.name = &"EnemyProjectiles"
	_projectiles.z_index = maxi(_projectiles.z_index, 10) # §2.3 : projectiles au-dessus des murs (lisibilité)
	add_child(_projectiles)
	_projectiles.prewarm(PROJECTILE_POOL)
	for i in enemy_pool_size:
		_free.append(_make_enemy())
	for i in BOSS_POOL:
		_free_bosses.append(_make_enemy())
	_head.resize(GRID_DIM * GRID_DIM)
	wave_timer = _rng.randf_range(Balance.WAVE_INTERVAL_MIN_S, Balance.WAVE_INTERVAL_MAX_S)
	Events.floor_started.connect(func(_stage: int) -> void: _detect_now = true)


func _make_enemy() -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.director = self
	e.nav = nav
	_container.add_child(e)
	return e


# --- API publique (contrat)
func spawn_boss(kind: StringName, pos: Vector2) -> Node2D:
	var b: Enemy
	if _free_bosses.is_empty():
		push_warning("Director : pool de boss épuisé, instanciation à chaud")
		b = _make_enemy()
	else:
		b = _free_bosses.pop_back()
	if nav != null and not nav.is_reachable(pos): # jamais dans un mur ni une poche fermée (aucun boss ne traverse les murs)
		pos = nav.nearest_reachable(pos)
	b.activate_boss(kind, pos, RunState.difficulty())
	b.pool_index = _bosses.size()
	_bosses.append(b)
	Events.boss_spawned.emit(b, kind == &"etage")
	return b


## Lie la carte de l'étage (StageMap ou tout Node2D contenant des StaticBody2D couche 1).
## null = aucune carte (poursuite directe). À appeler une fois la carte dans l'arbre.
func bind_map(map: Node2D) -> void:
	if map != null and not map.is_inside_tree():
		bind_map.call_deferred(map)
		return
	_map = map
	nav = null
	if map != null:
		var nf := NavField.new()
		nf.build_from_map(map)
		if nf.is_valid():
			nav = nf
			var pl := get_tree().get_first_node_in_group(&"player") as Node2D
			nf.compute_now(pl.global_position if pl else nf.from_map(nf.bounds.get_center()))
	for list: Array[Enemy] in [_free, _active, _free_bosses, _bosses]:
		for e in list:
			e.nav = nav
			if nav and e.active:
				e.position = nav.resolve(e.position, e.radius_px)


func get_map() -> Node2D:
	return _map


func _map_alive() -> bool:
	return _map != null and is_instance_valid(_map) and _map.is_inside_tree() and not _map.is_queued_for_deletion()


func _auto_detect_map() -> void:
	_detect_now = false
	var found: Node2D = null
	for n in get_tree().get_nodes_in_group(&"stage_map"):
		if n is Node2D and not n.is_queued_for_deletion():
			found = n
			break
	if found == null:
		found = _find_stage_map(get_tree().root, 0)
	if found != null and found != _map:
		bind_map(found)
	elif found == null and _map != null:
		bind_map(null)


func _find_stage_map(n: Node, depth: int) -> Node2D:
	for ch in n.get_children():
		if ch == self:
			continue
		var sc: Script = ch.get_script()
		if ch is Node2D and sc != null and sc.get_global_name() == &"StageMap" and not ch.is_queued_for_deletion():
			return ch
		if depth < 4:
			var r := _find_stage_map(ch, depth + 1)
			if r != null:
				return r
	return null


## `kind` : &"mini" (pilier de mini-boss) ou &"etage" (charge du téléporteur) ; règle le bonus de crédits
## (Balance.ZONE_SPAWN_MULT, Alignement RoR2).
func set_zone(id: int, center: Vector2, radius: float, active: bool, kind: StringName = &"mini") -> void:
	_zones[id] = {"center": center, "radius": radius, "active": active, "kind": kind}


## Fait apparaître un monstre immédiatement (hors budget). Utilisé par le director et les tests.
## `variant` (tier 2) : Enemy.VARIANT_SHOOTER / VARIANT_LEAPER, -1 = tirage (Balance.LEAPER_SHARE).
func spawn_enemy(tier: int, pos: Vector2, elite: bool = false, affixes: Array[StringName] = [], variant: int = -1) -> Enemy:
	if _free.is_empty():
		return null
	var D := RunState.difficulty()
	if elite and affixes.is_empty():
		affixes = _roll_affixes(D)
	if variant < 0:
		variant = Enemy.VARIANT_LEAPER if tier == 2 and _rng.randf() < Balance.LEAPER_SHARE else Enemy.VARIANT_SHOOTER
	var e: Enemy = _free.pop_back()
	spawned_total += 1
	if nav != null and nav.is_enclosed(pos): # invocation, cocon… tombé dans une poche fermée : rabattu dehors
		pos = nav.nearest_reachable(pos)
	e.activate(tier, pos, D, elite, affixes, variant)
	e.pool_index = _active.size()
	_active.append(e)
	_roster += 1
	return e


## Appelé par Enemy à sa mort : retour au pool.
func release_enemy(e: Enemy) -> void:
	_roster += 1
	e.deactivate()
	var list := _bosses if e.is_boss else _active
	var i := e.pool_index
	if i < 0 or i >= list.size() or list[i] != e:
		i = list.find(e)
		if i < 0:
			return
	var last: Enemy = list[list.size() - 1]
	list[i] = last
	last.pool_index = i
	list.pop_back()
	e.pool_index = -1
	if e.is_boss:
		_free_bosses.append(e)
	else:
		_free.append(e)


## Retire tous les monstres, boss et projectiles sans émettre de mort (changement d'étage).
func despawn_all() -> void:
	corpses.clear()
	for e in _active.duplicate():
		release_enemy(e)
	for b in _bosses.duplicate():
		release_enemy(b)
	_projectiles.clear_all()
	credits = 0.0
	_next_tier = 0
	wave_credits = 0.0
	_wave_queue.clear()
	wave_timer = _rng.randf_range(Balance.WAVE_INTERVAL_MIN_S, Balance.WAVE_INTERVAL_MAX_S)


## Retourne le projectile (habillage optionnel : EnemyProjectilePool.set_skin).
func fire_projectile(source: Node2D, pos: Vector2, velocity: Vector2, damage: float) -> Node2D:
	return _projectiles.fire(source, pos, velocity, damage)


func active_count() -> int:
	return _active.size()


func free_count() -> int:
	return _free.size()


func boss_count() -> int:
	return _bosses.size()


func projectile_count() -> int:
	return _projectiles.active_count()


## Ombres de contact (CreatureShadows) : écrit, à partir de l'index d'instance `n`, une transformation
## MultiMesh TRANSFORM_2D par monstre du snapshot de la grille (_snap / _rad, relus seulement quand la
## liste change) puis par boss, à la position courante. Disque de largeur rayon × `w_per_r`, hauteur
## × `flat`, abaissé de 0,15 rayon (0,5 pour un boss) ; monstre inactif ou masqué = échelle 0 (l'index
## reste celui du snapshot). Perf : seuls les 4 termes utiles sont écrits, les termes hors diagonale
## du tampon (indices 1, 2, 4, 6) doivent rester nuls (contrat de CreatureShadows).
## Retourne le nouveau nombre d'instances (plafonné à `max_n`). Coordonnées du conteneur = monde
## (le Director reste à l'origine).
func fill_contact_shadows(buf: PackedFloat32Array, n: int, max_n: int, w_per_r: float, flat: float) -> int:
	var m := mini(mini(_snap.size(), _rad.size()), max_n - n)
	var k := n * 8
	for i in m:
		var e := _snap[i]
		var r := _rad[i] if e.visible else 0.0 # visible <=> actif (Enemy.activate / deactivate)
		var w := r * w_per_r
		var p := e.position
		buf[k] = w
		buf[k + 3] = p.x
		buf[k + 5] = w * flat
		buf[k + 7] = p.y + r * 0.15
		k += 8
	n += maxi(m, 0)
	for b in _bosses:
		if n >= max_n:
			return n
		if not b.active or not b.visible or b.radius_px <= 0.0:
			continue
		var w := b.radius_px * w_per_r
		k = n * 8
		buf[k] = w
		buf[k + 3] = b.position.x
		buf[k + 5] = w * flat
		buf[k + 7] = b.position.y + b.radius_px * 0.5
		n += 1
	return n


# --- Boucle
func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_frame += 1
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	var has_player := _player != null
	var ppos := _player.global_position if has_player else Vector2.ZERO
	if _detect_now or (_frame % 30 == 0 and not _map_alive()):
		_auto_detect_map()
	var tn := Time.get_ticks_usec()
	if nav and has_player:
		nav.update(ppos, delta)
	stat_breakdown_usec[5] = Time.get_ticks_usec() - tn

	if spawning_enabled and has_player:
		_update_spawning(delta, ppos)

	var t1 := Time.get_ticks_usec()
	_build_grid(ppos)
	var ta := Time.get_ticks_usec()
	_update_pack(_frame % PACK_SLICES)
	var tb := Time.get_ticks_usec()
	_compute_separation(_frame % SEP_PHASES)
	var t2 := Time.get_ticks_usec()
	stat_breakdown_usec[3] = ta - t1
	stat_breakdown_usec[4] = tb - ta

	var half_diag := _spawn_half_extent().length()
	var recycle_r2 := half_diag * RECYCLE_FACTOR * half_diag * RECYCLE_FACTOR
	# LOD inchangé (cercle) : la marge iso du bas n'y est pas ajoutée (mesuré : +0,1-0,2 ms à 250 monstres) ;
	# un monstre dans la bande du bas, pieds hors écran, peut être simulé à demi-cadence.
	var lod_r2 := (half_diag + LOD_MARGIN_PX) * (half_diag + LOD_MARGIN_PX)
	var odd := _frame & 1
	var n := _snap.size()
	if nav == null:
		_steer.fill(Vector2.ZERO) # poursuite directe
	else: # champ de flux : direction rafraîchie une frame sur deux (une moitié des monstres), en un seul appel
		if _walls.size() != n:
			_walls.resize(n)
		nav.steer_walls_many(_pos, _steer, _walls, odd, n)
	if has_player:
		var player := _player
		var delta2 := delta * 2.0
		for i in n:
			var e := _snap[i]
			if not e.active:
				continue
			# LOD : hors écran, un monstre n'est simulé qu'une frame sur deux (avec 2 × delta)
			var d2 := _pos[i].distance_squared_to(ppos)
			if d2 <= lod_r2:
				e.tick(delta, player, ppos, _sep[i], _steer[i], nav == null or _walls[i] != 0)
			elif (i & 1) == odd:
				if d2 > recycle_r2:
					var rp := _spawn_point(ppos) # trop loin : replacé hors écran
					if rp != Vector2.INF:
						e.position = rp
					continue
				e.tick(delta2, player, ppos, _sep[i], _steer[i], nav == null or _walls[i] != 0)
	else:
		for i in n:
			var e := _snap[i]
			if e.active:
				e.tick(delta, null, e.position, Vector2.ZERO)
	if not _bosses.is_empty():
		for b in _bosses.duplicate():
			if b.active:
				b.tick(delta, _player, ppos if has_player else b.position, Vector2.ZERO, nav.steer(b.position) if nav else Vector2.ZERO)

	var t3 := Time.get_ticks_usec()
	_projectiles.update(delta, _player, ppos, nav)
	var t4 := Time.get_ticks_usec()
	stat_tick_usec = t4 - t0
	stat_breakdown_usec[0] = t2 - t1
	stat_breakdown_usec[1] = t3 - t2
	stat_breakdown_usec[2] = t4 - t3


# --- Spawn
func _update_spawning(delta: float, ppos: Vector2) -> void:
	var D := RunState.difficulty()
	var zone = _player_zone(ppos)
	var zone_kind: StringName = zone["kind"] if zone != null else &""
	var t := RunState.active_time_s
	var ramp := Balance.director_ramp(t) if spawn_ramp else 1.0
	var income := Balance.director_credits_per_s(D, zone_kind) * ramp * delta
	var share := Balance.WAVE_STREAM_SHARE if waves_enabled else 1.0
	credits = minf(credits + income * share, CREDIT_BANK_MAX)
	var alive_cap := mini(Balance.director_alive_cap(t), Balance.MAX_ENEMIES) if spawn_ramp else Balance.MAX_ENEMIES
	if waves_enabled:
		wave_credits = minf(wave_credits + income * (1.0 - share), CREDIT_BANK_MAX)
		_update_waves(delta, ppos, D, alive_cap)
	var spawned := 0
	while spawned < MAX_SPAWNS_PER_FRAME and _active.size() < alive_cap and not _free.is_empty():
		if _next_tier == 0:
			_next_tier = _pick_tier(D)
			_next_elite = _rng.randf() < Balance.elite_chance(D)
		var cost: float = Balance.TIER_COST[_next_tier] * (Balance.ELITE_COST_MULT if _next_elite else 1.0)
		if credits < cost:
			break # on économise pour ce tirage (permet aux tiers chers d'apparaître)
		var sp := _spawn_point(ppos)
		if sp == Vector2.INF:
			break # aucun point valide cette frame : crédits conservés
		credits -= cost
		spawn_enemy(_next_tier, sp, _next_elite)
		_next_tier = 0
		spawned += 1


# --- Vagues (principe Risk of Rain 2)
func _update_waves(delta: float, ppos: Vector2, D: float, alive_cap: int) -> void:
	_spawn_wave_queue(ppos, alive_cap)
	wave_timer -= delta
	if wave_timer > 0.0 or not _wave_queue.is_empty():
		return
	if _launch_wave(ppos, D, alive_cap):
		wave_timer = _rng.randf_range(Balance.WAVE_INTERVAL_MIN_S, Balance.WAVE_INTERVAL_MAX_S)
	else:
		wave_timer = Balance.WAVE_RETRY_S


## Lance une vague tout de suite si les crédits et la place le permettent (tests, scripts d'étage).
func trigger_wave() -> bool:
	var t := RunState.active_time_s
	var cap := mini(Balance.director_alive_cap(t), Balance.MAX_ENEMIES) if spawn_ramp else Balance.MAX_ENEMIES
	var pl := _player if is_instance_valid(_player) else get_tree().get_first_node_in_group(&"player") as Node2D
	if pl == null or not _wave_queue.is_empty():
		return false
	return _launch_wave(pl.global_position, RunState.difficulty(), cap)


## Compose la vague avec wave_credits : un type dominant (tier + variante), parfois mélangé,
## parfois une élite en tête. Choisit un bord d'écran où l'on peut apparaître. Faux = reportée.
func _launch_wave(ppos: Vector2, D: float, alive_cap: int) -> bool:
	var room := mini(mini(alive_cap - _active.size(), _free.size()), Balance.WAVE_MAX_COUNT)
	if room < Balance.WAVE_MIN_COUNT:
		return false
	var tier := _pick_tier(D)
	while tier > 1 and wave_credits < Balance.TIER_COST[tier] * Balance.WAVE_MIN_COUNT:
		tier -= 1
	if wave_credits < Balance.TIER_COST[1] * Balance.WAVE_MIN_COUNT:
		return false
	var variant := -1 # tier 2 : une seule variante pour toute la vague (tireurs ou bondisseurs)
	if tier == 2:
		variant = Enemy.VARIANT_LEAPER if _rng.randf() < Balance.LEAPER_SHARE else Enemy.VARIANT_SHOOTER
	var same := _rng.randf() < Balance.WAVE_SAME_TYPE_CHANCE
	var bank := wave_credits
	var members: Array[Dictionary] = []
	if _rng.randf() < Balance.wave_leader_chance(D):
		var lc: float = Balance.TIER_COST[tier] * Balance.ELITE_COST_MULT
		if bank - lc >= Balance.TIER_COST[tier] * (Balance.WAVE_MIN_COUNT - 1):
			members.append({"tier": tier, "elite": true, "variant": variant, "cost": lc})
			bank -= lc
	while members.size() < room:
		var mt := tier if same else _pick_tier(D)
		var mv := variant if same else -1
		var el := _rng.randf() < Balance.elite_chance(D)
		var c: float = Balance.TIER_COST[mt] * (Balance.ELITE_COST_MULT if el else 1.0)
		if c > bank and el:
			el = false
			c = Balance.TIER_COST[mt]
		if c > bank and not same and bank >= Balance.TIER_COST[1]:
			mt = 1
			mv = -1
			c = Balance.TIER_COST[1]
		if c > bank:
			break
		bank -= c
		members.append({"tier": mt, "elite": el, "variant": mv, "cost": c})
	if members.size() < Balance.WAVE_MIN_COUNT:
		return false
	# bord d'écran : tirage, puis les suivants si aucun point valide de ce côté (carte, murs)
	var first := _rng.randi_range(0, 3)
	var side := Vector2.ZERO
	var along := 0.0
	for k in 4:
		var n: Vector2 = WAVE_SIDES[(first + k) % 4]
		var a := _rng.randf_range(-(1.0 - Balance.WAVE_SIDE_SPREAD), 1.0 - Balance.WAVE_SIDE_SPREAD)
		if _side_point(ppos, n, a) != Vector2.INF:
			side = n
			along = a
			break
	if side == Vector2.ZERO:
		return false
	# reliquat (moins qu'un monstre du type, ou au-delà de WAVE_MAX_COUNT) : rendu au flux continu
	credits = minf(credits + bank, CREDIT_BANK_MAX)
	wave_credits = 0.0
	last_wave_side = side
	_wave_along = along
	last_wave_positions.clear()
	_wave_queue = members
	wave_count += 1
	_spawn_wave_queue(ppos, alive_cap)
	_announce_wave(side, along)
	wave_started.emit(side, members.size())
	return true


## Fait apparaître la file de la vague (WAVE_SPAWNS_PER_FRAME par frame), du côté choisi.
## Plus de place (plafond) ou plus de point valide : les crédits non dépensés passent au flux continu.
func _spawn_wave_queue(ppos: Vector2, alive_cap: int) -> void:
	var n := 0
	while n < WAVE_SPAWNS_PER_FRAME and not _wave_queue.is_empty():
		var m: Dictionary = _wave_queue.pop_front()
		if _active.size() >= alive_cap or _free.is_empty():
			credits = minf(credits + float(m["cost"]), CREDIT_BANK_MAX)
			continue
		var sp := _side_point(ppos, last_wave_side, _wave_along)
		if sp == Vector2.INF:
			credits = minf(credits + float(m["cost"]), CREDIT_BANK_MAX)
			continue
		spawn_enemy(int(m["tier"]), sp, bool(m["elite"]), [], int(m["variant"]))
		last_wave_positions.append(sp)
		n += 1


## Point hors écran au-delà du bord `normal`, autour de la position `along` ([-1, 1]) le long du bord.
func _side_point(ppos: Vector2, normal: Vector2, along: float) -> Vector2:
	var box := _spawn_box()
	var half := box.size * 0.5
	var center := ppos + box.get_center() # décalé vers le bas de la moitié de la marge iso
	var tangent := Vector2(-normal.y, normal.x)
	var edge_half := absf(tangent.x) * half.x + absf(tangent.y) * half.y
	var depth := absf(normal.x) * half.x + absf(normal.y) * half.y
	for k in SPAWN_TRIES:
		var a := clampf(along + _rng.randf_range(-1.0, 1.0) * Balance.WAVE_SIDE_SPREAD, -1.0, 1.0)
		var p := center + normal * (depth + _rng.randf() * WAVE_DEPTH_PX) + tangent * (a * edge_half)
		if nav == null or nav.is_spawnable(p):
			return p
	if nav and not nav.free_cells.is_empty():
		var max_r := half.length() * RECYCLE_FACTOR * 0.9
		for k in SPAWN_FALLBACK_TRIES:
			var p := nav.cell_center(nav.free_cells[_rng.randi_range(0, nav.free_cells.size() - 1)])
			var d := p - center
			if d.dot(normal) >= depth and d.length() <= max_r and nav.is_spawnable(p):
				return p
	return Vector2.INF


## Annonce discrète : son grave + flèche au bord de l'écran côté vague (couche des télégraphes).
func _announce_wave(side: Vector2, along: float) -> void:
	Audio.play(WAVE_SOUND, Audio.NO_POS, WAVE_SOUND_DB, WAVE_SOUND_PITCH)
	var ind := WaveIndicator.new()
	ind.setup(self, side, along, Balance.WAVE_ANNOUNCE_S)
	var layer := AmbianceManager.telegraph_layer(get_tree())
	if layer != null:
		layer.add_child(ind)
	else:
		ind.top_level = true
		add_child(ind)


## Tirage du tier : vise le coût moyen 1 + DIRECTOR_MEAN_COST_SLOPE × (D - 1) parmi les tiers débloqués.
func _pick_tier(D: float) -> int:
	var mean := 1.0 + Balance.DIRECTOR_MEAN_COST_SLOPE * (D - 1.0)
	var p2 := 0.0
	var p3 := 0.0
	if D >= Balance.TIER_MIN_D[3]:
		var r := clampf((D - Balance.TIER_MIN_D[3]) / Balance.T3_RAMP_D, 0.0, 1.0) * Balance.T3_SHARE
		p2 = (mean - 1.0) / ((Balance.TIER_COST[2] - 1.0) + (Balance.TIER_COST[3] - 1.0) * r)
		p3 = p2 * r
	elif D >= Balance.TIER_MIN_D[2]:
		p2 = (mean - 1.0) / (Balance.TIER_COST[2] - 1.0)
	var total := p2 + p3
	if total > 0.8: # garde toujours au moins 20 % d'essaim
		p2 *= 0.8 / total
		p3 *= 0.8 / total
	var roll := _rng.randf()
	if roll < p3:
		return 3
	if roll < p3 + p2:
		return 2
	return 1


func _roll_affixes(D: float) -> Array[StringName]:
	var pool: Array[StringName] = [&"burn", &"slow", &"poison"]
	var out: Array[StringName] = []
	for k in Balance.elite_affix_count(D):
		out.append(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))
	return out


## Demi-étendue (monde) de la zone visible autour du joueur.
func _spawn_half_extent() -> Vector2:
	var vp := get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	var zoom := cam.zoom if cam else Vector2.ONE
	return vp / zoom * 0.5


## Marge du bas (px logiques) : hauteur de sprite d'un monstre exprimée en y logique (§6.2).
func _bottom_margin_px() -> float:
	return -Iso.lift_logical(SPAWN_SPRITE_HEIGHT_U)


## Rectangle d'apparition relatif au joueur : vue + SPAWN_MARGIN_PX, plus la marge iso en bas.
func _spawn_box() -> Rect2:
	var half := _spawn_half_extent() + Vector2(SPAWN_MARGIN_PX, SPAWN_MARGIN_PX)
	return Rect2(-half, half * 2.0 + Vector2(0.0, _bottom_margin_px()))


## Point juste hors écran (bordure du rectangle visible élargi). Dans une zone active où se
## trouve le joueur, on garde le meilleur de 3 candidats vers le centre de la zone.
## Avec une carte : jamais dans un obstacle, hors carte ou dans une poche inatteignable ;
## renvoie Vector2.INF si aucun point valide n'est trouvé (l'appelant réessaie plus tard).
func _spawn_point(ppos: Vector2) -> Vector2:
	var box := _spawn_box()
	var zone = _player_zone(ppos)
	var want := 3 if zone != null else 1
	var found := 0
	var best := Vector2.INF
	var best_d := INF
	for k in (SPAWN_TRIES if nav else want):
		var p := _rect_perimeter_point(box) + ppos
		if nav and not nav.is_spawnable(p):
			continue
		found += 1
		var d: float = p.distance_squared_to(zone["center"]) if zone != null else 0.0
		if d < best_d:
			best_d = d
			best = p
		if found >= want:
			break
	if found == 0 and nav:
		best = _nav_fallback_point(ppos, box)
	return best


## Repli (bord de carte, couloirs) : cellule libre au hasard, hors écran et pas trop loin ;
## en dernier recours une cellule libre à plus de 6 u du joueur (carte entièrement visible).
func _nav_fallback_point(ppos: Vector2, box: Rect2) -> Vector2:
	var cells := nav.free_cells
	if cells.is_empty():
		return Vector2.INF
	var max_r := box.size.length() * 0.5 * RECYCLE_FACTOR * 0.9
	var last_resort := Vector2.INF
	for k in SPAWN_FALLBACK_TRIES:
		var p := nav.cell_center(cells[_rng.randi_range(0, cells.size() - 1)])
		var d := p - ppos
		if not nav.is_spawnable(p):
			continue
		if not box.has_point(d):
			if d.length() <= max_r:
				return p
		elif last_resort == Vector2.INF and d.length() >= 6.0 * Balance.UNIT_PX:
			last_resort = p
	return last_resort


func _rect_perimeter_point(box: Rect2) -> Vector2:
	var w := box.size.x
	var h := box.size.y
	var a := box.position
	var b := box.end
	var t := _rng.randf() * (2.0 * (w + h))
	if t < w:
		return Vector2(a.x + t, a.y)
	t -= w
	if t < h:
		return Vector2(b.x, a.y + t)
	t -= h
	if t < w:
		return Vector2(b.x - t, b.y)
	t -= w
	return Vector2(a.x, b.y - t)


func _player_zone(ppos: Vector2):
	for z in _zones.values():
		if z["active"] and ppos.distance_to(z["center"]) <= z["radius"]:
			return z
	return null


# --- Séparation et Meute
func _build_grid(ppos: Vector2) -> void:
	var roster_changed := _grid_roster != _roster
	if roster_changed: # rayons et tiers ne changent qu'à l'apparition : relus seulement si la liste a bougé
		_grid_roster = _roster
		_snap.assign(_active)
	var n := _snap.size()
	_pos.resize(n)
	_rad.resize(n)
	_tier.resize(n)
	_cell_of.resize(n)
	_next.resize(n)
	if _steer.size() != n:
		_steer.resize(n)
	if _sep.size() != n:
		_sep.resize(n) # la moitié non recalculée reprend la valeur de l'index (approximation assumée)
	_head.fill(-1)
	if roster_changed:
		for i in n:
			var e := _snap[i]
			_rad[i] = e.radius_px
			_tier[i] = e.tier
	var origin := ppos - Vector2.ONE * (SEP_CELL_PX * GRID_DIM * 0.5)
	var ox := origin.x
	var oy := origin.y
	var inv := 1.0 / SEP_CELL_PX
	for i in n:
		var p := _snap[i].position
		_pos[i] = p
		var cx := int((p.x - ox) * inv)
		var cy := int((p.y - oy) * inv)
		if cx < 0 or cy < 0 or cx >= GRID_DIM or cy >= GRID_DIM:
			_cell_of[i] = -1
			_next[i] = -1
			continue
		var c := cy * GRID_DIM + cx
		_cell_of[i] = c
		_next[i] = _head[c]
		_head[c] = i


func _compute_separation(phase: int) -> void:
	var n := _snap.size()
	var i := phase
	while i < n:
		var c := _cell_of[i]
		if c < 0:
			_sep[i] = Vector2.ZERO
			i += SEP_PHASES
			continue
		var p := _pos[i]
		var ri := _rad[i]
		var push := Vector2.ZERO
		var seen := 0
		var cx := c % GRID_DIM
		var cy := c / GRID_DIM
		var x0 := maxi(cx - 1, 0)
		var x1 := mini(cx + 2, GRID_DIM)
		for yy in range(maxi(cy - 1, 0), mini(cy + 2, GRID_DIM)):
			var row := yy * GRID_DIM
			for xx in range(x0, x1):
				var j := _head[row + xx]
				while j >= 0 and seen < SEP_MAX_NEIGHBORS:
					if j != i:
						seen += 1 # plafond sur les candidats examinés : coût borné en foule dense
						var d := p - _pos[j]
						var min_d := ri + _rad[j]
						var d2 := d.length_squared()
						if d2 < min_d * min_d:
							if d2 > 0.0001:
								var dist := sqrt(d2)
								push += d / dist * (1.0 - dist / min_d)
							else:
								push += Vector2.from_angle(float(i))
					j = _next[j]
				if seen >= SEP_MAX_NEIGHBORS:
					break
			if seen >= SEP_MAX_NEIGHBORS:
				break
		_sep[i] = push * SEP_STRENGTH_PX
		i += SEP_PHASES


## Meute (T1) : +15 % de vitesse si ≥ 5 alliés à 3 u. Évaluée sur 1/15 des monstres par frame.
func _update_pack(slice: int) -> void:
	var n := _snap.size()
	var r2 := PACK_RADIUS_PX * PACK_RADIUS_PX
	var span := int(ceil(PACK_RADIUS_PX / SEP_CELL_PX))
	var i := slice
	while i < n:
		var e := _snap[i]
		if _tier[i] != 1 or _cell_of[i] < 0:
			e.pack_bonus = false
			i += PACK_SLICES
			continue
		var c := _cell_of[i]
		var cx := c % GRID_DIM
		var cy := c / GRID_DIM
		var count := 0
		var p := _pos[i]
		for yy in range(maxi(cy - span, 0), mini(cy + span + 1, GRID_DIM)):
			for xx in range(maxi(cx - span, 0), mini(cx + span + 1, GRID_DIM)):
				var j := _head[yy * GRID_DIM + xx]
				while j >= 0:
					if j != i and _tier[j] == 1 and p.distance_squared_to(_pos[j]) <= r2:
						count += 1
						if count >= PACK_MIN_ALLIES:
							break
					j = _next[j]
				if count >= PACK_MIN_ALLIES:
					break
			if count >= PACK_MIN_ALLIES:
				break
		e.pack_bonus = count >= PACK_MIN_ALLIES
		i += PACK_SLICES
