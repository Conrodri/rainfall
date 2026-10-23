"""F2 forest terrain; shared C1 MAP/TOP contract. Blender background only.
Reuses C1 geometry/periodicity and ash_lord worn PBR; Pillow assembles/checks only.
Run with -- --only name to resume, or regular Python --verify after rendering.
"""
from pathlib import Path
import sys, math, random, json
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/terrain/fog_forest/iso'
SRC=ROOT/'art/blender/terrain'
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'art/tools/iso/_deps'))
sys.path.insert(0,str(ROOT/'art/tools/terrain'))
sys.path.insert(0,str(ROOT/'art/tools/iso'))
sys.path.insert(0,str(ROOT/'art/tools/monsters'))
SPECS={**{'ground_'+v:((512,256),(256,128)) for v in 'abcd'},
       **{v:((256,128),(128,64)) for v in ('water_shallow','water_deep')},
       **{v:((256,256),(128,192)) for v in ('block_a','block_b','block_c','rampart_ne','rampart_nw','rampart_corner_n')},
       **{v:((256,384),(128,64)) for v in ('cliff_sw','cliff_se','cliff_corner_s','cliff_corner_w','cliff_corner_e')},
       'void_1024':((1024,1024),(512,512))}

def verify():
    from PIL import Image
    errors=[]
    geometry=SRC/'f2_geometry.json'
    if not geometry.exists() or json.loads(geometry.read_text())['status']!='PASS':errors.append('geometry audit')
    for name,(size,pivot) in SPECS.items():
        for suffix in ('','_n'):
            p=OUT/(name+suffix+'.png')
            if not p.exists(): errors.append('missing '+p.name);continue
            with Image.open(p) as im:
                if im.size!=size or not im.getchannel('A').getbbox():errors.append('invalid '+p.name)
                if name.startswith(('ground','water')) and im.getpixel((4,4))[3]:errors.append('diamond '+p.name)
        if name.startswith('block'):
            with Image.open(OUT/(name+'_shadow.png')) as im:
                if im.size!=(512,512) or not im.getchannel('A').getbbox(): errors.append('shadow '+name)
    for name in ('block_b','rampart_corner_n'):
        with Image.open(OUT/(name+'_e.png')) as im:
            if max(im.getextrema()[i][1] for i in range(3))<40:errors.append('emission '+name)
    pivots=[]
    for p in SRC.glob('f2_*_check.json'):
        c=json.loads(p.read_text());pivots.append(c)
        if max(abs(a-b) for a,b in zip(c['pivot'],SPECS[c['name']][1]))>.01:errors.append('pivot '+c['name'])
    if len(pivots)!=18:errors.append('pivot count')
    expected={n+s+'.png' for n in SPECS for s in ('','_n')}
    expected|={n+'_shadow.png' for n in ('block_a','block_b','block_c')}
    expected|={n+'_e.png' for n in ('block_b','rampart_corner_n')}
    actual={p.name for p in OUT.glob('*.png')}
    if actual!=expected:errors.append('inventory '+str(actual^expected))
    canvas=Image.new('RGBA',(1800,1780),(19,25,28,255))
    def paste(name,x,y):
        im=Image.open(OUT/(name+'.png')).convert('RGBA');pivot=SPECS[name][1]
        canvas.alpha_composite(im,(x-pivot[0],y+100-pivot[1]))
    for row in range(3):
        for col in range(3):paste('ground_'+'abcd'[(row*3+col)%4],900+(col-row)*256,125+(col+row)*128)
    for n,x,y in [('rampart_ne',1028,189),('rampart_corner_n',900,125),('rampart_nw',772,189),
                  ('block_a',772,445),('block_b',900,509),('block_c',1028,573),
                  ('cliff_corner_w',388,637),('cliff_sw',644,765),('cliff_corner_s',900,893),
                  ('cliff_se',1156,765),('cliff_corner_e',1412,637),
                  ('water_shallow',245,950),('water_deep',245,1100)]:paste(n,x,y)
    for i,n in enumerate(('block_a','block_b','block_c')):
        im=Image.open(OUT/(n+'_shadow.png')).convert('RGBA');im.thumbnail((130,130));canvas.alpha_composite(im,(40+i*155,1310))
    im=Image.open(OUT/'void_1024.png').convert('RGBA');im.thumbnail((256,256));canvas.alpha_composite(im,(1515,930))
    for i,p in enumerate((ROOT/'art/tools/iso/_c4_contact.png',ROOT/'art/tools/characters/_m2_contact.png',ROOT/'art/tools/iso/_c1_contact.png')):
        im=Image.open(p).convert('RGBA');im.thumbnail((510,280));canvas.alpha_composite(im,(30+i*590,1470))
    canvas.convert('RGB').save(HERE/'_f2_contact.png',optimize=True,compress_level=9)
    result={'status':'FAIL' if errors else 'PASS','errors':errors,'diffuse':18,'normal':18,'shadows':3,'emission':2,'pivots':pivots}
    (SRC/'f2_validation.json').write_text(json.dumps(result,indent=2))
    print('F2 '+result['status']+': '+str(errors) if errors else 'F2 PASS: 41 PNG; sizes, pivots, diamond alpha, normals, shadows, emission')
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
        ('moss','3E4A3F','55634E',0,.84),('peat','1B201C','414137',0,.73),
        ('bark','211C19','453D32',0,.76),('wood','493E30','776A4E',0,.71),
        ('rock','252F2E','4A5650',.08,.55),('water','070F13','17262B',.28,.3),
        ('needles','272C24','53533C',0,.85),('iron','202927','536253',.65,.52) ]}
    # Longitudinal fissures are shader relief, with modeled buttresses and torn edges.
    for key in ('bark','wood'):
        n=m[key].node_tree.nodes;l=m[key].node_tree.links
        tc=n.new('ShaderNodeTexCoord');v=n.new('ShaderNodeVectorMath');v.operation='MULTIPLY';v.inputs[1].default_value=(4,4,.32)
        l.new(tc.outputs['Generated'],v.inputs[0])
        for q in n:
            if q.bl_idname=='ShaderNodeTexNoise':l.new(v.outputs[0],q.inputs['Vector'])
    g=bpy.data.materials.new('Sanctuary pale green 9CF0C8');g.use_nodes=True
    p=g.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.332,.871,.578,1)
    p.inputs['Emission Color'].default_value=(.332,.871,.578,1);p.inputs['Emission Strength'].default_value=2.6
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
    for i in range(40 if 'shallow' in name else 13):
        x=rng.uniform(-.83,.83);y=rng.uniform(-.83,.83)
        pebble('Duckweed',(x,y,.004),(.018,.014,.004),m['moss'],root,i)
    for i in range(4):
        x=rng.uniform(-.5,.5);y=rng.uniform(-.5,.5)
        pts=[(x+math.cos(a)*.18,y+math.sin(a)*.18,.002) for a in [j*.14 for j in range(16)]]
        root_curve(pts,.002,m['rock'],root,'Cold broken ripple')

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
    box('Continuous bank lip',(0,0,-.045),(2,2,.09),m['moss'],root,0)
    faces={'cliff_sw':[(1,-1)],'cliff_se':[(0,1)],'cliff_corner_s':[(1,-1),(0,1)],'cliff_corner_w':[(1,-1),(0,-1)],'cliff_corner_e':[(0,1),(1,1)]}[name]
    for axis,sign in faces:
        loc=(sign*.97,0,-1.25) if axis==0 else (0,sign*.97,-1.25)
        dims=(.06,2,2.5) if axis==0 else (2,.06,2.5)
        box('Sheared peat face',loc,dims,m['peat'],root,0)
        for j in range(15):
            a=-.93+j*.132;rng=random.Random(j+axis*50);pts=[]
            depth=rng.uniform(.7,2.38)
            for k in range(6):
                q=a+math.sin(k*1.7+j)*.035;d=sign*(1.0-.025*k)
                pts.append((d,q,-depth*k/5) if axis==0 else (q,d,-depth*k/5))
            root_curve(pts,rng.uniform(.012,.038),m['bark'],root,'Torn hanging cedar root')
            if j%3==0:
                p=list(pts[2]);p[2]-=.26;root_curve([pts[1],tuple(p),pts[4]],.008,m['wood'],root,'Exposed root fibres')
        for j in range(13):
            rng=random.Random(j);a=rng.uniform(-.86,.86);z=rng.uniform(-2.35,-.14)
            loc=(sign*.99,a,z) if axis==0 else (a,sign*.99,z)
            scale=(.045,.13,.07) if axis==0 else (.13,.045,.07)
            pebble('Embedded riverstone',loc,scale,m['rock'],root,j)
    litter(root,m,1,91,65)

