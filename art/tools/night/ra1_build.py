"""RA1: approved Rainette source, articulated grounded leaps, CREA atlases and PBR seals.
Background only. Reuses the validated AV1 atlas/pass exporter and ash_lord materials.
--source-only, --resume, --icons-only, --verify are restartable stages.
"""
import sys, math, json, hashlib, inspect
from pathlib import Path
sys.dont_write_bytecode=True
import bpy
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/characters'),str(ROOT/'art/tools/iso'),str(Path(__file__).parent)]
import iso_rig, av1_build as common
from ardent_iso_build import empty, worn, mesh, bead, rings, material
from cd_cd1_common import tube, cyl, rgb
from PIL import Image, ImageChops
DEST=ROOT/'game/assets/sprites/characters/rainette'
SOURCE=ROOT/'art/blender/characters/rainette.blend'
WORK=SOURCE.with_name('rainette_frames')
ICONS=ROOT/'game/assets/sprites/icons/spells'
ANIMS={'idle':8,'crouch':2,'jump':4,'land':3,'leap':6,'spit':4,'breathe':4,'belch':6,
       'attack':6,'cast':4,'cast_ult':6,'death':8,'run':4,'dodge':4}
FPS={k:12 for k in ANIMS};FPS.update(idle=8,crouch=12,jump=12,land=15,leap=14,breathe=4,death=10,run=12,dodge=12)
DIRS=iso_rig.DIRECTIONS
posed_mesh=common.posed_mesh
parent_keep=common.parent_keep
# Keep the same tested CanvasTexture/normal/emission export and pixel-bound checks.
exec(inspect.getsource(common.resources).replace('averse','rainette').replace('"idle","run"','"idle","run","breathe"'),globals())
exec(inspect.getsource(common.atlases).replace("['Averse']","['Rainette']").replace('AV1','RA1'),globals())

