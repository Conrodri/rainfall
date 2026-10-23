"""N1c: terrace masonry water buffalo. Background Blender only; C7a pass pipeline."""
import sys, math, random, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/bosses'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso/_deps')]
import bpy
from mathutils import Vector
from PIL import Image
import boss_common as c
import iso_rig
import cel_style as cel
from ash_lord_build import worn, mesh, rod
DST=ROOT/'game/assets/sprites/bosses/etage/ox_herder'
SPECS={**{f'idle_p{p}':(6,4,256,256,True) for p in (1,2,3)},**{f'walk_p{p}':(8,4,256,256,True) for p in (1,2,3)},'auto':(6,4,256,256,False),'spell_a':(8,4,256,256,False),'spell_b':(8,4,256,256,False),'trans_p2':(8,1,256,256,False),'trans_p3':(8,1,256,256,False),'bogged':(6,1,256,256,True),'death':(10,1,256,256,False),'furrow':(4,1,512,64,True),'stomp_ring':(6,1,256,256,False),'mud_wave':(8,1,704,96,True),'dust_burst':(6,1,128,128,False)}
EXTRAS={'furrow','stomp_ring','mud_wave','dust_burst'}
def block(n,loc,size,mat,parent,bevel=.025):
    o=c.box(n,loc,size,mat,parent,bevel)
    for m in o.modifiers:
        if m.type=='BEVEL':m.segments=1
    return o
def stone(n,loc,scale,mat,parent):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
    o=c.finish(bpy.context.object,n,mat,parent);o.location=loc;o.scale=scale
    return o
def setup(cell=(256,256),top=False):
    s=iso_rig.create_rig('TOP' if top else 'CREA',cell)
    s.camera.data.ortho_scale=cell[0]/64 if top else 5.5 if cell[0]==256 else cell[0]/90.5097
    if not top:
        bottom=189.28 if cell[0]==256 else 82
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(bottom-cell[1]/2)*s.camera.data.ortho_scale/cell[0],0))
    s.eevee.taa_render_samples=8
    data=bpy.data.lights.new('Cold upper-left rim','AREA');data.energy=650;data.color=(.48,.68,1);data.shape='DISK';data.size=4
    light=bpy.data.objects.new('Cold upper-left rim',data);s.collection.objects.link(light);light.location=(-3,2,5);light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
    return s
def materials():
    return [worn('Rice limestone','8E907F','B2B3A0'),worn('Lichen stone','7D856F','A3AA8C'),worn('Moss in mortar','526044','6F7E55'),worn('Deep masonry joints','313B32','4A5042'),worn('Verdigris bronze','42695F','82A693',.7,.5),worn('Worn bronze rivets','766749','B8A57B',.7,.4),worn('Heavy saturated mud','3F4233','6F7054'),c.material('Water cyan sole accent',(.112,.578,1),.2,.3,1.1)]
