import json, re, os, sys
DOC = open(r"C:/Users/const/Documents/Rainfall/docs/Design_Boss_Cartes.md", encoding="utf-8").read()
G = r"C:/Users/const/Documents/Rainfall/game"
blocks = re.findall(r"```\n(.*?)```", DOC, re.S)
grids = [b.strip("\n").split("\n") for b in blocks if b.lstrip().startswith("#") and "S" in b][:3]
# Retouches de grille décidées après Design_Boss_Cartes.md (guide en lecture seule) : (carte, rangée, colonne, texte)
# écrit à partir de cette colonne ; appliquées ici pour que la régénération reproduise data/maps/<id>.json.
GRID_EDITS = [
 # 22/10/2026, décision du joueur : la poche fermée de la carte 1 (rectangle creux de murs, cases 17-18 × 20-23)
 # devient un bassin d'eau profonde « ~ ». Contour adouci : les 4 coins « # » restent (bornes de margelle), les côtés
 # passent en sol « . » pour que la rive encre + écume (StageMap._build_water_banks, arêtes « ~ » / praticable)
 # entoure tout le bassin (un « ~ » bordé de « # » n'a aucun bord dessiné).
 ("terrasses_noyees", 19, 16, "#..#"),
 ("terrasses_noyees", 20, 16, ".~~."), ("terrasses_noyees", 21, 16, ".~~."),
 ("terrasses_noyees", 22, 16, ".~~."), ("terrasses_noyees", 23, 16, ".~~."),
 ("terrasses_noyees", 24, 16, "#..#"),
]
_GRID_IDS = ["terrasses_noyees", "foret_brume", "cite_rouille"]
for _id, _y, _x, _s in GRID_EDITS:
    _g = grids[_GRID_IDS.index(_id)]
    assert len(_g[_y]) >= _x + len(_s), (_id, _y, _x)
    _g[_y] = _g[_y][:_x] + _s + _g[_y][_x + len(_s):]

MAPS = [
 dict(id="terrasses_noyees", floor=1, name="Terrasses noyées", biome="terrasses", boss="eclusier",
  boss_name="L'Éclusier",
  ambient=dict(threshold_difficulty=2.5, name="Bassins débordants", effect="visuel : les cases ',' du sud s'élargissent d'1 u"),
  event_names={"autel_fortune":"lanterne de pierre","sanctuaire_risque":"bassin qu'on vide","marchand_ombre":"barque amarrée","coffre_piege":"coffre à demi immergé"}),
 dict(id="foret_brume", floor=2, name="Forêt-brume", biome="foret", boss="cerf_lanterne",
  boss_name="Le Cerf-Lanterne",
  ambient=dict(threshold_difficulty=4.0, name="Lucioles éteintes", effect="visuel : brume à 15 %, lanternes allumées"),
  event_names={"autel_fortune":"sanctuaire à lanterne","sanctuaire_risque":"cercle de champignons","marchand_ombre":"silhouette sous une racine","coffre_piege":"coffre couvert de mousse"}),
 dict(id="cite_rouille", floor=3, name="Cité de rouille", biome="cite", boss="sonneur",
  boss_name="Le Sonneur",
  ambient=dict(threshold_difficulty=4.0, name="Orage", effect="visuel : éclair de décor toutes les 10-20 s ; à Cataclysme le canal monte"),
  event_names={"autel_fortune":"lampe à vapeur","sanctuaire_risque":"vanne de pression","marchand_ombre":"guichet grillagé","coffre_piege":"caisse rivetée"}),
]
# Repères (C, P, G, E, S) et taille : déduits de la grille après mise en forme (voir shape_grid), comme pour NEW_MAPS.
U = 64
# Projection (docs/Design_Isometrique.md §1.2, §3) : "iso45" = grille de carte tournée de +45° dans le repère
# logique (Visual, Obstacles et Markers portent la rotation ; grilles, positions et rectangles inchangés).
# Étages 1-3 (terrasses_noyees, foret_brume, cite_rouille) en iso (cite_rouille : lot F3, 22/10/2026).
ISO = {"terrasses_noyees", "foret_brume", "cite_rouille", "cryptes_noyees", "la_source",
       "terrasses_rizieres_hautes", "foret_mangrove_lanternes", "cite_fonderie_canal", "cryptes_ossuaire_pluies"}
# Étages 4 et 5 (docs/Design_Etages.md §3-§4, lot L1) : grilles dessinées ici (pas dans Design_Boss_Cartes).
# Lettres : C coffre, P petit pilier, G gros pilier, E événement, S départ (cases praticables) ;
# les repères en u (centre de case = 2 * case + 1) sont déduits des lettres.
GRID_CRYPTES = [
  "##############################",
  "#........#..C....C..#........#",
  "#.#....#.#..........#.#....#.#",
  "#..C..C..#.#......#.#..C..C..#",
  "#.............S..............#",
  "#...P....................P...#",
  "#.....E..#.#......#.#..E.....#",
  "#.C......#..........#......C.#",
  "#........#..........#........#",
  "###...####.#......#.####...###",
  "###...####....P.....####...###",
  "#........#..........#........#",
  "#.#C.....#.#......#.#.....C#.#",
  "#........#....P.....#........#",
  "#...G....................G...#",
  "#..........#......#..........#",
  "#.....C..#....G.....#..C.....#",
  "#......#.#..........#.#......#",
  "#........#..C....C..#........#",
  "###...####....E.....####...###",
  "#............................#",
  "#.C.......,,,,,,,,,,.......C.#",
  "#.......,,,~~~~~~~~,,,.......#",
  "#...P..,,~~~~~~~~~~~~,,..P...#",
  "#.#...,,~~~~~~~~~~~~~~,,...#.#",
  "#.....,,~~~~~~~~~~~~~~,,.....#",
  "#......,,~~~~~~~~~~~~,,......#",
  "#.C..C..,#,~~~~~~~~,#,..C..C.#",
  "#.........,,,,,,,,,,.........#",
  "##############################",
 ]
GRID_SOURCE = [
  "#########################",
  "#C...#####.....#####...C#",
  "#...C##...........##C...#",
  "#.......................#",
  "#####...............#####",
  "####.....#..C..#.....####",
  "###.....E.......E.....###",
  "##.....................##",
  "##.....................##",
  "##...#....,,,,,....#...##",
  "#........,,,,,,,........#",
  "#........,,...,,........#",
  "#....C...,,.G.,,...C....#",
  "#........,,...,,........#",
  "#........,,,,,,,........#",
  "##...#....,,,,,....#...##",
  "##.....................##",
  "##.....................##",
  "###...................###",
  "####.....#..C..#.....####",
  "#####...............#####",
  "#.......................#",
  "#...C##...........##C...#",
  "#C...#####..S..#####...C#",
  "#########################",
 ]
