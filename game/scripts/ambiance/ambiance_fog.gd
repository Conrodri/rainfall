class_name AmbianceFog
extends Node2D
## Brumes, ombres de nuages et rayons de lumière (World). Direction §1.3, §2, §5.
## z (absolus) : nuages -16 (multiply, sous les entités), brume basse -14 et nappes -14 (sous les
## entités : jamais sur les monstres ni les télégraphes), brume haute 20 (Haut, dégagée dans 6 u
## autour du joueur), rayons 32 (additifs).
## Textures absentes : l'effet concerné est simplement coupé.

const U := 64.0
const VIEW_MARGIN := 256.0
const Z_CLOUDS := -16
const Z_FOG_LOW := -14
const Z_FOG_HIGH := 20
const Z_RAYS := 32
const HIGH_CLEAR_RADIUS_U := 6.0
const FOG_SHADER := preload("res://shaders/fog_scroll.gdshader")
const CLOUD_SHADER := preload("res://shaders/cloud_shadow.gdshader")
const RAYS_SHADER := preload("res://shaders/light_rays.gdshader")

var fog_low: ColorRect
var fog_high: ColorRect
var clouds: ColorRect
var puffs_root: Node2D
var rays_root: Node2D

var _low_mat: ShaderMaterial
var _high_mat: ShaderMaterial
var _cloud_mat: ShaderMaterial
var _off_low := Vector2.ZERO
var _off_2 := Vector2.ZERO
var _off_high := Vector2.ZERO
var _off_ca := Vector2.ZERO
var _off_cb := Vector2.ZERO
var _t := 0.0
var _puffs: Array = [] ## [{sprite, age, life, vel}]
var _rays: Array = [] ## [{sprite, anchor, phase}]
var _event_rays: Array = [] ## [{sprite, age, life, alpha}]
var _has_puff := false
var _has_ray := false
var _map_rect := Rect2()
var _height_mask: Texture2D = null


func _ready() -> void:
	clouds = _quad("Clouds", Z_CLOUDS)
	_cloud_mat = _mat(CLOUD_SHADER, clouds)
	fog_low = _quad("FogLow", Z_FOG_LOW)
	_low_mat = _mat(FOG_SHADER, fog_low)
	puffs_root = Node2D.new()
	puffs_root.name = "Puffs"
	puffs_root.z_index = Z_FOG_LOW
	add_child(puffs_root)
	fog_high = _quad("FogHigh", Z_FOG_HIGH)
	_high_mat = _mat(FOG_SHADER, fog_high)
	rays_root = Node2D.new()
	rays_root.name = "Rays"
	rays_root.z_index = Z_RAYS
	add_child(rays_root)


func _quad(nm: String, z: int) -> ColorRect:
	var r := ColorRect.new()
	r.name = nm
	r.z_index = z
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _mat(sh: Shader, r: CanvasItem) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	return m


## Structure d'une carte : textures (nuages ou canopée), masque de hauteur, rectangle de la carte.
func setup(profile: AmbianceProfile, map_rect: Rect2) -> void:
	_map_rect = map_rect
	var fa := AmbianceTextures.get_tex(&"fog_tile_1024")
	var fb := AmbianceTextures.get_tex(&"fog_tile_1024_2")
	if fb == null:
		fb = fa
	_low_mat.set_shader_parameter(&"fog_a", fa)
	_low_mat.set_shader_parameter(&"fog_b", fb)
	var fh := AmbianceTextures.get_tex(&"fog_volume_tile_1024")
	if fh == null:
		fh = fa
	_high_mat.set_shader_parameter(&"fog_a", fh)
	_high_mat.set_shader_parameter(&"layers", 1)
	fog_low.set_meta(&"has_tex", fa != null)
	fog_high.set_meta(&"has_tex", fh != null)
	var ct := AmbianceTextures.get_tex(profile.cloud_texture) if profile != null and profile.cloud_texture != &"" else null
	_cloud_mat.set_shader_parameter(&"clouds", ct)
	clouds.set_meta(&"has_tex", ct != null)
	_height_mask = null
	if profile != null:
		var mid := StringName("fog_height_mask_" + String(profile.map_id))
		if AmbianceTextures.exists(mid):
			_height_mask = AmbianceTextures.get_tex(mid)
	_low_mat.set_shader_parameter(&"height_mask", _height_mask)
	_low_mat.set_shader_parameter(&"map_rect", Vector4(map_rect.position.x, map_rect.position.y, maxf(map_rect.size.x, 1.0), maxf(map_rect.size.y, 1.0)))
	_has_puff = AmbianceTextures.is_real(&"fog_puff_512")
	_has_ray = AmbianceTextures.is_real(&"godray_512x1024")
	for pf in _puffs:
		(pf["sprite"] as Node).queue_free()
	_puffs.clear()


