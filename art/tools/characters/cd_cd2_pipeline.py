"""CD2 presentation sources only. Run either character wrapper in background Blender.
Reuses the validated Ardent lofts and Ash Lord layered PBR shaders.
All panel dimensions, rig calibration and poses are reproducible; no game writes.
"""
import sys, math, random
from pathlib import Path
sys.dont_write_bytecode=True
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from ardent_iso_build import worn, mesh, plate, rod, material, empty, bead, rings, soften
import iso_rig
random.seed(22)

def tube(name,pts,r,mat,parent=None):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=3
    p=c.splines.new('POLY');p.points.add(len(pts)-1)
    for v,co in zip(p.points,pts):v.co=(*co,1)
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=parent;c.materials.append(mat);return o

def segment(name,a,b,r1,r2,mat,par):
    d=Vector(b)-Vector(a);q=d.to_track_quat('Z','Y');verts=[];n=16
    for t,r in [(0,r1*.85),(.15,r1),(.55,(r1+r2)*.53),(.9,r2),(1,r2*.8)]:
        verts += [Vector(a)+d*t+q@Vector((r*math.cos(j*math.tau/n),r*.8*math.sin(j*math.tau/n),0)) for j in range(n)]
    faces=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(4) for j in range(n)]
    faces += [tuple(range(n-1,-1,-1)),tuple(range(4*n,5*n))]
    return soften(mesh(name,verts,faces,mat,par))

def torus(name,loc,major,minor,mat,par,rot=(0,0,0),scale=(1,1,1)):
    bpy.ops.mesh.primitive_torus_add(major_segments=28,minor_segments=8,major_radius=major,minor_radius=minor,location=loc,rotation=rot)
    o=bpy.context.object;o.name=name;o.parent=par;o.scale=scale;o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def chain(root,hot,iron,mode=False):
    pts=[]
    for i in range(105):
        t=i/104
        if mode:
            a=t*math.tau;v=(1.03*math.cos(a),.48+1.02*math.sin(a),.045)
        else:v=(.30+.28*math.sin(t*6.8),.1+t*1.6,.045)
        pts.append(Vector(v))
    for i,p in enumerate(pts):
        tangent=pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]
        o=torus('Forged copper trail link %03d'%i,p,.027,.007,hot if i%5 else iron,root,scale=(1,1.65,1))
        o.rotation_euler=tangent.to_track_quat('Y','Z').to_euler();o.rotation_euler.rotate_axis('Y',math.pi/2*(i%2))
    tube('Chain lead from spool',[(.34,.02,.89),(.4,.02,.55),(.41,.04,.22),pts[0]],.014,hot,root)

