"""C9B: new open-crucible foundry automaton. Background only; C7c pipeline."""
import sys, math, tempfile, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
for folder in ('bosses','iso','monsters','cel'):
    sys.path.insert(0,str(ROOT/'art/tools'/folder))
if '--review' not in sys.argv:
    import bpy
    from mathutils import Vector
    import boss_common as c
    import iso_rig
    import cel_style as cel
    from ash_lord_build import mesh, worn
from PIL import Image
DST=ROOT/'game/assets/sprites/bosses/etage/smelter'
SPECS={**{f'{a}_p{p}':(6 if a=='idle' else 8,('e','s','w','n'),(256,256),True) for a in ('idle','walk') for p in (1,2,3)},
 'auto':(6,('e','s','w','n'),(256,256),False),'spell_a':(8,('e','s','w','n'),(256,256),False),'spell_b':(8,('e','s','w','n'),(256,256),False),
 'trans_p2':(8,('s',),(256,256),False),'trans_p3':(8,('s',),(256,256),False),'death':(10,('s',),(256,256),False),
 'molten_pool':(6,('',),(768,128),True),'splash':(6,('',),(192,256),False),'molten_arc':(6,('',),(128,128),True)}

def box(name,loc,size,mat,parent):
    o=c.box(name,loc,size,mat,parent,.025)
    for mod in o.modifiers:
        if mod.type=='BEVEL':mod.segments=1
    return o

def bowl(name,parent,mat,profile,segments=24):
    verts=[(r*math.cos(j*math.tau/segments),r*math.sin(j*math.tau/segments),z) for r,z in profile for j in range(segments)]
    faces=[(k*segments+j,k*segments+(j+1)%segments,(k+1)*segments+(j+1)%segments,(k+1)*segments+j) for k in range(len(profile)-1) for j in range(segments)]
    return mesh(name,verts,faces,mat,parent,.015)

def disk(name,parent,mat,r,z):
    return bowl(name,parent,mat,[(0,z),(r*.7,z+.015),(r,z)],32)

def setup(size=(256,256),top=False):
    s=iso_rig.create_rig('TOP' if top else 'CREA',size)
    if not top:
        scale=5.35 if size==(256,256) else size[0]/90.5
        s.camera.data.ortho_scale=scale
        pivot=198 if size==(256,256) else 224
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(pivot/size[1]-.5)*scale*size[1]/size[0],0))
    else:
        s.camera.data.ortho_scale=size[0]/64
    light=bpy.data.lights.new('Cold upper left rim','AREA');ob=bpy.data.objects.new(light.name,light);s.collection.objects.link(ob)
    ob.location=(-4,1,6);ob.rotation_euler=(Vector((0,0,1.7))-ob.location).to_track_quat('-Z','Y').to_euler();light.energy=650;light.color=(.48,.68,1);light.shape='DISK';light.size=3
    s.render.image_settings.compression=85
    return s

def materials():
    return (worn('Cast iron - pale rust','805F48','B99673',.65),worn('Hammered steel','686C70','A5A8A6',.7),worn('Refractory firebrick','806F5C','BEB097'),worn('Crust and seams','383D40','65615A'),c.material('SODIUM FF9A3C',(1,.323,.045),emission=1.8),worn('Rain steam','66727A','ADB7BD'))

