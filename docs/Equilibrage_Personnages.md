# Équilibrage des personnages jouables (audit du 23/10/2026)

> Audit **en lecture seule** (méthode `.claude/skills/balance-check`, rôle `systems-designer`). Aucun fichier du jeu modifié.
> Personnages : Ardent (référence), Rictus, Tocsin, Averse, Arpenteuse, Rainette, Avare, Bourbe, Vigie, Taliant (`morfil`).
> Les recommandations Averse sont **indicatives** : un autre agent corrige Averse en parallèle.
> Les mesures sont dans le scratchpad (`balance_all/sim*.json`, `seed*.json`, `agg2.txt`). Elles n'ont pas été versées dans le dépôt.

## 0. Sources, mesures et limites de méthode

### Fichiers lus

| Fichier | État |
|---|---|
| `game/scripts/core/balance.gd` (difficulté, monstres, boss, joueur) | TROUVÉ |
| `game/scripts/spells/<id>_kit.gd` pour les 10 personnages, avec leurs auxiliaires (`decoy`, `tocsin_limb`, `rainette_goo`, `avare_purse_tip`, `bourbe_motte`, `vigie_flare`, `morfil_twin_blade`) | TROUVÉ |
| `game/scripts/spells/spell_caster.gd`, `zone_effect.gd`, `spell_data.gd` | TROUVÉ |
| `game/data/characters.json`, `game/data/floors.json` (`final_boss_hp_mult` = 2,0) | TROUVÉ |
| `docs/Maths_Scaling.md` §5, §14 ; `docs/Design_Etages.md` | TROUVÉ |
| `docs/fiches/vigie.md`, `docs/fiches/morfil.md` | TROUVÉ |
| Fiches des 8 autres personnages | ABSENT |

### Commandes lancées

**Combats scriptés : un passage complet (1 graine).**
- Commande : `balance_sim_run.tscn`, 4 scénarios × L1/L6/L12 × 10 personnages.
- Résultat : `RESULT: OK` sur les deux processus.

**Combats scriptés : trois graines.**
- Commande : `balance_sim_run.tscn --scen=mixed,elite,miniboss --cfg=L6,L12 --seeds=3`.
- Écarts-types faibles : 0,0 à 3,5 s.

**Simulateur historique : `docs/simulateur_scaling.py moyen`.**
- Ce modèle est v3 sur 3 étages, avec d'anciennes formules de PV de boss (`D^1,6`, base 2200). Il **ne concorde pas** avec `balance.gd` (§14 : base 3000 × niveau × √D × 0,95^(étage-1), 5 étages).
- Il sert seulement d'ordre de grandeur. Je ne l'ai pas utilisé pour les durées de boss.

**Calculs ad hoc (scripts Python dans le scratchpad).**
- PV des boss par étage, et temps pour tuer (TTK) estimé.
- Tous ces résultats sont marqués « estimé ».

### Charge machine
Pendant les mesures, 5 à 7 autres processus Godot tournaient : ce sont d'autres tests, je n'en ai tué aucun.
- Le simulateur avance à pas fixe (K = 12 ticks de 1/60 s), donc les résultats sont déterministes et ne dépendent pas de la charge.
- Seul le temps réel d'exécution a été allongé.

### Limites à garder en tête
1. **Le pilote du simulateur est un « joueur moyen » en lancer automatique.**
   - Il ne ramasse pas les membres de Tocsin.
   - Il ne trace pas la chaîne d'Arpenteuse à travers les paquets.
   - Il lance la Crue d'Averse à 75 d'eau (`AUTO_CRUE_AT`), jamais à 100.
   - Il ne thésaurise pas l'or d'Avare : l'or est fixé à 150 en L6 et à 400 en L12.
   - **Les stratégies d'un humain qui optimise ne sont donc pas mesurées.** Pour celles-ci, j'utilise le calcul théorique.
2. **Les combats sont courts (9 à 38 s).** Un ultime n'est lancé qu'une ou deux fois, ce qui sous-pèse les ultimes à forte recharge et les ressources qui s'accumulent.
3. **Le scénario « swarm » (essaim) ne discrimine pas.** La durée y est dominée par l'approche des monstres (8 à 14 s pour tous). J'ai retenu :
   - « mixed » pour la zone (paquets de 3-6 + tireurs) ;
   - « elite » et « miniboss » pour le mono-cible.
4. **Pas de scénario « boss d'étage » dans le simulateur.** Le TTK par étage est donc **estimé** (§3).

### Notations
- **B** = dégât de base = `Balance.player_base_damage(L)` = 12 + 2,4 (L-1).
- Un coup inflige coef × B × (1 + Σadd) × Πmult.
- **Ratio vs Ardent** = durée d'Ardent / durée du personnage pour le même combat (> 1 : plus rapide qu'Ardent). C'est un ratio de DPS effectif.

---

## 1. Verdict global : **À SURVEILLER** (deux points **CRITIQUES** côté joueur humain)

### Points critiques
- **Crue d'Averse** : un ultime sans recharge qui écrase le kit en jeu manuel. Le retour joueur le confirme.
- **Mottes de Bourbe** : elles attirent aussi les boss. En simulation, le mini-boss ne lui inflige **0 dégât** (L6 et L12).

### Ratios de DPS mesurés
Moyenne géométrique sur 3 graines, en L6 et L12 :

