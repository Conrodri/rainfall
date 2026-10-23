"""BO2: Bourbe companion, approved CD materials and native CREA scale.
Background Blender only; --source-only / --resume / --verify / --icons-only.
Reuses AV1 posed-mesh/atlas/CanvasTexture pipeline and ash_lord PBR geometry.
"""
import sys, math, json, inspect, random
from pathlib import Path
sys.dont_write_bytecode=True
import bpy
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/characters'),str(ROOT/'art/tools/iso')]
import iso_rig, av1_build as common
from cd_cd3_common import tube, ell, loft, rgb, empty
from ash_lord_build import worn, mesh
from PIL import Image, ImageChops
DEST=ROOT/'game/assets/sprites/characters/bourbe/motte'
SOURCE=ROOT/'art/blender/characters/bourbe_motte.blend'
WORK=ROOT/'art/blender/characters/bourbe_motte_frames'
ICONS=ROOT/'game/assets/sprites/icons/spells'
ANIMS={'idle':6,'run':6,'die':4}
FPS={'idle':8,'run':12,'die':8}
DIRS=iso_rig.DIRECTIONS
posed_mesh=common.posed_mesh
# Exact validated export format; only paths and source-root name differ.
exec(inspect.getsource(common.resources).replace('characters/averse/', 'characters/bourbe/motte/').replace('averse_emission.tres','motte_emission.tres').replace('averse.tres','motte.tres'),globals())
exec(inspect.getsource(common.atlases).replace("['Averse']", "['Motte']").replace('AV1','BO2'),globals())

