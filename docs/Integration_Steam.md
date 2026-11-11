# Intégration Steam (GodotSteam) : succès et sauvegarde dans le cloud

Décision du joueur (11/11/2026) : sur PC, Rainfall utilise le SDK Steamworks via **GodotSteam** pour les **succès Steam** et la **sauvegarde du profil dans Steam Cloud**, **avec repli** : sans Steam (client fermé, extension absente, Android, iOS, tests headless), le jeu marche exactement comme avant, sans erreur.

Le code est prêt et testé avec un faux Steam. **Aucun binaire n'est fourni dans le dépôt** : c'est au joueur de télécharger et poser l'extension (§2-3), puis de configurer Steamworks (§5-6).

## 1. Ce qui est en place dans le code

| Élément | Fichier | Rôle |
|---|---|---|
| Interface (repli) | `game/scripts/meta/platform_services.gd` | `PlatformServices.current` ; `install(host, profile)` choisit le backend au démarrage (appelé par `App._ready`). |
| Backend Steam | `game/scripts/meta/steam/steam_services.gd` | Seul fichier qui parle à Steam. Initialise Steam, envoie les succès, porte le cloud. |
| Cloud | `game/scripts/meta/steam/steam_cloud.gd` | Copie de `user://profile.json` dans Steam Cloud (Remote Storage), règle de conflit, copies de sauvegarde. |
| Hôte | `game/scripts/meta/steam/steam_services_host.gd` | Nœud sous App : envoi au cloud (au plus toutes les 20 s après un changement, à chaque fin de run, à la fermeture) et arrêt propre de Steam. |
| Test | `game/tests/steam_services_test.tscn` (+ faux singleton `steam_fake.gd`) | Repli, traduction des ids, succès, cloud, fermeture. |

Conditions pour que Steam soit utilisé (sinon interface vide, aucun appel) :
1. PC (Windows, Linux, macOS), pas de rendu headless, pas d'argument `-- --no-steam` ;
2. extension GodotSteam chargée (`Engine.has_singleton("Steam")`) ;
3. `steamInitEx(app_id, true)` renvoie le statut 0 (client Steam lancé, compte connecté, AppID accepté).

Le code n'écrit jamais l'identifiant global `Steam` : il passe par `Engine.get_singleton("Steam")` et des appels dynamiques vérifiés (`has_method`). Le projet se charge donc avec ou sans l'extension.

En build de debug, une ligne apparaît dans la sortie quand Steam est actif : `Steam : connecté (AppID 480), cloud : …, succès envoyés : …`. Rien n'est affiché en repli.

## 2. Version de GodotSteam à installer

Vérifié le 11/11/2026 sur les publications officielles (le développement de GodotSteam a déménagé sur Codeberg ; le dépôt GitHub ne garde que des fichiers de débordement des versions « module ») :

| Publication | Date | Cible | SDK Steamworks |
|---|---|---|---|
| **GodotSteam GDExtension 4.23.2** (`v4.23.2-gde`, fichier `godotsteam-4.23.2-gdextension-plugin-4.4.zip`) | 20/10/2026 | Godot 4.4 et plus | 1.65 |
| GodotSteam GDExtension 4.24 (`v4.24-gde`, `godotsteam-4.24-gdextension-plugin-4.4.zip`) | 07/11/2026 | Godot 4.4 et plus | 1.65 |

