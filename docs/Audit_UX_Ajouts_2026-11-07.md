# Audit UX/UI des ajouts récents (07/11/2026)

Auteur : ux-designer (consultant). Demande du joueur : chaque nouvel item et chaque nouvel écran doit avoir du visuel (images, icônes), un HUD clair et une UX/UI claire. Le présent audit liste, pour chaque ajout récent, ce qui est déjà un asset Codex, ce qui reste du texte seul ou une forme dessinée en code (placeholder), les problèmes de lisibilité (téléphone paysage 1920×1080 `keep_height`, manette, tactile, clavier-souris) et les corrections recommandées. Il se termine par la liste des assets Codex à produire, groupés en lots.

## 0. Méthode et limites

- Lecture du code : `game/scripts/menu/coop_lobby_screen.gd`, `game/scripts/ui/coop_plates.gd`, `game/scripts/ui/pause_menu.gd`, `game/scripts/game/coop_local.gd`, `game/scripts/ui/forge_panel.gd`, `game/scripts/ui/item_bar.gd`, `game/scripts/items/forge.gd`, `game/data/recipes.json`, `game/scripts/ui/epreuve_hud.gd`, `game/scripts/ui/minimap.gd`, `game/scripts/stage/epreuve.gd`, `game/scripts/ui/objectives_panel.gd`, `game/scripts/ui/end_run_screen.gd`, `game/scripts/spells/vigie_kit.gd`, `game/scripts/spells/averse_rivulet.gd`, `game/scripts/ui/resource_gauge.gd`, `game/scripts/fx/zone_outline.gd`, `game/scripts/ui/settings_panel.gd`.
- Inventaire des assets livrés : `game/assets/sprites/ui/` (kit `da/`, `prompts/`, `menu/`, `cues/`, `resource_gauge/`, `icons/passives/`, `portraits/`), `game/assets/sprites/icons/` (cadres, `storm_core.png`, `forge_ready.png`, `items/`), `game/assets/sprites/pickups/storm_core.png`, `game/assets/sprites/characters/*/portrait.png` et portraits de skins.
- Tests headless lancés : `coop_ui_test`, `forge_test`, `epreuve_ui_test` : `RESULT: OK` (ils valident la logique, pas le rendu).
- **Aucune capture en jeu** de ces écrans (pas de scène `capture_*` pour le lobby, les plaques, la Forge ou les épreuves). Les contrastes « mesurés » le sont sur les PNG (pixels opaques contre une couleur de fond connue) ; les contrastes en situation réelle (sur le sol, sous la lumière du biome) sont **NON ÉVALUÉS**. Les autres chiffres de lisibilité sont **estimés** d'après le code.
- Gravité : S1 empêche de jouer ou de comprendre une règle vitale ; S2 gêne forte ou exigence du joueur non tenue ; S3 gêne modérée ; S4 finition. « BLOQUANT » = à corriger avant de considérer l'ajout comme fini (exigence du joueur « visuel + HUD clair » ou critère WCAG / GAG non tenu) ; « CONSEIL » = amélioration.

### Assets déjà livrés et réutilisables sans nouvelle commande

| Besoin | Asset existant | Chemin |
|---|---|---|
| Portraits de personnages (10 sur 10) | bustes 256 px | `characters/<id>/portrait.png` (8), `ui/portraits/{rictus,morfil}.png` ; portraits de skins `characters/<id>/skins/<skin>/portrait.png` ; fonction prête : `CharacterCard.portrait_info(c, skin_id)` |
| Invites manette A, B, X, Y, LB, RB, LT, RT, sticks, faces neutres | 64 px | `ui/prompts/pad_*.png` (via `KeyPrompt`) |
| Touches clavier et souris | 64 px, 128×64 px | `ui/prompts/key_1x1.png`, `key_2x1.png`, `mouse_*.png` |
| Coche, cadenas | 64 px, 96 px | `ui/menu/icon_check.png`, `ui/menu/icon_lock.png` |
| Plaque, panneau, barres PV / XP de la DA | 9-slices | `ui/da/panel_small_9slice.png` (192, marges 24), `panel_9slice.png`, `bar_frame_hp`, `bar_fill_hp`, `bar_fill_hp_lost`, `bar_frame_xp`, `bar_fill_xp` |
| Or, rubis, XP | 64 px | `ui/da/icon_gold.png`, `icon_ruby.png`, `icon_xp.png` |
| Cadre « forgé » cuivré | 64 et 128 px | `icons/frame_forge.png`, `frame_forge_128.png` |
| Pastille « Forge possible » | 64 px | `icons/forge_ready.png` |
| Jauge de ressource de kit | kit U1 | `ui/resource_gauge/*` |
| Repères hors écran | chevrons 96 px | `ui/cues/cue_{boss,elite,telegraph}.png` |
| Anneau de recharge de sort | | `ui/spell_cooldown_ring.png` |
| Tuiles de la Gouttière (vide / pleine) | 128 px | `characters/averse/variants/rivulet_tile/` |

