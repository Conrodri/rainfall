class_name Enemy
extends AnimatableBody2D
## Monstre poolé (tiers 1-3) ou boss prototype (tier 4). Groupe `enemies` (+ `bosses`), couche 3.
## Tier 2 : deux variantes (Maths §4) — tireur (sort Salve) ou bondisseur (sort Charge télégraphiée).
##
## Choix de performance : pas de CharacterBody2D / move_and_slide. Le corps est un
## AnimatableBody2D (mode cinématique, mask 0) déplacé par affectation de position : il reste
## détectable par les projectiles du joueur (Area2D `body_entered`, requêtes de formes, rayons)
## mais ne calcule aucune collision lui-même. La séparation entre monstres est faite par le
## Director avec une grille spatiale O(n), et le contact avec le joueur par un simple test de
## distance. Aucun _process par nœud : le Director appelle tick() sur les monstres actifs.

const LAYER_ENEMIES := 1 << 2
const U: float = preload("res://scripts/core/balance.gd").UNIT_PX # constante repliée à la compilation
const BOSS_TIER := 4

# Gabarits (en unités, 1 u = U)
const RADIUS_U := {1: 0.35, 2: 0.42, 3: 0.65}
const BOSS_RADIUS_U := {&"mini": 1.1, &"etage": 1.4}
## Dégâts de boss : Balance.BOSS_BASE_DMG (Alignement RoR2 ; remplace 25/35 ici).
const BOSS_SPEED_U := 1.6
## Rayon de dégâts du joueur : miroir de PlayerHitbox.radius_px (posé par PlayerHitbox.set_radius ; statique propre =
## lecture la moins chère dans la boucle chaude du Director). Ne pas écrire ailleurs.
static var PLAYER_RADIUS_PX := PlayerHitbox.BASE_PX

# Tier 1 : essaim
const CONTACT_INTERVAL := 1.0
const PACK_SPEED_BONUS := 0.15
# Tier 2 : tireur. Cycle (docs/Comportements_Monstres.md) : arrêt -> armement (pose d'attaque, teinte,
# ligne de visée, visée verrouillée à SHOOTER_AIM_LOCK) -> tir -> récupération immobile -> reprise.
# Valeurs dans Balance (constantes repliées à la compilation : aucune lecture d'autoload dans la boucle chaude).
const _BAL := preload("res://scripts/core/balance.gd")
const SHOOT_INTERVAL: float = _BAL.SHOOTER_INTERVAL_S
const SALVO_CD := 8.0
const SALVO_SPREAD := 0.28
const SHOOT_RANGE_U: float = _BAL.SHOOTER_RANGE_U
const KEEP_DISTANCE_U: float = _BAL.SHOOTER_KEEP_U
const RETREAT_U: float = _BAL.SHOOTER_RETREAT_U
const PROJECTILE_SPEED_U := 6.0
## Jetons d'attaque (Doom 2016) : au plus SHOOTER_MAX_CHARGING tireurs arment en même temps. Chaque case = fin de
## réservation (s, horloge physique) ; rendue au tir ou à l'interruption, expire seule (garde-fou : mort, pool).
static var _shot_tokens := PackedFloat32Array()
## Essaim : sur place tant que _attack_cd > BITE_PAUSE_GATE (morsure récente), puis petit recul. Une comparaison
## de plus dans le chemin chaud du tier 1, aucun état ajouté.
const BITE_PAUSE_GATE: float = CONTACT_INTERVAL - _BAL.SWARM_BITE_PAUSE_S
const BITE_RECOIL_PX: float = _BAL.SWARM_BITE_RECOIL_U * U
# Tier 2 variante bondisseur : même auto (projectile / 2 s), sort Charge télégraphiée (10 s)
const VARIANT_SHOOTER := 0
const VARIANT_LEAPER := 1
const LEAP_CD := 10.0
const LEAP_WINDUP := 0.8 ## règle de lisibilité : télégraphe >= 0,8 s
const LEAP_SPEED_U := 12.0
const LEAP_LENGTH_U := 6.0
const LEAP_WIDTH_U := 1.0
const LEAP_TRIGGER_U := 5.5
const LEAP_KEEP_DISTANCE_U := 3.0
const LEAP_DMG_MULT := 1.5
# Sons de monstres : seulement près du joueur (pas d'appel audio pour les monstres hors écran)
const AUDIO_RADIUS_PX := 1100.0
const SFX_PER_FRAME := 2

static var _sfx_frame := -1
static var _sfx_budget := 0
# Tier 3 : brute
const CONE_RANGE_U := 1.9
const CONE_HALF_ANGLE := 0.70
const CONE_WINDUP := 0.6
const CONE_CD := 1.8
const SHOCK_RADIUS_U := 3.0
const SHOCK_WINDUP := 1.0
const SHOCK_CD := 12.0
const SHOCK_DMG_MULT := 1.2
# Boss prototype
const BOSS_AUTO_INTERVAL := 1.4
const BOSS_SLAM_RADIUS_U := 3.5
const BOSS_SLAM_WINDUP := 1.0
const BOSS_SLAM_CD := 8.0
const BOSS_STRIKE_RADIUS_U := 1.8
const BOSS_STRIKE_WINDUP := 0.9
const BOSS_STRIKE_CD := 5.0
const BOSS_SPELL_DMG_MULT := 1.5
## Tir automatique d'un boss armé (retour joueur : coups illisibles) : le projectile part à la frame
## d'impact de l'anim d'attaque (EnemyVisual.attack_impact_time), au plus tôt BOSS_AUTO_MIN_WINDUP
## après l'armement ; une courte ligne au sol annonce l'axe du tir pendant l'armement.
const BOSS_AUTO_MIN_WINDUP := 0.35
const BOSS_AUTO_LINE_U := 3.0
const BOSS_AUTO_LINE_WIDTH_U := 0.5
# Statuts subis (Maths §4, colonne « infligé aux monstres »)
const DOT_TICK := 0.5
## Brûlure et poison : cumuls indépendants (Tri-Tip / Sticky Bomb RoR2), chacun inflige data.total sur data.duration.
## Au-delà de DOT_MAX_STACKS, le cumul le plus ancien est remplacé (garde-fou de performance).
const BURN_DURATION := 3.0
const POISON_DURATION := 4.0
const DOT_MAX_STACKS := 10
const SLOW_DEFAULT_PCT := 0.30
const SLOW_DEFAULT_DURATION := 1.5
const FLASH_TIME := 0.08
const KB_RATE := 26.0 ## amortissement du recul (1/s) : part du reste parcourue par seconde

enum Windup { NONE, CONE, SHOCK, SLAM, STRIKE, LEAP, AUTO, SHOT, SALVO, RECOVER }

var tier := 1
var is_elite := false
var is_boss := false
var boss_kind: StringName = &""
var _boss_sprite_id: StringName = &"" ## identifiant du skin du boss (cerf, ash_lord…), &"" = placeholder
var hp := 1.0
var max_hp := 1.0
var damage := 1.0
var affixes: Array[StringName] = []
var active := false
var radius_px := 20.0
var speed_px := 100.0
var pack_bonus := false ## mis à jour par le Director (Meute)
var fight_time := 0.0 ## boss : temps de combat (enrage)
## Priorité de ciblage automatique (Design_Boss_Raid §1.9) : SpellCaster divise la distance par cette valeur
## (adds prioritaires des boss façon raid : 2). Remise à 1 à chaque activation (pool).
var aim_priority := 1.0
## Cible de marche imposée (adds prioritaires des boss façon raid : ils marchent vers leur boss, PriorityAdds) ;
## null = le joueur. Remise à null à chaque activation.
var walk_target: Node2D = null
var variant := VARIANT_SHOOTER ## tier 2 : tireur ou bondisseur

