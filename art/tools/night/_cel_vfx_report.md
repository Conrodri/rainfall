# CEL VFX

| Dossier | Action | Motif |
|---|---|---|
| `ardent_ashes` | laissé | lumière/particules; exclusion explicite |
| `ardent_brasier` | laissé | lot R1 |
| `ardent_nova` | laissé | lot R1 |
| `charge_ring` | laissé | lumière/particules; exclusion explicite |
| `chest_open` | laissé | halo/rayons/étoiles uniquement; aucun coffre dans make_chest |
| `ember_orbs` | laissé | lumière/particules; exclusion explicite |
| `ember_shard_impact` | laissé | lumière/particules; exclusion explicite |
| `flame_pillar` | laissé | lumière/particules; exclusion explicite |
| `level_up` | laissé | lumière/particules; exclusion explicite |
| `lightning_arc` | laissé | lumière/particules; exclusion explicite |
| `meteor` | re-rendu | disque opaque et fumée; prop |
| `meteor_impact` | re-rendu | fumée; vfx |
| `monster_death` | re-rendu | fumée; vfx |
| `particles` | laissé | lumière/particules; exclusion explicite |
| `phoenix` | laissé | plumes en flame émissives; aucune plume solide |
| `pillar_zone_ring` | laissé | lumière/particules; exclusion explicite |
| `source` | laissé | pluie lumineuse; ambiance protégée |
| `status_burn` | laissé | lumière/particules; exclusion explicite |
| `status_frost` | laissé | lumière/particules; exclusion explicite |
| `status_poison` | laissé | lumière/particules; exclusion explicite |
| `telegraph_circle` | laissé | lumière/particules; exclusion explicite |
| `telegraph_cone` | laissé | lumière/particules; exclusion explicite |

6 planches; profils `prop` et `vfx`; teintes, graphes alpha, mouvements et cadrages originaux. Rampes produites par `cel_style.toon_materials`; billboards ?missifs natifs conserv?s hors corps. Contour int?rieur du disque; fum?es en 2 tons sans contour. Aucun coffre ni plume solide dans les sources: exclusions assum?es.

Masques `_e` archiv?s conserv?s octet pour octet, demi-r?solution; accent IoU 1.0. Aucun `_n`; aucune planche > 4096. Atlas, ressources et fichiers non cibl?s inchang?s pendant le lot. Archives uniques dans `art/archive_3d/sprites/vfx/`.

?cart de v?rification: cellules finales translucides pr?sentes dans les originaux; contr?le alpha > 0 et unicit? au lieu du seuil alpha > 240 r?serv? aux corps opaques. `cel.check_sheet(..., normals=False)` sur chaque diffus; minimum silhouette IoU 0.9964442013129103.

PNG VFX: 16966230 ? 16978444 octets; 16.966 ? 16.978 Mo. Budget mobile global: 177 Mo <= 180 Mo.

`texture_budget.py --apply-policy`: 0 fichier(s) .import modifi?s. Import Godot: exit 0, sans erreur. `sprites_test`, `action_vfx_test`, `texture_budget_test`: RESULT: OK.

Avertissement de sortie `action_vfx_test` (exit 0): `ERROR: 16 resources still in use at exit (run with --verbose for details).`

`fx/elites` et `game/assets/sprites/ambiance` laiss?s: hors p?rim?tre. `.blend` sources jamais enregistr?s.
