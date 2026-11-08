extends AmbientEffect
## « Cristaux qui s'éteignent par vagues » (Cryptes, Furieux) : toutes les `gap_s` secondes, un front part d'un
## cristal tiré au hasard et file à `speed_u` u/s ; chaque lumière `preset` (et chaque prop de décor dont la texture
## contient `props_match`, par son masque `_e`) qu'il atteint baisse à `dim` pendant `hold_s` (3 s d'obscurité
## partielle, docs/Design_Etages.md), puis revient. Lisibilité : le fill des entités et les garde-fous de
## l'AmbianceManager ne sont pas touchés (jamais sous le plancher de luminance). En Bas, les lumières de décor sont
## à 0 (plafond LightRig) : seuls les masques `_e` des props bougent.
## Paramètres : "preset" ("crystal_vein"), "rules_only" (true : lumières des light_rules, pas les point_lights
## comme la colonne froide du puits de l'Ossuaire), "props_match" ("crystal"), "gap_s" [6, 10], "speed_u" (10),
## "hold_s" (3), "dim" (0,15), "edge_s" (0,4 : fondu de chaque bord).

const LIGHT_FADE_IN_WAVE := 0.3

var handles: Array = [] ## LightRig.Handle
var defs: Array = [] ## définitions des lumières (AmbianceManager.map_lights)
var props: Array[CanvasItem] = [] ## masques « Emission » des props de cristal
var _prop_base: Array[Color] = []
var _pos := PackedVector2Array() ## positions : lumières puis props
var _delay := PackedFloat32Array() ## arrivée du front sur chaque cible (s)
var _wave_t := -1.0 ## temps écoulé dans la vague (< 0 : au repos)
var _wave_len := 0.0
var _wait := 0.0
var waves := 0 ## vagues lancées (tests)
var min_mult := 1.0 ## multiplicateur le plus bas de la vague en cours (tests)


func start() -> void:
	handles.clear()
	defs.clear()
	props.clear()
	_prop_base.clear()
	var preset := StringName(def.get("preset", "crystal_vein"))
	var rules_only := bool(def.get("rules_only", true))
	for ml in mgr.map_lights():
		var d: Dictionary = ml["def"]
		if StringName(d.get("preset", &"")) != preset or (rules_only and not d.has("char")):
			continue
		handles.append(ml["handle"])
		defs.append(d)
	var pat := String(def.get("props_match", "crystal"))
	var root := map.get_node_or_null(^"Blocks")
	if pat != "" and root != null:
		for c in root.get_children():
			if c is Sprite2D and (c as Sprite2D).texture != null and (c as Sprite2D).texture.resource_path.get_file().contains(pat):
				var em := emission_of(c)
				if em != null:
					props.append(em)
					_prop_base.append(em.self_modulate)
	_pos.resize(handles.size() + props.size())
	_delay.resize(_pos.size())
	for i in handles.size():
		_pos[i] = defs[i]["global"]
		(handles[i] as LightRig.Handle).set_fade(LIGHT_FADE_IN_WAVE)
	for j in props.size():
		_pos[handles.size() + j] = (props[j].get_parent() as Node2D).global_position
	_wave_t = -1.0
	_wait = rand_range_of(def.get("gap_s"), Vector2(6.0, 10.0)) * 0.5 # première vague assez tôt


func process(delta: float) -> void:
	if _pos.is_empty():
		return
	if _wave_t < 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_begin_wave()
		return
	_wave_t += delta
	var dim := float(def.get("dim", 0.15))
	var hold := float(def.get("hold_s", 3.0))
	var edge := maxf(float(def.get("edge_s", 0.4)), 0.01)
	min_mult = 1.0
	var nh := handles.size()
	for i in _pos.size():
		var t := _wave_t - _delay[i]
		var e := 0.0 # 0 = allumé, 1 = au plus bas
		if t > 0.0 and t < hold + edge:
			e = minf(t / edge, 1.0) * (1.0 - clampf((t - hold) / edge, 0.0, 1.0))
		var m := lerpf(1.0, dim, e)
		min_mult = minf(min_mult, m)
		if i < nh:
			var h: LightRig.Handle = handles[i]
			h.set_energy(mgr.map_light_base_energy(defs[i]) * m)
		else:
			var em := props[i - nh]
			if is_instance_valid(em):
				var b := _prop_base[i - nh]
				em.self_modulate = Color(b.r * m, b.g * m, b.b * m, b.a)
	if _wave_t >= _wave_len:
		_wave_t = -1.0
		_wait = rand_range_of(def.get("gap_s"), Vector2(6.0, 10.0))


func _begin_wave() -> void:
	waves += 1
	var origin := _pos[randi() % _pos.size()]
	var speed := maxf(float(def.get("speed_u", 10.0)), 0.1) * U
	var far := 0.0
	for i in _pos.size():
		_delay[i] = _pos[i].distance_to(origin) / speed
		far = maxf(far, _delay[i])
	_wave_len = far + float(def.get("hold_s", 3.0)) + float(def.get("edge_s", 0.4)) * 2.0
	_wave_t = 0.0


func stop() -> void:
	for i in handles.size():
		var h: LightRig.Handle = handles[i]
		h.set_fade(AmbianceManager.LIGHT_FADE_S)
		if mgr != null and is_instance_valid(mgr):
			h.set_energy(mgr.map_light_base_energy(defs[i]))
	for j in props.size():
		if is_instance_valid(props[j]):
			props[j].self_modulate = _prop_base[j]
	handles.clear()
	defs.clear()
	props.clear()
	_prop_base.clear()
	_pos.resize(0)
	_delay.resize(0)
	_wave_t = -1.0


func wave_running() -> bool:
	return _wave_t >= 0.0


## Lance une vague tout de suite (tests).
func force_wave() -> void:
	if not _pos.is_empty():
		_begin_wave()


func describe() -> Dictionary:
	var d := super.describe()
	d["lights"] = handles.size()
	d["props"] = props.size()
	d["waves"] = waves
	return d
