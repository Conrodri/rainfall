"""M3A rust-city minis. Blender background only; --pack uses system Python.
Shared Ash Lord forged geometry, frost_bear CREA framing, shared cel compositor.
Resume: --only steam_hound|grinder|blind_pump --resume. No normal-map output.
"""
import sys, math, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
SRC=ROOT/'art/blender/monsters'
IDS=('steam_hound','grinder','blind_pump')
SPEC={'idle':6,'run':8,'attack':6,'cast_a':8,'cast_b':8,'phase2':8,'death':10}
DIM={'steam_hound':120,'grinder':110,'blind_pump':125}
BOTTOM={'steam_hound':140,'grinder':138,'blind_pump':140}
def dirs(a):return ('e','s','w','n') if a in ('run','attack','cast_a','cast_b') else ('s',)
def selected():return sys.argv[sys.argv.index('--only')+1].split(',') if '--only' in sys.argv else IDS

def pack():
    from PIL import Image, ImageChops
    sys.path.insert(0,str(ROOT/'art/tools/cel'));import cel_style as cel
    summary=[]
    for who in selected():
        out=ROOT/'game/assets/sprites/bosses/mini'/who
        if out.exists() and not (SRC/f'm3a_{who}.blend').exists():cel.archive_folder('bosses/mini/'+who)
        out.mkdir(parents=True,exist_ok=True)
        ext=[];subs=[];anims=[];stats=[]
        for a,n in dict(SPEC,**({'disc':8} if who=='grinder' else {})).items():
            cell=96 if a=='disc' else 170;ds=('s',) if a=='disc' else dirs(a)
            tid=str(len(ext)+1)
            ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/mini/{who}/{a}.png" id="{tid}"]')
            for suffix in ('','_e'):
                sheet=Image.new('RGBA',(n*cell,len(ds)*cell))
                for row,d in enumerate(ds):
                    for i in range(n):
                        p=SRC/f'm3a_frames/{who}/{a}/{d}_{i:02d}{suffix}.png'
                        with Image.open(p) as im:
                            im=im.convert('RGBA');assert im.size==(cell,cell)
                            if not suffix:
                                bb=im.getchannel('A').getbbox();assert bb,(who,a,d,i)
                                assert bb[0]>0 and bb[1]>0 and bb[2]<cell and bb[3]<cell,(who,a,d,i,bb)
                            sheet.paste(im,(i*cell,row*cell))
                if suffix:
                    assert max(sheet.convert('RGB').getextrema()[c][1] for c in range(3))>8
                    sys.path.insert(0,str(ROOT/'art/tools'))
                    from halve_emission import downscale
                    sheet=downscale(sheet,True)
                png=out/f'{a}{suffix}.png';sheet.save(png,optimize=True,compress_level=9)
                sys.path.insert(0,str(ROOT/'art/tools'));import texture_budget
                params=texture_budget.expected_params(png.relative_to(ROOT/'game').as_posix(),texture_budget.load_budget())
                ip=png.with_suffix('.png.import')
                if not ip.exists():ip.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'+''.join(f'{k}={texture_budget._fmt(v)}\n' for k,v in params.items()))
            for row,d in enumerate(ds):
                frames=[]
                for i in range(n):
                    sid='f'+str(len(subs));subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{tid}")\nregion = Rect2({i*cell}, {row*cell}, {cell}, {cell})\n')
                    frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
                name=a if a=='disc' else a+'_'+d
                anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(a in ('idle','run','disc')).lower()+', "name": &"'+name+'", "speed": '+str(14.0 if a in ('run','disc') else 12.0)+'}')
            cel.check_sheet(f'bosses/mini/{who}/{a}.png',cell=cell,frames=n,rows=len(ds),normals=False)
            stats.append([a,n,len(ds),cell])
        (out/f'{who}.tres').write_text('[gd_resource type="SpriteFrames" load_steps='+str(1+len(ext)+len(subs))+' format=3]\n\n'+'\n'.join(ext)+'\n\n'+'\n'.join(subs)+'\n[resource]\nanimations = ['+',\n'.join(anims)+']\n')
        summary.append({'id':who,'atlases':stats,'dim':DIM[who],'bottom':BOTTOM[who]})
    (HERE/'_m3a_verification.json').write_text(json.dumps(summary,indent=2))
    print('PASS M3A pack: '+', '.join(selected()))

