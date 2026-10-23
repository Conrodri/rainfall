# Brief icônes et UI (Rainfall)

Règles : voir STYLE.md. Chaque icône = un petit objet 3D modélisé dans Blender (primitives, bevel, courbes, booleans), rendu Eevee, fond transparent, Standard, caméra orthographique 3/4 de face (objet légèrement vu de dessus, ~25-30° d'élévation pour les icônes, objet debout face caméra), Sun haut-gauche #FFE2C0 + fill froid #8FA8C8, pas de plan d'ombre. Contour sombre #1a1620 1-2 px. Rendu 512 px puis réduit à 256 (Pillow LANCZOS autorisé pour réduire/rogner seulement). Marges 12 px, objet centré, silhouette lisible à 64 px (formes grosses, peu de détails fins, couleurs contrastées). Palette STYLE.md. Pas de texte dans les icônes.
Emissive braise (#FF7A1F/#FFB347) pour feu/lumière ; bleu cyan #5FD4E8 pour givre/foudre/temps ; vert toxique #7FA35B pour poison ; or #F2C14E ; violet #8A6AB0 pour arcane.

## Objets des items (id : objet 3D)
lentille_aiguisee: loupe/lentille de verre biseautée dans monture de laiton, reflet
sablier_fele: sablier de bois avec sable cyan et fissure sur le verre
antidote: petite fiole ronde verte à bouchon de liège, croix claire
botte_rapiecee: botte de cuir avec pièces cousues et lacet
pierre_a_aiguiser: pierre à aiguiser grise plate avec une lame qui l'effleure, étincelle
bague_de_vigueur: anneau d'or avec gemme rouge (rubis) 
amulette_de_cuir: pendentif cuir avec cordon et disque de cuir clouté
aimant_de_poche: aimant en fer à cheval rouge/argent avec 2 pièces d'or collées
sifflet_de_chasse: sifflet d'os/laiton avec cordelette
etincelle: petite flamme/étincelle orange rayonnante sur une pierre
flocon: flocon de neige cristal bleu cyan 6 branches (3D épais)
fiole_verte: fiole en goutte pleine d'un liquide vert vif, bulles
pavois_fele: bouclier rond de bois renforcé de fer avec une fissure
coeur_de_mousse: cœur de pierre recouvert de mousse verte
piece_porte_bonheur: grosse pièce d'or avec trèfle gravé
eclat_d_experience: éclat de cristal cyan facetté lumineux
plume_d_empenne: plume d'empennage de flèche grise/ardoise avec tige
cristal_de_feu: cristal rouge-orange facetté avec cœur incandescent
givre: cristal de glace bleu pâle pointu, givre
horloge_arcanique: horloge ronde de laiton à runes violettes, aiguilles
lame_jumelle: deux dagues croisées en X
venin_concentre: flacon à bec rempli de poison vert + goutte
cape_de_brume: cape/manteau gris-bleu à capuche flottant, bas effiloché
epines: branche/boule d'épines acérées sombres
eclair_en_bouteille: bouteille de verre contenant un éclair cyan
rune_de_portee: pierre plate gravée d'une rune en cercle concentrique lumineuse
morsure_vorace: mâchoire/croc de monstre avec gouttes de sang
tonique_vital: flacon rouge large étiquette croix, bouchon
orbe_de_veille: orbe de verre lumineux sur un petit socle, œil/lueur
sang_chaud: goutte de sang rouge profond avec lueur orange
marque_du_chasseur: cible/croix de viseur en métal sur une planchette, ou crâne de cerf avec marque
carquois_affute: carquois de cuir avec flèches
pointe_perforante: pointe de flèche en acier longue avec traînée
aimant_d_ame: aimant fer à cheval violet/cyan avec fantômes d'âme (volutes cyan)
chronometre_brise: chronomètre de poche à boîtier brisé, verre cassé, rouages
tempete_de_braises: tourbillon de braises, bol de fer avec braises en spirale
coeur_de_glace: cœur de glace bleu translucide avec stalactites
peste_vivante: crâne/bouteille ou sphère verte avec nuage toxique
oeil_du_predateur: gros œil de prédateur à pupille fendue, orangé, dans un cabochon
bouclier_reactif: écu hexagonal arcanique cyan avec 2 gemmes (charges)
faveur_du_marchand: bourse de cuir pleine avec pièces d'or débordantes, sceau
danseur: paire de bottes/escarpin ailé élégant avec aile
phenix_de_poche: petit phénix de braise (oiseau flamboyant) sur un médaillon
rafale_d_acier: gerbe de 3 flèches/carreaux d'acier en éventail
coeur_du_chronomancien: cœur cristal doré entouré d'engrenages et anneau temporel, cyan/or
couronne_d_echo: couronne d'or avec trois copies fantômes décalées
nova_infinie: étoile/sphère de nova avec anneaux rouge-orange, cyan, vert
armure_du_colosse: plastron massif/épaulière de plate d'acier ardoise
moisson: faucille et gerbe de blé d'or
de_pipe: dé à six faces d'ivoire/or avec points, légèrement truqué (lueur dorée)

## Cadres de rareté (4 PNG, 256x256, carré à coins arrondis, intérieur transparent)
commun gris #7C8898, peu commun vert #5FA85B, rare violet #8A5FD0, légendaire doré #F2C14E avec lueur. Cadre métal/pierre biseauté 3D.

## Sorts Ardent
A: eclat_de_braise (boule de feu pointue), nova_ardente (anneau de flammes), cendres (tas de cendres fumantes braise), brasier (grand feu).
B: braises_errantes (3 orbes de braise en orbite), pilier_de_flamme (colonne de feu), pluie_de_meteores (3 météores en chute), phenix (phénix de flammes aile déployée).

## Icône de critique (crit_icon.png) — intérim Claude, à refaire par Codex à l'identique
- Sortie : game/assets/sprites/ui/crit_icon.png, 128x128 RGBA, fond transparent, SANS normal map (UI non éclairée). Affichée à 40 px à gauche des chiffres de dégâts critiques (scripts/fx/damage_numbers.gd).
- Design : étoile d'impact à 8 branches anguleuses, rouge-orangé vif #FF5230, cœur jaune chaud #FFC940 (étoile à 8 pointes plus petite, tournée de 22,5°), « ! » blanc épais en relief au centre (barre trapézoïdale + point carré), contour sombre #2A0C08 (étoile agrandie derrière + « ! » élargi) pour la lisibilité sur tous les sols. Biseaux légers.
- Rendu : caméra orthographique vue de dessus, matériaux à forte émission (quasi non éclairés), Standard, Eevee 32 échantillons, 512 px puis réduit à 128.
- Source : art/tools/ui/crit_icon.py ; .blend : art/blender/ui/crit_icon.blend. Doit rester lisible à 40 px.
