class_name AvareKit
extends Node
## Kit d'Avare, l'usurier des Terrasses (docs/Design_Personnages.md §2.4) : mêlée / tank, ressource = l'or de
## la run (RunState.gold). Données : character(). Logique : ce nœud, enfant « Kit » du joueur, interrogé par
## les hooks (blocks_slot, cast_spell, action_for, damage_add, on_cast, rests_on_hit, on_projectile_rest…).
## - Puissance de l'or : +15 % de dégâts par P d'or en bourse (P = prix courant d'un petit coffre), plafond +90 %
##   (SpellCaster.compute_damage -> damage_add). Lisible en jeu : l'or qui fuit du coffre (masque _e) et la
##   lueur dorée autour d'Avare montent avec la bourse.
## - Sort 1 Coup de coffre (auto) : arc devant lui vers l'ennemi le plus proche, à la frame d'impact de `swing`.
## - Sort 2 Poignée de pièces : 5 pièces en éventail (SpellData FAN) ; coûte 2 % de l'or (min 0,1 P) ; chaque
##   pièce retombe où elle s'arrête (dernier coup, portée, mur) : 80 % du coût, ramassable au contact.
## - Sort 3 Rançon : frappe au sol autour de lui (slam) : étourdit 0,5 s, marque 4 s (+50 % d'or à la mort).
## - Sort 4 Faillite : dépense 50 % de l'or, explosion de pièces (coef 6 + 4 × min(1, dépensé / 4 P)), recul 2 u ;
##   la moitié de l'or dépensé retombe en pièces sur la zone.
## - Malus : chaque coup subi fait tomber 3 % de l'or en pièces. Roulade lourde : 2,5 u.
## - Pièces d'Avare = RESSOURCES DE JOUEUR (retour joueur 22/10/2026) : GroundPickup (PLAYER_RESOURCE, meta
##   `player_resource`), jamais aspirées par le ramassage automatique de l'or ; elles restent au sol jusqu'au
##   ramassage (au contact). Plafond MAX_GROUND_COINS (la plus ancienne rentre alors dans la bourse) ; au
##   changement d'étage les pièces au sol rentrent dans la bourse avant la part gardée (floor_gold_kept).
## - Bourse expliquée : jauge HUD « Bourse » (+X % dégâts, un repère par P), bulle de tutoriel la première fois
##   (AvarePurseTip, une fois par profil : Profile.objective_progress(TIP_KEY)).
## Équité de l'or : les pièces d'Avare rendent exactement leur valeur (RunState.add_gold, jamais × gold_mult
## ni Events.pickup_collected : recycler son or ne crée pas d'or) ; seule la prime de Rançon est de l'or neuf,
## versée comme une prime de monstre (PickupManager, gold_mult appliqué comme pour toute prime).

# --- Assets (AA1 livré ; AA2 attendu : chemins exacts du brief art/tools/night/_aa2.txt / aa2_build.py) ---
const ASSET_DIR := "res://assets/sprites/characters/avare/"
const SPRITE_FRAMES := ASSET_DIR + "avare.tres" ## idle/run/swing/throw/slam/ult/attack/cast/cast_ult/death _<dir>
const FX_DIR := ASSET_DIR + "effects/"
## Balayage du coffre (AA2, CREA 192, 4 frames × 8 dir, anims `coffre_arc_<dir>`, même rig et pivot que le
## personnage) : enfant du sprite d'Avare. Absent = croissant doré dessiné par ZoneEffect.
const COFFRE_ARC_FRAMES := FX_DIR + "coffre_arc/coffre_arc.tres"
## Portée horizontale de la traîne dans sa cellule (mesurée sur AA2 : 58 px du pivot = 0,64 u à 90,51 px/u) :
## le balayage est agrandi autour du pivot pour que son bord tombe sur le rayon réel du Coup de coffre.
const COFFRE_ARC_REACH_PX := 58.0
## Pièce en vol (AA2, CREA 48, 4 frames en boucle, `default`, vers +X).
const COIN_PROJECTILE_FRAMES := FX_DIR + "coin_projectile/coin_projectile.tres"
## Pièce au sol (AA2, CREA 48, 8 frames en boucle, `default`). Absente = coin.png des pickups.
const COIN_PICKUP_FRAMES := FX_DIR + "coin_pickup/coin_pickup.tres"
const COIN_FALLBACK_TEX := "res://assets/sprites/pickups/coin.png"
## Sceau de Rançon (AA2, TOP 256 à 128 px/u, 4 frames, `default`) : anneau final à 0,89 u = 114 px.
const RANSOM_RING_FRAMES := FX_DIR + "ransom_ring/ransom_ring.tres"
const RANSOM_RING_RADIUS_PX := 114.0
## Gerbe de Faillite (AA2, CREA 512 à 90,51 px/u, 6 frames, `default`) : rayon final ≈ 2,2 u = 200 px.
const COIN_BURST_FRAMES := FX_DIR + "coin_burst/coin_burst.tres"
const COIN_BURST_RADIUS_PX := 200.0 ## mesuré sur la dernière frame AA2 (pièces les plus lointaines)
## Or qui saigne à chaque coup subi (AA2, CREA 192, 6 frames, `default`, même échelle que le personnage).
const GOLD_BLEED_FRAMES := FX_DIR + "gold_bleed/gold_bleed.tres"
const PLACEHOLDER_TINT := Color(0.62, 0.52, 0.42) ## sans avare.tres : Ardent teinté cuir gras

const GOLD := Color("#F2C14E") ## accent émissif unique
const LIGHT_PRESET := &"avare_gold"
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const WALL_MASK := 1
## Anims d'action et frames d'impact (index 0) de avare.tres (AA1 : swing 4, throw 4, slam 6, ult 8 à 12 i/s).
const ACTION_IMPACT_FRAMES := {&"swing": 2, &"throw": 2, &"slam": 3, &"ult": 5, &"attack": 2, &"cast": 3, &"cast_ult": 4}

# --- Statistiques (§2.4, §3.1) ----------------------------------------------------------------------
const BASE_HP := 120.0
const HP_PER_LEVEL := 36.0
const ARMOR := 30.0 ## équilibrage 22/10 : 15 -> 30 (tank)
const BASE_REGEN := 0.8
const REGEN_PER_LEVEL := 0.16
const SPEED_U := 3.8
const HITBOX_U := 0.5
const DODGE_U := 2.5 ## roulade lourde (Balance.DODGE_DISTANCE_U = 3 u, coupée à 2,5 u)
## Râfle du coffre (esquive, docs/Design_Esquives.md §Avare) : dash lourd à RAKE_SPEED_U ; pendant et RAKE_AFTER_S
## après, ses propres pièces à RAKE_PICKUP_U sont ramassées (jamais l'or des monstres : aucun or créé).
const RAKE_SPEED_U := 10.0
const RAKE_PICKUP_U := 1.2
const RAKE_AFTER_S := 0.3
const DODGE_GHOST_COLOR := Color(0.95, 0.76, 0.31, 0.4) ## #F2C14E
const DODGE_SOUND := [&"spell.avare_coup_de_coffre.cast_light", -6.0, 1.1]

