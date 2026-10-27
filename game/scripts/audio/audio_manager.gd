extends Node
## Autoload `Audio` : bus, volumes persistés, pool de voix, puissance des coups, pas, UI,
## ducking, pause, tonnerre, et pilotage de l'AudioDirector (musique/ambiance par carte).
## Tout est piloté par des identifiants logiques (data/audio/sounds.json). Un son manquant = silence.

const SoundBank := preload("res://scripts/audio/sound_bank.gd")
const VoicePool := preload("res://scripts/audio/voice_pool.gd")
const AudioDirector := preload("res://scripts/audio/audio_director.gd")
const SynthFallback := preload("res://scripts/audio/synth_fallback.gd")

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"
const DEFAULT_VOLUMES := {"master": 1.0, "music": 0.8, "sfx": 1.0, "ambience": 0.8, "ui": 1.0}
const BUS_OF := {"master": "Master", "music": "Music", "sfx": "SFX", "ambience": "Ambience", "ui": "UI"}
const BUS_TREE := [["Music", "Master"], ["SFX", "Master"], ["Spells", "SFX"], ["Impacts", "SFX"],
		["Footsteps", "SFX"], ["UI", "SFX"], ["Ambience", "Master"]]
const PENTATONIC := [0, 2, 4, 7, 9]
const COIN_CHAIN_RESET_MS := 1500
const COIN_MAX_STEP := 12
const HIT_CELL_PX := 192.0
const STEP_TICK_S := 0.09
const NO_POS := Vector2(INF, INF)

signal volumes_changed

var bank: SoundBank
var game_pool: VoicePool
var ui_pool: VoicePool
var director: AudioDirector
var volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
## Vrai : la pièce est jouée ici sur Events.pickup_collected(&"gold") ; pickup_manager n'appelle
## alors plus play_coin() lui-même (pas de doublon).
var auto_gold_event := true
## Vrai : start_map() est lancé seul à Events.floor_started (carte devinée). La scène de jeu met
## false et appelle start_map(map_id) elle-même au bon moment (pas de double démarrage).
var auto_start_map := true
var mobile := false

var _rng := RandomNumberGenerator.new()
var _duck_db := 0.0
var _duck_target := 0.0
var _duck_rate_in := 60.0
var _duck_rate_out := 20.0
var _duck_hold := 0.0
var _paused := false
var _pause_mix := 0.0 ## 0..1 lissé
var _bus_cache: Dictionary = {}
var _save_timer := 0.0
## Fichier effectif des volumes (tests : fichier injecté, jamais le réglage réel du joueur).
var settings_path := SETTINGS_PATH
var _listener_cache := Vector2.ZERO
var _listener_frame := -1

var _hit_cells: Dictionary = {}
var _hit_events := 0
var _loops: Array = [] ## boucles actives (play_loop)
var _kill_cells: Dictionary = {}
var _last_hit_flush := {"events": 0, "played": 0}
## Audio mono (A11y-L9, audit A-12) : réglage accessibility/mono_audio (GameSettings, défaut false), appliqué sur le
## bus Master par un AudioEffectStereoEnhance à pan_pullout 0 (canal latéral L-R annulé = L et R identiques).
## Relu au plus une fois par seconde (MONO_POLL_S) : la bascule du panneau de réglages s'applique sans appel.
const MONO_POLL_S := 1.0
var mono := false
var _mono_poll := 0.0

var _coin_step := 0
var _chest_gen := 0 ## séquence légendaire de coffre en cours (minuteurs annulables)
var _chest_gen_landed := 0
var _coin_last_ms := -100000

var _step_timer := 0.0
var _player_prev := NO_POS
var _player_acc := 0.0
var _enemy_track: Dictionary = {} ## instance_id -> [Vector2 pos, float acc]

var _map_grid: Array = []
var _map_info: Dictionary = {}
var _surfaces: Dictionary = {}
var _floor_bosses := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	_rng.randomize()
	mobile = Platform.is_mobile()
	_ensure_buses()
	apply_mono(GameSettings.mono_audio())
	load_settings()
	_apply_volumes(true)
	bank = SoundBank.new()
	bank.load_json()
	if not bank.has_sound(&"pickup.coin"):
		bank.set_override(&"pickup.coin", [SynthFallback.make_ting()])
	var cap_scale := 0.6 if mobile else 1.0
	game_pool = VoicePool.new()
	game_pool.name = "GameVoices"
	game_pool.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game_pool)
	var total := int(bank.config.get("voices_mobile", 24)) if mobile else int(bank.config.get("voices_pc", 40))
	game_pool.setup(total, true, bank.families, cap_scale)
	ui_pool = VoicePool.new()
	ui_pool.name = "UIVoices"
	ui_pool.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_pool)
	ui_pool.setup(8, false, bank.families, 1.0)
	director = AudioDirector.new(bank)
	director.name = "AudioDirector"
	add_child(director)
	_connect_events()
	get_tree().node_added.connect(_on_node_added)


