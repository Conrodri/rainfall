# Captures d'écran pour la page Steam

Dix-sept captures 1920x1080 du vrai jeu (rendu en fenêtre, pas en headless), générées le 11/11/2026. Aucun panneau de test ni texte de debug n'est visible : le mode test n'est pas utilisé, seuls l'invulnérabilité du joueur, quelques objets donnés et les monstres invoqués sont forcés par les scènes de capture. Les épreuves sont coupées (`--no-epreuves`) pour que la carte reste lisible.

| Fichier | Sujet |
|---|---|
| `screenshots/01_terrasses_horde.png` | Étage 1 (Terrasses noyées), Ardent, horde dense et sorts lancés |
| `screenshots/02_foret_horde.png` | Étage 2 (Forêt de brume), Tocsin, horde dense |
| `screenshots/03_cite_horde.png` | Étage 3 (Cité de rouille), Ardent, horde sous la pluie |
| `screenshots/04_cryptes_horde.png` | Étage 4 (Cryptes noyées), Averse, horde et eau |
| `screenshots/05_boss_etage.png` | Boss d'étage (La Tisseuse), barre de boss et télégraphes de toile |
| `screenshots/06_forge.png` | Inventaire, onglet Forge (recette réalisable, noyaux d'orage) |
| `screenshots/07_coop_locale.png` | Coop locale à deux (Ardent et Averse), cartes de joueur en bas |
| `screenshots/08_selection_personnage.png` | Écran Nouvelle run, grille des personnages |
| `screenshots/09_fiche_personnage.png` | Fiche d'un personnage (Taliant : sorts, passif) |
| `screenshots/10_boss_raid.png` | Boss de raid (L'Idole noyée) dans son cercle, barre de boss, étage 2 |
| `screenshots/11_boss_final.png` | Boss final (Le Semeur de pluie), étage 5, barre de boss, éclairs et télégraphes |
| `screenshots/12_coffre.png` | Grand coffre ouvert, choix de deux objets, relance gratuite |
| `screenshots/13_fin_de_run.png` | Récap de victoire avec rubis et médaillons d'épreuves (valeurs de mise en scène) |
| `screenshots/14_repere_cite_creusets.png` | Variante B de la Cité (fonderie du canal), creusets en fusion, pluie |
| `screenshots/15_coop_3_joueurs.png` | Coop locale à trois, cartes de joueur en bas |
| `screenshots/16_coop_4_joueurs.png` | Coop locale à quatre, cartes de joueur en bas |
| `screenshots/17_repere_terrasses_noria.png` | Variante B des Terrasses (rizières hautes), noria |

## Régénérer

Depuis la racine du dépôt, sans `--headless` (la lecture du viewport demande une fenêtre). Le wrapper ajoute `--path game` et prend le verrou partagé. Le premier lancement après un import compile les shaders et peut durer plusieurs minutes.

Scène de run (`game/tests/capture_store_run.tscn`, arguments après `--`) : `--scene=horde|boss|forge|coop|raid|final|chest|endrun|landmark`, `--players=<2-4>` (coop), `--boss=<id>` (raid), `--floor=<1-5>`, `--char=<id>`, `--seed=<n>`, `--force-map=<id>` (variante de carte), `--out=<fichier.png>` (chemin absolu conseillé), `--no-epreuves`.

```
G="sh art/tools/vfx_test/godot_locked.sh res://tests/capture_store_run.tscn --"
O=<dossier absolu>/docs/store/screenshots
$G --scene=horde --floor=1 --char=ardent --no-epreuves --out=$O/01_terrasses_horde.png
$G --scene=horde --floor=2 --char=tocsin --no-epreuves --out=$O/02_foret_horde.png
$G --scene=horde --floor=3 --char=ardent --no-epreuves --out=$O/03_cite_horde.png
$G --scene=horde --floor=4 --char=averse --no-epreuves --out=$O/04_cryptes_horde.png
$G --scene=boss  --floor=2 --char=ardent --no-epreuves --out=$O/05_boss_etage.png
$G --scene=forge --floor=2 --char=ardent --no-epreuves --out=$O/06_forge.png
$G --scene=coop  --floor=1 --no-epreuves --out=$O/07_coop_locale.png
$G --scene=raid  --floor=2 --boss=drowned_idol --no-epreuves --out=$O/10_boss_raid.png
$G --scene=final --floor=5 --no-epreuves --out=$O/11_boss_final.png
$G --scene=chest --floor=1 --no-epreuves --out=$O/12_coffre.png
$G --scene=endrun --floor=1 --no-epreuves --out=$O/13_fin_de_run.png
$G --scene=landmark --floor=3 --force-map=cite_fonderie_canal --no-epreuves --out=$O/14_repere_cite_creusets.png
$G --scene=coop --floor=1 --players=3 --no-epreuves --out=$O/15_coop_3_joueurs.png
$G --scene=coop --floor=1 --players=4 --no-epreuves --out=$O/16_coop_4_joueurs.png
$G --scene=landmark --floor=1 --force-map=terrasses_rizieres_hautes --no-epreuves --out=$O/17_repere_terrasses_noria.png
```

Menus (`game/tests/capture_store_menu.tscn`) : écrit `select.png` (grille) et `sheet.png` (fiche de la carte `--pick=<n>`, 2 = Taliant) dans `--out=<dossier>` ; à renommer en `08_` et `09_`.

```
sh art/tools/vfx_test/godot_locked.sh res://tests/capture_store_menu.tscn -- --out=<dossier absolu> --pick=2
```

## Limites connues

- Les PNG ne sont pas recompressés (aucun optimiseur PNG installé) : 0,4 à 2,8 Mo chacun, sous les limites de Steam.
- Variante B de la forêt (`foret_mangrove_lanternes`) : pas de repère, non capturée. Variante B des Cryptes : non retenue.
- Fin de run (13) : chiffres de mise en scène incohérents entre eux (00:04, niveau 1, 1873 monstres) ; à ne pas retenir en vitrine telle quelle.
- Étiquettes de prix de coffre « N or (-N) » visibles sur les captures de run (or du joueur à 0).
- Les captures de run affichent le niveau 1 et peu d'or : les objets sont donnés d'office, pas gagnés.
- La texture d'ombre `shadow_blob_256` est signalée absente au lancement (repli neutre), sans effet visible sur ces images.
- L'écran titre n'est pas retenu : il affiche le bouton « Mode test » et « Version 0.1.0 » (à retirer avant la sortie, voir CLAUDE.md).
