extends Node
## Formules de docs/Maths_Scaling.md (v3, §14 Alignement RoR2 pour difficulté, director, monstres, boss, économie, niveau).
## Fonctions pures : aucun état. Tout chiffre d'équilibrage du jeu passe par ici.

const UNIT_PX := 64.0 # 1 u = taille du joueur

# Menu pause (docs/ux/Audit_Menus.md M15) : compte à rebours de reprise selon le danger autour du joueur.
const RESUME_COUNTDOWN_DANGER_S := 3.0 ## danger proche : monstre ou projectile ennemi à portée, ou boss actif
const RESUME_COUNTDOWN_CALM_S := 1.0 ## sinon
const RESUME_DANGER_MONSTER_U := 6.0 ## monstre vivant plus près que ça = danger
const RESUME_DANGER_PROJECTILE_U := 8.0 ## projectile ennemi actif plus près que ça = danger

# Réglage « Animation des coffres » (docs/ux/Audit_Choix.md §3.3, GameSettings.chest_reveal) : multiplicateurs de durée
# [défilement de rareté, défilement des items] par mode. Instantanée = résultat direct (seul le son de rareté reste).
const CHEST_REVEAL_MODES := [&"complete", &"short", &"instant"]
const CHEST_REVEAL_MULT := {&"complete": [1.0, 1.0], &"short": [0.5, 0.6], &"instant": [0.0, 0.0]}

# Difficulté (Alignement RoR2, docs/Maths_Scaling.md §14) : coeff = (1 + min × 0,0506 × diff × TIME_COMPRESSION) × 1,15^(étage-1).
## Remplacé : K_TEMPS 0,30 × mode, accélération « endless » dès l'étage 4 (×1,5 temps, 1,25/étage), modes 0,7/1/1,5.
const TIME_SLOPE := 0.0506 ## RoR2 : hausse du coeff par minute et par point de difficulté
const TIME_COMPRESSION := 1.5 ## étage Rainfall de 5 min ≈ étage RoR2 de 7,5 min
const K_STAGE := 1.15
const MODES := {&"facile": 1.0, &"moyen": 2.0, &"difficile": 3.0} ## Drizzle / Rainstorm / Monsoon
const RUBY_MODE_MULT := {&"facile": 0.8, &"moyen": 1.0, &"difficile": 1.3}

# Director
## Crédits/s = CREDIT_K × (1 + 0,4 coeff) × zone (RoR2 : (1 + 0,4 coeff) × multiplicateur du director).
## Remplacé : 4 + 2,5 D. Zone d'étage : téléporteur RoR2 (+2,0 aux deux directors à 0,75) = ×2,33.
const CREDIT_K := 0.894
const ZONE_SPAWN_MULT := {&"mini": 1.5, &"etage": 2.33}
const MAX_ENEMIES := 250
## Mise en route (retour joueur : trop de monstres d'entrée, le doc suppose ~5 kills/s dès 0 s).
## Les crédits et le plafond de monstres vivants montent avec le temps actif, plafond plein à RAMP_TIME_S.
const RAMP_TIME_S := 480.0 ## 2e retour joueur : encore trop de monstres à 300 s
const RAMP_CREDITS_MIN := 0.2
const RAMP_ALIVE_MIN := 8
## Principe Risk of Rain : la difficulté achète des monstres plus forts, pas une foule plus grande.
## Plafond de vivants 150 (au lieu de 250) et coût moyen visé 1 + 1,0 × (D - 1) (doc : 0,5) :
## à crédits égaux, moins de monstres mais plus de tiers 2-3 et d'élites.
const RAMP_ALIVE_MAX := 150
## Alignement RoR2 : pente 0,4 (rythme de kills décroissant, comme RoR2 où le coût moyen monte avec le coeff).
const DIRECTOR_MEAN_COST_SLOPE := 0.4
const TIER_COST := {1: 1.0, 2: 4.0, 3: 12.0}
const TIER_MIN_D := {1: 0.0, 2: 1.35, 3: 2.0} ## T2 vers 70 s au lieu de 40 s (retour joueur : mort avant 2 min)
const ELITE_COST_MULT := 6.0 ## RoR2 élites tier 1 : coût ×6 (remplace ×4)
## Vagues (principe Risk of Rain 2) : WAVE_STREAM_SHARE des crédits part en flux continu, le reste est
## mis de côté et lâché d'un coup (groupe du même côté hors écran) toutes les WAVE_INTERVAL_MIN_S à
## WAVE_INTERVAL_MAX_S (tirage RNG du Director). Redistribution : mêmes crédits au total qu'avant.
const WAVE_STREAM_SHARE := 0.35
const WAVE_INTERVAL_MIN_S := 20.0
const WAVE_INTERVAL_MAX_S := 35.0
const WAVE_RETRY_S := 3.0 ## vague reportée (crédits ou place insuffisants) : nouvel essai après ce délai
const WAVE_MIN_COUNT := 3 ## en dessous, la vague attend (sinon elle passe au tier 1)
const WAVE_MAX_COUNT := 50 ## au-delà, le reliquat de la vague repasse au flux continu
const WAVE_SAME_TYPE_CHANCE := 0.75 ## vague d'un seul type (tier + variante), sinon mélange
const WAVE_LEADER_BASE := 0.15 ## chance d'une élite en tête : base + 2 × elite_chance(D), plafonnée
const WAVE_LEADER_MAX := 0.6
const WAVE_SIDE_SPREAD := 0.45 ## part du bord d'écran occupée par la vague
const WAVE_ANNOUNCE_S := 1.5 ## flèche au bord de l'écran, côté de la vague