# Variantes B (docs/Design_Variantes_B.md, intégrées le 28/10/2026) : grilles du level designer. Lettres en plus :
# D = porte scellée (solide tant que fermée, rectangle de collision séparé `Door_<secret>`), : = sol scellé
# (praticable une fois la porte ouverte ; exclu des capsules et des apparitions tant qu'elle est fermée).
GRID_RIZIERES = [
  "########################",
  "#:::#......C.....,,,,,C#",
  "#:::D............,~~~,.#",
  "#:::D..P.........,~~~,.#",
  "#####............,,,,,.#",
  "#...........G..........#",
  "#..................P...#",
  "#C...E.........C.......#",
  "#......................#",
  "#######..######..#######",
  "#...,,,...C.......,,,..#",
  "#C..,,,.....#.....,,,..#",
  "#...,,,...........,,,.C#",
  "##..#######..#######..##",
  "#C..............E......#",
  "#......C.,,,,,,.......C#",
  "#........,~~~~,........#",
  "#...G....,~~~~,....P...#",
  "#........,~~~~,.P......#",
  "#....P...,~~~~,........#",
  "#........,,,,,,.......C#",
  "#...........C..........#",
  "######..########..######",
  "#.......,,,...,,,......#",
  "#C......,,,.C.,,,.....C#",
  "#.......,,,...,,,......#",
  "###..######..######..###",
  "#.................C....#",
  "#....................E.#",
  "#.........P............#",
  "#.....P......,,,,..G...#",
  "#.S..........,~~,......#",
  "#.......#....,~~,......#",
  "#.......#..C.,,,,.....C#",
  "#.......#..............#",
  "########################",
 ]
GRID_MANGROVE = [
  "####################################",
  "#C.......C.#:::#.....C............C#",
  "#..........#:::#............C......#",
  "#..........#:::#.P.................#",
  "#...P......##D##......~~,,~~~..P...#",
  "#.......E............~~~,,~~~......#",
  "#....................~~.....~~.....#",
  "#~~,,~~..........C..~~......~~.....#",
  "#~~,,~~.....G.......~~E......~~..C.#",
  "#~.C..~............~~....P...~~....#",
  "#~....~~C..........~~.........~~...#",
  "#~~,,~~~~.........~~...#......~~...#",
  "#~~,,~~~~~........~~...........~~..#",
  "#.......~~~~~,,~~~~.........C..~~..#",
  "#C.......~~~~,,~~~~....G........~~.#",
  "#.........~~....~~..............~,,#",
  "#...G......~..C.~~..C............,,#",
  "#..........~~,,~~..................#",
  "#..........~~,,~~..............P...#",
  "#.........................C........#",
  "#.....###....P..............###....#",
  "#.........C................E.....S.#",
  "#C................C................#",
  "####################################",
 ]
GRID_FONDERIE = [
  "################################",
  "#C.......#...............#:::::#",
  "#.....C..#.C........C....#:::::#",
  "#........#......P........#:::::#",
  "#........................##DD###",
  "#....G...E...~~,,~~............#",
  "#.C.......~~~~~,,~~~~~........C#",
  "#........~~~........~~~....P...#",
  "#.......~~......C.....~~.......#",
  "####...~~....######....~~...####",
  "#.....~~....##....##....~~.....#",
  "#.....~~................~~.....#",
  "#C....~...#.....#....#...~.....#",
  "#....~~..##..C.......##..~~...C#",
  "#....~~..#............#..~~....#",
  "#....,,.C#..#.........#..,,....#",
  "#..P.,,..#......G..#..#C.,,.P..#",
  "#....~~..#...P........#..~~....#",
  "#....~~..##..E....C..##..~~....#",
  "#.....~...#....#.....#...~.....#",
  "#.....~~................~~.....#",
  "#.....~~....##....##....~~.....#",
  "####...~~....######....~~...####",
  "#.......~~......C.....~~.......#",
  "#........~~~........~~~........#",
  "#....P....~~~~~,,~~~~~...G.....#",
  "#............~~,,~~......E.....#",
  "#..S...........................#",
  "#........#......P.....#.....P..#",
  "#........#............#........#",
  "#........#...C........#.C.....C#",
  "################################",
 ]
GRID_OSSUAIRE = [
  "########################",
  "#C....C#...C....#::::::#",
  "#......#........#::::::#",
  "#......#........###DD###",
  "#..P...#..#..#..#......#",
  "#................C.....#",
  "#...........P..........#",
  "#......#C.......#...P..#",
  "#.,,...#........#......#",
  "#.,,...#..#..#..#.....C#",
  "#......#........#......#",
  "#C.....................#",
  "#..............C...,,,.#",
  "#......#...G....#..,,,.#",
  "#..P...#........#......#",
  "#......#........#......#",
  "#........,,,,,,.......E#",
  "#........,~~~~,........#",
  "#...E....,~~~~,....G...#",
  "#C.......,~~~~,........#",
  "#........,~~~~,........#",
  "#....C...,,,,,,.......C#",
  "#......#........#......#",
  "#.,,,..#.......C#......#",
  "#.,,,..#...G....#......#",
  "#......#C.......#.....C#",
  "#......................#",
  "#...................P..#",
  "#......#..#..#..#......#",
  "#C.....#........#......#",
  "####...#........#...####",
  "#.....C#....P...#.....C#",
  "#......................#",
  "#.........#..#.........#",
  "#......#.......E#......#",
  "#..S...#........#......#",
  "#C.....#...C....#C.....#",
  "########################",
 ]
