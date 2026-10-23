"""M2: animate the approved M1b sources; fixed CREA sheets and attachment manifest."""
import sys, math, json
from pathlib import Path
import bpy
from mathutils import Vector, Matrix, Euler
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/characters'))
import m1_build as base
from bpy_extras.object_utils import world_to_camera_view
from PIL import Image
OUT=ROOT/'art/tools/characters/_m2_out'
DEST=ROOT/'game/assets/sprites/characters'
ANIMS={'rictus':{'idle':8,'run':8,'slash':4,'throw':4,'spin':8,'stagger':3,'summon':6,'lift':3,'death':6,'throw_ult':6},'montreur':{'hover':6,'pull':4}}
DIRS=list(base.DIRECTIONS)
PIVOT=[96,136.32]
manifest={'format':{'version':1,'coordinates':'pixels relative to actor foot/origin pivot; +x right, +y down. Add cell_pivot_px for cell coordinates. Montreur coordinates exclude game lift. Frame indices zero based; impact frame N/2 (2 slash/throw, 3 summon).','cell_size':192,'cell_pivot_px':PIVOT,'directions':DIRS,'width_px':1,'color':'#9FC8C0','alpha':0.35,'montreur_alpha':0.8,'montreur_lift_u':1.4,'montreur_offset_screen_px':[-19.2,-19.2],'pairing':{'head':'finger_2','elbow_l':'finger_0','elbow_r':'finger_4','knee_l':'finger_1','knee_r':'finger_3'},'montreur_animation':'pull for spin/lift/summon/throw, hover otherwise; index = Rictus frame modulo companion frame count','spin':'one row e; reuse spin_e for any facing'},'animations':{}}

def aim(rig,name,direction,parent_delta=Matrix.Identity(4)):
    b=rig.data.bones[name];q=(b.tail_local-b.head_local).rotation_difference(Vector(direction))
    rig.pose.bones[name].matrix=parent_delta @ Matrix.Translation(b.head_local) @ q.to_matrix().to_4x4() @ b.matrix_local.to_3x3().to_4x4()
    bpy.context.view_layer.update()
    return rig.pose.bones[name].matrix @ b.matrix_local.inverted()

def delta(rig,name):
    bpy.context.view_layer.update();return rig.pose.bones[name].matrix @ rig.data.bones[name].matrix_local.inverted()

