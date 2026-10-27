"""RAID_FLOOD_GUNNER: background Eevee, contractual atlases, no normal maps.
Blender --background --python this_file [-- --resume]; Python this_file --finish.
Shared geometry/render pipeline: raid_drowned_idol_build.py, cel_style boss.
"""
import sys, math, tempfile, json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
DST=ROOT/'game/assets/sprites/bosses/etage/flood_gunner'
SOURCE=ROOT/'art/blender/bosses/flood_gunner_iso.blend'
BODY={**{f'idle_p{p}':(6,True) for p in (1,2,3)},**{f'walk_p{p}':(8,True) for p in (1,2)},'walk_p3':(6,True),'auto':(6,False),'spell_a':(8,False),'spell_b':(8,False),'volley_loop':(6,True),'shell':(8,False),'shield':(8,True),'vent':(8,True),'trans_p2':(8,False),'trans_p3':(8,False),'death':(10,False)}
EXTRA={'pylon_ok':(128,224,6,True,False),'pylon_cracked':(128,224,6,True,False),'pylon_broken':(128,224,6,True,False),'pylon_drop':(128,320,6,False,False),'shelter_shadow':(128,384,6,True,True),'rivet':(48,24,4,True,True),'rivet_hit':(64,64,4,False,True),'volley_cone':(1024,1024,8,True,True),'shell':(128,384,6,False,False),'shell_crater':(384,384,6,False,True),'coal_mouth':(160,160,6,True,False),'stoker_idle_s':(128,160,6,True,False),**{f'stoker_walk_{d}':(128,160,8,True,False) for d in 'eswn'},'stoker_death_s':(128,160,8,False,False),'steam_vent':(256,320,8,True,False),'reload_smoke':(192,256,6,True,False)}
# Separate shell_s body atlas and shell extra; all other body names lack the direction suffix on disk.
def sheet(task,body=False):
    if body and task=='shell':return 'shell_s'
    # Direction suffixes must not collide with emission/normal file conventions.
    return {'stoker_walk_e':'stoker_walk_east','stoker_walk_n':'stoker_walk_north'}.get(task,task)
def directions(task):return list('eswn') if task in list(BODY)[:10] else ['s']

