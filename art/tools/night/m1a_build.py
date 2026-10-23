"""M1A Terrasses: authored geometry, cel Eevee, contractual 170px atlases.
Blender --background --python this.py -- --render [--only ID] [--resume]
System Python this.py --pack / --contact / --verify. No normal-map export.
Shared Ash Lord geometry, C0 camera, cel compositor and emission peak reducer.
"""
import sys, math, json, re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SRC = ROOT/'art/blender/monsters'
IDS = ('iron_heron', 'vat_toad', 'scarecrow_reaper')
SPECS = {'idle': (1,6), 'run': (21,8), 'attack': (41,6), 'cast_a': (61,8),
         'cast_b': (81,8), 'phase2': (101,8), 'death': (121,10)}
def dirs(a): return ['e','s','w','n'] if a in ('run','attack','cast_a','cast_b') else ['s']
def selected(): return sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else IDS
def folder(who): return ROOT/'game/assets/sprites/bosses/mini'/who
def raw(who,a,d,i): return SRC/f'm1a_frames/{who}/{a}/{d}_{i:02d}.png'

def pack():
    from PIL import Image
    sys.path[:0] = [str(ROOT/'art/tools'), str(ROOT/'art/tools/cel')]
    import texture_budget, halve_emission, cel_style as cel
    budget = texture_budget.load_budget()
    for who in selected():
        out=folder(who);out.mkdir(parents=True,exist_ok=True)
        ext=[];sub=[];anims=[];counter=0
        for a,(_,n) in SPECS.items():
            ds=dirs(a);tid=str(len(ext)+1)
            ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/mini/{who}/{a}.png" id="{tid}"]')
            for suffix in ('','_e'):
                sheet=Image.new('RGBA',(n*170,len(ds)*170))
                for y,d in enumerate(ds):
                    for i in range(n):
                        p=raw(who,a,d,i);p=p.with_stem(p.stem+suffix)
                        with Image.open(p) as im:
                            assert im.size==(170,170),(p,im.size)
                            sheet.paste(im.convert('RGBA'),(i*170,y*170))
                if suffix:
                    assert max(v[1] for v in sheet.convert('RGB').getextrema())>20,(who,a,'empty accent')
                    sheet=halve_emission.downscale(sheet)
                dest=out/f'{a}{suffix}.png';sheet.save(dest,optimize=True,compress_level=9)
                ip=dest.with_suffix('.png.import')
                if not ip.exists():
                    params=texture_budget.expected_params(dest.relative_to(ROOT/'game').as_posix(),budget)
                    ip.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'+''.join(f'{k}={texture_budget._fmt(v)}\n' for k,v in params.items()))
            for y,d in enumerate(ds):
                frames=[]
                for i in range(n):
                    sid=f'f{counter}';counter+=1
                    sub.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{tid}")\nregion = Rect2({i*170}, {y*170}, 170, 170)\n')
                    frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
                anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+('true' if a in ('idle','run') else 'false')+', "name": &"'+a+'_'+d+'", "speed": '+str(14.0 if a=='run' else 12.0)+'}')
        text='[gd_resource type="SpriteFrames" load_steps='+str(1+len(ext)+len(sub))+' format=3]\n\n'+'\n'.join(ext)+'\n\n'+'\n'.join(sub)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n'
        tres=out/f'{who}.tres'
        if not tres.exists() or tres.read_text()!=text:tres.write_text(text)
        for a,(_,n) in SPECS.items():
            cel.check_sheet(f'bosses/mini/{who}/{a}.png',cell=170,frames=n,rows=len(dirs(a)),normals=False)
        print('PACK_PASS',who,counter,'frames',flush=True)

