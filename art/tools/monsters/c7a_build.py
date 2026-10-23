"""C7a: new sluice guardian; background Blender, legacy grid/pivot, CREA 30deg.
Reuses official worn shaders, boss pass renderer and existing water geometry.
Run Blender --background --python this.py. Temporary frames are removed on success.
"""
import sys, math, json, re, tempfile, hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/bosses'),str(ROOT/'art/tools/iso')]
sys.path[:0]=[str(ROOT/'art/tools/iso/_deps'),str(Path.home()/'AppData/Local/RainfallIsoDeps')]
import bpy
from mathutils import Vector
from PIL import Image
import boss_common as c
import eclusier_animate as legacy
import iso_rig
from ash_lord_build import worn, plate

DST=ROOT/'game/assets/sprites/bosses/etage/eclusier'
INV=json.loads((HERE/'_c7a_inventory.json').read_text())
COUNTS={k:v[0] for k,v in legacy.SPECS.items()}
EXTRAS={'wheel','wave','geyser','ground_geyser','ground_water','ground_wave'}

def block(n,loc,size,mat,parent,bevel=.035):
    o=c.box(n,loc,size,mat,parent,bevel)
    for m in o.modifiers:
        if m.type=='BEVEL':m.segments=1
    return o

def setup():
    s=iso_rig.create_rig('CREA',256)
    s.eevee.taa_render_samples=16
    s.camera.data.ortho_scale=6.4
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,6.4*.12,0))
    s['c7a_height_u']=3.5;s['c7a_pixels_per_u']=40;s['c7a_pivot']=[128,158.72]
    s.render.image_settings.compression=100
    return s