# Monstres : [PV base, dégâts base, vitesse base u/s] au niveau ambiant 1.
# Vitesses -20 % par rapport au doc (retour joueur : « ils courent un peu trop vite »).
# Alignement RoR2 : PV/dégâts de base calibrés (remplacent 20/6, 80/12, 300/30) ; la prime suit TIER_COST
# (clé « reward » et ELITE_REWARD remplacés : or et XP ∝ coût director, comme RoR2).
const TIER_STATS := {
	1: {"hp": 18.0, "dmg": 5.0, "speed": 2.0},
	2: {"hp": 80.0, "dmg": 10.0, "speed": 2.0},
	3: {"hp": 300.0, "dmg": 24.0, "speed": 1.6},
}
## Croissance RoR2 par niveau ambiant (niveau = 1 + (coeff - 1) / 0,33) : +30 % PV, +20 % dégâts.
const LEVEL_HP_GROWTH := 0.30
const LEVEL_DMG_GROWTH := 0.20
const ELITE_HP := 4.0 ## RoR2 élites tier 1 (remplace 3,5)
const ELITE_DMG := 2.0 ## (remplace 1,5)
## Prime des kills (RoR2 : or = 2 × coeff × coût × R, XP = coeff × coût × R ; R = 0,2 pour les directors
## continus). Calibré par simulation (docs/Maths_Scaling.md §14) : 0,235.
const REWARD_MULT := 0.235
const MAX_HIT_FRACTION := 0.25 # d'un monstre, en part des PV max du joueur
const MAX_HIT_FRACTION_BOSS := 0.40
## Comportements des monstres (docs/Comportements_Monstres.md, retour joueur « ils tirent en marchant ») :
## cycle anticipation -> action -> récupération, immobile pendant l'armement et la récupération.
const SHOOTER_WINDUP_S := 0.7 ## tir simple : armement (pose d'attaque, teinte, ligne de visée), Lemurian RoR2 0,6 s + marge mobile
const SHOOTER_AIM_LOCK := 0.75 ## part de l'armement où la visée suit le joueur ; ensuite verrouillée (éclat plus vif)
const SHOOTER_RECOVERY_S := 0.5 ## immobile après le tir (Lemurian : 0,5 s de récupération)
const SHOOTER_SALVO_WINDUP_S := 1.0 ## salve de 3 (sort) : règle de lisibilité des sorts >= 0,8 s
const SHOOTER_SALVO_RECOVERY_S := 0.8
const SHOOTER_INTERVAL_S := 2.5 ## d'un début d'armement au suivant (était 2,0 s en marchant)
const SHOOTER_INTERVAL_JITTER := 0.15 ## ± part tirée au hasard : désynchronise la horde
const SHOOTER_RANGE_U := 8.0 ## tir permis jusqu'à (ligne de vue), toujours à l'écran
const SHOOTER_KEEP_U := 5.5 ## distance préférée (avance au-delà)
const SHOOTER_RETREAT_U := 3.5 ## repli en deçà, plus lent que le joueur
const SHOOTER_RETREAT_SPEED := 0.45 ## part de la vitesse du tireur en repli (Spitter Brotato : 0,44 du joueur)
const SHOOTER_MAX_CHARGING := 3 ## jetons d'attaque (Doom 2016) : tireurs qui arment en même temps, toutes espèces
const SHOOTER_TOKEN_RETRY_S := 0.2 ## pas de jeton libre : nouvel essai après ce délai (en continuant à se placer)
const SHOOTER_AIM_LINE_U := 1.6 ## ligne de visée au sol pendant l'armement (longueur, largeur)
const SHOOTER_AIM_LINE_WIDTH_U := 0.22
const SHOOTER_SALVO_CONE_U := 2.2 ## cône annonçant la salve
const LEAPER_SHOT_WINDUP_S := 0.5 ## bondisseur : tir d'appoint, armement plus court (jeton partagé)
const LEAPER_SHOT_RECOVERY_S := 0.3
const LEAPER_DASH_RECOVERY_S := 0.5 ## immobile après sa course : fenêtre de punition
const BRUTE_RECOVERY_S := 0.4 ## immobile après le cône ou l'onde de choc
const SWARM_BITE_PAUSE_S := 0.25 ## essaim : sur place après chaque morsure (contact passif, sans armement)
const SWARM_BITE_RECOIL_U := 0.25 ## petit recul après la morsure (lisibilité du coup, évite de coller le joueur)

