"""G4: MAP organic props, shared F2 geometry and CEL pipeline; no integration edits."""
from pathlib import Path
import sys, math, random, json, hashlib
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(ROOT/'art/tools'/p) for p in ('cel','iso','night')]
import cel_style as cel
OUT = ROOT/'game/assets/sprites/props/fog_forest'
SRC = ROOT/'art/blender/props'
SPECS = {'hanging_roots':((256,320),(128,300)), 'calcite_cascade':((192,256),(96,236)), 'mushroom_shelf':((192,192),(96,166))}

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
        assert not np.any(a[[0,-1],:,3]>5) and not np.any(a[:,[0,-1],3]>5), 'clipped '+name
        rgb=a[:,:,:3][a[:,:,3]>240].astype(float)
        contrast=float(np.percentile(rgb.mean(1),95)-np.percentile(rgb.mean(1),5))
        assert contrast>25, (name,contrast)
        sh=np.asarray(Image.open(OUT/(name+'_shadow.png')).convert('RGBA'))
        assert sh.shape==(512,512,4) and 0<sh[:,:,3].max()<=153
        assert np.array_equal(sh[:,:,0],sh[:,:,1]) and np.array_equal(sh[:,:,1],sh[:,:,2])
        if name!='calcite_cascade':
            e=Image.open(OUT/(name+'_e.png')); assert e.size==tuple((n+1)//2 for n in size)
            v=np.asarray(e).astype(float); assert (v[:,:,:3].max(2)*v[:,:,3]/255).max()>2
        else: assert not (OUT/(name+'_e.png')).exists()
        hashes.append(hashlib.sha256(p.read_bytes()).hexdigest())
        results.append(dict(name=name,size=size,foot=foot,contrast=round(contrast,2),cel=check))
    assert len(set(hashes))==3
    (HERE/'_g4_verification.json').write_text(json.dumps(results,indent=2))
    # Assembly only: real biome ground, three new assets, four reference sprites.
    canvas=Image.new('RGBA',(960,600),(23,20,23,255))
    gp=ROOT/'game/assets/sprites/terrain/fog_forest/iso/ground_a.png'
    if not gp.exists(): gp=ROOT/'game/assets/sprites/terrain/fog_forest/ground_mud.png'
    ground=Image.open(gp).convert('RGBA')
    for i,(name,(size,foot)) in enumerate(SPECS.items()):
        x=160+i*320; y=338
        g=ground.copy(); g.thumbnail((320,160)); canvas.alpha_composite(g,(x-g.width//2,y-g.height//2))
        canvas.alpha_composite(Image.open(OUT/(name+'.png')).convert('RGBA'),(x-foot[0],y-foot[1]))
        ep=OUT/(name+'_e.png')
        if ep.exists(): canvas.alpha_composite(Image.open(ep).convert('RGBA'),(i*320+15,365))
    for i,name in enumerate(('stump','mushrooms','standing_stone','root_arch_a')):
        im=Image.open(OUT/(name+'.png')).convert('RGBA');im.thumbnail((140,145))
        canvas.alpha_composite(im,(340+i*150,440))
    canvas.save(HERE/'_g4_contact.png')
    print('PASS G4: 8 PNG; dimensions alpha contrast distinct frames feet MAP shadows TOP; no normals')

def build():
    import bpy
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    import iso_rig as rig
    from f2p_build import tube, pebble
    from f2_build import mesh
    C=rig.common
    cel.archive_folder('props/fog_forest')
    for name in (() if '--retry' in sys.argv else SPECS):
        assert not (OUT/(name+'.png')).exists(), 'G4 refuses overwrite: '+name
        assert not (SRC/('g_'+name+'.blend')).exists(), 'Existing blend: '+name
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
        # Local x is camera horizontal, y is depth; rotate organic construction to MAP.
        root.rotation_euler.z=math.pi/4
        if name=='hanging_roots':
            rng=random.Random(404)
            tube('Overhead dead root', [(-1.04,.04,3.22),(-.58,.08,3.35),(.12,.06,3.22),(.95,.02,3.30)],.09,m['root'],root)
            for i in range(15):
                x=-.97+i*.136; top=3.23+rng.uniform(-.08,.07); end=.04 if i%3==0 else rng.uniform(.18,.85)
                pts=[(x,.03,top),(x+rng.uniform(-.12,.12),.04,top*.78),(x+rng.uniform(-.18,.18),-.03,top*.42),(x+rng.uniform(-.16,.16),-.09,end)]
                tube('Tapered hanging dead root',pts,.025+(i%4)*.011,m['root'] if i%3 else m['bark'],root)
                for j in (1,2):
                    x1,y,z=pts[j];tube('Split dry tendril',[(x1,y,z),(x1+(.12 if i%2 else -.12),y-.03,z-.24),(x1+.16,y-.03,z-.4)],.009,m['root'],root)
            for i,x in enumerate((-.64,.03,.67)):
                pts=[(x,-.13,2.9),(x+.06,-.16,2.45),(x-.07,-.17,1.98),(x+.03,-.18,1.56-i*.16)]
                tube('Mycelium hair',pts,.012,m['filament'],root)
            accents.append(m['filament'])
        elif name=='calcite_cascade':
            pebble('Fractured sandstone block',(0,.1,.69),(.69,.46,.83),m['rock'],root,42)
            pebble('Broken shoulder',(-.3,.09,1.25),(.4,.32,.52),m['schist'],root,8)
            # Irregular hanging mineral sheets: connected folded mesh, no crystals.
            rng=random.Random(426); N=30; levels=9; verts=[]
            for k in range(levels):
                t=k/(levels-1)
                for j in range(N):
                    u=j/(N-1); x=(u-.5)*(1.21-.2*t)
                    z=.14+t*(1.92+.09*math.sin(u*11))+.035*math.sin(j*1.3+k*.4)
                    y=-.32-.13*math.sin(math.pi*t)-.085*math.cos(u*math.pi*12)+.025*math.sin(k+u*13)
                    verts.append((x,y,z))
            faces=[(k*N+j,k*N+j+1,(k+1)*N+j+1,(k+1)*N+j) for k in range(levels-1) for j in range(N-1)]
            ob=mesh('Folded flowstone drapery',verts,faces,m['calcite'],root)
            for i in range(6):
                x=-.47+i*.186
                tube('Thin wet mineral glint',[(x,-.44,.35),(x+.024,-.53,.8),(x-.014,-.48,1.36),(x+.01,-.37,1.83)],.007,m['wet'],root)
            for i in range(5):pebble('Calcite apron',(-.50+i*.25,-.12,.07),(.21,.18,.07),m['calcite'],root,i+70)
        else:
            pebble('Split shelf sandstone',(0,.14,.53),(.53,.41,.64),m['rock'],root,33)
            pebble('Upper shale',(.12,.15,.99),(.36,.28,.30),m['schist'],root,63)
            for i,(x,z,r) in enumerate(((-.26,.41,.43),(.18,.68,.48),(-.22,.94,.38),(.12,1.18,.31),(.40,.34,.27))):
                # Fan shaped bracket; sculpted rim and pale underside, no luminous diffuse.
                N=19;verts=[]
                for rr,h in ((0,.12),(.46,.10),(1,0),(.95,-.055),(.20,-.07)):
                    for j in range(N):
                        a=math.pi*.05+j/(N-1)*math.pi*.9
                        rad=r*rr*(1+.045*math.sin(j*2.7+i))
                        verts.append((x+rad*math.cos(a),-.12-rad*math.sin(a),z+h))
                faces=[(k*N+j,k*N+j+1,(k+1)*N+j+1,(k+1)*N+j) for k in range(4) for j in range(N-1)]
                ob=mesh('Mauve bracket fan',verts,faces,m['cap'],root)
                ob.data.materials.append(m['gill'])
                for p in ob.data.polygons:
                    if p.index>=2*(N-1):p.material_index=1
                for j in range(9):
                    a=.15+j/8*(math.pi-.3)
                    tube('Bracket gills',[(x+math.cos(a)*r*.22,-.12-math.sin(a)*r*.22,z-.06),(x+math.cos(a)*r*.90,-.12-math.sin(a)*r*.9,z-.045)],.006,m['gill'],root)
            accents.append(m['cap'])
        bpy.context.view_layer.update()
        q=world_to_camera_view(s,s.camera,Vector((0,0,0)))
        assert abs(q.x*size[0]-foot[0])<.01 and abs((1-q.y)*size[1]-foot[1])<.01
        cel.install('prop',normals=False)
        cel.toon_materials('prop')
        # AOV color independent of neutral, cel shaded diffuse.
        for material in accents:
            for node in material.node_tree.nodes:
                if node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=(*lin('C27BFF'),1)
        rig.render_frame(OUT/(name+'.png'))
        ep=OUT/(name+'_e.png')
        if name=='calcite_cascade':ep.unlink(missing_ok=True)
        else:
            # Blender image scaling: PIL is only used by the shared render pipeline.
            im=bpy.data.images.load(str(ep),check_existing=False);im.scale((size[0]+1)//2,(size[1]+1)//2);im.filepath_raw=str(ep);im.file_format='PNG';im.save();bpy.data.images.remove(im)
        s['g4_foot']=list(foot);s['g4_profile']='prop';s['g4_normals']=False
        blend=SRC/('g_'+name+('_v2' if '--revision' in sys.argv else '')+'.blend')
        if not blend.exists(): bpy.ops.wm.save_as_mainfile(filepath=str(blend))
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
    print('PASS G4 build: 3 props, MAP feet, TOP shadows, CEL prop, normals=False')

if __name__=='__main__':
    if '--verify' in sys.argv:verify()
    else:build()



