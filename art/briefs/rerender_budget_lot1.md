# Re-rendus allégés, lot RR1 (08/11/2026)

But : regagner de la marge sur le budget de textures mobiles (168,0 Mo avant, 165,5 Mo après) sans perte visible. Règle de fond : un sprite plus léger est un nouveau rendu Codex dans Blender, jamais un redimensionnement par code.

## Livré
- `vfx/source/rain_column.png` et `_e` : 12 cellules de 192 × 768 (avant 256 × 1024), même cadrage monde, planche 2304 × 768, `_e` 1152 × 384. Constante `SHEET_PX_PER_U` de `source_column.gd` passée de 90,51 à 67,8823 (75 %). Contrôle chiffré : boîte englobante, couleur moyenne et couverture identiques à ±1 %.
- `vfx/raid/safe_sector.png` : cellules de 576 px (avant 1152), grille 3 × 3, 8 images. `raid.tres` (régions divisées par deux) et `RaidFx.SAFE_SECTOR_SCALE = 2.0` gardent la même emprise de 1152 px au sol. Contrôle chiffré identique.
- Anim `danger_sheet` du kit de raid : jamais jouée par le code. Retirée de `raid.tres` et de `GROUND_ANIMS`, planche exclue de l'export Android (préréglage et `android_unused_excluded`), conservée dans le dépôt.

## Écarté après essai (à refaire avec la bonne chaîne de rendu)
- `ui/da/vignette_hit.png` (1024 → 512) : le script `art/tools/ui/u1_build.py` ne reproduit pas le fichier livré (cadre rouge deux fois plus épais). Le livré vient d'une chaîne ultérieure (commit 853820d0) dont le script n'est pas dans le dépôt.
- `bosses/etage/drowned_idol/carillon_ring.png` (1152 → 576 par cellule) : le script actuel rend un bleu terne (RGB moyen 65,122,143 au lieu de 101,191,191). Même cause probable.
Fichiers restaurés à l'identique ; gain visé non réalisé (≈ 1,2 Mo).

Consignes : `art/tools/rerender/_lot1.txt`, `_lot1b.txt`. Planche avant/après : `art/renders/rerender/lot1_compare.png`.
