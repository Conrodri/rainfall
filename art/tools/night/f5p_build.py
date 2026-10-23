"""F5P / La Source. Blender geometry, shared MAP/TOP rigs and cel prop profile.
Usage: Blender --background --python this.py [-- --only rod|column|chapel|crystal_giant]
System Python: this.py --verify (Pillow checks / assembly only).
"""
from pathlib import Path
import sys, math, json, random
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'game/assets/sprites/props/source'
SRC=ROOT/'art/blender/props'
SPECS={'mother_rod_off':(512,512),'mother_rod_done':(512,512),'mother_rod_active':(4096,512),
       'column':(256,384),'chapel':(768,640),'crystal_giant':(384,512)}
FEET={'rod':[256,419.84],'column':[128,330],'chapel':[384,566],'crystal_giant':[192,435]}

def verify():
    from PIL import Image, ImageChops
    errors=[];counts={};boxes={}
    for name,size in SPECS.items():
        p=OUT/(name+'.png')
        if not p.exists():errors.append('missing '+name);continue
        im=Image.open(p).convert('RGBA');a=im.getchannel('A');boxes[name]=a.getbbox()
        if im.size!=size or not a.getbbox():errors.append(name+' size/empty')
        for suffix in ['_n']+(['_e'] if name not in ('column','mother_rod_off') else []):
            q=OUT/(name+suffix+'.png')
            if not q.exists():errors.append(q.name+' missing');continue
            other=Image.open(q).convert('RGBA')
            if other.size!=size or ImageChops.difference(a,other.getchannel('A')).getbbox():errors.append(name+suffix+' alpha/size')
            if suffix=='_n':
                cols={v[:3] for v in other.getdata() if v[3]>250};counts[name]=len(cols)
                if len(cols)>27:errors.append(name+' normal count '+str(len(cols)))
                if any(abs(math.sqrt(sum((v/127.5-1)**2 for v in rgb))-1)>.015 for rgb in cols):errors.append(name+' unit normals')
            elif not any(max(v[:3])>100 and v[3]>0 for v in other.getdata()):errors.append(name+' black emission')
        if name!='chapel':
            sh=Image.open(OUT/(name+'_shadow.png')).convert('RGBA')
            if sh.size!=(512,512) or not sh.getchannel('A').getbbox():errors.append(name+' shadow')
            if any(r!=g or g!=b for r,g,b,a0 in sh.getdata()):errors.append(name+' shadow gray')
        cell=512 if 'rod' in name else size[0]
        seen=set()
        for j in range(size[0]//cell):
            f=im.crop((j*cell,0,(j+1)*cell,size[1]));b=f.getchannel('A').getbbox()
            if not b or min(b[:2])<3 or b[2]>cell-3 or b[3]>size[1]-3:errors.append(name+' clipped '+str(j))
            key=f.tobytes()
            if key in seen:errors.append(name+' duplicate frame')
            seen.add(key)
    manifest=json.loads((OUT/'props.json').read_text())
    expected=[('chapel',[4,4]),('chapel',[46,4]),('chapel',[4,46]),('chapel',[46,46]),
              ('crystal_giant',[25,3]),('crystal_giant',[3,25]),('crystal_giant',[47,25])]
    if manifest['density']!=0 or manifest['props'] or [(p['name'],p['pos_u']) for p in manifest['fixed']]!=expected:errors.append('manifest')
    for p in manifest['fixed']:
        if p['foot']!=FEET[p['name']] or p['px_per_u']!=90.51:errors.append('fixed pivot')
    # One final sheet: native assets on actual biome ground, frames and approved references.
    board=Image.new('RGBA',(2048,1800),(22,27,31,255))
    ground=ROOT/'game/assets/sprites/terrain/source/iso/ground_a.png'
    if not ground.exists():ground=ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png'
    tile=Image.open(ground).convert('RGBA')
    for name,x,y in [('mother_rod_off',0,0),('mother_rod_done',512,0),('column',1024,0),('crystal_giant',1536,0),('chapel',0,540)]:
        im=Image.open(OUT/(name+'.png')).convert('RGBA')
        fx,fy=FEET['rod' if 'rod' in name else name];panel=Image.new('RGBA',(max(512,im.width),max(525,im.height)),(22,27,31,255))
        panel.alpha_composite(tile,(round(fx-tile.width/2),round(fy-tile.height/2)))
        panel.alpha_composite(im,(0,0));board.alpha_composite(panel,(x,y))
    act=Image.open(OUT/'mother_rod_active.png').convert('RGBA')
    for j in range(8):
        im=act.crop((j*512,0,j*512+512,512));im.thumbnail((256,256));board.alpha_composite(im,(j*256,1190))
    for j,name in enumerate(['mother_rod_done','crystal_giant','chapel']):
        im=Image.open(OUT/(name+'_e.png')).convert('RGBA');im.thumbnail((300,300));board.alpha_composite(im,(810+(j%3)*390,650))
    refs=['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png']
    for j,ref in enumerate(refs):
        im=Image.open(ROOT/ref).convert('RGBA')
        if j==3:im=im.crop((im.width//2,0,im.width,im.height))
        im.thumbnail((500,330));board.alpha_composite(im,(j*512,1460))
    board.convert('RGB').save(HERE/'_f5p_contact.png',optimize=True)
    report={'status':'FAIL' if errors else 'PASS','errors':errors,'normal_colors':counts,'bounds':boxes,'feet':FEET,
            'choices':['Inverted reliquary crown, downward thorns, linked iron chains, crystal tear',
                       'Broken ribbed sanctuary, salt altar, anatomical bone ex-votos',
                       'Faceted crystal with pale translucent laminae; no baked halo'],
            'column_reference':'Exact F5 block_a geometry loaded from its delivered Blender source'}
    (SRC/'f5p_validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print('F5P '+report['status']+(': '+str(errors) if errors else ': 6 sheets / 8 unique frames / finite normals / alpha / pivots / 7 fixed props'))
    return not errors

if '--verify' in sys.argv:sys.exit(0 if verify() else 1)
sys.path.insert(0,str(HERE))
# Existing production helpers and shared normal-alpha correction, no duplicated renderer.
from f4p_build import C,box,rod,cyl,ring,worn,mesh,rig,cel,shard,slab,skull
import f4p_build as shared
# Stable midpoint rounding after premultiplication: avoid 127/128 duplicates.
exec(compile(shared._normal_source.replace('enc.inputs[2].default_value = (.5, .5, .5)',
    'enc.inputs[2].default_value = (.5001, .5001, .5001)'), '<F5P stable normal midpoint>', 'exec'),cel.__dict__)
import bpy
from mathutils import Vector
from PIL import Image

def materials():
    m={k:worn('F5P '+k,a,b,metal,.7) for k,a,b,metal in [
        ('stone','283034','566468',0),('edge','424C4E','7C8989',0),('salt','67716E','B2B9AE',0),
        ('iron','202627','41494A',.65),('bronze','35433B','788271',.6),
        ('bone','575447','A6A18B',0),('dark','10171A','202A2F',0),('glass','617B80','C3E0DE',.1)]}
    # linear RGB of #BFF4FF. Only this hue emits in the entire lot.
    cyan=(.521,.905,1.0)
    for key,energy in [('glow',1.65),('faint',.48),('core',2.4)]:
        m[key]=C.material('F5P white cyan '+key,cyan,0,.22,energy)
        m[key]['rainfall_emissive']=True
    return m

def setup(size,foot,anchor=(0,0,0)):
    s=rig.create_rig('MAP',size);cel.setup_scene()
    # Pixel-exact contact, maintaining the shared 90.51 px/u projection.
    s.camera.location+=Vector(anchor)+s.camera.rotation_euler.to_matrix()@Vector(((size[0]/2-foot[0])/rig.R,(foot[1]-size[1]/2)/rig.R,0))
    return s

def save(n):
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('f5p_'+n+'.blend')))

def normals(paths,n):
    s=bpy.context.scene
    work=SRC/('f5p_'+n+'_normals')
    if work.exists():
        for p in work.glob('*_n.png'):p.unlink()
    cel.quantize_normal_files(paths,work=work)
    bpy.context.window.scene=s

def triangulate_curves(r):
    bpy.ops.object.select_all(action='DESELECT')
    curves=[o for o in r.children_recursive if o.type=='CURVE']
    for o in curves:o.select_set(True)
    if curves:
        bpy.context.view_layer.objects.active=curves[0]
        bpy.ops.object.convert(target='MESH')

def shadow(r,n):
    s=bpy.context.scene;sun=bpy.data.objects['Sun_chaud_haut_gauche'];rotation=sun.rotation_euler.copy()
    rig.create_rig('TOP',(512,512),reset=False);cel.setup_scene()
    # Steep sanctuary sun: full projection fits centred 4u TOP decal, contact at centre.
    ray=rotation.to_matrix()@Vector((0,0,-1));ray=Vector((ray.x*.30,ray.y*.30,ray.z))
    sun.rotation_euler=ray.to_track_quat('-Z','Y').to_euler()
    rig.render_shadow_decal(r,OUT/(n+'_shadow.png'))

def tear(n,p,rad,h,mat,r):
    # Pear-cut falling drop with long upper point, six planes and a pointed lower tip.
    x,y,z=p;N=8;v=[(x,y,z)]
    for zz,rr in [(.18,.66),(.38,1),(.60,.78)]:
        for i in range(N):
            a=i*math.tau/N;v.append((x+rad*rr*math.cos(a),y+rad*rr*math.sin(a),z+h*zz))
    v.append((x,y,z+h));faces=[]
    for i in range(N):
        k=(i+1)%N;faces.append((0,1+k,1+i))
        for row in range(2):faces.append((1+row*N+i,1+row*N+k,1+(row+1)*N+k,1+(row+1)*N+i))
        faces.append((1+2*N+i,1+2*N+k,len(v)-1))
    return mesh(n,v,faces,mat,r,.001)

def column(r,m):
    cyl('Chipped octagonal plinth',(0,0,.10),1.0,.20,m['stone'],r,8)
    cyl('Recessed base moulding',(0,0,.25),.83,.13,m['edge'],r,12)
    cyl('Water carved torus',(0,0,.35),.66,.12,m['stone'],r,16)
    cyl('Fluted stone shaft',(0,0,1.28),.55,1.75,m['stone'],r,12,r2=.48)
    for j in range(12):
        a=j*math.tau/12
        rod('Flute arris',(.54*math.cos(a),.54*math.sin(a),.43),(.48*math.cos(a),.48*math.sin(a),2.14),.035,m['edge'],r)
    cyl('Capital neck',(0,0,2.16),.60,.16,m['edge'],r,12)
    for j in range(7):
        a=j*math.tau/8
        ob=box('Fractured capital tooth',(.51*math.cos(a),.51*math.sin(a),2.34),(.42,.37,.24 if j!=2 else .13),m['stone'],r,.025);ob.rotation_euler.z=a
    slab('Capital fracture',[(-.38,-.34),(.32,-.37),(.45,.14),(-.20,.42)],2.43,.07,m['edge'],r)
    for j in range(5):
        a=j*1.2
        shard('Salt scab',(.65*math.cos(a),.65*math.sin(a),.18),.07,.15,m['salt'],r,j)

def chapel(r,m):
    rng=random.Random(533)
    # 8 x 6 u footprint aligned to the screen, open towards arena centre.
    for x in range(8):
        for y in range(6):
            if (x,y) in [(0,0),(7,0),(0,5)]:continue
            box('Broken sanctuary paving',(x-3.5,y-2.5,.05),(.96,.96,.10),m['stone' if (x+y)%4 else 'edge'],r,.035)
    for side in [-1,1]:
        for bay in range(3):
            yy=-1.7+bay*1.8
            for level in range(5):
                box('Coursed apse masonry',(side*3.55,yy,.34+level*.42),(.62,1.7,.39),m['stone'],r,.035)
            box('Salted wall cap',(side*3.55,yy,2.28),(.76,1.73,.14),m['edge'],r,.025)
            box('Gothic buttress',(side*3.75,yy,1.3),(.42,.55,2.4),m['stone'],r,.045)
    # Wide pointed arch, fractured at apex, voussoirs genuinely separated.
    for side in [-1,1]:
        for level in range(5):
            box('Arch pier ashlar',(side*2.72,-2.35,.25+level*.43),(.58,.70,.40),m['edge' if level%3==0 else 'stone'],r,.028)
        for k in range(6):
            t=k/6;tn=(k+.88)/6
            a=(side*(2.72*(1-t)), -2.35, 2.20+1.55*math.sin(t*math.pi/2))
            b=(side*(2.72*(1-tn)), -2.35, 2.20+1.55*math.sin(tn*math.pi/2))
            ob=rod('Broken pointed arch voussoir',a,b,.28,m['stone' if k%2 else 'edge'],r)
        # Inner ribs and tethered anatomical ex-votos.
        C.tube('Gothic archivolt',[(side*2.35,-2.72,.2),(side*2.35,-2.72,2.1),(side*1.3,-2.72,3.05),(side*.25,-2.72,3.5)],.065,m['edge'],r)
    box('Drowned altar steps',(0,.9,.19),(3.7,2.2,.28),m['stone'],r,.055)
    box('Altar salt monolith',(0,1.1,.65),(2.8,1.25,.76),m['salt'],r,.065)
    box('Fractured mensa',(0,1.1,1.1),(3.15,1.5,.22),m['edge'],r,.035)
    for j in range(13):
        x=rng.uniform(-1.4,1.4);yy=rng.uniform(.47,1.75)
        shard('Salt altar accretion',(x,yy,1.2),rng.uniform(.04,.11),rng.uniform(.08,.3),m['salt'],r,j)
    for j,x in enumerate([-2.7,-2.35,2.35,2.7]):
        zz=1.1+(j%2)*.5
        C.tube('Ex voto iron thread',[(x,-2.72,2.5),(x+.05,-2.8,1.8),(x,-2.78,zz+.28)],.012,m['iron'],r)
        rod('Offered human long bone',(x,-2.8,zz),(x+.10,-2.8,zz+.34),.042,m['bone'],r)
        C.sphere('Bone epiphysis',(x+.10,-2.8,zz+.34),(.065,.048,.052),m['bone'],r)
    skull(r,m,(-.7,.4,1.23),.2,1.25);skull(r,m,(.78,.55,1.23),-.5,1.1)
    ring('Vigil iron aureole',(0,1.1,1.98),.40,.03,m['bronze'],r,(math.pi/2,0,0))
    tear('Single crystal vigil',(0,1.06,1.48),.13,.74,m['glow'],r)
    for j in range(9):
        x=rng.choice([-1,1])*rng.uniform(2.7,3.5);yy=rng.uniform(-2.75,2.7)
        ob=box('Fallen arch fragment',(x,yy,.17),(.40,.5,.30),m['edge'],r,.035);ob.rotation_euler.z=rng.random()*2

def giant(r,m):
    for i,(p,rad,h) in enumerate([((0,0,0),.48,3),((-.42,.05,.02),.28,1.9),((.46,.16,.02),.27,1.55),((.16,-.45,.01),.25,1.12)]):
        ob=shard('Giant rain quartz',p,rad,h,m['glass'],r,i+501)
        ob.rotation_euler.y=(-.10 if i==0 else .13*(i-1))
        # Long luminous laminae sit just inside the broad forward crystal facets.
        shard('Transmitted cyan heart',(p[0]+rad*.25,p[1]-rad*.75,p[2]+h*.12),rad*.22,h*.78,m['glow' if i else 'core'],r,i+11)
    for j in range(9):
        a=j*math.tau/9
        shard('Paroi basalt splinter',(.73*math.cos(a),.53*math.sin(a),0),.19,.24+(j%3)*.13,m['stone'],r,j)
    # Light-catching nonemissive facets retain depth without a painted glow.
    shard('Pale crystal cleavage',(-.21,-.27,.12),.13,2.08,m['salt'],r,81)

def mother(r,m):
    cyl('Submerged broken foundation',(0,0,.06),.98,.12,m['stone'],r,9)
    cyl('Socket salt crust',(0,0,.17),.68,.16,m['edge'],r,8)
    cyl('Black bronze mast',(0,.09,2.63),.135,4.74,m['bronze'],r,12,r2=.085)
    for z in [.36,.7,1.1,1.7,2.3,3.95,4.55,4.92]:
        cyl('Iron mast binding',(0,.09,z),.19,.11,m['iron'],r,12)
        for j in range(4):
            a=j*math.tau/4;C.sphere('Binding rivet',(.19*math.cos(a),.09+.19*math.sin(a),z),(.025,)*3,m['bronze'],r)
    for j in range(6):
        a=j*math.tau/6
        start=(.17*math.cos(a),.09+.17*math.sin(a),4.88)
        elbow=(.78*math.cos(a),.09+.78*math.sin(a),4.47)
        tip=(.58*math.cos(a),.09+.58*math.sin(a),3.38+(j%2)*.14)
        C.tube('Inverted crown black rib',[start,elbow,tip],.063,m['iron'],r)
        rod('Crown bronze ferrule',start,elbow,.037,m['bronze'],r)
        # Spear tapers downwards, a crown planted upside down in the lake.
        ob=cyl('Downward thorn',(tip[0],tip[1],tip[2]-.18),.005,.4,m['iron'],r,6,r2=.09)
    ring('Inverted crown girdle',(0,.09,4.43),.77,.045,m['bronze'],r)
    # Actual alternating chain links, asymmetric hanging lengths.
    for side in [-1,1]:
        for j in range(18 if side<0 else 14):
            z=4.4-j*.145;x=side*(.73+.16*math.sin(j*.16));yy=.05+.11*math.sin(j*.19)
            ring('Alternating forged chain link',(x,yy,z),.067,.014,m['iron' if j%4 else 'bronze'],r,(math.pi/2,0,(j%2)*math.pi/2))
    for a in [0,2.1,4.2]:
        C.tube('Drowned anchor brace',[(.15*math.cos(a),.15*math.sin(a),1.3),(.5*math.cos(a),.5*math.sin(a),.35),(.83*math.cos(a),.83*math.sin(a),.14)],.05,m['iron'],r)
    tear('White crystal tear',(0,-.29,2.65),.29,1.17,m['glass'],r)
    for j in range(3):
        a=j*math.tau/3
        C.tube('Crystal reliquary prong',[(.30*math.cos(a),-.29+.30*math.sin(a),2.88),(.36*math.cos(a),-.29+.36*math.sin(a),3.2),(.13*math.cos(a),-.29+.13*math.sin(a),3.76)],.025,m['bronze'],r)

def rod_fx(r,m,frame,ready=False):
    phase=math.tau*frame/8
    if ready:
        tear('Awakened crystal heart',(0,-.43,2.69),.16,1.04,m['glow'],r)
        for j in range(3):
            a=j*math.tau/3
            C.tube('Luminous water hairline',[(.80*math.cos(a),.80*math.sin(a),.12),(.35*math.cos(a),.35*math.sin(a),.31),(.17*math.cos(a),.17*math.sin(a),1.3)],.012,m['faint'],r)
        return
    amp=.16+.055*math.sin(phase)
    tear('Pulsing crystal heart',(0,-.44,2.68),amp,1.06,m['core' if frame%4<2 else 'glow'],r)
    for j in range(3):
        pts=[]
        for k in range(31):
            z=.12+k*.133;a=phase+j*math.tau/3+k*.28;rr=.83*(1-k/46)
            pts.append((rr*math.cos(a),rr*math.sin(a),z))
        C.tube('Ascending water helix',pts,.014 if j else .021,m['faint' if j else 'glow'],r)
    rng=random.Random(510+frame)
    for j in range(3):
        a=j*2.1+phase*.2;pts=[]
        for k in range(16):
            z=.35+k*.29;rr=.19+rng.uniform(-.07,.10)
            pts.append((rr*math.cos(a),.09+rr*math.sin(a),z))
        # Polyline lightning, no smooth painted bolt and no baked halo.
        for k in range(len(pts)-1):rod('Mast lightning fracture',pts[k],pts[k+1],.012,m['glow'],r)
    for j in range(7):
        a=phase+j*.91;z=.25+((j*.39+frame*.21)%2.6);rr=.72
        tear('Rising rain droplet',(rr*math.cos(a),rr*math.sin(a),z),.022,.09,m['faint'],r)

def remove_tree(r):
    for ob in list(r.children_recursive):bpy.data.objects.remove(ob,do_unlink=True)
    bpy.data.objects.remove(r,do_unlink=True)

def build():
    OUT.mkdir(parents=True,exist_ok=True);SRC.mkdir(parents=True,exist_ok=True)
    cel.install('prop',keep_black_emission=False)
    only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else None
    for n,fun in [('column',column),('chapel',chapel),('crystal_giant',giant)]:
        if only and only!=n:continue
        size=SPECS[n];anchor=(0,0,0)
        if n=='chapel':anchor=Vector((0,-2.35,0));anchor.rotate(__import__('mathutils').Euler((0,0,math.pi/4)))
        setup(size,FEET[n],anchor)
        f5=ROOT/'art/blender/terrain/f5_block_a.blend'
        if n=='column' and f5.exists():
            bpy.ops.wm.open_mainfile(filepath=str(f5))
            ss=rig.create_rig('MAP',size,reset=False);cel.setup_scene()
            ss.camera.location+=ss.camera.rotation_euler.to_matrix()@Vector((0,(FEET[n][1]-size[1]/2)/rig.R,0))
            roots=[o for o in ss.objects if o.type in {'EMPTY','MESH','CURVE'} and o.parent is None]
            r=C.empty('F5P column exact F5 block_a')
            for ob in roots:ob.parent=r
            r.rotation_euler.z=math.pi/4  # Same F5 model, diamond footprint fits the fixed foot=330.
        else:
            m=materials();r=C.empty('F5P '+n);fun(r,m)
        triangulate_curves(r)
        if n=='chapel':r.rotation_euler.z=math.pi/4
        cel.toon_materials('prop');rig.render_frame(OUT/(n+'.png'))
        normals([OUT/(n+'_n.png')],n);save(n)
        if n!='chapel':shadow(r,n)
        print('F5P DONE '+n,flush=True)
    if not only or only=='rod':
        setup((512,512),FEET['rod']);m=materials();r=C.empty('F5P mother rod');mother(r,m);triangulate_curves(r)
        cel.toon_materials('prop');rig.render_frame(OUT/'mother_rod_off.png');save('mother_rod')
        fx=C.empty('Ready water and crystal');rod_fx(fx,m,0,True);cel.toon_materials('prop')
        rig.render_frame(OUT/'mother_rod_done.png');remove_tree(fx)
        frame_paths=[]
        for j in range(8):
            fx=C.empty('Active water frame '+str(j));rod_fx(fx,m,j);cel.toon_materials('prop')
            p=SRC/('f5p_frame_%02d.png'%j);rig.render_frame(p);frame_paths.append(p);remove_tree(fx)
            print('F5P FRAME '+str(j),flush=True)
        for suffix in ['','_n','_e']:
            atlas=Image.new('RGBA',(4096,512))
            for j,p in enumerate(frame_paths):
                with Image.open(p.with_name(p.stem+suffix+'.png')) as im:atlas.paste(im,(j*512,0))
            atlas.save(OUT/('mother_rod_active'+suffix+'.png'),optimize=True,compress_level=9)
        normals([OUT/(n+'_n.png') for n in ['mother_rod_off','mother_rod_done','mother_rod_active']],'rod')
        shadow(r,'mother_rod_off')
        import shutil
        for n in ['done','active']:shutil.copyfile(OUT/'mother_rod_off_shadow.png',OUT/('mother_rod_'+n+'_shadow.png'))
    fixed=[]
    for pos in [[4,4],[46,4],[4,46],[46,46]]:fixed.append(dict(name='chapel',pos_u=pos,foot=FEET['chapel'],px_per_u=90.51,fade=True))
    for pos in [[25,3],[3,25],[47,25]]:fixed.append(dict(name='crystal_giant',pos_u=pos,foot=FEET['crystal_giant'],px_per_u=90.51,shadow_rig='top'))
    (OUT/'props.json').write_text(json.dumps(dict(density=0.0,props=[],fixed=fixed),indent=2)+'\n')
    print('F5P BUILD COMPLETE',flush=True)

if __name__=='__main__':build()
