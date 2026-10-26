"""UXMB: front orthographic UI icons, shared two-tone cel, no auxiliary maps."""
from pathlib import Path
import sys, math
import subprocess
if "--finish" not in sys.argv:
    import bpy
else:
    from PIL import Image
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'art/tools/cel'))
if "--finish" not in sys.argv:
    import cel_style as cel
OUT = ROOT / 'game/assets/sprites/ui/menu'
OUT.mkdir(parents=True, exist_ok=True)

def material(name, color, ink=False):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    def linear(v):
        v=v/255; return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
    c=tuple(linear(v) for v in color)
    p.inputs['Base Color'].default_value=tuple(v/1.65 for v in c)+(1,)
    if ink:
        p.inputs['Emission Color'].default_value=c+(1,)
        p.inputs['Emission Strength'].default_value=1
    return m

def stroke(name, points, radius, z, mat):
    c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.resolution_u=1
    c.bevel_depth=radius; c.bevel_resolution=4; c.use_fill_caps=True
    s=c.splines.new('POLY'); s.points.add(len(points)-1)
    for p,(x,y) in zip(s.points,points): p.co=(x,y,z,1)
    o=bpy.data.objects.new(name,c); bpy.context.collection.objects.link(o); o.data.materials.append(mat)
    for x,y in (points[0],points[-1]):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,radius=radius,location=(x,y,z))
        bpy.context.object.data.materials.append(mat)

def panel(name,x0,x1,y0,y1,r,z,mat):
    pts=[]
    for cx,cy,start in [(x1-r,y1-r,0),(x0+r,y1-r,90),(x0+r,y0+r,180),(x1-r,y0+r,270)]:
        for i in range(9):
            a=math.radians(start+i*90/8); pts.append((cx+r*math.cos(a),cy+r*math.sin(a),z))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(pts,[],[list(range(len(pts)))])
    ob=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(ob); mesh.materials.append(mat)

def render(kind,size):
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    scene=bpy.context.scene; cel.setup_scene(samples=8)
    scene.render.resolution_x=scene.render.resolution_y=size*2; scene.render.resolution_percentage=100
    scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
    scene.world.color=(.18,.18,.18)
    bpy.ops.object.camera_add(location=(0,0,200)); cam=bpy.context.object
    cam.data.type='ORTHO'; cam.data.ortho_scale=size; scene.camera=cam
    bpy.ops.object.light_add(type='SUN',location=(-40,30,100)); bpy.context.object.data.energy=3
    white=material(kind+' white',(232,238,248) if kind=='lock' else (255,255,255))
    ink=material(kind+' ink',(24,18,16),True)
    if kind=='lock':
        pts=[(-21,0),(-21,15)]+[(21*math.cos(math.pi-i*math.pi/32),15+19*math.sin(math.pi-i*math.pi/32)) for i in range(33)]+[(21,0)]
        stroke('shackle outline',pts,6,0,ink); stroke('shackle',pts,4,2,white)
        panel('body outline',-33,33,-40,8,5,9,ink)
        panel('body',-31,31,-38,6,3,10,white)
        stroke('keyhole',[(0,-12),(0,-23)],2.6,11,ink)
    else:
        pts=[(-19,0),(-5,-13),(19,15)]
        stroke('check outline',pts,6,0,ink); stroke('check',pts,4.5,3,white)
    for ob in scene.objects:
        if ob.type in {'MESH','CURVE'}:
            ob.scale.x *= .88; ob.scale.y *= .88
            ob.location.x *= .88; ob.location.y *= .88
    cel.install('ui',normals=False); cel.toon_materials('ui')
    target=OUT / ('icon_'+kind+'.png')
    scene.render.filepath=str(target); bpy.ops.render.render(write_still=True)

if '--finish' not in sys.argv:
    render('lock',96)
    render('check',64)
    subprocess.run([r'C:\Users\const\AppData\Local\Python\pythoncore-3.15-64\python.exe',str(Path(__file__).resolve()),'--finish'],check=True)
    sys.exit(0)
for kind,size in [('lock',96),('check',64)]:
    target=OUT / ('icon_'+kind+'.png')
    with Image.open(target) as im:
        im.convert('RGBA').resize((size,size),Image.Resampling.LANCZOS).save(target,optimize=True,compress_level=9)
    with Image.open(target) as im:
        assert im.mode=='RGBA' and im.size==(size,size)
        b=im.getbbox(); assert b and min(b[0],b[1],size-b[2],size-b[3]) >= (8 if kind=='lock' else 6),b

# Pillow assembles only: every colored panel is a solid background image.
contact=Image.new('RGB',(240,120))
for col,bg in enumerate(('#2B3340','#C23B12','#1c1f26')):
    panel_im=Image.new('RGB',(80,120),bg)
    for row,name in enumerate(('lock','check')):
        with Image.open(OUT / ('icon_'+name+'.png')) as im:
            small=im.resize((40,40),Image.Resampling.LANCZOS)
            panel_im.paste(small,(20,10+60*row),small)
    contact.paste(panel_im,(80*col,0))
contact.save(Path(__file__).with_name('_uxmb_contact.png'),optimize=True)
print('PASS UXMB: 96x96, 64x64 RGBA; contact 40px; no auxiliary maps')

