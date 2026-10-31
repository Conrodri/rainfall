# Étage 2 : « Le Gouffre luisant » (biome grotte illuminée, remplace la Forêt-brume)

> Statut : **proposition de game design** suite à la demande du joueur du 31/10/2026 : les étages 1 (Terrasses noyées) et 2 (Forêt-brume) se ressemblent trop (eau, pierre, mousse, brume, accent froid dans les deux cas) ; l'étage 2 et ses variantes A/B deviennent un biome « grotte illuminée », aux jeux de couleurs profonds, très rocheux.
> Aucun code ni asset modifié par ce document. Cohérent avec `Design_Etages.md` (§2.3-2.4, §3, §5.2), `Design_Variantes_B.md` (§3, §9-12), `Design_Isometrique.md` (§1.5, §2.2, §4.2-4.3), `art/briefs/STYLE.md`, `STYLE_boss_da.md`, `STYLE_cel.md`. Brief Codex associé : `art/briefs/biome_grotte.md`.
> **Gel des boss (28/10/2026)** : aucune mécanique, aucun id de boss ou de mini-boss ne change ; seuls des rhabillages (nom affiché, matières, couleur d'accent) sont proposés, classés par priorité.
> **Ids techniques conservés** (sauvegardes, tests, `floors.json`) : `foret_brume`, `foret_mangrove_lanternes`, biome `foret`, dossiers `fog_forest`, ids audio `music.foret_brume.*`. Seuls les noms affichés et le contenu des fichiers changent.
> Le rendu du sol est en cours de refonte par un architecte (tous biomes) : ce document décrit **les besoins** du sol de la grotte (§4), pas le système.

---

## 0. Résumé

| | Avant (Forêt-brume) | Après (Gouffre luisant) |
|---|---|---|
| Thème | mangrove de cèdres, brume, lanternes, aube bleue | **gouffre karstique dans le grès ferrugineux** : doline effondrée, salles concrétionnées, rivière souterraine, mycélium luminescent dans les fissures |
| Palette dominante | vert-gris, bleu d'aube | **ocre, brun-rouge, ombre d'umbre** (roche chaude et profonde) |
| Accent émissif unique | vert pâle lanterne `#9CF0C8` | **mycélium améthyste `#C27BFF`** (cœur `#E6C8FF`) |
| Lumière | ciel diffus 5 h 10, canopée | **pas de soleil** : 3 puits de lumière (A), mycélium (A et B), joueur ; contre-jours |
| Eau | étangs noirs `#17262B` | rivière d'infiltration **vert-bouteille** `#14302C`, gours `#2A4A42` |
| Ambiance | pluie lourde, lucioles, brume 17 % | gouttes, poussière dans les rais, spores violettes, brume basse 8 %, échos ; pas de pluie |
| Variante A | `foret_brume`, moyeu et rayons | **« Le Gouffre »** : grande salle sous le puits central, galeries en rayons, même grille |
| Variante B | `foret_mangrove_lanternes`, méandre | **« Les Galeries noyées »** : rivière souterraine en méandre, sans puits de lumière, même grille |
| Boss / minis | Cerf-Lanterne, Tisseuse, Cèdre-Ermite ; 5 minis | identiques ; rhabillage (§6) |

Lecture de l'arc de la run : terrasses à ciel ouvert (1) → **le sol s'effondre, descente dans le gouffre sous les rizières** (2) → remontée par le canal dans la cité (3) → les cryptes sous la cité (4) → la Source (5). L'eau des rizières s'infiltre : c'est elle qui goutte dans le gouffre et ressort dans le canal de la cité.

---

## 1. Identité du biome

**Nom affiché** : « Le Gouffre luisant ». Variante A : « Le Gouffre » ; variante B : « Les Galeries noyées ».

**Thème géologique** : karst de grès ferrugineux (ocre, brun-rouge, lits sombres de schiste), pas de calcaire blanc. Un gouffre d'effondrement (doline) ouvert sur le ciel par trois puits ; des salles à concrétions (stalagmites trapues, coulées de calcite beige, gours en gradins) reliées par des galeries ; une rivière souterraine froide. Les racines mortes de la forêt de surface pendent des voûtes (seule survivance de l'ancienne forêt, et ce qui permet de rhabiller les arches de racines existantes). Rien de construit, rien de taillé : **toute ligne est naturelle**, c'est la différence de fond avec l'étage 4 (§3).

