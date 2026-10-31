class_name ItemEffects
extends Node
## Effets des items à logique propre (champ `special` de items.json, valeurs dans `special_data` ; les stats simples
## passent par ItemStats, les procs de statuts par SpellCaster._roll_procs). Un seul composant, enfant du joueur :
## tick() appelé par Player.tick, refresh() par Player.apply_stats (acquisition d'un item ET reprise de sauvegarde
## passent par apply_stats). Branché sur les signaux Events (enemy_killed, player_damaged, pickup_collected) et sur
## SpellCaster.spell_cast : fonctionne pour Ardent comme pour tous les kits. Aucune recherche de groupe à l'image.
##  - Légendaires : Cœur du chronomancien, Couronne d'écho, Nova infinie, Faux (id `moisson`) (Armure du colosse : stats ;
##    Dé pipé : ChestSession).
##  - Autres : Pièce porte-bonheur (soin), Épines (riposte), Morsure vorace, Orbe de veille, Chronomètre brisé,
##    Tempête de braises, Peste vivante, Bouclier réactif, Phénix de poche, Rafale d'acier ; Faveur du marchand
##    (prix des coffres et relance gratuite : helpers statiques lus par Chest et ChestSession).
##  - Hooks du joueur : absorb_hit() (Player.take_damage) et try_revive() (Player._damage_hp).

const ID_CHRONO := &"coeur_chronomancien"
const ID_ECHO := &"couronne_echo"
const ID_NOVA := &"nova_infinie"
const ID_MOISSON := &"moisson"
const COUNTER_MOISSON := "moisson_kills"
const ID_PIECE := &"piece_soin"
const ID_RIPOSTE := &"riposte"
const ID_MORSURE := &"morsure_vorace"
const ID_ORBE := &"orbe_veille"
const ID_CHRONOMETRE := &"chronometre_brise"
const ID_BRAISES := &"tempete_braises"
const ID_PESTE := &"peste_vivante"
const ID_BOUCLIER := &"bouclier_reactif"
const ID_FAVEUR := &"faveur_marchand"
const ID_PHENIX := &"phenix"
const ID_RAFALE := &"rafale_acier"
const COUNTER_PHENIX := "phenix_used"
const COUNTER_FAVEUR := "faveur_free_stage"
const BOSS_BLAST_HITS := 40.0 ## plafond des PV servant de base à l'explosion d'un boss, en coups de dégât de base du joueur
const MAX_BLASTS_PER_TICK := 6 ## explosions de monstres traitées par image (réactions en chaîne étalées)
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
var _riposte_cd := 0.0
var _orb := 0.0 ## part du bouclier du joueur venant de l'Orbe de veille
var _orb_quiet := 0.0 ## s sans coup reçu
var _orb_known := false
var _charges := 0 ## Bouclier réactif
var _charge_t := 0.0
var _charges_known := false
var _blasts: Array = [] ## {pos, hp, kind} : explosions de monstres en attente (tempête de braises, peste vivante)
var _rafale_count := 0
var _rafale_queue: Array = [] ## {slot, t}
static var _data_cache := {}


func setup(p: Node2D) -> void:
	player = p
	name = "ItemEffects"
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.boss_killed.connect(_on_boss_killed)
	Events.player_damaged.connect(_on_player_damaged)
	Events.pickup_collected.connect(_on_pickup_collected)


func _exit_tree() -> void:
	if Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.disconnect(_on_enemy_killed)
	if Events.boss_killed.is_connected(_on_boss_killed):
		Events.boss_killed.disconnect(_on_boss_killed)
	if Events.player_damaged.is_connected(_on_player_damaged):
		Events.player_damaged.disconnect(_on_player_damaged)
	if Events.pickup_collected.is_connected(_on_pickup_collected):
		Events.pickup_collected.disconnect(_on_pickup_collected)


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
	if stacks(ID_ORBE) > 0 and not _orb_known: # orbe acquise (ou run reprise) : bouclier plein tout de suite
		_orb_known = true
		_orb_quiet = float(data_of(ID_ORBE).get("delay_s", 5.0))
	if stacks(ID_BOUCLIER) > 0 and not _charges_known:
		_charges_known = true
		_charges = int(data_of(ID_BOUCLIER).get("charges", 2))


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

func _on_enemy_killed(e: Node2D, pos: Vector2, _tier: int, elite: bool) -> void:
	if player == null or bool(player.get("dead")):
		return
	var morsure := stacks(ID_MORSURE)
	if morsure > 0:
		player.heal(float(data_of(ID_MORSURE).get("heal_pct", 0.002)) * morsure * float(player.max_hp))
	if elite:
		var chrono := stacks(ID_CHRONOMETRE)
		if chrono > 0:
			_refund_all(chrono_refund_s(chrono))
	if e != null and is_instance_valid(e):
		if stacks(ID_BRAISES) > 0 and e.has_method(&"is_burning") and e.is_burning():
			_queue_blast(e, pos, ID_BRAISES)
		if stacks(ID_PESTE) > 0 and e.has_method(&"is_poisoned") and e.is_poisoned():
			_queue_blast(e, pos, ID_PESTE)
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


