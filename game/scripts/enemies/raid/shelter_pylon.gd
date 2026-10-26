class_name ShelterPylon
extends Node2D
## Pylônes-abris d'un boss (docs/Design_Boss_Raid.md §1.2) : UN nœud par boss gère tous ses pylônes (plafond
## RAID_PYLON_MAX = 6, les plus vieux cassent), une seule passe par image physique.
## - Pose : chute télégraphée `fall_s` (0,9 s, cercle rouge 1,2 u ; joueur dessous -> coup du boss coef
##   RAID_PYLON_FALL_COEF), puis StaticBody2D couche 1 (bloque le joueur) de rayon 0,5 u + obstacle dynamique NavField
##   (les monstres le contournent).
## - Abri : chaque image, les projectiles ennemis qui touchent un pylône sont détruits (EnemyProjectilePool.cull_circles)
##   et l'abîment ; pendant un barrage (`set_shadow_origin`), l'ombre derrière chaque pylône (couloir de 1 u × 6 u
##   dans l'axe origine -> pylône) est aussi protégée (cull_shadows) et dessinée au sol (bande cyan).
## - Vie `life_s` (12-16 s), PV = RAID_PYLON_HP_FRAC des PV du boss ; 3 états d'usure (ok / fissuré / brisé) ;
##   PROJ_HITS_TO_BREAK projectiles le cassent (20 par état), `damage_pylon` pour un obus du boss.
## Visuel : anims `pylon_ok|pylon_cracked|pylon_broken` du .tres du boss si présentes (billboard), sinon forme
## provisoire ; ombre : anim `shelter_shadow` du kit.

signal pylon_broken(pos: Vector2)
signal pylon_landed(pos: Vector2)

const RADIUS_U := 0.5
const FALL_R_U := 1.2
const FALL_S := 0.9
const SHADOW_HALF_W_U := 0.5
const SHADOW_LEN_U := 6.0
const WALL_MARGIN_U := 2.0
const PROJ_HITS_TO_BREAK := 60.0
const WEAR_ANIMS := [&"pylon_ok", &"pylon_cracked", &"pylon_broken"]

var boss: Node2D = null
var nav: NavField = null
var life_s := 14.0
var pylons: Array[Dictionary] = [] ## {pos, fall, tele, body, vis, shadow, hp, max_hp, life, wear}
var shadow_origin := Vector2.INF ## origine du barrage en cours (INF = pas d'ombre)
var blocked_total := 0 ## projectiles arrêtés (tests, mesure)
var _frames: SpriteFrames = null
var _centers := PackedVector2Array()
var _radii := PackedFloat32Array()
var _counts := PackedInt32Array()
var _standing := PackedVector2Array()
var _index: PackedInt32Array = PackedInt32Array() ## index de pylône de chaque centre (pylônes debout)
var _shadows_shown := false


static func create(p_boss: Node2D, p_life_s := 14.0) -> ShelterPylon:
	var s := ShelterPylon.new()
	s.name = &"ShelterPylon"
	s.boss = p_boss
	s.life_s = p_life_s
	s.nav = p_boss.get(&"nav") as NavField
	var bv := p_boss.get(&"visual") as EnemyVisual
	if bv != null and bv.body_sprite() != null and bv.body_sprite().sprite_frames.has_animation(&"pylon_ok"):
		s._frames = bv.body_sprite().sprite_frames
	RaidKit.world_of(p_boss).add_child(s)
	return s


## Plante un pylône en `at` (ramené sur le sol accessible, à WALL_MARGIN_U des murs). Retourne sa position.
func plant(at: Vector2, fall_s := FALL_S) -> Vector2:
	while pylons.size() >= Balance.RAID_PYLON_MAX:
		_break(0)
	var p := RaidKit.place(boss, at)
	if nav != null:
		p = nav.resolve(p, WALL_MARGIN_U * RaidKit.U)
	var bhp: float = float(boss.get(&"max_hp")) if boss != null and boss.get(&"max_hp") != null else 100.0
	var c := {"pos": p, "fall": maxf(fall_s, 0.0), "tele": null, "body": null, "vis": null, "shadow": null,
		"max_hp": maxf(bhp * Balance.RAID_PYLON_HP_FRAC, 1.0), "life": life_s + maxf(fall_s, 0.0), "wear": 0}
	c["hp"] = c["max_hp"]
	if fall_s > 0.0:
		var t := EnemyTelegraph.new()
		add_child(t)
		t.show_circle(p, FALL_R_U * RaidKit.U)
		c["tele"] = t
	pylons.append(c)
	if fall_s <= 0.0:
		_land(c, false)
	return p


