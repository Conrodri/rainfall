class_name TocsinKit
extends Node
## Kit de Tocsin, l'automate de crue (docs/Design_Personnages.md §1) : 4 sorts / 0 passif. Le corps est
## l'arsenal : chaque membre lancé n'est plus sur le robot tant que sa recharge court, et son absence change
## la locomotion (§1.4). Données : character(). Logique : ce nœud, enfant « Kit » du joueur, interrogé par les
## hooks du joueur et de SpellCaster (blocks_slot, cast_spell, speed_mult, dodge_distance_u, visual_anim…).
## - Sort 1 Rivets rougis : projectile auto (SpellCaster) ; Surchauffe +12 % de vitesse d'attaque par membre
##   absent (foyer plus vif) ; sans tête, ciblage 8 -> 5 u.
## - Sort 2 Bras-grappins (2 charges) / Sort 3 Coups de botte (2 charges, bloqué sans bras) / Sort 4 Tête-cloche :
##   SpellData KIT, membres TocsinLimb lancés à la frame d'impact de throw_<membre>.
## Charges séquentielles (S1) tenues ici : un membre présent = une charge ; un seul membre se recharge à la fois
## par sort ; la recharge du SpellCaster est recalée à chaque frame (0 s'il reste une charge, sinon le temps
## avant le prochain membre) : HUD et sauvegarde inchangés.
## Rendu : TocsinLayers (7 calques du lot T5) ; sans calques : composite tocsin.tres ; sans rien : Ardent teinté.

# --- Assets (lots Codex T1-T5) : game/assets/sprites/characters/tocsin/ ----------------------------
const ASSET_DIR := "res://assets/sprites/characters/tocsin/"
const COMPOSITE_FRAMES := ASSET_DIR + "tocsin.tres" ## repli un seul sprite (tous membres)
const REGEN_FRAMES := ASSET_DIR + "regen_rivets.tres" ## anim `regen_rivets`, 1 direction, centrée sur le socle
const BLAST_FRAMES := ASSET_DIR + "tocsin_blast.tres" ## anims `head_blast` (CREA) et `head_blast_top` (TOP)
const BLAST_TOP_RING_PX := 512.0 ## rayon de l'anneau final de `head_blast_top` (lot T6 : 4 u = 512 px au rig TOP, cellule 1032)
const HEAD_RING_FRAMES := ASSET_DIR + "head_ring/head_ring.tres" ## T6 : télégraphe au sol de la tête (anim `default`, TOP)
const HEAD_RING_PX := 512.0 ## rayon de l'anneau de `head_ring` dans sa cellule 1032 (4 u à 128 px/u)
const SOCKETS_JSON := ASSET_DIR + "sockets.json" ## T6 : attaches des membres par anim idle/run, direction et frame
const BLAST_CREA_K := 2.2 ## gerbe volumique CREA : échelle sur le rig du personnage (lisible sans écraser le sol)
## Rivet (sort 1) : `rivet/rivet.tres` (lot T6, anim `default`, pointe vers +X) ; s'il manque, repli sur
## l'éclat de braise de la scène, teinté laiton par la lumière `tocsin_rivet`.
const RIVET_FRAMES := ASSET_DIR + "rivet/rivet.tres"
const PLACEHOLDER_TINT := Color(0.55, 0.68, 0.62) ## Ardent teinté bronze vert-de-gris, si aucun asset
const ACCENT := Color("#FF7A1F") ## foyer : accent émissif unique

# --- Statistiques (§1.8) ----------------------------------------------------------------------------
const BASE_HP := 130.0
const HP_PER_LEVEL := 36.0
const ARMOR := 20.0
const BASE_REGEN := 0.8
const REGEN_PER_LEVEL := 0.16
const BASE_SPEED_U := 4.0
const HITBOX_U := 0.5
const HITBOX_GROUND_U := 0.45 ## rampe / tonneau

# --- Sort 1 : Rivets rougis ---------------------------------------------------------------------------
const RIVET_COEF := 0.8
const RIVET_INTERVAL_S := 0.6
const RIVET_RANGE_U := 8.0
const RIVET_RANGE_HEADLESS_U := 5.0
const RIVET_SPEED_U := 12.0
const RIVET_PIERCE := 1 ## équilibrage 22/10 : 0 -> 1 (comme l'Éclat d'Ardent ; essaim −40 % à l'origine)
const OVERHEAT_PER_LIMB := 0.12 ## Surchauffe : vitesse d'attaque par membre absent (s'additionne aux items)
const FURNACE_ENERGY := 2.0 ## émission du foyer, tous membres présents
const FURNACE_PER_LIMB := 0.2 ## +20 % par membre absent (1,0 -> 2,0 à 5 membres)
const FURNACE_KICK := 0.6 ## bouffée à chaque rivet
const FURNACE_KICK_S := 0.12

# --- Sort 2 : Bras-grappins -------------------------------------------------------------------------
const ARM_COEF := 1.8 ## équilibrage 22/10 : 1,5 -> 1,8
const ARM_CD_S := 8.0
const ARM_RANGE_U := 7.0
const ARM_RANGE_HEADLESS_U := 4.0
const ARM_WIDTH_U := 1.2
const ARM_SPEED_U := 16.0
const ARM_PROC := 0.7
const ARM_CAPACITY := 6 ## points par bras (T1 1, T2 1, élite 2, T3 3)
const ARM_DROP_U := 2.0
const ARM_LATERAL_U := 0.8 ## deux paquets côte à côte
const ARM_BACK_MAX_S := 1.2 ## sécurité : le bras finit toujours par se planter
const ARM_RELEASE_SLOW_PCT := 0.4
const ARM_RELEASE_SLOW_S := 2.0
const ARM_BOSS_SLOW_PCT := 0.2
const ARM_BOSS_SLOW_S := 1.0
const PACK_RADIUS_U := 1.0
const CLAMP_S := 2.5

# --- Sort 3 : Coups de botte --------------------------------------------------------------------------
const LEG_COEF := 3.0
const LEG_CD_S := 9.0
const LEG_RANGE_U := 5.0
const LEG_RANGE_HEADLESS_U := 4.0
const LEG_WIDTH_U := 1.5
const LEG_TRAVEL_S := 0.4
const LEG_PUSH_U := 4.0 ## × masse (T1 4 u, T2 2,8 u, T3 1,6 u)
const LEG_PRISONER_PUSH_MULT := 1.5
const QUILLE_TRANSFER := 0.5
const QUILLE_COEF := 1.0
const QUILLE_PROC := 0.5

# --- Sort 4 : Tête-cloche -----------------------------------------------------------------------------
const HEAD_COEF := 10.0 ## équilibrage 23/10 : 12 -> 10 (22/10 : 10 -> 12)
const PICKUP_CD_REFUND := 0.5 ## équilibrage 23/10 : ramasser un membre ne rend que 50 % de la recharge restante (avant : charge pleine)
const HEAD_CD_S := 22.0
const HEAD_RANGE_U := 6.0
const HEAD_RADIUS_U := 4.0
const HEAD_FLIGHT_S := 0.9
const HEAD_RING_S := 0.3
const HEAD_LOB_HEIGHT_U := 2.2
const HEAD_PRISONER_BONUS := 0.5 ## +50 % sur les emprisonnés / accrochés
const HEAD_PUSH_EXTRA_U := 1.4 ## + le recul du coup (0,6 u) = 2 u × masse
const HEAD_SHAKE_PX := 10.0
const HEAD_BOSS_ADD := 0.3 ## équilibrage 22/10 : la cloche sonne plus fort sur les boss (+30 % additif)

