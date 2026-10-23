"""T6: exact T1/T2 sockets, forged rivet and 4u TOP pressure marks.
Run with Blender 5.2 --background --python this file. No interactive scene touched.
Pillow only packs, crops and checks images. T4 geometry/poses are reused verbatim
except the corrected TOP extent; all pre-existing clip names/timing are retained.
"""
import sys, math, json, re, inspect, hashlib
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
import t4_build as t4
import t2_build as base
import t1_build as t1
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
from PIL import Image

OUT = ROOT/'art/tools/night/t_out/t6'
GAME = base.GAME
SUFFIXES = ('', '_n', '_e')
TOP_SIZE = 1032  # diameter 8u * 128px/u, plus four pixels each side
OUT.mkdir(parents=True, exist_ok=True)


def setup():
    t4.OUT = OUT
    t4.setup()
    t4.reset_parts()


def render(name, rig='TOP', size=TOP_SIZE):
    """Use the T1 compositor, explicitly retain TOP px/u (T1.frame is CREA)."""
    scene = bpy.context.scene
    t1.OUT = OUT
    def frame(s, shift=0):
        base.iso_rig.set_frame(s, rig)
        scene.camera.data.shift_x = scene.camera.data.shift_y = shift
    old = t1.frame
    t1.frame = frame
    try:
        scene.eevee.taa_render_samples = 8
        return t1.render(name, size, 0, passes=True)
    finally:
        t1.frame = old


