class_name RainetteKit
extends Node
## Kit de Rainette, chevalière des roseaux (docs/Design_Personnages.md §2.3 ; kit complété le 22/10/2026,
## voir le rapport d'intégration) : mobilité / burst. Refonte du 26/10/2026 : plus de ressource « Souffle ». Données : character(). Logique :
## ce nœud, enfant « Kit » du joueur, interrogé par hooks (locomote, ignores_hit, blocks_slot, cast_spell,
## visual_anim, can_dodge, on_dodge_start…), comme RictusKit.
## - Locomotion S11 : elle ne marche pas, elle BONDIT, sans limite ni jauge. Joystick poussé = bonds enchaînés de
##   2,5 u en 0,35 s (+0,1 s d'atterrissage) par-dessus les monstres (pas les murs), orientables en l'air
##   (virage doux vers le joystick). En l'air : intouchable au contact (pas par les projectiles ni par les boss).
##   Distance × vitesse d'items / ralentissements.
## - Sort 1 Langue (auto) : fouet de 4,5 u vers le plus proche ; la CIBLE PRINCIPALE (boss, sinon élite, sinon le plus
##   proche de la ligne) prend le gros coup (monocible), le reste de la ligne un coup réduit ; tire les cibles de
##   0,25 u vers elle ; un T1 tué par la Langue est avalé : +1 % PV max.
## - Sort 2 Grand saut (7 s) : accroupie 0,12 s puis bond de 6 u vers le point visé, atterrissage coef 3,8
##   dans 3 u + étourdissement 0,5 s. Pressé en l'air = mis en file.
## - Sort 3 Gluant (8 s) : crachat au point visé (6 u) : éclaboussure coef 1,0 puis flaque 2,5 u / 5 s,
##   ralentit 40 % et colle le paquet (attraction vers le centre) ; bonds depuis la flaque +50 %.
## - Sort 4 Chant de crue (20 s) : 4 s, sac vocal gonflé : bonds ×2 (plus hauts), chaque atterrissage
##   inflige coef 2,8 dans 3 u.
## - Roulade = bond arrière (3 u, invulnérable, même recharge) : elle saute à reculons en gardant la menace
##   en face (sans direction : recule depuis le curseur / l'avant).
## Rendu : rainette.tres (RA1) ; VFX tongue (RA1) ; goo, land_ring, ombre de contact (RA2) : absents = repli.

# --- Assets (lots Codex RA1 livré, RA2 attendu) : chemins exacts ----------------------------------
const ASSET_DIR := "res://assets/sprites/characters/rainette/"
const SPRITE_FRAMES := ASSET_DIR + "rainette.tres"
## Langue (RA1, CREA 4 frames 512², pointe vers +X, longueur max 405 px = 4,5 u à 90,5 px/u ; base de la
## langue à (40, 248) dans la frame).
const TONGUE_FRAMES := ASSET_DIR + "effects/tongue/tongue.tres"
const TONGUE_FRAME_LEN_PX := 405.0
const TONGUE_ORIGIN_PX := Vector2(40.0, 248.0)
const TONGUE_MOUTH_U := 0.55 ## hauteur de la bouche
const TONGUE_FORWARD_U := 0.2 ## la langue part un peu devant le corps
## Flaque de Gluant (RA2 livré, rig TOP 64 px/u natif, cellule 352², `default` 6 frames en boucle) : bord de la
## flaque à 2,5 u = 160 px du centre de la frame (mesuré : filaments jusqu'à ~168 px).
const GOO_FRAMES := ASSET_DIR + "effects/goo/goo.tres"
const GOO_RADIUS_PX := 160.0
## Crachat en vol (RA2, CREA 128 à 90,5 px/u, `default` 4 frames en boucle, vers +X) : purement visuel, il vole
## de la bouche à la flaque pendant son fondu d'apparition (RainetteGoo.FADE_IN_S) : timing de jeu inchangé.
const GOO_PROJECTILE_FRAMES := ASSET_DIR + "effects/goo_projectile/goo_projectile.tres"
const GOO_GLOB_ARC_U := 0.6 ## flèche de la parabole du crachat
## Anneau d'atterrissage (RA2 livré, rig TOP 64 px/u, cellule 384², `default` 4 frames non bouclées) : anneau final
## à 2,5 u = 160 px (ultime 3 u : même couronne × 1,2, échelle calculée par ZoneEffect).
const LAND_RING_FRAMES := ASSET_DIR + "effects/land_ring/land_ring.tres"
const LAND_RING_RADIUS_PX := 160.0
## Ombre de contact (RA2 livré, 104², disque flou de rayon 45 px, affiché à 0,35 u par RainetteShadow) ;
## absente = ellipse sombre dessinée (placeholder).
const SHADOW_TEX := ASSET_DIR + "effects/shadow/shadow.png"
const SHADOW_RADIUS_PX := 45.0
const PLACEHOLDER_TINT := Color(0.55, 0.64, 0.5) ## Ardent teinté vert-gris si rainette.tres manque

# --- Couleurs (fiche §2.3 Aspect) ----------------------------------------------------------------
const SKIN := Color("#5B6B4F")
const ACCENT := Color("#8DBBA8") ## sac vocal : accent émissif unique
const LIGHT := &"rainette_jade" ## preset LightRig des sorts (jamais la braise d'Ardent)
const LIGHT_SAC := &"rainette_sac" ## sac vocal gonflé (Chant de crue)
const PLAYER_LIGHT_TINT := Color("#C9DCCF") ## lumière du joueur refroidie (pluie, jade pâle), pas la braise

# --- Statistiques (§2.3 Stats) --------------------------------------------------------------------
const BASE_HP := 90.0
const HP_PER_LEVEL := 27.0
const ARMOR := 10.0
const BASE_REGEN := 1.2
const REGEN_PER_LEVEL := 0.24
const SPEED_U := 5.5 ## vitesse nominale (affichage, items) : 2,5 u / 0,45 s
const HITBOX_U := 0.45

# --- Bonds et souffle -----------------------------------------------------------------------------
const HOP_DIST_U := 2.5
const HOP_AIR_S := 0.35
const HOP_LAND_S := 0.1
const HOP_HEIGHT_U := 0.55
const AIR_TURN_RAD_S := 4.5 ## virage en l'air vers le joystick (rad/s) : les bonds se corrigent, rien d'engagé
const CONTACT_MARGIN_U := 0.35 ## en l'air : un coup de monstre à portée de contact (+ marge) est ignoré
const DODGE_HEIGHT_U := 0.6
const BACK_HOP_U := 3.5 ## bond arrière (roulade) : 3 u de Balance -> 3,5 u (équilibrage 22/10, sa défense = la distance) ## bond arrière : arc visuel

