# Rapport d'équilibrage des personnages (simulateur automatique)

Généré le 23/10/2026 08:45 par `art/tools/night/balance_sim.py` (scène `game/tests/balance_sim_run.tscn`, code `game/tests/balance_sim/`). Référence : **Ardent** ; écart > ±20 % en **gras** (▲ favorable, ▼ défavorable au personnage).

**Méthode** : arène vide, vrai joueur + vrai kit, pilote scripté identique pour tous (distance = portée utile du sort 1, va au contact pour lancer un sort 2-4 prêt à courte portée, kite, sort des télégraphes, roulade si l'impact est imminent ; sorts 2-4 en auto-cast du jeu, ciblage automatique mobile). Monstres réels du Director (IA, télégraphes, projectiles). D figé par config ; objets neutres sans proc (dégâts, vitesse d'attaque, PV, armure, recharge, critique). Morts : le joueur est relevé et la mort comptée. DPS = dégâts effectifs (sans overkill) / durée du combat. **DPS cible** = moyenne Élite + Mini-boss ; **DPS zone** = essaim de 64 T1.

Limites : pilote moyen (réagit aux télégraphes après 0,2 s, en rate 25 %), pas de pickups ni de montée de niveau pendant le combat, pas de carte (ni murs ni goulets), **pas d'AmbianceManager** : pluie moyenne (repli du kit) pour Averse, or de poche fixe (0 / 150 / 400 selon la config, pour Avare), objets neutres seulement. L'essaim de 64 T1 arrive en ~5 s : au-delà d'un certain DPS le TTK essaim sature (arrivée des monstres). Dégâts subis : écart signalé seulement s'il dépasse aussi 5 % PV/min en absolu. Les ratios valent plus que les valeurs absolues.

## Statut des personnages

| Perso | Statut | Note | Erreurs de script | Autres erreurs moteur |
|---|---|---|---|---|
| ardent | simulé |  | 0 | 0 |
| rictus | simulé |  | 0 | 0 |
| tocsin | simulé |  | 0 | 0 |
| averse | simulé |  | 0 | 0 |
| arpenteuse | simulé |  | 0 | 376 |
| rainette | simulé |  | 0 | 0 |
| avare | simulé |  | 0 | 0 |
| bourbe | simulé |  | 0 | 0 |
| vigie | simulé |  | 0 | 0 |
| morfil | simulé |  | 30 | 356 |

## Synthèse : Niv 1 · Moyen 0 min · sans objet

| Perso | DPS zone | DPS mixte | DPS cible | TTK essaim | TTK mixte | TTK élite | TTK mini-boss | Dégâts subis (% PV/min) | Morts | Kills/min essaim | Ressource ≥ 50 % |
|---|---|---|---|---|---|---|---|---|---|---|---|
| ardent | 118 | 47 | 33 | 9.8 s | 26.4 s | 41.9 s | 26.6 s | 59.4 | 0 | 394 | — |
| rictus | 96 (-19 %) | 30 (**-35 %** ▼) | 35 (+5 %) | 12.0 s (**+23 %** ▼) | 40.6 s (**+54 %** ▼) | 48.5 s (+16 %) | 22.2 s (-16 %) | 87.9 (**+48 %** ▼) | 0 | 320 (-19 %) | — |
| tocsin | 118 (-0 %) | 51 (+9 %) | 41 (**+24 %** ▲) | 9.8 s (+0 %) | 24.0 s (-9 %) | 32.5 s (**-22 %** ▲) | 22.3 s (-16 %) | 120.0 (**+102 %** ▼) | 2 | 393 (-0 %) | 1 % |
| averse | 100 (-15 %) | 53 (+13 %) | 27 (-18 %) | 12.0 s (**+23 %** ▼) | 23.2 s (-12 %) | 37.4 s (-11 %) | 45.0 s (**+69 %** ▼) | 126.0 (**+112 %** ▼) | 3 | 333 (-15 %) | 25 % |
| arpenteuse | 98 (-17 %) | 25 (**-47 %** ▼) | 31 (-6 %) | 12.0 s (**+23 %** ▼) | 51.1 s (**+93 %** ▼) | 37.9 s (-10 %) | 33.2 s (**+25 %** ▼) | 144.4 (**+143 %** ▼) | 5 | 326 (-17 %) | 57 % |
| rainette | 86 (**-27 %** ▼) | 46 (-1 %) | 33 (+1 %) | 13.6 s (**+39 %** ▼) | 26.5 s (+0 %) | 41.5 s (-1 %) | 26.4 s (-1 %) | 106.7 (**+80 %** ▼) | 3 | 286 (**-27 %** ▼) | 64 % |
| avare | 106 (-11 %) | 43 (-9 %) | 38 (+14 %) | 11.1 s (+14 %) | 29.0 s (+10 %) | 40.1 s (-4 %) | 21.9 s (-18 %) | 134.4 (**+126 %** ▼) | 2 | 353 (-11 %) | 0 % |
| bourbe | 73 (**-38 %** ▼) | 37 (**-21 %** ▼) | 35 (+6 %) | 15.7 s (**+61 %** ▼) | 33.3 s (**+26 %** ▼) | 44.9 s (+7 %) | 23.0 s (-14 %) | 75.8 (**+28 %** ▼) | 0 | 244 (**-38 %** ▼) | 18 % |
| vigie | 86 (**-28 %** ▼) | 52 (+11 %) | 39 (+17 %) | 13.5 s (**+38 %** ▼) | 23.7 s (-10 %) | 34.7 s (-17 %) | 23.2 s (-13 %) | 69.3 (+17 %) | 0 | 285 (**-28 %** ▼) | 49 % |
| morfil | 108 (-9 %) | 37 (**-21 %** ▼) | 30 (-8 %) | 10.7 s (+10 %) | 33.3 s (**+26 %** ▼) | 46.1 s (+10 %) | 28.8 s (+8 %) | 58.3 (-2 %) | 0 | 360 (-9 %) | 87 % |

## Synthèse : Niv 6 · Moyen 6 min · 6 objets neutres

