# Checklist de sortie 1.0

Tout ce qui doit être retiré, masqué ou remis avant la sortie (Steam, Google Play, App Store). Établie le 11/11/2026 à partir de `CLAUDE.md` et d'une recherche dans `game/` et `docs/` (`AVANT LA SORTIE`, `avant la sortie`, `TEST_BUILD`, `test_only`, `--unlock-variants`). Ce document est une liste : aucun de ces réglages n'est modifié ici. Les numéros de ligne sont ceux du 11/11/2026 ; les rechercher par texte si le fichier a bougé.

Légende : **Retirer** = supprimer le code ou la donnée ; **Masquer** = garder le code mais le rendre inaccessible dans la version vendue ; **Remettre** = changer une valeur ; **Décider** = choix du joueur à trancher.

## 1. Personnages : déblocages à remettre

Mécanisme : `Profile.is_character_available` considère comme jouable tout personnage dont `data/characters.json` porte `"unlocked": true` (`scripts/save/profile.gd` ~l.481-496). Pour remettre une condition, passer `"unlocked"` à `false` ; la règle de déblocage réelle vit déjà dans `profile.gd` (`UNLOCK_ON_OBJECTIVE` l.33-38, `UNLOCK_ON_RUN` l.42-48, `AVARE_PURSE_P` l.50). Seuls Ardent (`DEFAULT_CHARACTERS`, l.27) et Tocsin restent ouverts dès le départ.

| # | Quoi | Où | Valeur actuelle → sortie | Condition de déblocage validée (06/11/2026) |
|---|---|---|---|---|
| 1 | Rictus ouvert | `game/data/characters.json` l.90 `"unlocked"`, l.94 `"hidden"` | `true` / `false` → `false` / `true` | 200 monstres tués à moins de 2 u (`close_kills`, cumul toutes runs) |
| 2 | Averse ouverte | `characters.json` l.236 | `true` → `false` (hidden reste `false`) | 60 s cumulées dans l'eau en une run (`water_s`) |
| 3 | Arpenteuse ouverte | `characters.json` l.293 | `true` → `false` | 300 monstres tués par une zone persistante (`zone_kills`, cumul) |
| 4 | Rainette ouverte | `characters.json` l.347 `"unlocked"`, l.349 `"hidden"` | `true` / `false` → `false` / `true` | finir un étage sans être touché au contact (`clean_floors`) |
| 5 | Avare ouvert | `characters.json` l.401, l.403 | `true` / `false` → `false` / `true` | finir une run avec plus de 4 P d'or (`purse_over`, `AVARE_PURSE_P`) |
| 6 | Bourbe ouverte | `characters.json` l.455 | `true` → `false` | tuer 3 élites avec des familiers (`familiar_elite_kills`, cumul) |
| 7 | Vigie ouverte | `characters.json` l.509 | `true` → `false` | 100 monstres tués à plus de 8 u en une run (`far_kills`) |
| 8 | Taliant (id `morfil`) ouvert | `characters.json` l.563 | `true` → `false` | vaincre un boss d'étage en subissant au plus 3 coups (`light_boss_kills`, n'importe quel perso) |
| 9 | Grésille ouverte | `characters.json` l.618 | `true` → `false` | 100 monstres foudroyés par l'Éclair en bouteille (`lightning_kills`, cumul) |
| 10 | Grésille cachée ou non | `characters.json` l.621 `"hidden"` | `false` → **Décider** | `CLAUDE.md` ne le dit pas : seuls Rictus, Rainette et Avare sont cachés ; garder `false` par défaut |