# ----------------------------------------------------------------------------------- bus

func _ensure_buses() -> void:
	for pair in BUS_TREE:
		if AudioServer.get_bus_index(pair[0]) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, pair[0])
			AudioServer.set_bus_send(i, pair[1])
	var m := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(m) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 3.0
		comp.attack_us = 20000.0
		comp.release_ms = 220.0
		comp.gain = 2.0
		AudioServer.add_bus_effect(m, comp)
		var lim: AudioEffect = AudioEffectHardLimiter.new() if ClassDB.class_exists("AudioEffectHardLimiter") else AudioEffectLimiter.new()
		AudioServer.add_bus_effect(m, lim)
	var mu := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(mu) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 20500.0
		AudioServer.add_bus_effect(mu, lp) # effet 0 : filtre de pause (voir _apply_bus_volumes)
		# Les 4 stems au palier 4 culminent à -1,3 dBFS : limiteur dédié (plafond -1,5 dB) après le filtre.
		var mlim: AudioEffect
		if ClassDB.class_exists("AudioEffectHardLimiter"):
			mlim = AudioEffectHardLimiter.new()
			mlim.set(&"ceiling_db", -1.5)
		else:
			mlim = AudioEffectLimiter.new()
			mlim.set(&"ceiling_db", -1.5)
		AudioServer.add_bus_effect(mu, mlim)


## Active / coupe le mono sur le bus Master (effet ajouté une fois, en tête de chaîne, puis activé / désactivé).
func apply_mono(on: bool) -> void:
	mono = on
	var m := AudioServer.get_bus_index("Master")
	if m == -1:
		return
	var idx := mono_effect_index()
	if idx == -1:
		if not on:
			return
		var fx := AudioEffectStereoEnhance.new()
		fx.pan_pullout = 0.0
		fx.time_pullout_ms = 0.0
		AudioServer.add_bus_effect(m, fx, 0)
		idx = 0
	AudioServer.set_bus_effect_enabled(m, idx, on)


## Index de l'effet mono sur Master (-1 s'il n'existe pas).
func mono_effect_index() -> int:
	var m := AudioServer.get_bus_index("Master")
	if m == -1:
		return -1
	for i in AudioServer.get_bus_effect_count(m):
		var fx := AudioServer.get_bus_effect(m, i)
		if fx is AudioEffectStereoEnhance and is_zero_approx((fx as AudioEffectStereoEnhance).pan_pullout):
			return i
	return -1


# ------------------------------------------------------------------------------ réglages

func load_settings() -> void:
	volumes = DEFAULT_VOLUMES.duplicate()
	var cf := ConfigFile.new()
	if cf.load(settings_path) == OK:
		for k: String in volumes:
			volumes[k] = clampf(float(cf.get_value(SETTINGS_SECTION, k, volumes[k])), 0.0, 1.0)


func save_settings() -> void:
	_save_timer = 0.0
	if settings_path == SETTINGS_PATH and (DisplayServer.get_name() == "headless" or Engine.get_write_movie_path() != ""):
		return # tests et captures : la config du joueur reste intacte (comme GameSettings.set_value)
	var cf := ConfigFile.new()
	cf.load(settings_path) # conserve les autres sections
	for k: String in volumes:
		cf.set_value(SETTINGS_SECTION, k, volumes[k])
	cf.save(settings_path)


## key : master | music | sfx | ambience | ui ; v : 0..1 linéaire. Persisté (différé 0,5 s).
func set_volume(key: String, v: float) -> void:
	if not volumes.has(key):
		return
	volumes[key] = clampf(v, 0.0, 1.0)
	_save_timer = 0.5
	_apply_volumes(false)
	volumes_changed.emit()


func get_volume(key: String) -> float:
	return float(volumes.get(key, 1.0))


func _apply_volumes(force: bool) -> void:
	for key: String in BUS_OF:
		var idx := AudioServer.get_bus_index(BUS_OF[key])
		if idx == -1:
			continue
		var db := -80.0 if float(volumes[key]) <= 0.001 else linear_to_db(float(volumes[key]))
		match key:
			"music":
				db += _duck_db - 9.0 * _pause_mix
			"ambience":
				db += _duck_db * 0.8 - 6.0 * _pause_mix
		if force or absf(float(_bus_cache.get(key, 999.0)) - db) > 0.05:
			_bus_cache[key] = db
			AudioServer.set_bus_volume_db(idx, db)
	var mu := AudioServer.get_bus_index("Music")
	if mu != -1 and AudioServer.get_bus_effect_count(mu) > 0:
		var lp := AudioServer.get_bus_effect(mu, 0)
		if lp is AudioEffectLowPassFilter:
			(lp as AudioEffectLowPassFilter).cutoff_hz = lerpf(20500.0, 1400.0, _pause_mix)


