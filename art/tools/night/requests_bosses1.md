# Demandes d'art — boss d'étage 1 (Bouvier, Porteuse de jarres)

Code intégré le 22/10/2026 (aucun lot lancé) : `game/scripts/enemies/ox_herder_brain.gd`, `jar_bearer_brain.gd`
(+ `floor1_fx.gd` = formes dessinées PROVISOIRES, `floor1_hazards.gd` = zones au sol, `jar_bearer_jar.gd` =
jarre-mère cassable), tests `ox_herder_boss_test` / `jar_bearer_boss_test` / `floor1_boss_test`. Tant que rien n'est
livré, le jeu affiche des silhouettes et effets dessinés ; **chaque fichier ci-dessous se branche seul** dès qu'il
existe (chemins et noms d'anims enregistrés dans `game/data/fauna.json` → `boss_sprites.ox_herder` /
`boss_sprites.jar_bearer`). Ne rien renommer. L'Éclusier (lot C7a, livré) a reçu son IA propre
(`eclusier_brain.gd`) qui utilise déjà tous ses extras : c'est la **référence de qualité et de lisibilité** de ces
deux lots (même biome, même échelle, même accent).
Captures de référence (placeholders) : lancer les tests sans `--headless` avec
`--resolution 1280x720 -- capture shots=<dossier>`.

## Règles communes (les deux lots)
- Méthode **C7a/C7c** à l'identique (`art/tools/monsters/c7a_build.py`, `_c7c.txt`, `c7c_build.py`) ; DA
  `art/briefs/STYLE.md` en tête + `STYLE_boss_da.md` ; références : ash_lord_build.py, planche `_c7a_contact.png`
  (Éclusier). PBR usé, palette sombre désaturée, **un seul accent émissif : cyan d'eau doux `#5EC8FF`** (biome
  Terrasses noyées : rizières, pierre moussue, bronze vert-de-gris, fin d'après-midi), silhouettes anguleuses,
  jamais cartoon. Caméra iso du jeu (Design_Isometrique), Eevee à échantillons modestes, rendu ×2 puis LANCZOS,
  film transparent.
- **Lisibilité de nuit (leçon du Sonneur, OBLIGATOIRE)** : albédo moyen du corps **≥ 90/255** (L* ≥ 60 sur les
  masses principales), **liseré de lumière froide haut-gauche** (rim) sur toute la silhouette ; vérifier le
  contraste sur un fond de rizière sombre `#3A4038` dans la planche de contrôle. L'Éclusier, plus sombre, est
  relevé en jeu par `self_modulate` : ne pas compter là-dessus. L'accent va dans `_e` (EmissiveOverlay).
- **Cellules à la taille réelle d'affichage**, planches **≤ 4096 px** de côté : lignes = directions `e, s, w, n`
  (ordre fixe), colonnes = frames. Corps : cellule **256 × 256**, pieds sur la ligne `bottom` de fauna.json
  (Bouvier y = 210, Porteuse y = 215), grande dimension de la silhouette ≈ `dim` (180 / 170 px) ; le code met
  l'échelle et le pivot d'après ces trois valeurs (à recaler dans fauna.json si la planche change).
- Chaque PNG livré avec `<f>_n.png` (normales espace écran, fond (128,128,255,0)) et `<f>_e.png` (émission seule),
  même découpage. SpriteFrames texte `<id>.tres` (AtlasTexture), 12 fps (walk 14 fps), boucle seulement idle/walk
  et les extras marqués « boucle ».
- **Frame d'impact = moitié de l'anim** (auto : frame 3 sur 6 ; spell_a/b : frame 4 sur 8) — c'est là que le code
  applique les dégâts (EnemyVisual.BOSS_IMPACT_FRAC). Le geste doit culminer exactement sur cette frame.
- Extras « sol » : vus de dessus (caméra orthographique verticale), **1 u = 64 px**, le jeu les écrase en iso.
  Extras « billboard » : caméra iso du jeu, pied sur la ligne indiquée, centrés en x.
