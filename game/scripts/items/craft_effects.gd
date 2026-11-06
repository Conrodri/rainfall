class_name CraftEffects
extends Node
## Effets des six objets exclusifs de la Forge (docs/Design_Forge.md ; champ `special` de items.json, valeurs dans
## `special_data`, lues par ItemEffects.data_of). Un composant par joueur, enfant du joueur comme ItemEffects :
## tick() appelé par Player.tick, refresh() par Player.apply_stats. Les stats simples (crit, armure, zone) passent par
## ItemStats ; ici seulement la logique propre. Rien n'est lu en dehors du joueur concerné (coop : un composant par joueur,
## filtrage sur l'emplacement du joueur pour les signaux Events globaux).
##  - Mèche-silex : critique -> brûlure (150 % du dégât de base sur 3 s, sans jet ni proc coefficient).
##  - Rosée figée : toucher une cible ralentie soigne, au plus un plafond de PV max par seconde.
##  - Rouage de traque : touche du sort 1 -> retire du temps aux recharges des sorts 2-4 (plafond/s, plancher de recharge).
##  - Sève rampante : mort d'un monstre empoisonné -> ses cumuls passent aux voisins (une génération, plafond/s).
##  - Écorce de pluie : gros coup subi -> barrière temporaire (recharge interne, total plafonné BARRIER_CAP_PCT).
##  - Prisme de grêle : les zones des sorts 2-4 ralentissent les cibles.

const ID_MECHE := &"meche_silex"
const ID_ROSEE := &"rosee_figee"
const ID_ROUAGE := &"rouage_traque"
const ID_SEVE := &"seve_rampante"
const ID_ECORCE := &"ecorce_pluie"
const ID_PRISME := &"prisme_grele"

var player: Node2D
var _caster: SpellCaster = null
var _dew_tokens := 0.0 ## part de PV max encore soignable cette seconde (seau qui se remplit au plafond/s)
var _gear_tokens := 0.0 ## secondes de recharge encore retirables cette seconde
var _spread_tokens := float(Balance.CRAFT_SPREAD_MAX_PER_S) ## propagations de Sève restantes
var _bark_cd := 0.0
var _bark_left := 0.0
var _bark_amount := 0.0
var _gear_cut := {} ## slot -> {cut: s retirées sur la recharge en cours, rem: recharge restante à la dernière touche}


func setup(p: Node2D) -> void:
	player = p
	name = "CraftEffects"
	Events.enemy_killed_by.connect(_on_enemy_killed_by)
	Events.player_damaged_by.connect(_on_player_damaged_by)


func _exit_tree() -> void:
	if Events.enemy_killed_by.is_connected(_on_enemy_killed_by):
		Events.enemy_killed_by.disconnect(_on_enemy_killed_by)
	if Events.player_damaged_by.is_connected(_on_player_damaged_by):
		Events.player_damaged_by.disconnect(_on_player_damaged_by)


func stacks(id: StringName) -> int:
	return int(player.call(&"special_stacks", id)) if player != null else 0


func _pid() -> int:
	return int(player.get("player_id")) if player != null and player.get("player_id") != null else 0


func _alive() -> bool:
	return player != null and is_instance_valid(player) and not bool(player.get("dead"))


## Stats recalculées (apply_stats) : rebranche le signal de coup de sort du lanceur courant.
func refresh() -> void:
	var sp: SpellCaster = player.get("spells") as SpellCaster
	if sp != _caster:
		if _caster != null and is_instance_valid(_caster) and _caster.spell_hit.is_connected(_on_spell_hit):
			_caster.spell_hit.disconnect(_on_spell_hit)
		_caster = sp
		if sp != null and not sp.spell_hit.is_connected(_on_spell_hit):
			sp.spell_hit.connect(_on_spell_hit)


