# Rainfall : spécification des menus (v1)

> Spec d'implémentation, prête à être découpée en lots parallèles (§7). Design seulement : aucun code ici.
> Sources : `CLAUDE.md` (décisions plateformes), `game/CONTRACTS.md`, `docs/GDD.md` §3-§4, `docs/Direction_Lumiere_Ambiance.md`.
> Existant réutilisé : `scripts/ui/pause_menu.gd`, `run_screens.gd`, `game_settings.gd`, `hud.gd`, `scripts/game/main.gd` (stub `build_save_data` / `_on_save_quit`, `SAVE_PATH = user://run_save.json`), autoloads `Platform`, `Audio`, `Quality`, `RunState`.
> Quand le GDD est muet, la ligne est marquée **[décision de design]** : elle est tranchée, pas ouverte.

---

## 0. Décisions de cadrage

| Sujet | Décision |
|---|---|
| Scène principale | Nouvelle racine `res://scenes/app.tscn` (`App`) qui héberge soit l'écran titre, soit la scène de jeu `scenes/main.tscn` instanciée en enfant. `project.godot : run/main_scene` passe à `app.tscn` (orchestrateur). `main.gd` reste la scène de run et émet déjà `restart_requested` / `run_ended` quand elle n'est pas `current_scene` : `App` s'y branche. |
| Choix de la carte | **Aucun** : les 3 cartes tournent dans l'ordre seedé (GDD §2, `StageManager.map_order`). **[décision de design]** |
| Variantes de sorts | Pas d'écran de variantes en v1 (une seule variante existe par slot). L'écran « Nouvelle run » réserve la zone « Kit » qui affichera les variantes plus tard. **[décision de design]** |
| Personnages | `data/characters.json` (8 entrées du GDD §5 : ardent, rictus, tocsin, averse, arpenteuse, rainette, avare, bourbe ; ancien roster Veilleuse/Brise-Os/Chronomancienne/Invocateur/Faux-Roi retiré le 22/10/2026). Seul `ardent` était jouable en v1 ; les 7 autres sont affichés **verrouillés** (« Bientôt », objectif en gris). Pas de raccourci rubis tant qu'un seul perso est jouable. **[décision de design]** |
| Méta-progression | Écran **Progression** : total de rubis, modes débloqués, 8 cartes de personnages avec objectif. Pas de Boutique ni de Personnalisations ni de Défi du jour en v1 (GDD mois 4+) : aucun bouton grisé, ils n'existent pas. **[décision de design]** |
| Modes | Facile toujours ouvert ; Moyen ouvert dès le départ aussi (mode de référence, GDD) ; **Difficile** débloqué en terminant Moyen (victoire étage 3). Profil persistant. **[décision de design]** |
| Langue | Français uniquement, textes en dur dans le code (pas de sélecteur). **[décision de design]** |
| Sauvegarde de run | Un emplacement, `user://run_save.json`, écriture atomique (`.tmp` puis `DirAccess.rename`), `version` + empreinte `sha256` du payload. Autosave : pause, arrière-plan, toutes les 15 s, à chaque item choisi (GDD §4). Incompatible ou corrompue : convertie en rubis (`Balance.run_rubies(..., victory=false)`) avec message au titre. |
| Profil | `user://profile.json` (rubis, modes/personnages débloqués, stats : runs, victoires, meilleur temps par mode). Jamais dans `settings.cfg`. |
| Réglages | Un **seul** panneau `SettingsPanel` réutilisé par le titre et la pause ; persistance inchangée : `user://settings.cfg` (sections `audio` par `Audio`, `graphics` et `gameplay` par `GameSettings`) ; `Quality` garde `user://quality.cfg` pour sa calibration auto. |
| Pause | Le menu pause existant est conservé ; « Sauvegarder et quitter » **revient au titre** (ne ferme plus l'app) ; « Quitter le jeu » (hors iOS) sauvegarde puis ferme. |
| Fin de run | Écran de fin (victoire/défaite/abandon) restylé, puis **retour au titre** (plus de « Rejouer » qui recharge la scène : « Continuer » → titre, et « Rejouer » relance directement la même config). La sauvegarde est supprimée à la fin de run. |

---

## 1. Parcours

```
Lancement (App)
 └─ Chargement (RunScreens.loading, ≤ 2 images) → ÉCRAN TITRE
      ├─ [Reprendre]  (si run_save valide)  → Chargement → JEU (main.tscn, from_save)
      ├─ [Jouer] / [Nouvelle run]           → NOUVELLE RUN (personnage + mode)
      │      └─ [Commencer] (confirme l'écrasement si une sauvegarde existe) → Chargement → JEU
      ├─ [Progression]                      → PROGRESSION (rubis, déblocages)
      ├─ [Réglages]                         → RÉGLAGES (SettingsPanel plein écran) ─ [Commandes]
      ├─ [Crédits]                          → CRÉDITS (défilement)
      └─ [Quitter] (masqué sur iOS)         → CONFIRMATION → fermeture
JEU
 ├─ Pause (existant) : Reprendre · Réglages (SettingsPanel) · Objets · Commandes ·
 │        Sauvegarder et quitter → TITRE · Abandonner → FIN DE RUN · Quitter le jeu (hors iOS)
 ├─ Étage 3 terminé : Terminer la run / Continuer (sans fin) (existant, restylé)
 └─ Fin de run (victoire / mort / abandon) → RÉCAP → [Continuer] TITRE   |  [Rejouer] JEU (même perso, même mode)
```

Retour arrière universel : `ui_cancel` (Échap, B manette, bouton « Retour » tactile) = écran précédent ; au titre, Échap/B ne fait rien (pas de quitter accidentel).

---

## 2. Règles communes à tous les écrans

### 2.1 Mise en page paysage (PC et téléphone)
- Base logique 1920×1080 `keep_height` : la hauteur est toujours 1080, la largeur visible va de **1920 (16:9)** à **≈ 2400 (20:9 téléphones)**. Tout est ancré ; **aucune position en dur sur x > 1920**.
- **Zone sûre** : `DisplayServer.get_display_safe_area()` converti en coordonnées logiques (diviser par `content_scale_factor` effectif = taille fenêtre / 1080). Marge effective = `max(inset_safe, 48)` à gauche/droite (encoche, caméra perforée), `max(inset_safe, 32)` en haut/bas. Sur PC les insets sont 0 → marges 48 / 32.
- Grille : colonne de gauche (logo, boutons) alignée à `safe_left + 96` ; coins supérieurs pour les compteurs ; bandeau d'invites en bas (hauteur 56) masqué en tactile.
- **Tailles tactiles** : tout contrôle cliquable ≥ **88×88 px** (base 1080) ; boutons principaux 720×120, secondaires 620×104, icônes 96×96, lignes de réglage 88 de haut, curseurs avec poignée 64 px. Espacement vertical ≥ 16 px.
- Réduction : facteur `s = clamp(min(vp.x, vp.y) / 1080, 0.55, 1.0)` comme dans `pause_menu.gd`, uniquement pour les fenêtres PC redimensionnées très petites ; sur mobile `s = 1`.
- Textes : titres 64 px, boutons 44 px, corps 32 px, légendes 26 px ; toujours `outline 6-8 px #1a1620` sur fond animé (L\* UI 95, règle Direction §1.1).

### 2.2 Navigation
| Mode (`Platform.input_mode`) | Comportement |
|---|---|
| Tactile | Aucun focus visible ; boutons « Retour » explicites en bas à gauche de chaque sous-écran ; les invites `[E]/[A]` sont vides ; vibration courte à l'appui si `GameSettings.haptics()` (mobile). |
| Clavier/souris | Focus initial sur le bouton principal (`grab_focus.call_deferred`) ; flèches/Tab/ZQSD ne déplacent **pas** (les actions `move_*` n'ont pas d'effet en menu) : `ui_up/down/left/right` seulement ; `ui_accept` (Entrée/Espace) valide ; `ui_cancel` (Échap) retour ; la souris change le focus au survol. |
| Manette | `ui_*` (croix + stick gauche par défaut Godot) ; A valide ; B retour ; Start = valider le bouton principal sur le titre. `focus_neighbor_*` renseignés explicitement sur chaque écran (pas de saut vers un bouton masqué). |
| Changement de mode en direct | Signal `Platform.input_mode_changed` : les invites se mettent à jour, le focus est rendu/retiré ; aucun relayout. |

Un bouton désactivé (`disabled = true`) est ignoré par le focus et affiché à 45 % d'opacité avec son libellé explicatif en dessous (ex. « Aucune run sauvegardée »).

### 2.3 Sons UI (ids existants dans `data/audio/sounds.json` / `assets/audio/ui`)
| Événement | Appel |
|---|---|
| Changement de focus / survol | `Audio.play_ui(&"ui.hover")` |
| Appui bouton | `Audio.play_ui(&"ui.click")` |
| Retour / annuler | `Audio.play_ui(&"ui.click", -6.0, 0.85)` |
| Validation importante (Commencer, Reprendre) | `Audio.play_ui(&"ui.item_pick")` |
| Ouverture d'un écran | `Audio.play_ui(&"ui.hover", -4.0, 1.15)` |
| Compteur de rubis qui monte (récap) | `Audio.play_ui(&"pickup.ruby")` toutes les 90 ms (max 12 tics) |
| Victoire (récap) | `Audio.play_ui(&"ui.level_up")` |
| Verrouillé (clic sur un perso/mode fermé) | `Audio.play_ui(&"ui.click", -8.0, 0.7)` |
Musique : stem `music.menu` (fichier existant `assets/audio/music/music_menu_01.ogg`) via `Audio.start_map("menu")` ; l'entrée `maps.menu` de `sounds.json` est à ajouter (§7, lot C). Entrée en jeu : `Audio.start_map(<carte>)` fait fondre `music.menu` (4 s, comportement de `AudioDirector.start_map`).

### 2.4 Transitions
- Entre écrans de menu : fondu noir 0,18 s sortie + 0,18 s entrée (un `ColorRect` plein écran sous `App`, layer 200, `process_mode ALWAYS`), **jamais** de slide (coûteux et illisible sur fond animé).
- Menu → jeu : fondu noir 0,35 s, puis `RunScreens.loading()` (existant) pendant la préchauffe, puis fondu 0,5 s à l'ouverture de l'étage.
- Jeu → titre : fondu noir 0,35 s, libération de `main.tscn`, instanciation du titre, fondu 0,5 s.
- Sous-panneaux d'un même écran (Réglages → Commandes) : pas de fondu, simple bascule de visibilité + son d'ouverture.

### 2.5 Placeholders autorisés tant que les assets Codex manquent
`StyleBoxFlat` en code : fond `#2B3340` α 0,86, bord 2 px `#7C8898`, coins 12 px ; bouton principal fond `#C23B12`, texte `#FFE9A8` ; focus = bord 4 px `#FFB347`. Logo = `Label` « RAINFALL » 160 px avec outline. Portraits = première frame `idle_s` de `assets/sprites/characters/<id>/<id>.tres` (Ardent), silhouette grise pour les autres. Tout le code de style passe par `UiTheme` (§7 lot A) : le remplacement par les PNG 9-slice ne touche qu'un fichier.

---

## 3. Écrans

### 3.1 Écran titre (`scenes/menu/title.tscn`)
**But** : lancer ou reprendre une run en un appui, donner accès au reste sans pop-up.

**Éléments et disposition** (coordonnées en base 1080, x relatif à `safe_left` ; la colonne gauche ne bouge pas quand l'écran s'élargit) :
- Fond animé plein écran (§4).
- Logo « Rainfall » : haut-gauche, `x = 96, y = 72`, 640×220 (`assets/sprites/ui/menu/logo_rainfall.png`, placeholder texte).
- Sous-titre version : sous le logo, 26 px, `Version 0.x · Godot 4.7` (lue dans `ProjectSettings application/config/version`).
- Haut-droite (depuis `safe_right`) : compteur **rubis** (icône `ui/hud/icon_ruby.png` 64 px + nombre 40 px, lu dans `Profile.rubies`) ; à sa gauche bouton icône **Réglages** 96×96 (`ui/hud/icon_settings.png`). Rubis non cliquable.
- Colonne de boutons bas-gauche, `x = 96`, premier bouton à `y = 520`, pas de 120 (principal) puis 112 :
  1. **Principal** (720×120) : « Reprendre » si sauvegarde valide, sinon « Jouer ».
     Sous le libellé, en 26 px : « Ardent · Étage 2 · Moyen · 04:12 » (résumé `RunSave.summary()`), ou rien.
  2. « Nouvelle run » (620×104) : affiché **seulement** s'il y a une sauvegarde (sinon « Jouer » y mène déjà).
  3. « Progression »
  4. « Réglages » (doublon volontaire de l'icône : accessible au focus manette)
  5. « Crédits »
  6. « Quitter » : **absent sur iOS** (`Platform.can_quit()`), pas seulement masqué.
- Bandeau d'invites bas (y = 1080 − 32 − 56), centré, 28 px, non tactile : « [Entrée] Valider   [Échap] —   [F11] Plein écran » / manette « [A] Valider  [B] — ». Vide en tactile.
- Message éphémère (toast) haut-centre, 32 px, 4 s : « Sauvegarde incompatible : +N rubis » ou « Run précédente convertie en rubis ».

**États** : `has_save` (true/false) change le bouton principal et affiche « Nouvelle run » ; `Platform.can_quit()` ; `Profile.rubies`.

**Navigation** : focus initial sur le bouton principal ; `focus_neighbor_top/bottom` chaînés dans l'ordre de la colonne, puis l'icône Réglages ; Échap/B : rien ; Start : bouton principal.

**Actions** :
- Reprendre → `App.resume_run()`.
- Jouer / Nouvelle run → écran Nouvelle run (§3.2). Si `has_save`, « Nouvelle run » demande d'abord : titre « Remplacer la run en cours ? », ligne « Ardent · Étage 2 · 04:12 sera perdue (les rubis déjà gagnés sont conservés). », boutons « Remplacer » (destructif, à droite) / « Annuler » (focus par défaut).
- Quitter → dialogue « Quitter Rainfall ? » / « Quitter » / « Annuler » → `Platform.quit_game()`.

**Sons** : §2.3 ; au premier affichage, `Audio.start_map("menu")`.

### 3.2 Nouvelle run (`scenes/menu/new_run.tscn`)
**But** : choisir personnage et mode, voir le kit, partir.

**Disposition** :
- Titre « Nouvelle run » haut-gauche (64 px, `x = 96, y = 48`).
- **Rangée de portraits** (6 cartes 240×320, espacement 24, centrées horizontalement, `y = 160`) : cadre de rareté réutilisé (`icons/frame_commun.png` placeholder) + portrait (`assets/sprites/ui/portraits/<id>.png`, 240×320) + nom (32 px). Verrouillé : portrait désaturé à 40 %, cadenas 64 px (`ui/menu/icon_lock.png`), nom gris. Sélectionnée : bord `#FFB347` 4 px + léger scale 1,05 (tween 0,12 s).
  Sur téléphone 20:9 la rangée reste centrée (2400 de large : marges plus grandes) ; sur 16:9 elle occupe 6×240 + 5×24 = 1560 px.
- **Fiche** sous la rangée (`y = 520`, largeur = largeur des portraits) : à gauche (560 px) aperçu animé `idle_s` du personnage à l'échelle ×2 (384 px) sur un disque sombre ; à droite : nom 48 px, style (« Zone, débutant »), config (« 4 sorts »), puis **Kit** : 4 lignes 88 px : icône de sort 64 px (`assets/sprites/icons/spells/<spell_id>.png`) + nom + rôle (« Auto », « Recharge », « Ultime »). Verrouillé : la fiche affiche l'objectif (« Atteindre le niveau 12 en une run ») ou « Objectif caché » et « Bientôt disponible ».
- **Mode** : trois boutons segmentés 300×96, `y = 880`, alignés à gauche de la fiche : « Facile » « Moyen » « Difficile ». Sous chacun, 26 px : « Scaling ×0,7 · rubis ×0,8 » / « ×1,0 · ×1 » / « ×1,5 · ×1,3 ». Difficile verrouillé tant que `Profile.unlocked_modes` ne le contient pas : cadenas + « Terminez une run en Moyen ». Mode par défaut = dernier mode joué (`Profile.last_mode`), sinon Moyen.
- Bas-droite : **« Commencer »** principal 720×120 (`x = safe_right − 96 − 720, y = 920`). Bas-gauche : « Retour » 300×96.

**Navigation** : focus initial sur le portrait sélectionné (dernier joué, sinon Ardent) ; gauche/droite entre portraits ; bas → modes ; bas → Commencer ; Retour accessible par gauche depuis Facile. Échap/B → titre. Un portrait verrouillé est focusable (pour lire l'objectif) mais « Commencer » est désactivé avec libellé « Personnage verrouillé ».

**Action Commencer** : `App.start_run({character: &"ardent", mode: &"moyen"})` ; `Profile.last_mode` et `last_character` mis à jour ; sauvegarde existante supprimée (la confirmation a eu lieu au titre).

**Données** : `data/characters.json` : `[{"id","name","style","config","spells":[{"id","name","slot":"auto|cd|ultime"}],"unlocked":bool,"unlock_text","hidden":bool,"playable":bool,"scene":"res://scenes/player/player.tscn"}]`. v1 : Ardent `playable=true`, les 5 autres `playable=false` (scène absente).

**MISE À JOUR (demande du joueur, 21/10/2026, prioritaire sur ce qui précède)** : écran de **sélection du personnage** au démarrage d'une partie.
- **Au clic / appui / validation sur un portrait, sa FICHE apparaît** (panneau qui glisse/fond, 0,18 s) et **explique chaque sort** : icône 96 px, nom, rôle (Auto / Recharge / Ultime), description en une ou deux phrases, et chiffres clés (dégâts, recharge, portée) lus dans les données des sorts (`SpellData` / `data/spells*.json`, rg pour trouver la source ; ne rien inventer : si un chiffre manque, ne pas l'afficher).
- **Sorts alternatifs** : pour chaque emplacement, afficher à côté du sort de base les **variantes** prévues (GDD §5 et Items/Spells : rg -n "variante|alternatif|déblo" docs/) en petites icônes 72 px. Variante **non débloquée = grisée** (désaturée + cadenas). **Au survol (souris) / focus (manette, clavier) / appui long (tactile)**, une infobulle affiche la **quête de déblocage** (« Tuer 500 monstres avec Éclat », etc.) ; si débloquée : sa description. Sélection de variante pour la run si débloquée (sinon le sort de base) ; `start_requested` porte alors `{character, mode, spells: {slot: spell_id}}`.
- Persistance des déblocages de variantes : `Profile.unlocked_spells` (lot B fournit l'API `Profile.is_unlocked(&"spell:<id>")` ; en attendant, tout est verrouillé sauf les sorts de base).
- Données : `data/characters.json` gagne `spells[].variants: [{"id","name","desc","unlock_text","unlock_key"}]` (rempli depuis les docs ; si le GDD n'en définit pas pour un perso, liste vide).
- Les icônes des variantes manquantes : placeholder (icône du sort de base désaturée) + entrée dans la liste d'assets §7 pour Codex.

### 3.3 Progression (`scenes/menu/progress.tscn`)
**But** : montrer la méta-progression (rubis, modes, personnages) sans boutique.
- Titre « Progression ». Haut-droite : gros compteur rubis (icône 96 + nombre 64 px).
- Bloc **Modes** (gauche, 3 lignes 88 px) : nom, état « Débloqué » / « Terminez Moyen », meilleur temps actif (`mm:ss`) et nombre de victoires.
- Bloc **Personnages** (droite) : grille 4×2 de cartes 300×200 : portrait 128, nom, barre d'objectif (`ProgressBar` 24 px, valeur `Profile.objective_progress(id)`, v1 = 0 ou 1) ou « Objectif caché ».
- Bloc **Statistiques** (bas, 26 px, une ligne) : « Runs : 12 · Victoires : 3 · Monstres tués : 8 412 · Temps de jeu : 1 h 52 ».
- « Retour » bas-gauche. Échap/B → titre. Rien n'est cliquable à part Retour (focus unique).
- Données : `Profile` (§6.2).

### 3.4 Réglages (`scenes/ui/settings_panel.tscn`, réutilisé en plein écran au titre et dans la pause)
Voir §5 pour le contenu. Mise en page : liste défilante (`ScrollContainer`, molette/stick/doigt) de lignes 88 px, libellé à gauche (36 px, 45 % de largeur), contrôle à droite (55 %) ; largeur du panneau 1200 px centré ; groupes séparés par un sous-titre 40 px (« Audio », « Affichage », « Jeu », « Accessibilité »). Boutons bas : « Commandes » (ouvre §3.5), « Réinitialiser » (confirmation « Rétablir les réglages par défaut ? »), « Retour ». Au titre, le panneau est posé sur le fond animé assombri à 70 % ; en pause, dans le cadre pause existant.
Navigation : focus initial sur le premier curseur ; gauche/droite modifient curseur/option (pas de focus sur les items d'`OptionButton` : utiliser des boutons « ‹ valeur › » 88 px, plus lisibles en tactile et manette). Échap/B → retour.

### 3.5 Commandes (sous-panneau de Réglages, et en pause)
Grille 2 colonnes des lignes `Platform.controls_help()` (existant), avec icônes d'invites (`ui/prompts/*`, via `KeyPrompt`) à la place du texte quand une icône existe. Trois onglets en haut « Clavier · Manette · Tactile » (88 px), onglet initial = mode courant ; l'onglet Tactile n'apparaît que si `Platform.has_touch()`. Pas de remappage en v1 **[décision de design]**. « Retour ».

### 3.6 Crédits (`scenes/menu/credits.tscn`)
Texte défilant (60 px/s, accélérable ×4 en maintenant `ui_accept` / le doigt), colonne centrée 900 px sur le fond animé assombri 60 % : « Rainfall », « Conception et code : <joueur> », « Assets Blender et audio : pipeline Codex », « Moteur : Godot Engine 4.7 (licence MIT) », « Merci d'avoir joué ». « Retour » bas-gauche ; Échap/B ; retour automatique au titre à la fin du défilement + 2 s.

### 3.7 Dialogue de confirmation (composant `ConfirmDialog`, `scripts/ui/theme/confirm_dialog.gd`)
Cadre 900×420 centré sur un voile noir 70 % ; titre 48 px, ligne 32 px, deux boutons 400×104 côte à côte : action neutre à gauche (focus initial), action destructive à droite (style rouge `#C23B12`). Échap/B = neutre. Utilisé par : écrasement de sauvegarde, quitter, abandonner (remplace `_panel_confirm` de la pause), réinitialiser les réglages.

### 3.8 Pause (existant `pause_menu.gd`, modifications)
- Boutons : « Reprendre », « Réglages » (→ `SettingsPanel` incrusté à la place de `_build_settings`), « Objets (N) », « Commandes » (→ sous-panneau §3.5), « Sauvegarder et quitter », « Abandonner » (→ `ConfirmDialog` « Abandonner la run ? » / « Les rubis déjà gagnés sont conservés. » / « Abandonner » / « Annuler »), « Quitter le jeu » (hors iOS : sauvegarde **puis** ferme).
- Sons §2.3 ajoutés (focus, clic). Compte à rebours 3 s inchangé.
- Comportement « Sauvegarder et quitter » : `save_quit_requested` → `main.gd` sauvegarde → `App.return_to_title()` (plus de `quit_game`).
- Taille tactile : boutons 620×130 déjà conformes.

### 3.9 Choix de fin d'étage 3 (existant `RunScreens.dialog`, restylé)
Même contenu (« Étage 3 terminé », « Terminer la run » / « Continuer (sans fin) ») dans le cadre `UiTheme` ; focus sur « Terminer la run ». Pas de retour arrière possible (pas d'Échap).

### 3.10 Récap de fin de run (`scenes/ui/end_run.tscn`, remplace l'`end_screen` de `main.gd`)
**But** : récompenser, informer, renvoyer au titre.
- Voile noir 85 % (la carte reste visible derrière, figée, pluie en pause).
- Titre 72 px : « Victoire ! » (victoire, teinte `#FFE9A8`) / « Vous êtes tombé » (mort, `#7C8898`) / « Run abandonnée ».
- Ligne 40 px : « Ardent · Moyen · Étage 3 · 10:42 · niveau 18 ».
- Quatre tuiles 280×160 en ligne : « Piliers 7 », « Monstres 1 204 », « Objets 27 », « Or restant 980 » (`RunState` + compteurs de `main.gd` : `pillars_done`, kills via `Events.enemy_killed`, `RunState.items` somme des stacks, `RunState.gold`).
- Ligne **Rubis** 56 px : icône 64 + compteur animé de 0 à `last_rubies` sur 1,2 s (son §2.3) + « (×1,3 Difficile) » si mode ≠ moyen.
- Ligne déblocage (si `Profile` a changé) : « Mode Difficile débloqué ! » en `#FFB347`.
- Boutons : « Continuer » principal (→ titre) à droite, « Rejouer » (même perso, même mode) à gauche. Focus : Continuer. Pas d'Échap avant la fin de l'animation (1,2 s), ensuite Échap = Continuer.
- `main.gd` : à `end_run`, supprime la sauvegarde (`RunSave.delete()`), crédite `Profile.add_run_result(...)`, puis affiche ce récap. `restart_requested` / nouveau signal `title_requested` remontent à `App`.

### 3.11 Chargement
`RunScreens.loading()` existant (fond `#050810`), avec en plus : logo centré 480 px, ligne « Chargement… » puis, après 1,5 s, une astuce aléatoire 32 px tirée de `data/tips.json` (12 lignes, ex. « Le téléporteur ne s'active que par l'action Interagir : on peut rester farmer. »). Pas de barre de progression (préchauffe bloquante de 2 images).

---

## 4. Ambiance visuelle des menus (cohérente avec `Direction_Lumiere_Ambiance.md`)

- **Fond = la vraie carte du jeu**, pas une image : `scenes/menu/menu_background.tscn` instancie `scenes/stage/maps/<id>.tscn` + `AmbianceManager` (`auto_bind = false`, `bind_map(map)`, `set_difficulty(0.6, &"Calme")`), sans Director, sans joueur, sans pickups. Pluie, brume, flaques, éclairage et étalonnage de la carte sont ceux du jeu (règles §1-§3 de la Direction).
- **Carte affichée** : celle de la run sauvegardée (`RunSave.summary().map_id`) ; sinon rotation quotidienne `["terrasses_noyees","foret_brume","cite_rouille"][jour_de_l_annee % 3]`. **[décision de design]**
- **Caméra** : `Camera2D` lente, 14 px/s, trajet aller-retour entre 3 points lisibles de la carte (`Marker2D` du groupe `menu_camera` s'ils existent, sinon : centre, centre + (−6 u, −4 u), centre + (5 u, 3 u)), interpolation `ease in-out` 25 s par segment, zoom 1,15 (le décor paraît plus grand, moins « jeu »). Légère dérive verticale ±8 px en sinus 9 s (respiration).
- **Lisibilité de l'UI** : dégradé vertical gauche → droite `#050810` α 0,78 → α 0,15 sur les 1100 premiers px (colonne des boutons), plus vignette (`assets/ambience/vignette_1024.png`, multiply, α 0,35). Le sol reste à L\* ≥ 22, l'UI à L\* 95 (Direction §1.1).
- **Détail vivant** : une `PointLight2D` chaude (`LightRig` preset `&"ember"`, énergie 0,8, rayon 6 u) posée au point « feu de camp » du GDD §3 (Marker2D `menu_campfire`, sinon centre carte + (3 u, 2 u)) avec scintillement 0,9-1,1 à 7 Hz + 12 étincelles/s (`spark_16`, existant) ; en Bas : halo `halo_soft_256` sans lumière.
- **Qualité** : le fond respecte `Quality.tier` ; en Bas, pluie et brume en une seule couche, pas de glow (`Quality.is_cut`). Budget menu : ≤ 3 ms GPU mobile moyen de gamme.
- **Changement de réglage Qualité au titre** : le fond se reconstruit (`AmbianceManager._on_quality` existant), l'écran ne bouge pas.
- **Musique** : `music.menu` (douce, boucle), ambiance `amb.rain.light` à −12 dB, pas de vent. Fondu de 4 s vers la musique de carte au lancement.
- **Au récap de fin de run**, la pluie reste visible derrière le voile : aucune scène de fond supplémentaire.

---

## 5. Réglages : contenu, valeurs, persistance

| Groupe | Libellé FR | Contrôle | Valeurs | Appel / persistance |
|---|---|---|---|---|
| Audio | Volume général | curseur 0-100 % pas 5 | déf. 100 | `Audio.set_volume("master", v)` → `settings.cfg [audio]` (écrit par `Audio`, 0,5 s après la dernière modification) |
| Audio | Musique | curseur | déf. 80 | `Audio.set_volume("music", v)` |
| Audio | Effets | curseur | déf. 100 | `Audio.set_volume("sfx", v)` |
| Audio | Ambiance | curseur | déf. 80 | `Audio.set_volume("ambience", v)` |
| Audio | Interface | curseur | déf. 100 | `Audio.set_volume("ui", v)` ; joue `ui.click` au relâchement |
| Affichage | Qualité | ‹ › | Automatique · Bas · Moyen · Haut | `GameSettings.set_quality(-1..2)` → `[graphics] quality` ; `Quality` gère sa propre calibration dans `user://quality.cfg` |
| Affichage | Plein écran (PC seulement) | interrupteur | déf. fenêtré | `DisplayServer.window_set_mode` → `[graphics] fullscreen` (nouvelle clé, `GameSettings`) |
| Affichage | Afficher les FPS | interrupteur | déf. off | `[graphics] show_fps` ; le HUD lit `GameSettings.show_fps()` |
| Jeu | Sorts automatiques | interrupteur | déf. off | `GameSettings.set_auto_cast(tree, on)` → `[gameplay] auto_cast` |
| Jeu | Vibrations (mobile) | interrupteur | déf. on | `[gameplay] haptics` (nouvelle clé) ; `Input.vibrate_handheld(40)` aux coffres/boss/ultimes via `GameSettings.haptics()` |
| Jeu | Bouton pause : appui long | interrupteur | déf. on (mobile) / off (PC) | `[gameplay] pause_long_press` ; `PauseButton` lit la valeur (0,3 s ou appui simple) |
| Accessibilité | Flashs et secousses | ‹ › | Aucun · Réduits · Complets | `GameSettings.set_flashes(0..2)` → `[graphics] flashes` (Direction §7.5) |
| Accessibilité | Taille des chiffres de dégâts | ‹ › | Petits · Normaux · Grands | `[gameplay] damage_text_scale` 0,8 / 1 / 1,3 ; `DamageNumbers` lit `GameSettings.damage_text_scale()` |
| Accessibilité | Mode daltonien | ‹ › | Aucun · Deutéranopie · Protanopie · Tritanopie | `[graphics] colorblind` ; v1 : seule la jauge de difficulté et les cadres de rareté ajoutent un motif/une icône (pas de shader) **[décision de design]** |

- « Réinitialiser » : efface les sections `graphics` et `gameplay`, remet les volumes par défaut (`Audio.DEFAULT_VOLUMES`), puis relit.
- Headless / `--write-movie` : `GameSettings.set_value` et `Audio` n'écrivent rien (comportement existant à conserver).
- Le panneau ne stocke rien lui-même : il lit à l'ouverture (`_sync`), écrit à chaque changement, et se resynchronise sur `Audio.volumes_changed` et `Quality.quality_changed`.

---

## 6. Données persistantes

### 6.1 Sauvegarde de run : `user://run_save.json` (lot B, `RunSave`)
```
{ "version": 2, "hash": "<sha256 du champ data sérialisé>", "saved_at": <unix>,
  "data": { "character": "ardent", "mode": "moyen", "seed": int, "rng_state": int,
            "run": {stage, active_time_s, gold, xp, level, items{id:n}, pity, kills, pillars_done},
            "stage": StageManager.to_dict(),       // carte, map_order, coffres, piliers, capsules
            "player": {pos:[x,y], hp, cooldowns:[..], statuses:[]},
            "pending_chest": {quality, items:[id,id]} | null } }     // GDD §4 : même choix à la reprise
```
- Écriture : `FileAccess` sur `run_save.json.tmp` puis `DirAccess.rename_absolute`. Lecture : parse, vérification `version == 2` et `hash` ; sinon `RunSave.load()` renvoie `{"ok": false, "reason": "version|corrupt", "rubies": N}` et le titre affiche le toast.
- API : `RunSave.exists() -> bool`, `RunSave.summary() -> Dictionary` (`character, character_name, mode, stage, active_time_s, map_id, saved_at`) sans charger tout, `RunSave.save(data) -> bool`, `RunSave.load() -> Dictionary`, `RunSave.delete()`.
- `main.gd` : `@export var resume_data: Dictionary` ; si non vide, `_build` appelle `stage.from_dict`, restaure `RunState`, le joueur, le coffre en attente, puis `RunState.rng.state`. Autosave : `Timer` 15 s (`process_mode ALWAYS`, ignoré si `get_tree().paused` sauf pause-menu), `Events.item_chosen`, `NOTIFICATION_APPLICATION_PAUSED/FOCUS_OUT`, « Sauvegarder et quitter ». Monstres vivants **non** sauvegardés en v1 (recréés par le Director) **[décision de design]**.

### 6.2 Profil : `user://profile.json` (lot B, autoload `Profile`)
`{ "version": 1, "rubies": int, "unlocked_modes": ["facile","moyen"], "unlocked_characters": ["ardent"], "last_mode": "moyen", "last_character": "ardent", "stats": {runs, victories, kills, play_time_s, best_time_s: {mode: s}}, "objectives": {id: progress} }`
API : `Profile.rubies`, `Profile.add_rubies(n)`, `Profile.is_mode_unlocked(mode)`, `Profile.is_character_unlocked(id)`, `Profile.add_run_result({victory, mode, character, active_time_s, kills, rubies}) -> Array[StringName]` (retourne les déblocages obtenus, ex. `[&"mode:difficile"]`), `Profile.objective_progress(id) -> float`, `Profile.save()` (atomique, immédiate), signal `changed`. Chargé dans `_ready`, jamais écrit en headless.

---

## 7. ASSETS à demander à Codex / Blender

Tous rendus dans Blender (règle absolue), PNG RGBA, `Standard`, filtre linéaire, palette `art/briefs/STYLE.md`. Dossier `game/assets/sprites/ui/menu/` sauf mention. Brief à écrire : `art/briefs/ui_menu.md` (copie des lignes ci-dessous). Les 9-slice existants (`button_normal/pressed/primary.png`, marges 24) sont **réutilisés** pour les boutons.

| Fichier | Taille | Usage | Notes |
|---|---|---|---|
| `logo_rainfall.png` (+ `_e.png`) | 1280×440 (affiché 640×220) | titre, chargement | lettrage « RAINFALL » en métal patiné bleu-gris `#5E7390`, gouttes qui perlent, braise `#FF7A1F` dans le A ; masque d'émission pour le glow HDR |
| `panel_9slice.png` | 192×192, marges 32 | cadres des panneaux (réglages, dialogues, récap) | pierre/métal sombre `#2B3340`, rivets dans les coins, intérieur uni α 0,86 |
| `panel_dark_9slice.png` | 192×192, marges 32 | fiche personnage, tuiles du récap | plus sombre `#1a1620` α 0,9 |
| `button_icon.png` / `button_icon_pressed.png` | 128×128 | boutons icônes (réglages, onglets) | rond métal, même famille que `button_normal` |
| `tab_active.png` / `tab_inactive.png` | 256×96, marges 24 | onglets Commandes, modes | |
| `slider_track.png` / `slider_fill.png` / `slider_grab.png` | 512×24 ; 512×24 ; 64×64 | curseurs de volume | rail de pierre, remplissage braise, poignée goutte d'eau |
| `toggle_on.png` / `toggle_off.png` | 160×88 | interrupteurs | lanterne allumée / éteinte |
| `arrow_left.png` / `arrow_right.png` | 88×88 | sélecteurs ‹ › | |
| `icon_lock.png` | 96×96 | personnage / mode verrouillé | cadenas de fer rouillé |
| `icon_check.png` | 64×64 | mode débloqué | |
| `focus_frame_9slice.png` | 96×96, marges 20 | cadre de focus clavier/manette | liseré `#FFB347` lumineux, intérieur transparent |
| `icon_mode_facile.png` / `_moyen.png` / `_difficile.png` | 128×128 | boutons de mode | une, deux, trois gouttes/éclairs |
| `divider.png` | 1024×16 | séparateurs de groupes | |
| `assets/sprites/ui/portraits/<id>.png` ×8 | 480×640 (affiché 240×320) | cartes de personnage | buste 3/4, éclairage haut-gauche, fond transparent ; `ardent` d'abord, puis `rictus`, `tocsin`, `averse`, `arpenteuse`, `rainette`, `avare`, `bourbe` (silhouettes grises acceptées pour les verrouillés en v1) |
| `assets/sprites/ui/portraits/<id>_silhouette.png` ×5 | 480×640 | verrouillés | silhouette unie `#4A5565` |
| `assets/sprites/ui/menu/stat_pillar.png`, `stat_kills.png`, `stat_items.png`, `stat_gold.png` | 96×96 | tuiles du récap | pilier, crâne, sac, pièce |
| `assets/sprites/ui/menu/ruby_large.png` | 128×128 | compteur de rubis (titre, récap) | variante grande de `icon_ruby` |
| `assets/audio/ui/ui_back_01..03.ogg` (id `ui.back`) | — | retour | optionnel ; en attendant `ui.click` pitché |
| `assets/audio/music/music_menu_01.ogg` | existe | musique du titre | rien à produire |

Placeholders autorisés jusqu'à livraison : §2.5 (StyleBox en code dans `UiTheme`, aucune image dessinée en code ni en PIL).

---

## 8. Lots d'implémentation (indépendants, sans chevauchement de fichiers)

Convention : chaque lot livre ses fichiers + un test headless `tests/<lot>_test.tscn` (sortie `RESULT: OK`) + une scène de capture `tests/capture_<lot>.tscn` (`godot --path game --write-movie <dossier>/<lot>.png --fixed-fps 30 res://tests/capture_<lot>.tscn`, PC puis `-- --mobile`). Les lots codent contre les API ci-dessous ; l'orchestrateur pose les **stubs** (§8.0) avant de lancer les agents pour que tout parse.

### 8.0 Orchestrateur (fichiers partagés) : liste exacte
1. `project.godot` : `run/main_scene = "res://scenes/app.tscn"` ; autoload `Profile="*res://scripts/save/profile.gd"` (après `Platform`) ; `application/config/version = "0.1.0"`.
2. `scenes/main.tscn` : inchangé (le script `main.gd` est attribué au lot B).
3. `scripts/core/events.gd` : ajouter `signal item_chosen(item_id: StringName)` s'il manque (CONTRACTS le liste déjà) et `signal run_saved`.
4. `scripts/core/run_state.gd` : ajouter `var character: StringName = &"ardent"`, `var kills := 0` (incrémenté sur `Events.enemy_killed` dans `_ready`), `func to_dict() -> Dictionary` / `func from_dict(d)` (mode, stage, active_time_s, gold, xp, level, items, pity, kills, character, seed, `rng.state`).
5. `scripts/core/platform.gd` : `func safe_margins() -> Dictionary` (`{left, top, right, bottom}` en px logiques, planchers 48/32, cf. §2.1).
6. Stubs avant lancement (fichiers vides avec signatures, écrasés par les lots) : `scripts/ui/theme/ui_theme.gd` (lot A), `scripts/save/run_save.gd` et `scripts/save/profile.gd` (lot B), `scripts/app/app.gd` (lot F).
7. Intégration finale : lancer les tests de chaque lot, puis `tests/menu_flow_test.tscn` (lot F) sur la vraie `app.tscn`.

### Lot A : thème et composants UI (Sonnet)
Fichiers : `scripts/ui/theme/ui_theme.gd` (`class_name UiTheme`), `scripts/ui/theme/menu_button.gd` (`class_name MenuBtn extends Button`), `scripts/ui/theme/confirm_dialog.gd` (`class_name ConfirmDialog extends CanvasLayer`), `scripts/ui/theme/option_stepper.gd` (`class_name OptionStepper`, boutons ‹ valeur ›), `scripts/ui/theme/safe_area.gd` (`class_name SafeArea extends MarginContainer`), `scripts/ui/theme/fade_layer.gd` (`class_name FadeLayer`), `tests/ui_theme_test.tscn/.gd`, `tests/capture_ui_theme.tscn/.gd`.
API : `UiTheme.theme() -> Theme` (StyleBox placeholders §2.5, remplacés par les 9-slice §7 s'ils existent via `ResourceLoader.exists`), `UiTheme.apply(root: Control)`, `UiTheme.hook_sounds(root)` (connecte `focus_entered → ui.hover`, `pressed → ui.click` sur tous les `BaseButton` descendants), `UiTheme.primary(btn)`, `UiTheme.destructive(btn)`, `UiTheme.scale() -> float` (§2.1), `MenuBtn.subtitle: String` (class_name `MenuBtn` : `MenuButton` est une classe native Godot), `ConfirmDialog.ask(title, line, neutral_text, destructive_text) -> Signal chosen(destructive: bool)`, `OptionStepper.items`, `.index`, signal `changed(index)`, `SafeArea` (lit `Platform.safe_margins()` et `size_changed`), `FadeLayer.fade_out(0.18) -> Signal`, `fade_in(0.18)`.
Test headless : tous les contrôles ont `custom_minimum_size >= 88` ; `hook_sounds` appelle `Audio.play_ui` (compter via `Audio.last_flush_stats` ou un `set_override`) ; `ConfirmDialog` répond à `ui_cancel` par `chosen(false)`. Capture : galerie des composants (boutons normal/principal/désactivé/focus, stepper, curseur, interrupteur, dialogue) en PC et mobile.

### Lot B : sauvegarde, profil, intégration run (Opus)
Fichiers : `scripts/save/run_save.gd` (`class_name RunSave`, statique), `scripts/save/profile.gd` (autoload `Profile`), `scripts/game/main.gd` (reprise, autosave, fin de run → `Profile`, signaux `title_requested`, `replay_requested`), `scripts/ui/end_run_screen.gd` + `scenes/ui/end_run.tscn` (§3.10, utilise `UiTheme`), `data/tips.json`, `tests/save_test.tscn/.gd`, `tests/end_run_test.tscn/.gd`, `tests/capture_end_run.tscn/.gd`.
Test headless : sauvegarder une run jouée 3 s avec 2 items et un coffre en attente → `exists()`, `summary()` corrects → recharger `main.tscn` avec `resume_data` → même étage, même `map_order`, mêmes items, même `rng.state`, même coffre en attente ; fichier corrompu → `ok=false, reason="corrupt", rubies>0` ; `.tmp` jamais laissé ; `Profile.add_run_result` victoire Moyen → `[&"mode:difficile"]` ; rien n'est écrit en headless hors `user://` de test (utiliser un `path` paramétrable). Capture : récap victoire avec compteur de rubis en cours d'animation (image à 0,6 s) PC et mobile.

### Lot C : écran titre, fond animé, crédits, musique de menu (Sonnet)
Fichiers : `scenes/menu/title.tscn`, `scripts/menu/title_screen.gd`, `scenes/menu/menu_background.tscn`, `scripts/menu/menu_background.gd`, `scenes/menu/credits.tscn`, `scripts/menu/credits_screen.gd`, `data/audio/sounds.json` (ajout du seul bloc `maps.menu` : `music: [{id:"music.menu", db:[0,0,0,0,0]}]`, `ambience: [{id:"amb.rain.light", db:[-12,-12,-12,-12,-12], rain:true}]`, `surfaces: {}`), `tests/title_test.tscn/.gd`, `tests/capture_title.tscn/.gd`.
API : `TitleScreen` signaux `resume_requested`, `new_run_requested`, `progress_requested`, `settings_requested`, `credits_requested`, `quit_requested` ; `func refresh()` (relit `RunSave.summary()` et `Profile.rubies`) ; `func show_toast(text)`. `MenuBackground.setup(map_id: String)`, `set_paused_visuals(bool)`.
Test headless : sans sauvegarde → bouton principal « Jouer », pas de « Nouvelle run » ; avec sauvegarde factice → « Reprendre » + sous-titre « Ardent · Étage 2 · Moyen · 04:12 » et « Nouvelle run » ; `Platform.is_ios()` simulé → pas de bouton Quitter ; focus initial sur le principal en KBM, aucun focus en tactile ; `Audio.current_map_id() == "menu"` ; fond : `AmbianceManager.map_light_count() > 0`. Capture : titre à t = 1 s et t = 6 s (la caméra a bougé), PC puis mobile 20:9 (`--mobile` + fenêtre 2400×1080 forcée dans la scène de capture).

### Lot D : nouvelle run et progression (Sonnet)
Fichiers : `data/characters.json`, `scenes/menu/new_run.tscn`, `scripts/menu/new_run_screen.gd`, `scripts/menu/character_card.gd`, `scenes/menu/progress.tscn`, `scripts/menu/progress_screen.gd`, `tests/new_run_test.tscn/.gd`, `tests/capture_new_run.tscn/.gd`.
API : `NewRunScreen` signal `start_requested(config: Dictionary)` (`{character, mode}`), `back_requested` ; `ProgressScreen` signal `back_requested`.
Test headless : 6 cartes, 1 jouable ; sélection d'un verrouillé → « Commencer » désactivé ; Difficile verrouillé si `Profile` sans `difficile` ; navigation `ui_right` ×2 puis `ui_down` → focus sur « Moyen » ; `start_requested` émet `{character:&"ardent", mode:&"facile"}` après `ui_left` + accept ; aperçu animé joue `idle_s`. Capture : Nouvelle run avec Ardent sélectionné (PC, mobile), Progression.

### Lot E : réglages unifiés, commandes, pause (Sonnet)
Fichiers : `scenes/ui/settings_panel.tscn`, `scripts/ui/settings_panel.gd` (`class_name SettingsPanel`), `scripts/ui/controls_panel.gd`, `scripts/ui/game_settings.gd` (nouvelles clés §5 : `fullscreen`, `show_fps`, `haptics`, `pause_long_press`, `damage_text_scale`, `colorblind`, `reset_all()`), `scripts/ui/pause_menu.gd` (§3.8), `scripts/ui/pause_button.gd` (appui long optionnel), `scripts/menu/settings_screen.gd` + `scenes/menu/settings.tscn` (enveloppe plein écran du panneau pour le titre), `tests/settings_test.tscn/.gd`, `tests/capture_settings.tscn/.gd`.
API : `SettingsPanel` signaux `back_requested`, `controls_requested` ; `func sync()`. Les consommateurs des nouvelles clés (HUD FPS, DamageNumbers, haptique) ne sont **pas** modifiés par ce lot : seuls les getters existent ; brancher plus tard.
Test headless : chaque ligne ≥ 88 px ; modifier un curseur appelle `Audio.set_volume` (valeur relue) ; stepper Qualité → `GameSettings.quality_choice()` ; `reset_all()` remet les défauts ; en headless aucun fichier écrit ; la pause ouvre le panneau et `ui_cancel` revient au menu pause ; onglets Commandes selon `Platform.input_mode`. Capture : panneau au titre et dans la pause, PC et mobile.

### Lot F : App et flux (Sonnet, après stubs ; s'intègre en dernier)
Fichiers : `scenes/app.tscn`, `scripts/app/app.gd` (`class_name App`), `tests/menu_flow_test.tscn/.gd`, `tests/capture_menu_flow.tscn/.gd`.
API : `App.start_run(config: Dictionary)`, `App.resume_run()`, `App.return_to_title(toast := "")`, `App.show(screen: StringName)` (`&"title"|&"new_run"|&"progress"|&"settings"|&"credits"`), `App.current` ; branche `TitleScreen`, `NewRunScreen`, `ProgressScreen`, `SettingsScreen`, `CreditsScreen`, et `main.gd` (`title_requested`, `replay_requested`, `restart_requested`) ; `FadeLayer` ; instancie `main.tscn` avec `run_mode`, `run_seed = 0`, `resume_data`, et `RunState.character`.
Test headless (sur `app.tscn` réel, avec les lots A-E livrés) : titre → Jouer → Commencer → `game_ready` reçu → `Audio.current_map_id() != "menu"` → pause → Sauvegarder et quitter → titre avec « Reprendre » → Reprendre → même `RunState.stage` → abandonner → récap → Continuer → titre sans sauvegarde ; aucun nœud `Main` orphelin (`get_tree().get_nodes_in_group("director").size() == 0` au titre). Capture `--write-movie` 12 s : titre (0-3 s), nouvelle run (3-5), chargement, 2 s de jeu, pause, retour titre.

---

## 9. Hors périmètre v1 (noté pour plus tard)
Boutique, Personnalisations, Défi du jour, sauvegarde cloud, remappage des touches, sélecteur de langue, variantes de sorts, raccourci rubis pour débloquer, monstres vivants dans la sauvegarde.
