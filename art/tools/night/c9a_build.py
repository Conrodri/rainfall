"""C9A / La Grue. C7c rendering pipeline, shared boss cel, contractual grids.
Run in background Blender; --only names permits resuming completed sheets.
System Python --check assembles the single contact sheet and audits output.
"""
import sys, math, json, tempfile, random, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
DST=ROOT/'game/assets/sprites/bosses/etage/crane'
sys.path[:0]=[str(ROOT/'art/tools'/p) for p in ('bosses','monsters','iso','iso/_deps','cel','')]
sys.path.append(str(Path.home()/'AppData/Local/RainfallIsoDeps'))
if '--check' in sys.argv:
    sys.path=[p for p in sys.path if not p.endswith('iso\\_deps') and not p.endswith('iso/_deps') and not p.endswith('RainfallIsoDeps')]
from PIL import Image
SPECS={**{f'{a}_p{p}':(6 if a=='idle' else 8,(256,256),4) for a in ('idle','walk') for p in (1,2,3)},
 'auto':(6,(256,256),4),'spell_a':(8,(256,256),4),'spell_b':(8,(256,256),4),
 'trans_p2':(8,(256,256),1),'trans_p3':(8,(256,256),1),'death':(10,(256,256),1),
 'container':(4,(256,256),1),'boom_shadow':(4,(896,96),1),'arc':(6,(448,64),1),'dust':(6,(192,192),1)}
EXTRAS={'container','boom_shadow','arc','dust'}

def tres():
    # No provisional files were present at initial inventory; create their documented contract.
    path=DST/'crane.tres'
    if path.exists() and all(f'id="{name}"' in path.read_text() for name in SPECS):return
    ext=[];sub=[];anims=[];k=0
    for name,(n,(w,h),rows) in SPECS.items():
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/crane/{name}.png" id="{name}"]')
        for row,d in enumerate(('e','s','w','n') if rows==4 else ('s',)):
            fs=[]
            for i in range(n):
                k+=1;sid=f'AtlasTexture_{k}'
                sub.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{name}")\nregion = Rect2({i*w}, {row*h}, {w}, {h})')
                fs.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
            an=name if name in EXTRAS else name+'_'+d
            loop=name.startswith(('idle','walk')) or name in ('boom_shadow','arc')
            anims.append('{"frames": ['+', '.join(fs)+f'], "loop": {str(loop).lower()}, "name": &"{an}", "speed": {14 if name.startswith("walk") else 12}.0'+'}')
    path.write_text(f'[gd_resource type="SpriteFrames" load_steps={len(ext)+k+1} format=3]\n\n'+'\n'.join(ext)+'\n\n'+'\n\n'.join(sub)+'\n\n[resource]\nanimations = [\n'+',\n'.join(anims)+'\n]\n',encoding='utf8')

