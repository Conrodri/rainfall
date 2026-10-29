class_name AverseKit
extends Node
## Kit d'Averse, la porteuse de pluie (docs/Design_Personnages.md §2.1) : distance / zone, ressource « Eau » 0-100
## portée dans l'amphore. Plus l'amphore est pleine, plus elle est lente ; il faut dépenser pour courir.
## Enfant « Kit » du joueur (CharacterData.kit_script), interrogé par hooks comme RictusKit (blocks_slot,
## cast_spell, speed_mult, can_dodge, visual_anim…). Les 4 sorts sont SpellData.Behavior.KIT : le kit
## consomme l'eau au lancement et déclenche l'effet à la frame d'impact de l'anim d'action (Player.action_impact).
## Refonte « sans recharge » (demande du joueur, 22/10/2026) : les sorts 2-4 n'ont plus de temps de recharge, la
## seule limite est l'EAU (verrou anti-spam = jusqu'à la frame d'impact de l'anim, au moins CAST_LOCK_S).
## - Sort 1 Goutte-lame : projectile auto vers l'ennemi le plus proche, coef 0,75 + 0,4 × eau/100, traverse 1,
##   gratuit ; chaque goutte qui touche rend un peu d'eau (plus sur élite/boss).
## - Sort 2 Vague (WAVE_COST) : cône de 6,25 u / 60° vers la visée, recul 1,5 u, trempe 4 s (ralenti 30 %).
## - Sort 3 Flaque-miroir (PUDDLE_COST) : zone au sol 3,1 u, 6 s, trempe ; Averse y regagne de l'eau ; PUDDLE_MAX
##   flaques au plus (la plus ancienne s'assèche).
## - Sort 4 Crue (toute l'eau, min CRUE_MIN) : onde 5 u + 0,02 u/eau, coef CRUE_COEF_FULL × (eau/100)^CRUE_COEF_EXP
##   (garder l'eau paie : rendement par goutte croissant), recul 3 u × masse, trempe, laisse une Flaque-miroir.
## - Eau : pluie × carte (0,5-1,5), gouttes qui touchent, monstres tués, eau de la carte, sa Flaque.
## - À sec : une Vague / Flaque qui vide l'amphore (< DRY_BELOW) la laisse « à sec » DRY_LOCK_S s, sans aucun gain.
##   La Crue, vidange volontaire, n'est jamais pénalisée.
## - Esquive = Glissade (SlideDodge, docs/Design_Esquives.md) : elle verse de l'eau sous ses pieds et glisse tant que le
##   bouton est tenu et qu'il reste de l'eau (SLIDE_START_COST au départ puis SLIDE_DRAIN_PER_S, drain ÷2 sur l'eau de
##   la carte, une Flaque ou une Gouttière) ; contact des monstres ignoré en glisse (projectiles et zones touchent).
## - Amphore ≥ 80 : à l'arrêt de la glisse, elle freine mal (anim `stumble`, vitesse ×0,6 STUMBLE_RECOVER_S).
## Variantes (docs/Variantes_Sorts.md §2.4, `variant(slot, id)`) : Bruine (sort 1, 3 gouttes en éventail), Geyser (sort 2,
##   projection en l'air), Gouttière (sort 3, ligne qui porte Averse), Mousson (sort 4, déluge attaché à Averse).
## Rendu : averse.tres (lot AV1) ; niveau d'eau = énergie du masque `_e` (fenêtre de l'amphore) ; VFX AV2.

# --- Assets (lots Codex AV1/AV2) ------------------------------------------------------------------
const ASSET_DIR := "res://assets/sprites/characters/averse/"
const SPRITE_FRAMES := ASSET_DIR + "averse.tres" ## idle/run/attack/cast/wave/crue/cast_ult/stumble/death _<dir>
const GOUTTE_FRAMES := ASSET_DIR + "effects/goutte_lame/goutte_lame.tres" ## `default`, pointe vers +X
## Cône de la Vague : rig CREA (même échelle que le personnage, 90,5 px/u), `wave_cone_<dir>`, pivot au centre.
const WAVE_FRAMES := ASSET_DIR + "effects/wave_cone/wave_cone.tres"
const WAVE_VFX_LENGTH_U := 5.0 ## longueur du cône rendu à l'échelle 1 (le sprite suit WAVE_LENGTH_U par k)
## Flaque-miroir : `default` en boucle, cellule 416 px ; bord du disque à 150,4 px du centre (sortie du lot R1,
## _logr1.txt.last.txt). ZoneEffect met le VFX à l'échelle rayon logique / PUDDLE_RADIUS_PX : le disque vu = la zone.
## Correctif 23/10 : la constante était restée à 301 px (planches AV2 avant R1) : le disque s'affichait à la MOITIÉ
## du rayon réel (retour joueur « Flaque un peu petite »).
const PUDDLE_FRAMES := ASSET_DIR + "effects/puddle_mirror/puddle_mirror.tres"
const PUDDLE_RADIUS_PX := 150.4
## Crue : `default` 8 frames non bouclées, cellule 800 px ; anneau final à 374,6 px du centre (sortie R1). Même
## correctif : 776 px (avant R1) affichait l'onde à la moitié de son rayon réel.
const CRUE_FRAMES := ASSET_DIR + "effects/crue_ring/crue_ring.tres"
const CRUE_RADIUS_PX := 374.6
const PLACEHOLDER_TINT := Color(0.62, 0.7, 0.8) ## Ardent teinté ciré gris pluie, si AV1 manquait

# --- Rendu ------------------------------------------------------------------------------------------
const ACCENT := Color("#5FD4E8") ## eau cyan : accent émissif unique
const PLAYER_LIGHT_COLOR := Color("#B8E2EA") ## la lumière du joueur passe de la braise d'Ardent à une pluie froide
const PLAYER_CORE_COLOR := Color("#8FD6E4")
const EMISSION_EMPTY := 0.25 ## énergie du `_e` (fenêtre de l'amphore) à 0 d'eau
const EMISSION_FULL := 2.8 ## à 100 d'eau
const EMISSION_STEPS := 20 ## paliers (un matériau par palier, jamais recréé à chaque image)
const WAVE_EMISSION := 4.5 ## crêtes cyan du cône bien lisibles sur l'eau noire (le diffus est très sombre)
const WAVE_SPRITE_SCALE := Vector2(Iso.SPRITE_K, Iso.SPRITE_K * 2.0) ## comme le nœud Visual du joueur
## Flaque et Crue se ressemblaient au sol (retour du joueur, 22/10/2026) : la Flaque-miroir reste un miroir d'eau
## calme et sombre (teinte froide, valeur basse) ; la Crue devient une déferlante LUMINEUSE (anneau en mélange
## additif : le mur d'eau sombre disparaît, seules les crêtes brillent, teinte HDR blanc-cyan) qui grandit.
const PUDDLE_VFX_TINT := Color(0.62, 0.72, 0.86)
const CRUE_VFX_TINT := Color(1.6, 2.0, 2.2)
const ACTION_IMPACT_FRAMES := {&"attack": 3, &"wave": 3, &"cast": 2, &"crue": 5, &"cast_ult": 5}

# --- Statistiques (§2.1) ----------------------------------------------------------------------------
const BASE_HP := 90.0
const HP_PER_LEVEL := 27.0
const BASE_REGEN := 1.0
const REGEN_PER_LEVEL := 0.2
const HITBOX_U := 0.5
const SPEED_EMPTY_U := 4.4 ## vitesse à 0 d'eau (base du personnage)
const SPEED_FULL_U := 3.4 ## à 100 d'eau (linéaire, avant les items)

# --- Eau (refonte sans recharge, 22/10/2026 : l'eau est la seule limite des sorts 2-4) -------------
const WATER_MAX := 100.0
const WATER_START := 50.0 ## amphore à moitié pleine en début de run : sorts 2-4 disponibles tout de suite
## Pluie passive réduite (4 -> 2,5/s) : sans recharge, l'eau doit surtout se GAGNER en combat (gouttes, kills,
## flaque) ; la pluie seule ne paie qu'une Vague toutes les ~8 s.
const RAIN_GAIN_PER_S := 2.5
const RAIN_MULT_MIN := 0.5
const RAIN_MULT_MAX := 1.5
const RAIN_DRY_BELOW := 0.05 ## rain_intensity du profil sous ce seuil = pas de pluie (Cryptes noyées)
const RAIN_FALLBACK_MULT := 1.0 ## sans AmbianceManager (tests, cartes nues) : pluie moyenne
const RAIN_POLL_S := 0.5
const KILL_GAIN := 0.9
## « Chaque goutte revient à l'amphore » : une Goutte-lame qui touche rend HIT_WATER (BIG_HIT_WATER sur une élite
## ou un boss : contre une cible unique, l'auto-attaque est la vraie source d'eau).
const HIT_WATER := 0.4 ## combos 29/10 : 0,5 -> 0,4 (compense AV-3, docs/Design_Combos.md §4.3)
const BIG_HIT_WATER := 1.0 ## équilibrage P1 23/10 : 2,0 -> 1,0 (eau sur boss ×2,5 trop forte)
## Eau de la carte 12 -> 7/s (retour joueur 23/10) : à 12 (+2,5 de pluie) l'amphore se remplissait en ~7 s, une
## Crue pleine toutes les 8 s en restant dans l'eau (+19 % de DPS moyen, +45-57 % sur élite / mini-boss mesurés).
const MAP_WATER_GAIN_PER_S := 7.0
const PUDDLE_GAIN_PER_S := 2.5 ## dans SA flaque (une seule comptée) : rend ~15 des 18 d'eau si elle y reste 6 s (P1 23/10 : 4 -> 2,5)
## À sec : une Vague / Flaque qui laisse moins de DRY_BELOW d'eau fige tout gain pendant DRY_LOCK_S
## (l'amphore « boit l'air ») ; garder une gorgée est un choix. La Crue n'est jamais pénalisée.
const DRY_BELOW := 1.0
const DRY_LOCK_S := 2.0
## Les objets de recharge (cooldown_mult) deviennent des économies d'eau : coût × cooldown_mult, plancher COST_FLOOR.
const COST_FLOOR := 0.75

# --- Sorts ---------------------------------------------------------------------------------------
const GOUTTE_COEF_MIN := 0.7 ## équilibrage 22/10 : 0,6 -> 0,75 ; combos 29/10 : 0,7 (compense AV-3)
const GOUTTE_COEF_WATER := 0.4
const GOUTTE_RANGE_U := 9.0
const GOUTTE_CD := 0.6 ## cadence d'attaque du sort 1 (auto), pas une recharge
const GOUTTE_SPEED_U := 13.0

