class_name BourbeKit
extends Node
## Kit de Bourbe, la mère-vase de la Mangrove (docs/Design_Personnages.md §2.5) : invocatrice / mêlée,
## ressource = sa propre masse. 4 sorts / 0 passif. Données : character(). Logique d'état : ce nœud, enfant
## « Kit » du joueur, interrogé par les hooks (blocks_slot, cast_spell, speed_mult, can_dodge, max_hp_mult…).
## - Masse (retour joueur 23/10/2026 : retour au modèle d'origine « la masse ») : chaque motte détachée retire
##   temporairement MASS_PER_MOTTE (15 %) des PV MAX (la masse quitte le corps) ; les PV actuels sont seulement
##   plafonnés au nouveau max (jamais mortel : le max ne descend pas sous MAX_HP_FLOOR_FRAC = 40 % = 4 mottes).
##   Détacher n'est JAMAIS refusé à cause des PV actuels : seul le nombre de mottes dehors (4) limite.
##   Recollée = masse rendue × PV restants de la motte (+ les PV actuels rognés au lancer, au même prorata) ;
##   la part abîmée et une motte écrasée = masse perdue DEAD_MASS_S (8 s) puis rendue ; Bourbier et
##   changement d'étage rendent tout de suite toute la masse.
##   Plus elle se divise, plus elle est vive (+0,15 u/s par motte) et petite (hitbox 0,6 -> 0,45 u).
## - Sort 1 Gifle de vase : SpellData ARC (SpellCaster), vers l'ennemi le plus proche.
## - Sort 2 Détacher : 4 charges séquentielles de 3 s (gérées ici, en attendant S1) ; motte lancée en cloche
##   au point visé (5 u) à la frame d'impact de `throw` ; elle combat 10 s puis rampe vers Bourbe.
## - Sort 3 Rappel : toutes les mottes foncent vers elle, chaque monstre traversé prend coef 1,5.
## - Sort 4 Bourbier : 4 s enfoncée (invulnérable, immobile), zone 5 u (coef 1,0 / 0,5 s, ralentit 50 %),
##   les mottes fusionnent ; à la sortie, RISE_FREE_MOTTES (2) mottes jaillissent, gratuites (sans masse).
## Les sorts 2-4 sont Behavior.KIT (délégués au kit par SpellCaster) ; dispatch par id.
## Rendu : bourbe.tres (lot BO1) sinon Ardent teinté argile ; mottes : BourbeMotte (lot BO2) ; VFX lot BO3.

# --- Assets attendus (lots Codex BO1-BO3 : art/tools/night/_bo*.txt) ------------------------------
const ASSET_DIR := "res://assets/sprites/characters/bourbe/"
## idle/run 8, slap/throw/recall/sink/rise 4, attack, cast, cast_ult, death (×8 dir : <anim>_<dir>)
const SPRITE_FRAMES := ASSET_DIR + "bourbe.tres"
const MOTTE_FRAMES := ASSET_DIR + "motte/motte.tres" ## idle 6, run 6, die 4 (×8 dir), cellule 192
const BOG_ZONE_FRAMES := ASSET_DIR + "bog_zone/bog_zone.tres" ## TOP 8, `default` en boucle, `end` facultative
const ALLY_RING_FRAMES := ASSET_DIR + "ally_ring/ally_ring.tres" ## TOP, `default` (1 frame ou boucle)
const MUD_SLAP_FRAMES := ASSET_DIR + "mud_slap/mud_slap.tres" ## TOP 4, arc centré sur +X (Gifle)
const MUD_SPLASH_FRAMES := ASSET_DIR + "mud_splash/mud_splash.tres" ## TOP 6, gerbe (plouf, sortie du Bourbier)
const PLACEHOLDER_TINT := Color(0.42, 0.5, 0.52) ## Ardent teinté argile humide #2B3340 / bronze, en attendant BO1
const PLACEHOLDER_SCALE := 1.15 ## la golemme est plus massive qu'Ardent (repli seulement)

# --- Accent unique : feu follet vert froid (planche art/tools/characters/_cd_bourbe.png) -----------
const ACCENT := Color("#8DDBA8")
const MUD_COLOR := Color("#5F8F80") ## bronze vert-de-gris : contours de repli des zones
const LIGHT_SPELL := &"bourbe_follet"
const LIGHT_BOG := &"bourbe_bog"

# --- Statistiques (§2.5) ------------------------------------------------------------------------
const BASE_HP := 150.0
const HP_PER_LEVEL := 45.0
const ARMOR := 10.0
const BASE_REGEN := 1.5
const REGEN_PER_LEVEL := 0.3
const BASE_SPEED_U := 3.6
const SPEED_PER_MOTTE_U := 0.15
const HITBOX_U := 0.6
const HITBOX_MIN_U := 0.45 ## à MAX_MOTTES dehors
const DODGE_U := 2.5

# --- Masse et mottes ---------------------------------------------------------------------------
const MAX_MOTTES := 4
const MASS_PER_MOTTE := 0.15 ## masse d'une motte : 15 % des PV max (non divisés) retirés des PV MAX tant qu'elle est dehors
## Plancher des PV max : 1 − 4 × 15 % = 40 % (4 mottes dehors). La masse perdue (écrasée, part abîmée) au-delà
## ne fait pas descendre plus bas : Détacher n'est limité que par le nombre de mottes dehors.
const MAX_HP_FLOOR_FRAC := 0.4
const DEAD_MASS_S := 8.0 ## masse perdue (motte écrasée, part abîmée d'une motte recollée) : rendue après 8 s (règle d'origine)
const MOTTE_HP_FRAC := 0.15 ## PV d'une motte = 15 % des PV max (non divisés) de Bourbe
const MOTTE_SPEED_U := 3.8
const MOTTE_CHASE_U := 6.0 ## laisse : cibles à 6 u de Bourbe
const MOTTE_FOLLOW_U := 1.3
const MOTTE_FIGHT_S := 10.0
const MOTTE_RADIUS_U := 0.3
const MOTTE_CONTACT_COEF := 0.40 ## équilibrage 22/10 : 0,4 -> 0,45 -> 0,40 (soir) ; 23/10 (modèle masse) : voir §2.5
const MOTTE_CONTACT_INTERVAL_S := 0.8
const MOTTE_CONTACT_PROC := 0.5
const MOTTE_FLY_S := 0.35
const MOTTE_FLY_HEIGHT_U := 1.2
const MOTTE_LAND_COEF := 1.4 ## équilibrage 22/10 : 0,6 -> 1,0 -> 1,4 (soir : essaim −30 % au niv 1) ; « plouf » à l'atterrissage
const MOTTE_LAND_RADIUS_U := 2.0 ## équilibrage 22/10 : 1,0 -> 1,5 -> 2,0 (soir)
const MOTTE_LAND_PROC := 0.5
const MOTTE_FALLBACK_SCALE := 0.6 ## repli : sprite de Bourbe/Ardent réduit (motte 96 px dans 192)
const MOTTE_FALLBACK_TINT := Color(0.5, 0.62, 0.6)
const MOTTE_FOLLET_U := 0.35 ## hauteur du follet dessiné en repli
const ALLY_RING_U := 0.42
const ATTACH_U := 0.6
const DETACH_RANGE_U := 5.0
const DETACH_CHARGE_S := 3.0
const DETACH_LOCK_S := 0.35 ## entre deux lancers (durée du geste)
## Plus de plancher de PV actuels (retour joueur 23/10/2026 : « les invocations sont souvent impossibles » avec
## le refus sous 50 % de PV du 22/10 au soir). Détacher ne retire plus de PV actuels : jamais mortel par construction.

