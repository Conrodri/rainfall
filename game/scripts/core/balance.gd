extends Node
## Formules de docs/Maths_Scaling.md (v3, §14 Alignement RoR2 pour difficulté, director, monstres, boss, économie, niveau).
## Fonctions pures : aucun état. Tout chiffre d'équilibrage du jeu passe par ici.

const UNIT_PX := 64.0 # 1 u = taille du joueur

# Foudre en chaîne (Éclair en bouteille, Ukulele RoR2) : rayon de saut entre deux cibles.
const CHAIN_LIGHTNING_RANGE_U := 5.0
const CHAIN_LIGHTNING_RANGE_STACK_U := 0.5 ## par exemplaire au-delà du premier

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
## Audit monstres simples (29/10/2026, docs/Audit_Monstres_Simples_2026-10-29.md) : moins de corps, plus de poids.
## Pente 0,55 (était 0,4) : le coût moyen monte plus vite avec le coeff, donc plus de tireurs/brutes par crédit.
const DIRECTOR_MEAN_COST_SLOPE := 0.55
const TIER_COST := {1: 1.0, 2: 5.0, 3: 16.0} ## était 1 / 4 / 12 ; la prime suit le coût (PV par crédit presque inchangé)
## T2 vers 70 s (retour joueur : mort avant 2 min) ; T3 à D 1,6 (première brute vers 4 min, pendant la charge du pilier).
const TIER_MIN_D := {1: 0.0, 2: 1.35, 3: 1.6}
const T3_RAMP_D := 1.0 ## T3 atteint son poids plein 1 point de D après son apparition
const T3_SHARE := 0.5 ## p3 = 0,5 × p2 à pleine rampe (était 0,4, constante locale du director)
const LEAPER_SHARE := 0.4 ## part des tier 2 qui sont des bondisseurs (le reste : tireurs)
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
const WAVE_LEADER_BASE := 0.20 ## chance d'une élite en tête : base + 2 × elite_chance(D), plafonnée
const WAVE_LEADER_MAX := 0.6
const WAVE_SIDE_SPREAD := 0.45 ## part du bord d'écran occupée par la vague
const WAVE_ANNOUNCE_S := 1.5 ## flèche au bord de l'écran, côté de la vague