NEW_MAPS = [
 dict(id="cryptes_noyees", floor=4, name="Cryptes noyées", biome="cryptes", variant="A", boss="recluse",
  boss_name="Le Reclus", grid=GRID_CRYPTES,
  ambient=dict(threshold_difficulty=2.5, name="Crue", effect="visuel : la crue monte (cases ',' élargies) ; Furieux : cristaux qui s'éteignent par vagues"),
  event_names={"autel_fortune":"reliquaire de cristal","sanctuaire_risque":"ossuaire scellé","marchand_ombre":"passeur sur le lac noir","coffre_piege":"sarcophage entrouvert"}),
 dict(id="la_source", floor=5, name="La Source", biome="source", variant="", boss="rain_sower",
  boss_name="Le Semeur de pluie", grid=GRID_SOURCE,
  rules=dict(small_chests=6, large_chests=2, legendary_chance=1.0, small_pillars=0, big_pillars=1),
  ambient=dict(threshold_difficulty=4.0, name="Colonne de pluie", effect="visuel : la colonne de pluie centrale s'épaissit avec la difficulté"),
  event_names={"autel_fortune":"autel de la Source","sanctuaire_risque":"vasque de pluie","marchand_ombre":"pèlerin sous la colonne","coffre_piege":"offrande noyée"}),
 dict(id="terrasses_rizieres_hautes", floor=1, name="Rizières hautes", biome="terrasses", variant="B", boss="eclusier",
  boss_name="L'Éclusier", grid=GRID_RIZIERES, hour_shift_min=30,
  ambient=json.loads(r'''{"threshold_difficulty": 2.5, "name": "La noria repart", "effect": "visuel et sonore : la noria du bassin central se remet à tourner (grincement, éclaboussures) ; les cases ',' des rizières s'élargissent d'1 u"}'''),
  event_names=json.loads(r'''{"autel_fortune": "lanterne de pierre du palier", "sanctuaire_risque": "rizière qu'on draine", "marchand_ombre": "cabane de la noria", "coffre_piege": "coffre dans la boue"}'''),
  secrets=json.loads(r'''[{"id": "citerne_noria", "kind": "sealed_door", "skin": "dalles de vanne + grille de citerne (habillage Terrasses)", "door_cells": [[12, 4], [12, 5]], "room_cells": [[9, 3], [10, 3], [11, 3], [9, 4], [10, 4], [11, 4], [9, 5], [10, 5], [11, 5]], "plates_u": [[15, 25], [49, 43]], "guardians_u": [[19, 7], [21, 11]], "guardian_names": ["Orme", "Aulne"], "reward": "2 reliquaires (table gardien)"}]''')),
 dict(id="foret_mangrove_lanternes", floor=2, name="Mangrove des lanternes", biome="foret", variant="B", boss="cerf_lanterne",
  boss_name="Le Cerf-Lanterne", grid=GRID_MANGROVE, hour_shift_min=-30,
  ambient=json.loads(r'''{"threshold_difficulty": 4.0, "name": "Marée montante", "effect": "visuel : la marée monte, les cases ',' des pontons et des rives s'élargissent d'1 u ; lucioles éteintes, brume à 15 %"}'''),
  event_names=json.loads(r'''{"autel_fortune": "sanctuaire à lanterne sur pilotis", "sanctuaire_risque": "cercle de champignons", "marchand_ombre": "barque sous les racines", "coffre_piege": "coffre pris dans les racines"}'''),
  secrets=json.loads(r'''[{"id": "sanctuaire_racines", "kind": "sealed_door", "skin": "pierres plates à rune + rideau de racines (habillage Forêt)", "door_cells": [[16, 7]], "room_cells": [[15, 4], [16, 4], [17, 4], [15, 5], [16, 5], [17, 5], [15, 6], [16, 6], [17, 6]], "plates_u": [[17, 27], [73, 19]], "guardians_u": [[31, 11], [35, 11]], "guardian_names": ["Lierre", "Houx"], "reward": "2 reliquaires (table gardien)"}]''')),
 dict(id="cite_fonderie_canal", floor=3, name="Fonderie du canal", biome="cite", variant="B", boss="sonneur",
  boss_name="Le Sonneur", grid=GRID_FONDERIE, hour_shift_min=30,
  ambient=json.loads(r'''{"threshold_difficulty": 4.0, "name": "Coulée", "effect": "visuel : les creusets de la cour pulsent orange (coulée de métal) ; orage à Furieux ; à Cataclysme le canal circulaire monte"}'''),
  event_names=json.loads(r'''{"autel_fortune": "lampe à vapeur de l'atelier", "sanctuaire_risque": "vanne de la coulée", "marchand_ombre": "guichet du contremaître", "coffre_piege": "caisse de lingots"}'''),
  secrets=json.loads(r'''[{"id": "chambre_forte", "kind": "sealed_door", "skin": "plaques de pression rivetées + porte blindée à volant (habillage Cité)", "door_cells": [[17, 5], [18, 5]], "room_cells": [[16, 2], [17, 2], [18, 2], [19, 2], [20, 2], [16, 3], [17, 3], [18, 3], [19, 3], [20, 3], [16, 4], [17, 4], [18, 4], [19, 4], [20, 4]], "plates_u": [[11, 39], [39, 65]], "guardians_u": [[35, 7], [39, 7]], "guardian_names": ["Rivet", "Soudure"], "reward": "2 reliquaires (table gardien)"}]''')),
 dict(id="cryptes_ossuaire_pluies", floor=4, name="Ossuaire des pluies", biome="cryptes", variant="B", boss="recluse",
  boss_name="Le Reclus", grid=GRID_OSSUAIRE, hour_shift_min=0,
  ambient=json.loads(r'''{"threshold_difficulty": 2.5, "name": "Pluie du puits", "effect": "visuel : la pluie de la ville tombe par le puits de lumière et le bassin central déborde (cases ',' élargies) ; Furieux : cristaux qui s'éteignent par vagues"}'''),
  event_names=json.loads(r'''{"autel_fortune": "reliquaire de cristal", "sanctuaire_risque": "ossuaire scellé", "marchand_ombre": "passeur du puits", "coffre_piege": "sarcophage entrouvert"}'''),
  secrets=json.loads(r'''[{"id": "ossuaire_scelle", "kind": "sealed_door", "skin": "dalles d'os à glyphe de sel + grille d'ossuaire (habillage Cryptes)", "door_cells": [[17, 5], [18, 5]], "room_cells": [[15, 3], [16, 3], [17, 3], [18, 3], [19, 3], [20, 3], [15, 4], [16, 4], [17, 4], [18, 4], [19, 4], [20, 4]], "plates_u": [[15, 51], [41, 33]], "guardians_u": [[35, 13], [37, 15]], "guardian_names": ["Sel", "Suie"], "reward": "2 reliquaires (table gardien)"}]''')),
]

def markers(grid, ch):
    return [(2*x+1, 2*y+1) for y, row in enumerate(grid) for x, c in enumerate(row) if c == ch]

# --- Outils de forme (28/10/2026, demande du joueur : « des maps rondes ou plus naturelles ») ------------------
# Une carte est d'abord dessinée dans un rectangle (grilles ci-dessus), puis découpée par un masque de forme :
# - les cases hors masque deviennent du VIDE « ' ' » (abîme : pas de sol, collision, aucune apparition) ;
# - toute case gardée qui touche le vide (8 voisins) devient un mur « # » ; StageMap._wall_texture choisit la
#   tuile de bord (rempart ou falaise) d'après le côté où se trouve le vide, comme pour l'ancien anneau extérieur ;
# - les murs « # » qui ne bordent plus aucune case praticable sont rendus au vide (contour d'une seule case).
# Les lettres (repères) doivent rester à l'intérieur du masque, hors contour : le script s'arrête sinon.
import math
LETTERS = "CPGESD:"
VOID = " "

