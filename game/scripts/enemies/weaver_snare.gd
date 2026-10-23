class_name WeaverSnare
extends Node2D
## Pièges posés au sol par les boss alternatifs de la Forêt-brume (docs/Design_Etages.md §5.2), partagé par
## la Tisseuse (`weaver` : fils, toile, cocons) et le Cèdre-Ermite (`hermit_cedar` : souches).
## - Fils (segments) et toile (anneau à brèches) : le joueur qui les touche est ralenti de 40 % (design,
##   Player.apply_slow, traîne SLOW_LINGER_S) ; ils arrêtent les projectiles des monstres
##   (EnemyProjectilePool.cull_segments) ; un contact avec la TOILE est noté (`web_touches`) : la Tisseuse
##   sent la vibration et tombe dessus.
## - Obstacles (cocons, souches) : StaticBody2D couche 1 (monde) qui bloquent le joueur + obstacle dynamique
##   NavField (contournés par les monstres) ; un cocon éclot en monstre de tier 1 (Director.spawn_enemy).
## Créé par le cerveau du boss (sous le parent du boss, coordonnées logiques) ; à la mort du boss, la trace
## reste tant que la charge du gros pilier continue (comme RecluseGloom), puis tout se dissipe.

const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const SLOW_MULT := 0.6 ## fils et toile : -40 % (Design_Etages §5.2)
const SLOW_LINGER_S := 0.5 ## le ralentissement dure encore 0,5 s après le contact
const TOUCH_CD := 1.0 ## la toile signale au plus une vibration par seconde
const MAX_S := 180.0
const FADE_S := 0.6

var boss_alive := true
var web_touches: Array[Vector2] = [] ## vibrations de la toile pas encore lues par la Tisseuse
var slowed := 0 ## ralentissements infligés (tests)
var blocked := 0 ## projectiles arrêtés (tests)
var hatched := 0 ## cocons éclos (tests)
var frames: SpriteFrames = null ## .tres du boss (extras), null = formes provisoires
var prefix := "Weaver" ## préfixe des nœuds (tests : rien ne doit rester)

var _threads: Array[Dictionary] = [] ## {a, b, w, life, max, node}
var _web: Dictionary = {} ## {center, r, w, gaps, gap_half, node, segs}
var _obstacles: Array[Dictionary] = [] ## {pos, r, life, max, body, node, hatch, kind}
var _touch_cd := 0.0
var _nav: NavField = null ## champ de la carte du boss (obstacles dynamiques)
var _pillar: Node = null
var _life := 0.0
var _dir_cache: Node = null


static func create(e: Enemy, p_prefix: String) -> WeaverSnare:
	var host := e.get_parent()
	if host == null:
		return null
	var s := WeaverSnare.new()
	s.name = StringName(p_prefix + "Snare")
	s.prefix = p_prefix
	s._dir_cache = e.director
	s._nav = e.nav
	host.add_child(s)
	return s


## Libéré (trace finie, changement d'étage) : les obstacles quittent le champ des monstres.
func _exit_tree() -> void:
	if _nav != null:
		for o in _obstacles:
			if is_instance_valid(o["body"]):
				_nav.remove_obstacle((o["body"] as Node).get_instance_id())


# --- Fils et toile -------------------------------------------------------------------

## Fil de `a` à `b`, largeur `w_u` (u), durée `life` s (<= 0 : jusqu'au retrait). Retourne son index.
func add_thread(a: Vector2, b: Vector2, w_u: float, life: float) -> void:
	var node: Node2D
	var len := a.distance_to(b)
	if frames != null and _first_anim(["thread", "silk", "silk_thread"]) != &"":
		var an := _first_anim(["thread", "silk", "silk_thread"])
		var s := _sprite(an)
		s.centered = false
		var tex := frames.get_frame_texture(an, 0)
		var tw := float(tex.get_width()) if tex != null else 768.0
		var th := float(tex.get_height()) if tex != null else 64.0
		s.offset = Vector2(0.0, -th * 0.5)
		s.scale = Vector2(len / tw, w_u * U / th)
		s.play(an)
		node = s
	else:
		var f := WeaverFx.make(WeaverFx.Kind.THREAD, Color(WeaverFx.MIST.r, WeaverFx.MIST.g, WeaverFx.MIST.b, 0.95), -1)
		f.radius = len
		f.width = w_u * U * 0.5
		node = f
	node.name = StringName(prefix + "_thread")
	add_child(node)
	node.position = a
	node.rotation = (b - a).angle()
	_threads.append({"a": a, "b": b, "w": w_u * U, "life": life, "max": life, "node": node, "glow": 0.0})