# --- Variantes de sorts (docs/Variantes_Sorts.md §2.3 : « le bélier à vapeur ») ----------------------------
const V_VAPEUR := &"tocsin_vapeur" ## slot 1 (remplace Rivets rougis)
const V_HARPON := &"tocsin_bras_harpon" ## slot 2 (remplace Bras-grappins)
const V_RESSORTS := &"tocsin_jambes_ressorts" ## slot 3 (remplace Coups de botte)
const V_FUMIGENE := &"tocsin_tete_fumigene" ## slot 4 (remplace Tête-cloche)
const COUNTER_IMPRISONED := "tocsin.imprisoned" ## monstres emprisonnés par les Bras-grappins (+1 par monstre)
const COUNTER_PUSHED := "tocsin.pushed" ## monstres poussés par les Coups de botte (+1 par monstre et par botte, quilles comprises)
const COUNTER_HEADLESS_BOSS := "tocsin.headless_boss_kills" ## boss d'étage tué tête en recharge
## Vapeur : cône 60° à 3 u, anneau 360° de 2 u sans tête. Coef réglé par balance_sim (±15 % des Rivets).
const VAPEUR_COEF := 0.55
const VAPEUR_RANGE_U := 3.0
const VAPEUR_RING_U := 2.0
const VAPEUR_CONE_DEG := 60.0
const VAPEUR_RANGE_ADD_K := 0.5 ## la portée d'items compte pour moitié
const VAPEUR_PROC := 0.6
const VAPEUR_KNOCK_U := 0.2
const VAPEUR_SLOW_PCT := 0.2
const VAPEUR_SLOW_S := 0.6
## Bras-harpon : tir droit, premier monstre touché, traction du joueur.
const HARPON_COEF := 1.8
const HARPON_RANGE_U := 8.0
const HARPON_RANGE_HEADLESS_U := 5.0
const HARPON_SPEED_U := 20.0
const HARPON_WIDTH_U := 1.0
const HARPON_PROC := 0.7
const HARPON_PULL_SPEED_U := 16.0
const HARPON_PULL_MAX_S := 0.5
const HARPON_STOP_U := 1.0 ## Tocsin s'arrête à 1 u de la cible (+ son rayon)
const HARPON_WAVE_U := 1.5
const HARPON_WAVE_PUSH_U := 1.0 ## × masse, sans dégâts
const HARPON_PLANT_S := 2.5
const HARPON_PLANT_SLOW_PCT := 0.4
## Jambes-ressorts : saut LOB, atterrissage en disque.
const RESSORTS_COEF := 3.0
const RESSORTS_RANGE_U := 5.0
const RESSORTS_RANGE_HEADLESS_U := 4.0
const RESSORTS_FLIGHT_S := 0.5
const RESSORTS_HEIGHT_U := 1.5
const RESSORTS_RADIUS_U := 2.0
const RESSORTS_PUSH_U := 2.0 ## × masse (×1,5 et libération sur les emprisonnés)
const RESSORTS_PROC := 1.0
const RESSORTS_SHAKE_PX := 8.0
## Tête-fumigène : lob 6 u (comme la Tête-cloche), tintement, puis zone de fumée 5 s (10 ticks de 0,5 s).
const FUMI_COEF := 1.25 ## par tick
const FUMI_RADIUS_U := 4.0
const FUMI_S := 5.0
const FUMI_TICK_S := 0.5
const FUMI_STUN_S := 1.0
const FUMI_SLOW_PCT := 0.5
const FUMI_BOSS_SLOW_PCT := 0.4
const FUMI_PROC := 0.3
const FUMI_PRISONER_BONUS := 0.5

# --- Membres au sol, roulade, états (§1.4, §1.5) -----------------------------------------------------
const PICKUP_CONTACT_U := 0.6
const PICKUP_DELAY_S := 0.8
const DODGE_U := 3.0
const DODGE_HOP_U := 1.5
const DODGE_ROLL_U := 2.0
const FALL_S := 0.2
const GHOST_EVERY_S := 0.04
const GHOST_FADE_S := 0.3
const GHOST_COLOR := Color(1.0, 0.62, 0.35, 0.45)
const VIGNETTE_ALPHA := 0.1 ## sans tête : bords assombris de 10 % (coupé en qualité Bas)
## Anims d'action : frames d'impact (index 0) du lot T3 (layers_order.json : throw_release_frames, attack 3/6).
const ACTION_IMPACT_FRAMES := {&"attack": 3, &"cast": 3, &"cast_ult": 3, &"throw_arm_l": 2, &"throw_arm_r": 2,
	&"throw_leg_l": 2, &"throw_leg_r": 2, &"throw_head": 3}
## Socles des membres dans la cellule 192 (vue s), repli de sockets.json (T6) pour la régénération.
const SOCKETS_PX := {&"arm_l": Vector2(64, 70), &"arm_r": Vector2(128, 70), &"leg_l": Vector2(86, 108),
	&"leg_r": Vector2(106, 108), &"head": Vector2(96, 50)}
const CELL_PIVOT := Vector2(96, 136.32)
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const SLOT_LIMBS := {2: [&"arm_l", &"arm_r"], 3: [&"leg_l", &"leg_r"], 4: [&"head"]}

var player: CharacterBody2D = null
var present := {&"arm_l": true, &"arm_r": true, &"leg_l": true, &"leg_r": true, &"head": true}
var limbs := {} ## clé -> TocsinLimb en jeu (vol, pince, sol)
var queue := {2: [], 3: [], 4: []} ## membres en recharge, dans l'ordre de lancer (le premier se recharge)
var recharge_left := {2: 0.0, 3: 0.0, 4: 0.0}
var layers: TocsinLayers = null
var quille_spell: SpellData = null
var blast_bonus_spell: SpellData = null
var smoke_bonus_spell: SpellData = null ## Tête-fumigène : +50 % sur les emprisonnés, sans proc
var _pull: Dictionary = {} ## Bras-harpon : traction en cours {e, left, limb}
var _jump: Dictionary = {} ## Jambes-ressorts : saut en cours {start, target, t, spell}
var _visual_y0 := 0.0
var _visual: AnimatedSprite2D = null
var _pending: Array = [] ## lancers en attente de la frame d'impact : {key, spell, dir, aim}
var _last_action: StringName = &""
var _fall_left := 0.0
var _legs_before := 2
var _ghost_t := 0.0
var _kick_left := 0.0
var _absent_cache := -1
var _vignette: CanvasLayer = null
var _regen_frames: SpriteFrames = null


# --- Données -------------------------------------------------------------------------------------

static func _spell(sid: StringName, name: String, slot: int, behavior: SpellData.Behavior, coef: float, cd: float) -> SpellData:
	var s := SpellData.new()
	s.id = sid
	s.display_name = name
	s.slot = slot
	s.behavior = behavior
	s.coef = coef
	s.base_cooldown = cd
	s.element = &"physical"
	s.color = ACCENT
	s.light_preset = &"tocsin_limb" ## braise du foyer : l'accent de Tocsin (pas la lumière d'Ardent)
	return s


