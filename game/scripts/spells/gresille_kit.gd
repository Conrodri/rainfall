class_name GresilleKit
extends Node
## Kit de Grésille, la paratonnerrière (docs/fiches/gresille.md) : électricité, distance moyenne, état « Statique »
## porté par les monstres (registre GresilleStatic, jamais par Enemy). Enfant « Kit » du joueur (CharacterData.kit_script),
## interrogé par hooks comme AverseKit / VigieKit. Aucune ressource, aucune jauge.
## - Sort 1 Arc : hitscan 7 u sur le monstre le plus proche (coef 0,8) puis rebond 0,45 sur un voisin à <= 2,5 u
##   (<= 4,5 u si l'un des deux est mouillé). Chaque coup dépose 1 Statique (2 sur un mouillé).
## - Sort 2 Décharge : sur le monstre le plus CHARGÉ (hook pick_target), coef 2,8 + 0,15 n, consomme ses n cumuls, puis
##   n arcs de 0,6 vers n voisins distincts à <= 3 u (<= 5 u si mouillé).
## - Sort 3 Mise à la terre : zone 3 u sous Grésille, 5 s, tick 0,5 s, ralentit 20 %, +1 Statique par tick ; sur l'eau,
##   elle épouse la nappe d'eau connexe (StageMap.water_patch_at, plafond 113 cases de 1 u = rayon 6 u).
## - Sort 4 Orage appelé : canalisé 3 s (marche à 70 %, sort 1 suspendu), 6 coups de foudre (1 / 0,5 s) sur le monstre le
##   plus chargé à <= 7 u, cercle 1,5 u, 1,3 + 0,05 n par coup ; l'esquive l'interrompt.
## - Esquive Court-circuit : roulade invulnérable dont le sillage (0,5 s) dépose +1 Statique aux monstres traversés.
## - Statique : 1-5 cumuls, 6 s ; 3 = crispé (ralenti 20 %) ; 5 = le prochain coup foudroie (étourdi 0,5 s ; boss +10 %
##   de dégâts subis 2 s). Voir GresilleStatic.
## - Isolée (trait) : -50 % de dégâts d'une flaque électrisée de mini-boss (le ralentissement n'est pas neutralisé :
##   aucun contrat côté joueur, voir rapport).
## Rendu : gresille.tres (lot GR1) ; VFX GR2 absents = arcs ChainLightningFx existants + placeholders marqués ci-dessous.

# --- Assets --------------------------------------------------------------------------------------------
const ASSET_DIR := "res://assets/sprites/characters/gresille/"
const SPRITE_FRAMES := ASSET_DIR + "gresille.tres" ## idle/run/attack/cast/ground/call/cast_ult/death _<dir>
const PLACEHOLDER_TINT := Color("#4F6B5E") ## Ardent teinté vert-de-gris si GR1 manquait

# --- Rendu ----------------------------------------------------------------------------------------------
const ACCENT := Color("#B9A6FF") ## lilas d'arc : accent émissif unique
const CORE := Color("#F2EEFF")
const PLAYER_LIGHT_COLOR := Color("#D9D4E8") ## blanc de pluie à peine violet
const EMISSION_LOW := 0.6 ## énergie du `_e` des bouteilles, Décharge à 0 % de recharge
const EMISSION_FULL := 3.0 ## Décharge prête
const EMISSION_STEPS := 10
const ACTION_IMPACT_FRAMES := {&"attack": 2, &"cast": 3, &"ground": 3, &"call": 2}
const CALL_LOOP_FROM := 3 ## `call` : la boucle de canalisation reprend à la frame 3
const LABEL_COLOR := ACCENT

# --- Statistiques (fiche §8) -------------------------------------------------------------------------
const BASE_HP := 95.0
const HP_PER_LEVEL := 28.0
const BASE_REGEN := 1.0
const REGEN_PER_LEVEL := 0.2
const ARMOR := 5.0
const SPEED_U := 4.1
const STORM_SPEED_U := 2.9 ## pendant l'Orage (70 %)
const HITBOX_U := 0.45

# --- Sorts (fiche §4) ---------------------------------------------------------------------------------
const ARC_COEF := 0.8
const ARC_RANGE_U := 7.0
const ARC_CD := 0.6
const ARC_PROC := 0.9
const BOUNCE_COEF := 0.45
const BOUNCE_U := 2.5
const BOUNCE_PROC := 0.5
const WET_BONUS_U := 2.0 ## les arcs sautent 2 u plus loin vers / depuis un mouillé
const ARC_KNOCK_U := 0.2

const DISCHARGE_COEF := 2.8
const DISCHARGE_PER_STACK := 0.15
const DISCHARGE_CD := 7.0
const DISCHARGE_RANGE_U := 8.0
const DISCHARGE_PROC := 1.0
const DISCHARGE_KNOCK_U := 0.5
const DISCHARGE_ARC_COEF := 0.6
const DISCHARGE_ARC_U := 3.0
const DISCHARGE_ARC_PROC := 0.6
const DISCHARGE_AIM_U := 2.0 ## PC : monstre le plus chargé à <= 2 u du curseur