def build():
    s=setup();root=c.empty('ECLUSIER_C7A');body=c.empty('Carcass',(0,0,1.1),root)
    stone=worn('Wet quarried schist','202B2D','56615B',.1,.68)
    bronze=worn('Verdigris bronze 5F8F80','233E37','5F8F80',.65,.52)
    edge=worn('Worn bronze 8DBBA8','435D50','8DBBA8',.7,.43)
    iron=worn('Black chain iron','111B1C','424B47',.65,.59)
    wood=worn('Waterlogged oak','171914','403C2A',0,.83)
    water=worn('Black sluice water','071719','17383B',.35,.22)
    cyan=c.material('Cyan water only accent',(.025,.42,.5),.25,.23,1.5)
    # A split stone pier clad with offset cast bronze ribs; open gate at the front.
    for side in (-1,1):
        plate('Chipped pier',[(side*x,z) for x,z in ((.22,.02),(.70,0),(.86,.28),(.78,1.17),(.55,1.56),(.23,1.39))],-.29,.71,stone,body,.045)
        block('Flanking bronze jamb',(side*.60,-.39,.67),(.17,.20,1.45),bronze,body)
    block('Black recessed spillway',(0,-.34,.56),(.87,.1,1.0),iron,body)
    gate=c.empty('Sliding gate',(0,-.43,.62),body)
    for j in range(4):block('Oak gate stave',((j-1.5)*.17,0,0),(.155,.18,.91),wood,gate,.018)
    for z in (-.31,.31):block('Gate strap',(0,-.13,z),(.83,.10,.105),bronze,gate)
    for x in (-.28,.28):
        for z in (-.31,.31):c.sphere('Square pin',(x,-.20,z),(.037,.025,.037),edge,gate)
    for z in (.13,1.10):
        block('Pier lintel',(0,0,z),(1.65,.82,.16),bronze,body)
        for x in (-.65,-.33,0,.33,.65):c.sphere('Lintel bolt',(x,-.44,z),(.045,.025,.045),edge,body)
    # Narrow impersonal helmet embedded in the masonry, no oversized face.
    neck=c.empty('Helmet',(0,-.06,1.65),body)
    plate('Angular keeper mask',[(-.33,-.20),(.26,-.22),(.38,.08),(.19,.40),(-.22,.36),(-.36,.04)],-.30,.46,bronze,neck,.03)
    block('Dark visor',(0,-.337,.12),(.53,.055,.085),iron,neck,.012)
    block('Cyan slit',(0,-.37,.12),(.40,.015,.021),cyan,neck,.004)
    block('Mask keel',(.03,-.38,-.065),(.075,.13,.30),edge,neck,.015)
    # Large valve crown behind the torso; eight spokes and toothed locking wheel.
    wheel=c.empty('Valve axle',(0,.60,1.39),body)
    c.ring('Cast valve wheel',(0,0,0),.90,.095,bronze,wheel)
    c.ring('Polished outer lip',(0,-.025,0),.97,.026,edge,wheel)
    c.rod('Valve axle hub',(0,-.18,0),(0,.25,0),.17,iron,wheel)
    for j in range(8):
        a=j*math.tau/8;x,z=math.cos(a),math.sin(a)
        c.rod('Valve spoke',(.15*x,0,.15*z),(.85*x,0,.85*z),.052,bronze,wheel)
        o=block('Wheel tooth',(1.0*x,0,1.0*z),(.11,.18,.12),edge,wheel,.012);o.rotation_euler.y=-a
    arms=[];legs=[];chains=[]
    for side in (-1,1):
        arm=c.empty('Gate arm '+str(side),(side*.91,0,1.12),body);arms.append(arm)
        block('Shoulder socket',(0,0,0),(.51,.65,.49),stone,arm,.055)
        plate('Shoulder cast armour',[(-.32,-.12),(.31,-.14),(.37,.16),(.16,.30),(-.30,.24)],-.37,.58,bronze,arm,.03)
        c.rod('Elbow piston',(0,.05,-.14),(side*.14,.05,-.77),.105,iron,arm)
        for j in range(3):
            block('Massive gate plank',((j-1)*.19,-.035,-.73),(.17,.39,1.13),wood,arm,.021)
        for z in (-.28,-1.05):
            block('Door bronze brace',(0,-.27,z),(.74,.17,.13),bronze,arm)
            for x in (-.26,.26):c.sphere('Brace rivet',(x,-.37,z),(.044,.026,.044),edge,arm)
        o=block('Diagonal gate brace',(0,-.29,-.66),(.095,.09,.82),edge,arm,.012);o.rotation_euler.y=side*.52
        block('Stone impact fist',(0,-.08,-1.27),(.66,.55,.35),stone,arm,.055)
        # Alternating linked iron ovals draped below each shoulder.
        for j in range(8):
            o=c.ring('Hanging chain',(side*.29,-.38,-.11-j*.115),.072,.017,iron,arm,rotation=(math.pi/2,0,j%2*math.pi/2));o.scale.z=1.35;chains.append(o)
        leg=c.empty('Pier leg '+str(side),(side*.48,.02,.60),root);legs.append(leg)
        block('Stone shin',(0,0,-.12),(.47,.52,.72),stone,leg,.045)
        block('Ankle collar',(0,-.035,-.29),(.53,.59,.14),bronze,leg)
        block('Anchored foot',(0,-.19,-.47),(.64,.85,.24),stone,leg,.045)
        for x in (-.16,.16):block('Bronze foot cleat',(x,-.40,-.41),(.09,.30,.10),edge,leg,.012)
    # Physical leaks/phase additions; a second silhouette of water and burst braces.
    leaks=c.empty('Phase2 spill',parent=root)
    for side in (-1,1):
        c.tube('Sluice outflow',[(side*.22,-.52,1.24),(side*.3,-.65,.68),(side*.45,-.64,.13)],.065,water,leaks)
        c.tube('Cyan water glint',[(side*.22,-.59,1.18),(side*.27,-.71,.73),(side*.45,-.68,.14)],.013,cyan,leaks)
        for j in range(3):c.tube('Hanging weeds',[(side*.75,.02,1.8-j*.2),(side*(.85+j*.04),-.10,1.22-j*.16),(side*.79,-.12,.92-j*.11)],.021,wood,leaks)
    burst=c.empty('Phase3 ruptured bronze',parent=body)
    for side in (-1,1):
        o=block('Broken brace',(side*.72,-.28,.8),(.13,.17,1.1),edge,burst);o.rotation_euler.y=side*.38
        c.tube('Pressurised water',[(side*.55,-.4,.8),(side*.98,-.55,1.12),(side*1.16,-.68,.4)],.042,water,burst)
        c.tube('Water jet highlight',[(side*.55,-.44,.8),(side*.98,-.59,1.12),(side*1.16,-.72,.4)],.012,cyan,burst)
    iso_rig.bake_ao_shadows(root)
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def pose(anim,i,n):
        for o,(l,r,sc) in rest.items():o.location=l;o.rotation_euler=r;o.scale=sc
        t=i/n;u=i/max(n-1,1);w=math.sin(math.tau*t)
        p=3 if anim.endswith('p3') or anim in ('anchored','death') else 2 if anim.endswith('p2') else 1
        if anim=='trans_p2':ph=1+u
        elif anim=='trans_p3':ph=2+u
        else:ph=p
        leaks.scale=(max(.001,min(1,ph-1)),)*3;burst.scale=(max(.001,ph-2),)*3
        gate.location.z+=.29*(ph-1);body.location.z-=.12*(ph-1)
        for j,l in enumerate(legs):l.location.x+=(-1 if j==0 else 1)*.10*(ph-1)
        wheel.rotation_euler.y=t*math.tau*(.125 if ph<3 else .5)
        body.location.z+=.018*w
        if anim.startswith('walk'):
            for j,l in enumerate(legs):l.rotation_euler.x=.28*math.sin(math.tau*t+j*math.pi)
            for j,a in enumerate(arms):a.rotation_euler.x=-.20*math.sin(math.tau*t+j*math.pi)
            body.rotation_euler.z=.035*w
        if anim=='auto':
            # 0 ready, 1/2 windup, 3=N/2 full impact, 4 recoil, 5 recovered.
            swing=[0,.85,1.90,-.65,-.28,0][i]
            arms[1].rotation_euler.x=swing;arms[1].rotation_euler.y=[0,.1,.25,-.20,-.1,0][i]
            body.rotation_euler.x=[0,-.08,-.19,.24,.10,0][i]
            body.rotation_euler.z=[0,-.1,-.23,.20,.08,0][i]
            arms[0].rotation_euler.x=-.28*math.sin(math.pi*u)
        if anim=='spell_a':
            q=math.sin(math.pi*u);arms[0].rotation_euler.x=-1.1*q;arms[1].rotation_euler.x=-.6*q
            wheel.rotation_euler.y=t*math.tau;gate.location.z+=.65*q;leaks.scale=(max(.001,q),)*3
        if anim=='spell_b':
            q=[0,.13,.31,.43,-.14,-.07,-.025,0][i];body.location.z+=q
            for a in arms:a.rotation_euler.x=-2*q
            legs[1].location.z+=max(0,q);burst.scale=(max(.001,math.sin(math.pi*u)),)*3
        if anim=='death':
            body.location.z-=.75*u;body.rotation_euler.x=1.3*u
            wheel.location.z-=1.2*u;wheel.rotation_euler.z=1.7*u
            for j,a in enumerate(arms):a.rotation_euler.y=(-1 if j==0 else 1)*u
            for j,l in enumerate(legs):l.rotation_euler.x=.9*u
            leaks.scale=(max(.001,1-u),)*3
        for j,ch in enumerate(chains):ch.rotation_euler.x+=.09*math.sin(math.tau*t+j*.4)
    return root,pose,wheel

