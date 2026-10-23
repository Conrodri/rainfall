extends Node
## Musique et ambiance d'une carte : stems synchronisés qui montent/descendent en fondu selon le
## palier de difficulté (Calme..Cataclysme), couches d'ambiance (pluie, vent, décor), thème de boss.
## Fonctionne même sans aucun fichier (les stems sans flux sont ignorés).

const TIERS: Array[StringName] = [&"Calme", &"Tendu", &"Hostile", &"Furieux", &"Cataclysme"]
const SILENT_AMP := 0.001
const SoundBankScript := preload("res://scripts/audio/sound_bank.gd")

class Stem extends RefCounted:
	var id: StringName = &""
	var group := "music" ## music | boss | amb
	var player: AudioStreamPlayer
	var amp := 0.0
	var target := 0.0
	var db_by_tier: Array = []
	var fade_s := 4.0
	var is_rain := false
	var stream: AudioStream
	var dying := false
	var boss_db := 0.0

var bank: RefCounted
var map_id := ""
var tier := 0
var boss_active := false
var rain_scale := 1.0
var stems: Array[Stem] = []
var _dying: Array[Stem] = []


func _init(p_bank: RefCounted = null) -> void:
	bank = p_bank
	process_mode = Node.PROCESS_MODE_ALWAYS


static func tier_index(tier_name: StringName) -> int:
	var i := TIERS.find(tier_name)
	return maxi(i, 0)


## Démarre (ou remplace) la musique et l'ambiance de la carte `id`. Les anciens stems fondent.
func start_map(id: String) -> void:
	for s in stems:
		_retire(s)
	stems.clear()
	map_id = id
	boss_active = false
	var cfg: Dictionary = {}
	if bank != null:
		var maps: Dictionary = bank.maps
		cfg = maps.get(id, maps.get("default", {}))
	var def_cfg: Dictionary = bank.maps.get("default", {}) if bank != null else {}
	_add_group(cfg.get("music", def_cfg.get("music", [])), "music")
	_add_group(cfg.get("ambience", def_cfg.get("ambience", [])), "amb")
	var boss_ids: Array = cfg.get("boss", def_cfg.get("boss", []))
	_add_group(boss_ids, "boss")
	_retarget(true)
	# Démarrage synchronisé : tous les stems audibles partent à 0,0 dans la même image.
	for s in stems:
		if s.group != "boss" and s.target > SILENT_AMP:
			_play_stem(s, 0.0)


func _add_group(list: Array, group: String) -> void:
	for e in list:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var s := Stem.new()
		s.id = StringName(e.get("id", ""))
		s.group = group
		s.db_by_tier = e.get("db", [0, 0, 0, 0, 0])
		s.fade_s = float(e.get("fade_s", {"music": 4.0, "amb": 6.0, "boss": 2.0}[group]))
		s.is_rain = bool(e.get("rain", false))
		s.boss_db = float(e.get("boss_db", 0.0))
		var st: AudioStream = bank.pick_stream(s.id) if bank != null else null
		if st == null:
			continue # fichier manquant : stem ignoré
		s.stream = SoundBankScript.looped(st)
		var p := AudioStreamPlayer.new()
		p.bus = &"Ambience" if group == "amb" else &"Music"
		p.volume_db = -80.0
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		s.player = p
		stems.append(s)


func _retire(s: Stem) -> void:
	s.target = 0.0
	s.dying = true
	s.fade_s = minf(s.fade_s, 2.5)
	_dying.append(s)


func set_tier(new_tier: int) -> void:
	new_tier = clampi(new_tier, 0, TIERS.size() - 1)
	if new_tier == tier:
		return
	tier = new_tier
	_retarget(false)


func set_tier_by_name(tier_name: StringName) -> void:
	set_tier(tier_index(tier_name))


func set_boss(active: bool) -> void:
	if active == boss_active:
		return
	boss_active = active
	_retarget(false)


func set_rain_scale(v: float) -> void:
	rain_scale = clampf(v, 0.0, 1.5)
	_retarget(false)


func stop_all(fade := true) -> void:
	for s in stems:
		if fade:
			_retire(s)
		else:
			_free_stem(s)
	stems.clear()


func _retarget(instant: bool) -> void:
	var has_boss_stem := false
	for s in stems:
		if s.group == "boss":
			has_boss_stem = true
	for s in stems:
		var db: float = -80.0
		match s.group:
			"music":
				if boss_active and has_boss_stem:
					db = -80.0
				else:
					db = float(s.db_by_tier[mini(tier, s.db_by_tier.size() - 1)])
			"amb":
				db = float(s.db_by_tier[mini(tier, s.db_by_tier.size() - 1)])
			"boss":
				db = s.boss_db if boss_active else -80.0
		var a := db_to_linear(db) if db > -60.0 else 0.0
		if s.is_rain:
			a *= rain_scale
		s.target = a
		if instant:
			s.amp = a if s.group != "boss" else 0.0
			_apply_volume(s)


func _apply_volume(s: Stem) -> void:
	if s.player != null:
		s.player.volume_db = linear_to_db(s.amp) if s.amp > SILENT_AMP * 0.1 else -80.0


## Position de lecture d'un stem de référence encore audible (pour la synchronisation).
func _reference_position(exclude: Stem) -> float:
	for s in stems:
		if s != exclude and s.group == exclude.group and s.player.playing:
			return s.player.get_playback_position()
	for s in stems:
		if s != exclude and s.group != "boss" and s.player.playing:
			return s.player.get_playback_position()
	return 0.0


func _play_stem(s: Stem, from: float) -> void:
	s.player.stream = s.stream
	_apply_volume(s)
	if s.player.is_inside_tree():
		s.player.play(from)


func _process(delta: float) -> void:
	for s in stems:
		_step_stem(s, delta)
	var i := _dying.size() - 1
	while i >= 0:
		var d := _dying[i]
		_step_stem(d, delta)
		if d.amp <= SILENT_AMP:
			_free_stem(d)
			_dying.remove_at(i)
		i -= 1


func _step_stem(s: Stem, delta: float) -> void:
	if s.amp != s.target:
		s.amp = move_toward(s.amp, s.target, delta / maxf(s.fade_s, 0.05))
		_apply_volume(s)
	var p := s.player
	if p == null or not p.is_inside_tree():
		return
	if s.target > SILENT_AMP and not p.playing:
		_play_stem(s, _reference_position(s) if not s.dying else 0.0)
	elif s.target <= SILENT_AMP and s.amp <= SILENT_AMP and p.playing:
		p.stop()


func _free_stem(s: Stem) -> void:
	if s.player != null and is_instance_valid(s.player):
		s.player.stop()
		s.player.queue_free()
	s.player = null


## Pour les tests : db demandé par stem pour le palier courant.
func stem_report() -> Dictionary:
	var out := {}
	for s in stems:
		out[String(s.id)] = {"target": s.target, "amp": s.amp, "playing": s.player != null and s.player.playing}
	return out
