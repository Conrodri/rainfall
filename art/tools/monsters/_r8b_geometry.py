"""R8b mist forest sculpts. Shared R8a PBR, studio, AO and swept geometry.
Only enclosed meshes for cast effects; existing pose hierarchies are preserved.
"""
from ash_lord_build import worn, mesh, plate, rod, shard, iso_rig
from boss_pipeline import *
import math

def studio():
    s=iso_rig.create_rig('CREA',170);s.eevee.taa_render_samples=16
    s['diffuse_contour_pixels']=0;s['r8b_camera_elevation']=30
    return s

def palette():
    return (worn('Mist black iron','181F21','5D6865',.65,.58),
            worn('Weathered deadwood','242E2B','6F7865',0,.88),
            worn('Bleached lichen bone','58665C','ADB8A0',0,.85),
            worn('Moss in crevices','202D29','526653',0,.93),
            worn('Old chitin','202C2C','697E77',.25,.65),
            worn('Mist torn weave','1D292B','566761',0,.92),
            material('Lantern pale cyan - sole emission','9BE5CF',1.6,True))

def taper(name,points,radii,mat,parent):
    verts=[];N=7
    for i,p in enumerate(points):
        axis=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        q=axis.to_track_quat('Z','Y')
        verts.extend(Vector(p)+q@Vector((radii[i]*math.cos(j*math.tau/N),radii[i]*math.sin(j*math.tau/N),0)) for j in range(N))
    faces=[tuple(range(N-1,-1,-1)),tuple(range((len(points)-1)*N,len(points)*N))]
    faces.extend((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j) for i in range(len(points)-1) for j in range(N))
    return mesh(name,verts,faces,mat,parent)

def thorn(name,a,b,c,r,mat,parent):
    return taper(name,[a,b,c],[r,r*.6,.003],mat,parent)

def shell(name,loc,scale,mat,parent):
    # Lathed pointed shell with eight ridges and five shaped cross sections.
    v=[];N=10
    for z,r in [(-1,.08),(-.7,.70),(0,1),(.65,.74),(1,.07)]:
        v.extend((scale[0]*r*math.cos(j*math.tau/N)+loc[0],scale[1]*r*math.sin(j*math.tau/N)+loc[1],z*scale[2]+loc[2]) for j in range(N))
    f=[tuple(range(N-1,-1,-1)),tuple(range(4*N,5*N))]
    f.extend((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j) for i in range(4) for j in range(N))
    return mesh(name,v,f,mat,parent,.009)

