class_name AmbianceLightning
extends Node
## Éclairs de décor et foudre de gameplay, séquence Direction §3.4 :
## flash additif `#E8ECFF` (CanvasLayer 6) 0 → 0,60 × intensité en 1 image, tenu 80 ms, décroissance
## exponentielle 160 ms ; double flash (120 ms, 0,4) selon le profil ; directionnelle → énergie de
## flash, couleur `#E8ECFF`, rotation 280-340°, ombres 2,5 u (Haut), retour en 160 ms ; bolt dans
## le haut de l'écran (50 %, Haut) ; reflets blancs dans l'eau ; tonnerre après 0,3 s + distance
## × 0,35 s ; extinction d'une lampe (60 %, 300 ms après) ; cloche d'alerte.
## Garde-fous : >= 4 s entre deux événements, <= 3 flashs par 10 s ; option « secousses et
## flashs » (Quality.flashes_level) : réduit ×0,25, aucun = directionnelle ×0,5 + son seulement.

signal struck(world_pos: Vector2, intensity: float, gameplay: bool)
signal thunder(intensity: float, delay_s: float) ## émis au flash (pour planifier l'audio)
signal thunder_rumble(intensity: float) ## émis au moment du tonnerre
signal shake_requested(amplitude_px: float, hz: float, duration_s: float)

const FLASH_COLOR := Color(0.91, 0.925, 1.0) # #E8ECFF
const FLASH_ALPHA := 0.60
const HOLD_S := 0.08
const DECAY_S := 0.16
const DOUBLE_DELAY_S := 0.12
const MIN_GAP_S := 4.0
const MAX_PER_10S := 3

var mgr: Node = null ## AmbianceManager
var flash_rect: ColorRect
var bolt: Sprite2D
var horizon: Sprite2D

var _next_t := -1.0
var _next_h := -1.0
var _clock := 0.0
var _last_event := -100.0
var _history: Array[float] = []
var _flash_q: Array = [] ## [{t0, alpha}]
var _sun_t := -1.0
var _sun_from := {}
var _sun_flash := {}
var _pending: Array = [] ## [{t, kind, data}]
var _bolt_t := -1.0
var _hz_t := -1.0


func _process(delta: float) -> void:
	_clock += delta
	if mgr == null:
		return
	var p: Dictionary = mgr.current_params()
	if p.is_empty():
		return
	_schedule(p)
	_run_flash()
	_run_sun()
	_run_pending()
	if bolt != null and _bolt_t >= 0.0:
		_bolt_t += delta
		bolt.modulate.a = 0.9 if _bolt_t < HOLD_S else 0.0
		if _bolt_t >= HOLD_S:
			_bolt_t = -1.0
			bolt.visible = false
	if horizon != null and _hz_t >= 0.0:
		_hz_t += delta
		horizon.modulate.a = 0.15 * maxf(0.0, 1.0 - _hz_t / 0.3)
		if _hz_t >= 0.3:
			_hz_t = -1.0
			horizon.visible = false


func reset_schedule() -> void:
	_next_t = -1.0
	_next_h = -1.0


func _schedule(p: Dictionary) -> void:
	var mx := float(p[&"lightning_interval_max"])
	if mx > 0.0 and float(p[&"lightning_flash"]) > 0.0:
		if _next_t < 0.0:
			_next_t = _clock + randf_range(float(p[&"lightning_interval_min"]), mx)
		elif _clock >= _next_t:
			_next_t = -1.0
			strike_decor(p)
	else:
		_next_t = -1.0
	var hmx := float(p[&"horizon_interval_max"])
	if hmx > 0.0 and mx <= 0.0:
		if _next_h < 0.0:
			_next_h = _clock + randf_range(float(p[&"horizon_interval_min"]), hmx)
		elif _clock >= _next_h:
			_next_h = -1.0
			horizon_glow()
	else:
		_next_h = -1.0


## Vrai si un nouvel éclair respecte les garde-fous photosensibles.
func can_flash() -> bool:
	if _clock - _last_event < MIN_GAP_S:
		return false
	var recent := 0
	for t in _history:
		if _clock - t < 10.0:
			recent += 1
	return recent < MAX_PER_10S


