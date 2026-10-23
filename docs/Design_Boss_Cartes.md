# Rainfall : identité, boss et cartes (design v1)

> Document de game design, exploitable par les développeurs (GDScript) et le pipeline d'assets (Blender → sprites pré-rendus).
> Cohérent avec `GDD.md` (§2, §7), `Maths_Scaling.md` (§1, §4, §5, §11) et `Items_Catalog.md` (§7).
> Règles non négociables : **télégraphe ≥ 0,8 s** pour tout sort de zone, **plafond de 40 % des PV max du joueur par coup de boss**, **jamais de mort instantanée**, aucun nom ni design emprunté à Risk of Rain ou Vampire Survivors.
> Unité : **1 u = 64 px** (taille du joueur). Écran portrait 1080×1920 = **16,9 u × 30 u** visibles.

---

## 0. Résumé des conventions chiffrées (à lire avant le reste)

### Dégâts des boss
```
Dég_boss = Coef × Dég_base_boss × (1 + 0,30 × (D - 1)) × Enrage
Dég_base_boss : mini-boss = 20   |   boss d'étage = 24
Enrage = 1 + 0,015 × max(0, t_combat - 60 s)
Clamp final : min(Dég_boss, 0,40 × PV_max_joueur)      (règle Maths §4-5)
```
Les monstres de tier 1-3 gardent leurs Dég_base (8 / 12 / 30) ; les boss ont leur propre base, plus élevée, car ils frappent moins souvent.

**Règle d'empilement** : un même lancer de sort ne touche le joueur **qu'une fois** (sauf sorts canalisés, qui tickent toutes les 0,5 s avec un coef par tick). Les cercles d'un même sort **ne se chevauchent jamais** (espacement ≥ 0,5 u). Ainsi, même en restant immobile, un joueur ne peut pas prendre plus d'un coup lourd par télégraphe : pas de mort instantanée.

### Vérification des coefficients sur les 9 combats simulés (Moyen, Maths §5)
PV du joueur estimés à partir des niveaux visés (Maths §6). Coef max = 2,2 pour un mini-boss, 2,5 pour un boss d'étage.

| Combat | D | Mult (1+0,3(D-1)) | Auto (coef 1,0) | Coup le plus lourd | PV joueur ≈ | Part des PV |
|---|---|---|---|---|---|---|
| É1 Mini A (0:30) | 1,15 | 1,045 | 21 | 46 (2,2) | 130 (L2) | 35 % |
| É1 Mini B (1:22) | 1,41 | 1,123 | 22 | 49 (2,2) | 190 (L4) | 26 % |
| É1 Boss (2:03) | 1,61 | 1,183 | 28 | 71 (2,5) | 220 (L5) | 32 % |
| É2 Mini A (4:08) | 2,58 | 1,474 | 29 | 65 (2,2) | 340 (L9) | 19 % |
| É2 Mini B (4:43) | 2,78 | 1,534 | 31 | 68 (2,2) | 355 (L9-10) | 19 % |
| É2 Boss (5:18) | 2,98 | 1,594 | 38 | 96 (2,5) | 370 (L10) | 26 % |
| É3 Mini A (7:23) | 4,25 | 1,975 | 40 | 87 (2,2) | 490 (L14) | 18 % |
| É3 Mini B (7:57) | 4,48 | 2,044 | 41 | 90 (2,2) | 505 (L14-15) | 18 % |
| É3 Boss (8:29) | 4,69 | 2,107 | 51 | 126 (2,5) | 550 (L16) | 23 % |

Le plafond de 40 % n'est jamais atteint en Moyen ; il sert de garde-fou en Difficile tôt dans la run (0:30 en Difficile : D = 1,23 → 47 dégâts = 36 % de 130 PV). La part relative baisse avec le temps : c'est voulu, la pression de fin de run vient de la **zone** (crédits ×1,5), pas du boss seul (Maths §11).

