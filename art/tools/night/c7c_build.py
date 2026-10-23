"""C7C Sonneur: C7a pipeline, new rust-city bell foundry colossus.
Background Blender only; original grids, animation definitions and pivot retained.
"""
import sys, math, json, re, tempfile, hashlib, random
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path[:0]=[str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/bosses'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/iso/_deps'),str(Path.home()/'AppData/Local/RainfallIsoDeps')]
import bpy
from mathutils import Vector
from PIL import Image
import boss_common as c
import sonneur as legacy
import iso_rig
from ash_lord_build import worn, plate, mesh

DST=ROOT/'game/assets/sprites/bosses/etage/sonneur'
INV=json.loads((HERE/'_c7c_inventory.json').read_text())
COUNTS={k:v[0] for k,v in legacy.SPECS.items()}
EXTRAS={'lightning','bolt','steam_vent','ground_lightning','ground_scorch','ground_steam'}

def block(n,loc,size,mat,parent,bevel=.025):
    o=c.box(n,loc,size,mat,parent,bevel)
    for m in o.modifiers:
        if m.type=='BEVEL':m.segments=1
    return o

def setup():
    s=iso_rig.create_rig('CREA',256)
    s.eevee.taa_render_samples=16
    s.camera.data.ortho_scale=5.3
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,5.3*.15,0))
    s['c7c_height_u']=3.8;s['c7c_pixels_per_u']=256/5.3;s['c7c_pivot']=[128,166.4]
    s.render.image_settings.compression=100
    s.view_layers[0].use_pass_normal=True;s.view_layers[0].use_pass_emit=True
    return s

def steam_mesh(parent,mat,name='Pressure vapour',height=1):
    objects=[]
    for j in range(5):
        verts=[];faces=[]
        for k in range(12):
            t=k/11; a=t*4+j*1.7; width=(.035+.11*t)*math.sin(math.pi*t)**.6
            center=Vector((.11*math.sin(a)*t,.08*math.cos(a*1.3)*t,t*height))
            for side in (-1,1):verts.append(center+Vector((side*width,side*width*.2,0)))
        for k in range(11):faces.append((k*2,k*2+1,k*2+3,k*2+2))
        o=mesh(name,verts,faces,mat,parent);o.rotation_euler.z=j*1.1;objects.append(o)
    return objects