| Perso | DPS zone | DPS mixte | DPS cible | TTK essaim | TTK mixte | TTK élite | TTK mini-boss | Dégâts subis (% PV/min) | Morts | Kills/min essaim | Ressource ≥ 50 % |
|---|---|---|---|---|---|---|---|---|---|---|---|
| ardent | 190 | 94 | 95 | 9.7 s | 20.9 s | 23.8 s | 20.4 s | 39.0 | 0 | 396 | — |
| rictus | 167 (-12 %) | 73 (**-23 %** ▼) | 91 (-4 %) | 11.1 s (+14 %) | 27.1 s (**+29 %** ▼) | 29.6 s (**+24 %** ▼) | 18.8 s (-7 %) | 32.7 (-16 %) | 0 | 349 (-12 %) | — |
| tocsin | 207 (+9 %) | 93 (-1 %) | 112 (+18 %) | 8.9 s (-8 %) | 21.1 s (+1 %) | 19.8 s (-17 %) | 17.3 s (-15 %) | 61.7 (**+58 %** ▼) | 0 | 432 (+9 %) | 2 % |
| averse | 226 (+19 %) | 98 (+4 %) | 77 (-19 %) | 8.2 s (-15 %) | 20.0 s (-4 %) | 19.9 s (-17 %) | 38.6 s (**+89 %** ▼) | 50.9 (**+31 %** ▼) | 0 | 470 (+19 %) | 11 % |
| arpenteuse | 174 (-8 %) | 51 (**-45 %** ▼) | 88 (-8 %) | 10.7 s (+10 %) | 38.3 s (**+83 %** ▼) | 22.1 s (-7 %) | 25.1 s (**+23 %** ▼) | 78.4 (**+101 %** ▼) | 0 | 363 (-8 %) | 53 % |
| rainette | 204 (+7 %) | 94 (+0 %) | 91 (-4 %) | 9.0 s (-7 %) | 20.8 s (-1 %) | 23.8 s (+0 %) | 21.8 s (+7 %) | 41.3 (+6 %) | 0 | 426 (+7 %) | 62 % |
| avare | 192 (+1 %) | 84 (-11 %) | 123 (**+29 %** ▲) | 9.6 s (-0 %) | 23.5 s (+12 %) | 21.8 s (-8 %) | 14.1 s (**-31 %** ▲) | 51.9 (**+33 %** ▼) | 0 | 400 (+1 %) | 0 % |
| bourbe | 204 (+7 %) | 87 (-8 %) | 95 (-0 %) | 9.0 s (-7 %) | 22.8 s (+9 %) | 25.9 s (+9 %) | 19.0 s (-7 %) | 26.9 (**-31 %** ▲) | 0 | 425 (+7 %) | 29 % |
| vigie | 184 (-3 %) | 94 (-0 %) | 103 (+8 %) | 10.0 s (+3 %) | 20.9 s (-0 %) | 20.0 s (-16 %) | 20.0 s (-2 %) | 57.5 (**+48 %** ▼) | 0 | 384 (-3 %) | 51 % |
| morfil | 165 (-13 %) | 81 (-14 %) | 84 (-12 %) | 11.2 s (+16 %) | 24.4 s (+16 %) | 27.7 s (+17 %) | 22.7 s (+11 %) | 32.3 (-17 %) | 0 | 343 (-13 %) | 92 % |

## Synthèse : Niv 12 · Difficile ét.3 4 min · 15 objets neutres

| Perso | DPS zone | DPS mixte | DPS cible | TTK essaim | TTK mixte | TTK élite | TTK mini-boss | Dégâts subis (% PV/min) | Morts | Kills/min essaim | Ressource ≥ 50 % |
|---|---|---|---|---|---|---|---|---|---|---|---|
| ardent | 250 | 175 | 219 | 10.1 s | 15.4 s | 13.2 s | 13.4 s | 23.5 | 0 | 379 | — |
| rictus | 265 (+6 %) | 149 (-15 %) | 233 (+7 %) | 9.5 s (-6 %) | 18.1 s (+17 %) | 15.6 s (+18 %) | 10.6 s (**-21 %** ▲) | 13.7 (**-42 %** ▲) | 0 | 402 (+6 %) | — |
| tocsin | 221 (-12 %) | 156 (-11 %) | 230 (+5 %) | 11.5 s (+14 %) | 17.4 s (+13 %) | 11.9 s (-10 %) | 13.2 s (-2 %) | 28.4 (+21 %) | 0 | 335 (-12 %) | 13 % |
| averse | 298 (+19 %) | 158 (-10 %) | 207 (-5 %) | 8.5 s (-16 %) | 17.3 s (+12 %) | 12.1 s (-8 %) | 16.3 s (**+22 %** ▼) | 20.9 (-11 %) | 0 | 452 (+19 %) | 34 % |
| arpenteuse | 245 (-2 %) | 101 (**-43 %** ▼) | 201 (-8 %) | 10.4 s (+2 %) | 27.0 s (**+75 %** ▼) | 13.7 s (+4 %) | 15.0 s (+12 %) | 35.0 (**+49 %** ▼) | 0 | 371 (-2 %) | 39 % |
| rainette | 307 (**+23 %** ▲) | 155 (-12 %) | 192 (-12 %) | 8.2 s (-19 %) | 17.5 s (+13 %) | 13.6 s (+3 %) | 16.8 s (**+25 %** ▼) | 39.4 (**+68 %** ▼) | 0 | 465 (**+23 %** ▲) | 71 % |
| avare | 279 (+12 %) | 151 (-14 %) | 307 (**+40 %** ▲) | 9.1 s (-10 %) | 18.0 s (+17 %) | 10.2 s (**-23 %** ▲) | 9.1 s (**-32 %** ▲) | 18.5 (**-21 %** ▲) | 0 | 423 (+12 %) | 5 % |
| bourbe | 259 (+3 %) | 156 (-11 %) | 239 (+9 %) | 9.8 s (-3 %) | 17.3 s (+12 %) | 11.2 s (-15 %) | 13.0 s (-3 %) | 10.5 (**-55 %** ▲) | 0 | 392 (+3 %) | 42 % |
| vigie | 230 (-8 %) | 156 (-11 %) | 221 (+1 %) | 11.2 s (+10 %) | 17.4 s (+13 %) | 11.9 s (-10 %) | 14.2 s (+6 %) | 16.9 (**-28 %** ▲) | 0 | 348 (-8 %) | 48 % |
| morfil | 279 (+12 %) | 150 (-14 %) | 239 (+9 %) | 9.1 s (-10 %) | 18.0 s (+17 %) | 10.6 s (-20 %) | 13.9 s (+3 %) | 14.2 (**-39 %** ▲) | 0 | 423 (+12 %) | 98 % |

## Écarts signalés (> ±20 % vs Ardent)

- **rictus**, L1 : DPS mixte -35 % ; dégâts subis +48 % ; TTK Essaim T1 (64) +23 % ; TTK Mixte + tireurs +54 %
- **rictus**, L6 : DPS mixte -23 % ; TTK Mixte + tireurs +29 % ; TTK Élite T3 +24 %
- **rictus**, L12 : dégâts subis -42 % ; TTK Mini-boss -21 %
- **tocsin**, L1 : DPS cible +24 % ; dégâts subis +102 % ; TTK Élite T3 -22 % ; morts 2 (Ardent 0)
- **tocsin**, L6 : dégâts subis +58 %
- **averse**, L1 : dégâts subis +112 % ; TTK Essaim T1 (64) +23 % ; TTK Mini-boss +69 % ; morts 3 (Ardent 0)
- **averse**, L6 : dégâts subis +31 % ; TTK Mini-boss +89 %
- **averse**, L12 : TTK Mini-boss +22 %
- **arpenteuse**, L1 : DPS mixte -47 % ; dégâts subis +143 % ; TTK Essaim T1 (64) +23 % ; TTK Mixte + tireurs +93 % ; TTK Mini-boss +25 % ; morts 5 (Ardent 0)
- **arpenteuse**, L6 : DPS mixte -45 % ; dégâts subis +101 % ; TTK Mixte + tireurs +83 % ; TTK Mini-boss +23 %
- **arpenteuse**, L12 : DPS mixte -43 % ; dégâts subis +49 % ; TTK Mixte + tireurs +75 %
- **rainette**, L1 : DPS zone -27 % ; dégâts subis +80 % ; kills/min -27 % ; TTK Essaim T1 (64) +39 % ; morts 3 (Ardent 0)
- **rainette**, L12 : DPS zone +23 % ; dégâts subis +68 % ; kills/min +23 % ; TTK Mini-boss +25 %
- **avare**, L1 : dégâts subis +126 % ; morts 2 (Ardent 0)
- **avare**, L6 : DPS cible +29 % ; dégâts subis +33 % ; TTK Mini-boss -31 %
- **avare**, L12 : DPS cible +40 % ; dégâts subis -21 % ; TTK Élite T3 -23 % ; TTK Mini-boss -32 %
- **bourbe**, L1 : DPS zone -38 % ; DPS mixte -21 % ; dégâts subis +28 % ; kills/min -38 % ; TTK Essaim T1 (64) +61 % ; TTK Mixte + tireurs +26 %
- **bourbe**, L6 : dégâts subis -31 %
- **bourbe**, L12 : dégâts subis -55 %
- **vigie**, L1 : DPS zone -28 % ; kills/min -28 % ; TTK Essaim T1 (64) +38 %
- **vigie**, L6 : dégâts subis +48 %
- **vigie**, L12 : dégâts subis -28 %
- **morfil**, L1 : DPS mixte -21 % ; TTK Mixte + tireurs +26 %
- **morfil**, L12 : dégâts subis -39 %

