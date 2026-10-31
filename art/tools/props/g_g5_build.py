"""G5: new cave concretions, adapted F2P geometry and CEL prop pipeline."""
from pathlib import Path
import sys, math, random, json, inspect
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
import cel_style as cel
OUT=ROOT/'game/assets/sprites/props/fog_forest'
SRC=ROOT/'art/blender/props'
WORK=ROOT/'art/tools/props'
SPECS={'stalagmite_cluster':(192,192,170),'gour_rim':(256,128,None),'geode_dark':(128,128,100),'boulder_split':(192,192,166)}

def prepare():
    cel.archive_folder('props/fog_forest')
    for name in SPECS:
        assert not (OUT/(name+'.png')).exists(), 'Existing new asset: '+name
        assert not (SRC/('g_'+name+'.blend')).exists(), 'Existing source: '+name
    import hashlib
    protected={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir() if p.suffix in ('.json','.tres','.import')}
    (WORK/'_g5_protected.json').write_text(json.dumps(protected))

def render():
    import bpy
    import f2p_build as f
    import iso_rig as rig
    from mathutils import Vector, Matrix
    from bpy_extras.object_utils import world_to_camera_view
    from PIL import Image
    # Preserve shared rig on disk; omit every auxiliary output for this unlit lot.
    source=inspect.getsource(rig.render_frame).replace("('_n','_e')",'()').replace("('_e',)",'()')
    exec(compile(source,str(ROOT/'art/tools/iso/iso_rig.py'),'exec'),rig.__dict__)
    configure=cel.install('prop',normals=False)
    def diffuse_only(path):
        configure(path)
        nodes=bpy.context.scene.compositing_node_group.nodes
        for node in list(nodes):
            if node.bl_idname=='CompositorNodeOutputFile': nodes.remove(node)
    rig.common.configure_passes=diffuse_only
    def mat(name,h):
        return f.C.material(name,tuple((int(h[i:i+2],16)/255)**2.2 for i in (0,2,4)),roughness=.95)
    def mesh(name,v,faces,m,root):
        return f.mesh(name,v,faces,m,root,0)
    def rings(name,center,levels,m,root,seed=1,n=9):
        rng=random.Random(seed);v=[]
        irregular=[rng.uniform(.88,1.12) for _ in range(n)]
        for k,(z,rx,ry) in enumerate(levels):
            for j in range(n):
                a=j*math.tau/n+.13
                v.append((center[0]+rx*math.cos(a)*irregular[j]+z*.055,center[1]+ry*math.sin(a)*irregular[j],z+.018*math.sin(j*2.1+k)))
        faces=[tuple(range(n-1,-1,-1))]
        for k in range(len(levels)-1):
            for j in range(n): faces.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
        faces.append(tuple(range((len(levels)-1)*n,len(levels)*n)))
        return mesh(name,v,faces,m,root)
    def cluster(root,m):
        f.pebble('Eroded sandstone base',(0,0,.09),(.64,.47,.14),m['rock'],root,23)
        for i,(x,y,h,r) in enumerate(((-.31,.16,.91,.22),(.12,.25,1.27,.26),(.34,-.13,.69,.23),(-.16,-.25,.58,.24))):
            rings('Blunt calcite concretion',(x,y),[(.08,r*1.25,r),(h*.33,r,r*.85),(h*.72,r*.66,r*.61),(h*.94,r*.32,r*.27),(h,r*.10,r*.09)],m['calcite'],root,31+i)
        for i in range(5):
            a=i*2.4
            f.pebble('Calcite apron chip',(.54*math.cos(a),.39*math.sin(a),.075),(.12,.09,.055),m['calcite'],root,61+i)
    def geode(root,m):
        # Open shell faces toward the MAP camera, with a recessed concave smoky core.
        right=Vector((.707,.707,0)); up=Vector((-.354,.354,.866)); front=Vector((.612,-.612,.5)); center=Vector((0,0,.42))
        n=11;v=[]
        for k,(r,depth) in enumerate(((.46,-.02),(.34,.06),(.23,-.15))):
            for j in range(n):
                a=j*math.tau/n; rr=r*(1+.11*math.sin(j*2.7))
                p=center+right*(math.cos(a)*rr)+up*(math.sin(a)*rr)+front*depth
                v.append(tuple(p))
        v.append(tuple(center-front*.24))
        faces=[]
        for k in range(2):
            for j in range(n): faces.extend(((k*n+j,k*n+(j+1)%n,(k+1)*n+j),(k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j)))
        faces.extend((2*n+j,2*n+(j+1)%n,3*n) for j in range(n))
        ob=mesh('Broken geode rind and recessed matte facets',v,faces,m['rock'],root)
        ob.data.materials.append(m['quartz']);ob.data.materials.append(m['quartzlight'])
        for p in ob.data.polygons:
            if p.index>=2*n:p.material_index=2 if p.index%5==0 else 1
        f.pebble('Geode sandstone contact',(0,0,.06),(.40,.30,.10),m['rock'],root,91)
    def boulder(root,m):
        # Two naturally parted halves, irregular fracture seam, oblique sediment bands.
        n=9
        for side in (-1,1):
            v=[]
            outline=[(-.55,-.38),(-.12,-.47),(.0,-.30),(.015,.08),(-.02,.35),(-.29,.43),(-.56,.30),(-.66,.05),(-.61,-.21)]
            for k,z in enumerate((.04,.27,.43,.63,.80,1.02)):
                scale=(.92,1.06,1.02,.98,.89,.65)[k]
                for j,(x,y) in enumerate(outline):
                    xx=(x*scale-.045)*side; yy=y*scale+.04*side
                    v.append((xx,yy,max(.02,z+.17*yy+.085*xx+.025*math.sin(j*2.3))))
            faces=[]
            for k in range(5):
                for j in range(n):faces.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
            faces.append(tuple(range(5*n,6*n)))
            ob=mesh('Naturally split sandstone half',v,faces,m['rock'],root)
            ob.data.materials.append(m['strata']);ob.data.materials.append(m['cut'])
            for p in ob.data.polygons:
                if p.index//n in (1,3):p.material_index=1
                if p.index%n in (2,3):p.material_index=2
        for i in range(4):f.pebble('Fracture debris',(-.11+i*.08,-.43,.065),(.08,.07,.06),m['strata'],root,101+i)
    def gour(root,m):
        # Three nested uneven terrace lips, no receiver and no cast shadow.
        n=35
        for k in range(3):
            rx=.92-k*.18;ry=.43-k*.09;v=[]
            for r,z in ((1,.015+k*.035),(.93,.065+k*.035),(.85,.055+k*.035)):
                for j in range(n):
                    a=j*math.tau/n;w=1+.045*math.sin(5*a+.6)+.025*math.sin(9*a)
                    v.append((rx*r*w*math.cos(a),ry*r*w*math.sin(a),z))
            faces=[(q*n+j,q*n+(j+1)%n,(q+1)*n+(j+1)%n,(q+1)*n+j) for q in range(2) for j in range(n)]
            mesh('Uneven calcite terrace rim',v,faces,m['calcite'],root)
        water=bpy.data.materials.new('Non luminous half alpha water film');water.use_nodes=True
        nodes=water.node_tree.nodes;nodes.clear();links=water.node_tree.links
        out=nodes.new('ShaderNodeOutputMaterial');mix=nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=.5
        tr=nodes.new('ShaderNodeBsdfTransparent');diff=nodes.new('ShaderNodeBsdfDiffuse');diff.inputs[0].default_value=(.055,.058,.063,1)
        links.new(tr.outputs[0],mix.inputs[1]);links.new(diff.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],out.inputs[0])
        water.surface_render_method='DITHERED'
        verts=[(0,0,.10)]+[(.48*math.cos(j*math.tau/n),.205*math.sin(j*math.tau/n),.10) for j in range(n)]
        mesh('Quiet water film',verts,[(0,1+j,1+(j+1)%n) for j in range(n)],water,root)
    metadata=[]
    for name,(w,h,fy) in SPECS.items():
        s=rig.create_rig('TOP' if fy is None else 'MAP',(w,h));s.eevee.taa_render_samples=8
        if fy is not None:s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(fy-h/2)/rig.R,0))
        root=f.C.empty(name)
        m={k:mat(k,c) for k,c in {'rock':'5A4232','calcite':'8A7A62','quartz':'2E2A30','quartzlight':'403B43','strata':'7A5D45','cut':'3A3634'}.items()}
        {'stalagmite_cluster':cluster,'gour_rim':gour,'geode_dark':geode,'boulder_split':boulder}[name](root,m)
        bpy.context.view_layer.update()
        if name in ('stalagmite_cluster','boulder_split'):
            depth=.66 if name=='stalagmite_cluster' else .60
            a=(1+depth)/2;b=(1-depth)/2
            squash=Matrix(((a,b,0,0),(b,a,0,0),(0,0,1,0),(0,0,0,1)))
            for ob in root.children_recursive:
                if ob.type=='MESH':ob.matrix_world=squash@ob.matrix_world
        rig.bake_ao_shadows(root);bpy.context.view_layer.update()
        q=world_to_camera_view(s,s.camera,Vector((0,0,0)));foot=[round(q.x*w,4),round((1-q.y)*h,4)]
        if fy is not None:assert foot==[w/2,fy],(name,foot)
        rig.render_frame(OUT/(name+'.png'))
        blend=SRC/('g_'+name+'.blend')
        if not blend.exists():bpy.ops.wm.save_as_mainfile(filepath=str(blend))
        if fy is not None:
            sun=bpy.data.objects['Sun_chaud_haut_gauche'];ray=sun.rotation_euler.to_matrix()@Vector((0,0,-1));ray.x*=.6;ray.y*=.6
            rig.create_rig('TOP',(512,512),reset=False);s.eevee.taa_render_samples=8;sun.rotation_euler=ray.to_track_quat('-Z','Y').to_euler()
            rig.render_shadow_decal(root,OUT/(name+'_shadow.png'))
            # Blur in Blender compositor; Pillow only resizes/reads rendered assets.
            shadow=OUT/(name+'_shadow.png');image=bpy.data.images.load(str(shadow),check_existing=False)
            group=bpy.data.node_groups.new('G5 soft shadow','CompositorNodeTree');s.compositing_node_group=group
            inp=group.nodes.new('CompositorNodeImage');inp.image=image
            blur=group.nodes.new('CompositorNodeBlur');blur.inputs['Size'].default_value=(2.5,2.5)
            group.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor');out=group.nodes.new('NodeGroupOutput')
            group.links.new(inp.outputs['Image'],blur.inputs['Image']);group.links.new(blur.outputs['Image'],out.inputs['Image'])
            s.render.resolution_x=512;s.render.resolution_y=512;s.render.filepath=str(shadow)
            bpy.ops.render.render(write_still=True)
            bpy.data.images.remove(image)
        metadata.append(dict(name=name,size=[w,h],foot=foot,frames=1,rig='TOP' if fy is None else 'MAP',shadow_length=.6))
    (WORK/'_g5_geometry.json').write_text(json.dumps(metadata,indent=2))
    print('PASS G5: 4 props, 3 TOP shadows, 4 new blends',flush=True)