# --- Sorts -------------------------------------------------------------------------------------
const SLAP_COEF := 1.0
const SLAP_INTERVAL_S := 0.8
const SLAP_RADIUS_U := 2.0 ## équilibrage 22/10 : 1,5 -> 2,0 (essaim −30 % à l'origine)
const SLAP_SPREAD_DEG := 210.0 ## équilibrage 22/10 : 150° -> 210° (la vase gifle autour d'elle ; essaim −30 %)
const SLAP_KNOCK_U := 0.45
const RECALL_COEF := 1.5
const RECALL_CD := 6.0
const RECALL_SPEED_U := 12.0
const RECALL_WIDTH_U := 0.45
const RECALL_KNOCK_U := 0.8
const BOG_COEF := 1.2 ## équilibrage 22/10 : 1,0 -> 1,4 ; soir : 1,2 (cible unique +24 % au niv 12)
const BOG_CD := 22.0
const BOG_RADIUS_U := 5.0
const BOG_DURATION_S := 4.0
const BOG_TICK_S := 0.5
const BOG_PROC := 0.3
const BOG_SLOW_PCT := 0.5
const BOG_SLOW_REFRESH_S := 0.25
const BOG_SLOW_DURATION_S := 0.6
const RISE_COEF := 1.0 ## gerbe de sortie (ajout : la remontée frappe)
const RISE_RADIUS_U := 2.0
## Équilibrage 22/10/2026 (simulateur : dégâts subis ×3-4 vs Ardent, 4 morts au niveau 1 contre le mini-boss).
## Vase compacte : sans motte dehors elle encaisse mieux (−COMPACT_REDUCTION), l'avantage fond par motte détachée.
## Audit 23/10 (docs/Equilibrage_Personnages.md P4) : les mottes ne provoquent PLUS les boss ni les mini-boss
## (0 dégât subi sur mini-boss au simulateur) ; 2 mottes gratuites à la sortie du Bourbier au lieu de 4.
const COMPACT_REDUCTION := 0.3
const RISE_FREE_MOTTES := 2 ## mottes gratuites à la sortie du Bourbier (audit 23/10 : 4 -> 2)
const RISE_RING_U := 1.2 ## les mottes gratuites jaillissent sur cet anneau

# --- Variantes de sorts (docs/Variantes_Sorts.md §2.8 ; CONTRACTS.md « Variantes de sorts ») --------------------
## Coefficients calés par balance_sim (chaque variante à ±15 % du sort de base) ; le style ne change pas.
const V_CRACHAT := &"bourbe_crachat_de_vase" ## slot 1, remplace la Gifle de vase
const V_BOUTURE := &"bourbe_bouture" ## slot 2, remplace Détacher
const V_ECLAT := &"bourbe_eclatement" ## slot 3, remplace le Rappel
const V_MAREE := &"bourbe_maree_de_vase" ## slot 4, remplace le Bourbier
const VAR_DIR := ASSET_DIR + "variants/" ## VFX des variantes (lot Codex BOUV), absents = replis dessinés
const GLOB_FRAMES := VAR_DIR + "mud_glob/mud_glob.tres" ## CREA 3 : boule d'argile (Crachat), repli dessiné
const MUD_BURST_FRAMES := VAR_DIR + "mud_burst/mud_burst.tres" ## TOP 6 : gerbe d'Éclatement, repli = mud_splash
const SHIELD_FRAMES := VAR_DIR + "bourbe_shield/bourbe_shield.tres" ## couche de vase de la Marée, repli teinté
const CRACHAT_COEF := 1.0
const CRACHAT_INTERVAL_S := 0.8
const CRACHAT_RANGE_U := 6.0
const CRACHAT_RADIUS_U := 1.2
const CRACHAT_PROC := 0.8
const CRACHAT_SLOW_PCT := 0.25
const CRACHAT_SLOW_S := 1.0
const CRACHAT_KNOCK_U := 0.2
const CRACHAT_FLY_S := 0.45
const CRACHAT_ARC_U := 0.8
const BIG_MAX_CHARGES := 2 ## Bouture : 2 charges
const BIG_CHARGE_S := 6.0
const BIG_WEIGHT := 2 ## une grosse motte occupe 2 places sur MAX_MOTTES
const BIG_MASS_FRAC := 0.30 ## masse d'une grosse motte : 30 % des PV max
const BIG_HP_FRAC := 0.30
const BIG_CONTACT_COEF := 0.9
const BIG_CONTACT_PROC := 0.6
const BIG_SPEED_U := 3.6
const BIG_FIGHT_S := 15.0
const BIG_RADIUS_U := 0.45
const BIG_RING_U := 0.6
const BIG_SCALE := 1.5
const ECLAT_COEF := 2.0
const ECLAT_CD := 6.0
const ECLAT_RADIUS_U := 1.5
const ECLAT_MIN_FRAC := 0.5 ## coef x max(PV restants / PV max de la motte, 0,5)
const ECLAT_KNOCK_U := 0.8
const ECLAT_SLOW_PCT := 0.30
const ECLAT_SLOW_S := 1.0
const TIDE_CD := 22.0
const TIDE_DURATION_S := 6.0
const TIDE_SHIELD_FRAC := 0.5 ## bouclier = 50 % des PV max
const TIDE_SCALE := 1.35
const TIDE_HITBOX_U := 0.75
const TIDE_RADIUS_MULT := 1.5 ## auto : rayon x1,5, coef x1,3
const TIDE_COEF_MULT := 1.3
const TIDE_FREE_MOTTES := 4
## Compteurs de déblocage (RunState.add_counter -> Profile.stats ; règles « counter » de characters.json)
const COUNTER_RECALLED := "bourbe_mottes_recalled" ## motte recollée (retour, Rappel, Bourbier, étage)
const COUNTER_RAPPEL_HITS := "bourbe_rappel_hits" ## monstre écrasé par le Rappel (adapte hits_by_spell:rappel)
const COUNTER_MINIBOSS4 := "bourbe_miniboss_4mottes" ## mini-boss tué avec 4 mottes dehors
const TIDE_TINT := Color(0.62, 1.0, 0.78)

