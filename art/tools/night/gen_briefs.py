# Génère les consignes Codex de la file de nuit (art/tools/night/_<id>.txt).
import os

D = 'art/tools/night/'
G = '"C:\\Users\\const\\Downloads\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64_console.exe" --headless --path game res://tests/sprites_test.tscn'
DA = ("DA OBLIGATOIRE : art/briefs/STYLE.md en tête + STYLE_boss_da.md ; références validées : Ardent art/tools/iso/_c4_contact.png, "
      "Rictus art/tools/characters/_m2_contact.png, ash_lord_build.py, terrain art/tools/iso/_c1_contact.png. PBR usé, palette sombre "
      "désaturée, un accent émissif, réaliste et malsain par la forme et la matière, jamais cartoon. Le joueur dort : aucune validation "
      "possible, prends les décisions de design toi-même dans l'esprit de la DA et SURPRENDS par la qualité ; note tes choix dans le rapport.")
FOOT = ("\nVérification : {G} -> RESULT: OK, chargement de chaque .tres sans erreur ; planche de contrôle art/tools/night/_{id}_contact.png. "
        "Aucun .gd/.tscn ; des agents Claude codent en parallèle et d'autres lots Codex tournent : reste dans ton périmètre. "
        "Si le quota manque, arrête-toi après une étape complète et écris où reprendre dans le rapport. Rapport final court en français.")
CHAR = ("Format des personnages jouables : exactement comme game/assets/sprites/characters/ardent/ et rictus/ (planches <anim>.png + _n + _e, "
        "cellule 192, 8 directions e, se, s, sw, w, nw, n, ne en lignes, frames en colonnes, SpriteFrames <id>.tres avec animations "
        "<anim>_<dir>, CanvasTexture diffuse+normal), rig CREA art/tools/iso/iso_rig.py (élévation 30°, R = 90,51 px/u), même pivot des "
        "pieds qu'Ardent. Inclure en plus des anims de la fiche : attack_<dir> (auto, impact frame N/2), cast_<dir>, cast_ult_<dir>, death_<dir>. ")


ICONS = ("ICÔNES DE SORTS (exigence joueur) : chaque icône 128 px (+ tailles existantes si le dossier en a) suit art/tools/ui/_i_common.txt à la lettre "
         "(vraie géométrie biseautée, PBR réaliste, métaux vraiment métalliques, éclairage studio commun, saturation basse à moyenne, jamais pastel "
         "ni crayeux, pas de barre ni de cadre parasite) et la même famille que les icônes validées art/tools/ui/_i2_contact.png : un emblème "
         "lisible du sort sur fond sombre gravé, l'accent émissif du personnage. Planche des icônes du personnage dans leur medaillon "
         "spell_frame.png à 64 et 128 px, à côté des icônes d'Ardent. ")


def w(id, txt):
    with open(D + '_' + id + '.txt', 'w', encoding='utf-8') as f:
        icons = ICONS if 'icône' in txt else ''
        f.write(txt + "\n" + icons + DA + FOOT.format(G=G, id=id) + "\n")


def charlot(id, name, sec, what):
    low = name.lower()
    w(id, f"LOT {id.upper()} : personnage jouable « {name} » (docs/Design_Personnages.md {sec} : lis la fiche entière, surtout Aspect et "
          f"Animations). Base : le chara design art/blender/characters/cd_{low}.blend et art/tools/characters/_cd_{low}.png s'ils existent "
          f"(sinon modèle neuf selon la fiche). {what}\n" + CHAR +
          f"Sorties : game/assets/sprites/characters/{low}/ (et sous-dossiers d'effets), sources art/blender/characters/{low}*, script "
          f"art/tools/night/{id}_build.py. Périmètre : ces chemins + icônes game/assets/sprites/icons/spells/{low}_*.png.")


