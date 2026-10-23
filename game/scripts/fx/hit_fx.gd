class_name HitFx
extends Node2D
## Particules d'impact au point de contact (coups directs) et petites particules de DoT (brûlure,
## poison, zones persistantes). Textures rendues dans Blender : assets/sprites/vfx/particles/
## (spark, ember, smoke, fire_drop, frost_flake, poison_bubble, arc_fragment) et l'éclat
## assets/sprites/vfx/ember_shard_impact (impact du projectile d'Ardent).
##
## Performance : UN seul nœud, un pool fixe de Sprite2D créés au _ready (jamais en jeu), animés par
## une boucle unique sur les seuls actifs (tableaux packés). Plafond global d'impacts par image.
## Instance unique créée à la volée par Enemy._ready (HitFx.ensure) sous le Director.
## API : HitFx.impact(pos, dir, element, f, is_crit, anim) ; HitFx.dot(pos, element).
## Caméra iso 2:1 : les particules sont volumiques, donc en espace billboard (le nœud porte
## Iso.UNSQUASH). `pos` reste un point du monde en y logique, MAIS sa hauteur au-dessus des pieds est
## déjà comptée en y logique (Enemy fournit pieds + hauteur × 2) ; il est converti ici en (x, y/2).
## `dir` (plan de sol) passe par Iso.to_screen_dir ; vitesses, gravité et dérive verticales sont
## déjà des px d'écran. Les rotations (suivi de vitesse, éclat) sont des angles d'écran.

enum Kind { SPARK, EMBER, SMOKE, FIRE_DROP, FROST, POISON, ARC }

const DIR := "res://assets/sprites/vfx/particles/"
const KIND_FILES := ["spark", "ember", "smoke", "fire_drop", "frost_flake", "poison_bubble", "arc_fragment"]
const VARIANTS := 4
const SHARD_FRAMES := "res://assets/sprites/vfx/ember_shard_impact/ember_shard_impact.tres"
const POOL_SIZE := 192
const SHARD_POOL := 12
const SHARD_SCALE := 0.55 ## 96 px -> ~53 px (≈ 0,8 u)
const IMPACTS_PER_FRAME := 24 ## plafond global (coups directs + DoT) par image
const DOT_PER_FRAME := 10 ## dont DoT au plus
const Z := 30 ## au-dessus des monstres, sous les chiffres de dégâts (100)
const HDR := Color(1.5, 1.35, 1.2, 1.0) ## modulation additive (glow HDR)

static var _inst: HitFx = null
static var _frame := -1
static var _budget := 0
static var _dot_budget := 0
## compteurs (tests / mesures)
static var stat_impacts := 0
static var stat_dots := 0
static var stat_dropped := 0

var _tex: Array = [] ## Kind -> Array[Texture2D]
var _sprites: Array[Sprite2D] = []
var _shards: Array[AnimatedSprite2D] = []
var _mat_add: CanvasItemMaterial
var _mat_mix: CanvasItemMaterial
var _free := PackedInt32Array()
var _live := PackedInt32Array()
var _vel := PackedVector2Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _drag := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _s0 := PackedFloat32Array()
var _s1 := PackedFloat32Array()
var _a0 := PackedFloat32Array()
var _follow := PackedByteArray()
var _rng := RandomNumberGenerator.new()


## Crée l'instance unique (différé) sous `parent` si elle n'existe pas encore.
static func ensure(parent: Node) -> void:
	if _inst != null and is_instance_valid(_inst) and not _inst.is_queued_for_deletion():
		return
	if parent == null:
		return
	_inst = HitFx.new()
	_inst.name = &"HitFx"
	parent.add_child.call_deferred(_inst)


static func instance() -> HitFx:
	if _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree():
		return _inst
	return null


static func _take_budget(is_dot: bool) -> bool:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_budget = IMPACTS_PER_FRAME
		_dot_budget = DOT_PER_FRAME
	if _budget <= 0 or (is_dot and _dot_budget <= 0):
		stat_dropped += 1
		return false
	_budget -= 1
	if is_dot:
		_dot_budget -= 1
	return true


