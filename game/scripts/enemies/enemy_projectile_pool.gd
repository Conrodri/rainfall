class_name EnemyProjectilePool
extends Node2D
## Projectiles ennemis poolés (préchauffés, aucune instanciation en jeu). Chaque projectile est
## une Area2D couche 5 (enemy_projectiles), monitorable mais sans monitoring : un bouclier du
## joueur peut les détecter, mais le coup au joueur est un test de distance centralisé
## (bien moins cher que N Area2D en monitoring). Mise à jour en un seul passage par frame.

const LAYER_ENEMY_PROJECTILES := 1 << 4
const RADIUS_PX := 9.0
const LIFETIME := 4.0
const COLOR := Color(1.0, 0.35, 0.55)

var _free: Array[Projectile] = []
var _active: Array[Projectile] = []
var _flip := false ## test des murs une frame sur deux par projectile (≤ 13 px d'avance, murs ≥ 128 px)


func prewarm(count: int) -> void:
	top_level = true
	for i in count:
		_free.append(_make())


func active_count() -> int:
	return _active.size()


func free_count() -> int:
	return _free.size()


func fire(source: Node2D, pos: Vector2, velocity: Vector2, damage: float) -> Projectile:
	var p: Projectile
	if _free.is_empty():
		push_warning("EnemyProjectilePool : pool épuisé, instanciation à chaud")
		p = _make()
	else:
		p = _free.pop_back()
	p.position = pos
	p.visible = true
	p.active = true
	p.velocity = velocity
	p.life = LIFETIME
	p.damage = damage
	p.source = source
	_active.append(p)
	p.sync_layer.call_deferred()
	return p


## Habillage d'un projectile tiré (sprite d'un boss : follet du cerf…) : `skin` remplace le disque
## placeholder jusqu'à la libération du projectile (le pool libère alors le nœud).
static func set_skin(p: Node2D, skin: Node2D) -> void:
	var pr := p as Projectile
	if pr == null or skin == null:
		return
	if is_instance_valid(pr.skin):
		pr.skin.queue_free()
	pr.skin = skin
	pr.add_child(skin)
	var v := pr.get_node_or_null(^"Visual") as CanvasItem
	if v != null:
		v.visible = false


func clear_all() -> void:
	for i in range(_active.size() - 1, -1, -1):
		_release_at(i)


## nav : champ de la carte (les projectiles s'arrêtent sur les obstacles), null sinon.
func update(delta: float, player: Node2D, player_pos: Vector2, nav: NavField = null) -> void:
	var hit_r := RADIUS_PX + PlayerHitbox.radius_px # rayon de dégâts du joueur (suit set_hitbox_u), lu une fois par passe
	var hit_r2 := hit_r * hit_r
	_flip = not _flip
	var fl := int(_flip)
	var decoys := not Decoy.live.is_empty() # hit_by rend null si la dernière doublure disparaît en cours de boucle
	var has_player := is_instance_valid(player)
	var i := _active.size() - 1
	while i >= 0:
		var p := _active[i]
		p.life -= delta
		var pos := p.position + p.velocity * delta
		p.position = pos
		if has_player and pos.distance_squared_to(player_pos) <= hit_r2:
			var src: Node2D = p.source if is_instance_valid(p.source) else null
			if player.has_method(&"note_hit_from"): # éclat de l'anneau de hitbox côté impact (coups seulement)
				player.note_hit_from(pos)
			if player.has_method(&"take_damage"):
				player.take_damage(p.damage, src)
			if src is Enemy:
				(src as Enemy).apply_affixes_to(player, p.damage)
			_release_at(i)
		elif decoys and Decoy.hit_by(pos, RADIUS_PX) != null: # S14 : la doublure encaisse
			Decoy.hit_by(pos, RADIUS_PX).take_damage(p.damage, p.source if is_instance_valid(p.source) else null)
			_release_at(i)
		elif p.life <= 0.0 or (nav and (i & 1) == fl and nav.is_blocked_at(pos)):
			_release_at(i)
		i -= 1


## API publique (boss, mini-boss, sorts) : détruit tout projectile ennemi dont le disque (RADIUS_PX) touche le
## cercle (center, radius) en px logiques (blocs de la Mère-Cristal, boucliers…). Retourne le nombre arrêté.
func kill_in_circle(center: Vector2, radius: float) -> int:
	var n := 0
	var r := radius + RADIUS_PX
	var r2 := r * r
	var i := _active.size() - 1
	while i >= 0: # parcours descendant : _release_at met le dernier à la place de i (déjà testé)
		if _active[i].position.distance_squared_to(center) <= r2:
			_release_at(i)
			n += 1
		i -= 1
	return n