func thread_count() -> int:
	return _threads.size()


## Toile : anneau de rayon `r_u` (u) autour de `center`, brèches aux angles `gap_angles` (demi-ouverture
## `gap_half` rad). Une seule toile ; la reposer la remplace.
func set_web(center: Vector2, r_u: float, gap_angles: PackedFloat32Array, gap_half: float) -> void:
	clear_web()
	var f: Node2D
	if frames != null and frames.has_animation(&"web") and gap_angles.size() == 2:
		# extra « web » (lot N2c) : anneau vu de dessus qui remplit sa cellule, brèches à +x et -x de la cellule
		var s := _sprite(&"web")
		var tex := frames.get_frame_texture(&"web", 0)
		s.scale = Vector2.ONE * (2.0 * r_u * U / (float(tex.get_width()) if tex != null else 768.0))
		s.rotation = gap_angles[0]
		s.play(&"web")
		f = s
		gap_angles = PackedFloat32Array([gap_angles[0], gap_angles[0] + PI])
	else:
		var wf := WeaverFx.make(WeaverFx.Kind.WEB, Color(WeaverFx.MIST.r, WeaverFx.MIST.g, WeaverFx.MIST.b, 0.9), -1)
		wf.radius = r_u * U
		wf.width = 0.22 * U
		wf.gaps = gap_angles
		wf.gap_half = gap_half
		f = wf
	f.name = StringName(prefix + "_web")
	add_child(f)
	f.position = center
	# segments de la toile (cordes de 10°, sans les brèches) : contacts et projectiles
	var segs := PackedVector2Array()
	var n := 36
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var mid := (a0 + a1) * 0.5
		var gap := false
		for g in gap_angles:
			if absf(angle_difference(mid, g)) < gap_half:
				gap = true
		if not gap:
			segs.append(center + Vector2.from_angle(a0) * r_u * U)
			segs.append(center + Vector2.from_angle(a1) * r_u * U)
	_web = {"center": center, "r": r_u * U, "w": 0.35 * U, "gaps": gap_angles, "gap_half": gap_half, "node": f, "segs": segs, "glow": 0.0}


func has_web() -> bool:
	return not _web.is_empty()


func web() -> Dictionary:
	return _web


func clear_web() -> void:
	if not _web.is_empty() and is_instance_valid(_web.get("node")):
		(_web["node"] as Node).queue_free()
	_web = {}


## La toile vibre (contact du joueur ou chute de la Tisseuse) : flash menthe le long des brins.
func pulse_web(k := 1.0) -> void:
	if not _web.is_empty():
		_web["glow"] = maxf(float(_web["glow"]), k)


# --- Obstacles -----------------------------------------------------------------------