# --- Sorts ----------------------------------------------------------------------------------------
const TONGUE_COEF := 1.1 ## cible principale (refonte 26/10 : monocible). Combos 29/10 : 1,15 -> 1,1 (compensation de la Langue sur étourdi)
const TONGUE_LINE_COEF := 0.9 ## autres monstres de la ligne (zone un peu réduite en compensation)
const TONGUE_RANGE_U := 4.5
const TONGUE_WIDTH_U := 0.5 ## équilibrage 22/10 : 0,35 -> 0,5 (essaim −27 %) ; demi-largeur de la ligne frappée (+ rayon du monstre)
const TONGUE_PULL_U := 0.25
const SWALLOW_HEAL_PCT := 0.01
const LEAP_COEF := 3.4 ## équilibrage 22/10 : 3,0 -> 3,8 (burst) ; combos 29/10 : 3,8 -> 3,4 (compensation Écrasement)
const LEAP_CD := 7.0
const LEAP_RANGE_U := 6.0
const LEAP_MIN_U := 1.5
const LEAP_RADIUS_U := 3.0 ## équilibrage 22/10 : 2,5 -> 3,0
const LEAP_STUN_S := 0.5
const LEAP_CROUCH_S := 0.12
const LEAP_AIR_S := 0.55
const LEAP_HEIGHT_U := 1.6
const LEAP_GRACE_S := 0.35 ## équilibrage 22/10 : 0,15 -> 0,35 ; invulnérabilité à l'atterrissage du Grand saut (lisibilité de l'impact)
const LEAP_SHAKE_PX := 7.0
const GOO_SPLASH_COEF := 1.3 ## équilibrage 22/10 : 1,0 -> 1,4 (zone) ; combos 29/10 : 1,4 -> 1,3 (compensation)
const GOO_CD := 8.0
const GOO_RANGE_U := 6.0
const GOO_RADIUS_U := 2.5
const GOO_DURATION_S := 5.0
const GOO_SLOW_PCT := 0.4
const GOO_PULL_U_S := 0.9 ## attraction vers le centre (le paquet se colle et avance lentement)
const GOO_HOP_BONUS := 0.5
const ULT_CD := 20.0
const ULT_DURATION_S := 4.0
const ULT_LAND_COEF := 2.8 ## équilibrage 22/10 : 3,0 -> 3,6 ; audit 23/10 (P5) : 3,6 -> 2,8
const ULT_LAND_RADIUS_U := 3.0
const ULT_HOP_MULT := 2.0
const ULT_AIR_MULT := 1.6
const ULT_HEIGHT_MULT := 1.8
## Anims d'action (rainette.tres) et frames d'impact (index 0) : attack = Langue (manifeste RA1 : frame 3),
## spit = Gluant, belch = Chant de crue (repli cast_ult).
const ACTION_IMPACT_FRAMES := {&"attack": 3, &"spit": 2, &"belch": 3, &"cast": 2, &"cast_ult": 3}
## Prise en main (retour joueur 23/10/2026 : « stacks de déplacement » illisibles, sauts ratés) : un appui un peu
## trop tôt n'est plus perdu (tampon), un refus se voit et s'entend.
const INPUT_BUFFER_S := 0.15 ## appui de bond pendant un bond / un atterrissage, ou de sort juste avant la fin de recharge
const WARN_GAP_S := 0.5 ## espacement mini entre deux retours de refus
# Variantes de sorts (docs/Variantes_Sorts.md §2.6) : aucune n'ajoute de contrainte de déplacement.
const V_CROAK := &"rainette_croassement" ## slot 1, remplace la Langue
const V_RICOCHET := &"rainette_ricochet" ## slot 2, remplace le Grand saut
const V_BULLE := &"rainette_bulle" ## slot 3, remplace le Gluant
const V_CHOEUR := &"rainette_choeur" ## slot 4, remplace le Chant de crue
const CROAK_COEF := 1.2
const CROAK_RADIUS_U := 2.5
const CROAK_KNOCK_U := 0.4
const CROAK_CD_GAIN_S := 0.25 ## par T1 tué : recharge du Grand saut raccourcie
const CROAK_CD_GAIN_MAX_S := 1.0 ## par croassement
const RIC_COEF := 1.9
const RIC_CD := 7.0
const RIC_RANGE_U := 3.5
const RIC_RADIUS_U := 2.0
const RIC_AIR_S := 0.35
const RIC_HEIGHT_U := 0.9
const RIC_CROUCH_S := 0.06 ## accroupie brève : le second bond part tout de suite
const RIC_STUN_S := 0.3
const RIC_GRACE_S := 0.2
const BULLE_COEF := 1.4
const BULLE_CD := 8.0
const BULLE_CATCH_U := 2.5 ## rayon de capture au point visé
const BULLE_BURST_U := 2.0 ## rayon de l'éclatement
const BULLE_HOLD_S := 1.5
const BULLE_PULL_U := 1.0 ## attraction vers le centre sur la durée
const BULLE_BOSS_SLOW := 0.4
const CHOEUR_COEF := 1.8
const CHOEUR_RADIUS_U := 2.5
const CHOEUR_DURATION_S := 8.0
const CHOEUR_GOO_U := 1.5
const CHOEUR_GOO_S := 2.0
const CHOEUR_GOO_MAX := 10 ## mini-flaques vivantes en même temps (plafond de perf)
## Combos (docs/Design_Combos.md §5.3). Écrasement : Gluant -> Grand saut qui atterrit dans la flaque.
const CRUSH_ADD := 0.3 ## coef additif du Grand saut sur un monstre collé (3,4 -> 3,7)
const CRUSH_STUN_S := 1.0 ## étourdissement des collés (0,5 s sur les autres)
const GOO_BURST_COEF := 1.2 ## la flaque éclate : un coup dans tout son rayon, puis elle est consommée
const GOO_BURST_END_SPEED := 2.0 ## vitesse de l'animation `end` de la flaque qui éclate
const TONGUE_STUN_COEF := 1.6 ## Langue sur cible étourdie ou collée (cible principale)
const TONGUE_STUN_PULL_U := 0.75 ## traction de cette Langue (0,25 u sinon)
const CRUSH_READY_RANGE_U := 1.0 ## combo_ready(2) : une flaque à portée de saut (portée + marge)
const AUTO_WAIT_GOO_S := 1.0 ## auto-cast : le Grand saut attend le Gluant s'il revient dans moins de ce délai
const COUNTER_LEAP_STUNS :="rainette.leap_stuns" ## monstres (hors boss) étourdis par le Grand saut
const COUNTER_GLUED := "rainette.glued" ## monstres pris dans le Gluant (1 fois par flaque)
const COUNTER_SWALLOWED := "rainette.swallowed" ## T1 avalés par la Langue
const WALL_MASK := 1
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

enum State { GROUND, CROUCH, AIR, LAND }

var player: CharacterBody2D = null
var state := State.GROUND
var state_left := 0.0
var ult_left := 0.0
var choir := false ## le Chœur des roseaux est en cours (bonds normaux, flaques aux atterrissages)
var croak_cd_gain := 0.0 ## secondes de recharge du Grand saut rendues par le Croassement (tests)
var ric_chains := 0 ## seconds bonds du Ricochet lancés (tests)
var hop_dir := Vector2.DOWN
var hop_is_leap := false ## bond en cours = Grand saut
var hop_air_total := HOP_AIR_S
var hop_height_u := HOP_HEIGHT_U
var hop_speed_px := 0.0
var hop_count := 0 ## bonds lancés (tests)
var landings := 0 ## atterrissages (tests)
var swallowed := 0 ## T1 avalés (tests)
var last_tongue: Node2D = null ## dernier VFX de langue (tests)
var buffered_hops := 0 ## bonds lancés depuis le tampon d'entrée (tests)
var buffered_casts := 0 ## sorts lancés depuis le tampon de recharge (tests)
var _warn_gap := 0.0
var _dir_active := false
var _hop_buf := 0.0
var _hop_buf_dir := Vector2.ZERO
var _spell_buf := {} ## slot -> temps restant du tampon
var _leap_target := Vector2.ZERO
var _queued_leap: Variant = null ## Grand saut pressé en l'air : {spell, aim}
var _leap_spell: SpellData = null
var _ric_second := false ## le bond en cours est le second du Ricochet
var _mini_goo_sd: SpellData = null
var _crush_ids := {} ## instance_id -> true : monstres collés à l'atterrissage du Grand saut (lus par combo_coef_add)
var _pending := {} ## base d'action -> {spell, aim, target}
var _visual: AnimatedSprite2D = null
var _shadow: Node2D = null
var _line_sd: SpellData = null ## Langue de la ligne (coef réduit), copie paresseuse du sort du slot 1
var _line_src: SpellData = null
var _sac_light: LightRig.Handle = null
var _tongue_frames: SpriteFrames = null


