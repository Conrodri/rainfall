"""C7E: exact C7C geometry/rig/density, brighter PBR and four requested VFX.
Run with Blender 5.2 --background --python this_file. Pillow only packs/inspects.
"""
import sys, math, json, re, random, tempfile, hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import c7c_build as base
from c7c_build import bpy, c, legacy, Vector, Image, worn
ROOT=base.ROOT; DST=base.DST
REPORT=HERE/'_c7e_render_report.json'

def setup():
    s=original_setup()
    bpy.data.objects['Fill_froid'].data.energy=650
    bpy.ops.object.light_add(type='AREA',location=(-3,-.6,5.5))
    rim=bpy.context.object;rim.name='C7E cold upper left rim'
    rim.data.energy=680;rim.data.color=(.54,.71,1);rim.data.shape='DISK';rim.data.size=3
    rim.rotation_euler=(Vector((0,0,1.7))-rim.location).to_track_quat('-Z','Y').to_euler()
    return s

original_setup=base.setup
base.setup=setup
def brighter(name,dark,light,metal=0,rough=.8):
    colors={
      'Scabbed iron':('55483B','A88060'),
      'Soot black':('384345','77807B'),
      'Worn brass':('797054','D2BC8C'),
      'Cast bell':('465C55','94A18A'),
      'Bell lip':('74694C','C5B68A')}
    for prefix,pair in colors.items():
        if name.startswith(prefix):dark,light=pair;break
    return worn(name,dark,light,metal,rough)
base.worn=brighter

def body():
    root,pose,fire=base.build()
    # Existing surfaces only: keep the complete C7C mesh, hierarchy and rest pivots.
    for ob in root.children_recursive:
        if ob.type!='MESH':continue
        if ob.name.startswith(('Armoured furnace door','Bell cast moulding')) or (ob.name.startswith('Peened brass bolt') and ob.location.y<-.4):
            m=ob.data.materials[0].copy();m.name='C7E amber seam '+ob.name
            bs=m.node_tree.nodes.get('Principled BSDF')
            bs.inputs['Emission Color'].default_value=(*legacy.linear('FFC584'),1)
            bs.inputs['Emission Strength'].default_value=.065 if ob.name.startswith('Armoured') else .24
            ob.data.materials[0]=m
    return root,pose

def front_camera(w,h,scale,center):
    s=bpy.context.scene;s.camera.rotation_euler=(math.pi/2,0,0)
    # C7C uses sensor_fit HORIZONTAL even for portrait atlases: ortho is WIDTH.
    s.camera.location=(0,-20,center);s.camera.data.ortho_scale=scale*w/max(w,h)
    s.render.dither_intensity=0