def source():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/cd_rainette.blend'))
    root=next(o for o in bpy.data.objects if o.name.startswith('Rainette') and o.type=='EMPTY')
    s=next(s for s in bpy.data.scenes if root.name in s.objects)
    bpy.context.window.scene=s
    root.name='Rainette';root.location=(0,0,0);root.rotation_euler=(0,0,0);root.scale=(1,1,1)
    keep={root,*root.children_recursive}
    for o in list(s.objects):
        if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
    for o in keep:
        o.hide_render=False;o.animation_data_clear()
        if o.type=='CURVE':o.data.bevel_resolution=1;o.data.resolution_u=6
        for mod in o.modifiers:
            if mod.type=='SUBSURF':mod.levels=1;mod.render_levels=1
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
    for o in list(root.children_recursive):
        if o.type not in ('MESH','CURVE'):continue
        data=bpy.data.meshes.new_from_object(o.evaluated_get(deps),depsgraph=deps)
        ob=bpy.data.objects.new(o.name+' baked',data);s.collection.objects.link(ob)
        ob.parent=o.parent;ob.matrix_world=o.matrix_world.copy()
        name=o.name;bpy.data.objects.remove(o,do_unlink=True);ob.name=name
    bpy.context.view_layer.update()
    torso=bpy.data.objects['Lean amphibian torso'];arms=[bpy.data.objects['Leap arm '+str(i)] for i in (-1,1)]
    hips=[bpy.data.objects['Jump hip '+str(i)] for i in (-1,1)]
    for o in list(root.children):
        if o not in [torso,*hips]:parent_keep(o,torso)
    legs=[]
    for side,hip in zip((-1,1),hips):
        h=Vector((side*.12,.04,.91));k=h+Vector((side*.16,-.15,-.33));a=h+Vector((side*.13,.12,-.70))
        knee=empty('RA1 knee '+str(side),k,root);ankle=empty('RA1 ankle '+str(side),a,root)
        bpy.context.view_layer.update()
        for ob in list(hip.children):
            if ob.name.startswith(('Long articulated toe','Small gripping toe pad','Taut webbed foot','Elongated ankle')):parent_keep(ob,ankle)
            elif ob.name.startswith(('Bent reverse shin','Rusted fitted greave','Greave leather binding')):parent_keep(ob,knee)
        legs.append((hip,knee,ankle,h,k,a))
    sac=bpy.data.objects['Inflatable vocal sac'];head=bpy.data.objects['Frog head']
    # A tight mouth opens on attack/cast; tongue itself belongs to the following VFX lot.
    jaw=empty('RA1 articulated lower jaw',(0,-.08,1.52),torso)
    skin=bpy.data.materials['Rain-wet amphibian skin #5B6B4F']
    bead('Lower rain-wet jaw',(0,-.09,-.008),(.137,.068,.027),skin,jaw)
    dark=bpy.data.materials['Black iron #2B2A29']
    bead('Recessed mouth cavity',(0,-.153,.002),(.125,.008,.015),dark,jaw)
    rig=[torso,*arms,sac,head,jaw,*[o for leg in legs for o in leg[:3]]]
    rest={o.name:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in rig}
    root.scale=(.72,)*3;root.location.z=-.045*.72
    s=iso_rig.create_rig('CREA',192,reset=False);s.camera.data.shift_y=.21
    for ob in list(s.objects):
        if ob.type=='LIGHT':bpy.data.objects.remove(ob,do_unlink=True)
    for name,loc,energy,col in [('Warm upper left',(-4,-6,8),2.5,(1,.76,.53)),('Cold rain rim',(4,3,5),1.25,(.50,.66,.85))]:
        bpy.ops.object.light_add(type='SUN',location=loc);ob=bpy.context.object;ob.name=name
        ob.data.energy=energy;ob.data.color=col;ob.data.angle=.15;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
    s.world.color=(.18,)*3;s.eevee.taa_render_samples=12
    s.render.threads_mode='FIXED';s.render.threads=8
    s.view_layers[0].use_pass_normal=True;s.view_layers[0].use_pass_emit=True
    iso_rig.bake_ao_shadows(root)
    manifest={};start=1
    for anim,n in ANIMS.items():
        s.timeline_markers.new(anim,frame=start)
        manifest[anim]={'start':start,'frames':n,'fps':FPS[anim],'loop':anim in ('idle','run','breathe')}
        for i in range(n):
            pose(anim,i,n,rig,rest,legs)
            for ob in rig:
                for prop in ('location','rotation_euler','scale'):ob.keyframe_insert(prop,frame=start+i)
        start+=n+4
    s['animation_manifest']=json.dumps(manifest);s['render_px_per_u']=iso_rig.R;s['ground_pivot_px']=[96,136.32]
    s['RA1_notes']='CD Rainette preserved; wet olive skin, riveted corroded iron, reed spear. Grounded analytical two-bone legs; green vocal sac only emission. Airborne displacement provided by game lift_px, never baked twice. Attack impact zero-based frame 3/6. Run is a hop cycle; dodge is backward bound.'
    s.frame_start=1;s.frame_end=start-5;s.render.fps=12;s.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0;SOURCE.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE));print('RA1 SOURCE PASS',flush=True)