# --- Données -------------------------------------------------------------------------------------

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
	s.element = &"physical"
	s.color = ACCENT
	s.light_preset = LIGHT
	return s


static func character() -> CharacterData:
	var c := CharacterData.new()
	c.id = &"rainette"
	c.display_name = "Rainette"
	c.base_hp = BASE_HP
	c.hp_per_level = HP_PER_LEVEL
	c.armor = ARMOR
	c.base_regen = BASE_REGEN
	c.regen_per_level = REGEN_PER_LEVEL
	c.base_speed_u = SPEED_U
	c.hitbox_u = HITBOX_U
	c.dodge_distance_u = BACK_HOP_U
	c.kit_script = RainetteKit
	c.sprite_frames_path = SPRITE_FRAMES
	c.placeholder_tint = PLACEHOLDER_TINT
	c.body_color = SKIN
	c.accent_color = ACCENT
	c.light_color = PLAYER_LIGHT_TINT # lumière du joueur : jade pâle froid au lieu de la braise d'Ardent
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"rainette_langue", "Langue", 1, TONGUE_COEF, 0.6)
	s1.is_auto = true
	s1.range_u = TONGUE_RANGE_U
	s1.trigger_range_u = TONGUE_RANGE_U
	s1.is_zone = false
	s1.proc_coef = 1.0
	s1.hit_force = _force_for(TONGUE_PULL_U)

	var s2 := _spell(&"rainette_grand_saut", "Grand saut", 2, LEAP_COEF, LEAP_CD)
	s2.range_u = LEAP_RANGE_U
	s2.radius_u = LEAP_RADIUS_U
	s2.proc_coef = 1.0
	s2.hit_force = 1.0
	s2.target_mode = &"densest"
	s2.trigger_range_u = LEAP_RANGE_U
	s2.vfx_frames = LAND_RING_FRAMES
	s2.vfx_radius_px = LAND_RING_RADIUS_PX
	s2.vfx_floor_aspect = 1.0 # rig TOP

	var s3 := _spell(&"rainette_gluant", "Gluant", 3, GOO_SPLASH_COEF, GOO_CD)
	s3.range_u = GOO_RANGE_U
	s3.radius_u = GOO_RADIUS_U
	s3.duration = GOO_DURATION_S
	s3.proc_coef = 1.0
	s3.hit_force = 0.0
	s3.target_mode = &"densest"
	s3.trigger_range_u = GOO_RANGE_U
	s3.element = &"poison" # vase : teinte des impacts (aucun poison appliqué)
	s3.vfx_frames = GOO_FRAMES
	s3.vfx_radius_px = GOO_RADIUS_PX
	s3.vfx_floor_aspect = 1.0

	var s4 := _spell(&"rainette_chant_de_crue", "Chant de crue", 4, ULT_LAND_COEF, ULT_CD)
	s4.radius_u = ULT_LAND_RADIUS_U
	s4.duration = ULT_DURATION_S
	s4.proc_coef = 1.0
	s4.hit_force = 1.0
	s4.trigger_range_u = 3.0
	s4.vfx_frames = LAND_RING_FRAMES
	s4.vfx_radius_px = LAND_RING_RADIUS_PX
	s4.vfx_floor_aspect = 1.0

	c.spells = [s1, s2, s3, s4]
	return c


## Variantes (contrat CONTRACTS.md) : SpellData de la variante `variant_id` pour `slot`, ou null (non codée).
## Coefficients ajustés par balance_sim (±15 % du sort de base en DPS cible et zone) ; le style ne change pas.
static func variant(slot: int, variant_id: StringName) -> SpellData:
	match [slot, variant_id]:
		[1, V_CROAK]:
			var s1 := _spell(V_CROAK, "Croassement", 1, CROAK_COEF, 0.6)
			s1.is_auto = true
			s1.radius_u = CROAK_RADIUS_U
			s1.trigger_range_u = CROAK_RADIUS_U
			s1.range_u = CROAK_RADIUS_U
			s1.proc_coef = 0.7
			s1.hit_force = _force_for(CROAK_KNOCK_U)
			s1.vfx_frames = LAND_RING_FRAMES
			s1.vfx_radius_px = LAND_RING_RADIUS_PX
			s1.vfx_floor_aspect = 1.0
			return s1
		[2, V_RICOCHET]:
			var s2 := _spell(V_RICOCHET, "Ricochet", 2, RIC_COEF, RIC_CD)
			s2.range_u = RIC_RANGE_U
			s2.radius_u = RIC_RADIUS_U
			s2.proc_coef = 1.0
			s2.hit_force = 1.0
			s2.target_mode = &"densest"
			s2.trigger_range_u = RIC_RANGE_U
			s2.vfx_frames = LAND_RING_FRAMES
			s2.vfx_radius_px = LAND_RING_RADIUS_PX
			s2.vfx_floor_aspect = 1.0
			return s2
		[3, V_BULLE]:
			var s3 := _spell(V_BULLE, "Bulle", 3, BULLE_COEF, BULLE_CD)
			s3.range_u = GOO_RANGE_U
			s3.radius_u = BULLE_BURST_U
			s3.duration = BULLE_HOLD_S
			s3.proc_coef = 1.0
			s3.hit_force = _force_for(0.3)
			s3.target_mode = &"densest"
			s3.trigger_range_u = GOO_RANGE_U
			s3.element = &"poison"
			return s3
		[4, V_CHOEUR]:
			var s4 := _spell(V_CHOEUR, "Chœur des roseaux", 4, CHOEUR_COEF, ULT_CD)
			s4.radius_u = CHOEUR_RADIUS_U
			s4.duration = CHOEUR_DURATION_S
			s4.proc_coef = 0.8
			s4.hit_force = 0.6
			s4.trigger_range_u = 3.0
			s4.vfx_frames = LAND_RING_FRAMES
			s4.vfx_radius_px = LAND_RING_RADIUS_PX
			s4.vfx_floor_aspect = 1.0
			return s4
	return null


# --- Mise en place ------------------------------------------------------------------------------

func setup(p: CharacterBody2D) -> void:
	player = p
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	if ResourceLoader.exists(TONGUE_FRAMES):
		_tongue_frames = load(TONGUE_FRAMES) as SpriteFrames
	_shadow = RainetteShadow.new()
	_shadow.name = "RainetteShadow"
	p.add_child(_shadow)
	p.move_child(_shadow, 0) # sous le sprite
	Events.floor_started.connect(_on_floor_started)
	Events.player_died.connect(_on_player_died)
	if p.has_signal(&"action_impact"):
		p.action_impact.connect(_on_action_impact)