# ------------------------------------------------------------------------------- ducking

## Baisse Music et Ambience de `amount_db` (positif = fort) pendant `hold_s`, avec retour progressif.
func duck(amount_db: float, hold_s := 1.0, attack_s := 0.15, release_s := 1.2) -> void:
	var target := -absf(amount_db)
	if target < _duck_target or _duck_hold <= 0.0:
		_duck_target = target
		_duck_rate_in = absf(target) / maxf(attack_s, 0.02)
	_duck_hold = maxf(_duck_hold, hold_s)
	_duck_rate_out = absf(_duck_target) / maxf(release_s, 0.05)


func duck_event(kind: StringName) -> void:
	var d: Dictionary = bank.ducks.get(String(kind), {})
	if d.is_empty():
		return
	duck(float(d.get("db", 9.0)), float(d.get("hold", 1.0)), float(d.get("attack", 0.15)), float(d.get("release", 1.2)))


func current_duck_db() -> float:
	return _duck_db


# ---------------------------------------------------------------------------- lecture

func listener_pos() -> Vector2:
	var f := Engine.get_process_frames()
	if f == _listener_frame:
		return _listener_cache
	_listener_frame = f
	var vp := get_viewport()
	var cam: Camera2D = vp.get_camera_2d() if vp != null else null
	if cam != null:
		_listener_cache = cam.get_screen_center_position()
	else:
		var pl := get_tree().get_first_node_in_group(&"player") as Node2D
		_listener_cache = pl.global_position if pl != null else Vector2.ZERO
	return _listener_cache


## Son de jeu (suspendu avec l'arbre). `pos` = NO_POS (défaut) : au niveau du listener.
func play(id: StringName, pos: Vector2 = NO_POS, vol_db := 0.0, pitch := 1.0) -> bool:
	return _play_on(game_pool, id, pos, vol_db, pitch)


## Boucle liée à un nœud (bourdon, marée, ambiance de boss). Retourne une poignée (Dictionary) ou {} si le son est
## absent / pas de voix libre (repli silencieux). Arrêtée par stop_loop ou quand `host` sort de l'arbre.
## Suit la position de `host` s'il est un Node2D.
func play_loop(id: StringName, host: Node, vol_db := 0.0, pitch := 1.0) -> Dictionary:
	if game_pool == null or bank == null or host == null or not is_instance_valid(host):
		return {}
	var stream := bank.pick_stream(id)
	if stream == null:
		return {}
	var def := bank.get_def(id)
	var at := listener_pos()
	if host is Node2D:
		at = (host as Node2D).global_position
	if not game_pool.request(def, id, SoundBank.looped(stream), at, float(def.get("vol_db", 0.0)) + vol_db, pitch):
		return {}
	var v := game_pool.last_started
	if v == null:
		return {}
	var h := {"voice": v, "id": id, "start": v.start_ms, "host": host}
	_loops.append(h)
	return h


func stop_loop(handle: Dictionary) -> void:
	if handle.is_empty():
		return
	_loops.erase(handle)
	var v: VoicePool.Voice = handle.get("voice")
	if v != null and v.active and v.sound_id == handle.get("id") and v.start_ms == handle.get("start"):
		game_pool._release(v)


func active_loops() -> int:
	return _loops.size()


func _update_loops() -> void:
	var i := _loops.size() - 1
	while i >= 0:
		var h: Dictionary = _loops[i]
		var v: VoicePool.Voice = h["voice"]
		var o: Variant = h["host"]
		var alive: bool = v.active and v.sound_id == h["id"] and v.start_ms == h["start"] # sinon : voix volée
		if not alive:
			_loops.remove_at(i)
		elif not is_instance_valid(o) or not (o as Node).is_inside_tree():
			stop_loop(h)
		elif o is Node2D:
			v.player.set("global_position", (o as Node2D).global_position)
		i -= 1


## Son d'interface (continue pendant la pause).
func play_ui(id: StringName, vol_db := 0.0, pitch := 1.0) -> bool:
	return _play_on(ui_pool, id, NO_POS, vol_db, pitch)


func _play_on(pool: VoicePool, id: StringName, pos: Vector2, vol_db: float, pitch: float) -> bool:
	if pool == null or bank == null:
		return false
	var stream := bank.pick_stream(id)
	if stream == null:
		return false
	var def := bank.get_def(id)
	var at := pos
	if pool.spatial:
		var l := listener_pos()
		if not is_finite(pos.x):
			at = l
		elif pos.distance_to(l) > float(def.get("max_distance", 1400.0)):
			return false # trop loin : pas de voix gaspillée
	var pv := float(def.get("pitch_var", 0.05))
	var vv := float(def.get("vol_var_db", 1.0))
	var v := float(def.get("vol_db", 0.0)) + vol_db + _rng.randf_range(-vv, vv)
	var p := pitch * (1.0 + _rng.randf_range(-pv, pv))
	return pool.request(def, id, stream, at, v, p)


