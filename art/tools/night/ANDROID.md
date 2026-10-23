# Build Android Rainfall : checklist

Etat constate le 22/10/2026 : export impossible, il manque 4 choses.

## A installer / telecharger (rien n'a ete telecharge par l'agent)
1. **Modeles d'export Godot 4.7.2** (dossier `%APPDATA%\Godot\export_templates\` vide). Editeur Godot > Editeur > Gerer les modeles d'export > Telecharger et installer (source officielle godotengine.org). Version a obtenir : 4.7.2.stable.
2. **JDK 17** (OpenJDK, ex. Temurin 17 sur adoptium.net). Aucun JDK installe. Puis Editeur > Parametres de l'editeur > Export > Android > *Java SDK Path* (ex. `C:\Program Files\Eclipse Adoptium\jdk-17...`).
3. **Android SDK** : installer Android Studio (developer.android.com/studio) ou les seuls "command-line tools", puis via sdkmanager : `platform-tools` (adb), `build-tools;35.0.1` (version demandee par Godot 4.7, a verifier dans la doc d'export), `platforms;android-35`, `cmdline-tools;latest`, CMake 3.10.2 et NDK seulement si build Gradle. Le chemin est deja reglé dans l'editeur : `C:\Users\const\AppData\Local\Android\Sdk` (n'existe pas encore) ; sinon corriger *Android SDK Path*.
4. **Keystore debug** : l'editeur pointe vers `%APPDATA%\Godot\keystores\debug.keystore` (absent). Un `C:\Users\const\.android\debug.keystore` existe deja : soit changer *Debug Keystore* dans les parametres de l'editeur vers ce fichier, soit en generer un avec `keytool` (JDK) dans le dossier voulu. Alias `androiddebugkey`, mot de passe `android` (valeurs standard Android debug, a saisir dans l'editeur, jamais dans le preset).

## Preset (deja pret, sans secret)
`game/export_presets.cfg`, preset `Android` : arm64-v8a seul, APK, signe, `keystore/debug*` VIDES (Godot prend ceux des parametres de l'editeur). Orientation = `project.godot` `window/handheld/orientation=4` (paysage capteur). Renderer Mobile. Immersif actif.
A faire avant publication : changer `package/unique_name` (`com.example.rainfall` = placeholder), icones launcher, keystore release (hors depot).

## Commandes (apres installation)
```
Godot_v4.7.2-stable_win64_console.exe --headless --path game --export-debug "Android" ..\build\android\Rainfall.apk
adb devices
adb install -r build\android\Rainfall.apk      (sur accord du joueur)
```
Telephone : mode developpeur + debogage USB actives.

## Risques mobile releves
- Textures : ~5,9 Go en RGBA brut (2099 PNG), dont `averse/effects/wave_cone*` 3 x 6144x8192 (192 Mo chacune brute) et `crue_ring*` 13312x1664 : depassent la taille max de texture de nombreux GPU (4096-8192) et la RAM. A redecouper/reduire en priorite, ainsi que `ardent_brasier/default*` (11520x640) et ombres 2048.
- Repartition brute : characters ~4,5 Go, bosses ~0,86 Go, vfx 0,16, ambiance 0,15. Les cartes normales `_n` et emissives `_e` triplent le cout. ASTC (deja actif) divise par ~4 a ~8 : toujours trop pour un jeu mobile sans reduction.
- Dossier `.godot/imported` 386 Mo ; APK probablement > 400 Mo : prevoir reduction (limite Play 200 Mo base, AAB obligatoire a la publication).
- **Budget textures (22/10/2026, palier 1 fait)** : outil `art/tools/texture_budget.py` (mesure par catégorie, > 4096, APK estimé ; `--apply-policy` remet les .import à la politique) + test `game/tests/texture_budget_test.tscn` ; budgets dans `game/tests/texture_budget.json`. Import VRAM haute qualité partout (BPTC sur PC = définition intacte, ASTC 4x4 sur mobile ; UI/icônes lossless ; pas de mipmaps) : mémoire GPU 5,9 Go -> 1,5 Go, textures dans l'APK 284 -> 169 Mo, APK estimé 389 -> 274 Mo (audio 67 Mo). Planches > 4096 découpées en atlases (crue_ring, puddle_mirror, ardent_brasier, ardent_nova ; originaux dans `art/renders/_presplit/`) ; wave_cone attend AV3. Ombres 2048 : `size_limit` 1024 (shader en UV monde, taille d'affichage inchangée).
- Palier 2 (cible APK <= 200 Mo : textures <= 95 Mo) = re-rendus Codex à la taille d'affichage (règle dure dans STYLE.md « OPTIMISATION ») : crue_ring 1664 -> ~800 px (rendu à 128 px/u, affiché à 0,33-0,5), puddle_mirror 768 -> ~416, wave_cone/goutte_lame 90,5 -> 64 px/u (AV3) ; couches de Tocsin (604 Mo VRAM, 46 Mo APK : cellules 192 px pour des membres qui en occupent une fraction) à rogner par couche ; inversement ardent_brasier (affiché x1,7) et ardent_nova (x1,2) sont agrandis en jeu : à re-rendre à 64 px/u (plus nets). Audio 67 Mo : à recompresser (hors périmètre textures).
- Palier qualite : mobile = Moyen par defaut, Bas si GPU d'entree de gamme detecte (`quality.gd`), mesure 5 s ensuite : OK.
- Tactile : joystick flottant, boutons sorts/interaction/pause presents. Zone sure geree (`Platform.safe_margins`, marge mini 48/32 px) : OK, non testee sur appareil.
- Non verifie : perf reelle (ombres cuites, brouillard, eclairs), permissions, `emulate_touch_from_mouse=true` dans project.godot (inoffensif sur mobile).