func _exit_tree() -> void:
	if Events.floor_started.is_connected(_on_floor_started):
		Events.floor_started.disconnect(_on_floor_started)
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)
	clear_transients()


func _caster() -> SpellCaster:
	return player.spells if player != null else null


func _spell_of(slot: int) -> SpellData:
	for s in player.character.spells:
		if s.slot == slot:
			return s
	return null


func _u(v: float) -> float:
	return v * Balance.UNIT_PX


# --- Hooks du joueur et de SpellCaster ----------------------------------------------------------

func is_airborne() -> bool:
	return state == State.AIR


func is_singing() -> bool:
	return ult_left > 0.0


## Plus de ressource : aucun sort n'est bloqué par l'état de Rainette.
func blocks_slot(_slot: int) -> bool:
	return false


## Le bond arrière est permis partout sauf pendant le Grand saut (engagé).
func can_dodge() -> bool:
	return not (hop_is_leap and (state == State.CROUCH or state == State.AIR))


func speed_mult() -> float:
	return 1.0


func inertia_s() -> float:
	return 0.0


func slow_immune() -> bool:
	return false


func locks_facing() -> bool:
	return false


func dodge_ghosts() -> bool:
	return false # le bond se lit par l'arc et l'ombre


func dodge_label() -> String:
	return "Bond"


## Distance du Bond (esquive) : +50 % depuis une flaque de Gluant (comme les bonds), docs/Design_Combos.md §5.3.
func dodge_distance_u() -> float:
	return BACK_HOP_U * (1.0 + GOO_HOP_BONUS) if in_goo() else BACK_HOP_U


## Monstre étourdi, emprisonné ou collé dans une flaque : la cible de « Langue sur étourdi ».
func _is_held(e: Node) -> bool:
	if not is_instance_valid(e) or not (e is Node2D):
		return false
	if e.has_method(&"is_stunned") and e.is_stunned():
		return true
	if e.has_method(&"is_imprisoned") and e.is_imprisoned():
		return true
	return RainetteGoo.contains((e as Node2D).global_position)


## SpellCaster.compute_damage : coef additif de combo. Grand saut sur un collé : +0,3 ; Langue principale sur un étourdi : 1,1 -> 1,6.
func combo_coef_add(s: SpellData, enemy: Node) -> float:
	if s.slot == 2 and s.id == &"rainette_grand_saut" and enemy != null and _crush_ids.has(enemy.get_instance_id()):
		return CRUSH_ADD
	if s.slot == 1 and s.id == &"rainette_langue" and s != _line_sd and _is_held(enemy):
		return TONGUE_STUN_COEF - TONGUE_COEF
	return 0.0


## SpellCaster.deal_damage : chiffre en accent et son lourd pour ces coups.
func combo_hit(s: SpellData, enemy: Node) -> bool:
	return combo_coef_add(s, enemy) > 0.0


## Fenêtre de combo du slot 2 (HUD : le bouton pulse) : une flaque de Gluant à portée de saut. Sans boucle sur les monstres.
func combo_ready(slot: int) -> bool:
	if slot != 2 or player == null or not is_inside_tree():
		return false
	var s := _spell_of(2)
	if s == null or s.id != &"rainette_grand_saut":
		return false
	var reach := _u(s.range_u + CRUSH_READY_RANGE_U) * (1.0 + float(player.stat(&"range_add")))
	for g in RainetteGoo.live:
		if is_instance_valid(g) and not g.mini and not g.is_ending() 				and g.global_position.distance_to(player.global_position) <= reach + g.radius:
			return true
	return false


## Auto-cast (jamais en manuel) : le Grand saut attend le Gluant s'il revient dans la seconde et qu'aucune flaque n'est posée.
func auto_cast_ok(slot: int) -> bool:
	if slot != 2 or _caster() == null:
		return true
	var s := _spell_of(2)
	if s == null or s.id != &"rainette_grand_saut" or not _caster().has_slot(3):
		return true
	var rem := _caster().cooldown_remaining(3)
	if rem <= 0.0 or rem > AUTO_WAIT_GOO_S:
		return true
	for g in RainetteGoo.live:
		if is_instance_valid(g) and not g.mini and not g.is_ending():
			return true
	return false


func dodge_sound() -> Array:
	return [&"spell.rainette_grand_saut.cast_light", -8.0, 1.3]


## En l'air : intouchable au contact (coup d'un monstre à portée de contact, boss compris depuis l'équilibrage du
## 22/10/2026 : elle bondit par-dessus) ; les projectiles touchent toujours.
func ignores_hit(source: Node) -> bool:
	if state != State.AIR or source == null or not is_instance_valid(source) or not (source is Node2D):
		return false
	var r: float = float(source.get(&"radius_px")) if &"radius_px" in source else 20.0
	var reach := r + 26.0 + _u(CONTACT_MARGIN_U)
	return (source as Node2D).global_position.distance_to(player.global_position) <= reach


## Bond arrière : la roulade part à reculons. Sans direction de déplacement : recule depuis le curseur /
## l'avant (elle garde la menace en face) ; sinon elle saute là où pousse le joystick, tournée vers l'arrière.
func dodge_motion_dir(dir: Vector2) -> Vector2:
	return -dir if _no_move_input() else dir


func on_dodge_start(dir: Vector2) -> void:
	_abort_hop()
	player.facing = dir if _no_move_input() else -dir


func _no_move_input() -> bool:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() < 0.0001


func cast_spell(s: SpellData, aim: Variant) -> bool:
	match s.slot:
		1:
			if s.id == V_CROAK:
				return _cast_croak(s)
			return _cast_tongue(s)
		2:
			return _cast_leap(s, aim)
		3:
			return _cast_goo(s, aim)
		4:
			_pending[ult_action()] = {"spell": s}
			return true
	return false


func action_for(s: SpellData) -> StringName:
	match s.slot:
		1:
			return &"attack"
		3:
			return &"spit"
		4:
			return ult_action()
	return &"" # Grand saut : anims d'état (crouch, leap, land)


func ult_action() -> StringName:
	if _visual != null and _visual.sprite_frames != null:
		for a: StringName in [&"belch", &"cast_ult"]:
			if _visual.sprite_frames.has_animation(StringName("%s_s" % a)):
				return a
	return &"belch"


func on_cast(_s: SpellData) -> void:
	pass


func has_pending() -> bool:
	return not _pending.is_empty()


func _on_action_impact(base: StringName) -> void:
	if not _pending.has(base):
		return
	var pend: Dictionary = _pending[base]
	_pending.erase(base)
	if player == null or player.dead:
		return
	var s: SpellData = pend["spell"]
	match s.slot:
		1:
			if pend.has("croak"):
				_croak(s)
			else:
				_lash(s, pend["target"], pend["dir"])
		3:
			if s.id == V_BULLE:
				_spawn_bubble(s, pend["aim"])
			else:
				_spawn_goo(s, pend["aim"])
		4:
			_start_song(s)


# --- Locomotion S11 (Player._physics_process, hors roulade) --------------------------------------

