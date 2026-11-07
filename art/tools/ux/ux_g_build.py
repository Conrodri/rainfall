import bpy, math, os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'game', 'assets', 'sprites', 'ui', 'icons', 'tags')
os.makedirs(OUT, exist_ok=True)
NAMES = ['tag_feu','tag_crit','tag_givre','tag_poison','tag_zone','tag_survie','tag_auto','tag_recharge']

def reset():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def mat():
    m=bpy.data.materials.new('Pale blue enamel'); m.diffuse_color=(.9,.94,1,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(.9,.94,1,1); p.inputs['Metallic'].default_value=0; p.inputs['Roughness'].default_value=.7; p.inputs['Emission Color'].default_value=(.9,.94,1,1); p.inputs['Emission Strength'].default_value=.7
    return m
M=mat()
def stroke(points, r=.22, cyclic=False):
    c=bpy.data.curves.new('icon stroke','CURVE'); c.dimensions='3D'; c.resolution_u=1; c.bevel_depth=r; c.bevel_resolution=1
    s=c.splines.new('POLY'); s.points.add(len(points)-1)
    for p,co in zip(s.points,points): p.co=(co[0],co[1],co[2] if len(co)>2 else .3,1)
    s.use_cyclic_u=cyclic; o=bpy.data.objects.new('Stroke',c); bpy.context.collection.objects.link(o); o.data.materials.append(M); return o
def poly(points):
    c=bpy.data.curves.new('filled icon silhouette','CURVE'); c.dimensions='2D'; c.fill_mode='BOTH'; c.resolution_u=1
    s=c.splines.new('POLY'); s.points.add(len(points)-1)
    for p,co in zip(s.points,points): p.co=(co[0],co[1],0,1)
    s.use_cyclic_u=True; o=bpy.data.objects.new('Filled silhouette',c); bpy.context.collection.objects.link(o); o.data.materials.append(M); return o
def circle(cx,cy,r,start=0,end=2*math.pi,n=48):
    return [(cx+r*math.cos(start+(end-start)*i/(n-1)),cy+r*math.sin(start+(end-start)*i/(n-1)),.3) for i in range(n)]
def render(name, build):
    reset(); global M; M=mat(); build()
    factor={'tag_crit':1.22,'tag_auto':1.22,'tag_recharge':1.58,'tag_zone':.72}.get(name,1.0)
    for obj in bpy.context.scene.objects: obj.scale.x*=factor; obj.scale.y*=factor
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.shade_smooth()
    sc=bpy.context.scene; sc.render.engine='BLENDER_EEVEE'; sc.eevee.taa_render_samples=16
    sc.render.resolution_x=48; sc.render.resolution_y=48; sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG'; sc.render.image_settings.color_mode='RGBA'; sc.render.film_transparent=True
    sc.view_settings.view_transform='Standard'; sc.view_settings.look='Medium High Contrast'; sc.view_settings.exposure=0; sc.view_settings.gamma=1
    if sc.camera is None:
        bpy.ops.object.camera_add(location=(0,0,10)); sc.camera=bpy.context.object
    sc.camera.data.type='ORTHO'; sc.camera.data.ortho_scale=4.6; sc.camera.location=(0,0,10); sc.camera.rotation_euler=(0,0,0)
    sc.world.color=(0,0,0)
    sc.render.filepath=os.path.join(OUT,name+'.png'); bpy.ops.render.render(write_still=True)
def flame():
    poly([(-.12,-1.5),(-.78,-1.15),(-1.04,-.55),(-.94,-.08),(-1.22,.22),(-.82,.3),(-.67,.78),(-.38,1.08),(-.27,1.56),(.12,1.18),(.38,.82),(.58,1.03),(.87,.62),(1.04,.08),(.94,-.48),(.63,-1.04),(.12,-1.48)])
    poly([(-.08,-1.02),(-.44,-.68),(-.3,-.25),(-.08,.02),(.12,-.32),(.37,-.66),(.19,-1.02),(.02,-1.16)])
def crit():
    poly([(0,1.55),(.36,.36),(1.55,0),(.36,-.36),(0,-1.55),(-.36,-.36),(-1.55,0),(-.36,.36)])
def frost():
    for a in range(0,360,60):
        t=math.radians(a); u=(math.cos(t),math.sin(t)); v=(-u[1],u[0]); p=(0,0,.3); q=(u[0]*1.48,u[1]*1.48,.3); stroke([p,q],.23)
        for d in (.82,):
            x=u[0]*d; y=u[1]*d
            stroke([(x,y,.3),(x-u[0]*.28+v[0]*.25,y-u[1]*.28+v[1]*.25,.3)],.21)
            stroke([(x,y,.3),(x-u[0]*.28-v[0]*.25,y-u[1]*.28-v[1]*.25,.3)],.21)
def poison():
    poly([(0,1.45),(.34,.92),(.74,.35),(1.02,-.26),(.98,-.72),(.69,-1.12),(.32,-1.34),(0,-1.4),(-.32,-1.34),(-.69,-1.12),(-.98,-.72),(-1.02,-.26),(-.74,.35),(-.34,.92)])
    for x,y,r in [(-.27,-.22,.12),(.27,-.22,.12),(0,-.55,.1)]:
        poly(circle(x,y,r,n=20))
def zone():
    for r in (.42,.92,1.42): stroke(circle(0,0,r),.23,True)
def shield():
    poly([(0,1.5),(1.12,1.05),(1.02,.05),(.7,-.72),(0,-1.5),(-.7,-.72),(-1.02,.05),(-1.12,1.05)])
    stroke([(-.55,.05),(-.12,-.38),(.62,.48)],.24)
def auto():
    stroke(circle(0,0,1.12,math.radians(45),math.radians(330),48),.17)
    poly([(.5,1.55),(1.5,1.48),(1.08,.55)])
def hourglass():
    poly([(-.98,1.38),(.98,1.38),(.98,1.08),(.28,1.08),(.1,.72),(0,.28),(-.1,.72),(-.28,1.08),(-.98,1.08),(-.98,-1.08),(-.28,-1.08),(-.1,-.72),(0,-.28),(.1,-.72),(.28,-1.08),(.98,-1.08),(.98,-1.38),(-.98,-1.38)])
    poly([(-.2,-1.02),(.2,-1.02),(.08,-.78),(0,-.7),(-.08,-.78)])

def camera_light():
    bpy.ops.object.camera_add(location=(0,0,10)); cam=bpy.context.object; cam.rotation_euler=(0,0,0); bpy.context.scene.camera=cam
    bpy.ops.object.light_add(type='AREA', location=(-3,4,6)); bpy.context.object.data.energy=450; bpy.context.object.data.shape='DISK'; bpy.context.object.data.size=5
camera_light()
for n,b in zip(NAMES,[flame,crit,frost,poison,zone,shield,auto,hourglass]): render(n,b)
print('UXG_RENDER_OK 8')
