class_name Decoy
extends Node2D
## S14 (Design_Personnages §2.6.3 sort 4, §3.3) : leurre immobile posé par un kit (Doublures de Rictus ;
## base des mottes de Bourbe). Groupes `allies` et `decoys`, jamais `enemies`.
## - PV propres (fraction des PV max du joueur), minuteur `life_s` : explosion au minuteur (sort `explode_spell`)
##   ou immédiatement à la mort (`death_spell`, 60 %).
## - Provocation : Enemy.tick prend pour cible la doublure la plus proche à PROVOKE_RANGE_U (jamais un boss).
## - push(dir) : part droit devant à FLIGHT_SPEED_U sur FLIGHT_DIST_U, une seule fois ; les monstres traversés
##   prennent `flight_spell` ; explosion au premier monstre après FLIGHT_ARM_U de vol, sur un boss, un mur,
##   ou en bout de course (§2.6.5 : le mur ne demande pas FLIGHT_ARM_U).
## Dégâts toujours via SpellCaster (deal_damage / spawn_zone) : les items et procs du joueur s'appliquent.
## Visuel : même SpriteFrames que le joueur (anim idle_<dir>), désaturé −40 % et assombri, sans Montreur ni fils.

const PROVOKE_RANGE_U := 4.0 ## rayon par défaut ; chaque leurre peut avoir le sien (provoke_range_u)
const RADIUS_U := 0.45
const FLIGHT_SPEED_U := 10.0
const FLIGHT_DIST_U := 4.0
const FLIGHT_ARM_U := 1.0
const WALL_MASK := 1
const DESATURATE := 0.4
const DARKEN := 0.75
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

## Doublures vivantes (≤ 6) : lues par Enemy (provocation) et EnemyProjectilePool (tirs reçus).
static var live: Array[Decoy] = []

## Provoque aussi les boss (mottes de Bourbe, équilibrage 22/10/2026) ; les doublures de Rictus non.
var lures_bosses := false

## En l'air (motte lancée) : ni provoquée par les monstres ni touchée par leurs tirs.
var airborne := false

## Charge de combo (docs/Design_Combos.md §5.1) : 0 = normale, 1 = chargée (couteau de l'Éventail passé à travers).
## Une doublure chargée explose avec `charge_explode_add` de coef en plus et vole avec `charge_flight_coef`
## (valeurs posées par le kit propriétaire ; 0 = pas de bonus, cas de Bourbe). Ses coups portent la méta `combo`
## (le kit la lit dans combo_hit : chiffre en couleur d'accent, son lourd).
var charged := 0.0
var charge_explode_add := 0.0
var charge_flight_coef := 0.0
const CHARGE_TINT := Color(1.5, 1.7, 1.9) ## argent spectral HDR : les fissures s'allument

## Rayon de provocation propre à ce leurre (u). Un leurre dépasse le `max_px` passé par l'appelant (4 u) s'il
## a un rayon plus grand : les appelants existants n'ont rien à changer.
var provoke_range_u := PROVOKE_RANGE_U

var caster: SpellCaster = null
var hp := 1.0
var max_hp := 1.0
var life_s := 3.0
var facing := Vector2.UP ## vers l'extérieur de l'anneau : direction de poussée
var explode_spell: SpellData = null
var death_spell: SpellData = null
var flight_spell: SpellData = null
var on_explode: Callable = Callable() ## on_explode.call(self) : soin du Montreur, vibration des fils
var exploded := false
var pushed := false
var flying := false
var flown_px := 0.0
var _t := 0.0
var _flight_hits: Array = []
var _sprite: AnimatedSprite2D = null
static var _desat_shader: Shader = null


func _ready() -> void:
	add_to_group(&"allies")
	add_to_group(&"decoys")
	live.append(self)
	tree_exiting.connect(func() -> void: live.erase(self))
	GroundMarker.attach(self, RADIUS_U, false, &"exploded") # invocation : halo fixe, caché à l'explosion / la mort


## Doublure la plus proche de `pos` qui la provoque (distance <= max(max_px, provoke_range_u du leurre)), ou null.
static func nearest_to(pos: Vector2, max_px: float) -> Decoy:
	return _nearest(pos, max_px, false)


## Leurre qui provoque les boss (lures_bosses) le plus proche de `pos` (même règle de rayon), ou null.
static func nearest_boss_lure(pos: Vector2, max_px: float) -> Decoy:
	return _nearest(pos, max_px, true)


static func _nearest(pos: Vector2, max_px: float, bosses_only: bool) -> Decoy:
	var best: Decoy = null
	var best_d := INF
	for d in live:
		if not is_instance_valid(d) or d.exploded or d.airborne or (bosses_only and not d.lures_bosses):
			continue
		var dd := d.global_position.distance_squared_to(pos)
		var lim := maxf(max_px, d.provoke_range_u * Balance.UNIT_PX)
		if dd <= lim * lim and dd <= best_d:
			best_d = dd
			best = d
	return best


## Doublure touchée par un projectile ennemi en `pos` (rayon de projectile r_px), ou null.
static func hit_by(pos: Vector2, r_px: float) -> Decoy:
	var r := r_px + RADIUS_U * Balance.UNIT_PX
	for d in live:
		if not d.exploded and not d.airborne and is_instance_valid(d) and d.global_position.distance_squared_to(pos) <= r * r:
			return d
	return null


## Changement d'étage / mort du joueur : les doublures disparaissent sans exploser (§2.6.5).
static func clear_all() -> void:
	for d in live.duplicate():
		if is_instance_valid(d):
			d.exploded = true
			d.queue_free()
	live.clear()