## Remise de recharge du Chronomètre brisé par élite ou boss tué : premier exemplaire + suivants × (n - 1).
func chrono_refund_s(n: int) -> float:
	if n <= 0:
		return 0.0
	var d := data_of(ID_CHRONOMETRE)
	return float(d.get("elite_refund_s", 0.5)) + float(d.get("elite_refund_per_extra_s", 0.25)) * (n - 1)


## Les boss (mini et d'étage) n'émettent pas enemy_killed mais boss_killed : leur mort compte comme celle d'une élite.
func _on_boss_killed(boss: Node2D, _is_floor_boss: bool) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	_on_enemy_killed(boss, boss.global_position if boss.is_inside_tree() else Vector2.ZERO, 0, true)


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
	_rafale_on_cast(s)
	var n := stacks(ID_ECHO)
	if n <= 0:
		return
	var step := float(data_of(ID_ECHO).get("repeat_delay_s", 0.15))
	var d := data_of(ID_ECHO)
	var base := float(d.get("echo_damage", 0.45))
	var decay := float(d.get("echo_decay", 0.7))
	for i in n: # écho i : base × decay^i (rendements décroissants)
		_echo_queue.append({"slot": s.slot, "t": step * (i + 1), "mult": base * pow(decay, i)})


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
			# « toutes vos brûlures » (Cristal de feu) : même règle que les procs et le Phénix d'Ardent
			b["total"] = float(burn.get("base_fraction", 2.4)) * base * (1.0 + float(player.call(&"stat", &"burn_damage_add")))
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
	_riposte_cd = maxf(_riposte_cd - delta, 0.0)
	if _orb_known:
		_tick_orb(delta)
	if _charges_known:
		_tick_bouclier(delta)
	if not _blasts.is_empty():
		_tick_blasts()
	if not _rafale_queue.is_empty():
		_tick_rafale(delta)
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
			sp.repeat_cast(int(q["slot"]), float(q.get("mult", 1.0)))
			_echoing = false
	_echo_queue = keep


# --- Pièce porte-bonheur, Épines, Chronomètre brisé -------------------------------------

## Chaque or crédité soigne `heal_pct` des PV max par exemplaire (Events.pickup_collected &"gold", en or entiers).
func _on_pickup_collected(kind: StringName, amount: float) -> void:
	if kind != &"gold" or player == null:
		return
	var n := stacks(ID_PIECE)
	if n > 0:
		player.heal(float(data_of(ID_PIECE).get("heal_pct", 0.0005)) * n * amount * float(player.max_hp))


## Coup subi (Events.player_damaged, émis après le bouclier) : Orbe de veille (le délai repart) et Épines (riposte).
func _on_player_damaged(_amount: float, _source: Node) -> void:
	if player == null:
		return
	_orb_quiet = 0.0
	_orb = minf(_orb, float(player.shield))
	var n := stacks(ID_RIPOSTE)
	# Tout coup direct déclenche la riposte (monstres, projectiles, mais aussi dangers de boss et de terrain :
	# scories, tempête, pièges, dont la source n'a pas take_damage). Les DoT n'émettent pas player_damaged.
	if n > 0 and _riposte_cd <= 0.0 and not bool(player.get("dead")):
		_riposte(n)


## Épines (Razorwire RoR2) : `fraction` du dégât de base à `targets` ennemis proches (+`targets_per_extra` par exemplaire).
func _riposte(n: int) -> void:
	var sp: SpellCaster = player.get("spells") as SpellCaster
	if sp == null:
		return
	var d := data_of(ID_RIPOSTE)
	_riposte_cd = float(d.get("cooldown_s", 0.5))
	var dmg := float(d.get("fraction", 1.6)) * Balance.player_base_damage(RunState.level)
	var count := int(d.get("targets", 5)) + int(d.get("targets_per_extra", 2)) * (n - 1)
	for e in sp.nearest_enemies(player.global_position, float(d.get("range_u", 6.0)) * Balance.UNIT_PX, count):
		e.take_damage(dmg, false, &"")


## Rend `seconds` de recharge à tous les sorts non automatiques (Chronomètre brisé : élite tuée).
func _refund_all(seconds: float) -> void:
	var sp: SpellCaster = player.get("spells") as SpellCaster
	if sp == null or seconds <= 0.0:
		return
	for s in sp.character.spells:
		if not s.is_auto:
			sp.reduce_cooldown(s.slot, seconds)