## Verrou anti-spam des sorts 2-4 (aucune recharge) : un sort 2-4 attend que l'effet du précédent soit parti
## (frame d'impact : Vague 0,25 s, Flaque 0,17 s, Crue 0,42 s à 12 i/s) et au moins CAST_LOCK_S, pour que deux
## sorts ne se marchent pas dessus dans la même anim d'action et qu'une touche tenue ne vide pas l'amphore.
const CAST_LOCK_S := 0.2

const WAVE_COST := 20.0
const WAVE_COEF := 3.4 ## combos 29/10 : 3,5 -> 3,4 (compense AV-2)
const WAVE_LENGTH_U := 6.0 ## 5 -> 6 u (retour joueur 23/10 + P1 : cône 19 u²)
const WAVE_SPREAD_DEG := 70.0 ## P1 23/10 : 60 -> 70
const WAVE_KNOCK_U := 1.5

const PUDDLE_COST := 18.0
const PUDDLE_COEF := 0.45 ## P1 23/10 : 0,5 -> 0,45 (compense la surface)
const PUDDLE_RADIUS_U := 3.0 ## 2,5 -> 3,0 u (retour joueur 23/10 + P1)
const PUDDLE_LIFE_S := 6.0
const PUDDLE_TICK_S := 0.5
const PUDDLE_RANGE_U := 7.0 ## portée de pose (comme Cendres)
const PUDDLE_SOAK_POLL_S := 0.25
const PUDDLE_MAX := 2 ## une 3e flaque assèche la plus ancienne (pas de tapis de flaques sur un boss)
## Seule exception à « aucune recharge » (joueur, 22/10/2026) : la Flaque garde une recharge anti-spam.
const PUDDLE_CD := 5.0

const CRUE_MIN := 40.0
## Recharge de la Crue (P1 23/10) : l'eau seule ne bornait pas l'ultime quand elle abonde (Sirlin).
const CRUE_CD := 12.0
## Coef de la Crue = CRUE_COEF_FULL × (eau/100)^CRUE_COEF_EXP. Le rendement par point d'eau monte encore avec le
## remplissage : la Crue pleine reste le meilleur usage de l'eau, à payer en lenteur (trébuchement ≥ 80).
## Retour joueur 23/10 (« la Crue tape énormément pour son coût ») : 15 × (eau/100)^1,5 -> 9 × (eau/100)^1,25
## (40 -> 2,9 ; 70 -> 5,8 ; 100 -> 9, comme le Brasier d'Ardent qui a 20 s de recharge), rayon 4 + 0,02/eau ->
## 5 + 0,02/eau (7 u à 100). P1 23/10 : exposant 1,25 -> 1,2, recharge CRUE_CD.
const CRUE_COEF_FULL := 8.6 ## combos 29/10 : 9 -> 8,6 (compense AV-1 : +20 % sur les trempés)
const CRUE_COEF_EXP := 1.2
const CRUE_RADIUS_U := 5.0
const CRUE_RADIUS_PER_WATER_U := 0.02 ## 5 + 0,02/eau : 7 u à 100 (P1)
const CRUE_KNOCK_U := 3.0

# --- Combos (docs/Design_Combos.md §4) -----------------------------------------------------------
const CRUE_SOAK_MULT := 1.2 ## AV-1 : la Crue (ou la Mousson) fait +20 % sur un monstre déjà trempé
const CRUE_SOAK_KNOCK_U := 4.5 ## AV-1 : recul de la Crue sur un trempé (3 u sinon)
const WAVE_PUDDLE_ADD := 0.5 ## AV-2 : coef additif de la Vague de fond (cône qui traverse une Flaque ou part d'elle)
const WAVE_PUDDLE_SOAK_S := 8.0 ## AV-2 : trempe prolongée
const WAVE_PUDDLE_SOAK_PCT := 0.4
const WAVE_PUDDLE_PULSE := 1.15 ## la Flaque pulse (échelle) quand la Vague de fond la traverse
const WAVE_PUDDLE_PULSE_S := 0.3
const SOAK_HIT_WATER := 1.0 ## AV-3 : eau rendue en plus par une Goutte-lame sur un trempé
const SOAK_GOUTTE_ADD := 0.25 ## AV-3 : coef additif de la Goutte-lame sur un trempé
const BRUINE_SOAK_WATER := 0.33 ## AV-3, Bruine : eau en plus par goutte sur un trempé
const BRUINE_SOAK_VOLLEY_CAP := 2.0 ## plafond de salve sur un trempé (1,0 sinon)
const WAKE_SOAK_S := 2.0 ## AV-4 : le sillage de la Glissade trempe, sans dégât
const WAKE_SOAK_PCT := 0.3
const WAKE_POLL_S := 0.25
const COMBO_READY_POLL_S := 0.25 ## cache de combo_ready (le HUD l'interroge toutes les 0,1 s)
const COMBO_READY_MIN := 3 ## trempés dans le rayon pour que la Crue pulse (un boss trempé suffit)

# --- Variantes de sorts (docs/Variantes_Sorts.md §2.4) --------------------------------------------
const V_BRUINE := &"averse_bruine" ## slot 1 (remplace la Goutte-lame)
const V_GEYSER := &"averse_geyser" ## slot 2 (remplace la Vague)
const V_GOUTTIERE := &"averse_gouttiere" ## slot 3 (remplace la Flaque-miroir)
const V_MOUSSON := &"averse_mousson" ## slot 4 (remplace la Crue)
## VFX des variantes (lot Codex AVSV, art/tools/night/_avsv.txt) : absents = placeholders dessinés en code.
const VAR_DIR := ASSET_DIR + "variants/"
const DROPLET_FRAMES := VAR_DIR + "droplet_small/droplet_small.tres" ## `default`, pointe vers +X
const GEYSER_FRAMES := VAR_DIR + "geyser/geyser.tres"
const GEYSER_RADIUS_PX := 256.0 ## rayon du disque à l'échelle 1 (rig TOP 128 px/u : 2 u)
const MONSOON_FRAMES := VAR_DIR + "monsoon_zone/monsoon_zone.tres"
const MONSOON_RADIUS_PX := 640.0 ## 5 u à 128 px/u

## Compteurs de déblocage (RunState.add_counter, versés dans Profile.stats en fin de run).
const COUNTER_SOAKED := "averse.soaked" ## Geyser : +1 par monstre trempé (un monstre déjà trempé n'est pas recompté)
const COUNTER_PUDDLE_WATER := "averse.puddle_water" ## Gouttière : eau réellement gagnée dans une Flaque-miroir
const COUNTER_FULL_CRUES := "averse.full_crues" ## Mousson : Crue de base lancée avec >= FULL_CRUE_WATER d'eau
const FULL_CRUE_WATER := 99.0

## Bruine : 3 gouttes (coef BRUINE_COEF_MIN + BRUINE_COEF_WATER × eau/100 chacune, figé au tir), éventail 30°, 7 u,
## sans traversée. Eau : HIT_WATER par goutte qui touche, plafonné à BRUINE_VOLLEY_WATER_CAP par salve ; une élite
## ou un boss touché rend BIG_HIT_WATER, une fois par salve, en plus du plafond.
const BRUINE_COEF_MIN := 0.30
const BRUINE_COEF_WATER := 0.15
const BRUINE_RANGE_U := 7.0
const BRUINE_COUNT := 3
const BRUINE_SPREAD_DEG := 30.0
const BRUINE_PROC := 0.6
const BRUINE_VOLLEY_WATER_CAP := 1.0

## Geyser : disque de 2 u au point visé (<= 6 u), télégraphe 0,3 s, coup direct sans recul, trempe, projection 0,8 s
## (statut `imprisoned` + Iso.lift_logical). Un boss n'est pas projeté (il prend les dégâts et la trempe).
const GEYSER_COEF := 3.5
const GEYSER_RADIUS_U := 2.0
const GEYSER_RANGE_U := 6.0
const GEYSER_TELEGRAPH_S := 0.3
const GEYSER_LIFT_S := 0.8
const GEYSER_LIFT_U := 1.0 ## hauteur du sommet de l'arc

## Gouttière : ligne LENGTH x WIDTH u depuis Averse vers le point visé, LIFE s, un coup de GOUTTIERE_COEF par tick ;
## dessus, Averse regagne PUDDLE_GAIN_PER_S d'eau/s et court GOUTTIERE_SPEED_MULT fois plus vite. 2 au plus.
const GOUTTIERE_COEF := 0.45
const GOUTTIERE_RANGE_U := 7.0 ## portée du ciblage du paquet (mobile)
const GOUTTIERE_LENGTH_U := 6.0
const GOUTTIERE_WIDTH_U := 1.0
const GOUTTIERE_LIFE_S := 6.0
const GOUTTIERE_TICK_S := 0.5
const GOUTTIERE_SPEED_MULT := 1.25
const GOUTTIERE_MAX := 2

## Mousson : toute l'eau (min CRUE_MIN) -> zone de MOUSSON_RADIUS_U attachée à Averse pendant MOUSSON_LIFE_S ; dégâts
## totaux = crue_coef(eau) x MOUSSON_TOTAL_MULT répartis en ticks ; MOUSSON_WATER_PER_S d'eau/s rendus. Pas de boucle :
## l'amphore est vidée, la recharge CRUE_CD dépasse la durée et ~18 d'eau + pluie rendus restent sous le seuil de
## relance à pleine amphore (voir averse_variants_test).
const MOUSSON_RADIUS_U := 5.0
const MOUSSON_LIFE_S := 6.0
const MOUSSON_TICK_S := 0.5
const MOUSSON_TOTAL_MULT := 1.0
const MOUSSON_WATER_PER_S := 3.0
const MOUSSON_PROC := 0.3

# --- Auto-cast (option d'accessibilité, simulateur) : ne jamais vider l'eau bêtement ------------------------
## Vague et Flaque ne dépensent que AUTO_SPEND_SHARE de l'eau gagnée (budget) ; le reste s'accumule pour la Crue,
## lancée à AUTO_CRUE_AT (avant le trébuchement), ou dès CRUE_MIN face à une foule (AUTO_CRUE_CROWD monstres dans
## l'onde) ou PV bas (AUTO_CRUE_LOW_HP). Une seule Flaque à la fois en auto.
const AUTO_SPEND_SHARE := 0.6
const AUTO_BUDGET_START := 20.0
const AUTO_BUDGET_MAX := 40.0
const AUTO_CRUE_AT := 75.0
const AUTO_CRUE_CROWD := 6
const AUTO_CRUE_LOW_HP := 0.35
const WARN_S := 0.45 ## clignotement de la jauge quand un sort est refusé faute d'eau

