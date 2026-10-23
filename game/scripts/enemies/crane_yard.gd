class_name CraneYard
extends Node2D
## Conteneurs lâchés par la Grue (boss d'étage 3) : obstacles de 2 u (StaticBody2D, couche 1 « world » :
## bloquent le joueur ; obstacle dynamique NavField `nav` : contournés par les monstres et le boss), qui
## coupent la flèche (blocks_line) et servent de conducteurs à l'arc de tempête
## (phase 3). Durée LIFE s ; la lampe au sodium clignote les BLINK_S dernières secondes.
## Survit à l'IA : à la mort de la Grue pendant la charge du gros pilier, les conteneurs restent (trace)
## jusqu'à la fin de la charge (keep_until_charge), puis s'effacent.

const U := 64.0
const HALF_U := 1.0 ## demi-côté (conteneur de 2 u)
const LIFE := 8.0
const BLINK_S := 1.5
const FADE_S := 0.4
const MAX := 9
const MAX_S := 120.0 ## garde-fou de la trace

var containers: Array[Dictionary] = [] ## {body, vis, light, life, pos, rot}
var _frames: SpriteFrames = null
var nav: NavField = null ## champ de la carte (posé par la Grue) : obstacles dynamiques
var _pillar: Node = null
var _keep := false
var _keep_t := 0.0


static func create(host: Node, frames: SpriteFrames) -> CraneYard:
	var y := CraneYard.new()
	y.name = &"CraneYard"
	y._frames = frames
	y.y_sort_enabled = true
	host.add_child(y)
	return y


func count() -> int:
	return containers.size()


## Pose un conteneur (impact) au point p ; rot : orientation du carré (rad, 0 = losange de la grille iso).
func drop(p: Vector2, rot: float = 0.0) -> Dictionary:
	while containers.size() >= MAX:
		_remove(0)
	var body := StaticBody2D.new()
	body.name = &"Crane_container"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2.ONE * HALF_U * 2.0 * U
	cs.shape = rs
	cs.rotation = PI * 0.25 + rot
	body.add_child(cs)
	body.position = p
	var vis: Node2D
	if _frames != null and _frames.has_animation(&"container"):
		var s := AnimatedSprite2D.new()
		EmissiveOverlay.apply(s, _frames, 1.6)
		s.animation = &"container"
		s.frame = randi() % maxi(_frames.get_frame_count(&"container"), 1)
		s.scale = Vector2.ONE * Iso.SPRITE_K * Iso.UNSQUASH
		s.offset = Vector2(0.0, -96.0) # cellule 256², pied à y 224 (brief)
		vis = s
	else:
		var f := CraneFx.make(CraneFx.Kind.CONTAINER, CraneFx.RUST.lerp(Color(0.55, 0.25, 0.18), randf() * 0.6))
		f.size = HALF_U * U
		f.rotation = 0.0
		vis = f
	vis.name = &"Crane_container_vis"
	body.add_child(vis)
	add_child(body)
	var light := LightRig.attach(body, &"ember", {"color": CraneFx.SODIUM, "energy": 0.7, "radius": 0.55,
		"offset": Vector2(0.0, Iso.lift_logical(1.5))})
	var c := {"body": body, "vis": vis, "light": light, "life": LIFE, "pos": p, "rot": PI * 0.25 + rot}
	containers.append(c)
	if nav != null:
		nav.add_box_obstacle(body.get_instance_id(), p, Vector2.ONE * HALF_U * U, PI * 0.25 + rot)
	return c


## Le segment a-b traverse-t-il un conteneur (carré tourné) ? Abri contre la flèche.
func blocks_line(a: Vector2, b: Vector2, margin := 0.0) -> bool:
	var h := HALF_U * U + margin
	for c in containers:
		var inv := Transform2D(float(c["rot"]), c["pos"] as Vector2).affine_inverse()
		if _seg_box(inv * a, inv * b, h):
			return true
	return false


