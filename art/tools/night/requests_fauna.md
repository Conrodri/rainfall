# Demandes d'art — faune par biome (monstres courants T1-T3, élites, mini-boss)

Rédigé par l'agent Claude « faune par biome » (22/10/2026). **Rien n'est lancé** : briefs prêts à copier
dans `art/tools/night/_<lot>.txt` + une ligne de `queue.txt`. Rien n'est bloquant : le jeu retombe sur les
sprites de l'étage 1 tant qu'un dossier manque.

## 0. Code déjà branché (contrat)

- Table : `game/data/fauna.json` (lue par `EnemyVisual`, `game/scripts/enemies/enemy_visual.gd`).
  Biome -> rôle (`swarm` tier 1, `shooter` tier 2, `leaper` tier 2 bondisseur, `brute` tier 3) -> dossier
  `game/assets/sprites/monsters/<nom>/<nom>.tres` ; `elites` (même forme, vide aujourd'hui) ; `minis` et
  `floor_bosses` par biome (rotation filtrée sur les `.tres` présents) ; `boss_sprites` = géométrie des boss
  à venir (dim/bottom provisoires, **à recaler à la livraison** d'après la planche de contact).
- Biome courant = carte du StageManager (`data/maps/<id>.json` -> `biome`), sinon étage de RunState
  (1 terrasses, 2 foret, 3 cite, 4 cryptes, 5 source ; sans fin : 6 -> 1).
- Replis : élite du biome -> sprite normal du biome -> sprite de l'étage 1 -> (bondisseur) tireur -> placeholder.
- Un dossier livré au nom attendu **se branche seul** (aucun code à toucher). Seule condition : anims
  `run_<dir>` sur les 8 directions `e, se, s, sw, w, nw, n, ne` (le chargeur teste `run_e`), mêmes grilles,
  pivots et densité que le dossier de l'étage 1 du même rôle (la géométrie `scale/offset_y/render_px_per_u`
  est héritée ; une surcharge par biome reste possible dans le JSON : `{"name": ..., "scale": ...}`).
- Test : `game/tests/biome_fauna_test.tscn` (table, replis, chemins des mini-boss, intégration étages 1-3).

## 1. Inventaire au 22/10/2026

| Famille | Présent (`game/assets/sprites/…`) | Attendu (enregistré, absent) |
|---|---|---|
| Monstres étage 1 | `monsters/swarm_tier1` (96 px, run ×8, iso C5 90,51 px/u), `shooter_tier2` (112 px, run+attack), `leaper_tier2` (112 px, run+charge), `brute_tier3` (160 px, run+attack+cast) | — |
| Monstres forêt | — | `monsters/<rôle>_moss/` ×4 (lot **N2e**, déjà en file) |
| Monstres cité | — | `monsters/<rôle>_rust/` ×4 (lot **N3e**, §3 ci-dessous) |
| Monstres cryptes / Source | — | `<rôle>_salt/`, `<rôle>_source/` (§4, plus tard) |
| Élites | — (aura + lumière en code) | tables `elites` vides (§5, optionnel) |
| Mini-boss | `bosses/mini/` ash_lord, bramble_queen, brood_mother, frost_bear, rust_archon, stone_colossus | forêt : `mist_wolf`, `lantern_owl` (N2a), `moss_mantis` (N2b), invocation `mist_wolf_cub` (N2a) ; étages 1, 3, 4 : roster Design_Etages §5 |
| Boss d'étage | `bosses/etage/` cerf, eclusier, sonneur | forêt : `weaver` (N2c), `hermit_cedar` (N2d) ; autres : roster §5 |

## 2. Forêt-brume : monstres courants = lot N2e (déjà en file, rappel)

Le brief `_n2e.txt` convient tel quel au code : dossiers `swarm_tier1_moss`, `shooter_tier2_moss`,
`leaper_tier2_moss`, `brute_tier3_moss` (+ `.tres` du même nom). **Correction de chemin** : le lot C5 est
`art/tools/iso/_c5.txt` (et non `art/tools/monsters/_c5.txt`). Si N2e est relancé, ajouter cette phrase :

> Nommage EXACT (le jeu les charge seul via game/data/fauna.json, biome « foret ») : monsters/<nom>_moss/<nom>_moss.tres, mêmes noms d'animations (run_<8 dirs>, attack_/charge_/cast_<8 dirs> selon le rôle), mêmes tailles de cellule (96 / 112 / 112 / 160 px), même pivot des pieds et même densité que le dossier d'origine (swarm à 90,51 px/u comme C5) ; _n et _e pour chaque planche. Lot C5 : art/tools/iso/_c5.txt.

## 3. Cité de rouille : monstres courants — nouveau lot N3e (brief prêt)

Fichier à créer : `art/tools/night/_n3e.txt` ; ligne de file : `12 art/tools/night/_n3e.txt art/tools/night/_logn3e.txt medium`.

```
LOT N3E : variante de matière « rouille » (Cité de rouille, étage 3) des monstres swarm_tier1, shooter_tier2, leaper_tier2, brute_tier3 : mêmes modèles, mêmes grilles, frames, pivots, densités et noms d'animations que leurs dossiers actuels (inspecte game/assets/sprites/monsters/ et le lot C5 art/tools/iso/_c5.txt ; si le lot N2e est livré, reprends sa méthode art/tools/night/n2e_build.py). Matière : tôle et fonte rouillées, rivets, câbles gainés de suie, béton écaillé sur la brute, coulures d'huile, vapeur froide aux jointures ; essaim = larves-boulons qui grouillent, tireur = guetteur encapuchonné de toile goudronnée avec lanterne-œil, bondisseur = carcasse de chien-ressort, brute = manœuvre-fondeur aux épaules de chaudière. Accent émissif UNIQUE orange de lampe au sodium #FF9A3C (yeux, fissures, filaments) dans les _e, lisible sur sol sombre de la cité (art/tools/night/_f3_contact.png). Livre dans un dossier frère suffixé _rust : game/assets/sprites/monsters/swarm_tier1_rust/swarm_tier1_rust.tres (et shooter_tier2_rust, leaper_tier2_rust, brute_tier3_rust), PNG + _n + _e par planche, .tres calqué sur celui d'origine (chemins remplacés). Nommage EXACT : le jeu les charge seul via game/data/fauna.json (biome « cite »). Sources art/blender/monsters/n3e_*, script art/tools/night/n3e_build.py. Périmètre : ces chemins uniquement.
DA OBLIGATOIRE : art/briefs/STYLE.md en tête + STYLE_boss_da.md ; références validées : Ardent art/tools/iso/_c4_contact.png, Rictus art/tools/characters/_m2_contact.png, ash_lord_build.py (mini-boss de la cité, même accent), rust_archon (game/assets/sprites/bosses/mini/rust_archon/), terrain art/tools/iso/_c1_contact.png. PBR usé, palette sombre désaturée, un accent émissif, réaliste et malsain par la forme et la matière, jamais cartoon. Le joueur dort : aucune validation possible, prends les décisions de design toi-même dans l'esprit de la DA et SURPRENDS par la qualité ; note tes choix dans le rapport.
Vérification : "C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path game res://tests/sprites_test.tscn -> RESULT: OK puis res://tests/biome_fauna_test.tscn -> RESULT: OK (il vérifie que chaque dossier _rust livré est bien pris pour la cité) ; chargement de chaque .tres sans erreur ; planche de contrôle art/tools/night/_n3e_contact.png (les 4 rôles _rust à côté de leur version d'origine et d'ash_lord, même échelle, sur une tuile de la cité). Aucun .gd/.tscn/.json ; des agents Claude codent en parallèle et d'autres lots Codex tournent : reste dans ton périmètre. Si le quota manque, arrête-toi après un monstre complet et écris où reprendre dans le rapport. Rapport final court en français.
```

## 4. Plus tard (enregistré, pas de brief tant que le biome n'existe pas)

- **Cryptes noyées (étage 4)** : `<rôle>_salt` (sel cristallisé, os, eau noire ; accent cristal blanc-cyan ;
  Design_Etages §3 : chroma +20 % pour rester lisible, L* ≥ 60). Même gabarit que N3e, après le tileset C4.
- **La Source (étage 5)** : `<rôle>_source` (bronze noirci ruisselant, accent goutte blanche). Facultatif :
  l'étage final peut garder la foule de l'étage 1 (repli automatique).

## 5. Élites (optionnel, petit lot « E1 » si le quota le permet)

Aujourd'hui une élite = sprite normal + aura et lumière d'affixe (code). Le code accepte une variante :
`fauna.json` -> `"elites": {"brute": "brute_tier3_elite"}` (par biome). Proposition : **brute et bondisseur
de l'étage 1 seulement** (les gardiens des zones secrètes sont des brutes élites) : même modèle, armure
renforcée + 2e matériau (bronze cerclé), silhouette +10 % (cellule inchangée), même accent ; dossiers
`monsters/brute_tier3_elite/`, `monsters/leaper_tier2_elite/`, mêmes anims. Après livraison : ajouter les
deux entrées dans `elites` de « terrasses » (une ligne JSON, sans code).

## 6. Mini-boss forêt (N2a-N2d) : rappel du contrat de livraison

Chemins enregistrés (rotation automatique dès que le `.tres` existe, après bramble_queen et brood_mother) :
`bosses/mini/mist_wolf/mist_wolf.tres`, `bosses/mini/lantern_owl/lantern_owl.tres`,
`bosses/mini/moss_mantis/moss_mantis.tres`, `bosses/etage/weaver/weaver.tres`,
`bosses/etage/hermit_cedar/hermit_cedar.tres` ; invocation `bosses/mini/mist_wolf_cub/mist_wolf_cub.tres`
(exposée par `EnemyVisual.summon_frames`, pas encore de comportement de meute en jeu). Conditions : mini =
anim `idle_s` (format frost_bear, cadre 170) ; boss d'étage = `idle_p1_s` (format cerf/éclusier, cadre 256).
À la livraison, recaler `dim` et `bottom` de `boss_sprites` dans `game/data/fauna.json` sur la planche.
Note : la correspondance de requests_floor2.md §2 (mini-boss forêt utilisés comme monstres T1-T3) est
**remplacée** par ce plan : les briefs N2a-N2d livrent des mini-boss/boss, la foule forestière vient de N2e.