# --- Lisibilité de l'eau (joueur, 22/10/2026 : « je ne connais pas mon taux de régénération ») -----------
const REGEN_WINDOW_S := 1.0 ## taux d'eau mesuré (tout gain compris) sur cette fenêtre, lissé
const REGEN_SMOOTH := 0.5 ## poids de la dernière fenêtre
const POPUP_WINDOW_S := 0.4 ## gains hors pluie cumulés puis affichés « +N » au-dessus d'Averse
const POPUP_MIN := 0.5 ## un kill (0,9) s'affiche « +1 »

const SOAK_S := 4.0 ## trempé = ralenti (clé `slow`)
const SOAK_PCT := 0.30

const STUMBLE_WATER := 80.0
const STUMBLE_RECOVER_S := 0.25
const STUMBLE_SPEED_MULT := 0.6

# --- Glissade (esquive, docs/Design_Esquives.md §Averse) -------------------------------------------------
const SLIDE_SPEED_U := 9.0 ## indépendante du niveau d'eau (lente à pied pleine, glisse à la même vitesse)
const SLIDE_START_COST := 10.0 ## la gerbe de lancement ; sous ce niveau d'eau, bouton grisé
const SLIDE_DRAIN_PER_S := 25.0 ## amphore pleine : 3,6 s de glisse, 32 u
const SLIDE_WATER_DRAIN_MULT := 0.5 ## sur l'eau de la carte, une Flaque ou une Gouttière : l'eau porte
const SLIDE_WAKE_WIDTH_U := 0.6
const SLIDE_WAKE_GLOW := 1.15 ## teinte légèrement > 1 (glow HDR) en additif ; la queue de la trace s'estompe (dégradé)
const SLIDE_WAKE_ALPHA := 0.7
const SLIDE_WAKE_FADE_S := 1.0
const SLIDE_WAKE_MAX_POINTS := 80
const SLIDE_WAKE_MIN_STEP_PX := 6.0
const SLIDE_CONTACT_MARGIN_U := 0.3 ## portée de contact d'un monstre : son rayon + celui d'Averse + cette marge
const SLIDE_SOUND := [&"spell.vague.cast_light", -6.0, 1.25]
const SLIDE_STOP_SOUND := [&"spell.flaque_miroir.cast_light", -10.0, 1.3]
## Trace d'eau : texture `slide_wake` du lot Codex (art/tools/vfx/_dodge_vfx.txt), en additif ; absente = bande cyan unie
## (PLACEHOLDER temporaire, pas un asset final).
const SLIDE_WAKE_TEX := "res://assets/sprites/vfx/dodge_slide/slide_wake.png"
const SLIDE_SPLASH_FRAMES := "res://assets/sprites/vfx/dodge_slide/dodge_slide.tres" ## anim `splash` (lot Codex)
const SLIDE_SPLASH_FALLBACK := ASSET_DIR + "effects/puddle_mirror/puddle_mirror.tres" ## sa Flaque, en petit
const SLIDE_SPLASH_SCALE := 0.6
const SLIDE_SPLASH_FADE_S := 0.7

const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

var player: CharacterBody2D = null
var water := WATER_START
var puddles: Array = [] ## ZoneEffect des Flaques-miroirs vivantes
var stumble_left := 0.0
var sliding := false ## Glissade en cours (SlideDodge)
var _wake: Line2D = null ## trace d'eau de la glisse en cours
var _visual: AnimatedSprite2D = null
var _pending: Array = [] ## [{base, fn, t}] effets en attente de la frame d'impact
var _rain_mult := RAIN_FALLBACK_MULT
var _rain_t := 0.0
var _soak_t := 0.0
var _emission_step := -1
var _grid_cache := {} ## id de carte -> AmbianceWater.grid_of
var in_map_water := false
var in_puddle := false
var dry_left := 0.0 ## « à sec » : aucun gain d'eau tant que > 0
var _lock_left := 0.0 ## verrou anti-spam des sorts 2-4
var _auto_budget := AUTO_BUDGET_START ## eau que l'auto-cast peut dépenser en Vagues / Flaques
var _warn_left := 0.0 ## appui refusé faute d'eau : la jauge clignote
var _regen_rate := 0.0 ## eau/s mesurée (resource_regen_per_s)
var _regen_acc := 0.0
var _regen_t := 0.0
var _popup_acc := 0.0
var _popup_t := 0.0
var rivulets: Array = [] ## AverseRivulet (Gouttière) vivantes
var monsoons: Array = [] ## ZoneEffect (Mousson) attachées à Averse
var monsoon_left := 0.0 ## s de Mousson restantes (eau rendue pendant ce temps)
var in_rivulet := false
var _kit_clock := 0.0 ## horloge du kit (s), avance dans tick()
var _wave_deep := false ## AV-2 : la Vague en cours d'application traverse une Flaque (lu par combo_coef_add)
var _wake_pts := PackedVector2Array() ## AV-4 : polyligne du sillage (monde), <= SLIDE_WAKE_MAX_POINTS
var _wake_left := 0.0 ## s pendant lesquelles le sillage trempe encore après l'arrêt de la glisse
var _wake_t := 0.0
var _ready_t := -10.0 ## combo_ready : dernier sondage (horloge du kit)
var _ready := {2: false, 4: false}
var _soaked_until := {} ## instance id -> _kit_clock de fin de trempe (compteur de trempés sans recomptage)
var _lifted: Array = [] ## Geyser : [{e, t, y0, shadow}] monstres en l'air
var _delayed: Array = [] ## [{t, fn}] effets à retardement (télégraphe du Geyser)
var _base_puddle: SpellData = null ## Flaque-miroir de base (laissée par la Crue même si le slot 3 est une variante)


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
	s.element = &"frost" # eau froide : éclats et son de givre (pas de feu)
	s.color = ACCENT
	s.light_preset = &"averse_water"
	return s


static func character() -> CharacterData:
	var c := CharacterData.new()
	c.id = &"averse"
	c.display_name = "Averse"
	c.base_hp = BASE_HP
	c.hp_per_level = HP_PER_LEVEL
	c.armor = 0.0
	c.base_regen = BASE_REGEN
	c.regen_per_level = REGEN_PER_LEVEL
	c.base_speed_u = SPEED_EMPTY_U
	c.hitbox_u = HITBOX_U
	c.kit_script = AverseKit
	c.sprite_frames_path = SPRITE_FRAMES
	c.placeholder_tint = PLACEHOLDER_TINT
	c.body_color = Color("#4A5565")
	c.accent_color = ACCENT
	c.light_color = PLAYER_LIGHT_COLOR
	c.light_core_color = PLAYER_CORE_COLOR
	c.action_impact_frames = ACTION_IMPACT_FRAMES

	var s1 := _spell(&"goutte_lame", "Goutte-lame", 1, GOUTTE_COEF_MIN, GOUTTE_CD)
	s1.is_auto = true
	s1.range_u = GOUTTE_RANGE_U
	s1.trigger_range_u = GOUTTE_RANGE_U
	s1.pierce = 1
	s1.is_zone = false
	s1.proc_coef = 1.0
	s1.speed_u = GOUTTE_SPEED_U
	s1.projectile_frames = GOUTTE_FRAMES

	var s2 := _spell(&"vague", "Vague", 2, WAVE_COEF, 0.0) # aucune recharge : l'eau limite
	s2.range_u = WAVE_LENGTH_U
	s2.radius_u = WAVE_LENGTH_U
	s2.spread_deg = WAVE_SPREAD_DEG
	s2.proc_coef = 1.0
	s2.trigger_range_u = WAVE_LENGTH_U - 1.0
	s2.target_mode = &"densest"
	s2.hit_force = 1.0
	s2.light_preset = &"averse_wave"
	s2.vfx_frames = WAVE_FRAMES

	var s3 := _spell(&"flaque_miroir", "Flaque-miroir", 3, PUDDLE_COEF, PUDDLE_CD)
	s3.range_u = PUDDLE_RANGE_U
	s3.radius_u = PUDDLE_RADIUS_U
	s3.duration = PUDDLE_LIFE_S
	s3.tick = PUDDLE_TICK_S
	s3.proc_coef = 0.3
	s3.trigger_range_u = 6.0
	s3.target_mode = &"densest"
	s3.vfx_frames = PUDDLE_FRAMES
	s3.vfx_radius_px = PUDDLE_RADIUS_PX
	s3.vfx_floor_aspect = 1.0 # rig TOP : jamais pré-écrasé

	var s4 := _spell(&"crue", "Crue", 4, crue_coef(CRUE_MIN), CRUE_CD)
	s4.radius_u = CRUE_RADIUS_U + CRUE_RADIUS_PER_WATER_U * WATER_MAX
	s4.proc_coef = 1.0
	s4.trigger_range_u = CRUE_RADIUS_U
	s4.hit_force = 1.0
	s4.light_preset = &"averse_crue"
	s4.vfx_frames = CRUE_FRAMES
	s4.vfx_radius_px = CRUE_RADIUS_PX
	s4.vfx_floor_aspect = 1.0
	s4.vfx_additive = true # déferlante lumineuse, jamais une flaque sombre

	c.spells = [s1, s2, s3, s4]
	return c