func _first_available(ids: Array) -> StringName:
	for i in ids:
		if bank.has_sound(StringName(i)):
			return StringName(i)
	return &""


# -------------------------------------------------------------------- puissance des coups

## Classe un coup : {name, level 0..2, ratio, t 0..1, vol_db, pitch}. Pur, testable.
static func classify_hit(damage: float, base_damage: float, is_crit: bool, cfg: Dictionary = {}) -> Dictionary:
	var light_max := float(cfg.get("light_max", 1.4))
	var medium_max := float(cfg.get("medium_max", 3.2))
	var ratio := damage / maxf(base_damage, 1.0)
	var level := 0 if ratio < light_max else (1 if ratio < medium_max else 2)
	if is_crit:
		level = mini(2, level + 1)
	var t := clampf(ratio / float(cfg.get("full_ratio", 6.0)), 0.0, 1.0)
	return {
		"name": ["light", "medium", "heavy"][level],
		"level": level,
		"ratio": ratio,
		"t": t,
		"vol_db": float(cfg.get("vol_min_db", -6.0)) + float(cfg.get("vol_range_db", 8.0)) * t + (2.0 if is_crit else 0.0),
		"pitch": float(cfg.get("pitch_max", 1.12)) - float(cfg.get("pitch_range", 0.22)) * t + (0.05 if is_crit else 0.0),
	}


## Coup subi par un ennemi. Mis en file et fusionné par zone (joué en fin d'image, flush_hits()).
## Le système de sorts peut l'appeler avec l'id du sort ; Events.enemy_damaged alimente la même file.
func play_hit(spell_id: StringName, damage: float, is_crit: bool, pos: Vector2, element: StringName = &"") -> void:
	_queue_hit(spell_id, damage, is_crit, pos, element)


func _queue_hit(spell_id: StringName, damage: float, is_crit: bool, pos: Vector2, element: StringName) -> void:
	_hit_events += 1
	var cell := Vector2i(int(floorf(pos.x / HIT_CELL_PX)), int(floorf(pos.y / HIT_CELL_PX)))
	if not _hit_cells.has(cell):
		_hit_cells[cell] = {"dmg": damage, "crit": is_crit, "pos": pos, "spell": spell_id, "elem": element, "n": 1}
		return
	var e: Dictionary = _hit_cells[cell]
	if spell_id != &"" and e["spell"] == &"" and (e["pos"] as Vector2) == pos and is_equal_approx(float(e["dmg"]), damage):
		e["spell"] = spell_id # même coup déjà reçu via Events.enemy_damaged : on ne compte pas deux fois
		if element != &"":
			e["elem"] = element
		return
	e["n"] = int(e["n"]) + 1
	if damage > float(e["dmg"]):
		e["dmg"] = damage
		e["pos"] = pos
	if is_crit:
		e["crit"] = true
	if spell_id != &"":
		e["spell"] = spell_id
	if element != &"":
		e["elem"] = element


func _by_distance(a: Dictionary, b: Dictionary) -> bool:
	var l := _listener_cache
	return (a["pos"] as Vector2).distance_squared_to(l) < (b["pos"] as Vector2).distance_squared_to(l)


## Joue les coups en attente (chaque image ; public pour les tests).
func flush_hits() -> void:
	var played := 0
	if not _hit_cells.is_empty():
		listener_pos()
		var arr: Array = _hit_cells.values()
		arr.sort_custom(_by_distance)
		var budget := int(bank.config.get("hits_per_frame_mobile", 3)) if mobile else int(bank.config.get("hits_per_frame", 4))
		for e: Dictionary in arr:
			if played >= budget:
				break
			if _play_hit_now(e):
				played += 1
	_last_hit_flush = {"events": _hit_events, "played": played}
	_hit_cells.clear()
	_hit_events = 0
	_flush_kills()


func _play_hit_now(e: Dictionary) -> bool:
	var base := Balance.player_base_damage(RunState.level)
	var h := classify_hit(float(e["dmg"]), base, bool(e["crit"]), bank.config.get("hit_power", {}))
	var nm: String = h["name"]
	var spell := String(e["spell"])
	var elem := String(e["elem"])
	var cands: Array = []
	if spell != "":
		cands.append("spell.%s.hit_%s" % [spell, nm])
		cands.append("spell.%s.hit" % spell)
	if elem != "":
		cands.append("hit.%s.%s" % [elem, nm])
	cands.append("hit.%s" % nm)
	var id := _first_available(cands)
	if id == &"":
		return false
	var n := float(e["n"])
	var vol: float = float(h["vol_db"]) + minf(3.0, 1.5 * log(n) / log(2.0)) # coups fusionnés = un peu plus fort
	if bool(e["crit"]):
		play(&"hit.crit", e["pos"], vol - 3.0, float(h["pitch"])) # « crack » superposé au coup
	return play(id, e["pos"], vol, float(h["pitch"]))


