class_name LegendaryEffects
extends Node
## Effets des items légendaires à logique propre (champ `special` de items.json, valeurs dans `special_data`) :
## Cœur du chronomancien, Couronne d'écho, Nova infinie, Moisson. (Armure du colosse et Dé pipé passent par les stats
## d'ItemStats et ChestSession.) Enfant du joueur : tick() appelé par Player.tick, refresh() par Player.apply_stats
## (acquisition d'un item ET reprise de sauvegarde passent par apply_stats). Branché sur SpellCaster.spell_cast :
## fonctionne pour Ardent comme pour tous les kits (Rictus, Averse…).

const ID_CHRONO := &"coeur_chronomancien"
const ID_ECHO := &"couronne_echo"
const ID_NOVA := &"nova_infinie"
const ID_MOISSON := &"moisson"
const COUNTER_MOISSON := "moisson_kills"
const NOVA_VFX := "res://assets/sprites/vfx/ardent_nova/ardent_nova.tres"
const NOVA_VFX_RADIUS_PX := 189.02
const NOVA_VFX_ASPECT := 0.4895

var player: Node2D
var _clock := 0.0
var _kill_times: Array[float] = []
var _chrono_cd := 0.0
var _nova_t := 0.0
var _echo_queue: Array = [] ## {slot, t}
var _echoing := false
var _moisson_applied := 0.0
var _nova_spell: SpellData = null
var _connected_caster: SpellCaster = null
static var _data_cache := {}


func setup(p: Node2D) -> void:
	player = p
	name = "LegendaryEffects"
	Events.enemy_killed.connect(_on_enemy_killed)


func _exit_tree() -> void:
	if Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.disconnect(_on_enemy_killed)


## `special_data` de l'item portant ce `special` (vide si absent).
static func data_of(special: StringName) -> Dictionary:
	if _data_cache.is_empty():
		for id in ItemDB.all_ids():
			var it := ItemDB.get_item(id)
			var sp := str(it.get("special", ""))
			if sp != "" and sp != "null" and it.get("special_data") is Dictionary:
				_data_cache[StringName(sp)] = it["special_data"]
	return _data_cache.get(special, {})


func stacks(id: StringName) -> int:
	return int(player.call(&"special_stacks", id)) if player != null else 0


## Stats recalculées (apply_stats) : rebranche le signal de sort et réapplique le bonus de Moisson.
func refresh() -> void:
	var sp: SpellCaster = player.get("spells") as SpellCaster
	if sp != _connected_caster:
		_connected_caster = sp
		if sp != null and not sp.spell_cast.is_connected(_on_spell_cast):
			sp.spell_cast.connect(_on_spell_cast)
	_moisson_applied = 0.0 # player.stats vient d'être remplacé : le bonus repart de zéro
	_apply_moisson()
	if stacks(ID_NOVA) <= 0:
		_nova_t = 0.0


# --- Moisson -------------------------------------------------------------------

func moisson_bonus() -> float:
	var n := stacks(ID_MOISSON)
	if n <= 0:
		return 0.0
	var d := data_of(ID_MOISSON)
	var cap := float(d.get("cap", 0.6)) + float(d.get("cap_per_extra", 0.3)) * (n - 1)
	return minf(float(RunState.counters.get(COUNTER_MOISSON, 0.0)) * float(d.get("per_kill", 0.002)), cap)


func _apply_moisson() -> void:
	var want := moisson_bonus()
	if is_equal_approx(want, _moisson_applied):
		return
	var stats: Dictionary = player.get("stats")
	stats["damage_add"] = float(stats.get("damage_add", 0.0)) + want - _moisson_applied
	_moisson_applied = want


# --- Kills : Moisson et Cœur du chronomancien ------------------------------------

func _on_enemy_killed(_e: Node2D, _pos: Vector2, _tier: int, _elite: bool) -> void:
	if player == null or bool(player.get("dead")):
		return
	if stacks(ID_MOISSON) > 0:
		RunState.add_counter(COUNTER_MOISSON)
		_apply_moisson()
	if stacks(ID_CHRONO) > 0:
		var d := data_of(ID_CHRONO)
		_kill_times.append(_clock)
		var win := float(d.get("window_s", 3.0))
		while not _kill_times.is_empty() and _clock - _kill_times[0] > win:
			_kill_times.pop_front()
		if _kill_times.size() >= int(d.get("kills", 10)) and _chrono_cd <= 0.0 and _reset_random_spell():
			_chrono_cd = float(d.get("internal_cd_s", 2.0))
			_kill_times.clear()