def queen():
    studio();iron,bark,bone,moss,chitin,rag,glow=palette()
    root=empty('BrambleQueen');body=empty('Slender queen',parent=root)
    # Broad, articulated root mantle, narrow waist and tall antler crown.
    shell('Splintered trunk corset',(0,.02,1.45),(.34,.24,.62),bark,body)
    for j in range(9):
        a=j*math.tau/9;x=math.cos(a);y=math.sin(a)
        pts=[(x*.19,y*.17,1.46),(x*.34,y*.29,.93),(x*.61,y*.48,.41),(x*.72,y*.60,.07)]
        taper('Fluted root buttress',pts,[.12,.14,.12,.018],bark,body)
        rod('Moss seam',[(px-.025,py-.012,pz) for px,py,pz in pts[1:]],.018,moss,body)
        plate('Ragged mourning skirt',[(x*.18,1.30),(x*.40+.07,.82),(x*.50+.05,.29),(x*.53-.07,.12),(x*.23-.04,.75)],y*.30,.028,rag,body)
    for j in range(5):
        z=1.44+j*.105
        for sign in (-1,1):
            rod('Iron thorn corset rib',[(sign*.03,-.24,z),(sign*.25,-.18,z+.08),(sign*.32,.01,z+.09)],.025,iron,body)
    shell('Caged lantern heart',(0,-.25,1.69),(.065,.055,.13),glow,body)
    head=empty('Head',(0,-.04,2.13),body)
    shell('Elongated wooden funeral mask',(0,0,0),(.14,.12,.245),bone,head)
    plate('Recessed black mask',[(-.12,.07),(0,.15),(.12,.07),(.09,-.14),(0,-.20),(-.085,-.13)],-.126,.018,iron,head)
    for sign in (-1,1):
        plate('Broken cheek crest',[(sign*.025,.15),(sign*.145,.12),(sign*.17,-.015),(sign*.08,-.19),(sign*.09,.025)],-.15,.045,bone,head)
        rod('Narrow lantern eye',[(sign*.025,-.158,.045),(sign*.092,-.166,.063)],.013,glow,head)
    thorn('Pointed chin',(0,-.15,-.10),(0,-.17,-.20),(.025,-.14,-.29),.04,bark,head)
    for j in range(7):
        a=j*math.tau/7;x=math.cos(a);y=math.sin(a);h=.43+.13*(j%3)
        pts=[(x*.12,y*.11,.13),(x*.23,y*.17,.31),(x*.35,y*.24,h),(x*.29,y*.25,h+.17)]
        taper('Ancient antler thorn crown',pts,[.052,.045,.027,.003],bone,head)
        thorn('Forked crown splinter',pts[1],(x*.35,y*.25,.34),(x*.47,y*.28,.40),.025,bark,head)
    arms=[]
    for sign in (-1,1):
        arm=empty('Branch arm',(sign*.40,.015,1.91),body);arms.append((arm,sign))
        shell('Black iron shoulder',(sign*.04,0,-.02),(.25,.22,.20),iron,arm)
        for k in range(3):
            thorn('Shoulder thicket',(sign*(.07+k*.06),.03,-.02),(sign*(.17+k*.08),.06,.19),(sign*(.26+k*.09),.09,.29-k*.05),.06,bark,arm)
        taper('Gnarled upper branch',[(0,0,-.08),(sign*.07,-.02,-.28),(sign*.10,-.02,-.51)],[.095,.075,.06],bark,arm)
        taper('Armoured forearm',[(sign*.10,-.02,-.49),(sign*.12,-.08,-.70),(sign*.07,-.13,-.91)],[.08,.105,.04],iron,arm)
        for j in range(3):
            thorn('Barbed arm',(sign*.11,.02,-.50-j*.14),(sign*.28,.02,-.42-j*.14),(sign*.30,.02,-.28-j*.14),.039,bone,arm)
        for k in range(4):
            x=sign*.07+(k-1.5)*.045
            taper('Long grasping twig claw',[(x,-.13,-.90),(x+(k-1.5)*.035,-.17,-1.04),(x+(k-1.5)*.04,-.27,-1.13)],[.024,.017,.002],bark,arm)
    train=empty('Root train',(0,.22,.10),body);roots=[]
    for j in range(9):
        a=math.radians(-62+j*15.5);r=empty('Root',parent=train);r.rotation_euler.z=a;roots.append(r)
        pts=[(0,0,0),(.07,.35,.08),(-.04,.70,.03),(.12,.96+.08*(j%3),-.03)]
        taper('Serpentine trailing root',pts,[.10,.09,.05,.003],bark,r)
        thorn('Trailing root barb',pts[2],(.02,.74,.22),(.09,.81,.32),.037,bone,r)
    puddle=empty('Poison pools',parent=root)
    for j in range(3):
        x=(j-1)*.61;y=-.53-.1*(j%2)
        for k in range(5):
            a=k*math.tau/5
            pts=[(x+math.cos(a)*.29,y+math.sin(a)*.24,.06),(x+math.cos(a+.5)*.25,y+math.sin(a+.5)*.23,.25),(x+math.cos(a+1)*.21,y+math.sin(a+1)*.18,.42)]
            taper('Volumetric venom bramble',pts,[.065,.055,.003],bark,puddle)
            shell('Lantern seed in thornbed',(pts[1][0],pts[1][1]-.025,.19),(.028,.029,.06),glow,puddle)
    ringo=empty('Summon ring',parent=root)
    for j in range(7):
        a=j*math.tau/7;x=math.cos(a)*.81;y=math.sin(a)*.72
        thorn('Rising hooked briar',(x,y,.05),(x*1.03,y*1.03,.55),(x*.78,y*.78,.96),.095,bark,ringo)
        thorn('Summon side barb',(x,y,.35),(x*1.19,y*1.19,.52),(x*1.22,y*1.22,.66),.04,bone,ringo)
    chunks=[]
    for j in range(6):
        o=shard('Falling bark fragment',(math.sin(j*2.4)*.33,.12,1.2+j*.13),(.04,.045,.10),bark,body);chunks.append((o,o.location.copy()))
    iso_rig.bake_ao_shadows(root)
    return root,body,head,arms,roots,puddle,ringo,chunks,glow

