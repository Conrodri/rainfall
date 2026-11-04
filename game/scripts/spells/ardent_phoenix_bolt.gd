class_name ArdentPhoenixBolt
extends Node2D
## Trait de feu du Phénix d'Ardent (ArdentPhoenix) : projectile qui part du phénix et TRAVERSE tous les monstres sur
## sa portée (chaque monstre n'est touché qu'une fois par trait), puis s'éteint au bout de sa course ou sur un mur plein.
## Couloir de touche : segment parcouru pendant l'image, demi-largeur HALF_W_U + rayon du monstre (balayage continu,
## aucun monstre sauté à grande vitesse). Pas de physique : avance par step(), donc déterministe dans les tests.
## Dégâts toujours via SpellCaster.deal_damage (items et procs du joueur), plus une brûlure par monstre touché.
## Visuel : asset dédié assets/sprites/projectiles/phoenix_bolt/ dès que Codex l'aura livré (consigne
## art/tools/iso/_phoenix_bolt.txt), sinon l'éclat de braise d'Ardent (asset Codex ember_shard, agrandi) ; il descend de
## l'altitude du phénix vers sa hauteur de vol en début de course.
## Pourquoi pas le pool de projectiles de SpellCaster : il part toujours du joueur, sa hitbox est fixe (14 px), il ne
## pose pas de statut à la touche et il dépend des collisions physiques (non déterministe dans les tests pas à pas).

const FRAMES_DEDICATED := "res://assets/sprites/projectiles/phoenix_bolt/phoenix_bolt.tres"
const SCALE_DEDICATED := 1.0 ## frame 96 px, oiseau de ~70 px -> ~1,1 u
const FRAMES := "res://assets/sprites/projectiles/ember_shard/ember_shard.tres"
const SPRITE_SCALE := 1.5 ## frame 48 px -> ~1,1 u
const LAND_U := 0.5 ## hauteur de vol après la descente (comme un projectile du joueur)
const DESCENT_K := 0.25 ## fraction de la course pendant laquelle le trait descend de l'altitude du phénix

var caster: SpellCaster = null
var player: Node2D = null
var spell: SpellData = null
var source: Node = null ## phénix lanceur (compteurs de test), peut disparaître avant la fin du trait
var direction := Vector2.RIGHT
var speed_px := 0.0
var range_px := 0.0
var half_w_px := 0.0
var burn_s := 0.0
var burn_total := 0.0
var start_h_u := 0.0
var traveled := 0.0
var done := false
var hits := 0 ## monstres touchés par ce trait (tests)
## Appelé avec la position finale quand le trait finit sa course ou bute sur un mur (dernier trait du phénix :
## explosion à l'arrivée). Jamais appelé si le lanceur a disparu.
var on_end: Callable = Callable()
var _already: Array = []
var _sprite: AnimatedSprite2D = null


## `burn_total_dmg` : dégâts totaux de la brûlure posée sur chaque monstre touché (0 = aucune).
## `new_spell` null : trait sans dégâts au passage (dernier trait du phénix, qui n'agit qu'à l'arrivée via on_end).
func setup(new_caster: SpellCaster, new_player: Node2D, new_spell: SpellData, from: Vector2, dir: Vector2,
		new_speed_px: float, new_range_px: float, new_half_w_px: float, new_burn_s: float, burn_total_dmg: float,
		from_h_u: float, new_source: Node = null) -> void:
	caster = new_caster
	player = new_player
	spell = new_spell
	source = new_source
	direction = dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
	speed_px = new_speed_px
	range_px = new_range_px
	half_w_px = new_half_w_px
	burn_s = new_burn_s
	burn_total = burn_total_dmg
	start_h_u = from_h_u
	name = "PhoenixBolt"
	global_position = from
	_build_visual()


func _build_visual() -> void:
	LightRig.attach(self, &"ember")
	var dedicated := ResourceLoader.exists(FRAMES_DEDICATED)
	var path := FRAMES_DEDICATED if dedicated else FRAMES
	if not ResourceLoader.exists(path):
		return
	var sf := load(path) as SpriteFrames
	if sf == null:
		return
	var k := SCALE_DEDICATED if dedicated else SPRITE_SCALE
	var billboard := Node2D.new()
	billboard.scale = Iso.UNSQUASH
	add_child(billboard)
	_sprite = AnimatedSprite2D.new()
	_sprite.scale = Vector2(k, k)
	_sprite.rotation = Iso.screen_angle(direction)
	billboard.add_child(_sprite)
	EmissiveOverlay.apply(_sprite, sf, 2.5)
	_sprite.play(&"default")
	_update_height()
	if VfxSwap.enabled() and VfxSwap.spawn_follow(self, "ardent/phoenix_bolt", direction, false, {"src": "projectile"}) != null: VfxSwap.hide_original(_sprite) # mode test : trait de test (scripts/testmode/vfx_swap.gd)


func _update_height() -> void:
	if _sprite == null:
		return
	var k := clampf(traveled / maxf(range_px * DESCENT_K, 1.0), 0.0, 1.0)
	_sprite.position = Vector2(0.0, Iso.lift_px(lerpf(start_h_u, LAND_U, k)))


func _physics_process(delta: float) -> void:
	step(delta)


## Public pour les tests : avance de `delta` s.
func step(delta: float) -> void:
	if done:
		return
	if caster == null or not is_instance_valid(caster) or player == null or not is_instance_valid(player):
		on_end = Callable()
		_finish()
		return
	var a := global_position
	var move := minf(speed_px * delta, range_px - traveled)
	var b := a + direction * move
	var map := get_tree().get_first_node_in_group(&"stage_map") as StageMap if is_inside_tree() else null
	var stop := false
	if map != null and map.is_projectile_wall_at(b): # mur plein : le trait s'éteint contre lui
		var n := maxi(1, ceili(move / 8.0))
		for i in range(1, n + 1):
			var p := a.lerp(b, float(i) / float(n))
			if map.is_projectile_wall_at(p):
				b = a.lerp(b, float(i - 1) / float(n))
				break
		stop = true
	if spell != null:
		_sweep(a, b)
	global_position = b
	traveled += move
	_update_height()
	if stop or traveled >= range_px - 0.5:
		_finish()


## Touche une fois chaque monstre actif dont le corps croise le couloir a-b (demi-largeur half_w_px).
func _sweep(a: Vector2, b: Vector2) -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or e.is_queued_for_deletion() or e in _already \
				or not e.has_method(&"take_damage") or e.get(&"active") == false:
			continue
		var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
		var closest := Geometry2D.get_closest_point_to_segment(e.global_position, a, b)
		if closest.distance_to(e.global_position) > half_w_px + er:
			continue
		_already.append(e)
		hits += 1
		if source != null and is_instance_valid(source) and &"bolt_hits" in source:
			source.set(&"bolt_hits", int(source.get(&"bolt_hits")) + 1)
		caster.deal_damage(e, spell, {"source_pos": closest - direction * Balance.UNIT_PX})
		if burn_total > 0.0 and is_instance_valid(e) and e.has_method(&"apply_status"):
			e.apply_status(&"burn", {"duration": burn_s, "total": burn_total, "by": PlayerRef.id_of(player)})


## Agrandit le visuel (dernier trait du phénix).
func scale_visual(k: float) -> void:
	if _sprite != null:
		_sprite.scale *= k


func _finish() -> void:
	done = true
	var cb := on_end
	on_end = Callable()
	if cb.is_valid():
		cb.call(global_position)
	queue_free()
