class_name RictusKit
extends Node
## Kit de Rictus, pantin de la barge noyée (docs/Design_Personnages.md §2.6, refonte docs/Design_Rictus_v2.md option 1
## « Le fil et la lame », 31/10/2026) : 4 sorts / 0 passif, le Montreur (fantôme) est un trait intégré.
## Données : character(). Logique d'état : ce nœud, enfant « Kit » du joueur (CharacterData.kit_script) ;
## le joueur et SpellCaster l'interrogent par des hooks (blocks_slot, cast_spell, speed_mult, inertia_s, slow_immune,
## can_dodge, visual_anim, auto_cast_ok, combo_ready, on_spell_hit…).
## - Sort 1 Dagues en demi-lune : SpellData ARC (SpellCaster), vers l'ennemi le plus proche, jamais le curseur ;
##   chaque coup sur le monstre ficelé enroule un tour de fil (TOUR_MAX).
## - Sort 2 Couteau ficelé : un seul couteau lourd (RictusPendulum), lancé à KNIFE_RANGE_U, planté dans le premier monstre
##   touché (« ficelé » FICELE_S, un seul à la fois) ; le fil scie toutes les SAW_TICK_S tant que le monstre est à
##   <= FICELE_RANGE_U (et hors mur). Grisé tant que le couteau n'est pas en main.
## - Sort 3 Saccade (3 s) : le couteau s'arrache (1,4 + 0,25 par tour), revient en ligne (0,6 à tout monstre traversé),
##   le sort 2 est prêt au rattrapage ; un non-boss ficelé est tiré de 1,5 u ; les Doublures posées explosent
##   (+30 % si une cible est ficelée). Grisée tant que le couteau est en main.
## - Sort 4 Les Doublures : 6 leurres Decoy (S14) en hexagone autour du ficelé (sinon du point visé, du paquet, de soi).
## - Variantes : Éventail (slot 2, l'ancien sort de base), Toupie (slot 3, l'ancien sort de base, étoile comprise),
##   Main du Montreur (slot 1), Rideau (slot 4).
## - Roulade = levée : même dash que la roulade (Balance.DODGE_*), pantin soulevé de LIFT_HEIGHT_U.
## - Fils tendus : +2 % PV max à la première explosion de chaque Doublures (et en fin de Toupie).
## Rendu : CompanionSprite (le Montreur) + StringRig (5 fils) ; assets M1-M3 absents = repli sur Ardent teinté.

# --- Assets attendus (lots Codex M2/M3) : chemins et noms d'anims de §2.6.11 ----------------------
const ASSET_DIR := "res://assets/sprites/characters/rictus/"
const MONTREUR_DIR := "res://assets/sprites/characters/montreur/"
const SPRITE_FRAMES := ASSET_DIR + "rictus.tres" ## idle/run/slash/throw/stagger/summon/lift/death _<dir> ; spin (1 dir)
const MONTREUR_FRAMES := MONTREUR_DIR + "montreur.tres" ## hover_<dir>, pull_<dir>
const STRINGS_MANIFEST := ASSET_DIR + "strings.json" ## points d'attache des fils (format : StringRig)
const STRING_TEXTURE := MONTREUR_DIR + "string_tile/string_tile.png"
const KNIFE_FRAMES := ASSET_DIR + "knife/knife.tres" ## anim `default`, pointe vers +X (couteaux légers de l'Éventail)
const KNIFE_PLANTED_FRAMES := ASSET_DIR + "knife_planted/knife_planted.tres" ## `default_<dir>`
## Demi-lune au sol (lot M3, rig TOP 128 px/u, 4 frames, arc centré sur +X, Rictus au centre de la frame) ;
## absente = croissant dessiné par ZoneEffect. Rayon de l'arc dans la frame : 2,5 u × 128 px.
const DAGGER_ARC_FRAMES := ASSET_DIR + "dagger_arc/dagger_arc.tres"
const DAGGER_ARC_RADIUS_PX := 320.0
## Explosion des doublures (lot M3, anim `default` = vue TOP 128 px/u, 6 frames non bouclées) : l'anneau
## final de la gerbe est à 1,92 u = 246 px du centre, calé sur le rayon réel de l'explosion (2 u + zone_size_add).
const DOUBLE_BURST_FRAMES := ASSET_DIR + "double_burst/double_burst.tres"
const DOUBLE_BURST_RADIUS_PX := 246.0
## Traînée de la toupie (lot M3, CREA 4 frames en boucle, additive, même échelle que le pantin, 90,5 px/u),
## enfant du sprite du pantin, centrée à 0,48 u au-dessus des pieds (= décalage du pivot, 40,32 px).
const SPIN_BLUR_FRAMES := ASSET_DIR + "spin_blur/spin_blur.tres"
const SPIN_BLUR_OFFSET := Vector2(0, -40.32)
const SPIN_BLUR_ALPHA := 0.55 ## teinte argent spectral (accent unique), discrète : le pantin reste lisible dessous
const PLACEHOLDER_TINT := Color(0.78, 0.66, 0.6) ## Ardent teinté bois verni / porcelaine, en attendant M2

# --- Rendu (retour joueur : fils fins et discrets, fantôme lisible) --------------------------------
const MONTREUR_LIFT_U := 1.4
const MONTREUR_ALPHA := 0.8
const STRING_COLOR := Color("#9FC8C0")
const STRING_ALPHA := 0.2 ## retour joueur : fils plus transparents (0,35 -> 0,2)
const STRING_GLOW := 1.25 ## légère lueur : couleur HDR (glow de l'étalonnage)
const STRING_WIDTH_SCREEN_PX := 1.0
const STRING_VIBRATE_S := 0.2

