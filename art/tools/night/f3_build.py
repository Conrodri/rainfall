"""F3 rust city terrain; shared C1 MAP/TOP contract. Blender background only.
Reuses C1 geometry/periodicity and ash_lord worn PBR; Pillow assembles/checks only.
Run with -- --only name to resume, or regular Python --verify after rendering.
"""
from pathlib import Path
import sys, math, random, json
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/terrain/rust_city/iso'
SRC=ROOT/'art/blender/terrain'
HERE=Path(__file__).resolve().parent
if '--verify' not in sys.argv:sys.path.insert(0,str(ROOT/'art/tools/iso/_deps'))
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
    geometry=SRC/'f3_geometry.json'
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
    for p in SRC.glob('f3_*_check.json'):
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
    canvas.convert('RGB').save(HERE/'_f3_contact.png',optimize=True,compress_level=9)
    result={'status':'FAIL' if errors else 'PASS','errors':errors,'diffuse':18,'normal':18,'shadows':3,'emission':2,'pivots':pivots}
    (SRC/'f3_validation.json').write_text(json.dumps(result,indent=2))
    print('F3 '+result['status']+': '+str(errors) if errors else 'F3 PASS: 41 PNG; sizes, pivots, diamond alpha, normals, shadows, emission')
    return not errors

if '--verify' in sys.argv:
    sys.exit(0 if verify() else 1)

import bpy
from mathutils import Vector
import iso_rig as rig
from ash_lord_build import worn, mesh, rod
from terraces_iso_build import box, periodic


def materials():
    m={k:worn('F3 '+k,a,b,metal,rough) for k,a,b,metal,rough in [
        ('iron','25292E','4E4A44',.68,.52),('brick','1C2025','3B3F46',.05,.64),
        ('rust','30251F','6B4530',.45,.66),('brass','5A4B32','A8946E',.72,.43),
        ('oil','080D12','141B22',.42,.3),('mortar','10151A','24292F',0,.8),
        ('concrete','292D31','4A4E4F',.04,.75)]}
    m['glow']=rig.material('F3 amber storm filament',(1,.38,.085),emission=2.5)
    return m

def bolt(pos,root,m,r=.018):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=r,location=pos)
    o=bpy.context.object;o.name='Peened brass rivet';o.scale.z=.45;o.parent=root;o.data.materials.append(m['brass'])
    return o

def sheet(loc,dims,root,m,tilt=0,rusted=False):
    o=box('Buckled riveted sheet',loc,dims,m['rust' if rusted else 'iron'],root,.009)
    o.rotation_euler=(tilt*.45,tilt,tilt*.3)
    # Rivets share the panel transform, retaining a credible fastening pattern.
    for x in (-dims[0]/2+.035,dims[0]/2-.035):
        for y in (-dims[1]/2+.035,dims[1]/2-.035):
            b=bolt((0,0,0),root,m);b.parent=o;b.location=(x,y,dims[2]/2+.005)
    return o

def pipe(points,r,root,m):
    return rod('Split industrial conduit',points,r,m['rust'],root)

def flange(pos,root,m,r=.16,axis='Z'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=.04,location=pos)
    o=bpy.context.object;o.name='Bolted pipe flange';o.parent=root;o.data.materials.append(m['iron'])
    if axis=='X':o.rotation_euler.y=math.pi/2
    for j in range(8):
        a=j*math.tau/8
        if axis=='Z':q=(pos[0]+r*.79*math.cos(a),pos[1]+r*.79*math.sin(a),pos[2]+.026)
        else:q=(pos[0]+.026,pos[1]+r*.79*math.cos(a),pos[2]+r*.79*math.sin(a))
        bolt(q,root,m,.016)
    return o

def grating(x,y,z,w,h,root,m):
    box('Drain black well',(x,y,z-.025),(w,h,.05),m['mortar'],root,.006)
    for dx in (-w/2,w/2):box('Drain rim',(x+dx,y,z+.01),(.028,h+.04,.025),m['iron'],root,.004)
    for dy in (-h/2,h/2):box('Drain rim',(x,y+dy,z+.01),(w,.028,.025),m['iron'],root,.004)
    for j in range(max(2,int(w/.075))):
        xx=x-w/2+.04+j*.075
        box('Grille slots',(xx,y,z+.015),(.018,h,.03),m['iron'],root,.003)

def oil_patch(x,y,z,rx,ry,root,m,seed=1):
    rng=random.Random(seed);n=20
    verts=[(x,y,z)]+[(x+math.cos(j*math.tau/n)*rx*rng.uniform(.85,1.1),y+math.sin(j*math.tau/n)*ry*rng.uniform(.85,1.1),z) for j in range(n)]
    mesh('Spilled black oil',verts,[(0,j+1,(j+1)%n+1) for j in range(n)],m['oil'],root)

