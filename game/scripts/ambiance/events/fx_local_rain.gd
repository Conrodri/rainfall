extends AmbientEffect
## Pluie LOCALE (Ossuaire des pluies, « Pluie du puits ») : la pluie de la ville tombe par le puits de lumière sur la
## margelle `prop` (props_fixed `well_rim`), dans un cylindre de rayon `radius_u` : gouttes (texture Codex `drop_32`,
## celle de la pluie globale) lâchées `height_u` au-dessus de la margelle, éclaboussures au sol (`splash_8x64`, Moyen
## et Haut), boucle de pluie spatialisée sur la margelle (son `loop_sound`, déjà livré). Rien en dehors de la zone :
## tests/ambient_events_test vérifie les bornes. Fondu d'entrée `fade_s`. Aucun effet de jeu.
## Coût : deux émetteurs GPU (repli CPU en Compatibilité) créés à start() et libérés à stop() ; quantités par
## palier `drops` [Bas, Moyen, Haut] et `splashes`.
## Paramètres : "prop" ("well_rim"), "radius_u" (1,6), "height_u" (7), "drops" [24, 48, 96], "splashes" [0, 8, 16]
## (par seconde), "fade_s" (4), "loop_sound" ("amb.rain.light"), "loop_db" (-8).

const DROP_TEX := &"drop_32"
const SPLASH_TEX := &"splash_8x64"
const FALL_S := 0.6

var anchor: Node2D = null ## margelle (Sprite2D du prop fixe)
var drops: Node2D = null
var splashes: Node2D = null
var root: Node2D = null ## conteneur posé sur la margelle (espace billboard : UNSQUASH)
var _ratio := 0.0
var _loop := {}


func setup() -> void:
	if fixed_props(String(def.get("prop", "well_rim"))).is_empty():
		note_missing("props_fixed « %s » absent de la carte ou texture non livrée" % String(def.get("prop", "well_rim")))
	if not AmbianceTextures.is_real(DROP_TEX):
		note_missing("texture d'ambiance %s" % DROP_TEX)


func radius_px() -> float:
	return float(def.get("radius_u", 1.6)) * U


func height_px() -> float:
	return float(def.get("height_u", 7.0)) * U


func start() -> void:
	_ratio = 0.0
	var list := fixed_props(String(def.get("prop", "well_rim")))
	anchor = list[0] if not list.is_empty() else null
	_build()


func _build() -> void:
	_free_nodes()
	if anchor == null or not is_instance_valid(anchor):
		return
	root = Node2D.new()
	root.name = "LocalRain"
	# espace billboard : 1 px local = 1 px à l'écran (la caméra iso écrase y de moitié)
	root.scale = Iso.UNSQUASH
	mgr.events.add_child(root)
	root.global_position = anchor.global_position
	var r := radius_px()
	var nd := int(per_tier(def.get("drops", [24, 48, 96])))
	if nd > 0 and AmbianceTextures.is_real(DROP_TEX):
		var tex := AmbianceTextures.get_tex(DROP_TEX)
		var h := height_px()
		var g := _particles("Drops", nd, FALL_S, tex)
		var pm := g.process_material as ParticleProcessMaterial
		# lâcher au-dessus de la margelle : disque au sol vu en iso = ellipse (r, r/2) ; la hauteur de chute est
		# verticale à l'écran, la profondeur du disque passe par l'étalement vertical de l'émetteur
		g.position = Vector2(0.0, -h)
		pm.emission_box_extents = Vector3(r * 0.85, r * 0.42, 1.0)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 1.5
		pm.initial_velocity_min = h / FALL_S * 0.95
		pm.initial_velocity_max = h / FALL_S * 1.05
		pm.particle_flag_align_y = true
		var s := 0.14 * U / maxf(float(tex.get_width()), 1.0) # un peu plus marquées que la pluie globale : on lit la colonne
		pm.scale_min = s
		pm.scale_max = s * 1.7
		pm.color = Color(0.86, 0.93, 1.0, 0.62)
		g.visibility_rect = Rect2(-r, -h * 0.1, r * 2.0, h * 1.1 + r)
		drops = AmbianceWeather.finalize_particles(g)
		drops.z_index = AmbianceWeather.Z_RAIN
		root.add_child(drops)
	var ns := per_tier(def.get("splashes", [0, 8, 16]))
	if ns > 0.0 and AmbianceTextures.is_real(SPLASH_TEX):
		var tex2 := AmbianceTextures.get_tex(SPLASH_TEX)
		var life := 0.25
		var g2 := _particles("Splashes", maxi(int(ceil(ns * life)), 1), life, tex2)
		var pm2 := g2.process_material as ParticleProcessMaterial
		pm2.emission_box_extents = Vector3(r * 0.85, r * 0.42, 1.0)
		pm2.initial_velocity_min = 0.0
		pm2.initial_velocity_max = 0.0
		pm2.anim_speed_min = 1.0
		pm2.anim_speed_max = 1.0
		var frames := AmbianceTextures.frame_count(tex2)
		var s2 := 0.25 * U / maxf(float(tex2.get_width()) / float(frames), 1.0)
		pm2.scale_min = s2 * 0.7
		pm2.scale_max = s2 * 1.1
		pm2.color = Color(1, 1, 1, 0.5)
		var m := g2.material as CanvasItemMaterial
		if frames > 1:
			m.particles_animation = true
			m.particles_anim_h_frames = frames
			m.particles_anim_v_frames = 1
			m.particles_anim_loop = false
		g2.visibility_rect = Rect2(-r, -r, r * 2.0, r * 2.0)
		splashes = AmbianceWeather.finalize_particles(g2)
		splashes.z_index = -12 # au sol, sous les entités (comme les éclaboussures globales)
		root.add_child(splashes)
	_apply_ratio()
	var a := audio()
	if a != null and drops != null:
		var res: Variant = a.call(&"play_loop", StringName(def.get("loop_sound", "amb.rain.light")), root, float(def.get("loop_db", -8.0)))
		_loop = res if res is Dictionary else {}