def check():
    import numpy as np
    errors=[];stats={}
    for name,(n,(w,h),rows) in SPECS.items():
        hashes=[];means=[]
        for suffix in ('','_e'):
            p=DST/f'{name}{suffix}.png'
            if not p.exists():
                if suffix=='_e' and name=='dust':continue
                errors.append(p.name+' missing');continue
            with Image.open(p) as raw:
                im=raw.convert('RGBA');a=np.asarray(im)
                expected=(n*w,rows*h) if suffix=='' else ((n*w+1)//2,(rows*h+1)//2)
                if im.size!=expected or max(im.size)>4096:errors.append(p.name+' dimensions')
                if suffix=='_e' and not np.any(a[:,:,:3]):errors.append(p.name+' empty emission')
                if suffix=='':
                    for r in range(rows):
                        for i in range(n):
                            cell=im.crop((i*w,r*h,(i+1)*w,(r+1)*h));v=np.asarray(cell);mask=v[:,:,3]>220
                            if not mask.any():errors.append(f'{name}/{r}/{i} empty')
                            hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
                            means.append(float(v[:,:,:3][mask].mean()))
        stats[name]={'unique':len(set(hashes)),'cells':len(hashes),'mean_rgb':round(sum(means)/len(means),1)}
        if name not in EXTRAS and min(means)<90:errors.append(name+' albedo <90')
        if len(set(hashes))<len(hashes):errors.append(name+' duplicated frames')
    if list(DST.glob('*_n.png')):errors.append('forbidden normal maps')
    text=(DST/'crane.tres').read_text()
    if 'CanvasTexture' in text or 'normal_texture' in text:errors.append('forbidden texture wrapper')
    # Contact: actual biome tiled by assembly only, no painted pixels.
    ground=Image.open(ROOT/'game/assets/sprites/terrain/rust_city/iso/ground_a.png').convert('RGBA')
    board=Image.new('RGBA',(1536,1536),(30,35,38,255))
    for y in range(-256,1536,128):
        for x in range(-512,1536,512):board.alpha_composite(ground,(x+(256 if (y//128)%2 else 0),y))
    for row,d in enumerate(('e','s','w','n')):
        for col,name in enumerate(('idle_p1','idle_p2','idle_p3','auto','spell_a')):
            i=2 if name=='auto' else 3 if name=='spell_a' else 0
            im=Image.open(DST/f'{name}.png').convert('RGBA').crop((i*256,row*256,(i+1)*256,(row+1)*256))
            board.alpha_composite(im,(col*256,row*256))
        # Sonneur in its CURRENT state, same physical 3.8 u scale (existing dim ~185).
        son=Image.open(ROOT/'game/assets/sprites/bosses/etage/sonneur/idle_p1.png').convert('RGBA').crop((0,0,256,256))
        box=son.getbbox();son=son.crop(box);son.thumbnail((185,185),Image.Resampling.LANCZOS)
        board.alpha_composite(son,(1280+(256-son.width)//2,row*256+215-son.height))
    for col,(name,i,row) in enumerate((('spell_b',3,1),('trans_p2',3,0),('trans_p3',4,0),('death',4,0),('death',9,0),('container',0,0))):
        im=Image.open(DST/f'{name}.png').convert('RGBA').crop((i*256,row*256,(i+1)*256,(row+1)*256))
        board.alpha_composite(im,(col*256,1024))
    for j,name in enumerate(('arc','boom_shadow','dust')):
        w,h=SPECS[name][1];im=Image.open(DST/f'{name}.png').convert('RGBA').crop((0,0,w,h))
        im.thumbnail((480,200),Image.Resampling.LANCZOS);board.alpha_composite(im,(j*500,1280))
    # All mandatory reference boards appear on this sole inspection sheet.
    for j,p in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png','art/tools/night/_f3_contact.png')):
        im=Image.open(ROOT/p).convert('RGBA');im.thumbnail((125,80));board.alpha_composite(im,(850+j*130,1450))
    board.convert('RGB').save(HERE/'_c9a_contact.png',compress_level=9)
    report={'result':'PASS' if not errors else 'FAIL','errors':errors,'sheets':len(list(DST.glob('*.png'))),'stats':stats}
    (HERE/'_c9a_verify.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({k:v for k,v in report.items() if k!='stats'},ensure_ascii=False))
    return not errors

if '--check' in sys.argv:
    sys.exit(0 if check() else 1)

import bpy
from mathutils import Vector
import boss_common as c
import iso_rig
import cel_style as cel
from ash_lord_build import worn, mesh, plate

def mat(name,h,emit=0):
    vals=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    rgb=tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in vals)
    return c.material(name,rgb,.55,.72,emit)

def box(n,p,sz,m,par,b=.015):
    o=c.box(n,p,sz,m,par,b)
    for md in o.modifiers:
        if md.type=='BEVEL':md.segments=1
    return o

def rod(n,a,b,r,m,par):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=r,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return c.finish(o,n,m,par)

def wire(n,pts,r,m,par):
    cv=bpy.data.curves.new(n,'CURVE');cv.dimensions='3D';cv.bevel_depth=r;cv.bevel_resolution=0
    sp=cv.splines.new('POLY');sp.points.add(len(pts)-1)
    for v,pt in zip(sp.points,pts):v.co=(*pt,1)
    ob=bpy.data.objects.new(n,cv);bpy.context.collection.objects.link(ob);ob.parent=par;ob.data.materials.append(m);return ob

def show(group,on):
    for ob in group.children_recursive:
        if ob.type in ('MESH','CURVE','FONT'):ob.hide_render=not on

def compact():
    # Merge static siblings by parent; dynamic joints stay separate, 6-sided lattice rods.
    groups={}
    for ob in list(bpy.context.scene.objects):
        if ob.type in ('MESH','CURVE','FONT'):groups.setdefault(ob.parent,[]).append(ob)
    for par,obs in groups.items():
        if not obs:continue
        bpy.ops.object.select_all(action='DESELECT')
        for ob in obs:ob.select_set(True)
        bpy.context.view_layer.objects.active=obs[0]
        bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
        bpy.context.object.name=(par.name if par else 'Geometry')+' / fabricated assembly'

def setup(top=False,cell=(256,256),scale=5.15,pivot=186):
    s=iso_rig.create_rig('TOP' if top else 'CREA',cell)
    s.camera.data.ortho_scale=scale
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(pivot/cell[1]-.5)*scale*cell[1]/max(cell),0))
    # Cold upper-left rim, directional and restrained; warm studio remains the value key.
    bpy.ops.object.light_add(type='AREA',location=(-3,2,6));o=bpy.context.object;o.name='Cold rain rim upper left'
    o.data.energy=580;o.data.color=(.50,.67,.85);o.data.shape='DISK';o.data.size=3
    o.rotation_euler=(Vector((0,0,1.5))-o.location).to_track_quat('-Z','Y').to_euler()
    s.eevee.taa_render_samples=16
    s.render.image_settings.compression=65
    return s

def materials():
    return {'rust':worn('Light rust plate 9A5A3A B87A52','9A5A3A','B87A52',.55,.8),
      'steel':mat('Weathered steel 7A746C','7A746C'),'paint':mat('Faded ochre paint remnants','A9986B'),
      'dark':mat('Oily recesses only','4E514E'),'edge':mat('Cold worn edges','B2B9B6'),
      'lamp':mat('SODIUM FF9A3C unique accent','FF9A3C',2.2),'glass':mat('Smoke-stained cabin glazing','8B795F'),
      'vapor':mat('Cold escaping pressure','A2ACA8'),'concrete':mat('Fresh broken concrete','92918A')}

def lattice(parent,length,width,m):
    for x in (-width/2,width/2):
        for y in (-width/2,width/2):rod('Rolled angle chord',(x,y,0),(x,y,length),.035,m,parent)
    n=max(3,int(length/.31))
    for i in range(n):
        a=i*length/n;b=(i+1)*length/n
        for side in (-1,1):
            rod('Diagonal lattice web',(-width/2,side*width/2,a),(width/2,side*width/2,b),.019,m,parent)
            rod('Diagonal lattice web',(side*width/2,-width/2,a),(side*width/2,width/2,b),.019,m,parent)
        if i%2==0:
            rod('Transverse batten',(-width/2,-width/2,a),(width/2,-width/2,a),.025,m,parent)

def cargo(par,M,variant=0):
    rust,steel,paint,glow=M['rust'],M['steel'],M['paint'],M['lamp']
    co=c.empty('Freight container / dented serial 7'+str(variant),parent=par)
    box('Cargo shell',(0,0,.69),(1.94,1.94,1.34),rust,co,.025)
    for side in (-1,1):
        for j in range(9):
            t=(j-4)*.202
            box('Pressed corrugation',(t,side*.982,.71),(.067,.035,1.24),steel if j%4==variant else rust,co,.008)
            box('Pressed corrugation',(side*.982,t,.71),(.035,.067,1.24),rust,co,.008)
        for z in (.08,1.31):
            box('Cargo corner rail',(0,side*.98,z),(2,.055,.075),paint,co,.006)
            box('Cargo corner rail',(side*.98,0,z),(.055,2,.075),steel,co,.006)
        for x in (-.98,.98):box('Corner casting',(x,side*.98,.7),(.09,.09,1.4),steel,co,.008)
        rod('Door locking bar',(side*.31,-1.015,.18),(side*.31,-1.015,1.2),.018,paint,co)
    for j in range(8):box('Roof pressing',((j-3.5)*.23,0,1.38),(.045,1.88,.028),steel,co,.004)
    box('Corner sodium warning lamp',(-.91,-1.019,1.2),(.105,.035,.1),glow,co,.006)
    # Geometric scars vary between all four actual manufactured containers.
    rng=random.Random(140+variant)
    for j in range(11):
        x=rng.uniform(-.85,.85);z=rng.uniform(.2,1.2)
        o=box('Peeling ochre scar',(x,-1.005,z),(rng.uniform(.05,.23),.015,.025),paint,co,.001);o.rotation_euler.y=rng.uniform(-.6,.6)
    # Crushed rear roof: retain the true 2u footprint, 1.4u maximum height and
    # 90.5px/u camera while fitting the 256 cell above its visible foot at 224.
    # This is model deformation, never raster painting or image rescaling.
    bpy.context.view_layer.update()
    for ob in co.children_recursive:
        if ob.type!='MESH':continue
        transform=ob.matrix_local.copy();inv=transform.inverted()
        for v in ob.data.vertices:
            p=transform@v.co
            p.z-=max(0,(p.z-.60)/.8)*max(0,p.x+p.y)*(.18+.008*variant)
            v.co=inv@p
    return co

def build():
    s=setup();M=materials();M['cab']=M['lamp'].copy();M['cab'].name='Cab sodium / extinguishes last'
    root=c.empty('LA GRUE / storm salvage automaton / 3.8u')
    base=c.empty('Crawler undercarriage',parent=root)
    for side in (-1,1):
        track=c.empty('Riveted track', (side*.83,0,.28),base)
        box('Track carcass',(0,0,0),(.48,1.94,.45),M['steel'],track,.08)
        for j in range(14):
            y=(j-6.5)*.139
            for z in (-.23,.23):box('Worn caterpillar shoe',(0,y,z),(.53,.103,.062),M['steel'],track,.008)
        for j in range(5):
            y=(j-2)*.36;rod('Drive wheel',(side*.23,y,0),(side*.29,y,0),.17,M['dark'],track)
            rod('Wheel boss',(side*.28,y,0),(side*.32,y,0),.067,M['paint'],track)
        box('Track rust guard',(0,0,.32),(.58,1.94,.12),M['rust'],track,.02)
    box('Riveted chassis',(0,0,.63),(1.63,1.61,.3),M['rust'],base)
    rod('Slew bearing',(0,0,.72),(0,0,.89),.62,M['steel'],base)
    house=c.empty('Slewing engine and cabin',(0,0,.86),root);house.rotation_euler.z=math.pi/4
    box('Engine casing',(0,.39,.35),(1.6,1.0,.68),M['rust'],house,.04)
    box('Yellow paint surviving on engine lid',(0,.4,.705),(1.44,.87,.04),M['paint'],house)
    for j in range(7):box('Cooling louvers',((j-3)*.16,.911,.38),(.066,.033,.37),M['dark'],house,.003)
    for side in (-1,1):
        for y in (-.01,.28,.56,.84):rod('Peened rivet',(side*.81,y,.5),(side*.84,y,.5),.024,M['edge'],house)
    cabin=c.empty('Armoured sodium-lit cab',(-.49,-.40,.14),house)
    box('Cab lower armour',(0,0,.23),(.73,.83,.46),M['rust'],cabin,.025)
    box('Smoked glass volume',(0,0,.84),(.69,.77,.83),M['glass'],cabin,.025)
    for x in (-.36,.36):
        for y in (-.41,.41):rod('Cab structural mullion',(x,y,.43),(x*.91,y*.94,1.31),.035,M['steel'],cabin)
    box('Overhanging cab roof',(0,0,1.32),(.9,1.0,.10),M['rust'],cabin,.02)
    for x in (-.19,.16):box('Light through rain-streaked front glazing',(x,-.394,.87),(.25,.018,.62),M['cab'],cabin,.004)
    box('Side sodium pane',(-.358,0,.9),(.015,.61,.59),M['cab'],cabin,.005)
    rod('Cab windshield split',(0,-.42,.49),(0,-.4,1.29),.025,M['steel'],cabin)
    rod('Stalled windshield wiper',(-.25,-.438,.58),(.12,-.434,1.09),.012,M['dark'],cabin)
    box('Cab visor',(0,-.45,1.23),(.79,.17,.08),M['steel'],cabin)
    box('Door lower faded yellow',(0,-.427,.24),(.55,.02,.11),M['paint'],cabin)
    rod('Cab handrail',(-.46,-.38,.05),(-.46,-.38,.73),.022,M['edge'],cabin)
    for j in range(3):box('Boarding step',(-.50,-.44,-.09-j*.12),(.23,.28,.048),M['steel'],cabin)
    # Actual extruded stencil, after joining becomes geometry in the saved source.
    cv=bpy.data.curves.new('Foundry stencil GR 03','FONT');cv.body='GR-03';cv.size=.18;cv.extrude=.001
    ob=bpy.data.objects.new('Serial stencil GR-03',cv);bpy.context.collection.objects.link(ob);ob.parent=house
    ob.location=(.17,-.125,.30);ob.rotation_euler=(math.pi/2,0,0);cv.materials.append(M['paint'])
    mast=c.empty('Fixed lattice mast',(.36,.1,.38),house);lattice(mast,1.28,.38,M['steel'])
    box('Beacon protective cage',(.36,.1,1.70),(.30,.30,.13),M['steel'],house)
    rod('Sodium rotating beacon',(.36,.1,1.75),(.36,.1,1.93),.105,M['lamp'],house)
    boom=c.empty('Articulated lattice boom',(.36,-.07,.31),house);lattice(boom,2.03,.33,M['rust'])
    elbow=c.empty('Folding boom tip',(0,0,2.03),boom);lattice(elbow,.60,.25,M['paint'])
    rod('Boom hinge',(-.26,0,.03),(.26,0,.03),.14,M['steel'],boom)
    # Thin parallel hoist cables read as tension lines against the open truss.
    for x in (-.11,.11):rod('Hoist tension rope',(x,.11,.03),(x,.11,2.58),.012,M['dark'],boom)
    cable=c.empty('Suspended hook cable',parent=house)
    rod('Suspension cable',(0,0,0),(0,0,-1),.018,M['steel'],cable)
    hook=c.empty('Forged hook',(0,0,-1),cable)
    box('Hook pulley block',(0,0,.05),(.18,.13,.23),M['steel'],hook)
    wire('Swan-neck forged hook',[(0,0,-.04),(.04,0,-.22),(.15,0,-.32),(.26,0,-.28),(.27,0,-.15)],.045,M['steel'],hook)
    latch=c.empty('Hook safety tongue pivot',parent=hook)
    rod('Opening hook safety tongue',(.03,-.015,-.12),(.25,-.015,-.15),.014,M['paint'],latch)
    weight=c.empty('Split rear counterweight',(0,.88,.36),house)
    for side in (-1,1):
        o=box('Fractured cast counterweight',(side*.34,0,0),(.65,.44,.70),M['rust'],weight,.025)
        o.rotation_euler.y=side*.05
        for j in range(3):box('Cast counterweight rib',(side*.34,.232,(j-1)*.18),(.61,.035,.04),M['steel'],weight,.004)
    steam=c.empty('Counterweight escaping steam',(0,.95,.64),house)
    for j in range(6):
        pts=[(.04*math.sin(k+j),.04*math.cos(k+j),k*.14) for k in range(6)]
        wire('Pressure plume',pts,.022+j*.003,M['vapor'],steam)
    anchors=c.empty('Four concrete-piercing stabilisers',parent=root)
    for x in (-1,1):
        for y in (-1,1):
            rod('Diagonal stabiliser piston',(x*.68,y*.64,.62),(x*1.24,y*.98,.19),.075,M['steel'],anchors)
            box('Planted anchor shoe',(x*1.23,y*.98,.08),(.40,.36,.14),M['steel'],anchors)
            for j in range(3):
                ob=box('Broken concrete',(x*(1.2+j*.12),y*(1.03+j*.06),.045),(.11,.15,.09),M['concrete'],anchors);ob.rotation_euler.z=j*1.1
    arcs=c.empty('Amber lattice induction',parent=boom)
    for j in range(3):wire('Storm conduction',[(.21+(-1)**k*.055,-.21,k*.25) for k in range(j,11)],.015,M['lamp'],arcs)
    carried=c.empty('Released cargo',parent=root);cargo(carried,M)
    compact()
    cab_slots=[(o,j) for o in root.children_recursive if o.type=='MESH' for j,m in enumerate(o.data.materials) if m==M['cab']]
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def pose(name,i,n):
        for o,(loc,rot,sc) in rest.items():o.location=loc;o.rotation_euler=rot;o.scale=sc;o.hide_render=False
        for ob,j in cab_slots:ob.data.materials[j]=M['glass'] if name=='death' and i>=8 else M['cab']
        t=i/n;wave=math.sin(t*math.tau);q=i/max(1,n-1)
        phase=3 if name.endswith('p3') else 2 if name.endswith('p2') else 1
        if name=='trans_p2':phase=2 if i>=3 else 1
        if name=='trans_p3':phase=3 if i>=3 else 2
        angle=.99 if phase<3 else .13
        if name=='trans_p3':angle=.99-.86*min(1,i/4)
        boom.rotation_euler.x=angle+.025*wave
        if phase==3:
            # Telescoping lattice settles into its locking collar when grounded.
            boom.scale.z=.72;house.location.z-=.12
        house.rotation_euler.z+=.025*wave+.018*math.cos(t*math.tau)
        if name.startswith('walk'):
            house.location.z+=.018*math.cos(t*math.tau*2)
            house.rotation_euler.z+=.16*wave if phase==3 else .025*wave
        show(anchors,phase==3);show(steam,phase>=2);show(arcs,phase==3)
        steam.scale=(1+.2*wave,1+.2*wave,.55+.45*(.5+.5*math.sin(t*math.tau+1)))
        arcs.scale.x=1+.17*math.sin(i*2.1)
        weight.rotation_euler.y=.07 if phase>=2 else 0
        show(carried,False)
        if name in ('auto','spell_a','spell_b'):
            impact=2 if name=='auto' else 3
            attack=max(0,1-abs(i-impact)/(impact+1))
            if name=='auto':boom.rotation_euler.x=.99+.34*attack;elbow.rotation_euler.x=-.26*attack
            if name=='spell_a':
                boom.rotation_euler.x=.99-.82*attack
                show(carried,1<=i<=4);carried.scale=(.40,.40,.40)
                carried.location=(.60,-1.12,1.2*(1-attack))
                latch.rotation_euler.y=-attack*1.5
            if name=='spell_b':
                boom.rotation_euler.x=1.25+.12*attack
                house.rotation_euler.z+=(-.45 if i<3 else -.45+(i-3)*.32)
        if name=='death':
            boom.rotation_euler.x=.99+.60*q;boom.scale.z=1-.25*q;elbow.rotation_euler.x=1.7*q*q
            house.rotation_euler.y=-.30*q;house.location.z-=.32*q
            show(arcs,False);show(steam,i<7)
        # Cab and beacon emission are real shader strengths, isolated by CEL_Accent.
        for key,off in (('lamp',5),('cab',8)):
            strength=(2.2 if phase==1 else 3.4)*(0 if name=='death' and i>=off else 1)
            lamp=M[key];lamp['c9a_strength']=strength
            node=lamp.node_tree.nodes.get('Principled BSDF')
            if node:node.inputs['Emission Strength'].default_value=strength
            for nd in lamp.node_tree.nodes:
                if nd.type=='EMISSION':nd.inputs['Strength'].default_value=strength
                if nd.type=='OUTPUT_AOV':nd.inputs['Color'].default_value=tuple(v*strength for v in lamp.diffuse_color[:3])+(1,)
        bpy.context.view_layer.update()
        tip=boom.matrix_local@elbow.matrix_local@Vector((0,0,.60))
        cable.location=tip;cable.scale.z=.92+.07*wave
        cable.rotation_euler.y=.12*wave
        cable.rotation_euler.x=.045*math.cos(t*math.tau)
        if name=='auto':cable.rotation_euler.x=-.62*attack
        if name=='death':cable.scale.z=.92*(1-q)+.10*q
    return root,pose

def extra(name):
    n,cell,_=SPECS[name];top=name!='container'
    scale=max(cell)/64 if top else 256/90.5
    s=setup(top,cell,scale,cell[1]/2 if top else 160)
    if top and name in ('arc','boom_shadow'):
        s.camera.location.x=scale/2
    M=materials();root=c.empty('C9A '+name)
    if name=='container':
        variants=[cargo(root,M,i) for i in range(4)];root.rotation_euler.z=math.pi/4
        def pose(i):
            for j,ob in enumerate(variants):show(ob,j==i)
    elif name=='boom_shadow':
        for side in (-1,1):rod('Projected long truss chord',(0,side*.34,.01),(13.8,side*.15,.01),.045,M['dark'],root)
        for j in range(25):
            rod('Projected truss diagonal',(j*.55,-.34,.015),((j+1)*.55,.34,.015),.031,M['dark'],root)
        lamp=c.empty('Moving tip lamp',(13.8,0,.025),root)
        box('Tip lamp',(0,0,0),(.15,.15,.04),M['lamp'],lamp)
        def pose(i):lamp.location.y=.10*math.sin(i*math.pi/2)+.025*math.cos(i*math.pi/2)
    elif name=='arc':
        variants=[]
        for j in range(6):
            par=c.empty('Arc flicker '+str(j),parent=root);variants.append(par)
            rng=random.Random(80+j);pts=[(0,0,.02)]+[(k*.34,rng.uniform(-.28,.28),.02) for k in range(1,20)]+[(6.97,0,.02)]
            wire('Amber electrical channel',pts,.028,M['lamp'],par)
            for k in (4,10,16):wire('Fork discharge',[pts[k],(pts[k][0]+.12,pts[k][1]+.19,.02),(pts[k][0]+.33,pts[k][1]+.29,.02)],.014,M['lamp'],par)
        def pose(i):
            for j,ob in enumerate(variants):show(ob,j==i)
    else:
        debris=[];rng=random.Random(912)
        for j in range(48):
            a=j*math.tau/48;radius=rng.uniform(.78,1.24)
            ob=box('Concrete grit',(radius*math.cos(a),radius*math.sin(a),.025),(rng.uniform(.035,.13),rng.uniform(.04,.10),.04),M['concrete'] if j%3 else M['vapor'],root,.005)
            ob.rotation_euler.z=a;debris.append((ob,ob.location.copy()))
        def pose(i):
            for j,(ob,p) in enumerate(debris):
                ob.location=p*(.45+i*.105);ob.scale=(1-i*.12,)*3;ob.hide_render=i>=4 and j%3==0
    if name!='dust':compact()
    return root,pose

def render_frame(path):
    # C7c pass assembly, adapted locally to the no-normal-map contract.
    s=bpy.context.scene
    c.configure_passes(path)
    s.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    emission=list(path.parent.glob(path.stem+'_e__*.png'))
    if len(emission)!=1:raise RuntimeError('Missing emission pass')
    emission[0].replace(path.with_name(path.stem+'_e.png'))
    for suffix in ('','_e'):
        f=path.with_name(path.stem+suffix+'.png')
        with Image.open(f) as raw:im=raw.convert('RGBA').resize(tuple(s['iso_frame']),Image.Resampling.LANCZOS)
        im.save(f,compress_level=3)

def render():
    DST.mkdir(parents=True,exist_ok=True)
    names=list(SPECS)
    if '--only' in sys.argv:names=sys.argv[sys.argv.index('--only')+1].split(',')
    with tempfile.TemporaryDirectory(prefix='rainfall_c9a_') as td:
        td=Path(td);root,pose=build();pose('idle_p1',0,6)
        if '--diagnose' in sys.argv:
            from bpy_extras.object_utils import world_to_camera_view
            for d in ('e','s','w','n'):
                root.rotation_euler.z=c.DIRECTIONS[d];pose('idle_p1',0,6);bpy.context.view_layer.update()
                bounds=[]
                for o in root.children_recursive:
                    if o.type=='MESH' and not o.hide_render:
                        pts=[world_to_camera_view(bpy.context.scene,bpy.context.scene.camera,o.matrix_world@Vector(v)) for v in o.bound_box]
                        bounds.append((round(max(p.y for p in pts),3),o.name))
                print('C9A DIAG',d,sorted(bounds,reverse=True)[:4],flush=True)
            return
        s=bpy.context.scene;s['C9A_contract']='256px; bottom215; dim195; e,s,w,n; sodium FF9A3C'
        # Fully editable hierarchical source with a named action for every body timeline.
        frame=1
        for name,(n,cell,rows) in SPECS.items():
            if name in EXTRAS:continue
            start=frame
            for i in range(n):
                pose(name,i,n)
                for o in root.children_recursive:
                    if o.type=='EMPTY':
                        for prop in ('location','rotation_euler','scale'):o.keyframe_insert(prop,frame=frame+i)
                for o in root.children_recursive:
                    if o.type=='MESH':o.keyframe_insert('hide_render',frame=frame+i)
            s.timeline_markers.new(name,frame=start);frame+=n+2
        s.frame_end=frame;s.render.fps=12;s.frame_set(1)
        # Runtime posing must not be overridden by the source timeline keys.
        source=ROOT/'art/blender/bosses/crane_iso.blend';source.parent.mkdir(parents=True,exist_ok=True)
        pose('idle_p1',0,6);cel.install('boss', normals=False);cel.toon_materials('boss')
        s.render.image_settings.compression=100
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        for o in root.children_recursive:o.animation_data_clear()
        cel.install('boss', normals=False)
        for name in names:
            n,cell,rows=SPECS[name]
            if name in EXTRAS:
                root,epose=extra(name);cel.install('boss', normals=False)
            s=bpy.context.scene;s.render.resolution_x=cell[0]*2;s.render.resolution_y=cell[1]*2
            if name in ('auto','spell_a','spell_b'):
                # One framing for the entire gesture: no cropped hook or rotating lattice.
                import numpy as np
                max_width=max_height=max_x=0.
                for direction in ('e','s','w','n'):
                    for index in range(n):
                        pose(name,index,n);root.rotation_euler.z=c.DIRECTIONS[direction]
                        bpy.context.view_layer.update();points=[]
                        inv=s.camera.matrix_world.inverted()
                        for ob in root.children_recursive:
                            if ob.type!='MESH' or ob.hide_render:continue
                            vertices=np.empty(len(ob.data.vertices)*3);ob.data.vertices.foreach_get('co',vertices)
                            matrix=np.array(inv@ob.matrix_world)
                            points.append(vertices.reshape(-1,3)@matrix[:3,:3].T+matrix[:3,3])
                        points=np.concatenate(points)
                        max_width=max(max_width,float(np.ptp(points[:,0])))
                        max_height=max(max_height,float(np.ptp(points[:,1])))
                        max_x=max(max_x,float(np.abs(points[:,0]).max()))
                s.camera.data.ortho_scale=max(5.15,max_width*256/200,max_height*256/200,max_x*256/119)
                print('C9A FRAMING',name,round(s.camera.data.ortho_scale,3),flush=True)

            boards=[Image.new('RGBA',(cell[0]*n,cell[1]*rows),(0,0,0,0)) for _ in range(2)]
            for row,d in enumerate(('e','s','w','n') if rows==4 else ('s',)):
                for i in range(n):
                    if name in EXTRAS:
                        epose(i)
                    else:
                        pose(name,i,n);root.rotation_euler.z=c.DIRECTIONS[d]
                    bpy.context.view_layer.update()
                    if name not in EXTRAS:
                        # Use actual crawler / planted pad vertices for the invariant footline.
                        from bpy_extras.object_utils import world_to_camera_view
                        foot=[o for o in root.children_recursive if o.type=='MESH' and not o.hide_render and
                              ('Riveted track' in o.name or 'Crawler undercarriage /' in o.name or 'Four concrete-piercing' in o.name)]
                        low=min(world_to_camera_view(s,s.camera,o.matrix_world@v.co).y for o in foot for v in o.data.vertices)
                        delta=(215/256-(1-low))*s.camera.data.ortho_scale
                        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,delta,0))
                        bpy.context.view_layer.update()
                    p=td/'frame.png';render_frame(p)
                    for j,suffix in enumerate(('','_e')):
                        im=Image.open(p.with_name('frame'+suffix+'.png')).convert('RGBA')
                        boards[j].paste(im,(i*cell[0],row*cell[1]))
            for j,suffix in enumerate(('','_e')):
                out=DST/f'{name}{suffix}.png';board=boards[j]
                if suffix=='_e':
                    import numpy as np
                    if not np.asarray(board)[:,:,:3].any():
                        out.unlink(missing_ok=True);continue
                    from halve_emission import downscale
                    board=downscale(board)
                board.save(out,compress_level=9)
            print('C9A DONE '+name,flush=True)
        tres()
    print('C9A RENDER PASS',flush=True)

if __name__=='__main__':render()