const GROUND_COEF := 0.45
const GROUND_CD := 10.0
const GROUND_RADIUS_U := 3.0
const GROUND_LIFE_S := 5.0
const GROUND_TICK_S := 0.5
const GROUND_PROC := 0.3
const GROUND_WATER_CELLS_MAX := 113 ## cases de 1 u : rayon 6 u
const GROUND_SLOW_S := 0.75 ## rafraîchi à chaque tick

const STORM_COEF := 1.3
const STORM_PER_STACK := 0.05
const STORM_CD := 22.0
const STORM_STRIKES := 6
const STORM_INTERVAL_S := 0.5
const STORM_RANGE_U := 7.0
const STORM_RADIUS_U := 1.5
const STORM_PROC := 1.0
const STORM_KNOCK_U := 0.8
const VFX_DIR := "res://assets/sprites/vfx/gresille/"
const STORM_SKY_PX := 320.0 ## hauteur logique du point de départ de la foudre (arc ChainLightningFx, repli de bolt_strike)

const WAKE_S := 0.5 ## sillage du Court-circuit
const WAKE_RADIUS_U := 0.6
const WAKE_WIDTH_U := 0.6
const WAKE_FADE_S := 0.5

const ISOLEE_MULT := 0.5 ## -50 % d'une flaque électrisée de mini-boss

const COMBO_READY_STACKS := 4 ## Décharge : bouton qui pulse quand une cible a au moins 4 cumuls à portée
const POLL_S := 0.25
const CRISP_POLL_S := 0.4
const CRISP_REFRESH_S := 0.6
const FLASH_S := 0.08

## Compteur de déblocage de la variante Paratonnerre (RunState.add_counter, versé dans Profile.stats).
const COUNTER_GROUNDED_WET := "gresille.grounded_wet"

const SOUND_ZAP := &"lightning.zap.light" ## repli des sons GR (à produire : voir rapport)
const SOUND_CHAIN := &"lightning.chain_start.medium"

const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

var player: CharacterBody2D = null
var reg := GresilleStatic.new()
var field: Node = null ## Mise à la terre vivante (ZoneEffect disque ou GresilleGroundField nappe)
var storm_left := 0.0 ## s de canalisation restantes (> 0 : l'Orage tient la tige levée)
var storm_strikes_done := 0
var _storm_pending := false ## Orage lancé, la frame d'impact n'est pas encore passée
var _storm_t := 0.0
var _visual: AnimatedSprite2D = null
var _pending: Array = [] ## [{base, fn, t}] effets en attente de la frame d'impact
var _clock := 0.0
var _poll_t := 0.0
var _crisp_t := 0.0
var _emission_step := -1
var _ready_flags := {2: false, 4: false}
var _label: Label = null
var _label_target: Node2D = null
var _trail: Array = [] ## [{p: Vector2, t: float}] sillage du Court-circuit
var _wake_victims := {}
var _wake_line: Line2D = null
var _last_call_frame := -1
var _bounce_spell: SpellData = null
var _discharge_arc_spell: SpellData = null


# --- Données --------------------------------------------------------------------------------------------

static func _force_for(knock_u: float) -> float:
	return clampf(inverse_lerp(Balance.KB_MIN_U, Balance.KB_MAX_U, knock_u), 0.0, 1.0)


static func _spell(sid: StringName, name: String, slot: int, coef: float, cd: float) -> SpellData:
	var s := SpellData.new()
	s.id = sid
	s.display_name = name
	s.slot = slot
	s.behavior = SpellData.Behavior.KIT
	s.coef = coef
	s.base_cooldown = cd
	s.element = &"lightning"
	s.color = ACCENT
	s.light_preset = &"spell_lightning"
	s.is_zone = false
	return s


static func character() -> CharacterData:
	var c := CharacterData.new()
	c.id = &"gresille"
	c.display_name = "Grésille"
	c.base_hp = BASE_HP
	c.hp_per_level = HP_PER_LEVEL
	c.armor = ARMOR
	c.base_regen = BASE_REGEN
	c.regen_per_level = REGEN_PER_LEVEL
	c.base_speed_u = SPEED_U
	c.hitbox_u = HITBOX_U
	c.kit_script = GresilleKit
	c.sprite_frames_path = SPRITE_FRAMES
	c.placeholder_tint = PLACEHOLDER_TINT
	c.body_color = Color("#5A5E66")
	c.accent_color = ACCENT
	c.light_color = PLAYER_LIGHT_COLOR
	c.light_core_color = CORE
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"gresille_arc", "Arc", 1, ARC_COEF, ARC_CD)
	s1.is_auto = true
	s1.range_u = ARC_RANGE_U
	s1.trigger_range_u = ARC_RANGE_U
	s1.proc_coef = ARC_PROC
	s1.hit_force = _force_for(ARC_KNOCK_U)

	var s2 := _spell(&"gresille_decharge", "Décharge", 2, DISCHARGE_COEF, DISCHARGE_CD)
	s2.range_u = DISCHARGE_RANGE_U
	s2.trigger_range_u = DISCHARGE_RANGE_U
	s2.proc_coef = DISCHARGE_PROC
	s2.target_mode = &"most_stacked" # contrat : le plus chargé (hook kit.pick_target), sinon le plus proche
	s2.hit_force = _force_for(DISCHARGE_KNOCK_U)

	var s3 := _spell(&"gresille_terre", "Mise à la terre", 3, GROUND_COEF, GROUND_CD)
	s3.is_zone = true
	s3.radius_u = GROUND_RADIUS_U
	s3.duration = GROUND_LIFE_S
	s3.tick = GROUND_TICK_S
	s3.proc_coef = GROUND_PROC
	s3.trigger_range_u = GROUND_RADIUS_U
	s3.range_u = 0.0
	s3.zone_outline_color = ACCENT
	s3.vfx_frames = VFX_DIR + "ground_field/ground_field.tres" # disque à sec (GR2) ; la nappe d'eau utilise ground_tile
	s3.vfx_radius_px = 190.0 # rayon du disque dans la frame 384x384
	s3.vfx_floor_aspect = 1.0 # rig TOP : jamais pré-écrasé

	var s4 := _spell(&"gresille_orage", "Orage appelé", 4, STORM_COEF, STORM_CD)
	s4.radius_u = STORM_RADIUS_U
	s4.range_u = STORM_RANGE_U
	s4.trigger_range_u = STORM_RANGE_U
	s4.proc_coef = STORM_PROC
	s4.hit_force = _force_for(STORM_KNOCK_U)

	c.spells = [s1, s2, s3, s4]
	return c