def pack(name, count, size, folder=None):
    target = GAME/folder if folder else GAME
    target.mkdir(parents=True, exist_ok=True)
    cols = min(count, 4096//size)
    rows = math.ceil(count/cols)
    assert max(cols*size, rows*size) <= 4096
    for suffix in SUFFIXES:
        atlas = Image.new('RGBA', (cols*size, rows*size))
        for i in range(count):
            with Image.open(OUT/name/f'{i:02d}{suffix}.png') as im:
                assert im.size == (size, size)
                assert im.getchannel('A').getbbox(), (name, i, suffix)
                atlas.paste(im, ((i%cols)*size, (i//cols)*size))
        atlas.save(target/f'{name}{suffix}.png', optimize=True, compress_level=9)
    return cols


def new_resource(name, count, size, cols, fps=12):
    uri = 'res://assets/sprites/characters/tocsin/'+name+'/'+name
    blocks = [f'[ext_resource type="Texture2D" path="{uri}.png" id="1"]',
              f'[ext_resource type="Texture2D" path="{uri}_n.png" id="2"]',
              '[sub_resource type="CanvasTexture" id="canvas"]\ndiffuse_texture = ExtResource("1")\nnormal_texture = ExtResource("2")']
    for i in range(count):
        blocks.append(f'[sub_resource type="AtlasTexture" id="f{i}"]\natlas = SubResource("canvas")\nregion = Rect2({i%cols*size}, {i//cols*size}, {size}, {size})')
    frames = ', '.join('{"duration": 1.0, "texture": SubResource("f'+str(i)+'")}' for i in range(count))
    animation = '{"frames": ['+frames+'], "loop": true, "name": &"default", "speed": '+str(float(fps))+'}'
    text = '[gd_resource type="SpriteFrames" load_steps='+str(count+4)+' format=3]\n\n'+'\n\n'.join(blocks)+'\n\n[resource]\nanimations = ['+animation+']\n'
    (GAME/name/f'{name}.tres').write_text(text, encoding='utf-8')


def sockets():
    base.OUT = OUT
    base.configure()
    scene = base.scene
    base.iso_rig.create_rig('CREA', 192, reset=False)
    scene.camera.data.shift_y = .21
    keys = [k for k in base.PARTS if k != 'torso']
    result = {'version': 1, 'cell_size': [192,192], 'pivot_px': [96,136.32],
              'coordinates': 'pixels in logical cell; origin top-left, +x right, +y down',
              'rig': 'T1 modular roots / T2 poses; CREA 30 degrees',
              'socket_names': keys, 'source_clips': {'idle':'idle','run':'walk'},
              'animations': {}}
    for exported, source in [('idle','idle'), ('run','walk')]:
        directions = {}
        for direction, angle in base.DIRS.items():
            frames = []
            for i in range(base.ANIMS[source]):
                base.pose(source, i)
                base.root.rotation_euler.z = angle
                bpy.context.view_layer.update()
                frame = {}
                for key in keys:
                    p = world_to_camera_view(scene, scene.camera, base.mods[key].matrix_world.translation)
                    frame[key] = [round(p.x*192,4), round((1-p.y)*192,4)]
                assert all(0 <= v <= 192 for pair in frame.values() for v in pair)
                frames.append(frame)
            directions[direction] = frames
        result['animations'][exported] = directions
    (GAME/'sockets.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')


def rivet():
    setup()
    cd = t4.cd
    iron = bpy.data.materials['Pitted black iron']
    brass = bpy.data.materials['Worn brass rivet heads']
    ember = bpy.data.materials['Single accent / furnace orange']
    ob = cd.empty('T6 forged rivet / +X', (0,0,0))
    # Native CREA density: 35px long, 14px crown and 4-8px AA-safe margins.
    ob.location.x = -.025
    cd.cyl('Oxide crust shank',(-.12,0,0),(.13,0,0),.037,iron,ob,vertices=16)
    cd.cyl('Sheared incandescent point',(.13,0,0),(.22,0,0),.037,ember,ob,vertices=12,r2=.006)
    cd.cyl('Peened octagonal crown',(-.17,0,0),(-.12,0,0),.077,brass,ob,vertices=8,r2=.060)
    cd.cyl('Furnace seam',(-.118,0,0),(-.097,0,0),.039,ember,ob,vertices=16)
    for j in range(3):
        a = j*math.tau/3+.3
        cd.tube('Longitudinal cooling fissure '+str(j),
                [(-.08, .037*math.sin(a), .037*math.cos(a)),
                 (.03, .038*math.sin(a+.13), .038*math.cos(a+.13)),
                 (.125, .037*math.sin(a), .037*math.cos(a))], .0025,ember,ob)
    base.iso_rig.create_rig('CREA', 56, reset=False)
    for i in range(4):
        ob.rotation_euler.x = i*math.tau/4
        ember.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value = [2.3,2.7,2.3,1.9][i]
        render(f'rivet/{i:02d}', 'CREA', 56)
    cols = pack('rivet',4,56,'rivet')
    new_resource('rivet',4,56,cols)


def ring():
    setup()
    cd = t4.cd
    iron = bpy.data.materials['Pitted black iron']
    bronze = next(m for m in bpy.data.materials if m.name.startswith('Bell bronze weathered'))
    ember = bpy.data.materials['Single accent / furnace orange']
    root = cd.empty('T6 four metre resonant pressure engraving',(0,0,0))
    # Broken concentric lathe scars; a restrained orange cut through worn metal.
    for j in range(12):
        a = j*math.tau/12
        angles = [a+.025+k*(math.tau/12-.05)/32 for k in range(33)]
        for radius, width, mat in [(3.988,.012,ember),(3.93,.011,bronze)]:
            cd.tube('Fractured bell harmonic %d %.3f'%(j,radius),
                    [(radius*math.cos(t),radius*math.sin(t),.012) for t in angles], width,mat,root)
        # The twelve short peened registration cuts echo the bell construction.
        for k in range(3):
            angle = a+(k-1)*.009
            cd.tube('Foundry registration %d %d'%(j,k),
                    [(r*math.cos(angle),r*math.sin(angle),.01) for r in (3.80,3.88)], .009,
                    iron if k else bronze,root)
    base.iso_rig.create_rig('TOP', TOP_SIZE, reset=False)
    for i in range(6):
        pulse = .5-.5*math.cos(i*math.tau/6)
        # Pulse in heat only: boundary always denotes exactly the 4u hit radius.
        ember.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value = 1.15+1.7*pulse
        render(f'head_ring/{i:02d}')
    cols = pack('head_ring',6,TOP_SIZE,'head_ring')
    new_resource('head_ring',6,TOP_SIZE,cols,12)


def update_blast_regions(cols):
    # Preserve every existing animation, frame index, speed and external name.
    for path in GAME.glob('*.tres'):
        text = path.read_text(encoding='utf-8')
        if 'head_blast_top' not in text or 'head_blast_top.png' not in text and 'head_blast_top_e.png' not in text:
            continue
        is_combined = 'path="res://assets/sprites/characters/tocsin/head_blast.png"' in text or 'path="res://assets/sprites/characters/tocsin/head_blast_e.png"' in text
        def change(m):
            block = m.group(0)
            if is_combined and 'atlas = SubResource("c_head_blast_top")' not in block:
                return block
            index = int(re.search(r'id="[^"\n]*_(\d+)"',block).group(1))
            return re.sub(r'region = Rect2\([^\n]+\)',
                          f'region = Rect2({index%cols*TOP_SIZE}, {index//cols*TOP_SIZE}, {TOP_SIZE}, {TOP_SIZE})',block)
        updated = re.sub(r'\[sub_resource type="AtlasTexture"[^\[]+',change,text)
        if updated != text:
            path.write_text(updated,encoding='utf-8')


def blast():
    # Reuse the actual T4 builder without writing its CREA clip or .blend file.
    source = inspect.getsource(t4.blast)
    replacements = {
        "[('TOP','head_blast_top','top'),('CREA','head_blast','s')]": "[('TOP','head_blast_top','top')]",
        "base.iso_rig.create_rig(rig,192,reset=False)": "base.iso_rig.create_rig(rig,1032,reset=False); effect.scale=(3.96/.7,)*3",
        'q=i/7': 'q=min(1,i/6)',
        'r=.04+q*v*.72': 'r=.04+q*v*.60',
        'r=.03+q*v*.83': 'r=.03+q*v*.65',
        '(.18+.82*q,.18+.82*q,': '(.18+.72*q,.18+.72*q,',
        '(.15+.9*q,.15+.9*q,1)': '(.15+.85*q,.15+.85*q,1)',
        'ob.hide_render=i==7': 'ob.hide_render=False',
        "tile(f'{anim}/{d}/{i:02d}',rig,0 if rig=='TOP' else .10)": "t6_render(f'{anim}/{i:02d}',rig)",
        'assemble(anim,8,[d])': "t6_pack()",
        "bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/characters/tocsin_t4_blast.blend'))": 'pass',
        "if all(path.with_name(path.stem+s+'.png').exists() for s in ('','_n')) and 'refresh' not in sys.argv: continue": 'pass',
    }
    for old,new in replacements.items():
        assert old in source, old
        source = source.replace(old,new)
    t4.OUT=OUT
    scope = vars(t4)
    scope.update(t6_render=render,t6_pack=lambda: update_blast_regions(pack('head_blast_top',8,TOP_SIZE)))
    exec(compile(source, str(__file__)+'::reused_T4', 'exec'),scope)
    scope['blast']()


def contact():
    board = Image.new('RGBA',(1536,1152),(17,22,24,255))
    # Row 1: projectile native size + both technical passes; T1 scale reference.
    for col,suffix in enumerate(SUFFIXES):
        with Image.open(OUT/'rivet'/f'01{suffix}.png') as im:
            board.alpha_composite(im,(col*192+72,60))
    for i in range(6):
        with Image.open(OUT/'head_ring'/f'{i:02d}.png') as im:
            im.thumbnail((256,256)); board.alpha_composite(im,(i*256,160))
    for i in range(8):
        with Image.open(OUT/'head_blast_top'/f'{i:02d}.png') as im:
            im.thumbnail((192,192)); board.alpha_composite(im,(i*192,432))
    refs = ['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png',
            'art/tools/iso/_c1_contact.png','art/tools/night/_t1_contact.png']
    for i,path in enumerate(refs):
        with Image.open(ROOT/path) as im:
            im=im.convert('RGBA'); im.thumbnail((384,380));board.alpha_composite(im,(i*384,752))
    for col,suffix in enumerate(('_n','_e')):
        with Image.open(OUT/'head_blast_top'/f'06{suffix}.png') as im:
            im.thumbnail((128,128)); board.alpha_composite(im,(768+col*160,16))
    board.save(ROOT/'art/tools/night/_t6_contact.png',optimize=True,compress_level=9)


def main():
    if '--rivet-only' in sys.argv:
        rivet()
        contact()
        print('T6 RIVET PASS: native CREA density, AA-safe margins',flush=True)
        return
    if '--blast-only' not in sys.argv:
        sockets()
        rivet()
        ring()
    blast()
    contact()
    print('T6 PASS: 18 rendered cells, aligned D/N/E; TOP radius 512px; 128 socket poses / 6 roots; atlas <=3096px',flush=True)


if __name__ == '__main__':
    main()