# --- Orbe de veille ----------------------------------------------------------------

func orb_cap() -> float:
	return float(data_of(ID_ORBE).get("shield_pct", 0.28)) * stacks(ID_ORBE) * float(player.max_hp)


## Bouclier de l'orbe encore présent (fondu par les coups).
func orb_shield() -> float:
	return _orb


func _tick_orb(delta: float) -> void:
	if stacks(ID_ORBE) <= 0:
		return
	_orb_quiet += delta
	if _orb_quiet < float(data_of(ID_ORBE).get("delay_s", 5.0)):
		return
	var cap := orb_cap()
	if _orb < cap - 0.01:
		player.add_shield(cap - _orb)
		_orb = cap
		LightRig.flash(player.global_position, &"spell_frost", 0.2)


# --- Bouclier réactif --------------------------------------------------------------

func shield_charges() -> int:
	return _charges


func _charge_time() -> float:
	var d := data_of(ID_BOUCLIER)
	var m := float(player.stat(&"cooldown_mult"))
	if m <= 0.0:
		m = 1.0 # pas d'item de recharge
	m = maxf(m, Balance.COOLDOWN_FLOOR) # même plancher que les sorts (Balance.effective_cooldown)
	var n := stacks(ID_BOUCLIER)
	var t := float(d.get("recharge_s", 3.4)) * m / (1.0 + float(d.get("stack_speed", 0.5)) * maxi(n - 1, 0))
	return maxf(t, float(d.get("recharge_floor_s", 1.2))) # plancher absolu : cumuls de Boucliers (audit 28/10/2026)


func _tick_bouclier(delta: float) -> void:
	var max_charges := int(data_of(ID_BOUCLIER).get("charges", 2))
	if stacks(ID_BOUCLIER) <= 0 or _charges >= max_charges:
		return
	_charge_t -= delta
	if _charge_t <= 0.0:
		_charges += 1
		if _charges < max_charges:
			_charge_t += _charge_time()


## Hook de Player.take_damage : une charge annule le coup (court répit contre les coups simultanés). true = annulé.
func absorb_hit() -> bool:
	if _charges <= 0 or stacks(ID_BOUCLIER) <= 0:
		return false
	if _charges >= int(data_of(ID_BOUCLIER).get("charges", 2)):
		_charge_t = _charge_time() # la recharge ne tourne que s'il manque une charge
	_charges -= 1
	player.grant_invulnerability(float(data_of(ID_BOUCLIER).get("invuln_s", 0.4)))
	LightRig.flash(player.global_position, &"spell_steel", 0.2)
	return true


# --- Phénix de poche ---------------------------------------------------------------

func revives_left() -> int:
	return maxi(stacks(ID_PHENIX) - int(RunState.counters.get(COUNTER_PHENIX, 0.0)), 0)


## Hook de Player._damage_hp (PV à zéro) : ressuscite si une charge reste (usage compté dans RunState.counters, donc
## sauvegardé). true = le joueur reste en vie.
func try_revive() -> bool:
	if revives_left() <= 0:
		return false
	var d := data_of(ID_PHENIX)
	RunState.add_counter(COUNTER_PHENIX)
	player.hp = float(player.max_hp) * float(d.get("hp_pct", 0.5))
	player.hp_changed.emit(player.hp, player.max_hp)
	player.grant_invulnerability(float(d.get("invuln_s", 2.0)))
	if player.has_method(&"on_revived"):
		player.call(&"on_revived") # DoT et ralentissements purgés, flash doré, vibration
	LightRig.flash(player.global_position, &"phoenix", 0.8)
	return true


# --- Tempête de braises, Peste vivante -----------------------------------------------

func _queue_blast(e: Node2D, pos: Vector2, id: StringName) -> void:
	var hp := float(e.get("max_hp")) if e.get("max_hp") != null else 0.0
	if hp <= 0.0:
		return
	if e.is_in_group(&"bosses") or bool(e.get("is_boss")):
		hp = minf(hp, BOSS_BLAST_HITS * Balance.player_base_damage(RunState.level)) # un boss ne détruit pas le paquet voisin
	else:
		hp = minf(hp, Balance.BLAST_HP_CAP_HITS * Balance.player_base_damage(RunState.level)) # une brute non plus
	if _blasts.size() >= Balance.BLAST_QUEUE_MAX:
		return # garde-fou des chaînes d'explosions (perf mobile)
	_blasts.append({"pos": e.global_position if e.is_inside_tree() else pos, "hp": hp, "id": id})


