"""T4: detached foundry parts, bell detonation, museum spell emblems, HUD busts.
Blender --background --python this_file [-- parts|blast|ui|finish|inspect].
Reuses T1 geometry, T2 configuration and CREA pass renderer. Pillow assembles only.
Each rendered tile is a resume checkpoint. Existing body resources stay untouched.
"""
import sys, math, json, random, re, hashlib
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
import t2_build as base
import t1_build as t1
import bpy
from mathutils import Vector, Matrix
from PIL import Image

OUT = ROOT/'art/tools/night/t_out/t4'
GAME = base.GAME
ICONS = ROOT/'game/assets/sprites/icons/spells'
DIRS = base.DIRS
ANIMS = {'arm_fly':4, 'arm_clamp':3, 'arm_ground':1,
         'leg_fly':4, 'leg_ground':1, 'head_fly':6}
SPELLS = ['tocsin_rivets_rougis','tocsin_bras_grappins','tocsin_coups_de_botte','tocsin_tete_cloche']
SUFFIXES = ('','_n','_e')
random.seed(404)


def setup():
    global scene, root, mods, cd, common
    base.OUT = OUT; base.configure()
    scene,root,mods = base.scene,base.root,base.mods
    cd=t1.cd; common=base.iso_rig.common
    ember=next(m for m in bpy.data.materials if m.name=='Single accent / furnace orange')
    # Residual furnace heat in the quick-release sockets remains readable on pickups.
    cd.cyl('T4 severed shoulder hot seal',(-.083,0,0),(-.091,0,0),.048,ember,mods['arm_l'],vertices=24)
    cd.cyl('T4 severed hip hot seal',(0,0,.002),(0,0,.010),.046,ember,mods['leg_l'],vertices=24)
    t1.OUT=OUT
    OUT.mkdir(parents=True,exist_ok=True)
    scene.eevee.taa_render_samples=12
    scene.render.image_settings.compression=30
    for ob in bpy.data.objects:
        if ob.type in ('MESH','CURVE','FONT'): ob.hide_render=True


def reset_parts():
    root.location=(0,0,0); root.rotation_euler=(0,0,0); root.scale=(1,1,1)
    for k,ob in mods.items():
        ob.location=base.rest[k][0]; ob.rotation_euler=base.rest[k][1]; ob.scale=(1,1,1)
        t1.visible(ob,False)
    for ob in mods['arm_l'].children_recursive:
        if 'talon' in ob.name.lower(): ob.matrix_basis=Matrix.Identity(4)
    root.hide_render=False


def bbox(ob):
    bpy.context.view_layer.update()
    return [child.matrix_world@Vector(v) for child in [ob,*ob.children_recursive]
            if child.type=='MESH' and not child.hide_render for v in child.bound_box]


def center(ob,z=0):
    pts=bbox(ob)
    low=Vector(tuple(min(p[j] for p in pts) for j in range(3)))
    high=Vector(tuple(max(p[j] for p in pts) for j in range(3)))
    # XY centre stays on the common ground pivot; lowest point rests at z.
    ob.location-=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z-z))
    bpy.context.view_layer.update()


def part_pose(anim,i,d):
    reset_parts()
    key='arm_l' if anim.startswith('arm') else 'leg_l' if anim.startswith('leg') else 'head'
    ob=mods[key]; t1.visible(ob,True)
    ob.location=(0,0,0); ob.rotation_euler=(0,0,0)
    q=i/(ANIMS[anim] if anim.endswith('_fly') else max(1,ANIMS[anim]-1))
    if anim=='arm_fly':
        ob.rotation_euler=(math.pi/2, .12*math.sin(q*math.tau), .06*math.sin(q*math.tau))
        center(ob,.22+.035*math.sin(q*math.tau))
    elif anim=='arm_clamp':
        ob.rotation_euler=(.18-.18*q,0,0)
        center(ob,.10*(1-q))
        # Rotate real talons about their individual wrist hinges, closing inwards.
        talons=[child for child in ob.children_recursive if 'talon' in child.name.lower()]
        for j,child in enumerate(talons):
            a=math.tau*j/3; pivot=Vector((-.22+math.cos(a)*.05,-.08+math.sin(a)*.05,-.44))
            axis=Vector((-math.sin(a),math.cos(a),0))
            child.matrix_basis=Matrix.Translation(pivot)@Matrix.Rotation(.32-.52*q,4,axis)@Matrix.Translation(-pivot)
        center(ob,0)
        steam=mods['neck_steam']; steam.location=(0,.015,.12)
        steam.rotation_euler=(0,0,.2*i); steam.scale=(.55,.55,.6+.1*i)
        t1.visible(steam,True)
    elif anim=='arm_ground':
        ob.rotation_euler=(math.pi/2,.18,-.20); center(ob,.025)
    elif anim=='leg_fly':
        ob.rotation_euler=(math.pi/2,.08*math.sin(q*math.tau),0)
        center(ob,.20+.025*math.sin(q*math.tau))
    elif anim=='leg_ground':
        ob.rotation_euler=(-math.pi/2,.25,.24); center(ob,.025)
    else:
        ob.rotation_euler=(.26*math.sin(q*math.tau),.18*math.cos(q*math.tau),q*math.tau)
        center(ob,.26+.08*math.sin(q*math.pi))
    root.rotation_euler.z=DIRS[d]
    bpy.context.view_layer.update()
    return ob