static func character() -> CharacterData:
	var c := CharacterData.new()
	c.id = &"tocsin"
	c.display_name = "Tocsin"
	c.base_hp = BASE_HP
	c.hp_per_level = HP_PER_LEVEL
	c.armor = ARMOR
	c.base_regen = BASE_REGEN
	c.regen_per_level = REGEN_PER_LEVEL
	c.base_speed_u = BASE_SPEED_U
	c.hitbox_u = HITBOX_U
	c.kit_script = TocsinKit
	if TocsinLayers.available(ASSET_DIR):
		c.sprite_frames_path = TocsinLayers.frames_path(ASSET_DIR, &"torso") # le Visual = calque torse
	else:
		c.sprite_frames_path = COMPOSITE_FRAMES
	c.placeholder_tint = PLACEHOLDER_TINT
	c.body_color = Color("#5F8F80")
	c.accent_color = ACCENT
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"tocsin_rivets_rougis", "Rivets rougis", 1, SpellData.Behavior.PROJECTILE, RIVET_COEF, RIVET_INTERVAL_S)
	s1.is_auto = true
	s1.range_u = RIVET_RANGE_U
	s1.trigger_range_u = RIVET_RANGE_U
	s1.speed_u = RIVET_SPEED_U
	s1.pierce = RIVET_PIERCE
	s1.is_zone = false
	s1.proc_coef = 1.0
	s1.light_preset = &"tocsin_rivet"
	s1.projectile_frames = RIVET_FRAMES if ResourceLoader.exists(RIVET_FRAMES) else ""

	var s2 := _spell(&"tocsin_bras_grappins", "Bras-grappins", 2, SpellData.Behavior.KIT, ARM_COEF, ARM_CD_S)
	s2.range_u = ARM_RANGE_U
	s2.radius_u = ARM_WIDTH_U * 0.5
	s2.proc_coef = ARM_PROC
	s2.target_mode = &"densest"
	s2.trigger_range_u = ARM_RANGE_U

	var s3 := _spell(&"tocsin_coups_de_botte", "Coups de botte", 3, SpellData.Behavior.KIT, LEG_COEF, LEG_CD_S)
	s3.range_u = LEG_RANGE_U
	s3.radius_u = LEG_WIDTH_U * 0.5
	s3.proc_coef = 1.0
	s3.trigger_range_u = LEG_RANGE_U

	var s4 := _spell(&"tocsin_tete_cloche", "Tête-cloche", 4, SpellData.Behavior.KIT, HEAD_COEF, HEAD_CD_S)
	s4.range_u = HEAD_RANGE_U
	s4.radius_u = HEAD_RADIUS_U
	s4.proc_coef = 1.0
	s4.trigger_range_u = HEAD_RANGE_U - 1.0
	s4.light_preset = &"tocsin_blast"

	c.spells = [s1, s2, s3, s4]
	return c


static func _force_for(knock_u: float) -> float:
	return clampf(inverse_lerp(Balance.KB_MIN_U, Balance.KB_MAX_U, knock_u), 0.0, 1.0)


## Variantes (contrat CONTRACTS.md) : SpellData de la variante `variant_id` pour `slot`, ou null (non codée).
## Coefficients ajustés par balance_sim (±15 % du sort de base) ; le style ne change pas.
static func variant(slot: int, variant_id: StringName) -> SpellData:
	match [slot, variant_id]:
		[1, V_VAPEUR]:
			var s1 := _spell(V_VAPEUR, "Vapeur", 1, SpellData.Behavior.KIT, VAPEUR_COEF, RIVET_INTERVAL_S)
			s1.is_auto = true
			s1.range_u = VAPEUR_RANGE_U
			s1.trigger_range_u = VAPEUR_RANGE_U
			s1.radius_u = VAPEUR_RANGE_U
			s1.spread_deg = VAPEUR_CONE_DEG
			s1.proc_coef = VAPEUR_PROC
			s1.hit_force = _force_for(VAPEUR_KNOCK_U)
			s1.light_preset = &"tocsin_rivet"
			return s1
		[2, V_HARPON]:
			var s2 := _spell(V_HARPON, "Bras-harpon", 2, SpellData.Behavior.KIT, HARPON_COEF, ARM_CD_S)
			s2.range_u = HARPON_RANGE_U
			s2.radius_u = HARPON_WIDTH_U * 0.5
			s2.proc_coef = HARPON_PROC
			s2.is_zone = false
			s2.target_mode = &"densest"
			s2.trigger_range_u = HARPON_RANGE_U
			return s2
		[3, V_RESSORTS]:
			var s3 := _spell(V_RESSORTS, "Jambes-ressorts", 3, SpellData.Behavior.KIT, RESSORTS_COEF, LEG_CD_S)
			s3.range_u = RESSORTS_RANGE_U
			s3.radius_u = RESSORTS_RADIUS_U
			s3.proc_coef = RESSORTS_PROC
			s3.target_mode = &"densest"
			s3.trigger_range_u = RESSORTS_RANGE_U
			return s3
		[4, V_FUMIGENE]:
			var s4 := _spell(V_FUMIGENE, "Tête-fumigène", 4, SpellData.Behavior.KIT, FUMI_COEF, HEAD_CD_S)
			s4.range_u = HEAD_RANGE_U
			s4.radius_u = FUMI_RADIUS_U
			s4.duration = FUMI_S
			s4.tick = FUMI_TICK_S
			s4.proc_coef = FUMI_PROC
			s4.trigger_range_u = HEAD_RANGE_U - 1.0
			s4.light_preset = &"tocsin_blast"
			return s4
	return null


## Points d'emprisonnement d'un monstre (§1.3 : T1 1, T2 1, élite 2, T3 3).
static func capture_cost(e: Node) -> int:
	if not (e is Enemy):
		return 1
	var en := e as Enemy
	var c := 3 if en.tier >= 3 else 1
	return maxi(c, 2) if en.is_elite else c


# --- Mise en place ------------------------------------------------------------------------------

func setup(p: CharacterBody2D) -> void:
	player = p
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	if _visual != null and TocsinLayers.available(ASSET_DIR) and _visual.sprite_frames != null \
			and _visual.sprite_frames.has_animation(&"walk_s"):
		layers = TocsinLayers.attach(_visual, ASSET_DIR)
	quille_spell = _spell(&"quilles", "Quilles", 3, SpellData.Behavior.KIT, QUILLE_COEF, 0.0)
	quille_spell.proc_coef = QUILLE_PROC
	blast_bonus_spell = _spell(&"tocsin_tete_cloche", "Tête-cloche (confinée)", 4, SpellData.Behavior.KIT,
			HEAD_COEF * HEAD_PRISONER_BONUS, 0.0)
	blast_bonus_spell.proc_coef = 0.0 # le bonus n'est pas un second coup : pas de proc
	smoke_bonus_spell = _spell(V_FUMIGENE, "Tête-fumigène (confinée)", 4, SpellData.Behavior.KIT,
			FUMI_COEF * FUMI_PRISONER_BONUS, 0.0)
	smoke_bonus_spell.proc_coef = 0.0
	if ResourceLoader.exists(REGEN_FRAMES):
		_regen_frames = load(REGEN_FRAMES) as SpriteFrames
	if _visual != null:
		_visual_y0 = _visual.position.y
	Events.floor_started.connect(_on_floor_started)
	Events.player_died.connect(_on_player_died)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.boss_killed.connect(_on_boss_killed)
	if p.has_signal(&"action_impact"):
		p.action_impact.connect(_on_action_impact)
	_refresh_state()


func _exit_tree() -> void:
	for sig: Signal in [Events.floor_started, Events.player_died, Events.enemy_killed, Events.boss_killed]:
		for cn in sig.get_connections():
			if cn["callable"].get_object() == self:
				sig.disconnect(cn["callable"])
	clear_transients()


func _caster() -> SpellCaster:
	return player.spells if player != null else null


func _spell_of(slot: int) -> SpellData:
	for s in player.character.spells:
		if s.slot == slot:
			return s
	return null


# --- État des membres ----------------------------------------------------------------------------

func arms() -> int:
	return int(present[&"arm_l"]) + int(present[&"arm_r"])


func legs() -> int:
	return int(present[&"leg_l"]) + int(present[&"leg_r"])


func has_head() -> bool:
	return bool(present[&"head"])