## Explosions en attente (plafond par image : la chaîne de morts se déroule sur plusieurs images, sans récursion).
func _tick_blasts() -> void:
	var sp: SpellCaster = player.get("spells") as SpellCaster
	var todo := _blasts.slice(0, MAX_BLASTS_PER_TICK)
	_blasts = _blasts.slice(MAX_BLASTS_PER_TICK)
	if sp == null or bool(player.get("dead")):
		return
	for b in todo:
		var id: StringName = b["id"]
		var d := data_of(id)
		var n := stacks(id)
		if n <= 0:
			continue
		var pct := float(d.get("damage_pct", 0.3)) * (n if id == ID_BRAISES else 1) # braises : linéaire ; peste : fixe
		var radius := float(d.get("radius_u", 4.0)) * Balance.UNIT_PX * (1.0 + float(player.stat(&"zone_size_add")))
		var pos: Vector2 = b["pos"]
		var poison: Dictionary = d.get("poison", {})
		for e in sp.nearest_enemies(pos, radius, int(d.get("targets", 4))):
			e.take_damage(float(b["hp"]) * pct, false, &"fire" if id == ID_BRAISES else &"poison")
			if id == ID_PESTE and e.has_method("apply_status"):
				var pd := poison.duplicate()
				pd["total"] = float(poison.get("base_fraction", 1.8)) * Balance.player_base_damage(RunState.level)
				e.apply_status(&"poison", pd)
		LightRig.flash(pos, &"meteor_impact" if id == ID_BRAISES else &"spell_poison", 0.25)


# --- Rafale d'acier ----------------------------------------------------------------

## Tous les `every` tirs du sort 1 : `extra` projectiles en éventail autour de la cible (sort projectile) ou `extra` rejeux du sort (autres).
func _rafale_on_cast(s: SpellData) -> void:
	if stacks(ID_RAFALE) <= 0:
		return
	_rafale_count += 1
	if _rafale_count % maxi(int(data_of(ID_RAFALE).get("every", 4)), 1) != 0:
		return
	if s.behavior != SpellData.Behavior.PROJECTILE:
		# Sort 1 de kit (zone, mêlée, rayon...) : `extra` rejeux du sort comme la Couronne d'écho (même file, même garde).
		var step := float(data_of(ID_ECHO).get("repeat_delay_s", 0.15))
		for i in maxi(int(data_of(ID_RAFALE).get("extra", 2)), 1):
			_echo_queue.append({"slot": s.slot, "t": step * (i + 1)})
	else:
		_rafale_queue.append({"spell": s, "t": 0.0, "wait": 0.5}) # attend le tir principal (frame d'impact), 0,5 s au plus


func _tick_rafale(delta: float) -> void:
	var sp: SpellCaster = player.get("spells") as SpellCaster
	var keep: Array = []
	for q in _rafale_queue:
		q["t"] = float(q["t"]) + delta
		if sp != null and sp.has_pending() and float(q["t"]) < float(q["wait"]):
			keep.append(q)
		elif sp != null and not bool(player.get("dead")):
			_fire_rafale(sp, q["spell"])
	_rafale_queue = keep


func _fire_rafale(sp: SpellCaster, s: SpellData) -> void:
	var d := data_of(ID_RAFALE)
	var target := sp.nearest_enemy(sp.range_px(s))
	if target == null:
		return
	var dir: Vector2 = (target.global_position - player.global_position).normalized()
	var spread := deg_to_rad(float(d.get("spread_deg", 14.0)))
	for i in maxi(int(d.get("extra", 2)), 1):
		var side := -1.0 if i % 2 == 0 else 1.0
		sp.fire_dir(s, dir.rotated(side * spread * float(i / 2 + 1)))


# --- Faveur du marchand (helpers statiques : Chest, ChestSession) ----------------------

## Exemplaires, dans la run, des items portant ce `special` (RunState.items).
static func run_special_stacks(special: StringName) -> int:
	var n := 0
	for id in RunState.items:
		if str(ItemDB.get_item(id).get("special", "")) == str(special):
			n += int(RunState.items[id])
	return n


## Multiplicateur du prix des coffres (0,85 par exemplaire, plancher `price_floor`).
static func chest_price_mult() -> float:
	var n := run_special_stacks(ID_FAVEUR)
	if n <= 0:
		return 1.0
	var d := data_of(ID_FAVEUR)
	return maxf(pow(float(d.get("price_mult", 0.85)), n), float(d.get("price_floor", 0.4)))


## La première relance à l'or de chaque étage est gratuite (`rerolls_done` : relances déjà faites sur ce coffre).
static func free_gold_reroll(stage: int, rerolls_done: int) -> bool:
	return rerolls_done == 0 and run_special_stacks(ID_FAVEUR) > 0 and int(RunState.counters.get(COUNTER_FAVEUR, 0)) != stage


static func consume_free_gold_reroll(stage: int) -> void:
	RunState.counters[COUNTER_FAVEUR] = stage
