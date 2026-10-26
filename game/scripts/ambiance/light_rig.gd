class_name LightRig
extends Node2D
## Pool de PointLight2D avec budget par palier (Quality : total `max_lights` et plafonds par
## catégorie `light_caps`), les plus importantes d'abord. Direction §4 et §5.
## Les autres systèmes ne créent jamais de PointLight2D eux-mêmes :
##
##   var h := LightRig.attach(self, &"chest_legendaire")   # suit le nœud, libérée à sa sortie d'arbre
##   h.set_preset(&"pillar_active")                        # changement d'état
##   h.ramp(0.0, 1.0, 1.6, 0.7, 0.6)                       # rayon ×0→×1 et énergie 1,6→0,7 en 0,6 s
##   h.set_energy(0.5) ; h.set_radius_mult(1.2) ; h.set_enabled(false) ; h.release()
##   LightRig.flash(global_position, &"meteor_impact", 0.35)   # éclat qui décroît puis se libère
##
## Presets : data/ambiance/light_presets.json. Les demandes sont statiques : attach() marche avant
## que la scène de jeu n'existe ; le pool (créé par AmbianceManager) les prend en charge.
## Une cible invisible (`is_visible_in_tree() == false`, ex. monstre rendu au pool) n'est pas
## éclairée. Hors écran (+ marge 3 u), la lumière est rendue au pool (sauf `cull: false`).
## Ombres : le joueur d'abord, puis les candidates `shadow` les plus proches, dans la limite
## `Quality.shadow_lights`. Masques : bit 1 = entités (monde hors sol), bit 2 = flaques (presets
## `reflect`), bit 4 = sol et décor de la carte (éclairage profond v2 : le « fill » des entités
## d'AmbianceManager n'éclaire que le bit 1, le sol reste sombre).

const PRESETS_PATH := "res://data/ambiance/light_presets.json"
const REASSIGN_INTERVAL := 0.1 ## s entre deux tris des demandes
const VIEW_MARGIN_PX := 192.0 ## 3 u (§4.5)
const UNIT_PX := 64.0
const RANGE_Z_MIN := -20 ## §1.3 : n'éclaire ni la pluie, ni la brume haute
const RANGE_Z_MAX := 10
const MASK_WORLD := 1
const MASK_PUDDLES := 2
const MASK_GROUND := 8 ## sol et décor de la carte (voir AmbianceManager._mask_ground)
const MASK_LIT := MASK_WORLD | MASK_GROUND ## tout ce qu'une lumière ponctuelle éclaire


## Une demande de lumière. Utiliser les méthodes ; les champs sont lus par le pool.
class Handle extends RefCounted:
	var target: WeakRef = null ## Node2D suivi (null si position fixe)
	var position := Vector2.ZERO ## position globale si pas de cible, sinon décalage
	var preset: StringName
	var energy_mult := 1.0
	var radius_mult := 1.0
	var color_override := Color(0, 0, 0, 0) ## alpha 0 = couleur du preset
	var enabled := true
	var priority_bonus := 0.0
	var rate_mult := 1.0 ## accélère pulsation/battement (ex. 1,6/1,1 sous 30 % PV)
	var flicker_override := Vector2(-1, 0) ## (amplitude, hz) ; x < 0 = celui du preset
	var fade_s := 0.12 ## constante de temps des changements d'énergie (lanternes : 10 s)
	var lifetime := -1.0 ## > 0 : éclat qui décroît puis se libère
	var age := 0.0
	var released := false
	var seed := 0.0
	var current_energy := 0.0
	var light: PointLight2D = null ## lumière du pool assignée (interne)
	var _ramp := {} ## {r0, r1, e0, e1, t, d}
	var _outage_t := 0.0
	var _outage_left := 0.0

	func set_preset(p: StringName) -> void:
		preset = p

	func set_energy(mult: float) -> void:
		energy_mult = mult

	func set_radius_mult(mult: float) -> void:
		radius_mult = mult

	func set_color(c: Color) -> void:
		color_override = c

	func set_enabled(on: bool) -> void:
		enabled = on

	func set_priority_bonus(b: float) -> void:
		priority_bonus = b

	func set_rate_mult(m: float) -> void:
		rate_mult = m

	## Scintillement imposé (pilier qui grésille hors zone) ; amplitude < 0 = celui du preset.
	func set_flicker_override(amplitude: float, hz: float = 6.0) -> void:
		flicker_override = Vector2(amplitude, hz)

	func set_fade(seconds: float) -> void:
		fade_s = maxf(seconds, 0.01)

	## Animation de rayon et d'énergie (multiplicateurs du preset) sur `duration` s.
	func ramp(radius_from: float, radius_to: float, energy_from: float, energy_to: float, duration: float) -> void:
		_ramp = {"r0": radius_from, "r1": radius_to, "e0": energy_from, "e1": energy_to, "t": 0.0, "d": maxf(duration, 0.01)}
		radius_mult = radius_from
		energy_mult = energy_from

	## Extinction brève (surtension des lampes à l'éclair, coffre piégé).
	func outage(ms: float = 120.0) -> void:
		_outage_left = ms / 1000.0

	func release() -> void:
		released = true

	func get_target() -> Node2D:
		return target.get_ref() as Node2D if target != null else null

	func world_position() -> Vector2:
		var t := get_target()
		return t.global_position + position if t != null else position


