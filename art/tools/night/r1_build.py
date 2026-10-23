"""R1: native 64 px/u cel rerenders, AV2 geometry and corrected A2 sources.
Run with system Python --archive, Blender --background --python this.py,
then system Python --verify. No gameplay files are written.
"""
import sys, json, math, re, hashlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
sys.dont_write_bytecode = True
sys.path[:0] = [str(ROOT/'art/tools/cel'), str(ROOT/'art/tools/iso'), str(HERE)]
if '--background' in sys.argv:
    sys.path[:0] = [str(ROOT/'art/tools/iso/_deps'), str(Path.home()/'AppData/Local/RainfallIsoDeps')]
import cel_style as cel
SPRITES = ROOT/'game/assets/sprites'
WORK = ROOT/'art/blender/cel/r1'
SPECS = {
    'crue_ring': dict(rel='characters/averse/effects/crue_ring', cell=800, old=1664, frames=8, slots=8, cols=2, capacity=4, stem='crue_ring'),
    'puddle_mirror': dict(rel='characters/averse/effects/puddle_mirror', cell=416, old=768, frames=6, slots=6, cols=2, capacity=6, stem='puddle_mirror'),
    'ardent_brasier': dict(rel='vfx/ardent_brasier', cell=1088, old=640, frames=12, slots=18, cols=3, capacity=9, stem='default', radius=384.0),
    'ardent_nova': dict(rel='vfx/ardent_nova', cell=616, old=512, frames=10, slots=14, cols=3, capacity=15, stem='default', radius=224.0),
}

def archive():
    for sp in SPECS.values():
        cel.archive_folder(sp['rel'])
    print('R1 ARCHIVE PASS (4 folders)')

def geometry_measure(scene, objects, cell):
    from bpy_extras.object_utils import world_to_camera_view
    points=[]
    for ob in objects:
        if ob.type != 'MESH' or ob.hide_render:
            continue
        for v in ob.data.vertices:
            q=ob.matrix_world@v.co; q.z=0
            p=world_to_camera_view(scene,scene.camera,q)
            points.append((p.x*cell,(1-p.y)*cell))
    xs,ys=zip(*points)
    w,h=max(xs)-min(xs),max(ys)-min(ys)
    return dict(radius_px=round(w/2,4),floor_aspect=round(h/w,6))