## Anims d'action (Player.play_action). Chaque sort essaie sa base, puis le repli d'Ardent (attack/cast/cast_ult).
const ACTIONS := {
	&"gifle_de_vase": [&"slap", &"attack"],
	&"detacher": [&"throw", &"cast"],
	&"rappel": [&"recall", &"cast"],
	&"bourbier": [&"sink", &"cast_ult"],
	&"rise": [&"rise", &"cast"],
	&"bourbe_crachat_de_vase": [&"slap", &"attack"],
	&"bourbe_bouture": [&"throw", &"cast"],
	&"bourbe_eclatement": [&"recall", &"cast"],
	&"bourbe_maree_de_vase": [&"cast_ult", &"cast"],
}
## Frames d'impact (index 0) : slap/throw/recall/sink/rise 4 frames -> 2 (N/2, brief BO1).
const ACTION_IMPACT_FRAMES := {&"slap": 2, &"throw": 2, &"recall": 2, &"sink": 2, &"rise": 2,
	&"attack": 2, &"cast": 2, &"cast_ult": 3}
const KIT_ACTIONS: Array[StringName] = [&"throw", &"recall", &"sink", &"cast", &"cast_ult"]
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

var player: CharacterBody2D = null
var mottes: Array[BourbeMotte] = []
var charges := MAX_MOTTES
var sunk_left := 0.0
var mottes_died := 0
var mottes_merged := 0
var dead_mass: Array = [] ## [fraction des PV max, secondes restantes] : masse perdue, rendue après DEAD_MASS_S
var bog_zone: Node2D = null
var _charge_t := 0.0
var _pending: Array = [] ## [base d'anim, Callable] en attente de la frame d'impact (Détacher, Rappel, Bourbier)
var _slow_t := 0.0
var _visual: AnimatedSprite2D = null
var _last_out := -1
var _heal_on_clear := 0.0
var _contact_spell: SpellData = null
var _land_spell: SpellData = null
var _recall_spell: SpellData = null
var _big_contact_spell: SpellData = null
var tide_left := 0.0 ## Marée de vase en cours (s restantes)
var _tide_shield := 0.0 ## part du bouclier encore à la Marée (retirée à la fin)
var _tide_saved: Dictionary = {} ## réglages du sort 1 avant la Marée
var _tide_base_scale := Vector2.ONE
var _tide_base_tint := Color.WHITE
var _silent_merge := false ## recollage sans compteur (Éclatement, Marée)
var _globs: Array = [] ## Crachats en vol : {node, from, to, t, spell, pos}


# --- Données -------------------------------------------------------------------------------------

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
	s.color = ACCENT
	s.light_preset = LIGHT_SPELL ## feu follet vert froid, jamais la braise d'Ardent
	return s


## Rayon (px de la frame) d'un VFX TOP livré : le disque/arc occupe ~90 % de la frame. 0 = absent.
static func _vfx_radius(path: String) -> float:
	if not ResourceLoader.exists(path):
		return 0.0
	var sf := load(path) as SpriteFrames
	if sf == null or not sf.has_animation(&"default") or sf.get_frame_count(&"default") == 0:
		return 0.0
	var t := sf.get_frame_texture(&"default", 0)
	return float(t.get_width()) * 0.45 if t != null else 0.0


static func _with_vfx(s: SpellData, path: String) -> void:
	var r := _vfx_radius(path)
	if r > 0.0:
		s.vfx_frames = path
		s.vfx_radius_px = r
		s.vfx_floor_aspect = 1.0 # rig TOP : jamais pré-écrasé


static func character() -> CharacterData:
	var c := CharacterData.new()
	c.id = &"bourbe"
	c.display_name = "Bourbe"
	c.base_hp = BASE_HP
	c.hp_per_level = HP_PER_LEVEL
	c.armor = ARMOR
	c.base_regen = BASE_REGEN
	c.regen_per_level = REGEN_PER_LEVEL
	c.base_speed_u = BASE_SPEED_U
	c.hitbox_u = HITBOX_U
	c.kit_script = BourbeKit
	c.sprite_frames_path = SPRITE_FRAMES
	c.placeholder_tint = PLACEHOLDER_TINT
	c.placeholder_scale = PLACEHOLDER_SCALE # repli : Ardent teinté, plus massif
	c.body_color = Color("#2B3340")
	c.accent_color = ACCENT
	c.dodge_distance_u = DODGE_U # roulade lourde (§2.5)
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"gifle_de_vase", "Gifle de vase", 1, SpellData.Behavior.ARC, SLAP_COEF, SLAP_INTERVAL_S)
	s1.is_auto = true
	s1.range_u = SLAP_RADIUS_U
	s1.radius_u = SLAP_RADIUS_U
	s1.spread_deg = SLAP_SPREAD_DEG
	s1.proc_coef = 1.0
	s1.trigger_range_u = SLAP_RADIUS_U
	s1.hit_force = _force_for(SLAP_KNOCK_U)
	_with_vfx(s1, MUD_SLAP_FRAMES)

	var s2 := _spell(&"detacher", "Détacher", 2, SpellData.Behavior.KIT, MOTTE_CONTACT_COEF, DETACH_LOCK_S)
	s2.range_u = DETACH_RANGE_U
	s2.radius_u = MOTTE_LAND_RADIUS_U
	s2.duration = MOTTE_FIGHT_S
	s2.proc_coef = MOTTE_CONTACT_PROC
	s2.target_mode = &"densest"
	s2.trigger_range_u = DETACH_RANGE_U
	s2.is_zone = false

	var s3 := _spell(&"rappel", "Rappel", 3, SpellData.Behavior.KIT, RECALL_COEF, RECALL_CD)
	s3.range_u = MOTTE_CHASE_U
	s3.proc_coef = 1.0
	s3.is_zone = false
	s3.trigger_range_u = MOTTE_CHASE_U
	s3.hit_force = _force_for(RECALL_KNOCK_U)

	var s4 := _spell(&"bourbier", "Bourbier", 4, SpellData.Behavior.KIT, BOG_COEF, BOG_CD)
	s4.radius_u = BOG_RADIUS_U
	s4.duration = BOG_DURATION_S
	s4.tick = BOG_TICK_S
	s4.proc_coef = BOG_PROC
	s4.trigger_range_u = 3.0
	s4.light_preset = LIGHT_BOG
	s4.color = MUD_COLOR
	_with_vfx(s4, BOG_ZONE_FRAMES)

	c.spells = [s1, s2, s3, s4]
	return c