func last_flush_stats() -> Dictionary:
	return _last_hit_flush


## Lancement d'un sort. `power` ~ rapport Dégât/Dégât_base (1 = normal) : hauteur/volume modulés.
func play_cast(spell_id: StringName, pos: Vector2, power := 1.0) -> void:
	var lvl := power_level(power)
	var id := _first_available(["spell.%s.cast_%s" % [spell_id, lvl], "spell.%s.cast" % spell_id, "spell.cast"])
	if id == &"":
		return
	var t := clampf(power / 6.0, 0.0, 1.0)
	play(id, pos, -3.0 + 5.0 * t, 1.08 - 0.18 * t)


## Variante légère / moyenne / lourde d'un lancement selon `power` (rapport Dégât attendu / Dégât_base,
## soit coef du sort × bonus d'items, cf. SpellCaster.cast_power). Seuils de config.hit_power.
func power_level(power: float) -> String:
	var cfg: Dictionary = bank.config.get("hit_power", {}) if bank != null else {}
	if power < float(cfg.get("light_max", 1.4)):
		return "light"
	return "medium" if power < float(cfg.get("medium_max", 3.2)) else "heavy"


## Ultime : son + ducking musique/ambiance.
func play_ultimate(spell_id: StringName, pos: Vector2, power := 1.0) -> void:
	var id := _first_available(["spell.%s.ultimate" % spell_id, "spell.%s.cast_%s" % [spell_id, power_level(power)],
			"spell.%s.cast" % spell_id, "spell.ultimate"])
	if id != &"":
		play(id, pos, 2.0)
	duck_event(&"ultimate")


# ------------------------------------------------------------------------------- morts

func _on_enemy_killed(_enemy: Node2D, pos: Vector2, tier: int, is_elite: bool) -> void:
	var cell := Vector2i(int(floorf(pos.x / HIT_CELL_PX)), int(floorf(pos.y / HIT_CELL_PX)))
	var rank := tier + (10 if is_elite else 0)
	if not _kill_cells.has(cell):
		_kill_cells[cell] = {"pos": pos, "tier": tier, "elite": is_elite, "rank": rank, "n": 1}
		return
	var e: Dictionary = _kill_cells[cell]
	e["n"] = int(e["n"]) + 1
	if rank > int(e["rank"]):
		e["rank"] = rank
		e["tier"] = tier
		e["elite"] = is_elite
		e["pos"] = pos


func _flush_kills() -> void:
	if _kill_cells.is_empty():
		return
	listener_pos()
	var arr: Array = _kill_cells.values()
	arr.sort_custom(_by_distance)
	var budget := int(bank.config.get("kills_per_frame", 3))
	var played := 0
	for e: Dictionary in arr:
		if played >= budget:
			break
		var cands: Array = []
		if bool(e["elite"]):
			cands.append("death.elite")
		cands.append("death.t%d" % clampi(int(e["tier"]), 1, 4))
		cands.append("death.generic")
		var id := _first_available(cands)
		var n := float(e["n"])
		if id != &"" and play(id, e["pos"], minf(3.0, 1.5 * log(n) / log(2.0))):
			played += 1
	_kill_cells.clear()


# ---------------------------------------------------------------------------------- pas

## Un pas. actor_kind : &"player", &"monster_t1".. &"monster_t3", &"boss" (ou id de personnage).
## surface : &"" = déduite de la carte courante. Les pas du joueur et des monstres proches sont
## déjà pilotés automatiquement (voir _step_tick) ; cet appel sert aux cas particuliers.
func footstep(actor_kind: StringName, pos: Vector2, surface: StringName = &"", vol_db := 0.0) -> bool:
	var s := surface if surface != &"" else surface_at(pos)
	var klass := "player" if actor_kind == &"player" else ("boss" if actor_kind == &"boss" else "monster")
	var id := _first_available(["step.%s.%s" % [actor_kind, s], "step.%s" % actor_kind,
			"step.%s.%s" % [klass, s], "step.%s" % klass, "step.%s" % s, "step.generic"])
	if id == &"":
		return false
	var fam := "footsteps_player" if klass == "player" else "footsteps_monster"
	var stream := bank.pick_stream(id)
	var def := bank.get_def(id)
	def.merge(bank.families.get(fam, {}), false)
	def["family"] = fam
	def["bus"] = bank.families.get(fam, {}).get("bus", "Footsteps")
	if pos.distance_to(listener_pos()) > float(def.get("max_distance", 900.0)):
		return false
	var pv := float(def.get("pitch_var", 0.08))
	var vv := float(def.get("vol_var_db", 1.5))
	return game_pool.request(def, id, stream, pos, float(def.get("vol_db", 0.0)) + vol_db + _rng.randf_range(-vv, vv),
			1.0 + _rng.randf_range(-pv, pv))


