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
const ZONE_SPAWN_MULT := {&"mini": 1.5, &"etage": 2.33, &"epreuve": 1.5} ## &"epreuve" : zone mobile des épreuves (prototype, EPREUVES_ENABLED)
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
const TELEGRAPH_BIOME_TINT := {&"terrasses": Color(1.0, 0.55, 0.12), &"foret": Color(1.0, 0.48, 0.18),
	&"cite": Color(1.0, 0.42, 0.08), &"cryptes": Color(0.72, 0.20, 0.80), &"source": Color(0.98, 0.80, 0.30)}
## --- Coups en V (retour joueur 31/10/2026) : le trou central est fermé par un suivi télégraphié, chaque branche laisse une trace ---
const V_FOLLOWUP_DELAY_S := 0.5 ## délai entre les branches et le coup central (visée figée du lâcher d'eau)
const V_TRACE_LIFE_S := 2.5 ## durée d'une trace de branche, comptée à partir de la fin du trajet de la vague
const V_TRACE_DMG_COEF := 0.15 ## dégâts par tick de trace = dégâts du boss × ce coef (faible)
const V_TRACE_TICK_S := 0.5
const V_TRACE_SLOW_MULT := 0.7 ## ralentissement dans la trace (Player.apply_slow : -30 %)
const V_TRACE_HALF_W_U := 1.7 ## demi-largeur de la zone (u)
const V_TRACE_MAX := 4 ## traces actives max par boss (mobile) : la plus ancienne se referme


## Angles (rad, centrés sur la visée) d'un éventail de n branches réparties sur `spread` : toujours une branche
## au centre (n pair -> n + 1 branches), donc jamais de trou au point visé. Aide commune des coups en V.
static func v_fan_angles(n: int, spread: float) -> Array[float]:
	var m := maxi(n, 1)
	if m > 1 and m % 2 == 0:
		m += 1
	var out: Array[float] = []
	for i in m:
		out.append(0.0 if m == 1 else -spread * 0.5 + spread * float(i) / float(m - 1))
	return out
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
## Audit runs complètes 31/10/2026 (docs/Audit_Runs_Completes_2026-10-31.md) : 1,20 -> 1,0 (neutre, gardé comme levier).
## Avec 1,20 le rapport PV / DPS du joueur passait de ~70 s (étages 1-3) à 110-200 s à l'étage 4 et au boss final ;
## à 1,12 puis 1,05 l'étage 4 restait 1,8 puis 1,4 × l'étage 1 en rencontre ciblée (rythme visé de 19 min). Le niveau
## ambiant et √coeff suffisent à suivre les objets.
const BOSS_STAGE_K := 1.0
## Part du DPS qui touche réellement le boss (audit du 31/10/2026) : les PV ci-dessus visaient 65-75 s avec 100 % des
## dégâts sur le boss ; en jeu (monstres de la charge, zones, procs) seuls 35-50 % le touchent. Facteur de PV calibré
## pour les cibles AVEC monstres (médiane de 6 personnages, rencontres ciblées au rythme visé) : mini-boss 21-30 s,
## boss d'étage 65-75 s, boss final 120-150 s.
const BOSS_FOCUS_HP_MULT := {&"mini": 0.55, &"etage": 0.5}
## Boss final (la Source) : PV = boss d'étage de l'étage 5 × ce facteur (était 2,0 dans data/floors.json).
## TTK visé 120-150 s en Moyen, build moyen (décision du joueur du 28/10) : 1,55 → ≈ 135 s (audit §8 : 1,2 → 105 s,
## 1,5 → 130 s, 2,0 → 175 s). Lu par StageManager (Pillar.setup_final) et par TestTools.final_hp_mult().
## Audit runs complètes 31/10/2026 : 1,55 -> 1,35 (boss final 4 tués sur 30 en 420 s dans les runs simulées).
const FINAL_BOSS_HP_MULT := 1.35
## Priorité de ciblage automatique des boss et mini-boss (Enemy.aim_priority : distance effective ÷ ce facteur dans
## SpellCaster._nearest_enemy). Seule la visée AUTO est concernée (sort 1, sorts 2-4 sur mobile ou « Sorts automatiques »,
## repli manette au repos) ; la visée au curseur et au stick n'en tient pas compte. Audit du 31/10/2026 : sans elle, 36-50 %
## seulement des dégâts touchent le boss (monstres de la charge plus proches) ; avec 2,0 : TTK -10 à -25 %.
const BOSS_AIM_PRIORITY := 2.0
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
const BOSS_HP_MULT := {&"drowned_idol": 0.7, &"flood_gunner": 0.9, &"salt_king": 0.9} ## Idole 0,9 -> 0,7 (audit 31/10/2026 : 2,1 × le TTK médian de l'étage 1, garde-fou de bouclier de 45 s compris)
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
	## Danseur : +35 % puis +20 % par exemplaire, plafonné à +95 % (1/3/4/5/10 ex. = 35/75/95/95/95 %).
	"moving_damage_add": 0.95,
}
## Foudre en chaîne (Éclair en bouteille) : cibles maximum, quel que soit le nombre d'exemplaires (perf mobile).
const CHAIN_LIGHTNING_MAX_TARGETS := 8
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
## 10 -> 4 (joueur, 01/11/2026) : moins de « tour de map » obligatoire ; or par étage -1,5 P environ (docs/Boucle_Etage_Design.md §6).
const CAPSULES_PER_STAGE := 4
## 20 -> 40 (01/11/2026) : l'intention était de réduire le ramassage obligatoire, pas l'or total (4 × 40 = 8 × 20 anciennes).
const CAPSULE_GOLD := 40.0