## Remet à zéro la recharge d'un sort (non automatique) en cours de recharge, tiré au hasard. false si aucun.
func _reset_random_spell() -> bool:
	var sp: SpellCaster = player.get("spells") as SpellCaster
	if sp == null:
		return false
	var slots: Array[int] = []
	for s in sp.character.spells:
		if not s.is_auto and sp.cooldown_remaining(s.slot) > 0.0:
			slots.append(s.slot)
	if slots.is_empty():
		return false
	var slot := slots[sp.rng.randi() % slots.size()]
	sp.reduce_cooldown(slot, sp.cooldown_remaining(slot))
	LightRig.flash(player.global_position, &"level_up", 0.5)
	return true


# --- Couronne d'écho -------------------------------------------------------------

func _on_spell_cast(s: SpellData) -> void:
	if _echoing or not s.is_auto:
		return
	var n := stacks(ID_ECHO)
	if n <= 0:
		return
	var step := float(data_of(ID_ECHO).get("repeat_delay_s", 0.15))
	for i in n:
		_echo_queue.append({"slot": s.slot, "t": step * (i + 1)})


# --- Nova infinie ----------------------------------------------------------------

func _nova() -> SpellData:
	if _nova_spell == null:
		var s := SpellData.new()
		s.id = &"nova_infinie"
		s.display_name = "Nova infinie"
		s.slot = 2
		s.behavior = SpellData.Behavior.NOVA
		s.element = &"fire"
		s.color = Color(1.0, 0.45, 0.15)
		s.is_zone = false # bonus de zone des items non cumulé : coef fixé par l'item
		s.light_preset = &"nova"
		if ResourceLoader.exists(NOVA_VFX):
			s.vfx_frames = NOVA_VFX
			s.vfx_radius_px = NOVA_VFX_RADIUS_PX
			s.vfx_floor_aspect = NOVA_VFX_ASPECT
		_nova_spell = s
	return _nova_spell


func _fire_nova(n: int) -> bool:
	var sp: SpellCaster = player.get("spells") as SpellCaster
	if sp == null:
		return false
	var d := data_of(ID_NOVA)
	var s := _nova()
	s.coef = float(d.get("coef", 4.0)) * n
	s.radius_u = float(d.get("radius_u", 6.0))
	var radius_px: float = s.radius_u * Balance.UNIT_PX * (1.0 + float(player.call(&"stat", &"zone_size_add")))
	var targets: Array = []
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and e.has_method("take_damage") and e.global_position.distance_to(player.global_position) <= radius_px:
			targets.append(e)
	if targets.is_empty():
		return false # rien à toucher : la nova attend un ennemi à portée
	var base := Balance.player_base_damage(RunState.level)
	var hit := s.coef * base
	var burn: Dictionary = d.get("burn", {"base_fraction": 2.4, "duration": 3.0})
	var slow: Dictionary = d.get("slow", {"pct": 0.4, "duration": 2.0})
	var poison: Dictionary = d.get("poison", {"hit_fraction": 1.8, "duration": 4.0})
	for e in targets:
		if e.has_method("apply_status"):
			var b := burn.duplicate()
			b["total"] = float(burn.get("base_fraction", 2.4)) * base
			e.apply_status(&"burn", b)
			e.apply_status(&"slow", slow.duplicate())
			var p := poison.duplicate()
			p["total"] = float(poison.get("hit_fraction", 1.8)) * hit
			e.apply_status(&"poison", p)
	sp.spawn_zone(s, player.global_position) # dégâts (400 % × exemplaires) + visuel de nova
	return true


# --- Boucle ----------------------------------------------------------------------

func tick(delta: float) -> void:
	_clock += delta
	_chrono_cd = maxf(_chrono_cd - delta, 0.0)
	if not _echo_queue.is_empty():
		_tick_echo(delta)
	var n := stacks(ID_NOVA)
	if n > 0:
		_nova_t += delta
		if _nova_t >= float(data_of(ID_NOVA).get("period_s", 4.0)) and _fire_nova(n):
			_nova_t = 0.0


func _tick_echo(delta: float) -> void:
	var sp: SpellCaster = player.get("spells") as SpellCaster
	var keep: Array = []
	for q in _echo_queue:
		q["t"] = float(q["t"]) - delta
		if float(q["t"]) > 0.0:
			keep.append(q)
		elif sp != null and not bool(player.get("dead")):
			_echoing = true
			sp.repeat_cast(int(q["slot"]))
			_echoing = false
	_echo_queue = keep