## Pilote le déplacement : `dir` = consigne du joystick / clavier (vecteur logique).
func locomote(dir: Vector2, delta: float) -> void:
	if player == null or player.dead:
		return
	player.velocity = Vector2.ZERO
	var active := dir.length_squared() > 0.0001
	_hop_buf = maxf(_hop_buf - delta, 0.0)
	if active and not _dir_active and state != State.GROUND: # appui franc pendant un bond : tampon d'entrée
		_hop_buf = INPUT_BUFFER_S
		_hop_buf_dir = dir.normalized()
	_dir_active = active
	match state:
		State.GROUND:
			if _queued_leap != null:
				_begin_queued_leap()
			else:
				var want := _hop_request(dir)
				if want != Vector2.ZERO:
					_try_hop(want, not active)
		State.CROUCH:
			state_left -= delta
			if state_left <= 0.0:
				_takeoff()
		State.AIR:
			if active and not hop_is_leap: # virage doux vers le joystick : un bond se corrige en l'air
				var turn := clampf(hop_dir.angle_to(dir.normalized()), -AIR_TURN_RAD_S * delta, AIR_TURN_RAD_S * delta)
				hop_dir = hop_dir.rotated(turn)
				player.facing = hop_dir
			_air_step(delta)
		State.LAND:
			state_left -= delta
			if state_left <= 0.0:
				state = State.GROUND
				if _queued_leap != null:
					_begin_queued_leap()
				else: # bonds enchaînés sans frame morte
					var want := _hop_request(dir)
					if want != Vector2.ZERO:
						_try_hop(want, not active)
	player.is_moving = state == State.AIR


## Direction du prochain bond : le joystick tenu, sinon l'appui franc encore dans le tampon, sinon rien.
func _hop_request(dir: Vector2) -> Vector2:
	if dir.length_squared() > 0.0001:
		return dir.normalized()
	if _hop_buf > 0.0:
		return _hop_buf_dir
	return Vector2.ZERO


func _hop_mult() -> float:
	# items de vitesse et ralentissements : la longueur du bond (la durée reste fixe : rythme lisible)
	return player.move_speed() / maxf(_u(SPEED_U), 1.0)


func in_goo() -> bool:
	return RainetteGoo.contains(player.global_position)


func _try_hop(dir: Vector2, from_buffer := false) -> bool:
	if state != State.GROUND:
		return false
	var singing := ult_left > 0.0
	if from_buffer:
		buffered_hops += 1
	_hop_buf = 0.0
	var dist := _u(HOP_DIST_U) * _hop_mult()
	if in_goo():
		dist *= 1.0 + GOO_HOP_BONUS
	hop_is_leap = false
	hop_air_total = HOP_AIR_S
	hop_height_u = HOP_HEIGHT_U
	if singing and not choir: # le Chœur garde des bonds normaux
		dist *= ULT_HOP_MULT
		hop_air_total *= ULT_AIR_MULT
		hop_height_u *= ULT_HEIGHT_MULT
	hop_dir = dir
	hop_speed_px = dist / hop_air_total
	player.facing = dir
	state = State.AIR
	state_left = hop_air_total
	hop_count += 1
	Audio.play(&"step.player", player.global_position, -2.0, 1.25 if not (singing and not choir) else 0.9)
	return true


func _air_step(delta: float) -> void:
	var step := minf(delta, state_left)
	state_left -= delta
	var motion := hop_dir * hop_speed_px * step
	player.velocity = hop_dir * hop_speed_px
	var col := player.move_and_collide(motion) # masque monde : les monstres passent dessous, les murs arrêtent
	if col != null:
		var rest := col.get_remainder().slide(col.get_normal())
		if rest.length_squared() > 0.01:
			player.move_and_collide(rest)
	if state_left <= 0.0:
		_land()


func _land() -> void:
	landings += 1
	var pos := player.global_position
	var leap := hop_is_leap
	hop_is_leap = false
	state = State.LAND
	state_left = HOP_LAND_S
	player.velocity = Vector2.ZERO
	if leap:
		_leap_impact(pos)
		_ricochet_chain()
		if choir:
			_spawn_mini_goo(pos)
	if ult_left > 0.0 and not leap: # audit 23/10 (P5) : Grand saut pendant le Chant = un seul impact (le plus fort : celui du saut)
		_ult_landing(pos)
	if not leap and ult_left <= 0.0:
		Audio.play(&"step.player", pos, -4.0, 0.8)


func _abort_hop() -> void:
	if state == State.AIR or state == State.CROUCH or state == State.LAND:
		state = State.GROUND
	hop_is_leap = false
	state_left = 0.0


# --- Sort 1 : Langue ------------------------------------------------------------------------------

func _tongue_range_px(s: SpellData) -> float:
	return _u(s.range_u) * (1.0 + player.stat(&"range_add"))


func _cast_tongue(s: SpellData) -> bool:
	if _caster() == null:
		return false
	var near := _caster().nearest_enemies(player.global_position, _tongue_range_px(s), 1)
	if near.is_empty():
		return false # aucun coup, aucune recharge
	var target: Node2D = near[0]
	var dir := target.global_position - player.global_position
	dir = dir.normalized() if dir.length_squared() > 1.0 else player.facing
	if state != State.AIR: # en l'air, l'orientation suit le bond engagé
		player.facing = dir
	_pending[&"attack"] = {"spell": s, "target": target, "dir": dir}
	return true


## Coup de langue (frame d'impact de `attack`) : fouet de toute sa longueur (4,5 u) vers la cible, tout ce qui
## est sur la ligne est frappé et tiré vers elle.
func _lash(s: SpellData, target: Variant, dir0: Vector2) -> void:
	var origin := player.global_position
	var max_len := _tongue_range_px(s)
	var dir := dir0
	var length := max_len # le fouet claque toujours à pleine longueur
	if target != null and is_instance_valid(target) and (target as Node2D).is_inside_tree() \
			and bool((target as Node2D).get(&"active") if &"active" in target else true):
		var d: Vector2 = (target as Node2D).global_position - origin
		if d.length_squared() > 1.0:
			dir = d.normalized()
	else: # cible disparue : la langue claque dans le vide vers le plus proche, sinon tout droit
		var near := _caster().nearest_enemies(origin, max_len, 1)
		if not near.is_empty():
			var d2: Vector2 = (near[0] as Node2D).global_position - origin
			if d2.length_squared() > 1.0:
				dir = d2.normalized()
	_spawn_tongue_vfx(dir, length)
	var half := _u(TONGUE_WIDTH_U)
	var hit: Array = []
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		var v: Vector2 = (e as Node2D).global_position - origin
		var along := v.dot(dir)
		var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
		if along < -er or along > length + er:
			continue
		if absf(v.cross(dir)) > half + er:
			continue
		hit.append(e)
	var primary := _tongue_primary(hit, origin)
	var line_sd := _tongue_line_spell(s)
	var held := primary != null and s.id == &"rainette_langue" and _is_held(primary) # Langue sur étourdi (docs/Design_Combos.md §5.3)
	for e in hit:
		# source au-delà de la cible : le recul la TIRE vers Rainette
		_caster().deal_damage(e, s if e == primary else line_sd, {"source_pos": (e as Node2D).global_position + dir * Balance.UNIT_PX})
		_check_swallow(e)
	if held and is_instance_valid(primary) and primary.has_method(&"push") and not _is_dead(primary):
		primary.push(-dir * _u(TONGUE_STUN_PULL_U - TONGUE_PULL_U)) # traction 0,25 -> 0,75 u
	LightRig.flash(origin + dir * length * 0.5, LIGHT, 0.12)