def contact():
    from PIL import Image
    ground=Image.open(ROOT/'game/assets/sprites/terrain/rust_city/iso/ground_a.png').convert('RGBA')
    board=Image.new('RGBA',(1280,1260),(29,33,38,255))
    for y in range(-128,1260,128):
        for x in range(-128,1280,256):board.alpha_composite(ground,(x+(128 if (y//128)%2 else 0),y))
    for col,who in enumerate(IDS):
        for row,(a,i) in enumerate((('idle',0),('run',0),('attack',3),('cast_a',4),('cast_b',4),('phase2',7),('death',9))):
            with Image.open(ROOT/f'game/assets/sprites/bosses/mini/{who}/{a}.png') as im:
                r=1 if a in ('attack','cast_a','cast_b') else 0
                board.alpha_composite(im.crop((170*i,170*r,170*(i+1),170*(r+1))).convert('RGBA'),(35+col*235,10+row*180))
    for x,rel,c in ((760,'bosses/mini/rust_archon/idle.png',170),(975,'bosses/etage/sonneur/idle_p1.png',256)):
        p=ROOT/'game/assets/sprites'/rel
        with Image.open(p) as im:
            tile=im.crop((0,0,c,c)).convert('RGBA')
            # The legacy Archon still has oversized transparent margins. Compare
            # the declared fauna dimensions, using a shared pixel/world scale.
            tile=tile.crop(tile.getchannel('A').getbbox());dim=100 if c==170 else 190
            factor=dim/max(tile.size);tile=tile.resize(tuple(round(v*factor) for v in tile.size),Image.Resampling.LANCZOS)
            board.alpha_composite(tile,(x,320-tile.height))
    for i,rel in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png')):
        with Image.open(ROOT/rel) as im:
            tile=im.convert('RGBA');tile.thumbnail((125,120));board.alpha_composite(tile,(755+(i%2)*230,465+(i//2)*125))
    with Image.open(ROOT/'game/assets/sprites/bosses/mini/grinder/disc.png') as im:board.alpha_composite(im.crop((0,0,96,96)).convert('RGBA'),(800,345))
    board.convert('RGB').save(HERE/'_m3a_contact.png',optimize=True)
    print('PASS contact')

def verify():
    import re
    import numpy as np
    from PIL import Image
    sys.path.insert(0,str(ROOT/'art/tools/cel'));import cel_style as cel
    results=[]
    for who in IDS:
        out=ROOT/'game/assets/sprites/bosses/mini'/who
        text=(out/f'{who}.tres').read_text()
        assert 'CanvasTexture' not in text and 'normal_texture' not in text
        assert not list(out.glob('*_n.png'))
        expected={a+'_'+d for a in SPEC for d in dirs(a)}|({'disc'} if who=='grinder' else set())
        assert set(re.findall(r'"name": &"([^"]+)"',text))==expected
        measured={}
        for a,n in dict(SPEC,**({'disc':8} if who=='grinder' else {})).items():
            cell=96 if a=='disc' else 170;rows=1 if a=='disc' else len(dirs(a))
            cel.check_sheet(f'bosses/mini/{who}/{a}.png',cell=cell,frames=n,rows=rows,normals=False)
            with Image.open(out/f'{a}.png') as im:arr=np.array(im.convert('RGBA'))
            with Image.open(out/f'{a}_e.png') as im:
                assert im.size==((arr.shape[1]+1)//2,(arr.shape[0]+1)//2)
                e=np.array(im);assert (e[:,:,:3].max(2)*e[:,:,3].astype(float)/255).max()>8
            if a in ('idle','disc'):
                opaque=arr[:cell,:cell,3]>128;ys,xs=np.where(opaque)
                bb=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]
                measured[a]={'bbox':bb,'rgb_mean':arr[:cell,:cell,:3][opaque].mean(0).round(2).tolist()}
                assert abs(bb[3]-(88 if a=='disc' else BOTTOM[who]))<=3,(who,a,bb)
                if a=='idle':assert abs(max(bb[2]-bb[0],bb[3]-bb[1])-DIM[who])<=15,(who,bb)
        assert (SRC/f'm3a_{who}.blend').is_file()
        results.append({'id':who,'animations':len(expected),'normal_maps':0,'measured':measured})
    (HERE/'_m3a_verification.json').write_text(json.dumps({'result':'PASS','cell':170,'camera_ortho':4.051028251647949,'pivot':[85,119],'impact_frames':{'attack':3,'cast_a':4,'cast_b':4},'assets':results},indent=2))
    print('PASS M3A: contracts, bounds, unique frames, emission, sources, no normals')

def build():
    import bpy
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    sys.path[:0]=[str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
    from ash_lord_build import mesh,rod,shard
    from common import empty,material,cube
    import iso_rig,cel_style as cel
    from PIL import Image

    def box(name,p,sc,m,parent):return cube(name,p,sc,m,parent,bevel=.025)
    def cyl(name,p,r,depth,m,parent,axis='Z',verts=12):
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth)
        o=bpy.context.object;o.name=name;o.parent=parent;o.location=p;o.data.materials.append(m)
        if axis=='Y':o.rotation_euler.x=math.pi/2
        if axis=='X':o.rotation_euler.y=math.pi/2
        bevel=o.modifiers.new('Forged lip','BEVEL');bevel.width=.015;bevel.segments=1
        return o
    def wheel(name,p,r,parent):
        hub=empty(name,p,parent)
        cyl('Chipped grinding stone',(0,0,0),r,.11,stone,hub,'Y',24)
        cyl('Recessed bearing',(0,-.075,0),r*.35,.15,iron,hub,'Y')
        cyl('Axle cap',(0,-.16,0),r*.14,.08,brass,hub,'Y')
        for k in range(16):
            t=k*math.tau/16
            ob=box('Angled carbide tooth',(r*math.sin(t),0,r*math.cos(t)),(.045,.068,.09),edge,hub);ob.rotation_euler.y=t+.3
        for k in range(5):
            t=k*math.tau/5;rod('Wheel face scoring',[(r*.42*math.sin(t),-.063,r*.42*math.cos(t)),(r*.83*math.sin(t+.16),-.063,r*.83*math.cos(t+.16))],.012,iron,hub)
        return hub
    def pipe(name,points,r,parent,m=None):return rod(name,points,r,m or brass,parent)
    def rivets(parent,z,r,count=10):
        for k in range(count):
            t=k*math.tau/count;cyl('Rivet',(r*math.cos(t),r*math.sin(t),z),.035,.055,brass,parent)
    def leg(parent,x,y):
        pivot=empty('Articulated piston hip',(x,y,.69),parent)
        cyl('Hip bearing',(0,0,0),.13,.17,brass,pivot,'X')
        pipe('Upper ram',[(0,0,0),(.10*x,.12,-.29)],.075,pivot,iron)
        pipe('Exposed bright piston',[(.10*x,.12,-.29),(.04*x,-.02,-.59)],.043,pivot,edge)
        box('Cloven steel shoe',(.04*x,-.10,-.63),(.14,.22,.06),iron,pivot)
        pipe('Hydraulic hose',[(.12,0,.03),(.16,.18,-.22),(.08,.12,-.50)],.026,pivot,leather)
        return pivot
    def steam(parent,side):
        fx=empty('Side valve steam',(side*.69,0,1.18),parent)
        for j in range(4):
            ob=shard('Torn steam ribbon',(side*j*.16,0,.06*j),(.15+.025*j,.06,.07),steam_mat,fx)
        return fx
    def key(o,f):
        for prop in ('location','rotation_euler','scale'):o.keyframe_insert(data_path=prop,frame=f)
    def render(path):
        # Same shared cel pipeline as iso_rig, but excludes its legacy _n collector.
        cel.setup_scene();cel.toon_materials('creature');cel.cel_passes(path,'creature',normals=False)
        s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        ep=list(path.parent.glob(path.stem+'_e__*.png'));assert len(ep)==1,ep
        ep[0].replace(path.with_stem(path.stem+'_e'))
        for p in (path,path.with_stem(path.stem+'_e')):
            with Image.open(p) as im:im.convert('RGBA').resize(tuple(s['iso_frame']),Image.Resampling.LANCZOS).save(p,optimize=True,compress_level=9)

    for who in selected():
        cel.uninstall();s=iso_rig.create_rig('CREA',170)
        s.camera.data.ortho_scale=4.051028251647949;s.camera.data.shift_y=.2
        s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,0,12))
        s.render.threads_mode='FIXED';s.render.threads=8
        bpy.ops.object.light_add(type='AREA',location=(-3,-1,5))
        rim=bpy.context.object;rim.name='Cold upper left silhouette rim';rim.data.energy=320;rim.data.color=(.57,.73,1);rim.data.size=3
        rim.rotation_euler=(-rim.location).to_track_quat('-Z','Y').to_euler()
        iron=material('Raised charcoal steel 108','626970',0)
        rust=material('Dry red iron oxide','806653',0)
        brass=material('Blackened brass worn edges','99866A',0)
        edge=material('Cold steel edge','9CAFB8',0)
        stone=material('Abrasive grey stone','83817B',0)
        leather=material('Carbon bellows','5D6064',0)
        oil=material('Viscous umber oil','665B4B',0)
        steam_mat=material('Condensed white steam','A1ABB0',0)
        glow=material('Only accent steam lamp orange','FF9A3C',1.1,True)
        root=empty(who+' ground');body=empty('Suspended chassis',(0,0,0),root)
        legs=[];fx=[];moving=[];discs=[];tears=[]
        if who=='steam_hound':
            box('Ribbed long chassis',(0,.06,.88),(.42,.70,.21),iron,body)
            tank=cyl('Horizontal pressure boiler',(0,.10,1.35),.43,1.18,rust,body,'Y',16)
            for y in (-.43,.10,.64):
                cyl('Boiler retaining hoop',(0,y,1.35),.457,.065,brass,body,'Y',16)
                for x in (-.30,.30):cyl('Hoop stud',(x,y-.04,1.66),.033,.08,edge,body)
            cyl('Firebox bezel',(0,-.53,1.35),.27,.10,iron,body,'Y')
            fire=cyl('Boiler fire',(0,-.59,1.35),.21,.025,glow,body,'Y')
            for x in (-.13,0,.13):box('Fire grate',(x,-.615,1.35),(.022,.025,.205),iron,body)
            pipe('Crooked exhaust',[(.24,.48,1.62),(.24,.48,1.95),(.38,.48,2.02)],.09,body,iron)
            head=empty('Piston skull',(0,-.81,.97),body)
            box('Wedge skull',(0,-.15,.06),(.29,.35,.17),rust,head)
            jaw=empty('Guillotine jaw hinge',(0,.05,-.08),head)
            box('Lower piston jaw',(0,-.29,-.11),(.28,.38,.065),iron,jaw)
            for x in (-.23,.23):
                pipe('Jaw piston',[(x,.08,.14),(x,-.46,-.02)],.055,head,edge)
                for y in (-.17,-.38,-.53):shard('Interlocking chisel tooth',(x,y,-.02),(.045,.065,.10),brass,jaw)
            for x in (-.46,.46):
                for y in (-.48,.55):legs.append(leg(body,x,y))
                pipe('Flank safety valve',[(x,.05,1.38),(x*1.5,.05,1.38)],.07,body)
                fx.append(steam(body,1 if x>0 else -1))
            for j in range(5):
                ob=shard('Overpressure escaping rivet',(.36*math.cos(j*1.7),.2+.3*math.sin(j),1.8),(.035,.035,.04),brass,body);moving.append(ob)
        elif who=='grinder':
            for x in (-.29,.29):legs.append(leg(body,x,.10))
            box('Hunched riveted torso',(0,.10,1.15),(.38,.25,.46),rust,body)
            for z in (.88,1.12,1.37):box('Asymmetric chest lamella',(0,-.18,z),(.40,.055,.06),iron,body)
            head=empty('Blind slotted tool hood',(0,-.02,1.76),body)
            box('Narrow faceless visor',(0,-.04,0),(.20,.20,.16),iron,head)
            box('Single ventilation slit',(0,-.247,0),(.15,.018,.027),leather,head)
            pipe('Hunched neck cable',[(.18,.16,1.55),(.25,.24,1.8),(.15,.18,1.9)],.035,body)
            arm=empty('Grinding shoulder',(.40,-.02,1.42),body)
            pipe('Long grinding arm',[(0,0,0),(.16,-.28,-.30),(.03,-.62,-.48)],.09,arm,iron)
            grinder=wheel('Arm mounted meule',(.03,-.68,-.49),.39,arm)
            pipe('Counterweight arm',[(-.39,0,1.4),(-.58,-.18,1.07),(-.44,-.43,.94)],.08,body,brass)
            for j,x in enumerate((-.27,0,.27)):
                ob=wheel('Dorsal spare saw',(x,.37,1.55+(.2 if j==1 else 0)),.28,body);discs.append(ob)
            for j in range(5):
                a=j*.75;ob=shard('Grinding spark',(.55+.12*math.cos(a),-.8-.07*j,.73+.08*j),(.018,.018,.10),glow,body);fx.append(ob)
            for x in (-.57,.57):moving.append(wheel('Retractable second stage disc',(x,.26,1.42),.26,body))
        else:
            cyl('Headless pressure vessel',(0,0,1.25),.58,1.25,iron,body,verts=16)
            for z in (.69,1.48,1.85):
                cyl('Heavy riveted flange',(0,0,z),.63,.09,brass,body,verts=16);rivets(body,z+.055,.56)
            cyl('Bolted sealed lid',(0,0,1.93),.49,.10,rust,body)
            cyl('Oil inspection bezel',(0,-.58,1.36),.22,.10,brass,body,'Y')
            cyl('Hot oil sight glass',(0,-.643,1.36),.16,.02,glow,body,'Y')
            box('Oil sight cross brace',(0,-.66,1.36),(.022,.018,.17),iron,body)
            head=empty('Frontal oil nozzle',(0,-.55,.93),body)
            pipe('Hooked oil nozzle',[(0,0,0),(0,-.27,0),(0,-.38,.07)],.105,head,brass)
            cyl('Black nozzle opening',(0,-.39,.07),.071,.025,leather,head,'Y')
            for x in (-.53,.53):
                for y in (-.40,.40):legs.append(leg(body,x,y))
                bell=empty('Accordion suction bellows',(x,0,1.2),body)
                for k in range(6):cyl('Bellows pleat',(x/abs(x)*k*.055,0,0),.23 if k%2 else .26,.038,leather,bell,'X')
                moving.append(bell)
                for j in range(3):
                    strip=shard('Torn accordion membrane',(x*1.35,-.14+j*.12,1.1),(.10,.04,.24),leather,body);tears.append(strip)
            for j in range(4):
                x=(-1 if j%2 else 1)*.70;y=(-1 if j<2 else 1)*.37
                ob=empty('Ground tapping pipe',(x,y,.1),body)
                pipe('Geyser siphon',[(0,0,0),(x*.12,0,.45),(-x*.25,0,.8)],.062,ob,brass);fx.append(ob)
            oiljet=empty('Short oil pressure stream',(0,-.95,1.0),body)
            for j in range(4):shard('Heavy oil slug',(0,-j*.12,-j*j*.012),(.08,.12,.06),oil,oiljet)
            fx.append(oiljet)
        # Fit MODEL once to fauna.dim; camera/scale remain frost_bear's exact rig.
        bpy.context.view_layer.update()
        points=[o.matrix_world@Vector(v) for o in body.children_recursive if o.type=='MESH' for v in o.bound_box]
        spans=[]
        for d,angle in (('s',0),('e',math.pi/2),('w',-math.pi/2),('n',math.pi)):
            from mathutils import Matrix
            pts=[world_to_camera_view(s,s.camera,Matrix.Rotation(angle,4,'Z')@p) for p in points]
            spans.append(max(max(p.x for p in pts)-min(p.x for p in pts),max(p.y for p in pts)-min(p.y for p in pts))*170)
        modelscale=DIM[who]/max(spans);root.scale=(modelscale,)*3
        # Rig world origin remains [85,119]; feet use the declared bottom line.
        offset=(BOTTOM[who]-119)/170*4.051028251647949/math.cos(math.pi/6)
        root.location.z=-offset
        base=[(o,o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in [body,*body.children_recursive] if o.type in ('EMPTY','MESH')]
        original_sc={o:sc.copy() for o,_,_,sc in base}
        for ai,(a,n) in enumerate(SPEC.items()):
            for i in range(n):
                f=ai*20+i+1;t=i*math.tau/n;p=i/(n-1)
                hit=([0,-.22,-.6,1,.28,0][i] if a=='attack' else [0,-.1,-.3,-.55,1,.45,.15,0][i] if a in ('cast_a','cast_b') else 0)
                for o,loc,rot,sc in base:o.location=loc;o.rotation_euler=rot;o.scale=sc
                body.location.z=.016*math.sin(t) if a!='run' else .035*math.sin(t*2)
                body.rotation_euler.z=.012*math.cos(t)
                for j,o in enumerate(legs):o.rotation_euler.x=.5*math.sin(t+(j%2)*math.pi) if a=='run' else -.10*hit
                if who=='steam_hound':
                    head.rotation_euler.x=-.20*hit if a in ('attack','cast_a') else .02*math.sin(t)
                    jaw.rotation_euler.x=([.05,.25,.65,0,.1,.05][i] if a=='attack' else .03)
                    if a=='attack':body.location.y=-.23*hit
                    if a=='cast_a':
                        body.rotation_euler.x=.14*hit;body.location.y=-.32*max(hit,0)
                        for o in legs:o.rotation_euler.x=-.55*hit
                    for o in fx:o.scale=(max(.001,hit),)*3 if a=='cast_b' else (.001,)*3
                    for j,o in enumerate(moving):
                        q=max(0,p-.35) if a=='phase2' else 0;o.location.z+=q*(.12+j*.04);o.scale=original_sc[o]*(1 if q else .001)
                    if a=='phase2':fire.scale=(1+.25*p,1+.25*p,1+.25*p)
                elif who=='grinder':
                    grinder.rotation_euler.y=t*2
                    if a=='attack':
                        arm.rotation_euler.x=[0,-.25,.40,-.75,.40,0][i];arm.rotation_euler.z=[-.1,-.45,.2,.65,-.3,0][i];body.rotation_euler.z=.24*hit
                    if a=='cast_a':
                        arm.rotation_euler.z=-.65*hit
                        for j,o in enumerate(discs):o.location.y-=max(0,hit)*.42;o.location.x+=(j-1)*.20*max(0,hit);o.rotation_euler.y=t*2
                    if a=='cast_b':body.rotation_euler.z=i*math.tau/(n-1);arm.rotation_euler.z=.55*max(0,hit)
                    for j,o in enumerate(fx):o.scale=original_sc[o]*(.65+.35*math.sin(t+j))
                    for o in moving:o.scale=(max(.001,p),)*3 if a=='phase2' else (.001,)*3
                else:
                    if a=='cast_a':
                        for o in moving:o.scale.x=1-.65*max(0,hit)
                        body.scale=(1-.07*max(0,hit),1-.07*max(0,hit),1+.05*max(0,hit))
                    for j,o in enumerate(fx):
                        show=(a=='attack' and j==4) or (a=='cast_b' and j<4)
                        o.scale=(max(.001,hit),)*3 if show else (.001,)*3
                        if a=='cast_b' and j<4:o.location.z-=.09*max(hit,0)
                    if a=='phase2':
                        for j,o in enumerate(moving):o.rotation_euler.y=(1 if j else -1)*p*.6;o.scale.x=1-.5*p
                    for j,o in enumerate(tears):
                        o.scale=original_sc[o]*(max(.001,p) if a=='phase2' else .001)
                        o.rotation_euler.y=(j-2.5)*.22*p if a=='phase2' else 0
                if a=='death':body.location.z+=.50*p;body.location.x=-.75*p;body.rotation_euler.y=1.15*p
                for o,_,_,_ in base:key(o,f)
            s.timeline_markers.new(a,frame=ai*20+1)
        s.frame_end=130;s.render.fps=12
        s['animation_manifest']=json.dumps({a:{'start':ai*20+1,'frames':n,'directions':dirs(a),'loop':a in ('idle','run')} for ai,(a,n) in enumerate(SPEC.items())})
        s['m3a_contract']=json.dumps({'cell':170,'dim':DIM[who],'bottom':BOTTOM[who],'impact':{'attack':3,'cast_a':4,'cast_b':4},'normals':False})
        s.frame_set(1);cel.install('creature',normals=False)
        bpy.context.view_layer.update()
        # Evaluate authored animation before final calibration (dependency graph,
        # bevels and parent transforms can differ from the construction bounds).
        from mathutils import Matrix
        evaluated_points=[root.matrix_world.inverted()@o.matrix_world@Vector(v) for o in body.children_recursive if o.type=='MESH' and min(o.matrix_world.to_scale())>.01 for v in o.bound_box]
        spans=[]
        for angle in (0,math.pi/2,-math.pi/2,math.pi):
            root.rotation_euler.z=angle;bpy.context.view_layer.update()
            pts=[world_to_camera_view(s,s.camera,root.matrix_world@p) for p in evaluated_points]
            spans.append(max(max(p.x for p in pts)-min(p.x for p in pts),max(p.y for p in pts)-min(p.y for p in pts))*170)
        root.scale*=DIM[who]/max(spans)
        print('M3A_CALIBRATION',who,round(max(spans),2),tuple(root.scale),flush=True)
        ground_z={};center_x={}
        for d,angle in {'s':0,'e':math.pi/2,'w':-math.pi/2,'n':math.pi}.items():
            root.rotation_euler.z=angle;bpy.context.view_layer.update()
            feet=[o for legroot in legs for o in legroot.children_recursive if o.type=='MESH' and 'shoe' in o.name]
            low=max((1-world_to_camera_view(s,s.camera,o.matrix_world@Vector(v)).y)*170 for o in feet for v in o.bound_box)
            ground_z[d]=root.location.z+(low-BOTTOM[who])/170*4.051028251647949/math.cos(math.pi/6)
            px=[world_to_camera_view(s,s.camera,o.matrix_world@Vector(v)).x for o in body.children_recursive if o.type=='MESH' for v in o.bound_box]
            center_x[d]=(.5-(min(px)+max(px))/2)*4.051028251647949
        root.rotation_euler.z=0;root.location.z=ground_z['s'];root.location.x=center_x['s']
        s['ground_alignment_z']=json.dumps(ground_z)
        cel.toon_materials('creature')
        SRC.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(SRC/f'm3a_{who}.blend'))
        for ai,(a,n) in enumerate(SPEC.items()):
            if '--anim' in sys.argv and a!=sys.argv[sys.argv.index('--anim')+1]:continue
            folder=SRC/f'm3a_frames/{who}/{a}';folder.mkdir(parents=True,exist_ok=True)
            for d in dirs(a):
                for i in range(n):
                    path=folder/f'{d}_{i:02d}.png'
                    if '--resume' in sys.argv and path.exists() and path.with_stem(path.stem+'_e').exists():continue
                    s.frame_set(ai*20+i+1);root.rotation_euler.z={'s':0,'e':math.pi/2,'w':-math.pi/2,'n':math.pi}[d]
                    root.location.z=ground_z[d]
                    root.location.x=center_x[d]
                    bpy.context.view_layer.update();render(path)
            print('M3A_COMPLETE',who,a,flush=True)
        if who=='grinder':
            for o in root.children_recursive:o.hide_render=True
            iso_rig.set_frame(96,'MAP');s.camera.rotation_euler=(math.pi/3,0,math.pi/4);s.camera.data.shift_y=0
            s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,0,12))
            projectile=wheel('Bouncing toothed abrasive disc',(0,0,.42),.35,None)
            spark=shard('Steel contact spark',(.25,-.1,.25),(.015,.018,.085),glow,projectile)
            cel.toon_materials('creature')
            folder=SRC/'m3a_frames/grinder/disc';folder.mkdir(parents=True,exist_ok=True)
            # MAP 90.51 px/u, flight baseline 8 px above the cell bottom.
            bpy.context.view_layer.update()
            disc_bottom=max((1-world_to_camera_view(s,s.camera,o.matrix_world@Vector(v)).y)*96 for o in projectile.children_recursive if o.type=='MESH' for v in o.bound_box)
            s.camera.data.shift_y=(88-disc_bottom)/96
            for i in range(8):
                projectile.rotation_euler.y=i*math.tau/8;spark.scale.z=.085*(.65+.35*math.sin(i*1.7))
                bpy.context.view_layer.update();render(folder/f's_{i:02d}.png')
            bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'m3a_grinder_disc.blend'))
        print('M3A_MINI_DONE',who,flush=True)

if __name__=='__main__':
    if '--pack' in sys.argv:pack()
    elif '--contact' in sys.argv:contact()
    elif '--verify' in sys.argv:verify()
    else:build()
