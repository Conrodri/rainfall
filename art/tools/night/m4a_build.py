"""M4A. Background Blender only; --pack uses Pillow solely for atlas assembly/checks.
Shared Ash Lord geometry tools, C0/R9 camera and mandatory creature cel compositor.
No normal textures. Resume: blender -b --python this.py -- --resume [--only ID].
"""
import sys, math, json, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
SOURCE=ROOT/'art/blender/monsters'
FRAMES=SOURCE/'m4a_frames'
IDS=('ossuary_bearer','blind_swarm','salt_golem')
SPECS={'idle':(1,6),'run':(21,8),'attack':(41,6),'cast_a':(61,8),'cast_b':(81,8),'phase2':(101,8),'death':(121,10)}
GEOM={'ossuary_bearer':(120,140),'blind_swarm':(110,135),'salt_golem':(125,140)}
def dirs(a):return ['e','s','w','n'] if a in ('run','attack','cast_a','cast_b') else ['s']
def selected():return sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else IDS

def pack():
    from PIL import Image
    sys.path.insert(0,str(ROOT/'art/tools'))
    import texture_budget
    sys.path.insert(0,str(ROOT/'art/tools/cel'))
    import cel_style as cel
    budget=texture_budget.load_budget();report=[]
    for who in selected():
        out=ROOT/'game/assets/sprites/bosses/mini'/who;out.mkdir(parents=True,exist_ok=True)
        ext=[];sub=[];anims=[];bounds=[]
        entries=[(a,n,dirs(a),170) for a,(_,n) in SPECS.items()]
        if who=='ossuary_bearer':entries.append(('bone_pile',4,['s'],128))
        for a,n,ds,cell in entries:
            tid=str(len(ext)+1);ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/mini/{who}/{a}.png" id="{tid}"]')
            for suffix in ('','_e'):
                sheet=Image.new('RGBA',(n*cell,len(ds)*cell))
                for row,d in enumerate(ds):
                    for i in range(n):
                        with Image.open(FRAMES/who/a/f'{d}_{i:02d}{suffix}.png') as im:
                            im=im.convert('RGBA');assert im.size==(cell,cell)
                            if not suffix:
                                bb=im.getchannel('A').point(lambda v:255 if v>16 else 0).getbbox();assert bb,(who,a,d,i)
                                assert bb[0]>=2 and bb[1]>=2 and bb[2]<=cell-2,(who,a,d,i,bb)
                                if a=='idle':bounds.append(bb)
                            sheet.paste(im,(i*cell,row*cell))
                if suffix:
                    assert max(v[1] for v in sheet.convert('RGB').getextrema())>20,(who,a,'empty emission')
                    sheet=sheet.resize(((sheet.width+1)//2,(sheet.height+1)//2),Image.Resampling.LANCZOS)
                png=out/f'{a}{suffix}.png';sheet.save(png,optimize=True,compress_level=9)
                ip=png.with_suffix('.png.import')
                if not ip.exists():
                    params=texture_budget.expected_params(png.relative_to(ROOT/'game').as_posix(),budget)
                    ip.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'+''.join(f'{k}={texture_budget._fmt(v)}\n' for k,v in params.items()))
            for row,d in enumerate(ds):
                seq=[]
                for i in range(n):
                    sid=f'f{len(sub)}';sub.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{tid}")\nregion = Rect2({i*cell}, {row*cell}, {cell}, {cell})\n')
                    seq.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
                name=a if a=='bone_pile' else a+'_'+d
                anims.append('{"frames": ['+', '.join(seq)+'], "loop": '+('true' if a in ('idle','run') else 'false')+', "name": &"'+name+'", "speed": '+str(1.0 if a=='bone_pile' else 14.0 if a=='run' else 12.0)+'}')
        for a,n,ds,cell in entries:cel.check_sheet(f'bosses/mini/{who}/{a}.png',cell=cell,frames=n,rows=len(ds),normals=False)
        (out/f'{who}.tres').write_text('[gd_resource type="SpriteFrames" load_steps='+str(1+len(ext)+len(sub))+' format=3]\n\n'+'\n'.join(ext)+'\n\n'+'\n'.join(sub)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n')
        report.append({'id':who,'animations':len(anims),'frames':len(sub),'idle_bounds':bounds,'dim_bottom':GEOM[who]})
    (HERE/'_m4a_verification.json').write_text(json.dumps({'result':'PASS','normal_maps':False,'emission_ratio':.5,'camera_ortho':4.051028251647949,'impact_zero_based':{'attack':3,'cast_a':4,'cast_b':4},'assets':report},indent=2))
    print('PASS M4A atlases, direct AtlasTexture, emission, dimensions')

def contact():
    from PIL import Image
    # Only crops/assembly: actual game pixels on the crypt floor. Ground baselines align.
    board=Image.new('RGBA',(1530,1320),(46,50,56,255))
    for col,who in enumerate(IDS):
        for row,(a,i) in enumerate([('idle',0),('attack',3),('cast_a',4),('cast_b',4),('phase2',6),('death',8)]):
            with Image.open(ROOT/f'game/assets/sprites/bosses/mini/{who}/{a}.png') as im:
                y=170 if a in ('attack','cast_a','cast_b') else 0
                board.alpha_composite(im.convert('RGBA').crop((i*170,y,(i+1)*170,y+170)),(col*200,300-GEOM[who][1]+row*174))
    for col,who in enumerate(('crystal_mother','ash_lord')):
        folder=ROOT/'game/assets/sprites/bosses'/('etage' if col==0 else 'mini')/who
        path=folder/('idle_p1.png' if col==0 else 'idle.png')
        import re
        tres=(folder/f'{who}.tres').read_text()
        region=re.search(r'region = Rect2\(0, 0, (\d+), (\d+)\)',tres)
        w,h=map(int,region.groups()) if region else (448,448)
        with Image.open(path) as im:
            cell=im.convert('RGBA').crop((0,0,w,h))
            # No resize: all creature sources are presented at the same sprite-pixel scale.
            board.alpha_composite(cell,(620+col*470,300-(215 if col==0 else 117)))
    for j,rel in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png')):
        with Image.open(ROOT/rel) as im:
            ref=im.convert('RGBA');ref.thumbnail((390,180));board.alpha_composite(ref,(620+(j%2)*440,400+(j//2)*205))
    with Image.open(ROOT/'game/assets/sprites/bosses/mini/ossuary_bearer/bone_pile.png') as im:board.alpha_composite(im.convert('RGBA'),(650,1090))
    board.convert('RGB').save(HERE/'_m4a_contact.png',optimize=True)
    print('PASS contact assembled')

if __name__=='__main__' and '--pack' in sys.argv:pack();sys.exit()
if __name__=='__main__' and '--contact' in sys.argv:contact();sys.exit()

if __name__=='__main__':
    import bpy
    bpy.context.preferences.filepaths.save_version=0
    from mathutils import Vector
    sys.path.insert(0,str(ROOT/'art/tools/monsters'))
    from ash_lord_build import mesh,plate,rod,shard,worn
    from common import empty,material,pose
    from boss_pipeline import key
    sys.path.insert(0,str(ROOT/'art/tools/iso'))
    import iso_rig
    sys.path.insert(0,str(ROOT/'art/tools/cel'))
    import cel_style as cel
    from PIL import Image

    def rock(name,loc,scale,mat,parent,seed=0):
        rng=random.Random(seed)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1)
        ob=bpy.context.object;ob.name=name;ob.parent=parent;ob.location=loc;ob.scale=scale
        for v in ob.data.vertices:v.co*=rng.uniform(.84,1.12)
        ob.data.materials.append(mat)
        bevel=ob.modifiers.new('Broken salt edges','BEVEL');bevel.width=.035;bevel.segments=1
        ob.modifiers.new('Facet normals','WEIGHTED_NORMAL')
        return ob

    def bone(name,a,b,r,parent):
        rod(name,[a,b],r,ivory,parent)
        for p in (a,b):rock('Bone knuckle',p,(r*1.6,r*1.2,r*1.2),ivory,parent,5)

    def skull(loc,scale,parent):
        ob=empty('Hollow skull',loc,parent);ob.scale=(scale,)*3
        rock('Cranium',(0,0,.03),(.13,.11,.14),ivory,ob,9)
        for x in (-.05,.05):rock('Empty socket',(x,-.093,.04),(.039,.033,.044),cavity,ob,7)
        for x in (-.07,-.025,.025,.07):rod('Teeth',[(x,-.08,-.07),(x,-.087,-.12)],.014,ivory,ob)
        return ob

    def build_golem(who):
        root=empty(who);body=empty('Weight and spine',(0,0,0),root)
        isoss=who=='ossuary_bearer'
        rock('Hunched salt thorax',(0,.05,1.45),(.68,.39,.68),stone,body,11)
        rock('Sacral wedge',(0,.06,.88),(.43,.32,.37),stone2,body,15)
        rock('Blind visor',(-.12,-.19,2.11),(.30,.28,.32),stone2,body,22)
        plate('Visor slit',[(-.30,2.12),(.07,2.09),(.08,2.04),(-.28,2.07)],-.45,.025,cavity,body)
        limbs=[];legs=[]
        for sign in (-1,1):
            leg=empty('Weight bearing leg',(sign*.32,0,.77),body);legs.append(leg)
            rock('Broken shin',(0,0,-.30),(.23,.26,.43),stone,leg,23+sign)
            rock('Anchored heel',(0,-.13,-.64),(.28,.38,.14),stone2,leg,29+sign)
            arm=empty('Raised heavy arm',(sign*.59,.03,1.77),body);limbs.append(arm)
            rock('Chipped shoulder',(sign*.04,0,-.02),(.32,.31,.33),stone2,arm,sign+31)
            rod('Sinew of salt',[(0,0,0),(sign*.19,-.03,-.42),(sign*.15,-.23,-.79)],.17,stone,arm)
            rock('Massive fist',(sign*.15,-.27,-.78),(.31,.30,.30),stone2,arm,sign+40)
            for j in range(3):rock('Knuckle ridge',(sign*.15+(j-1)*.14,-.50,-.73),(.08,.10,.12),ivory if isoss else stone,arm,j+42)
        niche=empty('Lifted reliquary',(0,.15,1.25),body)
        effects=[];halves=[]
        if isoss:
            # A roofless funerary lancet, carried diagonally over the shoulders.
            plate('Ossuary dark interior',[(-.48,0),(.48,0),(.48,1.12),(0,1.60),(-.48,1.12)],.27,.16,cavity,niche)
            for sign in (-1,1):
                post=empty('Opening stone wing',(sign*.47,.16,0),niche);halves.append(post)
                rod('Salt buttress',[(0,0,0),(0,0,1.08),(-sign*.47,0,1.56)],.105,stone2,post)
            rod('Reliquary sill',[(-.51,.06,.06),(.51,.06,.06)],.11,stone2,niche)
            for j in range(7):
                skull(((j%3-1)*.26,-.01,.26+(j//3)*.34),.8,niche)
                bone('Crossed relic',(-.35,-.04,.18+j*.17),(.34,-.06,.42+j*.13),.035,niche)
            for j in range(5):shard('Niche cyan crystal',((j-2)*.17,-.04,1.03),(.08,.07,.26+(j%2)*.09),accent,niche)
            for j in range(6):
                fx=empty('Rising ancestral bone',((j-2.5)*.23,-.58,.08),root)
                bone('Emerging ulna',(0,0,0),(.03,0,.46),.045,fx);skull((0,0,.56),.6,fx);effects.append(fx)
        else:
            # Two interlocking jagged masses conceal the open phase-two cleft.
            for sign in (-1,1):
                half=empty('Split salt monolith',(sign*.13,0,1.40),body);halves.append(half)
                outline=[(sign*x,z) for x,z in [(.015,-.49),(.39,-.41),(.51,.04),(.43,.58),(.25,.91),(.035,.81),(.11,.52),(.015,.35),(.095,.13),(.015,-.06)]]
                plate('Cleaved salt monolith',outline,-.36,.70,stone2,half,.025)
                for j in range(6):
                    ob=shard('Cubic salt crown',(sign*(.17+j*.035),.06,.54+j*.09),(.12,.12,.29),stone,half)
                    ob.rotation_euler.y=sign*(.15+j*.08)
            shard('Exposed cyan heart',(0,-.42,1.55),(.14,.10,.35),accent,body)
            for sign in (-1,1):
                rod('Heart fracture',[(0,-.40,1.25),(sign*.23,-.39,1.55),(sign*.29,-.28,1.96)],.025,accent,body)
            for j in range(4):
                fx=empty('Salt cross spear',(0,0,1.45),body);fx.rotation_euler.z=j*math.pi/2
                rod('Extruded salt lance',[(0,0,0),(0,-.42,.04),(0,-1.12,.08)],.11,stone2,fx)
                shard('Shard tip',(0,-1.05,.12),(.09,.10,.22),ivory,fx);effects.append(fx)
        return root,body,limbs,legs,niche,halves,effects

    def bat_mesh(parent,sign,small=False):
        w=empty('Membrane spar',(sign*.18,0,1.58),parent)
        points=[(0,0,0),(sign*.48,.03,.54),(sign*1.06,.08,.29),(sign*.90,-.06,-.31),(sign*.65,-.10,-.12),(sign*.43,-.15,-.45),(sign*.17,-.14,-.21)]
        ob=mesh('Torn translucent membrane',points,[(0,j,j+1) for j in range(1,6)],membrane,w)
        for j in (1,2,3,5):rod('Wing bone',[points[0],points[1],points[j]] if j>1 else [points[0],points[1]],.025,ivory,w)
        return w

    def build_bat():
        root=empty('blind_swarm');body=empty('Hovering queen',(0,0,.13),root)
        rock('Gaunt breast',(0,0,1.37),(.24,.24,.51),stone,body,61)
        for j in range(5):
            for sign in (-1,1):rod('Exposed rib',[(0,-.22,1.58-j*.12),(sign*.18,-.15,1.52-j*.12),(sign*.13,.02,1.43-j*.12)],.026,ivory,body)
        head=empty('Eyeless face',(0,-.06,1.93),body)
        rock('Folded snout',(0,-.05,0),(.21,.22,.25),stone2,head,64)
        rock('Mouth void',(0,-.24,-.065),(.105,.055,.12),cavity,head,65)
        jaw=empty('Screech jaw',(0,-.12,-.15),head)
        rod('Mandible',[(-.12,-.02,.02),(0,-.16,-.07),(.12,-.02,.02)],.038,ivory,jaw)
        for sign in (-1,1):
            plate('Crystal ear',[(sign*.08,.08),(sign*.29,.65),(sign*.23,.01)],-.02,.065,accent,head)
            for j in range(2):rod('Needle fang',[(sign*(.05+j*.035),-.25,-.02),(sign*(.04+j*.035),-.27,-.16)],.018,ivory,head)
        wings=[bat_mesh(body,s) for s in (-1,1)];feet=[]
        for sign in (-1,1):
            foot=empty('Raking talons',(sign*.16,0,1.03),body);feet.append(foot)
            rod('Tendon',[(0,0,0),(sign*.07,-.04,-.30)],.045,stone,foot)
            for j in range(3):rod('Sickle claw',[(sign*.07+(j-1)*.06,-.04,-.30),(sign*.07+(j-1)*.07,-.18,-.43),(sign*.07+(j-1)*.07,-.26,-.36)],.022,ivory,foot)
        swarm=[]
        for j in range(10):
            b=empty('Orbiting blind bat',(0,0,0),root)
            rock('Small bat body',(0,0,0),(.04,.04,.10),stone2,b,j)
            for sign in (-1,1):plate('Swarm wing',[(0,0),(sign*.17,.10),(sign*.14,-.08),(sign*.07,-.02)],0,.012,stone,b,0)
            swarm.append(b)
        waves=[]
        for j in range(3):
            fx=empty('Screech air arc',(0,-.37,1.87),body)
            rod('Visible salt breath',[(math.cos(t)*.45,-.10,math.sin(t)*.45) for t in [k*math.pi/8 for k in range(9)]],.022,ivory,fx);waves.append(fx)
        return root,body,wings,feet,head,jaw,swarm,waves

    def render(dest,cell=170):
        dest.parent.mkdir(parents=True,exist_ok=True)
        s=bpy.context.scene
        iso_rig.common.configure_passes(dest)
        s.render.filepath=str(dest);bpy.ops.render.render(write_still=True)
        candidates=list(dest.parent.glob(dest.stem+'_e__*.png'));assert len(candidates)==1
        ep=dest.with_stem(dest.stem+'_e');candidates[0].replace(ep)
        for p in (dest,ep):
            with Image.open(p) as im:im=im.convert('RGBA').resize((cell,cell),Image.Resampling.LANCZOS)
            im.save(p,optimize=True,compress_level=9)

    for who in selected():
        s=iso_rig.create_rig('CREA',170)
        s.render.threads_mode='FIXED';s.render.threads=6
        s.camera.data.ortho_scale=4.051028251647949
        # Same camera scale as frost_bear; asset-specific registered ground line.
        s.camera.data.shift_y=(GEOM[who][1]-(7 if who!='blind_swarm' else 0))/170-.5
        s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,0,12))
        stone=material('Wet crypt salt','8C8778',0)
        stone2=material('Chipped salt planes','B4B0A2',0)
        ivory=material('Funerary bone','B6B29A',0)
        cavity=material('Black water in crevices','343B40',0)
        accent=material('Only emission crystal white cyan','BFF4FF',2.2,True)
        membrane=material('Readable thin wing membrane','807F8D',0)
        p=membrane.node_tree.nodes.get('Principled BSDF');p.inputs['Alpha'].default_value=.86
        # Cold upper-left silhouette light; cel quantizes its sculptural contribution.
        ld=bpy.data.lights.new('Crypt cold rim','AREA');ld.energy=430;ld.color=(.60,.82,1);ld.shape='DISK';ld.size=3
        lo=bpy.data.objects.new('Crypt cold rim',ld);s.collection.objects.link(lo);lo.location=(-3,1,4)
        lo.rotation_euler=(Vector((0,0,1.3))-lo.location).to_track_quat('-Z','Y').to_euler()
        if who=='blind_swarm':root,body,arms,legs,head,jaw,swarm,waves=build_bat()
        else:root,body,arms,legs,niche,halves,effects=build_golem(who)
        # Body silhouettes occupy 110/120/125 final pixels, no image scaling in game.
        body.scale=(.98,)*3 if who=='ossuary_bearer' else (1.18,)*3 if who=='salt_golem' else (1,)*3
        base_scale=body.scale.copy();base_loc=body.location.copy()
        for a,(start,n) in SPECS.items():
            for i in range(n):
                t=i*math.tau/n;p=i/(n-1);hit=n//2
                strike=([0,-.25,-.62,1,.38,0][i] if a=='attack' else [0,-.12,-.34,-.65,1,.48,.16,0][i] if a in ('cast_a','cast_b') else 0)
                death=p if a=='death' else 0;opening=p if a=='phase2' else 0
                body.location=base_loc.copy();body.rotation_euler=(0,0,0);body.scale=base_scale.copy()
                body.location.z+=.025*math.sin(t)+.45*death;body.rotation_euler.y=death*1.20
                body.location.x-=.80*death;body.scale.z*=1-.45*death
                body.location.x+=.022*math.cos(t)*(1-death)
                if a=='run':body.location.z+=.045*math.cos(t*2);body.rotation_euler.x=.08*math.sin(t)
                if who=='blind_swarm':
                    body.location.z+=.07*math.sin(t);body.rotation_euler.x=.26*strike
                    for j,wing in enumerate(arms):
                        sign=(-1,1)[j];wing.rotation_euler.y=sign*(.32*math.sin(t) if a in ('idle','run') else -.45*max(0,strike) if a=='cast_a' else .40*strike)
                        key(wing,start+i)
                    for foot in legs:foot.rotation_euler.x=-1.0*strike if a=='attack' else .07*math.sin(t);key(foot,start+i)
                    jaw.rotation_euler.x=.95*max(0,strike) if a=='cast_b' else .04;key(jaw,start+i)
                    for j,b in enumerate(swarm):
                        angle=j*math.tau/5+t*.35;radius=.70+(max(0,strike)*.25 if a=='cast_a' else 0)
                        b.location=(math.cos(angle)*radius,math.sin(angle)*.34,.80+(j%3)*.34+.09*math.sin(t+j))
                        b.rotation_euler=(.18*math.sin(t+j),0,angle)
                        q=1 if j<5 or opening>.3 else .001;b.scale=(q,)*3;key(b,start+i)
                    for j,fx in enumerate(waves):
                        fx.location.y=-.45-j*.18;fx.scale=(max(.001,strike)*(1+j*.25),)*3 if a=='cast_b' else (.001,)*3;key(fx,start+i)
                else:
                    body.rotation_euler.x=(.70*max(0,strike) if a=='cast_a' else .19*strike if a=='attack' else -.08*strike)
                    if a=='cast_a':
                        body.location.z-=.35*max(0,strike)
                        body.location.y+=.75*max(0,strike)
                    for j,arm in enumerate(arms):
                        arm.rotation_euler=(.43*math.sin(t+j*math.pi) if a=='run' else -1.65*strike if a=='attack' and j==0 else [0,-.35,-.85,-1.7,-.2,-.1,0,0][i] if a=='cast_a' else -.5*strike if a=='cast_b' else .025*math.sin(t+j),0,0)
                        key(arm,start+i)
                    for j,leg in enumerate(legs):
                        leg.rotation_euler.x=.38*math.sin(t+j*math.pi) if a=='run' else -.1*strike
                        leg.location.z=.77+(.35*max(0,strike) if a=='cast_a' else 0)
                        key(leg,start+i)
                    if who=='ossuary_bearer':
                        niche.location=(0,.15,1.25);niche.rotation_euler=(0,0,0)
                        if a=='cast_b':
                            lift=[0,.14,.33,.44,-.60,-.23,-.05,0][i]
                            niche.location.z+=lift;niche.location.y-=max(0,strike)*.60;niche.rotation_euler.x=-.9*strike
                        key(niche,start+i)
                        for j,h in enumerate(halves):h.rotation_euler.y=(-1,1)[j]*opening*.65;key(h,start+i)
                        for j,fx in enumerate(effects):
                            q=max(.001,strike) if a=='cast_a' else max(.001,opening*.9) if a=='phase2' else .001
                            fx.scale=(q,)*3;key(fx,start+i)
                    else:
                        for j,h in enumerate(halves):h.location.x=(-1,1)[j]*(.13+.23*opening);h.rotation_euler.y=(-1,1)[j]*opening*.23;key(h,start+i)
                        for fx in effects:q=max(.001,strike) if a=='cast_b' else .001;fx.scale=(q,)*3;key(fx,start+i)
                key(body,start+i)
            s.timeline_markers.new(a,frame=start)
        s.frame_start=1;s.frame_end=130;s.render.fps=12
        s['m4a_contract']=json.dumps({'cell':170,'dim_bottom':GEOM[who],'normals':False,'impact':'N/2','ortho_scale':s.camera.data.ortho_scale})
        s['animation_manifest']=json.dumps({a:{'start':v[0],'frames':v[1],'directions':dirs(a)} for a,v in SPECS.items()})
        pose(root,1,'s');cel.install('creature',normals=False)
        cel.toon_materials('creature')
        if who=='blind_swarm':
            # Keep the mandated cel palette, with 14% physical membrane transparency.
            nodes=membrane.node_tree.nodes;links=membrane.node_tree.links
            out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
            shader=out.inputs['Surface'].links[0].from_socket
            transparent=nodes.new('ShaderNodeBsdfTransparent');mix=nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=.86
            links.new(transparent.outputs[0],mix.inputs[1]);links.new(shader,mix.inputs[2]);links.new(mix.outputs[0],out.inputs['Surface'])
            membrane.surface_render_method='DITHERED'
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/f'm4a_{who}.blend'))
        for a,(start,n) in SPECS.items():
            if '--anim' in sys.argv and a!=sys.argv[sys.argv.index('--anim')+1]:continue
            for d in dirs(a):
                for i in range(n):
                    dest=FRAMES/who/a/f'{d}_{i:02d}.png'
                    if '--resume' in sys.argv and dest.exists() and dest.with_stem(dest.stem+'_e').exists():continue
                    pose(root,start+i,d);render(dest)
            print('M4A_COMPLETE',who,a,flush=True)
        if who=='ossuary_bearer':
            for ob in [root,*root.children_recursive]:ob.hide_render=True
            iso_rig.set_frame(128,'MAP');s.camera.data.shift_y=.5
            s.camera.rotation_euler.z=math.pi/4
            s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,0,12))
            for i in range(4):
                pile=empty('Collapsed ossuary variant',(-.19,.19,0));pile.scale=(1.12,1.12,1.25)
                rng=random.Random(440+i)
                for j in range(12):
                    x=rng.uniform(-.33,.33);y=rng.uniform(-.20,.20);z=.10+(1-abs(x)*2)*rng.uniform(.1,.37)
                    bone('Fallen long bone',(x,y,z),(x+rng.uniform(-.20,.20),y+.18,z+.08),.043,pile)
                for j in range(3):skull((-.22+j*.21,-.12,.24+(j%2)*.28),.8,pile)
                shard('Subtle relic crystal',(0,0,.28),(.045,.04,.16),accent,pile)
                cel.install('creature',normals=False);render(FRAMES/who/'bone_pile'/f's_{i:02d}.png',128)
                for ob in [pile,*pile.children_recursive]:ob.hide_render=True
            for ob in [root,*root.children_recursive]:ob.hide_render=False
            iso_rig.set_frame(170,'CREA');s.camera.data.ortho_scale=4.051028251647949
            s.camera.rotation_euler.z=0;s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,0,12))
            s.camera.data.shift_y=(GEOM[who][1]-7)/170-.5
            pose(root,1,'s');bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/f'm4a_{who}.blend'))
        cel.uninstall()
    print('M4A_RENDER_PASS',flush=True)