## Variantes (contrat CONTRACTS.md) : SpellData de la variante `variant_id` pour `slot`, ou null (non codée).
static func variant(slot: int, variant_id: StringName) -> SpellData:
	match [slot, variant_id]:
		[1, V_CRACHAT]:
			var s1 := _spell(V_CRACHAT, "Crachat de vase", 1, SpellData.Behavior.KIT, CRACHAT_COEF, CRACHAT_INTERVAL_S)
			s1.is_auto = true
			s1.range_u = CRACHAT_RANGE_U
			s1.radius_u = CRACHAT_RADIUS_U
			s1.proc_coef = CRACHAT_PROC
			s1.trigger_range_u = CRACHAT_RANGE_U
			s1.hit_force = _force_for(CRACHAT_KNOCK_U)
			_with_vfx(s1, MUD_SPLASH_FRAMES)
			return s1
		[2, V_BOUTURE]:
			var s2 := _spell(V_BOUTURE, "Bouture", 2, SpellData.Behavior.KIT, BIG_CONTACT_COEF, DETACH_LOCK_S)
			s2.range_u = DETACH_RANGE_U
			s2.radius_u = MOTTE_LAND_RADIUS_U
			s2.duration = BIG_FIGHT_S
			s2.proc_coef = BIG_CONTACT_PROC
			s2.target_mode = &"densest"
			s2.trigger_range_u = DETACH_RANGE_U
			s2.is_zone = false
			return s2
		[3, V_ECLAT]:
			var s3 := _spell(V_ECLAT, "Éclatement", 3, SpellData.Behavior.KIT, ECLAT_COEF, ECLAT_CD)
			s3.range_u = MOTTE_CHASE_U
			s3.radius_u = ECLAT_RADIUS_U
			s3.proc_coef = 1.0
			s3.trigger_range_u = MOTTE_CHASE_U
			s3.hit_force = _force_for(ECLAT_KNOCK_U)
			_with_vfx(s3, MUD_BURST_FRAMES if ResourceLoader.exists(MUD_BURST_FRAMES) else MUD_SPLASH_FRAMES)
			return s3
		[4, V_MAREE]:
			var s4 := _spell(V_MAREE, "Marée de vase", 4, SpellData.Behavior.KIT, 0.0, TIDE_CD)
			s4.duration = TIDE_DURATION_S
			s4.proc_coef = 0.0
			s4.trigger_range_u = 3.0
			s4.is_zone = false
			s4.light_preset = LIGHT_BOG
			s4.color = MUD_COLOR
			return s4
	return null


# --- Mise en place ------------------------------------------------------------------------------

func setup(p: CharacterBody2D) -> void:
	player = p
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	_build_sub_spells()
	Events.floor_started.connect(_on_floor_started)
	Events.player_died.connect(_on_player_died)
	Events.boss_killed.connect(_on_boss_killed)
	if p.has_signal(&"action_impact"):
		p.action_impact.connect(_on_action_impact)
	_refresh_body()


func _exit_tree() -> void:
	if Events.floor_started.is_connected(_on_floor_started):
		Events.floor_started.disconnect(_on_floor_started)
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)
	if Events.boss_killed.is_connected(_on_boss_killed):
		Events.boss_killed.disconnect(_on_boss_killed)
	clear_transients()


func _build_sub_spells() -> void:
	_contact_spell = _spell(&"motte_contact", "Motte", 2, SpellData.Behavior.NOVA, MOTTE_CONTACT_COEF, 0.0)
	_contact_spell.is_zone = false
	_contact_spell.proc_coef = MOTTE_CONTACT_PROC
	_contact_spell.hit_force = _force_for(0.25)
	_big_contact_spell = _spell(&"motte_contact", "Grosse motte", 2, SpellData.Behavior.NOVA, BIG_CONTACT_COEF, 0.0)
	_big_contact_spell.is_zone = false
	_big_contact_spell.proc_coef = BIG_CONTACT_PROC
	_big_contact_spell.hit_force = _force_for(0.25)
	_land_spell = _spell(&"motte_plouf", "Plouf", 2, SpellData.Behavior.NOVA, MOTTE_LAND_COEF, 0.0)
	_land_spell.radius_u = MOTTE_LAND_RADIUS_U
	_land_spell.proc_coef = MOTTE_LAND_PROC
	_land_spell.hit_force = _force_for(0.4)
	_land_spell.color = MUD_COLOR
	_with_vfx(_land_spell, MUD_SPLASH_FRAMES)
	_recall_spell = _spell(&"rappel", "Rappel", 3, SpellData.Behavior.NOVA, RECALL_COEF, 0.0)
	_recall_spell.is_zone = false
	_recall_spell.proc_coef = 1.0
	_recall_spell.hit_force = _force_for(RECALL_KNOCK_U)


func _caster() -> SpellCaster:
	return player.spells if player != null else null


func _spell_of(slot: int) -> SpellData:
	for s in player.character.spells:
		if s.slot == slot:
			return s
	return null


# --- Masse --------------------------------------------------------------------------------------

## Mottes dehors (vivantes).
func out_count() -> int:
	return mottes.size()


## Places occupées sur MAX_MOTTES (motte normale 1, grosse motte 2).
func out_weight() -> int:
	var w := 0
	for m in mottes:
		w += m.weight
	return w


## Variante Bouture équipée au sort 2 ?
func big_mode() -> bool:
	if player == null or player.character == null:
		return false
	var s := _spell_of(2)
	return s != null and s.id == V_BOUTURE


func max_charges() -> int:
	return BIG_MAX_CHARGES if big_mode() else MAX_MOTTES


func charge_s() -> float:
	return BIG_CHARGE_S if big_mode() else DETACH_CHARGE_S