def tile(name,rig='CREA',shift=.21,size=192,scale=None):
    scene['iso_rig']=rig
    return t1.render(name,size,shift,passes=True,scale=scale)


def parts():
    for anim,n in ANIMS.items():
        for d in DIRS:
            for i in range(n):
                path=OUT/anim/d/f'{i:02d}.png'
                if all(path.with_name(path.stem+s+'.png').exists() for s in ('','_n')) and 'refresh' not in sys.argv: continue
                part_pose(anim,i,d)
                tile(f'{anim}/{d}/{i:02d}')
        assemble(anim,n,list(DIRS))
        print('T4 PART PASS '+anim,flush=True)
    reset_parts(); part_pose('arm_fly',0,'s')
    scene['T4_contract']='CREA 30deg R90.509668, 192px, ground pivot 96/136.32, separate detached parts'
    scene['T4_clips']=json.dumps(ANIMS)
    # Native part tracks, one direction; root Z supplies all eight headings.
    start=1
    for anim,n in ANIMS.items():
        scene.timeline_markers.new(anim,frame=start)
        for i in range(n):
            ob=part_pose(anim,i,'s')
            for module in mods.values():
                for field in ('location','rotation_euler','scale'):
                    module.keyframe_insert(field,frame=start+i,group=anim)
                for child in [module,*module.children_recursive]:
                    child.keyframe_insert('hide_render',frame=start+i,group=anim)
        start+=n
    scene.frame_start=1; scene.frame_end=start-1
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/characters/tocsin_t4.blend'))
    for module in mods.values(): module.animation_data_clear()


def resource(anim,n,dirs,emission=False):
    suffix='_e' if emission else ''
    if not (GAME/(anim+suffix+'.png')).exists(): return
    rel='res://assets/sprites/characters/tocsin/'+anim
    ext=[f'[ext_resource type="Texture2D" path="{rel}{suffix}.png" id="1"]']
    canvas='[sub_resource type="CanvasTexture" id="canvas"]\ndiffuse_texture = ExtResource("1")'
    if not emission:
        ext.append(f'[ext_resource type="Texture2D" path="{rel}_n.png" id="2"]')
        canvas+='\nnormal_texture = ExtResource("2")'
    subs=[canvas]; animations=[]
    for row,d in enumerate(dirs):
        frames=[]
        for i in range(n):
            sid=f'f{row}_{i}'
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = SubResource("canvas")\nregion = Rect2({i*192}, {row*192}, 192, 192)')
            frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
        loop=anim in ('arm_fly','head_fly','leg_fly','arm_ground','leg_ground')
        fps=15 if 'blast' in anim else 10 if anim=='arm_clamp' else 12
        animations.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(loop).lower()+', "name": &"'+anim+'_'+d+'", "speed": '+str(float(fps))+'}')
    path=GAME/('tocsin_'+anim+('_emission' if emission else '')+'.tres')
    path.write_text('[gd_resource type="SpriteFrames" load_steps='+str(len(ext)+len(subs)+1)+' format=3]\n\n'+'\n\n'.join(ext+subs)+'\n\n[resource]\nanimations = [\n'+',\n'.join(animations)+'\n]\n')


