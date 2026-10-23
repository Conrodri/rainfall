# Audit UX/UI : écrans de décision et interactions en cours de run

> Consultant ux-designer, 22/10/2026. Avis seulement : aucun code du jeu modifié.
> Périmètre : montée de niveau, ouverture de coffre (défilement, passer, relance), choix d'item, interactions (piliers,
> téléporteur, capsules d'or, sanctuaires), invites d'interaction, infobulles d'items, lisibilité des raretés, retours de ramassage.
> Hors périmètre (audits parallèles) : HUD général, menus, remappage et accessibilité globale.

## 0. Méthode et limites

- **Lecture du code** : `game/scripts/ui/chest/chest_ui.gd`, `loot/chest.gd`, `loot/chest_session.gd`, `loot/gold_capsule.gd`, `loot/ad_hook.gd`,
  `stage/pillar.gd`, `stage/exit_teleporter.gd`, `stage/stage_manager.gd`, `ui/hud.gd` (interaction, or, niveau), `ui/interact_button.gd`,
  `ui/key_prompt.gd`, `ui/item_bar.gd`, `pickups/pickup_manager.gd`, `pickups/ground_pickup.gd`, `fx/ground_marker.gd`,
  `player/player.gd` (montée de niveau), `core/platform.gd`, `core/balance.gd` (table des coffres), `data/items.json` (48 items).
  Documents : `docs/GDD.md` §2 et §6, `.claude/agents/ux-designer.md`.
- **Captures : aucune.** Une scène temporaire `game/tests/_tmp_ux_choice_world.tscn` a été écrite, mais il y avait déjà d'autres Godot
  en cours, puis l'orchestrateur a interdit tout Godot et toute capture (le joueur utilise la machine). La scène a été supprimée
  sans être lancée. Tout ce qui demande une image est donc marqué **NON ÉVALUÉ (capture à faire)**.
- **Chiffres** : les durées viennent des constantes du code (« calculé ») ; les tailles physiques supposent un téléphone de 6,1 pouces
  au format 20:9 en paysage (1080 px ≈ 63,6 mm, soit ≈ 17 px/mm ; « estimé »).

## 1. Temps passé hors action

### Coffre (arbre en pause pendant tout l'écran)
Durée de la mise en scène = défilement de rareté + `ITEM_GAP` 0,08 + `ITEM_DUR[1]` 0,56 + `END_HOLD` 0,12 (calculé) :