# --- Puissance de l'or -----------------------------------------------------------------------------
const GOLD_POWER_PER_P := 0.15
const GOLD_POWER_CAP := 0.30 ## équilibrage 23/10 : 0,70 -> 0,45 -> 0,30 (mono L12 1,45 -> ≈1,2 ; or fixe 400 de la sim) ; = 2 P
## Équilibrage 22/10/2026 (simulateur : 10 morts au niveau 1 à 0 or, cible unique −42 %) : l'usurier fauché
## garde une puissance plancher et frappe encore (Poignée gratuite sans pièces rendues quand la bourse est vide).
const GOLD_POWER_FLOOR := 0.0 ## équilibrage 23/10 : 0,10 -> 0,0
## Coffre-bouclier : pendant ses frappes au contact (Coup de coffre, Rançon) le coffre s'interpose.
const GUARD_TAKEN_MULT := 0.55
const GUARD_S := 0.4 ## équilibrage 23/10 : 0,6 -> 0,4
## Changement d'étage : part de la bourse qu'Avare garde (le reste devient de l'XP comme pour tous, RoR2).
## Sans elle sa puissance repartait de 0 à chaque étage et la Poignée était grisée (socle commun, 22/10/2026).
## L'or gardé ne rapporte pas d'XP, et P grandit avec D et l'étage : la puissance gardée s'érode d'elle-même.
const FLOOR_GOLD_KEEP := 0.5
const PRICE_KIND := &"petit"
const EMISSION_MIN := 1.0 ## énergie du masque _e bourse vide…
const EMISSION_MAX := 3.4 ## … et bourse pleine (6 P)
const GLOW_MIN := 0.2 ## lueur dorée autour d'Avare (× preset avare_gold)
const GLOW_MAX := 1.0

# --- Sort 1 : Coup de coffre -------------------------------------------------------------------------
const SWING_COEF := 0.8 ## équilibrage 23/10 : 1,0 -> 0,8 (le Coup de coffre porte le mono : 1,0 coef/s à bourse pleine)
const SWING_CD := 0.8
const SWING_RADIUS_U := 2.6 ## retour joueur 23/10 : 2,0 -> 2,6 u (portée de mêlée trop courte) ; ancien : fiche 1,5 u, retour Rictus 1,8 u trop court
const SWING_ARC_DEG := 150.0
const SWING_KNOCK_U := 0.4

# --- Sort 2 : Poignée de pièces ----------------------------------------------------------------------
const COINS_COEF := 1.2
const COINS_CD := 5.0
const COINS_COUNT := 5
const COINS_SPREAD_DEG := 50.0
const COINS_RANGE_U := 6.0
const COINS_SPEED_U := 13.0
const COINS_COST_FRAC := 0.02
const COINS_MIN_COST_P := 0.1 ## « min 5 » de la fiche, en P (5 or à coeff 1) : suit le scaling
const COINS_REFUND_FRAC := 0.8
const COIN_LIFE_S := INF ## retour joueur 22/10 : 3 s -> jusqu'au ramassage
const COIN_CONTACT_U := 0.75

# --- Sort 3 : Rançon -------------------------------------------------------------------------------
const RANSOM_COEF := 1.8 ## équilibrage 23/10 : 3,0 -> 2,4 -> 1,8
const RANSOM_CD := 9.0
const RANSOM_RADIUS_U := 3.0
const RANSOM_STUN_S := 0.5
const RANSOM_MARK_S := 4.0
const RANSOM_GOLD_BONUS := 0.5

# --- Sort 4 : Faillite -------------------------------------------------------------------------------
const RUIN_BASE_COEF := 5.0 ## équilibrage 23/10 : 6 -> 7 -> 5,0 (burst d'ouverture : mini-boss L12 1,55 -> cible)
const RUIN_BONUS_COEF := 3.5 ## équilibrage 23/10 : 4 -> 3,5
const RUIN_BONUS_AT_P := 4.0
const RUIN_CD := 25.0
const RUIN_RADIUS_U := 5.0
const RUIN_SPEND_FRAC := 0.5
const RUIN_REFUND_FRAC := 0.5
const RUIN_PUSH_U := 2.0
const RUIN_COINS := 10
const RUIN_COIN_LIFE_S := INF ## retour joueur 22/10 : 3 s -> jusqu'au ramassage
const RUIN_COIN_DELAY_S := 0.3 ## les pièces retombent avant d'être ramassables

# --- Variantes de sorts (docs/Variantes_Sorts.md §2.7 ; ids = characters.json) -------------------------
const V_RAM := &"avare_coffre_belier" ## slot 1, remplace Coup de coffre
const V_COIN := &"avare_piece_truquee" ## slot 2, remplace Poignée de pièces
const V_GRAB := &"avare_saisie" ## slot 3, remplace Rançon
const V_BURIED := &"avare_tresor_enterre" ## slot 4, remplace Faillite
## Compteurs de déblocage (RunState.add_counter -> Profile.stats ; règles « counter » de characters.json)
const COUNTER_COINS := "avare.coins_picked" ## pièces d'Avare ramassées (Poignée, Faillite, saignement…)
const COUNTER_RANSOM_GOLD := "avare.ransom_gold" ## or neuf des primes de Rançon / Saisie
const COUNTER_BOSS2 := "avare.floor2_boss_kills" ## boss d'étage vaincu à l'étage 2
const BOSS_FLOOR := 2

## Coffre-bélier : ligne devant lui, plus forte et plus longue que l'arc, bouclier plus long.
const RAM_COEF := 0.9 ## équilibrage 23/10 : fiche 1,1 -> 0,9 (base Coup de coffre 1,0 -> 0,8 le même jour)
const RAM_CD := 0.8
const RAM_LENGTH_U := 3.5
const RAM_WIDTH_U := 1.4 ## équilibrage 23/10 : fiche 1,0 -> 1,4 (essaim : une ligne mince touchait trop peu)
const RAM_KNOCK_U := 0.8
const RAM_GUARD_S := 0.8

## Pièce truquée : une pièce qui rebondit de monstre en monstre.
const TRICK_COEF := 1.5
const TRICK_CD := 5.0
const TRICK_BOUNCES := 4
const TRICK_BOUNCE_U := 3.0
const TRICK_SPEED_U := 13.0
const TRICK_RANGE_U := 6.0

## Saisie : la chaîne harponne un paquet et le tire aux pieds d'Avare, marqué.
const GRAB_COEF := 2.0
const GRAB_CD := 9.0
const GRAB_RANGE_U := 5.0
const GRAB_RADIUS_U := 2.0
const GRAB_FRONT_U := 1.5 ## les tirés se tassent à cette distance devant lui
const GRAB_CHAIN_S := 0.35

