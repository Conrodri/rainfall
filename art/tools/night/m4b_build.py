"""M4B: background Eevee sculpt/animation; python --pack assembles final atlases.
Reuse the approved Ash Lord materials, C0 rig and compositor. No interactive API.
"""
import sys, math, json, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
SOURCES=ROOT/'art/blender/monsters'
SPECS={'idle':(1,6),'run':(21,8),'attack':(41,6),'cast_a':(61,8),'cast_b':(81,8),'phase2':(101,8),'death':(121,10)}
IDS=('blind_lamplighter','sarcophagus_crab')
def directions(a): return ['e','s','w','n'] if a in ('run','attack','cast_a','cast_b') else ['s']
def specs(who): return SPECS

def pack():
    from PIL import Image
    sys.path.insert(0,str(ROOT/'art/tools'))
    import texture_budget
    budget=texture_budget.load_budget()
    checks=[]; rows=[]
    for who in IDS:
        out=ROOT/'game/assets/sprites/bosses/mini'/who;out.mkdir(parents=True,exist_ok=True)
        ext=[];sub=[];anims=[];count=0;minmargin=170
        for ai,(a,(start,n)) in enumerate(specs(who).items(),1):
            ds=directions(a)
            # Directional atlases use e,s,w,n; single direction animations use s.
            groups=[(a,ds)]
            for stem,dirs in groups:
                tid=str(len(ext)+1)
                ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/mini/{who}/{stem}.png" id="{tid}"]')
                for suffix in ('','_e'):
                    sheet=Image.new('RGBA',(n*170,len(dirs)*170))
                    for y,d in enumerate(dirs):
                        for i in range(n):
                            p=SOURCES/f'm4b_frames/{who}/{a}/{d}_{i:02d}{suffix}.png'
                            with Image.open(p) as src: cell=src.convert('RGBA');assert cell.size==(170,170)
                            sheet.paste(cell,(170*i,170*y))
                            if not suffix:
                                bb=cell.getchannel('A').getbbox();assert bb,(who,a,d,i)
                                margin=min(bb[0],bb[1],170-bb[2],170-bb[3]);minmargin=min(minmargin,margin)
                                assert margin>=2,(who,a,d,i,bb)
                    png=out/f'{stem}{suffix}.png'
                    
                    if suffix=='_e': sheet=sheet.resize(((sheet.width+1)//2,(sheet.height+1)//2),Image.Resampling.LANCZOS)
                    sheet.save(png,optimize=True,compress_level=9)
                    ip=png.with_suffix('.png.import')
                    if not ip.exists():
                        params=texture_budget.expected_params(png.relative_to(ROOT/'game').as_posix(),budget)
                        ip.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'+''.join(f'{k}={texture_budget._fmt(v)}\n' for k,v in params.items()))
                for d in dirs:
                    sequence=[SOURCES/f'm4b_frames/{who}/{a}/{d}_{i:02d}.png' for i in range(n)]
                    assert len({p.read_bytes() for p in sequence})>=3,(who,a,d,'poses static')
                with Image.open(out/f'{stem}_e.png') as emission:
                    assert max(hi for lo,hi in emission.convert('RGB').getextrema())>16,(who,stem,'missing emission')
                for y,d in enumerate(dirs):
                    frames=[]
                    for i in range(n):
                        sid=f'f{count}';count+=1
                        sub.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{tid}")\nregion = Rect2({i*170}, {y*170}, 170, 170)\n')
                        frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
                    anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+('true' if a in ('idle','run') else 'false')+', "name": &"'+a+'_'+d+'", "speed": '+str(14.0 if a=='run' else 12.0)+'}')
        tres='[gd_resource type="SpriteFrames" load_steps='+str(1+len(ext)+len(sub))+' format=3]\n\n'+'\n'.join(ext)+'\n\n'+'\n'.join(sub)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n'
        resource=out/f'{who}.tres'
        if resource.exists(): assert resource.read_text()==tres,'Existing contract differs; inspect before replacing'
        else: resource.write_text(tres)
    print("M4B_PACK_PASS",flush=True)

def build():
    import bpy
    from mathutils import Vector
    sys.path[:0]=[str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
    from common import empty, sphere, material, cube, pose
    from ash_lord_build import worn, mesh, rod, shard
    from boss_pipeline import key
    import iso_rig,cel_style as cel

    def slab(name,outline,z,height,mat,parent,bevel=.018):
        n=len(outline);v=[(x,y,z+h) for h in (0,height) for x,y in outline]
        return mesh(name,v,[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat,parent,bevel)

    def lantern(parent,name,loc,stone,metal,glow):
        lamp=empty(name,loc,parent)
        shard('Long fractured crystal',(0,0,0),(.12,.12,.28),glow,lamp)
        for z,r in [(-.26,.14),(.25,.11)]:
            outline=[(math.cos(j*math.tau/6)*r,math.sin(j*math.tau/6)*r) for j in range(6)]
            slab('Corroded hexagonal lantern cage',outline,z,.055,metal,lamp)
        for j in range(4):
            x,y=.13*math.cos(j*math.pi/2),.13*math.sin(j*math.pi/2)
            rod('Cage strut',[(x,y,-.24),(x,y,.23)],.014,metal,lamp)
        rod('Hanging hook',[(0,0,.28),(0,0,.39),(.045,0,.43)],.019,metal,lamp)
        return lamp

    def lamplighter():
        root=empty('Blind lamplighter ground');body=empty('Hunched pilgrim',parent=root)
        salt=worn('Wet salt crust cloth','737B7A','B4B0A2');bone=worn('Blind waxed linen and exposed bone','8C8778','CBC7B1')
        iron=worn('Salt corroded ferrules','515F62','93A4A3',.5);dark=worn('Deep folded sea leather','515D63','8C9697')
        glow=material('ONLY ACCENT - white cyan crystal','BFF4FF',2.2,True)
        # Continuous jagged garment, pinched waist and a sharply bent thoracic spine.
        levels=[(.20,.44,.27,.02),(.65,.32,.24,0),(1.03,.29,.23,-.05),(1.42,.38,.28,-.20),(1.76,.40,.30,-.31),(1.94,.25,.24,-.39)]
        v=[];N=12
        for k,(z,rx,ry,y) in enumerate(levels):
            for j in range(N):
                a=j*math.tau/N;v.append((rx*math.cos(a),y+ry*math.sin(a),z+(.10*(j%3) if k==0 else 0)))
        mesh('Continuous torn mantle',v,[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(len(levels)-1) for j in range(N)],salt,body)
        for j in range(9):
            a=j*math.tau/9
            rod('Raised salt encrusted cloak seam',[(.43*math.cos(a),.26*math.sin(a),.3),(.31*math.cos(a),.23*math.sin(a)-.04,1.02),(.38*math.cos(a),.29*math.sin(a)-.27,1.65)],.018,bone,body)
        head=empty('Eyeless bowed head',(0,-.57,1.88),body)
        shard('Long blind skull',(0,-.02,.13),(.20,.22,.29),bone,head)
        shard('Nasal bridge',(0,-.23,.12),(.055,.09,.12),bone,head)
        for z in [.16,.23,.30]:
            rod('Tight blindfold strip',[(-.19,-.10,z),(-.15,-.215,z-.02),(.15,-.215,z-.02),(.19,-.10,z)],.034,dark,head)
        for j in range(5):rod('Uneven exposed teeth',[((j-2)*.035,-.21,-.005),((j-2)*.035,-.22,-.055)],.012,bone,head)
        legs=[]
        for sign in [-1,1]:
            leg=empty('Bowed shin',(sign*.19,0,.52),body);legs.append(leg)
            rod('Shin wrapped in linen',[(0,0,0),(sign*.035,-.045,-.24),(sign*.05,-.15,-.43)],.075,dark,leg)
            shard('Salt bleached bare foot',(sign*.05,-.22,-.46),(.105,.20,.06),bone,leg)
            rod('Scapular bone',[(sign*.10,-.2,1.85),(sign*.40,-.30,1.65)],.06,bone,body)
        staff=empty('Perch hand and thrust fulcrum',(.40,-.38,1.20),body)
        rod('Bent iron capped staff',[(0,0,-.83),(0,0,.15),(.015,-.08,1.42),(-.20,-.08,1.52)],.035,dark,staff)
        for z in [-.90,.05,1.12]:rod('Silver staff binding',[(0,0,z),(0,0,z+.08)],.049,iron,staff)
        lamp=lantern(staff,'Suspended crystal lantern',(-.20,-.08,1.05),salt,iron,glow)
        for sign in [-1,1]:
            rod('Long bent arm',[(sign*.39,-.28,1.65),(sign*.48,-.59,1.20),(.40,-.39,1.23)],.065,salt,body)
        for j in range(4):rod('Hooked grasping finger',[(.34+j*.028,-.41,1.26),(.34+j*.028,-.45,1.16),(.34+j*.028,-.38,1.13)],.016,bone,body)
        left=lantern(body,'Phase two left hand lantern',(-.48,-.65,1.15),salt,iron,glow)
        planted=lantern(root,'Lantern lowered to ground',(.52,-.45,.31),salt,iron,glow)
        left.scale=(.001,)*3;planted.scale=(.001,)*3
        return root,body,head,legs,staff,lamp,left,planted

    def crab():
        root=empty('Sarcophagus crab ground');body=empty('Stone burial chamber',parent=root)
        stone=worn('Wet grey salt limestone','8C8778','B4B0A2');bone=worn('Old linen and bone','969180','C6C1AB')
        dark=worn('Chitin in salt water','546972','95A9AA');edge=worn('Cut stone bevels','757C77','A8B6AE')
        glow=material('ONLY ACCENT - cyan funerary joints','BFF4FF',1.8,True)
        outline=[(-.38,-.89),(.38,-.89),(.62,-.52),(.57,.70),(.34,.91),(-.34,.91),(-.57,.70),(-.62,-.52)]
        shard('Angular armored abdomen',(0,.05,.59),(.78,.94,.40),dark,body)
        slab('Eight sided ancient sarcophagus',outline,.68,.58,stone,body,.035)
        # Lid hinge runs along left longitudinal edge; mummy lies inside the box.
        lid=empty('Opening coffin lid',(-.61,0,1.29),body)
        slab('Chipped coffin cover',[(x+.61,y) for x,y in outline],0,.13,edge,lid,.025)
        for y in [-.62,-.25,.30,.65]:
            rod('Transverse carved inscription',[(.20,y,.145),(.46,y+.035,.15),(.67,y-.015,.15),(.96,y,.145)],.018,stone,lid)
        # Small carved death mask, angular, no eyes glowing.
        shard('Funerary face relief',(.61,-.39,.18),(.19,.25,.055),bone,lid)
        for x in [.53,.69]:rod('Mask recessed eye slit',[(x-.045,-.44,.235),(x+.045,-.44,.235)],.012,dark,lid)
        for i in range(8):
            a=outline[i];b=outline[(i+1)%8]
            rod('Light trapped in coffin joint',[(a[0]*1.007,a[1]*1.007,1.275),(b[0]*1.007,b[1]*1.007,1.275)],.018,glow,body)
        for sign in [-1,1]:
            for y in [-.57,.43]:
                rod('Limestone side retaining rib',[(sign*.60,y,.75),(sign*.62,y,1.15),(sign*.48,y,1.28)],.033,bone,body)
        mummy=empty('Exposed embalmed occupant',(0,0,1.18),body)
        shard('Wrapped mummy thorax',(0,.05,0),(.24,.47,.10),bone,mummy)
        shard('Mummy skull',(0,-.56,.035),(.16,.18,.13),bone,mummy)
        for x in [-.067,.067]:shard('Empty mummy eye socket',(x,-.66,.115),(.034,.042,.025),dark,mummy)
        for y in [-.25,-.10,.05,.20,.35]:rod('Linen rib binding',[(-.22,y,.06),(0,y-.035,.11),(.22,y,.06)],.023,edge,mummy)
        legs=[]
        for sign in [-1,1]:
            for j in range(3):
                y=-.40+j*.43;leg=empty('Articulated blade leg',(sign*.56,y,.56),body);legs.append((leg,sign,j))
                rod('Stone crust leg with pointed tarsus',[(0,0,0),(sign*.43,.13,.14),(sign*.77,.22,-.35),(sign*.82,.10,-.54)],.065,dark,leg)
                shard('Chipped knee guard',(sign*.43,.13,.14),(.14,.13,.12),stone,leg)
        claw=empty('Giant forward pincer',(-.66,-.63,.59),body)
        rod('Giant articulated claw arm',[(0,0,0),(-.20,-.26,.03),(-.11,-.56,.08)],.15,dark,claw)
        shard('Pincer palm',(-.09,-.58,.07),(.30,.34,.22),stone,claw)
        fingers=[]
        for sign in [-1,1]:
            finger=empty('Scissor pincer digit',(-.09+sign*.15,-.73,.08),claw);fingers.append((finger,sign))
            rod('Angular serrated pincer',[(0,0,0),(sign*.13,-.20,.04),(sign*.07,-.43,.015),(-sign*.12,-.52,-.015)],.11,stone,finger)
            for j in range(3):shard('Pincer inward serration',(-sign*.04,-.12-j*.09,0),(.06,.06,.055),bone,finger)
        small=empty('Small opposing claw',(.59,-.66,.55),body)
        rod('Slender feeding claw',[(0,0,0),(.22,-.23,-.05),(.12,-.51,0)],.08,dark,small)
        for x in [.04,.21]:rod('Fine feeding prong',[(.12,-.48,0),(x,-.71,.08)],.04,bone,small)
        return root,body,lid,legs,claw,fingers,small

    for who in IDS:
        if '--only' in sys.argv and who!=sys.argv[sys.argv.index('--only')+1]:continue
        s=iso_rig.create_rig('CREA',170)
        s.camera.data.ortho_scale=4.051028251647949
        s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,0,12))
        s.camera.data.shift_y=140/170-.5
        s.render.threads_mode='FIXED';s.render.threads=8
        ld=bpy.data.lights.new('M4B cold upper left rim','AREA');ld.energy=450;ld.color=(.65,.86,1);ld.shape='DISK';ld.size=2.5
        rim=bpy.data.objects.new('M4B cold upper left rim',ld);s.collection.objects.link(rim);rim.location=(-3,-1,5)
        rim.rotation_euler=(Vector((0,0,1))-rim.location).to_track_quat('-Z','Y').to_euler()
        obj=lamplighter() if who=='blind_lamplighter' else crab()
        root,body=obj[:2];root.scale=((1.04 if who=='blind_lamplighter' else .90),)*3
        controlled=list(obj[2:])
        for a,(start,n) in SPECS.items():
            for i in range(n):
                t=i/n*math.tau;p=i/(n-1)
                hit=([-.25,-.65,1,.45,.12,0][i] if a=='attack' else [-.08,-.38,-.70,1,.72,.40,.12,0][i] if a in ('cast_a','cast_b') else 0)
                death=p if a=='death' else 0
                body.location=(0,0,.025*math.sin(t) if a=='idle' else .035*math.sin(t*2) if a=='run' else 0)
                body.rotation_euler=(.018*math.cos(t) if a=='idle' else 0,0,0);body.scale=(1,1,1)
                if who=='blind_lamplighter':
                    _,_,head,legs,staff,lamp,left,planted=obj
                    head.rotation_euler.x=.06*math.sin(t)-.16*hit;head.rotation_euler.y=.04*math.cos(t)
                    staff.rotation_euler=(.08*math.sin(t),0,0);staff.location=(.40,-.38,1.20);staff.scale=(1,1,1)
                    lamp.location=(-.20,-.08,1.05);lamp.scale=(1,1,1);left.scale=(.001,)*3;planted.scale=(.001,)*3
                    if a=='attack':
                        staff.rotation_euler=(hit*.67,0,hit*.16);body.rotation_euler.x=hit*.10;body.location.y=.05*hit
                    elif a=='cast_a':
                        staff.rotation_euler=(-.32*max(hit,0),0,hit*.75);staff.location.z+=.22*max(hit,0)
                    elif a=='cast_b':
                        staff.rotation_euler.x=.7*hit
                        # Lower the crystal visibly to the floor on exactly frame 4.
                        planted.scale=(1,)*3 if i>=3 else (.001,)*3
                        if i>=3:lamp.scale=(.001,)*3
                        planted.location=(.52,-.45,.31)
                    elif a=='phase2':
                        q=min(1,p*2);left.scale=(max(.001,q),)*3;staff.scale=(max(.001,1-q),)*3
                        lamp.scale=(.001,)*3;planted.scale=(max(.001,q),)*3;planted.location=(.46,-.64,1.20)
                        # Final pose: one suspended lantern at each hand.
                    for j,leg in enumerate(legs):
                        leg.rotation_euler.x=.48*math.sin(t+j*math.pi) if a=='run' else 0
                        key(leg,start+i)
                    body.rotation_euler.x=-death*1.3;body.location.z-=death*.12
                    if a=='death':staff.scale=(1-death*.70,)*3
                    for ob in [head,staff,lamp,left,planted]:key(ob,start+i)
                else:
                    _,_,lid,legs,claw,fingers,small=obj
                    lid.rotation_euler.y=-1.55*p if a=='phase2' else -.30*death
                    claw.rotation_euler=(0,0,.08*math.sin(t));claw.location=(-.66,-.50,.59);claw.scale=(.86,)*3
                    if a=='attack':claw.rotation_euler.z=-.50*hit;claw.location.y-=.20*hit
                    if a=='cast_a':claw.location.y-=.36*hit;claw.rotation_euler.z=-.42*hit;body.location.y-=.10*hit
                    if a=='cast_b':
                        # Frame 4 reaches the hiding pose; the final frame stays buried.
                        sink=[0,.12,.45,.97,1.02,1.03,1.04,1.05][i]
                        body.location.z=-sink;body.scale.z=1-.18*min(1,sink)
                    for finger,sign in fingers:
                        opening=.16+.035*math.sin(t)
                        if a in ('attack','cast_a'):opening=.18+.50*max(0,-hit) if i<2+(a=='cast_a') else .03+.15*(1-max(0,hit))
                        finger.rotation_euler.z=sign*opening;key(finger,start+i)
                    for leg,sign,j in legs:
                        leg.rotation_euler=(.22*math.sin(t+j*1.8)*sign if a=='run' else 0,.10*math.sin(t+j) if a=='run' else 0,sign*.10*math.sin(t+j*1.6) if a=='run' else 0)
                        if a=='cast_b':leg.rotation_euler.y=sign*.65*min(1,i/3)
                        if a=='death':leg.rotation_euler.y=-sign*.80*death
                        key(leg,start+i)
                    body.rotation_euler.y=death*.35;body.location.z-=death*.37
                    for ob in [lid,claw,small]:key(ob,start+i)
                key(body,start+i)
            s.timeline_markers.new(a,frame=start)
        from bpy_extras.object_utils import world_to_camera_view
        offsets={}
        for d in ['e','s','w','n']:
            root.location=(0,0,0);pose(root,1,d)
            ys=[]
            for ob in s.objects:
                if ob.type!='MESH' or ob.name=='Invisible ground cutout':continue
                for vert in ob.data.vertices:
                    pt=ob.matrix_world@vert.co
                    if -.06<pt.z<.12:ys.append(world_to_camera_view(s,s.camera,pt).y)
            assert ys
            offsets[d]=((1-140/170)-min(ys))*s.camera.data.ortho_scale/.5
        s['ground_offsets']=json.dumps(offsets)
        s['animation_manifest']=json.dumps({a:{'start':start,'frames':n,'directions':directions(a),'loop':a in ('idle','run'),'fps':14 if a=='run' else 12} for a,(start,n) in SPECS.items()})
        s['m4b_contract']=json.dumps({'cell':170,'bottom':140,'ortho_scale':s.camera.data.ortho_scale,'impact_frames_1based':[3,4,4],'normals':False})
        s.frame_start=1;s.frame_end=130;s.render.fps=12
        pose(root,1,'s');root.location.y=offsets['s']
        cel.install('creature',normals=False)
        cel.setup_scene();cel.toon_materials('creature')
        # Actual world-space ground clipping, also present in the saved source.
        for mat in bpy.data.materials:
            if not mat.use_nodes or not mat.get('cel_done'):continue
            nt=mat.node_tree;ns=nt.nodes;lk=nt.links
            output=next(n for n in ns if n.type=='OUTPUT_MATERIAL')
            old=output.inputs['Surface'].links[0].from_socket
            geo=ns.new('ShaderNodeNewGeometry');sep=ns.new('ShaderNodeSeparateXYZ');test=ns.new('ShaderNodeMath');test.operation='LESS_THAN';test.inputs[1].default_value=0
            trans=ns.new('ShaderNodeBsdfTransparent');mix=ns.new('ShaderNodeMixShader')
            lk.new(geo.outputs['Position'],sep.inputs[0]);lk.new(sep.outputs['Z'],test.inputs[0]);lk.new(test.outputs[0],mix.inputs[0]);lk.new(old,mix.inputs[1]);lk.new(trans.outputs[0],mix.inputs[2]);lk.new(mix.outputs[0],output.inputs['Surface'])
            if hasattr(mat,'surface_render_method'):mat.surface_render_method='DITHERED'

        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCES/f'm4b_{who}.blend'))
        from PIL import Image
        for a,(start,n) in SPECS.items():
            if '--anim' in sys.argv and a not in sys.argv[sys.argv.index('--anim')+1].split(','):continue
            folder=SOURCES/f'm4b_frames/{who}/{a}';folder.mkdir(parents=True,exist_ok=True)
            for d in directions(a):
                for i in range(n):
                    dest=folder/f'{d}_{i:02d}.png'
                    if '--resume' in sys.argv and all(dest.with_stem(dest.stem+k).exists() for k in ('','_e')):continue
                    pose(root,start+i,d);root.location.y=offsets[d];bpy.context.view_layer.update()
                    iso_rig.common.configure_passes(dest)
                    s.render.filepath=str(dest);bpy.ops.render.render(write_still=True)
                    candidates=list(folder.glob(dest.stem+'_e__*.png'));assert len(candidates)==1
                    candidates[0].replace(dest.with_stem(dest.stem+'_e'))
                    for png in [dest,dest.with_stem(dest.stem+'_e')]:
                        with Image.open(png) as im:cell=im.convert('RGBA').resize((170,170),Image.Resampling.LANCZOS)
                        cell.save(png,optimize=True,compress_level=9)
            print('M4B_COMPLETE',who,a,flush=True)
    print('M4B_RENDER_PASS',flush=True)


