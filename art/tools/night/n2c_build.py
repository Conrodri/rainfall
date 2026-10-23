"""N2C La Tisseuse. Blender background only; --resume skips complete atlases.
Reuses official ash_lord worn materials, CREA rig, AO, and boss normal/emission compositor.
System Python --verify / --contact. No painting: Pillow only packs rendered pixels.
"""
import sys, math, json, re, tempfile, argparse, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
if '--background' in sys.argv:
    sys.path[:0]=[str(ROOT/'art/tools/iso/_deps'),str(Path.home()/'AppData/Local/RainfallIsoDeps')]
OUT=ROOT/'game/assets/sprites/bosses/etage/weaver'
SOURCE=ROOT/'art/blender/monsters/weaver_iso.blend'
CONTACT=ROOT/'art/tools/night/_n2c_contact.png'
SPECS={**{f'idle_p{p}':(6,['s'],256) for p in (1,2,3)},
       **{f'walk_p{p}':(8,['e','s','w','n'],256) for p in (1,2,3)},
       **{a:(n,['s'],256) for a,n in [('auto',6),('spell_a',8),('spell_b',8),('trans_p2',8),('trans_p3',8),('death',10),('ascend',8),('drop',8)]},
       **{a+'_dirs':(n,['e','w','n'],256) for a,n in [('auto',6),('spell_a',8),('spell_b',8)]},
       'thread':(6,['s'],(776,60)), 'web':(6,['s'],776), 'cocoon':(8,['s'],80), 'drop_dust':(8,['s'],392),
       'ground_silk':(6,['s'],136)}

def dims(size):return (size,size) if isinstance(size,int) else size

def write_tres():
    ext=[]; sub=[]; anims=[]
    for a,(n,ds,size) in SPECS.items():
        w,h=dims(size); cols=min(n,4096//w)
        for page in range(math.ceil(n/cols)):
            name=a+('' if page==0 else f'_{page+1}')
            ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/weaver/{name}.png" id="{name}"]')
        for row,d in enumerate(ds):
            ids=[]
            for i in range(n):
                page=i//cols; name=a+('' if page==0 else f'_{page+1}'); ident=f'{a}_{d}_{i}'
                sub.append(f'[sub_resource type="AtlasTexture" id="{ident}"]\natlas = ExtResource("{name}")\nregion = Rect2({i%cols*w}, {row*h}, {w}, {h})')
                ids.append('{"duration": 1.0, "texture": SubResource("'+ident+'")}')
            base=a.removesuffix('_dirs')
            name=base+'_'+d if a not in ('thread','web','cocoon','drop_dust','ground_silk') else a
            loop=a.startswith(('idle','walk')) or a in ('thread','web','cocoon','ground_silk')
            anims.append('{"frames": ['+', '.join(ids)+f'], "loop": {str(loop).lower()}, "name": &"{name}", "speed": {14.0 if a.startswith("walk") else 12.0}'+'}')
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'weaver.tres').write_text(f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(sub)+1} format=3]\n\n'+'\n\n'.join(ext+sub)+'\n\n[resource]\nanimations = ['+',\n'.join(anims)+']\n',encoding='utf-8')

