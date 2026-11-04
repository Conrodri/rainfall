"""M3: Rictus separate assets. Blender background; reuse approved I2 studio and C0 passes."""
import sys, math, random, json, hashlib
from pathlib import Path
import bpy
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/ui'))
import i2_build as ui
sys.path.insert(0,str(ROOT/'art/tools/iso'))
import iso_rig as iso
from PIL import Image
OUT=ROOT/'art/tools/night/m3_raw';OUT.mkdir(exist_ok=True)
DEST=ROOT/'game/assets/sprites/characters/rictus'
NAMES=['dagues_demi_lune','eventail','toupie','doublures']
DIRS=['e','se','s','sw','w','nw','n','ne']

def clear():
    for o in list(bpy.context.scene.objects):
        if o.type not in {'CAMERA','LIGHT'}:bpy.data.objects.remove(o,do_unlink=True)

def palette():
    ui.palette()
    ui.accent=ui.mat('#73968F',.32,.25,'#9FC8C0',2.8)
    global silver,porcelain,wood,iron,glow
    silver=ui.surface('rain tarnished silver','#344847','#9FAEAB',1,.4)
    porcelain=ui.surface('cracked dirty porcelain','#655E52','#B7AA97',0,.62)
    wood=ui.surface('rain swollen walnut','#160F0D','#50382A',0,.67)
    iron=ui.surface('black iron ferrules','#191D20','#626C70',1,.46)
    glow=ui.accent

def mesh(name,v,f,m,bevel=.008):
    me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(o);o.data.materials.append(m)
    if bevel:
        b=o.modifiers.new('worn bevel','BEVEL');b.width=bevel;b.segments=3
        o.modifiers.new('weighted normals','WEIGHTED_NORMAL')
    return o

def dagger():
    # Narrow wood blade enclosed by real forged edge strips, matching Rictus' daggers.
    ui.slab([(-.07,-.25),(-.09,.25),(-.035,.55),(.045,.72),(.09,.24),(.07,-.25)],wood,.09,0,.014)
    ui.slab([(.04,.69),(.09,.24),(.07,-.25),(.043,-.25),(.06,.24)],silver,.025,-.058,.006)
    ui.slab([(-.07,-.25),(-.09,.25),(-.035,.55),(-.057,.24),(-.042,-.25)],iron,.028,-.053,.006)
    ui.rod((-.19,0,-.27),(.19,0,-.27),.032,iron)
    ui.leather_grip(0,-.46,.32)
    ui.sphere((0,0,-.65),(.065,.058,.05),iron)
    for z in [-.37,-.44,-.51]:ui.rod((-.06,-.065,z),(.06,-.065,z+.025),.008,silver)
    for z in [-.17,.04,.22]:ui.bead(0,z,.016,-.06,iron)

def ribbon(radius,a,b,width,mat,z=.025,seed=0):
    rng=random.Random(seed);v=[];n=max(12,int(abs(b-a)*35))
    for j in range(n+1):
        t=j/n;ang=a+(b-a)*t;w=width*(math.sin(math.pi*t)**.65)*(.85+.15*rng.random())+.001
        for rr in [radius-w,radius]:v.append((rr*math.cos(ang),rr*math.sin(ang),z+.008*math.sin(j*.7)))
    return mesh('tapered spectral knife wake',v,[(2*j,2*j+1,2*j+3,2*j+2) for j in range(n)],mat,0)

def render(path,size,rig='CREA',target=(0,0,0),passes=True):
    s=iso.create_rig(rig,size,target=target,reset=False)
    s.camera.data.shift_y=0;s.eevee.taa_render_samples=12
    s.view_layers[0].use_pass_normal=True;s.view_layers[0].use_pass_emit=True
    s.render.threads_mode='FIXED';s.render.threads=8
    iso.render_frame(path,passes=passes)