## Sorts internes (rebond, arcs de Décharge, coup d'Orage) : jamais dans le kit du personnage, seulement dans deal_damage.
func _make_internal() -> void:
	_bounce_spell = _spell(&"gresille_arc_rebond", "Rebond", 1, BOUNCE_COEF, ARC_CD)
	_bounce_spell.is_auto = true
	_bounce_spell.proc_coef = BOUNCE_PROC
	_discharge_arc_spell = _spell(&"gresille_decharge_arc", "Arc de décharge", 2, DISCHARGE_ARC_COEF, 0.0)
	_discharge_arc_spell.proc_coef = DISCHARGE_ARC_PROC


## Sort de base du slot (celui du joueur : variantes comprises), sinon le sort de base de la fiche.
func character_spell(slot: int) -> SpellData:
	var sp := _spell_of(slot)
	return sp if sp != null else character().spells[slot - 1]


func _spell_of(slot: int) -> SpellData:
	var c := _caster()
	if c == null or c.character == null:
		return null
	for s: SpellData in c.character.spells:
		if s.slot == slot:
			return s
	return null


# --- Mise en place --------------------------------------------------------------------------------------

func setup(p: CharacterBody2D) -> void:
	player = p
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	_make_internal()
	Events.floor_started.connect(_on_floor_started)
	Events.enemy_killed_by.connect(_on_enemy_killed_by)
	if p.has_signal(&"action_impact"):
		p.action_impact.connect(_on_action_impact)
	_update_emission()


func _exit_tree() -> void:
	if Events.floor_started.is_connected(_on_floor_started):
		Events.floor_started.disconnect(_on_floor_started)
	if Events.enemy_killed_by.is_connected(_on_enemy_killed_by):
		Events.enemy_killed_by.disconnect(_on_enemy_killed_by)
	clear_transients()


func _caster() -> SpellCaster:
	return player.spells if player != null else null


func _on_floor_started(_n: int) -> void:
	clear_transients()


func _on_enemy_killed_by(_id: int, e: Node2D, _pos: Vector2, _tier: int, _elite: bool) -> void:
	reg.forget(e) # le pool réutilise l'identifiant : aucun cumul ne survit à la mort


func clear_transients() -> void:
	reg.clear()
	_pending.clear()
	storm_left = 0.0
	_storm_pending = false
	if field != null and is_instance_valid(field):
		field.queue_free()
	field = null
	if _label != null and is_instance_valid(_label):
		_label.queue_free()
	_label = null
	_label_target = null
	_trail.clear()
	_wake_victims.clear()
	_end_wake_line(true)


# --- Statique (lecture) ---------------------------------------------------------------------------------

func stacks_of(e: Node) -> int:
	return reg.stacks(e, _clock)


## Horloge du kit (s) : avance dans tick().
func clock() -> float:
	return _clock


## Trempé : lecture du statut partagé Enemy.is_wet() (trempe d'Averse, case d'eau, Flaque-miroir).
static func is_wet(e: Node) -> bool:
	return e != null and is_instance_valid(e) and e.has_method(&"is_wet") and bool(e.is_wet())


## Contrat « la plus chargée » (SpellData.target_mode = &"most_stacked") : le monstre le plus chargé à <= range_px,
## sinon le plus proche, sinon null.
func pick_target(range_px: float) -> Node2D:
	var t := reg.most_stacked(player.global_position, range_px, _clock)
	return t if t != null else _caster().nearest_enemy(range_px)


# --- Hooks du joueur et de SpellCaster -------------------------------------------------------------------

## Sort 1 suspendu pendant l'Orage (tige levée, y compris pendant la montée) ; l'Orage ne se relance pas dans sa propre anim.
func blocks_slot(slot: int) -> bool:
	if slot == 1:
		return storm_left > 0.0 or _storm_pending
	if slot == 4:
		return storm_left > 0.0 or _storm_pending
	return false


