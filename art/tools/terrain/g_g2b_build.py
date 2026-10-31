"""G2b sandstone ravine terrain; shared F2 MAP/TOP contract. Blender background only.
Reuses C1 geometry/periodicity and ash_lord worn PBR; Pillow assembles/checks only.
Run with -- --only name to resume, or regular Python --verify after rendering.
"""
from pathlib import Path
import sys, math, random, json
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/iso/_deps'))
sys.path.insert(0,str(ROOT/'art/tools/cel'))
OUT=ROOT/'game/assets/sprites/terrain/fog_forest/iso'
SRC=ROOT/'art/blender/terrain'
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'art/tools/terrain'))
sys.path.insert(0,str(ROOT/'art/tools/iso'))
sys.path.insert(0,str(ROOT/'art/tools/monsters'))
SPECS={**{v:((256,128),(128,64)) for v in ('water_shallow','water_deep')},
       **{v:((256,384),(128,64)) for v in ('cliff_sw','cliff_se','cliff_corner_s','cliff_corner_w','cliff_corner_e')},
       'void_1024':((1024,1024),(512,512))}

def verify():
    from PIL import Image
    errors=[]
    geometry=SRC/'g_g2b_geometry.json'
    if not geometry.exists() or json.loads(geometry.read_text())['status']!='PASS':errors.append('geometry audit')
    for name,(size,pivot) in SPECS.items():
        for suffix in ('', '_n'):
            if suffix=='_n': continue
            p=OUT/(name+suffix+'.png')
            if not p.exists(): errors.append('missing '+p.name);continue
            with Image.open(p) as im:
                if im.size!=size or not im.getchannel('A').getbbox():errors.append('invalid '+p.name)
                if name.startswith('water') and im.getpixel((4,4))[3]:errors.append('diamond '+p.name)
    pivots=[]
    for p in SRC.glob('g_g2b_*_check.json'):
        c=json.loads(p.read_text());pivots.append(c)
        if max(abs(a-b) for a,b in zip(c['pivot'],SPECS[c['name']][1]))>.01:errors.append('pivot '+c['name'])
    if len(pivots)!=len(SPECS):errors.append('pivot count')
    expected={n+'.png' for n in SPECS}
    if (OUT/'water_shallow_e.png').exists():expected.add('water_shallow_e.png')
    actual={p.name for p in OUT.glob('*.png')}
    if actual!=expected:errors.append('inventory '+str(actual^expected))
    canvas=Image.new('RGBA',(960,600),(19,25,28,255))
    def paste(name,x,y):
        im=Image.open(OUT/(name+'.png')).convert('RGBA');pivot=SPECS[name][1]
        canvas.alpha_composite(im,(x-pivot[0],y+100-pivot[1]))
    for i,n in enumerate(SPECS):
        im=Image.open(OUT/(n+'.png')).convert('RGBA');im.thumbnail((256,384));canvas.alpha_composite(im,(i%3*320,i//3*400))
    canvas.convert('RGB').save(ROOT/'art/renders/grotte/g2b_avant_apres.png',optimize=True)
    result={'status':'FAIL' if errors else 'PASS','errors':errors,'diffuse':len(SPECS),'pivots':pivots}
    (SRC/'g_g2b_validation.json').write_text(json.dumps(result,indent=2))
    print('G2b '+result['status']+': '+str(errors) if errors else 'G2b PASS: sizes, pivots, transparent alpha')
    return not errors

if '--verify' in sys.argv:
    sys.exit(0 if verify() else 1)

import bpy
from mathutils import Vector
import iso_rig as rig
from ash_lord_build import worn, mesh, rod
from terraces_iso_build import box, periodic

def pebble(name,loc,scale,mat,root,seed=0):
    rng=random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc)
    o=bpy.context.object;o.name=name;o.parent=root;o.scale=scale
    for v in o.data.vertices:v.co*=rng.uniform(.88,1.09)
    o.data.materials.append(mat)
    return o

def materials():
    m={k:worn(k,a,b,metal,rough) for k,a,b,metal,rough in [
        ('moss','2A4A42','8A7A62',0,.84),('peat','2E221C','5A4232',0,.73),
        ('bark','3A3634','5A4232',0,.76),('wood','4A3A30','7A5D45',0,.71),
        ('rock','4A3225','7A5D45',0,.85),('water','0D1D1A','14302C',0,.96),
        ('needles','272C24','53533C',0,.85),('iron','202927','536253',.65,.52) ]}
    # Longitudinal fissures are shader relief, with modeled buttresses and torn edges.
    for key in ('bark','wood'):
        n=m[key].node_tree.nodes;l=m[key].node_tree.links
        tc=n.new('ShaderNodeTexCoord');v=n.new('ShaderNodeVectorMath');v.operation='MULTIPLY';v.inputs[1].default_value=(4,4,.32)
        l.new(tc.outputs['Generated'],v.inputs[0])
        for q in n:
            if q.bl_idname=='ShaderNodeTexNoise':l.new(v.outputs[0],q.inputs['Vector'])
    g=bpy.data.materials.new('Grotte amethyst C27BFF');g.use_nodes=True
    p=g.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.54,.16,.92,1)
    p.inputs['Emission Color'].default_value=(.54,.16,.92,1);p.inputs['Emission Strength'].default_value=1.2
    m['glow']=g
    return m