# --- Gameplay (§2.6.3, §2.6.7) --------------------------------------------------------------------
const HITBOX_U := 0.45
const SPIN_HITBOX_U := 0.5
const SPIN_SPEED_U := 4.8 ## 4,2 × (4,8 / 4,2) : la toupie glisse à 4,8 u/s de base
const SPIN_INERTIA_S := 0.3
const SPIN_TICK_S := 0.25
const SPIN_KNOCK_U := 0.3
const STAGGER_S := 0.3
const STAGGER_SPEED_MULT := 0.5
const HEAL_PCT := 0.02
const LIFT_HEIGHT_U := 0.8
const ARC_KNOCK_U := 0.2
const KNIFE_LIFE_S := 4.0 ## couteau planté au sol (Éventail) : durée de vie
const KNIFE_CONTACT_U := 0.6
const KNIFE_REFUND_S := 1.0
const KNIFE_REFUND_CAP_S := 5.0 ## par salve
const DECOY_COUNT := 6
const DECOY_RING_U := 1.2
const DECOY_HP_FRAC := 0.2
const DECOY_LIFE_S := 3.0
const DECOY_BURST_U := 2.4 ## rayon d'explosion de chaque doublure (2,0 -> 2,4 u, retour joueur 26/10)
const DECOY_DEATH_FRAC := 0.6
const DECOY_BLOCK_PUSH_U := 0.5
const FLIGHT_COEF := 1.2 ## vol d'une doublure expédiée par la Toupie (variante)
const ARC_COEF := 0.8 ## demi-lune 0,6 -> 0,8
const FAN_COEF := 1.35 ## Éventail (variante) : par couteau
## Refonte v2 (docs/Design_Rictus_v2.md §3.9) ----------------------------------------------------------------------
const KNIFE_COEF := 1.5 ## impact du couteau lourd
const KNIFE_RANGE_U := 8.0
const KNIFE_SPEED_U := 14.0
const KNIFE_KNOCK_U := 0.3
const KNIFE_RECAST_S := 1.0 ## anti-spam : le vrai verrou est « couteau en main »
const KNIFE_REMAKE_S := 6.0 ## couteau perdu : le Montreur en refait un (6 s après sa chute)
const FICELE_S := 5.0 ## fenêtre du combo
const FICELE_RANGE_U := 9.0 ## longueur du fil
const FICELE_RANGE_CAP_U := 30.0 ## plafond de la longueur du fil avec les bonus de portée (et la portée infinie du mode test)
const FICELE_POLL_S := 0.25 ## sondage de la distance et des murs (jamais une boucle par image)
const SAW_COEF := 0.22
const SAW_TICK_S := 0.5
const SAW_PROC := 0.3
const TOUR_MAX := 3
const SACCADE_CD := 3.0
const SACCADE_COEF := 1.0
const SACCADE_TOUR_ADD := 0.25
const SACCADE_PULL_U := 1.5
const SACCADE_KNOCK_U := 0.5
const SACCADE_LINE_COEF := 0.6 ## retour du couteau, perce tout
const SACCADE_LINE_KNOCK_U := 0.2
const DECOY_COEF := 1.8 ## 2,2 -> 1,8 (compensation du monocible)
const DECOY_FICELE_MULT := 1.3 ## détonées par la Saccade avec une cible ficelée
const DECOY_THROW_RANGE_U := 7.0
const DECOY_AUTO_RANGE_U := 6.0
const DECOY_AUTO_NEAR_U := 3.0
const DECOY_AUTO_PACK_N := 3 ## ficelé entouré de >= 3 monstres (à DECOY_BURST_U) : ultime auto
const AUTO_PLANT_S := 2.0 ## Saccade auto : couteau planté depuis >= 2,0 s
const AUTO_STRING_LIMIT_U := 8.5 ## Saccade auto : le ficelé sort de 8,5 u (le fil va casser)
const AUTO_DECOYS_S := 1.5 ## Saccade auto : doublures posées depuis >= 1,5 s et une cible ficelée
const COUNTER_CLOSE := "rictus.close_kills" ## monstres tués à moins de CLOSE_KILL_U (déblocage Toupie)
const CLOSE_KILL_U := 2.0
## Sons de repli (rien de dédié livré) : Saccade ~ claquement d'un sort existant, plantage ~ grelot grave.
const SND_SACCADE := &"rictus_saccade" ## variantes `spell.rictus_saccade.cast_light|medium|heavy` (Audio.play_cast)
const SND_PLANT := &"rictus_knife_plant"
## Combo « L'étoile armée » (variantes Éventail + Toupie ; docs/Design_Combos.md §5.1) : Doublures -> Éventail (les couteaux
## chargent les doublures traversées) -> Toupie (les chargées expédiées font FLIGHT_CHARGED_COEF en vol et DECOY_CHARGE_ADD de plus).
const DECOY_CHARGE_ADD := 0.7 ## coef ajouté à l'explosion d'une doublure chargée
const FLIGHT_CHARGED_COEF := 1.6 ## coef en vol d'une doublure chargée (1,2 sinon)
const CHARGE_MAX_PER_SALVE := 3 ## doublures chargées par salve d'Éventail (2-3 selon la géométrie)
const FAN_WATCH_S := 0.7 ## durée de surveillance des couteaux après le lancer (portée 7 u à 14 u/s = 0,5 s)
const KNIFE_CHARGE_PAD_U := 0.2 ## rayon du couteau : marge de passage sur une doublure (une salve de 5 couteaux sur 60° charge 3 doublures)
## Esquive Levée : atterrir à cette distance de doublures en attente les détone tout de suite (aucun dégât en plus).
const LIFT_DETONATE_U := 2.4
## Garde du Montreur : après chaque demi-lune, les fils tirent le pantin hors des coups (−30 % de dégâts subis
## pendant GUARD_S). La mêlée garde son risque hors attaque (déplacement, vertige).
## Pointe de la toupie (variante) : à chaque tick, un coup supplémentaire frappe l'ennemi le plus proche.
const TOUPIE_FOCUS_COEF := 0.15
const TOUPIE_FOCUS_RADIUS_U := 0.9
const TOUPIE_COEF := 0.42 ## Toupie, par tick
const GUARD_TAKEN_MULT := 0.7
const GUARD_S := 0.3 ## équilibrage 23/10 : 0,5 -> 0,35 -> 0,3
const FLIGHT_PROC := 0.5
## Anims d'action (Player.play_action) : slash à chaque demi-lune (anim complète), throw (couteau, Éventail),
## summon (Doublures, posées à la frame d'impact). Frames d'impact (index 0) des anims de rictus.tres.
## Lot M2b : `throw_ult` (6 frames × 8 dir, impact frame 3) remplace `summon` pour les Doublures (bras lancés
## vers l'extérieur, tirés par les fils) ; `summon` reste le repli si throw_ult n'est pas livrée.
## `catch` (Saccade, 4 frames × 8 dir) : pas encore livrée -> repli `throw`.
const ACTION_IMPACT_FRAMES := {&"slash": 1, &"throw": 2, &"summon": 3, &"throw_ult": 3, &"catch": 2}
const ULT_ACTIONS: Array[StringName] = [&"throw_ult", &"summon"]
const WALL_MASK := 1

# --- Variantes de sorts (docs/Variantes_Sorts.md §2.2 ; contrat CONTRACTS.md « Variantes de sorts ») ---------
const V_MAIN := &"rictus_main_du_montreur" ## slot 1 (remplace les Dagues en demi-lune)
const V_EVENTAIL := &"rictus_eventail" ## slot 2 (remplace le Couteau ficelé)
const V_TOUPIE := &"rictus_toupie" ## slot 3 (remplace la Saccade)
const V_RIDEAU := &"rictus_rideau" ## slot 4 (remplace Les Doublures)
const ID_KNIFE := &"couteau_ficele"
const ID_SACCADE := &"rictus_saccade"
const COUNTER_KNIVES := "rictus.knives_picked" ## couteaux plantés ramassés ou rappelés (déblocage Éventail)
const VAR_DIR := ASSET_DIR + "variants/" ## VFX des variantes (lot Codex RICV), absents = replis dessinés
## Main du Montreur : claquement au sol sur le paquet le plus dense à portée.
const MAIN_RANGE_U := 4.0
const MAIN_RADIUS_U := 1.4
const MAIN_GUARD_U := 1.5 ## la garde ne vaut que si le claquement tombe à cette distance de Rictus
const MAIN_COEF := 1.3 ## doc 0,8 ; sim : le pilote tient 2,8 u et perd l'uptime de ses sorts de mêlée -> coef relevé
const MAIN_KNOCK_U := 0.2
## Rideau : 6 doublures en ligne perpendiculaire à la visée.
const RIDEAU_AHEAD_U := 2.0
const RIDEAU_SPACING_U := 1.0
const RIDEAU_LIFE_S := 6.0
const RIDEAU_HP_FRAC := 0.3
const RIDEAU_COEF := 1.5 ## 1,7 -> 1,5 (même rapport que la base 2,2 -> 1,8)
const RIDEAU_AIM_U := 8.0 ## sans visée manuelle : ennemi le plus proche à cette distance
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

## État du couteau lourd (table §3.4).
enum K { HAND, FLYING, PLANTED, GROUND, RETURNING, LOST }

var player: CharacterBody2D = null
var companion: CompanionSprite = null
var strings: StringRig = null
var knives: Array = [] ## GroundPickup plantés (Éventail)
var spin_left := 0.0
var stagger_left := 0.0
var lifting := false
var kstate: K = K.HAND
var knife: RictusPendulum = null ## couteau lourd en vol / planté / au sol / en retour
var ficele: Node2D = null ## monstre ficelé (kstate PLANTED)
var tours := 0 ## tours de fil enroulés sur le ficelé
var _ficele_t := 0.0 ## s restantes de la fenêtre
var _saw_n := 0 ## ticks de scie déjà portés
var _poll_t := 0.0
var _planted_age := 0.0
var _since_drop := 0.0
var _clock := 0.0
var _decoys_landed_at := -100.0
var _knife_spell: SpellData = null ## sort 2 lancé (copie de base des coups de scie et de retour)
var _heavy := true ## sort 2 équipé = Couteau ficelé (sinon Éventail)
var _sacc := true ## sort 3 équipé = Saccade (sinon Toupie)
var _spin_elapsed := 0.0
var _spin_ticks := 0
var _spin_total := 2.5
var _spin_tick_spell: SpellData = null
var _spin_focus_spell: SpellData = null
var _pending_decoys := {} ## Doublures lancées, posées à la frame d'impact de `summon` : {spell, aim, center}
var _visual: AnimatedSprite2D = null
var guard_left := 0.0 ## garde du Montreur après une demi-lune
var spin_blur: AnimatedSprite2D = null ## traînée additive pendant la toupie (null sans asset)
var _fan_watch := 0.0 ## s restantes de surveillance des couteaux de l'Éventail (charge des doublures)
var _salve_charged := 0 ## doublures déjà chargées par la salve en cours


# --- Données -------------------------------------------------------------------------------------

## Recul imposé (u) -> force de coup (Balance.knockback_px est linéaire entre KB_MIN_U et KB_MAX_U).
static func _force_for(knock_u: float) -> float:
	return clampf(inverse_lerp(Balance.KB_MIN_U, Balance.KB_MAX_U, knock_u), 0.0, 1.0)