## Coup direct : gerbe d'étincelles orientée selon `dir` (sens du coup), braises selon l'élément.
## f : force relative [0, 1] (Balance.hit_force) ; le nombre de particules la suit.
static func impact(pos: Vector2, dir: Vector2, element: StringName, f: float, is_crit: bool = false, anim: bool = false) -> void:
	var fx := instance()
	if fx == null or not _take_budget(false):
		return
	stat_impacts += 1
	fx._impact(pos, dir, element, f, is_crit, anim)


## Tic de DoT : une particule discrète (flammèche, bulle).
static func dot(pos: Vector2, element: StringName) -> void:
	var fx := instance()
	if fx == null or not _take_budget(true):
		return
	stat_dots += 1
	fx._dot(pos, element)


func _ready() -> void:
	top_level = true
	scale = Iso.UNSQUASH
	z_index = Z
	light_mask = 0
	_rng.randomize()
	_mat_add = CanvasItemMaterial.new()
	_mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_mat_add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_mat_mix = CanvasItemMaterial.new()
	_mat_mix.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for k in KIND_FILES.size():
		var arr: Array[Texture2D] = []
		for v in VARIANTS:
			var p := "%s%s_%02d.png" % [DIR, KIND_FILES[k], v + 1]
			if ResourceLoader.exists(p):
				arr.append(load(p) as Texture2D)
		_tex.append(arr)
	_vel.resize(POOL_SIZE)
	_age.resize(POOL_SIZE)
	_life.resize(POOL_SIZE)
	_drag.resize(POOL_SIZE)
	_grav.resize(POOL_SIZE)
	_s0.resize(POOL_SIZE)
	_s1.resize(POOL_SIZE)
	_a0.resize(POOL_SIZE)
	_follow.resize(POOL_SIZE)
	for i in POOL_SIZE:
		var s := Sprite2D.new()
		s.visible = false
		s.light_mask = 0
		add_child(s)
		_sprites.append(s)
		_free.append(POOL_SIZE - 1 - i)
	var frames: SpriteFrames = load(SHARD_FRAMES) if ResourceLoader.exists(SHARD_FRAMES) else null
	if frames != null:
		for i in SHARD_POOL:
			var a := AnimatedSprite2D.new()
			a.sprite_frames = frames
			a.visible = false
			a.light_mask = 0
			a.material = _mat_add
			a.scale = Vector2(SHARD_SCALE, SHARD_SCALE)
			a.animation_finished.connect(a.hide)
			add_child(a)
			_shards.append(a)
	set_process(false)


func _low() -> bool:
	return Quality.tier == Quality.Tier.LOW


func _count(n: float) -> int:
	return maxi(1, roundi(n * (0.5 if _low() else 1.0)))


func _impact(pos: Vector2, dir: Vector2, element: StringName, f: float, is_crit: bool, anim: bool) -> void:
	var d := dir if dir.length_squared() > 0.0001 else Vector2.from_angle(_rng.randf() * TAU)
	var base := d.angle()
	var sparks := _count(lerpf(2.0, 6.0, f) + (1.0 if is_crit else 0.0))
	var spark_kind := Kind.SPARK
	var second := Kind.EMBER
	var n2 := 0
	match element:
		&"fire":
			n2 = _count(lerpf(1.0, 3.0, f))
		&"ice", &"frost":
			second = Kind.FROST
			n2 = _count(lerpf(1.0, 3.0, f))
		&"lightning":
			spark_kind = Kind.ARC
			sparks = _count(lerpf(1.0, 3.0, f))
		&"poison":
			second = Kind.POISON
			n2 = _count(lerpf(1.0, 2.0, f))
	for i in sparks:
		var a := base + _rng.randf_range(-0.9, 0.9)
		_spawn(spark_kind, pos, Iso.to_screen_dir(Vector2.from_angle(a)) * _rng.randf_range(260.0, 520.0) * (0.8 + 0.4 * f),
			_rng.randf_range(0.14, 0.24), 7.0, 0.0, _rng.randf_range(0.6, 0.9) * (1.0 + 0.3 * f), 0.4, 1.0, true, true)
	for i in n2:
		var a2 := base + _rng.randf_range(-1.3, 1.3)
		_spawn(second, pos, Iso.to_screen_dir(Vector2.from_angle(a2)) * _rng.randf_range(70.0, 170.0) + Vector2(0.0, -40.0),
			_rng.randf_range(0.3, 0.5), 3.0, -90.0, _rng.randf_range(0.45, 0.75), 0.5, 1.0, false, second != Kind.POISON)
	if f >= 0.55 and not _low():
		_spawn(Kind.SMOKE, pos, Iso.to_screen_dir(d) * 30.0 + Vector2(0.0, -20.0), 0.45, 2.0, -20.0, 0.45, 1.6, 0.35, false, false)
	if anim and not _low():
		for s in _shards:
			if not s.visible:
				s.position = _to_billboard(pos)
				s.rotation = Iso.screen_angle(d)
				s.visible = true
				s.play(&"default")
				break


