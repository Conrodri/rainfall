"""Rainfall rain assets. Run with Blender 5.2 --background --python rain.py."""
import bpy, math, json
from array import array
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/sprites/ambiance/rain'
RAW = ROOT / 'art/renders/ambiance'
BLEND = ROOT / 'art/blender/ambiance'
for p in (OUT, RAW, BLEND): p.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = False
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '8'
scene.render.use_file_extension = True
scene.render.use_compositing = False
scene.render.use_sequencer = False
scene.render.resolution_percentage = 100
scene.render.image_settings.compression = 25
scene.render.dither_intensity = 0
scene.render.use_stamp = False
scene.render.fps = 12
scene.render.fps_base = 1
scene.render.image_settings.color_management = 'FOLLOW_SCENE'
scene.render.use_overwrite = True
scene.render.use_placeholder = False
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.world.color = (0,0,0)
bpy.ops.object.camera_add(location=(0,0,10))
camera = bpy.context.object; camera.name = 'Rain_orthographic'; camera.data.type = 'ORTHO'
scene.camera = camera
bpy.ops.mesh.primitive_plane_add(size=2)
plane = bpy.context.object; plane.name = 'Procedural_rain_canvas'

class Graph:
    def __init__(self, name):
        self.mat = bpy.data.materials.new(name); self.mat.use_nodes = True
        self.n = self.mat.node_tree.nodes; self.n.clear(); self.l = self.mat.node_tree.links
        uv = self.n.new('ShaderNodeTexCoord')
        sep = self.n.new('ShaderNodeSeparateXYZ'); self.l.new(uv.outputs['UV'], sep.inputs[0])
        self.u, self.v = sep.outputs['X'], sep.outputs['Y']
    def put(self, socket, value):
        if isinstance(value, (float,int)): socket.default_value = value
        else: self.l.new(value, socket)
    def op(self, kind, a, b=0):
        n = self.n.new('ShaderNodeMath'); n.operation=kind
        self.put(n.inputs[0],a); self.put(n.inputs[1],b); return n.outputs[0]
    def add(self,a,b): return self.op('ADD',a,b)
    def sub(self,a,b): return self.op('SUBTRACT',a,b)
    def mul(self,a,b): return self.op('MULTIPLY',a,b)
    def div(self,a,b): return self.op('DIVIDE',a,b)
    def gauss(self,a,s): return self.op('EXPONENT',self.mul(self.op('POWER',self.div(a,s),2),-0.5))
    def finish(self,alpha,color=None):
        emission=self.n.new('ShaderNodeEmission'); emission.inputs[0].default_value=(1,1,1,1)
        if color is not None: self.l.new(color,emission.inputs[0])
        transparent=self.n.new('ShaderNodeBsdfTransparent')
        mix=self.n.new('ShaderNodeMixShader'); self.put(mix.inputs[0],alpha)
        self.l.new(transparent.outputs[0],mix.inputs[1]); self.l.new(emission.outputs[0],mix.inputs[2])
        out=self.n.new('ShaderNodeOutputMaterial'); self.l.new(mix.outputs[0],out.inputs[0])
        plane.data.materials.clear(); plane.data.materials.append(self.mat)

products=[]
def render(name,w,h,g):
    plane.scale=(w/h,1,1); camera.data.ortho_scale=2 * max(1,w/h)
    scene.render.resolution_x=w*2; scene.render.resolution_y=h*2; scene.render.resolution_percentage=100
    scene.render.filepath=str(RAW/(name+'_2x.png'))
    bpy.ops.render.render(write_still=True)
    im=bpy.data.images.load(scene.render.filepath,check_existing=False)
    im.scale(w,h)
    if name.startswith('drop_'):
        pixels=array('f',[0])*(w*h*4); im.pixels.foreach_get(pixels)
        peak=max(pixels[3::4])
        for j in range(3,len(pixels),4): pixels[j]=min(1,pixels[j]/peak)
        im.pixels.foreach_set(pixels)
    im.filepath_raw=str(OUT/(name+'.png')); im.file_format='PNG'; im.save()
    products.append((name,w,h)); bpy.data.images.remove(im)