def assemble(anim,n,dirs):
    for s in SUFFIXES:
        sheet=Image.new('RGBA',(n*192,len(dirs)*192))
        for row,d in enumerate(dirs):
            for i in range(n):
                path=OUT/anim/d/(f'{i:02d}'+s+'.png')
                if not path.exists() and s=='_e': continue
                with Image.open(path) as im:
                    sheet.paste(im.convert('RGBA'),(i*192,row*192))
        if s=='_e' and max(c.getextrema()[1] for c in sheet.split()[:3])<=1: continue
        sheet.save(GAME/(anim+s+'.png'),optimize=True,compress_level=9)
    resource(anim,n,dirs); resource(anim,n,dirs,True)


def blast():
    setup(); reset_parts()
    iron=next(m for m in bpy.data.materials if m.name=='Pitted black iron')
    bronze=next(m for m in bpy.data.materials if m.name.startswith('Bell bronze weathered'))
    ember=next(m for m in bpy.data.materials if m.name=='Single accent / furnace orange')
    soot=cd.worn('T4 pressure ash','141918','343C37',0,.97)
    soot.surface_render_method='DITHERED'
    soot_bsdf=soot.node_tree.nodes.get('Principled BSDF')
    effect=cd.empty('T4 / shattered bell pressure wave',(0,0,0))
    # Broken cast-bronze sectors, soot ribbons and sharp cinders; no cartoon fireball.
    shards=[]; cinders=[]; ribbons=[]; waves=[]
    for j in range(15):
        a=j*math.tau/15+random.uniform(-.12,.12)
        r=random.uniform(.025,.05)
        vs=[(-r,-r*.5,0),(r,-r*.35,.005),(r*.3,r*.8,.015),(-r*.8,r*.5,-.008)]
        shard=cd.mesh('Bell fracture %02d'%j,vs,[(0,1,2,3)],bronze,effect)
        solid=shard.modifiers.new('Broken casting thickness','SOLIDIFY'); solid.thickness=.012
        bevel=shard.modifiers.new('Worn fracture edge','BEVEL'); bevel.width=.003; bevel.segments=2
        shards.append((shard,a,random.uniform(.55,1.0)))
    for j in range(26):
        a=j*2.399963
        ob=common.rod('Hot rivet splinter %02d'%j,(0,0,0),(.006,0,.028),.005,ember,effect)
        cinders.append((ob,a,random.uniform(.5,1.0)))
    for j in range(17):
        a=j*2.399963+random.uniform(-.15,.15)
        start=random.uniform(.29,.49); length=random.uniform(.10,.24)
        verts=[]
        for k in range(7):
            t=k/6; r=start+t*length
            for sign in (-1,1):
                angle=a+sign*(.006+.018*math.sin(t*math.pi))+.12*t+.02*math.sin(t*13+j)
                verts.append((r*math.cos(angle),r*math.sin(angle),.04+.035*math.sin(t*math.pi+j)))
        ob=cd.mesh('Radial soot scar %02d'%j,verts,[(2*k,2*k+1,2*k+3,2*k+2) for k in range(6)],soot,effect)
        ribbons.append(ob)
    for j in range(3):
        ob=cd.tube('Pressure arc %d'%j,[(math.cos(a)*.7,math.sin(a)*.7,.025) for a in [(.15+j*2.1+k*.026) for k in range(53)]],.007,ember if j==0 else bronze,effect)
        waves.append(ob)
    hot=cd.worn('T4 fleeting furnace flash','7F2A09','E59B53',0,.48)
    hot_bsdf=hot.node_tree.nodes.get('Principled BSDF')
    hot_bsdf.inputs['Emission Color'].default_value=cd.rgb('FF7A1F')
    hot_bsdf.inputs['Emission Strength'].default_value=2
    flash=cd.empty('Pressure flash, torn incandescent facets',(0,0,0),effect)
    for j in range(13):
        a=j*math.tau/13; radius=random.uniform(.09,.20)
        cd.mesh('Incandescent torn pressure sheet %d'%j,
            [(0,0,.05),(radius*math.cos(a),radius*math.sin(a),random.uniform(.08,.25)),
             (.055*math.cos(a+.8),.055*math.sin(a+.8),.06)],[(0,1,2)],hot,flash)
    for rig,anim,d in [('TOP','head_blast_top','top'),('CREA','head_blast','s')]:
        base.iso_rig.create_rig(rig,192,reset=False)
        scene.eevee.taa_render_samples=12
        for i in range(8):
            path=OUT/anim/d/f'{i:02d}.png'
            if all(path.with_name(path.stem+s+'.png').exists() for s in ('','_n')) and 'refresh' not in sys.argv: continue
            q=i/7
            flash.scale=([.35,1,.65,.22,.08,.035,.015,.005][i],)*3
            soot_bsdf.inputs['Alpha'].default_value=[.08,.30,.46,.38,.25,.14,.06,.015][i]
            for ob,a,v in shards:
                r=.04+q*v*.72
                ob.location=(r*math.cos(a),r*math.sin(a),.08+.43*math.sin(q*math.pi)*(1-v*.4))
                ob.rotation_euler=(q*4+a,q*3,q*5+a)
                ob.scale=(1-.50*q,)*3
            for ob,a,v in cinders:
                r=.03+q*v*.83
                ob.location=(r*math.cos(a),r*math.sin(a),.05+.4*math.sin(q*math.pi)*v)
                ob.rotation_euler=(0,q*2,a)
                ob.scale=(max(.06,1-q*.93),)*3
            for ob in ribbons:
                ob.scale=(.18+.82*q,.18+.82*q,.6+.4*math.sin(q*math.pi))
                ob.hide_render=i in (0,7)
            for ob in waves:
                ob.scale=(.15+.9*q,.15+.9*q,1)
                ob.hide_render=i==7
            tile(f'{anim}/{d}/{i:02d}',rig,0 if rig=='TOP' else .10)
        assemble(anim,8,[d])
    scene['T4_effect']='Bell fragments, ballistic cinders, expanding soot and fractured pressure arcs; TOP + CREA'
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/characters/tocsin_t4_blast.blend'))
    print('T4 BLAST PASS TOP + CREA',flush=True)