static func _spell(sid: StringName, name: String, slot: int, behavior: SpellData.Behavior, coef: float, cd: float) -> SpellData:
	var s := SpellData.new()
	s.id = sid
	s.display_name = name
	s.slot = slot
	s.behavior = behavior
	s.coef = coef
	s.base_cooldown = cd
	s.element = &"physical"
	s.color = STRING_COLOR
	s.light_preset = &"spell_steel" ## argent spectral (accent unique), jamais la braise d'Ardent
	return s


static func character() -> CharacterData:
	var c := CharacterData.new()
	c.id = &"rictus"
	c.display_name = "Rictus"
	c.base_hp = 95.0
	c.hp_per_level = 28.0
	c.armor = 10.0
	c.base_regen = 0.6
	c.regen_per_level = 0.12
	c.base_speed_u = 4.2
	c.hitbox_u = HITBOX_U
	c.kit_script = RictusKit
	c.sprite_frames_path = SPRITE_FRAMES
	c.placeholder_tint = PLACEHOLDER_TINT
	c.body_color = Color("#7A3B24")
	c.accent_color = STRING_COLOR
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"dagues_demi_lune", "Dagues en demi-lune", 1, SpellData.Behavior.ARC, ARC_COEF, 0.6)
	s1.is_auto = true
	s1.is_zone = false # audit P3 : l'auto ne cumule pas zone_damage_add (comme les autos d'Ardent et de Tocsin)
	s1.range_u = 3.0 # retour joueur 23/10 : portée de l'auto 2,5 -> 3,0 u (le VFX se met à l'échelle : k = rayon / DAGGER_ARC_RADIUS_PX)
	s1.radius_u = 3.0
	s1.spread_deg = 180.0
	s1.proc_coef = 0.8
	s1.hit_force = _force_for(ARC_KNOCK_U)
	s1.vfx_frames = DAGGER_ARC_FRAMES
	s1.vfx_radius_px = DAGGER_ARC_RADIUS_PX
	s1.vfx_floor_aspect = 1.0 # rig TOP : jamais pré-écrasé

	var s2 := _spell(ID_KNIFE, "Couteau ficelé", 2, SpellData.Behavior.KIT, KNIFE_COEF, KNIFE_RECAST_S)
	s2.range_u = KNIFE_RANGE_U
	s2.speed_u = KNIFE_SPEED_U
	s2.is_zone = false
	s2.item_pierce = false # Pointe perforante : sort 1 seulement
	s2.proc_coef = 0.8
	s2.hit_force = _force_for(KNIFE_KNOCK_U)
	s2.trigger_range_u = KNIFE_RANGE_U

	var s3 := _spell(ID_SACCADE, "Saccade", 3, SpellData.Behavior.KIT, SACCADE_COEF, SACCADE_CD)
	s3.is_zone = false
	s3.item_pierce = false
	s3.proc_coef = 0.8
	s3.hit_force = _force_for(SACCADE_KNOCK_U)
	s3.trigger_range_u = FICELE_RANGE_U

	var s4 := _spell(&"doublures", "Les Doublures", 4, SpellData.Behavior.DECOYS, DECOY_COEF, 20.0)
	s4.radius_u = DECOY_BURST_U
	s4.duration = DECOY_LIFE_S
	s4.proc_coef = 1.0
	s4.trigger_range_u = KNIFE_RANGE_U ## le filtre fin est dans auto_cast_ok(4)
	s4.hit_force = 1.0

	c.spells = [s1, s2, s3, s4]
	return c


## Variantes (contrat CONTRACTS.md) : SpellData de la variante `variant_id` pour `slot`, ou null (non codée).
## Coefficients ajustés par balance_sim (±15 % du sort de base en DPS cible et zone) ; le style ne change pas.
static func variant(slot: int, variant_id: StringName) -> SpellData:
	match [slot, variant_id]:
		[1, V_MAIN]:
			var s1 := _spell(V_MAIN, "Main du Montreur", 1, SpellData.Behavior.KIT, MAIN_COEF, 0.6)
			s1.is_auto = true
			s1.range_u = MAIN_RANGE_U
			s1.trigger_range_u = MAIN_RANGE_U
			s1.radius_u = MAIN_RADIUS_U
			s1.proc_coef = 0.8
			s1.hit_force = _force_for(MAIN_KNOCK_U)
			s1.vfx_frames = VAR_DIR + "montreur_hand_slam/montreur_hand_slam.tres"
			s1.vfx_radius_px = MAIN_RADIUS_U * 128.0 # rig TOP 128 px/u
			s1.vfx_floor_aspect = 1.0
			return s1
		[2, V_EVENTAIL]: # l'ancien sort de base : 5 couteaux légers, multi-cible au lieu du monocible
			var s2 := _spell(V_EVENTAIL, "Éventail", 2, SpellData.Behavior.FAN, FAN_COEF, 6.0)
			s2.count = 5
			s2.spread_deg = 60.0
			s2.speed_u = 14.0
			s2.range_u = 7.0
			s2.pierce = 1
			s2.item_pierce = false # Pointe perforante : sort 1 seulement
			s2.is_zone = false
			s2.proc_coef = 0.8
			s2.rests_on_ground = true
			s2.target_mode = &"densest"
			s2.trigger_range_u = 6.0
			s2.projectile_frames = KNIFE_FRAMES
			return s2
		[3, V_TOUPIE]: # l'ancien sort de base : tourne 2,5 s invulnérable, pousse les doublures en étoile
			var s3 := _spell(V_TOUPIE, "Toupie", 3, SpellData.Behavior.SPIN, TOUPIE_COEF, 8.0)
			s3.radius_u = 2.2 # retour joueur : toupie plus large (1,5 -> 2,2 u)
			s3.duration = 2.5
			s3.tick = SPIN_TICK_S
			s3.proc_coef = 0.3
			s3.trigger_range_u = 2.5
			s3.hit_force = _force_for(SPIN_KNOCK_U)
			return s3
		[4, V_RIDEAU]:
			var s4 := _spell(V_RIDEAU, "Rideau", 4, SpellData.Behavior.DECOYS, RIDEAU_COEF, 20.0)
			s4.radius_u = DECOY_BURST_U
			s4.duration = RIDEAU_LIFE_S
			s4.proc_coef = 1.0
			s4.trigger_range_u = 3.0
			s4.hit_force = 1.0
			return s4
	return null


# --- Mise en place ------------------------------------------------------------------------------

func setup(p: CharacterBody2D) -> void:
	player = p
	refresh_equipment()
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	if _visual != null:
		companion = CompanionSprite.attach(p, _visual, MONTREUR_FRAMES, MONTREUR_LIFT_U, MONTREUR_ALPHA)
		var col := Color(STRING_COLOR.r * STRING_GLOW, STRING_COLOR.g * STRING_GLOW, STRING_COLOR.b * STRING_GLOW, STRING_ALPHA)
		strings = StringRig.attach(p, _visual, companion, STRINGS_MANIFEST, col,
				STRING_WIDTH_SCREEN_PX / Iso.camera_zoom().x, STRING_TEXTURE)
		_attach_spin_blur()
	Events.floor_started.connect(_on_floor_started)
	Events.player_died_by.connect(_on_player_died_by)
	Events.enemy_killed_by.connect(_on_enemy_killed_by)
	if p.has_signal(&"action_impact"):
		p.action_impact.connect(_on_action_impact)


## Quels sorts de base ou variantes sont équipés (Couteau ficelé / Éventail, Saccade / Toupie).
func refresh_equipment() -> void:
	var s2 := _spell_of(2)
	var s3 := _spell_of(3)
	_heavy = s2 == null or s2.id == ID_KNIFE
	_sacc = s3 == null or s3.id == ID_SACCADE


func _exit_tree() -> void:
	if Events.floor_started.is_connected(_on_floor_started):
		Events.floor_started.disconnect(_on_floor_started)
	if Events.player_died_by.is_connected(_on_player_died_by):
		Events.player_died_by.disconnect(_on_player_died_by)
	if Events.enemy_killed_by.is_connected(_on_enemy_killed_by):
		Events.enemy_killed_by.disconnect(_on_enemy_killed_by)
	clear_transients()


func _caster() -> SpellCaster:
	return player.spells if player != null else null


func _spell_of(slot: int) -> SpellData:
	if player == null or player.character == null:
		return null
	for s in player.character.spells:
		if s.slot == slot:
			return s
	return null