sizes=[(16,64),(18,72),(20,80),(22,88),(24,96),(26,104),(30,116),(32,128)]
for i,(w,h) in enumerate(sizes):
    g=Graph('Drop_%02d'%i)
    y=g.mul(g.sub(g.v,.5),h); x=g.mul(g.sub(g.u,.5),w)
    cross=g.add(x,g.mul(y,math.tan(math.radians(12))))
    width=.40+i*.045
    core=g.gauss(cross,width); halo=g.mul(g.gauss(cross,width*2.3),.15)
    # Low end is the bright falling head; tail fades towards the upper end.
    t=g.div(g.add(y,h*.43),h*.86)
    bounds=g.mul(g.op('GREATER_THAN',t,0),g.op('LESS_THAN',t,1))
    tail=g.op('POWER',g.op('MAXIMUM',g.sub(1,t),0),.8)
    cap=g.sub(1,g.op('EXPONENT',g.mul(g.op('MAXIMUM',t,0),-65)))
    alpha=g.op('MINIMUM',g.mul(g.mul(g.add(core,halo),tail),g.mul(bounds,cap)),1)
    g.finish(alpha); render('drop_%02d'%i,w,h,g)

def coords(g,count):
    f=g.mul(g.u,count); frame=g.op('FLOOR',f)
    return g.sub(g.mul(g.op('FRACT',f),2),1), g.sub(g.mul(g.v,2),1), frame

def radius(g,x,y): return g.op('SQRT',g.add(g.mul(x,x),g.mul(y,y)))

for variant in range(3):
    g=Graph('Splash_'+chr(97+variant)); x,y,f=coords(g,6)
    t=g.div(g.add(f,.2),6)
    r=radius(g,x,g.div(y,.57))
    rr=g.add(.10,g.mul(t,.80))
    ring=g.mul(g.gauss(g.sub(r,rr),g.add(.012,g.mul(t,.008))),g.op('POWER',g.sub(1,t),1.1))
    alpha=ring
    for j in range(11+variant*2):
        angle=j*math.tau/(11+variant*2)+variant*.51
        travel=g.add(.10,g.mul(t,.65+ .18*math.sin(j*2.7+variant)))
        px=g.mul(travel,math.cos(angle))
        # Ballistic screen-space rise and fall, with a compressed ground ellipse.
        lift=g.mul(g.mul(t,g.sub(1,t)), .55+.2*math.sin(j*4.1))
        py=g.add(g.mul(travel,math.sin(angle)*.57),lift)
        d=radius(g,g.sub(x,px),g.div(g.sub(y,py),1.3))
        dot=g.mul(g.gauss(d,.018+.007*((j%3)/2)),g.mul(g.op('POWER',g.sub(1,t),.85),.95))
        alpha=g.op('MAXIMUM',alpha,dot)
    g.finish(alpha); render('splash_'+chr(97+variant),384,64,g)

for normal in (False,True):
    g=Graph('Ripple_normal' if normal else 'Ripple_alpha'); x,y,f=coords(g,8)
    t=g.div(g.add(f,.3),8); r=radius(g,x,g.div(y,.59))
    height=0
    for k in range(3):
        rr=g.sub(g.add(.10,g.mul(t,.88)),k*.125)
        valid=g.op('GREATER_THAN',rr,.025)
        ring=g.mul(g.gauss(g.sub(r,rr),.015),g.mul(valid,g.mul(g.op('POWER',g.sub(1,t),1.3),1-k*.22)))
        height=g.add(height,ring)
    if normal:
        bump=g.n.new('ShaderNodeBump'); bump.inputs['Distance'].default_value=.065
        g.l.new(height,bump.inputs['Height'])
        scale=g.n.new('ShaderNodeVectorMath'); scale.operation='SCALE'; g.l.new(bump.outputs['Normal'],scale.inputs[0]); scale.inputs[3].default_value=.5
        add=g.n.new('ShaderNodeVectorMath'); add.operation='ADD'; g.l.new(scale.outputs[0],add.inputs[0]); add.inputs[1].default_value=(128/255,128/255,.5)
        # Inverse sRGB inside the shader preserves data bytes under Standard.
        sep=g.n.new('ShaderNodeSeparateXYZ'); g.l.new(add.outputs[0],sep.inputs[0])
        combine=g.n.new('ShaderNodeCombineXYZ')
        for j in range(3):
            c=sep.outputs[j]
            linear=g.op('POWER',g.div(g.add(g.op('MAXIMUM',c,0),.055),1.055),2.4)
            g.l.new(linear,combine.inputs[j])
        g.finish(1,combine.outputs[0])
        scene.world.use_nodes=True
        scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.215861,.215861,1,1)
        scene.world.node_tree.nodes['Background'].inputs[1].default_value=1
        scene.render.film_transparent=False
    else: g.finish(height)
    render('ripple_n' if normal else 'ripple',512,64,g)
    scene.render.film_transparent=True
    scene.view_settings.view_transform='Standard'

