"""B1: MAP organic props, shared F2 geometry and CEL pipeline; no integration edits."""
from pathlib import Path
import sys, math, random, json, hashlib
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(ROOT/'art/tools'/p) for p in ('cel','iso','night')]
import cel_style as cel
OUT = ROOT/'game/assets/sprites/props/rust_city'
SRC = ROOT/'art/blender/props'
SPECS = {'crucible':((352,368),(176,288)), 'rails':((400,224),(200,116)), 'minecart':((256,240),(128,180))}

def verify():
    from PIL import Image
    import numpy as np
    results=[]; hashes=[]
    for name,(size,foot) in SPECS.items():
        p=OUT/(name+'.png'); a=np.asarray(Image.open(p).convert('RGBA'))
        check=cel.check_sheet('props/rust_city/'+p.name,cell=size,frames=1,rows=1,normals=False)
        assert Image.open(p).size==size
        assert not (OUT/(name+'_n.png')).exists()
        assert a[:,:,3].min()==0 and a[:,:,3].max()==255
        assert not np.any(a[:6,:,3]>5) and not np.any(a[-6:,:,3]>5) and not np.any(a[:,:6,3]>5) and not np.any(a[:,-6:,3]>5), 'margin '+name
        rgb=a[:,:,:3][a[:,:,3]>240].astype(float)
        contrast=float(np.percentile(rgb.mean(1),95)-np.percentile(rgb.mean(1),5))
        assert contrast>25, (name,contrast)
        sh=np.asarray(Image.open(OUT/(name+'_shadow.png')).convert('RGBA'))
        assert sh.shape==(512,512,4) and 0<sh[:,:,3].max()<=153
        assert np.array_equal(sh[:,:,0],sh[:,:,1]) and np.array_equal(sh[:,:,1],sh[:,:,2])
        if name=='crucible':
            e=Image.open(OUT/(name+'_e.png')); assert e.size==tuple((n+1)//2 for n in size)
            v=np.asarray(e).astype(float); assert (v[:,:,:3].max(2)*v[:,:,3]/255).max()>2
        else: assert not (OUT/(name+'_e.png')).exists()
        hashes.append(hashlib.sha256(p.read_bytes()).hexdigest())
        results.append(dict(name=name,size=size,foot=foot,contrast=round(contrast,2),cel=check))
    assert len(set(hashes))==3
    main=Path('C:/Users/const/Documents/Rainfall/game/assets/sprites/props/rust_city')
    before=json.loads((HERE/'_b1_main_before.json').read_text())
    after={p.name:[p.stat().st_size,p.stat().st_mtime_ns] for p in main.glob('*') if p.is_file()}
    assert before==after, 'Principal repository changed'
    for name in SPECS: assert (SRC/('b1_'+name+'.blend')).stat().st_size<5_000_000

    (HERE/'_b1_verification.json').write_text(json.dumps(results,indent=2))
    # Assembly only: real biome ground, three new assets, four reference sprites.
    canvas=Image.new('RGBA',(960,640),(23,20,23,255))
    gp=ROOT/'game/assets/sprites/terrain/rust_city/iso/ground_a.png'
    ground=Image.open(gp).convert('RGBA')
    for i,(name,(size,foot)) in enumerate(SPECS.items()):
        x=160+i*320; y=338
        g=ground.copy(); g.thumbnail((320,160)); canvas.alpha_composite(g,(x-g.width//2,y-g.height//2))
        canvas.alpha_composite(Image.open(OUT/(name+'.png')).convert('RGBA'),(x-foot[0],y-foot[1]))
        ep=OUT/(name+'_e.png')
        if ep.exists(): canvas.alpha_composite(Image.open(ep).convert('RGBA'),(i*320+15,365))
    for i,name in enumerate(('tank_large','crate_se','pipe_stub','steam_lamp_se')):
        im=Image.open(OUT/(name+'.png')).convert('RGBA');im.thumbnail((140,145))
        canvas.alpha_composite(im,(110+i*210,465))
    cp=ROOT/'art/renders/props_b/b1_codex.png';cp.parent.mkdir(parents=True,exist_ok=True);canvas.save(cp)
    print('PASS B1: 7 PNG; dimensions alpha contrast distinct frames feet MAP shadows TOP; no normals')

def build():
    import bpy
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    import iso_rig as rig
    from f2p_build import tube, pebble
    from f2_build import mesh
    C=rig.common
    # Local adapter for legacy iso_rig: collect emission only, never a normal file.
    def render_no_normals(path,passes=True):
        if passes: C.configure_passes(path)
        else: bpy.context.scene.compositing_node_group=None
        sc=bpy.context.scene;sc.render.filepath=str(path)
        bpy.ops.render.render(write_still=True)
        files=[Path(path)]
        if passes:
            candidates=list(Path(path).parent.glob(Path(path).stem+'_e__*.png'))
            assert len(candidates)==1
            dest=Path(path).with_name(Path(path).stem+'_e.png');candidates[0].replace(dest);files.append(dest)
        for f in files:
            im=bpy.data.images.load(str(f),check_existing=False)
            im.scale(*tuple(sc['iso_frame']));im.filepath_raw=str(f);im.file_format='PNG';im.save();bpy.data.images.remove(im)
    rig.render_frame=render_no_normals
    for name in (() if '--retry' in sys.argv or '--along-y' in sys.argv else SPECS):
        assert not (OUT/(name+'.png')).exists(), 'B1 refuses overwrite: '+name
        assert not (SRC/('b1_'+name+'.blend')).exists(), 'Existing blend: '+name
    def lin(h):
        v=[int(h[i:i+2],16)/255 for i in (0,2,4)]
        return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v)
    def mat(n,h): return C.material(n,lin(h),roughness=.8)
    for name,(size,foot) in SPECS.items():
        if '--along-y' in sys.argv and name != 'rails': continue
        if '--only' in sys.argv and name!=sys.argv[sys.argv.index('--only')+1]: continue
        s=rig.create_rig('MAP',size)
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(foot[1]-size[1]/2)/rig.R,0))
        root=C.empty(name)
        m={k:mat(k,h) for k,h in {'iron':'2B2A29','rust':'6B3A22','dark':'3E2419','edge':'65574B','wood':'352A23','stone':'494541'}.items()}
        accents=[]
        def box(n,loc,dim,ma,bevel=.025):
            bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
            o=bpy.context.object;o.name=n;o.dimensions=dim
            bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
            return C.finish(o,n,ma,root,bevel)
        def cyl(n,loc,rad,depth,ma,rotation=(0,0,0),vertices=12):
            bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=rad,depth=depth,location=loc,rotation=rotation)
            return C.finish(bpy.context.object,n,ma,root,.012)
        def track(length,ties):
            for i in range(ties):
                x=-length/2+.18+i*(length-.36)/(ties-1)
                o=box('Split tarred sleeper',(x,0,.075),(.19,1.55,.13),m['wood'])
                o.rotation_euler.z=.018*math.sin(i*7)
                for y in (-.53,.53):
                    box('Iron rail chair',(x,y,.15),(.28,.27,.045),m['dark'])
                    for yy in (y-.10,y+.10):cyl('Square spike',(x,yy,.19),.027,.045,m['edge'],vertices=4)
            for y in (-.53,.53):
                for z,w,h in ((.15,.15,.045),(.21,.065,.10),(.275,.105,.045)):
                    box('Worn rail section',(0,y,z),(length,w,h),m['rust'] if z<.25 else m['iron'],.008)
                for x in (-length*.28,length*.28):
                    box('Fishplate',(x,y-.055,.215),(.35,.035,.085),m['dark'],.008)
                    for dx in (-.11,.11):cyl('Fishplate bolt',(x+dx,y-.08,.215),.025,.035,m['edge'],(math.pi/2,0,0),6)
        rng=random.Random(117)
        if name=='crucible':
            # Hollow twelve sided iron vessel; thick rim, tapered base, four cast legs.
            N=16; verts=[]
            for rad,z in ((.88,.60),(1.34,2.20),(1.43,2.36),(1.25,2.36),(1.17,2.13),(.78,.78)):
                verts.extend((rad*math.cos(i*math.tau/N),rad*math.sin(i*math.tau/N),z) for i in range(N))
            faces=[(k*N+i,k*N+(i+1)%N,(k+1)*N+(i+1)%N,(k+1)*N+i) for k in range(5) for i in range(N)]
            vessel=mesh('Heavy hollow riveted crucible',verts,faces,m['iron'],root)
            bevel=vessel.modifiers.new('Chipped vessel edges','BEVEL');bevel.width=.022;bevel.segments=1
            for z,rad in ((.83,.97),(1.65,1.21),(2.22,1.40)):
                for i in range(N):
                    a=i*math.tau/N;b=(i+1)*math.tau/N
                    tube('Riveted iron hoop',[(rad*math.cos(a),rad*math.sin(a),z),(rad*math.cos(b),rad*math.sin(b),z)],.045,m['dark'],root)
                    cyl('Hoop rivet',(rad*math.cos(a),rad*math.sin(a),z),.045,.065,m['edge'],(0,math.pi/2,a))
            for i in range(4):
                a=math.pi/4+i*math.pi/2;x,y=.77*math.cos(a),.77*math.sin(a)
                box('Splayed cast support',(x,y,.38),(.24,.26,.65),m['iron'])
                box('Cast foot plate',(x,y,.065),(.44,.42,.13),m['dark'])
            # Front pouring beak, dark channel between two angular flanges.
            for y in (-.24,.24):
                mesh('Pouring beak flange',[(1.12,y,2.18),(1.83,y*.65,2.04),(1.74,y*.65,2.25),(1.20,y,2.41)],[(0,1,2,3)],m['iron'],root)
            box('Pouring channel',(1.51,0,2.12),(.63,.32,.07),m['dark'])
            for x in (-1,1):cyl('Lifting trunnion',(x*1.36,0,1.72),.15,.38,m['iron'],(0,math.pi/2,0))
            molten=C.material('Molten orange',lin('FF7A1F'),emission=1)
            hot=C.material('Molten core',lin('FFB347'),emission=1)
            cyl('Visible molten surface',(0,0,2.10),1.17,.035,molten,vertices=16)
            for i in range(13):
                a=rng.random()*math.tau;rad=rng.uniform(.15,.98)
                pebble('Floating slag',(rad*math.cos(a),rad*math.sin(a),2.135),(.14,.09,.035),m['dark'],root,i)
            for i in range(5):
                a=i*1.3;tube('Incandescent fracture',[(.2*math.cos(a),.2*math.sin(a),2.14),(.66*math.cos(a+.18),.66*math.sin(a+.18),2.14)],.018,hot,root)
        elif name=='rails':
            track(3.95,8)
            for i in range(65):
                pebble('Angular ballast',(rng.uniform(-1.88,1.88),rng.uniform(-.88,.88),.035),(rng.uniform(.035,.085),rng.uniform(.035,.09),.035),m['stone'] if i%3 else m['dark'],root,i)
        else:
            track(1.90,4)
            for x in (-.60,.60):
                cyl('Axle',(x,0,.39),.065,1.47,m['iron'],(math.pi/2,0,0))
                for y in (-.65,.65):
                    cyl('Flanged iron wheel',(x,y,.40),.235,.12,m['dark'],(math.pi/2,0,0))
                    cyl('Wheel hub',(x,y*1.10,.40),.095,.15,m['edge'],(math.pi/2,0,0))
            box('Cart chassis',(0,0,.55),(1.63,1.14,.16),m['iron'])
            # Flared open riveted sheet metal hopper.
            for y in (-1,1):
                ob=box('Hopper long side',(0,y*.59,.98),(1.74,.075,.68),m['rust']);ob.rotation_euler.x=-y*.16
                box('Worn top rim',(0,y*.65,1.31),(1.86,.10,.09),m['iron'])
                for x in (-.73,-.36,0,.36,.73):
                    for z in (.74,1.20):cyl('Hopper rivet',(x,y*(.59+(z-.98)*.16),z),.029,.09,m['edge'],(math.pi/2,0,0),6)
            for x in (-1,1):
                ob=box('Hopper end plate',(x*.85,0,.98),(.075,1.21,.68),m['dark']);ob.rotation_euler.y=x*.12
                box('End rim',(x*.89,0,1.31),(.10,1.32,.09),m['iron'])
                for y in (-.48,0,.48):cyl('End rivet',(x*.89,y,1.18),.029,.08,m['edge'],(0,math.pi/2,0),6)
            for i in range(17):
                ob=box('Broken scrap iron',(rng.uniform(-.66,.66),rng.uniform(-.44,.44),rng.uniform(.92,1.22)),(rng.uniform(.20,.62),.09,.09),m['iron'] if i%3 else m['rust'])
                ob.rotation_euler=(rng.uniform(-.4,.4),rng.uniform(-.5,.5),rng.random()*math.pi)
            for x in (-1,1):box('Tow coupling',(x*1.04,0,.54),(.26,.16,.10),m['iron'])
        if '--along-y' in sys.argv:
            assert name == 'rails', 'B5 target only'
            root.rotation_euler.z += math.pi/2
            s['b5_along_y'] = True
        bpy.context.view_layer.update()
        q=world_to_camera_view(s,s.camera,Vector((0,0,0)))
        assert abs(q.x*size[0]-foot[0])<.01 and abs((1-q.y)*size[1]-foot[1])<.01
        cel.install('prop',normals=False)
        cel.toon_materials('prop')
        rig.render_frame(OUT/(name+'.png'))
        ep=OUT/(name+'_e.png')
        if name!='crucible':ep.unlink(missing_ok=True)
        else:
            # Blender image scaling: PIL is only used by the shared render pipeline.
            im=bpy.data.images.load(str(ep),check_existing=False);im.scale((size[0]+1)//2,(size[1]+1)//2);im.filepath_raw=str(ep);im.file_format='PNG';im.save();bpy.data.images.remove(im)
        s['b1_foot']=list(foot);s['b1_profile']='prop';s['b1_normals']=False
        blend=SRC/(('b5_' if '--along-y' in sys.argv else 'b1_')+name+('_v2' if '--revision' in sys.argv else '')+'.blend')
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
        # Shared TOP projector, unshortened DA sun, soft alpha in compositor.
        sun=bpy.data.objects['Sun_chaud_haut_gauche']; rot=sun.rotation_euler.copy()
        rig.create_rig('TOP',(512,512),reset=False);sun.rotation_euler=rot
        original=rig.render_frame
        def soft_shadow(path,passes=False):
            cel.setup_scene(samples=8)
            tree=bpy.data.node_groups.new('B1 soft TOP shadow','CompositorNodeTree');s.compositing_node_group=tree
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
    print('PASS B1 build: 3 props, MAP feet, TOP shadows, CEL prop, normals=False')

if __name__=='__main__':
    if '--verify' in sys.argv:verify()
    else:build()