## Nombre de flashs déclenchés dans les 10 dernières secondes (tests).
func flashes_last_10s() -> int:
	var n := 0
	for t in _history:
		if _clock - t < 10.0:
			n += 1
	return n


## Éclair de décor (planifié par le profil).
func strike_decor(p: Dictionary) -> bool:
	if not can_flash():
		return false
	var intensity := float(p[&"lightning_flash"])
	var double := randf() < float(p[&"lightning_double_chance"])
	_strike(intensity, double, p, Vector2.INF, false)
	return true


## Foudre de gameplay (Sonneur phase 2 : 0,35 ; pilier terminé : 0,5). Pas de garde-fou de
## fréquence pour le gameplay, mais l'option d'accessibilité s'applique.
func strike_gameplay(world_pos: Vector2, alpha: float, immediate_thunder: bool) -> void:
	var p: Dictionary = mgr.current_params()
	_strike(alpha / FLASH_ALPHA, false, p, world_pos, true, immediate_thunder)


func horizon_glow() -> void:
	if horizon == null or horizon.texture == null:
		return
	horizon.visible = true
	_hz_t = 0.0
	_place_horizon()


func _strike(intensity: float, double: bool, p: Dictionary, world_pos: Vector2, gameplay: bool, immediate_thunder: bool = false) -> void:
	_last_event = _clock
	_history.append(_clock)
	while _history.size() > 8:
		_history.pop_front()
	var acc := Quality.flash_mult()
	var a := clampf(FLASH_ALPHA * intensity * acc, 0.0, FLASH_ALPHA)
	if a > 0.0:
		_flash_q.append({"t0": _clock, "alpha": a})
		if double:
			_flash_q.append({"t0": _clock + DOUBLE_DELAY_S, "alpha": minf(0.4 * intensity * acc, FLASH_ALPHA)})
	# Directionnelle
	var sun: DirectionalLight2D = mgr.get(&"sun")
	if sun != null and sun.visible and bool(Quality.get_setting(&"lightning_sun")) and float(p.get(&"lightning_sun", 1.0)) > 0.5:
		var e := float(p[&"lightning_sun_energy"]) * (0.5 if Quality.flashes_level == 0 else 1.0)
		_sun_from = {"energy": sun.energy, "color": sun.color, "rot": sun.rotation_degrees, "len": sun.max_distance, "sh": sun.shadow_enabled}
		_sun_flash = {"energy": e, "rot": randf_range(280.0, 340.0)}
		_sun_t = 0.0
		sun.energy = e
		sun.color = FLASH_COLOR
		sun.rotation_degrees = _sun_flash["rot"]
		if bool(Quality.get_setting(&"lightning_extras")) and bool(Quality.get_setting(&"sun_shadows")):
			sun.shadow_enabled = true
			sun.max_distance = maxf(sun.max_distance, AmbianceManager.SUN_SHADOW_CULL_PX) # v2 : zone de projection entière
	var extras := bool(Quality.get_setting(&"lightning_extras"))
	# Bolt dans le haut de l'écran
	if extras and bolt != null and bolt.texture != null and randf() < float(p[&"lightning_bolt_chance"]):
		bolt.visible = true
		_bolt_t = 0.0
		_place_bolt()
	# Rayons (carte 3)
	var nr := roundi(float(p[&"lightning_rays"]))
	if extras and nr > 0 and mgr.has_method(&"spawn_rays"):
		var vr: Rect2 = mgr.view_rect()
		mgr.spawn_rays(Vector2(vr.get_center().x, vr.position.y + vr.size.y * 0.3), nr, 0.30, 0.4, Color.html("#DCE4FF"), 88.0)
	# Reflets dans l'eau
	var water = mgr.get(&"water")
	if water != null:
		water.flash()
	# Lampes : surtension
	if randf() < 0.6:
		_pending.append({"t": _clock + 0.3, "kind": &"lamp"})
	if mgr.has_method(&"_on_lightning_bell"):
		mgr._on_lightning_bell()
	# Tonnerre : distance virtuelle 0-6, pondérée vers le proche quand D monte
	var d_val := float(mgr.get(&"difficulty"))
	var near_bias := clampf((d_val - 1.0) / 6.0, 0.0, 1.0)
	var dist := 0.0 if immediate_thunder else (randf_range(0.0, 1.5) if randf() < 0.2 + 0.5 * near_bias else randf_range(0.0, 6.0))
	var delay := 0.3 + dist * 0.35
	if immediate_thunder:
		delay = 0.1
	thunder.emit(intensity, delay)
	_pending.append({"t": _clock + delay, "kind": &"thunder", "intensity": intensity})
	struck.emit(world_pos, intensity, gameplay)
	if mgr.get_node_or_null(^"/root/Events") != null:
		var ev := mgr.get_node_or_null(^"/root/Events")
		if ev != null and ev.has_signal(&"lightning_struck"):
			ev.emit_signal(&"lightning_struck", intensity, world_pos)