# --- Boucle d'étage : Boussole de rouille, Paratonnerre dévié, coffres à vitrine, marchand de l'étage 3 ---
## Sources : docs/Ateliers_Chiffres.md §7-8 (Boussole, Paratonnerre), docs/Boucle_Etage_Design.md §2.5 (vitrine),
## demande du joueur du 01/11/2026 (marchand). Les ateliers eux-mêmes (STATION_*) sont dans leur propre bloc.
## Boussole de rouille : gratuite (elle occupe la case d'atelier de l'étage), 2 charges, petits et grands coffres, 1er tirage.
const BOUSSOLE_PRICE_P := 0.0
const BOUSSOLE_CHARGES := 2
const BOUSSOLE_TAGS_SHOWN := 6 ## 4 tags les plus présents du build + 2 tirés parmi les autres
const BOUSSOLE_TAGS_BUILD := 4
const BOUSSOLE_CHEST_KINDS: Array[StringName] = [&"petit", &"large"] ## jamais légendaire, boss, guardian
## Paratonnerre dévié : option du gros pilier, étages 2-4 seulement (étage de la boucle : 6-8 en sans fin aussi).
const PILLAR_DEVIATED_MIN_FLOOR := 2
const PILLAR_DEVIATED_MAX_FLOOR := 4
const PILLAR_DEVIATED_BOSS_HP_MULT := {2: 1.4, 3: 1.4, 4: 1.3}
## L'enrage est décalé du même facteur que les PV (sinon un boss 40 % plus long passerait 60 s enragé).
const PILLAR_DEVIATED_ENRAGE_DELAY_MULT := {2: 1.4, 3: 1.4, 4: 1.3}
const PILLAR_DEVIATED_AFFIXES: Array[StringName] = [&"burn", &"slow", &"poison"]
const PILLAR_DEVIATED_CHESTS := 2 ## coffres de boss au total ; un Présage « pas de coffre de boss » ne retire que le coffre de base
const PILLAR_DEVIATED_EXCLUDED: Array[StringName] = [&"drowned_idol", &"flood_gunner", &"salt_king", &"rain_sower"] ## raids et boss final
## Coffres à vitrine : 2 par étage parmi les petits coffres, 3 objets visibles (qualité tirée une fois, table `petit`),
## on en choisit 1, prix x1,2 d'un petit coffre. Plafond de coffres spéciaux par étage (vitrine, gardés, crue…).
const CHEST_SHOWCASE_PER_STAGE := 2
const CHEST_SHOWCASE_COUNT := 3
const CHEST_SHOWCASE_PRICE_P := 1.2
const CHEST_SPECIAL_MAX_PER_STAGE := 2
## Marchand de l'étage 3 (une fois par run) : 1 objet par rareté, prix = petit coffre de l'étage x multiplicateur.
const MERCHANT_STAGE := 3
const MERCHANT_PRICE_MULT := {&"commun": 1.5, &"peu_commun": 2.0, &"rare": 2.5, &"legendaire": 4.0}
const MERCHANT_MIN_START_DIST_U := 20.0 ## distance mini au départ et aux piliers (assouplie en repli, voir StageManager)
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


## Coefficient de difficulté RoR2 ; `d` = MODES[mode]. Pas d'accélération « endless » (RoR2 n'en a pas).
## `n` = joueurs actifs de la partie (docs/multi/Scaling_Multi.md §2.3) : départ party_factor(n), pente × n^0,2.
## n = 1 : (1 + t/60 × pente × d × 1,5) × 1,15^(étage-1), formule solo inchangée.
func difficulty(t_s: float, stage: int, d: float = 1.0, n: int = 1) -> float:
	return (party_factor(n) + t_s / 60.0 * TIME_SLOPE * d * TIME_COMPRESSION * party_time_mult(n)) * pow(K_STAGE, stage - 1)


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
## `n` : joueurs actifs (× party_credit_mult(n) = (n + 1) / 2, RoR2) ; n = 1 inchangé.
func director_credits_per_s(D: float, zone_kind: StringName = &"", n: int = 1) -> float:
	return CREDIT_K * (1.0 + 0.4 * D) * float(ZONE_SPAWN_MULT.get(zone_kind, 1.0)) * party_credit_mult(n)


## Multiplicateur de crédits en début de run : RAMP_CREDITS_MIN à 0 s, 1 à RAMP_TIME_S / 2.
func director_ramp(t_s: float) -> float:
	return clampf(RAMP_CREDITS_MIN + (1.0 - RAMP_CREDITS_MIN) * t_s / (RAMP_TIME_S * 0.5), RAMP_CREDITS_MIN, 1.0)


## Monstres vivants autorisés : RAMP_ALIVE_MIN à 0 s, RAMP_ALIVE_MAX à RAMP_TIME_S (MAX_ENEMIES reste la taille du pool).
## Coop (`n` joueurs actifs) : × (1 + PLAYER_ALIVE_SLOPE (n - 1)), au plus MAX_ENEMIES ; `low_quality` (mobile, qualité
## Basse) garde le plafond solo quel que soit n (docs/multi/Scaling_Multi.md §2.5). n = 1 : valeur solo inchangée.
func director_alive_cap(t_s: float, n: int = 1, low_quality: bool = false) -> int:
	var cap := int(lerpf(RAMP_ALIVE_MIN, RAMP_ALIVE_MAX, clampf(t_s / RAMP_TIME_S, 0.0, 1.0)))
	if n <= 1 or low_quality:
		return cap
	return mini(int(cap * (1.0 + PLAYER_ALIVE_SLOPE * (_party_n(n) - 1))), MAX_ENEMIES)


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
## `n_alive` : joueurs vivants à l'apparition du boss (figé ensuite) -> × boss_party_hp_mult(party_kind, n_alive) ;
## `party_kind` vide = `kind` (&"mini" ou &"etage") ; boss final : boss_hp(&"etage", D, s, n, &"final") × FINAL_BOSS_HP_MULT.
## n_alive = 1 : valeur solo inchangée.
func boss_hp(kind: StringName, D: float, stage: int = 1, n_alive: int = 1, party_kind: StringName = &"") -> float:
	var hp: float = BOSS_BASE_HP[kind] * float(BOSS_FOCUS_HP_MULT.get(kind, 1.0)) * (1.0 + LEVEL_HP_GROWTH * (monster_level(D) - 1)) * sqrt(D) * pow(BOSS_STAGE_K, stage - 1)
	if n_alive <= 1:
		return hp
	return hp * boss_party_hp_mult(kind if party_kind == &"" else party_kind, n_alive)