def build():
    setup();iron,steel,brick,dark,hot,steam=materials()
    root=c.empty('LE FONDEUR - 3.5u');body=c.empty('Tilting forge',(0,0,.88),root)
    bowl('Flared riveted casting',body,iron,[(.53,.15),(.82,.42),(1.10,1.35),(1.19,1.56),(1.05,1.60),(.94,1.36),(.66,.43),(.38,.27)])
    for z,r in ((.45,.84),(1.02,1.02),(1.56,1.19)):
        c.ring('Forged retaining hoop',(0,0,z),r,.055,steel,body,rotation=(0,0,0))
        for j in range(16):
            a=j*math.tau/16;c.sphere('Square headed rivet',(r*math.cos(a),r*math.sin(a),z),(.045,.045,.045),steel,body)
    bricks=[]
    for j in range(20):
        a=j*math.tau/20;o=box('Refractory lining',(1.045*math.cos(a),1.045*math.sin(a),1.46),(.22,.13,.23),brick,body);o.rotation_euler.z=a+math.pi/2;bricks.append(o)
    liquid=disk('Open molten charge',body,hot,.91,1.20)
    light=bpy.data.lights.new('Upward molten bounce','POINT');light.energy=65;light.color=(1,.323,.045);light.shadow_soft_size=.6
    ob=bpy.data.objects.new(light.name,light);bpy.context.scene.collection.objects.link(ob);ob.parent=body;ob.location=(0,-.2,1.47)
    bubbles=[]
    for j in range(9):
        a=j*2.4;r=.20+.055*j;o=c.sphere('Boiling blister',(r*math.cos(a),r*math.sin(a),1.23),(.10,.10,.04),hot,body);bubbles.append(o)
    legs=[]
    for sign in (-1,1):
        leg=c.empty('Massive short piston leg',(sign*.53,0,0),root);legs.append(leg)
        box('Splayed iron boot',(0,-.16,.15),(.61,.89,.30),steel,leg)
        box('Shin armour',(0,.04,.49),(.47,.51,.55),iron,leg)
        c.rod('Hydraulic shin',(0,-.25,.32),(0,-.25,.8),.075,steel,leg)
        c.rod('Knee axle',(-.29,0,.76),(.29,0,.76),.13,dark,leg)
    arms=[]
    for sign in (-1,1):
        arm=c.empty('Articulated ladle arm',(sign*1.04,0,1.35),body);arms.append(arm)
        c.rod('Shoulder axle',(-.12,0,0),(.12,0,0),.18,steel,arm)
        c.rod('Upper casting',(0,0,0),(sign*.32,-.10,-.42),.14,iron,arm)
        c.rod('Chrome piston',(sign*.08,-.12,-.05),(sign*.31,-.23,-.41),.048,steel,arm)
        c.sphere('Elbow knuckle',(sign*.32,-.10,-.42),(.18,.18,.17),dark,arm)
        c.rod('Ladle shaft',(sign*.32,-.10,-.42),(sign*.40,-.65,-.51),.075,steel,arm)
        ladle=c.empty('Hollow ladle',(sign*.40,-.76,-.51),arm)
        bowl('Concave iron scoop',ladle,steel,[(0,-.16),(.21,-.13),(.29,.06),(.25,.09),(.16,-.07),(0,-.09)],16)
        disk('Metal caught in ladle',ladle,hot,.20,-.04)
    stack=c.empty('Asymmetric rear flue',(.44,.58,1.2),body)
    bowl('Open segmented chimney',stack,iron,[(.19,0),(.20,1.15),(.29,1.22),(.29,1.31),(.19,1.32),(.13,1.23),(.13,.9)],12)
    for z in (.35,.8,1.22):c.ring('Chimney band',(0,0,z),.22,.035,steel,stack,rotation=(0,0,0))
    drips=[];cracks=[];sparks=[];vapours=[]
    heat=c.material('Sodium incandescence in casting',(1,.323,.045),emission=.15)
    patches=[]
    for j in range(7):
        a=j*math.tau/7+.2
        verts=[]
        for aa,z in ((a-.11,.80),(a+.06,.72),(a+.16,1.20),(a+.04,1.39),(a-.10,1.24)):
            r=.82+(z-.42)*.28/.93+.025;verts.append((r*math.cos(aa),r*math.sin(aa),z))
        patches.append(mesh('Heat scar in iron',verts,[(0,1,2,3,4)],heat,body))
    for j in range(13):
        a=j*math.tau/13;r=1.08
        pts=[(r*math.cos(a),r*math.sin(a),1.48),((r-.10)*math.cos(a), (r-.10)*math.sin(a),1.13),((r-.24)*math.cos(a+.06),(r-.24)*math.sin(a+.06),.65+.10*(j%3))]
        c.tube('Frozen runnel',pts,.045,steel,body)
        drips.append(c.tube('Overflow sodium',[(x*1.025,y*1.025,z) for x,y,z in pts],.035,hot,body))
        cracks.append(c.tube('Thermal split',[(x*1.035,y*1.035,z-.12) for x,y,z in pts],.012,hot,body))
    hoop=c.ring('Breakaway heated hoop',(0,0,1.06),1.08,.045,hot,body,rotation=(0,0,0))
    for j in range(16):
        o=c.sphere('Chimney cinder',(0,0,0),(.022,.022,.055),hot,body);sparks.append(o)
    for j in range(7):
        a=j*math.tau/7
        verts=[]
        for k in range(8):
            t=k/7;w=.025+.07*math.sin(t*math.pi)
            for sign in (-1,1):verts.append((.86*math.cos(a)+.16*math.sin(t*5+j)+sign*w,.86*math.sin(a)+.12*t,1.6+t*.55))
        vapours.append(mesh('Rain steam ribbon',verts,[(k*2,k*2+1,k*2+3,k*2+2) for k in range(7)],steam,body))
    stream=c.tube('Pour contacts ground',[(0,-.9,2.25),(0,-1.20,1.72),(0,-1.40,.9),(0,-1.58,.05)],.11,hot,root)
    fracture=c.tube('Cold fractured crucible',[(.13,-1.18,1.56),(.07,-1.07,1.30),(.22,-.98,1.03),(.10,-.91,.78),(.19,-.82,.47)],.037,dark,body)
    def pose(anim,i,n):
        t=i/n;wave=math.sin(t*math.tau);phase=int(anim[-1]) if anim[-2:-1]=='p' else 1
        if anim=='trans_p2':phase=2
        if anim in ('trans_p3','death'):phase=3
        q=i/(n-1);impact=3 if anim=='auto' else 4;hit=math.exp(-((i-impact)/1.3)**2)
        body.location.z=.88+(.025*wave if anim.startswith(('idle','walk')) else 0);body.rotation_euler=(0,0,0)
        root.location=(0,0,0);root.scale=(1,1,1)
        for j,leg in enumerate(legs):leg.location.y=(.12*wave*(-1 if j else 1) if anim.startswith('walk') else 0);leg.location.z=(max(0,wave*(-1 if j else 1))*.10 if anim.startswith('walk') else 0)
        for j,arm in enumerate(arms):
            arm.rotation_euler=(.05*wave,0,.035*wave*(-1 if j else 1))
            if anim=='auto':arm.rotation_euler=(.85*hit,-.30*hit,(1 if j else -1)*.8*hit)
            if anim=='spell_b':arm.rotation_euler=(.05*wave*(1-hit),0,(-1 if j else 1)*1.65*hit)
        if anim=='spell_a':body.rotation_euler.x=.62*hit
        liquid.scale=(1,1,1);liquid.hide_render=False
        level=(0,.36,.40)[phase-1]
        if anim=='trans_p2':level=.36*q
        liquid.location.z=level+.025*wave;liquid.rotation_euler.x=.04*wave
        for j,o in enumerate(bubbles):o.hide_render=False;o.location.z=1.23+level+.025*math.sin(t*math.tau+j);o.scale=(.10,.10,.04*(1+.5*math.sin(t*math.tau+j)))
        for j,o in enumerate(drips):
            o.hide_render=phase<2 or (anim=='trans_p2' and q<.25)
            o.scale.z=(1+.08*math.sin(t*math.tau+j))*(.45+.55*q if anim=='trans_p2' else 1)
        for o in cracks:o.hide_render=phase<3;o.scale=(1,1,1)
        for o in patches:o.hide_render=phase<3
        hoop.scale=(1,1,1)
        hoop.hide_render=phase<2;hoop.location.z=1.06;hoop.rotation_euler.x=0
        if anim=='trans_p3':hoop.location.z=1.06+q*.9;hoop.rotation_euler.x=q*.8
        for j,o in enumerate(sparks):
            o.scale=(.022,.022,.055);u=(t+j/16)%1;o.location=(.44+.38*math.sin(j*2.4)*u,.58+.3*math.cos(j*2.4)*u,2.53+u*.42);o.hide_render=(j>5 and phase<3 and anim!='spell_b')
            if anim=='spell_b':
                o.location.x+=math.sin(j*2.4)*u*.85*hit
                o.location.z+=u*.28*hit
                o.scale*=1+.7*hit
        for j,o in enumerate(vapours):o.hide_render=phase<3 and j>1;o.rotation_euler.z=.035*math.sin(t*math.tau+j)
        stream.hide_render=anim!='spell_a' or i not in (4,5)
        fracture.hide_render=anim!='death' or q<.3
        if anim=='death':
            body.rotation_euler.y=.20*q;body.location.z-=.23*q
            for o in [*bubbles,*drips,*cracks,*sparks,hoop,*patches]:o.hide_render=q>.75 or o.hide_render;o.scale*=max(.02,1-q*.8)
        power=(1.5,3,12)[phase-1]*(1+.08*wave)
        if anim=='death':power=12*(1-q)**3
        for node in hot.node_tree.nodes:
            if node.type=='EMISSION':node.inputs['Strength'].default_value=power
            if node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=(power,power*.323,power*.045,1)
        power=.22*(1+.15*wave)*(max(0,1-q) if anim=='death' else 1)
        for node in heat.node_tree.nodes:
            if node.type=='EMISSION':node.inputs['Strength'].default_value=power
            if node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=(power,power*.323,power*.045,1)
    return root,pose