# Monstres : [PV base, dégâts base, vitesse base u/s] au niveau ambiant 1.
# Vitesses -20 % par rapport au doc (retour joueur : « ils courent un peu trop vite »).
# Alignement RoR2 : PV/dégâts de base calibrés (remplacent 20/6, 80/12, 300/30) ; la prime suit TIER_COST
# (clé « reward » et ELITE_REWARD remplacés : or et XP ∝ coût director, comme RoR2).
const TIER_STATS := {
	1: {"hp": 18.0, "dmg": 5.0, "speed": 2.0},
	2: {"hp": 90.0, "dmg": 10.0, "speed": 2.0}, ## 80 avant l'audit du 29/10/2026
	3: {"hp": 360.0, "dmg": 24.0, "speed": 1.6}, ## 300 avant l'audit du 29/10/2026
}
## Croissance RoR2 par niveau ambiant (niveau = 1 + (coeff - 1) / 0,33) : +30 % PV (boss seulement, gelés), +20 % dégâts.
const LEVEL_HP_GROWTH := 0.30
## Croissance des PV des monstres simples par niveau ambiant et par tier (audit 29/10/2026) : les tiers lourds
## montent plus vite que l'essaim, qui reste fauché en 1-2 coups. Les boss restent sur LEVEL_HP_GROWTH.
const MONSTER_HP_GROWTH := {1: 0.33, 2: 0.36, 3: 0.40}
const LEVEL_DMG_GROWTH := 0.20
const ELITE_HP := 4.0 ## RoR2 élites tier 1 (remplace 3,5)
const ELITE_DMG := 2.0 ## (remplace 1,5)
## Prime des kills (RoR2 : or = 2 × coeff × coût × R, XP = coeff × coût × R ; R = 0,2 pour les directors
## continus). Calibré par simulation (docs/Maths_Scaling.md §14) : 0,235.
const REWARD_MULT := 0.235
## Explosions proportionnelles aux PV du mort (Tempête de braises, Peste vivante) : les PV servant de base sont
## plafonnés à BLAST_HP_CAP_HITS coups de dégât de base du joueur (monstre ordinaire ; les boss : 40, voir ItemEffects),
## et la file d'explosions en attente est bornée (chaînes de morts sur mobile).
const BLAST_HP_CAP_HITS := 12.0
const BLAST_QUEUE_MAX := 48
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
const SWARM_BITE_WINDUP_S := 0.35 ## essaim : armement de la morsure (tête en arrière) avant le coup ; au plus une morsure par CONTACT_INTERVAL
const SWARM_BITE_REACH_U := 0.25 ## essaim : allonge au-delà du contact ; la morsure s'arme à cette distance et manque si le joueur en sort
## Cadavres des monstres de base (anim `death_<e|s|w|n>` des sprites v2) : le monstre joue sa mort puis reste
## au sol, puis s'efface en fondu. Pool plafonné par palier de qualité (Bas / Moyen / Haut), réutilisé sans allocation.
const CORPSE_MAX_BY_TIER: Array[int] = [12, 24, 40]
const CORPSE_HOLD_S := 5.0 ## temps au sol (dernière frame) avant le fondu
const CORPSE_FADE_S := 1.5 ## durée du fondu
## Lisibilité des attaques (passe du 28/10/2026) : rendu seulement, aucun effet sur les dégâts ni les durées.
const TELEGRAPH_FX_MAX := 40 ## monstres simultanément animés par l'armement / l'impact (écrasement, clignotement)
const TELEGRAPH_GROUND_MAX := 14 ## télégraphes au sol de monstres de base (cône de brute, onde, course) affichés en même temps ; au-delà l'attaque est retardée de TELEGRAPH_RETRY_S
const TELEGRAPH_RETRY_S := 0.35
const ARM_SQUASH := 0.08 ## armement : le corps s'écrase de 8 % le long de l'axe du coup (et s'élargit de moitié moins)
const ARM_IN_S := 0.14 ## durée de l'écrasement
const IMPACT_STRETCH := 0.14 ## impact : étirement de 14 % le long de l'axe du coup
const IMPACT_S := 0.16 ## durée de l'impact (retour à l'échelle, éclat chaud)
const ARM_BLINK_HZ := 7.0 ## clignotement de la teinte d'armement (monstres armant >= 0,5 s ; coupé si flashs réduits)
const SWARM_BITE_RECOIL_U := 0.25 ## petit recul après la morsure (lisibilité du coup, évite de coller le joueur)
## Passe télégraphes (29/10/2026, docs/Audit_Telegraphes_2026-10-29.md) : rendu seulement, dégâts / PV / durées inchangés.
## Hiérarchie : un coup au sol n'a de zone dessinée que s'il est lourd ou mortel ; les coups légers (coef <= TELEGRAPH_LIGHT_MAX_COEF)
## sont lus par l'anticipation du corps. Le réglage « Télégraphes renforcés » rend tout, comme avant.
const TELEGRAPH_LIGHT_MAX_COEF := 1.1 ## coup de boss / mini-boss : coef de dégâts <= à ça = léger (pas de zone au sol)
const TELEGRAPH_DEADLY_MIN_COEF := 2.0 ## coef >= à ça = mortel (remplissage plus dense)
const TELEGRAPH_LITE_BASE_ALPHA := 0.035 ## aplat de fond de la zone (presque invisible : seul le bord dit où)
const TELEGRAPH_LITE_FILL_END := 0.20 ## alpha du remplissage à l'impact, coup lourd
const TELEGRAPH_LITE_FILL_END_DEADLY := 0.30 ## idem, coup mortel
const TELEGRAPH_LITE_FILL_START := 0.10 ## part de l'alpha final au début de l'armement (le remplissage monte, en courbe douce)
const TELEGRAPH_LITE_OUTER_PX := 4.0 ## bord fin : trait sombre (lisible sur tous les sols) ...
const TELEGRAPH_LITE_INNER_PX := 1.6 ## ... et liseré clair net par-dessus
const TELEGRAPH_BIOME_MIX := 0.35 ## part de la teinte du biome mêlée au rouge d'alerte (nulle en mode daltonien)
const TELEGRAPH_BIOME_TINT := {&"terrasses": Color(1.0, 0.55, 0.12), &"foret": Color(0.95, 0.22, 0.42),
	&"cite": Color(1.0, 0.42, 0.08), &"cryptes": Color(0.72, 0.20, 0.80), &"source": Color(0.98, 0.80, 0.30)}
