"""T2 rigid modular animation. Run with Blender --background --python this_file.
Reuses the approved T1 geometry, CREA renderer and material/pass pipeline.
Seven spatially isolated tiles give complete removable parts, without holdout holes.
Pillow only crops, assembles and checks the Blender renders.
"""
import sys, math, json, time
from pathlib import Path
sys.dont_write_bytecode = True
import bpy
from mathutils import Matrix, Vector
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'art/tools/iso'))
sys.path.insert(0, str(Path(__file__).parent))
import iso_rig
from t1_build import render, visible, label
from PIL import Image

OUT = ROOT/'art/tools/night/t_out/t2'
GAME = ROOT/'game/assets/sprites/characters/tocsin'
PARTS = ['torso', 'head', 'neck_steam', 'arm_l', 'arm_r', 'leg_l', 'leg_r']
ANIMS = {'idle':8, 'walk':8, 'hop_l':6, 'hop_r':6, 'handwalk':8,
         'crawl_l':6, 'crawl_r':6, 'roll':8, 'fall':3,
         'attack':6, 'cast':6, 'cast_ult':6, 'death':6}
DIRS = iso_rig.DIRECTIONS
FPS = {a: (15 if a=='fall' else 12 if a.startswith(('hop','attack','cast')) else 10) for a in ANIMS}

def active(anim):
    keys = list(PARTS)
    if anim.startswith('hop_'): keys.remove('leg_r' if anim.endswith('_l') else 'leg_l')
    if anim=='handwalk' or anim.startswith('crawl_') or anim=='roll':
        keys = [k for k in keys if not k.startswith('leg_')]
    if anim.startswith('crawl_'): keys.remove('arm_r' if anim.endswith('_l') else 'arm_l')
    if anim=='roll': keys = ['torso','head','neck_steam']
    return keys

