class_name MenuBackground
extends Node2D
## Fond animé des menus : la VRAIE carte du jeu + AmbianceManager (pluie, brume, éclairage, étalonnage
## de la carte), sans Director, joueur ni pickups. Caméra lente (3 points, aller-retour), feu de camp
## (lumière chaude + étincelles). docs/Design_Menus.md §4.
## Doit rester dans le canvas racine (pas sous un CanvasLayer) : l'UI des menus vit sur un CanvasLayer >= 10.

const MAPS_DIR := "res://scenes/stage/maps/"
const DAILY_MAPS := ["terrasses_noyees", "foret_brume", "cite_rouille"]
const U := 64.0
const AMBIANCE := "res://scenes/ambiance/ambiance_manager.tscn"
const CAMERA_ZOOM := 1.15 ## multiplicateur d'Iso.camera_zoom (vue iso 2:1 du jeu, un peu plus proche)
## Position écran visée pour le feu de camp (fraction de l'écran) : à droite du menu (colonne de gauche), un peu bas.
const SUBJECT_SCREEN := Vector2(0.66, 0.56)
const DRIFT_U := 1.6 ## amplitude de la dérive lente de la caméra autour du cadrage (u logiques)
const SEGMENT_S := 25.0
const BREATH_S := 9.0
const BREATH_PX := 8.0
const MENU_DIFFICULTY := 0.6
const FILL_ENERGY := 0.5 ## remplissage froid : sans joueur ni lanterne forte, le sol resterait sous L* 22
const FILL_COLOR := Color("#8FA6C8")
const EMBER_ENERGY := 2.8 ## multiplicateur du preset ember (0,5) : 1,4 absolu (Audit_Menus M10), le feu doit se voir sur la carte sombre
const EMBER_RADIUS_U := 9.0 ## Audit_Menus M10 : 6 -> 9 u, le sol autour du feu au-dessus de L* 22

var map_id := ""
var map: Node2D = null
var ambiance: AmbianceManager = null
var camera: Camera2D = null
var paused_visuals := false

var _points: Array[Vector2] = []
var _t := 0.0
var _campfire_pos := Vector2.ZERO
var _fire: LightRig.Handle = null
var _sparks: CPUParticles2D = null
var _halo: Sprite2D = null
var _flicker_t := 0.0
var _fill: DirectionalLight2D = null


## Carte du jour (rotation quotidienne sur 3 cartes).
static func daily_map_id() -> String:
	var day := int(Time.get_date_dict_from_system().get("day", 1))
	var month := int(Time.get_date_dict_from_system().get("month", 1))
	var doy := (month - 1) * 31 + day
	return DAILY_MAPS[doy % DAILY_MAPS.size()]


func setup(p_map_id: String) -> void:
	_teardown()
	map_id = p_map_id if ResourceLoader.exists(MAPS_DIR + p_map_id + ".tscn") else DAILY_MAPS[0]
	if ambiance == null:
		ambiance = (load(AMBIANCE) as PackedScene).instantiate() as AmbianceManager
		ambiance.auto_bind = false
		add_child(ambiance)
		ambiance.set_difficulty(MENU_DIFFICULTY, &"Calme")
	map = (load(MAPS_DIR + map_id + ".tscn") as PackedScene).instantiate() as Node2D
	map.name = "Map"
	add_child(map)
	ambiance.bind_map(map)
	ambiance.set_difficulty(MENU_DIFFICULTY, &"Calme")
	_build_camera()
	_build_fill()
	_build_campfire()
	if not Quality.quality_changed.is_connected(_on_quality):
		Quality.quality_changed.connect(_on_quality)
	_t = 0.0
	set_process(true)
	_update_camera(0.0)


func _teardown() -> void:
	_release_fire()
	if map != null:
		map.queue_free()
		map = null
	if camera != null:
		camera.queue_free()
		camera = null


func _exit_tree() -> void:
	_release_fire()
	if Quality.quality_changed.is_connected(_on_quality):
		Quality.quality_changed.disconnect(_on_quality)


func _release_fire() -> void:
	if _fire != null:
		_fire.release()
		_fire = null
	if _sparks != null:
		_sparks.queue_free()
		_sparks = null
	if _halo != null:
		_halo.queue_free()
		_halo = null


## Fige (ou relance) caméra, étincelles, pluie et brume : utile quand un écran opaque ou le chargement recouvre le fond.
func set_paused_visuals(on: bool) -> void:
	paused_visuals = on
	set_process(not on)
	if ambiance != null:
		ambiance.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
		_set_particles_speed(ambiance, 0.0 if on else 1.0)
	if _sparks != null:
		_sparks.speed_scale = 0.0 if on else 1.0


static func _set_particles_speed(n: Node, s: float) -> void:
	for c in n.get_children():
		if c is GPUParticles2D:
			(c as GPUParticles2D).speed_scale = s
		elif c is CPUParticles2D:
			(c as CPUParticles2D).speed_scale = s
		_set_particles_speed(c, s)


# --- Caméra -------------------------------------------------------------------

