class_name HudMetrics
extends RefCounted
## Table unique des tailles du HUD (docs/ux/Audit_HUD.md §4.1-4.2, lot B + L8 de l'audit accessibilité).
## Toutes les valeurs sont données à 1080 px de haut. Un texte final n'est jamais plus petit que
## FLOOR_PC (PC) / FLOOR_MOBILE (mobile), quelle que soit la taille de la fenêtre.
## Échelle de l'interface choisie par le joueur : user_scale() = GameSettings.hud_user_scale(). Le réglage
## « Taille de l'interface » (Réglages > Affichage, clé gameplay/ui_scale) affiche 80-150 % rapporté au PC :
## défaut 150 % sur mobile (= MOBILE_K, déjà dans les tables mobiles) et 100 % sur PC, donc user_scale() = 1,0
## au défaut de chaque plateforme (0,53 à 1,0 sur mobile, 0,8 à 1,5 sur PC).

const FLOOR_PC := 18 ## aucun texte de jeu sous 18 px sur PC
const FLOOR_MOBILE := 26 ## ni sous 26 px sur mobile
const MOBILE_K := 1.5 ## facteur mobile des barres et textes du HUD
const USER_SCALE_MIN := 0.5 ## 80 % sur mobile = 0,8 / MOBILE_K
const USER_SCALE_MAX := 1.5
const USER_SCALE_KEY := "ui_scale" ## section « gameplay » de GameSettings
const SECTION := "gameplay"

## Niveaux typographiques : [PC, mobile].
const T1_HP := [22, 32] ## PV « 228 / 228 »
const T1_COOLDOWN := [40, 52] ## chiffre de recharge
const T2_TIME := [34, 40] ## chrono
const T2_GOLD := [30, 38] ## or
const T2_BOSS := [26, 34] ## nom du boss
const T3_GAUGE := [18, 28] ## libellé / valeur de jauge
const T4_SMALL := [18, 26] ## nom du perso, régén, « AUTO », difficulté
const T5_BADGE := [18, 26] ## badges, invites de touches
const BADGE_LEVEL := [30, 40] ## numéro du médaillon de niveau (décoratif, > T2)
const PROMPT := [22, 30] ## invite d'interaction clavier / manette
const HELP := [32, 36] ## aide des commandes
const TOAST := [30, 38] ## « +N XP (or converti) »

## Contours (px) : T1/T2 = 4, T3/T4 = 3, T5 = 2.
const OUTLINE_T1 := 4
const OUTLINE_T3 := 3
const OUTLINE_T5 := 2

## Dimensions [PC, mobile] (barres de PV / XP : largeur, hauteur).
const HP_BAR := [Vector2(300, 28), Vector2(360, 36)]
const XP_BAR := [Vector2(300, 10), Vector2(360, 12)]
const BADGE_PX := [62.0, 80.0] ## médaillon de niveau
const PORTRAIT_PX := [72.0, 92.0]
const TOUCH_SPELL_PX := 150.0 ## boutons de sort tactiles (audit § 4.2) ; en arc paysage : 128 -> 150
const TOUCH_DODGE_PX := 184.0 ## roulade tactile
const AUTO_PX := [110.0, 72.0] ## indicateur du sort 1 (PC barre / mobile)
const BAR_SPELL_PX := 110.0 ## barre de sorts clavier-souris
const MINIMAP_PX := [380.0, 300.0] ## losange compact [PC, mobile]
const GOLD_ICON_PX := [48.0, 56.0]

## Plaque commune minimap + difficulté.
const PLATE_ALPHA := 0.55
const PLATE_PAD := 10.0

## Couleurs PV du joueur (identiques à OverheadBars.COL_HP / COL_HP_LOW) et régénération.
const COL_HP := Color("#52C45A")
const COL_HP_LOW := Color("#D9483A")
const COL_REGEN := Color("#E8E2D6")
const COL_XP := Color("#59CCFF")
const LOW_HP_FRAC := 0.25


static func is_mobile() -> bool:
	return Platform.is_mobile()


## Échelle de l'interface demandée par le joueur, bornée.
static func user_scale() -> float:
	return clampf(GameSettings.hud_user_scale(), USER_SCALE_MIN, USER_SCALE_MAX)


## Facteur de géométrie du HUD pour un viewport donné (ancien `ui_scale`), user_scale compris.
static func geometry_scale(viewport: Vector2) -> float:
	var s := clampf(minf(viewport.x, viewport.y) / 1080.0, 0.6, 1.0)
	return s * user_scale()


static func floor_px(mobile := is_mobile()) -> int:
	return FLOOR_MOBILE if mobile else FLOOR_PC


## Taille de police finale d'un niveau [pc, mobile] : choisie selon la plateforme, multipliée par `s`
## (échelle de géométrie), jamais sous le plancher.
static func font(level: Array, s := 1.0, mobile := is_mobile()) -> int:
	var base := float(level[1] if mobile else level[0])
	return maxi(roundi(base * s), floor_px(mobile))


## Valeur [pc, mobile] (Vector2 ou float) pour la plateforme courante.
static func pick(pair: Array, mobile := is_mobile()) -> Variant:
	return pair[1] if mobile else pair[0]