# Preview is itself a Blender render of the delivered PNGs on a solid background.
plane.hide_render=True
def srgb(v): return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
bg=tuple(srgb(v/255) for v in (43,51,64))
scene.world.use_nodes=True; scene.world.node_tree.nodes['Background'].inputs[0].default_value=(*bg,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=1
scene.render.film_transparent=False
def card(name,cx,cy,w,h):
    bpy.ops.mesh.primitive_plane_add(size=2,location=(cx,cy,0)); ob=bpy.context.object; ob.name='Preview_'+name; ob.scale=(w/2,h/2,1)
    mat=bpy.data.materials.new('Preview_'+name); mat.use_nodes=True
    n=mat.node_tree.nodes; n.clear(); l=mat.node_tree.links
    tex=n.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(OUT/(name+'.png')),check_existing=True)
    em=n.new('ShaderNodeEmission'); l.new(tex.outputs['Color'],em.inputs[0])
    trans=n.new('ShaderNodeBsdfTransparent'); mix=n.new('ShaderNodeMixShader')
    l.new(tex.outputs['Alpha'],mix.inputs[0]); l.new(trans.outputs[0],mix.inputs[1]); l.new(em.outputs[0],mix.inputs[2])
    output=n.new('ShaderNodeOutputMaterial'); l.new(mix.outputs[0],output.inputs[0]); ob.data.materials.append(mat)
for i,(w,h) in enumerate(sizes): card('drop_%02d'%i,-4.5+i*1.25,2.5,w/64*1.5,h/64*1.5)
for i,name in enumerate(['splash_a','splash_b','splash_c','ripple','ripple_n']):
    card(name,0, .3-i*1.65, 9 if i<3 else 10, 1.5 if i<3 else 1.25)
camera.location=(0,-1.3,10); camera.data.ortho_scale=14
scene.render.resolution_x=3072; scene.render.resolution_y=2688
scene.render.filepath=str(RAW/'rain_preview_2x.png')
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND/'rain.blend'))
bpy.ops.render.render(write_still=True)
preview=bpy.data.images.load(scene.render.filepath,check_existing=False)
preview.scale(1536,1344); preview.filepath_raw=str(RAW/'rain_preview.png'); preview.save()
bpy.data.images.remove(preview)

report=[]
for name,w,h in products:
    path=OUT/(name+'.png'); im=bpy.data.images.load(str(path),check_existing=False)
    assert tuple(im.size)==(w,h),(name,tuple(im.size))
    assert im.channels==4,(name,im.channels)
    a=im.pixels[3::4]; lo,hi=min(a),max(a)
    assert hi>0,(name,'empty alpha')
    if name!='ripple_n': assert lo==0 and hi>0.05,(name,lo,hi)
    entry={'path':str(path.relative_to(ROOT)),'size':[w,h],'alpha_min':lo,'alpha_max':hi}
    if name=='ripple_n':
        im.colorspace_settings.name='Non-Color'
        neutral=[round(v*255) for v in im.pixels[:3]]
        assert neutral==[128,128,255],('normal background',neutral)
        entry['neutral_rgb']=neutral
    report.append(entry)
    bpy.data.images.remove(im)
    raw=bpy.data.images.load(str(RAW/(name+'_2x.png')),check_existing=False)
    assert tuple(raw.size)==(w*2,h*2) and raw.channels==4
    report.append({'path':str((RAW/(name+'_2x.png')).relative_to(ROOT)),'size':list(raw.size)})
    bpy.data.images.remove(raw)
im=bpy.data.images.load(str(RAW/'rain_preview.png'),check_existing=False)
assert tuple(im.size)==(1536,1344) and im.channels==4
report.append({'path':str((RAW/'rain_preview.png').relative_to(ROOT)),'size':list(im.size)})
raw=bpy.data.images.load(str(RAW/'rain_preview_2x.png'),check_existing=False)
assert tuple(raw.size)==(3072,2688) and raw.channels==4
report.append({'path':str((RAW/'rain_preview_2x.png').relative_to(ROOT)),'size':list(raw.size)})
(RAW/'rain_validation.json').write_text(json.dumps({'files':report,'errors':[]},indent=2))
print('RAINFALL_VALIDATED',json.dumps(report))
