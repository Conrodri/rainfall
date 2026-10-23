"""F2P forest props: MAP 90.51px/u, original frames, TOP shadow decals.
Reuse F2 organic meshes, Ash Lord worn PBR and C0 render/pass pipeline.
Blender: --background --python this.py [-- --only NAME]. Python: --verify.
"""
from pathlib import Path
import sys, math, json, random, hashlib
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'game/assets/sprites/props/fog_forest'
SRC=ROOT/'art/blender/props'
SPECS={'cedar_giant':(384,340),'lantern_shrine':(192,158),'lantern_shrine_se':(192,158),'lantern_shrine_sw':(192,158),**{f'root_arch_{k}':(256,224) for k in ('a','b','c')},'root_arch_corner':(256,212),'mushrooms':(128,94),'standing_stone':(192,166),'stump':(128,94)}

def verify():
    from PIL import Image
    errors=[]
    for name,(sz,fy) in SPECS.items():
        for suff in ('','_n','_shadow')+(('_e',) if 'shrine' in name else ()):
            p=OUT/(name+suff+'.png')
            if not p.exists():errors.append('missing '+p.name);continue
            im=Image.open(p).convert('RGBA');expect=(512,512) if suff=='_shadow' else (sz,sz)
            if im.size!=expect:errors.append('size '+p.name)
            bbox=im.getchannel('A').point(lambda a:255 if a>24 else 0).getbbox()
            if not bbox or min(bbox[0],bbox[1],im.width-bbox[2],im.height-bbox[3])<3:errors.append('clipped/empty '+p.name)
            if suff=='_e' and max(c.getextrema()[1] for c in im.split()[:3])<30:errors.append('empty emission')
        meta=json.loads((SRC/('f2p_'+name+'_check.json')).read_text())
        if max(meta['footprint'])>1.501:errors.append('footprint '+name)
        if abs(meta['foot'][0]-sz/2)>.05 or abs(meta['foot'][1]-fy)>.05:errors.append('pivot '+name)
    manifest=json.loads((OUT/'props.json').read_text())
    if len(manifest['props'])!=6:errors.append('manifest')
    # One contact board, all props in context + validated visual references.
    board=Image.new('RGBA',(1536,1536),(21,27,28,255))
    tile=Image.open(ROOT/'game/assets/sprites/terrain/fog_forest/iso/ground_a.png').convert('RGBA')
    ard=Image.open(ROOT/'game/assets/sprites/characters/ardent/idle.png').convert('RGBA').crop((0,192,192,384))
    for idx,(name,(sz,fy)) in enumerate(SPECS.items()):
        panel=Image.new('RGBA',(384,400),(21,27,28,255));cx,cy=192,325
        # Four metre F2 ground tile at its native MAP pixel density, as are props/Ardent.
        panel.alpha_composite(tile,(cx-256,cy-128))
        im=Image.open(OUT/(name+'.png')).convert('RGBA')
        panel.alpha_composite(im,(cx-sz//2,cy-fy))
        panel.alpha_composite(ard,(cx-173,cy+36-round(192*.62)))
        sh=Image.open(OUT/(name+'_shadow.png')).convert('RGBA');sh.thumbnail((90,90))
        panel.alpha_composite(sh,(284,302))
        board.alpha_composite(panel,((idx%4)*384,(idx//4)*400))
    for i,ref in enumerate(('iso/_c4_contact.png','characters/_m2_contact.png','iso/_c1_contact.png')):
        im=Image.open(ROOT/'art/tools'/ref).convert('RGBA');im.thumbnail((490,320))
        board.alpha_composite(im,(i*512+(512-im.width)//2,1208))
    board.convert('RGB').save(HERE/'_f2p_contact.png',optimize=True)
    print('F2P '+('FAIL '+str(errors[:12]) if errors else 'PASS: 11 props; MAP pivots; footprint <=1.5u; TOP shadows; normal/emission; manifest'))
    return not errors

if __name__=='__main__' and '--verify' in sys.argv:sys.exit(0 if verify() else 1)

sys.path.insert(0,str(HERE))
from f2_build import materials, pebble, root_curve, trunk, worn, mesh
import bpy
from mathutils import Vector
import iso_rig as rig
C=rig.common
from bpy_extras.object_utils import world_to_camera_view

def box(n,loc,dim,mat,root,bevel=.012):return C.box(n,loc,dim,mat,root,bevel)
def tube(n,pts,r,mat,root):return root_curve(pts,r,mat,root,n)
def moss(root,m,seed=1):
    rng=random.Random(seed)
    for i in range(15):
        x,y=rng.uniform(-.5,.5),rng.uniform(-.36,.36)
        pebble('Clinging wet moss',(x,y,.035),(.12,.085,.035),m['moss'],root,i)

def stump(root,m):
    trunk(0,0,0,.35,.57,root,m,21)
    for i in range(10):
        a=i*math.tau/10;r=.30
        tube('Split silvered heartwood',[(r*math.cos(a),r*math.sin(a),.55),(.32*math.cos(a),.32*math.sin(a),.68+(.09 if i%3==0 else 0))],.024,m['wood'],root)
    moss(root,m)
    for j in range(3): fungus(root,m,(.28,-.13+j*.10,.28+j*.1),.15,j)

def fungus(root,m,p,s,seed):
    rng=random.Random(seed);x,y,z=p
    tube('Bent ivory stalk',[(x,y,z),(x+.025,y,.24*s+z),(x-.04*s,y,.46*s+z)],.035*s,m['bone'],root)
    N=24;verts=[]
    # Sculpted, thin, fluted bell caps; no sphere caps.
    for k,(rr,h) in enumerate(((0,.78),(.28,.74),(.57,.6),(1,.39),(.86,.37))):
        for j in range(N):
            a=j*math.tau/N;r=s*.32*rr*(1+.055*math.sin(a*7+seed))
            verts.append((x-.04*s+r*math.cos(a),y+r*math.sin(a),z+s*h+.018*s*math.sin(a*5+seed)))
    faces=[tuple(range(N-1,-1,-1))]+[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(4) for j in range(N)]
    ob=mesh('Torn oyster bell',verts,faces,m['cap'],root)
    for f in ob.data.polygons:f.use_smooth=True
    for j in range(12):
        a=j*math.tau/12
        tube('Radial exposed gills',[(x-.04*s+math.cos(a)*s*.07,y+math.sin(a)*s*.07,z+s*.47),(x-.04*s+math.cos(a)*s*.27,y+math.sin(a)*s*.27,z+s*.38)],.006*s,m['bone'],root)

def mushrooms(root,m):
    moss(root,m,4)
    for j,(x,y,s) in enumerate(((-.18,.12,.88),(.23,.18,.65),(0,-.10,1.1),(-.38,-.16,.46),(.37,-.24,.44),(.10,-.36,.40))):fungus(root,m,(x,y,.03),s,j)
    for i in range(5):tube('Fallen cedar needles',[(-.48+i*.19,-.23,.025),(-.35+i*.19,.18,.035)],.007,m['wood'],root)

def cedar(root,m):
    trunk(0,0,0,.30,2.30,root,m,17)
    tube('Lightning split upper trunk',[(0,0,1.9),(.07,.03,2.55),(-.10,.04,3.15),(-.02,.02,3.62)],.12,m['bark'],root)
    rng=random.Random(42)
    # Layered cedar sprays taper up; broken, drooping, visibly individual needles.
    for level in range(7):
        z=1.30+level*.31;reach=.95-level*.09
        for j in range(5):
            a=j*math.tau/5+level*1.43
            tip=(math.cos(a)*reach,math.sin(a)*reach,z+.08)
            tube('Gnarled sweeping cedar bough',[(0,0,z),(.42*tip[0],.42*tip[1],z-.08),tip],.047*(1-level*.075),m['bark'],root)
            verts=[];faces=[]
            for k in range(11):
                t=.25+k*.066
                for side in (-1,1):
                    px=tip[0]*t;py=tip[1]*t
                    span=(.22*(1-t)+.075)*side
                    q=(px-math.sin(a)*span,py+math.cos(a)*span,z+.08*t-.045)
                    tube('Flat drooping spray',[(px,py,z+.08*t-.05),q],.009,m['needles'],root)
                    for leaf in range(7):
                        u=leaf/7;xx=px+(q[0]-px)*u;yy=py+(q[1]-py)*u;zz=q[2]-.035*u
                        base=len(verts);w=.024;length=rng.uniform(.08,.15)
                        verts.extend([(xx-math.sin(a)*w,yy+math.cos(a)*w,zz),(xx+math.sin(a)*w,yy-math.cos(a)*w,zz),(xx+math.cos(a)*length,yy+math.sin(a)*length,zz-.035)])
                        faces.append((base,base+1,base+2))
            mesh('Individually serrated cedar needles',verts,faces,m['needles'],root)
    moss(root,m,5)
    for j in range(4):fungus(root,m,(.23,-.11+j*.08,.45+j*.13),.22,j)
    # Long fungal beards in sober grey green, not emissive.
    for j in range(9):
        a=j*2.4;x=.62*math.cos(a);y=.62*math.sin(a);z=1.6+(j%4)*.34
        tube('Hanging lichen beard',[(x,y,z),(x+.025,y-.02,z-.15),(x-.03,y,z-.30)],.012,m['lichen'],root)

def arch(root,m,kind):
    paths={'a':[(-.59,0,.02),(-.52,.02,.78),(-.28,.01,1.60),(.19,0,1.84),(.54,0,1.28),(.61,0,.025)],'b':[(-.62,0,.025),(-.48,0,.82),(-.13,.03,1.42),(.40,.04,1.60),(.61,0,1.18)],'c':[(-.60,0,.025),(-.53,0,.57),(-.29,.04,1.08),(.13,0,1.29),(.62,0,1.34)],'corner':[(-.59,0,.025),(-.49,0,.87),(-.23,.03,1.51),(.31,.04,1.68),(.40,-.32,.92),(.37,-.59,.025)]}
    p=paths[kind]
    for j in range(6):
        pts=[(x+(j-2.5)*.021,y+math.sin(k*1.1+j)*.085,z+math.cos(k+j)*.04) for k,(x,y,z) in enumerate(p)]
        tube('Interwoven exposed root tendon',pts,.052,m['bark'] if j%3 else m['wood'],root)
    for j in range(9):
        t=j/8;x=-.55+t*1.1;z=(1.74 if kind in ('a','corner') else 1.35)-((t-.5)**2)*3
        tube('Dead thorn splinter',[(x,.06,z),(x-.07,.09,z+.16)],.012,m['wood'],root)
    moss(root,m,8)
    for j in range(4):fungus(root,m,(-.46,.0,.40+j*.17),.20,j)
    for j in range(5):
        x=-.30+j*.13
        tube('Dangling root fibres',[(x,.02,1.48),(x+.025,.015,1.24),(x-.025,.0,1.10)],.009,m['lichen'],root)

def stone(root,m):
    verts=[];N=7
    for z,rad in ((0,.40),(.17,.38),(1.24,.27),(1.66,.18)):
        for j in range(N):
            a=math.tau*j/N;verts.append((math.cos(a)*rad+.08*z,math.sin(a)*rad,z+(.07*math.sin(j*2) if z>1 else 0)))
    faces=[tuple(range(N-1,-1,-1)),tuple(range(3*N,4*N))]+[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(3) for j in range(N)]
    mesh('Tilted split funerary menhir',verts,faces,m['rock'],root,.013)
    # Inlaid old bronze broken sigil, deliberately unlit.
    for i in range(3):
        z=.61+i*.23
        tube('Oxidised burial ligature',[(-.12,-.30+i*.019,z),(.02,-.31+i*.019,z+.06),(.13,-.27+i*.019,z+.03)],.018,m['bronze'],root)
    for i in range(6):
        tube('Mineral streak',[(.20+i*.025,-.17,1.34-i*.08),(.19+i*.025,-.20,.64-i*.055)],.008,m['lichen'],root)
    moss(root,m,2)

def shrine(root,m):
    for z,w,h in ((.07,.84,.14),(.20,.68,.12)):
        box('Chipped wet shrine plinth',(0,0,z),(w,w,h),m['rock'],root,.025)
    # Four dark ribs, asymmetric votive door, corroded pitched bronze roof.
    for x in (-.24,.24):
        for y in (-.24,.24):
            box('Eroded iron cage upright',(x,y,.76),(.045,.045,.99),m['iron'],root,.008)
            for z in (.32,1.16):pebble('Copper rivet',(x,y-.026,z),(.034,.025,.034),m['bronze'],root,3)
    for z in (.36,1.04,1.20):box('Cast bronze cage band',(0,0,z),(.57,.57,.055),m['bronze'],root)
    for x in (-.13,0,.13):box('Votive front grille',(x,-.275,.74),(.022,.027,.67),m['iron'],root,.004)
    pebble('Single pale green captive ember',(0,0,.77),(.095,.085,.23),m['glow'],root,10)
    for z in (.54,.97):box('Hammered candle cup',(0,0,z),(.24,.21,.035),m['bronze'],root)
    # Sharp hipped roof, flared eaves, no stylised pagoda curl.
    v=[(-.43,-.43,1.23),(.43,-.43,1.23),(.43,.43,1.23),(-.43,.43,1.23),(-.11,0,1.58),(.11,0,1.58)]
    mesh('Patinated pitched shrine roof',v,[(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4),(3,2,1,0)],m['bronze'],root,.012)
    for t in (-.27,-.09,.09,.27):
        tube('Raised roof seam',[(t,-.42,1.245),(t*.22,0,1.59),(t,.42,1.245)],.012,m['iron'],root)
    box('Front worn prayer tablet',(.16,-.34,.28),(.24,.09,.055),m['wood'],root)
    for z in (.61,.84):C.ring('Door hinge',(-.25,-.30,z),.037,.009,m['bronze'],root)
    moss(root,m,6)

def build():
    OUT.mkdir(parents=True,exist_ok=True);SRC.mkdir(parents=True,exist_ok=True)
    only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else None
    for name,(sz,fy) in SPECS.items():
        if only and name!=only:continue
        s=rig.create_rig('MAP',(sz,sz));s.eevee.taa_render_samples=16
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(fy-sz/2)/rig.R,0))
        # Higher key retains DA upper-left direction and fits tall cedar's TOP decal.
        sun=bpy.data.objects['Sun_chaud_haut_gauche'];sun.location=s.camera.rotation_euler.to_matrix()@Vector((-4,9,8));sun.rotation_euler=(-sun.location).to_track_quat('-Z','Y').to_euler()
        root=C.empty(name);m=materials()
        m['bone']=worn('Damp fungal ivory','625E4D','A29B7E',0,.72)
        m['cap']=worn('Smoky oyster caps','302F28','736E56',0,.62)
        m['lichen']=worn('Pallid hanging lichen','424D42','798572',0,.86)
        m['bronze']=worn('Pitted verdigris bronze','303D37','789B81',.62,.55)
        if name=='cedar_giant':cedar(root,m)
        elif name=='stump':stump(root,m)
        elif name=='mushrooms':mushrooms(root,m)
        elif name=='standing_stone':stone(root,m)
        elif name.startswith('root_arch'):arch(root,m,name.removeprefix('root_arch_'))
        else:
            shrine(root,m)
            root.rotation_euler.z=math.pi/2 if name.endswith('_se') or name=='lantern_shrine' else 0
        rig.bake_ao_shadows(root);bpy.context.view_layer.update()
        points=[o.matrix_world@v.co for o in root.children_recursive if o.type=='MESH' for v in o.data.vertices]
        ground=[p for p in points if p.z<.16]
        q=world_to_camera_view(s,s.camera,Vector((0,0,0)))
        check={'name':name,'foot':[round(q.x*sz,4),round((1-q.y)*sz,4)],'px_per_u':rig.R,'footprint':[round(max(p[i] for p in ground)-min(p[i] for p in ground),4) for i in (0,1)],'rig':'MAP','yaw':45,'elevation':30,'shadow_rig':'TOP','shadow_px_per_u':128}
        (SRC/('f2p_'+name+'_check.json')).write_text(json.dumps(check,indent=2))
        rig.render_frame(OUT/(name+'.png'))
        if 'shrine' not in name:(OUT/(name+'_e.png')).unlink(missing_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('f2p_'+name+'.blend')))
        rot=sun.rotation_euler.copy()
        rig.create_rig('TOP',(512,512),reset=False);sun.rotation_euler=rot
        rig.render_shadow_decal(root,OUT/(name+'_shadow.png'))
        print('F2P DONE '+name,flush=True)
    if not only or all((OUT/(n+'_shadow.png')).exists() for n in SPECS):
        props=[]
        for n,w in [('stump',4),('mushrooms',5),('standing_stone',2),('root_arch_a',2),('lantern_shrine_se',1),('cedar_giant',1)]:
            sz,fy=SPECS[n];props.append(dict(name=n,weight=w,foot=[sz//2,fy],px_per_u=90.51,fade=n=='cedar_giant',shadow_rig='top'))
        (OUT/'props.json').write_text(json.dumps(dict(density=.05,props=props),indent=2)+'\n')
    print('F2P BUILD COMPLETE',flush=True)

if __name__=='__main__':build()