def build():
    setup();random.seed(71);root=c.empty('OX_HERDER');body=c.empty('Masonry barrel',(0,0,0),root)
    st,lichen,moss,joint,bronze,edge,mud,water=materials()
    stone('Dark recessed continuous carcass',(0,.25,1.12),(.69,1.2,.64),joint,body)
    # Fitted convex voussoirs: offset courses around an anatomical barrel.
    for j in range(5):
        y=-.82+j*.45;radius=math.sqrt(max(.28,1-((y-.13)/1.55)**2))
        for k in range(10):
            a=(k+.12*(j%2))*math.tau/10; da=.284
            verts=[]
            for yy in (y-.213,y+.213):
                for aa in (a-da,a+da):verts.append((.73*radius*math.cos(aa),yy,1.16+.66*radius*math.sin(aa)))
            verts += [(x*.84,yy,1.16+(z-1.16)*.84) for x,yy,z in verts]
            # Individually hewn stones: chipped corners and staggered mortar, never a tiled cylinder.
            verts=[(x+random.uniform(-.018,.018),yy+random.uniform(-.014,.014),z+random.uniform(-.014,.014)) for x,yy,z in verts]
            mesh('Fitted terrace ashlar',verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],st if (j+k)%4 else lichen,body,.018)
            if k in (1,3,4,6,8) and j%2==0:
                rod('Moss packed into mortar',[(.738*radius*math.cos(a-da),y+.218,1.16+.67*radius*math.sin(a-da)),(.738*radius*math.cos(a+da),y+.218,1.16+.67*radius*math.sin(a+da))],.014,moss,body)
    for side in (-1,1):
        mesh('Carved shoulder shield',[(side*.52,-.74,1.23),(side*.69,-.63,1.65),(side*.48,-.25,1.79),(side*.81,-.20,1.44),(side*.76,-.43,.96)],[(0,1,2),(0,2,3),(0,3,4)],st,body,.016)
    legs=[];splashes=[];mudboots=[]
    for i,(x,y) in enumerate([(-.49,-.65),(.49,-.65),(-.48,.99),(.48,.99)]):
        leg=c.empty('Articulated load leg',(x,y,.92),body);legs.append(leg)
        stone('Stone thigh',(0,0,-.13),(.245,.29,.39),st,leg)
        block('Angular shank',(0,-.03,-.53),(.27,.30,.47),lichen,leg,.055)
        block('Split stone hoof',(0,-.09,-.81),(.36,.43,.20),joint,leg,.035)
        block('Hoof cleft',(0,-.312,-.82),(.025,.016,.13),moss,leg,.002)
        mudboots.append(stone('Knee deep mud',(0,-.02,-.64),(.22,.25,.29),mud,leg))
        ring=c.ring('Two centimetre hoof water',(x,y,.022),.24,.018,water,root,rotation=(0,0,0));ring.scale.y=.78;splashes.append(ring)
    head=c.empty('Patient lowered head',(0,-1.02,1.24),body)
    mesh('Carved sloping forehead',[(-.43,.16,.21),(.43,.16,.21),(-.46,-.40,.03),(.46,-.40,.03),(-.30,-.53,-.30),(.30,-.53,-.30),(-.39,.05,-.36),(.39,.05,-.36)],[(0,1,3,2),(2,3,5,4),(0,2,4,6),(1,7,5,3),(6,4,5,7),(0,6,7,1)],st,head,.035)
    stone('Broad buffalo muzzle',(0,-.57,-.31),(.45,.32,.24),lichen,head)
    block('Heavy hanging lip',(0,-.69,-.44),(.67,.23,.085),joint,head,.02)
    for side in (-1,1):
        stone('Low lateral ear',(side*.55,-.02,.02),(.25,.15,.10),bronze,head)
        block('Recessed narrow eye',(side*.42,-.39,.04),(.15,.09,.065),joint,head,.015)
        block('Water eye',(side*.435,-.43,.043),(.09,.025,.022),water,head,.003)
        stone('Nostril',(side*.25,-.826,-.27),(.09,.025,.055),joint,head)
        rod('Nostril water',[(side*.25,-.85,-.29),(side*.26,-.87,-.48),(side*.28,-.84,-.69)],.018,water,head)
        points=[(side*.37,-.08,.22),(side*.67,-.03,.34),(side*.97,.02,.37),(side*1.22,-.13,.32),(side*1.25,-.41,.24),(side*1.05,-.59,.24),(side*.94,-.51,.34)]
        points=[(x*1.1,y,z) for x,y,z in points]
        rod('Swept anchor horn',points,.105,bronze,head)
        rod('Anchor fluke',[(side*1.05,-.59,.24),(side*1.14,-.65,.40),(side*.91,-.61,.38)],.06,edge,head)
        c.ring('Horn socket',(side*.43,-.07,.24),.14,.033,edge,head,rotation=(0,math.pi/2,0))
    # Collar and two bronze bands follow the body, with rivets at every joint.
    for y in (-.72,.66):
        pts=[(.77*math.cos(a),y,1.15+.69*math.sin(a)) for a in [k*math.tau/16 for k in range(17)]]
        rod('Riveted bronze girth',pts,.047,bronze,body)
        for x,yy,z in pts[::2]:stone('Old brass rivet',(x,yy-.045,z),(.044,.035,.044),edge,body)
        for side in (-1,1):
            rod('Weeping harness seam',[(side*.73,y-.05,1.34),(side*.755,y-.05,1.21),(side*.74,y-.05,1.12)],.012,water,body)
    yoke=c.empty('Broken draught yoke',(0,-.51,1.83),body)
    rod('Splintered bronze yoke',[(-1.04,0,-.04),(-.70,0,.12),(-.28,0,.05),(.18,0,.12),(.52,0,.02),(.79,0,.17)],.10,bronze,yoke)
    for k in range(7):c.ring('Hanging chain',(-.89,-.49,1.64-k*.12),.075,.019,edge,body,rotation=(math.pi/2,0,k%2*math.pi/2))
    rod('Thin lowered tail',[(0,1.28,1.27),(.12,1.64,.98),(.19,1.73,.45),(.12,1.68,.23)],.04,bronze,body)
    harrow=c.empty('Dragged bronze harrow',(0,1.85,.13),root)
    for x in (-.58,.58):rod('Harrow tow chain',[(x,1.0,.55),(x,1.5,.20),(x,1.85,.1)],.026,edge,root)
    for y in (0,.36):block('Harrow crossbeam',(0,y,0),(1.55,.10,.09),bronze,harrow)
    for x in (-.65,-.32,0,.32,.65):rod('Plough tooth',[(x,-.08,.06),(x,.42,.08),(x,.54,-.11)],.045,bronze,harrow)
    pool=stone('Churned sinking mud',(0,.2,-.04),(.83,1.35,.08),mud,root)
    jets=[]
    for x,y,z in [(-.62,-.4,1.38),(.63,.25,1.52),(-.39,.80,1.69),(.30,-.7,1.72)]:
        rod('Split stone fissure',[(x,y,z),(x*.8,y+.18,z+.05),(x*.9,y+.35,z-.07)],.027,joint,body)
        jets.append(rod('Pressurised joint water',[(x,y,z),(x*1.3,y+.08,z+.16),(x*1.7,y+.17,z+.02)],.021,water,body))
    fracture=block('Split anchor scar',(.96,-.45,.30),(.028,.22,.09),joint,head,.001)
    mist=worn('Cold mineral vapour','809495','B3C0BA')
    steam=[]
    for side in (-1,1):
        steam.append(mesh('Thin cold breath',[(side*.25,-.86,-.40),(side*.36,-1.0,-.32),(side*.45,-1.07,-.12),(side*.36,-1.02,-.25)],[(0,1,2,3)],mist,head))
    seep=[o for o in head.children if o.name.startswith('Nostril water')]
    def pose(anim,i,n):
        t=i/n;phase=3 if 'p3' in anim or anim in ('bogged','death') else 2 if 'p2' in anim else 1
        body.location=(0,0,0);body.rotation_euler=(0,0,0);head.rotation_euler=(.025*math.sin(math.tau*t),0,0)
        for j,o in enumerate(body.children):
            if o.name.startswith('Fitted terrace ashlar'):
                o.location=(0,0,0)
                if anim=='death':
                    fall=max(0,(i-3)/6);o.location=((1 if j%2 else -1)*.14*fall,((j%5)-2)*.07*fall,-.06*fall)
        for j,leg in enumerate(legs):
            leg.rotation_euler=(0,0,0)
            for child in leg.children_recursive:child.hide_render=anim=='bogged'
        for o in harrow.children_recursive+[harrow]:o.hide_render=phase<2
        # Tow chain only belongs to phases two and three.
        for o in root.children_recursive:
            if o.name.startswith('Harrow tow'):o.hide_render=phase<2
        for o in mudboots:o.hide_render=phase<3 or anim=='bogged'
        for o in jets:o.hide_render=phase<3
        for o in steam:o.hide_render=phase<3 or anim=='death' and i>=7
        for o in head.children:
            if o.name.startswith(('Water eye','Nostril water')):o.hide_render=anim=='death' and i>=8
        pool.hide_render=phase<3;pool.scale=(.83,1.35,.08)
        fracture.hide_render=phase<2
        for o in seep:o.scale=(1,1,1+.22*(phase-1)+.06*math.sin(math.tau*t))
        for j,o in enumerate(splashes):o.scale=(1+.13*math.sin(math.tau*t+j),.78,.75+phase*.2)
        body.location.z=.023*math.sin(math.tau*t)
        yoke.rotation_euler.y=0;yoke.location.z=1.83
        if anim.startswith('walk'):
            body.location.z=.055*math.cos(2*math.tau*t);body.rotation_euler.y=.045*math.sin(math.tau*t)
            for j,leg in enumerate(legs):leg.rotation_euler.x=.52*math.sin(math.tau*t+(0 if j in (0,3) else math.pi))
            head.rotation_euler.x=-.12+.08*math.sin(math.tau*t)
        if anim=='auto':
            head.rotation_euler.x=[-.12,-.38,-.57,.65,.31,.05][i];body.location.y=[0,.05,.12,-.23,-.12,0][i]
        if anim=='spell_a':
            head.rotation_euler.x=-.38
            legs[0].rotation_euler.x=[0,.52,-.2,.62,-.66,.5,-.5,0][i]
            body.location.y=[0,.05,0,.1,-.32,-.2,-.1,0][i];body.rotation_euler.x=[0,0,0,.06,-.13,-.06,0,0][i]
        if anim=='spell_b':
            lift=[0,.14,.36,.48,-.08,.06,.02,0][i];body.rotation_euler.x=-lift;body.location.z=max(0,lift*.65)
            for leg in legs[:2]:leg.rotation_euler.x=-lift*1.5
            if i==4:
                for o in splashes:o.scale=(1.8,1.5,2)
        if phase>=2:yoke.rotation_euler.y=.38;yoke.location.z=1.55
        if anim=='trans_p2':yoke.rotation_euler.y=.38*i/7+math.sin(math.pi*i/7)*.65;yoke.location.z=1.83-.28*i/7+.35*math.sin(math.pi*i/7);head.rotation_euler.x=.4*math.sin(math.pi*i/7)
        if anim=='trans_p3':body.location.z=-.28*i/7;body.rotation_euler.y=.07*math.sin(i*2)
        if anim=='bogged':body.location.z=-.52+.04*math.sin(math.tau*t);body.rotation_euler.y=.12*math.sin(math.tau*t);head.rotation_euler.x=.24*math.sin(math.tau*t);pool.scale=(1.12,1.6,.14)
        if anim=='death':
            fall=min(1,i/6);angle=1.35*fall
            body.rotation_euler.y=angle;body.location.x=-.8*math.sin(angle)
            body.location.z=.8*(1-math.cos(angle))-.12*fall;head.rotation_euler.x=-.4*i/9
            for o in jets:o.hide_render=i>=7
    return root,pose