w('m3', "LOT M3 : Rictus (ex-Marotte) 3/3, docs/Design_Personnages.md §2.6.11 « Assets séparés ». knife (CREA 4 frames, pointe +X) -> "
        "game/assets/sprites/characters/rictus/knife/knife.tres (anim default) ; knife_planted (1 frame x 8 dir) -> "
        "rictus/knife_planted/knife_planted.tres (default_<dir>) ; dagger_arc (rig TOP 128 px/u, 4 frames, anim default non bouclée, demi-lune au sol centrée sur +X, Rictus au centre de la frame, rayon 2,5 u = 320 px ; le jeu la tourne vers la cible) -> rictus/dagger_arc/dagger_arc.tres ; "
        "spin_blur (CREA 4, 1 dir, additif) -> rictus/spin_blur/ ; double_burst (TOP 6 + CREA 6) -> rictus/double_burst/ ; string_tile "
        "(TOP, 1 tuile de fil argent) -> game/assets/sprites/characters/montreur/string_tile/string_tile.png ; 4 icônes 128 -> "
        "game/assets/sprites/icons/spells/{dagues_demi_lune,eventail,toupie,doublures}.png (cohérentes avec art/tools/ui/_i2_contact.png) ; "
        "portrait. Lis art/tools/characters/_m2.txt et le modèle art/blender/characters/rictus.blend. Périmètre : ces chemins, "
        "art/tools/night/m3_*.")

for id, boss, biome, floor in [('c7b', 'cerf', "Forêt de brume (foret_brume) : brume #B8C8C0, mousse, bois noir, lanternes de feu follet", '2'),
                               ('c7c', 'sonneur', "Cité rouillée (cite_rouille) : fer rouillé, laiton, vapeur, foudre", '3')]:
    w(id, f"LOT {id.upper()} : boss d'étage {floor} « {boss} » refait dans la DA, EXACTEMENT selon la méthode du lot C7a de l'Éclusier "
          f"(lis art/tools/monsters/_c7a.txt, son rapport art/tools/monsters/_logc7a.txt.last.txt et c7a_build.py) : modèle neuf imposant, "
          f"biome {biome} ; rôle, taille, extras et sols d'art/briefs/bosses_etage.md section {boss} ; remplacer à l'identique tout "
          f"game/assets/sprites/bosses/etage/{boss}/ (inventaire d'abord) ; auto, spell_a, spell_b en 4 directions (s + planches _dirs "
          f"e, w, n) ajoutées au .tres. Sources art/blender/monsters/{boss}_iso.blend, script art/tools/night/{id}_build.py. Périmètre : "
          f"ces fichiers et game/assets/sprites/bosses/etage/{boss}/.")

for id, biome, map_, desc in [('f2', 'forêt de brume', 'foret_brume', "sol de tourbe et racines, dalles moussues, eau stagnante, troncs noirs et souches pour les murs, brume basse, lanternes de feu follet vert froid comme accent"),
                              ('f3', 'cité rouillée', 'cite_rouille', "pavés de fer et briques noires, grilles, flaques d'huile, murs de tôle rivetée et de briques effondrées, tuyaux, vapeur, accent foudre et laiton chaud")]:
    w(id, f"LOT {id.upper()} : biome iso de la carte {map_} ({biome}). Refais pour ce biome tout ce que les lots C1/C1b (terrain : tuiles "
          f"de sol, murs et falaises en sprites, bords, abîme) et C10 ont fait pour terrasses_noyees, plus les props de décor du biome "
          f"(les coffres, piliers, téléporteur et capsules restent communs) : lis art/tools/iso/_c1.txt, _c1b.txt, _c8.txt, _c10.txt et "
          f"leurs rapports, docs/Design_Isometrique.md et docs/Direction_Lumiere_Ambiance.md. Ambiance : {desc}. MÊME format et mêmes "
          f"noms de fichiers que les terrasses : inspecte game/assets/sprites/terrain/ et la façon dont game/scripts/stage/ choisit les "
          f"tuiles d'une carte ; si le code attend un dossier par biome, livre-le à ce chemin, sinon livre dans "
          f"game/assets/sprites/terrain/{map_}/ et décris le mapping exact dans le rapport pour l'agent de code. Variantes _se/_sw, _n/_e, "
          f"ombres cuites. Sources art/blender/terrain/{id}_*, script art/tools/night/{id}_build.py. Périmètre : ces fichiers et les "
          f"dossiers d'assets du biome (ne modifie pas les tuiles des terrasses).")

