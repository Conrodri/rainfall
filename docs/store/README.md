# Captures d'écran pour la page Steam

Neuf captures 1920x1080 du vrai jeu (rendu en fenêtre, pas en headless), générées le 11/11/2026. Aucun panneau de test ni texte de debug n'est visible : le mode test n'est pas utilisé, seuls l'invulnérabilité du joueur, quelques objets donnés et les monstres invoqués sont forcés par les scènes de capture. Les épreuves sont coupées (`--no-epreuves`) pour que la carte reste lisible.

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

## Régénérer

Depuis la racine du dépôt, sans `--headless` (la lecture du viewport demande une fenêtre). Le wrapper ajoute `--path game` et prend le verrou partagé. Le premier lancement après un import compile les shaders et peut durer plusieurs minutes.

Scène de run (`game/tests/capture_store_run.tscn`, arguments après `--`) : `--scene=horde|boss|forge|coop`, `--floor=<1-5>`, `--char=<id>`, `--seed=<n>`, `--force-map=<id>` (variante de carte), `--out=<fichier.png>` (chemin absolu conseillé), `--no-epreuves`.

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
```

Menus (`game/tests/capture_store_menu.tscn`) : écrit `select.png` (grille) et `sheet.png` (fiche de la carte `--pick=<n>`, 2 = Taliant) dans `--out=<dossier>` ; à renommer en `08_` et `09_`.

```
sh art/tools/vfx_test/godot_locked.sh res://tests/capture_store_menu.tscn -- --out=<dossier absolu> --pick=2
```

## Limites connues

- Les PNG ne sont pas recompressés (aucun optimiseur PNG installé) : 0,4 à 2,8 Mo chacun, sous les limites de Steam.
- Manquent encore : boss de raid, boss final (étage 5, La Source), coffre et choix d'objet, fin de run, coop à 4 joueurs, variantes B des cartes. Ajouter une valeur de `--scene` dans `capture_store_run.gd` pour chacun.
- Les captures de run affichent le niveau 1 et peu d'or : les objets sont donnés d'office, pas gagnés.
- La texture d'ombre `shadow_blob_256` est signalée absente au lancement (repli neutre), sans effet visible sur ces images.
- L'écran titre n'est pas retenu : il affiche le bouton « Mode test » et « Version 0.1.0 » (à retirer avant la sortie, voir CLAUDE.md).