def build():
    s=setup();root=c.empty('SONNEUR_C7C_3_8U');root['height_u']=3.8
    body=c.empty('Riveted firebox',(0,0,.76),root)
    rust=worn('Scabbed iron oxide 6B3A22','241B16','6B3A22',.58,.77)
    black=worn('Soot black iron 2B2A29','0B1011','353A37',.65,.57)
    brass=worn('Worn brass A8946E','474535','A8946E',.72,.48)
    bellmat=worn('Cast bell verdigris 5F8F80','263C36','667F69',.72,.61)
    edge=worn('Bell lip worn brass','474333','9B8C66',.75,.42)
    coal=worn('Carbon in furnace cavities','050707','181B18',.05,.95)
    glow=legacy.emissive('Single pale amber electrical accent','FFC584',1.3)
    smoke=worn('Condensed dirty pressure steam','505C59','8D9990',0,.95)
    bs=smoke.node_tree.nodes.get('Principled BSDF');bs.inputs['Alpha'].default_value=.26
    smoke.surface_render_method='DITHERED'
    # Tall polygonal firebox; open front, nested cavity, cast segments and bands.
    legacy.lathe('Dodecagonal boiler',[(.48,.05),(.69,.15),(.75,.55),(.68,1.14),(.49,1.60),(.30,1.68)],rust,body,12)
    plate('Deep furnace cavity',[(-.4,.29),(.36,.29),(.44,.88),(.25,1.25),(-.27,1.26),(-.45,.85)],-.724,.14,coal,body,.025)
    fire=c.empty('Exposed furnace fire',(0,-.75,.72),body)
    for j in range(5):
        plate('Internal hot flue',[(-.035,-.37),(.03,-.32),(.05,.27),(-.02,.35)],-.03-j*.005,.02,glow,fire,.003).location.x=(j-2)*.125
    gate=c.empty('Torn furnace door',(-.40,-.80,.32),body)
    plate('Armoured furnace door',[(0,0),(.80,.01),(.85,.52),(.69,.91),(.14,.94),(-.06,.58)],0,.11,rust,gate,.025)
    for x in (.11,.31,.51,.71):block('Door grille',(x,-.027,.51),(.067,.05,.46),black,gate,.008)
    block('Door viewing slit',(.40,-.062,.72),(.34,.012,.026),glow,gate,.004)
    for z,r in ((.22,.75),(1.03,.72),(1.46,.53)):
        c.ring('Forged boiler strap',(0,0,z),r,.045,black,body,rotation=(0,0,0))
        for k in range(12):
            a=k*math.tau/12
            c.sphere('Peened brass bolt',(r*math.sin(a),-r*math.cos(a),z),(.035,.035,.035),brass,body)
    for side in (-1,1):
        c.tube('High pressure return pipe',[(side*.56,.31,.13),(side*.81,.35,.48),(side*.81,.35,1.62),(side*.32,.29,1.83)],.055,black,body)
        for z in (.48,1.35):c.ring('Pipe compression collar',(side*.81,.35,z),.075,.025,brass,body,rotation=(0,0,0))
    # Asymmetric chimney organ behind the bell; slim negative spaces.
    for j in range(3):
        x=(j-1)*.25;h=(1.98,2.42,2.18)[j]
        c.rod('Soot stack',(x,.43,.8),(x,.43,h),.09,black,body)
        c.ring('Chimney lip',(x,.43,h),.105,.025,brass,body,rotation=(0,0,0))
    bell=c.empty('Bell head',(0,-.03,2.36),root)
    # Hollow flared casting, uneven crown armour and visible clapper.
    legacy.lathe('Hollow funerary bell',[(.54,0),(.57,.06),(.50,.13),(.39,.31),(.32,.61),(.27,.75),(.19,.79),(.13,.73),(.22,.63),(.28,.32),(.43,.10),(.49,.06)],bellmat,bell,32)
    for z,r in ((.075,.55),(.18,.47),(.62,.31)):
        c.ring('Bell cast moulding',(0,0,z),r,.023,edge,bell,rotation=(0,0,0))
    c.rod('Suspended bell clapper',(0,0,.5),(0,0,-.14),.047,black,bell)
    c.sphere('Clapper striker',(0,0,-.15),(.11,.11,.16),brass,bell)
    for k in range(10):
        a=k*math.tau/10;ob=block('Incised bell rib',(.355*math.sin(a),-.355*math.cos(a),.38),(.032,.04,.29),black,bell,.004);ob.rotation_euler.z=a
    c.rod('Lightning conductor',(0,0,.77),(.07,0,1.34),.026,brass,bell)
    for z in (.87,.96,1.05):c.ring('Porcelain insulator',(0,0,z),.071,.022,black,bell,rotation=(0,0,0))
    arcs=c.empty('Phase two induction arcs',(0,0,0),bell)
    for j in range(3):
        c.tube('Induction hairline',[(.06,0,1.32),(.18*(-1)**j,-.05,1.20),(.10,-.10,1.11),(.30*(-1)**j,-.10,.88)],.012,glow,arcs)
    arms=[];legs=[]
    for side in (-1,1):
        arm=c.empty('Hammer shoulder',(side*.84,0,1.98),body);arms.append(arm)
        plate('Sloping shoulder shield',[(side*x,z) for x,z in ((-.18,.02),(.31,-.09),(.48,-.38),(.25,-.53),(-.14,-.30))],-.25,.49,rust,arm,.025)
        c.rod('Arm piston',(side*.17,0,-.13),(side*.30,-.03,-.71),.10,black,arm)
        c.rod('Piston polished shaft',(side*.18,-.12,-.29),(side*.32,-.15,-.85),.045,brass,arm)
        c.ring('Elbow bearing',(side*.30,-.04,-.69),.15,.035,brass,arm)
        block('Cast hammer arm',(side*.35,-.10,-1.0),(.29,.35,.55),black,arm)
        block('Forging hammer',(side*.38,-.16,-1.29),(.62 if side==1 else .47,.58,.37),rust,arm,.045)
        block('Worn striking face',(side*.38,-.47,-1.29),(.55 if side==1 else .41,.075,.29),brass,arm,.018)
        for z in (-1.15,-1.40):block('Hammer iron binding',(side*.38,-.16,z),(.65 if side==1 else .50,.61,.043),black,arm,.01)
        leg=c.empty('Anchored iron leg',(side*.43,0,.79),root);legs.append(leg)
        c.rod('Lower hydraulic strut',(0,0,-.05),(side*.09,-.03,-.49),.13,black,leg)
        plate('Shin shield',[(-.18,-.12),(.16,-.15),(.23,-.53),(-.24,-.57)],-.18,.25,rust,leg,.025)
        block('Splayed foundry foot',(side*.09,-.18,-.66),(.48,.69,.22),black,leg,.03)
        for x in (-.12,.12):block('Foot cleat',(side*.09+x,-.53,-.66),(.09,.1,.17),brass,leg,.01)
    vent=c.empty('Boiler rupture steam',(.49,.16,1.90),body)
    steam_mesh(vent,smoke,height=.54)
    iso_rig.bake_ao_shadows(root)
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def pose(anim,i,n):
        for o,(l,r,sc) in rest.items():o.location=l;o.rotation_euler=r;o.scale=sc;o.hide_render=False
        t=i/n;u=i/max(1,n-1);w=math.sin(math.tau*t)
        ph=3 if anim.endswith('p3') or anim in ('death','boiler_open') else 2 if anim.endswith('p2') else 1
        if anim=='trans_p2':ph=1+u
        if anim=='trans_p3':ph=2+u
        arcs.scale=(max(.001,min(1,ph-1)),)*3
        gate.rotation_euler.z=-1.15*max(0,ph-2)
        gate.rotation_euler.y=-.19*max(0,ph-2)
        vent.scale=(max(.001,ph-2),)*3
        body.location.z+=.018*w;bell.rotation_euler.y=.02*w
        if anim.startswith('walk'):
            for j,l in enumerate(legs):l.rotation_euler.x=.28*math.sin(math.tau*t+j*math.pi)
            for j,a in enumerate(arms):a.rotation_euler.x=-.17*math.sin(math.tau*t+j*math.pi)
            body.rotation_euler.z=.035*w;bell.rotation_euler.x=.04*w
        if anim=='auto':
            arms[1].rotation_euler.x=[0,.8,1.65,-.72,-.31,0][i]
            arms[1].rotation_euler.y=[0,.10,.24,-.16,-.06,0][i]
            body.rotation_euler.x=[0,-.06,-.15,.20,.08,0][i]
            body.rotation_euler.z=[0,-.08,-.18,.15,.06,0][i]
        if anim=='spell_a':
            q=math.sin(math.pi*u);bell.rotation_euler.y=.2*math.sin(math.tau*t*2)*q
            bell.location.z-=.18*q
            arms[0].rotation_euler.x=-1.22*q;arms[1].rotation_euler.x=-.94*q
            arcs.scale=(max(.001,q),)*3
        if anim=='spell_b':
            q=[0,.08,.18,.24,-.12,-.06,-.02,0][i];body.location.z+=q
            for a in arms:a.rotation_euler.x=-3*q
            gate.rotation_euler.z=-.7*math.sin(math.pi*u);vent.scale=(max(.001,math.sin(math.pi*u)),)*3
        if anim=='bell_ring':bell.rotation_euler.y=.17*math.sin(math.tau*t*2)
        if anim=='boiler_open':
            keep=set(fire.children_recursive+[fire,gate]+gate.children_recursive+vent.children_recursive)
            for o in root.children_recursive:
                if o.type in ('MESH','CURVE'):o.hide_render=o not in keep
        if anim=='death':
            body.location.z-=.63*u;body.rotation_euler.x=1.35*u
            bell.location.z-=1.7*u;bell.location.x+=.7*u;bell.rotation_euler.y=1.5*u
            for j,a in enumerate(arms):a.rotation_euler.y=(-1 if j==0 else 1)*.9*u
            for l in legs:l.rotation_euler.x=.7*u
            arcs.scale=(max(.001,1-u),)*3
    return root,pose,fire