def save_source(root,pose):
    s=bpy.context.scene;f=1
    for anim in [a for a in COUNTS if a not in EXTRAS]:
        n=COUNTS[anim];s.timeline_markers.new(anim,frame=f)
        for i in range(n):
            pose(anim,i,n)
            for o in root.children_recursive:
                for k in ('location','rotation_euler','scale'):o.keyframe_insert(k,frame=f+i)
        f+=n+2
    s.frame_end=f;s.render.fps=12
    path=ROOT/'art/blender/monsters/eclusier_iso.blend';path.parent.mkdir(parents=True,exist_ok=True)
    s.frame_set(1);bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    for o in root.children_recursive:o.animation_data_clear()

def append_tres():
    t=INV['original_tres'];ext=[];subs=[];anims=[]
    for anim in ('auto','spell_a','spell_b'):
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/eclusier/{anim}_dirs.png" id="c7a_{anim}"]')
        ref=next(a for a in INV['animations'] if a['name']==anim+'_s')
        for row,d in enumerate(('e','w','n')):
            frames=[]
            for i in range(COUNTS[anim]):
                sid=f'C7a_{anim}_{d}_{i}'
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("c7a_{anim}")\nregion = Rect2({i*256}, {row*256}, 256, 256)')
                frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
            anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(ref['loop']).lower()+', "name": &"'+anim+'_'+d+'", "speed": '+str(ref['fps'])+'}')
    t=t.replace('[sub_resource', '\n\n'.join(ext)+'\n\n[sub_resource',1)
    t=t.replace('[resource]', '\n\n'.join(subs)+'\n\n[resource]',1)
    at=t.rfind(']');t=t[:at]+',\n'+',\n'.join(anims)+t[at:]
    t=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])+3+66),t,count=1)
    (DST/'eclusier.tres').write_text(t,encoding='utf-8')