## Charge la doublure (une seule fois). Les sorts d'explosion et de vol sont dupliqués : ceux du kit, partagés par les
## six doublures, restent intacts. Retourne false si déjà chargée, explosée ou en l'air.
func charge(amount := 1.0) -> bool:
	if exploded or airborne or charged > 0.0 or amount <= 0.0:
		return false
	charged = clampf(amount, 0.0, 1.0)
	if explode_spell != null:
		explode_spell = explode_spell.duplicate() as SpellData
		explode_spell.coef += charge_explode_add * charged
		explode_spell.set_meta(&"combo", true)
	if flight_spell != null and charge_flight_coef > 0.0:
		flight_spell = flight_spell.duplicate() as SpellData
		flight_spell.coef = lerpf(flight_spell.coef, charge_flight_coef, charged)
		flight_spell.set_meta(&"combo", true)
	if _sprite != null:
		_sprite.self_modulate = _sprite.self_modulate * CHARGE_TINT
	return true


## Copie l'apparence du sprite du joueur (sans ses enfants : ni Montreur, ni fils).
func copy_look(src: AnimatedSprite2D) -> void:
	if src == null or src.sprite_frames == null:
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = src.sprite_frames
	_sprite.scale = src.scale
	_sprite.offset = src.offset
	_sprite.self_modulate = src.self_modulate * Color(DARKEN, DARKEN, DARKEN, 1.0)
	_sprite.material = _desat_material()
	add_child(_sprite)
	var i := roundi(facing.angle() / (TAU / 8.0))
	var anim := StringName("idle_" + DIR_NAMES[(i % 8 + 8) % 8])
	if not _sprite.sprite_frames.has_animation(anim):
		anim = &"idle_s"
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


## Apparition (frame d'impact de `summon`) : le pantin jaillit (échelle 0,4 -> 1 avec dépassement, éclat pâle
## qui retombe) et une gerbe d'éclats et de fumée (HitFx, textures rendues dans Blender) part vers l'extérieur.
## Placeholder de `double_burst` (lot M3) côté apparition.
const APPEAR_S := 0.22
const APPEAR_FX_HEIGHT_U := 0.5
func appear() -> void:
	if _sprite != null:
		var s0 := _sprite.scale
		_sprite.scale = s0 * 0.4
		_sprite.modulate = Color(2.2, 2.2, 2.0, 0.35)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_sprite, "scale", s0, APPEAR_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sprite, "modulate", Color.WHITE, APPEAR_S)
	HitFx.impact(global_position + Vector2(0.0, Iso.lift_logical(APPEAR_FX_HEIGHT_U)), facing, &"physical", 0.6)


static func _desat_material() -> ShaderMaterial:
	if _desat_shader == null:
		_desat_shader = Shader.new()
		_desat_shader.code = "shader_type canvas_item;\nuniform float desat = 0.4;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat g = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(mix(c.rgb, vec3(g), desat), c.a);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = _desat_shader
	m.set_shader_parameter("desat", DESATURATE)
	return m


# --- Contrat « cible » des monstres (comme le joueur) ------------------------

func take_damage(amount: float, _source: Node = null) -> void:
	if exploded or amount <= 0.0:
		return
	hp -= amount
	if _sprite != null:
		_sprite.modulate = Color(1.8, 0.6, 0.6)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	if hp <= 0.0:
		explode(death_spell)


## Les doublures ne subissent ni zones ni statuts ennemis (§2.6.5 : rester simple).
func apply_status(_status: StringName, _data: Dictionary) -> void:
	pass


# --- Poussée par la Toupie ----------------------------------------------------

## Percutée : part droit devant (sa direction `facing`), une seule fois par doublure.
func push(dir := Vector2.ZERO) -> bool:
	if exploded or pushed:
		return false
	pushed = true
	flying = true
	if dir.length_squared() > 0.0001:
		facing = dir.normalized()
	return true


func _physics_process(delta: float) -> void:
	step(delta)


## Public pour les tests : minuteur ou vol.
func step(delta: float) -> void:
	if exploded:
		return
	if flying:
		_fly(delta)
		return
	_t += delta
	if _t >= life_s:
		explode(explode_spell)


func _fly(delta: float) -> void:
	var u := Balance.UNIT_PX
	var dist := minf(FLIGHT_SPEED_U * u * delta, FLIGHT_DIST_U * u - flown_px)
	var motion := facing * dist
	if is_inside_tree():
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, WALL_MASK)
		var col := get_world_2d().direct_space_state.intersect_ray(q)
		if not col.is_empty(): # mur : explosion contre lui, quelle que soit la distance parcourue
			global_position = (col["position"] as Vector2) - facing * 2.0
			explode(explode_spell)
			return
	global_position += motion
	flown_px += dist
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or e in _flight_hits or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		if e.get(&"active") == false:
			continue
		var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
		if e.global_position.distance_to(global_position) > RADIUS_U * u + er:
			continue
		_flight_hits.append(e)
		if caster != null and flight_spell != null:
			caster.deal_damage(e, flight_spell, {"source_pos": global_position - facing * u})
		if flown_px >= FLIGHT_ARM_U * u or e.is_in_group(&"bosses"):
			explode(explode_spell)
			return
	if flown_px >= FLIGHT_DIST_U * u - 0.01:
		explode(explode_spell)


## Explosion (zone du sort `s` au point courant, rayon × zone_size_add), puis disparition.
func explode(s: SpellData) -> void:
	if exploded:
		return
	exploded = true
	flying = false
	if caster != null and is_instance_valid(caster) and s != null:
		caster.spawn_zone(s, global_position)
	LightRig.flash(global_position, &"nova", 0.35)
	Audio.play_cast(s.id if s != null else &"", global_position, s.coef if s != null else 1.0)
	if on_explode.is_valid():
		on_explode.call(self)
	live.erase(self)
	queue_free()