## Trésor enterré : la moitié de la bourse sous un coffre-mine ; l'or enterré retombe en entier à la détonation.
const BURIED_BASE_COEF := 4.0 ## équilibrage 23/10 : fiche 5 -> 4 (la Faillite de base a baissé de 7 à 5 : le Trésor reste ≈ 0,8 x Faillite)
const BURIED_BONUS_COEF := 2.5 ## équilibrage 23/10 : fiche 3 -> 2,5
const BURIED_CD := 25.0
const BURIED_RADIUS_U := 5.0
const BURIED_SPEND_FRAC := 0.5
const BURIED_REFUND_FRAC := 1.0 ## levier d'équilibrage : 0,85 si la Faillite devient dominée (economy_test)
const BURIED_COINS := 12
const BURIED_COIN_RING_U := Vector2(1.5, 4.5)
const BURIED_PUSH_U := 2.0

# --- Malus : l'or saigne -----------------------------------------------------------------------------
const BLEED_FRAC := 0.03
const BLEED_COINS := 3
const BLEED_LIFE_S := INF ## retour joueur 22/10 : 5 s -> jusqu'au ramassage (le malus = aller les rechercher)
const BLEED_DELAY_S := 0.35
const BLEED_RING_U := Vector2(0.9, 1.6)
const BLEED_MIN_GOLD := 0.5
## Pièces au sol : plafond (perf, ≤ 15-40 GroundPickup) ; au-delà la plus ancienne rentre dans la bourse.
const MAX_GROUND_COINS := 40
const PLAYER_RESOURCE_META := &"player_resource" ## marquage « ressource de joueur » (contrat 22/10/2026)

# --- Tutoriel de la bourse ---------------------------------------------------------------------------
const TIP_KEY := &"tip_seen:avare_purse" ## Profile.objectives : bulle vue une fois par profil
const TIP_DELAY_S := 1.5

var player: CharacterBody2D = null
var coins: Array = [] ## GroundPickup d'or au sol (Poignée, Faillite, saignement)
var marks := {} ## instance_id -> {"t": fin de marque (s), "ref": WeakRef}
var last_ruin := {} ## dernier Faillite : {spent, coef} (tests, rapport)
var last_buried := {} ## dernier Trésor enterré : {buried, coef, cause}
var mines: Array = [] ## AvareMine posés (Trésor enterré)
var _clock := 0.0
var guard_left := 0.0 ## coffre-bouclier
var rake_left := 0.0 ## Râfle du coffre : ramassage élargi des pièces après le dash
var _pending := {} ## base d'anim -> Callable (effet à la frame d'impact)
var _salvo_coin_value := 0.0
var _power_override := -1.0 ## puissance figée pendant Faillite (l'or vient d'être dépensé)
var _visual: AnimatedSprite2D = null
var _glow: LightRig.Handle = null
var _rng := RandomNumberGenerator.new()
var _arc_frames: SpriteFrames = null
var _bleed_frames: SpriteFrames = null


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
	s.color = GOLD
	s.light_preset = LIGHT_PRESET ## l'or, jamais la braise d'Ardent
	return s


static func character() -> CharacterData:
	var c := CharacterData.new()
	c.id = &"avare"
	c.display_name = "Avare"
	c.base_hp = BASE_HP
	c.hp_per_level = HP_PER_LEVEL
	c.armor = ARMOR
	c.base_regen = BASE_REGEN
	c.regen_per_level = REGEN_PER_LEVEL
	c.base_speed_u = SPEED_U
	c.hitbox_u = HITBOX_U
	c.kit_script = AvareKit
	c.sprite_frames_path = SPRITE_FRAMES
	c.placeholder_tint = PLACEHOLDER_TINT
	c.body_color = Color("#4A3A2A")
	c.accent_color = GOLD
	c.dodge_distance_u = DODGE_U
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"avare_coup_de_coffre", "Coup de coffre", 1, SpellData.Behavior.KIT, SWING_COEF, SWING_CD)
	s1.is_auto = true
	s1.range_u = SWING_RADIUS_U
	s1.radius_u = SWING_RADIUS_U
	s1.spread_deg = SWING_ARC_DEG
	s1.proc_coef = 1.0
	s1.hit_force = _force_for(SWING_KNOCK_U)
	s1.trigger_range_u = SWING_RADIUS_U

	var s2 := _spell(&"avare_poignee_de_pieces", "Poignée de pièces", 2, SpellData.Behavior.FAN, COINS_COEF, COINS_CD)
	s2.count = COINS_COUNT
	s2.spread_deg = COINS_SPREAD_DEG
	s2.speed_u = COINS_SPEED_U
	s2.range_u = COINS_RANGE_U
	s2.pierce = 1
	s2.item_pierce = false # Pointe perforante : sort 1 seulement
	s2.is_zone = false
	s2.proc_coef = 0.8
	s2.rests_on_ground = true # chaque pièce retombe (on_projectile_rest)
	s2.target_mode = &"densest"
	s2.trigger_range_u = COINS_RANGE_U
	s2.projectile_frames = COIN_PROJECTILE_FRAMES

	var s3 := _spell(&"avare_rancon", "Rançon", 3, SpellData.Behavior.KIT, RANSOM_COEF, RANSOM_CD)
	s3.radius_u = RANSOM_RADIUS_U
	s3.range_u = RANSOM_RADIUS_U
	s3.proc_coef = 1.0
	s3.trigger_range_u = 2.5
	s3.hit_force = _force_for(0.5)
	s3.vfx_frames = RANSOM_RING_FRAMES
	s3.vfx_radius_px = RANSOM_RING_RADIUS_PX
	s3.vfx_floor_aspect = 1.0 # rig TOP : jamais pré-écrasé

	var s4 := _spell(&"avare_faillite", "Faillite", 4, SpellData.Behavior.KIT, RUIN_BASE_COEF, RUIN_CD)
	s4.radius_u = RUIN_RADIUS_U
	s4.range_u = RUIN_RADIUS_U
	s4.proc_coef = 1.0
	s4.trigger_range_u = 3.5
	s4.hit_force = 1.0
	s4.vfx_frames = COIN_BURST_FRAMES
	s4.vfx_radius_px = COIN_BURST_RADIUS_PX
	s4.vfx_floor_aspect = 0.5 # rig CREA 30°

	c.spells = [s1, s2, s3, s4]
	return c