def extra(name):
    size=SPECS[name][2];top=name!='splash';setup(size,top);iron,steel,brick,dark,hot,steam=materials();root=c.empty(name)
    objects=[]
    if name=='molten_pool':
        # Longitudinal mesh, x=0 is the inlet at the left edge of the atlas cell.
        bpy.context.scene.camera.location.x=6
        for width,z,mat in ((.88,0,dark),(.68,.015,iron),(.52,.025,hot)):
            verts=[]
            for j in range(49):
                x=j/48*12;w=width*(.9+.07*math.sin(j*2.4))*(1-.22*(j/48)**6)
                verts.extend(((x,-w,z),(x,w,z)))
            objects.append(mesh('Flow crust and hot core',verts,[(j*2,j*2+1,j*2+3,j*2+2) for j in range(48)],mat,root))
        for j in range(22):
            x=.2+j*.54;y=.37*math.sin(j*2.4);o=box('Raft of cooled slag',(x,y,.045),(.16+.12*(j%3),.10,.025),dark,root);o.rotation_euler.z=j*.7
    elif name=='molten_arc':
        for width,z,mat in ((.60,0,dark),(.43,.02,hot)):
            verts=[]
            for j in range(25):
                a=(j/24-.5)*.32
                for r in (5-width,5+width):verts.append((r*math.sin(a),r*math.cos(a)-5,z))
            objects.append(mesh('Curved overflow sector',verts,[(j*2,j*2+1,j*2+3,j*2+2) for j in range(24)],mat,root))
    else:
        for j in range(15):
            a=j*2.4;r=.18+.08*(j%5);h=.45+.17*(j%7)
            objects.append(c.tube('Molten splash finger',[(0,0,.04),(r*math.cos(a),r*math.sin(a),h*.6),(r*1.5*math.cos(a),r*1.5*math.sin(a),h)],.025+.008*(j%3),hot,root))
    def pose(anim,i,n):
        t=i/n
        if name=='splash':root.scale=(.45+i*.14,.45+i*.14,max(.05,math.sin((i+1)/7*math.pi)))
        else:
            for j,o in enumerate(objects):o.scale.y=1+.035*math.sin(t*math.tau+j);o.location.z=.006*math.sin(t*math.tau+j)
    return root,pose