## Masse hors du corps (fraction des PV max non divisés) : mottes payées vivantes + masse perdue en attente.
func mass_out_frac() -> float:
	var t := 0.0
	for m in mottes:
		t += m.mass_frac
	for d in dead_mass:
		t += float(d[0])
	return t


## Hook Player._recompute : PV max × (1 − masse dehors), jamais sous MAX_HP_FLOOR_FRAC (40 %).
func max_hp_mult() -> float:
	return maxf(1.0 - mass_out_frac(), MAX_HP_FLOOR_FRAC)


## PV max non divisés (avant la masse détachée).
func full_max_hp() -> float:
	return player.max_hp / max_hp_mult()


## Masse d'une motte en PV max : 15 % des PV max non divisés.
func motte_cost() -> float:
	return MASS_PER_MOTTE * full_max_hp()


## PV max recalculés après un changement de masse. Les PV actuels ne sont que plafonnés au nouveau max (jamais
## mortels : ≥ 1) ; un gain de PV max ne soigne PAS (sinon détacher puis recoller soignerait gratuitement) : seul
## `heal` (PV actuels rognés au lancer, rendus au recollage) remonte les PV actuels.
func _recompute_mass(heal := 0.0) -> void:
	if player != null and is_instance_valid(player):
		var hp0: float = player.hp
		player.refresh_max_hp(false)
		if player.dead:
			player.hp = minf(hp0, player.max_hp)
		else:
			player.hp = clampf(hp0 + maxf(heal, 0.0), 1.0, player.max_hp)
		player.hp_changed.emit(player.hp, player.max_hp)
	_refresh_body()


## Vitesse et hitbox suivent le nombre de mottes dehors.
func _refresh_body() -> void:
	var n := out_weight() if tide_left <= 0.0 else -2 - out_weight() # Marée : hitbox imposée
	if n == _last_out or player == null:
		return
	_last_out = n
	if tide_left > 0.0:
		player.set_hitbox_u(TIDE_HITBOX_U)
		return
	player.set_hitbox_u(lerpf(HITBOX_U, HITBOX_MIN_U, float(mini(n, MAX_MOTTES)) / MAX_MOTTES))


func can_detach() -> bool:
	charges = mini(charges, max_charges())
	if sunk_left > 0.0 or charges <= 0:
		return false
	var w := BIG_WEIGHT if big_mode() else 1
	return out_weight() + w <= MAX_MOTTES # jamais refusé à cause des PV : le max ne descend pas sous 40 % (4 mottes)


# --- Hooks du joueur et de SpellCaster ----------------------------------------------------------

func is_sunk() -> bool:
	return sunk_left > 0.0


func blocks_slot(slot: int) -> bool:
	if sunk_left > 0.0:
		return true
	match slot:
		2:
			return not can_detach()
		3:
			return out_count() == 0
	return false


## Hook Player.take_damage : vase compacte (−30 % à 0 motte, −0 % à 4 mottes dehors).
func damage_taken_mult(_source: Node) -> float:
	return 1.0 - COMPACT_REDUCTION * (1.0 - float(mini(out_weight(), MAX_MOTTES)) / MAX_MOTTES)


func can_dodge() -> bool:
	return sunk_left <= 0.0


func speed_mult() -> float:
	if sunk_left > 0.0:
		return 0.0
	return (BASE_SPEED_U + SPEED_PER_MOTTE_U * out_weight()) / BASE_SPEED_U


func inertia_s() -> float:
	return 0.0


func slow_immune() -> bool:
	return sunk_left > 0.0 or tide_left > 0.0


func locks_facing() -> bool:
	return sunk_left > 0.0


func dodge_ghosts() -> bool:
	return true


func on_dodge_start(_dir: Vector2) -> void:
	pass




func cast_spell(s: SpellData, aim: Variant) -> bool:
	match s.id:
		&"detacher":
			if not can_detach():
				return false
			charges -= 1
			_pending.append([_action_name(&"detacher"), _throw_motte.bind(s, aim)])
			return true
		&"rappel":
			if out_count() == 0:
				return false
			_pending.append([_action_name(&"rappel"), _recall_all])
			return true
		&"bourbier":
			if sunk_left > 0.0:
				return false
			_start_sink(s)
			return true
		V_CRACHAT:
			return _spit(s)
		V_BOUTURE:
			if not can_detach():
				return false
			charges -= 1
			_pending.append([_action_name(V_BOUTURE), _throw_motte.bind(s, aim)])
			return true
		V_ECLAT:
			if out_count() == 0:
				return false
			_burst_all(s)
			return true
		V_MAREE:
			if sunk_left > 0.0:
				return false
			_start_tide(s)
			return true
	return false


## Anim d'action de chaque sort : la base livrée par BO1, sinon le repli d'Ardent.
func action_for(s: SpellData) -> StringName:
	return _action_name(s.id)


func _action_name(key: StringName) -> StringName:
	var cands: Array = ACTIONS.get(key, [])
	if cands.is_empty():
		return &""
	var sf := _visual.sprite_frames if _visual != null else null
	if sf != null:
		for a: StringName in cands:
			if sf.has_animation(StringName("%s_s" % a)) or sf.has_animation(a):
				return a
	return cands[0]


## Frame d'impact d'une anim du kit : l'effet en attente part (dans l'ordre des lancers).
func _on_action_impact(base: StringName) -> void:
	if not (base in KIT_ACTIONS):
		return
	for i in _pending.size():
		if _pending[i][0] == base:
			var f: Callable = _pending[i][1]
			_pending.remove_at(i)
			if player != null and not player.dead:
				f.call()
			return


func has_pending() -> bool:
	return not _pending.is_empty()


func on_cast(_s: SpellData) -> void:
	pass


# --- Sort 2 : Détacher -------------------------------------------------------------------------

func _throw_motte(s: SpellData, aim: Variant) -> void:
	var big := s.id == V_BOUTURE
	if out_weight() + (BIG_WEIGHT if big else 1) > MAX_MOTTES:
		charges = mini(charges + 1, max_charges()) # place prise au moment du geste : charge rendue
		return
	var origin := player.global_position
	var dir: Vector2 = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
	var dist := DETACH_RANGE_U * 0.6 * Balance.UNIT_PX
	if aim != null:
		var off := (aim as Vector2) - origin
		if off.length_squared() > 1.0:
			dir = off.normalized()
			dist = minf(off.length(), DETACH_RANGE_U * Balance.UNIT_PX * (1.0 + player.stat(&"range_add")))
	var to := _clip_to_walls(origin, origin + dir * dist)
	var hp0: float = player.hp
	var m := _new_motte(true, big)
	m.mass_frac = BIG_MASS_FRAC if big else MASS_PER_MOTTE
	_recompute_mass() # la masse quitte le corps : PV max −15 %, PV actuels plafonnés au nouveau max
	m.paid_hp = maxf(hp0 - player.hp, 0.0) # PV actuels rognés par le plafond (rendus au recollage)
	m.launch(origin, to)
	LightRig.flash(origin, LIGHT_SPELL, 0.25)