# Boss
## Alignement RoR2 : PV = base × niveau ambiant (+30 %/niv) × √coeff (le téléporteur RoR2 dépense 600·√coeff)
## × BOSS_STAGE_K^(étage-1) (compense les ~10 objets/étage). Base étage 3000 (était 4300) : ~50-60 s en Moyen (remplace 2200 × D^1,6).
const BOSS_BASE_HP := {&"mini": 1000.0, &"etage": 3000.0} ## −23 % / −30 % (retour joueur 21/10 : boss d'étage 1 ≈ 3 min avec 8 objets)
const BOSS_BASE_DMG := {&"mini": 20.0, &"etage": 28.0} ## +20 %/niveau ambiant (remplace 25/35 × (1 + 0,3 (D-1)))
const BOSS_STAGE_K := 0.95
## Valeur director d'un boss (en coûts de tier 1) pour sa prime : or = 2 × coeff × valeur × R, XP = la moitié.
const BOSS_VALUE := {&"mini": 25.0, &"etage": 60.0}
const BOSS_ENRAGE_AFTER_S := 90.0 ## boss d'étage visé ~75 s : l'enrage arrive après (remplace 60)
const BOSS_ENRAGE_PER_S := 0.015
## Coefficients des coups des boss d'étage à IA propre (× Enemy.damage = boss_damage), par skin et par coup
## (docs/Design_Boss_Cartes.md §3) ; lus par CerfBrain / SonneurBrain via boss_attack_coef(). Coup absent : 1.
const BOSS_ATTACK_COEF := {
	&"cerf": {&"gore": 1.1, &"charge": 1.6, &"trail": 0.35, &"wisp": 0.75, &"leap": 1.5},
	## Sonneur §3.3 : marteau 1,0 ; glas 1,5 ; boulons 1,3 ; foudre 2,5 (P2+) ; vapeur 0,4 par 0,5 s (P3) ;
	## orage (foudre après sa mort, jusqu'à la fin de la charge) 2,0, sans le plafond des boss (25 %).
	&"sonneur": {&"hammer": 1.0, &"glas": 1.5, &"bolts": 1.3, &"lightning": 2.5, &"steam": 0.4, &"storm": 2.0},
	## Reclus (étage 4, Design_Etages §5.4) : bâton 1,0 ; cloche 1,5 (+ silence 2 s) ; prières 1,3 ;
	## rayons de cristal 0,45 par 0,5 s (P3).
	&"recluse": {&"staff": 1.0, &"bell": 1.5, &"prayers": 1.3, &"rays": 0.45},
	## Semeur de pluie (boss final, §4) : fouet 1,0 ; averse 1,3 ; vague 1,5 ; débordement 1,2 (P2) ;
	## noyade 0,3 par 0,5 s (P2) ; tourbillon 1,1, croix 0,45 par 0,5 s, foudre 2,5 (P3).
	&"rain_sower": {&"lash": 1.0, &"rain": 1.3, &"wave": 1.5, &"surge": 1.2, &"drown": 0.3, &"whirl": 1.1, &"cross": 0.45, &"lightning": 2.5},
	## Éclusier (étage 1, Design_Boss_Cartes §3.1) : coup de vanne 1,0 ; lâcher d'eau 1,6 (+ poussée 3 u) ;
	## geysers 1,4 ; geysers permanents 1,0 (P2+, trace) ; croix de la roue 1,2 (P3).
	&"eclusier": {&"gate": 1.0, &"wave": 1.6, &"geyser": 1.4, &"spring": 1.0, &"cross": 1.2},
	## Bouvier (étage 1, Design_Etages §5.1) : cornes 1,0 ; charge 1,8 ; piétinement 1,4 ; vagues de boue 0,4 par
	## 0,5 s (P3, embourbé) ; arrachement (piétinement de sortie de boue) 1,2.
	&"ox_herder": {&"horns": 1.0, &"charge": 1.8, &"stomp": 1.4, &"mud": 0.4, &"tear": 1.2},
	## Porteuse de jarres (étage 1, §5.1) : jet de jarre 1,0 ; pluie de jarres 1,3 ; jarre-mère 1,5 ;
	## jarres en orbite 0,6 par contact (P3, 1 s entre deux coups).
	&"jar_bearer": {&"jar": 1.0, &"rain": 1.3, &"mother": 1.5, &"orbit": 0.6},
	## Grue (étage 3, Design_Etages §5.3) : crochet 1,0 ; conteneur 1,8 ; balayage de flèche 1,4 ;
	## arc de tempête entre conteneurs 1,3 (P3).
	&"crane": {&"hook": 1.0, &"container": 1.8, &"sweep": 1.4, &"arc": 1.3},
	## Fondeur (étage 3, §5.3) : louche 1,0 (+ brûlure) ; coulée 1,5 (+ brûlure) ; métal au sol 0,5 par
	## 0,5 s (+ brûlure, coulées et anneau) ; étincelles 0,8 chacune ; vapeur 0,4 par 0,5 s (P3) ; trempe 1,6 (P3).
	&"smelter": {&"ladle": 1.0, &"pour": 1.5, &"pool": 0.5, &"sparks": 0.8, &"steam": 0.4, &"quench": 1.6},
	## Mère-Cristal (étage 4, Design_Etages §5.4) : éclat 1,0 ; stalactites 1,3 ; prisme 2,0 (et ses lignes
	## réfractées) ; éclats en orbite 0,5 par contact (P3) ; reflet (sort d'un bloc, P2+) 1,5.
	&"crystal_mother": {&"shard": 1.0, &"stalactites": 1.3, &"prism": 2.0, &"orbit": 0.5, &"reflect": 1.5},
	## Anguille des profondeurs (étage 4, §5.4) : morsure 1,1 ; émergence 1,8 ; décharge 1,4 (+ ralenti) ;
	## fouets 0,5 par 0,5 s (P3, échouée) ; eau électrisée (P3 : toute l'eau, flaques comprises) 1,2.
	&"deep_eel": {&"bite": 1.1, &"emergence": 1.8, &"discharge": 1.4, &"whip": 0.5, &"live_water": 1.2},
	## Tisseuse (étage 2, Design_Etages §5.2) : morsure 1,0 ; fils 1,2 (au lancer, puis ralentissent) ;
	## descente 1,6 (aussi quand la toile vibre, P2+).
	&"weaver": {&"bite": 1.0, &"threads": 1.2, &"drop": 1.6},
	## Cèdre-Ermite (étage 2, §5.2) : branche 1,0 ; racines 1,3 ; spores 0,6 + poison (coup de référence
	## spore_poison 1,0) ; vrille 1,0 (P2) ; charge 1,8 et racines des souches 1,0 (P3).
	&"hermit_cedar": {&"branch": 1.0, &"roots": 1.3, &"spores": 0.6, &"spore_poison": 1.0, &"tendril": 1.0, &"charge": 1.8, &"echo": 1.0},
	## Idole noyée (étage 1, Design_Boss_Raid §2.1) : paume 1,0 ; carillon 1,2 ; chapelet 1,3 ; chute de cloche 0,8
	## (RAID_ORB_FALL_COEF) ; digue (dessous) 0,6 ; noria 0,5 par 0,5 s ; anneau continu P3 1,0.
	&"flood_gunner": {&"breech": 1.0, &"pylon_drop": 0.8, &"shell": 1.6},
	## Roi de sel (étage 4, Design_Boss_Raid §2.3) : sceptre 1,0 ; marée de la Procession 0,4 par 0,5 s
	## (RAID_SECTOR_TICK_COEF, appliquée par SafeSector) ; stèle (dessous à la levée) 1,2 ; édit (anneau) 1,4.
	&"salt_king": {&"scepter": 1.0, &"procession": 0.4, &"stele": 1.2, &"edict": 1.4},
	&"drowned_idol": {&"palm": 1.0, &"carillon": 1.2, &"chaplet": 1.3, &"bell_drop": 0.8, &"dike": 0.6, &"noria": 0.5, &"ring_p3": 1.0},
}
## Mère-Cristal P2+ : un monstre (et la Mère elle-même) dans la lumière d'une lampe de cristal subit +15 %.
const CRYSTAL_LAMP_DAMAGE_TAKEN := 1.15
## Anguille plongée dans l'eau noire : dégâts reçus × 0,3 (« DPS sur une cible qui disparaît »).
const EEL_SUBMERGED_DAMAGE_TAKEN := 0.3
## Dégâts reçus par phase (index phase - 1) : Sonneur P3 « chaudière rompue » +25 % ; Semeur P3 ancré +20 %.
const BOSS_PHASE_DAMAGE_TAKEN := {&"sonneur": [1.0, 1.0, 1.25], &"rain_sower": [1.0, 1.0, 1.2],
	&"deep_eel": [1.0, 1.0, 1.25], ## Anguille P3 échouée sur l'anneau : +25 %
	&"smelter": [1.0, 1.0, 1.25], ## Fondeur P3 « surchauffe » : +25 %
	&"hermit_cedar": [1.0, 1.25, 1.0], ## Cèdre-Ermite P2 enraciné, lanterne exposée : +25 % (burst)
	&"drowned_idol": [1.0, 1.0, 1.2]} ## Idole noyée P3 ancrée sur son socle fendu : +20 %
