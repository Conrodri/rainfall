class_name TocsinKit
extends Node
## Kit de Tocsin, l'automate de crue (docs/Design_Personnages.md §1) : 4 sorts / 0 passif. Le corps est
## l'arsenal : les bras et la tête sont lancés et ne sont plus sur le robot tant que leur recharge court.
## Refonte du 23/10/2026 (retours du joueur) : les JAMBES ne sont plus jamais lancées (plus de perte de vitesse,
## plus de blocage) ; le Bras-grappin devient le Bras-pilier ; le slot 3 est un Coup de tocsin autour de lui.
## Données : character(). Logique : ce nœud, enfant « Kit » du joueur, interrogé par les hooks du joueur et de
## SpellCaster (blocks_slot, cast_spell, speed_mult, dodge_distance_u, visual_anim…).
## - Sort 1 Rivets rougis : projectile auto (SpellCaster) ; Surchauffe +12 % de vitesse d'attaque par membre
##   absent (foyer plus vif) ; sans tête, ciblage 8 -> 5 u.
## - Sort 2 Bras-pilier (2 charges) : le bras est lancé au point visé, se plante et décharge en zone 5 s, puis reste
##   au sol : le toucher le rattache TOUT DE SUITE (capacité, calque et recharge rendus dans la même frame).
## - Sort 3 Coup de tocsin : onde de choc autour de Tocsin, sans membre ni charge.
## - Sort 4 Tête-cloche : lob puis explosion, SpellData KIT, membre TocsinLimb lancé à la frame d'impact de throw_head.
## Charges séquentielles tenues ici : un membre présent = une charge ; un seul membre se recharge à la fois
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

# --- Sort 2 : Bras-pilier (23/10/2026, remplace le Bras-grappin) -------------------------------------
const PILLAR_COEF := 0.7 ## par tick de décharge, à tout monstre de la zone (combos 29/10 : 0,75 -> 0,7)
const PILLAR_CD_S := 8.0 ## recharge par bras (2 charges)
const PILLAR_RANGE_U := 7.0 ## portée du lancer
const PILLAR_RANGE_HEADLESS_U := 4.0
const PILLAR_RADIUS_U := 2.2 ## rayon de la zone de décharge
const PILLAR_FLIGHT_S := 0.6 ## lob
const PILLAR_LOB_HEIGHT_U := 2.0
const PILLAR_TICK_S := 0.5
const PILLAR_TICKS := 10 ## 10 ticks = 5 s ; le premier à la pose
const PILLAR_S := PILLAR_TICK_S * PILLAR_TICKS ## durée de la décharge (5 s)
const PILLAR_PROC := 0.25
const PILLAR_SLOW_PCT := 0.25 ## ralentissement rafraîchi à chaque tick (décharge qui engourdit)

# --- Sort 3 : Coup de tocsin (23/10/2026, remplace les Coups de botte) ----------------------------------
const TOLL_COEF := 2.3 ## combos 29/10 : 2,5 -> 2,3 (compensation du Coup qui fait sonner)
const TOLL_CD_S := 7.0
const TOLL_RADIUS_U := 3.0 ## onde autour de Tocsin (zone_size_add compte)
const TOLL_PUSH_U := 2.5 ## × masse (comme la poussée de la Tête-cloche, sans effet sur les boss)
const TOLL_PROC := 1.0
const TOLL_SHAKE_PX := 6.0