func _particles(nm: String, amount: int, life: float, tex: Texture2D) -> GPUParticles2D:
	var g := GPUParticles2D.new()
	g.name = nm
	g.amount = maxi(amount, 1)
	g.lifetime = life
	g.local_coords = true # émetteur fixe : repère local (billboard UNSQUASH) appliqué aux positions et au dessin
	g.texture = tex
	g.preprocess = life
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.gravity = Vector3.ZERO
	pm.spread = 0.0
	g.process_material = pm
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	g.material = m
	return g


func _apply_ratio() -> void:
	AmbianceWeather.set_ratio(drops, _ratio)
	AmbianceWeather.set_ratio(splashes, _ratio)


func process(delta: float) -> void:
	if root == null:
		return
	if anchor == null or not is_instance_valid(anchor):
		_free_nodes()
		return
	if _ratio < 1.0:
		_ratio = minf(_ratio + delta / maxf(float(def.get("fade_s", 4.0)), 0.01), 1.0)
		_apply_ratio()


func on_quality() -> void:
	var keep := _ratio
	_build()
	_ratio = keep
	_apply_ratio()


## Ambiance reconstruite (palier de qualité) : émetteurs refaits aux nouvelles quantités, fondu gardé.
func refresh() -> void:
	on_quality()


## Zone couverte, en repère logique global : rectangle des émetteurs (gouttes et éclaboussures), hauteur de chute
## comprise (tests : pluie bornée au puits).
func bounds() -> Rect2:
	if root == null or not is_instance_valid(root):
		return Rect2()
	var out := Rect2()
	var first := true
	for n in [drops, splashes]:
		if n == null:
			continue
		var ext := Vector2.ZERO
		if n is GPUParticles2D:
			var e3 := ((n as GPUParticles2D).process_material as ParticleProcessMaterial).emission_box_extents
			ext = Vector2(e3.x, e3.y)
		elif n is CPUParticles2D:
			ext = (n as CPUParticles2D).emission_rect_extents
		var c := (n as Node2D).position
		var loc := Rect2(c - ext, ext * 2.0)
		if n == drops: # trajet de chute jusqu'au sol de la margelle
			loc = loc.merge(Rect2(Vector2(c.x - ext.x, 0.0) - Vector2(0.0, ext.y), ext * 2.0))
		var xf := root.global_transform
		var g := Rect2(xf * loc.position, Vector2.ZERO).expand(xf * loc.end)
		out = g if first else out.merge(g)
		first = false
	return out


func drop_count() -> int:
	if drops is GPUParticles2D:
		return (drops as GPUParticles2D).amount
	if drops is CPUParticles2D:
		return (drops as CPUParticles2D).amount
	return 0


func _free_nodes() -> void:
	var a := audio()
	if a != null and not _loop.is_empty():
		a.call(&"stop_loop", _loop)
	_loop = {}
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = null
	drops = null
	splashes = null


func stop() -> void:
	_free_nodes()
	anchor = null
	_ratio = 0.0


func describe() -> Dictionary:
	var d := super.describe()
	d["drops"] = drop_count()
	d["splashes"] = splashes != null
	d["anchor"] = anchor != null
	return d