## Seuils de phase des boss d'étage (fraction de PV restante : phase 2 à <= [0], phase 3 à <= [1]).
## Défaut 66 / 33 % (cerf, sonneur, reclus) ; Semeur de pluie 70 / 35 % (Design_Etages §4). Mini-boss : 50 %.
const BOSS_PHASE_THRESHOLDS_DEFAULT := [0.66, 0.33]
const BOSS_PHASE_THRESHOLDS := {&"rain_sower": [0.70, 0.35],
	&"crystal_mother": [0.70, 0.35], &"deep_eel": [0.70, 0.35], ## Design_Etages §5.4 : 70 / 35 %
	&"crane": [0.70, 0.35], &"smelter": [0.70, 0.35], ## Design_Etages §5.3 : 70 / 35 %
	&"weaver": [0.70, 0.35], &"hermit_cedar": [0.70, 0.35], ## Design_Etages §5.2 : 70 / 35 %
	&"eclusier": [0.70, 0.35], &"ox_herder": [0.70, 0.35], &"jar_bearer": [0.70, 0.35],
	&"drowned_idol": [0.70, 0.35], &"flood_gunner": [0.70, 0.35], &"salt_king": [0.70, 0.35]} ## Boss_Cartes §3.1, Etages §5.1 ; Canonnier §2.2
## Fenêtre d'ancrage (Bouvier P3 « embourbé ») : dégâts reçus × ce facteur tant qu'il est enlisé (burst).
const BOSS_ANCHOR_DAMAGE_TAKEN := {&"ox_herder": 1.3}
## Mémoire de profil (Design_Etages §2.2) : le boss d'étage vu à cet étage lors de la run précédente pèse × 0,5
## au tirage du plan de run (FloorPlan, Profile.last_floor_boss).
const BOSS_MEMORY_WEIGHT := 0.5
const MINI_BOSS_PHASE_THRESHOLD := 0.5
## --- Mini-boss pilotés par données (MiniBossBrain, data/minibosses.json). Les coefs du JSON sont relatifs à
## Enemy.damage (Dég_base 20, Design_Boss_Cartes §2) et passent tous par mini_attack_damage().
const MINI_ATTACK_SCALE := 1.0 ## échelle globale des coups de mini-boss (réglage d'équilibrage)
const MINI_SPELL_WINDUP_MIN := 0.8 ## règle de lisibilité : sort télégraphé >= 0,8 s
const MINI_AUTO_WINDUP_MIN := 0.35
const MINI_SPELL_GAP_S := 2.0 ## délai minimal entre deux sorts d'un mini-boss
const MINI_DESIGN_SPEED_REF_U := 2.6 ## vitesse de design moyenne (u/s) : speed_u / ref × vitesse de boss
const MINI_SUMMON_CAP := 12 ## invocations vivantes max par mini-boss (perf, foule)
const MINI_GUARD_MIN := 0.3 ## plancher des réductions de dégâts cumulées (gardes, carapaces)
## Boss final (Design_Etages §4) apparu comme boss d'étage : dégâts de base 32 au lieu de 28, appliqués par
## son IA (RainSowerBrain) à l'activation. Ses PV ×2 viennent du paratonnerre-mère (Pillar.setup_final).
const BOSS_DMG_MULT := {&"rain_sower": 32.0 / 28.0}
## --- Rythme des coups de boss d'étage et de mini-boss (retour joueur 22/10 : « ils frappent en marchant ») :
## armement planté, impact, récupération immobile. Lu par BossPace (scripts/enemies/boss_pace.gd) ; valeurs de
## docs/Comportements_Monstres.md « Boss : armement / récupération ». Par catégorie, [phase 1, phase 2, phase 3]
## en s (mini-boss : phases 1-2) : plus long en phase 1, un peu plus court en phase 3, jamais sous la valeur
## de phase 3 (seuil lisible). La récupération ne raccourcit pas avec l'enrage (seule la cadence monte).
## auto = attaque de base (mêlée ou tir), mini_auto = celle d'un mini-boss, spell = sort / zone (cercle, cône,
## ligne), heavy = gros coup (slam, laser), charge = ruée ou bond (mouvement pendant l'action seulement),
## combo = récupération après le dernier coup d'un enchaînement.
const BOSS_PACE_WINDUP := {&"auto": [0.6, 0.55, 0.5], &"mini_auto": [0.5, 0.47, 0.45],
	&"spell": [1.1, 0.95, 0.85], &"heavy": [1.6, 1.4, 1.25], &"charge": [1.0, 0.9, 0.8], &"combo": [0.6, 0.55, 0.5]}
const BOSS_PACE_RECOVER := {&"auto": [0.5, 0.45, 0.4], &"mini_auto": [0.45, 0.4, 0.35],
	&"spell": [0.9, 0.8, 0.7], &"heavy": [1.3, 1.15, 1.0], &"charge": [0.8, 0.7, 0.6], &"combo": [0.8, 0.7, 0.6]}