def extra(task):
    s=setup();s.camera.location-=s.camera.rotation_euler.to_matrix()@Vector((0,5.3*.15,0))
    if task in ('steam_vent','ground_steam'):
        root=c.empty('Pressure plume')
        smoke=worn('Dirty steam plume','414C4B','A2AAA0',0,.98)
        smoke.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.35;smoke.surface_render_method='DITHERED'
        objects=steam_mesh(root,smoke,height=5.65)
        if task=='ground_steam':
            for o in objects:o.rotation_euler.x=math.pi/2
        def p(t):
            for j,o in enumerate(objects):
                o.rotation_euler.z=(.025*math.sin(math.tau*t+j)) if task=='ground_steam' else j*1.1+.32*math.sin(math.tau*t+j)
                o.scale.x=.8+.2*math.sin(math.tau*t+j)
    else:root,p=legacy.prop(task)
    if task=='bolt':root.location.z=0;root.scale=(.72,)*3
    if task in ('lightning','steam_vent'):
        s.camera.rotation_euler=(math.pi/2,0,0);s.camera.location=(0,-20,6 if task=='lightning' else 3);s.camera.data.ortho_scale=12 if task=='lightning' else 6
    elif task in ('ground_steam','ground_lightning','ground_scorch'):
        s.camera.rotation_euler=(0,0,0);s.camera.location=(0,-2.8,10) if task=='ground_steam' else (0,0,10);s.camera.data.ortho_scale=6 if task=='ground_steam' else 2.4
    else:s.camera.data.ortho_scale=1.15
    # One hue shared by induction, impact and the furnace; no blue/orange split.
    old=p
    def pose(t):
        old(t)
        for m in bpy.data.materials:
            bs=m.node_tree.nodes.get('Principled BSDF') if m.use_nodes else None
            if bs and bs.inputs['Emission Strength'].default_value>0:bs.inputs['Emission Color'].default_value=(*legacy.linear('FFC584'),1)
    bpy.context.view_layer.update()
    return root,pose