def pack(key):
    from PIL import Image
    sp=SPECS[key];cell=sp['cell'];dest=SPRITES/sp['rel']
    for page,start in enumerate(range(0,sp['slots'],sp['capacity'])):
        n=min(sp['capacity'],sp['slots']-start)
        cols=sp['cols'];rows=math.ceil(n/cols)
        for suffix in ('','_n','_e'):
            atlas=Image.new('RGBA',(cols*cell,rows*cell))
            for i in range(n):
                f=start+i
                if f>=sp['frames']:continue
                with Image.open(WORK/key/(f'{f:02d}'+suffix+'.png')) as im:
                    atlas.paste(im,(i%cols*cell,i//cols*cell))
            if suffix=='_n':
                # Assemble the contractual shared coverage channel. The legacy
                # normal compositor exports slightly different edge coverage.
                with Image.open(dest/f"{sp['stem']}_{page}.png") as diffuse:
                    atlas.putalpha(diffuse.getchannel('A'))
            atlas.save(dest/(f"{sp['stem']}_{page}{suffix}.png"),optimize=True,compress_level=9)
    update_resources(key)

def update_resources(key):
    """Keep original animation arrays, timings, IDs and unused legacy slots."""
    sp=SPECS[key];dest=SPRITES/sp['rel'];old=cel.ARCHIVE/sp['rel']
    for src in sorted(old.glob('*.tres')):
        text=src.read_text(encoding='utf-8');is_water=key in ('crue_ring','puddle_mirror')
        # Use old resource as template; replace atlas declarations and regions only.
        blocks=re.split(r'(?=\[sub_resource type="AtlasTexture")',text)
        header=blocks[0]
        if not is_water:
            declarations=[]
            for page in range(math.ceil(sp['slots']/sp['capacity'])):
                declarations.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/{sp["rel"]}/{sp["stem"]}_{page}.png" id="1_{page}"]')
            header=re.sub(r'\[ext_resource[^\n]+\]\s*','',header)
            header=header.rstrip()+'\n\n'+'\n'.join(declarations)+'\n\n'
        for i in range(1,len(blocks)):
            f=i-1;page=f//sp['capacity'];local=f%sp['capacity']
            c=sp['cell'];x=local%sp['cols']*c;y=local//sp['cols']*c
            blocks[i]=re.sub(r'region = Rect2\([^\n]+\)',f'region = Rect2({x}, {y}, {c}, {c})',blocks[i],count=1)
            if not is_water:
                blocks[i]=re.sub(r'atlas = ExtResource\("[^"]+"\)',f'atlas = ExtResource("1_{page}")',blocks[i],count=1)
        blocks[0]=header
        (dest/src.name).write_text(''.join(blocks),encoding='utf-8')

def material_profiles():
    import bpy
    # AV2's procedural cyan must remain the unique emission accent.
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        bsdf=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if bsdf and bsdf.inputs['Emission Strength'].default_value>.01:
            mat['rainfall_emissive']=True
    # Solid coal fragments use the prop profile; liquid, flame and soot use vfx.
    solids=[m for m in bpy.data.materials if m.use_nodes and 'charcoal' in m.name.lower()]
    others=[m for m in bpy.data.materials if m.use_nodes and m not in solids]
    if solids:
        for m in others:m.use_nodes=False
        cel.toon_materials('prop')
        for m in others:m.use_nodes=True
    cel.toon_materials('vfx')

def quantize_normals(key):
    """Quantize RGB in Blender, then assemble the original coverage channel.

    Blender's image round trip changes antialiased alpha by a few code values;
    coverage belongs to the diffuse, independently of normal quantization.
    """
    from PIL import Image
    paths=sorted((SPRITES/SPECS[key]['rel']).glob('*_n.png'))
    cel.quantize_normal_files(paths,work=WORK/key/'normal_quantization_shared_alpha')
    for path in paths:
        with Image.open(path) as src: normal=src.convert('RGBA')
        with Image.open(path.with_stem(path.stem[:-2])) as diffuse:
            normal.putalpha(diffuse.getchannel('A'))
        normal.save(path,optimize=True,compress_level=9)

def build():
    import bpy, iso_rig
    from mathutils import Vector
    import av2_build as av2
    measures={}
    for key,sp in SPECS.items():
        cell=sp['cell'];raw=WORK/key;raw.mkdir(parents=True,exist_ok=True)
        if key.startswith('ardent_'):
            bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'art/blender/vfx/a2_{key}.blend'))
            s=bpy.context.scene
            # Measure the corrected original bed, then scale world geometry to a true 64px/u rig.
            original=[]
            for f in range(1,sp['frames']+1):
                s.frame_set(f);bpy.context.view_layer.update()
                obs=[o for o in s.objects if o.name.startswith('Fractured incandescent')]
                original.append(geometry_measure(s,obs,sp['old'])['radius_px'])
            scale=sp['radius']/max(original)*iso_rig.R/64
            for ob in s.objects:
                if ob.type=='MESH':
                    for v in ob.data.vertices:v.co*=scale
                    ob.location*=scale
            iso_rig.set_frame(cell,'CREA');s.camera.data.ortho_scale=cell/64
            cel.install('vfx');material_profiles()
        else:
            s=iso_rig.create_rig('TOP',cell)
            s.camera.data.ortho_scale=cell/64
            mats=av2.materials();cel.install('vfx');material_profiles()
        s['R1_px_per_u']=64;s['R1_cel_profile']='vfx; solid coals prop'
        s['R1_pivot_relative']=[.5,.5]
        s.render.threads_mode='FIXED';s.render.threads=8
        frames=[]
        for f in range(sp['frames']):
            if key.startswith('ardent_'):
                s.frame_set(f+1);bpy.context.view_layer.update()
                floor=[o for o in s.objects if o.name.startswith('Fractured incandescent')]
            else:
                root=av2.geometry(key,f,sp['frames'],mats);bpy.context.view_layer.update()
                # Ground footprint is the water body, excluding airborne spray and foam.
                floor=[o for o in root.children_recursive if o.name.startswith(('Undercut rainwater crest','Black mirror puddle'))]
            frames.append(geometry_measure(s,floor,cell))
            iso_rig.render_frame(raw/f'{f:02d}.png')
            if not key.startswith('ardent_'):
                for ob in [*root.children_recursive,root]:bpy.data.objects.remove(ob,do_unlink=True)
        best=max(range(len(frames)),key=lambda i:frames[i]['radius_px'])
        measures[key]=dict(**frames[best],cell_px=cell,frames=sp['frames'],pivot_relative=[.5,.5],px_per_u=64,measured_frame=best,measurement='projected z=0 ground-body mesh bounds',per_frame=frames)
        pack(key)
        quantize_normals(key)
        print('R1 RENDER PASS '+key,flush=True)
    (HERE/'_r1_geometry.json').write_text(json.dumps(measures,indent=2),encoding='utf-8')