def pose(anim, i):
    n=ANIMS[anim]; t=i/n; q=i/max(1,n-1); wave=math.sin(t*math.tau)
    for k,ob in mods.items():
        ob.location=rest[k][0]; ob.rotation_euler=(0,0,0)
    root.location=(0,0,0); root.rotation_euler=(0,0,0)
    torso=mods['torso']; head=mods['head']
    if anim=='idle':
        root.location.z=.008*wave
        torso.rotation_euler.y=.014*wave; head.rotation_euler.z=.025*wave
        head.rotation_euler.x=.018*math.cos(t*math.tau)
        for side,sgn in [('l',1),('r',-1)]: mods['arm_'+side].rotation_euler.x=.025*wave*sgn
    elif anim=='walk':
        root.location.z=.018*(1-math.cos(t*math.tau*2))
        torso.rotation_euler.y=.045*wave; torso.rotation_euler.z=.035*math.cos(t*math.tau)
        for side,sgn in [('l',1),('r',-1)]:
            mods['leg_'+side].rotation_euler.x=.36*wave*sgn
            mods['arm_'+side].rotation_euler.x=-.27*wave*sgn
            mods['leg_'+side].location.z+=.06*max(0,wave*sgn)
    elif anim.startswith('hop_'):
        sgn=1 if anim.endswith('_l') else -1
        root.location.z=.13*max(0,math.sin(math.pi*t))-.045*max(0,-wave)
        root.rotation_euler.y=sgn*.10; torso.rotation_euler.x=.10*wave
        mods[anim.replace('hop','leg')].rotation_euler.x=.26*wave
        for k in ['arm_l','arm_r']: mods[k].rotation_euler.y=.16*sgn+.08*wave
    elif anim=='handwalk':
        # Boiler sits between its long claws; no inversion of the head/neck.
        root.location.z=-.42+.025*math.cos(t*math.tau*2)
        root.rotation_euler.x=.28
        for side,sgn in [('l',1),('r',-1)]:
            arm=mods['arm_'+side]; arm.rotation_euler.x=.34*wave*sgn
            arm.rotation_euler.y=-sgn*.18
            arm.location.z+=.07*max(0,wave*sgn)
        torso.rotation_euler.z=.07*wave
        torso.rotation_euler.y=.035*math.cos(t*math.tau)
    elif anim.startswith('crawl_'):
        sgn=1 if anim.endswith('_l') else -1
        root.location.z=-.47+.025*wave; root.rotation_euler.y=sgn*.40
        root.rotation_euler.x=.40
        arm=mods[anim.replace('crawl','arm')]
        arm.rotation_euler.x=.48*wave; arm.rotation_euler.y=-sgn*.38
        torso.rotation_euler.z=.12*wave
        torso.rotation_euler.y=.045*math.cos(t*math.tau)
    elif anim=='roll':
        # Roll about the boiler centre, rather than orbiting the foot origin.
        angle=math.tau*t
        root.rotation_euler.y=angle
        centre=Vector((0,0,.74))
        root.location=Vector((0,0,.39))-root.rotation_euler.to_matrix()@centre
    elif anim=='fall':
        root.location.z=-.43*q; root.rotation_euler.x=.55*q
        torso.rotation_euler.y=.18*math.sin(q*math.pi)
        for side,sgn in [('l',1),('r',-1)]: mods['arm_'+side].rotation_euler.y=-sgn*.30*q
        # Retract the released connecting rods; retained export layers stay in frame.
        for k in ('leg_l','leg_r'): mods[k].rotation_euler.x=1.35*q
    elif anim in ('attack','cast','cast_ult'):
        # Impact index N//2. Deliberate anticipation, impulse, damped recovery.
        pulse=[0,-.28,-.50,1,.30,0][i]
        root.location.y=.035*pulse; torso.rotation_euler.x=.13*pulse
        head.rotation_euler.x=-.08*pulse
        if anim=='cast':
            mods['arm_l'].rotation_euler.x=-.65*pulse
            mods['arm_r'].rotation_euler.x=.20*pulse
        if anim=='cast_ult':
            root.location.z=-.045*pulse
            head.location.z+=.13*max(0,pulse)
            for side,sgn in [('l',1),('r',-1)]: mods['arm_'+side].rotation_euler.y=-sgn*.18*pulse
        # Only the furnace accent surges; no new hue or floating drawn effects.
        for socket,base in emissions: socket.default_value=base*(1+2.5*max(0,pulse))
    elif anim=='death':
        root.location.z=-.30*q; torso.rotation_euler.x=.85*q
        for j,k in enumerate(PARTS):
            if k in ('torso','neck_steam'): continue
            sgn=-1 if k.endswith('_l') else 1
            mods[k].location.x+=sgn*(.14+.035*j)*q
            mods[k].location.y+=(.12 if k=='head' else -.05*j)*q
            mods[k].location.z+=.24*math.sin(q*math.pi)-(.45 if k=='head' else .10)*q
            mods[k].rotation_euler=(.65*q,sgn*.9*q,sgn*.5*q)
    if anim=='handwalk' or anim.startswith('crawl_') or anim=='roll':
        # Keep the supporting claws/boiler on the common world ground plane.
        bpy.context.view_layer.update()
        support=['torso','head'] if anim=='roll' else [k for k in active(anim) if k.startswith('arm_')]
        low=min((ob.matrix_world@Vector(v)).z for k in support
                for ob in mods[k].children_recursive if ob.type=='MESH' for v in ob.bound_box)
        root.location.z-=low

def configure():
    global root,mods,rest,emissions,scene
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/tocsin.blend'))
    scene=bpy.context.scene; root=bpy.data.objects['Tocsin_Root']
    mods={k:bpy.data.objects[k] for k in PARTS}
    rest={k:(ob.location.copy(),ob.rotation_euler.copy()) for k,ob in mods.items()}
    emissions=[]
    for mat in bpy.data.materials:
        if mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type=='BSDF_PRINCIPLED':
                    socket=node.inputs.get('Emission Strength')
                    if socket and socket.default_value>0: emissions.append((socket,socket.default_value))
    for ob in [root,*root.children_recursive]: ob.animation_data_clear()
    scene.eevee.taa_render_samples=8
    # Directional cold fill gives identical exposure in every isolated tile.
    fill=bpy.data.objects.get('Fill_froid')
    if fill:
        fill.data.type='SUN'; fill.data.energy=.32; fill.data.angle=.35
    scene.render.threads_mode='FIXED'; scene.render.threads=8
    scene.render.image_settings.compression=25
    OUT.mkdir(parents=True,exist_ok=True)