def atlas(name,rows,size,anims=None):
    dest=DEST/name;dest.mkdir(exist_ok=True)
    for sheet,grid in rows.items():
        for suffix in ['','_e']:
            if not any(p.with_name(p.stem+suffix+'.png').exists() for row in grid for p in row):continue
            canvas=Image.new('RGBA',(len(grid[0])*size,len(grid)*size))
            for y,row in enumerate(grid):
                for x,p in enumerate(row):
                    q=p.with_name(p.stem+suffix+'.png')
                    if q.exists():canvas.paste(Image.open(q).convert('RGBA'),(x*size,y*size))
            canvas.save(dest/(sheet+suffix+'.png'),compress_level=9)
    resource=dest/(name+'.tres')
    if resource.exists():return # Existing contracts always take priority.
    anims=anims or [('default',next(iter(rows)),0,len(next(iter(rows.values()))[0]),False)]
    ex=[];subs=[];animations=[]
    for sheet in rows:
        for suffix in ['','_e']:
            p=dest/(sheet+suffix+'.png')
            if p.exists():ex.append(f'[ext_resource type="Texture2D" path="res://{p.relative_to(ROOT/"game").as_posix()}" id="{sheet+suffix}"]')
        subs.append(f'[sub_resource type="CanvasTexture" id="c_{sheet}"]\ndiffuse_texture = ExtResource("{sheet}")')
    for anim,sheet,row,count,loop in anims:
        frames=[]
        for i in range(count):
            ident=f'{anim}_{i}'
            subs.append(f'[sub_resource type="AtlasTexture" id="{ident}"]\natlas = SubResource("c_{sheet}")\nregion = Rect2({i*size}, {row*size}, {size}, {size})')
            frames.append('{"duration": 1.0, "texture": SubResource("'+ident+'")}')
        animations.append('{"frames": ['+', '.join(frames)+f'], "loop": {str(loop).lower()}, "name": &"{anim}", "speed": 16.0'+'}')
    resource.write_text('[gd_resource type="SpriteFrames" load_steps='+str(len(ex)+len(subs)+1)+' format=3]\n\n'+'\n\n'.join(ex+subs)+'\n\n[resource]\nanimations = ['+',\n'.join(animations)+']\n')
    # Parallel emission SpriteFrames use the same atlas rectangles, compatible with EmissiveOverlay.
    content=resource.read_text()
    for sheet in rows:content=content.replace(f'diffuse_texture = ExtResource("{sheet}")',f'diffuse_texture = ExtResource("{sheet}_e")')
    if all((dest/(sheet+'_e.png')).exists() for sheet in rows):(dest/(name+'_emission.tres')).write_text(content)

def cache_head():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/rictus.blend'))
    head=next(o for o in bpy.context.scene.objects if o.name.startswith('Tilted porcelain head'))
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();cache=[]
    for o in head.children_recursive:
        if o.type not in {'MESH','CURVE'}:continue
        me=bpy.data.meshes.new_from_object(o.evaluated_get(deps));me.use_fake_user=True
        cache.append((me,head.matrix_world.inverted()@o.matrix_world))
    return cache

def icons():
    heads=cache_head()
    for name in NAMES:
        s=ui.studio('m3_'+name);palette();ui.spell('m3_backing')
        if name=='dagues_demi_lune':
            for x,a in [(-.24,-.65),(.24,.65)]:ui.group(dagger,loc=(x,-.17,.04),scale=.7,rot=(0,a,0))
            ui.curve([(.62*math.cos(t),-.27,.62*math.sin(t)) for t in [i*math.pi/40 for i in range(41)]],.016,glow)
        elif name=='eventail':
            for a in [-.85,-.43,0,.43,.85]:ui.group(dagger,loc=(0,-.19,-.03),scale=.74,rot=(0,a,0),pivot=(0,0,-.62))
        elif name=='toupie':
            # Museum spinning top: conical turned wood, silver hoops, taut controller strings.
            profile=[(-.66,.012),(-.52,.08),(-.25,.29),(.05,.43),(.18,.43),(.24,.35),(.25,.06)]
            v=[(r*math.cos(i*math.tau/48),-.22+r*math.sin(i*math.tau/48),z) for z,r in profile for i in range(48)]
            faces=[(j*48+i,j*48+(i+1)%48,(j+1)*48+(i+1)%48,(j+1)*48+i) for j in range(len(profile)-1) for i in range(48)]
            top=mesh('turned rain worn walnut spinning top',v,faces,wood,.008)
            for poly in top.data.polygons:poly.use_smooth=True
            for z,r in [(.18,.43),(-.05,.39),(-.25,.29)]:
                o=ui.torus((0,-.22,z),r,.021,silver);o.rotation_euler.x=0
            ui.rod((0,-.18,.15),(0,-.18,.57),.045,iron)
            for x in [-.32,.32]:ui.rod((x,-.12,.6),(0,-.22,.31),.008,glow)
            ui.curve([(.62*math.cos(t),-.12,.22*math.sin(t)-.12) for t in [i*math.tau/64 for i in range(56)]],.018,glow)
        else:
            for x,z,k in [(-.42,-.03,.73),(0,.13,.92),(.42,-.03,.73)]:
                for me,local in heads:
                    o=bpy.data.objects.new('validated Rictus porcelain effigy',me);s.collection.objects.link(o)
                    o.matrix_world=Matrix.Translation((x,-.22,z))@Matrix.Rotation(-.16 if x==0 else x*.4,4,'Y')@Matrix.Scale(k*1.8,4)@local
                ui.rod((x,-.11,z+.29*k),(x*.7,-.12,.63),.008,glow)
            ui.rod((-.5,-.1,.64),(.5,-.1,.64),.032,wood)
            for i in range(6):
                a=math.tau*i/6;ui.jewel(.58*math.cos(a),-.06+.58*math.sin(a),glow,-.15,.025)
        s.camera.location=(.55,-10,1.9);ui.aim(s.camera,(0,0,0));s.camera.data.ortho_scale=2.05
        s.render.resolution_x=s.render.resolution_y=256;s.eevee.taa_render_samples=16
        s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
        dest=ROOT/'game/assets/sprites/icons/spells'/f'{name}.png'
        size=Image.open(dest).size if dest.exists() else (128,128)
        Image.open(s.render.filepath).resize(size,Image.Resampling.LANCZOS).save(dest,compress_level=9)
        print('M3_ICON',name,flush=True)