func surface_at(pos: Vector2) -> StringName:
	var fallback := StringName(_surfaces.get(".", "stone"))
	if _map_grid.is_empty():
		return fallback
	var u := float(_map_info.get("unit_px", 64.0))
	var cell_u := float(_map_info.get("grid_cell_u", 2.0))
	var size_u: Array = _map_info.get("size_u", [64, 56])
	var cx := int(floorf((pos.x / u + float(size_u[0]) * 0.5) / cell_u))
	var cy := int(floorf((pos.y / u + float(size_u[1]) * 0.5) / cell_u))
	if cy < 0 or cy >= _map_grid.size():
		return fallback
	var row: String = _map_grid[cy]
	if cx < 0 or cx >= row.length():
		return fallback
	return StringName(_surfaces.get(row[cx], fallback))


func _load_map_surfaces(id: String) -> void:
	_map_grid = []
	_map_info = {}
	_surfaces = bank.maps.get(id, bank.maps.get("default", {})).get("surfaces", {})
	var path := "res://data/maps/%s.json" % id
	if not FileAccess.file_exists(path):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) == TYPE_DICTIONARY:
		_map_grid = d.get("grid", [])
		_map_info = d


## Pilote les pas du joueur (cadence = distance parcourue / foulée) et des monstres proches.
func _step_tick(dt: float) -> void:
	var cfg: Dictionary = bank.config.get("steps", {})
	var pl := get_tree().get_first_node_in_group(&"player") as Node2D
	if pl != null:
		var p := pl.global_position
		var stride := float(cfg.get("player_stride", 105.0))
		if is_finite(_player_prev.x):
			var dist := p.distance_to(_player_prev)
			if dist < 400.0 and dist / dt > float(cfg.get("min_speed", 30.0)):
				_player_acc += dist
				if _player_acc >= stride:
					_player_acc = fmod(_player_acc, stride)
					footstep(&"player", p)
			else:
				_player_acc = minf(_player_acc, stride * 0.5)
		_player_prev = p
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	if enemies.is_empty():
		_enemy_track.clear()
		return
	var l := listener_pos()
	var radius := float(cfg.get("monster_radius", 650.0))
	var r2 := radius * radius
	var strides: Dictionary = cfg.get("monster_stride", {"1": 70.0, "2": 95.0, "3": 130.0, "4": 170.0})
	var fresh: Dictionary = {}
	var cells: Dictionary = {}
	for n in enemies:
		var e := n as Node2D
		if e == null or not e.visible or not e.is_processing():
			continue
		var ep := e.global_position
		if ep.distance_squared_to(l) > r2:
			continue
		var id := e.get_instance_id()
		var acc := 0.0
		if _enemy_track.has(id):
			var tr: Array = _enemy_track[id]
			var dist := ep.distance_to(tr[0])
			if dist < 200.0:
				acc = float(tr[1]) + dist
		var tier := clampi(int(e.get("tier")), 1, 4)
		var stride := float(strides.get(str(tier), 100.0))
		if acc >= stride:
			acc = fmod(acc, stride)
			var cell := Vector2i(int(floorf(ep.x / 160.0)), int(floorf(ep.y / 160.0)))
			if not cells.has(cell):
				cells[cell] = {"pos": ep, "tier": tier, "n": 1}
			else:
				var c: Dictionary = cells[cell]
				c["n"] = int(c["n"]) + 1
				c["tier"] = maxi(int(c["tier"]), tier)
		fresh[id] = [ep, acc]
	_enemy_track = fresh
	if cells.is_empty():
		return
	var arr: Array = cells.values()
	arr.sort_custom(_by_distance)
	var n_max := int(cfg.get("monster_steps_per_tick", 3))
	for i in mini(n_max, arr.size()):
		var c: Dictionary = arr[i]
		var tier := int(c["tier"])
		var kind := &"boss" if tier >= 4 else StringName("monster_t%d" % tier)
		var cnt := float(c["n"])
		footstep(kind, c["pos"], &"", minf(4.0, 1.5 * log(cnt) / log(2.0)))


# ------------------------------------------------------------------------------ ambiance

## Lance la musique et l'ambiance de la carte `id` (ex. "foret_brume").
func start_map(id: String) -> void:
	_load_map_surfaces(id)
	director.start_map(id)
	director.set_tier_by_name(Balance.difficulty_tier_name(RunState.difficulty()))
	_floor_bosses = 0