## Variantes de sorts (CONTRACTS.md « Variantes de sorts ») : nouveau SpellData du slot, ou null (inconnue).
## Tous les comportements propres passent par Behavior.KIT + cast_spell ; ils lisent s.id.
static func variant(slot: int, variant_id: StringName) -> SpellData:
	match variant_id:
		V_RAM:
			if slot != 1:
				return null
			var s := _spell(V_RAM, "Coffre-bélier", 1, SpellData.Behavior.KIT, RAM_COEF, RAM_CD)
			s.is_auto = true
			s.range_u = RAM_LENGTH_U
			s.radius_u = RAM_LENGTH_U
			s.proc_coef = 1.0
			s.hit_force = _force_for(RAM_KNOCK_U)
			s.trigger_range_u = RAM_LENGTH_U
			return s
		V_COIN:
			if slot != 2:
				return null
			var s := _spell(V_COIN, "Pièce truquée", 2, SpellData.Behavior.KIT, TRICK_COEF, TRICK_CD)
			s.count = 1 # une seule pièce : on_cast rend 80 % du coût entier en une pièce
			s.speed_u = TRICK_SPEED_U
			s.range_u = TRICK_RANGE_U
			s.proc_coef = 0.8
			s.is_zone = false
			s.item_pierce = false
			s.target_mode = &"densest"
			s.trigger_range_u = TRICK_RANGE_U
			return s
		V_GRAB:
			if slot != 3:
				return null
			var s := _spell(V_GRAB, "Saisie", 3, SpellData.Behavior.KIT, GRAB_COEF, GRAB_CD)
			s.range_u = GRAB_RANGE_U
			s.radius_u = GRAB_RADIUS_U
			s.proc_coef = 1.0
			s.hit_force = 0.0
			s.target_mode = &"densest"
			s.trigger_range_u = GRAB_RANGE_U
			s.vfx_frames = RANSOM_RING_FRAMES
			s.vfx_radius_px = RANSOM_RING_RADIUS_PX
			s.vfx_floor_aspect = 1.0
			return s
		V_BURIED:
			if slot != 4:
				return null
			var s := _spell(V_BURIED, "Trésor enterré", 4, SpellData.Behavior.KIT, BURIED_BASE_COEF, BURIED_CD)
			s.radius_u = BURIED_RADIUS_U
			s.range_u = BURIED_RADIUS_U
			s.proc_coef = 1.0
			s.trigger_range_u = 3.5
			s.hit_force = 1.0
			s.vfx_frames = COIN_BURST_FRAMES
			s.vfx_radius_px = COIN_BURST_RADIUS_PX
			s.vfx_floor_aspect = 0.5
			return s
	return null


# --- Mise en place ------------------------------------------------------------------------------

func setup(p: CharacterBody2D) -> void:
	player = p
	_rng.randomize()
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	if ResourceLoader.exists(COFFRE_ARC_FRAMES):
		_arc_frames = load(COFFRE_ARC_FRAMES) as SpriteFrames
	if ResourceLoader.exists(GOLD_BLEED_FRAMES):
		_bleed_frames = load(GOLD_BLEED_FRAMES) as SpriteFrames
	_glow = LightRig.attach(p, LIGHT_PRESET, {"energy": GLOW_MIN})
	Events.floor_started.connect(_on_floor_started)
	Events.player_died.connect(_on_player_died)
	Events.player_damaged.connect(_on_player_damaged)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.boss_killed.connect(_on_boss_killed)
	if p.has_signal(&"action_impact"):
		p.action_impact.connect(_on_action_impact)
	_update_purse_look()
	_schedule_tip()


# --- Tutoriel de la bourse (une fois par profil) --------------------------------------------------

func tip_seen() -> bool:
	return Profile.objective_progress(TIP_KEY) > 0.0


## Première partie avec Avare (profil) : bulle courte et non bloquante qui explique la bourse.
func _schedule_tip() -> void:
	if tip_seen() or not is_inside_tree():
		return
	get_tree().create_timer(TIP_DELAY_S, false).timeout.connect(show_tip)


## Affiche la bulle (si pas encore vue) et la marque vue dans le profil. Retourne la bulle (tests) ou null.
func show_tip() -> AvarePurseTip:
	if tip_seen() or player == null or not is_instance_valid(player) or player.dead or not is_inside_tree():
		return null
	Profile.set_objective_progress(TIP_KEY, 1.0)
	return AvarePurseTip.spawn(get_tree(), GOLD)


func _exit_tree() -> void:
	if Events.floor_started.is_connected(_on_floor_started):
		Events.floor_started.disconnect(_on_floor_started)
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)
	if Events.player_damaged.is_connected(_on_player_damaged):
		Events.player_damaged.disconnect(_on_player_damaged)
	if Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.disconnect(_on_enemy_killed)
	if Events.boss_killed.is_connected(_on_boss_killed):
		Events.boss_killed.disconnect(_on_boss_killed)
	if _glow != null:
		LightRig.detach(_glow)
		_glow = null
	clear_transients()


func _caster() -> SpellCaster:
	return player.spells if player != null else null


# --- Or ------------------------------------------------------------------------------------------

## P : prix courant d'un petit coffre (suit le scaling de la run).
static func price_unit() -> float:
	return maxf(Balance.chest_price(PRICE_KIND, RunState.difficulty(), RunState.stage), 1.0)


## Bonus additif de dégâts de l'or détenu (0 … +0,9).
static func gold_power_for(gold: float) -> float:
	return clampf(GOLD_POWER_PER_P * gold / price_unit(), GOLD_POWER_FLOOR, GOLD_POWER_CAP)


func gold_power() -> float:
	return _power_override if _power_override >= 0.0 else gold_power_for(RunState.gold)


## Coût de la Poignée de pièces : 2 % de l'or, au moins 0,1 P.
static func coins_cost() -> float:
	return maxf(COINS_COST_FRAC * RunState.gold, COINS_MIN_COST_P * price_unit())


## Coef de Faillite pour un or dépensé.
static func ruin_coef(spent: float) -> float:
	return RUIN_BASE_COEF + RUIN_BONUS_COEF * minf(1.0, spent / (RUIN_BONUS_AT_P * price_unit()))


## Ressource (contrat KitResource) : la bourse = bonus de dégâts de l'or détenu ; un repère par P (prix d'un
## petit coffre) jusqu'au plafond ; éteinte quand la Poignée n'est pas payable.
func resource_state() -> Dictionary:
	var pw := gold_power()
	var marks: Array = []
	var step := GOLD_POWER_PER_P / GOLD_POWER_CAP
	var m := step
	while m < 0.999:
		marks.append(m)
		m += step
	return KitResource.make(&"gold_power", "Bourse", pw / GOLD_POWER_CAP, GOLD,
		{"text": "+%d %% dégâts" % roundi(pw * 100.0), "blocked": is_broke(), "marks": marks})


## Bourse trop maigre pour payer la Poignée : elle part quand même, sans pièces à ramasser.
func is_broke() -> bool:
	return RunState.gold + 0.0001 < coins_cost()


# --- Hooks du joueur et de SpellCaster ----------------------------------------------------------

## Hook StageManager.next_stage : or de la bourse gardé hors conversion en XP. Les pièces d'Avare encore au
## sol rentrent d'abord dans la bourse (ressource de joueur : jamais perdues au changement d'étage).
func floor_gold_kept(gold: float) -> float:
	var ground := ground_gold()
	if ground > 0.0:
		RunState.add_gold(ground)
		for g in coins.duplicate():
			if is_instance_valid(g):
				g.set_meta(&"gold", 0.0)
				g.queue_free()
		coins.clear()
	return FLOOR_GOLD_KEEP * (gold + ground)