## Cible principale de la ligne : le boss, sinon l'élite, sinon le monstre le plus proche de Rainette.
func _tongue_primary(hit: Array, origin: Vector2) -> Node:
	var best: Node = null
	var best_score := -1
	var best_d := INF
	for e in hit:
		var score := 0
		if e.is_in_group(&"bosses") or e.get(&"is_boss") == true:
			score = 2
		elif e.get(&"is_elite") == true:
			score = 1
		var d: float = (e as Node2D).global_position.distance_squared_to(origin)
		if score > best_score or (score == best_score and d < best_d):
			best = e
			best_score = score
			best_d = d
	return best


## Copie de la Langue au coef de ligne (mise en cache : le sort ne change pas en cours de run).
func _tongue_line_spell(s: SpellData) -> SpellData:
	if _line_sd == null or _line_src != s:
		_line_src = s
		_line_sd = s.duplicate() as SpellData
		_line_sd.coef = TONGUE_LINE_COEF
	return _line_sd


## Un T1 tué par la Langue est avalé : +1 % PV max (sac vocal qui palpite).
func _check_swallow(e: Node) -> void:
	if not is_instance_valid(e) or not (&"tier" in e) or int(e.get(&"tier")) != 1:
		return
	if &"is_boss" in e and bool(e.get(&"is_boss")):
		return
	var dead_now := (&"active" in e and not bool(e.get(&"active"))) or (&"hp" in e and float(e.get(&"hp")) <= 0.0)
	if not dead_now:
		return
	swallowed += 1
	RunState.add_counter(COUNTER_SWALLOWED) # déblocage du Chœur des roseaux
	player.heal(SWALLOW_HEAL_PCT * player.max_hp)
	Audio.play(&"pickup.xp", player.global_position, -6.0, 0.55)


func _spawn_tongue_vfx(dir: Vector2, length_px: float) -> void:
	if _tongue_frames == null or player == null:
		return
	var bb := Node2D.new()
	bb.name = "TongueFX"
	bb.scale = Iso.UNSQUASH # espace billboard (= écran)
	bb.z_index = 1
	player.add_child(bb)
	var spr := AnimatedSprite2D.new()
	spr.centered = false
	spr.offset = -TONGUE_ORIGIN_PX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sd := Iso.to_screen_dir(dir)
	spr.position = sd * _u(TONGUE_FORWARD_U) + Vector2(0.0, Iso.lift_px(TONGUE_MOUTH_U) + _visual_lift_px())
	spr.rotation = sd.angle()
	var screen_len := length_px * sd.length()
	spr.scale = Vector2(maxf(screen_len, 8.0) / TONGUE_FRAME_LEN_PX, Iso.SPRITE_K)
	bb.add_child(spr)
	EmissiveOverlay.apply(spr, _tongue_frames)
	spr.play(&"default")
	spr.animation_finished.connect(bb.queue_free)
	last_tongue = bb


# --- Variante Croassement (sort 1) -----------------------------------------------------------------

func _croak_radius_px(s: SpellData) -> float:
	return _u(s.radius_u) * (1.0 + player.stat(&"zone_size_add"))


func _cast_croak(s: SpellData) -> bool:
	if _caster() == null:
		return false
	var near := _caster().nearest_enemies(player.global_position, _croak_radius_px(s), 1)
	if near.is_empty():
		return false # aucun croassement, aucune recharge
	var d: Vector2 = (near[0] as Node2D).global_position - player.global_position
	if d.length_squared() > 1.0 and state != State.AIR:
		player.facing = d.normalized()
	_pending[&"attack"] = {"spell": s, "croak": true}
	return true


## Anneau autour de Rainette (frame d'impact de `attack`) ; chaque T1 tué raccourcit la recharge du Grand saut.
func _croak(s: SpellData) -> void:
	var pos := player.global_position
	var r := _croak_radius_px(s)
	var smalls: Array = []
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and (e as Node2D).global_position.distance_to(pos) <= r and _is_small(e):
			smalls.append(e)
	var z := s.duplicate() as SpellData
	z.behavior = SpellData.Behavior.NOVA
	z.duration = 0.0
	_caster().spawn_zone(z, pos)
	var killed := 0
	for e in smalls:
		if _is_dead(e):
			killed += 1
	if killed > 0:
		croak_cd_gain += _caster().reduce_cooldown(2, minf(CROAK_CD_GAIN_S * float(killed), CROAK_CD_GAIN_MAX_S))
		Audio.play(&"pickup.xp", pos, -8.0, 0.55)
	LightRig.flash(pos, LIGHT, 0.12)
	Audio.play(&"pickup.xp", pos, -8.0, 0.7)


func _is_small(e: Node) -> bool:
	return &"tier" in e and int(e.get(&"tier")) == 1 and not (&"is_boss" in e and bool(e.get(&"is_boss")))


func _is_dead(e: Node) -> bool:
	if not is_instance_valid(e):
		return true
	return (&"active" in e and not bool(e.get(&"active"))) or (&"hp" in e and float(e.get(&"hp")) <= 0.0)


# --- Variante Ricochet (sort 2) ---------------------------------------------------------------------

## Atterrissage du premier bond du Ricochet : le second part tout de suite (file de bonds, visée rafraîchie).
## Le joueur n'a qu'à viser ; aucun second appui à réussir, aucun déplacement imposé.
func _ricochet_chain() -> void:
	var s := _leap_spell
	if s == null or s.id != V_RICOCHET:
		return
	if _ric_second:
		_ric_second = false
		return
	_queued_leap = {"spell": s, "aim": null, "chain": true}


# --- Sort 2 : Grand saut --------------------------------------------------------------------------

func _cast_leap(s: SpellData, aim: Variant) -> bool:
	if hop_is_leap and (state == State.CROUCH or state == State.AIR):
		return false
	if state == State.AIR or player.is_dodging(): # pressé en plein bond / bond arrière : part dès qu'elle touche le sol
		_queued_leap = {"spell": s, "aim": aim}
		return true
	if state == State.LAND: # les 0,1 s d'atterrissage ne retardent pas le saut
		_abort_hop()
	_start_leap(s, aim)
	return true


func _begin_queued_leap() -> void:
	var q: Dictionary = _queued_leap
	_queued_leap = null
	var sp: SpellData = q["spell"]
	_ric_second = bool(q.get("chain", false))
	if _ric_second:
		ric_chains += 1
	_start_leap(sp, _fresh_aim(sp, q["aim"]))


## Visée au moment du départ (le curseur ou le paquet ont bougé pendant l'attente) ; repli : la visée de l'appui.
func _fresh_aim(s: SpellData, stale: Variant) -> Variant:
	var c := _caster()
	if c == null:
		return stale
	var px: float = _u(s.range_u) * (1.0 + float(player.stat(&"range_add")))
	var a: Variant = c.get_manual_aim_point(px)
	if a == null and s.target_mode == &"densest":
		a = c.densest_point(px)
	return a if a != null else stale