static var _requests: Array = [] ## Array[Handle]
static var _presets: Dictionary = {}
static var _instance: LightRig = null
## Multiplicateurs globaux par catégorie, réglés par AmbianceManager (D et carte) :
## {&"player": Vector2(rayon, énergie), &"decor": …}
static var category_scale: Dictionary = {}
## Plafond d'énergie d'une PointLight2D de catégorie « boss » (retour joueur 26/10/2026 : boss trop brillants).
## Mini-boss : JSON 1,7-2,3 + boosts de phase ; au-delà, la lumière écrase le cel-shading et sature le glow.
const BOSS_LIGHT_MAX_ENERGY := 1.5
## Multiplie l'intervalle entre deux extinctions (lampes à Cataclysme : 0,35).
static var outage_scale := 1.0

var budget_override := -1 ## >= 0 : impose un budget total (tests)
var _pool: Array[PointLight2D] = []
var _assigned: Array = [] ## handles qui ont une lumière
var _reassign_t := 0.0
var _time := 0.0
var _max_lights := 0
var _caps: Dictionary = {}
var _shadow_lights := 0
var _shadow_filter := 0
var _quality := 2


# --- API statique ---------------------------------------------------------

## Attache une lumière au nœud. `opts` : energy, radius, color, offset (Vector2 px), priority_bonus,
## fade (s). Libérée automatiquement quand le nœud quitte l'arbre.
static func attach(node: Node2D, preset: StringName, opts: Dictionary = {}) -> Handle:
	var h := Handle.new()
	h.target = weakref(node)
	h.preset = preset
	h.position = opts.get("offset", Vector2(0, float(get_preset(preset).get("offset_u", 0.0)) * UNIT_PX))
	_apply_opts(h, opts)
	if node != null and not node.tree_exiting.is_connected(h.release):
		node.tree_exiting.connect(h.release, CONNECT_ONE_SHOT)
	_requests.append(h)
	return h


## Lumière fixe à une position globale (sources de la carte).
static func attach_at(global_pos: Vector2, preset: StringName, opts: Dictionary = {}) -> Handle:
	var h := Handle.new()
	h.position = global_pos
	h.preset = preset
	_apply_opts(h, opts)
	_requests.append(h)
	return h


const FLASH_CAP_PER_S := 3 ## A-07 : au plus 3 éclats forts par seconde (WCAG 2.3.1), les suivants sont fusionnés (éteints)
const FLASH_CAP_MIN_ENERGY := 1.0 ## énergie du preset × multiplicateur à partir de laquelle un éclat compte (petites lueurs exemptes)
static var _flash_times: Array[float] = []


## Éclat ponctuel (impact, ouverture de coffre, foudre) : énergie du preset × (1-u)² sur `duration`.
## Point unique du réglage « Flashs » (GameSettings.flash_scale() : 0 / 0,25 / 1) et du plafond d'éclats forts par seconde.
static func flash(global_pos: Vector2, preset: StringName, duration: float = 0.3, opts: Dictionary = {}) -> Handle:
	var o := opts.duplicate()
	var mult := float(o.get("energy", 1.0)) * GameSettings.flash_scale()
	if mult > 0.0 and mult * float(get_preset(preset).get("energy", 0.6)) >= FLASH_CAP_MIN_ENERGY:
		var now := Time.get_ticks_msec() * 0.001
		while not _flash_times.is_empty() and now - _flash_times[0] > 1.0:
			_flash_times.pop_front()
		if _flash_times.size() >= FLASH_CAP_PER_S:
			mult = 0.0 # fusionné avec les éclats récents
		else:
			_flash_times.append(now)
	o["energy"] = mult
	var h := attach_at(global_pos, preset, o)
	h.lifetime = maxf(duration, 0.01)
	h.priority_bonus += 50.0
	return h