## Point d'atterrissage avant un mur (la motte ne passe pas à travers).
func _clip_to_walls(from: Vector2, to: Vector2) -> Vector2:
	if not player.is_inside_tree():
		return to
	var q := PhysicsRayQueryParameters2D.create(from, to, 1, [player.get_rid()])
	var hit := player.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	var p: Vector2 = hit["position"]
	return p - (to - from).normalized() * MOTTE_RADIUS_U * Balance.UNIT_PX


func _new_motte(costed: bool, big := false) -> BourbeMotte:
	var m := BourbeMotte.new()
	m.name = "Motte"
	m.kit = self
	m.bourbe = player
	m.caster = _caster()
	m.costed = costed
	m.max_hp = (BIG_HP_FRAC if big else MOTTE_HP_FRAC) * full_max_hp()
	m.hp = m.max_hp
	m.life_s = INF
	if big:
		m.big = true
		m.weight = BIG_WEIGHT
		m.fight_s = BIG_FIGHT_S
		m.speed_u = BIG_SPEED_U
		m.radius_u = BIG_RADIUS_U
		m.ring_u = BIG_RING_U
	m.contact_spell = _big_contact_spell if big else _contact_spell
	m.land_spell = _land_spell
	m.recall_spell = _recall_spell
	player.get_parent().add_child(m)
	m.global_position = player.global_position
	m.build_look(_visual)
	mottes.append(m)
	return m


func on_motte_died(m: BourbeMotte) -> void:
	if not mottes.has(m):
		return
	mottes.erase(m)
	mottes_died += 1
	if m.mass_frac > 0.0:
		dead_mass.append([m.mass_frac, DEAD_MASS_S]) # masse perdue : PV max réduits encore 8 s, puis rendus
	_recompute_mass()


func on_motte_merged(m: BourbeMotte) -> void:
	if not mottes.has(m):
		return
	mottes.erase(m)
	mottes_merged += 1
	if not _silent_merge:
		RunState.add_counter(COUNTER_RECALLED) # déblocage de la Bouture
	if player != null and not player.dead:
		HitFx.impact(player.global_position, -m.facing, &"physical", 0.3)
	var lost: float = m.mass_frac - merge_mass(m)
	if lost > 0.0005:
		dead_mass.append([lost, DEAD_MASS_S]) # la part abîmée de la motte revient plus tard (8 s)
	_recompute_mass(merge_refund(m) if player != null and not player.dead else 0.0) # masse rendue × PV restants


## Fraction des PV max rendue tout de suite par une motte qui se recolle : masse × PV restants (gratuite : 0).
func merge_mass(m: BourbeMotte) -> float:
	if m.mass_frac <= 0.0 or m.max_hp <= 0.0:
		return 0.0
	return m.mass_frac * clampf(m.hp / m.max_hp, 0.0, 1.0)


## PV actuels rendus au recollage : PV rognés au lancer × PV restants de la motte (motte gratuite : 0).
func merge_refund(m: BourbeMotte) -> float:
	if m.paid_hp <= 0.0 or m.max_hp <= 0.0:
		return 0.0
	return m.paid_hp * clampf(m.hp / m.max_hp, 0.0, 1.0)


# --- Sort 3 : Rappel ---------------------------------------------------------------------------

func _recall_all() -> void:
	for m in mottes:
		m.recall()
	if player != null:
		LightRig.flash(player.global_position, LIGHT_SPELL, 0.35)


# --- Sort 4 : Bourbier --------------------------------------------------------------------------

func _start_sink(s: SpellData) -> void:
	if tide_left > 0.0:
		_end_tide(false) # le Bourbier prend le relais : pas de mottes de fin de Marée
	sunk_left = BOG_DURATION_S
	_slow_t = 0.0
	player.velocity = Vector2.ZERO
	player.clear_slow()
	player.grant_invulnerability(BOG_DURATION_S) # inciblable : rien ne la touche sous la vase
	# les mottes fusionnent : toute la masse revient tout de suite, masse perdue comprise (règle d'origine)
	for m in mottes.duplicate():
		m.merge()
	dead_mass.clear()
	_recompute_mass()
	_pending.append([_action_name(&"bourbier"), _open_bog.bind(s)])


func _open_bog(s: SpellData) -> void:
	var z := s.duplicate() as SpellData
	z.behavior = SpellData.Behavior.NOVA
	bog_zone = _caster().spawn_zone(z, player.global_position)
	if bog_zone != null:
		bog_zone.z_index = -1


func _step_sink(delta: float) -> void:
	sunk_left = maxf(sunk_left - delta, 0.0)
	_slow_t -= delta
	if _slow_t <= 0.0 and is_instance_valid(bog_zone):
		_slow_t = BOG_SLOW_REFRESH_S
		var r: float = BOG_RADIUS_U * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e is Node2D and e.has_method(&"apply_status") and e.global_position.distance_to(bog_zone.global_position) <= r:
				e.apply_status(&"slow", {"pct": BOG_SLOW_PCT, "duration": BOG_SLOW_DURATION_S})
	if sunk_left <= 0.0:
		_rise()


func _rise() -> void:
	sunk_left = 0.0
	player.play_action(_action_name(&"rise"), player.facing)
	var origin := player.global_position
	var rise := _spell_of(4).duplicate() as SpellData
	rise.behavior = SpellData.Behavior.NOVA
	rise.duration = 0.0
	rise.coef = RISE_COEF
	rise.radius_u = RISE_RADIUS_U
	rise.proc_coef = 1.0
	rise.light_preset = LIGHT_SPELL
	rise.vfx_frames = ""
	_with_vfx(rise, MUD_SPLASH_FRAMES)
	_caster().spawn_zone(rise, origin)
	LightRig.flash(origin, LIGHT_SPELL, 0.5)
	# RISE_FREE_MOTTES mottes jaillissent autour d'elle, gratuites (cadeau du Bourbier : sans masse, rien à rendre)
	_spawn_free_mottes(RISE_FREE_MOTTES)
	charges = mini(charges, max_charges())
	_refresh_body()