func _start_leap(s: SpellData, aim: Variant) -> void:
	var origin := player.global_position
	var to: Vector2
	if aim != null and ((aim as Vector2) - origin).length_squared() > 1.0:
		to = (aim as Vector2) - origin
	else:
		to = player.facing * _u(s.range_u)
	var ric := s.id == V_RICOCHET
	var air := RIC_AIR_S if ric else LEAP_AIR_S
	var max_px: float = _u(s.range_u) * (1.0 + player.stat(&"range_add"))
	var dist := clampf(to.length(), _u(LEAP_MIN_U), max_px)
	hop_dir = to.normalized() if to.length_squared() > 1.0 else player.facing
	_leap_target = origin + hop_dir * dist
	_leap_spell = s
	hop_is_leap = true
	hop_air_total = air
	hop_height_u = RIC_HEIGHT_U if ric else LEAP_HEIGHT_U
	hop_speed_px = dist / air
	player.facing = hop_dir
	state = State.CROUCH # sort aussi de l'essoufflement
	state_left = RIC_CROUCH_S if ric else LEAP_CROUCH_S


func _takeoff() -> void:
	state = State.AIR
	state_left = hop_air_total
	hop_count += 1
	Audio.play(&"step.player", player.global_position, 0.0, 0.7)


func _leap_impact(pos: Vector2) -> void:
	var s := _leap_spell if _leap_spell != null else _spell_of(2)
	var goo: RainetteGoo = _crush_goo_at(pos) if s.id == &"rainette_grand_saut" else null
	_crush_ids.clear()
	if goo != null: # Écrasement : les monstres collés dans la flaque où elle atterrit
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e is Node2D and is_instance_valid(e) and (e as Node2D).global_position.distance_to(goo.global_position) <= goo.radius:
				_crush_ids[e.get_instance_id()] = true
	var z := s.duplicate() as SpellData
	z.behavior = SpellData.Behavior.NOVA
	z.duration = 0.0
	_caster().spawn_zone(z, pos)
	var r: float = _u(s.radius_u) * (1.0 + player.stat(&"zone_size_add"))
	var ric := s.id == V_RICOCHET
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and e.has_method(&"stun") and (e as Node2D).global_position.distance_to(pos) <= r:
			var crushed := _crush_ids.has(e.get_instance_id())
			e.stun(RIC_STUN_S if ric else (CRUSH_STUN_S if crushed else LEAP_STUN_S))
			if not ric and e.get(&"is_boss") != true:
				RunState.add_counter(COUNTER_LEAP_STUNS) # déblocage du Ricochet
	_crush_ids.clear()
	if goo != null:
		goo.burst(_caster(), GOO_BURST_COEF, GOO_BURST_END_SPEED) # la flaque éclate, consommée
	player.grant_invulnerability(RIC_GRACE_S if ric else LEAP_GRACE_S)
	LightRig.flash(pos, LIGHT, 0.4, {"radius": 1.6})
	Audio.play(&"enemy.shockwave.heavy", pos, -3.0, 1.25)
	_shake(LEAP_SHAKE_PX)


## Flaque de Gluant (hors mini-flaques du Chœur) qui contient `pos`, ou null.
func _crush_goo_at(pos: Vector2) -> RainetteGoo:
	for g in RainetteGoo.live:
		if is_instance_valid(g) and not g.mini and not g.is_ending() and g.global_position.distance_to(pos) <= g.radius:
			return g
	return null


func _shake(px: float) -> void:
	var n := player.get_parent()
	while n != null:
		if n.has_method(&"shake"):
			n.shake(px, 22.0, 0.2)
			return
		n = n.get_parent()


# --- Sort 3 : Gluant ------------------------------------------------------------------------------

func _cast_goo(s: SpellData, aim: Variant) -> bool:
	var origin := player.global_position
	var max_px: float = _u(s.range_u) * (1.0 + player.stat(&"range_add"))
	var at: Vector2
	if aim != null:
		at = origin + ((aim as Vector2) - origin).limit_length(max_px)
	else:
		var near := _caster().nearest_enemies(origin, max_px, 1)
		at = (near[0] as Node2D).global_position if not near.is_empty() else origin + player.facing * _u(3.0)
	var d := at - origin
	if d.length_squared() > 1.0 and state != State.AIR:
		player.facing = d.normalized()
	_pending[&"spit"] = {"spell": s, "aim": at}
	return true


func _spawn_goo(s: SpellData, at: Vector2) -> void:
	var r: float = _u(s.radius_u) * (1.0 + player.stat(&"zone_size_add"))
	for e in get_tree().get_nodes_in_group(&"enemies"): # éclaboussure : un coup à l'arrivée
		if e is Node2D and is_instance_valid(e) and (e as Node2D).global_position.distance_to(at) <= r:
			_caster().deal_damage(e, s, {"source_pos": at})
	_spawn_goo_glob(at)
	var g := RainetteGoo.new()
	g.setup(at, r, s.duration, GOO_SLOW_PCT, _u(GOO_PULL_U_S), s)
	player.get_parent().add_child(g)
	g.global_position = at
	Audio.play(&"status.poison.light", at, 0.0, 0.7)


## Crachat de Gluant (visuel seul) : billboard qui suit une parabole de la bouche au centre de la flaque.
func _spawn_goo_glob(at: Vector2) -> void:
	if player == null or player.get_parent() == null or not ResourceLoader.exists(GOO_PROJECTILE_FRAMES):
		return
	var sf := load(GOO_PROJECTILE_FRAMES) as SpriteFrames
	if sf == null or not sf.has_animation(&"default"):
		return
	var from := player.global_position
	var bb := Node2D.new()
	bb.name = "GooGlob"
	bb.scale = Iso.UNSQUASH # espace billboard (= écran)
	bb.z_index = 1
	player.get_parent().add_child(bb)
	bb.global_position = from
	var spr := AnimatedSprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.scale = Vector2(Iso.SPRITE_K, Iso.SPRITE_K)
	spr.rotation = Iso.to_screen_dir(at - from).angle()
	bb.add_child(spr)
	EmissiveOverlay.apply(spr, sf)
	spr.play(&"default")
	var h0 := TONGUE_MOUTH_U + lift_u()
	var fly := func(t: float) -> void:
		if not is_instance_valid(bb):
			return
		bb.global_position = from.lerp(at, t)
		spr.position.y = Iso.lift_px(h0 * (1.0 - t) + GOO_GLOB_ARC_U * 4.0 * t * (1.0 - t))
	var tw := bb.create_tween()
	tw.tween_method(fly, 0.0, 1.0, RainetteGoo.FADE_IN_S)
	tw.tween_callback(bb.queue_free)


# --- Variante Bulle (sort 3) -----------------------------------------------------------------------

func _spawn_bubble(s: SpellData, at: Vector2) -> void:
	var zone := 1.0 + float(player.stat(&"zone_size_add"))
	var b := RainetteBubble.new()
	b.setup(_caster(), s, _u(BULLE_CATCH_U) * zone, _u(s.radius_u) * zone, s.duration,
			_u(BULLE_PULL_U) / maxf(s.duration, 0.1), BULLE_BOSS_SLOW)
	player.get_parent().add_child(b)
	b.global_position = at
	b.capture()
	Audio.play(&"status.poison.light", at, 0.0, 0.9)


# --- Variante Chœur des roseaux (sort 4) ------------------------------------------------------------

func _mini_goo_spell() -> SpellData:
	if _mini_goo_sd == null:
		_mini_goo_sd = _spell(&"rainette_choeur_flaque", "Flaque", 3, 0.0, 0.0)
		_mini_goo_sd.vfx_frames = GOO_FRAMES
		_mini_goo_sd.vfx_radius_px = GOO_RADIUS_PX
		_mini_goo_sd.vfx_floor_aspect = 1.0
		_mini_goo_sd.light_preset = &"" # une lumière par mini-flaque coûterait trop cher
	return _mini_goo_sd