def verify():
    from PIL import Image, ImageChops
    # Pillow only crops, assembles and verifies; labels are omitted (no raster drawing).
    results={};canvas=Image.new('RGBA',(1920,1680),(18,22,23,255))
    ground=Image.open(SPRITES/'terrain/terraces/iso/ground_a.png').convert('RGBA')
    for row,(key,sp) in enumerate(SPECS.items()):
        dest=SPRITES/sp['rel'];old=cel.ARCHIVE/sp['rel']
        for p in dest.glob('*.png'):
            with Image.open(p) as im:assert max(im.size)<=4096,(p,im.size)
        occupied=[]
        for page,start in enumerate(range(0,sp['slots'],sp['capacity'])):
            path=dest/f'{sp["stem"]}_{page}.png'
            with Image.open(path) as im:
                alpha=im.getchannel('A')
                for su in ('_n','_e'):
                    with Image.open(path.with_stem(path.stem+su)) as companion:
                        assert companion.size==im.size
                        assert ImageChops.difference(alpha,companion.getchannel('A')).getbbox() is None,(key,su,'alpha')
                        if su=='_n':
                            colors={rgb[:3] for rgb in companion.convert('RGBA').getdata() if rgb[3]==255}
                            assert len(colors)<=27,(key,'normal colors',len(colors))
                for local in range(min(sp['capacity'],sp['slots']-start)):
                    c=sp['cell'];x=local%sp['cols']*c;y=local//sp['cols']*c
                    crop=im.crop((x,y,x+c,y+c));bbox=crop.getchannel('A').getbbox()
                    if start+local<sp['frames']:
                        assert bbox,(key,start+local,'empty')
                        assert min(bbox[:2])>=3 and max(bbox[2:])<=c-3,(key,start+local,'clipped',bbox)
                        occupied.append(hashlib.sha256(crop.tobytes()).hexdigest())
                    else:assert bbox is None,(key,'legacy padding')
        assert len(set(occupied))==sp['frames'],(key,'duplicate')
        # Three chronological samples, archive left/current right, true nighttime ground.
        for col,f in enumerate((0,sp['frames']//2,sp['frames']-1)):
            for side,base in enumerate((old,dest)):
                c=sp['old'] if side==0 else sp['cell']
                cap=(4 if key=='crue_ring' else 6 if key=='puddle_mirror' else sp['slots']) if side==0 else sp['capacity']
                cols=(2 if key in ('crue_ring','puddle_mirror','ardent_nova') else 3) if side==0 else sp['cols']
                page=f//cap;local=f%cap
                with Image.open(base/f'{sp["stem"]}_{page}.png') as im:
                    crop=im.crop((local%cols*c,local//cols*c,local%cols*c+c,local//cols*c+c)).convert('RGBA')
                crop.thumbnail((304,312),Image.Resampling.LANCZOS)
                cx=side*960+col*320+160;cy=row*360+180
                tile=ground.copy();tile.thumbnail((320,180),Image.Resampling.LANCZOS)
                canvas.alpha_composite(tile,(cx-tile.width//2,cy))
                canvas.alpha_composite(crop,(cx-crop.width//2,cy-crop.height//2))
        results[key]={'frames':sp['frames'],'unique_frames':len(set(occupied)),'cell':sp['cell'],'alpha_normal_emission':'identical','normal_colors':'<=27','clipping':'PASS','pivot':[.5,.5]}
    refs=['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png',
          'art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png']
    for i,ref in enumerate(refs):
        with Image.open(ROOT/ref) as im:
            thumb=im.convert('RGBA')
        if i==3:thumb=thumb.crop((thumb.width//2,0,thumb.width,thumb.height))
        thumb.thumbnail((480,240),Image.Resampling.LANCZOS)
        canvas.alpha_composite(thumb,(i*480+(480-thumb.width)//2,1440))
    canvas.convert('RGB').save(HERE/'_r1_contact.png',optimize=True)
    (HERE/'_r1_verification.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    print('R1 VERIFY PASS: 4 effects; frames, alpha, normals, padding, bounds; archive LEFT / cel RIGHT')

if __name__=='__main__':
    if '--archive' in sys.argv:archive()
    elif '--verify' in sys.argv:verify()
    elif '--repack' in sys.argv:
        for key,sp in SPECS.items():
            pack(key)
            quantize_normals(key)
    else:build()