# --- Hooks du joueur et de SpellCaster ----------------------------------------------------------

func is_spinning() -> bool:
	return spin_left > 0.0


func is_staggered() -> bool:
	return stagger_left > 0.0


func knife_in_hand() -> bool:
	return kstate == K.HAND


## Monstre ficelé (couteau planté dedans), ou null.
func ficele_enemy() -> Node2D:
	return ficele if _ficele_valid() else null


## Table d'états §3.4 : le sort 2 exige le couteau en main, la Saccade exige qu'il soit planté (monstre ou sol).
func blocks_slot(slot: int) -> bool:
	if lifting:
		return true
	if spin_left > 0.0 and (slot == 1 or slot == 3):
		return true
	if stagger_left > 0.0 and slot == 3:
		return true
	if slot == 2 and _heavy and kstate != K.HAND:
		return true
	if slot == 3 and _sacc and not saccade_ready():
		return true
	return false


## Saccade utilisable : couteau lourd planté (dans un monstre ou au sol) ; avec l'Éventail : couteaux plantés au sol
## à rappeler ou doublures à détoner.
func saccade_ready() -> bool:
	if _heavy:
		return kstate == K.PLANTED or kstate == K.GROUND
	return not knives.is_empty() or _decoys_waiting()


## Retour joueur : la levée est permise pendant la Toupie (la toupie continue) ; seul le vertige l'interdit.
func can_dodge() -> bool:
	return stagger_left <= 0.0


func speed_mult() -> float:
	if spin_left > 0.0:
		return SPIN_SPEED_U / maxf(player.character.base_speed_u, 0.01)
	if stagger_left > 0.0:
		return STAGGER_SPEED_MULT
	return 1.0


func inertia_s() -> float:
	return SPIN_INERTIA_S if spin_left > 0.0 else 0.0


## Le Montreur tient la toupie droite : ralentissements ignorés (et non appliqués).
func slow_immune() -> bool:
	return spin_left > 0.0


## L'orientation pendant la demi-lune est tenue par l'anim d'action du joueur (Player.action_locks_facing).
func locks_facing() -> bool:
	return false


func dodge_ghosts() -> bool:
	return false # la levée se lit par le pantin soulevé, pas par des fantômes


func dodge_label() -> String:
	return "Levée"


func on_dodge_start(_dir: Vector2) -> void:
	lifting = true
	# au-dessus des monstres : masque sans la couche 3 (le joueur n'a déjà que le monde) ; les murs arrêtent
	player.collision_mask = WALL_MASK
	if strings != null:
		strings.tension = 1.0


func cast_spell(s: SpellData, aim: Variant) -> bool:
	match s.id:
		V_MAIN:
			return _cast_main(s)
		ID_KNIFE:
			return _cast_knife(s, aim)
		ID_SACCADE:
			return _cast_saccade(s)
	match s.behavior:
		SpellData.Behavior.SPIN:
			return _start_spin(s)
		SpellData.Behavior.DECOYS:
			_pending_decoys = {"spell": s, "aim": aim, "center": _decoy_fallback(aim)}
			return true
	return false


## Anim d'action de chaque sort (Player.action_base_for) ; la Toupie a ses propres anims d'état.
func action_for(s: SpellData) -> StringName:
	match s.behavior:
		SpellData.Behavior.ARC:
			return &"slash"
		SpellData.Behavior.KIT:
			if s.id == V_MAIN:
				return &"slash"
			if s.id == ID_KNIFE:
				return &"throw"
			if s.id == ID_SACCADE:
				return catch_action()
			return &""
		SpellData.Behavior.FAN:
			return &"throw"
		SpellData.Behavior.DECOYS:
			return ult_action()
	return &""


## Anim du rattrapage : `catch` si livrée (Codex), sinon `throw` (pas de lecture à l'envers : Player.play_action n'en a pas).
func catch_action() -> StringName:
	if _visual != null and _visual.sprite_frames != null:
		var sf := _visual.sprite_frames
		for a: StringName in [&"catch_s", &"catch"]:
			if sf.has_animation(a):
				return &"catch"
	return &"throw"


## Anim de lancement des Doublures : `throw_ult` (M2b) si livrée, sinon `summon`.
func ult_action() -> StringName:
	if _visual != null and _visual.sprite_frames != null:
		for a: StringName in ULT_ACTIONS:
			if _visual.sprite_frames.has_animation(StringName("%s_s" % a)) or _visual.sprite_frames.has_animation(a):
				return a
	return &"summon"


## Frame d'impact de `throw_ult` / `summon` : les doublures apparaissent (Player.action_impact).
func _on_action_impact(base: StringName) -> void:
	if base in ULT_ACTIONS and not _pending_decoys.is_empty():
		var pend := _pending_decoys
		_pending_decoys = {}
		if player != null and not player.dead:
			_spawn_decoys(pend["spell"], pend["aim"], pend.get("center", null))


## Doublures lancées mais pas encore posées (avant la frame d'impact).
func decoys_pending() -> bool:
	return not _pending_decoys.is_empty()


## Anims et orientation : Player.play_action (action_for) ; rien d'autre à faire au lancement.
func on_cast(s: SpellData) -> void:
	if s.slot == 1 and s.id != V_MAIN: # Main du Montreur : garde posée par _cast_main (conditionnelle)
		guard_left = GUARD_S
	if s.behavior == SpellData.Behavior.FAN and not Decoy.live.is_empty(): # Éventail : les couteaux chargent
		_fan_watch = FAN_WATCH_S
		_salve_charged = 0


## Hook Player.take_damage : garde du Montreur juste après une demi-lune.
func damage_taken_mult(_source: Node) -> float:
	return GUARD_TAKEN_MULT if guard_left > 0.0 else 1.0


## Coup de sort 1 sur le monstre ficelé : un tour de fil de plus (TOUR_MAX), le fil s'enroule autour du couteau.
func on_spell_hit(s: SpellData, enemy: Node, _amount: float) -> void:
	if s != null and s.slot == 1 and kstate == K.PLANTED and enemy == ficele and tours < TOUR_MAX:
		tours += 1
		if knife != null and is_instance_valid(knife):
			knife.tours = tours


## Couteau (Éventail) en fin de course (portée ou mur) : planté KNIFE_LIFE_S ; marcher dessus rend 1 s à l'Éventail.
func on_projectile_rest(s: SpellData, at: Vector2, group: Dictionary) -> void:
	if player == null or player.dead or player.get_parent() == null:
		return
	var g := GroundPickup.spawn(player.get_parent(), at, player, func(_g: GroundPickup) -> void:
		_collect_knife(s.slot, group), KNIFE_LIFE_S, KNIFE_CONTACT_U, KNIFE_PLANTED_FRAMES,
		_knife_facing(at))
	knives.append(g)
	g.tree_exiting.connect(func() -> void: knives.erase(g))


## Orientation du couteau planté (default_<dir>) : direction de vol approchée (du pantin vers le point de chute).
func _knife_facing(at: Vector2) -> Vector2:
	var d := at - player.global_position
	return d.normalized() if d.length_squared() > 1.0 else player.facing


func _collect_knife(slot: int, group: Dictionary) -> void:
	var left := KNIFE_REFUND_CAP_S - float(group.get("refunded", 0.0))
	if left <= 0.0 or _caster() == null:
		return
	group["refunded"] = float(group.get("refunded", 0.0)) + _caster().reduce_cooldown(slot, minf(KNIFE_REFUND_S, left))
	PlayerRef.state_of(player).add_counter(COUNTER_KNIVES)
	Audio.play(&"pickup.coin", player.global_position, -8.0, 1.6)


# --- Boucle (appelée par Player.tick, avant les sorts) -------------------------------------------

func tick(delta: float) -> void:
	_clock += delta
	guard_left = maxf(guard_left - delta, 0.0)
	if stagger_left > 0.0:
		stagger_left = maxf(stagger_left - delta, 0.0)
	if lifting and not player.is_dodging():
		lifting = false
	if spin_left > 0.0:
		_spin_step(delta)
	if _fan_watch > 0.0:
		_fan_watch -= delta
		_charge_by_knives()
	_knife_step(delta)
	_update_rig()


# --- Couteau ficelé (sort 2) -------------------------------------------------------------------------------------

