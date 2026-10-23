"""C8a / Reclus. Background Blender, shared C7/cel pipeline; resumable by sheet.
Run with Blender --background --python this_file. --only comma,separated,sheets.
Python this_file --verify assembles the sole contact sheet and checks contracts.
"""
import sys, math, json, hashlib, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
DST=ROOT/'game/assets/sprites/bosses/etage/recluse'
sys.path[:0]=[str(ROOT/'art/tools'/p) for p in ('cel','iso','monsters','bosses')]
import cel_style as cel
SPECS={**{f'{a}_p{p}':(6 if a=='idle' else 8,(256,256),('e','s','w','n'),True) for a in ('idle','walk') for p in (1,2,3)},
 'auto':(6,(256,256),('e','s','w','n'),False),
 'spell_a':(8,(256,256),('e','s','w','n'),False),'spell_b':(8,(256,256),('e','s','w','n'),False),
 'trans_p2':(8,(256,256),('s',),False),'trans_p3':(8,(256,256),('s',),False),'death':(10,(256,256),('s',),False),
 'bell_wave':(8,(256,256),('s',),False),'prayer_glyph':(8,(128,128),('s',),True),
 'prayer_burst':(6,(192,384),('s',),False),'ray':(8,(896,64),('s',),True),'silence_mark':(6,(96,96),('s',),True)}
EXTRAS={'bell_wave','prayer_glyph','prayer_burst','ray','silence_mark'}

