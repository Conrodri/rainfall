class_name SaltSteles
extends Node2D
## Stèles de sel du Roi de sel (docs/Design_Boss_Raid.md §2.3). UN nœud par boss gère toutes ses stèles :
## - jaillissement télégraphé `rise_s` (1,0 s, cercle rouge de 0,9 u ; joueur dessous à la levée -> coup du boss
##   coef `coef`, 1,2), puis StaticBody2D couche 1 (bloque le joueur) de rayon 0,5 u + obstacle dynamique NavField ;
## - vie `life_s` (10 s), érodée sur les `ERODE_S` dernières secondes (anim `stele`, 2 états x 6 frames si le .tres
##   du boss la contient, sinon forme provisoire du kit) ;
## - abri : `shelters(p, origin)` vrai si la ligne origine -> p est coupée par une stèle debout ou si p est dans
##   l'ombre (couloir de 1 u x 6 u derrière la stèle) : la nef sèche de la Procession s'étend derrière chaque stèle ;
## - `make_permanent()` à la mort du boss : les stèles restent (trace) sans plus de minuterie.
## `step(delta)` est appelé par le cerveau ; une fois détaché (`detached`), le nœud se pilote seul.

signal landed(pos: Vector2)
signal expired(pos: Vector2)

const RADIUS_U := 0.5
const HIT_R_U := 0.9
const RISE_S := 1.0
const LIFE_S := 10.0
const ERODE_S := 3.0
const SHADOW_HALF_W_U := 0.5
const SHADOW_LEN_U := 6.0
const MAX_STELES := 14
const WALL_MARGIN_U := 1.0

var boss: Node2D = null
var nav: NavField = null
var steles: Array[Dictionary] = [] ## {pos, rise, rise_total, tele, body, vis, life, age, coef, eroded}
var detached := false
var permanent := false
var hits := 0 ## joueur touché à la levée (tests)
var landed_total := 0
var _frames: SpriteFrames = null


static func create(p_boss: Node2D) -> SaltSteles:
	var s := SaltSteles.new()
	s.name = &"SaltSteles"
	s.boss = p_boss
	s.nav = p_boss.get(&"nav") as NavField
	var bv := p_boss.get(&"visual") as EnemyVisual
	if bv != null and bv.body_sprite() != null and bv.body_sprite().sprite_frames.has_animation(&"stele"):
		s._frames = bv.body_sprite().sprite_frames
	RaidKit.world_of(p_boss).add_child(s)
	return s


## Fait jaillir une stèle en `at` (ramenée sur le sol accessible). Retourne sa position.
func plant(at: Vector2, rise_s := RISE_S, coef := 1.2, life_s := LIFE_S) -> Vector2:
	while steles.size() >= MAX_STELES:
		_remove(0, true)
	var p := RaidKit.place(boss, at)
	if nav != null:
		p = nav.resolve(p, WALL_MARGIN_U * RaidKit.U)
	var c := {"pos": p, "rise": maxf(rise_s, 0.0), "rise_total": maxf(rise_s, 0.01), "tele": null, "body": null, "vis": null,
		"life": life_s, "age": 0.0, "coef": coef, "eroded": false}
	if rise_s > 0.0:
		var t := EnemyTelegraph.new()
		add_child(t)
		t.show_circle(p, HIT_R_U * RaidKit.U)
		c["tele"] = t
	steles.append(c)
	if rise_s <= 0.0:
		_land(c, false)
	return p


func live_count() -> int:
	var n := 0
	for c in steles:
		if float(c["rise"]) <= 0.0:
			n += 1
	return n


func pending_count() -> int:
	return steles.size() - live_count()


func positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for c in steles:
		if float(c["rise"]) <= 0.0:
			out.append(c["pos"])
	return out


