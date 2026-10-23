"""C10: ground pickups, CREA 30deg, 64px/unit, contractual atlases.
Run with Blender --background --python art/tools/iso/c10_build.py.
"""
import bpy, sys, math, json, hashlib, tempfile
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
import iso_rig as rig
from PIL import Image
C=rig.common
OUT=ROOT/'game/assets/sprites/pickups'
INV=Path(__file__).with_name('_c10_inventory.json')

def mat(name,hex,metal=0,rough=.5,emit=0):
    rgb=tuple((int(hex[i:i+2],16)/255)**2.2 for i in (0,2,4))
    m=C.material(name,rgb,metal,rough,emit,grain=True)
    n=m.node_tree.nodes;l=m.node_tree.links;p=n['Principled BSDF']
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=28
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.25;ramp.color_ramp.elements[0].color=tuple(v*.3 for v in rgb)+(1,)
    ramp.color_ramp.elements[1].position=.78;ramp.color_ramp.elements[1].color=tuple(min(v*1.4,1) for v in rgb)+(1,)
    l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
    return m

def cylinder(name,loc,r,depth,m,parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=r,depth=depth,location=loc)
    return C.finish(bpy.context.object,name,m,parent,.006)

def coin(metal,patina):
    root=C.empty('Ground engraved bronze coin')
    cylinder('Worn bronze blank',(0,0,.035),.235,.055,metal,root)
    C.ring('Raised worn border',(0,0,.069),.211,.008,metal,root,rotation=(0,0,0))
    cylinder('Recessed oxidised face',(0,0,.065),.182,.008,patina,root)
    # Engraved sun / rain emblem, visible from the elevated camera.
    C.ring('Engraved sun',(0,0,.073),.065,.009,metal,root,rotation=(0,0,0))
    for i in range(8):
        a=i*math.tau/8
        C.rod('Radial engraving',(.094*math.cos(a),.094*math.sin(a),.075),(.148*math.cos(a),.148*math.sin(a),.075),.008,metal,root)
    for i in range(24):
        a=i*math.tau/24
        C.box('Milled rim',(.224*math.cos(a),.224*math.sin(a),.036),(.012,.013,.04),patina,root,.002).rotation_euler.z=a
    root.rotation_euler=(.22,.10,-.3)
    root.location.z=.025
    return root

def bag(leather,dark,metal):
    root=C.empty('Ground leather purse')
    # Sewn irregular panels, gathered neck: one constructed mesh.
    verts=[];count=14
    rings=[(.022,.155),(.10,.232),(.23,.218),(.34,.142),(.39,.078),(.45,.105)]
    for j,(z,r) in enumerate(rings):
        for i in range(count):
            a=i*math.tau/count; rr=r*(1+.065*math.sin(i*3+j))
            verts.append((rr*math.cos(a),rr*.73*math.sin(a),z))
    faces=[tuple(reversed(range(count)))]
    for j in range(len(rings)-1):
        for i in range(count): faces.append((j*count+i,j*count+(i+1)%count,(j+1)*count+(i+1)%count,(j+1)*count+i))
    mesh=bpy.data.meshes.new('Gathered leather panels');mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new('Stitched leather body',mesh);bpy.context.collection.objects.link(o);o.parent=root;o.data.materials.append(leather)
    C.ring('Drawstring',(0,0,.395),.087,.012,dark,root,rotation=(0,0,0))
    for x in [-.055,.025]:
        C.tube('Loose drawstring',[(x,-.07,.395),(x-.035,-.18,.29),(x+.015,-.195,.14)],.008,dark,root)
    for i in range(8):
        z=.07+i*.032
        C.rod('Saddle stitch',(-.12,-.143,z),(-.102,-.153,z+.014),.0038,metal,root)
    C.box('Small bronze clasp',(.08,-.155,.27),(.054,.025,.072),metal,root,.007)
    root.rotation_euler.z=-.18
    return root