def arpenteuse():
    root=empty('Arpenteuse — articulated surveyor');parts={}
    leather=worn('Waxed umber #3F2B1E','201A17','654B35',0,.46)
    iron=worn('Blackened iron #2B2A29','151A1D','474A48',.7,.5)
    bronze=worn('Verdigris bronze #5F8F80','253D36','859C80',.75,.48)
    brass=worn('Worn graduations #A8946E','584B35','B4A481',.75,.4)
    skin=worn('Weathered skin #957B69','51423B','B49A85',0,.78)
    cloth=worn('Charcoal underclothes','131B22','3A454B',0,.88)
    hot=material('Only emission: hot copper #FF7A1F','FF7A1F',2.4,True)
    # Human proportions: 1.83 units, narrow skull, split ankle-length oilskin.
    torso=empty('Shoulders and fitted coat',(0,0,0),root)
    rings('Tailored oilskin torso',[(.83,.16,.105,0),(1.03,.17,.11,0),(1.30,.225,.13,0),(1.45,.18,.105,0)],leather,torso,24)
    for side in (-1,1):
        leg=empty('Booted leg '+str(side),(side*.095,0,.86),root)
        segment('Wool trouser', (0,0,0),(side*.025,.025,-.42),.09,.065,cloth,leg)
        segment('Worn high boot',(side*.025,.025,-.36),(side*.035,-.015,-.77),.075,.055,leather,leg)
        bead('Square weathered boot',(side*.035,-.085,-.79),(.074,.15,.063),iron,leg)
        for z in (-.47,-.57):torus('Boot seam',(side*.025,.015,z),.068,.006,brass,leg,scale=(1,.8,1))
        # Separate shaped coat quarters with irregular hems and pressed longitudinal folds.
        verts=[];N=17
        for k,(z,rx,ry) in enumerate([(.99,.18,.13),(.77,.215,.16),(.47,.255,.19),(.19,.285,.215)]):
            for j in range(N):
                a=(.2+j/(N-1)*2.73)*side
                f=.007*math.sin(j*2.7+k*.3)
                verts.append(((rx+f)*math.sin(a),-(ry+f)*math.cos(a),z+.018*math.sin(j*.8)*(k==3)))
        faces=[(k*N+j,k*N+j+1,(k+1)*N+j+1,(k+1)*N+j) for k in range(3) for j in range(N-1)]
        coat=soften(mesh('Split storm coat panel',verts,faces,leather,root));coat.modifiers.new('Heavy waxed hem','SOLIDIFY').thickness=.012
        for a in (.29,2.8):
            tube('Stitched coat seam',[(side*rx*math.sin(a),-ry*math.cos(a)-.004,z) for z,rx,ry in [(.98,.18,.13),(.76,.215,.16),(.46,.255,.19),(.20,.285,.215)]],.004,brass,root)
        arm=empty('Arm '+str(side),(side*.23,0,1.36),root);parts['arm'+str(side)]=arm
        segment('Sleeve upper',(0,0,0),(side*.095,.025,-.28),.083,.065,leather,arm)
        segment('Sleeve forearm',(side*.095,.025,-.28),(side*.08,-.10,-.52),.065,.05,leather,arm)
        bead('Leather glove',(side*.08,-.10,-.56),(.055,.045,.085),iron,arm)
        for j in range(4):tube('Glove finger seam',[(side*.08+(j-1.5)*.018,-.143,-.54),(side*.08+(j-1.5)*.018,-.14,-.61)],.004,brass,arm)
        plate('Storm lapel',[(side*.025,1.12),(side*.06,1.43),(side*.18,1.36),(side*.12,1.2)],-.14,.016,iron,root)
    rings('High storm collar',[(1.41,.11,.09,0),(1.51,.115,.095,0)],leather,root)
    bead('Long human skull',(0,-.005,1.66),(.091,.082,.13),skin,root)
    bead('Angular jaw',(0,-.033,1.59),(.066,.067,.055),skin,root)
    bead('Nose bridge',(0,-.084,1.66),(.018,.028,.047),skin,root)
    bead('Nose tip',(0,-.106,1.638),(.021,.018,.013),skin,root)
    for s in (-1,1):
        bead('Sunken orbital shadow',(s*.037,-.074,1.685),(.028,.018,.013),iron,root)
        tube('Narrow tired eyelid',[(s*.017,-.088,1.688),(s*.04,-.09,1.691),(s*.057,-.079,1.685)],.004,skin,root)
        tube('Cheekbone',[(s*.066,-.052,1.67),(s*.06,-.08,1.635)],.006,skin,root)
    tube('Closed severe mouth',[(-.03,-.09,1.607),(0,-.1,1.603),(.027,-.09,1.607)],.0028,iron,root)
    rings('Close leather surveyor cap',[(1.71,.097,.087,0),(1.78,.082,.074,.005),(1.795,.012,.012,.005)],leather,root,24)
    plate('Cap visor',[(-.1,1.717),(.10,1.717),(.085,1.704),(-.085,1.704)],-.136,.10,leather,root)
    # Measuring belt and diagonal harness.
    torus('Survey belt',(0,0,1.0),.17,.025,iron,root,scale=(1,.7,1))
    tube('Diagonal tripod harness',[(-.20,-.11,1.38),(-.11,-.151,1.21),(.08,-.14,1.02),(.22,.02,.99)],.027,leather,root)
    for j in range(8):bead('Coat bronze fastener',(.015,-.12,1.07+j*.039),(.008,.009,.008),brass,root)
    # Spool is a real flange pair, radial spokes and tightly nested copper turns.
    spool=empty('Hip chain winch',(.30,0,.93),root)
    for x in (-.07,.07):
        torus('Spool flange',(x,0,0),.142,.012,bronze,spool,(0,math.pi/2,0))
        for j in range(8):
            a=j*math.tau/8;tube('Spool radial spoke',[(x,0,0),(x,.14*math.sin(a),.14*math.cos(a))],.008,brass,spool)
    for x in range(11):torus('Coiled copper at hip',(-.055+x*.011,0,0),.104,.007,bronze,spool,(0,math.pi/2,0))
    segment('Spool spindle',(-.10,0,0),(.10,0,0),.027,.027,iron,spool)
    tube('Crank handle',[(.1,0,0),(.12,0,.07),(.16,0,.07)],.014,brass,spool)
    for s in (-1,0,1):
        a=(s*.06,.17,1.53);b=(s*.10,.22,.43)
        segment('Folded bronze survey tripod',a,b,.018,.012,bronze,root)
        segment('Tripod telescopic lower',(s*.083,.215,.73),(s*.10,.22,.38),.012,.006,iron,root)
        for z in (.70,1.17):torus('Tripod sliding collar',(s*.08,.21,z),.021,.005,brass,root)
    bead('Tripod angular hinge',(0,.19,1.54),(.075,.055,.035),brass,root)
    for j in range(12):tube('Instrument engraved graduation',[(.006+j*.012,.235,1.37),(.006+j*.012,.237,1.385)],.002,brass,root)
    chainpar=empty('Ground trail',parent=root);chain(chainpar,hot,bronze);parts.update(chain=chainpar,hot=hot,iron=bronze)
    return root,parts,['3F2B1E','5F8F80','2B2A29','A8946E','957B69','FF7A1F']

