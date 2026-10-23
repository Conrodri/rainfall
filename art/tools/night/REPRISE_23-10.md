# Reprise après l'arrêt volontaire du 23/10/2026 (quota hebdomadaire Claude)

Arrêt demandé par le joueur (quota hebdo à 3 %). Chaque agent s'est arrêté à un point stable et a écrit son état dans `art/tools/night/reprise/<perso>.md`.

## État au moment de l'arrêt
- **File Codex** (`art/tools/night/night_queue.sh`) : laissée en marche (quota Codex séparé). Corrigée ce matin : saute les groupes déjà finis. Le 23/10 vers 08:16, elle en était au groupe 15. Si elle est morte, relancer `sh art/tools/night/night_queue.sh` (les lots finis sont sautés ; `night_report.md` est réécrit, l'ancien est copié dans `night_report_part3.md`). Elle ne lit `queue.txt` qu'au démarrage : les briefs de variantes ajoutés ensuite (`_ardv`, `_ricv`, `_avav`, `_avsv`, `_vigv`, `_talv`, `_tocv`, `_arpv`, `_rainv`, `_bouv`) demandent une relance après « FILE TERMINÉE ».
- **Tests de boss** : `jar_bearer`, `deep_eel` et `crane` sont verts (correctif dans `crane_brain.gd`). **UX** : `spell_tooltip_test` et `hud_overlays_test` sont verts (appui long à 0,6 s + glissement de 12 px dans `spell_button.gd`). Suite complète du matin : 97/116 ; le reste, ce sont des captures ou des mesures, plus 3 tests de perf à refaire sur une machine calme (`enemies_perf`, `enemies_map_test`, `render_perf_test`).
- **Équilibrage** (`docs/Equilibrage_Personnages.md` §5) : P1 à P8 appliqués, plus la Grêle de Vigie. Décision du joueur appliquée : l'attaque auto ne prend plus `zone_damage_add` (`spell_caster.gd compute_damage`, `CONTRACTS.md`). Écarts restants : Rictus et Avare au-dessus de la cible (resserrage confié aux agents de variantes), Arpenteuse « mixed » à 0,55 (pilote de chaîne à ajouter), Taliant élite L12 à 1,26, Rainette mini-boss L12 à 0,79.
- **Variantes de sorts** (`docs/Variantes_Sorts.md`, lot 0 fait) : 10 agents en cours, un par personnage, chacun propriétaire de son kit et de son entrée dans `characters.json`. Voir `reprise/<perso>.md`.
- **Retours du joueur en cours** :
  - Arpenteuse : la chaîne ne s'ancre pas au sol, angles bizarres, prise en main difficile (agent Arpenteuse, prioritaire).
  - Rainette : sauts ratés, charges de déplacement peu lisibles (agent Rainette, prioritaire).
  - Portée des autos de mêlée trop courte : Rictus 2,5 -> 3,0 u ; Avare 2,0 -> 2,6 u ; Bourbe 2,0 -> 2,6 u ; Taliant cercle 2,3 -> 2,8 u, estoc 3,2 -> 3,6 u. Vérifier que le visuel couvre la hitbox en iso 2:1.

- **Orchestrateur (core)** : retirer l'enfant Emission quand `NormalMaps.emission_frames` rend null (`EmissiveOverlay.apply`), car l'overlay d'Ardent reste branché sur les autres persos (erreurs « Animation 'plant_e' doesn't exist » d'Arpenteuse). Arpenteuse : brief Codex des masques `<anim>_e.png` à écrire. Bourbe : `Decoy.PROVOKE_RANGE_U` fixe à 4 u (grosse motte prévue à 5 u), description JSON de `detacher` périmée.

- **Contrats proposés par l'agent Ardent** : `SpellCaster` diffère les effets seulement si `_kit()==null`, donc avec une variante (et donc un kit), les sorts de base d'Ardent partent sans attendre la frame d'impact (proposition : hook `kit.defers_effects()`) ; signal `spell_hit(spell, enemy, amount)` pour des compteurs exacts. `character_data.gd apply_loadout` modifié (+4 lignes, méta `kit_script`) : à relire.

## À la reprise
1. Lire `reprise/*.md`, relancer un agent par personnage non terminé (style ultracave, voir CLAUDE.md).
2. Lancer une simulation globale des 10 personnages (`balance_sim.py --seeds 3`) une fois les kits stables, puis la suite complète des tests.
3. Machine calme : refaire les 3 tests de perf.
4. Relancer la file Codex pour les briefs de variantes.

## Builds (23/10 matin)
- Dépôt git : https://github.com/Conrodri/rainfall (privé), commit initial poussé.
- Installés : templates Godot 4.7.2 (`%APPDATA%/Godot/export_templates/4.7.2.stable`), JDK 17 (`%LOCALAPPDATA%/Programs/jdk-17.0.20.1+1`, renseigné dans editor_settings-4.7.tres, sauvegarde .bak), Android cmdline-tools (`%LOCALAPPDATA%/Android/Sdk/cmdline-tools/latest`).
- `build/windows/Rainfall.exe` exporté (1,4 Go : le filtre d'export inclut tests et sources, à restreindre).
- Preset Android : AAB Gradle, package `com.rainfall.game` (= Play Console). RESTE : `sdkmanager --licenses` (accord du joueur requis) + platform-tools/build-tools/platforms ; installer le gabarit de build Android (Projet > Installer le modèle de build Android) ; clé de publication créée PAR LE JOUEUR (keytool) et saisie par lui dans le preset ; export AAB ; upload dans Tests internes (liste de testeurs : le joueur en crée une nouvelle, NE PAS cocher « Testeur »).