const BOSS_PACE_RECOVER_MIN_S := 0.3 ## plancher absolu d'une récupération réglée à la main
const BOSS_PACE_COMBO_GAP_S := 0.25 ## écart minimal entre deux coups d'un enchaînement (immobile)
const BOSS_PACE_SPELL_AFTER_AUTO_S := 0.3 ## écart minimal entre la fin d'une auto et l'armement d'un sort
## Impact : arrêt sur image du corps du boss (s, coupé si GameSettings.hitstop_enabled() est faux) et secousse de
## caméra (px, × GameSettings.shake_scale() « Secousses de caméra », appliqué dans Main.shake).
const BOSS_PACE_FREEZE_S := {&"auto": 0.04, &"mini_auto": 0.03, &"spell": 0.06, &"heavy": 0.09, &"charge": 0.07, &"combo": 0.04}
const BOSS_PACE_SHAKE_PX := {&"spell": 2.5, &"heavy": 7.0, &"charge": 5.0}
const BOSS_PACE_SHAKE_HZ := 20.0
const BOSS_PACE_SHAKE_S := 0.22
## --- Boss façon raid (docs/Design_Boss_Raid.md §1, boîte à outils scripts/enemies/raid/). Les réglages marqués
## « question ouverte » attendent l'arbitrage du joueur (§5) : ils sont centralisés ici pour être changés sans code.
## PV des boss à deux boucliers (§0 règle 5) : × ce facteur, lu par boss_hp_mult(boss_id) (à appliquer à
## l'activation du boss, boss_hp() reste inchangé).
const BOSS_HP_MULT := {&"drowned_idol": 0.9, &"flood_gunner": 0.9, &"salt_king": 0.9}
## Nombre de boucliers de phase par boss (question ouverte 1 : 2 pour les nouveaux, 1 pour les existants).
const BOSS_SHIELDS := {&"drowned_idol": 2, &"flood_gunner": 2, &"salt_king": 2}
const BOSS_SHIELDS_DEFAULT := 1
## Bouclier (§1.1) : transition figée, mise en place, garde-fou (question ouverte 2 : 25 s, 20 s pour l'ultime),
## rupture, fenêtre de vulnérabilité bonus (× dégâts reçus), cadence du seul sort lent gardé sous bouclier.
const BOSS_SHIELD_TRANSITION_S := 0.9
const BOSS_SHIELD_SETUP_S := 1.2
const BOSS_SHIELD_BACKSTOP_S := 25.0
const BOSS_SHIELD_BACKSTOP_ULT_S := 20.0
const BOSS_SHIELD_BREAK_S := 0.5
const BOSS_SHIELD_EXPOSED_MULT := 1.3
const BOSS_SHIELD_EXPOSED_S := 2.5
const BOSS_SHIELD_SLOW_SPELL_S := 4.0
## Enrage doux (§1.8) : avertissement avant l'enrage (BOSS_ENRAGE_AFTER_S), horloge gelée sous bouclier.
const BOSS_ENRAGE_WARN_S := 75.0
## Condition ULTIMATE_HIT (question ouverte 4) : ultime obligatoire ; option « N coups lourds » (0 = coupée, 2 =
## alternative proposée) : un coup de sort >= RAID_HEAVY_HIT_FRAC du meilleur coup vu compte comme un coup d'ultime.
const RAID_ULT_REQUIRED := true
const RAID_ULT_ALT_HEAVY_HITS := 0
const RAID_HEAVY_HIT_FRAC := 0.25
## Barrage (§1.2, question ouverte 3) : coef par projectile (× dégâts du boss, enrage compris), immunité visée
## (aujourd'hui couverte par l'invulnérabilité de 0,4 s du joueur après un coup), télégraphe, plafond vivant.
const RAID_BARRAGE_COEF := 0.2
const RAID_BARRAGE_IFRAME_S := 0.35
const RAID_BARRAGE_TELEGRAPH_S := 1.5
const RAID_BARRAGE_MAX_LIVE := 160
const RAID_BARRAGE_MIN_PYLONS := 2
## Pylônes-abris : PV (part des PV du boss), plafond vivant, coef de la chute (joueur dessous).
const RAID_PYLON_HP_FRAC := 0.04
const RAID_PYLON_MAX := 6
const RAID_PYLON_FALL_COEF := 0.8
const RAID_ORB_FALL_COEF := 0.8
## Pénalités d'échec : zone à absorber ratée, soin du boss par add arrivé (plafond par bouclier), secteur.
const RAID_SOAK_FAIL_COEF := 1.0
const RAID_ADD_HEAL_FRAC := 0.10
const RAID_ADD_HEAL_CAP_FRAC := 0.20
const RAID_SECTOR_TICK_COEF := 0.4
const RAID_SECTOR_SLOW_PCT := 0.30
## Point faible : dégâts transférés au boss × ce facteur.
const RAID_WEAK_TRANSFER := 2.0
## Plafond d'une pénalité d'échec (part des PV max du joueur) ; non létale : jamais sous 1 PV (règle 2).
const RAID_PENALTY_MAX_FRAC := 0.40
const RAID_PENALTY_NONLETHAL := true


## Multiplicateur de PV d'un boss façon raid (BOSS_HP_MULT), 1 sinon.
func boss_hp_mult(boss_id: StringName) -> float:
	return float(BOSS_HP_MULT.get(boss_id, 1.0))


## Nombre de boucliers de phase d'un boss (BOSS_SHIELDS, défaut BOSS_SHIELDS_DEFAULT).
func boss_shield_count(boss_id: StringName) -> int:
	return int(BOSS_SHIELDS.get(boss_id, BOSS_SHIELDS_DEFAULT))

# Joueur
const PLAYER_SPEED_U := 4.0
const MOVE_SPEED_BONUS_CAP := 0.35 ## RoR2 n'a pas de plafond ; garde-fou survivor-like (remplace 0,10)
const ATTACK_SPEED_BONUS_CAP := 2.0
const PROJECTILE_SPEED_U := 12.0
const PROJECTILE_SPEED_BONUS_CAP := 1.0
const PIERCE_CAP := 5
## Plafonds des bonus d'items, appliqués par ItemStats.compute (somme de tous les items).
const ITEM_BONUS_CAPS := {
	"move_speed": MOVE_SPEED_BONUS_CAP, "attack_speed": ATTACK_SPEED_BONUS_CAP,
	"projectile_speed": PROJECTILE_SPEED_BONUS_CAP, "zone_size_add": 1.0, "xp_mult": 1.0,
	"range_add": 0.5, "pickup_radius_mult": 2.0, "pierce": float(PIERCE_CAP),
}
## Roulade (esquive d'Ardent) : DODGE_DISTANCE_U en DODGE_DURATION_S, invulnérable pendant, recharge fixe.
const DODGE_DISTANCE_U := 3.0
const DODGE_DURATION_S := 0.25
const DODGE_COOLDOWN_S := 3.0
const COOLDOWN_FLOOR := 0.25
const BASE_CRIT_CHANCE := 0.01 ## RoR2 (remplace 0,05)
const BASE_CRIT_MULT := 2.0

