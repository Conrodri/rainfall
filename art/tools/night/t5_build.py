"""T5 lossless assembly. Python + Pillow: crop/assemble/verify only, no painting.
Preserves the contractual 192px sheets; optimizes runtime layer resources using
AtlasTexture.margin. Reuses T2/T3 SpriteFrames, camera, art and animation timings.
Run: python art/tools/night/t5_build.py
Audit Godot: --headless --path game --script <absolute path to t_out/t5/verify_resources.tres>
"""
from pathlib import Path
import hashlib
import json
import math
import re
import sys
from PIL import Image, ImageChops

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
GAME = ROOT/'game/assets/sprites/characters/tocsin'
OUT = ROOT/'art/tools/night/t_out/t5'
DIRS = ['e', 'se', 's', 'sw', 'w', 'nw', 'n', 'ne']
PASSES = ['', '_n', '_e']
PREFIX = 'res://assets/sprites/characters/tocsin/'


def shelf(rects, width):
    positions = {}
    x = y = line = 0
    for key, (w, h) in sorted(rects.items(), key=lambda item: (-item[1][1], -item[1][0], item[0])):
        if x+w > width:
            x = 0
            y += line
            line = 0
        positions[key] = (x, y)
        x += w
        line = max(line, h)
    return positions, y+line


