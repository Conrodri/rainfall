class_name VfxTestPlayer
extends Node2D
## Lecteur des VFX de sorts de TEST (pixelfx) en jeu, adapté à la caméra iso (docs/Design_Isometrique.md §1.6) et lumineux.
## Données : res://assets/sprites/vfx_test/<owner>/<spell>/ (corps .tres, halo _e.tres, .meta.json) + iso_classes.json.
##
##   VfxTestPlayer.spawn(parent, "ardent/brasier", pos_logique, dir_logique, {scale_mult = 1.0, duration = 3.0})
##
## Hiérarchie (champs publics lus par les tests) :
##   VfxTestPlayer (position logique du pied)
##   ├─ Space      Node2D : UNSQUASH (billboard, projectile) ; échelle 1 (ground, ground_dir : la caméra écrase)
##   │   └─ Rot    Node2D : rotation (projectile : Iso.screen_angle ; ground_dir : angle logique) ; billboard : échelle x = -1 si dir.x < 0
##   │       ├─ Body  AnimatedSprite2D (nearest)       └─ Halo  AnimatedSprite2D (additif, HDR)
##   ├─ PartSpace  Node2D : UNSQUASH, CPUParticles2D sans texture (carrés de 3 px, additifs)
##   └─ lumière : LightRig.attach (pool avec plafonds du palier Quality), au pied, suit le nœud.
## Mode `follow` (VfxSwap : vrais sorts en mode test) : opts.follow = nœud hôte. Le lecteur est top_level, suit la
## position globale de l'hôte (+ opts.follow_offset), n'a aucun déplacement propre (même en projection projectile),
## boucle tant que l'hôte vit et se libère quand l'hôte sort de l'arbre ou est masqué après avoir été visible.
## À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

const ROOT := "res://assets/sprites/vfx_test/"
const CLASSES_PATH := ROOT + "iso_classes.json"
const LIGHT_PRESET := &"spell_physical" ## rayon 2,5 u, énergie 1,2, catégorie « spell » (plafond Quality.light_caps)
const PRESET_RADIUS_U := 2.5
const PRESET_ENERGY := 1.2
const PROJ_SPEED_U := 8.0
const PROJ_RANGE_U := 8.0
const DEFAULT_LOOP_S := 3.0
const TAIL_S := 0.9 ## délai laissé aux particules après la fin de l'animation
const PARTICLE_PX := 3.0

static var _classes: Dictionary = {}
static var _classes_loaded := false

var key := ""
var projection := "billboard"
var particles_kind := "none"
var space: Node2D
var rot: Node2D
var body: AnimatedSprite2D
var halo: AnimatedSprite2D
var part_space: Node2D
var particles: CPUParticles2D
var light: LightRig.Handle
var meta: Dictionary = {}
var node_scale := 1.0 ## échelle finale du corps (scale_mult compris)
var dir := Vector2.RIGHT
var finished_flag := false

var _fps := 12.0
var _frames := 1
var _loop := false
var _curve: Array = []
var _lpos: Array = []
var _light_base := 1.0
var _light_x_dir := Vector2.RIGHT
var _t := 0.0
var _end_t := DEFAULT_LOOP_S
var _peak_frame := 0
var _burst_done := false
var _speed_px := 0.0
var _traveled := 0.0
var _range_px := 0.0
var _radius_u := 2.5
var _light_on := true
var _center_billboard := Vector2.ZERO
var follow: Node2D = null ## hôte suivi (mode follow), null sinon
var follow_offset := Vector2.ZERO
var _host_seen := false ## l'hôte a été visible au moins une fois (masqué ensuite = fin)

signal finished(player: VfxTestPlayer)


# --- Données ---------------------------------------------------------------------------

static func reload_classes() -> void:
	_classes_loaded = false
	_classes = {}


static func classes() -> Dictionary:
	if not _classes_loaded:
		_classes_loaded = true
		_classes = {}
		if FileAccess.file_exists(CLASSES_PATH):
			var data = JSON.parse_string(FileAccess.get_file_as_string(CLASSES_PATH))
			if typeof(data) == TYPE_DICTIONARY:
				var d: Dictionary = data
				_classes = d.get("classes", d) if typeof(d.get("classes", null)) == TYPE_DICTIONARY else d
	return _classes