T = ["modèle 7 parties nommées avec pivots, matières DA, planche avec Ardent et ash_lord à la même échelle (sources seulement, rien dans game/)",
     "rig + locomotion en CALQUES (idle, walk, hop_l/r, handwalk, crawl_l/r, roll, fall) + layers_order.json, sorties brutes dans art/tools/night/t_out/",
     "lancers x5 (throw_arm_l/r, throw_leg_l/r, throw_head), death, regen_rivets, vapeur de cou, attack (rivets), sorties brutes dans art/tools/night/t_out/",
     "membres en vol et au sol (arm_fly, arm_clamp, arm_ground, leg_fly, leg_ground, head_fly), head_blast, 4 icônes de sorts, 2 portraits -> game/assets/sprites/characters/tocsin/ et icons/spells/tocsin_*.png",
     "assemblage final : découpe des calques, atlas rognés, .tres par calque (SpriteFrames <anim>_<dir>), _n/_e, manifeste layers_order.json -> game/assets/sprites/characters/tocsin/ ; documente le format exact pour l'agent de code"]
for i, txt in enumerate(T, 1):
    w(f't{i}', f"LOT T{i} (Tocsin, l'automate de crue, {i}/5) : docs/Design_Personnages.md §1 entier, surtout §1.11 Aspect et §1.12 (table "
               f"des lots T1-T5 : fais le lot T{i}). Base : chara design art/blender/characters/cd_tocsin.blend et "
               f"art/tools/characters/_cd_tocsin.png s'ils existent ; rapports des lots précédents art/tools/night/_logt*.txt.last.txt. "
               f"Contenu : {txt}. " + CHAR + f"Sources art/blender/characters/tocsin*, script art/tools/night/t{i}_build.py. Périmètre : "
               f"ces chemins, art/tools/night/t_out/, game/assets/sprites/characters/tocsin/, icons/spells/tocsin_*.")

for id, name, sec in [('av', 'Averse', '§2.1'), ('ar', 'Arpenteuse', '§2.2'), ('ra', 'Rainette', '§2.3'), ('aa', 'Avare', '§2.4')]:
    charlot(id + '1', name, sec, "Lot 1/2 : modèle final + TOUTES les animations du corps de la fiche en 8 directions.")
    charlot(id + '2', name, sec, "Lot 2/2 : tous les VFX et objets de la fiche (rubrique Animations : VFX, zones, projectiles), 4 icônes de "
                                 "sorts 128 px cohérentes avec art/tools/ui/_i2_contact.png, portrait. Lis le rapport du lot 1 "
                                 f"(art/tools/night/_log{id}1.txt.last.txt).")
charlot('bo1', 'Bourbe', '§2.5', "Lot 1/3 : Bourbe, modèle final + toutes ses animations en 8 directions.")
charlot('bo2', 'Bourbe', '§2.5', "Lot 2/3 : la motte (familier : 96 px rognés dans la cellule 192 ; idle 6, run 6, die 4 ; 8 directions) -> "
                                 "game/assets/sprites/characters/bourbe/motte/ ; même matière et feu follet que Bourbe.")
charlot('bo3', 'Bourbe', '§2.5', "Lot 3/3 : VFX (bog_zone TOP 8, anneau d'allié, tous les VFX de la fiche), 4 icônes, portrait. Lis les "
                                 "rapports bo1 et bo2.")