func current_map_id() -> String:
	return director.map_id if director != null else ""


## Tonnerre : distance virtuelle 0..6 (Direction_Lumiere §3.4), délai = 0,3 + d × 0,35 s.
func thunder(distance := 2.0) -> void:
	thunder_after(0.3 + distance * 0.35, distance)


func thunder_after(delay_s: float, distance := 2.0) -> void:
	if delay_s > 0.02:
		get_tree().create_timer(delay_s, false).timeout.connect(_play_thunder.bind(distance))
	else:
		_play_thunder(distance)


func _play_thunder(distance: float) -> void:
	var near := distance <= 1.5
	var id := _first_available(["amb.thunder_close" if near else "amb.thunder_far", "amb.thunder_far", "amb.thunder_close", "amb.thunder"])
	if id != &"":
		play(id, NO_POS, -2.5 * distance, 1.0 + _rng.randf_range(-0.04, 0.04) - 0.02 * distance)
		if near:
			duck(4.0, 0.4)


## Intensité de pluie 0..1 (ambiance) : module les couches marquées « rain ».
func set_rain_intensity(v: float) -> void:
	director.set_rain_scale(lerpf(0.5, 1.2, clampf(v, 0.0, 1.0)))


func _on_lightning(a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	# Signal d'éclair éventuel : un 1er argument numérique = délai du tonnerre (s), sinon tirage.
	if typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT:
		thunder_after(float(a), clampf((float(a) - 0.3) / 0.35, 0.0, 6.0))
		return
	var dist := _rng.randf_range(0.0, 6.0)
	if RunState.difficulty() >= 6.0 and _rng.randf() < 0.7:
		dist = _rng.randf_range(0.0, 1.5)
	thunder(dist)


# ------------------------------------------------------------------------------- UI / pickups

func ui_click() -> void:
	play_ui(&"ui.click")


func spell_ready(slot := 0) -> void:
	play_ui(&"ui.spell_ready", -4.0, 1.0 + 0.04 * slot)


func dice_roll() -> void:
	play_ui(&"ui.dice")


## Ting d'une pièce, en chaîne pentatonique (remplace CoinSound.play_coin()).
func play_coin() -> void:
	var now := Time.get_ticks_msec()
	if now - _coin_last_ms > COIN_CHAIN_RESET_MS:
		_coin_step = 0
	else:
		_coin_step = mini(_coin_step + 1, COIN_MAX_STEP)
	_coin_last_ms = now
	var semis: int = PENTATONIC[_coin_step % 5] + 12 * (_coin_step / 5)
	play_ui(&"pickup.coin", -2.0, pow(2.0, semis / 12.0))


func coin_chain_step() -> int:
	return _coin_step


func _on_pickup(kind: StringName, _amount: float) -> void:
	match kind:
		&"gold":
			if auto_gold_event:
				play_coin()
		&"xp":
			play_ui(&"pickup.xp", -6.0)
		&"ruby":
			play_ui(&"pickup.ruby")
		_:
			play_ui(StringName("pickup.%s" % kind))


func _on_chest_opened(_chest: Node, quality: StringName, _offered: Array) -> void:
	play_chest_sequence(quality)


## Verrou, ouverture, révélation ; Légendaire : montée, silence (ducking profond), impact.
func play_chest_sequence(quality: StringName) -> void:
	play_ui(&"chest.lock", -2.0)
	var q := String(quality)
	if q == "legendaire":
		duck_event(&"legendary_chest")
		play_ui(&"chest.legendary.rise")
		_chest_gen += 1
		var gen := _chest_gen
		get_tree().create_timer(1.4, true, false, true).timeout.connect(func() -> void:
			if gen == _chest_gen:
				play_ui(&"chest.legendary.impact", 3.0))
		get_tree().create_timer(1.6, true, false, true).timeout.connect(func() -> void:
			if gen == _chest_gen:
				play_ui(&"chest.reveal"))
	else:
		var id := _first_available(["chest.open.%s" % q, "chest.open"])
		get_tree().create_timer(0.25, true, false, true).timeout.connect(func() -> void:
			if id != &"":
				play_ui(id)
			play_ui(&"chest.reveal", -3.0))


## L'écran de coffre a posé la rareté (arrêt réel ou skip) : la frappe légendaire encore en attente
## est jouée maintenant (et plus au minuteur). Sans séquence légendaire en attente : rien.
func chest_sequence_land() -> void:
	if _chest_gen == _chest_gen_landed:
		return
	_chest_gen += 1 # annule les minuteurs de play_chest_sequence
	_chest_gen_landed = _chest_gen
	play_ui(&"chest.legendary.impact", 3.0)
	get_tree().create_timer(0.2, true, false, true).timeout.connect(func() -> void: play_ui(&"chest.reveal"))


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta(&"no_ui_sound"):
		(n as BaseButton).pressed.connect(ui_click)


# --------------------------------------------------------------------------------- Events

func _connect_events() -> void:
	Events.enemy_damaged.connect(_on_enemy_damaged)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.chest_opened.connect(_on_chest_opened)
	Events.pickup_collected.connect(_on_pickup)
	Events.floor_started.connect(_on_floor_started)
	Events.lightning_struck.connect(_on_lightning_struck)
	Events.floor_cleared.connect(func(_s: int) -> void: play_ui(&"stage.cleared"))
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_killed.connect(_on_boss_killed)
	Events.player_damaged.connect(func(_a: float, _s: Node) -> void: play(&"player.hurt"))
	Events.player_died.connect(_on_player_died)
	Events.item_chosen.connect(func(_i: StringName) -> void: play_ui(&"ui.item_pick"))
	RunState.level_up.connect(func(_l: int) -> void:
		play_ui(&"ui.level_up")
		duck(5.0, 0.6))
	RunState.difficulty_changed.connect(_on_difficulty)
	# Le tonnerre suit AmbianceManager.thunder (délai calculé par l'orage) : la scène de jeu le
	# branche sur thunder_after(). Events.lightning_struck ne sert qu'au grondement de secours.


func _on_enemy_damaged(enemy: Node2D, amount: float, is_crit: bool, element: StringName) -> void:
	if not is_instance_valid(enemy):
		return
	_queue_hit(&"", amount, is_crit, enemy.global_position, element)


func _on_difficulty(_d: float, tier_name: StringName) -> void:
	director.set_tier_by_name(tier_name)


func _on_floor_started(_stage: int) -> void:
	if auto_start_map:
		start_map(_find_map_id())


## Foudre sans AmbianceManager branché (tests, scènes simples) : tonnerre tiré au hasard.
## Avec la scène de jeu, `thunder_driven` est vrai et l'orage pilote thunder_after() lui-même.
var thunder_driven := false


func _on_lightning_struck(_intensity: float, _pos: Vector2) -> void:
	if not thunder_driven:
		_on_lightning()


func _find_map_id() -> String:
	var t := get_tree()
	var sm := t.get_first_node_in_group(&"stage_manager")
	if sm == null:
		sm = t.root.find_child("StageManager", true, false)
		if sm == null:
			sm = t.root.find_child("Stage", true, false)
	if sm != null:
		var v: Variant = sm.get("map_id")
		if v != null and String(v) != "":
			return String(v)
	var m := t.get_first_node_in_group(&"stage_map")
	if m != null and m.scene_file_path != "":
		return m.scene_file_path.get_file().get_basename()
	return "default"


func _on_boss_spawned(_boss: Node2D, is_floor_boss: bool) -> void:
	play(&"boss.spawn", NO_POS, 2.0)
	duck_event(&"boss")
	if is_floor_boss:
		_floor_bosses += 1
		director.set_boss(true)


func _on_boss_killed(boss: Node2D, is_floor_boss: bool) -> void:
	play(&"boss.defeat", NO_POS, 2.0)
	if is_instance_valid(boss):
		play(&"death.boss_heavy", boss.global_position, 1.0)
	duck_event(&"boss")
	if is_floor_boss:
		_floor_bosses = maxi(0, _floor_bosses - 1)
		if _floor_bosses == 0:
			director.set_boss(false)


func _on_player_died() -> void:
	play_ui(&"player.death")
	duck(12.0, 3.0, 0.3, 2.0)


# ---------------------------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	_mono_poll += delta
	if _mono_poll >= MONO_POLL_S:
		_mono_poll = 0.0
		var want := GameSettings.mono_audio()
		if want != mono:
			apply_mono(want)
	if bank == null:
		return
	flush_hits()
	_update_loops()
	# Pause : musique basse + passe-bas, SFX de jeu suspendus (pool pausable), UI continue.
	_paused = get_tree().paused
	var pm := move_toward(_pause_mix, 1.0 if _paused else 0.0, delta / 0.25)
	var changed := pm != _pause_mix
	_pause_mix = pm
	if _duck_hold > 0.0:
		_duck_hold -= delta
		var nd := move_toward(_duck_db, _duck_target, _duck_rate_in * delta)
		changed = changed or nd != _duck_db
		_duck_db = nd
	elif _duck_db != 0.0:
		_duck_db = move_toward(_duck_db, 0.0, _duck_rate_out * delta)
		_duck_target = 0.0
		changed = true
	if changed:
		_apply_volumes(false)
	if _save_timer > 0.0:
		_save_timer -= delta
		if _save_timer <= 0.0:
			save_settings()
	if not _paused:
		_step_timer += delta
		if _step_timer >= STEP_TICK_S:
			var dt := _step_timer
			_step_timer = 0.0
			_step_tick(dt)