def main():
    contact={};report={}
    with tempfile.TemporaryDirectory(prefix='rainfall_c7a_') as tmp:
        tmp=Path(tmp);root,pose,wheel=build();save_source(root,pose)
        tasks=[a for a in COUNTS if a not in EXTRAS]+['auto_dirs','spell_a_dirs','spell_b_dirs','idle_contact']
        tasks+=list(a for a in COUNTS if a in EXTRAS)
        if '--attack-only' in sys.argv:tasks=['auto','auto_dirs','spell_b','spell_b_dirs','idle_contact']
        for task in tasks:
            if task in EXTRAS:
                if task=='wheel':
                    root,pose,wheel=build();allobs=root.children_recursive
                    keep=set(wheel.children_recursive+[wheel])
                    for o in allobs:o.hide_render=o not in keep
                    wheel.parent=root;wheel.location=(0,0,.25)
                    bpy.context.scene.camera.data.ortho_scale=3.9
                    def p(t):wheel.rotation_euler.y=math.tau*t/8
                else:
                    root,p=legacy.make(task)
                    s=bpy.context.scene
                    if task!='ground_water':
                        origin=s.camera.location-s.camera.rotation_euler.to_matrix()@Vector((0,0,10))
                        s.camera.rotation_euler=(math.pi/3,0,0)
                        s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,0,10))
                    s.eevee.taa_render_samples=16
                    for mat in bpy.data.materials:
                        if mat.name.startswith(('Eau argent','Ecume lumineuse')):
                            bs=mat.node_tree.nodes.get('Principled BSDF')
                            bs.inputs['Base Color'].default_value=(.012,.044,.05,1) if mat.name.startswith('Eau argent') else (.04,.29,.32,1)
                            bs.inputs['Emission Color'].default_value=(.015,.32,.38,1)
                            bs.inputs['Emission Strength'].default_value=.06 if mat.name.startswith('Eau argent') else .7
            base=task.replace('_dirs','');base='idle_p1' if task=='idle_contact' else base
            n=COUNTS[base];dirs=['e','w','n'] if task.endswith('_dirs') else ['e','s','w','n'] if task.startswith('walk') or task=='idle_contact' else ['s']
            cell=(128,576) if base in ('wave','ground_wave') else (128,128) if base in EXTRAS else (256,256)
            s=bpy.context.scene;s.render.resolution_x=cell[0]*2;s.render.resolution_y=cell[1]*2
            boards=[Image.new('RGBA',(cell[0]*n,cell[1]*len(dirs)),(128,128,255,0) if j==1 else (0,0,0,0)) for j in range(3)]
            for row,d in enumerate(dirs):
                for i in range(n if task!='idle_contact' else 1):
                    path=tmp/f'{task}_{d}_{i}.png'
                    fn=p if task in EXTRAS else lambda t,b=base,i=i,n=n:pose(b,i,n)
                    c.render_still(root,fn,path,i/n,d)
                    for j,suffix in enumerate(('','_n','_e')):
                        im=Image.open(path.with_name(path.stem+suffix+'.png')).convert('RGBA').resize(cell,Image.Resampling.LANCZOS)
                        if j==0:alpha=im.getchannel('A')
                        else:im.putalpha(alpha)
                        if j==1:
                            im.putdata([(128,128,255,0) if a==0 else (r,g,b,a) for r,g,b,a in im.getdata()])
                        boards[j].paste(im,(i*cell[0],row*cell[1]))
                        if j==0 and (task=='idle_contact' or base=='auto' and i in (2,3) or base in EXTRAS and i==0):contact[f'{base}_{d}_{i}']=im.copy()
            if task!='idle_contact':
                for board,suffix in zip(boards,('','_n','_e')):board.save(DST/f'{task}{suffix}.png',compress_level=9)
                report[task]={'size':boards[0].size,'frames':n,'directions':dirs}
            print('C7A DONE',task,flush=True)
        append_tres();make_contact(contact)
        (DST/'lighting.md').write_text('C7a: CREA elevation 30 deg; orthographic scale 6.4, 40 px/u, ground origin (128,158.72). Standard, Eevee 16 samples, 2x/Lanczos. PBR worn bronze/stone/oak, AO and studio self-shadows baked. _n: Blender world Normal projected to screen, R right G up B camera, Raw encoding, transparent=(128,128,255,0). _e: Blender Emission, isolated cyan water only; matching alpha/grid. walk rows e,s,w,n; *_dirs rows e,w,n. auto impact frame 3 of 6, non-looping.\n',encoding='utf-8')
        rp=HERE/'_c7a_render_report.json'
        if '--attack-only' in sys.argv and rp.exists():report={**json.loads(rp.read_text()),**report}
        rp.write_text(json.dumps(report,indent=2))
        manifest=['# Eclusier C7a','', 'New stone and verdigris bronze sluice guardian, height 3.5 u. Worn oak gate arms, linked chains, eight-spoke valve crown. Phase 2: raised gate, leaks and weeds. Phase 3: braced stance, ruptured bronze and pressurised jets.','', 'Source: art/blender/monsters/eclusier_iso.blend; generator: art/tools/monsters/c7a_build.py.','', '| Sheet | Cell | Frames | Rows |','|---|---|---:|---|']
        for a in COUNTS:
            cell='128x576' if a in ('wave','ground_wave') else '128x128' if a in EXTRAS else '256x256'
            manifest.append(f'| {a} | {cell} | {COUNTS[a]} | '+('e,s,w,n' if a.startswith('walk') else 's')+' |')
        for a in ('auto','spell_a','spell_b'):manifest.append(f'| {a}_dirs | 256x256 | {COUNTS[a]} | e,w,n |')
        manifest+=['','Each sheet includes matching _n and _e. Existing animation definitions retained verbatim; nine directional attacks appended. Auto impact index 3, 12 fps, non-looping. Legacy ortho scale/pivot preserved at elevation 30 degrees.','Contact: art/tools/monsters/_c7a_contact.png. Inventory: _c7a_inventory.json.']
        (DST/'manifest.md').write_text('\n'.join(manifest)+'\n',encoding='utf-8')