## Entrée de classe fusionnée avec celle de l'alias ; `asset_key` = clé des fichiers à charger.
static func resolve(k: String) -> Dictionary:
	var entry: Dictionary = {}
	var raw = classes().get(k, {})
	if typeof(raw) == TYPE_DICTIONARY:
		entry = (raw as Dictionary).duplicate()
	var asset_key := k
	var alias := String(entry.get("alias", ""))
	if alias != "" and alias != k:
		asset_key = alias
		var base = classes().get(alias, {})
		if typeof(base) == TYPE_DICTIONARY:
			var merged: Dictionary = (base as Dictionary).duplicate()
			for f in entry:
				if f != "alias":
					merged[f] = entry[f]
			entry = merged
	entry["asset_key"] = asset_key
	return entry


static func tres_path(k: String, emission := false) -> String:
	var parts := k.split("/")
	if parts.size() != 2:
		return ""
	return "%s%s/%s/%s%s.tres" % [ROOT, parts[0], parts[1], parts[1], "_e" if emission else ""]


static func meta_path(k: String) -> String:
	var parts := k.split("/")
	if parts.size() != 2:
		return ""
	return "%s%s/%s/%s.meta.json" % [ROOT, parts[0], parts[1], parts[1]]


static func load_meta(k: String) -> Dictionary:
	var p := meta_path(k)
	if p == "" or not FileAccess.file_exists(p):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(p))
	return data if typeof(data) == TYPE_DICTIONARY else {}


## true si les images du corps existent (tolère un lot en cours de régénération).
static func available(k: String) -> bool:
	var p := tres_path(String(resolve(k).get("asset_key", k)))
	return p != "" and ResourceLoader.exists(p)


## {owner: [spell_id, ...]} trié ; sorts dont le .tres existe. Alias inclus s'ils sont listés dans iso_classes.json.
static func catalog() -> Dictionary:
	var out: Dictionary = {}
	var owners: Array[String] = []
	var da := DirAccess.open(ROOT)
	if da != null:
		for d in da.get_directories():
			owners.append(d)
	owners.sort()
	for o in owners:
		var sd := DirAccess.open(ROOT + o)
		if sd == null:
			continue
		var spells: Array[String] = []
		for s in sd.get_directories():
			if ResourceLoader.exists("%s%s/%s/%s.tres" % [ROOT, o, s, s]):
				spells.append(s)
		for ck in classes():
			var parts := String(ck).split("/")
			if parts.size() == 2 and parts[0] == o and not spells.has(parts[1]) and available(String(ck)):
				spells.append(parts[1])
		spells.sort()
		if not spells.is_empty():
			out[o] = spells
	return out


# --- Création ----------------------------------------------------------------------------

## opts : scale_mult (1), duration (3, effets en boucle), halo (true), halo_hdr (1,6), light (true), light_energy (1),
## particles (true), speed_u (8), range_u (8), always (true : tourne aussi quand l'arbre est en pause), z (10),
## follow (Node2D : suit cet hôte, voir l'en-tête), follow_offset (Vector2), max_s (durée maximale en mode follow).
## Retourne null si les images du corps manquent.
static func spawn(parent: Node, key: String, logical_pos: Vector2, dir_logical: Vector2, opts := {}) -> Node2D:
	var cls := resolve(key)
	var asset_key := String(cls.get("asset_key", key))
	var frames_path := tres_path(asset_key)
	if frames_path == "" or not ResourceLoader.exists(frames_path):
		return null
	var frames := load(frames_path) as SpriteFrames
	if frames == null or not frames.has_animation(&"default") or frames.get_frame_count(&"default") < 1:
		return null
	var v := VfxTestPlayer.new()
	v.name = "Vfx_%s" % key.replace("/", "_")
	v._setup(key, asset_key, cls, frames, logical_pos, dir_logical, opts)
	if parent != null:
		parent.add_child(v)
	return v


