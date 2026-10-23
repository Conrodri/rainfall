# Demandes d'art — boss de l'étage 4 (Reclus) et boss final (Semeur de pluie)

Code intégré le 22/10/2026 (aucun lot lancé) : `game/scripts/enemies/recluse_brain.gd`, `rain_sower_brain.gd`
(+ `recluse_fx.gd` = formes dessinées PROVISOIRES, `recluse_gloom.gd`), tests `recluse_boss_test` /
`rain_sower_boss_test`. Tant que rien n'est livré, le jeu affiche des silhouettes et effets dessinés ; **chaque
fichier ci-dessous se branche seul** dès qu'il existe (chemins et noms d'anims enregistrés dans
`game/data/fauna.json` → `boss_sprites.recluse` / `boss_sprites.rain_sower`). Ne rien renommer.
Captures de référence (placeholders) : lancer les tests sans `--headless` avec `-- capture shots=<dossier>`.

## Règles communes (les deux lots)
- Méthode **C7b/C7c** à l'identique (`_c7b.txt`, `_c7c.txt`, `c7c_build.py`) ; DA `art/briefs/STYLE.md` en tête +
  `STYLE_boss_da.md` ; références : ash_lord_build.py, `_c7c_contact.png`. PBR usé, palette sombre désaturée,
  **un seul accent émissif**, silhouettes anguleuses, jamais cartoon. Caméra iso du jeu (Design_Isometrique),
  Eevee à échantillons modestes, rendu ×2 puis LANCZOS, film transparent.
- **Lisibilité de nuit (leçon du Sonneur, OBLIGATOIRE)** : le Sonneur rendu à ~40/255 d'albédo moyen restait noir
  en jeu malgré une lumière ×6 (le code le compense par `self_modulate`). Ici : albédo moyen du corps
  **≥ 90/255** (L* ≥ 60 sur les masses principales, chroma +20 % comme demandé pour les Cryptes,
  Design_Etages §3), **liseré de lumière froide haut-gauche** (rim) sur toute la silhouette, sol des Cryptes
  `#2E3238` et de la Source très sombres : vérifier le contraste du corps sur un fond `#2E3238` dans la planche
  de contrôle. L'accent émissif va dans `_e` (le code l'allume via EmissiveOverlay).
- **Cellules à la taille réelle d'affichage**, planches **≤ 4096 px** de côté : lignes = directions `e, s, w, n`
  (ordre fixe), colonnes = frames. Corps : cellule **256 × 256**, pieds sur la ligne `bottom` de fauna.json
  (Reclus y = 215, Semeur y = 225), grande dimension de la silhouette ≈ `dim` (185 / 200 px) ; le code met
  l'échelle et le pivot d'après ces trois valeurs (à recaler dans fauna.json si la planche change).
- Chaque PNG livré avec `<f>_n.png` (normales espace écran, fond (128,128,255,0)) et `<f>_e.png` (émission seule),
  même découpage. SpriteFrames texte `<id>.tres` (AtlasTexture), 12 fps (walk 14 fps), boucle seulement idle/walk
  et les extras marqués « boucle ».
- **Frame d'impact = moitié de l'anim** (auto : frame 3 sur 6 ; spell_a/b : frame 4 sur 8) — c'est là que le code
  applique les dégâts (EnemyVisual.BOSS_IMPACT_FRAC). Le geste doit culminer exactement sur cette frame.
- Extras « sol » : vus de dessus (caméra orthographique verticale), **1 u = 64 px**, le jeu les écrase en iso.
  Extras « billboard » : caméra iso du jeu, **1 u = 90,5 px** (Iso.RENDER_PX_PER_U, comme les corps), pied au
  bas de la cellule, centrés en x.
- Vérification : `godot --headless --path game res://tests/sprites_test.tscn` puis le test du boss
  (`recluse_boss_test` / `rain_sower_boss_test`) → RESULT: OK ; planche `art/tools/night/_<lot>_contact.png`.
  Aucun .gd/.tscn ; ne jamais toucher user://run_save.json, settings.cfg, ni un .blend hors `art/blender/`.

---

<a id="reclus"></a>
## Lot C8a — Le Reclus (`recluse`, boss d'étage 4, Cryptes noyées)

Consigne Codex (à copier dans `_c8a.txt`, effort `medium`) :

> LOT C8A : boss d'étage 4 « recluse » (Le Reclus), modèle neuf selon la méthode C7c (lis art/tools/night/_c7c.txt,
> c7c_build.py et art/tools/night/requests_bosses45.md section Reclus, qui fait foi pour les noms, cellules et
> frames). Biome Cryptes noyées : pierre de sel humide, os, cristal blanc-cyan #BFF4FF, eau noire. Sortie
> game/assets/sprites/bosses/etage/recluse/ (recluse.tres + planches + _n/_e), source art/blender/bosses/recluse_iso.blend,
> script art/tools/night/c8a_build.py. Lisibilité de nuit obligatoire (albédo ≥ 90/255, rim froid). Périmètre : ces
> fichiers seulement. Vérification : sprites_test et recluse_boss_test -> RESULT: OK, planche _c8a_contact.png.
> Le joueur dort : décide toi-même dans l'esprit de la DA et SURPRENDS. Rapport court en français.

