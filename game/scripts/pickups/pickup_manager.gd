class_name PickupManager
extends Node2D
## Systeme de pickups : gemmes d'XP et pieces d'or deposees a la mort des ennemis (Events.enemy_killed).
## Ramassage AUTOMATIQUE (joueur, 22/10/2026) : or et XP sont credites au depot (portee infinie) ; les
## pieces / gemmes ne sont plus qu'un effet visuel qui vole vers le joueur. Les ressources de kit (pieces de
## l'Avare, membres de Tocsin...) n'entrent jamais ici : GroundPickup (ramassage manuel au contact).
## Les pickups sont des DONNEES (tableaux paralleles) dessinees en un seul _draw : pas de noeud par
## pickup, plusieurs centaines au sol sans cout. Un slot libre est recycle (pooling).
## Le noeud est dans le groupe "pickups". A instancier une fois dans la scene de jeu.
## Camera iso 2:1 : les pickups sont des billboards, dessines sous une matrice (1, 2) avec des
## positions (x, y/2) et un leger soulevement : toujours un seul _draw, aucun noeud par pickup.

const KIND_XP := 0
const KIND_GOLD := 1
const MAX_PICKUPS := 700
const GOLD_BAG_COUNT := 5 ## a partir de 5 pieces pour une mort -> un sac unique
const FLY_TIME := 0.6 ## durée du vol visuel jusqu'au joueur (s), quelle que soit la distance
const MAX_VISUAL_DIST := 900.0 ## un dépôt plus loin part du bord de ce rayon (vers le monstre) : vol court et visible
const COLLECT_DIST := 28.0
const LAUNCH_SPEED := 260.0 ## petit jaillissement au depot avant de filer vers le joueur (visuel)
const SCATTER := 36.0
const HOVER_PX := 10.0 ## hauteur du centre du pickup au-dessus du sol (px billboard)

var active_count := 0
var gold_carry := 0.0 ## fraction d'or de prime reportée (< 1), voir drop_bounty
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _val := PackedFloat32Array()
var _kind := PackedByteArray()
var _big := PackedByteArray() ## sac d'or / grosse gemme
var _magnet := PackedByteArray()
var _age := PackedFloat32Array() ## âge du vol visuel (s)
var _alive := PackedByteArray()
var _free: Array[int] = []
var _player: Node2D
var _coin_sound: CoinSound
var _rng := RandomNumberGenerator.new()
var _pulse := 0.0
var _tex_coin: Texture2D
var _tex_bag: Texture2D
var _tex_gem: Texture2D
var _tex_gem_big: Texture2D


func _ready() -> void:
	add_to_group("pickups")
	z_index = -1
	_rng.randomize()
	_coin_sound = CoinSound.new()
	add_child(_coin_sound)
	for i in MAX_PICKUPS:
		_pos.append(Vector2.ZERO)
		_vel.append(Vector2.ZERO)
		_val.append(0.0)
		_kind.append(0)
		_big.append(0)
		_magnet.append(0)
		_age.append(0.0)
		_alive.append(0)
	for i in range(MAX_PICKUPS - 1, -1, -1):
		_free.append(i)
	_tex_coin = _load_tex(["coin", "gold_coin", "piece"])
	_tex_bag = _load_tex(["gold_bag", "bag", "sac"])
	_tex_gem = _load_tex(["xp_gem", "gem", "gem_xp", "xp"])
	_tex_gem_big = _load_tex(["xp_gem_big", "gem_big"])
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.boss_killed.connect(_on_boss_killed)


func _on_enemy_killed(_enemy: Node2D, position: Vector2, tier: int, is_elite: bool) -> void:
	# Prime RoR2 ∝ coût director (élite ×6), sans réserve d'étage (Balance.monster_gold / monster_xp).
	var D: float = RunState.difficulty()
	var cost: float = Balance.monster_cost(tier, is_elite)
	var xp: float = Balance.monster_xp(D, cost)
	var gold: float = Balance.monster_gold(D, cost)
	if xp > 0.0:
		_credit_xp(position, xp, 1 if (tier >= 3 or is_elite) else 0)
	if gold > 0.0:
		drop_bounty(position, gold)