# --- Sort 4 : Tête-cloche -----------------------------------------------------------------------------
const HEAD_COEF := 9.0 ## équilibrage 23/10 : 12 -> 10 (22/10 : 10 -> 12) ; combos 29/10 : 10 -> 9 (compensation de la cloche sur le pilier)
const HEAD_CD_S := 22.0
const HEAD_RANGE_U := 6.0
const HEAD_RADIUS_U := 4.0
const HEAD_FLIGHT_S := 0.9
const HEAD_RING_S := 0.3
const HEAD_LOB_HEIGHT_U := 2.2
const HEAD_PUSH_EXTRA_U := 1.4 ## + le recul du coup (0,6 u) = 2 u × masse
const HEAD_SHAKE_PX := 10.0
const HEAD_BOSS_ADD := 0.3 ## équilibrage 22/10 : la cloche sonne plus fort sur les boss (+30 % additif)
## Combos (docs/Design_Combos.md §5.2). « La cloche sur le pilier » : Bras-pilier -> Tête-cloche ; « Le Coup qui fait sonner ».
const CHARGE_TAG := &"tocsin_charge" ## étiquette « électrisé » : add_damage_taken_mod(CHARGE_TAG, 1.0, CHARGE_TAG_S), sans effet propre
const CHARGE_TAG_S := 0.6 ## durée de l'étiquette, rafraîchie à chaque tick du pilier
const HEAD_CHARGE_ADD := 0.5 ## Tête-cloche sur un électrisé : +50 %, additif avec HEAD_BOSS_ADD (1,8 sur un boss électrisé)
const PILLAR_RING_CAP := 5.0 ## le pilier qui sonne : PILLAR_COEF x ticks restants, plafonné à ce coef
const PILLAR_RING_COEF := 1.5 ## décharge supplémentaire du pilier atteint par l'onde du Coup de tocsin
const PILLAR_RING_TICKS := 2 ## ticks gagnés par ce pilier (+1 s), une fois
const PILLAR_RISE_TICKS := 4 ## un bras au sol atteint par l'onde se redresse 2 s (sans recharge en plus)
const PICKUP_CD_REFUND := 0.5 ## audit P7 : ramasser un bras sans charge en main ne laisse que 50 % de sa recharge restante avant le lancer suivant
const STEAM_CHARGED_SLOW_PCT := 0.5 ## Vapeur lâchée dans un pilier en décharge : ralentissement des électrisés (0,3 sinon)
const AUTO_PROBE_S := 0.25 ## auto_cast_ok(4) : sondage du pilier
const AUTO_PILLAR_MIN_HITS := 2 ## la Tête automatique attend ce nombre de monstres dans un pilier actif

# --- Variantes de sorts (docs/Variantes_Sorts.md §2.3) ------------------------------------------------
## Retirées le 23/10/2026 avec leur sort de base : Bras-harpon (le grappin n'existe plus) et Jambes-ressorts
## (les jambes ne sont plus lancées). Restent Vapeur (slot 1) et Tête-fumigène (slot 4).
const V_VAPEUR := &"tocsin_vapeur" ## slot 1 (remplace Rivets rougis)
const V_FUMIGENE := &"tocsin_tete_fumigene" ## slot 4 (remplace Tête-cloche)
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
## Tête-fumigène : lob 6 u (comme la Tête-cloche), tintement, puis zone de fumée 5 s (10 ticks de 0,5 s).
const FUMI_COEF := 1.25 ## par tick
const FUMI_RADIUS_U := 4.0
const FUMI_S := 5.0
const FUMI_TICK_S := 0.5
const FUMI_STUN_S := 1.0
const FUMI_SLOW_PCT := 0.5
const FUMI_BOSS_SLOW_PCT := 0.4
const FUMI_PROC := 0.3
const FUMI_PRISONER_BONUS := 0.5 ## +50 % sur les monstres étourdis par l'entrée de la zone

# --- Membres au sol, roulade, états ------------------------------------------------------------------
const PICKUP_CONTACT_U := 0.6
const PICKUP_DELAY_S := 0.0 ## 23/10/2026 : plus de délai, le contact rattache le membre tout de suite
const DODGE_U := 3.0
## Coup de vapeur (docs/Design_Esquives.md §Tocsin) : la chaudière lâche sa vapeur au départ de la roulade :
## nuage STEAM_RADIUS_U pendant STEAM_S, monstres dedans ralentis STEAM_SLOW_PCT pendant STEAM_SLOW_S. Pas de dégâts.
const STEAM_RADIUS_U := 1.2
const STEAM_S := 0.6
const STEAM_SLOW_PCT := 0.3
const STEAM_SLOW_S := 1.0
const DODGE_SOUND := [&"spell.tocsin_bras_pilier.end", -6.0, 1.2]
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
## Membres lancés par slot (les jambes ne partent plus). Le slot 3 n'a pas de membre.
const SLOT_LIMBS := {2: [&"arm_l", &"arm_r"], 4: [&"head"]}
const THROWN_KEYS := [&"arm_l", &"arm_r", &"head"]
const ALL_KEYS := [&"arm_l", &"arm_r", &"leg_l", &"leg_r", &"head"]