| Rareté tirée | Défilement de rareté | Total avant de pouvoir choisir |
|---|---|---|
| Commun | 0,62 s | **1,38 s** |
| Peu commun | 0,72 s | **1,48 s** |
| Rare | 0,92 s | **1,68 s** |
| Légendaire | 1,22 s | **1,98 s** |
| Relance (items seuls) | — | **0,68 s** |
| Passée (appui) | immédiat | **≥ 0,22 s** (`SKIP_LOCK_MS`, jusqu'au relâcher) |

Moyenne pondérée par `Balance.CHEST_QUALITY_TABLE` : petit coffre ≈ **1,41 s**, grand ≈ **1,53 s**, boss ≈ **1,51 s**.
Sur une run (≈ 28 items d'après le GDD) : environ **40 s d'animation** si le joueur ne passe jamais. Il faut y ajouter environ 3 s de lecture
de 2 cartes par coffre (estimé), soit à peu près **2 min sur 18-20 min de run (≈ 10 %)**.
Ce budget est raisonnable : un appui passe l'animation, et rien ne se joue dans le monde pendant l'écran.
Le coût restant est la lecture, et c'est lui que les recommandations R5 et R6 réduisent.

### Montée de niveau
**0 s hors action** : il n'y a pas d'écran de choix (`player.gd::_on_level_up` donne des stats automatiques, 25 % de soin,
1 s d'invulnérabilité, un VFX, un éclair de lumière et le son `ui.level_up`). C'est le bon choix pour un survivor-like à 250 monstres.
Le manque se situe dans le retour visuel, voir C9.

### Interactions
Les capsules, piliers et le téléporteur ne mettent pas en pause et réagissent en une image (0 s hors action).

## 2. Tableau des problèmes

Gravité : S1 = perte de progression ou blocage, S2 = erreur probable ou frein fort, S3 = gêne réelle, S4 = finition.

| # | Constat (fichiers) | Critère | Gravité | Statut | Recommandation |
|---|---|---|---|---|---|
| P1 | **Un seul appui sur « interagir » déclenche tous les interactables à portée.** Chaque objet lit lui-même `Input.is_action_just_pressed("interact")` (`chest.gd` `_process`, `gold_capsule.gd`, `exit_teleporter.gd` et `pillar.gd` en `_physics_process`), alors que le HUD n'affiche que le plus proche (`hud.gd::_update_interact`). Le bouton tactile simule l'action : il a le même défaut. Cas réel : coffre du boss posé au pilier, téléporteur à +220 px (`TELEPORTER_OFFSET`). Rayons 96 + 80 et joueur de 24 px : il reste une bande de chevauchement d'environ 4 px (estimé), plus large si `reachable_local` rapproche le téléporteur d'un mur. Le téléporteur agit en physique, donc avant le coffre : `next_stage` retire la carte et **le coffre gratuit Rare du boss est perdu sans message**. | Modèle mental (l'invite = l'action) ; GAG « éviter les actions irréversibles accidentelles » | **S1** | **BLOQUANT** | Un seul répartiteur : le HUD (ou un nœud dédié) appelle `interact()` sur `interact_target` seulement, et les objets ne lisent plus l'entrée. En plus, écarter le téléporteur du coffre du boss : `TELEPORTER_OFFSET` ≥ 300 px (rayons 96 + 80 + 2 × 24 + 76 de marge). |
| P2 | **Le choix d'item se fait à l'appui, pas au relâcher** (`chest_ui.gd::_on_card_input` : `InputEventScreenTouch.pressed` ou clic pressé). Au doigt, on ne peut pas annuler en glissant hors de la carte, et le choix est irréversible. | WCAG **SC 2.5.2** (annulation du pointeur) | **S2** | **BLOQUANT** (mobile) | Valider au **relâcher dans la même carte** ; un glissement de plus de 24 px annule. L'appui ne fait que mettre la carte en surbrillance (échelle 1,04 et contour de rareté). Garder le verrou de skip actuel. |
| P3 | **Boutons de relance trop petits et empilés au doigt** : `_relayout` passe `BUTTON_H` à 96 px en paysage, soit ≈ 5,6 mm (estimé), avec 18 px d'écart. « Relancer (pub/gratuit) » est juste au-dessus de « Relancer (or) », qui **dépense de l'or**. | Fitts ; cible ≥ 9 mm (fiche, ≈ 120-153 px) ; Material 48 dp, Apple 44 pt | **S2** | **BLOQUANT** (mobile) | En tactile : boutons de **128 px** (Balance `UI_CHEST_BUTTON_H_TOUCH`), **côte à côte** avec 48 px d'écart, relance gratuite ou pub à gauche, relance à l'or à droite avec l'icône d'or. 96 px restent acceptables en clavier-souris. |
| P4 | **Le téléporteur « Partir » agit sans confirmation** (`exit_teleporter.gd::use` → `request_exit` → `next_stage`). Changer d'étage est irréversible : coffres non ouverts perdus, or converti. Avec P1, une capsule ou un coffre voisin peut aussi déclencher le départ. | GAG « confirmer les actions irréversibles » ; prévention d'erreur | **S2** | **BLOQUANT** | **Maintien de 0,6 s** (anneau de progression sur l'invite et sur le bouton tactile), plus une ligne de résumé dans l'invite : « Partir — 3 coffres restants · 240 or → XP ». Clé `Balance.UI_EXIT_HOLD_S = 0.6`. |
| P5 | **Coffre du boss : relances à l'or gratuites et illimitées.** Le prix du coffre vaut 0, donc `gold_reroll_price(0, n) = 0` et `can_gold_reroll()` est toujours vrai. Le bouton affiche « Relancer (or) - 0 or ». Le GDD fixe aussi « 1 relance par coffre », alors que les relances à l'or ne sont plafonnées nulle part (`chest_session.gd`). | Cohérence (le libellé promet un coût) ; GDD §6 | **S2** | **BLOQUANT** (design) | Prix plancher pour le coffre du boss (par exemple le prix d'un grand coffre de l'étage × 0,6) ou une seule relance. À trancher avec systems-designer. Tant qu'il n'y a pas de plafond, afficher « Relancer (or) — 2/2 ». |
| P6 | **Le refus d'achat est très discret** : la secousse du prix dure 160 ms (`chest.gd::_shake_label`) ; l'invite garde « Ouvrir — 125 or » ; le prix trop cher n'est signalé que par la couleur (jaune ou rouge). | **SC 1.4.1** (couleur seule) ; retour < 0,5 s sur plusieurs canaux | **S3** | CONSEIL | Invite « Il manque 37 or » (texte) ; prix précédé d'un cadenas quand l'or manque ; son de refus et vibration légère de 40 ms. |
| P7 | **Gros pilier verrouillé muet** : `can_interact()` exige `STATE_READY`, donc aucune invite ; le libellé « Verrouillé » de `interact_label()` n'est jamais affiché. Le joueur ne sait pas pourquoi le pilier ne répond pas. | Divulgation et visibilité d'état (Nielsen n° 1) | **S3** | CONSEIL | Invite **désactivée** (grisée, sans action) : « Verrouillé — petits piliers 1/2 ». Contrat proposé : `interact_state() -> {enabled, label}`. |
| P8 | **Raccourcis du coffre invisibles** : 1 / 2, R, G, LB / RB, Y ne sont affichés nulle part (`chest_ui.gd::_input`), alors que `KeyPrompt` existe. Le focus de manette n'est montré que par une échelle de 1,04. | **SC 2.4.7** (focus visible) ; invites selon `Platform.input_mode` | **S3** | CONSEIL | `KeyPrompt` de 44 px sous chaque carte (1 / LB, 2 / RB) et sur chaque bouton (R / Y) ; masqué en tactile. Focus : contour de 6 px de la couleur de rareté avec un contraste ≥ 3:1. |
| P9 | **La carte ne montre pas ce que gagne un exemplaire de plus** : « Vous en avez déjà 2 » sans l'effet cumulé. Les textes d'effet vont jusqu'à 126 caractères. | Divulgation progressive ; charge cognitive | **S3** | CONSEIL | Ligne « ×2 → ×3 : +75 PV max au total » calculée depuis `stats` et `stack` ; texte d'effet limité à 90 caractères, le détail dans l'infobulle. |
| P10 | **Pas d'infobulle d'item à la manette** pendant le jeu : `item_bar.gd` ne réagit qu'au survol de la souris ou à l'appui long au doigt. La liste « Objets » du menu pause existe, pour toutes les entrées. | GAG « tout ce qu'on peut faire à la souris se fait à la manette » | **S3** | CONSEIL | Ajouter un **bouton Objets** à l'écran de coffre (Select / Tab), qui ouvre la liste en surimpression sans quitter le choix. En jeu, la liste du menu pause suffit. |
| P11 | **La rareté repose surtout sur la couleur** dans l'inventaire (cadre `frame_<q>.png`) et sur la carte (nom coloré). Le vert peu commun (0,35 ; 0,82 ; 0,40) et l'orange légendaire (1 ; 0,65 ; 0,12) se confondent en deutéranopie ; le gris commun et le vert sont proches en luminance. La bande et l'en-tête affichent bien le nom de la rareté. | **SC 1.4.1** ; GAG daltonisme | **S3** | CONSEIL | (1) Mot de rareté dans le bandeau de la carte (« Rare · Lentille… ») et dans l'infobulle. (2) Brief Codex : les cadres de rareté reçoivent une **marque de forme** (0 / 1 / 2 / 3 crans ou gemmes en haut du cadre, 12 px à 56 px de case). Formes des cadres actuels : **NON ÉVALUÉ (capture à faire)**. |
| P12 | **Les ressources de kit expirent sans prévenir** : `GroundPickup` disparaît à `life_s` ; seul le repli dessiné pâlit, un sprite reste plein jusqu'à la dernière image. Le halo `GroundMarker` pulse à vitesse constante. | Retour < 0,5 s ; prévisibilité | **S3** | CONSEIL | Pendant la dernière seconde, clignotement à **2,5 Hz** du sprite et du halo (sous les 3 flashs par seconde de SC 2.3.1), alpha entre 0,35 et 1. Clé `Balance.PICKUP_EXPIRE_WARN_S = 1.0`. |
| P13 | **Montée de niveau peu visible dans le HUD** : seul le texte du médaillon change (`hud.gd::_on_level`) ; pas d'impulsion, pas de libellé, pas de vibration. La barre d'XP se vide d'un coup. | Retour sur plusieurs canaux (fiche §4) | **S4** | CONSEIL | Impulsion du médaillon (échelle 1,0 → 1,35 → 1,0 en 300 ms), « Niveau 7 » flottant pendant 1 s au-dessus du joueur, éclat de la barre d'XP de 200 ms, vibration de 60 ms (désactivable). |
| P14 | **Or crédité avant l'arrivée des pièces** : le compteur saute à la mort du monstre (`drop_bounty`), et la pièce arrive 0,6 s plus tard (`FLY_TIME`). Pas d'impulsion du compteur. | Lien cause-effet | **S4** | CONSEIL | Impulsion du compteur (1,0 → 1,15, 120 ms) à l'arrivée de la première pièce de chaque prime, plafonnée à 6 par seconde. Garder le crédit immédiat (exact et sûr). |
| P15 | **Invites provisoires** : `interact_button.gd` dessine en `_draw` avec la police de repli ; l'invite PC est un texte « [E] Ouvrir » sans les icônes de `KeyPrompt`. | Règle « tout élément d'UI final est produit par Codex » | **S4** | CONSEIL | Brief Codex (§4.3) ; l'invite PC réutilise `KeyPrompt` (44 px). |
| P16 | **Le style principal va à la relance à l'or** (`_gold_btn` en `PrimaryButton`) plutôt qu'au choix ; il n'y a pas d'aide sur les probabilités, alors que le GDD §6 les promet. | Hiérarchie visuelle | **S4** | CONSEIL | Boutons de relance en style secondaire ; un « ? » ouvre la table de rareté du coffre (`CHEST_QUALITY_TABLE`). |
| P17 | **Sanctuaires** (GDD : sanctuaire de risque, autel de fortune) : **absents du code** (seulement des props décoratifs dans `stage_map.gd`). | — | — | NON ÉVALUÉ | Quand ils arriveront : même contrat d'interaction que P1/P7, avec le coût et le risque dans l'invite, et un maintien de 0,6 s si le coût est irréversible. |

Points **solides** à garder :
- On peut passer l'animation dès la première image, et cet appui ne choisit jamais de carte (verrou de 220 ms jusqu'au relâcher). Cela corrige le retour « le clic sur un item déclenchait un sort ».
- Le tirage est fait à l'ouverture, avec un générateur de présentation séparé : relancer la partie ne change pas le résultat.
- L'éclair de rareté reste limité au coffre et à la bande, et respecte `Quality.flashes_level` (un seul éclair, SC 2.3.1 respecté).
- La mise en page s'adapte au paysage (en-tête à gauche) et le texte des cartes se réduit pour tenir dans la carte.
- La montée de niveau n'interrompt pas le jeu.
- L'or est arrondi à l'entier : « chaque pièce visible = au moins +1 ».
- La reprise de sauvegarde rouvre l'écran de coffre en cours.

## 3. Options et recommandations détaillées

### 3.1 Interaction unique (P1, P4, P7)
- **Option A, répartiteur dans le HUD** (Recommandé) : `hud.gd` choisit `interact_target` (le plus proche, avec priorité coffre > capsule > pilier > téléporteur à distance égale ± 16 px) et appelle `interact_target.interact()` sur `interact` pressé. Les objets ne lisent plus l'entrée. Il n'y a qu'une source de vérité pour l'invite et l'action.
  Inconvénients : le contrat « Interaction » change (`interact()` et `interact_state()`), à valider par l'orchestrateur dans `CONTRACTS.md`.
- **Option B, verrou d'image** : le premier objet qui consomme l'action pose un drapeau dans l'image. C'est fragile (l'ordre physique et l'ordre de traitement diffèrent) et l'objet choisi peut être différent de celui affiché par l'invite.
- **Téléporteur** : maintien de 0,6 s (clavier, manette et doigt), anneau qui se remplit autour de l'invite, et annulation si l'on relâche ou si l'on sort de la zone. Le maintien vaut mieux qu'une boîte de dialogue (Hick : aucun écran de plus, et le joueur continue à bouger autour).

### 3.2 Écran de coffre au doigt (P2, P3, P8, P16)
Maquette paysage 2400 × 1080 (logique 2400 × 1080, `keep_height`) :
- En-tête à gauche, 40 % de la largeur : titre, coffre (≤ 280 px), bande de rareté de 130 à 220 px de haut, nom de la rareté en 60 px.
- Corps à droite, 60 % : 2 cartes au ratio 384:560, de 560 à 600 px de haut environ (estimé).
- Dessous, une **rangée de 128 px** : [Relancer gratuit / pub 2/3] et [Relancer 54 or], écart de 48 px, style secondaire, invites R / Y.
- **Sélection au relâcher** (P2), surbrillance à l'appui, annulation si le doigt glisse de plus de 24 px.
- Option rejetée : « appuyer pour choisir puis bouton Valider ». C'est plus sûr mais coûte un appui de plus par coffre (28 par run). Le relâcher avec annulation suffit (SC 2.5.2).

### 3.3 Rythme (budget hors action)
- **Réglage « Animation des coffres » : Complète / Courte / Instantanée** (`GameSettings` clé `chest_reveal`, défaut Complète).
  Courte : `RARITY_DUR × 0,5`, `ITEM_DUR × 0,6`, soit environ 0,8 s en moyenne. Instantanée : le résultat directement, avec le son de rareté.
  Gain : environ 20 à 40 s par run, sans perdre l'effet de tension pour qui le veut.
- Garder la relance à 0,68 s.

### 3.4 Lisibilité des cartes (P9, P11)
- Bandeau : « RARE · Nom » (rareté en 70 % de la taille du nom, en capitales).
- Ligne d'empilement : « ×2 → ×3 : +75 PV max au total » (texte ≥ 22 px à 1080p, couleur or (1 ; 0,85 ; 0,4) sur fond sombre, contraste ≥ 4,5:1 estimé).
- Plancher de police de la description : 18 px (aujourd'hui `clampi(…, 12, 30)` ; en pratique ≈ 30 px à 1080p, estimé). Si 18 px ne suffit pas, couper le texte et renvoyer à l'infobulle plutôt que de descendre à 12 px.

## 4. Briefs et réglages

### 4.1 Clés de réglage proposées
| Clé | Valeur | Où |
|---|---|---|
| `UI_CHEST_BUTTON_H_TOUCH` | 128 px | Balance (orchestrateur) |
| `UI_CHEST_BUTTON_GAP_TOUCH` | 48 px | Balance |
| `UI_CARD_CANCEL_DRAG_PX` | 24 px | Balance |
| `UI_EXIT_HOLD_S` | 0,6 s | Balance |
| `TELEPORTER_OFFSET` | (0, 300) | `stage_manager.gd` |
| `PICKUP_EXPIRE_WARN_S` | 1,0 s, clignotement 2,5 Hz | Balance |
| `chest_reveal` | complete / short / instant | GameSettings |
| `haptics` | on / off (refus 40 ms, niveau 60 ms, coffre rare et plus 80 ms) | GameSettings |

### 4.2 Brief Codex : cadres de rareté
`icons/frame_<q>.png` : à 56 px affichés, une marque de forme lisible en niveaux de gris :
commun = aucun cran, peu commun = 1, rare = 2, légendaire = 3 crans plus un fleuron.
États normal et survol (+15 % de luminance). Contraste du cadre sur le fond du HUD ≥ 3:1 (SC 1.4.11). Rendu cel-shadé, sans normal map.

### 4.3 Brief Codex : bouton et invite d'interaction
Bouton tactile de 400 × 140 px (à l'échelle 1) ; états normal, pressé et **désactivé** (pour P7) ; anneau de maintien de 12 px en 8 segments (pour P4) ;
icône d'action de 64 px à gauche (main, pièce, éclair de pilier, portail). Texte de 38 px ou plus, posé en jeu (pas dans la texture).

## 5. Plan d'implémentation priorisé (lots)

| Lot | Contenu | Problèmes | Fichiers | Dépendances |
|---|---|---|---|---|
| **L1 — Interaction unique et sûre** (priorité 1) | Répartiteur unique ; `interact()` et `interact_state()` sur chaque interactable ; maintien de 0,6 s et résumé pour le téléporteur ; invite grisée pour le pilier verrouillé ; refus d'achat en texte, son et vibration ; `TELEPORTER_OFFSET` à 300. | P1, P4, P6, P7 | `ui/hud.gd` (`_update_interact` seulement), `ui/interact_button.gd`, `loot/chest.gd`, `loot/gold_capsule.gd`, `stage/exit_teleporter.gd`, `stage/pillar.gd`, `stage/stage_manager.gd` (constante) ; `CONTRACTS.md` par l'orchestrateur | Contrat à valider par l'orchestrateur |
| **L2 — Écran de coffre au doigt et à la manette** (priorité 1) | Choix au relâcher avec annulation ; boutons de 128 px côte à côte ; invites `KeyPrompt` ; contour de focus ; relances en style secondaire ; « ? » pour les probabilités ; ligne d'empilement et rareté dans le bandeau. | P2, P3, P8, P9, P11 (texte), P16 | `ui/chest/chest_ui.gd` seul | Aucune (lit les constantes de Balance si L5 est fait, sinon des constantes locales) |
| **L3 — Règle de relance** (priorité 2) | Prix plancher ou plafond des relances du coffre du boss ; plafond par coffre conforme au GDD ; libellé « n/N ». | P5 | `loot/chest_session.gd` ; `core/balance.gd` (orchestrateur) | Décision de systems-designer |
| **L4 — Retours de progression** (priorité 3) | Impulsion du médaillon et « Niveau N » ; éclat de la barre d'XP ; impulsion du compteur d'or ; vibration désactivable. | P13, P14 | `player/player.gd` (libellé flottant), `ui/hud.gd` (`_on_level` et `_on_gold` seulement) | Partage `hud.gd` avec L1 : à faire **après** L1, ou par un autre agent sur des fonctions distinctes |
| **L5 — Réglages** (priorité 3) | `chest_reveal` (Complète, Courte, Instantanée) et `haptics` ; clés dans Balance. | §3.3, haptique | `ui/game_settings.gd`, `ui/settings_panel.gd` ; `core/balance.gd` (orchestrateur) | À coordonner avec l'audit des menus (même panneau) |
| **L6 — Inventaire et rareté accessibles** (priorité 3) | Rareté écrite dans l'infobulle ; bouton Objets depuis l'écran de coffre (manette) ; brief des cadres (§4.2) à Codex. | P10, P11 | `ui/item_bar.gd` ; brief dans `art/briefs/` | L2 pour le bouton dans le coffre |
| **L7 — Ressources de kit** (priorité 4) | Clignotement d'expiration. | P12 | `pickups/ground_pickup.gd` | Aucune |
| **L8 — Assets d'invite** (Codex) | Bouton d'interaction et icônes (§4.3). | P15 | `art/tools/ui/` | Après L1 (états désactivé et maintien) |

## 6. NON ÉVALUÉ (capture à faire)
Captures à faire en 1920 × 1080 (clavier-souris) et en 2400 × 1080 `--mobile` (tactile), avec une scène `game/tests/_tmp_ux_choice_*` à supprimer ensuite :
1. Écran de coffre : pendant la rareté (0,25 s), pendant les items (0,8 s), au résultat, après une relance. Vérifier la taille réelle du texte des cartes, le contraste du nom de rareté sur le cadre (≥ 4,5:1) et la place des boutons.
2. Coffre au sol : prix lisible (taille et contraste), coffre trop cher, invite PC et bouton tactile.
3. Capsule, pilier prêt, pilier verrouillé, téléporteur à côté du coffre du boss (mesurer le chevauchement réel avec `can_interact()` des deux).
4. Infobulle d'item (souris et appui long) ; forme des cadres `frame_<q>.png` en niveaux de gris (simulation de deutéranopie).
5. Montée de niveau à +0,15 s et +0,65 s : le VFX est-il lisible au milieu de 250 monstres ?
6. Temps de décision réel par coffre (chronométrer sur 5 coffres avec le joueur).
7. Sanctuaires : non implémentés.

## 7. Sources
- WCAG 2.1, SC 1.4.1 Use of Color : https://www.w3.org/WAI/WCAG21/Understanding/use-of-color
- WCAG 2.1, SC 1.4.3 et 1.4.11 Contrast : https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum , https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast
- WCAG 2.1, SC 2.5.2 Pointer Cancellation : https://www.w3.org/WAI/WCAG21/Understanding/pointer-cancellation
- WCAG 2.1, SC 2.4.7 Focus Visible : https://www.w3.org/WAI/WCAG21/Understanding/focus-visible
- WCAG 2.1, SC 2.3.1 Three Flashes : https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold
- Game Accessibility Guidelines : https://gameaccessibilityguidelines.com/full-list/
- Material Design, cibles tactiles 48 dp : https://m3.material.io/foundations/designing/structure#touch-targets
- Apple Human Interface Guidelines, 44 pt : https://developer.apple.com/design/human-interface-guidelines/accessibility
- Loi de Fitts et loi de Hick (Nielsen Norman Group) : https://www.nngroup.com/articles/fitts-law/ , https://lawsofux.com/hicks-law/
- Projet : `docs/GDD.md` §2 et §6 ; `.claude/agents/ux-designer.md`.