func can_dodge() -> bool:
	return true


func speed_mult() -> float:
	return STORM_SPEED_U / SPEED_U if storm_left > 0.0 else 1.0


func inertia_s() -> float:
	return 0.0


func slow_immune() -> bool:
	return false


func locks_facing() -> bool:
	return false


func on_cast(_s: SpellData) -> void:
	pass


func dodge_ghosts() -> bool:
	return true


func dodge_ghost_color() -> Color:
	return Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)


func action_for(s: SpellData) -> StringName:
	match s.slot:
		1: return &"attack"
		2: return &"cast"
		3: return &"ground"
		4: return &"call"
	return &""


## Isolée : bottes de gutta-percha, cape-treillis. Une flaque de mini-boss fraîchement électrisée sous ses pieds ne fait
## que ISOLEE_MULT du coup (la foudre des boss, elle, la touche normalement).
func damage_taken_mult(source: Node) -> float:
	if source != null and is_instance_valid(source) and source.get(&"brain") != null and _in_electrified_water(source.get(&"brain")):
		return ISOLEE_MULT
	return 1.0


func _in_electrified_water(brain: Object) -> bool:
	var zones: Variant = brain.get(&"_zones")
	if not (zones is Array):
		return false
	for z in (zones as Array):
		if z is Dictionary and bool(z.get("conduct", false)) and float(z.get("shock", 0.0)) > 0.0 \
				and MiniPatterns.zone_contains(z, player.global_position):
			return true
	return false


## Auto-cast (accessibilité, simulateur) : Décharge sur une cible chargée (>= 3), Mise à la terre au contact d'un paquet,
## Orage face à un paquet dense (>= 4 monstres à 6 u) ou une cible chargée.
func auto_cast_ok(slot: int) -> bool:
	match slot:
		2:
			return reg.most_stacked(player.global_position, DISCHARGE_RANGE_U * Balance.UNIT_PX, _clock, 3) != null
		3:
			return _count_near(player.global_position, GROUND_RADIUS_U * Balance.UNIT_PX) >= 3
		4:
			if reg.most_stacked(player.global_position, STORM_RANGE_U * Balance.UNIT_PX, _clock, 3) != null:
				return true
			return _count_near(player.global_position, 6.0 * Balance.UNIT_PX) >= 4
	return true


func _count_near(at: Vector2, r: float) -> int:
	var n := 0
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and (e as Node2D).global_position.distance_to(at) <= r:
			n += 1
	return n


## Fenêtre de combo (HUD) : le bouton 2 pulse dès qu'une cible a >= COMBO_READY_STACKS cumuls à portée de la Décharge ;
## le bouton 4 quand une cible est à 5 cumuls à portée de l'Orage. Sondé toutes les POLL_S.
func combo_ready(slot: int) -> bool:
	return bool(_ready_flags.get(slot, false))


func _probe_ready() -> void:
	var here := player.global_position
	_ready_flags[2] = reg.most_stacked(here, DISCHARGE_RANGE_U * Balance.UNIT_PX, _clock, COMBO_READY_STACKS) != null
	_ready_flags[4] = reg.most_stacked(here, STORM_RANGE_U * Balance.UNIT_PX, _clock, GresilleStatic.ZAP_AT) != null


# --- Lancement ---------------------------------------------------------------------------------------------

func cast_spell(s: SpellData, aim: Variant) -> bool:
	if player == null or player.dead or blocks_slot(s.slot):
		return false
	var c := _caster()
	match s.slot:
		1:
			var target := c.nearest_enemy(c.range_px(s))
			if target == null:
				return false # l'auto ne consomme rien sans cible
			_face(target.global_position)
			_queue(&"attack", func() -> void: _arc(s, target))
		2:
			var tgt := _pick_discharge_target(s, aim)
			if tgt == null:
				return false
			_face(tgt.global_position)
			_queue(&"cast", func() -> void: _discharge(s, tgt))
		3:
			_queue(&"ground", func() -> void: _ground(s))
		4:
			_storm_pending = true
			_queue(&"call", func() -> void: _storm_begin(s))
		_:
			return false
	return true


## PC : le plus chargé à <= DISCHARGE_AIM_U du curseur (sinon le plus proche du curseur) ; mobile / manette au repos :
## le plus chargé à portée (pick_target), sinon le plus proche.
func _pick_discharge_target(s: SpellData, aim: Variant) -> Node2D:
	var c := _caster()
	var reach := c.range_px(s)
	if aim == null:
		return pick_target(reach)
	var p := aim as Vector2
	var here := player.global_position
	var best: Node2D = null
	var best_key := -1.0
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		var pos := (e as Node2D).global_position
		if pos.distance_to(here) > reach or pos.distance_to(p) > DISCHARGE_AIM_U * Balance.UNIT_PX:
			continue
		var key := float(reg.stacks(e, _clock)) * 1000.0 - pos.distance_to(p)
		if key > best_key:
			best_key = key
			best = e
	return best if best != null else pick_target(reach)


func _face(at: Vector2) -> void:
	var d := at - player.global_position
	if d.length_squared() > 1.0:
		player.facing = d.normalized()