## Anticipation du corps (visuelle, le coup tombe au même instant) : dans les ANTICIP_HOLD_S avant l'impact le corps s'écrase
## davantage (ANTICIP_EXTRA × ARM_SQUASH), la pose « gèle » (la fente d'un boss part en courbe lente puis claque) et un
## bref éclat d'émission monte (ANTICIP_FLASH).
const ANTICIP_HOLD_S := 0.18
const ANTICIP_EXTRA := 1.2
const ANTICIP_FLASH := 0.3

# Boss
## Alignement RoR2 : PV = base × niveau ambiant (+30 %/niv) × √coeff (le téléporteur RoR2 dépense 600·√coeff)
## × BOSS_STAGE_K^(étage-1) : +20 % de PV par étage pour suivre les ~10 objets que le joueur gagne à chaque étage
## (audit docs/Audit_PV_Boss_2026-10-28.md, option A, décision du joueur du 28/10 ; était 0,95, qui retirait des PV
## et faisait tomber le TTK des boss d'étage de 63 à 33 s entre les étages 1 et 4). Vaut aussi pour les mini-boss.
## Base étage 3300 (était 3000) : boss d'étage ≈ 65-75 s en Moyen, build moyen, à tous les étages.
const BOSS_BASE_HP := {&"mini": 1000.0, &"etage": 3300.0}
const BOSS_BASE_DMG := {&"mini": 20.0, &"etage": 28.0} ## +20 %/niveau ambiant (remplace 25/35 × (1 + 0,3 (D-1)))
const BOSS_STAGE_K := 1.20
## Boss final (la Source) : PV = boss d'étage de l'étage 5 × ce facteur (était 2,0 dans data/floors.json).
## TTK visé 120-150 s en Moyen, build moyen (décision du joueur du 28/10) : 1,55 → ≈ 135 s (audit §8 : 1,2 → 105 s,
## 1,5 → 130 s, 2,0 → 175 s). Lu par StageManager (Pillar.setup_final) et par TestTools.final_hp_mult().
const FINAL_BOSS_HP_MULT := 1.55
## PV des boss d'étage, des raids et du boss final selon le mode (mini-boss non concernés). Difficile 0,85 : sans lui,
## les boss d'étage 2-4 du Difficile duraient 101-107 s, au-delà de l'enrage (90 s) ; avec, ≈ 86-91 s (audit §6).
## Le Difficile reste plus dangereux (dégâts au niveau ambiant) sans devenir une guerre d'usure. Appliqué par
## Enemy.activate_boss (une seule fois ; Pillar et TestTools ne le réappliquent pas).
const BOSS_HP_MODE_MULT := {&"facile": 1.0, &"moyen": 1.0, &"difficile": 0.85}
## Durée de charge du gros pilier (s, n'avance que joueur dans la zone ; était 90 s codé dans pillar.gd). Le pilier
## n'est terminé qu'avec la charge pleine ET le boss mort : avec des boss d'étage de ≈ 70 s, c'est le boss qui fixe la fin.
const PILLAR_CHARGE_S := 60.0
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
## Attendre sous bouclier coûte (retour joueur 27/10/2026 : « il suffit d'attendre »). Garde-fou anti-blocage :
## le bouclier finit par tomber SANS fenêtre, mais après une sanction (soin du boss de cette part de ses PV max +
## salve). Tant que rien ne progresse, une impulsion de pression part toutes les `stall_every_s`
## (BossShield.stall_pulse), la n-ième impulsion portant n zones.
const RAID_STALL_HEAL_FRAC := 0.10