func tick(delta: float) -> void:
	_bark_cd = maxf(_bark_cd - delta, 0.0)
	if _bark_left > 0.0:
		_bark_left -= delta
		if _bark_left <= 0.0:
			_expire_barrier()
	_spread_tokens = minf(_spread_tokens + float(Balance.CRAFT_SPREAD_MAX_PER_S) * delta, float(Balance.CRAFT_SPREAD_MAX_PER_S))
	var dew := dew_cap_pct()
	if dew > 0.0:
		_dew_tokens = minf(_dew_tokens + dew * delta, dew)
	var gear := gear_cap_s()
	if gear > 0.0:
		_gear_tokens = minf(_gear_tokens + gear * delta, gear)


# --- Valeurs (2e exemplaire plus faible) ------------------------------------------------------------

func meche_fraction() -> float:
	var n := stacks(ID_MECHE)
	if n <= 0:
		return 0.0
	var d := ItemEffects.data_of(ID_MECHE)
	return float(d.get("burn_fraction", 1.5)) + float(d.get("burn_fraction_extra", 0.75)) * (n - 1)


## Soin maximal par seconde de Rosée figée, en part des PV max.
func dew_cap_pct() -> float:
	var n := stacks(ID_ROSEE)
	if n <= 0:
		return 0.0
	var d := ItemEffects.data_of(ID_ROSEE)
	return float(d.get("cap_pct_s", 0.01)) + float(d.get("cap_pct_s_extra", 0.005)) * (n - 1)


## Secondes de recharge retirables par seconde par le Rouage de traque.
func gear_cap_s() -> float:
	var n := stacks(ID_ROUAGE)
	if n <= 0:
		return 0.0
	var d := ItemEffects.data_of(ID_ROUAGE)
	return float(d.get("cap_s_per_s", 0.4)) + float(d.get("cap_s_per_s_extra", 0.15)) * (n - 1)


func seve_neighbors() -> int:
	var n := stacks(ID_SEVE)
	if n <= 0:
		return 0
	var d := ItemEffects.data_of(ID_SEVE)
	return int(d.get("neighbors", 2)) + int(d.get("neighbors_extra", 1)) * (n - 1)


func barrier_pct() -> float:
	var n := stacks(ID_ECORCE)
	if n <= 0:
		return 0.0
	var d := ItemEffects.data_of(ID_ECORCE)
	return float(d.get("barrier_pct", 0.10)) + float(d.get("barrier_pct_extra", 0.05)) * (n - 1)


# --- Coups de sort : Mèche-silex, Rosée figée, Rouage de traque, Prisme de grêle ----------------------

func _on_spell_hit(s: SpellData, enemy: Node, _amount: float) -> void:
	if not _alive() or enemy == null or not is_instance_valid(enemy):
		return
	if _caster != null and _caster.last_hit_crit and stacks(ID_MECHE) > 0 and enemy.has_method(&"apply_status"):
		_meche_burn(enemy)
	if stacks(ID_ROSEE) > 0 and enemy.has_method(&"is_slowed") and enemy.is_slowed():
		_dew_heal()
	if s.is_auto and stacks(ID_ROUAGE) > 0:
		_gear_cut_cooldowns()
	if stacks(ID_PRISME) > 0 and s.is_zone and not s.is_auto and enemy.has_method(&"apply_status"):
		var d := ItemEffects.data_of(ID_PRISME)
		enemy.apply_status(&"slow", {"pct": float(d.get("slow_pct", 0.3)), "duration": float(d.get("slow_s", 1.5)), "by": _pid()})


func _meche_burn(enemy: Node) -> void:
	var d := ItemEffects.data_of(ID_MECHE)
	var base := Balance.player_base_damage(_caster.player_level())
	# Brûlure sans jet de proc : fraction du dégât de base, « toutes vos brûlures » (Cristal de feu) comprises.
	var total := meche_fraction() * base * (1.0 + float(player.call(&"stat", &"burn_damage_add")))
	enemy.apply_status(&"burn", {"total": total, "duration": float(d.get("duration_s", 3.0)), "by": _pid()})


func _dew_heal() -> void:
	var want := float(ItemEffects.data_of(ID_ROSEE).get("heal_pct", 0.003))
	var got := minf(want, _dew_tokens)
	if got <= 0.0:
		return
	_dew_tokens -= got
	player.call(&"heal", got * float(player.get("max_hp")))