w('i3', "LOT I3 : icônes des 8 sorts d'Ardent, game/assets/sprites/icons/spells/{eclat_de_braise,nova_ardente,cendres,brasier,braises_errantes,"
        "phenix,pilier_de_flamme,pluie_de_meteores}.png, À REFAIRE (retour joueur : flammes saumon, une barre parasite sur la 4e, l'auto ne correspond "
        "pas à la DA). Même format, noms, tailles, marges alpha et .import (inventaire d'abord). Feu réaliste orange braise (cohérent avec la "
        "torche d'Ardent _c4_contact.png et le projectile V2 _v2_contact.png), emblème par sort : l'auto = éclat de braise incandescent à croûte "
        "de charbon en vol avec traînée d'étincelles ; nova = onde annulaire de flammes ; cendres = sol de cendres rougeoyantes ; brasier = "
        "colonne d'embrasement ; etc. Les icônes doivent se distinguer d'un coup d'œil à 64 px. Périmètre : ces 8 fichiers et "
        "art/tools/night/i3_*, art/blender/ui/i3_*.")
print(sorted(f for f in os.listdir(D) if f.endswith('.txt')))

# Contenu de l'étage 2 (rapport de l'agent contenu, 22/10) : nouveaux mini-boss, boss d'étage alternatifs, variantes « mousse ».
MINI = ("Format mini-boss EXACTEMENT comme les lots C5/R9 (lis art/tools/monsters/_r9a.txt et son rapport, inspecte "
        "game/assets/sprites/bosses/mini/frost_bear/ et son .tres) : frame 170 px, idle_s, run_e/s/w/n, attack_/cast_a_/cast_b_<e,s,w,n> "
        "(impact à la moitié, non bouclées), phase2_s, death_s, _n/_e, render scale et pivot identiques. ")
for id, ids, extra in [('n2a', 'mist_wolf (+ son louveteau mist_wolf_cub, plus petit, idle/run/attack/death) et lantern_owl', ''),
                       ('n2b', 'moss_mantis', '')]:
    w(id, f"LOT {id.upper()} : nouveaux mini-boss du biome forêt de brume : {ids}. Rôles, attaques et aspect : docs/Design_Etages.md "
          f"(cherche ces ids) et docs/Design_Boss_Cartes.md. " + MINI + f"Sorties game/assets/sprites/bosses/mini/<id>/<id>.tres ; sources "
          f"art/blender/monsters/{id}_*, script art/tools/night/{id}_build.py. Périmètre : ces chemins uniquement.")
for id, boss in [('n2c', 'weaver'), ('n2d', 'hermit_cedar')]:
    w(id, f"LOT {id.upper()} : nouveau boss d'étage alternatif de la forêt de brume « {boss} » (docs/Design_Etages.md, cherche l'id). "
          f"Format EXACTEMENT comme le Cerf/Éclusier refaits (lis art/tools/monsters/_c7a.txt et art/tools/night/_c7b.txt, inspecte "
          f"game/assets/sprites/bosses/etage/eclusier/) : idle/walk par phase, auto, spell_a, spell_b en 4 directions (s + _dirs e, w, n), "
          f"trans_p2/p3, death, extras de son design ; sorties game/assets/sprites/bosses/etage/{boss}/{boss}.tres ; sources "
          f"art/blender/monsters/{boss}_iso.blend, script art/tools/night/{id}_build.py. Périmètre : ces chemins uniquement.")
w('n2e', "LOT N2E : variante de matière « mousse » (forêt de brume) des monstres swarm_tier1, shooter_tier2, leaper_tier2, brute_tier3 : "
         "mêmes modèles, mêmes grilles, frames, pivots et noms d'animations que leurs dossiers actuels (inspecte game/assets/sprites/monsters/ "
         "et le lot C5 art/tools/monsters/_c5.txt), matière couverte de mousse, lichen et brume, bois noir, accent émissif feu follet vert "
         "froid ; livre dans un dossier frère suffixé _moss (ex. monsters/swarm_tier1_moss/) avec son .tres, et décris le mapping dans le "
         "rapport. Sources art/blender/monsters/n2e_*, script art/tools/night/n2e_build.py. Périmètre : ces chemins uniquement.")

