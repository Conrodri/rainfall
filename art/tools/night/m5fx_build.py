"""M5FX: top-down, 64 px/u. Blender background only; no normal outputs.
Bodies use shared vfx cel; feathering is geometry alpha, never painted.
Run with Blender, then system Python with --assemble (Pillow assembly only).
"""
import sys, math, random, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT/'art/blender/fx/m5fx_frames'
OUT = ROOT/'game/assets/sprites/fx/minis'
TAU = math.tau
NAMES = ['zone_poison','zone_mud','zone_oil','zone_salt','zone_ember','zone_ice']

def assemble():
    from PIL import Image
    import numpy as np, re
    sys.path.insert(0,str(ROOT/'art/tools/cel'))
    import cel_style as cel
    OUT.mkdir(parents=True,exist_ok=True)
    specs = [(n,256,256,8) for n in NAMES]+[('beam_judgment',1024,96,1),('egg_brood',64,64,4)]
    report=[]
    for name,w,h,count in specs:
        for suffix in ('','_e'):
            sheet=Image.new('RGBA',(w*count,h))
            for i in range(count):
                p=WORK/f'{name}_{i:02d}{suffix}.png'
                with Image.open(p) as im:
                    im=im.convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
                    sheet.paste(im,(i*w,0))
            a=np.asarray(sheet)
            if suffix:
                if float((a[:,:,:3].max(2)* (a[:,:,3]/255)).max())<=2:
                    continue
                # Peak filter shared with the project's half-resolution emission tool.
                sys.path.insert(0,str(ROOT/'art/tools'))
                import halve_emission
                halve_emission.downscale(sheet,peak=True).save(OUT/f'{name}{suffix}.png',compress_level=9)
            else:
                sheet.save(OUT/f'{name}.png',compress_level=9)
        report.append(cel.check_sheet(f'fx/minis/{name}.png',cell=(w,h),frames=count,rows=1,normals=False))
    # Contact uses actual dark biome ground; only crop, resize and composite.
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    contact=Image.new('RGBA',(1024,768),(24,29,34,255))
    for y in range(-128,768,128):
        for x in range(-128,1024,256):
            contact.alpha_composite(ground.resize((256,128)),(x,y))
    for i,n in enumerate(NAMES):
        with Image.open(OUT/f'{n}.png') as im: contact.alpha_composite(im.crop((768,0,1024,256)),((i%3)*320+32,(i//3)*272))
    with Image.open(OUT/'beam_judgment.png') as im: contact.alpha_composite(im,(0,562))
    with Image.open(OUT/'egg_brood.png') as im: contact.alpha_composite(im.resize((512,128)),(256,638))
    contact.convert('RGB').save(ROOT/'art/tools/night/_m5fx_contact.png')
    (WORK/'verification.json').write_text(json.dumps(report,indent=2))
    # Apply the existing import policy to this lot only.
    sys.path.insert(0,str(ROOT/'art/tools'))
    import texture_budget as budget
    policy=budget.load_budget()
    owned={name+suffix+'.png.import' for name,_,_,_ in specs for suffix in ('','_e')}
    for path in (OUT/name for name in sorted(owned) if (OUT/name).exists()):
        rel=path.relative_to(ROOT/'game').as_posix()[:-7]
        txt=path.read_text(encoding='utf-8')
        for key,value in budget.expected_params(rel,policy).items():
            line=f'{key}={budget._fmt(value)}'
            pattern=r'^'+re.escape(key)+r'=.*$'
            txt=re.sub(pattern,line,txt,flags=re.M) if re.search(pattern,txt,re.M) else txt.rstrip()+'\n'+line+'\n'
        path.write_text(txt,encoding='utf-8')
    print('PASS M5FX: 8 sheets, cel checks, no normal maps')

if '--assemble' in sys.argv:
    assemble(); raise SystemExit

import bpy
from mathutils import Vector
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel
WORK.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene
cel.install('vfx',normals=False)
cel.setup_scene(samples=8)
s.world=bpy.data.worlds.new('Night'); s.world.use_nodes=True
s.world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.13,.18,1)
s.world.node_tree.nodes['Background'].inputs[1].default_value=.35
bpy.ops.object.camera_add(location=(0,0,12))
cam=bpy.context.object; cam.name='TopDown_64px_per_unit'; cam.data.type='ORTHO'; s.camera=cam
for name,loc,color,power,size in [('Cold upper left',(-3,4,7),(.65,.81,1),450,5),('Warm key',(-3,1,6),(1,.84,.66),240,4)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    o=bpy.context.object; o.name=name; o.data.color=color; o.data.energy=power; o.data.shape='DISK'; o.data.size=size
    o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()

def mat(name,color,glow=False):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    if glow:
        p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=1.5
        m['rainfall_emissive']=True
    return m

def mesh(name,vs,fs,material,alphas=None):
    d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update()
    o=bpy.data.objects.new(name,d);s.collection.objects.link(o);d.materials.append(material);o['fx']=True
    if alphas is not None:
        c=d.color_attributes.new(name='Feather',type='FLOAT_COLOR',domain='POINT')
        for i,a in enumerate(alphas):c.data[i].color=(1,1,1,a)
    return o

def feather_material(m):
    """Wrap shared cel result in transparent mix driven by mesh alpha."""
    n=m.node_tree.nodes;l=m.node_tree.links
    out=next(x for x in n if x.type=='OUTPUT_MATERIAL')
    source=out.inputs['Surface'].links[0].from_socket
    a=n.new('ShaderNodeVertexColor');a.layer_name='Feather'
    t=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader')
    l.new(a.outputs['Alpha'],mix.inputs[0]);l.new(t.outputs[0],mix.inputs[1]);l.new(source,mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
    # The same opacity attenuates the accent AOV at the geometry feather.
    accent=next(x for x in n if x.type=='OUTPUT_AOV')
    if max(accent.inputs['Color'].default_value[:3])>0:
        v=n.new('ShaderNodeVectorMath');v.operation='SCALE';v.inputs[0].default_value=accent.inputs['Color'].default_value[:3]
        l.new(a.outputs['Alpha'],v.inputs['Scale']);l.new(v.outputs[0],accent.inputs['Color'])

def pool(m,t,seed):
    rng=random.Random(seed);count=96
    phase=[rng.random()*TAU for _ in range(4)]
    vs=[(0,0,.015)];aa=[1.0]
    rings=[(.68,1),(.92,.96),(1,.0)]
    for radius,alpha in rings:
        for j in range(count):
            a=j*TAU/count
            r=1.77*radius*(1+.032*math.sin(7*a+phase[0])+.023*math.sin(11*a+phase[1])+.015*math.sin(5*a+t))
            vs.append((r*math.cos(a),r*math.sin(a),.018+.005*math.cos(3*a+t)));aa.append(alpha)
    fs=[(0,1+j,1+(j+1)%count) for j in range(count)]
    for k in range(2):
        b=1+k*count;c=b+count
        fs += [(b+j,b+(j+1)%count,c+(j+1)%count,c+j) for j in range(count)]
    return mesh('Irregular soft shoreline',vs,fs,m,aa)

def ribbon(name,points,width,m,soft=False):
    vs=[];aa=[]
    for i,p in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        tangent.z=0;tangent.normalize();side=Vector((-tangent.y,tangent.x,0))
        taper=max(0,math.sin(math.pi*i/(len(points)-1)))**.4
        for sign in (-1,1):vs.append(Vector(p)+side*(sign*width*(.12+.88*taper)));aa.append(taper)
    return mesh(name,vs,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(points)-1)],m,aa if soft else None)

def shard(loc,scale,m,rotation=0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=loc)
    o=bpy.context.object;o.name='Fractured plate';o.scale=scale;o.rotation_euler=(.1,.17,rotation);o.data.materials.append(m);o['fx']=True
    return o

def crust(x,y,r,a,m,seed,elongation=1):
    rng=random.Random(seed);count=7
    vs=[(x,y,.075)]
    for j in range(count):
        ang=j*TAU/count+a;rr=r*rng.uniform(.78,1.15)
        vs.append((x+rr*math.cos(ang)*elongation,y+rr*math.sin(ang),.045+rng.uniform(0,.018)))
    mesh('Interlocking fractured crust',vs,[(0,j+1,(j+1)%count+1) for j in range(count)],m)

def clear():
    for o in list(s.objects):
        if o.get('fx'):bpy.data.objects.remove(o,do_unlink=True)
    for m in list(bpy.data.materials):
        if m.users==0:bpy.data.materials.remove(m)

def passes(path):
    # Minimal compositor: never creates a normal converter or normal file node.
    tree=bpy.data.node_groups.new('M5FX accent only','CompositorNodeTree');s.compositing_node_group=tree
    tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
    n=tree.nodes;l=tree.links;r=n.new('CompositorNodeRLayers');o=n.new('NodeGroupOutput');l.new(r.outputs['Image'],o.inputs['Image'])
    f=n.new('CompositorNodeOutputFile');f.directory=str(path.parent);f.file_name=path.stem+'_e__'
    f.file_output_items.new('RGBA','Image');f.format.media_type='IMAGE';f.format.file_format='PNG';f.format.color_mode='RGBA';f.format.color_depth='8'
    a=n.new('CompositorNodeSetAlpha');l.new(r.outputs[cel.AOV],a.inputs['Image']);l.new(r.outputs['Alpha'],a.inputs['Alpha']);l.new(a.outputs[0],f.inputs[0])

def render(name,i,w,h):
    cel.toon_materials('vfx')
    for m in bpy.data.materials:
        if m.get('soft') and not m.get('wrapped'):feather_material(m);m['wrapped']=True
    s.render.resolution_x=w*2;s.render.resolution_y=h*2;s.render.resolution_percentage=100
    cam.data.ortho_scale=w/64
    p=WORK/f'{name}_{i:02d}.png';cel.cel_passes(p,'vfx',base_configure=passes,normals=False)
    s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
    files=list(WORK.glob(p.stem+'_e__*.png'));assert len(files)==1
    files[0].replace(WORK/f'{name}_{i:02d}_e.png')
    if (name.startswith('zone_') and i==3) or name=='beam_judgment':
        collection=bpy.data.collections.new(name+' source');s.collection.children.link(collection)
        collection.hide_render=True;collection.hide_viewport=True
        for original in list(s.objects):
            if original.get('fx'):
                copy=original.copy();copy['fx']=False;collection.objects.link(copy)
    print(f'M5FX {name} {i+1}',flush=True)

palettes=[((.13,.20,.095),(.29,.39,.19),(.32,.57,.10)),((.20,.145,.095),(.30,.245,.18),None),((.075,.09,.11),(.18,.20,.22),(.85,.24,.055)),((.32,.40,.42),(.52,.61,.60),(.15,.55,.61)),((.145,.13,.125),(.26,.245,.22),(1,.22,.035)),((.23,.34,.38),(.43,.56,.58),(.18,.57,.65))]
for k,name in enumerate(NAMES):
    for f in range(8):
        clear();t=f*TAU/8;rng=random.Random(210+k)
        body,light,accent=palettes[k]
        base=mat(name+' body',body);base['soft']=True
        plate=mat('Lifted material facets',light);rim=mat('Cold upper-left rim',(.27,.36,.41))
        glow=mat('Single accent',accent,True) if accent else None
        pool(base,t,k)
        # Broken islands, polygonal crusts and branching drainage fissures.
        for j in range(58 if k in (3,5) else 26):
            a=rng.random()*TAU;r=math.sqrt(rng.random())*1.52
            x,y=r*math.cos(a),r*math.sin(a)
            width=rng.uniform(.12,.30);length=rng.uniform(.10,.27)
            z=.04+.015*math.sin(t+j)
            if k==3:crust(x,y,width*1.25,a,plate if j%4 else rim,j)
            elif k==5:
                # Dendritic frost: three narrow branching crystal blades.
                for b in range(3):
                    ang=a+b*.58
                    shard((x+.07*b,y-.045*b,z),(.025,width*(1.2-b*.2),.022),plate if b else rim,ang)
            elif k==1:crust(x,y,width,a,plate,j,1.5)
            elif k==4:crust(x,y,width*1.6,a,plate if j%3 else rim,j)
            else:
                # Nested crescent menisci rather than decorative wave symbols.
                points=[(x+width*math.cos(a+v*.14),y+length*math.sin(a+v*.14),z) for v in range(14)]
                ribbon('Oil meniscus' if k==2 else 'Poison surface tension',points,.008,plate)
                if j%3==0:crust(x,y,width,a,plate,j,1.7)
        for j in range(8):
            a=1.8+j*.135
            pts=[((1.66+.02*math.sin(t+v))*math.cos(a+v*.012),(1.66+.02*math.sin(t+v))*math.sin(a+v*.012),.055) for v in range(8)]
            ribbon('Cold shoreline highlight',pts,.010,rim)
        if glow:
            for j in range(7 if k!=4 else 13):
                a=rng.random()*TAU;r=rng.uniform(.18,1.40);x,y=r*math.cos(a),r*math.sin(a)
                pts=[(x+v*.043,y+.024*math.sin(v*1.6+j)+.008*math.sin(t+j),.12) for v in range(7)]
                o=ribbon('Living fissure',pts,.009*(1+.23*math.sin(t+j)),glow)
                if k==0:shard((x,y,.09),(.055,.045,.023*(1+.3*math.sin(t+j))),plate)
        render(name,f,256,256)

clear()
gold=mat('Judgment white gold',(1,.73,.34),True);gold['soft']=True
core=mat('Judgment incandescent core',(1,.89,.66),True);core['soft']=True
# An asymmetric sword of light: 16u long, fractured peripheral lances.
for j in range(9):
    pts=[(-7.85+v*.25,(j-4)*.055+math.sin(v*.5+j)*.013,.02+j*.004) for v in range(64)]
    ribbon('Judgment lance',pts,.012 if j!=4 else .065,core if j==4 else gold,True)
render('beam_judgment',0,1024,96)

for f in range(4):
    clear();shell=mat('Brood calcified shell',(.35,.37,.30));inner=mat('Brood dark membrane',(.12,.16,.12));glow=mat('Brood sickly inner light',(.36,.57,.13),True)
    rng=random.Random(55)
    shard((0,0,.08),(.245,.31,.12),inner)
    for j in range(11):
        a=j*TAU/11;r=.13+.045*f
        o=shard((r*math.cos(a),r*math.sin(a),.13),(.13,.16,.105),shell,a)
        o.rotation_euler.x=f*.20*math.cos(a);o.rotation_euler.y=f*.20*math.sin(a)
    for j in range(5):
        a=j*TAU/5;pts=[((.015+v*.026)*math.cos(a),(.015+v*.026)*math.sin(a),.255) for v in range(7)]
        ribbon('Hatching split',pts,.006+.003*f,glow)
    if f>=2:
        for j in range(3):
            a=j*TAU/3
            ribbon('Brood hooked feeler',[(.05*math.cos(a),.05*math.sin(a),.27),(.18*math.cos(a),.18*math.sin(a),.29),(.29*math.cos(a+.25),.29*math.sin(a+.25),.26),(.30*math.cos(a+.65),.30*math.sin(a+.65),.21)],.018,inner)
    render('egg_brood',f,64,64)
s['M5FX']='64 px/u; top-down; vfx cel, normals=False; 6x8 + 1 + 4 frames; script rebuilds all scenes'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fx/m5fx.blend'))
print('PASS M5FX render complete',flush=True)
