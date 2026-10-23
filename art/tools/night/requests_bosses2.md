# Demandes d'art — boss d'étage 2 alternatifs (Tisseuse, Cèdre-Ermite)

Code intégré le 22/10/2026 (aucun lot lancé par Claude) : `game/scripts/enemies/weaver_brain.gd`,
`hermit_cedar_brain.gd` (+ `weaver_fx.gd` = formes dessinées PROVISOIRES des deux boss, `weaver_snare.gd` = fils,
toile, cocons et souches au sol), tests `weaver_boss_test` / `hermit_cedar_boss_test`. Tant que rien n'est livré,
le jeu affiche des silhouettes et effets dessinés ; **chaque fichier ci-dessous se branche seul** dès qu'il existe
(chemins et noms d'anims enregistrés dans `game/data/fauna.json` → `boss_sprites.weaver` /
`boss_sprites.hermit_cedar`). Ne rien renommer.
Captures de référence (placeholders) : lancer les tests sans `--headless` avec
`--resolution 1280x720 -- capture shots=<dossier>`.

**Lots N2c / N2d déjà en file** (`_n2c.txt`, `_n2d.txt`, consignes génériques « extras de son design ») : s'ils
livrent le corps sans ces extras, le code garde ses replis pour les extras manquants. Noms acceptés par le code
(premier trouvé) : `thread` | `silk` | `silk_thread` ; `cocoon` ; `drop_dust` | `dust` | `land_dust` ;
`root_spike` | `roots` | `root_line` | `root_burst` ; `spore_cloud` | `spores` ; `stump` | `root_stump` ; corps
spéciaux `ascend_s`, `drop_s`, `lay_s`. Un lot complémentaire (N2c2 / N2d2, effort `low`) ne fait que les extras
manquants dans le même `.tres`.

## Règles communes (les deux lots)
- Méthode **C7b** à l'identique (`_c7b.txt`, Cerf : même biome, même accent, référence de lisibilité) ; DA
  `art/briefs/STYLE.md` en tête + `STYLE_boss_da.md` ; références : ash_lord_build.py, `_c7b_contact.png`. PBR usé,
  palette sombre désaturée, **un seul accent émissif : feu follet menthe `#9CF0C8`**, brume `#B8C8C0` dans les
  matières (lichen, soie, écorce pâlie), silhouettes anguleuses, jamais cartoon, malsain par la forme.
- **Lisibilité de nuit (leçon du Sonneur, OBLIGATOIRE)** : albédo moyen du corps **≥ 90/255**, **liseré de lumière
  froide haut-gauche** sur toute la silhouette ; sol de la forêt `#3E4A3F`→`#55634E` sous l'heure bleue
  (`CanvasModulate #8FA3A8`) : vérifier le contraste du corps sur `#3E4A3F` dans la planche de contrôle. L'accent
  va dans `_e` (le code l'allume via EmissiveOverlay).
- **Cellules à la taille réelle d'affichage**, planches **≤ 4096 px** de côté (découper en plusieurs atlases ;
  `python art/tools/texture_budget.py` sans ligne « > 4096 »), lignes = directions `e, s, w, n`, colonnes = frames.
  Corps : cellule **256 × 256**, pieds sur la ligne `bottom` de fauna.json (Tisseuse y = 210, Cèdre y = 220),
  grande dimension ≈ `dim` (180 / 190 px) ; à recaler dans fauna.json si la planche change.
- Chaque PNG avec `<f>_n.png` (normales espace écran, fond (128,128,255,0)) et `<f>_e.png` (émission seule),
  même découpage. SpriteFrames texte `<id>.tres` (AtlasTexture), 12 fps (walk 14 fps), boucle seulement idle/walk
  et les extras marqués « boucle ».
- **Frame d'impact = moitié de l'anim** (auto : frame 3 sur 6 ; spell_a/b : frame 4 sur 8) : le code y applique
  les dégâts (EnemyVisual.BOSS_IMPACT_FRAC). Le geste culmine exactement sur cette frame.
- Extras « sol » : vus de dessus, **1 u = 64 px**, le jeu les écrase en iso. Extras « billboard » : caméra iso du jeu,
  **1 u = 90,5 px**, pied au bas de la cellule, centrés en x.