## Pression des boss d'étage raid, v2 du 27/10/2026 (retour joueur : « trop simples à esquiver, quasi aucun impact »),
## SANS toucher aux dégâts (BOSS_ATTACK_COEF, RAID_*_COEF, BOSS_HP_MULT inchangés) : recharges et armements plus
## courts (jamais sous windup_floor_s), zones plus grandes et plus nombreuses, sorts qui visent où le joueur VA
## (lead_s), superpositions. Tables [P1, P2, P3] sauf mention. Lues par DrownedIdolBrain / FloodGunnerBrain via
## boss_pressure(id, clé). Valeurs d'avant : docs/Design_Boss_Raid.md §2.1 / §2.2 (« v2 27/10 »). Roi de sel : docs/Design_Boss_Raid.md §2.3 (« v2 27/10 »).
const BOSS_PRESSURE := {
	&"drowned_idol": {
		"auto_cd": [1.2, 1.1, 0.9], ## Paume (avant 1,8 / 1,7 / 1,6)
		"spell_cd": [3.0, 2.6, 1.6], ## écart entre deux sorts (avant 4,8 / 4,3 / 3,8)
		"palm_range_u": 4.5, ## avant 3,0
		"palm_half": 1.05, ## demi-angle 60° = cône de 120° (avant 0,785 = 90°)
		"windup_heavy_mult": 0.7, "windup_spell_mult": 0.75, "windup_floor_s": 0.65, ## armements ×, plancher
		"ring_thick_u": 1.0, ## épaisseur d'un anneau du Carillon (avant 0,8)
		"ring_step_s": 0.35, ## écart entre deux anneaux (avant 0,5)
		"ring_radii": [[2.5, 4.5, 6.5, 8.5], [2.0, 3.8, 5.6, 7.4, 9.2], [2.0, 3.8, 5.6, 7.4, 9.2]], ## avant 3 / 4 anneaux
		"ring_jitter_u": 0.6, ## chaque Carillon décale tous ses anneaux de ±0,6 u : le couloir de la fois d'avant ne sert plus
		"chaplet_count": 7, "spiral_count": 9, ## avant 5 / 6
		"chaplet_r_u": 1.3, ## avant 1,0
		"chaplet_step_s": 0.18, ## avant 0,25
		"chaplet_lines": [1, 3, 3], ## files de cercles (côtés à ±0,38 rad en P2/P3)
		"lead_s": 0.8, ## le dernier cercle vise où le joueur sera dans ce délai (vitesse lissée)
		"cycles": [[0, 1, 0, 1], [0, 3, 2, 1, 0, 3, 1], [3, 4, 2, 3, 4]], ## ordre des sorts : Spell.CARILLON 0, CHAPLET 1, DIKES 2, NORIA 3, SPIRAL 4
		"noria_count": [1, 2, 3], ## avant 1 / 1 / 2
		"noria_turn_s": 1.5, "noria_sweep_rad": 4.71, ## pale de 270° en 1,5 s (avant 180° en 2,0 s)
		"noria_blade_u": 9.0, "noria_width_u": 1.8, ## avant 8,0 x 1,5
		"noria_tick_s": 0.4, ## avant 0,5
		"ring_every_s": [0.0, 4.0, 1.1], ## anneau continu (avant P3 seule, 2,5)
		"ring_wind_s": 0.75, "ring_sweep_s": 1.0, ## avant 0,9 / 1,2
		"shield_slow_spell_s": 2.8, ## Chapelet sous bouclier (avant 4,0)
		"shield_backstop_s": 45.0, ## avant 25,0 : à l'échéance, soin + salve d'anneaux puis chute SANS fenêtre
		"shield_stall_every_s": 8.0, ## impulsion d'anneaux tant que rien ne progresse
	},
	&"flood_gunner": {
		"auto_cd": 0.9, ## Culasse (avant 2,0)
		"windup_min_s": 0.7, ## avant 0,8
		"breech_speed_u": 13.0, ## avant 11,0
		"breech_shots": [1, 2, 3], ## rivets par Culasse en éventail (avant 1 / 1 / 2)
		"breech_split": 0.2, ## écart d'éventail, rad (avant 0,262 en P3)
		"lead_s": 1.0, ## la Culasse (armement + vol) et l'Obus visent où le joueur sera
		"plant_count": [2, 3, 2], ## pylônes par plantage (avant 3 / 4 / 3)
		"pylon_life_s": 11.0, ## avant 14,0
		"plant_settle_s": 1.2, ## avant 2,5
		"p3_plant_every_s": 7.0, ## avant 10,0
		"volley_cd": 3.5, "volley_first_s": 1.2, ## avant 14,0 / 2,0
		"volley_telegraph_s": 0.9, ## avant 1,5
		"volley_rate": [32.0, 36.0, 36.0], ## avant 24 projectiles/s partout
		"volley_duration_s": [7.0, 8.0, 100000.0], ## avant 5 / 6
		"volley_arc_deg": [140.0, 60.0, 60.0], ## avant 120 / 60 / 60
		"volley_cones": [1, 3, 3], ## avant 1 / 2 / 2
		"volley_turn_deg_s": [0.0, 60.0, 30.0], ## avant 0 / 45 / 20
		"volley_speed_u": [10.0, 10.5, 10.5], ## avant 9
		"volley_sweep_deg": 40.0, "volley_sweep_period_s": 4.0, ## balayage P1 (avant ±30° sur 5 s)
		"reload_every_s": 10.0, "reload_s": 1.5, ## P3 (avant 8 / 2)
		"shell_r_u": 3.6, ## avant 3,0
		"shell_windup_s": 0.9, ## avant 1,2
		"shell_every_s": [8.0, 4.0, 3.0], ## avant 0 (aucun) / 8 / 5
		"shell_first_s": 2.5, ## avant 3,5 (P1 : +2,5 s ; l'Obus de P1 est nouveau)
		"shell_extra": [0, 0, 1], ## cercles d'Obus supplémentaires (aléatoires autour du joueur)
		"shield_breech_cd": 1.6, ## Culasse sous bouclier (avant 3,0)
		"shield_shell_every_s": 5.5, ## Obus aussi sous bouclier (avant : aucun)
		"shield_backstop_s": 45.0, ## avant 25,0
		"shield_stall_every_s": 7.0, ## salve de vapeur tant qu'aucun soutier ne tombe
		"burst_r_u": 4.5, "burst_windup_s": 1.2, ## salve de vapeur (dégâts = coef de l'Obus)
		"add_walk_u": 2.4, ## avant 2,0
		"add_ring_u": 11.0, ## avant 12,0
		"add_heal_cap_frac": 0.30, ## avant 0,20
	},
	&"salt_king": {
		"auto_cd": 1.17, ## Sceptre (avant 1,8)
		"auto_windup_mult": 0.8, "auto_windup_floor_s": 0.45, ## armement du Sceptre (table BossPace x, plancher)
		"spell_windup_mult": 0.8, "spell_windup_floor_s": 0.6, ## armements des sorts (Procession, Stèles, Édit)
		"proc_cd": [9.0, 8.0, 0.0], ## Procession (avant 16 / 16 ; x0,65 = 10,4 ne suffisait pas aux mesures)
		"auto_lead_s": 0.45, ## le Sceptre vise où le joueur sera à l'impact (vitesse lissée)
		"proc_deg": [80.0, 52.0, 52.0], ## nef sèche (avant 90 / 60 / 60) ; vitesses de rotation inchangées
		"stele_cd": [7.2, 5.9, 6.0], ## Stèles (avant 11 / 9 / 6) ; P3 inchangé : plus de stèles debout abritent le joueur de la marée permanente (mesuré)
		"stele_ring": [4, 6, 4], ## stèles posées autour du joueur (inchangé)
		"stele_lead": [1, 1, 1], ## +1 stèle par phase, sur la position anticipée du joueur (avant 4 / 6 / 4 au total)
		"stele_hit_r_u": 1.125, ## rayon de la zone de coup d'une stèle (avant 0,9 : +25 %)
		"stele_rise_s": 0.8, ## levée / télégraphe (avant 1,0)
		"lead_s": 0.9, ## la stèle anticipée vise où le joueur sera dans ce délai (vitesse lissée)
		"edict_cd": 2.6, ## Édit (avant 4,0)
		"edict_w_u": 1.3, ## épaisseur de l'anneau (avant 1,0)
		"edict_windup_floor_s": 0.6,
		"first_stele_s": 4.0, "first_proc_s": 3.0, ## premières échéances (avant 6,0 / 3,0)
		"shield_stele_every_s": 3.3, ## stèles sous bouclier (avant 5,0)
		"tears_every_s": 5.2, ## Larmes de sel sous bouclier (avant 8,0)
		"shield_backstop_s": 45.0, ## avant 20,0 : à l'échéance, soin + salve de stèles puis chute SANS fenêtre
		"shield_stall_every_s": 7.5, ## salve de stèles tant que rien ne progresse (n-ième impulsion = n stèles, 3 au plus)
		"stall_max": 3,
		"stall_rise_s": 1.0, ## levée des stèles de punition
	},
}


