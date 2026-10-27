"""Drowned idol: background Eevee geometry, cel boss, no normal-map delivery.
Run in Blender to render; system Python --finish assembles the contact and audits.
"""
import sys, math, json, tempfile, re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
DST = ROOT/'game/assets/sprites/bosses/etage/drowned_idol'
SOURCE = ROOT/'art/blender/bosses/drowned_idol_iso.blend'
if '--finish' not in sys.argv:
    sys.path[:0] = [str(ROOT/p) for p in ('art/tools/bosses','art/tools/iso','art/tools/cel','art/tools/iso/_deps')] + [str(Path.home()/'AppData/Local/RainfallIsoDeps')]
from PIL import Image
BODY = {**{f'idle_p{p}':(6,True) for p in (1,2,3)}, **{f'walk_p{p}':(8,True) for p in (1,2,3)}, 'auto':(6,False),'spell_a':(8,False),'spell_b':(8,False),'shield':(8,True),'throw':(8,False),'stun':(6,True),'trans_p2':(8,False),'trans_p3':(8,False),'death':(10,False)}
EXTRA = {'bell':(96,128,8,True,False),'bell_roll':(64,64,6,False,True),'bell_return':(128,256,6,False,False),'carillon_ring':(1152,1152,8,True,True),'chaplet_circle':(256,256,6,False,True),'dike':(256,160,12,False,False),'dike_rise':(256,192,6,False,False),'noria_wheel':(512,512,8,True,True),'noria_mark':(128,128,6,False,True),'water_bubble':(288,320,8,True,False),'bubble_burst':(320,320,6,False,False),'lotus_crack':(256,256,6,True,True)}