func _run_flash() -> void:
	var a := 0.0
	for i in range(_flash_q.size() - 1, -1, -1):
		var f: Dictionary = _flash_q[i]
		var t := _clock - float(f["t0"])
		if t < 0.0:
			continue
		var v := 0.0
		if t < HOLD_S:
			v = float(f["alpha"])
		else:
			v = float(f["alpha"]) * exp(-(t - HOLD_S) / (DECAY_S / 4.0))
			if t > HOLD_S + DECAY_S:
				_flash_q.remove_at(i)
				v = 0.0
		a = maxf(a, v)
	if flash_rect != null:
		flash_rect.color = Color(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, a)
		flash_rect.visible = a > 0.001


## Alpha courant du flash (tests).
func flash_alpha() -> float:
	return flash_rect.color.a if flash_rect != null and flash_rect.visible else 0.0


func _run_sun() -> void:
	if _sun_t < 0.0:
		return
	var sun: DirectionalLight2D = mgr.get(&"sun")
	if sun == null:
		_sun_t = -1.0
		return
	_sun_t += get_process_delta_time()
	if _sun_t < HOLD_S:
		return
	var u := clampf((_sun_t - HOLD_S) / DECAY_S, 0.0, 1.0)
	sun.energy = lerpf(_sun_flash["energy"], _sun_from["energy"], u)
	sun.color = FLASH_COLOR.lerp(_sun_from["color"], u)
	sun.rotation_degrees = lerpf(_sun_flash["rot"], _sun_from["rot"], u)
	if u >= 1.0:
		sun.max_distance = _sun_from["len"]
		sun.shadow_enabled = _sun_from["sh"]
		_sun_t = -1.0


## Vrai pendant un flash de directionnelle (AmbianceManager ne pilote pas le soleil pendant ce temps).
func sun_busy() -> bool:
	return _sun_t >= 0.0


func _run_pending() -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var e: Dictionary = _pending[i]
		if _clock < float(e["t"]):
			continue
		_pending.remove_at(i)
		match e["kind"]:
			&"thunder":
				var inten := float(e["intensity"])
				thunder_rumble.emit(inten)
				var p: Dictionary = mgr.current_params()
				# Tremblement 1 px à 12 Hz pendant 400 ms à Cataclysme (désactivable)
				if float(mgr.get(&"difficulty")) >= 6.0 and Quality.flashes_level == 2:
					shake_requested.emit(1.0, 12.0, 0.4)
			&"lamp":
				if mgr.has_method(&"outage_random_lamp"):
					mgr.outage_random_lamp(120.0)


func _place_bolt() -> void:
	var vr: Rect2 = mgr.view_rect()
	var tex := bolt.texture
	var h := vr.size.y * 0.45
	bolt.scale = Vector2.ONE * h / maxf(float(tex.get_height()), 1.0)
	bolt.position = Vector2(randf_range(0.15, 0.85) * flash_rect.size.x, h * 0.5)
	bolt.flip_h = randf() < 0.5


func _place_horizon() -> void:
	var tex := horizon.texture
	var w := flash_rect.size.x
	horizon.scale = Vector2.ONE * w / maxf(float(tex.get_width()), 1.0)
	horizon.position = Vector2(w * 0.5, float(tex.get_height()) * horizon.scale.y * 0.5)