func absent_count() -> int:
	return 5 - arms() - legs() - int(has_head())


## Charges disponibles d'un sort (membres présents).
func charges(slot: int) -> int:
	var n := 0
	for k: StringName in SLOT_LIMBS.get(slot, []):
		n += int(present[k])
	return n


## Hook SpellCaster.slot_charges : pastilles de charges des boutons (bras, jambes ; la tête n'en a pas).
func slot_charges(slot: int) -> Vector2i:
	var n: int = (SLOT_LIMBS.get(slot, []) as Array).size()
	return Vector2i(charges(slot), n) if n > 1 else Vector2i(-1, 0)


## Ressource (contrat KitResource) : membres présents (5 pastilles : bras, jambes, tête).
func resource_state() -> Dictionary:
	var n := 5 - absent_count()
	return KitResource.make(&"limbs", "Membres", 0.0, ACCENT,
		{"pips": 5, "filled": n, "blocked": blocks_slot(3)})


## Sauvegarde de run : membres présents et recharges (les membres lancés repartent en recharge à la reprise).
func save_state() -> Dictionary:
	var pres := {}
	for k: StringName in present:
		pres[String(k)] = bool(present[k])
	var q := {}
	for slot: int in queue:
		q[str(slot)] = (queue[slot] as Array).map(func(k: StringName) -> String: return String(k))
	var r := {}
	for slot: int in recharge_left:
		r[str(slot)] = float(recharge_left[slot])
	return {"present": pres, "queue": q, "recharge_left": r}


func load_state(d: Dictionary) -> void:
	if not (d.get("present") is Dictionary):
		return
	clear_transients()
	for k: StringName in present:
		present[k] = bool((d["present"] as Dictionary).get(String(k), true))
	for slot: int in queue:
		var q: Array = []
		for k in (d.get("queue", {}) as Dictionary).get(str(slot), []):
			if present.has(StringName(k)) and not present[StringName(k)]:
				q.append(StringName(k))
		queue[slot] = q
		recharge_left[slot] = float((d.get("recharge_left", {}) as Dictionary).get(str(slot), 0.0)) if not q.is_empty() else 0.0
	for k: StringName in present: # membre absent sans recharge (sauvegarde incohérente) : rendu
		if not present[k] and not ((queue[_slot_of(k)] as Array).has(k)):
			present[k] = true
	_refresh_state()
	_sync_caster()


## Membre en jeu sous `key`, ou null (jamais une instance libérée : le membre a pu disparaître dans la frame).
func _limb(key: StringName) -> TocsinLimb:
	var v: Variant = limbs.get(key)
	if v == null or not is_instance_valid(v):
		return null
	return v as TocsinLimb


static func _slot_of(key: StringName) -> int:
	for slot: int in SLOT_LIMBS:
		if (SLOT_LIMBS[slot] as Array).has(key):
			return slot
	return 0


## Locomotion (§1.4) : &"walk", &"hop", &"handwalk", &"crawl", &"roll".
func locomotion() -> StringName:
	var l := legs()
	if l == 2:
		return &"walk"
	if l == 1:
		return &"hop"
	match arms():
		2:
			return &"handwalk"
		1:
			return &"crawl"
	return &"roll"


## Le monstre est-il accroché ou emprisonné par un bras ?
func is_captured(e: Node) -> bool:
	for k: StringName in [&"arm_l", &"arm_r"]:
		var l: TocsinLimb = _limb(k)
		if l != null and l.holds(e):
			return true
	return false


## Libère un prisonnier (jambe qui le frappe, explosion de la tête).
func free_enemy(e: Node) -> void:
	for k: StringName in [&"arm_l", &"arm_r"]:
		var l: TocsinLimb = _limb(k)
		if l != null:
			l.release(e)


# --- Hooks du joueur et de SpellCaster ----------------------------------------------------------

## Seul vrai blocage : les jambes sans bras (les charges épuisées passent par la recharge du SpellCaster).
func blocks_slot(slot: int) -> bool:
	if (slot == 2 or slot == 3) and (is_pulling() or is_jumping()):
		return true # une traction / un saut à la fois
	return slot == 3 and not _spring() and arms() == 0 and legs() > 0


func can_dodge() -> bool:
	return not is_pulling() and not is_jumping()


## Variante active du slot (sort du joueur).
func _is_variant(slot: int, vid: StringName) -> bool:
	var s := _spell_of(slot)
	return s != null and s.id == vid


func _spring() -> bool:
	return _is_variant(3, V_RESSORTS)


func is_pulling() -> bool:
	return not _pull.is_empty()


func is_jumping() -> bool:
	return not _jump.is_empty()


## Auto-cast (SpellCaster._auto_cast_ok) : les bottes exigent un bras présent. Tant qu'une jambe est là,
## le dernier bras reste sur le corps (sinon les deux bras partent et les bottes restent bloquées : 0 lancer
## au simulateur du 22/10/2026). En manuel le joueur décide seul.
func auto_cast_ok(slot: int) -> bool:
	if slot == 2:
		return arms() >= 2 or legs() == 0 or _spring() # les ressorts n'ont pas besoin de bras
	if slot == 3: # une botte à la fois : jamais à ramper au milieu du combat
		return legs() >= 2
	return true


## SpellCaster.compute_damage : Tête-cloche renforcée sur les boss.
func damage_add(s: SpellData, enemy: Node) -> float:
	if s.slot == 4 and s.id != V_FUMIGENE and is_instance_valid(enemy) and enemy.is_in_group(&"bosses"):
		return HEAD_BOSS_ADD
	return 0.0


func speed_mult() -> float:
	if is_pulling() or is_jumping():
		return 0.0 # la traction / le saut portent Tocsin : l'entrée ne lutte pas
	match locomotion():
		&"hop":
			return 0.5 # cloche-pied 2,0 u/s
		&"handwalk":
			return 0.6 # 2,4 u/s
		&"crawl":
			return 0.35 # 1,4 u/s
		&"roll":
			return 0.5 # tonneau 2,0 u/s
	return 1.0


func dodge_distance_u() -> float:
	match locomotion():
		&"hop", &"crawl":
			return DODGE_HOP_U
		&"roll":
			return DODGE_ROLL_U
	return DODGE_U


func inertia_s() -> float:
	return 0.0


func slow_immune() -> bool:
	return false


func locks_facing() -> bool:
	return false


## Fantômes de roulade : le kit les fait lui-même avec tous les calques (TocsinLayers.spawn_ghost).
func dodge_ghosts() -> bool:
	return layers == null


func on_dodge_start(_dir: Vector2) -> void:
	_ghost_t = 0.0


func cast_spell(s: SpellData, aim: Variant) -> bool:
	if player == null or player.dead:
		return false
	match s.id: # variantes sans lancer de membre standard
		V_VAPEUR:
			return _cast_vapeur(s)
		V_RESSORTS:
			return _cast_spring(s, aim)
	var key := _next_limb(s.slot)
	if key == &"":
		return false
	if s.slot == 3 and arms() == 0:
		return false
	var origin := player.global_position
	var point: Variant = aim
	if point == null:
		point = _auto_target(s)
	var d: Vector2 = player.facing
	if point != null and ((point as Vector2) - origin).length_squared() > 1.0:
		d = ((point as Vector2) - origin).normalized()
	if d == Vector2.ZERO:
		d = Vector2.DOWN
	if point == null:
		point = origin + d * _range_px(s) * 0.6
	present[key] = false
	(queue[s.slot] as Array).append(key)
	if (queue[s.slot] as Array).size() == 1:
		recharge_left[s.slot] = _cooldown(s)
	player.facing = d
	_last_action = StringName("throw_%s" % key)
	var pend := {"key": key, "spell": s, "dir": d, "aim": point}
	if _has_throw_anim():
		_pending.append(pend)
	else:
		_last_action = &""
		_launch(pend) # rampe / tonneau : pas d'anim de lancer debout, le membre part tout de suite
	_refresh_state()
	return true