- Page des publications : https://codeberg.org/godotsteam/godotsteam/releases (filtrer les étiquettes `-gde`). Aussi sur la boutique d'assets Godot (« GodotSteam GDExtension »), où la 4.24 est marquée instable par l'éditeur au 10/11/2026.
- **Recommandation : 4.23.2** (stable depuis trois semaines), ou 4.24 si un correctif utile y figure. Une GDExtension compilée pour Godot 4.4 se charge dans les versions 4.x plus récentes (compatibilité ascendante de l'API GDExtension), donc dans Godot 4.7.2. `compatibility_minimum = "4.4"` dans `godotsteam.gdextension`.
- Ne pas mélanger avec les versions « module » (éditeur et modèles d'export précompilés GodotSteam, ex. `win64-g472-s165-gs424-editor`) : elles remplacent l'éditeur Godot, ce n'est pas notre choix. Avec la GDExtension, on garde l'éditeur et les modèles d'export officiels de Godot 4.7.2.
- Signatures utilisées (GodotSteam 4.2x) : `steamInitEx(app_id: int = 0, embed_callbacks: bool = false) -> {status, verbal}`, `get_steam_init_result()`, `setAchievement(name) -> bool`, `storeStats() -> bool`, `isCloudEnabledForAccount()`, `isCloudEnabledForApp()`, `fileExists`, `getFileSize`, `getFileTimestamp`, `fileRead(name, size) -> {ret, buf}`, `fileWrite(name, data, size) -> bool`, `steamShutdown()`. Si une future version change l'une d'elles, `steam_services_test` (avec le faux) passera toujours : refaire alors le protocole du §8 avec le vrai Steam.

**Vérifier la compatibilité après installation** : ouvrir le projet dans Godot 4.7.2 ; la sortie ne doit afficher aucune erreur `GDExtension` ; dans un script de test ou la console de débogage, `Engine.has_singleton("Steam")` doit valoir `true`. En cas d'erreur de chargement, essayer la version précédente (`-gde`) et signaler la version qui marche.

## 3. Installation (à faire par le joueur)

1. Télécharger le zip de la version choisie (§2) depuis la page Codeberg.
2. Le décompresser hors du projet, puis copier **le dossier `addons/godotsteam/`** dans `game/addons/godotsteam/` (résultat : `game/addons/godotsteam/godotsteam.gdextension`, `win64/steam_api64.dll`, `win64/libgodotsteam.windows.template_*.x86_64.dll`, etc.).
3. Ouvrir le projet dans l'éditeur (réimport), fermer, rouvrir. Ne rien régler dans les « Paramètres du projet > Steam » : en particulier **laisser `initialize_on_startup` désactivé** et ne pas y mettre d'AppID (le code initialise Steam lui-même ; s'il est déjà initialisé, il le réutilise).
4. Le zip contient aussi un greffon d'éditeur « GodotSteam GDExtension Updater » (`plugin.cfg`) qui interroge Internet pour proposer des mises à jour. Il n'est pas nécessaire : **le laisser désactivé** (Projet > Paramètres > Greffons).
5. Lancer `steam_services_test` (§8) puis le protocole manuel.
6. Versionner : les bibliothèques pèsent environ 27 Mo pour toutes les plateformes. Garder au moins `godotsteam.gdextension`, `win64/` (et `linux64/`, `osx/` si une version Linux / macOS est prévue) ; les dossiers `win32/`, `linux32/`, `linuxarm64/`, `androidarm64/` peuvent être supprimés.

## 4. AppID

- **Debug (éditeur, export debug)** : AppID **480** (Spacewar, l'application de test de Valve), passé à `steamInitEx` par le code (`SteamServices.DEBUG_APP_ID`). Aucun fichier `steam_appid.txt` n'est nécessaire.
- **Release** : renseigner le vrai AppID réservé sur Steamworks dans `game/scripts/meta/steam/steam_services.gd`, constante `RELEASE_APP_ID` (0 aujourd'hui : l'AppID est alors fourni par le client Steam, ce qui exige de lancer le jeu depuis Steam).
- **Surcharge** : la variable d'environnement `RAINFALL_STEAM_APPID=<id>` remplace l'AppID en debug comme en release (tests sur le vrai AppID depuis l'éditeur).
- **`steam_appid.txt`** : si quelqu'un en crée un dans `game/` pour un essai, il est ignoré par git (`.gitignore`) et exclu de tous les exports (`export_presets.cfg`). Ne jamais le livrer.
- **Lancement hors de Steam** : avec un vrai AppID, l'exe lancé directement s'initialise quand même si le client Steam tourne et que le compte possède le jeu. On n'appelle pas `restartAppIfNecessary` (pas de relance forcée par Steam) : le jeu reste jouable sans Steam, en repli.

## 5. Sauvegarde dans le cloud : Auto-Cloud ou Remote Storage

| | Steam Auto-Cloud | Steam Remote Storage (retenu) |
|---|---|---|
| Code | Aucun : configuration Steamworks seule (racine `WinAppDataRoaming`, sous-dossier `Godot/app_userdata/Rainfall`, motif `profile.json`) | API GodotSteam (`steam_cloud.gd`) |
| Moment de synchro | Au lancement et à la fermeture du jeu par le client Steam | Au démarrage (après l'init) et pendant la partie |
| Conflit | Boîte de dialogue du client Steam, le joueur choisit ; la version écartée est perdue | Règle du jeu : le plus récent gagne, **l'ancien est copié** dans `user://profile_backups/` |
| Plateformes | Chemins à déclarer par OS (Windows, Linux / Steam Deck, macOS) | Identique partout (fichier distant `profile.json`) |
| Lancement hors Steam | Pas de synchro | Pas de synchro (repli) ; rattrapage au prochain lancement avec Steam |

**Recommandation : Remote Storage**, implémenté. Auto-Cloud suffirait pour un simple aller-retour, mais il ne garantit pas la règle demandée (« jamais de perte, le plus récent par horodatage, sauvegarde de l'ancien ») : en conflit, la version écartée par le joueur disparaît.

Règles du code (`SteamCloudSync`) :
- le fichier local `user://profile.json` reste la source : le jeu ne lit et n'écrit que lui ; le cloud en est une copie ;
- au démarrage : contenus identiques = rien ; un seul côté lisible = il gagne ; sinon le plus récent gagne (date de modification du fichier local contre horodatage Steam du fichier distant ; égalité = local) ;
- le perdant est toujours copié dans `user://profile_backups/profile_<date>_<local|cloud>.json` (5 copies au plus) ; un fichier corrompu n'est jamais envoyé ;
- en partie : le fichier tel qu'il est sur le disque est envoyé s'il a changé, au plus toutes les 20 s, à chaque fin de run et à la fermeture ; rien en mode test (bac à sable).
- Seul le profil est synchronisé. Restent locaux : `run_save.json` (run en cours), `settings.cfg` (réglages propres à la machine), `quality.cfg`, `run_logs/`.

**Configuration Steamworks à faire** (App Admin > Cloud) :
1. Activer Steam Cloud pour l'application.
2. « Byte quota per user » : **10 Mo** (le profil fait quelques centaines de Ko au plus, historique de 200 runs compris).
3. « Number of files allowed per user » : **4**.
4. **Ne déclarer aucun chemin Auto-Cloud** pour `profile.json` (les deux mécanismes se marcheraient dessus).
5. Publier les changements (Publish).

Dossier local du profil sous Windows : `%APPDATA%\Godot\app_userdata\Rainfall\` (nom du projet, pas de dossier utilisateur personnalisé).

## 6. Succès : configuration Steamworks

Dans App Admin > Stats & Achievements > Achievements, créer les 30 succès de `docs/Fiche_Steam.md` §9 :
- **API Name** = colonne « API name Steam » (id local de `game/data/achievements.json` en majuscules, ex. `FIRST_BLOOD`, `KILLS_10000`, `BOSS_FLOOR_4`). Le test `steam_services_test` vérifie que la table de la fiche et le JSON concordent.
- Nom affiché et description en français (et anglais si la page l'est), repris de la fiche.
- « Hidden » coché pour `WIN_CHARS_ALL` et `SECRET_ZONE`.
- Icônes 256×256 « achieved » et « unachieved » (version grisée), à produire par Codex.
- Aucune statistique (stats) n'est utilisée : les compteurs restent locaux, seuls les succès sont envoyés.
- Publier les changements.

Comportement en jeu : à chaque succès local débloqué, `setAchievement(API name)` puis `storeStats()`. À chaque démarrage avec Steam, tous les succès locaux déjà débloqués sont renvoyés (rattrapage : succès gagnés hors Steam ou avant l'installation). Un succès refusé par Steam (API name inconnue, par exemple sur Spacewar) reste en attente sans erreur. Ajouter un succès = l'ajouter dans `achievements.json`, dans la fiche §9 et dans Steamworks avec la même API name.

## 7. Exports

`export_presets.cfg` (déjà modifié) :
- **Windows Desktop** : rien à ajouter pour l'extension. L'export copie automatiquement, à côté de l'exe, la bibliothèque GodotSteam et `steam_api64.dll` (section `[dependencies]` du `.gdextension`). Exclusion ajoutée : `steam_appid.txt`.
- **Android et iOS** : exclusion ajoutée `addons/godotsteam/*` (et `steam_appid.txt`) : rien de Steam n'est livré sur mobile.

À vérifier au premier export après installation :
1. Windows : le dossier d'export contient `Rainfall.exe`, `Rainfall.pck`, `libgodotsteam.windows.template_release.x86_64.dll` et `steam_api64.dll`. Lancer l'exe sans Steam : le jeu démarre normalement (repli).
2. Android : l'APK / AAB ne contient aucun `libgodotsteam*.so` ni `libsteam_api.so` ; au lancement, aucune erreur `GDExtension` dans logcat (`adb logcat -s godot`). Si Godot signale l'extension manquante au démarrage, retirer aussi `addons/godotsteam` de la liste des extensions exportées (`res://.godot/extension_list.cfg` est régénéré par l'éditeur) et le signaler.
3. Steamworks > SteamPipe : téléverser le contenu du dossier d'export Windows (exe, pck, les deux dll) dans le dépôt Windows.

## 8. Vérification

Automatique (sans Steam) :
```
sh art/tools/vfx_test/godot_locked.sh --headless res://tests/steam_services_test.tscn   # RESULT: OK
```
Couvre : repli (aucun singleton, interface vide, aucun appel, succès locaux inchangés), API names valides et conformes à la fiche, init en échec, rattrapage, envoi via MetaTracker, attente puis reprise, cloud (envoi, identique, rapatriement du plus récent, copie de l'ancien, fichiers corrompus, bac à sable, plafond des copies), fermeture propre.

Manuel (après installation, client Steam lancé et connecté) :
1. Lancer le jeu depuis l'éditeur (debug, AppID 480) : la sortie affiche `Steam : connecté (AppID 480), cloud : pushed|same|pulled, …`. L'overlay Steam (Maj+Tab) s'ouvre en jeu.
2. Débloquer un succès (ex. tuer un monstre) : aucun message d'erreur ; sur Spacewar l'API name n'existe pas, le succès reste en attente sans erreur (normal).
3. Relancer avec `-- --no-steam` : aucune ligne Steam, le jeu marche comme avant.
4. Client Steam fermé : même résultat qu'au point 3, sans erreur.
5. Avec le vrai AppID (`RAINFALL_STEAM_APPID=<id>`, succès publiés dans Steamworks) : débloquer `first_blood`, vérifier la notification Steam et la page des succès du compte.
6. Cloud entre deux PC : jouer sur le PC A, quitter ; lancer sur le PC B : la sortie indique `cloud : pulled`, le profil (rubis, succès) est celui de A et l'ancien profil de B est dans `user://profile_backups/`.

## 9. Limites et risques

- **Conflit sans fusion** : si deux machines progressent hors ligne (sans Steam), la plus récente l'emporte au retour ; la progression de l'autre n'est plus qu'une copie dans `profile_backups/` (récupérable à la main). Une fusion champ par champ (union des succès et déblocages, maximum des compteurs) est possible plus tard.
- **Horloges** : la règle « le plus récent » se fie à l'horloge de chaque machine.
- Pas de classement Steam pour le défi du jour (`submit_daily_score` ne fait rien) ; pas de Steam Input (les manettes passent par Godot) ; pas de coop en ligne Steam (prévue avec EOS, docs/Design_Multijoueur.md).
- Avant la sortie : renseigner `RELEASE_APP_ID`, publier succès et cloud dans Steamworks, refaire le §8 sur le build de release.