- Vérification : `godot --headless --path game res://tests/sprites_test.tscn` puis le test du boss → RESULT: OK ;
  planche `art/tools/night/_<lot>_contact.png`. Aucun .gd/.tscn ; jamais user://run_save.json, settings.cfg, ni un
  .blend hors `art/blender/`.

---

<a id="tisseuse"></a>
## Lot N2c — La Tisseuse (`weaver`, boss d'étage 2, Forêt-brume)

Consigne Codex (`_n2c.txt`, effort `medium`) : celle de la file + « requests_bosses2.md section Tisseuse fait foi
pour les noms, cellules et frames ».

**Concept** : araignée-sanctuaire de **3,3 u**, 8 pattes de **bois de cèdre poli par l'usage** (articulations
cerclées de bronze verdi, brins de soie collés), céphalothorax = petit autel de bois aux 4 yeux menthe ; **abdomen =
lanterne de sanctuaire fêlée** (cage de bois et papier huilé déchiré, flamme de feu follet menthe dedans : l'accent
unique, qui éclaire les pattes par en dessous), soie gris-brume qui pend en guirlandes. Phases visibles :
**p1** lanterne voilée, soie propre ; **p2** soie tendue partout (fils qui partent des filières vers le sol),
lanterne plus vive ; **p3** la lanterne se fend (éclats de papier, flamme qui fuit), œufs translucides menthe
collés sous l'abdomen, une patte cassée qui traîne.

| anim | frames | dirs | notes |
|---|---|---|---|
| idle_p1, idle_p2, idle_p3 | 6 (boucle) | e,s,w,n | pattes qui tâtent le sol |
| walk_p1, walk_p2, walk_p3 | 8 (boucle, 14 fps) | e,s,w,n | marche araignée, rapide |
| auto | 6 | e,s,w,n | **morsure** (cône 63°, 2,6 u) : se cabre, chélicères en avant, **impact frame 3** |
| spell_a | 8 | e,s,w,n | **fils** : abdomen relevé vers la cible, 3 jets de soie, **impact frame 4** ; sert aussi à la ponte si `lay_s` manque |
| spell_b | 8 | e,s,w,n | **départ de la descente** : se ramasse puis bondit vers le haut sur son fil, **impact frame 4** = pieds quittent le sol |
| ascend | 8 | s | se hisse sur le fil hors du cadre (dernière frame vide), joué à la place de spell_b s'il existe |
| drop | 8 | s | tombe du haut du cadre, **frame 4 = contact au sol** (pattes écartées, poussière) |
| lay | 8 | s | ponte : abdomen contre le sol, œufs (phase 3) |
| trans_p2 | 8 | s | tend sa toile (fils qui partent dans toutes les directions) |
| trans_p3 | 8 | s | la lanterne se fend, flamme qui jaillit |
| death | 10 | s | s'effondre pattes repliées, la lanterne s'éteint en dernier |

Extras (même `weaver.tres`) :

| nom | type | cellule | frames | utilisation par le code |
|---|---|---|---|---|
| `thread` | sol | 768 × 64 (12 u × 1 u), **fil de soie vers +x**, départ au bord gauche, perles de rosée menthe (`_e`) | 4 (boucle, vibration) | fils persistants : étiré à la longueur du fil, échelle y 0,8 |
| `cocoon` | billboard | 96 × 160, cocon de soie debout, cœur menthe qui palpite | 6 (boucle) | obstacles de 1 u (phase 3), 3 s avant éclosion |
| `drop_dust` | sol | 192 × 192 (cercle de 3 u), poussière + brins de soie qui s'écartent | 6 | impact de la chute |

