"""C7D: additive Cerf extensions, using the exact C7b model, rig and passes.
Blender --background --python art/tools/night/c7d_build.py
Pillow only assembles/resizes Blender renders. No game scripts are modified.
"""
import sys, math, re, json, tempfile, hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import c7b_build as b
import bpy
from mathutils import Vector
from PIL import Image
c=b.c; DST=b.DST; ROOT=b.ROOT
DIRS=('e','s','w','n')
SPECS={'charge_dirs':(6,256,256,18,True),'antlers_dirs':(8,256,256,12,False),'wisp_bolt':(4,64,32,12,True)}


def charge_pose(root,base,i):
    base('idle_p1',i,6)
    t=math.tau*i/6
    body=next(o for o in root.children_recursive if o.name=='Thorax')
    neck=next(o for o in root.children_recursive if o.name=='Neck pivot')
    head=next(o for o in root.children_recursive if o.name=='Narrow death mask')
    crown=next(o for o in root.children_recursive if o.name=='Ramure')
    body.location.z+=-.12+.085*math.cos(t)
    body.rotation_euler.x=.10+.045*math.sin(t)
    # Real neck flexion sends the broad crown forward, below the shoulder line.
    neck.rotation_euler.x=.83+.045*math.sin(t)
    head.rotation_euler.x=.16
    head.rotation_euler.z=.018*math.sin(t)
    crown.rotation_euler.x=.10
    for o in root.children_recursive:
        if o.name.startswith(('Foreleg','Hindleg')):
            front=o.name.startswith('Foreleg');side=1 if o.location.x>0 else -1
            a=t+(0 if front else 2.05)+side*.28
            o.rotation_euler.x=.78*math.sin(a)+(-.12 if front else .12)
            o.location.z+=.075*max(0,math.cos(a))
            shin=next(ch for ch in o.children if ch.name.startswith('Shin pivot'))
            shin.rotation_euler.x=-.90*max(0,math.cos(a))
        if o.name.startswith('Hanging votive lantern'):
            o.rotation_euler.x=1.02+.13*math.sin(t+o.location.x)
            o.rotation_euler.y=.09*math.sin(t+o.location.x*2)
        if o.name.startswith('Captive wisp flame'):
            o.rotation_euler.x=-.32;o.scale.z*=1.30+.12*math.sin(t)


def lantern_pose(root,base,i):
    # The unmodified spell_b pose is evaluated at exactly the original frame time.
    base('spell_b',i,8)
    for o in root.children_recursive:
        if o.type in ('MESH','CURVE'):
            o.hide_render=not o.name.startswith('Captive wisp flame')


def bolt_build():
    s=b.setup(64/(256/5.1),64,0)
    s.render.resolution_x=128;s.render.resolution_y=64
    root=c.empty('C7D_WISP_BOLT');plane=c.empty('Bolt camera plane',parent=root)
    # Construct in the camera plane: the projectile points exactly screen +x.
    basis=s.camera.rotation_euler.to_matrix()
    plane.rotation_euler=basis.to_euler()
    mint=c.material('C7D mint #9CF0C8',b.legacy.linear('9CF0C8'),0,.68,1.4)
    mint.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.006,.015,.010,1)
    fog=c.material('C7D torn mist #B8C8C0',b.legacy.linear('B8C8C0'),0,.96,.06)
    b.legacy.fade_material(fog,False,.28);b.legacy.soften_mist(fog)
    pieces=[]
    # A sharp asymmetric hollow flame and three thin, forked vapour ribbons.
    for j in range(3):
        pts=[(-.24,.015+j*.014,0),(-.10,(-1)**j*.07,.015),(.10,.025*j-.02,.025),(.30,.035,.01),(.44,.008,0)]
        o=b.twig('Stretched soul flame',pts,.043 if j==0 else .025,mint,plane);pieces.append(o)
    for j in range(4):
        sign=(-1)**j
        pts=[(.03,sign*.035,.018),(-.15,sign*(.06+j*.012),0),(-.32,sign*(.04+j*.016),-.015),(-.52,sign*(.08+j*.012),-.025)]
        o=b.twig('Ragged vapour tail',pts,.032 if j<2 else .018,fog,plane);pieces.append(o)
    rest={o:[v.co.copy() for v in o.data.vertices] for o in pieces}
    def pose(t):
        for j,o in enumerate(pieces):
            for v,p in zip(o.data.vertices,rest[o]):
                v.co=p
                weight=max(0,min(1,(.44-p.x)/.96))
                v.co.y+=.034*weight*math.sin(math.tau*t+weight*5+j*.85)
            o.scale.y=1+.08*math.sin(math.tau*t+j)
    return root,pose


def append_tres():
    path=DST/'cerf.tres';t=path.read_text(encoding='utf-8')
    if '"C7d_charge_dirs"' in t:return
    old=t;ext=[];subs=[];anims=[]
    for task,(n,w,h,fps,loop) in SPECS.items():
        eid='C7d_'+task
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/cerf/{task}.png" id="{eid}"]')
        for row,d in enumerate(DIRS if task!='wisp_bolt' else ('e',)):
            name=('charge_'+d if task=='charge_dirs' else 'antlers_charge_'+d if task=='antlers_dirs' else 'wisp_bolt')
            frames=[]
            for i in range(n):
                sid=f'C7d_{name}_{i}'
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{eid}")\nregion = Rect2({i*w}, {row*h}, {w}, {h})')
                frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
            anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(loop).lower()+', "name": &"'+name+'", "speed": '+str(float(fps))+'}')
    oldanims=old[old.index('animations = '):].rstrip()
    t=t.replace('[sub_resource','\n\n'.join(ext)+'\n\n[sub_resource',1)
    t=t.replace('[resource]','\n\n'.join(subs)+'\n\n[resource]',1)
    at=t.rfind(']');t=t[:at]+',\n'+',\n'.join(anims)+t[at:]
    t=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])+len(ext)+len(subs)),t,count=1)
    assert oldanims[:-1] in t,'Existing animations changed'
    path.write_text(t,encoding='utf-8')