def save_rig():
    # Native, editable rigid-part tracks with named timeline ranges.
    frame=1; clips={}
    objects=[root,*mods.values()]
    for anim,n in ANIMS.items():
        start=frame
        for i in range(n):
            pose(anim,i)
            for ob in objects:
                ob.keyframe_insert('location',frame=frame,group=anim)
                ob.keyframe_insert('rotation_euler',frame=frame,group=anim)
            frame+=1
        scene.timeline_markers.new(anim,frame=start)
        clips[anim]={'start':start,'end':frame-1,'frames':n,'fps':FPS[anim],
                     'layers':active(anim),'impact_frame':n//2 if anim=='attack' else None}
    scene.frame_start=1; scene.frame_end=frame-1; scene.render.fps=12
    scene['t2_clips']=json.dumps(clips)
    scene['rig_type']='Rigid modular socket rig: seven keyed roots, Z direction on Tocsin_Root'
    scene['layer_render']='Independent complete modules; same camera/pivot; no holdout cutouts'
    scene.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/characters/tocsin_t2.blend'))
    for ob in objects: ob.animation_data_clear()
    (OUT/'clips.json').write_text(json.dumps(clips,indent=2))

def render_tiles(anim,direction,index):
    pose(anim,index)
    root.rotation_euler.z=DIRS[direction]
    if anim=='roll':
        # The boiler-centre compensation must rotate with the chosen direction.
        root.location=Matrix.Rotation(DIRS[direction],3,'Z')@root.location
    for k,ob in mods.items(): visible(ob,k in active(anim))
    bpy.context.view_layer.update()
    originals={k:ob.matrix_world.copy() for k,ob in mods.items()}
    # Rotate/pose while parented, then spatially isolate the complete modules.
    for j,(k,ob) in enumerate(mods.items()):
        ob.parent=None
        ob.matrix_world=Matrix.Translation(((j-3)*192/iso_rig.R,0,0))@originals[k]
    bpy.context.view_layer.update()
    iso_rig.set_frame((1344,192),'CREA')
    scene.camera.data.shift_y=.21/7
    path=OUT/'_tiles.png'
    original=iso_rig.common.configure_passes
    def passes(p):
        original(p)
        for node in scene.compositing_node_group.nodes:
            if node.bl_idname=='CompositorNodeSetAlpha': node.inputs['Type'].default_value='Replace Alpha'
    iso_rig.common.configure_passes=passes
    try: iso_rig.render_frame(path,passes=True)
    finally: iso_rig.common.configure_passes=original
    folder=OUT/anim/direction; folder.mkdir(parents=True,exist_ok=True)
    for suffix in ('','_n','_e'):
        p=path.with_name('_tiles'+suffix+'.png')
        if not p.exists(): continue
        with Image.open(p) as im:
            for j,k in enumerate(PARTS):
                if k not in active(anim): continue
                tile=im.crop((j*192,0,(j+1)*192,192))
                if suffix=='_e' and max(c.getextrema()[1] for c in tile.split()[:3])<=1: continue
                tile.save(folder/f'{k}_{index:02d}{suffix}.png',compress_level=6)
        p.unlink()
    for k,ob in mods.items():
        ob.parent=root
        ob.matrix_world=originals[k]
    for socket,base in emissions: socket.default_value=base

def order_table():
    result={}
    for direction,angle in DIRS.items():
        pose('idle',0); root.rotation_euler.z=angle
        bpy.context.view_layer.update()
        axis=scene.camera.matrix_world.to_3x3().col[2]
        depths={k:float(ob.matrix_world.translation.dot(axis)) for k,ob in mods.items()}
        result[direction]=sorted(PARTS,key=lambda k:depths[k])
    data={'directions':list(DIRS),'cell':192,'pivot_px':[96,136.32],
          'order':'back_to_front','layers':PARTS,'orders':result,
          'neck_steam':'visible only without head','animations':{a:active(a) for a in ANIMS},
          'rendering':'complete isolated modules; camera-depth ordering from socket roots'}
    (OUT/'layers_order.json').write_text(json.dumps(data,indent=2))
    (OUT.parent/'layers_order.json').write_text(json.dumps(data,indent=2))
    return result

def resource(path,layer=None,emission=False):
    lines=[]; subs=[]; animations=[]; ext=0; sub=0
    for anim,n in ANIMS.items():
        if layer and layer not in active(anim): continue
        stem=anim if layer is None else f'layers/{layer}/{anim}'
        suffix='_e' if emission else ''
        if not (GAME/(stem+suffix+'.png')).exists(): continue
        ext+=1; eid=str(ext)
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/tocsin/{stem}{suffix}.png" id="{eid}"]')
        sub+=1; canvas=f'c{sub}'
        subs.append(f'[sub_resource type="CanvasTexture" id="{canvas}"]\ndiffuse_texture = ExtResource("{eid}")')
        if not emission:
            ext+=1
            lines.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/tocsin/{stem}_n.png" id="{ext}"]')
            subs[-1]+=f'\nnormal_texture = ExtResource("{ext}")'
        for row,d in enumerate(DIRS):
            frames=[]
            for i in range(n):
                sub+=1; sid=f'a{sub}'
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = SubResource("{canvas}")\nregion = Rect2({192*i}, {192*row}, 192, 192)')
                frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
            loop=anim not in ('fall','attack','cast','cast_ult','death')
            animations.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(loop).lower()+', "name": &"'+anim+'_'+d+'", "speed": '+str(float(FPS[anim]))+'}')
    if not animations: return
    path.write_text(f'[gd_resource type="SpriteFrames" load_steps={ext+sub+1} format=3]\n\n'+'\n\n'.join(lines+subs)+'\n\n[resource]\nanimations = [\n'+',\n'.join(animations)+'\n]\n')

