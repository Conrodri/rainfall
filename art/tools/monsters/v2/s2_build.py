"""MOB_V2_S2: fresh articulated salt greyhound and drowned caryatid.
Blender --background --python art/tools/monsters/v2/s2_build.py -- leaper|brute|contact
Shared CREA cells, cel AOV, atlas writer and verification remain in common_v2.
"""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common_v2 import *
from t1_build import resetters
from t2_build import plate, fin, ring, plant, finish

_shared_finish=finish
def finish(name,size,bottom,counts,root,pose):
    if '--check' not in sys.argv:
        return _shared_finish(name,size,bottom,counts,root,pose)
    from bpy_extras.object_utils import world_to_camera_view
    s=bpy.context.scene; worst=[size[0],size[1],0,0]; culprit=[]
    meshes=[o for o in root.children_recursive if o.type=='MESH']
    for a,n in counts.items():
        ab=[size[0],size[1],0,0]
        for d in (('e','s','w','n') if a=='death' else DIRS):
            root.rotation_euler.z=math.radians(90-45*DIRS.index(d)); rot=root.rotation_euler.to_matrix()
            lowest=min((rot@Vector(p)).y*.5+p[2]*math.cos(math.pi/6) for p in root['foot_reference'])
            s.camera.data.shift_y=(bottom-size[1]/2+lowest*64)/size[0]
            for f in range(n):
                pose(a,f,n); bpy.context.view_layer.update()
                ps=[world_to_camera_view(s,s.camera,o.matrix_world@v.co) for o in meshes for v in o.data.vertices]
                box=[min(p.x for p in ps)*size[0],(1-max(p.y for p in ps))*size[1],max(p.x for p in ps)*size[0],(1-min(p.y for p in ps))*size[1]]
                worst=[min(worst[0],box[0]),min(worst[1],box[1]),max(worst[2],box[2]),max(worst[3],box[3])]
                ab=[min(ab[0],box[0]),min(ab[1],box[1]),max(ab[2],box[2]),max(ab[3],box[3])]
                if min(box[0],box[1],size[0]-box[2],size[1]-box[3])<4: culprit.append((a,d,f,[round(v,1) for v in box]))
        print('S2 BOUNDS',a,[round(v,1) for v in ab],flush=True)
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    print('S2 PREFLIGHT',name,'tris',tris,'bounds',[round(v,1) for v in worst],'overflow',culprit[:6],flush=True)


def palette():
    return (material('Ivory salt bone','D2D4BD'),
            material('Salt shadow blue','789794'),
            material('Black drowned algae','303E3D'),
            material('Crystal BFF4FF','BFF4FF',1.0))


def supported(body):
    """Ground support for collapse poses; no ground mesh or painted shadow."""
    bpy.context.view_layer.update()
    lo=min((o.matrix_world@Vector(c)).z for o in body.children_recursive
           if o.type=='MESH' for c in o.bound_box)
    body.location.z-=lo-.012


def planted(hip,knee,foot,upper,lower,y,z):
    # No reach clamping during stance: soles stay on the same ground plane.
    assert math.hypot(y,z)<math.hypot(*upper)+math.hypot(*lower)-.001
    plant(hip,knee,foot,upper,lower,y,z)