func boss_damage(kind: StringName, D: float) -> float:
	return BOSS_BASE_DMG[kind] * (1.0 + LEVEL_DMG_GROWTH * (monster_level(D) - 1))


## `delay_mult` > 1 : enrage décalé (boss dévié par le Paratonnerre : PILLAR_DEVIATED_ENRAGE_DELAY_MULT), même pente.
func boss_enrage_mult(fight_time_s: float, delay_mult: float = 1.0) -> float:
	return 1.0 + BOSS_ENRAGE_PER_S * maxf(0.0, fight_time_s - BOSS_ENRAGE_AFTER_S * maxf(delay_mult, 1.0))


## Paratonnerre dévié : étage de la boucle (1-5) -> multiplicateur de PV du boss (1.0 hors étages 2-4).
func pillar_deviated_hp_mult(floor_n: int) -> float:
	return float(PILLAR_DEVIATED_BOSS_HP_MULT.get(floor_n, 1.0))


func pillar_deviated_enrage_delay(floor_n: int) -> float:
	return float(PILLAR_DEVIATED_ENRAGE_DELAY_MULT.get(floor_n, 1.0))


## Coffres de boss à poser à la mort du gros pilier : `base` (1, ou 0 avec un Présage « pas de coffre de boss ») + le
## coffre supplémentaire du Paratonnerre dévié (PILLAR_DEVIATED_CHESTS - 1) = 2 au total en jeu normal.
func boss_chest_count(base: int, deviated: bool) -> int:
	return maxi(base, 0) + (PILLAR_DEVIATED_CHESTS - 1 if deviated else 0)


# --- Tisseuse : fils et toile ---------------------------------------------------------
## Les fils posés et la toile (phase 2+) blessent au contact en plus du ralentissement : un tic de
## WEAVER_STRAND_COEF × dégâts du boss (même échelle que BOSS_ATTACK_COEF), puis WEAVER_STRAND_TIC_S s
## d'immunité aux brins (un tic par intervalle, tous brins confondus).
const WEAVER_STRAND_COEF := 0.35
const WEAVER_STRAND_TIC_S := 0.7

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


## Or d'une capsule d'argent : CAPSULE_GOLD × coeff^1,25 (4 capsules = 160 or à coeff 1). `stage` ignoré
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


## Coop (docs/multi/Scaling_Multi.md §2.12) : `n` joueurs (bonus d'or ÷ party_factor(n)^1,25, les prix suivant pf(n)) et
## `participation` 0-1 (ruby_participation) ; n = 1 et participation = 1 : formule solo inchangée.
func run_rubies(active_minutes: float, mode: StringName, pillars_done: int, victory: bool, gold_left: float, n: int = 1, participation: float = 1.0) -> int:
	var gold_div := 500.0 if n <= 1 else 500.0 * pow(party_factor(n), 1.25)
	var gold_bonus := mini(int(gold_left / gold_div), 20)
	var base := int(floor(1.2 * active_minutes * RUBY_MODE_MULT[mode])) + 8 * pillars_done + (25 if victory else 0) + gold_bonus
	if participation >= 1.0:
		return base
	return int(floor(clampf(participation, 0.0, 1.0) * base))


# --- Forge (docs/Design_Forge.md) : objets exclusifs forgés avec un noyau d'orage ---
const CRAFT_CATALYST_PER_FLOOR_BOSS := 1 ## noyaux d'orage par boss d'étage vaincu (étages 1-4), à CHAQUE joueur
const CRAFT_CATALYST_PER_GUARDIAN := 1 ## noyaux d'orage du reliquaire `guardian` d'une zone secrète
const CRAFT_CATALYST_CAP := 2 ## noyaux portés au plus (non achetables, non copiables)
const CRAFT_CATALYST_MAX_FLOOR := 4 ## le boss de l'étage 5 (La Source) n'en donne pas
const CRAFT_MAX_STACKS := 2 ## exemplaires d'un même objet forgé (le 2e est plus faible)
const CRAFT_SPREAD_MAX_PER_S := 8 ## propagations par seconde de Sève rampante (perf mobile)
const BARRIER_CAP_PCT := 0.25 ## barrières forgées : total (bouclier du joueur compris) plafonné à 25 % des PV max
const BURN_MAX_STACKS := 10 ## cumuls de brûlure par monstre (= Enemy.DOT_MAX_STACKS)
const POISON_MAX_STACKS := 5 ## cumuls de poison transmis par Sève rampante
## Rang -> ingrédients : deux ingrédients clés portant un tag (qualité minimale `key_a_q` / `key_b_q`), puis des
## ingrédients quelconques (`fillers` : qualités minimales). Les légendaires ne sont jamais consommés.
const CRAFT_TIERS := {
	1: {"key_a_q": &"commun", "key_b_q": &"commun", "fillers": [&"commun"]},
	2: {"key_a_q": &"peu_commun", "key_b_q": &"commun", "fillers": [&"peu_commun", &"commun"]},
}
## Valeur de l'objet forgé par rapport à la somme des ingrédients (doc et tests, aucune formule en jeu).
const CRAFT_VALUE_RATIO := {1: 0.87, 2: 0.875}


