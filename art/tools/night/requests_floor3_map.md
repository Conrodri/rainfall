# Demandes d'art — étage 3 (Cité de rouille), carte iso

Rédigé par l'agent Claude « étage 3 carte » (22/10/2026). Rien n'est bloquant : la cité tourne en iso
avec les tuiles du lot F3 (`game/assets/sprites/terrain/rust_city/iso/`, 41 PNG, intégrés tels quels).
DA : art/briefs/STYLE.md + STYLE_boss_da.md ; palette du lot F3 (fer riveté, brique noire, huile),
accent unique ambre/laiton (lampes à vapeur #E8A86C). Toujours `_n` (et `_e` si émissif), rig MAP
lacet 45°, 90,51 px/u, mêmes conventions que F2p (art/tools/night/_f2p.txt, requests_floor2.md §1).

## 1. F3p — props iso de la cité (nouveau lot, comme F2p)

Les rendus actuels de `game/assets/sprites/props/rust_city/` (bell, cables, catwalk, crate, steam_lamp,
tank_large, tank_small, ticket_booth, valve) ne sont PAS iso : à remplacer (mêmes noms autorisés).
Le code est prêt (`StageMap._build_props`, `BIOME_PROPS["cite"]`) et reste inactif tant que
`game/assets/sprites/props/rust_city/props.json` n'existe pas.

| Fichier | Contenu | Emprise | Notes |
|---|---|---|---|
| `crate_se`, `crate_sw` | caisse rivetée, cerclages laiton | ≤ 1,2 u | `_shadow` rig TOP |
| `barrels` | 2-3 fûts d'huile cabossés, coulure noire | ≤ 1,2 u | `_shadow` rig TOP |
| `valve` | vanne de pression au sol, volant en fonte | ≤ 1 u | |
| `pipe_stub` | tronçon de conduite qui sort du pavé, coude, rivets | ≤ 1,5 u | `_shadow` rig TOP |
| `debris` | tôles et poutrelles tombées, à plat | ≤ 1,5 u | décor bas, sans ombre |
| `steam_lamp_se`, `steam_lamp_sw` | réverbère à vapeur 2,2 u de haut, globe ambre | ≤ 0,8 u | `_e` (globe #E8A86C), halo NON cuit ; `fade: true` |
| `tank_large` | cuve verticale 2,5 u, échelle | ≤ 1,5 u | `fade: true`, `_shadow` rig TOP |

Manifeste à écrire (fin du lot) :

```json
{"density": 0.05, "props": [
  {"name": "crate_se",     "weight": 4, "foot": [px, py], "px_per_u": 90.51, "fade": false, "shadow_rig": "top"},
  {"name": "barrels",      "weight": 4, "foot": [px, py], "px_per_u": 90.51, "fade": false, "shadow_rig": "top"},
  {"name": "debris",       "weight": 4, "foot": [px, py], "px_per_u": 90.51, "fade": false},
  {"name": "valve",        "weight": 2, "foot": [px, py], "px_per_u": 90.51, "fade": false},
  {"name": "pipe_stub",    "weight": 2, "foot": [px, py], "px_per_u": 90.51, "fade": false, "shadow_rig": "top"},
  {"name": "tank_large",   "weight": 1, "foot": [px, py], "px_per_u": 90.51, "fade": true,  "shadow_rig": "top"}
]}
```

`foot` = pixel du diffus qui touche le sol au centre de l'emprise ; `shadow_rig: "top"` seulement si
`<name>_shadow.png` est rendu au rig TOP 128 px/u (512² centré sur l'emprise, comme `block_*_shadow.png`).

## 2. Réverbères du canal (lien avec l'ambiance)

Le profil `data/ambiance/cite_rouille.tres` pose jusqu'à 32 lumières `steam_lamp` le long du canal
(`light_rules`, cases bordant « ~ », espacement 6 u) : en jeu ce sont des flaques de lumière sans source
visible. Avec `steam_lamp_se/sw` livrés, un agent Claude posera le sprite au point de chaque lumière
(petit ajout dans `StageMap`/`AmbianceManager`, pas de manifeste). Livrer le pied (`foot`) et la hauteur
du globe en px dans le rapport (pour caler `height` de la lumière).

## 3. Eau du canal (facultatif)

`water_deep.png` / `water_shallow.png` de F3 sont presque noirs (moyenne ~16/255) : bien pour une eau
huileuse, l'éclat vient du shader (`puddle.gdshader`, reflets bas réglés dans le profil). Si un re-rendu
est fait : film d'huile irisé très discret et quelques détritus flottants, sans dépasser 0,10 d'albédo.
