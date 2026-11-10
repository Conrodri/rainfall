"""Grésille lot B. Blender background rendering; --pack with system Python."""
from pathlib import Path
import sys, math, random, json, warnings
warnings.filterwarnings('ignore', category=DeprecationWarning)
ROOT = Path('C:/Users/const/Documents/Rainfall/.claude/worktrees/agent-a989f232cfdebff08')
WORK = ROOT/'art/renders/gresille_vfx'
VFX = ROOT/'game/assets/sprites/vfx/gresille'
ICONS = ROOT/'game/assets/sprites/icons/spells'
NAMES = ['gresille_arc','gresille_decharge','gresille_terre','gresille_orage']
TAU = math.tau

def render():
    import bpy
    from mathutils import Vector
    sys.path[:0] = [str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/night')]
    import cel_style as cel
    WORK.mkdir(parents=True,exist_ok=True)
    def material(name, rgb):
        m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
        n=m.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission')
        # Convert the specified sRGB palette to linear emission.
        e.inputs[0].default_value=(*[((c+.055)/1.055)**2.4 if c>.04045 else c/12.92 for c in rgb],1)
        m.node_tree.links.new(e.outputs[0],o.inputs[0]);m['cel_done']=True
        return m
    def mesh(name,pts,mat):
        d=bpy.data.meshes.new(name);d.from_pydata(pts,[],[tuple(range(len(pts)))]);d.materials.append(mat)
        ob=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(ob);return ob
    def stroke(pts,width,mat,z=.04):
        d=bpy.data.curves.new('angular filament','CURVE');d.dimensions='3D';d.resolution_u=1;d.bevel_depth=width;d.bevel_resolution=0;d.resolution_u=1
        s=d.splines.new('POLY');s.points.add(len(pts)-1)
        for p,(x,y) in zip(s.points,pts):p.co=(x,y,z,1)
        ob=bpy.data.objects.new('angular filament',d);bpy.context.collection.objects.link(ob);d.materials.append(mat);return ob
    def disc(radius,mat,z=0):
        return mesh('ground disc',[(radius*math.cos(i*TAU/96),radius*math.sin(i*TAU/96),z) for i in range(96)],mat)
    for name,count,size in [('ground_tile',1,64),('ground_field',11,384)]:
        for f in range(count):
            bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;cel.setup_scene(s,8);cel.install('vfx',normals=False)
            for layer in s.view_layers:layer.use_pass_normal=False;layer.use_pass_emit=False
            s.render.threads_mode='FIXED';s.render.threads=8
            s.render.resolution_x=s.render.resolution_y=size;s.render.resolution_percentage=100
            cam=bpy.data.cameras.new('Pure top down');ob=bpy.data.objects.new('Camera',cam);s.collection.objects.link(ob)
            ob.location=(0,0,10);cam.type='ORTHO';cam.ortho_scale=6.4;s.camera=ob
            lilac=material('arc #B9A6FF',(185/255,166/255,1));heart=material('core #F2EEFF',(242/255,238/255,1))
            dim=material('violet recess',(.22,.18,.32));slate=material('wet slate',(.075,.10,.12));reflection=material('slate reflections',(.13,.18,.20))
            nonemit=[];rng=random.Random(930+f)
            if name=='ground_tile':
                nonemit.append(mesh('seamless water',[(-4,-4,0),(4,-4,0),(4,4,0),(-4,4,0)],slate))
                for j in range(9):
                    x=rng.uniform(-2.5,2.1);y=rng.uniform(-2.4,2.5)
                    nonemit.append(mesh('water glint',[(x,y,.01),(x+.5,y+.08,.01),(x+.85,y+.04,.01),(x+.25,y-.06,.01)],reflection))
                for j in range(4):
                    x=rng.uniform(-2.3,1.2);y=rng.uniform(-2.3,2.2)
                    pts=[(x,y),(x+.35,y+.22),(x+.23,y+.40),(x+.85,y+.25),(x+1.2,y+.5)]
                    stroke(pts,.055,lilac);stroke(pts,.018,heart,.075)
            else:
                fade=1 if f<8 else [0.65,0.32,0.10][f-8]
                nonemit.append(disc(2.96,slate))
                # The loop retains a stable ring; angular fissures jump between frames.
                for j in range(12):
                    a=j*TAU/12;pts=[((2.87+.025*math.sin(k*2+f))*math.cos(a+k*.040),(2.87+.025*math.sin(k*2+f))*math.sin(a+k*.040)) for k in range(12)]
                    if f<8 or j%(f-6)==0:stroke(pts,.019*fade+.004,lilac)
                for j in range(10):
                    a=j*TAU/10+rng.uniform(-.12,.12)
                    pts=[]
                    for k in range(6):
                        r=.65+k*.435;angle=a+(rng.uniform(-.13,.13) if k not in (0,5) else 0)
                        pts.append((r*math.cos(angle),r*math.sin(angle)))
                    nonemit.append(stroke(pts,.055,dim,.015))
                    if f>=8 and j%(f-6):continue
                    stroke(pts,.020*fade+.003,lilac);stroke(pts[2:5],.007*fade+.002,heart,.075)
                    p=pts[3];q=(p[0]+.37*math.cos(a+.9),p[1]+.37*math.sin(a+.9));r=(q[0]+.25*math.cos(a+.5),q[1]+.25*math.sin(a+.5))
                    stroke([p,q,r],.013*fade+.002,lilac)
                if f>=8:
                    # Physical material radiance fades as well as filament coverage.
                    for mat in (lilac,heart):
                        e=next(n for n in mat.node_tree.nodes if n.type=='EMISSION');e.inputs[1].default_value=fade
            s.render.filepath=str(WORK/f'{name}_{f:02d}.png');bpy.ops.render.render(write_still=True)
            for o in nonemit:o.hide_render=True
            s.render.resolution_x=s.render.resolution_y=size//2
            s.render.filepath=str(WORK/f'{name}_{f:02d}_e.png');bpy.ops.render.render(write_still=True)

    import icons_norm_build as kit
    kit.WORK=WORK
    def bolt(pts,r=.024):
        kit.line(pts,r,kit.glow);kit.line(pts,r*.31,kit.heart,y=-.34)
    def rod(x=-.32):
        kit.line([(x,-.49),(x,.41)],.044,kit.metal)
        kit.line([(x-.11,.25),(x,.41),(x+.11,.25)],.025,kit.metal)
        kit.line([(x,-.42),(x,-.15)],.014,kit.heart,y=-.34)
    def arc():
        rod();bolt([(-.32,.42),(-.04,.22),(-.13,.06),(.20,.10),(.12,-.12),(.53,-.25)],.033)
        kit.dot(.53,-.25,.075,kit.heart)
        bolt([(-.04,.22),(.12,.40),(.25,.36)],.015)
    def discharge():
        charged=kit.mat('#59625F',.85)
        kit.plate([(-.16,-.34),(-.23,.05),(-.14,.18),(-.17,.34),(-.03,.44),(.12,.34),(.10,.15),(.24,.03),(.17,-.34)],charged)
        for x in (-.11,.08):
            kit.plate([(x-.035,.32),(x-.07,.52),(x+.04,.39)],kit.metal)
            kit.dot(x,.25,.027,kit.heart,y=-.35)
        kit.line([(-.18,.05),(-.05,.15),(.09,.04)],.032,kit.metal)
        for j in range(7):
            a=j*TAU/7;pts=[(.16*math.cos(a),.16*math.sin(a))]
            for r,t in [(.32,a+.22),(.40,a-.1),(.64,a+.08)]:pts.append((r*math.cos(t),r*math.sin(t)))
            bolt(pts,.023)
        kit.dot(0,0,.075,kit.heart)
    def earth():
        rod(-.06)
        kit.arc(0,-.37,.58,0,TAU,kit.glow,.025,32,sy=.32)
        for sign in (-1,1):bolt([(sign*.10,-.20),(sign*.31,-.12),(sign*.24,-.32),(sign*.49,-.38)],.022)
        kit.plate([(-.3,-.49),(.30,-.49),(.19,-.41),(-.22,-.42)],kit.metal)
    def storm():
        cloud=kit.mat('#354044',.9)
        for x,z,r in [(-.34,.29,.22),(-.13,.42,.26),(.15,.38,.28),(.37,.27,.19)]:kit.blob(x,z,r,cloud,9)
        bolt([(.07,.22),(-.13,-.04),(.11,-.01),(-.10,-.29),(.08,-.23),(-.08,-.57)],.043)
        bolt([(.08,.15),(.29,-.02),(.22,-.15),(.41,-.32)],.018)
        kit.arc(-.08,-.55,.34,0,TAU,kit.glow,.019,24,sy=.22)
    for name,emblem in zip(NAMES,[arc,discharge,earth,storm]):
        s=kit.scene(name,emblem,'#B9A6FF');s.render.resolution_x=s.render.resolution_y=128
        # Match the approved 111x112 medallion footprint at final resolution.
        s.camera.data.ortho_scale*=1.017
        s.camera.data.shift_x-=1.5/128
        s.eevee.taa_render_samples=12;s.render.threads_mode='FIXED';s.render.threads=8
        for layer in s.view_layers:layer.use_pass_normal=False
        bpy.ops.render.render(write_still=True)
    print('PASS Blender lot B: 12 VFX frames + emission, 4 icons',flush=True)

def pack():
    from PIL import Image,ImageStat
    import hashlib
    WORK.mkdir(parents=True,exist_ok=True);ICONS.mkdir(parents=True,exist_ok=True)
    outputs=[];checks=[]
    for name,n,size in [('ground_tile',1,64),('ground_field',11,384)]:
        folder=VFX/name;folder.mkdir(parents=True,exist_ok=True)
        for suffix,side in [('',size),('_e',size//2)]:
            frames=[Image.open(WORK/f'{name}_{f:02d}{suffix}.png').convert('RGBA') for f in range(n)]
            assert all(im.size==(side,side) and im.getbbox() for im in frames)
            if n>1:assert len({hashlib.sha256(im.tobytes()).hexdigest() for im in frames})==n
            sheet=Image.new('RGBA',(n*side,side))
            for i,im in enumerate(frames):sheet.paste(im,(i*side,0))
            path=folder/f'{name}{suffix}.png';sheet.save(path,optimize=True);outputs.append(path)
            a=sheet.getchannel('A');assert a.getextrema()[1]>0
            if name=='ground_field':assert a.getextrema()[0]==0
            if suffix:assert max(ImageStat.Stat(sheet).extrema[c][1] for c in range(3))>0
            checks.append({'file':str(path),'size':sheet.size,'alpha':a.getextrema(),'frames':n})
    for name in NAMES:
        im=Image.open(WORK/f'{name}_raw.png').convert('RGBA');assert im.size==(128,128)
        assert im.getbbox()==(10,8,121,120)
        assert im.getchannel('A').getextrema()==(0,255)
        assert max(ImageStat.Stat(im).stddev[:3])>25
        path=ICONS/f'{name}.png';im.save(path,optimize=True);outputs.append(path)
        checks.append({'file':str(path),'size':im.size,'alpha':(0,255)})
    tile=Image.open(VFX/'ground_tile/ground_tile.png')
    assert tile.crop((0,0,1,64)).tobytes()==tile.crop((63,0,64,64)).tobytes()
    assert tile.crop((0,0,64,1)).tobytes()==tile.crop((0,63,64,64)).tobytes()
    # Contact assembly only; no Pillow drawing or asset resizing.
    board=Image.new('RGBA',(896,640),(27,29,34,255))
    for i,name in enumerate(NAMES):board.alpha_composite(Image.open(ICONS/f'{name}.png'),(i*160+20,12))
    for i in range(6):
        for j in range(3):board.alpha_composite(tile,(i*64+496,j*64+160))
    for i,f in enumerate([0,3,7,8,9,10]):
        im=Image.open(WORK/f'ground_field_{f:02d}.png');im.thumbnail((192,192))
        board.alpha_composite(im,((i%3)*192+8,(i//3)*208+160))
    board.save(WORK/'controle_b.png',optimize=True)
    total=sum(p.stat().st_size for p in outputs);assert total<=1500000,total
    (WORK/'verification_b.json').write_text(json.dumps({'bytes':total,'files':checks,'tile_seam':'PASS','distinct_frames':'PASS'},indent=2),encoding='utf8')
    print(f'PASS 8 PNG; dimensions, alpha, seamless tile, distinct frames, contrast; {total} bytes')

if __name__=='__main__':
    if '--pack' in sys.argv:pack()
    else:render()