**Concept** : moine de pierre de **3,6 u**, robe lourde de pierre de sel striée (gris clair `#8C8778` → `#B4B0A2`,
pas plus sombre), **capuche VIDE** (intérieur noir profond : le seul vrai noir du modèle), un **cristal
blanc-cyan `#BFF4FF` enchâssé dans la poitrine** (accent émissif unique, il éclaire le dedans de la capuche par en
dessous), à la main droite une **cloche de silence** en bronze verdi au bout d'une hampe-bâton ; chapelet d'os ;
bas de robe mouillé, gouttes de sel cristallisé. Silhouette verticale, étroite en haut, évasée en bas.
Phases visibles sur le modèle : **p1** cristal voilé (lueur moyenne) ; **p2** la robe se fend, veines de cristal
qui courent sur la pierre (dans `_e`), cristal plus grand ; **p3** **lévite** à 0,5 u du sol (ombre de contact
seule au sol, bas de robe qui pend, éclats de pierre en orbite lente), cristal éblouissant.

| anim | frames | dirs | notes |
|---|---|---|---|
| idle_p1, idle_p2, idle_p3 | 6 (boucle) | e,s,w,n | p3 : en lévitation (balancement lent) |
| walk_p1, walk_p2, walk_p3 | 8 (boucle, 14 fps) | e,s,w,n | pas lourds, robe qui traîne ; p3 : glisse en lévitation |
| auto | 6 | e,s,w,n | coup de bâton en arc (cône 70°, 3,2 u), **impact frame 3** |
| spell_a | 8 | e,s,w,n | **la cloche** : lève la cloche puis la frappe contre le bâton, **impact frame 4** (l'anneau part du boss) |
| spell_b | 8 | e,s,w,n | **prières** : mains jointes sur le cristal puis ouvertes vers le sol, **impact frame 4** |
| trans_p2 | 8 | s | la robe se fend, les veines s'allument (les cristaux de l'arène s'éteignent en même temps) |
| trans_p3 | 8 | s | décolle du sol jusqu'à 0,5 u |
| death | 10 | s | retombe, la pierre se fissure, le cristal s'éteint en dernier |

Extras (dans le même `recluse.tres`, mêmes conventions `_n`/`_e`) :

| nom | type | cellule | frames | utilisation par le code |
|---|---|---|---|---|
| `bell_wave` | sol | 256 × 256, anneau d'onde (son visible) de rayon extérieur **124 px**, fin, blanc-cyan | 8 (non bouclé) | étiré de 1 u à 8 u en 0,8 s (`scale = r / 124`) |
| `prayer_glyph` | sol | 128 × 128 (cercle de 2 u), cercle de glyphes gravés qui s'allument | 8 (boucle) | posé sous chaque cercle de prière pendant son télégraphe (échelle 1) |
| `prayer_burst` | billboard | 192 × 384, colonne de lumière cristalline qui jaillit du sol | 6 | impact d'une prière (pied au bas de la cellule) |
| `ray` | sol | 896 × 64 (14 u × 1 u), rayon de cristal **vers +x**, départ au bord gauche | 8 (boucle) | phase 3 : 4 rayons qui tournent (le code décale de +448 px) |
| `silence_mark` | sol | 96 × 96, petit anneau de runes autour du joueur | 6 (boucle) | 2 s sur le joueur touché par la cloche |

Sons (Codex audio, `art/tools/audio/`) : `enemy.silence_bell.heavy` (cloche fêlée étouffée + souffle qui « coupe »
le son 0,3 s), `enemy.prayer_chime.medium` (tintement cristallin), `amb.crystal_outage` (cristaux qui s'éteignent
en cascade). Le code utilise aujourd'hui `enemy.shockwave.heavy`, `telegraph.boss.heavy`, `telegraph.warn_*`.

---

<a id="semeur"></a>
## Lot C8b — Le Semeur de pluie (`rain_sower`, boss final, La Source)

Consigne Codex (à copier dans `_c8b.txt`, effort `medium`) :

> LOT C8B : boss final « rain_sower » (Le Semeur de pluie), modèle neuf selon la méthode C7c (lis art/tools/night/_c7c.txt,
> c7c_build.py et art/tools/night/requests_bosses45.md section Semeur, qui fait foi pour les noms, cellules et frames).
> Biome La Source : caverne ouverte sur le ciel, colonne de pluie blanche, bronze noirci, cristal blanc. Sortie
> game/assets/sprites/bosses/etage/rain_sower/ (rain_sower.tres + planches + _n/_e), source art/blender/bosses/rain_sower_iso.blend,
> script art/tools/night/c8b_build.py. C'est le CLIMAX de la run : le modèle le plus imposant et le plus soigné du jeu.
> Lisibilité de nuit obligatoire (albédo ≥ 90/255, rim froid). Périmètre : ces fichiers seulement. Vérification :
> sprites_test et rain_sower_boss_test -> RESULT: OK, planche _c8b_contact.png. Le joueur dort : décide toi-même dans
> l'esprit de la DA et SURPRENDS. Rapport court en français.

**Concept** : figure encapuchonnée de **4,5 u** (la plus grande du jeu, cellule 256 : elle doit la remplir en
hauteur) qui a pris la place du premier paratonnerre : manteau-cloche de **bronze noirci** relevé de vert-de-gris
(`#5A4A36` → `#8A7A5C` sur les arêtes, jamais plus sombre), capuche pointue qui rappelle la pointe du paratonnerre,
**bras-chaînes** (deux faisceaux de chaînes de bronze qui pendent jusqu'au sol et traînent), **cœur = une goutte
de cristal blanc** (`#E8F8FF`, accent émissif unique) visible à travers une déchirure du manteau, qui **bat** (le code
pulse la lumière). Toujours ruisselant : filets d'eau sur le manteau (spéculaire fort).
Phases visibles : **p1** manteau fermé, chaînes pendantes ; **p2** le bas du manteau est noyé, l'eau monte en
volutes autour des pieds, chaînes tendues vers le haut ; **p3** **ancré** : chaînes plantées dans le sol en croix,
manteau ouvert, cœur à nu, arcs électriques sur la capuche (dans `_e`).

| anim | frames | dirs | notes |
|---|---|---|---|
| idle_p1, idle_p2, idle_p3 | 6 (boucle) | e,s,w,n | p3 : ancré (chaînes au sol), le cœur bat |
| walk_p1, walk_p2, walk_p3 | 8 (boucle, 14 fps) | e,s,w,n | glisse, chaînes qui traînent ; p3 rarement vu (ancré) |
| auto | 6 | e,s,w,n | **fouet de chaîne** (ligne 1,2 × 5,5 u) ; sert aussi au tourbillon de P3 ; **impact frame 3** |
| spell_a | 8 | e,s,w,n | **Averse** : bras levés, la pluie se condense, **impact frame 4** (gouttes au sol) |
| spell_b | 8 | e,s,w,n | **Vague** : balayage bas des deux bras vers l'avant, **impact frame 4** (départ du front) |
| intro | 12 | s | descend dans la colonne de pluie et se pose (le code attend max(2,2 s, durée)) |
| trans_p2 | 12 | s | lève les chaînes, l'eau monte (1 s) |
| trans_p3 | 12 | s | plante les chaînes en croix, le manteau s'ouvre, la foudre frappe la capuche |
| death | 10 | s | la goutte se fend, la pluie s'arrête, le bronze se fige |

Extras (dans `rain_sower.tres`) :

| nom | type | cellule | frames | utilisation par le code |
|---|---|---|---|---|
| `rain_column` | billboard | 256 × 1024 (≈ 2,8 × 11 u), rideau de pluie blanche + lumière | 8 (boucle) | entrée (1,0 d'alpha) et phase 3 sur le boss (0,38, derrière lui) |
| `raindrop` | billboard | 48 × 256, goutte allongée en chute | 4 (boucle) | une par cercle d'Averse, tombe pendant 0,45 s |
| `splash` | sol | 128 × 128 (2 u), éclaboussure + anneaux | 6 | impact de chaque goutte |
| `wave_front` | sol | 128 × 128 (2 × 2 u), mur d'eau vu de dessus, **front vers +x** | 8 (boucle) | parcourt le couloir de la Vague à 14 u/s (rotation par le code) |
| `flood_water` | sol | 896 × 896, disque d'eau profonde de **rayon 448 px** (bord d'écume net, reflets du cristal) | 4 (boucle) | phase 2 : bassin infranchissable, `scale = r / 448` (r monte de 0 à 6 u puis reflue) |
| `mist_band` | sol | 256 × 256, nappe de brume froide translucide | 6 (boucle) | 20 copies en anneau à 17 u du centre (×1,6) |
| `lightning` | billboard | 128 × 768, éclair pleine hauteur, pied au bas | 4 variantes | foudre de P3 et ancrage (frame tirée au hasard) |
| `ground_scorch` | sol | 128 × 128, brûlure humide fumante | 4 variantes | sous chaque éclair, 6 s |
| `cross_beam` | sol | 832 × 64 (13 × 1 u), rayon d'orage **vers +x**, départ au bord gauche | 8 (boucle) | phase 3 : 4 lignes en croix qui tournent (le code décale de +416 px) |

Sons : `enemy.chain_lash.medium`, `enemy.rain_burst.medium` (averse qui s'abat), `enemy.wave_rush.heavy` (vague),
`amb.flood_rise` (crue, 1,5 s), `enemy.sower_heart` (battement grave en boucle, phase 3 plus rapide),
`enemy.sower_death` (la pluie s'arrête : silence brutal puis goutte). Le code utilise aujourd'hui
`amb.thunder_close`, `enemy.shockwave.heavy`, `telegraph.boss.heavy`, `telegraph.warn_*`.