**Ce qui luit** : un mycélium bioluminescent colonise les fissures humides, les racines pendantes et les chapeaux de champignons en étagère. Il pulse lentement (0,12 Hz). C'est le seul accent émissif du biome, et la seule « vie végétale » qu'on garde de l'ancienne forêt. **Aucun cristal lumineux** : le cristal blanc-cyan appartient aux Cryptes (étage 4). Les minéraux de la grotte (géodes, quartz fumé) sont **éteints**, sombres, et servent de relief, pas de lumière.

**Ressenti visé** : « illumination » et non « obscurité ». Les Cryptes sont l'étage noir ; le Gouffre est l'étage **coloré** : roche chaude, ombres d'umbre, violet froid des fissures, rais de jour blanc-chaud qui tombent des puits avec la poussière. Le joueur-lanterne reste la seule chaleur mobile, mais il n'est plus la seule lumière.

---

## 2. Palette (hex)

| Usage | Ombre | Moyen | Lumière | Note |
|---|---|---|---|---|
| Roche (grès ferrugineux) | `#2E221C` | `#5A4232` | `#7A5D45` | base des murs, falaises, stalagmites, blocs |
| Lits sombres (schiste) | `#1E1C1E` | `#3A3634` | `#4E4A48` | strates dans les falaises, blocs `c` |
| Sol d'argile et d'éboulis | `#30261F` | `#4A3A30` | `#5C4A3A` | sol principal ; plus rouge que les murs pour que les blocs se détachent |
| Sol humide (argile grise) | `#26262A` | `#3B3A3C` | `#4A4A50` | près de l'eau et sous les puits ; flaques réfléchissantes |
| Calcite (coulées, gours) | `#5C5040` | `#8A7A62` | `#A89880` | beige chaud, **jamais blanc** (le blanc est aux Cryptes) |
| Eau profonde `~` | `#0C1F1C` | `#14302C` | `#1E4038` | rivière vert-bouteille, reflets violets des fissures |
| Eau peu profonde `,` | `#1E3A34` | `#2A4A42` | `#3A5A50` | gours, bords de rivière |
| Racines mortes | `#1A1410` | `#2A2420` | `#3C3428` | comme les anciennes racines (teinte conservée) |
| Champignons (chair) | `#4A3C44` | `#6A5A66` | `#8A7A86` | mauve désaturé, non émissif |
| **Accent émissif : mycélium** | — | `#C27BFF` | cœur `#E6C8FF` | `_e` uniquement ; lumière de jeu `#B98BFF` |
| Puits de lumière (lumière de scène, non émissive) | — | `#FFE9C4` | — | PointLight2D + rai ; pas un accent d'asset |

Règle : saturation gardée dans les matières (profil cel 3 tons, STYLE_cel §1), pas d'étalonnage qui désature (§3.2). Les monstres restent rendus +10 % de chroma comme pour la forêt (Direction_Lumiere §2.2), pour se détacher de la roche.