## Ordre des charges : gauche puis droite.
func _next_limb(slot: int) -> StringName:
	for k: StringName in SLOT_LIMBS.get(slot, []):
		if present[k]:
			return k
	return &""


## Les anims de lancer sont rendues debout : sans jambe, le membre part sans elles.
func _has_throw_anim() -> bool:
	return legs() >= 1


## Ciblage automatique (tactile, stick au repos) : jambes -> paquet emprisonné sinon le plus dense ;
## tête -> paquet emprisonné sinon le plus dense à 6 u ; bras -> le plus dense (SpellCaster, S5).
func _auto_target(s: SpellData) -> Variant:
	var r := _range_px(s)
	if s.slot == 3 or s.slot == 4:
		for k: StringName in [&"arm_l", &"arm_r"]:
			var l: TocsinLimb = _limb(k)
			if l != null and l.is_clamping() \
					and l.global_position.distance_to(player.global_position) <= r + PACK_RADIUS_U * Balance.UNIT_PX:
				return l.global_position
	var c := _caster()
	return c.densest_point(r) if c != null else null


func _range_px(s: SpellData) -> float:
	return s.range_u * Balance.UNIT_PX * (1.0 + player.stat(&"range_add"))


func _cooldown(s: SpellData) -> float:
	var m: float = player.stat(&"cooldown_mult")
	return Balance.effective_cooldown(s.base_cooldown, m if m > 0.0 else 1.0)


## Anim d'action (Player.play_action) : throw_<membre> pour les sorts 2-4 ; `attack` pour les rivets
## seulement à l'arrêt, debout, sans autre action en cours (en marche, le corps continue de marcher).
func action_for(s: SpellData) -> StringName:
	if s.slot == 1:
		if legs() == 2 and not player.is_moving and player.action_base() == &"":
			return &"attack"
		return &""
	var a := _last_action
	_last_action = &""
	return a


## Frame d'impact de throw_* : le membre part (le plus ancien lancer en attente).
func _on_action_impact(base: StringName) -> void:
	if String(base).begins_with("throw_") and not _pending.is_empty():
		var pend: Dictionary = _pending.pop_front()
		if player != null and not player.dead:
			_launch(pend)


func on_cast(s: SpellData) -> void:
	if s.slot == 1:
		_kick_left = FURNACE_KICK_S # le foyer crache le rivet


func _launch(pend: Dictionary) -> void:
	var key: StringName = pend["key"]
	var s: SpellData = pend["spell"]
	var d: Vector2 = pend["dir"]
	var parent := player.get_parent()
	if parent == null:
		return
	var l := TocsinLimb.new()
	l.kit = self
	l.caster = _caster()
	l.spell = s
	l.key = key
	l.dir = d
	l.name = "Tocsin_%s" % key
	var zone: float = 1.0 + player.stat(&"zone_size_add")
	match s.slot:
		2:
			l.kind = &"arm"
			l.phase = TocsinLimb.Phase.OUT
			l.speed_px = ARM_SPEED_U * Balance.UNIT_PX
			l.travel_left_px = _range_px(s)
			l.half_width_px = ARM_WIDTH_U * 0.5 * zone * Balance.UNIT_PX
			if s.id == V_HARPON: # tir droit, s'arrête au premier monstre
				l.harpoon = true
				l.speed_px = HARPON_SPEED_U * Balance.UNIT_PX
				l.half_width_px = HARPON_WIDTH_U * 0.5 * Balance.UNIT_PX
			else:
				var other: TocsinLimb = _limb(&"arm_r" if key == &"arm_l" else &"arm_l")
				if other != null and other.phase != TocsinLimb.Phase.GROUND:
					l.lateral = -ARM_LATERAL_U if other.lateral >= 0.0 else ARM_LATERAL_U
		3:
			l.kind = &"leg"
			l.phase = TocsinLimb.Phase.OUT
			l.travel_left_px = _range_px(s)
			l.speed_px = l.travel_left_px / LEG_TRAVEL_S
			l.half_width_px = LEG_WIDTH_U * 0.5 * zone * Balance.UNIT_PX
		4:
			l.kind = &"head"
			l.phase = TocsinLimb.Phase.FLY
			l.start = player.global_position
			var aim: Vector2 = pend["aim"]
			l.target = player.global_position + (aim - player.global_position).limit_length(_range_px(s))
			l.smoke = s.id == V_FUMIGENE
			l.radius_px = (FUMI_RADIUS_U if l.smoke else HEAD_RADIUS_U) * zone * Balance.UNIT_PX
	parent.add_child(l)
	l.global_position = player.global_position
	l.setup_visual()
	_track_limb(key, l)
	Audio.play(&"enemy.shot.medium", player.global_position, -4.0, 0.55) # le membre se dévisse
	if s.slot == 4:
		Audio.play(&"enemy.shockwave.heavy", player.global_position, -10.0, 1.6) # le bouchon saute


## Seul point d'entrée de `limbs` : un membre quitte le dictionnaire quand il quitte l'arbre (queue_free,
## étage déchargé…), jamais d'instance libérée dedans. Un membre plus récent de même clé n'est pas effacé.
func _track_limb(key: StringName, l: TocsinLimb) -> void:
	limbs[key] = l
	l.tree_exiting.connect(_untrack_limb.bind(key, l), CONNECT_ONE_SHOT)


func _untrack_limb(key: StringName, l: TocsinLimb) -> void:
	if limbs.get(key) == l:
		limbs.erase(key)


## Membre au sol ramassé : équilibrage 23/10 : le membre ne revient plus tout de suite, la recharge restante
## du sort est réduite de PICKUP_CD_REFUND (avant : charge pleine rendue).
func collect_limb(l: TocsinLimb) -> void:
	if l == null or player == null or player.dead:
		return
	var key := l.key
	l.release_all(ARM_RELEASE_SLOW_PCT, ARM_RELEASE_SLOW_S)
	l.queue_free()
	limbs.erase(key)
	var slot := _slot_of(key)
	if (queue[slot] as Array).has(key):
		recharge_left[slot] = float(recharge_left[slot]) * PICKUP_CD_REFUND
	else:
		_regen(key)
	Audio.play(&"pickup.coin", player.global_position, -6.0, 0.7)


## Explosion de la tête : lumière, secousse, gerbes (TOP au sol + CREA volumique).
func on_head_blast(l: TocsinLimb, at: Vector2) -> void:
	limbs.erase(l.key)
	LightRig.flash(at, &"tocsin_blast", 0.7)
	Audio.play(&"enemy.shockwave.heavy", at, 2.0, 0.8)
	var n := player.get_parent()
	while n != null and not n.has_method(&"shake"):
		n = n.get_parent()
	if n != null:
		n.shake(HEAD_SHAKE_PX, 18.0, 0.35)
	_blast_vfx(at, l.radius_px)