def source():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/cd_bourbe.blend'))
    s=bpy.context.scene
    root=next(o for o in s.objects if o.type=='EMPTY' and o.name.startswith('Motte'))
    keep={root,*root.children_recursive}
    root.parent=None;root.location=(0,0,0);root.rotation_euler=(0,0,0);root.scale=(1,1,1);root.name='Motte'
    for o in list(s.objects):
        if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
    for o in keep:o.animation_data_clear();o.hide_render=False;o.hide_set(False)
    mats={m.name:m for m in bpy.data.materials}
    mud=mats['Argile humide striée'];wood=mats['Racines tendons'];bronze=mats['Bronze vert-de-gris'];moss=mats['Mousse éparse'];edge=mats['Tranches bronze ancien'];light=next(m for m in mats.values() if m.name.startswith('Unique feu follet'))
    p=mud.node_tree.nodes.get('Principled BSDF');p.inputs['Coat Weight'].default_value=.62;p.inputs['Coat Roughness'].default_value=.14
    light.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=1.35
    core=empty('Torn clay and broken bronze');core.parent=root
    limbs=[]
    for o in list(root.children):
        if o==core:continue
        if o.name.startswith('Patte racine'):
            limb=empty('Front root '+str(len(limbs)));limb.parent=root;limb.location=(math.copysign(.14,o.data.splines[0].bezier_points[0].co.x),0,.16)
            o.parent=limb;o.location=-limb.location;limbs.append(limb)
        else:o.parent=core
    # Torn strata and splintered roots, without a face or cartoon eyes.
    for side in (-1,1):
        for j in range(3):
            tube('Wet torn ribs',[(side*(.08+j*.037),-.13,.32-j*.045),(side*(.13+j*.03),-.183,.23-j*.04),(side*(.14+j*.025),-.155,.12-j*.025)],.009,mud,core)
        limb=empty('Rear root '+str(side));limb.parent=root;limb.location=(side*.15,.08,.16);limbs.append(limb)
        tube('Splintered hind tendon',[(0,0,0),(side*.10,.10,-.04),(side*.16,.13,-.14),(side*.19,.04,-.15)],.019,wood,limb)
        tube('Fine root claw',[(side*.13,.11,-.12),(side*.19,.15,-.15)],.007,wood,limb)
    for j in range(7):
        t=j*2.399
        tube('Clinging root filament',[(.12*math.sin(t),.08*math.cos(t),.35),(.19*math.sin(t),.14*math.cos(t),.20),(.22*math.sin(t+.25),.16*math.cos(t+.25),.07)],.005,wood,core)
    for j in range(8):
        t=.30+j*.69
        ell('Verdigris rivet',(.175*math.sin(t),.138*math.cos(t),.24+.02*math.sin(t*2)),(.012,.012,.013),edge,core)
    tube('Broken dorsal bronze clasp',[(-.17,.07,.21),(-.11,.14,.26),(.02,.145,.28),(.14,.08,.23)],.016,bronze,core)
    for j in range(11):
        t=j*2.399
        ell('Moss trapped in clay seams',(.18*math.sin(t),.14*math.cos(t),.14+.14*(j%3)/2),(.018,.011,.019),moss,core)
    flames=empty('Cold follet breathing through torn crown');flames.parent=core
    for o in list(core.children):
        if o.name.startswith('Même feu follet'):o.parent=flames
    # The same heart leaks from the crown: the ally remains identifiable from behind.
    loft('Crown follet',[(.30,.018,.013,.015),(.34,.029,.017,.018),(.40,.012,.009,.018),(.465,.001,.001,.035)],light,flames,N=9,rough=.06)
    # Convert curves once; evaluated meshes are reused for each atlas direction.
    for o in list(root.children_recursive):
        if o.type=='CURVE':
            bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
    s=iso_rig.create_rig('CREA',192,reset=False);s.camera.data.shift_y=.21
    for name,loc,power,color in [('Sun_chaud_haut_gauche',(-4,-6,8),2.5,(1,.76,.53)),('Cold rim',(4,3,5),.65,(.5,.66,.85))]:
        bpy.ops.object.light_add(type='SUN',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.color=color;o.data.angle=.15;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    s.world.color=(.18,)*3;s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0
    s.eevee.taa_render_samples=12;s.render.threads_mode='FIXED';s.render.threads=8
    s.view_layers[0].use_pass_normal=True;s.view_layers[0].use_pass_emit=True
    iso_rig.bake_ao_shadows(root)
    rig=[root,core,*limbs,flames];rest={o.name:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in rig}
    manifest={};start=1
    for anim,n in ANIMS.items():
        manifest[anim]={'start':start,'frames':n,'fps':FPS[anim],'loop':anim!='die'};s.timeline_markers.new(anim,frame=start)
        for i in range(n):
            for o in rig:o.location,o.rotation_euler,o.scale=[v.copy() for v in rest[o.name]]
            t=i/n;wave=math.sin(math.tau*t)
            if anim=='idle':
                core.scale=(1+.025*wave,1+.025*wave,1-.035*wave);core.rotation_euler.y=.025*wave
                flames.scale=(1+.12*wave,1+.12*wave,1+.14*math.sin(math.tau*t+.4))
            elif anim=='run':
                core.location.z=.025*(1-math.cos(2*math.tau*t));core.scale=(1-.07*wave,1+.07*wave,1-.06*wave);core.rotation_euler.y=.07*wave
                for j,o in enumerate(limbs):
                    a=math.sin(math.tau*t+(j%2)*math.pi);o.rotation_euler.x=.36*a;o.rotation_euler.y=.22*a;o.location.z+=.025*max(0,a)
                flames.scale=(1,1,1+.18*wave)
            else:
                q=i/(n-1);core.scale=(1+.40*q,1+.38*q,1-.88*q);core.rotation_euler.y=.10*math.sin(math.pi*q)
                for j,o in enumerate(limbs):o.rotation_euler.y=(-1 if j%2 else 1)*.55*q;o.scale.z=1-.70*q
                flames.scale=(max(.001,1-q),)*3
            for o in rig:
                for prop in ('location','rotation_euler','scale'):o.keyframe_insert(prop,frame=start+i)
        start+=n+4
    s['animation_manifest']=json.dumps(manifest);s['ground_pivot_px']=[96,136.32];s['render_px_per_u']=iso_rig.R
    s['BO2_notes']='Approved CD motte extracted at native world scale; wet stratified clay, root-tendon scuttle, fractured verdigris clasp; same #8DBBA8 cold follet, crown spill visible from rear. Idle breath 6, diagonal crawl 6, clay collapse 4. Padded cell192 / tight envelope96; no independent shadow or ally ring (BO3 owns ring).'
    s.frame_start=1;s.frame_end=start-5;s.render.fps=12;s.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0;SOURCE.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    print('BO2 SOURCE PASS',flush=True)

def fix_alpha():
    for anim in ANIMS:
        with Image.open(DEST/(anim+'.png')) as im:alpha=im.getchannel('A')
        for suffix in ('_n','_e'):
            p=DEST/(anim+suffix+'.png')
            with Image.open(p) as im:
                ch=im.convert('RGBA').split()
                if ImageChops.difference(ch[3],alpha).getbbox():Image.merge('RGBA',(*ch[:3],alpha)).save(p,optimize=True,compress_level=9)

def icons():
    for idx,key in enumerate(('gifle_de_vase','detacher','rappel','bourbier')):
        s=iso_rig.create_rig('CREA',128);s.eevee.taa_render_samples=20
        s.camera.location=(2.4,-4.8,7);s.camera.rotation_euler=(-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=1.45
        s.view_settings.view_transform='AgX'
        try:s.view_settings.look='AgX - Medium High Contrast'
        except Exception:pass
        clay=worn('Icon wet slate clay','171E29','384653',0,.34);p=clay.node_tree.nodes.get('Principled BSDF');p.inputs['Coat Weight'].default_value=.6
        bronze=worn('Icon worn solid bronze','31443B','A8946E',1,.38);dark=worn('Engraved dark field','0C1116','26313A',.65,.43)
        fire=bpy.data.materials.new('Bourbe cold follet');fire.use_nodes=True;p=fire.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=rgb('8DBBA8');p.inputs['Emission Color'].default_value=rgb('8DBBA8');p.inputs['Emission Strength'].default_value=1.3
        r=empty('Bourbe seal '+key)
        base=mesh('Chipped engraved stone', [(-.44,-.39,0),(.32,-.44,0),(.47,-.21,0),(.42,.36,0),(-.19,.44,0),(-.45,.23,0)],[tuple(range(6))],dark,r,.02);base.modifiers.new('Substantial thickness','SOLIDIFY').thickness=.065
        for j in range(7):
            x=-.30+j*.09;tube('Cut tally',[(x,.28,.015),(x+.04,.34,.015)],.005,bronze,r)
        if idx==0:
            ell('Broad mud palm',(-.03,-.03,.13),(.20,.20,.075),clay,r)
            for j in range(4):
                x=-.23+j*.12;tube('Tapered root finger',[(x,-.04,.14),(x-.025,-.23,.15),(x+.03,-.36,.12)],.034,bronze,r)
            tube('Cold heart palm fissure',[(-.10,.13,.20),(.02,.03,.21),(-.01,-.12,.21)],.016,fire,r)
        elif idx==1:
            for x,y,sc in [(-.18,-.07,.21),(.22,.20,.115)]:
                ell('Torn clay mass',(x,y,.13),(sc,sc*.85,sc*.65),clay,r)
                tube('Fractured bronze staple',[(x-sc,y,.14),(x,y-sc,.24),(x+sc,y,.14)],.025,bronze,r)
                tube('Follet through split',[(x-.03,y-.08,.27),(x+.03,y,.30),(x,y+.08,.27)],.013,fire,r)
            tube('Severed root',[(-.02,.08,.12),(.05,.13,.16),(.10,.17,.13)],.014,bronze,r)
        elif idx==2:
            for j in range(3):
                t=j*math.tau/3;pts=[]
                for k in range(15):
                    a=t+k*.08;rad=.39-k*.017;pts.append((rad*math.cos(a),rad*math.sin(a),.10+k*.004))
                tube('Returning root spiral',pts,.027,bronze,r);tube('Cold returning current',[(x,y,z+.029) for x,y,z in pts[3:]],.009,fire,r)
            ell('Rejoining heart',(0,0,.14),(.07,.07,.065),clay,r)
        else:
            for j in range(3):
                a=.37-j*.09;tube('Mire concentric bronze ripples',[(a*math.cos(k*math.tau/48),a*.80*math.sin(k*math.tau/48),.07+j*.025) for k in range(49)],.020,bronze,r)
            for j in range(4):
                t=j*math.tau/4;tube('Roots sinking into bog',[(.37*math.cos(t),.34*math.sin(t),.13),(.18*math.cos(t+.3),.16*math.sin(t+.3),.16),(0,0,.11)],.022,clay,r)
            tube('Cold bog fault',[(-.12,-.02,.16),(0,.04,.18),(.09,-.07,.16)],.018,fire,r)
        bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE.with_name('bourbe_icon_'+key+'.blend')))
        iso_rig.render_frame(ICONS/('bourbe_'+key+'.png'),passes=False)
    print('BO2 ICONS PASS',flush=True)

