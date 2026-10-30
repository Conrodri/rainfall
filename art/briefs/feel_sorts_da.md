# DA des lancements de sorts : lisibilité et poids (Arpenteuse, Ardent, Averse)

Demande du joueur (30/10/2026) : lancements de sorts très visibles, gestes grands et imposants, coup qui part vite, récupération plus longue, effets satisfaisants et impactants, fini les zones géométriques plates (cônes, demi-cercles, disques) : la forme de la zone doit se lire dans l'effet lui-même. Cadrage détaillé : `docs/Design_Feel_Sorts.md` §2 et §9.

## Règles d'animation de personnage (planches 8 directions)
1. Anticipation courte et exagérée : le corps sort de la silhouette d'`idle` d'au moins 25 % (sorts 2-3) ou 35 % (ultime) : bras levés ou écartés, cape ou manteau soulevé, buste cambré, arme ou outil brandi.
2. Une frame de smear (flou de mouvement : membre et objet étirés en arc, 2 à 3 images fantômes translucides) juste avant l'impact, jamais sur l'auto.
3. Frame d'impact tenue : pose nette, la plus grande de l'anim (extension maximale, poids sur la jambe d'appui), accent émissif `_e` doublé pendant l'impact.
4. Récupération lisible : retour en 2-3 frames vers une pose proche de `idle`/`run` (la dernière frame ressemble à une pose de course).
5. Mêmes noms de fichiers, mêmes cellules (192 px pour Ardent et Arpenteuse ; Averse : cellule existante), 8 directions. L'indice de la frame d'impact ne change pas (le code le lit). Le nombre de frames peut augmenter si indiqué ; planche <= 4096 px.
6. Durées : le .tres porte une `duration` par frame ; un SpriteFrames lit `duration / speed` secondes. Pour une frame de `n` images à 60 Hz : `duration = n * speed / 60`. Les tableaux `F60` des consignes donnent n par frame.

## Règles d'effets (VFX)
1. La forme de la zone vient du rendu (Blender, géométrie réelle : vagues, langues de flamme, éclats, fissures, braises, brume), pas d'un disque ou d'un cône plat. Silhouette irrégulière, dentelée, volumétrique ; hauteur visible (la caméra est isométrique 2:1, élévation 30°).
2. L'empreinte au sol (z=0) garde le rayon déclaré par le kit (`radius_px`, `floor_aspect`) : le code met l'effet à l'échelle de la zone de jeu. On peut dépasser en hauteur et en débris, pas en rayon.
3. Une frame de départ très lisible (explosion, claquement) puis une queue qui s'éteint ; accent émissif (`_e`) fort ; palette du personnage (Arpenteuse cuivre chauffé #FF7A1F sur acier sombre ; Ardent braise/orange sur cendre ; Averse cyan froid et eau sombre avec écume claire).
4. Cel-shadé (art/briefs/STYLE_cel.md), aucun `_n.png`, PNG optimisés. Budget textures : ne pas grossir (mêmes dimensions ou plus petit, moins de frames inutiles).
5. Mêmes noms de fichiers et de dossiers que l'existant ; le code ne doit rien avoir à changer.