func _setup(k: String, asset_key: String, cls: Dictionary, frames: SpriteFrames, pos: Vector2, d: Vector2, opts: Dictionary) -> void:
	key = k
	meta = load_meta(asset_key)
	dir = d.normalized() if d.length() > 0.001 else Vector2.RIGHT
	position = pos
	z_index = int(opts.get("z", 10))
	light_mask = 0
	if bool(opts.get("always", true)):
		process_mode = Node.PROCESS_MODE_ALWAYS
	var fol: Variant = opts.get("follow", null)
	if fol is Node2D and is_instance_valid(fol):
		follow = fol
		follow_offset = opts.get("follow_offset", Vector2.ZERO)
		top_level = true # ni l'échelle, ni la rotation de l'hôte : position globale seule
		z_as_relative = false
		z_index = clampi(_abs_z(follow) + int(opts.get("z", 0)), RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)
		position = follow.global_position + follow_offset
	_frames = frames.get_frame_count(&"default")
	_fps = float(meta.get("fps", frames.get_animation_speed(&"default")))
	if _fps <= 0.0:
		_fps = 12.0
	_loop = bool(meta.get("loop", frames.get_animation_loop(&"default")))
	_curve = meta.get("light_curve", [])
	_lpos = meta.get("light_pos", [])
	projection = String(cls.get("projection", "billboard"))
	if not ["billboard", "ground", "ground_dir", "projectile"].has(projection):
		projection = "billboard"
	particles_kind = String(cls.get("particles", "burst" if not _loop else "embers"))
	if not bool(opts.get("particles", true)):
		particles_kind = "none"
	# échelle : largeur de l'effet = frame_size.x × node_scale ; size_u fixe la largeur gameplay (u × 64 px)
	var base_scale := float(meta.get("node_scale", 1.0))
	var fs: Array = meta.get("frame_size", [])
	var fw := float(fs[0]) if fs.size() == 2 and float(fs[0]) > 0.0 else 0.0
	var size_u := float(cls.get("size_u", 0.0))
	node_scale = base_scale
	if size_u > 0.0 and fw > 0.0:
		node_scale = size_u * Balance.UNIT_PX / fw
	node_scale *= float(opts.get("scale_mult", 1.0))
	var width_u := (fw if fw > 0.0 else 128.0) * node_scale / Balance.UNIT_PX
	_radius_u = clampf(maxf(width_u * 0.8, 1.2), 1.2, 7.0)
	var off := Vector2.ZERO
	var mo: Array = meta.get("offset", [])
	if mo.size() == 2:
		off = Vector2(float(mo[0]), float(mo[1]))
	# repères
	space = Node2D.new()
	space.name = "Space"
	space.light_mask = 0
	if projection == "billboard" or projection == "projectile":
		space.scale = Iso.UNSQUASH
	add_child(space)
	rot = Node2D.new()
	rot.name = "Rot"
	rot.light_mask = 0
	space.add_child(rot)
	match projection:
		"projectile":
			rot.rotation = Iso.screen_angle(dir)
		"ground_dir":
			rot.rotation = dir.angle()
		"billboard":
			if dir.x < 0.0:
				rot.scale.x = -1.0
	# corps et halo
	body = _make_sprite(frames, off, node_scale, false, 1.0)
	body.name = "Body"
	rot.add_child(body)
	var halo_path := tres_path(asset_key, true)
	if bool(opts.get("halo", true)) and ResourceLoader.exists(halo_path):
		var hf := load(halo_path) as SpriteFrames
		if hf != null and hf.has_animation(&"default"):
			halo = _make_sprite(hf, off, node_scale, true, float(opts.get("halo_hdr", 1.6)))
			halo.name = "Halo"
			rot.add_child(halo)
	# durée
	var anim_s := float(_frames) / _fps
	_end_t = anim_s + TAIL_S
	if _loop:
		_end_t = float(opts.get("duration", DEFAULT_LOOP_S))
	if projection == "projectile":
		_speed_px = float(opts.get("speed_u", PROJ_SPEED_U)) * Balance.UNIT_PX
		_range_px = float(opts.get("range_u", PROJ_RANGE_U)) * Balance.UNIT_PX
		_end_t = _range_px / maxf(_speed_px, 1.0) + 0.3
	if follow != null:
		_speed_px = 0.0 # l'hôte porte le mouvement
		_range_px = INF
		if _loop or projection == "projectile":
			_end_t = INF # vit autant que l'hôte
		if opts.has("max_s"):
			_end_t = minf(_end_t, float(opts["max_s"]))
	_peak_frame = 0
	var best := -1.0
	for i in _curve.size():
		if float(_curve[i]) > best:
			best = float(_curve[i])
			_peak_frame = i
	if _curve.is_empty():
		_peak_frame = int(_frames / 3)
	# centre visuel de l'effet (espace billboard) : le pivot pixelfx est le pied, `offset` place le centre de la planche
	_center_billboard = off * node_scale if projection == "billboard" else Vector2.ZERO
	# particules
	if particles_kind != "none":
		_make_particles(cls, opts)
	# lumière
	_light_on = bool(opts.get("light", true))
	if _light_on:
		_light_base = float(opts.get("light_energy", 1.0))
		_attach_light()
	_apply_frame(0)


