# Multijoueur coop 1 à 4 joueurs : synthèse (01/11/2026)

Synthèse des trois études du dossier `docs/multi/` :
- `Archi_Reseau.md` : architecture et réseau (audit du code, transport, plan).
- `Scaling_Multi.md` et `sim_multi.py` : scaling façon Risk of Rain 2, simulation de 1 à 4 joueurs.
- `Design_Coop.md` : boucle coop, partage, mort, lisibilité, interface.

Statut (11/11/2026) : **la coop locale PC, étapes 1 à 4 du plan, est codée** (registre `Players`, état par joueur, refactor N joueurs, director multi-cibles, lobby de manettes, caméra commune avec laisse, plaques HUD, menus et réticules par joueur ; tests `players_registry_test`, `coop_player_test`, `coop_ui_test`, `coop_stage_test`, `director_multi_perf_test`). **Le jeu en ligne (étapes 5 à 10, EOS) n'est pas codé** : il est prévu dans une mise à jour après la sortie (décision du 06/11/2026). Les points marqués « À trancher » attendent le joueur ; les pings, la roue de messages, le veto du téléporteur et la cagnotte du légendaire restent à arbitrer.

## 1. Périmètre et technique

- **Ordre recommandé** :
  1. refactor « N joueurs » du code solo ;
  2. coop locale sur PC (manettes, caméra commune avec laisse, zoom ×1,4) ;
  3. coop en ligne.
- Le mobile en local et l'écran partagé sont écartés : l'écran est trop petit et le rendu deux fois trop coûteux.
- **Réseau** : l'hôte décide du monde (monstres, coffres, or, boss). Chaque client décide de son déplacement, de ses sorts et des dégâts qu'il reçoit, pour garder les esquives justes.
- **Synchronisation** : par snapshots, et non en lockstep. Le code tire 49 aléas non semés, et la physique est en flottants. Le débit est d'environ 25 Ko/s par client, et d'environ 75 Ko/s en montée pour l'hôte avec 4 joueurs.
- **Transport** :
  - ENet pour le réseau local ;
  - **EOS P2P** (Epic Online Services) pour Internet : gratuit, relais fourni par Epic, cross-play Windows, Android et iOS.
  - Pourquoi pas les autres :
    - le temps réel de Play Games est fermé ;
    - Game Center n'a pas de cross-play ;
    - WebRTC exigerait un serveur TURN payant, incompatible avec un jeu vendu 5 € sans revenu récurrent.
  - Un prototype EOS décide d'abord si on continue.
- **Effort estimé** :
  - environ 47 jours-agent pour le refactor et la coop locale sur PC ;
  - environ 61 jours-agent pour le jeu en ligne ;
  - soit environ 108 jours-agent en 11 étapes testables (détail dans `Archi_Reseau.md`).
- **Conséquences** :
  - la permission Internet Android passe à vrai (`export_presets.cfg`) ;
  - les formulaires de confidentialité des stores sont à refaire ;
  - aucune sauvegarde de run coop en v1, pas de chat (pings seulement).
- **Contrats à créer par l'orchestrateur** :
  - les autoloads `Players` et `Net` ;
  - `PlayerState`, qui sépare de `RunState` ce qui est propre à chaque joueur ;
  - un `Events` qui porte le joueur concerné ;
  - `Balance.party_factor(n)` ;
  - des entrées par appareil.

## 2. Scaling (façon RoR2, simulé)

| Grandeur | Formule retenue | Source |
|---|---|---|
| Difficulté D | (1 + 0,3 (n−1) + min × pente × n^0,2) × 1,15^(étage−1) | RoR2 tel quel |
| Crédits du director | × (n+1)/2 | RoR2 tel quel |
| Monstres ordinaires | PV et dégâts inchangés, plafond global de 250 | RoR2 |
| Boss d'étage | PV × (1 + 0,4 (n−1)) | **écart** à RoR2 (× n) |
| Mini-boss | PV × (1 + 0,3 (n−1)) | écart |
| Boss final | PV × (1 + 0,35 (n−1)) | écart |
| Coffres | +50 % par joueur en plus | RoR2 |
| Or des kills | partagé à parts égales, morts compris | RoR2 |
| XP | entière pour chacun, niveau de départ 1/1/2/3 selon n | ajout |
| Coffre de boss | un par joueur | RoR2 |
| Charge du gros pilier | au prorata des joueurs dans la zone (plancher 0,25) | RoR2 |
| Joueur absent (45 s) | retiré du compte n | ajout |
| Rubis | × participation, aucun bonus multi (rubis par heure = solo) | ajout |

