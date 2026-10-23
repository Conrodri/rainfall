"""T3: pressure-driven throws, dislocation, furnace recoil and socket repair.
Reuses the approved T1 model and T2 isolated-module renderer. Pillow only assembles.
Run Blender background --python this_file; checkpoints allow safe resume.
"""
import sys, math, json, time, re
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
import t2_build as base
import bpy
from mathutils import Vector
from PIL import Image
from t1_build import visible, render, label
OUT = ROOT/'art/tools/night/t_out/t3'
GAME = base.GAME
NEW = {'throw_arm_l':4,'throw_arm_r':4,'throw_leg_l':4,'throw_leg_r':4,
       'throw_head':6,'death':6,'attack':6,'cast':6,'cast_ult':6,'neck_steam':6}
ORIGINAL = dict(base.ANIMS)
ALL = dict(ORIGINAL, **NEW)
old_pose, old_active = base.pose, base.active

def active(anim):
    return ['neck_steam'] if anim=='neck_steam' else old_active(anim)

def pose(anim,i):
    firing.scale=(0,0,0)
    for ob in base.mods.values(): ob.scale=(1,1,1)
    for socket,value in base.emissions: socket.default_value=value
    old_pose('idle' if anim.startswith('throw_') or anim=='neck_steam' else anim,i if anim in ORIGINAL else 0)
    n=ALL[anim]; q=i/max(1,n-1)
    torso=base.mods['torso']; steam=base.mods['neck_steam']
    steam.rotation_euler.z=.22*math.sin(i*math.tau/n)
    steam.scale=(1+.12*math.sin(i*2.1),1, .80+.25*math.sin(i*1.3)**2)
    if anim.startswith('throw_'):
        key=anim[len('throw_'):]; part=base.mods[key]
        pulse=([0,-.65,1,.15] if n==4 else [0,-.35,-.75,1,.35,0])[i]
        base.root.location=(0,.04*pulse,-.025*max(0,pulse))
        torso.rotation_euler.x=.18*pulse
        torso.rotation_euler.z=(.09 if key.endswith('_l') else -.09)*pulse
        if key.startswith('arm_'):
            part.rotation_euler.x=.55 if i==1 else -.55 if i==2 else 0
            part.rotation_euler.y=(.2 if key.endswith('_l') else -.2)*(i==1)
            # Socket becomes empty on frame 2 (zero based), matching the fiche.
            if i>=2: part.scale=(0,0,0)
        elif key.startswith('leg_'):
            side=1 if key.endswith('_l') else -1
            base.root.rotation_euler.y=-side*.09*max(0,pulse)
            base.mods['arm_'+key[-1]].rotation_euler.x=-.42 if i==1 else -.18
            part.rotation_euler.x=.45 if i==1 else 0
            if i>=2: part.scale=(0,0,0)
        else:
            part.location.z+=.035 if i==1 else -.025 if i==2 else 0
            if i>=3: part.scale=(0,0,0)
            for k in ('arm_l','arm_r'): base.mods[k].rotation_euler.x=.12*pulse
        for socket,value in base.emissions: socket.default_value=value*(1+1.2*max(0,pulse))
    elif anim=='death':
        # Boiler implodes; heavy pieces settle independently on the same ground.
        base.root.location=(0,0,0)
        torso.rotation_euler=(1.25*q,.16*q,0)
        torso.location.z=base.rest['torso'][0].z-.30*q
        for j,k in enumerate(('head','arm_l','arm_r','leg_l','leg_r')):
            ob=base.mods[k]; side=-1 if k.endswith('_l') else 1
            ob.location.x=base.rest[k][0].x+side*(.14+.015*j)*q
            ob.location.y=base.rest[k][0].y+(.12 if k=='head' else -.12)*q
            ob.rotation_euler=(1.15*q,side*.45*q,side*.35*q)
        if q>0:
            bpy.context.view_layer.update()
            for k in ('torso','head','arm_l','arm_r','leg_l','leg_r'):
                ob=base.mods[k]
                low=min((child.matrix_world@Vector(v)).z for child in ob.children_recursive
                        if child.type=='MESH' for v in child.bound_box)
                target=.10*math.sin(q*math.pi) if k!='torso' else 0
                ob.location.z+=(target-low)*q
        steam.location=torso.location+Vector((0,0,.30))
        steam.scale=(1,1,1-.7*q)
        for socket,value in base.emissions: socket.default_value=value*(1-.85*q)
    elif anim=='attack':
        # Pectoral firing, usable with all five detachable parts absent.
        pulse=[0,-.28,-.50,1,.30,0][i]
        torso.rotation_euler.x=.16*pulse
        if i in (3,4):
            firing.scale=(1,1,1)
            firing.location=(0,-.32-.19*(i-3),.035)
    elif anim=='cast_ult':
        if i>=3: base.mods['head'].scale=(0,0,0)


