# Demandes d'art — boss de l'étage 4 (suite) : Mère-Cristal et Anguille des profondeurs

Code intégré le 22/10/2026 (aucun lot lancé) : `game/scripts/enemies/crystal_mother_brain.gd`, `deep_eel_brain.gd`
(+ `recluse_fx.gd` = formes dessinées PROVISOIRES, `recluse_gloom.gd` étendu : pénombre et traces), tests
`crystal_mother_boss_test` / `deep_eel_boss_test` / `floor4_boss_test`. Tant que rien n'est livré, le jeu affiche des
silhouettes et effets dessinés ; **chaque fichier ci-dessous se branche seul** dès qu'il existe (chemins et noms
d'anims enregistrés dans `game/data/fauna.json` → `boss_sprites.crystal_mother` / `boss_sprites.deep_eel`).
Ne rien renommer. Tant que le `.tres` n'est pas livré, ces boss ne sont pas tirés en run (le plan garde le Reclus).
Captures de référence (placeholders) : `art/tools/night/_floor4_boss_captures/` (tests sans `--headless`,
`--resolution 1280x720 -- capture shots=<dossier>`).

## Règles communes (les deux lots)
- Méthode **C7b/C7c** à l'identique (`_c7b.txt`, `_c7c.txt`, `c7c_build.py`) et mêmes règles que le Reclus
  (`requests_bosses45.md`, section « Règles communes ») : DA `art/briefs/STYLE.md` en tête + `STYLE_boss_da.md`,
  PBR usé, palette sombre désaturée, silhouettes anguleuses, jamais cartoon, caméra iso du jeu, Eevee modeste,
  rendu ×2 puis LANCZOS, film transparent.
- **DA des Cryptes noyées** : pierre mouillée, sel cristallisé, os, eau noire ; **un seul accent émissif :
  cristal blanc-cyan `#BFF4FF`** (dans `_e`, le code l'allume via EmissiveOverlay). Aucune autre couleur lumineuse.
- **Lisibilité de nuit (leçon du Sonneur, OBLIGATOIRE)** : albédo moyen du corps **≥ 90/255** (L* ≥ 60 sur les
  masses), chroma +20 %, **liseré froid haut-gauche** sur toute la silhouette, contraste vérifié sur fond `#2E3238`
  dans la planche de contrôle. L'eau noire (`black_pool`, `puddle`) est la seule grande masse sombre : son bord
  doit garder un liseré clair (reflet cristal) pour être lu au sol.
- **Cellules à la taille réelle d'affichage**, planches **≤ 4096 px** : lignes = directions `e, s, w, n`,
  colonnes = frames. Corps : cellule **256 × 256**, pieds sur `bottom` de fauna.json (Mère y = 215, Anguille
  y = 210), grande dimension ≈ `dim` (180 / 195 px). Recaler fauna.json si la planche change.
- Chaque PNG avec `<f>_n.png` (normales espace écran, fond (128,128,255,0)) et `<f>_e.png` (émission seule).
  SpriteFrames texte `<id>.tres` (AtlasTexture), 12 fps (walk 14 fps), boucle seulement idle/walk et les extras
  marqués « boucle ».
- **Frame d'impact = moitié de l'anim** (auto : frame 3 sur 6 ; spell_a/b : frame 4 sur 8) : le geste culmine là.
- Extras « sol » : vus de dessus, **1 u = 64 px**, le jeu les écrase en iso. Extras « billboard » : caméra iso du
  jeu, **1 u = 90,5 px**, pied au bas de la cellule, centrés en x.
- Vérification : `godot --headless --path game res://tests/sprites_test.tscn`, puis le test du boss et
  `floor4_boss_test` → RESULT: OK ; planche `art/tools/night/_<lot>_contact.png`. Aucun .gd/.tscn ; ne jamais
  toucher user://run_save.json, settings.cfg, ni un .blend hors `art/blender/`.

---

<a id="mere"></a>
## Lot C8c — La Mère-Cristal (`crystal_mother`, boss d'étage 4)

Consigne Codex (à copier dans `_c8c.txt`, effort `medium`) :

> LOT C8C : boss d'étage 4 « crystal_mother » (La Mère-Cristal), modèle neuf selon la méthode C7c (lis
> art/tools/night/_c7c.txt, c7c_build.py et art/tools/night/requests_bosses4.md section Mère-Cristal, qui fait foi
> pour les noms, cellules et frames). Cryptes noyées : sel cristallisé, pierre mouillée, os, cristal blanc-cyan
> #BFF4FF seul accent émissif. Sortie game/assets/sprites/bosses/etage/crystal_mother/ (crystal_mother.tres +
> planches + _n/_e), source art/blender/bosses/crystal_mother_iso.blend, script art/tools/night/c8c_build.py.
> Lisibilité de nuit obligatoire (albédo ≥ 90/255, rim froid). Périmètre : ces fichiers seulement. Vérification :
> sprites_test, crystal_mother_boss_test et floor4_boss_test -> RESULT: OK, planche _c8c_contact.png. Le joueur
> dort : décide toi-même dans l'esprit de la DA et SURPRENDS. Rapport court en français.