var pool_index := -1 ## index dans la liste active du Director (gestion interne)
var director: Node = null
var nav: NavField = null ## champ de flux de la carte (null = poursuite directe)

var _attack_cd := 0.0
var _spell_cd := 0.0
var _windup := Windup.NONE
var _windup_left := 0.0
var _windup_total := 1.0
var _token := -1 ## jeton d'attaque tenu (index de _shot_tokens), -1 = aucun
var _token_until := 0.0 ## fin de réservation posée par ce monstre (rendue seulement si la case est encore la sienne)
var _aim_locked := false ## tir armé : visée verrouillée (SHOOTER_AIM_LOCK atteint)
var _target := Vector2.ZERO
var _facing := 0.0
var _flash_left := 0.0
var _resolve_flip := false
var _near_wall := true ## posé par tick() (Director) : faux = aucun mur à portée, resolve() sauté
var _burn_left := 0.0 ## durée restante du cumul le plus long (0 = ne brûle pas)
var _burn_stack_left := PackedFloat32Array()
var _burn_dps := PackedFloat32Array()
var _burn_tick := 0.0
var _poison_left := PackedFloat32Array()
var _poison_dps := PackedFloat32Array()
var _poison_tick := 0.0
var _slow_left := 0.0
var _slow_pct := 0.0
var _dmg_mods := {} ## id -> Vector2(multiplicateur, s restantes ; < 0 = jusqu'au retrait) : add_damage_taken_mod
var _dmg_mod := 1.0 ## produit des multiplicateurs en cours (1 = aucun)
var _dmg_timed := false ## au moins un modificateur à durée (décompte dans tick)
## Statut `imprisoned` (pince de Tocsin, Tendeur d'Arpenteuse) : figé sur place, voir imprison().
var _held_left := 0.0
var _held_release := Vector2.ZERO ## ralentissement posé à la fin : (pct, durée s)
const HELD_ATTACK_DELAY_S := 0.3 ## libéré : pas d'attaque ni de sort avant ce délai
var _dash_left := 0.0 ## bondisseur : temps de course restant
var _dash_dir := Vector2.ZERO
var _dash_hit := false
var _near_player := false ## à portée d'oreille (sons)
var _light: LightRig.Handle = null ## élites (elite_<affixe>) et boss
# Poids des coups (coups directs) : simples compteurs du tick, ni Timer ni Tween (Balance §poids des coups)
var _stop_left := 0.0 ## hitstop : temps de gel restant (animation et déplacement en pause)
var _stop_cd := 0.0 ## délai avant qu'un nouveau gel soit possible
var _kb := Vector2.ZERO ## recul restant à parcourir (px), amorti sur quelques frames, bloqué par les murs
## IA propre à un boss (Cerf-Lanterne : CerfBrain) ; null = boss prototype générique (branche BOSS_TIER).
var brain = null ## CerfBrain | SonneurBrain | RecluseBrain | RainSowerBrain (duck typing : tick, owns_motion, clear, damage_taken_mult optionnel)

@onready var visual: Node2D = $Visual
@onready var aura: EnemyAura = $Aura
@onready var telegraph: EnemyTelegraph = $Telegraph
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _ev: EnemyVisual = $Visual ## même nœud que `visual`, typé (lecture d'état sans appel)


func _ready() -> void:
	sync_to_physics = false
	collision_mask = 0
	collision_layer = 0
	visible = false
	set_physics_process(false)
	_shape.shape = _shape.shape.duplicate() # rayon propre à chaque instance
	tree_exiting.connect(func() -> void:
		if _light != null:
			_light.release())
	HitFx.ensure(director if director != null else get_parent()) # pool de particules unique, créé avec le pool


# --- Contrat
## hit (optionnel) : {source_pos: Vector2 (point d'origine du coup : recul à l'opposé),
## force: float (force relative [0, 1] imposée ; sinon Balance.hit_force), is_dot: bool,
## anim: bool (éclat d'impact animé)}. Coup direct = flash + hitstop + recul (si source_pos) +
## étincelles ; DoT (is_dot, ou élément burn/poison) = petite particule seulement.
func take_damage(amount: float, is_crit: bool = false, element: StringName = &"", hit: Dictionary = {}) -> void:
	if not active or amount <= 0.0:
		return
	if brain != null and brain.has_method(&"damage_taken_mult"): # boss à IA propre (Sonneur P3 : +25 %)
		amount *= brain.damage_taken_mult()
	if _dmg_mod != 1.0: # modificateurs externes (lampes de la Mère-Cristal…)
		amount *= _dmg_mod
	hp -= amount
	if is_boss and hp > 0.0:
		visual.set_phase(boss_phase())
	Events.enemy_damaged.emit(self, amount, is_crit, element)
	var center := position + Vector2(0.0, -radius_px * 0.8 * Iso.UNSQUASH.y) # corps (pieds à l'origine ; hauteur en y logique = billboard × 2)
	if hit.get("is_dot", element == &"burn" or element == &"poison"):
		HitFx.dot(center, element)
	else:
		_direct_hit(amount, is_crit, element, hit, center)
	if hp <= 0.0:
		_die()


## Phase du boss selon ses PV (Balance.boss_phase) : mini-boss 2 sous 50 %, boss d'étage 66 / 33 %
## (Semeur de pluie 70 / 35 %).
func boss_phase() -> int:
	return Balance.boss_phase(boss_kind, _boss_sprite_id, hp / max_hp)


## Identifiant du boss (skin : eclusier, cerf…), &"" pour un monstre ou un boss sans skin (Profile : mémoire des boss).
func boss_id() -> StringName:
	return _boss_sprite_id if is_boss else &""


func _direct_hit(amount: float, is_crit: bool, element: StringName, hit: Dictionary, center: Vector2) -> void:
	var f: float = hit.get("force", -1.0)
	if f < 0.0:
		f = Balance.hit_force(amount, Balance.player_base_damage(RunState.level), is_crit)
	f = clampf(f, 0.0, 1.0)
	if Quality.flashes_level > 0:
		_flash_left = Balance.hit_flash_time(f)
		visual.set_flash(true)
	if not is_boss and _stop_cd <= 0.0 and GameSettings.hitstop_enabled():
		_stop_left = Balance.hitstop_time(f)
		_stop_cd = _stop_left + Balance.HITSTOP_REARM_S
		visual.set_frozen(true)
	var push := Vector2.ZERO
	# cerveau qui refuse le recul (duck typing `ignores_knockback()`) : l'Anguille, qui se déplace seule dans l'eau du
	# vrai lac (cases murs pour les marcheurs : resolve l'en éjecterait)
	if hit.has("source_pos") and not (brain != null and brain.has_method(&"ignores_knockback") and brain.ignores_knockback()):
		var away: Vector2 = position - (hit["source_pos"] as Vector2)
		if away.length_squared() > 0.01:
			push = away.normalized()
			var mass := Balance.knockback_mass(tier, is_elite, boss_kind if is_boss else &"")
			_kb = (_kb + push * Balance.knockback_px(f, mass)).limit_length(Balance.KB_MAX_U * mass * U)
	HitFx.impact(center - push * radius_px * 0.5, push, element, f, is_crit, hit.get("anim", false))