- **Pourquoi ne pas reprendre le × n de RoR2 sur les boss** : transposé tel quel, il donne à 4 joueurs un boss d'étage de 119 à 194 s, pour un enrage à 90 s, un boss final de 401 s et une run de 33 min.
- **Simulation recommandée, à 4 joueurs** :
  - run de 18,0 min (solo : 17,7) ;
  - boss d'étage de 70 à 81 s, boss final de 139 s ;
  - 24 objets par joueur (solo : 37) ;
  - pression de foule × 1,32, menace par joueur proche du solo.
  - Ni triviale ni impossible.
  - Le modèle est en champ moyen : il vaut pour comparer n = 1 à 4, pas pour donner des valeurs absolues.

## 3. Règles de partie

- **Choix des personnages** : doublons autorisés, chaque joueur reçoit une teinte d'équipe (contour, chevron, barres, minimap, pings).
- **Mode et présages** :
  - l'hôte choisit le mode, et le Difficile s'applique à tous ;
  - un seul présage pour l'équipe, choisi au vote.
- **Or** : chaque joueur a sa bourse. Les bonus d'or d'un kit ou d'un objet reviennent à son propriétaire. Aucun transfert d'or ni d'objet.
- **Coffres** :
  - l'objet va à celui qui paie ; un ping permet de signaler un coffre, sans le réserver ;
  - **le jeu ne se met jamais en pause** : le choix d'objet passe par une « sacoche » (overlay non bloquant, choix différé) ;
  - relances et pitié sont comptées par joueur.
- **Ateliers et marchand** : usages et étal par joueur.
- **Téléporteur** : compte à rebours de 15 s après activation, et un veto borné (2 × 15 s).
- **Lisibilité** :
  - les VFX des alliés sont atténués (α 0,55, 0,35 en qualité Bas) ;
  - secousse et hit-stop ne s'appliquent qu'à soi ;
  - des indicateurs hors écran signalent les alliés, les alliés à terre et les pings.
- **Kits** :
  - rendements décroissants sur les contrôles empilés (2 s, élites et boss) ;
  - les boss changent de cible au bout de 6 s ;
  - les procs d'objets sont attribués au propriétaire.
- **Gel des boss respecté** : aucun nouveau boss.

## 4. Décisions du joueur (01/11/2026)

- **Périmètre** : coop locale sur PC d'abord, puis en ligne.
- **PV des boss** : × (1 + 0,4 (n−1)) pour les boss d'étage ; × (1 + 0,3 (n−1)) pour les mini-boss ; × (1 + 0,35 (n−1)) pour le boss final.
- **Or** (précisé par le joueur) : chaque gain d'or crédite le même montant à chaque joueur, morts compris, dans sa bourse individuelle ; chacun dépense comme il veut (le coffre va à celui qui paie, aucun transfert). Un multiplicateur `Balance.coop_gold_mult(n)` (1,0 au départ) sera calibré pour que le nombre d'objets par joueur reste proche de la simulation.
- **Réanimation** : comme dans RoR2. Un joueur mort devient spectateur et ressuscite au début de l'étage suivant. Si tous les joueurs sont morts, la run est perdue. Pas de relevé au sol.
- **Restent ouverts** :
  - coffres +50 % ou +75 % par joueur en plus (défaut : +50 %) ;
  - plafond de monstres vivants quand un mobile héberge ;
  - compte développeur Epic pour EOS (étape 9).

## 4 bis. Points posés avant décision

1. **Périmètre** : local PC puis en ligne (recommandé), en ligne seul, ou local seul.
2. **PV des boss** : × (1 + 0,4 (n−1)) (recommandé) ou × n comme RoR2.
3. **Or** : partagé à parts égales comme RoR2 (recommandé, simulé), ou or entier à chacun avec moins de coffres.
4. **Réanimation** : deux propositions sont sur la table.
   - **A**, au sol : 30 s, relevé par un allié qui maintient 3 s à 1,5 u, retour à 40 % des PV, 3 chutes par étage.
   - **B**, comme RoR2 : spectateur, puis retour à la fin du prochain pilier terminé ou à l'étage suivant.
5. **Coffres** : +50 % (recommandé) ou +75 % par joueur en plus.
6. **Plafond de monstres vivants sur mobile** quand un mobile héberge.
7. **Contrat EOS** : compte développeur Epic à créer par le joueur.