def verify():
    from PIL import Image
    import numpy as np
    import re
    sys.path.insert(0,str(ROOT/'art/tools/cel'))
    import cel_style as cel
    report=[]
    for who in IDS:
        folder=ROOT/'game/assets/sprites/bosses/mini'/who
        for a,(_,n) in SPECS.items():
            rel=f'bosses/mini/{who}/{a}.png'
            cel.check_sheet(rel,cell=170,frames=n,rows=len(directions(a)),normals=False)
            with Image.open(folder/f'{a}.png') as im:
                assert im.size==(n*170,len(directions(a))*170)
                assert max(im.size)<=4096
                for y,d in enumerate(directions(a)):
                    for i in range(n):
                        cell=im.crop((i*170,y*170,(i+1)*170,(y+1)*170));b=cell.getchannel('A').getbbox()
                        assert b and min(b[0],b[1],170-b[2],170-b[3])>=2,(who,a,d,i,b)
            with Image.open(folder/f'{a}_e.png') as im:
                assert im.size==(n*85,len(directions(a))*85)
                ar=np.array(im);assert float((ar[:,:,:3].max(axis=2)* (ar[:,:,3]/255)).max())>16
            report.append({'id':who,'animation':a,'frames':n,'rows':len(directions(a))})
        assert not list(folder.glob('*_n.png'))
        t=(folder/f'{who}.tres').read_text();assert 'CanvasTexture' not in t and 'normal_texture' not in t
        animations=re.findall(r'\{"frames": \[(.*?)\], "loop": (true|false), "name": &"([^"]+)", "speed": ([0-9.]+)\}',t,re.S)
        expected={f'{a}_{d}':(n,a in ('idle','run'),14 if a=='run' else 12)
                  for a,(_,n) in SPECS.items() for d in directions(a)}
        assert len(animations)==len(expected),(who,'animation count')
        for frames,loop,name,speed in animations:
            assert name in expected,(who,'unexpected animation',name)
            assert (frames.count('SubResource('),loop=='true',float(speed))==expected.pop(name),(who,name,'frames/loop/fps')
        assert not expected,(who,'missing animations',expected)
    # One contact only. Unscaled top row aligns the foot lines of the two minis,
    # the floor-four Recluse and Ash Lord; lower rows document every gesture.
    board=Image.new('RGBA',(1360,1220),(46,50,56,255))
    samples=[('bosses/mini/blind_lamplighter/idle.png',170,0,0,140),('bosses/mini/sarcophagus_crab/idle.png',170,0,0,140),('bosses/etage/recluse/idle_p1.png',256,0,0,215),('bosses/mini/ash_lord/idle.png',170,0,0,119)]
    for j,(rel,c,x,y,bottom) in enumerate(samples):
        p=ROOT/'game/assets/sprites'/rel
        if not p.exists() and 'recluse' in rel:
            p=next((ROOT/'game/assets/sprites/bosses/etage/recluse').glob('idle*.png'))
        with Image.open(p) as im:crop=im.convert('RGBA').crop((x*c,y*c,(x+1)*c,(y+1)*c))
        board.alpha_composite(crop,(j*300+30,225-bottom))
    selections=[('idle','s',0),('run','e',2),('attack','e',1),('attack','e',2),('attack','s',2),('cast_a','s',3),('cast_b','s',0),('cast_b','s',3),('cast_b','s',7),('phase2','s',7),('death','s',9)]
    for j,who in enumerate(IDS):
        for k,(a,d,i) in enumerate(selections):
            with Image.open(SOURCES/f'm4b_frames/{who}/{a}/{d}_{i:02d}.png') as im:cell=im.convert('RGBA')
            board.alpha_composite(cell,((k%6)*190,270+j*360+(k//6)*175))
    refs=['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png']
    for j,rel in enumerate(refs):
        with Image.open(ROOT/rel) as im:
            ref=im.convert('RGBA')
            if j==3:ref=ref.crop((ref.width//2,0,ref.width,ref.height))
            ref.thumbnail((325,220));board.alpha_composite(ref,(j*338,995))
    board.convert('RGB').save(HERE/'_m4b_contact.png',optimize=True)
    (HERE/'_m4b_verification.json').write_text(json.dumps({'result':'PASS','cell':170,'bottom':140,'ortho_scale':4.051028251647949,'impact_1based':{'attack':3,'cast_a':4,'cast_b':4},'normals':False,'emission_scale':.5,'assets':report},indent=2))
    print('M4B_VERIFY_PASS')

if __name__=='__main__':
    if '--pack' in sys.argv: pack()
    elif '--verify' in sys.argv: verify()
    else: build()
