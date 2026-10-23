extends Area2D
## Projectile du joueur, poolé par SpellCaster. Couche 4, masque 3 (ennemis).
## Visuel : Billboard (échelle Iso.UNSQUASH) / AnimatedSprite2D « Visual » (éclat de braise, 4 frames
## pointant vers +x, émission additive). Échelle 1 : frame 48 px = 0,75 u. La racine n'est pas tournée
## (forme de collision circulaire) : c'est le sprite qui l'est, de Iso.screen_angle(direction), et il vole
## à la hauteur lift_px(0,5) au-dessus du sol.

var caster: Object = null
var spell: SpellData = null
var direction := Vector2.RIGHT
var speed := 0.0
var hits_left := 1
var life_left := 0.0
var active := false
var _already_hit: Array = []
var _light: LightRig.Handle = null ## lumière du projectile (éteinte quand il dort dans le pool)


func _ready() -> void:
	collision_layer = 8 # couche 4
	collision_mask = 4 # couche 3
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)
	_light = LightRig.attach(self, &"ember")
	_visual.position = Vector2(0.0, Iso.lift_px(FLIGHT_HEIGHT_U))
	_set_active(false)


const FLIGHT_HEIGHT_U := 0.5

@onready var _visual: AnimatedSprite2D = $Billboard/Visual


## Fin de course (portée ou mur, pas un coup) : on_rest(position) si défini (couteaux plantés, S7
## `rests_on_ground`). stop_on_walls : arrêt sur la couche 1 (monde). Remis à zéro à chaque lancement.
var on_rest: Callable = Callable()
var stop_on_walls := false
## Le dernier coup (traversées épuisées) appelle aussi on_rest au point d'impact (pièces d'Avare). Remis à zéro.
var rest_on_hit := false
const WALL_MASK := 1
static var _frames_cache := {} ## chemin -> SpriteFrames (null si absent)
var _default_frames: SpriteFrames = null
var _default_em: SpriteFrames = null ## émission de la scène (braise)
var _src_frames: SpriteFrames = null ## frames source affichées (jamais la version convertie)


func launch(from: Vector2, dir: Vector2, new_spell: SpellData, new_caster: Object, new_speed: float, range_px: float, hits: int) -> void:
	on_rest = Callable()
	stop_on_walls = false
	rest_on_hit = false
	_apply_frames(new_spell.projectile_frames if new_spell != null else "")
	global_position = from
	direction = dir.normalized()
	_visual.rotation = Iso.screen_angle(direction)
	spell = new_spell
	caster = new_caster
	speed = new_speed
	life_left = range_px / maxf(new_speed, 1.0)
	hits_left = hits
	_already_hit.clear()
	if _light != null:
		_light.set_preset(new_spell.light_preset if new_spell != null and new_spell.light_preset != &"" else &"ember")
	_set_active(true)


func _set_active(on: bool) -> void:
	active = on
	visible = on
	if _light != null:
		_light.set_enabled(on)
	if _visual != null:
		if on:
			_visual.play(&"default")
		else:
			_visual.stop()
	set_physics_process(on)
	set_deferred("monitoring", on)


## SpriteFrames propres au sort (couteau de Rictus), sinon celles de la scène ; un asset absent
## garde l'éclat de braise (placeholder).
func _apply_frames(path: String) -> void:
	if _visual == null:
		return
	var em := _visual.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as AnimatedSprite2D
	if _default_frames == null:
		_default_frames = _visual.sprite_frames
		_default_em = em.sprite_frames if em != null else null
		_src_frames = _default_frames
	var f: SpriteFrames = _default_frames
	if path != "":
		if not _frames_cache.has(path):
			_frames_cache[path] = load(path) as SpriteFrames if ResourceLoader.exists(path) else null
		if _frames_cache[path] != null:
			f = _frames_cache[path]
	if _src_frames == f:
		return
	_src_frames = f
	if f == _default_frames:
		_visual.sprite_frames = f
		if em != null: # masque _e de la scène (braise) rétabli
			em.sprite_frames = _default_em
			em.visible = _default_em != null
	elif _visual is EmissiveOverlay: # change aussi le masque _e (sinon l'émission de la braise reste)
		(_visual as EmissiveOverlay).set_frames(f)
	else:
		_visual.sprite_frames = f


func _physics_process(delta: float) -> void:
	var motion := direction * speed * delta
	if stop_on_walls and is_inside_tree():
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, WALL_MASK)
		var col := get_world_2d().direct_space_state.intersect_ray(q)
		if not col.is_empty():
			global_position = (col["position"] as Vector2) - direction * 4.0
			_rest()
			return
	global_position += motion
	life_left -= delta
	if life_left <= 0.0:
		_rest()


func _rest() -> void:
	var cb := on_rest
	var at := global_position
	_recycle()
	if cb.is_valid():
		cb.call(at)


func _on_hit(node: Node) -> void:
	if not active or node in _already_hit or not node.is_in_group("enemies"):
		return
	_already_hit.append(node)
	if caster != null:
		# coup direct : recul dans le sens du vol (origine un peu en arrière du projectile), éclat animé
		caster.deal_damage(node, spell, {"source_pos": global_position - direction * Balance.UNIT_PX, "anim": true})
	hits_left -= 1
	if hits_left <= 0:
		if rest_on_hit and on_rest.is_valid():
			_rest()
		else:
			_recycle()


func _recycle() -> void:
	_set_active(false)