## Petite flaque (1,5 u, 2 s, -40 %, sans attraction) laissée par un atterrissage du Chœur ; plafond de flaques vivantes.
func _spawn_mini_goo(pos: Vector2) -> void:
	var minis: Array = []
	for old in RainetteGoo.live:
		if is_instance_valid(old) and old.mini and not old.is_queued_for_deletion():
			minis.append(old)
	while minis.size() >= CHOEUR_GOO_MAX:
		(minis.pop_front() as Node).queue_free()
	var g := RainetteGoo.new()
	g.mini = true
	g.count_glued = false
	g.setup(pos, _u(CHOEUR_GOO_U) * (1.0 + float(player.stat(&"zone_size_add"))), CHOEUR_GOO_S, GOO_SLOW_PCT, 0.0, _mini_goo_spell())
	player.get_parent().add_child(g)
	g.global_position = pos


# --- Sort 4 : Chant de crue -----------------------------------------------------------------------

func _start_song(s: SpellData = null) -> void:
	choir = s != null and s.id == V_CHOEUR
	ult_left = s.duration if s != null and s.duration > 0.0 else ULT_DURATION_S
	if _sac_light == null:
		_sac_light = LightRig.attach(player, LIGHT_SAC)


func _end_song() -> void:
	ult_left = 0.0
	choir = false
	if _sac_light != null:
		_sac_light.release()
		_sac_light = null


func _ult_landing(pos: Vector2) -> void:
	var s := _spell_of(4)
	if s == null:
		return
	var z := s.duplicate() as SpellData
	z.behavior = SpellData.Behavior.NOVA
	z.duration = 0.0
	_caster().spawn_zone(z, pos)
	if choir:
		_spawn_mini_goo(pos)
	LightRig.flash(pos, LIGHT, 0.3, {"radius": 1.8})
	Audio.play(&"enemy.shockwave.heavy", pos, -6.0, 1.5)
	_shake(LEAP_SHAKE_PX * 0.5)


# --- Boucle (Player.tick, avant les sorts) --------------------------------------------------------

func tick(delta: float) -> void:
	if player == null:
		return
	_warn_gap = maxf(_warn_gap - delta, 0.0)
	_tick_spell_buffer(delta)
	if ult_left > 0.0:
		ult_left -= delta
		if ult_left <= 0.0:
			_end_song()
	_update_rig()


## Tampon de recharge (sorts 2-4) : un appui dans les 0,15 s avant la fin de la recharge part quand elle finit ;
## un appui franchement trop tôt fait un tic sourd (pas de jauge de recharge à clignoter ici : le bouton la montre).
func _tick_spell_buffer(delta: float) -> void:
	var c := _caster()
	if c == null:
		return
	for slot in [2, 3, 4]:
		if not c.has_slot(slot):
			continue
		if Input.is_action_just_pressed("spell_%d" % slot):
			var rem := c.cooldown_remaining(slot)
			if rem > 0.0 and rem <= INPUT_BUFFER_S:
				_spell_buf[slot] = INPUT_BUFFER_S
			elif rem > INPUT_BUFFER_S and _warn_gap <= 0.0:
				_warn_gap = WARN_GAP_S
				Audio.play(&"telegraph.warn_light", player.global_position, -14.0, 0.7)
	for slot in _spell_buf.keys():
		_spell_buf[slot] = float(_spell_buf[slot]) - delta
		var rem2 := c.cooldown_remaining(slot)
		if float(_spell_buf[slot]) <= 0.0 or rem2 > INPUT_BUFFER_S + 0.05 or c.is_slot_blocked(slot):
			_spell_buf.erase(slot) # expiré, ou lancé entre-temps par le tick normal
		elif rem2 <= 0.0:
			_spell_buf.erase(slot)
			if c.cast(slot):
				buffered_casts += 1


# --- Nettoyage ------------------------------------------------------------------------------------

func clear_transients() -> void:
	_pending.clear()
	_spell_buf.clear()
	_hop_buf = 0.0
	_queued_leap = null
	_ric_second = false
	RainetteGoo.clear_all()
	RainetteBubble.clear_all()
	if ult_left > 0.0 or _sac_light != null:
		_end_song()


func _on_floor_started(_n: int) -> void:
	clear_transients()


func _on_player_died() -> void:
	_abort_hop()
	clear_transients()
	if _visual != null:
		_visual.position.y = 0.0
	if _visual != null and _visual.sprite_frames != null:
		var anim := _resolve(&"death", _dir_name())
		if anim != &"":
			_visual.sprite_frames.set_animation_loop(anim, false)
			_visual.play(anim)


# --- Rendu ----------------------------------------------------------------------------------------

func _dir_name() -> String:
	var i := roundi(player.facing.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES[(i + 8) % 8]


func _resolve(base: StringName, dir: String) -> StringName:
	if _visual == null or _visual.sprite_frames == null:
		return &""
	for a: StringName in [StringName("%s_%s" % [base, dir]), base]:
		if _visual.sprite_frames.has_animation(a):
			return a
	return &""


## États du kit prioritaires (bond, accroupi, atterrissage, essoufflée, bond arrière) ; au sol : action en
## cours (attack / spit / belch) ou idle (elle ne court jamais : `run` n'est pas utilisée).
func visual_anim(fallback: StringName) -> StringName:
	var base := &""
	if player.is_dodging():
		base = &"dodge"
	else:
		match state:
			State.CROUCH:
				base = &"crouch"
			State.AIR:
				base = &"leap" if hop_is_leap else &"jump"
			State.LAND:
				base = &"land"
	if base != &"":
		var a := _resolve(base, _dir_name())
		if a != &"":
			return a
	if String(fallback).begins_with("run_"):
		return StringName(String(fallback).replace("run_", "idle_"))
	return fallback


## Hauteur courante du sprite (0 au sol) : arc sinus du bond / du bond arrière.
func lift_u() -> float:
	if player.is_dodging():
		return DODGE_HEIGHT_U * sin(PI * clampf(1.0 - player.dodge_progress_left(), 0.0, 1.0))
	if state == State.AIR and hop_air_total > 0.0:
		var k := clampf(1.0 - state_left / hop_air_total, 0.0, 1.0)
		return hop_height_u * sin(PI * k)
	return 0.0


func _visual_lift_px() -> float:
	return Iso.lift_px(lift_u())


func _update_rig() -> void:
	var h := lift_u()
	if _visual != null and not player.dead:
		_visual.position.y = Iso.lift_logical(h)
	if _shadow != null:
		(_shadow as RainetteShadow).set_height(h)
	if _sac_light != null:
		_sac_light.set_energy(1.0 + 0.35 * sin(Time.get_ticks_msec() * 0.012))



# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) ------------------------------------

static func passive_info() -> Dictionary:
	var f := KitResource.fmt
	return KitResource.passive("Avalement", &"avalement",
		"Rainette ne marche pas, elle bondit : sans jauge ni limite, et intouchable au contact en l'air. Sa Langue vise une cible principale (le boss, sinon l'élite, sinon le plus proche) et la frappe %s fois plus fort que le reste de la ligne." % f.call(TONGUE_COEF / TONGUE_LINE_COEF),
		"", "",
		"un petit monstre tué par la Langue est avalé : +%s des PV max." % KitResource.pct(SWALLOW_HEAL_PCT), false)
