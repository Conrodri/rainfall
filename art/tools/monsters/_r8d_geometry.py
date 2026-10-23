"""Drowned terraces: enclosed sculpts, R8a procedural PBR and CREA studio."""
from _r8b_geometry import studio, taper, thorn, shell
from ash_lord_build import worn, mesh, plate, rod, shard, iso_rig
from boss_pipeline import *
import random, math

def palette():
    return (worn('Wet fractured basalt','242E30','77817B',0,.57),
            worn('Fresh chipped wet stone','475453','9BA99E',0,.6),
            worn('Patinated bronze','283F3B','5F8F80',.65,.56),
            worn('Verdigris worn rims','5F8F80','8DBBA8',.55,.6),
            worn('Black iron in crevices','11191C','434C49',.65,.58),
            worn('Soaked matted bear fur','283238','8A9692',0,.83),
            worn('Dirty glacial ice','354E54','A7BDB8',.15,.34),
            material('Cold blue eyes - sole emission','62BCE8',1.5,True))

def rock(name,loc,scale,mat,parent,seed=0):
    rng=random.Random(seed);N=7;v=[]
    for z,r in [(-1,.67),(-.7,1),(.53,1),(1,.63)]:
        for j in range(N):
            a=j*math.tau/N;rr=r*rng.uniform(.88,1.1)
            v.append((loc[0]+scale[0]*rr*math.cos(a),loc[1]+scale[1]*rr*math.sin(a),loc[2]+scale[2]*(z+rng.uniform(-.055,.055))))
    f=[tuple(range(N-1,-1,-1)),tuple(range(3*N,4*N))]
    f.extend((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j) for i in range(3) for j in range(N))
    return mesh(name,v,f,mat,parent,.012)

def bear():
    studio();stone,edge,bronze,patina,iron,fur,ice,glow=palette()
    root=empty('FrostBear');body=empty('Long low bear body',parent=root)
    # Anatomical shoulder saddle, deep chest and lean posterior; layered fur follows muscle.
    shell('Long ribcage',(0,.10,1.04),(.60,.92,.48),fur,body)
    shell('Massive scapular hump',(0,-.45,1.19),(.68,.53,.58),fur,body)
    shell('Sloping muscular hindquarters',(0,.72,.96),(.5,.43,.44),fur,body)
    for side in (-1,1):
        for j in range(12):
            y=-.77+j*.14;z=1.05+.18*math.cos(j*.32)
            thorn('Clumped hanging wet guard hair',(side*.48,y,z+.18),(side*.63,y+.06,z-.04),(side*.53,y+.19,z-.26),.105,fur,body)
        for j in range(3):
            y=-.45+j*.16
            thorn('Broken shoulder ice plate',(side*.27,y,1.56),(side*.39,y+.04,1.81),(side*.45,y+.13,1.92+j*.03),.12,ice,body)
    head=empty('Low muzzle head',(0,-.87,.97),body)
    rock('Angular bear cranium',(0,-.10,.04),(.37,.36,.31),fur,head,3)
    shell('Long tapered muzzle',(0,-.43,-.12),(.25,.31,.17),fur,head)
    rock('Wet black nose',(0,-.70,-.07),(.17,.055,.085),iron,head,5)
    plate('Recessed snarling mouth',[(-.23,-.20),(.23,-.20),(.19,-.29),(-.18,-.28)],-.51,.27,iron,head)
    for sign in (-1,1):
        shell('Small torn bear ear',(sign*.29,.015,.28),(.105,.08,.12),fur,head)
        plate('Narrow cold blue eye',[(sign*.18,.06),(sign*.31,.09),(sign*.29,.035),(sign*.19,.025)],-.352,.018,glow,head,.002)
        rod('Heavy overhanging brow',[(sign*.14,-.36,.12),(sign*.29,-.36,.15),(sign*.37,-.28,.08)],.045,fur,head)
        thorn('Long chipped canine',(sign*.16,-.51,-.18),(sign*.16,-.53,-.28),(sign*.14,-.55,-.36),.041,ice,head)
        for j in range(4):
            thorn('Ragged cheek mane',(sign*.28,-.08+j*.065,-.05),(sign*.41,j*.06,-.14),(sign*.35,.11+j*.07,-.35),.08,fur,head)
    legs=[]
    for y in (-.55,.64):
        for sign in (-1,1):
            leg=empty('Front paw' if y<0 else 'Hind paw',(sign*.46,y,.85),body);legs.append((leg,sign,y))
            shell('Weight bearing upper limb',(0,0,-.11),(.245,.27,.37),fur,leg)
            taper('Angular shin',[(0,.02,-.25),(0,-.02,-.49),(0,-.10,-.65)],[.17,.15,.14],fur,leg)
            rock('Broad splayed bear paw',(0,-.16,-.69),(.26,.31,.14),fur,leg,8)
            if y<0:
                rod('Old bronze shackle',[(-.22,-.02,-.45),(-.17,-.17,-.45),(.18,-.17,-.45),(.23,0,-.45)],.042,bronze,leg)
            for j in range(4):
                x=(j-1.5)*.12
                thorn('Black hooked claw',(x,-.33,-.63),(x,-.44,-.67),(x,-.49,-.75),.038,iron,leg)
    for j in range(7):
        y=-.56+j*.21
        for sign in (-1,1):
            h=.33+(j%3)*.13
            thorn('Ragged dorsal glacial spear',(sign*.18,y,1.43),(sign*.27,y+.03,1.65),(sign*.34,y+.13,1.59+h),.12,ice,body)
    breath=empty('Volumetric frost breath',(0,-.61,-.1),head)
    for j in range(11):
        a=j*2.4;r=.035+j*.011
        rock('Windblown dirty ice shard',(math.sin(a)*r,-.15-j*.105,math.cos(a)*r),(.035+j*.004,.12,.04+j*.003),ice,breath,j)
    crown=empty('Roar ice motes',parent=root)
    for j in range(9):
        a=j*math.tau/9;x=math.cos(a)*.76;y=math.sin(a)*.84
        thorn('Rising volumetric ice',(x,y,.09),(x*1.04,y*1.04,.3),(x*1.10,y*1.10,.6+(j%3)*.08),.09,ice,crown)
    iso_rig.bake_ao_shadows(root)
    return root,body,head,legs,breath,crown,glow

