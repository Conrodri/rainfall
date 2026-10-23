"""F4P drowned ossuary props. Reuses F3P geometry helpers, MAP/TOP rigs and shared cel.
Blender --background --python this.py [-- --only name]; system Python --verify.
Pillow only crops, assembles and checks; all marks and fractures are geometry.
"""
from pathlib import Path
import sys, math, random, json
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'game/assets/sprites/props/crypts'
SRC=ROOT/'art/blender/props'
WEIGHTS={'bone_pile':4,'ossuary_niche':2,'salt_crust':4,'crystal_cluster':2,
         'stalagmite':1,'broken_column':4,'crystal_lantern':1,'sarcophagus_lid':2}
SHADOWS={'bone_pile','ossuary_niche','stalagmite','broken_column','sarcophagus_lid'}
EMIT={'crystal_cluster','crystal_lantern'}
LIMITS={'bone_pile':1.2,'ossuary_niche':1.5,'salt_crust':1.5,'crystal_cluster':1.5,
        'stalagmite':.8,'broken_column':1.5,'crystal_lantern':.8,'sarcophagus_lid':1.5}

def verify():
    from PIL import Image, ImageChops
    errors=[]; manifest=json.loads((OUT/'props.json').read_text())
    if {p['name'] for p in manifest['props']} != set(WEIGHTS):errors.append('manifest names')
    expected={n+s+'.png' for n in WEIGHTS for s in ('','_n')}
    expected|={n+'_shadow.png' for n in SHADOWS}|{n+'_e.png' for n in EMIT}
    if {p.name for p in OUT.glob('*.png')}!=expected:errors.append('inventory')
    for p in manifest['props']:
        n=p['name'];c=json.loads((SRC/('f4p_'+n+'_check.json')).read_text())
        im=Image.open(OUT/(n+'.png')).convert('RGBA');a=im.getchannel('A');bbox=a.getbbox()
        if im.size!=(bbox[2]-bbox[0]+8,bbox[3]-bbox[1]+8) or bbox[:2]!=(4,4):errors.append(n+' crop')
        if max(c['envelope'])>LIMITS[n]+.001:errors.append(n+' envelope')
        if p['weight']!=WEIGHTS[n] or p['px_per_u']!=90.51 or p['foot']!=c['foot']:errors.append(n+' manifest')
        if p['fade']!=(n in {'stalagmite','crystal_lantern'}):errors.append(n+' fade')
        if p.get('shadow_rig')!=('top' if n in SHADOWS else None):errors.append(n+' shadow rig')
        for suffix in ['_n']+(['_e'] if n in EMIT else []):
            other=Image.open(OUT/(n+suffix+'.png')).convert('RGBA')
            if other.size!=im.size or ImageChops.difference(a,other.getchannel('A')).getextrema()[1]>0:errors.append(n+suffix+' alpha')
            if suffix=='_n':
                colors={rgb[:3] for rgb in other.getdata() if rgb[3]>250}
                if len(colors)>27:errors.append(n+' normal colors '+str(len(colors)))
                if any(abs(math.sqrt(sum((v/127.5-1)**2 for v in rgb))-1)>.015 for rgb in colors):errors.append(n+' normal length')
            elif max(x.getextrema()[1] for x in other.split()[:3])<100:errors.append(n+' emission')
        if n in SHADOWS:
            sh=Image.open(OUT/(n+'_shadow.png')).convert('RGBA')
            if sh.size!=(512,512) or not sh.getchannel('A').getbbox():errors.append(n+' shadow')
            if any(r!=g or g!=b for r,g,b,a0 in sh.getdata()):errors.append(n+' gray')
    for n,h in [('stalagmite',1.8),('crystal_cluster',1.2),('crystal_lantern',2.0)]:
        c=json.loads((SRC/('f4p_'+n+'_check.json')).read_text())
        if abs(c['height_u']-h)>.012:errors.append(n+' height')
    if manifest['density']!=.05 or len(manifest['props'])!=8:errors.append('density/count')
    # Only final contact sheet: native-size assets, emissions/shadows and approved references.
    board=Image.new('RGBA',(1600,1260),(23,28,33,255))
    tile=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    for i,p in enumerate(manifest['props']):
        panel=Image.new('RGBA',(400,350),(23,28,33,255));cx,cy=200,265
        panel.alpha_composite(tile,(cx-tile.width//2,cy-tile.height//2))
        im=Image.open(OUT/(p['name']+'.png')).convert('RGBA')
        panel.alpha_composite(im,(cx-round(p['foot'][0]),cy-round(p['foot'][1])))
        if p['name'] in SHADOWS:
            sh=Image.open(OUT/(p['name']+'_shadow.png')).convert('RGBA');sh.thumbnail((85,85));panel.alpha_composite(sh,(300,260))
        if p['name'] in EMIT:
            e=Image.open(OUT/(p['name']+'_e.png')).convert('RGBA');panel.alpha_composite(e,(315-e.width//2,40))
        board.alpha_composite(panel,((i%4)*400,(i//4)*350))
    refs=['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png']
    for i,ref in enumerate(refs):
        im=Image.open(ROOT/ref).convert('RGBA')
        if i==3:im=im.crop((im.width//2,0,im.width,im.height))
        im.thumbnail((790,270));board.alpha_composite(im,((i%2)*800,710+(i//2)*275))
    board.convert('RGB').save(HERE/'_f4p_contact.png',optimize=True)
    (SRC/'f4p_validation.json').write_text(json.dumps({'status':'FAIL' if errors else 'PASS','errors':errors},indent=2))
    print('F4P '+('FAIL '+str(errors) if errors else 'PASS: 8 props, bounds+8, MAP feet, 5 TOP shadows, 2 accents, finite normals'))
    return not errors

if '--verify' in sys.argv:sys.exit(0 if verify() else 1)
sys.path.insert(0,str(HERE))
from f3p_build import C, box, rod, cyl, ring, worn, mesh, rig
import bpy
from mathutils import Vector
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel

# Shared normal quantizer writes straight RGB to a premultiplied compositor output.
# Apply the alpha once before SetAlpha so Blender's PNG writer unpremultiplies
# back to the exact finite palette, including partially covered pixels.
import inspect
_normal_source=inspect.getsource(cel.quantize_normal_files)
_normal_source=_normal_source.replace("links.new(enc.outputs[0], alpha.inputs['Image'])", """premul = nodes.new('ShaderNodeVectorMath'); premul.operation = 'SCALE'
    links.new(enc.outputs[0], premul.inputs[0])
    links.new(src.outputs['Alpha'], premul.inputs['Scale'])
    links.new(premul.outputs[0], alpha.inputs['Image'])""")
exec(compile(_normal_source,'<F4P shared normal alpha fix>','exec'),cel.__dict__)

def mats():
    return {k:worn(k,a,b,metal,.75) for k,a,b,metal in [
        ('bone','514C3F','A9A28A',0),('stone','252E33','59656A',0),
        ('edge','3C4548','788184',0),('salt','505D61','A0ACA7',0),
        ('iron','222827','454D49',.65),('bronze','344C46','728E7C',.6),
        ('dark','101517','202729',0)]}

def shard(n,p,rad,h,m,r,seed=0):
    rng=random.Random(seed);verts=[];sides=6
    for z,f in [(0,1),(h*.70,.88)]:
        for i in range(sides):
            a=i*math.tau/sides;rr=rad*(.88+rng.random()*.24)*f
            verts.append((p[0]+rr*math.cos(a),p[1]+rr*math.sin(a),p[2]+z))
    verts.append((p[0]+rad*.24,p[1]-rad*.15,p[2]+h))
    faces=[tuple(reversed(range(sides)))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]+[(i+6,(i+1)%6+6,12) for i in range(6)]
    return mesh(n,verts,faces,m,r,.002)

def slab(n,poly,z,h,m,r):
    N=len(poly);v=[(x,y,zz) for zz in (z,z+h) for x,y in poly]
    return mesh(n,v,[tuple(reversed(range(N))),tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)],m,r,.009)

def skull(r,m,p,angle=0,scale=1):
    q=C.empty('Human cranium');q.parent=r;q.location=p;q.rotation_euler.z=angle;q.scale=(scale,)*3
    # Anatomical cranial vault, zygomatic arches, nasal opening and separate jaw/teeth.
    C.sphere('Occipital vault',(0,.014,.135),(.108,.13,.13),m['bone'],q)
    box('Maxilla',(0,-.079,.063),(.145,.075,.07),m['bone'],q,.014)
    for x in [-.052,.052]:
        C.sphere('Recessed orbit',(x,-.111,.143),(.041,.026,.040),m['dark'],q)
        rod('Supraorbital ridge',(x-.036,-.123,.18),(x+.033,-.119,.183),.013,m['bone'],q)
        rod('Zygomatic arch',(x*1.62,-.07,.095),(x*1.43,-.117,.11),.014,m['bone'],q)
    shard('Nasal aperture',(0,-.126,.077),.022,.058,m['dark'],q)
    for x in [-.047,-.026,0,.026,.047]:
        box('Upper tooth',(x,-.125,.055),(.018,.021,.024),m['bone'],q,.003)
    box('Mandibular body',(0,-.079,.024),(.139,.075,.023),m['bone'],q,.008)
    return q

def bones(r,m):
    rng=random.Random(41)
    for i in range(11):
        x,y=rng.uniform(-.36,.36),rng.uniform(-.29,.29);a=rng.uniform(0,math.tau);L=rng.uniform(.22,.47);z=.035+(i%3)*.025
        A=(x-math.cos(a)*L/2,y-math.sin(a)*L/2,z);B=(x+math.cos(a)*L/2,y+math.sin(a)*L/2,z+.025)
        rod('Weathered long bone',A,B,.019,m['bone'],r)
        for end in [A,B]:
            for side in [-1,1]:C.sphere('Epiphysis',(end[0]+side*.016,end[1],end[2]),(.022,.028,.025),m['bone'],r)
    skull(r,m,(-.23,-.19,.07),-.22);skull(r,m,(.16,.05,.09),.62,.88)
    for i in range(4):
        a=i*.32
        C.tube('Broken rib',[(-.1+a*.2,.17,.06),(-.18+a*.2,.27,.13),(-.1+a*.2,.36,.12),(.06+a*.2,.38,.06)],.012,m['bone'],r)

def niche(r,m):
    box('Broken ossuary sill',(0,0,.065),(1.12,.66,.13),m['stone'],r,.025)
    box('Recess darkness',(0,.20,.27),(.77,.05,.38),m['dark'],r)
    for x in [-.45,.45]:
        for z in [.22,.42]:box('Chipped jamb',(x,.17,z),(.20,.27,.18),m['edge' if z==.42 else 'stone'],r,.025)
    # Truncated Romanesque arch with missing right voussoirs.
    for i in range(7):
        a=math.pi*i/8+.2
        ob=box('Arch voussoir',(.41*math.cos(a),.18,.45+.31*math.sin(a)),(.19,.29,.17),m['stone'],r,.018);ob.rotation_euler.y=a-math.pi/2
    skull(r,m,(-.20,-.07,.14),-.15,.82);skull(r,m,(.15,-.03,.14),.2,.72)
    for i in range(3):
        ob=box('Collapsed masonry',(.38-i*.22,-.29,.14),(.22,.22,.17),m['edge'],r,.018);ob.rotation_euler=(.12,.3,i*.9)

def salt(r,m):
    rng=random.Random(45)
    for i in range(19):
        x,y=rng.uniform(-.48,.48),rng.uniform(-.40,.40);rad=rng.uniform(.08,.23)
        poly=[(x+rad*math.cos(a*math.tau/6),y+rad*.7*math.sin(a*math.tau/6)) for a in range(6)]
        slab('Overlapping salt lamina',poly,.002+(i%3)*.012,.018,m['salt' if i%3 else 'stone'],r)
    for i in range(8):shard('Salt tooth',(rng.uniform(-.4,.4),rng.uniform(-.28,.28),.03),.035,.065,m['salt'],r,i)

def crystals(r,m):
    for i,(x,y,h,rad) in enumerate([(-.08,.05,1.2,.15),(.19,.06,.75,.12),(-.27,-.08,.61,.11),(.11,-.21,.48,.13),(.02,.26,.59,.10)]):
        shard('Salt prism',(x,y,0),rad,h,m['salt'],r,i)
        # Thin emissive inclusions bounded by the mineral, no baked halo.
        shard('Cold luminous inclusion',(x+rad*.6,y-rad*.28,h*.30),rad*.16,h*.53,m['glow'],r,i+12)
    for i in range(5):shard('Basal shattered prism',(-.32+i*.15,-.20,.005),.075,.15,m['edge'],r,i)

def stalagmite(r,m):
    rng=random.Random(91);N=11;verts=[]
    for j,(z,rad) in enumerate([(0,.29),(.13,.26),(.55,.18),(1.12,.11),(1.55,.055),(1.8,.008)]):
        for i in range(N):
            a=i*math.tau/N;rr=rad*(.86+rng.random()*.22)
            verts.append((rr*math.cos(a)+.035*z,rr*math.sin(a)-.025*z,z))
    faces=[tuple(reversed(range(N)))]+[(j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i) for j in range(5) for i in range(N)]
    ob=mesh('Layered eroded speleothem',verts,faces,m['stone'],r,.005)
    ob.data.materials.append(m['salt'])
    for f in ob.data.polygons:
        if f.index%11 in [2,7]:f.material_index=1
    for i in range(4):shard('Salt at foot',(-.21+i*.13,-.12,.01),.05,.12,m['salt'],r,i)

def column(r,m):
    # A fallen, fluted shaft: local cylinder z rotates onto the floor.
    q=C.empty('Fallen column axis');q.parent=r;q.location=(0,0,.245);q.rotation_euler.y=math.pi/2;q.rotation_euler.z=.17
    verts=[];N=40
    for j,z in enumerate([-.56,-.49,.43,.56]):
        for i in range(N):
            a=i*math.tau/N;rad=.21 if i%4 in [0,3] else .176
            verts.append((rad*math.cos(a),rad*math.sin(a),z+(.024*math.sin(i*2.4) if j in [0,3] else 0)))
    faces=[tuple(reversed(range(N))),tuple(range(3*N,4*N))]+[(j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i) for j in range(3) for i in range(N)]
    mesh('Broken fluted shaft',verts,faces,m['edge'],q,.004)
    for z in [-.45,-.38]:cyl('Carved collar',(0,0,z),.25,.055,m['stone'],q,24)
    for i in range(4):shard('Stone spall',(-.37+i*.2,-.28,.01),.09,.09,m['stone'],r,i)

def lantern(r,m):
    slab('Octagonal socket',[(.22*math.cos(i*math.tau/8),.22*math.sin(i*math.tau/8)) for i in range(8)],0,.10,m['stone'],r)
    rod('Forged pole',(0,0,.08),(0,0,1.62),.026,m['iron'],r)
    for z in [.17,.23,1.43]:cyl('Bronze binding',(0,0,z),.044,.045,m['bronze'],r,8)
    rod('Crooked gallows',(0,0,1.58),(.20,0,1.93),.025,m['iron'],r)
    rod('Suspension',(.20,0,1.93),(.29,0,1.88),.018,m['bronze'],r)
    for z in [1.38,1.84]:cyl('Lantern crown',(.27,0,z),.15,.055,m['bronze'],r,6,r2=.10)
    for i in range(4):
        a=i*math.tau/4;rod('Iron cage',(.27+.12*math.cos(a),.12*math.sin(a),1.4),(.27+.12*math.cos(a),.12*math.sin(a),1.83),.012,m['iron'],r)
    shard('Suspended crystal',(.27,0,1.42),.085,.36,m['glow'],r)
    shard('Spear finial',(.20,0,1.93),.038,.07,m['bronze'],r)

def lid(r,m):
    # Two irregular fracture faces, six-sided anthropoid lid and relief effigy.
    slab('Fractured lid left',[(-.32,-.66),(-.35,-.48),(-.28,.56),(-.17,.66),(-.03,.66),(-.05,.18),(.015,-.08),(-.07,-.29),(-.035,-.66)],.015,.105,m['edge'],r)
    slab('Fractured lid right',[(.008,-.66),(.31,-.66),(.35,-.48),(.28,.56),(.17,.66),(.005,.66),(-.012,.18),(.055,-.08),(-.025,-.29)],.015,.10,m['stone'],r)
    for x in [-.25,.25]:rod('Worn raised border',(x,-.53,.13),(x,.48,.13),.018,m['edge'],r)
    C.sphere('Funerary relief head',(.08,.36,.14),(.085,.11,.035),m['edge'],r)
    slab('Effigy shroud',[(.02,.23),(.20,.18),(.17,-.38),(.06,-.48),(.045,-.09)],.12,.026,m['edge'],r)
    for y in [-.33,-.24,-.15]:rod('Incised shroud fold',(.06,y,.15),(.16,y+.05,.15),.008,m['stone'],r)

BUILDERS=dict(zip(WEIGHTS,[bones,niche,salt,crystals,stalagmite,column,lantern,lid]))

def build():
    from PIL import Image
    OUT.mkdir(parents=True,exist_ok=True);SRC.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    cel.install('prop',keep_black_emission=False)
    only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else None
    for n in WEIGHTS:
        if only and n!=only:continue
        s=rig.create_rig('MAP',(320,320));cel.setup_scene()
        r=C.empty(n);m=mats();m['glow']=C.material('Salt light BFF4FF',(.521,.905,1.0),0,.4,1)
        BUILDERS[n](r,m);bpy.context.view_layer.update()
        # TOP decal helper projects mesh geometry; include ribs by converting curves.
        for ob in list(r.children_recursive):
            if ob.type=='CURVE':
                bpy.ops.object.select_all(action='DESELECT');ob.select_set(True)
                bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH')
        deps=bpy.context.evaluated_depsgraph_get();pts=[]
        for ob in r.children_recursive:
            if ob.type not in {'MESH','CURVE'}:continue
            ev=ob.evaluated_get(deps);geo=ev.to_mesh();pts.extend(ev.matrix_world@v.co for v in geo.vertices);ev.to_mesh_clear()
        env=[max(p[i] for p in pts)-min(p[i] for p in pts) for i in (0,1)]
        center=Vector(tuple((max(p[i] for p in pts)+min(p[i] for p in pts))/2 for i in (0,1))+(0,))
        r.location-=center;bpy.context.view_layer.update()
        path=OUT/(n+'.png');rig.render_frame(path)
        if n not in EMIT:(OUT/(n+'_e.png')).unlink(missing_ok=True)
        # Exact alpha bounding box plus four pixels on every side; shared pass rectangle.
        with Image.open(path) as im:b=im.getchannel('A').getbbox()
        rect=(b[0]-4,b[1]-4,b[2]+4,b[3]+4)
        assert min(rect[:2])>=0 and max(rect[2:])<=320
        for suffix in ['','_n']+(['_e'] if n in EMIT else []):
            p=OUT/(n+suffix+'.png')
            with Image.open(p) as im:cropped=im.crop(rect)
            cropped.save(p,optimize=True,compress_level=9)
        work=SRC/('f4p_'+n+'_normals')
        if work.exists():
            for cache in work.glob('*_n.png'):cache.unlink()
        cel.quantize_normal_files([OUT/(n+'_n.png')],work=work)
        bpy.context.window.scene=s
        check=dict(name=n,foot=[160-rect[0],160-rect[1]],size=[rect[2]-rect[0],rect[3]-rect[1]],
                   envelope=[round(x,5) for x in env],height_u=round(max(p.z for p in pts),5),rig='MAP',px_per_u=90.51,
                   yaw=45,elevation=30,profile='prop',shadow_rig='top' if n in SHADOWS else None)
        (SRC/('f4p_'+n+'_check.json')).write_text(json.dumps(check,indent=2))
        # Save the contractual cropped camera as well as the construction geometry.
        rig.set_frame(tuple(check['size']),'MAP')
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector(((rect[0]+rect[2])/2/rig.R-160/rig.R,(160-(rect[1]+rect[3])/2)/rig.R,0))
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('f4p_'+n+'.blend')))
        if n in SHADOWS:
            sun=bpy.data.objects['Sun_chaud_haut_gauche'];rot=sun.rotation_euler.copy()
            rig.create_rig('TOP',(512,512),reset=False);cel.setup_scene();sun.rotation_euler=rot
            rig.render_shadow_decal(r,OUT/(n+'_shadow.png'))
        print('F4P DONE '+n,flush=True)
    if all((SRC/('f4p_'+n+'_check.json')).exists() for n in WEIGHTS):
        props=[]
        for n,w in WEIGHTS.items():
            c=json.loads((SRC/('f4p_'+n+'_check.json')).read_text())
            props.append(dict(name=n,weight=w,foot=c['foot'],px_per_u=90.51,fade=n in {'stalagmite','crystal_lantern'},**({'shadow_rig':'top'} if n in SHADOWS else {})))
        (OUT/'props.json').write_text(json.dumps(dict(density=.05,props=props),indent=2)+'\n')
    print('F4P BUILD COMPLETE',flush=True)

if __name__=='__main__':build()