def root_curve(points,r,mat,parent,name='Cedar root'):
    # Curved, tapering roots: no angular tube elbows at sprite scale.
    source=[Vector(p) for p in points];smooth=[]
    for i in range(len(source)-1):
        a=source[max(0,i-1)];b=source[i];c=source[i+1];d=source[min(len(source)-1,i+2)]
        for j in range(4):
            t=j/4
            smooth.append(tuple(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)))
    smooth.append(tuple(source[-1]));ob=rod(name,smooth,r,mat,parent)
    for p in ob.data.polygons:p.use_smooth=True
    return ob

def trunk(x,y,z,r,h,root,m,seed=1):
    rng=random.Random(seed);N=32;verts=[];levels=[0,.15,.56,.91,1]
    variation=[rng.uniform(.88,1.09) for _ in range(N)]
    for k,f in enumerate(levels):
        for j in range(N):
            a=math.tau*j/N;radius=r*variation[j]*(1.25 if k==0 else 1-.22*f)*(1+(.05 if j%3==0 else -.025))
            verts.append((x+math.cos(a)*radius+.035*f,y+math.sin(a)*radius,z+h*f+(rng.uniform(-.025,.025) if k==4 else 0)))
    faces=[tuple(range(N-1,-1,-1))]+[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(4) for j in range(N)]
    mesh('Fluted torn cedar bark',verts,faces,m['bark'],root)
    cap=verts[-N:];mesh('Weathered endgrain',cap,[tuple(range(N))],m['wood'],root)
    for rr in (.22,.39,.57,.7):
        pts=[(x+.035+math.cos(a)*r*rr,y+math.sin(a)*r*rr,z+h+.003) for a in [math.tau*j/40 for j in range(41)]]
        root_curve(pts,.006,m['bark'],root,'Irregular endgrain rings')
    for i in range(6):
        a=i*math.tau/6+.2;rr=r*.9
        root_curve([(x+math.cos(a)*rr,y+math.sin(a)*rr,z+h*.65),
                    (x+math.cos(a)*r*1.3,y+math.sin(a)*r*1.3,z+h*.16),
                    (x+math.cos(a)*r*1.8,y+math.sin(a)*r*1.8,z+.025)],r*.16,m['bark'],root)