def rainette():
    root=empty('Rainette — reed knight');parts={}
    skin=worn('Rain-wet amphibian skin #5B6B4F','27372D','798568',0,.29)
    belly=worn('Throat folds','3A4C42','8A9480',0,.46)
    iron=worn('Oxidized forged cuirass #6B3A22','262726','8A5134',.7,.55)
    dark=worn('Black iron #2B2A29','111A1B','414541',.6,.53)
    brass=worn('Rivets #A8946E','574E37','BAAA83',.7,.48)
    leather=worn('Waterlogged straps #3F2B1E','201D17','67513B',0,.75)
    wood=worn('Reed spear shaft','232D22','73765B',0,.71)
    glow=material('Only emission: vocal membrane #8DBBA8','8DBBA8',.7,True)
    p=glow.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.35
    torso=empty('Lean amphibian torso',parent=root)
    rings('Long wet torso',[(.85,.12,.095,.035),(1.05,.14,.115,.02),(1.29,.19,.13,.0),(1.40,.15,.10,-.015)],skin,torso,24)
    # Convex overlapping plates with deliberately irregular lower edges.
    for k in range(4):
        z=1.05+k*.075;w=.14+k*.013
        verts=[]
        for row in range(2):
            for j in range(13):
                u=(j-6)/6;verts.append((u*w,-.105-.065*(1-u*u),z+row*.08+.014*math.cos(u*4)))
        o=soften(mesh('Hammered overlapping breastplate',verts,[(j,j+1,14+j,13+j) for j in range(12)],iron,torso,.004));o.modifiers.new('Forged thickness','SOLIDIFY').thickness=.012
        tube('Rolled plate lip',verts[:13],.007,dark,torso)
        for s in (-1,1):bead('Riveted plate corner',(s*w*.85,-.14,z+.05),(.009,.008,.009),brass,torso)
    for side in (-1,1):
        hip=empty('Jump hip '+str(side),(side*.12,.04,.91),root);parts['hip'+str(side)]=hip
        segment('Long amphibian thigh',(0,0,0),(side*.16,-.15,-.33),.10,.067,skin,hip)
        segment('Bent reverse shin',(side*.16,-.15,-.33),(side*.13,.12,-.70),.065,.04,skin,hip)
        bead('Knee ridge',(side*.16,-.15,-.33),(.065,.06,.05),dark,hip)
        segment('Rusted fitted greave',(side*.16,-.13,-.38),(side*.13,.105,-.64),.069,.045,iron,hip)
        for z,y in [(-.42,-.08),(-.59,.06)]:torus('Greave leather binding',(side*.14,y,z),.057,.009,leather,hip)
        foot=(side*.13,.07,-.83)
        segment('Elongated ankle',(side*.13,.12,-.70),foot,.04,.033,skin,hip)
        tips=[]
        for j in range(3):
            end=(side*.13+(j-1)*.075,-.21-.035*(j==1),-.865);tips.append(end)
            tube('Long articulated toe',[foot,(end[0],-.06,-.85),end],.014,skin,hip)
            bead('Small gripping toe pad',end,(.022,.027,.012),belly,hip)
        mesh('Taut webbed foot',[foot,*tips],[(0,1,2),(0,2,3)],skin,hip)
        arm=empty('Leap arm '+str(side),(side*.19,-.005,1.34),root);parts['arm'+str(side)]=arm
        segment('Lean upper arm',(0,0,0),(side*.11,.02,-.27),.052,.037,skin,arm)
        segment('Long forearm',(side*.11,.02,-.27),(side*.16,-.14,-.51),.043,.025,skin,arm)
        segment('Bracer',(side*.12,-.01,-.32),(side*.15,-.11,-.46),.046,.031,iron,arm)
        bead('Palm',(side*.16,-.14,-.53),(.041,.032,.048),skin,arm)
        for j in range(4):
            tube('Splayed fine finger',[(side*.16+(j-1.5)*.018,-.15,-.54),(side*.16+(j-1.5)*.035,-.175,-.61),(side*.16+(j-1.5)*.041,-.15,-.63)],.008,skin,arm)
        # Asymmetric spiked reed shoulder armor.
        if side==1:
            plate('Angular reed pauldron',[(.13,1.38),(.24,1.43),(.34,1.32),(.31,1.26),(.19,1.31)],-.07,.15,iron,root)
            for j in range(3):segment('Reed shoulder thorn',(.22+j*.026,0,1.39-j*.02),(.24+j*.035,.015,1.53-j*.025),.012,.001,dark,root)
    # Flattened wedge head, recessed lateral eyes: deliberately no spherical frog eyes.
    head=empty('Frog head',parent=torso)
    rings('Flattened amphibian skull',[(1.43,.11,.09,-.03),(1.51,.16,.135,-.055),(1.58,.175,.15,-.065),(1.65,.13,.11,-.015),(1.685,.055,.065,0)],skin,head,32)
    bead('Wide flattened upper muzzle',(0,-.156,1.55),(.153,.077,.049),skin,head)
    tube('Long tight mouth',[(-.15,-.151,1.527),(-.09,-.211,1.515),(0,-.231,1.513),(.09,-.211,1.515),(.15,-.151,1.527)],.0035,dark,head)
    for s in (-1,1):
        bead('Recessed lateral eye',(s*.132,-.11,1.621),(.032,.023,.018),dark,head)
        bead('Narrow nonemissive iris',(s*.139,-.13,1.62),(.011,.004,.009),brass,head)
        tube('Heavy slanted brow',[(s*.10,-.138,1.645),(s*.145,-.122,1.651),(s*.164,-.079,1.624)],.013,skin,head)
        tube('Dorsal skin ridge',[(s*.07,.07,1.65),(s*.105,.112,1.57),(s*.11,.12,1.44)],.009,belly,head)
        bead('Small nostril',(s*.04,-.215,1.568),(.008,.005,.004),dark,head)
    sac=empty('Inflatable vocal sac',(0,-.10,1.445),torso);parts['sac']=sac
    bead('Vascular vocal membrane',(0,-.04,-.015),(.102,.08,.075),glow,sac)
    for j in range(13):
        a=(j-6)*.19
        tube('Vocal membrane rib',[(math.sin(a)*.084,-.07-math.cos(a)*.06,-.055),(math.sin(a)*.095,-.055-math.cos(a)*.08,-.015),(math.sin(a)*.07,-.045-math.cos(a)*.05,.035)],.0016,belly,sac)
    # Skin pores and nodules concentrated on silhouette, never spherical toy anatomy.
    for i in range(65):
        s=random.choice([-1,1]);z=random.uniform(1.0,1.40);x=s*random.uniform(.11,.18);y=random.uniform(.045,.095)
        bead('Rain skin granular pore',(x,y,z),(.005,.006,.008),belly,torso)
    tube('Spear diagonal back sling',[(-.16,.10,1.36),(.16,.15,.97)],.022,leather,torso)
    a=(-.26,.19,.65);b=(.27,.19,1.85)
    segment('Short reed spear haft',a,b,.014,.012,wood,torso)
    plate('Leaf-shaped spear blade',[(.245,1.80),(.21,1.91),(.31,2.07),(.32,1.88)],.18,.019,dark,torso)
    for i in range(10):torus('Spear leather lashing',(.24-i*.004,.19,1.79-i*.009),.018,.004,leather,torso)
    return root,parts,['5B6B4F','6B3A22','2B2A29','3F2B1E','A8946E','8DBBA8']