| Perso | Global (6 combats) | Mono (élite + mini-boss) | Zone (mixte) | Mini-boss L6 / L12 | Hors ±20 % ? |
|---|---|---|---|---|---|
| Ardent | 1,00 | 1,00 | 1,00 | 1,00 / 1,00 | réf. |
| Rictus | 1,02 | 1,17 | **0,78** | **1,41 / 1,44** | mono sur boss, zone |
| Tocsin | 1,09 | 1,18 | 0,92 | **1,22** / 1,05 | élite (1,26 / 1,20) |
| Averse (bot) | 1,03 | 1,10 | 0,89 | 1,14 / 1,10 | non en bot, **oui en manuel** (§2.3) |
| Arpenteuse (bot) | **0,83** | 1,03 | **0,55** | 0,97 / 0,89 | zone (biais du bot, §2.4) |
| Rainette | 0,95 | 0,95 | 0,93 | 0,94 / 0,85 | non |
| Avare | **1,16** | **1,35** | 0,86 | **1,45 / 1,54** | mono, boss |
| Bourbe | 1,04 | 1,17 | 0,81 | **1,31** / 1,13 | boss L6, aucun dégât subi |
| Vigie | 1,04 | 1,06 | 1,01 | 1,02 / 0,94 | non |
| Taliant | 0,94 | 0,97 | 0,88 | **0,79** / 0,99 | mono en début de run |

### DPS total sur une run de 18-20 min (vs Ardent, cible ±20 %)
Le score « Global » sert d'approximation de la run. En lancer automatique, tous les personnages sont dans ±20 %, sauf Arpenteuse (−17 %, en limite, biais du bot). **Mais l'écart réel se joue sur les boss et sur le jeu manuel :**
- Avare, Rictus et Bourbe tuent les mini-boss 30 à 54 % plus vite.
- Taliant est à −21 % en début de run.

---

## 2. Par personnage et par sort

Les colonnes « mono » et « zone 5 » sont des **DPS théoriques en B/s**, tous coups touchant, avec un paquet serré de 5 monstres. La rentabilité de l'ultime se compare au Brasier d'Ardent (8 B par cible, 40 B sur 5 cibles, toutes les 20 s).

### 2.1 Ardent (référence) : `ardent_kit.gd`

| Sort | Coef / recharge | Portée / rayon | Mono | Zone 5 | Sécurité |
|---|---|---|---|---|---|
| Éclat de braise (auto) | 0,8 / 0,6 s, perce 1 | 9 u | 1,33 | 2,67 | distance |
| Nova ardente | `NOVA_COEF` 2,5 / 6 s | r 3,5 (déclenchement à 3 u) | 0,42 | 2,08 | contact court |
| Cendres | 0,5 par tick de 0,5 s, 5 s (11 coups) / 8 s, proc 0,3 | r 2,5, portée 7 | 0,69 | 3,4 | distance |
| Brasier (ultime) | `BRASIER_COEF` 8 / 20 s | r 6 | 0,40 | 2,0 | contact moyen |
| **Total** | | | **≈ 2,8** | **≈ 10,2** | |

**Aberrations :** aucune. Le kit est équilibré entre ses sorts, et les Cendres portent la zone.

**TTK mesuré :** voir §3.

### 2.2 Rictus : `rictus_kit.gd`

| Sort | Valeurs (constante) | Mono | Zone 5 | Sécurité |
|---|---|---|---|---|
| Dagues demi-lune (auto, ARC 180°) | `ARC_COEF` 0,8 / 0,6 s, r 2,5 | 1,33 | 6,7 | contact ; `GUARD_S` 0,5 s de garde ×0,7 après chaque coup, soit **83 % du temps** |
| Éventail (FAN ×5) | `FAN_COEF` 1,6 / 6 s, portée 7, perce 1 ; un couteau ramassé rend 1 s (5 s au plus) | 0,3-0,8 | 1,3-1,9 | distance |
| Toupie (SPIN) | 0,7 × 10 ticks / 8 s, r 2,2, proc 0,3 | 0,46 net | 4,4 | **invulnérable 2,5 s** + 2 % de PV |
| Doublures (ultime, 6 leurres) | `DECOY_COEF` 3,0 par explosion / 20 s, r 2,0, anneau à 1,2 u | 0,45-0,9 | 2,3-4,5 | les leurres attirent les monstres |
| **Total** | | **2,5-3,5** | **15-17 (théorique)** | |

**Aberrations :**
- **Doublures :** les 6 explosions se superposent au centre. Cela fait **18 B** sur un monstre (et sur un boss collé), soit 2,25 × le Brasier. En pratique, c'est ce qui explique la mesure sur mini-boss (+41 à +44 %).
- **Garde et Toupie :** la garde à 83 % du temps et l'invulnérabilité de la Toupie (31 % du temps) rendent la mêlée presque gratuite.
- **Double prise d'items :** le sort 1 est `is_auto` et `is_zone` (valeur par défaut). Il cumule `auto_damage_add` et `zone_damage_add`, alors qu'Ardent et Tocsin ont `is_zone = false` sur leur auto.
- **Zone faible en mixte (0,78) :** les tireurs restent hors de portée de la mêlée.

### 2.3 Averse : `averse_kit.gd` (indicatif)