func _blast_vfx(at: Vector2, radius: float) -> void:
	var parent := player.get_parent()
	if parent == null or not ResourceLoader.exists(BLAST_FRAMES):
		return
	var sf := load(BLAST_FRAMES) as SpriteFrames
	if sf == null:
		return
	if sf.has_animation(&"head_blast_top"): # vue TOP : posée au sol, calée sur le rayon réel
		var top := AnimatedSprite2D.new()
		top.z_index = -1
		parent.add_child(top)
		top.global_position = at
		EmissiveOverlay.apply(top, sf)
		var k := radius / BLAST_TOP_RING_PX
		top.scale = Vector2(k, k)
		top.sprite_frames.set_animation_loop(&"head_blast_top", false)
		top.play(&"head_blast_top")
		top.animation_finished.connect(top.queue_free)
	if sf.has_animation(&"head_blast"): # gerbe de bronze et de suie (CREA, billboard)
		var crea := AnimatedSprite2D.new()
		parent.add_child(crea)
		crea.global_position = at
		EmissiveOverlay.apply(crea, sf)
		crea.scale = Vector2(0.70710678, 1.4142136) * BLAST_CREA_K
		crea.offset = Vector2(0, -40.32)
		crea.sprite_frames.set_animation_loop(&"head_blast", false)
		crea.play(&"head_blast")
		crea.animation_finished.connect(crea.queue_free)


# --- Variantes : Vapeur, Bras-harpon, Jambes-ressorts, Tête-fumigène -----------------------------------

## Vapeur : cône de 60° vers le monstre le plus proche (portée 3 u, + range_add × 0,5), anneau 360° sans tête.
## Rien à portée : pas de lancer (le sort auto ne consomme rien).
func _cast_vapeur(s: SpellData) -> bool:
	var c := _caster()
	if c == null:
		return false
	var reach: float = s.range_u * Balance.UNIT_PX * (1.0 + VAPEUR_RANGE_ADD_K * player.stat(&"range_add"))
	var near := c.nearest_enemy(reach)
	if near == null:
		return false
	var origin := player.global_position
	var d := near.global_position - origin
	if d.length_squared() > 1.0:
		d = d.normalized()
	else:
		d = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
	var ring := not has_head()
	var half := deg_to_rad(VAPEUR_CONE_DEG) * 0.5
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		var off: Vector2 = (e as Node2D).global_position - origin
		var rad := TocsinLimb._radius_of(e)
		var dist := off.length()
		if dist > reach + rad:
			continue
		if not ring and dist > rad + 0.3 * Balance.UNIT_PX: # cône : l'angle compte (marge = rayon du corps vu de là)
			var slack := asin(clampf(rad / maxf(dist, 1.0), 0.0, 1.0))
			if absf(d.angle_to(off)) > half + slack:
				continue
		c.deal_damage(e, s, {"source_pos": origin})
		if TocsinLimb._alive(e):
			e.apply_status(&"slow", {"pct": VAPEUR_SLOW_PCT, "duration": VAPEUR_SLOW_S})
	player.facing = d
	TocsinSteamFx.spawn(player.get_parent(), origin, TocsinSteamFx.Mode.RING if ring else TocsinSteamFx.Mode.CONE,
			reach, d, 0.22)
	Audio.play(&"enemy.shot.medium", origin, -12.0, 1.9 - 0.05 * mini(absent_count(), 5)) # « pschhh », plus grave si Surchauffe haute
	return true


## Bras-harpon accroché : Tocsin est tiré vers la cible (16 u/s, 0,5 s max, traverse les monstres, invulnérable).
func begin_pull(l: TocsinLimb, e: Node2D) -> void:
	if player == null or player.dead or e == null:
		return
	_pull = {"e": e, "left": HARPON_PULL_MAX_S, "limb": l}
	var d := e.global_position - player.global_position
	if d.length_squared() > 1.0:
		player.facing = d.normalized()
	player.grant_invulnerability(HARPON_PULL_MAX_S + 0.05)
	Audio.play(&"hit.heavy", player.global_position, -6.0, 1.3) # le treuil


func _pull_step(delta: float) -> void:
	if _pull.is_empty():
		return
	var e: Variant = _pull["e"]
	_pull["left"] = float(_pull["left"]) - delta
	if e == null or not is_instance_valid(e) or not TocsinLimb._alive(e as Node) or float(_pull["left"]) <= 0.0:
		_end_pull()
		return
	var target := e as Node2D
	var to := target.global_position - player.global_position
	var stop := HARPON_STOP_U * Balance.UNIT_PX + TocsinLimb._radius_of(target)
	var dist := to.length()
	if dist <= stop:
		_end_pull()
		return
	var step := minf(HARPON_PULL_SPEED_U * Balance.UNIT_PX * delta, dist - stop)
	var moved: Vector2 = player.move_swept(to.normalized() * step)
	player.grant_invulnerability(delta * 2.0)
	if moved.length() < step * 0.25: # mur : la traction s'arrête
		_end_pull()


## Arrivée : onde de 1,5 u, recul 1 u × masse, aucun dégât (il écarte le paquet).
func _end_pull() -> void:
	if _pull.is_empty():
		return
	_pull = {}
	var zone: float = 1.0 + player.stat(&"zone_size_add")
	var r: float = HARPON_WAVE_U * zone * Balance.UNIT_PX
	shockwave(player.global_position, r, HARPON_WAVE_PUSH_U, false)
	TocsinSteamFx.spawn(player.get_parent(), player.global_position, TocsinSteamFx.Mode.WAVE, r, Vector2.RIGHT, 0.25)
	Audio.play(&"enemy.shockwave.heavy", player.global_position, -8.0, 1.5)


## Poussée radiale autour de `center` : `push_u` × masse (×1,5 et libération des emprisonnés si `free_prisoners`).
## Sans effet sur un boss (Enemy.push).
func shockwave(center: Vector2, radius_px: float, push_u: float, free_prisoners: bool) -> void:
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		if (e as Node2D).global_position.distance_to(center) > radius_px + TocsinLimb._radius_of(e) * 0.5:
			continue
		var mult := 1.0
		if free_prisoners and is_captured(e):
			free_enemy(e)
			mult = LEG_PRISONER_PUSH_MULT
		if TocsinLimb._alive(e) and not TocsinLimb._is_boss(e):
			var away: Vector2 = (e as Node2D).global_position - center
			TocsinLimb._push(e, (away.normalized() if away.length_squared() > 1.0 else Vector2.RIGHT) * push_u * mult)


## Jambes-ressorts : saut LOB 0,5 s vers le point visé (≤ 5 u, 4 sans tête) ; la jambe reste au décollage.
func _cast_spring(s: SpellData, aim: Variant) -> bool:
	if is_jumping() or is_pulling():
		return false
	var key := _next_limb(3)
	if key == &"":
		return false
	var origin := player.global_position
	var point: Variant = aim
	if point == null:
		point = _auto_target(s)
	var d: Vector2 = player.facing
	if point != null and ((point as Vector2) - origin).length_squared() > 1.0:
		d = ((point as Vector2) - origin).normalized()
	if d == Vector2.ZERO:
		d = Vector2.DOWN
	var reach := _range_px(s) * 0.6
	if point != null:
		reach = minf(((point as Vector2) - origin).length(), _range_px(s))
	present[key] = false
	(queue[3] as Array).append(key)
	if (queue[3] as Array).size() == 1:
		recharge_left[3] = _cooldown(s)
	player.facing = d
	_plant_leg(key, s, origin, d)
	_jump = {"start": origin, "target": origin + d * reach, "t": 0.0, "spell": s}
	if _visual != null:
		_visual_y0 = _visual.position.y
	player.grant_invulnerability(RESSORTS_FLIGHT_S + 0.05)
	_refresh_state()
	Audio.play(&"enemy.shot.medium", origin, -4.0, 0.5) # ressort comprimé
	return true