func _make_sprite(frames: SpriteFrames, off: Vector2, s: float, additive: bool, hdr: float) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.animation = &"default"
	a.centered = true
	a.offset = off
	a.scale = Vector2(s, s)
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.light_mask = 0
	a.speed_scale = 0.0 # image pilotée à la main : corps et halo restent synchronisés
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		a.material = m
		a.modulate = Color(hdr, hdr, hdr, 1.0)
	return a


func _accent() -> Color:
	return Color.from_string(String(meta.get("light_color", "#FFFFFF")), Color.WHITE)


func _attach_light() -> void:
	var offs := Vector2.ZERO
	light = LightRig.attach(self, LIGHT_PRESET, {
		"energy": 0.0,
		"radius": _radius_u / PRESET_RADIUS_U,
		"color": _accent(),
		"offset": offs,
		"fade": 0.04,
	})


func _particle_cap() -> int:
	var m := int(Quality.get_setting(&"ambient_particles_max")) if Quality != null else 500
	return 10 if m <= 150 else (18 if m <= 500 else 26)


func _make_particles(cls: Dictionary, opts: Dictionary) -> void:
	part_space = Node2D.new()
	part_space.name = "PartSpace"
	part_space.scale = Iso.UNSQUASH
	part_space.light_mask = 0
	add_child(part_space)
	var p := CPUParticles2D.new()
	p.name = "Particles"
	p.light_mask = 0
	p.texture = null
	p.local_coords = false
	p.draw_order = CPUParticles2D.DRAW_ORDER_INDEX
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.modulate = Color(1.5, 1.5, 1.5, 1.0) # HDR : accroche la lueur 2D
	var acc := _accent()
	var g := Gradient.new()
	g.set_color(0, acc.lightened(0.45))
	g.set_offset(0, 0.0)
	g.set_color(1, Color(acc.r, acc.g, acc.b, 0.0))
	g.set_offset(1, 1.0)
	g.add_point(0.4, acc)
	p.color_ramp = g
	p.scale_amount_min = PARTICLE_PX
	p.scale_amount_max = PARTICLE_PX
	p.angular_velocity_min = 0.0
	p.angular_velocity_max = 0.0
	var cap := _particle_cap()
	var half_w := _radius_u * Balance.UNIT_PX * 0.5
	match particles_kind:
		"trail":
			p.amount = cap
			p.lifetime = 0.55
			p.direction = Vector2.UP
			p.spread = 180.0
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 36.0
			p.gravity = Vector2(0, -30)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = clampf(half_w * 0.15, 3.0, 14.0)
			p.emitting = true
		"embers":
			p.amount = cap
			p.lifetime = 1.3
			p.direction = Vector2.UP
			p.spread = 28.0
			p.initial_velocity_min = 22.0
			p.initial_velocity_max = 60.0
			p.gravity = Vector2(0, -12)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = maxf(half_w * 0.6, 8.0)
			p.emitting = true
		_: # burst : une gerbe au pic de la courbe de lumière
			p.amount = cap
			p.lifetime = 0.8
			p.one_shot = true
			p.explosiveness = 1.0
			p.direction = Vector2.UP
			p.spread = 180.0
			p.initial_velocity_min = 50.0
			p.initial_velocity_max = 150.0
			p.damping_min = 40.0
			p.damping_max = 90.0
			p.gravity = Vector2(0, 160)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = clampf(half_w * 0.25, 4.0, 24.0)
			p.emitting = false
	p.position = _center_billboard * (0.6 if particles_kind != "trail" else 0.0)
	part_space.add_child(p)
	particles = p


