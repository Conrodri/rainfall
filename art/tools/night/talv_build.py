"""TALV: reuse SA1 geometry, rig and CEL compositor; Blender background only."""
import sys, math, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
import sa1_build as sa
import bpy
from PIL import Image
sys.path.insert(0,str(ROOT/'art/tools'))
from halve_emission import downscale
OUT=ROOT/'art/tools/night/_talv_out'
DEST=sa.DEST/'variants'
rng=random.Random(2710)
def tube(name,pts,r,mat,g): return sa.tube(name,pts,r,mat,g,5)
def build(name,w,h,n,cols):
    sa.iso.create_rig('CREA' if name=='temper_sheen' else 'TOP',(w,h))
    s=bpy.context.scene;s.render.threads_mode='FIXED';s.render.threads=6
    if name=='cut_cleave':s.camera.location.x=2.75
    bark=sa.mat('Weathered bark','504739');dark=sa.mat('Fracture shadow','252B26')
    sap=sa.mat('Sap CDEB6E','CDEB6E',1.0);water=sa.mat('Cold water reflection 7FC8C0','7FC8C0',1.0)
    steam=sa.mat('Pale cold vapour','6D8581')
    groups=[]
    for f in range(n):
        g=sa.empty(name+' frame '+str(f));groups.append(g);p=f/(n-1)
        if name=='cut_kesa':
            radius=[1.8,2.35,2.8,2.985,2.94,2.9][f]
            span=[.35,.75,1.25,math.pi/2,1.15,.55][f]
            end=math.pi/4;start=end-span
            for band in range(3):
                pts=[]
                for j in range(65):
                    t=j/64;a=start+span*t;rr=radius-band*.055*(math.sin(math.pi*t)**.5)
                    pts.append((rr*math.cos(a),rr*math.sin(a),.02+band*.003))
                tube('Single heavy kesa edge' if band==0 else 'Dark swept heartwood',pts,[.002+.012*math.sin(math.pi*j/64)**.7*(1-.6*p) for j in range(65)],sap if band==0 else dark,g)
            for j in range(23):
                a=start+span*rng.random();r=radius-rng.uniform(.08,.5)-p*.10
                x,y=r*math.cos(a),r*math.sin(a)
                ob=sa.plaque('Flying bark shaving',(x,y,.015),(.025+rng.random()*.065,.013,.015),bark,g)
                ob.rotation_euler.z=a+.7
        elif name=='cut_cleave':
            length=[2.3,4.1,5,5,4.4,2.8][f];opening=[.07,.16,.23,.16,.07,.015][f]
            pts=[(.018+length*j/40,.045*math.sin(j*1.9)+.028*math.sin(j*.7),.022) for j in range(41)]
            tube('Jagged opened earth',pts,[opening*math.sin(math.pi*j/40)**.4+.003 for j in range(41)],dark,g)
            tube('Sap in closing fault',[(x,y,z+.025) for x,y,z in pts],[.002+opening*.12*math.sin(math.pi*j/40) for j in range(41)],sap,g)
            for j in range(18):
                x=.10+length*rng.random();side=(-1,1)[j%2];y=side*(opening+.03+rng.random()*.26)*(1-.5*p)
                ob=sa.plaque('Broken bark bank',(x,y,.025),(.06+rng.random()*.12,.025+rng.random()*.04,.035),bark,g);ob.rotation_euler.z=rng.uniform(-.7,.7)
                if j%3==0:
                    tube('Branching sap fissure',[(x,0,.045),(x+.08,y*.45,.045),(x+.16,y*.7,.045)],[.008,.005,.0015],sap,g)
        else:
            # CREA projection of SA1's .93-unit blade: narrow overlay only.
            for j in range(2):
                center=(f*.25+j*.49)%1
                ts=[max(0,min(1,center+(k/16-.5)*.29)) for k in range(17)]
                tube('Running water sheen',[(.17*t*t-.075,0,.07+.93*t-.48) for t in ts],[.001+.009*math.sin(math.pi*k/16) for k in range(17)],water,g)
            t=(f*.25+.2)%1
            tube('Water drop',[(.17*t*t-.055,-.01,.93*t-.48),(.17*t*t-.05,-.01,.93*t-.51)],[.009,.002],water,g)
            for j in range(2):
                tube('Small escaping steam',[(.01+j*.028+.012*math.sin(k*.9+f),.01,.06+j*.12+k*.014) for k in range(7)],[.0025]*(7),steam,g)
    sa.merge_parts();sa.cel.install('vfx',normals=False)
    sheets=[Image.new('RGBA',(cols*w,math.ceil(n/cols)*h)) for _ in range(2)]
    for f,g in enumerate(groups):
        for group in groups:
            for ob in group.children_recursive:ob.hide_render=group!=g
        path=OUT/name/f'{f:02}.png';path.parent.mkdir(parents=True,exist_ok=True)
        sa.iso.common.configure_passes(path);s.eevee.taa_render_samples=8;s.render.filepath=str(path)
        bpy.ops.render.render(write_still=True)
        for k,suffix in enumerate(('','_e')):
            src=path if not suffix else next(path.parent.glob(path.stem+'_e__*.png'))
            with Image.open(src) as im:im=im.convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
            sheets[k].paste(im,((f%cols)*w,(f//cols)*h))
    sa.cel.uninstall();dest=DEST/name;dest.mkdir(parents=True,exist_ok=True)
    sheets[0].save(dest/'default.png',optimize=True)
    downscale(sheets[1]).save(dest/'default_e.png',optimize=True)
    subs=[];entries=[]
    for f in range(n):
        subs.append(f'[sub_resource type="AtlasTexture" id="a{f}"]\natlas = ExtResource("1")\nregion = Rect2({f%cols*w}, {f//cols*h}, {w}, {h})')
        entries.append('{"duration": 1.0, "texture": SubResource("a%d")}'%f)
    text=f'[gd_resource type="SpriteFrames" load_steps={n+2} format=3]\n\n[ext_resource type="Texture2D" path="res://assets/sprites/characters/morfil/variants/{name}/default.png" id="1"]\n\n'+'\n\n'.join(subs)+'\n\n[resource]\nanimations = [{"frames": ['+', '.join(entries)+'], "loop": '+('true' if n==4 else 'false')+', "name": &"default", "speed": '+('8.0' if n==4 else '24.0')+'}]\n'
    (dest/(name+'.tres')).write_text(text)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/characters'/('morfil_'+name+'.blend')))
    print('PASS TALV '+name,flush=True)
for spec in [('cut_kesa',768,768,6,3),('cut_cleave',704,192,6,3),('temper_sheen',128,128,4,4)]:build(*spec)