## Cible du lancer sans visée (mobile, manette au repos, auto) : boss / mini-boss d'abord (priorité de visée de
## SpellCaster.nearest_enemy), sinon l'élite ou le T3 le plus proche, sinon le monstre le plus proche.
func _pick_target(range_px: float) -> Node2D:
	var c := _caster()
	if c == null:
		return null
	var best: Node2D = c.nearest_enemy(range_px)
	if best != null:
		var pr: Variant = best.get(&"aim_priority")
		if pr != null and float(pr) > 1.0:
			return best
	var pick: Node2D = null
	var pd := INF
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or e.get(&"active") == false:
			continue
		var tier: Variant = e.get(&"tier")
		if not (e.get(&"is_elite") == true or (tier != null and int(tier) >= 3)):
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d <= range_px and d < pd:
			pd = d
			pick = e
	return pick if pick != null else best


func _cast_knife(s: SpellData, aim: Variant) -> bool:
	var c := _caster()
	if c == null or kstate != K.HAND:
		return false
	var rng := c.range_px(s)
	var dir: Vector2 = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
	if aim != null and ((aim as Vector2) - player.global_position).length_squared() > 1.0:
		dir = ((aim as Vector2) - player.global_position).normalized()
	else:
		var tgt := _pick_target(rng)
		if tgt != null and (tgt.global_position - player.global_position).length_squared() > 1.0:
			dir = (tgt.global_position - player.global_position).normalized()
	var spd := s.speed_u * Balance.UNIT_PX * (1.0 + minf(player.stat(&"projectile_speed"), Balance.PROJECTILE_SPEED_BONUS_CAP))
	_knife_spell = s
	knife = RictusPendulum.launch(c, player, s, dir, spd, rng)
	knife.hand_fn = _hand_pos
	knife.planted_in.connect(_on_knife_planted)
	knife.dropped.connect(_on_knife_dropped)
	knife.caught.connect(_on_knife_caught)
	knife.expired.connect(_on_knife_expired)
	kstate = K.FLYING
	tours = 0
	player.facing = dir
	if strings != null:
		strings.vibrate(STRING_VIBRATE_S)
	return true


func _hand_pos() -> Vector2:
	if companion != null and is_instance_valid(companion):
		return companion.global_position
	return player.global_position + Vector2(0.0, Iso.lift_logical(MONTREUR_LIFT_U))


## Le couteau se plante dans `e` : ficelé FICELE_S (un seul à la fois), grelot.
func _on_knife_planted(e: Node2D) -> void:
	kstate = K.PLANTED
	ficele = e
	_ficele_t = FICELE_S
	_saw_n = 0
	_poll_t = FICELE_POLL_S
	_planted_age = 0.0
	tours = 0
	Audio.play(SND_PLANT, e.global_position, -3.0, 1.0)
	LightRig.flash(e.global_position, &"spell_steel", 0.15)


## Le couteau tombe au sol (bout de course, mur, fil cassé, cible morte, fin de la fenêtre).
func _on_knife_dropped(_at: Vector2, _lost: bool) -> void:
	kstate = K.GROUND
	ficele = null
	tours = 0
	_since_drop = 0.0
	if _heavy and not _sacc and knife != null and is_instance_valid(knife): # pas de Saccade : le Montreur le rappelle seul
		knife.recall(_line_spell(_knife_spell, KNIFE_COEF))
		kstate = K.RETURNING


func _on_knife_caught() -> void:
	knife = null
	ficele = null
	tours = 0
	kstate = K.HAND
	var c := _caster()
	if c != null:
		c.set_cooldown(2, 0.0, 1.0) # sort 2 prêt dans la même frame
	if strings != null:
		strings.vibrate(STRING_VIBRATE_S * 0.5)


func _on_knife_expired() -> void:
	knife = null
	kstate = K.LOST # le Montreur en refait un à KNIFE_REMAKE_S après la chute


func _ficele_valid() -> bool:
	return kstate == K.PLANTED and ficele != null and is_instance_valid(ficele) and ficele.is_inside_tree() \
			and ficele.get(&"active") != false


## Longueur du fil (px) : 9 u + le bonus de portée du lancer, plafonné.
func ficele_range_px() -> float:
	var extra := 0.0
	var s2 := _spell_of(2)
	if s2 != null and _caster() != null:
		extra = maxf(_caster().range_px(s2) / Balance.UNIT_PX - KNIFE_RANGE_U, 0.0)
	return minf(FICELE_RANGE_U + extra, FICELE_RANGE_CAP_U) * Balance.UNIT_PX


func _knife_step(delta: float) -> void:
	match kstate:
		K.PLANTED:
			_planted_age += delta
			_ficele_t -= delta
			if not _ficele_valid():
				return # le couteau retombe tout seul au prochain pas (cible morte ou disparue)
			var elapsed := FICELE_S - _ficele_t
			var due := mini(int((elapsed + 0.0001) / SAW_TICK_S), int(roundf(FICELE_S / SAW_TICK_S)))
			while _saw_n < due and _ficele_valid():
				_saw_n += 1
				_saw_tick()
			_poll_t -= delta
			if _poll_t <= 0.0 and _ficele_valid():
				_poll_t = FICELE_POLL_S
				_poll_ficele()
			if _ficele_t <= 0.0 and _ficele_valid() and knife != null and is_instance_valid(knife):
				knife.drop_at(ficele.global_position) # fenêtre finie : le couteau tombe au sol
		K.GROUND, K.LOST:
			_since_drop += delta
			if _since_drop >= KNIFE_REMAKE_S:
				if knife != null and is_instance_valid(knife):
					knife.queue_free()
				knife = null
				kstate = K.HAND
				var c := _caster()
				if c != null:
					c.set_cooldown(2, 0.0, 1.0)


## Fil trop tendu (au-delà de FICELE_RANGE_U) ou coupé par un mur : le couteau tombe là où est le monstre.
func _poll_ficele() -> void:
	if knife == null or not is_instance_valid(knife):
		return
	var too_far := ficele.global_position.distance_to(player.global_position) > ficele_range_px()
	if too_far or _wall_between(player.global_position, ficele.global_position):
		knife.drop_at(ficele.global_position)


func _wall_between(a: Vector2, b: Vector2) -> bool:
	if player == null or not player.is_inside_tree():
		return false
	var q := PhysicsRayQueryParameters2D.create(a, b, WALL_MASK, [player.get_rid()])
	return not player.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Point de `target` atteignable depuis `origin` sans traverser un mur (le dernier point libre devant le mur).
func _clip_to_wall(origin: Vector2, target: Vector2) -> Vector2:
	if player == null or not player.is_inside_tree():
		return target
	var q := PhysicsRayQueryParameters2D.create(origin, target, WALL_MASK, [player.get_rid()])
	var r := player.get_world_2d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return target
	var back := (origin - target).normalized() * 0.5 * Balance.UNIT_PX
	return (r["position"] as Vector2) + back


## Coup de scie sur le ficelé (public : tests ; la Toupie en porte un par tick).
func _saw_tick() -> void:
	var c := _caster()
	if c == null or not _ficele_valid() or not StageMap.los(player.get_tree(), player.global_position, ficele.global_position):
		return
	var base := _knife_spell if _knife_spell != null else _spell_of(2)
	if base == null:
		return
	var sp := base.duplicate() as SpellData
	sp.coef = base.coef * SAW_COEF / KNIFE_COEF
	sp.proc_coef = SAW_PROC
	sp.hit_force = 0.0
	sp.is_zone = false
	var at := ficele.global_position
	c.deal_damage(ficele, sp, {"source_pos": player.global_position})
	LightRig.flash(at, &"spell_steel", 0.1)
	Audio.play(&"pickup.coin", at, -12.0, 2.0) # grelot de chaque tick de scie


## Sort du retour du couteau (0,6 à tout monstre traversé), calé sur le sort `base` (écho, items).
func _line_spell(base: SpellData, base_coef: float) -> SpellData:
	var sp: SpellData = (base if base != null else _spell_of(2)).duplicate() as SpellData
	sp.coef = SACCADE_LINE_COEF * sp.coef / base_coef
	sp.proc_coef = 0.8
	sp.hit_force = _force_for(SACCADE_LINE_KNOCK_U)
	sp.is_zone = false
	return sp


# --- Saccade (sort 3) -------------------------------------------------------------------------------------------

func _decoys_waiting() -> bool:
	for d in Decoy.live:
		if is_instance_valid(d) and not d.exploded and not d.flying and not d.airborne:
			return true
	return false