func update_fog(view: Rect2, p: Dictionary, delta: float, player_pos: Vector2) -> void:
	_t += delta
	var r := view.grow(VIEW_MARGIN)
	var wind := float(p[&"wind_mult"])
	for q in [clouds, fog_low, fog_high]:
		(q as ColorRect).position = r.position - global_position
		(q as ColorRect).size = r.size
	# Brume basse (1 ou 2 calques selon le palier)
	var layers := int(Quality.get_setting(&"fog_layers"))
	_off_low -= (p[&"fog_low_speed"] as Vector2) * U * wind * delta
	var s2: Vector2 = p[&"fog2_speed"]
	var drift := Vector2(0.0, 0.05 * sin(_t * TAU / 18.0)) # dérive sinusoïdale (§2.1)
	_off_2 -= (s2 + drift) * U * wind * delta
	var low_a := float(p[&"fog_low_opacity"])
	var low_b := float(p[&"fog2_opacity"]) if layers >= 2 else 0.0
	fog_low.visible = bool(fog_low.get_meta(&"has_tex", false)) and (low_a + low_b) > 0.001
	_low_mat.set_shader_parameter(&"layers", 2 if low_b > 0.0 else 1)
	_low_mat.set_shader_parameter(&"color_a", p[&"fog_low_color"])
	_low_mat.set_shader_parameter(&"color_b", p[&"fog2_color"])
	_low_mat.set_shader_parameter(&"opacity_a", low_a)
	_low_mat.set_shader_parameter(&"opacity_b", low_b)
	_low_mat.set_shader_parameter(&"offset_a", _off_low)
	_low_mat.set_shader_parameter(&"offset_b", _off_2)
	_low_mat.set_shader_parameter(&"use_height_mask", _height_mask != null and bool(Quality.get_setting(&"fog_height_mask")))
	# Brume haute (Haut seulement)
	var high_on := bool(Quality.get_setting(&"fog_high")) and layers >= 3 and float(p[&"fog_high_opacity"]) > 0.001
	fog_high.visible = high_on and bool(fog_high.get_meta(&"has_tex", false))
	if fog_high.visible:
		_off_high -= (p[&"fog_high_speed"] as Vector2) * U * wind * delta
		_high_mat.set_shader_parameter(&"color_a", p[&"fog_high_color"])
		_high_mat.set_shader_parameter(&"opacity_a", float(p[&"fog_high_opacity"]))
		_high_mat.set_shader_parameter(&"offset_a", _off_high)
		_high_mat.set_shader_parameter(&"clear_center", player_pos)
		_high_mat.set_shader_parameter(&"clear_radius", HIGH_CLEAR_RADIUS_U * U)
	# Ombres de nuages / canopée
	var cl := int(Quality.get_setting(&"cloud_layers"))
	var co := float(p[&"cloud_opacity"])
	clouds.visible = cl > 0 and co > 0.001 and bool(clouds.get_meta(&"has_tex", false))
	if clouds.visible:
		var cs: Vector2 = p[&"cloud_speed_u"]
		_off_ca -= cs * U * delta
		_off_cb -= cs * U * 1.4 * delta
		_cloud_mat.set_shader_parameter(&"opacity", co)
		_cloud_mat.set_shader_parameter(&"layers", cl)
		_cloud_mat.set_shader_parameter(&"offset_a", _off_ca)
		_cloud_mat.set_shader_parameter(&"offset_b", _off_cb)
		_cloud_mat.set_shader_parameter(&"scale_mult", 1.0 + float(p[&"cloud_breathe"]) * sin(_t * TAU / 9.0))
	_update_puffs(view, p, delta)
	_update_rays(view, p, delta)


func _update_puffs(view: Rect2, p: Dictionary, delta: float) -> void:
	var want := 0
	if _has_puff:
		want = mini(roundi(float(p[&"puffs_count"])), int(Quality.get_setting(&"fog_puffs_max")))
	while _puffs.size() > want:
		(_puffs.pop_back()["sprite"] as Node).queue_free()
	while _puffs.size() < want:
		var s := Sprite2D.new()
		s.texture = AmbianceTextures.get_tex(&"fog_puff_512")
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		s.material = m
		puffs_root.add_child(s)
		var pf := {"sprite": s, "age": 0.0, "life": 1.0, "vel": Vector2.ZERO, "spin": 0.0}
		_respawn_puff(pf, view, true)
		_puffs.append(pf)
	var wind := float(p[&"wind_mult"])
	var col: Color = p[&"puffs_color"]
	var op := float(p[&"puffs_opacity"])
	for pf in _puffs:
		pf["age"] = float(pf["age"]) + delta
		var s: Sprite2D = pf["sprite"]
		s.global_position += (pf["vel"] as Vector2) * wind * delta
		s.rotation += deg_to_rad(float(pf["spin"])) * delta
		var u := float(pf["age"]) / float(pf["life"])
		var fade := clampf(minf(u, 1.0 - u) * 5.0, 0.0, 1.0)
		s.modulate = Color(col.r, col.g, col.b, AmbianceManager.ldr_alpha(op * fade, col))
		if u >= 1.0 or not view.grow(VIEW_MARGIN * 3.0).has_point(s.global_position):
			_respawn_puff(pf, view, false)