## API publique : détruit tout projectile ennemi qui touche le segment a-b de largeur totale `width` (px
## logiques). Retourne le nombre arrêté. Plusieurs segments d'un coup : cull_segments.
func kill_in_segment(a: Vector2, b: Vector2, width: float) -> int:
	return cull_segments(PackedVector2Array([a, b]), width * 0.5)


## Détruit les projectiles ennemis qui touchent un des segments `segs` (paires de points a, b, en px
## logiques) à `half_w` près (une passe pour tous les segments) : fils de la Tisseuse (WeaverSnare, étage 2).
## Retourne le nombre de projectiles arrêtés.
func cull_segments(segs: PackedVector2Array, half_w: float) -> int:
	var n := 0
	var r2 := (half_w + RADIUS_PX) * (half_w + RADIUS_PX)
	var i := _active.size() - 1
	while i >= 0:
		var pos := _active[i].position
		var k := 0
		while k + 1 < segs.size():
			var a := segs[k]
			var ab := segs[k + 1] - a
			var t := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			if pos.distance_squared_to(a + ab * t) <= r2:
				_release_at(i)
				n += 1
				break
			k += 2
		i -= 1
	return n


## Boss façon raid (Design_Boss_Raid §1.2) : détruit les projectiles ennemis dont le disque touche un des cercles
## (centers[k], radii[k]) en px logiques, en une passe. `counts` (optionnel, même taille que centers) reçoit le
## nombre de projectiles arrêtés par chaque cercle (pylônes-abris abîmés). Retourne le total arrêté.
func cull_circles(centers: PackedVector2Array, radii: PackedFloat32Array, counts: PackedInt32Array = PackedInt32Array()) -> int:
	var n := 0
	var nc := mini(centers.size(), radii.size())
	if nc == 0:
		return 0
	var track := counts.size() >= nc
	var i := _active.size() - 1
	while i >= 0:
		var pos := _active[i].position
		for k in nc:
			var r := radii[k] + RADIUS_PX
			if pos.distance_squared_to(centers[k]) <= r * r:
				_release_at(i)
				n += 1
				if track:
					counts[k] += 1
				break
		i -= 1
	return n


## Ombres des pylônes-abris (Design_Boss_Raid §1.2) : pour chaque pylône p, couloir protégé de demi-largeur
## `half_w` et de longueur `length` derrière lui dans l'axe origin -> p (origine du barrage). Une passe, segments
## réutilisés (aucune allocation si `pylons` ne change pas de taille). Retourne le nombre de projectiles arrêtés.
var _shadow_segs := PackedVector2Array()
func cull_shadows(origin: Vector2, pylons: PackedVector2Array, half_w: float, length: float = 384.0) -> int:
	if pylons.is_empty():
		return 0
	if _shadow_segs.size() != pylons.size() * 2:
		_shadow_segs.resize(pylons.size() * 2)
	for k in pylons.size():
		var p := pylons[k]
		var d := p - origin
		var l := d.length()
		d = d / l if l > 0.001 else Vector2.RIGHT
		_shadow_segs[k * 2] = p
		_shadow_segs[k * 2 + 1] = p + d * length
	return cull_segments(_shadow_segs, half_w)


## Nombre de projectiles vivants tirés par `source` (plafond d'un barrage : RAID_BARRAGE_MAX_LIVE).
func count_from(source: Node) -> int:
	var n := 0
	for p in _active:
		if p.source == source:
			n += 1
	return n


func _release_at(i: int) -> void:
	var p := _active[i]
	_active[i] = _active[_active.size() - 1]
	_active.pop_back()
	p.visible = false
	p.active = false
	p.source = null
	if p.skin != null:
		if is_instance_valid(p.skin):
			p.skin.queue_free()
		p.skin = null
		(p.get_node(^"Visual") as CanvasItem).visible = true
	_free.append(p)
	p.sync_layer.call_deferred()


func _make() -> Projectile:
	var p := Projectile.new()
	p.monitoring = false
	p.monitorable = true
	p.collision_layer = 0
	p.collision_mask = 0
	p.visible = false
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS_PX
	cs.shape = shape
	p.add_child(cs)
	var vis := _ProjectileVisual.new() # nœud visuel remplaçable
	vis.name = &"Visual"
	p.add_child(vis)
	add_child(p)
	return p


class Projectile extends Area2D:
	var active := false
	var velocity := Vector2.ZERO
	var life := 0.0
	var damage := 0.0
	var source: Node2D = null
	var skin: Node2D = null ## habillage (set_skin), libéré avec le projectile

	func sync_layer() -> void:
		collision_layer = EnemyProjectilePool.LAYER_ENEMY_PROJECTILES if active else 0


class _ProjectileVisual extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, EnemyProjectilePool.RADIUS_PX, EnemyProjectilePool.COLOR)
		draw_circle(Vector2.ZERO, EnemyProjectilePool.RADIUS_PX * 0.5, Color.WHITE)
