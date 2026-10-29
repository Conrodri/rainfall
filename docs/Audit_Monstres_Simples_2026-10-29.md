# Audit des monstres simples (29/10/2026)

Question du joueur : les monstres non élites meurent un poil trop vite ; ce sont des « trash mobs » presque tout le temps, seuls les boss sont intéressants. Rythme visé à l'origine (CLAUDE.md) : monstres de base fauchés en 1-2 coups, paquets de 3-8.

Consultant : systems-designer. Aucun code modifié. Les valeurs proposées sont à appliquer par l'orchestrateur (fichiers partagés `scripts/core/balance.gd`, `scripts/director/director.gd`).

## 0. Sources et méthode

| Source | Ce qui en est tiré |
|---|---|
| `game/scripts/core/balance.gd` | `TIER_STATS` (18/5, 80/10, 300/24), `LEVEL_HP_GROWTH` 0,30, `LEVEL_DMG_GROWTH` 0,20, `ELITE_HP` 4, `TIER_COST` 1/4/12, `DIRECTOR_MEAN_COST_SLOPE` 0,4, `TIER_MIN_D` {2: 1,35, 3: 2,0}, `elite_chance` 0,05 × (D − 1) plafonnée 0,25, `REWARD_MULT` 0,235, `difficulty()` |
| `game/scripts/director/director.gd` | `_pick_tier`, `T3_SHARE` 0,4, `T3_RAMP_D` 1,0, `LEAPER_SHARE` 0,4 (constantes locales, hors `Balance`) |
| Kits `game/scripts/spells/*_kit.gd` | coefs des sorts 1 (0,8 / 0,6 s pour Ardent, Tocsin, Vigie ; Taliant 1,5 / 0,7 s en cercle…), Nova 2,5, Brasier 8 |
| `game/data/items.json` | Pierre +10 %, Lame jumelle +25 % au sort 1, Lentille +10 % crit, Étincelle (brûlure 240 % du dégât de base), Éclair en bouteille (25 %, 80 % × 3 cibles), Tempête de braises, Peste vivante |
| Journal de run réel `run_20261029-213629` (Tocsin, Moyen, étage 1 complet + début d'étage 2) | kills par minute et par tier, niveau, objets, D |
| Simulateur de combat `balance_sim_run.tscn`, 11 personnages × essaim / mixte / élite × L1 / L6 / L12 (mesuré, 29/10) | DPS de zone et mono, dégâts subis |
| Modèle Python ad hoc (scratchpad, non versionné) | courbes D, niveau, PV, coups pour tuer, composition, flux de PV ; **estimé, non mesuré en jeu** |

Hypothèses du modèle : Moyen (d = 2), chronologie 0-4,5 / 4,5-8,5 / 8,5-12,5 / 12,5-16,5 / 16,5-19,5 min (run ≈ 19,5 min) ; niveau du joueur intégré depuis les crédits du director (≈ 6 à 4,5 min, recoupé avec le journal : niveau 5-6 à 4-5 min) ; objets ≈ 2,1 par minute (journal : 11 à 6,7 min avec un peu de farm) ; build « offensif typique » (Pierre, Lame jumelle, Sifflet, Lentille, Étincelle, Éclair, puis Œil et Danseur à partir de l'étage 3).

Écarts signalés :
- `docs/simulateur_scaling.py` est le modèle v3 (D^1,15, 4 + 2,5 D…) : il ne reflète plus `balance.gd` (§14). Non utilisé pour les conclusions.
- La config `L12` de `balance_sim` est « Difficile étage 3 à 4 min », soit **D = 2,53 (niveau ambiant 5)**. Dans une vraie run Moyen, le joueur est niveau 12 vers l'étage 4, à **D ≈ 4,9 (niveau ambiant 12)** : les PV des monstres y sont 1,9 fois plus hauts. Les mesures L12 du simulateur sont donc optimistes pour le joueur. Proposer une config `L12m` (Moyen, étage 4, 14 min, ≈ 30 objets).
- Le commentaire de `DIFFICULTY_TIERS` (« coeff ≈ 3 en fin d'étage 5 ») est périmé : la formule donne **D ≈ 6,9** à 19,5 min en Moyen.

## 1. Formules en vigueur

**PV d'un monstre** : `PV = PV_base(tier) × (1 + 0,30 × (niv − 1)) × (4 si élite)`, avec `niv = 1 + ⌊(D − 1) / 0,33⌋`.

| Symbole | Type | Plage | Sens |
|---|---|---|---|
| PV_base | constante | 18 / 80 / 300 | `TIER_STATS[tier].hp` (essaim / tireur et bondisseur / brute) |
| D | réel | 1 → 6,9 (Moyen, 19,5 min) | `Balance.difficulty(t, étage, 2)` = (1 + 0,1518 × min) × 1,15^(étage − 1) |
| niv | entier | 1 → 18 | niveau ambiant, marche d'escalier tous les 0,33 de D |

Sortie : linéaire en D, non plafonnée ; min 18 PV (essaim, D = 1), ≈ 1 830 PV (brute, fin d'étage 5), ×4 en élite. La même croissance 0,30 sert à `boss_hp` : tout changement de `LEVEL_HP_GROWTH` toucherait les boss (gelés).

**Coup du joueur** : `coef × (12 + 2,4 × (L − 1)) × (1 + Σ bonus additifs) × crit`. Le dégât de base croît linéairement en L, et L croît en logarithme de l'XP (`1 + log1,55(1 + 0,076 XP)`) : sans objets, le joueur prendrait du retard sur les PV. Ce sont les objets (additifs + procs) qui font la différence.

## 2. Courbes au fil d'une run (Moyen)

### 2.1 PV des monstres simples et coup auto d'Ardent (coef 0,8)

| Moment | t (min) | D | niv | Essaim | Tireur / bondisseur | Brute | Élite essaim | Élite brute | L joueur | Objets | Coup auto (direct) | Multiplicateur moyen (crit + brûlure) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Ét. 1 début | 0,1 | 1,01 | 1 | 18 | 80 | 300 | 72 | 1 200 | 1 | 0 | 10 | ×1,01 |
| Ét. 1 milieu | 2,2 | 1,34 | 2 | 23 | 104 | 390 | 94 | 1 560 | 3 | 5 | 14 | ×1,01 |
| Ét. 1 fin | 4,5 | 1,68 | 3 | 29 | 128 | 480 | 115 | 1 920 | 6 | 9 | 26 | ×1,44 |
| Ét. 2 début | 4,5 | 1,94 | 3 | 29 | 128 | 480 | 115 | 1 920 | 7 | 10 | 29 | ×1,44 |
| Ét. 2 milieu | 6,5 | 2,28 | 4 | 34 | 152 | 570 | 137 | 2 280 | 8 | 14 | 31 | ×1,44 |
| Ét. 2 fin | 8,4 | 2,63 | 5 | 40 | 176 | 660 | 158 | 2 640 | 9 | 18 | 37 | ×1,44 |
| Ét. 3 début | 8,6 | 3,04 | 7 | 50 | 224 | 840 | 202 | 3 360 | 10 | 18 | 38 | ×1,44 |
| Ét. 3 milieu | 10,5 | 3,43 | 8 | 56 | 248 | 930 | 223 | 3 720 | 10 | 22 | 40 | ×1,57 |
| Ét. 3 fin | 12,4 | 3,82 | 9 | 61 | 272 | 1 020 | 245 | 4 080 | 11 | 26 | 52 | ×2,25 |
| Ét. 4 début | 12,6 | 4,42 | 11 | 72 | 320 | 1 200 | 288 | 4 800 | 11 | 26 | 53 | ×2,25 |
| Ét. 4 milieu | 14,5 | 4,87 | 12 | 77 | 344 | 1 290 | 310 | 5 160 | 12 | 30 | 66 | ×2,25 |
| Ét. 4 fin | 16,4 | 5,32 | 14 | 88 | 392 | 1 470 | 353 | 5 880 | 13 | 35 | 69 | ×2,47 |
| Ét. 5 début | 16,6 | 6,14 | 16 | 99 | 440 | 1 650 | 396 | 6 600 | 13 | 35 | 70 | ×2,47 |
| Ét. 5 milieu | 18,0 | 6,53 | 17 | 104 | 464 | 1 740 | 418 | 6 960 | 13 | 38 | 74 | ×2,94 |
| Ét. 5 fin | 19,4 | 6,91 | 18 | 110 | 488 | 1 830 | 439 | 7 320 | 14 | 41 | 76 | ×2,94 |

Estimé, non mesuré en jeu (sauf l'étage 1, recoupé avec le journal Tocsin). Le multiplicateur moyen compte le critique et la brûlure d'Étincelle (240 % du dégât de base, étalée sur 3 s) ; il ne compte ni l'Éclair en bouteille, ni la traversée, ni les explosions à la mort.

### 2.2 Coups pour tuer (sort 1 d'Ardent, coup direct sans critique)

| Moment | Essaim | Tireur / bondisseur | Brute | Essaim, valeur moyenne avec procs | Nova (2,5) : part de la Nova nécessaire essaim / tireur / brute |
|---|---|---|---|---|---|
| Ét. 1 début | 1,9 | 8,3 | 31 | 1,8 | 0,60 / 2,7 / 9,9 |
| Ét. 1 fin | 1,1 | 4,9 | 18 | 0,8 | 0,43 / 1,9 / 7,2 |
| Ét. 2 début | **1,0** | 4,4 | 16 | **0,7** | 0,39 / 1,7 / 6,4 |
| Ét. 2 fin | 1,1 | 4,8 | 18 | 0,8 | 0,42 / 1,9 / 6,9 |
| Ét. 3 milieu | 1,4 | 6,2 | 23 | 0,9 | 0,54 / 2,4 / 9,0 |
| Ét. 3 fin | 1,2 | 5,2 | 20 | **0,5** | 0,52 / 2,3 / 8,7 |
| Ét. 4 milieu | 1,2 | 5,2 | 20 | 0,5 | 0,49 / 2,2 / 8,2 |
| Ét. 5 fin | 1,4 | 6,4 | 24 | 0,5 | 0,59 / 2,6 / 9,8 |

Courbe en texte, coups d'auto pour tuer un essaim (direct `#`, avec procs moyens `·`) :

```
2.0 |#
1.5 |#·          #           #  #        #
1.0 |   #  #  # ·    #  #  #     #  #  #
0.5 |    ·  ·  ·   ·  ·  ·  ·  ·  ·  ·  ·
    +--------------------------------------
     1d 1m 1f 2d 2m 2f 3d 3m 3f 4d 4m 4f 5d 5m 5f
```

Lecture :
- **La courbe des PV n'est pas en cause en coups directs** : l'essaim reste entre 1,0 et 1,4 coup d'auto du milieu de l'étage 1 à la fin de la run ; la croissance linéaire des PV suit à peu près le dégât de base + les bonus additifs.
- **Bascule en « trash » (moins d'un coup)** : à la fin de l'étage 1 et au début de l'étage 2 (9-14 objets, niveau ambiant bloqué à 3-4 alors que le joueur passe de 6 à 8). Puis de nouveau dès la fin de l'étage 3, quand la Lentille et l'Œil font monter le critique : la valeur moyenne tombe à **0,5 coup**. C'est la boule de neige des objets, portée par les **probabilités** (critique, brûlure, Éclair), pas par les bonus plats.
- **Les sorts de zone fauchent l'essaim toute la run** : la Nova n'a besoin que de 40 à 60 % de sa puissance pour tuer un essaim, à tout moment. Il en va de même pour la Tête-cloche de Tocsin, le Brasier, la Vague d'Averse. C'est voulu (fauchage) et c'est à garder.
- **Tireur et brute ne deviennent jamais du « trash » en coups** (4-6 coups pour un tireur, 16-24 pour une brute). Le problème est ailleurs : on n'en voit presque pas (§3).

### 2.3 Temps pour tuer (mono-cible, tout le kit)

DPS mono mesuré au simulateur (scénario élite, moyenne des 11 personnages) : L1 ≈ 30, L6 ≈ 88, L12 ≈ 220 ; interpolé selon le niveau du modèle.

| Étage (milieu) | L | DPS mono | Essaim | Tireur | Brute | Élite tireur | Élite brute |
|---|---|---|---|---|---|---|---|
| 1 | 3 | 55 | 0,42 s | 1,9 s | (absente) | 7,6 s | 28 s |
| 2 | 8 | 135 | **0,25 s** | 1,1 s | 4,2 s | 4,5 s | 17 s |
| 3 | 10 | 183 | 0,31 s | 1,4 s | 5,1 s | 5,4 s | 20 s |
| 4 | 12 | 218 | 0,35 s | 1,6 s | 5,9 s | 6,3 s | 24 s |
| 5 | 13 | 243 | 0,43 s | 1,9 s | 7,2 s | 7,6 s | 29 s |

Le creux est à l'étage 2 : le tireur y meurt en 1,1 s et la brute en 4 s. Écart entre personnages (DPS mono à L6) : 67 (Rictus, Tocsin) à 112 (Arpenteuse), hors cible ±20 % pour Arpenteuse (voulu 1,30) ; c'est le sujet de `docs/Equilibrage_Personnages.md`, pas de cet audit.

## 3. Rôle du monstre simple dans la boucle : qu'est-ce qui rend la chose plate ?

### 3.1 Mesures

**Journal réel (Tocsin, étage 1, kills par minute [essaim, tireur/bondisseur, brute, élites])** :

| Minute | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| D | 1,15 | 1,30 | 1,46 | 1,61 | 1,76 | 1,91 | 2,37 | 2,50 |
| Kills | 22/0/0/0 | 31/0/0/0 | 50/1/0/0 | 111/1/0/2 | 123/7/0/3 | 117/3/0/2 | 56/1/0/4 | 42/3/0/6 |

Sur 7,7 minutes : **≈ 95 % d'essaims, 3 % de tir 2, 0 brute**. Le tier 3 n'apparaît qu'à D ≥ 2,0, soit au boss de l'étage 1, et seulement à 2 % des tirages jusqu'à D ≈ 2,5.

**Simulateur (11 personnages)** : essaim de 64 monstres (32 d'un coup) nettoyé en 8 à 14 s ; **dégâts subis 0** à L6 et L12 pour 10 personnages sur 11 (Vigie : 6). Mixte (25 monstres dont 6 tireurs et une brute) : 0 à 3 coups subis à L6/L12, PV minimum ≥ 87 % sauf Arpenteuse (53 %) et Bourbe.

**Composition du director (modèle, `_pick_tier`, coût moyen visé 1 + 0,4 (D − 1))** :

| Étage (milieu) | D | Essaim / tireur / brute | Élites | Corps par seconde (hors zone) |
|---|---|---|---|---|
| 1 | 1,34 | 100 / 0 / 0 | 2 % | 1,27 |
| 2 | 2,28 | 87 / 12 / 1 | 6 % | 0,86 |
| 3 | 3,43 | 82 / 13 / 5 | 12 % | 0,67 |
| 4 | 4,87 | 71 / 21 / 8 | 19 % | 0,53 |
| 5 | 6,53 | 58 / 30 / 12 | 25 % | 0,45 |

**Menace (dégâts des monstres / PV du joueur)** : morsure d'essaim 5 × (1 + 0,2 (niv − 1)) contre 100 + 30 PV par niveau : 2,5 % des PV à l'étage 1, ≈ 3 % à l'étage 4 (16 sur ≈ 500). Tir : ≈ 7 %. Brute : ≈ 15-18 % (plafond 25 % pour une élite).

### 3.2 Diagnostic, par ordre de poids

1. **Densité et composition (cause principale)**. Jusqu'à l'étage 3, plus de 80 % des corps sont des essaims, la brute est absente des étages 1-2 et les élites restent sous 12 %. Comme l'essaim meurt en un coup ou dans n'importe quelle zone, la run *est* faite de trash. Le monstre « intéressant » existe (tireur avec armement 0,7 s et repli, bondisseur, brute à cône), mais le director en achète très peu.
2. **Sorts de zone et procs** : chaque sort à recharge tue l'essaim à 40-60 % de sa puissance ; à partir de l'étage 3 le critique et les procs mettent la valeur moyenne d'un coup d'auto à 2 essaims. Voulu pour l'essaim, mais cela touche aussi le tireur (1,1-1,9 s).
3. **Menace faible** : morsure à 3 % des PV, aucun coup subi dans les essaims simulés. Le monstre simple n'est ni un danger ni une question de positionnement ; il est une ressource d'XP et d'or, et un compteur de kills.
4. **PV** : en coups directs, la courbe tient (1,0-1,4 coup). Monter les PV de tout le monde n'améliore ni la composition ni la menace, et coûte du débit (XP et or perçus).

Rôle voulu, à mon sens : **l'essaim reste la ressource** (fauché en zone, ≈ 1-2 coups d'auto), **le tireur est une question de positionnement** (2-3 s, il faut l'aller chercher), **la brute est un mur** (6-10 s seule, elle bloque un couloir et force à la contourner ou à sortir la grosse recharge), **l'élite est un mini-événement** (8-40 s).

### 3.3 Économie : un levier neutre

La prime d'un kill est proportionnelle à son coût (`monster_xp = D × coût × 0,235`, or = 2×). Le director dépense ses crédits, donc **l'XP et l'or par seconde ne dépendent pas de la composition** tant que le joueur tue au rythme où le director achète. Seuls deux paramètres économiques comptent :
- le **flux de PV** que le joueur doit abattre (PV par crédit × crédits/s) ; s'il dépasse le débit du joueur, les crédits s'accumulent (`CREDIT_BANK_MAX` 1 000) et l'XP n'est pas perçue ;
- la durée d'étage, fixée par la charge des piliers (`PILLAR_CHARGE_S` 60 s) et les boss, que cet audit ne touche pas.

PV par crédit actuels : essaim 18, tireur 20, brute 25. Augmenter les PV **et** le coût d'un tier ensemble rend le monstre plus solide sans changer le flux ni l'économie, et réduit le nombre de corps (performance).

## 4. Options

### Option R (Recommandé) : « moins de corps, plus de poids »

Changer la composition et la solidité des tiers 2-3 en gardant le flux de PV presque constant ; ne pas toucher à l'essaim de l'étage 1.

1. **Croissance des PV par tier, séparée de celle des boss** : nouvelle constante `MONSTER_HP_GROWTH := {1: 0.33, 2: 0.36, 3: 0.40}` utilisée par `monster_hp(base, D, tier)` ; `LEVEL_HP_GROWTH` 0,30 reste pour `boss_hp` (gel des boss).
2. **Bases** : tireur/bondisseur 80 → 90, brute 300 → 360.
3. **Coûts** : tier 2 4 → 5, tier 3 12 → 16 (la prime suit : économie par crédit inchangée ; le tireur rapporte +25 %, la brute +33 %, le joueur le sent).
4. **Composition** : `DIRECTOR_MEAN_COST_SLOPE` 0,4 → 0,55 ; `TIER_MIN_D[3]` 2,0 → 1,6 (première brute vers 4 min, pendant la charge du gros pilier de l'étage 1) ; `T3_SHARE` 0,4 → 0,5 (à déplacer dans `Balance`).
5. **Élites** : pente de `elite_chance` 0,05 → 0,06 (plafond 0,25 inchangé) ; `WAVE_LEADER_BASE` 0,15 → 0,20.
6. **Brute « mur »** : `KB_MASS[3]` 0,4 → 0,25 (elle recule moins sous le tir ; c'est le seul changement de ressenti en mêlée).

Formule résultante :

`PV = PV_base(tier) × (1 + g(tier) × (niv − 1)) × (4 si élite)` ; g = 0,33 / 0,36 / 0,40 ; PV_base = 18 / 90 / 360.

| Symbole | Type | Plage | Sens |
|---|---|---|---|
| g(tier) | constante | 0,30-0,42 | croissance par niveau ambiant, par tier |
| niv | entier | 1-18 en Moyen | `monster_level(D)` |

Sortie : bornée par niv ; essaim 18 → 117 PV, tireur 90 → 640, brute 360 → 2 800 (fin d'étage 5, D = 6,9) ; aucune valeur inutilisable (g > 0, PV > 0).

Exemple chiffré (étage 4, D = 4,87, niv 12) : brute = 360 × (1 + 0,40 × 11) = 1 944 PV (actuel 1 290) ; à 218 de DPS mono : 8,9 s (actuel 5,9 s).

Effets (modèle, estimé, non mesuré en jeu) :

| Étage | Essaim / tireur / brute (actuel → R) | Élites | Coups d'auto essaim / tireur / brute | TTK mono tireur / brute | Flux de PV | Corps/s |
|---|---|---|---|---|---|---|
| 1 | 100/0/0 → 100/0/0 | 2 % | 1,7 / 7,6 → 8,9 / (28 → 37 au boss) | 1,9 → 2,2 s / — | +2 % | −2 % |
| 2 | 87/12/1 → 90/8/3 | 6 → 8 % | 1,1 / 4,8 → 6,0 / 18 → 25 | 1,1 → 1,4 s / 4,2 → 5,9 s | +6 % | −15 % |
| 3 | 82/13/5 → 83/12/6 | 12 → 15 % | 1,4 → 1,5 / 6,2 → 8,0 / 23 → 34 | 1,4 → 1,7 s / 5,1 → 7,5 s | +8 % | −22 % |
| 4 | 71/21/8 → 72/19/9 | 19 → 23 % | 1,2 → 1,3 / 5,2 → 6,8 / 20 → 30 | 1,6 → 2,0 s / 5,9 → 8,9 s | +9 % | −26 % |
| 5 | 58/30/12 → 60/26/13 | 25 % | 1,4 → 1,5 / 6,3 → 8,2 / 23 → 36 | 1,9 → 2,5 s / 7,2 → 11 s | +13 % | −21 % |

- **TTK** : essaim +0-8 % (fauchage intact), tireur +20-30 %, brute +45-55 %, élites +20-50 %.
- **Durée d'étage** : inchangée à ±10 s (charge à durée fixe, PV des boss intacts) ; l'arène de charge se vide un peu moins vite.
- **XP et or** : identiques par crédit ; flux de PV +2 à +13 %, donc perte d'XP perçue nulle si le joueur suit, au pire ≈ −5 % en zone de charge tardive (≈ −0,2 niveau en fin de run).
- **Performance** : −15 à −26 % de corps à partir de l'étage 2, à crédits égaux : moins de séparation, de snapshots et de cadavres.
- Théorie : la difficulté RoR2 « achète des monstres plus forts, pas une foule plus grande » (commentaire de `RAMP_ALIVE_MAX`), poussée plus loin ; la prime proportionnelle au coût garde l'économie neutre (programme à ratio variable inchangé côté coffres).

### Variante A : pente de PV plus raide pour tous

Une seule constante : `MONSTER_HP_GROWTH` 0,36 pour les 3 tiers (boss inchangés, toujours 0,30). Composition, coûts et élites inchangés.

| Étage | Coups d'auto essaim / tireur / brute | TTK mono tireur / brute | Flux | Corps/s |
|---|---|---|---|---|
| 1 | 2,0 / 7,9 / 30 | 2,0 s / — | +5 % | 0 |
| 3 | 2,0 / 8,0 / 30 | 1,5 s / 5,8 s | +14 % | 0 |
| 5 | 2,6 / 10,3 / 38 | 2,2 s / 8,3 s | +17 % | 0 |

- Avantages : un seul nombre, l'essaim tient un peu mieux (« un poil »), facile à annuler.
- Inconvénients : ne règle pas la cause principale (95 % d'essaims à l'étage 1, aucune brute avant l'étage 2) ; aucun gain de performance ; le flux monte de 17 % sans compensation, donc saturation possible en zone de charge tardive. La Nova continue de faucher l'essaim (0,5-0,7 de sa puissance).
- Plage sûre : 0,33-0,38. Au-delà de 0,40, l'essaim de fin de run demande plus de 2 coups d'auto et le flux dépasse +25 %.

### Variante B : brute à garde frontale, PV inchangés

Composition et coûts comme R (`DIRECTOR_MEAN_COST_SLOPE` 0,55, `TIER_MIN_D[3]` 1,6, `TIER_COST` 5/16, élites 0,07), PV et croissance inchangés, plus un comportement : **garde frontale de la brute**, `BRUTE_FRONT_DAMAGE_TAKEN` = 0,7 (−30 % sur les coups venus d'un cône de ±60° devant elle, selon `hit.source_pos`), sans effet sur les brûlures, poisons et la foudre (pas de `source_pos`), garde levée pendant l'armement du cône et la récupération (`BRUTE_RECOVERY_S` 0,4 s : fenêtre de punition).

- Avantages : la brute devient une question de positionnement (contourner, frapper pendant la récupération) ; contre-jeu au sens de Sirlin, sans interdiction ; flux de PV −11 à −20 %, donc l'économie perçue s'améliore ; −20 à −29 % de corps.
- Inconvénients : tireur et essaim inchangés (ne répond pas au « un poil » pour eux) ; à manette et sur mobile avec visée auto, le joueur ne choisit pas l'angle de ses projectiles : la garde pénalise davantage les kits à distance (Vigie, Ardent, Tocsin) que les mêlées qui tournent autour ; demande un retour visuel (bouclier qui brille) et un son de coup paré ; code dans `enemy.gd` (`take_damage`).
- TTK brute : +20 % en moyenne (moitié des coups de face) ; tireur et essaim 0 %.

### Option écartée : armure plate (réduction fixe par coup)

Une réduction plate (ex. −5 dégâts par coup sur la brute) frappe d'abord les kits à petits coups répétés : tics de Cendres (0,5 × 12 = 6 à L1), Toupie de Rictus (0,42), Chaîne d'Arpenteuse, tics de brûlure et de poison. Elle casserait l'équilibre ±20 % entre personnages et l'intérêt des objets à proc ; la réduction en pourcentage (variante B) n'a pas ce défaut.

## 5. Recommandation (Recommandé : option R)

| Constante / clé | Actuel | Proposé | Plage sûre |
|---|---|---|---|
| `Balance.MONSTER_HP_GROWTH` (nouvelle, par tier ; `monster_hp` reçoit le tier) | 0,30 pour tous (via `LEVEL_HP_GROWTH`) | {1: 0,33, 2: 0,36, 3: 0,40} | T1 0,30-0,35 ; T2 0,33-0,38 ; T3 0,36-0,42 |
| `Balance.LEVEL_HP_GROWTH` (boss seulement) | 0,30 | 0,30 (inchangé, gel des boss) | — |
| `Balance.TIER_STATS[2].hp` | 80 | 90 | 85-95 |
| `Balance.TIER_STATS[3].hp` | 300 | 360 | 330-390 |
| `Balance.TIER_COST[2]` | 4 | 5 | 4-5 |
| `Balance.TIER_COST[3]` | 12 | 16 | 14-18 |
| `Balance.DIRECTOR_MEAN_COST_SLOPE` | 0,4 | 0,55 | 0,5-0,6 |
| `Balance.TIER_MIN_D[3]` | 2,0 | 1,6 | 1,5-1,75 |
| `T3_SHARE` (`director.gd`, à déplacer dans `Balance`) | 0,4 | 0,5 | 0,45-0,55 |
| Pente de `Balance.elite_chance` (nouvelle constante `ELITE_CHANCE_SLOPE`) | 0,05 | 0,06 | 0,05-0,07 |
| `Balance.WAVE_LEADER_BASE` | 0,15 | 0,20 | 0,15-0,25 |
| `Balance.KB_MASS[3]` | 0,4 | 0,25 | 0,2-0,3 |

À garder tel quel : `TIER_STATS[1]` (18 PV, 2 coups d'auto à L1), `TIER_MIN_D[2]` 1,35 (retour joueur « mort avant 2 min »), `RAMP_*`, `REWARD_MULT`, `CREDIT_K`, coefs des sorts de zone (fauchage de l'essaim), dégâts des monstres (`LEVEL_DMG_GROWTH` 0,20).

Ordre d'application conseillé : d'abord la composition (coûts, pente, `TIER_MIN_D[3]`, `T3_SHARE`, élites), mesurer en jeu, puis la croissance par tier. Si le joueur trouve encore l'essaim trop fragile après cela, ajouter `MONSTER_HP_GROWTH[1]` 0,33 → 0,35 (variante A partielle).

Protocole de vérification (mode test et simulateur) :
1. `balance_sim_run.tscn -- --scen=swarm,mixed,elite --cfg=L1,L6,L12` avant/après : temps de nettoyage de l'essaim ±10 %, mixte +15-25 %, élite brute +40-50 %.
2. Ajouter une config `L12m` (Moyen, étage 4, 870 s, ≈ 30 objets) : les mesures L12 actuelles sont à D 2,5, pas 4,9.
3. Run complète Moyen avec `RunLog` : part de brutes dans les kills de l'étage 2 ≥ 3 %, élites 8-15 % à l'étage 3, niveau en fin d'étage 1 ≈ 7 (inchangé), or de fin d'étage ±10 %.
4. Mode test, D réglée à 4,9 : une brute seule doit tenir ≈ 9 s face au sort 1 + sorts à recharge ; un paquet de 8 essaims doit tomber sur une Nova.

## 6. Risques et points à trancher

- **Contrat** : `Balance.monster_hp(base, D)` devient `monster_hp(base, D, tier)` ; appelant `enemy.gd:429`, tests `test_balance.gd`. `T3_SHARE`, `T3_RAMP_D` et `LEAPER_SHARE` sont des nombres d'équilibrage hors `Balance` (règle du projet) : à déplacer.
- **Compteurs par kill** (−15 à −26 % de corps) : déblocages « 300 kills avec Cendres », « 200 monstres à moins de 2 u », Vigie « 100 monstres à plus de 8 u », Moisson (+0,2 % par kill, plafond atteint ≈ 20 % plus tard), Morsure vorace (soin par kill), Cœur du chronomancien (10 kills en 3 s, plus rare hors essaims). À revoir avec la revue des objets ; les 3 déblocages se gagnent surtout sur l'essaim, donc peu touchés.
- **Explosions proportionnelles aux PV max** : Tempête de braises (30 % des PV max du mort sur 4 ennemis) et Peste vivante (25 %) grossissent avec les PV des brutes (+50 %) : une brute qui meurt en brûlant fait 580 dégâts à l'étage 4 et efface tout un paquet. Le plafond « un boss compte au plus pour 40 coups de dégât de base » existe pour la Tempête ; en proposer un pour les brutes (ex. 12 coups de dégât de base) et vérifier les chaînes d'explosions (perf mobile : une explosion par mort, en cascade).
- **Saturation en zone de charge** (×2,33) en fin de run : flux +9 à +13 % aux étages 4-5. Ajouter au `RunLog` le nombre de vivants par minute et les crédits reportés pour le vérifier ; si les crédits dépassent 500 en zone, baisser `MONSTER_HP_GROWTH[3]` à 0,38.
- **Brute à l'étage 1** : apparaît à D 1,6, soit vers 4 min, pendant la charge. 504 PV à ce moment, ≈ 6 s pour un joueur niveau 5-6 ; coup de 29 sur ≈ 220 PV (13 %), sous le plafond de 25 %. À surveiller avec Bourbe (60 PV à L1 sans masse) et Vigie (PV min 11 % dans le mixte L1).
- **Combos (docs/Design_Combos.md, en cours)** : Nova 2,5 → 2,3 et Brasier 8 → 7,4, +30 % sur les cibles préparées. Sur l'essaim, rien ne change (la Nova 2,3 le tue encore à 45-65 % de sa puissance) ; sur le tireur, il faut ≈ 8 % de Novas en plus, cumulé avec R ≈ +35 %. Relancer le simulateur après les deux chantiers, pas avant.
- **Boule de neige des procs** : la valeur moyenne d'un coup d'auto double entre les étages 2 et 5 (critique linéaire de la Lentille, brûlure cumulable). C'est ce qui ramène l'essaim à 0,5 coup ; ce n'est pas un problème pour l'essaim (voulu), mais la Lentille linéaire (+10 % par exemplaire, 100 % de critique à 10 exemplaires) mérite d'être vue dans la revue des objets.
- **Menace** : laissée de côté volontairement (retours « mort avant 2 min »). Si R ne suffit pas à rendre les monstres intéressants, le levier suivant est le comportement (morsure de meute de l'essaim, salve du tireur plus fréquente à D ≥ 3), pas les dégâts bruts.
- **Écart mesuré / modèle** : tous les chiffres d'étage 2-5 viennent du modèle (niveau et objets estimés). Un seul journal de run réel existe (Tocsin, étage 1 + 1 minute d'étage 2) ; il faut 3-5 runs complètes journalisées pour recaler.