def extra(anim):
    n,rows,w,h,loop=SPECS[anim];setup((w,h),anim!='dust_burst');root=c.empty(anim)
    st,li,mo,jo,br,ed,mud,water=materials();objects=[]
    if anim in ('furrow','mud_wave'):
        length=w/64;half=h/128
        for j in range(30):
            x=(j+.45)*length/30
            for side in (-1,1):
                o=stone('Turned mud bank',(x-length/2,side*half*.64,.09),(.23,half*.27,.13 if anim=='furrow' else .34),mud,root);objects.append(o)
            rod('Water running forward',[(x-length/2-.12,-half*.35,.035),(x-length/2,0,.06),(x-length/2+.14,half*.26,.035)],.026 if anim=='furrow' else .05,water,root)
        if anim=='mud_wave':
            for j in range(16):objects.append(stone('Broken wave crest',(-length/2+.35+j*length/17,0,.23),(.31,.47,.28),mud,root))
    elif anim=='stomp_ring':
        verts=[];faces=[]
        for j in range(96):
            a=j*math.tau/96
            for r in (1.70+.035*math.sin(a*9),1.90+.035*math.sin(a*13)):
                verts.append((r*math.cos(a),r*math.sin(a),.04+.035*math.sin(a*7)))
        for j in range(96):faces.append((2*j,2*j+1,(2*j+3)%192,(2*j+2)%192))
        objects.append(mesh('Continuous broken mud wavefront',verts,faces,mud,root))
        c.ring('Cyan wet annulus',(0,0,.04),1.79,.037,water,root,rotation=(0,0,0))
    else:
        random.seed(93)
        for j in range(42):
            o=stone('Mud water ballistic clod',(0,0,0),(.035+random.random()*.04,)*3,water if j%4==0 else mud,root);objects.append(o)
            o['velocity']=[random.uniform(-1,1),random.uniform(-.35,.35),random.uniform(.8,2.2)]
    base=[o.location.copy() for o in objects]
    def pose(t):
        for j,o in enumerate(objects):
            if anim=='dust_burst':
                vx,vy,vz=o['velocity'];age=.12+t*.72;o.location=(vx*age,vy*age,max(.02,vz*age-1.6*age*age))
                o.scale=(.055*max(.1,1-t*.65),)*3
            elif anim=='stomp_ring':
                for k,v in enumerate(o.data.vertices):
                    angle=(k//2)*math.tau/96
                    r=(1.70 if k%2==0 else 1.90)+.035*math.sin(angle*(9 if k%2==0 else 13)+t*math.tau)
                    v.co=(r*math.cos(angle),r*math.sin(angle),.04+.035*math.sin(angle*7+t*math.tau))
            else:o.location.z=base[j].z+.035*math.sin(t*math.tau+j*.8)
    return root,pose

def write_tres():
    lines=['[gd_resource type="SpriteFrames" load_steps=999 format=3]'];ext=[];subs=[];anims=[]
    for a,(n,rows,w,h,loop) in SPECS.items():
        chunks=math.ceil(n*w/4096)
        per=4096//w
        for chunk in range(chunks):
            stem=a if chunks==1 else f'{a}_{chunk}'
            ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/ox_herder/{stem}.png" id="{stem}"]')
        for row,d in enumerate(('e','s','w','n') if rows==4 else ('s',)):
            frames=[]
            for i in range(n):
                chunk=i//per;stem=a if chunks==1 else f'{a}_{chunk}';uid=f'{a}_{row}_{i}'
                subs.append(f'[sub_resource type="AtlasTexture" id="{uid}"]\natlas = ExtResource("{stem}")\nregion = Rect2({i%per*w}, {row*h}, {w}, {h})')
                frames.append('{"duration": 1.0, "texture": SubResource("'+uid+'")}')
            name=a if a in EXTRAS else f'{a}_{d}'
            anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(loop).lower()+', "name": &"'+name+'", "speed": '+('14.0' if a.startswith('walk') else '12.0')+'}')
    lines[0]=lines[0].replace('999',str(1+len(ext)+len(subs)))
    (DST/'ox_herder.tres').write_text('\n\n'.join(lines+ext+subs+['[resource]\nanimations = ['+',\n'.join(anims)+']'])+'\n')