def tres():
    ext=[];subs=[];anims=[]
    for a,(n,dirs,cell,loop) in SPECS.items():
        w,h=cell
        for part in range(math.ceil(n/(4096//w))):
            key=a+(f'_{part+1}' if n*w>4096 else '');ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/smelter/{key}.png" id="{key}"]')
        for row,d in enumerate(dirs):
            frames=[]
            for i in range(n):
                per=4096//w;key=a+(f'_{i//per+1}' if n*w>4096 else '');sid=f'{a}_{d}_{i}'
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{key}")\nregion = Rect2({i%per*w}, {row*h}, {w}, {h})')
                frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
            name=a+('_'+d if d else '');anims.append('{"frames": ['+', '.join(frames)+f'], "loop": {str(loop).lower()}, "name": &"{name}", "speed": {14.0 if a.startswith("walk") else 12.0}'+'}')
    (DST/'smelter.tres').write_text('[gd_resource type="SpriteFrames" load_steps='+str(len(ext)+len(subs)+1)+' format=3]\n\n'+'\n'.join(ext+subs)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n')

def main():
    DST.mkdir(parents=True,exist_ok=True)
    only=sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else list(SPECS)
    with tempfile.TemporaryDirectory(prefix='c9b_') as td:
        tmp=Path(td)
        for a in only:
            n,dirs,cell,loop=SPECS[a];w,h=cell;root,pose=extra(a) if a in ('molten_pool','splash','molten_arc') else build()
            cel.install('boss', normals=False)
            cel.toon_materials('boss')
            if a=='idle_p1':
                frame=1;s=bpy.context.scene
                for anim,(nf,dd,cc,ll) in SPECS.items():
                    if cc!=(256,256):continue
                    s.timeline_markers.new(anim,frame=frame)
                    for ii in range(nf):
                        pose(anim,ii,nf)
                        for ob in [root,*root.children_recursive]:
                            for key in ('location','rotation_euler','scale','hide_render'):ob.keyframe_insert(key,frame=frame+ii)
                    frame+=nf+2
                s.frame_end=frame;s.render.fps=12;s.frame_set(1)
                pose(a,0,n);bpy.context.scene['contract']='256px; bottom=215; dim~185; e,s,w,n; sodium FF9A3C; CEL boss'
                path=ROOT/'art/blender/bosses/smelter_iso.blend';path.parent.mkdir(parents=True,exist_ok=True);bpy.context.preferences.filepaths.save_version=0
                bpy.ops.wm.save_as_mainfile(filepath=str(path))
                for ob in [root,*root.children_recursive]:ob.animation_data_clear()
            camera=bpy.context.scene.camera;camera_base=camera.location.copy()
            per=4096//w
            for start in range(0,n,per):
                count=min(per,n-start);boards=[Image.new('RGBA',(w*count,h*len(dirs)),(0,0,0,0)) for j in range(2)]
                for row,d in enumerate(dirs):
                    camera.location=camera_base
                    if cell==(256,256):camera.location+=camera.rotation_euler.to_matrix()@Vector((0,{'e':-5,'s':0,'w':-5,'n':8}[d]*5.35/256,0))
                    for i in range(start,start+count):
                        path=tmp/'frame.png';c.render_still(root,lambda t:pose(a,i,n),path,i/n,d or 's')
                        for j,suffix in enumerate(('','_e')):
                            im=Image.open(path.with_name(path.stem+suffix+'.png')).convert('RGBA').resize(cell,Image.Resampling.LANCZOS)
                            if j==0:alpha=im.getchannel('A')
                            else:im.putalpha(alpha)
                            boards[j].paste(im,((i-start)*w,row*h))
                key=a+(f'_{start//per+1}' if n*w>4096 else '')
                for board,suffix in zip(boards,('','_e')):
                    if suffix:
                        sys.path.insert(0,str(ROOT/'art/tools'))
                        from halve_emission import downscale
                        board=downscale(board)
                    board.save(DST/f'{key}{suffix}.png',compress_level=9)
            print('C9B PASS',a,flush=True)
    tres() # Existing provisional resource is incomplete: add required animations/extras.

def review():
    import numpy as np
    errors=[];stats={}
    for a,(n,dirs,(w,h),loop) in SPECS.items():
        per=4096//w
        for start in range(0,n,per):
            key=a+(f'_{start//per+1}' if n*w>4096 else '')
            images=[Image.open(DST/f'{key}{s}.png').convert('RGBA') for s in ('','_e')]
            rgb=np.asarray(images[0]);emit_small=np.asarray(images[1])
            emit=np.asarray(images[1].resize(images[0].size,Image.Resampling.NEAREST))
            if images[0].size!=(min(per,n-start)*w,len(dirs)*h):errors.append(key+' grid')
            if max(images[0].size)>4096:errors.append(key+' budget')
            if images[1].size!=tuple((v+1)//2 for v in images[0].size):errors.append(key+' emission size')
            if (DST/f'{key}_n.png').exists():errors.append(key+' forbidden normal')
            if not np.any((emit_small[:,:,:3].max(axis=2)>2)&(emit_small[:,:,3]>2)):errors.append(key+' empty emission')
            import hashlib
            hashes=set();bounds=[]
            for row in range(len(dirs)):
                for col in range(min(per,n-start)):
                    frame=images[0].crop((col*w,row*h,(col+1)*w,(row+1)*h));bounds.append(frame.getbbox())
                    digest=hashlib.sha256(frame.tobytes()).hexdigest()
                    if not bounds[-1]:errors.append(key+' empty frame')
                    if digest in hashes:errors.append(key+' duplicate frame')
                    hashes.add(digest)
            body=(rgb[:,:,3]>240)&(np.max(emit[:,:,:3],axis=2)<30)&(np.mean(rgb[:,:,:3],axis=2)>35)
            mean=float(np.mean(rgb[:,:,:3][body])) if body.any() else 0
            if (w,h)==(256,256) and mean<90:errors.append(key+' dark '+str(mean))
            stats[key]={'size':images[0].size,'body_mean':round(mean,1),'bounds':bounds}
    board=Image.new('RGBA',(2048,1536),(34,38,42,255));ground=Image.open(ROOT/'game/assets/sprites/terrain/rust_city/iso/ground_a.png').convert('RGBA')
    for row in range(-2,14):
        for col in range(-2,9):board.alpha_composite(ground,(col*512+(row%2)*256,row*128))
    fauna=json.loads((ROOT/'game/data/fauna.json').read_text(encoding='utf8'))['boss_sprites']
    for row in range(4):
        for col,(a,idx) in enumerate((('idle_p1',0),('idle_p2',0),('idle_p3',0),('auto',3),('spell_a',4),('spell_b',4))):
            im=Image.open(DST/f'{a}.png').convert('RGBA').crop((idx*256,row*256,(idx+1)*256,(row+1)*256));board.alpha_composite(im,(col*256,row*256))
        for col,boss in enumerate(('sonneur','crane')):
            path=ROOT/f'game/assets/sprites/bosses/etage/{boss}/walk_p1.png'
            if path.exists():
                data=fauna.get(boss,{'fh':256,'bottom':215});fh=int(data['fh']);im=Image.open(path).convert('RGBA').crop((0,row*fh,fh,(row+1)*fh))
                # Match source orthographic pixels per world unit (C7c / C9a).
                scale={'sonneur':5.3,'crane':5.15}[boss]/5.35;side=round(fh*scale)
                im=im.resize((side,side),Image.Resampling.LANCZOS)
                board.alpha_composite(im,(1536+col*256+(256-side)//2,row*256+215-round(float(data['bottom'])*scale)))
    for col,a in enumerate(('trans_p2','trans_p3','death')):
        idx=4 if a!='death' else 9;im=Image.open(DST/f'{a}.png').convert('RGBA').crop((idx*256,0,(idx+1)*256,256));board.alpha_composite(im,(col*256,1024))
    im=Image.open(DST/'molten_pool_1.png').convert('RGBA').crop((0,0,768,128));board.alpha_composite(im,(768,1056))
    board.alpha_composite(Image.open(DST/'splash.png').convert('RGBA').crop((576,0,768,256)),(1536,1024))
    board.alpha_composite(Image.open(DST/'molten_arc.png').convert('RGBA').crop((0,0,128,128)),(768,1200))
    for j,name in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png','art/tools/night/_f3_contact.png')):
        im=Image.open(ROOT/name).convert('RGBA')
        if '_cs1_' in name:im=im.crop((im.width//2,0,im.width,im.height))
        im.thumbnail((340,220));board.alpha_composite(im,(j*352,1300))
    board.convert('RGB').save(ROOT/'art/tools/night/_c9b_contact.png',compress_level=9)
    report={'errors':errors,'sheets':stats,'contact_columns':'p1 p2 p3 auto3 spell_a4 spell_b4 Sonneur Grue, rows e s w n; extras and validated references below','optional_molten_arc':'Delivered; absent from fauna.json extras by contract'}
    (ROOT/'art/tools/night/_c9b_verify.json').write_text(json.dumps(report,indent=2))
    print('C9B VERIFY', 'PASS' if not errors else 'FAIL',len(stats),'sheets',errors[:8])
    if errors:raise SystemExit(1)

if __name__=='__main__':
    if '--review' in sys.argv:review()
    else:main()
