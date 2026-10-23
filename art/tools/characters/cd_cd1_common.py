"""CD1 presentation only. Shared worn PBR and geometry from validated Ardent / ash lord.
No game exports. Blender text/layout; Pillow only assembles and verifies renders.
"""
import sys, math, random
sys.dont_write_bytecode=True
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'art/tools/characters'
sys.path.insert(0,str(OUT));sys.path.insert(0,str(ROOT/'art/tools/iso'))
from ardent_iso_build import worn, mesh, rod, rings, bead, soften, empty
import iso_rig
random.seed(21)

def rgb(h):
    a=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in a)+(1,)
def flat(name,h,emit=0):
    m=bpy.data.materials.new(name);m.diffuse_color=rgb(h);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=rgb(h)
    if emit:p.inputs['Emission Color'].default_value=rgb(h);p.inputs['Emission Strength'].default_value=emit
    return m
def block(name,loc,scale,mat,parent,bev=.008):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.parent=parent;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
    if bev:b=o.modifiers.new('Worn forged edges','BEVEL');b.width=bev;b.segments=3;o.modifiers.new('Normals','WEIGHTED_NORMAL')
    return o
def cyl(name,a,b,r,mat,parent,vertices=24,r2=None):
    a,b=Vector(a),Vector(b);v=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=v.length,location=(a+b)/2)
    o=bpy.context.object;o.name=name;o.parent=parent;o.rotation_euler=v.to_track_quat('Z','Y').to_euler();o.data.materials.append(mat)
    bevel=o.modifiers.new('Cast edge','BEVEL');bevel.width=.004;bevel.segments=2
    for p in o.data.polygons:p.use_smooth=True
    return o
def tube(name,pts,r,mat,parent):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=2;s=c.splines.new('POLY');s.points.add(len(pts)-1)
    for p,co in zip(s.points,pts):p.co=(*co,1)
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=parent;o.data.materials.append(mat);return o
def ring(name,z,rx,ry,cy,r,mat,parent):
    return tube(name,[(rx*math.sin(t*math.tau/64),cy-ry*math.cos(t*math.tau/64),z) for t in range(65)],r,mat,parent)
def lathe(name,levels,mat,parent,n=64):return rings(name,levels,mat,parent,n=n,closed=False)
def rivets(parent,z,rx,ry,cy,mat,n=16):
    for j in range(n):
        t=math.tau*j/n;bead('Peened brass rivet',(rx*math.sin(t),cy-ry*math.cos(t),z),(.009,.009,.009),mat,parent)
def palette():
    return dict(iron=worn('Pitted black iron','151817','2B2A29',.68,.55),bronze=worn('Verdigris bloom on cast bronze','263C37','5F8F80',.72,.55),bell=worn('Bell bronze weathered to pale green','426257','8DBBA8',.74,.43),brass=worn('Worn brass rivet heads','5D503B','A8946E',.76,.42),rust=worn('Rust leaking from joints','3E2419','6B3A22',.2,.85),leather=worn('Cracked wet harness leather','131919','40372C',0,.66),dark=worn('Soot deep in openings','05090A','131A1B'),moss=worn('Moss lodged in seams','1F2924','475143',0,.94),ember=flat('Single accent / furnace orange','FF7A1F',2.3),water=flat('Single accent / cyan water','5FD4E8',1.15),coat=worn('Waxed rain grey cloth','242D39','4A5565',0,.54),skin=worn('Cold weathered skin','473E39','9E8A78',0,.8))