## SpellCaster.compute_damage : puissance de l'or sur tous ses sorts.
func damage_add(_s: SpellData, _enemy: Node) -> float:
	return gold_power()


## Rien n'est grisé : fauché, la Poignée part gratuite mais ne rend aucune pièce (on_cast).
func blocks_slot(_slot: int) -> bool:
	return false


## Hook Player.take_damage : coffre-bouclier juste après un Coup de coffre ou une Rançon.
func damage_taken_mult(_source: Node) -> float:
	return GUARD_TAKEN_MULT if guard_left > 0.0 else 1.0


func can_dodge() -> bool:
	return true


func speed_mult() -> float:
	return 1.0


func inertia_s() -> float:
	return 0.0


func slow_immune() -> bool:
	return false


func locks_facing() -> bool:
	return false


func dodge_ghosts() -> bool:
	return true


func dodge_ghost_color() -> Color:
	return DODGE_GHOST_COLOR


func dodge_label() -> String:
	return "Râfle"


func dodge_sound() -> Array:
	return DODGE_SOUND


func dodge_speed_u() -> float:
	return RAKE_SPEED_U


func on_dodge_start(_dir: Vector2) -> void:
	rake_left = RAKE_AFTER_S # le temps du dash puis RAKE_AFTER_S (remis à la fin)
	_rake()


func on_dodge_end(_from: Vector2, _to: Vector2) -> void:
	rake_left = RAKE_AFTER_S


## Le coffre râfle ses pièces au passage (ressources de joueur, ramassage normal : aucun or créé).
func _rake() -> void:
	if player == null:
		return
	var r := RAKE_PICKUP_U * Balance.UNIT_PX
	for g in coins.duplicate():
		if g is GroundPickup and is_instance_valid(g) and not g.is_queued_for_deletion() \
				and (g as Node2D).global_position.distance_to(player.global_position) <= r:
			g.collect()


func action_for(s: SpellData) -> StringName:
	match s.slot:
		1:
			return &"swing"
		2:
			return &"throw"
		3:
			return &"slam"
		4:
			return &"ult"
	return &""


func visual_anim(fallback: StringName) -> StringName:
	return fallback


## Sorts KIT (1, 3, 4) : préparés ici, effet à la frame d'impact de l'anim (Player.action_impact).
func cast_spell(s: SpellData, aim: Variant) -> bool:
	match s.slot:
		1:
			var r: float = s.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
			var target := _nearest_enemy(r)
			if target == null:
				return false # l'auto ne consomme rien sans cible
			var dir := target.global_position - player.global_position
			if dir.length_squared() < 1.0:
				dir = player.facing
			dir = dir.normalized()
			player.facing = dir # Player.play_action garde l'orientation actuelle (aim nul pour l'auto)
			if s.id == V_RAM:
				_pending[&"swing"] = _do_ram.bind(s, dir)
			else:
				_pending[&"swing"] = _do_swing.bind(s, dir)
			return true
		2: # seule la Pièce truquée est un sort KIT (la Poignée est un FAN du caster)
			if s.id != V_COIN:
				return false
			var d: Vector2 = player.facing
			if aim is Vector2:
				d = (aim as Vector2) - player.global_position
			else:
				var t := _nearest_enemy(s.range_u * Balance.UNIT_PX)
				if t != null:
					d = t.global_position - player.global_position
			if d.length_squared() < 1.0:
				d = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
			d = d.normalized()
			player.facing = d
			_pending[&"throw"] = _do_trick_coin.bind(s, d)
			return true
		3:
			if s.id == V_GRAB:
				if not (aim is Vector2): # Saisie : rien à harponner, rien n'est consommé
					return false
				var off: Vector2 = ((aim as Vector2) - player.global_position).limit_length(s.range_u * Balance.UNIT_PX)
				if off.length_squared() > 1.0:
					player.facing = off.normalized()
				_pending[&"slam"] = _do_grab.bind(s, player.global_position + off)
				return true
			_pending[&"slam"] = _do_ransom.bind(s)
			return true
		4:
			if s.id == V_BURIED:
				_pending[&"ult"] = _do_buried.bind(s)
				return true
			_pending[&"ult"] = _do_ruin.bind(s)
			return true
	return false


## Après tout lancement réussi (Player.on_cast) : la Poignée se paie ici (déjà tirée par SpellCaster).
func on_cast(s: SpellData) -> void:
	if s.slot == 1 or s.slot == 3:
		guard_left = RAM_GUARD_S if s.id == V_RAM else GUARD_S
	if s.slot != 2:
		return
	var cost := coins_cost()
	if RunState.spend_gold(cost):
		_salvo_coin_value = cost * COINS_REFUND_FRAC / float(maxi(s.count, 1))
	else:
		_salvo_coin_value = 0.0


## Les pièces retombent aussi quand elles s'arrêtent sur un monstre (traversées épuisées).
func rests_on_hit(s: SpellData) -> bool:
	return s.slot == 2


func on_projectile_rest(s: SpellData, at: Vector2, group: Dictionary) -> void:
	if s.slot != 2 or player == null or player.dead:
		return
	if not group.has("coin"):
		group["coin"] = _salvo_coin_value
	var v: float = group["coin"]
	if v > 0.0:
		drop_coin(at, v, COIN_LIFE_S)


func _on_action_impact(base: StringName) -> void:
	if not _pending.has(base):
		return
	var fx: Callable = _pending[base]
	_pending.erase(base)
	if player != null and not player.dead:
		fx.call()


## Effets en attente de la frame d'impact (tests).
func has_pending() -> bool:
	return not _pending.is_empty()


# --- Effets des sorts --------------------------------------------------------------------------

func _do_swing(s: SpellData, dir: Vector2) -> void:
	var c := _caster()
	if c == null:
		return
	var hit := s
	if _arc_frames != null: # balayage rendu : pas de croissant de repli par-dessus
		hit = s.duplicate() as SpellData
		hit.color = Color(GOLD, 0.0)
		_play_arc_fx(dir, s.radius_u * (1.0 + player.stat(&"zone_size_add")))
	c.spawn_zone(hit, player.global_position, dir)


func _do_ransom(s: SpellData) -> void:
	var c := _caster()
	if c == null:
		return
	var pos := player.global_position
	var r: float = s.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
	var victims := _enemies_in(pos, r)
	for e in victims: # marque d'abord : un monstre tué par la Rançon paie déjà sa rançon
		marks[e.get_instance_id()] = {"t": _clock + RANSOM_MARK_S, "ref": weakref(e)}
	c.spawn_zone(s, pos)
	for e in victims:
		if is_instance_valid(e) and e.has_method(&"stun") and not e.is_in_group(&"bosses"):
			if not (&"active" in e) or bool(e.get(&"active")):
				e.stun(RANSOM_STUN_S)
	LightRig.flash(pos, LIGHT_PRESET, 0.45)
	_shake(5.0)