## Hitstop en cours (tests, debug).
func hitstop_left() -> float:
	return _stop_left


## Recul restant (px).
func knockback_left() -> Vector2:
	return _kb


## Poussée imposée (px), parcourue comme un recul (amortie, arrêtée par les murs). Sans effet sur un boss.
func push(offset_px: Vector2) -> void:
	if active and not is_boss:
		_kb += offset_px


## Étourdissement (Rançon d'Avare…) : figé comme un hitstop prolongé (animation, déplacement, attaques).
## Ne raccourcit jamais un gel en cours. Sans effet sur un boss.
func stun(seconds: float) -> void:
	if not active or is_boss or seconds <= 0.0:
		return
	_stop_left = maxf(_stop_left, seconds)
	_stop_cd = maxf(_stop_cd, _stop_left + Balance.HITSTOP_REARM_S)
	visual.set_frozen(true)


## Étourdi (gel en cours), pour les tests et les kits.
func is_stunned() -> bool:
	return _stop_left > 0.0


## Statut `imprisoned` (partagé par les kits) : position tenue, recul annulé, attaques, sorts et télégraphe
## suspendus, animation figée (un recul reçu est encore joué : traîné par la chaîne), ralenti total (is_slowed() vrai : synergies de ralentissement). Ne raccourcit
## jamais un emprisonnement en cours ; à la fin, ralentissement de sortie `release_pct` pendant `release_s`.
## Sans effet sur un boss. Un kit qui tient le monstre à un point appelle aussi hold_at() à chaque frame.
func imprison(seconds: float, release_pct := 0.0, release_s := 0.0) -> void:
	if not active or is_boss or seconds <= 0.0:
		return
	_held_left = maxf(_held_left, seconds)
	if release_s > 0.0:
		_held_release = Vector2(maxf(release_pct, _held_release.x), maxf(release_s, _held_release.y))
	if _windup != Windup.NONE or _dash_left > 0.0:
		_cancel_windup()
	_dash_left = 0.0
	visual.set_frozen(true)


## Fin anticipée de l'emprisonnement (membre ramassé, jambe qui le frappe) avec son ralentissement de sortie.
func release_imprison(release_pct := -1.0, release_s := -1.0) -> void:
	if _held_left <= 0.0:
		return
	_held_left = 0.0
	if release_s >= 0.0:
		_held_release = Vector2(maxf(release_pct, 0.0), release_s)
	_end_imprison()


## Emprisonné : tenu à `p` (corrigé hors des murs par le champ de flux).
func hold_at(p: Vector2) -> void:
	if _held_left <= 0.0:
		return
	_kb = Vector2.ZERO
	global_position = nav.resolve(p, radius_px) if nav != null else p


func is_imprisoned() -> bool:
	return _held_left > 0.0


func _end_imprison() -> void:
	if not active:
		return
	visual.set_frozen(_stop_left > 0.0)
	_attack_cd = maxf(_attack_cd, HELD_ATTACK_DELAY_S)
	_spell_cd = maxf(_spell_cd, HELD_ATTACK_DELAY_S)
	if _held_release.y > 0.0:
		apply_status(&"slow", {"pct": _held_release.x, "duration": _held_release.y})
	_held_release = Vector2.ZERO


func apply_status(status: StringName, data: Dictionary) -> void:
	if not active:
		return
	var total: float = data.get("total", 0.0)
	match status:
		&"burn":
			var dur: float = data.get("duration", BURN_DURATION)
			if _burn_stack_left.is_empty():
				_burn_tick = DOT_TICK
				_sfx(&"status.burn.light")
			_add_dot_stack(_burn_stack_left, _burn_dps, dur, total / dur)
			_burn_left = maxf(_burn_left, dur)
		&"poison":
			var dur: float = data.get("duration", POISON_DURATION)
			if _poison_left.is_empty():
				_poison_tick = DOT_TICK
				_sfx(&"status.poison.light")
			_add_dot_stack(_poison_left, _poison_dps, dur, total / dur)
		&"slow": # Flocon -30 % 1,5 s ; Givre {pct 0.4, duration 2 (+2 par exemplaire)}
			var pct: float = data.get("pct", SLOW_DEFAULT_PCT)
			var dur: float = data.get("duration", SLOW_DEFAULT_DURATION)
			if _slow_left <= 0.0:
				_sfx(&"status.frost.light")
			_slow_pct = maxf(pct, _slow_pct if _slow_left > 0.0 else 0.0)
			_slow_left = maxf(_slow_left, dur)
		&"imprisoned": # {duration, release_pct?, release_s?}
			imprison(float(data.get("duration", 1.0)), float(data.get("release_pct", 0.0)), float(data.get("release_s", 0.0)))


## Ajoute un cumul de DoT (tableaux modifiés en place) ; au plafond, remplace le plus ancien.
static func _add_dot_stack(lefts: PackedFloat32Array, dpss: PackedFloat32Array, dur: float, dps: float) -> void:
	if lefts.size() < DOT_MAX_STACKS:
		lefts.append(dur)
		dpss.append(dps)
		return
	var oldest := 0
	for i in lefts.size():
		if lefts[i] < lefts[oldest]:
			oldest = i
	lefts[oldest] = dur
	dpss[oldest] = dps


## Avance les cumuls d'un DoT de delta ; retourne leur dps total au début de la frame.
static func _advance_dot_stacks(lefts: PackedFloat32Array, dpss: PackedFloat32Array, delta: float) -> float:
	var dps := 0.0
	var i := lefts.size() - 1
	while i >= 0:
		dps += dpss[i]
		lefts[i] -= delta
		if lefts[i] <= 0.0:
			lefts.remove_at(i)
			dpss.remove_at(i)
		i -= 1
	return dps


func is_slowed() -> bool:
	return _slow_left > 0.0 or _held_left > 0.0


## Flash blanc de coup en cours (cerveaux de boss : corps émissif synchronisé).
func is_flashing() -> bool:
	return _flash_left > 0.0


## Rayon de collision du corps (px) ; met aussi à jour `radius_px` (boss à silhouette propre).
func set_body_radius(px: float) -> void:
	radius_px = px
	var cs := _shape.shape as CircleShape2D
	if cs != null:
		cs.radius = px


func is_burning() -> bool:
	return _burn_left > 0.0


func is_poisoned() -> bool:
	return not _poison_left.is_empty()


