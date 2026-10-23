extends Node
## Pool de voix : plafond par famille, plafond global, priorité, vol de voix (steal),
## limite d'instances simultanées d'un même son et intervalle minimum entre deux lancements.
## `spatial` = AudioStreamPlayer2D (atténuation par distance au listener), sinon AudioStreamPlayer.

class Voice extends RefCounted:
	var player: Node
	var family := ""
	var sound_id: StringName = &""
	var priority := 0
	var start_ms := 0
	var active := false

var spatial := true
var voices: Array[Voice] = []
var family_caps: Dictionary = {} ## famille -> plafond
var stats := {"played": 0, "stolen": 0, "dropped": 0}
var clock_ms: Callable = Callable() ## injectable pour les tests

var _active_by_family: Dictionary = {}
var _active_by_sound: Dictionary = {}
var _last_play_ms: Dictionary = {}
var _active_count := 0
var _seq := 0


func setup(total: int, is_spatial: bool, families: Dictionary, cap_scale := 1.0) -> void:
	spatial = is_spatial
	for fam: String in families:
		var cap := int(families[fam].get("cap", 4))
		family_caps[fam] = maxi(1, int(round(cap * cap_scale)))
	for i in total:
		var v := Voice.new()
		var p: Node = AudioStreamPlayer2D.new() if spatial else AudioStreamPlayer.new()
		add_child(p)
		v.player = p
		voices.append(v)


func now_ms() -> int:
	if clock_ms.is_valid():
		return int(clock_ms.call())
	return Time.get_ticks_msec()


func active_total() -> int:
	return _active_count


func active_in_family(fam: String) -> int:
	return int(_active_by_family.get(fam, 0))


func active_of_sound(id: StringName) -> int:
	return int(_active_by_sound.get(id, 0))


## Tente de jouer un son. Retourne vrai si une voix a été attribuée.
func request(def: Dictionary, id: StringName, stream: AudioStream, pos: Vector2, vol_db: float, pitch: float) -> bool:
	if stream == null:
		return false
	var now := now_ms()
	var prio := int(def.get("priority", 20))
	var fam := String(def.get("family", "misc"))
	var min_gap := int(def.get("min_interval_ms", 0))
	if min_gap > 0 and now - int(_last_play_ms.get(id, -1000000)) < min_gap:
		stats.dropped += 1
		return false
	# 1) instances simultanées du même son
	var max_inst := int(def.get("max_instances", 4))
	if active_of_sound(id) >= max_inst:
		var victim := _find_victim(prio, "", id)
		if victim == null:
			stats.dropped += 1
			return false
		_release(victim, true)
	# 2) plafond de la famille
	var cap := int(family_caps.get(fam, 4))
	if active_in_family(fam) >= cap:
		var victim := _find_victim(prio, fam, &"")
		if victim == null:
			stats.dropped += 1
			return false
		_release(victim, true)
	# 3) voix libre, sinon vol global
	var v := _free_voice()
	if v == null:
		var victim := _find_victim(prio, "", &"")
		if victim == null:
			stats.dropped += 1
			return false
		_release(victim, true)
		v = _free_voice()
		if v == null:
			stats.dropped += 1
			return false
	_start(v, def, id, stream, pos, vol_db, pitch, prio, fam, now)
	return true


func _free_voice() -> Voice:
	for v in voices:
		if not v.active:
			return v
	return null


## Voix à voler : priorité la plus basse (<= prio demandée), la plus ancienne en cas d'égalité.
func _find_victim(prio: int, fam: String, id: StringName) -> Voice:
	var best: Voice = null
	for v in voices:
		if not v.active:
			continue
		if fam != "" and v.family != fam:
			continue
		if id != &"" and v.sound_id != id:
			continue
		if v.priority > prio:
			continue
		if best == null or v.priority < best.priority or (v.priority == best.priority and v.start_ms < best.start_ms):
			best = v
	return best


func _start(v: Voice, def: Dictionary, id: StringName, stream: AudioStream, pos: Vector2, vol_db: float, pitch: float, prio: int, fam: String, now: int) -> void:
	v.active = true
	v.family = fam
	v.sound_id = id
	v.priority = prio
	_seq += 1
	v.start_ms = now * 1000 + (_seq % 1000) # ordre strict même dans la même milliseconde
	_active_count += 1
	_active_by_family[fam] = active_in_family(fam) + 1
	_active_by_sound[id] = active_of_sound(id) + 1
	_last_play_ms[id] = now
	stats.played += 1
	var p := v.player
	p.set("stream", stream)
	p.set("volume_db", vol_db)
	p.set("pitch_scale", clampf(pitch, 0.1, 4.0))
	p.set("bus", StringName(def.get("bus", "SFX")))
	if spatial:
		p.set("global_position", pos)
		p.set("max_distance", float(def.get("max_distance", 1400.0)))
		p.set("attenuation", float(def.get("attenuation", 1.6)))
		p.set("panning_strength", float(def.get("panning", 0.6)))
	if p.is_inside_tree():
		p.call("play")


func _release(v: Voice, stolen := false) -> void:
	if not v.active:
		return
	v.active = false
	_active_count -= 1
	_active_by_family[v.family] = maxi(0, active_in_family(v.family) - 1)
	_active_by_sound[v.sound_id] = maxi(0, active_of_sound(v.sound_id) - 1)
	if stolen:
		stats.stolen += 1
	if v.player.is_inside_tree():
		v.player.call("stop")


func stop_all() -> void:
	for v in voices:
		_release(v)


func _process(_delta: float) -> void:
	if _active_count == 0:
		return
	for v in voices:
		if v.active and v.player.is_inside_tree() and not bool(v.player.get("playing")):
			_release(v)
