# C7E — Sonneur

Corps C7c conservé exactement : 23 627 polygones, hiérarchie et poses du générateur C7c, caméra CREA 30°, échelle orthographique 5,3, pivot (128 ; 166,4), cellules 256 px. Les 240 frames du corps sont re-rendues en Eevee, 16 échantillons, résolution double puis réduction Lanczos. Source actualisée : `art/blender/monsters/sonneur_iso.blend` ; recette : `art/tools/night/c7e_build.py`.

Choix DA : remonter l'albédo des fontes et de la patine plutôt que leur ajouter un éclairage uniforme ; garder les cavités et les pieds sombres. Fer usé plus réfléchissant, laiton pâle, liseré froid haut-gauche ; ambre unique sur le foyer, les rivets antérieurs et les joints de la cloche. Aucun ajout géométrique au corps. Moyennes des pixels opaques P1 : 37,3 → 98,5/255, mesurées sur le diffus seul, sans BODY_GAIN. Les valeurs des trois phases sont dans `_c7e_verify.json`.

Compléments, dans l'ordre demandé :

- `glas_wave` : 8 × 256 px, anneaux fins fracturés concentriques, expansion et extinction, non bouclé, 10 fps ; atlas 2048 × 256.
- `lightning` : 4 × 128 × 768 px, 756 px utiles contre 131 auparavant, ramifications anguleuses, cœur blanc-ambre placé devant la couronne ambre ; marge alpha inférieure 5 px. Correction de la vraie cause C7c : `sensor_fit=HORIZONTAL` exige une échelle orthographique de largeur 2 u pour une cellule de hauteur 12 u, et non 12 u.
- `steam_jet` : 8 × 384 × 64 px, origine à gauche, vapeur sale gris-brun au ras du sol, boucle 12 fps ; atlas 3072 × 64. Émission réellement noire, dithering de sortie désactivé pour éviter les valeurs parasites 1–2/255.
- `bolt` : 6 × 64 px, boulon hexagonal en laiton patiné, filet visible, traînée dans les frames 1 et 4. Atlas 384 × 64.

57 PNG existants remplacés, 6 nouveaux PNG ; 75 PNG au total, avec `_n` et `_e` alignés exactement sur chaque diffus. Les 38 animations existantes et leurs paramètres sont conservés ; ajout de `glas_wave` et `steam_jet` seulement. Dans `sonneur.tres`, seules les 6 régions du boulon passent de 32 à 64 px, en plus des deux animations nouvelles. Plus grande planche du lot : 3072 px.

La planche `_c7e_contact.png` compare en première ligne avant/après P1, P2 et P3 sur le vrai sol F3 ; seconde ligne quatre directions, normale et émission ; ensuite onde, anciens/nouveaux boulons, quatre nouveaux éclairs et ancien éclair, puis vapeur. Références validées F3, Ardent, Rictus et terrain assemblées en bas. Pillow sert uniquement à assembler, redimensionner et inspecter.

Contrôles pixels, grilles, mouvements, dimensions, alpha partagé, régions existantes et nouvelles animations : PASS (`c7e_verify.py`). Résultats Godot et budget : voir `_c7e_godot_sonneur.log`, `_c7e_godot_sprites.log`, `_c7e_godot_budget.log`, `_c7e_budget.log`.

Godot demandé : `sonneur_boss_test.tscn` → **RESULT: OK** ; `sprites_test.tscn` → **RESULT: OK**. Le premier log contient aussi un message moteur `Cannot blit_rect in compressed image formats` et un avertissement de fuite de deux ObjectDB à la fermeture ; ils n'empêchent pas la réussite des assertions du scénario.

Le contrôle global ne trouve aucune texture dépassant 4096 px. Il signale des problèmes hors Sonneur déjà présents au premier contrôle : catégorie `monsters`, imports UI `resource_gauge`, total textures mobiles et APK. Aucun asset hors périmètre n'a été corrigé pour masquer ces résultats.

Dernière mesure globale : `bosses` 56,3/45 Mo, `monsters` 16,1/12 Mo, mobile 234/180 Mo, APK 342/200 Mo ; 8 imports UI hors politique. Le nombre de textures boss est passé de 494 à 626 pendant le travail, alors que ce lot ajoute seulement 6 PNG : d'autres assets ont évolué en parallèle hors périmètre. Le Sonneur complet représente **6,75 Mo mobiles ASTC** (75 PNG) ; même son retrait total ne ferait pas passer la catégorie boss sous 45 Mo. Le scénario supplémentaire `texture_budget_test.tscn` donne **RESULT: FAIL (2)** : lecture des paramètres d'import avec `\r` final sous Windows et plafond global mobile. Il valide néanmoins les dimensions, les passes et toutes les régions d'atlas.

Aucun son, `.gd` ou `.tscn` modifié. Les compensations existantes du code (BODY_GAIN, étirement de la colonne et taille du projectile) restent présentes conformément au contrat ; ce lot livre les assets corrigés, leur suppression relève de l'intégration du code. Les deux nouvelles animations sont disponibles dans le SpriteFrames, sans modification de l'IA.
