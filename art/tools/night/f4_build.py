"""F4 flooded crypt terrain; shared C1 MAP/TOP contract. Blender background only.
Reuses C1 geometry/periodicity and ash_lord worn PBR; Pillow assembles/checks only.
Run with -- --only name to resume, or regular Python --verify after rendering.
"""
from pathlib import Path
import sys, math, random, json
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/terrain/crypts/iso'
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
    geometry=SRC/'f4_geometry.json'
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
    for p in SRC.glob('f4_*_check.json'):
        c=json.loads(p.read_text());pivots.append(c)
        if max(abs(a-b) for a,b in zip(c['pivot'],SPECS[c['name']][1]))>.01:errors.append('pivot '+c['name'])
    if len(pivots)!=18:errors.append('pivot count')
    expected={n+s+'.png' for n in SPECS for s in ('','_n')}
    expected|={n+'_shadow.png' for n in ('block_a','block_b','block_c')}
    expected|={n+'_e.png' for n in ('block_b','rampart_corner_n')}
    actual={p.name for p in OUT.glob('*.png')}
    if actual!=expected:errors.append('inventory '+str(actual^expected))
    canvas=Image.new('RGBA',(1800,2020),(19,25,28,255))
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
    refs=(ROOT/'art/tools/iso/_c4_contact.png',ROOT/'art/tools/characters/_m2_contact.png',ROOT/'art/tools/iso/_c1_contact.png',ROOT/'art/tools/night/_cs1_contact.png')
    for i,p in enumerate(refs):
        im=Image.open(p).convert('RGBA')
        if i==3:im=im.crop((im.width//2,0,im.width,im.height))
        im.thumbnail((425,240));canvas.alpha_composite(im,(20+i*450,1470))
    for i,n in enumerate(('ground_a_n','block_b_n','block_b_e','rampart_corner_n_e','water_deep_n')):
        im=Image.open(OUT/(n+'.png')).convert('RGBA');im.thumbnail((300,240));canvas.alpha_composite(im,(30+i*350,1740))
    canvas.convert('RGB').save(HERE/'_f4_contact.png',optimize=True,compress_level=9)
    import numpy as np
    measurements={}
    for name in SPECS:
        d=np.asarray(Image.open(OUT/(name+'.png')).convert('RGBA'))
        n=np.asarray(Image.open(OUT/(name+'_n.png')).convert('RGBA'))
        if not np.array_equal(d[:,:,3],n[:,:,3]):errors.append('normal alpha '+name)
        colors=np.unique(n[n[:,:,3]==255,:3],axis=0)
        if len(colors)>27:errors.append('normal tones '+name+' '+str(len(colors)))
        rgb=d[d[:,:,3]>240,:3]
        measurements[name]={'normal_colors':len(colors),'rgb_mean':rgb.mean(axis=0).round(2).tolist()}
        if name in ('water_deep','void_1024') and float(rgb.mean())>28:errors.append('abyss too light '+name)
        for suffix in ('_e',):
            path=OUT/(name+suffix+'.png')
            if path.exists():
                e=np.asarray(Image.open(path).convert('RGBA'))
                if not np.array_equal(d[:,:,3],e[:,:,3]):errors.append('emission alpha '+name)
                if name=='rampart_corner_n' and int((e[:,:,:3].max(axis=2)>40).sum())<100:
                    errors.append('corner crystal occluded')
    void=np.asarray(Image.open(OUT/'void_1024.png').convert('RGBA')).astype(float)
    seam=max(float(abs(void[0]-void[-1]).max()),float(abs(void[:,0]-void[:,-1]).max()))
    if seam>2:errors.append('void seam '+str(seam))
    (SRC/'f4_measurements.json').write_text(json.dumps({'assets':measurements,'void_seam_max':seam},indent=2))
    result={'status':'FAIL' if errors else 'PASS','errors':errors,'diffuse':18,'normal':18,'shadows':3,'emission':2,'pivots':pivots}
    (SRC/'f4_validation.json').write_text(json.dumps(result,indent=2))
    print('F4 '+result['status']+': '+str(errors) if errors else 'F4 PASS: 41 PNG; sizes, pivots, diamond alpha, normals, shadows, emission')
    return not errors

if '--verify' in sys.argv:
    sys.exit(0 if verify() else 1)

import bpy
from mathutils import Vector
import iso_rig as rig
from ash_lord_build import worn, mesh, rod
from terraces_iso_build import box, periodic
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel
cel.install('tile')


def materials():
    m={k:worn('F4 '+k,a,b,metal,rough) for k,a,b,metal,rough in [
        ('stone','2E3238','40434A',.05,.78),('salt','3C3A33','646257',0,.8),
        ('bone','444239','777164',0,.8),('wall','1E2126','343A42',0,.8),
        ('edge','596770','8FA3B0',.08,.7),('joint','12171D','24292E',0,.9),
        ('wet','182329','2A383F',.2,.3),('crystal','536B77','8BA6B0',.15,.25)]}
    m['glow']=rig.material('F4 white cyan crystal',(0.521,.905,1),emission=2.0)
    m['glow']['rainfall_emissive']=True
    return m


def shard(name,loc,radius,height,root,mat,seed=0):
    rng=random.Random(seed);n=7
    v=[]
    for z,scale in ((0,1),(height*.68,.78)):
        for j in range(n):
            a=j*math.tau/n;r=radius*rng.uniform(.78,1.12)*scale
            v.append((loc[0]+r*math.cos(a),loc[1]+r*math.sin(a),loc[2]+z))
    v.append((loc[0]+radius*.2,loc[1]-radius*.15,loc[2]+height))
    faces=[tuple(range(n-1,-1,-1))]
    faces += [(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
    faces += [(n+j,n+(j+1)%n,2*n) for j in range(n)]
    return mesh(name,v,faces,mat,root)


def polygon(name,x,y,z,rx,ry,root,mat,seed=0):
    rng=random.Random(seed);n=10
    verts=[(x+rx*math.cos(j*math.tau/n)*rng.uniform(.7,1),y+ry*math.sin(j*math.tau/n)*rng.uniform(.7,1),z) for j in range(n)]
    return mesh(name,verts,[tuple(range(n))],mat,root)


def bone(x,y,z,root,m,angle=0,scale=1):
    a=Vector((math.cos(angle),math.sin(angle),0));p=Vector((x,y,z))
    rod('Embedded long bone',[p-a*.11*scale,p,p+a*.11*scale],.014*scale,m['bone'],root)
    for sign in (-1,1):
        q=p+a*sign*.115*scale
        shard('Broken epiphysis',q,.022*scale,.027*scale,root,m['bone'],sign+12)


def skull(x,y,z,root,m,scale=1):
    # Faceted anatomical cranium, jaw and recessed dark orbital plates; no round cartoon eyes.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,y,z+.045*scale))
    o=bpy.context.object;o.name='Ossuary human cranium';o.scale=(.048*scale,.055*scale,.058*scale);o.parent=root;o.data.materials.append(m['bone'])
    box('Broken mandible',(x,y-.019*scale,z),(.062*scale,.053*scale,.023*scale),m['salt'],root,.006*scale)
    for sign in (-1,1):
        box('Recessed orbit',(x+sign*.022*scale,y-.048*scale,z+.048*scale),(.022*scale,.009*scale,.021*scale),m['joint'],root,.004*scale)
    mesh('Nasal cavity',[(x-.008*scale,y-.056*scale,z+.021*scale),(x+.008*scale,y-.056*scale,z+.021*scale),(x,y-.057*scale,z+.038*scale)],[(0,1,2)],m['joint'],root)


def ground(name,root,m):
    rng=random.Random(104+ord(name[-1]))
    # Continuous overscan stone bed; detailed motifs stay within the shared perimeter course.
    box('Overlapping crypt bed',(0,0,-.045),(4.045,4.045,.09),m['joint'],root,0)
    for row in range(8):
        for col in range(8):
            x=-1.75+col*.5;y=-1.75+row*.5
            mat=m['salt' if (row*3+col)%11==0 else 'stone']
            box('Fractured funerary paving',(x,y,-.016),(.484,.484,.048),mat,root,.012)
    for i in range(7):
        x=rng.uniform(-1.55,1.55);y=rng.uniform(-1.55,1.55)
        polygon('Damp slab hollow',x,y,.010,.12,.22,root,m['wet'],i)
        pts=[(x-.13,y-.20,.013),(x-.035,y-.04,.014),(x+.05,y+.015,.014),(x+.1,y+.23,.013)]
        rod('Forked fracture',pts,.008,m['joint'],root)
    # A sunken ledger stone, cut epitaph and sparse embedded remains.
    x=(-.62,.58,-.25,.68)['abcd'.index(name[-1])];y=.30
    box('Recess of tomb ledger',(x,y,.008),(.66,1.24,.018),m['joint'],root,.025)
    box('Split tomb ledger',(x,y,.022),(.59,1.16,.025),m['salt'],root,.026)
    for dy,w in ((.34,.27),(.23,.34),(.12,.25),(-.05,.18)):
        box('Eroded epitaph',(x,y+dy,.037),(w,.013,.004),m['joint'],root,.001)
    rod('Ledger fracture',[(x-.27,y-.45,.041),(x-.08,y-.19,.042),(x-.13,y+.03,.042),(x+.28,y+.34,.042)],.008,m['joint'],root)
    for i in range(6):
        bx=rng.uniform(-1.55,1.55);by=rng.uniform(-1.5,1.5)
        bone(bx,by,.019,root,m,rng.random()*math.tau,.7)
        polygon('Crusted salt seam',bx+.11,by,.012,.075,.035,root,m['salt'],i+70)
    if name in ('ground_c','ground_d'):skull(-.95,-.78,.019,root,m,.8)


def dark_surface(name,root,size,shallow=False):
    # Blender image texture: periodic low-frequency water bands; no painted Pillow pixels.
    import numpy as np
    n=256;u,v=np.meshgrid(np.arange(n)/n,np.arange(n)/n)
    bands=np.sin(math.tau*(u*3+v*2)+.28*np.sin(v*math.tau*2))
    fine=np.sin(math.tau*(u*7-v*3))
    level=.010+(bands>.86)*.002+(fine>.97)*.001
    if shallow:level=level+.002
    rgba=np.ones((n,n,4),dtype=np.float32)
    for c,k in enumerate((.65,.88,1.1)):rgba[:,:,c]=level*k
    image=bpy.data.images.new('F4 '+name+' periodic darkwater',width=n,height=n,alpha=True)
    image.colorspace_settings.name='Non-Color';image.pixels.foreach_set(rgba.ravel());image.pack()
    mat=rig.material('F4 '+name+' black water',(1,1,1))
    nd=mat.node_tree.nodes;lk=mat.node_tree.links
    tex=nd.new('ShaderNodeTexImage');tex.image=image;tex.extension='REPEAT';tex.interpolation='Linear'
    lk.new(tex.outputs['Color'],nd.get('Principled BSDF').inputs['Base Color'])
    extent=size+.06 if size==8 else size
    ob=box('Seamless blackwater',(0,0,-.02),(extent,extent,.04),mat,root,0)
    for poly in ob.data.polygons:
        for loop in poly.loop_indices:
            v=ob.data.vertices[ob.data.loops[loop].vertex_index].co
            ob.data.uv_layers.active.data[loop].uv=(v.x/size+.5,v.y/size+.5)


def water(name,root,m):
    shallow=name=='water_shallow';dark_surface(name,root,2,shallow)
    if shallow:
        for j in range(3):
            for k in range(3):
                box('Drowned flagstone',(-.65+j*.65,-.65+k*.65,.001),(.61,.61,.006),m['wet'],root,.015)
        bone(-.25,-.35,.012,root,m,.4,.8)
    for j in range(3):
        x=-.6+j*.48;y=-.24+j*.25
        rod('Cold crystal reflection',[(x,y,.014),(x+.12,y+.006,.014),(x+.18,y-.008,.014)],.0025,m['crystal'],root)


def column(x,y,z,height,root,m,seed=0):
    # Broken fluted limestone column: irregular radial crown rather than a clean cylinder.
    rng=random.Random(seed);n=16;verts=[]
    for layer in range(2):
        for j in range(n):
            a=j*math.tau/n;r=.19 if j%2 else .23
            verts.append((x+r*math.cos(a),y+r*math.sin(a),z+(height*rng.uniform(.83,1) if layer else 0)))
    mesh('Fluted fractured column',verts,[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)],m['salt'],root,.008)
    box('Chipped column plinth',(x,y,z+.045),(.55,.55,.09),m['stone'],root,.026)


def ossuary(x,y,z,root,m):
    box('Burial niche darkness',(x,y,z+.22),(.94,.52,.44),m['joint'],root,.02)
    for zz in (0,.44):box('Ossuary shelf',(x,y-.035,z+zz), (1.02,.62,.08),m['salt'],root,.018)
    for xx in (-.49,.49):box('Niche jamb',(x+xx,y-.04,z+.22),(.09,.62,.44),m['stone'],root,.015)
    for j in range(5):
        skull(x-.36+j*.18,y-.28,z+.11,root,m,.92)
        bone(x-.33+j*.16,y-.13,z+.06,root,m,.35+j,.8)


def blocks(name,root,m):
    rng=random.Random(442)
    if name=='block_a':
        ossuary(-.32,.34,.05,root,m);ossuary(-.28,.34,.57,root,m)
        column(.58,-.25,.02,.77,root,m,6)
        skull(-.56,-.42,.07,root,m,1.05)
    elif name=='block_b':
        column(-.48,.32,.02,.90,root,m,9)
        for j,(x,y,h,r) in enumerate(((.30,.10,1.06,.15),(.56,.12,.68,.11),(.16,-.10,.53,.10),(.48,-.17,.44,.09))):
            shard('Crystal gangue',(x,y,.04),r*1.35,h*.80,root,m['crystal'],j+5)
            shard('White cyan crystal vein',(x-.025,y-.025,.08),r*.48,h,root,m['glow'],j+12)
        bone(-.38,-.42,.08,root,m,.2,1.2)
    else:
        # A collapsed rib vault, with one surviving pier and jagged stalagmites.
        column(-.48,.35,.02,.82,root,m,12)
        for j in range(5):
            o=box('Fallen vault voussoir',(-.44+j*.23,-.24+.08*math.sin(j),.17),(.25,.40,.25),m['salt'],root,.023)
            o.rotation_euler=(.16*j,.15*(j-2),.22*(j-2))
        for j in range(4):shard('Calcite stalagmite',(.33+j*.13,.38-j*.19,.02),.09,.36+j*.10,root,m['wall'],j+10)
    for j in range(8):
        x=rng.uniform(-.8,.8);y=rng.uniform(-.7,.7)
        shard('Vault rubble',(x,y,.005),rng.uniform(.055,.13),rng.uniform(.05,.12),root,m['stone'],j)


def wall_segment(axis,root,m):
    # Side-facing burial loculi as deep black openings between separate masonry ribs.
    # Both burial faces open toward the MAP camera; the west wall must be mirrored.
    def pos(a,b,z):return (a,b,z) if axis==0 else (-b,a,z)
    def dims(a,b,z):return (a,b,z) if axis==0 else (b,a,z)
    box('Cavern wall backing',pos(0,.78,.58),dims(2,.34,1.16),m['wall'],root,.025)
    for z in (.10,.56,1.03):box('Burial course ledge',pos(0,.51,z),dims(2,.26,.075),m['stone'],root,.015)
    for j in range(5):
        a=-.8+j*.40
        for z in (.33,.79):
            box('Funerary loculus shadow',pos(a,.48,z),dims(.31,.014,.31),m['joint'],root,.06)
            for da in (-.18,.18):box('Loculus carved jamb',pos(a+da,.49,z),dims(.045,.15,.38),m['salt'],root,.007)
            box('Funeral tablet',pos(a,.45,z-.12),dims(.19,.032,.052),m['bone'],root,.01)
    # Angular rock crest and cool worn rim, restrained and nonemissive.
    for j in range(8):
        a=-.86+j*.245
        shard('Cavern crest',pos(a,.77,1.02),.16,.19,root,m['wall'],j+axis*10)
    box('Cold limestone rim',pos(0,.48,1.075),dims(2,.07,.04),m['edge'],root,.009)


def rampart(name,root,m):
    if name in ('rampart_ne','rampart_corner_n'):wall_segment(1,root,m)
    if name in ('rampart_nw','rampart_corner_n'):wall_segment(0,root,m)
    if name=='rampart_corner_n':
        for j,(x,y,r,h) in enumerate(((.36,.34,.15,.87),(.58,.30,.085,.59),(.29,.53,.085,.49))):
            shard('Corner crystal root',(x,y,.15),r*1.4,h*.75,root,m['crystal'],j+41)
            shard('Corner crystal heart',(x,y,.20),r*.65,h,root,m['glow'],j+44)


def cliff(name,root,m):
    box('Crypt chasm lip',(0,0,-.04),(2.025,2.025,.08),m['stone'],root,0)
    faces={'cliff_sw':[(1,-1)],'cliff_se':[(0,1)],'cliff_corner_s':[(1,-1),(0,1)],'cliff_corner_w':[(1,-1),(0,-1)],'cliff_corner_e':[(0,1),(1,1)]}[name]
    for axis,sign in faces:
        def pos(a,b,z):return (sign*b,a,z) if axis==0 else (a,sign*b,z)
        def dims(a,b,z):return (b,a,z) if axis==0 else (a,b,z)
        box('Abyss wet core',pos(0,.84,-1.25),dims(2,.32,2.5),m['wall'],root,0)
        for j in range(8):
            a=-.86+j*.245
            # Exposed basalt/calcite teeth plunge down to the black water.
            o=box('Fractured cavern strata',pos(a,.955,-1.18),dims(.21,.10,2.33),m['wall' if j%3 else 'stone'],root,.018)
            for k in range(3):
                z=-.24-k*.71-.07*(j%2)
                box('Broken burial foundation',pos(a,.99,z),dims(.22,.095,.15),m['salt' if (j+k)%7==0 else 'stone'],root,.018)
            if j%3==0:
                rod('Petrified salt runnel',[pos(a,1.012,-.08),pos(a+.03,1.016,-.48),pos(a-.015,1.012,-.92)],.009,m['edge'],root)
        box('Damp chasm arris',pos(0,.99,-.065),dims(2,.045,.055),m['salt'],root,.007)
    for i in range(3):bone(-.56+i*.45,.2,.012,root,m,i*.8,.7)


def build():
    OUT.mkdir(parents=True,exist_ok=True);SRC.mkdir(parents=True,exist_ok=True)
    only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else None
    for name,(size,pivot) in SPECS.items():
        if only and name!=only:continue
        s=rig.create_rig('TOP' if name.startswith('void') else 'MAP',size)
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(pivot[1]-size[1]/2)/rig.R,0))
        s.eevee.taa_render_samples=8
        key=bpy.data.objects.get('Sun_chaud_haut_gauche');key.data.color=(.70,.82,1);key.data.energy=1.4
        fill=bpy.data.objects.get('Fill_froid');fill.data.type='SUN';fill.data.color=(.60,.75,1);fill.data.energy=.35
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
            dark_surface(name,root,8)
        if name.startswith(('block','rampart')):
            for ob in root.children_recursive:
                if ob.type!='MESH':continue
                for v in ob.data.vertices:
                    w=ob.matrix_world@v.co
                    w.x=max(-1,min(1,w.x));w.y=max(-1,min(1,w.y));w.z=min(1.25,w.z)
                    v.co=ob.matrix_world.inverted()@w
        if not name.startswith(('water','void')):rig.bake_ao_shadows(root)
        from bpy_extras.object_utils import world_to_camera_view
        bpy.context.view_layer.update();q=world_to_camera_view(s,s.camera,Vector((0,0,0)))
        check={'name':name,'pivot':[q.x*size[0],(1-q.y)*size[1]],'R':rig.R,'size':size}
        (SRC/('f4_'+name+'_check.json')).write_text(json.dumps(check))
        path=OUT/(name+'.png');rig.render_frame(path)
        if name not in ('block_b','rampart_corner_n'):path.with_name(name+'_e.png').unlink(missing_ok=True)
        # Retain each complete source scene with its contractual MAP camera.
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('f4_'+name+'.blend')))
        if name.startswith('block'):
            rig.create_rig('TOP',(512,512),reset=False)
            rig.render_shadow_decal(root,OUT/(name+'_shadow.png'))
        print('F4 PASS '+name,flush=True)
    # The diffuse rampart_corner_n.png also ends in _n: select passes explicitly.
    normals=[OUT/(name+'_n.png') for name in SPECS]
    import hashlib, shutil
    work=SRC/'f4_normal_sources';work.mkdir(exist_ok=True)
    for p in normals:
        key=hashlib.sha1(str(p.resolve()).encode()).hexdigest()[:10]
        shutil.copyfile(p,work/(key+'_'+p.name))
    cel.quantize_normal_files(normals,work=work)
    print('F4 BUILD COMPLETE',flush=True)

def audit():
    failures=[]
    for name in SPECS:
        bpy.ops.wm.open_mainfile(filepath=str(SRC/('f4_'+name+'.blend')))
        root=bpy.data.objects[name];bpy.context.view_layer.update()
        points=[ob.matrix_world@v.co for ob in root.children_recursive if ob.type=='MESH' for v in ob.data.vertices]
        limits=[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)]
        if name.startswith(('block','rampart')):
            if any(lo< -1.001 or hi>1.001 for lo,hi in limits[:2]) or limits[2][1]>1.251:failures.append(name)
        if name.startswith('cliff') and abs(limits[2][0]+2.5)>.001:failures.append(name+' depth')
        path=SRC/('f4_'+name+'_check.json');check=json.loads(path.read_text());check['bounds']=limits;path.write_text(json.dumps(check))
    (SRC/'f4_geometry.json').write_text(json.dumps({'status':'FAIL' if failures else 'PASS','errors':failures}))
    print('F4 GEOMETRY '+('FAIL '+str(failures) if failures else 'PASS: footprint, 1.25u height, 2.5u cliffs'),flush=True)

if __name__=='__main__':
    if '--audit' in sys.argv:audit()
    else:
        build()
        if '--only' not in sys.argv:audit()