**Concept** : amas de cristal de sel de **3,4 u** à **silhouette féminine** (une madone de géode) : robe de
grands prismes laiteux (`#9AA6AC` → `#C9D3D6`, jamais plus sombre), buste de sel strié, tête = couronne de pointes
sans visage ; **6 bras-stalactites** qui pendent des épaules (3 par côté, longs, pointus, translucides) ; au centre
de la poitrine un **cœur-géode blanc-cyan `#BFF4FF`** (accent émissif unique, qui éclaire les prismes par
l'intérieur) ; os et coquilles pris dans le sel à la base, flaque d'eau noire aux pieds.
Phases visibles : **p1** cristal laiteux, cœur voilé ; **p2** des veines de lumière courent dans les prismes
(`_e`), le cœur grossit, quelques prismes s'allument comme des lampes ; **p3** **éclatée** : les prismes de la robe
s'écartent du corps (vides entre eux, le cœur visible à travers), 8 éclats flottent autour (ceux du jeu sont
dessinés à part : `orbit_shard`), couronne fendue.

| anim | frames | dirs | notes |
|---|---|---|---|
| idle_p1, idle_p2, idle_p3 | 6 (boucle) | e,s,w,n | p3 : facettes qui respirent (écart qui pulse) |
| walk_p1, walk_p2, walk_p3 | 8 (boucle, 14 fps) | e,s,w,n | glisse lourdement, la robe racle le sol (pas de jambes visibles) |
| auto | 6 | e,s,w,n | **éclat** : un bras-stalactite se tend et décoche un éclat vers la direction, **impact frame 3** |
| spell_a | 8 | e,s,w,n | **stalactites** : les 6 bras se lèvent puis s'abaissent d'un coup, **impact frame 4** (les stalactites tombent du plafond) |
| spell_b | 8 | e,s,w,n | **prisme** : le cœur se concentre puis tire un rayon droit devant, **impact frame 4** |
| trans_p2 | 8 | s | les veines s'allument (les cristaux de l'arène s'éteignent en même temps : elle boit leur lumière) |
| trans_p3 | 8 | s | se fend et s'éclate : les prismes de la robe s'écartent, éclats projetés |
| death | 10 | s | le cœur se fêle, les prismes tombent en pluie de sel, le cœur s'éteint en dernier |

Extras (même `crystal_mother.tres`, mêmes conventions `_n`/`_e`) :

| nom | type | cellule | frames | utilisation par le code |
|---|---|---|---|---|
| `crystal_block` | billboard | 128 × 192, bloc-prisme de cristal de **1 u** de large, ~1,3 u de haut, cœur lumineux | 6 (boucle, scintillement lent) | bloc laissé par chaque stalactite (6-8 s) ; pied au bas de la cellule (décalage −96 px) |
| `stalactite` | billboard | 128 × 384, stalactite qui tombe du haut de la cellule et se plante (éclats au sol à la dernière frame) | 6 | chute sur chaque cercle de 1,5 u (pied au bas, décalage −192 px) |
| `shard` | sol | 64 × 32, éclat de cristal **vers +x** (pointe à droite), traînée lumineuse | 4 (boucle) | projectile de l'auto (1 u), orienté par le code |
| `prism_beam` | sol | 1024 × 96 (16 u × 1,5 u), rayon de cristal **vers +x**, départ au bord gauche | 6 (boucle) | prisme et lignes réfractées (le code décale de +512 px et étire en x à la longueur réelle) |
| `orbit_shard` | billboard | 64 × 96, éclat flottant qui tourne sur lui-même | 8 (boucle) | phase 3 : 8 éclats en orbite à 2,6 u (décalage −48 px) |
| `lamp_glow` | sol | 256 × 256, halo de lumière blanc-cyan au sol, **rayon 128 px**, très doux, bord net discret | 8 (boucle, pulsation lente) | phase 2+ : zone de lampe autour de chaque bloc (échelle = 2,2 u / 128 px) |
| `reflect_burst` | billboard | 192 × 384, gerbe de cristal qui jaillit du sol (la Mère ressort d'un bloc) | 6 | « Reflet » et éclats d'impact (pied au bas, décalage −192 px) |

Sons (Codex audio, `art/tools/audio/`) : `enemy.crystal_shard.medium` (tintement sec qui file), `enemy.stalactite_fall.heavy`
(craquement de voûte puis impact cristallin), `enemy.prism_beam.heavy` (accord de verre qui monte puis claque),
`amb.crystal_drink` (les cristaux de l'arène qui s'éteignent en aspiration). Le code utilise aujourd'hui
`enemy.shot.medium`, `enemy.shockwave.heavy`, `telegraph.*`.

---

<a id="anguille"></a>
## Lot C8d — L'Anguille des profondeurs (`deep_eel`, boss d'étage 4)

Consigne Codex (à copier dans `_c8d.txt`, effort `medium`) :

> LOT C8D : boss d'étage 4 « deep_eel » (L'Anguille des profondeurs), modèle neuf selon la méthode C7c (lis
> art/tools/night/_c7c.txt, c7c_build.py et art/tools/night/requests_bosses4.md section Anguille, qui fait foi pour
> les noms, cellules et frames). Cryptes noyées : écailles de sel, eau noire, os, lueur interne blanc-cyan #BFF4FF
> seul accent émissif. Sortie game/assets/sprites/bosses/etage/deep_eel/ (deep_eel.tres + planches + _n/_e),
> source art/blender/bosses/deep_eel_iso.blend, script art/tools/night/c8d_build.py. Lisibilité de nuit
> obligatoire (albédo ≥ 90/255, rim froid). Périmètre : ces fichiers seulement. Vérification : sprites_test,
> deep_eel_boss_test et floor4_boss_test -> RESULT: OK, planche _c8d_contact.png. Le joueur dort : décide toi-même
> dans l'esprit de la DA et SURPRENDS. Rapport court en français.