- Vérification : `godot --headless --path game res://tests/sprites_test.tscn` puis le test du boss
  (`ox_herder_boss_test` / `jar_bearer_boss_test`) et `floor1_boss_test` → RESULT: OK ; planche
  `art/tools/night/_<lot>_contact.png` avec l'Éclusier à la même échelle.
  Aucun .gd/.tscn ; ne jamais toucher user://run_save.json, settings.cfg, ni un .blend hors `art/blender/`.

---

<a id="bouvier"></a>
## Lot N1c — Le Bouvier (`ox_herder`, boss d'étage 1, Terrasses noyées)

Consigne Codex (à copier dans `_n1c.txt`, effort `medium`) :

> LOT N1C : boss d'étage 1 « ox_herder » (Le Bouvier), modèle neuf selon la méthode C7a/C7c (lis
> art/tools/monsters/c7a_build.py, art/tools/night/_c7c.txt et art/tools/night/requests_bosses1.md section Bouvier,
> qui fait foi pour les noms, cellules et frames). Biome Terrasses noyées : rizières, pierre moussue, bronze
> vert-de-gris, eau cyan #5EC8FF. Sortie game/assets/sprites/bosses/etage/ox_herder/ (ox_herder.tres + planches +
> _n/_e), source art/blender/bosses/ox_herder_iso.blend, script art/tools/night/n1c_build.py. Lisibilité de nuit
> obligatoire (albédo ≥ 90/255, rim froid). Périmètre : ces fichiers seulement. Vérification : sprites_test,
> ox_herder_boss_test et floor1_boss_test -> RESULT: OK, planche _n1c_contact.png (avec l'Éclusier). Le joueur dort :
> décide toi-même dans l'esprit de la DA et SURPRENDS. Rapport court en français.

**Concept** : **buffle d'eau de pierre** de **3,4 u** de long (bête basse et massive, plus longue que haute),
taillé dans une pierre de rizière moussue claire (`#8E907F` → `#B2B3A0`, mousse `#6F7E55` dans les creux), corps
fait de blocs ajustés comme un mur de terrasse (joints sombres, éclats). **Harnais de bronze vert-de-gris**
(collier, sangles rivetées, joug cassé sur le garrot dont pend une chaîne). **Cornes-ancres** : deux ancres de
bronze recourbées à la place des cornes (verge + bras + pattes), la silhouette se lit à ces deux crochets.
Accent unique : **l'eau cyan `#5EC8FF`** qui suinte des naseaux, des yeux et des joints du harnais (dans `_e`),
sabots toujours dans 2 cm d'eau (éclaboussures). Évite le taureau de corrida : c'est un animal de labour,
patient, lourd — le danger vient de sa masse.
Phases visibles : **p1** propre, eau qui suinte doucement ; **p2** « attelage » : le joug cassé traîne une herse
de bronze (dents qui labourent l'eau), filets d'eau plus forts, une corne fendue ; **p3** « embourbé » : boue
jusqu'aux genoux, pierre fissurée d'où jaillit l'eau sous pression, souffle de vapeur froide.

| anim | frames | dirs | notes |
|---|---|---|---|
| idle_p1, idle_p2, idle_p3 | 6 (boucle) | e,s,w,n | respiration lourde, la tête balance, eau qui goutte des naseaux |
| walk_p1, walk_p2, walk_p3 | 8 (boucle, 14 fps) | e,s,w,n | pas lourds ; sert aussi à la **ruée** (le code l'accélère) : prévoir une foulée lisible même rapide |
| auto | 6 | e,s,w,n | **coup de cornes** (cône 70°, 2,8 u) : tête baissée puis relevée en crochet, **impact frame 3** |
| spell_a | 8 | e,s,w,n | **Charge** : gratte le sol 2 fois, tête basse, cornes en avant, **impact frame 4** = départ de la ruée |
| spell_b | 8 | e,s,w,n | **Piétinement** : se cabre puis retombe des deux antérieurs, **impact frame 4** (onde de 2 à 6 u) |
| trans_p2 | 8 | s | arrache le joug, la herse tombe derrière lui |
| trans_p3 | 8 | s | les pattes s'enfoncent, la pierre se fend, l'eau jaillit |
| bogged | 6 (boucle) | s | **embourbé** (pose tenue 5,5 s, `play_special(&"bogged")`) : enfoncé jusqu'au poitrail, se débat, eau et boue qui giclent |
| death | 10 | s | s'effondre sur le flanc, les blocs se disjoignent, l'eau s'écoule et s'éteint |

Extras (dans le même `ox_herder.tres`, mêmes conventions `_n`/`_e`) :

| nom | type | cellule | frames | utilisation par le code |
|---|---|---|---|---|
| `furrow` | sol | 512 × 64 (8 × 1 u), **sillon d'eau vers +x**, départ au bord gauche, bords de terre retournée, eau cyan sombre au fond | 4 (boucle, frémissement) | posé le long de chaque ruée (étiré à sa longueur et à 1,6 u de large, `centered = false`, décalé de −32 px en y) ; ralentit ; reste après la mort |
| `stomp_ring` | sol | 256 × 256, onde de choc boue + eau de **rayon extérieur 124 px**, trou net au centre | 6 (non bouclé) | piétinement, `scale = 6 u / 124` |
| `mud_wave` | sol | 704 × 96 (11 × 1,5 u), **vague de boue vers +x**, départ au bord gauche | 8 (boucle) | phase 3 : 2 vagues qui tournent autour de lui (`centered = false`, −48 px en y) |
| `dust_burst` | billboard | 128 × 128, gerbe de boue/eau qui retombe, **sol à y = 82**, gerbe sur toute la largeur | 6 (non bouclé) | arrivée de ruée, mur percuté, piétinement, transitions |

Sons (Codex audio, `art/tools/audio/`) : `enemy.ox_snort.medium` (souffle d'eau par les naseaux, avant la charge),
`enemy.ox_charge.heavy` (galop de pierre dans l'eau), `enemy.ox_stomp.heavy` (choc sourd + gerbe),
`enemy.mud_suck.medium` (enlisement, succion). Le code utilise aujourd'hui `enemy.shockwave.heavy`,
`enemy.brute_cone.heavy`, `telegraph.boss.heavy`, `telegraph.warn_*`.

---

<a id="porteuse"></a>
## Lot N1d — La Porteuse de jarres (`jar_bearer`, boss d'étage 1, Terrasses noyées)

Consigne Codex (à copier dans `_n1d.txt`, effort `medium`) :

> LOT N1D : boss d'étage 1 « jar_bearer » (La Porteuse de jarres), modèle neuf selon la méthode C7a/C7c (lis
> art/tools/monsters/c7a_build.py, art/tools/night/_c7c.txt et art/tools/night/requests_bosses1.md section Porteuse,
> qui fait foi pour les noms, cellules et frames). Biome Terrasses noyées : pierre moussue, terre cuite, bronze,
> eau cyan #5EC8FF. Sortie game/assets/sprites/bosses/etage/jar_bearer/ (jar_bearer.tres + planches + _n/_e), source
> art/blender/bosses/jar_bearer_iso.blend, script art/tools/night/n1d_build.py. Lisibilité de nuit obligatoire
> (albédo ≥ 90/255, rim froid). Périmètre : ces fichiers seulement. Vérification : sprites_test,
> jar_bearer_boss_test et floor1_boss_test -> RESULT: OK, planche _n1d_contact.png (avec l'Éclusier et le
> Bouvier). Le joueur dort : décide toi-même dans l'esprit de la DA et SURPRENDS. Rapport court en français.

**Concept** : **esprit de lanterne de pierre** (tōrō des terrasses) de **3,0 u**, qui marche : socle à pattes
courtes de pierre, fût, **chambre du feu où brûle de l'eau cyan `#5EC8FF`** (accent unique, la lumière du boss,
dans `_e`), toit de pagode moussu aux coins relevés. Sur le dos, un **bât de bambou et de cordes** qui porte
**6 jarres de terre cuite** (`#A88060` → `#C49A74`, glaçure vert-de-gris coulée sur le col, sceaux de papier
délavés). Deux bras fins de pierre articulée. Elle est calme, cérémonielle : elle « offre » ses jarres.
Phases visibles : **p1** 6 jarres, foyer doux ; **p2** des jarres fêlées suintent une **vase verdâtre** (`#4C5A3C`)
le long du bât ; **p3** **lévitation** à 0,5 u du sol, le bât s'est ouvert, **4 jarres tournent autour d'elle**
(le code les fait tourner : NE PAS les peindre dans le corps en p3), foyer éclatant.

| anim | frames | dirs | notes |
|---|---|---|---|
| idle_p1, idle_p2, idle_p3 | 6 (boucle) | e,s,w,n | flamme d'eau qui danse ; p3 : en lévitation (balancement lent), 2 jarres seulement sur le bât |
| walk_p1, walk_p2, walk_p3 | 8 (boucle, 14 fps) | e,s,w,n | petits pas lourds, jarres qui s'entrechoquent ; p3 : glisse |
| auto | 6 | e,s,w,n | **jet de jarre** : décroche une jarre par-dessus l'épaule et la lance en cloche, **impact frame 3** (la jarre quitte la main) |
| spell_a | 8 | e,s,w,n | **Pluie de jarres** : bras levés, les jarres du bât s'envolent vers le ciel, **impact frame 4** |
| spell_b | 8 | e,s,w,n | **Jarre-mère** : décroche la grande jarre du bas et la pose devant elle, **impact frame 4** |
| trans_p2 | 8 | s | deux jarres se fêlent, la vase coule |
| trans_p3 | 8 | s | décolle du sol, le bât s'ouvre, 4 jarres se libèrent |
| death | 10 | s | la flamme d'eau s'éteint, la lanterne retombe et se fend, les jarres restantes roulent |

Extras (dans `jar_bearer.tres`) :

| nom | type | cellule | frames | utilisation par le code |
|---|---|---|---|---|
| `jar` | billboard | 64 × 64, jarre en vol (≈ 64 px de large), centrée | 8 (boucle, rotation) | jarre lancée, jarre de la pluie qui tombe, jarres en orbite (P3, ×1,1) |
| `jar_shatter` | billboard | 128 × 128, jarre qui éclate : tessons + gerbe d'eau, **sol à y = 82**, ≈ 96 px de large | 6 (non bouclé) | chaque jarre brisée (auto, pluie, jarre-mère) |
| `mother_jar` | billboard | 128 × 128, **grande jarre scellée** ≈ 72 px de large, **base à y = 112**, sceaux qui s'allument (cyan) de plus en plus vite | 6 (boucle) | jarre-mère posée (3 s avant l'explosion, cassable) |
| `puddle` | sol | 128 × 128 (2 u), **flaque de vase** verdâtre, reflets d'eau, bord net | 4 (boucle) | dès la phase 2, sous chaque jarre brisée (7 s ; ralentit ; reste après la mort) |

Sons : `enemy.jar_throw.light` (souffle + tintement de terre cuite), `enemy.jar_break.medium` (terre cuite qui
éclate + éclaboussure), `enemy.mother_jar_tick` (sceaux qui grésillent, accélère), `enemy.mother_jar_blast.heavy`,
`enemy.jar_orbit` (bourdonnement de jarres en rotation, boucle). Le code utilise aujourd'hui
`enemy.shockwave.heavy`, `telegraph.boss.heavy`, `telegraph.warn_*`.