## Plante `count` pylônes à `dist_u` de `center`, répartis à 360/count degrés (>= 90° jusqu'à 4).
func plant_around(center: Vector2, count := 3, dist_u := 5.0, base_angle := 0.0, fall_s := FALL_S) -> void:
	for k in count:
		plant(center + Vector2.from_angle(base_angle + TAU * k / maxf(count, 1)) * dist_u * RaidKit.U, fall_s)


## Pylônes debout (posés, pas en chute).
func live_count() -> int:
	var n := 0
	for c in pylons:
		if float(c["fall"]) <= 0.0:
			n += 1
	return n


func positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for c in pylons:
		if float(c["fall"]) <= 0.0:
			out.append(c["pos"])
	return out


## Le point p est-il à l'abri de l'origine `origin` (ligne de vue coupée par un pylône debout, ou dans une ombre) ?
func shelters(p: Vector2, origin: Vector2) -> bool:
	var r := RADIUS_U * RaidKit.U
	for c in pylons:
		if float(c["fall"]) > 0.0:
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


## Barrage en cours depuis `origin` : ombres protégées et dessinées (INF : coupées).
func set_shadow_origin(origin: Vector2) -> void:
	shadow_origin = origin
	_sync_shadows()


func clear_shadow() -> void:
	set_shadow_origin(Vector2.INF)


## Abîme le pylône le plus proche de `at` (à `r_px` près) : obus du boss…
func damage_at(at: Vector2, amount: float, r_px := 48.0) -> void:
	for i in range(pylons.size() - 1, -1, -1):
		var c: Dictionary = pylons[i]
		if float(c["fall"]) <= 0.0 and (c["pos"] as Vector2).distance_to(at) <= r_px + RADIUS_U * RaidKit.U:
			_damage(i, amount)
			return


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	var i := pylons.size() - 1
	while i >= 0:
		var c: Dictionary = pylons[i]
		if float(c["fall"]) > 0.0:
			c["fall"] = float(c["fall"]) - delta
			var t := c["tele"] as EnemyTelegraph
			if t != null and is_instance_valid(t):
				t.set_progress(1.0 - float(c["fall"]) / FALL_S)
			if float(c["fall"]) <= 0.0:
				_land(c, true)
		c["life"] = float(c["life"]) - delta
		if float(c["life"]) <= 0.0:
			_break(i)
		i -= 1
	_cull()


## Une passe pour tous les pylônes : disques (et usure), puis ombres si un barrage est en cours.
func _cull() -> void:
	var pool := RaidKit.pool_of(boss)
	if pool == null or pool.active_count() == 0:
		return
	var n := 0
	for c in pylons:
		if float(c["fall"]) <= 0.0:
			n += 1
	if n == 0:
		return
	if _centers.size() != n:
		_centers.resize(n)
		_radii.resize(n)
		_counts.resize(n)
		_index.resize(n)
		_standing.resize(n)
	var k := 0
	for i in pylons.size():
		var c: Dictionary = pylons[i]
		if float(c["fall"]) <= 0.0:
			_centers[k] = c["pos"]
			_radii[k] = RADIUS_U * RaidKit.U
			_counts[k] = 0
			_index[k] = i
			k += 1
	blocked_total += pool.cull_circles(_centers, _radii, _counts)
	if shadow_origin != Vector2.INF:
		blocked_total += pool.cull_shadows(shadow_origin, _centers, SHADOW_HALF_W_U * RaidKit.U, SHADOW_LEN_U * RaidKit.U)
	for j in range(n - 1, -1, -1):
		if _counts[j] > 0:
			var c: Dictionary = pylons[_index[j]]
			_damage(_index[j], float(_counts[j]) * float(c["max_hp"]) / PROJ_HITS_TO_BREAK)