def litter(root,m,extent,seed,count=180):
    rng=random.Random(seed);verts=[];faces=[]
    for i in range(count):
        x=rng.uniform(-extent+.12,extent-.12);y=rng.uniform(-extent+.12,extent-.12);a=rng.uniform(0,math.tau);length=rng.uniform(.025,.105);w=.003
        dx=math.cos(a)*length;dy=math.sin(a)*length;k=len(verts)
        verts.extend([(x-dx,y-dy,.009),(x+dy*w/length,y-dx*w/length,.013),(x+dx,y+dy,.009)])
        faces.append((k,k+1,k+2))
    mesh('Fallen cedar needles',verts,faces,m['needles'],root)

def ground(name,root,m):
    n=m['moss'].node_tree.nodes;l=m['moss'].node_tree.links
    # Peat/moss islands share a single periodic substrate across every variation.
    broad=n.new('ShaderNodeTexNoise');broad.inputs['Scale'].default_value=2.4;broad.inputs['Detail'].default_value=3.5
    cr=n.new('ShaderNodeValToRGB');cr.color_ramp.elements[0].position=.3;cr.color_ramp.elements[0].color=(.012,.015,.011,1)
    cr.color_ramp.elements[1].position=.72;cr.color_ramp.elements[1].color=(.071,.095,.059,1)
    l.new(broad.outputs['Fac'],cr.inputs[0]);l.new(cr.outputs[0],n.get('Principled BSDF').inputs['Base Color'])
    periodic(m['moss'],4);periodic(m['peat'],4)
    # Common boundary shader, all variants share the 4m phase and stay flat at edges.
    mesh('Continuous four metre moss carpet',[(-2,-2,0),(2,-2,0),(2,2,0),(-2,2,0)],[(0,1,2,3)],m['moss'],root)
    rng=random.Random(30+ord(name[-1]));litter(root,m,2,ord(name[-1]),240)
    for i in range(42):
        x=rng.uniform(-1.68,1.68);y=rng.uniform(-1.68,1.68)
        pebble('Sodden hummock',(x,y,.003),(rng.uniform(.02,.07),rng.uniform(.025,.09),.012),m['moss'],root,i)
    for i in range(7):
        x=rng.uniform(-1.4,1.1);y=rng.uniform(-1.4,1.4)
        root_curve([(x-.3,y,.015),(x-.12,y+.065,.035),(x+.14,y+.03,.025),(x+.43,y-.02,.012)],.015,m['bark'],root,'Flat exposed root')
    for i in range(4):
        x=rng.uniform(-1.3,1.3);y=rng.uniform(-1.3,1.3)
        pebble('Black rain pocket',(x,y,.006),(.14,.1,.004),m['water'],root,i)

def water(name,root,m):
    periodic(m['water'],2);mesh('Black pond',[(-1,-1,0),(1,-1,0),(1,1,0),(-1,1,0)],[(0,1,2,3)],m['water'],root)
    rng=random.Random(71 if 'shallow' in name else 72)
    for i in range(22 if 'shallow' in name else 9):
        x=rng.uniform(-.83,.83);y=rng.uniform(-.83,.83)
        pebble('Submerged calcite' if 'shallow' in name else 'Dark submerged pebble',
               (x,y,.003),(.035,.025,.004),m['moss'] if 'shallow' in name else m['rock'],root,i)


def lantern(root,m,pos):
    x,y,z=pos
    box('Shrine iron crown',(x,y,z+.115),(.17,.15,.035),m['iron'],root,.008)
    box('Shrine iron foot',(x,y,z-.115),(.16,.14,.035),m['iron'],root,.008)
    box('Pale green slit',(x,y,z),(.085,.085,.18),m['glow'],root,.005)
    for dx in (-.061,.061):
        for dy in (-.057,.057):root_curve([(x+dx,y+dy,z-.1),(x+dx,y+dy,z+.1)],.011,m['iron'],root,'Lantern iron cage')

