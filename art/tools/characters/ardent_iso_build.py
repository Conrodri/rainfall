"""C4: fresh human pilgrim, CREA 30 degrees, fixed 192px / 71% ground pivot.
Background Blender only. Reuses boss materials, geometry helpers and iso export.
No input character model; --build-only saves the fully keyed source without renders.
"""
import sys, math, json, hashlib
sys.dont_write_bytecode=True
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/monsters'))
from ash_lord_build import worn, mesh, plate, rod, material, empty
from mathutils import Matrix
sys.path.insert(0,str(ROOT/'art/tools/iso'))
import iso_rig
from boss_common import box, DIRECTIONS
OUT=ROOT/'art/tools/characters/ardent_iso_frames'
BLEND=ROOT/'art/blender/characters/ardent_iso.blend'

def soften(ob,subdivide=False):
    for mod in ob.modifiers:
        if mod.type=='BEVEL':mod.segments=3
    if subdivide:
        mod=ob.modifiers.new('Tailored surface refinement','SUBSURF');mod.levels=1;mod.render_levels=1
    for poly in ob.data.polygons:poly.use_smooth=True
    return ob

def bead(name,loc,scale,mat,parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1)
    ob=bpy.context.object;ob.name=name;ob.parent=parent;ob.location=loc;ob.scale=scale
    ob.data.transform(Matrix.Diagonal((*scale,1)))
    ob.scale=(1,1,1)
    ob.data.materials.append(mat)
    return soften(ob)

def rings(name,levels,mat,parent,n=16,closed=True):
    verts=[]
    for z,rx,ry,cy in levels:
        verts.extend((rx*math.sin(j*math.tau/n),cy-ry*math.cos(j*math.tau/n),z) for j in range(n))
    faces=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(levels)-1) for j in range(n)]
    if closed: faces += [tuple(range(n-1,-1,-1)),tuple(range((len(levels)-1)*n,len(levels)*n))]
    return soften(mesh(name,verts,faces,mat,parent,.006))