def sprites():
    s=ui.studio('m3_sprites');palette();clear()
    if '--arc-only' in sys.argv:
        arc();return
    # Slightly oscillating flying knife, fixed +X tip in screen space.
    knives()
    if '--knife-only' in sys.argv or '--knives-only' in sys.argv:return
    arc()
    paths=[]
    for f in range(4):
        clear()
        for j in range(7):
            a=f*math.pi/2+j*2.4
            ribbon(1.32-.045*(j%3),a,a+2.4,.028,glow,.16+j*.12,j)
        p=OUT/f'spin_{f}.png';render(p,288,target=(0,0,.48));paths.append(p)
    atlas('spin_blur',{'default':[paths]},288,[('default','default',0,4,True)])
    burst()

def knives():
    paths=[]
    for f in range(4):
        clear();ui.group(dagger,scale=.43,rot=(math.pi/2,0,math.pi/2))
        for o in ui.meshes():o.matrix_world=Matrix.Rotation(f*.47,4,'X')@o.matrix_world
        p=OUT/f'knife_{f}.png';render(p,64);paths.append(p)
    atlas('knife',{'default':[paths]},64)
    if '--knife-only' in sys.argv:return
    rows=[]
    for d in range(8):
        clear();ui.group(dagger,scale=.36,rot=(0,math.pi-.4,-d*math.pi/4))
        for o in ui.meshes():o.location.z+=.31
        p=OUT/f'planted_{d}.png';render(p,64,target=(0,0,.28));rows.append([p])
    atlas('knife_planted',{'default':rows},64,[(f'default_{d}','default',i,1,True) for i,d in enumerate(DIRS)])

def arc():
    paths=[]
    # Full 140 degree fan, 320 px radius at 128 px/u. Faceted blade volumes.
    for f in range(4):
        clear();strength=[1,.72,.40,.16][f]
        for j in range(11):
            a=math.radians(-68+j*13.6)+f*.018
            def pt(r,da,z):return (r*math.cos(a+da),r*math.sin(a+da),z)
            outer=2.49-.035*(j%3);inner=outer-(.89+.16*(j%2))*strength
            v=[pt(inner,-.18,.045),pt(outer-.13,-.065,.07),pt(outer,.012,.12),
               pt(outer-.32,.09,.16),pt(inner+.18,.12,.08),pt((inner+outer)/2,-.005,.42*strength+.08)]
            mesh('spectral swept dagger',v,[(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5),(4,3,2,1,0)],silver,0)
            # Broad angular wake, tapering toward the broken trailing edge.
            mesh('jagged raised blade wake',[pt(inner-.12,-.26,.04),pt(outer-.20,-.1,.09),pt(outer-.35,.055,.17),pt(inner+.17,.04,.21)],[(0,1,2),(0,2,3)],glow,0)
            ui.curve([pt(inner,-.18,.05),pt((inner+outer)/2,-.05,.28*strength+.08),pt(outer,.012,.12)],.019*strength,glow)
            # Shattered silver points remain inside the contractual floor radius.
            for k in range(2):
                rr=1.24+.37*k+.06*(j%3)
                mesh('broken silver shard',[pt(rr,-.12,.12),pt(rr+.17,-.09,.24),pt(rr+.05,-.04,.10)],[(0,1,2)],glow if k else silver,0)
            if j%2==0:ui.curve([pt(.9,-.08,.06),pt(1.27,-.04,.31),pt(1.39,-.09,.43)],.009*strength,glow)
        for o in bpy.context.scene.objects:
            if o.type not in {'LIGHT','CAMERA'}:
                o.scale *= [1,.84,.62,.35][f];o.location *= [1,.84,.62,.35][f]
        p=OUT/f'arc_{f}.png';render(p,672,'TOP');paths.append(p)
    atlas('dagger_arc',{'default':[paths]},672)

