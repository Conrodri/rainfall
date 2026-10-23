---
name: balance-check
description: Audit d'équilibrage de Rainfall à partir des sources du projet (balance.gd, JSON de game/data, simulateur Python, balance_sim Godot). À utiliser pour vérifier un personnage, un item, un boss ou mini-boss, ou l'économie (or, coffres, loot, pitié) et produire un rapport type - TTK, DPS par niveau, écarts entre personnages, stratégies dégénérées, recommandations chiffrées. Argument - "perso <id>", "item <id>", "boss <id>" ou "economie".
---

# Balance check (Rainfall)

Audit en lecture seule. On ne modifie ni `balance.gd` ni les JSON : on mesure, on compare aux cibles, on recommande.
Sorties temporaires (JSON de simulation, scripts de calcul) dans le scratchpad de la session, jamais dans le dépôt.

## 0. Données insuffisantes : vérifier avant tout rapport
Lister les entrées nécessaires et marquer chacune **TROUVÉ** ou **ABSENT**. Une section dont une entrée manque est
**NON ÉVALUÉ - PAS DE DONNÉES** (dire quoi manque). Ne jamais estimer à partir d'un fichier voisin pour remplir une case.
Un kit absent ou un test qui ne compile pas n'est pas un succès : « RESULT: OK » prouve l'absence d'erreur, pas l'équilibre.

## 1. Domaine
- **perso <id>** : `game/data/characters.json`, `game/scripts/spells/<id>_kit.gd`, `docs/fiches/<id>.md`, `docs/Design_Personnages.md`.
- **item <id>** : `game/data/items.json`, `docs/Items_Catalog.md`, clés de stats de `game/CONTRACTS.md`, Maths §9 (empilement).
- **boss <id>** : `game/data/floors.json`, `minibosses.json`, `docs/Design_Boss_Cartes.md`, `docs/Comportements_Monstres.md`, Maths §5.
- **economie** : `game/scripts/core/run_state.gd`, Maths §7-8 (économie, loot par dés, pitié) et §14, `docs/GDD.md`.
- Toujours : `game/scripts/core/balance.gd` (formules en vigueur) et `docs/Maths_Scaling.md` **§14 Alignement RoR2** (cibles).
  Noter chaque fichier lu : ils forment la section « Sources » du rapport.

## 2. Cibles
Prendre les cibles dans Maths_Scaling (§11 courbe de puissance, §12 résultats, §14) et le GDD :
monstre de base tué en 1-2 coups, paquets de 3-8, run 18-20 min, télégraphes ≥ 0,8 s, plafond de dégâts par coup 25 % des PV max
(40 % boss), écart de DPS entre personnages ±20 % autour d'Ardent (référence du simulateur). Une valeur sans cible écrite
va dans « Valeurs sans plage cible (non jugées) », ni conforme ni aberrante.

## 3. Mesures
Exécutables : `PY="C:\Users\const\AppData\Local\Python\bin\python.exe"`,
`G="C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"`, depuis la racine du dépôt.
1. **Formules pures** : `$G --headless --path game --script res://tests/test_balance.gd`.
2. **Combats scriptés** (personnage, item porté par un perso, mini-boss) :
   - fumée : `$G --headless --path game res://tests/balance_sim_test.tscn` ;
   - rapport : `$G --headless --path game res://tests/balance_sim_run.tscn -- --chars=ardent,<id> --scen=swarm,mixed,elite,miniboss --cfg=L1,L6,L12 --out=<scratchpad>/sim.json`
     (Ardent toujours inclus comme référence). Mesures : DPS effectif, temps pour tout tuer, dégâts subis, morts, kills/min, lancers par slot.
3. **Run entière, or et durées** (modèle v3 historique, ordre de grandeur) : `$PY docs/simulateur_scaling.py moyen` ;
   vérifier d'abord que ses constantes concordent avec `balance.gd`, sinon le signaler et pondérer la conclusion.
4. **Tests ciblés** : `res://tests/economy_test.tscn`, `loot_test.tscn`, `boss_pace_test.tscn`, `<boss>_boss_test.tscn`, `<perso>_test.tscn`.
5. **Calcul à la main** (item non encore codé, variante de valeur) : script Python ad hoc dans le scratchpad ; résultat marqué « estimé ».

## 4. Analyses par domaine
- **Combat** : DPS par niveau (L1, L6, L12) et par scénario ; TTK monstre de base, élite, mini-boss, boss d'étage ; option strictement
  dominante ; états invulnérables ou soins infinis ; respect du plafond de dégâts et des télégraphes.
- **Item** : apport marginal par pile (1, 5, 10, 20 piles), forme de la courbe (linéaire, hyperbolique, plafonnée), synergies à risque
  (crit × proc, CDR × zone, soin × armure), coût en perf (procs en chaîne, projectiles par kill).
- **Boss** : PV selon D et étage, durée du combat par perso (cible Maths §5), densité de télégraphes, fenêtres d'attaque, coups non lisibles.
- **Économie** : sources d'or par minute et par étage, puits (coffres, relances, piliers), coffres achetables par étage, surplus ou
  déficit ; boucle de farm infinie ; probabilités de rareté et pitié (tirages moyens avant chaque rareté) ; rubis par run.

## 5. Rapport type
```
## Balance check : <cible> (<date>)
### Sources (fichiers lus, commandes lancées, TROUVÉ/ABSENT)
### Verdict : NON ÉVALUÉ | SAIN | À SURVEILLER | CRITIQUE
### TTK
| Cible | L1 | L6 | L12 | Cible doc | Écart |
### DPS par niveau et scénario
| Perso | Scénario | L1 | L6 | L12 | vs Ardent |
### Écarts entre personnages (hors ±20 % signalés)
### Valeurs aberrantes
| Constante/clé | Plage cible | Actuel | Problème |
### Stratégies dégénérées
- <stratégie>, pourquoi elle domine, contre-jeu existant ou absent
### Recommandations chiffrées
| Priorité | Constante `Balance` ou clé JSON | Actuel → proposé | Plage sûre | Effet attendu (TTK, DPS, or) |
### Valeurs sans plage cible (non jugées)
### Limites (mesuré / estimé / non vérifié)
```
Verdict, au pire constat : **CRITIQUE** = stratégie qui domine tout, progression bloquée, boucle d'or sans puits, mort possible
sans télégraphe ; **À SURVEILLER** = aberrations corrigeables par réglage ; **NON ÉVALUÉ** = données manquantes (dire lesquelles) ;
**SAIN** = tout jugé contre une cible, rien hors plage.

## 6. Suite
Rendre le rapport à l'orchestrateur (ou au joueur). L'écrire dans `docs/` seulement si on le demande. Les corrections de valeurs
sont faites par un agent dev dans `balance.gd` ou les JSON, puis on relance ce balance-check pour vérifier.

Adapté de Claude-Code-Game-Studios (MIT, Donchitos)