func _gear_cut_cooldowns() -> void:
	if _caster == null:
		return
	var per_hit := minf(float(ItemEffects.data_of(ID_ROUAGE).get("cut_s", 0.08)), _gear_tokens)
	if per_hit <= 0.0:
		return
	_gear_tokens -= per_hit
	for sd in _caster.character.spells:
		if sd.is_auto:
			continue
		var slot: int = sd.slot
		var rem := _caster.cooldown_remaining(slot)
		if rem <= 0.0:
			continue
		var st: Dictionary = _gear_cut.get(slot, {})
		if st.is_empty() or rem > float(st["rem"]) + 0.05: # nouvelle recharge : le cumul de coupes repart
			st = {"cut": 0.0, "rem": rem}
		# jamais sous le plancher de recharge : la recharge de ce lancer ne descend pas sous base × COOLDOWN_FLOOR
		var floor_s: float = float(sd.base_cooldown) * Balance.COOLDOWN_FLOOR
		var room := maxf(_caster.cooldown_total(slot) - floor_s - float(st["cut"]), 0.0)
		var done := _caster.reduce_cooldown(slot, minf(per_hit, room))
		st["cut"] = float(st["cut"]) + done
		st["rem"] = rem - done
		_gear_cut[slot] = st


# --- Sève rampante -----------------------------------------------------------------------------------

func _on_enemy_killed_by(killer: int, enemy: Node2D, pos: Vector2, _tier: int, _elite: bool) -> void:
	if not _alive() or enemy == null or not is_instance_valid(enemy):
		return
	if killer != _pid() and not (killer == Events.NO_PLAYER and Players.count() <= 1):
		return
	var k := seve_neighbors()
	if k <= 0 or not enemy.has_method(&"poison_stacks") or _spread_tokens < 1.0:
		return
	var d := ItemEffects.data_of(ID_SEVE)
	var cumuls: Array = enemy.poison_stacks(int(d.get("stacks_max", Balance.POISON_MAX_STACKS)))
	if cumuls.is_empty():
		return
	var origin: Vector2 = enemy.global_position if enemy.is_inside_tree() else pos
	var r2 := pow(float(d.get("radius_u", 3.0)) * Balance.UNIT_PX, 2.0)
	var cands: Array = []
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if e == enemy or not (e is Node2D) or not e.has_method(&"apply_status") or e.get("active") == false:
			continue
		var d2 := origin.distance_squared_to((e as Node2D).global_position)
		if d2 <= r2:
			cands.append([d2, e])
	if cands.is_empty():
		return
	_spread_tokens -= 1.0
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in mini(k, cands.size()):
		var target: Node = cands[i][1]
		for c in cumuls:
			target.apply_status(&"poison", {"total": float(c["dps"]) * float(c["left"]), "duration": float(c["left"]), "by": _pid()})


# --- Écorce de pluie ----------------------------------------------------------------------------------

func _on_player_damaged_by(pid: int, amount: float, _source: Node) -> void:
	if pid != _pid() or not _alive() or _bark_cd > 0.0:
		return
	var pct := barrier_pct()
	if pct <= 0.0:
		return
	var d := ItemEffects.data_of(ID_ECORCE)
	var max_hp := float(player.get("max_hp"))
	if amount < float(d.get("hit_pct", 0.10)) * max_hp:
		return
	var room := maxf(Balance.BARRIER_CAP_PCT * max_hp - float(player.get("shield")), 0.0)
	var add := minf(pct * max_hp, room)
	if add <= 0.0:
		return
	player.call(&"add_shield", add)
	_bark_amount += add
	_bark_left = float(d.get("duration_s", 4.0))
	_bark_cd = float(d.get("cooldown_s", 6.0))


func _expire_barrier() -> void:
	if _bark_amount > 0.0 and player != null and is_instance_valid(player):
		player.set("shield", maxf(float(player.get("shield")) - _bark_amount, 0.0))
	_bark_amount = 0.0


## Barrière de l'Écorce encore active (tests, HUD).
func barrier_active() -> float:
	return _bark_amount if _bark_left > 0.0 else 0.0
