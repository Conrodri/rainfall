"""B2: crypt masonry props, shared F2 geometry and CEL pipeline; no integration edits."""
from pathlib import Path
import sys, math, random, json, hashlib
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(ROOT/'art/tools'/p) for p in ('cel','iso','night')]
import cel_style as cel
OUT = ROOT/'game/assets/sprites/props/crypts'
SRC = ROOT/'art/blender/props'
SPECS = {'well_rim':((352,224),(176,134)), 'crypt_stairs':((400,304),(200,196))}

def verify():
    from PIL import Image
    import numpy as np
    results=[]; hashes=[]
    for name,(size,foot) in SPECS.items():
        p=OUT/(name+'.png'); a=np.asarray(Image.open(p).convert('RGBA'))
        check=cel.check_sheet('props/crypts/'+p.name,cell=size,frames=1,rows=1,normals=False)
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
        if name=='well_rim':
            e=Image.open(OUT/(name+'_e.png')); assert e.size==tuple((n+1)//2 for n in size)
            v=np.asarray(e).astype(float); assert (v[:,:,:3].max(2)*v[:,:,3]/255).max()>2
        else: assert not (OUT/(name+'_e.png')).exists()
        hashes.append(hashlib.sha256(p.read_bytes()).hexdigest())
        results.append(dict(name=name,size=size,foot=foot,contrast=round(contrast,2),cel=check))
    assert len(set(hashes))==2
    (HERE/'_b2_verification.json').write_text(json.dumps(results,indent=2))
    main=Path('C:/Users/const/Documents/Rainfall/game/assets/sprites/props/crypts')
    before=json.loads((HERE/'_b2_main_before.json').read_text())
    after={f.name:[f.stat().st_size,f.stat().st_mtime_ns] for f in main.iterdir() if f.is_file()} if main.exists() else {}
    assert before==after, 'Main repository changed'
    assert not (OUT/'crypt_stairs_e.png').exists()
    for name in SPECS:
        assert (SRC/('b2_'+name+'.blend')).stat().st_size<5_000_000
        a=Image.open(OUT/(name+'.png')).getchannel('A')
        box=a.point(lambda v:255 if v>5 else 0).getbbox()
        assert min(box[0],box[1],a.width-box[2],a.height-box[3])>=6, (name,box)
    canvas=Image.new('RGBA',(960,460),(21,27,31,255))
    ground=Image.open(ROOT/'game/assets/sprites/terrain/crypts/iso/ground_a.png').convert('RGBA')
    for i,(name,(size,foot)) in enumerate(SPECS.items()):
        x=240+i*480; y=260
        canvas.alpha_composite(ground,(x-ground.width//2,y-ground.height//2))
        canvas.alpha_composite(Image.open(OUT/(name+'.png')).convert('RGBA'),(x-foot[0],y-foot[1]))
    board=ROOT/'art/renders/props_b/b2_codex.png';board.parent.mkdir(parents=True,exist_ok=True);canvas.save(board)
    print('PASS B2: 5 PNG; canvas foot alpha contrast distinct margins emission TOP shadows; main unchanged')


def build():
    import bpy
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    import iso_rig as rig
    from f2p_build import tube, pebble
    from f2_build import mesh
    # Reuse the shared renderer with emission-only pass collection.
    import inspect
    source=inspect.getsource(rig.render_frame).replace("('_n','_e')", "('_e',)")
    exec(compile(source, str(Path(rig.__file__)), "exec"), rig.__dict__)
    C=rig.common
    for name in (() if '--retry' in sys.argv or '--along-y' in sys.argv else SPECS):
        assert not (OUT/(name+'.png')).exists(), 'G4 refuses overwrite: '+name
        assert not (SRC/('b2_'+name+'.blend')).exists(), 'Existing blend: '+name
    def lin(h):
        v=[int(h[i:i+2],16)/255 for i in (0,2,4)]
        return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v)
    def mat(n,h): return C.material(n,lin(h),roughness=.8)
    for name,(size,foot) in SPECS.items():
        if '--along-y' in sys.argv and name != 'crypt_stairs': continue
        if '--only' in sys.argv and name!=sys.argv[sys.argv.index('--only')+1]: continue
        s=rig.create_rig('MAP',size)
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(foot[1]-size[1]/2)/rig.R,0))
        root=C.empty(name)
        rng=random.Random(20261108)
        m={k:mat(k,h) for k,h in {'stone':'3D4B54','slate':'35414B','worn':'4B5962','salt':'727D80','moss':'303F3B','wet':'26343E','crack':'172127','water':'101F29'}.items()}
        glow=C.material('Cold water BF F4 FF',lin('BFF4FF'),emission=.7)
        accents=[glow] if name=='well_rim' else []
        def block(label,x,y,z,dx,dy,dz,material,seed):
            rr=random.Random(seed);v=[]
            for zz in (z-dz/2,z+dz/2):
                for xx,yy in ((-1,-1),(1,-1),(1,1),(-1,1)):
                    v.append((x+xx*dx/2+rr.uniform(-.018,.018),y+yy*dy/2+rr.uniform(-.018,.018),zz+rr.uniform(-.012,.012)))
            return mesh(label,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],material,root,bevel=.018)
        if name=='well_rim':
            # Two staggered courses, individually chipped octagonal voussoirs.
            for course in range(2):
                for j in range(16):
                    # Subdivide each straight octagon side; preserve its angular silhouette.
                    side=j//2; t0=(j%2)/2+.012;t1=(j%2+1)/2-.012
                    a=side*math.tau/8+math.pi/8;b=a+math.tau/8
                    def pt(r,t):return (r*((1-t)*math.cos(a)+t*math.cos(b)),r*((1-t)*math.sin(a)+t*math.sin(b)))
                    ring=[pt(1.79,t0),pt(1.79,t1),pt(1.20,t1),pt(1.20,t0)]
                    vs=[]
                    for z in (.025+course*.285,.295+course*.285):
                        for x,y in ring:vs.append((x+rng.uniform(-.012,.012),y+rng.uniform(-.012,.012),z+rng.uniform(-.012,.012)))
                    mesh('Worn octagonal ashlar',vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],m[['stone','slate','worn'][j%3]],root,bevel=.022)
            bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=1.215,depth=.035,location=(0,0,.065),rotation=(0,0,math.pi/8))
            water=bpy.context.object;water.name='Recessed black water';water.parent=root;water.data.materials.append(m['water'])
            # Sparse broken reflections, only luminous accent.
            for j,(x,y,length) in enumerate(((-.38,-.32,.40),(-.14,-.48,.24),(.17,-.25,.31),(.38,.08,.17))):
                tube('Cold water glimmer',[(x-length/2,y,.091),(x,y+.015,.092),(x+length/2,y+.008,.091)],.010 if j!=0 else .016,glow,root)
            for j in range(28):
                a=rng.uniform(0,math.tau);r=rng.uniform(1.33,1.63);x,y=r*math.cos(a),r*math.sin(a)
                pebble('Salt and moss fleck',(x,y,.584),(.035+rng.random()*.055,.018+rng.random()*.025,.009),m['moss'] if j%3 else m['salt'],root,j)
            for j in range(10):
                a=j*math.tau/10+.1;r=1.50;x,y=r*math.cos(a),r*math.sin(a)
                tube('Stone hairline split',[(x,y,.599),(x+.06,y+.04,.602),(x+.14,y+.015,.600)],.007,m['crack'],root)
            for j in range(12):
                a=j*math.tau/12
                # Capillary dark trails along outer walls, kept within octagon planes.
                side=int((a-math.pi/8)%(math.tau)/(math.tau/8));theta=math.pi/8+(side+.5)*math.tau/8
                r=1.79*math.cos(math.pi/8)+.013;x,y=r*math.cos(theta),r*math.sin(theta)
                tube('Wet masonry seep',[(x,y,.50),(x+.01,y,.36),(x,y,.13)],.012,m['wet'],root)
        else:
            # +x footprint; high end -x projects toward screen upper left.
            for step in range(5):
                x=1.6-step*.8;h=(step+1)*.24
                for course in range(step+1):
                    for col in range(3):
                        y=-.65+col*.65
                        block('Fractured stair masonry',x,y,.02+course*.24+.11,.785,.635,.225,m[['stone','slate','worn'][(step+col+course)%3]],step*100+course*7+col)
                for k in range(3):
                    y=-.78+k*.72+rng.uniform(-.06,.06)
                    tube('Split stair tread',[(x-.31,y,h+.028),(x-.1,y+.045,h+.030),(x+.04,y+.018,h+.027)],.008,m['crack'],root)
                for k in range(7):
                    xx=x+rng.uniform(-.32,.32);yy=rng.uniform(-.86,.86)
                    pebble('Tread salt or lichen',(xx,yy,h+.025),(.026+rng.random()*.035,.015+rng.random()*.02,.008),m['salt'] if k%3==0 else m['moss'],root,step*30+k)
            for j in range(9):
                x=rng.uniform(-1.8,1.8);y=-.98
                pebble('Rough broken flank',(x,y,.06),(.09,.045,.06),m['slate'],root,300+j)
        if '--along-y' in sys.argv:
            assert name == 'crypt_stairs', 'B5 target only'
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
        cel.setup_scene(samples=16)
        # AOV color independent of neutral, cel shaded diffuse.
        for material in accents:
            for node in material.node_tree.nodes:
                if node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=(*lin('BFF4FF'),1)
        rig.render_frame(OUT/(name+'.png'))
        ep=OUT/(name+'_e.png')
        if name=='crypt_stairs':ep.unlink(missing_ok=True)
        else:
            # Blender image scaling: PIL is only used by the shared render pipeline.
            im=bpy.data.images.load(str(ep),check_existing=False);im.scale((size[0]+1)//2,(size[1]+1)//2);im.filepath_raw=str(ep);im.file_format='PNG';im.save();bpy.data.images.remove(im)
        s['b2_foot']=list(foot);s['b2_profile']='prop';s['b2_normals']=False
        blend=SRC/(('b5_' if '--along-y' in sys.argv else 'b2_')+name+'.blend')
        bpy.context.preferences.filepaths.save_version=0
        if '--along-y' in sys.argv or not blend.exists(): bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
        # Preserve MAP sun direction through TOP setup, full DA cast length.
        rot=bpy.data.objects['Sun_chaud_haut_gauche'].rotation_euler.copy()
        rig.create_rig('TOP',(512,512),reset=False)
        s.camera.data.ortho_scale=6.0
        bpy.data.objects['Sun_chaud_haut_gauche'].rotation_euler=rot
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
    print('PASS B2 build: 2 props; MAP feet; TOP shadows; CEL prop; normals=False')

if __name__=='__main__':
    if '--verify' in sys.argv:verify()
    else:build()



