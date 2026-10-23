"""CD3 presentation pipeline. Background only; no gameplay exports. Reuses ash-lord PBR and CREA."""
import sys, math, random
from pathlib import Path
sys.dont_write_bytecode=True
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/monsters'))
from ash_lord_build import worn, mesh, plate, rod
sys.path.insert(0,str(ROOT/'art/tools/iso'))
import iso_rig
random.seed(73)
OUT=ROOT/'art/tools/characters'

def rgb(h):
    a=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in a)+(1,)
def emit(name,h,power=1):
    m=bpy.data.materials.new(name);m.diffuse_color=rgb(h);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=rgb(h);p.inputs['Emission Color'].default_value=rgb(h);p.inputs['Emission Strength'].default_value=power
    return m

def empty(n):
    o=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(o);return o

def cube(n,p,sc,ma,pa=None,b=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=n;o.scale=sc;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.parent=pa;o.data.materials.append(ma)
    if b:
        mod=o.modifiers.new('Worn forged edges','BEVEL');mod.width=b;mod.segments=3;o.modifiers.new('Normals','WEIGHTED_NORMAL')
    return o

def ell(n,p,sc,ma,pa=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=1,location=p);o=bpy.context.object;o.name=n;o.scale=sc;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.parent=pa;o.data.materials.append(ma)
    for f in o.data.polygons:f.use_smooth=True
    return o

def tube(n,pts,r,ma,pa=None):
    c=bpy.data.curves.new(n,'CURVE');c.dimensions='3D';c.resolution_u=3;c.bevel_depth=r;c.bevel_resolution=2
    s=c.splines.new('BEZIER');s.bezier_points.add(len(pts)-1)
    for p,co in zip(s.bezier_points,pts):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    o=bpy.data.objects.new(n,c);bpy.context.collection.objects.link(o);o.parent=pa;o.data.materials.append(ma);return o

def loft(n,levels,ma,pa,N=32,rough=0):
    vs=[]
    for k,(z,xr,yr,cy) in enumerate(levels):
        for j in range(N):
            t=j*math.tau/N;d=1+rough*(.6*math.sin(t*7+k*.6)+.4*math.cos(t*11-k))
            vs.append((xr*math.sin(t)*d,cy-yr*math.cos(t)*d,z+rough*.08*math.sin(t*5)))
    fs=[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(len(levels)-1) for j in range(N)]
    fs += [tuple(range(N-1,-1,-1)),tuple(range((len(levels)-1)*N,len(levels)*N))]
    o=mesh(n,vs,fs,ma,pa)
    for f in o.data.polygons:f.use_smooth=True
    return o

def torus(n,p,major,minor,ma,pa=None,rot=(0,0,0),sc=(1,1,1)):
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=p,major_radius=major,minor_radius=minor,rotation=rot);o=bpy.context.object;o.name=n;o.parent=pa;o.scale=sc;o.data.materials.append(ma)
    for f in o.data.polygons:f.use_smooth=True
    return o