## Prime de boss (Alignement RoR2) : or Balance.boss_gold, XP Balance.boss_xp (la moitié de l'or).
func _on_boss_killed(boss: Node2D, is_floor_boss: bool) -> void:
	var D: float = RunState.difficulty()
	var kind: StringName = &"etage" if is_floor_boss else &"mini"
	drop_bounty(boss.global_position, Balance.boss_gold(kind, D))
	_credit_xp(boss.global_position, Balance.boss_xp(kind, D), 1)


## Ramassage automatique (joueur, 22/10/2026) : l'XP est créditée tout de suite (× xp_mult, portée infinie),
## la gemme n'est plus qu'un effet visuel qui vole vers le joueur.
func _credit_xp(at: Vector2, value: float, big: int) -> void:
	if value <= 0.0:
		return
	var amount := value * _mult(&"xp_mult")
	if amount <= 0.0:
		return
	RunState.add_xp(amount)
	Events.pickup_collected.emit(&"xp", amount)
	_add(at, KIND_XP, amount, 1 if (big == 1 or amount >= 6.0) else 0)


## Or d'une prime (monstre, boss, Rançon, capsule) : crédité TOUT DE SUITE (× gold_mult, portée infinie), en
## ors ENTIERS : la fraction est reportée sur la prime suivante (`gold_carry`, < 1). Une prime de 0,47 or
## (petit monstre à coeff 1) ne montre donc plus une pièce que le compteur entier du HUD n'affichait jamais
## (bug « pièce ramassée, compteur inchangé ») : chaque pièce visible = au moins +1 au compteur. Somme exacte
## conservée (sweep rend la fraction). Les pièces posées ne sont qu'un effet visuel vers le joueur.
func drop_bounty(at: Vector2, value: float) -> void:
	if value <= 0.0:
		return
	gold_carry += value * _mult(&"gold_mult")
	var whole := floorf(gold_carry + 0.0001)
	if whole < 1.0:
		return
	gold_carry = maxf(gold_carry - whole, 0.0)
	RunState.add_gold(whole)
	Events.pickup_collected.emit(&"gold", whole)
	if not Audio.auto_gold_event: # sinon Audio joue la pièce sur Events.pickup_collected (pas de doublon)
		Audio.play_coin()
	_spawn_gold(at, whole)


## Effet visuel : n pièces (ou un sac à partir de GOLD_BAG_COUNT) qui volent vers le joueur.
func _spawn_gold(at: Vector2, value: float) -> void:
	var n := clampi(int(round(value)), 1, 12)
	if n >= GOLD_BAG_COUNT:
		_add(at, KIND_GOLD, value, 1)
		return
	for i in n:
		_add(at + _scatter(), KIND_GOLD, value / n, 0)


func _scatter() -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * SCATTER


func _add(at: Vector2, kind: int, value: float, big: int) -> int:
	if _free.is_empty():
		return -1
	var i: int = _free.pop_back()
	if _player != null and is_instance_valid(_player):
		var pp := _player.global_position
		if at.distance_squared_to(pp) > MAX_VISUAL_DIST * MAX_VISUAL_DIST:
			at = pp + (at - pp).normalized() * MAX_VISUAL_DIST
	_pos[i] = at
	_age[i] = 0.0
	_vel[i] = Vector2.from_angle(_rng.randf() * TAU) * LAUNCH_SPEED # jaillit puis file vers le joueur
	_val[i] = value
	_kind[i] = kind
	_big[i] = big
	_magnet[i] = 1
	_alive[i] = 1
	active_count += 1
	return i


## Changement d'étage : efface les effets visuels et renvoie l'or/XP pas encore crédités {gold, xp} :
## seulement la fraction d'or reportée (`gold_carry`), tout le reste a été crédité au dépôt.
func sweep() -> Dictionary:
	var out := {"gold": gold_carry, "xp": 0.0}
	gold_carry = 0.0
	for i in _alive.size():
		if _alive[i] == 1:
			_release(i)
	queue_redraw()
	return out