func _do_ruin(s: SpellData) -> void:
	var c := _caster()
	if c == null:
		return
	var pos := player.global_position
	var power_before := gold_power()
	var spent := floorf(RunState.gold * RUIN_SPEND_FRAC)
	if spent > 0.0 and not RunState.spend_gold(spent):
		spent = 0.0
	var boom := s.duplicate() as SpellData
	boom.coef = ruin_coef(spent)
	last_ruin = {"spent": spent, "coef": boom.coef}
	var r: float = s.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
	var victims := _enemies_in(pos, r)
	_power_override = power_before # tout l'or jeté dans un seul coup : la puissance d'avant compte
	c.spawn_zone(boom, pos)
	_power_override = -1.0
	_blast_push(victims, pos, RUIN_PUSH_U) # recul de 2 u (le coup direct en donne déjà ≈ 0,6 u × masse)
	if spent > 0.0: # la moitié retombe en pièces sur la zone
		var each := spent * RUIN_REFUND_FRAC / float(RUIN_COINS)
		for i in RUIN_COINS:
			var a := (float(i) + _rng.randf_range(-0.3, 0.3)) * TAU / float(RUIN_COINS)
			var d := _rng.randf_range(1.2, s.radius_u * 0.8) * Balance.UNIT_PX
			drop_coin(_clip_to_walls(pos, pos + Vector2.from_angle(a) * d), each, RUIN_COIN_LIFE_S, RUIN_COIN_DELAY_S)
	LightRig.flash(pos, LIGHT_PRESET, 0.9, {"energy": 2.0, "radius": 2.2})
	_shake(10.0)


# --- Variantes : effets ----------------------------------------------------------------------------

## Coffre-bélier : ligne de RAM_LENGTH_U x RAM_WIDTH_U vers `dir`, coef à tout monstre de la ligne (recul via hit_force).
func _do_ram(s: SpellData, dir: Vector2) -> void:
	var c := _caster()
	if c == null:
		return
	var zk: float = 1.0 + player.stat(&"zone_size_add")
	var length: float = RAM_LENGTH_U * Balance.UNIT_PX * zk
	var half_w: float = RAM_WIDTH_U * Balance.UNIT_PX * zk * 0.5
	var origin := player.global_position
	for e in ram_targets(origin, dir, length, half_w):
		if is_instance_valid(e):
			c.deal_damage(e, s, {"source_pos": origin})
	_play_ram_fx(origin, dir, length, half_w)


## Monstres touchés par la ligne (origine, sens, longueur, demi-largeur en px ; marge de corps comprise).
func ram_targets(origin: Vector2, dir: Vector2, length: float, half_w: float) -> Array:
	var out: Array = []
	var n := dir.normalized()
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and e.has_method(&"take_damage"):
			var v: Vector2 = (e as Node2D).global_position - origin
			var along := v.dot(n)
			if along >= -8.0 and along <= length + 8.0 and absf(v.cross(n)) <= half_w + 14.0:
				out.append(e)
	return out


func _play_ram_fx(origin: Vector2, dir: Vector2, length: float, half_w: float) -> void:
	var c := _caster()
	var par: Node = c.effects_parent() if c != null else null
	if par == null:
		return
	var l := Line2D.new() # placeholder : traînée dorée en ligne (chest_ram à venir)
	l.width = half_w * 1.4
	l.default_color = Color(GOLD, 0.55)
	l.add_point(origin)
	l.add_point(origin + dir.normalized() * length)
	l.z_index = 2
	par.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.22)
	tw.tween_callback(l.queue_free)
	LightRig.flash(origin + dir.normalized() * length * 0.5, LIGHT_PRESET, 0.3)


## Pièce truquée : une pièce vers `dir` (portée du sort), rebonds de monstre en monstre, tombe où elle s'arrête.
func _do_trick_coin(s: SpellData, dir: Vector2) -> AvareBounceCoin:
	var c := _caster()
	var par: Node = c.effects_parent() if c != null else null
	if par == null:
		return null
	var coin := AvareBounceCoin.new()
	coin.kit = self
	coin.spell = s
	coin.speed_px = s.speed_u * Balance.UNIT_PX * (1.0 + minf(player.stat(&"projectile_speed"), Balance.PROJECTILE_SPEED_BONUS_CAP))
	coin.bounce_px = TRICK_BOUNCE_U * Balance.UNIT_PX
	coin.bounces_left = TRICK_BOUNCES
	coin.value = _salvo_coin_value
	par.add_child(coin)
	coin.launch(player.global_position, dir, _clip_len(player.global_position, dir, s.range_u * Balance.UNIT_PX))
	return coin


## Saisie : chaîne vers `point` (<= 5 u), marque les monstres du disque de 2 u, les frappe puis tire les non-boss
## à GRAB_FRONT_U devant Avare (Enemy.push parcourt tout le déplacement, murs exceptés).
func _do_grab(s: SpellData, point: Vector2) -> void:
	var c := _caster()
	if c == null:
		return
	var pos := player.global_position
	var r: float = s.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
	var victims := _enemies_in(point, r)
	for e in victims: # marque d'abord : un monstre tué par la Saisie paie déjà sa rançon
		marks[e.get_instance_id()] = {"t": _clock + RANSOM_MARK_S, "ref": weakref(e)}
	c.spawn_zone(s, point)
	var dir: Vector2 = (point - pos).normalized() if point.distance_to(pos) > 1.0 else player.facing
	var front: Vector2 = pos + dir * GRAB_FRONT_U * Balance.UNIT_PX
	for e in victims:
		if is_instance_valid(e) and e is Enemy and e.active and not e.is_boss:
			var jitter := Vector2(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35)) * Balance.UNIT_PX
			e.push(front + jitter - e.global_position)
	_play_chain_fx(pos, point)
	LightRig.flash(point, LIGHT_PRESET, 0.45)
	_shake(5.0)


func _play_chain_fx(a: Vector2, b: Vector2) -> void:
	var c := _caster()
	var par: Node = c.effects_parent() if c != null else null
	if par == null:
		return
	var l := Line2D.new() # placeholder : chaîne fer noir + maillons dorés
	l.width = 7.0
	l.default_color = Color("#2A2622")
	l.add_point(a)
	l.add_point(b)
	l.z_index = 2
	par.add_child(l)
	var g := Line2D.new()
	g.width = 3.0
	g.default_color = GOLD
	g.add_point(a)
	g.add_point(b)
	l.add_child(g)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, GRAB_CHAIN_S)
	tw.tween_callback(l.queue_free)


## Trésor enterré : floor(50 % de l'or) quitte la bourse, un coffre-mine est posé aux pieds d'Avare.
func _do_buried(s: SpellData) -> AvareMine:
	var c := _caster()
	if c == null:
		return null
	var power_before := gold_power()
	var buried := floorf(RunState.gold * BURIED_SPEND_FRAC)
	if buried > 0.0 and not RunState.spend_gold(buried):
		buried = 0.0
	var m := AvareMine.new()
	m.kit = self
	m.spell = s
	m.buried = buried
	m.power = power_before
	m.radius_px = s.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
	var par: Node = c.effects_parent()
	par.add_child(m)
	m.global_position = player.global_position
	m.z_index = -1
	mines.append(m)
	m.tree_exiting.connect(func() -> void: mines.erase(m))
	LightRig.flash(m.global_position, LIGHT_PRESET, 0.5)
	_shake(4.0)
	return m