var player: CharacterBody2D = null
var present := {&"arm_l": true, &"arm_r": true, &"leg_l": true, &"leg_r": true, &"head": true} ## les jambes restent true
var limbs := {} ## clé -> TocsinLimb en jeu (vol, décharge, sol)
var queue := {2: [], 4: []} ## membres en recharge, dans l'ordre de lancer (le premier se recharge)
var recharge_left := {2: 0.0, 4: 0.0}
var layers: TocsinLayers = null
var smoke_bonus_spell: SpellData = null ## Tête-fumigène : +50 % sur les étourdis, sans proc
var _visual: AnimatedSprite2D = null
var _pending: Array = [] ## lancers en attente de la frame d'impact : {key, spell, dir, aim}
var _last_action: StringName = &""
var _ghost_t := 0.0
var _kick_left := 0.0
var _absent_cache := -1
var _vignette: CanvasLayer = null
var _time := 0.0
var _pickup_lock := {2: 0.0, 4: 0.0} ## slot -> secondes de recharge laissées par un ramassage (P7)
var _probe_t := -10.0
var _probe_pillar_ok := true
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
	var adir := Skins.asset_dir(&"tocsin", ASSET_DIR) # dossier du skin équipé s'il est livré (docs/Skins.md)
	if TocsinLayers.available(adir):
		c.sprite_frames_path = TocsinLayers.frames_path(adir, &"torso") # le Visual = calque torse
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

	var s2 := _spell(&"tocsin_bras_pilier", "Bras-pilier", 2, SpellData.Behavior.KIT, PILLAR_COEF, PILLAR_CD_S)
	s2.range_u = PILLAR_RANGE_U
	s2.radius_u = PILLAR_RADIUS_U
	s2.duration = PILLAR_S
	s2.tick = PILLAR_TICK_S
	s2.proc_coef = PILLAR_PROC
	s2.target_mode = &"densest"
	s2.trigger_range_u = PILLAR_RANGE_U

	var s3 := _spell(&"tocsin_coup_de_tocsin", "Coup de tocsin", 3, SpellData.Behavior.KIT, TOLL_COEF, TOLL_CD_S)
	s3.range_u = TOLL_RADIUS_U
	s3.radius_u = TOLL_RADIUS_U
	s3.proc_coef = TOLL_PROC
	s3.trigger_range_u = TOLL_RADIUS_U
	s3.light_preset = &"tocsin_blast"

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


## Variantes (contrat CONTRACTS.md) : SpellData de la variante `variant_id` pour `slot`, ou null (non codée ou retirée :
## le jeu retombe sur le sort de base). Coefficients ajustés par balance_sim (±15 % du sort de base).
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


# --- Mise en place ------------------------------------------------------------------------------

func setup(p: CharacterBody2D) -> void:
	player = p
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	var adir := Skins.asset_dir(&"tocsin", ASSET_DIR)
	if _visual != null and TocsinLayers.available(adir) and _visual.sprite_frames != null \
			and _visual.sprite_frames.has_animation(&"walk_s"):
		layers = TocsinLayers.attach(_visual, adir)
	smoke_bonus_spell = _spell(V_FUMIGENE, "Tête-fumigène (étourdie)", 4, SpellData.Behavior.KIT,
			FUMI_COEF * FUMI_PRISONER_BONUS, 0.0)
	smoke_bonus_spell.proc_coef = 0.0
	if ResourceLoader.exists(REGEN_FRAMES):
		_regen_frames = load(REGEN_FRAMES) as SpriteFrames
	Events.floor_started.connect(_on_floor_started)
	Events.player_died.connect(_on_player_died)
	Events.boss_killed.connect(_on_boss_killed)
	if p.has_signal(&"action_impact"):
		p.action_impact.connect(_on_action_impact)
	_refresh_state()


func _exit_tree() -> void:
	for sig: Signal in [Events.floor_started, Events.player_died, Events.boss_killed]:
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


## Les jambes ne partent jamais (23/10/2026) : toujours 2.
func legs() -> int:
	return 2


func has_head() -> bool:
	return bool(present[&"head"])


## Membres lancés absents (2 bras + la tête : 0 à 3).
func absent_count() -> int:
	return 3 - arms() - int(has_head())


## Charges disponibles d'un sort (membres présents).
func charges(slot: int) -> int:
	var n := 0
	for k: StringName in SLOT_LIMBS.get(slot, []):
		n += int(present[k])
	return n