def pose(actor,root,rig,anim,f,n):
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    root.rotation_euler=(0,0,0);root.location=(0,0,0)
    t=f/n;w=math.tau*t; pulse=math.sin(math.pi*f/(n-1)) if n>1 else 0
    if actor=='montreur':
        rig.pose.bones['root'].location.z=.018*math.sin(w)
        for side,suffix in [(-1,'L'),(1,'R')]:
            rig.pose.bones['upper_arm.'+suffix].rotation_mode='XYZ'
            rig.pose.bones['upper_arm.'+suffix].rotation_euler.x=(-.22*pulse if anim=='pull' else .035*math.sin(w+side))
            rig.pose.bones['hand.'+suffix].rotation_mode='XYZ';rig.pose.bones['hand.'+suffix].rotation_euler.y=.12*math.sin(w+side)
        return
    b=rig.pose.bones['root'];b.rotation_mode='XYZ';b.location.z=.008*math.sin(w)
    if anim=='run':b.location.z=.020*(1-math.cos(w*2));b.rotation_euler.x=.07
    if anim=='lift':b.rotation_euler.x=-.10*pulse # game applies lift_px; sprite stays at its own origin
    if anim=='stagger':b.rotation_euler.y=.14*math.sin(w)
    if anim=='slash':
        b.matrix=Matrix.Translation((0,0,b.location.z)) @ Euler(([.02,-.16,.17,.02][f],0,[-.48,-.90,.90,.08][f])).to_matrix().to_4x4() @ rig.data.bones['root'].matrix_local
    if anim=='throw_ult':
        b.matrix=Matrix.Translation((0,0,b.location.z)) @ Euler(([0,.08,.10,-.06,-.04,0][f],0,[0,-.16,-.32,.24,.12,0][f])).to_matrix().to_4x4() @ rig.data.bones['root'].matrix_local
    if anim=='death':b.location.z=-.46*f/(n-1);b.rotation_euler.x=1.30*f/(n-1)
    h=rig.pose.bones['head'];hb=rig.data.bones['head'];h.rotation_mode='QUATERNION'
    recoil=([0,.10,-.45,-.12][f] if anim=='slash' else (-.34 if anim=='spin' else 0))
    h.matrix=delta(rig,'neck') @ Matrix.Translation(hb.head_local+Vector((0,0,-.05 if anim=='spin' else 0))) @ Euler((.13+recoil+.025*math.sin(w),-.40+.025*math.cos(w),.035)).to_matrix().to_4x4() @ hb.matrix_local.to_3x3().to_4x4()
    spine_delta=delta(rig,'spine')
    for side,suffix in [(-1,'L'),(1,'R')]:
        upper=Vector((side, .025*math.sin(w+side), .025+.025*math.sin(w)))
        phase=w-.48+(0 if side<0 else 1.35)
        swing=math.radians(27)*math.sin(phase)
        fore=Vector((side*.065,math.sin(swing),-math.cos(swing)))
        resting=fore.copy()
        if anim in ('slash','throw'):
            # The elbow initiates; the forearm whips through the exact impact frame.
            strength=[0,.45,1,0][f]
            upper=Vector((side, -.70*strength, .08+.10*strength))
            fore=Vector((side*.15,-1.7*strength,-1+1.1*strength))
            if anim=='slash':
                upper=Vector((side,[.15,.65,-.72,.03][f]*side,[.03,.03,.08,.03][f]))
                angle=[0,-math.pi/2,math.pi/2,0][f]
                fore=Vector((side*.12,-math.sin(angle),-math.cos(angle))) if f in (1,2) else resting
                if f in (1,2):fore.z-=.16
            elif f==n-1:fore=resting
        if anim=='summon':
            strength=[0,.25,.65,1,.40,0][f];upper.z+=strength*.85;fore=resting.lerp(Vector((side*.12,-.12,-.4)),strength)
        if anim=='throw_ult':
            strength=[0,.15,.45,1,.55,0][f]
            upper=Vector((side,-.65*math.sin(math.pi*strength),.03*(1-strength)))
            fore=resting.lerp(Vector((side*math.cos(.48),side*math.sin(.48),-.07)),strength)
        if anim=='spin':upper=Vector((side*math.cos(.48),side*math.sin(.48),0));fore=upper.copy()
        if anim=='death':upper=Vector((side*.3,.02,-1));fore=Vector((side*.05,-.08,-1))
        du=aim(rig,'upper_arm.'+suffix,upper,spine_delta)
        # Child head is the transformed elbow; desired direction remains actor-local.
        bfore=rig.data.bones['forearm.'+suffix];head=du@bfore.head_local
        rot=(bfore.tail_local-bfore.head_local).rotation_difference(fore)
        rig.pose.bones[bfore.name].matrix=Matrix.Translation(head) @ rot.to_matrix().to_4x4() @ bfore.matrix_local.to_3x3().to_4x4()
        bpy.context.view_layer.update()
        hand=rig.pose.bones['hand.'+suffix];hand.rotation_mode='XYZ';hand.rotation_euler=(.34+.10*math.sin(w+side),side*.18,side*.12)
        hand.rotation_euler.x=.30+.23*math.sin(phase-.40)
        if anim=='spin' or (anim=='throw_ult' and f==3) or (anim in ('slash','throw') and f in (1,2)):
            outward=fore.normalized()
            # Align the complete hand/blade chain in actor space, including blade tip.
            for bone in ('hand.'+suffix,'dagger.'+suffix):
                pb=rig.pose.bones[bone];bb=rig.data.bones[bone]
                parent_delta=delta(rig,pb.parent.name)
                pos=parent_delta @ bb.head_local
                q=(bb.tail_local-bb.head_local).rotation_difference(outward)
                pb.matrix=Matrix.Translation(pos) @ q.to_matrix().to_4x4() @ bb.matrix_local.to_3x3().to_4x4()
                bpy.context.view_layer.update()
        if anim=='spin':
            rig.pose.bones['thigh.'+suffix].rotation_mode='XYZ';rig.pose.bones['thigh.'+suffix].rotation_euler.x=.22
            rig.pose.bones['shin.'+suffix].rotation_mode='XYZ';rig.pose.bones['shin.'+suffix].rotation_euler.x=-.50
        if anim=='run':
            rig.pose.bones['thigh.'+suffix].rotation_mode='XYZ';rig.pose.bones['thigh.'+suffix].rotation_euler.x=.48*math.sin(w+side*math.pi/2)
            rig.pose.bones['shin.'+suffix].rotation_mode='XYZ';rig.pose.bones['shin.'+suffix].rotation_euler.x=-.38*max(0,math.cos(w+side*math.pi/2))
        if anim=='lift':rig.pose.bones['shin.'+suffix].rotation_mode='XYZ';rig.pose.bones['shin.'+suffix].rotation_euler.x=-.25*pulse
    bpy.context.view_layer.update()

