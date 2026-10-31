from pathlib import Path
import sys, math, json, random
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
import f2p_build as f
import cel_style as cel
from mathutils import Vector
OUT=ROOT/'game/assets/sprites/props/fog_forest'; SRC=ROOT/'art/blender/props'
f.SPECS={'stump':(128,94),'mushrooms':(128,94),'standing_stone':(192,166),'root_arch_a':(256,224)}
f.OUT=OUT; f.SRC=SRC

# Retouch parameters: original cells/pivots; short projected shadows.
SHADOW_LENGTH=.6
MUSHROOMS=[(-.28,.22,.62,.27),(.12,.24,.84,.32),(.38,.02,.55,.25),
           (-.39,-.10,.49,.24),(-.03,-.10,.66,.30),(.26,-.29,.41,.25),(-.20,-.35,.33,.22)]

def stump(root,m):
    rng=random.Random(32); N=9; verts=[]
    for k,(z,rx,ry) in enumerate(((.04,.57,.44),(.34,.52,.42),(.65,.34,.32))):
        for j in range(N):
            a=math.tau*j/N; r=rng.uniform(.83,1.14)
            verts.append((rx*r*math.cos(a)+.10*k,ry*r*math.sin(a),z+rng.uniform(-.07,.07)))
    faces=[]
    for k in range(2):
        for j in range(N):
            a=k*N+j;b=k*N+(j+1)%N;c=b+N;d=a+N
            faces.extend(((a,b,d),(b,c,d)))
    verts.append((.15,-.06,.79))
    faces.extend((2*N+j,2*N+(j+1)%N,3*N) for j in range(N))
    ob=f.mesh('Collapsed irregular fracture',verts,faces,m['rock'],root)
    ob.data.materials.append(m['wood'])
    for poly in ob.data.polygons:
        if poly.index>=4*N:poly.material_index=1
    for j,(x,y,r) in enumerate(((-.55,-.25,.12),(.43,-.40,.14),(.60,.15,.11),(-.30,.42,.09))):
        f.pebble('Fresh fallen chip',(x,y,r*.5),(r,r*.72,r*.55),m['wood'] if j%2==0 else m['rock'],root,41+j)

def mushrooms(root,m):
    for i,(x,y,z,r) in enumerate(MUSHROOMS):
        f.tube('Thick ivory stalk',[(x,y,.04),(x+.025,y,z-.10)],.052,m['bone'],root)
        N=32; verts=[]
        # Thick rounded mauve crown, curled rim and exposed luminous underside.
        for rr,h in ((0,.16),(.40,.15),(.78,.10),(1,0),(.97,-.075),(.72,-.10),(.13,-.07)):
            for j in range(N):
                a=math.tau*j/N; radius=r*rr*(1+.035*math.sin(5*a+i))
                verts.append((x+radius*math.cos(a),y+radius*.86*math.sin(a),z+h+.012*math.sin(3*a+i)))
        faces=[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(6) for j in range(N)]
        ob=f.mesh('Thick mauve cap',verts,faces,m['cap'],root)
        for poly in ob.data.polygons:poly.use_smooth=True
        for j in range(16):
            a=j*math.tau/16
            f.tube('Luminous amethyst gill',[(x+math.cos(a)*r*.15,y+math.sin(a)*r*.13,z-.075),
                (x+math.cos(a)*r*.70,y+math.sin(a)*r*.60,z-.105),
                (x+math.cos(a)*r*.94,y+math.sin(a)*r*.81,z-.068)],.012,m['glow'],root)

def stone(root,m):
    N=40; verts=[]
    levels=((.02,.49),(.12,.47),(.30,.43),(.49,.38),(.69,.33),(.88,.28),(1.08,.22),(1.28,.16),(1.42,.08),(1.47,.015))
    for k,(z,r) in enumerate(levels):
        for j in range(N):
            a=math.tau*j/N
            rr=r*(1+.10*math.sin(5*a+.6*k)+.065*math.sin(9*a-.4*k))
            verts.append((rr*math.cos(a)+.045*math.sin(z*2),rr*.85*math.sin(a),z+.018*math.sin(4*a+k)))
    faces=[tuple(range(N-1,-1,-1))]+[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(len(levels)-1) for j in range(N)]
    ob=f.mesh('Squat weathered stalagmite',verts,faces,m['bone'],root)
    for poly in ob.data.polygons:poly.use_smooth=True
    for k in (1,2,3,4,5,6,7):
        pts=[verts[k*N+j] for j in range(N)]
        pts=[(x*1.015,y*1.015,z) for x,y,z in pts];pts.append(pts[0])
        f.tube('Wavy calcite growth band',pts,.018 if k<4 else .012,m['bone'],root)

def arch(root,m):
    # Closed irregular stone vault: thick shoulders and continuous rock crown.
    N=27; K=12; verts=[]
    for i in range(N):
        a=math.pi*i/(N-1);x=.91*math.cos(a);z=.10+1.18*math.sin(a)
        radius=.235*(1+.14*math.sin(i*1.7)+.08*math.cos(i*.8))
        for j in range(K):
            b=math.tau*j/K;rr=radius*(1+.12*math.sin(j*2.7+i*.9))
            verts.append((x+rr*math.cos(b)*math.cos(a),rr*.85*math.sin(b),z+rr*math.cos(b)*math.sin(a)))
    faces=[tuple(range(K-1,-1,-1))]+[(i*K+j,i*K+(j+1)%K,(i+1)*K+(j+1)%K,(i+1)*K+j) for i in range(N-1) for j in range(K)]+[tuple((N-1)*K+j for j in range(K))]
    ob=f.mesh('Eroded natural stone vault',verts,faces,m['rock'],root)
    for poly in ob.data.polygons:poly.use_smooth=True
    for j in range(9):
        a=.30+j*.31;x=.91*math.cos(a);z=.10+1.18*math.sin(a)-.16
        length=.23+.20*((j*7)%5)/4
        pts=[(x,-.18,z),(x+.035,-.20,z-length*.4),(x-.035,-.21,z-length)]
        f.tube('Hanging dead root',pts,.018 if j%3 else .026,m['deadroot'],root)
        if j%2==0:f.tube('Broken root twig',[pts[1],(x+.12,-.21,z-length*.72)],.009,m['deadroot'],root)