## Depose de l'or / de l'XP (capsules, Rancon de l'Avare, tests) : credite tout de suite comme une prime.
func drop(at: Vector2, kind: int, value: float) -> void:
	if kind == KIND_GOLD:
		drop_bounty(at, value)
	else:
		_credit_xp(at, value, 1 if value >= 6.0 else 0)


func _process(delta: float) -> void:
	_pulse += delta
	if active_count == 0:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null:
		_update_pickups(delta)
	else: # pas de joueur : rien à rejoindre, l'or/XP est déjà crédité
		for i in MAX_PICKUPS:
			if _alive[i] == 1:
				_release(i)
	queue_redraw()


## Effets visuels seulement (or et XP deja credites) : chaque piece / gemme jaillit puis rejoint le joueur
## en FLY_TIME au plus (il bouge : la cible est relue a chaque image ; jamais d'orbite ni d'esquive).
func _update_pickups(delta: float) -> void:
	var pp := _player.global_position
	for i in MAX_PICKUPS:
		if _alive[i] == 0:
			continue
		_age[i] += delta
		var left := FLY_TIME - _age[i]
		if left <= delta or _pos[i].distance_squared_to(pp) < COLLECT_DIST * COLLECT_DIST:
			_release(i)
			continue
		_vel[i] *= maxf(0.0, 1.0 - 6.0 * delta) # le jaillissement s'amortit
		_pos[i] += _vel[i] * delta
		_pos[i] += (pp - _pos[i]) * (delta / left) # arrivée exacte au bout de FLY_TIME


func _release(i: int) -> void:
	_alive[i] = 0
	_free.append(i)
	active_count -= 1


## Multiplicateur du joueur : methode player.xp_mult() / gold_mult() (renvoie 1 + bonus) ; sinon x1.
func _mult(key: StringName) -> float:
	if (_player == null or not is_instance_valid(_player)) and is_inside_tree():
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null and is_instance_valid(_player) and _player.has_method(key):
		return maxf(float(_player.call(key)), 0.0)
	return 1.0


## Cherche une texture dans assets/sprites/pickups/ (ou sous-dossiers coin/gem). Null = repli en formes.
static func _load_tex(names: Array) -> Texture2D:
	for n in names:
		for path in ["res://assets/sprites/pickups/%s.png" % n, "res://assets/sprites/pickups/%s/%s.png" % [n, n]]:
			if ResourceLoader.exists(path):
				return load(path) as Texture2D
	return null


func _draw() -> void:
	var glint := 0.8 + 0.2 * sin(_pulse * 6.0)
	draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(0.0, Iso.UNSQUASH.y), Vector2.ZERO))
	for i in MAX_PICKUPS:
		if _alive[i] == 0:
			continue
		var p := Vector2(_pos[i].x, _pos[i].y / Iso.UNSQUASH.y - HOVER_PX)
		var big := _big[i] == 1
		var tex: Texture2D
		if _kind[i] == KIND_XP:
			tex = _tex_gem_big if (big and _tex_gem_big != null) else _tex_gem
		else:
			tex = _tex_bag if (big and _tex_bag != null) else _tex_coin
		if tex != null:
			var ts := tex.get_size()
			var k := (44.0 if big else 30.0) / maxf(ts.x, ts.y)
			draw_texture_rect(tex, Rect2(p - ts * k * 0.5, ts * k), false, Color(1, 1, 1, glint if _kind[i] == KIND_XP else 1.0))
			continue
		if _kind[i] == KIND_XP:
			var s := 11.0 if big else 7.0
			var col := Color(0.7, 0.5, 1.0) if big else Color(0.35, 0.9, 1.0)
			var pts := PackedVector2Array([p + Vector2(0, -s * 1.3), p + Vector2(s, 0), p + Vector2(0, s * 1.3), p + Vector2(-s, 0)])
			draw_colored_polygon(pts, col * glint)
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1, 1, 1, 0.7), 1.5)
		else:
			var rad := 15.0 if big else 8.0
			draw_circle(p, rad, Color(0.95, 0.72, 0.1))
			draw_arc(p, rad, 0.0, TAU, 16, Color(1.0, 0.92, 0.5), 2.0)
			if big:
				draw_circle(p + Vector2(0, -rad * 0.2), rad * 0.45, Color(1.0, 0.85, 0.3))