## La jambe reste au point de décollage (ramassable après PICKUP_DELAY_S, comme une jambe tombée).
func _plant_leg(key: StringName, s: SpellData, at: Vector2, d: Vector2) -> void:
	var parent := player.get_parent()
	if parent == null:
		return
	var l := TocsinLimb.new()
	l.kit = self
	l.caster = _caster()
	l.spell = s
	l.key = key
	l.dir = d
	l.kind = &"leg"
	l.phase = TocsinLimb.Phase.GROUND
	l.name = "Tocsin_%s" % key
	parent.add_child(l)
	l.global_position = at
	l.setup_visual()
	l.plant_ground()
	_track_limb(key, l)


func _jump_step(delta: float) -> void:
	if _jump.is_empty():
		return
	_jump["t"] = float(_jump["t"]) + delta
	var k := clampf(float(_jump["t"]) / RESSORTS_FLIGHT_S, 0.0, 1.0)
	var want: Vector2 = (_jump["start"] as Vector2).lerp(_jump["target"] as Vector2, k)
	var off := want - player.global_position
	if off.length_squared() > 0.01:
		player.move_swept(off)
	player.grant_invulnerability(delta * 2.0)
	if _visual != null:
		_visual.position.y = _visual_y0 + Iso.lift_logical(RESSORTS_HEIGHT_U) * sin(PI * k)
	if k >= 1.0:
		_land_spring()


## Atterrissage : disque 2 u (+ zone_size_add), coef 3,0, poussée radiale 2 u × masse (×1,5 et libération des prisonniers).
func _land_spring() -> void:
	var s: SpellData = _jump["spell"]
	_jump = {}
	if _visual != null:
		_visual.position.y = _visual_y0
	var c := _caster()
	var at := player.global_position
	var r: float = RESSORTS_RADIUS_U * (1.0 + player.stat(&"zone_size_add")) * Balance.UNIT_PX
	if c != null:
		var victims: Array = []
		for e in player.get_tree().get_nodes_in_group(&"enemies"):
			if e is Node2D and is_instance_valid(e) and e.has_method(&"take_damage") \
					and (e as Node2D).global_position.distance_to(at) <= r + TocsinLimb._radius_of(e) * 0.5:
				victims.append(e)
		for e: Node2D in victims:
			var held := is_captured(e)
			if held:
				free_enemy(e)
			c.deal_damage(e, s, {"source_pos": at})
			if TocsinLimb._alive(e) and not TocsinLimb._is_boss(e):
				var away := e.global_position - at
				TocsinLimb._push(e, (away.normalized() if away.length_squared() > 1.0 else Vector2.RIGHT)
						* RESSORTS_PUSH_U * (LEG_PRISONER_PUSH_MULT if held else 1.0))
	TocsinSteamFx.spawn(player.get_parent(), at, TocsinSteamFx.Mode.WAVE, r, Vector2.RIGHT, 0.3)
	LightRig.flash(at, &"tocsin_blast", 0.35)
	Audio.play(&"enemy.shockwave.heavy", at, -2.0, 1.1) # choc de fonte
	_shake(RESSORTS_SHAKE_PX)


func _shake(px: float) -> void:
	var n := player.get_parent()
	while n != null and not n.has_method(&"shake"):
		n = n.get_parent()
	if n != null:
		n.shake(px, 18.0, 0.3)


## Tête-fumigène posée (tintement fini) : lumière, secousse ; la zone et ses ticks sont tenus par le membre.
func on_smoke_start(_l: TocsinLimb, at: Vector2) -> void:
	LightRig.flash(at, &"tocsin_blast", 0.5)
	Audio.play(&"enemy.shockwave.heavy", at, -2.0, 1.1)
	_shake(HEAD_SHAKE_PX * 0.6)


func _on_boss_killed(_boss: Node2D, is_floor_boss: bool) -> void:
	if is_floor_boss and not has_head():
		RunState.add_counter(COUNTER_HEADLESS_BOSS)


# --- Boucle (Player.tick, avant les sorts) ------------------------------------------------------

func tick(delta: float) -> void:
	if player == null or player.dead:
		return
	for slot: int in queue:
		_recharge_step(slot, delta)
	_sync_caster()
	if _fall_left > 0.0:
		_fall_left = maxf(_fall_left - delta, 0.0)
	if _kick_left > 0.0:
		_kick_left = maxf(_kick_left - delta, 0.0)
	_update_overheat()
	_pull_step(delta)
	_jump_step(delta)
	if layers != null:
		var e := FURNACE_ENERGY * (1.0 + FURNACE_PER_LIMB * absent_count()) + (FURNACE_KICK if _kick_left > 0.0 else 0.0)
		layers.set_furnace(e)
		if player.is_dodging():
			_ghost_t -= delta
			if _ghost_t <= 0.0:
				_ghost_t = GHOST_EVERY_S
				layers.spawn_ghost(player.get_parent(), GHOST_COLOR, GHOST_FADE_S)


func _recharge_step(slot: int, delta: float) -> void:
	var q: Array = queue[slot]
	if q.is_empty():
		return
	recharge_left[slot] = float(recharge_left[slot]) - delta
	while not q.is_empty() and float(recharge_left[slot]) <= 0.0:
		var key: StringName = q.pop_front()
		var l: TocsinLimb = _limb(key)
		if l != null and l.kind != &"head":
			l.vanish() # le membre au sol part en braises
		limbs.erase(key)
		_regen(key)
		if not q.is_empty():
			recharge_left[slot] = float(recharge_left[slot]) + _cooldown(_spell_of(slot))
	if q.is_empty():
		recharge_left[slot] = 0.0


## Recharge du SpellCaster = celle des membres : 0 s'il reste un membre, sinon le temps avant le prochain.
## Une réduction venue d'ailleurs (item) est reportée sur le membre en recharge.
func _sync_caster() -> void:
	var c := _caster()
	if c == null:
		return
	for slot: int in queue:
		if not c.has_slot(slot):
			continue
		var r := c.cooldown_remaining(slot)
		var want := 0.0
		if charges(slot) == 0:
			if r < float(recharge_left[slot]) - 0.001:
				recharge_left[slot] = r
			want = float(recharge_left[slot])
		if r > want:
			c.reduce_cooldown(slot, r - want)


## Membre revenu (fin de recharge, ramassage, étage) : compte tout de suite, VFX de rivets + vapeur.
func _regen(key: StringName) -> void:
	present[key] = true
	_refresh_state()
	Audio.play(&"pickup.coin", player.global_position, -10.0, 0.45)
	if _visual == null or _regen_frames == null or not _regen_frames.has_animation(&"regen_rivets"):
		return
	var fx := AnimatedSprite2D.new()
	fx.name = "Regen_%s" % key
	fx.sprite_frames = _regen_frames
	var sock := socket_px(key)
	fx.position = sock - CELL_PIVOT # repère de la cellule (enfant du Visual : même échelle, même pivot)
	_visual.add_child(fx)
	fx.sprite_frames.set_animation_loop(&"regen_rivets", false)
	fx.play(&"regen_rivets")
	fx.animation_finished.connect(fx.queue_free)


static var _sockets_cache = null ## sockets.json décodé (Dictionary), {} si absent


## Attache du membre dans la cellule 192 : sockets.json (anim idle/run, direction, frame courantes), sinon
## SOCKETS_PX (vue s, miroir approché pour les bras).
func socket_px(key: StringName) -> Vector2:
	if _sockets_cache == null:
		_sockets_cache = {}
		if FileAccess.file_exists(SOCKETS_JSON):
			var d = JSON.parse_string(FileAccess.get_file_as_string(SOCKETS_JSON))
			if d is Dictionary and d.get("animations") is Dictionary:
				_sockets_cache = d["animations"]
	var dn := _dir_name()
	var clip: Dictionary = _sockets_cache.get("run" if player.is_moving else "idle", {})
	var frames: Array = clip.get(dn, [])
	if not frames.is_empty():
		var fi := _visual.frame if _visual != null else 0
		var f: Dictionary = frames[posmod(fi, frames.size())]
		var v: Array = f.get(String(key), [])
		if v.size() >= 2:
			return Vector2(float(v[0]), float(v[1]))
	var sock: Vector2 = SOCKETS_PX.get(key, Vector2(96, 80))
	if player.facing.x < -0.2 and (key == &"arm_l" or key == &"arm_r"): # vue miroir approchée
		sock.x = 192.0 - sock.x
	return sock


