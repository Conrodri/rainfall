class_name SmelterSlag
extends Node2D
## Métal en fusion du Fondeur (boss d'étage 3) : coulées (lignes 2 × 12 u, POOL_LIFE s) et anneaux de
## débordement (rayon 5 u, 2 brèches marquées par des lampes au sodium). Les dégâts au contact sont appliqués
## par SmelterBrain (in_metal) tant que le boss vit ; à sa mort pendant la charge du gros pilier, le métal
## reste (trace) et brûle seul jusqu'à la fin de la charge (keep_until_charge).

const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const MAX_POOLS := 10
const FADE_S := 0.6
const TICK := 0.5
const MAX_S := 120.0

var pools: Array[Dictionary] = [] ## {a, ang, len, w, life, max, node, light}
var rings: Array[Dictionary] = [] ## {c, r, band, gaps, gap_half, life, max, node, lights}
var quenched := 0 ## flaques éteintes par la trempe (tests)
var _frames: SpriteFrames = null
var _pillar: Node = null
var _keep := false
var _keep_t := 0.0
var _damage := 0.0
var _tick := 0.0


static func create(host: Node, frames: SpriteFrames) -> SmelterSlag:
	var s := SmelterSlag.new()
	s.name = &"SmelterSlag"
	s._frames = frames
	host.add_child(s)
	return s


func pool_count() -> int:
	return pools.size()


func ring_count() -> int:
	return rings.size()


func metal_count() -> int:
	return pools.size() + rings.size()


func add_pool(a: Vector2, ang: float, length: float, w: float, life: float) -> Dictionary:
	while pools.size() >= MAX_POOLS:
		_free_pool(pools.pop_front())
	var n: Node2D
	if _frames != null and _frames.has_animation(&"molten_pool"):
		var s := AnimatedSprite2D.new()
		EmissiveOverlay.apply(s, _frames, 2.2)
		s.animation = &"molten_pool"
		s.scale = Vector2(length / 768.0, w / 128.0)
		s.offset = Vector2(384.0, 0.0)
		s.play(&"molten_pool")
		n = s
	else:
		var f := SmelterFx.make(SmelterFx.Kind.POOL, SmelterFx.SODIUM, 0)
		f.size = length
		f.width = w
		n = f
	n.name = &"Smelter_pool"
	n.z_index = -2
	add_child(n)
	n.global_position = a
	n.rotation = ang
	var light := LightRig.attach(n, &"ember", {"color": SmelterFx.SODIUM, "energy": 0.9, "radius": 1.1,
		"offset": Vector2.from_angle(ang) * length * 0.5})
	var p := {"a": a, "ang": ang, "len": length, "w": w, "life": life, "max": life, "node": n, "light": light}
	pools.append(p)
	return p


func add_ring(c: Vector2, r: float, band: float, gap_angles: Array, gap_half: float, life: float) -> Dictionary:
	var f := SmelterFx.make(SmelterFx.Kind.RING, SmelterFx.SODIUM, 0)
	f.name = &"Smelter_ring"
	f.size = r
	f.width = band
	f.gaps = gap_angles
	f.gap_half = gap_half
	f.z_index = -2
	add_child(f)
	f.global_position = c
	var lights: Array = []
	for g in gap_angles: # lampes au sodium posées dans les brèches : on lit la sortie à la lumière
		lights.append(LightRig.attach_at(c + Vector2.from_angle(float(g)) * r, &"ember", {"color": SmelterFx.SODIUM, "energy": 1.4, "radius": 0.8}))
	var ring := {"c": c, "r": r, "band": band, "gaps": gap_angles, "gap_half": gap_half, "life": life, "max": life, "node": f, "lights": lights}
	rings.append(ring)
	return ring


## Le point p (joueur, rayon PLAYER_R) touche-t-il du métal en fusion ?
func in_metal(p: Vector2) -> bool:
	for q in pools:
		var v := p - (q["a"] as Vector2)
		var d := Vector2.from_angle(float(q["ang"]))
		var along := v.dot(d)
		if along >= -PLAYER_R * 0.5 and along <= float(q["len"]) + PLAYER_R * 0.5 and absf(v.cross(d)) <= float(q["w"]) * 0.5 + PLAYER_R * 0.5:
			return true
	for r in rings:
		if in_ring(r, p):
			return true
	return false


static func in_ring(r: Dictionary, p: Vector2) -> bool:
	var v := p - (r["c"] as Vector2)
	if absf(v.length() - float(r["r"])) > float(r["band"]) * 0.5 + PLAYER_R * 0.5:
		return false
	var slack := asin(clampf(PLAYER_R / maxf(float(r["r"]), 1.0), 0.0, 1.0)) # le corps entier doit passer
	for g in r["gaps"]:
		if absf(angle_difference(float(g), v.angle())) <= float(r["gap_half"]) - slack:
			return false
	return true


## Alerte de la trempe : tout le métal blanchit (k 0..1, clignotant).
func electrify(k: float) -> void:
	for q in pools:
		var n := q["node"] as Node2D
		if n is SmelterFx:
			(n as SmelterFx).heat = k
			n.queue_redraw()
		elif is_instance_valid(n):
			n.modulate = Color(1.0 + k, 1.0 + k, 1.0 + k, n.modulate.a)
	for r in rings:
		var f := r["node"] as SmelterFx
		if is_instance_valid(f):
			f.heat = k
			f.queue_redraw()


