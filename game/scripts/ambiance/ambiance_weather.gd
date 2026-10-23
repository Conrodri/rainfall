class_name AmbianceWeather
extends Node2D
## Pluie et particules d'ambiance (World, au-dessus des entités, non éclairées). Direction §2, §5.
## - calque de pluie : shader `rain_sheet` sur un rectangle qui suit la caméra (ancré au monde) ;
## - gouttes individuelles (Haut) et éclaboussures au sol : GPUParticles2D (repli CPUParticles2D
##   si le moteur tourne en Compatibilité, ex. vieil Android sans Vulkan) ;
## - jusqu'à 3 systèmes d'ambiance par carte (feuilles, lucioles, spores, cendres).
## Une texture Blender absente coupe proprement le système concerné (aucun dessin en code).

const U := 64.0
const Z_RAIN := 30 ## §1.3
const Z_AMBIENT := 25
const VIEW_MARGIN := 256.0
const RAIN_SHADER := preload("res://shaders/rain_sheet.gdshader")

var rain_rect: ColorRect
var drops: Node2D = null ## GPUParticles2D ou CPUParticles2D
var splashes: Node2D = null
var ambient: Array = [] ## [{node, def, slot, max}]

var _rain_mat: ShaderMaterial
var _fall_px := 0.0
var _gust_t := 0.0
var _view := Rect2()
var _defs: Array = []


func _ready() -> void:
	z_index = Z_RAIN
	rain_rect = ColorRect.new()
	rain_rect.name = "RainSheet"
	rain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = RAIN_SHADER
	rain_rect.material = _rain_mat
	add_child(rain_rect)


static func use_cpu_particles() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Convertit en CPUParticles2D si nécessaire (Compatibilité) ; retourne le nœud à ajouter.
static func finalize_particles(gpu: GPUParticles2D) -> Node2D:
	if not use_cpu_particles():
		return gpu
	var cpu := CPUParticles2D.new()
	cpu.convert_from_particles(gpu)
	cpu.name = gpu.name
	cpu.z_index = gpu.z_index
	cpu.material = gpu.material
	gpu.free()
	return cpu


static func set_ratio(p: Node2D, ratio: float) -> void:
	if p == null:
		return
	ratio = clampf(ratio, 0.0, 1.0)
	if "amount_ratio" in p:
		p.set("amount_ratio", ratio)
	p.set("emitting", ratio > 0.001)


## Reconstruit les systèmes d'une carte (structure du profil + palier de qualité).
func setup(profile: AmbianceProfile) -> void:
	_defs = profile.particle_defs if profile != null else []
	_rebuild()


func on_quality() -> void:
	_rebuild()


func _rebuild() -> void:
	for n in [drops, splashes]:
		if n != null:
			n.queue_free()
	drops = null
	splashes = null
	for a in ambient:
		(a["node"] as Node).queue_free()
	ambient.clear()
	var has_sheet := AmbianceTextures.is_real(&"rain_sheet_512")
	rain_rect.visible = has_sheet
	if has_sheet:
		_rain_mat.set_shader_parameter(&"sheet", AmbianceTextures.get_tex(&"rain_sheet_512"))
	if bool(Quality.get_setting(&"rain_drops")) and AmbianceTextures.is_real(&"drop_32"):
		drops = _make_drops()
		add_child(drops)
	if AmbianceTextures.is_real(&"splash_8x64") and float(Quality.get_setting(&"splash_max")) > 0.0:
		splashes = _make_splashes(float(Quality.get_setting(&"splash_max")))
		splashes.z_index = -Z_RAIN - 12 # éclaboussures au sol : sous les entités (z -12 absolu)
		add_child(splashes)
	var cap := int(Quality.get_setting(&"ambient_particles_max"))
	for i in mini(_defs.size(), 3):
		var def: Dictionary = _defs[i]
		var tex_id := StringName(def.get("texture", &""))
		if not AmbianceTextures.is_real(tex_id):
			continue
		var mx := maxi(int(cap / maxi(_defs.size(), 1)), 1)
		var node := _make_ambient(def, AmbianceTextures.get_tex(tex_id), mx)
		node.z_index = Z_AMBIENT - Z_RAIN
		add_child(node)
		ambient.append({"node": node, "def": def, "slot": i, "max": mx})