## `n` mottes normales gratuites sur un anneau autour de Bourbe (limitées par les places libres).
func _spawn_free_mottes(n: int) -> void:
	var origin := player.global_position
	var first: Vector2 = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
	var space := player.get_world_2d().direct_space_state if player.is_inside_tree() else null
	var n_free := mini(n, MAX_MOTTES - out_weight())
	for i in n_free:
		var dir: Vector2 = first.rotated(TAU * (i + 0.5) / maxi(n_free, 1))
		var pos: Vector2 = origin + dir * RISE_RING_U * Balance.UNIT_PX
		if space != null:
			var q := PhysicsRayQueryParameters2D.create(origin, pos, 1, [player.get_rid()])
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				pos = (hit["position"] as Vector2) - dir * 4.0
		var m := _new_motte(false)
		m.pop_at(pos, dir)


# --- Variante Crachat de vase (sort 1) -----------------------------------------------------------

## Crache une motte en cloche sur l'ennemi le plus proche à portée ; false sans cible (rien consommé).
func _spit(s: SpellData) -> bool:
	var range_px: float = CRACHAT_RANGE_U * Balance.UNIT_PX * (1.0 + player.stat(&"range_add"))
	var near := _caster().nearest_enemies(player.global_position, range_px, 1)
	if near.is_empty():
		return false
	var to: Vector2 = (near[0] as Node2D).global_position
	var from := player.global_position
	var g := Node2D.new()
	g.name = "Glob"
	g.top_level = true
	g.draw.connect(func() -> void: # repli dessiné (CREA 3 mud_glob attendu)
		g.draw_circle(Vector2.ZERO, 7.0, Color(0.37, 0.56, 0.5, 0.95))
		g.draw_circle(Vector2(0, -1), 3.0, Color(ACCENT.r * 1.6, ACCENT.g * 1.6, ACCENT.b * 1.6, 0.9)))
	player.get_parent().add_child(g)
	g.global_position = from
	_globs.append({"node": g, "from": from, "to": to, "t": 0.0, "spell": s})
	if to != from:
		player.facing = (to - from).normalized()
	LightRig.flash(from, LIGHT_SPELL, 0.15)
	return true


func _step_globs(delta: float) -> void:
	for g in _globs.duplicate():
		g["t"] = minf(float(g["t"]) + delta / CRACHAT_FLY_S, 1.0)
		var t: float = g["t"]
		var node := g["node"] as Node2D
		if is_instance_valid(node):
			var base: Vector2 = (g["from"] as Vector2).lerp(g["to"] as Vector2, t)
			node.global_position = base + Vector2(0.0, -Iso.lift_logical(CRACHAT_ARC_U) * sin(PI * t))
			node.queue_redraw()
		if t >= 1.0:
			_globs.erase(g)
			if is_instance_valid(node):
				node.queue_free()
			_glob_land(g["spell"] as SpellData, g["to"] as Vector2)