def studio():
    # Shared museum recipe: warm upper-left softbox, cool rim, neutral dark world.
    for ob in list(scene.objects):
        if ob.type=='LIGHT': bpy.data.objects.remove(ob,do_unlink=True)
    for name,loc,col,power,size in [('T4 warm studio',(-3,-4,5),(1,.76,.53),520,3),
                                  ('T4 cold rim',(3,1,3),(.50,.66,.85),620,2.5),
                                  ('T4 reflection card',(1,-4,1),(.78,.83,.84),100,2)]:
        data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.color=col; data.shape='DISK'; data.size=size
        ob=bpy.data.objects.new(name,data); scene.collection.objects.link(ob); ob.location=loc
        ob.rotation_euler=(Vector((0,0,.5))-ob.location).to_track_quat('-Z','Y').to_euler()
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get('Background'); bg.inputs['Color'].default_value=(.18,.18,.18,1); bg.inputs['Strength'].default_value=.25
    scene.view_settings.view_transform='AgX'; scene.view_settings.look='AgX - Medium High Contrast'
    scene.eevee.taa_render_samples=24
    # Full metallic response in the emblem studio; retain approved worn procedural nodes.
    for mat in bpy.data.materials:
        if mat.use_nodes:
            p=mat.node_tree.nodes.get('Principled BSDF')
            if p and p.inputs['Metallic'].default_value>.55: p.inputs['Metallic'].default_value=1