# Coffres
## Bases ÷3 par rapport au doc (retour joueur : trop chers ; or mesuré ≈ 55 à 60 s, joueur immobile).
## Le prix est figé à l'apparition du coffre (début d'étage), voir chest.gd.
const CHEST_BASE := {&"petit": 50.0, &"large": 100.0, &"legendaire": 400.0}
## Alignement RoR2 : petit 50 / grand 100 / légendaire 400 (×8, arbitrage joueur ; RoR2 25/50/400 $ = ×16).
const CHEST_PRICE_STAGE := 1.04 ## calibré (remplace 1,05)
## Capsules d'argent gratuites : nombre par étage et or par capsule à coeff 1 (remplace CAPSULE_GOLD_SHARE 0,4
## du prix d'un petit coffre).
const CAPSULES_PER_STAGE := 10
const CAPSULE_GOLD := 20.0
## d100 de qualité, aligné RoR2 (blanc 79 / vert 20 / rouge 1 ; grand coffre vert 80 / rouge 20 ; boss = vert,
## 15 % d'objet de boss). Le légendaire ne sort que des grands coffres et du coffre légendaire. Pas de pity
## (RoR2 n'en a pas) : la Chance (relances du d100) est le seul levier. Remplace 60/32/7/1 + pity, 80/20, 90/10.
const CHEST_QUALITY_TABLE := {
	&"petit": {&"commun": 78, &"peu_commun": 20, &"rare": 2},
	&"large": {&"peu_commun": 80, &"rare": 18, &"legendaire": 2},
	&"legendaire": {&"legendaire": 100},
	&"boss": {&"peu_commun": 85, &"rare": 15},
}


## Coefficient de difficulté RoR2 (solo) ; `d` = MODES[mode]. Pas d'accélération « endless » (RoR2 n'en a pas).
func difficulty(t_s: float, stage: int, d: float = 1.0) -> float:
	return (1.0 + t_s / 60.0 * TIME_SLOPE * d * TIME_COMPRESSION) * pow(K_STAGE, stage - 1)


## Paliers de difficulté (seuils resserrés pour l'échelle RoR2 : coeff ≈ 3 en fin d'étage 5 en Moyen).
## Source unique : nom, D de début (le palier dure jusqu'au début du suivant ; le dernier est sans fin),
## identifiant de texture du bandeau (`ui/difficulty/banner/seg_<id>.png`) et couleur.
const DIFFICULTY_TIERS: Array[Dictionary] = [
	{"name": &"Calme", "from": 0.0, "id": &"calme", "color": Color(0.35, 0.8, 0.45)},
	{"name": &"Tendu", "from": 1.25, "id": &"tendu", "color": Color(0.95, 0.85, 0.25)},
	{"name": &"Hostile", "from": 1.6, "id": &"hostile", "color": Color(0.98, 0.55, 0.15)},
	{"name": &"Furieux", "from": 2.2, "id": &"furieux", "color": Color(0.9, 0.2, 0.2)},
	{"name": &"Cataclysme", "from": 3.0, "id": &"cataclysme", "color": Color(0.75, 0.2, 0.9)},
]


func difficulty_tier_index(D: float) -> int:
	var idx := 0
	for i in DIFFICULTY_TIERS.size():
		if D >= float(DIFFICULTY_TIERS[i]["from"]):
			idx = i
	return idx


func difficulty_tier_name(D: float) -> StringName:
	return DIFFICULTY_TIERS[difficulty_tier_index(D)]["name"]


## Couleur d'un palier (blanc si le nom est inconnu).
func difficulty_tier_color(tier_name: StringName) -> Color:
	for t in DIFFICULTY_TIERS:
		if t["name"] == tier_name:
			return t["color"]
	return Color.WHITE


func monster_level(D: float) -> int:
	return 1 + int(floor((D - 1.0) / 0.33))


# --- Director
## `zone_kind` : &"" hors zone, &"mini" (pilier de mini-boss) ou &"etage" (charge du téléporteur).
func director_credits_per_s(D: float, zone_kind: StringName = &"") -> float:
	return CREDIT_K * (1.0 + 0.4 * D) * float(ZONE_SPAWN_MULT.get(zone_kind, 1.0))


## Multiplicateur de crédits en début de run : RAMP_CREDITS_MIN à 0 s, 1 à RAMP_TIME_S / 2.
func director_ramp(t_s: float) -> float:
	return clampf(RAMP_CREDITS_MIN + (1.0 - RAMP_CREDITS_MIN) * t_s / (RAMP_TIME_S * 0.5), RAMP_CREDITS_MIN, 1.0)


## Monstres vivants autorisés : RAMP_ALIVE_MIN à 0 s, RAMP_ALIVE_MAX à RAMP_TIME_S (MAX_ENEMIES reste la taille du pool).
func director_alive_cap(t_s: float) -> int:
	return int(lerpf(RAMP_ALIVE_MIN, RAMP_ALIVE_MAX, clampf(t_s / RAMP_TIME_S, 0.0, 1.0)))


func elite_chance(D: float) -> float:
	return clampf(0.05 * (D - 1.0), 0.0, 0.25)


## Chance qu'une vague du Director soit menée par une élite.
func wave_leader_chance(D: float) -> float:
	return clampf(WAVE_LEADER_BASE + 2.0 * elite_chance(D), 0.0, WAVE_LEADER_MAX)


func elite_affix_count(D: float) -> int:
	return 2 if D >= 4.0 else 1


# --- Monstres
## Remplacé : base × D^1,15 (PV) et base × (1 + 0,3 (D-1)) (dégâts). Désormais par niveau ambiant (RoR2).
func monster_hp(base: float, D: float) -> float:
	return base * (1.0 + LEVEL_HP_GROWTH * (monster_level(D) - 1))


func monster_damage(base: float, D: float) -> float:
	return base * (1.0 + LEVEL_DMG_GROWTH * (monster_level(D) - 1))


func monster_speed(base: float, D: float) -> float:
	return base * minf(1.30, 1.0 + 0.02 * (D - 1.0))


## Coût director d'un monstre (prime RoR2 ∝ coût) : TIER_COST × ELITE_COST_MULT si élite.
func monster_cost(tier: int, elite: bool) -> float:
	return float(TIER_COST.get(tier, 1.0)) * (ELITE_COST_MULT if elite else 1.0)


## XP d'un kill = coeff × coût × R (remplace XP_BASE × D^0,8 × reward).
func monster_xp(D: float, cost: float) -> float:
	return D * cost * REWARD_MULT


## Or d'un kill = 2 × coeff × coût × R (remplace D^1,25 × reward, plafonné par la réserve d'étage, supprimée).
func monster_gold(D: float, cost: float) -> float:
	return 2.0 * D * cost * REWARD_MULT


## `stage` : étage du combat (RunState.stage côté jeu).
func boss_hp(kind: StringName, D: float, stage: int = 1) -> float:
	return BOSS_BASE_HP[kind] * (1.0 + LEVEL_HP_GROWTH * (monster_level(D) - 1)) * sqrt(D) * pow(BOSS_STAGE_K, stage - 1)


