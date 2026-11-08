"""G4: MAP organic props, shared F2 geometry and CEL pipeline; no integration edits."""
from pathlib import Path
import sys, math, random, json, hashlib
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(ROOT/'art/tools'/p) for p in ('cel','iso','night')]
import cel_style as cel
OUT = ROOT/'game/assets/sprites/props/terraces'
SRC = ROOT/'art/blender/props'
SPECS = {'noria':((416,432),(208,344)), 'scarecrow':((160,224),(80,198)), 'stone_stairs':((432,384),(216,268))}

def verify():
    from PIL import Image
    import numpy as np
    results=[]; hashes=[]
    for name,(size,foot) in SPECS.items():
        p=OUT/(name+'.png'); a=np.asarray(Image.open(p).convert('RGBA'))
        check=cel.check_sheet('props/terraces/'+p.name,cell=size,frames=1,rows=1,normals=False)
        assert Image.open(p).size==size
        assert not (OUT/(name+'_n.png')).exists()
        assert a[:,:,3].min()==0 and a[:,:,3].max()==255
        assert not np.any(a[[0,-1],:,3]>5) and not np.any(a[:,[0,-1],3]>5), 'clipped '+name
        rgb=a[:,:,:3][a[:,:,3]>240].astype(float)
        contrast=float(np.percentile(rgb.mean(1),95)-np.percentile(rgb.mean(1),5))
        assert contrast>25, (name,contrast)
        sh=np.asarray(Image.open(OUT/(name+'_shadow.png')).convert('RGBA'))
        assert sh.shape==(512,512,4) and 0<sh[:,:,3].max()<=153
        assert np.array_equal(sh[:,:,0],sh[:,:,1]) and np.array_equal(sh[:,:,1],sh[:,:,2])
        assert not (OUT/(name+'_e.png')).exists()
        bbox=Image.fromarray(a[:,:,3]).getbbox(); assert min(bbox[0],bbox[1],size[0]-bbox[2],size[1]-bbox[3])>=6, (name,bbox)
        hashes.append(hashlib.sha256(p.read_bytes()).hexdigest())
        results.append(dict(name=name,size=size,foot=foot,contrast=round(contrast,2),cel=check))
    assert len(set(hashes))==3
    (HERE/'_b4_verification.json').write_text(json.dumps(results,indent=2))
    canvas=Image.new('RGBA',(1024,500),(22,29,30,255))
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    for x,name in zip((210,510,810),SPECS):
        size,foot=SPECS[name]; y=370
        canvas.alpha_composite(ground,(x-ground.width//2,y-ground.height//2))
        canvas.alpha_composite(Image.open(OUT/(name+'.png')).convert('RGBA'),(x-foot[0],y-foot[1]))
    dest=ROOT/'art/renders/props_b/b4_codex.png';dest.parent.mkdir(parents=True,exist_ok=True);canvas.save(dest)
    assert not Path('C:/Users/const/Documents/Rainfall/game/assets/sprites/props/terraces').exists(), 'main repository terraces exists'
    assert len(list(OUT.glob('*.png')))==6
    assert all((SRC/('b4_'+n+'.blend')).stat().st_size<5_000_000 for n in SPECS)
    print('PASS B4: 6 PNG; dimensions alpha margins contrast distinct feet shadows; no _e/_n; main repository absent')

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
        elif name=='scarecrow':
            rod('Leaning bamboo post',[(0,0,.02),(-.07,0,.85),(-.19,.01,1.8)],.038,'wood')
            rod('Drooping crossbar',[(-.66,0,1.51),(-.16,0,1.66),(.5,.02,1.48)],.032,'wood')
            verts=[(-.37,-.06,1.66),(.09,-.06,1.66),(.42,-.06,1.43),(.29,-.08,1.28),(.08,-.09,1.4),(.15,-.12,.73),(-.08,-.1,.85),(-.28,-.09,.70),(-.4,-.08,.87),(-.31,-.08,1.38),(-.57,-.05,1.30),(-.66,-.04,1.45)]
            mesh('Ragged rice keeper tunic',verts,[tuple(range(len(verts)))],m['cloth'],root)
            for i in range(36):
                x=-.3+rng.random()*.4;z=rng.uniform(.73,1.37)
                rod('Loose grey straw',[(x,0,z+.14),(x+rng.uniform(-.12,.12),-.06,z-.11)],.006,'straw')
            pebble('Stuffed sack head',(-.19,0,1.85),(.14,.12,.17),m['straw'],root,4)
            N=13; verts=[(-.22,.01,2.19)]+[(-.19+.36*math.cos(i*math.tau/N),.28*math.sin(i*math.tau/N),1.98+rng.uniform(-.035,.015)) for i in range(N)]
            mesh('Torn conical reed hat',verts,[(0,i+1,(i+1)%N+1) for i in range(N-1)],m['grain'],root)
            for z in (.5,1.05,1.55):rod('Bamboo node',[(-.09,-.04,z),(.01,-.04,z)],.012,'bronze')
            rod('Faded hanging belt',[(-.3,-.13,1.2),(-.05,-.13,1.17),(.05,-.13,.91)],.014,'grain')
        else:
            for i in range(5):
                x=1.6-i*.8;h=(i+1)*.24
                for j in range(3):
                    box('Split worn stair block',(x,-.64+j*.64,h/2),(.79,.625,h),'stone',.025)
                    box('Chipped tread lip',(x+.32,-.64+j*.64,h-.018),(.07,.58,.038),'edge',.008)
                for y in (-.97,.97):
                    box('Low sidewall',(x,y,h/2+.12),(.79,.22,h+.24),'stone',.028)
                    box('Weathered wall coping',(x,y,h+.25),(.81,.25,.09),'edge',.016)
                for j in range(7):
                    pebble('Moss in tread seams',(x+rng.uniform(-.35,.35),rng.uniform(-.8,.8),h+.01),(.1,.07,.016),m['moss'],root,10*i+j)
                rod('Stone fracture',[(x-.2,-.3,h+.012),(x+.04,-.18,h+.012),(x+.12,.02,h+.012)],.008,'iron')
        if '--along-y' in sys.argv:
            assert name == 'stone_stairs', 'B5 target only'
            # MAP camera projects +y upper-right: reverse the stair run so risers face lower-left.
            from mathutils import Matrix
            turn = Matrix.Rotation(math.pi, 4, 'Z')
            for child in root.children:
                child.matrix_basis = turn @ child.matrix_basis
            root.rotation_euler.z += math.pi/2
            s['b5_along_y'] = True
        bpy.context.view_layer.update()
        q=world_to_camera_view(s,s.camera,Vector((0,0,0)))
        assert abs(q.x*size[0]-foot[0])<.01 and abs((1-q.y)*size[1]-foot[1])<.01
        cel.install('prop',normals=False)
        cel.toon_materials('prop')
        path=OUT/(name+'.png'); C.configure_passes(path)
        s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        from PIL import Image
        with Image.open(path) as src: im=src.convert('RGBA').resize(size,Image.Resampling.LANCZOS)
        im.save(path,optimize=True)
        for ep in OUT.glob(name+'_e__*.png'): ep.unlink()
        (OUT/(name+'_e.png')).unlink(missing_ok=True)
        s['b4_foot']=list(foot);s['b4_normals']=False
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(('b5_' if '--along-y' in sys.argv else 'b4_')+name+'.blend')),compress=True)
        # Shared TOP projector, shorter cast vector (x0.6), soft alpha in compositor.
        sun=bpy.data.objects['Sun_chaud_haut_gauche']; rot=sun.rotation_euler.copy()
        rig.create_rig('TOP',(512,512),reset=False);sun.rotation_euler=rot; s.camera.data.ortho_scale=8
        original=rig.render_frame
        def soft_shadow(path,passes=False):
            cel.setup_scene(samples=8)
            tree=bpy.data.node_groups.new('G4 soft TOP shadow','CompositorNodeTree');s.compositing_node_group=tree
            n=tree.nodes;links=tree.links
            layer=n.new('CompositorNodeRLayers');blur=n.new('CompositorNodeBlur');blur.inputs['Size'].default_value=(5,5)
            output=n.new('NodeGroupOutput');tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
            links.new(layer.outputs['Image'],blur.inputs['Image']);links.new(blur.outputs['Image'],output.inputs[0])
            s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
            from PIL import Image
            with Image.open(path) as src: im=src.convert('RGBA').resize((512,512),Image.Resampling.LANCZOS)
            im.save(path)
        rig.render_frame=soft_shadow
        try:rig.render_shadow_decal(root,OUT/(name+'_shadow.png'))
        finally:rig.render_frame=original
    print('PASS B4 build: 3 props, MAP feet, TOP shadows, CEL prop, normals=False')

if __name__=='__main__':
    if '--verify' in sys.argv:verify()
    else:build()



