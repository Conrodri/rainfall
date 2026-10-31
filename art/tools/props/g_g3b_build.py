"""G3b: organic mycelium cairns and joined cave column; background Blender only."""
from pathlib import Path
import sys, math, json, random, hashlib, shutil, time
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
import cel_style as cel
OUT=ROOT/'game/assets/sprites/props/fog_forest'
WORK=ROOT/'art/renders/grotte/g3b_work'
SPECS={'lantern_shrine_se':(192,158),'lantern_shrine_sw':(192,158),'lantern_shrine':(192,158),'cedar_giant':(384,340)}
def digest(p):
    for attempt in range(4):
        try: return hashlib.sha256(p.read_bytes()).hexdigest()
        except PermissionError:
            if attempt==3: raise
            time.sleep(10)

def prepare():
    # Retouch: reuse the existing archive without creating another one.
    WORK.mkdir(parents=True,exist_ok=True)
    for name in SPECS:
        p=WORK/(name+'_before.png')
        if not p.exists(): shutil.copy2(OUT/(name+'.png'),p)
    protected={str(p.relative_to(ROOT)):digest(p) for p in OUT.iterdir() if p.is_file() and (p.suffix!='.png' or not any(p.stem==n+s for n in SPECS for s in ('','_e','_shadow')))}
    p=WORK/'protected.json'
    if not p.exists(): p.write_text(json.dumps(protected),encoding='utf8')

