# F3P — Cité de rouille — 22 octobre 2026

Lot terminé : 16 diffus, 16 normales, 3 émissions et 8 ombres TOP, soit 43 PNG (696 658 octets avant import). Les neuf noms historiques sont remplacés, avec leurs dimensions conservées ; sept variantes/nouveaux props complètent la demande. Aucun .gd, .tscn ou .tres édité.

## Choix de direction artistique

Fer noir martelé, émail municipal encrassé, oxyde aux soudures, laiton terni et huile presque noire. Shaders PBR bruités et relief fin issus d'Ash Lord, AO et auto-ombres cuits via le pipeline F2P/C0. Lumière chaude haute à gauche, remplissage froid faible ; couleurs sombres et désaturées. Seule émission : ambre vapeur #E8A86C, dans le globe protégé par six barreaux ; aucun halo cuit.

Les réverbères dessinent un col de cygne maigre, presque insectile, avec capillaire de vapeur, pied boulonné et cheminée anguleuse. Les cuves portent une échelle excentrée, un manomètre, des rangées de rivets et des coulures. Les fûts ont une silhouette cabossée et des suintements géométriques ; les débris mêlent tôles vrillées et poutrelles en I. Lisibilité par les arêtes, le métal usé et la silhouette, sans couleurs vives.

## Contrat et placement

Rig MAP orthographique : lacet 45°, élévation 30°, 90,51 px/u ; rendu Eevee 16 échantillons à 2× puis réduction. Sources : `art/blender/props/f3p_<nom>.blend`. Script : `art/tools/night/f3p_build.py` ; reprise ciblée `-- --only <nom>`, vérification Python `--verify`.

| Nom | Frame | Pied | Emprise complète X × Y (u) |
|---|---|---|---|
| crate_se | 128² | 64,94 | 0,8385 × 0,9250 |
| crate_sw | 128² | 64,94 | 0,9250 × 0,8385 |
| barrels | 160² | 80,122 | 1,0410 × 0,7910 |
| valve | 128² | 64,96 | 0,7518 × 0,5600 |
| pipe_stub | 192² | 96,148 | 1,1000 × 0,6400 |
| debris | 192² | 96,108 | 1,2010 × 0,6794 |
| steam_lamp_se | 256² | 128,220 | 0,3423 × 0,7862 |
| steam_lamp_sw | 256² | 128,220 | 0,7862 × 0,3423 |
| tank_large | 320² | 160,268 | 1,0800 × 1,2010 |

`props.json` : densité 0,05 ; exactement crate_se (4), barrels (4), debris (4), valve (2), pipe_stub (2), tank_large (1). `fade: true` pour tank_large. Pas de réverbères dans ce manifeste, conformément au placement par les règles d'ambiance demandé au §2.

Pour poser les réverbères du canal : `fade: true`, pied **[128,220]** pour les deux orientations ; hauteur totale **2,2 u**, centre du globe **1,81 u**. Globe SE **[155,520 ; 64,366]**, soit **155,634 px** au-dessus du pied ; globe SW **[155,520 ; 91,886]**, soit **128,114 px** au-dessus du pied. La différence verticale vient du déport du col de cygne. Aucun code de placement modifié ; raccordement par l'agent carte comme prévu dans la demande.

Ombres : TOP 512², 128 px/u, pied centré [256,256], pour crate_se/sw, barrels, pipe_stub, tank_large ; supplémentaires pour crate et steam_lamp_se/sw. Aucune ombre pour debris. Valeur `shadow_rig: "top"` seulement sur les entrées effectivement munies de ce rendu TOP.

Compatibilité : crate 128², steam_lamp 128², bell 192², cables 128², catwalk 256², tank_small 192², ticket_booth 192², valve 128², tank_large 320². Le nom historique steam_lamp conserve sa frame 128² avec une version réduite à 57 % ; les nouvelles variantes 256² portent la hauteur contractuelle de 2,2 u.

## Vérifications

- `python art/tools/night/f3p_build.py --verify` : PASS ; tailles, alpha, marges, normales, émissions, pieds, emprises complètes, hauteurs et manifeste contrôlés. Correction locale du compositor Blender 5.2 : Set Alpha remplace l'alpha au lieu de multiplier deux fois la couverture des normales.
- `cite_iso_test.tscn` : **RESULT: OK**, code retour 0. Au second passage, messages de chargement externes pour `bosses/etage/sonneur/steam_jet.png` et sonneur.tres ; premier passage sans ces erreurs. Aucun fichier de ce boss modifié.
- `sprites_test.tscn` : **RESULT: OK**, code retour 0, sans erreur.
- `texture_budget.py` : aucune texture >4096 px dans le projet ; catégorie props sous budget. Alertes globales hors lot : monsters 16,1 >12 Mo ; imports UI non conformes ; APK estimé 322 >200 Mo ; textures mobiles 214 >180 Mo. Aucun correctif hors périmètre appliqué.
- `texture_budget_test.tscn` : **RESULT: FAIL (2)** hors lot : imports de boss non conformes et budget mobile global 214 >180 Mo. Tailles, passes, régions d'atlas et absence de mipmaps : OK.
- Planche unique assemblée et inspectée : `art/tools/night/_f3p_contact.png`, **1920×2080**, props sur terrain F3 et références Ardent/Rictus/C1/F3/captures. Maximum des PNG du lot : 512 px.

Rien à reprendre dans le lot F3P. Intégration des sprites aux lumières du canal réservée à l'agent carte, conformément au §2.