def pack(layer, anim, layout=None):
    if layout is not None:
        # Contractual re-renders keep the existing atlas regions and deduplication.
        folder = GAME/'layers'/layer
        for suffix in PASSES:
            source = folder/(anim+suffix+'.png')
            if not source.exists():
                continue
            with Image.open(source) as src:
                sheet = src.convert('RGBA')
            atlas = Image.new('RGBA', tuple(layout['size']))
            for frame in layout['frames']:
                row = DIRS.index(frame['direction'])
                x0,y0,x1,y1 = frame['crop']
                x,y,w,h = frame['region']
                tile = sheet.crop((frame['frame']*192, row*192, (frame['frame']+1)*192, (row+1)*192))
                atlas.paste(tile.crop((x0,y0,x1,y1)), (x,y))
            atlas.save(folder/'packed'/(anim+suffix+'.png'), optimize=True, compress_level=9)
        return layout
    stem = GAME/'layers'/layer/anim
    sheets = {s: Image.open(str(stem)+s+'.png').convert('RGBA')
              for s in PASSES if Path(str(stem)+s+'.png').exists()}
    w, h = sheets[''].size
    assert w % 192 == 0 and h == 1536, (stem, w, h)
    assert all(im.size == (w, h) for im in sheets.values())
    frames, unique, rects = [], {}, {}
    for row, d in enumerate(DIRS):
        for i in range(w//192):
            region = (i*192, row*192, (i+1)*192, (row+1)*192)
            tiles = {s: im.crop(region) for s, im in sheets.items()}
            # Alpha of every pass participates: no loss of normals or emission.
            boxes = [im.getchannel('A').getbbox() for im in tiles.values()]
            boxes = [b for b in boxes if b]
            box = (max(0, min(b[0] for b in boxes)-4), max(0, min(b[1] for b in boxes)-4),
                   min(192, max(b[2] for b in boxes)+4), min(192, max(b[3] for b in boxes)+4)) if boxes else (0, 0, 1, 1)
            crops = {s: im.crop(box) for s, im in tiles.items()}
            key = hashlib.sha256(str(box).encode()+b''.join(crops[s].tobytes() for s in sheets)).hexdigest()
            if key not in unique:
                unique[key] = crops
                rects[key] = crops[''].size
            frames.append({'direction': d, 'frame': i, 'key': key, 'crop': list(box)})
    options = []
    for width in (128, 192, 256, 384, 512, 768, 1024, 1536, 2048):
        if width < max(v[0] for v in rects.values()):
            continue
        positions, height = shelf(rects, width)
        if height <= 4096:
            options.append((width*height, width, height, positions))
    _, width, height, positions = min(options, key=lambda o: (o[0], max(o[1:3])))
    packed = {s: Image.new('RGBA', (width, height)) for s in sheets}
    for key, crops in unique.items():
        for s, im in crops.items():
            packed[s].paste(im, positions[key])
    folder = stem.parent/'packed'
    folder.mkdir(exist_ok=True)
    for s, im in packed.items():
        im.save(folder/(anim+s+'.png'), optimize=True, compress_level=9)
    for f in frames:
        key = f.pop('key')
        x, y = positions[key]
        cw, ch = rects[key]
        f['region'] = [x, y, cw, ch]
        f['margin'] = [f['crop'][0], f['crop'][1], 192-cw, 192-ch]
        # Verify all visible pixels against the original for all three passes.
        for s, im in packed.items():
            restored = Image.new('RGBA', (192, 192))
            restored.paste(im.crop((x, y, x+cw, y+ch)), tuple(f['crop'][:2]))
            row = DIRS.index(f['direction'])
            original = sheets[s].crop((f['frame']*192, row*192, (f['frame']+1)*192, (row+1)*192))
            assert ImageChops.difference(restored.getchannel('A'), original.getchannel('A')).getbbox() is None, (layer, anim, s)
            difference = ImageChops.difference(restored.convert('RGB'), original.convert('RGB'))
            visible = original.getchannel('A').point(lambda a: 255 if a else 0).convert('RGB')
            assert ImageChops.multiply(difference, visible).getbbox() is None, (layer, anim, f, s)
    for im in sheets.values():
        im.close()
    return {'size': [width, height], 'source_size': [w, h], 'passes': list(packed),
            'unique_frames': len(unique), 'frames': frames,
            'bytes_before': w*h*4*len(packed), 'bytes_after': width*height*4*len(packed)}


def rewrite_resource(path, atlas):
    backup = OUT/'source_resources'/path.name
    if not backup.exists():
        backup.write_bytes(path.read_bytes())
    source = backup.read_text(encoding='utf-8')
    ext = dict(re.findall(r'path="([^"]+)" id="([^"]+)"', source))
    ids = {v: k for k, v in ext.items()}
    canvases = {}
    for match in re.finditer(r'\[sub_resource type="CanvasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', source, re.S):
        eid = re.search(r'diffuse_texture = ExtResource\("([^"]+)"\)', match[2])
        if eid and '/layers/' in ids[eid[1]]:
            rel = ids[eid[1]].split('/layers/')[1]
            layer, filename = rel.split('/')
            anim = filename.removesuffix('.png').removesuffix('_e')
            if (layer, anim) in atlas:
                canvases[match[1]] = atlas[layer, anim]

    def replace_frame(match):
        block = match[0]
        canvas = re.search(r'atlas = SubResource\("([^"]+)"\)', block)
        if not canvas or canvas[1] not in canvases:
            return block
        region = re.search(r'region = Rect2\(([^)]+)\)', block)
        x, y, w, h = [int(float(v)) for v in region[1].split(',')]
        assert w == h == 192
        data = canvases[canvas[1]]
        f = data['frames'][(y//192)*(data['source_size'][0]//192)+x//192]
        value = 'region = Rect2('+', '.join(map(str, f['region']))+')\nmargin = Rect2('+', '.join(map(str, f['margin']))+')'
        return block[:region.start()]+value+block[region.end():]

    source = re.sub(r'\[sub_resource type="AtlasTexture"[^\n]*\]\n.*?(?=\n\[|\Z)', replace_frame, source, flags=re.S)
    source = re.sub(r'(/layers/[^/]+)/([^/"\n]+\.png)', r'\1/packed/\2', source)
    assert canvases, path
    path.write_text(source, encoding='utf-8')


def audit_script():
    # T2 embedded GDScript resource pattern: no .gd or .tscn created.
    source = 'extends SceneTree\nfunc _initialize() -> void:\n    var failed := 0\n    var count := 0\n'
    for p in sorted(GAME.glob('*.tres')):
        uri = 'res://'+p.relative_to(ROOT/'game').as_posix()
        source += '    failed += check_frames('+json.dumps(uri)+')\n    count += 1\n'
    source += '    print("T5_RESOURCES: ", count, " loaded; errors=", failed)\n    quit(0 if failed == 0 else 1)\n'
    source += '''func check_frames(path: String) -> int:
    var sf = ResourceLoader.load(path)
    if not sf is SpriteFrames:
        push_error(path)
        return 1
    for anim in sf.get_animation_names():
        if sf.get_frame_count(anim) == 0:
            return 1
        for i in range(sf.get_frame_count(anim)):
            var t = sf.get_frame_texture(anim, i)
            if t == null or t.get_width() != 192 or t.get_height() != 192:
                push_error(path + ": invalid logical frame " + anim)
                return 1
            if not t is AtlasTexture or not t.atlas is CanvasTexture:
                return 1
    return 0
'''
    (OUT/'verify_resources.tres').write_text('[gd_resource type="GDScript" format=3]\n\n[resource]\nscript/source = '+json.dumps(source)+'\n')


def contact():
    # One final control board; all panels are existing renders, never Pillow art.
    board = Image.new('RGBA', (1536, 1152), (22, 26, 30, 255))
    for col, d in enumerate(DIRS):
        with Image.open(GAME/'idle.png') as im:
            board.alpha_composite(im.crop((0, col*192, 192, (col+1)*192)), (col*192, 0))
    for col, anim in enumerate(['walk', 'hop_l', 'handwalk', 'crawl_l', 'roll', 'attack', 'cast_ult', 'death']):
        with Image.open(GAME/(anim+'.png')) as im:
            frame = min(im.width//192-1, 3)
            board.alpha_composite(im.crop((frame*192, 384, (frame+1)*192, 576)), (col*192, 192))
    manifest = json.loads((GAME/'layers_order.json').read_text())
    for col, layer in enumerate(manifest['layers']):
        with Image.open(GAME/'layers'/layer/'idle.png') as im:
            board.alpha_composite(im.crop((0, 384, 192, 576)), (col*192, 384))
    for col, name in enumerate(['arm_fly', 'arm_clamp', 'leg_fly', 'head_fly', 'head_blast', 'head_blast_top', 'regen_rivets']):
        path = GAME/(name+'.png')
        if path.exists():
            with Image.open(path) as im:
                x = min(3, im.width//192-1)*192
                y = 384 if im.height >= 576 else 0
                board.alpha_composite(im.crop((x, y, x+192, y+192)), (col*192, 576))
    refs = ['art/tools/characters/_cd_tocsin.png', 'art/tools/iso/_c4_contact.png',
            'art/tools/characters/_m2_contact.png', 'art/tools/iso/_c1_contact.png']
    for col, ref in enumerate(refs):
        path = ROOT/ref
        if path.exists():
            with Image.open(path) as im:
                tile = im.convert('RGBA')
                tile.thumbnail((384, 384))
                board.alpha_composite(tile, (col*384, 768))
    board.save(ROOT/'art/tools/night/_t5_contact.png', optimize=True, compress_level=9)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT/'source_resources').mkdir(exist_ok=True)
    manifest = json.loads((GAME/'layers_order.json').read_text())
    atlas = {}
    for layer in manifest['layers']:
        for path in sorted((GAME/'layers'/layer).glob('*.png')):
            if path.stem.endswith(('_n', '_e')):
                continue
            atlas[layer, path.stem] = pack(layer, path.stem)
        print('PASS packed '+layer, flush=True)
    for layer in manifest['layers']:
        for suffix in ['', '_emission']:
            path = GAME/('tocsin_'+layer+suffix+'.tres')
            if path.exists():
                rewrite_resource(path, atlas)
    before = sum(d['bytes_before'] for d in atlas.values())
    after = sum(d['bytes_after'] for d in atlas.values())
    manifest.update({'format_version': 2, 'logical_cell': [192, 192],
                     'atlas_format': 'packed rectangles; AtlasTexture.region + margin reconstructs 192x192',
                     'atlas_manifest': 'atlas_manifest.json', 'layer_resources': {
                         k: {'diffuse_normal': f'tocsin_{k}.tres',
                             'emission': f'tocsin_{k}_emission.tres' if (GAME/f'tocsin_{k}_emission.tres').exists() else None}
                         for k in manifest['layers']},
                     'attack_impact': {'frame': 3, 'indexing': 'zero_based', 'frames': 6},
                     'throw_release_frames': {'throw_arm_l': 2, 'throw_arm_r': 2,
                                              'throw_leg_l': 2, 'throw_leg_r': 2, 'throw_head': 3},
                     'pixel_roundtrip': 'PASS', 'raw_runtime_layer_MiB': round(after/2**20, 3),
                     'raw_legacy_layer_MiB': round(before/2**20, 3)})
    (GAME/'layers_order.json').write_text(json.dumps(manifest, indent=2)+'\n')
    packed_manifest = {layer+'/'+anim: d for (layer, anim), d in atlas.items()}
    (GAME/'atlas_manifest.json').write_text(json.dumps(packed_manifest, separators=(',', ':'))+'\n')
    audit_script()
    contact()
    summary = {'result': 'PASS', 'layer_animations': len(atlas),
               'frames': sum(len(d['frames']) for d in atlas.values()),
               'unique_frames': sum(d['unique_frames'] for d in atlas.values()),
               'before_MiB': round(before/2**20, 3), 'after_MiB': round(after/2**20, 3),
               'reduction_percent': round(100*(1-after/before), 2), 'roundtrip': 'exact alpha and all RGB pixels with nonzero alpha, all passes'}
    (OUT/'audit.json').write_text(json.dumps(summary, indent=2)+'\n')
    integration_doc(manifest, summary)
    print(json.dumps(summary), flush=True)


def integration_doc(manifest, summary):
    """Exact consumer contract; no gameplay or scene changes."""
    inventory = {}
    for path in sorted(GAME.glob('*.tres')):
        source = path.read_text(encoding='utf-8')
        inventory[path.name] = re.findall(r'"name":\s*&?"([^"]+)"', source)
    (GAME/'resource_animations.json').write_text(json.dumps(inventory, indent=2)+'\n')
    (GAME/'FORMAT_T5.md').write_text('''# Tocsin : contrat des ressources T5

## Chargement et placement
Lire `layers_order.json` (format_version 2). `layers` contient exactement les sept
modules. `layer_resources[layer].diffuse_normal` est un SpriteFrames ; `emission`
est son SpriteFrames lumineux synchronisé, à multiplier par la couleur/intensité
de surchauffe (1 à 2). `_e` est un masque coloré de braise, pas une normal map.
Chaque frame diffuse est AtlasTexture -> CanvasTexture(diffuse_texture,
normal_texture). CanvasTexture ne possède pas de propriété emission_texture :
afficher la ressource emission dans un sprite superposé avec le matériau du jeu.

Directions en lignes : e, se, s, sw, w, nw, n, ne. Noms exacts : `<anim>_<dir>`.
`resource_animations.json` inventorie chaque animation de chaque .tres ; les VFX
à direction unique utilisent leurs noms existants, sans suffixe ajouté.
Cadence et loop sont ceux des SpriteFrames ; ne pas imposer une cadence globale.
Synchroniser animation, frame et progression de tous les sprites visibles.
`animations[anim]` du manifeste indique les modules autorisés pour cet état.
Les membres absents sont masqués ; neck_steam apparaît seulement sans tête.
`orders[dir]` donne l'ordre arrière vers avant : indice croissant = z_index local.

Toutes les frames logiques font 192 x 192, pivot au sol (96, 136.32), identique
au rig Ardent. Sprite centré : offset = (0, -40.32) pour placer ce pivot à
l'origine du parent ; sprite non centré : position = (-96, -136.32).
Élévation CREA 30 degrés, R = 64*sqrt(2) = 90.51 px/u. Aucun agrandissement
des cellules : conserver l'échelle du rig, sans ajouter de marge de rendu.

## Atlas et conservation du cadre
Les planches contractuelles `<anim>.png`, `_n.png`, `_e.png` restent disponibles
en grille 192 ; les .tres des modules utilisent `layers/<layer>/packed/`.
Le rognage est identique pour diffuse, normal et émission. AtlasTexture.region
est le rectangle physique ; AtlasTexture.margin = (crop_x, crop_y,
192-region_width, 192-region_height) reconstitue le cadre logique complet.
Ne pas appliquer un deuxième décalage de rognage dans le code.
`atlas_manifest.json` : clés `layer/anim`, size, source_size, passes, frames.
Chaque frame donne direction, frame (base zéro), crop (x0,y0,x1,y1), region
(x,y,w,h) et margin (x,y,total_horizontal,total_vertical).
Les frames identiques peuvent partager un rectangle. Taille maximale 4096.

## Événements et assets séparés
Auto attack : 6 frames, impact index 3 = N/2 (base zéro).
throw_arm_l/r et throw_leg_l/r : libération index 2 ; throw_head : index 3.
death et cast/cast_ult sont fournis en huit directions. Utiliser les événements
du gameplay pour masquer les membres ; aucune rotation/pivot de membre à calculer.
fall se joue à l'envers pour se relever. Les membres détachés, head_blast,
head_blast_top et regen_rivets sont des ressources séparées, jamais des modules.
Les ressources tocsin.tres et tocsin_emission.tres sont le repli corps complet ;
ne pas les superposer au rendu modulaire. Les icônes et portraits T4 sont conservés.

## Reconstruction et vérification
`python art/tools/night/t5_build.py` reconstruit les atlas depuis les planches
existantes et les .tres depuis les sauvegardes t_out/t5/source_resources.
Le contrôle reconstruit chaque frame et compare alpha et RGB visibles sur les
trois passes. Les pixels RGB entièrement transparents ne participent pas.
Audit Godot : `--headless --path game --script` suivi du chemin ABSOLU vers
`art/tools/night/t_out/t5/verify_resources.tres` (ce fichier est hors de res://).
Les sept modules sont complets et isolés ; l'occlusion est déterminée par
l'ordre de profondeur des racines du rig, sans découpe holdout dynamique.
''', encoding='utf-8')
    sizes = []
    for path in GAME.rglob('*.png'):
        with Image.open(path) as im:
            assert max(im.size) <= 4096, (path, im.size)
            sizes.append(im.size)
    summary['texture_count'] = len(sizes)
    summary['max_texture_side'] = max(max(s) for s in sizes)
    (OUT/'audit.json').write_text(json.dumps(summary, indent=2)+'\n')


if __name__ == '__main__':
    main()