def assemble(orders):
    GAME.mkdir(parents=True,exist_ok=True)
    missing_e=[]; raw_bytes=0; content_bytes=0; bounds=[]
    for anim,n in ANIMS.items():
        sheets={(k,s):Image.new('RGBA',(n*192,1536)) for k in active(anim) for s in ('','_n','_e')}
        full={s:Image.new('RGBA',(n*192,1536)) for s in ('','_n','_e')}
        for row,d in enumerate(DIRS):
            for i in range(n):
                for k in orders[d]:
                    if k not in active(anim): continue
                    for s in ('','_n','_e'):
                        p=OUT/anim/d/f'{k}_{i:02d}{s}.png'
                        if not p.exists():
                            assert s=='_e',str(p)
                            continue
                        with Image.open(p) as im:
                            tile=im.convert('RGBA')
                            sheets[k,s].paste(tile,(i*192,row*192))
                            if k!='neck_steam': full[s].alpha_composite(tile,(i*192,row*192))
                            if s=='':
                                box=tile.getchannel('A').getbbox()
                                assert box,str(p)
                                bounds.append((str(p.relative_to(OUT)),box))
                                assert box[0]>=3 and box[1]>=3 and box[2]<=189 and box[3]<=189, str(p)+' clipped '+str(box)
                                raw_bytes+=192*192*4*3
                                content_bytes+=(box[2]-box[0]+12)*(box[3]-box[1]+12)*4*3
        for (k,s),im in sheets.items():
            folder=GAME/'layers'/k; folder.mkdir(parents=True,exist_ok=True)
            if s=='_e' and max(c.getextrema()[1] for c in im.split()[:3])<=1:
                missing_e.append(f'layers/{k}/{anim}_e.png'); continue
            im.save(folder/(anim+s+'.png'),optimize=True,compress_level=9)
        for s,im in full.items(): im.save(GAME/(anim+s+'.png'),optimize=True,compress_level=9)
        print('T2 ATLAS '+anim,flush=True)
    resource(GAME/'tocsin.tres'); resource(GAME/'tocsin_emission.tres',emission=True)
    for k in PARTS:
        resource(GAME/f'tocsin_{k}.tres',k)
        resource(GAME/f'tocsin_{k}_emission.tres',k,True)
    (GAME/'layers_order.json').write_text((OUT/'layers_order.json').read_text())
    manifest={'result':'PASS','animations':ANIMS,'directions':list(DIRS),'cell':192,
              'pivot_px':[96,136.32],'impact_frame':{'attack':3},
              'omitted_black_emissions':missing_e,'raw_rgba_triplets_MiB':round(raw_bytes/2**20,2),
              'cropped_rgba_estimate_MiB':round(content_bytes/2**20,2),
              'note':'Fixed 192 cells retained by contract; T5 can crop atlases using shared diffuse/pass bounds.',
              'bounds':bounds}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    # Same embedded-resource audit as m3_finish.py; no .gd/.tscn files.
    paths=sorted(GAME.glob('*.tres'))
    source='extends SceneTree\nfunc _initialize() -> void:\n    var failed := 0\n    var count := 0\n'
    for p in paths:
        rel='res://'+p.relative_to(ROOT/'game').as_posix()
        source+='    if not ResourceLoader.load('+json.dumps(rel)+') is SpriteFrames:\n        failed += 1\n    count += 1\n'
    source+='    print("T2_RESOURCES: ", count, " loaded; errors=", failed)\n    quit(0 if failed == 0 else 1)\n'
    (OUT/'verify_resources.tres').write_text('[gd_resource type="GDScript" format=3]\n\n[resource]\nscript/source = '+json.dumps(source)+'\n')