# --- Ateliers (docs/Ateliers_Chiffres.md fait foi : Fondoir, Matrice, Alambic, Enclume de bronze) ---
## Tous les prix sont des multiples de P = prix d'un petit coffre de l'étage (D figé au début de l'étage) ; voir
## station_price_p(). Les poids de tirage par étage sont dans data/stations.json (somme 100 par étage).
const STATION_PER_STAGE := 1 ## ateliers par étage 1-4
const STATION_FINAL := &"enclume" ## atelier fixe de l'étage 5
const STATION_REPEAT_WEIGHT := 0.25 ## poids d'une famille d'atelier déjà sortie dans la run
const STATION_FAMILY := {&"fondoir_matrice": &"matrice", &"matrice": &"matrice", &"alambic": &"alambic", &"enclume": &"enclume", &"boussole": &"boussole"}
const STATION_COPY_EXCLUDED: Array[StringName] = [&"phenix_de_poche"] ## jamais copié par la Matrice ni l'Enclume (vies empilées)
const STATION_MIN_START_DIST_U := 20.0 ## repli sans case `E` : point libre à au moins 20 u du départ et des piliers
const FONDOIR_USES := 2
const FONDOIR_REFUND_P := {&"commun": 0.3, &"peu_commun": 0.6, &"rare": 1.2} ## remboursement de fonte en P (prix brut)
const SCRAP_CAP := 3 ## scories portées au total, toutes qualités confondues
const MATRICE_USES := 3
## Qualité de l'objet affiché selon l'étage (poids) ; l'étage 1 lit la ligne 2, l'étage 5 la ligne 4. Jamais légendaire.
const MATRICE_QUALITY_TABLE := {
	2: {&"commun": 70, &"peu_commun": 30},
	3: {&"commun": 55, &"peu_commun": 40, &"rare": 5},
	4: {&"commun": 45, &"peu_commun": 45, &"rare": 10},
}
const MATRICE_MAX_OWNED := 5 ## jamais un objet dont le joueur a déjà >= 5 exemplaires
const MATRICE_TAG_WEIGHT := 1.3 ## = LootRoller.BUILD_TAG_WEIGHT
const ALAMBIC_INPUT := 3
const ALAMBIC_USES := 2
const ALAMBIC_TAG_GUIDED := true
const ALAMBIC_ALLOW_LEGENDARY := false
const ENCLUME_PRICE_P := {&"commun": 1.25, &"peu_commun": 2.75, &"rare": 6.0}
const ENCLUME_PRICE_GROWTH := 1.4 ## prix x1,4 par usage déjà fait
const ENCLUME_USES := 3
const ENCLUME_TAG_PRICE_MULT := {&"Or": 1.5} ## surcoût d'un objet portant ce tag (copier la Faveur n'est pas une rente)


## P : prix d'un petit coffre de l'étage, D figé au début de l'étage, sans la Faveur du marchand.
func station_price_p(floor_start_d: float, stage: int) -> float:
	return chest_price(&"petit", floor_start_d, stage)


## Remboursement en or d'une fonte (0 si la qualité n'est pas fondable : légendaire). Prix brut : ni Faveur du
## marchand ni présage ne le modifient.
func fondoir_refund(quality: StringName, floor_start_d: float, stage: int) -> float:
	return float(FONDOIR_REFUND_P.get(quality, 0.0)) * station_price_p(floor_start_d, stage)


## Prix de l'exemplaire forgé par l'Enclume : ENCLUME_PRICE_P[q] x 1,4^k x P x `price_mult` (Faveur du marchand x
## présage) x surcoût de tag. `uses_done` = usages déjà faits sur cette enclume ; `tags` = tags de l'objet copié.
func enclume_price(quality: StringName, uses_done: int, floor_start_d: float, stage: int, price_mult: float = 1.0, tags: Array = []) -> float:
	var tag_mult := 1.0
	for t in tags:
		tag_mult = maxf(tag_mult, float(ENCLUME_TAG_PRICE_MULT.get(StringName(str(t)), 1.0)))
	return float(ENCLUME_PRICE_P.get(quality, 0.0)) * pow(ENCLUME_PRICE_GROWTH, uses_done) * station_price_p(floor_start_d, stage) * price_mult * tag_mult


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


# --- Présages (docs/Ateliers_Chiffres.md §9, docs/Propositions_Boucle_Interactions.md §3.1) ---
## Mutateur d'étage choisi à l'arrivée, étages 2 à 5 : une contrainte + une compensation, actif jusqu'au téléporteur.
## Les valeurs de chaque présage vivent dans data/omens.json (contrat du doc) ; ici, les règles communes.
const OMEN_FROM_FLOOR := 2 ## premier étage avec présage
const OMEN_LAST_FLOOR := 5 ## dernier étage avec présage (la Source comprise ; pas de présage en sans fin)
const OMEN_CHOICES := 2 ## cartes proposées : un présage de combat + un présage de butin (+ « Ciel clair » hors Difficile)
const OMEN_MANDATORY_MODES: Array[StringName] = [&"difficile"] ## choix obligatoire (pas de « Ciel clair »)
const OMEN_RUBIES := 2 ## rubis par présage accepté (plage 0-3 ; à trancher, §13 point 2 du doc)
const OMEN_BUDGET_TOLERANCE := 5.0 ## contrôle de test : valeur nette d'un présage dans 0 ± 5 points d'étage
const OMEN_ELITE_CHANCE_CAP := 0.40 ## plafond de la chance d'élite avec « Éveil des élites » (ELITE_CHANCE_MAX hors présage)
const OMEN_CLEAR_ID := &"ciel_clair" ## carte « aucun présage » (Facile et Moyen)