def contact():
    board=Image.new('RGBA',(1536,1024),'#3A4038')
    samples=[('idle_p1',0,0),('idle_p2',0,1),('idle_p3',0,1),('walk_p1',2,0),('spell_a',4,1),('spell_b',3,1),('auto',3,0),('trans_p2',4,0),('trans_p3',6,0),('bogged',2,0),('death',8,0)]
    for j,(a,i,row) in enumerate(samples):
        im=Image.open(DST/f'{a}.png').convert('RGBA').crop((i*256,row*256,(i+1)*256,(row+1)*256));board.alpha_composite(im,((j%6)*256,(j//6)*256))
    im=Image.open(ROOT/'game/assets/sprites/bosses/etage/eclusier/idle_p1.png').convert('RGBA').crop((0,0,256,256))
    # Both sprites retain their actual 256 px display cells.
    board.alpha_composite(im,(1280,256))
    for j,a in enumerate(('furrow','stomp_ring','mud_wave','dust_burst')):
        n,r,w,h,l=SPECS[a];stem=a+'_0' if n*w>4096 else a
        frame=3 if a=='dust_burst' else 0
        im=Image.open(DST/f'{stem}.png').convert('RGBA').crop((frame*w,0,(frame+1)*w,h));board.alpha_composite(im,(0 if j<2 else 768,530+(j%2)*240))
    board.convert('RGB').save(ROOT/'art/tools/night/_n1c_contact.png')

def main():
    DST.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='n1c_') as temp:
        temp=Path(temp);root,pose=build()
        source=ROOT/'art/blender/bosses/ox_herder_iso.blend';source.parent.mkdir(parents=True,exist_ok=True)
        # Store all authored actions in source for review and reuse.
        frame=1
        for a,(n,rows,w,h,l) in SPECS.items():
            if a in EXTRAS:continue
            bpy.context.scene.timeline_markers.new(a,frame=frame)
            for i in range(n):
                pose(a,i,n)
                for o in root.children_recursive:
                    for prop in ('location','rotation_euler','scale','hide_render'):o.keyframe_insert(data_path=prop,frame=frame+i)
            frame+=n
        bpy.context.scene.frame_end=frame-1;bpy.context.scene.render.fps=12
        bpy.context.scene.frame_set(1)
        bpy.context.preferences.filepaths.save_version=0
        cel.install('boss', normals=False)
        cel.toon_materials('boss');cel.setup_scene(samples=8)
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        for o in root.children_recursive:o.animation_data_clear()
        pose('idle_p1',0,6)
        cel.install('boss', normals=False)
        for a,(n,rows,w,h,loop) in SPECS.items():
            if '--only' in sys.argv and a not in sys.argv[sys.argv.index('--only')+1].split(','):continue
            if a in EXTRAS:root,epose=extra(a)
            per=4096//w
            for chunk in range(math.ceil(n/per)):
                count=min(per,n-chunk*per);boards=[Image.new('RGBA',(count*w,rows*h),(0,0,0,0)) for k in range(2)]
                for row,d in enumerate(('e','s','w','n') if rows==4 else ('s',)):
                    if a not in EXTRAS:
                        cam=bpy.context.scene.camera
                        base=cam.rotation_euler.to_matrix()@Vector((0,82*5.5/256,12))
                        # Lowest planted hoof, rather than ground origin, is y=210.
                        offset={'s':.955*.5,'e':.67*.5,'w':.67*.5,'n':1.295*.5}[d]
                        cam.location=base+cam.rotation_euler.to_matrix()@Vector((0,-offset,0))
                    for local in range(count):
                        i=chunk*per+local;path=temp/'frame.png'
                        fn=epose if a in EXTRAS else lambda t:pose(a,i,n)
                        c.render_still(root,fn,path,i/n,d)
                        for k,suffix in enumerate(('','_e')):
                            im=Image.open(path.with_name(path.stem+suffix+'.png')).convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
                            if k==0:alpha=im.getchannel('A')
                            else:im.putalpha(alpha)
                            boards[k].paste(im,(local*w,row*h))
                stem=a if n<=per else f'{a}_{chunk}'
                for board,suffix in zip(boards,('','_e')):
                    if suffix:
                        board=board.resize(((board.width+1)//2,(board.height+1)//2),Image.Resampling.LANCZOS)
                        assert max(max(px[:3])*px[3] for px in board.getdata())>510, 'Empty emission '+stem
                    board.save(DST/f'{stem}{suffix}.png',compress_level=9)
            print('N1C DONE '+a,flush=True)
    if not (DST/'ox_herder.tres').exists():write_tres()
    contact();print('N1C PASS',flush=True)
if __name__=='__main__':main()