## Trempe : la pluie d'orage fige tout le métal d'un coup (bouffées de vapeur). Retourne les positions.
func quench(fx_host: Node, fx: Array) -> Array[Vector2]:
	var where: Array[Vector2] = []
	for q in pools:
		for k in 3:
			where.append((q["a"] as Vector2) + Vector2.from_angle(float(q["ang"])) * float(q["len"]) * (k + 0.5) / 3.0)
		_free_pool(q)
		quenched += 1
	pools.clear()
	for r in rings:
		for k in 6:
			where.append((r["c"] as Vector2) + Vector2.from_angle(TAU * k / 6.0) * float(r["r"]))
		_free_ring(r)
		quenched += 1
	rings.clear()
	for p in where:
		var n: Node2D
		var sf := EnemyVisual.boss_frames(&"sonneur")
		if sf != null and sf.has_animation(&"ground_steam"):
			var s := AnimatedSprite2D.new()
			EmissiveOverlay.apply(s, sf, 1.0)
			s.animation = &"ground_steam"
			s.scale = Vector2(2.4, 2.0) * (64.0 / 48.301887) * Iso.UNSQUASH
			s.offset = Vector2(0.0, -32.0)
			s.play(&"ground_steam")
			n = s
		else:
			var f := SmelterFx.make(SmelterFx.Kind.PUFF, Color(0.85, 0.85, 0.9), 1)
			f.size = 0.9 * U
			n = f
		n.name = &"Smelter_puff"
		fx_host.add_child(n)
		n.global_position = p
		fx.append({"node": n, "life": 1.1, "max": 1.1})
	return where


## Mort du Fondeur pendant la charge du gros pilier : le métal reste et brûle (dégâts `damage` par TICK s)
## jusqu'à la fin de la charge. Sans charge (ou sans métal) : tout est libéré.
func keep_until_charge(damage: float) -> bool:
	_pillar = null
	if is_inside_tree():
		for p in get_tree().get_nodes_in_group(&"pillars"):
			if p is Pillar and (p as Pillar).kind == Pillar.Kind.BIG and (p as Pillar).state == Pillar.STATE_ACTIVE and not (p as Pillar).is_charged():
				_pillar = p
				break
	if _pillar == null or metal_count() == 0:
		release()
		return false
	_keep = true
	_damage = damage
	return true


func is_kept() -> bool:
	return _keep


func release() -> void:
	for q in pools:
		_free_pool(q)
	pools.clear()
	for r in rings:
		_free_ring(r)
	rings.clear()
	queue_free()


func _physics_process(delta: float) -> void:
	if _keep:
		_keep_t += delta
		var pl := _pillar as Pillar
		if _keep_t > MAX_S or not is_instance_valid(pl) or pl.state != Pillar.STATE_ACTIVE:
			release()
			return
		_tick -= delta
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		if _tick <= 0.0 and player != null and in_metal(player.global_position) and player.has_method(&"take_damage"):
			_tick = TICK
			player.take_damage(_damage, self)
			if player.has_method(&"apply_status"):
				player.apply_status(&"burn", {"hit": _damage, "source": self})
		return # trace : le métal ne refroidit pas tant que la charge dure
	var i := pools.size() - 1
	while i >= 0:
		var q: Dictionary = pools[i]
		q["life"] = float(q["life"]) - delta
		var n := q["node"] as Node2D
		if float(q["life"]) <= 0.0:
			_free_pool(q)
			pools.remove_at(i)
		elif is_instance_valid(n):
			n.modulate.a = clampf(float(q["life"]) / FADE_S, 0.0, 1.0)
			if n is SmelterFx:
				var cool := 1.0 - float(q["life"]) / float(q["max"])
				if absf(cool - (n as SmelterFx).progress) > 0.05:
					(n as SmelterFx).progress = cool
					n.queue_redraw()
		i -= 1
	i = rings.size() - 1
	while i >= 0:
		var r: Dictionary = rings[i]
		r["life"] = float(r["life"]) - delta
		if float(r["life"]) <= 0.0:
			_free_ring(r)
			rings.remove_at(i)
		elif is_instance_valid(r["node"]):
			(r["node"] as CanvasItem).modulate.a = clampf(float(r["life"]) / FADE_S, 0.0, 1.0)
		i -= 1


func _free_pool(q: Dictionary) -> void:
	var lh := q["light"] as LightRig.Handle
	if lh != null:
		lh.release()
	if is_instance_valid(q["node"]):
		(q["node"] as Node).queue_free()


func _free_ring(r: Dictionary) -> void:
	for lh in r["lights"]:
		if lh != null:
			(lh as LightRig.Handle).release()
	if is_instance_valid(r["node"]):
		(r["node"] as Node).queue_free()


func _exit_tree() -> void:
	for q in pools:
		var lh := q["light"] as LightRig.Handle
		if lh != null:
			lh.release()
	for r in rings:
		for lh in r["lights"]:
			if lh != null:
				(lh as LightRig.Handle).release()