def pose(anim,i,n,rig,rest,legs):
    torso,al,ar,sac,head,jaw=rig[:6]
    for ob in rig:ob.location,ob.rotation_euler,ob.scale=[v.copy() for v in rest[ob.name]]
    p=i/(n-1);t=math.tau*i/n;pulse=math.sin(math.pi*p)
    c=.035+.012*math.sin(t);spread=0;air=0
    torso.rotation_euler.x=.035;head.rotation_euler.x=.018*math.sin(t+.3)
    sac.scale=(1+.05*math.sin(t),1+.09*math.sin(t),1+.06*math.sin(t))
    if anim=='crouch':c=[.12,.34][i]
    elif anim in ('jump','run','dodge','leap'):
        curve={'jump':[.31,.03,.00,.20],'run':[.30,.03,.01,.22],'dodge':[.28,.04,.00,.23],'leap':[.35,.16,.015,.00,.09,.30]}[anim]
        c=curve[i];air=math.sin(math.pi*p)*.10
        spread=.10*math.sin(math.pi*p);torso.rotation_euler.x=(.24 if anim!='dodge' else -.18)*pulse
        al.rotation_euler.x=(-.9 if anim!='dodge' else .7)*pulse;ar.rotation_euler.x=al.rotation_euler.x*.85
        al.rotation_euler.y=-.22*pulse;ar.rotation_euler.y=.22*pulse
    elif anim=='land':c=[.34,.23,.06][i];torso.rotation_euler.x=[.30,.15,.03][i]
    elif anim in ('spit','cast','attack'):
        k=i/(n//2) if i<=n//2 else (n-1-i)/(n-1-n//2)
        c=.10*k;torso.rotation_euler.x=-.12*math.sin(math.pi*p)+.22*k
        head.rotation_euler.x=-.10*k;jaw.rotation_euler.x=.65*k
        al.rotation_euler.x=-.27*k;ar.rotation_euler.x=-.39*k
        sac.scale=(1+.27*k,1+.45*k,1+.22*k)
    elif anim=='breathe':
        c=.14+.025*math.sin(t);torso.rotation_euler.x=.22+.055*math.sin(t)
        sac.scale=(1+.13*math.sin(t),1+.23*math.sin(t),1+.16*math.sin(t))
        al.rotation_euler.x=-.3;ar.rotation_euler.x=-.36;head.rotation_euler.x=.08*math.sin(t)
    elif anim in ('belch','cast_ult'):
        k=[.08,.38,.82,1,.70,.28][i];c=.09+.10*k
        sac.scale=(1+1.05*k,1+1.65*k,1+.85*k)
        torso.rotation_euler.x=-.15*k;head.rotation_euler.x=-.18*k;jaw.rotation_euler.x=.27*k
        al.rotation_euler.y=-.45*k;ar.rotation_euler.y=.45*k
        al.rotation_euler.x=-.44*k;ar.rotation_euler.x=-.37*k
    elif anim=='death':
        c=.32*p;torso.rotation_euler.x=1.05*p*p;torso.rotation_euler.y=.22*p
        pivot=Vector((0,0,.95))
        torso.location+=pivot-torso.rotation_euler.to_matrix()@pivot
        torso.location.y+=.08*p;torso.location.z-=.45*p*p
        head.rotation_euler.x=.27*p;al.rotation_euler.x=-.75*p;ar.rotation_euler.x=-1.05*p
        jaw.rotation_euler.x=.15*p;sac.scale=(1-.4*p,)*3
    torso.location.z-=c
    for side,arm in [(-1,al),(1,ar)]:arm.rotation_euler.z=side*.04*math.sin(t+.4)
    # Independent thigh/shin rotations solve each leg while toes remain grounded.
    for j,(hip,knee,ankle,H,K,A) in enumerate(legs):
        h=H+Vector((0,0,-c));a=A+Vector(((-1 if j==0 else 1)*spread,0,air))
        d=a-h;dist=d.length;axis=d.normalized();l1=(K-H).length;l2=(A-K).length
        pole=(K-H)-axis*(K-H).dot(axis);pole.normalize()
        along=(l1*l1-l2*l2+dist*dist)/(2*dist)
        k=h+axis*along+pole*math.sqrt(max(.00001,l1*l1-along*along))
        hip.location=h;hip.rotation_euler=(K-H).rotation_difference(k-h).to_euler()
        knee.location=k;knee.rotation_euler=(A-K).rotation_difference(a-k).to_euler()
        ankle.location=a;ankle.rotation_euler.x=-.12*air

def icons():
    for idx,key in enumerate(('langue','grand_saut','gluant','chant_de_crue')):
        s=iso_rig.create_rig('CREA',128);s.eevee.taa_render_samples=24
        s.camera.location=(2.3,-4.5,7);s.camera.rotation_euler=(-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=1.5
        s.view_settings.view_transform='AgX'
        try:s.view_settings.look='AgX - Medium High Contrast'
        except Exception:pass
        for ob in list(s.objects):
            if ob.type=='LIGHT':bpy.data.objects.remove(ob,do_unlink=True)
        for name,loc,power,col,size in [('Icon warm studio key',(-3,-4,6),650,(1,.80,.61),3),('Icon cold rim',(3,2,4),850,(.54,.72,.92),2)]:
            bpy.ops.object.light_add(type='AREA',location=loc);ob=bpy.context.object;ob.name=name;ob.data.energy=power;ob.data.color=col;ob.data.shape='DISK';ob.data.size=size;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
        s.world.color=(.10,)*3
        iron=worn('RA1 icon patinated black iron','161C1B','546057',1,.39)
        bronze=worn('RA1 icon worn bronze','36372B','9B9570',1,.36)
        slate=worn('RA1 incised wet shale','10191A','303C38',0,.52)
        accent=worn('RA1 vocal jade metal','253C31','647D68',1,.30)
        bs=accent.node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=rgb('8DBBA8');bs.inputs['Emission Strength'].default_value=.85
        r=empty('Rainette seal '+key)
        vs=[(-.45,-.40,0),(.29,-.46,0),(.46,-.18,0),(.43,.34,0),(.10,.45,0),(-.40,.31,0)]
        ob=mesh('Worn engraved shale',vs,[tuple(range(6))],slate,r,.018);ob.modifiers.new('Shale thickness','SOLIDIFY').thickness=.045
        for j in range(5):tube('Reed engraving',[(-.30+j*.14,.22,.018),(-.28+j*.14,.35,.018)],.004,iron,r)
        if idx==0:
            pts=[(-.29,-.31,.09),(-.32,-.10,.12),(-.27,.10,.14),(-.09,.23,.16),(.15,.18,.16),(.29,.06,.18),(.27,-.13,.20),(.10,-.23,.23),(-.03,-.16,.25),(.02,-.02,.27),(.17,.02,.29)]
            tube('Forged coiled tongue whip',pts,.038,bronze,r)
            tube('Vocal jade inlaid whip groove',[(x,y,z+.03) for x,y,z in pts],.009,accent,r)
            mesh('Barbed tongue tip',[(.10,-.02,.28),(.24,-.05,.28),(.27,.12,.28),(.16,.07,.34)],[(0,1,3),(1,2,3),(2,0,3)],iron,r,.008)
        elif idx==1:
            for side in (-1,1):
                pts=[(side*.10,-.30,.09),(side*.29,-.10,.13),(side*.15,.08,.18),(side*.22,.26,.20)]
                tube('Long flexed forged frog leg',pts,.04,bronze,r)
                for j in range(3):tube('Splayed webbed leap toe',[pts[-1],(side*.22+(j-1)*.10,.38,.21)],.022,iron,r)
            tube('Inlaid trajectory',[(0,-.35,.12),(-.04,-.12,.20),(0,.08,.29),(.03,.31,.28)],.013,accent,r)
        elif idx==2:
            for j in range(3):
                rr=.32-j*.075;tube('Forged viscous pool ripple',[(rr*math.cos(k*math.tau/48),rr*.72*math.sin(k*math.tau/48),.065+j*.008) for k in range(49)],.015,bronze,r)
            bead('Convex dark jade pool',(0,0,.07),(.21,.14,.025),accent,r)
            rings('Falling pointed globule',[(.12,.07,.06,-.03),(.19,.09,.075,-.03),(.27,.06,.055,-.03),(.43,.008,.008,-.03)],iron,r,24)
            tube('Jade globule incision',[(0,-.09,.17),(0,-.09,.24),(0,-.05,.36)],.012,accent,r)
        else:
            bead('Hammered vocal chamber',(0,-.04,.13),(.18,.22,.13),bronze,r)
            for j in range(7):
                a=(j-3)*.22;tube('Inlaid vocal chamber fold',[(math.sin(a)*.13,-.21,.17),(math.sin(a)*.18,-.02,.25),(math.sin(a)*.12,.15,.17)],.009,accent,r)
            for side in (-1,1):
                for j in range(2):
                    rr=.25+j*.10;tube('Cast chant resonance',[(side*rr*math.cos(a),rr*math.sin(a),.08) for a in [-.9+k*.09 for k in range(21)]],.018,iron,r)
        iso_rig.bake_ao_shadows(r);bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE.with_name('rainette_icon_'+key+'.blend')))
        iso_rig.render_frame(ICONS/('rainette_'+key+'.png'),passes=False)
        print('RA1 ICON PASS '+key,flush=True)