## Variantes (contrat CONTRACTS.md) : SpellData de la variante `variant_id` pour `slot`, ou null (non codée).
## Coefficients ajustés par balance_sim (±15 % du sort de base en DPS cible et zone) ; le style ne change pas.
static func variant(slot: int, variant_id: StringName) -> SpellData:
	match [slot, variant_id]:
		[1, V_BRUINE]:
			var s1 := _spell(V_BRUINE, "Bruine", 1, BRUINE_COEF_MIN, GOUTTE_CD)
			s1.is_auto = true
			s1.range_u = BRUINE_RANGE_U
			s1.trigger_range_u = BRUINE_RANGE_U
			s1.count = BRUINE_COUNT
			s1.spread_deg = BRUINE_SPREAD_DEG
			s1.pierce = 0
			s1.is_zone = false
			s1.proc_coef = BRUINE_PROC
			s1.speed_u = GOUTTE_SPEED_U
			s1.projectile_frames = DROPLET_FRAMES if ResourceLoader.exists(DROPLET_FRAMES) else GOUTTE_FRAMES
			return s1
		[2, V_GEYSER]:
			var s2 := _spell(V_GEYSER, "Geyser", 2, GEYSER_COEF, 0.0)
			s2.range_u = GEYSER_RANGE_U
			s2.radius_u = GEYSER_RADIUS_U
			s2.proc_coef = 1.0
			s2.trigger_range_u = GEYSER_RANGE_U - 1.0
			s2.target_mode = &"densest"
			s2.light_preset = &"averse_wave"
			return s2
		[3, V_GOUTTIERE]:
			var s3 := _spell(V_GOUTTIERE, "Gouttière", 3, GOUTTIERE_COEF, PUDDLE_CD)
			s3.range_u = GOUTTIERE_RANGE_U
			s3.radius_u = GOUTTIERE_LENGTH_U # longueur de la ligne (affichage et portée utile)
			s3.duration = GOUTTIERE_LIFE_S
			s3.tick = GOUTTIERE_TICK_S
			s3.proc_coef = 0.3
			s3.trigger_range_u = 6.0
			s3.target_mode = &"densest"
			return s3
		[4, V_MOUSSON]:
			var s4 := _spell(V_MOUSSON, "Mousson", 4, crue_coef(CRUE_MIN), CRUE_CD)
			s4.radius_u = MOUSSON_RADIUS_U
			s4.duration = MOUSSON_LIFE_S
			s4.tick = MOUSSON_TICK_S
			s4.proc_coef = MOUSSON_PROC
			s4.trigger_range_u = MOUSSON_RADIUS_U
			s4.light_preset = &"averse_crue"
			return s4
	return null


# --- Mise en place ------------------------------------------------------------------------------

func setup(p: CharacterBody2D) -> void:
	player = p
	_visual = p.get_node_or_null(^"Visual") as AnimatedSprite2D
	Events.floor_started.connect(_on_floor_started)
	Events.player_died.connect(_on_player_died)
	Events.enemy_killed.connect(_on_enemy_killed)
	if p.has_signal(&"action_impact"):
		p.action_impact.connect(_on_action_impact)
	_poll_rain()
	_update_emission()


func _exit_tree() -> void:
	for sig: Signal in [Events.floor_started, Events.player_died, Events.enemy_killed]:
		for cb: Callable in [_on_floor_started, _on_player_died, _on_enemy_killed]:
			if sig.is_connected(cb):
				sig.disconnect(cb)
	clear_transients()


func _caster() -> SpellCaster:
	return player.spells if player != null else null


# --- Eau ---------------------------------------------------------------------------------------

func water_ratio() -> float:
	return water / WATER_MAX


## Mode test « ressource pleine » et aperçu : eau au maximum, état « à sec » levé.
func refill_resource() -> void:
	water = WATER_MAX
	dry_left = 0.0


## Ressource (contrat KitResource) : l'eau de l'amphore ; repère = seuil du trébuchement.
## Repère principal = seuil de la Crue (CRUE_MIN) ; repère secondaire = trébuchement. À sec : jauge éteinte.
## Appui refusé faute d'eau : `warn` (la jauge clignote).
func resource_state() -> Dictionary:
	var txt := "À SEC" if dry_left > 0.0 else str(floori(water))
	return KitResource.make(&"water", "Eau", water_ratio(), ACCENT,
		{"text": txt, "mark": CRUE_MIN / WATER_MAX, "marks": [STUMBLE_WATER / WATER_MAX],
		"blocked": dry_left > 0.0, "warn": _warn_left > 0.0,
		"regen": _regen_rate})


## Sauvegarde de run : l'eau est conservée entre étages, donc aussi à la reprise.
func save_state() -> Dictionary:
	return {"water": water, "dry": dry_left}


func load_state(d: Dictionary) -> void:
	if d.has("water"):
		water = clampf(float(d["water"]), 0.0, WATER_MAX)
		dry_left = clampf(float(d.get("dry", 0.0)), 0.0, DRY_LOCK_S)
		_update_emission()


func add_water(amount: float) -> void:
	var w := clampf(water + amount, 0.0, WATER_MAX)
	if w != water:
		water = w
		_update_emission()


## Gain d'eau (pluie, gouttes, kills, flaque, eau de carte) : nul « à sec » ; nourrit le budget de l'auto-cast,
## le taux mesuré (resource_regen_per_s) et, hors pluie (`popup`), les « +N » flottants.
func gain_water(amount: float, popup := true) -> void:
	if amount <= 0.0 or dry_left > 0.0:
		return
	var before := water
	add_water(amount)
	var got := water - before
	_auto_budget = minf(_auto_budget + got * AUTO_SPEND_SHARE, AUTO_BUDGET_MAX)
	_regen_acc += amount # taux brut (même amphore pleine : le joueur voit ce que son jeu rapporte)
	if popup:
		_popup_acc += amount


## Hook générique (contrat KitResource) : gain de ressource par seconde, mesuré sur REGEN_WINDOW_S et lissé
## (pluie + gouttes + kills + flaque + eau de carte ; 0 à sec). Affiché par le HUD.
func resource_regen_per_s() -> float:
	return _regen_rate


## Coût en eau d'un sort (2-3 : × objets de recharge, plancher COST_FLOOR ; 4 : seuil de la Crue).
func cost_of(slot: int) -> float:
	match slot:
		2: return WAVE_COST * _cost_mult()
		3: return PUDDLE_COST * _cost_mult()
		4: return CRUE_MIN
	return 0.0


func _cost_mult() -> float:
	var m: float = player.stat(&"cooldown_mult") if player != null and player.has_method(&"stat") else 1.0
	return clampf(m, COST_FLOOR, 1.0) if m > 0.0 else 1.0


## Hook générique SpellCaster / HUD : assez d'eau pour ce slot (bouton grisé « pas assez d'eau » sinon).
func slot_affordable(slot: int) -> bool:
	return slot < 2 or water >= cost_of(slot)


## Hook générique SpellCaster / HUD : coût affiché (bulle de description) et message de manque (bouton).
func slot_cost_info(slot: int) -> Dictionary:
	match slot:
		2, 3: return {"cost": "%d d'eau" % roundi(cost_of(slot)), "lack": "pas assez d'eau"}
		4: return {"cost": "toute l'eau (min %d)" % roundi(CRUE_MIN), "lack": "pas assez d'eau"}
	return {}


## Pluie de la carte : rain_intensity du profil d'ambiance -> multiplicateur 0,5-1,5 ; sec = 0.
func rain_mult() -> float:
	return _rain_mult


func _poll_rain() -> void:
	if player == null or not player.is_inside_tree():
		return
	var am := AmbianceManager.find(player.get_tree())
	if am == null:
		_rain_mult = RAIN_FALLBACK_MULT
		return
	var r := float(am.current_params().get(&"rain_intensity", 0.0))
	_rain_mult = 0.0 if r < RAIN_DRY_BELOW else clampf(RAIN_MULT_MIN + r, RAIN_MULT_MIN, RAIN_MULT_MAX)


## Case d'eau (« , » peu profonde, « ~ » profonde) de la grille de la carte sous `pos`.
func is_map_water(pos: Vector2) -> bool:
	if player == null or not player.is_inside_tree():
		return false
	var am := AmbianceManager.find(player.get_tree())
	var map: Node2D = am.map if am != null else null
	if map == null or not is_instance_valid(map):
		return false
	var key := map.get_instance_id()
	if not _grid_cache.has(key):
		_grid_cache[key] = AmbianceWater.grid_of(map)
	var g: Dictionary = _grid_cache[key]
	if g.is_empty():
		return false
	var mp: Vector2 = (map.global_transform * StageMap.frame_of(map)).affine_inverse() * pos
	var c: Vector2 = ((mp - (g["origin"] as Vector2)) / float(g["cell_px"])).floor()
	var grid: PackedStringArray = g["grid"]
	if c.y < 0 or int(c.y) >= grid.size():
		return false
	var row := grid[int(c.y)]
	if c.x < 0 or int(c.x) >= row.length():
		return false
	var ch := row[int(c.x)]
	return ch == "," or ch == "~"


func _player_in_rivulet() -> bool:
	for r in rivulets:
		if is_instance_valid(r) and r.contains(player.global_position):
			return true
	return false


func _player_in_puddle() -> bool:
	for z in puddles:
		if is_instance_valid(z) and player.global_position.distance_to(z.global_position) <= float(z.radius):
			return true
	return false


func _on_enemy_killed(_e: Node2D, _pos: Vector2, _tier: int, _elite: bool) -> void:
	if player != null and not player.dead:
		gain_water(KILL_GAIN)


## Niveau d'eau lisible : la fenêtre de verre de l'amphore (masque `_e`) brille selon le remplissage.
func _update_emission() -> void:
	if _visual == null:
		return
	var step := roundi(water_ratio() * EMISSION_STEPS)
	if step == _emission_step:
		return
	_emission_step = step
	NormalMaps.set_emission_energy(_visual, lerpf(EMISSION_EMPTY, EMISSION_FULL, float(step) / EMISSION_STEPS))


# --- Hooks du joueur et de SpellCaster ----------------------------------------------------------

## Sorts 2-4 bloqués faute d'eau ou pendant le verrou anti-spam (effet précédent pas encore parti). Sort 1 gratuit.
func blocks_slot(slot: int) -> bool:
	if slot < 2:
		return false
	return not slot_affordable(slot) or is_cast_locked()


## Verrou anti-spam : CAST_LOCK_S après un sort 2-4, prolongé tant que son effet attend la frame d'impact.
func is_cast_locked() -> bool:
	if _lock_left > 0.0:
		return true
	for p in _pending:
		if p["base"] != &"attack":
			return true
	return false


## Glissade : il faut l'eau du départ (sinon bouton grisé) ; à sec, rien ne part.
func can_dodge() -> bool:
	return sliding or (water >= SLIDE_START_COST and dry_left <= 0.0)


# --- Glissade (hooks SlideDodge) ---------------------------------------------------------------------

func make_dodge() -> DodgeMove:
	return SlideDodge.new()


func dodge_label() -> String:
	return "Glissade"


func dodge_sound() -> Array:
	return SLIDE_SOUND


func slide_speed_u() -> float:
	return SLIDE_SPEED_U


func slide_can_start() -> bool:
	return can_dodge()