## Surchauffe (+12 % / membre absent, additif aux items, plafond global) et ciblage sans tête.
func _update_overheat() -> void:
	var n := absent_count()
	var s1 := _spell_of(1)
	if s1 == null:
		return
	var a: float = player.stat(&"attack_speed")
	var cap := Balance.ATTACK_SPEED_BONUS_CAP
	# Balance.attack_interval(base', a) = base / (1 + min(a + 0,12 n, cap))
	s1.base_cooldown = RIVET_INTERVAL_S * (1.0 + minf(a, cap)) / (1.0 + minf(a + OVERHEAT_PER_LIMB * n, cap))
	if n == _absent_cache:
		return
	_absent_cache = n
	var head := has_head()
	var vap := s1.id == V_VAPEUR
	s1.range_u = (VAPEUR_RANGE_U if vap else RIVET_RANGE_U) if head else (VAPEUR_RING_U if vap else RIVET_RANGE_HEADLESS_U)
	s1.trigger_range_u = s1.range_u
	var s2 := _spell_of(2)
	if s2 != null:
		var har := s2.id == V_HARPON
		s2.range_u = (HARPON_RANGE_U if har else ARM_RANGE_U) if head else (HARPON_RANGE_HEADLESS_U if har else ARM_RANGE_HEADLESS_U)
		s2.trigger_range_u = s2.range_u
	var s3 := _spell_of(3)
	if s3 != null:
		var spr := s3.id == V_RESSORTS
		s3.range_u = (RESSORTS_RANGE_U if spr else LEG_RANGE_U) if head else (RESSORTS_RANGE_HEADLESS_U if spr else LEG_RANGE_HEADLESS_U)
		s3.trigger_range_u = s3.range_u


## Hitbox, calques visibles, vignette, transition `fall` après un changement de membres.
func _refresh_state() -> void:
	if player == null:
		return
	var l := legs()
	if l == 0 and _legs_before > 0:
		_fall_left = FALL_S # perd la 2e jambe : il tombe
	_legs_before = l
	var loco := locomotion()
	player.set_hitbox_u(HITBOX_GROUND_U if loco == &"crawl" or loco == &"roll" else HITBOX_U)
	if layers != null:
		for k: StringName in [&"arm_l", &"arm_r", &"leg_l", &"leg_r", &"head"]:
			layers.set_wanted(k, bool(present[k]))
		layers.set_wanted(&"neck_steam", not has_head())
	_update_vignette()
	_absent_cache = -1
	if player.is_inside_tree():
		_update_overheat()


func _update_vignette() -> void:
	var on := not has_head() and player.is_inside_tree() and int(Quality.tier) > 0 \
			and DisplayServer.get_name() != "headless"
	if on and _vignette == null:
		_vignette = CanvasLayer.new()
		_vignette.name = "TocsinHeadless"
		_vignette.layer = 5
		var rect := TextureRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0.03, 0.02, 0.02, VIGNETTE_ALPHA * 2.5))
		g.add_point(0.62, Color(0, 0, 0, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.05, 0.5)
		gt.width = 256
		gt.height = 256
		rect.texture = gt
		_vignette.add_child(rect)
		player.add_child(_vignette)
	if _vignette != null:
		_vignette.visible = on


# --- Rendu ----------------------------------------------------------------------------------------

func _dir_name() -> String:
	var i := roundi(player.facing.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES[(i + 8) % 8]


func _resolve(base: String) -> StringName:
	if _visual == null or _visual.sprite_frames == null:
		return &""
	var a := StringName("%s_%s" % [base, _dir_name()])
	return a if _visual.sprite_frames.has_animation(a) else &""


## Anim du corps (Player._update_visual) : l'anim d'action en cours, sinon la locomotion de l'état (§1.4).
## `fallback` = anim d'action ou idle/run_<dir> d'Ardent : run devient walk ; sans jambe, le corps ne tient pas debout.
func visual_anim(fallback: StringName) -> StringName:
	if _visual == null or _visual.sprite_frames == null or not _visual.sprite_frames.has_animation(&"walk_s"):
		return fallback # repli Ardent teinté : ses anims idle/run
	if player.action_anim() != &"" and fallback == player.action_anim():
		return fallback
	if _fall_left > 0.0:
		var f := _resolve("fall")
		if f != &"":
			return f
	var base := "idle"
	match locomotion():
		&"walk":
			base = "walk" if player.is_moving else "idle"
		&"hop":
			base = ("hop_r" if present[&"leg_r"] else "hop_l") if player.is_moving else "idle"
		&"handwalk":
			base = "handwalk"
		&"crawl":
			base = "crawl_l" if present[&"arm_l"] else "crawl_r"
		&"roll":
			base = "roll"
	var a := _resolve(base)
	if a == &"" and base.begins_with("crawl"):
		a = _resolve("roll") # §1.12 : crawl coupable, repli roll
	return a if a != &"" else fallback


# --- Nettoyage (étage, mort) ----------------------------------------------------------------------

func clear_transients() -> void:
	_pending.clear()
	_pull = {}
	if not _jump.is_empty():
		_jump = {}
		if _visual != null:
			_visual.position.y = _visual_y0
	for k in limbs.keys():
		var l: TocsinLimb = _limb(k)
		if l != null:
			l.vanish()
	limbs.clear()


## Changement d'étage : tout membre est régénéré (état propre).
func regen_all() -> void:
	clear_transients()
	for slot: int in queue:
		(queue[slot] as Array).clear()
		recharge_left[slot] = 0.0
	for k: StringName in present:
		present[k] = true
	_last_action = &""
	_refresh_state()
	_sync_caster()


func _on_floor_started(_n: int) -> void:
	regen_all()


func _on_enemy_killed(e: Node2D, _pos: Vector2, _tier: int, _elite: bool) -> void:
	for k: StringName in [&"arm_l", &"arm_r"]:
		var l: TocsinLimb = _limb(k)
		if l != null:
			l.forget(e)


## Mort : le corps se disloque (anim `death` de tous les calques encore présents).
func _on_player_died() -> void:
	clear_transients()
	if _visual != null and _visual.sprite_frames != null:
		var a := _resolve("death")
		if a != &"":
			_visual.sprite_frames.set_animation_loop(a, false)
			_visual.play(a)



# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) ------------------------------------

static func passive_info() -> Dictionary:
	return KitResource.passive("Membres", &"membres",
		"Le corps de Tocsin est son arsenal : 5 membres (2 bras, 2 jambes, la tête). Chaque sort lance les siens ; les pastilles du HUD montrent ceux qui sont sur le robot.",
		"un membre lancé revient quand la recharge de son sort est finie (un seul membre se recharge à la fois par sort).",
		"lancer un membre le retire du robot tant que sa recharge court : jambes absentes = autre façon de marcher, tête absente = visée plus courte.",
		"Surchauffe : +%s de vitesse d'attaque par membre absent, et le foyer brille plus fort. Sans ses 2 bras ou 2 jambes, le sort concerné est bloqué. La tête sonne +%s sur les boss." % [
			KitResource.pct(OVERHEAT_PER_LIMB), KitResource.pct(HEAD_BOSS_ADD)])
