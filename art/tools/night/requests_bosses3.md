# Demandes d'art — boss de l'étage 3 (Cité de rouille) : la Grue et le Fondeur

Code intégré le 22/10/2026 (aucun lot lancé) : `game/scripts/enemies/crane_brain.gd` (+ `crane_yard.gd`,
`crane_fx.gd`), `smelter_brain.gd` (+ `smelter_slag.gd`, `smelter_fx.gd`), tests `crane_boss_test` /
`smelter_boss_test`. `*_fx.gd` = formes dessinées PROVISOIRES. Tant que rien n'est livré, le jeu affiche ces
silhouettes ; **chaque fichier ci-dessous se branche seul** dès qu'il existe (chemins et noms d'anims enregistrés dans
`game/data/fauna.json` → `boss_sprites.crane` / `boss_sprites.smelter`). Ne rien renommer.
Captures de référence (placeholders) : lancer les tests sans `--headless` avec `-- capture shots=<dossier>`.

## Règles communes (les deux lots)
- Méthode **C7c** (le Sonneur, même étage) à l'identique (`_c7c.txt`, `c7c_build.py`, `_c7c_contact.png`) ; DA
  `art/briefs/STYLE.md` en tête + `STYLE_boss_da.md` ; références : ash_lord_build.py, rust_archon. PBR usé : tôle
  et fonte rouillées, béton écaillé, rivets, câbles gainés de suie, coulures d'huile ; palette sombre désaturée ;
  **un seul accent émissif : orange de lampe au sodium `#FF9A3C`** (comme les monstres `_rust`, lot N3E) ;
  silhouettes anguleuses, jamais cartoon. Thème partagé avec le Sonneur : **crépuscule d'orage**, pluie, foudre (le
  code réutilise déjà la foudre du Sonneur : `lightning`, `ground_lightning`, `ground_scorch`, `steam_vent`,
  `ground_steam` de `sonneur.tres` ; ne pas les refaire). Caméra iso du jeu (Design_Isometrique), Eevee à
  échantillons modestes, rendu ×2 puis LANCZOS, film transparent.
- **Lisibilité de nuit (leçon du Sonneur, OBLIGATOIRE)** : le Sonneur rendu à ~40/255 d'albédo moyen restait noir en
  jeu malgré une lumière ×6 (le code le compense par `self_modulate`). Ici : albédo moyen du corps **≥ 90/255**
  (rouille claire `#9A5A3A` → `#B87A52`, acier `#7A746C`, jamais plus sombre sur les masses), **liseré de lumière
  froide haut-gauche** (rim) sur toute la silhouette ; vérifier le contraste sur un fond de sol de la cité
  (`art/tools/night/_f3_contact.png`) dans la planche de contrôle. L'accent va dans `_e` (EmissiveOverlay).
- **Cellules à la taille réelle d'affichage**, planches **≤ 4096 px** de côté : lignes = directions `e, s, w, n`
  (ordre fixe), colonnes = frames. Corps : cellule **256 × 256**, pieds sur la ligne `bottom` de fauna.json (y = 215),
  grande dimension ≈ `dim` (Grue 195 px, Fondeur 185 px) ; le code met l'échelle et le pivot d'après ces valeurs.
- Chaque PNG livré avec `<f>_n.png` (normales espace écran, fond (128,128,255,0)) et `<f>_e.png` (émission seule),
  même découpage. SpriteFrames texte `<id>.tres` (AtlasTexture), 12 fps (walk 14 fps), boucle seulement idle/walk et
  les extras marqués « boucle ».
- **Frame d'impact = moitié de l'anim** (auto : frame 3 sur 6 ; spell_a/b : frame 4 sur 8) — c'est là que le code
  applique les dégâts (EnemyVisual.BOSS_IMPACT_FRAC). Le geste doit culminer exactement sur cette frame.
- Extras « sol » : vus de dessus (caméra orthographique verticale), **1 u = 64 px**, le jeu les écrase en iso.
  Extras « billboard » : caméra iso du jeu, **1 u = 90,5 px** (Iso.RENDER_PX_PER_U), pied au bas utile indiqué.
- Vérification : `godot --headless --path game res://tests/sprites_test.tscn` puis le test du boss
  (`crane_boss_test` / `smelter_boss_test`) → RESULT: OK ; planche `art/tools/night/_<lot>_contact.png`.
  Aucun .gd/.tscn ; ne jamais toucher user://run_save.json, settings.cfg, ni un .blend hors `art/blender/`.

---

<a id="grue"></a>
## Lot C9a — La Grue (`crane`, boss d'étage 3, Cité de rouille)

