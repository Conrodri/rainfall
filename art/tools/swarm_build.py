"""Essaim T1. Blender 5.2 --background --python swarm_build.py -- [test|full].
Tout est modele et rendu dans Blender; pipeline monstres importe sans modification.
"""
import sys, math, json
from pathlib import Path
import bpy
ART=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ART/'tools'/'monsters'))
from common import *
BASE=ART/'renders'/'swarm_tier1'
BLEND=ART/'blender'/'swarm_tier1.blend'

def key(obj,f):
    for prop in ('location','rotation_euler','scale'):obj.keyframe_insert(prop,frame=f)

def build():
    if BLEND.exists():raise RuntimeError('Refus de remplacer un .blend existant')
    bpy.ops.wm.read_homefile(use_empty=True)
    s=setup_scene(96)
    skin=material('Acid grey green Lstar 65','9EAF7E',.42)
    belly=material('Pale silt belly','CDDBA7',.38)
    moss=material('Limnous turquoise','8FB8A0',.35)
    foot=material('Pale hooked limbs','A6B68B',.36)
    dark=material('Mouth and eye sockets','34313D',.12)
    ivory=material('Tiny ivory teeth','E3E6C8',.36)
    red=material('Red eyes D8342A','D8342A',.85,True)
    glint=material('Wet cool glints','D6EBDA',.35)
    for mat in (skin,moss):
        p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.27;p.inputs['Specular IOR Level'].default_value=.38
    root=empty('Swarm_Root');body=empty('Squash_and_bounce',parent=root)
    sphere('Round silt body',(0,.035,.57),(.49,.40,.44),skin,body)
    sphere('Pale belly',(0,-.255,.42),(.355,.17,.29),belly,body)
    # Eye sockets project forward, with a broad red surface visible at sprite scale.
    for side in (-1,1):
        x=side*.215
        sphere('Dark eye rim',(x,-.298,.735),(.159,.107,.16),dark,body)
        sphere('Red bulging eye',(x,-.355,.744),(.131,.092,.131),red,body)
        sphere('Wet eye glint',(x-.035,-.428,.794),(.028,.012,.032),glint,body)
    sphere('Small toothy mouth',(0,-.410,.437),(.166,.036,.083),dark,body)
    for x,z in [(-.10,.477),(0,.489),(.10,.477)]:
        tooth=cone('Upper tiny fang',(x,-.445,z-.025),0,.029,.075,ivory,body)
    for x in (-.055,.055):cone('Lower tooth',(x,-.448,.398),.022,0,.045,ivory,body)
    # Luminous wetness is specular, not an emissive source; only eyes populate run_e.
    sphere('Gelatinous drop base',(.075,.075,1.005),(.105,.095,.12),moss,body)
    drop=cone('Gelatinous drop tip',(.075,.075,1.125),.072,0,.15,moss,body);drop.rotation_euler.y=-.18
    sphere('Drop reflection',(.035,.005,1.058),(.023,.018,.053),glint,body)
    for x,y,z,r in [(-.29,.22,.85,.092),(.27,.30,.73,.10),(0,.398,.60,.12),(-.30,.33,.46,.075)]:
        sphere('Silty back blister',(x,y,z),(r,r*.55,r*.65),moss,body)
    legs=[]
    for side in (-1,1):
        for j,y in enumerate((-.23,.045,.29)):
            leg=empty('Leg_%s_%s'%(side,j),(side*.33,y,.26),root);legs.append((leg,side,j))
            segment('Short leg',(0,0,0),(side*.18,-.035,-.10),.052,foot,leg)
            segment('Hook ankle',(side*.18,-.035,-.10),(side*.205,-.10,-.20),.044,foot,leg)
            sphere('Rounded toe',(side*.205,-.12,-.205),(.063,.081,.043),foot,leg)
            segment('Pale claw',(side*.21,-.15,-.20),(side*.19,-.215,-.185),.022,ivory,leg)
    for i in range(9):
        t=2*math.pi*i/8
        body.location.z=.032*(1-math.cos(2*t))
        body.scale=(1+.035*math.cos(2*t),1+.02*math.cos(2*t),1-.045*math.cos(2*t))
        body.rotation_euler=(.025*math.sin(2*t),.035*math.sin(t),0);key(body,i+1)
        for leg,side,j in legs:
            phase=t+(math.pi if (j+(side==1))%2 else 0)
            leg.rotation_euler.x=.42*math.sin(phase)
            leg.location.z=.26+.045*max(0,math.cos(phase));key(leg,i+1)
    s.frame_start=1;s.frame_end=8;s.render.fps=14
    s.timeline_markers.new('Run loop; closing key at 9',frame=1)
    framing=fit_camera(root,{'run':(1,8)},96)
    # Le fitter commun reserve 18 px a 2x. Pour le petit T1, garder 5 px
    # transparents + 4 px de contour + 1 px de filtre sur toutes les poses.
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector
    xmin,xmax,ymin,ymax=framing['bounds_camera'];margin=10/192
    s.camera.data.ortho_scale=max(max(abs(xmin),abs(xmax))/(.5-margin),ymax/(.7-margin),-ymin/(.3-margin))
    s.camera.data.shift_y=0;bpy.context.view_layer.update()
    s.camera.data.shift_y=world_to_camera_view(s,s.camera,Vector((0,0,0))).y-.30
    framing['ortho_scale']=s.camera.data.ortho_scale
    diffuse_compositor(s);pose(root,1,'s')
    s['asset']='swarm_tier1';s['palette_main']='#9EAF7E; L* >=60';s['loop_period']=8
    BLEND.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    BASE.mkdir(parents=True,exist_ok=True)
    (BASE/'build_report.json').write_text(json.dumps(framing,indent=2))
    return s,root