f.stump=stump; f.mushrooms=mushrooms; f.stone=stone; f.arch=arch
# No new archive: keep the original rollback copy unchanged.
import inspect, iso_rig as rig
cel.install('prop', normals=False)
_original_setup=cel.setup_scene
def modest_setup(*args,**kwargs):
    result=_original_setup(*args,**kwargs)
    __import__('bpy').context.scene.eevee.taa_render_samples=16
    return result
cel.setup_scene=modest_setup
_src=inspect.getsource(rig.render_frame).replace("('_n','_e')","()")
if _src != inspect.getsource(rig.render_frame): exec(compile(_src, str(ROOT/'art/tools/iso/iso_rig.py'),'exec'),rig.__dict__)

from PIL import Image
boardpath=ROOT/'art/renders/grotte/g3a_avant_apres.png'
if boardpath.exists() and Image.open(boardpath).size==(1024,512):
    oldboard=Image.open(boardpath).convert('RGBA')
    before={name:oldboard.crop((i*256+128-size//2,224-fy,i*256+128+size//2,224-fy+size)) for i,(name,(size,fy)) in enumerate(f.SPECS.items())}
else:before={name:Image.open(OUT/(name+'.png')).convert('RGBA') for name in f.SPECS}
metrics=[]
for name,(size,fy) in f.SPECS.items():
    scene=f.rig.create_rig('MAP',(size,size)); scene.eevee.taa_render_samples=16
    scene.camera.location += scene.camera.rotation_euler.to_matrix()@Vector((0,(fy-size/2)/f.rig.R,0))
    root=f.C.empty(name); m=f.materials()
    m['rock']=f.worn('Ferruginous sandstone','5A4232','7A5D45',0,.8)
    m['wood']=f.worn('Fresh sandstone fracture','8A725B','B39A7B',0,.75)
    m['bone']=f.worn('Calcite','8A7A62','B5A58A',0,.65)
    m['cap']=f.worn('Mauve cave cap','6A5A66','8A7485',0,.65)
    m['bronze']=m['rock']; m['lichen']=m['bone']
    m['deadroot']=f.worn('Dry dead roots','382B24','635142',0,.85)
    m['glow']=f.worn('Amethyst mycelium','C27BFF','E6C8FF',1,.25)
    glow=m['glow'].node_tree.nodes.get('Principled BSDF')
    glow.inputs['Emission Color'].default_value=tuple((int('C27BFF'[i:i+2],16)/255)**2.2 for i in (0,2,4))+(1,)
    glow.inputs['Emission Strength'].default_value=2.0
    m['glow']['rainfall_emissive']=True
    if name=='stump': stump(root,m)
    elif name=='mushrooms': mushrooms(root,m)
    elif name=='standing_stone': stone(root,m)
    else: arch(root,m)
    if name=='root_arch_a':root.rotation_euler.z=math.pi/4
    if name=='stump':root.scale=(.85,.85,1)
    if name=='mushrooms':root.scale=(.90,.90,.91)
    f.rig.bake_ao_shadows(root)
    f.rig.render_frame(OUT/(name+'.png'))
    pivot=f.world_to_camera_view(scene,scene.camera,Vector((0,0,0)))
    actual=[round(pivot.x*size,4),round((1-pivot.y)*size,4)]
    if abs(actual[0]-size/2)>.05 or abs(actual[1]-fy)>.05:raise RuntimeError('G3a pivot '+name+' '+str(actual))
    metrics.append(dict(name=name,foot=actual,size=[size,size],frames=1,shadow_length=SHADOW_LENGTH))
    emission=OUT/(name+'_e.png')
    if emission.exists():
        with Image.open(emission) as src: im=src.convert('RGBA')
        if max(im.getchannel(c).getextrema()[1] for c in 'RGB')==0:emission.unlink()
        else:im.resize(((size+1)//2,(size+1)//2),Image.Resampling.LANCZOS).save(emission)
    bpy=__import__('bpy'); bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('g_'+name+'.blend')))
    f.rig.create_rig('TOP',(512,512),reset=False)
    sun=bpy.data.objects['Sun_chaud_haut_gauche'];ray=sun.rotation_euler.to_matrix()@Vector((0,0,-1))
    ray.x*=SHADOW_LENGTH;ray.y*=SHADOW_LENGTH
    sun.rotation_euler=ray.to_track_quat('-Z','Y').to_euler()
    f.rig.render_shadow_decal(root,OUT/(name+'_shadow.png'))
# Pillow assembles the single control board; no drawing.
board=Image.new('RGBA',(1024,512),(26,24,29,255))
for i,(name,(size,fy)) in enumerate(f.SPECS.items()):
    for row,im in enumerate((before[name],Image.open(OUT/(name+'.png')).convert('RGBA'))):
        board.alpha_composite(im,(i*256+128-size//2,row*256+224-fy))
boardpath=ROOT/'art/renders/grotte/g3a_avant_apres.png';boardpath.parent.mkdir(parents=True,exist_ok=True)
board.convert('RGB').save(boardpath)
(ROOT/'art/tools/props/_g3a_geometry_check.json').write_text(json.dumps(metrics,indent=2))
print('PASS G3a rendered 4 props; shadows x0.6; no archive',flush=True)