## Départ : la gerbe coûte SLIDE_START_COST d'eau ; eau versée sous ses pieds (VFX), trace commencée.
func slide_begin() -> bool:
	if water < SLIDE_START_COST or dry_left > 0.0:
		return false
	add_water(-SLIDE_START_COST)
	sliding = true
	_spawn_splash(player.global_position)
	_start_wake()
	_wake_pts = PackedVector2Array([player.global_position])
	_wake_left = 0.0
	return true


## Drain par image ; sur l'eau (carte, Flaque, Gouttière) l'eau porte : drain ÷2. Faux = réservoir vide : la
## glisse s'arrête.
func slide_drain(delta: float) -> bool:
	var mult := SLIDE_WATER_DRAIN_MULT if (in_map_water or in_puddle or in_rivulet) else 1.0
	add_water(-SLIDE_DRAIN_PER_S * mult * delta)
	return water > 0.0


## Fin (relâcher, vide, mur de face) : amphore ≥ 80 = elle freine mal (anim stumble, ×0,6).
func slide_end(_by_wall: bool) -> void:
	sliding = false
	if water >= STUMBLE_WATER:
		stumble_left = STUMBLE_RECOVER_S
	if player != null:
		Audio.play(SLIDE_STOP_SOUND[0], player.global_position, SLIDE_STOP_SOUND[1], SLIDE_STOP_SOUND[2])
	_wake_left = SLIDE_WAKE_FADE_S # la trace s'efface en 1 s : elle trempe encore jusque-là
	_end_wake()


## Trace d'eau au sol : un point par pas de glisse (Line2D qui s'efface après l'arrêt).
func slide_trail(_from: Vector2, to: Vector2) -> void:
	if _wake == null or not is_instance_valid(_wake):
		return
	var n := _wake.get_point_count()
	if n > 0 and _wake.get_point_position(n - 1).distance_to(to) < SLIDE_WAKE_MIN_STEP_PX:
		return
	_wake.add_point(to)
	if _wake.get_point_count() > SLIDE_WAKE_MAX_POINTS:
		_wake.remove_point(0)
	_wake_pts = _wake.points # polyligne sondée par AV-4 (monde : la Line2D est à l'origine)


## En glisse, elle passe à travers la mêlée : le coup d'un monstre à portée de contact est ignoré (boss compris) ;
## projectiles, zones et ondes touchent. Règle de Rainette en l'air.
func ignores_hit(source: Node) -> bool:
	if not sliding or source == null or not is_instance_valid(source) or not (source is Node2D):
		return false
	var r: float = float(source.get(&"radius_px")) if &"radius_px" in source else 20.0
	var reach: float = r + player.hit_radius_px() + SLIDE_CONTACT_MARGIN_U * Balance.UNIT_PX
	return (source as Node2D).global_position.distance_to(player.global_position) <= reach


func _start_wake() -> void:
	_end_wake()
	if player == null or player.get_parent() == null:
		return
	var l := Line2D.new()
	l.width = SLIDE_WAKE_WIDTH_U * Balance.UNIT_PX
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.z_index = -1 # au ras du sol, sous les sprites
	if ResourceLoader.exists(SLIDE_WAKE_TEX):
		l.texture = load(SLIDE_WAKE_TEX)
		l.texture_mode = Line2D.LINE_TEXTURE_TILE
		var tint := Color(ACCENT.r * SLIDE_WAKE_GLOW, ACCENT.g * SLIDE_WAKE_GLOW, ACCENT.b * SLIDE_WAKE_GLOW, SLIDE_WAKE_ALPHA)
		var g := Gradient.new()
		g.set_offset(0, 0.0)
		g.set_color(0, Color(tint, 0.0)) # queue : s'évapore
		g.set_offset(1, 0.45)
		g.set_color(1, tint)
		l.gradient = g
		l.material = _additive()
	else:
		l.default_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35) # PLACEHOLDER (lot Codex dodge_slide)
	player.get_parent().add_child(l)
	l.global_position = Vector2.ZERO
	l.add_point(player.global_position)
	_wake = l


static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _end_wake() -> void:
	if _wake == null or not is_instance_valid(_wake):
		_wake = null
		return
	var l := _wake
	_wake = null
	var tw := l.create_tween()
	tw.tween_property(l, ^"modulate:a", 0.0, SLIDE_WAKE_FADE_S)
	tw.tween_callback(l.queue_free)


## Eau versée sous ses pieds au départ : anim `splash` du lot Codex, sinon sa Flaque-miroir en petit, qui s'efface.
func _spawn_splash(at: Vector2) -> void:
	if player == null or player.get_parent() == null:
		return
	var path := SLIDE_SPLASH_FRAMES if ResourceLoader.exists(SLIDE_SPLASH_FRAMES) else SLIDE_SPLASH_FALLBACK
	if not ResourceLoader.exists(path):
		return
	var sf := load(path) as SpriteFrames
	if sf == null:
		return
	var anim: StringName = &"splash" if sf.has_animation(&"splash") else StringName(sf.get_animation_names()[0])
	var fx := AnimatedSprite2D.new()
	fx.scale = Vector2.ONE * SLIDE_SPLASH_SCALE
	fx.z_index = -1
	fx.material = _additive()
	player.get_parent().add_child(fx)
	fx.global_position = at
	EmissiveOverlay.apply(fx, sf)
	fx.play(anim)
	var tw := fx.create_tween()
	tw.tween_property(fx, ^"modulate:a", 0.0, SLIDE_SPLASH_FADE_S)
	tw.tween_callback(fx.queue_free)


## Auto-cast (SpellCaster._auto_cast_ok, option d'accessibilité et simulateur ; jamais en manuel) :
## Vague / Flaque seulement sur le budget (AUTO_SPEND_SHARE de l'eau gagnée), une Flaque à la fois ; Crue à
## AUTO_CRUE_AT, ou dès CRUE_MIN face à une foule ou à PV bas.
func auto_cast_ok(slot: int) -> bool:
	match slot:
		2, 3:
			if slot == 3 and _live_slot3() > 0:
				return false
			return _auto_budget >= cost_of(slot) and water - cost_of(slot) >= DRY_BELOW
		4:
			if water >= AUTO_CRUE_AT:
				return true
			if water < CRUE_MIN or player == null:
				return false
			if player.max_hp > 0.0 and player.hp / player.max_hp <= AUTO_CRUE_LOW_HP:
				return true
			return _count_in_radius(player.global_position, crue_radius_u(water) * Balance.UNIT_PX) >= AUTO_CRUE_CROWD
	return true


func _count_in_radius(at: Vector2, r: float) -> int:
	var n := 0
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and (e as Node2D).global_position.distance_to(at) <= r:
			n += 1
	return n


## Flaques (ou Gouttières, si le slot 3 en est une) vivantes : une seule à la fois en auto.
func _live_slot3() -> int:
	if _slot3_is_rivulet():
		var k := 0
		for r in rivulets:
			if is_instance_valid(r) and not r.is_ending():
				k += 1
		return k
	return _live_puddles()


func _slot3_is_rivulet() -> bool:
	var sp := _spell_of(3)
	return sp != null and sp.id == V_GOUTTIERE


func _live_puddles() -> int:
	var n := 0
	for z in puddles:
		if is_instance_valid(z) and not z.is_ending():
			n += 1
	return n


## Hook SpellCaster.deal_damage : chaque Goutte-lame qui touche rend de l'eau (plus sur une élite ou un boss).
func on_spell_hit(s: SpellData, enemy: Node, _amount: float) -> void:
	if s.slot != 1 or not is_instance_valid(enemy):
		return
	var big: bool = enemy.get(&"is_elite") == true or enemy.is_in_group(&"bosses")
	var wet := is_soaked(enemy) # AV-3 : la Goutte sur un trempé rend plus d'eau
	var volley: Variant = s.get_meta(&"volley", null) if s.has_meta(&"volley") else null
	if volley is Dictionary: # Bruine : plafond d'eau par salve, bonus élite / boss une fois par salve
		var v := volley as Dictionary
		if big and not bool(v["big"]):
			v["big"] = true
			gain_water(BIG_HIT_WATER)
		else:
			var cap := BRUINE_SOAK_VOLLEY_CAP if wet else BRUINE_VOLLEY_WATER_CAP
			var g := minf(HIT_WATER + (BRUINE_SOAK_WATER if wet else 0.0), cap - float(v["gain"]))
			if g > 0.0:
				v["gain"] = float(v["gain"]) + g
				gain_water(g)
		return
	gain_water((BIG_HIT_WATER if big else HIT_WATER) + (SOAK_HIT_WATER if wet else 0.0))


## 4,4 u/s à vide -> 3,4 u/s pleine (linéaire, avant les items) ; ×0,6 en se relevant d'un trébuchement.
func speed_mult() -> float:
	var m := lerpf(1.0, SPEED_FULL_U / SPEED_EMPTY_U, water_ratio())
	if in_rivulet:
		m *= GOUTTIERE_SPEED_MULT # le courant de la Gouttière porte Averse, même amphore pleine
	if stumble_left > 0.0 and not player.is_dodging():
		m *= STUMBLE_SPEED_MULT
	return m


func inertia_s() -> float:
	return 0.0


func slow_immune() -> bool:
	return false


func locks_facing() -> bool:
	return false


## Pas de fantômes de sprite : la glisse se lit par la trace d'eau.
func dodge_ghosts() -> bool:
	return false


func on_dodge_start(_dir: Vector2) -> void:
	stumble_left = 0.0


func on_cast(_s: SpellData) -> void:
	pass


func action_for(s: SpellData) -> StringName:
	match s.slot:
		1: return &"attack"
		2: return &"wave"
		3: return &"cast"
		4: return &"crue"
	return &""