**Concept** : anguille de **3,8 u** de long, corps épais comme un tronc, **écailles de sel** gris perle
(`#98A2A6` → `#C4CCCE`) incrustées de cristaux, **nageoires-lames** sur le dos (os translucides tranchants), tête
plate sans yeux visibles mais **un œil-lanterne** et une **ligne de lueur interne** blanc-cyan `#BFF4FF` qui court
sous la peau translucide du flanc (accent émissif unique : c'est elle qu'on devine sous l'eau noire). Le corps
**sort de l'eau en arche** : les sprites montrent la partie émergée, l'eau noire et ses remous à la base de chaque
pose (anneaux d'eau aux points d'entrée). Phases : **p1** arche basse, lueur faible ; **p2** plus de lueur, sel
qui craquelle, filets d'eau qui ruissellent ; **p3** **échouée** : couchée en S sur la berge, écailles arrachées,
nageoires dressées, lueur éblouissante, la queue reste dans l'eau.

| anim | frames | dirs | notes |
|---|---|---|---|
| idle_p1, idle_p2, idle_p3 | 6 (boucle) | e,s,w,n | p1/p2 : arche qui ondule au ras de l'eau ; p3 : échouée, respiration lourde |
| walk_p1, walk_p2, walk_p3 | 8 (boucle, 14 fps) | e,s,w,n | reptation sur la terre (retour vers l'eau après une émergence) ; p3 : non utilisée (ancrée), rendre la même que idle_p3 |
| auto | 6 | e,s,w,n | **morsure** au bord : la tête recule puis claque, **impact frame 3** |
| spell_a | 8 | e,s,w,n | **émergence** : jaillit de l'eau et se jette droit devant (corps tendu horizontal), **impact frame 4** |
| spell_b | 8 | e,s,w,n | **décharge** : s'enroule, la lueur interne éclate en arcs blanc-cyan autour d'elle, **impact frame 4** |
| trans_p2 | 8 | s | la crue : elle frappe l'eau, une vague déborde |
| trans_p3 | 8 | s | se hisse et s'échoue sur la berge, en S |
| death | 10 | s | se tord, la lueur s'éteint de la queue vers la tête, le sel se fend |

Extras (même `deep_eel.tres`, mêmes conventions `_n`/`_e`) :

| nom | type | cellule | frames | utilisation par le code |
|---|---|---|---|---|
| `black_pool` | sol | 896 × 896, **lac d'eau noire circulaire de rayon 448 px**, bord de dalles effondrées et de sel, reflets cristal sur le bord | 8 (boucle, ondulation lente) | lac de l'anguille (rayon 3,5 u, puis 5,5 u après la crue) : `scale = rayon / 448` |
| `puddle` | sol | 128 × 128, flaque d'eau noire de rayon 64 px (1 u), bord clair | 6 (boucle) | flaques projetées par la décharge (9 s), d'où elle peut surgir en phase 2 |
| `wake` | sol | 128 × 128, sillage en V **vers −x** + lueur sous l'eau au centre | 6 (boucle) | anguille plongée : suit sa position, orienté par le code |
| `emerge_splash` | billboard | 192 × 384, gerbe d'eau noire avec éclats de lumière | 6 | émergence, plongée, retour à l'eau (pied au bas, décalage −192 px) |
| `discharge_ring` | sol | 256 × 256, anneau d'arcs électriques blanc-cyan de **rayon extérieur 124 px** | 6 | décharge (étiré à 6 u : `scale = 6 u / 124 px`) |
| `whip` | sol | 448 × 77 (7 u × 1,2 u), nageoire-lame / queue qui fouette **vers +x**, départ au bord gauche | 8 (boucle) | phase 3 : 2 fouets qui tournent (le code décale de +224 px) |

Sons (Codex audio) : `enemy.eel_emerge.heavy` (eau qui explose + sifflement), `enemy.eel_discharge.heavy`
(bourdonnement électrique sous l'eau qui claque), `enemy.eel_bite.medium`, `amb.black_water` (clapotis sourd et
bulles, boucle). Le code utilise aujourd'hui `enemy.shockwave.heavy`, `enemy.brute_cone.heavy`, `telegraph.*`.
