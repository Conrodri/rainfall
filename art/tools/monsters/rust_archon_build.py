"""R8c: massive hollow rust archon, R8a PBR/studio/AO, closed cast volumes.
Preserved pose hierarchy, seven timelines and legacy atlas contract.
"""
import sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
from ash_lord_build import worn,mesh,plate,rod,shard,iso_rig

def build():
    s=iso_rig.create_rig('CREA',170);s.eevee.taa_render_samples=16
    s['diffuse_contour_pixels']=0;s['r8c_height_units']=2.8
    rust=worn('Pitted rust #6B3A22','3E2419','6B3A22',.5,.76)
    iron=worn('Black iron #2B2A29','191A19','55514A',.65,.58)
    edge=worn('Tarnished brass #A8946E','514633','A8946E',.65,.62)
    leather=worn('Scorched leather straps','201A17','59422C',0,.9)
    cloth=worn('Burnt burial cloth','17191A','49443B',0,.94)
    dark=worn('Empty armour cavity','080908','1B1B19',.2,.9)
    cyan=material('Sole accent - ember orange','FF681D',1.8,True)
    root=empty('RustArchon');body=empty('Floating hollow armor',parent=root);pieces=[]
    def armor(name,pts,y,thick,mat,parent=body):
        o=plate(name,pts,y,thick,mat,parent,.012)
        if parent==body:
            center=Vector((sum(x for x,z in pts)/len(pts),y+thick/2,sum(z for x,z in pts)/len(pts)))
            for v in o.data.vertices:v.co-=center
            o.location=center;pieces.append((o,center.copy()))
        return o
    # Deep open cuirass: folded asymmetric plates and brass ribs around darkness.
    armor('Rear cuirass silhouette',[(-.46,1.48),(-.53,2.19),(-.31,2.34),(.36,2.32),(.48,2.08),(.39,1.48)],.22,.12,iron)
    for sign in (-1,1):
        def pts(coords):return [(sign*x,z) for x,z in coords]
        armor('Overlapping breastplate',pts([(.10,2.22),(.40,2.30),(.55,2.05),(.40,1.71),(.15,1.59),(.23,1.94)]),-.22,.18,rust)
        armor('Chipped breast rim',pts([(.10,2.22),(.16,2.23),(.29,1.94),(.20,1.62),(.15,1.59),(.23,1.94)]),-.237,.026,edge)
        for j in range(3):
            z=1.75+j*.14
            rod('Riveted cuirass flute',[(sign*.32,-.27,z),(sign*.45,-.15,z+.06),(sign*.48,.07,z+.07)],.025,iron,body)
            shard('Brass chest rivet',(sign*.34,-.284,z),(.018,.014,.018),edge,body)
        armor('Layered floating hip tasset',pts([(.06,1.48),(.40,1.49),(.56,.96),(.32,.80),(.14,1.01)]),-.12,.19,iron)
        armor('Corroded hip plate',pts([(.12,1.41),(.37,1.41),(.46,1.02),(.31,.91),(.19,1.08)]),-.14,.035,rust)
        armor('Detached pointed greave',pts([(.21,.83),(.39,.86),(.45,.59),(.31,.22),(.18,.41)]),-.02,.20,iron)
        armor('Greave brass ridge',pts([(.30,.80),(.33,.80),(.34,.48),(.29,.29),(.27,.48)]),-.04,.025,edge)
        rod('Leather suspended joint',[(sign*.31,.08,1.16),(sign*.32,.09,.90)],.033,leather,body)
        armor('Flared jagged gorget',pts([(.03,2.26),(.36,2.25),(.41,2.48),(.22,2.39),(.06,2.38)]),-.06,.24,iron)
        # Split pointed helm; small face and deep orange seams.
        armor('Fissured pointed helm',pts([(.025,2.43),(.18,2.38),(.23,2.57),(.16,2.77),(.045,2.87),(.065,2.64)]),-.13,.25,rust)
        armor('Helm cheek blade',pts([(.08,2.58),(.23,2.64),(.25,2.44),(.11,2.33)]),-.175,.04,iron)
        rod('Recessed narrow ember visor',[(sign*.035,-.18,2.59),(sign*.17,-.18,2.62)],.014,cyan,body)
        rod('Broken helm crest',[(sign*.16,.06,2.68),(sign*.30,.10,2.85),(sign*.26,.13,3.03 if sign==1 else 2.94)],.038,iron,body)
    rod('Vertical split ember',[(0,-.105,2.43),(.025,-.10,2.60),(0,-.07,2.80)],.012,cyan,body)
    # The torso stays visibly hollow, with suspended coals behind restraints.
    for j in range(3):
        shard('Deep suspended coal',(0,.10,1.69+j*.17),(.045,.04,.065),cyan,body)
        rod('Hollow chest restraint',[(-.16,-.12,1.71+j*.17),(0,-.16,1.66+j*.17),(.16,-.12,1.71+j*.17)],.018,iron,body)
    armor('Heavy belt',[(-.40,1.48),(-.37,1.58),(.38,1.58),(.43,1.46),(0,1.36)],-.18,.25,edge)
    arms=[]
    for sign in (-1,1):
        arm=empty('Detached arm',(sign*.59,0,2.18),body);arms.append((arm,sign))
        plate('Jagged layered pauldron',[(-.25,.06),(-.12,.24),(.14,.21),(.34,.03),(.24,-.25),(.04,-.18),(-.22,-.28)],-.14,.31,iron,arm,.015)
        plate('Rust shoulder cap',[(-.21,.07),(-.10,.20),(.12,.17),(.27,.02),(.19,-.09),(-.06,-.04)],-.16,.04,rust,arm,.01)
        for j in range(3):
            x=-.12+j*.14
            shard('Shoulder brass rivet',(x,-.177,.06),(.023,.018,.023),edge,arm)
            rod('Shoulder blade spikes',[(x,.03,.15),(x+sign*.07,.04,.30),(x+sign*.11,.06,.39-j*.045)],.045,iron,arm)
        rod('Hanging leather tendon',[(0,.05,-.19),(sign*.035,.03,-.48)],.048,leather,arm)
        plate('Long vambrace',[(-.12,-.35),(.11,-.34),(.17,-.63),(.065,-.81),(-.12,-.67)],-.12,.22,rust,arm,.012)
        for j in range(3):
            plate('Articulated wrist lames',[(-.12,-.57-j*.065),(.13,-.55-j*.065),(.14,-.62-j*.065),(-.11,-.65-j*.065)],-.14,.05,iron,arm,.006)
        shard('Iron gauntlet',(0,-.08,-.84),(.12,.10,.12),iron,arm)
        for j in range(4):
            x=(j-1.5)*.052
            rod('Pointed gauntlet fingers',[(x,-.14,-.87),(x,-.18,-.99),(x+.018,-.22,-1.02)],.022,edge,arm)
    # Solid ragged cloth with sculpted fold cross sections.
    for j in range(7):
        x=(j-3)*.13;h=.95+.25*math.sin(j*2.2)
        plate('Burnt mantle strip',[(x-.075,2.19),(x+.075,2.15),(x+.11,2.19-h),(x+.025,2.05-h),(x-.09,2.27-h)],.30,.025,cloth,body,.003)
        rod('Mantle fold',[(x,.34,2.17),(x+.03,.40,1.65),(x+.015,.45,2.19-h)],.025,cloth,body)
    weapon=empty('Two body lengths halberd',(.76,-.18,1.38),body)
    rod('Black haft',[(0,0,-1.48),(0,0,.70),(0,0,2.90)],.036,iron,weapon)
    for j in range(9):
        z=-.4+j*.12
        rod('Leather haft binding',[(-.035,-.03,z),(.035,-.03,z+.04),(.035,.03,z+.08)],.013,leather,weapon)
    plate('Forged cleaver halberd head',[(.025,2.43),(.26,2.63),(.54,2.84),(.49,2.40),(.33,2.12),(.08,2.18)],-.055,.11,rust,weapon,.014)
    plate('Battered brass cutting edge',[(.54,2.84),(.49,2.40),(.33,2.12),(.28,2.16),(.43,2.43)],-.065,.13,edge,weapon,.006)
    plate('Rear hooked poll',[(-.03,2.54),(-.30,2.56),(-.41,2.29),(-.27,2.36),(-.19,2.43),(-.025,2.40)],-.05,.10,iron,weapon,.01)
    plate('Long diamond spear',[(-.07,2.83),(0,3.47),(.085,2.83),(0,2.65)],-.035,.07,edge,weapon,.006)
    for j in range(3):rod('Ember weapon score',[(.11+j*.065,-.068,2.39),(.14+j*.065,-.069,2.49)],.009,cyan,weapon)
    chains=empty('Summoned chains',parent=root);linkdata=None
    for sign in (-1,1):
        for j in range(12):
            if linkdata is None:
                bpy.ops.mesh.primitive_torus_add(major_segments=8,minor_segments=4,major_radius=.074,minor_radius=.018)
                o=bpy.context.object;linkdata=o.data;linkdata.materials.append(iron)
            else:
                o=bpy.data.objects.new('Judgement chain link',linkdata);bpy.context.collection.objects.link(o)
            o.name='Volumetric summoned chain';o.parent=chains
            o.location=(sign*(.38+j*.105),-.28-.13*math.sin(j*.5),.62+.43*math.sin(j*.23))
            o.rotation_euler=(math.pi/2,0,math.pi/2*(j%2));o.scale=(1.2,1,1)
            o.material_slots[0].link='OBJECT';o.material_slots[0].material=iron
            if j in (3,8):shard('Chain trapped ember',o.location,(.025,.025,.035),cyan,chains)
    motes=[]
    for j in range(8):
        o=shard('Solid falling rust shard',(math.sin(j*2.4)*.43,math.cos(j*2.4)*.22,.27+j*.065),(.035,.025,.06),rust,root);motes.append((o,o.location.copy()))
    iso_rig.bake_ao_shadows(root)
    def animate(a,i,n,f):
        t=i*math.tau/n;p=i/(n-1);dead=p if a=='death' else 0;split=p if a=='phase2' else 0
        body.location=(0,0,.035*math.sin(t) if a in ('idle','run') else -.48*dead)
        body.rotation_euler=(.12 if a=='run' else .12*dead,0,.035*math.sin(t) if a=='run' else 0);key(body,f)
        for j,(o,loc) in enumerate(pieces):
            v=Vector(((-1 if loc.x<0 else 1)*(.18+.015*j)*split, .10*math.sin(j)*split,.1*math.cos(j)*split))
            o.location=loc+v+Vector((math.sin(j*2.4)*dead*.6,math.cos(j*2.4)*dead*.25,-max(0,loc.z-.18)*dead))
            o.rotation_euler=(.25*split*math.sin(j)+dead*j*.3,.2*split*math.cos(j),dead*j*.5);key(o,f)
        for arm,sign in arms:
            arm.rotation_euler=(sign*.10*math.sin(t) if a=='run' else -.8*math.sin(p*math.pi) if a=='cast_a' else 0,0,sign*(1.15*math.sin(p*math.pi) if a=='cast_b' else .6*split+.9*dead));key(arm,f)
        weapon.location=(.76,-.18,1.38-.6*dead)
        weapon.scale=(1,1,1);weapon.rotation_euler=(.12,-.24,0)
        if a=='attack':weapon.rotation_euler=(.2,-.7,[.4,.55,.7,-.8,-.4,0][i])
        if a=='cast_a':weapon.rotation_euler=(1.30*math.sin(p*math.pi),-.24,0)
        if a=='cast_b':weapon.rotation_euler=(0,0,0);weapon.location=(.80,-.18,1.49)
        if a=='death':weapon.rotation_euler=(.15,-.5-1.1*dead,0)
        key(weapon,f)
        q=math.sin(p*math.pi) if a=='cast_b' else .001;chains.scale=(q,q,q);key(chains,f)
        for j,(o,loc) in enumerate(motes):o.location=loc+Vector((0,0,-.12*(i%n)/n));key(o,f)
        pulse(cyan,f,1.1+.7*math.sin(t) if a!='phase2' else 1.5+3*p)
    export('rust_archon',root,animate)
if __name__=='__main__':build()