func _build_camera() -> void:
	var base := Vector2.ZERO
	if map is StageMap:
		base = map.to_global((map as StageMap).get_player_start())
	else:
		base = map.global_position
	var markers: Array[Vector2] = []
	for n in get_tree().get_nodes_in_group(&"menu_camera"):
		if n is Node2D and map.is_ancestor_of(n):
			markers.append((n as Node2D).global_position)
	_campfire_pos = _find_campfire(base)
	_points.clear()
	if markers.size() >= 2:
		_points.assign(markers)
	else:
		# Cadrage sur le feu de camp (sujet) : il tombe à SUBJECT_SCREEN de l'écran ; dérive lente autour.
		var c := _campfire_pos + _subject_offset()
		_points = [c, c + Vector2(-DRIFT_U, -DRIFT_U * 0.6) * U, c + Vector2(DRIFT_U, DRIFT_U * 0.6) * U]
	camera = Camera2D.new()
	camera.name = "MenuCamera"
	camera.zoom = Iso.camera_zoom(CAMERA_ZOOM) # même projection dimétrique 2:1 que le jeu (Player)
	camera.position = _points[0]
	add_child(camera)
	camera.make_current()
	if not get_viewport().size_changed.is_connected(_reframe):
		get_viewport().size_changed.connect(_reframe)


## Décalage logique caméra -> sujet pour que le sujet tombe à SUBJECT_SCREEN (zoom non uniforme iso).
func _subject_offset() -> Vector2:
	var vs := get_viewport_rect().size
	var z := Iso.camera_zoom(CAMERA_ZOOM)
	var d := Vector2((0.5 - SUBJECT_SCREEN.x) * vs.x / z.x, (0.5 - SUBJECT_SCREEN.y) * vs.y / z.y)
	return d


## Redimensionnement (PC, rotation mobile) : recalcule le cadrage sans marqueurs.
func _reframe() -> void:
	if camera == null or map == null or _points.size() != 3:
		return
	var c := _campfire_pos + _subject_offset()
	_points = [c, c + Vector2(-DRIFT_U, -DRIFT_U * 0.6) * U, c + Vector2(DRIFT_U, DRIFT_U * 0.6) * U]


## Feu de camp : marqueur `menu_campfire` de la carte, sinon le départ du joueur.
func _find_campfire(base: Vector2) -> Vector2:
	for n in get_tree().get_nodes_in_group(&"menu_campfire"):
		if n is Node2D and map.is_ancestor_of(n):
			return (n as Node2D).global_position
	return base


func _update_camera(_dt: float) -> void:
	if camera == null or _points.is_empty():
		return
	if GameSettings.reduce_motion(): # « Réduire les mouvements » : plus de dérive ni de respiration de la caméra du titre
		camera.position = _points[0]
		camera.offset = Vector2.ZERO
		return
	var n := _points.size()
	# Aller-retour : 0 → 1 → … → n-1 → … → 1 (boucle de 2(n-1) segments).
	var seg_count := maxi(2 * (n - 1), 1)
	var s := _t / SEGMENT_S
	var idx := int(floorf(s)) % seg_count
	var f: float = s - floorf(s)
	f = f * f * (3.0 - 2.0 * f) # ease in-out
	var a := idx if idx < n else seg_count - idx
	var b_raw := idx + 1
	var b := b_raw if b_raw < n else seg_count - b_raw
	camera.position = _points[a].lerp(_points[b], f)
	camera.offset = Vector2(0.0, sin(_t * TAU / BREATH_S) * BREATH_PX)


func _build_fill() -> void:
	if _fill != null:
		return
	_fill = DirectionalLight2D.new()
	_fill.name = "MenuFill"
	_fill.blend_mode = Light2D.BLEND_MODE_ADD
	_fill.color = FILL_COLOR
	_fill.energy = FILL_ENERGY
	_fill.height = 0.6
	_fill.range_z_min = LightRig.RANGE_Z_MIN
	_fill.range_z_max = LightRig.RANGE_Z_MAX
	_fill.range_item_cull_mask = LightRig.MASK_WORLD | LightRig.MASK_PUDDLES
	_fill.shadow_enabled = false
	add_child(_fill)


# --- Feu de camp ----------------------------------------------------------------

func _build_campfire() -> void:
	_release_fire()
	var low := Quality.tier == Quality.Tier.LOW
	if low:
		_halo = Sprite2D.new()
		_halo.name = "CampfireHalo"
		_halo.texture = AmbianceTextures.get_tex(&"halo_soft_256")
		_halo.global_position = _campfire_pos
		_halo.modulate = Color(1.0, 0.6, 0.25, 0.55)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_halo.material = m
		_halo.z_index = 5
		add_child(_halo)
	else:
		_fire = LightRig.attach_at(_campfire_pos, &"ember",
			{"energy": EMBER_ENERGY, "radius": EMBER_RADIUS_U / 2.5, "fade": 0.3, "priority_bonus": 500.0})
		_fire.set_flicker_override(0.1, 7.0)
		_sparks = CPUParticles2D.new()
		_sparks.name = "CampfireSparks"
		_sparks.texture = AmbianceTextures.get_tex(&"spark_16")
		_sparks.global_position = _campfire_pos
		_sparks.amount = 12
		_sparks.lifetime = 1.0
		_sparks.direction = Vector2(0, -1)
		_sparks.spread = 25.0
		_sparks.gravity = Vector2(0, -20)
		_sparks.initial_velocity_min = 30.0
		_sparks.initial_velocity_max = 70.0
		_sparks.scale_amount_min = 0.5
		_sparks.scale_amount_max = 1.0
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1.6, 1.0, 0.45, 1.0), Color(1.4, 0.45, 0.1, 0.0)])
		_sparks.color_ramp = g
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_sparks.material = mat
		_sparks.z_index = 8
		add_child(_sparks)
		_sparks.speed_scale = 0.0 if paused_visuals else 1.0


func _on_quality(_t_unused: int) -> void:
	if map != null:
		_build_campfire()


func _process(delta: float) -> void:
	_t += delta
	_update_camera(delta)
	_flicker_t += delta
	if _halo != null:
		var k := 0.9 + 0.1 * sin(_flicker_t * TAU * 7.0) * sin(_flicker_t * 2.3)
		_halo.modulate.a = 0.55 * k
