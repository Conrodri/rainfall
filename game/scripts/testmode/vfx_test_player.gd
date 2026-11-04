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
## Un effet NON bouclé (hors projectile) suivant un hôte est posé sous le PARENT de l'hôte (pas sous l'hôte) : si l'hôte
## disparaît avant la fin (racines du Cèdre : sprite d'origine libéré à 0,7 s), l'effet finit son animation sur place.
## opts.hide_with_host (effet en boucle) : hôte masqué -> effet masqué (et rendu quand l'hôte réapparaît) au lieu d'être libéré.
##
## Meta `usage` (art/briefs/vfx_test_pixelfx.md, dessin vu de dessus dans le repère logique) :
##   tile_along_line    tuile de segment_u répétée bout à bout de 0 à line_px (dernier segment mis à l'échelle) ;
##   line_from_pivot    ligne dessinée du pivot vers +x sur L u (« sur L u » de usage_note) : étirée en x à line_px ;
##   ground_oneshot, ground_zone_loop, follow_ground_loop : à plat ; opts.radius_u -> échelle rayon / rayon dessiné ;
##   follow_front, ground_dir_oneshot : à plat, tournés selon la direction ; opts.width_u -> largeur perpendiculaire
##   (sur une ligne, opts.width_u n'étire que l'épaisseur : la longueur reste line_px).
## opts de ligne : line_px (longueur gameplay), follow_line (longueur locale de l'hôte : direction et longueur relues
## sur sa transformation globale à chaque image, rayons qui tournent ; follow_axis_y : ligne le long de l'axe y local,
## follow_centered : ligne centrée sur l'hôte, l'effet part de son début). opts.fit_host_px : largeur locale de l'hôte qui
## vaut la largeur gameplay (disque de crue qui grandit ; si la meta donne un rayon dessiné, c'est le rayon qui est ajusté). opts.move_speed_u / move_range_u : déplacement propre hors
## projectile (crête de l'Éclusier le long d'un bras). opts.aspect_y : étirement vertical du corps. Projectile : longueur raccourcie par la perspective
## (échelle x locale = |(d.x, d.y × SQUASH)|), épaisseur inchangée.
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
const LINE_USAGES := ["tile_along_line", "line_from_pivot"]
const RADIUS_USAGES := ["ground_oneshot", "ground_zone_loop", "follow_ground_loop", "ground_dir_oneshot"]
## Projection par défaut d'un usage quand iso_classes.json n'en donne pas.
const USAGE_PROJECTION := {
	"tile_along_line": "ground_dir", "line_from_pivot": "ground_dir", "follow_front": "ground_dir",
	"ground_dir_oneshot": "ground_dir", "ground_oneshot": "ground", "ground_zone_loop": "ground",
	"follow_ground_loop": "ground", "projectile": "projectile",
}
const TILE_MERGE := 0.35 ## reste < 35 % d'un segment : la dernière tuile pleine s'étire au lieu d'ajouter un bout

static var _classes: Dictionary = {}
static var _classes_loaded := false
static var _re_line: RegEx = null
static var _re_radius: RegEx = null
static var _re_width: RegEx = null

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
var usage := "" ## meta usage ("" = ancien effet)
var line_px := 0.0 ## longueur affichée (usages de ligne), px logiques
var segment_px := 0.0 ## tile_along_line : longueur d'une tuile
var native_line_px := 0.0 ## line_from_pivot : longueur dessinée à l'échelle de base
var tiles: Array[AnimatedSprite2D] = [] ## tile_along_line : corps des tuiles (tiles[0] = body)
var tile_halos: Array[AnimatedSprite2D] = []
var proj_k := 1.0 ## projectile : raccourci de perspective appliqué à rot.scale.x
var detached := false ## hôte disparu : l'effet non bouclé finit sur place
var _frames_res: SpriteFrames = null
var _halo_res: SpriteFrames = null
var _off := Vector2.ZERO
var _fw := 0.0
var _hide_with_host := false
var _shown := true
var _follow_line := 0.0 ## longueur locale de la ligne de l'hôte (0 = pas de ligne suivie)
var _last_bx := Vector2.ZERO
var _fit_host_px := 0.0
var _fit_base := 1.0 ## node_scale avant l'ajustement à l'hôte
var _last_fit := -1.0
var _follow_axis_y := false
var _follow_centered := false
var _fit_note_r := 0.0 ## rayon dessiné (u, à _fit_base) : l'ajustement à l'hôte porte sur le rayon
var _aspect_y := 1.0 ## opts.aspect_y : étirement vertical du corps (ellipse d'un asset billboard ramenée au 2:1 du sol)
var _move_speed := 0.0
var _move_range := 0.0
var _moved := 0.0

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


