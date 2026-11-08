"""G4: MAP organic props, shared F2 geometry and CEL pipeline; no integration edits."""
from pathlib import Path
import sys, math, random, json, hashlib
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(ROOT/'art/tools'/p) for p in ('cel','iso','night')]
import cel_style as cel
OUT = ROOT/'game/assets/sprites/props/terraces'
SRC = ROOT/'art/blender/props'
SPECS = {'noria':((416,432),(208,344))}

def build():
    import bpy
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    import iso_rig as rig
    from f2p_build import tube, pebble
    from f2_build import mesh
    C=rig.common
    OUT.mkdir(parents=True,exist_ok=True); SRC.mkdir(parents=True,exist_ok=True)
    def lin(h):
        v=[int(h[i:i+2],16)/255 for i in (0,2,4)]
        return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v)
    def mat(n,h): return C.material(n,lin(h),roughness=.8)
    for name,(size,foot) in SPECS.items():
        if '--along-y' in sys.argv and name != 'stone_stairs': continue
        if '--only' in sys.argv and name!=sys.argv[sys.argv.index('--only')+1]: continue
        s=rig.create_rig('MAP',size)
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(foot[1]-size[1]/2)/rig.R,0))
        root=C.empty(name)
        m={k:mat(k,h) for k,h in {'stone':'2F3A3C','edge':'8AA09A','moss':'46574A','wood':'39352B','grain':'5C5541','iron':'292E2C','bronze':'8C7A4C','straw':'777366','cloth':'4A5B5A','water':'54707A'}.items()}
        rng=random.Random(84)
        def box(n,p,d,k,bevel=.015):return C.box(n,p,d,m[k],root,bevel)
        def rod(n,pts,r,k):return tube(n,pts,r,m[k],root)
        def ring(n,y,r,k):
            pts=[(r*math.cos(i*math.tau/48),y,1.92+r*math.sin(i*math.tau/48)) for i in range(49)]
            return rod(n,pts,.045,k)
        if name=='noria':
            for y in (-.7,.7):
                for z in range(5):
                    for x in (-.25,.25):
                        box('Weathered masonry pier',(x+(z%2)*.04,y,z*.32+.16),(.48,.54,.31),'stone',.035)
                box('Worn stone cap',(0,y,1.68),(.75,.68,.15),'edge')
                for i in range(9):
                    pebble('Damp moss patch',(rng.uniform(-.34,.34),y-.28,rng.uniform(.15,1.65)),(.12,.035,.055),m['moss'],root,i)
            rod('Bronze axle',[(0,-1,1.92),(0,1,1.92)],.095,'bronze')
            for y in (-.30,.30):
                ring('Outer iron hoop',y,1.6,'iron');ring('Inner timber rim',y,1.48,'wood')
                for i in range(12):
                    a=i*math.tau/12
                    rod('Wheel spoke',[(0,y,1.92),(1.5*math.cos(a),y,1.92+1.5*math.sin(a))],.055,'wood')
            for i in range(16):
                a=i*math.tau/16; x=1.48*math.cos(a);z=1.92+1.48*math.sin(a)
                ob=box('Bucket bottom',(x,0,z),(.25,.65,.09),'wood');ob.rotation_euler.y=-a
                for y in (-.32,.32):
                    ob=box('Bucket cheek',(x,y,z+.08),(.28,.055,.23),'grain');ob.rotation_euler.y=-a
                for y in (-.35,.35):pebble('Iron pin',(x,y,z),(.035,.025,.035),m['bronze'],root,i)
            for i in range(4):
                rod('Falling water filament',[(1.42+i*.025,-.12,.95-i*.08),(1.45+i*.022,-.13,.5),(1.49+i*.02,-.14,.06)],.012,'water')
            box('Sluice beam',(.85,.8,1.07),(1.8,.18,.17),'wood')
        bpy.context.view_layer.update()
        q=world_to_camera_view(s,s.camera,Vector((0,0,0)))
        assert abs(q.x*size[0]-foot[0])<.01 and abs((1-q.y)*size[1]-foot[1])<.01
        cel.install('prop',normals=False)
        cel.toon_materials('prop')
        pivot=C.empty('Wheel pivot')
        pivot.location=(0,0,1.92)
        prefixes=('Bronze axle','Outer iron hoop','Inner timber rim','Wheel spoke','Bucket bottom','Bucket cheek','Iron pin')
        bpy.context.view_layer.update()
        for ob in list(root.children):
            if ob.name.startswith(prefixes):
                world=ob.matrix_world.copy(); ob.parent=pivot; ob.matrix_world=world
        s['b4_foot']=list(foot); s['b4_normals']=False
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'b4_noria_spin.blend'),compress=True)
        from PIL import Image
        extent=[]
        for k in range(8):
            pivot.rotation_euler.y=math.radians(-k*11.25)
            bpy.context.view_layer.update()
            for ob in pivot.children:
                for corner in ob.bound_box:
                    q=world_to_camera_view(s,s.camera,ob.matrix_world@Vector(corner))
                    extent.append((q.x*416,(1-q.y)*432))
        bounds=[math.floor(min(v[0] for v in extent))-6,math.floor(min(v[1] for v in extent))-6,math.ceil(max(v[0] for v in extent))+6,math.ceil(max(v[1] for v in extent))+6]
        (HERE/'_noria_spin_wheel_bounds.json').write_text(json.dumps(bounds))
        pivot.rotation_euler.y=0
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'b4_noria_spin.blend'),compress=True)
        for k in range(8):
            pivot.rotation_euler.y=math.radians(-k*11.25)
            path=OUT/('noria_spin_%02d.png'%k)
            C.configure_passes(path)
            s.render.filepath=str(path); bpy.ops.render.render(write_still=True)
            with Image.open(path) as img: im=img.convert('RGBA').resize(size,Image.Resampling.LANCZOS)
            im.save(path,optimize=True)
            for ep in OUT.glob(path.stem+'_e*.png'): ep.unlink()
        optimize()
        write_resource()
        verify()