# --- Pool (appelé par le Director)
func activate(p_tier: int, pos: Vector2, D: float, elite: bool, p_affixes: Array[StringName], p_variant: int = VARIANT_SHOOTER) -> void:
	tier = p_tier
	variant = p_variant if p_tier == 2 else VARIANT_SHOOTER
	is_boss = false
	boss_kind = &""
	_boss_sprite_id = &""
	is_elite = elite
	var st: Dictionary = Balance.TIER_STATS[tier]
	max_hp = Balance.monster_hp(st["hp"], D) * (Balance.ELITE_HP if elite else 1.0)
	damage = Balance.monster_damage(st["dmg"], D) * (Balance.ELITE_DMG if elite else 1.0)
	speed_px = Balance.monster_speed(st["speed"], D) * U
	radius_px = RADIUS_U[tier] * U
	affixes = p_affixes if elite else ([] as Array[StringName])
	_attack_cd = randf_range(0.2, 1.0) * (SHOOT_INTERVAL if tier == 2 else (BITE_PAUSE_GATE if tier == 1 else 1.0))
	_spell_cd = randf_range(3.0, SALVO_CD if tier == 2 else SHOCK_CD)
	if variant == VARIANT_LEAPER:
		_spell_cd = randf_range(2.0, LEAP_CD * 0.5)
	_common_activate(pos)
	add_to_group(&"enemies")
	if elite and not affixes.is_empty():
		_set_light(StringName("elite_%s" % affixes[0]))


const RAID_BRAINS := {
	&"drowned_idol": "res://scripts/enemies/drowned_idol_brain.gd",
	&"flood_gunner": "res://scripts/enemies/flood_gunner_brain.gd",
	&"salt_king": "res://scripts/enemies/salt_king_brain.gd",
}


func activate_boss(kind: StringName, pos: Vector2, D: float) -> void:
	tier = BOSS_TIER
	is_boss = true
	variant = VARIANT_SHOOTER
	boss_kind = kind
	if brain != null:
		brain.clear()
		brain = null
	_boss_sprite_id = EnemyVisual.resolve_boss_id(get_tree() if is_inside_tree() else null, kind, director)
	is_elite = false
	max_hp = Balance.boss_hp(kind, D, RunState.stage) * Balance.boss_hp_mult(_boss_sprite_id)
	damage = Balance.boss_damage(kind, D)
	speed_px = Balance.monster_speed(BOSS_SPEED_U, D) * U
	radius_px = BOSS_RADIUS_U.get(kind, 1.1) * U
	affixes = [] as Array[StringName]
	fight_time = 0.0
	_attack_cd = 1.5
	_spell_cd = 3.0
	_common_activate(pos)
	add_to_group(&"enemies")
	add_to_group(&"bosses")
	_set_light(&"boss")
	if kind == &"mini": # mini-boss pilotés par données (MiniBossBrain, data/minibosses.json)
		var mini_id := MiniBossBrain.resolve_id(self)
		if MiniBossBrain.has_config(mini_id):
			brain = MiniBossBrain.new(self, mini_id)
	if _boss_sprite_id == &"cerf":
		brain = CerfBrain.new(self)
	elif _boss_sprite_id == &"sonneur":
		brain = SonneurBrain.new(self)
	elif _boss_sprite_id == &"recluse":
		brain = RecluseBrain.new(self)
	elif _boss_sprite_id == &"rain_sower":
		brain = RainSowerBrain.new(self)
	elif _boss_sprite_id == &"crane":
		brain = CraneBrain.new(self)
	elif _boss_sprite_id == &"smelter":
		brain = SmelterBrain.new(self)
	elif _boss_sprite_id == &"crystal_mother":
		brain = CrystalMotherBrain.new(self)
	elif _boss_sprite_id == &"deep_eel":
		brain = DeepEelBrain.new(self)
	elif _boss_sprite_id == &"weaver":
		brain = WeaverBrain.new(self)
	elif _boss_sprite_id == &"hermit_cedar":
		brain = HermitCedarBrain.new(self)
	elif _boss_sprite_id == &"eclusier":
		brain = EclusierBrain.new(self)
	elif _boss_sprite_id == &"ox_herder":
		brain = OxHerderBrain.new(self)
	elif _boss_sprite_id == &"jar_bearer":
		brain = JarBearerBrain.new(self)
	elif RAID_BRAINS.has(_boss_sprite_id):
		# Boss façon raid : cerveau chargé à l'exécution (un script absent ou en cours d'écriture ne casse pas le parse).
		var bs: Variant = load(RAID_BRAINS[_boss_sprite_id]) if ResourceLoader.exists(RAID_BRAINS[_boss_sprite_id]) else null
		if bs is GDScript:
			brain = (bs as GDScript).new(self)


## Lumière d'élite / de boss : une poignée gardée d'une activation à l'autre (pool), éteinte au repos.
func _set_light(preset: StringName) -> void:
	if _light == null:
		_light = LightRig.attach(self, preset)
	else:
		_light.set_preset(preset)
		_light.set_enabled(true)


## Son de monstre près du joueur. Budget global de SFX_PER_FRAME appels par image physique (coût
## borné en foule) ; `important` (télégraphes, ondes) passe toujours.
func _sfx(id: StringName, vol_db := 0.0, important := false) -> void:
	if not _near_player:
		return
	if not important:
		var f := Engine.get_physics_frames()
		if f != _sfx_frame:
			_sfx_frame = f
			_sfx_budget = SFX_PER_FRAME
		if _sfx_budget <= 0:
			return
		_sfx_budget -= 1
	Audio.play(id, position, vol_db)


func _common_activate(pos: Vector2) -> void:
	hp = max_hp
	aim_priority = 1.0
	walk_target = null
	position = pos
	active = true
	pack_bonus = false
	_windup = Windup.NONE
	_release_token()
	_aim_locked = false
	_flash_left = 0.0
	_burn_left = 0.0
	_burn_stack_left.clear()
	_burn_dps.clear()
	_poison_left.clear()
	_poison_dps.clear()
	_slow_left = 0.0
	_slow_pct = 0.0
	_dmg_mods.clear()
	_dmg_mod = 1.0
	_dmg_timed = false
	_held_left = 0.0
	_held_release = Vector2.ZERO
	_dash_left = 0.0
	_near_player = false
	_stop_left = 0.0
	_stop_cd = 0.0
	_kb = Vector2.ZERO
	visual.set_frozen(false)
	(_shape.shape as CircleShape2D).radius = radius_px
	visual.configure(tier, radius_px, is_boss, variant, _boss_sprite_id, is_elite) # élite : sprite d'élite du biome si livré (data/fauna.json)
	aura.set_affixes(affixes, radius_px)
	telegraph.hide_telegraph()
	telegraph.set_in_world(is_boss) # boss / mini-boss : télégraphe sous les corps (défaut générique)
	visible = true
	_sync_layer.call_deferred() # jamais de changement d'état physique pendant un flush


func deactivate() -> void:
	active = false
	if brain != null:
		brain.clear()
		brain = null
	visible = false
	telegraph.hide_telegraph()
	_windup = Windup.NONE
	_release_token()
	_dash_left = 0.0
	if _light != null:
		_light.set_enabled(false)
	if is_in_group(&"enemies"):
		remove_from_group(&"enemies")
	if is_in_group(&"bosses"):
		remove_from_group(&"bosses")
	_sync_layer.call_deferred()


func _sync_layer() -> void:
	collision_layer = LAYER_ENEMIES if active else 0


func _die() -> void:
	active = false # bloque toute réentrée (coups multiples dans la même frame)
	if is_boss:
		Events.boss_killed.emit(self, boss_kind == &"etage")
	else:
		Events.enemy_killed.emit(self, position, tier, is_elite)
	if director:
		director.release_enemy(self)
	else:
		deactivate()


