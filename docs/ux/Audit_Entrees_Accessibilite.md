# Audit UX : entrées et accessibilité (Rainfall)

Auteur : consultant ux-designer · 22/10/2026 · périmètre : entrées (tactile, clavier-souris, manette, invites de touches) et accessibilité transversale. Le HUD, les menus et les écrans de choix sont traités par d'autres audits.

> **Méthode et limites.**
> - L'audit repose sur la **lecture du code** : `platform.gd`, `input_setup.gd`, `game/scripts/ui/*`, `fx/*`, `enemies/enemy_telegraph.gd`, `ambiance/*`, `game_settings.gd` et `settings_panel.gd`.
> - Les **couleurs** ont été comparées par calcul, à partir des constantes du code :
>   - simulation de la protanopie, de la deutéranopie et de la tritanopie (Machado 2009, sévérité 1,0) ;
>   - écart de couleur ΔE2000 et contraste WCAG ;
>   - script : `scratchpad/ux_input/cvd.py`.
> - **Aucune capture n'a été faite.** L'orchestrateur a interdit de lancer Godot pendant que le joueur utilise la machine. Les points qui demandent une image sont donc marqués **NON ÉVALUÉ (capture à faire)**.
> - Les teintes de sol utilisées pour le télégraphe et l'eau sont des valeurs types, pas des mesures. Ces chiffres sont **estimés**.
> - La scène temporaire `_tmp_ux_input_cap` avait été écrite. Elle n'a jamais été lancée et elle est supprimée.
>
> **Conversion en millimètres** (téléphone de 6,1 pouces au format 19,5:9, en paysage) :
> - hauteur d'écran ≈ 64,9 mm pour 1 080 px logiques, soit **1 px ≈ 0,060 mm** ;
> - une cible de 9 mm mesure donc **≈ 150 px**.

---

## 1. Synthèse

**Points forts :**
- Les entrées passent par des actions simulées. Le changement de mode d'entrée est propre : `Platform.input_mode` bascule au dernier périphérique utilisé.
- Les invites de touches suivent le mode, et le nom des touches tient compte de la disposition du clavier.
- La manette vise au stick droit ; sans stick, le sort vise l'ennemi le plus proche.
- Une option « Sorts automatiques » existe, utile pour jouer d'une seule main.
- Le jeu a 5 volumes séparés.
- L'appui long sur Pause est réglable.
- L'anneau de hitbox est réglable.
- Les statuts des élites et des boss ont des icônes à glyphe, en plus de la couleur.
- L'eau profonde se distingue par sa luminance, pas seulement par sa teinte.
- Le focus est visible : contour `COL_FOCUS` #FFB347, contraste de 7,55:1 sur le panneau.

**Les 5 problèmes les plus graves :**
1. **Le « Mode daltonien » ne fait rien** (A-01). Le réglage est enregistré, mais aucun code ne le lit. C'est une fausse promesse d'accessibilité. En protanopie et en deutéranopie, brûlure et poison se confondent (ΔE 4,4 à 7,1).
2. **Les télégraphes rouges sont trop pâles**, surtout pour les protanopes (A-04). Le remplissage disparaît : ΔE 1,4 à 4,5 avec le sol. Le bord n'atteint que 1,9 à 2,2:1 en protanopie, et 2,7 à 3,1:1 en vision normale, sous le seuil de 3:1.
3. **Pas de remappage des touches** (E-01). C'est écrit dans `controls_panel.gd` : « Pas de remappage en v1 ». La molette lance aussi le sort 4 : un défilement accidentel lance l'ultime.
4. **Les flashs et secousses ne sont réglés qu'en partie, dans un seul réglage commun** (A-07). `LightRig.flash` (31 appels) et `HurtFeedback` ignorent ce réglage. Les secousses ne se règlent pas à part. La valeur par défaut est « Complets ».
5. **Plusieurs problèmes à la frontière du tactile et du système** (E-03, E-04, E-05) :
   - Le bouton Retour d'Android et le geste de retour depuis le bord ne sont pas gérés. Le joystick commence au pixel 0, exactement là où part ce geste.
   - Le bandeau du haut et le bouton Pause n'utilisent pas la zone sûre, alors que l'encoche peut se trouver à gauche ou à droite.
   - Le joystick est probablement dessiné décalé de 540 px.
   - L'haptique est réglable, mais aucun code ne vibre.

---

## 2. Tableau des problèmes

**Gravité :**
- **S1** : bloque ou trompe une partie des joueurs.
- **S2** : friction forte ou non-conformité nette.
- **S3** : gêne modérée.
- **S4** : finition.

**BLOQUANT** = à corriger avant la sortie. **CONSEIL** = amélioration.

### 2.1 Entrées

