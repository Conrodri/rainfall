extends AmbientEffect
## « Vent de gouffre » (Gouffre B, Hostile, docs/Design_Etage2_Grotte.md) : toutes les `gap_s` secondes (20-30 s),
## une bouffée de `duration_s` (4 s) : `wind_mult` du profil porté à `wind` (brume basse et nappes qui filent),
## poussée de vent sur les particules d'ambiance légères (spores, poussière : pas les gouttes), traînées de vent
## horizontales (texture Codex `wind_streak_128`, émetteur sur la vue, plafonné par palier, rien en Bas), lumières
## `flicker_preset` qui vacillent, souffle grave (son `sound`, muet tant qu'il n'est pas livré). Aucun effet de jeu.
## Paramètres : "gap_s" [20, 30], "duration_s" (4), "wind" (2), "push_deg" (200 : direction du vent, écran),
## "push_u" (1,5 u/s² sur les particules), "flicker_preset" ("mycelium_glow"), "flicker" [0,08, 2] (amplitude, Hz),
## "streaks" [Bas, Moyen, Haut] ([0, 16, 32]), "sound" ("amb.gust").

const STREAK_TEX := &"wind_streak_128"

var gust := 0.0 ## enveloppe 0..1 de la bouffée
var gusts := 0 ## bouffées lancées (tests)
var wait := 0.0
var _t := -1.0
var _flicker := false
var _pushing := false
var streaks: Node2D = null


func setup() -> void:
	if not AmbianceTextures.is_real(STREAK_TEX):
		note_missing("texture d'ambiance %s (traînées de vent)" % STREAK_TEX)
	var snd := StringName(def.get("sound", "amb.gust"))
	var a := audio()
	if a != null and a.get(&"bank") != null and not a.bank.has_sound(snd):
		note_missing("son %s (souffle grave d'une bouffée, 4 s, one-shot)" % snd)


func start() -> void:
	gust = 0.0
	_t = -1.0
	wait = rand_range_of(def.get("gap_s"), Vector2(20.0, 30.0))
	_build_streaks()


func _build_streaks() -> void:
	_free_streaks()
	var n := int(per_tier(def.get("streaks", [0, 16, 32])))
	if n <= 0 or not AmbianceTextures.is_real(STREAK_TEX) or mgr.weather == null:
		return
	var tex := AmbianceTextures.get_tex(STREAK_TEX)
	var g := GPUParticles2D.new()
	g.name = "GustStreaks"
	g.amount = n
	g.lifetime = 1.2
	g.local_coords = false
	g.texture = tex
	g.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.gravity = Vector3.ZERO
	var d := Vector2.from_angle(deg_to_rad(float(def.get("push_deg", 200.0))))
	pm.direction = Vector3(d.x, d.y, 0.0)
	pm.spread = 6.0
	pm.initial_velocity_min = 9.0 * U
	pm.initial_velocity_max = 13.0 * U
	pm.particle_flag_align_y = false
	var s := 1.4 * U / maxf(float(tex.get_width()), 1.0)
	pm.scale_min = s * 0.7
	pm.scale_max = s * 1.3
	pm.color = Color(0.82, 0.86, 0.92, 0.22)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	g.process_material = pm
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	g.material = m
	streaks = AmbianceWeather.finalize_particles(g)
	streaks.z_index = AmbianceWeather.Z_AMBIENT
	mgr.events.add_child(streaks)


func _free_streaks() -> void:
	if streaks != null and is_instance_valid(streaks):
		streaks.queue_free()
	streaks = null


func process(delta: float) -> void:
	if _t >= 0.0:
		_t += delta
		var dur := maxf(float(def.get("duration_s", 4.0)), 0.1)
		var u := _t / dur
		gust = smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.7, 1.0, u))
		if _t >= dur:
			_t = -1.0
			gust = 0.0
			wait = rand_range_of(def.get("gap_s"), Vector2(20.0, 30.0))
	else:
		wait -= delta
		if wait <= 0.0:
			_begin()
	_apply()


func _begin() -> void:
	_t = 0.0
	gusts += 1
	var a := audio()
	if a != null:
		a.call(&"play", StringName(def.get("sound", "amb.gust")))


func _apply() -> void:
	mgr.gust_level = gust
	mgr.gust_wind = float(def.get("wind", 2.0))
	if mgr.weather != null and (gust > 0.0 or _pushing):
		_pushing = gust > 0.0
		var d := Vector2.from_angle(deg_to_rad(float(def.get("push_deg", 200.0))))
		mgr.weather.set_gust_push(d * float(def.get("push_u", 1.5)) * U * gust)
	if streaks != null:
		AmbianceWeather.set_ratio(streaks, gust)
		var view := mgr.view_rect()
		streaks.global_position = view.get_center()
		var half := view.size * 0.5
		if streaks is GPUParticles2D:
			((streaks as GPUParticles2D).process_material as ParticleProcessMaterial).emission_box_extents = Vector3(half.x, half.y, 1.0)
			(streaks as GPUParticles2D).visibility_rect = Rect2(-half * 1.5, half * 3.0)
		elif streaks is CPUParticles2D:
			(streaks as CPUParticles2D).emission_rect_extents = half
	var want := gust > 0.05
	if want != _flicker:
		_flicker = want
		var fp := StringName(def.get("flicker_preset", "mycelium_glow"))
		var fl: Variant = def.get("flicker", [0.08, 2.0])
		for ml in mgr.map_lights():
			if StringName((ml["def"] as Dictionary)["preset"]) == fp:
				var lh: LightRig.Handle = ml["handle"]
				if want:
					lh.set_flicker_override(float(fl[0]), float(fl[1]))
				else:
					lh.set_flicker_override(-1.0)


func on_quality() -> void:
	_build_streaks()


## Lumières de la carte reconstruites : le vacillement est réappliqué à la prochaine image, la bouffée continue.
func refresh() -> void:
	_flicker = false
	_build_streaks()


## Lance une bouffée tout de suite (tests, mode test).
func force_gust() -> void:
	wait = 0.0


func stop() -> void:
	gust = 0.0
	_t = -1.0
	if mgr != null and is_instance_valid(mgr):
		mgr.gust_level = 0.0
		if mgr.weather != null:
			mgr.weather.set_gust_push(Vector2.ZERO)
		if _flicker:
			var fp := StringName(def.get("flicker_preset", "mycelium_glow"))
			for ml in mgr.map_lights():
				if StringName((ml["def"] as Dictionary)["preset"]) == fp:
					(ml["handle"] as LightRig.Handle).set_flicker_override(-1.0)
	_flicker = false
	_pushing = false
	_free_streaks()


func describe() -> Dictionary:
	var d := super.describe()
	d["gust"] = gust
	d["gusts"] = gusts
	d["streaks"] = streaks != null
	return d
