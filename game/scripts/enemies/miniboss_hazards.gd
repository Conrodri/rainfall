class_name MiniHazards
extends Node2D
## Objets de terrain et projectiles spéciaux des mini-boss pilotés par données (MiniBossBrain), créé à la
## demande sous le parent du boss (monde trié en y, coordonnées logiques), libéré par MiniBossBrain.clear().
## - Obstacles réels (blocs de glace de l'Ours, rochers du Colosse, tas d'os du Porte-ossuaire) : StaticBody2D
##   couche 1 (bloque le joueur), NavField.add_circle_obstacle (les monstres contournent, resolve les en sort,
##   la charge s'y écrase), EnemyProjectilePool.kill_in_circle chaque image (bloque les tirs) ; couverture
##   contre les rayons et cônes marqués `cover` (blocks_segment). Durée de vie, fondu de sortie.
## - Projectiles spéciaux (`bounces` : disques du Rémouleur qui rebondissent sur les murs N fois ; `status` :
##   brûlure, poison, gel, ralenti transmis au joueur) : test de distance comme EnemyProjectilePool, rebond en
##   repère CARTE (murs alignés sur la grille de NavField, tournée de 45° en iso), arrêtés par les obstacles et
##   par les doublures (Decoy).
## Formes provisoires : MiniFx (sinon anim du .tres du mini si livrée : « ice_block », « rock », « bone_pile »,
## « disc »).

const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 24 px des projectiles).
static var PLAYER_HIT_R: float:
	get: return PlayerHitbox.radius_px
const FADE_S := 0.5
const SHOT_LIFE := 4.0
const ANIMS := {&"ice": ["ice_block", "block"], &"rock": ["rock", "boulder"], &"bones": ["bone_pile", "bones"], &"saw": ["disc", "saw"]}

var brain: MiniBossBrain = null
var frames: SpriteFrames = null ## .tres du mini (extras), null = formes provisoires
var obstacles: Array[Dictionary] = [] ## {id, pos, r, life, max, body, node, style}
var shots: Array[Dictionary] = [] ## {pos, vel, r, dmg, status, bounces, life, node}
var bounced := 0 ## rebonds sur les murs (tests)
var shots_hit := 0 ## projectiles reçus par le joueur (tests)
var shots_blocked := 0 ## projectiles arrêtés par un obstacle (tests)
var proj_blocked := 0 ## projectiles du pool arrêtés par un obstacle (tests)
var _seq := 0


static func create(b: MiniBossBrain) -> MiniHazards:
	var host := b.e.get_parent()
	if host == null:
		return null
	var h := MiniHazards.new()
	h.name = &"MiniHazards"
	h.brain = b
	h.frames = EnemyVisual.boss_frames(b.mini_id) if EnemyVisual.boss_available(b.mini_id) else null
	host.add_child(h)
	return h


# --- Obstacles ---------------------------------------------------------------------------

## Obstacle rond de rayon `r_u` (u) pendant `life` s. Retourne sa position (recalée hors des murs).
func add_obstacle(pos: Vector2, r_u: float, life: float, style: StringName) -> Vector2:
	var r := r_u * U
	var nav := _nav()
	if nav != null:
		pos = nav.resolve(pos, r)
	# jamais sur le joueur : un corps statique qui le chevauche le dégagerait au hasard (au travers d'un mur fin)
	var pl: Node2D = brain.player if brain != null and is_instance_valid(brain.player) else null
	if pl != null:
		var away := pos - pl.global_position
		var clear_r := r + MiniBossBrain.PLAYER_R + 4.0
		if away.length() < clear_r:
			pos = pl.global_position + (away.normalized() if away.length_squared() > 1.0 else Vector2.RIGHT) * clear_r
			if nav != null:
				pos = nav.resolve(pos, r)
	_seq += 1
	var id := StringName("mini_ob_%d_%d" % [get_instance_id(), _seq])
	var body := StaticBody2D.new()
	body.name = &"MiniBlock"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = r
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.position = pos
	var node := _visual(style, r)
	add_child(node)
	node.position = pos
	if nav != null and nav.has_method(&"add_circle_obstacle"):
		nav.add_circle_obstacle(id, pos, r)
	obstacles.append({"id": id, "pos": pos, "r": r, "life": life, "max": life, "body": body, "node": node, "style": style})
	return pos