static func _note_u(meta: Dictionary, re: RegEx) -> float:
	var m := re.search(String(meta.get("usage_note", "")))
	if m == null:
		return 0.0
	for g in range(1, m.get_group_count() + 1): # alternatives : le premier groupe capturé
		if m.get_string(g) != "":
			return float(m.get_string(g).replace(",", "."))
	return 0.0


## Longueur dessinée (u) d'un effet line_from_pivot : meta `line_u`, sinon « sur L u » de usage_note ; 0 si inconnue.
static func note_line_u(meta: Dictionary) -> float:
	if meta.has("line_u"):
		return float(meta["line_u"])
	if _re_line == null:
		_re_line = RegEx.create_from_string("sur (\\d+(?:[.,]\\d+)?) u")
	return _note_u(meta, _re_line)


## Rayon dessiné (u) d'un effet au sol : meta `radius_u`, sinon « rayon R u » / « à R u » de usage_note ; 0 si inconnu.
static func note_radius_u(meta: Dictionary) -> float:
	if meta.has("radius_u"):
		return float(meta["radius_u"])
	if _re_radius == null:
		_re_radius = RegEx.create_from_string("(?:rayon ~?|à )(\\d+(?:[.,]\\d+)?) u")
	return _note_u(meta, _re_radius)


## Largeur dessinée (u) perpendiculaire à la direction : meta `width_u`, sinon « largeur (perpendiculaire) W u » ou
## « W u de large ».
static func note_width_u(meta: Dictionary) -> float:
	if meta.has("width_u"):
		return float(meta["width_u"])
	if _re_width == null:
		_re_width = RegEx.create_from_string("largeur(?: perpendiculaire)? ~?(\\d+(?:[.,]\\d+)?) u|(\\d+(?:[.,]\\d+)?) u de large")
	return _note_u(meta, _re_width)