def leaper():
    rig((96,96),82)
    pale,salt,dark,glow=palette()
    root=empty('Levrier de sel - CREA direction')
    body=empty('Articulated spine and breathing ribs',(0,.04,.70),root)
    # Open rib cage: individual arched ribs, no enclosing shell.
    taper('Spine',(0,-.22,.08),(0,.31,.09),(.063,.05),pale,body,6)
    ellipsoid('Oversized pelvis',(0,.27,.015),(.19,.16,.12),pale,body,2)
    for i in range(5):
        y=-.19+i*.074
        for sign in (-1,1):
            pts=((0,y,.07),(sign*.13,y-.014,.005),(sign*.15,y,-.12),(sign*.055,y+.014,-.19))
            for j in range(3):
                taper('Visible curved rib %d %d %d'%(i,sign,j),pts[j],pts[j+1],(.024,.018),pale,body,4)
    for i in range(5):
        y=-.18+i*.105
        fin('Dorsal salt crystal %d'%i,[(-.038,y,.10),(.042,y,.10),(.022,y+.015,.26 if i%2 else .22)],.065,salt,body)
    head=empty('Neck and long skull hinge',(0,-.23,.06),body)
    taper('Sloping neck',(0,0,0),(0,-.12,.045),(.083,.065),pale,head,6)
    ellipsoid('Long greyhound cranium',(0,-.16,.035),(.105,.14,.086),pale,head,2)
    taper('Long nasal bone',(0,-.19,.025),(0,-.38,-.005),(.074,.047),pale,head,5)
    plate('Dark nasal cavity',(0,-.377,-.003),(.074,.029,.045),dark,head,.006)
    for sign in (-1,1):
        ellipsoid('Deep eye socket',(sign*.083,-.19,.055),(.037,.043,.037),dark,head)
        ellipsoid('Crystal eye',(sign*.097,-.211,.061),(.027,.025,.022),glow,head)
        fin('Broken tall ear',[(sign*.065,-.09,.07),(sign*.103,-.055,.08),(sign*.095,-.025,.21)],.045,pale,head)
    jaw=empty('Hinged lower mandible',(0,-.12,-.043),head)
    for sign in (-1,1):
        taper('Mandible fork',(sign*.067,0,0),(sign*.038,-.255,0),(.027,.019),pale,jaw,4)
        for i in range(3):
            taper('Readable salt tooth',(sign*.04,-.13-i*.047,.006),(sign*.04,-.13-i*.047,.046),(.012,.002),pale,jaw,4)
    mouth=empty('Bite impact crystal throat',(0,-.20,-.022),head)
    ellipsoid('Open mouth accent',(0,0,0),(.055,.095,.043),glow,mouth)
    # Chain is a lagged hierarchy, terminating in a hollow reliquary.
    chain=empty('Reliquary chain root',(0,.37,.025),body)
    parent=chain
    for i in range(4):
        link=empty('Chain link hinge %d'%i,(0,.051 if i else .015,-.025),parent)
        o=ring('Iron reliquary link',(0,0,0),.034,.009,dark,link)
        o.rotation_euler=(math.pi/2,0,(i%2)*math.pi/2)
        parent=link
    relic=plate('Salt reliquary at chain tip',(0,.035,-.025),(.082,.09,.055),pale,parent,.012)
    legs=[]; refs=[]
    for i,y in enumerate((-.20,.27)):
        for sign in (-1,1):
            hip=empty('Hip %d %d'%(i,sign),(sign*.135,y,-.035),body)
            upper=(.08,-.30) if i else (.025,-.30)
            lower=(-.08,-.35) if i else (-.025,-.35)
            knee=empty('True hock joint',(0,*upper),hip)
            foot=empty('Level paw pivot',(0,*lower),knee)
            taper('Thick thigh' if i else 'Shoulder blade',(0,0,0),tuple(knee.location),(.075 if i else .047,.027),pale,hip,5)
            ellipsoid('Dark joint',(0,0,0),(.037,.039,.038),dark,knee)
            taper('Narrow shin',(0,0,0),tuple(foot.location),(.029,.017),pale,knee,5)
            plate('Cloven salt paw',(0,-.024,.005),(.08,.115,.037),pale,foot,.008)
            legs.append((hip,knee,foot,upper,lower,i,sign)); refs.append((sign*.135,y+.016,.012))
    root.scale=(.93,)*3
    root['foot_reference']=[tuple(v*.93 for v in p) for p in refs]
    reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n
        mouth.scale=(.025,)*3
        body.scale.z=1+.025*math.sin(t+.2)
        head.rotation_euler.z=.035*math.sin(t+.7)
        chain.rotation_euler.x=.18*math.sin(t-math.pi/4)
        if a=='idle':
            head.rotation_euler.x=.065*math.sin(t+.4)
            jaw.rotation_euler.x=.08*max(0,math.sin(t))
        elif a=='run':
            body.scale.z=1; body.location.z+=-.04+.014*math.cos(2*t)
            for hip,knee,foot,u,l,i,sign in legs:
                p=t+(math.pi if (i==0)==(sign<0) else 0)
                # Stance traverses at constant speed; swing lifts and returns.
                q=(p/math.tau)%1
                yy=.20*(1-4*q) if q<.5 else -.20+.40*(q-.5)*2
                lift=0 if q<.5 else .13*math.sin((q-.5)*math.tau)
                planted(hip,knee,foot,u,l,yy,-.605-.014*math.cos(2*t)+lift)
            head.rotation_euler.x=.07*math.sin(t+.4)
            chain.rotation_euler.z=.30*math.sin(t-math.pi/4)
        elif a=='charge':
            q=f/(n-1); body.location.z-=.13*q; body.location.y+=.035*q
            body.rotation_euler.x=-.14*q; head.rotation_euler.x=-.12*q
            for hip,knee,foot,u,l,i,sign in legs:
                hip.rotation_euler.x=(-.6 if i else .24)*q; knee.rotation_euler.x=.75*q
            chain.rotation_euler.x=-.4*q
            supported(body)
        elif a=='leap':
            body.location.z+=.08+.012*math.sin(t)
            body.scale.y=1.05; head.location.y-=.025
            for hip,knee,foot,u,l,i,sign in legs:
                hip.rotation_euler.x=(.35 if i else -.36)+.06*math.sin(t+i)
                knee.rotation_euler.x=.12+.06*math.cos(t+.4)
            chain.rotation_euler.x=-.55+.1*math.sin(t-.8)
        elif a=='attack':
            ext=(0,-.035,-.075,.10,.035,.008)[f]
            body.location.y-=ext*.35
            head.location.y-=ext; head.location.z+=(0,.025,.055,.015,-.01,0)[f]
            head.scale.x=1.4 if f==3 else 1
            head.rotation_euler.x=(0,-.12,-.24,-.18,.17,.03)[f]
            jaw.rotation_euler.x=(.04,.13,.22,.9,.48,.12)[f]
            if f==3:
                head.location.z-=.055
                mouth.location.y=-.30; mouth.location.z=-.10
                mouth.scale=(1.25,1.0,1.2)
            for hip,knee,foot,u,l,i,sign in legs:
                hip.rotation_euler.x=(-.35 if i==0 else .35)*max(0,ext/.12)
        elif a=='death':
            q=f/(n-1); body.rotation_euler.x=.60*q
            body.rotation_euler.y=.24*q; body.scale.z=1-.35*q
            head.rotation_euler.x=.5*q; jaw.rotation_euler.x=.3+.25*q
            for hip,knee,foot,u,l,i,sign in legs:
                hip.rotation_euler.y=sign*.8*q; knee.rotation_euler.x=1.15*q
            supported(body)
    finish('leaper_tier2_salt',(96,96),82,dict(idle=4,run=8,charge=6,leap=4,attack=6,death=4),root,pose)