## Lancement (SpellCaster, Behavior.KIT) : l'eau est payée tout de suite, l'effet part à la frame d'impact.
func cast_spell(s: SpellData, aim: Variant) -> bool:
	if player == null or player.dead or blocks_slot(s.slot):
		return false
	var origin := player.global_position
	match s.slot:
		1:
			if s.id == V_BRUINE:
				return _cast_bruine(s)
			var c := _caster()
			var target := c.nearest_enemy(c.range_px(s))
			if target == null:
				return false # l'auto ne consomme rien sans cible
			var shot := s.duplicate() as SpellData # coef figé au tir (l'eau peut changer avant l'impact)
			shot.coef = GOUTTE_COEF_MIN + GOUTTE_COEF_WATER * water_ratio()
			var dir := (target.global_position - origin).normalized()
			if dir != Vector2.ZERO:
				player.facing = dir
			_queue(&"attack", func() -> void: c.fire_at(shot, target, dir))
		2:
			if s.id == V_GEYSER:
				var gat := _aim_point(aim, s, origin)
				_face(gat)
				_pay(cost_of(2))
				_queue(&"wave", func() -> void: _geyser(s, gat))
				return true
			var dir := _aim_dir(aim, s)
			player.facing = dir
			_pay(cost_of(2))
			_queue(&"wave", func() -> void: _wave(s, dir))
		3:
			if s.id == V_GOUTTIERE:
				var rdir := _aim_dir(aim, s)
				player.facing = rdir
				_pay(cost_of(3))
				_queue(&"cast", func() -> void: spawn_rivulet(s, player.global_position, rdir))
				return true
			var at := origin
			if aim != null:
				at = origin + ((aim as Vector2) - origin).limit_length(_caster().range_px(s))
			else:
				var t := _caster().nearest_enemy(_caster().range_px(s))
				if t != null:
					at = t.global_position
			_pay(cost_of(3))
			_queue(&"cast", func() -> void: spawn_puddle(s, at))
		4:
			var spent := water
			add_water(-spent)
			_lock_left = CAST_LOCK_S
			if s.id == V_MOUSSON:
				_queue(&"crue", func() -> void: _mousson(s, spent))
			else:
				_queue(&"crue", func() -> void: _crue(s, spent))
		_:
			return false
	return true


## Paie une Vague / Flaque : verrou anti-spam, budget de l'auto-cast ; amphore vidée (< DRY_BELOW) = à sec.
func _pay(cost: float) -> void:
	add_water(-cost)
	_lock_left = CAST_LOCK_S
	_auto_budget = maxf(_auto_budget - cost, 0.0)
	if water < DRY_BELOW:
		dry_left = DRY_LOCK_S


## Visée d'un sort orienté : point visé (souris, stick, paquet le plus dense), sinon ennemi le plus proche, sinon l'avant.
func _aim_dir(aim: Variant, s: SpellData) -> Vector2:
	var o := player.global_position
	var d := Vector2.ZERO
	if aim != null:
		d = (aim as Vector2) - o
	if d.length_squared() < 1.0:
		var t := _caster().nearest_enemy(_caster().range_px(s))
		if t != null:
			d = t.global_position - o
	if d.length_squared() < 1.0:
		d = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
	return d.normalized()


## Point visé d'un sort posé : visée (souris, stick, paquet le plus dense) limitée à la portée, sinon le monstre le
## plus proche à portée, sinon deux unités devant Averse.
func _aim_point(aim: Variant, s: SpellData, origin: Vector2) -> Vector2:
	var reach := _caster().range_px(s)
	if aim != null:
		return origin + ((aim as Vector2) - origin).limit_length(reach)
	var t := _caster().nearest_enemy(reach)
	if t != null:
		return t.global_position
	var f: Vector2 = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
	return origin + f.normalized() * 2.0 * Balance.UNIT_PX


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


## Effets en attente (tests) ; flush_pending les déclenche tout de suite.
func has_pending() -> bool:
	return not _pending.is_empty()


func flush_pending() -> void:
	var all := _pending
	_pending = []
	for p in all:
		(p["fn"] as Callable).call()


# --- Effets --------------------------------------------------------------------------------------

## Trempé : ralenti 30 % pendant 4 s (clé `slow`, rafraîchi). Les boss aussi (leur propre plancher).
## Une trempe plus courte (sillage 2 s) n'écourte jamais une trempe en cours (Vague de fond 8 s).
func _soak(e: Node, duration := SOAK_S, pct := SOAK_PCT) -> void:
	if is_instance_valid(e) and e.has_method(&"apply_status"):
		var id := e.get_instance_id() # compteur de déblocage : une nouvelle trempe, pas un rafraîchissement
		var until := float(_soaked_until.get(id, -1.0))
		var fresh := _kit_clock >= until
		if fresh:
			RunState.add_counter(COUNTER_SOAKED)
		var end := _kit_clock + duration
		if fresh or end >= until:
			e.apply_status(&"slow", {"pct": pct, "duration": duration})
			_soaked_until[id] = end


## Trempé (état lu par les combos AV-1 à AV-3 et l'aide de visée) ; la fin de trempe est suivie par l'horloge du kit.
func is_soaked(e: Node) -> bool:
	return e != null and is_instance_valid(e) and float(_soaked_until.get(e.get_instance_id(), -1.0)) > _kit_clock


## Aide de visée mobile (SpellCaster.densest_point) : les trempés pèsent plus.
func is_marked(e: Node) -> bool:
	return is_soaked(e)


## SpellCaster.compute_damage : coef additif. Goutte-lame sur trempé (AV-3), Vague de fond (AV-2).
func combo_coef_add(s: SpellData, enemy: Node) -> float:
	if s.slot == 1 and s.id != V_BRUINE and is_soaked(enemy):
		return SOAK_GOUTTE_ADD
	if s.slot == 2 and _wave_deep:
		return WAVE_PUDDLE_ADD
	return 0.0


## SpellCaster.compute_damage : multiplicateur. Crue / Mousson sur trempé (AV-1).
func combo_mult(s: SpellData, enemy: Node) -> float:
	if s.slot == 4 and is_soaked(enemy):
		return CRUE_SOAK_MULT
	return 1.0


## SpellCaster.deal_damage : chiffre d'accent (Crue sur trempé, Vague de fond).
func combo_hit(s: SpellData, enemy: Node) -> bool:
	if s.slot == 4:
		return is_soaked(enemy)
	return s.slot == 2 and _wave_deep


## Fenêtre de combo (HUD, boutons qui pulsent), sondée au plus toutes les COMBO_READY_POLL_S : Crue = au moins
## COMBO_READY_MIN trempés dans son rayon (ou un boss trempé) ; Vague = une Flaque vivante autour d'Averse.
func combo_ready(slot: int) -> bool:
	if player == null or not is_inside_tree():
		return false
	if _kit_clock - _ready_t >= COMBO_READY_POLL_S:
		_probe_ready()
	return bool(_ready.get(slot, false))


func invalidate_combo_cache() -> void:
	_ready_t = -10.0


func _probe_ready() -> void:
	_ready_t = _kit_clock
	_ready[2] = false
	_ready[4] = false
	var here := player.global_position
	var wave_r := WAVE_LENGTH_U * Balance.UNIT_PX
	for z in puddles:
		if is_instance_valid(z) and not z.is_ending() and z.global_position.distance_to(here) <= wave_r + float(z.radius):
			_ready[2] = true
			break
	if _soaked_until.is_empty():
		return
	var r := crue_radius_u(water) * Balance.UNIT_PX
	var n := 0
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_soaked(e) or (e as Node2D).global_position.distance_to(here) > r:
			continue
		n += 1
		if e.get(&"is_boss") == true or n >= COMBO_READY_MIN:
			_ready[4] = true
			break


## Recul imposé au-delà du plafond des coups directs (KB_MAX_U) : poussée complémentaire × masse.
func _shove(e: Node, from: Vector2, knock_u: float) -> void:
	if not (e is Enemy) or not is_instance_valid(e) or e.is_boss:
		return
	var away: Vector2 = (e as Node2D).global_position - from
	if away.length_squared() < 1.0:
		return
	var mass := Balance.knockback_mass(e.tier, e.is_elite)
	var extra := maxf(knock_u - Balance.KB_MAX_U, 0.0) * mass * Balance.UNIT_PX
	e.push(away.normalized() * extra)


func _enemies_in_cone(origin: Vector2, dir: Vector2, r: float, half: float) -> Array:
	var out: Array = []
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		var v: Vector2 = e.global_position - origin
		if v.length() > r:
			continue
		if v.length_squared() > 1.0 and absf(dir.angle_to(v)) > half:
			continue
		out.append(e)
	return out


## Une Flaque vivante dont le centre est dans le cône, ou dont le disque contient Averse (Vague lancée depuis elle).
## Elle n'est pas consommée ; elle pulse.
func _puddle_in_cone(origin: Vector2, dir: Vector2, r: float, half: float) -> bool:
	var found := false
	for z in puddles:
		if not is_instance_valid(z) or z.is_ending():
			continue
		var v: Vector2 = z.global_position - origin
		var inside: bool = v.length() <= float(z.radius)
		if not inside and v.length() <= r and (v.length_squared() < 1.0 or absf(dir.angle_to(v)) <= half):
			inside = true
		if inside:
			found = true
			_pulse_puddle(z)
	return found


func _pulse_puddle(z: Node) -> void:
	var v: Variant = z.get(&"vfx")
	if not (v is Node2D) or not is_instance_valid(v):
		return
	var n := v as Node2D
	var base := n.scale
	var tw := n.create_tween()
	tw.tween_property(n, ^"scale", base * WAVE_PUDDLE_PULSE, WAVE_PUDDLE_PULSE_S * 0.4)
	tw.tween_property(n, ^"scale", base, WAVE_PUDDLE_PULSE_S * 0.6)


func wave_radius_px(s: SpellData) -> float:
	return s.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))


## Vague : cône devant elle, coup direct (recul), trempe, poussée jusqu'à 1,5 u × masse.
func _wave(s: SpellData, dir: Vector2) -> void:
	var origin := player.global_position
	var r := wave_radius_px(s)
	var half := deg_to_rad(s.spread_deg) * 0.5
	var deep := _puddle_in_cone(origin, dir, r, half) # AV-2 : Vague de fond
	_wave_deep = deep
	for e in _enemies_in_cone(origin, dir, r, half):
		_caster().deal_damage(e, s, {"source_pos": origin, "anim": true})
		if deep:
			_soak(e, WAVE_PUDDLE_SOAK_S, WAVE_PUDDLE_SOAK_PCT)
		else:
			_soak(e)
		_shove(e, origin, WAVE_KNOCK_U)
	_wave_deep = false
	_spawn_wave_vfx(origin, dir, r / (WAVE_VFX_LENGTH_U * Balance.UNIT_PX))
	LightRig.flash(origin + dir * r * 0.5, s.light_preset, 0.45)