def ui():
    setup(); reset_parts(); studio()
    camera=scene.camera
    camera.location=(1.1,-7,3.0)
    target=Vector((0,0,.52)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    iron=cd.worn('T4 engraved wet steel','111816','343F39',1,.43)
    cut=cd.worn('T4 engraved recess','060B0A','141A17',.7,.64)
    brass=next(m for m in bpy.data.materials if m.name=='Worn brass rivet heads')
    ember=next(m for m in bpy.data.materials if m.name=='Single accent / furnace orange')
    backing=cd.empty('T4 / engraved foundry backing',(0,0,0))
    disk=cd.cyl('Blackened engraved plate',(0,.22,.52),(0,.27,.52),.53,iron,backing,vertices=96)
    for j in range(32):
        a=j*math.tau/32; r=.39 if j%4==0 else .445
        cd.tube('Foundry index incision %d'%j,[(math.sin(a)*r,.191,.52+math.cos(a)*r),
                 (math.sin(a)*.48,.191,.52+math.cos(a)*.48)],.003,cut,backing)
    for j in range(10):
        x=random.uniform(-.32,.32); z=random.uniform(.23,.80)
        cd.tube('Rain etched scratch %d'%j,[(x,.19,z),(x+.06,.19,z+.035)],.0015,cut,backing)
    for slot,name in enumerate(SPELLS):
        reset_parts(); t1.visible(backing,True)
        extra=cd.empty('T4 / spell emblem '+str(slot),(0,0,0))
        if slot==0:
            # Three forged pectoral rivets, broad peened heads and glowing necks.
            for j in range(3):
                x=(j-1)*.18; z=.47+(j-1)*.08
                cd.cyl('Forged rivet shank',(x,-.015,z-.13),(x,-.015,z+.15),.035,brass,extra,vertices=16)
                cd.cyl('Peened rivet head',(x,-.015,z+.12),(x,-.015,z+.17),.074,brass,extra,vertices=8)
                cd.cyl('Incandescent rivet collar',(x,-.015,z+.075),(x,-.015,z+.105),.04,ember,extra,vertices=16)
        else:
            key={1:'arm_l',2:'leg_l',3:'head'}[slot]
            ob=mods[key]; t1.visible(ob,True); ob.location=(0,0,0)
            ob.rotation_euler=(0,-.25,.10) if slot==1 else (.10,-.35,-.18) if slot==2 else (.08,0,-.18)
            # Largest emblem dimension .74 units, sitting clearly above engraved steel.
            pts=bbox(ob); extent=max(max(p[j] for p in pts)-min(p[j] for p in pts) for j in range(3))
            ob.scale=(.74/extent,)*3; center(ob,.16)
            pts=bbox(ob); ob.location.y-=max(p.y for p in pts)+.025
            if slot==1:
                cd.tube('Orange captive pressure filament',[(-.15,-.23,.40),(-.04,-.25,.36),(.13,-.23,.41)],.009,ember,extra)
            elif slot==2:
                for j in range(3):
                    cd.tube('Boot impact incision %d'%j,[(-.26+j*.17,-.13,.20),(-.31+j*.17,-.13,.11)],.009,ember,extra)
            else:
                # Sharp asymmetrical crack/lightning motif echoes the bent lightning rod.
                cd.tube('Bell pressure fracture',[(-.25,-.12,.68),(-.33,-.12,.77),(-.29,-.12,.86)],.009,ember,extra)
        path=tile('ui/'+name,'CREA',0,256,1.22)
        with Image.open(path) as src:
            src.resize((128,128),Image.Resampling.LANCZOS).save(ICONS/(name+'.png'),optimize=True,compress_level=9)
        # Save the source geometry with the studio for this exact spell.
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/('art/blender/characters/'+name+'.blend')))
        t1.visible(extra,False)
    t1.visible(backing,False)
    # Busts share the character's actual geometry; the second exposes the smoking socket.
    for name,head in [('portrait',True),('portrait_headless',False)]:
        reset_parts()
        for k in ('torso','arm_l','arm_r','head' if head else 'neck_steam'): t1.visible(mods[k],True)
        root.rotation_euler.z=-.16
        camera.location=(.75,-6,3.0); target=Vector((0,0,1.02))
        camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        # Both portraits have identical crop and lighting, with extra boiler heat headless.
        for socket,value in base.emissions: socket.default_value=value*(1 if head else 1.4)
        tile('ui/'+name,'CREA',0,256,1.02)
        for s in SUFFIXES:
            path=OUT/'ui'/(name+s+'.png')
            if path.exists():
                with Image.open(path) as im: im.save(GAME/(name+s+'.png'),optimize=True,compress_level=9)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/characters/tocsin_t4_portraits.blend'))
    print('T4 UI PASS four 128px spells + two 256px portraits',flush=True)