## Hook SpellCaster.slot_charges : pastilles de charges des boutons (bras ; la tête et le Coup de tocsin n'en ont pas).
func slot_charges(slot: int) -> Vector2i:
	var n: int = (SLOT_LIMBS.get(slot, []) as Array).size()
	return Vector2i(charges(slot), n) if n > 1 else Vector2i(-1, 0)


## Mode test « ressource pleine » et aperçu : tout membre en recharge est régénéré sur-le-champ, comme à la fin de
## sa recharge (un membre au sol ou en vol part en braises, un pilier finit d'abord sa décharge). Recharges à zéro.
func refill_resource() -> void:
	var any := false
	for slot: int in queue:
		var q: Array = queue[slot]
		while not q.is_empty():
			var key: StringName = q.pop_front()
			var l: TocsinLimb = _limb(key)
			if l != null and l.kind != &"head":
				l.expire()
			limbs.erase(key)
			_regen(key)
			any = true
		recharge_left[slot] = 0.0
	if any:
		_sync_caster()


## Ressource (contrat KitResource) : membres lancés présents (3 pastilles : bras, bras, tête).
func resource_state() -> Dictionary:
	var n := 3 - absent_count()
	return KitResource.make(&"limbs", "Membres", 0.0, ACCENT,
		{"pips": 3, "filled": n, "blocked": false})


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
	present[&"leg_l"] = true # anciennes sauvegardes : les jambes ne partent plus
	present[&"leg_r"] = true
	for slot: int in queue:
		var q: Array = []
		for k in (d.get("queue", {}) as Dictionary).get(str(slot), []):
			if present.has(StringName(k)) and not present[StringName(k)] and _slot_of(StringName(k)) == slot:
				q.append(StringName(k))
		queue[slot] = q
		recharge_left[slot] = float((d.get("recharge_left", {}) as Dictionary).get(str(slot), 0.0)) if not q.is_empty() else 0.0
	for k: StringName in THROWN_KEYS: # membre absent sans recharge (sauvegarde incohérente) : rendu
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


## Le membre est-il en recharge (lancé et pas encore revenu) ?
func is_queued(key: StringName) -> bool:
	var slot := _slot_of(key)
	return slot != 0 and (queue[slot] as Array).has(key)


## Locomotion : toujours &"walk" (les jambes ne sont plus lancées, 23/10/2026).
func locomotion() -> StringName:
	return &"walk"


# --- Hooks du joueur et de SpellCaster ----------------------------------------------------------

## Aucun blocage : plus de jambes à bloquer sans bras, les charges épuisées passent par la recharge du SpellCaster.
func blocks_slot(_slot: int) -> bool:
	return false


func can_dodge() -> bool:
	return true


## Auto-cast (SpellCaster._auto_cast_ok, jamais en manuel) : la Tête automatique attend, tant qu'un pilier décharge, qu'au
## moins AUTO_PILLAR_MIN_HITS monstres s'y trouvent (le pilier finit en 5 s au plus). Le reste part tout de suite.
func auto_cast_ok(slot: int) -> bool:
	if slot != 4 or player == null or not player.is_inside_tree():
		return true
	if _time - _probe_t >= AUTO_PROBE_S:
		_probe_t = _time
		_probe_pillar_ok = true
		for l: TocsinLimb in _pillars():
			_probe_pillar_ok = false
			if l.count_inside() >= AUTO_PILLAR_MIN_HITS:
				_probe_pillar_ok = true
				break
	return _probe_pillar_ok


## SpellCaster.compute_damage : Tête-cloche renforcée sur les boss (+30 %) et sur les électrisés (+50 %), additifs.
func damage_add(s: SpellData, enemy: Node) -> float:
	if s.slot == 4 and s.id != V_FUMIGENE and is_instance_valid(enemy):
		var add := 0.0
		if enemy.is_in_group(&"bosses"):
			add += HEAD_BOSS_ADD
		if is_charged(enemy):
			add += HEAD_CHARGE_ADD
		return add
	return 0.0


## Monstre « électrisé » (étiquette posée par les ticks d'un pilier).
func is_charged(e: Node) -> bool:
	return is_instance_valid(e) and e.has_method(&"has_damage_taken_mod") and e.has_damage_taken_mod(CHARGE_TAG)


