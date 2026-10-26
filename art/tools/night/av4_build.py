"""AV4: R1 TOP contracts; sculpted calm mirror / breaking flood. No gameplay edits.
Blender --background --python art/tools/night/av4_build.py ; python ... --verify.
Pillow only resizes, assembles and inspects Blender renders.
"""
import sys, math, random, re, json, hashlib
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(ROOT/'art/tools/iso'), str(ROOT/'art/tools/cel')]
WORK = ROOT/'art/blender/characters/averse_av4_frames'
SPRITES = ROOT/'game/assets/sprites'
SPECS = {'puddle_mirror': (416, 6, 6, 150.3751), 'crue_ring': (800, 8, 4, 374.6283)}

def folder(key, variant='averse'):
    return SPRITES/f'characters/{variant}/effects/{key}'

def material(name, color, emission=0):
    import bpy
    from cd_cd1_common import rgb
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=rgb(color)
    p.inputs['Roughness'].default_value=.28
    if emission:
        p.inputs['Emission Color'].default_value=rgb('5FD4E8')
        p.inputs['Emission Strength'].default_value=emission
        m['rainfall_emissive']=True
    return m

def puddle(f):
    from av2_build import mesh, empty, tube
    root=empty('AV4 calm rain mirror')
    dark=material('Still blue grey sky', '1E2B38')
    sky=material('Stretched slate cloud reflection', '354451')
    light=material('Rain sky silver reflection', '4B5A65')
    rim=material('Weak broken cyan bank', '5FD4E8', .11)
    mats=[dark,sky,light]
    # One unchanging organic outline; exact R1 bounding radius, no circular meniscus.
    seg=192
    edge=[]
    for j in range(seg):
        a=j*math.tau/seg
        r=1+.075*math.sin(3*a+.7)+.046*math.sin(7*a+1.3)+.028*math.cos(11*a)
        edge.append((r*math.cos(a),r*math.sin(a)))
    extent=(max(x for x,y in edge)-min(x for x,y in edge)+max(y for x,y in edge)-min(y for x,y in edge))/4
    scale=SPECS['puddle_mirror'][3]/64/extent
    edge=[(x*scale,y*scale) for x,y in edge]
    # Concentric topology only: coplanar, no raised rings; cloud bands cross the entire surface.
    verts=[(0,0,.018)]+[(x*k/20,y*k/20,.018) for k in range(1,21) for x,y in edge]
    faces=[(0,1+j,1+(j+1)%seg) for j in range(seg)]
    for k in range(19):
        for j in range(seg):
            a=1+k*seg+j; b=1+k*seg+(j+1)%seg
            faces.append((a,b,b+seg,a+seg))
    ob=mesh('Flat irregular water mirror',verts,faces,dark,root)
    ob.data.materials.append(sky); ob.data.materials.append(light)
    for poly in ob.data.polygons:
        x,y,_=tuple(sum(verts[i][c] for i in poly.vertices)/len(poly.vertices) for c in range(3))
        cloud=y+.09*math.sin(x*2+.1*math.sin(f*math.tau/6))
        poly.material_index=2 if .48<cloud<.67 or -.75<cloud<-.68 else (1 if -.45<cloud<.30 or cloud>1.25 else 0)
    for k in range(11):
        start=k*17+3
        pts=[(*edge[j%seg],.026) for j in range(start,start+9+(k%3))]
        tube('Single discontinuous bank glint',pts,.008,rim,root)
    # Off-centre tiny rain impacts, staggered in a perfectly periodic six-frame loop.
    rng=random.Random(41)
    for k in range(16):
        x,y=rng.uniform(-1.65,1.65),rng.uniform(-1.5,1.5)
        age=(f+k*2)%6
        if age>3: continue
        rr=.022+.022*age
        pts=[(x+rr*math.cos(a),y+rr*.76*math.sin(a),.035) for a in [j*math.tau/20 for j in range(21)]]
        tube('Ephemeral rain pinprick',pts,.005 if age>1 else .008,sky if age==3 else light,root)
    return root