| Sort | Valeurs (constante) | Mono | Zone 5 | Sécurité |
|---|---|---|---|---|
| Goutte-lame (auto) | `GOUTTE_COEF_MIN` 0,75 + `GOUTTE_COEF_WATER` 0,4 × eau / 0,6 s, 9 u, perce 1 | 1,25-1,9 | 2,5-3,8 | distance ; rend 0,5 d'eau par touche, **`BIG_HIT_WATER` 2,0 sur élite ou boss** |
| Vague | `WAVE_COEF` 3,5, `WAVE_COST` 20 d'eau, **aucune recharge** ; cône `WAVE_LENGTH_U` 5 u × `WAVE_SPREAD_DEG` 60° (≈ 13 u²) | selon l'eau | 0,175 B par point d'eau et par cible | moyenne |
| Flaque-miroir | `PUDDLE_COEF` 0,5 × 13 ticks (6,5 B), `PUDDLE_COST` 18, recharge 5 s, `PUDDLE_RADIUS_U` 2,5 (≈ 20 u²) | 0,9 (en continu) | 4,5 | **rend `PUDDLE_GAIN_PER_S` 4 × 6 s = 24 d'eau pour 18 payés** |
| Crue (ultime) | `CRUE_COEF_FULL` 15 × (eau/100)^`CRUE_COEF_EXP` 1,5, **aucune recharge** ; rayon 4 + 0,02 × eau (6 u à 100) ; laisse une Flaque gratuite | voir ci-dessous | | recul 3 u + ralentissement |

**Économie de l'eau sur un boss (estimé) :**
- Gains : pluie 2,5/s, plus les touches de Goutte sur le boss 1,67/s × 2 = 3,3/s, plus la Flaque laissée par la Crue 4/s. Total ≈ **9,8 d'eau/s**.
- Soit **une Crue pleine toutes les 10-12 s**.

**Rendement d'une Crue à 100 :**
- 15 B + 6,5 B de Flaque = **21,5 B par cible, toutes les 11 s**, soit ≈ 2 B/s sur un boss par l'ultime seul.
- Brasier : 0,4 B/s. **La Crue vaut environ 5 Brasiers.**
- En surface : 113 u² pour 100 d'eau, contre 13 u² pour 20 d'eau avec la Vague. Par point d'eau, **la Crue couvre ×1,7 de surface et fait ×1,2 de dégâts par cible.**