### Rythme d'un combat
- Mini-boss : 17-37 s. Deux sorts à recharge **9 à 13 s** → chaque sort est lancé 2 à 4 fois. Premier lancer du sort A à **1,5 s**, du sort B à **5 s** ; **délai global de 2,5 s** entre deux débuts de sorts pour ne jamais superposer deux télégraphes. **Phase 2 à 50 % PV** (transition de 1,0 s : le boss n'attaque pas, reste touchable, jamais invulnérable).
- Boss d'étage : 28-39 s. **Phases à 70 % et 35 %** (≈ 10-13 s chacune), même règle de transition. La zone de charge (90 s) continue après sa mort : les phases doivent créer des **souvenirs** (le combat est court) et laisser des **traces au sol** qui pèsent sur la fin de charge.
- Vitesse de déplacement des boss : **2,2 à 3,2 u/s** (jamais plus que le joueur à 4,0 u/s), sauf charges télégraphées (10-14 u/s).
- Si le joueur quitte la zone : le boss le suit, à **+40 % de vitesse** tant qu'il est hors zone (kite infini impossible). À valider en playtest.
- Boss **ignorés par les ralentissements des items** à hauteur de 50 % seulement (Flocon/Givre appliquent la moitié de leur valeur), sauf mention contraire ; immunisés aux poussées.

### Palette des télégraphes (réservée, le sol ne doit jamais utiliser ces teintes saturées)
| Usage | Couleur | Forme |
|---|---|---|
| Zone de dégâts imminente | rouge `#E53935`, alpha 55 %, liseré blanc 2 px, **remplissage qui monte** pendant la durée du télégraphe | cercle, ligne, cône, anneau |
| Zone persistante (mare, flaque, mur) | teinte du statut (orange brûlure `#FF8A30`, bleu givre `#5EC8FF`, vert poison `#7BE04B`) alpha 45 % | cercle, ligne |
| Zone de combat / de charge | blanc bleuté `#CFE8FF` alpha 25 %, bord 3 px pulsant | cercle rayon 7 u (petit pilier), 9 u (gros pilier) |

---

## 1. Identité de Rainfall

### Pitch (3 phrases)
Dans un monde où la pluie ne s'est jamais arrêtée, un porteur de braise descend de terrasse en terrasse pour rallumer les **paratonnerres** éteints qui tenaient le déluge à distance. Chaque étage est un combat de 3 minutes contre des centaines de créatures nées de l'eau stagnante, ponctué de coffres à prix croissant et de piliers qui invoquent leurs gardiens. Le joueur construit sa puissance à coups d'items empilables lisibles, puis décide s'il repart ou s'il tente de tenir sous l'orage qui grossit.

### Ton
- **Mélancolique mais chaleureux** : la pluie est partout, le joueur est la seule source de lumière chaude à l'écran (braise, lanterne, feu de camp du menu). Pas de gore, pas d'humour parodique ; une gravité tranquille à la façon d'un conte.
- **Lisible avant tout** : tout ce qui peut blesser est annoncé ; la pluie habille, elle ne cache jamais.
- **Le jeu respecte le temps** : une run de 10 min, pause et reprise sans frustration, aucune pression hors-jeu.

### Palette et ambiance : la pluie comme motif central
| Élément | Direction |
|---|---|
| Sol | gris-bleu désaturé, valeur moyenne sombre (L* 30-45) ; flaques qui reflètent les télégraphes et les sorts |
| Joueur et sorts | chauds et saturés : orange braise `#FF9A3C`, jaune `#FFD36B`, blanc chaud |
| Monstres | froids ou acides mais **clairs** (L* ≥ 60) avec contour sombre 2 px : turquoise, violet, vert-jaune |
| Pluie | calque diagonal (12° d'inclinaison) **≤ 12 % d'opacité**, jamais au-dessus de l'UI ; intensité liée à la jauge de difficulté (Calme : bruine, Cataclysme : rideaux + éclairs blancs de 80 ms) |
| Audio | nappe de pluie continue qui s'étoffe avec D ; les sons de kill et de pièces sont « secs » pour trancher sur la nappe |
| Piliers | **paratonnerres** de bronze vert-de-gris ; chargés, ils attirent la foudre et rayonnent en blanc froid |

### Ce qui distingue Rainfall des clones
1. **Le temps qui pèse sur l'or** : les coffres sont posés dès l'arrivée, leur prix monte avec D ; attendre coûte.
2. **Deux boss à la fois si on l'ose** : les deux petits piliers peuvent être activés ensemble (deux zones, deux gardiens).
3. **Des boss qui testent un build** : chaque gardien met une synergie d'items à l'épreuve (zone, givre, burst, mobilité…) et laisse une trace au sol qui change la fin de l'étage.
4. **Cartes faites main**, à hauteur de pouce : trois cartes de 2,8-3,3 écrans de large, avec des arènes dessinées pour les zones et des couloirs pour fuir.
5. **La pluie comme système** : l'orage monte avec la difficulté ; le feu siffle, le givre tient, la rouille ronge. Le thème nourrit les boss.

---

## 2. Les 6 mini-boss (pool commun, tirage aléatoire à chaque petit pilier)

Fiche commune : **PV = 1 300 × D^1,6**, **Dég_base = 20**, récompense = 100 × D^1,25 d'or + XP de 40 kills tier 1 (Maths §5). Tous ont : silhouette ≤ 2,8 u, 1 attaque auto, 2 sorts télégraphiés, 1 passif, 1 phase 2 à 50 % PV. Les coefs sont relatifs à Dég_base (formule §0).

### 2.1 Colosse de pierre (existant, précisé)
- **Silhouette** : bloc trapu **2,5 u**, épaules carrées plus larges que la tête, bras-marteaux ; fissures orange qui pulsent (lisible à 160 px). Lent (2,2 u/s).
- **Auto : Coup de masse** : cône 90°, 2,5 u, **coef 1,0**, toutes les 1,8 s, préparation visible 0,5 s (bras levé).
- **Sort A : Charge** : télégraphe **ligne 2 u × 14 u** (orientée vers le joueur), **1,0 s**, puis course à 12 u/s ; **coef 1,8**, pousse de 2 u. Recharge **10 s**. S'il percute un obstacle ou un bord de carte, il s'écrase : **4 s de vulnérabilité** (voir passif) et étourdi 1,5 s.
- **Sort B : Onde de choc** : télégraphe **anneau** du boss jusqu'à 6 u, **0,9 s** ; **coef 1,4**, pousse de 2 u. Recharge **12 s**. Évitable en étant > 6 u ou dans le disque central de 1 u (sous le boss).
- **Passif : Peau de pierre** : -30 % de dégâts reçus, **perdue 4 s après chaque écrasement**.
- **Phase 2 (50 %)** : la charge devient **double** (seconde ligne télégraphée 1,0 s pendant la première course) ; l'onde de choc laisse **3 rochers** (obstacles de 1 u, 6 s) sur l'anneau : des murs portables pour le faire s'écraser au milieu de l'arène.
- **Contre-jeu** : se placer entre le boss et un mur (ou un rocher), esquiver perpendiculairement, frapper dans la fenêtre de 4 s.
- **Met à l'épreuve** : builds **burst** (CD mono-cible, Marque du chasseur, Chronomètre brisé) qui exploitent la fenêtre ; punit les builds de DoT lents (brûlure/poison) qui n'en profitent pas.

### 2.2 Reine des ronces (existant, précisé)
- **Silhouette** : haute et élancée **2,2 u**, vert-noir, couronne de ronces claire, traîne de racines qui s'étire derrière elle ; lente (2,4 u/s).
- **Auto : Épines** : éventail de **3 projectiles** (9 u/s, 0,5 u), toutes les 2 s, **coef 0,6 chacun**.
- **Sort A : Mares de poison** : **3 cercles de 2,5 u** (un sur le joueur, deux à ±4 u), télégraphe **0,9 s**, durent 6 s ; dedans : **coef 0,4 par 0,5 s** + 1 cumul de poison par 0,5 s (max 5, Maths §4). Recharge **10 s**.
- **Sort B : Appel des ronceux** : anneau télégraphé **1,0 s** à 4 u du boss, puis **6 monstres tier 1** (50 % PV, affixe Poison garanti sur 1 d'entre eux). Recharge **12 s**.
- **Passif : Racines** : tant qu'au moins **3 ronceux** sont vivants, régénère **1 % PV/s** (plafond 8 % PV par combat).
- **Phase 2 (50 %)** : +25 % de vitesse ; épines ×5 ; mares ×4 ; l'appel engendre 8 ronceux.
- **Contre-jeu** : tuer les ronceux (ils meurent vite), rester hors des mares, attaquer par les côtés de l'éventail.
- **Met à l'épreuve** : **Zone** (Rune de portée, Éclair en bouteille, Pointe perforante) et **Antidote** ; **Peste vivante** brille (ronceux empoisonnés qui éclatent).

### 2.3 Seigneur des cendres (existant, précisé)
- **Silhouette** : **2,3 u**, cape en lambeaux qui fume, cœur-braise visible dans la cage thoracique, bras tendus ; sous la pluie, un halo de vapeur le signale. 2,6 u/s.
- **Auto : Boule de feu** : projectile 1,4 u à 10 u/s, toutes les 2 s, **coef 0,9**, laisse une **flaque de braise** 1,5 u pendant 2 s (coef 0,3 par 0,5 s + brûlure).
- **Sort A : Pluie de météores** : **5 cercles de 2 u** qui tombent en séquence (0,4 s d'écart) à partir de la position du joueur, chacun télégraphé **1,0 s** ; impact **coef 1,6**. Recharge **11 s**.
- **Sort B : Mur de flammes** : **ligne 1,5 u × 12 u** orientée vers le joueur, télégraphe **1,2 s**, brûle 5 s ; contact **coef 0,5 par 0,5 s** + brûlure. Recharge **13 s**. Le mur bloque les projectiles ennemis mais pas ceux du joueur.
- **Passif : Érodé par la pluie** : **-40 % de vitesse** quand il n'est pas sur une flaque de braise ; ses propres boules de feu lui font donc des « marches ». Résiste à la brûlure (-50 %).
- **Phase 2 (50 %)** : la pluie redouble (visuel) : météores ×7, mur de flammes **en croix** (deux lignes), les flaques durent 4 s.
- **Contre-jeu** : rester en mouvement en cercle large, couper les lignes de flaques, ne jamais traverser le mur.
- **Met à l'épreuve** : **Mobilité** (Botte, Danseur), **Survie %** (Pavois, Orbe de veille), Antidote ; punit les builds Feu purs (résistance).

### 2.4 Ours de givre (nouveau)
- **Silhouette** : quadrupède massif **2,6 u** (long), dos hérissé de stalactites bleu pâle, museau bas, souffle blanc visible ; silhouette basse et large, inverse de l'Archonte. 2,8 u/s.
- **Auto : Patte** : cône 120°, 2,5 u, toutes les 1,8 s, **coef 1,0**, applique **Ralentissement -30 % 1,5 s** (puis 2 s d'immunité, règle des élites).
- **Sort A : Souffle de givre** : cône 60° × 8 u, télégraphe **1,0 s**, canalisé 1,5 s (le boss est immobile), **coef 0,5 par 0,5 s** + ralentissement. Recharge **10 s**. **Bloqué par les blocs de glace** (voir sort B) : ils servent de couverture.
- **Sort B : Chute de stalactites** : **6 cercles de 1,5 u** répartis dans un rayon de 5 u autour du joueur (jamais chevauchants, un sur sa position exacte), télégraphe **1,2 s**, impact **coef 1,3**, chaque impact laisse un **bloc de glace** (obstacle 1 u, 4 s). Recharge **12 s**.
- **Passif : Fourrure épaisse** : ralentissements subis réduits de moitié ; **+20 % de dégâts** tant qu'il est à moins de 2 u d'un bloc de glace (il aime son terrain).
- **Phase 2 (50 %)** : se dresse : **Bond** remplace l'auto toutes les 9 s (cercle de 3 u sur le joueur, télégraphe **1,0 s**, saut à 14 u/s, atterrissage **coef 2,2**, pousse 2 u) ; souffle en balayage (le cône tourne de 40° pendant la canalisation).
- **Contre-jeu** : se mettre derrière un bloc pendant le souffle, sortir des cercles vers l'extérieur, frapper pendant la canalisation (il est immobile 1,5 s).
- **Met à l'épreuve** : **Mobilité** (Botte, Danseur) et **Givre** : Cœur de glace ne vaut que la moitié sur lui, ce qui force les builds Givre à diversifier ; **Épines** (riposte sur ses pattes fréquentes) est excellent.

### 2.5 Essaim-mère (nouveau)
- **Silhouette** : **2,4 u**, abdomen bulbeux translucide jaune-vert qui pulse (lumière interne), 6 pattes fines, ailes floues ; silhouette en « goutte renversée », très différente des autres. 3,0 u/s, ne traverse pas les obstacles.
- **Auto : Crachat** : projectile lent (6 u/s, 0,8 u) toutes les 2,2 s, **coef 0,8**, éclate en cercle de 1,5 u.
- **Sort A : Ponte** : anneau télégraphé **1,0 s** à 3 u de la mère, puis **8 œufs** ; éclosion après **1,5 s** (œufs destructibles, 1 coup) → **larves tier 1** à 40 % PV, Meute. Recharge **9 s**.
- **Sort B : Nuée** : cercle 2,5 u télégraphé **1,0 s** sur le joueur, 12 insectes convergent depuis 8 u en 1,2 s (lisibles comme une « pluie » d'insectes) ; **coef 1,2** à la convergence. Recharge **12 s**.
- **Passif : Carapace de couvée** : tant que **≥ 6 larves** sont vivantes, **-35 % de dégâts reçus**. Compteur de larves affiché sur sa barre de vie.
- **Phase 2 (50 %)** : l'abdomen éclate : +40 % de vitesse, ponte de **12 œufs**, double crachat ; les larves nées en phase 2 **explosent à la mort** (cercle 1 u télégraphé 0,8 s, coef 0,5).
- **Contre-jeu** : casser les œufs avant l'éclosion (zone), garder la couvée sous 6, se décaler de 3 u pour la Nuée.
- **Met à l'épreuve** : **Zone** (Rune de portée, Éclair en bouteille, Pointe perforante, Tempête de braises) et **Morsure vorace / Pièce porte-bonheur** (beaucoup de petits kills soignent) ; punit les builds mono-cible lents.

### 2.6 Archonte rouillé (nouveau)
- **Silhouette** : **2,8 u de haut**, armure creuse qui flotte à 0,5 u du sol, heaume fendu à lueur cyan, hallebarde deux fois plus longue que le corps ; silhouette verticale, fine, traînée de rouille. 2,6 u/s.
- **Auto : Balayage** : arc 180°, 3 u, toutes les 2 s, **coef 1,1**, préparation 0,5 s (hallebarde en arrière).
- **Sort A : Jugement** : **ligne 1,5 u × 16 u** depuis le boss, télégraphe **1,0 s**, rayon 0,4 s, **coef 2,0**. Recharge **9 s**.
- **Sort B : Cercle de chaînes** : **anneau** (épaisseur 1 u) de rayon 5 u autour du joueur, télégraphe **1,2 s**, dure 4 s ; le traverser **coef 1,5** + ralentissement ; **2 brèches de 2 u** toujours présentes (jamais d'enfermement total). Recharge **13 s**.
- **Passif : Garde levée** : **-40 % de dégâts reçus de face** (cône 120° devant lui, comme la Carapace des brutes).
- **Phase 2 (50 %)** : l'armure se disloque (les pièces flottent autour de lui) : **perd la Garde**, +30 % de vitesse, Jugement devient **croix** (2 lignes perpendiculaires télégraphées ensemble, 1,0 s).
- **Contre-jeu** : contourner pour frapper le dos, lire les brèches de l'anneau, s'écarter latéralement du Jugement.
- **Met à l'épreuve** : **Critique** (Lentille, Œil du prédateur) et **projectiles perforants / Couronne d'écho** (qui traversent et le touchent de dos), **Recharge** (CD mono-cible fréquents) ; punit les builds purement frontaux à auto-attaque.

### Tableau récapitulatif des mini-boss
| Boss | Taille | Vitesse | Auto (coef / s) | Sort A (coef, télég., recharge) | Sort B (coef, télég., recharge) | Phase 2 |
|---|---|---|---|---|---|---|
| Colosse de pierre | 2,5 u | 2,2 | 1,0 / 1,8 | Charge 1,8 / 1,0 s / 10 s | Onde 1,4 / 0,9 s / 12 s | double charge, rochers |
| Reine des ronces | 2,2 u | 2,4 | 3×0,6 / 2,0 | Mares 0,4 par tick / 0,9 s / 10 s | Ronceux – / 1,0 s / 12 s | +25 % vit., ×5 épines |
| Seigneur des cendres | 2,3 u | 2,6 | 0,9 / 2,0 | Météores 1,6 / 1,0 s / 11 s | Mur 0,5 par tick / 1,2 s / 13 s | ×7 météores, croix |
| Ours de givre | 2,6 u | 2,8 | 1,0 / 1,8 | Souffle 0,5 par tick / 1,0 s / 10 s | Stalactites 1,3 / 1,2 s / 12 s | Bond 2,2 |
| Essaim-mère | 2,4 u | 3,0 | 0,8 / 2,2 | Ponte – / 1,0 s / 9 s | Nuée 1,2 / 1,0 s / 12 s | +40 % vit., 12 œufs |
| Archonte rouillé | 2,8 u | 2,6 | 1,1 / 2,0 | Jugement 2,0 / 1,0 s / 9 s | Chaînes 1,5 / 1,2 s / 13 s | perd Garde, croix |

---

## 3. Les 3 boss d'étage (un par carte)

Fiche commune : **PV = 2 200 × D^1,6**, **Dég_base = 24**, zone de charge rayon 9 u (90 s), récompense = 250 or + 100 XP + coffre gratuit Rare+ (Maths §5). Phases à **70 %** et **35 %**. Le passif est un **passif de phase** : il change à chaque seuil.

### 3.1 L'Éclusier (carte 1, Terrasses noyées)
Gardien de la grande vanne qui retenait l'eau des terrasses.
- **Silhouette** : **3,5 u**, corps de bois noir cerclé de bronze, **roue de vanne** dans le dos (lisible même de loin), bras-portes. 2,4 u/s.
- **Auto : Coup de vanne** : cône 90°, 3 u, toutes les 1,8 s, **coef 1,0**.
- **Sort A : Lâcher d'eau** : **ligne 4 u × 18 u** depuis le boss vers le joueur, télégraphe **1,2 s**, vague à 10 u/s, **coef 1,6**, pousse de 3 u. Recharge **10 s**. La poussée peut faire sortir de la zone : danger pour la charge.
- **Sort B : Geysers** : **4 cercles de 2 u** (un sur le joueur, trois dans 5 u), télégraphe **0,9 s**, **coef 1,4**. Recharge **9 s**.
- **Phase 1 (100-70 %) : Vanne fermée** : comportement de base.
- **Phase 2 (70 %) : Montée des eaux** : toute la zone de charge se couvre d'eau peu profonde (visuel : éclaboussures, reflets) ; **2 geysers permanents** apparaissent à 6 u du gros pilier (cercles 2 u, pulsent toutes les 4 s avec télégraphe 0,9 s, coef 1,0) ; Lâcher d'eau devient **double** (deux lignes à ±30°).
- **Phase 3 (35 %) : Rupture** : le boss **s'ancre** au centre de sa position (immobile jusqu'à la mort = fenêtre de DPS) ; la roue tourne : **4 lignes en croix** (3 u × 14 u) pulsent toutes les 3 s avec télégraphe **1,0 s**, **coef 1,2** ; geysers toutes les 6 s. Les 2 geysers permanents **restent après sa mort** jusqu'à la fin de la charge.
- **Contre-jeu** : se tenir en diagonale des lignes, dos au centre de la zone pour que les poussées ne sortent pas de la zone, profiter de l'ancrage.
- **Met à l'épreuve** : **Survie %** (Bague, Pavois, Orbe de veille), **Mobilité**, et la gestion de zone (rester dedans malgré les poussées).
- **Coup le plus lourd** : 1,6 (45 dégâts s'il tombe à l'étage 1 = 21 % de 220 PV ; les cartes tournent dans un ordre aléatoire, chaque boss d'étage peut donc être le premier rencontré).

### 3.2 Le Cerf-Lanterne (carte 2, Forêt-brume)
Esprit de la forêt noyée, ses bois portent des lanternes qui attirent les feux follets.
- **Silhouette** : cervidé **3,2 u**, bois en forme de **lanternes allumées** (vert pâle `#9CF0C8`), corps sombre, pattes longues ; la ramure lumineuse se lit à 30 u. 3,2 u/s.
- **Auto : Coup de bois** : cône 60°, 2,5 u, toutes les 1,6 s, **coef 1,0**.
- **Sort A : Charge lumineuse** : **ligne 2,5 u × 16 u**, télégraphe **1,0 s**, course à 13 u/s, **coef 1,8** ; laisse **4 feux follets fixes** (1 u, 6 s) le long de la ligne qui éclatent au contact (cercle 1,5 u, **coef 0,6**). Recharge **10 s**.
- **Sort B : Appel des follets** : anneau télégraphé **1,0 s** à 5 u, puis **6 follets** (tier 1 rapides, 3,2 u/s, 30 % PV) qui **explosent à la mort** (cercle 1,5 u télégraphé **0,8 s**, **coef 0,8**). Recharge **11 s**.
- **Phase 1 (100-70 %) : Lanternes calmes** : base.
- **Phase 2 (70 %) : Brume** : l'anneau extérieur de 2 u de la zone de charge devient brume : les **monstres y gagnent +30 % de vitesse** (le joueur, rien) ; les lanternes s'allument : portée de l'auto +1 u, follets ×8.
- **Phase 3 (35 %) : Lanternes éteintes** : le cerf **s'évapore** toutes les 6 s et réapparaît sur le bord de la zone (cercle 3 u télégraphé **1,0 s**, atterrissage **coef 1,0**), puis enchaîne immédiatement une Charge lumineuse (télégraphe normal 1,0 s). La brume **persiste après sa mort** jusqu'à la fin de la charge.
- **Contre-jeu** : tuer les follets à distance ou les laisser exploser loin, rester au centre (hors brume), se décaler de la ligne de charge dès le cercle d'apparition.
- **Met à l'épreuve** : **Zone** (follets) et **mono-cible contre cible mobile** (Plume d'empenne, Carquois, Rafale d'acier : la vitesse de projectile compte), **Danseur**.
- **Coup le plus lourd** : 1,8 (51 à l'étage 1 = 23 % de 220 PV).

### 3.3 Le Sonneur (carte 3, Cité de rouille)
Automate-cloche qui faisait sonner l'alerte de crue ; rouillé, il ne sonne plus que la foudre.
- **Silhouette** : **3,8 u**, **tête-cloche** en bronze vert-de-gris, corps de chaudière rivetée, bras-marteaux, **paratonnerre** sur la cloche. 2,2 u/s. Le plus gros du jeu.
- **Auto : Marteau** : cône 90°, 3 u, toutes les 2,0 s, **coef 1,0**.
- **Sort A : Glas** : anneau de choc qui part du boss et s'étend de 1 à **8 u** en 0,8 s, télégraphe **1,0 s** (anneau rouge à 8 u + vibration de la cloche), **coef 1,5** ; évitable en étant > 8 u ou dans le disque de 1 u sous le boss. Recharge **10 s**.
- **Sort B : Pluie de boulons** : **6 cercles de 2 u** dans un rayon de 6 u autour du joueur (un sur sa position), télégraphe **1,0 s**, **coef 1,3**. Recharge **9 s**.
- **Phase 1 (100-70 %) : Carillon** : base.
- **Phase 2 (70 %) : Foudre** : le paratonnerre attire la foudre : toutes les **5 s**, un **éclair** frappe un cercle de 2 u télégraphé **1,0 s** sur le joueur, **coef 2,5** (le plus lourd du jeu, toujours clampé à 40 %). Glas devient **double** (second anneau 1,5 s après le premier).
- **Phase 3 (35 %) : Chaudière rompue** : la chaudière s'ouvre : **+25 % de dégâts reçus** par le boss, **+25 % de vitesse d'attaque** (auto 1,6 s, recharges ×0,8) ; **4 jets de vapeur** fixes depuis le boss (lignes 1 u × 6 u en croix, tournant à 20°/s, visibles en permanence = télégraphe continu), **coef 0,4 par 0,5 s**. Après sa mort, la foudre **continue** (toutes les 8 s) jusqu'à la fin de la charge.
- **Contre-jeu** : rester à 4-7 u (hors vapeur, hors glas en se reculant), lire le rythme de 5 s de la foudre, exploiter la phase 3 qui favorise le burst.
- **Met à l'épreuve** : **Survie %** (Armure du colosse, Bouclier réactif absorbe un éclair entier), **mêlée contre distance** (Brise-Os doit danser avec le Glas), **Marque du chasseur**.
- **Coup le plus lourd** : 2,5 (71 à l'étage 1 = 32 % de 220 PV ; 126 à l'étage 3 = 23 % de 550 PV ; clamp 40 % utile en Difficile).

### Tableau récapitulatif des boss d'étage
| Boss | Carte | Taille | Auto | Sort A | Sort B | 70 % | 35 % | Trace après la mort |
|---|---|---|---|---|---|---|---|---|
| L'Éclusier | 1 | 3,5 u | 1,0 / 1,8 s | Lâcher d'eau 1,6 / 1,2 s / 10 s | Geysers 1,4 / 0,9 s / 9 s | eau + 2 geysers fixes, double ligne | ancré, croix 1,2 | 2 geysers |
| Le Cerf-Lanterne | 2 | 3,2 u | 1,0 / 1,6 s | Charge 1,8 / 1,0 s / 10 s | Follets 0,8 / 1,0 s / 11 s | brume (+30 % vit. monstres), 8 follets | téléport + charge | brume |
| Le Sonneur | 3 | 3,8 u | 1,0 / 2,0 s | Glas 1,5 / 1,0 s / 10 s | Boulons 1,3 / 1,0 s / 9 s | foudre 2,5 / 5 s, double glas | +25 % dég. reçus, vapeur | foudre / 8 s |

---

## 4. Les 3 cartes dessinées à la main

### Conventions communes
- **Échelle des schémas** : 1 caractère = **2 u × 2 u** (128 px). Les coordonnées listées sont le **centre de la case en u** (origine en haut à gauche).
- Légende : `#` obstacle infranchissable (muret, tronc, cuve), `~` eau profonde (infranchissable pour tous), `,` eau peu profonde (franchissable, éclaboussures, aucune pénalité), `.` sol, `C` emplacement candidat de coffre, `P` candidat de petit pilier, `G` candidat de gros pilier, `E` candidat d'événement, `S` apparition du joueur.
- **Tirage par étage** : 8 petits + 2 grands coffres (+1 légendaire à 25 %) parmi les `C` ; 2 petits piliers parmi les `P` et 1 gros parmi les `G`, avec contraintes : **distance ≥ 18 u entre deux piliers**, **gros pilier ≥ 20 u du spawn**, le disque de 7 u (petit) / 9 u (gros) autour du pilier contient **≥ 70 % de sol praticable**. Le coffre légendaire est tiré parmi les `C` à **≥ 24 u du spawn** (il doit se mériter).
- **Apparition des monstres** : hors champ, à 2-4 u derrière le bord de la caméra, sur `.` ou `,` uniquement ; jamais sur `#`/`~`. Dans une zone active, les surplus (×1,5) apparaissent sur le bord de la zone.
- **Taille** : chaque carte fait 2,8 à 3,3 écrans de large et 1,9 à 2,7 écrans de haut : assez pour fuir, pas assez pour se perdre (un trajet spawn → pilier le plus loin ≤ 15 s à 4 u/s).
- **Arènes** : chaque carte a **3 zones ouvertes ≥ 20 u × 14 u** sans obstacle (un combat de zone s'y lit en entier), reliées par des **couloirs de 4-8 u** qui servent à « peigner » la foule ; des obstacles isolés d'1-2 u dans les arènes servent de murs pour le Colosse.
- **Lisibilité (contraste sol/monstres)** : sol en **L\* 30-45, chroma faible** ; textures de sol à **basse fréquence** (pas de motifs de 1-2 px qui vibrent sous 250 sprites) ; monstres en L\* ≥ 60 + contour sombre ; les obstacles ont un **liseré clair 2 px** côté haut-gauche (éclairage cohérent CLAUDE.md) pour que la collision se devine ; **eau profonde** plus sombre que le sol (L\* 20) avec reflet animé, **eau peu profonde** = sol + ondulations claires. Le rouge/orange/bleu/vert saturés sont **réservés** aux télégraphes et statuts (§0).

### 4.1 Carte 1 : « Terrasses noyées » : 56 u × 64 u (3 584 × 4 608 px)
**Thème** : rizières en terrasses abandonnées, murets de pierre moussue, bassins débordants, pins tordus. Bruine fine, lumière gris-vert, lanternes de pierre éteintes. C'est la carte d'apprentissage : la plus ouverte.
**Palette** : sol `#4A5B5A` → `#5C6E68` (mousse), murets `#2F3A3C` liseré `#8AA09A`, eau profonde `#1F3139`, eau peu profonde `#54707A`, accents bronze `#8C7A4C`.

```
############################
#~~~~.......#.....C........#
#~~~...C....#.........P....#
#~~.........#.......E......#
#......P....#.......C......#
#...........#..............#
#.....C.....####....C......#
#..............#...........#
#######..#######...####..###
#........#.................#
#...C....#.....G.......C...#
#........#.................#
#..P.....#.................#
#........##...........C....#
#...~~.........E...........#
#..~~~~...C....S.......~~~.#
#...~~.................~~~~#
#..........G..........P.~~.#
#....C..................~..#
#..######.......####.......#
#..#...C........#..#...C...#
#..#............#..#.......#
#..####.........#..#..####.#
#...............#..#.......#
#..C.....P......####...P...#
#...........G..............#
#.....####......E.....C....#
#.....#..#.................#
#..C..#C.#.....C.....,,,,..#
#.....#..#...........,,~,,.#
#..........P........C,,,,..#
############################
```

- **Arènes** : (A) terrasse haute nord-est, lignes 1-7 / colonnes 13-26 (≈ 28 × 14 u) ; (B) grande terrasse centrale, lignes 9-18 / colonnes 10-26 (≈ 34 × 20 u, la plus grande, contient le spawn) ; (C) terrasse basse sud, lignes 23-30 (≈ 52 × 14 u, coupée par la ruine centrale). Les murets de la ligne 8 et de la ligne 19 ont des **escaliers** (brèches de 4-6 u) : trois passages par muret.
- **Couloirs** : la bande ouest (colonnes 1-8, lignes 9-18) et les brèches des murets ; le bassin sud-est (`,`) est un piège à foule praticable.
- **Candidats** (centre en u, x;y) :
  - Coffres (18) : (37;3), (15;5), (41;9), (13;13), (41;13), (9;21), (47;21), (45;27), (21;31), (11;37), (15;41), (47;41), (7;49), (45;53), (7;57), (15;57), (31;57), (41;61)
  - Petits piliers (7) : (45;5), (15;9), (7;25), (45;35), (19;49), (47;49), (23;61)
  - Gros piliers (3) : (31;21), (23;35), (25;51)
  - Événements (3) : (41;7), (31;29), (33;53)
  - Spawn : (31;31)
- **Événements de carte** (1 par étage au plus, tiré parmi les `E`, détail §4.4) : **Autel de fortune** sous la forme d'une lanterne de pierre ; **Sanctuaire de risque** = bassin qu'on vide ; **Marchand de l'ombre** = barque amarrée ; **Coffre piégé** = coffre à demi immergé.
- **Événement ambiant** : à Hostile (D ≥ 2,5), les bassins **débordent** : les cases `,` du sud s'élargissent d'1 u (visuel seulement, pas de collision nouvelle).

### 4.2 Carte 2 : « Forêt-brume » : 64 u × 56 u (4 096 × 3 584 px)
**Thème** : mangrove de cèdres géants, racines en arches, sanctuaires à lanternes, étangs noirs. Pluie lourde, brume basse au ras du sol (calque ≤ 10 %), lucioles vertes. Carte en **moyeu et rayons** : une clairière centrale et quatre clairières périphériques.
**Palette** : sol `#3E4A3F` → `#55634E`, racines `#2A2420` liseré `#9A8C6A`, eau `#17262B`, lanternes `#9CF0C8`, brume `#B8C8C0` à 10 %.

```
################################
#....C.......##.......~~~.....C#
#............##......~~~~......#
#..P....E....##.......~~.....P.#
#............#..........C......#
#.....C......#.................#
####..#####.....#####....###...#
#..................#.....C.....#
#...~~.......C.....#.....G.....#
#..~~~~............#...........#
#...~~......G......#.......C...#
#..................###.....#####
#.C...............E............#
#.........#####.......,,,......#
#.........#...#...S...,,,......#
#..P......#.C.#...............C#
#.........#...#.........P......#
#.........###.#................#
#####..........................#
#.......C..........#####...#####
#.........C............#.......#
#...~~~......E.........#...C...#
#..~~~~.....................P..#
#...~~......G..........#.......#
#..........C...........#.......#
#.P....................####..C.#
#....C.........C...............#
################################
```

- **Arènes** : (A) clairière nord-ouest, lignes 1-5 / colonnes 1-12 (24 × 10 u, petite : réservée aux petits piliers) ; (B) clairière ouest-centre, lignes 7-12 / colonnes 1-18 (36 × 12 u) ; (C) **clairière centrale**, lignes 12-18 / colonnes 15-30 (32 × 14 u, le sanctuaire du spawn, trois racines en `#` au centre-gauche font un abri) ; (D) clairière sud, lignes 19-26 / colonnes 1-22 (44 × 16 u, la plus grande) ; (E) terrasse est, lignes 7-10 / colonnes 20-30 (22 × 8 u).
- **Couloirs** : brèches des racines (ligne 6 : colonnes 4-5, 11-15, 21-24, 28-30 ; ligne 11 : colonnes 22-26 ; ligne 18 : tout sauf colonnes 0-4 ; ligne 19 : colonnes 24-26).
- **Candidats** (x;y en u) :
  - Coffres (17) : (11;3), (61;3), (49;9), (13;11), (51;15), (27;17), (55;21), (5;25), (25;31), (61;31), (17;39), (21;41), (55;43), (23;49), (59;51), (11;53), (31;53)
  - Petits piliers (6) : (7;7), (59;7), (7;31), (49;33), (57;45), (5;51)
  - Gros piliers (3) : (51;17), (25;21), (25;47)
  - Événements (3) : (17;7), (37;25), (27;43)
  - Spawn : (37;29)
- **Événements de carte** : **Autel de fortune** = sanctuaire à lanterne ; **Sanctuaire de risque** = cercle de champignons ; **Marchand de l'ombre** = silhouette sous une racine ; **Coffre piégé** = coffre couvert de mousse.
- **Événement ambiant** : à Furieux (D ≥ 4), les **lucioles s'éteignent** et la brume monte à 15 % ; les lanternes des sanctuaires s'allument (points de repère). Lisibilité garantie : la brume n'est jamais appliquée sur les monstres ni sur les télégraphes (calque sous les entités).

### 4.3 Carte 3 : « Cité de rouille » : 48 u × 80 u (3 072 × 5 120 px)
**Thème** : canal industriel vertical, cuves rouillées, passerelles, cloche d'alerte au sud. Pluie en rideaux, éclairs, reflets orange des lampes à vapeur. Carte **verticale** (2,7 écrans de haut) : deux berges reliées par **trois ponts**, une cour haute et une **grande cour basse** pour le Sonneur.
**Palette** : sol `#3B3F46` (béton mouillé) → `#4E4A44` (rouille sèche), cuves `#26292E` liseré `#B07A48`, eau profonde `#141B22`, eau peu profonde `#3F4E58`, lampes `#FF9A3C` (petites, pour ne pas concurrencer le joueur).

```
########################
#..C........##......C..#
#...........##...C.....#
#...P.......##....P....#
#...........##.........#
#.....E.....##....C....#
#..C........##.........#
####.....####.....####.#
#.........~~~~.........#
#.........~~~~.........#
#..C......~~~~....C....#
#.........~~~~.........#
#.........,,,,.........#
#...G.....,,,,.....G...#
#.........,,,,.........#
#.........~~~~.........#
#..P......~~~~......P..#
#.........~~~~.........#
#.C.......~~~~.......C.#
#.........~~~~.........#
#.###.....~~~~.....###.#
#.#.E.....,,,,.....#...#
#.........,,S,.........#
#.........,,,,.........#
#..C......~~~~......C..#
#.........~~~~.........#
#...P.....~~~~.........#
#.........~~~~....P....#
#.........~~~~.........#
#..C......,,,,......C..#
#.........,,,,.........#
#.........~~~~.........#
####.....####.....####.#
#......................#
#..C.......E.......C...#
#......................#
#....P.....G.....P.....#
#......................#
#..C...............C...#
########################
```

- **Arènes** : (A) cour haute, lignes 1-6, coupée par un mur central en deux moitiés de 22 × 12 u ; (B) berge ouest et (C) berge est, lignes 8-31, chacune **18 u de large** : des couloirs longs où la foule s'étire, avec trois ponts (`,`, lignes 12-14, 21-23, 29-30, 8 u de large) pour changer de berge ; (D) **grande cour basse**, lignes 33-38 (44 × 12 u) : arène de boss privilégiée (`G` (23;73)), on y entre par trois brèches.
- **Gros piliers sur les berges** : (9;27) et (39;27) sont au niveau du pont nord : la zone de 9 u couvre la berge, le pont et déborde sur le canal (les monstres n'y apparaissent pas, le joueur peut traverser par le pont). Le choix du `G` change nettement le combat : berge = couloir, cour basse = arène.
- **Candidats** (x;y en u) :
  - Coffres (17) : (7;3), (41;3), (35;5), (37;11), (7;13), (7;21), (37;21), (5;37), (43;37), (7;49), (41;49), (7;59), (41;59), (7;69), (39;69), (7;77), (39;77)
  - Petits piliers (8) : (9;7), (37;7), (7;33), (41;33), (9;53), (37;55), (11;73), (35;73)
  - Gros piliers (3) : (9;27), (39;27), (23;73)
  - Événements (3) : (13;11), (9;43), (23;69)
  - Spawn : (25;45) (sur le pont central)
- **Événements de carte** : **Autel de fortune** = lampe à vapeur ; **Sanctuaire de risque** = vanne de pression ; **Marchand de l'ombre** = guichet grillagé ; **Coffre piégé** = caisse rivetée.
- **Événement ambiant** : à Furieux (D ≥ 4), **orage** : un éclair de décor toutes les 10-20 s (flash blanc 80 ms, désactivable avec les secousses) ; à Cataclysme, le canal **monte** : les ponts `,` deviennent sol + reflets (visuel) et les lampes clignotent.

### 4.4 Événements de carte (règles communes, 1 au plus par étage, 60 % de chance qu'il y en ait un)
| Événement | Interaction | Effet | Garde-fou |
|---|---|---|---|
| **Autel de fortune** | 1 offrande = 40 % du prix d'un petit coffre | Lance un d100 **visible** : 1-50 rien, 51-90 un Commun, 91-100 un Peu commun ; 3 offrandes max | Le dé est joué devant le joueur ; coûte moins qu'un coffre, rend moins |
| **Sanctuaire de risque** | Activation gratuite | Pendant 45 s : monstres **×1,5** dans 10 u, or **×2** ; à la fin, un petit coffre gratuit si le joueur est resté ≥ 30 s dans le rayon | Jamais cumulé avec une zone de pilier (désactivé si un pilier est actif à < 20 u) |
| **Marchand de l'ombre** | Vend **1 item visible** (Peu commun 70 % / Rare 30 %) au prix d'un grand coffre ×1,2 | Achat sans dé, sans relance | Disparaît au premier achat ou après 60 s |
| **Coffre piégé** | Ressemble à un petit coffre, prix -30 % | À l'ouverture : 8 monstres tier 2 (dont 1 élite) apparaissent sur un anneau télégraphé 1,0 s, puis le coffre s'ouvre normalement (table d'un petit coffre, pity inclus) | Indice visuel : chaîne cassée + prix barré ; jamais à < 12 u du spawn |

---

## 5. Assets à produire (priorisés)

Priorités : **P0** = nécessaire au mois 2 (1 carte jouable, 6 mini-boss, 1 boss d'étage) ; **P1** = mois 3 (cartes 2-3, boss 2-3, passe VFX) ; **P2** = polish. Tous les sprites sont **pré-rendus depuis Blender** (CLAUDE.md), éclairage haut-gauche, fond transparent, filtre linéaire. Les angles : vue de dessus légèrement inclinée (≈ 60° au-dessus de l'horizon), **4 directions** (N, E, S, O ; les diagonales par interpolation ou miroir) pour les boss, **8 images** par cycle de marche.

### 5.1 Assets partagés (P0)
| Asset | Spécification |
|---|---|
| Télégraphes | 4 formes vectorielles (`_draw` ou shader) : cercle, ligne (capsule), cône, anneau ; remplissage progressif ; palette §0. Aucun sprite nécessaire |
| Zone de combat / de charge | shader de disque 7 u / 9 u, bord pulsant, jauge de charge circulaire pour le gros pilier |
| Piliers | **petit paratonnerre** 1,5 u (96 px) et **gros paratonnerre** 2,5 u (160 px), 3 états chacun : éteint, actif (arc électrique en boucle 8 images), terminé (lueur blanche) |
| Coffres | petit 1 u, grand 1,3 u, légendaire 1,5 u ; fermé / tremble (6 images) / ouvert ; coffre piégé = variante petit avec chaîne cassée |
| Événements | 4 props de 1,5-2 u (autel, sanctuaire, marchand, variante par carte en P2) |
| Statuts | 3 icônes 24 px (brûlure, givre, poison) + 3 particules de statut |
| Pluie | shader plein écran (lignes diagonales, 3 intensités) + éclaboussures au sol (atlas 8 images) |
| Barre de vie de boss | HUD : nom, barre segmentée aux seuils (50 % mini / 70 % et 35 % étage), compteur de larves pour l'Essaim-mère |

### 5.2 Par mini-boss (6 × le même jeu, sprites **160-180 px** pour 2,2-2,8 u)
| Animation | Images | Notes |
|---|---|---|
| Idle | 6 | respiration, élément qui pulse (fissures, abdomen, heaume) |
| Marche (4 dir.) | 8 × 4 | |
| Auto | 6 | la préparation (0,5 s) doit se lire : membre en arrière |
| Sort A | 8 | pose de lancer distincte de l'auto |
| Sort B | 8 | |
| Transition phase 2 | 8 | 1,0 s : éclatement d'abdomen, armure qui se disloque, ours qui se dresse… |
| Mort | 10 | + particule de mort spécifique |
| Projectiles / props | épines, boule de feu + flaque, crachat, œuf (3 états), larve, ronceux, rocher 1 u, bloc de glace 1 u, pièces d'armure flottantes (3) | 32-64 px |

Ordre de production conseillé : **Colosse de pierre** (le plus simple, valide le pipeline) → Ours de givre → Archonte rouillé → Reine des ronces → Essaim-mère (le plus de props) → Seigneur des cendres (shader de braise).

### 5.3 Par boss d'étage (sprites **224-256 px** pour 3,2-3,8 u)
| Boss | Priorité | Spécifique en plus du jeu commun (idle, marche 4 dir., auto, 2 sorts, 2 transitions, mort) |
|---|---|---|
| L'Éclusier | **P0** (carte 1) | roue de vanne animée (boucle 8), vague (sprite de ligne 4 u animé, 8 images), geyser (12 images, boucle), pose « ancré » phase 3 |
| Le Cerf-Lanterne | P1 | ramure avec lumière émissive (couche séparée pour pulser en code), feu follet (6 images + explosion), évaporation/réapparition (8 + 8), brume d'anneau (shader) |
| Le Sonneur | P1 | cloche qui vibre (6 images), paratonnerre + éclair (sprite d'éclair 2 u × 12 u, 4 variantes), boulon (32 px), chaudière ouverte (couche), jets de vapeur (shader de ligne) |

### 5.4 Par carte
| Carte | Priorité | Tileset et props |
|---|---|---|
| Terrasses noyées | **P0** | 4 tuiles de sol (mousse, pierre, boue, herbe), 2 tuiles d'eau (profonde / peu profonde, shader de reflet), murets (coins + droits + brèche escalier), 6 props (pin tordu, lanterne de pierre, barque, jarre, stèle, rocher), overlay de bruine |
| Forêt-brume | P1 | 4 tuiles de sol, étangs, racines en arche (3 modules + coins), 6 props (cèdre, sanctuaire-lanterne, champignons, souche, pierre levée, lucioles en particules), calque de brume |
| Cité de rouille | P1 | 4 tuiles (béton mouillé, rouille, grille, pont), canal (shader d'eau en mouvement), cuves (2 tailles), passerelles, 6 props (lampe à vapeur, vanne, guichet, caisse, câbles, cloche), éclairs de décor |

Chaque carte est livrée avec un **fichier de données** (`game/data/maps/<carte>.json`) : taille, grille de collision, liste des candidats `C/P/G/E/S` ci-dessus, arènes (rectangles) et palette. Le schéma ASCII de ce document est la source de vérité jusqu'au dessin final.

---

## 6. Besoins techniques à signaler à l'orchestrateur (contrats nouveaux)
1. **`Events.boss_phase_changed(boss, phase: int)`** : nécessaire pour le HUD (barre segmentée), la musique et les traces de phase.
2. **Composant Télégraphe** (`scripts/combat/telegraph.gd` ou équivalent) : forme, durée, remplissage progressif, callback à l'échéance ; utilisé par monstres et boss.
3. **Obstacles temporaires** (rochers, blocs de glace, feux follets fixes) : nœuds de collision sur la couche 1 « world » avec durée de vie, et **blocage des sorts en cône** (souffle de l'Ours) par ces obstacles.
4. **Règle d'ignorance partielle des ralentissements** sur les boss (×0,5) et immunité aux poussées : à exposer dans `Balance`.
5. **Schéma JSON des boss** (`game/data/bosses.json`) : `id, kind (mini|floor), size_u, speed, auto {shape, range, coef, interval, windup}, spells [{id, shape, params, telegraph_s, coef, cooldown_s, first_cast_s}], passive, phases [{threshold, changes}]`.
6. Les poussées (Colosse, Éclusier) doivent **respecter les collisions** et ne jamais pousser dans l'eau profonde ni dans un mur.

---

## 7. Points à valider en playtest
- Les **coefficients** 2,2 / 2,5 (35 % des PV tôt dans la run) : trop punitif pour un débutant en Facile à 0:30 ? Alternative : Dég_base mini 18 / étage 22.
- Les boss **à +40 % hors zone** : suffisant pour empêcher le kite, pas injuste ?
- La **trace après la mort** du boss d'étage (geysers, brume, foudre) pendant la fin de charge : lisible et désirable, ou punition perçue ?
- L'**Essaim-mère** avec 250 monstres déjà à l'écran : le compteur de larves et la Carapace de couvée restent-ils compréhensibles ?
- La **carte 3** avec les berges de 18 u : un gros pilier sur une berge est-il trop étroit avec une zone de 9 u ?
- La règle « 2 piliers en même temps » sur la carte 2 (clairières nord-ouest et sud à 44 u l'une de l'autre) : la distance ≥ 18 u suffit-elle pour que les deux zones restent distinctes mais atteignables ?