def _hash01(*k):
    h = 2166136261
    for v in k:
        h = ((h ^ (int(v * 1000003) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return (h % 10007) / 10007.0

def blob(cx, cy, rx, ry, seed=0, amp=0.12, lobes=(3, 5, 7)):
    """Ellipse (centre, rayons en cases) au rayon modulé par un bruit radial doux : 1 + somme a_i*sin(l_i*t + f_i)."""
    ph = [(_hash01(seed, i) * 2.0 * math.pi, amp / (1.0 + 0.6 * i)) for i in range(len(lobes))]
    def inside(x, y):
        dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        t = math.atan2(dy, dx)
        r = 1.0 + sum(a * math.sin(l * t + f) for l, (f, a) in zip(lobes, ph))
        return dx * dx + dy * dy <= r * r
    return inside

def capsule(x1, y1, x2, y2, r):
    """Segment épais (passerelle, galerie) : cases à moins de r du segment [(x1,y1),(x2,y2)] (coins de cases)."""
    def inside(x, y):
        px, py = x + 0.5, y + 0.5
        vx, vy = x2 - x1, y2 - y1
        l2 = vx * vx + vy * vy or 1.0
        t = max(0.0, min(1.0, ((px - x1) * vx + (py - y1) * vy) / l2))
        ex, ey = px - (x1 + t * vx), py - (y1 + t * vy)
        return ex * ex + ey * ey <= r * r
    return inside

def path(points, r):
    """Chaîne de capsules (canal sinueux, galerie courbe)."""
    return union(*[capsule(*a, *b, r) for a, b in zip(points, points[1:])])

def union(*fns): return lambda x, y: any(f(x, y) for f in fns)
def inter(*fns): return lambda x, y: all(f(x, y) for f in fns)
def diff(a, *bs): return lambda x, y: a(x, y) and not any(b(x, y) for b in bs)
def rect(x0, y0, x1, y1): return lambda x, y: x0 <= x <= x1 and y0 <= y <= y1

def pad(grid, left=0, right=0, top=0, bottom=0, fill="."):
    """Agrandit le rectangle de dessin (les indices des cases existantes glissent de left / top)."""
    w = len(grid[0]) + left + right
    out = [fill * w for _ in range(top)]
    out += [fill * left + r + fill * right for r in grid]
    out += [fill * w for _ in range(bottom)]
    return out

def strip_ring(grid):
    """L'anneau extérieur de murs du dessin rectangulaire devient du sol : le masque dessine le nouveau contour."""
    h, w = len(grid), len(grid[0])
    g = [list(r) for r in grid]
    for y in range(h):
        for x in range(w):
            if (x in (0, w - 1) or y in (0, h - 1)) and g[y][x] == "#":
                g[y][x] = "."
    return ["".join(r) for r in g]

def carve(grid, inside, mid):
    """Applique le masque : vide hors masque, contour « # » d'une case, murs orphelins rendus au vide."""
    h, w = len(grid), len(grid[0])
    g = [list(r) for r in grid]
    bad = []
    for y in range(h):
        for x in range(w):
            if not inside(x, y):
                if g[y][x] in LETTERS:
                    bad.append((g[y][x], x, y, "hors masque")); continue
                g[y][x] = VOID
    def void(x, y): return x < 0 or y < 0 or x >= w or y >= h or g[y][x] == VOID
    def n8(x, y): return [(x + i, y + j) for i in (-1, 0, 1) for j in (-1, 0, 1) if i or j]
    for y in range(h):
        for x in range(w):
            if g[y][x] != VOID and any(void(*n) for n in n8(x, y)):
                if g[y][x] in LETTERS:
                    bad.append((g[y][x], x, y, "sur le contour")); continue
                g[y][x] = "#"
    if bad and os.environ.get("GEN_MAPS_LENIENT"):
        print("LETTRES", mid, bad)
    else:
        assert not bad, (mid, bad)
    changed = True
    while changed:
        changed = False
        for y in range(h):
            for x in range(w):
                if g[y][x] == "#" and any(void(*n) for n in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]) \
                   and not any(not void(*n) and g[n[1]][n[0]] != "#" for n in n8(x, y)):
                    g[y][x] = VOID; changed = True
    return ["".join(r) for r in g]

def stats(grid):
    """Cases praticables, d'eau profonde, de mur et de vide."""
    n = {"walk": 0, "deep": 0, "wall": 0, "void": 0}
    for r in grid:
        for c in r:
            n["void" if c == VOID else "wall" if c == "#" else "deep" if c == "~" else "walk"] += 1
    return n

# Forme de chaque carte : id -> fonction(grille) -> grille mise en forme (voir SHAPES plus bas).
def edit(g, items):
    """Retouches (x, y, texte) sur la grille agrandie (coordonnées après pad) : lettres déplacées hors du vide,
    murs qui doublaient l'ancien anneau, culs-de-sac nés de la découpe."""
    g = [list(r) for r in g]
    for x, y, t in items:
        assert 0 <= y < len(g) and 0 <= x and x + len(t) <= len(g[y]), (x, y, t)
        g[y][x:x + len(t)] = list(t)
    return ["".join(r) for r in g]

def canal(g, x0, x1, y0, y1, amp, period, phase=0.0, keep=None):
    """Canal sinueux : la bande d'eau [x0, x1] des rangées y0..y1 glisse de round(amp·sin) à chaque rangée ;
    les rangées de gué « , » restent des gués. Les lettres ne sont jamais écrasées."""
    g = [list(r) for r in g]
    wide = x1 - x0 + 1
    for y in range(y0, y1 + 1):
        ch = "," if g[y][x0] == "," else "~"
        d = round(amp * math.sin(2.0 * math.pi * (y - y0) / period + phase))
        for x in range(x0 - int(amp) - 1, x1 + int(amp) + 2):
            if g[y][x] in ",~":
                g[y][x] = "."
        for x in range(x0 + d, x0 + d + wide):
            if g[y][x] not in LETTERS:
                g[y][x] = ch
    return ["".join(r) for r in g]

def _shape_terrasses(g):
    # Éventail de terrasses : large galet (bruit radial) posé sur la pente, crique au sud-ouest (bassin qui s'ouvre
    # sur l'abîme) et cap au nord-est ; aucun angle droit sur le pourtour.
    g = pad(strip_ring(g), right=4, bottom=4)
    g = edit(g, [(12, 1, "."), (12, 2, "."), (12, 3, "."), (12, 4, "."),  # le mur nord s'arrête à la crête
                 (18, 1, "."), (16, 4, "C"), (7, 2, "."), (15, 3, "C"), (22, 2, "."), (23, 5, "P"), (20, 3, "."), (19, 5, "E"),
                 (7, 4, "."), (6, 11, "P"), (3, 24, "."), (8, 25, "C"), (3, 28, "."), (11, 29, "C"),
                 (6, 27, "...."), (6, 28, "...."), (6, 29, "...."), (12, 32, "C"),  # ancien réduit sud-ouest ouvert
                 (3, 19, "."), (3, 20, "."), (3, 21, "."),  # la bande ouest rejoint la terrasse (plus de cul-de-sac)
                 (14, 32, ",,,"), (14, 33, ",,,")])  # flaque de la terrasse basse (sud-est)
    m = diff(union(blob(16, 18, 15.6, 17.6, seed=11, amp=0.10), blob(24, 9, 7, 7, seed=12, amp=0.12)),
             blob(1, 29, 6.5, 6.0, seed=13, amp=0.15))
    return carve(g, m, "terrasses_noyees")

def _shape_foret(g):
    # Clairière de mangrove : contour très découpé (bruit fort), deux criques d'eau noire (nord-ouest, sud-est).
    g = pad(strip_ring(g), left=3, right=3, top=3, bottom=3)
    g = edit(g, [(33, 4, "."), (30, 5, "C"), (30, 24, "."), (28, 24, "C"), (31, 25, "."), (27, 27, "P"),
                 (5, 28, "."), (10, 24, "P"), (32, 28, "."), (25, 29, "C"), (8, 29, "."), (13, 29, "C"),
                 (26, 23, "."), (26, 24, "."), (26, 25, "."), (26, 26, "."), (26, 27, "."), (30, 22, ".."),  # la salle sud-est s'ouvre sur la crique
                 (24, 4, "#"),  # encoche nord : plus de case isolée
                 (6, 6, "."), (9, 6, "P"), (32, 6, "."), (33, 15, "P"), (6, 18, "."), (9, 18, "P"), (27, 27, "."), (24, 27, "P")])  # piliers sur sol dégagé (disque >= 70 %)
    m = diff(blob(19, 17, 18.6, 16.4, seed=21, amp=0.16), blob(0, 3, 5, 5, seed=22, amp=0.2), blob(37, 30, 6, 5, seed=23, amp=0.2))
    return carve(g, m, "foret_brume")

def _shape_cite(g):
    # Quartiers irréguliers : silhouette haute et découpée, deux « quais » rognés par le canal à l'ouest et à l'est.
    g = pad(strip_ring(g), left=3, right=3, top=3, bottom=3)
    g = canal(g, 13, 16, 11, 34, 3.0, 24.0)  # le canal serpente entre les quartiers (gués conservés)
    g = edit(g, [(6, 4, "."), (8, 3, "C"), (23, 4, "."), (20, 3, "C"), (6, 41, "."), (15, 41, "C"), (22, 41, "."), (18, 41, "C"),
                 (8, 39, "."), (9, 36, "P"), (20, 39, "."), (21, 36, "P")])  # piliers du sud sur sol dégagé
    m = diff(blob(15, 23, 14.6, 22.6, seed=31, amp=0.11), blob(-1, 24, 4.5, 5, seed=32, amp=0.2), blob(31, 14, 4, 5, seed=33, amp=0.2))
    return carve(g, m, "cite_rouille")

def _shape_rizieres(g):
    # Croissant de rizières : trois galets le long d'une courbe nord-sud (la pente), creux côté est.
    g = pad(strip_ring(g), left=4, right=4, top=2, bottom=2)
    g = edit(g, [(5, 3, "..."), (5, 4, "..."), (5, 5, "..."),  # citerne de la noria rentrée d'une terrasse
                 (8, 2, "#####"), (8, 3, "#:::#"), (8, 4, "#:::D"), (8, 5, "#:::D"), (8, 6, "#####"), (12, 8, "P"),
                 (5, 9, "."), (10, 10, "C"), (5, 13, "."), (7, 13, "C"), (26, 14, "."), (25, 13, "C"), (26, 17, "."), (22, 17, "C"),
                 (26, 22, "."), (23, 22, "C"), (6, 33, "."), (10, 33, "S"), (26, 26, "."), (26, 27, "C"),
                 (23, 19, "."), (21, 18, "P")])  # pilier sur sol dégagé
    m = diff(union(blob(19, 9, 12.5, 9.5, seed=41, amp=0.08), blob(14, 20, 13, 11, seed=42, amp=0.08), blob(19, 31, 12.5, 9.5, seed=43, amp=0.08)),
             blob(33, 20, 7, 9, seed=44, amp=0.15))
    return carve(g, m, "terrasses_rizieres_hautes")

def _shape_mangrove(g):
    # Archipel : grande lagune allongée au contour déchiqueté, criques au nord et au sud.
    g = pad(strip_ring(g), left=3, right=3, top=3, bottom=5)
    g = edit(g, [(14, 3, "#####"),  # toit du sanctuaire des racines (l'ancien anneau le fermait)
                 (4, 4, "."), (19, 2, "C"), (12, 4, "."), (21, 5, "C"), (37, 4, "."), (35, 6, "C"), (7, 7, "."), (8, 8, "P"),
                 (4, 25, "."), (8, 21, "C"), (13, 24, "."), (19, 25, "C"),
                 (8, 8, "."), (12, 9, "P"), (16, 23, "."), (21, 24, "P")])  # piliers sur sol dégagé
    m = diff(union(blob(21, 15, 21.0, 14.8, seed=51, amp=0.14), blob(24, 26.5, 9, 4.2, seed=54, amp=0.1)),
             blob(24, -2, 6, 4, seed=52, amp=0.2), blob(8, 29, 6, 6, seed=53, amp=0.2), blob(14, 32, 5, 5, seed=55, amp=0.2))
    return carve(g, m, "foret_mangrove_lanternes")

def _shape_fonderie(g):
    # Fonderie ronde : disque (cour centrale, deux anneaux), légère ondulation ; une encoche au sud-ouest (quai).
    g = pad(strip_ring(g), left=3, right=3, top=3, bottom=3)
    g = edit(g, [(28, 4, "......"), (28, 5, "......"), (28, 6, "......."), (28, 7, "......."),  # ancienne chambre forte (angle) rendue à la cour
                 (16, 1, "#####"), (15, 2, "#:::::#"), (15, 3, "#:::::#"), (15, 4, "#:::::#"), (15, 5, "##DD###"),  # chambre forte au nord
                 (4, 4, "."), (23, 3, "C"), (9, 5, "."), (11, 7, "C"), (6, 30, "."), (9, 30, "S"), (31, 31, "."), (29, 30, "P"),
                 (33, 33, "."), (28, 32, "C"),
                 (8, 8, "."), (9, 9, "G"), (19, 6, "."), (24, 6, "P"), (8, 28, "."), (12, 30, "P")])  # piliers sur sol dégagé
    m = diff(blob(19, 19, 18.6, 18.4, seed=61, amp=0.07), blob(1, 33, 5, 5, seed=62, amp=0.15))
    return carve(g, m, "cite_fonderie_canal")

def _shape_ossuaire(g):
    # Ossuaire : galerie haute et sinueuse (deux galets décalés), deux criques (ouest et est).
    g = pad(strip_ring(g), left=2, right=2, top=2, bottom=2)
    g = edit(g, [(14, 2, "########"), (14, 3, "#::::::#"), (14, 4, "#::::::#"), (14, 5, "###DD###"),  # ossuaire scellé décalé vers la nef
                 (22, 3, "..."), (22, 4, "..."), (22, 5, "..."),
                 (3, 3, "."), (6, 4, "C"), (24, 18, "."), (20, 18, "E"), (3, 21, "."), (8, 21, "C"), (24, 23, "."), (22, 23, "C"),
                 (3, 31, "."), (5, 31, "C"), (24, 33, "."), (22, 34, "C"), (5, 37, "."), (7, 37, "S"), (3, 38, "."), (12, 39, "C"),
                 (5, 16, "."), (6, 15, "P"), (21, 20, "."), (18, 21, "G")])  # piliers sur sol dégagé
    m = diff(union(blob(13, 12, 12.5, 12.5, seed=71, amp=0.1), blob(15, 30, 12.5, 13, seed=72, amp=0.1)),
             blob(-1, 21, 4, 5, seed=73, amp=0.2), blob(29, 20, 4, 5, seed=74, amp=0.2))
    return carve(g, m, "cryptes_ossuaire_pluies")

def _canvas(w, h, outer, land, deep="~"):
    """Grille w × h : sol là où `land`, eau profonde ailleurs dans `outer`, vide au-delà (découpe par `outer`).
    Les cases d'eau isolées (aucune voisine d'eau) redeviennent du sol : pas de flaque d'une case."""
    g = [["." if land(x, y) else deep for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if g[y][x] == deep and not any(0 <= x + i < w and 0 <= y + j < h and g[y + j][x + i] == deep
                                            for i, j in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = "."
    return ["".join(r) for r in g], outer

def _shape_cryptes(_g):
    # Cryptes noyées : nef ronde, quatre chapelles rondes et la salle du lac, reliées par des galeries courbes ;
    # entre elles, l'eau noire du lac souterrain ; le tout dans une caverne ronde au contour irrégulier.
    nave, nw, ne, w_, e_, lake = (18, 13), (6, 5), (30, 5), (5, 19), (31, 19), (18, 28)
    land = union(blob(*nave, 7.2, 6.8, seed=81, amp=0.05), blob(*nw, 4.8, 4.5, seed=82, amp=0.06), blob(*ne, 4.8, 4.5, seed=83, amp=0.06),
                 blob(*w_, 4.8, 4.8, seed=84, amp=0.06), blob(*e_, 4.8, 4.8, seed=85, amp=0.06), blob(*lake, 8.2, 6.2, seed=86, amp=0.05),
                 path([nave, nw], 1.8), path([nave, ne], 1.8), path([nave, w_], 1.8), path([nave, e_], 1.8),
                 path([nw, (3, 12), w_], 1.8), path([ne, (33, 12), e_], 1.8), path([w_, (9, 25), lake], 1.8), path([e_, (27, 25), lake], 1.8),
                 path([nave, (18, 21), lake], 1.8), path([lake, (18, 33)], 1.8))
    outer = blob(18, 17, 19.0, 19.5, seed=87, amp=0.08)
    g, m = _canvas(36, 36, outer, land)
    g = edit(g, [(16, 27, ",,,,,"), (15, 28, ",~~~~~,"), (15, 29, ",~~~~~,"), (16, 30, ",,,,,"),  # le lac noir de la salle sud
                 (14, 10, "#"), (22, 10, "#"), (14, 16, "#"), (22, 16, "#"),  # colonnes de la nef
                 (6, 3, "#"), (30, 3, "#"), (3, 21, "#"), (33, 21, "#"),  # ossuaires des chapelles
                 (18, 13, "G"), (5, 19, "G"), (31, 19, "G"), (18, 17, "S"),
                 (6, 5, "P"), (30, 5, "P"), (18, 7, "P"), (18, 22, "P"), (12, 29, "P"), (24, 29, "P"),
                 (3, 12, "E"), (33, 12, "E"), (18, 33, "E"),
                 (4, 7, "C"), (8, 3, "C"), (28, 3, "C"), (32, 7, "C"), (15, 11, "C"), (21, 11, "C"), (12, 15, "C"), (24, 15, "C"), (18, 9, "C"),
                 (3, 17, "C"), (7, 22, "C"), (29, 17, "C"), (33, 22, "C"), (10, 27, "C"), (26, 27, "C"), (14, 32, "C"), (22, 32, "C"),
                 (18, 25, "C"), (5, 12, "C"), (31, 12, "C")])
    return carve(g, m, "cryptes_noyees")

def _shape_source(_g):
    # La Source : cratère circulaire (amphithéâtre), bassin de pluie au centre, huit colonnes en cercle,
    # quatre chapelles rondes en baies sur les diagonales, départ au sud.
    c = (15, 15)
    chap = [(5, 5), (25, 5), (5, 25), (25, 25)]
    outer = union(blob(*c, 12.5, 12.3, seed=91, amp=0.05), *[blob(*q, 4.3, 4.3, seed=92 + i, amp=0.05) for i, q in enumerate(chap)])
    g, m = _canvas(30, 30, outer, outer)
    g = edit(g, [(12, 12, ",,,,,,,"), (11, 13, ",,,,,,,,,"), (11, 14, ",,,,,,,,,"), (11, 15, ",,,,G,,,,"), (11, 16, ",,,,,,,,,"),
                 (11, 17, ",,,,,,,,,"), (12, 18, ",,,,,,,"),  # bassin de pluie (praticable), paratonnerre-mère au centre
                 (15, 7, "#"), (15, 23, "#"), (7, 15, "#"), (23, 15, "#"), (9, 9, "#"), (21, 9, "#"), (9, 21, "#"), (21, 21, "#"),  # colonnes
                 (15, 5, "E"), (11, 24, "E"), (15, 25, "S"),
                 (4, 4, "C"), (6, 6, "C"), (24, 4, "C"), (26, 6, "C"), (4, 26, "C"), (6, 24, "C"), (26, 26, "C"), (24, 24, "C"),
                 (4, 15, "C"), (26, 15, "C"), (12, 5, "C"), (18, 5, "C")])
    return carve(g, m, "la_source")

SHAPES = {"cryptes_noyees": _shape_cryptes, "la_source": _shape_source, "terrasses_noyees": _shape_terrasses, "foret_brume": _shape_foret, "cite_rouille": _shape_cite,
          "terrasses_rizieres_hautes": _shape_rizieres, "foret_mangrove_lanternes": _shape_mangrove,
          "cite_fonderie_canal": _shape_fonderie, "cryptes_ossuaire_pluies": _shape_ossuaire}

def shape_grid(mid, grid):
    return SHAPES[mid](grid) if mid in SHAPES else grid

# Secrets des cartes A (29/10/2026, demande du joueur) : même système que les cartes B (2 plaques, porte D, salle
# scellée « : », 2 gardiens nommés, reliquaires), posés APRÈS la mise en forme dans le vide au bord du contour : une
# salle de 3 × 3 cases dont l'anneau de vide devient mur, et une porte « D » à la place d'une case de contour.
# `door` = case de contour remplacée par la porte, `dir` = sens du sol vers la salle, `pad_right` = colonnes de vide
# ajoutées à droite (cryptes : la caverne ronde n'a pas assez de vide), `plates` = cases « . » (plaques éloignées,
# hors chemin principal, ni départ ni arène de boss ; accessibles depuis le départ).
A_SECRETS = {
 "terrasses_noyees": dict(id="bassin_vanne", skin="dalles de vanne + grille de bassin (habillage Terrasses)", door=(7, 31), dir=(-1, 0),
                          plates=[(13, 2), (19, 34)], names=["Vase", "Crue"]),
 "foret_brume": dict(id="cercle_brume", skin="pierres plates à rune + rideau de brume (habillage Forêt)", door=(5, 4), dir=(-1, 0),
                     plates=[(36, 19), (1, 11)], names=["Mousse", "Fougère"]),
 "cite_rouille": dict(id="salle_pompes", skin="plaques de pression rivetées + porte à volant (habillage Cité)", door=(5, 5), dir=(-1, 0),
                      plates=[(20, 1), (4, 37)], names=["Boulon", "Chaudron"]),
 "cryptes_noyees": dict(id="chapelle_basse", skin="dalles d'os à glyphe de sel + grille d'ossuaire (habillage Cryptes)", door=(34, 7), dir=(1, 0),
                        pad_right=6, plates=[(3, 10), (20, 32)], names=["Algue", "Nef"]),
}

def add_a_secret(g, sp):
    """Pose le secret `sp` sur la grille mise en forme `g` ; retourne (grille, entrée `secrets`)."""
    if sp.get("pad_right"):
        g = pad(g, right=sp["pad_right"], fill=VOID)
    g = [list(r) for r in g]
    H, W = len(g), len(g[0])
    x, y = sp["door"]; dx, dy = sp["dir"]; px, py = abs(dy), abs(dx)
    assert g[y][x] == "#" and g[y - dy][x - dx] == ".", (sp["id"], "porte hors contour")
    cells = [(x + dx * d + px * s, y + dy * d + py * s) for d in (1, 2, 3) for s in (-1, 0, 1)]
    rs = set(cells)
    for (cx, cy) in cells:
        assert g[cy][cx] == VOID, (sp["id"], "salle hors du vide", cx, cy)
    for (cx, cy) in cells:
        for i in (-1, 0, 1):
            for j in (-1, 0, 1):
                n = (cx + i, cy + j)
                if n in rs or n == (x, y):
                    continue
                assert 0 <= n[0] < W and 0 <= n[1] < H and g[n[1]][n[0]] in VOID + "#", (sp["id"], "anneau de la salle", n)
                g[n[1]][n[0]] = "#"
    for s in (-1, 1):
        assert g[y + py * s][x + px * s] in VOID + "#", (sp["id"], "flanc de porte")
        g[y + py * s][x + px * s] = "#"
    for (cx, cy) in cells:
        g[cy][cx] = ":"
    g[y][x] = "D"
    for (cx, cy) in sp["plates"]:
        assert g[cy][cx] == ".", (sp["id"], "plaque hors sol", cx, cy)
    entry = dict(id=sp["id"], kind="sealed_door", skin=sp["skin"], door_cells=[[x, y]], room_cells=[list(c) for c in cells],
                 plates_u=[[2 * cx + 1, 2 * cy + 1] for cx, cy in sp["plates"]],
                 guardians_u=[[2 * cells[i][0] + 1, 2 * cells[i][1] + 1] for i in (3, 8)],
                 guardian_names=sp["names"], reward="2 reliquaires (table gardien)")
    return ["".join(r) for r in g], entry

# Emplacements des déclencheurs de secret autres que les plaques (29/10/2026) : levier caché dans un recoin
# (« interagir »), pilier éteint loin de la salle (rester dans son cercle). Cases « . » accessibles du départ, loin de la
# porte, hors départ, coffres et piliers de boss. Le mur fissuré est la porte « D » elle-même. Le tirage du déclencheur
# par run est dans FloorPlan.mark_secret (scripts/stage/floor_plan.gd) ; positions en cases de grille (x, y).
TRIGGER_SPOTS = {
 "terrasses_noyees": dict(lever=(27, 4), pillar=(29, 10)),
 "foret_brume": dict(lever=(24, 32), pillar=(4, 23)),
 "cite_rouille": dict(lever=(16, 43), pillar=(27, 26)),
 "cryptes_noyees": dict(lever=(1, 21), pillar=(11, 12)),
 "terrasses_rizieres_hautes": dict(lever=(23, 38), pillar=(2, 22)),
 "foret_mangrove_lanternes": dict(lever=(22, 29), pillar=(29, 27)),
 "cite_fonderie_canal": dict(lever=(27, 35), pillar=(23, 25)),
 "cryptes_ossuaire_pluies": dict(lever=(23, 40), pillar=(3, 28)),
}

ALL_MAPS = list(zip(MAPS, grids)) + [(m, m["grid"]) for m in NEW_MAPS]
for _m, _g in ALL_MAPS:
    _g = shape_grid(_m["id"], _g)
    if _m["id"] in A_SECRETS:
        _g, _sec = add_a_secret(_g, A_SECRETS[_m["id"]])
        _m["secrets"] = [_sec]
    if _m["id"] in TRIGGER_SPOTS:
        _ts = TRIGGER_SPOTS[_m["id"]]
        for _k, (_cx, _cy) in _ts.items():
            assert _g[_cy][_cx] == ".", (_m["id"], _k, "emplacement hors sol", _cx, _cy)
        _m["secrets"][0]["trigger_spots"] = {k: [[2 * cx + 1, 2 * cy + 1]] for k, (cx, cy) in _ts.items()}
    assert all(len(r) == len(_g[0]) for r in _g), (_m["id"], "rangées de longueurs différentes")
    _m["grid"] = _g
    _m["size"] = (2 * len(_g[0]), 2 * len(_g))
    _m.update(chests=markers(_g, "C"), small=markers(_g, "P"), big=markers(_g, "G"), events=markers(_g, "E"),
              spawn=markers(_g, "S")[0])

ROT45 = 0.785398163397448
NL = chr(10)

def rects(grid, chars):
    h, w = len(grid), len(grid[0])
    used = [[False]*w for _ in range(h)]
    out = []
    for y in range(h):
        for x in range(w):
            if grid[y][x] in chars and not used[y][x]:
                x2 = x
                while x2+1 < w and grid[y][x2+1] in chars and not used[y][x2+1]: x2 += 1
                y2 = y
                while y2+1 < h and all(grid[y2+1][i] in chars and not used[y2+1][i] for i in range(x, x2+1)): y2 += 1
                for yy in range(y, y2+1):
                    for xx in range(x, x2+1): used[yy][xx] = True
                out.append((x, y, x2-x+1, y2-y+1))
    return out

def main():
    warn = []
    # Arguments = ids à régénérer (défaut : toutes les cartes). Ex. : python tools/gen_maps.py cryptes_noyees la_source
    # --preview : affiche les grilles mises en forme et leurs surfaces sans rien écrire.
    ONLY = set(a for a in sys.argv[1:] if not a.startswith("--"))
    if "--preview" in sys.argv:
        for m in MAPS + NEW_MAPS:
            if ONLY and m["id"] not in ONLY:
                continue
            print(m["id"], m["size"], stats(m["grid"]))
            print("\n".join(m["grid"]))
        sys.exit(0)
    for m in MAPS + NEW_MAPS:
        grid = m["grid"]
        if ONLY and m["id"] not in ONLY:
            continue
        W, H = m["size"]
        assert all(len(r) == W//2 for r in grid) and len(grid) == H//2, (m["id"], len(grid), set(len(r) for r in grid))
        def chk(lst, ch):
            for (x, y) in lst:
                c = grid[y//2][x//2]
                if c != ch: warn.append(f'{m["id"]} {ch} ({x};{y}) -> cellule {c!r}')
        chk(m["chests"], "C"); chk(m["small"], "P"); chk(m["big"], "G"); chk(m["events"], "E"); chk([m["spawn"]], "S")
        ox, oy = W*U/2, H*U/2
        def P(x, y): return (x*U-ox, y*U-oy)
        out = ['[gd_scene format=3]', '', '[ext_resource type="Script" path="res://scripts/stage/stage_map.gd" id="1"]', '']
        shp = {}
        def shape(wpx, hpx):
            k = (wpx, hpx)
            if k not in shp: shp[k] = "s%d" % len(shp)
            return shp[k]
        solid = rects(grid, "#~" + VOID)
        shallow = rects(grid, ",")
        outer = [("OuterN", (W/2, -1), (W+4, 2)), ("OuterS", (W/2, H+1), (W+4, 2)),
                 ("OuterW", (-1, H/2), (2, H+4)), ("OuterE", (W+1, H/2), (2, H+4))]
        for (x, y, w, h) in solid: shape(w*2*U, h*2*U)
        # portes scellées : un rectangle par secret (boîte des cellules `door_cells`), nœud `Door_<id>` désactivable
        doors = []
        for sc in m.get("secrets", []):
            xs = [c[0] for c in sc["door_cells"]]; ys = [c[1] for c in sc["door_cells"]]
            dx, dy, dw, dh = min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
            assert dw * dh == len(sc["door_cells"]), (m["id"], sc["id"], "porte non rectangulaire")
            assert all(grid[cy][cx] == "D" for cx, cy in sc["door_cells"]), (m["id"], sc["id"], "cellule D manquante")
            doors.append((sc["id"], dx, dy, dw, dh)); shape(dw*2*U, dh*2*U)
        assert sum(r.count("D") for r in grid) == sum(len(sc["door_cells"]) for sc in m.get("secrets", [])), (m["id"], "D orphelin")
        for _, _, (a, b) in outer: shape(a*U, b*U)
        iso = m["id"] in ISO
        proj = "iso45" if iso else "flat"
        rot = 'rotation = %.15g\n' % ROT45 if iso else ''
        body = []
        body.append('[node name="StageMap" type="Node2D"]\n%sscript = ExtResource("1")\nmetadata/map_id = "%s"\nmetadata/size_u = Vector2(%d, %d)\n%s'
            % ('y_sort_enabled = true\n' if iso else '', m["id"], W, H, 'metadata/projection = "iso45"\n' if iso else ''))
        body.append('[node name="Visual" type="Node2D" parent="."]\n%s' % rot)
        body.append('[node name="Ground" type="TileMapLayer" parent="Visual"]\n')
        body.append('[node name="Decor" type="TileMapLayer" parent="Visual"]\n')
        # Sol, eau et falaises : peints à l'exécution par StageMap._build_ground (tuiles Blender).
        body.append('[node name="Obstacles" type="Node2D" parent="."]\n%s' % rot)
        body.append('[node name="Walls" type="StaticBody2D" parent="Obstacles"]\ncollision_layer = 1\ncollision_mask = 0\n')
        for i, (x, y, w, h) in enumerate(solid):
            cx, cy = P(x*2 + w, y*2 + h)
            body.append('[node name="Block%d" type="CollisionShape2D" parent="Obstacles/Walls"]\nposition = Vector2(%g, %g)\nshape = SubResource("%s")\n' % (i, cx, cy, shape(w*2*U, h*2*U)))
        for (sid, dx, dy, dw, dh) in doors:
            cx, cy = P(dx*2 + dw, dy*2 + dh)
            body.append('[node name="Door_%s" type="CollisionShape2D" parent="Obstacles/Walls"]\nposition = Vector2(%g, %g)\nshape = SubResource("%s")\n' % (sid, cx, cy, shape(dw*2*U, dh*2*U)))
        for n, (cx, cy), (a, b) in outer:
            p = P(cx, cy)
            body.append('[node name="%s" type="CollisionShape2D" parent="Obstacles/Walls"]\nposition = Vector2(%g, %g)\nshape = SubResource("%s")\n' % (n, p[0], p[1], shape(a*U, b*U)))
        body.append('[node name="Markers" type="Node2D" parent="."]\n%s' % rot)
        body.append('[node name="PlayerStart" type="Marker2D" parent="Markers" groups=["player_start"]]\nposition = Vector2(%g, %g)\n' % P(*m["spawn"]))
        for i, c in enumerate(m["chests"]):
            body.append('[node name="Chest%02d" type="Marker2D" parent="Markers" groups=["chest_spawn"]]\nposition = Vector2(%g, %g)\n' % ((i,)+P(*c)))
        for i, c in enumerate(m["small"]):
            body.append('[node name="PillarS%02d" type="Marker2D" parent="Markers" groups=["pillar_spawn", "pillar_small"]]\nposition = Vector2(%g, %g)\nmetadata/pillar_kind = "small"\n' % ((i,)+P(*c)))
        for i, c in enumerate(m["big"]):
            body.append('[node name="PillarG%02d" type="Marker2D" parent="Markers" groups=["pillar_spawn", "pillar_big"]]\nposition = Vector2(%g, %g)\nmetadata/pillar_kind = "big"\n' % ((i,)+P(*c)))
        for i, c in enumerate(m["events"]):
            body.append('[node name="Event%02d" type="Marker2D" parent="Markers" groups=["event_spawn"]]\nposition = Vector2(%g, %g)\n' % ((i,)+P(*c)))
        for sc in m.get("secrets", []):
            for i, c in enumerate(sc["plates_u"]):
                assert grid[c[1]//2][c[0]//2] == ".", (m["id"], sc["id"], "plaque hors sol", c)
                body.append('[node name="Plate_%s_%d" type="Marker2D" parent="Markers" groups=["secret_spawn"]]\nposition = Vector2(%g, %g)\nmetadata/secret_id = "%s"\nmetadata/role = "plate"\nmetadata/index = %d\n' % ((sc["id"], i) + P(*c) + (sc["id"], i)))
            for i, c in enumerate(sc["guardians_u"]):
                body.append('[node name="Guardian_%s_%d" type="Marker2D" parent="Markers" groups=["secret_spawn"]]\nposition = Vector2(%g, %g)\nmetadata/secret_id = "%s"\nmetadata/role = "guardian"\nmetadata/index = %d\nmetadata/guardian_name = "%s"\n' % ((sc["id"], i) + P(*c) + (sc["id"], i, sc["guardian_names"][i])))
            for k, role in (("lever", "lever"), ("pillar", "beacon")):
                for i, c in enumerate(sc.get("trigger_spots", {}).get(k, [])):
                    assert grid[c[1]//2][c[0]//2] == ".", (m["id"], sc["id"], k, "emplacement hors sol", c)
                    body.append('[node name="%s_%s_%d" type="Marker2D" parent="Markers" groups=["secret_spawn"]]\nposition = Vector2(%g, %g)\nmetadata/secret_id = "%s"\nmetadata/role = "%s"\nmetadata/index = %d\n' % ((role.capitalize(), sc["id"], i) + P(*c) + (sc["id"], role, i)))
            for (sid, dx, dy, dw, dh) in doors:
                if sid == sc["id"]:
                    body.append('[node name="DoorMark_%s" type="Marker2D" parent="Markers" groups=["secret_spawn"]]\nposition = Vector2(%g, %g)\nmetadata/secret_id = "%s"\nmetadata/role = "door"\nmetadata/size_u = Vector2(%d, %d)\n' % ((sid,) + P(dx*2 + dw, dy*2 + dh) + (sid, dw*2, dh*2)))
        for (w, h), n in shp.items():
            out.append('[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%g, %g)\n' % (n, w, h))
        out += body
        path = f'{G}/scenes/stage/maps/{m["id"]}.tscn'
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out))
        meta = dict(id=m["id"], name=m["name"], biome=m["biome"], scene=f'res://scenes/stage/maps/{m["id"]}.tscn',
            floor=m["floor"], **({"variant": m["variant"]} if "variant" in m else {}), size_u=list(m["size"]), size_px=[W*U, H*U], unit_px=U, projection=proj,
            origin="scène centrée sur (0,0) ; position_px = (coord_u - size_u/2) * 64 en repère carte"
                + (" ; repère logique = Rot(+45°) · carte" if iso else ""),
            floor_boss=m["boss"], floor_boss_name=m["boss_name"],
            grid_cell_u=2, grid=grid,
            player_start_u=list(m["spawn"]),
            candidates=dict(chests=[list(c) for c in m["chests"]], small_pillars=[list(c) for c in m["small"]],
                            big_pillars=[list(c) for c in m["big"]], events=[list(c) for c in m["events"]]),
            draw_rules=dict(dict(small_chests=8, large_chests=2, legendary_chance=0.25, small_pillars=2, big_pillars=1,
                min_pillar_distance_u=18, big_pillar_min_spawn_distance_u=20,
                pillar_walkable_ratio_min=0.70, pillar_zone_radius_u=dict(small=7, big=9),
                legendary_chest_min_spawn_distance_u=24, trapped_chest_min_spawn_distance_u=12), **m.get("rules", {})),
            events=dict(chance=0.6, max_per_floor=1, types=m["event_names"]),
            ambient_event=m["ambient"],
            monster_spawn=dict(margin_u=[2,4], allowed_cells=[".", ","], forbidden_cells=["#","~"," "]),
            **({"hour_shift_min": m["hour_shift_min"]} if "hour_shift_min" in m else {}),
            **({"secrets": m["secrets"]} if "secrets" in m else {}))
        os.makedirs(f"{G}/data/maps", exist_ok=True)
        # saut de ligne final : fichiers identiques à ceux de l'éditeur (pas de diff parasite)
        open(f'{G}/data/maps/{m["id"]}.json', "w", encoding="utf-8", newline=NL).write(json.dumps(meta, ensure_ascii=False, indent=1) + NL)
        print(m["id"], "blocs", len(solid), "shallow", len(shallow))
    print("WARN", len(warn)); print("\n".join(warn))

if __name__ == "__main__":
    main()