## Détonation du coffre-mine (AvareMine._boom) : explosion avec la puissance d'AVANT l'enterrement, recul,
## puis tout l'or enterré (x BURIED_REFUND_FRAC) retombe en BURIED_COINS pièces.
func detonate_mine(m: AvareMine) -> void:
	var c := _caster()
	if c == null or player == null or not is_instance_valid(player):
		return
	var pos := m.global_position
	var boom := m.spell.duplicate() as SpellData
	boom.coef = buried_coef(m.buried)
	last_buried = {"buried": m.buried, "coef": boom.coef, "cause": m.detonation_cause}
	var r: float = m.spell.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
	var victims := _enemies_in(pos, r)
	_power_override = m.power
	c.spawn_zone(boom, pos)
	_power_override = -1.0
	_blast_push(victims, pos, BURIED_PUSH_U)
	if m.buried > 0.0:
		var each := m.buried * BURIED_REFUND_FRAC / float(BURIED_COINS)
		for i in BURIED_COINS:
			var a := (float(i) + _rng.randf_range(-0.3, 0.3)) * TAU / float(BURIED_COINS)
			var d := _rng.randf_range(BURIED_COIN_RING_U.x, BURIED_COIN_RING_U.y) * Balance.UNIT_PX
			drop_coin(_clip_to_walls(pos, pos + Vector2.from_angle(a) * d), each, RUIN_COIN_LIFE_S, RUIN_COIN_DELAY_S)
	LightRig.flash(pos, LIGHT_PRESET, 0.9, {"energy": 2.0, "radius": 2.2})
	_shake(10.0)


## Coef du Trésor enterré pour un or enterré.
static func buried_coef(buried: float) -> float:
	return BURIED_BASE_COEF + BURIED_BONUS_COEF * minf(1.0, buried / (RUIN_BONUS_AT_P * price_unit()))


## Recul radial (u x masse) au-delà du recul du coup direct.
func _blast_push(victims: Array, pos: Vector2, push_u: float) -> void:
	for e in victims:
		if is_instance_valid(e) and e is Enemy and e.active and not e.is_boss:
			var away: Vector2 = e.global_position - pos
			if away.length_squared() > 1.0:
				var mass := Balance.knockback_mass(e.tier, e.is_elite, &"")
				e.push(away.normalized() * maxf(push_u - Balance.KB_MAX_U, 0.0) * mass * Balance.UNIT_PX)


## Longueur libre depuis `from` vers `dir` (px), arrêtée par un mur.
func _clip_len(from: Vector2, dir: Vector2, length: float) -> float:
	return _clip_to_walls(from, from + dir.normalized() * length).distance_to(from)


# --- Pièces ----------------------------------------------------------------------------------

## Pose une pièce d'Avare : ramassée au contact, rend exactement `value` (pas de gold_mult : aucun or créé).
func drop_coin(at: Vector2, value: float, life_s: float, delay_s := 0.0) -> GroundPickup:
	if player == null or player.get_parent() == null or value <= 0.0:
		return null
	var g := GroundPickup.spawn(player.get_parent(), at, player, func(gp: GroundPickup) -> void:
		_collect_coin(gp), life_s, COIN_CONTACT_U, COIN_PICKUP_FRAMES, Vector2.RIGHT)
	g.delay_s = delay_s
	g.color = GOLD
	g.set_marker_radius_u(0.28) # repère au sol : petit halo sous la pièce
	g.set_meta(&"gold", value)
	g.set_meta(PLAYER_RESOURCE_META, true) # ressource de joueur : ramassage manuel, jamais automatique
	if not ResourceLoader.exists(COIN_PICKUP_FRAMES) and ResourceLoader.exists(COIN_FALLBACK_TEX):
		var tex := load(COIN_FALLBACK_TEX) as Texture2D # repli : la pièce des pickups (rendu Codex)
		var spr := Sprite2D.new()
		spr.texture = tex
		var k := 26.0 / maxf(tex.get_size().x, tex.get_size().y)
		spr.scale = Vector2(k, k * Iso.UNSQUASH.y)
		spr.position = Vector2(0, -6.0)
		g.add_child(spr)
		g.set_meta(&"fallback_sprite", spr)
	coins.append(g)
	g.tree_exiting.connect(func() -> void: coins.erase(g))
	_enforce_coin_cap()
	return g


## Trop de pièces au sol : les plus anciennes rentrent dans la bourse (aucun or perdu ni créé).
func _enforce_coin_cap() -> void:
	while coins.size() > MAX_GROUND_COINS:
		var old: Variant = coins.pop_front()
		if old != null and is_instance_valid(old) and not (old as GroundPickup).is_queued_for_deletion():
			(old as GroundPickup).collect()


func _collect_coin(g: GroundPickup) -> void:
	var v := float(g.get_meta(&"gold", 0.0))
	if v > 0.0:
		RunState.add_gold(v)
	RunState.add_counter(COUNTER_COINS, 1.0) # déblocage de la Pièce truquée
	if player != null:
		Audio.play(&"pickup.coin", player.global_position, -6.0, _rng.randf_range(0.95, 1.15))


## Or au sol (non ramassé) : somme des pièces d'Avare.
func ground_gold() -> float:
	var t := 0.0
	for g in coins:
		if is_instance_valid(g):
			t += float(g.get_meta(&"gold", 0.0))
	return t


# --- Malus : chaque coup subi fait tomber 3 % de l'or ----------------------------------------------

func _on_player_damaged(_amount: float, _source: Node) -> void:
	if player == null or player.dead:
		return
	var loss := RunState.gold * BLEED_FRAC
	if loss < BLEED_MIN_GOLD or not RunState.spend_gold(loss):
		return
	var pos := player.global_position
	var a0 := _rng.randf() * TAU
	for i in BLEED_COINS:
		var a := a0 + float(i) * TAU / float(BLEED_COINS) + _rng.randf_range(-0.35, 0.35)
		var d := _rng.randf_range(BLEED_RING_U.x, BLEED_RING_U.y) * Balance.UNIT_PX
		drop_coin(_clip_to_walls(pos, pos + Vector2.from_angle(a) * d), loss / float(BLEED_COINS), BLEED_LIFE_S, BLEED_DELAY_S)
	_play_bleed_fx()
	Audio.play(&"pickup.coin", pos, -4.0, 0.7)


# --- Rançon : prime à la mort des monstres marqués -----------------------------------------------

func is_marked(e: Node) -> bool:
	var m: Variant = marks.get(e.get_instance_id())
	return m != null and float(m["t"]) > _clock