## Détail par combat

Moyennes sur les graines. Lancers par minute par slot (s1 auto / s2 / s3 / s4 ultime) ; esquives = roulades du pilote.

| Perso | Config | Scénario | Fini | Durée s | TTK s | DPS | Kills | Subis | % PV/min | Morts | PV min | Lancers/min s1·s2·s3·s4 | Esquives | Dist. pilote u |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ardent | L1 | Essaim T1 (64) | 3/3 | 9.8 | 9.8 | 118.3 | 64/64 | 8 | 51.2 | 0 | 90 % | 102·12.3·12.3·6.2 | 0.0 | 5.5 |
| ardent | L1 | Mixte + tireurs | 3/3 | 26.5 | 26.4 | 46.7 | 25/25 | 37 | 81.3 | 0 | 58 % | 100·10.6·8.3·4.6 | 0.0 | 5.5 |
| ardent | L1 | Élite T3 | 3/3 | 41.9 | 41.9 | 28.6 | 1/1 | 0 | 0.0 | 0 | 100 % | 101·10.0·8.6·4.3 | 0.0 | 5.5 |
| ardent | L1 | Mini-boss | 3/3 | 26.6 | 26.6 | 37.7 | 1/1 | 47 | 105.3 | 0 | 42 % | 101·10.5·9.0·4.5 | 0.0 | 5.5 |
| ardent | L6 | Essaim T1 (64) | 3/3 | 9.7 | 9.7 | 190.2 | 64/64 | 0 | 0.0 | 0 | 100 % | 116·12.4·12.4·6.2 | 0.0 | 5.5 |
| ardent | L6 | Mixte + tireurs | 3/3 | 21.0 | 20.9 | 94.0 | 25/25 | 51 | 51.9 | 0 | 83 % | 114·11.5·9.5·5.7 | 0.0 | 5.5 |
| ardent | L6 | Élite T3 | 3/3 | 23.8 | 23.8 | 81.7 | 1/1 | 0 | 0.0 | 0 | 100 % | 113·11.0·9.2·5.1 | 0.0 | 5.5 |
| ardent | L6 | Mini-boss | 3/3 | 20.4 | 20.4 | 108.9 | 1/1 | 98 | 104.1 | 0 | 46 % | 114·10.8·8.9·5.9 | 0.0 | 5.5 |
| ardent | L12 | Essaim T1 (64) | 3/3 | 10.1 | 10.1 | 250.3 | 64/64 | 0 | 0.0 | 0 | 100 % | 121·11.9·11.9·5.9 | 0.0 | 5.5 |
| ardent | L12 | Mixte + tireurs | 3/3 | 15.4 | 15.4 | 175.2 | 25/25 | 15 | 11.2 | 0 | 97 % | 113·11.7·11.7·7.8 | 0.0 | 5.5 |
| ardent | L12 | Élite T3 | 3/3 | 13.2 | 13.2 | 199.4 | 1/1 | 0 | 0.0 | 0 | 100 % | 131·13.6·13.6·4.5 | 0.0 | 5.5 |
| ardent | L12 | Mini-boss | 3/3 | 13.4 | 13.4 | 238.2 | 1/1 | 92 | 82.7 | 0 | 85 % | 131·13.6·11.8·4.5 | 0.0 | 5.5 |
| rictus | L1 | Essaim T1 (64) | 3/3 | 12.0 | 12.0 | 96.0 | 64/64 | 7 | 35.1 | 0 | 91 % | 65·13.3·10.0·5.0 | 0.0 | 1.9 |
| rictus | L1 | Mixte + tireurs | 3/3 | 40.6 | 40.6 | 30.4 | 25/25 | 83 | 128.9 | 0 | 39 % | 62·11.3·7.9·3.4 | 6.0 | 1.9 |
| rictus | L1 | Élite T3 | 3/3 | 48.5 | 48.5 | 24.8 | 1/1 | 22 | 29.7 | 0 | 48 % | 57·12.0·7.8·3.7 | 10.7 | 1.9 |
| rictus | L1 | Mini-boss | 3/3 | 22.3 | 22.2 | 45.0 | 1/1 | 56 | 157.9 | 0 | 18 % | 71·13.5·8.1·5.4 | 0.0 | 1.9 |
| rictus | L6 | Essaim T1 (64) | 3/3 | 11.1 | 11.1 | 167.3 | 64/64 | 1 | 3.2 | 0 | 98 % | 68·14.3·10.9·5.4 | 0.0 | 1.9 |
| rictus | L6 | Mixte + tireurs | 3/3 | 27.1 | 27.1 | 72.7 | 25/25 | 50 | 42.1 | 0 | 85 % | 64·13.3·8.9·4.4 | 2.3 | 1.9 |
| rictus | L6 | Élite T3 | 3/3 | 29.6 | 29.6 | 64.9 | 1/1 | 31 | 23.2 | 0 | 58 % | 59·14.2·8.1·4.1 | 7.0 | 1.9 |
| rictus | L6 | Mini-boss | 3/3 | 18.9 | 18.8 | 117.4 | 1/1 | 51 | 62.1 | 0 | 70 % | 74·14.8·9.6·5.3 | 0.0 | 1.9 |
| rictus | L12 | Essaim T1 (64) | 3/3 | 9.6 | 9.5 | 265.2 | 64/64 | 0 | 0.0 | 0 | 100 % | 42·18.8·12.6·6.3 | 0.0 | 1.9 |
| rictus | L12 | Mixte + tireurs | 3/3 | 18.1 | 18.1 | 149.3 | 25/25 | 16 | 10.4 | 0 | 95 % | 61·16.6·11.0·6.6 | 1.7 | 1.9 |
| rictus | L12 | Élite T3 | 3/3 | 15.6 | 15.6 | 169.9 | 1/1 | 31 | 26.2 | 0 | 87 % | 58·17.9·11.6·6.3 | 3.3 | 1.9 |
| rictus | L12 | Mini-boss | 3/3 | 10.6 | 10.6 | 297.0 | 1/1 | 16 | 18.2 | 0 | 97 % | 69·22.6·11.3·5.6 | 0.0 | 1.9 |
| tocsin | L1 | Essaim T1 (64) | 3/3 | 9.8 | 9.8 | 117.9 | 64/64 | 19 | 91.3 | 0 | 84 % | 135·12.3·12.3·6.1 | 0.0 | 5.5 |
| tocsin | L1 | Mixte + tireurs | 3/3 | 24.0 | 24.0 | 51.1 | 25/25 | 69 | 133.2 | 0 | 49 % | 132·9.2·7.5·5.0 | 3.0 | 5.5 |
| tocsin | L1 | Élite T3 | 3/3 | 32.5 | 32.5 | 36.9 | 1/1 | 9 | 12.9 | 0 | 70 % | 133·8.6·7.4·3.7 | 1.0 | 5.5 |
| tocsin | L1 | Mini-boss | 3/3 | 22.3 | 22.3 | 45.1 | 1/1 | 117 | 242.5 | 2 | 0 % | 125·8.1·8.1·4.4 | 0.0 | 5.5 |
| tocsin | L6 | Essaim T1 (64) | 3/3 | 8.9 | 8.9 | 207.1 | 64/64 | 22 | 43.4 | 0 | 94 % | 153·13.5·13.5·6.7 | 0.0 | 5.5 |
| tocsin | L6 | Mixte + tireurs | 3/3 | 21.1 | 21.1 | 93.2 | 25/25 | 79 | 65.1 | 0 | 70 % | 147·10.5·8.5·4.7 | 1.0 | 5.5 |
| tocsin | L6 | Élite T3 | 3/3 | 19.9 | 19.8 | 96.9 | 1/1 | 0 | 0.0 | 0 | 100 % | 150·9.1·9.1·4.0 | 0.0 | 5.5 |
| tocsin | L6 | Mini-boss | 3/3 | 17.3 | 17.3 | 127.9 | 1/1 | 134 | 138.3 | 0 | 53 % | 151·10.4·10.4·3.5 | 0.0 | 5.5 |
| tocsin | L12 | Essaim T1 (64) | 3/3 | 11.5 | 11.5 | 221.2 | 64/64 | 17 | 14.4 | 0 | 98 % | 161·15.7·10.5·5.2 | 0.0 | 5.5 |
| tocsin | L12 | Mixte + tireurs | 3/3 | 17.4 | 17.4 | 155.6 | 25/25 | 30 | 17.0 | 0 | 96 % | 135·12.6·10.4·6.9 | 0.7 | 5.5 |
| tocsin | L12 | Élite T3 | 3/3 | 11.9 | 11.9 | 221.7 | 1/1 | 0 | 0.0 | 0 | 100 % | 163·15.1·10.1·5.0 | 0.0 | 5.5 |
| tocsin | L12 | Mini-boss | 3/3 | 13.2 | 13.2 | 238.6 | 1/1 | 112 | 82.1 | 0 | 90 % | 165·13.6·12.0·4.5 | 0.0 | 5.5 |
| averse | L1 | Essaim T1 (64) | 2/2 | 12.0 | 12.0 | 100.0 | 64/64 | 0 | 0.0 | 0 | 100 % | 95·15.6·5.2·10.4 | 0.0 | 5.5 |
| averse | L1 | Mixte + tireurs | 2/2 | 23.2 | 23.2 | 52.9 | 25/25 | 55 | 157.8 | 0 | 54 % | 99·3.9·6.5·3.9 | 1.0 | 5.5 |
| averse | L1 | Élite T3 | 2/2 | 37.4 | 37.4 | 32.0 | 1/1 | 0 | 0.0 | 0 | 100 % | 101·6.4·6.4·1.6 | 0.0 | 5.5 |
| averse | L1 | Mini-boss | 2/2 | 45.0 | 45.0 | 22.3 | 1/1 | 232 | 346.4 | 3 | 9 % | 98·4.6·6.7·2.0 | 0.0 | 5.5 |
| averse | L6 | Essaim T1 (64) | 2/2 | 8.2 | 8.2 | 225.6 | 64/64 | 3 | 8.7 | 0 | 97 % | 102·18.6·10.8·14.7 | 0.0 | 5.5 |
| averse | L6 | Mixte + tireurs | 2/2 | 20.0 | 20.0 | 98.3 | 25/25 | 64 | 76.4 | 0 | 83 % | 112·6.0·6.0·3.0 | 0.0 | 5.5 |
| averse | L6 | Élite T3 | 2/2 | 19.9 | 19.9 | 97.1 | 1/1 | 0 | 0.0 | 0 | 100 % | 113·9.1·6.1·3.0 | 0.0 | 5.5 |
| averse | L6 | Mini-boss | 2/2 | 38.6 | 38.6 | 57.5 | 1/1 | 191 | 118.7 | 0 | 47 % | 112·7.1·7.0·1.6 | 0.0 | 5.5 |
| averse | L12 | Essaim T1 (64) | 2/2 | 8.5 | 8.5 | 298.1 | 64/64 | 0 | 0.0 | 0 | 100 % | 99·24.6·10.7·7.1 | 0.0 | 5.5 |
| averse | L12 | Mixte + tireurs | 2/2 | 17.3 | 17.3 | 158.0 | 25/25 | 15 | 11.0 | 0 | 97 % | 113·5.1·10.5·3.5 | 0.0 | 5.5 |
| averse | L12 | Élite T3 | 2/2 | 12.2 | 12.1 | 217.3 | 1/1 | 0 | 0.0 | 0 | 100 % | 133·9.9·9.9·4.9 | 0.0 | 5.5 |
| averse | L12 | Mini-boss | 2/2 | 16.3 | 16.3 | 197.1 | 1/1 | 94 | 72.4 | 0 | 84 % | 131·12.8·7.5·3.7 | 0.0 | 5.5 |
| arpenteuse | L1 | Essaim T1 (64) | 3/3 | 12.0 | 12.0 | 97.9 | 64/64 | 13 | 81.8 | 0 | 88 % | 0·11.6·10.2·5.1 | 0.0 | 4.2 |
| arpenteuse | L1 | Mixte + tireurs | 3/3 | 51.1 | 51.1 | 24.6 | 25/25 | 100 | 131.4 | 1 | 8 % | 0·9.1·8.3·3.6 | 1.0 | 4.2 |
| arpenteuse | L1 | Élite T3 | 3/3 | 37.9 | 37.9 | 31.8 | 1/1 | 0 | 0.0 | 0 | 100 % | 0·10.6·8.4·3.2 | 0.0 | 4.2 |
| arpenteuse | L1 | Mini-boss | 3/3 | 33.2 | 33.2 | 30.3 | 1/1 | 171 | 364.5 | 4 | 0 % | 0·9.1·8.4·3.6 | 0.0 | 4.2 |
| arpenteuse | L6 | Essaim T1 (64) | 3/3 | 10.7 | 10.7 | 174.1 | 64/64 | 15 | 37.6 | 0 | 93 % | 0·11.3·11.3·5.7 | 0.0 | 4.2 |
| arpenteuse | L6 | Mixte + tireurs | 3/3 | 38.3 | 38.3 | 51.3 | 25/25 | 93 | 62.3 | 0 | 74 % | 0·11.0·9.4·4.2 | 0.7 | 4.2 |
| arpenteuse | L6 | Élite T3 | 3/3 | 22.1 | 22.1 | 87.9 | 1/1 | 0 | 0.0 | 0 | 100 % | 0·11.0·9.9·5.5 | 0.0 | 4.2 |
| arpenteuse | L6 | Mini-boss | 3/3 | 25.1 | 25.1 | 88.1 | 1/1 | 210 | 213.8 | 0 | 14 % | 0·11.9·9.6·4.8 | 0.0 | 4.2 |
| arpenteuse | L12 | Essaim T1 (64) | 3/3 | 10.4 | 10.4 | 245.0 | 64/64 | 0 | 0.0 | 0 | 100 % | 0·13.4·11.6·5.8 | 0.0 | 4.2 |
| arpenteuse | L12 | Mixte + tireurs | 3/3 | 27.0 | 27.0 | 100.5 | 25/25 | 90 | 43.2 | 0 | 91 % | 0·12.6·11.8·5.1 | 0.3 | 4.2 |
| arpenteuse | L12 | Élite T3 | 3/3 | 13.7 | 13.7 | 192.4 | 1/1 | 0 | 0.0 | 0 | 100 % | 0·13.1·13.1·4.4 | 0.0 | 4.2 |
| arpenteuse | L12 | Mini-boss | 3/3 | 15.0 | 15.0 | 210.0 | 1/1 | 109 | 96.9 | 0 | 88 % | 0·12.0·12.0·8.0 | 0.0 | 4.2 |
| rainette | L1 | Essaim T1 (64) | 3/3 | 13.6 | 13.6 | 85.9 | 64/64 | 8 | 40.1 | 0 | 95 % | 83·11.7·8.9·4.5 | 0.0 | 3.1 |
| rainette | L1 | Mixte + tireurs | 3/3 | 26.5 | 26.5 | 46.4 | 25/25 | 39 | 101.4 | 0 | 54 % | 83·9.1·9.1·4.5 | 2.3 | 3.1 |
| rainette | L1 | Élite T3 | 3/3 | 41.5 | 41.5 | 28.9 | 1/1 | 14 | 22.0 | 0 | 65 % | 83·9.2·8.7·3.8 | 2.7 | 3.1 |
| rainette | L1 | Mini-boss | 3/3 | 26.4 | 26.4 | 38.0 | 1/1 | 105 | 263.5 | 3 | 1 % | 80·9.8·9.1·4.6 | 0.0 | 3.1 |
| rainette | L6 | Essaim T1 (64) | 3/3 | 9.0 | 9.0 | 204.4 | 64/64 | 0 | 0.0 | 0 | 100 % | 80·13.3·13.3·6.7 | 0.0 | 3.1 |
| rainette | L6 | Mixte + tireurs | 3/3 | 20.8 | 20.8 | 94.4 | 25/25 | 46 | 52.9 | 0 | 85 % | 78·11.5·8.6·3.8 | 1.3 | 3.1 |
| rainette | L6 | Élite T3 | 3/3 | 23.8 | 23.8 | 80.6 | 1/1 | 35 | 35.1 | 0 | 74 % | 93·10.1·10.1·5.0 | 1.7 | 3.1 |
| rainette | L6 | Mini-boss | 3/3 | 21.8 | 21.8 | 101.6 | 1/1 | 70 | 77.0 | 0 | 60 % | 87·11.0·9.2·5.5 | 0.0 | 3.1 |
| rainette | L12 | Essaim T1 (64) | 3/3 | 8.2 | 8.2 | 307.2 | 64/64 | 0 | 0.0 | 0 | 100 % | 80·14.5·14.5·7.3 | 0.0 | 3.1 |
| rainette | L12 | Mixte + tireurs | 3/3 | 17.5 | 17.5 | 154.6 | 25/25 | 28 | 19.8 | 0 | 95 % | 61·12.6·10.3·6.9 | 0.7 | 3.1 |
| rainette | L12 | Élite T3 | 3/3 | 13.7 | 13.6 | 197.2 | 1/1 | 53 | 46.7 | 0 | 83 % | 97·14.7·13.4·5.7 | 0.0 | 3.1 |
| rainette | L12 | Mini-boss | 3/3 | 16.9 | 16.8 | 187.6 | 1/1 | 121 | 91.0 | 0 | 85 % | 96·14.3·11.8·7.1 | 0.0 | 3.1 |
| avare | L1 | Essaim T1 (64) | 3/3 | 11.1 | 11.1 | 105.8 | 64/64 | 13 | 67.9 | 0 | 84 % | 68·12.5·11.0·5.5 | 0.0 | 1.4 |
| avare | L1 | Mixte + tireurs | 3/3 | 29.1 | 29.0 | 42.6 | 25/25 | 97 | 166.4 | 0 | 24 % | 64·13.1·7.5·4.2 | 3.3 | 1.4 |
| avare | L1 | Élite T3 | 3/3 | 40.1 | 40.1 | 29.9 | 1/1 | 94 | 117.5 | 2 | 0 % | 60·12.0·7.5·3.0 | 9.0 | 1.4 |
| avare | L1 | Mini-boss | 3/3 | 22.0 | 21.9 | 45.6 | 1/1 | 82 | 186.0 | 0 | 18 % | 73·13.7·8.2·2.7 | 0.0 | 1.4 |
| avare | L6 | Essaim T1 (64) | 3/3 | 9.7 | 9.6 | 192.1 | 64/64 | 16 | 30.5 | 0 | 96 % | 77·14.4·12.5·6.3 | 0.0 | 1.4 |
| avare | L6 | Mixte + tireurs | 3/3 | 23.5 | 23.5 | 84.1 | 25/25 | 31 | 24.1 | 0 | 94 % | 70·14.5·7.7·3.3 | 2.0 | 1.4 |
| avare | L6 | Élite T3 | 3/3 | 21.8 | 21.8 | 89.0 | 1/1 | 75 | 58.7 | 0 | 53 % | 70·15.6·8.3·2.8 | 4.7 | 1.4 |
| avare | L6 | Mini-boss | 3/3 | 14.1 | 14.1 | 156.6 | 1/1 | 72 | 94.3 | 0 | 71 % | 82·17.0·8.5·4.2 | 0.0 | 1.4 |
| avare | L12 | Essaim T1 (64) | 3/3 | 9.1 | 9.1 | 279.3 | 64/64 | 0 | 0.0 | 0 | 100 % | 59·17.5·13.2·6.6 | 0.0 | 1.4 |
| avare | L12 | Mixte + tireurs | 3/3 | 18.0 | 18.0 | 150.6 | 25/25 | 16 | 9.0 | 0 | 98 % | 64·18.9·10.0·4.4 | 1.3 | 1.4 |
| avare | L12 | Élite T3 | 3/3 | 10.2 | 10.2 | 258.6 | 1/1 | 0 | 0.0 | 0 | 100 % | 78·19.4·11.8·5.9 | 2.0 | 1.4 |
| avare | L12 | Mini-boss | 3/3 | 9.1 | 9.1 | 355.6 | 1/1 | 60 | 64.9 | 0 | 95 % | 92·20.3·10.8·6.8 | 0.0 | 1.4 |
| bourbe | L1 | Essaim T1 (64) | 3/3 | 15.7 | 15.7 | 73.3 | 64/64 | 0 | 0.0 | 0 | 59 % | 51·31.9·11.5·3.8 | 0.0 | 1.5 |
| bourbe | L1 | Mixte + tireurs | 3/3 | 33.3 | 33.3 | 37.1 | 25/25 | 62 | 115.6 | 0 | 5 % | 50·25.8·9.6·3.6 | 4.3 | 1.5 |
| bourbe | L1 | Élite T3 | 3/3 | 44.9 | 44.9 | 27.0 | 1/1 | 32 | 33.2 | 0 | 2 % | 46·23.2·8.9·3.5 | 8.3 | 1.5 |
| bourbe | L1 | Mini-boss | 3/3 | 23.0 | 23.0 | 43.5 | 1/1 | 85 | 154.5 | 0 | 30 % | 59·28.7·10.4·4.3 | 0.0 | 1.5 |
| bourbe | L6 | Essaim T1 (64) | 3/3 | 9.0 | 9.0 | 204.0 | 64/64 | 0 | 0.0 | 0 | 100 % | 27·46.5·13.3·6.6 | 0.0 | 1.5 |
| bourbe | L6 | Mixte + tireurs | 3/3 | 22.8 | 22.8 | 86.6 | 25/25 | 18 | 13.3 | 0 | 39 % | 48·29.1·10.6·4.3 | 2.7 | 1.5 |
| bourbe | L6 | Élite T3 | 3/3 | 25.9 | 25.9 | 74.1 | 1/1 | 48 | 32.7 | 0 | 16 % | 45·29.3·11.6·4.6 | 4.7 | 1.5 |
| bourbe | L6 | Mini-boss | 3/3 | 19.1 | 19.0 | 116.2 | 1/1 | 78 | 61.4 | 0 | 77 % | 67·31.5·12.6·3.2 | 0.0 | 1.5 |
| bourbe | L12 | Essaim T1 (64) | 3/3 | 9.8 | 9.8 | 259.0 | 64/64 | 0 | 0.0 | 0 | 100 % | 37·42.8·18.4·6.1 | 0.0 | 1.5 |
| bourbe | L12 | Mixte + tireurs | 3/3 | 17.3 | 17.3 | 156.1 | 25/25 | 0 | 0.0 | 0 | 82 % | 29·37.0·13.9·6.9 | 0.3 | 1.5 |
| bourbe | L12 | Élite T3 | 3/3 | 11.2 | 11.2 | 236.0 | 1/1 | 0 | 0.0 | 0 | 87 % | 43·46.3·16.1·5.4 | 2.0 | 1.5 |
| bourbe | L12 | Mini-boss | 3/3 | 13.0 | 13.0 | 242.9 | 1/1 | 47 | 42.0 | 0 | 95 % | 63·43.0·15.3·4.6 | 0.0 | 1.5 |
| vigie | L1 | Essaim T1 (64) | 3/3 | 13.5 | 13.5 | 85.6 | 64/64 | 5 | 24.8 | 0 | 94 % | 101·8.9·8.9·4.5 | 0.0 | 5.5 |
| vigie | L1 | Mixte + tireurs | 3/3 | 23.7 | 23.7 | 51.8 | 25/25 | 27 | 74.9 | 0 | 78 % | 100·8.4·7.6·5.1 | 0.0 | 5.5 |
| vigie | L1 | Élite T3 | 3/3 | 34.7 | 34.7 | 34.6 | 1/1 | 0 | 0.0 | 0 | 100 % | 100·8.7·6.9·3.5 | 0.0 | 5.5 |
| vigie | L1 | Mini-boss | 3/3 | 23.2 | 23.2 | 43.2 | 1/1 | 62 | 177.5 | 0 | 20 % | 100·7.8·5.2·5.2 | 0.0 | 5.5 |
| vigie | L6 | Essaim T1 (64) | 3/3 | 10.0 | 10.0 | 184.2 | 64/64 | 11 | 25.4 | 0 | 95 % | 114·12.0·12.0·6.0 | 0.0 | 5.5 |
| vigie | L6 | Mixte + tireurs | 3/3 | 21.0 | 20.9 | 93.8 | 25/25 | 59 | 66.7 | 0 | 66 % | 114·8.6·8.6·5.7 | 0.7 | 5.5 |
| vigie | L6 | Élite T3 | 3/3 | 20.0 | 20.0 | 95.8 | 1/1 | 0 | 0.0 | 0 | 100 % | 115·9.0·9.0·6.0 | 0.0 | 5.5 |
| vigie | L6 | Mini-boss | 3/3 | 20.0 | 20.0 | 110.4 | 1/1 | 115 | 138.0 | 0 | 45 % | 113·9.0·7.0·6.0 | 0.0 | 5.5 |
| vigie | L12 | Essaim T1 (64) | 3/3 | 11.2 | 11.2 | 229.7 | 64/64 | 0 | 0.0 | 0 | 100 % | 129·12.4·10.9·5.4 | 0.0 | 5.5 |
| vigie | L12 | Mixte + tireurs | 3/3 | 17.5 | 17.4 | 156.1 | 25/25 | 5 | 4.1 | 0 | 97 % | 124·12.6·10.4·6.9 | 0.0 | 5.5 |
| vigie | L12 | Élite T3 | 3/3 | 11.9 | 11.9 | 221.1 | 1/1 | 0 | 0.0 | 0 | 100 % | 131·15.1·10.0·5.0 | 0.0 | 5.5 |
| vigie | L12 | Mini-boss | 3/3 | 14.3 | 14.2 | 221.5 | 1/1 | 72 | 63.6 | 0 | 92 % | 132·12.6·12.6·7.0 | 0.0 | 5.5 |
| morfil | L1 | Essaim T1 (64) | 3/3 | 10.7 | 10.7 | 107.9 | 64/64 | 1 | 3.4 | 0 | 98 % | 86·11.2·5.6·5.6 | 0.0 | 1.6 |
| morfil | L1 | Mixte + tireurs | 3/3 | 33.3 | 33.3 | 37.1 | 25/25 | 43 | 67.5 | 0 | 62 % | 79·11.4·6.0·2.3 | 5.3 | 1.6 |
| morfil | L1 | Élite T3 | 3/3 | 46.1 | 46.1 | 26.1 | 1/1 | 38 | 43.0 | 0 | 29 % | 75·10.4·5.2·2.6 | 10.3 | 1.6 |
| morfil | L1 | Mini-boss | 3/3 | 28.8 | 28.8 | 34.8 | 1/1 | 66 | 119.2 | 0 | 14 % | 85·10.4·6.3·2.1 | 0.0 | 1.6 |
| morfil | L6 | Essaim T1 (64) | 3/3 | 11.2 | 11.2 | 164.6 | 64/64 | 0 | 0.0 | 0 | 100 % | 95·12.4·5.4·5.4 | 0.0 | 1.6 |
| morfil | L6 | Mixte + tireurs | 3/3 | 24.4 | 24.4 | 81.1 | 25/25 | 25 | 20.2 | 0 | 90 % | 87·12.4·5.7·2.5 | 2.3 | 1.6 |
| morfil | L6 | Élite T3 | 3/3 | 27.7 | 27.7 | 69.4 | 1/1 | 65 | 46.3 | 0 | 51 % | 84·12.2·6.5·2.2 | 6.7 | 1.6 |
| morfil | L6 | Mini-boss | 3/3 | 22.7 | 22.7 | 98.1 | 1/1 | 75 | 62.6 | 0 | 66 % | 96·12.3·6.1·2.7 | 0.0 | 1.6 |
| morfil | L12 | Essaim T1 (64) | 3/3 | 9.1 | 9.1 | 279.4 | 64/64 | 0 | 0.0 | 0 | 100 % | 94·15.2·6.6·6.6 | 0.0 | 1.6 |
| morfil | L12 | Mixte + tireurs | 3/3 | 18.0 | 18.0 | 150.0 | 25/25 | 19 | 10.8 | 0 | 97 % | 62·11.1·6.7·3.3 | 0.7 | 1.6 |
| morfil | L12 | Élite T3 | 3/3 | 10.7 | 10.6 | 251.3 | 1/1 | 22 | 22.8 | 0 | 94 % | 94·17.1·5.7·5.7 | 2.3 | 1.6 |
| morfil | L12 | Mini-boss | 3/3 | 13.9 | 13.9 | 227.6 | 1/1 | 32 | 23.3 | 0 | 97 % | 104·17.3·8.7·4.3 | 0.0 | 1.6 |