## Vrai si le choix d'un présage est obligatoire dans ce mode (pas de carte « Ciel clair »).
func omen_mandatory(mode: StringName) -> bool:
	return OMEN_MANDATORY_MODES.has(mode)


## Rubis des présages acceptés (hors « Ciel clair »).
func omen_rubies(accepted: int) -> int:
	return OMEN_RUBIES * maxi(accepted, 0)


# --- Épreuves (prototype « Les Épreuves », docs/Boucle_Etage_Refonte.md §1.3 et §5.3) ---
## À l'étage 1 (Terrasses), les deux petits piliers deviennent deux épreuves : une Escorte (barque sur un tracé) et un
## Rituel (3 relais autour d'un cœur qui pulse). Le mini-boss du plan de run apparaît à la fin de l'épreuve ; le gros
## pilier et le boss d'étage ne changent pas. DÉSACTIVÉ par défaut : sans drapeau, le jeu est strictement inchangé.
## Activation : `Balance.EPREUVES_ENABLED = true` (tests) ou l'option de lancement `-- --epreuves` (epreuves_enabled()).
var EPREUVES_ENABLED := false
const EPREUVES_ARG := "--epreuves"
const EPREUVES_OFF_ARG := "--no-epreuves" ## interrupteur de comparaison et de secours (l'emporte sur le drapeau)
var EPREUVES_PER_STAGE := 2 ## épreuves par étage 1-4 (0-2) ; le reste en petits piliers classiques (docs/Design_Epreuves.md §8)
const EPREUVE_IN_ENDLESS := true ## épreuves aussi aux étages 6-9 du mode sans fin (joueur, 07/11/2026) ; jamais à la Source
## Verbes partageables en coop : la cible « parfait » baisse de EPREUVE_TARGET_PLAYER_SLOPE par joueur en plus.
## La Poursuite n'en fait plus partie (audit 07/11/2026) : sa durée est fixée par les sauts (CHASE_POINTS x CHASE_JUMP_S).
const EPREUVE_SHARED_VERBS: Array[StringName] = [&"rituel"]
## Rubis cosmétiques (joueur, 07/11/2026) : 1 rubis par épreuve « parfaite », plafond par run (versé avec run_rubies).
const EPREUVE_RUBIES_PARFAIT := 1
const EPREUVE_RUBIES_CAP := 8
## Or versé à la fin de l'épreuve selon la note, en P (prix d'un petit coffre au début de l'étage, station_price_p).
## Calé sur l'or réel (docs/Ateliers_Chiffres.md §1.2, étage 1 : 8,0-8,8 P, bande 8-10,5 P, capsules 4 x 40 déjà
## comptées) : un petit pilier rapporte aujourd'hui ≈ 1,0 P (prime du mini-boss 0,3 + kills en zone 0,7). Une épreuve
## rapporte la note + 0,3 P de prime + les kills en zone réduits (EPREUVE_ZONE_GOLD_MULT x 0,7 P = 0,28 P).
## Audit du 07/11/2026 (le modèle ignorait l'allongement de l'étage par l'épreuve et le farm en zone) : note abaissée à
## 0,8 / 0,5 / 0,2 P et kills en zone x 0,4. Mix 25/55/20 % : note moyenne 0,515 P, +0,3 + 0,28 = 1,1 P par épreuve, soit
## ≈ +0,1 P par rapport à un petit pilier : l'étage reste dans la bande 8-10,5 P même avec le farm de la zone.
const EPREUVE_GOLD_P := {&"parfait": 0.8, &"bien": 0.5, &"fait": 0.2}
const EPREUVE_ZONE_GOLD_MULT := 0.4 ## or des kills en zone d'épreuve : l'or vient de la note, pas du farm
## Seuil « parfait » (s) par verbe ; « bien » = seuil x EPREUVE_GOOD_MULT ; « fait » au-delà. Cinq verbes
## (docs/Design_Epreuves.md).
const EPREUVE_TARGET_S := {&"escorte": 40.0, &"rituel": 35.0, &"poursuite": 40.0, &"veine": 40.0, &"tenue": 40.0}
const EPREUVE_GOOD_MULT := 1.5
const EPREUVE_BACKSTOP_S := 75.0 ## passé ce délai l'épreuve se termine d'elle-même en « fait » (jamais bloqué)
const EPREUVE_ZONE_RADIUS_U := 7.0 ## zone de monstres x ZONE_SPAWN_MULT[&"epreuve"] qui suit l'objet mobile
## Tirage des coffres (§1.1) : 3 près du tracé de l'escorte, 3 près du rituel (<= 8 u), 3 autour du gros pilier, 1 au départ.
const EPREUVE_CHEST_TRACE_U := 8.0
const EPREUVE_CHEST_ARENA_U := 12.0
const EPREUVE_CHEST_START_U := 14.0
## Aucun repère de coffre à moins de EPREUVE_CHEST_MIN_U d'un objet interactif d'épreuve (relais, cœur, cloche, source,
## autel, bornes, départ de la barque) : un coffre ouvert ne doit pas se trouver sous les pieds de l'interaction.
const EPREUVE_CHEST_MIN_U := 3.0
const EPREUVE_ARENA_MIN_CHESTS := 2 ## repères de coffre minimum à <= EPREUVE_CHEST_ARENA_U d'un gros pilier candidat (sinon écarté du tirage)
const EPREUVE_CHEST_SPLIT := {&"epreuve": 3, &"arene": 3, &"depart": 1} ## "epreuve" = par épreuve (3 chacune)
## Le gros pilier reste à cette distance (u) de l'objet d'épreuve (tracé, cœur et relais, bornes, cloche) selon le verbe.
const EPREUVE_BIG_AVOID_U := {&"escorte": 12.0, &"rituel": 12.0, &"veine": 10.0, &"tenue": 12.0, &"poursuite": 6.0}
## Escorte : la barque suit `escort_path` à ESCORT_SPEED_U ; elle s'arrête si le joueur s'éloigne de plus de
## ESCORT_LEASH_U ; les monstres au contact (ESCORT_HIT_RADIUS_U) la blessent ; à 0 PV elle s'immobilise ESCORT_STALL_S
## puis repart pleine (jamais détruite). PV = ESCORT_HP_MINI_SHARE x PV d'un mini-boss.
const ESCORT_SPEED_U := 2.5
const ESCORT_LEASH_U := 6.0
const ESCORT_HP_MINI_SHARE := 0.3
const ESCORT_STALL_S := 5.0
const ESCORT_HIT_RADIUS_U := 1.3
const ESCORT_BOARD_RANGE_U := 2.0 ## portée pour « lancer la barque »
## Rituel : RITUAL_RELAYS relais à fermer (maintien RITUAL_HOLD_S), le cœur pulse toutes les RITUAL_PULSE_S[relais fermés] s :
## anneau télégraphié RITUAL_TELEGRAPH_S puis onde qui s'étend à RITUAL_WAVE_SPEED_U (largeur 2 x RITUAL_WAVE_HALF_U) jusqu'à
## RITUAL_WAVE_MAX_U ; dégâts = coup de mini-boss x RITUAL_RING_COEF (plafond de coup du joueur inchangé), un seul par onde.
const RITUAL_RELAYS := 3
const RITUAL_HOLD_S := 1.2
const RITUAL_PULSE_S: Array[float] = [12.0, 9.0, 7.0]
const RITUAL_TELEGRAPH_S := 1.0
const RITUAL_RING_COEF := 1.0
const RITUAL_WAVE_SPEED_U := 8.0
const RITUAL_WAVE_MAX_U := 16.0
const RITUAL_WAVE_HALF_U := 0.75
const RITUAL_ZONE_RADIUS_U := 15.0 ## zone de monstres du Rituel : couvre les relais (10-14 u du cœur)
## Poursuite (docs/Design_Epreuves.md §3.3) : une lumière saute toutes les CHASE_JUMP_S s entre CHASE_POSTS bornes, à
## CHASE_JUMP_MIN_U-CHASE_JUMP_MAX_U de la borne courante, vacille CHASE_WARN_S avant ; un joueur à <= CHASE_REACH_U de la
## borne avant le saut = 1 point ; CHASE_POINTS points -> le mini-boss sort de terre.
const CHASE_POSTS := 6
const CHASE_JUMP_S := 8.0
const CHASE_POINTS := 5
const CHASE_JUMP_MIN_U := 9.0
const CHASE_JUMP_MAX_U := 17.0
const CHASE_REACH_U := 2.0
const CHASE_WARN_S := 1.5
## Veine (§3.4) : un disque de lumière (rayon VEIN_RADIUS_U) glisse à VEIN_SPEED_U le long du tracé ; la charge
## (VEIN_CHARGE_S s) n'avance que si un joueur est dedans ; un geyser est annoncé toutes les VEIN_GEYSER_EVERY_S s. Avec
## VEIN_GEYSER_ON_PLAYER (audit du 07/11/2026) il se pose sous un joueur vivant du disque (tour de rôle), décalé de
## VEIN_GEYSER_AHEAD_U dans le sens d'avance du disque ; sans joueur dedans : devant le centre. Télégraphe
## VEIN_GEYSER_TELEGRAPH_S >= 0,8 s, coup de mini-boss x VEIN_GEYSER_COEF.
const VEIN_RADIUS_U := 6.0
const VEIN_SPEED_U := 1.5
const VEIN_CHARGE_S := 30.0
const VEIN_LOOP_MIN_U := 40.0
const VEIN_LOOP_MAX_U := 70.0
const VEIN_GEYSER_EVERY_S := 6.0
const VEIN_GEYSER_RADIUS_U := 2.0
const VEIN_GEYSER_TELEGRAPH_S := 1.2
const VEIN_GEYSER_COEF := 1.0
const VEIN_GEYSER_AHEAD_U := 0.75
const VEIN_GEYSER_ON_PLAYER := true
const VEIN_GEYSER_FALLBACK_AHEAD_U := 3.0 ## sans joueur éligible dans le disque : ancien placement, devant le centre
const VEIN_ZONE_RADIUS_U := 7.0 ## zone de monstres = disque + 1 u
## Tenue (§3.5) : la cloche (PV = HOLD_HP_MINI_SHARE x PV d'un mini-boss, x pente coop du mini-boss : 1,3 / 1,6 / 1,9) est
## attaquée par un paquet de HOLD_PACKET monstres toutes les HOLD_WAVE_EVERY_S s pendant HOLD_DURATION_S s, annoncé
## HOLD_ANNOUNCE_S s à l'avance sur l'un des HOLD_SIDES côtés, à HOLD_SPAWN_DIST_U ; un joueur à <= HOLD_LURE_BREAK_U d'un
## monstre leurré le délivre ; note « parfait » si PV >= HOLD_PERFECT_HP_PCT.
const HOLD_HP_MINI_SHARE := 0.5
const HOLD_DURATION_S := 40.0
const HOLD_SIDES := 3
const HOLD_WAVE_EVERY_S := 8.0
const HOLD_PACKET := 4
const HOLD_ANNOUNCE_S := 2.0
const HOLD_SPAWN_DIST_U := 10.0
const HOLD_LURE_BREAK_U := 3.0
const HOLD_HIT_RADIUS_U := 1.3
const HOLD_PERFECT_HP_PCT := 0.7
const HOLD_ZONE_RADIUS_U := 12.0