## Obstacle rond (cocon, souche) qui bloque le joueur. `hatch_s` > 0 : éclot en tier 1 après ce délai.
func add_obstacle(pos: Vector2, r_u: float, life: float, kind: StringName, hatch_s := -1.0) -> void:
	var body := StaticBody2D.new()
	body.name = StringName(prefix + "_block")
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = r_u * U
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.position = pos
	var node: Node2D
	var cands: Array = ["cocoon"] if kind == &"cocoon" else ["stump", "root_stump"]
	var an := _first_anim(cands)
	if frames != null and an != &"":
		var s := _sprite(an)
		s.scale = Iso.UNSQUASH * Iso.SPRITE_K # billboard : pied au bas de la cellule
		var tex := frames.get_frame_texture(an, 0)
		s.offset = Vector2(0.0, -(float(tex.get_height()) if tex != null else 128.0) * 0.5)
		if kind == &"cocoon":
			s.play(an)
		else: # souche : variante fixe tirée au hasard
			s.frame = randi() % maxi(frames.get_frame_count(an), 1)
		node = s
	else:
		var col := Color(0.70, 0.74, 0.70) if kind == &"cocoon" else Color(0.47, 0.42, 0.36)
		var f := WeaverFx.make(WeaverFx.Kind.COCOON if kind == &"cocoon" else WeaverFx.Kind.STUMP, col, 0)
		f.radius = r_u * U
		node = f
	node.name = StringName(prefix + "_" + String(kind))
	add_child(node)
	node.position = pos
	_obstacles.append({"pos": pos, "r": r_u * U, "life": life, "max": life, "body": body, "node": node, "hatch": hatch_s, "kind": kind})
	if _nav != null:
		_nav.add_circle_obstacle(body.get_instance_id(), pos, r_u * U)


func obstacle_count(kind: StringName = &"") -> int:
	var n := 0
	for o in _obstacles:
		if kind == &"" or o["kind"] == kind:
			n += 1
	return n


func obstacle_positions(kind: StringName = &"") -> Array[Vector2]:
	var out: Array[Vector2] = []
	for o in _obstacles:
		if kind == &"" or o["kind"] == kind:
			out.append(o["pos"])
	return out


## Le point est-il dans un obstacle (le boss ne s'y arrête pas) ?
func blocked_at(p: Vector2, r: float) -> bool:
	for o in _obstacles:
		if p.distance_to(o["pos"]) < float(o["r"]) + r:
			return true
	return false


# --- Vie -------------------------------------------------------------------------------

## Mort du boss : la trace reste si un gros pilier actif charge encore ; sinon tout se dissipe.
func on_boss_dead() -> void:
	boss_alive = false
	_pillar = null
	for o in _obstacles: # les cocons d'un boss mort n'éclosent plus : ils restent comme obstacles
		o["hatch"] = -1.0
	if is_inside_tree():
		for p in get_tree().get_nodes_in_group(&"pillars"):
			if p is Pillar and (p as Pillar).kind == Pillar.Kind.BIG and (p as Pillar).state == Pillar.STATE_ACTIVE and not (p as Pillar).is_charged():
				_pillar = p
				break
	if _pillar == null:
		release()


func release() -> void:
	queue_free()


