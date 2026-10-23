# N2A — forêt de brume

Trois créatures originales, construites et animées sous Blender 5.2 en arrière-plan, Eevee 16 échantillons, rendu 340 puis réduction 170 px. Aucun fichier .gd/.tscn écrit. Les trois dossiers n'existaient pas au démarrage ; création des SpriteFrames nécessaire.

Choix DA : alpha maigre au garrot haut, cage thoracique et tendons lisibles, museau effilé, oreilles déchirées, pelage gris-lichen mouillé en mèches asymétriques ; le louveteau conserve une anatomie canine sobre à 60 % de l'échelle. Chouette aux rémiges séparées et abîmées, masque facial anguleux en os patiné, orbites creusées et fines cages vert-de-gris devant des yeux en fentes obliques ; tête réduite et thorax renforcé après contrôle de la planche. Un seul accent vert lanterne #9CF0C8, commun à la forêt ; matériaux procéduraux Ash Lord, AO et ombres internes intégrées, aucune ombre au sol ajoutée.

Morsure : recul puis coup à l'index 3/6. Bond : préparation basse puis détente à 4/8. Évanouissement : silhouette rabattue dans la brume avant réapparition à 4/8. Phase 2 : hurlement tête levée. Chouette : serres projetées en piqué à 3/6, cri ailes écartées à 4/8, semis de trois follets à 4/8 et cinq en phase 2. La téléportation, les projectiles et les effets de gameplay restent pilotés par le jeu.

Contrat : cellule 170, caméra orthographique R9 4.051028251647949, élévation 30°, shift_y 0.2, pivot sol (85,119) ; mêmes comptes de frames et vitesses C5/R9. Idle et run seuls bouclent. Run : e/s/w/n ; attack/cast : sud dans la planche historique, e/w/n dans *_dirs. Cub : idle/run/attack/death. Diffus/_n/_e strictement co-découpés. Import mobile repris de texture_budget.expected_params uniquement pour ces trois dossiers.

Reproduction : Blender --background --python art/tools/night/n2a_build.py -- --resume ; puis python art/tools/night/n2a_build.py --pack. --only <id> limite la reconstruction à une créature ; omettre --resume pour refaire les rendus après modification.

Planche : lecture par paires de groupes, gauche puis droite, de haut en bas ; créatures dans l'ordre alpha, louveteau, chouette. Groupes : idle ; run e (0/2/4) ; attack s/e/w/n (armement 2, impact 3, retour 5) ; pour les adultes cast_a et cast_b (3/4/7), phase2 (4) ; death (0/5/9). Références Ardent/Rictus/terrain assemblées en bas, sans dessin Pillow.

Vérifications terminées : 360 frames, 48 animations, 75 PNG diffus/n/e ; grilles identiques, poses distinctes, émission présente, marges minimales alpha 8 px / cub 26 px / chouette 21 px. Aucun atlas N2A au-delà de 1360 × 680. Import mobile conforme sur 75/75 textures (BPTC/ASTC, sans mipmaps). Les trois SpriteFrames sont chargés individuellement par Godot sans erreur, traces « Completed load for » dans _n2a_load_<id>.log. Test demandé sprites_test.tscn : RESULT: OK. Sauvegardes Blender intermédiaires .blend1 supprimées, trois sources finales conservées.

Limite globale hors périmètre : texture_budget.py signale encore les trois wave_cone{,_n,_e}.png d'Averse en 6144 × 8192 (lot AV3). Son dernier relevé indique 208 Mo de textures mobiles / 180 Mo et APK estimé 314 Mo / 200 Mo ; texture_budget_test.tscn : RESULT: FAIL (1), textures mobiles globales. Ces dépassements concernent l'ensemble du projet et nécessitent les autres lots ; aucun de ces fichiers n'a été modifié. N2A est intégralement terminé ; aucune reprise N2A en attente.