def verify():
    from PIL import Image
    import numpy as np, hashlib
    metrics=[]; hashes=[]
    for name,(w,h,fy) in SPECS.items():
        result=cel.check_sheet('props/fog_forest/'+name+'.png',cell=(w,h),frames=1,rows=1,normals=False,emission=False)
        im=Image.open(OUT/(name+'.png')).convert('RGBA');a=np.asarray(im);opaque=a[:,:,3]>128
        assert im.size==(w,h) and opaque.any()
        assert max(a[0,:,3].max(),a[-1,:,3].max(),a[:,0,3].max(),a[:,-1,3].max())<128,(name,'clipping')
        assert np.ptp(a[:,:,:3][opaque].astype(float))>25,(name,'contrast')
        assert not (OUT/(name+'_e.png')).exists() and not (OUT/(name+'_n.png')).exists()
        hashes.append(hashlib.sha256(im.tobytes()).hexdigest())
        if fy is None:
            assert 120<=a[h//2,w//2,3]<=136,('water alpha',a[h//2,w//2,3])
            assert not (OUT/(name+'_shadow.png')).exists()
        else:
            sh=np.asarray(Image.open(OUT/(name+'_shadow.png')).convert('RGBA'))
            assert sh.shape==(512,512,4) and 0<sh[:,:,3].max()<=153
            assert np.array_equal(sh[:,:,0],sh[:,:,1]) and np.array_equal(sh[:,:,1],sh[:,:,2])
            yy,xx=np.nonzero(sh[:,:,3]>5);assert min(xx)>0 and min(yy)>0 and max(xx)<511 and max(yy)<511
            result['shadow_alpha_max']=int(sh[:,:,3].max())
        result['contrast']=float(np.std(a[:,:,:3][opaque]));metrics.append(result)
    assert len(set(hashes))==4
    for name,digest in json.loads((WORK/'_g5_protected.json').read_text()).items():
        assert hashlib.sha256((OUT/name).read_bytes()).hexdigest()==digest,name
    (WORK/'_g5_checks.json').write_text(json.dumps(metrics,indent=2))
    ground=Image.open(ROOT/'game/assets/sprites/terrain/fog_forest/iso/ground_a.png').convert('RGBA')
    board=Image.new('RGBA',(1024,300),(28,24,26,255))
    for i,(name,(w,h,fy)) in enumerate(SPECS.items()):
        board.alpha_composite(ground.resize((256,128),Image.Resampling.LANCZOS),(i*256,150))
        im=Image.open(OUT/(name+'.png')).convert('RGBA');board.alpha_composite(im,(i*256+(256-w)//2,220-(fy if fy is not None else h//2)))
    board.convert('RGB').save(WORK/'_g5_contact.png')
    print('PASS G5: dimensions, alpha, contrast, distinct assets, pivots, shadows, protected files')

if __name__=='__main__':
    if '--prepare' in sys.argv:prepare();print('PASS G5 archive and new names')
    elif '--verify' in sys.argv:verify()
    else:render()