def contact():
    board=Image.new('RGBA',(8*192,4*192),(24,27,29,255))
    samples=[('idle',0),('walk',2),('hop_l',3),('hop_r',3),('handwalk',2),('crawl_l',2),('crawl_r',2),('roll',2),('fall',2),('attack',3),('cast',3),('cast_ult',3),('death',4)]
    for j,(a,i) in enumerate(samples):
        with Image.open(GAME/(a+'.png')) as im: board.alpha_composite(im.crop((i*192,2*192,(i+1)*192,3*192)),((j%8)*192,(j//8)*192))
    for column,suffix in [(5,'_n'),(6,'_e')]:
        with Image.open(GAME/('attack'+suffix+'.png')) as im:
            board.alpha_composite(im.crop((576,384,768,576)),(column*192,192))
    ash=ROOT/'art/tools/night/t_out/scale_ash_lord.png'
    if ash.exists():
        with Image.open(ash) as im: board.alpha_composite(im.crop((96,136,288,328)),(1344,192))
    for j,k in enumerate(PARTS):
        with Image.open(GAME/'layers'/k/'idle.png') as im: board.alpha_composite(im.crop((0,384,192,576)),(j*192,384))
    # One final contact also includes the approved references; no separate image reads.
    refs=[ROOT/'art/tools/characters/_cd_tocsin.png',ROOT/'art/tools/iso/_c4_contact.png',ROOT/'art/tools/characters/_m2_contact.png',ROOT/'art/tools/iso/_c1_contact.png']
    for j,p in enumerate(refs):
        if p.exists():
            with Image.open(p) as im:
                thumb=im.convert('RGBA'); thumb.thumbnail((384,192))
                board.alpha_composite(thumb,(j*384,576))
    # All typography is rendered in Blender, never drawn with Pillow.
    for ob in scene.objects:
        if ob.type in ('MESH','FONT','CURVE'): ob.hide_render=True
    ink=bpy.data.materials.new('T2 contact typography'); ink.use_nodes=True
    shader=ink.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(.65,.69,.68,1)
    shader.inputs['Emission Color'].default_value=(.65,.69,.68,1)
    shader.inputs['Emission Strength'].default_value=1
    captions=[[a+':'+str(i) for a,i in samples[:8]],
              [a+':'+str(i) for a,i in samples[8:]]+['normal','emission','ash_lord'],PARTS,
              ['CD Tocsin','','Ardent CREA','','Rictus','','Terrain','']]
    for row,names in enumerate(captions):
        texts=[label(name,(j*192-672)/iso_rig.R,-.055,.12,ink) for j,name in enumerate(names) if name]
        strip=render('t2_contact_labels_'+str(row),(1536,24),0,passes=False)
        with Image.open(strip) as im: board.alpha_composite(im,(0,row*192+168))
        for ob in texts: ob.hide_render=True
    board.save(ROOT/'art/tools/night/_t2_contact.png',optimize=True,compress_level=9)

def main():
    configure()
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if 'contact' in args:
        contact(); return
    if 'assemble' in args:
        orders=json.loads((OUT/'layers_order.json').read_text())['orders']
        assemble(orders); contact(); return
    save_rig(); orders=order_table(); start=time.time(); count=0
    for anim,n in ANIMS.items():
        if 'force_roll' in args and anim!='roll': continue
        for d in DIRS:
            for i in range(n):
                # Checkpoint resumes completed triplets, including intentional black _e omission.
                done=OUT/anim/d/f'{i:02d}.done'
                if done.exists() and 'force_roll' not in args: continue
                render_tiles(anim,d,i); done.write_text('PASS')
                count+=1
                if 'trial' in args:
                    print(f'T2 TRIAL PASS seconds={time.time()-start:.1f}',flush=True); return
            print(f'T2 RENDER {anim}/{d} elapsed={time.time()-start:.0f}s',flush=True)
    assemble(orders); contact()
    print(f'T2 PASS frames={sum(ANIMS.values())*8} elapsed={time.time()-start:.0f}s',flush=True)

if __name__=='__main__': main()