## Cône rendu (rig CREA, 8 directions) : posé aux pieds d'Averse, à l'échelle du personnage.
func _spawn_wave_vfx(origin: Vector2, dir: Vector2, k: float) -> AnimatedSprite2D:
	if not ResourceLoader.exists(WAVE_FRAMES):
		return null
	var sf := load(WAVE_FRAMES) as SpriteFrames
	var anim := StringName("wave_cone_" + _dir_of(dir))
	if sf == null or not sf.has_animation(anim):
		return null
	var spr := AnimatedSprite2D.new()
	spr.name = "WaveCone"
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var parent: Node = _caster().effects_parent() if _caster() != null else player.get_parent()
	parent.add_child(spr)
	EmissiveOverlay.apply(spr, sf, WAVE_EMISSION)
	spr.global_position = origin
	spr.scale = WAVE_SPRITE_SCALE * k
	sf.set_animation_loop(anim, false)
	spr.play(anim)
	spr.animation_finished.connect(spr.queue_free)
	return spr


## Flaque-miroir : ZoneEffect persistante (DoT, VFX, lumière) ; trempe et regain d'eau gérés par le kit.
func spawn_puddle(s: SpellData, at: Vector2) -> Node2D:
	var live: Array = []
	for p in puddles:
		if is_instance_valid(p) and not p.is_ending():
			live.append(p)
	while live.size() >= PUDDLE_MAX: # la plus ancienne s'assèche
		var old: Node = live.pop_front()
		puddles.erase(old)
		old.queue_free()
	var z := _caster().spawn_zone(s, at)
	_tint_vfx(z, PUDDLE_VFX_TINT)
	puddles.append(z)
	z.tree_exiting.connect(func() -> void: puddles.erase(z))
	return z


## Teinte (rgb) du VFX d'une ZoneEffect ; ZoneEffect ne pilote que l'alpha (fondus).
func _tint_vfx(z: Node, tint: Color) -> void:
	var v: Variant = z.get(&"vfx") if z != null else null
	if v is CanvasItem:
		var ci := v as CanvasItem
		ci.modulate = Color(tint.r, tint.g, tint.b, ci.modulate.a)


# --- Variantes : effets ----------------------------------------------------------------------------

## Bruine : 3 gouttes en éventail vers le monstre le plus proche (coef figé au tir) ; l'eau rendue est plafonnée par
## salve (méta `volley` partagée par les 3 gouttes, lue par on_spell_hit).
func _cast_bruine(s: SpellData) -> bool:
	var c := _caster()
	var target := c.nearest_enemy(c.range_px(s))
	if target == null:
		return false # l'auto ne consomme rien sans cible
	var shot := s.duplicate() as SpellData
	shot.coef = BRUINE_COEF_MIN + BRUINE_COEF_WATER * water_ratio()
	shot.set_meta(&"volley", {"gain": 0.0, "big": false})
	var dir := (target.global_position - player.global_position).normalized()
	if dir != Vector2.ZERO:
		player.facing = dir
	var n := maxi(s.count, 1)
	var half := deg_to_rad(s.spread_deg) * 0.5
	_queue(&"attack", func() -> void:
		for i in n:
			var a := 0.0 if n == 1 else lerpf(-half, half, float(i) / float(n - 1))
			c.fire_at(shot, null, dir.rotated(a)))
	return true


func geyser_radius_px(s: SpellData) -> float:
	return s.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))


## Geyser : télégraphe GEYSER_TELEGRAPH_S au point visé, puis jaillissement.
func _geyser(s: SpellData, at: Vector2) -> void:
	var r := geyser_radius_px(s)
	var fx := AverseGeyserFx.new()
	_caster().effects_parent().add_child(fx)
	fx.setup(at, r, GEYSER_TELEGRAPH_S, ACCENT, GEYSER_FRAMES, GEYSER_RADIUS_PX)
	_delayed.append({"t": GEYSER_TELEGRAPH_S, "fn": func() -> void: _geyser_burst(s, at, r, fx)})


## Jaillissement : coup direct (aucun recul : pas de source_pos), trempe ; les monstres (hors boss) sont projetés en
## l'air GEYSER_LIFT_S (statut `imprisoned` + élévation du Visual et ombre de contact).
func _geyser_burst(s: SpellData, at: Vector2, r: float, fx: Node) -> void:
	if player == null or player.dead:
		return
	if is_instance_valid(fx):
		fx.burst()
	var on_puddle := false # AV-2 : Geyser posé sur une Flaque, trempe longue
	for z in puddles:
		if is_instance_valid(z) and not z.is_ending() and z.global_position.distance_to(at) <= float(z.radius):
			on_puddle = true
			break
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		if e.global_position.distance_to(at) > r:
			continue
		_caster().deal_damage(e, s, {"anim": true})
		if on_puddle:
			_soak(e, WAVE_PUDDLE_SOAK_S, WAVE_PUDDLE_SOAK_PCT)
		else:
			_soak(e)
		if e.get(&"is_boss") == true or not e.has_method(&"apply_status"):
			continue
		e.apply_status(&"imprisoned", {"duration": GEYSER_LIFT_S})
		_lift(e)
	LightRig.flash(at, s.light_preset, 0.45)


func _lift(e: Node2D) -> void:
	for l in _lifted:
		if l["e"] == e:
			l["t"] = 0.0 # déjà en l'air : l'arc repart
			return
	var vis: Variant = e.get(&"visual")
	var y0 := (vis as Node2D).position.y if vis is Node2D else 0.0
	var shadow := _GeyserShadow.new()
	e.add_child(shadow)
	shadow.radius_px = float(e.get(&"radius_px")) if &"radius_px" in e else 18.0
	_lifted.append({"e": e, "t": 0.0, "y0": y0, "shadow": shadow})


## Hauteur (u) d'un monstre projeté à l'instant t de son arc (sinus : monte, redescend).
static func lift_height_u(t: float) -> float:
	return GEYSER_LIFT_U * sin(PI * clampf(t / GEYSER_LIFT_S, 0.0, 1.0))


func lifted_count() -> int:
	return _lifted.size()


func _tick_lifted(delta: float) -> void:
	for l in _lifted.duplicate():
		var e: Variant = l["e"]
		var alive: bool = is_instance_valid(e) and not (&"active" in e and not bool(e.get(&"active")))
		l["t"] = float(l["t"]) + delta
		var done: bool = float(l["t"]) >= GEYSER_LIFT_S or not alive
		if is_instance_valid(e):
			var vis: Variant = e.get(&"visual")
			if vis is Node2D:
				var h := 0.0 if done else lift_height_u(float(l["t"]))
				(vis as Node2D).position.y = float(l["y0"]) + Iso.lift_logical(h)
			var sh: Variant = l["shadow"]
			if is_instance_valid(sh):
				(sh as Node2D).scale = Vector2.ONE * (1.0 - 0.3 * lift_height_u(float(l["t"])) / GEYSER_LIFT_U)
				if done:
					(sh as Node).queue_free()
		if done:
			_lifted.erase(l)


func _release_lifted() -> void:
	for l in _lifted:
		var e: Variant = l["e"]
		if is_instance_valid(e):
			var vis: Variant = e.get(&"visual")
			if vis is Node2D:
				(vis as Node2D).position.y = float(l["y0"])
		if is_instance_valid(l["shadow"]):
			(l["shadow"] as Node).queue_free()
	_lifted.clear()


## Ombre de contact d'un monstre en l'air (placeholder dessiné : ellipse au sol).
class _GeyserShadow extends Node2D:
	var radius_px := 18.0

	func _ready() -> void:
		z_index = -1

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, radius_px, Color(0.0, 0.0, 0.0, 0.35))


## Gouttière : ruisseau posé depuis Averse vers `dir`. 2 au plus (la plus ancienne s'assèche).
func spawn_rivulet(s: SpellData, origin: Vector2, dir: Vector2) -> Node2D:
	var live: Array = []
	for r in rivulets:
		if is_instance_valid(r) and not r.is_ending():
			live.append(r)
	while live.size() >= GOUTTIERE_MAX:
		var old: Node = live.pop_front()
		rivulets.erase(old)
		old.queue_free()
	var k: float = 1.0 + player.stat(&"zone_size_add")
	var rv := AverseRivulet.new()
	_caster().effects_parent().add_child(rv)
	rv.setup(_caster(), s, origin, dir, GOUTTIERE_LENGTH_U * Balance.UNIT_PX * k, GOUTTIERE_WIDTH_U * Balance.UNIT_PX * k)
	rivulets.append(rv)
	rv.tree_exiting.connect(func() -> void: rivulets.erase(rv))
	return rv


## Mousson : zone attachée à Averse (suit chaque image), dégâts totaux = crue_coef(eau) x MOUSSON_TOTAL_MULT en
## MOUSSON_LIFE_S / MOUSSON_TICK_S ticks ; l'amphore se remplit pendant ce temps (tick()).
func _mousson(s: SpellData, spent: float) -> void:
	for m in monsoons.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	monsoons.clear()
	var zs := s.duplicate() as SpellData
	zs.behavior = SpellData.Behavior.GROUND_ZONE
	zs.coef = crue_coef(spent) * MOUSSON_TOTAL_MULT / (s.duration / maxf(s.tick, 0.05) + 1.0) # coup initial + un par tick
	if ResourceLoader.exists(MONSOON_FRAMES):
		zs.vfx_frames = MONSOON_FRAMES
		zs.vfx_radius_px = MONSOON_RADIUS_PX
		zs.vfx_floor_aspect = 1.0
		zs.vfx_additive = true
	var z := _caster().spawn_zone(zs, player.global_position)
	_tint_vfx(z, CRUE_VFX_TINT)
	monsoons.append(z)
	z.tree_exiting.connect(func() -> void: monsoons.erase(z))
	monsoon_left = s.duration
	LightRig.flash(player.global_position, s.light_preset, 0.6)


func crue_radius_u(w: float) -> float:
	return CRUE_RADIUS_U + CRUE_RADIUS_PER_WATER_U * w


static func crue_coef(w: float) -> float:
	return CRUE_COEF_FULL * pow(clampf(w, 0.0, WATER_MAX) / WATER_MAX, CRUE_COEF_EXP)