def flood(f):
    from av2_build import mesh, empty, tube, bead
    root=empty('AV4 single outward breaker')
    water=material('Flood steel blue trough', '304C58')
    wall=material('Lifted slate water wall', '527784')
    foam=material('Broken white aerated crest', 'D4DDDC')
    cyan=material('Strong cyan crest accent', '5FD4E8', .9)
    # Match R1 frame-by-frame footprint; highest outward edge is the final 374.6283px.
    radii=[48.0296,95.1711,140.9311,188.6261,235.6678,281.4462,326.8695,374.6283]
    r=radii[f]/64
    width=min(r*.62,.64+.14*math.sin(f*.6))
    height=.18+.72*math.sin(math.pi*(.12+.82*f/7))
    rng=random.Random(230+f)
    for sector in range(23):
        a0=sector*math.tau/23
        a1=a0+math.tau/23-rng.uniform(.008,.035)
        count=11; verts=[]
        for j in range(count+1):
            a=a0+(a1-a0)*j/count
            wob=.018*(math.sin(19*a+f)+math.sin(37*a-f))
            for k in range(7):
                t=k/6; rr=r-width*(1-t)+wob*math.sin(math.pi*t)
                z=.022+height*math.sin(t*math.pi)**1.15*(1+.14*math.sin(a*17+f))
                verts.append((rr*math.cos(a),rr*math.sin(a),z))
        faces=[(j*7+k,(j+1)*7+k,(j+1)*7+k+1,j*7+k+1) for j in range(count) for k in range(6)]
        ob=mesh('Rolled outward wave with empty centre',verts,faces,water,root)
        ob.data.materials.append(wall); ob.data.materials.append(foam)
        for p in ob.data.polygons:
            k=p.index%6
            p.material_index=2 if k in (3,4) and (p.index//6+sector+f)%7!=0 else (1 if k in (1,2,3,4) else 0)
            p.use_smooth=True
        # Broad broken foam with a single narrow luminous edge, no inner ring.
        pts=[]
        for j in range(15):
            a=a0+(a1-a0)*j/14
            rr=r-width*.30+.027*math.sin(a*53+f)
            pts.append((rr*math.cos(a),rr*math.sin(a),height*.88+.045))
        tube('Torn white lip',pts,.025+.008*(sector%3),foam,root)
        tube('Cyan caustic along foam',[(x*.997,y*.997,z+.025) for x,y,z in pts[2:11]],.013,cyan,root)
        for k in range(3):
            a=rng.uniform(a0,a1); rr=r+rng.uniform(.025,.18)
            ob=bead('Outward thrown spray',(rr*math.cos(a),rr*math.sin(a),height*rng.uniform(.7,1.6)),(.014+rng.random()*.015,.014+rng.random()*.015,.05+rng.random()*.08),foam if k else cyan,root)
            # Lean droplets radially: visible streaks in the TOP projection.
            ob.rotation_euler=(.85*math.sin(a),-.85*math.cos(a),a)
        # Foam tongues projected beyond the bank, disconnected and asymmetric.
        if sector%2==f%2:
            a=(a0+a1)/2
            tube('Outward foam tongue',[(q*math.cos(a+.007*j),q*math.sin(a+.007*j),.08+height*.4) for j,q in enumerate((r-.04,r+.04,r+.11))],.018,foam,root)
    if f<2:
        mesh('Initial lifted impact core',[(0,0,.04)]+[(r*.45*math.cos(j*math.tau/80),r*.45*math.sin(j*math.tau/80),.04) for j in range(80)],[(0,j+1,(j+1)%80+1) for j in range(80)],wall,root)
    return root

def render():
    import bpy, iso_rig, cel_style as cel
    from PIL import Image
    for key,(cell,n,capacity,radius) in SPECS.items():
        s=iso_rig.create_rig('TOP',cell)
        s.camera.data.ortho_scale=cell/64
        s.render.threads_mode='FIXED'; s.render.threads=8
        cel.install('vfx',normals=False)
        pages={}
        # Snapshot R1 files and resource bytes before writing.
        contracts={p.name:Image.open(p).size for p in folder(key).glob('*.png')}
        resources={p.name:p.read_bytes() for p in folder(key).glob('*.tres')}
        for f in range(n):
            root=puddle(f) if key=='puddle_mirror' else flood(f)
            path=WORK/key/f'{f}.png'; path.parent.mkdir(parents=True,exist_ok=True)
            iso_rig.common.configure_passes(path)
            s.render.filepath=str(path)
            bpy.ops.render.render(write_still=True)
            emitted=list(path.parent.glob(path.stem+'_e__*.png'))
            assert len(emitted)==1,emitted
            emitted[0].replace(path.with_stem(path.stem+'_e'))
            for su in ('','_e'):
                with Image.open(path.with_stem(path.stem+su)) as src:
                    im=src.convert('RGBA').resize((cell,cell),Image.Resampling.LANCZOS)
                im.save(path.with_stem(path.stem+su),optimize=True)
                page=f//capacity; slot=f%capacity
                name=f'{key}_{page}{su}.png'
                if name not in pages:
                    # R1 atlas grid: puddle 2x3, flood two 2x2 pages.
                    pages[name]=Image.new('RGBA',(cell*2,cell*(capacity//2)))
                pages[name].paste(im,((slot%2)*cell,(slot//2)*cell))
            for ob in [*root.children_recursive,root]:bpy.data.objects.remove(ob,do_unlink=True)
            print(f'AV4 FRAME PASS {key} {f}',flush=True)
        for name,im in pages.items():
            if name.endswith('_e.png'):
                # Box reduction, exact policy half-size; retain alpha coverage.
                im=im.resize(((im.width+1)//2,(im.height+1)//2),Image.Resampling.BOX)
            assert name in contracts and (im.size==contracts[name] or name.endswith('_e.png')),(name,im.size)
            for variant in ('averse','averse_cel'):
                dest=folder(key,variant);dest.mkdir(parents=True,exist_ok=True)
                im.save(dest/name,optimize=True,compress_level=9)
        for name,data in resources.items():
            assert (folder(key)/name).read_bytes()==data
            (folder(key,'averse_cel')/name).write_bytes(data.replace(b'characters/averse/',b'characters/averse_cel/'))
        cel.uninstall()
        print(f'AV4 EFFECT PASS {key}',flush=True)

def verify():
    from PIL import Image
    import numpy as np
    import cel_style as cel
    results={}
    ground=Image.open(SPRITES/'terrain/terraces/iso/ground_a.png').convert('RGBA')
    # One contact only: corresponding frame indices, mirror left / flood right.
    contact=Image.new('RGBA',(1600,1600))
    for y in range(0,1600,ground.height):
        for x in range(0,1600,ground.width):contact.paste(ground,(x,y))
    for key,(cell,n,capacity,radius) in SPECS.items():
        hashes=[]; vals=[]; loop_tiles=[]
        for page in range((n+capacity-1)//capacity):
            name=f'{key}_{page}.png'
            rel=f'characters/averse_cel/effects/{key}/{name}'
            # The silhouette intentionally changes: compare the identically delivered variants.
            original_archive=cel.ARCHIVE
            cel.ARCHIVE=SPRITES
            try: cel.check_sheet(rel,normals=False,emission=False)
            finally:cel.ARCHIVE=original_archive
            for variant in ('averse','averse_cel'):
                dest=folder(key,variant)
                assert not list(dest.glob('*_n.png'))
                text=''.join(p.read_text() for p in dest.glob('*.tres'))
                assert 'normal_texture' not in text and 'CanvasTexture' not in text
                assert (dest/name).read_bytes()==(folder(key)/name).read_bytes()
            with Image.open(folder(key)/name) as src: diffuse=src.convert('RGBA')
            with Image.open(folder(key)/name.replace('.png','_e.png')) as src: emission=src.convert('RGBA')
            assert emission.size==((diffuse.width+1)//2,(diffuse.height+1)//2)
            e=np.asarray(emission); assert np.max(e[:,:,:3].max(2)*(e[:,:,3]/255))>2
            assert max(diffuse.size)<=4096
            for slot in range(min(capacity,n-page*capacity)):
                f=page*capacity+slot; x=(slot%2)*cell; y=(slot//2)*cell
                im=diffuse.crop((x,y,x+cell,y+cell)); a=np.asarray(im)
                hashes.append(hashlib.sha256(im.tobytes()).hexdigest())
                box=im.getchannel('A').getbbox(); assert box and min(box[:2])>=4 and max(box[2:])<=cell-4,(key,f,box)
                mask=a[:,:,3]>128
                vals.append(float(a[:,:,:3][mask].mean()))
                if key=='crue_ring' and f>=2:
                    assert a[cell//2,cell//2,3]==0,(key,f,'full centre')
                # Identical pixels/world-unit for both effects, paired at every frame index.
                side=cell//2
                tile=im.resize((side,side),Image.Resampling.LANCZOS)
                offset=(400-side)//2
                contact.alpha_composite(tile,((f%2)*800+(0 if key=='puddle_mirror' else 400)+offset,(f//2)*400+offset))
                if key=='puddle_mirror' and f<2:loop_tiles.append(tile.copy())
        if key=='puddle_mirror':
            for j,tile in enumerate(loop_tiles):
                contact.alpha_composite(tile,(j*800+(400-tile.width)//2,1200+(400-tile.height)//2))
        assert len(set(hashes))==n,(key,'duplicate frames')
        results[key]={'cell':cell,'frames':n,'radius_px_R1':radius,'mean_value':round(sum(vals)/n,2),'unique':len(set(hashes))}
    assert results['crue_ring']['mean_value']>results['puddle_mirror']['mean_value']*1.5,results
    contact.convert('RGB').save(HERE/'_av4_contact.png',optimize=True)
    print('AV4 VERIFY PASS '+json.dumps(results),flush=True)

if __name__=='__main__':
    if '--verify' in sys.argv:verify()
    else:render()