func _dot(pos: Vector2, element: StringName) -> void:
	var p := pos + Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-8.0, 4.0))
	match element:
		&"poison":
			_spawn(Kind.POISON, p, Vector2(_rng.randf_range(-12.0, 12.0), -35.0), 0.45, 1.0, -20.0, 0.45, 0.8, 0.85, false, false)
		&"lightning":
			_spawn(Kind.ARC, p, Iso.to_screen_dir(Vector2.from_angle(_rng.randf() * TAU)) * 60.0, 0.12, 4.0, 0.0, 0.4, 0.6, 0.8, true, true)
		&"ice", &"frost": # DoT de glace / d'eau : éclat froid qui saute et retombe (jamais de flammèche)
			_spawn(Kind.FROST, p, Vector2(_rng.randf_range(-14.0, 14.0), -40.0), 0.4, 1.5, 90.0, 0.45, 0.7, 0.85, false, true)
		_: # brûlure, Cendres et autres DoT de feu : petite flammèche qui monte
			_spawn(Kind.FIRE_DROP, p, Vector2(_rng.randf_range(-15.0, 15.0), -55.0), 0.38, 1.5, -40.0, 0.5, 0.5, 0.85, false, true)


## Point du monde (y logique) -> espace billboard : (x, y/2).
func _to_billboard(p: Vector2) -> Vector2:
	return Vector2(p.x, p.y / Iso.UNSQUASH.y)


## v : vitesse initiale (px/s, espace billboard = px d'écran) ; drag : amortissement (1/s) ; grav : accélération verticale (px/s²,
## négative = monte) ; s0 -> s0 × s1 sur la vie ; a0 : opacité de départ ; follow : orienté selon la vitesse.
func _spawn(kind: int, pos: Vector2, v: Vector2, life: float, drag: float, grav: float, s0: float, s1: float, a0: float, follow: bool, additive: bool) -> void:
	var texs: Array = _tex[kind]
	if texs.is_empty() or _free.is_empty():
		return
	var i := _free[_free.size() - 1]
	_free.remove_at(_free.size() - 1)
	_live.append(i)
	var s := _sprites[i]
	s.texture = texs[_rng.randi() % texs.size()]
	s.material = _mat_add if additive else _mat_mix
	s.position = _to_billboard(pos)
	s.rotation = v.angle() if follow else _rng.randf() * TAU
	s.scale = Vector2(s0, s0)
	var c := HDR if additive else Color.WHITE
	c.a = a0
	s.modulate = c
	s.visible = true
	_vel[i] = v
	_age[i] = 0.0
	_life[i] = life
	_drag[i] = drag
	_grav[i] = grav
	_s0[i] = s0
	_s1[i] = s1
	_a0[i] = a0
	_follow[i] = 1 if follow else 0
	set_process(true)


func live_count() -> int:
	return _live.size()


func _process(delta: float) -> void:
	var k := _live.size() - 1
	while k >= 0:
		var i := _live[k]
		var age := _age[i] + delta
		var s := _sprites[i]
		if age >= _life[i]:
			s.visible = false
			_free.append(i)
			_live[k] = _live[_live.size() - 1]
			_live.remove_at(_live.size() - 1)
			k -= 1
			continue
		_age[i] = age
		var v := _vel[i] * maxf(0.0, 1.0 - _drag[i] * delta)
		v.y += _grav[i] * delta
		_vel[i] = v
		s.position += v * delta
		var t := age / _life[i]
		var sc := _s0[i] * lerpf(1.0, _s1[i], t)
		s.scale = Vector2(sc, sc)
		s.modulate.a = _a0[i] * (1.0 - t * t)
		if _follow[i] == 1:
			s.rotation = v.angle()
		k -= 1
	if _live.is_empty():
		set_process(false)