def corrections(root,rig):
    root.name='Rictus';rig.name='Rictus_Rig';rig.data.name='Rictus_Skeleton'
    head=next(o for o in root.children_recursive if o.name.startswith('Tilted porcelain head'))
    head.matrix_world=Matrix.Translation(head.matrix_world.translation) @ Matrix.Diagonal(Vector((.95,1,1.035,1)));bpy.context.view_layer.update()
    face=next(o for o in root.children_recursive if o.name.startswith('Fissured porcelain face'))
    for v in face.data.vertices:
        z=v.co.z; factor=math.sqrt(max(.10,1-((z-.018)/.146)**2));v.co.x*=.78+.22*factor
    ruff=next(o for o in root.children_recursive if o.name.startswith('Collapsed pleated ruff'));ruff.scale=(1.62,1.60,1)
    mats=base.pbr()
    for side,suffix in [(-1,'L'),(1,'R')]:
        foot=next(o for o in root.children_recursive if o.name=='Foot_'+suffix)
        shoe=next(o for o in foot.children_recursive if o.name.startswith('Narrow rain swollen wooden shoe'));shoe.hide_render=True
        x=side*.14
        verts=[(x-.032,-.135,.025),(x+.032,-.135,.025),(x+.028,.030,.025),(x-.028,.030,.025),(x-.026,-.122,.058),(x+.026,-.122,.058),(x+.025,.021,.080),(x-.025,.021,.080)]
        obj=base.mesh('Carved articulated wooden foot '+suffix,verts,[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],mats['wood'],root)
        bev=obj.modifiers.new('Worn wooden foot edges','BEVEL');bev.width=.008;bev.segments=2
        bpy.context.view_layer.update();world=obj.matrix_world.copy();obj.parent=rig;obj.parent_type='BONE';obj.parent_bone='foot.'+suffix;obj.matrix_world=world
        # Real articulated ankle bridges the shank to the carved shoe.
        o=base.limb('Wood ankle tenon '+suffix,(side*.14,0,.140),(side*.14,-.025,.052),.014,.020,mats['peg'],root)
        bpy.context.view_layer.update();world=o.matrix_world.copy();o.parent=rig;o.parent_type='BONE';o.parent_bone='foot.'+suffix;o.matrix_world=world
        o=base.rod('Ankle hinge axle '+suffix,[(side*.14-.027,0,.092),(side*.14+.027,0,.092)],.009,mats['iron'],root)
        bpy.context.view_layer.update();world=o.matrix_world.copy();o.parent=rig;o.parent_type='BONE';o.parent_bone='foot.'+suffix;o.matrix_world=world
    for o in root.children_recursive:
        if o.name.startswith('string_wrist.'):
            suffix=o.name[-1];b=rig.data.bones['forearm.'+suffix];o.name='string_elbow.'+suffix;o.parent_bone=b.name
            o.matrix_world=rig.matrix_world @ Matrix.Translation(b.head_local)
    root['game_name']='Rictus'

def corrections_m2b(root,rig):
    """Apply once to the approved M2 scene, preserving its existing design and rig."""
    if not root.get('M2b_head_offsets'):
        cranium=next(o for o in root.children_recursive if o.name.startswith('Carved wooden cranium'))
        cranium.location.y+=.045
        cap=next(o for o in root.children_recursive if o.name.startswith('Small collapsed soaked fool cap'))
        cap.location.z-=.111*.48
        root['M2b_head_offsets']=True
    if root.get('M2b_geometry'):return
    cranium=next(o for o in root.children_recursive if o.name.startswith('Carved wooden cranium'))
    cranium.scale.y*=1.65
    cap=next(o for o in root.children_recursive if o.name.startswith('Small collapsed soaked fool cap'))
    cap.scale=(1.30,1.22,1.48)
    root.scale=tuple(v*1.15 for v in root.scale)
    root['M2b_geometry']='15 percent at foot origin; oval wooden cranium; visible soaked cap'
    bpy.context.view_layer.update()