func _cast_saccade(s: SpellData) -> bool:
	var c := _caster()
	if c == null or not saccade_ready():
		return false
	var had_ficele := _ficele_valid()
	var did := false
	if _heavy:
		if knife == null or not is_instance_valid(knife):
			return false
		var ret := s.duplicate() as SpellData
		ret.coef = SACCADE_LINE_COEF * s.coef / SACCADE_COEF
		ret.hit_force = _force_for(SACCADE_LINE_KNOCK_U)
		if had_ficele:
			_pull_ficele(s)
		knife.recall(ret)
		kstate = K.RETURNING
		ficele = null
		tours = 0
		did = true
	else: # Éventail : les couteaux plantés reviennent en ligne
		did = _recall_fan(s)
	var det := _detonate_decoys(had_ficele)
	if not did and det == 0:
		return false
	if strings != null:
		strings.vibrate(STRING_VIBRATE_S)
	Audio.play_cast(SND_SACCADE, player.global_position, c.cast_power(s))
	return true


## Arrachement : coup 1,4 + 0,25 par tour, recul, non-boss tiré de SACCADE_PULL_U vers Rictus.
func _pull_ficele(s: SpellData) -> void:
	var c := _caster()
	var e := ficele
	var sp := s.duplicate() as SpellData
	sp.coef = s.coef * (SACCADE_COEF + SACCADE_TOUR_ADD * tours) / SACCADE_COEF
	var at := e.global_position
	if StageMap.los(player.get_tree(), player.global_position, at):
		c.deal_damage(e, sp, {"source_pos": player.global_position})
	HitFx.impact(at, (at - player.global_position).normalized(), &"physical", 0.8, false, false, PlayerRef.id_of(player))
	LightRig.flash(at, &"spell_steel", 0.4)
	if is_instance_valid(e) and e.get(&"active") != false and e.has_method(&"push") and not e.is_in_group(&"bosses"):
		var to := player.global_position - e.global_position
		var d := minf(SACCADE_PULL_U * Balance.UNIT_PX, maxf(to.length() - 0.5 * Balance.UNIT_PX, 0.0))
		if d > 0.0:
			e.push(to.normalized() * d)


## Les doublures posées explosent toutes ensemble (+30 % et couleur de combo si une cible est ficelée).
func _detonate_decoys(had_ficele: bool) -> int:
	var n := 0
	for d in Decoy.live.duplicate():
		if not is_instance_valid(d) or d.exploded or d.flying or d.airborne:
			continue
		var sp: SpellData = d.explode_spell
		if had_ficele and sp != null:
			sp = sp.duplicate() as SpellData
			sp.coef *= DECOY_FICELE_MULT
			sp.set_meta(&"combo", true)
		d.explode(sp)
		n += 1
	return n


## Éventail + Saccade : les couteaux plantés reviennent en ligne (0,6 chacun, perce tout), 1 s de recharge rendue chacun.
func _recall_fan(s: SpellData) -> bool:
	var c := _caster()
	if c == null or knives.is_empty():
		return false
	var s2 := _spell_of(2)
	var sp := (s2 if s2 != null else s).duplicate() as SpellData
	sp.coef = SACCADE_LINE_COEF * s.coef / SACCADE_COEF
	sp.proc_coef = 0.8
	sp.hit_force = _force_for(SACCADE_LINE_KNOCK_U)
	sp.is_zone = false
	var group := {"refunded": 0.0}
	var spd := KNIFE_SPEED_U * Balance.UNIT_PX * (1.0 + minf(player.stat(&"projectile_speed"), Balance.PROJECTILE_SPEED_BONUS_CAP))
	var n := 0
	for k in knives.duplicate():
		if not is_instance_valid(k):
			continue
		var at: Vector2 = k.global_position
		k.queue_free()
		var r := RictusPendulum.recall_light(c, player, sp, at, spd, KNIFE_FRAMES)
		r.on_caught = func() -> void: _collect_knife(2, group)
		n += 1
	knives.clear()
	return n > 0


# --- Combo « L'étoile armée » (variantes Éventail + Toupie ; docs/Design_Combos.md §5.1) -------------------------------

## Un couteau de l'Éventail qui passe sur une doublure en attente la charge (une charge par doublure, au plus
## CHARGE_MAX_PER_SALVE par salve). Appelé seulement pendant FAN_WATCH_S après le lancer, sur ≤ 6 doublures.
func _charge_by_knives() -> void:
	var c := _caster()
	if c == null or _salve_charged >= CHARGE_MAX_PER_SALVE or Decoy.live.is_empty():
		return
	var host := c.effects_parent()
	if host == null:
		return
	var reach: float = (Decoy.RADIUS_U + KNIFE_CHARGE_PAD_U) * Balance.UNIT_PX
	for k in host.get_children():
		if not (k is Node2D) or k.get(&"active") != true:
			continue
		var ks: Variant = k.get(&"spell")
		if not (ks is SpellData) or (ks as SpellData).behavior != SpellData.Behavior.FAN:
			continue
		for d in Decoy.live:
			if _salve_charged >= CHARGE_MAX_PER_SALVE:
				return
			if is_instance_valid(d) and not d.exploded and not d.flying and not d.airborne and d.charged <= 0.0 \
					and (k as Node2D).global_position.distance_to(d.global_position) <= reach:
				d.charge_explode_add = DECOY_CHARGE_ADD
				d.charge_flight_coef = FLIGHT_CHARGED_COEF
				if d.charge():
					_salve_charged += 1
					Audio.play(&"pickup.coin", d.global_position, -10.0, 2.0) # grelot de la charge
					LightRig.flash(d.global_position, &"spell_steel", 0.15)


## Doublures chargées encore en attente (fenêtre de la Toupie).
func charged_decoys() -> int:
	var n := 0
	for d in Decoy.live:
		if is_instance_valid(d) and d.charged > 0.0 and not d.exploded and not d.pushed:
			n += 1
	return n


## SpellCaster.deal_damage : coup de combo = explosion / vol d'une doublure chargée ou détonée sur un ficelé (méta `combo`).
func combo_hit(s: SpellData, _enemy: Node) -> bool:
	return s != null and s.has_meta(&"combo")


## Marquage « coup d'ultime » (bouclier ULTIMATE_HIT) : les doublures sont souvent détonées par la Saccade bien après la
## pose (> ULT_MARK_S) ; leurs sorts d'explosion, de mort et de vol (copies du sort 4, base ou Rideau) comptent donc toujours.
func counts_as_ultimate(s: SpellData) -> bool:
	return s != null and s.slot == 4


## Fenêtre de combo du slot (HUD, sondé par SpellCaster toutes les 0,1 s). Saccade : pulse tant qu'un monstre est
## ficelé ou que des doublures attendent. Variantes : l'Éventail pulse tant qu'une doublure attend sa charge, la Toupie
## tant qu'une doublure chargée attend d'être expédiée.
func combo_ready(slot: int) -> bool:
	if slot == 3 and _sacc:
		return _ficele_valid() or _decoys_waiting()
	if Decoy.live.is_empty():
		return false
	if slot == 3:
		return charged_decoys() > 0
	if slot == 2 and not _heavy:
		for d in Decoy.live:
			if is_instance_valid(d) and not d.exploded and not d.pushed and d.charged <= 0.0:
				return true
	return false


## Lancer automatique (mobile, « Sorts automatiques », docs §3.5) : la Saccade attend son moment, l'ultime vise le ficelé.
func auto_cast_ok(slot: int) -> bool:
	if slot == 3 and _sacc:
		if not saccade_ready():
			return false
		if not _heavy:
			return true
		if kstate == K.GROUND:
			return true # (c) ficelé mort, fil cassé : le couteau est au sol
		if not _ficele_valid():
			return false
		if _planted_age >= AUTO_PLANT_S: # (a)
			return true
		if ficele.global_position.distance_to(player.global_position) > AUTO_STRING_LIMIT_U * Balance.UNIT_PX: # (b)
			return true
		if tours >= TOUR_MAX: # (e)
			return true
		return _decoys_waiting() and _clock - _decoys_landed_at >= AUTO_DECOYS_S # (d)
	if slot == 4:
		var c := _caster()
		if c == null:
			return false
		if c.nearest_enemy(DECOY_AUTO_NEAR_U * Balance.UNIT_PX) != null:
			return true
		if _ficele_valid():
			var pr: Variant = ficele.get(&"aim_priority")
			if ficele.is_in_group(&"bosses") or (pr != null and float(pr) > 1.0):
				return true # boss ou mini-boss ficelé
			var n := 0
			var r := DECOY_BURST_U * Balance.UNIT_PX
			for e in player.get_tree().get_nodes_in_group(&"enemies"):
				if e is Node2D and is_instance_valid(e) and e.get(&"active") != false \
						and (e as Node2D).global_position.distance_to(ficele.global_position) <= r:
					n += 1
			return n >= DECOY_AUTO_PACK_N
		return false
	return true