# --- Simulation (appelée par le Director, une fois par frame physique)
## sep : poussée de séparation calculée par le Director (px/s).
## path_dir : direction du champ de flux (Vector2.ZERO = foncer droit sur le joueur).
## near_wall : faux = aucun mur à portée de résolution (Director, NavField.walls_many) -> resolve() épargné.
func tick(delta: float, player: Node2D, player_pos: Vector2, sep: Vector2, path_dir: Vector2 = Vector2.ZERO, near_wall := true) -> void:
	_near_wall = near_wall
	if _dmg_timed: # modificateurs de dégâts reçus à durée (booléen : chemin chaud de 250 monstres)
		_tick_damage_mods(delta)
	if _slow_left > 0.0 or _burn_left > 0.0 or not _poison_left.is_empty():
		_update_statuses(delta)
		if not active: # tué par un DoT
			return
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			visual.set_flash(false)
	if _stop_cd > 0.0:
		_stop_cd -= delta
		if _stop_left > 0.0: # hitstop : figé (animation, déplacement, attaques) le temps du gel
			_stop_left -= delta
			if _stop_left > 0.0:
				return
			visual.set_frozen(_held_left > 0.0)
	if _held_left > 0.0: # emprisonné (imprison) : ni marche ni attaque ; un recul reçu se joue (traîné), hold_at l'annule
		_held_left -= delta
		if _kb != Vector2.ZERO:
			_knockback_step(delta)
		if _held_left > 0.0:
			return
		_end_imprison()
	if _kb != Vector2.ZERO:
		_knockback_step(delta)
	if is_boss:
		fight_time += delta
		visual.boss_tick(delta) # fente et fin du coup armé
		if not Decoy.live.is_empty(): # mottes de Bourbe : provoquent aussi les boss (Decoy.lures_bosses)
			var blure := Decoy.nearest_boss_lure(position, Decoy.PROVOKE_RANGE_U * U)
			if blure != null:
				player = blure
				player_pos = blure.global_position
				path_dir = Vector2.ZERO
	elif not Decoy.live.is_empty(): # S14 : provoqué par la doublure la plus proche à 4 u
		var lure := Decoy.nearest_to(position, Decoy.PROVOKE_RANGE_U * U)
		if lure != null:
			player = lure
			player_pos = lure.global_position
			path_dir = Vector2.ZERO
	if walk_target != null: # add de raid : marche vers son boss (direct, sans champ de flux)
		if is_instance_valid(walk_target):
			player = walk_target
			player_pos = walk_target.global_position
			path_dir = Vector2.ZERO
		else:
			walk_target = null
	var to_player := player_pos - position
	var dist := to_player.length()
	_near_player = player != null and dist < AUDIO_RADIUS_PX
	_attack_cd -= delta
	_spell_cd -= delta

	if tier == 1 and _dash_left <= 0.0 and _windup == Windup.NONE:
		# Essaim (≈ 70 % de la foule) : chemin chaud sans calcul inutile ni appel (_move_to déroulé).
		# Toute la logique du tier 1 est ICI (perf : tests/enemies_perf, budget du Director).
		var contact1 := radius_px + PLAYER_RADIUS_PX
		var move1 := Vector2.ZERO
		if dist > contact1 * 0.85 and _attack_cd < BITE_PAUSE_GATE: # morsure récente : sur place (récupération)
			move1 = (path_dir if path_dir != Vector2.ZERO else to_player / dist) * speed_px * (1.0 + (PACK_SPEED_BONUS if pack_bonus else 0.0))
			if _slow_left > 0.0:
				move1 *= 1.0 - _slow_pct
		if dist <= contact1 and _attack_cd <= 0.0:
			_attack_cd = CONTACT_INTERVAL
			_sfx(&"enemy.contact.light")
			_hit_player(player, damage)
			if dist > 0.001:
				_kb -= to_player * (BITE_RECOIL_PX / dist)
		var p1 := position + (move1 + sep) * delta
		_resolve_flip = not _resolve_flip
		if _resolve_flip and _near_wall and nav:
			p1 = nav.resolve(p1, radius_px)
		position = p1
		return

	var dir := to_player / dist if dist > 0.001 else Vector2.RIGHT
	var go := path_dir if path_dir != Vector2.ZERO else dir # direction d'approche (contourne les murs)
	var slow_mult := (1.0 - _slow_pct) if _slow_left > 0.0 else 1.0
	var move := Vector2.ZERO

	if _dash_left > 0.0:
		_dash_step(delta, player, player_pos)
		return

	if _windup != Windup.NONE:
		_windup_left -= delta
		telegraph.set_progress(1.0 - _windup_left / _windup_total)
		if is_boss: # le boss suit le joueur des yeux pendant tout le télégraphe
			_facing = dir.angle()
			visual.set_facing(_facing)
		elif not _aim_locked and (_windup == Windup.SHOT or _windup == Windup.SALVO):
			# tir armé : la visée suit le joueur, puis se verrouille (éclat plus vif) pour laisser l'esquive
			_facing = dir.angle()
			visual.set_facing(_facing)
			telegraph.rotation = _facing
			if _windup_left <= _windup_total * (1.0 - _BAL.SHOOTER_AIM_LOCK):
				_aim_locked = true
				visual.set_charge(2)
		if _windup_left <= 0.0:
			_resolve_windup(player, player_pos)
		_move_to(position + sep * delta * 0.3)
		return

	match tier:
		2 when variant == VARIANT_LEAPER:
			var keep_l := LEAP_KEEP_DISTANCE_U * U
			if _spell_cd <= 0.0 and dist < LEAP_TRIGGER_U * U and path_dir == Vector2.ZERO:
				_spell_cd = LEAP_CD
				_facing = dir.angle()
				visual.set_facing(_facing)
				visual.set_action(&"charge")
				visual.set_charge(1)
				_start_windup(Windup.LEAP, LEAP_WINDUP, position)
				telegraph.show_line(position, _facing, LEAP_LENGTH_U * U, LEAP_WIDTH_U * U)
				_sfx(&"telegraph.warn_light.light", 0.0, true)
				return
			if dist > keep_l:
				move = go * speed_px
			elif dist < keep_l * 0.6:
				move = -dir * speed_px * 0.5
			if _attack_cd <= 0.0 and dist <= SHOOT_RANGE_U * U and path_dir == Vector2.ZERO:
				if _begin_shot(dir, false):
					return
		2:
			if dist <= SHOOT_RANGE_U * U and path_dir == Vector2.ZERO and (_spell_cd <= 0.0 or _attack_cd <= 0.0):
				if _begin_shot(dir, _spell_cd <= 0.0): # tire seulement en ligne de vue, à l'arrêt
					return
			if dist > KEEP_DISTANCE_U * U:
				move = go * speed_px
			elif dist < RETREAT_U * U: # repli plus lent que le joueur
				move = -dir * speed_px * _BAL.SHOOTER_RETREAT_SPEED
		3:
			if _spell_cd <= 0.0 and dist < SHOCK_RADIUS_U * U * 0.85:
				_spell_cd = SHOCK_CD
				visual.set_charge(1)
				visual.set_action(&"cast", true) # pose d'armement (anim cast_<dir>), tenue jusqu'à la fin de RECOVER
				_start_windup(Windup.SHOCK, SHOCK_WINDUP, position)
				telegraph.show_circle(position, SHOCK_RADIUS_U * U)
				_sfx(&"telegraph.warn_heavy.heavy", 0.0, true)
			elif _attack_cd <= 0.0 and dist < CONE_RANGE_U * U:
				_attack_cd = CONE_CD
				_facing = dir.angle()
				visual.set_facing(_facing)
				visual.set_charge(1)
				visual.set_action(&"attack", true) # coup porté à la fin de l'anim (8 frames à 12 i/s ≈ armement)
				_start_windup(Windup.CONE, CONE_WINDUP, position)
				telegraph.show_cone(position, _facing, CONE_RANGE_U * U, CONE_HALF_ANGLE)
				_sfx(&"telegraph.warn_light.light", -4.0)
			elif dist > CONE_RANGE_U * U * 0.7:
				move = go * speed_px
		BOSS_TIER when brain != null: # Cerf-Lanterne : IA à phases (scripts/enemies/cerf_brain.gd)
			move = brain.tick(delta, player, player_pos, dir, dist, path_dir)
			if brain.owns_motion():
				return
		BOSS_TIER:
			_facing = dir.angle() # face au joueur (la marche reprend la direction du pas plus bas)
			visual.set_facing(_facing)
			if visual.is_attacking(): # fin du coup (retour de fente) : le boss reste planté
				pass
			elif _spell_cd <= 0.0:
				_spell_cd = BOSS_SLAM_CD if dist < BOSS_SLAM_RADIUS_U * U else BOSS_STRIKE_CD
				if dist < BOSS_SLAM_RADIUS_U * U:
					visual.play_attack(&"cast_a", BOSS_SLAM_WINDUP, dir)
					_start_windup(Windup.SLAM, BOSS_SLAM_WINDUP, position)
					telegraph.show_circle(position, BOSS_SLAM_RADIUS_U * U)
				else:
					visual.play_attack(&"cast_b", BOSS_STRIKE_WINDUP, dir)
					_start_windup(Windup.STRIKE, BOSS_STRIKE_WINDUP, player_pos)
					telegraph.show_circle(player_pos, BOSS_STRIKE_RADIUS_U * U)
				_sfx(&"telegraph.boss.heavy", 0.0, true)
				return
			elif _attack_cd <= 0.0 and path_dir == Vector2.ZERO:
				_attack_cd = BOSS_AUTO_INTERVAL
				var wind := maxf(visual.attack_impact_time(&"attack"), BOSS_AUTO_MIN_WINDUP)
				visual.play_attack(&"attack", wind, dir)
				_start_windup(Windup.AUTO, wind, player_pos)
				telegraph.show_line(position, _facing, BOSS_AUTO_LINE_U * U, BOSS_AUTO_LINE_WIDTH_U * U)
				_sfx(&"telegraph.warn_light.light", -6.0)
				return
			elif dist > radius_px + 2.0 * U:
				move = go * speed_px

	if tier != 1 and move != Vector2.ZERO:
		_facing = move.angle()
		# perf : appel évité quand l'octant du sprite ne change pas (set_facing n'y ferait rien) ;
		# facing_octant < 0 = pas de sprite 8 directions (placeholder) -> toujours transmis
		var oct := _ev.facing_octant
		if is_boss or oct < 0 or oct != posmod(roundi(_facing / (TAU / 8.0)), 8):
			visual.set_facing(_facing)
	if is_boss:
		visual.set_action(&"run" if move != Vector2.ZERO else &"idle")
	_move_to(position + (move * slow_mult + sep) * delta)