def light(name,loc,power,color,size=3):
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.color=color;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()

def studio():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    s=bpy.context.scene;s.name='CD2 model and calibrated studio';s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=24
    s.render.threads_mode='FIXED';s.render.threads=8;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.film_transparent=False
    s.world=bpy.data.worlds.new('Uniform blue grey studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.021,.03,.044,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.5
    s.view_settings.view_transform='Standard';s.view_settings.look='Medium High Contrast' if False else 'None';s.view_settings.exposure=0
    light('Warm upper left softbox',(-3,-4,6),480,(1,.77,.56),4)
    light('Cold restrained fill',(3,-2,3),190,(.52,.7,1),3)
    light('Cold silhouette strip',(1,3,4),620,(.57,.78,1),2.2)
    bpy.ops.object.camera_add(location=(3,-6,3));s.camera=bpy.context.object;s.camera.name='Presentation orthographic camera';s.camera.data.type='ORTHO'
    return s

def render_panel(s,path,size,loc,target,width):
    s.render.resolution_x,s.render.resolution_y=size;s.render.resolution_percentage=100
    s.camera.location=loc;s.camera.rotation_euler=(Vector(target)-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.sensor_fit='HORIZONTAL';s.camera.data.ortho_scale=width
    s.render.filepath=str(path);bpy.ops.render.render(write_still=True)

def load_ardent():
    with bpy.data.libraries.load(str(ROOT/'art/blender/characters/ardent_iso.blend'),link=False) as (a,b):
        b.objects=list(a.objects)
    objects=[o for o in b.objects if o];root=next(o for o in objects if o.name.startswith('Ardent_Root'))
    for o in objects:
        if o==root or is_child(o,root):
            bpy.context.collection.objects.link(o)
            if o.animation_data:o.animation_data_clear()
    return root

def is_child(o,r):
    while o.parent:
        o=o.parent
        if o==r:return True
    return False

def iso_panel(s,root,out):
    # Reuse C1 terraces source meshes at their world-unit scale, never write there.
    with bpy.data.libraries.load(str(ROOT/'art/blender/terrain/terraces_iso.blend'),link=False) as (a,b):b.scenes=['ground_a']
    ground=[]
    for o in b.scenes[0].objects:
        if o and o.type in ('MESH','EMPTY'):
            bpy.context.collection.objects.link(o);ground.append(o)
    ard=load_ardent();ard.location=(-.90,0,0);ard.rotation_euler.z=math.pi/4
    root.location=(.90,0,0);root.rotation_euler.z=math.pi/4
    iso_rig.create_rig('CREA',(650,280),target=(0,0,.65),reset=False)
    if s.camera.name not in s.objects:s.collection.objects.link(s.camera)
    s.render.film_transparent=False;s.eevee.taa_render_samples=24
    s.render.resolution_x=650;s.render.resolution_y=280;s.render.resolution_percentage=100
    s.camera.data.shift_y=0;s.camera.data.shift_x=0
    s.camera.data.ortho_scale=650/iso_rig.R;s.render.filepath=str(out);bpy.ops.render.render(write_still=True)
    s['CREA_ppu']=iso_rig.R;s['CREA_direction']='se';s['comparison']='Ardent C4 source, unchanged scale; C1 terraces_iso ground_a scene'
    for o in [ard,*ard.children_recursive,*ground]:o.hide_render=True
    root.location=(0,0,0);root.rotation_euler.z=0

def flat(name,hex):return material(name,hex,1,True)

def board_image(scene,path,x,y,w,h):
    image=bpy.data.images.load(str(path),check_existing=True)
    m=bpy.data.materials.new(path.stem+' print');m.use_nodes=True;n=m.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');t=n.new('ShaderNodeTexImage');t.image=image;m.node_tree.links.new(t.outputs['Color'],e.inputs[0]);m.node_tree.links.new(e.outputs[0],o.inputs[0])
    bpy.ops.mesh.primitive_plane_add(size=1,location=(x+w/2,1350-y-h/2,0));p=bpy.context.object;p.scale=(w,h,1);p.data.materials.append(m)

def textline(body,x,y,size,mat):
    c=bpy.data.curves.new(body,'FONT');c.body=body;c.size=size;c.space_character=1.12
    # Windows font, embedded when saving the blend.
    fp='C:/Windows/Fonts/seguisb.ttf'
    if Path(fp).exists():c.font=bpy.data.fonts.load(fp,check_existing=True)
    o=bpy.data.objects.new(body,c);bpy.context.collection.objects.link(o);o.location=(x,1350-y,2);c.materials.append(mat)

def compose(id,out,pal):
    s=bpy.data.scenes.new('CD2 — presentation 2400 x 1350');bpy.context.window.scene=s;s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=8
    s.world=bpy.data.worlds.new('Printed blue grey');s.world.color=(.02,.03,.04);s.render.film_transparent=False;s.view_settings.view_transform='Standard';s.view_settings.look='None'
    bg=flat('Presentation background','17212D');white=flat('Parchment labels','D2D2C4');muted=flat('Secondary captions','8A9A9E');accent=flat('Character swatch',pal[-1])
    bpy.ops.mesh.primitive_plane_add(size=1,location=(1200,675,-1));o=bpy.context.object;o.scale=(2400,1350,1);o.data.materials.append(bg)
    name,title=('ARPENTEUSE','La géomètre de la Cité') if id=='arpenteuse' else ('RAINETTE','Chevalière des roseaux')
    textline(name,55,76,48,white);textline(title,58,113,23,muted);textline('RAINFALL  /  ÉTUDE DE PERSONNAGE  /  CD2',1620,55,16,muted)
    board_image(s,out/'hero.png',25,150,870,1000)
    for i,key in enumerate(['front','profile','back']):
        x=915+i*255;board_image(s,out/(key+'.png'),x,150,245,400);textline(['FACE','PROFIL','DOS'][i],x+10,579,17,muted)
    for i,key in enumerate(['head','detail','signature']):
        x=915+i*255;board_image(s,out/(key+'.png'),x,615,245,240)
        labels=['VISAGE / MESURE','TOURET / CUIVRE','TRÉPIED / PATINE'] if id=='arpenteuse' else ['TÊTE / PEAU HUMIDE','SAC VOCAL / PLIS','FER / RIVETS']
        textline(labels[i],x+2,884,13,muted)
    board_image(s,out/'cast.png',1715,150,650,715)
    textline('TENDEUR · LE TRAJET SE REFERME' if id=='arpenteuse' else 'CHANT DE CRUE · SAC GONFLÉ',1730,897,17,white)
    board_image(s,out/'iso.png',1715,940,650,280)
    textline('ARDENT  /  '+name+'   ·   CREA  SE   ·   90,51 PX/U   ·   SOL C1',1725,1243,12,muted)
    textline('MATIÈRES / PALETTE',925,957,18,white)
    for i,h in enumerate(pal):
        x=948+(i%3)*234;y=1010+(i//3)*103
        bpy.ops.mesh.primitive_circle_add(vertices=48,radius=18,fill_type='NGON',location=(x,1350-y,2));bpy.context.object.data.materials.append(flat('Palette #'+h,h))
        textline('#'+h,x+30,y+6,18,white)
    note='Cuivre chaud : chaîne uniquement.' if id=='arpenteuse' else 'Vert pâle : membrane vocale uniquement.'
    textline(note,925,1213,17,muted);textline('ÉTUDE VOLUMÉTRIQUE  /  PBR USÉ  /  SOURCE BLENDER',57,1287,16,muted)
    bpy.ops.object.camera_add(location=(1200,675,100));s.camera=bpy.context.object;s.camera.data.type='ORTHO';s.camera.data.ortho_scale=2400;s.camera.data.sensor_fit='HORIZONTAL'
    s.render.resolution_x=2400;s.render.resolution_y=1350;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGB';s.render.filepath=str(ROOT/f'art/tools/characters/_cd_{id}.png');bpy.ops.render.render(write_still=True)
    return s

def run(id):
    out=ROOT/f'art/tools/characters/cd_{id}_panels';out.mkdir(parents=True,exist_ok=True)
    s=studio();root,parts,pal=arpenteuse() if id=='arpenteuse' else rainette()
    s['design']='Presentation only; CD2; single emissive hue; real-scale humanoid anatomy';s['palette_hex']=pal
    def panel(key,size,loc,target,width):render_panel(s,out/(key+'.png'),size,loc,target,width)
    panel('hero',(870,1000),(3,-6,2.7),(0,.1,.94),1.98 if id=='arpenteuse' else 1.96)
    for key,loc in [('front',(0,-7,1.25)),('profile',(7,0,1.25)),('back',(0,7,1.25))]:panel(key,(245,400),loc,(0,0,1.0),1.4)
    if id=='arpenteuse':
        panel('head',(245,240),(1,-3,2.05),(0,-.02,1.66),.41)
        panel('detail',(245,240),(2,-2,1.42),(.31,0,.92),.46)
        panel('signature',(245,240),(1,3,1.75),(0,.18,1.19),.66)
    else:
        panel('head',(245,240),(1,-3,1.95),(0,-.06,1.57),.48)
        parts['sac'].scale=(1.5,1.5,1.5);panel('detail',(245,240),(.7,-3,1.6),(0,-.12,1.42),.43);parts['sac'].scale=(1,1,1)
        panel('signature',(245,240),(1,-3,1.7),(.04,-.08,1.22),.49)
    iso_panel(s,root,out/'iso.png')
    # Back to the studio camera: signature pose is stored as a second keyed pose.
    s.camera=bpy.data.objects.get('Presentation orthographic camera')
    poseobjs=[root]+[o for o in parts.values() if isinstance(o,bpy.types.Object)]
    for o in poseobjs:
        for prop in ('location','rotation_euler','scale'):o.keyframe_insert(prop,frame=1)
    s.frame_set(30)
    if id=='arpenteuse':
        for ob in parts['chain'].children_recursive:ob.hide_render=True
        loop=empty('Tendeur closed chain path',parent=root);chain(loop,parts['hot'],parts['iron'],True)
        parts['arm1'].rotation_euler.x=-1.0;parts['arm-1'].rotation_euler.x=-.45
        for o in loop.children_recursive:
            o.hide_render=True;o.keyframe_insert('hide_render',frame=1);o.hide_render=False;o.keyframe_insert('hide_render',frame=30)
        for ob in parts['chain'].children_recursive:
            ob.hide_render=False;ob.keyframe_insert('hide_render',frame=1);ob.hide_render=True;ob.keyframe_insert('hide_render',frame=30)
        for ob in poseobjs:
            for prop in ('location','rotation_euler','scale'):ob.keyframe_insert(prop,frame=30)
        panel('cast',(650,715),(3,-5,3.5),(0,.28,.7),3.2)
    else:
        root.location.z=.57;root.rotation_euler.y=-.18;parts['sac'].scale=(2.05,2.1,1.95)
        parts['hip1'].rotation_euler.x=-.9;parts['hip-1'].rotation_euler.x=.6
        parts['arm1'].rotation_euler=(.3,-.75,-.1);parts['arm-1'].rotation_euler=(-.5,.45,.2)
        for ob in poseobjs:
            for prop in ('location','rotation_euler','scale'):ob.keyframe_insert(prop,frame=30)
        # Ground contact shadow explicitly separates lifted silhouette from landing point.
        shadow=flat('Ground contact subdued','101820');bpy.ops.mesh.primitive_circle_add(vertices=64,radius=.36,fill_type='NGON',location=(0,0,.005));o=bpy.context.object;o.scale=(1,.6,1);o.data.materials.append(shadow)
        panel('cast',(650,715),(3,-6,3.0),(0,0,1.25),2.65)
    for o in poseobjs:
        for prop in ('location','rotation_euler','scale'):o.keyframe_insert(prop,frame=30)
    s.timeline_markers.new('Studio neutral',frame=1);s.timeline_markers.new('Signature spell',frame=30);s.frame_start=1;s.frame_end=30
    s.frame_set(1);root.location=(0,0,0);root.rotation_euler=(0,0,0)
    render_panel(s,out/'source_preview.png',(870,1000),(3,-6,2.7),(0,.1,.94),1.98)
    compose(id,out,pal)
    blend=ROOT/f'art/blender/characters/cd_{id}.blend';blend.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    print('PASS CD2 '+id+' | board 2400x1350 | model + spell pose + CREA/C1 comparison',flush=True)
