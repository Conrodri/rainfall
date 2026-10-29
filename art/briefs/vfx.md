# Rainfall - Brief VFX (effets visuels)

Regles : tout est simule/modelise/rendu DANS Blender (Eevee ou Cycles, film transparent, Standard view transform), en arriere-plan uniquement :
`"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python art/tools/vfx/<script>.py`.
JAMAIS la fenetre interactive (reservee a un autre agent). Pas de PIL pour dessiner ; PIL/Python seulement pour assembler et rogner (art/tools/vfx/pack_vfx.py).
Sources .blend : art/blender/vfx/ ; rendus bruts : art/renders/vfx/<nom>/<anim>/x_<frame:02d>.png ; sortie : game/assets/sprites/vfx/<nom>/<anim>.png (une ligne, N colonnes) + <nom>.tres (SpriteFrames texte, AtlasTexture, loop selon effet).

## Rendu
- Camera orthographique, meme angle que STYLE.md (elevation 55 deg) pour les effets au sol (zones, anneaux, telegraphes) : le disque au sol apparait en ellipse (hauteur ~ 0.82 x largeur). Pour projectiles/impacts/statuts : memes camera et angle.
- Fond transparent. Effets lumineux (feu, foudre, lueurs) : emission forte sur noir -> prevus pour BLEND ADDITIF dans Godot ; RGB vif, alpha = intensite (alpha premultiplie propre, pas de halo sombre). Les telegraphes rouges (non additifs) ont un alpha reel semi-opaque.
- Palette : feu #FF7A1F, #FFB347, #C23B12, coeur #FFE9A8 ; poison vert #7FD65A/#3E8F3A ; givre cyan-bleu #8FD8F0/#5E7390 ; foudre blanc-bleu #CFE8FF/#7AB8FF ; telegraphe rouge #D83A2A ; coffres : blanc #FFFFFF, vert #6FE08A, violet #B06CFF, dore #F2C14E.
- Les boucles doivent etre parfaites (derniere frame -> premiere sans saut) : animer avec des fonctions periodiques / simulation bouclee, pas une simulation lineaire coupee.
- Rendre a 2x, reduire LANCZOS a la taille finale (dans pack_vfx.py). Marges transparentes >= 4 px.
- Utiliser vraiment des particules/simulations/shaders Blender (systemes de particules, Geometry Nodes, textures bruit/Voronoi animees, volumes ou meshes emissifs) pour que ce ne soit pas des formes plates.

## Niveau de detail (exigence joueur : VFX tres detailles, ambiance lumineuse marquee)
- Couches multiples par effet : coeur lumineux, flammes, fumee, etincelles/braises. Utiliser Mantaflow (fumee+feu) et systemes de particules Blender quand pertinent (bake en background OK) ; sinon volumes/GN/bruits animes.
- Masque d'emission : pour chaque sprite lumineux, un fichier jumeau `<fichier>_e.png` (meme taille, uniquement les couches emissives, fond transparent), rendu par Blender (passe emission ou rendu des seules couches emissives).
- Gros sorts : Nova 12-16 frames, Brasier 16-20 frames.
- Particules reutilisables pour Godot : game/assets/sprites/vfx/particles/<type>_<NN>.png (+ _e.png), 32-64 px, 4-6 variantes par type : spark, ember, smoke, fire_drop, frost_flake, poison_bubble, arc_fragment. Rendues dans Blender (une planche par type si besoin).

## Esquives (lot `art/tools/vfx/_dodge_vfx.txt`, Codex, 29/10/2026 ; docs/Design_Esquives.md)
- `game/assets/sprites/vfx/dodge_blink/` : `dodge_blink.tres`, anims `out` (silhouette qui s'eparpille en braises) et `in` (anneau de braises qui se rassemble), 6 frames chacune, 128x128 px, 18 fps, sans boucle, palette braise, masques `_e`. Joue aux deux bouts de l'Eclat d'Ardent (BlinkDodge).
- `game/assets/sprites/vfx/dodge_slide/` : `dodge_slide.tres`, anim `splash` (gerbe d'eau cyan #5FD4E8 versee au sol), 6 frames, 128x96 px, 18 fps, sans boucle ; tuile `slide_wake.png` 64x32 px (+ `slide_wake_e.png` 32x16) repetable horizontalement, film d'eau au sol vu de dessus (Line2D texturee de la Glissade d'Averse).
- Reutilises sans nouveau rendu : `ember_shard_impact` (repli de l'Eclat), `characters/bourbe/mud_splash` (trainee de la Coulee), `TocsinSteamFx` (Vapeur, placeholder du lot TOCV), fantomes du sprite (Vigie rouge #FF3A4F, Avare or #F2C14E).