def optimize():
    from PIL import Image
    paths=[OUT/('noria_spin_%02d.png'%k) for k in range(8)]
    if sum(p.stat().st_size for p in paths)>600*1024:
        atlas=Image.new('RGBA',(416*8,432))
        for k,p in enumerate(paths): atlas.paste(Image.open(p).convert('RGBA'),(k*416,0))
        import numpy as np
        alpha=np.asarray(atlas.getchannel('A')).astype(float)
        atlas=atlas.convert('RGB').quantize(colors=36,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert('RGBA')
        atlas.putalpha(Image.fromarray((np.round(alpha*7/255)*255/7).astype('uint8')))
        for k,p in enumerate(paths): atlas.crop((k*416,0,(k+1)*416,432)).save(p,optimize=True)

def write_resource():
    lines=['[gd_resource type="SpriteFrames" load_steps=9 format=3]','']
    for k in range(8):
        lines.append('[ext_resource type="Texture2D" path="res://assets/sprites/props/terraces/noria_spin_%02d.png" id="%d"]'%(k,k+1))
    lines.extend(['','[resource]','animations = [{','"frames": ['])
    lines.append(',\n'.join('{"duration": 1.0, "texture": ExtResource("%d")}'%(k+1) for k in range(8)))
    lines.extend(['],','"loop": true,','"name": &"spin",','"speed": 8.0','}]'])
    (OUT/'noria_spin.tres').write_text('\n'.join(lines)+'\n')

def verify():
    from PIL import Image
    import numpy as np
    paths=[OUT/('noria_spin_%02d.png'%k) for k in range(8)]
    arrays=[]; contrasts=[]
    for p in paths:
        im=Image.open(p); assert im.mode=='RGBA' and im.size==(416,432)
        a=np.asarray(im); arrays.append(a)
        assert a[:,:,3].min()==0 and a[:,:,3].max()==255
        b=im.getbbox(); assert min(b[0],b[1],416-b[2],432-b[3])>=6,b
        rgb=a[:,:,:3][a[:,:,3]>240].astype(float).mean(1)
        contrast=float(np.percentile(rgb,95)-np.percentile(rgb,5)); assert contrast>25
        contrasts.append(round(contrast,2))
        assert not list(OUT.glob(p.stem+'_e*.png')) and not list(OUT.glob(p.stem+'_n*.png'))
    assert len({hashlib.sha256(a.tobytes()).hexdigest() for a in arrays})==8
    ref=np.asarray(Image.open(OUT/'noria.png').convert('RGBA'))
    mask=(ref[:,:,3]>0)|(arrays[0][:,:,3]>0)
    diff=float(np.abs(arrays[0].astype(float)-ref)[mask].mean()); assert diff<2,diff
    total=sum(p.stat().st_size for p in paths); assert total<=600*1024,total
    assert (SRC/'b4_noria_spin.blend').stat().st_size<5_000_000
    # Outside the projected wheel extent, fixed scenery must remain byte identical.
    yy,xx=np.indices((432,416)); bounds=json.loads((HERE/'_noria_spin_wheel_bounds.json').read_text()); outside=(xx<bounds[0])|(xx>bounds[2])|(yy<bounds[1])|(yy>bounds[3])
    assert all(np.array_equal(a[outside],arrays[0][outside]) for a in arrays[1:]),'fixed scenery changed'
    baseline=json.loads((HERE/'_noria_spin_main_before.json').read_text())
    main=Path('C:/Users/const/Documents/Rainfall/game/assets/sprites/props/terraces')
    assert sorted(p.name for p in main.iterdir())==baseline if main.exists() else baseline==[]
    canvas=Image.new('RGBA',(832,432),(22,29,30,255))
    for k,p in enumerate(paths):
        im=Image.open(p).resize((208,216),Image.Resampling.LANCZOS)
        canvas.alpha_composite(im,((k%4)*208,(k//4)*216))
    dest=ROOT/'art/renders/props_b/noria_spin.png';dest.parent.mkdir(parents=True,exist_ok=True);canvas.save(dest)
    report=dict(bytes=total,diff_mean=diff,contrast=contrasts,fixed_outside_diff=0,frames=8)
    (HERE/'_noria_spin_verification.json').write_text(json.dumps(report))
    print('PASS noria_spin '+json.dumps(report))

if __name__=='__main__':
    if '--verify' in sys.argv: verify()
    else: build()