---

## 1. Lobby de la coop locale (`coop_lobby_screen.gd`)

**État** : écran 100 % texte et formes de code. Fond `ColorRect`, quatre cartes `StyleBoxFlat` (bordure 3 px à la teinte d'équipe), cinq `Label` par carte (Joueur N, appareil, « ◀ Nom ▶ », « Skin : … », état), consignes en une phrase avec des flèches Unicode et les lettres « A / Start / LB / RB » écrites en texte. **Aucun asset Codex** n'y est utilisé, alors que les portraits, les invites de touches, la coche et le cadenas existent.

| # | Constat | Critère | Gravité | Statut | Recommandation |
|---|---|---|---|---|---|
| L1 | Aucun portrait ni aperçu de skin : le choix du personnage se fait sur un nom ; deux Ardent ne se distinguent que par « Skin : Base / … » | Exigence joueur ; reconnaissance plutôt que rappel | S2 | BLOQUANT | Portrait du skin choisi dans chaque carte, via `CharacterCard.portrait_info(c, skin)` (aucun asset neuf) |
| L2 | Commandes écrites en texte (« A / Start », « LB / RB », « ◀ ▶ ▲ ▼ ») | Exigence joueur ; GAG « invites selon l'appareil » | S2 | BLOQUANT | `KeyPrompt` avec `pad_a`, `pad_b`, `pad_lb`, `pad_rb`, `key_1x1` / `key_2x1` (livrés) ; **manquent** `pad_start`, `pad_select`, `pad_dpad_lr`, `pad_dpad_ud` (lot UX-A) |
| L3 | État « Prêt » peu saillant : un mot de 24 px, la carte ne change pas | Retour < 0,5 s ; hiérarchie visuelle | S2 | BLOQUANT | Voir maquette « Prêt » ci-dessous |
| L4 | Débordement en 4:3 et 5:4 : 4 cartes à 380 px mini + 3 écarts de 24 = 1 592 px, place disponible 1 440 − 120 = 1 320 px (4:3) ; 16:10 passe tout juste (1 608 px) | Adaptatif au ratio (règle du projet) | S2 | BLOQUANT | Largeur de carte = clamp((W − 120 − 3 × 24) / 4, 280, 420) ; sous 280 px, grille 2 × 2 |
| L5 | « Manette 3 » = index Godot + 1, pas le numéro physique ; aucun moyen de savoir quelle manette est quelle carte | GAG « retour par plusieurs canaux » | S3 | CONSEIL | À l'inscription : vibration de la manette 200 ms (0,5 / 0,5) + pulsation de la carte ; icône d'appareil (lot UX-A) |
| L6 | Aucun son : rejoindre, prêt, compte à rebours, lancement | Jamais un seul canal | S2 | BLOQUANT | `ui.click` à l'inscription, `ui.spell_ready` au « Prêt », tic à chaque seconde du compte, son de départ (lot audio UX-H) |
| L7 | Polices codées en dur (24 à 64 px), ignorent « Taille du texte » | WCAG 1.4.4 | S3 | CONSEIL | Passer par `UiTheme` / `Accessibility` comme les autres menus |
| L8 | Variantes de sorts (mémorisées au profil) invisibles : un joueur ne sait pas quel kit il lance | Divulgation progressive | S3 | CONSEIL | Rangée de 4 icônes de sorts 48 px sous le portrait (icônes livrées) |
| L9 | Modes verrouillés sautés en silence par ◀ ▶ | Modèle mental | S4 | CONSEIL | Afficher « Difficile » grisé + `icon_lock` 32 px au lieu de sauter |
| L10 | Cadres de cartes et fond = `StyleBoxFlat` / `ColorRect` (placeholders) | Règle « tout élément d'UI final par Codex » | S3 | BLOQUANT | 9-slice neutre teinté par `modulate` (lot UX-D) |
| L11 | Bouton « Coop locale » du titre en texte seul | Exigence joueur | S4 | CONSEIL | Icône 4 silhouettes 96 px (lot UX-D) |

### Options de mise en page d'une carte joueur

1. **Carte portrait (Recommandé)** : carte verticale, largeur 280-420 px (voir L4), hauteur 520 px à 1080. De haut en bas : bandeau « Joueur N » 40 px (pastille numérotée + nom en teinte d'équipe), icône d'appareil 32 px ; portrait 240 × 240 px (48 % de la hauteur de carte), invites `◀`/`▶` remplacées par `pad_dpad_lr` 48 px de part et d'autre du portrait ; nom du personnage 32 px ; ligne skin 24 px avec `pad_dpad_ud` 32 px ; 4 icônes de sorts 48 px ; zone d'état 64 px. Avantages : reconnaissance immédiate, doublons distingués par le portrait du skin. Inconvénient : hauteur, d'où le passage en 2 × 2 sous 280 px. Fondement : reconnaissance plutôt que rappel, Hick (une décision par axe du D-pad).
2. **Carte compacte horizontale** : portrait 128 px à gauche, textes à droite, 4 cartes empilées verticalement. Avantage : tient en 4:3 sans grille. Inconvénient : plus de lecture, portrait petit sur une TV à 3 m (coop canapé), cible PC uniquement mais distance de jeu typique 2-3 m.
3. **Aperçu animé** (sprite `idle_s` qui tourne) au lieu du buste. Plus vivant mais coût de 4 `AnimatedSprite2D` et pas de buste pour certains skins ; à garder pour plus tard.

### Maquette de l'état « Prêt » (Recommandé)

- Non inscrit : carte à 55 % d'opacité, portrait remplacé par la silhouette de manette `device_gamepad` 128 px, « Rejoindre » + `pad_a` 48 px + `pad_start` 48 px ; « Entrée » en `key_2x1` si le clavier n'est pas inscrit.
- Inscrit, pas prêt : bordure 3 px à 60 % de la teinte, invite « Prêt » + `pad_a` 40 px.
- Prêt : bordure 6 px à 100 % de la teinte, bandeau « PRÊT » 40 px en bas de carte avec `icon_check` 48 px, portrait qui fait un petit rebond de 120 ms (désactivé par « Réduire les mouvements »), flèches de choix remplacées par `icon_lock` 32 px, invite « Annuler » + `pad_b`. Son `ui.spell_ready` + vibration 120 ms de cette manette.
- Compte à rebours : chiffre 96 px centré sous les cartes, tic sonore par seconde ; `LAUNCH_S` 2,0 s garde la marge d'annulation.

---

## 2. Plaques HUD de la coop (`coop_plates.gd`)

**État** : tout est dessiné en `_draw` : fond, liseré, bordure, pastille numérotée, barre de PV, voile de recharge. Assets Codex utilisés : `icon_gold.png` et les icônes de sorts. La disposition est bonne (1-2 en bas à gauche, 3-4 en bas à droite, bas-centre libre ; 4 × 400 + écarts + 240 = 1 912 px à 1920, empilement 2 × 2 en 4:3 calculé par `layout()`), la teinte n'est jamais seule (chiffre 1-4).

| # | Constat | Critère | Gravité | Statut | Recommandation |
|---|---|---|---|---|---|
| P1 | Plaque, barre de PV et pastille en formes de code alors que `panel_small_9slice`, `bar_frame_hp`, `bar_fill_hp`, `bar_fill_hp_lost` existent | Règle assets Codex ; cohérence avec le HUD solo | S3 | BLOQUANT | Réutiliser ces 9-slices ; pastille = `team_pip` (lot UX-D) |
| P2 | Pas de portrait : en coop canapé on cherche « son » personnage, pas son nom | Exigence joueur | S3 | BLOQUANT | Portrait 56 px (buste existant, rogné rond dans `portrait_ring`, lot UX-D) à gauche de la plaque, liseré à la teinte |
| P3 | Spectateur : texte `COL_DIM` à 60 % d'opacité sur fond à 43 % (0,72 × 0,6) ; contraste estimé ≈ 3:1 | WCAG 1.4.3 (4,5:1) | S2 | BLOQUANT | Texte à 100 % en `COL_TEXT` ; n'atténuer que le cadre et le portrait (désaturé) ; icône `status_spectator` 40 px (lot UX-D) |
| P4 | Manette déconnectée : bordure grise + texte `COL_ABSENT` (≈ #8C8C8C) ; contraste estimé ≈ 4:1, limite ; aucune icône, aucune consigne pour reprendre | WCAG 1.4.3 ; 1.4.1 (gris = seul signal du cadre) | S2 | BLOQUANT | Icône `device_gamepad_off` 40 px + « Manette déconnectée » en `COL_TEXT` + « `pad_a` / `pad_start` pour reprendre » |
| P5 | Appareil écrit « clavier » / « manette » / « manette ? » dans la ligne du nom (tronquée à 400 px) | Lisibilité | S4 | CONSEIL | Icône `device_keyboard` / `device_gamepad` 24 px ; libère la ligne pour le nom |
| P6 | PV bas : seul le passage de la couleur à `hp_low` le signale | WCAG 1.4.1 | S3 | CONSEIL | ≤ 25 % : bordure de plaque qui pulse à 1 Hz (désactivable par « Réduire les mouvements ») + barre `bar_fill_hp_lost` visible |
| P7 | Bulles d'interaction des joueurs 2-4 : « 2 · A Ouvrir », la touche en texte | GAG invites | S3 | CONSEIL | `pad_a` 28 px (ou `key_1x1` « E ») dans la bulle, cadre `panel_small_9slice` |
| P8 | « Niv. N » répété sur chaque plaque | Économie d'espace | S4 | CONSEIL | Si le niveau est commun (Design_Coop), l'afficher une seule fois dans le médaillon du HUD |
| P9 | Tactile, mobile | — | — | NON ÉVALUÉ | Coop locale = PC seulement en 1.0 |

---

## 3. Pause « Manette déconnectée » (`pause_menu.gd`, `coop_local.gd`)

**État** : texte seul, ajouté en tête du libellé `_info` (celui du chrono et de l'étage), en couleur `UiTheme.COL_MUTED`. Solo : « Manette déconnectée » ; coop : « Manette du joueur N déconnectée : rebranchez-la ou appuyez sur A / Start sur une manette libre ».

| # | Constat | Critère | Gravité | Statut | Recommandation |
|---|---|---|---|---|---|
| D1 | Information critique affichée dans le style secondaire (gris atténué, taille du chrono) | Hiérarchie visuelle | S2 | BLOQUANT | Bandeau dédié en tête du panneau pause (maquette ci-dessous) |
| D2 | À la reconnexion (`CoopLocal.pad_restored`), le message n'est ni retiré ni remplacé : le joueur ne sait pas si ça a marché | Retour < 0,5 s | S2 | BLOQUANT | Écouter `pad_restored` : remplacer par « Manette du joueur N reconnectée » + `icon_check`, vibration 200 ms de la manette rendue ; le jeu reste en pause, le joueur reprend lui-même |
| D3 | Aucun son à la perte | Jamais un seul canal | S3 | CONSEIL | Son `pad_lost` (lot audio UX-H) |
| D4 | « A / Start » en texte | GAG invites | S3 | CONSEIL | `pad_a` + `pad_start` 40 px |

**Maquette (Recommandé)** : bandeau pleine largeur du panneau, hauteur 140 px à 1080, cadre `panel_small_9slice` ; à gauche `device_gamepad_off` 96 px teinté à la couleur du joueur avec son chiffre ; titre 36 px « Manette du joueur 2 déconnectée » ; ligne 26 px « Rebranchez-la, ou appuyez sur [A] / [Start] sur une manette libre » avec les icônes. Même bandeau en solo sans chiffre.

---

## 4. Forge (`forge_panel.gd`, `recipes.json`, icônes, noyau d'orage)

**État** : assets Codex livrés et branchés : 6 icônes 256 px (`icons/items/{meche_silex,rosee_figee,rouage_traque,seve_rampante,ecorce_pluie,prisme_grele}.png`), cadre cuivré `frame_forge(_128).png`, pastille `forge_ready.png`, noyau `icons/storm_core.png` (256 px) et pickup `pickups/storm_core.png` (64 px). Placeholders en code : boutons de recette (`StyleBoxFlat` cuivre), carte de gain (`StyleBoxFlat`), repli « ● / ○ » des noyaux. Le parcours en 3 étapes (liste, choix pré-rempli, confirmation « Vous perdez / Vous gagnez ») est bon : un appui par étape, retour B / Échap, pas de perte sans confirmation.

| # | Constat | Critère | Gravité | Statut | Recommandation |
|---|---|---|---|---|---|
| F1 | La liste des recettes est **sans icône** : nom, rang, rôles et état en 3 lignes de texte | Exigence joueur | S2 | BLOQUANT | Icône du résultat 96 px dans `frame_forge_128` à gauche de chaque ligne (déjà livrée) ; ligne de 128 px gardée (≥ 120 px tactile) |
| F2 | Contraste des 6 icônes forgées sur l'intérieur du cadre cuivré (#30201C), mesuré sur PNG, médiane des pixels opaques : 1,1:1 (Mèche-silex, Rouage, Sève) à 2,4:1 (Prisme) ; 90e centile 2,0 à 5,3:1 | WCAG 1.4.11 (3:1 pour un graphique porteur de sens) | S2 | BLOQUANT | Reprise des icônes (lot UX-B) : liseré clair 2 px à 128 px, accent émissif `_e`, médiane ≥ 3:1 sur #30201C |
| F3 | Rosée figée et Prisme de grêle : même silhouette (cristal pentagonal gris-bleu + pastilles cyan) ; Sève rampante : 19 % de couverture, trait fin ; Mèche-silex se lit comme une bobine, sans feu ni silex | Silhouette distinctive (reconnaissance à 48 px) | S2 | BLOQUANT | Silhouettes distinctes (rosée = goutte gelée sur feuille, prisme = grêlon prismatique éclaté), Sève plus massive, Mèche avec étincelle émissive |
| F4 | Noyau d'orage HUD : très sombre (luminance médiane 0,034), décentré (boîte 28-219 × 35-232 sur 256), se lit comme une montre | Lisibilité d'icône | S2 | BLOQUANT | Icône v2 centrée, cœur cyan lumineux + éclairs, `_e` (lot UX-B) |
| F5 | Noyau au sol (64 px) : contraste médian ≈ 1,4:1 sur un sol sombre (#1A1C20) ; récompense de boss qui risque de passer inaperçue | WCAG 1.4.11 ; hiérarchie « butin » | S2 | BLOQUANT | Pickup 96 px avec `_e` (cœur et éclairs) + `_shadow` + halo additif (lot UX-B) ; rendu en jeu NON ÉVALUÉ (branchement en cours) |
| F6 | Gain d'un noyau silencieux (`RunState` à la mort du boss, `Chest` pour le reliquaire) ; au plafond (2), le noyau est perdu sans message | Retour < 0,5 s ; « savoir ce qui s'est passé » | S2 | BLOQUANT | Toast 2,5 s « Noyau d'orage +1 (1/2) » avec l'icône 64 px + son + vibration 80 ms ; au plafond « Noyaux d'orage au maximum (2/2) » |
| F7 | Le HUD ne montre les noyaux que si une recette est réalisable (case « Forge ») | Visibilité de l'état | S3 | CONSEIL | Compteur 32 px (icône + « 1/2 ») à côté de l'or dès qu'un noyau est porté |
| F8 | Confirmation : « Vous perdez » liste des noms en texte, sans icônes | Exigence joueur ; prévention d'erreur | S2 | BLOQUANT | Icônes 64 px des objets perdus (cadre de rareté livré) + icône du noyau ; rouge + titre écrit, donc pas de sens par la seule couleur |
| F9 | Rôles « Objet [Feu] ou [Crit] (commun ou mieux) » en texte | Lisibilité, balayage visuel | S3 | CONSEIL | Puces d'étiquettes 48 px (lot UX-G, 8 étiquettes utilisées par les recettes) |
| F10 | Onglets « Objets / Forge » en texte, LB / RB non affichés | GAG invites | S3 | CONSEIL | `pad_lb` / `pad_rb` 40 px de part et d'autre (manette seulement), `forge_ready` 40 px dans l'onglet Forge |
| F11 | Forger : ni son, ni flash, ni vibration ; seul un texte vert apparaît | Jamais un seul canal | S2 | BLOQUANT | Son `forge_craft`, flash cuivré 200 ms sur la carte de gain, vibration 120 ms |
| F12 | Boutons de recette et carte de gain en `StyleBoxFlat` | Règle assets Codex | S3 | BLOQUANT | 9-slice cuivré normal / indisponible (lot UX-E) |
| F13 | Infobulle de recette (`tooltip_text`) inaccessible au tactile ; le détail sous la liste suit le focus et le survol | Tactile | S4 | CONSEIL | Déjà compensé par `_detail` ; vérifier que l'appui tactile met bien à jour `_detail` avant d'ouvrir le sélecteur (NON ÉVALUÉ) |

---

## 5. Épreuves (`epreuve_hud.gd`, `minimap.gd`, `epreuve.gd`, fin de run)

**État** : **aucun asset Codex**. Barre de progression, libellé de note et flèche hors écran dessinés en code (police de repli) ; icônes de minimap en formes de code (barque = losange, rituel = anneau, tenue = carré, poursuite et veine = même disque) ; objets du monde en `Polygon2D` (barque, bornes, disque, cloche) ; `Audio.play("epreuve_grade_*")` appelle des sons qui n'existent pas (`game/assets/audio/epreuves/` absent). Les lots EP-A à EP-G sont déjà spécifiés dans `docs/Design_Epreuves.md` §9 et non produits.

| # | Constat | Critère | Gravité | Statut | Recommandation |
|---|---|---|---|---|---|
| E1 | Objets du monde en placeholders | Exigence joueur | S2 | BLOQUANT | Lots EP-A à EP-E (Design_Epreuves §9), inchangés |
| E2 | Minimap : Poursuite et Veine ont la même forme (disque) ; seule la couleur les distingue | WCAG 1.4.1 | S3 | BLOQUANT | `minimap_epreuve_<verbe>.png` (EP-F, repris dans le lot UX-C) |
| E3 | Barre 420 × 14 px (≈ 17 px sur mobile, ≈ 1,2 mm sur un 6 pouces) dessinée en code ; pas d'icône du verbe | Lisibilité mobile ; exigence joueur | S3 | BLOQUANT | Réutiliser `bar_frame_xp` / `bar_fill_xp` teinté au verbe, hauteur 20 px PC / 28 px mobile ; icône du verbe 40 px à gauche du titre (même PNG que la minimap) |
| E4 | Note « Parfait / Bien / Fait » : texte coloré 2 s, son manquant, pas de vibration | Jamais un seul canal | S2 | BLOQUANT | Médaillon de note 128 px (forme différente par note) + sons EP-G + vibration 100 ms (parfait 2 × 80 ms) |
| E5 | Le panneau Objectifs n'affiche rien avant le gros pilier : le joueur ne sait pas que les 2 épreuves sont le but de l'étage ni où il en est | « Savoir ce qui s'est passé et pourquoi » | S2 | BLOQUANT | Ligne « Épreuves 1/2 » avec l'icône de chaque verbe et la note obtenue (médaillon 32 px) ; remplacée par les objectifs du gros pilier quand il s'active |
| E6 | Flèche hors écran : triangle teinté, sans pictogramme ; se confond avec les autres repères | Hiérarchie, forme | S3 | CONSEIL | `cue_epreuve.png` 96 px (chevron double) + icône du verbe 32 px dedans |
| E7 | Récompense : l'or tombe en pièces (visible) ; le rubis de « parfait » n'est signalé qu'en fin de run | Retour < 0,5 s | S3 | CONSEIL | Sous la note : « +1 rubis » avec `icon_ruby` 32 px |
| E8 | Fin de run : « Épreuves +N » noyé dans la ligne des rubis | Récapitulatif | S3 | CONSEIL | Rangée de 8 médaillons de note 48 px (un par épreuve, case vide si non faite) |
| E9 | Libellé de note dans le monde en police de repli 36 px fixe | WCAG 1.4.4 | S4 | CONSEIL | Police du thème et échelle de texte |
| E10 | Contraste réel de la barre et des formes sur les quatre biomes | WCAG 1.4.11 | — | NON ÉVALUÉ | Capture `capture_epreuves` à prévoir (4 biomes × 5 verbes) |

---

## 6. Jauge « Guet » de Vigie et Gouttière d'Averse

### 6.1 Guet (`vigie_kit.gd`, `resource_gauge.gd`)

**État** : bonne base. La jauge générique utilise le kit Codex U1 (`ui/resource_gauge/*`), libellé « Guet », valeur « NN % », « PLEIN » qui pulse, émission de l'arc par paliers en jeu. Icône de passif : `ui/icons/passives/tension.png` (arc bandé, nommé d'après l'ancienne mécanique).

| # | Constat | Critère | Gravité | Statut | Recommandation |
|---|---|---|---|---|---|
| V1 | La règle centrale (immobile = remplissage 1,5 × plus rapide, 8 s au lieu de 12 s) n'est pas visible : `resource_state()` ne passe pas `regen` | Visibilité de l'état | S3 | CONSEIL | Passer `regen` (12,5 %/s ancrée = `1/GUET_STILL_S`, 8,3 %/s en marche = `1/GUET_MOVING_S`) et un repère « ANCRÉE » 18/26 px quand `is_anchored()` |
| V2 | Guet plein : signal visuel seulement | Jamais un seul canal | S3 | CONSEIL | Son court `vigie_guet_full` + vibration 60 ms (mobile, manette) |
| V3 | Icône de passif « tension » pour une jauge « Guet » | Cohérence nom / image | S4 | CONSEIL | Icône `guet.png` 128 px + `_e` (lot UX-G) |

### 6.2 Gouttière (`averse_rivulet.gd`)

**État** : tuiles Codex `rivulet_tile` (vide sombre / pleine cyan clair : contraste fort). Le déversement est un flash dessiné en code (sprite `rivulet_burst` refusé le 07/11/2026). Aucun indicateur dans le HUD.

| # | Constat | Critère | Gravité | Statut | Recommandation |
|---|---|---|---|---|---|
| G1 | Le remplissage est rendu par l'opacité uniforme de **toutes** les tuiles pleines : une gouttière à 50 % ressemble à une gouttière pleine délavée ; on lit mal « combien » | Forme plutôt que transparence | S3 | BLOQUANT | Remplissage séquentiel depuis l'embouchure : tuile k pleine si f ≥ (k + 1)/n, tuile courante en opacité partielle (aucun asset neuf) |
| G2 | Déversement en flash de code | Règle assets Codex | S3 | BLOQUANT | `rivulet_burst` à refaire (lot UX-F) |
| G3 | Aucun rappel dans le HUD de l'état de la gouttière posée | Visibilité de l'état | S4 | CONSEIL | Arc de remplissage autour du bouton du sort 3 (`spell_cooldown_ring.png` teinté eau) + « PLEINE » 18/26 px |

---

## 7. Réglage « Contours des zones de sorts » (`settings_panel.gd`, `zone_outline.gd`)

**État** : bascule texte dans l'onglet Accessibilité, désactivée par défaut ; affecte seulement les zones des sorts des joueurs (les contours ennemis et les télégraphes restent toujours visibles), y compris le cercle de visée de Vigie.

| # | Constat | Critère | Gravité | Statut | Recommandation |
|---|---|---|---|---|---|
| C1 | Aucune explication (l'infobulle n'existe qu'au survol souris ; rien en tactile ni à la manette) : le joueur ne sait pas ce que le réglage change | GAG « expliquer les options » | S3 | BLOQUANT | Sous-titre 20 px PC / 26 px mobile : « Trace le bord net des zones de vos sorts (cercles, bandes, cônes). Les attaques ennemies sont toujours contourées. » |
| C2 | Libellé ambigu avec les télégraphes ennemis | Modèle mental | S4 | CONSEIL | « Contours des zones de vos sorts » |
| C3 | Pas d'aperçu de l'effet | Divulgation progressive | S4 | CONSEIL | Aperçu vivant 320 × 180 px dans la ligne : un VFX de zone existant + `ZoneOutline`, rendu par le jeu (système, aucun asset neuf) |
| C4 | Lisibilité du liseré discret par défaut (opacité 0,4, 1,5 px) sur les quatre sols | WCAG 1.4.11 | — | NON ÉVALUÉ | Capture à prévoir |

---

## 8. Assets Codex à produire

Règles communes : rendu Blender cel-shadé sans normal maps, DA `art/briefs/STYLE_boss_da.md` + `STYLE_cel.md`, face caméra pour l'UI (pas d'iso), fond transparent, liseré sombre 2 px à la taille source pour la lecture sur fond clair comme sombre, masque `_e` seulement pour les accents lumineux, contraste ≥ 3:1 (médiane des pixels opaques) sur #1A1C20 et sur l'intérieur de `panel_small_9slice`. Éléments « teintables » : rendus en gris neutre clair (#D8D8D8 à #F0F0F0) pour être multipliés par `modulate` à la teinte d'équipe. Un lot à la fois, profil `eco-mini`, raisonnement `low`.

### P0 (bloquants)

**Lot UX-A : invites et appareils** (`game/assets/sprites/ui/prompts/`), même style que `pad_lb.png` (métal sombre, repère ambre), 64 × 64 px :

| Fichier | Description |
|---|---|
| `pad_start.png` | bouton Menu (trois traits), neutre entre marques |
| `pad_select.png` | bouton Vue (deux rectangles superposés) |
| `pad_dpad_lr.png` | croix directionnelle, branches gauche et droite en ambre |
| `pad_dpad_ud.png` | croix directionnelle, branches haut et bas en ambre |
| `device_keyboard.png` | clavier + souris stylisés, silhouette |
| `device_gamepad.png` | manette, silhouette |
| `device_gamepad_off.png` | même manette barrée d'une diagonale ambre-rouge, plus sombre |

7 fichiers. Brancher `pad_start` / `pad_select` / `pad_dpad_*` dans `KeyPrompt.PAD_ICONS`.

**Lot UX-B : Forge, lisibilité** :

| Fichier | Taille | Dossier | Description |
|---|---|---|---|
| `storm_core.png` + `storm_core_e.png` (v2, mêmes noms) | 256 × 256 | `game/assets/sprites/icons/` | noyau centré (marge 24 px), coque sombre, cœur cyan lumineux et éclairs ; plus de cadran de montre |
| `storm_core.png` + `_e` + `_shadow` (v2, mêmes noms, taille changée) | 96 × 96 | `game/assets/sprites/pickups/` | pickup iso 2:1, cœur émissif visible de loin, ombre cuite |
| `storm_core_halo.png` | 128 × 128 | `game/assets/sprites/pickups/` | halo additif cyan doux pour le pickup (texture du système de lumière) |
| `meche_silex.png`, `rosee_figee.png`, `rouage_traque.png`, `seve_rampante.png`, `ecorce_pluie.png`, `prisme_grele.png` (v2) + `_e` pour Mèche (étincelle), Rosée et Prisme (givre) | 256 × 256 | `game/assets/sprites/icons/items/` | médiane ≥ 3:1 sur #30201C, liseré clair, silhouettes distinctes (voir F3) |

Environ 15 fichiers. Vérifier après livraison que `ItemBar` et `ForgePanel` ne codent pas la taille 64 du pickup.

**Lot UX-C : Épreuves, interface** (reprend EP-F et l'étend) :

| Fichier | Taille | Dossier | Description |
|---|---|---|---|
| `minimap_epreuve_escorte.png` | 64 × 64 | `ui/da/` | barque vue de dessus |
| `minimap_epreuve_rituel.png` | 64 × 64 | `ui/da/` | anneau à 3 relais |
| `minimap_epreuve_poursuite.png` | 64 × 64 | `ui/da/` | lanterne / flamme courante |
| `minimap_epreuve_veine.png` | 64 × 64 | `ui/da/` | cristal-source avec tracé |
| `minimap_epreuve_tenue.png` | 64 × 64 | `ui/da/` | cloche |
| `epreuve_grade_parfait.png` + `_e` | 128 × 128 | `ui/da/` | médaillon à trois pointes, or |
| `epreuve_grade_bien.png` | 128 × 128 | `ui/da/` | médaillon à deux pointes, vert-de-gris |
| `epreuve_grade_fait.png` | 128 × 128 | `ui/da/` | médaillon rond simple, fer |
| `cue_epreuve.png` | 96 × 96 | `ui/cues/` | chevron double, même trait que `cue_elite.png`, gris neutre teintable au verbe |

10 fichiers. Les icônes de verbe servent à la minimap, à la barre de progression, au panneau Objectifs et à la flèche ; les médaillons servent au HUD, au panneau Objectifs (32 px) et à la fin de run (48 px) : la forme porte la note, la couleur la double.

**Lots EP-A à EP-E** (objets du monde des épreuves) : inchangés, voir `docs/Design_Epreuves.md` §9.

### P1

**Lot UX-D : coop** (`game/assets/sprites/ui/coop/`) :

| Fichier | Taille | Description |
|---|---|---|
| `team_card_9slice.png` + `.json` | 192 × 192, marges 24 | cadre de carte de lobby et de plaque, fer gris clair teintable |
| `team_pip.png` | 48 × 48 | pastille losangée gris clair pour le chiffre du joueur, teintable |
| `portrait_ring.png` | 128 × 128 | anneau de portrait rond, gris clair teintable, intérieur transparent |
| `status_spectator.png` + `_e` | 64 × 64 | œil-lanterne pâle : « spectateur jusqu'à l'étage suivant » |
| `icon_coop_local.png` | 96 × 96 | quatre silhouettes en arc, pour le bouton du titre |

6 fichiers (+ json). « Prêt » réutilise `ui/menu/icon_check.png`, « verrouillé » `ui/menu/icon_lock.png`, « absent » `device_gamepad_off` (lot UX-A).

**Lot UX-E : Forge, cadres** (`game/assets/sprites/icons/`) :

| Fichier | Taille | Description |
|---|---|---|
| `forge_recipe_9slice.png` + `.json` | 192 × 192, marges 28 | carte de recette cuivrée, rivets aux coins (réalisable) |
| `forge_recipe_9slice_off.png` | 192 × 192 | même carte éteinte, cuivre terni (indisponible) |
| `forge_gain_9slice.png` | 192 × 192 | carte du gain, cuivre plus clair avec liseré émissif `_e` |

3 à 4 fichiers. L'état focus reste une bordure de code `UiTheme.COL_FOCUS` (système de focus, pas un asset).

**Lot UX-F : VFX Gouttière** : `rivulet_burst` refait (refus du 07/11/2026), dossier `game/assets/sprites/characters/averse/variants/rivulet_burst/`, 6 frames 256 × 128 px par frame, additif, la nappe d'eau s'étire en largeur puis retombe en gouttes ; même cadrage que `rivulet_tile`.

### P2

**Lot UX-G : étiquettes et passif** :

| Fichier | Taille | Dossier | Description |
|---|---|---|---|
| `tag_feu.png`, `tag_crit.png`, `tag_givre.png`, `tag_poison.png`, `tag_zone.png`, `tag_survie.png`, `tag_auto.png`, `tag_recharge.png` | 48 × 48 | `game/assets/sprites/ui/icons/tags/` | pictogrammes monochromes clairs, lisibles à 32 px ; les 8 étiquettes utilisées par `recipes.json` |
| `guet.png` + `guet_e.png` | 128 × 128 | `game/assets/sprites/ui/icons/passives/` | œil de guetteuse dans une lanterne, même cadre rond que `tension.png` |

10 fichiers (les 8 autres étiquettes de `items.json` plus tard si l'inventaire les affiche).

**Lot UX-H : sons** (Codex, `art/tools/audio/`, sortie `game/assets/audio/ui/`, entrée dans `MANIFEST.md`) : `lobby_join`, `lobby_ready`, `lobby_tick`, `lobby_go`, `pad_lost`, `pad_restored`, `forge_craft`, `storm_core_gain`, `vigie_guet_full`, plus les sons EP-G de `Design_Epreuves.md` §9 (dont `epreuve_grade_{parfait,bien,fait}`, déjà appelés par le code). Mono 44,1 kHz, ≤ 1,2 s.

### Ordre conseillé

UX-A → UX-B → UX-C → EP-B/EP-D/EP-E → UX-D → UX-E → UX-F → UX-H → UX-G. Les corrections sans asset (portraits du lobby, invites existantes, remplissage séquentiel de la Gouttière, toasts du noyau, bandeau de déconnexion, sous-titre du réglage, débordement 4:3) peuvent être codées tout de suite, en parallèle des lots.

---

## 9. Risques et points à trancher

- **Contrastes réels non mesurés** : il faut des scènes de capture (`capture_coop`, `capture_forge`, `capture_epreuves`) sur les quatre biomes et en 16:9, 19,5:9 et 4:3 pour clore F5, E10 et C4.
- **Forme des invites** : les faces `pad_a` / `pad_b` sont en couleur (vert / rouge) avec la lettre ajoutée en texte par `KeyPrompt`. Pour les manettes PlayStation et Switch, les faces neutres `pad_btn_*` existent ; la détection de marque n'a pas été vérifiée (NON ÉVALUÉ).
- **Performance** : portraits dans les plaques = 4 textures déjà chargées par l'écran de sélection ; toasts plafonnés à 1 visible + 2 en file ; aucun coût par monstre.
- **Entrées** : dans le lobby, le stick gauche et le D-pad font la même chose (cohérent) ; ajouter les invites `pad_dpad_*` ne crée aucun conflit. Le compteur de noyaux près de l'or ne doit pas passer sous le pouce gauche sur mobile (zone du joystick flottant).
- **À trancher par le joueur** : (1) carte de lobby verticale avec grand portrait (recommandé) ou compacte horizontale ; (2) compteur de noyaux permanent dans le HUD ou seulement dans l'inventaire ; (3) reprise des 6 icônes forgées (recommandé) ou simple ajout d'un liseré clair.