def blocks(name,root,m):
    box('Jointive dark root bank',(0,0,.08),(2,2,.16),m['peat'],root,0)
    if name=='block_a':
        trunk(-.12,.06,.15,.49,1.07,root,m,42)
        for j in range(7):
            a=j*math.tau/7+.13*math.sin(j*4)
            root_curve([(-.12+math.cos(a)*.37,.06+math.sin(a)*.37,.55),(.64*math.cos(a+.12),.64*math.sin(a+.12),.25),(.94*math.cos(a),.94*math.sin(a),.15)],.07,m['bark'],root)
    elif name=='block_b':
        for j in range(4):
            y=-.5+j*.32
            pts=[(-.94,y,.17),(-.77,y-.05,.55),(-.42,y,.99),(-.04,y+.04,1.13),(.44,y,1.02),(.76,y-.04,.6),(.94,y,.18)]
            root_curve(pts,.09 if j==0 else .065,m['bark'],root,'Ancient root vault')
            root_curve([(p[0]+.018,p[1]-.065,p[2]+.015) for p in pts],.013,m['moss'],root,'Moss in root fissure')
        lantern(root,m,(.05,-.57,.74))
        root_curve([(.05,-.54,1.13),(.05,-.55,.88)],.009,m['iron'],root,'Suspended shrine chain')
    else:
        o=pebble('Fractured moss boulder',(-.12,.08,.58),(.88,.82,.64),m['rock'],root,92)
        for p in o.data.polygons:p.use_smooth=True
        for j in range(11):
            a=j*2.4;rr=.44
            pebble('Moss seam',(-.12+math.cos(a)*rr,.08+math.sin(a)*rr,1.02+random.Random(j).uniform(-.12,.05)),(.2,.18,.04),m['moss'],root,j)
    rng=random.Random(81)
    for i in range(17):
        x=rng.uniform(-.87,.87);y=rng.uniform(-.87,.87)
        pebble('Root bank moss',(x,y,.16),(.12,.09,.025),m['moss'],root,i)

def rampart(name,root,m):
    edges=[1] if name.endswith('ne') else [0] if name.endswith('nw') else [0,1]
    for axis in edges:
        for i in range(7):
            a=-.86+i*.286;x,y=(a,.84) if axis==1 else (-.84,a)
            trunk(x,y,0,.13,1.2-(i%3)*.06,root,m,i+axis*30)
        for k in (0,1):
            pts=[(-.96+i*.32,.72,.22+k*.48+.065*math.sin(i)) if axis==1 else (-.72,-.96+i*.32,.22+k*.48+.065*math.sin(i)) for i in range(7)]
            root_curve(pts,.055,m['bark'],root,'Binding cedar root')
    if name.endswith('corner_n'):lantern(root,m,(-.65,.62,.85))

def cliff(name,root,m):
    box('Continuous sandstone shelf',(0,0,-.045),(2,2,.09),m['peat'],root,0)
    faces={'cliff_sw':[(1,-1)],'cliff_se':[(0,1)],'cliff_corner_s':[(1,-1),(0,1)],'cliff_corner_w':[(1,-1),(0,-1)],'cliff_corner_e':[(0,1),(1,1)]}[name]
    for axis,sign in faces:
        loc=(sign*.97,0,-1.25) if axis==0 else (0,sign*.97,-1.25)
        dims=(.06,2,2.5) if axis==0 else (2,.06,2.5)
        box('Oblique ferruginous sandstone face',loc,dims,m['wood'],root,0)
        # Exposed sloping beds, physically outside the wall rather than buried curves.
        rng=random.Random(800+axis*7+sign)
        for j in range(11):
            z=-.10-j*.225; slope=.13 if sign>0 else -.16
            verts=[]
            for k in range(13):
                q=-1+k/6; zz=max(-2.49,min(-.055,z+slope*q+rng.uniform(-.024,.024)))
                for dz in (0,-rng.uniform(.045,.085)):
                    d=sign*1.006
                    verts.append((d,q,max(-2.499,zz+dz)) if axis==0 else (q,d,max(-2.499,zz+dz)))
            ob=mesh('Oblique sandstone bed',verts,[(k*2,k*2+1,k*2+3,k*2+2) for k in range(12)],m['rock'],root)
        for j in range(30):
            a=rng.uniform(-.95,.95);z=rng.uniform(-2.4,-.12)
            loc=(sign*1.015,a,z) if axis==0 else (a,sign*1.015,z)
            scale=(.025,.065,.025) if axis==0 else (.065,.025,.025)
            ob=pebble('Small sandstone chip',loc,scale,m['wood'],root,j)
        for j in range(18):
            a=-.97+j*1.94/17
            loc=(sign*.99,a,rng.uniform(-.025,.005)) if axis==0 else (a,sign*.99,rng.uniform(-.025,.005))
            pebble('Chipped shelf edge',loc,(rng.uniform(.035,.075),rng.uniform(.035,.075),rng.uniform(.025,.04)),m['rock'],root,j)