func _queue(base: StringName, fn: Callable) -> void:
	_pending.append({"base": base, "fn": fn, "t": 0.0})


func _on_action_impact(base: StringName) -> void:
	if _pending.is_empty():
		return
	var keep: Array = []
	var fire: Array = []
	for p in _pending:
		(fire if p["base"] == base else keep).append(p)
	_pending = keep
	for p in fire:
		if player != null and not player.dead:
			(p["fn"] as Callable).call()


func has_pending() -> bool:
	return not _pending.is_empty()


## Déclenche tout de suite les effets en attente de la frame d'impact (tests).
func flush_pending() -> void:
	var all := _pending
	_pending = []
	for p in all:
		(p["fn"] as Callable).call()


# --- Statique : application d'un coup (hook SpellCaster.deal_damage) ----------------------------------------

## SpellCaster.deal_damage : tout coup de Grésille (Arc, rebond, arcs de Décharge, ticks de Mise à la terre, coups
## d'Orage) dépose de la Statique ; sur un monstre à 5 cumuls il foudroie à la place. La Décharge elle-même est gérée
## dans _discharge (elle consomme les cumuls).
func on_spell_hit(s: SpellData, enemy: Node, _amount: float) -> void:
	if not is_instance_valid(enemy):
		return
	match s.id:
		&"gresille_arc", &"gresille_arc_rebond", &"gresille_decharge_arc", &"gresille_terre", &"gresille_orage":
			apply_static(enemy, true)
	if s.id == &"gresille_terre" and enemy.has_method(&"apply_status"):
		enemy.apply_status(&"slow", {"pct": GresilleStatic.CRISP_SLOW, "duration": GROUND_SLOW_S})


## Dépose la Statique d'un coup : Foudroiement si 5 cumuls et hors immunité, sinon +1 (+2 sur un mouillé). `can_zap` faux
## = sillage du Court-circuit (jamais de foudroiement). Retourne vrai si foudroyé.
func apply_static(e: Node, can_zap := true) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	if can_zap and reg.can_zap(e, _clock):
		reg.zap(e, _clock)
		_zap_fx(e)
		return true
	var n := GresilleStatic.WET_STACKS if is_wet(e) else 1
	var got := reg.add(e, n, _clock)
	if got >= GresilleStatic.CRISP_AT:
		_crisp(e)
	StatusFx.shock(e, 0.3) # petits arcs sur le corps (visuel seul)
	return false


func _crisp(e: Node) -> void:
	if e.has_method(&"apply_status"):
		e.apply_status(&"slow", {"pct": GresilleStatic.CRISP_SLOW, "duration": CRISP_REFRESH_S})


func _zap_fx(e: Node) -> void:
	if not (e is Node2D):
		return
	var pos := (e as Node2D).global_position
	if not _play_fx("zap_flash", pos, 4.0):
		StatusFx.shock(e, 0.5)
	Audio.play(SOUND_ZAP, pos, 0.0, 0.85) # PLACEHOLDER : `gresille.zap` (claquement blanc) à produire
	if Quality.flashes_level > 0:
		LightRig.flash(pos, &"spell_lightning", FLASH_S)


# --- Effets -------------------------------------------------------------------------------------------------

## Arc : hitscan sur `target`, puis rebond sur le voisin le plus proche (portée +2 u si l'un des deux est mouillé).
func _arc(s: SpellData, target: Node2D) -> void:
	var c := _caster()
	if not is_instance_valid(target) or not target.is_inside_tree():
		target = c.nearest_enemy(c.range_px(s))
		if target == null:
			return
	var pts: Array = [player.global_position, target.global_position]
	var hit_ids := {target.get_instance_id(): true}
	c.deal_damage(target, s)
	var bounces := 1 + int(player.stat(&"pierce")) # Pointe perforante : un rebond de plus
	var from: Node2D = target
	for _i in bounces:
		var nb := _nearest_neighbor(from, BOUNCE_U, hit_ids, true)
		if nb == null:
			break
		hit_ids[nb.get_instance_id()] = true
		pts.append(nb.global_position)
		c.deal_damage(nb, _bounce_spell)
		from = nb
	_arc_fx(pts)


## Voisin le plus proche de `from` à <= (base_u + WET_BONUS_U si `from` ou lui est mouillé) u, hors `exclude`.
func _nearest_neighbor(from: Node2D, base_u: float, exclude: Dictionary, wet_bonus: bool) -> Node2D:
	var from_wet := wet_bonus and is_wet(from)
	var best: Node2D = null
	var best_d := INF
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or exclude.has(e.get_instance_id()) or not e.has_method(&"take_damage"):
			continue
		var d := (e as Node2D).global_position.distance_to(from.global_position)
		if d >= best_d:
			continue
		var reach := (base_u + (WET_BONUS_U if (from_wet or (wet_bonus and is_wet(e))) else 0.0)) * Balance.UNIT_PX
		if d <= reach:
			best_d = d
			best = e
	return best


func _arc_fx(pts: Array) -> void:
	ChainLightningFx.chain(pts, player.get_parent(), true) # arc_tile lilas (repli : arcs neutres si la planche manque)