## Point p dans un conteneur (marge en px) ?
func inside(p: Vector2, margin := 0.0) -> Dictionary:
	var h := HALF_U * U + margin
	for c in containers:
		var lp := Transform2D(float(c["rot"]), c["pos"] as Vector2).affine_inverse() * p
		if absf(lp.x) <= h and absf(lp.y) <= h:
			return c
	return {}


## Pousse p hors du conteneur c (bord le plus proche + marge).
func push_out(c: Dictionary, p: Vector2, margin: float) -> Vector2:
	var xf := Transform2D(float(c["rot"]), c["pos"] as Vector2)
	var lp := xf.affine_inverse() * p
	var h := HALF_U * U + margin
	if absf(lp.x) > absf(lp.y):
		lp.x = signf(lp.x if lp.x != 0.0 else 1.0) * h
	else:
		lp.y = signf(lp.y if lp.y != 0.0 else 1.0) * h
	return xf * lp


static func _seg_box(a: Vector2, b: Vector2, h: float) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for ax in 2:
		var p := a[ax]
		var v := d[ax]
		if absf(v) < 0.0001:
			if p < -h or p > h:
				return false
		else:
			var ta := (-h - p) / v
			var tb := (h - p) / v
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return false
	return true


## Mort de la Grue pendant la charge du gros pilier : les conteneurs restent jusqu'à la fin de la charge.
## Retourne false (et libère tout) s'il n'y a pas de charge en cours.
func keep_until_charge() -> bool:
	_pillar = null
	if is_inside_tree():
		for p in get_tree().get_nodes_in_group(&"pillars"):
			if p is Pillar and (p as Pillar).kind == Pillar.Kind.BIG and (p as Pillar).state == Pillar.STATE_ACTIVE and not (p as Pillar).is_charged():
				_pillar = p
				break
	if _pillar == null or containers.is_empty():
		release()
		return false
	_keep = true
	for c in containers:
		c["life"] = maxf(float(c["life"]), BLINK_S + 0.1)
	return true


func is_kept() -> bool:
	return _keep


func release() -> void:
	while not containers.is_empty():
		_remove(0)
	queue_free()


func _physics_process(delta: float) -> void:
	if _keep:
		_keep_t += delta
		var p := _pillar as Pillar
		if _keep_t > MAX_S or not is_instance_valid(p) or p.state != Pillar.STATE_ACTIVE:
			_keep = false
			for c in containers:
				c["life"] = minf(float(c["life"]), BLINK_S)
		else:
			return
	var i := containers.size() - 1
	while i >= 0:
		var c: Dictionary = containers[i]
		c["life"] = float(c["life"]) - delta
		var life := float(c["life"])
		var vis := c["vis"] as CanvasItem
		if life <= 0.0:
			_remove(i)
		else:
			var lamp := 1.0
			if life < BLINK_S:
				lamp = 1.0 if fmod(life, 0.3) > 0.15 else 0.1
			if vis is CraneFx and absf((vis as CraneFx).lamp - lamp) > 0.01:
				(vis as CraneFx).lamp = lamp
				vis.queue_redraw()
			var lh := c["light"] as LightRig.Handle
			if lh != null:
				lh.set_energy(lamp)
			if is_instance_valid(vis):
				vis.modulate.a = clampf(life / FADE_S, 0.0, 1.0)
		i -= 1
	if containers.is_empty() and not _keep and _pillar != null:
		queue_free()


func _remove(i: int) -> void:
	var c: Dictionary = containers[i]
	var lh := c["light"] as LightRig.Handle
	if lh != null:
		lh.release()
	var b := c["body"] as Node
	if is_instance_valid(b):
		if nav != null:
			nav.remove_obstacle(b.get_instance_id())
		b.queue_free()
	containers.remove_at(i)


func _exit_tree() -> void:
	for c in containers:
		if nav != null and is_instance_valid(c["body"]):
			nav.remove_obstacle((c["body"] as Node).get_instance_id())
		var lh := c["light"] as LightRig.Handle
		if lh != null:
			lh.release()