def ground(name,root,m):
    seed=ord(name[-1]);rng=random.Random(seed)
    for key in ('mortar','brick','iron','oil'):periodic(m[key],4)
    box('Periodic iron paving bed',(0,0,-.035),(4,4,.07),m['mortar'],root,0)
    # Exact common perimeter course, inset variation only: no broken tile seams.
    for row in range(12):
        for col in range(8):
            x=-2+(col+.5)*.5;y=-2+(row+.5)/3
            mat=m['iron' if (row+col)%5==0 else 'brick']
            o=box('Worn iron sett',(x,y,-.009),(.486,.319,.035),mat,root,.011)
    for k in range(4):
        x=rng.uniform(-1.4,1.4);y=rng.uniform(-1.3,1.3)
        oil_patch(x,y,.011,rng.uniform(.13,.35),rng.uniform(.1,.22),root,m,k+seed)
    grating(-.75,.65,.017,.46,.62,root,m)
    if name in ('ground_b','ground_d'):
        sheet((.55,-.56,.03),(.75,.48,.025),root,m,0,True)
    if name=='ground_c':
        for j in range(3):box('Old tram rail',(-.7+j*.07,0,.02),(.022,2.9,.018),m['iron'],root,.002)

def water(name,root,m):
    periodic(m['oil'],2)
    box('Canal oily blackwater',(0,0,-.015),(2,2,.03),m['oil'],root,0)
    if name=='water_shallow':
        # Sunken machine fragments; restrained cold reflections come from PBR.
        for j in range(4):
            box('Drowned iron fragments',(-.6+j*.36,.25*math.sin(j*4),-.006),(.18,.31,.012),m['iron'],root,.005)
    for j in range(4):
        pts=[(-.7+i*.09,-.55+j*.34+.022*math.sin(i*.8+j),.002) for i in range(15)]
        rod('Broken oily ripple',pts,.0025,m['iron'],root)

def lantern(root,m,pos):
    x,y,z=pos
    box('Storm lamp backplate',(x,y+.025,z),(.18,.055,.27),m['iron'],root,.01)
    box('Amber furnace slit',(x,y-.017,z),(.105,.045,.17),m['glow'],root,.003)
    for dz in (-.11,.11):box('Lamp brass cowl',(x,y-.02,z+dz),(.19,.1,.035),m['brass'],root,.006)
    for dx in (-.065,0,.065):box('Lamp protective ribs',(x+dx,y-.05,z),(.011,.025,.21),m['iron'],root,.002)

def blocks(name,root,m):
    box('Machine rubble foot',(0,0,.055),(2,2,.11),m['mortar'],root,0)
    if name=='block_a':
        for j,(x,y,z,w,h,t) in enumerate([(-.14,.15,.23,1.5,1.1,.08),(.15,-.08,.43,1.34,1.2,-.19),(-.23,.04,.66,1.3,.9,.15),(.16,.13,.87,1.1,.75,-.24)]):
            sheet((x,y,z),(w,h,.09),root,m,t,j%2==0)
        pipe([(-.72,-.67,.15),(-.72,-.67,.61),(-.28,-.67,.78),(.15,-.67,.74)],.075,root,m)
    elif name=='block_b':
        box('Collapsed generator housing',(-.16,.1,.51),(1.3,1.2,.75),m['iron'],root,.065)
        sheet((-.13,.1,.93),(1.42,1.25,.055),root,m,-.1,True)
        for i in range(8):box('Motor cooling fins',(-.65+i*.14,-.53,.52),(.042,.08,.58),m['iron'],root,.006)
        flange((.6,.08,.65),root,m,.3,'X')
        pipe([(.65,.08,.65),(.81,.08,.65),(.81,.08,.33),(.81,-.61,.33)],.095,root,m)
        lantern(root,m,(-.18,-.6,.64))
        for i in range(3):pipe([(-.6+i*.28,.62,.16),(-.6+i*.28,.62,1.1),(-.4+i*.28,.55,1.2)],.035,root,m)
    else:
        for i in range(3):
            y=-.58+i*.56
            pipe([(-.85,y,.22),(-.57,y,.22),(-.48,y,.68),(-.16,y,1.05),(.37,y,1.05),(.64,y,.8),(.88,y,.8)],.12,root,m)
            flange((-.48,y,.65),root,m,.18)
        sheet((.08,.02,.28),(1.25,1.5,.055),root,m,.18,True)
    rng=random.Random(191)
    for j in range(7):
        x=rng.uniform(-.8,.8);y=rng.uniform(-.8,.8)
        box('Fallen quay brick',(x,y,.13),(.18,.11,.09),m['brick'],root,.012)

def wall_course(axis,fixed,z,root,m,rows=5):
    for row in range(rows):
        for j in range(7):
            a=-.857+j*2/7
            loc=(a,fixed,z+row*.205) if axis==1 else (fixed,a,z+row*.205)
            dims=(.277,.28,.195) if axis==1 else (.28,.277,.195)
            box('Black kiln masonry',loc,dims,m['brick' if (row+j)%6 else 'concrete'],root,.012)