## Erreurs relevées

- morfil : `ERROR: res://assets/sprites/characters/morfil/morfil.tres:1176 - Parse Error: [ext_resource] referenced non-existent resource at: res://assets/sprites/characters/morfil/sharpen.png`
- morfil : `ERROR: res://assets/sprites/characters/morfil/morfil.tres:1178 - Parse Error: [ext_resource] referenced non-existent resource at: res://assets/sprites/characters/morfil/sharpen.png`
- morfil : `ERROR: res://assets/sprites/characters/morfil/morfil.tres:1180 - Parse Error: [ext_resource] referenced non-existent resource at: res://assets/sprites/characters/morfil/sharpen.png`
- arpenteuse (moteur) : `res://scripts/ambiance/normal_maps.gd:257` Animation 'plant_nw' doesn't exist.
- arpenteuse (moteur) : `res://scripts/ambiance/normal_maps.gd:257` Animation 'whip_nw' doesn't exist.
- arpenteuse (moteur) : `res://scripts/ambiance/normal_maps.gd:257` Animation 'loop_w' doesn't exist.
- arpenteuse (moteur) : `res://scripts/ambiance/normal_maps.gd:257` Animation 'plant_s' doesn't exist.
- arpenteuse (moteur) : `res://scripts/ambiance/normal_maps.gd:257` Animation 'loop_s' doesn't exist.
- arpenteuse (moteur) : `res://scripts/ambiance/normal_maps.gd:257` Animation 'plant_e' doesn't exist.
- arpenteuse (moteur) : `res://scripts/ambiance/normal_maps.gd:257` Animation 'whip_e' doesn't exist.
- arpenteuse (moteur) : `res://scripts/ambiance/normal_maps.gd:257` Animation 'loop_ne' doesn't exist.
- arpenteuse : … (autres erreurs dans art/tools/night/balance_sim/sim_arpenteuse.json)
- morfil (moteur) : `res://scripts/player/player.gd:357` No loader found for resource: res://assets/sprites/characters/morfil/sharpen.png (expected type: Texture2D)
- morfil (moteur) : `res://scripts/player/player.gd:357` No loader found for resource: res://assets/sprites/characters/morfil/twin_draw.png (expected type: Texture2D)
- morfil (moteur) : `res://scripts/player/player.gd:357` No loader found for resource: res://assets/sprites/characters/morfil/dodge.png (expected type: Texture2D)
- morfil (moteur) : `res://scripts/player/player.gd:357` No loader found for resource: res://assets/sprites/characters/morfil/hurt.png (expected type: Texture2D)
- morfil (moteur) : `res://scripts/player/player.gd:357` No loader found for resource: res://assets/sprites/characters/morfil/death.png (expected type: Texture2D)
- morfil (moteur) : `res://scripts/player/player.gd:357` res://assets/sprites/characters/morfil/morfil.tres:1176 - Parse Error: [ext_resource] referenced non-existent resource at: res://assets/sprites/characters/morfi
- morfil (moteur) : `res://scripts/player/player.gd:357` Failed loading resource: res://assets/sprites/characters/morfil/morfil.tres.
- morfil (moteur) : `res://scripts/player/player.gd:357` No loader found for resource: res://assets/sprites/characters/morfil/idle_dual.png (expected type: Texture2D)
- morfil : … (autres erreurs dans art/tools/night/balance_sim/sim_morfil.json)