func _on_enemy_killed(enemy: Node2D, pos: Vector2, tier: int, is_elite: bool) -> void:
	if enemy == null:
		return
	var id := enemy.get_instance_id()
	if not marks.has(id):
		return
	var live := float(marks[id]["t"]) > _clock
	marks.erase(id) # monstre recyclé par le pool : jamais de marque héritée
	if not live:
		return
	var bonus := RANSOM_GOLD_BONUS * Balance.monster_gold(RunState.difficulty(), Balance.monster_cost(tier, is_elite))
	var pm := get_tree().get_first_node_in_group(&"pickups") as PickupManager if is_inside_tree() else null
	if pm != null and bonus > 0.0:
		pm.drop(pos + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10)), PickupManager.KIND_GOLD, bonus)
		RunState.add_counter(COUNTER_RANSOM_GOLD, bonus) # déblocage de la Saisie


# --- Boucle (Player.tick) ----------------------------------------------------------------------

func tick(delta: float) -> void:
	_clock += delta
	guard_left = maxf(guard_left - delta, 0.0)
	if player != null and player.is_dodging():
		_rake()
	elif rake_left > 0.0:
		rake_left = maxf(rake_left - delta, 0.0)
		_rake()
	if not marks.is_empty() and Engine.get_physics_frames() % 30 == 0:
		for id in marks.keys():
			if float(marks[id]["t"]) <= _clock or (marks[id]["ref"] as WeakRef).get_ref() == null:
				marks.erase(id)
	_update_purse_look()


## La bourse se lit sur Avare : l'or qui fuit du coffre (masque _e) et sa lueur suivent la puissance.
func _update_purse_look() -> void:
	var k := gold_power_for(RunState.gold) / GOLD_POWER_CAP
	if _visual != null:
		NormalMaps.set_emission_energy(_visual, lerpf(EMISSION_MIN, EMISSION_MAX, k))
	if _glow != null:
		_glow.set_energy(lerpf(GLOW_MIN, GLOW_MAX, k))


# --- Nettoyage ---------------------------------------------------------------------------------

func clear_transients() -> void:
	_pending.clear()
	for m in mines.duplicate():
		if is_instance_valid(m):
			m.detonated = true
			m.queue_free()
	mines.clear()
	marks.clear()
	for g in coins.duplicate():
		if is_instance_valid(g):
			g.queue_free()
	coins.clear()


func _on_floor_started(_n: int) -> void:
	refund_mines() # l'or enterré rentre dans la bourse au changement d'étage
	clear_transients()


## Boss d'étage vaincu à l'étage 2 (déblocage du Trésor enterré).
func _on_boss_killed(_boss: Node2D, is_floor_boss: bool) -> void:
	if is_floor_boss and RunState.stage == BOSS_FLOOR:
		RunState.add_counter(COUNTER_BOSS2, 1.0)


## Coffres-mines non détonés : l'or enterré revient dans la bourse (aucun or perdu), les coffres disparaissent.
func refund_mines() -> void:
	for m in mines.duplicate():
		if is_instance_valid(m):
			if not m.detonated and m.buried > 0.0:
				RunState.add_gold(m.buried)
			m.detonated = true
			m.queue_free()
	mines.clear()


func _on_player_died() -> void:
	clear_transients()
	if _visual != null and _visual.sprite_frames != null:
		var anim := StringName("death_" + _dir_name())
		if _visual.sprite_frames.has_animation(anim):
			_visual.sprite_frames.set_animation_loop(anim, false)
			_visual.play(anim)


# --- Utilitaires et rendu -----------------------------------------------------------------------

func _dir_name() -> String:
	var i := roundi(player.facing.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES[(i + 8) % 8]


func _nearest_enemy(max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e):
			var d: float = (e as Node2D).global_position.distance_to(player.global_position)
			if d <= best_d:
				best_d = d
				best = e
	return best


func _enemies_in(pos: Vector2, r: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and e.has_method(&"take_damage") and (e as Node2D).global_position.distance_to(pos) <= r:
			out.append(e)
	return out


## Point le plus loin vers `to` sans traverser un mur.
func _clip_to_walls(from: Vector2, to: Vector2) -> Vector2:
	if player == null or not player.is_inside_tree():
		return to
	var q := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK, [player.get_rid()])
	var hit := player.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	return (hit["position"] as Vector2) - (to - from).normalized() * 8.0


func _shake(px: float) -> void:
	var n := player.get_parent()
	while n != null:
		if n.has_method(&"shake"):
			n.shake(px, 22.0, 0.2)
			return
		n = n.get_parent()


## Balayage du coffre rendu (AA2) : enfant du sprite d'Avare (même échelle, même pivot), une fois.
func _play_arc_fx(dir: Vector2, radius_u := SWING_RADIUS_U) -> void:
	if _visual == null or _arc_frames == null:
		return
	var i := roundi(dir.angle() / (TAU / 8.0)) % 8
	var anim := StringName("coffre_arc_" + DIR_NAMES[(i + 8) % 8])
	if not _arc_frames.has_animation(anim):
		return
	var fx := AnimatedSprite2D.new()
	fx.name = "CoffreArc"
	fx.offset = _visual.offset
	fx.centered = _visual.centered
	var k := radius_u / (COFFRE_ARC_REACH_PX / Iso.RENDER_PX_PER_U) # même repère que le Visual : échelle uniforme
	fx.scale = Vector2(k, k)
	_visual.add_child(fx)
	EmissiveOverlay.apply(fx, _arc_frames)
	fx.sprite_frames.set_animation_loop(anim, false)
	fx.play(anim)
	fx.animation_finished.connect(fx.queue_free)


## Or qui gicle du coffre au coup subi (AA2) ; absent : rien (les pièces au sol suffisent).
func _play_bleed_fx() -> void:
	if _visual == null or _bleed_frames == null or not _bleed_frames.has_animation(&"default"):
		return
	var fx := AnimatedSprite2D.new()
	fx.name = "GoldBleed"
	fx.offset = _visual.offset
	_visual.add_child(fx)
	EmissiveOverlay.apply(fx, _bleed_frames)
	fx.sprite_frames.set_animation_loop(&"default", false)
	fx.play(&"default")
	fx.animation_finished.connect(fx.queue_free)



# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) ------------------------------------

static func passive_info() -> Dictionary:
	return KitResource.passive("Bourse", &"bourse",
		"L'or que tu portes fait ta force : +%s de dégâts par prix de petit coffre en bourse (un repère sur la jauge), plafond +%s." % [
			KitResource.pct(GOLD_POWER_PER_P), KitResource.pct(GOLD_POWER_CAP)],
		"l'or ramassé, et les pièces de la Poignée que tu reprends au sol.",
		"la Poignée coûte %s de l'or, la Faillite la moitié, et chaque coup subi fait tomber %s de l'or en pièces à ramasser. À chaque étage, tu gardes %s de ta bourse." % [
			KitResource.pct(COINS_COST_FRAC), KitResource.pct(BLEED_FRAC), KitResource.pct(FLOOR_GOLD_KEEP)],
		"bourse vide : la Poignée part gratuite, sans pièces à reprendre.")
