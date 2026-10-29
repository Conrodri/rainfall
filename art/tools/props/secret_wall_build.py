"""Secret walls: retained biome block geometry, camera and shared CEL renderer.
Rig/light/material helpers follow secret_lever_build.py; no game code changes.
"""
import bpy, math, sys, random, inspect, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.dont_write_bytecode=True
sys.path[:0]=[str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/iso/_deps')]
import cel_style as cel
import iso_rig as rig
from PIL import Image, ImageChops, ImageStat
OUT=ROOT/'game/assets/sprites/props/secret'
HERE=Path(__file__).parent
OUT.mkdir(parents=True,exist_ok=True)
BIOMES={'terraces':('terraces_iso',(.08,.48,.42,1)), 'fog_forest':('f2_block_a',(.80,.37,.08,1)), 'rust_city':('f3_block_a',(.95,.22,.035,1)), 'crypts':('f4_block_a',(.10,.60,.85,1))}
# Keep the official renderer, suppress its obsolete compulsory normal enumeration.
code=inspect.getsource(rig.render_frame).replace("for suffix in ('_n','_e'):","for suffix in ('_e',):")
exec(compile(code,rig.__file__,'exec'),rig.__dict__)

def mat(name,color,emit=0):
    m=bpy.data.materials.new(name);m.diffuse_color=color;m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=color;p.inputs['Roughness'].default_value=.83
    if emit:
        p.inputs['Emission Color'].default_value=color;p.inputs['Emission Strength'].default_value=emit
        m['rainfall_emissive']=True
    return m

def ribbon(name,points,width,material):
    s=bpy.context.scene;cam=s.camera;basis=cam.rotation_euler.to_matrix()
    forward=basis@Vector((0,0,-1));right=basis@Vector((1,0,0));up=basis@Vector((0,1,0))
    verts=[];faces=[];deps=bpy.context.evaluated_depsgraph_get()
    for a,b in zip(points,points[1:]):
        delta=Vector((b[0]-a[0],b[1]-a[1]));side=Vector((-delta.y,delta.x)).normalized()*width/2
        # Small independent quads adhere to the actual authored chipped surfaces.
        steps=max(1,int(delta.length/2))
        for j in range(steps):
            quad=[]
            for t,sign in ((j/steps,-1),(j/steps,1),((j+1)/steps,1),((j+1)/steps,-1)):
                q=Vector(a).lerp(Vector(b),t)+side*sign
                origin=cam.location+right*((q.x-128)/rig.R)+up*((128-q.y)/rig.R)
                hit,loc,*_=s.ray_cast(deps,origin,forward)
                if not hit: break
                quad.append(loc-forward*.016)
            if len(quad)==4:
                k=len(verts);verts.extend(quad);faces.append(tuple(range(k,k+4)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.materials.append(material)
    ob=bpy.data.objects.new(name,mesh);s.collection.objects.link(ob);return ob

PATHS=[[(129,53),(122,71),(132,87),(119,106),(125,123),(111,145),(117,166),(108,189)],[(130,87),(154,100),(164,118),(183,126)],[(121,106),(99,111),(91,129),(72,139)],[(125,123),(147,139),(143,158),(162,174)],[(122,71),(102,76),(89,88)],[(111,145),(91,154),(81,173)]]

def cracks(level,accent):
    dark=mat('fracture exposed dark stone',(.012,.015,.016,1))
    glow=mat('biome accent',accent,1.7 if level==1 else 2.8)
    obs=[]
    for i,p in enumerate(PATHS[:3 if level==1 else 6]):
        obs.append(ribbon('jagged split',p,{1:2.3,2:5.0,3:10.0}[level],dark))
        # Recessed glow is narrower than the broken stone lip.
        obs.append(ribbon('light through fracture',p,{1:.65,2:1.8,3:3.2}[level],glow))
    return obs

def render(path):
    cel.setup_scene(samples=8);cel.toon_materials('tile');rig.render_frame(path)

def split_large(objects):
    import bmesh
    result=[]
    for ob in objects:
        if max(ob.dimensions)<1.4: result.append(ob);continue
        # Subdivide continuous backing into six falling masonry pans.
        for ix in range(3):
          for iz in range(2):
            bm=bmesh.new();bm.from_mesh(ob.data);bm.transform(ob.matrix_world)
            for co,no in [((-1+ix*2/3,0,0),(1,0,0)),((-1+(ix+1)*2/3,0,0),(-1,0,0)),((0,0,iz*.7),(0,0,1)),((0,0,(iz+1)*.7),(0,0,-1))]:
                if bm.verts:
                    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=co,plane_no=no,clear_inner=True,dist=.00001)
            if bm.faces:
                mesh=bpy.data.meshes.new('broken backing');bm.to_mesh(mesh)
                for m in ob.data.materials:mesh.materials.append(m)
                child=bpy.data.objects.new('fractured pan',mesh);bpy.context.scene.collection.objects.link(child);result.append(child)
            bm.free()
        ob.hide_render=True
    return result

def run():
    cel.install('tile',normals=False)
    for biome,(source,accent) in BIOMES.items():
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/terrain'/ (source+'.blend')))
        if biome=='terraces':bpy.context.window.scene=bpy.data.scenes['block_a']
        s=bpy.context.scene;s.render.dither_intensity=0;s.render.image_settings.color_depth='8'
        s['iso_frame']=[256,256];s.render.resolution_x=s.render.resolution_y=512
        original=[o for o in s.objects if o.type=='MESH' and not o.hide_render]
        # Exact intact artwork; preserves every weathered detail of the adjacent block.
        reference=ROOT/f'game/assets/sprites/terrain/{biome}/iso/block_a.png'
        Image.open(reference).save(OUT/f'wall_{biome}_0.png')
        fracture=[]
        for level in (1,2):
            for o in fracture:bpy.data.objects.remove(o,do_unlink=True)
            fracture=cracks(level,accent);render(OUT/f'wall_{biome}_{level}.png')
        # Opening split, outward burst, falling pans, dust, settled low rubble.
        frames=[];emissions=[]
        for o in fracture:bpy.data.objects.remove(o,do_unlink=True)
        fracture=cracks(3,accent)
        render(OUT/f'wall_{biome}_break_0.png')
        frames.append(Image.open(OUT/f'wall_{biome}_break_0.png').copy())
        emissions.append(Image.open(OUT/f'wall_{biome}_break_0_e.png').copy())
        for o in fracture:bpy.data.objects.remove(o,do_unlink=True)
        pieces=split_large(original);rng=random.Random(912)
        saved=[]
        for ob in pieces:
            world=ob.matrix_world.copy();ob.parent=None;ob.matrix_world=world
            center=sum((Vector(v) for v in ob.bound_box),Vector())/8
            wc=ob.matrix_world@center
            for v in ob.data.vertices:v.co-=center
            ob.location=wc
            saved.append((ob,wc.copy(),ob.rotation_euler.copy(),ob.scale.copy(),rng.uniform(-1,1),rng.uniform(-1,1)))
        dustmat=mat('desaturated angular masonry dust',(.105,.11,.10,1))
        dust=[]
        for j in range(15):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(rng.uniform(-.9,.9),rng.uniform(-.9,.9),rng.uniform(.12,.35)))
            ob=bpy.context.object;ob.name='low angular dust';ob.data.materials.append(dustmat);dust.append((ob,rng.uniform(.12,.32)))
        for frame in range(1,5):
            for ob,loc,rot,scale,rx,ry in saved:
                ob.location=loc+Vector((rx*.13*min(frame,2),ry*.13*min(frame,2),0))
                ob.rotation_euler=rot;ob.rotation_euler.x+=rx*.22*frame;ob.rotation_euler.y+=ry*.22*frame
                ob.scale=scale.copy()
                if frame>=2:
                    ob.location.z=max(.055,loc.z-(frame-1)*.48)
                    ob.scale.z*=max(.12,1-(frame-1)*.27)
                if frame==4:ob.scale*=.65;ob.location.z=.045
            for ob,radius in dust:
                ob.hide_render=frame==1 or frame==4
                ob.scale=(radius*(1+frame*.13),radius*(1+frame*.13),radius*.65)
            path=OUT/f'wall_{biome}_break_{frame}.png';render(path)
            frames.append(Image.open(path).copy())
            emissions.append(Image.new('RGBA',(256,256)))
        for suffix,images in (('',frames),('_e',emissions)):
            sheet=Image.new('RGBA',(1280,256))
            for i,im in enumerate(images):sheet.paste(im,(256*i,0))
            sheet.save(OUT/f'wall_{biome}_break{suffix}.png')
        for i in range(5):
            for suffix in ('','_e'):(OUT/f'wall_{biome}_break_{i}{suffix}.png').unlink(missing_ok=True)
        if biome=='crypts':
            bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/props/secret_wall.blend'))
    verify()

def verify():
    rows=[];report={}
    for biome in BIOMES:
        states=[Image.open(OUT/f'wall_{biome}_{i}.png').convert('RGBA') for i in range(3)]
        sheet=Image.open(OUT/f'wall_{biome}_break.png').convert('RGBA')
        assert all(im.size==(256,256) for im in states) and sheet.size==(1280,256)
        assert len({hashlib.sha256(im.tobytes()).hexdigest() for im in states})==3
        frames=[sheet.crop((i*256,0,(i+1)*256,256)) for i in range(5)]
        assert len({hashlib.sha256(im.tobytes()).hexdigest() for im in frames})==5
        assert all(im.getchannel('A').getbbox() for im in states+frames)
        for im in states+frames:
            assert not im.getchannel('A').getpixel((0,0))
            assert max(ImageStat.Stat(im.convert('RGB'),im.getchannel('A')).stddev)>5
        ref=Image.open(ROOT/f'game/assets/sprites/terrain/{biome}/iso/block_a.png').convert('RGBA')
        a=ref.getchannel('A').point(lambda p:255 if p>127 else 0)
        ious=[]
        for im in states:
            b=im.getchannel('A').point(lambda p:255 if p>127 else 0)
            inter=sum(ImageChops.darker(a,b).getdata())/255;union=sum(ImageChops.lighter(a,b).getdata())/255
            ious.append(round(inter/union,4))
        assert min(ious)>.97,(biome,ious)
        energies=[]
        for suffix,size in (('1_e',(256,256)),('2_e',(256,256)),('break_e',(1280,256))):
            path=OUT/f'wall_{biome}_{suffix}.png';im=Image.open(path).convert('RGBA');assert im.size==size
            energy=sum(sum(px[:3])*px[3]/255 for px in im.getdata());assert energy>2
            energies.append(round(energy))
        assert energies[1]>energies[0]
        report[biome]={'silhouette_iou':ious,'emission_energy':energies,'frames_distinct':5}
        row=Image.new('RGBA',(1024,128),(22,25,27,255))
        for i,im in enumerate(states+frames):row.alpha_composite(im.resize((128,128),Image.Resampling.LANCZOS),(i*128,0))
        rows.append(row)
    contact=Image.new('RGBA',(1024,512))
    for i,row in enumerate(rows):contact.paste(row,(0,128*i))
    contact.save(OUT/'secret_wall_contact.png')
    (HERE/'secret_wall_verify.log').write_text('PASS '+json.dumps(report)+'\n',encoding='utf8')
    print('PASS secret_wall: 16 diffuse, 12 emission, 4 biomes, 5 break frames; verification PASS')

if __name__=='__main__':run()
