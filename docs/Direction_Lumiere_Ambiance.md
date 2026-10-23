# Rainfall : direction lumière, ambiance et VFX (v1)

> Document de direction artistique « lumière ». Exploitable par le développeur Godot (éclairage 2D, renderer Mobile, Godot 4.7) et par les pilotes d'assets Blender.
> Cohérent avec `CLAUDE.md` (règles « Ambiance lumineuse très marquée » et « Normal maps »), `Design_Boss_Cartes.md` (§1 palette, §3 boss, §4 cartes), `GDD.md` §2 (jauge de difficulté) et §8 (game feel), `Maths_Scaling.md` §2.
> Unité : **1 u = 64 px**. Écran portrait 1080×1920 = 16,9 u × 30 u ; en paysage PC (16:9 à 1080p) ≈ 30 u × 16,9 u, même aire. Les rayons de lumière sont donnés en u.
> Conventions Godot : `CanvasModulate` = lumière ambiante multiplicative ; `DirectionalLight2D` = soleil/ciel ; `PointLight2D` = sources ponctuelles ; `LightOccluder2D` = ombres ; glow = `WorldEnvironment` avec `rendering/viewport/hdr_2d = true`. Les couleurs sont données en hexadécimal sRGB **et** en RGB linéaire 0-1 quand elles vont dans une propriété `Color` d'une lumière (Godot convertit lui-même les `Color` saisies en sRGB dans l'inspecteur ; en code, utiliser `Color.html("#…")`).
> **Toutes les textures** citées (gradients de lumière, gouttes, brumes, nuages, rayons, halos, étincelles) sont rendues dans Blender (§6). Le code Godot ne fait que les animer.

---

## 0. Résumé en 12 règles

1. **Le joueur est la seule source chaude saturée** de l'écran : braise `#FF9A3C`. Le décor peut être tiède (soleil bas, lampes à vapeur) mais toujours **moins saturé** (chroma ≤ 60 % de celui du joueur) et **moins intense** (énergie ≤ 0,6 contre 1,1).
2. **La lumière est une information** : chaque source ponctuelle du gameplay a une couleur réservée (pilier blanc-bleu, coffre selon rareté, élite selon affixe, boss selon fiche) ; le décor n'emprunte jamais ces couleurs à pleine saturation.
3. **Les télégraphes ne sont jamais éclairés** : ils vivent sur un `CanvasLayer` séparé (sans `CanvasModulate`, shader `unshaded`) et gardent leur palette §0 de `Design_Boss_Cartes.md` quel que soit l'orage.
4. **Hiérarchie des valeurs** (L\* CIE, mesurée **après** éclairage et étalonnage) : sol 25-45 ; eau profonde 15-22 ; monstres ≥ 60 ; joueur 80-90 ; télégraphes et halos de sorts 70-95 ; UI 95. L'ambiance la plus sombre (Cataclysme) ne descend jamais le sol sous L\* 22 ni les monstres sous L\* 55.
5. **La pluie habille, elle ne cache jamais** : calque de pluie ≤ 12 % d'opacité (Calme 4 %, Cataclysme 12 %), toujours **sous l'UI et sous les télégraphes**, jamais flouté.
6. **La brume est au sol** : calques de brume dessinés **sous les entités** (z-index inférieur aux monstres), jamais par-dessus les monstres ni les télégraphes, densité plein écran ≤ 15 %.
7. **Un seul éclairage directionnel** par carte, cohérent avec les sprites rendus en haut-gauche (`CLAUDE.md`) : direction entre 300° et 330° (sens Godot, 0° = droite, horaire), jamais inversée.
8. **Les ombres sont courtes** (≤ 2,5 u) et **colorées** (jamais noires) : vue de dessus, une ombre longue cache les monstres.
9. **Budget mobile** : au plus 16 lumières **visibles** à la fois en Moyen (8 en Bas, 32 en Haut), toutes en `PointLight2D` partageant **3 textures** de gradient ; les lumières des 250 monstres n'existent pas (émission dans le sprite via `_e.png`).
10. **Les flashs** (éclairs) durent 80 ms, ne dépassent jamais 3 par 10 s, sont espacés d'au moins 4 s, et sont réduits à 25 % par l'option « secousses et flashs » du menu de pause.
11. **Tout paramètre d'ambiance est une fonction continue de D** (coefficient de difficulté) interpolée linéairement entre paliers, jamais un saut brutal (sauf les éclairs, par définition).
12. **Trois paliers de qualité** (Bas/Moyen/Haut) choisis automatiquement au premier lancement (mesure de 5 s de frame time) et modifiables dans les réglages ; une scène d'ambiance ne lit ses paramètres que via `AmbienceConfig` (à créer, voir §7).

---

## 1. Principes

### 1.1 Lisible avec 250 monstres sur mobile

Le problème : une ambiance « très marquée » (ambiante sombre, lumières colorées, brume, pluie) écrase naturellement le contraste sol/monstres, alors que la lisibilité est le pilier n°2 du jeu. La solution est une **hiérarchie des valeurs** fixée une fois pour toutes, et des **couches non éclairées** pour tout ce qui porte de l'information.

**Hiérarchie des valeurs, du plus sombre au plus clair (L\*, après tout traitement) :**