def brood():
    studio();iron,bark,bone,moss,shellmat,wing,core=palette();belly=core
    root=empty('BroodMother');body=empty('Inverted drop body',parent=root)
    shell('Ridged thoracic cuirass',(0,-.17,1.02),(.43,.48,.40),shellmat,body)
    head=empty('Head',(0,-.60,1.02),body)
    shell('Predatory head shield',(0,0,.02),(.28,.28,.21),iron,head)
    for sign in (-1,1):
        plate('Recessed compound eye',[(sign*.08,.075),(sign*.22,.11),(sign*.19,.04),(sign*.09,.015)],-.245,.018,core,head)
        thorn('Sickle mandible',(sign*.12,-.16,-.10),(sign*.26,-.35,-.16),(sign*.075,-.43,-.20),.064,bone,head)
        taper('Jointed antenna',[(sign*.12,-.15,.16),(sign*.24,-.27,.35),(sign*.22,-.47,.50)],[.025,.02,.004],shellmat,head)
    abd=empty('Abdomen pivot',(0,.18,1.12),body)
    shell('Dark brood sac',(0,.55,.10),(.70,.90,.64),moss,abd)
    # Overlapping ridged carapace segments: the belly stays dark, light leaks through seams.
    for j in range(6):
        y=-.02+j*.235;w=.53+.16*math.sin((j+1)*.55);z=.10+.54*math.sin((j+1)*.48)
        for sign in (-1,1):
            pts=[(sign*.035,y-.10,z+.08),(sign*w*.60,y-.04,z+.01),(sign*w,y+.015,.13),(sign*w*.83,y+.04,-.25)]
            taper('Overlapping scuted abdomen',pts,[.10,.14,.13,.035],shellmat,abd)
            rod('Worn ridge on shell',[(x,yy-.095,zz+.02) for x,yy,zz in pts[:3]],.018,bone,abd)
            if j in (1,3,4):
                rod('Lantern slit between scutes',[(sign*w*.65,y-.105,z-.09),(sign*w*.86,y-.06,.20)],.018,core,abd)
            thorn('Abdominal backward spine',(sign*w*.93,y+.02,.13),(sign*(w+.15),y+.12,.22),(sign*(w+.18),y+.26,.16),.065,iron,abd)
    thorn('Ovipositor',(0,1.29,.02),(0,1.40,-.23),(0,1.31,-.53),.13,iron,abd)
    for j in range(4):
        shell('Brood window',(0,.18+j*.26,.53+math.sin(j*.7)*.11),(.045,.065,.026),core,abd)
    wings=[]
    for sign in (-1,1):
        w=empty('Wing',(sign*.32,.02,1.34),body);wings.append((w,sign))
        # Enclosed angular wing plates, thick at leading edge and tapering at tip.
        for k in range(2):
            pts=[(0,k*.13,0),(sign*.35,.18+k*.22,.11),(sign*.73,.52+k*.25,.12),(sign*.97,.72+k*.24,.02)]
            taper('Folded leathery wing volume',pts,[.045,.16,.115,.004],wing,w)
            rod('Raised leading wing vein',[(x,y-.06,z+.03) for x,y,z in pts],.022,bone,w)
            for l in (1,2):
                x,y,z=pts[l];rod('Wing cross vein',[(x-sign*.08,y-.12,z+.03),(x+sign*.12,y+.10,z+.035)],.012,shellmat,w)
    legs=[]
    for k,y in enumerate((-.36,-.02,.35)):
        for sign in (-1,1):
            leg=empty('Thin leg',(sign*.34,y,1.0),body);legs.append((leg,sign,k))
            a=(0,0,0);b=(sign*.46,-.22+.16*k,.27);c=(sign*.77,-.36+.21*k,-.25);d=(sign*.89,-.46+.24*k,-.96)
            taper('Armoured femur',[a,(sign*.22,-.08,.17),b],[.095,.11,.055],shellmat,leg)
            shell('Angular knee',b,(.092,.09,.09),iron,leg)
            taper('Bladed tibia',[b,c,d],[.066,.071,.009],shellmat,leg)
            rod('Exposed tibia ridge',[b,c],.018,bone,leg)
            thorn('Knee hooked thorn',b,(b[0]+sign*.14,b[1],b[2]+.15),(b[0]+sign*.11,b[1]-.04,b[2]+.26),.042,bone,leg)
    eggs=empty('Eggs ring',parent=root)
    for j in range(7):
        a=j*math.tau/7;loc=(math.cos(a)*.66,math.sin(a)*.68,.16)
        shell('Ribbed brood egg',loc,(.11,.12,.19),moss,eggs)
        for sign in (-1,1):
            rod('Egg shell cage',[(loc[0]+sign*.07,loc[1]-.08,.09),(loc[0]+sign*.055,loc[1]-.09,.25),(loc[0],loc[1],.35)],.018,shellmat,eggs)
        shell('Egg lantern slit',(loc[0],loc[1]-.108,.17),(.019,.018,.073),core,eggs)
    swarm=empty('Swarm',parent=root)
    flymesh=None
    for j in range(12):
        a=j*math.tau/12;r=.66+.17*(j%2);z=.62+.29*(j%3)
        fly=empty('Animated volumetric drone',(math.cos(a)*r,math.sin(a)*r,z),swarm)
        if flymesh is None:
            ob=shell('Drone chitin',(0,0,0),(.065,.13,.06),shellmat,fly);flymesh=ob.data
        else:
            ob=bpy.data.objects.new('Drone chitin',flymesh);bpy.context.collection.objects.link(ob);ob.parent=fly
            ob.material_slots[0].link='OBJECT';ob.material_slots[0].material=shellmat
        for sign in (-1,1):
            taper('Drone volumetric wing',[(sign*.03,0,.025),(sign*.12,.015,.09),(sign*.20,.06,.08)],[.02,.045,.002],wing,fly)
            rod('Drone leg',[(sign*.03,-.02,-.02),(sign*.07,-.08,-.08)],.009,iron,fly)
        shard('Drone lantern',(0,-.10,.01),(.018,.021,.019),core,fly)
    chunks=[]
    for j in range(6):
        o=shard('Burst chitin shard',(math.sin(j*2.4)*.32,.46+math.cos(j*2.4)*.22,.42+j*.025),(.09,.10,.05),shellmat,abd);chunks.append((o,o.location.copy()))
    iso_rig.bake_ao_shadows(root)
    return root,body,head,abd,wings,legs,eggs,swarm,chunks,core,belly