def avare():
    root=empty('AVARE — coffre intégré, chaîne articulée');skin=worn('Chair cireuse crevassée','51463B','AA947B',0,.74);leather=worn('Cuir gras craquelé','17191A','493A2C',0,.51);iron=worn('Fonte piquée','151A1C','4A4944',.72,.58);wood=worn('Chêne noir rainuré','171815','403326',0,.83);brass=worn('Laiton ancien','443A25','A8946E',.72,.55);gold=emit('Unique accent — or F2C14E','F2C14E',.9);dark=worn('Cavités','080D12','171A1B',0,.9)
    for x,z in [(-.205,.13),(.205,.13)]:
        cube('Botte de fonte à bout carré',(x,-.08,z),(.235,.40,.21),iron,root,.035)
        for i in range(3):cube('Plaque de cou-de-pied',(x,-.22+i*.08,.23),(.235,.045,.032),iron,root,.008)
        loft('Pantalon lourd',[(.2,.105,.11,0),(.46,.12,.12,.01),(.72,.14,.13,0)],leather,root).location.x=x
    loft('Manteau cintré / pans lourds',[(.36,.37,.24,.04),(.42,.40,.26,.02),(.72,.35,.24,0),(1.02,.35,.21,0),(1.17,.38,.19,.015),(1.23,.26,.15,.02)],leather,root,rough=.035)
    for x in [-1,1]:
        plate('Revers effilé',[(x*.08,1.16),(x*.29,1.18),(x*.21,.86),(x*.04,.96)],-.225,.035,leather,root)
    for z in [.56,.68,.80,.92]:ell('Bouton terne',(.035,-.257,z),(.018,.012,.018),brass,root)
    belt=torus('Ceinture affaissée',(0,0,.78),.34,.033,leather,root,sc=(1,.72,1));cube('Boucle de ceinture',(.10,-.272,.78),(.13,.035,.09),brass,root)
    for x in [-.32,.30]:
        ell('Bourse cousue',(x,-.11,.65),(.105,.105,.15),leather,root)
        for j in range(7):tube('Couture poissée',[(x-.06+j*.02,-.20,.60),(x-.055+j*.02,-.205,.62)],.003,brass,root)
    head_start=set(bpy.context.scene.objects)
    ell('Cou',(.0,.01,1.28),(.085,.08,.12),skin,root)
    loft('Crâne décharné',[(1.28,.055,.062,-.035),(1.32,.084,.080,-.02),(1.41,.10,.09,0),(1.51,.105,.10,.013),(1.59,.075,.075,.025),(1.61,.025,.035,.03)],skin,root,N=28,rough=.04)
    for x in [-.052,.052]:
        ell('Arcade dure',(x,-.085,1.48),(.046,.013,.008),skin,root)
        cube('Oeil plissé',(x,-.105,1.46),(.035,.008,.006),dark,root,.002)
        tube('Sillon naso-labial',[(x*.5,-.103,1.43),(x*.8,-.106,1.39),(x,-.09,1.36)],.002,skin,root)
    ell('Nez busqué',(0,-.113,1.423),(.021,.033,.041),skin,root)
    tube('Bouche serrée',[(-.034,-.09,1.342),(0,-.105,1.35),(.032,-.093,1.342)],.002,dark,root)
    for x in [-.109,.109]:ell('Oreille',(x,.007,1.44),(.018,.022,.042),skin,root)
    for i in range(7):tube('Cheveux rares plaqués',[(-.085+i*.027,.025,1.565),(-.08+i*.025,.08,1.55),(-.06+i*.02,.10,1.47)],.004,iron,root)
    headparts=set(bpy.context.scene.objects)-head_start
    for ob in headparts:
        if ob.type=='MESH':
            for v in ob.data.vertices:
                world=ob.location+v.co;world.x*=.89;world.y*=.89;world.z=1.31+(world.z-1.31)*.80;v.co=world-ob.location
        elif ob.type=='CURVE':
            for spl in ob.data.splines:
                for v in spl.bezier_points:
                    for attr in ['co','handle_left','handle_right']:
                        co=getattr(v,attr).copy();co.x*=.89;co.y*=.89;co.z=1.31+(co.z-1.31)*.80;setattr(v,attr,co)
    for node in skin.node_tree.nodes:
        if node.type=='BUMP':node.inputs['Strength'].default_value=.10;node.inputs['Distance'].default_value=.004
    arm=empty('Bras droit — geste de Faillite');arm.parent=root
    for sign,pa in [(-1,root),(1,arm)]:
        pts=[(sign*.32,.02,1.12),(sign*.45,-.035,.91),(sign*.46,-.16,.72)]
        tube('Manche cassée',pts,.105,leather,pa)
        for k in range(4):tube('Plis de manche',[(sign*.42-.07,-.075,.92-k*.035),(sign*.43,-.13,.91-k*.035),(sign*.44+.07,-.07,.92-k*.035)],.008,leather,pa)
        ell('Main noueuse',(sign*.46,-.17,.69),(.072,.06,.10),skin,pa)
        for j in range(4):tube('Doigts aux phalanges',[(sign*.46-.043+j*.027,-.205,.71),(sign*.46-.043+j*.027,-.23,.66),(sign*.46-.04+j*.027,-.19,.64)],.012,skin,pa)
    safe=empty('Coffre-fort traîné');safe.parent=root;safe.location=(-.86,.49,.02);safe.rotation_euler.z=-.22
    cube('Caisse chêne massif',(0,0,.34),(.64,.53,.64),wood,safe,.018)
    for j in range(6):
        x=-.268+j*.107
        cube('Planche de porte',(x,-.277,.34),(.095,.034,.57),wood,safe,.005)
        tube('Fil du bois',[(x-.025,-.298,.10),(x-.015,-.301,.29),(x-.025,-.298,.57)],.002,iron,safe)
    for x in [-.29,.29]:
        cube('Cerclage frontal vertical',(x,-.30,.34),(.075,.045,.67),iron,safe)
        cube('Cerclage arrière',(x,.28,.34),(.075,.05,.67),iron,safe)
    for z in [.065,.61]:
        cube('Traverse fer forgé',(0,-.30,z),(.66,.05,.065),iron,safe)
        for x in [-.30,.30]:cube('Cerclage retour',(x,0,z),(.06,.59,.065),iron,safe)
    for x in [-.29,.29]:
        for z in [.08,.23,.45,.60]:ell('Rivet maté',(x,-.335,z),(.018,.012,.018),brass,safe)
    torus('Anse du cadenas',(0,-.34,.43),.062,.014,brass,safe,rot=(math.pi/2,0,0));cube('Cadenas de laiton',(0,-.36,.345),(.145,.07,.125),brass,safe);cube('Trou de serrure',(0,-.398,.35),(.012,.006,.029),dark,safe,.001)
    tube('Fuite entre les planches',[(-.18,-.303,.54),(-.18,-.307,.30),(-.22,-.31,.16)],.006,gold,safe)
    tube('Joint incandescent sous la caisse',[(-.25,-.31,.036),(.10,-.31,.036),(.28,-.29,.05)],.007,gold,safe)
    a=Vector((-.46,-.16,.67));b=Vector((-.85,.22,.50))
    for i in range(20):
        t=i/19;p=a.lerp(b,t);p.z-=.28*math.sin(t*math.pi)
        torus('Maillon forgé %02d'%i,p,.031,.008,iron,root,rot=(math.pi/2,(i%2)*math.pi/2,.4),sc=(.76,1.25,1))
    for i in range(30):
        x=-.8+random.uniform(-.32,.32);y=.1+random.random()*1.05
        coin=torus('Pièce qui fuit',(x,y,.018+random.random()*.018),.023,.009,gold,root);coin.rotation_euler=(random.random()*.3,random.random()*.3,0)
    return root,arm,[("CUIR",'493A2C'),('FONTE','2B2A29'),('CHÊNE','3F2B1E'),('LAITON','A8946E'),('CHAIR','AA947B'),('OR','F2C14E')]