def brute():
    rig((128,136),124)
    pale,salt,dark,glow=palette()
    root=empty('Cariatide noyee - CREA direction')
    body=empty('Broken column pelvis',(0,0,.57),root)
    plate('Fractured waist plinth',(0,0,.04),(.47,.31,.19),pale,body,.035)
    torso=empty('Upper fractured column hinge',(0,0,.19),body)
    taper('Tapered column torso',(0,0,0),(0,0,.56),(.20,.29),pale,torso,8)
    # Flutes and broken lower ends describe a statue, with algae in the recesses.
    for i in range(8):
        a=math.tau*i/8
        x,y=math.cos(a),math.sin(a)
        taper('Exposed stone flute %d'%i,(x*.19,y*.19,.04+(i%3)*.03),(x*.27,y*.27,.53),(.034,.048),salt if i%3==0 else pale,torso,4)
        if i%2==0:
            fin('Black algae ribbon',[(x*.23,y*.23,.36),(x*.25,y*.25,.06),(x*.20+.06,y*.20,-.10)],.038,dark,torso)
    for sign in (-1,1):
        fin('Fracture crystal seam',[(sign*.16,-.178,.05),(sign*.11,-.20,.18),(sign*.08,-.21,.08)],.027,glow,torso)
    plate('Broad worn shoulder lintel',(0,0,.57),(.77,.39,.16),pale,torso,.035)
    head=empty('Sunken small statue head',(0,-.055,.69),torso)
    ellipsoid('Worn stone face',(0,0,0),(.14,.13,.17),pale,head,2)
    plate('Stone heavy brow',(0,-.12,.04),(.25,.075,.065),salt,head,.012)
    for sign in (-1,1):
        ellipsoid('Recessed eye',(sign*.062,-.13,.005),(.034,.019,.022),glow,head)
    taper('Chipped nose',(0,-.12,.04),(0,-.17,-.07),(.034,.023),pale,head,4)
    legs=[]; refs=[]
    for sign in (-1,1):
        hip=empty('Statue hip',(sign*.18,0,0),body)
        knee=empty('Articulated knee',(0,0,-.26),hip)
        foot=empty('Ground sole',(0,0,-.28),knee)
        taper('Stone thigh',(0,0,0),(0,0,-.26),(.14,.095),pale,hip,6)
        plate('Knee block',(0,-.03,0),(.21,.20,.13),salt,knee,.025)
        taper('Stone shin',(0,0,0),(0,0,-.26),(.09,.065),pale,knee,6)
        plate('Broken statue foot',(0,-.045,.015),(.24,.32,.09),pale,foot,.025)
        legs.append((hip,knee,foot,sign))
        refs.extend((sign*.18+dx,yy,.012) for dx in (-.12,.12) for yy in (-.205,.115))
    arms=[]
    for sign in (-1,1):
        shoulder=empty('Right hammer shoulder' if sign>0 else 'Left arm shoulder',(sign*.36,0,.54),torso)
        elbow=empty('Actual elbow hinge',(sign*.09,-.015,-.26),shoulder)
        hand=empty('Articulated stone wrist',(0,-.12,-.22),elbow)
        taper('Upper stone arm',(0,0,0),tuple(elbow.location),(.125,.09),pale,shoulder,6)
        taper('Forearm',(0,0,0),tuple(hand.location),(.10,.065),salt,elbow,6)
        plate('Stone fist',(0,0,0),(.16,.18,.16),pale,hand,.018)
        arms.append((shoulder,elbow,hand,sign))
    shoulder,elbow,hand,_=arms[1]
    hammer=empty('Right hand carried capital',(0,-.015,-.06),hand)
    taper('Broken column hammer grip',(0,0,.05),(0,0,.25),(.045,.065),dark,hammer,6)
    plate('Capital abacus',(0,0,-.11),(.44,.38,.13),pale,hammer,.035)
    taper('Capital echinus',(0,0,-.07),(0,0,.13),(.23,.11),pale,hammer,8)
    for sign in (-1,1):
        o=ring('Ionic capital volute',(sign*.15,-.13,.015),.073,.025,salt,hammer)
        o.rotation_euler.x=math.pi/2
    impact=empty('Hammer impact crystal face',(0,-.205,-.10),hammer)
    plate('Illuminated fracture on capital',(0,0,0),(.31,.025,.063),glow,impact,.006)
    root.scale=(.98,)*3
    root['foot_reference']=[tuple(v*.98 for v in p) for p in refs]; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n
        impact.scale=(.025,)*3
        torso.scale.z=1+.018*math.sin(t+.3)
        head.rotation_euler.z=.045*math.sin(t+.6)
        arms[0][1].rotation_euler.x=.08*math.sin(t-.8)
        if a=='idle':
            shoulder.rotation_euler.x=.035*math.sin(t-.8)
        elif a=='run':
            torso.scale.z=1; body.location.z+=-.055+.016*math.cos(2*t)
            for hip,knee,foot,sign in legs:
                p=(t+(math.pi if sign<0 else 0))/math.tau%1
                yy=.20*(1-4*p) if p<.5 else -.20+.4*(p-.5)*2
                lift=0 if p<.5 else .15*math.sin((p-.5)*math.tau)
                planted(hip,knee,foot,(0,-.26),(0,-.28),yy,-.480-.016*math.cos(2*t)+lift)
            torso.rotation_euler.z=.07*math.sin(t)
            for sh,el,ha,sign in arms:
                sh.rotation_euler.x=sign*.22*math.sin(t-.5)
                el.rotation_euler.x=.15+.08*math.sin(t-.8)
        elif a in ('attack','cast'):
            # Two explicit backward anticipation frames, impact index 4.
            swing=(0,-.27,-.55,-.70,1.20,.85,.35,.07)[f]
            if a=='attack':
                shoulder.rotation_euler.x=-swing
                shoulder.rotation_euler.z=(0,-.12,-.24,-.35,-.85,-.55,-.22,0)[f]
                elbow.rotation_euler.x=.20*max(0,swing)
                torso.rotation_euler.z=(0,.06,.13,.18,-.16,-.11,-.04,0)[f]
                # In the south view the hammer is projected toward the camera.
                if f==4: shoulder.location.y-=.12; hand.location.y-=.10
            else:
                shoulder.rotation_euler.x=(0,.8,1.5,1.9,-.50,-.38,-.20,0)[f]
                elbow.rotation_euler.x=(0,-.2,-.45,-.65,.25,.18,.08,0)[f]
                if f==4:
                    shoulder.location.z-=.44; shoulder.location.y-=.03
                    torso.rotation_euler.x=.15; torso.location.y-=.05
                    hammer.rotation_euler.x=.85
            head.rotation_euler.x=.13 if f==4 else -.025*f
            if f==4: impact.scale=(1.2,1,1.7)
            arms[0][0].rotation_euler.x=-.45 if f==4 else .06*f
        elif a=='death':
            q=f/(n-1); body.rotation_euler.x=.44*q
            torso.rotation_euler.x=.20*q; torso.scale.z=1-.45*q
            torso.rotation_euler.y=-.18*q
            shoulder.rotation_euler.x=-.7*q; elbow.rotation_euler.x=-.65*q
            head.rotation_euler.x=.55*q
            for hip,knee,foot,sign in legs:
                hip.rotation_euler.y=sign*.55*q; knee.rotation_euler.x=1.2*q
            supported(body)
    finish('brute_tier3_salt',(128,136),124,dict(idle=4,run=8,attack=8,cast=8,death=6),root,pose)