## Levée (DodgeMove, fin de l'esquive) : atterrir près de doublures en attente les détone tout de suite. Le joueur choisit
## le moment ; l'invulnérabilité de la levée couvre l'explosion. Aucun dégât direct de l'esquive (règle 5).
func on_dodge_end(_from: Vector2, _to: Vector2) -> void:
	if player == null or Decoy.live.is_empty():
		return
	var r := LIFT_DETONATE_U * Balance.UNIT_PX
	for d in Decoy.live.duplicate():
		if is_instance_valid(d) and not d.exploded and not d.flying and not d.airborne \
				and d.global_position.distance_to(player.global_position) <= r:
			d.explode(d.explode_spell)


# --- Toupie (variante du slot 3) --------------------------------------------------------------------------------------

func _start_spin(s: SpellData) -> bool:
	if spin_left > 0.0 or lifting:
		return false
	_spin_tick_spell = s.duplicate() as SpellData
	_spin_tick_spell.behavior = SpellData.Behavior.NOVA
	_spin_tick_spell.duration = 0.0 # chaque tick = coup direct (recul), pas un DoT
	_spin_focus_spell = _spin_tick_spell.duplicate() as SpellData
	_spin_focus_spell.coef = TOUPIE_FOCUS_COEF
	_spin_focus_spell.radius_u = TOUPIE_FOCUS_RADIUS_U
	_spin_focus_spell.vfx_frames = "" # coup direct sans gerbe
	_spin_focus_spell.is_zone = false
	_spin_focus_spell.hit_force = -1.0
	_spin_total = s.duration
	spin_left = s.duration
	_spin_elapsed = 0.0
	_spin_ticks = 0
	player.set_hitbox_u(SPIN_HITBOX_U)
	player.clear_slow()
	player.grant_invulnerability(s.duration) # retour joueur : invulnérable pendant toute la toupie
	_spin_tick() # premier tick au lancement : 10 ticks à 0, 0,25 … 2,25 s
	_push_decoys()
	return true


func _spin_step(delta: float) -> void:
	_spin_elapsed += delta
	spin_left = maxf(_spin_total - _spin_elapsed, 0.0)
	var n := int(roundf(_spin_total / SPIN_TICK_S))
	while _spin_ticks < n and _spin_elapsed + 0.0001 >= _spin_ticks * SPIN_TICK_S:
		_spin_tick()
	_push_decoys()
	if spin_left <= 0.0:
		_end_spin()


func _spin_tick() -> void:
	_spin_ticks += 1
	if _caster() != null and _spin_tick_spell != null:
		_caster().spawn_zone(_spin_tick_spell, player.global_position)
		if _spin_focus_spell != null: # Pointe de la toupie : coup monocible sur l'ennemi le plus proche
			var tgt := _caster().nearest_enemy(spin_radius_px())
			if tgt != null:
				_caster().spawn_zone(_spin_focus_spell, tgt.global_position)
		if _ficele_valid(): # le fil s'enroule autour de la toupie : un tick de scie par tick de Toupie
			_saw_tick()


func spin_radius_px() -> float:
	var r: float = _spin_tick_spell.radius_u if _spin_tick_spell != null else 1.5
	return r * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))


## Toute doublure dont le centre entre dans la toupie est percutée (une fois) : départ droit devant elle.
func _push_decoys(radius_px := -1.0) -> void:
	if Decoy.live.is_empty():
		return
	var r := radius_px if radius_px >= 0.0 else spin_radius_px()
	for d in Decoy.live.duplicate():
		if is_instance_valid(d) and not d.pushed and d.global_position.distance_to(player.global_position) <= r:
			d.push()


## Fin de toupie : fils tendus (+2 % PV), vertige.
func _end_spin() -> void:
	spin_left = 0.0
	stagger_left = STAGGER_S
	player.set_hitbox_u(HITBOX_U)
	player.heal(HEAL_PCT * player.max_hp)
	if strings != null:
		strings.vibrate(STRING_VIBRATE_S)


# --- Main du Montreur (variante du slot 1) -------------------------------------------------------------------------

## Main du Montreur : claquement (disque) sur le paquet le plus dense à MAIN_RANGE_U ; la garde ne vaut que de près.
func _cast_main(s: SpellData) -> bool:
	var c := _caster()
	if c == null:
		return false
	var pt: Variant = c.densest_point(MAIN_RANGE_U * Balance.UNIT_PX)
	if pt == null:
		return false
	var at: Vector2 = pt
	var zs := s.duplicate() as SpellData
	zs.behavior = SpellData.Behavior.NOVA
	zs.duration = 0.0
	var d := at - player.global_position
	if d.length_squared() > 1.0:
		player.facing = d.normalized()
	c.spawn_zone(zs, at)
	if d.length() <= MAIN_GUARD_U * Balance.UNIT_PX:
		guard_left = GUARD_S
	if strings != null:
		strings.vibrate(STRING_VIBRATE_S)
	return true


# --- Doublures (S14) ----------------------------------------------------------------------------------------------

## Centre de repli des Doublures sans ficelé : point visé (curseur / stick, plafond 7 u), sinon le paquet le plus
## dense à 6 u (le monstre le plus proche en lancer auto), sinon Rictus. Jamais derrière un mur.
func _decoy_fallback(aim: Variant) -> Vector2:
	var origin := player.global_position
	var pt: Variant = null
	if aim != null and ((aim as Vector2) - origin).length_squared() > 1.0:
		pt = origin + ((aim as Vector2) - origin).limit_length(DECOY_THROW_RANGE_U * Balance.UNIT_PX)
	elif _caster() != null:
		pt = _caster().densest_point(DECOY_AUTO_RANGE_U * Balance.UNIT_PX)
	if pt == null:
		return origin
	return _clip_to_wall(origin, pt as Vector2)


func _spawn_decoys(s: SpellData, aim: Variant, center_fallback: Variant = null) -> void:
	var origin := player.global_position
	var rideau := s.id == V_RIDEAU
	var center := origin
	if not rideau: # autour du ficelé (même sur PC), sinon le repli calculé au lancement
		if _ficele_valid():
			center = ficele.global_position
		elif center_fallback is Vector2:
			center = center_fallback
	var first := Vector2.UP # sans visée : vers le haut de l'écran
	if (center - origin).length_squared() > 1.0:
		first = (center - origin).normalized()
	elif aim != null and ((aim as Vector2) - origin).length_squared() > 1.0:
		first = ((aim as Vector2) - origin).normalized()
	var explode := s.duplicate() as SpellData
	explode.behavior = SpellData.Behavior.NOVA
	explode.duration = 0.0
	explode.vfx_frames = DOUBLE_BURST_FRAMES # gerbe de copeaux et de fils rompus (M3, vue TOP)
	explode.vfx_radius_px = DOUBLE_BURST_RADIUS_PX
	explode.vfx_floor_aspect = 1.0 # rig TOP : jamais pré-écrasé
	var death := explode.duplicate() as SpellData
	death.coef = s.coef * DECOY_DEATH_FRAC
	var flight := explode.duplicate() as SpellData
	flight.vfx_frames = "" # coups directs en vol : pas de gerbe
	flight.coef = FLIGHT_COEF
	flight.proc_coef = FLIGHT_PROC
	flight.is_zone = false
	flight.hit_force = -1.0
	var token := {"healed": false}
	var parent := player.get_parent()
	var space := player.get_world_2d().direct_space_state if player.is_inside_tree() else null
	var fwd := Vector2.UP
	if rideau: # ligne perpendiculaire à la visée, dos à Rictus (poussée vers l'avant)
		fwd = _rideau_forward(aim)
	for i in DECOY_COUNT:
		var dir := first.rotated(i * TAU / DECOY_COUNT)
		var pos := center + dir * DECOY_RING_U * Balance.UNIT_PX
		var ray_from := center
		if rideau:
			dir = fwd
			pos = origin + fwd * RIDEAU_AHEAD_U * Balance.UNIT_PX + fwd.orthogonal() * (float(i) - (DECOY_COUNT - 1) * 0.5) * RIDEAU_SPACING_U * Balance.UNIT_PX
			ray_from = origin
		if space != null: # position dans un mur (ou derrière) : sautée
			var q := PhysicsRayQueryParameters2D.create(ray_from, pos, WALL_MASK, [player.get_rid()])
			if not space.intersect_ray(q).is_empty():
				continue
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e is Node2D and e.has_method(&"push") and not e.is_in_group(&"bosses"):
				var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
				if e.global_position.distance_to(pos) <= Decoy.RADIUS_U * Balance.UNIT_PX + er:
					e.push(dir * DECOY_BLOCK_PUSH_U * Balance.UNIT_PX)
		var d := Decoy.new()
		d.caster = _caster()
		d.max_hp = (RIDEAU_HP_FRAC if rideau else DECOY_HP_FRAC) * player.max_hp
		d.hp = d.max_hp
		d.life_s = s.duration if s.duration > 0.0 else DECOY_LIFE_S
		d.facing = dir
		d.explode_spell = explode
		d.death_spell = death
		d.flight_spell = flight
		d.on_explode = func(_d: Decoy) -> void: _on_decoy_exploded(token)
		parent.add_child(d)
		d.global_position = pos
		d.copy_look(_visual)
		d.appear()
	_decoys_landed_at = _clock
	if spin_left > 0.0: # ultime pendant la toupie (variante) : percutées à la frame suivante (au plus tard)
		_push_decoys()