func obstacle_count(style: StringName = &"") -> int:
	var n := 0
	for o in obstacles:
		if style == &"" or o["style"] == style:
			n += 1
	return n


## Le disque (p, r) touche-t-il un obstacle ?
func blocked_at(p: Vector2, r: float) -> bool:
	for o in obstacles:
		if p.distance_to(o["pos"]) < float(o["r"]) + r:
			return true
	return false


## Distance de `p` à l'obstacle le plus proche (style donné ou tous), INF sans obstacle.
func nearest_obstacle(p: Vector2, style: StringName = &"") -> float:
	var best := INF
	for o in obstacles:
		if style == &"" or o["style"] == style:
			best = minf(best, p.distance_to(o["pos"]) - float(o["r"]))
	return best


## Un obstacle coupe-t-il le segment a-b (couverture contre rayons et cônes) ? Les extrémités ne comptent pas
## (le joueur collé au bloc est couvert seulement s'il est derrière).
func blocks_segment(a: Vector2, b: Vector2) -> bool:
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 0.001)
	for o in obstacles:
		var c: Vector2 = o["pos"]
		var t := clampf((c - a).dot(ab) / l2, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		if c.distance_to(a + ab * t) <= float(o["r"]) * 0.9:
			return true
	return false


func _free_obstacle(o: Dictionary) -> void:
	for k in ["body", "node"]:
		if is_instance_valid(o.get(k)):
			(o[k] as Node).queue_free()
	var nav := _nav()
	if nav != null and nav.has_method(&"remove_obstacle"):
		nav.remove_obstacle(o["id"])


# --- Projectiles spéciaux ------------------------------------------------------------------

## Projectile du mini : rebondit `bounces` fois sur les murs, transmet `status` au joueur touché.
func fire(pos: Vector2, vel: Vector2, dmg: float, status: String, bounces: int, r_u: float, color: Color) -> void:
	var node: Node2D
	var an := _anim(&"saw") if bounces > 0 else &""
	var r := maxf(r_u * U, 8.0)
	if an != &"":
		var s := _sprite(an)
		s.play(an)
		node = s
	else:
		var f := MiniFx.make(MiniFx.Kind.SAW if bounces > 0 else MiniFx.Kind.ORB, color, 1)
		f.radius = r
		node = f
	node.name = &"MiniShot"
	add_child(node)
	node.position = pos
	shots.append({"pos": pos, "vel": vel, "r": r, "dmg": dmg, "status": status, "bounces": bounces, "life": SHOT_LIFE, "node": node})


func shot_count() -> int:
	return shots.size()


func _update_shots(delta: float, player: Node2D) -> void:
	var nav := _nav()
	var ppos := player.global_position if player != null else Vector2.INF
	var i := shots.size() - 1
	while i >= 0:
		var s: Dictionary = shots[i]
		s["life"] = float(s["life"]) - delta
		var pos: Vector2 = s["pos"]
		var vel: Vector2 = s["vel"]
		var np := pos + vel * delta
		var kill := float(s["life"]) <= 0.0
		if not kill and nav != null and nav.is_blocked_at(np):
			if int(s["bounces"]) > 0:
				# rebond en repère carte : on inverse l'axe dont le pas seul entre dans le mur
				var pm := nav.to_map(pos)
				var vm := nav.to_map(pos + vel) - pm
				var bx := nav.is_blocked_at(nav.from_map(pm + Vector2(vm.x * delta, 0.0)))
				var by := nav.is_blocked_at(nav.from_map(pm + Vector2(0.0, vm.y * delta)))
				if bx or not by:
					vm.x = -vm.x
				if by or not bx:
					vm.y = -vm.y
				vel = nav.from_map(pm + vm) - nav.from_map(pm)
				s["vel"] = vel
				s["bounces"] = int(s["bounces"]) - 1
				s["life"] = maxf(float(s["life"]), 1.5)
				bounced += 1
				Audio.play(&"enemy.shot.medium", pos, -6.0)
				np = pos # reste devant le mur cette image
			else:
				kill = true
		if not kill and blocked_at(np, float(s["r"])):
			kill = true
			shots_blocked += 1
		s["pos"] = np
		if not kill and player != null:
			var hr := float(s["r"]) + PLAYER_HIT_R
			if np.distance_squared_to(ppos) <= hr * hr:
				kill = true
				shots_hit += 1
				if brain != null and is_instance_valid(brain.e):
					brain.shot_hit(player, float(s["dmg"]), String(s["status"]))
			elif not Decoy.live.is_empty():
				var dc := Decoy.hit_by(np, float(s["r"]))
				if dc != null:
					kill = true
					dc.take_damage(float(s["dmg"]), brain.e if brain != null and is_instance_valid(brain.e) else null)
		var n := s["node"] as Node2D
		if kill:
			if is_instance_valid(n):
				n.queue_free()
			shots.remove_at(i)
		elif is_instance_valid(n):
			n.position = np
		i -= 1


# --- Vie -----------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	_update_shots(delta, player)
	var pool := _pool()
	var i := obstacles.size() - 1
	while i >= 0:
		var o: Dictionary = obstacles[i]
		o["life"] = float(o["life"]) - delta
		if pool != null:
			proj_blocked += pool.kill_in_circle(o["pos"], float(o["r"])) if pool.has_method(&"kill_in_circle") \
				else pool.cull_segments(PackedVector2Array([o["pos"], o["pos"]]), float(o["r"]))
		if float(o["life"]) <= 0.0:
			_free_obstacle(o)
			obstacles.remove_at(i)
		elif float(o["life"]) < FADE_S and is_instance_valid(o["node"]):
			(o["node"] as CanvasItem).modulate.a = float(o["life"]) / FADE_S
		i -= 1


## Tout libérer (mort du mini, retour au pool) : obstacles retirés du NavField, projectiles détruits.
func release() -> void:
	for o in obstacles:
		_free_obstacle(o)
	obstacles.clear()
	shots.clear()
	brain = null
	queue_free()


func _nav() -> NavField:
	return brain.e.nav if brain != null and is_instance_valid(brain.e) else null


func _pool() -> EnemyProjectilePool:
	var d: Node = brain.e.director if brain != null and is_instance_valid(brain.e) else null
	return d.get_node_or_null(^"EnemyProjectiles") as EnemyProjectilePool if d != null else null


# --- Visuels -------------------------------------------------------------------------------------

func _anim(style: StringName) -> StringName:
	if frames == null:
		return &""
	for c in ANIMS.get(style, []):
		if frames.has_animation(StringName(c)):
			return StringName(c)
	return &""


func _sprite(anim: StringName) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	EmissiveOverlay.apply(s, frames, 2.0)
	s.animation = anim
	return s


func _visual(style: StringName, r: float) -> Node2D:
	var an := _anim(style)
	if an != &"":
		var s := _sprite(an)
		s.scale = Iso.UNSQUASH * Iso.SPRITE_K
		var tex := frames.get_frame_texture(an, 0)
		s.offset = Vector2(0.0, -(float(tex.get_height()) if tex != null else 128.0) * 0.5)
		s.frame = randi() % maxi(frames.get_frame_count(an), 1)
		s.name = StringName("Mini_" + String(style))
		return s
	var f := MiniFx.make(MiniFx.Kind.BLOCK, Color.WHITE, 0)
	f.style = style
	f.radius = r
	f.name = StringName("Mini_" + String(style))
	return f