## Mise à jour par image : rectangle de vue (monde), paramètres lissés, delta.
func update_weather(view: Rect2, p: Dictionary, delta: float) -> void:
	_view = view
	var r := view.grow(VIEW_MARGIN)
	rain_rect.position = r.position - global_position
	rain_rect.size = r.size
	var intensity := clampf(float(p[&"rain_intensity"]) * float(Quality.get_setting(&"rain_density_mult")), 0.0, 1.0)
	var gust := 1.0
	if bool(Quality.get_setting(&"rain_gusts")) and float(p[&"rain_gusts"]) > 0.0:
		_gust_t += delta
		gust = 1.0 + float(p[&"rain_gusts"]) * (sin(_gust_t * TAU / 4.5) * 0.6 + sin(_gust_t * TAU / 2.9 + 1.3) * 0.4)
	var speed := float(p[&"rain_speed_u"]) * U
	_fall_px += speed * delta
	if _fall_px > 1.0e6:
		_fall_px = fmod(_fall_px, 512.0 * 64.0)
	var angle := deg_to_rad(float(p[&"rain_angle_deg"]))
	_rain_mat.set_shader_parameter(&"opacity", float(p[&"rain_opacity"]) * clampf(gust, 0.3, 1.6))
	_rain_mat.set_shader_parameter(&"density", clampf(intensity * gust, 0.0, 1.0))
	_rain_mat.set_shader_parameter(&"layers", mini(roundi(float(p[&"rain_layers"])), int(Quality.get_setting(&"rain_layers"))))
	_rain_mat.set_shader_parameter(&"angle", angle)
	_rain_mat.set_shader_parameter(&"fall_px", _fall_px)
	_rain_mat.set_shader_parameter(&"length_scale", float(p[&"rain_length_u"]) / 0.35)
	_rain_mat.set_shader_parameter(&"tint", p[&"rain_tint"])
	var center := view.get_center() - global_position
	var dir := Vector2(sin(angle), cos(angle))
	if drops != null:
		# émission sur toute la vue (+ marge) : une ligne au-dessus de l'écran ne couvrait que
		# le haut (trajet d'une goutte ≈ 0,6 s × 6-9 u/s ≈ 4-5 u, bien moins que la hauteur de vue)
		drops.position = center - dir * U * 2.0
		_set_box(drops, view.size * 0.5 + Vector2(VIEW_MARGIN, VIEW_MARGIN))
		set_ratio(drops, float(p[&"drops_amount"]) / float(drops.get_meta(&"max", 1.0)) * gust)
		_set_dir(drops, dir)
	if splashes != null:
		splashes.position = center
		_set_box(splashes, view.size * 0.5)
		var rate := minf(float(p[&"splash_rate"]) * gust, float(Quality.get_setting(&"splash_max")))
		set_ratio(splashes, rate / float(splashes.get_meta(&"max_rate", 1.0)))
	for a in ambient:
		var node: Node2D = a["node"]
		node.position = center
		_set_box(node, view.size * 0.5 + Vector2(VIEW_MARGIN, VIEW_MARGIN))
		var amount := float(p[[&"p1_amount", &"p2_amount", &"p3_amount"][int(a["slot"])]])
		set_ratio(node, amount / float(a["max"]))
		var def: Dictionary = a["def"]
		if StringName(def.get("behavior", &"")) == &"wind":
			var sp := float(def.get("speed_u", 1.0)) * U * float(p[&"wind_mult"])
			_set_dir(node, Vector2.from_angle(deg_to_rad(200.0))) # vent de la carte 3 : 200-230°
			_set_vel(node, sp * 0.8, sp * 1.2)


## Nombre de particules d'ambiance max configurées (tests de budget).
func ambient_capacity() -> int:
	var n := 0
	for a in ambient:
		n += int(a["max"])
	return n


func _set_dir(n: Node2D, d: Vector2) -> void:
	if n is GPUParticles2D:
		((n as GPUParticles2D).process_material as ParticleProcessMaterial).direction = Vector3(d.x, d.y, 0.0)
	elif n is CPUParticles2D:
		(n as CPUParticles2D).direction = d


func _set_vel(n: Node2D, vmin: float, vmax: float) -> void:
	if n is GPUParticles2D:
		var pm := (n as GPUParticles2D).process_material as ParticleProcessMaterial
		pm.initial_velocity_min = vmin
		pm.initial_velocity_max = vmax
	elif n is CPUParticles2D:
		(n as CPUParticles2D).initial_velocity_min = vmin
		(n as CPUParticles2D).initial_velocity_max = vmax


func _set_box(n: Node2D, half: Vector2) -> void:
	if n is GPUParticles2D:
		var pm := (n as GPUParticles2D).process_material as ParticleProcessMaterial
		pm.emission_box_extents = Vector3(half.x, half.y, 1.0)
		(n as GPUParticles2D).visibility_rect = Rect2(-half * 1.5, half * 3.0)
	elif n is CPUParticles2D:
		(n as CPUParticles2D).emission_rect_extents = half