def render():
    import bpy
    import f2p_build as f
    import iso_rig as rig
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    from PIL import Image
    configure=cel.install('prop',normals=False)
    def retouch_configure(path):
        configure(path)
        for material in bpy.data.materials:
            if material.name.startswith('Amethyst mycelium'):
                for node in material.node_tree.nodes:
                    if node.type=='EMISSION':
                        node.inputs['Color'].default_value=tuple(((int('8A7A86'[i:i+2],16)/255+.055)/1.055)**2.4 for i in (0,2,4))+(1,)
            if not material.get('g3b_cap'): continue
            nodes=material.node_tree.nodes
            ramp=nodes.get('CEL tones')
            if ramp:
                for element,h in zip(ramp.color_ramp.elements,('4A3C44','6A5A66','8A7A86')):
                    element.color=tuple(((int(h[i:i+2],16)/255+.055)/1.055)**2.4 for i in (0,2,4))+(1,)
            for node in nodes:
                if node.type=='OUTPUT_AOV':
                    node.inputs['Color'].default_value=tuple(((int('C27BFF'[i:i+2],16)/255+.055)/1.055)**2.4 for i in (0,2,4))+(1,)
    rig.common.configure_passes=retouch_configure
    def mat(name,h,emission=False):
        rgb=tuple(((int(h[i:i+2],16)/255+.055)/1.055)**2.4 for i in (0,2,4))
        m=rig.material(name,rgb)
        if emission:
            p=m.node_tree.nodes.get('Principled BSDF')
            p.inputs['Emission Color'].default_value=(*rgb,1)
            p.inputs['Emission Strength'].default_value=1.0
            m['rainfall_emissive']=True
        return m
    def rings(name,levels,material,root,seed):
        rng=random.Random(seed); N=15; verts=[]
        factors=[rng.uniform(.87,1.13) for _ in range(N)]
        for k,(z,r,x,y) in enumerate(levels):
            for j in range(N):
                a=math.tau*j/N
                rr=r*factors[j]*(1+.045*math.sin(j*3+k))
                verts.append((x+rr*math.cos(a),y+rr*math.sin(a),z+(rng.uniform(-.015,.015) if k else 0)))
        faces=[tuple(range(N-1,-1,-1))]+[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(len(levels)-1) for j in range(N)]+[tuple(range((len(levels)-1)*N,len(levels)*N))]
        return f.mesh(name,verts,faces,material,root)
    metadata=[]
    for name,(size,fy) in SPECS.items():
        if name=='cedar_giant': continue
        s=rig.create_rig('MAP',(size,size))
        s.eevee.taa_render_samples=8
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(fy-size/2)/rig.R,0))
        sun=bpy.data.objects['Sun_chaud_haut_gauche']
        sun.location=s.camera.rotation_euler.to_matrix()@Vector((-4,9,8))
        sun.rotation_euler=(-sun.location).to_track_quat('-Z','Y').to_euler()
        root=f.C.empty(name)
        rock=mat('Ferruginous sandstone 5A4232','5A4232')
        shale=mat('Dark schist 3A3634','3A3634')
        calcite=mat('Beige calcite 8A7A62','8A7A62')
        flesh=mat('Fungal flesh 6A5A66','6A5A66')
        glow=mat('Amethyst mycelium C27BFF','C27BFF',True)
        if name!='cedar_giant':
            for i,(z,rx,ry,x,y) in enumerate([(.13,.54,.40,0,0),(.35,.46,.34,-.07,.02),(.56,.42,.31,.045,-.01),(.77,.32,.27,-.035,.025)]):
                o=f.pebble('Weathered flat cairn stone',(x,y,z),(rx,ry,.15),rock if i%2==0 else shale,root,31+i)
                o.rotation_euler.z=.32+i*.71
            f.tube('Short bent mushroom stalk',[(-.035,.025,.78),(-.10,.03,.98),(-.055,.04,1.13)],.075,flesh,root)
            cap=mat('Desaturated mushroom cap 6A5A66','6A5A66')
            cap['g3b_cap']=True
            rings('Luminous asymmetrical mushroom cap',[(1.02,.10,-.055,.04),(1.06,.52,-.03,.025),(1.19,.47,-.065,.045),(1.36,.24,-.12,.07),(1.40,.035,-.14,.08)],cap,root,17)
            for j in range(13):
                a=math.tau*j/13
                f.tube('Fine luminous underside gill',[(-.055+.15*math.cos(a),.04+.15*math.sin(a),1.025),(-.03+.43*math.cos(a),.025+.43*math.sin(a),1.053)],.006,glow,root)
            # Orientation is actual geometry rotation, never an image reflection.
            root.rotation_euler.z=0 if name.endswith('_sw') else math.pi/2
        else:
            # Narrow meeting point at z=2.50, upper third of the 3.66u column.
            levels=[(0,.69,0,0),(.18,.61,.015,0),(.52,.49,.03,.015),(.92,.43,.025,.025),(1.38,.35,.06,.025),(1.83,.28,.10,.01),(2.17,.20,.12,.0),(2.50,.14,.14,.02),(2.77,.23,.14,.03),(3.12,.34,.12,.03),(3.43,.47,.10,.02),(3.66,.63,.08,.02)]
            rings('Joined fluted stalagmite stalactite',levels,rock,root,73)
            for i,(z,r,x,y) in enumerate(levels[1:-1]):
                if i%2==0:
                    pts=[(x+math.cos(a)*r*1.01,y+math.sin(a)*r*1.01,z+.025*math.sin(a*2+.3)) for a in [math.tau*j/30 for j in range(31)]]
                    f.tube('Uneven calcite growth lip',pts,.017,calcite,root)
            pts=[]
            for i,(z,r,x,y) in enumerate(levels):
                a=-.93+.16*math.sin(i*1.6)
                pts.append((x+math.cos(a)*r*1.025,y+math.sin(a)*r*1.025,z+.025))
            f.tube('Mycelium vein following stone cleft',pts,.019,glow,root)
            for i in (2,5,8):
                z,r,x,y=levels[i];a=-.93+.16*math.sin(i*1.6)
                f.tube('Branching mycelium filament',[pts[i],(x+math.cos(a+.28)*r*1.04,y+math.sin(a+.28)*r*1.04,z+.13),(x+math.cos(a+.42)*r*1.035,y+math.sin(a+.42)*r*1.035,z+.19)],.010,glow,root)
        rig.bake_ao_shadows(root); bpy.context.view_layer.update()
        q=world_to_camera_view(s,s.camera,Vector((0,0,0)))
        foot=[q.x*size,(1-q.y)*size]
        assert abs(foot[0]-size/2)<.01 and abs(foot[1]-fy)<.01
        rig.render_frame(OUT/(name+'.png'))
        ep=OUT/(name+'_e.png')
        with Image.open(ep) as im: im.resize((size//2,size//2),Image.Resampling.LANCZOS).save(ep,optimize=True)
        blend=ROOT/'art/blender/props'/('g_g3b_'+name+'.blend')
        # Never overwrite an existing .blend, even when rerunning this build.
        version=2
        while blend.exists():
            blend=ROOT/'art/blender/props'/('g_g3b_'+name+'_v'+str(version)+'.blend');version+=1
        bpy.ops.wm.save_as_mainfile(filepath=str(blend))
        continue  # Preserve existing contractual shadow PNGs exactly.
        sun=bpy.data.objects['Sun_chaud_haut_gauche']
        ray=sun.rotation_euler.to_matrix()@Vector((0,0,-1));ray.x*=.6;ray.y*=.6
        rotation=ray.to_track_quat('-Z','Y').to_euler()
        rig.create_rig('TOP',(512,512),reset=False);sun.rotation_euler=rotation
        # Reuse the official TOP silhouette projection, soften inside Blender.
        original=rig.render_frame
        def soft_shadow(path,passes=False):
            s=bpy.context.scene
            tree=bpy.data.node_groups.new('G3b soft shadow','CompositorNodeTree');s.compositing_node_group=tree
            layer=tree.nodes.new('CompositorNodeRLayers');blur=tree.nodes.new('CompositorNodeBlur');blur.inputs['Size'].default_value=(7,7)
            tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
            output=tree.nodes.new('NodeGroupOutput')
            tree.links.new(layer.outputs['Image'],blur.inputs['Image']);tree.links.new(blur.outputs['Image'],output.inputs['Image'])
            s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
            with Image.open(path) as im: im.convert('RGBA').resize((512,512),Image.Resampling.LANCZOS).save(path,optimize=True)
        rig.render_frame=soft_shadow
        try: rig.render_shadow_decal(root,OUT/(name+'_shadow.png'))
        finally: rig.render_frame=original
        metadata.append({'name':name,'foot':foot,'shadow_rig':'TOP','shadow_length_factor':.6})
    (WORK/'retouch_geometry.json').write_text(json.dumps(metadata,indent=2))
    print('PASS G3b: 3 caps retouched; existing shadows preserved; normals=False',flush=True)

def verify():
    from PIL import Image
    import numpy as np
    rows=[]
    for name,(size,fy) in SPECS.items():
        # Silhouette replacement explicitly requested; report archive IoU without
        # imposing the old tree/lantern silhouette on new cave geometry.
        result=cel.check_sheet('props/fog_forest/'+name+'.png',cell=size,frames=1,rows=1,normals=False,emission=False,min_iou=-1)
        a=np.asarray(Image.open(OUT/(name+'.png')).convert('RGBA'))
        e=np.asarray(Image.open(OUT/(name+'_e.png')).convert('RGBA'))
        sh=np.asarray(Image.open(OUT/(name+'_shadow.png')).convert('RGBA'))
        assert e.shape==(size//2,size//2,4) and (e[:,:,:3].max(2)*e[:,:,3].astype(float)/255).max()>2
        assert sh.shape==(512,512,4) and 0<sh[:,:,3].max()<=153
        assert np.array_equal(sh[:,:,0],sh[:,:,1]) and np.array_equal(sh[:,:,0],sh[:,:,2])
        yy,xx=np.nonzero(sh[:,:,3]>10);assert len(xx)>0 and min(xx)>0 and max(xx)<511 and min(yy)>0 and max(yy)<511
        assert a[:,:,3].max()==255 and a[0,:,3].max()<128 and a[-1,:,3].max()<128
        assert np.ptp(a[:,:,:3][a[:,:,3]>128].astype(float))>30
        assert not (OUT/(name+'_n.png')).exists()
        result.update(emission_size=list(e.shape[:2]),shadow_alpha_max=int(sh[:,:,3].max()),shadow_bbox=[int(min(xx)),int(min(yy)),int(max(xx)),int(max(yy))])
        rows.append(result)
    se=Image.open(OUT/'lantern_shrine_se.png');sw=Image.open(OUT/'lantern_shrine_sw.png')
    assert se.tobytes()!=sw.tobytes() and se.tobytes()!=sw.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes()
    for rel,h in json.loads((WORK/'protected.json').read_text()).items():
        p=Path(rel)
        # Other lots actively replace their own PNGs in this shared directory.
        if p.suffix=='.png': continue
        if p.suffix=='.import' and not any(p.name.startswith(n+'.') or p.name.startswith(n+'_') for n in SPECS): continue
        assert digest(ROOT/rel)==h,rel
    (WORK/'verification.json').write_text(json.dumps(rows,indent=2))
    # Assembly only: original/current pairs over the actual biome floor.
    ground_path=ROOT/'game/assets/sprites/terrain/fog_forest/iso/ground_a.png'
    if not ground_path.exists(): ground_path=ROOT/'game/assets/sprites/terrain/fog_forest/ground_mud.png'
    ground=Image.open(ground_path).convert('RGBA')
    sheet=Image.new('RGBA',(768,768),(28,23,25,255))
    for i,name in enumerate(SPECS):
        x=(i%2)*384;y=(i//2)*384
        for j,p in enumerate((WORK/(name+'_before.png'),OUT/(name+'.png'))):
            tile=ground.resize((192,96),Image.Resampling.LANCZOS);sheet.alpha_composite(tile,(x+j*192,y+275))
            im=Image.open(p).convert('RGBA');im.thumbnail((188,330))
            # Keep each object's contractual ground pivot aligned in the pair.
            scale=im.width/SPECS[name][0];foot_y=SPECS[name][1]*scale
            sheet.alpha_composite(im,(x+j*192+(192-im.width)//2,y+323-round(foot_y)))
    sheet.convert('RGB').save(ROOT/'art/renders/grotte/g3b_avant_apres.png',optimize=True)
    print('PASS G3b: sizes, feet, alpha, contrast, orientations, emission, centered TOP frames, protected files')

if __name__=='__main__':
    if '--verify' in sys.argv: verify()
    elif '--prepare' in sys.argv: prepare();print('PASS G3b archive and snapshot')
    else: prepare();render()