static func detach(h: Handle) -> void:
	if h != null:
		h.release()


static func instance() -> LightRig:
	return _instance if is_instance_valid(_instance) else null


static func request_count() -> int:
	return _requests.size()


static func get_preset(p: StringName) -> Dictionary:
	if _presets.is_empty():
		_load_presets()
	if _presets.has(p):
		return _presets[p]
	return _presets.get(&"default", {})


static func has_preset(p: StringName) -> bool:
	if _presets.is_empty():
		_load_presets()
	return _presets.has(p)


static func preset_names() -> Array:
	if _presets.is_empty():
		_load_presets()
	return _presets.keys()


## Vide toutes les demandes (changement de scène, tests).
static func clear_all() -> void:
	for h in _requests:
		(h as Handle).released = true
	_requests.clear()
	_flash_times.clear()


static func _apply_opts(h: Handle, opts: Dictionary) -> void:
	h.energy_mult = float(opts.get("energy", 1.0))
	h.radius_mult = float(opts.get("radius", 1.0))
	if opts.has("color"):
		h.color_override = opts["color"]
	h.priority_bonus = float(opts.get("priority_bonus", 0.0))
	if opts.has("fade"):
		h.set_fade(float(opts["fade"]))
	h.seed = randf() * 100.0
	h._outage_t = randf() * 3.0


static func _load_presets() -> void:
	_presets = {}
	var txt := FileAccess.get_file_as_string(PRESETS_PATH)
	var data = JSON.parse_string(txt) if txt != "" else null
	if typeof(data) != TYPE_DICTIONARY:
		push_error("LightRig : presets illisibles (%s)" % PRESETS_PATH)
		data = {"default": {}}
	for k in data:
		if String(k).begins_with("_"):
			continue
		var p: Dictionary = data[k]
		var sc := Color.from_string(String(p.get("shadow_color", "#101418")), Color.BLACK)
		sc.a = float(p.get("shadow_alpha", 0.5))
		_presets[StringName(k)] = {
			"color": Color.from_string(String(p.get("color", "#ffffff")), Color.WHITE),
			"energy": float(p.get("energy", 0.6)),
			"radius_u": float(p.get("radius_u", 2.0)),
			"height": float(p.get("height", 32.0)),
			"priority": float(p.get("priority", 10.0)),
			"category": StringName(p.get("category", "decor")),
			"shadow": bool(p.get("shadow", false)),
			"shadow_color": sc,
			"flicker": float(p.get("flicker", 0.0)),
			"flicker_hz": float(p.get("flicker_hz", 6.0)),
			"pulse": float(p.get("pulse", 0.0)),
			"pulse_hz": float(p.get("pulse_hz", 1.0)),
			"pulse_shape": StringName(p.get("pulse_shape", "sine")),
			"outage_min": float(p.get("outage_min", 0.0)),
			"outage_max": float(p.get("outage_max", 0.0)),
			"outage_ms": float(p.get("outage_ms", 120.0)),
			"spin_dps": float(p.get("spin_dps", 0.0)),
			"texture": StringName(p.get("texture", "light_soft_256")),
			"min_quality": int(p.get("min_quality", 0)),
			"offset_u": float(p.get("offset_u", 0.0)),
			"cull": bool(p.get("cull", true)),
			"reflect": bool(p.get("reflect", false)),
		}


## Forme « lub-dub » du battement du joueur (§4.1) : +18 % 90 ms puis +8 % 120 ms plus tard,
## base 0,95. `phase` en périodes.
static func heartbeat(phase: float) -> float:
	var t := fposmod(phase, 1.0)
	var period := 1.0 / 1.1
	var s := t * period # secondes dans le cycle (référence 1,1 Hz)
	var v := 0.95
	if s < 0.09:
		v += 0.20 * sin(s / 0.09 * PI)
	elif s >= 0.21 and s < 0.30:
		v += 0.10 * sin((s - 0.21) / 0.09 * PI)
	return v


# --- Pool -----------------------------------------------------------------

func _enter_tree() -> void:
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null
	for h in _assigned:
		(h as Handle).light = null
	_assigned.clear()


func _ready() -> void:
	if _presets.is_empty():
		_load_presets()
	if not Quality.quality_changed.is_connected(_on_quality):
		Quality.quality_changed.connect(_on_quality)
	_on_quality(Quality.tier)


func _on_quality(_t: int) -> void:
	_quality = Quality.tier
	_max_lights = int(Quality.get_setting(&"max_lights"))
	_caps = Quality.get_setting(&"light_caps")
	_shadow_lights = int(Quality.get_setting(&"shadow_lights"))
	_shadow_filter = int(Quality.get_setting(&"shadow_filter"))
	reassign()