def burst():
    top=[];crea=[]
    for f in range(6):
        clear();t=f/5;rng=random.Random(306)
        # Frame zero carries the full blast; later frames scatter and fade.
        reach=.78-.24*t
        for j in range(46):
            a=rng.random()*math.tau;v=rng.uniform(.45,1.88);r=v*reach
            z=max(.025,(1-t)*rng.uniform(.22,.88)+rng.uniform(.02,.16))
            m=[wood,porcelain,iron,silver][j%4];k=rng.uniform(.025,.075)*(1-.42*t)
            o=ui.slab([(-k,-k*2),(k,-k),(k*.6,k*3),(-k*.5,k)],m,k*.8,0,k*.16)
            o.location=(r*math.cos(a),r*math.sin(a),z);o.rotation_euler=(j*.9,t*j,j)
        # Jagged raised shockwave, with separated peaks instead of a flat ring.
        for j in range(13):
            a=j*math.tau/13+.08;r=1.92*reach
            k=rng.uniform(.12,.24)
            if f<5:ui.curve([((r-k)*math.cos(a-.08),(r-k)*math.sin(a-.08),.05), (r*math.cos(a),r*math.sin(a),.36+.12*(j%3)),((r+k)*math.cos(a+.07),(r+k)*math.sin(a+.07),.04)],.018,glow)
        for j in range(11):
            a=rng.random()*math.tau;rr=rng.uniform(.65,1.82)*reach
            ui.curve([(rr*math.cos(a),rr*math.sin(a),.08),( (rr+.18)*math.cos(a+.07),(rr+.18)*math.sin(a+.07),.27)],.012,silver if j%2 else glow)
        # Hot splinters retain the silver emission accent at impact.
        for j in range(10):
            a=rng.random()*math.tau;rr=rng.uniform(.5,1.65)*reach
            ui.bead(rr*math.cos(a),rr*math.sin(a),.025,-.02,silver if j%3 else glow)
        p=OUT/f'burst_top_{f}.png';render(p,512,'TOP');top.append(p)
        p=OUT/f'burst_crea_{f}.png';render(p,384,target=(0,0,.25));crea.append(p)
    for p in crea:
        for suffix in ['','_e']:
            q=p.with_name(p.stem+suffix+'.png')
            if q.exists():
                im=Image.open(q);canvas=Image.new('RGBA',(512,512));canvas.paste(im,(64,64));canvas.save(q,compress_level=9)
    atlas('double_burst',{'top':[top],'crea':[crea]},512,[('default','top',0,6,False),('default_top','top',0,6,False),('default_crea','crea',0,6,False)])

def portrait():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/rictus.blend'))
    s=bpy.context.scene;root=bpy.data.objects['Rictus']
    rig=next(o for o in root.children_recursive if o.type=='ARMATURE')
    rig.animation_data_clear();root.animation_data_clear();root.rotation_euler=(0,0,-.18)
    sys.path.insert(0,str(ROOT/'art/tools/characters'));import m2_build
    m2_build.pose('rictus',root,rig,'idle',0,8)
    bpy.context.view_layer.update()
    head=next(o for o in s.objects if o.name.startswith('Tilted porcelain head'))
    bounds=[o.matrix_world@Vector(v) for o in head.children_recursive if o.type=='MESH' for v in o.bound_box]
    low=min(v.z for v in bounds);high=max(v.z for v in bounds);height=high-low
    target=head.matrix_world.translation.copy();target.z=(low+high)/2-height*.2
    s=iso.create_rig('CREA',256,target=target,reset=False)
    s.camera.location=target+Vector((.08,-4,1.0));ui.aim(s.camera,target);s.camera.data.ortho_scale=height*1.65;s.camera.data.shift_y=0
    s.eevee.taa_render_samples=16
    p=OUT/'portrait.png';iso.render_frame(p)
    dest=ROOT/'game/assets/sprites/ui/portraits/rictus.png';dest.parent.mkdir(exist_ok=True,parents=True)
    size=Image.open(dest).size if dest.exists() else (256,256)
    Image.open(p).resize(size,Image.Resampling.LANCZOS).save(dest,compress_level=9)
    print('M3_PORTRAIT_PASS',flush=True)

if __name__=='__main__':
    mode=sys.argv[-1]
    if mode=='icons':icons()
    elif mode=='portrait':portrait()
    elif mode=='rictus_vfx':
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/rictus.blend'))
        s=ui.studio('m3_sprites');palette();clear();arc();burst()
        print('RICTUS_VFX_PASS',flush=True)
    else:sprites()