def resource():
    """Text SpriteFrames; split the 14u ray into two four-frame atlases."""
    sheets=[];frames=[];anims=[]
    for a,(n,(w,h),dirs,loop) in SPECS.items():
        for part in range(math.ceil(n/(4096//w))):
            name=a if part==0 else a+'_'+str(part+1)
            sheets.append(name)
        for row,d in enumerate(dirs):
            ids=[]
            for i in range(n):
                part=i//(4096//w);col=i%(4096//w);name=a if part==0 else a+'_'+str(part+1)
                ident=f'{a}_{d}_{i}';ids.append(ident)
                frames.append(f'[sub_resource type="AtlasTexture" id="{ident}"]\natlas = ExtResource("{name}")\nregion = Rect2({col*w}, {row*h}, {w}, {h})\n')
            label=a if a in EXTRAS else a+'_'+d
            sequence=', '.join('{"duration": 1.0, "texture": SubResource("'+v+'")}' for v in ids)
            anims.append('{"frames": ['+sequence+'], "loop": '+str(loop).lower()+', "name": &"'+label+'", "speed": '+str(14.0 if a.startswith('walk') else 12.0)+'}')
    txt='[gd_resource type="SpriteFrames" load_steps='+str(1+len(sheets)+len(frames))+' format=3]\n\n'
    txt+='\n'.join(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/recluse/{a}.png" id="{a}"]' for a in sheets)+'\n\n'
    txt+='\n'.join(frames)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n'
    (DST/'recluse.tres').write_text(txt,encoding='utf-8')

def build():
    import bpy
    import boss_common as c, iso_rig
    from ash_lord_build import mesh, plate, rod, shard
    from mathutils import Vector
    s=iso_rig.create_rig('CREA',256);s.camera.data.ortho_scale=5.10
    # The foremost salt hem, rather than the centre of the broad robe, is at y=215.
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,5.10*(196.5/256-.5),0))
    s['c8a_ground_pivot']=[128,215];s['c8a_height_u']=3.6
    # Linear base colors from physical stone/salt palette, not texture grain.
    def mat(n,h,metal=0,emit=0):
        rgb=tuple(((int(h[i:i+2],16)/255+.055)/1.055)**2.4 for i in (0,2,4))
        m=c.material(n,rgb,metal,.73,emit)
        if emit:m['rainfall_emissive']=True
        return m
    stone=mat('Salt limestone B4B0A2','B4B0A2');shade=mat('Damp stone 8C8778','8C8778')
    edge=mat('Fracture chalk','C7C5B5');wet=mat('Drowned robe hem','737D79')
    bone=mat('Funeral bone rosary','B8AD91');bronze=mat('Verdigris silence bell','668D7E',.7)
    brass=mat('Worn bell lip','A8946E',.7);wood=mat('Petrified staff','6C736D')
    cavity=mat('Empty hood interior','080C0E');glow=mat('ONLY accent BFF4FF','BFF4FF',0,1.5)
    root=c.empty('RECLUSE_3_6U');body=c.empty('Salt habit',parent=root)
    # Each long wedge is a sculpted fold, with staggered broken hem and chisel planes.
    panels=[]
    for j in range(18):
        a=j*math.tau/18;verts=[]
        for k,(z,r) in enumerate(((.10,.82),(.36,.77),(1.05,.62),(1.85,.45),(2.55,.39),(2.91,.44))):
            for q in range(3):
                aa=a+(q-1)*math.tau/36;rr=r+(.075 if q==1 else -.016)
                zz=z+(.055*math.sin(j*2.7) if k==0 else .025*math.sin(j+k))
                verts.append((rr*math.sin(aa),rr*.78*math.cos(aa),zz))
        faces=[(k*3+q,k*3+q+1,(k+1)*3+q+1,(k+1)*3+q) for k in range(5) for q in range(2)]
        ob=mesh('Chiselled salt habit fold',verts,faces,shade if j%4==0 else stone,body,.008);panels.append(ob)
        # Long salt streaks are geometry: no surface-noise or painted shading.
        if j%2==0:
            rod('Calcified vertical fold',[(r*math.sin(a),r*.78*math.cos(a),z) for z,r in ((.24,.85),(.8,.73),(1.65,.55),(2.48,.46))],.017,edge,body)
        shard('Wet fractured hem',(math.sin(a)*.76,math.cos(a)*.60,.15),(.11,.10,.18),wet,body)
    # Hollow pointed cowl: nested arch with a real open front, no face or eyes.
    outer=[(-.40,2.88),(-.43,3.16),(-.30,3.43),(0,3.60),(.28,3.42),(.39,3.15),(.33,2.85)]
    inner=[(-.24,2.94),(-.27,3.14),(-.18,3.32),(0,3.44),(.17,3.31),(.24,3.13),(.20,2.93)]
    verts=[(x,y,z) for y,pts in ((-.28,outer),(-.40,inner),(.22,outer)) for x,z in pts]
    faces=[]
    for j in range(6):faces.extend(((j,j+1,7+j+1,7+j),(j,14+j,14+j+1,j+1)))
    faces.append(tuple(range(14,21)))
    mesh('Pointed open stone cowl',verts,faces,stone,body,.013)
    plate('Deep empty hood well',inner,-.19,.055,cavity,body,0)
    rod('Cowl left worn rim',[(-.25,-.42,2.94),(-.28,-.41,3.14),(-.17,-.40,3.33),(0,-.32,3.46)],.025,edge,body)
    # A cyan reflected lip beneath the empty hood belongs to the same chest crystal.
    plate('Underlit cowl lower lip',[(-.13,2.94),(0,2.97),(.13,2.94),(0,2.91)],-.405,.022,glow,body,0)
    plate('Broken pectoral stone setting',[(-.27,2.57),(0,2.77),(.28,2.54),(.18,2.16),(0,2.03),(-.19,2.20)],-.43,.13,shade,body,.018)
    heart=c.empty('Crystal heart',(0,-.55,2.40),body)
    shard('Faceted cyan crystal heart',(0,0,0),(.14,.12,.28),glow,heart)
    for side in (-1,1):
        rod('Stone heart clamp',[(side*.17,-.59,2.20),(side*.18,-.64,2.35),(side*.13,-.59,2.55)],.024,edge,body)
    veins=c.empty('Phase two crystalline fractures',parent=body)
    for side in (-1,1):
        for j in range(3):
            rod('Exposed cyan branching vein',[(side*.09,-.53,2.40-j*.13),(side*(.28+j*.04),-.48,2.2-j*.32),(side*(.22+j*.09),-.51,1.98-j*.42),(side*(.35+j*.09),-.50,1.67-j*.44)],.013,glow,veins)
    arms=[]
    for side in (-1,1):
        arm=c.empty('Right bell arm' if side==1 else 'Left prayer arm',(side*.43,0,2.64),body);arms.append(arm)
        plate('Heavy broken stone sleeve',[(side*-.13,.04),(side*.16,-.04),(side*.29,-.63),(side*.14,-.90),(side*-.16,-.78)],-.18,.36,stone,arm,.021)
        rod('Sleeve carved crease',[(side*.04,-.21,-.13),(side*.14,-.22,-.47),(side*.07,-.24,-.75)],.021,shade,arm)
        c.box('Exposed bone hand',(side*.12,-.15,-.86),(.14,.19,.22),bone,arm,.018)
        for f in range(3):rod('Long skeletal finger',[(side*.12+(f-1)*.041,-.26,-.83),(side*.14+(f-1)*.041,-.30,-.97),(side*.10+(f-1)*.041,-.25,-1.02)],.017,bone,arm)
    staff=c.empty('Bell staff',(.18,-.17,-.87),arms[1])
    rod('Long petrified silence staff',[(0,0,-1.54),(.025,0,0),(0,.015,1.16)],.037,wood,staff)
    for z in (-.09,.08,.91):c.ring('Staff bronze binding',(0,0,z),.048,.015,brass,staff,rotation=(0,0,0))
    bell=c.empty('Hanging hollow silence bell',(.01,0,.85),staff)
    # Cast bell is one continuous open shell, rather than a sphere/cone assembly.
    vv=[];profile=[(.26,-.26),(.28,-.21),(.20,-.13),(.15,.14),(.09,.22),(.06,.19),(.115,.12),(.16,-.13),(.23,-.21)]
    for r,z in profile:
        vv.extend((r*math.cos(k*math.tau/24),r*math.sin(k*math.tau/24),z) for k in range(24))
    ff=[(j*24+k,j*24+(k+1)%24,(j+1)*24+(k+1)%24,(j+1)*24+k) for j in range(len(profile)-1) for k in range(24)]
    mesh('Hollow bronze bell casting',vv,ff,bronze,bell,.004)
    c.ring('Bell worn striking lip',(0,0,-.22),.256,.022,brass,bell,rotation=(0,0,0))
    rod('Bell clapper',[(0,0,.15),(0,0,-.26)],.025,brass,bell)
    for j in range(6):
        a=j*math.tau/6;rod('Bell incised vertical ribs',[(.15*math.sin(a),.15*math.cos(a),.1),(.22*math.sin(a),.22*math.cos(a),-.15)],.012,brass,bell)
    # Asymmetric rosary of small oblong bones, hung on a continuous cord.
    points=[]
    for j in range(15):
        t=j/14;x=-.34+.68*t;z=2.14-.38*math.sin(math.pi*t);y=-.55
        points.append((x,y,z));shard('Bone rosary bead',(x,y-.02,z),(.032,.035,.057),bone,body)
    rod('Rosary cord',points,.011,wood,body)
    orbit=c.empty('Phase three orbiting salt ruins',parent=body)
    for j in range(5):
        a=j*math.tau/5;ob=shard('Orbiting fractured stone',(math.cos(a)*.99,math.sin(a)*.78,.45+j*.28),(.12,.09,.21),shade,orbit);ob.rotation_euler=(j*.3,j*.7,a)
    rim=bpy.data.lights.new('Cold upper-left rim','AREA');rim.energy=650;rim.color=(.64,.82,1);rim.shape='DISK';rim.size=3
    ob=bpy.data.objects.new('Cold upper-left rim',rim);s.collection.objects.link(ob);ob.location=(-3,2,5);ob.rotation_euler=(Vector((0,0,1.6))-ob.location).to_track_quat('-Z','Y').to_euler()
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def pose(a,i,n):
        for o,(l,r,sc) in rest.items():o.location=l;o.rotation_euler=r;o.scale=sc
        t=i/n;u=i/max(1,n-1);wave=math.sin(math.tau*t)
        ph=3 if a.endswith('p3') or a=='death' else 2 if a.endswith('p2') else 1
        if a=='trans_p2':ph=1+u
        if a=='trans_p3':ph=2+u
        f=max(0,min(1,ph-1));lift=max(0,ph-2)
        veins.scale=(max(.001,f),)*3;heart.scale=(.70+.22*(ph-1),)*3
        orbit.scale=(max(.001,lift),)*3;orbit.rotation_euler.z=.20*wave
        body.location.z=.5*lift+.012*wave*(1+lift)
        body.rotation_euler.y=.009*math.cos(math.tau*t)
        for j,o in enumerate(panels):o.rotation_euler.y=(.012*wave+f*.017)*math.sin(j*1.7)
        if a.startswith('walk'):
            body.rotation_euler.x=.025*wave;body.location.z+=.024*abs(wave)*(1-lift)
            for j,o in enumerate(panels):o.rotation_euler.x=.035*math.sin(math.tau*t+j*.65)*(1-lift*.7)
            arms[0].rotation_euler.x=.12*wave;arms[1].rotation_euler.x=-.08*wave
        if a=='auto':
            arms[1].rotation_euler.x=[0,.42,.85,-.63,-.28,0][i]
            arms[1].rotation_euler.y=[0,-.25,-.55,.45,.2,0][i]
            body.rotation_euler.z=[0,-.10,-.26,.23,.09,0][i]
        if a=='spell_a':
            q=[0,.20,.48,.72,.14,.08,.035,0][i];arms[1].rotation_euler.x=-q
            arms[0].rotation_euler.x=-.7*math.sin(math.pi*u);arms[0].rotation_euler.y=-.5*math.sin(math.pi*u)
            bell.rotation_euler.y=[0,.05,.12,.25,-.48,.29,-.14,0][i]
        if a=='spell_b':
            q=[0,.4,.8,1,.8,.5,.2,0][i]
            for j,arm in enumerate(arms):
                side=(-1,1)[j];arm.rotation_euler.x=-.55*q
                arm.rotation_euler.y=side*([0,.25,.5,.55,-.55,-.4,-.15,0][i])
            heart.scale*=1+.18*q
        if a=='death':
            body.location.z=.5*(1-u)-.2*u;body.rotation_euler.x=.68*u
            for j,o in enumerate(panels):o.location.x+=math.sin(j*math.tau/18)*.55*u;o.location.z-=.12*u*(j%3)
            heart.scale*=max(.001,1-max(0,(u-.72)/.28));veins.scale=(max(.001,1-u),)*3
            orbit.scale=(max(.001,1-u),)*3
    return root,pose

def extra(a):
    import bpy, boss_common as c, iso_rig
    from ash_lord_build import mesh, rod, shard
    from mathutils import Vector
    n,(w,h),_,_=SPECS[a]
    s=iso_rig.create_rig('CREA' if a=='prayer_burst' else 'TOP',(w,h))
    s.camera.data.ortho_scale=w/(90.5 if a=='prayer_burst' else 64)
    if a=='prayer_burst':s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(h/2-6)/90.5,0))
    if a=='ray':s.camera.location.x=7
    glow=c.material('Cyan crystal ritual accent',(.52,.90,1),0,.5,1.3);glow['rainfall_emissive']=True
    stone=c.material('Crystalline dark facet',(.16,.32,.35),0,.7)
    root=c.empty('Recluse '+a);moving=[]
    if a in ('bell_wave','prayer_glyph','silence_mark'):
        radius={'bell_wave':1.88,'prayer_glyph':.88,'silence_mark':.63}[a]
        # Leave a visible cyan core between the mandatory two-pixel ink edges.
        # Bell outer radius: (1.88 + .0575) * 64 = exactly 124px.
        c.ring('Thin crystalline ritual circle',(0,0,0),radius,.0575 if a=='bell_wave' else .049,glow,root,rotation=(0,0,0))
        if a!='bell_wave':
            c.ring('Inner engraved ritual circle',(0,0,0),radius*.73,.042,glow,root,rotation=(0,0,0))
            for j in range(12):
                theta=j*math.tau/12
                rune=c.empty('Angular funerary rune',parent=root);rune.rotation_euler.z=theta
                rod('Carved fork glyph',[(radius*.79,-.035,.01),(radius*.87,.015,.01),(radius*.93,-.03,.01)],.045,glow,rune)
                rod('Carved rune stem',[(radius*.86,.018,.01),(radius*.85,.075,.01)],.043,glow,rune)
                moving.append(rune)
        else:
            for j in range(16):
                theta=j*math.tau/16
                shard('Travelling salt echo',(1.75*math.cos(theta),1.75*math.sin(theta),0),(.024,.024,.02),glow,root)
    elif a=='prayer_burst':
        for j in range(9):
            theta=j*2.4;hgt=3.8 if j==0 else 1.2+(j%4)*.55
            ob=shard('Upward crystalline prayer',(0 if j==0 else .60*math.cos(theta),0 if j==0 else .35*math.sin(theta),hgt/2+.04),(.14 if j else .19,.11,hgt/2),glow if j%3 else stone,root)
            moving.append(ob)
        c.ring('Crystal impact at feet',(0,0,.035),.7,.035,glow,root,rotation=(0,0,0))
    else:
        # Exact +X origin, 14u extent; thin jagged overlapping crystalline ribbons.
        for j in range(5):
            verts=[]
            for k in range(29):
                x=k*.5;width=.025+.025*math.sin(k*1.7+j)**2
                y=(j-2)*.105+.028*math.sin(k*1.9+j)
                verts.extend(((x,y-width,.01+j*.002),(x,y+width,.01+j*.002)))
            ob=mesh('Ray crystalline filament',verts,[(k*2,k*2+1,k*2+3,k*2+2) for k in range(28)],glow,root);moving.append(ob)
        for k in range(1,28):shard('Ray crystalline node',(k*.5,0,.02),(.10,.13,.06),glow,root)
    rest={o:o.scale.copy() for o in moving}
    def pose(a,i,n):
        t=i/n
        for j,o in enumerate(moving):
            o.scale=rest[o];o.scale.y*=.86+.14*math.sin(math.tau*t+j)
            if a=='prayer_burst':o.scale.z*=([.18,.65,1,.88,.55,.13][i])
        if a=='bell_wave':root.scale=(.975+.025*i/(n-1),)*3
        if a in ('prayer_glyph','silence_mark'):root.rotation_euler.z=.025*math.sin(math.tau*t)
    return root,pose