**Aberrations :**
- **La Crue écrase la Vague.** Garder l'eau est toujours meilleur, ce qui contredit le retour joueur (« Vague un peu petite »).
- **L'eau n'est jamais limitante sur un boss.** Les gains sont élevés (2 d'eau par Goutte sur un boss) et la Flaque est rentable en eau.
- **La vitesse d'attaque compte deux fois** : elle augmente les dégâts de la Goutte et la recharge en eau de la Crue.
- **Le bot ne voit rien de tout cela** (ratio mesuré de 1,03) car il lance la Crue à 75 d'eau (coef 9,7) dans des combats de 20 s.
- **Effet de bord sur la durée de run :** à 100 d'eau, Averse court à `SPEED_FULL_U` 3,4 u/s au lieu de 4,4 à vide. Le kit pousse donc à jouer lentement (voir §4).

### 2.4 Arpenteuse : `arpenteuse_kit.gd`

| Sort | Valeurs (constante) | Mono | Zone 5 | Sécurité |
|---|---|---|---|---|
| Chaîne (auto, ticks gérés par le kit) | `CHAIN_COEF` 1,0 par `CHAIN_TICK_S` 0,5 s / (1 + vitesse d'attaque), sur les 14 u de chaîne (`CHAIN_MAX_U`), proc 0,3, ralentit de 35 % | 2,0 par ennemi sur la chaîne | **10 (théorique), sans plafond de cibles** | maximale (les dégâts tombent derrière elle) |
| Boucle | `BOUCLE_COEF` 3,5 / 6 s, consomme la chaîne | 0,58 | 2,9 | moyenne |
| Piquet | `PIQUET_COEF` 1,0 (1,6 sur élite ou boss) / 8 s, 5 s, au plus 2 coups/s par cible | ≤ 1,25 (**3,2 sur un boss**) | ≤ 6 | distance |
| Tendeur (ultime) | `TENDEUR_COEF` 10 (16 sur élite ou boss) / 20 s ; emprisonne 1,5 s | 0,5 (0,8 sur boss) | 2,5 | moyenne |

**Mesure :** zone 0,55, mono 1,03, et le plus de dégâts subis en mixte (93 contre 45 pour Ardent).

**Cible élite 1,30 (décision du joueur, 26/10/2026) :** Arpenteuse est difficile à jouer, elle a donc le droit d'être au-dessus de la cible habituelle (compensation de difficulté). Mesurée à 1,5-1,7 × Ardent en élite (8 graines), elle est ramenée vers 1,30 par `BIG_TARGET_ADD` 0,4 → 0,25 et `PEG_IMMUNITY_S` 0,5 → 0,65 (le Piquet frappe une même cible moins souvent). Résultat au simulateur (8 graines, élite) : L1 1,34, L6 1,29, L12 1,23 ; mini-boss 1,19 / 1,11 / 1,06 ; essaim et mixte inchangés (0,75-0,93). Variantes : Chaîne lestée, Nœud et Cerceau à ±15 % du sort remplacé en moyenne ; les Jalons restent à −25 / −30 % en élite (ligne A-B, bonne en essaim), écart antérieur non traité.

**Le bot ne trace pas la chaîne à travers les paquets**, alors que le calcul théorique fait de la chaîne le meilleur sort de zone du jeu. **Les deux ne sont pas réconciliés : NON ÉVALUÉ en jeu réel.**

**Aberrations :**
- **Double prise d'items** `auto` + `zone` sur la chaîne.
- **`BIG_TARGET_ADD` (+0,6)** porte le Piquet au-dessus du plafond de 2 coef/s annoncé en commentaire.
- **Erreurs d'animation** : 32 à 44 erreurs par configuration, du type « Animation 'plant_nw' / 'whip_se' / 'loop_s' doesn't exist » (`normal_maps.gd:257`). Les sprites d'Arpenteuse n'ont pas toutes leurs directions ; c'est un bug visuel, pas d'équilibrage.

### 2.5 Rainette : `rainette_kit.gd`

| Sort | Valeurs (constante) | Mono | Zone 5 | Sécurité |
|---|---|---|---|---|
| Langue (auto, ligne qui perce tout) | `TONGUE_COEF` 1,0 / 0,6 s, 4,5 u | 1,67 (1,22 avec l'essoufflement) | ≈ 5 | moyenne ; +1 % de PV par T1 avalé |
| Grand saut | `LEAP_COEF` 3,8 / 7 s, r 3, étourdit 0,5 s | 0,54 | 2,7 | invulnérable 0,35 s |
| Gluant | `GOO_SPLASH_COEF` 1,4 / 8 s, flaque 5 s qui ralentit de 40 % | 0,18 | 0,9 | contrôle |
| Chant de crue (ultime) | `ULT_LAND_COEF` 3,6 par atterrissage, environ 6 en 4 s / 20 s, r 3 | 1,08 | **5,4** | souffle illimité, en l'air environ 85 % du temps |

**Mesure :** 0,95 au global ; mini-boss à 0,85 en L12, et le plus de dégâts subis sur mini-boss (134).

**Aberrations :**
- **Chant de crue :** 21,6 B par cible et par lancer, soit **×2,7 le Brasier**.
- **Saut pendant le Chant :** un Grand saut lancé pendant le Chant déclenche les deux impacts (3,8 + 3,6).
- **Immunité au contact en l'air :** elle couvre aussi les boss, pendant 57 à 78 % du temps.
- **Souffle qui ne se recharge pas en bonds enchaînés :** `_breath_t = 0` à chaque bond (l.464). C'est probablement un effet de bord.
- **Gluant :** sort faible en dégâts.

### 2.6 Avare : `avare_kit.gd`

| Sort | Valeurs (constante) | Mono | Zone 5 | Sécurité |
|---|---|---|---|---|
| Coup de coffre (auto, arc 150°) | `SWING_COEF` 1,0 / 0,8 s, r 2 | 1,25 × (1 + or) | 6,25 × (1 + or) | contact ; **bouclier ×0,55 pendant 0,6 s, soit 75 % du temps**, armure 30 |
| Poignée de pièces (FAN ×5) | 1,2 par pièce / 5 s, 6 u ; coût 0,1 P, rendu à 80 % | 0,24-1,2 | 1,3-2,4 | distance |
| Rançon | 3,0 / 9 s, r 3, étourdit 0,5 s, marque +50 % d'or | 0,33 | 1,67 | contact |
| Faillite (ultime) | 6 + 4 × min(1, dépensé / 4 P) / 25 s, r 5 ; coûte 50 % de l'or | 0,27 | 1,35 | contact |
| Bourse (passif) | `GOLD_POWER_PER_P` 0,15 par P (prix d'un petit coffre), plancher `GOLD_POWER_FLOOR` 0,10, **plafond `GOLD_POWER_CAP` 0,70** | +16 à +25 % avec l'or typique | | |

**Mesure :**
- **Mono +35 %** ; mini-boss +45 % en L6 et **+54 % en L12**, avec seulement +20 à +25 % d'or.
- **Zone 0,86.**

**Aberrations :**
- **L'or ne limite jamais les sorts :** la Poignée coûte 0,02 P net.
- **Thésauriser 4,7 P donne +70 % à tous les dégâts**, ce qui fait de « ne pas acheter de coffres » une stratégie candidate à la domination.
- **Bouclier et armure 30 :** très solide pour une mêlée.
- **Faillite :** ultime faible, à peu près le Brasier avec une recharge de 25 s.

### 2.7 Bourbe : `bourbe_kit.gd`, `bourbe_motte.gd`

| Sort | Valeurs (constante) | Mono | Zone 5 | Sécurité |
|---|---|---|---|---|
| Gifle de vase (auto, arc 210°) | 1,0 / 0,8 s, r 2 | 1,25 | 6,25 | contact ; −30 % de dégâts subis à 0 motte |
| Détacher (motte) | atterrissage 1,4 (r 2) + contact 0,40 / 0,8 s pendant 10 s ; coûte 15 % des PV (rendus au recollage) ; 4 charges de 3 s | **2,0 avec 4 mottes** | 2,3 + 2,0 | **les mottes attirent les monstres ET les boss** (`bourbe_motte.gd` l.47) |
| Rappel | 1,5 par traversée / 6 s | 0,25-1 | 1,5-2,5 | rend des PV |
| Bourbier (ultime) | 1,2 × 9 ticks / 22 s, r 5, ralentit de 50 % ; invulnérable 4 s ; **4 mottes gratuites à la sortie** | **1,45 (32 B par lancer)** | 3,6 (79 B) | invulnérable |

**Mesure :**
- Mini-boss : 1,31 en L6 et 1,13 en L12.
- **0 dégât subi sur le mini-boss en L6 et en L12**, et 0 en mixte L12.

**Aberrations :**
- **Les mottes attirent le boss :** c'est une immunité de fait.
- **Bourbier :** environ ×4 le Brasier en mono, à cause des 4 mottes gratuites (20 B).
- **La ressource en PV n'est pas un vrai coût :** le recollage la rembourse.

### 2.8 Tocsin : `tocsin_kit.gd`, `tocsin_limb.gd`

| Sort | Valeurs (constante) | Mono | Zone 5 | Sécurité |
|---|---|---|---|---|
| Rivets rougis (auto) | `RIVET_COEF` 0,8 / 0,6 s / (1 + vitesse d'attaque + 0,12 × membre absent), 8 u, perce 1 | 1,33-2,1 | 2,7-3,3 | distance (5 u sans tête) |
| Bras-grappins (2 charges) | `ARM_COEF` 1,8 / `ARM_CD_S` 8 s ; capture 6 points, pince 2,5 s | 0,23 (0,9 en ramassant) | 0,7 | contrôle très fort |
| Coups de botte (2 charges) | `LEG_COEF` 3,0 / `LEG_CD_S` 9 s, poussée 4 u, Quilles 1,0 | 0,33 (0,86 en ramassant) | 1,2 | moyenne |
| Tête-cloche (ultime) | `HEAD_COEF` 12 / `HEAD_CD_S` 22 s, r 4 ; ×1,5 sur un prisonnier, +0,3 sur un boss | 0,55 (0,82 sur un prisonnier) | 2,7-4,1 | 22 s sans tête |

**Mesure :** élite +26 % en L6 et +20 % en L12 ; mini-boss +22 % en L6. Il encaisse beaucoup sur mini-boss (132 contre 95).

**Aberrations :**
- **Le ramassage d'un membre rend la charge tout de suite** : les recharges de 8-9 s tombent à 2-3,5 s en manuel. **Ce n'est pas mesuré** (le bot ne ramasse pas).
- **Tête-cloche sur prisonniers :** 2 × le Brasier par cible.

### 2.9 Vigie : `vigie_kit.gd`

| Sort | Valeurs (constante) | Mono | Zone 5 | Sécurité |
|---|---|---|---|---|
| Trait / Allonge (auto + Tension) | `TRAIT_COEF` 0,8 ; `ALLONGE_COEF` 2,0, perce 30, 12 u ; Tension pleine en 1,0 s à l'arrêt, 2,2 s en marchant | 2,33 à l'arrêt, 1,83 en marchant | 6,3 / 4,5 | distance, 7-12 u |
| Fusée | 1,2 / 8 s, exposition ×1,1 | 0,15 | 0,15 | distance |
| Filet | 0,5 + 1,2 en zone / 9 s, r 3, immobilise 1,5 s ; remplit la Tension | 0,32 | 1,2 | distance |
| Grêle (ultime) | 0,7 × 11 ticks (7,7 B) / 20 s, r 4,5, **proc 0,4 sur des ticks de 0,25 s** | 0,39 | 1,93 | distance |

**Mesure :** 1,04 au global, aucun écart hors cible. **C'est le personnage le mieux calibré.**

**Points mineurs :**
- La Tension se remplit sans ennemi et se garde d'un étage à l'autre.
- La Grêle fait environ 4,4 jets de proc par cible et par lancer.
- Le commentaire l.9 annonce une exposition de +20 %, alors que la constante vaut +10 %.

### 2.10 Taliant (`morfil`) : `morfil_kit.gd`

| Sort | Valeurs (constante) | Mono | Zone 5 | Sécurité |
|---|---|---|---|---|
| Taille / estoc (auto) | cercle 1,5 (r 2,3) et estoc 2,0 (3,2 u, 40°) / 0,7 s ; `COST_CIRCLE` / `COST_THRUST` 4 % d'aiguisage ; dégâts × aiguisage | 2,5 × s | 9,6 × s | mêlée ; garde ×0,55 pendant 0,6 s, soit 86 % du temps |
| Fauche-lune | 4,0 / 6 s, 180° × 3,5 u, `COST_CRESCENT` 15 % | 0,67 × s | 3,3 × s | mêlée |
| Aiguisage | remet à 100 % / 10 s | — | — | — |
| Lames jumelles (ultime) | dégainé 2,5, puis **chaque coup doublé pendant 15 s** (la moitié de la recharge de 30 s), seuil 90 % | ×1,5 en moyenne | | garde permanente |

**Aiguisage moyen réel :** environ **0,58**, avec une usure de 8 à 9,5 %/s. La fiche (`morfil.md` l.30) annonce environ 40 % d'usure par cycle ; c'est faux.

**Mesure :** mini-boss **0,79 en L6**, élite 0,88 en L6 ; normal en L12. Le début de run est faible.

**Aberrations :**
- **Ultime :** environ 2,3 × le Brasier rapporté à 20 s, mais l'usure le bride.
- **Bug d'alternance auto :** contre une cible entre 2,3 et 3,2 u, l'auto fait toujours l'estoc (`_cast_auto` l.421-426).
- **Iaï :** pas de plafond de cibles.

---

## 3. Temps pour tuer un boss d'étage (estimé)

### Hypothèses
- **Run de 19 min en Moyen**, 5 étages d'environ 3:48. Le boss est lancé environ 2:30 après l'arrivée sur l'étage, et le boss final vers 16:30.
- **PV d'un boss d'étage** = 3000 × (1 + 0,3 (niv-1)) × √D × 0,95^(étage-1). Le boss final a un multiplicateur de PV ×2 (`floors.json`).
- **DPS d'Ardent :**
  - étage 1 : mesuré sur mini-boss en L6 (109 DPS) ;
  - étage 3 : mesuré en L12 (236 DPS) ;
  - étage 2 : moyenne géométrique des deux ;
  - **étages 4-5 : extrapolés ×1,4 et ×1,8 (non mesurés).**
- **Autres personnages :** DPS d'Ardent × leur ratio sur mini-boss.
- Mécaniques de phase, invulnérabilités et déplacements sont ignorés.

### Moments des boss et PV

| Étage | Moment | D | Niveau ambiant | PV du boss |
|---|---|---|---|---|
| 1 | 2:30 | 1,38 | 2 | 4 581 |
| 2 | 6:18 | 2,25 | 4 | 8 122 |
| 3 | 10:06 | 3,35 | 8 | 15 362 |
| 4 | 13:54 | 4,73 | 12 | 24 054 |
| 5 (final ×2) | 16:30 | 6,13 | 16 | 66 547 |

### TTK estimé (en secondes)
Cible du §14 : 65-75 s pour un boss d'étage ; cible de `Design_Etages` : 75-100 s pour le boss final.

| Perso | Ét. 1 | Ét. 2 | Ét. 3 | Ét. 4 (extrapolé) | Final (extrapolé) |
|---|---|---|---|---|---|
| Ardent | 42 | 51 | 65 | 73 | 157 |
| Rictus | **30** | **35** | 45 | 51 | 109 |
| Tocsin | 34 | 45 | 62 | 69 | 149 |
| Averse (bot) | 37 | 45 | 59 | 66 | 143 |
| Averse (manuel, Crue à 100, estimé) | ≈ 25 | ≈ 30 | ≈ 40 | ≈ 45 | ≈ 95 |
| Arpenteuse | 43 | 54 | 73 | 82 | 176 |
| Rainette | 45 | 57 | 77 | 86 | **185** |
| Avare | **29** | **34** | **42** | **47** | **102** |
| Bourbe | 32 | 42 | 58 | 65 | 139 |
| Vigie | 41 | 52 | 69 | 78 | 167 |
| Taliant | **53** | 57 | 66 | 74 | 159 |

### Lecture
- **Étages 1-2 :** tous les personnages sont sous la cible de 65-75 s. Les boss du début meurent vite, sans alerte pour autant.
- **Rictus et Avare** tuent un boss d'étage **30 à 40 % plus vite** que les autres.
- **Boss final :** il serait **trop long pour presque tous** (140-185 s contre 75-100 s), si l'extrapolation tient. C'est à vérifier en priorité (§6).
- **Averse en manuel :** l'écart s'explique par environ 2 B/s de Crue (§2.3).

---

## 4. Run observée de 27:30 contre la cible de 18-20 min

### Ce que la durée change

| | Run de 19 min | Run de 27:30 |
|---|---|---|
| D en fin de run | 6,79 (niveau 18) | 9,05 (niveau 25) |
| PV des monstres | ×6,1 | ×8,2 (**+34 %**) |
| PV du boss final (lancé vers 24:00) | 66 500 | ≈ 101 700 (**+53 %**) |

Le scaling est **temporel** (`TIME_SLOPE` 0,0506 × 1,5), donc chaque minute de plus durcit la suite. Une run lente est aussi une run plus dure, ce qui crée une boucle renforçante.

### Deux explications possibles, non départagées faute de télémétrie

**1. Jeu prudent ou farm**
- Le téléporteur ne s'active qu'en interagissant, ce qui permet de rester farmer. La relance de coffre est gratuite pendant les tests.
- Pour Averse, le kit **pousse à jouer lent** :
  - elle porte une amphore pleine (3,4 u/s contre 4,4 u/s, et elle trébuche dès 80 d'eau) pour garder la Crue à 100 ;
  - elle reste dans sa Flaque pour regagner de l'eau.
- Dans ce cas, la Crue trop forte **masque** la hausse de difficulté.
- Indice dans ce sens : le joueur a trouvé la Crue « beaucoup trop forte » à 27 min, alors que les monstres avaient +34 % de PV. Il ne manquait donc pas de puissance.

**2. Structure d'étage plus longue que prévu**
- `Design_Etages.md` §19 estime lui-même la run à « ≈ 22-25 min à 4-5 min l'étage ». C'est en contradiction avec la cible de 18-20 min.
- Il faut 5 min 30 par étage pour faire 27:30. Avec 90 s de charge, 2 mini-boss, l'exploration et les coffres, 4-5 min par étage est déjà la norme du plan.

### Ce qu'il faut mesurer (télémétrie absente du code : aucun `floor_times` ni journal de run trouvé)
1. Par étage, le temps de chaque phase : exploration jusqu'au premier pilier, chaque combat de mini-boss, combat du boss d'étage, charge restante après la mort du boss, et temps passé après la fin du pilier (farm).
2. L'or dépensé, les coffres ouverts, le niveau et D à chaque changement d'étage.
3. Pour Averse : le temps passé au-dessus de 80 d'eau, le nombre de Crues et l'eau moyenne au lancer, le temps passé dans une flaque.
4. La part du temps où le joueur est immobile.

Sans ces données, **je ne peux pas dire** si les 27:30 viennent du scaling ou du style de jeu. Mon hypothèse la plus probable est un étage trop long par construction (5 étages × 4-5 min) plus du farm, et non un manque de puissance.

---

## 5. Recommandations chiffrées (par priorité)

Les colonnes sont : fichier:constante, valeur actuelle → proposée, plage sûre, raison.

### P1 : Averse (indicatif, coordonner avec l'agent qui corrige Averse)

| Fichier:constante | Actuel → proposé | Plage sûre | Raison |
|---|---|---|---|
| `averse_kit.gd:CRUE_COEF_FULL` | 15 → **9** | 8-10 | Crue pleine ≈ 1,1 Brasier par lancer |
| `averse_kit.gd:CRUE_COEF_EXP` | 1,5 → **1,2** | 1,0-1,3 | Moins de prime à « tout garder » ; à 40 d'eau ≈ 3,0 |
| `averse_kit.gd` : recharge de la Crue (`s4.base_cooldown`, nouvelle constante `CRUE_CD`) | 0 → **12 s** | 10-15 | Sirlin : une ressource seule ne borne pas un ultime quand l'eau abonde |
| `averse_kit.gd:BIG_HIT_WATER` | 2,0 → **1,0** | 0,8-1,2 | Eau sur boss ×2,5 trop forte |
| `averse_kit.gd:PUDDLE_GAIN_PER_S` | 4,0 → **2,5** | 2-3 | La Flaque rend 15 d'eau < 18 payés (aujourd'hui 24 > 18) |
| `averse_kit.gd:CRUE_RADIUS_U` | 4,0 → **5,0** (soit 7 u à 100 avec +0,02/eau) | 4,5-5,5 | Retour joueur : portée trop petite |
| `averse_kit.gd:WAVE_LENGTH_U` | 5,0 → **6,0** | 5,5-6,5 | Retour joueur ; cône de 13 → 19 u² |
| `averse_kit.gd:WAVE_SPREAD_DEG` | 60 → **70** | 60-75 | Cône de 22 u² au total ; la Vague redevient une alternative à la Crue |
| `averse_kit.gd:PUDDLE_RADIUS_U` | 2,5 → **3,0** | 2,75-3,25 | Retour joueur |
| `averse_kit.gd:PUDDLE_COEF` | 0,5 → **0,45** | 0,4-0,5 | Compense le +44 % de surface |

**Effet estimé :**
- Ultime sur boss : environ 2 → environ 0,8 B/s.
- TTK du boss d'étage en manuel : environ 25-40 s → environ 37-60 s (ratio vers 1,05-1,15).

### P2 : Avare (mono +35 %, boss +45-54 %)

| Fichier:constante | Actuel → proposé | Plage sûre | Raison |
|---|---|---|---|
| `avare_kit.gd:GOLD_POWER_CAP` | 0,70 → **0,45** | 0,4-0,5 | Thésauriser ne doit pas valoir +70 % sur tout |
| `avare_kit.gd:GOLD_POWER_FLOOR` | 0,10 → **0,0** | 0-0,05 | −8 % sur le cas typique |
| `avare_kit.gd` : coef de la Rançon (l.108) | 3,0 → **2,4** | 2,2-2,6 | Burst sur boss |
| `avare_kit.gd:GUARD_S` | 0,6 → **0,4** | 0,35-0,45 | Bouclier de 75 → 50 % du temps |
| `avare_kit.gd` : Faillite, coef de base (l.116) | 6 → **7** | 6,5-7,5 | Ultime aujourd'hui inférieur au Brasier |

**Effet estimé :** ratio mono 1,35 → environ 1,12 ; ultime plus rentable.

### P3 : Rictus (boss +41-44 %, zone 0,78)

| Fichier:constante | Actuel → proposé | Plage sûre | Raison |
|---|---|---|---|
| `rictus_kit.gd:DECOY_COEF` | 3,0 → **2,0** | 1,8-2,2 | Centre de 18 → 12 B (1,5 Brasier) |
| `rictus_kit.gd:GUARD_S` | 0,5 → **0,35** | 0,3-0,4 | Garde de 83 → 58 % du temps |
| `rictus_kit.gd:FAN_COEF` | 1,6 → **1,8** | 1,7-1,9 | Remonte la zone / les tireurs (0,78) |
| `rictus_kit.gd` : sort 1, `is_zone` | true → **false** (contrat à trancher, voir P8) | — | Double prise auto + zone |

### P4 : Bourbe (aucun dégât subi sur boss, Bourbier ×4 Brasier en mono)

| Fichier:constante | Actuel → proposé | Plage sûre | Raison |
|---|---|---|---|
| `bourbe_motte.gd` (l.47) : provocation des boss | les boss sont attirés → **les boss ne sont pas attirés** (ou 1,5 s au plus, puis ignorés 6 s) | — | Immunité de fait sur boss |
| `bourbe_kit.gd` : mottes gratuites à la sortie du Bourbier | 4 → **2** | 1-2 | Bourbier de 32 → 22 B en mono |
| `bourbe_kit.gd` : coef par tick du Bourbier (l.93) | 1,2 → 1,2 | — | Inchangé |

### P5 : Rainette (ultime ×2,7 Brasier, boss faible en L12)

| Fichier:constante | Actuel → proposé | Plage sûre | Raison |
|---|---|---|---|
| `rainette_kit.gd:ULT_LAND_COEF` | 3,6 → **2,8** | 2,6-3,0 | 6 atterrissages = 16,8 B (≈ 2 Brasiers, compensés par 0 dégât en l'air) |
| `rainette_kit.gd` l.507-510 : Grand saut pendant le Chant | les deux impacts → **un seul (le plus fort)** | — | Cumul de 7,4 B |
| `rainette_kit.gd:TONGUE_COEF` | 1,0 → **1,1** | 1,0-1,15 | Le boss en L12 est à 0,85 : rendre le DPS soutenu plutôt que l'ultime |
| `rainette_kit.gd` l.464 : `_breath_t` remis à 0 à chaque bond | à **trancher** (bug ou voulu) | — | Le souffle ne se recharge jamais en bonds enchaînés |

### P6 : Taliant (−21 % en début de run, ultime surdimensionné)

| Fichier:constante | Actuel → proposé | Plage sûre | Raison |
|---|---|---|---|
| `morfil_kit.gd:COST_CIRCLE` / `COST_THRUST` | 4 → **3** % | 3-3,5 | Aiguisage moyen de 0,58 → environ 0,68 (+17 % de DPS) |
| `morfil_kit.gd` : coef du coup jumeau sous l'ultime (copie du coup, l.509) | ×1,0 → **×0,7** | 0,6-0,8 | Ultime de 2,3 → environ 1,6 Brasier |
| `morfil_kit.gd` l.421-426 : alternance cercle / estoc | à corriger | — | Toujours l'estoc entre 2,3 et 3,2 u |

### P7 : Tocsin (élite +20-26 %, ramassage non mesuré)

| Fichier:constante | Actuel → proposé | Plage sûre | Raison |
|---|---|---|---|
| `tocsin_kit.gd:HEAD_COEF` | 12 → **10** | 10-11 | Tête-cloche de 1,4-2 → 1,25-1,9 Brasier |
| `tocsin_kit.gd` : ramassage d'un membre (`collect_limb` l.612) | charge pleine → **recharge restante ×0,5** (nouvelle constante `PICKUP_CD_REFUND` = 0,5) | 0,4-0,7 | Le ramassage annule aujourd'hui les recharges de 8-9 s |

### P8 : Arpenteuse (à mesurer avant de toucher)

| Fichier:constante | Actuel → proposé | Plage sûre | Raison |
|---|---|---|---|
| `arpenteuse_kit.gd:BIG_TARGET_ADD` | 0,6 → 0,4 → **0,25** (26/10, cible élite 1,30) | 0,2-0,3 | Piquet sur boss au-dessus du plafond annoncé |
| `arpenteuse_kit.gd:PEG_IMMUNITY_S` | 0,5 → **0,65** (26/10) | 0,6-0,7 | Corrige surtout le niveau 1 en élite |
| `arpenteuse_kit.gd:CHAIN_COEF` | 1,0 → **inchangé tant que non mesuré** | — | Théorie ×5 Ardent en zone, mesure ×0,55 |
| Animations manquantes (directions de `plant`, `whip`, `loop`, `death_se`) | — | — | Erreurs dans le simulateur, à livrer côté assets |

### Transverse (contrat `CONTRACTS.md`, à trancher par l'orchestrateur)
- **Attaque auto et `is_zone` :** une attaque auto ne devrait prendre que `auto_damage_add`. Concerné aujourd'hui : `is_zone = true` sur Rictus, Arpenteuse, Bourbe et Taliant.
- **Vigie : `vigie_kit.gd`, proc de la Grêle** 0,4 → **0,25** (ticks de 0,25 s).

### Ce que le test suivant doit vérifier
1. Relancer `balance_sim_run` en 3 graines, L6 et L12 :
   - ratio mono de chaque personnage dans [0,85 ; 1,20] ;
   - mini-boss dans [0,8 ; 1,25] ;
   - Bourbe doit **subir des dégâts** sur mini-boss (> 0).
2. Averse : un scénario dédié de 60 s contre un mini-boss, avec la Crue lancée à 100 d'eau (pilote modifié, `AUTO_CRUE_AT` = 100). Les deux critères :
   - part de l'ultime ≤ 35 % des dégâts ;
   - ratio ≤ 1,2.
3. Ajouter au simulateur un **scénario « boss d'étage »** (3 étages, D réel) et une **configuration L18** (étage 4-5, environ 20 objets), pour remplacer les extrapolations du §3.
4. Ajouter des pilotes « manuels » : Tocsin qui ramasse, Arpenteuse qui trace la chaîne, Avare qui thésaurise.
5. Après correction : `test_balance.gd` et `boss_pace_test.tscn`, qui ne doivent pas régresser.

---

## 6. NON ÉVALUÉ

| Point | Ce qui manque |
|---|---|
| TTK réel des boss d'étage et du boss final | Pas de scénario « boss d'étage » dans `balance_sim` ; étages 4-5 et boss final **extrapolés** (×1,4 / ×1,8 sur le DPS de L12). Le boss final semble trop long (140-185 s), **non vérifié** |
| Jeu manuel optimisé | Crue d'Averse à 100, ramassage des membres de Tocsin, chaîne d'Arpenteuse tracée, thésaurisation d'Avare : seulement en **théorie** |
| Arpenteuse | Écart théorie / mesure (×2 contre ×0,55) non réconcilié ; erreurs d'animation pendant la mesure |
| DPS sur une vraie run de 18-20 min | Le simulateur ne fait que des combats isolés de 10 à 40 s. Pas de flux du director, d'objets réels, de procs, ni d'empilement d'objets offensifs au-delà de 9 piles neutres |
| Durée de run de 27:30 | Aucune télémétrie de run dans le code (temps par phase, farm, or, niveau) ; mode de difficulté joué inconnu |
| Survie | Seulement les dégâts subis en combat scripté (bot à 25 % d'esquives ratées) ; pas de taux de mort sur une run |
| Synergies d'objets par personnage | Crit × proc et vitesse d'attaque × Crue ou Chaîne, non simulés |
| Simulateur historique Python | Formules v3 non alignées sur `balance.gd` §14 ; non utilisé |
| Fiches de design | Absentes pour 8 personnages sur 10 ; pas de cible propre au personnage (rôle attendu de zone ou de mono-cible) au-delà de ±20 % |
| Variantes de sorts (Ardent B, etc.) | Non codées |

### Valeurs sans plage cible (non jugées)
- Temps passé intouchable : Rainette 57-85 %, Rictus avec la Toupie 31 %, Bourbe 18 %.
- Bonus de vitesse de déplacement des kits.
- Surchauffe de Tocsin (+12 % de vitesse d'attaque par membre absent).