## SpellCaster.deal_damage : chiffre en accent et son lourd pour la Tête sur un électrisé.
func combo_hit(s: SpellData, enemy: Node) -> bool:
	return s.slot == 4 and s.id != V_FUMIGENE and is_charged(enemy)


## SpellCaster (aide de visée mobile) : les électrisés pèsent plus dans le paquet visé.
func is_marked(e: Node) -> bool:
	return is_charged(e)


## Fenêtre de combo (HUD : le bouton pulse) : Tête-cloche = un pilier en décharge à portée du lancer ; Coup de tocsin = un
## pilier (en décharge ou au sol) dans son onde. Sondé par SpellCaster toutes les 0,1 s ; ne boucle que sur les 2 bras.
func combo_ready(slot: int) -> bool:
	if player == null or (slot != 3 and slot != 4):
		return false
	var s := _spell_of(slot)
	if s == null:
		return false
	var zone: float = 1.0 + float(player.stat(&"zone_size_add"))
	for l: TocsinLimb in _pillars(slot == 3):
		var d := l.global_position.distance_to(player.global_position)
		if slot == 3 and d <= TOLL_RADIUS_U * zone * Balance.UNIT_PX:
			return true
		if slot == 4 and s.id != V_FUMIGENE and l.phase == TocsinLimb.Phase.PILLAR \
				and d <= _range_px(s) + HEAD_RADIUS_U * zone * Balance.UNIT_PX:
			return true
	return false


## Bras-pilier en jeu : en décharge, et (`with_ground`) au sol.
func _pillars(with_ground := false) -> Array:
	var out: Array = []
	for key in [&"arm_l", &"arm_r"]:
		var l := _limb(key)
		if l != null and l.kind == &"arm" and (l.phase == TocsinLimb.Phase.PILLAR or (with_ground and l.phase == TocsinLimb.Phase.GROUND)):
			out.append(l)
	return out


## Aucune perte de vitesse liée aux membres lancés (23/10/2026).
func speed_mult() -> float:
	return 1.0


func dodge_distance_u() -> float:
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


func on_dodge_start(dir: Vector2) -> void:
	_ghost_t = 0.0
	_steam_burst(dir)


func dodge_label() -> String:
	return "Vapeur"


func dodge_sound() -> Array:
	return DODGE_SOUND


## Nuage de vapeur au départ : anneau (TocsinSteamFx) et ralentissement des monstres à portée.
func _steam_burst(dir: Vector2) -> void:
	if player == null:
		return
	var r := STEAM_RADIUS_U * Balance.UNIT_PX
	TocsinSteamFx.spawn(player.get_parent(), player.global_position, TocsinSteamFx.Mode.RING, r, dir, STEAM_S)
	if not player.is_inside_tree():
		return
	var in_pillar := false # dans un pilier en décharge : les électrisés ralentissent à 50 % au lieu de 30 %
	for l: TocsinLimb in _pillars():
		if l.global_position.distance_to(player.global_position) <= l.radius_px:
			in_pillar = true
			break
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and e.has_method(&"apply_status") \
				and (e as Node2D).global_position.distance_to(player.global_position) <= r:
			var pct := STEAM_CHARGED_SLOW_PCT if in_pillar and is_charged(e) else STEAM_SLOW_PCT
			e.apply_status(&"slow", {"pct": pct, "duration": STEAM_SLOW_S})


func cast_spell(s: SpellData, aim: Variant) -> bool:
	if player == null or player.dead:
		return false
	if s.id == V_VAPEUR:
		return _cast_vapeur(s)
	if s.slot == 3:
		return _cast_toll(s)
	var key := _next_limb(s.slot)
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
		_launch(pend)
	_refresh_state()
	return true


## Ordre des charges : gauche puis droite.
func _next_limb(slot: int) -> StringName:
	for k: StringName in SLOT_LIMBS.get(slot, []):
		if present[k]:
			return k
	return &""


## Les anims de lancer (throw_arm_*, throw_head) sont rendues debout : toujours disponibles, jambes présentes.
func _has_throw_anim() -> bool:
	return true


## Ciblage automatique (tactile, stick au repos) : le paquet le plus dense à portée (SpellCaster, S5).
func _auto_target(s: SpellData) -> Variant:
	var c := _caster()
	return c.densest_point(_range_px(s)) if c != null else null


func _range_px(s: SpellData) -> float:
	return s.range_u * Balance.UNIT_PX * (1.0 + player.stat(&"range_add"))