## Déplacement avec résolution de pénétration contre les obstacles de la carte, une frame sur
## deux (pénétration transitoire ≤ ~7 px, le centre ne rentre jamais dans un mur) ; boss : à
## chaque frame.
func _move_to(p: Vector2) -> void:
	_resolve_flip = not _resolve_flip
	if nav and (is_boss or (_resolve_flip and _near_wall)):
		p = nav.resolve(p, radius_px)
	position = p


## Recul : ~35 % du reste par frame à 60 Hz (≈ 0,15 s), résolu contre les murs à chaque pas avec
## le même NavField que le déplacement (pas ≤ ~17 px < rayon : aucun mur traversé) ; un mur l'arrête.
func _knockback_step(delta: float) -> void:
	var step := _kb * minf(1.0, delta * KB_RATE)
	_kb -= step
	if _kb.length_squared() < 0.25:
		_kb = Vector2.ZERO
	var want := position + step
	var p := nav.resolve(want, radius_px) if nav else want
	if p.distance_squared_to(want) > 1.0:
		_kb = Vector2.ZERO
	position = p


## Point unique de l'arrêt « armement / récupération » des monstres sans cerveau (SHOT, SALVO, RECOVER…) : la
## branche `_windup != NONE` de tick() les tient sur place. Pas d'API publique `hold_still(duration)` :
## les boss passent par BossPace (cerveau qui possède son mouvement : owns_motion/planted), et un arrêt imposé
## de l'extérieur existe déjà sous deux formes, stun() (gel complet) et imprison()/hold_at() (tenu, recul joué).
## Une quatrième voie dupliquerait ces états ; ajouter plutôt une catégorie ici ou dans BossPace.
func _start_windup(kind: Windup, duration: float, target: Vector2) -> void:
	_windup = kind
	_windup_left = duration
	_windup_total = duration
	_target = target


## Tireur et bondisseur : demande un jeton puis s'arrête et arme le tir (`salvo` : salve de 3, sort).
## Faux sans jeton libre : le monstre continue de se placer et réessaie après SHOOTER_TOKEN_RETRY_S.
func _begin_shot(dir: Vector2, salvo: bool) -> bool:
	var leaper := variant == VARIANT_LEAPER
	var wind: float = _BAL.SHOOTER_SALVO_WINDUP_S if salvo else (_BAL.LEAPER_SHOT_WINDUP_S if leaper else _BAL.SHOOTER_WINDUP_S)
	if not _take_token(wind):
		_attack_cd = maxf(_attack_cd, _BAL.SHOOTER_TOKEN_RETRY_S)
		if salvo:
			_spell_cd = maxf(_spell_cd, _BAL.SHOOTER_TOKEN_RETRY_S)
		return false
	var interval := SHOOT_INTERVAL * randf_range(1.0 - _BAL.SHOOTER_INTERVAL_JITTER, 1.0 + _BAL.SHOOTER_INTERVAL_JITTER)
	if salvo:
		_spell_cd = SALVO_CD
		_attack_cd = maxf(_attack_cd, wind + _BAL.SHOOTER_SALVO_RECOVERY_S + 0.8)
	else:
		_attack_cd = interval
	_facing = dir.angle()
	_aim_locked = false
	visual.set_facing(_facing)
	visual.set_action(&"attack", true) # bondisseur : pas encore de pose (lot Codex MB1) -> repli run, teinte et ligne
	visual.set_charge(1)
	_start_windup(Windup.SALVO if salvo else Windup.SHOT, wind, position)
	if salvo:
		telegraph.show_cone(position, _facing, _BAL.SHOOTER_SALVO_CONE_U * U, SALVO_SPREAD + 0.1)
	else:
		telegraph.show_line(position, _facing, _BAL.SHOOTER_AIM_LINE_U * U, _BAL.SHOOTER_AIM_LINE_WIDTH_U * U)
	_sfx(&"telegraph.warn_light.light", -4.0 if salvo else -9.0, salvo)
	return true