Consigne Codex (à copier dans `_c9a.txt`, effort `medium`) :

> LOT C9A : boss d'étage 3 « crane » (La Grue), modèle neuf selon la méthode C7c (lis art/tools/night/_c7c.txt,
> c7c_build.py et art/tools/night/requests_bosses3.md section Grue, qui fait foi pour les noms, cellules et frames).
> Cité de rouille : tôle rivetée rouillée, acier, béton, lampe au sodium #FF9A3C, pluie d'orage. Sortie
> game/assets/sprites/bosses/etage/crane/ (crane.tres + planches + _n/_e), source art/blender/bosses/crane_iso.blend,
> script art/tools/night/c9a_build.py. Lisibilité de nuit obligatoire (albédo ≥ 90/255, rim froid). Périmètre : ces
> fichiers seulement. Vérification : sprites_test et crane_boss_test -> RESULT: OK, planche _c9a_contact.png.
> Le joueur dort : décide toi-même dans l'esprit de la DA et SURPRENDS. Rapport court en français.

**Concept** : automate-grue de **3,8 u** sur **chenilles** de chantier, caisse-moteur rivetée, **cabine vitrée
éclairée de l'intérieur** (lampe au sodium, l'accent), mât en treillis, **flèche articulée** en treillis qui porte
un **crochet** au bout d'un câble ; gyrophare-lampe au sodium au sommet du mât ; plaques de tôle peintes d'origine
(jaune de chantier délavé presque effacé sous la rouille, numéro de série au pochoir). Silhouette : une masse basse
et large + une grande diagonale (la flèche) qui DOIT rester lisible dans les 4 directions.
Phases visibles : **p1** flèche basse, crochet qui se balance ; **p2** contrepoids fendu qui laisse fuir de la
vapeur, câbles qui sifflent, lampes plus vives ; **p3** **ancrée** : 4 patins d'ancrage plantés dans le béton
(éclats au sol), **flèche dressée à la verticale** comme un paratonnerre, arcs électriques ambrés qui courent le
long du treillis (dans `_e`).

| anim | frames | dirs | notes |
|---|---|---|---|
| idle_p1, idle_p2, idle_p3 | 6 (boucle) | e,s,w,n | p3 : ancrée, flèche dressée, arcs qui crépitent |
| walk_p1, walk_p2, walk_p3 | 8 (boucle, 14 fps) | e,s,w,n | chenilles ; p3 : sur place (ancrée, le code ne la déplace plus), cabine qui pivote |
| auto | 6 | e,s,w,n | **crochet** : la flèche se tend et projette le crochet en ligne droite (1 × 6 u), **impact frame 3** |
| spell_a | 8 | e,s,w,n | **lâcher de conteneur** : la flèche pivote vers le haut, le crochet s'ouvre, **impact frame 4** (le conteneur touche le sol à ce moment) |
| spell_b | 8 | e,s,w,n | **balayage** : la flèche s'abaisse et part en rotation, **impact frame 4** (début du balayage de 90°) |
| trans_p2 | 8 | s | le contrepoids se fend, jet de vapeur |
| trans_p3 | 8 | s | patins plantés (choc), la flèche se dresse, premier arc |
| death | 10 | s | la flèche plie et s'effondre, la cabine s'éteint en dernier |

Extras (dans le même `crane.tres`, mêmes conventions `_n`/`_e`) :

| nom | type | cellule | frames | utilisation par le code |
|---|---|---|---|---|
| `container` | billboard | 256 × 256, conteneur de fret rouillé de **2 u** de côté au sol, 1,4 u de haut, posé en losange sur la grille iso, pied (centre de la base) à **y 224** ; petite lampe au sodium sur un angle | 4 variantes (1 par frame, non bouclé : le code tire une frame) | obstacle de 8 s ; échelle `Iso.SPRITE_K × UNSQUASH`, décalé de −96 px ; la lampe clignote avant disparition (le code module l'énergie) |
| `boom_shadow` | sol | 896 × 96 (14 u × 1,5 u), ombre portée de la flèche en treillis **vers +x**, départ au bord gauche, petite lampe au bout | 4 (boucle) | balayage : tourne de 90° autour de la Grue (le code décale de +448 px) |
| `arc` | sol | 448 × 64, arc électrique ambre-blanc **vers +x** (zigzag), départ au bord gauche | 6 (boucle) | phase 3 : arcs de tempête entre conteneurs, étirés à la longueur (`scale.x = L / 448`) |
| `dust` | sol | 192 × 192, anneau de poussière et d'éclats de béton (impact d'un conteneur, cercle de 3 u) | 6 (non bouclé) | à chaque conteneur posé (échelle 1) |