Abîme (`void_1024`) : brun-noir `#120E0C` avec une brume basse ocre `#3A2C24` à 20 % (le vide n'est plus bleu).

---

## 3. Différence nette avec l'étage 4 « Cryptes noyées »

| Axe | Étage 2 · Gouffre luisant | Étage 4 · Cryptes noyées |
|---|---|---|
| Nature | **roche naturelle** : karst, doline, concrétions, éboulis ; aucune ligne droite | **architecture** : catacombes, voûtes, colonnes, nefs, chapelles, ossuaires, dalles |
| Teinte | **chaude et profonde** : ocre, brun-rouge, umbre ; roche à L\* 30-45 | **froide et noire** : pierre humide `#2E3238`, sel, os `#8C8778` ; sol L\* 20-25 |
| Accent | mycélium **violet améthyste** `#C27BFF`, vivant, pulsation 0,12 Hz | cristal **blanc-cyan** `#BFF4FF`, minéral, pulsation 0,1 Hz |
| Lumière | 3 puits de jour blanc-chaud (A), mycélium partout, le joueur ; vignette 0,34 | aucune lumière du jour ; cristaux froids et le joueur ; vignette 0,38 (étage le plus sombre) |
| Eau | rivière **vert-bouteille** qui coule, gours en gradins | lac **noir** `#0E1419` immobile, crue |
| Matières organiques | champignons, racines mortes, lichen | **os**, sarcophages, croûtes de sel |
| Ciel | **ouvert** par les puits (poussière dans les rais, gouttes qui tombent de haut) | fermé ; voûtes qui gouttent |
| Son | rivière, vent de gouffre, échos secs, gouttes | silence, gouttes réverbérées, grondement de crue, cristal qui tinte |
| Jauge | Furieux : les puits se voilent (l'orage dehors) et le violet prend le dessus : **changement de couleur, jamais d'obscurité** | Furieux : les cristaux s'éteignent par vagues (**obscurité partielle**) |
| Télégraphes | teinte de biome **orange-rouge** `TELEGRAPH_BIOME_TINT.foret` → `Color(1.0, 0.48, 0.18)` (complémentaire du violet : lisibilité maximale) | pourpre `Color(0.72, 0.20, 0.80)` |
| Mots-clés de brief | « gouffre, grès, ocre, mycélium, violet, rai de jour, poussière » | « crypte, voûte, os, sel, cristal, eau noire » |

Ce qui est **interdit** dans la grotte pour préserver l'étage 4 : os et crânes, dalles et colonnes taillées, sel, cristal lumineux, eau noire, blanc-cyan. Ce qui est interdit dans les Cryptes en retour : mycélium violet, champignons, lumière du jour.

---

## 4. Sol : besoins (le système est défini par l'architecte)

Constat du joueur : le sol actuel fait « tuiles rectangulaires » (losanges 4 × 4 u à motif visible, joints lisibles, répétition). Besoins du sol de la grotte, sans présumer du mécanisme :

1. **Aucun motif de grille** : la roche d'un gouffre n'a ni dalles ni joints. Le sol doit se lire comme une surface continue d'argile, d'éboulis et de calcite, avec des cassures **obliques et irrégulières** (jamais alignées sur les axes du losange).
2. **Textures de base tuilables grand format** (ordre de grandeur : 8 u de période, 1024 px au rig TOP 128 px/u ; taille finale à fixer par le contrat de l'architecte), 1 base + 3 variations de même famille (éboulis fin, argile lisse, calcite), mélangées par zone et non tuile par tuile, pour casser toute répétition à l'écran (une vue = 27 × 15 u : la période de 8 u doit être masquée par le mélange et les décalques).
3. **Décalques** (rig TOP, fond transparent) posés par-dessus, dans le désordre : fissures à mycélium (avec `_e`), gours, éboulis, coulées de calcite, flaques d'argile humide, taches de spores. Ce sont eux qui portent l'identité du biome et l'accent émissif au sol ; la base reste neutre.
4. **Transitions organiques** sol → eau (`~`, `,`) et sol → falaise : bord irrégulier avec une bande humide plus sombre (0,5-1 u) ; pas d'arête de losange visible au bord de l'eau.
5. **Albédo** ≥ 0,12 en moyenne (STYLE.md « flaques de lumière ») ; sous les puits de lumière le sol peut monter à 0,18 (argile claire) pour que le rai se voie au sol.
6. **Lisibilité des télégraphes** : contraste local modéré (pas de taches très claires de plus de 1 u), pas de fissures émissives plus larges que 0,15 u au sol (elles ne doivent pas se confondre avec un liseré de zone). Les décalques émissifs sont de petites touches.
7. **Compatibilité provisoire** : tant que le nouveau système n'est pas branché, les 4 tuiles `ground_a..d.png` (512 × 256) du dossier `terrain/fog_forest/iso/` restent le repli et sont re-rendues dans la palette grotte avec les **mêmes noms** (aucun changement de code).

---

## 5. Éclairage, étalonnage et ambiance par variante

Profil `data/ambiance/foret_brume.tres` (A) et `foret_mangrove_lanternes.tres` (B), générés par `scripts/ambiance/tools/build_profiles.gd` (`_foret()` et le bloc forêt de `_variants_b()`). Valeurs ci-dessous = palier Calme ; le garde-fou de luminance ≥ 0,42 relatif de l'AmbianceManager reste actif.

### 5.1 Variante A « Le Gouffre » (`foret_brume`, grille actuelle de `foret_brume.json` : 64 × 56 u utiles, 76 × 68 u avec la marge de vide)

| Paramètre | Valeur | Commentaire |
|---|---|---|
| `mood` | « Gouffre karstique sous les rizières, midi dehors : trois puits de jour blanc-chaud tombent dans la grande salle, le reste est éclairé par le mycélium améthyste des fissures. » | |
| `ambient_color` / `ambient_low` | `#A89686` / `#B8A898` | chaud, lum ≈ 0,32 ; `ambient_low` au palier Bas sans directionnelle |
| Directionnelle | `sun_rotation_deg` 315, `sun_color` `#FFE2B8`, `sun_energy` 0,30, `sun_height` 0,95 | « jour qui descend des puits » : quasi zénithale, relief doux ; pas un soleil |
| Ombres | `sun_shadow_length_u` 0 ; Haut : 0,5 u sous les puits seulement (ombres cuites ailleurs) | contre-jours obtenus par les PointLight2D des puits |
| Puits de lumière | 3 PointLight2D `light_shaft` (nouveau préréglage : `#FFE9C4`, énergie 1,4, rayon 9 u, `height` 96, pulse 0,05 @ 0,05 Hz, texture `light_soft_256`) + rai `lightshaft_256x1024` (billboard additif, alpha 0,35, poussière `mote_16` `#FFE2B8` qui flotte dans le cône) | positions proposées : salle centrale (31 ; 27), lobe nord-est (57 ; 23), lobe sud (31 ; 53) = les 3 candidats de gros pilier : le boss se bat sous le jour |
| Mycélium | `light_rules` : `{"preset": "mycelium_glow", "char": "#", "edge": true, "spacing_u": 14, "max": 8}` ; préréglage nouveau `mycelium_glow` = `#B98BFF`, énergie 0,9, rayon 3,5 u, `height` 40, pulse 0,15 @ 0,12 Hz, flicker 0, texture `light_soft_256`, `reflect` true | même coût que `shrine_lantern` (8 lumières) ; remplace la règle lanternes |
| `map_lights_energy` | 1,0 (Hostile 1,2 ; Furieux 1,35) | |
| Étalonnage | `lift_color` `#1E1410` 0,25 ; `gain_color` `#FFD9B0` 0,12 ; `saturation` **1,02** ; `contrast` 1,10, pivot 0,42 ; `vignette_strength` 0,34, rayon 0,70, douceur 0,55, couleur `#140C08` | couleurs profondes gardées (forêt : 0,92 ; cryptes : 0,85) |
| Pluie | `rain_intensity` 0, `rain_layers` 0, `splash_rate` 0 | aucune pluie en grotte ; les gouttes tombent des puits |
| Gouttes | `drops_amount` 60 (texture `drop_32`, chute lente, éclaboussures `splash_8x64` sur l'argile humide et les gours) | cryptes : 30 ; forêt : 80 |
| Brume | `fog_low_color` `#8C7E78`, `fog_low_opacity` 0,08, vitesse 0,1 u/s ; `fog_high_opacity` 0 ; `puffs_count` 6, `puffs_color` `#9A8A84`, opacité 0,06 | basse et chaude, au ras des gours ; jamais plus de 10 % (lisibilité) |
| Calque multiply | `cloud_texture` `cave_ceiling_2048` (ombres de voûte et de stalactites, remplace `canopy_shadow_2048`), opacité 0,22, vitesse 0 (fixe : une voûte ne bouge pas), respiration 0 | donne les masses d'ombre sans ombres dynamiques |
| `sky_texture` | `&""` ; `sky_reflect` 0 ; `puddle_reflect` 0,45 ; `water_reflect` 0,7 ; `ripple_hz` 0,2 | reflets violets dans la rivière |
| Particules | `spores` : `mote_16`, `float`, `#C27BFF`, 0,06-0,10 u, alpha 0,55, additif, 2 nuées (remplace les lucioles) ; `poussière` : `mote_16`, `rise` lent 0,08 u/s, `#FFE2B8`, alpha 0,3, dans les cônes des puits ; `gouttes de voûte` : `drop_32`, `fall`, 2,5 u/s | `p1_amount` 36, `p2_amount` 30, `p3_amount` 40 |
| Vent | `wind_mult` 0,6 | |
| Son | `amb.foret_brume.decor` : rivière lointaine, gouttes sèches à écho court, vent de gouffre ; `amb.wind.foret_brume` : souffle grave par bouffées ; pas de nappe de pluie ; réverbération « salle » sur les pas et les sorts (bus déjà prévu pour les cryptes, réglage plus court : 0,9 s) ; musique `music.foret_brume.*` à resynthétiser (§8) | ids inchangés |

**Jauge de difficulté (A)** : Tendu : spores ×1,5 ; Hostile : `map_lights_energy` 1,2, gouttes 90 ; **Furieux : « Puits voilés »** (événement ambiant, remplace « Lucioles éteintes ») : l'orage de surface voile les puits (`light_shaft` énergie ×0,4 en 10 s, rai alpha 0,12, poussière éteinte), le mycélium monte (`map_lights_energy` 1,35, pulse 0,25) : la salle passe du blanc-chaud au violet, sans perte de luminance globale (ambiante +4 %) ; Cataclysme : grondement continu, chutes de gouttes 130, vent 1,2.

### 5.2 Variante B « Les Galeries noyées » (`foret_mangrove_lanternes`, grille actuelle : 72 × 48 u utiles)

Dérivée de A (`_variants_b()`), `hour_shift_min` sans objet (pas de soleil) : garder −30 pour la cohérence des données, sans effet.

| Delta par rapport à A | Valeur | Pourquoi |
|---|---|---|
| Puits de lumière | **aucun** (0 `light_shaft`) | plus profond : la B est l'étage « violet » |
| `ambient_color` | ×0,92 (`#9A8A7C`) ; garde-fou actif | compensé par les lumières |
| Directionnelle | `sun_energy` 0,22, `sun_color` `#E8D8C8` | jour résiduel qui filtre de loin |
| Mycélium | règle sur `"char": "~"`, `spacing_u` 12, `max` 8 inchangé | comme la Mangrove : lumières le long de la rivière, même coût |
| `map_lights_energy` | 1,2 | |
| `fog_low_opacity` | 0,10 (au ras de la rivière) | |
| Spores | 3 nuées ; poussière 0 | |
| Eau | `water_reflect` 0,8, `ripple_hz` 0,35 | la rivière coule plus vite (bruit de courant dans `amb.foret_brume.decor`, variante B : courant +6 dB) |
| Calque multiply | `cave_ceiling_2048` opacité 0,28 | voûte plus basse |
| Événement ambiant B | **« Vent de gouffre »** à Hostile (remplace « Marée montante ») : bouffées de vent froid dans les galeries (`wind_mult` 2,0, spores et brume qui filent en `wind_streak_128` horizontaux pendant 4 s toutes les 20-30 s, mycélium qui vacille : flicker 0,08 @ 2 Hz, souffle grave) ; aucun effet de jeu | distinct de la crue (étage 4) et de la marée (ancienne B) |

Topologie B inchangée : rivière souterraine en méandre (ex-chenal `~`), **4 franchissements** = 2 îlots de calcite (ex-îlots-gués, cases `,`) et 2 gués de galets (ex-pontons, cases `,`), lobe nord (ex-sanctuaire scellé = « diaclase scellée », §7), cèdre central de l'arène sud → **colonne stalagmite-stalactite** (`cedar_giant` rhabillé, même emprise, `fade` true).

---

## 6. Roster de l'étage 2 : rhabillage (gel des boss : mécaniques et ids inchangés)

Priorité : **P1** = à faire avant de montrer le biome (c'est vu à chaque étage 2) ; **P2** = après les lots terrain/props ; **P3** = peut rester tel quel en v1. « Nom » = nom affiché (`floors.json` `boss_names`, `bosses.json`, `minibosses.json`) ; l'id ne change jamais.

| Rôle | Id | Nom actuel → proposé | Rhabillage | Priorité | Tel quel en v1 ? |
|---|---|---|---|---|---|
| Boss | `cerf` | Le Cerf-Lanterne (inchangé) | pelage poudré d'ocre, bois **chargés de mycélium** : lanternes des bois → amas luminescents violets (`_e` recoloré `#C27BFF`, forme des bois inchangée) ; follets (`wisp_bolt`, `ground_wisp_trail`, `ground_mist`) en violet ; sabots noirs de schiste | **P1** (son accent menthe serait un 2e accent dans un biome violet) | non : au minimum recolorer les `_e` et les VFX de follets |
| Boss | `weaver` | La Tisseuse (inchangé) | araignée de gouffre : pattes de grès, abdomen = **chapeau de champignon fêlé** luisant ; fils gris-beige ; cocons = boules de mycélium | P2 | oui (une araignée se lit en grotte ; recolorer `_e` seulement si livré) |
| Boss | `hermit_cedar` | Le Cèdre-Ermite → **« L'Ermite des racines »** | tronc **pétrifié** couleur grès, racines pendantes de la voûte en guise de ramure, la lanterne du tronc → poche de mycélium ; souches de la charge = blocs de roche ; spores = spores de champignon (déjà le cas) | **P1 pour le nom** (texte), P2 pour le sprite | nom : non ; sprite : oui (placeholder `weaver_fx.gd` de toute façon) |
| Mini | `bramble_queen` | Reine des ronces → **« Reine du mycélium »** | ronces → filaments de mycélium et lichen, couronne de chapeaux violets ; zones de poison = tapis de spores | P2 | oui (matière sombre, se lit) |
| Mini | `brood_mother` | Essaim-mère (inchangé) | carapace de grès, essaim = coléoptères de grotte, ventre luisant violet | P3 | oui |
| Mini | `mist_wolf` | Loup de brume → **« Loup des gouffres »** | pelage gris-ocre poudreux, yeux violets ; la « brume » du B devient un nuage de poussière (VFX recoloré ocre) ; louveteaux `mist_wolf_cub` idem | P1 pour le nom, P2 sprite | nom : non ; sprite : oui |
| Mini | `lantern_owl` | Chouette-lanterne (inchangé) | chouette de doline, yeux-lanternes violets ; son passif « nocturne : −30 % hors des flaques de lumière » devient **le** mini-boss du biome (puits de jour et mycélium = flaques de lumière) | P2 (`_e` recoloré) | oui |
| Mini | `moss_mantis` | Mante de mousse → **« Mante de lichen »** | camouflage de lichen ocre et gris sur grès, lames de schiste | P1 nom, P2 sprite | nom : non ; sprite : oui |
| Foule | `swarm_tier1_moss`, `shooter_tier2_moss`, `leaper_tier2_moss`, `brute_tier3_moss` | — | matière « mousse » → **roche, lichen et poussière d'ocre**, petit accent violet (yeux) ; mêmes planches, mêmes noms de dossiers | P2 (lot creature, scripts existants) | oui : la mousse sombre passe en grotte humide |
| Gardiens | brute tier 3 rhabillée | A : *Mousse* et *Fougère* → **« Lichen » et « Silex »** ; B : *Lierre* et *Houx* → **« Ocre » et « Basalte »** ; groupe « Les Veilleurs » → **« Les Dormeurs du gouffre »** | affixes `foret` inchangés (`poison`, `burn`) | P1 (texte : `tools/gen_maps.py` `A_SECRETS.names`, `secrets[0].guardians` du JSON B) | non (texte) |

Ce qui ne bouge pas : `cerf_brain.gd`, `weaver_brain.gd`, `hermit_cedar_brain.gd`, `miniboss_patterns`, `minibosses.json` (hors nom affiché), PV, coefs, télégraphes, `enemy_visual.gd` `BOSS_SPRITES`.

---

## 7. Secrets : version grotte des props (déclencheurs `plates` / `lever` / `wall` / `pillar`, Design_Variantes_B §12)

Secrets existants conservés : A `cercle_brume` (porte (5, 4), plaques (36, 19) et (1, 11)) ; B « sanctuaire des racines » (porte (13, 4)). Seul l'habillage change.

| Élément | Avant (forêt) | Grotte | Fichiers |
|---|---|---|---|
| Salle secrète | sanctuaire de racines | **diaclase scellée** : fente de roche fermée par une coulée de calcite | `:` (sol scellé, rendu mur tant que fermé) : aucun asset |
| Porte `D` | rideau de racines | **coulée de calcite fissurée** qui s'effondre (ouverture) ; glyphe = veine de mycélium qui s'allume d'un cran par plaque | rendue par le code (mur) ; asset S-A optionnel |
| Plaques (`plates`) | pierres plates à rune vert pâle | **dalles de calcite veinées de mycélium** : la veine s'allume violet quand enfoncée | placeholder `_draw` (`secret_plate.gd`) : pas d'asset chargé aujourd'hui ; spec prête dans le brief (lot G6, « si le code les charge un jour ») |
| Levier (`lever`) | levier de bois | **stalagmite-levier** : concrétion fendue qu'on bascule, veine violette `_e` à l'état `on` | `props/secret/lever_fog_forest_{off,on}.png` 128² (+ `_e` 64², `_shadow` 128²) : **mêmes noms**, re-rendu |
| Mur fissuré (`wall`) | mur de racines | **paroi de grès lézardée** : fissures à mycélium qui s'élargissent (0 → 1 → 2), éclatement en 5 images | `props/secret/wall_fog_forest_{0,1,2}.png` 256² (+ `_e` 128² pour 1 et 2), `wall_fog_forest_break.png` 1280 × 256 (+ `_e` 640 × 128) : **mêmes noms** |
| Pilier éteint (`pillar`) | sprite du petit pilier | inchangé (`props/pillar_small_off.png`, partagé) | aucun |
| Reliquaires | grand coffre teinté turquoise, lumière `chest_guardian` | inchangé | aucun |
| Sons | `chest.lock`, `ui.spell_ready`, `chest.open.large` | inchangés | aucun |

---

## 8. Changements de code et de données (ids techniques conservés)

Fichiers partagés (`balance.gd`, `floors.json`) : orchestrateur. Le reste : agent Sonnet « étage 2 ».

| Fichier | Changement | Propriétaire |
|---|---|---|
| `tools/gen_maps.py` | `MAPS` : `name` « Forêt-brume » → « Le Gouffre », « Mangrove des lanternes » → « Les Galeries noyées » ; `ambient=` (« Puits voilés », « Vent de gouffre ») ; `event_names=` (autel_fortune « autel de mycélium » / « autel sous le rai », sanctuaire_risque « cercle de champignons luisants », marchand_ombre « silhouette dans une diaclase » / « barque sur la rivière souterraine », coffre_piege « coffre pris dans la calcite ») ; `A_SECRETS["foret_brume"]` : `skin` « dalles de calcite à mycélium + coulée fissurée (habillage Gouffre) », `names=["Lichen", "Silex"]` ; régénérer les 2 JSON | Sonnet |
| `data/maps/foret_brume.json`, `foret_mangrove_lanternes.json` | régénérés (ci-dessus) ; B : `secrets[0].guardians` → « Ocre », « Basalte » ; `hour_shift_min` gardé | Sonnet (via gen_maps) |
| `data/floors.json` | étage 2 : `"name": "Le Gouffre luisant"` ; `boss_names.hermit_cedar` → « L'Ermite des racines » ; ids, `maps`, `ambiance`, `music` inchangés | orchestrateur |
| `data/fauna.json` | `biomes.foret.name` → « Le Gouffre luisant » | Sonnet |
| `data/minibosses.json` | noms affichés : `bramble_queen` « Reine du mycélium », `mist_wolf` « Loup des gouffres », `moss_mantis` « Mante de lichen » | Sonnet |
| `scripts/ambiance/tools/build_profiles.gd` | `_foret()` et bloc forêt de `_variants_b()` : valeurs du §5 ; puis `godot --headless --path game --script res://scripts/ambiance/tools/build_profiles.gd` (**attention** : regénère aussi terrasses et cité ; vérifier d'abord qu'aucune retouche manuelle des `.tres` A n'est perdue, sinon n'éditer que les 2 `.tres` de l'étage 2 dans l'inspecteur) | Sonnet |
| `data/ambiance/light_presets.json` | + `mycelium_glow`, + `light_shaft` (§5.1) ; `shrine_lantern` conservé (événement autel, autres cartes) | Sonnet |
| `scripts/ambiance/ambiance_manager.gd` | **besoin de code** : (1) poser 3 lumières `light_shaft` à des positions fixes de la carte (clé `fixed_lights` du profil ou Marker2D `ambiance_light` dans la scène, méta `light_preset`, déjà lue ligne 391) ; (2) rai `lightshaft_256x1024` billboard sous chaque `light_shaft` ; (3) événement ambiant « Puits voilés » (fondu d'énergie des `light_shaft` à Furieux) et « Vent de gouffre » (rafales à Hostile) : `ambient_event` n'est lu par aucun script aujourd'hui (Design_Variantes_B §7) | Opus / Sonnet |
| `scripts/core/balance.gd` | `TELEGRAPH_BIOME_TINT[&"foret"]` → `Color(1.0, 0.48, 0.18)` | orchestrateur |
| `data/audio/sounds.json` | `maps.foret_brume` et `maps.foret_mangrove_lanternes` : ids inchangés ; `surfaces` : `"." : "stone"` si la surface existe dans `art/tools/audio/footsteps_manifest.json`, sinon `dirt` ; `"," : "water"` ; supprimer les couches `amb.rain.*` de ces 2 cartes (pas de pluie) | Sonnet |
| `art/tools/audio/music_manifest.json`, `ambience_manifest.json` | mêmes chemins et ids, nouveaux prompts (§5.1 son) : lot Codex audio | Codex |
| `scripts/stage/stage_map.gd` | rien (`ISO_TILES.foret`, `BIOME_PROPS.foret`, `ISO_GROUND_OVERLAP.foret` pointent sur les mêmes dossiers) ; le sol passe par le nouveau système de l'architecte | — |
| `scripts/stage/secret_room.gd` | rien (`AFFIXES.foret` gardé) | — |
| Commentaires d'en-tête | `cerf_brain.gd`, `weaver_brain.gd`, `hermit_cedar_brain.gd`, `weaver_fx.gd`, `weaver_snare.gd`, `floor2_boss_test.gd` : « Forêt-brume » → « Gouffre luisant » (cosmétique, à l'occasion) | Sonnet |
| Tests | `foret_iso_test`, `maps_test`, `biome_fauna_test`, `ambiance_test`, `secrets_test`, `floor2_boss_test`, `texture_budget_test`, `sprites_test` : ids inchangés → doivent rester `RESULT: OK` ; ajouter dans `ambiance_test` : profil `foret_brume` sans pluie (`rain_intensity` 0) et 2 préréglages nouveaux présents | Sonnet |
| `menu_background.gd` | rien (`DAILY_MAPS` par id) | — |

Noms de dossiers (`terrain/fog_forest/`, `props/fog_forest/`, `lever_fog_forest_*`, `wall_fog_forest_*`, `*_moss`) : **conservés** (sinon `stage_map.gd`, `secret_lever.gd`, `secret_wall.gd`, `fauna.json`, les `.tres` et plusieurs tests changent). Une ligne dans `art/briefs/biome_grotte.md` rappelle que `fog_forest` = biome `foret` = Gouffre luisant.

---

## 9. Ordre de production conseillé

1. Texte et données (§8 : noms, gen_maps, floors, fauna, minibosses) + profils d'ambiance + préréglages + teinte des télégraphes : **jouable en une passe**, avec les anciens sprites.
2. Lots Codex G1 (sol de repli + décalques), G2a/G2b (murs, falaises, eau), G3a/G3b (props A), G6 (secrets), G7 (textures d'ambiance) : voir `art/briefs/biome_grotte.md`.
3. Code AmbianceManager (puits de lumière, événements ambiants).
4. G4 (props B), G5 (concrétions), G8 (foule `_moss`), G9 (Cerf-Lanterne `_e` et follets), G10 (minis P2), G11 (audio).

---

## 10. Questions pour le joueur (avec recommandation par défaut)

1. **Nom du biome** : « Le Gouffre luisant » (reco) ; alternatives : « La Grotte des mycéliums », « Les Gouffres d'ocre ».
2. **Accent émissif** : mycélium violet améthyste (reco : seul accent qui ne se confond ni avec le cyan des étages 1/4, ni avec l'orange de l'étage 3, ni avec le rouge des télégraphes) ; alternative chaude : champignons ambre `#FFB36B` (plus proche de la cité).
3. **Puits de lumière seulement en A** (reco : c'est ce qui distingue A « jour qui tombe » de B « violet profond ») ou dans les deux variantes.
4. **Renommer le Cèdre-Ermite** en « L'Ermite des racines » (reco : oui, texte seul) ou garder le nom malgré la grotte.
5. **Props propres à B** (`hanging_roots`, `calcite_cascade`, `mushroom_shelf`) : en attendant les props par carte (besoin de code, Design_Variantes_B §7), les ajouter à `props.json` du biome à faible poids pour A et B (reco), ou attendre le code.
6. **Dossiers `fog_forest` / `_moss`** : garder les noms techniques (reco) ou renommer (coûte du code et des tests, aucun gain joueur).