def render(s,root,test=False):
    for name in ('run','run_n','run_e'):(BASE/name).mkdir(parents=True,exist_ok=True)
    diffuse_compositor(s)
    for d in (['e','s','n'] if test else DIRS):
        for i in ([0] if test else range(8)):
            pose(root,i+1,d);p=BASE/'run'/f'{d}_{i:02d}.png'
            s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
            passes.render_normal_pass(BASE/'run_n'/p.name,p,s)
            passes.render_emission_pass(BASE/'run_e'/p.name,p,s)
            print('SWARM_FRAME',d,i,flush=True)

def verify():
    import numpy as np
    report={'counts':{},'min_margin_px':192,'alpha_max_difference':0,'bbox_width_range':[]}
    widths=[]
    def pixels(path):
        im=bpy.data.images.load(str(path),check_existing=False);im.colorspace_settings.name='Non-Color'
        assert tuple(im.size)==(192,192)
        a=np.array(im.pixels[:]).reshape(192,192,4);bpy.data.images.remove(im);return a
    for folder in ('run','run_n','run_e'):
        report['counts'][folder]=len(list((BASE/folder).glob('*.png')))
        assert report['counts'][folder]==64
    for d in DIRS:
        for i in range(8):
            name=f'{d}_{i:02d}.png';a=pixels(BASE/'run'/name)
            yy,xx=np.where(a[:,:,3]>.01)
            margin=min(xx.min(),yy.min(),191-xx.max(),191-yy.max())
            report['min_margin_px']=min(report['min_margin_px'],int(margin));widths.append(int(xx.max()-xx.min()+1))
            for folder in ('run_n','run_e'):
                b=pixels(BASE/folder/name)
                diff=float(np.max(np.abs(a[:,:,3]-b[:,:,3])))
                report['alpha_max_difference']=max(report['alpha_max_difference'],diff)
    report['bbox_width_range']=[min(widths),max(widths)]
    assert report['min_margin_px']>=5,report
    assert report['alpha_max_difference']<=1/255+.0001,report
    root=bpy.data.objects['Swarm_Root'];animated=[o for o in bpy.context.scene.objects if o.animation_data]
    bpy.context.scene.frame_set(1);first=[np.array(o.matrix_local) for o in animated]
    bpy.context.scene.frame_set(9)
    report['loop_max_transform_difference']=max(float(np.max(np.abs(a-np.array(o.matrix_local)))) for a,o in zip(first,animated))
    assert report['loop_max_transform_difference']<1e-5
    report['normal_convention']=passes.validate_normal_convention(BASE/'verification')
    (BASE/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)

if __name__=='__main__':
    mode=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'test'
    if mode=='test':s,root=build()
    else:
        bpy.ops.wm.open_mainfile(filepath=str(BLEND));s=bpy.context.scene;root=bpy.data.objects['Swarm_Root']
    if mode=='verify':verify()
    else:render(s,root,mode=='test')