func _land(c: Dictionary, check_player: bool) -> void:
	c["fall"] = 0.0
	var t := c["tele"] as EnemyTelegraph
	if t != null and is_instance_valid(t):
		t.queue_free()
	c["tele"] = null
	var p: Vector2 = c["pos"]
	var body := StaticBody2D.new()
	body.name = &"ShelterPylon_body"
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
		s.animation = WEAR_ANIMS[0]
		s.scale = Iso.UNSQUASH * Iso.SPRITE_K
		var tex := _frames.get_frame_texture(WEAR_ANIMS[0], 0)
		if tex != null:
			s.offset = Vector2(0.0, -tex.get_height() * 0.5)
		s.play()
		vis = s
	else:
		vis = RaidFx.visual(&"pylon", RaidFx.Kind.PYLON, RaidFx.CYAN, RADIUS_U * RaidKit.U)
	body.add_child(vis)
	body.add_to_group(RaidFx.CUE_GROUP)
	c["body"] = body
	c["vis"] = vis
	if nav != null:
		nav.add_circle_obstacle(body.get_instance_id(), p, RADIUS_U * RaidKit.U)
	if check_player:
		var pl := RaidKit.player_of(self)
		if pl != null and pl.global_position.distance_to(p) <= FALL_R_U * RaidKit.U:
			RaidKit.boss_hit(boss, pl, Balance.RAID_PYLON_FALL_COEF)
	RaidFx.sfx(&"enemy.raid_pylon_land.heavy", p)
	if shadow_origin != Vector2.INF:
		_sync_shadows()
	pylon_landed.emit(p)


func _damage(i: int, amount: float) -> void:
	var c: Dictionary = pylons[i]
	c["hp"] = float(c["hp"]) - amount
	if float(c["hp"]) <= 0.0:
		_break(i)
		return
	var wear := clampi(int((1.0 - float(c["hp"]) / float(c["max_hp"])) * 3.0), 0, 2)
	if wear != int(c["wear"]):
		c["wear"] = wear
		var vis := c["vis"] as Node2D
		if vis is AnimatedSprite2D and (vis as AnimatedSprite2D).sprite_frames.has_animation(WEAR_ANIMS[wear]):
			(vis as AnimatedSprite2D).play(WEAR_ANIMS[wear])
		else:
			RaidFx.set_value(vis, float(wear))


func _break(i: int) -> void:
	var c: Dictionary = pylons[i]
	var t := c["tele"] as EnemyTelegraph
	if t != null and is_instance_valid(t):
		t.queue_free()
	var body := c["body"] as Node
	if body != null and is_instance_valid(body):
		if nav != null:
			nav.remove_obstacle(body.get_instance_id())
		body.queue_free()
	for key in ["shadow", "shadow_holder"]:
		var sh := c.get(key) as Node
		if sh != null and is_instance_valid(sh):
			sh.queue_free()
	var p: Vector2 = c["pos"]
	pylons.remove_at(i)
	if body != null:
		RaidFx.sfx(&"enemy.raid_pylon_break.medium", p)
		pylon_broken.emit(p)


## Bandes cyan d'ombre protégée (une par pylône debout), visibles seulement pendant un barrage.
func _sync_shadows() -> void:
	var on := shadow_origin != Vector2.INF
	for c in pylons:
		if float(c["fall"]) > 0.0:
			continue
		var sh := c["shadow"] as Node2D
		if sh == null and on:
			var holder := Node2D.new()
			holder.name = &"ShelterShadow"
			add_child(holder)
			holder.global_position = c["pos"]
			var v := RaidFx.visual(&"shelter_shadow", RaidFx.Kind.SHADOW, RaidFx.CYAN, SHADOW_LEN_U * RaidKit.U)
			if v is RaidFx:
				(v as RaidFx).width = SHADOW_HALF_W_U * 2.0 * RaidKit.U
			sh = RaidFx.attach_ground(holder, v, -2)
			c["shadow"] = sh
			c["shadow_holder"] = holder
		if sh != null:
			sh.visible = on
			if on:
				sh.rotation = ((c["pos"] as Vector2) - shadow_origin).angle()
	_shadows_shown = on


func shadows_shown() -> bool:
	return _shadows_shown


## Libère tous les pylônes (fin du combat).
func release() -> void:
	while not pylons.is_empty():
		_break(pylons.size() - 1)
	queue_free()


func _exit_tree() -> void:
	for c in pylons:
		var body := c["body"] as Node
		if nav != null and body != null and is_instance_valid(body):
			nav.remove_obstacle(body.get_instance_id())