def tocsin(M):
    r=empty('Tocsin / 1.40 m / seven removable modules');body=empty('Torso',parent=r)
    lathe('Riveted boiler shell',[(.46,.22,.19,0),(.51,.29,.21,0),(.66,.32,.24,0),(.93,.29,.22,0),(1.01,.23,.18,0)],M['iron'],body)
    for z,rx,ry in [(.51,.29,.22),(.61,.32,.245),(.95,.285,.223)]:
        ring('Bronze retaining hoop',z,rx,ry,0,.018,M['bronze'],body);rivets(body,z,rx+.006,ry+.006,0,M['brass'])
    block('Inset furnace mouth',(0,-.233,.775),(.30,.045,.265),M['dark'],body,.022)
    block('Living furnace',(0,-.258,.77),(.23,.008,.19),M['ember'],body,.016)
    for x in [-.105,-.052,0,.052,.105]:cyl('Pectoral fire grate',(x,-.274,.665),(x,-.274,.875),.012,M['iron'],body,12)
    for z in [.658,.885]:block('Hinged furnace border',(0,-.276,z),(.28,.025,.023),M['brass'],body)
    for x in [-.16,.16]:
        cyl('Grate hinge',(x,-.258,.70),(x,-.258,.84),.018,M['bronze'],body)
        tube('Oxide run',[(x,-.239,.94),(x*.9,-.249,.89),(x*1.05,-.242,.84)],.007,M['rust'],body)
    for x in [-.23,.23]:tube('Boiler harness',[(x,.13,1.0),(x,-.12,.98),(x,-.207,.92),(x,-.22,.61)],.021,M['leather'],body)
    cyl('Neck socket',(0,0,.99),(0,0,1.09),.085,M['iron'],body)
    head=empty('Head / detachable cracked bell',(0,0,1.06),r)
    lathe('Cast bell with flared lip',[(0,.16,.14,0),(.025,.18,.16,0),(.06,.145,.13,0),(.19,.115,.105,0),(.24,.08,.075,0),(.26,.04,.04,0)],M['bell'],head)
    ring('Bell lip bead',.025,.178,.158,0,.012,M['bronze'],head)
    for x in [-.06,.06]:block('Soot cut eye slit',(x,-.105,.151),(.069,.019,.017),M['dark'],head,.001);block('Furnace seen through slit',(x,-.116,.151),(.055,.002,.005),M['ember'],head,.001)
    tube('Bell fracture',[(.04,-.155,.02),(.032,-.129,.07),(.061,-.114,.11),(.052,-.10,.18),(.026,-.077,.23)],.005,M['dark'],head)
    tube('Bent lightning finial',[(0,0,.26),(0,0,.295),(.045,0,.32),(.031,.006,.34)],.009,M['brass'],head)
    for side in [-1,1]:
        arm=empty('Arm L' if side<0 else 'Arm R',(side*.30,0,.94),r)
        cyl('Quick release shoulder',(0,0,0),(side*.08,0,0),.082,M['bronze'],arm)
        cyl('Shoulder axle',(side*.09,-.06,0),(side*.09,.06,0),.044,M['brass'],arm)
        cyl('Upper arm piston',(side*.10,0,-.04),(side*.16,-.02,-.21),.036,M['iron'],arm)
        cyl('Bronze forearm tube',(side*.16,-.02,-.21),(side*.22,-.08,-.40),.057,M['bronze'],arm)
        cyl('Visible piston',(side*.16,-.07,-.17),(side*.20,-.11,-.34),.012,M['brass'],arm)
        for z in [-.23,-.37]:ring('Tube collar',z,.061,.058,0,.008,M['iron'],arm).location=(side*(.17 if z>-.3 else .21),-.04 if z>-.3 else -.07,0)
        bead('Wrist swivel',(side*.22,-.08,-.43),(.05,.045,.045),M['iron'],arm)
        for j in range(3):
            t=math.tau*j/3;xx=side*.22+math.cos(t)*.05;yy=-.08+math.sin(t)*.05
            tube('Three jointed grapple talon',[(xx,yy,-.44),(xx+math.cos(t)*.035,yy+math.sin(t)*.035,-.53),(side*.22+math.cos(t)*.025,-.08+math.sin(t)*.025,-.58)],.015,M['iron'],arm)
        tube('Slack hydraulic cable',[(0,.06,0),(side*.10,.10,-.17),(side*.13,.11,-.28),(side*.20,.02,-.36)],.009,M['leather'],arm)
        leg=empty('Leg L' if side<0 else 'Leg R',(side*.145,0,.50),r)
        cyl('Disconnect hip flange',(0,0,0),(0,0,-.07),.065,M['bronze'],leg)
        for yy in [-.034,.034]:cyl('Paired connecting rod',(0,yy,-.07),(side*.025,yy,-.30),.018,M['iron'],leg)
        cyl('Knee pin',(.025,-.055,-.23),(.025,.055,-.23),.035,M['brass'],leg)
        block('Cast iron sabot',(side*.015,-.065,-.42),(.18,.26,.12),M['iron'],leg,.017)
        block('Bronze toe plate',(side*.015,-.176,-.4),(.16,.025,.07),M['bronze'],leg)
        for xx in [-.055,.055]:bead('Boot rivet',(xx,-.193,-.4),(.009,.009,.009),M['brass'],leg)
    for j in range(7):
        x=random.uniform(-.24,.24);tube('Mineral streak at seam',[(x,.216,.92),(x+.008,.236,.81),(x-.005,.238,.72)],.005,M['rust'],body)
    for j in range(10):bead('Waterlogged moss',(random.uniform(-.20,.20),.20,.54),(.018,.01,.006),M['moss'],body)
    # Pressure gauge and crooked copper pipe, more industrial salvage than face.
    cyl('Pressure dial housing',(.21,-.18,.94),(.21,-.23,.94),.045,M['brass'],body)
    cyl('Dark gauge face',(.21,-.231,.94),(.21,-.235,.94),.035,M['dark'],body)
    tube('Gauge needle',[(.21,-.24,.94),(.226,-.24,.962)],.0025,M['brass'],body)
    tube('Bent return pipe',[(-.18,.15,.59),(-.31,.16,.68),(-.32,.12,.98),(-.2,.10,1.02)],.014,M['bronze'],body)
    return r

def coat_panel(name,levels,M,parent):
    n=72;vs=[]
    for k,(z,rx,ry,cy) in enumerate(levels):
        for j in range(n):
            t=math.tau*j/n;fold=.009*math.sin(11*t+k*.7)+.005*math.sin(19*t-k)
            vs.append(((rx+fold)*math.sin(t),cy-(ry+fold)*math.cos(t),z+.008*math.sin(t*7) if k==0 else z))
    fs=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(levels)-1) for j in range(n)]
    o=mesh(name,vs,fs,M,parent);sol=o.modifiers.new('Waxed cloth thickness','SOLIDIFY');sol.thickness=.008
    for p in o.data.polygons:p.use_smooth=True
    return o