## Passe d'équilibrage du 22/10/2026 (après le socle commun) : avant / après

Simulateur relancé sur les 8 personnages, 2 graines × 12 combats chacun, avant (socle commun seul, JSON gardés dans
`art/tools/night/balance_sim_before/`) et après la passe. Référence de lecture = **L6**. Décisions de l'orchestrateur :
Ardent garde son identité (débutant, kite, zone) mais baisse un peu ; les 6 nouveaux montent en cible unique ; la
punition de la mêlée baisse par la défense propre à chaque kit (pas de buff général).

#### Niv 6 · Moyen 6 min · 6 objets neutres

Écart vs Ardent **avant → après** (Ardent comparé à lui-même : valeur absolue avant → après). Subis = dégâts subis (% PV/min) en multiple d'Ardent.

| Perso | DPS cible | DPS zone | DPS mixte | TTK élite | TTK mini-boss | Subis (× Ardent) | Morts |
|---|---|---|---|---|---|---|---|
| ardent | 106 → 92 | 194 → 198 | 102 → 103 | 19.5 → 22.4 s | 19.4 → 22.6 s | 25.3 → 25.4 %/min | 0 → 0 |
| rictus | -36 % → **-5 %** | -16 % → **-18 %** | -28 % → **-19 %** | +39 % → **+5 %** | +79 % → **+9 %** | ×1.8 → **×1.4** | 0 → 0 |
| tocsin | -62 % → **+9 %** | -40 % → **+7 %** | -14 % → **-8 %** | +106 % → **-14 %** | +253 % → **-2 %** | ×0.8 → **×1.8** | 0 → 0 |
| averse | -44 % → **-4 %** | +1 % → **+1 %** | -29 % → **-18 %** | +73 % → **+7 %** | +82 % → **+2 %** | ×0.8 → **×1.4** | 0 → 0 |
| arpenteuse | -44 % → **+10 %** | -5 % → **-11 %** | -19 % → **-18 %** | +65 % → **-15 %** | +95 % → **-2 %** | ×1.7 → **×0.9** | 0 → 0 |
| rainette | -40 % → **-5 %** | -19 % → **-21 %** | -10 % → **-5 %** | +51 % → **-1 %** | +86 % → **+12 %** | ×2.5 → **×1.6** | 0 → 0 |
| avare | -8 % → **+9 %** | +0 % → **-2 %** | -18 % → **-18 %** | +9 % → **-6 %** | +11 % → **-8 %** | ×5.2 → **×2.8** | 0 → 0 |
| bourbe | -19 % → **+15 %** | -30 % → **-22 %** | -16 % → **-12 %** | +31 % → **+2 %** | +18 % → **-23 %** | ×3.1 → **×0.4** | 0 → 0 |