def assemble_pass_alpha():
    # Assemble rendered channels only: the Raw normal pass must share the diffuse
    # coverage after antialiasing. No painted geometry or generated pixel shapes.
    for anim in ANIMS:
        with Image.open(DEST/(anim+'.png')) as im:alpha=im.getchannel('A')
        for suffix in ('_n','_e'):
            path=DEST/(anim+suffix+'.png')
            with Image.open(path) as im:
                channels=im.convert('RGBA').split()
                if ImageChops.difference(channels[3],alpha).getbbox():
                    Image.merge('RGBA',(*channels[:3],alpha)).save(path,optimize=True,compress_level=9)

def contact_verify():
    report={'character':'rainette','cell':192,'directions':list(DIRS),'pivot':[96,136.32],'R':iso_rig.R,'attack_impact_frame_zero_based':3,'airborne_offset':'game lift_px','animations':{}}
    board=Image.new('RGBA',(1536,len(ANIMS)*192+384),(20,25,29,255))
    for row,(anim,n) in enumerate(ANIMS.items()):
        with Image.open(DEST/(anim+'.png')) as diffuse:alpha=diffuse.getchannel('A')
        for su in ('','_n','_e'):
            with Image.open(DEST/(anim+su+'.png')) as im:
                assert im.size==(192*n,1536),(anim,su,im.size)
                assert im.getchannel('A').getbbox(),(anim,su,'empty')
                assert not ImageChops.difference(im.getchannel('A'),alpha).getbbox(),(anim,su,'alpha mismatch')
                if not su:
                    for d in range(8):
                        hashes=[]
                        for f in range(n):
                            cell=im.crop((f*192,d*192,(f+1)*192,(d+1)*192));bb=cell.getbbox()
                            assert bb and min(bb[:2])>=3 and max(bb[2:])<=189,(anim,d,f,bb)
                            hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
                        assert len(set(hashes))==n,(anim,d,'duplicate')
                        board.alpha_composite(im.crop((n//2*192,d*192,(n//2+1)*192,(d+1)*192)),(d*192,row*192))
        report['animations'][anim]={'frames':n,'fps':FPS[anim],'directions':8}
    frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
    keys=['rainette_langue','rainette_grand_saut','rainette_gluant','rainette_chant_de_crue','eclat_de_braise','nova_ardente','cendres','brasier']
    for j,key in enumerate(keys):
        path=ICONS/(key+'.png')
        if not path.exists():continue
        im=Image.open(path).convert('RGBA')
        if key.startswith('rainette'):assert im.size==(128,128)
        for size,y in [(128,len(ANIMS)*192),(64,len(ANIMS)*192+144)]:
            tile=Image.new('RGBA',(size,size));tile.alpha_composite(im.resize((size,size),Image.Resampling.LANCZOS));tile.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS));board.alpha_composite(tile,(j*192+(192-size)//2,y))
    refs=['art/tools/characters/_cd_rainette.png','art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/ui/_i2_contact.png','art/tools/iso/_c1_contact.png']
    for j,path in enumerate(refs):
        im=Image.open(ROOT/path).convert('RGBA');im.thumbnail((300,155),Image.Resampling.LANCZOS);board.alpha_composite(im,(j*307,len(ANIMS)*192+224))
    board.save(ROOT/'art/tools/night/_ra1_contact.png',optimize=True)
    report['directional_frames']=sum(ANIMS.values())*8
    (DEST/'rainette_manifest.json').write_text(json.dumps(report,indent=2))
    print('RA1 VERIFY PASS '+str(report['directional_frames'])+' frames / 42 atlases / 4 icons',flush=True)

if __name__=='__main__':
    if '--verify' in sys.argv:contact_verify()
    elif '--assemble-alpha' in sys.argv:assemble_pass_alpha();contact_verify()
    elif '--icons-only' in sys.argv:icons()
    else:
        if '--resume' not in sys.argv or not SOURCE.exists() or '--rebuild-source' in sys.argv:source()
        if '--source-only' not in sys.argv:atlases();assemble_pass_alpha();icons();contact_verify()