---

<a id="fondeur"></a>
## Lot C9b — Le Fondeur (`smelter`, boss d'étage 3, Cité de rouille)

Consigne Codex (à copier dans `_c9b.txt`, effort `medium`) :

> LOT C9B : boss d'étage 3 « smelter » (Le Fondeur), modèle neuf selon la méthode C7c (lis art/tools/night/_c7c.txt,
> c7c_build.py et art/tools/night/requests_bosses3.md section Fondeur, qui fait foi pour les noms, cellules et
> frames). Cité de rouille : fonte rouillée, briques réfractaires, métal en fusion orange sodium #FF9A3C (seul
> émissif), pluie d'orage. Sortie game/assets/sprites/bosses/etage/smelter/ (smelter.tres + planches + _n/_e),
> source art/blender/bosses/smelter_iso.blend, script art/tools/night/c9b_build.py. Lisibilité de nuit obligatoire
> (albédo ≥ 90/255, rim froid). Périmètre : ces fichiers seulement. Vérification : sprites_test et
> smelter_boss_test -> RESULT: OK, planche _c9b_contact.png. Le joueur dort : décide toi-même dans l'esprit de la DA
> et SURPRENDS. Rapport court en français.

**Concept** : automate-forge trapu de **3,5 u**, jambes courtes et massives, **creuset ouvert à la place du torse**
(bol de fonte cerclé et riveté, garni de briques réfractaires, rempli de **métal en fusion** = l'accent : la lumière
monte de la bouche du creuset et éclaire le dessous des bras), **deux bras-louches** (longs bras articulés terminés
par des louches), cheminée-évent dans le dos qui crache des étincelles ; coulures de métal figé sur le ventre ; la
pluie qui frappe le creuset fume. Silhouette en coupe évasée, large en haut.
Phases visibles : **p1** creuset à demi plein, braises ; **p2** le creuset déborde : coulures vives sur les flancs,
cerclages chauffés au rouge sombre ; **p3** **surchauffe** : fonte rougie par plaques (dans `_e`, reste dans l'orange
sodium, jamais un second ton), métal du creuset presque blanc, fissures lumineuses, vapeur d'orage tout autour.

| anim | frames | dirs | notes |
|---|---|---|---|
| idle_p1, idle_p2, idle_p3 | 6 (boucle) | e,s,w,n | métal qui bouillonne ; p3 : vapeur et fissures qui pulsent |
| walk_p1, walk_p2, walk_p3 | 8 (boucle, 14 fps) | e,s,w,n | pas lourds, le métal tangue dans le creuset |
| auto | 6 | e,s,w,n | **louche** : coup de louche en arc (cône 80°, 3 u) qui projette du métal, **impact frame 3** |
| spell_a | 8 | e,s,w,n | **coulée** : le Fondeur bascule son creuset vers l'avant, **impact frame 4** (le métal touche le sol) |
| spell_b | 8 | e,s,w,n | **étincelles** : la cheminée crache, les louches s'entrechoquent, **impact frame 4** (l'éventail part) |
| trans_p2 | 8 | s | le creuset déborde tout autour (le code pose l'anneau juste après) |
| trans_p3 | 8 | s | surchauffe : la fonte rougit, un cerclage saute |
| death | 10 | s | se fige : le métal refroidit du blanc au noir, le creuset se fend |

Extras (dans le même `smelter.tres`, mêmes conventions `_n`/`_e`) :

| nom | type | cellule | frames | utilisation par le code |
|---|---|---|---|---|
| `molten_pool` | sol | 768 × 128 (12 u × 2 u), coulée de métal en fusion **vers +x** (départ au bord gauche), bords de croûte sombre, cœur orange | 6 (boucle) | flaque de 5 s (et après la mort tant que la charge dure) ; étirée à la longueur réelle (`scale.x = L / 768`, la coulée s'arrête au mur) |
| `splash` | billboard | 192 × 256, gerbe de métal en fusion, pied à **y 224** | 6 (non bouclé) | impact de louche et de coulée |

Anneau de débordement (P2) : **aucun sprite demandé** pour l'instant (dessiné par le code, morceaux d'arc avec deux
brèches éclairées) ; si tu as du temps, livre `molten_arc` (sol, 128 × 128, tronçon de métal en fusion courbe de 1,2 u
d'épaisseur sur un arc de rayon 5 u, 6 frames en boucle) : le code saura le poser le long de l'anneau dans un second
temps (le signaler dans le rapport).