## Éclatement de la motte crachée : disque `radius_u`, coup + ralentissement 25 % 1 s.
func _glob_land(s: SpellData, pos: Vector2) -> void:
	if player == null or player.dead or not is_instance_valid(player):
		return
	var z := s.duplicate() as SpellData
	z.behavior = SpellData.Behavior.NOVA
	z.duration = 0.0
	_caster().spawn_zone(z, pos)
	_slow_circle(pos, z.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add")), CRACHAT_SLOW_PCT, CRACHAT_SLOW_S)
	HitFx.impact(pos, Vector2.DOWN, &"physical", 0.4)


func _slow_circle(pos: Vector2, r: float, pct: float, secs: float) -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and e.has_method(&"apply_status") and e.global_position.distance_to(pos) <= r:
			e.apply_status(&"slow", {"pct": pct, "duration": secs})


# --- Variante Éclatement (sort 3) ---------------------------------------------------------------

## Chaque motte vivante explose sur place (coef x PV restants, min 0,5) puis sa vase revient d'un coup.
func _burst_all(s: SpellData) -> void:
	for m in mottes.duplicate():
		if not is_instance_valid(m):
			continue
		var frac := clampf(m.hp / maxf(m.max_hp, 0.001), ECLAT_MIN_FRAC, 1.0)
		var z := s.duplicate() as SpellData
		z.behavior = SpellData.Behavior.NOVA
		z.duration = 0.0
		z.coef = s.coef * frac
		var pos: Vector2 = m.global_position
		_caster().spawn_zone(z, pos)
		_slow_circle(pos, z.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add")), ECLAT_SLOW_PCT, ECLAT_SLOW_S)
		LightRig.flash(pos, LIGHT_SPELL, 0.3)
		_silent_merge = true
		m.merge() # la vase revient : masse et PV rendus x PV restants
		_silent_merge = false
	if player != null:
		LightRig.flash(player.global_position, LIGHT_SPELL, 0.35)


# --- Variante Marée de vase (sort 4) ------------------------------------------------------------

func _start_tide(_s: SpellData) -> void:
	if tide_left > 0.0:
		_end_tide(false)
	# toutes les mottes sont absorbées : soin plein du prix payé, quel que soit leur état
	for m in mottes.duplicate():
		if is_instance_valid(m):
			m.hp = m.max_hp
			_silent_merge = true
			m.merge()
			_silent_merge = false
	tide_left = TIDE_DURATION_S
	_tide_shield = TIDE_SHIELD_FRAC * player.max_hp
	player.add_shield(_tide_shield)
	player.clear_slow()
	var a := _spell_of(1)
	if a != null:
		_tide_saved = {"coef": a.coef, "radius": a.radius_u, "vfx": a.vfx_radius_px}
		a.coef *= TIDE_COEF_MULT
		a.radius_u *= TIDE_RADIUS_MULT
		a.vfx_radius_px *= TIDE_RADIUS_MULT
	if _visual != null:
		_tide_base_scale = _visual.scale
		_tide_base_tint = _visual.self_modulate
		_visual.scale = _tide_base_scale * TIDE_SCALE
		_visual.self_modulate = _tide_base_tint * TIDE_TINT
	_refresh_body()
	if player != null:
		LightRig.flash(player.global_position, LIGHT_BOG, 0.5)


## Fin de la Marée : bouclier restant perdu, taille et gifles rendues ; `spawn` : 4 mottes gratuites.
func _end_tide(spawn: bool) -> void:
	if tide_left <= 0.0:
		return
	tide_left = 0.0
	if player != null and is_instance_valid(player):
		player.shield = maxf(player.shield - _tide_shield, 0.0)
	_tide_shield = 0.0
	var a := _spell_of(1)
	if a != null and not _tide_saved.is_empty():
		a.coef = float(_tide_saved["coef"])
		a.radius_u = float(_tide_saved["radius"])
		a.vfx_radius_px = float(_tide_saved["vfx"])
	_tide_saved = {}
	if _visual != null and is_instance_valid(_visual):
		_visual.scale = _tide_base_scale
		_visual.self_modulate = _tide_base_tint
	_last_out = -1
	if spawn and player != null and not player.dead:
		_spawn_free_mottes(TIDE_FREE_MOTTES)
		LightRig.flash(player.global_position, LIGHT_SPELL, 0.5)
	_refresh_body()


# --- Boucle (Player.tick, avant les sorts) -------------------------------------------------------

func tick(delta: float) -> void:
	if player == null or player.dead:
		return
	# charges séquentielles : une seule en recharge à la fois (× cooldown_mult)
	charges = mini(charges, max_charges())
	if charges < max_charges():
		_charge_t += delta
		var m: float = player.stat(&"cooldown_mult")
		var cd := Balance.effective_cooldown(charge_s(), m if m > 0.0 else 1.0)
		if _charge_t >= cd:
			_charge_t = 0.0
			charges += 1
	else:
		_charge_t = 0.0
	if not dead_mass.is_empty(): # la vase perdue repousse : PV max rendus (sans soin)
		var back := false
		for d in dead_mass:
			d[1] = float(d[1]) - delta
			back = back or float(d[1]) <= 0.0
		if back:
			dead_mass = dead_mass.filter(func(d: Array) -> bool: return float(d[1]) > 0.0)
			_recompute_mass()
	if sunk_left > 0.0:
		_step_sink(delta)
	if not _globs.is_empty():
		_step_globs(delta)
	if tide_left > 0.0:
		tide_left = maxf(tide_left - delta, 0.0)
		_tide_shield = minf(_tide_shield, player.shield) # le bouclier de la Marée fond avec les coups
		if tide_left <= 0.0:
			tide_left = 0.001
			_end_tide(true)
	_refresh_body()
	_update_look()


## Ressource (contrat KitResource) : charges de Détacher (4 pastilles) ; ratio = recharge de la charge en cours.
func resource_state() -> Dictionary:
	var m: float = player.stat(&"cooldown_mult")
	var cd := Balance.effective_cooldown(charge_s(), m if m > 0.0 else 1.0)
	return KitResource.make(&"mottes", "Mottes", _charge_t / maxf(cd, 0.01) if charges < max_charges() else 1.0, ACCENT,
		{"pips": max_charges(), "filled": mini(charges, max_charges()), "blocked": not can_detach(), "boost": sunk_left > 0.0})


# --- Nettoyage ---------------------------------------------------------------------------------

func clear_transients() -> void:
	_pending.clear()
	for g in _globs:
		if is_instance_valid(g["node"]):
			(g["node"] as Node).queue_free()
	_globs.clear()
	if tide_left > 0.0:
		_end_tide(false)
	for m in mottes.duplicate():
		if is_instance_valid(m):
			m.leave()
			m.queue_free()
	mottes.clear()
	dead_mass.clear()
	if is_instance_valid(bog_zone):
		bog_zone.queue_free()
	bog_zone = null
	if player != null and is_instance_valid(player):
		_recompute_mass(_heal_on_clear) # toute la masse rentre (PV max pleins)


func _on_floor_started(_n: int) -> void:
	sunk_left = 0.0
	charges = max_charges()
	for m in mottes:
		if is_instance_valid(m):
			RunState.add_counter(COUNTER_RECALLED) # les mottes rentrent à l'étage suivant
	if player != null and is_instance_valid(player) and not player.dead:
		var back := 0.0
		for m in mottes:
			if is_instance_valid(m):
				back += merge_refund(m)
		_heal_on_clear = back # étage : les mottes rentrent sans perte (masse + PV rognés)
	clear_transients()
	_heal_on_clear = 0.0


## Mini-boss tué avec 4 mottes dehors (déblocage de la Marée de vase).
func _on_boss_killed(_boss: Node2D, is_floor_boss: bool) -> void:
	if not is_floor_boss and out_count() >= MAX_MOTTES:
		RunState.add_counter(COUNTER_MINIBOSS4)


func _on_player_died() -> void:
	sunk_left = 0.0
	for m in mottes.duplicate():
		if is_instance_valid(m):
			m.die() # sans elle, la vase retombe
	mottes.clear()
	clear_transients()
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


## Enfoncée : `sink_<dir>` tenue sur sa dernière frame ; sinon `fallback` (action en cours ou idle/run).
func visual_anim(fallback: StringName) -> StringName:
	if sunk_left > 0.0 and player.action_left() <= 0.0:
		var a := _resolve(&"sink", _dir_name())
		if a != &"":
			_visual.sprite_frames.set_animation_loop(a, false)
			return a
	return fallback


## Repli sans `sink` : la golemme se fond dans la vase (alpha), le follet seul reste lisible.
const SINK_ALPHA := 0.28
func _update_look() -> void:
	if _visual == null:
		return
	var has_sink := _resolve(&"sink", "s") != &""
	var target := SINK_ALPHA if sunk_left > 0.0 and not has_sink else 1.0
	if not is_equal_approx(_visual.modulate.a, target):
		_visual.modulate.a = move_toward(_visual.modulate.a, target, 0.08)



# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) ------------------------------------

static func passive_info() -> Dictionary:
	var f := KitResource.fmt
	return KitResource.passive("Masse", &"masse",
		"Bourbe se divise en mottes (jusqu'à %d dehors). Les pastilles du HUD montrent les charges de Détacher disponibles." % MAX_MOTTES,
		"recoller une motte (Rappel, ou elle rampe seule vers toi) lui rend sa masse ; le Bourbier rend tout de suite toute la masse.",
		"chaque motte dehors retire %s des PV max (plancher %s). Une motte écrasée perd sa masse pendant %s s." % [
			KitResource.pct(MASS_PER_MOTTE), KitResource.pct(MAX_HP_FLOOR_FRAC), f.call(DEAD_MASS_S)],
		"plus Bourbe est divisée, plus elle est vive (+%s u/s par motte) et petite (hitbox plus fine)." % f.call(SPEED_PER_MOTTE_U))
