class_name EpreuveRitual
extends Epreuve
## Rituel (docs/Boucle_Etage_Refonte.md §1.1) : trois relais (EpreuveRelay, levier de secret à maintien de
## Balance.RITUAL_HOLD_S s) à 10-14 u autour d'un cœur qui PULSE : toutes les Balance.RITUAL_PULSE_S[relais fermés] s
## (12 -> 9 -> 7), un anneau télégraphié Balance.RITUAL_TELEGRAPH_S s (>= 0,8 s) puis une onde qui s'étend depuis le cœur ;
## l'onde inflige un coup de mini-boss (coef Balance.RITUAL_RING_COEF) si elle croise le joueur, une fois par onde. Trois
## relais fermés -> le cœur s'ouvre, le mini-boss apparaît. Parfait : durée <= EPREUVE_TARGET_S[rituel] et aucune onde reçue.
## Le cœur est le pilier lui-même (sprite de petit pilier). Placeholders : anneau et onde dessinés au sol.

var relays: Array[EpreuveRelay] = []
var closed := 0 ## relais fermés
var ring_hits := 0 ## ondes reçues par le joueur
var pulses := 0 ## ondes émises (mesure)
var _pulse_t := 0.0 ## s avant le prochain anneau
var _tele_t := 0.0 ## s restantes du télégraphe (> 0 : anneau annoncé)
var _wave_r := -1.0 ## rayon de l'onde (px), < 0 : aucune
var _wave_hit := false
var _wave_hit_ids: Array = [] ## coop : joueurs déjà touchés par l'onde courante (un coup par joueur et par onde)


## Rituel de cœur `heart` et de relais `relay_pts` (repère local de la carte). `skin` = déclinaison de sprites des relais
## (`lever_<skin>_{off,on}` : terraces, fog_forest, rust_city, crypts ; EpreuveData.lever_skin(biome)).
static func make(heart: Vector2, relay_pts: Array, skin: StringName = SecretLever.DEFAULT_BIOME) -> EpreuveRitual:
	var r := EpreuveRitual.new()
	r.position = heart
	for pt in relay_pts:
		var rl := EpreuveRelay.new()
		rl.epreuve = r
		rl.biome = skin
		rl.position = (pt as Vector2) - heart
		rl.activated.connect(r._on_relay_closed.bind(rl))
		r.relays.append(rl)
		r.add_child(rl)
	return r


func _init() -> void:
	verb = &"rituel"


func zone_radius() -> float:
	return Balance.RITUAL_ZONE_RADIUS_U * Balance.UNIT_PX


func progress() -> float:
	return float(closed) / float(maxi(relays.size(), 1))


func _begin() -> void:
	closed = 0
	ring_hits = 0
	pulses = 0
	_pulse_t = Balance.ritual_pulse_s(0)
	_tele_t = 0.0
	_wave_r = -1.0
	_wave_hit = false


func _run(delta: float) -> void:
	if _wave_r >= 0.0:
		_step_wave(delta)
	elif _tele_t > 0.0:
		_tele_t -= delta
		if _tele_t <= 0.0:
			_tele_t = 0.0
			_wave_r = 0.0
			_wave_hit = false
			_wave_hit_ids.clear()
			pulses += 1
	else:
		_pulse_t -= delta
		if _pulse_t <= 0.0:
			_tele_t = Balance.RITUAL_TELEGRAPH_S


func _step_wave(delta: float) -> void:
	var step := Balance.RITUAL_WAVE_SPEED_U * Balance.UNIT_PX * delta
	_wave_r += step
	var half := Balance.RITUAL_WAVE_HALF_U * Balance.UNIT_PX
	if is_inside_tree():
		for pl: Node2D in Players.alive().duplicate():
			if _wave_hit_ids.has(pl.get_instance_id()):
				continue
			var d := pl.global_position.distance_to(global_position)
			if absf(d - _wave_r) <= half + step * 0.5:
				_wave_hit_ids.append(pl.get_instance_id())
				_wave_hit = true
				ring_hits += 1
				clean = false
				if pl.has_method(&"take_damage"):
					pl.call(&"take_damage", Balance.ritual_ring_damage(RunState.difficulty()), self)
	if _wave_r > Balance.RITUAL_WAVE_MAX_U * Balance.UNIT_PX:
		_wave_r = -1.0
		_pulse_t = Balance.ritual_pulse_s(closed)


