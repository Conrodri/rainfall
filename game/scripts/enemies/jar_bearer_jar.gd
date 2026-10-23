class_name JarBearerJar
extends AnimatableBody2D
## Jarre-mère de la Porteuse de jarres (docs/Design_Etages.md §5.1, sort B) : obstacle de 1 u posé au sol qui
## explose au bout de 3 s (anneau télégraphé par JarBearerBrain). Cassable : corps sur la couche des monstres
## (3) et dans le groupe `enemies`, donc touché par les projectiles, les zones et les sorts du joueur comme un
## monstre (contre-jeu « zone : casser les jarres-mères ») ; cassée, elle s'éteint sans exploser.
## Pas un Enemy (pas de pool, pas de prime, jamais de signal enemy_killed) : expose seulement l'interface que les
## sorts lisent sur une cible (take_damage, apply_status, stun, push, is_slowed…, active, tier, is_boss,
## is_elite, radius_px, hp, max_hp). Visuel : extra `mother_jar` du .tres de la porteuse, sinon jarre dessinée.

const LAYER_ENEMIES := 1 << 2

var active := true
var tier := 1
var is_boss := false
var is_elite := false
var damage := 0.0
var affixes: Array[StringName] = []
var radius_px := 32.0
var hp := 1.0
var max_hp := 1.0
var broken := false ## cassée par le joueur
var hits := 0

var _vis: Node2D = null
var _flash := 0.0
var _nav: NavField = null ## obstacle dynamique posé (block) : contourné par les monstres
var _block: StaticBody2D = null ## couche 1 « world » : bloque le joueur


static func spawn(host: Node, pos: Vector2, p_hp: float, frames: SpriteFrames, r_px: float) -> JarBearerJar:
	var j := JarBearerJar.new()
	j.name = &"JarBearer_mother"
	j.radius_px = r_px
	j.hp = p_hp
	j.max_hp = p_hp
	j.sync_to_physics = false
	j.collision_mask = 0
	j.collision_layer = 0
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = r_px
	cs.shape = sh
	j.add_child(cs)
	if frames != null and frames.has_animation(&"mother_jar"):
		var s := Floor1Fx.sprite(frames, &"mother_jar", "JarBearer_", 2.0)
		s.scale = Floor1Fx.billboard(r_px * 2.2, 72.0)
		s.offset = Vector2(0.0, -48.0)
		s.play(&"mother_jar")
		j._vis = s
	else:
		var f := Floor1Fx.make(Floor1Fx.Kind.JAR)
		f.color = Floor1Fx.CLAY
		f.scale_u = r_px * 2.0 / Balance.UNIT_PX
		f.position = Vector2(0.0, -r_px * 0.9)
		j._vis = f
	j.add_child(j._vis)
	host.add_child(j)
	j.position = pos
	j.add_to_group(&"enemies")
	j.set_deferred(&"collision_layer", LAYER_ENEMIES)
	return j


func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"", _hit: Dictionary = {}) -> void:
	if not active or amount <= 0.0:
		return
	hp -= amount
	hits += 1
	_flash = 0.08
	if _vis != null:
		_vis.modulate = Color(2.0, 2.0, 2.0)
		if _vis is Floor1Fx:
			(_vis as Floor1Fx).cracks = 1.0 - clampf(hp / max_hp, 0.0, 1.0)
			_vis.queue_redraw()
	if hp <= 0.0:
		broken = true
		retire()


## Rend la jarre bloquante (obstacle de 1 u) : corps couche 1 (joueur) + obstacle dynamique NavField (monstres).
func block(nav: NavField) -> void:
	if not active or _block != null:
		return
	_block = StaticBody2D.new()
	_block.name = &"JarBearer_block"
	_block.collision_layer = 1
	_block.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = radius_px
	cs.shape = sh
	_block.add_child(cs)
	add_child(_block)
	_nav = nav
	if _nav != null:
		_nav.add_circle_obstacle(get_instance_id(), position, radius_px)


func _unblock() -> void:
	if _nav != null:
		_nav.remove_obstacle(get_instance_id())
		_nav = null
	if _block != null and is_instance_valid(_block):
		_block.queue_free()
	_block = null


func _exit_tree() -> void:
	_unblock()


## Hors jeu (cassée, explosée ou boss mort) : quitte le groupe et la couche des monstres.
func retire() -> void:
	if not active:
		return
	active = false
	visible = false
	_unblock()
	if is_in_group(&"enemies"):
		remove_from_group(&"enemies")
	set_deferred(&"collision_layer", 0)


func _physics_process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0 and _vis != null:
			_vis.modulate = Color.WHITE


func apply_status(_status: StringName, _data: Dictionary) -> void:
	pass


func stun(_seconds: float) -> void:
	pass


func push(_offset_px: Vector2) -> void:
	pass


func imprison(_seconds: float, _release_pct := 0.0, _release_s := 0.0) -> void:
	pass


func is_slowed() -> bool:
	return false


func is_burning() -> bool:
	return false


func is_poisoned() -> bool:
	return false


func is_stunned() -> bool:
	return false


func is_flashing() -> bool:
	return _flash > 0.0
