"""G4: MAP organic props, shared F2 geometry and CEL pipeline; no integration edits."""
from pathlib import Path
import sys, math, random, json, hashlib
sys.dont_write_bytecode=True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(ROOT/'art/tools'/p) for p in ('cel','iso','night')]
import cel_style as cel
OUT = ROOT/'game/assets/sprites/props/fog_forest'
SRC = ROOT/'art/blender/props'
SPECS = {'pontoon':((400,272),(200,166)), 'firefly_cage':((192,248),(96,208)), 'fallen_altar':((400,296),(200,190))}

def verify():
    from PIL import Image
    import numpy as np
    results=[]; hashes=[]
    for name,(size,foot) in SPECS.items():
        p=OUT/(name+'.png'); a=np.asarray(Image.open(p).convert('RGBA'))
        check=cel.check_sheet('props/fog_forest/'+p.name,cell=size,frames=1,rows=1,normals=False)
        assert Image.open(p).size==size
        assert not (OUT/(name+'_n.png')).exists()
        assert a[:,:,3].min()==0 and a[:,:,3].max()==255
        bbox=Image.fromarray(a[:,:,3]).point(lambda v:255 if v>5 else 0).getbbox()
        assert min(bbox[0],bbox[1],size[0]-bbox[2],size[1]-bbox[3])>=6
        assert not np.any(a[[0,-1],:,3]>5) and not np.any(a[:,[0,-1],3]>5), 'clipped '+name
        rgb=a[:,:,:3][a[:,:,3]>240].astype(float)
        contrast=float(np.percentile(rgb.mean(1),95)-np.percentile(rgb.mean(1),5))
        assert contrast>25, (name,contrast)
        sh=np.asarray(Image.open(OUT/(name+'_shadow.png')).convert('RGBA'))
        assert sh.shape==(512,512,4) and 0<sh[:,:,3].max()<=153
        assert np.array_equal(sh[:,:,0],sh[:,:,1]) and np.array_equal(sh[:,:,1],sh[:,:,2])
        if name=='firefly_cage':
            e=Image.open(OUT/(name+'_e.png')); assert e.size==tuple((n+1)//2 for n in size)
            v=np.asarray(e).astype(float); assert (v[:,:,:3].max(2)*v[:,:,3]/255).max()>2
        else: assert not (OUT/(name+'_e.png')).exists()
        hashes.append(hashlib.sha256(p.read_bytes()).hexdigest())
        results.append(dict(name=name,size=size,foot=foot,contrast=round(contrast,2),cel=check))
    assert len(set(hashes))==3
    (HERE/'_b3_verification.json').write_text(json.dumps(results,indent=2))
    canvas=Image.new('RGBA',(1000,420),(23,20,23,255))
    ground=Image.open(ROOT/'game/assets/sprites/terrain/fog_forest/iso/ground_a.png').convert('RGBA')
    for i,(name,(size,foot)) in enumerate(SPECS.items()):
        x=(210,505,790)[i];y=275
        canvas.alpha_composite(ground,(x-ground.width//2,y-ground.height//2))
        canvas.alpha_composite(Image.open(OUT/(name+'.png')).convert('RGBA'),(x-foot[0],y-foot[1]))
    dest=ROOT/'art/renders/props_b/b3_codex_v2.png';dest.parent.mkdir(parents=True,exist_ok=True);canvas.save(dest)
    baseline=json.loads((HERE/'_b3_main_baseline.json').read_text())
    assert baseline==main_snapshot(), 'main repository changed'
    assert all((SRC/('b3_'+n+'.blend')).stat().st_size<5*1024*1024 for n in SPECS)
    print('PASS B3: 7 PNG; dimensions alpha contrast distinct frames MAP feet TOP shadows emission; main unchanged')

def main_snapshot():
    base=Path('C:/Users/const/Documents/Rainfall/game/assets/sprites/props/fog_forest')
    return {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in base.glob('*') if p.is_file()}

def build():
    import bpy
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    import iso_rig as rig
    from f2p_build import tube, pebble
    from f2_build import mesh
    C=rig.common
    OUT.mkdir(parents=True,exist_ok=True);SRC.mkdir(parents=True,exist_ok=True)
    baseline=HERE/'_b3_main_baseline.json'
    if not baseline.exists():baseline.write_text(json.dumps(main_snapshot(),sort_keys=True))
    for name in (() if '--retry' in sys.argv else SPECS):
        assert not (OUT/(name+'.png')).exists(), 'G4 refuses overwrite: '+name
        assert not (SRC/('b3_'+name+'.blend')).exists(), 'Existing blend: '+name
    def lin(h):
        v=[int(h[i:i+2],16)/255 for i in (0,2,4)]
        return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v)
    def mat(n,h): return C.material(n,lin(h),roughness=.8)
    for name,(size,foot) in SPECS.items():
        if '--only' in sys.argv and name!=sys.argv[sys.argv.index('--only')+1]: continue
        s=rig.create_rig('MAP',size)
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(foot[1]-size[1]/2)/rig.R,0))
        root=C.empty(name)
        m={k:mat(k,h) for k,h in {'rock':'5A4232','schist':'3A3634','root':'2A2420','bark':'44352B','calcite':'8A7A62','wet':'A18E73','cap':'6A5A66','gill':'82737B','filament':'8B7B89'}.items()}
        accents=[]
        rng=random.Random(303+list(SPECS).index(name))
        def slab(label,loc,dim,material):
            # Rough hewn eight-corner block, individual chipped corners.
            verts=[(loc[0]+x*dim[0]/2+rng.uniform(-.045,.045),loc[1]+y*dim[1]/2+rng.uniform(-.035,.035),loc[2]+z*dim[2]/2+rng.uniform(-.025,.025)) for z in (-1,1) for y in (-1,1) for x in (-1,1)]
            ob=mesh(label,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],material,root)
            if material==m['rock']:
                for v in ob.data.vertices:
                    v.co.x+=rng.uniform(-.10,.10);v.co.y+=rng.uniform(-.09,.09);v.co.z+=rng.uniform(-.045,.045)
                bevel=ob.modifiers.new('Broken sandstone edges','BEVEL');bevel.width=.095;bevel.segments=1
                bevel.affect='EDGES'
            return ob
        if name=='pontoon':
            for x in (-1.48,1.45):
                for y in (-.68,.68):
                    tube('Waterlogged pile',[(x,y,-.3),(x+.025,y,.50)],.095,m['bark'],root)
            for y in (-.61,.61):slab('Load bearing beam',(0,y,.37),(3.75,.16,.20),m['root'])
            for i in range(14):
                if i in (3,10):continue
                x=-1.76+i*.271
                ob=slab('Split wet plank',(x,rng.uniform(-.025,.025),.51+rng.uniform(-.025,.025)),(.24,1.72-rng.uniform(0,.15),.12),m['bark'])
                for j in range(2):
                    yy=-.55+j*.91+rng.uniform(-.1,.1)
                    tube('Wood split',[(x-.06,yy-.1,.58),(x-.03,yy+.12,.58),(x-.05,yy+.31,.58)],.007,m['root'],root)
            for x in (-1.48,1.45):
                tube('Sagging rope',[(x,-.70,.59),(x-.07,0,.54),(x,.70,.59)],.025,m['calcite'],root)
                for z in (.42,.47,.52):tube('Rope binding',[(x-.1,-.77,z),(x+.10,-.77,z),(x+.11,-.6,z),(x-.1,-.59,z)],.018,m['root'],root)
        elif name=='firefly_cage':
            tube('Crooked support stake',[(0,0,0),(.035,.015,.74),(0,0,.91)],.065,m['bark'],root)
            slab('Cage foot',(0,0,.82),(.82,.70,.09),m['schist'])
            for z in (.86,1.52):
                pts=[(.46*math.cos(j*math.tau/12),.39*math.sin(j*math.tau/12),z) for j in range(13)]
                tube('Fine iron hoop',pts,.022,m['schist'],root)
            for j in range(12):
                a=j*math.tau/12;x=.46*math.cos(a);y=.39*math.sin(a)
                tube('Iron cage rib',[(x,y,.85),(x,y,1.49),(x*.55,y*.55,1.67),(0,0,1.75)],.015,m['schist'],root)
            m['spore']=mat('Mycelium','C27BFF');m['core']=mat('Spore heart','E6C8FF')
            for i in range(11):
                x=rng.uniform(-.28,.28);y=rng.uniform(-.23,.23);z=rng.uniform(.97,1.48)
                pebble('Luminous spore',(x,y,z),(.035,.032,.044),m['spore'],root,i)
                pebble('Spore heart',(x-.012,y-.025,z+.01),(.016,.016,.021),m['core'],root,i+20)
            accents.extend([m['spore'],m['core']])
        else:
            def stone(label,loc,scale,material,seed):
                ob=pebble(label,loc,scale,material,root,seed)
                noise=random.Random(seed+901)
                for v in ob.data.vertices:
                    v.co*=noise.uniform(.76,1.19)
                return ob
            def broken_slab(label,loc,sx,sy,thick,seed,tilt=0,offering=False):
                noise=random.Random(seed); count=11
                ring=[]
                for j in range(count):
                    t=2*math.pi*j/count
                    r=noise.uniform(.85,1.10)
                    ring.append((math.cos(t)*sx*r,math.sin(t)*sy*r))
                verts=[]
                for height,factor in ((-thick/2,.87),(thick*.22,1),(thick/2,.90)):
                    verts.extend((x*factor,y*factor,height+noise.uniform(-.035,.035)) for x,y in ring)
                faces=[]
                for k in range(2):
                    for j in range(count):
                        q=(j+1)%count; a=k*count+j; b=k*count+q
                        faces.extend(((a,b,b+count),(a,b+count,a+count)))
                faces.append(tuple(reversed(range(count))))
                if offering:
                    # Uneven sunken offering socket: a deep dark recess in the surviving slab.
                    verts.extend((x*.30,y*.30,thick/2-.025) for x,y in ring)
                    verts.extend((x*.23,y*.23,-thick*.35) for x,y in ring)
                    for j in range(count):
                        q=(j+1)%count
                        faces.extend(((22+j,22+q,33+q,33+j),(33+j,33+q,44+q,44+j)))
                    faces.append(tuple(range(44,55)))
                else:
                    verts.append((-.12,.08,thick*.52))
                    faces.extend((22+j,22+(j+1)%count,33) for j in range(count))
                ob=mesh(label,verts,faces,m['rock'],root)
                ob.location=loc;ob.rotation_euler=(.035,tilt,-.13 if offering else .18)
                ob.data.materials.append(m['schist'])
                for poly in ob.data.polygons:
                    if (offering and poly.index>=55) or noise.random()<.23: poly.material_index=1
                return ob
            stone('Collapsed broad lowest step',(-.18,.08,.18),(1.66,.84,.25),m['schist'],301)
            stone('Broken upper pedestal',(-.63,.16,.43),(1.10,.69,.35),m['rock'],302)
            stone('Split pedestal shoulder',(.80,.30,.28),(.68,.67,.29),m['schist'],303)
            broken_slab('Surviving offering slab',(-.65,.03,.78),1.03,.77,.25,314,-.09,True)
            broken_slab('Fallen matching slab leaning on pedestal',(.99,-.16,.48),.80,.72,.23,318,.58)
            for i in range(25):
                t=rng.uniform(0,math.tau)
                x=math.cos(t)*rng.uniform(1.25,1.81);y=math.sin(t)*rng.uniform(.63,.97)
                stone('Angular chipped scree',(x,y,.065),(rng.uniform(.065,.21),rng.uniform(.055,.14),rng.uniform(.045,.12)),m['rock'] if i%3 else m['schist'],351+i)
            for i in range(5):
                x=-1.31+i*.58
                height=.84 if i<3 else .58
                tube('Dead root winding over altar',[(x+.24,.86,.04),(x+.03,.56,.37),(x-.12,.28,height),(x+.04,-.10,height+.025),(x-.16,-.52,.37),(x+.13,-.92,.04)],.033 if i%2 else .045,m['root'],root)
                tube('Root branch',[(x-.16,-.52,.37),(x-.37,-.67,.13),(x-.52,-.83,.035)],.018,m['root'],root)
            for i in range(17):
                x=rng.uniform(-1.32,.10);y=rng.uniform(-.49,.48)
                if (x+.65)**2+y*y<.15: continue
                stone('Beige calcite crust',(x,y,.925+.09*(x+.65)),(rng.uniform(.07,.18),rng.uniform(.05,.12),.018),m['calcite'],401+i)
        bpy.context.view_layer.update()
        q=world_to_camera_view(s,s.camera,Vector((0,0,0)))
        assert abs(q.x*size[0]-foot[0])<.01 and abs((1-q.y)*size[1]-foot[1])<.01
        cel.install('prop',normals=False)
        cel.setup_scene(samples=16)
        cel.toon_materials('prop')
        # AOV color independent of neutral, cel shaded diffuse.
        for material in accents:
            for node in material.node_tree.nodes:
                if node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=(*lin('E6C8FF' if material.name.startswith('Spore heart') else 'C27BFF'),1)
        path=OUT/(name+'.png')
        from PIL import Image
        rig.common.configure_passes(path)
        for material in accents:
            for node in material.node_tree.nodes:
                if node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=(*lin('E6C8FF' if material.name.startswith('Spore heart') else 'C27BFF'),1)
        s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        raw=list(OUT.glob(name+'_e__*.png'));assert len(raw)==1
        raw[0].replace(OUT/(name+'_e.png'))
        for pp in (path,OUT/(name+'_e.png')):
            with Image.open(pp) as im: result=im.convert('RGBA').resize(size,Image.Resampling.LANCZOS)
            result.save(pp)

        ep=OUT/(name+'_e.png')
        if name!='firefly_cage':ep.unlink(missing_ok=True)
        else:
            # Blender image scaling: PIL is only used by the shared render pipeline.
            im=bpy.data.images.load(str(ep),check_existing=False);im.scale((size[0]+1)//2,(size[1]+1)//2);im.filepath_raw=str(ep);im.file_format='PNG';im.save();bpy.data.images.remove(im)
        s['g4_foot']=list(foot);s['g4_profile']='prop';s['g4_normals']=False
        blend=SRC/('b3_'+name+('_v2' if '--revision' in sys.argv else '')+'.blend')
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(blend))
        # Shared TOP projector, shorter cast vector (x0.6), soft alpha in compositor.
        sun=bpy.data.objects['Sun_chaud_haut_gauche']; ray=sun.rotation_euler.to_matrix()@Vector((0,0,-1))
        ray.x*=.6;ray.y*=.6;rot=ray.to_track_quat('-Z','Y').to_euler()
        rig.create_rig('TOP',(512,512),reset=False);sun.rotation_euler=rot
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
    print('PASS B3b build: fallen_altar; CEL prop; normals=False')

if __name__=='__main__':
    if '--verify' in sys.argv:verify()
    else:build()