def bourbe():
    root=empty('BOURBE — 1.30 u');mud=worn('Argile humide striée','171E29','2B3340',0,.34);rootmat=worn('Racines tendons','242B24','535346',0,.81);moss=worn('Mousse éparse','28332A','5B6B4F',0,.9);bronze=worn('Bronze vert-de-gris','314B43','5F8F80',.7,.55);edge=worn('Tranches bronze ancien','473D29','A8946E',.65,.58);light=emit('Unique feu follet — 8DBBA8','8DBBA8',.85);dark=worn('Cavité profonde','060D12','111A20',0,.96)
    pieces=[]
    def cl(n,p,sc):
        o=ell(n,p,sc,mud,root);pieces.append(o);return o
    cl('Bassin',(.0,.025,.43),(.31,.22,.26));cl('Cage argile',(-.025,.025,.77),(.33,.21,.29));cl('Dos voûté',(.0,.115,.97),(.23,.18,.22));cl('Tête sans yeux',(-.025,0,1.16),(.12,.12,.14))
    for sign in [-1,1]:
        cl('Cuisse',(sign*.18,.03,.29),(.135,.15,.23));cl('Cheville',(sign*.21,-.015,.11),(.10,.12,.15));cl('Pied ancré',(sign*.21,-.105,.055),(.15,.23,.067))
        cl('Épaule',(sign*.31,.015,.91),(.15,.16,.18));cl('Bras en vase',(sign*.39,-.025,.73),(.105,.12,.22));cl('Avant bras lourd',(sign*.43,-.12,.54),(.115,.14,.18));cl('Paume aplatie',(sign*.45,-.16,.40),(.13,.08,.13))
        for j in range(3):cl('Doigt de glaise',(sign*.45-.07+j*.065,-.18,.29),(.028,.037,.11))
    bpy.ops.object.select_all(action='DESELECT')
    for o in pieces:o.select_set(True)
    bpy.context.view_layer.objects.active=pieces[0];bpy.ops.object.join();body=bpy.context.object;body.name='Vase continue sculptée';mod=body.modifiers.new('Fusion argile','REMESH');mod.mode='VOXEL';mod.voxel_size=.021;bpy.ops.object.modifier_apply(modifier=mod.name)
    sm=body.modifiers.new('Lissage humide','SMOOTH');sm.factor=.9;sm.iterations=3;bpy.ops.object.modifier_apply(modifier=sm.name)
    tex=bpy.data.textures.new('Érosion stratifiée',type='CLOUDS');tex.noise_scale=.067;d=body.modifiers.new('Croûte et érosion','DISPLACE');d.texture=tex;d.strength=.025;d.texture_coords='GLOBAL'
    # Deep framed sternum, deliberately no round eyes.
    ell('Ombre de la cavité',(-.025,-.193,.79),(.125,.047,.175),dark,root)
    for sign in [-1,1]:
        tube('Bord déchiré du sternum',[(sign*.07,-.22,.94),(sign*.14,-.23,.84),(sign*.11,-.225,.67)],.024,mud,root)
        flame=loft('Langue de feu follet',[(.70,.015,.012,-.246),(.74,.026,.012,-.251),(.80,.013,.009,-.25),(.875,.001,.001,-.24)],light,root,N=9);flame.location.x=sign*.034-.025;flame.rotation_euler.y=sign*.13
    # Shattered rings, elliptical and interrupted at their missing sections.
    for z,rx,ry in [(.49,.30,.235),(.96,.30,.23),(1.16,.125,.115)]:
        for start,end in [(.15,2.7),(3.1,5.9)]:
            pts=[(rx*math.sin(t),-ry*math.cos(t),z+.035*math.sin(t*2)) for t in [start+(end-start)*j/22 for j in range(23)]]
            tube('Bande de bronze brisée',pts,.026,bronze,root)
            for t in [start+.15,end-.15]:ell('Rivet de cerclage',(rx*math.sin(t),-ry*math.cos(t),z+.035*math.sin(t*2)),(.014,.014,.014),edge,root)
    for j in range(28):
        t=j*2.399;side=-1 if j%2 else 1;x=side*(.17+.16*random.random());z=.32+random.random()*.71
        tube('Racine tendon',[(x*.65,.01,z+.17),(x,-.14,z),(x*1.2,-.12,z-.18)],.004+random.random()*.005,rootmat,root)
    for j in range(38):
        x=random.uniform(-.27,.27);z=random.uniform(.33,1.02)
        ell('Dépôt de mousse',(x,-.18+abs(x)*.10,z),(.025+random.random()*.02,.012,.012+random.random()*.025),moss,root)
    for j in range(9):
        tube('Strates du front',[(-.105,-.062,1.14+j*.012),(-.025,-.128,1.145+j*.012),(.07,-.071,1.14+j*.011)],.004,rootmat,root)
    # Actual 15% volume companion: cube-root of 0.15, compressed into a crawling shape.
    motte=empty('Motte — volume 15 pour cent / hauteur .43 u');motte.parent=root;motte.location=(.79,-.10,0)
    loft('Motte arrachée',[(.02,.22,.16,0),(.12,.26,.17,0),(.25,.18,.13,.025),(.36,.12,.09,.025),(.43,.025,.03,.02)],mud,motte,N=24,rough=.15)
    ell('Déchirure motte',(0,-.155,.19),(.095,.025,.095),dark,motte)
    tube('Même feu follet motte',[(-.04,-.18,.15),(0,-.19,.23),(.025,-.16,.28)],.012,light,motte)
    for sign in [-1,1]:
        tube('Patte racine de motte',[(sign*.14,-.03,.23),(sign*.25,-.13,.10),(sign*.28,-.23,.018)],.022,rootmat,motte)
    tube('Bronze solidaire motte',[(-.18,0,.22),(-.12,-.14,.26),(.07,-.15,.27),(.16,-.06,.24)],.017,bronze,motte)
    torus('Anneau allié motte',(.79,-.10,.012),.31,.007,light,root)
    return root,motte,[('ARGILE','2B3340'),('RACINES','535346'),('MOUSSE','5B6B4F'),('BRONZE','5F8F80'),('LAITON','A8946E'),('FOLLET','8DBBA8')]

