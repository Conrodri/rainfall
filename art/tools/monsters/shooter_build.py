"""Tireur T2 : capuche pointue lavande, bras de lanceur et orbe carmin.
Usage: blender.exe --background --python art/tools/monsters/shooter_build.py
"""
import sys, math, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
NAME='shooter_tier2'
ANIMS={'run':(1,8),'attack':(17,8)}

def key(o,frame):
    for p in ('location','rotation_euler','scale'):o.keyframe_insert(p,frame=frame)

def build():
    s=setup_scene(112)
    # #AD99C6 has L*=66.5, brighter than the indicative #8E7BA8 (L*~55).
    cloth=material('Main lavender Lstar 66','AD99C6')
    pale=material('Raised lavender seams','C6B5DA')
    shade=material('Violet lining','9383AC')
    dark=material('Dark hood interior','302937',.10)
    boot=material('Ash violet leather','897B99')
    bone=material('Long pale fingers','B9B7CD')
    red=material('Crimson eyes and orb','D8342A',1.1,True)
    hot=material('Orb core','EC817D',1.2,True)
    root=empty('Shooter_Root');body=empty('Body',(0,0,0),root)
    cone('Long split tunic',(0,.025,.61),.19,.13,.59,cloth,body,scale=(1,.77,1))
    cone('Pale hem',(0,.025,.325),.194,.185,.032,pale,body,scale=(1,.77,1))
    cone('High collar',(0,0,.92),.153,.17,.15,shade,body,scale=(1,.8,1))
    cone('Waist wrap',(0,0,.61),.169,.163,.065,shade,body,scale=(1,.8,1))
    sphere('Red clasp',(0,-.143,.70),(.035,.018,.047),red,body)
    # Open hood: rear skull plus tapered crown; dark inset face in front.
    sphere('Hood',(0,.025,1.115),(.206,.18,.245),cloth,body)
    peak=cone('Pointed hood',(0,.045,1.365),.17,.008,.42,cloth,body,scale=(1,.85,1))
    peak.rotation_euler.x=-.15
    sphere('Face recess',(0,-.145,1.115),(.148,.065,.158),dark,body)
    for x in (-.058,.058):
        eye=sphere('Red slit eye',(x,-.206,1.135),(.029,.012,.016),red,body);eye.rotation_euler.y=x*2
    for side,x in [('L',-.095),('R',.095)]:
        leg=empty('Leg_'+side,(x,.025,.35),body)
        cone('Shin_'+side,(0,0,-.12),.042,.053,.26,boot,leg)
        sphere('Foot_'+side,(0,-.045,-.29),(.062,.115,.06),boot,leg)
        cone('Boot cuff_'+side,(0,0,-.16),.052,.054,.06,pale,leg)
    arms=[]
    for side,sign in [('L',-1),('R',1)]:
        arm=empty('Arm_'+side,(sign*.17,-.005,.91),body);arms.append(arm)
        sphere('Shoulder_'+side,(sign*.025,0,-.055),(.075,.075,.11),cloth,arm)
        segment('Long sleeve_'+side,(sign*.025,0,-.075),(sign*.09,-.07,-.32),.062,cloth,arm)
        segment('Forearm_'+side,(sign*.09,-.07,-.32),(sign*.10,-.22,-.40),.035,bone,arm)
        sphere('Cuff_'+side,(sign*.085,-.075,-.31),(.052,.052,.05),pale,arm)
        sphere('Palm_'+side,(sign*.10,-.23,-.40),(.045,.052,.034),bone,arm)
        for j in range(3):segment('Finger_'+side+str(j),(sign*(.077+j*.022),-.24,-.4),(sign*(.078+j*.024),-.305,-.39),.010,bone,arm)
    orbroot=empty('Orb holder',(.10,-.34,-.35),arms[1])
    orb=sphere('Crimson orb',(0,0,0),(.084,.084,.084),red,orbroot)
    sphere('Orb glint',(-.024,-.064,.028),(.022,.023,.025),hot,orbroot)
    # Three curved talons cradle the orb; modeled cylinders, no drawn effects.
    for j in range(3):
        a=j*2*math.pi/3
        segment('Orb talon',(.10*math.cos(a),.02,.10*math.sin(a)),(.055*math.cos(a),-.025,.055*math.sin(a)),.013,shade,orbroot)
    bolt=cone('Release flare',(0,-.18,0),.05,0,.27,red,orbroot);bolt.rotation_euler.x=math.pi/2
    for anim,(start,count) in ANIMS.items():
        for i in range(9 if anim=='run' else 8):
            t=2*math.pi*i/8
            body.location=(0,0,.018*(1-math.cos(2*t)) if anim=='run' else 0)
            body.rotation_euler=(.08 if anim=='run' else [-.04,-.09,-.14,-.18,-.20,.18,.10,0][i],.025*math.sin(t) if anim=='run' else 0,0)
            key(body,start+i)
            for side,sign in [('L',1),('R',-1)]:
                leg=bpy.data.objects['Leg_'+side];leg.rotation_euler.x=sign*.65*math.sin(t) if anim=='run' else 0;key(leg,start+i)
                arm=bpy.data.objects['Arm_'+side]
                arm.rotation_euler=( -sign*.35*math.sin(t) if anim=='run' else [0,-.25,-.55,-.8,-.9,-1.35,-.8,0][i],0,0)
                if anim=='attack' and side=='L':arm.rotation_euler.x=[0,-.3,-.7,-1.,-1.15,-1.0,-.5,0][i];arm.rotation_euler.z=[0,-.12,-.3,-.45,-.5,.1,.05,0][i]
                key(arm,start+i)
            pulse=1+.06*math.sin(t) if anim=='run' else [1,1.1,1.25,1.4,1.55,.65,.65,1][i]
            orbroot.scale=(pulse,)*3;key(orbroot,start+i)
            bolt.scale=(.001,)*3 if anim=='run' or i!=5 else (1,1,1);key(bolt,start+i)
    s.frame_start=1;s.frame_end=24;s.render.fps=14
    for name,f in [('run 14fps loop',1),('run closing key',9),('attack 12fps no loop',17),('release frame 5',22)]:s.timeline_markers.new(name,frame=f)
    framing=fit_camera(root,ANIMS,112)
    diffuse_compositor(s);pose(root,1,'s')
    blend=ART/'blender/monsters'/f'{NAME}.blend';blend.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    base=ART/'renders/monsters'/NAME;base.mkdir(parents=True,exist_ok=True)
    verification=passes.validate_normal_convention(base/'verification')
    (base/'build_report.json').write_text(json.dumps({'framing':framing,'normal_verification':verification,'main_color':'#AD99C6'},indent=2))
    render_all(NAME,root,ANIMS)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))

if __name__=='__main__':build()