## Usage déclaré dans le meta de l'asset de `k` (alias résolu), "" sinon.
static func usage_of(k: String) -> String:
	return String(load_meta(String(resolve(k).get("asset_key", k))).get("usage", ""))


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
## follow (Node2D : suit cet hôte, voir l'en-tête), follow_offset (Vector2), max_s (durée maximale en mode follow),
## projection (force billboard / ground / ground_dir / projectile à la place de iso_classes.json).
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
	# effet non bouclé qui suit un hôte : posé à côté de l'hôte, il survit à sa libération et finit sur place
	if v.follow != null and parent == v.follow and not v._loop and v.projection != "projectile" and v.follow.get_parent() != null:
		parent = v.follow.get_parent()
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
	usage = String(meta.get("usage", ""))
	# opts.projection : force la projection (VfxSwap : effet posé à plat le long d'une ligne au sol -> ground_dir)
	projection = String(opts.get("projection", cls.get("projection", USAGE_PROJECTION.get(usage, "billboard"))))
	if not ["billboard", "ground", "ground_dir", "projectile"].has(projection):
		projection = "billboard"
	# effet couché au sol : sous les personnages (sinon un cône visé vers le haut de l'écran recouvre son lanceur)
	if projection in ["ground", "ground_dir"] and bool(opts.get("under", true)):
		z_index = maxi(z_index - 1, RenderingServer.CANVAS_ITEM_Z_MIN)
	particles_kind = String(cls.get("particles", "burst" if not _loop else "embers"))
	if not bool(opts.get("particles", true)):
		particles_kind = "none"
	# échelle : largeur de l'effet = frame_size.x × node_scale ; size_u fixe la largeur gameplay (u × 64 px)
	var base_scale := float(meta.get("node_scale", 1.0))
	var fs: Array = meta.get("frame_size", [])
	var fw := float(fs[0]) if fs.size() == 2 and float(fs[0]) > 0.0 else 0.0
	_fw = fw
	var size_u := float(cls.get("size_u", 0.0))
	node_scale = base_scale
	if size_u > 0.0 and fw > 0.0:
		node_scale = size_u * Balance.UNIT_PX / fw
	node_scale *= float(opts.get("scale_mult", 1.0))
	# taille gameplay connue : rayon d'une zone / onde, largeur perpendiculaire d'un front
	var want_r := float(opts.get("radius_u", 0.0))
	var note_r := note_radius_u(meta)
	if want_r > 0.0 and note_r > 0.0:
		node_scale *= want_r / note_r
	var want_w := float(opts.get("width_u", 0.0))
	var note_w := note_width_u(meta)
	var width_k := 1.0 # ligne : épaisseur seule (la longueur est line_px)
	if want_w > 0.0 and note_w > 0.0:
		width_k = want_w / note_w
		if not usage in LINE_USAGES:
			node_scale *= width_k
			width_k = 1.0
	var width_u := (fw if fw > 0.0 else 128.0) * node_scale / Balance.UNIT_PX
	_radius_u = clampf(maxf(width_u * 0.8, 1.2), 1.2, 7.0)
	var off := Vector2.ZERO
	var mo: Array = meta.get("offset", [])
	if mo.size() == 2:
		off = Vector2(float(mo[0]), float(mo[1]))
	_off = off
	_frames_res = frames
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
	set_dir(dir)
	# corps et halo
	body = _make_sprite(frames, off, node_scale, false, 1.0)
	body.name = "Body"
	rot.add_child(body)
	var halo_path := tres_path(asset_key, true)
	if bool(opts.get("halo", true)) and ResourceLoader.exists(halo_path):
		var hf := load(halo_path) as SpriteFrames
		if hf != null and hf.has_animation(&"default"):
			_halo_res = hf
			halo = _make_sprite(hf, off, node_scale, true, float(opts.get("halo_hdr", 1.6)))
			halo.name = "Halo"
			rot.add_child(halo)
	_aspect_y = float(opts.get("aspect_y", 1.0)) * width_k
	if not is_equal_approx(_aspect_y, 1.0):
		_set_body_scale(node_scale)
	# lignes : tuiles bout à bout ou ligne étirée sur la longueur gameplay
	tiles.append(body)
	if halo != null:
		tile_halos.append(halo)
	if usage == "tile_along_line":
		segment_px = float(meta.get("segment_u", float(cls.get("size_u", 2.0)))) * Balance.UNIT_PX
	if usage == "line_from_pivot":
		native_line_px = note_line_u(meta) * Balance.UNIT_PX
		if native_line_px <= 0.0: # repli : étendue de la planche devant le pivot
			native_line_px = maxf((fw * 0.5 + off.x) * node_scale, 1.0)
	_follow_line = float(opts.get("follow_line", 0.0)) if follow != null else 0.0
	_follow_axis_y = bool(opts.get("follow_axis_y", false))
	_follow_centered = bool(opts.get("follow_centered", false))
	if usage in LINE_USAGES:
		var lp := float(opts.get("line_px", 0.0))
		if lp <= 0.0:
			lp = segment_px if usage == "tile_along_line" else native_line_px
		set_line(dir, lp)
	_hide_with_host = bool(opts.get("hide_with_host", false)) and _loop
	_fit_host_px = float(opts.get("fit_host_px", 0.0)) if follow != null else 0.0
	_fit_base = node_scale
	_fit_note_r = note_radius_u(meta)
	_move_speed = float(opts.get("move_speed_u", 0.0)) * Balance.UNIT_PX
	_move_range = float(opts.get("move_range_u", 0.0)) * Balance.UNIT_PX
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
	elif _loop and _move_speed > 0.0 and projection != "projectile" and _move_range > 0.0 and not opts.has("duration"):
		_end_t = _move_range / _move_speed + 0.25 # course propre (crête le long d'un bras) puis fin
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


# --- Direction, lignes, taille -------------------------------------------------------------

## Oriente l'effet vers `d` (direction logique au sol) selon sa projection. Projectile : tourné par Iso.screen_angle et
## raccourci par la perspective (longueur × |(d.x, d.y × SQUASH)|, épaisseur inchangée), sauf meta `"round": true`
## (tête ronde, volume : braise, goutte, boule) qui garde sa taille dans toutes les directions.
func set_dir(d: Vector2) -> void:
	if d.length_squared() > 0.000001:
		dir = d.normalized()
	if rot == null:
		return
	match projection:
		"projectile":
			rot.rotation = Iso.screen_angle(dir)
			# meta `round` : tête ronde (un volume, pas un trait couché au sol) -> jamais raccourcie, sinon elle
			# devient une ellipse plate quand le tir part vers le haut ou le bas de l'écran (flèches, lames : raccourcies)
			proj_k = 1.0 if bool(meta.get("round", false)) else Iso.to_screen_dir(dir).length()
			rot.scale.x = proj_k
		"ground_dir":
			rot.rotation = dir.angle()
		"billboard":
			rot.scale.x = -1.0 if dir.x < 0.0 else 1.0


## Usages de ligne : direction `d` et longueur affichée `length` (px logiques). tile_along_line : tuiles bout à bout
## (créées seulement quand leur nombre change) ; line_from_pivot : corps étiré en x (épaisseur inchangée).
func set_line(d: Vector2, length: float) -> void:
	set_dir(d)
	line_px = maxf(length, 1.0)
	if usage == "line_from_pivot" and body != null:
		var sx := node_scale * line_px / maxf(native_line_px, 1.0)
		body.scale.x = sx
		if halo != null:
			halo.scale.x = sx
	elif usage == "tile_along_line" and body != null:
		_layout_tiles()


