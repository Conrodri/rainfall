"""N2D Le Cedre-Ermite. Blender background only; --resume skips complete atlases.
Reuses official ash_lord worn materials, CREA rig, AO, and boss normal/emission compositor.
System Python --verify / --contact. No painting: Pillow only packs rendered pixels.
"""
import sys, math, json, re, tempfile, argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
if '--background' in sys.argv or 'bpy' in sys.modules:
    sys.path[:0]=[str(ROOT/'art/tools/iso/_deps'),str(Path.home()/'AppData/Local/RainfallIsoDeps')]
OUT=ROOT/'game/assets/sprites/bosses/etage/hermit_cedar'
SOURCE=ROOT/'art/blender/monsters/hermit_cedar_iso.blend'
CONTACT=ROOT/'art/tools/night/_n2d_contact.png'
SPECS={**{f'idle_p{p}':(6,['e','s','w','n'],256) for p in (1,2,3)},
       **{f'walk_p{p}':(8,['e','s','w','n'],256) for p in (1,2,3)},
       **{a:(n,['s'],256) for a,n in [('auto',6),('spell_a',8),('spell_b',8),('trans_p2',8),('trans_p3',8),('death',10)]},
       **{a+'_dirs':(n,['e','w','n'],256) for a,n in [('auto',6),('spell_a',8),('spell_b',8)]},
       'root_spike':(8,['s'],(512,64)), 'spore_cloud':(8,['s'],256), 'stump':(4,['s'],(96,128))}
EXTRAS=('root_spike','spore_cloud','stump')

def dims(size):return (size,size) if isinstance(size,int) else size

def write_tres():
    ext=[]; sub=[]; anims=[]
    for a,(n,ds,size) in SPECS.items():
        w,h=dims(size); cols=min(n,4096//w)
        for page in range(math.ceil(n/cols)):
            name=a+('' if page==0 else f'_{page+1}')
            ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/hermit_cedar/{name}.png" id="{name}"]')
        for row,d in enumerate(ds):
            ids=[]
            for i in range(n):
                page=i//cols; name=a+('' if page==0 else f'_{page+1}'); ident=f'{a}_{d}_{i}'
                sub.append(f'[sub_resource type="AtlasTexture" id="{ident}"]\natlas = ExtResource("{name}")\nregion = Rect2({i%cols*w}, {row*h}, {w}, {h})')
                ids.append('{"duration": 1.0, "texture": SubResource("'+ident+'")}')
            base=a.removesuffix('_dirs')
            name=base+'_'+d if a not in EXTRAS else a
            loop=a.startswith(('idle','walk')) or a in ('spore_cloud',)
            anims.append('{"frames": ['+', '.join(ids)+f'], "loop": {str(loop).lower()}, "name": &"{name}", "speed": {14.0 if a.startswith("walk") else 12.0}'+'}')
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'hermit_cedar.tres').write_text(f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(sub)+1} format=3]\n\n'+'\n\n'.join(ext+sub)+'\n\n[resource]\nanimations = ['+',\n'.join(anims)+']\n',encoding='utf-8')

def import_policy():
    # Restrict policy changes to the delivered directory, following the approved Cerf import.
    import hashlib
    template=(ROOT/'game/assets/sprites/bosses/etage/cerf/idle_p1.png.import').read_text()
    template=re.sub(r'^uid=.*\n','',template,flags=re.M)
    old_hash=re.search(r'idle_p1.png-([a-f0-9]+)',template)[1]
    for path in OUT.glob('*.png'):
        resource='res://assets/sprites/bosses/etage/hermit_cedar/'+path.name
        digest=hashlib.md5(resource.encode()).hexdigest()
        text=template.replace('res://assets/sprites/bosses/etage/cerf/idle_p1.png',resource).replace('idle_p1.png-',path.name+'-').replace(old_hash,digest)
        path.with_suffix('.png.import').write_text(text,encoding='utf-8')
    print('PASS scoped mobile import policy')