## Le point p est-il à l'abri de la marée venue de `origin` (ligne de vue coupée, ou ombre derrière une stèle) ?
func shelters(p: Vector2, origin: Vector2) -> bool:
	var r := RADIUS_U * RaidKit.U
	for c in steles:
		if float(c["rise"]) > 0.0:
			continue
		var q: Vector2 = c["pos"]
		var ab := p - origin
		var t := clampf((q - origin).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if q.distance_to(origin + ab * t) <= r:
			return true
		var d := q - origin
		if d.length_squared() > 0.001:
			d = d.normalized()
			var lp := p - q
			var along := lp.dot(d)
			if along >= 0.0 and along <= SHADOW_LEN_U * RaidKit.U and absf(lp.cross(d)) <= SHADOW_HALF_W_U * RaidKit.U:
				return true
	return false


func _physics_process(delta: float) -> void:
	if detached:
		step(delta)


func step(delta: float) -> void:
	var i := steles.size() - 1
	while i >= 0:
		var c: Dictionary = steles[i]
		if float(c["rise"]) > 0.0:
			c["rise"] = float(c["rise"]) - delta
			var t := c["tele"] as EnemyTelegraph
			if t != null and is_instance_valid(t):
				t.set_progress(1.0 - float(c["rise"]) / float(c["rise_total"]))
			if float(c["rise"]) <= 0.0:
				_land(c, true)
		else:
			c["age"] = float(c["age"]) + delta
			if not permanent:
				c["life"] = float(c["life"]) - delta
				if not bool(c["eroded"]) and float(c["life"]) <= ERODE_S:
					c["eroded"] = true
				if float(c["life"]) <= 0.0:
					_remove(i, true)
					i -= 1
					continue
			_animate(c)
		i -= 1


func _animate(c: Dictionary) -> void:
	var v := c["vis"] as Node
	if v is AnimatedSprite2D:
		var s := v as AnimatedSprite2D
		var n := s.sprite_frames.get_frame_count(&"stele")
		if n >= 12:
			s.frame = (6 if bool(c["eroded"]) else 0) + int(float(c["age"]) * 8.0) % 6
	elif v != null:
		RaidFx.set_value(v, 1.0 if bool(c["eroded"]) else 0.0)


func _land(c: Dictionary, check_player: bool) -> void:
	c["rise"] = 0.0
	var t := c["tele"] as EnemyTelegraph
	if t != null and is_instance_valid(t):
		t.queue_free()
	c["tele"] = null
	var p: Vector2 = c["pos"]
	var body := StaticBody2D.new()
	body.name = &"SaltStele_body"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = RADIUS_U * RaidKit.U
	cs.shape = sh
	body.add_child(cs)
	add_child(body)
	body.global_position = p
	var vis: Node2D
	if _frames != null:
		var s := AnimatedSprite2D.new()
		EmissiveOverlay.apply(s, _frames, 1.4)
		s.animation = &"stele"
		s.scale = Iso.UNSQUASH * Iso.SPRITE_K
		var tex := _frames.get_frame_texture(&"stele", 0)
		if tex != null:
			s.offset = Vector2(0.0, -tex.get_height() * 0.5)
		s.pause()
		vis = s
	else:
		vis = RaidFx.visual(&"stele", RaidFx.Kind.PYLON, Color(0.79, 0.83, 0.84), RADIUS_U * RaidKit.U)
	body.add_child(vis)
	c["body"] = body
	c["vis"] = vis
	if nav != null:
		nav.add_circle_obstacle(body.get_instance_id(), p, RADIUS_U * RaidKit.U)
	if check_player:
		var pl := RaidKit.player_of(self)
		if pl != null and pl.global_position.distance_to(p) <= HIT_R_U * RaidKit.U:
			hits += 1
			RaidKit.boss_hit(boss, pl, float(c["coef"]))
	landed_total += 1
	RaidFx.sfx(&"enemy.salt_king_stele.medium", p)
	landed.emit(p)


func _remove(i: int, notify: bool) -> void:
	var c: Dictionary = steles[i]
	var t := c["tele"] as Node
	if t != null and is_instance_valid(t):
		t.queue_free()
	var body := c["body"] as Node
	if body != null and is_instance_valid(body):
		if nav != null:
			nav.remove_obstacle(body.get_instance_id())
		body.queue_free()
	var p: Vector2 = c["pos"]
	steles.remove_at(i)
	if notify and body != null:
		expired.emit(p)


## Mort du boss : les stèles restent, sans minuterie ; le nœud se pilote seul (érosion figée).
func make_permanent() -> void:
	permanent = true
	detached = true


## Libère tout (retour au pool, changement d'étage).
func release() -> void:
	while not steles.is_empty():
		_remove(steles.size() - 1, false)
	queue_free()


func _exit_tree() -> void:
	for c in steles:
		var body := c["body"] as Node
		if nav != null and body != null and is_instance_valid(body):
			nav.remove_obstacle(body.get_instance_id())