func epreuves_enabled() -> bool:
	var args := OS.get_cmdline_user_args()
	return (EPREUVES_ENABLED or args.has(EPREUVES_ARG)) and not args.has(EPREUVES_OFF_ARG)


## Note d'une épreuve : « parfait » si `clean` (barque jamais immobilisée, aucun anneau reçu) et durée <= seuil ; « bien »
## jusqu'à seuil x EPREUVE_GOOD_MULT ; « fait » au-delà.
func epreuve_grade(verb: StringName, elapsed_s: float, clean: bool) -> StringName:
	var target: float = float(EPREUVE_TARGET_S.get(verb, 40.0))
	if clean and elapsed_s <= target:
		return &"parfait"
	return &"bien" if elapsed_s <= target * EPREUVE_GOOD_MULT else &"fait"


## Or versé pour une note, `price_p` = prix d'un petit coffre au début de l'étage (station_price_p).
func epreuve_gold(grade: StringName, price_p: float) -> float:
	return float(EPREUVE_GOLD_P.get(grade, 0.0)) * price_p


## PV de la barque d'escorte : ESCORT_HP_MINI_SHARE x PV d'un mini-boss à la difficulté D.
func escort_hp(D: float, stage: int = 1) -> float:
	return ESCORT_HP_MINI_SHARE * boss_hp(&"mini", D, stage)