| ID | Constat (fichiers) | Critère | Grav. | Statut | Recommandation |
|---|---|---|---|---|---|
| E-01 | Aucun remappage : `InputSetup.KEYS` / `JOY_BUTTONS` sont des constantes, et `controls_panel.gd` dit « Pas de remappage en v1 ». Rien n'est prévu pour les gauchers, ni au clavier ni en tactile (grappe de boutons figée à droite). | GAG « Allow controls to be remapped » ; XAG 107 | S2 | BLOQUANT | Remapper les actions de jeu au clavier et à la manette (§3.1). En tactile, ajouter une option « Disposition miroir » (boutons à gauche, joystick à droite). |
| E-02 | La molette (haut ET bas) lance le sort 4 (`MOUSE_BUTTONS.spell_4`). Un défilement involontaire ou une molette « libre » enchaîne les ultimes. | GAG « Avoid / provide alternatives to accidental activation » | S3 | CONSEIL | Lier le sort 4 au **clic molette seul** par défaut ; la rotation de la molette devient une liaison facultative. |
| E-03 | Android : `NOTIFICATION_WM_GO_BACK_REQUEST` n'est pas géré et `application/config/quit_on_go_back` garde sa valeur par défaut (vrai). Retour = l'appli quitte en pleine partie (une sauvegarde automatique a lieu, mais la sortie est brutale). Le joystick (`hud.gd`, `anchor_left = 0`) part du bord gauche, comme le geste de retour système. | Modèle mental de la plateforme ; Android « gesture navigation conflicts » | S2 | BLOQUANT | `quit_on_go_back = false` ; Retour = ouvrir la pause (en pause : Retour = Reprendre). Garder la zone du joystick à ≥ `safe.left + 24 px` du bord (≈ 72 px), et ne pas l'étendre sous 32 px du bas (barre de gestes). À vérifier sur appareil. |
| E-04 | Zones sûres incomplètes. `safe_margins()` ne sert qu'à la grappe en bas à droite et aux objectifs. Le bandeau du haut (marge fixe de `30*s`), le bouton Pause (`24*s` du bord), la minimap et le joystick l'ignorent. En paysage capteur, l'encoche bascule à gauche ou à droite **sans que la taille change**, donc la mise en page n'est jamais recalculée. | Directives Apple/Android (safe area) ; « rien sous l'encoche » | S2 | BLOQUANT | Tout le HUD tactile dans un `SafeArea` racine. Recalculer au changement d'orientation : sondage de `DisplayServer.get_display_safe_area()` toutes les 0,5 s ou `NOTIFICATION_WM_SIZE_CHANGED` + `screen_get_orientation`. Marges : max(encoche, 48 px) sur les côtés, max(encoche, 32 px) en haut et en bas. NON ÉVALUÉ sur appareil. |
| E-05 | Joystick : `_draw()` dessine à `_origin - global_position`, alors que `_origin` vient de `_gui_input` (coordonnées déjà locales). Avec `anchor_top = 0.5`, l'anneau serait donc dessiné **≈ 540 px au-dessus du pouce**. Il n'est affiché que pendant l'appui et n'utilise pas les textures `ui/joystick/joystick_base.png` et `knob.png` déjà livrées. | Retour < 0,5 s, affordance | S2 | BLOQUANT (si confirmé) | Dessiner à `_origin` et `_knob` directement. Brancher les textures livrées. Anneau de repos facultatif à 35 % d'opacité à l'endroit du dernier appui. **NON ÉVALUÉ (capture à faire)** : à confirmer par une capture du joystick en tactile simulé. |
| E-06 | Taille des cibles tactiles (1 px ≈ 0,060 mm) : sorts 128 px ≈ **7,7 mm** (< 9 mm) ; roulade 176 px ≈ 10,6 mm (OK) ; Pause 110 px ≈ **6,6 mm** ; Interagir 400×140 px ≈ 8,4 mm de haut ; case d'inventaire (appui long) 64 px ≈ **3,8 mm**. Écart entre la roulade et les sorts : 38 px ≈ 2,3 mm (juste). | Fitts ; règle maison ≥ 9 mm ; WCAG 2.5.5 (AAA, 44 pt) | S2 | BLOQUANT (sorts) / CONSEIL (autres) | Sorts **150 px** (9 mm). Zone de frappe invisible de **+16 px** autour de chaque bouton (sans chevauchement). Pause : zone de frappe 140 px, visuel 110 px. Cases d'inventaire tactiles : zone de frappe 96 px. Écart minimal entre deux cibles : 40 px. |
| E-07 | Bouton Interagir à `(-890, -180)` du coin bas-droit, soit ≈ 53 mm du bord droit : hors de la zone naturelle du pouce droit (rayon confortable ≈ 45 mm depuis le coin). | Zones de pouce (Hoober) | S3 | CONSEIL | Le placer à ≤ 620 px du bord droit, au-dessus du sort 3, ou autoriser l'interaction par **appui sur la roulade quand une cible est à portée et la roulade inutile**. Option plus simple : accepter aussi un toucher sur l'objet lui-même dans le monde. |
| E-08 | Appui long sur un sort (0,4 s, `spell_button.gd`) : affiche la description et **annule le lancer**. En combat, un pouce qui reste posé 0,4 s perd son sort sans aucun retour. | Modèle mental (même geste = même effet) ; GAG « avoid holding » | S2 | CONSEIL | Passer le seuil à **0,6 s**, et seulement si le doigt glisse de moins de 12 px. Sinon, lancer le sort au relâcher même après le seuil. Description accessible aussi en pause (fiche du sort). |
| E-09 | Manette : les noms et icônes des boutons sont toujours au format Xbox (A/B/X/Y). Sur PlayStation ou Switch (où A et B sont inversés à l'écran), l'invite « A » désigne le bouton du bas, marqué B ou ✕. Les icônes positionnelles livrées `pad_btn_bottom/left/right/top`, `pad_lt/rt`, `pad_stick_*` ne servent pas. | XAG 101/112 (invites cohérentes) ; GAG « clear prompts » | S3 | CONSEIL | Lire `Input.get_joy_name()` → famille xbox / ps / nintendo / générique. Les familles PS et générique utilisent les icônes `pad_btn_*` positionnelles. Ajouter LT/RT (axes) dans `action_prompt_parts` (aujourd'hui seuls les boutons sont listés). |
| E-10 | AZERTY : `spell_2..4` sont liés aux touches **physiques** 1/2/3. `action_label()` traduit avec `keyboard_get_keycode_from_physical`, ce qui affiche probablement « & », « é », « " » au lieu de 1/2/3. Par ailleurs, `controls_help()` (mode clavier) écrit en dur « ZQSD / WASD », « E », « Échap », « Shift gauche / Espace » au lieu de lire les liaisons. | Invites exactes | S3 | CONSEIL | Pour les touches de la rangée des chiffres, afficher le chiffre (table physique → libellé). `controls_help()` construit toutes ses lignes avec `action_hint()`, ce qu'impose de toute façon le remappage. NON ÉVALUÉ (capture AZERTY à faire). |
| E-11 | Manette débranchée en partie : aucun `Input.joy_connection_changed`, donc aucune pause automatique. | XAG 107 ; règles des consoles | S3 | BLOQUANT (console) / CONSEIL (PC) | Débranchement en mode manette → ouvrir la pause et afficher « Manette déconnectée ». |
| E-12 | Focus au pad quand le mode change avec un menu ouvert : seuls le titre, la nouvelle partie, les crédits et les commandes écoutent `input_mode_changed`. Pause, réglages, fin de run et coffre ne posent le focus qu'à l'ouverture, et pas en tactile. Ouvert au doigt puis repris à la manette : aucun élément focalisé, le pad est « mort » jusqu'au premier appui. | XAG 112 (navigation à la manette) | S2 | BLOQUANT | Règle commune (UiTheme) : tout écran modal écoute `input_mode_changed`. Au passage en KBM ou GAMEPAD sans focus, il appelle `grab_focus` sur le dernier focus ou sur le premier élément. NON ÉVALUÉ (capture focus au pad à faire). |
| E-13 | Focus visible : `COL_FOCUS` #FFB347, contour de 4 px (repli) ou 9-slice `focus_frame_9slice.png`. Contraste de 7,55:1 contre le panneau, conforme à SC 2.4.7 / 1.4.11 dans les styles de boutons. Le rendu sur les cartes de personnage, le curseur de volume et `OptionStepper` n'a pas été vu. | WCAG 2.4.7, 1.4.11 | — | NON ÉVALUÉ (capture à faire) | Vérifier que le focus des cartes reste distinct de leur survol et de leur sélection (épaisseur ≥ 4 px à 1080p, ≥ 3:1 contre le fond **et** contre l'état sélectionné). |
| E-14 | Inventaire du HUD : les infobulles d'objets ne s'ouvrent qu'au survol de la souris ou à l'appui long. À la manette, aucun moyen de lire un objet en partie, hors panneau « Objets » de la pause (navigation non vérifiée). | XAG 112 ; parité des entrées | S3 | CONSEIL | Panneau « Objets » de la pause entièrement navigable au pad, avec description dans le focus. NON ÉVALUÉ (capture à faire). |
| E-15 | Invites de sorts masquées après 5 s (`KEY_HINTS_SHOW_S`) sauf réglage contraire. L'invite d'interaction est du texte « [E] Partir », sans les icônes de `KeyPrompt`. Les menus n'affichent aucune invite (« B Retour », « A Valider »). | Divulgation progressive ; GAG « clear prompts » | S4 | CONSEIL | Garder les 5 s, mais réafficher 3 s après chaque changement de mode d'entrée. L'invite d'interaction utilise `KeyPrompt` (icône 44 px). Barre d'aide en bas des menus au pad ou au clavier : « Ⓐ Valider · Ⓑ Retour », hauteur 48 px. |
| E-16 | Le mode clavier-souris passe en manette si un axe dépasse 0,5. Le retour en clavier-souris demande un mouvement de souris de plus de 3 px. C'est robuste. Seul risque : un stick qui dérive au-delà de 0,5, rare. | — | S4 | CONSEIL | Garder. Éventuellement ignorer les axes de gâchette au repos (certaines manettes envoient −1). |

### 2.2 Accessibilité

| ID | Constat (fichiers, chiffres) | Critère | Grav. | Statut | Recommandation |
|---|---|---|---|---|---|
| A-01 | **Le mode daltonien ne fait rien** : `GameSettings.colorblind()` n'est lu par aucun code (recherche : seuls `game_settings.gd` et `settings_panel.gd` le mentionnent). | Honnêteté des réglages ; GAG « colour » | S1 | BLOQUANT | Soit le brancher (§3.2), soit masquer le réglage tant qu'il ne fait rien. Un réglage d'accessibilité inopérant est pire qu'un réglage absent. |
| A-02 | Statuts des **monstres de base** : la barre est teintée par le statut dominant, **couleur seule**. Brûlure #F07A2A contre poison #8DAA3C : ΔE 41,6 en vision normale, **7,1 en protanopie, 4,4 en deutéranopie**. Les auras d'élite (`EnemyAura`) ont le même défaut (burn/poison ΔE 15,1 / **6,3**), comme les couleurs des mini-boss (**5,0** en deutéranopie ; poison/gel **9,5** en tritanopie). Les élites et les boss ont des icônes à glyphe (`status_*.png`) : conforme. | WCAG 1.4.1 ; GAG « don't rely on colour alone » | S2 | BLOQUANT | Le monstre de base porte un **pictogramme de 16 px** au bout de sa barre (réutiliser `status_<id>.png` réduit) quand un statut domine. Pas de nouvelle UI par monstre : la barre poolée l'ajoute. Auras : motif par affixe (anneau plein = brûlure, pointillé = poison, double anneau = gel). Palette daltonienne (§3.2). |
| A-03 | Chiffres de dégâts : **critique (1, 0,32, 0,18) contre dégât subi (1, 0,13, 0,13) : ΔE 6,1 même en vision normale** (3,4 en deutéranopie). Critique contre feu : 13,7 / 5,4. Glace contre foudre : **2,7** en deutéranopie. Taille : 19 px (×0,8 = 15 px en « Petits »). Contraste sur sol clair de pierre : **1,89:1** (estimé). | WCAG 1.4.1, 1.4.3 ; règle maison ≥ 18 px | S2 | BLOQUANT (subi/critique) | Le dégât subi se distingue par la **forme** : préfixe « − », position au-dessus de la tête (déjà fait) et contour épais de 4 px. Le critique garde son icône. Taille minimale de 20 px quel que soit le réglage (Petits = 20, Normaux = 24, Grands = 30). Contour sombre de 3 px minimum pour garder ≥ 3:1 sur les sols clairs. |
| A-04 | Télégraphes rouges (`EnemyTelegraph`, couleur seule) :<br>• remplissage (0,95, 0,10, 0,10) à 0,18 : **contraste ≈ 1,0 à 1,16:1**, ΔE 1,4 à 4,5 en protanopie ;<br>• bord (1, 0,25, 0,20) à 0,9 : **2,7 à 3,1:1** en vision normale, **1,9 à 2,2:1** en protanopie ;<br>• progression à 0,35 : 1,02 à 1,11:1 en protanopie. Estimé sur 3 sols types. | WCAG 1.4.11 (3:1) ; règle maison « télégraphe par forme ET contraste » | S1 | BLOQUANT | Bord **double** : liseré clair (#FFE2C8, 2 px, alpha 1) + trait rouge de 4 px, ce qui donne ≥ 4,5:1 sur tous les sols, quelle que soit la vision. Remplissage à 0,28. Progression par **anneau qui se resserre** (forme), et non par une teinte plus dense. Motif hachuré facultatif (réglage « Télégraphes renforcés »). Mesures réelles : NON ÉVALUÉ (capture à faire). |
| A-05 | Raretés : peu commun (vert) contre légendaire (orange) : **ΔE 7,7 en protanopie, 10,5 en deutéranopie**. Peu commun contre rare : 14,2 en tritanopie. Le coffre écrit le nom de la rareté (bien). La barre d'objets du HUD n'a que le cadre coloré : savoir si `frame_<qualité>.png` diffèrent par leur **forme** est NON ÉVALUÉ. | WCAG 1.4.1 | S3 | CONSEIL | Différencier les cadres par la forme : coins / gemme ×0, ×1, ×2, ×3 selon la rareté (brief Codex, 64 et 128 px). Infobulle : nom de la rareté en toutes lettres. |
| A-06 | Paliers de difficulté : Calme, Tendu et Hostile se confondent en protanopie et en deutéranopie (ΔE 10,6 à 16). Le nom est écrit : le défaut est atténué. Monstres de substitution : essaim contre brute **4,5 / 6,9** (à remplacer par des sprites). | WCAG 1.4.1 | S4 | CONSEIL | Garder le libellé. Jauge segmentée (5 crans) en plus de la couleur. |
| A-07 | **Flashs et secousses** : un seul réglage commun, « Flashs et secousses » (`flashes_level`, défaut 2 = complets). Ce réglage est respecté par : éclairs, `HitboxRing`, `boss_pace`, secousses du joueur et des kits (× `flash_mult()`), `enemy_health_bars`. Il est **ignoré** par : `LightRig.flash` (31 appels : coffres, montée de niveau, impacts de kit), `HurtFeedback` (vignette rouge), éclat de rareté du coffre (`chest_ui`). Il n'y a ni réglage de secousse séparé, ni « réduire les mouvements ». La valeur est stockée deux fois (`Quality` section « quality » et `GameSettings` « graphics/flashes ») : risque de désynchronisation. Respect du maximum de 3 flashs par seconde en combat dense : NON ÉVALUÉ (mesure à faire). | WCAG 2.3.1 ; GAG « avoid flicker », « camera shake option » ; XAG 117 | S2 | BLOQUANT | Séparer en **3 réglages** : « Flashs » (0 / 25 / 100 %), « Secousses de caméra » (curseur 0-100 %, pas de 10), « Réduire les mouvements » (bascule : pas de hitstop, pas de tremblement de barre, pulsation de PV bas fixe). `LightRig.flash` multiplie son énergie par `flash_mult()`. Plafond global : 3 éclats plein cadre par seconde, les suivants fusionnés. Une seule source de vérité : `GameSettings`. |
| A-08 | Taille du texte : HUD `_hp_label` **16 px**, `_hp_regen` **14 px**, nom 20 px, difficulté 22 px (à `s = 1`). Sur petite fenêtre PC, `s` descend à 0,6 → 8,4 px. Pas de réglage global de taille du texte ou de l'interface (seulement les chiffres de dégâts). Les réglages eux-mêmes sont confortables : 34-40 px. | Règle maison ≥ 18 px à 1080p ; WCAG 1.4.4 (agrandissement à 200 %) ; GAG « text size » | S2 | BLOQUANT | Plancher de **18 px** au rendu final (`max(18, base × s)`). Réglage « Taille de l'interface » : 100 / 125 / 150 %, appliqué au thème et au facteur `s` du HUD, ce qui couvre une partie de SC 1.4.4. Écrans très étroits : tester 4:3. NON ÉVALUÉ (capture à faire). |
| A-09 | Contrastes de texte de l'interface (calculés) : `COL_TEXT` 10,9:1, `COL_MUTED` 6,3:1, titre de groupe 9,9:1, invite 12:1 : conformes. **Bouton primaire FFE9A8 sur C23B12 : 4,45:1**, juste sous 4,5:1 (passe en grand texte ≥ 24 px). Barre de PV ennemie sur son fond : 3,33:1 (OK pour 1.4.11). | WCAG 1.4.3 / 1.4.11 | S4 | CONSEIL | Primaire : texte #FFF2CC ou fond #B0350F, ce qui donne ≥ 4,6:1. |
| A-10 | Eau profonde : luminance (`DEEP_TINT` à 0,62-0,82) avec rive tracée. Elle ne dépend pas de la teinte (bien), mais le contraste avec le sol n'est que **1,34 à 1,49:1** (ΔE ≈ 9-10, estimé). L'eau profonde bloque : c'est une information de jeu. | WCAG 1.4.11 (3:1 pour un élément d'information) | S3 | CONSEIL | Rive de **3 px** claire (≥ 3:1 contre l'eau) + écume animée lente. Mesure réelle : NON ÉVALUÉ (capture à faire). |
| A-11 | **Haptique** : la bascule « Vibrations » existe sur mobile, mais **aucun appel** à `Input.vibrate_handheld` ni à `Input.start_joy_vibration`. La manette ne vibre jamais. | GAG « multi-canal » ; règle maison « jamais un seul canal » | S2 | BLOQUANT | Table de vibrations (§3.4), réglage commun mobile et manette, avec curseur d'intensité 0-100 %. |
| A-12 | **Sous-titres et indicateurs sonores** : aucun système (normal, il n'y a pas de dialogue parlé). Aucun indicateur visuel de **menace hors écran** non plus (grep : rien dans le HUD), alors que le son porte des informations : tonnerre, sorts de boss, élites. Pas d'option **mono**. Volumes séparés ×5 : conforme. | GAG « visual cues for important sounds », « mono » ; XAG 104 | S3 | CONSEIL | Flèches de bord d'écran pour les boss, mini-boss et élites hors champ, et pour les télégraphes qui débordent de l'écran (≤ 6 flèches, 48 px). Bascule « Audio mono » (AudioServer : bus Master en mono). Si des voix arrivent : sous-titres activés par défaut, 32 px, fond à 60 %. |
| A-13 | Pause : pause au pad (Start) et au clavier (Échap, P), pause automatique à la perte du focus. Appui long de 0,3 s par défaut sur mobile. L'option « auto-cast » permet de jouer d'une main. | GAG « pause anywhere » | — | Conforme | — |
| A-14 | Mode clavier-souris : réticule au curseur (`aim_reticle.gd`). Pas d'option de taille ni de couleur du réticule. Pas de réglage de la zone morte ni de la sensibilité du stick droit (la zone morte de visée est fixée à 0,25). | GAG « sensitivity » ; XAG 107 | S4 | CONSEIL | Ajouter les réglages « Zone morte des sticks » (0,10-0,35) et « Taille du réticule » (100 / 150 %). |

---

## 3. Recommandations chiffrées (détail)

### 3.1 Remappage (E-01, E-02, E-10)

**Données et stockage :**
- `InputSetup` charge ses liaisons par défaut, puis applique les surcharges de `GameSettings` : section `[input]`, clé `<action>.<kbm|pad>.<n>`, valeur = événement sérialisé.
- Règles d'enregistrement : jamais en headless ; `settings.cfg` n'est écrit que par le jeu.

**Écran « Commandes » :**
- Dans chaque onglet, chaque ligne a 2 emplacements : « Principal » et « Secondaire ».
- Fonctionnement d'une ligne :
  - un appui la met en écoute pendant 5 s ;
  - Échap ou Start annule l'écoute ;
  - en cas de conflit, la touche est échangée avec l'action qui l'utilisait.
- Bouton « Par défaut », ligne par ligne et global.
- Actions verrouillées : `pause` (Échap / Start toujours actifs) et la navigation dans les menus.

**Tactile :**
- Réglage « Disposition » : Droitier / Gaucher (miroir horizontal de la grappe et du joystick).
- Réglage « Taille des boutons » : 100 / 115 / 130 %.

### 3.2 Palette daltonienne et redondance de forme (A-01 à A-06)

**Palettes par mode** (`GameSettings.colorblind()` → `HpBarStyle.status_color`, `EnemyAura`, `DamageNumbers.ELEMENT_COLORS`, `ItemBar.QUALITY_COLORS`) :

| Mode | Brûlure | Poison | Gel |
|---|---|---|---|
| Aucun | inchangé | inchangé | inchangé |
| Deutéranopie / protanopie | #F07A2A | **#B07CE8** (violet) | #9CC3D2 |
| Tritanopie | **#E8433A** | #8DAA3C | **#E8E8F0** |

- Chaque mode doit être revalidé avec `cvd.py` : objectif **ΔE2000 ≥ 20** entre statuts dans le mode visé.
- Télégraphe en protanopie : bord **#FF7A1A** (orange) en plus du double liseré du point A-04.

**La forme d'abord, quel que soit le mode :**
- pictogramme de statut ;
- motif d'aura ;
- « − » sur les dégâts subis ;
- forme du cadre de rareté.

### 3.3 Flashs, secousses, mouvements (A-07)

**Nouvelles clés :**

| Clé | Valeurs | Défaut |
|---|---|---|
| `graphics/flashes` | 0 / 1 / 2 | 2 |
| `gameplay/shake` | 0.0 à 1.0 | 1.0 |
| `gameplay/reduce_motion` | vrai / faux | faux |

**Raccordements :**
- `Main.shake()` multiplie l'amplitude par `shake`.
- `LightRig.flash()` multiplie l'énergie par `Quality.flash_mult()`.
- `HurtFeedback` est plafonnée à une opacité de 0,25 au niveau 1 et devient un contour fixe au niveau 0.
- Au premier lancement, proposer « Réduire flashs et secousses ? » sur l'écran d'avertissement de photosensibilité (titre).

### 3.4 Haptique (A-11)

Une seule fonction `Haptics.pulse(kind)`. Elle n'agit que si `GameSettings.haptics()` est vrai. L'intensité est multipliée par le curseur d'intensité. Sur mobile, `vibrate_handheld(ms, amplitude)` ; à la manette, `start_joy_vibration(device, faible, fort, s)`.

| Événement | Mobile (ms / amp.) | Manette (faible / fort / s) |
|---|---|---|
| Dégât subi | 30 / 0,5 | 0,3 / 0,2 / 0,12 |
| Gros dégât (≥ 15 % des PV) | 60 / 0,9 | 0,5 / 0,7 / 0,2 |
| Roulade | 15 / 0,3 | 0,2 / 0 / 0,06 |
| Montée de niveau, coffre légendaire | 2 × 40 / 0,7 | 0,4 / 0,4 / 0,25 |
| Télégraphe de boss lancé | 25 / 0,4 | 0 / 0,3 / 0,1 |

Limites : au plus 1 impulsion toutes les 80 ms ; jamais en continu.

### 3.5 Texte et cibles (A-08, E-06)

**Texte :**
- Plancher de 18 px pour tout `Label` du HUD.
- Réglage `gameplay/ui_scale` (1,0 / 1,25 / 1,5), multiplié au facteur `s` du HUD et aux tailles du thème.

**Cibles tactiles :**

| Élément | Taille | En mm (≈) |
|---|---|---|
| Sorts | 150 px | 9,0 |
| Roulade | 176 px | 10,6 |
| Pause (zone de frappe) | 140 px | 8,4 |
| Interagir | 400 × 150 px | — |

- Écart minimal entre deux cibles : 40 px.
- Ces tailles sont multipliées par le réglage « Taille des boutons ».

---

## 4. Plan d'implémentation priorisé (lots indépendants)

| Lot | Priorité | Contenu | Fichiers | Dépendances |
|---|---|---|---|---|
| **L1 — Honnêteté des réglages + daltonisme** | P0 | A-01, A-02, A-03, A-05 : palettes par mode, pictogramme de 16 px sur la barre des monstres de base, motif des auras, « − » et contour des dégâts subis, plancher de 20 px pour les chiffres | `ui/hp_bar_style.gd`, `fx/enemy_health_bars.gd`, `enemies/enemy_aura.gd`, `enemies/miniboss_brain.gd`, `fx/damage_numbers.gd`, `ui/item_bar.gd`, `ui/game_settings.gd` | Aucune. Brief Codex : cadres de rareté différenciés par la forme (64 et 128 px). |
| **L2 — Télégraphes lisibles** | P0 | A-04 : double liseré, anneau de progression, remplissage à 0,28, réglage « Télégraphes renforcés » ; A-10 : rive de l'eau | `enemies/enemy_telegraph.gd`, cerveaux de boss qui changent `telegraph.modulate`, `ambiance/ambiance_water.gd` (rive), `stage` (`_build_water_banks`) | Aucune. Validation : captures + `cvd.py`. |
| **L3 — Flashs, secousses, mouvements** | P0 | A-07 : 3 réglages, une seule source de vérité, `LightRig.flash`, `HurtFeedback`, `chest_ui`, plafond de 3 flashs par seconde | `ambiance/light_rig.gd`, `ambiance/quality.gd`, `fx/hurt_feedback.gd`, `game/main.gd` (shake), `ui/chest/chest_ui.gd`, `ui/game_settings.gd`, `ui/settings_panel.gd` | Fichiers `core` et `main` réservés à l'orchestrateur. |
| **L4 — Intégration mobile au système** | P0 | E-03 (Retour Android → pause, `quit_on_go_back`), E-04 (SafeArea racine du HUD, recalcul à la rotation), E-05 (correction du dessin du joystick et textures livrées), E-06 (cibles de 150 px, zones de frappe) | `project.godot`, `core/platform.gd`, `ui/hud.gd`, `ui/floating_joystick.gd`, `ui/pause_button.gd`, `ui/spell_button.gd`, `ui/interact_button.gd`, `ui/theme/safe_area.gd` | `project.godot` et `platform.gd` réservés à l'orchestrateur. Test sur appareil. |
| **L5 — Remappage** | P1 | E-01, E-02, E-10 : surcharges `[input]`, écran Commandes interactif, clic molette seul, libellés de la rangée des chiffres, `controls_help()` généré à partir des liaisons, disposition tactile Gaucher | `core/input_setup.gd`, `core/platform.gd`, `ui/controls_panel.gd`, `ui/game_settings.gd`, `ui/hud.gd` (miroir) | Contrat nouveau (`InputSetup.rebind/reset`) à ajouter dans CONTRACTS.md. |
| **L6 — Manette complète** | P1 | E-09 (famille de manette et icônes positionnelles, LT/RT), E-11 (débranchement → pause), E-12 (focus repris au changement de mode dans tous les écrans modaux), E-14 (Objets au pad), E-15 (barre d'aide des menus) | `core/platform.gd`, `ui/key_prompt.gd`, `ui/theme/ui_theme.gd`, `ui/pause_menu.gd`, `ui/end_run_screen.gd`, `ui/chest/chest_ui.gd`, `ui/settings_panel.gd`, `ui/hud.gd` | Brief Codex : icônes PS (✕○□△) et Nintendo, 64 px, états normal et pressé. |
| **L7 — Haptique** | P1 | A-11 : autoload ou classe `Haptics`, branchée sur `Events` (player_damaged, level, chest_opened, boss telegraph), intensité réglable | nouveau `scripts/fx/haptics.gd`, `ui/game_settings.gd`, `ui/settings_panel.gd` (afficher aussi sur PC si une manette est branchée) | `Events` existant ; aucun autre. |
| **L8 — Taille de l'interface et texte** | P1 | A-08 (plancher de 18 px, `ui_scale`), A-09 (bouton primaire) | `ui/hud.gd`, `ui/theme/ui_theme.gd`, `ui/game_settings.gd`, `ui/settings_panel.gd` | À coordonner avec l'audit HUD (même fichier). |
| **L9 — Indices sonores visuels et confort** | P2 | A-12 (flèches hors écran, audio mono), A-14 (zone morte, taille du réticule), E-07 (Interagir rapproché), E-08 (appui long de 0,6 s), E-16 | `ui/hud.gd` (indicateurs), `audio/audio_manager.gd` (mono), `core/input_setup.gd` (zone morte), `ui/aim_reticle.gd`, `ui/spell_button.gd` | Aucune. |

**Ordre conseillé :**
- L1, L2, L3 et L4 en parallèle : leurs périmètres sont disjoints, sauf `game_settings.gd` et `settings_panel.gd`. Pour ces deux fichiers, désigner **un seul lot propriétaire** (L3), qui ajoute toutes les clés.
- Puis L5 à L8.
- Puis L9.

**Captures à faire avant de clore** (scène temporaire `game/tests/_tmp_ux_input_*`, quand la machine est libre) :
1. joystick en tactile simulé (E-05) ;
2. HUD en clavier-souris et à la manette, invites comprises (E-09, E-10, E-15) ;
3. focus au pad dans la pause, les réglages et la fin de run, après une ouverture au doigt (E-12, E-13) ;
4. statuts sur des monstres de base et des élites, puis `cvd.py` sur les pixels (A-02) ;
5. télégraphes sur les 4 biomes et contraste mesuré (A-04) ;
6. eau profonde (A-10) ;
7. 4:3 et 19,5:9 avec taille de texte (A-08) ;
8. sur appareil Android et iOS : encoche des deux côtés, geste Retour (E-03, E-04).

---

## 5. Sources

- Game Accessibility Guidelines : https://gameaccessibilityguidelines.com/full-list/
- Xbox Accessibility Guidelines (XAG 101 à 117) : https://learn.microsoft.com/en-us/gaming/accessibility/guidelines
- WCAG 2.1 : SC 1.4.1, 1.4.3, 1.4.4, 1.4.11, 2.3.1, 2.4.7, 2.5.5 : https://www.w3.org/TR/WCAG21/
- Machado, Oliveira, Fernandes (2009), « A Physiologically-based Model for Simulation of Color Vision Deficiency », IEEE TVCG 15(6) : https://www.inf.ufrgs.br/~oliveira/pubs_files/CVD_Simulation/CVD_Simulation.html
- Sharma, Wu, Dalal (2005), « The CIEDE2000 Color-Difference Formula » : https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/
- Android : « Handle gesture navigation conflicts » : https://developer.android.com/develop/ui/views/touch-and-input/gestures/gesturenav
- Apple Human Interface Guidelines, « Layout » (safe areas) : https://developer.apple.com/design/human-interface-guidelines/layout
- Godot 4 : `Input.vibrate_handheld`, `Input.start_joy_vibration`, `Input.get_joy_name`, `DisplayServer.get_display_safe_area`, `NOTIFICATION_WM_GO_BACK_REQUEST` : https://docs.godotengine.org/en/stable/classes/class_input.html
- S. Hoober, « How Do Users Really Hold Mobile Devices? » (zones de pouce) : https://www.uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php