# --- Boucle --------------------------------------------------------------------------------

func _frame_at(t: float) -> int:
	var f := int(t * _fps)
	if _loop:
		return f % _frames
	return mini(f, _frames - 1)


func _apply_frame(f: int) -> void:
	body.frame = f
	if halo != null:
		halo.frame = f
	if light != null and body.visible:
		var c := 1.0
		if not _curve.is_empty():
			c = float(_curve[mini(f, _curve.size() - 1)])
		light.set_energy(c * _light_base)
		if not _lpos.is_empty():
			var lp: Array = _lpos[mini(f, _lpos.size() - 1)]
			var lx := float(lp[0]) * node_scale if lp.size() >= 2 else 0.0
			if projection == "billboard":
				lx *= -1.0 if rot.scale.x < 0.0 else 1.0
				light.position = Vector2(lx, 0.0)
			elif projection == "ground_dir":
				light.position = dir * lx
			else:
				light.position = Vector2.ZERO


## z absolu d'un CanvasItem (somme des z relatifs des ancêtres).
static func _abs_z(n: Node) -> int:
	var z := 0
	while n != null:
		if n is CanvasItem:
			z += (n as CanvasItem).z_index
			if not (n as CanvasItem).z_as_relative:
				break
		n = n.get_parent()
	return z


## Mode follow : recale sur l'hôte ; faux (et fin) si l'hôte n'est plus là ou a été masqué.
func _track_host() -> bool:
	if not is_instance_valid(follow) or not follow.is_inside_tree():
		_finish()
		return false
	if follow.is_visible_in_tree():
		_host_seen = true
	elif _host_seen:
		_finish() # projectile rendu au pool, effet masqué par son cerveau
		return false
	global_position = follow.global_position + follow_offset
	return true


func _ready() -> void:
	if follow != null:
		_track_host()


func _process(delta: float) -> void:
	if finished_flag:
		return
	if follow != null and not _track_host():
		return
	_t += delta
	_apply_frame(_frame_at(_t))
	if projection == "projectile" and follow == null:
		var step := _speed_px * delta
		position += dir * step
		_traveled += step
		if _traveled >= _range_px and body.visible:
			body.visible = false
			if halo != null:
				halo.visible = false
			if particles != null:
				particles.emitting = false
			if light != null:
				light.set_energy(0.0)
	if particles != null and particles_kind == "burst" and not _burst_done and _frame_at(_t) >= _peak_frame:
		_burst_done = true
		particles.restart()
		particles.emitting = true
	if not _loop and _t >= float(_frames) / _fps and projection != "projectile":
		if body.visible:
			body.visible = false # animation finie : plus d'image, restent les particules
			if halo != null:
				halo.visible = false
			if light != null:
				light.set_energy(0.0)
	elif _loop and particles != null and _t >= _end_t - 0.6:
		particles.emitting = false # laisse les dernières braises s'éteindre
	if _t >= _end_t:
		_finish()


func _finish() -> void:
	if finished_flag:
		return
	finished_flag = true
	if light != null:
		LightRig.detach(light)
		light = null
	finished.emit(self)
	queue_free()


## Arrêt immédiat (galerie : changement d'effet).
func stop() -> void:
	_finish()