func _respawn_puff(pf: Dictionary, view: Rect2, initial: bool) -> void:
	var s: Sprite2D = pf["sprite"]
	var r := view.grow(VIEW_MARGIN)
	s.global_position = Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))
	var size_u := randf_range(6.0, 10.0) # nappes de 6-10 u (§2.2)
	s.scale = Vector2.ONE * size_u * U / maxf(float(s.texture.get_width()), 1.0)
	s.rotation = randf() * TAU
	pf["vel"] = Vector2.from_angle(deg_to_rad(randf_range(140.0, 220.0))) * 0.10 * U
	pf["spin"] = randf_range(-2.0, 2.0) # 2°/s
	pf["life"] = randf_range(12.0, 20.0)
	pf["age"] = randf() * float(pf["life"]) if initial else 0.0


func _update_rays(view: Rect2, p: Dictionary, delta: float) -> void:
	var cap := int(Quality.get_setting(&"rays_max"))
	var cover := float(p[&"cloud_cover"])
	var gate := clampf((0.6 - cover) / 0.1, 0.0, 1.0) # §2.1 : seulement si cloud_cover < 0,6
	var want := 0
	if _has_ray:
		want = mini(roundi(float(p[&"rays_count"])), cap)
	while _rays.size() > want:
		(_rays.pop_back()["sprite"] as Node).queue_free()
	while _rays.size() < want:
		var s := _ray_sprite()
		_rays.append({"sprite": s, "anchor": Vector2.ZERO, "phase": randf() * TAU})
		_place_ray(_rays[-1], view)
	var op := float(p[&"rays_opacity"]) * gate
	for ry in _rays:
		var s: Sprite2D = ry["sprite"]
		ry["anchor"] = (ry["anchor"] as Vector2) + Vector2.from_angle(deg_to_rad(float(p[&"rays_rotation_deg"]))) * 0.1 * U * delta
		s.global_position = ry["anchor"]
		s.rotation_degrees = float(p[&"rays_rotation_deg"])
		var fade := 0.55 + 0.45 * sin(_t * TAU / 12.0 + float(ry["phase"])) # fondu de 12 s
		(s.material as ShaderMaterial).set_shader_parameter(&"opacity", op * fade)
		(s.material as ShaderMaterial).set_shader_parameter(&"ray_color", p[&"rays_color"])
		if not view.grow(VIEW_MARGIN * 4.0).has_point(s.global_position):
			_place_ray(ry, view)
	for i in range(_event_rays.size() - 1, -1, -1):
		var e: Dictionary = _event_rays[i]
		e["age"] = float(e["age"]) + delta
		var u := clampf(float(e["age"]) / float(e["life"]), 0.0, 1.0)
		((e["sprite"] as Sprite2D).material as ShaderMaterial).set_shader_parameter(&"opacity", float(e["alpha"]) * (1.0 - u))
		if u >= 1.0:
			(e["sprite"] as Node).queue_free()
			_event_rays.remove_at(i)


## Rayons ponctuels (pilier terminé carte 2, éclair carte 3, coffre légendaire).
## Sans effet si la texture `godray_512x1024` n'est pas livrée ou si le palier les coupe.
func spawn_event_rays(pos: Vector2, count: int, alpha: float, duration: float, color: Color, rotation_deg: float = 88.0) -> int:
	if not _has_ray or int(Quality.get_setting(&"rays_max")) <= 0:
		return 0
	for i in count:
		var s := _ray_sprite()
		s.global_position = pos + Vector2(randf_range(-1.0, 1.0) * U, -randf_range(3.0, 6.0) * U)
		s.rotation_degrees = rotation_deg + randf_range(-3.0, 3.0)
		(s.material as ShaderMaterial).set_shader_parameter(&"ray_color", color)
		_event_rays.append({"sprite": s, "age": 0.0, "life": maxf(duration, 0.05), "alpha": alpha})
	return count


func ray_count() -> int:
	return _rays.size() + _event_rays.size()


func _ray_sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = AmbianceTextures.get_tex(&"godray_512x1024")
	var m := ShaderMaterial.new()
	m.shader = RAYS_SHADER
	s.material = m
	var w := randf_range(2.0, 4.0) * U / maxf(float(s.texture.get_width()), 1.0)
	s.scale = Vector2(w, 14.0 * U / maxf(float(s.texture.get_height()), 1.0)) # 2-4 u × 14 u
	rays_root.add_child(s)
	return s


func _place_ray(ry: Dictionary, view: Rect2) -> void:
	ry["anchor"] = Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y))