func boss_damage(kind: StringName, D: float) -> float:
	return BOSS_BASE_DMG[kind] * (1.0 + LEVEL_DMG_GROWTH * (monster_level(D) - 1))


func boss_enrage_mult(fight_time_s: float) -> float:
	return 1.0 + BOSS_ENRAGE_PER_S * maxf(0.0, fight_time_s - BOSS_ENRAGE_AFTER_S)


## Coefficient d'un coup de boss à IA propre (BOSS_ATTACK_COEF), 1 si inconnu.
func boss_attack_coef(boss_id: StringName, attack: StringName) -> float:
	return float((BOSS_ATTACK_COEF.get(boss_id, {}) as Dictionary).get(attack, 1.0))


## Phase (1..3) d'un boss selon la fraction de PV restante `hp_frac` ; mini-boss : 1..2.
func boss_phase(kind: StringName, boss_id: StringName, hp_frac: float) -> int:
	if kind == &"mini":
		return 2 if hp_frac <= MINI_BOSS_PHASE_THRESHOLD else 1
	var t: Array = BOSS_PHASE_THRESHOLDS.get(boss_id, BOSS_PHASE_THRESHOLDS_DEFAULT)
	return 3 if hp_frac <= float(t[1]) else (2 if hp_frac <= float(t[0]) else 1)


## Multiplicateur des dégâts reçus par un boss selon sa phase (1..3), 1 si inconnu.
func boss_damage_taken_mult(boss_id: StringName, phase: int) -> float:
	var arr: Array = BOSS_PHASE_DAMAGE_TAKEN.get(boss_id, [])
	return float(arr[clampi(phase - 1, 0, arr.size() - 1)]) if not arr.is_empty() else 1.0


## Dégâts d'un coup de mini-boss : Enemy.damage × coef (data/minibosses.json) × MINI_ATTACK_SCALE.
func mini_attack_damage(base_damage: float, coef: float) -> float:
	return base_damage * coef * MINI_ATTACK_SCALE


## Télégraphe d'un mini-boss borné par la règle de lisibilité (sort >= 0,8 s, auto >= 0,35 s).
func mini_windup(windup: float, is_auto: bool) -> float:
	return maxf(windup, MINI_AUTO_WINDUP_MIN if is_auto else MINI_SPELL_WINDUP_MIN)


## Multiplicateur de vitesse d'un mini-boss d'après sa vitesse de design (u/s).
func mini_speed_mult(design_speed_u: float) -> float:
	return design_speed_u / MINI_DESIGN_SPEED_REF_U


## Multiplicateur de dégâts propre à un boss (BOSS_DMG_MULT), 1 si inconnu.
func boss_dmg_mult(boss_id: StringName) -> float:
	return float(BOSS_DMG_MULT.get(boss_id, 1.0))


# --- Poids des coups (game feel : hitstop et recul par monstre, coups directs seulement)
## Force relative f d'un coup = √(dégâts / (dégât de base du joueur × HIT_FORCE_REF_COEF)), bornée à [0, 1].
## Choix : dégâts / dégât de base plutôt que dégâts / PV max. La puissance mesure l'attaque elle-même
## (coef du sort × bonus d'items, la même grandeur que la puissance sonore du lancer) ; le poids du
## monstre est porté séparément par KB_MASS. Avec les PV max, tout coup sur un essaim serait « énorme »
## et tout coup sur un boss imperceptible. Référence : Brasier (coef 10) = 1 ; Éclat de braise (0,8) ≈ 0,28 ;
## Nova (3) ≈ 0,55. La racine garde les petits coups perceptibles et tasse les gros sous le plafond.
const HIT_FORCE_REF_COEF := 10.0
const HIT_FORCE_CRIT_BONUS := 0.25 ## ajouté à f avant le plafond
const HITSTOP_MIN_S := 0.016 ## 1 frame à 60 Hz (f = 0)
const HITSTOP_MAX_S := 0.080 ## plafond (f = 1)
const HITSTOP_REARM_S := 0.10 ## délai minimal entre deux gels d'un même monstre (pas de gel permanent sous un flot de coups)
const KB_MIN_U := 0.1 ## recul pour f = 0
const KB_MAX_U := 0.6 ## recul pour f = 1, avant le facteur de masse ; c'est aussi le plafond cumulé
const KB_MASS := {1: 1.0, 2: 0.7, 3: 0.4} ## essaim > tireur > brute
const KB_ELITE_MULT := 0.6
const KB_BOSS_MULT := {&"mini": 0.08, &"etage": 0.04} ## presque immunisés (les boss ne gèlent pas)
const HIT_FLASH_MIN_S := 0.06
const HIT_FLASH_MAX_S := 0.08


func hit_force(amount: float, base_damage: float, is_crit: bool) -> float:
	var f := sqrt(clampf(amount / maxf(base_damage * HIT_FORCE_REF_COEF, 0.001), 0.0, 1.0))
	if is_crit:
		f += HIT_FORCE_CRIT_BONUS
	return clampf(f, 0.0, 1.0)


func hitstop_time(f: float) -> float:
	return lerpf(HITSTOP_MIN_S, HITSTOP_MAX_S, clampf(f, 0.0, 1.0))


## Facteur de masse : tier (1-3), élite, boss (kind &"mini"/&"etage").
func knockback_mass(tier: int, elite: bool, boss_kind: StringName = &"") -> float:
	if boss_kind != &"":
		return KB_BOSS_MULT.get(boss_kind, 0.05)
	return float(KB_MASS.get(tier, 0.4)) * (KB_ELITE_MULT if elite else 1.0)


## Recul en px pour une force f et un facteur de masse.
func knockback_px(f: float, mass_mult: float) -> float:
	return lerpf(KB_MIN_U, KB_MAX_U, clampf(f, 0.0, 1.0)) * mass_mult * UNIT_PX


func hit_flash_time(f: float) -> float:
	return lerpf(HIT_FLASH_MIN_S, HIT_FLASH_MAX_S, clampf(f, 0.0, 1.0))


# --- Joueur
func player_max_hp(level: int) -> float:
	return 100.0 + 30.0 * (level - 1)


func player_base_damage(level: int) -> float:
	return 12.0 + 2.4 * (level - 1)


## Comme Risk of Rain 2 (1 PV/s + 0,2 par niveau) ; doc : 0,5 + 0,1.
func player_regen(level: int) -> float:
	return 1.0 + 0.2 * (level - 1)