def build():
    OUT.mkdir(parents=True,exist_ok=True);SRC.mkdir(parents=True,exist_ok=True)
    only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else None
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
            fog=periodic(worn('Blue green bottomless mist','0B171C','304747',0,1),8)
            bs=fog.node_tree.nodes.get('Principled BSDF')
            for link in list(bs.inputs['Normal'].links):fog.node_tree.links.remove(link)
            bs.inputs['Specular IOR Level'].default_value=0
            for n in fog.node_tree.nodes:
                if n.bl_idname=='ShaderNodeTexNoise':
                    n.inputs['Scale'].default_value=1.4 if n.inputs['Scale'].default_value<50 else 5
                    n.inputs['Detail'].default_value=2
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
        (SRC/('f2_'+name+'_check.json')).write_text(json.dumps(check))
        path=OUT/(name+'.png');rig.render_frame(path)
        if name not in ('block_b','rampart_corner_n'):path.with_name(name+'_e.png').unlink(missing_ok=True)
        # Retain each complete source scene with its contractual MAP camera.
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('f2_'+name+'.blend')))
        if name.startswith('block'):
            rig.create_rig('TOP',(512,512),reset=False)
            rig.render_shadow_decal(root,OUT/(name+'_shadow.png'))
        print('F2 PASS '+name,flush=True)
    print('F2 BUILD COMPLETE',flush=True)

def audit():
    failures=[]
    for name in SPECS:
        bpy.ops.wm.open_mainfile(filepath=str(SRC/('f2_'+name+'.blend')))
        root=bpy.data.objects[name];bpy.context.view_layer.update()
        points=[ob.matrix_world@v.co for ob in root.children_recursive if ob.type=='MESH' for v in ob.data.vertices]
        limits=[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)]
        if name.startswith(('block','rampart')):
            if any(lo< -1.001 or hi>1.001 for lo,hi in limits[:2]) or limits[2][1]>1.251:failures.append(name)
        if name.startswith('cliff') and abs(limits[2][0]+2.5)>.001:failures.append(name+' depth')
        path=SRC/('f2_'+name+'_check.json');check=json.loads(path.read_text());check['bounds']=limits;path.write_text(json.dumps(check))
    (SRC/'f2_geometry.json').write_text(json.dumps({'status':'FAIL' if failures else 'PASS','errors':failures}))
    print('F2 GEOMETRY '+('FAIL '+str(failures) if failures else 'PASS: footprint, 1.25u height, 2.5u cliffs'),flush=True)

if __name__=='__main__':
    if '--audit' in sys.argv:audit()
    else:build()