Vérification : `unlock_conditions_test`, `character_switch_test`, `character_sheet_ux_test` ; puis en jeu avec un profil neuf : seuls Ardent et Tocsin sélectionnables (mode test = bac à sable, ne pas s'y fier). Sur un profil neuf, `Profile.is_character_available(&"rictus")` doit renvoyer `false`.

Attention : `tests/*_variants_test` et `forge_test` peuvent supposer certains persos ouverts ; relancer toute la suite après la remise.

## 2. Interrupteur de test des variantes

| # | Quoi | Où | Valeur actuelle → sortie | Vérification |
|---|---|---|---|---|
| 11 | `RAINFALL_UNLOCK_ALL_VARIANTS=1` / `-- --unlock-variants` : toutes les variantes de sorts, objets et skins affichés débloqués (rien écrit au profil) | `game/scripts/save/profile.gd` l.52-55 (constantes `UNLOCK_ALL_VARIANTS_ENV`, `UNLOCK_ALL_VARIANTS_ARG`), l.111 (`unlock_all_variants`), l.437-441 (`is_unlocked`), l.884-888 (`_detect_unlock_all_variants`) | présent → **Retirer** (ou ne lire que dans un build debug : `OS.is_debug_build()`) | `grep -rn "UNLOCK_ALL_VARIANTS\|unlock-variants" game/scripts` vide |
| 12 | Mentions et test associés | `game/scripts/save/item_unlocks.gd` l.8, `variant_unlocks.gd` l.14, `game/CONTRACTS.md` l.215, `game/tests/variants_test.gd` l.295-301 | à adapter au retrait (le test doit viser le nouveau comportement) | `variants_test` OK |

## 3. Mode test (À RETIRER OU MASQUER)

Code concerné, à retirer ou à rendre inatteignable dans les builds de sortie. Option conseillée : masquer derrière un drapeau `OS.is_debug_build()` unique dans `TestMode`, et retirer les dossiers de l'export.

| # | Quoi | Où | Sortie | Vérification |
|---|---|---|---|---|
| 13 | Bouton « Mode test » de l'écran titre (ligne Coop locale et variante seule) | `game/scripts/menu/title_screen.gd` l.20, ~l.325-331 (`test_button`, `test_mode_requested`) | Masquer ou Retirer | `title_screen` : aucun nœud `TestMode` ; `test_mode_test` adapté |
| 14 | Démarrage direct `-- --test-mode` | `game/scripts/app/app.gd` l.53 (`TestMode.requested_by_arg()`), l.70 (`start_test_mode`), l.153 (connexion du signal) ; `game/scripts/core/test_mode.gd` l.18 (`ARG`), l.56 | Retirer | l'argument ne fait plus rien |
| 15 | Panneau, bulles et overlay en run | `game/scripts/game/main.gd` l.206 (`TestOverlay.attach`), l.356 (ajout d'un joueur local en test) ; `game/scripts/game/coop_local.gd` l.13 (`arm_join`) | Retirer l'accroche | `grep -rn "TestOverlay" game/scripts` vide hors `testmode/` |
| 16 | Autoload `TestMode` (drapeaux de triche : PV illimités, recharge 0, portée infinie, or infini, `vfx_test`, `ambient_d`) | `game/project.godot` l.31 ; `game/scripts/core/test_mode.gd` ; accroches dans `player.gd`, `spell_caster.gd`, `run_state.gd`, `skins.gd`, `stage_manager.gd`, `profile.gd` (`begin_sandbox`) | Retirer ou rendre inerte (`active` jamais vrai) | `grep -rn "TestMode\." game/scripts` ne reste que dans le code retiré |
| 17 | Dossier `scripts/testmode/` (15 scripts : `map_perf_bench`, `test_boss_adapter`, `test_bubbles`, `test_hud_hider`, `test_loop_tools`, `test_maps`, `test_muted_input`, `test_overlay`, `test_panel`, `test_poutch`, `test_thumbs`, `test_tools`, `vfx_gallery`, `vfx_swap`, `vfx_test_player`) | `game/scripts/testmode/` | Retirer du build (filtre d'export) | export sans `scripts/testmode/*` |
| 18 | Arène de test | `game/scenes/stage/test/test_arena.tscn`, `game/data/maps/test_arena.json` (`"test_only": true` l.6, `_doc` l.2) ; filtre `stage_manager.gd` l.405 | Retirer ou exclure de l'export (le filtre `test_only` la garde hors tirage, mais le fichier reste livré) | `StageManager` : aucune carte `test_only` tirée ; `map_catalog` OK |
| 19 | Onglet « Cartes », D d'ambiance, banc de perf | `test_maps.gd`, `map_perf_bench.gd`, `game/tests/map_perf_bench.tscn`, `TestMode.ambient_d`, `ambient_events.gd` l.35-36 ; option `-- --ambient-d=<D>` (`test_mode.gd` l.25) valable **hors mode test** : à retirer aussi | Retirer l'option avec le mode test | `grep -rn "ambient-d" game/scripts` vide |
| 20 | Raccourcis de test : F1 (panneau), Select maintenu 0,5 s (manette), bouton « TEST » tactile | `test_overlay.gd`, `test_bubbles.gd`, `InputSetup` si une action dédiée existe | Retirer avec le panneau | aucune action `test_*` dans `InputSetup` |
| 21 | Documentation du mode test | `CLAUDE.md` (entrée « Mode test »), `docs/Design_Variantes_B.md` §7.2, §« Vérifier en mode test » (~l.422), `docs/Mesures_Perf_Android.md` l.9-11 | Réécrire ou archiver | relecture |

Test : `test_mode_test`, `spell_auto_aim_test` (les sorts automatiques sont une triche du mode test : vérifier ce qui reste utile).

## 4. VFX de test pixelfx (À RETIRER)

| # | Quoi | Où | Sortie | Vérification |
|---|---|---|---|---|
| 22 | 152 effets de sorts et boss pixelfx | `game/assets/sprites/vfx_test/` (27 dossiers à la racine) ; code `scripts/testmode/vfx_swap.gd`, `vfx_test_player.gd`, `vfx_gallery.gd` ; brief `art/briefs/vfx_test_pixelfx.md` | Retirer le dossier et le code, ou exclure de **tous** les exports | taille du paquet |
| 23 | Filtres d'export | `game/export_presets.cfg` : `assets/sprites/vfx_test/*` présent **seulement** dans le preset Android (`exclude_filter` l.87) ; absent des presets Windows (l.16), iOS (l.316) et Web (l.585, filtre vide) | ajouter le filtre aux presets Windows et iOS (ou retirer le dossier) | exporter et lister le `.pck` : aucun `vfx_test` |

## 5. Journal de run (RunLog) et réglages

| # | Quoi | Où | Valeur actuelle → sortie | Vérification |
|---|---|---|---|---|
| 24 | `RunLog.TEST_BUILD` : journal actif par défaut | `game/scripts/telemetry/run_log.gd` l.44-46 (`const TEST_BUILD := true`), l.120 (défaut du réglage `[telemetry] run_log`) | `true` → **Décider** : le joueur a tranché le 06/11/2026 « gardé actif dans la version vendue », mais le commentaire dit « À REVOIR AVANT LA SORTIE » ; renommer la constante (elle n'est plus un « build de test ») et mettre à jour le commentaire | `run_log_test` l.28 (« journal activé par défaut ») à ajuster au nom |
| 25 | Bouton « Exporter les journaux » dans le sous-menu « Avancé » (décidé le 06/11/2026) | `game/scripts/ui/settings_panel.gd` l.128-133, l.244-251 (`_advanced_button`, `_export_row`) ; `RunLogExport` | fait (déjà dans « Avancé », replié à l'ouverture) → à re-vérifier | `settings_panel_test` / test d'UI correspondant ; export clavier, souris, manette, tactile |
| 26 | Mention de confidentialité du journal (rien ne quitte l'appareil sans export volontaire) | fiche store (`docs/Fiche_Play_Store.md`), politique de confidentialité Steam / App Store | à écrire / relire | relecture |

## 6. Plateformes

| # | Quoi | Où | Vérification |
|---|---|---|---|
| 27 | Aucun bouton Quitter sur iOS : écran titre et menu pause | `game/scripts/menu/title_screen.gd` l.333 (`Platform.can_quit() and not ios_override`), `game/scripts/ui/pause_menu.gd` l.157-159, `game/scripts/core/platform.gd` l.120-139 (`is_ios`, `can_quit`) | `pause_menu_test` l.85-88, `platform_input_test` l.23 ; exporter iOS et regarder les deux menus |
| 28 | Orientation paysage forcée, base 1920×1080 `keep_height` | `game/project.godot` l.37-41 (`window/handheld/orientation=4`) | lancer sur téléphone : les deux paysages, pas de portrait |
| 29 | Contrôles tactiles masqués sur PC sans écran tactile ; jeu payant sans pub ni achat | `CLAUDE.md` « Décisions » ; chercher toute trace de pub ou d'achat (`grep -rni "admob\|ads\|iap\|rewarded" game/`) | grep vide ; test d'entrée de plateforme |
| 30 | Numéros de version incohérents | `game/project.godot` l.14 `config/version="0.1.0"` ; `export_presets.cfg` l.118-119 Android `version/code=3`, `version/name="0.1.3"` ; `docs/Fiche_Play_Store.md` l.5 (état au 28/10, version 0.1.2) | passer toutes les versions à `1.0.0` (Android : `version/code` incrémenté) ; iOS et Windows aussi (`application/file_version`, `product_version` vides l.51-52) | relecture des trois presets |
| 31 | Signature et identifiants de release | `export_presets.cfg` Android (`package/signed=true`, `package/unique_name="com.Rainfall.game"`), keystore de release, profil iOS, Steam (AppID, dépôt) | à vérifier hors dépôt (jamais de clé dans git) | export release signé |
| 32 | Preset Web | `export_presets.cfg` l.577-585 (`exclude_filter` vide) : le jeu n'est pas prévu sur le Web | supprimer le preset ou ne jamais l'exporter | relecture |
| 33 | Build de debug vs release | exporter en **release** (pas « Export With Debug ») : `OS.is_debug_build()` figure dans le journal de run (`run_log.gd` l.188) | vérifier `"debug": false` dans un JSON de run issu du build de sortie |

## 7. Épreuves et autres drapeaux de fonctionnalité

| # | Quoi | Où | Valeur | Vérification |
|---|---|---|---|---|
| 34 | `Balance.EPREUVES_ENABLED` | `game/scripts/core/balance.gd` l.1151-1152 (`var EPREUVES_ENABLED := true`), l.1260 ; options `-- --epreuves` / `-- --no-epreuves` | `true` (décision du 07/11/2026 : activé dès la fusion E0-E5) → garder `true` ; retirer les options de ligne de commande de debug si on veut | `balance_test`, test des épreuves |
| 35 | Options de ligne de commande de debug | `-- --force-secret=<étage>` (`game/scripts/stage/floor_plan.gd` l.123, l.149-158), `-- --force-trigger=...` (docs/Design_Variantes_B.md §9-12), `-- --no-epreuves` | inoffensives pour le joueur ; **Décider** de les garder ou de les limiter au debug | `grep -rn "get_cmdline_user_args" game/scripts` : relire chaque option |
| 36 | Coop locale PC dans la 1.0, coop en ligne (EOS) **après** la sortie | `docs/Design_Multijoueur.md`, `docs/multi/` ; aucun code EOS ni bouton « En ligne » ne doit apparaître en 1.0 | `grep -rni "eos\|en ligne" game/scripts/menu` : rien d'actif |
| 37 | Ajout d'un joueur manette en cours de run | `game/scripts/game/main.gd` l.356, `coop_local.gd` l.13 (« À RETIRER OU MASQUER » dans le commentaire, car appelé par le panneau de test) | vérifier que le menu coop de la 1.0 offre son propre chemin pour rejoindre | test de coop locale |

## 8. Contenu et données

| # | Quoi | Où | Sortie | Vérification |
|---|---|---|---|---|
| 38 | Gel des boss : aucun nouveau boss, les boss existants sont revus après le rééquilibrage des personnages et des objets | `CLAUDE.md` « Gel des boss » | vérifier que ce rééquilibrage a eu lieu avant la sortie | `docs/audits/`, `balance_sim_run` |
| 39 | Props fixes des variantes B produits avant la sortie (noria, épouvantails, escaliers de pierre, creuset, rails, wagonnets…) | `docs/Design_Variantes_B.md` §7-8 (~l.136, 269, 379) ; une texture absente est ignorée sans erreur | sprites Codex livrés pour les 4 B | rendre chaque carte B en mode test avant le retrait du mode test (ordre : vérifier **puis** retirer) |
| 40 | Items verrouillés (11 objets, champ `"unlock"` de `game/data/items.json`) | `docs/Items_Catalog.md` l.170 ; `scripts/save/item_unlocks.gd` | l'interrupteur de test (n° 11) les débloque aussi : vérifier le comportement sans lui | `item_unlocks_test` |
| 41 | Conseils de chargement | `game/data/tips.json` (3 conseils de Grésille ajoutés le 11/11/2026) | relire avec le jeu final | `floor_card_test`, `onboarding_test` |
| 42 | Skins cosmétiques et rubis : les rubis n'achètent que du cosmétique | `docs/Boutique_Rubis.md` ; aucun skin ne doit donner d'avantage de jeu | relecture | — |
| 43 | Fiche de store et textes légaux | `docs/Fiche_Play_Store.md` (« À relire avant la sortie »), captures, icône v3 réaliste, classification d'âge, politique de confidentialité | à relire avec les chiffres de contenu de la 1.0 | relecture |
| 44 | Rubriques de docs « À trancher par le joueur » encore ouvertes | `docs/Design_Variantes_B.md` ~l.439 (départ excentré, porte scellée des Terrasses B…) ; audit `docs/ux/Audit_Entrees_Accessibilite.md` l.56 (**BLOQUANT** = à corriger avant la sortie) | relire tous les « BLOQUANT » | grep des lignes BLOQUANT non résolues |

## 9. Performance et poids

| # | Quoi | Où | Vérification |
|---|---|---|---|
| 45 | Budget de textures (Android 180 Mo, plus de normal maps) | `game/tests/texture_budget.json`, test de budget associé ; fichiers `_n.png` archivés dans `art/archive_normals/` | test de budget de textures OK |
| 46 | Mesures de perf sur téléphone (9 cartes × 3 paliers) | `docs/Mesures_Perf_Android.md` : à faire **avant** de retirer le banc de perf (n° 19) | résultats consignés |
| 47 | Anciens assets provisoires de Claude à remplacer par ceux de Codex (liste dans `CLAUDE.md` « Fin de l'exception ») | `art/tools/<famille>/_r*.txt` | vérifier lot par lot que plus aucun livrable provisoire ne reste (formes en code `Polygon2D` / `_draw` marquées placeholder) : `grep -rn "placeholder\|PLACEHOLDER" game/scripts` |

## Total

47 lignes numérotées (n° 1 à 47) ; 9 personnages à refermer (n° 1-9), 3 à recacher (Rictus, Rainette, Avare).

## Points douteux, à trancher par le joueur

- Grésille cachée ou visible dans la liste avant son déblocage (n° 10).
- `RunLog.TEST_BUILD` : valeur `true` gardée (décision du 06/11) mais nom et commentaire à corriger (n° 24).
- Options de ligne de commande (`--force-secret`, `--force-trigger`, `--ambient-d`, `--no-epreuves`) : garder en debug seulement ou retirer (n° 19, 35).
- Id technique `morfil` (Taliant) : ne pas le renommer au retrait des conditions (n° 8).
- Les 3 conseils de Grésille sont rédigés avec le préfixe « Grésille : » car `tips.json` est une liste commune à tous les personnages (n° 41).

## Vérification automatique proposée : `release_check_test`

Test headless `game/tests/release_check_test.tscn` (+ `.gd`), à lancer par le script de build de sortie, `RESULT: OK` seulement si la version est « propre ». Il ne modifie rien ; il lit les données et le code. Deux modes : `-- --release` (strict, sortie) et sans argument (informatif : liste les écarts sans échouer, pour suivre l'avancement pendant le développement).

Contrôles proposés :

1. **Personnages** : parcourir `data/characters.json` ; pour chaque personnage hors Ardent et Tocsin, `"unlocked"` doit valoir `false` ; Rictus, Rainette et Avare doivent avoir `"hidden": true` ; Ardent et Tocsin `"unlocked": true`. La liste attendue des 12 ids est codée dans le test pour attraper l'ajout accidentel d'un personnage de test.
2. **Règles de déblocage** : chaque personnage verrouillé possède une entrée dans `Profile.UNLOCK_ON_OBJECTIVE` ou `UNLOCK_ON_RUN` (clé `character:<id>`), avec les seuils validés du 06/11 (200, 60 s, 300, 1, 4 P, 3, 100, 100 de Grésille, 1 coup...).
3. **Interrupteur de variantes** : `Profile.unlock_all_variants` doit être `false` même avec `OS.set_environment("RAINFALL_UNLOCK_ALL_VARIANTS", "1")` (ou l'API est absente) ; recherche textuelle de `UNLOCK_ALL_VARIANTS` et `--unlock-variants` dans `res://scripts` : zéro occurrence.
4. **Mode test** : `TestMode` absent des autoloads (lecture de `ProjectSettings`) ou inerte ; `TestMode.requested_by_arg()` faux même avec `--test-mode` ; aucun bouton `TestMode` dans l'instance de `TitleScreen` ; `StageManager` ne propose aucune carte `test_only` ; absence de `data/maps/test_arena.json` en strict.
5. **VFX de test** : `res://assets/sprites/vfx_test/` absent, ou présent mais cité par le filtre d'export de **chaque** preset de `export_presets.cfg` (Windows, Android, iOS) ; en strict : absent.
6. **Journal** : valeur par défaut de `RunLog.enabled()` conforme à la décision (actif) ; `SettingsPanel` : le bouton d'export est dans la rangée « Avancé » repliée à l'ouverture.
7. **iOS** : avec `Platform` simulé iOS (si l'API le permet) ou en lisant `can_quit()` : `TitleScreen` et `PauseMenu` n'ont pas de bouton Quitter (ces assertions existent déjà dans `pause_menu_test` et `platform_input_test` ; le test de sortie les rappelle).
8. **Versions** : `config/version` de `project.godot` et `version/name` de chaque preset non vides et égaux ; `version/code` Android supérieur à celui de la dernière release (valeur de référence dans le test).
9. **Drapeaux** : `Balance.EPREUVES_ENABLED == true` ; pas de `print` ni de `push_warning` de debug listés (liste blanche) dans les scripts de boot.
10. **Pas d'argent réel** : recherche textuelle de `admob`, `rewarded`, `iap`, `in_app` dans `res://scripts` et `export_presets.cfg` : zéro occurrence.
11. **Conseils** : `data/tips.json` est un tableau non vide de chaînes, sans doublon, aucune chaîne vide.
12. **Bilan** : le test affiche le nombre d'écarts par catégorie (`RELEASE: <n> écarts`) pour suivre l'avancement.

Codes de sortie : en mode strict, `RESULT: OK` si zéro écart, `RESULT: FAIL` sinon avec chaque écart sur une ligne (`n° checklist : fichier : valeur actuelle → attendue`). Les numéros de la checklist (colonne `#`) servent de clés stables pour que chaque écart renvoie à une ligne de ce document.