func _cooldown(s: SpellData) -> float:
	var m: float = player.stat(&"cooldown_mult")
	return Balance.effective_cooldown(s.base_cooldown, m if m > 0.0 else 1.0)


## Anim d'action (Player.play_action) : throw_<membre> pour les bras et la tête, `cast` pour le Coup de tocsin ;
## `attack` pour les rivets seulement à l'arrêt, sans autre action en cours (en marche, le corps continue de marcher).
func action_for(s: SpellData) -> StringName:
	if s.slot == 1:
		if not player.is_moving and player.action_base() == &"":
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
	l.phase = TocsinLimb.Phase.FLY
	l.start = player.global_position
	var aim: Vector2 = pend["aim"]
	l.target = player.global_position + (aim - player.global_position).limit_length(_range_px(s))
	var zone: float = 1.0 + player.stat(&"zone_size_add")
	match s.slot:
		2:
			l.kind = &"arm"
			l.radius_px = PILLAR_RADIUS_U * zone * Balance.UNIT_PX
		4:
			l.kind = &"head"
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


## Membre au sol ramassé (contact) : il se rattache TOUT DE SUITE, dans la frame du contact.
## Cause racine du retour du 23/10/2026 : l'ancien code ne rendait pas le membre, il se contentait de raccourcir
## la recharge restante de 50 % (PICKUP_CD_REFUND) après un délai de pose de 0,8 s ; le bras ne revenait donc que
## quand la recharge finissait. Maintenant : sortie de la file de recharge, présence, calque, charge du bouton et
## recharge du SpellCaster recalés dans le même appel (pas de délai, pas de seconde action).
func collect_limb(l: TocsinLimb) -> void:
	if l == null or player == null or player.dead:
		return
	var key := l.key
	l.queue_free()
	limbs.erase(key)
	var slot := _slot_of(key)
	var lock := 0.0
	if slot != 0:
		var q: Array = queue[slot]
		var idx := q.find(key)
		if idx >= 0:
			if charges(slot) == 0: # audit P7 : sans charge en main, la recharge restante de ce bras n'est rendue qu'à moitié
				lock = (float(recharge_left[slot]) + idx * _cooldown(_spell_of(slot))) * (1.0 - PICKUP_CD_REFUND)
				lock = maxf(lock, 0.0)
			q.remove_at(idx)
			if q.is_empty():
				recharge_left[slot] = 0.0
			# tête de file retirée : le suivant reprend le temps restant (il ne repart pas de zéro)
	if not bool(present[key]):
		_regen(key)
	if lock > 0.0:
		_pickup_lock[slot] = maxf(float(_pickup_lock[slot]), lock)
	_sync_caster()
	Audio.play(&"pickup.coin", player.global_position, -6.0, 0.7)


## Explosion de la tête : lumière, secousse, gerbes (TOP au sol + CREA volumique).
func on_head_blast(l: TocsinLimb, at: Vector2) -> void:
	limbs.erase(l.key)
	LightRig.flash(at, &"tocsin_blast", 0.7)
	Audio.play(&"enemy.shockwave.heavy", at, 2.0, 0.8)
	_shake(HEAD_SHAKE_PX)
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


# --- Bras-pilier : retours du membre ----------------------------------------------------------------

## Le pilier se plante : lumière, secousse légère (la décharge et ses ticks sont tenus par le membre).
func on_pillar_planted(_l: TocsinLimb, at: Vector2) -> void:
	LightRig.flash(at, &"tocsin_limb", 0.5)
	_shake(HEAD_SHAKE_PX * 0.4)


## Un tick de décharge : petit éclat de lumière au pied du pilier.
func on_pillar_tick(_l: TocsinLimb, at: Vector2) -> void:
	LightRig.flash(at, &"tocsin_limb", 0.25)


# --- Sort 3 : Coup de tocsin ------------------------------------------------------------------------

