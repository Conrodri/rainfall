# Demandes d'art — étage 2 (Forêt-brume, Cerf-Lanterne)

Rédigé par l'agent Claude « étage 2 » (nuit du 22/10/2026). Rien n'est bloquant : le jeu tourne avec
l'existant (replis en place). DA : art/briefs/STYLE.md + STYLE_boss_da.md, accent unique #9CF0C8,
brume #B8C8C0. Toujours `_n` (et `_e` si émissif), mêmes conventions que C7b / F2.

## 1. F2p (déjà en file) — ajouter un manifeste `props.json`

Le code est prêt (`StageMap._build_props`, game/scripts/stage/stage_map.gd) mais reste inactif tant que
`game/assets/sprites/props/fog_forest/props.json` n'existe pas (les anciens rendus non iso du dossier ne
sont donc jamais posés). À écrire par Codex à la fin de F2p (ou par l'agent d'intégration) :

```json
{"density": 0.05, "props": [
  {"name": "stump",            "weight": 4, "foot": [px, py], "px_per_u": 90.51, "fade": false, "shadow_rig": "top"},
  {"name": "mushrooms",        "weight": 5, "foot": [px, py], "px_per_u": 90.51, "fade": false},
  {"name": "standing_stone",   "weight": 2, "foot": [px, py], "px_per_u": 90.51, "fade": false, "shadow_rig": "top"},
  {"name": "root_arch_a",      "weight": 2, "foot": [px, py], "px_per_u": 90.51, "fade": false, "shadow_rig": "top"},
  {"name": "lantern_shrine_se","weight": 1, "foot": [px, py], "px_per_u": 90.51, "fade": false, "shadow_rig": "top"},
  {"name": "cedar_giant",      "weight": 1, "foot": [px, py], "px_per_u": 90.51, "fade": true,  "shadow_rig": "top"}
]}
```

- `foot` = pixel du cadre (diffus) qui touche le sol au centre de l'emprise ; `px_per_u` = densité du rig
  (90,51 = rig MAP des tuiles iso) ; `shadow_rig: "top"` seulement si `<name>_shadow.png` est rendu avec le
  rig TOP 128 px/u (comme `block_*_shadow.png` de F2, 512² centré sur l'emprise), sinon omettre.
- Décor non bloquant (posé sur les cases libres) : emprise au sol ≤ 1,5 u, hauteur libre (le cèdre a
  `fade: true`, il passe en fondu quand le joueur est derrière).

## 2. Lot faune forêt (déjà prévu : moss_mantis, mist_wolf, lantern_owl, weaver, hermit_cedar)

Pas de code branché (le choix des sprites de monstres par tier, `EnemyVisual.SPRITES`, est partagé par
tous les étages : à brancher par l'orchestrateur). Contrat proposé pour que l'intégration soit triviale :
dossier `game/assets/sprites/monsters/<nom>/<nom>.tres` (SpriteFrames), anims `run_<dir>` sur les 8
directions `e, se, s, sw, w, nw, n, ne` (+ `charge_<dir>` pour le bondisseur), rig iso C5 (90,51 px/u),
pieds au même pivot que `swarm_tier1`. Correspondance suggérée : tier 1 essaim = moss_mantis (et weaver
en variante), tier 2 tireur = lantern_owl, tier 2 bondisseur = mist_wolf, tier 3 brute = hermit_cedar.

## 3. Cerf-Lanterne : compléments (nouveau, petit lot « C7d »)

Le combat est complet avec C7b ; ces ajouts amélioreraient la lisibilité de la charge et du tir :

| Fichier (game/assets/sprites/bosses/etage/cerf/) | Contenu | Cadre | Frames / fps | Ajout au cerf.tres |
|---|---|---|---|---|
| `charge_dirs.png` (+ `_n`, `_e`) | galop de ruée, tête basse, bois en avant, lanternes traînantes ; lignes e, s, w, n | 256 × 256, pivot (128 ; 179,2), 50,196 px/u | 6 frames, boucle, 18 fps | anims `charge_p1_e/s/w/n` (une seule série pour les 3 phases suffit : `charge_e/s/w/n`) |
| `antlers_dirs.png` (+ `_n`) | émission seule des lanternes pendant l'armement de la charge (comme `antlers`, alignée sur `spell_b_<dir>`) ; lignes e, s, w, n | 256 × 256 | 8 frames calées sur spell_b, non bouclé, 12 fps | anims `antlers_charge_e/s/w/n` |
| `wisp_bolt.png` (+ `_n`, `_e`) | follet-projectile du tir à distance (flamme menthe étirée, queue de brume), orienté vers +x | 64 × 32 | 4 frames, boucle, 12 fps | anim `wisp_bolt` |

Code prévu (CerfBrain) : la ruée joue `charge_<dir>` si présent (aujourd'hui : marche `walk_pN_<dir>`),
l'armement superpose `antlers_charge_<dir>`, le tir utilise `wisp_bolt` (aujourd'hui : projectile
générique du pool). Vérification : sprites_test.tscn et cerf_boss_test.tscn -> RESULT: OK.