## Réglage de pression d'un boss (BOSS_PRESSURE[boss_id][key]) ; valeur d'une table par phase : `pressure_at`.
func boss_pressure(boss_id: StringName, key: String) -> Variant:
	return (BOSS_PRESSURE[boss_id] as Dictionary)[key]


## Entrée de phase `phase` (1-3) d'une table par phase de BOSS_PRESSURE.
func pressure_at(boss_id: StringName, key: String, phase: int) -> Variant:
	var t: Array = (BOSS_PRESSURE[boss_id] as Dictionary)[key]
	return t[clampi(phase - 1, 0, t.size() - 1)]


## Multiplicateur de PV d'un boss façon raid (BOSS_HP_MULT), 1 sinon.
func boss_hp_mult(boss_id: StringName) -> float:
	return float(BOSS_HP_MULT.get(boss_id, 1.0))


## Multiplicateur de PV d'un boss selon le mode de la partie (BOSS_HP_MODE_MULT) ; 1 pour les mini-boss et les modes inconnus.
func boss_hp_mode_mult(kind: StringName, mode: StringName) -> float:
	if kind == &"mini":
		return 1.0
	return float(BOSS_HP_MODE_MULT.get(mode, 1.0))


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
	## Audit des objets du 28/10/2026 : Cœur de glace plafonné à +95 % (5 exemplaires),
	## Œil du prédateur à +150 % de dégâts critiques (critique ×3,5 au plus).
	"slowed_target_damage_add": 0.95, "crit_mult_add": 1.5,
}
## Roulade (esquive d'Ardent) : DODGE_DISTANCE_U en DODGE_DURATION_S, invulnérable pendant, recharge fixe.
const DODGE_DISTANCE_U := 3.0
const DODGE_DURATION_S := 0.25
const DODGE_COOLDOWN_S := 3.0
const COOLDOWN_FLOOR := 0.35 ## recharge minimale, fraction de la base (audit des objets 28/10/2026 : 0,25 -> 0,35)
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
	## Reliquaire de gardien de salle secrète (29/10/2026) : jamais Commun, Rare 12 % (6 × un petit coffre, un peu sous le
	## coffre de boss à 15 %), pas de Légendaire (le coffre de boss n'en donne pas : la récompense reste sous celui du boss).
	## Gratuit, sans relance spéciale (relances du d100 = Chance, comme partout), aucune pitié (RoR2 n'en a pas).
	&"guardian": {&"peu_commun": 88, &"rare": 12},
}