def make_contact(frames):
    # Assembly only, no painted text or imagery. At preserved 40 pixels/world unit.
    rows=[]
    for d in ('e','s','w','n'):
        rows.append([frames[f'idle_p1_{d}_0'],frames[f'auto_{d}_2'],frames[f'auto_{d}_3']])
    extras=[]
    for a in COUNTS:
        if a not in EXTRAS:continue
        im=Image.open(DST/f'{a}.png').convert('RGBA')
        w=128;h=576 if a in ('wave','ground_wave') else 128
        extras.append(im.crop((0,0,w,h)))
    # Ardent C4 uses 90.5097 px/u; ash R8 uses framing recorded in its contact metadata.
    ard=Image.open(ROOT/'game/assets/sprites/characters/ardent/idle.png').convert('RGBA').crop((0,384,192,576))
    ard=ard.resize((85,85),Image.Resampling.LANCZOS)
    ash=Image.open(ROOT/'game/assets/sprites/bosses/mini/ash_lord/idle.png').convert('RGBA').crop((0,0,170,170))
    ash=ash.resize((155,155),Image.Resampling.LANCZOS)
    board=Image.new('RGBA',(1280,1664),(38,44,46,255))
    for j,ims in enumerate(rows):
        for k,im in enumerate(ims):board.alpha_composite(im,(k*256,j*256))
        board.alpha_composite(ard,(850, j*256+int(158.72-.7*85)))
        board.alpha_composite(ash,(1010,j*256+int(158.72-.7*155)))
    x=0
    for im in extras:board.alpha_composite(im,(x,1056));x+=max(160,im.width)
    board.convert('RGB').save(HERE/'_c7a_contact.png',compress_level=9)
    (HERE/'_c7a_contact.json').write_text(json.dumps({'rows':'e,s,w,n: idle, auto windup frame2, impact frame3, Ardent C4, ash_lord','extras':[a for a in COUNTS if a in EXTRAS],'scale_px_u':40,'ardent_scale':40/iso_rig.R,'ash_scale':40/43.8114427},indent=2))

if __name__=='__main__':main()