def contact():
    from PIL import Image
    # Single inspection sheet: posed silhouettes on the exact forest background, passes and references.
    samples=[(f'idle_p{p}',r) for p in (1,2,3) for r in (1,0,2,3)]
    samples += [(a,r) for a in ('auto','auto_dirs','spell_a','spell_a_dirs','spell_b','spell_b_dirs') for r in range(len(SPECS[a][1]))]
    samples += [(a,0) for a in ('walk_p3','trans_p2','trans_p3','death','root_spike','spore_cloud','stump')]
    tiles=[]
    for a,r in samples:
        n,ds,size=SPECS[a];w,h=dims(size);cols=min(n,4096//w)
        tile=Image.new('RGBA',(384,150),(62,74,63,255))
        for k,i in enumerate((0,n//2,n-1)):
            page=i//cols;name=a+('' if page==0 else f'_{page+1}')
            with Image.open(OUT/f'{name}.png') as src:im=src.crop((i%cols*w,r*h,(i%cols+1)*w,(r+1)*h)).convert('RGBA')
            im.thumbnail((128,146),Image.Resampling.LANCZOS);tile.alpha_composite(im,(k*128+(128-im.width)//2,2))
        tiles.append(tile)
    # Normal/emission witness; no pixel drawing, only rendered image assembly.
    for suf in ('_n','_e'):
        with Image.open(OUT/f'idle_p2{suf}.png') as src:im=src.crop((0,256,768,512)).convert('RGBA')
        im.thumbnail((384,150),Image.Resampling.LANCZOS)
        tile=Image.new('RGBA',(384,150),(26,30,29,255));tile.alpha_composite(im,(0,0));tiles.append(tile)
    out=Image.new('RGBA',(1536,math.ceil(len(tiles)/4)*150+210),(26,30,29,255))
    for k,im in enumerate(tiles):out.alpha_composite(im,((k%4)*384,(k//4)*150))
    for k,path in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png')):
        with Image.open(ROOT/path) as src:im=src.convert('RGBA').crop((0,0,min(src.width,800),min(src.height,440)))
        im.thumbnail((512,205),Image.Resampling.LANCZOS);out.alpha_composite(im,(k*512,out.height-210))
    out.save(CONTACT,compress_level=9);print('PASS contact',flush=True)

def verify():
    from PIL import Image,ImageChops
    txt=(OUT/'hermit_cedar.tres').read_text();bad=[];count=0;maxside=0
    for a,(n,ds,size) in SPECS.items():
        w,h=dims(size);cols=min(n,4096//w)
        for page in range(math.ceil(n/cols)):
            name=a+('' if page==0 else f'_{page+1}');ims=[]
            for suf in ('','_n','_e'):
                with Image.open(OUT/f'{name}{suf}.png') as src:ims.append(src.convert('RGBA'))
            assert all(im.size==(min(cols,n-page*cols)*w,len(ds)*h) for im in ims),name
            assert max(ims[0].size)<=4096,name
            maxside=max(maxside,*ims[0].size)
            assert all(ImageChops.difference(ims[0].getchannel('A'),im.getchannel('A')).getbbox() is None for im in ims[1:]),name
            assert max(c.getextrema()[1] for c in ims[2].split()[:3])>1,('black emission',name)
            for r in range(len(ds)):
                for j in range(min(cols,n-page*cols)):
                    box=ims[0].crop((j*w,r*h,(j+1)*w,(r+1)*h)).getchannel('A').getbbox();count+=1
                    if box and min(box[0],box[1],w-box[2],h-box[3])<4:bad.append([name,r,j,box])
    assert not bad,bad[:8]
    names=re.findall(r'"name": &"([^"]+)"',txt)
    assert len(names)==len(set(names))
    assert len(re.findall('type="AtlasTexture"',txt))==count
    print(f'PASS verify: {len(names)} animations, {count} frames, matching alpha, margins >=4px, max atlas {maxside}px',flush=True)

def build():
    global bpy,c,iso,Vector,worn,rod,mesh
    import bpy,random
    from mathutils import Vector
    for p in ('bosses','monsters','iso'):sys.path.insert(0,str(ROOT/'art/tools'/p))
    import boss_common as c
    import iso_rig as iso
    from ash_lord_build import worn,rod,mesh
    rng=random.Random(24022)
    s=iso.create_rig('CREA',256);s.eevee.taa_render_samples=12
    s.camera.data.ortho_scale=4.8;s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,1.36,0))
    s.render.resolution_x=s.render.resolution_y=320
    bpy.data.objects['Fill_froid'].data.energy=260
    bpy.ops.object.light_add(type='AREA',location=(-3,1,5));rim=bpy.context.object;rim.name='Mist cold edge';rim.data.energy=400;rim.data.color=(.61,.76,.80);rim.data.size=3
    rim.rotation_euler=(Vector((0,0,1.8))-rim.location).to_track_quat('-Z','Y').to_euler()
    wood=worn('Cedar heartwood soaked in black water','282D25','818173',0,.88)
    bark=worn('Bleached fibrous cedar bark and fog lichen','4D5147','C3C4B0',0,.82)
    dark=worn('Deep wet fissures','101913','3D4938',0,.92)
    moss=worn('Dead moss and sodden roots','283329','6B7559',0,.97)
    bronze=worn('Corroded hermit votive bronze','283D35','8DA78E',.62,.62)
    rope=worn('Old prayer cord','424238','999780',0,.92)
    glow=c.material('Single foxfire accent #9CF0C8',(.333,.871,.578),roughness=.65,emission=1.8)
    root=c.empty('HERMIT_CEDAR_N2D');body=c.empty('Hollow cedar trunk',(0,0,0),root)
    halves=[c.empty('Split cedar left',(-.18,0,1.35),body),c.empty('Split cedar right',(.18,0,1.35),body)]
    # Contiguous irregular tapered staves, hollow inside. Open front: a real negative space, never a painted crack.
    for j in range(15):
        ang=j*math.tau/15
        if math.sin(ang)<-.76:continue
        side=0 if math.cos(ang)<0 else 1;parent=halves[side];hx=(-.18,.18)[side]
        verts=[]
        levels=((.55,.49),(1.0,.55),(1.55,.57),(2.15,.47),(2.65,.38),(3.12+rng.uniform(-.15,.28),.25))
        for k,(z,r) in enumerate(levels):
            for layer in (0,1):
                for edge in (-1,1):
                    a=ang+edge*.18+.045*math.sin(j*2+k);rr=r-(.13 if layer else 0)
                    verts.append((rr*math.cos(a)-hx,.78*rr*math.sin(a)+.07*math.sin(k),z-1.35))
        faces=[]
        for k in range(len(levels)-1):
            u=k*4;v=u+4;faces.extend(((u,u+1,v+1,v),(u+2,v+2,v+3,u+3),(u,v,v+2,u+2),(u+1,u+3,v+3,v+1)))
        faces.extend(((0,2,3,1),(20,21,23,22)))
        mesh('Riven cedar stave %02d'%j,verts,faces,bark if j%3 else wood,parent,.006)
        # Sculpted long fibres stand proud of the bark, following the taper.
        for f in range(3):
            pts=[]
            for k,(z,r) in enumerate(levels):
                a=ang+(f-1)*.09+.025*math.sin(k*2+j)
                pts.append(((r+.012)*math.cos(a)-hx,.78*(r+.012)*math.sin(a)+.07*math.sin(k),z-1.35))
            rod('Raised longitudinal cedar grain',pts,.014 if f!=1 else .024,wood if f%2 else bark,parent)
    # Lantern nested inside the open trunk. Narrow cage, visible from front and side through the split.
    lantern=c.empty('Swinging hermit lantern',(0,-.26,1.78),body)
    c.sphere('Sealed mint flame',(0,0,0),(.14,.12,.29),glow,lantern)
    for z,r in ((-.35,.19),(.35,.17)):
        pts=[(r*math.cos(k*math.tau/12),r*math.sin(k*math.tau/12),z) for k in range(13)]
        rod('Hammered bronze lantern rim',pts,.026,bronze,lantern)
    for j in range(6):
        a=j*math.tau/6
        rod('Lantern forged bars',[(.19*math.cos(a),.19*math.sin(a),-.35),(.23*math.cos(a),.23*math.sin(a),0),(.17*math.cos(a),.17*math.sin(a),.35)],.017,bronze,lantern)
    rod('Lantern bail',[(-.13,0,.35),(-.12,0,.52),(0,0,.61),(.12,0,.52),(.13,0,.35)],.018,bronze,lantern)
    rod('Lantern chain inside cedar',[(0,-.26,2.36),(.03,-.26,2.54),(0,-.25,2.73)],.018,bronze,body)
    # Overhanging cedar crown: jagged lightning fracture and sparse, layered dead branches.
    for j in range(7):
        a=j*2.399;h=2.55+j*.095;x=.27*math.cos(a);y=.22*math.sin(a)
        end=(x+.62*math.cos(a),y+.51*math.sin(a),h+.10+(j%2)*.15)
        rod('Dead cedar horizontal bough',[(x,y,h),((x+end[0])*.5,(y+end[1])*.5,h+.20),end],.065,wood,body)
        for k in (0,1):
            tip=(end[0]+.12*math.cos(a+.9),end[1]+.13*math.sin(a+.9),end[2]+.16+k*.10)
            rod('Razor dry cedar twig',[(end[0]*.78,end[1]*.78,end[2]),tip],.022,bark,body)
    # Long asymmetrical branch arms with hinge hierarchy and grasping root fingers.
    shoulders=[];elbows=[]
    for side in (-1,1):
        arm=c.empty('Branch shoulder '+str(side),(side*.45,.01,2.40 if side<0 else 2.27),body);shoulders.append(arm)
        rod('Crooked upper branch',[(0,0,0),(side*.31,-.03,-.30),(side*.37,-.05,-.64)],.14,bark,arm)
        elbow=c.empty('Branch elbow '+str(side),(side*.37,-.05,-.64),arm);elbows.append(elbow)
        rod('Split forearm',[(0,0,0),(side*.10,-.12,-.36),(side*.17,-.22,-.66)],.105,wood,elbow)
        for j in range(3):
            z=-.60-j*.025
            rod('Articulated root talon',[(side*.15+(j-1)*.07,-.20,z),(side*.18+(j-1)*.10,-.36,z-.19),(side*.10+(j-1)*.11,-.46,z-.27)],.035,bark,elbow)
        rod('Worn longitudinal arm ridge',[(side*.03,-.11,-.06),(side*.28,-.15,-.29),(side*.33,-.13,-.57)],.027,wood,arm)
    feet=[];anchored=[];dirt=[]
    for side in (-1,1):
        foot=c.empty('Root foot '+str(side),(side*.26,0,.66),root);feet.append(foot)
        rod('Buttress root leg',[(0,0,0),(side*.10,-.02,-.26),(side*.17,-.15,-.48)],.19,bark,foot)
        for j in range(3):
            rod('Dragging toe root',[(side*.15,-.11,-.43),(side*(.26+j*.04),-.28-j*.10,-.56),(side*(.38+j*.055),-.40-j*.10,-.60)],.063,wood,foot)
        for j in range(3):
            cl=c.sphere('Torn earth clod',(side*.10+(j-1)*.11,-.12-j*.13,-.44),(.12,.12,.09),moss,foot);dirt.append(cl)
    for j in range(8):
        a=j*math.tau/8
        ob=rod('Phase two planted radial root',[(.30*math.cos(a),.30*math.sin(a),.64),(.64*math.cos(a),.55*math.sin(a),.19),(.92*math.cos(a),.76*math.sin(a),.05)],.082,bark,root);anchored.append(ob)
        rod('Hair root tip',[(.70*math.cos(a),.61*math.sin(a),.11),(.96*math.cos(a+.10),.78*math.sin(a+.10),.045)],.019,wood,ob)
    # Prayer ropes with angular wooden votives and lichen flakes along one shoulder only.
    for j in range(2):
        pts=[(-.67+.10*math.sin(k*.7),-.22,2.52-k*.12) for k in range(10)]
        rod('Frayed hermit prayer rope',pts,.014,rope,body)
        for k in (2,5,8):
            x,y,z=pts[k];c.box('Carved wooden prayer tablet',(x+j*.09,y-.02,z-.04),(.065,.025,.13),wood,body,.008)
    for j in range(22):
        a=rng.uniform(0,math.tau);z=rng.uniform(.7,2.8);r=.52 if z<2 else .40
        if math.sin(a)<-.6:continue
        ob=c.sphere('Scaly fog lichen',(r*math.cos(a),.81*r*math.sin(a),z),(.07,.035,.10),moss if j%3 else bark,body)
    iso.bake_ao_shadows(root)
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in [root,*root.children_recursive]}
    def pose(anim,i,n):
        t=i/max(1,n-1);cycle=i/n*math.tau
        for o,(loc,rot,sc) in rest.items():o.location=loc;o.rotation_euler=rot;o.scale=sc;o.hide_render=False
        ph=2 if anim.endswith('p2') else 3 if anim.endswith('p3') else 1
        opened=1 if ph==2 else .35 if ph==3 else 0
        if anim=='trans_p2':opened=t
        if anim=='trans_p3':opened=1-t*.65
        planted=1 if ph==2 else 0
        if anim=='trans_p2':planted=t
        if anim=='trans_p3':planted=1-t
        for ob in anchored:ob.scale=(max(.001,planted),)*3
        for ob in dirt:ob.hide_render=ph!=3 and anim!='trans_p3'
        for j,ob in enumerate(halves):ob.rotation_euler.y=(-1 if j==0 else 1)*opened*.23
        body.location.z=-.14*opened;body.rotation_euler.x=-.16 if ph==3 else .012*math.sin(cycle)
        lantern.rotation_euler.y=.10*math.sin(cycle);lantern.rotation_euler.x=.035*math.cos(cycle)
        if ph==2:body.rotation_euler.x=0
        if anim.startswith('walk') and ph!=2:
            body.location.z+=.045*(1-math.cos(cycle*2))
            for j,ob in enumerate(feet):ob.rotation_euler.x=.25*math.sin(cycle+j*math.pi);ob.location.z+=.10*max(0,math.sin(cycle+j*math.pi))
            for j,ob in enumerate(shoulders):ob.rotation_euler.x=.12*math.sin(cycle+j*math.pi)
        # Arm then strike: maximum physical extension exactly at frames 3 / 4.
        if anim=='auto':
            u=i/3 if i<=3 else (5-i)/2
            if i<3:shoulders[1].rotation_euler.y=-.62*u;shoulders[1].rotation_euler.z=-.40*u
            else:shoulders[1].rotation_euler.x=-1.02*u;shoulders[1].rotation_euler.z=.72*u;elbows[1].rotation_euler.x=-.35*u
            body.rotation_euler.z=(-.18 if i<3 else .25)*u
        if anim=='spell_a':
            u=i/4 if i<=4 else (7-i)/3
            body.location.z=-.22*u;body.rotation_euler.x=.16*u
            for j,ob in enumerate(shoulders):ob.rotation_euler.x=-.33*u;ob.rotation_euler.y=(-1 if j==0 else 1)*.18*u
            for ob in anchored:ob.scale=(max(.001,u),)*3
        if anim=='spell_b':
            u=i/4 if i<=4 else (7-i)/3
            body.rotation_euler.x=-.13*u;body.rotation_euler.z=.13*math.sin(i*2.5)*u
            for j,ob in enumerate(shoulders):ob.rotation_euler.y=(-1 if j==0 else 1)*.48*u;ob.rotation_euler.x=-.15*u
            for j,ob in enumerate(halves):ob.rotation_euler.y=(-1 if j==0 else 1)*.12*u
        if anim=='trans_p3':
            body.location.z+=.23*math.sin(t*math.pi);body.rotation_euler.x=-.16*t
            for j,ob in enumerate(feet):ob.rotation_euler.x=-.32*t;ob.location.z+=.20*t
        if anim=='death':
            # Fold into the stump footprint; lantern drops forward and its core contracts to extinguish.
            body.location.z=-.48*t;body.scale=(1-.18*t,1-.20*t,1-.48*t)
            body.rotation_euler.x=.16*t
            for j,ob in enumerate(shoulders):ob.rotation_euler.y=(-1 if j==0 else 1)*.50*t
            lantern.location.y-=.40*t;lantern.location.z-=.24*t;lantern.rotation_euler.y=1.3*t
            for ob in lantern.children:
                if ob.name.startswith('Sealed mint'):ob.scale=rest[ob][2]*max(.001,1-t)
    return root,pose,{'wood':wood,'bark':bark,'moss':moss,'glow':glow,'bronze':bronze}


def extra(anim,mats):
    import random
    rng=random.Random(22026);root=c.empty('EXTRA_'+anim);s=bpy.context.scene
    w,h=dims(SPECS[anim][2]);s.render.resolution_x=w;s.render.resolution_y=h
    s.camera.data.ortho_scale=w/64;s.camera.location=(0,0,12);s.camera.rotation_euler=(0,0,0)
    moving=[];variants=[]
    if anim=='root_spike':
        for j in range(21):
            x=-3.80+j*.365;y=.12*math.sin(j*2)
            ob=rod('Thorned root emergence',[(x,y,0),(x+.11,y+.10,.16),(x+.28,y-.10,.04)],.062,mats['bark'],root);moving.append((ob,j))
            rod('Root needle',[(x+.09,y,.05),(x+.16,y-.25,.15)],.035,mats['wood'],ob)
            if j%3==0:rod('Seeping mint root crack',[(x,y-.04,.07),(x+.08,y+.02,.10),(x+.18,y-.03,.08)],.012,mats['glow'],ob)
    elif anim=='spore_cloud':
        # Four unit diameter at the consumer scale: real 3D irregular veils and spore particles.
        haze=c.material('Threadbare drifting spore fog',(.28,.36,.30),roughness=.98)
        nodes=haze.node_tree.nodes;links=haze.node_tree.links;p=nodes.get('Principled BSDF');haze.surface_render_method='DITHERED'
        geo=nodes.new('ShaderNodeNewGeometry');noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=3.3;noise.inputs['Detail'].default_value=4.2;noise.inputs['Roughness'].default_value=.72
        links.new(geo.outputs['Position'],noise.inputs['Vector'])
        ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.34;ramp.color_ramp.elements[0].color=(0,0,0,1);ramp.color_ramp.elements[1].position=.67;ramp.color_ramp.elements[1].color=(.48,.48,.48,1)
        links.new(noise.outputs['Fac'],ramp.inputs[0])
        distance=nodes.new('ShaderNodeVectorMath');distance.operation='LENGTH';links.new(geo.outputs['Position'],distance.inputs[0])
        fall=nodes.new('ShaderNodeMapRange');fall.inputs['From Min'].default_value=.45;fall.inputs['From Max'].default_value=1.78;fall.inputs['To Min'].default_value=1;fall.inputs['To Max'].default_value=0;fall.clamp=True
        links.new(distance.outputs['Value'],fall.inputs['Value'])
        alpha=nodes.new('ShaderNodeMath');alpha.operation='MULTIPLY';links.new(ramp.outputs[0],alpha.inputs[0]);links.new(fall.outputs[0],alpha.inputs[1]);links.new(alpha.outputs[0],p.inputs['Alpha'])
        p.inputs['Emission Color'].default_value=(.20,.32,.24,1);p.inputs['Emission Strength'].default_value=.10
        verts=[(0,0,.12)];faces=[];N=48
        for k in range(1,8):
            for j in range(N):
                a=j*math.tau/N;r=1.70*k/7*(1+.035*math.sin(a*7)+.03*math.cos(a*11))
                verts.append((r*math.cos(a),r*math.sin(a),.12+.08*math.sin(a*4+k)))
        faces.extend((0,1+j,1+(j+1)%N) for j in range(N))
        for k in range(6):
            u=1+k*N;v=u+N
            faces.extend((u+j,u+(j+1)%N,v+(j+1)%N,v+j) for j in range(N))
        ob=mesh('Continuous torn spore veil',verts,faces,haze,root);moving.append((ob,0))
        for j in range(62):
            a=j*2.399;r=1.70*math.sqrt((j+.5)/62)
            ob=c.sphere('Mint spore grain',(r*math.cos(a),r*math.sin(a),.12),(.012+(j%3)*.008,)*3,mats['glow'] if j%4==0 else mats['moss'],root);moving.append((ob,j))
    elif anim=='stump':
        s.camera.data.ortho_scale=w/(64*math.sqrt(2));s.camera.rotation_euler=(math.pi/3,0,0)
        s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,.45,12))
        for variant in range(4):
            par=c.empty('Stump variant '+str(variant),parent=root);variants.append(par)
            verts=[];N=11
            for z,r in ((.03,.40),(.25,.33),(.54,.26)):
                for j in range(N):
                    a=j*math.tau/N;zz=z+(rng.uniform(-.08,.12) if z>.5 else 0)
                    verts.append((r*math.cos(a),r*.84*math.sin(a),zz))
            faces=[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(2) for j in range(N)]
            faces.append(tuple(range(2*N,3*N)));mesh('Torn fibrous stump',verts,faces,mats['bark'],par)
            for j in range(5):
                a=j*math.tau/5+.2*variant
                rod('Stump root',[(.23*math.cos(a),.21*math.sin(a),.18),(.39*math.cos(a),.33*math.sin(a),.04),(.44*math.cos(a),.39*math.sin(a),.025)],.04,mats['wood'],par)
            rod('Split stump with foxfire sap',[(-.13,-.19,.54),(.02,-.08,.58),(-.04,.13,.57)],.016,mats['glow'],par)
            for j in range(11):
                a=j*math.tau/11;top=.50+rng.uniform(-.08,.08)
                rod('Stump torn bark fibre',[(.37*math.cos(a),.30*math.sin(a),.07),(.32*math.cos(a+.025),.27*math.sin(a+.025),.27),(.265*math.cos(a+.03),.22*math.sin(a+.03),top)],.018,mats['wood'] if j%2 else mats['bark'],par)
            for j in range(3):
                a=-1.1+j*.4
                rod('Ragged heartwood splinter',[(.20*math.cos(a),.17*math.sin(a),.43),(.23*math.cos(a),.20*math.sin(a),.61+j*.035)],.025,mats['wood'],par)
            for r in (.08,.15,.21):
                pts=[(r*math.cos(j*math.tau/18),r*.8*math.sin(j*math.tau/18),.55) for j in range(19)]
                rod('Weathered growth ring',pts,.008,mats['wood'],par)
    iso.bake_ao_shadows(root)
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def pose(a,i,n):
        for ob,(loc,rot,sc) in rest.items():ob.location=loc;ob.rotation_euler=rot;ob.scale=sc;ob.hide_render=False
        t=i/max(1,n-1)
        if a=='root_spike':
            for ob,j in moving:
                q=max(.04,min(1,(i-j*.10)/2));ob.scale=(1,q,q);ob.location.y=.03*math.sin(j+i)
        if a=='spore_cloud':
            for ob,j in moving:
                ob.rotation_euler.z=.25*math.sin(i*math.tau/n+j);ob.location.x+=.045*math.sin(i*math.tau/n+j);ob.location.y+=.045*math.cos(i*math.tau/n+j)
        if a=='stump':
            for j,par in enumerate(variants):
                par.hide_render=j!=i
                for ob in par.children_recursive:ob.hide_render=j!=i
    return root,pose

def render(args):
    from PIL import Image
    root,pose,mats=build();OUT.mkdir(parents=True,exist_ok=True)
    # Preserve all animation timelines in the delivered source, not just a still mesh.
    frame=1
    for a,(n,ds,size) in SPECS.items():
        if a.endswith('_dirs') or a in EXTRAS:continue
        bpy.context.scene.timeline_markers.new(a,frame=frame)
        for i in range(n):
            pose(a,i,n)
            for ob in [root,*root.children_recursive]:
                for prop in ('location','rotation_euler','scale','hide_render'):ob.keyframe_insert(prop,frame=frame+i)
        frame+=n+2
    bpy.context.scene.frame_end=frame;bpy.context.scene['n2d_contract']=json.dumps(SPECS)
    bpy.context.scene['pixels_per_unit']=64;bpy.context.scene['ground_pivot']=[128,220]
    SOURCE.parent.mkdir(parents=True,exist_ok=True);bpy.context.scene.render.filepath=''
    bpy.context.scene.frame_set(1);bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE),check_existing=False)
    # Explicit poses must not be overridden by stored animation curves during render.
    for ob in [root,*root.children_recursive]:ob.animation_data_clear()
    if args.bounds:
        from bpy_extras.object_utils import world_to_camera_view
        scene=bpy.context.scene;bad=[];bbox=[256,256,0,0]
        for a,(n,ds,size) in SPECS.items():
            if a in EXTRAS:continue
            for d in ds:
                for i in range(n):
                    pose(a.removesuffix('_dirs'),i,n);root.rotation_euler.z=c.DIRECTIONS[d];bpy.context.view_layer.update()
                    xy=[]
                    for ob in root.children_recursive:
                        if ob.hide_render or ob.type!='MESH':continue
                        if any(abs(x)<.002 for x in ob.matrix_world.to_scale()):continue
                        for v in ob.bound_box:
                            q=world_to_camera_view(scene,scene.camera,ob.matrix_world@Vector(v));xy.append((q.x*256,(1-q.y)*256))
                    box=(min(x for x,y in xy),min(y for x,y in xy),max(x for x,y in xy),max(y for x,y in xy))
                    bbox=[min(bbox[0],box[0]),min(bbox[1],box[1]),max(bbox[2],box[2]),max(bbox[3],box[3])]
                    if min(box[0],box[1],256-box[2],256-box[3])<5:bad.append((a,d,i,[round(v,1) for v in box]))
        print('BOUNDS', [round(x,1) for x in bbox], 'FAIL' if bad else 'PASS',bad[:6],flush=True)
        return
    with tempfile.TemporaryDirectory(prefix='rainfall_n2d_') as tmp:
        for a,(n,ds,size) in SPECS.items():
            if args.anims and a not in args.anims:continue
            w,h=dims(size);cols=min(n,4096//w);pages=math.ceil(n/cols)
            if args.resume and all((OUT/(a+('' if p==0 else f'_{p+1}')+suf+'.png')).exists() for p in range(pages) for suf in ('','_n','_e')):continue
            if a in EXTRAS:
                root,pose,mats=build()
                for ob in root.children_recursive:ob.hide_render=True
                root.hide_render=True
                root,pose=extra(a,mats)
            else:
                # Restore camera/model after an extra task or start fresh for deterministic phases.
                root,pose,mats=build()
            boards=[[Image.new('RGBA',(min(cols,n-p*cols)*w,h*len(ds)),(0,0,0,0)) for _ in range(3)] for p in range(pages)]
            for r,d in enumerate(ds):
                for i in range(n):
                    path=Path(tmp)/'frame.png'
                    c.render_still(root,lambda t:pose(a.removesuffix('_dirs'),i,n),path,0,d)
                    images=[]
                    for suf in ('','_n','_e'):
                        with Image.open(path.with_name('frame'+suf+'.png')) as src:images.append(src.convert('RGBA').resize((w,h),Image.Resampling.LANCZOS))
                    alpha=images[0].getchannel('A')
                    for k,im in enumerate(images):
                        im.putalpha(alpha);boards[i//cols][k].paste(im,(i%cols*w,r*h))
            for p,board in enumerate(boards):
                name=a+('' if p==0 else f'_{p+1}')
                for suf,im in zip(('','_n','_e'),board):im.save(OUT/(name+suf+'.png'),compress_level=9)
            print('N2D DONE',a,flush=True)
    write_tres();import_policy();contact();verify()
    (OUT/'manifest.md').write_text('N2D ? Le C?dre-Ermite. Tronc creux de c?dre noy?, fibres longitudinales sculpt?es, lichen brume, bronze corrod?, lanterne suspendue menthe #9CF0C8. Sans visage humain : la fente et le vide font le regard. Cordes de pri?re et tablettes de bois. P1 fente ?troite ; P2 valves de bois ?cart?es et huit racines plant?es, lanterne vuln?rable ; P3 racines arrach?es pleines de terre et charge vo?t?e. Mort : effondrement dans la souche, lanterne bascul?e et extinction.\n\nCellules corps 256px, dimension environ 190px et pieds vers y220 ; CREA30, Eevee12, AO et ombres internes cuites. Idle/walk ESWN par phase, auto6 et sorts8 en quatre directions ; impact exact frame3/4. Transitions8 et death10. Extras TOP64px/u : root_spike512x64, spore_cloud256x256 (diam?tre4u du consommateur), stump96x128 CREA90.5px/u, quatre variantes. Normales cam?ra Raw et emission Blender, alpha identique ; aucune planche >4096px.\n\nSource art/blender/monsters/hermit_cedar_iso.blend ; recette art/tools/night/n2d_build.py ; planche art/tools/night/_n2d_contact.png. R?utilisation du pipeline N2C/C7 et des mat?riaux ash_lord, sans modification de ces r?f?rences.\n',encoding='utf-8')


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--bounds',action='store_true');ap.add_argument('--resume',action='store_true');ap.add_argument('--anims',nargs='*');ap.add_argument('--verify',action='store_true');ap.add_argument('--contact',action='store_true');ap.add_argument('--import-policy',action='store_true')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ([] if 'bpy' in sys.modules else sys.argv[1:]))
    if args.verify:verify()
    elif args.contact:contact()
    elif args.import_policy:import_policy()
    else:render(args)