func budget() -> int:
	return budget_override if budget_override >= 0 else _max_lights


## Lumières du pool effectivement allumées.
func active_light_count() -> int:
	var n := 0
	for l in _pool:
		if l.visible and l.enabled:
			n += 1
	return n


func shadowed_light_count() -> int:
	var n := 0
	for l in _pool:
		if l.visible and l.enabled and l.shadow_enabled:
			n += 1
	return n


func pool_size() -> int:
	return _pool.size()


func assigned_handles() -> Array:
	return _assigned.duplicate()


## Nombre de lumières allumées par catégorie (tests, débogage).
func count_by_category() -> Dictionary:
	var d := {}
	for h in _assigned:
		var c: StringName = get_preset((h as Handle).preset)["category"]
		d[c] = int(d.get(c, 0)) + 1
	return d


func _process(delta: float) -> void:
	_time += delta
	_reassign_t += delta
	if _reassign_t >= REASSIGN_INTERVAL:
		_reassign_t = 0.0
		reassign()
	_update_lights(delta)


## Trie les demandes et assigne les lumières du pool (public pour les tests).
func reassign() -> void:
	var alive: Array = []
	for h in _requests:
		var hh := h as Handle
		if hh.released or (hh.target != null and hh.get_target() == null):
			hh.released = true
			continue
		alive.append(hh)
	_requests = alive

	var view := _view_rect()
	var center := view.get_center()
	var scored: Array = []
	for h in _requests:
		var hh := h as Handle
		if not hh.enabled or (hh.energy_mult <= 0.0 and hh.current_energy < 0.005):
			continue # énergie 0 : on garde la lumière le temps du fondu de sortie
		var p := get_preset(hh.preset)
		if float(p["energy"]) <= 0.0 or int(p["min_quality"]) > _quality:
			continue
		var t := hh.get_target()
		if t != null and not t.is_visible_in_tree():
			continue
		var wp := hh.world_position()
		var r := float(p["radius_u"]) * hh.radius_mult * UNIT_PX
		if bool(p["cull"]) and not view.grow(VIEW_MARGIN_PX + r).has_point(wp):
			continue
		var dist := wp.distance_to(center)
		var score := float(p["priority"]) + hh.priority_bonus - dist / UNIT_PX * 0.5
		scored.append([score, hh, dist])
	scored.sort_custom(func(a, b): return a[0] > b[0])

	var total := budget()
	var used := {}
	var chosen: Array = []
	var dists := {}
	for s in scored:
		if chosen.size() >= total:
			break
		var hh: Handle = s[1]
		var cat: StringName = get_preset(hh.preset)["category"]
		var cap := int(_caps.get(cat, total)) if budget_override < 0 else total
		if int(used.get(cat, 0)) >= cap:
			continue
		used[cat] = int(used.get(cat, 0)) + 1
		chosen.append(hh)
		dists[hh] = s[2]

	for h in _assigned:
		var hh := h as Handle
		if not dists.has(hh) and hh.light != null:
			_free_light(hh.light)
			hh.light = null
	_assigned = chosen
	_shrink_pool(total)

	# Ombres : le joueur d'abord, puis les candidates les plus proches du centre de l'écran.
	var shadow_cands: Array = []
	for hh in chosen:
		if bool(get_preset(hh.preset)["shadow"]):
			var is_player: bool = get_preset(hh.preset)["category"] == &"player"
			shadow_cands.append([(-1.0 if is_player else float(dists[hh])), hh])
	shadow_cands.sort_custom(func(a, b): return a[0] < b[0])
	var shadowed := {}
	for i in mini(_shadow_lights, shadow_cands.size()):
		shadowed[shadow_cands[i][1]] = true

	for hh in chosen:
		if hh.light == null:
			hh.light = _take_light()
			hh.current_energy = 0.0
		var p := get_preset(hh.preset)
		_configure(hh.light, p, hh)
		hh.light.shadow_enabled = shadowed.has(hh)
		if hh.light.shadow_enabled:
			hh.light.shadow_filter = _shadow_filter as Light2D.ShadowFilter
			hh.light.shadow_color = p["shadow_color"]


func _configure(l: PointLight2D, p: Dictionary, h: Handle) -> void:
	var tex := AmbianceTextures.get_tex(p["texture"])
	if l.texture != tex:
		l.texture = tex
	l.color = h.color_override if h.color_override.a > 0.0 else p["color"]
	l.height = float(p["height"])
	l.range_item_cull_mask = MASK_LIT | (MASK_PUDDLES if bool(p["reflect"]) else 0)
	l.visible = true
	l.enabled = true


