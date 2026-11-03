# VFX de sorts de TEST via pixelfx

Décision du joueur (03/11/2026) : produire avec pixelfx (plugin Claude Code) des **assets de test** pour les effets
visuels des **sorts** des personnages et des boss. Uniquement les sorts : pas d'impacts génériques, de pickups,
d'ambiance, de monstres ni de mini-boss. Ces assets **ne remplacent rien** : les VFX définitifs restent produits par
Codex dans Blender (règle absolue inchangée). Ils servent à tester le rythme, la lisibilité et le timing en jeu, et de
référence de mouvement pour les consignes Codex.

## Chaîne
- Dépôt pixelfx : `C:\Users\const\Documents\pixelfx` (Node, aucune installation). Ne pas modifier `src/`.
- Recherche : `node tools/list.mjs <mots>` ; catalogue `docs/CATALOG.md`.
- Rendu recoloré : `node tools/render.mjs <id> --no-actor --bg dark --opts '<json>' --out records_<groupe>` puis
  lire `records_<groupe>/<id>/contact.png`. Planche finale : même commande + `--sheet`.
- Conversion : `python art/tools/vfx_test/pixelfx_to_godot.py <planche.json> <owner> <spell_id> --source <id> --opts '<json>'`
  → `game/assets/sprites/vfx_test/<owner>/<spell_id>/` (`.png` x2 plus proche voisin, `.tres` SpriteFrames
  animation `default`, `.meta.json` avec fps, boucle et `offset` pour AnimatedSprite2D). Filtre de texture : nearest.

## Garder la DA du jeu
La DA officielle (art/briefs/STYLE.md) est sombre, désaturée, avec **un seul accent émissif** par personnage ou boss,
des silhouettes anguleuses et une lumière venant du haut-gauche. Pour s'en approcher avec pixelfx :
- **Palette `palette`** (6 à 8 couleurs, du sombre au clair) : 2-3 tons quasi noirs teintés vers la teinte de
  l'accent, 1-2 tons moyens désaturés, 2 tons vers l'accent (le dernier = l'accent hex exact), puis au plus un ton
  éclairci de l'accent. Pas de blanc pur, sauf un éclair d'1-2 images au cœur d'un impact lourd.
- **Lueur `light`** : 0,3 à 0,5. Plus fort délave l'image.
- **Choix d'effets** : sérieux et anguleux ; éviter le mignon (cœurs, bonbons, critters, motifs UI, confettis).
- Orientation : les effets directionnels regardent vers la droite (le jeu les tourne) ; les effets au sol sont
  posés sur y = 0.

## Périmètre et exclusions
Un asset par sort (variantes comprises). Une variante qui ne diffère visuellement en rien de son sort de base
réutilise l'asset du sort de base : à noter, pas à dupliquer. Exclus (ce sont des objets, pas des effets de sort) :
pylônes, stèles, conteneurs, couronnes, digues, cocons, jarres-objets, monstres invoqués, sprites d'armes, animations
du corps du personnage ou du boss. Les attaques de mêlée de boss (coup, cône) reçoivent une traînée ou un arc
d'impact adapté.

## Accents
Persos : ardent #FF7319 (feu) · rictus #9FC8C0 (fil, porcelaine) · tocsin #FF7A1F (foyer, cloche, vapeur) · averse
#5FD4E8 (eau) · arpenteuse #FF7A1F (chaîne de cuivre) · rainette #8DBBA8 (vase, roseaux) · avare #F2C14E (or) ·
bourbe #8DDBA8 (vase) · vigie #FF3A4F (fusée, flèches) · morfil #CDEB6E (sève, lame).
Boss : étage 1 Terrasses (eclusier, ox_herder, jar_bearer, drowned_idol) #5EC8FF · étage 2 Forêt-brume (cerf,
weaver, hermit_cedar) #9CF0C8 · étage 3 Cité rouillée (crane, smelter, flood_gunner) #FF9A3C, sonneur ambre
#FFB347 (foudre, cloche ; corps #5F8F80) · étage 4 Cryptes (recluse, crystal_mother, deep_eel, salt_king) #BFF4FF ·
boss final rain_sower #5EC8FF.

## Version lumineuse et isométrique (03/11/2026)
Demandes du joueur : sorts lumineux (halos, particules sur les traînées et aux explosions) et effets adaptés à la
caméra isométrique.
- `art/tools/vfx_test/build_lit.py` (avec `export_lit.mjs`) remplace la chaîne d'origine : pour chaque meta, il
  rend l'effet pixelfx en deux couches, `<sort>.png` (corps, recoloré sur la palette) et `<sort>_e.png` (halo
  additif, teinté sur le haut de la rampe), plus `light_curve` / `light_pos` / `light_color` dans le meta.
  Planches plafonnées à 4096 px (sinon `node_scale`). Pour changer l'effet d'un sort : modifier `source`/`opts` du
  meta puis `python build_lit.py <owner>/<sort>`.
- `game/assets/sprites/vfx_test/iso_classes.json` : projection (billboard, ground, ground_dir, projectile),
  particules (trail, burst, embers, none), `size_u` (taille gameplay), alias. La plupart des anneaux pixelfx sont
  déjà dessinés en ellipse : billboard, pas ré-écrasés.
- Lecteur `game/scripts/testmode/vfx_test_player.gd` (halo additif HDR, PointLight2D via LightRig sur la courbe,
  CPUParticles2D) et onglet « Galerie VFX » du panneau de test. Capture de revue : `game/tests/vfx_capture.tscn`.
- Limites connues : vagues de boss vues de profil (eclusier/wave, rain_sower/wave_front, salt_king/procession_tide),
  racines et chausse-trapes en rangée de profil, lignes longues (weaver/thread, arpenteuse_chaine) rendues par un
  trait court, nuages bas sans emprise au sol (le télégraphe en code la donne).
- Remplacement sur les vrais sorts (case « VFX pixelfx sur les sorts », drapeau `TestMode.vfx_test`) :
  `game/scripts/testmode/vfx_swap.gd`. L'effet d'origine est caché (il continue de tourner pour garder durées et
  fins de zone) et un VfxTestPlayer le suit. Clé : meta `vfx_key` > `<perso>/<id du sort>` > tables PATHS /
  BOSS_ANIMS > `<boss>/<anim>`. Accroches d'une ligne commentées « mode test » (`grep VfxSwap`) : emissive_overlay,
  zone_effect, projectile, spell_caster, boss_pace, quelques kits et cerveaux. 143 sorts sur 152 branchés ; non
  branchés : ardent/roaming_embers, chaînes de l'Arpenteuse, projectiles du Flood Gunner, charges sans anim
  d'origine. Bulles de test et masquage du HUD : `test_bubbles.gd`, `test_hud_hider.gd`, `test_boss_adapter.gd`.
