# Monstres de base v2 — refonte des 4 rôles × 5 biomes (brief, 28/10/2026)

Retour du joueur (28/10/2026) : « Les modèles des mobs de base me semblent très basiques et très cheap, il faudra les revoir » et « il n'y a aucune animation de coups pour les monstres de base, seulement des dégâts au contact pour les monstres corps à corps ». Ce brief fait foi pour les lots `art/tools/night/_mob_v2_<lot>.txt`. Il remplace `art/briefs/monsters.md` pour les monstres courants (tiers 1-3) ; les mini-boss et boss ne sont pas concernés. Règles de fond inchangées : `STYLE.md` (DA officielle en tête, optimisation), `STYLE_boss_da.md`, `STYLE_cel.md` (rendu cel, aucun `_n`), `docs/Design_Isometrique.md` §4.4 (rig CREA), `docs/Design_Etages.md` §3 (thèmes et accents des biomes).

## 1. Diagnostic de l'existant (lot C5 + variantes N2e/N3e)

Observé sur `game/assets/sprites/monsters/*/run.png` à 1× sur le sol réel (`terrain/terraces/iso/ground_a.png`) et dans `art/tools/monsters/iso_monster_build.py` :

1. **Construction par primitives.** Chaque créature est un assemblage de `rod` (capsules de rayon constant) et de `shell` (coque à 8 côtés). Membres = tubes sans articulation ni épaississement, têtes = une coque, aucune griffe, dent, sangle ou pièce qui dépasse à l'échelle d'affichage. Le brut se lit comme « tuyaux et boîtes » ; le tireur à 64 px/u × 0,9 n'est plus qu'un bonhomme-bâton (membres de 3-4 px, dont 3 px d'encre).
2. **Animation rigide.** Corps : oscillation de ±1,2 cm ; membres : rotation sinusoïdale autour d'un seul pivot (0,16-0,23 rad, soit ~10°), sans cycle de marche (pas de pose de contact / passage, aucun pied planté), sans mouvement secondaire (queue, tissu, chaînes). Les attaques sont une bascule de tout le corps en X : rien ne frappe, la créature « tangue ». 8 frames pour ~10° d'amplitude = frames gâchées.
3. **Silhouettes interchangeables.** Essaim = cafard plat et symétrique sans tête lisible ; tireur = bâton vertical ; bondisseur = araignée à pattes fines ; brute = la plus lisible mais boîte symétrique à tête-cube. À distance de jeu les quatre sont des taches sombres de même valeur.
4. **Valeurs trop basses.** Albédos de base `#202224`, `#1B1D23`, `#202A27` : après la rampe cel (0,63 / 1,12 / 1,65) le corps reste presque noir sur un sol `#2B3340` ; seul l'accent et l'encre se voient. `ash_lord` et `mist_wolf` (références validées) lisent grâce à de grands aplats clairs (os `#8D8B72`, poil gris-vert) où les 3 tons sont visibles.
5. **Variantes de biome = changement de matière.** N2e (`_moss`) et N3e (`_rust`) réutilisent les mêmes modèles : 12 dossiers pour 4 silhouettes ; la faune d'un étage ne raconte rien de son biome.
6. **Cellules gaspillées.** Essaim rendu à 90,51 px/u puis affiché à 0,566 (×0,8 × 64/90,51) ; les autres à 64 px/u puis ×0,8-0,9 ; cellules carrées remplies à ~55 %. Le budget monstres (12 Mo mobile) est déjà aux deux tiers (8,2 Mo) pour 3 biomes.
7. **Pas d'anims de coup ni de repos.** Essaim : `run` seulement (il court sur place quand il s'arrête) ; aucun rôle n'a `idle` (le code demande déjà `idle`, `enemy.gd` l. 802, et retombe sur `run`) ; les coups existants (`attack`, `cast`, `charge`) sont les bascules du point 2.