## Crue : onde centrée sur Averse, rayon et puissance selon l'eau vidée ; trempe, poussée 3 u × masse ;
## laisse une Flaque-miroir.
func _crue(s: SpellData, spent: float) -> void:
	if spent >= FULL_CRUE_WATER:
		RunState.add_counter(COUNTER_FULL_CRUES)
	var origin := player.global_position
	var wave := s.duplicate() as SpellData
	wave.behavior = SpellData.Behavior.NOVA
	wave.coef = crue_coef(spent)
	wave.radius_u = crue_radius_u(spent)
	var wet_before := {} # AV-1 : trempés avant la Crue (la zone frappe à sa création, avant la trempe de la Crue)
	if not _soaked_until.is_empty():
		for e in player.get_tree().get_nodes_in_group(&"enemies"):
			if is_soaked(e):
				wet_before[e.get_instance_id()] = true
	var z := _caster().spawn_zone(wave, origin) # dégâts radiaux (recul depuis le centre) à la création
	_tint_vfx(z, CRUE_VFX_TINT)
	var r: float = z.radius
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and e.global_position.distance_to(origin) <= r:
			var wet := wet_before.has(e.get_instance_id())
			_soak(e)
			_shove(e, origin, CRUE_SOAK_KNOCK_U if wet else CRUE_KNOCK_U)
	LightRig.flash(origin, s.light_preset, 0.9)
	var puddle := _puddle_spell()
	if puddle != null:
		spawn_puddle(puddle, origin)


## Flaque-miroir de base, même quand le slot 3 porte la Gouttière (la Crue laisse toujours une Flaque).
func _puddle_spell() -> SpellData:
	var sp := _spell_of(3)
	if sp != null and sp.id != V_GOUTTIERE:
		return sp
	if _base_puddle == null:
		_base_puddle = character().spells[2]
	return _base_puddle


func _spell_of(slot: int) -> SpellData:
	for sp in player.character.spells:
		if sp.slot == slot:
			return sp
	return null


# --- Boucle (Player.tick, avant les sorts) -------------------------------------------------------

func tick(delta: float) -> void:
	if player == null or player.dead:
		return
	_kit_clock += delta
	stumble_left = maxf(stumble_left - delta, 0.0)
	dry_left = maxf(dry_left - delta, 0.0)
	_lock_left = maxf(_lock_left - delta, 0.0)
	_warn_left = maxf(_warn_left - delta, 0.0)
	for sl in [2, 3, 4]: # appui refusé faute d'eau : la jauge (info centrale) clignote
		if not slot_affordable(sl) and Input.is_action_just_pressed("spell_%d" % sl):
			_warn_left = WARN_S
	_rain_t -= delta
	if _rain_t <= 0.0:
		_rain_t = RAIN_POLL_S
		_poll_rain()
		in_map_water = is_map_water(player.global_position)
	in_puddle = _player_in_puddle()
	in_rivulet = _player_in_rivulet()
	gain_water(RAIN_GAIN_PER_S * _rain_mult * delta, false)
	if in_map_water:
		gain_water(MAP_WATER_GAIN_PER_S * delta)
	if in_puddle or in_rivulet: # une seule source comptée (Flaque ou Gouttière)
		var before := water
		gain_water(PUDDLE_GAIN_PER_S * delta)
		if in_puddle and water > before:
			RunState.add_counter(COUNTER_PUDDLE_WATER, water - before) # déblocage de la Gouttière
	if monsoon_left > 0.0:
		monsoon_left = maxf(monsoon_left - delta, 0.0)
		gain_water(MOUSSON_WATER_PER_S * delta)
	for m in monsoons: # la Mousson suit Averse
		if is_instance_valid(m):
			m.global_position = player.global_position
	_tick_delayed(delta)
	_tick_lifted(delta)
	_tick_readout(delta)
	_tick_wake(delta)
	_soak_t -= delta
	if _soak_t <= 0.0 and not (puddles.is_empty() and rivulets.is_empty() and monsoons.is_empty()):
		_soak_t = PUDDLE_SOAK_POLL_S
		_soak_puddles()
	# filet de sécurité : un effet jamais déclenché (anim interrompue sans impact) part après 1 s
	for p in _pending.duplicate():
		p["t"] = float(p["t"]) + delta
		if float(p["t"]) > 1.0:
			_pending.erase(p)
			(p["fn"] as Callable).call()


## Taux d'eau mesuré + « +N » flottants (gains hors pluie cumulés sur POPUP_WINDOW_S).
func _tick_readout(delta: float) -> void:
	_regen_t += delta
	if _regen_t >= REGEN_WINDOW_S:
		_regen_rate = lerpf(_regen_rate, _regen_acc / _regen_t, REGEN_SMOOTH)
		_regen_acc = 0.0
		_regen_t = 0.0
	_popup_t += delta
	if _popup_t >= POPUP_WINDOW_S:
		_popup_t = 0.0
		if _popup_acc >= POPUP_MIN:
			AverseWaterText.pop(player, maxi(roundi(_popup_acc), 1), ACCENT)
			_popup_acc = 0.0


func _soak_puddles() -> void:
	var live: Array = [] # disques : Flaques et Mousson
	for z in puddles + monsoons:
		if is_instance_valid(z) and not z.is_ending():
			live.append(z)
	var strips: Array = []
	for r in rivulets:
		if is_instance_valid(r) and not r.is_ending():
			strips.append(r)
	if live.is_empty() and strips.is_empty():
		return
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		var wet := false
		for z in live:
			if e.global_position.distance_to(z.global_position) <= float(z.radius):
				wet = true
				break
		if not wet:
			for r in strips:
				if r.contains(e.global_position):
					wet = true
					break
		if wet:
			_soak(e)
	if _soaked_until.size() > 512: # purge des trempes finies
		for k in _soaked_until.keys():
			if float(_soaked_until[k]) <= _kit_clock:
				_soaked_until.erase(k)


## AV-4 : le sillage trempe (WAKE_SOAK_S / WAKE_SOAK_PCT, aucun dégât) les monstres qu'il traverse ou qui le traversent.
## Sondage toutes les WAKE_POLL_S sur la polyligne (<= SLIDE_WAKE_MAX_POINTS points), pas par image.
func _tick_wake(delta: float) -> void:
	if not sliding and _wake_left <= 0.0:
		return
	if not sliding:
		_wake_left -= delta
	_wake_t -= delta
	if _wake_t > 0.0 or _wake_pts.size() < 2:
		return
	_wake_t = WAKE_POLL_S
	var reach := SLIDE_WAKE_WIDTH_U * 0.5 * Balance.UNIT_PX
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"apply_status"):
			continue
		var rad: float = float(e.get(&"radius_px")) if &"radius_px" in e else 20.0
		if ArpenteuseKit.dist_to_polyline((e as Node2D).global_position, _wake_pts) <= reach + rad:
			_soak(e, WAKE_SOAK_S, WAKE_SOAK_PCT)


## Effets à retardement (télégraphe du Geyser) ; flush_delayed les déclenche tout de suite (tests).
func _tick_delayed(delta: float) -> void:
	for d in _delayed.duplicate():
		d["t"] = float(d["t"]) - delta
		if float(d["t"]) <= 0.0:
			_delayed.erase(d)
			if player != null and not player.dead:
				(d["fn"] as Callable).call()


func has_delayed() -> bool:
	return not _delayed.is_empty()


func flush_delayed() -> void:
	var all := _delayed
	_delayed = []
	for d in all:
		(d["fn"] as Callable).call()


# --- Nettoyage -----------------------------------------------------------------------------------

func clear_transients() -> void:
	_pending = []
	for z in puddles.duplicate():
		if is_instance_valid(z):
			z.queue_free()
	puddles.clear()
	for r in rivulets.duplicate():
		if is_instance_valid(r):
			r.queue_free()
	rivulets.clear()
	for m in monsoons.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	monsoons.clear()
	monsoon_left = 0.0
	in_rivulet = false
	_delayed.clear()
	_release_lifted()
	stumble_left = 0.0
	sliding = false
	_end_wake()
	_wake_pts = PackedVector2Array()
	_wake_left = 0.0
	_wave_deep = false
	_ready_t = -10.0
	_lock_left = 0.0
	_warn_left = 0.0


func _on_floor_started(_n: int) -> void:
	clear_transients() # l'eau de l'amphore est gardée d'un étage à l'autre
	_grid_cache.clear()
	_rain_t = 0.0


func _on_player_died() -> void:
	clear_transients()
	if _visual != null and _visual.sprite_frames != null:
		var anim := StringName("death_" + _dir_of(player.facing))
		if _visual.sprite_frames.has_animation(anim):
			_visual.sprite_frames.set_animation_loop(anim, false)
			_visual.play(anim)


# --- Rendu ----------------------------------------------------------------------------------------

func _dir_of(v: Vector2) -> String:
	if v == Vector2.ZERO:
		v = Vector2.DOWN
	var i := roundi(v.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES[(i + 8) % 8]


## Freinage (arrêt de glisse à amphore pleine, anim `stumble`) prioritaire ; sinon l'anim d'action ou idle/run.
func visual_anim(fallback: StringName) -> StringName:
	if stumble_left > 0.0 and _visual != null and _visual.sprite_frames != null:
		var a := StringName("stumble_" + _dir_of(player.facing))
		if _visual.sprite_frames.has_animation(a):
			return a
	return fallback



# --- Passif expliqué (infobulle du HUD ; contrat KitResource.passive) ------------------------------------

static func passive_info() -> Dictionary:
	var f := KitResource.fmt
	return KitResource.passive("Eau", &"eau",
		"L'amphore d'Averse est sa seule ressource : les sorts 2 à 4 n'ont pas de recharge, ils coûtent de l'eau.",
		"la pluie (%s par seconde, ×%s à ×%s selon la carte), chaque monstre tué (+%s), chaque goutte qui touche (+%s, +%s sur élite ou boss), sa Flaque-miroir (+%s par seconde)." % [
			f.call(RAIN_GAIN_PER_S), f.call(RAIN_MULT_MIN), f.call(RAIN_MULT_MAX), f.call(KILL_GAIN), f.call(HIT_WATER), f.call(BIG_HIT_WATER), f.call(PUDDLE_GAIN_PER_S)],
		"Vague %s, Flaque %s, Crue : toute l'eau (minimum %s). Sous %s d'eau, plus aucun gain pendant %s s." % [
			f.call(WAVE_COST), f.call(PUDDLE_COST), f.call(CRUE_MIN), f.call(DRY_BELOW), f.call(DRY_LOCK_S)],
		"plus l'amphore est pleine, plus Averse est lente (%s u/s à sec, %s u/s pleine) ; au-delà de %s elle trébuche à la roulade. La Goutte-lame gagne +%s de coef pour 100 d'eau." % [
			f.call(SPEED_EMPTY_U), f.call(SPEED_FULL_U), f.call(STUMBLE_WATER), f.call(GOUTTE_COEF_WATER)])