def verify():
    checks=[]; files=[]
    specs=[(a,n,list(DIRS)) for a,n in ANIMS.items()]+[('head_blast',8,['s']),('head_blast_top',8,['top'])]
    for a,n,dirs in specs:
        for s in ('','_n'):
            p=GAME/(a+s+'.png')
            with Image.open(p) as im: assert im.size==(n*192,len(dirs)*192),(p,im.size)
        with Image.open(GAME/(a+'.png')) as diffuse,Image.open(GAME/(a+'_n.png')) as normal:
            for row,d in enumerate(dirs):
                for i in range(n):
                    box=(i*192,row*192,(i+1)*192,(row+1)*192)
                    alpha=diffuse.crop(box).getchannel('A'); bounds=alpha.getbbox()
                    assert bounds and min(bounds[:2])>=3 and max(bounds[2:])<=189,(a,d,i,bounds)
                    # Passes share the exact same coverage (allow 1 unit codec rounding).
                    na=normal.crop(box).getchannel('A')
                    assert alpha.getbbox()==na.getbbox(),(a,d,i,'normal coverage')
                    checks.append([a,d,i,list(bounds)])
        for s in SUFFIXES:
            p=GAME/(a+s+'.png')
            if p.exists(): files.append(str(p.relative_to(ROOT)))
    for name in SPELLS:
        with Image.open(ICONS/(name+'.png')) as im: assert im.size==(128,128)
    for name in ('portrait','portrait_headless'):
        with Image.open(GAME/(name+'.png')) as im: assert im.size==(256,256)
    # Required body actions already delivered by T3: preserve and assert their contract.
    body=(GAME/'tocsin.tres').read_text()
    for anim in ('attack','cast','cast_ult','death'):
        for d in DIRS: assert '"'+anim+'_'+d+'"' in body
    (OUT/'manifest.json').write_text(json.dumps({'result':'PASS','cell':192,'directions':list(DIRS),
        'pivot':[96,136.32],'R':base.iso_rig.R,'animations':dict(ANIMS,head_blast=8,head_blast_top=8),
        'checked_cells':len(checks),'bounds':checks,'files':files,'icons':SPELLS,'portrait_size':256,
        'attack_impact_frame':3,'body_resources':'T3 resources preserved'},indent=2))
    print('T4 VERIFY PASS '+str(len(checks))+' cells; normals; margins; icons; portraits; T3 actions',flush=True)


def contact():
    # All image operations below are crops, resizing and assembly only.
    board=Image.new('RGBA',(1536,1920),(15,20,20,255))
    rows=[('arm_fly',0),('arm_clamp',2),('arm_ground',0),('leg_fly',1),('leg_ground',0),('head_fly',2)]
    for row,(anim,i) in enumerate(rows):
        with Image.open(GAME/(anim+'.png')) as im:
            for col in range(8): board.alpha_composite(im.crop((i*192,col*192,(i+1)*192,(col+1)*192)),(col*192,row*192))
    for row,anim in enumerate(('head_blast_top','head_blast')):
        with Image.open(GAME/(anim+'.png')) as im: board.alpha_composite(im.convert('RGBA'),(0,1152+row*192))
    frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
    ardent=['eclat_de_braise','nova_ardente','cendres','brasier']
    for col,name in enumerate(SPELLS+ardent):
        im=Image.open(ICONS/(name+'.png')).convert('RGBA')
        for size,y in ((128,1548),(64,1684)):
            cell=frame.resize((size,size),Image.Resampling.LANCZOS)
            emblem=im.resize((round(size*.79),round(size*.79)),Image.Resampling.LANCZOS)
            cell.alpha_composite(emblem,((size-emblem.width)//2,(size-emblem.height)//2))
            # Medallion gold lip is on top of the dark engraved emblem.
            cell.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS))
            board.alpha_composite(cell,(col*192+(192-size)//2,y))
    for col,name in enumerate(('portrait','portrait_headless')):
        with Image.open(GAME/(name+'.png')) as im:
            board.alpha_composite(im.convert('RGBA').resize((160,160),Image.Resampling.LANCZOS),(col*192+16,1754))
    # Show actual normal and emission channels beside portraits.
    for col,(anim,s) in enumerate([('head_fly','_n'),('head_fly','_e'),('head_blast','_n'),('head_blast','_e')],2):
        p=GAME/(anim+s+'.png')
        if p.exists():
            with Image.open(p) as im: board.alpha_composite(im.convert('RGBA').crop((384,0,576,192)).resize((160,160)),(col*192+16,1754))
    for col,char in enumerate(('ardent','rictus'),6):
        with Image.open(ROOT/f'game/assets/sprites/characters/{char}/idle.png') as im:
            board.alpha_composite(im.convert('RGBA').crop((0,384,192,576)).resize((160,160)),(col*192+16,1754))
    board.save(ROOT/'art/tools/night/_t4_contact.png',optimize=True,compress_level=9)
    print('T4 CONTACT PASS',flush=True)


def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    mode=args[0] if args else 'all'
    setup()
    if mode=='inspect':
        print('T4 INSPECT '+json.dumps({k:[c.name for c in mods[k].children_recursive][:12] for k in ('arm_l','leg_l','head')}),flush=True)
        return
    if mode in ('all','parts'): parts()
    if mode in ('all','blast'): blast()
    if mode in ('all','ui'): ui()
    if mode in ('all','finish'): verify(); contact()


if __name__=='__main__': main()