#### Niv 1 · Moyen 0 min · sans objet

Écart vs Ardent **avant → après** (Ardent comparé à lui-même : valeur absolue avant → après). Subis = dégâts subis (% PV/min) en multiple d'Ardent.

| Perso | DPS cible | DPS zone | DPS mixte | TTK élite | TTK mini-boss | Subis (× Ardent) | Morts |
|---|---|---|---|---|---|---|---|
| ardent | 33 → 31 | 115 → 112 | 39 → 41 | 39.8 → 41.5 s | 27.2 → 30.0 s | 44.7 → 55.0 %/min | 0 → 0 |
| rictus | -23 % → **+6 %** | -22 % → **-7 %** | -6 % → **-8 %** | +13 % → **-7 %** | +49 % → **-3 %** | ×2.4 → **×1.5** | 0 → 0 |
| tocsin | -55 % → **+31 %** | -47 % → **+2 %** | -33 % → **+27 %** | +63 % → **-28 %** | +216 % → **-20 %** | ×0.9 → **×2.2** | 0 → 0 |
| averse | -31 % → **-1 %** | +4 % → **+2 %** | -8 % → **-4 %** | +46 % → **+3 %** | +44 % → **-1 %** | ×0.6 → **×1.2** | 0 → 1 |
| arpenteuse | -37 % → **+18 %** | -24 % → **-21 %** | +8 % → **-5 %** | +46 % → **-21 %** | +72 % → **-9 %** | ×1.8 → **×1.3** | 0 → 0 |
| rainette | -28 % → **+7 %** | -25 % → **-19 %** | +11 % → **+31 %** | +19 % → **-11 %** | +61 % → **-2 %** | ×2.4 → **×2.1** | 2 → 0 |
| avare | -42 % → **+18 %** | -12 % → **+4 %** | -11 % → **+13 %** | +53 % → **-17 %** | +91 % → **-14 %** | ×5.1 → **×2.9** | 10 → 2 |
| bourbe | -14 % → **+24 %** | -31 % → **-27 %** | +15 % → **+11 %** | +12 % → **-11 %** | +21 % → **-25 %** | ×4.4 → **×0.7** | 4 → 0 |