## Coefficient de difficulté RoR2 (solo) ; `d` = MODES[mode]. Pas d'accélération « endless » (RoR2 n'en a pas).
func difficulty(t_s: float, stage: int, d: float = 1.0) -> float:
	return (1.0 + t_s / 60.0 * TIME_SLOPE * d * TIME_COMPRESSION) * pow(K_STAGE, stage - 1)


## Paliers de difficulté (seuils resserrés pour l'échelle RoR2). D atteint ≈ 6,9 à 19,5 min en Moyen (fin d'étage 5) :
## le palier Cataclysme (D ≥ 3,0) est franchi vers l'étage 3.
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


const ELITE_CHANCE_SLOPE := 0.06 ## était 0,05 (audit 29/10/2026)
const ELITE_CHANCE_MAX := 0.25


func elite_chance(D: float) -> float:
	return clampf(ELITE_CHANCE_SLOPE * (D - 1.0), 0.0, ELITE_CHANCE_MAX)


## Chance qu'une vague du Director soit menée par une élite.
func wave_leader_chance(D: float) -> float:
	return clampf(WAVE_LEADER_BASE + 2.0 * elite_chance(D), 0.0, WAVE_LEADER_MAX)


func elite_affix_count(D: float) -> int:
	return 2 if D >= 4.0 else 1