| `web` | sol | anneau de 6 u de rayon qui **remplit sa cellule** (768 px = 12 u de diamètre), **2 brèches centrées à +x et −x** de la cellule (~3,6 u d'ouverture chacune) | 4 (boucle) | toile de phase 2 : le code la tourne pour aligner ses brèches sur les zones sans collision ; repli : anneau dessiné |

Échelles adaptées à la planche livrée : `drop_dust` et `spore_cloud` sont mis à l'échelle d'après la largeur de leur
cellule (la cellule = le cercle de l'effet : 3 u et 4 u) ; `root_spike` et `thread` d'après leur largeur (longueur
de la ligne) et leur hauteur (épaisseur 1 u / 0,8 u). La N2d en cours a choisi `spore_cloud` 512 px « 8 u » : le
nuage du jeu fait 4 u, il sera donc rendu à moitié (cellule = cercle de 4 u).

Sons : `enemy.silk_shot.medium` (jet de soie sifflant), `enemy.web_thrum.light` (corde de toile pincée, joue à la
vibration), `enemy.drop_slam.heavy`, `enemy.cocoon_hatch.light`. Le code utilise aujourd'hui `enemy.shockwave.heavy`,
`enemy.brute_cone.heavy`, `telegraph.*`.

---

<a id="cedre"></a>
## Lot N2d — Le Cèdre-Ermite (`hermit_cedar`, boss d'étage 2, Forêt-brume)

Consigne Codex (`_n2d.txt`, effort `medium`) : celle de la file + « requests_bosses2.md section Cèdre fait foi ».

**Concept** : tréant de **3,6 u**, vieux cèdre noyé : écorce gris-brun fibreuse **pâlie par le lichen couleur de
brume** (`#B8C8C0`, pas plus sombre que 90/255 en moyenne), **tronc fendu de haut en bas** qui abrite une **lanterne
d'ermite** (bronze, flamme menthe : accent unique, éclaire l'intérieur de la fente), bras-branches noueux aux
doigts de racines, pieds = racines qui traînent, cordes de prière effilochées et clochettes de bois. Phases :
**p1** fente à demi close ; **p2** **enraciné** : racines plantées dans le sol tout autour (pose large, basse),
fente grande ouverte sur la lanterne (c'est la fenêtre de burst : elle doit se lire) ; **p3** **déraciné** :
racines arrachées pleines de terre, tronc penché en avant, lanterne qui vacille, écorce qui pèle.

| anim | frames | dirs | notes |
|---|---|---|---|
| idle_p1, idle_p2, idle_p3 | 6 (boucle) | e,s,w,n | p2 : immobile planté (respiration de la lanterne seulement) |
| walk_p1, walk_p2, walk_p3 | 8 (boucle, 14 fps) | e,s,w,n | lent, lourd ; p2 peut copier idle_p2 (il ne marche pas) ; p3 : charge, penché |
| auto | 6 | e,s,w,n | **branche** en arc (cône 90°, 3,2 u), **impact frame 3** ; sert aussi à la vrille (P2) |
| spell_a | 8 | e,s,w,n | **racines** : plante les bras dans le sol, **impact frame 4** = les racines jaillissent ; sert à l'armement de la charge (P3) |
| spell_b | 8 | e,s,w,n | **spores** : le houppier s'ébroue, nuage de spores, **impact frame 4** |
| trans_p2 | 8 | s | s'enracine (racines qui plongent), la fente s'ouvre |
| trans_p3 | 8 | s | s'arrache du sol (mottes de terre) |
| death | 10 | s | s'effondre en souches, la lanterne roule et s'éteint |

Extras (même `hermit_cedar.tres`) :

| nom | type | cellule | frames | utilisation par le code |
|---|---|---|---|---|
| `root_spike` | sol | 512 × 64 (8 u × 1 u), **racines épineuses qui jaillissent le long de +x**, départ au bord gauche | 8 | racines (cage, râteau, vrille, échos des souches), étiré à la longueur de la ligne |
| `spore_cloud` | sol | 256 × 256 (cercle de 4 u), spores brume teintées menthe (`_e` léger) | 8 (boucle) | nuage de spores (2 s, réempoisonne) |
| `stump` | billboard | 96 × 128, souche fendue, sève menthe | 4 variantes (1 frame chacune ; le code tire une frame au hasard) | souches de la charge (obstacles 6 s) et de la mort (trace) |

Sons : `enemy.root_burst.heavy` (craquement de sol + bois), `enemy.spore_puff.medium` (souffle sourd),
`enemy.uproot.heavy` (déchirement de racines), `enemy.stump_answer.light` (claquement sec, pour l'écho des souches).
