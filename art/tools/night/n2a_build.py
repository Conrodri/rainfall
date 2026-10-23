"""N2A: background Eevee sculpt/animation; python --pack assembles final atlases.
Reuse the approved Ash Lord materials, C0 rig and compositor. No interactive API.
"""
import sys, math, json, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
SOURCES=ROOT/'art/blender/monsters'
SPECS={'idle':(1,6),'run':(21,8),'attack':(41,6),'cast_a':(61,8),'cast_b':(81,8),'phase2':(101,8),'death':(121,10)}
IDS=('mist_wolf','mist_wolf_cub','lantern_owl')
def directions(a): return ['e','s','w','n'] if a in ('run','attack','cast_a','cast_b') else ['s']
def specs(who): return {a:v for a,v in SPECS.items() if who!='mist_wolf_cub' or a in ('idle','run','attack','death')}

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
            # Legacy south atlas plus e/w/n sheets for attacks/casts, run keeps four rows.
            groups=[(a,ds)] if a not in ('attack','cast_a','cast_b') else [(a,['s']),(a+'_dirs',['e','w','n'])]
            for stem,dirs in groups:
                tid=str(len(ext)+1)
                ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/mini/{who}/{stem}.png" id="{tid}"]')
                for suffix in ('','_n','_e'):
                    sheet=Image.new('RGBA',(n*170,len(dirs)*170))
                    for y,d in enumerate(dirs):
                        for i in range(n):
                            p=SOURCES/f'n2a_frames/{who}/{a}/{d}_{i:02d}{suffix}.png'
                            with Image.open(p) as src: cell=src.convert('RGBA');assert cell.size==(170,170)
                            sheet.paste(cell,(170*i,170*y))
                            if not suffix:
                                bb=cell.getchannel('A').getbbox();assert bb,(who,a,d,i)
                                margin=min(bb[0],bb[1],170-bb[2],170-bb[3]);minmargin=min(minmargin,margin)
                                assert margin>=4,(who,a,d,i,bb)
                    png=out/f'{stem}{suffix}.png'
                    sheet.save(png,optimize=True,compress_level=9)
                    ip=png.with_suffix('.png.import')
                    if not ip.exists():
                        params=texture_budget.expected_params(png.relative_to(ROOT/'game').as_posix(),budget)
                        ip.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'+''.join(f'{k}={texture_budget._fmt(v)}\n' for k,v in params.items()))
                for d in dirs:
                    sequence=[SOURCES/f'n2a_frames/{who}/{a}/{d}_{i:02d}.png' for i in range(n)]
                    assert len({p.read_bytes() for p in sequence})>=3,(who,a,d,'poses static')
                with Image.open(out/f'{stem}_e.png') as emission:
                    assert max(hi for lo,hi in emission.convert('RGB').getextrema())>16,(who,stem,'missing emission')
                for y,d in enumerate(dirs):
                    frames=[]
                    for i in range(n):
                        sid=f'f{count}';count+=1
                        sub.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{tid}")\nregion = Rect2({i*170}, {y*170}, 170, 170)\n')
                        frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
                    anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+('true' if a in ('idle','run') else 'false')+', "name": &"'+a+'_'+d+'", "speed": '+str(10.0 if a=='idle' else 8.0 if a=='phase2' else 12.0)+'}')
        tres='[gd_resource type="SpriteFrames" load_steps='+str(1+len(ext)+len(sub))+' format=3]\n\n'+'\n'.join(ext)+'\n\n'+'\n'.join(sub)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n'
        resource=out/f'{who}.tres'
        if resource.exists(): assert resource.read_text()==tres,'Existing contract differs; inspect before replacing'
        else: resource.write_text(tres)
        checks.append({'id':who,'frames':count,'animations':len(anims),'minimum_margin':minmargin,'max_atlas':[1360,680]})
        for a,d,indices in [('idle','s',[0]),('run','e',[0,2,4]),('attack','s',[2,3,5]),('attack','e',[2,3,5]),('attack','w',[2,3,5]),('attack','n',[2,3,5])]+([] if who.endswith('cub') else [('cast_a','s',[3,4,7]),('cast_b','s',[3,4,7]),('phase2','s',[4])])+[('death','s',[0,5,9])]:
            cells=[]
            for i in indices:
                with Image.open(SOURCES/f'n2a_frames/{who}/{a}/{d}_{i:02d}.png') as im: cells.append(im.convert('RGBA'))
            rows.append(cells)
    # One final contact only, including approved reference crops, no drawn pixels.
    nrows=(len(rows)+1)//2
    board=Image.new('RGBA',(1100,nrows*174+340),(37,42,40,255))
    for y,cells in enumerate(rows):
        for x,cell in enumerate(cells):board.alpha_composite(cell,((y%2)*550+x*174,(y//2)*174))
    for i,p in enumerate(['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png']):
        with Image.open(ROOT/p) as im:
            ref=im.convert('RGBA');ref.thumbnail((330,340));board.alpha_composite(ref,(i*360,nrows*174))
    board.convert('RGB').save(HERE/'_n2a_contact.png',optimize=True)
    (HERE/'_n2a_verification.json').write_text(json.dumps({'result':'PASS','cell':170,'pivot':[85,119],'ortho_scale':4.051028251647949,'impact_indices':{'attack':3,'cast_a':4,'cast_b':4},'assets':checks},indent=2))
    print('PASS: atlases, frame contracts, margins, contact')

if __name__=='__main__' and '--pack' in sys.argv:
    pack();sys.exit(0)

if __name__=='__main__':
    import bpy
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    sys.path.insert(0,str(ROOT/'art/tools/monsters'))
    from ash_lord_build import worn, mesh, rod, shard
    from common import empty, sphere, material, pose
    from boss_pipeline import key
    import iso_rig

    def ell(name,loc,sc,mat,parent):
        o=sphere(name,loc,sc,mat,parent)
        return o

    def leaf(name,a,b,width,mat,parent,curve=.05):
        a,b=Vector(a),Vector(b);delta=b-a
        side=delta.cross(Vector((0,-1,.15))).normalized()*width
        mid=a+delta*.46;ridge=mid+Vector((0,-curve,.035))
        return mesh(name,[a,mid+side,b,mid-side,ridge],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],mat,parent)

    def loft(name,sections,mat,parent):
        # Continuous anatomical surface, elliptical sections along local Y.
        v=[];segments=16
        for y,z,rx,rz in sections:
            v.extend([(rx*math.cos(j*math.tau/segments),y,z+rz*math.sin(j*math.tau/segments)) for j in range(segments)])
        f=[tuple(range(segments-1,-1,-1))]
        f.extend([(k*segments+j,k*segments+(j+1)%segments,(k+1)*segments+(j+1)%segments,(k+1)*segments+j) for k in range(len(sections)-1) for j in range(segments)])
        f.append(tuple((len(sections)-1)*segments+j for j in range(segments)))
        o=mesh(name,v,f,mat,parent)
        for p in o.data.polygons:p.use_smooth=True
        return o

    def wolf(cub=False):
        root=empty('Mist wolf ground pivot');body=empty('Scapular and spinal motion',parent=root)
        if cub:root.scale=(.60,.60,.60)
        fur=worn('Wet lichen grey guard hair','202B28','657064',rough=.86)
        dark=worn('Soot soaked undercoat','141C1B','39453F',rough=.92)
        pale=worn('Old silver throat and scar','475148','8F9781',rough=.84)
        hide=worn('Nose and exposed leather','101716','353D37',rough=.48)
        bone=worn('Weathered ivory fangs','727265','B9B9A0',rough=.59)
        eye=material('Single lantern green accent','9CF0C8',2.4,True)
        loft('Tucked continuous ribcage',[(.84,.94,.12,.18),(.61,1.04,.26,.31),(.24,1.02,.25,.30),(-.12,1.10,.34,.42),(-.40,1.12,.32,.40),(-.58,1.24,.24,.31)],fur,body)
        ell('Angular shoulder',(0,-.28,1.12),(.34,.35,.45),fur,body)
        head=empty('Neck and skull',(0,-.48,1.32),body)
        ell('Long cranial vault',(0,-.13,.16),(.25,.33,.26),fur,head)
        loft('Tapered nasal bridge',[(-.20,.13,.18,.15),(-.38,.075,.15,.105),(-.66,.025,.12,.075)],fur,head)
        ell('Black scent nose',(0,-.676,.035),(.115,.065,.067),hide,head)
        jaw=empty('Biting lower mandible',(0,-.18,.01),head)
        loft('Lean lower jaw',[(-.03,-.035,.16,.075),(-.30,-.08,.115,.055),(-.46,-.055,.09,.045)],dark,jaw)
        for sign in [-1,1]:
            leaf('Torn high triangular ear',(sign*.17,-.02,.26),(sign*.26,.08,.68 if sign<0 else .59),.125,dark,head)
            leaf('Ear silver rim',(sign*.17,-.04,.29),(sign*.26,.055,.60 if sign<0 else .53),.065,fur,head)
            ell('Deep orbital socket',(sign*.20,-.295,.19),(.065,.095,.07),dark,head)
            ell('Narrow green lantern eye',(sign*.25,-.395,.205),(.025,.052,.019),eye,head)
            rod('Heavy brow',[(sign*.21,-.24,.25),(sign*.245,-.33,.24),(sign*.19,-.39,.22)],.025,pale,head)
            for y in [-.29,-.43]:
                rod('Worn canine',[(sign*.105,y,.01),(sign*.10,y,-.095)],.021,bone,head)
            for j in range(7):
                leaf('Cheek guard hair',(sign*(.13+j*.015),-.09,.18-j*.035),(sign*(.32+j*.012),.16,.08-j*.038),.052,pale if j%3==0 else fur,head)
        legs=[]
        for front,y in [(True,-.35),(False,.58)]:
            for sign in [-1,1]:
                leg=empty(('Fore' if front else 'Hind')+' limb '+str(sign),(sign*.245,y,1.01),body);legs.append((leg,front,sign))
                knee=(sign*.025,.11 if front else -.16,-.45)
                ankle=(sign*.03,-.015 if front else .12,-.82)
                ell('Muscle taper',(0,.035,-.16),(.12,.16,.26),fur,leg)
                rod('Sinewy long shank',[(0,0,-.13),knee,ankle],.065,fur,leg)
                ell('Knuckled paw',(sign*.03,-.085,-.89),(.105,.17,.08),dark,leg)
                for digit in range(3):
                    x=(digit-1)*.052+sign*.03
                    rod('Keratin claw',[(x,-.18,-.88),(x,-.25,-.94)],.016,bone,leg)
                for j in range(3):leaf('Elbow ragged fur',(-.03,.03,-.16-j*.07),(.03,.21,-.32-j*.07),.065,fur,leg)
        tail=empty('Heavy brush tail',(0,.77,1.03),body)
        rod('Tapered tail spine',[(0,0,0),(.03,.25,-.12),(.08,.47,-.37),(.13,.57,-.53)],.11,dark,tail)
        for j in range(13):
            t=j/12
            leaf('Brush guard locks',(.045*math.sin(j*2.4),t*.48,-t*.36),(.07+math.sin(j*2.4)*.13,t*.53+.12,-t*.44-.13),.07,fur,tail)
        rng=random.Random(42)
        for j in range(56):
            y=rng.uniform(-.5,.5);x=rng.uniform(-.25,.25);z=1.40+.13*(1-abs(y))
            leaf('Broken mantle guard hair',(x,y,z),(x*1.2,y+.19,z-.16),rng.uniform(.035,.065),pale if j%7==0 else dark if j%3==0 else fur,body)
        for sign in [-1,1]:
            for j in range(5):
                rod('Visible rib fur crease',[(sign*.28,-.13+j*.105,1.22),(sign*.29,-.08+j*.105,1.07),(sign*.24,-.02+j*.105,.91)],.018,dark,body)
        return root,body,head,jaw,legs,tail,eye

    def owl():
        root=empty('Lantern owl ground pivot');body=empty('Hovering thorax',(0,0,.62),root)
        feather=worn('Waterlogged umber flight feather','1B2220','555C4F',rough=.86)
        edge=worn('Lichen grey feather edge','3B4940','7D8977',rough=.88)
        soot=worn('Coal down','111A19','333D36',rough=.96)
        bone=worn('Eroded bone facial disk','5B6253','A9AA8C',rough=.82)
        bronze=worn('Verdigris orbital cage','233C32','6C8872',metal=.6,rough=.62)
        horn=worn('Beak and sickle talons','1B201B','77786A',rough=.46)
        eye=material('Single lantern green accent','9CF0C8',.85,True)
        ell('Keeled feathered breast',(0,0,.65),(.38,.29,.57),soot,body)
        head=empty('Asymmetric facial mask',(0,-.015,1.03),body)
        head.scale=(.87,.92,.87)
        ell('Small owl skull',(0,0,.08),(.34,.235,.30),feather,head)
        # Two deeply recessed teardrop facial disks; tiny eyes behind oxidised ribs.
        for sign in [-1,1]:
            mask=[(sign*x,y,z) for x,y,z in [(.025,-.25,.20),(.25,-.21,.27),(.33,-.19,.08),(.19,-.24,-.14),(.055,-.28,-.06),(.045,-.27,.08),(.17,-.29,.08)]]
            mesh('Chiselled angular bone facial mask',mask,[(j,(j+1)%6,6) for j in range(6)],bone,head)
            orbit=[(sign*x,-.303,z) for x,z in [(.053,.156),(.27,.195),(.245,.064),(.09,.077)]]
            mesh('Deep angular lantern recess',orbit,[(0,1,2,3)],soot,head)
            lens=[(sign*x,-.316,z) for x,z in [(.083,.132),(.249,.160),(.217,.110),(.108,.109)]]
            mesh('Narrow slanted green lantern slit',lens,[(0,1,2,3)],eye,head)
            for off in [-.035,.035]:rod('Thin oxidised cage rib',[(sign*.155+off,-.32,.165),(sign*.155+off*.65,-.325,.09)],.007,bronze,head)
            rod('Severe sloping orbital brow',[(sign*.035,-.26,.205),(sign*.16,-.278,.24),(sign*.29,-.22,.22)],.024,bronze,head)
            for j in range(7):
                leaf('Facial disk radial feather',(sign*.10,-.22,.04),(sign*(.23+j*.016),-.16,-.09+j*.045),.026,edge,head)
            for j in range(3):leaf('Broken ear covert',(sign*.22,0,.20+j*.02),(sign*(.29+j*.025),.06,.40+j*.04),.047,feather,head)
        rod('Hooked dark beak',[(0,-.23,.08),(0,-.335,-.02),(0,-.30,-.14)],.055,horn,head)
        for j in range(30):
            angle=j*2.399;x=.27*math.cos(angle);y=-.20*math.sin(abs(angle));z=.92-(j%7)*.10
            leaf('Overlapping breast pennon',(x,y,z),(x*.8,y-.03,z-.23),.065,edge if j%4==0 else feather,body)
        wings=[]
        for sign in [-1,1]:
            wing=empty('Articulated wing '+str(sign),(sign*.24,0,.84),body);wings.append((wing,sign))
            ell('Muscular wing coverts',(sign*.21,.04,0),(.30,.19,.13),feather,wing)
            for j in range(10):
                x=sign*(.25+j*.085)
                leaf('Long separated primary',(.10*sign+j*.027*sign,.05,.02),(x,.32+j*.022,-.12-j*.027),.095-j*.004,edge if j%4==0 else feather,wing)
                rod('Pale primary rachis',[(sign*(.16+j*.025),.07,.028),(x,.29+j*.022,-.10-j*.025)],.006,soot,wing)
            for j in range(7):leaf('Scalloped upper wing covert',(sign*(.04+j*.06),-.09,.07),(sign*(.16+j*.07),.23,-.05),.075,edge if j%3==0 else feather,wing)
        feet=[]
        for sign in [-1,1]:
            foot=empty('Raking tarsus '+str(sign),(sign*.16,-.02,.28),body);feet.append((foot,sign))
            rod('Scaly tarsus',[(0,0,.07),(0,-.035,-.14)],.035,bronze,foot)
            for j in range(3):
                x=(j-1)*.065
                rod('Long sickle claw',[(0,-.02,-.11),(x,-.18,-.16),(x,-.23,-.26),(x,-.17,-.30)],.019,horn,foot)
        for j in range(7):leaf('Tattered fan tail',((j-3)*.05,.12,.43),((j-3)*.065,.62,.08),.065,feather,body)
        wisps=[]
        for j in range(5):
            wisp=empty('Seeded marsh light '+str(j),parent=root)
            leaf('Green follet tongue',(-.035,0,0),(.02,0,.21),.065,eye,wisp)
            ell('Follet lantern heart',(0,0,.045),(.043,.035,.055),eye,wisp)
            wisps.append(wisp)
        return root,body,head,wings,feet,eye,wisps

    for who in IDS:
        if '--only' in sys.argv and who not in sys.argv[sys.argv.index('--only')+1].split(','):continue
        s=iso_rig.create_rig('CREA',170);s.eevee.taa_render_samples=16
        # The shared optimizer omits black emission files. Keep empty individual
        # cells here so directional atlases retain an identical diffuse/n/e grid.
        # render_frame already performs max-compression saves before this hook.
        iso_rig.optimize_png=lambda path,*args,**kwargs: (0,0,170,170)
        s.render.threads_mode='FIXED';s.render.threads=8
        # Exact R9 framing and world ground pivot; never fit per creature or frame.
        s.camera.data.ortho_scale=4.051028251647949
        s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,0,12))
        s.camera.data.shift_y=.2
        bpy.context.view_layer.update()
        p=world_to_camera_view(s,s.camera,Vector((0,0,0)));assert abs(p.y-.30)<.0001
        isowl=who=='lantern_owl'
        if isowl:root,body,head,wings,feet,eye,wisps=owl();base=body.location.copy()
        else:root,body,head,jaw,legs,tail,eye=wolf(who.endswith('cub'));base=body.location.copy()
        iso_rig.bake_ao_shadows(root)
        for a,(start,n) in specs(who).items():
            for i in range(n):
                t=i*math.tau/n;p=i/(n-1);impact=n//2
                strike=([0,-.25,-.60,1,.35,0][i] if a=='attack' else [0,-.1,-.3,-.5,1,.5,.15,0][i] if a in ('cast_a','cast_b') else 0)
                death=p if a=='death' else 0
                body.location=base.copy();body.rotation_euler=(0,0,0);body.scale=(1,1,1)
                if isowl:
                    body.location.z+=.055*math.sin(t)-death*.57
                    if a=='attack':body.location.y=-.35*strike;body.location.z-=.27*max(0,strike)
                    body.rotation_euler.x=.38*strike if a=='attack' else -.22*strike if a=='cast_a' else 0
                    body.rotation_euler.y=1.25*death
                    if a=='phase2':body.rotation_euler.z=.16*math.sin(t)
                    key(body,start+i)
                    head.rotation_euler=(.20*strike if a=='cast_a' else 0,0,.24*math.sin(t) if a=='phase2' else 0);key(head,start+i)
                    for wing,sign in wings:
                        wing.rotation_euler=(0,sign*(.28+.38*math.sin(t)),0)
                        if a in ('cast_a','cast_b','phase2'):wing.rotation_euler.y=sign*(-.26-.28*max(0,strike))
                        if a=='attack':wing.rotation_euler.y=sign*(.18+.60*strike)
                        if death:wing.rotation_euler.y=sign*(.25+death*.7)
                        key(wing,start+i)
                    for foot,sign in feet:
                        foot.rotation_euler.x=-1.1*max(0,strike) if a=='attack' else .12*math.sin(t);key(foot,start+i)
                    for j,wisp in enumerate(wisps):
                        visible=(a=='cast_b' and i>=impact and j<3) or (a=='phase2' and i>=impact)
                        k=(i-impact)/max(1,n-impact-1);angle=j*math.tau/(3 if a=='cast_b' else 5)
                        wisp.location=(math.cos(angle)*(.52+.22*k),math.sin(angle)*(.52+.22*k),.85+.18*math.sin(j+t))
                        q=1 if visible else .001;wisp.scale=(q,q,q);key(wisp,start+i)
                else:
                    body.location.z=.045*math.sin(t*2) if a=='run' else .018*math.sin(t)
                    body.rotation_euler.x=.07*math.sin(t) if a=='run' else .13*strike
                    if a=='attack':body.location.y=-.24*strike
                    if a=='cast_a':body.location.z+=.33*max(0,strike);body.location.y=-.20*strike
                    if a=='cast_b':
                        # Fold completely into the ground mist before the N/2 reappearance bite.
                        squash=[1,.85,.5,.15,1.0,1.02,1,1][i];body.scale=(1,1,squash);body.location.y=-.19*max(0,strike)
                    body.location.z-=.58*death;body.rotation_euler.y=1.05*death
                    key(body,start+i)
                    head.rotation_euler.x=(-.50*math.sin(math.pi*p) if a=='phase2' else -.30*strike if a in ('attack','cast_a') else 0);key(head,start+i)
                    jaw.rotation_euler.x=.46*max(.0,strike) if a in ('attack','cast_b') else .33*math.sin(math.pi*p) if a=='phase2' else .025;key(jaw,start+i)
                    for leg,front,sign in legs:
                        leg.rotation_euler.x=.65*math.sin(t+(0 if (front==(sign==1)) else math.pi)) if a=='run' else -.65*strike if a=='cast_a' and front else .12*strike
                        leg.rotation_euler.y=sign*.45*death;key(leg,start+i)
                    tail.rotation_euler=(.12*math.sin(t),.22*math.sin(t),.12*math.sin(t));key(tail,start+i)
            s.timeline_markers.new(a,frame=start)
        s.frame_start=1;s.frame_end=130;s.render.fps=12
        s['n2a_contract']=json.dumps({'cell':170,'pivot':[85,119],'impact':'N/2','directions':'e,s,w,n','scale':s.camera.data.ortho_scale})
        s['animation_manifest']=json.dumps({a:{'start':start,'frames':n,'directions':directions(a),'loop':a in ('idle','run')} for a,(start,n) in specs(who).items()})
        pose(root,1,'s');bpy.ops.wm.save_as_mainfile(filepath=str(SOURCES/f'n2a_{who}.blend'))
        for a,(start,n) in specs(who).items():
            if '--anim' in sys.argv and a!=sys.argv[sys.argv.index('--anim')+1]:continue
            folder=SOURCES/f'n2a_frames/{who}/{a}';folder.mkdir(parents=True,exist_ok=True)
            for d in directions(a):
                for i in range(n):
                    dest=folder/f'{d}_{i:02d}.png'
                    if '--resume' in sys.argv and all(dest.with_stem(dest.stem+k).exists() for k in ('','_n','_e')):continue
                    pose(root,start+i,d);iso_rig.render_frame(dest)
            print('N2A_COMPLETE',who,a,flush=True)
    print('N2A_RENDER_PASS',flush=True)