## Décharge : n = cumuls de la cible (consommés ; 5 = foudroyée), coef 2,8 + 0,15 n, puis n arcs de 0,6 vers n voisins
## distincts à <= 3 u (<= 5 u si l'un des deux est mouillé), +1 Statique chacun. La cible repart avec 1 cumul.
func _discharge(s: SpellData, target: Node2D) -> void:
	var c := _caster()
	if not is_instance_valid(target) or not target.is_inside_tree():
		target = pick_target(c.range_px(s))
		if target == null:
			return
	var n := reg.stacks(target, _clock)
	var shot := s.duplicate() as SpellData
	shot.coef = discharge_coef(n, s.coef)
	c.deal_damage(target, shot)
	if reg.can_zap(target, _clock):
		reg.zap(target, _clock)
		_zap_fx(target)
	else:
		reg.consume(target, _clock)
	if is_instance_valid(target):
		apply_static_plain(target) # « la cible repart avec 1 cumul » (2 si mouillée)
	var pts: Array = [player.global_position, target.global_position]
	var used := {target.get_instance_id(): true}
	var left := n
	var from_pos := target
	while left > 0:
		var nb := _nearest_neighbor(from_pos, DISCHARGE_ARC_U, used, true)
		if nb == null:
			break # moins de voisins que de cumuls : les arcs en trop sont perdus
		used[nb.get_instance_id()] = true
		pts.append(nb.global_position)
		c.deal_damage(nb, _discharge_arc_spell)
		left -= 1
	_arc_fx(pts)
	_play_fx("discharge_burst", target.global_position, 0.0)
	Audio.play(SOUND_CHAIN, target.global_position) # PLACEHOLDER : `spell.gresille_decharge.*` à produire


static func discharge_coef(n: int, base := DISCHARGE_COEF) -> float:
	return base + DISCHARGE_PER_STACK * float(clampi(n, 0, GresilleStatic.STATIC_MAX))


## Statique sans foudroiement (sillage, repart-à-1 de la Décharge).
func apply_static_plain(e: Node) -> void:
	apply_static(e, false)


## Mise à la terre : tige plantée à ses pieds. Sur l'eau : nappe connexe (<= 113 cases) ; sinon disque de 3 u.
## Une seule à la fois (relancer déplace la zone).
func _ground(s: SpellData) -> void:
	if field != null and is_instance_valid(field):
		field.queue_free()
	field = null
	var c := _caster()
	var here := player.global_position
	var zsa: float = maxf(1.0 + player.stat(&"zone_size_add"), 0.1)
	var cap := roundi(float(GROUND_WATER_CELLS_MAX) * zsa * zsa)
	var patch: Array[Vector2] = []
	if StageMap.is_water_at(player.get_tree(), here):
		patch = StageMap.water_patch_at(player.get_tree(), here, cap)
	if patch.size() >= 1:
		var f := GresilleGroundField.new()
		c.effects_parent().add_child(f)
		f.setup(c, s, patch, s.duration, s.tick)
		field = f
		PlayerRef.state_of(player).add_counter(COUNTER_GROUNDED_WET, 1.0)
	else:
		field = c.spawn_zone(s, here)
	Audio.play(SOUND_ZAP, here, -3.0, 0.7) # PLACEHOLDER : `spell.gresille_ground.loop` à produire


## Orage, frame d'impact de `call` : la canalisation commence, premier coup tout de suite.
func _storm_begin(s: SpellData) -> void:
	_storm_pending = false
	storm_left = float(STORM_STRIKES) * STORM_INTERVAL_S
	storm_strikes_done = 0
	_storm_t = 0.0
	_storm_strike(s)


func _storm_strike(s: SpellData) -> void:
	storm_strikes_done += 1
	var c := _caster()
	var reach := STORM_RANGE_U * Balance.UNIT_PX
	var tgt := reg.most_stacked(player.global_position, reach, _clock)
	if tgt == null:
		tgt = c.nearest_enemy(reach)
	var at: Vector2
	if tgt != null:
		at = tgt.global_position
	else: # aucun monstre : le coup tombe à 1,5 u devant elle et ne fait rien
		var f: Vector2 = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
		at = player.global_position + f.normalized() * STORM_RADIUS_U * Balance.UNIT_PX
	var n := reg.stacks(tgt, _clock) if tgt != null else 0
	var shot := s.duplicate() as SpellData
	shot.coef = storm_coef(n, s.coef)
	var r: float = STORM_RADIUS_U * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
	var victims: Array = []
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and e.has_method(&"take_damage") and (e as Node2D).global_position.distance_to(at) <= r:
			victims.append(e)
	for e in victims:
		if is_instance_valid(e):
			c.deal_damage(e, shot)
	# `bolt_strike` (GR2) ; repli si la planche manque : arc ChainLightningFx du ciel au point d'impact
	if not _play_fx("bolt_strike", at, 0.0):
		ChainLightningFx.chain([at + Vector2(0.0, -STORM_SKY_PX), at], player.get_parent(), true)
	Audio.play(SOUND_CHAIN, at, 0.0, 0.8) # PLACEHOLDER : `spell.gresille_storm.*` (tonnerre sec) à produire
	if Quality.flashes_level > 0:
		LightRig.flash(at, &"spell_lightning", 0.15 if Quality.flashes_level == 2 else FLASH_S)


