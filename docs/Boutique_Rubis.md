# Boutique de rubis : catalogue cosmétique (proposition, 01/11/2026)

> Demande du joueur : une boutique de skins et d'autres achats en rubis (« gemmes ») qui diversifient le décor, **sans rogue-lite** (aucune amélioration hors run), **sans pay-to-win** et **sans argent réel** : le jeu est vendu 5 € sur les stores. Ce document ne touche à aucun fichier de code : il décrit le catalogue, l'économie et les contrats à prévoir pour les développeurs (Claude) et le pipeline d'assets (Codex dans Blender, synthèse audio).
> Sources : `docs/GDD.md` §3, §5, §10 ; `docs/Maths_Scaling.md` (rubis) ; `docs/Skins.md` ; `docs/Direction_Lumiere_Ambiance.md` ; `game/scripts/core/balance.gd` (`run_rubies`, `daily_rubies`, `omen_rubies`) ; `game/scripts/save/profile.gd`, `skins.gd` ; `game/scripts/menu/collection_view.gd`, `history_screen.gd` ; `game/scripts/game/main.gd` (`end_run`) ; `docs/Audit_Runs_Completes_2026-10-31.md`.

## 0. Résumé

- **Une seule monnaie, les rubis**, gagnés uniquement en jouant. Aucun pack, aucun hasard, aucune rotation, aucun chrono, aucune remise : le catalogue entier est visible et au même prix pour tout le monde, pour toujours.
- **Tout est cosmétique.** Rien dans `cosmetics.json` ne peut porter un champ d'effet ; un test headless le garantit. Les skins « trophée » existants (`<perso>_skin1`, victoire en Difficile) restent des trophées : ils ne s'achètent pas.
- **Gain réel mesuré dans le code** : ≈ 40-75 rubis par run perdue aux étages 2-3, ≈ 165-170 rubis par victoire en Moyen au rythme visé (19 min), ≈ 185-195 au rythme actuel des simulations (33-40 min). Soit **300 à 550 rubis par heure** selon le niveau du joueur. Les piliers pèsent 60 % du gain.
- **Catalogue v1 recommandé (sans Tenues ni Suivants) ≈ 27 500 rubis (55-90 h selon le joueur), v1 complète ≈ 32 500, v1 + v2 ≈ 50 500 (≈ 100-125 h)**. Paliers de prix : 60-150 (un achat toutes les 2-3 parties au début), 250-400, 500-800, 1 000.
- **14 familles** : Tenues et Teintes de personnages, Ciels des biomes (heures et saisons), Veillées (thèmes de l'écran titre), Parements d'interface, Sillages (pas et traînées), Rites (effets de mort et de victoire), Stèles, Partitions (musiques alternatives), Réticules, Saluts (poses de fin de run), Parures du téléporteur, Herbier des pluies (carnet illustré), Chambre claire (mode photo), Suivants (compagnons muets, v2).
- **Top 5 à produire d'abord** : Teintes de personnages, Ciels, Sillages, Parements d'interface, Veillées.

---

## 1. Ce que rapporte une run (mesure dans le code)

### 1.1 Formule en vigueur

`Balance.run_rubies(active_minutes, mode, pillars_done, victory, gold_left)` (`balance.gd` ligne 983) :

```
rubis = floor(1,2 × minutes actives × mult_mode) + 8 × piliers terminés + 25 si victoire + min(or restant / 500, 20)
mult_mode = 0,8 Facile / 1,0 Moyen / 1,3 Difficile (RUBY_MODE_MULT)
```

Plus, ajoutés dans `main.gd` (`end_run`, ligne 411) : `Balance.omen_rubies(présages acceptés)` = **2 rubis par présage accepté** hors « Ciel clair » (`OMEN_RUBIES`, étages 2 à 5, donc 0 à 8). Défi du jour (`daily_rubies`) : 10 + 1 par jour de série (7 max) + 10 si victoire, soit 10 à 26 rubis, une fois par jour.

`pillars_done` compte **tout pilier** passé à `Pillar.STATE_DONE` (`main.gd` ligne 303) : 2 petits piliers + 1 gros par étage 1-4, 1 gros à l'étage 5 (`docs/Design_Etages.md`), soit **13 piliers pour une run gagnée = 104 rubis**. Les piliers sont le premier poste : ils récompensent la progression dans l'étage même quand la run se perd.

Aucune dépense de rubis n'existe aujourd'hui dans le code (`grep spend_rub` vide ; le « raccourci rubis » du GDD §5 n'est pas codé). Le profil accumule sans puits : la boutique sera le premier.

### 1.2 Rubis par run selon l'issue (Moyen)

Durées et or : `docs/Audit_Runs_Completes_2026-10-31.md` (rythme visé 19 min ; simulations actuelles 32-40 min parce que les boss sont longs). Or restant en fin de run : 2 000 à 5 000 (bonus 4-10, plafond 20).

| Issue | Minutes actives | Piliers | Temps | Piliers | Victoire | Or | Présages | **Total** |
|---|---|---|---|---|---|---|---|---|
| Mort à l'étage 1 (boss d'étage) | 5 | 2 | 6 | 16 | 0 | 0 | 0 | **≈ 22** |
| Mort à l'étage 2 | 8-9 | 3-4 | 9-10 | 24-32 | 0 | 0-1 | 2 | **≈ 35-45** |
| Mort à l'étage 3 | 12-13 | 6-7 | 14-15 | 48-56 | 0 | 2-4 | 4 | **≈ 70-78** |
| Mort à l'étage 4 | 16-17 | 9-10 | 19-20 | 72-80 | 0 | 4-6 | 6 | **≈ 100-110** |
| Mort à l'étage 5 (boss final) | 18-19 | 12 | 21-22 | 96 | 0 | 6-10 | 8 | **≈ 130-145** |
| **Victoire, rythme visé** | 19 | 13 | 22 | 104 | 25 | 6-10 | 8 | **≈ 165-170** |
| Victoire, rythme actuel des simulations | 33-40 | 13 | 40-48 | 104 | 25 | 10-20 | 8 | **≈ 185-205** |
| Victoire en Difficile (19 min) | 19 | 13 | 29 | 104 | 25 | 6-10 | 8 | **≈ 172-176** |
| Victoire en Facile (19 min) | 19 | 13 | 18 | 104 | 25 | 6-10 | 8 | **≈ 161-165** |

Le mode ne pèse que sur le terme de temps : Difficile ne rapporte que +7 rubis sur une victoire (+4 %), loin du « +30 % » affiché dans l'écran Nouvelle run (`new_run_screen.gd` ligne 182, qui montre le multiplicateur, pas le résultat). Ce document n'y touche pas (hors périmètre, à signaler au systems-designer), mais les prix ci-dessous supposent le gain réel, pas le gain affiché.

Deux commentaires du code sont périmés par rapport à cette mesure : `balance.gd` ligne 1062 (« Une run normale rapporte ~15-45 rubis ») et `docs/Maths_Scaling.md` (« ≈ 125 rubis… à recalibrer »). À mettre à jour quand la boutique sera codée.

### 1.3 Rythme horaire et profils de joueurs

| Profil | Parties par heure | Rubis par partie | **Rubis par heure** |
|---|---|---|---|
| Débutant (meurt aux étages 2-3, 10-12 min) | 5-6 | 40-75 | **≈ 300** |
| Intermédiaire (atteint l'étage 4-5, gagne 1 fois sur 3) | 3-4 | 100-170 | **≈ 400-450** |
| Régulier (gagne 2 fois sur 3 en ≈ 20 min) | 3 | 150-170 | **≈ 500-550** |
| + Défi du jour (une fois par jour) | | +10-26 | négligeable sur l'heure, +15 % sur une session de 30 min |

Base de calibrage retenue : **400 rubis par heure** (joueur régulier moyen). 60 h = 24 000 rubis ; 100 h = 40 000 rubis.

---

## 2. Principes et garde-fous

### 2.1 Règles d'économie

1. **Prix fixes, visibles, définitifs.** Pas de rotation, pas d'offre limitée, pas de remise, pas de bundle, pas de « nouveauté » mise en avant par un chrono. Un article ajouté par une mise à jour arrive au prix de son palier, c'est tout.
2. **Aucune seconde monnaie, aucun achat en argent réel, aucun hasard.** Pas de coffres cosmétiques, pas de tirage.
3. **Rien ne se perd.** Les rubis dépensés ne sont pas remboursables (confirmation obligatoire), mais un article acheté reste acquis dans le profil (`owned_cosmetics`) même si son asset manque (repli silencieux sur le défaut, comme `Skins.has_assets`).
4. **Aucun article n'est gardé derrière un succès**, sauf les trophées existants (skins Difficile) qui ne sont pas dans la boutique. Le catalogue entier est achetable dès la première partie ; le joueur choisit l'ordre.
5. **Le mode test voit tout** (`TestMode` : aperçu de n'importe quel article sans écriture au profil), comme pour les skins.

### 2.2 Règles de lisibilité (toute famille)

- **Jamais sur la couche des télégraphes** (CanvasLayer 5, `unshaded`, `Direction_Lumiere_Ambiance.md` §4.9) ni sur les projectiles ennemis, ni sur les monstres, ni sur les barres de PV, ni sur les pickups. Un cosmétique vit sous le joueur, sur le joueur, dans l'interface hors HUD de combat, ou dans le décor.
- **Aucune couleur de la palette des télégraphes** (rouge/orange de `Design_Boss_Cartes.md` §0) sur un effet au sol du joueur (sillages, stèles, suivants). Alpha ≤ 0,5 pour tout effet au sol cosmétique.
- **Luminance du `CanvasModulate` ≥ 0,42** pour tout Ciel (borne déjà clampée par le code d'ambiance, §1.1 de la direction lumière) : un Ciel « nuit » est une nuit claire aux lanternes montées, jamais une nuit noire.
- **Rien ne change les hitbox, le gabarit, les cadences d'animation, la durée ou la portée des VFX de sorts, la taille du réticule** (`GameSettings.reticle_scale()` reste le seul réglage de taille, gratuit, dans Accessibilité).
- **Particules cosmétiques** : budget commun de **24 particules vivantes** pour toutes les familles réunies (sillages, suivants, rites), pool unique, coupées en qualité Bas, réduites de moitié au-dessus de 150 monstres vivants.
- **Aucune information de jeu** vendue : le bestiaire textuel (attaques, portées, PV) reste gratuit ; l'Herbier vend des planches illustrées et du lore, jamais une donnée qui aide à jouer.

### 2.3 Test headless à écrire (`game/tests/cosmetics_test.tscn`)

- Chaque entrée de `data/cosmetics.json` a `id`, `family`, `name`, `desc`, `price` (entier > 0, dans la liste des paliers), `preview` ; **aucune** clé parmi `effects`, `stats`, `mult`, `bonus`, `unlock_rule` ; `assets` listés existent ou l'entrée est marquée `"pending": true`.
- Somme des prix par famille et totale conforme au §4 à ± 10 %.
- Équiper puis déséquiper chaque article avec un `RunState` et un `Balance` de référence : empreinte des valeurs identique avant et après (aucune lecture de cosmétique dans `scripts/core/`).
- `Profile.buy_cosmetic(id)` : refuse si `rubies < price` ou déjà possédé ; une seule écriture ; mode test : refuse d'écrire.

---

## 3. Le catalogue, famille par famille

Pour chaque famille : ce que c'est, production (code Claude : S ≈ 1 jour, M ≈ 2-3 jours, L ≈ 1 semaine ; assets Codex : lots et poids mobile estimé), perf mobile, prix, risque et garde-fou. Les noms sont des propositions dans le vocabulaire du jeu (pluie, Source, biomes), sans emprunt à Risk of Rain ni Vampire Survivors.

### 3.1 Tenues (skins complets de personnages)

- **Quoi** : un second skin par personnage (`<perso>_skin2`), même contrat que `docs/Skins.md` (même silhouette IoU > 0,95, accent émissif conservé, mêmes planches, `.tres` substitué). Le skin 1 reste le trophée du Difficile ; la Tenue achetable raconte autre chose : **« ce qu'il était avant la pluie »** (tenues civiles, neuves, de la Cité avant la rouille : lin, laine, cuivre brillant, verre intact), contraste exact du trophée (après la Source).
- **Production** : code **S** (la plomberie `Skins` existe ; passer de « un skin par personnage » à une liste : `Skins.skin_of` → `skins_of`, `selected_skin` inchangé ; `collection_view` affiche n cellules par personnage). Assets Codex : **un lot par personnage**, copie du `.blend` du héros, matériaux et accessoires seulement, rendu `iso_rig`, même procédé que les lots 47-51 ; Tocsin reste le plus lourd (membres détachés).
- **Perf** : **+2 à 8 Mo mobile par Tenue** (36 Mo pour 10 skins, mesure de `Skins.md`). Avec un budget textures déjà dépassé (219 Mo pour 180), **les Tenues imposent le pack optionnel** : fichier `.pck` cosmétique téléchargé à la demande (Play Asset Delivery `on-demand` sur Android, On-Demand Resources sur iOS, `ProjectSettings.load_resource_pack`), PC l'embarque. Contrat orchestrateur (§5). Sans pack : 5 Tenues au plus en v1.
- **Prix** : **1 000 rubis** chacune (palier 4). 10 Tenues = 10 000.
- **Risque** : nul sur la puissance ; lisibilité tenue par le contrat IoU (le joueur et les monstres lisent le personnage comme avant). Garde-fou : aucun accessoire au-delà de 2 px hors silhouette, accent émissif identique (teinte et zones).

### 3.2 Teintes (recolorations de personnages)

- **Quoi** : 2 à 3 variantes de palette par personnage (tenue par défaut **ou** Tenue possédée), par exemple pour Ardent « Suie » (noir et gris, braise inchangée) et « Argile » (ocre et terre cuite). L'accent émissif ne change jamais.
- **Production** : code **M** : un shader de **table de correspondance** (gradient map) appliqué au sprite du joueur, qui lit une bande `lut_<teinte>.png` (256×8, rendue par Codex dans Blender comme une texture d'étalonnage, à la manière des `sky_*_256x64`) et **exclut les zones du masque `_e`** (émission intacte). C'est un shader d'étalonnage (famille autorisée par `CLAUDE.md` : « les systèmes sont du code Godot, toutes leurs textures sont rendues dans Blender »), pas un asset dessiné en code. **À valider par le joueur** : si la règle « tout visuel par Codex » est lue strictement, la solution de repli est le re-rendu Codex par Teinte (même coût Mo qu'une Tenue, 2-8 Mo chacune, ce qui tue la famille sur mobile). Rendu de contrôle : Codex livre pour chaque Teinte un portrait 256×256 rendu avec les vrais matériaux pour servir d'aperçu et de référence de couleur ; le shader doit rester à ΔE < 8 de ce portrait sur les trois tons du cel.
- **Perf** : **≈ 0 Mo** par Teinte (une bande de 2 Ko + un portrait 256). Un `ShaderMaterial` de plus sur un seul sprite : négligeable.
- **Prix** : **300 rubis** (palier 2). 10 personnages × 2 Teintes = 6 000 ; 3e Teinte en v2 (+3 000).
- **Risque** : une Teinte trop sombre perdrait le joueur dans la foule : garde-fou L\* du ton moyen ≥ 45 (même borne que les monstres sombres, direction lumière §1.1), vérifié par le test sur le portrait de référence. Les Teintes ne s'appliquent pas aux skins trophée (le trophée reste reconnaissable).

### 3.3 Ciels (heures et saisons des biomes)

- **Quoi** : un **profil d'ambiance alternatif** par biome (`data/ambiance/<biome>_<ciel>.tres`, classe `AmbianceProfile` existante : couleurs, soleil, brume, pluie, ciel reflété, particules). Le joueur choisit par biome son Ciel ; la variante A/B de carte, les monstres, les coffres sont inchangés. Propositions :

| Biome | Ciel par défaut | Ciel 1 | Ciel 2 (v2) |
|---|---|---|---|
| Terrasses noyées | 17 h 40, soleil sous les nuages | **Nuit de lanternes** (23 h, lanternes de rizière allumées, lucioles, pluie fine, lune dans les flaques) | **Matin de givre** (7 h, brume blanche, gel sur les terrasses, `frost_crystal_16`) |
| Forêt-brume | aube bleue | **Après-midi d'orage** (rayons chauds `godray`, feuilles de cèdre qui tombent) | **Nuit des lucioles** (canopée noire, lucioles ×3, lanternes vertes montées) |
| Cité de rouille | crépuscule d'orage | **Canicule de cendres** (midi ocre, `ash_16`, brume de chaleur, pas de pluie) | **Neige sur le canal** (nuit claire, neige lente, lampadaires) |
| Cryptes noyées | (profil actuel) | **Marée haute** (eau plus haute, reflets, bulles `bubble_16`) | **Veilleuse** (cierges, teinte ambre) |
| La Source | aucun Ciel (étage final, mise en scène fixe) | — | — |

- **Production** : code **S** (sélecteur `Profile.equipped["ciel:<biome>"]` lu par `AmbianceManager` au chargement de l'étage ; les textures de ciel reflété `sky_<ciel>_256x64` par Ciel). Assets Codex : par Ciel, **1 texture de ciel 256×64**, 0 à 2 textures de particules nouvelles (neige 16 px, cendre déjà existante, lucioles existantes), réglages du `.tres` par le game designer (pas d'asset). Un Ciel = un petit lot.
- **Perf** : identique à un profil existant (mêmes systèmes, mêmes textures de brume) ; **≈ 0,1 Mo** par Ciel. Les particules de Ciel sont déjà bornées par `quality.gd`.
- **Prix** : **600 rubis** (palier 3) par Ciel. 4 Ciels v1 = 2 400 ; 4 Ciels v2 = 2 400.
- **Risque** : le plus sensible du catalogue. Garde-fous : luminance `CanvasModulate` ≥ 0,42 (clamp existant), contraste des monstres L\* 55 vérifié par la capture de validation de chaque Ciel (même protocole que §2 de la direction lumière), **la couche des télégraphes ne lit pas le profil**, la brume basse ne monte jamais au-dessus de 0,35 d'opacité sur la zone jouable, les ombres cuites restent celles de la carte (pas de recuisson). Un Ciel « sans pluie » (Canicule) garde le fil conducteur par la brume de chaleur et les cendres ; la pluie revient quand D monte (règle §3 de la direction lumière, inchangée).

### 3.4 Veillées (thèmes de l'écran titre)

- **Quoi** : la scène du titre (`MenuBackground` : vraie carte + feu de camp + caméra lente) devient choisissable : carte, Ciel, et **mise en scène autour du feu** (props Codex). Propositions : « Feu de camp » (défaut, Terrasses), « Bivouac des cèdres » (Forêt, tente de toile cirée, lanterne), « Quai de la Cité » (Cité, brasero dans un bidon, chat de gouttière), « Crypte veilleuse » (cierges, eau noire), « Après la Source » (Source apaisée, pluie d'or fine : réservé aux joueurs qui ont gagné une fois, seul article conditionnel, gratuit à la première victoire).
- **Production** : code **S** (`MenuBackground.map_id` et un dictionnaire de props par thème ; le feu de camp devient un prop interchangeable). Assets Codex : par Veillée, **2 à 4 props** rendus iso (tente, brasero, cierges, lanterne, chat en boucle de 8 frames), ≈ 0,5-1 Mo mobile par thème.
- **Perf** : identique au titre actuel (déjà une carte + ambiance). Aucun impact en jeu.
- **Prix** : **500 rubis** (palier 3). 4 Veillées achetables = 2 000.
- **Risque** : nul (hors jeu). La musique du titre suit la Veillée si une Partition menu est possédée (§3.8), sinon `music_menu_01`.

### 3.5 Parements d'interface (cadres et thèmes d'UI)

- **Quoi** : jeux de **cadres** 9-slices (`ui/da/bar_frame_*.json`, `button_*.json`, `spell_frame*.png`, cadre du portrait, fond des menus) dans les matières des skins trophée : « Fer bleui » (défaut), « Bronze de cloche » (Tocsin), « Céladon » (Averse), « Laque noire et or » (Rictus), « Argent noirci » (Vigie). Seuls les **cadres, fonds et ornements** changent ; les **remplissages** (`bar_fill_hp`, `bar_fill_xp`, `bar_fill_boss`), les icônes de sorts et leurs anneaux de recharge, les chiffres de dégâts et les invites de touches sont inchangés.
- **Production** : code **M** (un `Theme` Godot par Parement chargé depuis `data/cosmetics.json`, substitution des `StyleBoxTexture` ; le HUD et les menus lisent déjà les 9-slices par chemin). Assets Codex : un lot par Parement, **≈ 12 PNG** (cadres de barres, boutons normal/pressé/danger, cadre de sort, cadre de portrait, séparateur), lossless, **≈ 0,4 Mo** chacun.
- **Perf** : nulle (mêmes nœuds, autres textures).
- **Prix** : **400 rubis** (palier 2). 4 Parements = 1 600.
- **Risque** : lisibilité des barres : garde-fou « le cadre ne couvre jamais le remplissage, contraste cadre/fond ≥ 3:1 », mêmes marges 9-slices (JSON identiques), tailles de police intouchées. Test : capture du HUD avec chaque Parement, PV à 20 % lisible.

### 3.6 Sillages (traces de pas et traînées)

- **Quoi** : un effet discret **sous le joueur** quand il marche : « Ronds d'eau » (ondulation dans les flaques, défaut gratuit), « Braises » (étincelles qui s'éteignent en 0,6 s), « Pétales » (fleurs de cerisier des terrasses), « Givre » (empreintes blanches qui fondent), « Feu follet » (spores vertes, Bourbe), « Encre » (taches sombres, Rictus). Plus deux **traînées** d'esquive : fumée, gouttelettes (sur `slide_dodge`, 0,3 s).
- **Production** : code **M** (émetteur unique `CosmeticTrail` sous `Player`, `CPUParticles2D` ou pool de `Sprite2D`, cadence liée à `footsteps` déjà joués par `audio_manager`). Assets Codex : par Sillage, **1 planche 4×4 de 32 px** (particule) + 1 décalque de pas 64 px, **≈ 50 Ko** chacun.
- **Perf** : ≤ 8 particules vivantes par Sillage (dans le budget commun de 24), coupé en qualité Bas, pas d'ombre, pas de lumière.
- **Prix** : **250 rubis** (palier 2). 6 Sillages + 2 traînées d'esquive à 200 = 1 900.
- **Risque** : confusion avec un télégraphe ou un pickup. Garde-fous : jamais de rouge ni d'orange saturé (Braises = ambre sombre, alpha 0,4, taille ≤ 0,15 u), z sous les créatures, alpha ≤ 0,5, rayon total ≤ 0,4 u autour du joueur, **aucune émission additive** (ne rivalise pas avec les capsules d'or), disparition en ≤ 0,8 s.

### 3.7 Rites (effets de mort et de victoire)

- **Quoi** : « Dernier souffle » : l'effet joué pendant `DEATH_SCREEN_DELAY_S` après la mort du joueur (défaut : chute + fondu) : « Lanterne » (une lanterne s'élève lentement et s'éteint), « Cendres au vent », « Reflet » (le personnage se dissout dans la flaque), « Carillon » (une cloche sourde, Tocsin). « Apothéose » : l'effet à la victoire sur la Source (défaut : `vfx/source`) : « Éclaircie » (les nuages s'ouvrent, rayons), « Pluie d'or », « Silence » (tout s'arrête, une seule goutte).
- **Production** : code **S** (un point d'accroche dans `main.gd` `_on_player_died` et dans la séquence de victoire ; lecture d'un `SpriteFrames` + son). Assets Codex : par Rite, **1 planche VFX** (8-16 frames, 256 px) + 1 son de synthèse court, **≈ 0,5-1 Mo** par Rite.
- **Perf** : joué une fois par run, hors combat : nul.
- **Prix** : **300 rubis** (mort), **400 rubis** (victoire). 4 morts + 3 victoires = 2 400.
- **Risque** : nul (la run est finie). Garde-fou : durée fixe (ne retarde ni n'accélère l'écran de récap : la durée du Rite est bornée à `DEATH_SCREEN_DELAY_S`).

### 3.8 Partitions (musiques alternatives)

- **Quoi** : par biome, un second jeu de musique **à 4 couches** (`base / tension / drive / climax`, même structure que `music_<biome>_*_01`, pour que la montée avec D fonctionne sans changer `audio_manager`) + un thème de boss ; et 2 musiques de menu. Propositions de ton : Terrasses « Flûtes de bambou et pluie », Forêt « Chœur de brume », Cité « Forge et tôle », Cryptes « Orgue noyé », menu « Berceuse de la Source ».
- **Production** : code **S** (`audio_manager` lit `music_<biome>_<partition>_<couche>.ogg` selon l'article équipé). Assets : **synthèse Codex** (`art/tools/audio/`), 5 pistes par biome, 1,5-2 min chacune en boucle, **≈ 4-6 Mo par Partition en OGG 96 kb/s** (l'audio pèse déjà 67 Mo : les Partitions vont **dans le pack optionnel** avec les Tenues).
- **Perf** : décodage OGG identique à aujourd'hui (une seule Partition active).
- **Prix** : **800 rubis** (palier 3) par biome, 400 par musique de menu. 4 biomes + 2 menus = 4 000.
- **Risque** : nul sur la lisibilité. Les **sons de jeu** (télégraphes sonores, coups, pas) ne font jamais partie d'une Partition.

### 3.9 Réticules (PC et manette)

- **Quoi** : formes et teintes du réticule de visée (`ui/crosshair.png`, `AimReticle`) : « Point » (défaut), « Goutte », « Croix de fer », « Anneau fin », « Rune de la Source », « Œil de cormoran ». Teinte parmi 4 (blanc, accent du personnage, céladon, ambre). Sur mobile (ciblage automatique), la famille n'apparaît pas dans la boutique sauf écran tactile avec souris.
- **Production** : code **S** (chemin du sprite + modulate). Assets Codex : **6 PNG 64×64** lossless, ≈ 30 Ko.
- **Perf** : nulle.
- **Prix** : **120 rubis** (palier 1, premier achat typique). 6 formes = 720 ; teintes gratuites avec la forme.
- **Risque** : un réticule plus gros ou plus contrasté aiderait la visée. Garde-fous : **même boîte 64×64, même surface opaque ± 10 %, même alpha**, taille réglée uniquement par `reticle_scale` (gratuit, Accessibilité) ; aucun indicateur de portée, aucune ligne de visée.

### 3.10 Saluts (poses de fin de run et emotes de récap)

- **Quoi** : la pose du personnage sur l'écran de récap (`EndRunScreen`) et sur la fiche personnage : « Salut » (défaut), « Lanterne levée », « Repos sur l'arme », « Révérence » (Rictus), « Carillon » (Tocsin), « Pluie bue » (Averse). Un Salut est joué aussi 1,5 s au départ de run devant le téléporteur d'arrivée, pendant la protection d'arrivée (aucune action possible).
- **Production** : code **S** (un `SpriteFrames` optionnel `salute_<id>` par personnage, repli sur `idle`). Assets Codex : par Salut et par personnage, **1 boucle de 8-12 frames, 1 direction (s)**, 256 px, **≈ 0,2 Mo** ; 5 Saluts universels (déclinés par perso par le même script) + 1 Salut propre à chaque personnage.
- **Perf** : hors combat.
- **Prix** : **150 rubis** (universel, achat pour tous les persos), **250** (propre au personnage). 5 × 150 + 10 × 250 = 3 250.
- **Risque** : nul. Garde-fou : jamais joué pendant une action ; le Salut de départ se coupe au premier déplacement.

### 3.11 Parures du téléporteur et des piliers

- **Quoi** : l'habillage du téléporteur de sortie (`teleporter_idle / active`) et, en v2, des 3 piliers : « Arche de pierre » (défaut), « Arche de bronze » (cerclages, cloche), « Lanternes de fête » (guirlande de lanternes de papier), « Racines » (l'arche envahie, lucioles), « Vitrail » (Source, verre et plomb).
- **Production** : code **S** (chemin des `SpriteFrames` du téléporteur par article ; les piliers lisent `Pillar` et demandent un nœud visuel séparé : v2). Assets Codex : par Parure, **idle + active + ombre**, 8 directions non nécessaires (objet symétrique vu en iso : 1 vue), **≈ 1 Mo**.
- **Perf** : nulle (même nombre de sprites, même lumière).
- **Prix** : **500 rubis** (palier 3). 3 Parures téléporteur v1 = 1 500 ; piliers v2 : 3 × 500 = 1 500.
- **Risque** : le téléporteur doit rester reconnaissable à 30 u et son état actif lisible. Garde-fous : même gabarit, même halo d'activation (couleur et rayon de la lumière `active` inchangés, seule la matière de l'arche change), l'anneau de charge (`pillar_zone_ring`) n'est jamais touché.

### 3.12 Herbier des pluies (carnet illustré)

- **Quoi** : un carnet dans l'écran Historique : une **planche illustrée** par monstre, mini-boss, boss et biome (rendu Codex « planche naturaliste » : la créature en pose d'étude sur papier taché d'eau, 512×512, une légende de lore de 2-3 phrases). Les fiches de jeu (attaques, PV, portées) restent **gratuites et séparées** (texte).
- **Production** : code **M** (onglet « Herbier » dans `HistoryScreen`, grille `CollectionView`, vue plein écran d'une planche, texte dans `data/herbier.json`). Assets Codex : **≈ 40 planches** (monstres T1-T3 des 4 biomes, 20 mini-boss, 12 boss d'étage, boss final, 4 biomes), rendues depuis les `.blend` existants avec un éclairage d'étude et un fond papier, **≈ 0,15 Mo** chacune (6 Mo au total, lossless inutile : ASTC). Textes par le game designer.
- **Perf** : nulle (menus).
- **Prix** : **60 rubis** par planche (palier 1, l'achat « entre deux parties »), boss d'étage et final 120. ≈ 40 planches = 3 000.
- **Risque** : nul tant que la planche ne montre **aucune portée ni zone d'attaque** (une pose, pas un schéma). La planche d'un monstre n'est proposée qu'une fois le monstre rencontré (pas de spoiler), sans condition d'achat autre.

### 3.13 Chambre claire (mode photo)

- **Quoi** : depuis la pause (jeu figé) : masquer le HUD, zoom 0,5-2×, filtres d'étalonnage (les Ciels possédés + « Sépia d'archive », « Encre », « Négatif de pluie »), cadres (les Parements possédés), rotation interdite (vue iso), export PNG dans `user://photos/` et partage système. Le mode lui-même : **gratuit** (c'est aussi un outil de capture pour le store) ; se vendent les filtres et les cadres de photo.
- **Production** : code **M** (caméra de pause, capture `Viewport.get_texture()`, partage `OS.share`/intent sur mobile). Assets Codex : 4 cadres de photo (bordure 9-slices, coins d'archive), 3 bandes LUT de filtre, ≈ 0,3 Mo.
- **Perf** : nulle en jeu (uniquement en pause).
- **Prix** : filtres **100 rubis**, cadres **100**. 3 filtres + 4 cadres = 700.
- **Risque** : **repérage de la carte en pause**. Garde-fous : déplacement de la caméra limité à ± 3 u autour du joueur, brume et obscurité d'ambiance inchangées, télégraphes visibles tels quels (ne pas les masquer : le joueur ne doit pas « voir à travers »), monstres hors écran non révélés (le zoom arrière 0,5× dévoile 2× plus de terrain : **plafonner le zoom arrière à 0,8×** et laisser le zoom avant libre).

### 3.14 Suivants (compagnons muets, v2)

- **Quoi** : une petite créature inoffensive qui suit le joueur : « Rainette » (grenouille, hors personnage Rainette), « Phalène de lanterne », « Feu follet », « Goéland boiteux ». Aucun effet, aucun ramassage, aucune collision, aucune lumière.
- **Production** : code **M** (suiveur avec retard et flottement, évitement visuel des monstres : il se place du côté opposé au plus proche). Assets Codex : **1 petite boucle 8 directions, 12 frames, 64 px** par Suivant, ≈ 0,4 Mo.
- **Perf** : 1 sprite animé de plus ; coupé au-dessus de 150 monstres vivants (il « se cache » dans la pèlerine du joueur avec un petit fondu).
- **Prix** : **700 rubis** (palier 3). 4 Suivants = 2 800.
- **Risque** : le plus discutable : confusion avec un pickup ou un petit monstre dans la foule. Garde-fous : ≤ 0,4 u, z sous le joueur, alpha 0,7 réduit à 0,3 quand plus de 20 monstres sont à moins de 6 u, aucune couleur de pickup (pas de doré, pas de vert XP), silhouette ronde et basse. **À produire en dernier**, après un test en mode test avec 250 monstres.

### 3.15 Refusés (et pourquoi)

| Idée | Pourquoi non |
|---|---|
| Couleurs de sorts du joueur | l'accent émissif est la couleur de lecture des sorts et de la lumière du joueur (`LightRig`, `Skins.md`) ; changer la couleur des projectiles change la lecture ami/ennemi. Les Teintes gardent l'accent. |
| Skins de monstres ou de boss | la silhouette et la palette des monstres sont de la lisibilité pure (250 monstres, L\* 55) : rien à vendre. |
| Couleurs de télégraphes, taille du réticule, barres de PV | réglages d'accessibilité, gratuits dans Réglages, jamais en boutique. |
| Décor qui change le sol (tuiles, props de combat) | un prop de plus au sol cache un télégraphe ou une capsule ; les Ciels ne touchent que la lumière, la brume et les particules hautes. |
| Raccourci rubis pour un personnage ou une variante (GDD §5) | ce n'est pas cosmétique ; hors boutique. À trancher à part : le garder en « raccourci » séparé avec un prix élevé (≈ 1 000) ou l'abandonner. Ce document recommande l'abandon : la boutique doit rester 100 % cosmétique pour que « rubis = jamais de puissance » soit une phrase vraie. |
| Boost de rubis, « x2 » cosmétique | aucune monnaie sur la monnaie. |

---

## 4. Économie : paliers, totaux, cadence

### 4.1 Paliers de prix

| Palier | Prix | Familles | Temps de jeu pour un article (400 rubis/h) |
|---|---|---|---|
| 1 | **60-150** | planches de l'Herbier (60-120), Réticules (120), Saluts universels (150), filtres et cadres photo (100) | 10-25 min : **un achat toutes les 2-3 parties** pour un débutant (40-75 rubis/run) |
| 2 | **250-400** | Sillages (200-250), Saluts de personnage (250), Teintes (300), Rites de mort (300), Parements (400), Rites de victoire (400), Partition de menu (400) | 40-60 min |
| 3 | **500-800** | Veillées (500), Parures du téléporteur (500), Ciels (600), Suivants (700), Partitions de biome (800) | 1 h 15 - 2 h |
| 4 | **1 000** | Tenues | 2 h 30 |

### 4.2 Totaux du catalogue

| Famille | v1 (articles × prix) | v1 (rubis) | v2 (rubis) |
|---|---|---|---|
| Teintes | 20 × 300 | 6 000 | +3 000 (3e Teinte) |
| Tenues | 5 × 1 000 (pack optionnel ou 5 persos) | 5 000 | +5 000 (5 restantes) |
| Ciels | 4 × 600 | 2 400 | +2 400 |
| Veillées | 4 × 500 | 2 000 | — |
| Parements | 4 × 400 | 1 600 | — |
| Sillages | 6 × 250 + 2 × 200 | 1 900 | — |
| Rites | 4 × 300 + 3 × 400 | 2 400 | — |
| Partitions | 2 biomes × 800 + 1 menu × 400 | 2 000 | +2 000 (2 biomes + 1 menu) |
| Réticules | 6 × 120 | 720 | — |
| Saluts | 5 × 150 + 10 × 250 | 3 250 | — |
| Parures du téléporteur | 3 × 500 | 1 500 | +1 500 (piliers) |
| Herbier | ≈ 40 planches | 3 000 | — |
| Chambre claire | 3 filtres + 4 cadres × 100 | 700 | — |
| Suivants | — | — | +2 800 |
| Stèles (§4.4, option) | — | — | +1 250 |
| **Total** | | **≈ 32 500** | **≈ 50 500** |

Lecture en temps de jeu : à 400 rubis/h, **v1 ≈ 80 h**, un joueur régulier (500-550/h) la vide en **≈ 60 h**, un débutant (300/h) en ≈ 110 h ; **v1 + v2 ≈ 100-125 h**. Pour viser strictement « 60-100 h » dès la v1, retirer les Tenues de la v1 (elles dépendent du pack optionnel) : v1 sans Tenues ≈ 27 500 rubis = **55-90 h**. C'est la recommandation : **v1 = tout sauf Tenues et Suivants**, Tenues dès que le pack optionnel existe.

### 4.3 Cadence vécue par un joueur régulier

| Parties jouées | Rubis cumulés (profil intermédiaire → régulier) | Achats possibles |
|---|---|---|
| 1-3 (découverte, morts aux étages 2-3) | 120-200 | 1 Réticule ou 2 planches, puis 1 Salut : **un article toutes les 2-3 parties** |
| 4-8 | 450-700 | 1 Sillage + 1 Teinte, ou 1 Parement |
| 9-15 (premières victoires) | 1 200-1 800 | 1 Ciel + 1 Teinte + planches, ou 1 Veillée + 1 Rite |
| 16-30 | 3 000-4 200 | 1 Partition, 2 Ciels, Parure du téléporteur : **un article de palier 3 toutes les 5-6 parties** |
| 31-60 | 7 000-9 000 | Tenues (pack), le reste des Ciels et Partitions |
| 61-100 | 13 000-16 000 | Partitions, Parures, derniers Ciels |
| 101-190 | 16 000-29 000 | **fin de la v1 recommandée (27 500) vers 170-190 parties, ≈ 60 h** pour un régulier à 3 parties par heure |

Ce rythme vient du gain réel ; si le systems-designer recalibre `run_rubies` (par exemple pour que Difficile rapporte vraiment +30 %), les prix suivent proportionnellement : garder le ratio « palier 1 ≈ 2-3 parties de débutant, palier 4 ≈ 6 victoires ».

### 4.4 Option : Stèles (pierres de pluie)

Famille retenue en option v2, proposée par le joueur : un marqueur **sans collision, sous les créatures, alpha 0,4**, posé sur la carte à l'endroit de la mort précédente du joueur sur la même carte (même variante), visible jusqu'à ce qu'on marche dessus (petit son, aucune récompense). Modèles : « Cairn », « Lanterne éteinte », « Épée plantée », « Nénuphar », « Cloche fêlée ». Prix 250, 5 modèles = 1 250. Codex : 5 props iso 64 px, 0,1 Mo. Risque : un prop de plus au sol ; garde-fous : jamais dans l'anneau d'un pilier ni dans l'arène de la Source, masqué pendant un combat de boss, désactivable dans Réglages. À produire après le test des Sillages.

---

## 5. Contrats à prévoir (pour l'orchestrateur, hors de ce document)

- **Données** : `game/data/cosmetics.json` : liste d'entrées `{id, family, name, desc, price, preview, assets: [...], per_character: bool, biome: "", pending: bool}`. Familles (clés) : `tenue`, `teinte`, `ciel`, `veillee`, `parement`, `sillage`, `rite_mort`, `rite_victoire`, `partition`, `reticule`, `salut`, `parure`, `herbier`, `filtre_photo`, `cadre_photo`, `suivant`, `stele`.
- **Profil** (`profile.gd`) : `owned_cosmetics: Array[StringName]`, `equipped_cosmetics: Dictionary` (`family[:scope]` → id, par exemple `"ciel:foret_brume"`, `"teinte:ardent"`, `"salut:tocsin"`), `spend_rubies(n) -> bool`, `buy_cosmetic(id) -> bool` (une écriture), `equip_cosmetic(family_scope, id)`. Migration de version : champs absents = vides. Rien en mode test (`begin_sandbox`).
- **Autoload de lecture** : `Cosmetics` (`scripts/core/cosmetics.gd`, orchestrateur) : `equipped(family, scope) -> Dictionary`, `path(family, scope, asset) -> String` avec repli sur le défaut si l'asset manque (même logique que `Skins.has_assets`). Aucun autre script de `scripts/core/` ne lit les cosmétiques.
- **Écran** : bouton **« Collection »** sur le titre (remplace les boutons « Personnalisations » et « Boutique » du GDD §3, fusionnés : il n'y a rien à vendre en argent réel), rubis en haut à droite, un onglet par famille, grille `CollectionView` réutilisée (aperçu, prix, « Acheter » → `ConfirmDialog` « Dépenser 300 rubis pour Suie ? », puis « Équiper » / « Équipé »). Articles verrouillés par manque de rubis : affichés en couleur avec le prix, jamais grisés comme un cadenas (ce n'est pas un objectif, c'est un prix). L'onglet Skins actuel de l'Historique devient l'onglet « Tenues » de la Collection ; les trophées y restent avec leur condition.
- **Pack optionnel** (Tenues, Partitions) : `cosmetics.pck` chargé par `ProjectSettings.load_resource_pack` au lancement s'il est présent ; sur Android via Play Asset Delivery `on-demand`, sur iOS via On-Demand Resources, bouton « Télécharger (36 Mo) » sur l'article ; PC embarque tout. Contrat de la couche `PlatformServices`.
- **Assets** : `game/assets/sprites/cosmetics/<famille>/<id>/` pour les nouvelles familles ; les Tenues restent dans `characters/<perso>/skins/<id>/` (contrat `Skins.md`) ; les Ciels dans `data/ambiance/<biome>_<ciel>.tres` + `assets/sprites/ambiance/sky_<ciel>_256x64.png` ; les Partitions dans `assets/audio/music/music_<biome>_<partition>_<couche>.ogg`. Consignes Codex : `art/tools/cosmetics/_c<n>_<famille>.txt` sur le gabarit `art/tools/_consigne_gabarit.txt`, profil `eco-mini`, un lot par article ou par famille légère.
- **Tests** : `tests/cosmetics_test.tscn` (§2.3) ; capture de validation par Ciel et par Parement (protocole de la direction lumière, PV à 20 %).
- **Docs à corriger quand c'est codé** : `balance.gd` ligne 1062, `Maths_Scaling.md` (rubis), `Design_Menus.md` (le titre gagne « Collection »), `GDD.md` §3 et §10 (plus de Boutique en argent réel : jeu payant).

---

## 6. Ordre de production recommandé

| Ordre | Famille | Pourquoi d'abord | Coût |
|---|---|---|---|
| 1 | **Teintes** | la famille « skins » la moins chère en Mo (≈ 0), 20 articles d'un coup, visible toute la run | code M + 20 bandes LUT et 20 portraits Codex |
| 2 | **Ciels** | la demande explicite « diversifier le décor », assets quasi nuls (profils `.tres` + 4 ciels 256×64), fort effet | code S + réglages GD + 4 petits lots |
| 3 | **Sillages** | premier achat de palier 2 plaisant, met en place le budget de particules partagé par Rites et Suivants | code M + 8 micro-lots |
| 4 | **Parements d'interface** | visibles dans tous les menus et le HUD, 4 lots simples de 9-slices | code M + 4 lots |
| 5 | **Veillées** | l'écran titre est vu à chaque session ; valorise les cartes existantes | code S + 4 lots de props |
| 6-9 | Réticules, Saluts, Rites, Herbier | paliers 1-2, remplissent la cadence « un achat toutes les 2-3 parties » | code S/M, lots légers |
| 10-11 | Parures du téléporteur, Partitions | palier 3, Partitions liées au pack optionnel | code S + lots moyens, audio |
| 12 | Tenues | dépendent du pack optionnel et du palier 2 du budget textures | code S + 10 lots lourds |
| v2 | Suivants, Stèles, piliers, 3e Teinte, Ciels 2, Partitions 2 | après mesure du comportement d'achat (journal de run : `RunLog` note déjà `skin`) | — |

Mesure après sortie : `RunLog` ajoute les articles équipés par run (`cosmetics: {family: id}`) et le profil le solde de rubis en fin de run ; `tools/analyse_runs.py` sort « rubis gagnés par heure réelle » et « premier achat à la partie n » pour vérifier la cadence 2-3 parties.