def contact_s2():
    # Contact only: compositing existing pixels, at the actual display scale.
    ground=Image.open(ROOT/'game/assets/sprites/terrain/crypts/iso/ground_a.png').convert('RGBA')
    board=Image.new('RGBA',(840,720))
    for y in range(-ground.height,board.height,ground.height//2):
        for x in range(-ground.width,board.width,ground.width):
            board.alpha_composite(ground,(x+(ground.width//2 if (y//(ground.height//2))%2 else 0),y))
    ash=Image.open(ROOT/'game/assets/sprites/bosses/mini/ash_lord/run.png').convert('RGBA')
    import re
    atlas=(ROOT/'game/assets/sprites/bosses/mini/ash_lord/ash_lord.tres').read_text()
    refs={}
    for d in ('s','e'):
        anim=next(b for b in atlas.split('}, {') if '"name": &"run_'+d+'"' in b)
        ident=re.search(r'SubResource\("([^"]+)"\)',anim)[1]
        block=atlas.split('[sub_resource type="AtlasTexture" id="'+ident+'"]')[1].split('[',1)[0]
        region=[int(v) for v in re.search(r'region = Rect2\(([^)]+)\)',block)[1].split(',')]
        margin=[int(v) for v in re.search(r'margin = Rect2\(([^)]+)\)',block)[1].split(',')]
        x,y,w,h=region; mx,my,mw,mh=margin
        ref=Image.new('RGBA',(w+mw,h+mh)); ref.alpha_composite(ash.crop((x,y,x+w,y+h)),(mx,my))
        refs[d]=ref
    factor=2.4*1.1*64/100
    for panel,(a,d) in enumerate((('run','s'),('run','e'),('attack','s'),('attack','e'),('cast','s'),('cast','e'))):
        ox=panel%2*420; baseline=panel//2*240+218
        for x,name,size,bottom,n in ((68,'leaper_tier2_salt',(96,96),82,6),(212,'brute_tier3_salt',(128,136),124,8)):
            action='idle' if a=='cast' and name.startswith('leaper') else a
            f=0 if action in ('run','idle') else n//2; row=DIRS.index(d)
            source=Image.open(ROOT/'game/assets/sprites/monsters'/name/(action+'.png')).convert('RGBA')
            tile=source.crop((f*size[0],row*size[1],(f+1)*size[0],(row+1)*size[1]))
            board.alpha_composite(tile,(ox+x-size[0]//2,baseline-bottom))
        ref=refs[d].resize((round(refs[d].width*factor),round(refs[d].height*factor)),Image.Resampling.LANCZOS)
        board.alpha_composite(ref,(ox+345-ref.width//2,baseline-round(117*factor)))
    board.save(ROOT/'art/tools/night/_mob_v2_s2_contact.png',optimize=True)


def validate_s2():
    import re
    from PIL import ImageChops
    for name,size,counts in (
        ('leaper_tier2_salt',(96,96),dict(idle=4,run=8,charge=6,leap=4,attack=6,death=4)),
        ('brute_tier3_salt',(128,136),dict(idle=4,run=8,attack=8,cast=8,death=6))):
        verify(name,size,counts)
        out=ROOT/'game/assets/sprites/monsters'/name
        text=(out/(name+'.tres')).read_text()
        assert 'CanvasTexture' not in text and 'normal_texture' not in text
        blocks=text.split('animations = [')[1].split('},\n')
        expected=sum(4 if a=='death' else 8 for a in counts)
        assert len(blocks)==expected
        for block in blocks:
            anim=re.search(r'"name": &"([^"]+)"',block)[1].rsplit('_',1)[0]
            speed=float(re.search(r'"speed": ([0-9.]+)',block)[1])
            loop=re.search(r'"loop": (true|false)',block)[1]=='true'
            assert speed==(8 if anim=='idle' else 14 if anim in ('run','leap') else 12)
            assert loop==(anim in ('idle','run','leap'))
        w,h=size
        def crop(a,f,d='s',suffix=''):
            k=2 if suffix else 1; x=f*w//k; y=DIRS.index(d)*h//k
            return Image.open(out/(a+suffix+'.png')).convert('RGBA').crop((x,y,x+w//k,y+h//k))
        idle=crop('idle',0).getchannel('A').point(lambda x:255 if x>64 else 0)
        for a in ('attack','cast'):
            if a not in counts: continue
            f=counts[a]//2
            hit=crop(a,f).getchannel('A').point(lambda x:255 if x>64 else 0)
            union=ImageChops.lighter(idle,hit)
            delta=sum(ImageChops.difference(idle,hit).getdata())/sum(union.getdata())
            assert delta>.08,(name,a,'frontal silhouette',delta)
            energies=[]
            for i in range(counts[a]):
                e=crop(a,i,suffix='_e')
                energies.append(sum(g*al for r,g,b,al in e.getdata()))
            assert energies[f]>max(energies[:f]+energies[f+1:]),(name,a,'impact emission',energies)
            print('S2 FRONTAL PASS',name,a,'delta',round(delta,3),'emission peak',f,flush=True)
        print('S2 CONTRACT PASS',name,'frames',sum(n*(4 if a=='death' else 8) for a,n in counts.items()),flush=True)


if __name__=='__main__':
    role=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'leaper'
    {'leaper':leaper,'brute':brute,'contact':contact_s2,'validate':validate_s2}[role]()