def averse(M):
    r=empty('Averse / 1.78 m / rain bearer');b=empty('Body',parent=r)
    for s in [-1,1]:
        cyl('Trouser leg',(s*.09,0,.16),(s*.105,.03,.65),.065,M['leather'],b,r2=.075)
        block('Worn leather ankle boot',(s*.09,-.06,.09),(.13,.25,.16),M['leather'],b,.02)
        block('Iron sole',(s*.09,-.07,.025),(.14,.26,.035),M['iron'],b)
    coat_panel('Heavy folded waxed raincoat',[(.30,.22,.18,.02),(.39,.215,.17,.025),(.65,.18,.14,0),(.87,.17,.13,0),(1.05,.20,.145,0),(1.28,.265,.15,.015),(1.36,.235,.13,.015),(1.40,.11,.08,0)],M['coat'],b)
    # Tailored overlapping storm flap; stitched seams follow the drape.
    for s in [-1,1]:
        tube('Long stitched hem',[(s*.04,-.18,.32),(s*.033,-.161,.60),(s*.03,-.14,.88),(s*.035,-.154,1.15),(s*.06,-.13,1.36)],.003,M['leather'],b)
        tube('Raglan seam',[(s*.10,-.085,1.40),(s*.20,-.141,1.30),(s*.27,-.10,1.21)],.003,M['brass'],b)
        for z in [.46,.56,.66]:block('Storm flap stitch',(s*.035,-.18,z),(.013,.004,.003),M['brass'],b,.001)
    for z in [.72,.84,.96,1.08,1.20]:bead('Tarnished coat fastening',(.035,-.154,z),(.009,.006,.009),M['brass'],b)
    for s in [-1,1]:
        arm=empty('Arm L' if s<0 else 'Arm R',(s*.245,0,1.29),r)
        cyl('Waxed upper sleeve',(0,0,0),(s*.075,-.01,-.24),.083,M['coat'],arm,r2=.069)
        cyl('Bent sleeve',(s*.075,-.01,-.24),(s*.09,-.14,-.43),.07,M['coat'],arm,r2=.047)
        for j in range(4):tube('Elbow fabric crease',[(s*.03+j*.01,-.07,-.19-j*.02),(s*.105,-.065,-.22-j*.02)],.004,M['leather'],arm)
        cyl('Leather glove',(s*.09,-.14,-.43),(s*.09,-.17,-.52),.044,M['leather'],arm,r2=.031)
        for j in range(4):tube('Long glove finger',[(s*.06+j*.018,-.19,-.49),(s*.061+j*.017,-.195,-.55+(j==3)*.012)],.008,M['leather'],arm)
        tube('Opposing glove thumb',[(s*.057,-.15,-.47),(s*.032,-.18,-.50),(s*.04,-.19,-.515)],.011,M['leather'],arm)
    # Deep open hood, cloth horseshoe around a narrow realistic face.
    hood=empty('Hood',(0,0,1.50),r)
    bead('Hood vault',(0,.02,.095),(.132,.126,.175),M['coat'],hood)
    bead('Black hood recess',(0,-.089,.058),(.102,.058,.137),M['dark'],hood)
    bead('Weathered narrow face',(0,-.12,.044),(.068,.044,.103),M['skin'],hood)
    mesh('Angular nose',[(-.012,-.151,.09),(.012,-.151,.09),(0,-.185,.01),(-.015,-.155,.005),(.015,-.155,.005)],[(0,1,2),(0,2,3),(1,4,2),(2,4,3)],M['skin'],hood)
    for s in [-1,1]:tube('Deep downcast eyelid',[(s*.017,-.157,.062),(s*.047,-.153,.067)],.0035,M['dark'],hood)
    tube('Unsmiling mouth',[(-.023,-.159,-.005),(0,-.164,-.009),(.022,-.157,-.005)],.0025,M['dark'],hood)
    tube('Heavy hood brow',[(-.11,-.09,.055),(-.09,-.14,.15),(0,-.16,.19),(.09,-.14,.15),(.11,-.09,.055)],.012,M['coat'],hood)
    for s in [-1,1]:tube('Hood draw cord',[(s*.09,-.09,.0),(s*.095,-.16,-.17)],.004,M['leather'],hood)
    # Amphora built as a hollow shell, open mouth and internal water surface.
    jar=empty('Amphora',(.035,.22,.73),r)
    lathe('Hammered bronze amphora',[(0,.085,.075,0),(.05,.13,.115,0),(.20,.21,.17,0),(.43,.23,.18,0),(.58,.19,.15,0),(.68,.10,.09,0),(.80,.11,.10,0),(.83,.135,.12,0)],M['bronze'],jar)
    lathe('Visible inner mouth',[(.83,.122,.108,0),(.78,.097,.087,0),(.68,.09,.08,0),(.59,.17,.13,0)],M['dark'],jar)
    for z,rx,ry in [(.13,.18,.15),(.48,.225,.18),(.80,.115,.105)]:
        ring('Amphora brass hoop',z,rx,ry,0,.013,M['brass'],jar);rivets(jar,z,rx,ry,0,M['brass'],12)
    for s in [-1,1]:
        tube('Cast amphora loop handle',[(s*.10,0,.73),(s*.22,0,.73),(s*.28,0,.64),(s*.27,0,.48),(s*.19,0,.46)],.016,M['brass'],jar)
        tube('Load bearing backpack strap',[(s*.12,.20,1.30),(s*.21,.015,1.40),(s*.20,-.16,1.25),(s*.15,-.163,.92),(s*.16,.12,.83)],.023,M['leather'],r)
        block('Harness buckle',(s*.168,-.18,1.02),(.06,.019,.075),M['brass'],r)
    # Sight glass on the outer back; brass mullions, clearly visible in back/detail views.
    block('Recessed glass sight channel',(0,.183,.37),(.083,.018,.40),M['dark'],jar,.008)
    water=block('Water level / full',(0,.197,.37),(.050,.010,.35),M['water'],jar,.003)
    for x in [-.043,.043]:block('Sight glass brass stile',(x,.202,.37),(.008,.016,.42),M['brass'],jar)
    for j in range(6):block('Graduation mark',(.031,.216,.20+j*.065),(.026,.006,.003),M['brass'],jar,.001)
    cyl('Full water surface',(0,0,.713),(0,0,.716),.089,M['water'],jar,48)
    for j in range(9):
        x=-.16+j*.04;tube('Repousse rain channel',[(x,.15,.20),(x*1.1,.17,.41),(x*.8,.14,.59)],.003,M['brass'],jar)
    tube('Drain hose',[(.16,.28,.87),(.29,.20,.72),(.31,.04,.63),(.26,-.1,.67)],.012,M['leather'],r)
    cyl('Drain valve spindle',(.27,-.1,.67),(.27,-.16,.67),.019,M['brass'],r)
    tube('Drain valve crossbar',[(.235,-.16,.67),(.305,-.16,.67)],.008,M['brass'],r)
    return r

