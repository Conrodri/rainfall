# Audit des télégraphes au sol (29/10/2026)

Demande du joueur : trop de prévisualisations au sol (cônes, demi-cercles, aplats) qui font « cheap » ; plus de clarté par l'animation.
Périmètre : `enemy_telegraph.gd`, cerveaux de boss `*_brain.gd`, mini-boss (`miniboss_patterns.gd`, `data/minibosses.json`), monstres de base (`enemy.gd`), `Balance.TELEGRAPH_*`.
Règle de classement : poids = coefficient de dégâts du coup (`Balance.BOSS_ATTACK_COEF`, `coef` des mini-boss). Léger <= 1,1 ; lourd 1,1 à 2,0 exclu ; mortel >= 2,0 (`Balance.TELEGRAPH_LIGHT_MAX_COEF` / `TELEGRAPH_DEADLY_MIN_COEF`). Une zone persistante (ticks, trace au sol) reste dessinée quel que soit son coef : elle dit où le danger reste.

Avant la passe, tout coup avait la même zone : aplat rouge 0,28 d'alpha plein dès l'armement, double liseré 6 px/2 px, anneau de progression, pour 100 % des coups, hors boss comme boss. Un boss enchaînait donc auto, sort et zones avec la même grammaire visuelle : le coup mortel ne se distinguait pas du coup de routine.

## 1. Inventaire

Durées d'armement : auto 0,6 / 0,55 / 0,5 s (phases 1-3), sort 1,1 / 0,95 / 0,85 s, lourd 1,6 / 1,4 / 1,25 s, charge 1,0 / 0,9 / 0,8 s (`BOSS_PACE_WINDUP`) ; les cerveaux ajoutent des variantes. Monstres : cône de brute 0,6 s, onde 1,0 s, bond 0,8 s, tir 0,7 s, salve 1,0 s.
Classement : **G** garder (zone fine, remplissage qui monte) ; **M** mortel, garder avec remplissage plus dense ; **A** alléger = supprimer la zone, lu par l'anticipation du corps (réglage renforcé : la zone revient) ; **P** zone persistante, garder.

### Monstres de base (`enemy.gd`)

| Attaque | Forme | Durée | Poids | Classement |
|---|---|---|---|---|
| Brute : cône | cône | 0,6 s | léger | A |
| Brute : onde de choc | disque r 3 u | 1,0 s | lourd | G |
| Bondisseur : bond | ligne 6 u | 0,8 s | léger | A |
| Tireur : tir simple | ligne de visée | 0,7 s | léger | A |
| Tireur : salve de 3 | cône | 1,0 s | léger | A |
| Essaim : morsure | aucune zone | 0,35 s | léger | (anticipation seule, inchangé) |
| Boss générique : auto | ligne | ~0,5 s | léger | A |
| Boss générique : écrasement / frappe | disque | 1,0 / 0,9 s | lourd | G |

### Boss d'étage et raids (coef de `BOSS_ATTACK_COEF`)