def effect(task):
    setup();root=c.empty('C7E '+task)
    amber=legacy.emissive('C7E pale amber','FFC584',1)
    core=legacy.emissive('C7E white amber core','FFF0CC',1.8)
    if task=='glas_wave':
        s=bpy.context.scene;s.camera.rotation_euler=(0,0,0);s.camera.location=(0,0,10);s.camera.data.ortho_scale=2
        rings=[]
        for j in range(3):
            # Slightly fractured concentric wave fronts, never a solid cartoon disc.
            for k in range(10):
                points=[]
                for q in range(8):
                    a=(k+(q/7)*.90)*math.tau/10
                    r=1-j*.055+.008*math.sin(a*13+j)
                    points.append((r*math.cos(a),r*math.sin(a),.015+j*.004))
                rings.append((c.tube('Ringing pressure filament',points,.007 if j else .011,amber,root),j))
        def pose(t):
            u=t*8/7;r=.12+.81*u
            root.scale=(r,r,1)
            amber.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=max(.015,1.25*(1-u)**.7)
            for ob,j in rings:ob.scale.z=1;ob.hide_render=(u>.73 and j==2)
        return root,pose
    if task=='lightning':
        front_camera(128,768,12,6)
        def pose(t):
            for ob in list(root.children):bpy.data.objects.remove(ob,do_unlink=True)
            rng=random.Random(741+int(t*4)*31)
            pts=[(0,0,11.83)]+[(rng.uniform(-.29,.29),0,11.83-k*11.66/23) for k in range(1,23)]+[(0,0,.17)]
            paths=[(pts,.028,.074)]
            for k in (4,9,14,18):
                p=Vector(pts[k]);end=p+Vector((rng.choice((-1,1))*.54,0,-rng.uniform(.7,1.4)))
                branch=[tuple(p.lerp(end,q/5)+Vector((rng.uniform(-.08,.08) if q not in (0,5) else 0,0,0))) for q in range(6)]
                paths.append((branch,.012,.029))
            for points,rc,rg in paths:
                halo=c.tube('Amber corona',points,rg,amber,root)
                white=c.tube('Lightning core',[(x,y-.09,z) for x,y,z in points],rc,core,root)
                for ob in (halo,white):
                    ob.data.bevel_resolution=1
                    for bp in ob.data.splines[0].bezier_points:bp.handle_left_type='VECTOR';bp.handle_right_type='VECTOR'
            c.sphere('Ground contact',(0,0,.17),(.17,.08,.055),core,root)
        return root,pose
    if task=='steam_jet':
        # Screen-space horizontal 6u jet, 1u cross section; source at left edge.
        front_camera(384,64,6,0)
        smoke=worn('Dirty wet pressure vapour','3E3A31','999589',0,.98)
        bs=smoke.node_tree.nodes.get('Principled BSDF');bs.inputs['Alpha'].default_value=.34
        bs.inputs['Emission Strength'].default_value=0;bs.inputs['Emission Color'].default_value=(0,0,0,1)
        smoke.surface_render_method='DITHERED'
        parts=[];rng=random.Random(817)
        for j in range(34):
            u=j/33
            ob=c.sphere('Turbulent pressure condensate',(0,0,0),(1,1,1),smoke,root)
            parts.append((ob,u,rng.uniform(-1,1),rng.uniform(0,math.tau)))
        def pose(t):
            for ob,u,offset,phase in parts:
                v=(u+t*.5)%1
                ob.location=(-2.78+5.2*v,.10*math.sin(phase+t*math.tau),offset*(.025+.16*v)+.035*math.sin(phase+t*math.tau))
                ob.scale=(.15+.27*v,.065+.10*v,.04+.12*v)
        return root,pose
    if task=='bolt':
        s=bpy.context.scene;s.camera.location-=s.camera.rotation_euler.to_matrix()@Vector((0,5.3*.15,0))
        s.camera.data.ortho_scale=1.05
        brass=worn('C7E bolt worn brass','655339','C1AC77',.72,.46)
        legacy.lathe('Hexagonal upset bolt head',[(0,.0),(.17,.0),(.20,.04),(.20,.14),(.15,.18),(0,.18)],brass,root,6)
        c.rod('Threaded bolt shaft',(0,0,0),(0,0,-.45),.078,brass,root)
        for z in (-.10,-.18,-.26,-.34,-.42):c.ring('Worn screw thread',(0,0,z),.089,.014,brass,root,rotation=(0,0,0))
        trails=[]
        ghost=brass.copy();ghost.name='Two frame falling metal trail';ghost.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.16;ghost.surface_render_method='DITHERED'
        for j in range(2):trails.append(c.rod('Falling streak',(-.08+j*.14,.06,.10),(-.11+j*.14,.06,.36),.012,ghost,root))
        def pose(t):
            root.rotation_euler.x=math.tau*t;root.rotation_euler.y=.28*math.sin(math.tau*t)
            for ob in trails:ob.hide_render=int(round(t*6)) not in (1,4)
        return root,pose
    raise ValueError(task)