def linear_hex(h):
    values=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in values)+(1,)

def retouch_palette(name):
    # Exact sRGB targets, converted once to scene-linear emission. No shadow-floor lift.
    palettes={'wood':('302218','59402D','806047'), 'rock':('36271D','6A4C35','937050'),
              'peat':('271C15','423023','624B37')}
    if name.startswith('water'):
        shallow='shallow' in name
        palettes={'water':('213D36','2A4A42','34564A') if shallow else ('0C1F1C','14302C','1E4038'),
                  'moss':('3C4B3E','4D5847','59604E') if shallow else ('132B26','1A352E','203D34'),
                  'rock':('132922','1B332B','243E32')}
    for mat in bpy.data.materials:
        ramp=mat.node_tree.nodes.get('CEL tones') if mat.use_nodes else None
        if ramp is None:continue
        colors=palettes.get(mat.name.split('.')[0])
        if colors:
            for el,h in zip(ramp.color_ramp.elements,colors):el.color=linear_hex(h)
        if mat.name.split('.')[0]=='water' or mat.name.startswith('Ochre chasm fog'):
            fog=name.startswith('void')
            if fog:
                ramp.color_ramp.interpolation='EASE'
                ramp.color_ramp.elements[0].position=.53
                ramp.color_ramp.elements[-1].position=.76
                ramp.color_ramp.elements[0].color=linear_hex('120E0C')
                # Only 20% ochre over the dark base, in soft local patches.
                dark=linear_hex('120E0C');ochre=linear_hex('3A2C24')
                ramp.color_ramp.elements[-1].color=tuple(.8*a+.2*b for a,b in zip(dark,ochre))
            else:
                for el,pos in zip(ramp.color_ramp.elements,(.0,.40,.65)):el.position=pos
            nodes=mat.node_tree.nodes;links=mat.node_tree.links
            noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=2.2 if fog else 1.6
            noise.inputs['Detail'].default_value=2
            periodic(mat,8 if fog else 2)
            links.new(noise.outputs['Fac'],ramp.inputs['Fac'])