def finish():
    from PIL import Image
    import numpy as np
    ext=[];subs=[];anims=[]
    def add(name,key,boxes,loop,fps=12):
        refs=[]
        for x,y,w,h in boxes:
            sid='a'+str(len(subs));subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{key}")\nregion = Rect2({x}, {y}, {w}, {h})\n');refs.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
        anims.append('{"frames": ['+', '.join(refs)+'], "loop": '+str(loop).lower()+', "name": &"'+name+'", "speed": '+str(float(fps))+'}')
    for task,(n,loop) in BODY.items():
        key=sheet(task,True);ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/flood_gunner/{key}.png" id="{key}"]')
        for row,d in enumerate(directions(task)):add(task+'_'+d,key,[(i*256,row*256,256,256) for i in range(n)],loop,14 if task.startswith('walk') else 12)
    for task,(w,h,n,loop,top) in EXTRA.items():
        key=sheet(task);ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/flood_gunner/{key}.png" id="{key}"]');cols=min(n,4096//w)
        add(task,key,[(i%cols*w,i//cols*h,w,h) for i in range(n)],loop)
    (DST/'flood_gunner.tres').write_text(f'[gd_resource type="SpriteFrames" load_steps={1+len(ext)+len(subs)} format=3]\n\n'+'\n'.join(ext+subs)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n',encoding='utf-8')
    for p in DST.glob('*.png'):
        with Image.open(p) as im:
            assert max(im.size)<=4096,p.name
            if p.stem.endswith('_e') and p.with_stem(p.stem[:-2]).exists():
                with Image.open(p.with_stem(p.stem[:-2])) as d:assert im.size==tuple((v+1)//2 for v in d.size),p.name
                a=np.asarray(im.convert('RGBA'));assert (a[:,:,:3].max(axis=2)*(a[:,:,3]/255)).max()>2,p.name
    assert not list(DST.glob('*_n.png'))
    for task,(n,_) in BODY.items():
        with Image.open(DST/(sheet(task,True)+'.png')) as im:
            for row in range(len(directions(task))):
                for i in range(n):
                    box=im.crop((i*256,row*256,(i+1)*256,(row+1)*256)).getbbox();assert box and min(box[:2])>0 and max(box[2:])<256,(task,row,i,box)
    im=Image.open(DST/'idle_p1.png').convert('RGBA');a=np.asarray(im);mask=a[:,:,3]>200;mean=float(a[:,:,:3][mask].mean());assert mean>=90,mean
    ground=Image.open(ROOT/'game/assets/sprites/terrain/rust_city/ground_concrete.png').convert('RGBA');contact=Image.new('RGBA',(1536,1024),(27,29,33,255))
    for y in range(0,1024,ground.height):
        for x in range(0,1536,ground.width):contact.alpha_composite(ground,(x,y))
    choices=[('idle_p1',0,1),('idle_p2',0,1),('idle_p3',0,1),('auto',3,1),('spell_a',4,1),('spell_b',4,1),('idle_p1',0,0),('idle_p1',0,2),('idle_p1',0,3),('shell_s',4,0),('trans_p3',7,0),('death',9,0)]
    for k,(task,i,row) in enumerate(choices):
        cell=Image.open(DST/(task+'.png')).convert('RGBA').crop((i*256,row*256,(i+1)*256,(row+1)*256));contact.alpha_composite(cell,(k%6*256,k//6*256))
    # Sonneur's delivered atlas is packed. Read its real cell, then use the same
    # in-game collision scale (dim 190 for Sonneur, 195 for the Canonnier).
    with (ROOT/'game/assets/sprites/bosses/etage/sonneur/sonneur.tres').open() as f:
        for line in f:
            match=re.search(r'region = Rect2\(0, 0, (\d+), (\d+)\)',line)
            if match:rw,rh=map(int,match.groups());break
    refpath=ROOT/'game/assets/sprites/bosses/etage/sonneur/idle_p1.png';ref=Image.open(refpath).convert('RGBA').crop((0,0,rw,rh));ref=ref.crop(ref.getbbox());factor=195/190;ref=ref.resize((round(ref.width*factor),round(ref.height*factor)),Image.Resampling.LANCZOS);contact.alpha_composite(ref,((256-ref.width)//2,512+215-ref.height))
    for k,task in enumerate(('pylon_ok','pylon_cracked','pylon_broken','coal_mouth','stoker_idle_s')):
        w,h,*_=EXTRA[task];cell=Image.open(DST/(task+'.png')).convert('RGBA').crop((0,0,w,h));contact.alpha_composite(cell,((k+1)*256+(256-w)//2,512+235-h))
    for k,task in enumerate(('volley_cone','shell_crater','shell','pylon_drop','steam_vent','reload_smoke')):
        w,h,*_=EXTRA[task];cell=Image.open(DST/(task+'.png')).convert('RGBA').crop((0,0,w,h));cell.thumbnail((248,248),Image.Resampling.LANCZOS);contact.alpha_composite(cell,(k*256+(256-cell.width)//2,768+250-cell.height))
    contact.convert('RGB').save(ROOT/'art/tools/night/_raid_flood_gunner_contact.png')
    print('PASS',len(anims),'animations;',len(list(DST.glob('*.png'))),'PNG; mean',round(mean,2))

if '--finish' in sys.argv:finish();sys.exit()
sys.path.insert(0,str(Path(__file__).resolve().parent))
import raid_drowned_idol_build as shared
import bpy
from mathutils import Vector
c=shared.c;cel=shared.cel;mat=shared.mat;block=shared.stone;mesh=shared.mesh;lathe=shared.lathe

def materials():
    global rust,iron,brass,edge,soot,glow,steam,cyan,red
    rust=mat('Oxide #6B3A22','6B3A22');iron=mat('Forged iron #2B2A29','2B2A29');brass=mat('Scuffed brass #A8946E','A8946E');edge=mat('Cold exposed steel','9BA8AD');soot=mat('Furnace shadow','353734');glow=mat('Sodium #FF9A3C','FF9A3C',1.4);steam=mat('Condensed grey vapour','9BA8AD');cyan=mat('Protected cyan ground','5A9DA8');red=mat('Danger red ground','A94C3C')
    # Preserve oxide hue, lift exposed albedo for the real nocturnal city floor.
    for m,floor in ((rust,.28),(iron,.17),(brass,.40)):
        p=m.node_tree.nodes.get('Principled BSDF');rgb=list(p.inputs['Base Color'].default_value[:3]);luma=sum(v*k for v,k in zip(rgb,(.2126,.7152,.0722)));rgb=[min(.72,v*max(1,floor/luma)) for v in rgb];p.inputs['Base Color'].default_value=(*rgb,1);m.diffuse_color=(*rgb,1)
    for m,alpha in ((steam,.28),(cyan,.32),(red,.3)):
        m.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=alpha;m.surface_render_method='DITHERED'

def cylinder(n,loc,r,depth,m,parent,axis=(0,0,1)):
    v=Vector(axis).normalized()*depth/2;return c.rod(n,Vector(loc)-v,Vector(loc)+v,r,m,parent)

def pylon(root,loc=(0,0,0),state=0,scale=1):
    p=c.empty('Lightning conductor',loc,root);p.scale=(scale,)*3
    h=.48 if state==2 else 1.0
    cylinder('Socket', (0,0,.10),.19,.20,iron,p);block('Anchor fins',(0,0,.09),(.48,.32,.10),rust,p)
    cylinder('Copper conductor',(0,0,h/2),.055,h,brass,p)
    for z in (.30,.52,.73):
        if z<h:lathe('Insulator',[(.05,z-.05),(.13,z),(.06,z+.045)],iron,p,segments=8)
    block('Sodium cap',(0,0,h),(.15,.14,.12),glow,p)
    for x in (-1,1):c.rod('Fork lightning prong',(0,0,h),(x*.14,0,h+.19),.024,edge,p)
    if state:
        for z in (.22,.39):c.rod('Split conductor',(-.10,-.06,z),(.10,-.07,z+.06),.025,soot,p)
    return p

def vapour(root,loc,height=1,width=.35,name='Leaking steam'):
    r=c.empty(name,loc,root)
    for j in range(4):
        verts=[]
        for k in range(7):
            t=k/6;v=width*(.15+.85*t)*math.sin(math.pi*t)**.7;cx=width*.3*math.sin(t*7+j)
            verts.extend([(cx-v,0,t*height),(cx+v,.02,t*height)])
        ob=mesh(name,verts,[(k*2,k*2+1,k*2+3,k*2+2) for k in range(6)],steam,r);ob.rotation_euler.z=j*math.pi/4
    return r

def build():
    s=shared.scene();materials();root=c.empty('FLOOD GUNNER 3.7u');root['height_u']=3.7
    bpy.ops.object.light_add(type='AREA',location=(-4,1.5,5.5));rim=bpy.context.object;rim.name='Cold upper-left iron rim';rim.data.energy=275;rim.data.color=(.48,.69,1);rim.data.shape='DISK';rim.data.size=2;rim.rotation_euler=(Vector((0,0,1.8))-rim.location).to_track_quat('-Z','Y').to_euler()
    body=c.empty('Suspended artillery torso',(0,0,1.95),root)
    legs=[]
    for j,a in enumerate((-math.pi/2,math.pi/6,5*math.pi/6)):
        leg=c.empty('Hydraulic leg '+str(j),parent=root);legs.append(leg)
        hip=(.58*math.cos(a),.58*math.sin(a),1.85);knee=(1.05*math.cos(a),1.05*math.sin(a),.94);foot=(1.24*math.cos(a),1.24*math.sin(a),.14)
        c.rod('Armoured upper ram',hip,knee,.14,rust,leg);c.rod('Bright hydraulic piston',knee,foot,.085,edge,leg);c.rod('Ram jacket',Vector(knee)*.7+Vector(foot)*.3,foot,.13,iron,leg)
        cylinder('Knuckle',knee,.20,.24,brass,leg,(-math.sin(a),math.cos(a),0));block('Planted stabiliser',foot,(.63,.49,.20),iron,leg)
        for k in (-1,1):c.rod('Gripping talon',(foot[0]+k*.15,foot[1],.17),(foot[0]+k*.24,foot[1]-.27,.035),.055,edge,leg)
    cylinder('Rivet drum core',(0,0,.15),.69,.94,iron,body,(0,1,0));drum=c.empty('Rotating exposed rivet cylinder',(0,-.02,.15),body)
    for j in range(10):
        a=j*math.tau/10;x,z=.62*math.sin(a),.62*math.cos(a)
        cylinder('Rivet cartridge',(x,0,z),.115,.99,brass if j%3 else edge,drum,(0,1,0));cylinder('Heavy rivet head',(x,-.53,z),.14,.075,iron,drum,(0,1,0))
    plates=[]
    for side in (-1,1):
        gate=c.empty('Opening armour leaf',(side*.68,-.03,.18),body);plates.append(gate)
        block('Salvaged rust armour',(0,-.10,0),(.22,1.12,1.30),rust,gate)
        for z in (-.46,.38):block('Riveted brass strap',(side*.12,-.10,z),(.045,1.12,.08),brass,gate)
        for z in (-.42,.05,.46):
            for y in (-.50,.33):cylinder('Armour rivet',(side*.14,y,z),.045,.04,edge,gate,(1,0,0))
        for k in range(3):block('Oxide run',(side*.125,-.37+k*.24,-.15),(.02,.045,.43-k*.06),iron,gate)
    furnace=glow.copy();furnace.name='Sodium furnace, white hot in phase 3'
    boiler=c.empty('Vertical boiler and stoker hatch',(0,.62,.02),body)
    lathe('Riveted vertical pressure boiler',[(.36,-.66),(.45,-.51),(.45,.79),(.29,.95)],rust,boiler)
    for z in (-.40,.61):c.ring('Boiler hoop',(0,0,z),.46,.055,brass,boiler,rotation=(0,0,0))
    block('Rear stoker hatch',(0,.41,-.15),(.58,.13,.57),iron,boiler);block('Rear furnace slit',(0,.49,-.15),(.34,.025,.20),furnace,boiler)
    block('Visible furnace cavity',(0,-.05,.14),(.61,.35,.72),soot,body)
    for j in range(4):block('Sodium fire grate',((j-1.5)*.12,-.26,.14),(.055,.06,.55),furnace,body)
    cylinder('Smokestack',(.23,.70,1.12),.115,.71,iron,body);cylinder('Chimney lip',(.23,.70,1.47),.16,.09,brass,body)
    gun=c.empty('Elevating short cannon',(0,-.30,.30),body)
    cylinder('Short cannon breech',(0,-.35,0),.30,.76,iron,gun,(0,1,0));cylinder('Brass muzzle',(0,-.76,0),.34,.19,brass,gun,(0,1,0));cylinder('Deep hollow muzzle',(0,-.87,0),.235,.025,soot,gun,(0,1,0))
    block('Lamp armoured brow',(0,-.24,1.03),(.64,.55,.35),iron,body)
    cylinder('Single sodium eye',(0,-.54,1.02),.17,.07,glow,body,(0,1,0));block('Lamp visor',(0,-.52,1.23),(.77,.38,.09),rust,body)
    quiver=[]
    for side in (-1,1):
        block('Conductor quiver',(side*.83,.42,.44),(.29,.39,.44),iron,body)
        for j in range(2):quiver.append(pylon(body,(side*.84,.26+j*.30,.52),scale=.70))
    leak=vapour(body,(-.35,.55,.91),.43,.17)
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive};fit=1.0
    def pose(task,i,n):
        root.location=(0,0,0);root.scale=(fit,)*3;root.rotation_euler=(0,0,0)
        for o,(l,r,sc) in rest.items():o.location=l;o.rotation_euler=r;o.scale=sc;o.hide_render=False
        t=i/max(1,n-1);wave=math.sin(math.tau*i/n);phase=3 if task.endswith('p3') else 2 if task.endswith('p2') else 1
        if task in ('vent',):phase=2
        if task=='death':phase=3
        heat=22.0 if phase==3 else .9 if phase==2 else 1.4
        for node in furnace.node_tree.nodes:
            if node.type=='BSDF_PRINCIPLED':node.inputs['Emission Strength'].default_value=heat
            elif node.type=='EMISSION':node.inputs['Strength'].default_value=heat
            elif node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=(heat,heat*((154/255+.055)/1.055)**2.4,heat*((60/255+.055)/1.055)**2.4,1)
        if phase>1:
            for side,g in zip((-1,1),plates):g.rotation_euler.z=side*(.70 if phase==2 else 1.4);g.location.x+=side*.13
            for k,q in enumerate(quiver):
                for ob in [q,*q.children_recursive]:ob.hide_render=phase==3 or k%2==1
        if phase==3:
            gun.rotation_euler.x=-.68
            for leg in legs:leg.scale=(1.06,1.06,.98)
            if task in ('idle_p3','walk_p3'):
                leak.rotation_euler.z=.18*wave;leak.scale=(1+.09*wave,1+.09*wave,1+.06*math.cos(math.tau*i/n));drum.rotation_euler.y=.018*wave
        else:body.location.z+=.018*wave
        if task.startswith('walk') and task!='walk_p3':
            for j,leg in enumerate(legs):leg.location.z=max(0,math.sin(math.tau*i/n+j*math.tau/3))*.20
            body.rotation_euler.y=.035*wave
        if task in ('auto','spell_b','volley_loop'):
            drum.rotation_euler.y=(i*math.tau/n if task!='auto' else .08*wave)
            recoil=max(0,1-abs(i-(3 if n==6 else 4)))
            gun.location.y+=.22*recoil;body.rotation_euler.x=.055*recoil
        if task=='spell_a':
            q=quiver[0];q.location.z+=.45*math.sin(math.pi*t);q.rotation_euler.y=-.9*math.sin(math.pi*t)
            if i>=4:q.location.z-=.65*(i-3)
        if task in ('shell','trans_p2','trans_p3'):gun.rotation_euler.x=-.82*math.sin(math.pi*t/2);body.location.z-=.07*math.sin(math.pi*t)
        if task=='shell' and i==4:gun.location.y+=.25;body.rotation_euler.x=.07
        if task=='shield':
            for g in plates:g.rotation_euler.z=0
        if task=='vent':leak.scale=(2.8,2.8,1.8+.12*wave)
        if task=='death':
            body.location.z-=1.12*t;body.rotation_euler.y=.42*t;body.rotation_euler.x=.28*t
            for j,leg in enumerate(legs):leg.rotation_euler.y=(j-1)*.45*t;leg.scale.z=1-.45*t
            for side,g in zip((-1,1),plates):g.location.x+=side*t*.45;g.rotation_euler.y=side*t
            leak.scale=(1+t*3,)*3
    pose('idle_p1',0,6);bpy.context.view_layer.update()
    # 64px/u, fixed pivot; settle all three feet on y=215 across direction rows.
    inv=s.camera.rotation_euler.to_matrix().transposed();bounds={}
    for d in 'eswn':
        root.rotation_euler.z=c.DIRECTIONS[d];bpy.context.view_layer.update();points=[inv@(o.matrix_world@Vector(v)) for o in root.children_recursive if o.type=='MESH' for v in o.bound_box];bounds[d]=(min(v.y for v in points),max(v.y for v in points),min(v.x for v in points),max(v.x for v in points))
    fit=192/(64*max(max(b[1]-b[0],b[3]-b[2]) for b in bounds.values()));root['render_fit']=fit
    for d,b in bounds.items():root['camera_y_'+d]=b[0]*fit+87/64
    pose('idle_p1',0,6);frame_body(root,'s');s['body_bottom']=215;s['body_dimension']=195;s['pixels_per_u']=64
    return root,pose

def frame_body(root,d):
    root.rotation_euler.z=c.DIRECTIONS[d];s=bpy.context.scene;s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,root['camera_y_'+d],12))

def sodium_strength(m,strength):
    rgb=(1,((154/255+.055)/1.055)**2.4,((60/255+.055)/1.055)**2.4)
    for node in m.node_tree.nodes:
        if node.type=='BSDF_PRINCIPLED':node.inputs['Emission Strength'].default_value=strength
        elif node.type=='EMISSION':node.inputs['Strength'].default_value=strength
        elif node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=(*(v*strength for v in rgb),1)

def extra(task):
    w,h,n,loop,top=EXTRA[task];s=shared.scene((w,h),top);materials();r=c.empty(task);movers=[]
    if top:s.camera.location=(0,0,12)
    if task.startswith('pylon_'):movers=[pylon(r,state=2 if task=='pylon_broken' else 1 if task=='pylon_cracked' else 0)]
    elif task=='shelter_shadow':
        # Contractual narrow portrait cell stores the +x strip vertically; rotate the top camera.
        mesh('Protected 1x6u strip',[(0,-.5,0),(6,-.5,0),(6,.5,0),(0,.5,0)],[(0,1,2,3)],cyan,r);s.camera.rotation_euler.z=-math.pi/2;s.camera.location=(3,0,12)
    elif task in ('rivet','rivet_hit'):
        if task=='rivet':c.rod('Heavy iron rivet',(-.28,0,0),(.28,0,0),.075,edge,r);cylinder('Flat rivet head',(-.25,0,0),.15,.07,brass,r,(1,0,0));block('Chipped rivet seam',(.02,.045,.065),(.22,.055,.035),iron,r)
        else:
            for j in range(8):
                a=j*math.tau/8;c.rod('Impact metal splinter',(.08*math.cos(a),.08*math.sin(a),0),(.35*math.cos(a),.35*math.sin(a),0),.022,brass,r)
    elif task=='volley_cone':
        verts=[(0,0,0)]+[(7.75*math.cos(-math.pi/3+j*2*math.pi/3/48),7.75*math.sin(-math.pi/3+j*2*math.pi/3/48),0) for j in range(49)];mesh('120 degree danger cone',verts,[(0,j,j+1) for j in range(1,49)],red,r)
        for j in range(28):
            a=-.98+(j%7)/6*1.96;rr=2+(j//7)*1.65;movers.append(c.rod('Rain of falling rivets',(rr*math.cos(a),rr*math.sin(a),.04),((rr+.22)*math.cos(a),(rr+.22)*math.sin(a),.04),.035,brass,r))
    elif task=='shell':
        p=c.empty('Falling artillery shell',parent=r);movers=[p];lathe('Heavy shell',[(.20,0),(.27,.1),(.27,.8),(.08,1.1),(0,1.15)],iron,p);cylinder('Shell brass collar',(0,0,.18),.28,.13,brass,p)
    elif task=='shell_crater':
        lathe('Torn concrete crater',[(0,.01),(.9,.01),(1.22,.09),(1.5,.04)],soot,r,segments=24)
        for j in range(15):
            a=j*math.tau/15;ob=block('Shattered rust pavement',(1.2*math.cos(a),1.2*math.sin(a),.07),(.37,.22,.16),rust if j%3 else edge,r);ob.rotation_euler.z=a
    elif task=='coal_mouth':
        block('Coal receiving hopper',(0,0,.34),(1.2,.65,.55),rust,r);block('Black throat',(0,-.35,.48),(.85,.04,.28),soot,r)
        for j in range(5):block('Hot coals',((j-2)*.16,-.39,.38),(.10,.06,.08),glow,r)
        for x in (-.52,.52):block('Feed hopper leg',(x,.08,.12),(.15,.3,.25),iron,r)
    elif task.startswith('stoker'):
        b=c.empty('Stoker 2.0u',parent=r);movers=[b]
        for x in (-.24,.24):c.rod('Stoker piston leg',(x,0,.18),(x,0,.83),.085,edge,b);block('Stoker iron boot',(x,-.1,.12),(.29,.45,.20),iron,b)
        block('Coal armoured torso',(0,0,1.08),(.65,.40,.67),rust,b);block('Stoker angular head',(0,-.02,1.65),(.40,.35,.38),iron,b);block('Pale face slit',(0,-.21,1.66),(.24,.03,.06),brass,b)
        for x in (-.42,.42):c.rod('Worker arm',(x,0,1.35),(x,-.19,.88),.085,iron,b)
        c.rod('Shovel handle',(.50,-.2,.15),(.50,-.2,1.65),.035,brass,b);block('Shovel blade',(.50,-.2,.24),(.30,.08,.40),edge,b);lathe('Coal bucket',[(.19,.05),(.24,.48),(.20,.49),(.16,.13)],iron,b,(-.52,-.15,0));c.ring('Bucket handle',(-.52,-.15,.55),.21,.02,brass,b)
    elif task in ('steam_vent','reload_smoke'):movers=[vapour(r,(0,0,0),3.2 if task=='steam_vent' else 2.5,1.1 if task=='steam_vent' else .65)]
    if not top:
        if task.startswith('stoker'):r.rotation_euler.z=c.DIRECTIONS.get(task.rsplit('_',1)[-1],0)
        bpy.context.view_layer.update();inv=s.camera.rotation_euler.to_matrix().transposed();low=min((inv@(o.matrix_world@Vector(v))).y for o in r.children_recursive if o.type=='MESH' for v in o.bound_box);margin=12 if task.startswith('stoker_walk') else 4;s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,low+(h/2-margin)/64,12))
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in r.children_recursive}
    def pose(i):
        for o,(l,rot,sc) in rest.items():o.location=l;o.rotation_euler=rot;o.scale=sc
        t=i/max(1,n-1);wave=math.sin(math.tau*i/n)
        if task.startswith('pylon_') or task=='coal_mouth':sodium_strength(glow,(.65 if task=='pylon_broken' else 1.4)+.15*wave)
        if task=='shelter_shadow':r.scale=(1,1+.035*wave,1)
        if task=='pylon_drop':movers[0].location.z=(1-t)*3.6
        if task=='shell':movers[0].location.z=(1-t)*3.8
        if task.startswith('stoker'):
            if 'idle' in task:movers[0].location.z=.018*wave;movers[0].rotation_euler.y=.015*math.cos(math.tau*i/n)
            if 'walk' in task:
                movers[0].location.z=.04*wave;movers[0].rotation_euler.y=.04*wave
                for ob in movers[0].children_recursive:
                    if ob.name.startswith(('Stoker piston leg','Stoker iron boot')):
                        stride=math.cos(math.tau*i/n)*(1 if rest[ob][0].x>0 else -1);ob.location.y+=.12*stride
                        if ob.name.startswith('Stoker iron boot'):ob.location.z+=max(0,stride)*.08
            if 'death' in task:movers[0].rotation_euler.x=-1.35*t;movers[0].location.z=-.01*t
            d=task.rsplit('_',1)[-1];r.rotation_euler.z=c.DIRECTIONS.get(d,0)
        if task in ('steam_vent','reload_smoke'):movers[0].scale=(1+.08*wave,1+.08*wave,1+.07*wave);movers[0].rotation_euler.z=i*.13
        if task=='rivet':r.rotation_euler.x=i*math.pi/2
        if task=='rivet_hit':r.scale=(.5+t*.6,)*3
        if task=='shell_crater':r.scale=(.92+t*.08,)*3
        if task=='volley_cone':
            for j,o in enumerate(movers):o.location.x=.12*math.sin(i*math.tau/n+j)
    return r,pose

def render_frame(path,size):
    # Shared cel conversion replaces Principled alpha. Restore intentional vapour
    # and ground telegraph translucency in geometry, before rendering (no paint).
    configure=c.configure_passes
    def configure_alpha(path):
        configure(path)
        for m,alpha in ((steam,.28),(cyan,.32),(red,.30)):
            if m.get('gunner_alpha'):continue
            tree=m.node_tree;out=next(o for o in tree.nodes if o.type=='OUTPUT_MATERIAL');surface=out.inputs['Surface'].links[0].from_socket
            transparent=tree.nodes.new('ShaderNodeBsdfTransparent');mix=tree.nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=alpha;tree.links.new(transparent.outputs[0],mix.inputs[1]);tree.links.new(surface,mix.inputs[2]);tree.links.new(mix.outputs[0],out.inputs['Surface']);m['gunner_alpha']=True
    c.configure_passes=configure_alpha
    try:return shared.render_frame(path,size)
    finally:c.configure_passes=configure

def run():
    from PIL import Image
    import numpy as np
    DST.mkdir(parents=True,exist_ok=True);SOURCE.parent.mkdir(parents=True,exist_ok=True);bpy.context.preferences.filepaths.save_version=0
    root,pose=build();scene=bpy.context.scene
    # Editable source: every directional action and phase, with named timeline markers.
    f=1
    for task,(n,_) in BODY.items():
        for d in directions(task):
            scene.timeline_markers.new(task+'_'+d,frame=f)
            for i in range(n):
                pose(task,i,n);frame_body(root,d)
                for ob in [root,*root.children_recursive]:
                    for key in ('location','rotation_euler','scale','hide_render'):ob.keyframe_insert(key,frame=f+i)
                for m in bpy.data.materials:
                    if m.name.startswith('Sodium furnace'):
                        node=m.node_tree.nodes.get('Principled BSDF')
                        if node:node.inputs['Emission Strength'].keyframe_insert('default_value',frame=f+i)
            f+=n
    scene.frame_end=f-1;scene.render.fps=12;scene.frame_set(7);pose('idle_p1',0,6);bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    # Clear source actions for deterministic rendering of individually posed frames.
    for ob in [root,*root.children_recursive]:ob.animation_data_clear()
    for m in bpy.data.materials:
        if m.node_tree:m.node_tree.animation_data_clear()
    only=sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else None
    with tempfile.TemporaryDirectory(prefix='rainfall_gunner_') as temp:
        for body,table in ((True,BODY),(False,EXTRA)):
            for task,spec in table.items():
                key=sheet(task,body)
                if only and key not in only:continue
                if '--resume' in sys.argv and (DST/(key+'.png')).exists():continue
                if body:n,loop=spec;w=h=256;dirs=directions(task);cols=n
                else:root,epose=extra(task);w,h,n,loop,top=spec;dirs=['s'];cols=min(n,4096//w)
                rows=len(dirs) if body else math.ceil(n/cols);boards=[Image.new('RGBA',(cols*w,rows*h)) for _ in range(2)]
                for row,d in enumerate(dirs):
                    for i in range(n):
                        if body:pose('idle_p3' if task=='walk_p3' else task,i,n);frame_body(root,d)
                        else:epose(i)
                        bpy.context.view_layer.update();images=render_frame(Path(temp)/'frame.png',(w,h))
                        for k,im in enumerate(images):boards[k].paste(im,((i%cols)*w,(row if body else i//cols)*h))
                boards[0].save(DST/(key+'.png'),compress_level=9);a=np.asarray(boards[1]);peak=(a[:,:,:3].max(axis=2)*(a[:,:,3]/255)).max()
                if peak>2:
                    sys.path.insert(0,str(ROOT/'art/tools'));from halve_emission import downscale
                    downscale(boards[1]).save(DST/(key+'_e.png'),compress_level=9)
                print('GUNNER DONE',key,flush=True)
    print('GUNNER RENDER PASS',flush=True)

if __name__=='__main__':run()