def points(root,actor):
    s=bpy.context.scene;out={}
    for o in root.children_recursive:
        if not o.get('M2_attachment'):continue
        if actor=='rictus':
            name='head' if o.name.startswith('string_head') else ('elbow_' if 'elbow' in o.name else 'knee_')+o.name[-1].lower()
        else:name='finger_'+str(int(o.name.split('_')[-1])-1)
        v=world_to_camera_view(s,s.camera,o.matrix_world.translation);out[name]=[round(v.x*192-PIVOT[0],3),round((1-v.y)*192-PIVOT[1],3)]
    return out

def resources(actor):
    out=DEST/actor; ext=[];subs=[];animations=[];sid=0
    for ai,(anim,n) in enumerate(ANIMS[actor].items()):
        eid=ai*2+1
        for off,suffix in [(0,''),(1,'_n')]:ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/{actor}/{anim}{suffix}.png" id="{eid+off}"]')
        cid='c'+str(ai);subs.append(f'[sub_resource type="CanvasTexture" id="{cid}"]\ndiffuse_texture = ExtResource("{eid}")\nnormal_texture = ExtResource("{eid+1}")')
        for row,d in enumerate(DIRS[:1] if anim=='spin' else DIRS):
            frames=[]
            for f in range(n):
                sid+=1;aid='a'+str(sid);subs.append(f'[sub_resource type="AtlasTexture" id="{aid}"]\natlas = SubResource("{cid}")\nregion = Rect2({f*192}, {row*192}, 192, 192)');frames.append('{"duration": 1.0, "texture": SubResource("'+aid+'")}')
            loop=anim in ('idle','run','spin','hover','pull')
            speed={'idle':8,'run':12,'slash':16,'throw':12,'spin':16,'stagger':10,'summon':12,'lift':12,'death':10,'hover':8,'pull':10,'throw_ult':12}[anim]
            animations.append('{"frames": ['+', '.join(frames)+f'], "loop": {str(loop).lower()}, "name": &"{anim}_{d}", "speed": {speed}.0'+'}')
    (out/(actor+'.tres')).write_text(f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(subs)+1} format=3]\n\n'+'\n\n'.join(ext+subs)+'\n\n[resource]\nanimations = ['+',\n'.join(animations)+']\n')