## Joue une fois l'animation `default` de vfx/gresille/<name>/<name>.tres, ancrée au sol en `at` (espace billboard,
## bas de la cellule au point). Faux si la ressource manque.
func _play_fx(fx_name: String, at: Vector2, lift_px: float) -> bool:
	var path := VFX_DIR + fx_name + "/" + fx_name + ".tres"
	if player == null or player.get_parent() == null or not ResourceLoader.exists(path):
		return false
	var frames := load(path) as SpriteFrames
	if frames == null:
		return false
	var root := Node2D.new()
	root.top_level = true
	root.scale = Iso.UNSQUASH
	root.position = at
	root.z_index = 31
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = frames
	var tex := frames.get_frame_texture(&"default", 0)
	sp.position = Vector2(0.0, -(tex.get_height() * 0.5) + lift_px)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sp.material = add
	sp.animation_finished.connect(root.queue_free)
	root.add_child(sp)
	player.get_parent().add_child(root)
	sp.play(&"default")
	return true


static func storm_coef(n: int, base := STORM_COEF) -> float:
	return base + STORM_PER_STACK * float(clampi(n, 0, GresilleStatic.STATIC_MAX))


func is_channeling() -> bool:
	return storm_left > 0.0


## L'esquive interrompt l'Orage (les coups restants sont perdus).
func on_dodge_start(_dir: Vector2) -> void:
	storm_left = 0.0
	_storm_pending = false
	_trail.clear()
	_wake_victims.clear()
	_start_wake_line()


# --- Boucle ---------------------------------------------------------------------------------------------------

func tick(delta: float) -> void:
	if player == null or player.dead:
		return
	_clock += delta
	if storm_left > 0.0:
		storm_left = maxf(storm_left - delta, 0.0)
		_storm_t += delta
		while _storm_t >= STORM_INTERVAL_S and storm_strikes_done < STORM_STRIKES:
			_storm_t -= STORM_INTERVAL_S
			_storm_strike(character_spell(4))
		_loop_call_anim()
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = POLL_S
		_probe_ready()
		_update_label()
	_crisp_t -= delta
	if _crisp_t <= 0.0:
		_crisp_t = CRISP_POLL_S
		_refresh_crisp()
	_tick_wake(delta)
	_update_emission()
	# filet de sécurité : un effet jamais déclenché (anim interrompue sans impact) part après 1 s
	for p in _pending.duplicate():
		p["t"] = float(p["t"]) + delta
		if float(p["t"]) > 1.0:
			_pending.erase(p)
			(p["fn"] as Callable).call()


## Crispés (>= 3 cumuls) : ralentissement rafraîchi, arcs sur le corps tant que les cumuls tiennent.
func _refresh_crisp() -> void:
	for e: Node2D in reg.live(_clock):
		if reg.stacks(e, _clock) >= GresilleStatic.CRISP_AT:
			_crisp(e)
			StatusFx.shock(e, CRISP_POLL_S + 0.1)


# --- Sillage du Court-circuit (esquive) ---------------------------------------------------------------------------

func _tick_wake(delta: float) -> void:
	var dodging: bool = player.is_dodging()
	if dodging:
		_trail.append({"p": player.global_position, "t": 0.0})
		if _wake_line != null and is_instance_valid(_wake_line):
			_wake_line.add_point(player.global_position)
	for pt in _trail:
		pt["t"] = float(pt["t"]) + delta
	while not _trail.is_empty() and float(_trail[0]["t"]) > WAKE_S:
		_trail.pop_front()
	if _trail.is_empty():
		if not dodging:
			_end_wake_line(false)
		return
	var r2 := pow(WAKE_RADIUS_U * Balance.UNIT_PX, 2.0)
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or _wake_victims.has(e.get_instance_id()) or not e.has_method(&"take_damage"):
			continue
		var ep := (e as Node2D).global_position
		for pt in _trail:
			if (pt["p"] as Vector2).distance_squared_to(ep) <= r2:
				_wake_victims[e.get_instance_id()] = true
				apply_static(e, false) # le sillage prépare, il ne foudroie jamais
				break


## Sillage : Line2D additive texturée par `arc_tile` (GR2), repli lilas uni ; s'efface.
func _start_wake_line() -> void:
	_end_wake_line(true)
	if player == null or player.get_parent() == null:
		return
	var l := Line2D.new()
	l.width = WAKE_WIDTH_U * Balance.UNIT_PX
	l.default_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)
	l.z_index = -1
	var tp := VFX_DIR + "arc_tile/arc_tile.png"
	if ResourceLoader.exists(tp):
		var at := AtlasTexture.new()
		at.atlas = load(tp) as Texture2D
		at.region = Rect2(0.0, 0.0, 256.0, 48.0) # variante 0, frame 0 de la grille 4x4
		l.texture = at
		l.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		l.default_color = Color(1.0, 1.0, 1.0, 0.8)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l.material = m
	player.get_parent().add_child(l)
	l.global_position = Vector2.ZERO
	l.add_point(player.global_position)
	_wake_line = l