def main():
    import bpy, boss_common as c, iso_rig
    from PIL import Image
    DST.mkdir(parents=True,exist_ok=True)
    inv=HERE/'_c8a_inventory.json'
    if not inv.exists():
        inv.write_text(json.dumps({p.name:{'size':Image.open(p).size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in DST.glob('*.png')},indent=2))
    cel.archive_folder('bosses/etage/recluse')
    root,pose=build()
    source=ROOT/'art/blender/bosses/recluse_iso.blend';source.parent.mkdir(parents=True,exist_ok=True)
    if '--only' not in sys.argv:
        f=1
        for a,(n,_,dirs,_) in SPECS.items():
            if a in EXTRAS:continue
            bpy.context.scene.timeline_markers.new(a,frame=f)
            for i in range(n):
                pose(a,i,n)
                for o in [root]+list(root.children_recursive):
                    for channel in ('location','rotation_euler','scale'):o.keyframe_insert(channel,frame=f+i)
            f+=n
        bpy.context.scene.frame_end=f-1;bpy.context.scene.render.fps=12
        bpy.context.scene.frame_set(1)
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        # Keep editable animation in the source, export using explicit procedural poses.
        for o in [root]+list(root.children_recursive):o.animation_data_clear()
        pose('idle_p1',0,6)
    if '--source-only' in sys.argv:return
    selected=sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else list(SPECS)
    cel.install('boss')
    with tempfile.TemporaryDirectory(prefix='rainfall_c8a_') as td:
        tmp=Path(td)
        for a in selected:
            n,(w,h),dirs,loop=SPECS[a]
            if a in EXTRAS:root,pose=extra(a)
            elif bpy.context.scene.get('iso_rig')!='CREA' or root.name!='RECLUSE_3_6U':root,pose=build()
            s=bpy.context.scene;s['iso_frame']=[w,h];s.render.resolution_x=w*2;s.render.resolution_y=h*2
            cap=4096//w
            for part,start in enumerate(range(0,n,cap)):
                count=min(cap,n-start);name=a if part==0 else a+'_'+str(part+1)
                boards=[Image.new('RGBA',(count*w,len(dirs)*h),(128,128,255,0) if j==1 else (0,0,0,0)) for j in range(3)]
                for row,d in enumerate(dirs):
                    for i in range(start,start+count):
                        pose(a,i,n)
                        if a not in EXTRAS:root.rotation_euler.z=c.DIRECTIONS[d]
                        bpy.context.view_layer.update();path=tmp/f'{a}_{d}_{i}.png'
                        iso_rig.render_frame(path)
                        for j,suffix in enumerate(('','_n','_e')):
                            with Image.open(path.with_name(path.stem+suffix+'.png')) as im0:im=im0.convert('RGBA')
                            if j==0:alpha=im.getchannel('A')
                            else:im.putalpha(alpha)
                            boards[j].paste(im,((i-start)*w,row*h))
                for board,suffix in zip(boards,('','_n','_e')):board.save(DST/f'{name}{suffix}.png',compress_level=9)
                cel.quantize_normal_files([DST/f'{name}_n.png'],work=tmp/'normal_quantize')
                print('C8A DONE '+name,flush=True)
    resource()
    (DST/'lighting.md').write_text('C8a: CEL boss / 3 tones / 2px inner ink / quantized screen normals / CEL_Accent. Eevee 8 samples, Standard, 2x Lanczos. Body: CREA 30deg, ortho 5.10, foremost hem pivot (128,215), ground centre y=196.5, height 3.6u. Cold upper-left rim, pale salt stone. Cyan is the sole emission. Ground extras 64px/u; burst 90.5px/u. Ray split into ray.png + ray_2.png to respect 4096px. Impact indices auto=3, spells=4.\n')

def verify():
    from PIL import Image
    import numpy as np
    errors=[];report={};samples=[]
    for a,(n,(w,h),dirs,_) in SPECS.items():
        for part,start in enumerate(range(0,n,4096//w)):
            count=min(4096//w,n-start);name=a if part==0 else a+'_'+str(part+1)
            ims=[Image.open(DST/f'{name}{s}.png').convert('RGBA') for s in ('','_n','_e')]
            arrays=[np.asarray(im) for im in ims];d,no,e=arrays
            assert ims[0].size==(count*w,len(dirs)*h),name
            assert max(ims[0].size)<=4096,name
            assert np.array_equal(d[:,:,3],no[:,:,3]) and np.array_equal(d[:,:,3],e[:,:,3]),name+' alpha'
            opaque=no[:,:,3]==255;colors=np.unique(no[:,:,:3][opaque],axis=0)
            assert len(colors)<=27,(name,len(colors))
            normals=colors.astype(float)/255*2-1
            assert np.max(np.abs(np.linalg.norm(normals,axis=1)-1))<.015,name
            cells=[]
            for r in range(len(dirs)):
                for i in range(count):
                    cc=d[r*h:(r+1)*h,i*w:(i+1)*w]
                    assert (cc[:,:,3]>240).any(),(name,r,i,'empty')
                    cells.append(hashlib.sha256(cc.tobytes()).hexdigest())
            assert len(cells)==len(set(cells)),(name,'duplicate frames')
            report[name]={'size':ims[0].size,'opaque_normal_colors':len(colors),'nonempty_unique_cells':len(cells)}
    # Real-size crops only, no painted asset or oversized contact. Background is the crypt floor color.
    contact=Image.new('RGBA',(1536,1664),'#2E3238')
    spots=[('idle_p1',0,1),('idle_p1',1,2),('idle_p1',2,3),('idle_p1',3,4),('idle_p2',1,2),('idle_p3',1,2),
           ('auto',1,2),('auto',1,3),('spell_a',1,3),('spell_a',1,4),('spell_b',1,3),('spell_b',1,4),
           ('trans_p2',0,4),('trans_p3',0,4),('death',0,5),('bell_wave',0,4),('prayer_glyph',0,3),('silence_mark',0,2)]
    for idx,(a,r,i) in enumerate(spots):
        w,h=SPECS[a][1];im=Image.open(DST/f'{a}.png').convert('RGBA').crop((i*w,r*h,(i+1)*w,(r+1)*h))
        contact.alpha_composite(im,((idx%6)*256+(256-w)//2,(idx//6)*256))
    burst=Image.open(DST/'prayer_burst.png').convert('RGBA').crop((384,0,576,384));contact.alpha_composite(burst,(0,768))
    ray=Image.open(DST/'ray.png').convert('RGBA').crop((1792,0,2688,64));contact.alpha_composite(ray,(256,800))
    # Validated visual references are assembled once, alongside the actual-size final assets.
    for idx,rel in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png')):
        im=Image.open(ROOT/rel).convert('RGBA')
        if idx==3:im=im.crop((im.width//2,0,im.width,im.height))
        im.thumbnail((368,480),Image.Resampling.LANCZOS);contact.alpha_composite(im,(idx*384,1160))
    contact.convert('RGB').save(HERE/'_c8a_contact.png',compress_level=9)
    body=np.asarray(Image.open(DST/'idle_p1.png').convert('RGBA'))
    mask=body[:,:,3]>250;mean=body[:,:,:3][mask].mean()
    assert mean>=90,('body luminance',mean)
    report['body_mean_srgb']=round(float(mean),2)
    (HERE/'_c8a_verify.json').write_text(json.dumps(report,indent=2))
    print('PASS C8a: 18 sheets, all grids/alpha/normals/unique frames; body mean',round(mean,1))

if __name__=='__main__':
    if '--verify' in sys.argv:verify()
    else:main()