#### Niv 12 · Difficile ét.3 4 min · 15 objets neutres

Écart vs Ardent **avant → après** (Ardent comparé à lui-même : valeur absolue avant → après). Subis = dégâts subis (% PV/min) en multiple d'Ardent.

| Perso | DPS cible | DPS zone | DPS mixte | TTK élite | TTK mini-boss | Subis (× Ardent) | Morts |
|---|---|---|---|---|---|---|---|
| ardent | 257 → 236 | 256 → 256 | 175 → 176 | 12.3 → 13.2 s | 10.6 → 11.7 s | 4.2 → 4.2 %/min | 0 → 0 |
| rictus | -18 % → **+10 %** | +9 % → **+3 %** | -19 % → **-15 %** | +25 % → **-0 %** | +20 % → **-15 %** | ×7.7 → **×4.9** | 0 → 0 |
| tocsin | -53 % → **+6 %** | -41 % → **-5 %** | -26 % → **-11 %** | +43 % → **-19 %** | +225 % → **+6 %** | ×1.3 → **×4.0** | 0 → 0 |
| averse | -40 % → **+1 %** | +13 % → **+9 %** | -16 % → **-21 %** | +51 % → **-14 %** | +78 % → **+12 %** | ×0.0 → **×0.6** | 0 → 0 |
| arpenteuse | -42 % → **-19 %** | -1 % → **-1 %** | -36 % → **-37 %** | +22 % → **-2 %** | +140 % → **+54 %** | ×2.0 → **×2.4** | 0 → 0 |
| rainette | -33 % → **-17 %** | -8 % → **+20 %** | -14 % → **-12 %** | +29 % → **+5 %** | +67 % → **+36 %** | ×2.5 → **×1.9** | 0 → 0 |
| avare | +12 % → **+20 %** | +6 % → **+5 %** | -11 % → **-11 %** | -19 % → **-24 %** | -3 % → **-10 %** | ×15.6 → **×8.4** | 0 → 0 |
| bourbe | -11 % → **+23 %** | -1 % → **+3 %** | -14 % → **-12 %** | -1 % → **-29 %** | +24 % → **-9 %** | ×9.5 → **×1.8** | 0 → 0 |