def crystal(big,ice,dark,glow):
    root=C.empty('Ground cold cut crystal')
    radius=.17 if not big else .216;height=.36 if not big else .45
    verts=[];N=6
    for z,r,offset in [(0,.08,0),(.09,radius,0),(height*.76,radius*.8,.08),(height,radius*.25,.08)]:
        for i in range(N):
            a=i*math.tau/N+offset;verts.append((r*math.cos(a),r*math.sin(a),z+.035))
    faces=[tuple(reversed(range(N)))]
    for j in range(3):
        for i in range(N):faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
    faces.append(tuple(range(18,24)))
    me=bpy.data.meshes.new('Hexagonal stepped facets');me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new('Cut weathered crystal',me);bpy.context.collection.objects.link(ob);ob.parent=root
    for m in [ice,dark]:me.materials.append(m)
    for p in me.polygons:p.material_index=1 if p.index%5==0 else 0
    C.rod('Cold light trapped fissure',(-.07,-radius*.84,.12),(.02,-radius*.81,height*.72),.006,glow,root)
    root.rotation_euler=(.18,-.22,.24)
    root.location.z=.018
    return root

def contact(root):
    # Actual AO receiver, transparent away from contact; no painted blob.
    m=bpy.data.materials.new('Baked contact AO');m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links
    out=n.new('ShaderNodeOutputMaterial');mix=n.new('ShaderNodeMixShader');tr=n.new('ShaderNodeBsdfTransparent');black=n.new('ShaderNodeEmission');black.inputs[0].default_value=(.008,.01,.014,1)
    ao=n.new('ShaderNodeAmbientOcclusion');ao.inputs['Distance'].default_value=.12;ao.samples=8
    inv=n.new('ShaderNodeMath');inv.operation='SUBTRACT';inv.inputs[0].default_value=1
    l.new(ao.outputs['AO'],inv.inputs[1])
    geo=n.new('ShaderNodeNewGeometry');length=n.new('ShaderNodeVectorMath');length.operation='LENGTH';l.new(geo.outputs['Position'],length.inputs[0])
    radial=n.new('ShaderNodeMapRange');radial.clamp=True;radial.inputs['From Min'].default_value=.06;radial.inputs['From Max'].default_value=.24;radial.inputs['To Min'].default_value=.24;radial.inputs['To Max'].default_value=0;l.new(length.outputs['Value'],radial.inputs['Value'])
    l.new(radial.outputs['Result'],mix.inputs[0]);l.new(tr.outputs[0],mix.inputs[1]);l.new(black.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
    bpy.ops.mesh.primitive_plane_add(size=.66,location=(0,0,.001));o=bpy.context.object;o.name='Contact AO receiver';o.data.materials.append(m)

def build(kind):
    s=rig.create_rig('CREA',48,target=(0,0,.105))
    s.camera.data.ortho_scale=48/64
    # Ground pivot around y=34, identical to current runtime frames.
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,.045,0))
    if hasattr(s,'eevee'):s.eevee.taa_render_samples=16
    bronze=mat('Worn bronze','B69B62',.72,.36);patina=mat('Oxidised recess','426758',.65,.65)
    leather=mat('Rain-dark leather','62432F',0,.74);dark=mat('Dark seams','291D18',0,.85)
    ice=mat('Cold cut crystal','648B9E',.25,.22);glow=mat('Cold fissure','7FC8D6',.1,.25,2.2)
    if kind=='gold_coin':root=coin(bronze,patina)
    elif kind=='gold_bag':root=bag(leather,dark,bronze)
    else:root=crystal(kind=='xp_gem_big',ice,patina,glow)
    rig.bake_ao_shadows(root);contact(root)
    bpy.ops.object.light_add(type='AREA',location=(.6,.8,1));rim=bpy.context.object;rim.name='Cold silhouette rim';rim.data.energy=35;rim.data.color=(.5,.68,.85);rim.data.size=.8;rim.rotation_euler=(-rim.location).to_track_quat('-Z','Y').to_euler()
    s['c10_px_per_unit']=64;s['c10_ground_pivot']=[24,34];s['style']='STYLE.md + STYLE_boss_da.md; CREA 30 degrees'
    dest=ROOT/f'art/blender/props/c10_{kind}.blend';dest.parent.mkdir(parents=True,exist_ok=True)
    s.render.fps=12;s.frame_end=8 if kind in ('gold_coin','xp_gem') else 1
    for f in range(s.frame_end):
        if kind=='gold_coin':root.rotation_euler.z=-.3+f*math.tau/8;root.keyframe_insert('rotation_euler',frame=f+1)
        if kind=='xp_gem':glow.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value=1.7+.5*math.cos(f*math.tau/8);glow.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].keyframe_insert('default_value',frame=f+1)
    s.frame_set(1);s.render.filepath='';s.render.image_settings.color_mode='RGBA';bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(dest))
    return root

