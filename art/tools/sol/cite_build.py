"""Cite v2: emission-only Blender surfaces; sol_tools crop/blend and validation."""
import math, random, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'game/assets/sprites/terrain/rust_city/sol'
REND = ROOT/'art/renders/sol_v2/codex/cite'
BLEND = ROOT/'art/blender/sol/cite_sol.blend'
for p in (OUT, REND, BLEND.parent): p.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(Path(__file__).parent))
def finish():
    from sol_tools import make_seamless, verify, sheet3x3
    from PIL import Image
    import numpy as np
    for i in range(4):
        make_seamless(REND/f'base_{i}_raw.png',OUT/f'base_{i}.png',size=512)
        sheet3x3(OUT/f'base_{i}.png',REND/f'base_{i}_sheet3x3.png')
    Image.open(REND/'decals_raw.png').save(OUT/'decals.png',optimize=True)
    checks=[verify(OUT/f'base_{i}.png') for i in range(4)]
    a=np.asarray(Image.open(OUT/'decals.png'))
    cells=[a[y:y+128,x:x+128] for y in range(0,512,128) for x in range(0,512,128)]
    atlas_ok=all(c[:,:,3].max()>128 and not np.any(np.concatenate((c[:8,:,3].ravel(),c[-8:,:,3].ravel(),c[:,:8,3].ravel(),c[:,-8:,3].ravel()))) for c in cells) and len({c.tobytes() for c in cells})==16
    ok=all(c['ok_size'] and c['mode']=='RGB' and c['kb']<=450 and c['seam_ratio']<2.5 and 8<=c['std']<=28 for c in checks) and atlas_ok
    sheet=Image.new('RGB',(1024,768),(39,42,47))
    for i in range(4):
        im=Image.open(REND/f'base_{i}_sheet3x3.png'); im.thumbnail((384,384)); sheet.paste(im,((i%2)*384,(i//2)*384))
    atlas=Image.open(OUT/'decals.png'); atlas.thumbnail((256,256)); sheet.paste(atlas,(768,256),atlas)
    sheet.save(REND/'contact.png')
    (REND/'verification.txt').write_text('\n'.join(str(c) for c in checks)+'\natlas='+str(atlas_ok)+'\n'+('PASS' if ok else 'FAIL'),encoding='utf8')
    print('CITE '+('PASS' if ok else 'FAIL'))
if '--finish' in sys.argv:
    finish(); sys.exit(0)
import bpy
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
sc=bpy.context.scene
sc.render.engine='BLENDER_EEVEE'; sc.eevee.taa_render_samples=32
sc.render.resolution_percentage=100
sc.render.image_settings.file_format='PNG'
sc.view_settings.view_transform='Standard'; sc.view_settings.look='None'
sc.world.color=(0,0,0)
bpy.ops.object.camera_add(location=(0,0,12))
cam=bpy.context.object; cam.data.type='ORTHO'; cam.data.ortho_scale=8; sc.camera=cam
def rgb(c):
    return tuple(((x/255)/12.92 if x/255<=.04045 else ((x/255+.055)/1.055)**2.4) for x in c)+(1,)
def material(name):
    m=bpy.data.materials.new(name); m.use_nodes=True
    n=m.node_tree.nodes; n.clear(); l=m.node_tree.links
    def node(t): return n.new('ShaderNode'+t)
    def wire(a,b): l.new(a,b)
    def mathn(op,a,b=None):
        q=node('Math'); q.operation=op
        for i,v in enumerate((a,b)):
            if v is None: continue
            if isinstance(v,(float,int)): q.inputs[i].default_value=v
            else: wire(v,q.inputs[i])
        return q.outputs[0]
    tc=node('TexCoord')
    out=node('OutputMaterial'); em=node('Emission'); wire(em.outputs[0],out.inputs['Surface'])
    return m,node,wire,mathn,tc,em,out
def base(idx):
    m,node,wire,f,tc,em,out=material('Cite '+str(idx)+' emission height')
    def noise(scale,vec):
        q=node('TexNoise'); q.inputs['Scale'].default_value=scale; q.inputs['Detail'].default_value=1 if idx==2 else 3; q.inputs['Roughness'].default_value=.72; wire(vec,q.inputs['Vector']); return q
    uv=tc.outputs['Generated']; warp=noise(5.7,uv)
    vs=node('VectorMath'); vs.operation='SCALE'; wire(warp.outputs['Color'],vs.inputs[0]); vs.inputs[3].default_value=.07
    add=node('VectorMath'); add.operation='ADD'; wire(uv,add.inputs[0]); wire(vs.outputs[0],add.inputs[1]); v=add.outputs[0]
    body=noise([32,24,22,33][idx],v).outputs['Fac']
    fine=noise([220,180,310,160][idx],v).outputs['Fac']
    vor=[]
    for scale in (17,57):
        q=node('TexVoronoi'); q.feature='DISTANCE_TO_EDGE'; q.inputs['Scale'].default_value=scale; q.inputs['Randomness'].default_value=1; wire(v,q.inputs['Vector']); vor.append(q.outputs['Distance'])
    micro=.035 if idx==2 else .2
    h=f('ADD',f('MULTIPLY',body,1-micro),f('MULTIPLY',fine,micro))
    if idx==0:
        # Broken hairline fissures, gated to avoid a continuous polygon network.
        cracks=f('MULTIPLY',f('LESS_THAN',vor[0],.018),f('GREATER_THAN',noise(13,v).outputs['Fac'],.53))
        h=f('SUBTRACT',h,f('MULTIPLY',cracks,.18))
    elif idx==3:
        chips=f('GREATER_THAN',vor[1],.16)
        h=f('ADD',f('MULTIPLY',h,.86),f('MULTIPLY',chips,.2))
    ramp=node('ValToRGB'); ramp.color_ramp.interpolation='EASE'
    palettes=[[(31,36,44),(67,70,73),(106,105,98)],[(37,34,34),(73,64,57),(111,91,70)],[(15,21,28),(39,47,55),(77,83,85)],[(22,25,31),(48,51,55),(105,101,91)]]
    span=[.16,.26,.21,.26][idx]
    r=ramp.color_ramp; r.elements[0].position=.5-span; r.elements[0].color=rgb(palettes[idx][0]); r.elements[1].position=.5+span; r.elements[1].color=rgb(palettes[idx][2]); r.elements.new(.5).color=rgb(palettes[idx][1]); wire(h,ramp.inputs[0])
    col=ramp.outputs[0]
    if idx in (0,1):
        rust=noise(37 if idx==0 else 16,v).outputs['Fac']
        mask=f('MULTIPLY',f('MAXIMUM',f('SUBTRACT',rust,.63 if idx==0 else .48),0),1.6)
        mix=node('MixRGB'); wire(mask,mix.inputs[0]); wire(col,mix.inputs[1]); mix.inputs[2].default_value=rgb((103,58,33)); col=mix.outputs[0]
    wire(col,em.inputs['Color']); return m
bpy.ops.mesh.primitive_plane_add(size=8); floor=bpy.context.object; floor.name='continuous poured surface'
sc.render.resolution_x=sc.render.resolution_y=1024
sc.render.image_settings.color_mode='RGB'
for idx in range(4):
    floor.data.materials.clear(); floor.data.materials.append(base(idx))
    raw=REND/f'base_{idx}_raw.png'; sc.render.filepath=str(raw); bpy.ops.render.render(write_still=True)
floor.hide_render=True
random.seed(7319)
def solid(name,color):
    m,node,wire,f,tc,em,out=material(name); em.inputs['Color'].default_value=rgb(color); return m
metal=solid('cold worn metal',(104,114,119)); edge=solid('raised metal lip',(136,139,130)); dark=solid('soot in recess',(28,34,40)); rust=solid('oxide metal',(103,59,36))
def mesh(name,verts,mat,z=.03):
    me=bpy.data.meshes.new(name); me.from_pydata([(x,y,z) for x,y in verts],[],[list(range(len(verts)))]); me.update()
    ob=bpy.data.objects.new(name,me); sc.collection.objects.link(ob); ob.data.materials.append(mat); return ob
def line(name,pts,width,mat):
    cu=bpy.data.curves.new(name,'CURVE'); cu.dimensions='3D'; cu.bevel_depth=width; cu.bevel_resolution=2
    sp=cu.splines.new('POLY'); sp.points.add(len(pts)-1)
    for p,(x,y) in zip(sp.points,pts): p.co=(x,y,.065,1)
    ob=bpy.data.objects.new(name,cu); sc.collection.objects.link(ob); ob.data.materials.append(mat)
def disc(x,y,r,mat,sides=6):
    return mesh('fastener',[(x+r*math.cos(i*2*math.pi/sides+.31),y+r*math.sin(i*2*math.pi/sides+.31)) for i in range(sides)],mat,.08)
def stain(i,cx,cy,kind):
    m,node,wire,f,tc,em,out=material('soft alpha '+str(i))
    sep=node('SeparateXYZ'); wire(tc.outputs['Generated'],sep.inputs[0])
    x=f('SUBTRACT',sep.outputs['X'],.5); y=f('SUBTRACT',sep.outputs['Y'],.5)
    # Rotated eccentric shapes, never image-aligned streaks.
    a=.37+i*.47
    xx=f('ADD',f('MULTIPLY',x,math.cos(a)),f('MULTIPLY',y,math.sin(a)))
    yy=f('SUBTRACT',f('MULTIPLY',y,math.cos(a)),f('MULTIPLY',x,math.sin(a)))
    d=f('ADD',f('MULTIPLY',f('MULTIPLY',xx,xx),24 if kind==1 else 4),f('MULTIPLY',f('MULTIPLY',yy,yy),2.5 if kind==1 else 6))
    no=node('TexNoise'); no.inputs['Scale'].default_value=7+i*.19; no.inputs['Detail'].default_value=2; wire(tc.outputs['Generated'],no.inputs['Vector'])
    mask=f('MULTIPLY',f('SUBTRACT',.75,f('ADD',d,f('MULTIPLY',no.outputs['Fac'],.3))),8)
    clamp=node('Clamp'); wire(mask,clamp.inputs[0])
    ramp=node('ValToRGB'); wire(no.outputs['Fac'],ramp.inputs[0])
    colors=([(19,37,48),(63,59,87),(49,93,88)] if kind==0 else [(57,32,25),(110,58,31),(131,83,46)])
    ramp.color_ramp.elements[0].color=rgb(colors[0]); ramp.color_ramp.elements[1].color=rgb(colors[2]); ramp.color_ramp.elements.new(.52).color=rgb(colors[1]); wire(ramp.outputs[0],em.inputs['Color'])
    tr=node('BsdfTransparent'); mix=node('MixShader'); wire(clamp.outputs[0],mix.inputs[0]); wire(tr.outputs[0],mix.inputs[1]); wire(em.outputs[0],mix.inputs[2]); wire(mix.outputs[0],out.inputs['Surface'])
    mesh('stain '+str(i),[(cx-.83,cy-.83),(cx+.83,cy-.83),(cx+.83,cy+.83),(cx-.83,cy+.83)],m,0)
for i in range(16):
    cx=-3+2*(i%4); cy=3-2*(i//4)
    if i<6: stain(i,cx,cy,0 if i<3 else 1)
    elif i<9:
        for k in range(i-3):
            x=cx+random.uniform(-.53,.53); y=cy+random.uniform(-.52,.52)
            disc(x,y,.10+random.random()*.04,rust); disc(x-.015,y+.015,.075,metal); disc(x,y,.033,dark)
    elif i<12:
        a=.29+(i-9)*.51
        def transform(x,y): return cx+x*math.cos(a)-y*math.sin(a),cy+x*math.sin(a)+y*math.cos(a)
        j=i-9
        poly=[(-.58+.06*j,-.31),(.36,-.39+.07*j),(.6-.05*j,-.13),(.48,.34-.09*j),(-.3+.08*j,.39),(-.61,.1)]
        mesh('bent plate '+str(i),[transform(x,y) for x,y in poly],rust)
        mesh('plate face '+str(i),[transform(x*.87,y*.8+.04) for x,y in poly],metal,.04)
        line('fold ridge',[transform(-.43,-.12),transform(.03,.12),transform(.48,.19)],.018,edge)
        for x,y in [(-.38,.22),(.38,-.2)]:
            xx,yy=transform(x,y); disc(xx,yy,.042,dark)
    elif i<14:
        for k in range(i-11):
            pts=[(cx-.65+1.3*t/30,cy+.27*math.sin(t/30*math.pi*2.2+k*.6)+k*.1-.18) for t in range(31)]
            line('cable sheath',pts,.037,dark); line('worn cable edge',[(x-.014,y+.014) for x,y in pts],.011,rust if k else metal)
    else:
        a=.39+(i-14)*.63
        def tr(x,y): return cx+x*math.cos(a)-y*math.sin(a),cy+x*math.sin(a)+y*math.cos(a)
        for x in [-.42,-.21,0,.21,.42]: line('grille bar',[tr(x,-.36),tr(x,.36)],.025,metal)
        for y in [-.36,.36]: line('grille frame',[tr(-.45,y),tr(.45,y)],.035,rust)
sc.render.film_transparent=True; sc.render.image_settings.color_mode='RGBA'
sc.render.resolution_x=sc.render.resolution_y=512
sc.render.filepath=str(REND/'decals_raw.png'); bpy.ops.render.render(write_still=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
import subprocess, shutil
subprocess.run([shutil.which('python'),str(Path(__file__).resolve()),'--finish'],check=True)