def rampart(name,root,m):
    edges=[1] if name.endswith('ne') else [0] if name.endswith('nw') else [0,1]
    for axis in edges:
        fixed=.83 if axis==1 else -.83
        wall_course(axis,fixed,.11,root,m,5)
        for j in range(4):
            a=-.75+j*.5
            loc=(a,fixed,1.12) if axis==1 else (fixed,a,1.12)
            dims=(.49,.33,.07) if axis==1 else (.33,.49,.07)
            sheet(loc,dims,root,m,0,j%2==0)
            # Iron straps and peened bolt heads across broken brick courses.
            loc=(a,.66,.53) if axis==1 else (-.66,a,.53)
            dims=(.055,.045,.92) if axis==1 else (.045,.055,.92)
            box('Quay iron retaining strap',loc,dims,m['iron'],root,.006)
        pts=[(-.9,.62,.25),(.87,.62,.25)] if axis==1 else [(-.62,-.9,.25),(-.62,.87,.25)]
        pipe(pts,.045,root,m)
    if name.endswith('corner_n'):lantern(root,m,(-.57,.62,.88))

def cliff(name,root,m):
    box('Dock top jointive lip',(0,0,-.035),(2,2,.07),m['brick'],root,0)
    faces={'cliff_sw':[(1,-1)],'cliff_se':[(0,1)],'cliff_corner_s':[(1,-1),(0,1)],'cliff_corner_w':[(1,-1),(0,-1)],'cliff_corner_e':[(0,1),(1,1)]}[name]
    for axis,sign in faces:
        fixed=sign*.86
        loc=(fixed,0,-1.25) if axis==0 else (0,fixed,-1.25)
        dims=(.28,2,2.5) if axis==0 else (2,.28,2.5)
        box('Deep cracked quay core',loc,dims,m['mortar'],root,0)
        for row in range(11):
            for j in range(6):
                a=-.833+j/3;z=-.14-row*.218
                loc=(sign*.95,a,z) if axis==0 else (a,sign*.95,z)
                dims=(.09,.319,.204) if axis==0 else (.319,.09,.204)
                if (row*5+j*7)%17==0:continue
                box('Spalled dock masonry',loc,dims,m['brick' if (j+row)%4 else 'concrete'],root,.014)
        for j in range(3):
            a=-.7+j*.7
            pts=[(sign*1.0,a,-.05),(sign*1.0,a,-.8),(sign*.98,a+.08,-1.2),(sign*.97,a+.04,-2.35)] if axis==0 else [(a,sign*1.0,-.05),(a,sign*1.0,-.8),(a+.08,sign*.98,-1.2),(a+.04,sign*.97,-2.35)]
            pipe(pts,.025,root,m)
        # Jagged, fractured quay buttresses with exposed twisted reinforcement.
        for a in (-.63,.63):
            loc=(sign*.89,a,-1.25) if axis==0 else (a,sign*.89,-1.25)
            dims=(.2,.12,2.5) if axis==0 else (.12,.2,2.5)
            box('Quay steel pile',loc,dims,m['rust'],root,.015)
    grating(0,0,.006,.44,.58,root,m)

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
            fog=periodic(worn('Storm steam abyss','10151B','303740',0,1),8)
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
        (SRC/('f3_'+name+'_check.json')).write_text(json.dumps(check))
        path=OUT/(name+'.png');rig.render_frame(path)
        if name not in ('block_b','rampart_corner_n'):path.with_name(name+'_e.png').unlink(missing_ok=True)
        # Retain each complete source scene with its contractual MAP camera.
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('f3_'+name+'.blend')))
        if name.startswith('block'):
            rig.create_rig('TOP',(512,512),reset=False)
            rig.render_shadow_decal(root,OUT/(name+'_shadow.png'))
        print('F3 PASS '+name,flush=True)
    print('F3 BUILD COMPLETE',flush=True)

def audit():
    failures=[]
    for name in SPECS:
        bpy.ops.wm.open_mainfile(filepath=str(SRC/('f3_'+name+'.blend')))
        root=bpy.data.objects[name];bpy.context.view_layer.update()
        points=[ob.matrix_world@v.co for ob in root.children_recursive if ob.type=='MESH' for v in ob.data.vertices]
        limits=[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)]
        if name.startswith(('block','rampart')):
            if any(lo< -1.001 or hi>1.001 for lo,hi in limits[:2]) or limits[2][1]>1.251:failures.append(name)
        if name.startswith('cliff') and abs(limits[2][0]+2.5)>.001:failures.append(name+' depth')
        path=SRC/('f3_'+name+'_check.json');check=json.loads(path.read_text());check['bounds']=limits;path.write_text(json.dumps(check))
    (SRC/'f3_geometry.json').write_text(json.dumps({'status':'FAIL' if failures else 'PASS','errors':failures}))
    print('F3 GEOMETRY '+('FAIL '+str(failures) if failures else 'PASS: footprint, 1.25u height, 2.5u cliffs'),flush=True)

if __name__=='__main__':
    if '--audit' in sys.argv:audit()
    else:build()
