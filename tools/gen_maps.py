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
 dict(id="terrasses_noyees", floor=1, name="Terrasses noyées", biome="terrasses", size=(56,64), boss="eclusier",
  boss_name="L'Éclusier",
  chests=[(37,3),(15,5),(41,9),(13,13),(41,13),(9,21),(47,21),(45,27),(21,31),(11,37),(15,41),(47,41),(7,49),(45,53),(7,57),(15,57),(31,57),(41,61)],
  small=[(45,5),(15,9),(7,25),(45,35),(19,49),(47,49),(23,61)],
  big=[(31,21),(23,35),(25,51)], events=[(41,7),(31,29),(33,53)], spawn=(31,31),
  ambient=dict(threshold_difficulty=2.5, name="Bassins débordants", effect="visuel : les cases ',' du sud s'élargissent d'1 u"),
  event_names={"autel_fortune":"lanterne de pierre","sanctuaire_risque":"bassin qu'on vide","marchand_ombre":"barque amarrée","coffre_piege":"coffre à demi immergé"}),
 dict(id="foret_brume", floor=2, name="Forêt-brume", biome="foret", size=(64,56), boss="cerf_lanterne",
  boss_name="Le Cerf-Lanterne",
  chests=[(11,3),(61,3),(49,9),(13,11),(51,15),(27,17),(55,21),(5,25),(25,31),(61,31),(17,39),(21,41),(55,43),(23,49),(59,51),(11,53),(31,53)],
  small=[(7,7),(59,7),(7,31),(49,33),(57,45),(5,51)],
  big=[(51,17),(25,21),(25,47)], events=[(17,7),(37,25),(27,43)], spawn=(37,29),
  ambient=dict(threshold_difficulty=4.0, name="Lucioles éteintes", effect="visuel : brume à 15 %, lanternes allumées"),
  event_names={"autel_fortune":"sanctuaire à lanterne","sanctuaire_risque":"cercle de champignons","marchand_ombre":"silhouette sous une racine","coffre_piege":"coffre couvert de mousse"}),
 dict(id="cite_rouille", floor=3, name="Cité de rouille", biome="cite", size=(48,80), boss="sonneur",
  boss_name="Le Sonneur",
  chests=[(7,3),(41,3),(35,5),(37,11),(7,13),(7,21),(37,21),(5,37),(43,37),(7,49),(41,49),(7,59),(41,59),(7,69),(39,69),(7,77),(39,77)],
  small=[(9,7),(37,7),(7,33),(41,33),(9,53),(37,55),(11,73),(35,73)],
  big=[(9,27),(39,27),(23,73)], events=[(13,11),(9,43),(23,69)], spawn=(25,45),
  ambient=dict(threshold_difficulty=4.0, name="Orage", effect="visuel : éclair de décor toutes les 10-20 s ; à Cataclysme le canal monte"),
  event_names={"autel_fortune":"lampe à vapeur","sanctuaire_risque":"vanne de pression","marchand_ombre":"guichet grillagé","coffre_piege":"caisse rivetée"}),
]
U = 64
# Projection (docs/Design_Isometrique.md §1.2, §3) : "iso45" = grille de carte tournée de +45° dans le repère
# logique (Visual, Obstacles et Markers portent la rotation ; grilles, positions et rectangles inchangés).
# Étages 1-3 (terrasses_noyees, foret_brume, cite_rouille) en iso (cite_rouille : lot F3, 22/10/2026).
ISO = {"terrasses_noyees", "foret_brume", "cite_rouille", "cryptes_noyees", "la_source"}
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
NEW_MAPS = [
 dict(id="cryptes_noyees", floor=4, name="Cryptes noyées", biome="cryptes", variant="A", size=(60,60), boss="recluse",
  boss_name="Le Reclus", grid=GRID_CRYPTES,
  ambient=dict(threshold_difficulty=2.5, name="Crue", effect="visuel : la crue monte (cases ',' élargies) ; Furieux : cristaux qui s'éteignent par vagues"),
  event_names={"autel_fortune":"reliquaire de cristal","sanctuaire_risque":"ossuaire scellé","marchand_ombre":"passeur sur le lac noir","coffre_piege":"sarcophage entrouvert"}),
 dict(id="la_source", floor=5, name="La Source", biome="source", variant="", size=(50,50), boss="rain_sower",
  boss_name="Le Semeur de pluie", grid=GRID_SOURCE,
  rules=dict(small_chests=6, large_chests=2, legendary_chance=1.0, small_pillars=0, big_pillars=1),
  ambient=dict(threshold_difficulty=4.0, name="Colonne de pluie", effect="visuel : la colonne de pluie centrale s'épaissit avec la difficulté"),
  event_names={"autel_fortune":"autel de la Source","sanctuaire_risque":"vasque de pluie","marchand_ombre":"pèlerin sous la colonne","coffre_piege":"offrande noyée"}),
]

def markers(grid, ch):
    return [(2*x+1, 2*y+1) for y, row in enumerate(grid) for x, c in enumerate(row) if c == ch]

for _m in NEW_MAPS:
    _g = _m["grid"]
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

warn = []
# Arguments = ids à régénérer (défaut : toutes les cartes). Ex. : python tools/gen_maps.py cryptes_noyees la_source
ONLY = set(sys.argv[1:])
for m, grid in list(zip(MAPS, grids)) + [(m, m["grid"]) for m in NEW_MAPS]:
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
    solid = rects(grid, "#~")
    shallow = rects(grid, ",")
    outer = [("OuterN", (W/2, -1), (W+4, 2)), ("OuterS", (W/2, H+1), (W+4, 2)),
             ("OuterW", (-1, H/2), (2, H+4)), ("OuterE", (W+1, H/2), (2, H+4))]
    for (x, y, w, h) in solid: shape(w*2*U, h*2*U)
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
        monster_spawn=dict(margin_u=[2,4], allowed_cells=[".", ","], forbidden_cells=["#","~"]))
    os.makedirs(f"{G}/data/maps", exist_ok=True)
    # saut de ligne final : fichiers identiques à ceux de l'éditeur (pas de diff parasite)
    open(f'{G}/data/maps/{m["id"]}.json', "w", encoding="utf-8", newline=NL).write(json.dumps(meta, ensure_ascii=False, indent=1) + NL)
    print(m["id"], "blocs", len(solid), "shallow", len(shallow))
print("WARN", len(warn)); print("\n".join(warn))