def light(name,loc,power,color,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler()
def setup():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=24;s.render.film_transparent=True
    s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.threads_mode='FIXED';s.render.threads=8
    s.view_settings.view_transform='Standard';s.world.color=(.045,.055,.07)
    light('Warm overcast studio key',(-3,-4,5),310,(1,.80,.62),3)
    light('Cold rim',(2,3,3.3),280,(.57,.70,.86),2.3)
    light('Soft reading fill',(3,-2,2),105,(.67,.78,.93),3)
    d=bpy.data.cameras.new('Presentation camera');o=bpy.data.objects.new('Presentation camera',d);s.collection.objects.link(o);s.camera=o;d.type='ORTHO';d.lens=55
    s.render.resolution_percentage=100
    return s

def render(id,key,w,h,eye,target,scale):
    s=bpy.context.scene;c=s.camera;c.location=eye;c.rotation_euler=(Vector(target)-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=scale;c.data.sensor_fit='HORIZONTAL'
    s.render.resolution_x=w;s.render.resolution_y=h;s.render.filepath=str(OUT/f'_cd_{id}_{key}.png');bpy.ops.render.render(write_still=True)
    return s.render.filepath

def hidden(root,yes):
    for o in [root,*root.children_recursive]:o.hide_render=yes

def iso_view(id,root):
    s=bpy.context.scene
    # Append the validated model at native metre scale, rather than approximating Ardent.
    with bpy.data.libraries.load(str(ROOT/'art/blender/characters/ardent_iso.blend'),link=False) as (src,dst):dst.objects=src.objects
    imported=[]
    for o in dst.objects:
        if o and o.type in ('MESH','EMPTY','CURVE'):s.collection.objects.link(o);imported.append(o)
    ar=next(o for o in imported if o.name.startswith('Ardent_Root'))
    keep=set([ar,*ar.children_recursive])
    for o in imported:
        if o not in keep:o.hide_render=True
    for o in keep:o.animation_data_clear()
    ar.location=(-.93,0,0);ar.rotation_euler.z=math.pi/4
    root.location=(.93,0,0);root.rotation_euler.z=math.pi/4
    oldcam=s.camera
    iso_rig.create_rig('CREA',(470,280),target=(0,0,.55),reset=False)
    s.eevee.taa_render_samples=16;s.render.resolution_x=470;s.render.resolution_y=280
    s.render.filepath=str(OUT/f'_cd_{id}_iso_actor.png');bpy.ops.render.render(write_still=True)
    from PIL import Image
    tile=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    bg=Image.new('RGBA',(470,280),(0,0,0,0));bg.alpha_composite(tile,(-21,35));bg.alpha_composite(Image.open(s.render.filepath).convert('RGBA'));bg.save(OUT/f'_cd_{id}_iso.png')
    for o in keep:o.hide_render=True
    root.location=(0,0,0);root.rotation_euler.z=0;s.camera=oldcam
    return str(OUT/f'_cd_{id}_iso.png')

def board(id,imgs):
    # Typography, palette and image panels are rendered in Blender, with no Pillow drawing.
    s=setup();s.render.film_transparent=False;s.world.color=(0,0,0);s.eevee.taa_render_samples=16
    for o in list(bpy.data.objects):
        if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
    c=s.camera;c.location=(1200,675,100);c.rotation_euler=(0,0,0);c.data.ortho_scale=2400;c.data.sensor_fit='HORIZONTAL'
    def emission(name,color):
        m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();p=n.new('ShaderNodeEmission');p.inputs[0].default_value=rgb(color);out=n.new('ShaderNodeOutputMaterial');m.node_tree.links.new(p.outputs[0],out.inputs[0]);return m
    bg=emission('Uniform blue grey board','171F29');txt=emission('Typography','D8D9D3');muted=emission('Muted type','8596A4');line=emission('Rules','354450')
    def rect(x,y,w,h,mat,z=0):
        o=mesh('Layout',[(x,1350-y, z),(x+w,1350-y,z),(x+w,1350-y-h,z),(x,1350-y-h,z)],[(0,1,2,3)],mat,None);return o
    rect(0,0,2400,1350,bg,-4)
    def text(t,x,y,size=20,mat=txt):
        d=bpy.data.curves.new('Caption','FONT');d.body=t;d.size=size;d.space_character=1.12;o=bpy.data.objects.new(t,d);s.collection.objects.link(o);o.location=(x,1350-y,3);d.materials.append(mat)
    def image_panel(key,x,y,w,h):
        im=bpy.data.images.load(imgs[key],check_existing=True);m=bpy.data.materials.new(key);m.use_nodes=True;n=m.node_tree.nodes;n.clear();tex=n.new('ShaderNodeTexImage');tex.image=im;em=n.new('ShaderNodeEmission');out=n.new('ShaderNodeOutputMaterial');trans=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');l=m.node_tree.links;l.new(tex.outputs['Color'],em.inputs[0]);l.new(tex.outputs['Alpha'],mix.inputs[0]);l.new(trans.outputs[0],mix.inputs[1]);l.new(em.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs[0]);m.surface_render_method='DITHERED'
        o=rect(x,y,w,h,m,1);uv=o.data.uv_layers.new()
        for p in o.data.polygons:
            for li,co in zip(p.loop_indices,[(0,1),(1,1),(1,0),(0,0)]):uv.data[li].uv=co
    title='TOCSIN' if id=='tocsin' else 'AVERSE';subtitle='AUTOMATE DE CRUE' if id=='tocsin' else 'LA PORTEUSE DE PLUIE'
    text('RAINFALL   /   ÉTUDES DE PERSONNAGES',48,42,17,muted);text(title,48,112,58);text(subtitle,52,151,22,muted);text('CD1  /  01' if id=='tocsin' else 'CD1  /  02',2170,50,18,muted)
    rect(810,95,1,1150,line);image_panel('hero',10,175,790,990)
    text('01   /   VOLUME & MATIÈRES',52,1175,16,muted)
    for j,key in enumerate(['front','side','back']):
        x=850+j*495;image_panel(key,x,155,440,430);text(['FACE','PROFIL','DOS'][j],x+175,603,17,muted)
    rect(850,625,1485,1,line)
    labels=(['CLOCHE FÊLÉE / FENTES','FOYER & MANOMÈTRE','PINCE / RACCORD RAPIDE'] if id=='tocsin' else ['CAPUCHE / VISAGE ABÎMÉ','AMPHORE / VERRE DE NIVEAU','HARNAIS / VANNE DE VIDANGE'])
    for j,key in enumerate(['detail1','detail2','detail3']):
        x=850+j*495;image_panel(key,x,646,450,230);text(labels[j],x,906,16,muted)
    rect(850,930,1485,1,line)
    image_panel('iso',840,957,470,280);text('CREA · SE · R 90,51 PX/U · SOL C1',850,1270,14,muted);text('ARDENT                 '+title,896,1244,14,txt)
    image_panel('spell',1320,955,350,280);text('TÊTE-CLOCHE' if id=='tocsin' else 'CRUE / AMPHORE VIDÉE',1330,1270,15,muted)
    if id=='tocsin':
        for j,key in enumerate(['noarms','oneleg','barrel']):image_panel(key,1700+j*215,962,210,245);text(['SANS BRAS','UNE JAMBE','TONNEAU'][j],1705+j*215,1240,14,muted)
    else:
        for j,key in enumerate(['full','empty']):image_panel(key,1710+j*315,960,300,260);text(['PLEINE / LESTÉE','VIDE / DÉLESTÉE'][j],1730+j*315,1240,14,muted)
    cols=['2B2A29','5F8F80','A8946E','6B3A22','8DBBA8','FF7A1F'] if id=='tocsin' else ['4A5565','2B3340','5F8F80','A8946E','3F2B1E','5FD4E8']
    for j,h in enumerate(cols):
        x=52+j*123;mat=emission('Palette '+h,h);rect(x,1210,44,28,mat,2);text('#'+h,x,1260,13,muted)
    text('BRONZE NOYÉ / MODULES DÉVISSABLES' if id=='tocsin' else 'CIRÉ LOURD / EAU CAPTIVE',52,1310,16,muted)
    text('MODÈLE 3D ORIGINAL  ·  PBR USÉ  ·  ÉTUDE DE PRÉSENTATION',1710,1322,13,muted)
    s.render.resolution_x=2400;s.render.resolution_y=1350;s.render.filepath=str(OUT/f'_cd_{id}.png');bpy.ops.render.render(write_still=True)

def polish(id,r,M):
    wp=M['water'].node_tree.nodes.get('Principled BSDF');wp.inputs['Metallic'].default_value=.18;wp.inputs['Roughness'].default_value=.22;wp.inputs['Emission Strength'].default_value=.35
    # Surface scales are material-specific: skin and waxed cloth cannot carry iron pits.
    for key in ['skin','coat','leather']:
        n=M[key].node_tree.nodes
        for b in n:
            if b.type=='BUMP':b.inputs['Distance'].default_value=.0014 if key=='skin' else .003;b.inputs['Strength'].default_value=.14
    for node in M['skin'].node_tree.nodes:
        if node.type=='VALTORGB':
            node.color_ramp.elements[0].color=rgb('655D53');node.color_ramp.elements[1].color=rgb('8B7D6F')
    if id=='tocsin':
        body=bpy.data.objects['Torso']
        # Repairable stacked flange joints, hexagonal fasteners and reinforcing ribs.
        for side in [-1,1]:
            leg=bpy.data.objects['Leg L' if side<0 else 'Leg R']
            for z in [-.09,-.30]:
                cyl('Bolted piston collar',(side*.012,0,z-.017),(side*.012,0,z+.017),.046,M['bronze'],leg,16)
            cyl('Machined shin piston',(side*.02,-.055,-.13),(side*.025,-.055,-.34),.013,M['brass'],leg)
            for zz in [-.12,-.19,-.28]:cyl('Shin piston seal',(side*.02,-.055,zz-.009),(side*.02,-.055,zz+.009),.021,M['iron'],leg,16)
            for o in list(leg.children):
                if o.name.startswith('Cast iron sabot') or o.name.startswith('Bronze toe plate'):bpy.data.objects.remove(o,do_unlink=True)
            vs=[(-.085,.075,-.48),(.085,.075,-.48),(.09,-.20,-.48),(-.09,-.20,-.48),(-.063,.055,-.35),(.063,.055,-.35),(.077,-.16,-.395),(-.077,-.16,-.395)]
            mesh('Wedge cast sabaton',vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],M['iron'],leg,.006)
            for zz in [-.415,-.448]:tube('Layered sabaton toe seam',[(-.074,-.178,zz),(.074,-.178,zz)],.004,M['bronze'],leg)
            arm=bpy.data.objects['Arm L' if side<0 else 'Arm R']
            for j in range(3):
                xx=side*(.16+j*.018);zz=-.22-j*.065
                cyl('Forearm locking screw',(xx,-.073,zz),(xx,-.09,zz),.009,M['brass'],arm,6)
            for j in range(4):
                t=side*(.65+j*.23);xx=.297*math.sin(t);yy=-.234*math.cos(t)
                tube('Cast boiler rib',[(xx*.94,yy*.94,.66),(xx,yy,.80),(xx*.92,yy*.92,.92)],.007,M['iron'],body)
            for j in range(3):
                zz=.69+j*.07;cyl('Steam return manifold',(side*.29,.05,zz),(side*.36,.05,zz),.025,M['bronze'],body)
                cyl('Manifold blanking plug',(side*.36,.05,zz),(side*.37,.05,zz),.029,M['brass'],body,6)
            for j in range(3):block('Shoulder cast vent',(side*.22,-.14,1.005),(.028,.04,.008),M['dark'],body,.002)
        head=bpy.data.objects['Head / detachable cracked bell']
        for o in list(head.children):
            if o.name.startswith('Furnace seen through slit'):o.data.materials.clear();o.data.materials.append(flat('Dim furnace through bell slit','FF7A1F',.8))
        for side in [-1,1]:
            ob=block('Cast overhang above slit',(side*.06,-.113,.171),(.087,.024,.014),M['bronze'],head,.003);ob.rotation_euler.y=side*.09
        # Uneven lip loss and dark foundry inscriptions keep the bell from reading as a face.
        for j in range(7):
            x=-.07+j*.022;block('Foundry tally groove',(x,-.143,.065),(.004,.004,.013+j%2*.006),M['dark'],head,.001)
        for j in range(18):
            t=random.uniform(0,math.tau);z=random.uniform(.64,.9)
            tube('Thin leaking oxidation',[(.31*math.sin(t),.236*math.cos(t),z),(.31*math.sin(t+.015),.237*math.cos(t+.015),z-.035)],.002,M['rust'],body)
    else:
        hood=bpy.data.objects['Hood'];body=bpy.data.objects['Body'];bpy.data.objects['Black hood recess'].location.y=-.025
        for o in list(hood.children):
            if any(o.name.startswith(n) for n in ['Weathered narrow face','Angular nose','Deep downcast eyelid','Unsmiling mouth']):bpy.data.objects.remove(o,do_unlink=True)
        # Continuous anatomic head surface: brow, sockets, nose bridge, lips and jaw.
        levels=[(-.085,.022,.027,-.105),(-.075,.038,.036,-.108),(-.060,.050,.040,-.107),(-.040,.058,.045,-.106),(-.020,.063,.048,-.104),(0,.065,.05,-.101),(.020,.067,.051,-.10),(.040,.068,.052,-.098),(.060,.068,.052,-.096),(.080,.067,.051,-.094),(.10,.064,.047,-.09),(.12,.055,.04,-.085),(.135,.038,.028,-.08),(.14,.01,.01,-.079)]
        vs=[];n=80
        def gauss(x,c,w):return math.exp(-((x-c)/w)**2)
        for z,rx,ry,cy in levels:
            for j in range(n):
                t=math.tau*j/n;x=rx*math.sin(t);fr=max(0,math.cos(t))**9;y=cy-ry*math.cos(t)
                # Frontal relief: long narrow nose, tired orbital cavities, sharp cheek planes.
                relief=.021*gauss(x,0,.013)*gauss(z,.022,.048)+.018*gauss(x,0,.020)*gauss(z,-.005,.014)
                relief+=.007*(gauss(x,.037,.018)+gauss(x,-.037,.018))*gauss(z,.006,.025)
                relief-=.008*(gauss(x,.028,.017)+gauss(x,-.028,.017))*gauss(z,.054,.015)
                relief+=.005*gauss(x,0,.032)*gauss(z,-.042,.009)
                y-=fr*relief;vs.append((x,y,z))
        fs=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(levels)-1) for j in range(n)]
        face=mesh('Sculpted gaunt human face',vs,fs,M['skin'],hood)
        for p in face.data.polygons:p.use_smooth=True
        sub=face.modifiers.new('Continuous skin surface','SUBSURF');sub.levels=2
        eyes=worn('Shadowed natural eye','272624','777567',0,.7)
        lip=worn('Desaturated chapped lip','594843','7B6660',0,.82)
        for mat in [eyes,lip]:
            for b in mat.node_tree.nodes:
                if b.type=='BUMP':b.inputs['Distance'].default_value=.0005
        for side in [-1,1]:
            # Deep narrow eyes under the hood, no round or luminous pupils.
            bead('Recessed tired eye',(side*.027,-.142,.054),(.014,.003,.0034),eyes,hood)
            tube('Upper eyelid',[(side*.012,-.145,.054),(side*.026,-.146,.058),(side*.041,-.140,.055)],.0018,M['skin'],hood)
            tube('Brow ridge',[(side*.012,-.149,.073),(side*.026,-.150,.076),(side*.043,-.141,.073)],.0025,M['leather'],hood)
            bead('Nostril recess',(side*.011,-.173,-.009),(.004,.002,.002),M['dark'],hood)
            tube('Cheek age crease',[(side*.038,-.148,.029),(side*.047,-.141,.005),(side*.046,-.14,-.018)],.0008,lip,hood)
        tube('Upper lip',[(-.022,-.151,-.037),(-.01,-.155,-.035),(0,-.157,-.037),(.010,-.155,-.035),(.022,-.151,-.037)],.0018,lip,hood)
        tube('Lower lip',[(-.018,-.152,-.041),(0,-.158,-.043),(.018,-.152,-.041)],.0018,M['skin'],hood)
        # Storm cape and gusseted pockets break the straight raincoat silhouette.
        cape=coat_panel('Overlapping shoulder storm cape',[(1.18,.288,.175,.015),(1.25,.30,.178,.015),(1.33,.258,.148,.01),(1.40,.115,.09,0)],M['coat'],body)
        for side in [-1,1]:
            block('Angled deep coat pocket',(side*.145,-.13,.76),(.105,.022,.14),M['coat'],body,.005)
            tube('Pocket bound edge',[(side*.10,-.151,.84),(side*.19,-.13,.81)],.003,M['leather'],body)
            tube('Long draped coat fold',[(side*.12,-.166,.34),(side*.13,-.157,.48),(side*.11,-.143,.66),(side*.12,-.14,.9)],.004,M['coat'],body)
        # Substitute forged ankle caps with shaped, laced wet leather boots.
        for o in list(body.children):
            if o.name.startswith('Worn leather ankle boot') or o.name.startswith('Iron sole'):bpy.data.objects.remove(o,do_unlink=True)
        for side in [-1,1]:
            foot=empty('Shaped boot',(side*.09,0,0),body)
            rings('Shaped boot leather',[(.035,.062,.105,-.045),(.06,.065,.115,-.05),(.11,.061,.10,-.038),(.15,.052,.06,0),(.24,.049,.053,.01)],M['leather'],foot,n=32)
            for j in range(4):tube('Cross lacing',[(-.026,-.07,.13+j*.022),(.026,-.07,.145+j*.022)],.0025,M['brass'],foot)
        # Broad flat webbing over the existing load cables, with real strap edges.
        for side in [-1,1]:
            verts=[]
            pts=[(side*.12,.21,1.30),(side*.21,.015,1.405),(side*.20,-.17,1.25),(side*.15,-.18,.92)]
            for x,y,z in pts:verts.extend([(x-.024,y-.003,z),(x+.024,y-.003,z)])
            mesh('Flat load bearing shoulder webbing',verts,[(2*k,2*k+1,2*k+3,2*k+2) for k in range(3)],M['leather'],r)
        jar=bpy.data.objects['Amphora']
        for side in [-1,1]:
            tube('Black mineral drip on amphora',[(side*.08,.105,.78),(side*.12,.14,.63),(side*.14,.16,.53)],.003,M['dark'],jar)
        for j in range(9):
            x=random.uniform(-.11,.11);tube('Mineral run beneath collar',[(x,.11,.78),(x*1.2,.145,.67)],.002,M['rust'],jar)


