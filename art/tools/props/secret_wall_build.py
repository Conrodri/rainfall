"""Secret walls: retained biome block geometry, camera and shared CEL renderer.
Rig/light/material helpers follow secret_lever_build.py; no game code changes.
"""
import bpy, math, sys, random, inspect, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.dont_write_bytecode=True
sys.path[:0]=[str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/iso/_deps')]
sys.path[:0]=[str(ROOT/'art/tools/terrain'),str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/night'),str(ROOT/'art/tools')]
import g_g2a_build as sandstone
import cel_style as cel
import iso_rig as rig
from PIL import Image, ImageChops, ImageStat
OUT=ROOT/'game/assets/sprites/props/secret'
HERE=Path(__file__).parent
BLEND=ROOT/'art/blender/props/g6_secret_wall.blend'
OUT.mkdir(parents=True,exist_ok=True)
BIOMES={'terraces':('terraces_iso',(.08,.48,.42,1)), 'fog_forest':('f2_block_a',(.76,.36,1.0,1)), 'rust_city':('f3_block_a',(.95,.22,.035,1)), 'crypts':('f4_block_a',(.10,.60,.85,1))}

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
    glow=mat('biome accent',accent,1)
    obs=[]
    if level==0:
        return [ribbon('hairline sandstone fissure',PATHS[0],.9,dark)]
    for i,p in enumerate(PATHS[:3 if level==1 else 6]):
        obs.append(ribbon('jagged split',p,{1:2.3,2:5.0,3:10.0}[level],dark))
        # Recessed glow is narrower than the broken stone lip.
        obs.append(ribbon('light through fracture',p,{1:.65,2:1.8,3:3.2}[level],glow))
    return obs

def render(path):
    cel.setup_scene(samples=8);cel.toon_materials('tile')
    for m in bpy.data.materials:
        ramp=m.node_tree.nodes.get('CEL tones') if m.use_nodes else None
        if ramp and m.name.startswith('sandstone'):
            for element,color in zip(ramp.color_ramp.elements,('2E221C','5A4232','7A5D45')):element.color=sandstone.linear(color)
    rig.render_frame(path,passes=False)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    hidden=[]
    for o in meshes:
        keep=not o.hide_render and any(m and m.get('rainfall_emissive') for m in o.data.materials)
        hidden.append((o,o.hide_render));o.hide_render=not keep
    epath=Path(path).with_name(Path(path).stem+'_e.png')
    if any(not o.hide_render for o in meshes):rig.render_frame(epath,passes=False)
    else:epath.unlink(missing_ok=True)
    for o,value in hidden:o.hide_render=value

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
    for biome in ('fog_forest',):
        source,accent=BIOMES[biome]
        s=rig.create_rig('MAP',(256,256))
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,64/rig.R,0))
        s.render.dither_intensity=0;s.render.image_settings.color_depth='8'
        s['iso_frame']=[256,256];s.render.resolution_x=s.render.resolution_y=512
        bpy.ops.object.empty_add();root=bpy.context.object;root.name='G6 sandstone wall'
        materials=sandstone.materials();sandstone.make('block_a',root,materials)
        rig.bake_ao_shadows(root);bpy.context.view_layer.update()
        accent=sandstone.linear('C27BFF')
        original=[o for o in s.objects if o.type=='MESH' and not o.hide_render]
        fracture=[]
        for level in (1,2):
            for o in fracture:bpy.data.objects.remove(o,do_unlink=True)
            fracture=cracks(level,accent)
            if level==2:
                for j,(x,y) in enumerate(((-.72,-1.02),(-.36,-1.11),(.10,-1.04))):
                    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,y,.055))
                    shard=bpy.context.object;shard.name='fallen sandstone flake';shard.scale=(.09,.065,.065);shard.data.materials.append(materials['sandstone']);original.append(shard)
            render(OUT/f'wall_{biome}_{level}.png')
        # Opening split, outward burst, falling pans, dust, settled low rubble.
        frames=[];emissions=[]
        for o in fracture:bpy.data.objects.remove(o,do_unlink=True)
        fracture=cracks(3,accent)
        render(OUT/f'wall_{biome}_break_0.png')
        frames.append(Image.open(OUT/f'wall_{biome}_break_0.png').copy())
        emissions.append(Image.open(OUT/f'wall_{biome}_break_0_e.png').copy())
        pieces=split_large(original);rng=random.Random(912)
        saved=[]
        for ob in pieces:
            world=ob.matrix_world.copy();ob.parent=None;ob.matrix_world=world
            center=sum((Vector(v) for v in ob.bound_box),Vector())/8
            wc=ob.matrix_world@center
            for v in ob.data.vertices:v.co-=center
            ob.location=wc
            saved.append((ob,wc.copy(),ob.rotation_euler.copy(),ob.scale.copy(),rng.uniform(-1,1),rng.uniform(-1,1)))
        dustmat=mat('ochre sandstone dust',sandstone.linear('A67A49'))
        dust=[]
        for j in range(15):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(rng.uniform(-.9,.9),rng.uniform(-.9,.9),rng.uniform(.12,.35)))
            ob=bpy.context.object;ob.name='low angular dust';ob.data.materials.append(dustmat);dust.append((ob,rng.uniform(.12,.32)))
        for frame in range(1,5):
            for ob in fracture:
                ob.hide_render=frame>=3
                ob.location.z=-.22*frame
                for m in ob.data.materials:
                    if m.get('rainfall_emissive'):
                        p=m.node_tree.nodes.get('Principled BSDF')
                        if p:p.inputs['Emission Strength'].default_value=.55 if frame==1 else .12
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
            ep=OUT/f'wall_{biome}_break_{frame}_e.png'
            emissions.append(Image.open(ep).copy() if ep.exists() else Image.new('RGBA',(256,256)))
            (OUT/f'wall_{biome}_break_{frame}_e.png').unlink(missing_ok=True)
        for suffix,images in (('',frames),('_e',emissions)):
            sheet=Image.new('RGBA',(1280,256))
            for i,im in enumerate(images):sheet.paste(im,(256*i,0))
            if suffix:sheet=sheet.resize((640,128),Image.Resampling.LANCZOS)
            sheet.save(OUT/f'wall_{biome}_break{suffix}.png')
        for level in (1,2):
            path=OUT/f'wall_{biome}_{level}_e.png'
            with Image.open(path) as im:small=im.resize((128,128),Image.Resampling.LANCZOS)
            small.save(path)
        for i in range(5):
            for suffix in ('','_e'):(OUT/f'wall_{biome}_break_{i}{suffix}.png').unlink(missing_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    verify()

def verify():
    rows=[];report={}
    for biome in ('fog_forest',):
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
        ref=states[0]
        a=ref.getchannel('A').point(lambda p:255 if p>127 else 0)
        ious=[]
        for im in states:
            b=im.getchannel('A').point(lambda p:255 if p>127 else 0)
            inter=sum(ImageChops.darker(a,b).getdata())/255;union=sum(ImageChops.lighter(a,b).getdata())/255
            ious.append(round(inter/union,4))
        assert ious[0]>.97,(biome,ious)
        energies=[]
        for suffix,size in (('1_e',(128,128)),('2_e',(128,128)),('break_e',(640,128))):
            path=OUT/f'wall_{biome}_{suffix}.png';im=Image.open(path).convert('RGBA');assert im.size==size
            energy=sum(sum(px[:3])*px[3]/255 for px in im.getdata());assert energy>2
            energies.append(round(energy))
        assert energies[1]>energies[0]
        report[biome]={'silhouette_iou':ious,'emission_energy':energies,'frames_distinct':5}
        row=Image.new('RGBA',(1024,128),(22,25,27,255))
        for i,im in enumerate(states+frames):row.alpha_composite(im.resize((128,128),Image.Resampling.LANCZOS),(i*128,0))
        rows.append(row)
    contact=Image.new('RGBA',(1024,128))
    for i,row in enumerate(rows):contact.paste(row,(0,128*i))
    contact.save(OUT/'secret_wall_contact.png')
    (HERE/'secret_wall_verify.log').write_text('PASS '+json.dumps(report)+'\n',encoding='utf8')
    print('PASS G6 secret_wall fog_forest 3 states 5 frames; verification PASS')

if __name__=='__main__':run()