## Courbe RoR2 : niveau = 1 + log1,55(1 + LEVEL_K × XP totale) ; RoR2 LEVEL_K = 0,0275, calibré 0,076
## (niveau ~7,5 en fin d'étage 1 en Moyen). XP du niveau L au suivant = 0,55 / LEVEL_K × 1,55^(L-1).
## Remplacé : 10 + 8 L + 0,5 L².
const LEVEL_K := 0.076
const LEVEL_GROWTH := 1.55


func xp_required(level: int) -> float:
	return (LEVEL_GROWTH - 1.0) / LEVEL_K * pow(LEVEL_GROWTH, level - 1)


func armor_reduction(armor: float) -> float:
	return armor / (armor + 100.0)


## Recharge multiplicative façon RoR2 (Alien Head ×0,75ⁿ) : cd_mult = produit des items (1 = neutre),
## plancher COOLDOWN_FLOOR de la base. Remplace base / (1 + Σ cdr).
func effective_cooldown(base_s: float, cd_mult: float) -> float:
	return maxf(base_s * cd_mult, base_s * COOLDOWN_FLOOR)


func attack_interval(base_s: float, attack_speed_sum: float) -> float:
	return base_s / (1.0 + minf(attack_speed_sum, ATTACK_SPEED_BONUS_CAP))


func move_speed_px(bonus_sum: float) -> float:
	return PLAYER_SPEED_U * (1.0 + minf(bonus_sum, MOVE_SPEED_BONUS_CAP)) * UNIT_PX


func projectile_speed_px(bonus_sum: float) -> float:
	return PROJECTILE_SPEED_U * (1.0 + minf(bonus_sum, PROJECTILE_SPEED_BONUS_CAP)) * UNIT_PX


# --- Stacking d'items (docs/Maths_Scaling.md §9)
func stack_linear(a: float, n: int) -> float:
	return a * n


func stack_hyperbolic(a: float, n: int) -> float:
	return 1.0 - 1.0 / (1.0 + a * n)


func stack_exponential(a: float, n: int) -> float:
	return pow(1.0 + a, n) - 1.0


# --- Économie
## RoR2 : prix = base × coeff^1,25 (remplace × (1 + 0,3 (D-1)) en plus) ; dérive CHEST_PRICE_STAGE par étage.
func chest_price(kind: StringName, D: float, stage: int) -> float:
	return CHEST_BASE[kind] * pow(D, 1.25) * pow(CHEST_PRICE_STAGE, stage - 1)


## Or d'une capsule d'argent : CAPSULE_GOLD × coeff^1,25 (10 capsules = 200 or à coeff 1). `stage` ignoré
## (remplace 0,4 × prix d'un petit coffre, dérive d'étage comprise) ; gardé pour la signature.
func capsule_gold(D: float, _stage: int = 1) -> float:
	return CAPSULE_GOLD * pow(D, 1.25)


func gold_reroll_price(chest_price_value: float, rerolls_done: int) -> float:
	return 0.6 * chest_price_value * pow(1.5, rerolls_done)


## Changement d'étage (comme Risk of Rain) : l'or restant (bourse + pièces au sol) devient de l'XP.
## Taux : GOLD_TO_XP_SHARE × l'XP des kills qui ont rapporté cet or (XP d'un kill = ½ or, même coût, même coeff).
## Moitié seulement : dépenser son or en coffres doit rester plus rentable que le garder. Soit 0,25 XP par or.
const GOLD_TO_XP_SHARE := 0.5


func gold_to_xp(gold_amount: float, _D: float = 1.0) -> float:
	if gold_amount <= 0.0:
		return 0.0
	return GOLD_TO_XP_SHARE * gold_amount * 0.5


func mini_boss_gold(D: float) -> float:
	return boss_gold(&"mini", D)


## Primes de boss (RoR2 : prime ∝ coût director) : or = 2 × coeff × BOSS_VALUE × R.
## Remplacé : BOSS_GOLD_KILLS (100/250) × BOSS_GOLD_MULT 0,25 × D^1,25.
func boss_gold(kind: StringName, D: float) -> float:
	return 2.0 * D * float(BOSS_VALUE.get(kind, 25.0)) * REWARD_MULT


## XP d'un boss = la moitié de son or (comme les kills). Remplacé : 40/100 kills de tier 1.
func boss_xp(kind: StringName, D: float) -> float:
	return 0.5 * boss_gold(kind, D)


## Remplacé (Alignement RoR2) : réserve d'or des monstres par étage (MONSTER_GOLD_BUDGET_MAX 4 petits coffres,
## +1,75/min, 5 % au-delà). RoR2 n'a pas de réserve : la prime suit le coeff et le coût, les prix montent en
## coeff^1,25 ; le surplus de fin d'étage est tenu par REWARD_MULT et CHEST_PRICE_STAGE (simulation).


func run_rubies(active_minutes: float, mode: StringName, pillars_done: int, victory: bool, gold_left: float) -> int:
	var gold_bonus := mini(int(gold_left / 500.0), 20)
	return int(floor(1.2 * active_minutes * RUBY_MODE_MULT[mode])) + 8 * pillars_done + (25 if victory else 0) + gold_bonus



# --- UX (docs/ux/Audit_Menus.md §3.3 : transition d étage) ---
const FLOOR_CARD_S := 2.2 ## durée du carton d étage (RunState.running = false, joueur invulnérable)
const FLOOR_FADE_OUT_S := 0.35 ## fondu au noir à l arrivée sur le carton
const FLOOR_FADE_IN_S := 0.5 ## fondu de sortie du carton vers le jeu
const FLOOR_CARD_SKIP_AFTER_S := 0.8 ## le carton peut être passé (toucher, Entrée, A) après ce délai
const FLOOR_ARRIVAL_INVULN_S := 1.5 ## protection à l arrivée sur le nouvel étage (= reprise de pause)
const UI_EXIT_HOLD_S := 0.6 ## maintien d'« interagir » exigé pour partir par le téléporteur (docs/ux/Audit_Choix.md P4)
## Ressources de kit au sol (GroundPickup, Audit_Choix P12) : clignotement pendant la dernière seconde, sous 3 flashs/s.
const PICKUP_EXPIRE_WARN_S := 1.0
const PICKUP_EXPIRE_BLINK_HZ := 2.5
const PICKUP_EXPIRE_ALPHA_MIN := 0.35