## PV de la cloche de la Tenue : HOLD_HP_MINI_SHARE x PV d'un mini-boss à D, x (1 + 0,3 (n_alive - 1)) en coop.
func hold_hp(D: float, stage: int = 1, n_alive: int = 1) -> float:
	return HOLD_HP_MINI_SHARE * boss_hp(&"mini", D, stage, n_alive)


## Note de la Tenue (durée fixe, notée aux PV restants) : « parfait » si PV >= HOLD_PERFECT_HP_PCT, « bien » si > 0,
## « fait » si la cloche est éteinte.
func epreuve_grade_hold(hp_ratio: float) -> StringName:
	if hp_ratio >= HOLD_PERFECT_HP_PCT:
		return &"parfait"
	return &"bien" if hp_ratio > 0.0 else &"fait"


## Dégâts d'un geyser de la Veine : un coup de mini-boss de coef VEIN_GEYSER_COEF.
func vein_geyser_damage(D: float) -> float:
	return mini_attack_damage(boss_damage(&"mini", D), VEIN_GEYSER_COEF)


## Rubis des notes « parfait » d'une run : EPREUVE_RUBIES_PARFAIT par note, plafonné à EPREUVE_RUBIES_CAP.
func epreuve_rubies(perfect_count: int) -> int:
	return mini(EPREUVE_RUBIES_PARFAIT * maxi(perfect_count, 0), EPREUVE_RUBIES_CAP)


## Cadence du cœur (s) quand `closed` relais sont fermés.
func ritual_pulse_s(closed: int) -> float:
	return RITUAL_PULSE_S[clampi(closed, 0, RITUAL_PULSE_S.size() - 1)]


## Dégâts de l'onde du cœur : un coup de mini-boss de coef RITUAL_RING_COEF.
func ritual_ring_damage(D: float) -> float:
	return mini_attack_damage(boss_damage(&"mini", D), RITUAL_RING_COEF)


# --- Multijoueur coop 1-4 (docs/Design_Multijoueur.md §4, docs/multi/Scaling_Multi.md §2.13) ---------------------
## Toutes les fonctions rendent exactement la valeur solo à n = 1. n = joueurs ACTIFS de la partie (connectés, non
## absents), recalculé au début de chaque étage (Players.party_size_for_scaling, RunState.party_size) ; n_alive =
## joueurs vivants à l'apparition d'un boss.
const MULTI_MAX_PLAYERS := 4
const PLAYER_FACTOR_SLOPE := 0.3 ## pf(n) = 1 + 0,3 (n - 1) : départ de D (RoR2)
const PLAYER_TIME_EXP := 0.2 ## pente de temps de D × n^0,2 (RoR2)
const PLAYER_CREDIT_SLOPE := 0.5 ## crédits du director × (1 + 0,5 (n - 1)) = (n + 1) / 2 (RoR2)
## Calibré par systems-designer (docs/multi/Scaling_Multi.md §2.13, 01/11/2026) : +60 % de coffres par joueur en plus (plage sûre 0,55-0,7).
const PLAYER_INTERACTABLE_SLOPE := 0.6
## Or (décision du joueur, 01/11/2026) : chaque gain crédite le même montant à chaque joueur (morts compris), bourses
## individuelles, aucun transfert ; × 2 / (n + 1) pour compenser les crédits du director × (n + 1) / 2 : l'or des kills
## par joueur reste celui du solo (Scaling_Multi.md §2.8). Index = n (0 inutilisé).
const COOP_GOLD_MULT: Array[float] = [1.0, 1.0, 2.0 / 3.0, 0.5, 0.4]
const PLAYER_ALIVE_SLOPE := 0.2 ## plafond de vivants × (1 + 0,2 (n - 1)) ; 0 en qualité Basse
## PV des boss × (1 + pente (n_alive - 1)) (décision du joueur, 01/11/2026).
const BOSS_HP_PLAYER_SLOPE := {&"mini": 0.3, &"etage": 0.4, &"final": 0.35}
const EPREUVE_TARGET_PLAYER_SLOPE := 0.08 ## épreuves partageables (Rituel seul) : cible × (1 - 0,08 (n - 1))
## Mort en coop (décision du joueur, 01/11/2026) : spectateur, ressuscité au début de l'étage suivant ; équipe entière
## morte = défaite. Pas de relevé au sol, pas de réanimation au pilier.
const MULTI_RESURRECT_ON_FLOOR_START := true
const MULTI_RESURRECT_HP_PCT := 1.0 ## PV au retour (début d'étage, comme RoR2)
const MULTI_RESURRECT_INVULN_S := 2.0
const MULTI_AFK_S := 45.0 ## sans entrée ni dégât infligé : retiré de n au prochain recalcul (début d'étage)
const MULTI_RUBY_PARTICIPATION_MIN := 0.25 ## part de la moyenne des dégâts de l'équipe qui vaut participation 1
## Charge d'un gros pilier en coop : au prorata des joueurs vivants dans la zone, jamais sous ce plancher tant qu'au
## moins un joueur y est (docs/multi/Design_Coop.md §1.3 ; ex-CoopRules.CHARGE_FLOOR).
const COOP_CHARGE_FLOOR := 0.25
## Téléporteur de sortie en coop : compte à rebours (s) après le premier « interagir », visible de tous
## (Design_Coop §1.4 ; ex-CoopRules.TELEPORT_COUNTDOWN_S).
const COOP_TELEPORT_COUNTDOWN_S := 15.0
## Boss et mini-boss en coop : changement de cible au plus toutes les N s (Design_Coop §5.2, anti « tank parking » ;
## ex-Director.COOP_BOSS_RETARGET_S).
const COOP_BOSS_RETARGET_S := 6.0
## Menace : pour le choix de cible d'un boss, la distance au dernier joueur qui l'a frappé compte × ce facteur
## (ex-Director.COOP_BOSS_THREAT_DIST_MULT).
const COOP_BOSS_THREAT_DIST_MULT := 0.7