## Sens du Rideau : visée manuelle, sinon ennemi le plus proche à RIDEAU_AIM_U, sinon orientation du pantin.
func _rideau_forward(aim: Variant) -> Vector2:
	if aim != null and ((aim as Vector2) - player.global_position).length_squared() > 1.0:
		return ((aim as Vector2) - player.global_position).normalized()
	var c := _caster()
	if c != null:
		var e := c.nearest_enemy(RIDEAU_AIM_U * Balance.UNIT_PX)
		if e != null and (e.global_position - player.global_position).length_squared() > 1.0:
			return (e.global_position - player.global_position).normalized()
	return player.facing if player.facing != Vector2.ZERO else Vector2.DOWN


func _on_decoy_exploded(token: Dictionary) -> void:
	if strings != null:
		strings.vibrate(STRING_VIBRATE_S)
	if not bool(token["healed"]) and player != null and is_instance_valid(player) and not player.dead:
		token["healed"] = true
		player.heal(HEAL_PCT * player.max_hp)


## Monstre tué à moins de CLOSE_KILL_U : compteur de run (déblocage de la variante Toupie).
## Coop : seuls les monstres tués par CE joueur (Events.enemy_killed_by ; auteur inconnu accepté en solo).
func _on_enemy_killed_by(id: int, e: Node2D, pos: Vector2, tier: int, elite: bool) -> void:
	if PlayerRef.owns(player, id):
		_on_enemy_killed(e, pos, tier, elite)


func _on_enemy_killed(_e: Node2D, pos: Vector2, _tier: int, _elite: bool) -> void:
	if player != null and is_instance_valid(player) and not player.dead \
			and pos.distance_to(player.global_position) <= CLOSE_KILL_U * Balance.UNIT_PX:
		PlayerRef.state_of(player).add_counter(COUNTER_CLOSE)


# --- Nettoyage (§2.6.5 : étage, mort) ------------------------------------------------------------

func clear_transients() -> void:
	_pending_decoys = {}
	if knife != null and is_instance_valid(knife):
		knife.queue_free()
	knife = null
	ficele = null
	tours = 0
	kstate = K.HAND # couteau rendu en main
	if player != null and is_instance_valid(player) and player.spells != null:
		player.spells.set_cooldown(2, 0.0, 1.0)
	Decoy.clear_all()
	for k in knives.duplicate():
		if is_instance_valid(k):
			k.queue_free()
	knives.clear()


func _on_floor_started(_n: int) -> void:
	clear_transients()


## Coop : seule la mort de CE joueur (Events.player_died_by ; solo : joueur 1).
func _on_player_died_by(id: int) -> void:
	if PlayerRef.owns(player, id):
		_on_player_died()


func _on_player_died() -> void:
	spin_left = 0.0
	stagger_left = 0.0
	clear_transients()
	if strings != null:
		strings.visible = false # fils coupés
	if _visual != null and _visual.sprite_frames != null:
		var anim := _resolve(&"death", _dir_name())
		if anim != &"":
			_visual.sprite_frames.set_animation_loop(anim, false)
			_visual.play(anim)


# --- Rendu ----------------------------------------------------------------------------------------

func _dir_name() -> String:
	var i := roundi(player.facing.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES[(i + 8) % 8]


## Anim `<base>_<dir>`, sinon `<base>` (spin : 1 direction), sinon &"" (le joueur garde idle/run).
func _resolve(base: StringName, dir: String) -> StringName:
	if _visual == null or _visual.sprite_frames == null:
		return &""
	# `spin` n'a qu'une direction (symétrie de rotation) : livrée `spin`, `spin_s` ou `spin_e` (M2b) selon le lot
	for a: StringName in [StringName("%s_%s" % [base, dir]), base, StringName("%s_s" % base), StringName("%s_e" % base)]:
		if _visual.sprite_frames.has_animation(a):
			return a
	return &""


## Anim du pantin (Player._update_visual) : états du kit (levée, toupie, vertige) prioritaires ; sinon
## `fallback` = anim d'action en cours (slash/throw/summon) ou idle/run_<dir>.
func visual_anim(fallback: StringName) -> StringName:
	var base := &""
	if lifting:
		base = &"lift"
	elif spin_left > 0.0:
		base = &"spin"
	elif stagger_left > 0.0:
		base = &"stagger"
	if base != &"":
		var a := _resolve(base, _dir_name())
		if a != &"":
			return a
	return fallback


## Traînée de la toupie : enfant du pantin (même échelle, suit la levée), additive, cachée hors toupie.
func _attach_spin_blur() -> void:
	if not ResourceLoader.exists(SPIN_BLUR_FRAMES):
		return
	var sf := load(SPIN_BLUR_FRAMES) as SpriteFrames
	if sf == null or not sf.has_animation(&"default"):
		return
	spin_blur = AnimatedSprite2D.new()
	spin_blur.name = "SpinBlur"
	spin_blur.sprite_frames = sf
	if VfxSwap.enabled(): # mode test : VFX de test (scripts/testmode/vfx_swap.gd)
		VfxSwap.on_sprite(spin_blur, sf)
	spin_blur.offset = SPIN_BLUR_OFFSET
	spin_blur.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	spin_blur.material = m
	spin_blur.modulate = Color(STRING_COLOR.r * STRING_GLOW, STRING_COLOR.g * STRING_GLOW, STRING_COLOR.b * STRING_GLOW, SPIN_BLUR_ALPHA)
	spin_blur.visible = false
	_visual.add_child(spin_blur)


func _update_rig() -> void:
	if spin_blur != null:
		var on := spin_left > 0.0
		if on != spin_blur.visible:
			spin_blur.visible = on
			if on:
				spin_blur.play(&"default")
			else:
				spin_blur.stop()
	# fils tendus : levée, toupie, lancer d'ultime, couteau en vol ou en retour (Montreur `pull`)
	var taut: bool = lifting or spin_left > 0.0 or player.action_base() in ULT_ACTIONS \
			or kstate == K.FLYING or kstate == K.RETURNING
	if _visual != null:
		# levée : le pantin monte et redescend (arc sinus), à la hauteur LIFT_HEIGHT_U au milieu du saut
		var k := 0.0
		if lifting:
			k = sin(PI * clampf(1.0 - player.dodge_progress_left(), 0.0, 1.0))
		_visual.position.y = Iso.lift_logical(LIFT_HEIGHT_U) * k
	if companion != null:
		companion.sync(_dir_name(), &"pull" if taut else &"hover")
	if strings != null:
		strings.tension = 1.0 if taut else 0.0


# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) ------------------------------------

static func passive_info() -> Dictionary:
	return KitResource.passive("Fils du Montreur", &"fils",
		"Pas de jauge : deux effets passifs. Les fils tirent le pantin hors des coups, et se tendent pour le réparer.",
		"",
		"",
		"Garde : -%s de dégâts subis pendant %s s après chaque demi-lune. Fils tendus : +%s des PV max rendus à la première explosion de chaque Doublures (et en fin de Toupie). Ficelé : un seul monstre à la fois porte le couteau lourd (%s s) ; chaque demi-lune sur lui enroule un tour de fil (%d au plus) qui renforce la Saccade." % [
			KitResource.pct(1.0 - GUARD_TAKEN_MULT), KitResource.fmt(GUARD_S), KitResource.pct(HEAL_PCT), KitResource.fmt(FICELE_S), TOUR_MAX])
