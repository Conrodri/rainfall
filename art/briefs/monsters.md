# Brief monstres (tiers 2-3, auras d'elite, mini-boss)

Respecter art/briefs/STYLE.md (camera ortho elevation 35 deg (ex-55, voir bloc en fin de fichier), Sun haut-gauche #FFE2C0, fill froid, rim froid #9FB8D8, Standard view transform, film transparent, pas d'ombre au sol, rendu 2x puis LANCZOS, pivot au sol a 70 % de la hauteur, marges >= 4 px). Reprendre le setup de scene de art/tools/ardent_build.py (lumieres, camera, shift_y pour le pivot, materiaux avec faible emission diffuse 0.32).
Direction: le modele regarde vers -Y local; rotation Z = radians(90 - 45*index) avec DIRS = e,se,s,sw,w,nw,n,ne. 8 frames par animation, boucles propres.
Monstres plus sourds que le joueur : saturation basse, yeux/accents rouges (#D8342A, legerement emissifs). Silhouette lisible a petite taille sur sol #2B3340.

## Identification par tier
- T1 essaim (autre agent) : petit 96 px, vert-gris #5B6B4F, rond.
- T2 tireur ~112 px : mince, haut, violet fane #5A4A63, capuche pointue, bras long tenant un arc/orbe, accents rouges.
- T2 bondisseur ~112 px : bas, trapu, quadrupede/felin, brun-gris #6A5A4A, plus large que haut, dos epineux, pattes arriere puissantes.
- T3 brute ~160 px : tres large, massif, ardoise #5E7390 / gris #4A5565, epaules enormes, gros poing/masse, petite tete, yeux rouges.
- Mini-boss ~256 px : Colosse de pierre (golem gris #7C8898 fissure, veines orange faibles), Reine des ronces (silhouette feminine, robe de ronces vert sombre #3F5A3A + fleurs violettes + lueur poison verte), Seigneur des cendres (armure noire #2B3340, cape en lambeaux, flammes #FF7A1F au torse/casque).
- Si docs/Design_Boss_Cartes.md existe, aligner silhouettes/themes dessus.

## Animations
- tireur: run (8f, 14 fps), attack (8f, 12 fps, noloop : armement puis tir, le tir au frame ~5). Dirs: 8.
- bondisseur: run (8f), charge (8f, noloop: 0-3 pose telegraphiee accroupie/recul, 4-7 elan en avant). Dirs: 8.
- brute: run (8f), attack (8f noloop, coup en cone, impact frame 5), cast (8f noloop, poing au sol, onde de choc). Dirs: 8.
- auras: 3 variantes (burn orange, slow bleu, poison vert), anneau/flammes/volutes autour du pied, boucle 8 frames, 160 px, fond transparent, rendu additif (couleurs vives sur alpha, le jeu applique CanvasItemMaterial add). Non directionnel.
- mini-boss: idle, run, attack, cast, death (death noloop), 8 frames chacun, direction unique s (miroir horizontal cote Godot pour e/w, sinon ok), 256 px.

## Conventions
Scripts : art/tools/monsters/. Sources : art/blender/monsters/<nom>.blend. Rendus : art/renders/monsters/<nom>/<anim>/<dir>_<ff>.png (dir 'x' si non directionnel ; mini-boss : 's').
Packaging : pack.py existant ne sait ecrire que sous game/assets/sprites/<cat>/<nom>; utiliser art/tools/monsters/pack_monsters.py (copie adaptee, lit art/renders/monsters/<nom>/, ecrit game/assets/sprites/monsters/<nom>/ ou bosses/<nom>/ ou fx/elites/<nom>/). SpriteFrames <nom>.tres avec animations <anim>_<dir>.
Blender : UNIQUEMENT en arriere-plan ("C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python script.py). Ne jamais toucher la fenetre Blender interactive ni PeakSurvivor.

## Regle absolue
Tout (monstres, auras, mini-boss, effets) est modelise, anime et rendu dans Blender (arriere-plan). Aucun sprite/effet dessine ou genere avec PIL/Python/numpy, aucun telechargement. Python hors Blender = uniquement assembler/rogner/redimensionner des rendus Blender (pack_monsters.py). Les auras sont des meshes/particules/emissions rendus par Blender (materiaux emissifs, fond transparent).

## MISE A JOUR (docs/Design_Boss_Cartes.md prime sur ce qui precede en cas de conflit)
- Palette monstres : froids ou acides mais CLAIRS (L* >= 60 pour les surfaces principales), contour sombre ~2 px (#1a1620 teinte), turquoise / violet / vert-jaune; toujours moins satures et moins chauds que le joueur (braise orange). Tireur : violet clair (~#8E7BA8), bondisseur : turquoise-gris clair (~#6FA8A0), brute : ardoise clair (~#8DA2B8) avec accents rouille. Les sols restent sombres (#2B3340).
- Mini-boss : sprites 170 px (rendu 340). Jeu d'animations (5.2) : idle 6f, run 8f en 4 directions (e, s, w, n ; diagonales = plus proche), attack 6f (prepa 0,5 s lisible : membre en arriere), cast_a 8f, cast_b 8f, phase2 8f (noloop, transition 1 s), death 10f (noloop). Seul run est a 4 directions; les autres animations sont en direction unique s (SpriteFrames nommes idle_s, attack_s, cast_a_s, cast_b_s, phase2_s, death_s ; run_e, run_s, run_w, run_n).
- 6 mini-boss, ordre : Colosse de pierre (2,5 u, bloc trapu, fissures orange), Ours de givre (quadrupede long 2,6 u, stalactites bleu pale sur le dos), Archonte rouille (2,8 u, armure creuse flottante, heaume fendu cyan, hallebarde 2x le corps), Reine des ronces (2,2 u, elancee vert-noir, couronne de ronces claire, traine de racines), Essaim-mere (2,4 u, abdomen bulbeux translucide jaune-vert lumineux, 6 pattes fines, ailes), Seigneur des cendres (2,3 u, cape en lambeaux fumante, coeur-braise dans la cage thoracique). Noms de dossier : stone_colossus, frost_bear, rust_archon, bramble_queen, brood_mother, ash_lord.
- cast_a / cast_b : Colosse A = charge (pose penchee, elan), B = onde de choc (poings au sol); Ours A = souffle (tete en avant, immobile), B = rugissement/stalactites (leve la tete); Archonte A = jugement (hallebarde pointee), B = chaines (hallebarde plantee, bras ecartes); Reine A = mares (bras vers le bas), B = appel (bras leves); Essaim-mere A = ponte (abdomen vers le sol), B = nuee (ailes ouvertes, abdomen leve); Seigneur A = meteores (bras vers le ciel), B = mur de flammes (bras tendus devant, paumes).
- Boss d'etage : hors perimetre.

## Normal maps et masques d'emission (OBLIGATOIRE, regle CLAUDE.md)
Pour chaque frame rendue <dir>_<ff>.png, produire dans Blender (memes cadrage/resolution/alpha) :
- <dir>_<ff>_n.png : normal map en ESPACE ECRAN (RGB = n*0.5+0.5, X droite, Y haut, Z vers camera ; alpha = alpha du diffus). Passe Normal d'Eevee (espace camera) via compositor/File Output, ou rendu avec materiau normal-geometry ; sans lissage qui melange les normales avec le fond (pas d'antialiasing de bord incorrect : fond (128,128,255) alpha 0).
- <dir>_<ff>_e.png : masque d'emission (blanc/couleur emissive sur parties lumineuses : yeux, braises, runes, flammes, fissures ; noir ailleurs ; alpha identique) rendu par Blender (passe Emit ou rendu avec materiaux non emissifs remplaces par noir).
Le pack_monsters.py doit emballer en parallele <anim>.png, <anim>_n.png, <anim>_e.png (memes decoupes), le .tres ne reference que le diffus. Pour les auras : seulement _e inutile ; elles sont additives (diffus seul + _n non requis).
Ces maps ne sont jamais dessinees hors Blender (python/PIL = seulement recadrer/assembler).


## MISE A JOUR 21/10/2026 - camera 35 deg (interim Claude, a reprendre par Codex)
- Camera ortho a 35 deg au-dessus de l'horizon (cam.location = cible(0,0,.65) + (0, -4*cos35, 4*sin35), regard vers la cible) au lieu de 55 : visage, torse et jambes visibles. Lumieres (Sun haut-gauche), tailles de cadre, nombre de frames, noms de fichiers, _n/_e et .tres inchanges.
- Tete agrandie : shooter x1.3, bondisseur x1.3, brute x1.4 (objets de tete, pivot au cou) ; essaim inchange. Mini-boss : meme camera 35 deg, geometrie inchangee.
- Scripts : art/tools/monsters/lowcam_monster.py (swarm_tier1, shooter_tier2, leaper_tier2, brute_tier3 ; `blender --background --python lowcam_monster.py -- <nom>`, lot : run_base.sh), lowcam_boss.py (mini-boss, lot : run_bosses.sh), packaging pack_monsters.py / art/tools/characters/pack.py (RENDER_SUB=monsters pour le swarm). Ardent : art/tools/characters/ardent_lowcam.py (ELEV=35, HEAD_K=1.25) + pack.py (RENDER_SUB=characters), sources art/blender/characters/ardent.blend.
- Rendus : art/renders/monsters/<nom>/..., art/renders/characters/ardent/... Eevee 16 echantillons, une seule instance Blender a la fois.