def save_source(root,pose):
    s=bpy.context.scene;f=1
    for anim in [a for a in COUNTS if a not in EXTRAS]:
        n=COUNTS[anim];s.timeline_markers.new(anim,frame=f)
        for i in range(n):
            pose(anim,i,n)
            for o in root.children_recursive:
                for k in ('location','rotation_euler','scale','hide_render'):o.keyframe_insert(k,frame=f+i)
        f+=n+2
    s.frame_end=f;s.render.fps=12
    path=ROOT/'art/blender/monsters/sonneur_iso.blend';path.parent.mkdir(parents=True,exist_ok=True)
    s.frame_set(1);bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(path))
    assert not any(o.hide_render for o in root.children_recursive if o.type in ('MESH','CURVE')),'Source initial pose hidden'
    print('C7C SOURCE PASS',sum(len(o.data.polygons) for o in root.children_recursive if o.type=='MESH'),'polygons',flush=True)
    for o in root.children_recursive:o.animation_data_clear()

def append_tres():
    t=INV['original_tres'];ext=[];subs=[];anims=[]
    for anim in ('auto','spell_a','spell_b'):
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/sonneur/{anim}_dirs.png" id="c7c_{anim}"]')
        ref=next(a for a in INV['animations'] if a['name']==anim+'_s')
        for row,d in enumerate(('e','w','n')):
            frames=[]
            for i in range(COUNTS[anim]):
                sid=f'C7c_{anim}_{d}_{i}'
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("c7c_{anim}")\nregion = Rect2({i*256}, {row*256}, 256, 256)')
                frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
            anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(ref['loop']).lower()+', "name": &"'+anim+'_'+d+'", "speed": '+str(ref['fps'])+'}')
    t=t.replace('[sub_resource','\n\n'.join(ext)+'\n\n[sub_resource',1)
    t=t.replace('[resource]','\n\n'.join(subs)+'\n\n[resource]',1)
    at=t.rfind(']');t=t[:at]+',\n'+',\n'.join(anims)+t[at:]
    t=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])+69),t,count=1)
    (DST/'sonneur.tres').write_text(t,encoding='utf-8')