def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
def area(n,p,power,color,size):
    d=bpy.data.lights.new(n,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size;o=bpy.data.objects.new(n,d);bpy.context.collection.objects.link(o);o.location=p;aim(o,(0,0,.7))
def render(path,w,h,target,scale,az=-25,elev=12,fit=False):
    s=bpy.context.scene;c=s.camera;t=Vector(target);a=math.radians(az);e=math.radians(elev);c.location=t+Vector((math.sin(a)*8,-math.cos(a)*8,math.tan(e)*8));aim(c,t);c.data.type='ORTHO';c.data.ortho_scale=scale;c.data.sensor_fit='HORIZONTAL';s.render.resolution_x=w;s.render.resolution_y=h;s.render.resolution_percentage=100;s.render.filepath=str(path)
    if fit:
        c.data.ortho_scale=4.0;s.render.resolution_x=2400;s.render.resolution_y=2650
    bpy.ops.render.render(write_still=True)
    if fit:
        from PIL import Image
        with Image.open(path) as im:
            cut=im.crop(im.getchannel('A').getbbox());cut.thumbnail((w-50,h-60),Image.Resampling.LANCZOS)
            canvas=Image.new('RGBA',(w,h),(0,0,0,0));canvas.alpha_composite(cut,((w-cut.width)//2,(h-cut.height)//2));canvas.save(path)

def board(id,title,root,pose,palette):
    global CHAR_ROOT
    CHAR_ROOT=root
    s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=24;s.render.image_settings.file_format='PNG';s.render.film_transparent=False;s.render.threads_mode='FIXED';s.render.threads=8;s.view_settings.view_transform='Standard';s.world.color=(.04,.05,.07)
    world=s.world;world.use_nodes=True;world.node_tree.nodes.get('Background').inputs[0].default_value=(.022,.032,.048,1);world.node_tree.nodes.get('Background').inputs[1].default_value=.45
    area('Key chaude',(-3,-4,6),500,(1,.76,.55),4);area('Fill froide',(4,-2,3),240,(.46,.62,.85),3);area('Liseré',(.5,4,4),750,(.56,.73,.88),3)
    bpy.ops.object.camera_add();s.camera=bpy.context.object
    floor=cube('Studio sol',(0,0,-.055),(200,200,.1),worn('Fond gris bleu uni','202C3A','202C3A',0,.96),b=.0)
    s['CD3']='Présentation uniquement';s['height_u']=1.61 if id=='avare' else 1.30;s['companion_volume_fraction']=.15 if id=='bourbe' else 0
    s.camera.location=(-3,-7,2.4);aim(s.camera,(0,0,.75));s.camera.data.type='ORTHO';s.camera.data.ortho_scale=3.1
    s.render.resolution_x=2400;s.render.resolution_y=1350
    blend=ROOT/f'art/blender/characters/cd_{id}.blend';blend.parent.mkdir(exist_ok=True,parents=True);bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    floor.hide_render=True;s.render.film_transparent=True
    paths=[]
    def shot(label,w,h,t,scale,az=-25,el=12):
        p=OUT/f'cd_{id}_{label}.png';render(p,w,h,t,scale,az,el,fit=(label=='hero'));paths.append((label,p))
    H=1.61 if id=='avare' else 1.30
    shot('hero',960,1060,(-.35 if id=='avare' else .23,0,H*.48),1.90 if id=='avare' else 1.72,-28,12)
    for label,az in [('face',0),('profil',90),('dos',180)]:shot(label,390,390,(-.15 if id=='avare' else .13,.05,H*.50),2.15 if id=='avare' else 1.85,az,8)
    if id=='avare':details=[('main',(-.85,.45,.35),.87),('tete',(0,-.015,1.45),.42),('or',(-.83,.47,.08),.75)]
    else:details=[('main',(-.025,-.13,.81),.49),('tete',(-.025,0,1.15),.37),('motte',(.79,-.1,.21),.73)]
    for label,t,sc in details:shot(label,390,300,t,sc,-15,14)
    # Pose is a real alternate staged model state, plus signature spell geometry.
    fx=empty('Pose de sort présentation')
    accent=next(m for m in bpy.data.materials if m.name.startswith('Unique'))
    if id=='avare':
        pose.rotation_euler.y=-.65;pose.rotation_euler.x=-.35
        for j in range(38):
            t=j*2.399;r=.35+j*.022;torus('Faillite / pièces en explosion',(math.cos(t)*r,math.sin(t)*r,.18+j*.033),.026,.009,accent,fx,rot=(t,.7,t/2))
    else:
        root.scale.z=.58
        for r in [.35,.55,.8,1.04]:torus('Bourbier / rides de vase',(0,0,.015),r,.012,accent,fx,sc=(1,.8,1))
        for j in range(12):
            t=j*math.tau/12;tube('Racines du bourbier',[(.2*math.cos(t),.2*math.sin(t),.15),(.6*math.cos(t),.6*math.sin(t),.05),(1.03*math.cos(t),1.03*math.sin(t),.02)],.016,bpy.data.materials.get('Racines tendons'),fx)
    shot('sort',570,355,(0,0,.62 if id=='avare' else .29),2.85,-26,27)
    pose.rotation_euler=(0,0,0);root.scale.z=1
    for o in [fx,*fx.children_recursive]:o.hide_render=True
    # Exact native CREA rig, SE direction and original Ardent geometry, same world units.
    for o in list(s.objects):
        if o.type=='LIGHT':o.hide_render=True
    iso_rig.create_rig('CREA',(570,290),target=(.35,0,.45),reset=False)
    from boss_common import DIRECTIONS
    root.rotation_euler.z=DIRECTIONS['se'];root.location.x=-.66
    with bpy.data.libraries.load(str(ROOT/'art/blender/characters/ardent_iso.blend'),link=False) as (a,b):b.objects=a.objects
    loaded=[o for o in b.objects if o and o.type not in {'CAMERA','LIGHT'}]
    for o in loaded:
        s.collection.objects.link(o)
        if o.animation_data:o.animation_data_clear()
    tops=[o for o in loaded if o.parent not in loaded]
    for o in tops:o.location.x=1.1;o.rotation_euler.z=DIRECTIONS['se']
    bpy.context.view_layer.update()
    # C1 terrace tile, physically 1 u square projected as a 128x64 diamond.
    tilepath=ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png'
    floor.hide_render=True
    m=bpy.data.materials.new('C1 original terrace');m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');im=n.new('ShaderNodeTexImage');im.image=bpy.data.images.load(str(tilepath));im.interpolation='Linear';l.new(im.outputs['Color'],p.inputs['Base Color']);p.inputs['Roughness'].default_value=.82
    a=math.sqrt(.5)
    for x in range(-3,4):
        for y in range(-3,4):
            cx=(x-y)*a;cy=(x+y)*a
            ob=mesh('C1 exact 128x64 terrace',[(cx,cy+a,-.005),(cx+a,cy,-.005),(cx,cy-a,-.005),(cx-a,cy,-.005)],[(0,3,2,1)],m,None);uv=ob.data.uv_layers.new()
            for poly in ob.data.polygons:
                for li,co in zip(poly.loop_indices,[(.5,1),(0,.5),(.5,0),(1,.5)]):uv.data[li].uv=co
    # Keep studio lamps plus native CREA camera; use exact R without supersampling.
    for o in list(s.objects):
        if o.type=='LIGHT':o.hide_render=False
    s.render.resolution_x=570;s.render.resolution_y=290;s.camera.data.ortho_scale=570/iso_rig.R;s.render.resolution_percentage=100;s.render.film_transparent=False;s.render.filepath=str(OUT/f'cd_{id}_jeu.png');bpy.ops.render.render(write_still=True);paths.append(('jeu',OUT/f'cd_{id}_jeu.png'))
    make_layout(id,title,palette,dict(paths))

def make_layout(id,title,palette,paths):
    # Blender generates all typography, panels and colour chips. Pillow never draws.
    s=bpy.data.scenes.new('Planche CD3');bpy.context.window.scene=s;s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=8;s.render.resolution_x=2400;s.render.resolution_y=1350;s.render.resolution_percentage=100;s.view_settings.view_transform='Standard';s.world=bpy.data.worlds.new('Planche sombre');s.world.color=(.01,.01,.01)
    bpy.ops.object.camera_add(location=(1200,675,3000));s.camera=bpy.context.object;s.camera.data.type='ORTHO';s.camera.data.ortho_scale=2400;s.camera.data.clip_end=10000
    bg=emit('Board background','17212D',1);textmat=emit('Typography','D0D5D6',1);muted=emit('Secondary','81939C',1)
    def quad(n,x,y,w,h,ma,z=0):return mesh(n,[(x,1350-y-h,z),(x+w,1350-y-h,z),(x+w,1350-y,z),(x,1350-y,z)],[(0,1,2,3)],ma,None)
    quad('Background',0,0,2400,1350,bg,-2)
    font=bpy.data.fonts.load('C:/Windows/Fonts/segoeui.ttf')
    def text(body,x,y,size=20,mat=textmat):
        c=bpy.data.curves.new('Caption','FONT');c.body=body;c.font=font;c.size=size;c.space_character=1.1;o=bpy.data.objects.new(body,c);s.collection.objects.link(o);o.location=(x,1350-y,20);o.data.materials.append(mat)
    def panel(label,x,y,w,h):
        m=bpy.data.materials.new(label);m.use_nodes=True;n=m.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');em=n.new('ShaderNodeEmission');im=n.new('ShaderNodeTexImage');im.image=bpy.data.images.load(str(paths[label]));mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=rgb('17212D');m.node_tree.links.new(im.outputs['Alpha'],mix.inputs[0]);m.node_tree.links.new(im.outputs['Color'],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],em.inputs[0]);m.node_tree.links.new(em.outputs[0],out.inputs[0]);o=quad(label,x,y,w,h,m,1);uv=o.data.uv_layers.new()
        for f in o.data.polygons:
            for li,co in zip(f.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):uv.data[li].uv=co
    text('RAINFALL  /  CD3  /  ÉTUDE DE PERSONNAGE',60,143,15,muted)
    panel('hero',15,165,960,1060)
    for j,(label,caption) in enumerate([('face','FACE'),('profil','PROFIL'),('dos','DOS')]):panel(label,990+j*460,168,390,390);text(caption,1002+j*460,159,17,muted)
    labs=['main','tete','or' if id=='avare' else 'motte'];caps=['COFFRE / FERRURES' if id=='avare' else 'CAVITÉ / FEU FOLLET','VISAGE / MATIÈRE','OR QUI FUIT' if id=='avare' else 'MOTTE / MÊME ÉCHELLE']
    for j,(label,cap) in enumerate(zip(labs,caps)):panel(label,990+j*460,610,390,300);text(cap,1002+j*460,598,17,muted)
    panel('jeu',995,977,570,290);panel('sort',1715,957,570,355)
    text('EN JEU / SE / CREA 30° / R = 90,51 px/u',1002,950,17);text('ARDENT + '+id.upper()+' / ÉCHELLE 1:1 / SOL C1',1002,1293,15,muted);text('FAILLITE' if id=='avare' else 'BOURBIER / IMMERSION',1722,944,18)
    for j,(name,h) in enumerate(palette):
        x=60+j*148;ma=emit('Palette '+h,h,1);quad('Pastille '+name,x,1243,31,31,ma,4);text('#'+h,x+39,1264,15);text(name,x,1302,12,muted)
    text('CUIR GRAS / FONTE / OR SOUS PRESSION' if id=='avare' else 'ARGILE HUMIDE / RACINES / BRONZE ROMPU',60,1218,17,muted)
    text(id.upper(),58,76,51,muted);text(title,60,112,22,muted)
    s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/f'_cd_{id}.png');bpy.ops.render.render(write_still=True)
    print('PASS CD3 '+id+' 2400x1350',flush=True)

def run(id):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    root,pose,palette=avare() if id=='avare' else bourbe()
    board(id,"L'usurier des Terrasses" if id=='avare' else 'La mère-vase de la Mangrove',root,pose,palette)