func _physics_process(delta: float) -> void:
	_life += delta
	if not boss_alive:
		var p := _pillar as Pillar
		if _life > MAX_S or not is_instance_valid(p) or p.state != Pillar.STATE_ACTIVE:
			release()
			return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var ppos := player.global_position if player != null else Vector2.INF
	_touch_cd -= delta
	var segs := PackedVector2Array()
	# fils
	var i := _threads.size() - 1
	while i >= 0:
		var t: Dictionary = _threads[i]
		if float(t["max"]) > 0.0 and boss_alive:
			t["life"] = float(t["life"]) - delta
		var n := t["node"] as CanvasItem
		if float(t["max"]) > 0.0 and float(t["life"]) <= 0.0:
			if is_instance_valid(n):
				n.queue_free()
			_threads.remove_at(i)
			i -= 1
			continue
		t["glow"] = maxf(0.0, float(t["glow"]) - delta * 2.0)
		if is_instance_valid(n):
			var a := 1.0 if float(t["max"]) <= 0.0 or not boss_alive else clampf(float(t["life"]) / FADE_S, 0.0, 1.0)
			n.modulate = Color(1.0 + 0.6 * float(t["glow"]), 1.0 + 0.8 * float(t["glow"]), 1.0 + 0.7 * float(t["glow"]), a)
		segs.append(t["a"])
		segs.append(t["b"])
		if player != null and _seg_dist(ppos, t["a"], t["b"]) <= float(t["w"]) * 0.5 + PLAYER_R:
			t["glow"] = 1.0
			_slow(player)
		i -= 1
	# toile
	if not _web.is_empty():
		_web["glow"] = maxf(0.0, float(_web["glow"]) - delta * 1.6)
		var wn: Variant = _web["node"]
		if is_instance_valid(wn) and wn is WeaverFx:
			(wn as WeaverFx).set_glow(1.0 + float(_web["glow"]))
		elif is_instance_valid(wn):
			var g := float(_web["glow"])
			(wn as CanvasItem).modulate = Color(1.0 + 0.6 * g, 1.0 + 0.8 * g, 1.0 + 0.7 * g)
		var ws: PackedVector2Array = _web["segs"]
		segs.append_array(ws)
		if player != null and absf(ppos.distance_to(_web["center"]) - float(_web["r"])) <= float(_web["w"]) * 0.5 + PLAYER_R:
			var k := 0
			while k + 1 < ws.size():
				if _seg_dist(ppos, ws[k], ws[k + 1]) <= float(_web["w"]) * 0.5 + PLAYER_R:
					_slow(player)
					if _touch_cd <= 0.0 and boss_alive:
						_touch_cd = TOUCH_CD
						web_touches.append(ppos)
						_web["glow"] = 1.0
					break
				k += 2
	if not segs.is_empty():
		var pool := _projectile_pool()
		if pool != null:
			blocked += pool.cull_segments(segs, 0.25 * U)
	# obstacles
	i = _obstacles.size() - 1
	while i >= 0:
		var o: Dictionary = _obstacles[i]
		if float(o["hatch"]) > 0.0:
			o["hatch"] = float(o["hatch"]) - delta
			var nd := o["node"] as Node2D
			if nd is WeaverFx:
				(nd as WeaverFx).set_progress(clampf(1.0 - float(o["hatch"]) / 3.0, 0.0, 1.0))
			if float(o["hatch"]) <= 0.0:
				_hatch(o)
				_free_obstacle(o)
				_obstacles.remove_at(i)
				i -= 1
				continue
		if boss_alive:
			o["life"] = float(o["life"]) - delta
		if float(o["life"]) <= 0.0:
			_free_obstacle(o)
			_obstacles.remove_at(i)
		elif float(o["life"]) < FADE_S and is_instance_valid(o["node"]):
			(o["node"] as CanvasItem).modulate.a = float(o["life"]) / FADE_S
		i -= 1


func _slow(player: Node2D) -> void:
	if not player.has_method(&"apply_slow"):
		return
	var was: bool = player.call(&"is_slowed") if player.has_method(&"is_slowed") else false
	player.apply_slow(SLOW_MULT, SLOW_LINGER_S, self)
	if not was and player.has_method(&"is_slowed") and player.call(&"is_slowed"):
		slowed += 1


func _hatch(o: Dictionary) -> void:
	hatched += 1
	var d := _dir_cache if is_instance_valid(_dir_cache) else get_tree().get_first_node_in_group(&"director")
	if d != null and d.has_method(&"spawn_enemy"):
		d.call(&"spawn_enemy", 1, o["pos"])
	Audio.play(&"enemy.shockwave.heavy", o["pos"], -8.0)
	LightRig.flash(to_global(o["pos"] as Vector2), &"boss_cerf", 0.25, {"energy": 0.6, "radius": 0.5})


func _free_obstacle(o: Dictionary) -> void:
	if _nav != null and is_instance_valid(o["body"]):
		_nav.remove_obstacle((o["body"] as Node).get_instance_id())
	if is_instance_valid(o["body"]):
		(o["body"] as Node).queue_free()
	if is_instance_valid(o["node"]):
		(o["node"] as Node).queue_free()


func _projectile_pool() -> EnemyProjectilePool:
	var d := _dir_cache if is_instance_valid(_dir_cache) else get_tree().get_first_node_in_group(&"director")
	return d.get_node_or_null(^"EnemyProjectiles") as EnemyProjectilePool if d != null else null


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _first_anim(cands: Array) -> StringName:
	if frames == null:
		return &""
	for c in cands:
		if frames.has_animation(StringName(c)):
			return StringName(c)
	return &""


func _sprite(anim: StringName) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	EmissiveOverlay.apply(s, frames, 2.0)
	s.animation = anim
	return s