## Interrompt un armement, une récupération ou une course (emprisonnement) : télégraphe, jeton et pose rendus.
func _cancel_windup() -> void:
	_windup = Windup.NONE
	telegraph.hide_telegraph()
	_release_token()
	visual.set_charge(0)
	visual.set_action(&"run")


## Horloge des jetons (s) : images physiques, indépendante du temps réel (tests accélérés, pauses).
static func _token_clock() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


## Prend un jeton d'attaque à distance pour `hold_s` (+ marge : gel, ralenti). Vrai si obtenu.
func _take_token(hold_s: float) -> bool:
	if _token >= 0:
		return true
	if _shot_tokens.size() != _BAL.SHOOTER_MAX_CHARGING:
		_shot_tokens.resize(_BAL.SHOOTER_MAX_CHARGING)
		_shot_tokens.fill(0.0)
	var now := _token_clock()
	for i in _shot_tokens.size():
		if _shot_tokens[i] <= now:
			_shot_tokens[i] = now + hold_s + 1.0
			_token_until = _shot_tokens[i] # relu : valeur arrondie en float32, comparée telle quelle au rendu
			_token = i
			return true
	return false


func _release_token() -> void:
	if _token >= 0 and _token < _shot_tokens.size() and _shot_tokens[_token] == _token_until:
		_shot_tokens[_token] = 0.0
	_token = -1


## Tireurs en train d'armer (jetons tenus et non expirés), pour les tests et le debug.
static func charging_shooters() -> int:
	var now := _token_clock()
	var n := 0
	for t in _shot_tokens:
		if t > now:
			n += 1
	return n


## Remet les jetons à zéro (tests, changement de scène).
static func reset_shot_tokens() -> void:
	_shot_tokens.fill(0.0)


func _resolve_windup(player: Node2D, player_pos: Vector2) -> void:
	var kind := _windup
	_windup = Windup.NONE
	telegraph.hide_telegraph()
	match kind:
		Windup.LEAP:
			visual.set_charge(0)
			_dash_dir = Vector2.from_angle(_facing)
			_dash_left = LEAP_LENGTH_U / LEAP_SPEED_U
			_dash_hit = false
		Windup.CONE:
			visual.set_charge(0)
			_sfx(&"enemy.brute_cone.heavy")
			var v := player_pos - _target
			var reach := CONE_RANGE_U * U + PLAYER_RADIUS_PX
			if v.length() <= reach and absf(angle_difference(_facing, v.angle())) <= CONE_HALF_ANGLE + 0.15:
				_hit_player(player, damage)
			_start_windup(Windup.RECOVER, _BAL.BRUTE_RECOVERY_S, position)
		Windup.SHOCK:
			visual.set_charge(0)
			_sfx(&"enemy.shockwave.heavy")
			if _target.distance_to(player_pos) <= SHOCK_RADIUS_U * U + PLAYER_RADIUS_PX:
				_hit_player(player, damage * SHOCK_DMG_MULT)
			_start_windup(Windup.RECOVER, _BAL.BRUTE_RECOVERY_S, position)
		Windup.SHOT, Windup.SALVO: # visée verrouillée (_facing) : un pas de côté pendant l'éclat esquive
			_release_token()
			visual.set_charge(0)
			var aim := Vector2.from_angle(_facing)
			if kind == Windup.SALVO:
				for k in 3:
					_shoot(aim.rotated((k - 1) * SALVO_SPREAD))
				_start_windup(Windup.RECOVER, _BAL.SHOOTER_SALVO_RECOVERY_S, position)
			else:
				_shoot(aim)
				_start_windup(Windup.RECOVER, _BAL.LEAPER_SHOT_RECOVERY_S if variant == VARIANT_LEAPER else _BAL.SHOOTER_RECOVERY_S, position)
		Windup.RECOVER:
			visual.set_action(&"run")
		Windup.SLAM:
			_sfx(&"enemy.shockwave.heavy", 2.0, true)
			if _target.distance_to(player_pos) <= BOSS_SLAM_RADIUS_U * U + PLAYER_RADIUS_PX:
				_hit_player(player, damage * BOSS_SPELL_DMG_MULT)
		Windup.STRIKE:
			if _target.distance_to(player_pos) <= BOSS_STRIKE_RADIUS_U * U + PLAYER_RADIUS_PX:
				_hit_player(player, damage * BOSS_SPELL_DMG_MULT)
		Windup.AUTO: # frame d'impact : le tir part vers la position actuelle du joueur
			var to := player_pos - position
			_shoot(to.normalized() if to.length_squared() > 0.01 else Vector2.from_angle(_facing))


## Course du bondisseur : ligne droite à LEAP_SPEED_U, un seul coup au contact, s'arrête sur un mur.
func _dash_step(delta: float, player: Node2D, player_pos: Vector2) -> void:
	_dash_left -= delta
	var want := position + _dash_dir * LEAP_SPEED_U * U * delta
	var p := nav.resolve(want, radius_px) if nav else want
	var blocked := p.distance_squared_to(want) > 4.0
	position = p
	if not _dash_hit and player != null and position.distance_to(player_pos) <= radius_px + PLAYER_RADIUS_PX:
		_dash_hit = true
		_hit_player(player, damage * LEAP_DMG_MULT)
	if _dash_left <= 0.0 or blocked:
		_dash_left = 0.0 # pose de charge tenue pendant la récupération (RECOVER rend la course)
		_start_windup(Windup.RECOVER, _BAL.LEAPER_DASH_RECOVERY_S, position)


## Dégâts courants (enrage inclus pour un boss).
func current_damage() -> float:
	return damage * (Balance.boss_enrage_mult(fight_time) if is_boss else 1.0)


func _hit_player(player: Node2D, amount: float) -> void:
	if player == null:
		return
	var dmg := amount * (Balance.boss_enrage_mult(fight_time) if is_boss else 1.0)
	if player.has_method(&"take_damage"):
		player.take_damage(dmg, self)
	apply_affixes_to(player, dmg)


## Applique les affixes d'élite au joueur touché (aussi utilisé par les projectiles).
func apply_affixes_to(player: Node2D, hit: float) -> void:
	if affixes.is_empty() or not player.has_method(&"apply_status"):
		return
	for a in affixes:
		player.apply_status(a, {"hit": hit, "source": self}) # source : filtres du joueur (Rainette en l'air)


func _shoot(dir: Vector2) -> void:
	_sfx(&"enemy.shot.medium")
	if director:
		director.fire_projectile(self, position + dir * radius_px, dir * PROJECTILE_SPEED_U * U, current_damage())