def save_charge_source(snapshots):
    path=ROOT/'art/blender/monsters/cerf_iso.blend'
    bpy.ops.wm.open_mainfile(filepath=str(path))
    s=bpy.context.scene
    marker=next((m for m in s.timeline_markers if m.name=='charge_C7D_18fps'),None)
    start=marker.frame if marker else s.frame_end+3
    if not marker:s.timeline_markers.new('charge_C7D_18fps',frame=start)
    for i,frame in enumerate(snapshots):
        s.frame_set(start+i)
        for name,vals in frame.items():
            o=bpy.data.objects.get(name)
            if o is None:continue
            for key,val in vals.items():
                setattr(o,key,val);o.keyframe_insert(key,frame=start+i)
    s.frame_end=max(s.frame_end,start+5)
    s['c7d_charge_fps']=18;s['c7d_charge_frames']=6
    s['c7d_notes']='C7b unchanged; charge at marker, 18 fps; antlers use spell_b at 12 fps.'
    s.frame_set(1);bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(path))


def contact():
    tiles=[]
    for task,(n,w,h,_,_) in SPECS.items():
        sheet=Image.open(DST/(task+'.png')).convert('RGBA')
        for row in range(4 if task!='wisp_bolt' else 1):
            strip=sheet.crop((0,row*h,n*w,(row+1)*h))
            if task=='wisp_bolt':strip=strip.resize((1024,128),Image.Resampling.NEAREST)
            tiles.append(strip)
    # One final board contains both results and the approved references.
    for ref in ('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png'):
        im=Image.open(ROOT/ref).convert('RGBA');im.thumbnail((650,260));tiles.append(im)
    board=Image.new('RGBA',(2056,sum(im.height+8 for im in tiles)+8),(24,29,28,255))
    y=8
    for im in tiles:board.alpha_composite(im,(4,y));y+=im.height+8
    board.convert('RGB').save(HERE/'_c7d_contact.png',compress_level=9)


def main():
    root,base,_=b.build();snapshots=[];report={}
    for i in range(6):
        charge_pose(root,base,i)
        snapshots.append({o.name:{'location':list(o.location),'rotation_euler':list(o.rotation_euler),'scale':list(o.scale),'hide_render':o.hide_render} for o in [root,*root.children_recursive]})
    with tempfile.TemporaryDirectory(prefix='rainfall_c7d_') as tmp:
        for task,(n,w,h,fps,loop) in SPECS.items():
            if task=='wisp_bolt':root,pose=bolt_build()
            s=bpy.context.scene;s.render.resolution_x=w*2;s.render.resolution_y=h*2
            dirs=DIRS if task!='wisp_bolt' else ('s',)
            suffixes=('','_n') if task=='antlers_dirs' else ('','_n','_e')
            boards=[Image.new('RGBA',(w*n,h*len(dirs)),(0,0,0,0)) for _ in suffixes]
            boxes=[];hashes=[]
            for row,d in enumerate(dirs):
                for i in range(n):
                    path=Path(tmp)/f'{task}_{d}_{i}.png'
                    fn=pose if task=='wisp_bolt' else lambda t,i=i:charge_pose(root,base,i) if task=='charge_dirs' else lantern_pose(root,base,i)
                    c.render_still(root,fn,path,i/n,d)
                    ims=[Image.open(path.with_name(path.stem+su+'.png')).convert('RGBA').resize((w,h),Image.Resampling.LANCZOS) for su in ('','_n','_e')]
                    if task=='antlers_dirs':ims[0]=ims[2].copy()
                    alpha=ims[0].getchannel('A');box=alpha.getbbox();boxes.append(box)
                    assert box and min(box[0],box[1],w-box[2],h-box[3])>=4,(task,d,i,box)
                    hashes.append(hashlib.sha256(ims[0].tobytes()).hexdigest())
                    for j in range(len(suffixes)):
                        ims[j].putalpha(alpha);boards[j].paste(ims[j],(i*w,row*h))
            for board,su in zip(boards,suffixes):board.save(DST/(task+su+'.png'),compress_level=9)
            report[task]={'size':boards[0].size,'frames':n,'fps':fps,'loop':loop,'bounds':boxes,'unique':len(set(hashes))}
            print('C7D PASS',task,flush=True)
    append_tres();save_charge_source(snapshots);contact()
    (HERE/'_c7d_report.txt').write_text('C7D : modele, rig, matieres usees et eclairage C7b conserves. Pivot (128;179.2), 50.196 px/u.\nChoix : galop dissymetrique, encolure abaissee, ramure offensive, cages rejetees en arriere; follet effile a trois langues et quatre lambeaux de brume. Accent menthe unique.\nAntlers : poses spell_b exactes, seules les six flammes de lanternes, yeux exclus.\n9 animations ajoutees; definitions existantes conservees. 8 PNG, aucun .gd/.tscn.\n'+json.dumps(report,indent=2),encoding='utf-8')
    print('C7D COMPLETE',flush=True)


if __name__=='__main__':main()