def contact():
    from PIL import Image
    # All figures at native game scale; no resizing of creatures, no drawn marks.
    board=Image.new('RGBA',(1020,980),'#3A4038')
    def cell(p,n=170,x=0,y=0):
        with Image.open(p) as im:return im.convert('RGBA').crop((x*n,y*n,(x+1)*n,(y+1)*n))
    for x,who in enumerate(IDS):
        if not (folder(who)/'idle.png').exists():continue
        for y,(a,i) in enumerate([('idle',0),('attack',3),('cast_a',4),('cast_b',4),('phase2',7)]):
            board.alpha_composite(cell(folder(who)/f'{a}.png',x=i,y=1 if a in ('attack','cast_a','cast_b') else 0),(x*170,110 if y==0 else 300+(y-1)*170))
    board.alpha_composite(cell(ROOT/'game/assets/sprites/bosses/mini/frost_bear/idle.png'),(510,110))
    # The Eclusier uses its own native 256px cells, preserve that scale too.
    ep=ROOT/'game/assets/sprites/bosses/etage/eclusier/idle_p1.png'
    with Image.open(ep) as im:
        e=im.convert('RGBA').crop((0,0,256,256));bottom=e.getchannel('A').getbbox()[3];board.alpha_composite(e,(710,250-bottom))
    # Approved DA references, thumbnails only in the reserved right column.
    for j,p in enumerate(['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png']):
        with Image.open(ROOT/p) as im:
            ref=im.convert('RGBA')
            if j==3:ref=ref.crop((ref.width//2,0,ref.width,ref.height))
            ref.thumbnail((490,132));board.alpha_composite(ref,(520,330+j*148))
    board.convert('RGB').save(HERE/'_m1a_contact.png',optimize=True)
    print('CONTACT_PASS')

def verify():
    from PIL import Image
    import numpy as np
    report=[]
    for who in selected():
        checks={}
        for a,(_,n) in SPECS.items():
            p=folder(who)/f'{a}.png'
            with Image.open(p) as im:
                assert im.size==(n*170,len(dirs(a))*170)
                bounds=[]
                for y,d in enumerate(dirs(a)):
                    unique=set()
                    for i in range(n):
                        c=im.crop((i*170,y*170,(i+1)*170,(y+1)*170));b=c.getchannel('A').getbbox()
                        assert b and min(b[0],b[1],170-b[2],170-b[3])>=2,(who,a,d,i,b)
                        bounds.append(b);unique.add(c.tobytes())
                    assert len(unique)>=3,(who,a,d,'static')
                checks[a]={'size':im.size,'bounds':bounds}
            with Image.open(p.with_stem(a+'_e')) as e:
                assert e.size==((n*170+1)//2,(len(dirs(a))*170+1)//2)
                accent=np.asarray(e.convert('RGBA'),dtype=np.float32)
                assert (accent[:,:,:3].max(axis=2)*accent[:,:,3]/255).max()>2,(who,a,'invisible accent')
        assert not list(folder(who).glob('*_n.png'))
        t=(folder(who)/f'{who}.tres').read_text()
        assert 'CanvasTexture' not in t and 'normal_texture' not in t
        animations=re.findall(r'"frames": \[(.*?)\], "loop": (true|false), "name": &"([^"]+)", "speed": ([\d.]+)',t,re.S)
        expected={f'{a}_{d}':(n,a in ('idle','run'),14 if a=='run' else 12)
                  for a,(_,n) in SPECS.items() for d in dirs(a)}
        assert len(animations)==len(expected),(who,'animation count')
        for frames,loop,name,speed in animations:
            assert name in expected,(who,name)
            n,repeat,fps=expected.pop(name)
            assert (frames.count('SubResource('),loop=='true',float(speed))==(n,repeat,fps),(who,name,'animation contract')
        assert not expected,(who,'missing animations',expected)
        with Image.open(folder(who)/'idle.png') as im:
            a=np.asarray(im.crop((0,0,170,170)));opaque=a[:,:,3]>230
            mean=float(a[:,:,:3][opaque].mean())
            assert mean>=90,(who,'night readability',mean)
            y=np.where(a[:,:,3]>128)[0];assert 138<=int(y.max())+1<=142,(who,'ground line',y.max())
        assert (SRC/f'm1a_{who}.blend').stat().st_size>10000
        report.append({'id':who,'idle_mean_srgb':round(mean,2),'checks':checks})
    (HERE/'_m1a_verification.json').write_text(json.dumps({'result':'PASS','cell':170,'camera_scale':4.051028251647949,'ground_bottom':140,'impact_indices':{'attack':3,'cast_a':4,'cast_b':4},'assets':report},indent=2))
    print('VERIFY_PASS: sizes, alpha margins, moving poses, emissions, direct AtlasTexture, no normals')

def build():
    import bpy
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    sys.path[:0]=[str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
    import iso_rig,cel_style as cel
    from common import empty, sphere, material, cube, pose
    from ash_lord_build import mesh, rod, shard, plate
    from boss_pipeline import key

    def mat(name,color):return material(name,color,0,False)
    def ell(name,p,s,m,parent):return sphere(name,p,s,m,parent)
    def leaf(name,a,b,w,m,parent,bend=.045):
        a,b=Vector(a),Vector(b);mid=a.lerp(b,.46)
        v=(b-a).cross(Vector((0,-1,.25))).normalized()*w
        return mesh(name,[a,mid+v,b,mid-v,mid+Vector((0,-bend,.04))],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],m,parent)
    def ring(name,center,r,thick,m,parent,scale=(1,1,1)):
        bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=6,location=(0,0,0),major_radius=r,minor_radius=thick)
        ob=bpy.context.object;ob.name=name;ob.parent=parent;ob.location=center;ob.scale=scale;ob.data.materials.append(m);return ob
    def rivets(parent,center,r,m,n=10):
        for j in range(n):
            t=j*math.tau/n;shard('Unequal bronze rivet',(center[0]+r*math.cos(t),center[1]+r*math.sin(t),center[2]),(.028,.028,.022),m,parent)
    def bird(parent,p,s=1):
        b=empty('Carrion crow',p,parent);b.scale=(s,s,s)
        ell('Crow arched breast',(0,0,.06),(.095,.19,.12),feather,b)
        ell('Crow narrow skull',(0,-.14,.16),(.076,.09,.075),edge,b)
        leaf('Crow wedge beak',(0,-.18,.16),(0,-.34,.13),.045,bronze,b)
        for sign in (-1,1):
            leaf('Corvid angular pinion',(sign*.07,.03,.1),(sign*.12,.28,-.05),.075,feather,b)
        leaf('Crow fork tail',(0,.10,.06),(0,.40,-.03),.065,edge,b)
        return b

    def heron():
        root=empty('Iron heron ground');body=empty('Thorax and sternum',(0,0,1.62),root)
        ell('Keel shaped metal thorax',(0,.12,.06),(.32,.52,.48),feather,body)
        for j in range(6):
            leaf('Segmented silver breast',(0,-.28,.38-j*.095),(0,-.39,.10-j*.095),.22-j*.018,edge if j%3==0 else bronze,body)
        neck=empty('Coiled harpoon neck',(0,-.18,.22),body)
        rod('S neck bronze vertebrae',[(0,0,0),(0,.04,.37),(0,-.20,.67),(0,-.34,.72)],.10,bronze,neck)
        for j in range(5):
            ring('Neck overlapping collar',(0,-.025-j*.044,.2+j*.095),.105,.018,edge,neck,scale=(1,1,.65))
        head=empty('Harpoon skull',(0,-.35,.73),neck)
        ell('Long narrow cranial plate',(0,0,.015),(.14,.23,.13),feather,head)
        beak=empty('Sliding telescopic harpoon',(0,-.18,0),head)
        # A lancet, with a dark split and an actual hooked barb.
        mesh('Four sided lance',[(0,0,.075),(-.08,0,0),(0,0,-.055),(.08,0,0),(0,-.70,-.035)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(0,3,2,1)],edge,beak)
        leaf('Backward cutting harpoon barb',(0,-.48,-.03),(.11,-.33,-.09),.035,bronze,beak)
        for sign in (-1,1):
            ell('Recessed eye socket',(sign*.125,-.11,.055),(.026,.078,.047),dark,head)
            ell('Cyan slit eye',(sign*.149,-.12,.06),(.014,.05,.017),accent,head)
            leaf('Brow blade',(sign*.11,-.19,.11),(sign*.19,.05,.14),.045,edge,head)
            for j in range(3):leaf('Swept crest',(sign*.045,.05,.08),(sign*(.14+j*.045),.40+j*.035,.13+j*.05),.038,bronze,head)
        legs=[];wings=[]
        for sign in (-1,1):
            leg=empty('Reverse knee stilt',(sign*.20,.12,1.65),root);legs.append((leg,sign))
            rod('Forged shin',[(0,0,0),(0,.17,-.62),(0,-.10,-1.50)],.043,bronze,leg)
            ell('Riveted knee',(0,.17,-.62),(.075,.075,.072),edge,leg)
            for j in range(3):rod('Splayed marsh talon',[(0,-.10,-1.50),((j-1)*.14,-.43,-1.59),((j-1)*.16,-.53,-1.57)],.024,edge,leg)
            rod('Rear spur',[(0,-.10,-1.50),(0,.12,-1.58)],.023,bronze,leg)
            wing=empty('Articulated sheet metal wing',(sign*.25,.10,.29),body);wings.append((wing,sign))
            for j in range(9):
                leaf('Overlapping sheared flight feather',(0,.02+j*.035,-j*.025),(sign*(.25+.045*j),.44+.035*j,-.28-j*.038),.11,edge if j%4==0 else feather,wing)
                leaf('Oxidized feather seam',(sign*.02,.12+j*.035,-.01-j*.025),(sign*(.18+.045*j),.43+.035*j,-.24-j*.038),.018,bronze,wing)
            for j in range(3):leaf('Tail sheet',(sign*.09,.44,-.08),(sign*(.20+j*.08),.95,-.32),.065,feather,body)
        return root,{'body':body,'neck':neck,'beak':beak,'wings':wings,'legs':legs,'head':head}

    def toad():
        root=empty('Vat toad ground');body=empty('Cauldron suspended abdomen',(0,0,.70),root)
        ell('Low amphibian mantle',(0,.12,.12),(.72,.65,.52),skin,body)
        # Open copper vessel buried in the back, held by widely spaced iron ribs.
        vat=empty('Boiling open back cistern',(0,.19,.65),body)
        verts=[]
        for rad,z in [(.18,-.37),(.49,-.13),(.49,.08),(.43,.06),(.17,-.30)]:
            verts.extend((rad*math.cos(j*math.tau/32),rad*.93*math.sin(j*math.tau/32),z) for j in range(32))
        faces=[(k*32+j,k*32+(j+1)%32,(k+1)*32+(j+1)%32,(k+1)*32+j) for k in range(4) for j in range(32)]
        mesh('Open hammered bronze bowl',verts,faces,bronze,vat)
        ring('Heavy rolled cauldron lip',(0,0,.08),.49,.055,edge,vat,scale=(1,.93,1))
        ell('Only luminous liquid surface',(0,0,.065),(.43,.40,.025),accent,vat)
        ring('Liquid meniscus',(0,0,.09),.35,.016,accent,vat)
        rivets(vat,(0,0,.09),.51,bronze)
        for j in range(8):
            t=j*math.tau/8;rod('Cage rib',[(.46*math.cos(t),.43*math.sin(t),.06),(.52*math.cos(t),.48*math.sin(t),-.18),(.26*math.cos(t),.25*math.sin(t),-.39)],.032,edge,vat)
        head=empty('Heavy hinged maxilla',(0,-.49,.24),body)
        mesh('Broad scarred wedge skull',[(-.48,.16,.10),(.46,.16,.11),(-.60,-.12,.13),(.57,-.12,.11),(-.48,-.37,.04),(.47,-.37,.015),(-.44,.10,-.12),(.44,.10,-.12),(-.46,-.30,-.10),(.45,-.30,-.12),(0,-.13,.21)],[(0,1,10),(0,10,2),(2,10,4),(4,10,5),(5,10,3),(3,10,1),(0,2,8,6),(2,4,8),(4,5,9,8),(5,3,7,9),(3,1,7),(0,6,7,1),(6,8,9,7)],skin,head)
        ell('Deep wide mouth',(0,-.37,-.04),(.46,.035,.085),dark,head)
        rod('Uneven pale lip',[(-.5,-.27,-.09),(-.27,-.40,-.05),(0,-.43,-.055),(.28,-.40,-.06),(.50,-.28,-.10)],.022,lichen,head)
        jaw=empty('Lower mandible',(0,-.20,-.1),head)
        shard('Asymmetric lower jaw',(0,-.08,-.015),(.48,.25,.095),lichen,jaw)
        tongue=empty('Retractable barbed tongue',(0,-.40,-.04),head)
        rod('Long muscular tongue',[(0,0,0),(.04,-.28,.01),(0,-.87,-.025)],.048,clay,tongue)
        leaf('Hook tongue tip',(0,-.7,0),(0,-1.0,.1),.10,clay,tongue)
        for sign in (-1,1):
            shard('Angular armored orbital ridge',(sign*.40,-.14,.18),(.19,.18,.10),skin,head)
            ell('Narrow obsidian eye',(sign*.41,-.29,.235),(.085,.025,.022),dark,head)
            rod('Bony eye hood',[(sign*.31,-.27,.26),(sign*.42,-.31,.29),(sign*.51,-.26,.25)],.026,lichen,head)
            leaf('Backward brow horn',(sign*.44,-.15,.23),(sign*.56,.04,.35),.065,lichen,head)
            for j in range(3):leaf('Exposed lower fang',(sign*(.20+j*.09),-.34,-.09),(sign*(.22+j*.09),-.36,-.015),.016,bronze,head)
        legs=[]
        for sign in (-1,1):
            for front in (True,False):
                leg=empty('Fore brace' if front else 'Folded frog haunch',(sign*(.48 if front else .56),-.30 if front else .40,.18),body)
                legs.append((leg,sign,front))
                ell('Angular frog muscle',(.13*sign,.04,-.09),(.21,.25,.21),skin,leg)
                rod('Bent webbed limb',[(0,0,0),(sign*.34,.23 if not front else -.18,-.22),(sign*.23,-.32,-.72)],.07,lichen,leg)
                for j in range(3):
                    rod('Spread webbed finger',[(sign*.23,-.32,-.72),(sign*(.11+j*.12),-.55,-.77)],.026,skin,leg)
                leaf('Web between toes',(sign*.23,-.29,-.70),(sign*.24,-.55,-.765),.18,skin,leg)
        # Geometric pores and patches, not procedural grain.
        for j in range(18):
            t=j*2.399;xx=.61*math.cos(t);yy=.50*math.sin(t)
            shard('Mossy callus',(xx,yy,.38+(.03*(j%3))),(.055,.07,.035),lichen if j%3 else bronze,body)
        bubbles=[];steam=[]
        for j in range(5):
            b=ell('Boiling mud blister',((j-2)*.14,-.02,.12),(.07,.07,.06),clay,vat);bubbles.append(b)
        for j in range(4):
            st=empty('Angular steam curl',((j-1.5)*.17,.16,.15),vat);steam.append(st)
            rod('Pale vapor ribbon',[(0,0,0),(.04,.02,.13),(-.025,.03,.27),(.05,.04,.36)],.014,mist,st)
        leak=empty('Fractured vat spill',(0,-.25,-.17),vat)
        for j in range(3):leaf('Liquid fracture seam',((j-1)*.13,0,.20),((j-1)*.17,-.13,-.42),.017,accent,leak)
        return root,{'body':body,'head':head,'jaw':jaw,'tongue':tongue,'legs':legs,'vat':vat,'bubbles':bubbles,'steam':steam,'leak':leak}

    def reaper():
        root=empty('Scarecrow ground');body=empty('Crooked timber spine',(0,0,1.25),root)
        rod('Split leaning oak backbone',[(0,0,-.89),(-.09,.08,-.30),(.08,0,.43),(.02,0,.85)],.082,wood,body)
        # Frayed hanging poncho: a real irregular volume and long nonuniform hems.
        verts=[(-.19,.09,.57),(.22,.09,.57),(.55,0,.26),(.36,-.12,-.60),(.17,-.18,-.41),(.04,-.20,-.84),(-.14,-.17,-.50),(-.37,-.06,-.70),(-.47,0,.18),(0,-.23,.24)]
        mesh('Torn wet canvas front',verts,[(0,1,9),(1,2,9),(2,3,9),(3,4,9),(4,5,9),(5,6,9),(6,7,9),(7,8,9),(8,0,9)],cloth,body)
        back=[(x,-y+.13,z) for x,y,z in verts];mesh('Torn wet canvas rear',back,[(a,c,b) for a,b,c in [(0,1,9),(1,2,9),(2,3,9),(3,4,9),(4,5,9),(5,6,9),(6,7,9),(7,8,9),(8,0,9)]],feather,body)
        for j in range(7):
            x=(j-3)*.095;leaf('Canvas repaired vertical pleat',(x,-.24,.34),(x*1.2,-.21,-.54-abs(x)),.025,linen,body)
        for z in (-.3,.1,.4):rod('Binding rope',[(-.2,-.17,z),(0,-.25,z-.04),(.23,-.14,z+.03)],.025,bronze,body)
        head=empty('Hanged sack skull',(.04,-.015,.76),body)
        shard('Narrow stitched sack',(0,0,.12),(.20,.18,.29),linen,head)
        for sign in (-1,1):
            ell('Eye gouge',(sign*.08,-.158,.17),(.060,.025,.041),dark,head)
            leaf('Cyan ember slit',(sign*.12,-.187,.19),(sign*.035,-.195,.15),.018,accent,head)
        rod('Stitched mouth',[(-.1,-.18,.045),(0,-.207,.005),(.10,-.18,.025)],.012,dark,head)
        for j in range(5):rod('Mouth staple',[((j-2)*.038,-.20,.045),((j-2)*.038+.012,-.21,-.015)],.009,wood,head)
        # Wide broken brim and a hooked crown, deliberately asymmetric.
        ring('Battered hat brim',(0,0,.35),.28,.045,wood,head,scale=(1.3,.85,.5))
        mesh('Collapsed torn hat crown',[(-.16,-.12,.34),(.16,-.12,.34),(.15,.13,.34),(-.13,.14,.34),(-.04,-.03,.47),(.15,.13,.43)],[(0,1,4),(1,2,5,4),(2,3,4,5),(3,0,4)],cloth,head)
        legs=[];arms=[]
        for sign in (-1,1):
            leg=empty('Crooked stake leg',(sign*.13,0,-.28),body);legs.append((leg,sign))
            rod('Splintered shin',[(0,0,0),(sign*.055,.03,-.32),(sign*.10,-.10,-.86)],.046,wood,leg)
            rod('Rag bound foot',[(sign*.10,-.10,-.86),(sign*.14,-.31,-.90)],.057,linen,leg)
            for j in range(2):leaf('Leg splinter',(0,0,-.10),(sign*(.16+j*.02),.03,-.02+j*.10),.018,edge,leg)
            arm=empty('Rotating timber arm',(sign*.21,0,.39),body);arms.append((arm,sign))
            rod('Elbow branch',[(0,0,0),(sign*.36,-.02,-.08),(sign*.60,-.08,-.20)],.048,wood,arm)
            leaf('Hanging sleeve',(sign*.07,.03,.04),(sign*.39,-.03,-.48),.12,cloth,arm)
            for j in range(3):rod('Twig gripping finger',[(sign*.57,-.08,-.20),(sign*.68,-.14-j*.025,-.26+j*.025)],.015,edge,arm)
        weapon=empty('Scythe sweeping pivot',(.02,-.02,.24),body)
        rod('Long warped haft',[(.62,-.12,-1.19),(.68,-.09,-.36),(.70,-.08,.55),(.61,-.08,1.18)],.034,bronze,weapon)
        blade=empty('Extending crescent blade',(.61,-.08,1.16),weapon)
        plate('Long rusted crescent',[(0,0),(-.24,.09),(-.61,.04),(-.91,-.12),(-1.13,-.44),(-.77,-.22),(-.45,-.15),(-.12,-.14)],-.025,.05,rust,blade)
        rod('Nicked cold cutting edge',[(0,0,-.14),(-.45,0,-.15),(-.77,0,-.22),(-1.13,0,-.44)],.014,edge,blade)
        crows=[]
        for j,p in enumerate([(-.50,.03,.45),(.30,.15,.62),(-.22,.10,1.38),(.52,.17,.20),(-.36,.19,-.10)]):crows.append(bird(body,p,.85 if j<3 else .72))
        furrows=[]
        for j in range(3):
            f=empty('Harvest furrow',((j-1)*.36,-.26,-1.10),body);furrows.append(f)
            rod('Torn raised earth',[(0,0,0),(.04,-.28,.035),(-.03,-.55,0)],.035,clay,f)
        return root,{'body':body,'head':head,'arms':arms,'legs':legs,'weapon':weapon,'blade':blade,'crows':crows,'furrows':furrows}

    for who in selected():
        s=iso_rig.create_rig('CREA',170)
        s.camera.data.ortho_scale=4.051028251647949;s.camera.data.shift_y=.2
        s.render.threads_mode='FIXED';s.render.threads=8
        # Rim from the upper left, readable in all orientations, baked in cel tones.
        ld=bpy.data.lights.new('Cold upper left contour','AREA');ld.energy=330;ld.color=(.45,.70,1);ld.shape='DISK';ld.size=3
        lo=bpy.data.objects.new(ld.name,ld);s.collection.objects.link(lo);lo.location=(-3,1,5);lo.rotation_euler=(Vector((0,0,1))-lo.location).to_track_quat('-Z','Y').to_euler()
        bronze=mat('Terrace oxidized bronze 8C7A4C','8C7A4C');edge=mat('Cold exposed tin edges','A0AAA5')
        feather=mat('Desaturated folded sheet steel','75817F' if who=='iron_heron' else '667674');dark=mat('Deep recessed cavities','373D3B')
        skin=mat('Wet moss toad hide','6F7D73');lichen=mat('Pale lichen scars','9A9E7C')
        wood=mat('Waterlogged charcoal oak lit grain','7A827B');cloth=mat('Wet ash hessian','909584');linen=mat('Frayed silver flax','B7B59E')
        rust=mat('Desaturated rusted blade','907053');clay=mat('Silt flesh and mud','8D8270');mist=mat('Cool vapor','A2B1AF')
        accent=material('Single water cyan accent 5EC8FF','5EC8FF',2.2,True)
        root,parts={'iron_heron':heron,'vat_toad':toad,'scarecrow_reaper':reaper}[who]()
        # Normalize idle geometry only, at the fixed frost_bear camera scale.
        # Keep the camera pivot [85,119]; feet are calibrated to the native bottom=140.
        # Transient effects excluded from body size calibration.
        if who=='vat_toad':parts['tongue'].scale=(.001,)*3;parts['leak'].scale=(.001,)*3
        if who=='scarecrow_reaper':
            for ob in parts['furrows']+parts['crows'][3:]:ob.scale=(.001,)*3
        pose(root,1,'s')
        def projected():
            bpy.context.view_layer.update();v=[]
            for ob in root.children_recursive:
                if ob.type!='MESH' or min(ob.matrix_world.to_scale())<.01:continue
                v.extend(world_to_camera_view(s,s.camera,ob.matrix_world@Vector(c)) for c in ob.bound_box)
            return v
        dim=125 if who=='iron_heron' else 115
        spans=[]
        for d in ['e','s','w','n']:
            pose(root,1,d);v=projected()
            spans.append(max(max(p.x for p in v)-min(p.x for p in v),max(p.y for p in v)-min(p.y for p in v))*170)
        span=max(spans)
        root.scale=(dim/span,)*3
        pose(root,1,'s')
        v=projected();bottom=(1-min(p.y for p in v))*170
        root.location.z+=(bottom-140)/170*s.camera.data.ortho_scale/math.cos(math.pi/6)
        # Store all authored rests, so every action starts cleanly.
        controls=[ob for ob in root.children_recursive if ob.type=='EMPTY']+parts.get('bubbles',[])
        rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in controls}
        for a,(start,n) in SPECS.items():
            for i in range(n):
                for o,(l,r,sc) in rest.items():o.location=l;o.rotation_euler=r;o.scale=sc
                p=i/(n-1);t=i*math.tau/n
                hit=([0,-.23,-.52,1,.35,0][i] if a=='attack' else [0,-.1,-.28,-.45,1,.54,.18,0][i] if a in ('cast_a','cast_b') else 0)
                positive=max(0,hit);death=p if a=='death' else 0
                body=parts['body'];body.location.z+=.018*math.sin(t)
                parts['head'].rotation_euler.z=.025*math.cos(t)
                if a=='run':body.location.z+=.045*math.sin(t*2)
                if a=='death':body.location.z-=.58*death;body.rotation_euler.y=1.32*death
                if who=='iron_heron':
                    neck=parts['neck'];beak=parts['beak']
                    if a in ('attack','cast_a'):
                        neck.rotation_euler.x=.92*hit;body.location.y-=.19*hit
                        beak.location.y-=positive*(.17 if a=='cast_a' else .08)
                        body.rotation_euler.x=.20*hit
                    if a=='phase2':neck.rotation_euler.x=-.32*math.sin(math.pi*p/2);body.location.z+=.11*p
                    if a=='cast_b':
                        body.location.z+=([0,-.04,-.10,-.14,.24,.30,.32,.34][i]);body.rotation_euler.x=-.10*positive
                        neck.rotation_euler.x=.5 if i>=4 else 0
                        for leg,sign in parts['legs']:leg.location.z+=([0,0,-.04,-.08,.20,.24,.26,.28][i])
                    for wing,sign in parts['wings']:
                        spread=(.9*positive if a=='cast_b' else .72*p if a=='phase2' else .08*math.sin(t))
                        if a=='cast_b' and i>=4:spread=.9+.10*math.sin(t)
                        wing.rotation_euler.y=sign*(-spread);wing.rotation_euler.z=sign*.10*hit
                    for leg,sign in parts['legs']:
                        if a=='run':leg.rotation_euler.x=.38*math.sin(t+(math.pi if sign<0 else 0))
                        if a=='cast_b' and i>=4:leg.rotation_euler.x=-.5
                        if death:leg.rotation_euler.y=sign*.6*death
                elif who=='vat_toad':
                    head=parts['head'];tongue=parts['tongue'];jaw=parts['jaw']
                    body.scale.z=1+.025*math.sin(t)
                    if a=='attack':
                        head.rotation_euler.x=.22*hit;body.location.y+=.12*hit
                        tongue.scale=(1,.35*positive,.8) if positive else (.001,)*3
                        jaw.rotation_euler.x=.4*positive
                    if a=='cast_a':
                        body.scale=(1+.13*max(0,-hit),1+.1*max(0,-hit),1+.19*max(0,-hit));head.rotation_euler.x=-.32*hit;jaw.rotation_euler.x=.4*positive
                    if a=='cast_b':
                        z=[0,-.07,-.14,-.20,.24,.28,.30,.32][i];body.location.z+=z;body.scale.z=1+min(0,z)*1.2
                    if death:body.location.z+=.65*death
                    if a=='phase2':parts['vat'].rotation_euler.y=.14*p;parts['leak'].scale=(p,p,p)
                    for leg,sign,front in parts['legs']:
                        leg.rotation_euler.x=(.45*math.sin(t+(math.pi if (sign<0)==front else 0)) if a=='run' else -.7*positive if a=='cast_b' else 0)
                    for j,b in enumerate(parts['bubbles']):
                        b.location.z+=.035*math.sin(t+j)
                        if a=='cast_a' and i>=4:b.location.y=-.95-(i-4)*.16;b.location.z=-.15+(i-4)*.10
                    for j,st in enumerate(parts['steam']):
                        st.rotation_euler.z=.20*math.sin(t+j);st.scale=(1,1,.75+.20*math.sin(t+j))
                else:
                    head=parts['head'];weapon=parts['weapon']
                    if a=='attack':
                        weapon.rotation_euler.z=math.radians([-12,-43,-88,92,40,12][i]);body.rotation_euler.z=.24*hit
                        body.rotation_euler.x=.15*hit;head.rotation_euler.z=-.18*hit
                    if a=='cast_a':
                        weapon.rotation_euler.y=-.65*hit;weapon.location.z-=.28*positive;body.rotation_euler.x=.32*hit
                        for f in parts['furrows']:f.scale=(positive,)*3
                    if a=='phase2':parts['blade'].scale=(1+.4*p,1,1+.12*p);head.rotation_euler.y=-.15*p
                    for arm,sign in parts['arms']:
                        arm.rotation_euler.y=sign*(-.80*positive if a=='cast_b' else -.16*hit)
                    for leg,sign in parts['legs']:
                        if a=='run':leg.rotation_euler.x=.5*math.sin(t+(math.pi if sign<0 else 0))
                    for j,crow in enumerate(parts['crows']):
                        if j>=3:crow.scale=(.72,)*3 if a=='phase2' and i>=4 else (.001,)*3
                        crow.rotation_euler.z=.1*math.sin(t+j)
                        if a=='cast_b' and i>=4:
                            k=(i-3)/4;crow.location+=Vector(((j-1)*.24*k,-.45*k,.24*k));crow.rotation_euler.x=-.35
                for o in controls:key(o,start+i)
            s.timeline_markers.new(a,frame=start)
        s.frame_start=1;s.frame_end=130;s.render.fps=12
        s['m1a_contract']=json.dumps({'cell':170,'dim':dim,'bottom':140,'camera_scale':s.camera.data.ortho_scale,'impact_indices':[3,4,4],'normals':False})
        s['animation_manifest']=json.dumps({a:{'start':start,'frames':n,'directions':dirs(a),'fps':14 if a=='run' else 12,'loop':a in ('idle','run')} for a,(start,n) in SPECS.items()})
        iso_rig.bake_ao_shadows(root)
        cel.install('creature',normals=False);cel.setup_scene();cel.toon_materials('creature')
        pose(root,1,'s');SRC.mkdir(parents=True,exist_ok=True)
        first=raw(who,'idle','s',0);first.parent.mkdir(parents=True,exist_ok=True)
        iso_rig.common.configure_passes(first)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/f'm1a_{who}.blend'))
        # Local adapter for iso_rig.render_frame, whose legacy loop requires _n.
        # Reuse its compositor and 2x LANCZOS pipeline without any normal output.
        from PIL import Image
        for a,(start,n) in SPECS.items():
            if '--anim' in sys.argv and a not in sys.argv[sys.argv.index('--anim')+1].split(','):continue
            for d in dirs(a):
                for i in range(n):
                    dest=raw(who,a,d,i);dest.parent.mkdir(parents=True,exist_ok=True)
                    if '--resume' in sys.argv and dest.exists() and dest.with_stem(dest.stem+'_e').exists():continue
                    pose(root,start+i,d);iso_rig.common.configure_passes(dest)
                    s.render.filepath=str(dest);bpy.ops.render.render(write_still=True)
                    candidates=list(dest.parent.glob(dest.stem+'_e__*.png'));assert len(candidates)==1
                    ep=dest.with_stem(dest.stem+'_e');candidates[0].replace(ep)
                    for fp in (dest,ep):
                        with Image.open(fp) as im:small=im.convert('RGBA').resize((170,170),Image.Resampling.LANCZOS)
                        small.save(fp,optimize=True,compress_level=9)
            print('M1A_COMPLETE',who,a,flush=True)
        print('M1A_MINI_PASS',who,flush=True)

def inspect():
    import bpy
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    sys.path[:0]=[str(ROOT/'art/tools/monsters')]
    from common import pose
    for who in selected():
        bpy.ops.wm.open_mainfile(filepath=str(SRC/f'm1a_{who}.blend'))
        s=bpy.context.scene;root=next(o for o in s.objects if o.type=='EMPTY' and not o.parent)
        for d in ['e','s','w','n']:
            pose(root,21,d);entries=[]
            for o in root.children_recursive:
                if o.type!='MESH' or min(o.matrix_world.to_scale())<.005:continue
                pts=[world_to_camera_view(s,s.camera,o.matrix_world@Vector(c)) for c in o.bound_box]
                b=[min(p.x for p in pts),min(p.y for p in pts),max(p.x for p in pts),max(p.y for p in pts)]
                if min(b[0],b[1],1-b[2],1-b[3])<.02:entries.append((o.name,[round(v,3) for v in b]))
            print('INSPECT',who,d,entries[:8],flush=True)

if __name__=='__main__':
    if '--render' in sys.argv:build()
    if '--pack' in sys.argv:pack()
    if '--verify' in sys.argv:verify()
    if '--contact' in sys.argv:contact()
    if '--inspect' in sys.argv:inspect()