### Changements (constantes nommées dans chaque kit ; tests mis à jour)
- **Ardent** : Nova 3,0 → 2,5, Brasier 10 → 8 (`ArdentKit.NOVA_COEF`, `BRASIER_COEF`) : DPS cible −6 à −13 %, zone inchangée.
- **Rictus** : demi-lune 0,6 → 0,8, Éventail 1,2 → 1,6, Doublures 2,5 → 3,0 ; **garde du Montreur** : −30 % de dégâts
  subis pendant 0,5 s après chaque demi-lune (`GUARD_*`).
- **Tocsin** : bug corrigé (instance libérée : `_limb()` teste `is_instance_valid` avant l'affectation typée) ; **auto-cast**
  qui garde le dernier bras tant qu'une jambe est là et lance une botte à la fois (les bottes partaient 0 fois/min) ;
  rivets perforants (pierce 0 → 1, coef 0,8 inchangé), bras 1,5 → 1,8, tête 10 → 12 et +30 % sur les boss. Dégâts subis
  en hausse (×0,8 → ×1,8 à L6) : il se bat enfin au contact et lance ses jambes (cloche-pied) ; reste le plus blindé.
- **Averse** : la Crue n'était jamais lancée en cible unique. **Auto-cast** : Crue prête → Vague/Flaque attendent que
  l'amphore garde 40 d'eau ; **+2 eau par Goutte-lame sur élite/boss** (`BIG_HIT_WATER`) ; Goutte 0,6 → 0,75 (+0,4 × eau),
  Vague 3,0 → 3,5. Crue désormais lancée ~4-5 fois/min contre élite et mini-boss. Multiplicateur de pluie vérifié :
  profils 0,25-1,0 → ×0,75-1,5 (moyenne ≈ ×1,1) ; le repli ×1,0 du simulateur est représentatif, formule inchangée.
- **Arpenteuse** : Chaîne 0,8 → 1,0, Boucle 3,0 → 3,5, **+60 % (additif) des sorts 2-4 sur élites et boss**
  (`BIG_TARGET_ADD`) ; défense : ralentissement de la chaîne 20 → 35 %, étourdissement du Tendeur 1 → 1,5 s.
- **Rainette** : Langue 0,8 → 1,0 (demi-largeur 0,35 → 0,5 u), Grand saut 3,0 → 3,8 (rayon 2,5 → 3 u), Gluant 1,0 → 1,4,
  Chant 3,0 → 3,6 ; défense : bond arrière 3 → 3,5 u, invulnérabilité d'atterrissage du Grand saut 0,15 → 0,35 s, en l'air
  le contact des **boss** est aussi esquivé (elle bondit par-dessus ; projectiles et coups armés à distance touchent).
- **Avare** : puissance plancher +10 % (bourse vide), plafond +90 % → +70 % ; Poignée jamais grisée (fauché : lancer
  gratuit sans pièces rendues) ; défense : armure 15 → 30 et **coffre-bouclier** −45 % de dégâts subis 0,6 s après un
  Coup de coffre ou une Rançon. Morts au niveau 1 : 10 → 2.
- **Bourbe** : les **mottes provoquent aussi les boss** (`Decoy.lures_bosses`, Enemy) ; **vase compacte** : −30 % de
  dégâts subis sans motte dehors, l'avantage fond par motte (0 à 4 mottes) ; Gifle 1,0 (arc 150° → 210°, rayon 1,5 → 2 u),
  mottes 0,4 → 0,45, plouf 0,6 → 1,0 (rayon 1 → 1,5 u), Bourbier 1,0 → 1,4. Morts au niveau 1 : 4 → 0.

### Hooks ajoutés (contrat « Kits de personnage », game/CONTRACTS.md)
- `kit.damage_taken_mult(source) -> float` (Player.take_damage, multiplie la part gardée, sous le plafond de mitigation).
- `kit.auto_cast_ok(slot) -> bool` (SpellCaster, branche auto-cast seulement : le joueur manuel décide seul). C'est
  l'amélioration du pilote : le simulateur utilise l'auto-cast du jeu, donc mieux jouer les combos de Tocsin et
  l'ultime d'Averse améliore aussi l'option d'accessibilité.
- `kit.on_spell_hit(spell, enemy, amount)` (SpellCaster.deal_damage).
- `Decoy.lures_bosses` + `Decoy.nearest_boss_lure()` (provocation des boss, mottes de Bourbe seulement).

### Écarts restants (> ±20 %), à surveiller
- L6 (référence) : seulement DPS zone de Bourbe (−22 %) et de Rainette (−21 %), TTK mini-boss de Bourbe (−23 %, ses
  mottes tiennent le boss).
- L1 : Tocsin au-dessus en cible unique (+31 %, Surchauffe dès qu'un membre part ; Ardent L1 n'a que ~31 DPS), Bourbe
  +24 % cible / −27 % zone, Rainette mixte +31 %. Avare encaisse encore ×2,9 (2 morts contre le mini-boss).
- L12 : Arpenteuse mixte −37 % et mini-boss +54 % (fermer une boucle sur un boss mobile reste rare), Rainette mini-boss
  +36 %, Bourbe +23 % cible. Les ratios de dégâts subis L12 (×4-8 pour Tocsin, Rictus, Avare) portent sur de petites
  valeurs absolues (Ardent 4 % PV/min).
- Limites du simulateur inchangées : pas de carte (Ardent kite sans murs), pilote moyen unique, pas d'AmbianceManager.

### Constat d'origine (analyse avant passe, résumé)
Ardent dominait la cible unique (DPS L6 105 contre 40-98) sans être touché ; la mêlée encaissait 2 à 5× plus pour moins
de DPS ; Tocsin ne lançait jamais ses bottes en auto-cast et levait une erreur d'instance libérée ; Averse ne lançait
jamais la Crue hors essaim ; Avare mourait 10 fois au niveau 1 à 0 or ; Bourbe mourait contre le mini-boss qui ignorait
ses mottes.