def render_sheet(task,root,pose,n,dirs,cell,tmp,isbody=False):
    s=bpy.context.scene;s.render.resolution_x=cell[0]*2;s.render.resolution_y=cell[1]*2
    boards=[Image.new('RGBA',(cell[0]*n,cell[1]*len(dirs)),(128,128,255,0) if j==1 else (0,0,0,0)) for j in range(3)]
    for row,d in enumerate(dirs):
        for i in range(n):
            path=tmp/f'{task}_{d}_{i}.png'
            fn=(lambda t:pose(task.replace('_dirs',''),i,n)) if isbody else pose
            c.render_still(root,fn,path,i/n,d)
            for j,suffix in enumerate(('','_n','_e')):
                im=Image.open(path.with_name(path.stem+suffix+'.png')).convert('RGBA').resize(cell,Image.Resampling.LANCZOS)
                if j==0:alpha=im.getchannel('A')
                else:im.putalpha(alpha)
                if j==1:im.putdata([(128,128,255,0) if a==0 else (r,g,b,a) for r,g,b,a in im.getdata()])
                boards[j].paste(im,(i*cell[0],row*cell[1]))
    for board,suffix in zip(boards,('','_n','_e')):board.save(DST/f'{task}{suffix}.png',compress_level=9)
    report=json.loads(REPORT.read_text()) if REPORT.exists() else {}
    report[task]={'cell':cell,'frames':n,'directions':dirs,'size':boards[0].size}
    REPORT.write_text(json.dumps(report,indent=2));print('C7E DONE '+task,flush=True)

def resources():
    p=DST/'sonneur.tres';text=p.read_text(encoding='utf-8');ext=[];subs=[];anims=[]
    # Sole existing frame change explicitly requested: 32 -> 64px bolt cells.
    text=re.sub(r'(atlas = ExtResource\("bolt"\)\s*region = Rect2\()(\d+), 0, 32, 32\)',lambda m:m[1]+str(int(m[2])*2)+', 0, 64, 64)',text)
    for name,n,w,h,loop,fps in [('glas_wave',8,256,256,False,10),('steam_jet',8,384,64,True,12)]:
        if f'"name": &"{name}"' in text:continue
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/sonneur/{name}.png" id="c7e_{name}"]')
        frames=[]
        for i in range(n):
            sid=f'C7e_{name}_{i}';subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("c7e_{name}")\nregion = Rect2({i*w}, 0, {w}, {h})')
            frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
        anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(loop).lower()+', "name": &"'+name+'", "speed": '+str(fps)+'}')
    if ext:
        text=text.replace('[sub_resource','\n\n'.join(ext)+'\n\n[sub_resource',1)
        text=text.replace('[resource]','\n\n'.join(subs)+'\n\n[resource]',1)
        at=text.rfind(']');text=text[:at]+',\n'+',\n'.join(anims)+text[at:]
        text=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])+len(ext)+len(subs)),text,count=1)
    p.write_text(text,encoding='utf-8')

def main():
    backup=HERE/'_c7e_before';backup.mkdir(exist_ok=True)
    for name in ('idle_p1','idle_p2','idle_p3','lightning','bolt'):
        dest=backup/(name+'.png')
        if not dest.exists():dest.write_bytes((DST/dest.name).read_bytes())
    tres=backup/'sonneur.tres'
    if not tres.exists():tres.write_bytes((DST/tres.name).read_bytes())
    with tempfile.TemporaryDirectory(prefix='rainfall_c7e_') as temp:
        tmp=Path(temp)
        tasks=[a for a in base.COUNTS if a not in base.EXTRAS]+['auto_dirs','spell_a_dirs','spell_b_dirs']
        if '--effects' not in sys.argv:
            root,pose=body();base.save_source(root,pose)
            for task in tasks:
                n=base.COUNTS[task.replace('_dirs','')]
                dirs=['e','w','n'] if task.endswith('_dirs') else ['e','s','w','n'] if task.startswith('walk') else ['s']
                render_sheet(task,root,pose,n,dirs,(256,256),tmp,True)
                if task=='idle_p1':
                    im=Image.open(DST/'idle_p1.png').convert('RGBA');px=[(r+g+b)/3 for r,g,b,a in im.getdata() if a>200]
                    print('C7E BODY MEAN',round(sum(px)/len(px),1),flush=True)
                if '--body-preview' in sys.argv:return
        if '--body-only' in sys.argv:return
        for task,n,cell in [('glas_wave',8,(256,256)),('lightning',4,(128,768)),('steam_jet',8,(384,64)),('bolt',6,(64,64))]:
            if '--only-effects' in sys.argv and task not in sys.argv[sys.argv.index('--only-effects')+1].split(','):continue
            root,pose=effect(task);render_sheet(task,root,pose,n,['s'],cell,tmp)
    resources()
    print('C7E BUILD PASS',flush=True)

if __name__=='__main__':main()