| Couche | L\* cible | Chroma (saturation) | Qui l'éclaire |
|---|---|---|---|
| Eau profonde | 15-22 | faible | ambiante + reflets |
| Ombres portées | sol − 8 à − 12 | teintée (jamais neutre) | `shadow_color` des lumières |
| Sol | 25-45 (carte 2 : 25-40 ; carte 1 : 30-45) | faible (chroma ≤ 15) | ambiante + directionnelle + normal map |
| Brume basse | 45-60, alpha ≤ 15 % | très faible | non éclairée (additive douce ou mix) |
| Obstacles | 35-50, liseré haut-gauche 70 | faible | ambiante + directionnelle + ombre portée |
| Monstres | **≥ 60**, contour 2 px L\* ≤ 20 | moyenne à forte, teintes froides/acides | ambiante + directionnelle ; **jamais assombris sous 55** |
| Élites | 65 + aura | forte (couleur d'affixe) | aura propre (PointLight2D ou halo additif) |
| Projectiles ennemis | 60-70 | moyenne | émission `_e.png`, pas de lumière |
| Joueur | 80-90 | forte, chaude | lumière propre |
| Sorts et projectiles du joueur | 75-95 + glow | forte, chaude | lumière propre + glow |
| Télégraphes | palette §0 Design, non éclairés | forte | **aucun** (couche séparée) |
| Pickups | 70-90 | forte (or, cyan, violet) | émission + scintillement, pas de lumière |
| UI | 95, fond 10 à 70 % | — | aucun |

**Garde-fou automatique** : le `CanvasModulate` et l'assombrissement d'orage sont bornés pour que la **luminance relative du `CanvasModulate` reste ≥ 0,42** (calculée en linéaire : 0,2126 R + 0,7152 G + 0,0722 B). En dessous, les monstres les plus sombres de la palette (violet L\* 60) tombent sous L\* 55. Les valeurs de §2 et §3 respectent cette borne ; `AmbienceConfig` doit la **clamper** en code.

**Pourquoi « le joueur seule source chaude »** : avec 250 silhouettes froides/acides, l'œil cherche la chaleur. Le joueur, ses sorts et ses projectiles sont les seuls objets **orange/jaune saturés et lumineux** (chroma ≥ 80, L\* ≥ 80). Les éléments tièdes du décor (soleil rasant de la carte 1, lampes de la carte 3, bronze) restent à chroma ≤ 50 et L\* ≤ 70, ou sont très petits (lampes 0,4 u). Les coffres légendaires (or) sont l'exception volontaire : ils doivent attirer, mais ils ne bougent pas et pulsent lentement (0,5 Hz) alors que le joueur pulse vite (1,1 Hz).

**Les télégraphes ne sont jamais noyés** :
- `CanvasLayer` « telegraphs » (layer 5, `follow_viewport_enabled = true`, aucun `CanvasModulate`), entre les entités et l'UI ; les lumières ne l'atteignent pas (`light_mask = 0`), le shader des télégraphes est `render_mode unshaded, blend_mix`.
- Le calque de pluie, la brume haute et la vignette sont **en dessous** de ce layer. Seul le flash d'éclair (80 ms) passe par-dessus, à 60 % d'alpha max, et il ne touche pas la couleur rouge du télégraphe (le flash est additif blanc : le rouge `#E53935` devient rose clair, encore lisible).
- Test de recette : à Cataclysme, sur la carte 3 (la plus sombre), un cercle rouge de 2 u sur le sol doit garder un contraste ≥ 4,5:1 avec le sol éclairé (mesure WCAG sur capture).

### 1.2 La pluie comme fil conducteur

La pluie est le **système** qui relie les trois cartes et la jauge de difficulté. Elle n'est jamais décorative seule : elle a une direction (vent), un rythme (densité), une conséquence au sol (éclaboussures, flaques, reflets), une conséquence sur la lumière (halos élargis, lampes qui grésillent, foudre), et elle **monte avec D**.

Déclinaison par carte, du plus doux au plus violent :
- **Carte 1, Terrasses noyées** : bruine fine, le soleil passe sous les nuages ; la pluie est **rétro-éclairée** (gouttes claires, chaudes) : c'est la carte « espoir ».
- **Carte 2, Forêt-brume** : pluie lourde filtrée par la canopée, gouttes **grosses et lentes**, brume ; c'est la carte « silence ».
- **Carte 3, Cité de rouille** : rideaux de pluie poussés par le vent, **éclairs** ; c'est la carte « colère ».

Le rythme de la pluie suit l'audio : la nappe de pluie s'étoffe avec D (`GDD` §8) et les **éclaboussures au sol** sont synchronisées avec la densité visuelle (même paramètre `rain_intensity` 0-1 partagé entre `AmbienceConfig` et le mixeur audio).

### 1.3 Chaîne de rendu (ordre des couches, de bas en haut)

| z / Layer | Contenu | Éclairé ? | Note |
|---|---|---|---|
| World, z = −20 | Sol (TileMapLayer, normal maps) | oui | `light_mask = 1` |
| World, z = −18 | Flaques et eau (shader de reflet) | oui | `light_mask = 1 | 2` (2 = lumières « reflétées ») |
| World, z = −16 | Ombres de nuages (texture défilante, multiply) | non | Moyen et Haut |
| World, z = −14 | Brume basse (2 calques) | non | sous les entités |
| World, z = −10 | Décors au sol, traces de boss (mares, flaques de braise) | oui | |
| World, z = 0 | Entités triées par Y (monstres, joueur, coffres, piliers, boss) | oui | `y_sort_enabled` |
| World, z = 10 | Projectiles, sorts, impacts | émission | |
| World, z = 20 | Brume haute (1 calque, Haut seulement) | non | alpha ≤ 6 %, jamais sur la zone 6 u autour du joueur (masque radial) |
| World, z = 30 | Pluie (shader plein écran) + éclaboussures (particules) | non | ≤ 12 % |
| World, z = 32 | Rayons de lumière (sprites additifs) | non | Moyen et Haut |
| Layer 4 | Étalonnage (ColorRect plein écran, shader `hint_screen_texture`) + vignette | — | hors Bas (vignette seule en Bas) |
| Layer 5 | Télégraphes, zones de combat, chiffres de dégâts | **non** | |
| Layer 6 | Flash d'éclair (ColorRect additif) | — | 80 ms |
| Layer 10 | HUD | non | |

`CanvasModulate` est placé dans World uniquement. Les `PointLight2D` sont dans World avec `range_z_min = −20`, `range_z_max = 10` (elles n'éclairent ni la pluie, ni la brume haute, ni les layers).

---

## 2. Les trois cartes

Format pour chaque carte : récit, ambiante, directionnelle, étalonnage, sources du décor, brumes, particules, rayons, flaques. Les valeurs sont celles du palier **Calme** (D < 1,5) ; §3 donne leur évolution.

### 2.1 Carte 1 : Terrasses noyées : **fin d'après-midi, soleil sous les nuages après l'averse**

**Récit lumineux** : la pluie vient de se calmer, le soleil passe sous le plafond nuageux à 12° au-dessus de l'horizon, côté haut-gauche. Tout ce qui est mouillé prend un liseré doré ; les ombres restent gris-vert, froides, et le ciel reflété dans les bassins est pêche-gris. C'est la carte d'apprentissage : la plus **claire** des trois, lumière rasante mais douce. La bruine, rétro-éclairée, scintille. Quand D monte, les nuages reviennent et le soleil se noie : la carte retourne au gris-vert du design d'origine.

**Lumière ambiante (`CanvasModulate`)** : `#C9C1B0` (linéaire 0,58 / 0,53 / 0,43 ; luminance 0,53). Tiède mais désaturée (chroma 12).

**Lumière directionnelle (`DirectionalLight2D`)** :
- `rotation` : 310° (vient du haut-gauche, légèrement plus horizontale que les 315° standard, pour des ombres un peu allongées vers le bas-droite).
- `color` : `#FFD9A8` (pêche désaturé), `energy` : 0,55.
- `height` : 0,25 (rasant : fait ressortir les normal maps des murets et de la mousse).
- Ombres : activées en Moyen/Haut ; `shadow_color` `#2E3B3A` alpha 0,55 (vert-gris, jamais noir) ; longueur cible 2,0 u pour un obstacle de 1 u de haut (`max_distance` réglé pour 128 px d'ombre au-delà de l'occluder, soit `shadow_filter = PCF5`, `shadow_filter_smooth = 2.0`).
- Les sprites étant déjà éclairés en haut-gauche dans Blender, la directionnelle ne sert qu'au **relief** (normal maps) et aux ombres portées : énergie faible.

**Étalonnage (shader plein écran, Layer 4)** :
| Paramètre | Valeur |
|---|---|
| Teinte des ombres (lift) | `#2F3D3B` à 18 % (vert-gris) |
| Teinte des hautes lumières (gain) | `#FFE3B5` à 22 % (or pâle) |
| Saturation globale | 1,05 |
| Contraste | 1,08 (pivot 0,45) |
| Vignette | intensité 0,22, rayon 0,78, douceur 0,45, couleur `#1E2A2C` |
| Aberration/grain | aucun (lisibilité) |

**Sources ponctuelles du décor** (toutes `PointLight2D` partageant la texture `light_soft_256`) :
| Source | Couleur | Rayon | Énergie | Scintillement | Occurrence |
|---|---|---|---|---|---|
| Lanterne de pierre (éteinte à Calme) | — | — | 0 | — | prop ; s'allume à Hostile (§3) en `#A8C8B8` rayon 2,5 u énergie 0,35, scintillement ±10 % à 3 Hz bruité |
| Reflet du soleil sur l'eau (« sun glint ») | `#FFE3B5` | 3 u | 0,30 | ondulation 0,4 Hz ±15 % | 1 par bassin visible, max 4 |
| Bronze des piliers éteints | — | — | 0 | — | relief seulement (normal map, `height` 0,25) |
| Barque du marchand (lanterne) | `#FFC27A` | 2 u | 0,40 | ±12 % à 4 Hz | 1 si l'événement est actif |

Total décor visible à la fois : ≤ 5 lumières (hors gameplay).

**Couches de brume** (textures `fog_tile_1024` A/B, raccordables, `blend_mix`, z = −14) :
| Calque | Hauteur (bande à l'écran) | Densité (alpha) | Vitesse | Couleur |
|---|---|---|---|---|
| Brume basse 1 (vapeur des bassins) | masque radial autour des cases `~` et `,`, rayon 4 u | 8 % | 0,25 u/s vers bas-droite (sous le vent) | `#C8D4CC` |
| Brume basse 2 (plein écran) | plein écran | 4 % | 0,12 u/s, dérive +0,05 u/s en sin (période 18 s) | `#D6DCD2` |
| Brume haute (Haut seulement) | plein écran, masque radial 6 u autour du joueur | 3 % | 0,4 u/s | `#E2E4DA` |

**Particules d'ambiance** (`GPUParticles2D`, valeurs Haut ; §5 pour Moyen/Bas) :
| Système | Quantité | Paramètres |
|---|---|---|
| Bruine (shader plein écran `rain_sheet`) | densité 0,25 (0-1) | inclinaison 10°, longueur des traits 0,25 u, vitesse 9 u/s, opacité 5 %, teinte `#FFE8C8` (rétro-éclairée) |
| Gouttes individuelles rétro-éclairées (particules) | 120 | texture `drop_32`, 0,06-0,10 u, chute 7 u/s, alpha 0,35, visibles surtout dans les rayons |
| Éclaboussures au sol | 60/s | atlas `splash_8x64`, 8 images en 0,25 s, 0,2-0,35 u, placées sur `.` et `,` uniquement |
| Pétales/feuilles de pin | 12 | texture `leaf_pine_32` (3 variantes), chute 1,5 u/s, dérive 0,6 u/s, rotation 90°/s, alpha 0,8 |
| Moucherons au-dessus des bassins | 30 | `mote_16`, mouvement brownien 0,3 u, alpha 0,4, uniquement à Calme/Tendu |
| Ondulations sur l'eau | 20/s | atlas `ripple_8x64`, 0,3-0,6 u, 0,6 s |

**Rayons de lumière** (sprites additifs `godray_512x1024`, z = 32) : 3 à 5 rayons orientés 310°, largeur 2-4 u, longueur 14 u, alpha 0,10-0,16, défilement lent (translation 0,1 u/s sur leur normale, période de fondu 12 s), déclenchés seulement si `cloud_cover < 0,6` (donc Calme et Tendu). Teinte `#FFE3B5`.

**Reflets dans les flaques** : les cases `,` et les flaques du sol (masque `puddle_mask_1024`, 4 variantes) reflètent : (a) le gradient de ciel `sky_sunset_256x64` à 35 % (bandes pêche → gris-vert), défilant avec les nuages à 0,05 u/s ; (b) les lumières `light_mask` bit 2 (joueur, sorts, piliers, coffres, boss) avec un facteur 0,6 et un étirement vertical ×1,6 ; (c) en Haut, le miroir des entités (texture écran inversée en Y, décalage 0,8 u, alpha 0,25, ondulé par `ripple_normal_256` à 0,5 Hz). Les télégraphes **ne se reflètent pas** (ils sont sur le Layer 5) : le design demandait des « flaques qui reflètent les télégraphes et les sorts » : on reflète les **sorts et leurs lumières**, mais le télégraphe reste unique à l'écran pour ne pas créer de faux cercle.

### 2.2 Carte 2 : Forêt-brume : **aube brumeuse, heure bleue sous la canopée**

**Récit lumineux** : 20 minutes avant le lever du soleil, sous des cèdres géants. La lumière vient du ciel, diffuse, bleu-vert ; aucune ombre nette, seulement des **masses**. La brume glisse au ras des racines, les lucioles vertes dérivent, les lanternes des sanctuaires sont les seuls points chauds-froids (vert pâle `#9CF0C8`). La pluie est lourde et lente, filtrée par les branches : grosses gouttes qui tombent des feuilles. Quand D monte, l'aube ne vient jamais : la brume épaissit, les lucioles s'éteignent, les lanternes s'allument (repères).

**Lumière ambiante** : `#8FA3A8` (linéaire 0,28 / 0,37 / 0,40 ; luminance 0,35). **Attention** : c'est en dessous de la borne 0,42 ; on compense par une directionnelle « ciel » à énergie 0,45 qui remonte tout uniformément. **Règle** : la somme ambiante + directionnelle doit donner une luminance effective ≥ 0,42 sur un sol plat (mesure : L\* du sol ≥ 25 sur capture). Si le palier Bas désactive la directionnelle, `AmbienceConfig` remplace l'ambiante par `#A6B8BC` (luminance 0,46).

**Lumière directionnelle** :
- `rotation` : 315°, `color` : `#C2E6E0` (cyan très pâle), `energy` : 0,45, `height` : 0,8 (lumière de ciel, presque zénithale : relief doux).
- Ombres : **désactivées** (aube diffuse). À la place, un **masque d'ombre de canopée** (texture `canopy_shadow_2048`, multiply à 25 %, z = −16) défile à 0,08 u/s avec une respiration d'échelle ±2 % (période 9 s) : donne des taches de lumière mouvantes sans coût d'ombre.
- Longueur d'ombre : 0 u.

**Étalonnage** :
| Paramètre | Valeur |
|---|---|
| Teinte des ombres | `#1C2A33` à 25 % (bleu nuit) |
| Teinte des hautes lumières | `#D8F2E8` à 15 % (vert d'eau) |
| Saturation | 0,92 (on désature le décor, les monstres gardent leur chroma via leur émission ; les monstres de cette carte sont **choisis plus saturés** à la source : +10 % dans Blender) |
| Contraste | 0,96 (image douce) |
| Vignette | 0,30, rayon 0,72, douceur 0,55, couleur `#0E1A1E` |

**Sources ponctuelles du décor** :
| Source | Couleur | Rayon | Énergie | Scintillement | Occurrence |
|---|---|---|---|---|---|
| Lanterne de sanctuaire | `#9CF0C8` | 3,5 u | 0,45 (Calme) → 0,7 (Furieux) | respiration 0,6 Hz ±8 % + bruit ±4 % | 6-8 sur la carte, ≤ 3 visibles |
| Champignons luminescents (Sanctuaire de risque) | `#7BE0B0` | 1,5 u | 0,25 | pulsation 0,3 Hz | cercle de 8, une seule lumière pour l'anneau |
| Eau luminescente des étangs | `#4FB8A0` | émission de la tuile (`_e.png`), **pas de lumière** | — | vagues 0,2 Hz | toutes les cases `~` |
| Lucioles | `#B8FF8A` | émission des particules, **pas de lumière** ; 1 `PointLight2D` douce rayon 5 u énergie 0,12 sur le centre de chaque nuée (≤ 2) | — | — | voir particules |

**Couches de brume** :
| Calque | Hauteur | Densité | Vitesse | Couleur |
|---|---|---|---|---|
| Brume basse 1 (racines) | plein écran, **masquée** par la hauteur du sol : plus dense dans les creux (masque `fog_height_mask` par carte, 1 par carte, 512 px) | 10 % (Calme) → 15 % (Furieux) | 0,18 u/s, direction 200° (vers bas-gauche) | `#B8C8C0` |
| Brume basse 2 (nappes) | nappes de 6-10 u (sprites `fog_puff_512`, 6 variantes), 8-12 à l'écran | 7 % chacune, bords doux | dérive 0,10 u/s + rotation 2°/s | `#C4D2CC` |
| Brume haute (Haut) | plein écran, masque radial 6 u autour du joueur | 5 % | 0,3 u/s | `#CFDCD4` |
| Brume d'anneau du Cerf-Lanterne (gameplay) | anneau 2 u sur le bord de la zone de charge (shader) | 20 %, **sous les entités** | rotation 6°/s | `#B8C8C0` + liseré `#CFE8FF` |

**Particules d'ambiance** :
| Système | Quantité | Paramètres |
|---|---|---|
| Pluie (shader `rain_sheet`) | densité 0,35 | inclinaison 6° (abritée), traits 0,35 u, vitesse 7 u/s, opacité 7 %, teinte `#C8DCD8` |
| Grosses gouttes de canopée (particules) | 80 | `drop_32`, 0,10-0,16 u, chute 6 u/s, une éclaboussure `splash_8x64` à l'impact (0,3-0,45 u) |
| Éclaboussures au sol | 45/s | atlas 8 images, 0,3 s |
| Lucioles | 2 nuées de 24 | `firefly_16`, additif, trajectoire sin/cos 0,5 u, vitesse 0,4 u/s, alpha 0,0 → 0,9 → 0,0 sur 2,5 s (clignotement décalé), couleur `#B8FF8A` ; **éteintes à Furieux** (fondu 10 s) |
| Spores/pollen | 40 | `mote_16`, 0,05 u, alpha 0,25, dérive 0,2 u/s, montent légèrement |
| Feuilles de cèdre | 8 | `leaf_cedar_32` (3 variantes), chute 1,2 u/s |
| Ondulations sur l'eau | 30/s | `ripple_8x64` |

**Rayons de lumière** : aucun à Calme (pas de soleil). À l'instant où un **pilier** se termine (lueur blanche), 2 rayons verticaux (`godray_512x1024`, 88°, presque verticaux) descendent 6 s sur le pilier, alpha 0,18 → 0 : « le ciel s'ouvre une seconde ». C'est une récompense lumineuse, pas une ambiance.

**Reflets dans les flaques** : étangs noirs (`~`) : miroir sombre, `sky_dawn_256x64` (bleu nuit → vert d'eau) à 25 %, lumières bit 2 à 0,8 (les lanternes et le joueur se reflètent très nettement dans l'eau noire : c'est l'image signature de la carte), ondulation lente 0,3 Hz, amplitude 0,02 u. Flaques du sol : masque `puddle_mask_1024`, reflets à 0,4.

### 2.3 Carte 3 : Cité de rouille : **crépuscule d'orage, nuit qui tombe sur le canal**

**Récit lumineux** : 20 minutes après le coucher du soleil, sous un orage. Le ciel est anthracite violacé ; l'unique chaleur vient des **lampes à vapeur** orange le long du canal (petites, 0,4 u, pour ne pas concurrencer le joueur) et du bronze vert-de-gris du Sonneur. Le vent pousse la pluie en rideaux (angle 18-25°), les éclairs révèlent la ville une fraction de seconde (silhouettes des cuves, reflets dans le canal). C'est la carte la plus sombre, et donc celle où les garde-fous de lisibilité sont les plus stricts.

**Lumière ambiante** : `#9A9CA8` (linéaire 0,32 / 0,33 / 0,40 ; luminance 0,34) + directionnelle « ciel d'orage » énergie 0,4 → luminance effective ≈ 0,45. Teinte bleu-violet froide. Borne basse à Cataclysme : `#8C8E9C` (voir §3).

**Lumière directionnelle** :
- `rotation` : 320°, `color` : `#B9BCD6` (lavande grise), `energy` : 0,40, `height` : 0,6.
- Ombres : activées en Haut seulement, très courtes (0,6 u), `shadow_color` `#15181F` alpha 0,5, `PCF13` (douces : ciel couvert).
- **Flash d'éclair** : la directionnelle passe à `energy` 1,6, `color` `#E8ECFF`, `rotation` aléatoire 280°-340°, pendant 80 ms (ombres longues instantanées de 2,5 u en Haut : « la ville se révèle »), voir §3.4.

**Étalonnage** :
| Paramètre | Valeur |
|---|---|
| Teinte des ombres | `#141826` à 30 % (bleu nuit violacé) |
| Teinte des hautes lumières | `#FFD2A0` à 12 % (les hautes lumières tirent vers les lampes) |
| Saturation | 0,88 décor ; **les monstres de cette carte sont rendus à +15 % de chroma** dans Blender pour compenser |
| Contraste | 1,12 (pivot 0,40) |
| Vignette | 0,34, rayon 0,70, douceur 0,5, couleur `#0A0C14` ; **jamais plus** : la zone de 7 u autour du joueur reste à pleine valeur |

**Sources ponctuelles du décor** :
| Source | Couleur | Rayon | Énergie | Scintillement | Occurrence |
|---|---|---|---|---|---|
| Lampe à vapeur | `#FF9A3C` **désaturée à 60 %** → `#E8A86C` | 2,8 u | 0,45 | grésillement : bruit ±15 % à 8 Hz + extinction 120 ms toutes les 6-14 s (à Cataclysme : toutes les 2-5 s) | ≈ 24 sur la carte, ≤ 4 visibles |
| Lampe à vapeur : halo dans la pluie | sprite additif `halo_soft_256` même couleur | 1,8 u | alpha 0,18 (monte avec `rain_intensity` : 0,18 + 0,20 × r) | idem lampe | 1 par lampe |
| Cuves : liserés de rouille chauffée | émission `_e.png` `#B07A48` | — | — | — | relief seulement |
| Guichet du marchand | `#9CE0FF` (écran froid) | 2 u | 0,35 | clignote 2 Hz, 1 image sur 8 noire | 1 si événement |
| Canal (eau profonde) | reflets seulement, **pas de lumière** | — | — | — | |
| Cloche d'alerte (prop sud) | `#CFE8FF` | 3 u | 0,2 (idle), 0,8 pendant 300 ms à chaque éclair | — | 1 |

**Couches de brume** :
| Calque | Hauteur | Densité | Vitesse | Couleur |
|---|---|---|---|---|
| Vapeur des cuves | nappes 3-5 u sortant des cuves et grilles (`fog_puff_512`, montée 0,5 u/s, dissipation 4 s) | 9 % | poussée par le vent : 0,6 u/s à 200°-230° | `#B8B2A8` (vapeur légèrement chaude près des lampes : teinte vers `#D0B08A` dans 2 u d'une lampe) |
| Brume du canal | bande de 6 u de large sur le canal (masque), | 6 % | 0,3 u/s le long du canal (vers le sud) | `#9FA8B8` |
| Embruns de pluie (Haut) | plein écran, masque radial 6 u | 4 % | 1,2 u/s (vent) | `#A8B0C0` |

**Particules d'ambiance** :
| Système | Quantité | Paramètres |
|---|---|---|
| Pluie en rideaux (shader) | densité 0,45 (Calme) → 1,0 | inclinaison **18°** (Calme) → 25° (Cataclysme), traits 0,5 u, vitesse 12 u/s, opacité 8 → 12 %, teinte `#C0C8E0` ; **2 couches** (proche : traits 0,5 u ; lointaine : 0,3 u, 60 % de l'opacité) |
| Rafales (bandes de densité) | — | modulation de la densité par un bruit 1D défilant (période 3-6 s, amplitude ±40 %) : la pluie « respire » |
| Éclaboussures au sol | 90/s (Calme) → 220/s | atlas 8 images, 0,25-0,4 u, orientées par le vent |
| Rebonds sur les passerelles métalliques | 40/s sur les cases de pont | `splash_8x64` variante « métal » (plus blanche), 0,15 u |
| Étincelles des lampes | 3/s par lampe visible | `spark_16`, chute 1 u, 0,4 s, additif `#FFC27A` |
| Cendres/rouille portées par le vent | 25 | `ash_16` (2 variantes), vitesse du vent 1,2 → 3 u/s, alpha 0,5, teinte `#8A6A48` |
| Ondulations sur le canal | 60/s | `ripple_8x64` + traînées de vent (`wind_streak_128`, 6/s) |

**Rayons de lumière** : aucun naturel. Les **lampes** projettent des cônes dans la pluie (`lightcone_256x512`, additif, alpha 0,12, orienté vers le bas, 2 u de long) ; les **éclairs** déclenchent 1-2 rayons `godray_512x1024` blanc-bleu alpha 0,30 → 0 en 400 ms depuis le haut de l'écran.

**Reflets dans le canal et les flaques** : le canal (`~`) est le **miroir principal** du jeu : `sky_storm_256x64` (anthracite → violet) à 30 %, lumières bit 2 à 1,0 (reflets orange des lampes et de la braise du joueur très lisibles, étirés ×2,2 verticalement, hachés par les vagues `ripple_normal_256` à 0,8 Hz amplitude 0,04 u), miroir des entités en Haut à 0,30. À chaque éclair, le canal se **remplit de blanc** (`#DCE4FF`, alpha 0,5, 80 ms puis décroissance 300 ms). À Cataclysme, les ponts `,` deviennent sol + reflets (Design §4.3) : ils héritent du shader de flaque à 0,6.

### 2.4 Tableau comparatif des trois cartes (Calme)

| | Terrasses noyées | Forêt-brume | Cité de rouille |
|---|---|---|---|
| Heure | 17 h 40, soleil sous les nuages | 5 h 10, heure bleue | 19 h 30, orage |
| `CanvasModulate` | `#C9C1B0` (lum 0,53) | `#8FA3A8` (lum 0,35) + ciel 0,45 | `#9A9CA8` (lum 0,34) + ciel 0,40 |
| Directionnelle | 310°, `#FFD9A8`, 0,55, h 0,25 | 315°, `#C2E6E0`, 0,45, h 0,8 | 320°, `#B9BCD6`, 0,40, h 0,6 |
| Ombres | 2,0 u, `#2E3B3A` 55 % | aucune (canopée en multiply) | 0,6 u, `#15181F` 50 % (Haut) |
| Saturation / contraste | 1,05 / 1,08 | 0,92 / 0,96 | 0,88 / 1,12 |
| Vignette | 0,22 | 0,30 | 0,34 |
| Pluie (densité, angle, opacité) | 0,25, 10°, 5 % | 0,35, 6°, 7 % | 0,45, 18°, 8 % |
| Brume totale (somme des alphas) | 12 % | 17 % | 15 % |
| Signature | rayons dorés, bruine qui scintille | lanternes dans l'eau noire, lucioles | lampes orange, éclairs sur le canal |
| Monstres (chroma dans Blender) | référence | +10 % | +15 % |

---

## 3. Évolution avec la jauge de difficulté

Paliers (`Maths_Scaling` §2) : Calme D < 1,5 ; Tendu 1,5-2,5 ; Hostile 2,5-4 ; Furieux 4-6 ; Cataclysme > 6. En Moyen, un étage 1 va de D = 1,0 à ≈ 1,6, l'étage 2 de ≈ 2,2 à 3,0, l'étage 3 de ≈ 3,8 à 5,3 ; Cataclysme n'est atteint qu'en Difficile ou en sans fin : il doit être **spectaculaire mais rare**.

### 3.1 Règle d'interpolation

Chaque paramètre p est défini aux **pivots** D = 1,0 / 2,0 / 3,25 / 5,0 / 7,0 (milieux des paliers) et interpolé linéairement entre eux ; au-delà de D = 7, les valeurs sont **gelées** (le sans fin ne doit pas finir dans le noir). `AmbienceConfig.evaluate(D)` renvoie un dictionnaire ; la scène d'ambiance tweene vers ces valeurs avec un lissage de 8 s (lerp exponentiel, demi-vie 2 s) pour absorber le saut de ×1,15 à l'entrée d'un étage. Exceptions discrètes : éclairs (gated par palier), extinction des lucioles, allumage des lanternes (fondus de 10 s déclenchés au passage de palier).

### 3.2 Paramètres communs (fonction de D)

| Paramètre | Calme (1,0) | Tendu (2,0) | Hostile (3,25) | Furieux (5,0) | Cataclysme (7,0) |
|---|---|---|---|---|---|
| `rain_intensity` (0-1, pilote densité, éclaboussures et audio) | carte ×1,0 | ×1,4 | ×1,9 | ×2,4 | ×3,0 (plafonné à 1,0) |
| Opacité du calque de pluie (max absolu) | 5-8 % | 7-9 % | 9-10 % | 11 % | **12 %** |
| Angle de pluie (ajout au vent de la carte) | +0° | +2° | +4° | +7° | +10° |
| Vent (dérive des particules et de la brume) | ×1,0 | ×1,3 | ×1,8 | ×2,5 | ×3,2 |
| Assombrissement (`CanvasModulate` × facteur) | ×1,00 | ×0,97 | ×0,92 | ×0,86 | ×0,80 (clampé par la borne 0,42) |
| Teinte de l'ambiante (mélange vers une couleur d'orage) | 0 % | 5 % | 12 % vers `#A89AA0` (« teinte rouge discrète », GDD) | 20 % vers `#8E8CA8` | 30 % vers `#7E7CA0` |
| Couverture nuageuse (`cloud_cover`, pilote rayons et ombres de nuages) | 0,3 | 0,5 | 0,7 | 0,9 | 1,0 |
| Vitesse des ombres de nuages | 0,08 u/s | 0,12 | 0,2 | 0,35 | 0,5 |
| Contraste (ajout) | +0 | +0,02 | +0,04 | +0,06 | +0,08 |
| Saturation du décor (ajout) | 0 | −0,02 | −0,05 | −0,08 | −0,10 |
| Vignette (ajout) | +0 | +0,02 | +0,05 | +0,08 | +0,10 |
| Éclairs de décor | non | non | carte 3 seulement, toutes les 25-40 s, flash 40 % | cartes 1-3, toutes les 12-25 s, flash 70 % | toutes les 6-14 s, flash 100 %, doubles (2 flashs à 120 ms) 30 % du temps |
| Vibration de l'image (Cataclysme, GDD) | — | — | — | — | tremblement 1 px à 12 Hz pendant 400 ms après chaque tonnerre, désactivable |
| Lumière du joueur (compensation) | rayon ×1,0 | ×1,0 | ×1,05 | ×1,10 | ×1,15 (plus l'orage monte, plus la braise porte : le joueur reste le phare) |
| Lampes/lanternes du décor | état de base | | +20 % d'énergie | +40 % | +40 % + extinctions fréquentes (carte 3) |

### 3.3 Spécificités par carte

**Carte 1, Terrasses noyées (le soleil se noie)** :
| | Calme | Tendu | Hostile | Furieux | Cataclysme |
|---|---|---|---|---|---|
| Directionnelle (couleur, énergie) | `#FFD9A8`, 0,55 | `#F3D0A6`, 0,50 | `#D8CDB8`, 0,40 | `#B8C2BC`, 0,32 | `#A8B4B8`, 0,28 |
| `CanvasModulate` | `#C9C1B0` | `#C2BDB0` | `#B4B8B0` (retour au gris-vert) | `#A4ACA8` | `#98A2A0` |
| Rayons de soleil | 3-5, alpha 0,10-0,16 | 2-3, 0,08 | 0 (fondu 15 s) | 0 | 0 |
| Longueur d'ombre | 2,0 u | 1,6 u | 1,0 u | 0,6 u | 0,4 u |
| Lanternes de pierre | éteintes | éteintes | **s'allument** (fondu 10 s), `#A8C8B8`, 2,5 u, 0,35 | 0,45 | 0,45, scintillement ±20 % |
| Bassins | normal | normal | **débordent** (Design §4.2) : brume basse 1 rayon 4 → 6 u, 8 → 12 % | 12 % | 14 % |
| Pluie | bruine 0,25, 10° | 0,35, 12° | 0,5, 14°, traits 0,35 u | 0,65, 17° | 0,8, 20°, rideaux |
| Teinte des gouttes | `#FFE8C8` (rétro-éclairées) | `#F0E2CC` | `#D8DCD4` | `#C8D0D0` | `#C0C8CC` |

**Carte 2, Forêt-brume (l'aube ne vient pas)** :
| | Calme | Tendu | Hostile | Furieux | Cataclysme |
|---|---|---|---|---|---|
| Directionnelle | `#C2E6E0`, 0,45 | `#B8DCDA`, 0,45 | `#A8CCD0`, 0,42 | `#98B8C4`, 0,40 | `#8CA8BC`, 0,40 |
| `CanvasModulate` | `#8FA3A8` | `#8C9EA6` | `#889AA6` | `#8494A4` (plancher) | `#8494A4` (plancher) |
| Brume basse 1 | 10 % | 11 % | 13 % | **15 %** (max) | 15 % |
| Nappes de brume | 8-12 | 10-14 | 12-16 | 16-20 | 20-24 (plafond) |
| Lucioles | 2 nuées | 2 | 1 | **éteintes** (fondu 10 s) | éteintes |
| Lanternes de sanctuaire | 0,45 | 0,5 | 0,6 | **0,7**, rayon 4 u (repères, Design §4.2) | 0,7, 4,5 u |
| Masque de canopée | 25 %, 0,08 u/s | 25 %, 0,12 | 30 %, 0,2 | 32 %, 0,35 (les branches s'agitent : échelle ±4 %) | 35 %, 0,5 |
| Pluie | 0,35, 6° | 0,45, 7° | 0,6, 9° | 0,75, 12° | 0,9, 15° |
| Gouttes de canopée | 80 | 100 | 130 | 160 | 200 |
| Éclairs | non | non | non | lointains : flash 50 %, directionnelle à 1,2, **pas de rayon** (canopée) | flash 80 %, toutes les 8-16 s |

**Carte 3, Cité de rouille (l'orage éclate)** :
| | Calme | Tendu | Hostile | Furieux | Cataclysme |
|---|---|---|---|---|---|
| Directionnelle | `#B9BCD6`, 0,40 | `#B0B4D0`, 0,40 | `#A6AACC`, 0,42 | `#9CA2C8`, 0,45 | `#949CC8`, 0,45 |
| `CanvasModulate` | `#9A9CA8` | `#9698A6` | `#9294A4` | `#8E90A0` | `#8C8E9C` (plancher) |
| Pluie | 0,45, 18°, 8 %, 1 couche | 0,6, 19°, 9 %, 2 couches | 0,75, 21°, 10 % | 0,9, 23°, 11 % | 1,0, 25°, 12 %, rafales ±50 % |
| Éclaboussures | 90/s | 120/s | 160/s | 200/s | 220/s |
| Éclairs | non | lueurs d'horizon seulement (bord haut de l'écran, `horizon_glow_1024x256`, alpha 0,15, 300 ms, toutes les 30-60 s, sans tonnerre audible fort) | **éclair toutes les 25-40 s** (Design §4.3 : 10-20 s à Furieux) | **toutes les 10-20 s**, flash 100 %, ombres 2,5 u | **toutes les 6-12 s**, doubles 30 %, le canal monte (ponts = flaques), lampes clignotent (extinction 120 ms toutes les 2-5 s) |
| Vapeur des cuves | 9 % | 9 % | 11 % | 13 % | 14 %, vitesse 1,5 u/s |
| Cendres | 25 | 30 | 40 | 60 | 80 |
| Brume du canal | 6 % | 6 % | 8 % | 10 % | 12 % |

### 3.4 Éclairs : séquence détaillée

1. **Pré-signal** (Haut/Moyen, facultatif) : 150 ms avant, lueur d'horizon alpha 0,1 (le joueur l'apprend sans s'en rendre compte).
2. **Flash** (Layer 6, ColorRect additif `#E8ECFF`) : alpha 0 → **0,60** en 1 frame, tenu 80 ms, décroissance exponentielle à 0 en 160 ms. Un second flash (double) après 120 ms à 0,4 dans 30 % des cas à Cataclysme. Intensité ×0,40 Hostile, ×0,70 Furieux, ×1,0 Cataclysme ; ×0,25 si l'option « secousses et flashs » est réduite ; **jamais** plus de 3 flashs en 10 s, **jamais** moins de 4 s entre deux événements d'éclair (recommandation d'accessibilité photosensible : ≤ 3 flashs/s, on est très en dessous).
3. **Directionnelle** : pendant le flash, `energy` → 1,6, `color` `#E8ECFF`, `rotation` tirée dans 280°-340° (l'ombre « saute » d'un côté), ombres allongées à 2,5 u (Haut) ; retour en 160 ms.
4. **Ciel visible** : sprite `lightning_bolt_256x1024` (4 variantes, Design §5.3 pour le Sonneur) dans le bord haut de l'écran, alpha 0,9, 80 ms, uniquement dans 50 % des cas (les autres sont des éclairs « hors champ » : flash seul).
5. **Reflets** : le canal / les bassins / les flaques reçoivent `#DCE4FF` alpha 0,5 sur 80 ms puis 300 ms de décroissance.
6. **Tonnerre** : délai = 0,3 s + distance virtuelle × 0,35 s (distance 0-6 tirée au hasard, pondérée vers le proche quand D monte : à Cataclysme 70 % des éclairs sont à distance ≤ 1,5, donc tonnerre en moins de 0,85 s). Le tremblement de 1 px (Cataclysme) démarre au tonnerre, 400 ms.
7. **Lampes à vapeur** (carte 3) : 60 % des éclairs provoquent une extinction de 120 ms d'une lampe visible (surtension), 300 ms après le flash.
8. **Gameplay** : l'éclair **n'inflige rien** et **n'est pas un télégraphe** ; la foudre du Sonneur (phase 2) utilise le **même flash** mais à 0,35 d'alpha, précédé de son cercle rouge télégraphé 1,0 s : le joueur apprend que « flash fort = décor, cercle rouge = danger ».

---

## 4. Lumière du gameplay

Toutes les lumières de gameplay sont des `PointLight2D` tirées d'un **pool** (`LightPool`, taille = budget du palier §5) et partagent 3 textures : `light_soft_256` (gaussienne, pour les halos chauds), `light_hard_256` (plateau + bord doux 25 %, pour les piliers et coffres), `light_ring_256` (anneau, pour les auras d'élite). `texture_scale = rayon_px × 2 / 256`. Le `shadow_enabled` n'est vrai que pour le joueur (Moyen) et le joueur + 4 lumières les plus proches (Haut). Toutes utilisent `blend_mode = ADD`, `range_z_min = −20`, `range_z_max = 10`, `light_mask` bit 1 (monde) et bit 2 (flaques) sauf mention.

### 4.1 Le joueur (Ardent, référence ; autres personnages en 4.1 bis)

| Propriété | Valeur |
|---|---|
| Texture | `light_soft_256` |
| Rayon | **4,5 u** (288 px) ; ×1,15 à Cataclysme ; +0,25 u par stack d'item « Feu » visible (plafond 6 u) |
| Couleur | `#FF9A3C` (braise) ; cœur 0,8 u en `#FFD36B` via une 2e lumière `light_soft_256` rayon 1,2 u énergie 0,5 (Haut seulement) |
| Énergie | **1,1** |
| Pulsation | battement cardiaque à **1,1 Hz** : 0,95 → 1,15 → 0,95 (deux pics courts, courbe « lub-dub » : +18 % pendant 90 ms, +8 % 120 ms plus tard) ; accélère à 1,6 Hz sous 30 % de PV |
| Ombres | Moyen : oui, `shadow_color` `#1E1410` alpha 0,45, PCF5 ; Haut : PCF13 |
| Comportement | la lumière est attachée au sprite, décalée de −0,3 u en Y (hauteur de la braise) ; à la mort, elle grandit à 8 u en 0,4 s puis s'éteint en 1,2 s (dernière braise) |
| Émission du sprite | `_e.png` : braise de la main et des yeux `#FFB060`, animée en opacité avec la pulsation |
| Glow (Haut/Moyen) | le sprite de braise dépasse 1,0 (HDR : émission ×1,8) → glow `intensity` 0,6, `bloom` 0,15, seuil 1,05 |

**4.1 bis, autres personnages** (même rayon 4,5 u, même énergie 1,1, teinte propre, toujours **chaude** : la règle est le joueur chaud, pas Ardent orange) : Veilleuse `#FFD36B` (lanterne d'or, pulsation lente 0,7 Hz ±6 %) ; Brise-Os `#FFB070` (braise rouge-orangée, pulsation 0,9 Hz) ; Chronomancienne `#FFE0A0` (ambre pâle, pulsation « tic-tac » 1 Hz à deux temps) ; Invocateur `#FFC080` (chaude) + familiers émissifs sans lumière ; Faux-Roi `#FF8A50` (plus rouge, pulsation 1,4 Hz, rayon 4 u).

### 4.2 Sorts (kit d'Ardent, et règles génériques)

| Sort | Lumière | Rayon | Couleur | Énergie | Durée / animation | Glow |
|---|---|---|---|---|---|---|
| Éclat de braise (auto, projectile) | **pas de lumière** (fréquence trop élevée) ; émission `_e.png` + traînée additive `trail_64x256` | — | `#FFB060` | — | traînée 0,25 s | émission 1,4 |
| Braises errantes (orbes) | 1 lumière **partagée** pour les orbes (centre de masse) | 2,5 u | `#FF9A3C` | 0,5 | pulsation 2 Hz ±15 % | 1,5 |
| Nova ardente (zone 6 s) | 1 lumière | 1,5 u → rayon de la nova + 1 u en 120 ms, puis décroissance 400 ms | `#FFD36B` → `#FF9A3C` | 1,8 → 0 | 1 lumière par lancer, retirée après 0,5 s ; pendant l'impact, les ombres (Haut) sont projetées depuis le centre | 2,0 pendant 120 ms |
| Pilier de flamme | 1 lumière | 3 u | `#FFB060` | 0,9, scintillement ±20 % à 10 Hz | durée du pilier | 1,6 |
| Cendres (zone persistante) | 1 lumière `light_hard_256` | rayon de la zone | `#FF7A30` à 50 % de chroma (braises rouges sombres) | 0,35, braises qui clignotent (émission de la texture) | durée de la zone, **ombres désactivées** | 1,2 |
| Pluie de météores (variante) | 1 lumière par impact, max 3 en vol | 2,5 u à l'impact | `#FFD36B` | 1,5 → 0 en 350 ms | | 1,8 à l'impact |
| Brasier (ultime) | 1 lumière | 7 u | `#FFC27A` | 1,4, respiration 1,5 Hz ±10 % | durée de l'ultime ; le `CanvasModulate` se réchauffe de 8 % vers `#FFD6B0` pendant la durée (le monde entier rougeoie : c'est l'ultime) | 1,8 ; **la pluie s'évapore** : particules `steam_puff_64` 20/s dans le rayon, éclaboussures remplacées par de la vapeur |
| Phénix (invocation) | 1 lumière | 3,5 u | `#FFB060` | 1,0, battement d'ailes 2 Hz ±12 % | durée | 1,6 |

**Règles génériques pour les autres personnages** : un sort à recharge = **1 lumière** au plus ; un auto = **0 lumière** (émission + traînée) ; un ultime = 1 lumière ≤ 7 u + modulation du `CanvasModulate` ≤ 8 % ; une zone persistante = `light_hard_256`, sans ombres, énergie ≤ 0,4. Couleurs par élément : feu `#FF9A3C`, givre `#5EC8FF` (seule lumière froide autorisée côté joueur, énergie ≤ 0,7 et toujours accompagnée d'un cœur blanc chaud `#FFF4E0`), foudre `#CFE8FF` (flash 60 ms puis 0), poison `#7BE04B` (énergie ≤ 0,4, jamais de glow : réservé aux télégraphes de mare), physique/acier `#FFF4E0` (blanc chaud). Les items qui agrandissent les sorts (« la taille et l'éclat des sorts augmentent avec les items », GDD §8) agrandissent **le rayon de lumière proportionnellement** (facteur du sort) et **l'énergie de +5 % par stack visible**, plafond +40 %.

### 4.3 Projectiles

| Type | Lumière | Visuel |
|---|---|---|
| Projectiles du joueur | aucune (sauf le plus gros : 1 lumière 1,5 u `#FFD36B` 0,6 pour un projectile ≥ 1 u, max 4 simultanées via le pool) | émission `_e.png` ≥ 1,3 (HDR), traînée additive `trail_64x256` 0,2 s, impact : `impact_8x64` 8 images 0,2 s + 6 étincelles `spark_16` |
| Projectiles ennemis (épines, boules, crachats, boulons) | **aucune** | émission 1,1, couleur de l'élément à chroma modéré, contour sombre 2 px ; « plus sourds » (GDD §8) : pas de traînée, pas de glow (émission < seuil 1,05) sauf la boule de feu du Seigneur des cendres (émission 1,3, traînée) |
| Vague de l'Éclusier, rayon du Jugement | 1 lumière chacun (voir 4.8) | |

### 4.4 Pickups

Aucune lumière (il peut y en avoir 300 au sol). Tout passe par l'émission et un **scintillement** piloté par le shader de l'atlas de pickups (`glint` déjà présent dans `pickup_manager.gd`) :

| Pickup | Couleur | Émission (HDR) | Scintillement | Taille |
|---|---|---|---|---|
| Pièce d'or | `#F2B81A` (base), reflet `#FFF0B0` | 1,25 | éclat `glint_32` (étoile 4 branches) 1 fois toutes les 1,2-2,4 s (phase aléatoire par pièce), 120 ms, alpha 0,9 ; rotation du reflet avec l'angle de la directionnelle de la carte | 0,3 u |
| Gemme d'XP (petite) | `#59E6FF` (cyan) | 1,3 | respiration 1,5 Hz ±20 % + reflet `glint_32` toutes les 2-4 s | 0,25 u |
| Gemme d'XP (grosse) | `#B380FF` (violet) | 1,4 | respiration 1 Hz ±25 %, halo additif `halo_soft_256` 0,8 u alpha 0,25 | 0,4 u |
| Rubis | `#FF4D6A` | 1,6 | 2 reflets décalés + halo 1 u alpha 0,35 + 4 étincelles `spark_16`/s ; **1 lumière** `#FF6A80` 1,5 u 0,5 (ils sont rares) | 0,4 u |
| Aimant/attraction | — | traînée `trail_64x256` à la couleur du pickup pendant l'attraction, 0,15 s | | |
| Ramassage | flash 1 image blanc sur le sprite + 3 étincelles vers le joueur | | | |

Sous la pluie, les pièces au sol ont un **reflet** dans les flaques (bit 2 n'est pas disponible sans lumière : on dessine un second sprite inversé alpha 0,25 uniquement si la pièce est sur une case flaque, Haut seulement).

### 4.5 Coffres par rareté

Les couleurs de `scripts/loot/chest.gd` font foi ; la lumière les rend lisibles à 20 u.

| Coffre | Couleur de lumière | Rayon | Énergie | Animation | Texture |
|---|---|---|---|---|---|
| Petit (bronze `#B08A59`) | `#D9A86A` | 1,5 u | 0,35 | respiration 0,5 Hz ±10 % | `light_hard_256` |
| Grand (bleu `#4A8FE3`) | `#6AA8F0` | 2,2 u | 0,5 | respiration 0,5 Hz ±12 % | `light_hard_256` |
| Légendaire (or `#FFB81C`) | `#FFCC4A` | 3,5 u | 0,8 | respiration 0,5 Hz ±15 % + 2 rayons `godray_512x1024` verticaux alpha 0,12 (Haut/Moyen) + 6 étincelles/s `spark_16` montantes | `light_soft_256` |
| Boss (violet `#C74ADE`) | `#D070F0` | 2,8 u | 0,7 | respiration 0,8 Hz | `light_soft_256` |
| Piégé (variante petit) | `#D9A86A` mais **scintillement irrégulier** (extinction 80 ms toutes les 1,5-3 s) : l'indice visuel lumineux s'ajoute à la chaîne cassée | 1,5 u | 0,35 | | |
| **Acheté / ouvert** | couleur → blanc chaud `#FFF4E0`, énergie 2,0 en 100 ms, puis 0 en 1,5 s ; 24 étincelles ; le couvercle émet 1,5 (HDR) pendant la révélation | | | | |
| **Inabordable** (or insuffisant) | aucune modification de la lumière (l'étiquette de prix suffit, `chest.gd`) | | | | |

Budget : avec 11 coffres posés par étage, ≤ 4 sont visibles en même temps ; les coffres hors champ **rendent leur lumière** au pool (`VisibleOnScreenNotifier2D`, marge 3 u).

### 4.6 Piliers (paratonnerres)

| État | Lumière | Détail |
|---|---|---|
| **Inactif** | aucune | bronze vert-de-gris, relief par la directionnelle ; à ≤ 6 u du joueur, un **reflet** de la braise sur le bronze (émission `_e.png` modulée par la distance au joueur : 0 → 0,6) : « il attend qu'on l'allume » |
| **Activation** (petit pilier) | `light_hard_256`, **0 → 7 u en 0,6 s** (rayon de la zone de combat), `#CFE8FF`, énergie 1,6 → 0,7 | arc électrique (boucle 8 images, émission 1,8), 1 rayon vertical `godray` alpha 0,2 pendant 1 s, 12 étincelles bleues ; le **bord de la zone de combat** (Layer 5, non éclairé) prend le relais pour la lisibilité |
| **Actif** (petit, combat en cours) | 3 u, `#CFE8FF`, 0,6, arc : scintillement ±25 % à 6 Hz bruité | 1 lumière seulement par pilier actif (2 piliers possibles) |
| **Activation** (gros pilier) | idem, 0 → 9 u en 0,8 s | |
| **Charge** (gros pilier, 90 s) | rayon **2 u → 9 u** linéaire avec la charge (0 → 100 %), énergie 0,5 → 1,0, couleur `#CFE8FF` → `#F0F6FF` ; toutes les 10 % de charge, une **impulsion** (+40 % d'énergie, 150 ms, 12 étincelles) ; quand le joueur sort de la zone, la lumière **se fige** et grésille (±30 % à 2 Hz) : la charge n'avance pas, on le voit | à ≥ 70 % : arc permanent plus épais, à 90 % : la pluie **monte** vers le paratonnerre dans 3 u (particules inversées, `drop_32`, 40/s) |
| **Terminé** | lueur blanche fixe 4 u, `#F4F8FF`, 0,5, aucune animation (repos) + **la foudre frappe** une fois à la complétion : flash 50 % (séquence §3.4 sans tonnerre lointain : tonnerre immédiat) ; carte 2 : les 2 rayons descendent 6 s | |
| **Téléporteur de sortie** | 2,5 u, `#CFE8FF`, 0,4, respiration 0,4 Hz ; à l'interaction : 0 → 12 u en 0,5 s, blanc, puis fondu de sortie | |

### 4.7 Élites (aura par affixe)

1 lumière `light_ring_256` par élite, rayon **1,8 u** (anneau de 1,2 à 1,8 u), énergie **0,55**, rotation de la texture 30°/s, respiration 1 Hz ±10 %, **pas d'ombre**, `light_mask` bit 1 seulement (pas de reflet : trop nombreux). Budget : ≤ 6 auras éclairées à la fois (les élites suivantes n'ont que leur sprite d'aura additif `aura_ring_128`, même couleur, alpha 0,6). Couleurs d'affixe (voir `GDD` §7 ; à compléter si la liste change) :

| Affixe | Couleur | Particule de statut (du Design §5.1) |
|---|---|---|
| Brûlure | `#FF8A30` | 6 braises/s |
| Givre | `#5EC8FF` | 4 cristaux/s |
| Poison | `#7BE04B` | 5 bulles/s |
| Foudre | `#CFE8FF` | arcs 2/s (`arc_8x64`) |
| Meute / vitesse | `#FFE066` | — |
| Carapace / brute | `#C0C8D0` (blanc acier) | — |
| Double affixe (D ≥ 4) | anneau bicolore (texture `light_ring_256` + seconde lumière décalée de 180° de rotation) | |

### 4.8 Boss (sources propres, lisibles à 30 u)

Chaque mini-boss a **1 lumière de corps** (1 par boss, ≤ 2 boss à la fois) + ses sorts ; les boss d'étage en ont 2.

| Boss | Lumière de corps | Sorts | Phase |
|---|---|---|---|
| Colosse de pierre | `#FF8A30` (fissures), 2,5 u, 0,4, pulsation 0,8 Hz | charge : traînée additive de poussière, pas de lumière ; onde : 1 lumière anneau 0 → 6 u en 0,3 s, `#FFF4E0` 0,8 → 0 | écrasement : fissures 1,0 pendant 4 s (vulnérable = plus lumineux) |
| Reine des ronces | `#7BE04B` à 50 % chroma, 2 u, 0,3 (couronne) | mares : `light_hard_256` rayon 2,5 u par mare, `#7BE04B` 0,3, **sans ombre**, max 4 (phase 2 : 1 lumière pour 2 mares) | phase 2 : couronne 0,5 |
| Seigneur des cendres | `#FF9A3C` **désaturé** `#E8A070`, 3 u, 0,7, scintillement ±15 % à 6 Hz (cœur-braise ; il doit rester **moins** chaud que le joueur : chroma 60 %) + vapeur `steam_puff_64` 8/s | flaques de braise : 1 lumière partagée par 3 flaques ; météores : 1 lumière/impact `#FFD36B` 1,5 → 0 ; mur de flammes : 1 lumière capsule (2 `PointLight2D` aux extrémités de la ligne, 2 u, 0,8) | phase 2 : vapeur ×2, cœur 0,9 |
| Ours de givre | `#5EC8FF`, 2,5 u, 0,35, souffle blanc `steam_puff_64` 4/s | souffle : 1 lumière 3 u `#AEE4FF` 0,6 ; blocs de glace : émission 1,2, 0 lumière, **mais** ils reflètent la braise du joueur (normal map + `_e` modulée par la distance, comme les piliers) | phase 2 : `#8ED8FF` |
| Essaim-mère | `#D6E85A` (abdomen), 3 u, 0,6, pulsation 1,2 Hz ±30 % (lumière interne, Design §2.5) | œufs : émission 1,1 ; nuée : 12 sprites émissifs ; ponte : aucune | phase 2 (abdomen éclaté) : lumière 0,3, 12 lucioles acides `firefly_16` en orbite |
| Archonte rouillé | `#6AE0FF` (heaume), 1,5 u, 0,5, clignote 1 image noire/2 s | Jugement : 2 lumières aux extrémités de la ligne, `#CFE8FF`, 3 u, 1,2 pendant 0,4 s, **le flash ne passe pas par le Layer 6** (ce n'est pas un éclair de décor) ; chaînes : émission 1,2, pas de lumière | phase 2 : pièces d'armure flottantes émissives `#B07A48` 1,2 |
| **L'Éclusier** (carte 1) | bronze (reflets `_e` + directionnelle), lumière 1 : `#FFD9A8` 3 u 0,35 ; lumière 2 : roue de vanne `#CFE8FF` 2 u 0,3 (tourne : rotation de texture 90°/s) | vague : 1 lumière capsule `#AEE4FF` 0,6 qui suit le front ; geysers : 1 lumière/geyser 2 u `#DCE8F0` 0,8 → 0 en 0,5 s | phase 2 (eau peu profonde partout) : la zone passe en shader de flaque 0,7 : **toutes les lumières se reflètent** ; phase 3 (ancré) : lumière 2 à 0,8, pulsation 1 Hz ; après la mort, les 2 geysers permanents gardent leur lumière |
| **Le Cerf-Lanterne** (carte 2) | ramure : **1 lumière** `#9CF0C8` 4 u 0,8 (les 4 lanternes sont dans l'émission `_e.png` de la couche séparée, pulsée à 0,6 Hz en code), lumière 2 : sabots `#9CF0C8` 1,5 u 0,25 | feux follets fixes : émission 1,5, halo `halo_soft_256` 0,8 u, 1 lumière partagée par 4 ; follets mobiles : émission + sprite d'aura, 0 lumière ; charge : traînée de lanternes `trail_64x256` verte 0,4 s | phase 2 (brume, lanternes allumées) : ramure 1,1, rayon 5 u ; phase 3 (lanternes éteintes) : ramure 0,25 pendant l'évaporation, 1,2 à la réapparition (impulsion 300 ms) ; après la mort, la brume d'anneau reste (sans lumière) |
| **Le Sonneur** (carte 3) | lumière 1 : paratonnerre `#CFE8FF` 2 u 0,3 + arcs `arc_8x64` 2/s ; lumière 2 : chaudière `#FF9A3C` désaturé `#E8A070` 2,5 u 0,4, visible par les rivets (émission) | glas : anneau lumineux 1 → 8 u en 0,8 s (`light_ring_256`, 0,9 → 0), `#CFE8FF` ; boulons : émission ; **foudre (phase 2)** : flash §3.4 à 0,35 + éclair `lightning_bolt` sur le cercle + 1 lumière 3 u `#FFFFFF` 2,0 → 0 en 200 ms + **ombres longues 2,5 u pendant 80 ms** (Haut) | phase 3 (chaudière rompue) : lumière 2 → 1,0 rayon 3,5 u, grésillement ±20 % à 10 Hz, vapeur `steam_puff_64` 20/s le long des jets ; après la mort, la foudre continue (toutes les 8 s) avec le même flash |

### 4.9 Télégraphes et zones (rappel : non éclairés)

- Layer 5, `render_mode unshaded`, palette §0 du Design ; aucune lumière ne les atteint, aucune brume ne les couvre, la pluie passe dessous.
- Ils **ne reflètent pas** dans les flaques (un faux cercle serait un faux danger).
- Le remplissage progressif reste **plat** (pas de glow) ; seul le liseré blanc 2 px peut émettre 1,2 pour accrocher le glow en Haut (il reste lisible en Bas sans).
- Le bord pulsant de la zone de combat (`#CFE8FF` 25 %) est aussi sur le Layer 5 ; la **lumière** du pilier (4.6) est dans World : les deux se superposent, l'un informe, l'autre habille.
- Test de recette (§1.1) obligatoire sur chaque carte à Cataclysme, en Bas et en Haut.

---

## 5. Paliers de qualité

Objectif : **60 fps** sur PC et mobile milieu de gamme (Moyen), **30 fps stables** sur mobile d'entrée de gamme (Bas, Mali-G52 / Adreno 610 à 1080×1920, ou rendu à 0,75 d'échelle), **60 fps** avec tout en Haut sur PC et mobile haut de gamme. Les 250 monstres et le gameplay sont prioritaires : la couche d'ambiance ne doit jamais coûter plus de **35 % du frame time** (Haut), 25 % (Moyen), 15 % (Bas).

| Fonction | **Bas** (mobile entrée de gamme) | **Moyen** (mobile milieu, PC portable) | **Haut** (PC, mobile haut de gamme) |
|---|---|---|---|
| `CanvasModulate` + teinte d'orage | oui | oui | oui |
| `DirectionalLight2D` | **non** (ambiante compensée : carte 2 `#A6B8BC`, carte 3 `#ACAEBC` ; le relief vient du sprite déjà éclairé) | oui, sans ombre | oui, ombres (carte 1 : 2 u ; carte 3 : 0,6 u ; carte 2 : aucune) |
| Normal maps | **non** (`CanvasTexture` sans normal : les lumières colorent sans relief) | oui sur sol, obstacles, boss, piliers, coffres ; non sur les monstres de tier 1-2 | oui partout |
| `PointLight2D` visibles (pool) | **8** : joueur 1, piliers ≤ 2, coffres ≤ 2, boss ≤ 1, sorts ≤ 2 ; décor 0 (les lampes sont des **halos additifs** `halo_soft_256`) ; élites 0 (sprites d'aura) | **16** : joueur 1-2, piliers 2, coffres 4, boss 2-3, sorts 3, élites 2, décor 2 | **32** : joueur 2, piliers 3, coffres 4, boss 4, sorts 6, élites 6, décor 5, réserve 2 |
| Ombres (`LightOccluder2D`) | aucune | joueur seul, PCF5, occluders : obstacles `#` et boss seulement | joueur + 4 lumières les plus proches, PCF13 ; occluders : obstacles, boss, coffres, piliers (monstres : **jamais**, 250 occluders tueraient le GPU) |
| Glow HDR (`hdr_2d`) | **non** : halos additifs pré-rendus (`halo_soft_256`) sur joueur, sorts, pickups rares | oui, `glow_levels` 2 (niveaux 3 et 5), `intensity` 0,5, `hdr_threshold` 1,05, `glow_normalized` | oui, 3 niveaux (2, 3, 5), `intensity` 0,6, `bloom` 0,15 |
| Étalonnage plein écran | **vignette seule** (sprite multiply `vignette_1024`, 1 draw) ; teintes d'ombres/hautes lumières **cuites** dans l'ambiante | shader : lift/gain/saturation/contraste/vignette, 1 passe | idem + reflets des entités dans les flaques (`hint_screen_texture`) |
| Pluie | 1 couche, shader simple (2 octaves), densité ×0,6, pas de rafales | 2 couches, rafales | 2 couches + gouttes individuelles (particules) |
| Éclaboussures (GPUParticles2D) | **40/s** max, 4 images | 120/s | 220/s + rebonds + ondulations |
| Brume | 1 calque plein écran défilant (densité ×1,0, le moins cher et le plus lisible) | 2 calques basse + nappes ≤ 8 | 3 calques (+ haute) + nappes ≤ 24 + masque de hauteur |
| Ombres de nuages / canopée | non | oui (1 texture multiply) | oui, 2 textures en parallaxe |
| Rayons de lumière | non | ≤ 3 sprites | ≤ 6 sprites |
| Particules d'ambiance (total à l'écran) | **≤ 150** (feuilles 4, lucioles 12, cendres 8) | ≤ 500 | ≤ 1 500 |
| Particules de gameplay (statuts, étincelles, impacts) | ≤ 300, statuts affichés sur 1 monstre sur 3 | ≤ 1 000 | ≤ 2 500 |
| Reflets dans les flaques | gradient de ciel statique + ondulation UV (normal `ripple_normal_256`) | + lumières bit 2 | + miroir des entités (alpha 0,25-0,30) |
| Éclairs | flash + directionnelle absente → flash seul à 0,6 (ou 0,25 si option) | flash + directionnelle + reflets | + ombres longues + rayons + bolt |
| Échelle de rendu | 0,75 (si fps < 30 après 10 s, passage automatique) | 1,0 | 1,0 |
| Coût cible de la couche d'ambiance | ≤ 5 ms (sur 33) | ≤ 4 ms (sur 16,6) | ≤ 5,5 ms (sur 16,6) |
| Draw calls supplémentaires (ambiance) | ≤ 12 | ≤ 30 | ≤ 60 |

**Règles de dégradation dynamique** (dans `AmbienceConfig`) : si le frame time moyen sur 2 s dépasse le budget du palier de 20 %, on coupe dans l'ordre : (1) miroir des entités, (2) ombres des 4 lumières secondaires, (3) nappes de brume au-delà de 8, (4) rayons, (5) particules d'ambiance ×0,5, (6) glow → halos, (7) `DirectionalLight2D`. On ne remonte qu'après 20 s sous le budget. La **lumière du joueur, les piliers, les télégraphes et le flash d'éclair ne sont jamais coupés**.

**Limites moteur à respecter** : Godot 4 limite à **16 lumières par CanvasItem** et le renderer Mobile à 256 lumières par viewport ; nos pools (8/16/32) et le `range_item_cull_mask` par zone garantissent qu'un même sprite de sol n'est jamais touché par plus de 8 lumières (sinon les lumières en trop sont ignorées silencieusement, ce qui ferait clignoter la braise du joueur). Les lumières d'une zone de combat se partagent le `item_cull_mask` bit 1 ; les lumières « flaques » ajoutent le bit 2.

---

## 6. Textures d'ambiance à rendre dans Blender (priorisées)

Toutes : PNG RGBA 8 bits, fond transparent, filtre linéaire, **sans** lissage sRGB cassé (exporter en sRGB, « Standard » view transform, pas Filmic/AgX pour les gradients de lumière). Les textures de lumière (`light_*`) sont en **niveaux de gris sur alpha** (Godot multiplie par `color`). Les textures raccordables (`_tile`) sont testées en 2×2 avant livraison. Nommage : `assets/ambience/<nom>.png`, `_n.png` et `_e.png` quand indiqués. Priorités : **P0** = nécessaire à la carte 1 jouable ; **P1** = cartes 2-3 et paliers ; **P2** = polish.

| Prio | Fichier | Taille | Variantes | Usage | Notes de rendu |
|---|---|---|---|---|---|
| P0 | `light_soft_256` | 256×256 | 1 | halos chauds (joueur, sorts, coffres légendaires) | gaussienne, 0 à 100 % au centre, rendu Cycles d'un disque émissif flouté (pas de code) |
| P0 | `light_hard_256` | 256×256 | 1 | piliers, zones, coffres petits/grands, mares | plateau 75 % puis bord doux |
| P0 | `light_ring_256` | 256×256 | 2 (anneau fin, anneau bicolore avec masque de 180°) | auras d'élite, glas du Sonneur | anneau de 66 à 100 % du rayon |
| P0 | `rain_sheet_512` | 512×512, raccordable | 2 (traits fins « bruine », traits longs « rideau ») | calque de pluie (shader : 2 échantillonnages décalés) | traits verticaux (l'inclinaison est faite en shader), gradient de longueur, 3 densités cuites dans R, G, B |
| P0 | `drop_32` | 32×32 | 4 | gouttes individuelles, pluie inversée des piliers | goutte rétro-éclairée avec reflet |
| P0 | `splash_8x64` | atlas 8×1 de 64 px (512×64) | 3 (eau, boue, métal) | éclaboussures au sol | rendu vue de dessus 60°, couronne d'eau qui s'ouvre en 8 images |
| P0 | `ripple_8x64` | 512×64 | 2 | ondulations sur l'eau et les flaques | anneau concentrique qui s'élargit et s'efface |
| P0 | `ripple_normal_256` | 256×256, raccordable | 2 | normal map animée des flaques (shader fait défiler 2 copies) | normal map de vaguelettes, amplitude faible |
| P0 | `puddle_mask_1024` | 1024×1024, raccordable | 4 | masque des flaques du sol (R = flaque, G = profondeur, B = bord mouillé) | bords organiques, 20-30 % de couverture ; livré avec `_n.png` |
| P0 | `fog_tile_1024` | 1024×1024, raccordable | 2 (A fin, B grumeleux) | brume basse plein écran | nuage volumétrique vu de dessus, contraste faible, alpha max 60 % (la densité se règle en code) |
| P0 | `vignette_1024` | 1024×1024 | 1 | vignette (Bas) et masque radial de brume haute | gradient radial doux, multiply |
| P0 | `sky_sunset_256x64` | 256×64 | 1 | reflet de ciel carte 1 | bandes horizontales pêche → or pâle → gris-vert, sans nuages |
| P0 | `godray_512x1024` | 512×1024 | 3 | rayons de soleil, de pilier, de coffre légendaire | faisceau vertical, bords doux, bruit léger, additif ; alpha max 50 % |
| P0 | `halo_soft_256` | 256×256 | 1 | halos additifs (lampes dans la pluie, Bas : remplace le glow) | gaussienne plus large que `light_soft` |
| P0 | `spark_16` | 16×16 | 2 | étincelles (sorts, coffres, lampes, piliers) | point avec traînée courte |
| P0 | `glint_32` | 32×32 | 2 | reflets des pièces et gemmes | étoile à 4 branches, blanc |
| P0 | `trail_64x256` | 64×256 | 2 | traînées de projectiles et de ramassage | gradient le long de la longueur |
| P0 | `impact_8x64` | 512×64 | 2 (feu, générique) | impacts de projectiles | |
| P0 | `cloud_shadow_2048` | 2048×2048, raccordable | 2 | ombres de nuages (multiply) | masque doux, 30-40 % de couverture, grandes formes (≥ 8 u) |
| P0 | `leaf_pine_32` | 32×32 | 3 | carte 1 | aiguilles et petites pommes |
| P0 | `mote_16` | 16×16 | 2 | moucherons, spores, pollen | |
| P1 | `fog_puff_512` | 512×512 | 6 | nappes de brume, vapeur des cuves | nuage isolé bords très doux ; livrées avec `_n.png` pour un relief léger (Haut) |
| P1 | `fog_height_mask` (par carte) | 512 px à l'échelle de la carte (≈ 9 px/u) | 3 (une par carte, à partir du schéma ASCII) | brume plus dense dans les creux | niveaux de gris, flou de 2 u |
| P1 | `canopy_shadow_2048` | 2048×2048, raccordable | 2 | ombres de canopée carte 2 | branches et feuillage de cèdre vus de dessous, bords doux |
| P1 | `sky_dawn_256x64` | 256×64 | 1 | reflet de ciel carte 2 | bleu nuit → vert d'eau |
| P1 | `sky_storm_256x64` | 256×64 | 1 | reflet de ciel carte 3 | anthracite → violet, bande claire d'horizon |
| P1 | `firefly_16` | 16×16 | 2 | lucioles, follets du Cerf | point vert avec halo |
| P1 | `leaf_cedar_32` | 32×32 | 3 | carte 2 | |
| P1 | `ash_16` | 16×16 | 2 | cendres et rouille portées (carte 3) | |
| P1 | `steam_puff_64` | 64×64 | 4 | vapeur (Brasier, cuves, Sonneur, Ours, Seigneur des cendres) | |
| P1 | `lightcone_256x512` | 256×512 | 2 | cônes des lampes dans la pluie | faisceau conique vers le bas |
| P1 | `lightning_bolt_256x1024` | 256×1024 | 4 (partagées avec le Sonneur, Design §5.3) | éclairs de décor et foudre | avec `_e.png` pour le glow |
| P1 | `horizon_glow_1024x256` | 1024×256 | 2 | lueurs d'orage lointaines (Tendu, carte 3) | gradient d'horizon bleu-blanc |
| P1 | `wind_streak_128` | 128×32 | 3 | traînées de vent sur l'eau | |
| P1 | `arc_8x64` | 512×64 | 3 | arcs électriques (piliers, Sonneur, élites Foudre) | boucle 8 images, émission |
| P1 | `aura_ring_128` | 128×128 | 1 | aura d'élite en sprite (Bas, et au-delà du budget) | anneau doux, additif |
| P1 | `water_caustics_512` | 512×512, raccordable | 2 | caustiques sur l'eau peu profonde (`,`) et la zone « montée des eaux » de l'Éclusier | boucle de 2 copies défilantes |
| P2 | `drop_window_64` | 64×64 | 6 | gouttes qui glissent sur « l'objectif » (Haut, option, ≤ 4 % d'opacité, jamais sur le centre) | avec `_n.png` pour réfraction |
| P2 | `fog_volume_tile_1024` | 1024×1024, raccordable | 2 | brume haute (Haut) | plus fine que `fog_tile` |
| P2 | `ember_16` | 16×16 | 3 | braises (Brasier, Cendres, Seigneur des cendres) distinctes des étincelles | orange, traînée |
| P2 | `frost_crystal_16` | 16×16 | 3 | statut givre, Ours | |
| P2 | `bubble_16` | 16×16 | 2 | statut poison, bassins | |
| P2 | `lantern_flare_128` | 128×128 | 2 | flare anamorphique des lanternes de sanctuaire et du Cerf (Haut) | trait horizontal doux |
| P2 | `rain_streak_far_512` | 512×512, raccordable | 1 | couche lointaine de pluie | traits plus courts et plus flous |

**Total** : 18 fichiers P0 (≈ 45 images en comptant les variantes), 17 P1, 8 P2. Toutes les textures de lumière et de particule sont **en niveaux de gris sur alpha** sauf les gradients de ciel, les feuilles, les cendres et les flares (colorés). Chaque texture est accompagnée dans `art/briefs/ambience/<nom>.md` d'une image de référence et de la taille en u à laquelle elle est affichée (pour que le pilote Blender cadre le rendu à la bonne échelle : une goutte de 32 px s'affiche à 0,06-0,16 u, soit 4-10 px à l'écran : le détail intérieur est inutile, la silhouette compte).

---

## 7. Besoins techniques à signaler à l'orchestrateur

1. **`AmbienceConfig`** (autoload ou nœud de `scenes/main.tscn`) : `quality: int` (0 Bas, 1 Moyen, 2 Haut), `evaluate(D: float, map_id: StringName) -> Dictionary` (toutes les valeurs de §2-§3), lissage temporel, bornes de luminance (§1.1), dégradation dynamique (§5). Signal `ambience_changed(params)`.
2. **`LightPool`** (`scripts/fx/light_pool.gd`) : `acquire(kind, priority) -> PointLight2D`, `release`, budgets par palier, priorité (joueur > piliers > télégraphes-lumière de boss > sorts > coffres > élites > décor), rendu des lumières hors champ.
3. **Signaux manquants** : `Events.lightning_struck(intensity, position)` (pour l'audio, le tremblement et les lampes), `Events.difficulty_tier_changed(tier)` (fondus discrets : lucioles, lanternes, rayons), `Events.pillar_charge_progress(pillar, ratio)` (lumière de charge), `Events.boss_phase_changed` (déjà demandé par le Design §6).
4. **Couche des télégraphes** : `CanvasLayer` layer 5 avec `follow_viewport_enabled`, sans `CanvasModulate`, et convention `light_mask = 0` pour tout nœud qui y est posé ; à ajouter à `CONTRACTS.md`.
5. **Option « secousses et flashs »** dans le menu de pause (GDD §4 mentionne « secousses ») : étendre à trois niveaux (complet / réduit / aucun) : réduit = flash ×0,25, tremblement 0 ; aucun = flash 0, l'éclair n'est signalé que par la directionnelle (×0,5) et le son.
6. **Pipeline Blender** : dossier `art/blender/ambience.blend` dédié (scènes de rendu de gradients, gouttes, brumes, nuages), un pilote d'assets à la fois (CLAUDE.md), sorties dans `game/assets/ambience/`.
7. **Recette** : scène de test `tests/test_ambience.tscn` qui charge chaque carte aux 5 pivots de D et aux 3 paliers, prend une capture et mesure le L\* du sol, d'un monstre violet de référence et d'un télégraphe rouge (§1.1), sortie `RESULT: OK` si les bornes sont respectées.

---

## 8. Éclairage profond v2 (21/10/2026) : valeurs en vigueur

Révision pour la DA « sérieuse » (STYLE.md) : sol sombre et contrasté, flaques de lumière franches, ombres portées longues. Les valeurs ci-dessous remplacent celles des §2-§5 quand elles diffèrent ; code : `scripts/ambiance/`, profils `data/ambiance/*.tres`, presets `data/ambiance/light_presets.json`.

**Architecture (masques de lumière).** Le sol et le décor (`Visual/Ground`, `Visual/Decor`) sont déplacés au **bit 8** (`LightRig.MASK_GROUND`) par `AmbianceManager.bind_map` ; les entités restent au **bit 1** (`MASK_WORLD`). Les lumières de gameplay et le soleil éclairent les deux (`MASK_LIT`, + bit 2 flaques) ; un **fill des entités** (`EntityFill`, DirectionalLight2D plate sans ombre, bit 1 seulement, couleur froide désaturée) rend joueur, monstres, pickups et coffres lisibles sans éclaircir le sol. L'ambiante (CanvasModulate) est donc plus basse : deux garde-fous dans `AmbianceProfile` : **sol** (ambiante + 0,33 × ciel) ≥ 0,20 avec soleil, ≥ 0,16 sans (Bas : ni ombre ni contraste d'étalonnage n'assombrissent plus le sol) ; **entités** (sol + fill) ≥ 0,42, le fill étant remonté en premier (`guard_fill`). Les paliers coupant le fill reviennent à une ambiante ≥ 0,42.

**Ombres directionnelles.** `DirectionalLight2D.max_distance` est un rayon de culling autour de la caméra (1 400 px, `SUN_SHADOW_CULL_PX`), pas une longueur d'ombre : les ombres 2D sont infinies ; `sun_shadow_length_u` module seulement l'alpha de l'ombre (plein à 2 u) et coupe les ombres sous 0,01 u. `sun_shadow_smooth` (nouveau paramètre) = `shadow_filter_smooth`. Les ombres du soleil sont actives dès **Moyen** (une ombre, occluders statiques).

| Carte (Calme → Cataclysme) | Ambiante (= ambiante Bas) | Ciel | Fill | Ombre (couleur, α, longueur u, flou) | Étalonnage | `lights_energy` |
|---|---|---|---|---|---|---|
| Terrasses | #7E7A70 → #626662 | #FFD2A0 0,50 h0,15 → #A4B0B4 0,26 | #B4C0C8 0,40 → 0,58 (Bas 0,50 → 0,68) | #1A2624 0,72, 3,2 → 1,2, 0,8 | lift #15201F 0,28 ; gain #FFE3B5 0,2 ; contraste 1,18 → 1,30 pivot 0,40 ; vignette 0,30 → 0,40 #0E1618 | 1,15 → 1,3 |
| Forêt-brume | #5E6E76 → #526272 | #B8DCD8 0,42 h0,7 → #82A2B6 0,38 | #A8C8CC 0,42 → 0,60 (Bas 0,52 → 0,70) | #0E1820 0,6, 1,0 → 0,6, 3,0 PCF13 | lift #0E1820 0,34 ; gain #D8F2E8 0,14 ; sat 0,9 ; contraste 1,10 → 1,18 pivot 0,38 ; vignette 0,36 → 0,45 #070E12 | 1,4 → 1,55 |
| Cité de rouille | #66687A → #5E606C | #A8ACCC 0,40 h0,4 → #8C94C0 0,46 | #A8B0C8 0,52 → 0,64 (Bas 0,62 → 0,74) | #0A0C14 0,7, 1,8 → 2,4, 1,5 PCF5 | lift #0C1020 0,36 ; gain #FFD2A0 0,12 ; sat 0,9 ; contraste 1,22 → 1,30 pivot 0,36 ; vignette 0,40 → 0,48 #05060C | 1,7 → 1,9 |

Luminance effective (Calme → Cataclysme) : sol 0,20 → 0,17 (terrasses), 0,19 → 0,16 (forêt), 0,19 → 0,16 (cité), garde-fou actif aux paliers hauts ; entités ≈ 0,42-0,45. `lights_energy` (nouveau paramètre de profil) multiplie l'énergie de **toutes** les lumières de gameplay et de décor de la carte : une flaque = lumière × albédo du sol, et le sol de la cité (albédo ≈ 0,08) demande 1,7 × l'énergie des terrasses (≈ 0,14) pour la même flaque.

**Presets (`light_presets.json`, avant `lights_energy`).** Joueur 1,8 / rayon 5,5 u (cœur 1,2 / 1,4 u, ombre α 0,65 #120C0A) ; lampes à vapeur 1,1 / 3,0 u ; lanternes de sanctuaire 1,1 / 3,6 u ; pierres 0,9 / 2,8 u ; coffres 0,75 / 2,0 u (petit) → 1,4 / 4,0 u (légendaire), ouverture 2,4 ; piliers actif 1,2 / 4,0 u, charge 0,9 / 2,5 u, activation 2,4, fini 1,0 / 4,5 u ; téléporteur 1,0 / 3,5 u ; braises 0,9 / 3,0 u, nova 2,6 / 4,5 u, pilier de flammes 1,5 / 3,5 u ; boss 0,9 / 3,0 u (éclair 2,4), autres boss/élites × 1,3 ; décor d'ambiance (bateau, échoppe, cercle, lucioles) 0,18-0,8.

**Qualité.** Bas : ni soleil ni HDR ni glow, fill actif, ambiante basse = ambiante de jour (plancher sol 0,16), vignette seule ; le rendu reste sombre mais ~15 % plus clair que Haut (pas de contraste d'étalonnage : coût). Moyen : ombres du soleil, glow 0,55 seuil 1,2. Haut : glow 0,7, bloom 0,04, seuil 1,2 (seuls les cœurs > 1,2 fleurissent : pas de voile). Coût mesuré (`tests/ambiance_bench.tscn`, cité D5, PC) : GPU +1,23 ms Haut, +0,94 ms Moyen, +0,23 ms Bas.

**Hors périmètre (à traiter par Codex / autres agents).** Les tilesets de sol n'ont pas de `CanvasTexture` (les `_n.png` existent mais ne sont pas branchés : la directionnelle rasante n'a donc pas de relief sur le sol) ; les halos jaunes des lampes de la cité sont **cuits dans le décor** (sprites), d'où leurs disques plats en Bas ; les flaques pâlissent sur un sol d'albédo < 0,1 : prévoir des sols un peu plus clairs là où l'on veut des flaques marquées.