def make_contact(frames):
    for row,d in enumerate(('e','s','w','n')):
        if f'idle_p1_{d}_0' not in frames:
            frames[f'idle_p1_{d}_0']=Image.open(DST/'walk_p1.png').convert('RGBA').crop((0,row*256,256,(row+1)*256))
        for i in (2,3):
            if f'auto_{d}_{i}' not in frames:
                filename='auto.png' if d=='s' else 'auto_dirs.png';r=0 if d=='s' else ('e','w','n').index(d)
                frames[f'auto_{d}_{i}']=Image.open(DST/filename).convert('RGBA').crop((i*256,r*256,(i+1)*256,(r+1)*256))
    board=Image.new('RGBA',(1536,1536),(35,40,41,255))
    ard=Image.open(ROOT/'game/assets/sprites/characters/ardent/idle.png').convert('RGBA').crop((0,384,192,576)).resize((102,102),Image.Resampling.LANCZOS)
    ash=Image.open(ROOT/'game/assets/sprites/bosses/mini/ash_lord/idle.png').convert('RGBA').crop((0,0,170,170)).resize((187,187),Image.Resampling.LANCZOS)
    for row,d in enumerate(('e','s','w','n')):
        for col,key in enumerate((f'idle_p1_{d}_0',f'auto_{d}_2',f'auto_{d}_3')):board.alpha_composite(frames[key],(col*256,row*256))
        board.alpha_composite(ard,(825,row*256+95));board.alpha_composite(ash,(1080,row*256+35))
    for j,a in enumerate(('idle_p2','idle_p3','bell_ring','boiler_open')):
        im=Image.open(DST/f'{a}.png').convert('RGBA').crop((0,0,256,256));board.alpha_composite(im,(j*256,1024))
    x=0
    for a in EXTRAS:
        w,h=legacy.SPECS[a][3];im=Image.open(DST/f'{a}.png').convert('RGBA').crop((0,0,w,h))
        im.thumbnail((128,240));board.alpha_composite(im,(x,1280));x+=160
    # Validated DA references included without separate image reads.
    for j,p in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png')):
        im=Image.open(ROOT/p).convert('RGBA');im.thumbnail((180,240));board.alpha_composite(im,(1000+j*178,1280))
    board.convert('RGB').save(HERE/'_c7c_contact.png',compress_level=9)