def finish():
    import numpy as np
    from PIL import ImageStat
    frames={}; ext=[]; subs=[]; anim=[]
    def add(name, sheet, indices, loop=False, fps=12):
        refs=[]
        for box in indices:
            sid='a'+str(len(subs)); x,y,w,h=box
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{sheet}")\nregion = Rect2({x}, {y}, {w}, {h})\n')
            refs.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
        anim.append('{"frames": ['+', '.join(refs)+'], "loop": '+str(loop).lower()+', "name": &"'+name+'", "speed": '+str(float(fps))+'}')
    for task,(n,loop) in BODY.items():
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/drowned_idol/{task}.png" id="{task}"]')
        dirs=['e','s','w','n'] if task in list(BODY)[:9] else ['s']
        for row,d in enumerate(dirs):add(task+'_'+d,task,[(i*256,row*256,256,256) for i in range(n)],loop,14 if task.startswith('walk') else 12)
    for task,(w,h,n,loop,top) in EXTRA.items():
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/drowned_idol/{task}.png" id="{task}"]')
        cols=min(n,4096//w)
        boxes=[(i%cols*w,i//cols*h,w,h) for i in range(n)]
        add(task,task,boxes,loop)
        if task=='dike':
            add('dike_intact',task,boxes[:6]);add('dike_crumble',task,boxes[6:])
    (DST/'drowned_idol.tres').write_text(f'[gd_resource type="SpriteFrames" load_steps={1+len(ext)+len(subs)} format=3]\n\n'+'\n'.join(ext+subs)+'\n[resource]\nanimations = ['+',\n'.join(anim)+']\n',encoding='utf-8')
    report={}
    for p in DST.glob('*.png'):
        with Image.open(p) as im:
            assert max(im.size)<=4096,p.name
            if p.stem.endswith('_e'):
                with Image.open(p.with_stem(p.stem[:-2])) as diffuse: assert im.size==tuple((v+1)//2 for v in diffuse.size)
                a=np.asarray(im.convert('RGBA'));assert float((a[:,:,:3].max(axis=2)* (a[:,:,3]/255)).max())>2,p.name
            else:report[p.name]=list(im.size)
    assert not list(DST.glob('*_n.png'))
    for task,(n,_) in BODY.items():
        im=Image.open(DST/(task+'.png'))
        for row in range(im.height//256):
            for i in range(n):
                box=im.crop((i*256,row*256,(i+1)*256,(row+1)*256)).getbbox()
                assert box and box[0]>0 and box[1]>0 and box[2]<256 and box[3]<256,(task,row,i,box)
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    contact=Image.new('RGBA',(1280,1024),(18,27,30,255))
    for y in range(0,1024,ground.height):
        for x in range(0,1280,ground.width):contact.alpha_composite(ground,(x,y))
    selections=[('idle_p1',0,1),('idle_p2',0,1),('idle_p3',0,1),('auto',3,1),('spell_a',4,1),('spell_b',4,1),('throw',4,0),('death',9,0),('idle_p1',0,0),('idle_p1',0,2),('idle_p1',0,3),('trans_p3',7,0)]
    for k,(task,col,row) in enumerate(selections):
        im=Image.open(DST/(task+'.png')).convert('RGBA').crop((col*256,row*256,(col+1)*256,(row+1)*256))
        contact.alpha_composite(im,((k%5)*256,(k//5)*256))
    # Eclusier C7a uses 40px/u; use the idol's actual 256/5.05px/u for comparison.
    ref=Image.open(ROOT/'game/assets/sprites/bosses/etage/eclusier/idle_p1.png').convert('RGBA')
    text=(ROOT/'game/assets/sprites/bosses/etage/eclusier/eclusier.tres').read_text()
    match=re.search(r'region = Rect2\(0, 0, (\d+), (\d+)\)',text)
    rw,rh=map(int,match.groups());ref=ref.crop((0,0,rw,rh));bbox=ref.getbbox()
    ref=ref.crop(bbox);factor=(256/5.05)/40
    ref=ref.resize((round(ref.width*factor),round(ref.height*factor)),Image.Resampling.LANCZOS)
    contact.alpha_composite(ref,(3*256+(256-ref.width)//2,2*256+215-ref.height))
    for k,task in enumerate(('bell','water_bubble','carillon_ring','noria_wheel','dike')):
        w,h,*_=EXTRA[task];im=Image.open(DST/(task+'.png')).convert('RGBA').crop((0,0,w,h));im.thumbnail((240,235),Image.Resampling.LANCZOS);contact.alpha_composite(im,(k*256+(256-im.width)//2,768))
    contact.convert('RGB').save(ROOT/'art/tools/night/_raid_drowned_idol_contact.png')
    with Image.open(DST/'idle_p1.png') as im:
        im=im.crop((0,256,256,512));a=np.asarray(im);mask=a[:,:,3]>200
        mean=float(a[:,:,:3][mask].mean());assert mean>=90,mean
        report['body_mean_255']=round(mean,2);report['body_bounds']=im.getbbox()
    print('PASS',len(report)-2,'diffuse sheets; body mean',report['body_mean_255'],'bounds',report['body_bounds'])

if '--finish' in sys.argv:
    finish();sys.exit()

import bpy
from mathutils import Vector
import boss_common as c
import iso_rig
import cel_style as cel

def mat(name,hexcode,emission=0):
    rgb=[int(hexcode[i:i+2],16)/255 for i in (0,2,4)]
    rgb=[v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    return c.material(name,rgb,emission=emission)

def stone(n,loc,size,m,parent):
    o=c.box(n,loc,size,m,parent,.045)
    for mod in o.modifiers:
        if mod.type=='BEVEL':mod.segments=1
    return o

def mesh(n,verts,faces,m,parent):
    data=bpy.data.meshes.new(n);data.from_pydata(verts,[],faces);data.update();o=bpy.data.objects.new(n,data);bpy.context.collection.objects.link(o);o.parent=parent;o.data.materials.append(m);return o

def lathe(n,profile,m,parent,loc=(0,0,0),segments=16):
    verts=[(r*math.cos(j*math.tau/segments),r*math.sin(j*math.tau/segments),z) for r,z in profile for j in range(segments)]
    faces=[(k*segments+j,k*segments+(j+1)%segments,(k+1)*segments+(j+1)%segments,(k+1)*segments+j) for k in range(len(profile)-1) for j in range(segments)]
    o=mesh(n,verts,faces,m,parent);o.location=loc;return o

def bell(parent,loc,scale=1,glow=False):
    r=c.empty('Suspended votive bell',loc,parent);r.scale=(scale,)*3
    lathe('Hollow flared bronze',[(.07,.59),(.16,.54),(.21,.35),(.23,.16),(.34,.04),(.34,0),(.28,.02),(.18,.18),(.16,.43)],bronze,r)
    for z,rad in ((.05,.33),(.17,.235),(.46,.18)):c.ring('Verdigris cast band',(0,0,z),rad,.018,patina,r,(0,0,0))
    c.rod('Clapper',(0,0,.06),(0,0,.36),.035,bronze,r)
    c.ring('Suspension loop',(0,0,.64),.065,.022,bronze,r)
    for j in range(5):
        a=j*math.tau/5;c.rod('Incised prayer',(math.cos(a)*.215,math.sin(a)*.215,.2),(math.cos(a)*.19,math.sin(a)*.19,.37),.012,patina,r)
    c.tube('Split casting',[(.22,-.20,.02),(.17,-.17,.18),(.18,-.12,.26)],.014,dark,r)
    if glow:c.ring('Cyan water at bell foot',(0,0,.025),.37,.022,water,r,(0,0,0))
    return r

def lotus(root,cracked=False):
    lathe('Lotus plinth',[(.94,.12),(1.12,.22),(.96,.38),(.67,.48),(0,.48)],stone_light,root)
    for j in range(10):
        a=j*math.tau/10;ra=1.23;side=.28
        pts=[(.57,-side,.3),(.9,-side,.14),(ra,0,.25),(.9,side,.14),(.57,side,.3),(.82,0,.55)]
        verts=[(x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a),z) for x,y,z in pts]
        mesh('Cut lotus petal',verts,[(0,1,2,5),(2,3,4,5),(0,5,4),(0,4,3,2,1)],stone_light if j%3 else stone_mid,root)
    if cracked:
        for j in range(7):
            a=j*math.tau/7;c.tube('Petrified lotus root',[(.7*math.cos(a),.7*math.sin(a),.32),(1.15*math.cos(a),1.15*math.sin(a),.15),(1.55*math.cos(a+.13),1.55*math.sin(a+.13),.03)],.065,stone_mid,root)

def scene(size=(256,256),top=False):
    s=iso_rig.create_rig('TOP' if top else 'CREA',size)
    s.camera.data.ortho_scale=size[0]/64 if top else size[0]/64
    s.camera.data.sensor_fit='HORIZONTAL'
    s.eevee.taa_render_samples=8;s.render.image_settings.compression=30
    s.render.film_transparent=True;s.render.use_file_extension=True
    cel.install('boss',normals=False)
    return s

def materials():
    global stone_light,stone_mid,dark,moss,bronze,patina,leather,water
    stone_light=mat('Weathered pale ash stone','8A9A92');stone_mid=mat('Wet stone facets','677B75');dark=mat('Deep seams','344B49');moss=mat('Moss and lichen','697F54');bronze=mat('Votive bronze','8C7A4C');patina=mat('Ancient verdigris','5F8F80');leather=mat('Rotten leather','655443');water=mat('Tears #5EC8FF','5EC8FF',1.8)

def build():
    s=scene();materials();root=c.empty('Drowned idol - no legs');lotus(root)
    body=c.empty('Kneeling hollow reliquary',(0,0,0),root)
    # A negative space chest, never a filled sphere: separated bowed side stones.
    for sign in (-1,1):
        o=stone('Side of hollow rib cage',(sign*.47,0,1.94),(.32,.66,1.3),stone_mid,body);o.rotation_euler.y=sign*-.14
        stone('Broken collar',(sign*.29,0,2.57),(.52,.59,.23),stone_light,body)
        stone('Kneeling folded robe',(sign*.47,.05,.74),(.79,.98,.55),stone_mid,body)
        for j in range(3):
            o=stone('Angular robe pleat',(sign*(.18+j*.19),-.49,.7),(.09,.15,.48),stone_light,body);o.rotation_euler.y=sign*.2
    stone('Lower chest sill',(0,0,1.34),(.95,.62,.25),stone_light,body)
    stone('Back slab',(0,.34,2.0),(.98,.22,1.16),stone_mid,body)
    c.rod('Neck',(0,.02,2.6),(0,.02,2.96),.19,stone_mid,body)
    head=c.empty('Faceless funeral head',(0,-.015,3.02),body)
    lathe('Smooth featureless mask',[(.18,-.29),(.32,-.12),(.38,.22),(.30,.49),(.14,.57),(0,.59)],stone_light,head,segments=12)
    tears=[]
    for x in (-.16,.16):
        stone('Empty orbit',(x,-.331,.12),(.12,.045,.075),dark,head)
        t=c.tube('Streaming cyan tears',[(x,-.357,.10),(x*.92,-.365,-.12),(x*.8,-.28,-.38),(x*.9,-.32,-.63)],.021,water,head);tears.append(t)
    wheel=c.empty('Exposed prayer wheel',(0,-.03,2.0),body)
    c.ring('Bronze prayer wheel rim',(0,0,0),.47,.065,bronze,wheel)
    c.ring('Verdigris inner wheel',(0,-.018,0),.36,.025,patina,wheel)
    for j in range(8):
        a=j*math.tau/8;c.rod('Prayer wheel spoke',(0,0,0),(.43*math.sin(a),0,.43*math.cos(a)),.025,bronze,wheel)
        stone('Inscribed prayer tablet',(.40*math.sin(a),-.045,.40*math.cos(a)),(.09,.065,.12),patina,wheel)
    c.rod('Wheel central axle',(0,-.16,0),(0,.23,0),.075,bronze,wheel)
    arms=[];hands=[];straps=[];bells=[]
    for sign in (-1,1):
        arm=c.empty('Offering arm', (sign*.70,0,2.42),body);arms.append(arm)
        stone('Shoulder capital',(0,0,0),(.45,.53,.48),stone_light,arm)
        c.rod('Upper arm',(0,0,-.06),(sign*.15,-.14,-.59),.18,stone_mid,arm)
        c.rod('Offering forearm',(sign*.15,-.14,-.59),(-sign*.45,-.63,-.45),.16,stone_light,arm)
        hand=c.empty('Joined stone palm',(-sign*.47,-.64,-.39),arm);hands.append(hand)
        stone('Broad palm',(0,0,0),(.23,.21,.39),stone_light,hand)
        for j in range(4):stone('Angular joined finger',(sign*(j-1.5)*.046,-.055,.18),(.037,.14,.21),stone_light,hand)
        c.tube('Frayed shoulder strap',[(0,.1,.18),(0,-.23,.18),(sign*.12,-.25,-.42)],.045,leather,arm)
        b=bell(arm,(sign*.15,-.29,-.99),.75 if sign==1 else 1.0);bells.append(b)
        for j in range(3):c.tube('Rotten rope',[(sign*.13+j*.025,-.25,-.4),(sign*.15+j*.018,-.28,-.53),(sign*.16+j*.02,-.25,-.62)],.012,leather,arm)
    bells.append(bell(body,(0,.48,1.96),.62))
    c.tube('Nape strap',[(0,.1,2.8),(0,.51,2.7),(0,.49,2.38)],.043,leather,body)
    pool=c.sphere('Offering water',(0,-.76,2.03),(.23,.17,.055),water,body)
    # Angular lichen embedded as geometry, deterministic, no texture noise.
    for j in range(28):
        sign=1 if j%2 else -1;x=sign*(.4+(j%4)*.045);z=.48+(j%11)*.20
        o=stone('Lichen crust',(x,-.36,z),(.09+(j%3)*.03,.025,.045),moss,body);o.rotation_euler.y=j*.71
    roots=c.empty('P3 lotus roots',(0,0,.28),root);lotus(roots,True);roots.scale=(.8,.8,1)
    # Only the root curves of the P3 assembly remain; original plinth splits instead.
    for o in list(roots.children):
        if not o.name.startswith('Petrified'):bpy.data.objects.remove(o,do_unlink=True)
    for j in range(5):
        a=j*math.tau/5+.13
        c.tube('Split in lotus',[(.25*math.cos(a),.25*math.sin(a),.49),(.55*math.cos(a+.07),.55*math.sin(a+.07),.50),(.91*math.cos(a),.91*math.sin(a),.35),(1.17*math.cos(a+.07),1.17*math.sin(a+.07),.26)],.018,dark,roots)
    wake=c.empty('Sliding wake',(0,0,.04),root)
    for r in (1.05,1.35):
        c.tube('Trailing wake',[(-r,.25,.02),(-r*.75,.75,.02),(0,1.0,.02),(r*.75,.75,.02),(r,.25,.02)],.018,patina,wake)
    shield=c.empty('Shield water silhouette',(0,0,0),root)
    for a in (0,math.pi/2):
        c.tube('Thin shield meridian',[(1.45*math.cos(k*math.tau/64)*math.cos(a),1.45*math.cos(k*math.tau/64)*math.sin(a),1.8+1.8*math.sin(k*math.tau/64)) for k in range(65)],.018,water,shield)
    base={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def pose(task,i,n):
        for o,(loc,rot,scale) in base.items():o.location=loc;o.rotation_euler=rot;o.scale=scale;o.hide_render=False
        p=3 if 'p3' in task else 2 if ('p2' in task or task=='stun') else 1
        if task=='trans_p2' and i<4:p=1
        if task=='trans_p3' and i<4:p=2
        t=i/max(1,n-1);wave=math.sin(math.tau*i/n)
        root.location=(0,0,0);root.rotation_euler=(0,0,0)
        body.location.z=.028*wave
        wheel.rotation_euler.y=(0 if task=='stun' else i*(.19 if p==1 else .73))
        for b in bells:
            b.hide_render=p>1
            for o in b.children_recursive:o.hide_render=p>1
            b.rotation_euler.y=.09*wave
        for o in roots.children_recursive:o.hide_render=p<3
        for o in wake.children_recursive:o.hide_render=not task.startswith('walk')
        for o in shield.children_recursive:o.hide_render=task!='shield'
        for tear in tears:tear.scale.x=1 if p==1 else 1.65
        if p==3:
            for o in body.children:
                if o.name.startswith(('Side of','Broken collar')):o.location.x*=1.3;o.rotation_euler.y+=.18 if o.location.x>0 else -.18
        if task.startswith('walk'):body.rotation_euler.y=.025*wave;wake.scale.x=1+.08*wave
        hit=max(0,1-abs(i-(3 if task=='auto' else 4))/3)
        if task in ('auto','spell_b','throw'):
            for sign,arm in zip((-1,1),arms):
                arm.rotation_euler.z=sign*hit*(.95 if task!='auto' else .5)
                arm.rotation_euler.x=-hit*(.55 if task=='auto' else .2)
            pool.scale=base[pool][2]*(1+hit*.65)
        if task=='spell_a':wheel.rotation_euler.y=i*1.4;body.rotation_euler.x=-.06*hit
        if task=='throw':
            for j,b in enumerate(bells):b.location.x+=((j-1)*.9)*hit;b.location.z+=.45*hit
        if task=='stun':body.rotation_euler.x=.16;head.rotation_euler.x=.2;pool.hide_render=True
        if task=='shield':pool.scale=base[pool][2]*1.4;wheel.rotation_euler.y=i*.12
        if task=='death':
            body.scale.z=1-.82*t;body.rotation_euler.x=.24*t;wheel.rotation_euler.y=min(i,5)*.22
            for o in [pool]+tears:o.hide_render=i==n-1
        if task.startswith('trans'):
            body.rotation_euler.x=.12*math.sin(math.pi*t)
    # Feet placement: measured geometry through the contractual camera basis.
    pose('idle_p1',0,6)
    bpy.context.view_layer.update();inv=s.camera.rotation_euler.to_matrix().transposed()
    deps=bpy.context.evaluated_depsgraph_get();lows=[]
    for ob in root.children_recursive:
        if ob.hide_render or ob.type not in ('MESH','CURVE'):continue
        ev=ob.evaluated_get(deps);data=ev.to_mesh()
        lows.extend((inv@(ev.matrix_world@v.co)).y for v in data.vertices);ev.to_mesh_clear()
    low=min(lows)
    s.camera.data.ortho_scale=5.05
    target_y=low+(215-128)*5.05/256
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,target_y,0))
    s['body_bottom']=215;s['body_dimension']=190;s['body_cell']=[256,256]
    return root,pose

def extra(task):
    w,h,n,loop,top=EXTRA[task];s=scene((w,h),top);materials();r=c.empty(task)
    if top:s.camera.location=(0,0,12)
    else:
        # Billboard ground at bottom; centre tall water effects in the frame.
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,h/128-.12,0))
    movers=[]
    if task in ('bell','bell_roll'):
        b=bell(r,(0,0,.04),1.15 if task=='bell' else .9,True);movers=[b]
    elif task in ('carillon_ring','chaplet_circle','noria_mark'):
        rad=8.3359375 if task=='carillon_ring' else 1 if task=='chaplet_circle' else .7
        thick=.265625 if task=='carillon_ring' else .035
        for j in range(3):c.ring('Rippling votive water',(0,0,.025+j*.008),rad+j*thick,thick*.5,water if j!=1 else patina,r,(0,0,0))
        for j in range(24 if task=='carillon_ring' else 12):
            a=j*math.tau/(24 if task=='carillon_ring' else 12)
            c.tube('Broken radial foam',[(rad*math.cos(a),rad*math.sin(a),.05),((rad-thick*1.5)*math.cos(a+.025),(rad-thick*1.5)*math.sin(a+.025),.06)],thick*.27,water,r)
    elif task=='noria_wheel':
        # Gameplay rotates around the centre of the cell; blade points to +x.
        hub=c.empty('Fixed spindle',(0,0,0),r)
        for rad in (.23,.4):c.ring('Noria central wheel',(0,0,.05),rad,.045,bronze,hub,(0,0,0))
        stone('Water paddle',(1.9,0,.04),(3.8,.65,.08),patina,hub)
        for j in range(16):stone('Water paddle rib',(j*.235+.1,0,.13),(.035,.95,.09),water if j%3==0 else bronze,hub)
        c.tube('Paddle luminous lip',[(.0,-.48,.08),(3.8,-.48,.08)],.03,water,hub)
    elif task in ('dike','dike_rise'):
        for j in range(13):
            x=(j%7-3)*.51;z=.28+(j//7)*.36
            stone('Rammed earth block',(x,(j%3-1)*.1,z),(.55,.65,.40),stone_mid if j%2 else moss,r)
        for j in range(5):c.tube('Rotten binding root',[(-1.7+j*.8,-.36,.04),(-1.55+j*.8,-.39,.4),(-1.7+j*.8,-.3,.72)],.026,leather,r)
    elif task=='lotus_crack':lotus(r,True)
    elif task=='bell_return':
        for j in range(4):
            c.tube('Ascending water ribbon',[(.12*math.sin(k+j),.06*math.cos(k),k*.25) for k in range(14)],.022+(j%2)*.012,water,r)
        bell(r,(0,0,.12),.7,True)
    elif task in ('water_bubble','bubble_burst'):
        # Open geometry reveals the boss; water is thin arcs, never an opaque ball.
        for j in range(7):
            a=j*math.pi/7
            pts=[(1.8*math.cos(k*math.pi/32)*math.cos(a),1.8*math.cos(k*math.pi/32)*math.sin(a),2.1+1.93*math.sin(k*math.pi/32)) for k in range(65)]
            c.tube('Shield meridian',pts,.018 if j%2 else .028,water,r)
        for z,rad in ((.45,1.0),(1.0,1.5),(2.1,1.8),(3.1,1.5),(3.75,1.0)):
            c.ring('Shield latitude',(0,0,z),rad,.025,water,r,(0,0,0))
        for j in range(16):
            a=j*2.4;c.sphere('Water droplet',(math.cos(a)*1.65,math.sin(a)*1.65,1+(j%6)*.45),(.045,.045,.11),water,r)
    if not top:
        bpy.context.view_layer.update();inv=s.camera.rotation_euler.to_matrix().transposed()
        deps=bpy.context.evaluated_depsgraph_get();lows=[]
        for ob in r.children_recursive:
            if ob.type not in ('MESH','CURVE'):continue
            ev=ob.evaluated_get(deps);data=ev.to_mesh()
            lows.extend((inv@(ev.matrix_world@v.co)).y for v in data.vertices)
            ev.to_mesh_clear()
        desired=min(lows)+(h/2-3)/64
        s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,desired,12))
    base={o:(o.location.copy(),o.scale.copy()) for o in r.children_recursive}
    def pose(i):
        t=i/max(n-1,1);wave=math.sin(math.tau*i/n)
        r.rotation_euler=(0,0,0);r.scale=(1,1,1);r.location=(0,0,0)
        for o,(loc,scale) in base.items():o.location=loc;o.scale=scale;o.hide_render=False
        if task=='bell':
            movers[0].rotation_euler.y=.045*wave
            for o in movers[0].children_recursive:
                if o.name.startswith('Cyan water'):o.scale=(1+.12*wave,1+.12*wave,1)
        if task=='bell_roll':
            movers[0].rotation_euler.y=t*math.tau
            movers[0].location.x=-.28*math.sin(t*math.tau)
        if task=='bell_return':r.location.z=t*.35
        if task in ('carillon_ring','chaplet_circle','noria_mark'):r.rotation_euler.z=i*.035;r.scale=(1+.012*wave,1+.012*wave,1)
        if task=='noria_wheel':
            # Sweep is owned by gameplay; animate the water coursing along the paddle.
            for j,o in enumerate(r.children_recursive):
                if o.name.startswith('Water paddle rib'):o.scale.z=1+.4*math.sin(i*.9+j)
        if task=='dike_rise':r.scale.z=.12+.88*t
        if task=='dike' and i>=6:
            for j,o in enumerate(r.children_recursive):o.location.x+=(j%3-1)*.12*(i-5);o.location.z-=.08*(i-5);o.scale.z=max(.15,1-.12*(i-5))
        if task=='water_bubble':r.scale=(1+.025*wave,1+.025*wave,1+.015*wave)
        if task=='bubble_burst':
            r.scale=(.85+t*.3,)*3
            for j,o in enumerate(r.children_recursive):o.hide_render=(j+i)%7<i
        if task=='lotus_crack':
            for j,o in enumerate(r.children_recursive):
                if o.name.startswith('Petrified'):o.scale.z=1+.05*wave
    return r,pose

def render_frame(path,size):
    s=bpy.context.scene;c.configure_passes(path);s.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    result=[]
    for suffix in ('','_e'):
        p=path if not suffix else next(path.parent.glob(path.stem+'_e__*.png'))
        with Image.open(p) as im:result.append(im.convert('RGBA').resize(size,Image.Resampling.LANCZOS))
        p.unlink()
    return result

def run():
    DST.mkdir(parents=True,exist_ok=True);SOURCE.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    root,pose=build();pose('idle_p1',0,6)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    only=sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else None
    import numpy as np
    with tempfile.TemporaryDirectory(prefix='rainfall_idol_') as tmp:
        tmp=Path(tmp)
        for task in list(BODY)+list(EXTRA):
            if only and task not in only:continue
            if '--resume' in sys.argv and (DST/(task+'.png')).exists():continue
            if task in BODY:
                n,loop=BODY[task];w=h=256;dirs=['e','s','w','n'] if task in list(BODY)[:9] else ['s'];cols=n
            else:
                root,epose=extra(task);w,h,n,loop,top=EXTRA[task];dirs=['s'];cols=min(n,4096//w)
            rows=len(dirs) if task in BODY else math.ceil(n/cols)
            boards=[Image.new('RGBA',(cols*w,rows*h)) for _ in range(2)]
            for row,d in enumerate(dirs):
                for i in range(n):
                    if task in BODY:pose(task,i,n);root.rotation_euler.z=c.DIRECTIONS[d]
                    else:epose(i)
                    bpy.context.view_layer.update()
                    images=render_frame(tmp/'frame.png',(w,h))
                    for k,im in enumerate(images):boards[k].paste(im,((i%cols)*w,(row if task in BODY else i//cols)*h))
            boards[0].save(DST/(task+'.png'),compress_level=9)
            emission=np.asarray(boards[1]);peak=float((emission[:,:,:3].max(axis=2)*(emission[:,:,3]/255)).max())
            if peak>2:
                # Shared emission downsampler preserves thin cyan accents.
                sys.path.insert(0,str(ROOT/'art/tools'));from halve_emission import downscale
                downscale(boards[1]).save(DST/(task+'_e.png'),compress_level=9)
            print('IDOL DONE',task,flush=True)
    print('IDOL RENDER PASS',flush=True)

if __name__=='__main__':run()