def run(id):
    s=setup();M=palette();r=tocsin(M) if id=='tocsin' else averse(M);polish(id,r,M);height=1.4 if id=='tocsin' else 1.78
    bpy.context.scene['purpose']='CD1 presentation only / no game assets';bpy.context.scene['character_height_m']=height
    render_args=(790,990,(3,-6,2.9),(0,0,height*.5),height*.875)
    # Save editable detailed source before rendering derived presentation views.
    s.camera.location=render_args[2];s.camera.rotation_euler=(Vector(render_args[3])-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=render_args[4]
    s.render.resolution_x=790;s.render.resolution_y=990
    path=ROOT/f'art/blender/characters/cd_{id}.blend';path.parent.mkdir(parents=True,exist_ok=True);bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(path))
    imgs={};imgs['hero']=render(id,'hero',*render_args)
    for key,eye in [('front',(0,-6,height*.62)),('side',(6,0,height*.62)),('back',(0,6,height*.62))]:imgs[key]=render(id,key,440,430,eye,(0,0,height*.51),height*1.28)
    if id=='tocsin':
        details=[((1,-3,1.6),(0,0,1.23),.48),((.3,-3,1.15),(0,-.12,.81),.70),((2,-4,1.1),(.48,-.06,.60),.52)]
    else:details=[((.5,-3,1.9),(0,-.02,1.56),.46),((1,4,2.2),(.035,.35,1.16),.85),((2,-3,1.5),(.20,-.01,1.10),.69)]
    for j,(eye,tgt,scale) in enumerate(details):imgs['detail'+str(j+1)]=render(id,'detail'+str(j+1),450,230,eye,tgt,scale)
    imgs['iso']=iso_view(id,r)
    if id=='tocsin':
        head=bpy.data.objects['Head / detachable cracked bell'];head.location=(.30,-.10,1.48);head.rotation_euler.y=.7
        for o in r.children:
            if o.name.startswith('Arm '):o.rotation_euler.y=(-.7 if o.location.x>0 else .7)
        # Spherical shock represented by thin fractured pressure rings, same furnace accent.
        shock=empty('Bell shockwave',parent=r)
        for radius in [.27,.38,.49]:ring('Pressure wave',.13,radius,radius,0,.006,M['ember'],shock)
        imgs['spell']=render(id,'spell',350,280,(3,-6,3),(0,0,.90),2.1);hidden(shock,True);head.location=(0,0,1.06);head.rotation_euler=(0,0,0)
        for o in r.children:
            if o.name.startswith('Arm '):hidden(o,True);o.rotation_euler=(0,0,0)
        imgs['noarms']=render(id,'noarms',210,245,(3,-6,2.8),(0,0,.7),1.25)
        hidden(bpy.data.objects['Leg L'],True);r.rotation_euler.y=-.13
        imgs['oneleg']=render(id,'oneleg',210,245,(3,-6,2.8),(0,0,.7),1.25)
        hidden(bpy.data.objects['Leg R'],True);r.rotation_euler=(math.pi/2,0,-.20);r.location.z=.28
        imgs['barrel']=render(id,'barrel',210,245,(3,-6,3),(0,-.65,.30),1.1)
    else:
        jar=bpy.data.objects['Amphora'];full=bpy.data.objects['Water level / full'];surface=bpy.data.objects['Full water surface']
        imgs['full']=render(id,'full',300,260,(2,4,2.3),(.035,.23,1.14),.95)
        full.scale.z=.08;full.location.z=.205;surface.location.z-=.57
        imgs['empty']=render(id,'empty',300,260,(2,4,2.3),(.035,.23,1.14),.95)
        for o in r.children:
            if o.name.startswith('Arm '):o.rotation_euler.x=-.8;o.rotation_euler.y= -.6 if o.location.x<0 else .6
        # Broad water sheets emerge from the drained vessel and spread outward.
        for side in [-1,1]:
            vs=[]
            for k in range(28):
                t=k/27;angle=(-1.2+2.4*t);rad=.30+.55*t
                for off in [0,.12]:vs.append((side*rad*math.cos(angle),-.35-rad*math.sin(angle),.10+off+.20*math.sin(t*math.pi)))
            o=mesh('Crue / torn water sheet',vs,[(2*k,2*k+1,2*k+3,2*k+2) for k in range(27)],M['water'],r)
            for p in o.data.polygons:p.use_smooth=True
        imgs['spell']=render(id,'spell',350,280,(3,-6,3),(0,-.2,.8),2.45)
    board(id,imgs)
    from PIL import Image
    im=Image.open(OUT/f'_cd_{id}.png');assert im.size==(2400,1350)
    print('PASS CD1 '+id+' / source saved / 2400x1350 / full views, details, CREA, signature and resource states',flush=True)