func _base_particles(nm: String, amount: int, lifetime: float, tex: Texture2D) -> GPUParticles2D:
	var g := GPUParticles2D.new()
	g.name = nm
	g.amount = maxi(amount, 1)
	g.lifetime = lifetime
	g.local_coords = false
	g.texture = tex
	g.preprocess = lifetime
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.gravity = Vector3.ZERO
	pm.spread = 0.0
	g.process_material = pm
	return g


func _unshaded(additive: bool, hframes: int = 1) -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if additive else CanvasItemMaterial.BLEND_MODE_MIX
	if hframes > 1:
		m.particles_animation = true
		m.particles_anim_h_frames = hframes
		m.particles_anim_v_frames = 1
		m.particles_anim_loop = false
	return m


func _make_drops() -> Node2D:
	var tex := AmbianceTextures.get_tex(&"drop_32")
	var mx := 200
	var g := _base_particles("Drops", mx, 0.6, tex)
	var pm := g.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 1, 0)
	pm.initial_velocity_min = 6.0 * U
	pm.initial_velocity_max = 9.0 * U
	pm.particle_flag_align_y = true
	var s := 0.08 * U / float(tex.get_width())
	pm.scale_min = s * 0.75
	pm.scale_max = s * 2.0
	pm.color = Color(1, 1, 1, 0.35)
	g.material = _unshaded(false)
	g.set_meta(&"max", float(mx))
	var n := finalize_particles(g)
	n.set_meta(&"max", float(mx))
	return n


func _make_splashes(max_rate: float) -> Node2D:
	var tex := AmbianceTextures.get_tex(&"splash_8x64")
	var life := 0.25
	var mx := maxi(int(ceil(max_rate * life)), 1)
	var g := _base_particles("Splashes", mx, life, tex)
	var pm := g.process_material as ParticleProcessMaterial
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0
	var frames := AmbianceTextures.frame_count(tex)
	var frame_w := float(tex.get_width()) / float(frames)
	var s := 0.3 * U / maxf(frame_w, 1.0)
	pm.scale_min = s * 0.7
	pm.scale_max = s * 1.2
	pm.color = Color(1, 1, 1, 0.55)
	g.material = _unshaded(false, frames)
	var n := finalize_particles(g)
	n.set_meta(&"max_rate", max_rate)
	return n


func _make_ambient(def: Dictionary, tex: Texture2D, mx: int) -> Node2D:
	var behavior := StringName(def.get("behavior", &"drift"))
	var life := float(def.get("lifetime", 6.0))
	var g := _base_particles(String(def.get("name", "ambient")), mx, life, tex)
	var pm := g.process_material as ParticleProcessMaterial
	var sp := float(def.get("speed_u", 0.5)) * U
	var size: Vector2 = def.get("size_u", Vector2(0.1, 0.2))
	var hf := int(def.get("hframes", 1))
	var fw := float(tex.get_width()) / float(hf)
	pm.scale_min = size.x * U / maxf(fw, 1.0)
	pm.scale_max = size.y * U / maxf(fw, 1.0)
	var col: Color = def.get("color", Color.WHITE)
	var additive := bool(def.get("additive", false))
	if additive:
		col = Color(col.r * 1.6, col.g * 1.6, col.b * 1.6) # HDR : accroche le glow
	col.a = float(def.get("alpha", 1.0))
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 1))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color = col
	pm.color_ramp = rt
	match behavior:
		&"fall":
			pm.direction = Vector3(0.35, 1, 0)
			pm.spread = 20.0
			pm.initial_velocity_min = sp * 0.8
			pm.initial_velocity_max = sp * 1.2
			var spin := float(def.get("spin_dps", 60.0))
			pm.angular_velocity_min = -spin
			pm.angular_velocity_max = spin
		&"firefly":
			pm.direction = Vector3(1, 0, 0)
			pm.spread = 180.0
			pm.initial_velocity_min = sp * 0.5
			pm.initial_velocity_max = sp
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 2.0
			pm.turbulence_noise_scale = 4.0
			pm.turbulence_influence_min = 0.05
			pm.turbulence_influence_max = 0.15
		&"rise":
			pm.direction = Vector3(0.2, -1, 0)
			pm.spread = 30.0
			pm.initial_velocity_min = sp * 0.6
			pm.initial_velocity_max = sp
		&"wind":
			pm.direction = Vector3(-0.94, -0.34, 0)
			pm.spread = 10.0
			pm.initial_velocity_min = sp * 0.8
			pm.initial_velocity_max = sp * 1.2
			pm.angular_velocity_min = -120.0
			pm.angular_velocity_max = 120.0
		_: # drift (brownien)
			pm.direction = Vector3(1, 0, 0)
			pm.spread = 180.0
			pm.initial_velocity_min = 0.0
			pm.initial_velocity_max = sp
	g.material = _unshaded(additive, hf)
	return finalize_particles(g)