def setup():
    global firing
    base.OUT=OUT; base.ANIMS=ALL; base.active=active; base.pose=pose
    base.FPS.update({a:12 for a in NEW}); base.FPS['death']=10
    base.configure()
    common=base.iso_rig.common
    firing=common.empty('T3 / fired pectoral rivet',(0,-.32,.035),base.mods['torso'])
    brass=next(m for m in bpy.data.materials if m.name=='Worn brass rivet heads')
    ember=next(m for m in bpy.data.materials if m.name=='Single accent / furnace orange')
    common.rod('T3 fired forged rivet',(0,.035,0),(0,-.025,0),.012,brass,firing)
    common.box('T3 incandescent rivet head',(0,-.03,0),(.029,.014,.029),ember,firing,.004)
    firing.scale=(0,0,0)
    # Native flame remains the only chromatic emission. Grey soot ribbons stay neutral.
    OUT.mkdir(parents=True,exist_ok=True)


def save_source():
    frame=1; clips={}; objects=[base.root,*base.mods.values(),firing]
    for anim,n in NEW.items():
        start=frame
        for i in range(n):
            pose(anim,i)
            for ob in objects:
                for prop in ('location','rotation_euler','scale'): ob.keyframe_insert(prop,frame=frame,group=anim)
            frame+=1
        base.scene.timeline_markers.new(anim,frame=start)
        clips[anim]={'start':start,'end':frame-1,'frames':n,'fps':base.FPS[anim],
                     'layers':active(anim),'release_frame':2 if anim.startswith(('throw_arm','throw_leg')) else 3 if anim=='throw_head' else None,
                     'impact_frame':n//2 if anim=='attack' else None}
    base.scene.frame_start=1; base.scene.frame_end=frame-1
    base.scene['T3_clips']=json.dumps(clips)
    base.scene['T3_design']='Heavy socket recoil; pressure-ejected bell; grounded dislocation; furnace orange only'
    base.scene.frame_set(1); bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/characters/tocsin_t3.blend'))
    for ob in objects: ob.animation_data_clear()
    (OUT/'clips.json').write_text(json.dumps(clips,indent=2))


def assemble():
    orders=json.loads((GAME/'layers_order.json').read_text())['orders']
    bounds=[]; absent=[]; omitted=[]
    for anim,n in NEW.items():
        sheets={(k,s):Image.new('RGBA',(n*192,1536)) for k in active(anim) for s in ('','_n','_e')}
        full={s:Image.new('RGBA',(n*192,1536)) for s in ('','_n','_e')}
        for row,d in enumerate(base.DIRS):
            for i in range(n):
                for k in orders[d]:
                    if k not in active(anim): continue
                    for suffix in ('','_n','_e'):
                        path=OUT/anim/d/f'{k}_{i:02d}{suffix}.png'
                        if not path.exists():
                            assert suffix=='_e',str(path)
                            continue
                        with Image.open(path) as im: tile=im.convert('RGBA')
                        sheets[k,suffix].paste(tile,(i*192,row*192))
                        show=k!='neck_steam' or anim=='neck_steam' or (anim in ('throw_head','cast_ult') and i>=3)
                        if show: full[suffix].alpha_composite(tile,(i*192,row*192))
                        if suffix=='':
                            box=tile.getchannel('A').getbbox()
                            if box:
                                assert box[0]>=3 and box[1]>=3 and box[2]<=189 and box[3]<=189,f'{path}: clipped {box}'
                                bounds.append((str(path.relative_to(OUT)),box))
                            else:
                                assert anim.startswith('throw_') and k==anim[6:] and i>=(3 if k=='head' else 2) or anim=='cast_ult' and k=='head' and i>=3,str(path)
                                absent.append(str(path.relative_to(OUT)))
        for (k,s),im in sheets.items():
            path=GAME/'layers'/k/(anim+s+'.png'); path.parent.mkdir(parents=True,exist_ok=True)
            if s=='_e' and max(c.getextrema()[1] for c in im.split()[:3])<=1:
                omitted.append(str(path.relative_to(GAME))); continue
            im.save(path,optimize=True,compress_level=9)
        for s,im in full.items():
            if s=='_e' and max(c.getextrema()[1] for c in im.split()[:3])<=1:
                omitted.append(anim+s+'.png'); continue
            im.save(GAME/(anim+s+'.png'),optimize=True,compress_level=9)
    # Existing resources gain required clips; all previous clips and texture paths stay.
    base.resource(GAME/'tocsin.tres'); base.resource(GAME/'tocsin_emission.tres',emission=True)
    for k in base.PARTS:
        base.resource(GAME/f'tocsin_{k}.tres',k)
        base.resource(GAME/f'tocsin_{k}_emission.tres',k,True)
    # New action clips must never loop.
    for path in GAME.glob('*.tres'):
        src=path.read_text()
        src=re.sub(r'"loop": true, "name": &"(throw_[^"]+)"',r'"loop": false, "name": &"\1"',src)
        path.write_text(src)
    data=json.loads((GAME/'layers_order.json').read_text())
    data['animations'].update({a:active(a) for a in NEW})
    (GAME/'layers_order.json').write_text(json.dumps(data,indent=2))
    (OUT/'manifest.json').write_text(json.dumps({'result':'PASS','animations':NEW,'cell':192,
        'directions':list(base.DIRS),'pivot_px':[96,136.32],'attack_impact':3,
        'bounds':bounds,'intentionally_absent':absent,'omitted_black_emissions':omitted},indent=2))
    print(f'T3 ASSEMBLE PASS cells={len(bounds)} absent={len(absent)}',flush=True)


def regen():
    for ob in base.scene.objects:
        if ob.type in ('MESH','CURVE','FONT'): ob.hide_render=True
    common=base.iso_rig.common
    root=common.empty('T3 / incoming repair rivets')
    steam=base.mods['neck_steam']
    steam.parent=root; steam.location=(0,0,0); steam.rotation_euler=(0,0,0)
    visible(steam,True)
    brass=next((m for m in bpy.data.materials if 'laiton' in m.name.lower() or 'brass' in m.name.lower()),None)
    if brass is None: brass=common.material('T3 patinated repair brass',(.29,.23,.14),.7,.55,grain=True)
    ember=common.material('T3 repair hot rivet tip',(.6,.13,.012),.4,.5,emission=2)
    pieces=[]
    for j in range(11):
        angle=j*math.tau/11; z=(j%3-1)*.07
        ob=common.empty('Repair rivet socket '+str(j),parent=root)
        common.rod('Repair shaft '+str(j),(0,0,-.022),(0,0,.023),.009,brass,ob)
        common.box('Repair forged head '+str(j),(0,0,.024),(.035,.029,.014),brass,ob,.005)
        common.box('Repair heated point '+str(j),(0,0,-.022),(.011,.011,.009),ember,ob,.002)
        pieces.append((ob,angle,z))
    folder=OUT/'regen_rivets'; folder.mkdir(exist_ok=True)
    tiles={s:[] for s in ('','_n','_e')}
    import t1_build
    saved=t1_build.OUT; t1_build.OUT=folder
    try:
        for i in range(6):
            base.scene.frame_set(i+1)
            q=i/5
            steam.location.z=.12*q
            steam.scale=(.6+.8*q,.6+.8*q,.35+.55*math.sin(q*math.pi))
            for prop in ('location','scale'): steam.keyframe_insert(prop,frame=i+1)
            for j,(ob,angle,z) in enumerate(pieces):
                radius=.43*(1-q)**1.3+.025
                ob.location=(radius*math.cos(angle+.3*q),radius*math.sin(angle+.3*q),z*(1-q)+.08*math.sin(q*math.pi))
                ob.rotation_euler=(angle+q*2,.9,angle)
                ob.scale=(1,1,1) if i<5 or j%3==0 else (0,0,0)
                for prop in ('location','rotation_euler','scale'): ob.keyframe_insert(prop,frame=i+1)
            path=render(f'{i:02d}',192,0,passes=True)
            for s in tiles:
                with Image.open(path.with_name(path.stem+s+'.png')) as im: tiles[s].append(im.convert('RGBA'))
        for s,frames in tiles.items():
            sheet=Image.new('RGBA',(1152,192))
            for i,im in enumerate(frames): sheet.paste(im,(i*192,0))
            sheet.save(GAME/('regen_rivets'+s+'.png'),optimize=True,compress_level=9)
    finally: t1_build.OUT=saved
    base.scene.frame_start=1; base.scene.frame_end=6; base.scene.render.fps=15
    base.scene['T3_VFX']='11 forged brass rivets, hot orange tips, expanding soot vapour; socket-centred 192px'
    base.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/characters/tocsin_t3_regen.blend'))
    visible(root,False)
    # 1-direction VFX with diffuse+normal CanvasTexture, separate emission resource.
    for suffix in ('','_e'):
        ext=f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/tocsin/regen_rivets{suffix}.png" id="1"]\n'
        if not suffix: ext+='[ext_resource type="Texture2D" path="res://assets/sprites/characters/tocsin/regen_rivets_n.png" id="2"]\n'
        subs='[sub_resource type="CanvasTexture" id="c"]\ndiffuse_texture = ExtResource("1")\n'
        if not suffix: subs+='normal_texture = ExtResource("2")\n'
        frames=[]
        for i in range(6):
            subs+=f'\n[sub_resource type="AtlasTexture" id="f{i}"]\natlas = SubResource("c")\nregion = Rect2({i*192}, 0, 192, 192)\n'
            frames.append('{"duration": 1.0, "texture": SubResource("f'+str(i)+'")}')
        (GAME/('regen_rivets'+('_emission' if suffix else '')+'.tres')).write_text('[gd_resource type="SpriteFrames" format=3]\n'+ext+'\n'+subs+'\n[resource]\nanimations = [{"frames": ['+', '.join(frames)+'], "loop": false, "name": &"regen_rivets", "speed": 15.0}]\n')
    print('T3 REGEN PASS',flush=True)


def contact():
    # One and only final visual review board, including approved style references.
    rows=[('throw_arm_l','s'),('throw_arm_r','se'),('throw_leg_l','s'),('throw_leg_r','se'),
          ('throw_head','s'),('death','s'),('attack','s'),('neck_steam','s'),('regen_rivets',None)]
    board=Image.new('RGBA',(1536,1920),(24,27,29,255))
    captions=[]
    for row,(anim,d) in enumerate(rows):
        n=6 if anim=='regen_rivets' else NEW[anim]; y=list(base.DIRS).index(d)*192 if d else 0
        with Image.open(GAME/(anim+'.png')) as im:
            for i in range(n): board.alpha_composite(im.crop((i*192,y,(i+1)*192,y+192)),(i*192,row*192))
        for col,s in [(6,'_n'),(7,'_e')]:
            p=GAME/(anim+s+'.png')
            if p.exists():
                i=n//2
                with Image.open(p) as im: board.alpha_composite(im.crop((i*192,y,(i+1)*192,y+192)),(col*192,row*192))
        captions.append(anim+'  '+(d or '1 dir')+'   |   normal / emission')
    refs=[ROOT/'art/tools/characters/_cd_tocsin.png',ROOT/'art/tools/iso/_c4_contact.png',ROOT/'art/tools/characters/_m2_contact.png',ROOT/'art/tools/iso/_c1_contact.png']
    for j,p in enumerate(refs):
        if p.exists():
            with Image.open(p) as im:
                thumb=im.convert('RGBA'); thumb.thumbnail((384,192)); board.alpha_composite(thumb,(j*384,1728))
    # Typography is geometry rendered by Blender, never Pillow drawing.
    for ob in base.scene.objects:
        if ob.type in ('MESH','CURVE','FONT'): ob.hide_render=True
    mat=base.iso_rig.common.material('T3 contact text',(.65,.69,.68),emission=1)
    for row,text in enumerate(captions):
        ob=label(text,0,0,.12,mat)
        ob.location=(0,0,0); ob.rotation_euler=base.scene.camera.rotation_euler
        ob.data.align_x='CENTER'
        p=render('t3_caption_'+str(row),(1536,24),0,passes=False)
        with Image.open(p) as im: board.alpha_composite(im.convert('RGBA'),(0,row*192))
        ob.hide_render=True
    board.save(ROOT/'art/tools/night/_t3_contact.png',optimize=True,compress_level=9)


def main():
    setup(); args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if 'vfx' in args:
        regen(); contact(); return
    if 'finish' not in args:
        save_source(); start=time.time()
        for anim,n in NEW.items():
            for d in base.DIRS:
                for i in range(n):
                    done=OUT/anim/d/f'{i:02d}.done'
                    if done.exists(): continue
                    for k in active(anim):
                        stale=OUT/anim/d/f'{k}_{i:02d}_e.png'
                        if stale.exists(): stale.unlink()
                    base.render_tiles(anim,d,i); done.write_text('PASS')
                print(f'T3 RENDER {anim}/{d} seconds={time.time()-start:.0f}',flush=True)
    assemble(); regen(); contact()
    print('T3 BUILD PASS',flush=True)

if __name__=='__main__': main()