def colossus():
    studio();stone,edge,bronze,patina,iron,fur,ice,fire=palette()
    root=empty('StoneColossus');body=empty('Massive block torso',parent=root)
    # Staggered masonry buttresses around a recessed iron-bound core.
    rock('Basalt chest monolith',(0,.03,1.56),(.70,.43,.57),stone,body,21)
    rock('Broken masonry pelvis',(0,.03,.84),(.49,.34,.23),stone,body,31)
    for sign in (-1,1):
        for j in range(3):
            rock('Overlapping chest masonry',(sign*(.25+j*.08),-.34,1.83-j*.21),(.30,.12,.13),stone,body,j+int(sign)*10)
        rod('Verdigris chest staple',[(sign*.52,-.38,1.94),(sign*.55,-.47,1.56),(sign*.42,-.4,1.25)],.035,bronze,body)
        for j in range(3):shard('Worn bronze bolt',(sign*.54,-.48,1.84-j*.22),(.038,.026,.035),patina,body)
    rock('Small eroded keystone head',(0,-.12,2.21),(.30,.29,.30),stone,body,17)
    jaw=empty('Roaring lower jaw',(0,-.3,1.96),body)
    rock('Separated stone lower jaw',(0,-.045,.035),(.24,.17,.10),edge,jaw,4)
    plate('Dark sunken face',[(-.23,.0),(.23,.0),(.25,.22),(-.24,.22)],-.414,.03,iron,body)
    # Face coordinates are in body space.
    for o in list(body.children):
        if o.name.startswith('Dark sunken'):o.location.z=2.04
    for sign in (-1,1):
        plate('Recessed blue eye slit',[(sign*.055,2.18),(sign*.21,2.19),(sign*.18,2.14),(sign*.06,2.14)],-.449,.012,fire,body,.002)
        rod('Slanted basalt brow',[(sign*.02,-.45,2.26),(sign*.20,-.45,2.29),(sign*.29,-.36,2.26)],.07,stone,body)
    for x,z in [(-.27,1.95),(.18,1.73),(-.10,1.46)]:
        rod('Recessed cold crack',[(x,-.443,z),(x+.045,-.445,z-.09),(x-.025,-.444,z-.19)],.009,fire,body)
    arms=[];legs=[];chunks=[]
    for sign in (-1,1):
        leg=empty('Stone leg',(sign*.37,0,.73),body);legs.append((leg,sign))
        rock('Fractured basalt shin',(0,0,-.25),(.26,.27,.34),stone,leg,12)
        rock('Heavy wedge foot',(0,-.16,-.60),(.32,.40,.15),stone,leg,2)
        rod('Oxidised shin staple',[(-.18,-.27,-.03),(-.19,-.29,-.4),(.13,-.3,-.5)],.035,bronze,leg)
        arm=empty('Hammer shoulder',(sign*.81,0,1.8),body);arms.append((arm,sign))
        rock('Jagged cantilever shoulder',(0,0,.02),(.39,.43,.33),stone,arm,8+sign)
        rock('Hanging upper arm',(sign*.03,.02,-.35),(.25,.27,.29),iron,arm,13)
        rock('Massive asymmetric basalt fist',(sign*.08,-.02,-.78),(.38,.39,.37 if sign==1 else .32),stone,arm,6)
        for j in range(3):
            rock('Carved broken knuckle',((j-1)*.19,-.37,-.80),(.11,.09,.18),edge,arm,11+j)
        rod('Bronze fist binding',[(-.31,-.16,-.55),(-.25,-.39,-.55),(.27,-.39,-.55),(.34,-.1,-.55)],.038,bronze,arm)
        for j in range(3):shard('Fist binding rivet',((j-1)*.22,-.43,-.55),(.034,.022,.034),patina,arm)
        thorn('Broken shoulder crest',(sign*.07,0,.24),(sign*.22,.02,.39),(sign*.28,.10,.51),.13,stone,arm)
    for j in range(7):
        o=rock('Detaching fractured stone',(0,0,0),(.10,.12,.15),stone,body,19+j);o.location=(math.sin(j*2.4)*.52,.22,1.05+j*.14);chunks.append((o,o.location.copy()))
    wave=empty('Volumetric rubble and dark water shockwave',parent=root)
    water=worn('Dark terrace water','14282D','426365',.3,.26)
    for j in range(15):
        a=j*math.tau/15;x=math.cos(a)*.84;y=math.sin(a)*.74
        rock('Thrown angular rubble',(x,y,.16+(j%3)*.09),(.11,.09,.12),stone,wave,j)
        thorn('Solid water splash',(x*.82,y*.82,.04),(x,y,.20),(x*1.1,y*1.1,.32+(j%4)*.05),.055,water,wave)
    iso_rig.bake_ao_shadows(root)
    return root,body,jaw,arms,legs,chunks,wave,fire
