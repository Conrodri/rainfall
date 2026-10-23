"""T2 feline leaper. Execute with Blender --background --python only."""
import sys, math, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
NAME='leaper_tier2'
ANIMS={'run':(1,8),'charge':(17,8)}
def key(o,f):
    for p in ('location','rotation_euler','scale'):o.keyframe_insert(p,frame=f)
def build():
    s=setup_scene(112)
    skin=material('Light turquoise grey Lstar 68','6A9F98');ridge=material('Pale dorsal armor','D0EBE3');shade=material('Turquoise joints','4B7A76');dark=material('Dark muzzle and claws','263C40');red=material('Emissive red eyes','FF3B2E',4,True)
    root=empty('Leaper_Root');body=empty('Low feline torso',(0,0,.48),root)
    sphere('Broad ribcage',(0,-.08,0),(.34,.49,.27),skin,body)
    sphere('Powerful haunches',(0,.34,-.015),(.38,.30,.28),skin,body)
    head=empty('Head',(0,-.49,.015),body)
    sphere('Feline skull',(0,0,0),(.27,.25,.20),skin,head)
    sphere('Squared muzzle',(0,-.21,-.065),(.21,.12,.10),ridge,head)
    sphere('Nose',(0,-.312,-.035),(.085,.028,.042),dark,head)
    for sign in (-1,1):
        ear=cone('Swept ear',(sign*.20,.04,.20),.09,0,.23,shade,head);ear.rotation_euler.y=sign*.3
        eye=sphere('Red eye',(sign*.184,-.19,.055),(.095,.042,.06),red,head);eye.rotation_euler.z=sign*.4
        sphere('Brow',(sign*.174,-.16,.115),(.105,.065,.035),shade,head)
    for j in range(6):
        spike=cone('Dorsal spine',(0,-.27+j*.145,.265),.075,0,.22+(.08 if j in (2,3) else 0),ridge,body);spike.rotation_euler.x=-.35
    legs=[]
    for rear,y in ((False,-.32),(True,.34)):
        for sign in (-1,1):
            leg=empty(('Hind' if rear else 'Fore')+str(sign),(sign*(.29 if rear else .255),y,-.06),body);legs.append((leg,rear,sign))
            sphere('Muscular thigh' if rear else 'Shoulder',(sign*.025,.015,-.055),(.155 if rear else .10,.20 if rear else .12,.22),skin,leg)
            segment('Lower leg',(0,.06,-.12),(0,-.055,-.33),.065,shade,leg)
            sphere('Paw',(0,-.105,-.365),(.105,.15,.065),skin,leg)
            for x in (-.055,0,.055):segment('Claw',(x,-.20,-.36),(x,-.26,-.375),.017,dark,leg)
    tail=empty('Low sweeping tail',(0,.51,-.04),body)
    segment('Tail base',(0,0,0),(0,.32,-.04),.075,skin,tail)
    segment('Tail tip',(0,.32,-.04),(.12,.58,-.12),.045,shade,tail)
    for anim,(start,_) in ANIMS.items():
        for i in range(9 if anim=='run' else 8):
            t=i*math.tau/8
            if anim=='run':
                body.location=(0,0,.48+.045*math.sin(2*t));body.scale=(1,1,1);body.rotation_euler.x=.05*math.sin(t)
            else:
                body.location=(0,[.02,.07,.12,.15,.02,-.09,-.15,-.18][i],[.43,.38,.34,.31,.46,.53,.51,.45][i]);body.scale=(1,[1,1,.98,.96,1.15,1.24,1.22,1.16][i],[1,.92,.85,.8,.90,.83,.85,.92][i]);body.rotation_euler.x=[0,-.04,-.07,-.10,.10,.13,.08,0][i]
            key(body,start+i)
            for leg,rear,sign in legs:
                leg.rotation_euler.x=.65*math.sin(t+(math.pi if (rear==(sign==1)) else 0)) if anim=='run' else ([-.1,-.3,-.55,-.7,.7,.9,.65,.3][i] if rear else [0,.1,.2,.25,-.8,-1,-.7,-.35][i]);key(leg,start+i)
            tail.rotation_euler=(.08*math.sin(t) if anim=='run' else [.1,.2,.3,.35,.1,0,0,.05][i],0,.12*math.sin(t) if anim=='run' else 0);key(tail,start+i)
    s.frame_start=1;s.frame_end=24;s.render.fps=14
    for label,f in [('run loop 14fps',1),('run closing key',9),('charge crouch 12fps noloop',17),('charge leap',21)]:s.timeline_markers.new(label,frame=f)
    framing=fit_camera(root,ANIMS,112);cam=s.camera;cam.data.ortho_scale*=.8;cam.data.shift_y=0;bpy.context.view_layer.update();cam.data.shift_y=world_to_camera_view(s,cam,Vector((0,0,0))).y-.30;framing['ortho_scale']=cam.data.ortho_scale;diffuse_compositor(s);pose(root,1,'s')
    blend=ART/'blender/monsters'/f'{NAME}.blend';blend.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    base=ART/'renders/monsters'/NAME;base.mkdir(parents=True,exist_ok=True)
    (base/'build_report.json').write_text(json.dumps({'framing':framing,'main_color':'#8BB9B1','normal_verification':passes.validate_normal_convention(base/'verification')},indent=2))
    render_all(NAME,root,ANIMS);bpy.ops.wm.save_as_mainfile(filepath=str(blend))
if __name__=='__main__':build()