def contact():
    from PIL import Image
    rows=[]
    # Order: phases, locomotion ESWN, bite/casts four directions, transitions/death, extras, references.
    samples=[(f'idle_p{p}',0) for p in (1,2,3)]+[('walk_p1',r) for r in range(4)]
    samples += [(a,r) for a in ('auto','auto_dirs','spell_a','spell_a_dirs','spell_b','spell_b_dirs') for r in range(len(SPECS[a][1]))]
    samples += [(a,0) for a in ('trans_p2','trans_p3','death','ascend','drop','thread','web','cocoon','drop_dust','ground_silk')]
    for a,r in samples:
        n,ds,size=SPECS[a];w,h=dims(size);cols=min(n,4096//w)
        row=Image.new('RGBA',(960,128),(26,30,29,255))
        for k,i in enumerate((0,n//2,n-1)):
            page=i//cols;name=a+('' if page==0 else f'_{page+1}')
            for off,suf in ((0,''),(3,'_n')):
                with Image.open(OUT/f'{name}{suf}.png') as src:
                    im=src.crop((i%cols*w,r*h,(i%cols+1)*w,(r+1)*h)).convert('RGBA')
                im.thumbnail((156,124),Image.Resampling.LANCZOS)
                row.alpha_composite(im,((k+off)*160+(160-im.width)//2,(128-im.height)//2))
        rows.append(row)
    row=Image.new('RGBA',(960,160),(26,30,29,255))
    for k,path in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png')):
        with Image.open(ROOT/path) as src:im=src.convert('RGBA').crop((0,0,min(src.width,640),min(src.height,320)))
        im.thumbnail((320,160),Image.Resampling.LANCZOS);row.alpha_composite(im,(k*320,0))
    references=row
    half=math.ceil(len(rows)/2)
    out=Image.new('RGBA',(1920,256+half*128+160),(26,30,29,255))
    for k,(a,i) in enumerate((('idle_p1',0),('idle_p2',0),('idle_p3',0),('auto',2),('auto',3),('death',9))):
        with Image.open(OUT/f'{a}.png') as src:im=src.convert('RGBA').crop((i*256,0,(i+1)*256,256))
        out.alpha_composite(im,(k*256,0))
    for j,row in enumerate(rows):out.paste(row,((j//half)*960,256+(j%half)*128))
    out.paste(references,(0,256+half*128))
    for j in range(3):
        with Image.open(OUT/f'idle_p{j+1}_e.png') as src:im=src.convert('RGBA').crop((0,0,256,256))
        im.thumbnail((160,160),Image.Resampling.LANCZOS);out.alpha_composite(im,(1000+j*240,256+half*128))
    out.save(CONTACT,compress_level=9)
    print('PASS contact',flush=True)

def verify():
    from PIL import Image,ImageChops
    txt=(OUT/'weaver.tres').read_text();bad=[];count=0;maxside=0;hashes={}
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
                    cell=ims[0].crop((j*w,r*h,(j+1)*w,(r+1)*h))
                    hashes.setdefault((a,r),[]).append(hashlib.sha256(cell.tobytes()).digest())
                    box=cell.getchannel('A').getbbox();count+=1
                    if box and min(box[0],box[1],w-box[2],h-box[3])<4:bad.append([name,r,j,box])
    assert not bad,bad[:8]
    assert all(len(set(v))==len(v) for v in hashes.values()),'duplicate animation frames'
    names=re.findall(r'"name": &"([^"]+)"',txt)
    assert len(names)==len(set(names))
    assert len(re.findall('type="AtlasTexture"',txt))==count
    print(f'PASS verify: {len(names)} animations, {count} frames, matching alpha, margins >=4px, max atlas {maxside}px',flush=True)

def build():
    global bpy,c,iso,Vector,worn,rod,mesh
    import bpy
    from mathutils import Vector
    for p in ('bosses','monsters','iso'):sys.path.insert(0,str(ROOT/'art/tools'/p))
    import boss_common as c
    import iso_rig as iso
    from ash_lord_build import worn,rod,mesh
    s=iso.create_rig('CREA',256);s.eevee.taa_render_samples=12
    s.camera.data.ortho_scale=4;s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,.8,0))
    s.render.resolution_x=s.render.resolution_y=384
    bpy.data.objects['Fill_froid'].data.energy=220
    wood=worn('Waterlogged split yew','151B19','4F5141',0,.88)
    bone=worn('Lichen stained ceramic reliquary','303E36','899382',.12,.73)
    iron=worn('Corroded iron braces','121919','424F48',.68,.63)
    silk=worn('Old damp shroud','363E37','A4AA91',0,.88)
    moss=worn('Dead moss','1B241B','4C5840',0,.95)
    glow=c.material('Foxfire mint single accent',(.25,.57,.39),roughness=.5,emission=1.3)
    root=c.empty('WEAVER_ROOT'); body=c.empty('Thorax',parent=root)
    abd=c.empty('Lantern abdomen',(0,.5,1.15),body)
    c.sphere('Charred lantern wick',(0,0,-.12),(.19,.44,.16),iron,abd)
    c.sphere('Sealed foxfire heart',(0,-.03,0),(.32,.63,.35),glow,abd)
    phase2=[];phase3=[]
    # Separated curved shell strips: physical cracks reveal a recessed luminous core.
    for j in range(11):
        a=j*math.tau/11;verts=[]
        for z,r in ((-.43,.38),(-.28,.83),(.08,1),(.32,.79),(.48,.3)):
            for off in (-.20,.20):
                ang=a+off;verts.append((.56*r*math.cos(ang),.82*r*math.sin(ang),z))
        ob=mesh(f'Cracked ceramic shutter {j}',verts,[(k,k+1,k+3,k+2) for k in (0,2,4,6)],bone,abd,.008)
        ob.modifiers.new('Ceramic thickness','SOLIDIFY').thickness=.035
        if j in (1,4,7):phase2.append(ob)
        if j in (2,8):phase3.append(ob)
        rod('Forged lantern rib',[(.58*r*math.cos(a),.84*r*math.sin(a),z) for z,r in ((-.46,.4),(-.28,.9),(.12,1.04),(.36,.74),(.52,.28))],.028,iron,abd)
        for z in (-.22,.23):c.sphere('Verdigris rivet',(.56*math.cos(a),.82*math.sin(a),z),(.035,.035,.035),iron,abd)
    for k in range(6):
        z=-.34+k*.14
        pts=[(.57*math.cos(j*math.tau/40),.85*math.sin(j*math.tau/40),z+.025*math.sin(j*.7+k)) for j in range(41)]
        rod('Silk ligature around reliquary',pts,.010,silk,abd)
    c.sphere('Thoracic heartwood',(0,-.35,.89),(.40,.55,.30),wood,body)
    for k in range(4):
        c.sphere('Overlapping thoracic scute',(0,-.09-k*.22,1.05),(.35-k*.035,.18,.15),bone,body)
    head=c.empty('Narrow death mask',(0,-.78,.88),body)
    # A tapered mask, small relative to abdomen; no bulbous eyes.
    mesh('Broken shrine mask',[(-.24,.07,.14),(.24,.07,.14),(.16,-.21,.04),(-.16,-.21,.04),(-.08,-.28,-.18),(.08,-.28,-.18)],[(0,1,2,3),(3,2,5,4),(0,3,4),(1,5,2)],bone,head,.015)
    jaws=[]
    for side in (-1,1):
        rod('Slit in mask',[(side*.08,-.22,.015),(side*.17,-.14,.065)],.014,glow,head)
        jaw=c.empty('Hooked mandible',(side*.13,-.17,-.09),head)
        jaws.append((jaw,side))
        rod('Biting yew fang',[(0,0,0),(side*.13,-.15,-.10),(side*.08,-.29,-.17),(0,-.27,-.23)],.065,iron,jaw)
    legs=[]
    for side in (-1,1):
        for j in range(4):
            yy=-.57+j*.38;fan=(-.65,-.26,.30,.69)[j]
            hip=c.empty(f'Leg {side} {j}',(side*.29,yy,.91),body)
            knee=(side*(.68+(.10 if j in (1,2) else 0)),fan,.35)
            tip=(side*(1.25+(.08 if j in (1,2) else 0)),fan*1.48,-.84)
            rod('Splintered femur',[(0,0,0),(knee[0]*.5,knee[1]*.5,.24),knee],.085,wood,hip)
            lower=c.empty('Patella',knee,hip)
            end=Vector(tip)-Vector(knee)
            rod('Tapered tibia',[(0,0,0),tuple(end*.60+Vector((side*.10,0,.08))),tuple(end),tuple(end+Vector((-side*.04,-.05,-.04)))],.065,wood,lower)
            c.sphere('Weathered joint collar',(0,0,0),(.12,.13,.11),iron,lower)
            for kk in (1,2):
                rod('Sharp root thorn',[(side*.30*kk,fan*.4*kk,.24),(side*(.30*kk+.12),fan*.4*kk-.08,.46)],.026,wood,hip)
            legs.append((hip,lower,side,j))
    # Ragged votive tags, grown into the wooden legs, and moss knots on the shell.
    for j in range(7):
        a=j*math.tau/7
        c.sphere('Moss on ceramic',(.45*math.cos(a),.7*math.sin(a),.33),(.12,.16,.045),moss,abd)
    for side in (-1,1):
        rod('Suspended votive wire',[(side*.46,.2,.12),(side*.56,.18,-.27)],.012,iron,abd)
        c.box('Torn funerary tablet',(side*.56,.18,-.30),(.12,.027,.20),bone,abd,.008)
    sacs=[]
    for j in range(6):
        a=j*math.tau/6;ob=c.sphere('Brood cocoon',(math.cos(a)*.48,.46+math.sin(a)*.58,.69),(.12,.16,.18),silk,body);sacs.append(ob)
        rod('Cocoon luminous seam',[(math.cos(a)*.51,.46+math.sin(a)*.61,.61),(math.cos(a)*.53,.46+math.sin(a)*.63,.77)],.013,glow,body)
    # Small ruined sanctuary roof: chipped asymmetric eaves, iron finial, slate slits.
    for side in (-1,1):
        mesh('Broken votive roof',[(0,.02,.58),(0,.98,.58),(side*.50,1.03,.35),(side*.64,.05,.33)],[(0,1,2,3)],iron,abd,.012).modifiers.new('Roof thickness','SOLIDIFY').thickness=.035
        for k in range(5):
            y=.13+k*.18
            rod('Roof engraved ridge',[(side*.06,y,.58),(side*.45,y,.40)],.012,bone,abd)
    rod('Bent shrine finial',[(0,.51,.56),(.025,.52,.79),(-.045,.52,.86)],.026,iron,abd)
    # Uneven silk catenaries attach to the rear legs rather than floating ornaments.
    for side in (-1,1):
        for k in range(3):
            rod('Funerary catenary',[(side*.38,.48,.87),(side*.69,.72+k*.08,.44-k*.04),(side*1.06,.91+k*.04,.35)],.008,silk,body)
    iso.bake_ao_shadows(root)
    def pose(anim,i,n):
        t=i/max(1,n-1);cy=i/n*math.tau;ph=int(anim[-1]) if anim.startswith(('idle_p','walk_p')) else 1
        if anim=='trans_p2':ph=2 if t>=.5 else 1
        if anim in ('trans_p3','death'):ph=3
        root.location=(0,0,0);root.scale=(1,1,1);body.location=(0,0,0);body.rotation_euler=(0,0,0)
        abd.rotation_euler=(0,0,0);head.rotation_euler=(0,0,0)
        for ob in phase2:ob.hide_render=ph>=2
        for ob in phase3:ob.hide_render=ph>=3
        for ob in sacs:ob.hide_render=ph<3
        breath=math.sin(cy)*.018
        body.location.z=breath;abd.rotation_euler.x=breath
        bite=math.sin(math.pi*t)**2
        for jaw,side in jaws:jaw.rotation_euler.z=side*((.38 if t<=.4 else -.50)*bite if anim=='auto' else .025*math.sin(cy))
        glow.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value=1.1+.5*(ph-1)+.13*math.sin(cy)
        if anim=='auto':
            thrust=(-.13 if t<=.4 else .14)*bite;body.location.y=-thrust;head.rotation_euler.x=-.35*bite
        if anim=='spell_a':abd.rotation_euler.x=-.24*bite;body.location.z=.10*bite
        if anim.startswith('trans'):abd.rotation_euler.y=.14*math.sin(cy*2);body.location.z=.14*bite
        if anim in ('spell_b','ascend','drop'):
            z=math.sin(math.pi*t)*.65 if anim=='spell_b' else (.8*t if anim=='ascend' else .8*(1-t))
            # Canopy silhouette contracts before leaving; avoid an overlarge empty render cell.
            body.location.z=z;root.scale=(1-.25*z,)*3
            if (anim=='ascend' and i==n-1) or (anim=='drop' and i==0):root.scale=(0,0,0)
        if anim=='death':body.location.z=-.34*t;body.rotation_euler.y=.10*t;abd.rotation_euler.x=.55*t
        for hip,lower,side,j in legs:
            walk=anim.startswith('walk');wave=math.sin(cy+(j%2)*math.pi+(0 if side==1 else math.pi))
            stride=math.cos(cy+(j%2)*math.pi+(0 if side==1 else math.pi))
            hip.rotation_euler=(.055*wave if walk else .015*math.sin(cy+j),side*.045*wave if walk else 0,side*.050*stride if walk else 0)
            lower.rotation_euler=(.09*max(0,wave) if walk else 0,side*.09*max(0,wave) if walk else 0,0)
            if anim=='auto' and j==0:hip.rotation_euler.x=-.12*bite
            if anim in ('spell_b','ascend','drop'):hip.rotation_euler.y=-side*.36*math.sin(math.pi*t)
            if anim=='death':hip.rotation_euler.y=side*.50*t;lower.rotation_euler.y=side*1.4*t
    return root,pose,{'wood':wood,'bone':bone,'silk':silk,'glow':glow,'iron':iron}

def extra(anim,mats):
    root=c.empty('EXTRA_'+anim);s=bpy.context.scene
    w,h=dims(SPECS[anim][2]);s.render.resolution_x=w;s.render.resolution_y=h
    s.camera.data.ortho_scale=w/64;s.camera.location=(0,0,12);s.camera.rotation_euler=(0,0,0)
    moving=[]
    if anim=='cocoon':
        # TOP framing uses the same 64px/u; physical hanging cocoon on the ground.
        c.sphere('Silken egg',(0,0,0),(.36,.48,.30),mats['silk'],root)
        for k in range(12):
            a=k*math.tau/12
            rod('Tight cocoon wrapping',[(-.32,math.sin(a)*.42,math.cos(a)*.23),(.0,math.sin(a+.2)*.49,math.cos(a+.2)*.31),(.32,math.sin(a+.3)*.42,math.cos(a+.3)*.23)],.012,mats['iron'],root)
        rod('Egg split',[(0,-.32,.27),(.045,-.15,.31),(-.035,.10,.31),(0,.32,.27)],.019,mats['glow'],root)
    elif anim in ('thread','ground_silk'):
        half=5.95 if anim=='thread' else .91
        for k in range(7):
            y=(k-3)*(.055 if anim=='thread' else .08)
            rod('Dragged silk cable',[(-half,y,0),(-half*.3,y+.05,.03),(half*.4,y-.03,.025),(half,y,0)],.012 if k%2 else .018,mats['silk'] if k%3 else mats['glow'],root)
        for k in range(17 if anim=='thread' else 5):
            x=-(half-.10)+2*(half-.10)*k/(16 if anim=='thread' else 4)
            rod('Silk crossbar',[(x-.08,-.2,0),(x+.08,.20,0)],.009,mats['iron'],root)
    elif anim=='web':
        # Six unit ring, two opposite navigable breaches, 64px/u, four px border.
        for off in (-.08,0,.08):
            for start,end in ((.20,math.pi-.20),(math.pi+.20,math.tau-.20)):
                points=[((5.87+off)*math.cos(start+(end-start)*j/100),(5.87+off)*math.sin(start+(end-start)*j/100),0) for j in range(101)]
                rod('Web ring with two breaches',points,.019,mats['glow'] if off==0 else mats['silk'],root)
        for j in range(44):
            a=j*math.tau/44
            if abs(math.sin(a))<.22:continue
            rod('Web radial knot',[(5.7*math.cos(a),5.7*math.sin(a),0),(5.96*math.cos(a+.008),5.96*math.sin(a+.008),0)],.015,mats['silk'],root)
    elif anim=='drop_dust':
        for j in range(24):
            a=j*math.tau/24
            ob=c.sphere('Splinter and foxfire dust',(math.cos(a),math.sin(a),0),(.12,.035,.025),mats['glow'] if j%4==0 else mats['wood'],root)
            ob.rotation_euler.z=a;moving.append((ob,a,j))
    def pose(a,i,n):
        t=i/(n-1);root.scale=(1,1,1)
        wave=math.sin(i/n*math.tau)+.17*math.cos(i/n*math.tau)
        mats['glow'].node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value=1.25+.35*wave
        if a in ('thread','ground_silk'):root.scale.y=1+.05*wave
        if a=='web':root.rotation_euler.z=.0015*wave
        if a=='cocoon':root.scale=(1+.025*math.sin(t*math.tau),1-.025*math.sin(t*math.tau),1)
        if a=='drop_dust':
            for ob,ang,j in moving:
                r=.35+2.3*t;ob.location=(r*math.cos(ang),r*math.sin(ang),0);ob.scale=(.10*(1-t)+.015,.025*(1-t)+.006,.025)
            if i==n-1:root.scale=(0,0,0)
    return root,pose

def render(args):
    from PIL import Image
    root,pose,mats=build();OUT.mkdir(parents=True,exist_ok=True)
    if args.bounds:
        bad=[];minimum=1000
        camera_inverse=bpy.context.scene.camera.matrix_world.inverted()
        for a,(n,ds,size) in SPECS.items():
            if a in ('thread','web','cocoon','drop_dust','ground_silk'):continue
            for d in ds:
                for i in range(n):
                    pose(a.removesuffix('_dirs'),i,n);root.rotation_euler.z=c.DIRECTIONS[d];bpy.context.view_layer.update()
                    points=[]
                    for ob in root.children_recursive:
                        if ob.type!='MESH' or ob.hide_render:continue
                        matrix=camera_inverse@ob.matrix_world
                        points.extend(matrix@v.co for v in ob.data.vertices)
                    bounds=((.5+min(p.x for p in points)/4)*256,(.5+min(p.y for p in points)/4)*256,(.5-max(p.x for p in points)/4)*256,(.5-max(p.y for p in points)/4)*256)
                    minimum=min(minimum,*bounds)
                    if min(bounds)<5:bad.append((a,d,i,[round(v,1) for v in bounds]))
        worst={}
        for a,d,i,b in bad:
            if a not in worst or min(b)<min(worst[a][2]):worst[a]=(d,i,b)
        print('BOUNDS',round(minimum,2),'FAIL' if bad else 'PASS',worst,flush=True);return
    # Preserve all animation timelines in the delivered source, not just a still mesh.
    frame=1
    for a,(n,ds,size) in SPECS.items():
        if a.endswith('_dirs') or a in ('thread','web','cocoon','drop_dust','ground_silk'):continue
        bpy.context.scene.timeline_markers.new(a,frame=frame)
        for i in range(n):
            pose(a,i,n)
            for ob in [root,*root.children_recursive]:
                for prop in ('location','rotation_euler','scale','hide_render'):ob.keyframe_insert(prop,frame=frame+i)
        frame+=n+2
    for action in bpy.data.actions:
        # Source uses sampled keys; renders below evaluate explicit absolute poses.
        pass
    bpy.context.scene.frame_end=frame;bpy.context.scene['n2c_contract']=json.dumps(SPECS)
    bpy.context.scene['pixels_per_unit']=64;bpy.context.scene['ground_pivot']=[128,179.2]
    SOURCE.parent.mkdir(parents=True,exist_ok=True);bpy.context.scene.render.filepath=''
    bpy.context.scene.frame_set(1);bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE),check_existing=False)
    # Explicit poses must not be overridden by stored animation curves during render.
    for ob in [root,*root.children_recursive]:ob.animation_data_clear()
    with tempfile.TemporaryDirectory(prefix='rainfall_n2c_') as tmp:
        for a,(n,ds,size) in SPECS.items():
            if args.anims and a not in args.anims:continue
            w,h=dims(size);cols=min(n,4096//w);pages=math.ceil(n/cols)
            if args.resume and all((OUT/(a+('' if p==0 else f'_{p+1}')+suf+'.png')).exists() for p in range(pages) for suf in ('','_n','_e')):continue
            if a in ('thread','web','cocoon','drop_dust','ground_silk'):
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
            print('N2C DONE',a,flush=True)
    write_tres();write_imports();contact();verify()
    (OUT/'manifest.md').write_text('N2C — La Tisseuse\n\nAraignee-sanctuaire 3,3 u : if detrempe, reliquaire de ceramique lichenisee, armatures de fer corrode, ligatures de soie funeraire. Accent unique feu follet menthe. Phase 2 : trois volets brises exposent le foyer ; phase 3 : deux autres volets arrachés et six poches de ponte. Huit pattes articulees, masque effile et crochets.\n\nCREA 30 deg, 64 px/u, pivot creature (128,179.2), Eevee12, AO et ombres internes dans le diffus. Normales camera Raw, emission Blender, alpha identique. Pas de planche >4096 : web et thread sur deux atlases chacun, memes decoupes pour _n/_e. Anneau 6u avec deux breches ; fils 12u ; retombee rayon3u ; cocon1u. Attaques et transitions non bouclees, impact morsure frame3/6. Les extras ascend_s, drop_s, drop_dust, thread et cocoon correspondent aux noms lus par weaver_brain/weaver_snare.\n\nSource art/blender/monsters/weaver_iso.blend ; recette art/tools/night/n2c_build.py ; controle art/tools/night/_n2c_contact.png.\n',encoding='utf-8')

def write_imports():
    # Reuse the project's policy, strictly restricted to this asset directory.
    sys.path.insert(0,str(ROOT/'art/tools'))
    import texture_budget as budget
    policy=budget.load_budget()
    for path in OUT.glob('*.png'):
        ip=path.with_suffix('.png.import')
        txt=ip.read_text() if ip.exists() else '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'
        for key,val in budget.expected_params(path.relative_to(ROOT/'game').as_posix(),policy).items():
            value=budget._fmt(val)
            if re.search('^'+re.escape(key)+'=',txt,re.M):txt=re.sub('^'+re.escape(key)+'=.*$',key+'='+value,txt,flags=re.M)
            else:txt+='\n'+key+'='+value+'\n'
        ip.write_text(txt,encoding='utf-8')

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--resume',action='store_true');ap.add_argument('--anims',nargs='*');ap.add_argument('--verify',action='store_true');ap.add_argument('--contact',action='store_true');ap.add_argument('--bounds',action='store_true')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ([] if '--background' in sys.argv else sys.argv[1:]))
    if args.verify:verify()
    elif args.contact:contact()
    else:render(args)
