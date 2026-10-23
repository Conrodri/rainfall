# I3 — Ardent, reprise des huit icônes

Huit PNG RGBA de 128 × 128 remplacés. Dimensions et rectangles alpha exacts de l'inventaire conservés, y compris l'éclat horizontal et le pilier étroit. Aucun compagnon _n/_e existant. Huit .import identiques à leurs empreintes initiales. Aucun .gd/.tscn créé ou modifié ; aucun .tres du jeu écrit par ce lot.

Choix : charbon fissuré incandescent et sillage d'étincelles pour l'attaque automatique ; couronne vide pour la nova ; plaques de cendre sur lit rougeoyant pour cendres ; embrasement large pour brasier ; trois braises orbitales ; phénix en bronze noirci à plumes incandescentes ; lance verticale torsadée pour pilier ; trois météores diagonaux. Les silhouettes répondent aux contraintes alpha héritées. Un fond de fer noir gravé assure la parenté avec I2 sans ajouter de cadre ni de barre. Les couleurs d'émission ont été abaissées et corrigées vers l'orange pour éviter le saumon sous AgX.

Géométrie Blender réelle, biseaux, charbon irrégulier, matériaux bruités, métaux metallic=1, éclairage studio I2 et HDRI empaqueté ; Eevee 24 échantillons. Pillow sert uniquement au rognage, redimensionnement, assemblage et contrôle. Source : art/blender/ui/i3_ardent.blend. Scripts : i3_build.py et i3_finish.py.

Vérifications finales : i3_report.json PASS ; i3_geometry.json PASS (8 scènes) ; sprites_test.tscn RESULT: OK ; chargement explicite des 65 .tres présents dans le projet, errors=0 (i3_resources.log). Le lanceur de contrôle est une ressource GDScript i3_verify.tres située hors du jeu, sans fichier .gd.

Concurrence : quatre ressources du jeu ont changé pendant ce lot (Ardent et VFX cendres/brasier/nova). Elles sont seulement lues ; leurs modifications externes sont listées dans i3_report.json, sans restauration. L'import Godot a rencontré une texture void_1024_n de terrain en cours d'écriture par un autre lot ; les deux vérifications finales ci-dessus passent après import.

Planche unique _i3_contact.png : ancien Ardent en haut, nouveau à 128 puis 64 px dans spell_frame.png ; références I2, Ardent, projectile V2, Rictus et terrain en dessous. L'ordre alphabétique est celui de l'inventaire. Travail terminé.
