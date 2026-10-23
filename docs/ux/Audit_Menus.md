# Rainfall : audit UX/UI des menus et du parcours hors combat

> Consultant ux-designer, 22/10/2026. Périmètre : titre (feu de camp), Nouvelle run (cartes, fiche, modes, variantes),
> Progression, Réglages et Commandes, Crédits, pause et liste d'objets, dialogue de fin d'étage final, récap de fin de run,
> transitions entre étages, premier lancement et onboarding (`data/tips.json`). HUD, écrans de choix (coffres, niveaux)
> et remappage relèvent des audits parallèles.
> Référence : `docs/Design_Menus.md` (spec v1). Aucun code du jeu modifié.

## 0. Méthode et preuves

- **Code lu** : `scripts/app/app.gd`, `scripts/menu/{title_screen,new_run_screen,character_card,character_sheet,progress_screen,settings_screen}.gd`,
  `scripts/ui/{pause_menu,end_run_screen,run_screens,settings_panel,controls_panel}.gd`, `scripts/game/main.gd`,
  `scripts/stage/stage_manager.gd` (`next_stage`), `scripts/stage/floor_plan.gd`, `scripts/core/platform.gd`, `data/tips.json`.
- **Captures réelles** : scène temporaire `tests/_tmp_ux_menu_capture.tscn` (supprimée) pilotant la vraie `App` ; profil injecté
  (`Profile.path` absent → profil vierge, `write_enabled = false`), sauvegarde injectée (`user://_tmp_ux_run_save.json`, supprimée).
  24 images en **PC 1920×1080 (clavier-souris)** et 24 en **mobile 2400×1080 (`--mobile`, mode tactile)**, dans le scratchpad
  (`…/scratchpad/uxmenu/{pc,mobile}_NN_*.png`). Toutes ont été relues.