func _update_lights(delta: float) -> void:
	for h in _assigned:
		var hh := h as Handle
		var l := hh.light
		if l == null:
			continue
		var p := get_preset(hh.preset)
		var cat_scale: Vector2 = category_scale.get(p["category"], Vector2.ONE)
		if not hh._ramp.is_empty():
			var rp: Dictionary = hh._ramp
			rp["t"] = float(rp["t"]) + delta
			var u := clampf(float(rp["t"]) / float(rp["d"]), 0.0, 1.0)
			hh.radius_mult = lerpf(rp["r0"], rp["r1"], u)
			hh.energy_mult = lerpf(rp["e0"], rp["e1"], u)
			if u >= 1.0:
				hh._ramp = {}
		var target_e := float(p["energy"]) * hh.energy_mult * cat_scale.y
		var fl := float(p["flicker"])
		var fhz := float(p["flicker_hz"])
		if hh.flicker_override.x >= 0.0:
			fl = hh.flicker_override.x
			fhz = hh.flicker_override.y
		if fl > 0.0:
			target_e *= 1.0 + fl * (sin(_time * fhz * TAU + hh.seed) * 0.6 + sin(_time * fhz * 2.71 * TAU + hh.seed * 3.1) * 0.4)
		var hz := float(p["pulse_hz"]) * hh.rate_mult
		if p["pulse_shape"] == &"heartbeat":
			target_e *= heartbeat(_time * hz + hh.seed)
		elif float(p["pulse"]) > 0.0:
			target_e *= 1.0 + float(p["pulse"]) * sin(_time * hz * TAU + hh.seed)
		if p["category"] == &"boss":
			target_e = minf(target_e, BOSS_LIGHT_MAX_ENERGY)
		var omax := float(p["outage_max"])
		if omax > 0.0:
			hh._outage_t -= delta
			if hh._outage_t <= 0.0:
				hh._outage_t = randf_range(float(p["outage_min"]), omax) * outage_scale
				hh._outage_left = float(p["outage_ms"]) / 1000.0
		if hh._outage_left > 0.0:
			hh._outage_left -= delta
			target_e = 0.0
		if hh.lifetime > 0.0:
			hh.age += delta
			var v := clampf(hh.age / hh.lifetime, 0.0, 1.0)
			hh.current_energy = target_e * (1.0 - v) * (1.0 - v)
			if v >= 1.0:
				hh.released = true
		elif hh._outage_left > 0.0:
			hh.current_energy = 0.0
		else:
			hh.current_energy = lerpf(hh.current_energy, target_e, clampf(delta / hh.fade_s, 0.0, 1.0))
		# perf : n'écrit vers le RenderingServer que ce qui a changé (lumières fixes : rien par image)
		if l.energy != hh.current_energy:
			l.energy = hh.current_energy
		var w := float(l.texture.get_width()) if l.texture != null else 256.0
		var ts := maxf(float(p["radius_u"]) * hh.radius_mult * cat_scale.x * UNIT_PX * 2.0 / w, 0.001)
		if l.texture_scale != ts:
			l.texture_scale = ts
		if float(p["spin_dps"]) != 0.0:
			l.rotation = deg_to_rad(_time * float(p["spin_dps"]))
		var wp := hh.world_position()
		if l.position != wp: # le pool est à l'origine (LightRig enfant d'AmbianceManager, lui-même à l'origine)
			l.global_position = wp


func _take_light() -> PointLight2D:
	for l in _pool:
		if not l.visible:
			return l
	var nl := PointLight2D.new()
	nl.name = "PooledLight%d" % _pool.size()
	nl.blend_mode = Light2D.BLEND_MODE_ADD
	nl.range_z_min = RANGE_Z_MIN
	nl.range_z_max = RANGE_Z_MAX
	nl.shadow_item_cull_mask = MASK_WORLD
	add_child(nl)
	_pool.append(nl)
	return nl


func _free_light(l: PointLight2D) -> void:
	l.visible = false
	l.enabled = false
	l.shadow_enabled = false
	l.energy = 0.0


func _shrink_pool(max_n: int) -> void:
	for i in range(_pool.size() - 1, -1, -1):
		if _pool.size() <= max_n:
			break
		var l := _pool[i]
		if not l.visible:
			_pool.remove_at(i)
			l.queue_free()


func _view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(-1e6, -1e6, 2e6, 2e6)
	var xf := vp.get_canvas_transform().affine_inverse()
	var size := vp.get_visible_rect().size
	return Rect2(xf.origin, size * xf.get_scale())
