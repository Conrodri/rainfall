# Budget textures - constats (26/10/2026)

Relance de `game/tests/texture_budget_test.tscn` : RESULT OK. Les trois échecs signalés plus tôt ne se reproduisent plus
(roll_e.png de la bonne taille, régions d'atlas de tocsin_torso.tres dans leur planche, APK mobile estimé à 177 Mo pour 180 max).
Cause probable : la file Codex a réécrit les sprites concernés entre-temps. Aucun PNG ni .tres modifié par cet audit.

Restes sans urgence :
- Marge APK faible (3 Mo) : toute nouvelle planche lourde repasse au-dessus de 180 Mo.
- `oversize_allowlist` de `tests/texture_budget.json` : retirer wave_cone.png et wave_cone_e.png (plus hors limite).
- Warning au lancement : texture d'ambiance `shadow_blob_256` absente (repli neutre).