- **Non évalué** : manette réelle (focus vérifié par le code seulement), lecteur d'écran, appareil iOS (`can_quit` simulé seulement),
  vraie encoche (la zone sûre d'un PC renvoie 0) ; durée du chargement sur téléphone milieu de gamme.

### Comptage des appuis (mesuré)

| Parcours | Appuis | Temps mesuré (PC, fondus compris) |
|---|---|---|
| Lancement → titre | 0 | titre prêt à **0,5 s** |
| Premier lancement → run | **2** (Jouer, Commencer) | **2,6 s** après le 1er appui (2,8 s en mobile) |
| Reprise d'une run sauvegardée | **1** (Reprendre) | idem |
| Nouvelle run avec sauvegarde existante | **3** (Nouvelle run, Remplacer, Commencer) | idem |
| Mort → nouvelle run identique | **1** (Rejouer) | idem |
| Mort → autre personnage | **3** (Continuer, Jouer, Commencer) + choix |  |
| Pause → lire ses objets | 2 (pause, Objets) | |

Le chemin critique est **excellent** (2 appuis, < 3 s) : à ne pas dégrader. Les problèmes sont ailleurs : rien n'enseigne le jeu,
plusieurs états ne se lisent pas, quelques écrans ont échappé au thème.

---

## 1. Tableau des problèmes

Gravité : **S1** bloque ou trompe le joueur · **S2** friction forte ou critère d'accessibilité non tenu · **S3** gêne notable · **S4** finition.

| # | Écran | Constat (preuve) | Critère | Grav. | Type | Recommandation |
|---|---|---|---|---|---|---|
| M1 | Premier lancement | **Aucun onboarding** : `data/tips.json` (12 astuces) n'est lu par **aucun** script (`rg tips.json scripts` vide) ; l'écran de chargement ne vit que 2 images et n'affiche que « Chargement… » ; aucune consigne de déplacement, roulade, interaction ou pilier au début de la 1ʳᵉ run (`mobile_12_game_start`). Les commandes ne sont qu'en Réglages → Commandes (3 niveaux). | GAG « tutoriel / rappel des commandes » ; NN/g visibilité de l'état | **S1** | BLOQUANT | Lot M-A : invites contextuelles en jeu au premier lancement (§3.1) + astuces sur les écrans d'attente. |
| M2 | Nouvelle run | **Focus et sélection ont le même style** (bord orange `#FFB347` + halo) : au clavier/manette, le focus parcourt sans sélectionner (`new_run_screen.gd` l.6) ; deux cartes paraissent alors « choisies » (`pc_05` : Ardent et Taliant encadrées). Le joueur ne sait pas qui il lance. | WCAG 2.4.7 (focus visible) + 1.4.1 ; cohérence | **S1** | BLOQUANT | Sélection = cadre plein + coche + nom en clair sur la fiche ; focus = liseré pointillé/animé blanc 3 px. Ou : le focus sélectionne (fiche suit le focus, comme déjà au tactile). (Recommandé : le focus sélectionne.) |
| M3 | Nouvelle run | **Mode sélectionné illisible** : « Moyen » ne diffère de « Facile » que par un bord à peine plus clair (`pc_02`) alors que la spec veut un fond `#C23B12` ; le style DA (`panel_box` 9-slice) écrase la couleur. Difficile verrouillé = seulement 55 % d'opacité, pas de cadenas. Légendes « Scaling ×2 · rubis ×1 » : jargon. | 1.4.1 ; 1.4.11 (3:1) ; Hick | **S2** | BLOQUANT | État choisi = fond braise `#C23B12` α 1 + coche 32 px + texte blanc ; verrouillé = cadenas 40 px + texte gris. Légendes : « Monstres ×1 · Rubis ×0,8 » → « Plus doux · rubis −20 % », « Normal », « Plus dur · rubis +30 % ». |
| M4 | Pause (mobile) | En 2 colonnes, **« Quitter le jeu » déborde sous le cadre** (`mobile_13_pause`, bouton à y ≈ 795-875 px pour un cadre fini à ≈ 840). Abandonner (rouge) est voisin de Commandes. | Lisibilité, Fitts (erreur) | **S2** | BLOQUANT | `_layout()` : compter `n` réel et la ligne de régénération (2ᵉ ligne d'info absente du calcul `head`). Ordre 2 colonnes : Reprendre (pleine largeur) / Objets · Réglages / Commandes · Sauvegarder et quitter / Abandonner · Quitter le jeu en bas, Abandonner jamais adjacent à un bouton fréquent. |
| M5 | Transition d'étage | **Coupe franche** : `StageManager.next_stage()` détruit la carte et en recharge une dans la même image, sans fondu ni carton ; `FloorPlan.display_name()` (« Étage 2 · Forêt de brume ») existe mais **n'est appelé nulle part** (`pc_18`, `pc_19`). Seul retour : « +75 XP (or converti) », coupé par le bouton pause (`pc_19`, haut-droit). | NN/g visibilité de l'état ; retour < 0,5 s | **S2** | BLOQUANT | Fondu noir 0,35 s + carton « Étage 2 · Forêt de brume » 2,2 s (§3.3) ; invulnérabilité pendant le carton ; toast d'or déplacé sous l'or. |
| M6 | Fin d'étage final | `RunScreens.dialog` **hors thème** : boutons sans cadre, texte gris sur voile (`mobile_20`) : ressemblent à des libellés ; aucune affordance tactile ; « (victoire) » ambigu. | Affordance ; 1.4.11 | **S2** | BLOQUANT | Restyler avec `UiTheme` (Design_Menus §3.9 jamais appliqué) : « Terminer la run » principal 720×120, « Continuer sans fin » secondaire ; ligne « Terminer = victoire, rubis +25 ». |
| M7 | Cartes de perso | **Noms en 14 px** (bande `0,068 × 263 px` → `nfs ≈ 14`, espacés) en PC ; sous-titres 18 px, légende « Zone, débutant » ≈ 13 px ; les cartes non sélectionnées sont assombries au point de **paraître verrouillées** (`pc_02`). | WCAG cible projet ≥ 18 px ; 1.4.3 | **S2** | BLOQUANT | Nom ≥ 24 px sans interlettrage forcé ; cartes non choisies à 85 % de luminosité (pas 50 %) ; verrou = cadenas + « Verrouillé », jamais l'ombre seule. Grille 5×2 → hauteur de carte ≥ 300 px en PC (réduire la fiche à 40 % de largeur). |
| M8 | Fiche de perso | Texte réduit jusqu'à `0,8` (`TEXT_SCALES`) : description **16 px**, chiffres **14 px** ; à 0,92 en PC pour Ardent/Taliant (18 → 17 px). Variantes : 4 cases « Verrou » 16 px aux icônes presque noires (`pc_02`), bruit permanent pour un contenu non débloquable en v1. « Dégâts ×0 » affiché pour Aiguisage (`pc_04`). | ≥ 18 px ; divulgation progressive | **S3** | CONSEIL | Plancher 18 px (`TEXT_SCALES` min 0,9) puis défilement ; masquer la colonne de variantes tant qu'aucune n'est débloquée (un seul badge « 3 variantes à débloquer » ouvre la liste) ; ne pas afficher un coefficient nul. |
| M9 | Titre | Icône Réglages haut-droit **quasi invisible** (engrenage sombre sur fond sombre, contraste estimé < 2:1, `pc_01`) et doublon du bouton Réglages. Invite « [Échap] — » sans sens. « Godot 4.7 » dans la ligne de version. | 1.4.11 (3:1) | **S3** | CONSEIL | Supprimer l'icône (le bouton existe) ou l'éclaircir à `#E8EEF8` ; invites : « [Entrée] Valider · [F11] Plein écran » ; version seule, 22 px, 60 % d'opacité. |
| M10 | Titre / fond | Fond de carte **très sombre** : le feu de camp n'est qu'un point de braises au centre-droit (`pc_01`, `mobile_01`), l'écran paraît vide sur un téléphone en extérieur. | Direction §1.1 (sol L* ≥ 22) | **S3** | CONSEIL | Lumière `ember` énergie 0,8 → 1,4, rayon 6 → 9 u, zoom caméra centré sur le feu ; mesurer L* du sol ≥ 22 sur capture. |
| M11 | Réglages | Options de développement exposées : « Style de rendu : 3D (ancien) / Cel-shadé », « Afficher la hitbox » (jargon). Interrupteurs = boutons texte « Activé / Désactivé » sans forme d'interrupteur. 15 lignes dans une liste sans onglets : 3 écrans de défilement en mobile (`mobile_08`). | Hick ; affordance | **S3** | CONSEIL | Retirer « Style de rendu » (cel-shadé décidé) ; « Afficher la hitbox » → « Cercle de collision du héros ». Onglets Audio · Affichage · Jeu · Accessibilité (4 × 88 px). Interrupteur visuel 160×88 (brief §7 `toggle_on/off`). |
| M12 | Progression | Compteur de rubis en **rouge** (`pc_06`) alors qu'il est or au titre et au récap ; aucune progression visible vers les déblocages (toutes les cartes identiques) ; rien n'est cliquable, la fiche d'un perso n'est pas consultable d'ici. | Cohérence ; 1.4.1 | **S3** | CONSEIL | Rubis `#FFE9A8` partout ; barre d'objectif sous chaque carte verrouillée ; « Prochain déblocage » mis en avant (1 ligne en haut). |
| M13 | Récap de fin | Bon écran, mais : aucune explication des **rubis gagnés** (0 sans raison lisible, `mobile_22`) ; ne montre pas l'avancement vers les déblocages (Difficile, persos) ; tuiles aux icônes placeholders presque invisibles ; « Rejouer » sans rappel du perso/mode. | Visibilité de l'état ; boucle méta | **S3** | CONSEIL | Détail des rubis en une ligne 26 px : « Temps 0 · Piliers 0 · Victoire — · Or 0 » ; ligne « Prochain objectif : terminer une run en Moyen » ; « Rejouer (Ardent · Moyen) ». |
| M14 | Pause / Objets | 14 objets → 3,5 visibles en mobile (`mobile_14`), liste à défiler sans tri ni regroupement ; noms gris pour la qualité commune. | Hick ; 1.4.3 | **S4** | CONSEIL | Grille d'icônes 96 px (6-8 par ligne) + détail au toucher/focus (divulgation progressive), tri par qualité ; nom en couleur de rareté + étiquette texte (« Commun »). |
| M15 | Pause | Compte à rebours de 3 s **à chaque reprise**, même depuis un sous-menu ouvert par erreur. | Ressenti, friction | **S4** | CONSEIL | 3 s si la pause a duré > 5 s ou s'il y a un monstre < 6 u, sinon 1 s ; durée dans `Balance` (`RESUME_COUNTDOWN_S`). |
| M16 | Nouvelle run | Pas de raccourci « Lancer avec le dernier perso » depuis le titre après la 1ʳᵉ run ; 10 cartes + fiche + 3 modes à chaque fois (Hick). | Hick | **S4** | CONSEIL | Sous « Jouer », en 26 px : « Ardent · Moyen » ; appui long / [Y] = lancer directement (option, pas le défaut). |
| M17 | Dialogues | `ConfirmDialog` « Remplacer la run » bien construit (Annuler à gauche, focus neutre, `mobile_24`) : **conforme**. Échap au titre ne fait rien : **conforme**. iOS sans Quitter : conforme au code (`can_quit`), **non évalué** sur appareil. | — | — | — | Rien à changer. |

---

## 2. Parcours cible

```
Lancement ── titre (0,5 s) ─┬─ [Reprendre]  (si sauvegarde)                 → chargement + astuce → JEU      (1 appui)
                            ├─ [Jouer]  « Ardent · Moyen » en sous-titre     → NOUVELLE RUN
                            │     focus = sélection ; mode choisi évident    → [Commencer] → JEU              (2 appuis)
                            ├─ Progression · Réglages (onglets) · Crédits · Quitter (hors iOS)
                            └─ 1ᵉʳ lancement : Jouer mis en avant, rien d'autre ne change
JEU (1ʳᵉ run seulement) : invites contextuelles 1 par 1 (déplacement → sort auto → roulade → interagir → pilier)
   Pause : Reprendre · Objets (grille) · Réglages · Commandes · Sauvegarder et quitter · Abandonner · Quitter
   Téléporteur : fondu 0,35 s → carton « Étage N · Biome » 2,2 s (invulnérable) → fondu 0,5 s
   Étage final : dialogue thémé (Terminer = victoire / Continuer sans fin)
FIN : récap (rubis détaillés + prochain objectif) → [Rejouer (Ardent · Moyen)] | [Continuer → titre]
```

Budget : appuis inchangés (1 / 2 / 1) ; aucune étape ajoutée au chemin critique ; l'onboarding vit **dans la run**, pas devant.

---

## 3. Recommandations chiffrées

### 3.1 Onboarding (M1) : options
1. **Invites contextuelles en jeu (Recommandé)** : au premier lancement (`Profile.stats.runs == 0`, clé `Profile.seen_hints`), une seule
   bulle à la fois, ancrée au-dessus du héros ou du bouton concerné, 32 px, fond `#1a1620` α 0,9, invite de touche selon
   `Platform.input_mode` (`KeyPrompt`). Séquence et déclencheurs : déplacement (t = 0, disparaît après 2 u parcourues) → « Le sort 1 tire tout seul »
   (1ᵉʳ kill) → roulade (1ᵉʳ dégât subi ou t = 25 s) → interagir (≤ 3 u d'une capsule ou d'un coffre) → pilier (≤ 6 u du 1ᵉʳ pilier)
   → téléporteur (étage nettoyé). Durée max 6 s chacune, jamais pendant un télégraphe de boss, désactivables (« Astuces de jeu » dans Réglages › Jeu).
   Théorie : onboarding par le jeu, divulgation progressive. Coût : 1 nœud HUD, aucun impact perf.
2. **Astuces sur les écrans d'attente** : `tips.json` en 26-28 px sur le carton d'étage (§3.3) et sur le récap de mort (une astuce liée à
   la cause si possible). Complément de l'option 1, pas un remplacement : le chargement dure 2 images, inutile d'y mettre du texte.
3. Tutoriel dédié (carte d'entraînement) : rejeté pour la v1 (+1 écran, contraire à « 2 appuis »).

### 3.2 Nouvelle run (M2, M3, M7, M8)
- **Le focus sélectionne** (Recommandé) : `focus_entered` d'une carte → `_select_character(i, true)` ; un perso verrouillé reste focusable
  et affiche son objectif, Commencer désactivé avec « Personnage verrouillé » (déjà codé). Un seul style « choisi ». Alternative : deux styles
  distincts (focus pointillé blanc 3 px, sélection cadre orange 4 px + coche 40 px).
- Modes : boutons segmentés 290×96, choisi = fond `#C23B12` + coche 32 px + texte `#FFFFFF` (contraste 5,6:1 estimé), non choisi = fond `#2B3340`.
  Verrouillé = cadenas 40 px + texte `#7C8898` + tooltip au toucher (déjà codé).
- Cartes : nom ≥ 24 px (bande ≥ 30 px de haut), sous-titre ≥ 18 px, luminosité des non-sélectionnées 0,85 ; fiche à 40 % de largeur (≥ 720 px)
  pour donner ≥ 300 px de haut aux cartes en 16:9.
- Fiche : `TEXT_SCALES = [1.0, 0.95, 0.9]` (plancher 18 px pour la description), défilement au-delà ; variantes repliées tant que toutes
  sont verrouillées ; masquer « Dégâts ×0 ».

### 3.3 Transition d'étage (M5)
Fondu noir 0,35 s (FadeLayer existant) → carton centré : « ÉTAGE 2 » 64 px + « Forêt de brume » 40 px (`FloorPlan.display_name`) + astuce 28 px,
2,2 s (toucher ou [A]/[Entrée] = passer après 0,8 s) → fondu 0,5 s ; `RunState.running = false` pendant le carton, invulnérabilité 1,5 s
à l'arrivée (même valeur que la reprise de pause). « +N XP (or converti) » affiché **sur le carton** plutôt qu'en toast HUD.
Valeurs dans `Balance` : `FLOOR_CARD_S = 2.2`, `FLOOR_FADE_OUT_S = 0.35`, `FLOOR_FADE_IN_S = 0.5`.

### 3.4 Pause (M4, M14, M15)
- Mise en page : calculer `head` avec le nombre réel de lignes d'info (chrono + régénération) ; en 2 colonnes, « Reprendre » sur toute la
  largeur, puis paires ; boutons ≥ 96 px de haut (OK), 16 px d'écart (OK).
- Objets : grille d'icônes 96 px, détail en panneau latéral au focus/toucher, tri par qualité, nom coloré + mot de rareté.
- Compte à rebours : 3 s / 1 s selon le danger (§1 M15).

### 3.5 Titre, Réglages, Progression, Récap (M9-M13)
Voir colonne « Recommandation ». Chiffres clés : icône Réglages supprimée ; lumière du feu énergie 1,4 / rayon 9 u ; Réglages en 4 onglets 88 px ;
rubis toujours `#FFE9A8` ; ligne de détail des rubis 26 px ; « Rejouer (Ardent · Moyen) ».

### Risques
- Accessibilité : M2 et M3 touchent WCAG 1.4.1/2.4.7 (S1/S2) ; les invites (§3.1) doivent respecter « Flashs réduits » (pas de pulsation > 3 Hz).
- Perf : carton d'étage = 3 `Label` + fondu, négligeable ; les invites, un seul nœud réutilisé.
- Entrées : « le focus sélectionne » change le test `new_run_test` (`ui_right ×2` sélectionnerait un verrouillé : Commencer désactivé, ce qui est voulu).
- **À trancher par le joueur** : option 1 de M2 (focus = sélection) ; garder ou non le compte à rebours fixe de 3 s ; masquer les variantes en v1.

---

## 4. Plan d'implémentation (lots indépendants, par priorité)

| Lot | Priorité | Contenu | Fichiers | Test |
|---|---|---|---|---|
| **M-A Onboarding** | P1 | Invites contextuelles 1ʳᵉ run (§3.1), clé `seen_hints` + réglage « Astuces de jeu » | nouveau `scripts/ui/onboarding_hints.gd` ; `scripts/save/profile.gd` (clé) ; `scripts/ui/game_settings.gd` + `settings_panel.gd` (1 ligne) ; branchement dans `hud.gd` (1 ligne, à coordonner avec l'audit HUD) | `tests/onboarding_test.tscn` : profil vierge → 1ʳᵉ invite visible ; profil `runs ≥ 1` → aucune |
| **M-B Nouvelle run lisible** | P1 | M2, M3, M7, M8 | `scripts/menu/new_run_screen.gd`, `character_card.gd`, `character_sheet.gd` | `new_run_test` adapté + capture PC/mobile |
| **M-C Transition d'étage** | P1 | Fondu + carton + astuces (§3.3), constantes `Balance` | nouveau `scripts/ui/floor_card.gd` ; `scripts/game/main.gd` (écoute de `stage_started` n > 1) ; `scripts/core/balance.gd` (orchestrateur) | `floor_card_test` : `next_stage()` → carton avec `display_name`, `running == false` pendant 2,2 s |
| **M-D Pause** | P2 | M4 (débordement), ordre des boutons, grille d'objets M14, compte à rebours M15 | `scripts/ui/pause_menu.gd` | `menu_wave3_test` + capture mobile 2400×1080 : tous les boutons dans le cadre |
| **M-E Dialogue de fin d'étage** | P2 | M6 : `RunScreens.dialog` thémé (UiTheme, principal/secondaire, focus) | `scripts/ui/run_screens.gd` | capture + test focus |
| **M-F Récap et Progression** | P3 | M12, M13 : détail des rubis, prochain objectif, rubis or, barres d'objectif | `scripts/ui/end_run_screen.gd`, `scripts/menu/progress_screen.gd` (+ API lecture `Profile.next_objective()` si besoin : `profile.gd`, à coordonner avec M-A) | `end_run_test` |
| **M-G Titre et Réglages** | P3 | M9, M10, M11, M16 : icône, invites, version, lumière du feu, onglets, retrait « Style de rendu » | `scripts/menu/title_screen.gd`, `menu_background.gd`, `scripts/ui/settings_panel.gd` | `title_test`, `settings_test` |
| **Assets (brief Codex)** | P3 | `icon_lock.png` 96, `icon_check.png` 64, `toggle_on/off.png` 160×88, `focus_frame_9slice.png` 96 (pointillé, distinct de la sélection), icônes de stats du récap 96 (déjà au brief §7 de Design_Menus) | `art/briefs/ui_menu.md` | — |

Chevauchements : M-A et M-F touchent tous deux `profile.gd` (ajouts distincts, à séquencer) ; M-A touche une ligne de `settings_panel.gd`
comme M-G : faire M-G après M-A. Les autres lots sont disjoints.

---

## 5. Sources
- WCAG 2.1 : contraste 1.4.3 / 1.4.11, usage de la couleur 1.4.1, focus visible 2.4.7, taille de cible 2.5.5 — https://www.w3.org/TR/WCAG21/
- Game Accessibility Guidelines (rappel des commandes, tutoriels, texte lisible) — https://gameaccessibilityguidelines.com/full-list/
- Nielsen Norman Group, visibilité de l'état du système — https://www.nngroup.com/articles/visibility-system-status/
- Nielsen Norman Group, divulgation progressive — https://www.nngroup.com/articles/progressive-disclosure/
- Loi de Hick et loi de Fitts, Laws of UX — https://lawsofux.com/hicks-law/ , https://lawsofux.com/fittss-law/
- Android, cibles tactiles ≥ 48 dp — https://developer.android.com/guide/topics/ui/accessibility/apps#large-controls
- Apple HIG, zones sûres en paysage — https://developer.apple.com/design/human-interface-guidelines/layout
- Projet : `docs/Design_Menus.md` (§2.1 tailles, §2.4 transitions, §3.9, §3.11), `docs/Direction_Lumiere_Ambiance.md` §1.1.