def build(actor):
    source=ROOT/'art/blender/characters'/(actor+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
    root=bpy.data.objects['Rictus' if actor=='rictus' else 'Montreur'];rig=next(o for o in root.children_recursive if o.type=='ARMATURE')
    rig.animation_data_clear();root.animation_data_clear()
    for action in list(bpy.data.actions):
        if action.name.startswith(actor+'_'):bpy.data.actions.remove(action)
    root.location.z=0
    base.iso_rig.create_rig('CREA',192,target=(0,0,0),reset=False);s.camera.data.shift_y=.21
    if actor=='rictus':corrections_m2b(root,rig)
    s.eevee.taa_render_samples=8;s.render.threads_mode='FIXED';s.render.threads=8
    pose(actor,root,rig,'idle' if actor=='rictus' else 'hover',0,8)
    # Store each animation as an independently selectable action.
    for anim,n in ANIMS[actor].items():
        rig.animation_data_clear()
        action=None
        for f in range(n):
            if rig.animation_data:rig.animation_data.action=None
            pose(actor,root,rig,anim,f,n)
            if action is not None:rig.animation_data.action=action
            for b in rig.pose.bones:
                b.keyframe_insert('location',frame=f+1,group=b.name);b.keyframe_insert('rotation_euler',frame=f+1,group=b.name);b.keyframe_insert('rotation_quaternion',frame=f+1,group=b.name);b.keyframe_insert('scale',frame=f+1,group=b.name)
            action=rig.animation_data.action
        rig.animation_data.action.name=actor+'_'+anim;rig.animation_data.action.use_fake_user=True
    if actor=='rictus':
        root.animation_data_clear()
        for f in range(8):
            root.rotation_euler.z=math.tau*f/8;root.keyframe_insert('rotation_euler',frame=f+1)
        root.animation_data.action.name='rictus_spin_model';root.animation_data.action.use_fake_user=True;root.animation_data_clear()
        root['M2_spin_actions']='Play rictus_spin on rig with rictus_spin_model on actor root (one rotation, 8 frames)'
    rig.animation_data_clear();pose(actor,root,rig,'idle' if actor=='rictus' else 'hover',0,8)
    bpy.context.preferences.filepaths.save_version=0
    s['M2_contract']='CREA R=90.5097; cell 192; pivot 96,136.32; game applies companion 1.4u and lift movement'
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/characters'/(actor+'.blend')))
    actorpoints={}
    for anim,n in ANIMS[actor].items():
        dirs=DIRS[:1] if anim=='spin' else DIRS;actorpoints[anim]={}
        for row,d in enumerate(dirs):
            entries=[]
            for f in range(n):
                pose(actor,root,rig,anim,f,n);root.rotation_euler.z=base.DIRECTIONS[d]+(math.tau*f/n if anim=='spin' else 0);bpy.context.view_layer.update()
                path=OUT/actor/anim/f'{d}_{f:02}.png'
                entries.append(points(root,actor))
                refresh=sys.argv[sys.argv.index('--refresh')+1].split(',') if '--refresh' in sys.argv else []
                if '--reuse' not in sys.argv or anim in refresh or ('--refresh-slash' in sys.argv and anim=='slash') or not path.exists():base.iso_rig.render_frame(path)
            actorpoints[anim][d]=entries
        dest=DEST/actor;dest.mkdir(parents=True,exist_ok=True)
        for suffix in ('','_n','_e'):
            sheet=Image.new('RGBA',(n*192,len(dirs)*192))
            for row,d in enumerate(dirs):
                for f in range(n):
                    with Image.open(OUT/actor/anim/f'{d}_{f:02}{suffix}.png') as im:sheet.paste(im,(f*192,row*192))
            sheet.save(dest/(anim+suffix+'.png'),optimize=True)
        print('PASS M2',actor,anim,flush=True)
    (OUT/(actor+'_points.json')).write_text(json.dumps(actorpoints));resources(actor)
    if actor=='rictus':
        for direction,view in [('front',Vector((0,-1,0))),('profile',Vector((1,0,0)))]:
            pose(actor,root,rig,'idle',0,8);root.rotation_euler.z=0
            s.camera.rotation_euler=(-view).to_track_quat('-Z','Y').to_euler();s.camera.location=Vector((0,0,1.0))+view*12;s.camera.data.shift_y=0
            base.iso_rig.set_frame((384,384),'CREA');s.camera.data.ortho_scale=384/(base.iso_rig.R*3)
            base.iso_rig.render_frame(OUT/('detail_'+direction+'.png'))

def finalize():
    rp=json.loads((OUT/'rictus_points.json').read_text());mp=json.loads((OUT/'montreur_points.json').read_text())
    manifest['montreur_animations']=mp;manifest['rictus']=rp;manifest['montreur']=mp
    for anim,dirs in rp.items():
        ma='pull' if anim in ('spin','lift','summon','throw','throw_ult') else 'hover';manifest['animations'][anim]={}
        for d,frames in dirs.items():manifest['animations'][anim][d]=[dict(frame=f,rictus=p,montreur=mp[ma][d][f%ANIMS['montreur'][ma]],montreur_animation=ma,montreur_frame=f%ANIMS['montreur'][ma]) for f,p in enumerate(frames)]
    manifest['format']['coordinates']+=' throw_ult impact at zero-based frame 3.'
    manifest['format']['montreur_animation']='pull for spin/lift/summon/throw/throw_ult, hover otherwise; index = Rictus frame modulo companion frame count'
    (DEST/'rictus/strings.json').write_text(json.dumps(manifest,indent=2))
    print('PASS M2 manifest + resources',flush=True)

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    if '--finalize' not in sys.argv:
        for actor in ('rictus',):build(actor)
    finalize()