static func _party_n(n: int) -> int:
	return clampi(n, 1, MULTI_MAX_PLAYERS)


## pf(n) = 1 + 0,3 (n - 1) : 1 / 1,3 / 1,6 / 1,9.
func party_factor(n: int) -> float:
	return 1.0 + PLAYER_FACTOR_SLOPE * (_party_n(n) - 1)


## n^0,2 : 1 / 1,149 / 1,246 / 1,320 (pente de temps de D).
func party_time_mult(n: int) -> float:
	return pow(float(_party_n(n)), PLAYER_TIME_EXP)


## g(n) = (n + 1) / 2 : crédits du director (1 / 1,5 / 2 / 2,5).
func party_credit_mult(n: int) -> float:
	return 1.0 + PLAYER_CREDIT_SLOPE * (_party_n(n) - 1)


## Coffres posés (petits, grands, vitrines, plafond de spéciaux) : × (1 + 0,5 (n - 1)).
func interactable_mult(n: int) -> float:
	return 1.0 + PLAYER_INTERACTABLE_SLOPE * (_party_n(n) - 1)


## Coffres posés par étage pour `base` en solo : roundi(base × interactable_mult(n)), soit +60 % par joueur en plus
## (8 petits -> 8/13/18/22, 2 grands -> 2/3/4/6). n = 1 : base. Les ateliers et les 4 capsules ne sont pas multipliés.
func coop_chest_count(base: int, n: int) -> int:
	if n <= 1 or base <= 0:
		return base
	return roundi(base * interactable_mult(n))


## Chance (0-1) multipliée par interactable_mult(n), plafonnée à 1 (coffre légendaire : 25 % -> 62,5 % à 4).
func party_chance(p: float, n: int) -> float:
	return p if n <= 1 else minf(1.0, p * interactable_mult(n))


## Multiplicateur de PV d'un boss pour `n_alive` joueurs vivants ; `kind` : &"mini", &"etage" ou &"final".
func boss_party_hp_mult(kind: StringName, n_alive: int) -> float:
	return 1.0 + float(BOSS_HP_PLAYER_SLOPE.get(kind, BOSS_HP_PLAYER_SLOPE[&"etage"])) * (_party_n(n_alive) - 1)


## Or crédité à CHAQUE joueur pour un gain `amount` (kill, capsule, prime, pilier, note d'épreuve) : amount × mult(n).
func coop_gold_mult(n: int) -> float:
	return COOP_GOLD_MULT[_party_n(n)]


## Niveau de départ des joueurs : monster_level(pf(n)) = 1 / 1 / 2 / 3 (§2.4).
func player_start_level(n: int) -> int:
	return monster_level(party_factor(n))


## XP cumulée pour atteindre `level` depuis le niveau 1 (somme des xp_required).
func xp_total_for_level(level: int) -> float:
	var total := 0.0
	for l in range(1, maxi(level, 1)):
		total += xp_required(l)
	return total


## Cible « parfait » des épreuves partageables (Rituel, Poursuite) : × (1 - 0,08 (n - 1)), soit × 0,76 à 4.
func epreuve_target_party_mult(n: int) -> float:
	return 1.0 - EPREUVE_TARGET_PLAYER_SLOPE * (_party_n(n) - 1)


## Participation aux rubis (0-1) : dégâts du joueur / (dégâts de l'équipe / n) / 0,25, bornée ; 1 en solo.
func ruby_participation(player_damage: float, team_damage: float, n: int) -> float:
	if n <= 1 or team_damage <= 0.0:
		return 1.0
	return clampf(player_damage / (team_damage / float(_party_n(n))) / MULTI_RUBY_PARTICIPATION_MIN, 0.0, 1.0)