func _end_wake_line(now: bool) -> void:
	if _wake_line == null or not is_instance_valid(_wake_line):
		_wake_line = null
		return
	var l := _wake_line
	_wake_line = null
	if now or not l.is_inside_tree():
		l.queue_free()
		return
	var tw := l.create_tween()
	tw.tween_property(l, ^"modulate:a", 0.0, WAKE_FADE_S)
	tw.tween_callback(l.queue_free)


# --- Lisibilité -------------------------------------------------------------------------------------------------

## Chiffre de cumuls sur la cible visée seulement (sinon 250 chiffres) : le monstre le plus chargé à portée de la Décharge.
## PLACEHOLDER : chiffre texte lilas, en attendant une police / un visuel dédié.
func _update_label() -> void:
	var t := reg.most_stacked(player.global_position, DISCHARGE_RANGE_U * Balance.UNIT_PX, _clock)
	if t == null:
		if _label != null and is_instance_valid(_label):
			_label.visible = false
		return
	if _label == null or not is_instance_valid(_label):
		var l := Label.new()
		l.top_level = true
		l.scale = Iso.UNSQUASH
		l.z_index = 40
		l.add_theme_color_override(&"font_color", LABEL_COLOR)
		l.add_theme_color_override(&"font_outline_color", Color(0.1, 0.08, 0.16))
		l.add_theme_constant_override(&"outline_size", 6)
		l.add_theme_font_size_override(&"font_size", 28)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		player.get_parent().add_child(l)
		_label = l
	_label.visible = true
	_label_target = t
	_label.text = str(reg.stacks(t, _clock))
	var r: float = float(t.get(&"radius_px")) if &"radius_px" in t else 20.0
	_label.global_position = t.global_position + Vector2(-8.0, -r * 2.0 * 2.0 - 36.0)


## Masque `_e` des bouteilles : énergie 0,6 -> 3,0 selon la recharge de la Décharge (10 paliers, comme l'amphore d'Averse).
func _update_emission() -> void:
	if _visual == null or player == null or player.spells == null:
		return
	var total: float = player.spells.cooldown_total(2)
	var ratio := 1.0 if total <= 0.0 else clampf(1.0 - player.spells.cooldown_remaining(2) / total, 0.0, 1.0)
	var step := roundi(ratio * EMISSION_STEPS)
	if step == _emission_step:
		return
	_emission_step = step
	NormalMaps.set_emission_energy(_visual, lerpf(EMISSION_LOW, EMISSION_FULL, float(step) / EMISSION_STEPS))


## Énergie courante du palier (tests).
func emission_step() -> int:
	return _emission_step


func _dir_of(v: Vector2) -> String:
	if v == Vector2.ZERO:
		v = Vector2.DOWN
	var i := roundi(v.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES[(i + 8) % 8]


## Canalisation de l'Orage : hors anim d'action, elle tient la tige levée (`call`, boucle).
func visual_anim(fallback: StringName) -> StringName:
	if storm_left > 0.0 and player.action_base() == &"" and _visual != null and _visual.sprite_frames != null:
		var a := StringName("call_" + _dir_of(player.facing))
		if _visual.sprite_frames.has_animation(a):
			return a
	return fallback


## `call` boucle de la frame CALL_LOOP_FROM à la fin (la montée n'est jouée qu'une fois) : au retour à la frame 0,
## on saute à la frame de reprise.
func _loop_call_anim() -> void:
	if _visual == null or not String(_visual.animation).begins_with("call_"):
		_last_call_frame = -1
		return
	var f := _visual.frame
	if f < _last_call_frame and f < CALL_LOOP_FROM:
		_visual.set_frame_and_progress(CALL_LOOP_FROM, 0.0)
		f = CALL_LOOP_FROM
	_last_call_frame = f


# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) --------------------------------------------------

static func passive_info() -> Dictionary:
	var f := KitResource.fmt
	return KitResource.passive("Statique", &"statique",
		"Chaque coup de Grésille charge le monstre touché : jusqu'à %s cumuls pendant %s s. L'état est sur les monstres, pas sur elle." % [
			f.call(GresilleStatic.STATIC_MAX), f.call(GresilleStatic.STATIC_S)],
		"un coup (Arc, rebond, Décharge, Mise à la terre, Orage) : +1 cumul, +%s sur un monstre mouillé ; le sillage de l'esquive : +1." % f.call(GresilleStatic.WET_STACKS),
		"la Décharge consomme les cumuls de sa cible et les libère en arcs vers les voisins.",
		"à %s cumuls le monstre est crispé (ralenti %s %%) ; à %s, le prochain coup le foudroie (étourdi %s s ; un boss subit +%s %% de dégâts %s s). Les monstres mouillés conduisent : arcs +%s u." % [
			f.call(GresilleStatic.CRISP_AT), f.call(GresilleStatic.CRISP_SLOW * 100.0), f.call(GresilleStatic.ZAP_AT),
			f.call(GresilleStatic.ZAP_STUN_S), f.call((GresilleStatic.ZAP_BOSS_MULT - 1.0) * 100.0), f.call(GresilleStatic.ZAP_BOSS_MOD_S), f.call(WET_BONUS_U)])