func _on_relay_closed(_relay: EpreuveRelay) -> void:
	closed = 0
	for r in relays:
		if r.used:
			closed += 1
	_pulse_t = minf(_pulse_t, Balance.ritual_pulse_s(closed)) # le cœur accélère
	if closed >= relays.size() and is_running():
		_resolve()


## Cadence courante du cœur (s) : 12 / 9 / 7 selon les relais fermés.
func pulse_interval() -> float:
	return Balance.ritual_pulse_s(closed)


func is_telegraphing() -> bool:
	return _tele_t > 0.0


func wave_radius() -> float:
	return _wave_r


func pulse_left() -> float:
	return _pulse_t


func _extra_dict() -> Dictionary:
	var ids: Array = []
	for i in relays.size():
		if relays[i].used:
			ids.append(i)
	return {"closed": ids, "pulse": _pulse_t, "hits": ring_hits, "pulses": pulses}


func _extra_restore(d: Dictionary) -> void:
	for i in d.get("closed", []):
		if int(i) >= 0 and int(i) < relays.size():
			relays[int(i)].pull(true)
	closed = 0
	for r in relays:
		if r.used:
			closed += 1
	_pulse_t = float(d.get("pulse", Balance.ritual_pulse_s(closed)))
	ring_hits = int(d.get("hits", 0))
	pulses = int(d.get("pulses", 0))
	_tele_t = 0.0
	_wave_r = -1.0


func _on_resolved() -> void:
	_tele_t = 0.0
	_wave_r = -1.0


func draw_overlay(c: Node2D) -> void:
	if state == Pillar.STATE_DONE:
		return
	var active := is_running()
	# relais : anneau de portée, vert une fois fermé
	for r in relays:
		var p := c.to_local(r.global_position)
		var col := Color(0.4, 0.95, 0.5, 0.55) if r.used else (Color(0.55, 0.9, 1.0, 0.65) if active else Color(0.55, 0.9, 1.0, 0.25))
		c.draw_arc(p, Balance.SECRET_LEVER_RANGE_U * Balance.UNIT_PX, 0.0, TAU, 32, col, 3.0)
		if active:
			c.draw_line(Vector2.ZERO, p, Color(col.r, col.g, col.b, 0.18), 2.0)
	if not active:
		return
	# cœur : jauge du prochain anneau
	var cadence := Balance.ritual_pulse_s(closed)
	var fill := 1.0 - clampf(_pulse_t / cadence, 0.0, 1.0) if _tele_t <= 0.0 and _wave_r < 0.0 else 1.0
	c.draw_arc(Vector2.ZERO, 70.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 48, Color(1.0, 0.55, 0.3, 0.9), 6.0)
	var rmax := Balance.RITUAL_WAVE_MAX_U * Balance.UNIT_PX
	if _tele_t > 0.0: # télégraphe : disque annoncé, bord qui se renforce
		var k := 1.0 - _tele_t / Balance.RITUAL_TELEGRAPH_S
		c.draw_circle(Vector2.ZERO, rmax, Color(1.0, 0.25, 0.2, 0.05 + 0.10 * k))
		c.draw_arc(Vector2.ZERO, rmax, 0.0, TAU, 96, Color(1.0, 0.3, 0.2, 0.35 + 0.5 * k), 4.0)
	if _wave_r >= 0.0:
		c.draw_arc(Vector2.ZERO, _wave_r, 0.0, TAU, 96, Color(1.0, 0.35, 0.25, 0.85), Balance.RITUAL_WAVE_HALF_U * Balance.UNIT_PX * 2.0)