## Nombre de tuiles et échelle de la dernière : `line_px` couvert sans trou ni chevauchement.
static func tile_layout(length: float, seg: float) -> Vector2:
	seg = maxf(seg, 1.0)
	var full := int(floor(length / seg + 0.0001))
	var rem := length - full * seg
	if full == 0:
		return Vector2(1, length / seg)
	if rem > seg * TILE_MERGE:
		return Vector2(full + 1, rem / seg)
	return Vector2(full, (seg + rem) / seg)


func _layout_tiles() -> void:
	var lay := tile_layout(line_px, segment_px)
	var n := int(lay.x)
	while tiles.size() < n:
		var t := _make_sprite(_frames_res, _off, node_scale, false, 1.0)
		t.name = "Tile%d" % tiles.size()
		t.frame = body.frame
		rot.add_child(t)
		tiles.append(t)
		if halo != null:
			var h := _make_sprite(_halo_res, _off, node_scale, true, halo.modulate.r)
			h.name = "TileHalo%d" % tile_halos.size()
			h.frame = body.frame
			rot.add_child(h)
			tile_halos.append(h)
	while tiles.size() > n:
		tiles.pop_back().queue_free()
		if tile_halos.size() > tiles.size():
			tile_halos.pop_back().queue_free()
	var sx := segment_px / maxf(_fw, 1.0)
	for i in n:
		var k := lay.y if i == n - 1 else 1.0
		var p := Vector2(segment_px * i, 0.0)
		var s := Vector2(sx * k, node_scale * _aspect_y)
		tiles[i].position = p
		tiles[i].scale = s
		if i < tile_halos.size():
			tile_halos[i].position = p
			tile_halos[i].scale = s


func _set_body_scale(s: float) -> void:
	node_scale = s
	body.scale = Vector2(s, s * _aspect_y)
	if halo != null:
		halo.scale = body.scale


## Effet masqué avec son hôte (opts.hide_with_host) ou rendu.
func _set_shown(on: bool) -> void:
	_shown = on
	space.visible = on
	if part_space != null:
		part_space.visible = on
	if not on and light != null:
		light.set_energy(0.0)


# --- Boucle --------------------------------------------------------------------------------

func _frame_at(t: float) -> int:
	var f := int(t * _fps)
	if _loop:
		return f % _frames
	return mini(f, _frames - 1)


func _apply_frame(f: int) -> void:
	for t in tiles:
		t.frame = f
	for h in tile_halos:
		h.frame = f
	if light != null and body.visible and _shown:
		var c := 1.0
		if not _curve.is_empty():
			c = float(_curve[mini(f, _curve.size() - 1)])
		light.set_energy(c * _light_base)
		if usage in LINE_USAGES and projection != "billboard":
			light.position = dir * line_px * 0.5 # milieu de la ligne
		elif not _lpos.is_empty():
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
	if not is_instance_valid(follow) or not follow.is_inside_tree() or follow.is_queued_for_deletion():
		return _host_lost()
	if follow.is_visible_in_tree():
		_host_seen = true
		if not _shown:
			_set_shown(true)
	elif _host_seen:
		if not _hide_with_host:
			return _host_lost() # projectile rendu au pool, effet masqué par son cerveau
		if _shown:
			_set_shown(false)
	global_position = follow.global_position + follow_offset
	if _follow_line > 0.0: # ligne de l'hôte (rayon qui tourne, sillage qui s'allonge) : relue sur sa transformation
		var bx := follow.global_transform.y if _follow_axis_y else follow.global_transform.x
		if _follow_centered:
			global_position -= bx * (_follow_line * 0.5)
		if not bx.is_equal_approx(_last_bx):
			_last_bx = bx
			set_line(bx, bx.length() * _follow_line)
	if _fit_host_px > 0.0: # zone qui grandit : largeur gameplay = largeur locale de l'hôte × son échelle
		var w := _fit_host_px * absf(follow.global_scale.x)
		if absf(w - _last_fit) > 0.5:
			_last_fit = w
			if _fit_note_r > 0.0:
				_set_body_scale(_fit_base * w * 0.5 / (Balance.UNIT_PX * _fit_note_r))
			else:
				_set_body_scale(w / maxf(_fw, 1.0))
	return true


## Hôte disparu ou masqué : un effet non bouclé (hors projectile) se détache et finit son animation sur place.
func _host_lost() -> bool:
	if not _loop and projection != "projectile" and _t < _end_t:
		follow = null
		detached = true
		return true
	_finish()
	return false


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
	if _move_speed > 0.0 and follow == null and _moved < _move_range and projection != "projectile":
		var st := minf(_move_speed * delta, _move_range - _moved)
		position += dir * st
		_moved += st
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