# Spécification exacte de la forêt (rapport de l'agent carte, 22/10) : remplace le F2 générique.
w('f2', "LOT F2 (= C2 forêt) : tuiles iso de la carte foret_brume, MÊME format que le lot C1b des terrasses (lis art/tools/iso/_c1b.txt, son "
        "rapport, et inspecte game/assets/sprites/terrain/terraces/iso/ : mêmes noms, cadres, pivots, _n obligatoire pour chaque fichier, _e "
        "si émissif). Dossier de sortie EXACT : game/assets/sprites/terrain/fog_forest/iso/ (le code bascule seul dessus dès que ground_a..d "
        "existent). Rig MAP de art/tools/iso/iso_rig.py, R = 90,51 px/u. Palette docs/Design_Etages.md §3 : sol #3E4A3F -> #55634E, racines "
        "#2A2420, eau #17262B, accent unique vert pâle #9CF0C8. Fichiers : ground_a, ground_b, ground_c, ground_d (512x256, losange 4x4 u, "
        "mousse, aiguilles de cèdre, boue, racines plates, albédo 0,12-0,25, périodique sur 4 m) ; water_shallow, water_deep (256x128, étang "
        "noir, lentilles d'eau, reflets froids) ; block_a, block_b, block_c (256x256, emprise 256x128, centre px (128,192), hauteur 1,25 u = "
        "98 px, arêtes jointives : souche, racines en arche, rocher moussu ; block_b_e = lanterne de sanctuaire verte) ; block_a/b/c_shadow "
        "(512x512, rig TOP 128 px/u) ; rampart_ne, rampart_nw, rampart_corner_n (+ rampart_corner_n_e, lanterne) (256x256, mur de troncs et "
        "racines de cèdres) ; cliff_sw, cliff_se, cliff_corner_s, cliff_corner_w, cliff_corner_e (256x384, centre d'emprise (128,64), paroi "
        "2,5 u = 196 px, berge de terre, racines pendantes au-dessus de la brume) ; void_1024 (1024x1024, rig TOP, sans raccord, abîme de "
        "brume bleu-vert). Sources art/blender/terrain/f2_*, script art/tools/night/f2_build.py. Périmètre : ces fichiers et "
        "game/assets/sprites/terrain/fog_forest/iso/ uniquement.")
w('f2p', "LOT F2P (= C9 forêt, props) : props iso du biome forêt de brume dans game/assets/sprites/props/fog_forest/ (les rendus actuels de ce "
         "dossier ne sont pas iso : remplace-les), rig MAP lacet 45°, _n, _shadow, _e si émissif, même format que les props du lot C8 (lis "
         "art/tools/iso/_c8.txt) : cedar_giant (haut, prévu pour le fondu quand le joueur passe derrière), lantern_shrine_se / lantern_shrine_sw "
         "(+ _e vert pâle #9CF0C8), root_arch_a, root_arch_b, root_arch_c, root_arch_corner, mushrooms, standing_stone, stump. Sources "
         "art/blender/props/f2p_*, script art/tools/night/f2p_build.py. Périmètre : ces chemins uniquement.")

w('f3', "LOT F3 (= C3 cité) : tuiles iso de la carte cite_rouille, MÊME format et MÊMES noms de fichiers que les terrasses et la forêt (lis "
        "art/tools/iso/_c1b.txt, art/tools/night/_f2.txt pour la liste exacte ground_a..d, water_shallow/deep, block_a..c (+ _shadow), "
        "rampart_*, cliff_*, void_1024, et inspecte game/assets/sprites/terrain/terraces/iso/). Dossier de sortie EXACT : "
        "game/assets/sprites/terrain/rust_city/iso/. Rig MAP, R = 90,51 px/u, _n pour chaque fichier, _e si émissif. Ambiance : pavés de fer "
        "et briques noires, grilles, flaques d'huile, blocs = tas de tôle rivetée, machines effondrées, tuyaux ; remparts de briques et tôle ; "
        "falaises = murs de quai effondrés au-dessus d'un abîme de vapeur ; accent unique laiton chaud / lueur de foudre (palette "
        "docs/Design_Etages.md, section de la cité). Sources art/blender/terrain/f3_*, script art/tools/night/f3_build.py. Périmètre : ces "
        "fichiers et game/assets/sprites/terrain/rust_city/iso/ uniquement.")