| Boss | Attaque | Forme | Coef | Poids | Classement |
|---|---|---|---|---|---|
| Cerf | andouiller (gore) | cône | 1,1 | léger | A |
| Cerf | tir | ligne | 0,75 | léger | A |
| Cerf | feu-follet | disque | 0,75 | léger | A |
| Cerf | charge | ligne | 1,6 | lourd | G |
| Cerf | bond | disque | 1,5 | lourd | G |
| Sonneur | marteau | cône | 1,0 | léger | A |
| Sonneur | glas | disque (grand) | 1,5 | lourd | G |
| Sonneur | boulons | disques | 1,3 | lourd | G |
| Sonneur | foudre | disque | 2,5 | mortel | M |
| Sonneur | vapeur | lignes | 0,4/0,5 s | persistant | P |
| Sonneur | orage (après mort) | disque | 2,0 | mortel | M |
| Éclusier | coup de vanne | cône | 1,0 | léger | A |
| Éclusier | lâcher d'eau / geysers / croix | lignes, disques | 1,2 à 1,6 | lourd | G |
| Bouvier | cornes | cône | 1,0 | léger | A |
| Bouvier | charge / piétinement | ligne, disque | 1,4 à 1,8 | lourd | G |
| Bouvier | boue | lignes | 0,4/0,5 s | persistant | P |
| Porteuse de jarres | jet de jarre | disque | 1,0 | léger | A |
| Porteuse de jarres | pluie, jarre-mère | disques | 1,3 à 1,5 | lourd | G |
| Tisseuse | morsure | cône | 1,0 | léger | A |
| Tisseuse | fils / descente | lignes, disque | 1,2 à 1,6 | lourd | G |
| Cèdre-Ermite | branche | cône | 1,0 | léger | A |
| Cèdre-Ermite | racines, charge | disques, ligne | 1,3 à 1,8 | lourd | G |
| Cèdre-Ermite | spores | disque | 0,6 + poison | persistant | P |
| Grue | crochet | ligne | 1,0 | léger | A |
| Grue | balayage, conteneur, arc | cône, disques, lignes | 1,3 à 1,8 | lourd | G |
| Fondeur | louche | cône | 1,0 | léger | A |
| Fondeur | étincelles | cône | 0,8 | léger | A |
| Fondeur | coulée, trempe | lignes, disque | 1,5 à 1,6 | lourd | G |
| Fondeur | vapeur / métal au sol | lignes | 0,4 à 0,5/0,5 s | persistant | P |
| Reclus | bâton | cône | 1,0 | léger | A |
| Reclus | cloche, prières | disques | 1,3 à 1,5 | lourd | G |
| Reclus | rayons | lignes | 0,45/0,5 s | persistant | P |
| Mère-Cristal | éclat | ligne | 1,0 | léger | A |
| Mère-Cristal | stalactites, reflet | disques | 1,3 à 1,5 | lourd | G |
| Mère-Cristal | prisme | lignes | 2,0 | mortel | M |
| Anguille | morsure | cône | 1,1 | léger | A |
| Anguille | émergence, décharge | ligne, disques | 1,4 à 1,8 | lourd | G |
| Anguille | fouets | lignes | 0,5/0,5 s | persistant | P |
| Semeur de pluie (final) | fouet | ligne | 1,0 | léger | A |
| Semeur de pluie (final) | tourbillon | disque | 1,1 | léger | A |
| Semeur de pluie (final) | averse, vague, débordement | disques, lignes | 1,2 à 1,5 | lourd | G |
| Semeur de pluie (final) | foudre | disque | 2,5 | mortel | M |
| Semeur de pluie (final) | croix | lignes | 0,45/0,5 s | persistant | P |
| Idole noyée (raid) | paume | cône | 1,0 | léger | A |
| Idole noyée (raid) | carillon, chapelet | disques | 1,2 à 1,3 | lourd | G |
| Idole noyée (raid) | digue, noria | lignes | 0,5 à 0,6 | persistant | P |
| Canonnier du déluge (raid) | culasse | lignes | 1,0 | léger | A |
| Canonnier du déluge (raid) | obus | disques | 1,6 | lourd | G |
| Roi de sel (raid) | sceptre | ligne | 1,0 | léger | A |
| Roi de sel (raid) | édit, stèles | disques | 1,2 à 1,4 | lourd | G |

Mécaniques de raid (chute d'orbe, abri, zone de trempage, barrage) : non touchées. Ce sont des zones de mécanique, pas des coups de routine, et le joueur doit les lire de loin.

### Mini-boss (20 mini-boss, 66 motifs, `data/minibosses.json`)

Poids dérivé du `coef` du motif (`MiniBossPatterns._w`) ; un motif avec `tick_s`, `zone` ou de type `beam` reste dessiné.

| Poids | Motifs | Classement |
|---|---|---|
| Léger (coef <= 1,1) | 39 (pattes, becs, éventails de projectiles, lignes d'appoint) | A |
| Zone persistante | souffle de l'ours, cône du lampiste, mares, flaques, mur de flammes, geysers | P |
| Lourd (1,1 à 2,0) | 23 (charges, ondes, stalactites, bonds, essaims) | G |
| Mortel (>= 2,0) | 2 (bond de l'ours de givre 2,2 ; jugement de l'archonte rouillé 2,0) | M |

## 2. Classement et résultat

- Supprimé au profit de l'anticipation : la majorité des télégraphes (tous les coups légers de boss, de mini-boss et de monstres ; 39 motifs de mini-boss sur 66). Reste : coups lourds, mortels, zones persistantes.
- Style : aplat de fond quasi invisible (alpha 0,035), bord fin net (sombre 4 px + clair 1,6 px, contraste >= 3:1 inchangé), remplissage qui monte du centre vers le bord à l'impact (de 10 % de l'alpha final au début à 0,20 à l'impact, 0,30 si mortel ; courbe douce), teinte rouge d'alerte mêlée à 35 % de l'accent du biome (jamais en mode daltonien).
- Anticipation du corps (visuelle seulement, le coup tombe au même instant) : dans les 0,18 s avant l'impact, écrasement supplémentaire (+120 % de l'armement), éclat d'émission qui monte, et pour les boss un recul qui se creuse (+60 %) puis claque dans la fente.
- Accessibilité : « Télégraphes renforcés » garde l'affichage complet pour tous les coups (liseré épais, remplissage 0,40, minuterie de bord).
- Inchangés : plafond de télégraphes de monstres au sol (`TELEGRAPH_GROUND_MAX`), dégâts, PV, timings de hitbox.