def main():
    contact={};report={}
    with tempfile.TemporaryDirectory(prefix='rainfall_c7c_') as tmp:
        tmp=Path(tmp);root,pose,fire=build()
        if '--diagnose' in sys.argv:
            from bpy_extras.object_utils import world_to_camera_view
            for anim,d,i in (('spell_a','e',5),('spell_a','w',3),('spell_b','s',3),('spell_b','e',3)):
                pose(anim,i,8);root.rotation_euler.z=c.DIRECTIONS[d];bpy.context.view_layer.update();tops=[]
                for o in root.children_recursive:
                    if o.type=='MESH' and not o.hide_render:
                        tops.append((max(world_to_camera_view(bpy.context.scene,bpy.context.scene.camera,o.matrix_world@v.co).y for v in o.data.vertices),o.name))
                print('DIAG',anim,d,i,sorted(tops,reverse=True)[:3],flush=True)
            return
        save_source(root,pose)
        if '--source-only' in sys.argv:return
        tasks=[a for a in COUNTS if a not in EXTRAS]+['auto_dirs','spell_a_dirs','spell_b_dirs','idle_contact']+sorted(EXTRAS)
        if '--preview' in sys.argv:tasks=['idle_contact','auto','auto_dirs','idle_p3']
        if '--only' in sys.argv:
            tasks=sys.argv[sys.argv.index('--only')+1].split(',')
            report=json.loads((HERE/'_c7c_render_report.json').read_text())
        for task in tasks:
            base=task.replace('_dirs','');base='idle_p1' if task=='idle_contact' else base
            if task in EXTRAS:root,p=extra(task)
            n=COUNTS[base];dirs=['e','w','n'] if task.endswith('_dirs') else ['e','s','w','n'] if task.startswith('walk') or task=='idle_contact' else ['s']
            cell=legacy.SPECS[base][3];s=bpy.context.scene;s.render.resolution_x=cell[0]*2;s.render.resolution_y=cell[1]*2
            boards=[Image.new('RGBA',(cell[0]*n,cell[1]*len(dirs)),(128,128,255,0) if j==1 else (0,0,0,0)) for j in range(3)]
            for row,d in enumerate(dirs):
                for i in range(n if task!='idle_contact' else 1):
                    path=tmp/f'{task}_{d}_{i}.png';fn=p if task in EXTRAS else lambda t,b=base,i=i,n=n:pose(b,i,n)
                    c.render_still(root,fn,path,i/n,d)
                    for j,suffix in enumerate(('','_n','_e')):
                        im=Image.open(path.with_name(path.stem+suffix+'.png')).convert('RGBA').resize(cell,Image.Resampling.LANCZOS)
                        if j==0:alpha=im.getchannel('A')
                        else:im.putalpha(alpha)
                        if j==1:im.putdata([(128,128,255,0) if a==0 else (r,g,b,a) for r,g,b,a in im.getdata()])
                        boards[j].paste(im,(i*cell[0],row*cell[1]))
                        if j==0 and (task=='idle_contact' or base=='auto' and i in (2,3)):contact[f'{base}_{d}_{i}']=im.copy()
            if task!='idle_contact':
                for board,suffix in zip(boards,('','_n','_e')):board.save(DST/f'{task}{suffix}.png',compress_level=9)
                report[task]={'size':boards[0].size,'frames':n,'directions':dirs}
            (HERE/'_c7c_render_report.json').write_text(json.dumps(report,indent=2))
            print('C7C DONE',task,flush=True)
        if '--preview' in sys.argv:return
        append_tres();make_contact(contact)
        (DST/'lighting.md').write_text('C7C: CREA 30 degrees, legacy ortho 5.3, 48.301887 px/u, ground origin (128,166.4). Eevee 16 samples, Standard, 2x/Lanczos. Worn PBR and shader AO/self shadows baked. Normal pass in screen space: R right, G up, B camera; Raw encoding; empty pixels (128,128,255,0). _e is isolated Blender Emission, single pale amber electrical/furnace accent. All passes share diffuse alpha and original grid. walk rows e,s,w,n; attack _dirs rows e,w,n. Auto impact index 3/6, non-looping. Extras retain legacy top/front framing.\n',encoding='utf-8')
        manifest=['# Sonneur C7C','','New 3.8 u foundry colossus: hollow verdigris funeral bell, asymmetric chimney organ, worn iron firebox, brass hydraulic hammer arms. Phase 2: live induction crown; phase 3: torn door, exposed furnace and dirty pressure steam. One pale amber accent unifies electricity and furnace.','','Source: art/blender/monsters/sonneur_iso.blend; generator: art/tools/night/c7c_build.py.','','| Sheet | Cell | Frames | Rows |','|---|---|---:|---|']
        for a,v in report.items():
            cell=legacy.SPECS[a.replace('_dirs','')][3];manifest.append(f"| {a} | {cell[0]}x{cell[1]} | {v['frames']} | {','.join(v['directions'])} |")
        manifest+=['','Original 60 PNG dimensions and 29 animation definitions retained; 9 directional animations appended, 69 PNG total. Each sheet has real Blender normal/emission passes. Inventory and checks: art/tools/night/_c7c_inventory.json, _c7c_verify.json. Contact columns: idle, anticipation, impact, Ardent, Ash Lord (same physical scale); lower rows: phases, bell, furnace layer, extras and validated DA reference boards.']
        (DST/'manifest.md').write_text('\n'.join(manifest)+'\n',encoding='utf-8')

if __name__=='__main__':main()