def build():
    s=iso_rig.create_rig('CREA',192)
    s.eevee.taa_render_samples=16
    s.render.threads_mode='FIXED';s.render.threads=8
    # Fixed scale; never zoom to fit individual poses. Original R4 pivot was 71%.
    s.camera.data.shift_y=.21
    s['render_px_per_u']=iso_rig.R;s['ground_pivot_px']=[96,136.32]
    s['character_design']='C4b human pilgrim: sculpted worn bronze, folded cloth, rounded volumes, ember eyes'
    leather=worn('Oiled charcoal leather','171B1C','57574D',0,.48)
    cloth=worn('Frayed rain cloak woven umber','232524','625F52',0,.9)
    bronze=worn('Patinated bronze plates','344A40','B5A27D',.72,.43)
    edge=worn('Worn brass edges and rivets','65563F','CAB491',.7,.4)
    iron=worn('Black forged iron','171B1C','494844',.65,.55)
    skin=worn('Weathered face','574237','A1876B',0,.88)
    dark=worn('Deep hood interior','090D0E','202525',0,.96)
    wood=worn('Charred torch haft','171411','4F3827',0,.85)
    fire=material('Single emissive accent - ash lord orange','FF681D',2.2,True)
    core=material('Flame hot heart same orange','FF681D',1.8,True)
    root=empty('Ardent_Root');body=empty('Torso',(0,0,.93),root)
    rings('Fitted cuirass',[(0,.145,.10,0),(.20,.17,.115,-.02),(.43,.245,.125,-.04),(.49,.16,.095,-.04)],leather,body)
    # Convex forged breastplate with scalloped articulations and recessed engraving.
    breast=[]
    for row in range(5):
        z=.12+row*.077
        width=.14+.04*math.sin(row*math.pi/5)
        for col in range(9):
            u=(col-4)/4
            breast.append((u*width,-.13-.065*(1-u*u),z+.012*math.cos(u*math.pi)))
    faces=[(r*9+c,r*9+c+1,(r+1)*9+c+1,(r+1)*9+c) for r in range(4) for c in range(8)]
    chest=soften(mesh('Sculpted convex bronze cuirass',breast,faces,bronze,body,.004),True)
    solid=chest.modifiers.new('Forged plate thickness','SOLIDIFY');solid.thickness=.018
    for side in (-1,1):
        rod('Engraved breastplate scroll',[(side*.035,-.198,.17),(side*.09,-.183,.23),(side*.12,-.168,.32),(side*.08,-.185,.38)],.004,iron,body)
        for z in (.17,.27,.39):bead('Hammered chest rivet',(side*.135,-.169,z),(.010,.008,.010),edge,body)
    for j in range(2):
        plate('Articulated abdomen',[(-.14,.035+j*.045),(0,.02+j*.045),(.14,.035+j*.045),(.14,.077+j*.045),(-.14,.077+j*.045)],-.144,.025,bronze,body)
    rod('Diagonal pilgrim baldric',[(-.19,-.15,.40),(-.06,-.21,.23),(.12,-.16,.02)],.021,leather,body)
    rings('Continuous oiled waist belt',[(-.015,.177,.13,0),(.045,.177,.13,0)],leather,body)
    box('Belt buckle',(.08,-.16,.01),(.07,.025,.065),edge,body,.009)
    for x in (-.20,.20):
        bead('Soft travel satchel',(x,.055,-.025),(.080,.065,.10),leather,body)
        box('Satchel folded flap',(x,.0,.015),(.14,.035,.07),cloth,body,.018)
        bead('Satchel clasp',(x,-.025,.01),(.012,.009,.015),edge,body)
    # Face is a narrow angular inset beneath a constructed open hood, no eyeballs.
    head=empty('Hood and face',(0,.065,.395),body);head.scale.z=.84
    rings('Sculpted gaunt face',[(.025,.058,.049,-.025),(.08,.079,.055,-.03),(.17,.072,.05,-.018),(.20,.049,.035,0)],skin,head,8)
    plate('Brow shadow',[(-.073,.145),(.074,.145),(.065,.18),(-.065,.18)],-.091,.012,dark,head)
    rod('Angular nose',[(0,-.091,.142),(0,-.117,.103),(0,-.094,.090)],.015,skin,head)
    plate('Lower face scarf',[(-.07,.01),(.065,.01),(.077,.075),(-.076,.08)],-.08,.025,cloth,head)
    # Hood fabric falls around an open face, with a rounded crown and rolled lip.
    for x in (-.032,.032):
        bead('Discrete ember eye',(x,-.094,.133),(.009,.005,.006),core,head)
    bead('Exposed angular chin',(0,-.073,.018),(.045,.033,.025),skin,head)
    hv=[];count=17
    for row,(z,rx,ry,cy) in enumerate([(-.035,.145,.115,.015),(.045,.14,.13,.005),(.17,.15,.13,.01),(.265,.10,.095,.01),(.30,.012,.025,.025)]):
        for j in range(count):
            t=.63+(math.tau-1.26)*j/(count-1)
            hv.append((rx*math.sin(t),cy-ry*math.cos(t),z+.009*math.cos(3*t)))
    hood=soften(mesh('Draped open rain hood',hv,[(r*count+j,r*count+j+1,(r+1)*count+j+1,(r+1)*count+j) for r in range(4) for j in range(count-1)],cloth,head,.002),True)
    mod=hood.modifiers.new('Hemmed cloth thickness','SOLIDIFY');mod.thickness=.009
    for j in (0,count-1):rod('Rolled hood opening',[hv[r*count+j] for r in range(5)],.010,leather,head)
    tails=[]
    for k in range(8):
        a=.48+k*(math.tau-.96)/8;b=.48+(k+1)*(math.tau-.96)/8
        ob=empty('Coat panel hinge %d'%k,(0,0,.03),body);vv=[]
        for row in range(7):
            w=row/6
            for col in range(7):
                t=a+(b-a)*col/6
                fold=.015*math.sin(col*math.pi+ k*.8)*(.35+w)
                radius=.17+.13*w+fold
                tear=(.020*math.sin(col*2.4+k)+(.045 if col in (2,5) else 0)) if row==6 else 0
                vv.append((math.sin(t)*radius,.025+.09*w-math.cos(t)*radius,-.65*w+tear))
        panel=soften(mesh('Folded torn coat gore',vv,[(r*7+c,r*7+c+1,(r+1)*7+c+1,(r+1)*7+c) for r in range(6) for c in range(6)],cloth,ob),True)
        mod=panel.modifiers.new('Woven cloth hem','SOLIDIFY');mod.thickness=.006
        rod('Coat raised seam',[vv[r*7] for r in range(7)],.004,leather,ob)
        tails.append(ob)
    # Shoulder mantle, irregular plate pauldrons, straps and visible rivets.
    for side in (-1,1):
        arm=empty('Arm '+str(side),(side*.225,-.02,.39),body)
        rings('Tailored upper sleeve',[(.015,.065,.065,0),(-.06,.085,.077,0),(-.18,.070,.065,-.01),(-.26,.055,.055,-.025)],cloth,arm)
        fore=empty('Forearm',(0,-.025,-.25),arm)
        endpoint=(.20,-.18,-.345) if side==1 else (side*.02,-.08,-.19)
        rod('Fitted gauntlet sleeve',[(0,0,0),endpoint],.058,iron if side==1 else leather,fore)
        bead('Curved gripping glove',endpoint,(.048,.045,.056),leather,fore)
        axis=Vector(endpoint);q=axis.to_track_quat('Z','Y')
        for j in range(6):
            center=axis*(.22+j*.105)
            wrap=rings('Overlapping forearm linen wrap',[(-.014,.061,.060,0),(.014,.061,.060,0)],cloth,fore)
            wrap.location=center;wrap.rotation_euler=q.to_euler()
        if side==1: torch_hand=fore;torch_grip=endpoint
        if side==1:
            bead('Bronze wrist guard',tuple(Vector(endpoint)*.79),(.063,.053,.035),bronze,fore)
        bead('Sculpted domed bronze pauldron',(side*.025,0,-.015),(.133,.108,.089),bronze,arm)
        rod('Pauldron chased border',[(-.10,-.06,-.04),(0,-.105,-.055),(.11,-.06,-.04)],.009,edge,arm)
        for j in range(3):rod('Pauldron engraved rays',[(j*.035-.04,-.104,-.035),(j*.04-.045,-.095,.02)],.004,iron,arm)
        for x in (-.07,.07): box('Shoulder brass rivet',(x,-.10,.015),(.019,.014,.019),edge,arm,.004)
        arm['side']=side
    # Human legs: hip/knee hierarchy, shaped boots rather than round toy feet.
    legs=[]
    for side in (-1,1):
        leg=empty('Hip '+str(side),(side*.095,0,.91),root)
        rings('Leather trouser',[(0,.075,.075,0),(-.20,.066,.065,0),(-.37,.054,.055,0)],leather,leg,8)
        knee=empty('Knee',(0,0,-.37),leg)
        rings('Tall fitted rain boot',[(0,.058,.056,0),(-.24,.045,.048,0),(-.39,.055,.065,-.02)],leather,knee,8)
        box('Angular boot sole',(0,-.075,-.48),(.12,.25,.075),iron,knee,.008)
        box('Boot instep',(0,-.055,-.43),(.105,.19,.095),leather,knee,.009)
        plate('Patinated knee plate',[(-.05,-.07),(.05,-.07),(.065,.04),(0,.075),(-.065,.04)],-.065,.024,bronze,knee,.006)
        legs.append((leg,knee))
    # Hand brazier staff, offset to keep fire separate from face in frontal view.
    torch=empty('Torch',torch_grip,torch_hand)
    rod('Octagonal scorched staff',[(0,0,-.56),(0,0,.18)],.034,wood,torch)
    for z in (-.12,.10): rings('Staff bronze ferrule',[(z,.034,.034,0),(z+.055,.034,.034,0)],edge,torch,8)
    rings('Forged open brazier cup',[(.10,.045,.045,0),(.20,.086,.086,0),(.24,.079,.079,0)],iron,torch,8,False)
    for j in range(4):
        a=j*math.pi/2
        rod('Brazier cage tooth',[(.065*math.cos(a),.065*math.sin(a),.17),(.08*math.cos(a),.08*math.sin(a),.30)],.009,edge,torch)
    flames=[]
    for j in range(4):
        ob=rings('Living flame tongue',[(.19,.054,.045,0),(.29,.066,.044,0),(.40,.035,.026,.018),(.54+j*.015,.001,.001,.052)],core if j==1 else fire,torch,7)
        ob.location=(.035*(j-1.5),.022*math.sin(j*2),-.025*j);flames.append(ob)
    for j in range(5):
        spark=bead('Rising orange ember',(.10*math.sin(j*2),.045*math.cos(j),.39+j*.043),(.006,.006,.012),fire,torch);flames.append(spark)
    bpy.ops.object.light_add(type='POINT');light=bpy.context.object;light.name='Local warm flame bounce';light.parent=torch;light.location=(0,-.025,.33);light.data.energy=12;light.data.color=(1,.22,.035);light.data.shadow_soft_size=.13
    # A restrained warm rim separates the dark mantle from the C1 ground.
    bpy.ops.object.light_add(type='AREA',location=(-2,2,3));rim=bpy.context.object;rim.name='Warm rain silhouette rim';rim.data.energy=350;rim.data.color=(1,.56,.27);rim.data.shape='DISK';rim.data.size=2
    rim.rotation_euler=(Vector((0,0,1))-rim.location).to_track_quat('-Z','Y').to_euler()
    # Apply the useful one-level refinement to the deliverable mesh topology.
    for ob in root.children_recursive:
        if ob.type!='MESH':continue
        for mod in ob.modifiers:
            if mod.type=='BEVEL':mod.segments=3
        bpy.context.view_layer.objects.active=ob
        for mod in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    iso_rig.bake_ao_shadows(root)
    for anim,start in [('idle',1),('run',21)]:
        s.timeline_markers.new(anim,frame=start)
        for i in range(9):
            t=math.tau*i/8;f=start+i;running=anim=='run'
            body.location.z=.93+(.025*math.cos(2*t) if running else .006*math.sin(t))
            body.rotation_euler=(.24 if running else .035,.012*math.cos(t),.04*math.cos(t) if running else .008*math.cos(t))
            for ob in (body,):
                ob.keyframe_insert('location',frame=f);ob.keyframe_insert('rotation_euler',frame=f)
            for index,(leg,knee) in enumerate(legs):
                phase=t+index*math.pi
                leg.rotation_euler.x=(.72*math.sin(phase) if running else .012*math.sin(phase))
                knee.rotation_euler.x=(.15+.75*max(0,-math.sin(phase)) if running else .025)
                for ob in (leg,knee):ob.keyframe_insert('rotation_euler',frame=f)
            for arm in [o for o in body.children if 'side' in o]:
                arm.rotation_euler.x=(-arm['side']*(.05 if arm['side']==1 else .44)*math.sin(t) if running else .018*math.sin(t))
                arm.rotation_euler.y=-.12 if arm['side']==1 else .05
                arm.keyframe_insert('rotation_euler',frame=f)
            for j,ob in enumerate(tails):
                ob.rotation_euler=(.33+.23*math.sin(t-.7+j*.33) if running else .018*math.sin(t+j*.3),.03*math.cos(t+j),0)
                ob.keyframe_insert('rotation_euler',frame=f)
            torch.rotation_euler.x=-.12+.06*math.sin(t) if running else .02*math.sin(t)
            torch.keyframe_insert('rotation_euler',frame=f)
            for j,ob in enumerate(flames):
                ob.scale=(1+.13*math.sin(t+j),1+.09*math.cos(t+j),1+.12*math.sin(t+j*1.7))
                ob.rotation_euler.y=.18*math.sin(t+j);ob.keyframe_insert('scale',frame=f);ob.keyframe_insert('rotation_euler',frame=f)
            light.data.energy=12+2*math.sin(t);light.data.keyframe_insert('energy',frame=f)
    s.frame_start=1;s.frame_end=29;s.render.fps=14
    s['animation_manifest']=json.dumps({'idle':{'start':1,'frames':8},'run':{'start':21,'frames':8},'directions':list(DIRECTIONS)})
    from bpy_extras.object_utils import world_to_camera_view
    bounds=[192.,192.,0.,0.];top=None
    for start in (1,21):
        for angle in DIRECTIONS.values():
            root.rotation_euler.z=angle
            for i in range(8):
                s.frame_set(start+i);bpy.context.view_layer.update()
                for ob in root.children_recursive:
                    if ob.type!='MESH':continue
                    for v in ob.data.vertices:
                        q=world_to_camera_view(s,s.camera,ob.matrix_world@v.co)
                        x,y=q.x*192,(1-q.y)*192
                        if y<bounds[1]:top=[ob.name,start,i,angle,list(ob.matrix_world@v.co)]
                        bounds=[min(bounds[0],x),min(bounds[1],y),max(bounds[2],x),max(bounds[3],y)]
    (ROOT/'art/tools/characters/ardent_iso_bounds.json').write_text(json.dumps({'projected_union':bounds,'top':top,'pivot':[96,136.32],'R':iso_rig.R}))
    print('C4 projected union '+str([round(v,2) for v in bounds]),flush=True)
    assert min(bounds[:2])>=5 and max(bounds[2:])<=187, 'Geometry exceeds shared frame margin'
    s.frame_set(1);root.rotation_euler.z=0
    bpy.context.preferences.filepaths.save_version=0
    BLEND.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    if '--build-only' in sys.argv:return
    for anim,start in [('idle',1),('run',21)]:
        for direction,angle in DIRECTIONS.items():
            root.rotation_euler.z=angle
            for i in range(8):
                path=OUT/anim/(direction+'_%02d.png'%i)
                if '--resume' in sys.argv and all(path.with_name(path.stem+su+'.png').exists() for su in ('','_n','_e')):continue
                s.frame_set(start+i);iso_rig.render_frame(path)
            print('C4 rendered '+anim+' '+direction,flush=True)
    print('C4 RENDER PASS',flush=True)

if __name__=='__main__':build()