def main():
    inv=json.loads(INV.read_text()); frames={}
    with tempfile.TemporaryDirectory(prefix='rainfall_c10_') as temp:
        for kind in ['gold_coin','gold_bag','xp_gem','xp_gem_big']:
            build(kind);frames[kind]=[]
            count=8 if kind in ('gold_coin','xp_gem') else 1
            for f in range(count):
                bpy.context.scene.frame_set(f+1);p=Path(temp)/f'{kind}_{f}.png';rig.render_frame(p)
                passes={}
                for suffix in ['','_n','_e']:
                    q=p.with_name(p.stem+suffix+'.png')
                    if q.exists():passes[suffix]=Image.open(q).convert('RGBA').copy()
                frames[kind].append(passes)
        for entry in inv['files']:
            p=ROOT/entry['path']
            if p.suffix!='.png':continue
            kind=p.parent.name if p.parent!=OUT else {'coin':'gold_coin','gold_bag':'gold_bag','xp_gem':'xp_gem','xp_gem_big':'xp_gem_big'}[p.stem.removesuffix('_n')]
            suffix='_n' if p.stem.endswith('_n') else '_e' if p.stem.endswith('_e') else ''
            atlas=Image.new('RGBA',tuple(entry['size']))
            for f in range(entry['size'][0]//48):atlas.paste(frames[kind][f][suffix],(48*f,0))
            atlas.save(p,optimize=True,compress_level=9)
    check(inv)
    sheet(frames)

def check(inv):
    errors=[]
    actual={str(p.relative_to(ROOT)).replace('\\','/') for p in OUT.rglob('*') if p.is_file()}
    if actual!={e['path'] for e in inv['files']}:errors.append('file set')
    for e in inv['files']:
        p=ROOT/e['path']
        if 'size' in e:
            im=Image.open(p).convert('RGBA')
            if list(im.size)!=e['size'] or not im.getchannel('A').getbbox():errors.append(e['path'])
        elif hashlib.sha256(p.read_bytes()).hexdigest()!=e['sha256']:errors.append(e['path'])
    inv['verification']={'result':'FAIL' if errors else 'PASS','errors':errors,'scale_px_per_unit':64,'camera_elevation':30,'ground_pivot':[24,34],'frames':{'gold_coin':8,'gold_bag':1,'xp_gem':8,'xp_gem_big':1},'emission':'Existing xp_gem_big/default_e.png only; no new files.'}
    INV.write_text(json.dumps(inv,indent=2))
    print('C10 verification '+inv['verification']['result'],flush=True)
    if errors:raise RuntimeError(errors)

def sheet(frames):
    # Pillow is used only to assemble existing rendered assets.
    tile=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    canvas=Image.new('RGBA',(1700,1100),(21,26,32,255))
    for y in range(3):
        for x in range(3):
            px=850+(x-y)*tile.width//2;py=400+(x+y-2)*tile.height//2
            canvas.alpha_composite(tile,(px-tile.width//2,py-tile.height//2))
    ard=Image.open(ROOT/'game/assets/sprites/characters/ardent/idle.png').convert('RGBA');sz=ard.height//8;ard=ard.crop((0,sz*2,sz,sz*3));canvas.alpha_composite(ard,(850-sz//2,440-int(sz*.7)))
    for name,x,y in [('gold_coin',780,425),('gold_bag',912,443),('xp_gem',817,484),('xp_gem_big',881,509)]:canvas.alpha_composite(frames[name][0][''],(x-24,y-34))
    for k,name in enumerate(frames):
        im=frames[name][0][''];canvas.alpha_composite(im.resize((144,144),Image.Resampling.NEAREST),(440+k*210,900))
    canvas.convert('RGB').save(Path(__file__).with_name('_c10_contact.png'),optimize=True)

if __name__=='__main__':main()