# --- Monstres
## Remplacé : base × D^1,15 (PV) et base × (1 + 0,3 (D-1)) (dégâts). Désormais par niveau ambiant (RoR2).
## `tier` : 1 essaim, 2 tireur/bondisseur, 3 brute (croissance MONSTER_HP_GROWTH[tier]).
func monster_hp(base: float, D: float, tier: int) -> float:
	return base * (1.0 + float(MONSTER_HP_GROWTH.get(tier, LEVEL_HP_GROWTH)) * (monster_level(D) - 1))


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
const KB_MASS := {1: 1.0, 2: 0.7, 3: 0.25} ## essaim > tireur > brute
const KB_ELITE_MULT := 0.6
const KB_BOSS_MULT := {&"mini": 0.08, &"etage": 0.04} ## presque immunisés (les boss ne gèlent pas)
const HIT_FLASH_MIN_S := 0.06
const HIT_FLASH_MAX_S := 0.08

# --- Rythme des sorts (docs/Design_Feel_Sorts.md) : cancel, buffer, poids du lancer côté joueur
const INPUT_BUFFER_S := 0.133 ## 8 f : un appui de sort 2-4 ou d'esquive pendant une fenêtre non annulable part à la première frame permise
## Frames (60 Hz) après l'impact avant qu'un geste puisse en couper un autre (docs/Design_Feel_Sorts.md §3.1).
const CANCEL_AFTER_IMPACT_F := {&"auto": 1, &"spell": 4, &"ult_by_spell": 12, &"ult_by_dodge": 6, &"spell_by_dodge": 2, &"ult_by_ult": 12}
const CAST_SHAKE_PX := {&"spell": 2.0, &"heavy": 3.5, &"ult": 6.0}
const CAST_SHAKE_HZ := {&"spell": 22.0, &"heavy": 20.0, &"ult": 18.0}
const CAST_SHAKE_S := {&"spell": 0.15, &"heavy": 0.2, &"ult": 0.25}
const CAST_SHAKE_MIN_HITS := 3 ## sorts 2-3 : secousse seulement à partir de 3 touchés (ou un boss)
const CAST_FEEL_WINDOW_S := 0.12 ## les coups portés dans ce délai après la frame d'impact comptent pour le poids du lancer (pas les ticks de zone)
const CAST_KICK_PX := 5.0
const ULT_KICK_PX := 9.0
const ULT_SQUASH := 0.08 ## tassement d'impact de l'ultime (échelle)
const ULT_SQUASH_F := 4 ## durée en frames
const ULT_GLOBAL_FREEZE_S := 0.05 ## gel global (3 f) à l'impact d'un ultime ou d'un coup f >= 0,85
const ULT_GLOBAL_FREEZE_REARM_S := 1.0
const ULT_GLOBAL_FREEZE_HITS := 8 ## ou >= 8 monstres touchés d'un coup
const COMBO_SEMITONES := 2.0 ## coup de combo : son lourd, +2 demi-tons
const COMBO_SOUND_GAP_S := 0.05
const AIM_MARKED_WEIGHT := 1.5 ## aide de visée mobile : poids d'un monstre marqué / trempé dans densest_point
const COMBO_PULSE_PERIOD_S := 0.6 ## pulsation du bouton de sort quand `kit.combo_ready(slot)`


## Frames de gel du corps du joueur à l'impact d'un sort selon la force f du coup (0 : léger).
func player_hitstop_frames(f: float, is_crit: bool) -> int:
	var n := 0
	if f >= 0.85:
		n = 4
	elif f >= 0.6:
		n = 3
	elif f >= 0.35:
		n = 2
	if n > 0 and is_crit:
		n += 1
	return n


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


## Hâte de recharge (audit des objets du 28/10/2026, docs/Maths_Scaling.md §9) : les hâtes de tous les
## objets s'additionnent (H) et la recharge est divisée par (1 + H), donc la cadence croît linéairement.
## Résultat borné à [COOLDOWN_FLOOR, 1] ; c'est le `cooldown_mult` produit par ItemStats.
func haste_cooldown_mult(haste_sum: float) -> float:
	return clampf(1.0 / (1.0 + maxf(haste_sum, 0.0)), COOLDOWN_FLOOR, 1.0)