func _update_statuses(delta: float) -> void:
	# Epsilon de tick : le dernier tick (à 3 s / 4 s pile) ne doit pas être perdu par dérive flottante.
	if _slow_left > 0.0:
		_slow_left -= delta
	if not _burn_stack_left.is_empty():
		_burn_left -= delta
		var burn_dps := _advance_dot_stacks(_burn_stack_left, _burn_dps, delta)
		if _burn_stack_left.is_empty():
			_burn_left = 0.0
		_burn_tick -= delta
		if _burn_tick <= 0.001:
			_burn_tick += DOT_TICK
			take_damage(burn_dps * DOT_TICK, false, &"burn")
			if not active:
				return
	if not _poison_left.is_empty():
		var dps := _advance_dot_stacks(_poison_left, _poison_dps, delta) # cumuls actifs au début de la frame
		_poison_tick -= delta
		if _poison_tick <= 0.001:
			_poison_tick += DOT_TICK
			take_damage(dps * DOT_TICK, false, &"poison")


# --- Barres de PV (lecture seule ; BossBars, EnemyHealthBars ; CONTRACTS.md « Barres de PV »)
## Bits de status_mask().
const ST_BURN := 1
const ST_POISON := 2
const ST_FROST := 4 ## ralentissement (Flocon, Givre) = « gel »
const ST_STUN := 8
const ST_HELD := 16 ## emprisonné
## Un gel plus long qu'un hitstop (plafond Balance.HITSTOP_MAX_S) se lit comme un étourdissement.
const STUN_SHOW_MIN_S := 0.1
var _stagger_brain_id := 0 ## cache de phase_transitioning() : cerveau dont S.STAGGER est connu
var _stagger_state := -1


## Seuils de phase en fraction de PV restante, décroissants (ex. [0.70, 0.35]) ; vide = pas de phase.
## Ordre : le cerveau s'il définit `phase_thresholds()`, sinon mini-boss `phase2.threshold`
## (data/minibosses.json, défaut Balance.MINI_BOSS_PHASE_THRESHOLD), sinon Balance.BOSS_PHASE_THRESHOLDS.
## Monstres et élites : vide (sauf cerveau qui en définit).
func phase_thresholds() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if brain != null and brain.has_method(&"phase_thresholds"):
		for v in brain.phase_thresholds():
			out.append(float(v))
	elif not is_boss:
		return out
	elif boss_kind == &"mini":
		var th := Balance.MINI_BOSS_PHASE_THRESHOLD
		var c: Variant = brain.get(&"cfg") if brain != null else null
		if c is Dictionary:
			var p2: Variant = (c as Dictionary).get("phase2")
			if p2 is Dictionary:
				th = float((p2 as Dictionary).get("threshold", th))
		out.append(th)
	else:
		for v in Balance.BOSS_PHASE_THRESHOLDS.get(_boss_sprite_id, Balance.BOSS_PHASE_THRESHOLDS_DEFAULT):
			out.append(float(v))
	out.sort()
	out.reverse()
	return out


## Transition de phase en cours (boss figé) : `brain.is_phase_transition()` s'il existe, sinon état S.STAGGER
## du cerveau (tous les cerveaux de boss et MiniBossBrain).
func phase_transitioning() -> bool:
	if brain == null:
		return false
	if brain.has_method(&"is_phase_transition"):
		return bool(brain.is_phase_transition())
	var id: int = brain.get_instance_id()
	if id != _stagger_brain_id:
		_stagger_brain_id = id
		_stagger_state = -1
		var sc: Script = brain.get_script()
		var s: Variant = sc.get_script_constant_map().get("S") if sc != null else null
		if s is Dictionary:
			_stagger_state = int((s as Dictionary).get("STAGGER", -1))
	var st: Variant = brain.get(&"state")
	return _stagger_state >= 0 and st is int and int(st) == _stagger_state


## API publique : multiplicateur de dégâts reçus posé par un autre système (lampes de la Mère-Cristal : 1,15).
## `id` = clé (StringName…) : le même id remplace son multiplicateur et prolonge sa durée ; ids différents =
## produit. `duration` s (< 0 : jusqu'à remove_damage_taken_mod). Appliqué dans take_damage APRÈS
## brain.damage_taken_mult() (qui garde ses effets propres) ; remis à zéro à chaque activation (pool).
func add_damage_taken_mod(id: Variant, mult: float, duration: float = -1.0) -> void:
	var cur: Vector2 = _dmg_mods.get(id, Vector2(1.0, 0.0))
	var left := -1.0 if duration < 0.0 else maxf(cur.y, duration)
	_dmg_mods[id] = Vector2(maxf(mult, 0.0), left)
	_dmg_mod = _damage_mods_product()
	_dmg_timed = _dmg_timed or left >= 0.0


func remove_damage_taken_mod(id: Variant) -> void:
	if _dmg_mods.erase(id):
		_dmg_mod = _damage_mods_product()


func has_damage_taken_mod(id: Variant) -> bool:
	return _dmg_mods.has(id)


## Produit des modificateurs externes (lecture pure, sans effet de bord ; n'inclut pas le cerveau).
func damage_taken_mod() -> float:
	return _dmg_mod


func _damage_mods_product() -> float:
	var m := 1.0
	for v: Vector2 in _dmg_mods.values():
		m *= v.x
	return m


func _tick_damage_mods(delta: float) -> void:
	var gone := false
	for k in _dmg_mods.keys():
		var v: Vector2 = _dmg_mods[k]
		if v.y < 0.0:
			continue
		v.y -= delta
		if v.y <= 0.0:
			_dmg_mods.erase(k)
			gone = true
		else:
			_dmg_mods[k] = v
	if gone:
		_dmg_mod = _damage_mods_product()
	var timed := false
	for v: Vector2 in _dmg_mods.values():
		timed = timed or v.y >= 0.0
	_dmg_timed = timed


## Intouchable (affichage) : `brain.is_invulnerable()` s'il existe, sinon mini-boss enfoui/évanoui (`hidden`).
## N'appelle jamais damage_taken_mult() (effets de bord : rage).
func is_invulnerable() -> bool:
	if brain == null:
		return false
	if brain.has_method(&"is_invulnerable"):
		return bool(brain.is_invulnerable())
	return brain.get(&"hidden") == true


## Statuts actifs (bits ST_*), lecture sans allocation pour les barres de monstres.
func status_mask() -> int:
	var m := 0
	if _burn_left > 0.0:
		m |= ST_BURN
	if not _poison_left.is_empty():
		m |= ST_POISON
	if _slow_left > 0.0:
		m |= ST_FROST
	if _stop_left > STUN_SHOW_MIN_S:
		m |= ST_STUN
	if _held_left > 0.0:
		m |= ST_HELD
	return m


## Statuts détaillés (barres riches : élites, mini-boss, boss) :
## [{id: &"burn"|&"poison"|&"frost"|&"stun"|&"imprisoned", left: s restantes, stacks: int}].
func status_list() -> Array:
	var out: Array = []
	if _burn_left > 0.0:
		out.append({"id": &"burn", "left": _burn_left, "stacks": maxi(_burn_stack_left.size(), 1)})
	if not _poison_left.is_empty():
		var l := 0.0
		for v in _poison_left:
			l = maxf(l, v)
		out.append({"id": &"poison", "left": l, "stacks": _poison_left.size()})
	if _slow_left > 0.0:
		out.append({"id": &"frost", "left": _slow_left, "stacks": 1})
	if _stop_left > STUN_SHOW_MIN_S:
		out.append({"id": &"stun", "left": _stop_left, "stacks": 1})
	if _held_left > 0.0:
		out.append({"id": &"imprisoned", "left": _held_left, "stacks": 1})
	return out
