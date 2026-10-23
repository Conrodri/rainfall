"""T3 block brute. Execute with Blender --background --python only."""
import sys, math, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
NAME='brute_tier3'
ANIMS={'run':(1,8),'attack':(17,8),'cast':(33,8)}
def key(o,f):
    for p in ('location','rotation_euler','scale'):o.keyframe_insert(p,frame=f)
def build():
    s=setup_scene(160)
    skin=material('Light slate Lstar 66','8DA2B8');pale=material('Armor edges','B8C7D5');shade=material('Slate joints','6F839C');rust=material('Muted rust armor bands','986E5B');dark=material('Face recess','303C4C');red=material('Red emissive eyes','D8342A',1.2,True);dust=material('Discrete cold shockwave','AABCC8',.6,True)
    root=empty('Brute_Root');body=empty('Block torso',(0,0,0),root)
    chest=cube('Trapezoid massive chest',(0,0,.99),(.48,.29,.39),skin,body,.14)
    sphere('Upper back',(0,.12,1.22),(.61,.32,.29),skin,body)
    cube('Narrow waist',(0,.015,.64),(.30,.24,.16),shade,body,.06)
    cube('Rust belt',(0,-.005,.61),(.33,.255,.06),rust,body,.025)
    sphere('Small head',(0,-.12,1.48),(.19,.18,.20),skin,body)
    cube('Dark face',(0,-.282,1.49),(.145,.035,.085),dark,body,.025)
    cube('Heavy brow',(0,-.29,1.58),(.18,.065,.045),pale,body,.025)
    for x in (-.075,.075):sphere('Red slit eye',(x,-.321,1.51),(.042,.018,.025),red,body)
    cube('Block jaw',(0,-.25,1.39),(.14,.10,.065),shade,body,.025)
    legs=[];arms=[]
    for sign in (-1,1):
        leg=empty('Leg'+str(sign),(sign*.235,0,.57),body);legs.append((leg,sign))
        cube('Thick thigh',(0,0,-.12),(.15,.17,.23),skin,leg,.07)
        cube('Heavy shin',(0,-.015,-.35),(.14,.16,.17),shade,leg,.05)
        cube('Wide planted foot',(0,-.10,-.49),(.18,.25,.09),skin,leg,.05)
        arm=empty('Hammer arm'+str(sign),(sign*.51,0,1.23),body);arms.append((arm,sign))
        cube('Huge shoulder',(sign*.055,0,0),(.25,.31,.24),skin,arm,.09)
        cube('Rust shoulder band',(sign*.06,.015,.17),(.26,.30,.055),rust,arm,.025)
        segment('Upper arm',(sign*.08,0,-.05),(sign*.14,-.02,-.34),.16,shade,arm)
        cube('Hammer forearm',(sign*.14,-.06,-.41),(.205,.23,.22),skin,arm,.06)
        cube('Massive fist',(sign*.14,-.12,-.64),(.235,.27,.20),skin,arm,.07)
        for j in range(3):cube('Knuckle',(sign*.14+(j-1)*.135,-.36,-.58),(.055,.065,.085),pale,arm,.02)
    impact=empty('Frontal cone impact',(0,0,.055),root)
    for j in range(9):
        a=-math.pi/2+(j-4)*.14
        shard=cone('Frontal impact debris',(math.cos(a)*.95,math.sin(a)*.95,.04),.045,0,.13,dust,impact);shard.rotation_euler.y=.5*math.cos(a)
    wave=empty('Shockwave meshes',(0,0,.055),root)
    bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=8,major_radius=.78,minor_radius=.025)
    finish(bpy.context.object,'Dust shock ring',(0,0,0),(1,1,.65),dust,wave)
    for j in range(12):
        a=j*math.tau/12
        rock=cube('Shockwave stone',(math.cos(a)*.81,math.sin(a)*.81,.04+(j%3)*.025),(.045,.065,.035),dust if j%3==0 else shade,wave,.015);rock.rotation_euler.z=a
    for anim,(start,_) in ANIMS.items():
        for i in range(9 if anim=='run' else 8):
            t=i*math.tau/8
            body.location=(0,0,.025*(1-math.cos(2*t)) if anim=='run' else 0);body.rotation_euler=(.035*math.sin(t) if anim=='run' else ([0,-.04,-.08,-.12,.20,.23,.12,0][i] if anim=='attack' else [0,-.05,-.10,-.16,.25,.18,.08,0][i]),0,.035*math.sin(t) if anim=='run' else 0);key(body,start+i)
            for leg,sign in legs:leg.rotation_euler.x=sign*.35*math.sin(t) if anim=='run' else 0;key(leg,start+i)
            for arm,sign in arms:
                arm.rotation_euler=( -sign*.22*math.sin(t) if anim=='run' else ([0,-.65,-1.4,-2.25,-.85,-.15,-.08,0][i] if anim=='attack' else [0,-.7,-1.6,-2.35,-.1,-.08,-.05,0][i]),0,0);key(arm,start+i)
            impact.scale=(1,1,1) if anim=='attack' and i in (4,5) else (.001,)*3;key(impact,start+i)
            q=([.001,.001,.001,.001,.001,.9,1.10,1.3][i] if anim=='cast' else .001);wave.scale=(q,q,q);key(wave,start+i)
    s.frame_start=1;s.frame_end=40;s.render.fps=12
    for label,f in [('run loop 12fps',1),('run closing key',9),('attack raise noloop',17),('frontal impact',21),('cast raise noloop',33),('ground strike',37),('shockwave',38)]:s.timeline_markers.new(label,frame=f)
    framing=fit_camera(root,ANIMS,160);diffuse_compositor(s);pose(root,1,'s')
    blend=ART/'blender/monsters'/f'{NAME}.blend';blend.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    base=ART/'renders/monsters'/NAME;base.mkdir(parents=True,exist_ok=True)
    (base/'build_report.json').write_text(json.dumps({'framing':framing,'main_color':'#8DA2B8','normal_verification':passes.validate_normal_convention(base/'verification')},indent=2))
    render_all(NAME,root,{k:v for k,v in ANIMS.items() if '--attack-only' not in sys.argv or k=='attack'});bpy.ops.wm.save_as_mainfile(filepath=str(blend))
if __name__=='__main__':build()