def verify():
    board=Image.new('RGBA',(1536,2080),(17,22,28,255));report={'cell':192,'tight_envelope':96,'pivot':[96,136.32],'directions':list(DIRS),'animations':{}}
    for ai,(anim,n) in enumerate(ANIMS.items()):
        images=[Image.open(DEST/(anim+su+'.png')).convert('RGBA') for su in ('','_n','_e')]
        assert all(im.size==(n*192,1536) and max(im.size)<=4096 for im in images)
        assert all(ImageChops.difference(images[0].getchannel('A'),im.getchannel('A')).getbbox() is None for im in images[1:])
        sizes=[]
        for row in range(8):
            for f in range(n):
                box=(f*192,row*192,(f+1)*192,(row+1)*192);im=images[0].crop(box);bounds=im.getchannel('A').getbbox();assert bounds,(anim,row,f)
                assert bounds[0]>=48 and bounds[2]<=144 and bounds[1]>=64 and bounds[3]<=160,(anim,row,f,bounds)
                sizes.append([bounds[2]-bounds[0],bounds[3]-bounds[1]])
            board.alpha_composite(images[0].crop((0,row*192,192,row*192+192)),(row*192,ai*192))
        for f in range(n):board.alpha_composite(images[0].crop((f*192,2*192,(f+1)*192,3*192)),(f*192,(3+ai)*192))
        for pi,im in enumerate(images):board.alpha_composite(im.crop((0,2*192,192,3*192)),((ai*3+pi)*160,1152))
        report['animations'][anim]={'frames_per_direction':n,'total':n*8,'max_content_px':[max(v[0] for v in sizes),max(v[1] for v in sizes)]}
    refs=['art/tools/characters/_cd_bourbe.png','art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/ui/_i2_contact.png']
    for j,p in enumerate(refs):
        path=ROOT/p
        if path.exists():
            im=Image.open(path).convert('RGBA');im.thumbnail((300,300),Image.Resampling.LANCZOS);board.alpha_composite(im,(j*305,1710))
    frames=list((ROOT/'game/assets/sprites').rglob('spell_frame.png'))
    frame=Image.open(frames[0]).convert('RGBA') if frames else None
    keys=['bourbe_gifle_de_vase','bourbe_detacher','bourbe_rappel','bourbe_bourbier','eclat_de_braise','nova_ardente','cendres','brasier']
    for j,k in enumerate(keys):
        path=ICONS/(k+'.png')
        if not path.exists():continue
        im=Image.open(path).convert('RGBA')
        for size,y in [(128,1376),(64,1536)]:
            tile=im.resize((size,size),Image.Resampling.LANCZOS)
            if frame:tile.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS))
            board.alpha_composite(tile,(j*192+(192-size)//2,y))
    board.save(ROOT/'art/tools/night/_bo2_contact.png',optimize=True)
    (DEST/'motte_manifest.json').write_text(json.dumps(report,indent=2))
    print('BO2 VERIFY PASS: 128 frames, 24 animations, 9 matched atlases, native scale/pivot',flush=True)

if __name__=='__main__':
    if '--verify' in sys.argv:verify()
    elif '--icons-only' in sys.argv:icons();verify()
    else:
        if '--resume' not in sys.argv or not SOURCE.exists():source()
        if '--source-only' not in sys.argv:atlases();fix_alpha();icons();verify()