Ce qui fait la DA validée (ash_lord, mist_wolf, boss d'étage) et manque ici : volumes construits avec biseaux et pièces qui débordent, une grande zone claire par créature, proportions crédibles, asymétrie, gestes d'attaque avec anticipation et extension.

## 2. Contrat de format v2 (identique pour les 5 biomes)

| | Essaim (`swarm_tier1<suffixe>`) | Tireur (`shooter_tier2<suffixe>`) | Bondisseur (`leaper_tier2<suffixe>`) | Brute (`brute_tier3<suffixe>`) |
|---|---|---|---|---|
| Taille en jeu | 0,8 u de long, ≤ 0,55 u de haut | 1,25 u de haut, mince | 1,1 u de long, 0,75 u de haut (dos) | 1,7 u de haut, 1,3 u d'épaules |
| Cellule (px, L × H) | **64 × 56** | **88 × 104** | **96 × 96** | **128 × 136** |
| Ligne des pieds (`bottom`, px depuis le haut) | 48 | 96 | 82 | 124 |
| Densité de rendu | 64 px/u (`render_px_per_u` 64, pas d'échelle en jeu : `scale` 1,0) | idem | idem | idem |
| Anims (frames) | idle 4, run **8**, attack 6, death 4 | idle 4, run 8, attack 8, death 4 | idle 4, run 8, charge 6, leap 4, attack 6, death 4 | idle 4, run 8, attack 8, cast 8, death 6 |
| Directions | 8 (`e, se, s, sw, w, nw, n, ne`) pour tout sauf `death` : 4 (`e, s, w, n`) | idem | idem | idem |
| Cellules par biome | 144 | 176 | 240 | 248 |

- Suffixes de biome : terrasses aucun, forêt `_moss`, cité `_rust`, cryptes `_salt`, Source `_source` (`game/data/fauna.json`, inchangé). Dossier `game/assets/sprites/monsters/<nom>/`, planches `<anim>.png` + `<anim>_e.png` (demi-résolution), `<nom>.tres`. Aucun `_n`.
- Planche : une ligne par direction (ordre ci-dessus), une colonne par frame, cellule fixe par rôle. `death.png` = 4 lignes (e, s, w, n). Jamais plus de 4096 px de côté (max ici : brute attack 1024 × 1088).
- Pivot : pieds centrés en x, sur la ligne `bottom` ; marges ≥ 4 px ; **la cellule est un plafond** : si une pose déborde, réduire l'amplitude ou le modèle, jamais agrandir la cellule (le code lit une géométrie unique par rôle, `EnemyVisual.SPRITES`).
- `.tres` texte (`SpriteFrames`, `AtlasTexture` par frame, diffus en `ExtResource` direct) : animations `<anim>_<dir>` ; fps idle 8, run 14, attack / cast / charge 12, leap 14, death 12 ; `loop` vrai pour idle, run, leap, faux pour les autres. Mêmes conventions que `swarm_tier1.tres` / `leaper_tier2.tres` actuels.
- **Frame d'impact** (lue par le code, fraction 0,5 comme `EnemyVisual.BOSS_IMPACT_FRAC`) : index `floor(n / 2)` → attack 6 fr : frame 3 ; attack / cast 8 fr : frame 4. Avant : anticipation (recul, armement) ; à l'impact : extension maximale du membre ou de l'arme ; après : récupération et retour à la pose de repos. La frame d'impact doit se lire seule (silhouette la plus étirée de l'anim).
- Rig : `art/tools/iso/iso_rig.py` `create_rig('CREA', (L, H))`, élévation 30°, `ortho_scale = L / 64`, `shift_y` pour poser les pieds sur `bottom` ; 8 directions en tournant le modèle (`rotation Z = radians(90 − 45 × index)`), jamais la caméra. Rendu 2× puis LANCZOS, Eevee 8-16 échantillons, `cel.install('creature', normals=False)` avant les rendus (`art/tools/cel/cel_style.py`), `_e` = AOV `CEL_Accent`.
- Sources : `art/blender/monsters/v2/<nom>.blend` (un fichier par monstre, matériaux et armature dedans), scripts `art/tools/monsters/v2/<lot>_build.py` (construction + animation + rendu + assemblage + `.tres`), planche de contrôle `art/tools/night/_mob_v2_<lot>_contact.png`.
- Budget : ≈ 8,7 Mpx de diffus + 2,2 Mpx de `_e` par biome ≈ 2,1 Mo mobile ; 5 biomes ≈ 10,5 Mo < 12 Mo (catégorie `monsters` de `game/tests/texture_budget.json`). Rendre à 90,51 px/u doublerait l'aire : refusé.

## 3. Règles de modélisation et d'animation (tous rôles)

- **Lecture du rôle par la silhouette, identique d'un biome à l'autre** : essaim = bas, large, horizontal, tête en avant, pattes ou segments nombreux, aucun bras ; tireur = haut, mince, vertical, un organe ou une arme longue qui s'avance au tir, capuche ou tête masquée à œil unique ; bondisseur = long, ramassé, arrière-train surdimensionné, queue, tête basse ; brute = massif, asymétrique (un bras ou une arme énorme d'un seul côté), petite tête enfoncée.
- **Polycount utile** : essaim ≤ 1 500 tris, tireur ≤ 3 000, bondisseur ≤ 3 500, brute ≤ 6 000 ; biseaux sur les arêtes vues ; pas de subdivision invisible. Pas de `rod` à rayon constant pour un membre : chaque membre a une épaisseur variable (cuisse > tibia > patte) et une articulation vraie (armature ou empties pivotés à l'articulation, 2-3 segments par membre).
- **Pièces qui débordent** (une ou deux par créature, lisibles à 64 px/u, ≥ 3 px de large après rendu) : tesson, branchies, lanterne, crochet, chaîne, colonne cassée… c'est ce qui distingue la créature de loin.
- **Valeurs** : une matière claire (os, sel, bronze clair, bois blanchi, chitine pâle ; luminance linéaire de base ≥ 0,25) sur ≥ 30 % de la silhouette, de préférence le dessus (vue de dessus 3/4) ; le reste en matières STYLE.md (rouille `#6B3A22`, fer noir `#2B2A29`, vert-de-gris `#5F8F80`, cuir, pierre). Contrôle obligatoire sur le sol du biome : le corps se détache par sa valeur, pas seulement par l'encre. Cryptes : chroma +20 % et L* ≥ 60 (Design_Etages §3).
- **Un accent émissif par biome** (STYLE.md), en petites touches : terrasses cyan d'eau `#5EC8FF`, forêt vert pâle `#9CF0C8`, cité orange `#FF9A3C`, cryptes cristal `#BFF4FF`, Source blanc froid `#DDF6FF`. Yeux toujours dans l'accent (le joueur repère la tête et la direction) ; un second point d'accent à l'impact du coup (gueule ouverte, lame, lanterne) pour que la frame d'impact « s'allume ».
- **Animation** : `run` = vrai cycle (contact, passage, pied planté ; 4 pattes : galop ou trot ; 6+ pattes : vagues déphasées), amplitude ≥ 25° aux hanches, ±3 % de hauteur de corps, mouvement secondaire décalé de 1-2 frames (queue, tissu, chaîne, branchies). `idle` = respiration + un tic (tête, mandibules). `attack` : anticipation nette (recul 2 frames, membre armé en arrière), impact étiré (smear toléré sur 1 frame), récupération. `death` : chute vers l'avant puis affaissement, 4 directions.
- **Sol et ombre** : pas d'ombre portée dans le PNG (ombre de contact commune `shadow_blob_256` du jeu), AO cuite dans le diffus (`iso_rig.bake_ao_shadows`).

## 4. Les 20 créatures

Une ligne par créature : silhouette, matières, accent, geste d'attaque. Noms affichés en français, dossiers en anglais (`fauna.json`).

### 4.1 Terrasses noyées (étage 1, lot pilote) — rizières, murets moussus, bassins, norias, bronze ; accent cyan `#5EC8FF`
- **Essaim `swarm_tier1` — Tesson de vase.** Larve de vase cuirassée d'un tesson de jarre de bronze vert-de-gris qu'elle porte comme un bernard-l'ermite ; 6 pattes courtes et pointues, abdomen mou vert-gris qui dépasse derrière ; le tesson (clair, cassé, un motif gravé) = la zone claire du dessus. Yeux : deux fentes cyan sous le bord du tesson. Attack : la tête jaillit de sous le tesson, mandibules ouvertes (impact), puis rentre.
- **Tireur `shooter_tier2` — Guetteur des rizières.** Épouvantail noyé : pieux de pin liés de corde pourrie, manteau de paille trempée, chapeau conique de bronze bosselé qui cache le visage ; un œil cyan dans l'ombre du chapeau ; sarbacane de bambou de 1,2 u. Attack : lève la sarbacane à l'horizontale (armement), souffle (impact : bouffée d'eau cyan au bout), redescend.
- **Bondisseur `leaper_tier2` — Salamandre des bassins.** Salamandre géante longue et basse, tête large et plate, branchies externes en éventail (claires, accent cyan aux pointes), queue aplatie, anneaux de bronze rouillé serrés sur la queue, peau vase `#4A5B5A` tachée. Charge : s'aplatit, branchies couchées ; leap : corps étiré, pattes en arrière ; attack : gueule ouverte en coup de tête latéral.
- **Brute `brute_tier3` — Manœuvre de vanne.** Golem de poutres de vanne gorgées d'eau et de plaques de bronze, mousse dans les joints, bras droit remplacé par une roue dentée de noria cassée (massue), bras gauche court ; tête = une petite lanterne de pierre éteinte enfoncée entre les épaules ; fissure cyan en travers du torse. Attack (cône) : la roue balaie de droite à gauche ; cast (onde de choc) : la roue frappe le sol à deux mains.

### 4.2 Forêt-brume (étage 2) — cèdres, racines, sanctuaires à lanternes, étangs noirs ; accent vert pâle `#9CF0C8`
- **Essaim `swarm_tier1_moss` — Cloporte des racines.** Cloporte géant à plaques de bois mort et de mousse (le dos clair, lichen gris-vert), 7 paires de pattes fines, antennes ; yeux : deux points verts. Attack : se cabre et referme ses plaques avant sur la cible (claquement).
- **Tireur `shooter_tier2_moss` — Archer d'écorce.** Silhouette creuse d'écorce de cèdre fendue, lichen pendu comme une capuche, lanterne de papier éteinte qui pend dans la cage thoracique (accent vert faible), arc de branche vivante aussi haut que lui. Attack : bande l'arc (armement), lâche une épine (impact), l'arc vibre.
- **Bondisseur `leaper_tier2_moss` — Martre des racines.** Mustélidé long et sinueux de bois noir et de mousse, mâchoire de ronces, dos clair de lichen, queue en racine effilochée ; yeux verts. Charge : dos rond ; leap : corps en arc ; attack : morsure en se retournant.
- **Brute `brute_tier3_moss` — Gardien de sanctuaire.** Statue de sanctuaire renversée qui marche : pierre grise claire couverte de racines, visage effacé, niche à lanterne dans la poitrine (accent vert), bras droit = racine arrachée avec sa motte (masse), chaîne votive qui pend. Attack : balayage de racine ; cast : plante la racine au sol.

### 4.3 Cité de rouille (étage 3) — canal industriel, cuves, passerelles, vapeur ; accent orange lampe `#FF9A3C`
- **Essaim `swarm_tier1_rust` — Larve-boulon.** Asticot gras à tête d'écrou rouillé, rivets le long du dos, ventre clair de suif ; filament orange dans l'écrou (yeux). Attack : l'écrou s'ouvre en quatre mâchoires.
- **Tireur `shooter_tier2_rust` — Riveteur.** Grand corps voûté sous une toile goudronnée, tête = cage de lampe à gaz (accent orange), riveteuse à vapeur tenue à deux mains reliée par un tuyau à une bonbonne dorsale claire (laiton `#A8946E`). Attack : épaule la riveteuse (armement), coup de vapeur et rivet (impact), recul.
- **Bondisseur `leaper_tier2_rust` — Chien-ressort.** Carcasse de chien en tôle et ressorts : colonne = ressort hélicoïdal, mâchoire = pince, pattes arrière = vérins, plaques claires d'acier zingué sur le dos ; œil-fournaise orange. Charge : ressort comprimé ; leap : ressort détendu ; attack : pince qui claque.
- **Brute `brute_tier3_rust` — Chauffeur de cuve.** Manœuvre colossal au torse-chaudière (grille orange au ventre), bras droit = crochet de grue sur chaîne, bras gauche = pelle à charbon, plaques de béton écaillé claires aux épaules, vapeur aux joints. Attack : le crochet balaie ; cast : le crochet s'abat au sol.

### 4.4 Cryptes noyées (étage 4) — ossuaires, sel, cristal, eau noire ; accent cristal `#BFF4FF` ; chroma +20 %, L* ≥ 60
- **Essaim `swarm_tier1_salt` — Main d'ossuaire.** Main squelettique géante qui court sur ses 5 doigts, croûte de sel blanche sur les phalanges, un cristal fiché dans le poignet (accent). Attack : les doigts se referment en griffe sur la cible.
- **Tireur `shooter_tier2_salt` — Pleureuse de sel.** Silhouette drapée d'un linceul raide de sel, capuche vide (un œil-cristal), encensoir de cristal au bout d'une chaîne. Attack : fait tourner l'encensoir (armement), le lance en avant (impact : éclat), le ramène.
- **Bondisseur `leaper_tier2_salt` — Lévrier de sel.** Squelette de lévrier aux os clairs, colonne hérissée de cristaux, mâchoire longue, pas de queue mais une chaîne de reliquaire. Charge : arrière-train bandé ; leap : étiré ; attack : morsure plongeante.
- **Brute `brute_tier3_salt` — Cariatide noyée.** Statue de colonne cassée à la taille qui porte son chapiteau comme un marteau de la main droite, pierre de sel claire, veines de cristal (accent) dans les fissures, algues noires. Attack : le chapiteau balaie ; cast : le chapiteau s'abat.

### 4.5 La Source (étage 5) — caverne, colonne de pluie, bronze noirci ruisselant ; accent blanc froid `#DDF6FF`
- **Essaim `swarm_tier1_source` — Goutte rampante.** Pointe de paratonnerre en bronze noirci qui marche sur 4 filaments de bronze, une bille d'eau blanche dans la tête (accent), ruissellement permanent. Attack : la pointe pique en avant.
- **Tireur `shooter_tier2_source` — Paratonnerre errant.** Tige de bronze humanoïde, cape d'eau qui coule (surfaces claires = reflets), tête = boule de paratonnerre fendue (accent). Attack : tend le bras, une goutte s'arrache (impact).
- **Bondisseur `leaper_tier2_source` — Fauve de pluie.** Félin lisse de bronze noirci, plaques claires de bronze poli sur le dos, eau qui ruisselle en filets, craquelures blanches aux pattes. Charge : accroupi ; leap : étiré ; attack : griffes.
- **Brute `brute_tier3_source` — Pylône errant.** Pylône de paratonnerre brisé devenu golem : jambes de bronze, bras-chaînes, cage de bronze clair au torse où bat une goutte blanche (accent). Attack : chaîne balayée ; cast : les deux chaînes au sol.

## 5. Gameplay : une vraie attaque pour chaque corps à corps

État du code (`game/scripts/enemies/enemy.gd`, `scripts/core/balance.gd`, 28/10/2026) :
- **Essaim (tier 1)** : dégâts **au contact** dans le chemin chaud (`tick`, l. 665-680) : `dist <= radius_px + PLAYER_RADIUS_PX` et `_attack_cd <= 0` → `_hit_player(damage)` immédiat, `_attack_cd = CONTACT_INTERVAL` (1,0 s), sur place 0,25 s (`SWARM_BITE_PAUSE_S`), recul 0,25 u. Aucun armement, aucune anim.
- **Bondisseur** : course télégraphiée (`LEAP_WINDUP` 0,8 s, ligne au sol) puis un coup au contact pendant la course (`_dash_step`, ×1,5) et récupération 0,5 s ; tir d'appoint à 3 u. Anim `charge` (bascule), pas de coup visible.
- **Brute** : cône (`CONE_WINDUP` 0,6 s, portée 1,9 u, demi-angle 0,70 rad, recharge 1,8 s) et onde de choc (1,0 s, 3 u, 12 s), télégraphes au sol, récupération 0,4 s. Anims `attack` / `cast` jouées mais ce sont des bascules ; leur vitesse n'est pas calée sur l'armement.
- **Tireur** : armement 0,7 s avec ligne de visée, anim `attack` 8 fr à 12 fps (0,67 s) où la flèche part visuellement à la frame 5 (0,42 s) : le projectile apparaît 0,28 s après le geste.

### 5.1 Essaim : du contact à la morsure (même DPS)
- Constantes `Balance` : `SWARM_BITE_WINDUP_S` **0,35**, `SWARM_BITE_REACH_U` **0,25** (allonge au-delà du contact : la tête jaillit), `SWARM_BITE_PAUSE_S` 0,25 (gardée : récupération), `CONTACT_INTERVAL` 1,0 s inchangé → **au plus une morsure par seconde par essaim, dégâts inchangés** (8 × (1 + 0,30 (D − 1)), plafond 25 % des PV max).
- Séquence, sans nouvel état (seuils sur `_attack_cd`, comme `BITE_PAUSE_GATE` aujourd'hui) : à `dist <= contact1 + REACH` et `_attack_cd <= 0` → `_attack_cd = CONTACT_INTERVAL`, `visual.set_action(&"attack", true)`, `visual.set_charge(1)`, immobile. Quand `_attack_cd` franchit `BITE_IMPACT_GATE = CONTACT_INTERVAL − SWARM_BITE_WINDUP_S` (0,65) : si `dist <= contact1 + REACH + 0,1 u` → `_hit_player(damage)` + recul 0,25 u, sinon **coup dans le vide** ; `set_charge(0)`. Immobile jusqu'à `BITE_PAUSE_GATE = BITE_IMPACT_GATE − SWARM_BITE_PAUSE_S` (0,40), puis `set_action(&"run")` et reprise. Coût : deux comparaisons de plus par tick de tier 1, deux `set_action` par morsure (seulement les essaims au contact).
- Lisibilité (250 monstres) : **aucun télégraphe au sol** pour l'essaim (250 dessins) ; l'anim (tête armée en arrière 2 frames, gueule allumée à l'impact) et la teinte `set_charge(1)` suffisent. 0,35 s est sous la règle des 0,8 s des sorts à zone, mais remplace un contact à 0 s : le joueur gagne de l'information. Un joueur à 4 u/s parcourt 1,4 u pendant l'armement : les morsures dans le vide deviennent la norme en mouvement, le DPS contre un joueur immobile ne change pas. Si l'essaim devient trop faible en test : `SWARM_BITE_REACH_U` 0,25 → 0,4 avant de toucher à l'armement.
- Hitstop / recul pendant l'armement : la morsure se résout quand même au seuil ; la distance décide (un essaim repoussé rate). Étourdissement (`_stun`) : comme aujourd'hui, gel du compteur.

### 5.2 Bondisseur : visuel seulement
- `Windup.LEAP` : `set_action(&"charge")` (6 fr non bouclées : accroupi progressif, dernière frame tenue jusqu'à la fin des 0,8 s). Résolution : `set_action(&"leap")` (boucle pendant `_dash_left`). Fin de course ou contact (`_dash_step`) : `set_action(&"attack", true)` (impact frame 3 ≈ 0,25 s après le coup réel : tolérable, le dégât est déjà appliqué au contact) ; `RECOVER` 0,5 s puis `run`. Dégâts, portée, recharge inchangés. Repli automatique si `leap_<dir>` manque (`_play_dir` → `run_<dir>`).

### 5.3 Brute et tireur : armement calé sur la frame d'impact
- Généraliser `EnemyVisual.attack_impact_time(action)` aux monstres non-boss : lit `<action>_s` dans les frames du tier, fraction 0,5 (`BOSS_IMPACT_FRAC`), retourne `floor(n/2) / fps`. Nouveau `EnemyVisual.set_action_timed(action, impact_in)` : joue `<action>_<dir>` depuis la frame 0 avec `speed_scale = natural / impact_in` jusqu'à la frame d'impact (signal `frame_changed`), puis `speed_scale = 1.0` (récupération à vitesse naturelle). Pas de fente de corps pour les mobs (la fente de `play_attack` reste aux boss).
- Brute : `wind = maxf(CONE_WINDUP, impact)` pour le cône, `maxf(SHOCK_WINDUP, impact)` pour l'onde (1,0 s ≥ 4/12 s : l'anim ralentit), `set_action_timed` à la place de `set_action(…, true)`. Dégâts, portées, recharges inchangés.
- Tireur : `set_action_timed(&"attack", SHOOTER_WINDUP_S)` : la flèche part à la frame 4 au moment exact du projectile (corrige le décalage de 0,28 s). Salve : idem avec `SHOOTER_SALVO_WINDUP_S`.

### 5.4 Repos et mort
- `idle_<dir>` : déjà demandé par `enemy.gd` l. 802 ; dès que l'anim existe, les tireurs à distance de garde et les brutes en récupération respirent au lieu de courir sur place. Rien à coder.
- `death` (4 dirs, 4-6 fr) : optionnel, après le pilote. `_die()` → si `Quality` le permet et `death_<dir4>` existe, un sprite de cadavre en pool (`AnimatedSprite2D` partageant les `SpriteFrames`, 0,33 s, plafond 40 simultanés, au-delà comportement actuel), l'ennemi est rendu au Director tout de suite comme aujourd'hui. Tant que ce code n'existe pas, les frames `death` sont livrées mais inutilisées.

### 5.5 Liste des changements de code (agent dev, après livraison du lot pilote)
1. `scripts/core/balance.gd` : `SWARM_BITE_WINDUP_S := 0.35`, `SWARM_BITE_REACH_U := 0.25` (+ commentaires) ; `SWARM_BITE_PAUSE_S` inchangé.
2. `scripts/enemies/enemy.gd` : `BITE_IMPACT_GATE`, `BITE_PAUSE_GATE` recalculés ; chemin chaud tier 1 (§5.1) ; bondisseur (§5.2) ; brute et tireur (§5.3) ; `_cancel_windup` remet `run`.
3. `scripts/enemies/enemy_visual.gd` : `SPRITES` v2 : `1: {"name": "swarm_tier1", "scale": 1.0, "offset_y": -20.0}` (= 56/2 − 48), `2: {… "scale": 1.0, "offset_y": -44.0}` (104/2 − 96), `LEAPER_KEY: {… "offset_y": -34.0}` (96/2 − 82), `3: {… "offset_y": -56.0}` (136/2 − 124) ; plus de clé `render_px_per_u` sur l'essaim (64 par défaut) ; vérifier les pieds sur la capture de `enemies_map_test` ; `attack_impact_time` et `set_action_timed` (§5.3). Les biomes héritent (`fauna.json` inchangé).
4. Tests : `tests/sprites_test.gd` (essaim : `run_w` 8 frames inchangé ; ajouter `attack_s` 6 frames, `idle_s` 4) ; nouveau `tests/swarm_bite_test` (armement 0,35 s, coup dans le vide si le joueur sort de l'allonge, 1 coup/s immobile, DPS = avant) ; `tests/ranged_behavior_test` (projectile à la frame d'impact) ; `enemies_perf` (budget inchangé).
5. `game/tests/texture_budget.json` : rien ; après les 5 biomes, décider du sort de `monsters/swarm_tier1_cel` et `brute_tier3_cel` (doublons du bouton F7 `RenderStyle`, 1,3 Mo mobile).

## 6. Lots Codex (consignes `art/tools/night/_mob_v2_<lot>.txt`, effort `medium`)

| Lot | Contenu | Après |
|---|---|---|
| `t1` | terrasses : essaim + tireur (pilote du format) | validation joueur sur `_mob_v2_t1_contact.png`, intégration code §5.5 |
| `t2` | terrasses : bondisseur + brute | idem |
| `f1`, `f2` | forêt : essaim + tireur / bondisseur + brute | |
| `c1`, `c2` | cité | |
| `s1`, `s2` | cryptes (`_salt`, nouveaux dossiers) | `biome_fauna_test` (prise en compte du biome 4) |
| `q1`, `q2` | Source (`_source`, nouveaux dossiers ; facultatif : le jeu retombe sur les terrasses) | |

Ordre : `t1`, `t2` (puis arrêt pour validation), `f1`, `f2`, `c1`, `c2`, `s1`, `s2`, `q1`, `q2`. Un lot = 2 monstres complets, un seul à la fois ; si le quota manque, arrêt après un monstre complet. Chaque lot vérifie : tailles de cellule, 8/4 lignes, frames non vides et non dupliquées, `_e` non noir, pieds sur `bottom`, `python art/tools/texture_budget.py` (0 ligne « > 4096 », catégorie `monsters` ≤ 12 Mo), `godot --headless --path game --import` puis `res://tests/sprites_test.tscn` et `res://tests/biome_fauna_test.tscn` → `RESULT: OK`, planche de contrôle sur le sol du biome à côté d'`ash_lord` (même échelle en jeu : mobs à 64 px/u, ash_lord cadre 170).