## Onde de choc autour de Tocsin : coef 2,5 à tout monstre dans 3 u (+ zone_size_add), poussée 2,5 u × masse.
## Rien à portée en auto : pas de lancer (le sort auto ne consomme rien) ; en manuel il sonne même à vide.
func _cast_toll(s: SpellData) -> bool:
	var c := _caster()
	if c == null:
		return false
	var zone: float = 1.0 + player.stat(&"zone_size_add")
	var r: float = TOLL_RADIUS_U * zone * Balance.UNIT_PX
	var at := player.global_position
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		if (e as Node2D).global_position.distance_to(at) > r + TocsinLimb._radius_of(e) * 0.5:
			continue
		c.deal_damage(e, s, {"source_pos": at})
		if TocsinLimb._alive(e) and not TocsinLimb._is_boss(e):
			var away: Vector2 = (e as Node2D).global_position - at
			TocsinLimb._push(e, (away.normalized() if away.length_squared() > 1.0 else Vector2.RIGHT) * TOLL_PUSH_U)
	for l: TocsinLimb in _pillars(true): # le Coup qui fait sonner : décharge en plus, ticks en plus, bras au sol redressé
		if l.global_position.distance_to(at) <= r:
			l.toll_hit()
	if _visual != null and _resolve("cast") != &"":
		_last_action = &"cast"
	TocsinSteamFx.spawn(player.get_parent(), at, TocsinSteamFx.Mode.WAVE, r, Vector2.RIGHT, 0.3)
	LightRig.flash(at, &"tocsin_blast", 0.4)
	Audio.play(&"enemy.shockwave.heavy", at, -4.0, 1.25) # la cloche sonne
	_shake(TOLL_SHAKE_PX)
	return true


func _shake(px: float) -> void:
	var n := player.get_parent()
	while n != null and not n.has_method(&"shake"):
		n = n.get_parent()
	if n != null:
		n.shake(px, 18.0, 0.3)


# --- Variantes : Vapeur, Tête-fumigène ----------------------------------------------------------------

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
	_time += delta
	for slot: int in queue:
		_recharge_step(slot, delta)
		_pickup_lock[slot] = maxf(float(_pickup_lock[slot]) - delta, 0.0)
	_sync_caster()
	if _kick_left > 0.0:
		_kick_left = maxf(_kick_left - delta, 0.0)
	_update_overheat()
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
			l.expire() # le membre au sol part en braises ; un pilier en décharge finit d'abord
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
		var lock := float(_pickup_lock.get(slot, 0.0))
		if lock > want: # ramassage bridé (P7) : le sort ne repart qu'après ce délai, même avec un bras en main
			want = lock
			if r < want - 0.001:
				c.set_cooldown(slot, want, want)
				r = want
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
		s2.range_u = PILLAR_RANGE_U if head else PILLAR_RANGE_HEADLESS_U
		s2.trigger_range_u = s2.range_u


## Hitbox, calques visibles, vignette après un changement de membres.
func _refresh_state() -> void:
	if player == null:
		return
	player.set_hitbox_u(HITBOX_U)
	if layers != null:
		for k: StringName in ALL_KEYS:
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


## Anim du corps (Player._update_visual) : l'anim d'action en cours, sinon marche / repos (jambes toujours là).
## `fallback` = anim d'action ou idle/run_<dir> d'Ardent : run devient walk.
func visual_anim(fallback: StringName) -> StringName:
	if _visual == null or _visual.sprite_frames == null or not _visual.sprite_frames.has_animation(&"walk_s"):
		return fallback # repli Ardent teinté : ses anims idle/run
	if player.action_anim() != &"" and fallback == player.action_anim():
		return fallback
	var a := _resolve("walk" if player.is_moving else "idle")
	return a if a != &"" else fallback


# --- Nettoyage (étage, mort) ----------------------------------------------------------------------

func clear_transients() -> void:
	_pending.clear()
	for slot: int in _pickup_lock:
		_pickup_lock[slot] = 0.0
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
		"Les bras et la tête de Tocsin sont des armes : il les lance, ils reviennent. Les pastilles du HUD montrent ceux qui sont sur le robot. Ses jambes ne partent jamais, il court toujours à pleine vitesse.",
		"un bras lancé revient dès que tu marches dessus (même quand le pilier a fini de décharger), sinon quand la recharge de son sort est finie. Un seul membre se recharge à la fois par sort.",
		"un membre lancé n'est plus sur le robot tant que sa recharge court ; sans tête, ta visée est plus courte.",
		"Surchauffe : +%s de vitesse d'attaque par membre absent, et le foyer brille plus fort. La tête sonne +%s sur les boss." % [
			KitResource.pct(OVERHEAT_PER_LIMB), KitResource.pct(HEAD_BOSS_ADD)])