## Recharge effective : base × cd_mult (1 = neutre, issu de la hâte des objets), plancher COOLDOWN_FLOOR de la base.
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


## Gardiens des salles secrètes (brutes élites nommées) : leur prime d'élite est multipliée par GUARDIAN_GOLD_MULT
## (2 = prime d'élite doublée ; l'XP reste celle d'une élite).
const GUARDIAN_GOLD_MULT := 2.0

## Fréquence des secrets à plaques (joueur, 29/10/2026) : au plus un par run, SECRET_RUN_CHANCE de chances qu'elle en
## ait un, sur un étage tiré entre 1 et SECRET_MAX_FLOOR parmi ceux dont la carte tirée en porte un (jamais l'étage 5).
const SECRET_RUN_CHANCE := 1.0 / 3.0
const SECRET_MAX_FLOOR := 4
## Déclencheurs d'ouverture, tirés (seedé) pour chaque secret : plaques de pression, levier caché (interagir), mur fissuré
## (dégâts de sorts du joueur), pilier éteint (rester dans son cercle). Salle, porte, gardiens et reliquaires identiques.
const SECRET_TRIGGERS: Array[StringName] = [&"plates", &"lever", &"wall", &"pillar"]
const SECRET_LEVER_RANGE_U := 1.5 ## portée d'« interagir » du levier
const SECRET_WALL_SECONDS := 3.5 ## mur fissuré : secondes de dégâts de référence pour céder (~3-4 s demandées)
const SECRET_WALL_COEF_PER_S := 3.0 ## dégâts de référence par seconde, en coefficients de sort (≈ auto 1,5/s + sorts à recharge)
const SECRET_PILLAR_CHARGE_S := 6.0 ## pilier éteint : secondes cumulées dans le cercle (les gros piliers de boss : PILLAR_CHARGE_S)
const SECRET_PILLAR_RADIUS_U := 3.0 ## rayon du cercle du pilier éteint


## Or SUPPLÉMENTAIRE versé à la mort d'un gardien (en plus de la prime d'élite normale du PickupManager).
func guardian_bonus_gold(D: float, tier: int) -> float:
	return (GUARDIAN_GOLD_MULT - 1.0) * monster_gold(D, monster_cost(tier, true))


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


# --- Lisibilité des mini-boss : plafond de brillance du corps (retour joueur 28/10/2026, Cryptes noyées trop lumineuses) ---
## Le gain de corps des mini-boss (data/minibosses.json body_gain × biome_gain) éclaircit les sprites sombres. Sur un sprite
## clair (sel, os) il grille : le gain est plafonné pour que la luminance moyenne du sprite × gain reste <= cette valeur
## (data/boss_albedo_lum.json, art/tools/measure_emission_mass.py). Les sprites sombres gardent leur gain complet.
const MINI_BODY_MEAN_MAX := 0.65


# --- Défi du jour (méta hors ligne, scripts/meta/daily_challenge.gd) ---
## Récompense modeste, une seule fois par jour (le premier essai compté) : base + palier de série (plafonné) + bonus de victoire.
## Une run normale rapporte ~15-45 rubis : le défi du jour reste un petit bonus, pas une ferme à rubis.
const DAILY_RUBIES_BASE := 10
const DAILY_RUBIES_STREAK_STEP := 1 ## par jour de série consécutif au-delà du premier
const DAILY_RUBIES_STREAK_CAP := 7 ## jours de série pris en compte
const DAILY_RUBIES_WIN := 10
## Un abandon avant ce temps actif (s) ne compte pas comme un essai du défi du jour.
const DAILY_MIN_ABANDON_S := 60.0


func daily_rubies(streak: int, victory: bool) -> int:
	var s := clampi(streak, 1, DAILY_RUBIES_STREAK_CAP)
	return DAILY_RUBIES_BASE + DAILY_RUBIES_STREAK_STEP * (s - 1) + (DAILY_RUBIES_WIN if victory else 0)