def build():
    OUT.mkdir(parents=True,exist_ok=True);SRC.mkdir(parents=True,exist_ok=True)
    import cel_style as cel
    only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else None
    bpy.context.preferences.filepaths.save_version=0
    # Overwrite owned diffuse files only; preserve all emission and unrelated assets.
    for name,(size,pivot) in SPECS.items():
        if only and name!=only:continue
        s=rig.create_rig('TOP' if name.startswith('void') else 'MAP',size)
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(pivot[1]-size[1]/2)/rig.R,0))
        s.eevee.taa_render_samples=16
        s.render.use_file_extension=True
        if name.startswith(('ground','water','void')):
            # Directional fill removes tile-local falloff, preserving periodic joins.
            fill=bpy.data.objects.get('Fill_froid');fill.data.type='SUN';fill.data.energy=.35
        bpy.ops.object.empty_add();root=bpy.context.object;root.name=name
        m=materials()
        if name.startswith('ground'):ground(name,root,m)
        elif name.startswith('water'):water(name,root,m)
        elif name.startswith('block'):blocks(name,root,m)
        elif name.startswith('rampart'):rampart(name,root,m)
        elif name.startswith('cliff'):cliff(name,root,m)
        else:
            fog=periodic(worn('Ochre chasm fog','120E0C','3A2C24',0,1),8)
            bs=fog.node_tree.nodes.get('Principled BSDF')
            for link in list(bs.inputs['Normal'].links):fog.node_tree.links.remove(link)
            bs.inputs['Specular IOR Level'].default_value=0
            for n in fog.node_tree.nodes:
                if n.bl_idname=='ShaderNodeTexNoise':
                    n.inputs['Scale'].default_value=4.0 if n.inputs['Scale'].default_value<50 else 8.0
                    n.inputs['Detail'].default_value=3
                    n.inputs['Roughness'].default_value=.72
            box('Seamless abyss mist',(0,0,-.01),(8,8,.02),fog,root,0)
        if name.startswith(('block','rampart')):
            for ob in root.children_recursive:
                if ob.type!='MESH':continue
                for v in ob.data.vertices:
                    w=ob.matrix_world@v.co
                    w.x=max(-1,min(1,w.x));w.y=max(-1,min(1,w.y));w.z=min(1.25,w.z)
                    v.co=ob.matrix_world.inverted()@w
        rig.bake_ao_shadows(root)
        from bpy_extras.object_utils import world_to_camera_view
        bpy.context.view_layer.update();q=world_to_camera_view(s,s.camera,Vector((0,0,0)))
        check={'name':name,'pivot':[q.x*size[0],(1-q.y)*size[1]],'R':rig.R,'size':size}
        (SRC/('g_g2b_'+name+'_check.json')).write_text(json.dumps(check))
        cel.uninstall()
        rig.optimize_png=lambda p,crop=False,margin=6: (0,0,*size)
        profile=cel.profile('tile')
        if name.startswith('void'):profile.update(tones=2,creases=False)
        cel.install(profile,normals=False)
        cel.setup_scene(samples=8)
        for layer in s.view_layers:layer.use_pass_normal=False
        for mat in bpy.data.materials:mat.pop('cel_done',None)
        cel.toon_materials(profile)
        retouch_palette(name)
        path=OUT/(name+'.png')
        rig.render_frame(path,passes=False)
        cel.uninstall()
        # Retain each complete source scene with its contractual MAP camera.
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('g_g2b_'+name+'.blend')))
        print('G2b PASS '+name,flush=True)
    print('G2b BUILD COMPLETE',flush=True)

def audit():
    failures=[]
    for name in SPECS:
        bpy.ops.wm.open_mainfile(filepath=str(SRC/('g_g2b_'+name+'.blend')))
        root=bpy.data.objects[name];bpy.context.view_layer.update()
        points=[ob.matrix_world@v.co for ob in root.children_recursive if ob.type=='MESH' for v in ob.data.vertices]
        limits=[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)]
        if name.startswith('cliff') and (abs(limits[2][0]+2.5)>.001 or limits[2][1]>.051):failures.append(name+' depth')
        path=SRC/('g_g2b_'+name+'_check.json');check=json.loads(path.read_text());check['bounds']=limits;path.write_text(json.dumps(check))
    (SRC/'g_g2b_geometry.json').write_text(json.dumps({'status':'FAIL' if failures else 'PASS','errors':failures}))
    print('G2b GEOMETRY '+('FAIL '+str(failures) if failures else 'PASS: footprint, 2.5u cliffs'),flush=True)

if __name__=='__main__':
    if '--audit' in sys.argv:audit()
    else:build()
