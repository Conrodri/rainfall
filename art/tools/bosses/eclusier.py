"""L'Eclusier : construction procedurale, articulation et quatre apercus uniquement.
Usage : blender --background --python art/tools/bosses/eclusier.py -- --phase 1
"""
import sys, math, argparse
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_common import *

def build(phase=1):
    root=empty('ECLUSIER_ROOT');root['phase']=phase;root['height_u']=3.5
    wood=material('Bois noir humide #2a2018',(.024,.014,.009),roughness=.34,grain=True)
    grain=material('Fibres usees',(.115,.077,.038),roughness=.55,grain=True)
    bronze=material('Bronze #8a6a3a',(.254,.144,.042),.72,.31)
    edge=material('Bronze poli des aretes',(.49,.32,.105),.74,.28)
    moss=material('Mousse sourde',(.025,.065,.035) if phase>=2 else (.065,.095,.035),roughness=.95)
    patina=material('Vert de gris',(.07,.17,.135),.3,.7)
    water=material('Eau argentee',(.22,.45,.48),.38,.16,emission=.17)
    foam=material('Reflets eau',(.52,.73,.7),.18,.24,emission=.3)
    dark=material('Interieur vanne',(.006,.013,.015),roughness=.85)
    torso=empty('Torse_pivot',(0,0,1.35),root)
    # Barrel made of individual curved staves: open seams remain visible at sprite scale.
    for i in range(16):
        a=i*math.tau/16
        verts=[]
        for z,r in ((0,.68),(.16,.79),(.65,.88),(1.12,.79),(1.35,.62)):
            for angle in (a-.177,a+.177):
                verts.append((r*math.sin(angle),r*.76*math.cos(angle),z))
        faces=[(j,j+1,j+3,j+2) for j in range(0,8,2)]+[(0,2,4,6,8),(1,9,7,5,3),(0,1,3,2),(6,7,9,8)]
        mesh=bpy.data.meshes.new('Douve galbee');mesh.from_pydata(verts,[],faces);mesh.update()
        ob=bpy.data.objects.new('Fut douve %02d'%i,mesh);bpy.context.collection.objects.link(ob)
        finish(ob,'Fut douve %02d'%i,wood if i%3 else grain,torso,.025)
        if phase==3:
            ob.rotation_euler.y=.035*math.sin(a);ob.location.x=.035*math.sin(a)
    for z,r in ((.13,.78),(.38,.86),(1.12,.81)):
        band=ring('Cercle du fut',(0,0,z),r,.065,bronze,torso,rotation=(0,0,0));band.scale.y=.76
        for i in range(12):
            a=i*math.tau/12
            sphere('Rivet de cerclage',(r*math.sin(a),r*.77*math.cos(a),z),(.038,.038,.038),edge,torso)
    # Recessed sluice mouth, independently raised gate for phase 2 and rupture.
    box('Bouche noire',(0,-.447,.57),(.85,.10,.57),dark,torso)
    gate=empty('Vanne_coulissante',(0,-.52,.52+(0 if phase==1 else .23 if phase==2 else .48)),torso)
    box('Panneau vanne',(0,0,0),(.82,.13,.49),bronze,gate)
    for x in (-.27,0,.27):box('Raidisseur vanne',(x,-.075,0),(.045,.045,.43),edge,gate,.008)
    eye=material('Yeux cyan froid',(.08,.55,.72),roughness=.25,emission=2.8 if phase==3 else .8)
    head=empty('Tete_pivot',(0,-.43,1.94),torso);head.scale=(1.13,1.10,1.10)
    sphere('Casque bois noir',(0,0,0),(.57,.48,.59),wood,head)
    # Broad recessed face, pitched toward the elevated camera.
    face=empty('Masque incline',(0,-.36,.05),head);face.rotation_euler.x=math.radians(-18)
    box('Fente visage',(0,-.08,0),(.88,.16,.24),dark,face,.075)
    for x in (-.235,.235):
        box('Oeil lumineux',(x,-.178,.025),(.20,.035,.065),eye,face,.024)
    box('Sourcil bronze',(0,-.12,.18),(.98,.19,.10),bronze,face,.04)
    box('Nez de bronze',(0,-.22,-.025),(.11,.14,.31),edge,face,.035)
    for z,r in ((-.24,.51),(.27,.49)):
        band=ring('Cerclage casque',(0,0,z),r,.045,bronze,head,rotation=(0,0,0));band.scale.y=.86
    for x in (-.29,0,.29):
        tube('Crete de casque',[(x,-.35,.29),(x,-.15,.57),(x,.18,.54),(x,.36,.30)],.045,bronze,head)
        for y in (-.24,.12):sphere('Rivet casque',(x,y,.55),(.043,.043,.035),edge,head)
    # Articulated door arms: three long slabs, cross braces, hinges, heavy knuckles.
    arms=[];legs=[]
    for side in (-1,1):
        arm=empty(('Bras_gauche' if side<0 else 'Bras_droit'),(side*1.48,-.02,1.03),torso);arms.append(arm)
        sphere('Epaule arrondie',(0,0,0),(.48,.43,.34),bronze,arm)
        sphere('Coiffe epaule',(0,-.02,.14),(.40,.38,.24),wood,arm)
        for j in range(3):
            p=box('Bras_porte_planche',((j-1)*.24,-.02,-.63),(.23,.47,1.42),wood,arm,.04)
            if phase==3 and j==1:p.rotation_euler.y=.17*side;p.location.z+=.13
        for z in (-.2,-1.02):
            box('Traverse porte',(0,-.29,z),(.82,.15,.15),bronze,arm)
            for x in (-.29,.29):sphere('Clou porte',(x,-.38,z),(.047,.029,.047),edge,arm)
        brace=box('Echarpe diagonale',(0,-.28,-.62),(.105,.11,.94),bronze,arm);brace.rotation_euler.y=side*.56
        for z in (-.23,-.94):rod('Gond',(side*.4,-.02,z-.1),(side*.4,-.02,z+.1),.07,edge,arm)
        sphere('Poing de bronze',(0,-.08,-1.32),(.43,.34,.25),bronze,arm)
        for k in range(3):sphere('Articulation du poing',((k-1)*.22,-.35,-1.3),(.12,.13,.14),edge,arm)
        leg=empty('Jambe_'+str(side),(side*(.67 if phase==3 else .46),0,.81),root);legs.append(leg)
        box('Pilier jambe',(0,0,-.27),(.43,.49,.76),wood,leg)
        box('Genou cercle',(0,-.05,-.10),(.54,.58,.18),bronze,leg)
        box('Sabot ancre',(side*(.12 if phase==3 else 0),-.19,-.68),(.68,.86,.25),bronze,leg,.06)
        for j in range(3):box('Dent du sabot',((j-1)*.18,-.54,-.68),(.1,.15,.17),edge,leg)
        if phase==3:
            rod('Etai ancrage',(side*.4,.15,.43),(side*1.02,.35,.08),.12,bronze,root)
    wheel=empty('Roue_de_vanne_pivot',(0,1.0,2.67 if phase<3 else 2.48),root)
    radius=1.57 if phase<3 else 1.82
    ring('Roue couronne',(0,0,0),radius,.13,bronze,wheel)
    ring('Roue liseré',(0,-.085,0),radius,.025,edge,wheel)
    for i in range(8):
        a=i*math.tau/8
        rod('Rayon',(math.cos(a)*.18,0,math.sin(a)*.18),(math.cos(a)*radius,0,math.sin(a)*radius),.095,bronze,wheel)
        sphere('Noeud patine',(math.cos(a)*radius,-.06,math.sin(a)*radius),(.07,.06,.07),patina,wheel)
    rod('Moyeu',(0,-.19,0),(0,.21,0),.23,bronze,wheel)
    rod('Axe dorsal',(0,.2,2.29),(0,.7,2.29),.15,bronze,root)
    # Moss pockets always present; hanging algae and water are phase-specific geometry.
    for side in (-1,1):
        for j in range(4):sphere('Mousse epaule',(side*(1.16+j*.12),-.11,2.60-j*.025),(.13,.22,.065),moss,root)
    if phase>=2:
        for side in (-1,1):
            for j in range(3):
                x=side*(.93+j*.15)
                tube('Algue pendante',[(x,-.27,2.5),(x+side*.05,-.35,2.12),(x-.04,-.37,1.75-j*.12)],.025,moss,root)
        sphere('Eau peu profonde',(0,-.05,.032),(1.80,1.20,.025),water,root)
        for x in (-.3,.04,.31):
            tube('Ecoulement vanne',[(x,-.61,1.85),(x*.9,-.68,1.30),(x*1.4,-.52,.17)],.038 if phase==2 else .07,water,root)
        for x in (-1.1,1.05):ring('Ride de surface',(x,-.3,.075),.40,.014,foam,root,rotation=(0,0,0))
        for side in (-1,1):
            for j in range(4):
                x=side*(.75+j*.23)
                tube('Eclaboussure',[(x,-.75,.07),(x+side*.09,-.77,.24+j*.035),(x+side*.19,-.72,.10)],.018,foam,root)
                sphere('Goutte de flaque',(x,-.79,.32+j*.035),(.025,.025,.045),water,root)
    if phase==3:
        jet=material('Eau sous pression lumineuse',(.15,.60,.72),.25,.18,emission=1.4)
        crest=material('Crete de jet brillante',(.40,.85,.94),.1,.2,emission=2.1)
        for side in (-1,1):
            tube('Jet de rupture',[(side*.55,-.4,1.92),(side*1.15,-.53,1.96),(side*1.65,-.48,1.43),(side*1.78,-.43,.3)],.075,jet,root)
            tube('Filet reflet',[(side*.56,-.46,1.95),(side*1.15,-.59,2),(side*1.63,-.54,1.45)],.025,crest,root)
            for j in range(5):sphere('Goutte rupture',(side*(1.65+j*.035),-.42+(j%2)*.13,.28+j*.17),(.035,.03,.065),foam,root)
            for j in range(3):
                x=side*(.25+j*.17)
                tube('Fissure ouverte',[(x,-.61,1.42),(x+side*.07,-.66,1.77),(x-.035,-.61,2.18)],.035,dark,root)
                tube('Source lumineuse fissure',[(x,-.65,1.45),(x+side*.07,-.70,1.77),(x-.035,-.65,2.12)],.023,jet,root)
            for j in range(3):
                shard=box('Douve eclatee',(side*(.64+j*.095),-.60,1.65+j*.19),(.095,.17,.43),grain,root,.018);shard.rotation_euler.y=side*(.4+j*.12)
            shard=box('Echarde rompue',(side*.62,-.46,2.36),(.11,.14,.65),grain,root);shard.rotation_euler.y=side*.42
    def pose(t,walking=False):
        wave=math.sin(t*math.tau)
        torso.location.z=(1.13 if phase==3 else 1.35)+(.025*wave if not walking else .045*math.cos(t*math.tau*2))
        torso.rotation_euler.y=.015*wave
        for i,arm in enumerate(arms):arm.rotation_euler.x=(.25*wave*(-1 if i else 1) if walking else .018*wave);arm.rotation_euler.y=(-.09 if i==0 else .09)*(1.7 if phase==3 else 1)
        for i,leg in enumerate(legs):leg.rotation_euler.x=.29*wave*(-1 if i else 1) if walking else 0
        wheel.rotation_euler.y=t*math.tau+.23 if phase==3 else .025*wave
        head.rotation_euler.z=.015*wave
    pose(0);return root,pose

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--phase',type=int,choices=(1,2,3),default=1);args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=ROOT/'art/renders/bosses/eclusier/_preview/raw'
    for phase in (1,2,3):
        setup_scene(scale=6.4);root,pose=build(phase)
        if phase==args.phase:
            bpy.context.scene['instructions']='Relancer eclusier.py -- --phase 1|2|3. Avant -Y. Roue articulee autour Y local. Apercus seulement.'
            configure_passes(out/f'idle_p{phase}_s.png')
            bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bosses/eclusier.blend'))
        render_still(root,pose,out/f'idle_p{phase}_s.png')
        if phase==1:render_still(root,lambda t:pose(t,True),out/'walk_p1_e.png',.125,'e')
if __name__=='__main__':main()

