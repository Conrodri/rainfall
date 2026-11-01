"""Flat ritual decal; MAP 35 degrees, compensated 2:1 footprint. No normal exports."""
import bpy, math, sys, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
import iso_rig as iso
import cel_style as cel
OUT=ROOT/'game/assets/sprites/props/pillar_deflect'
OUT.mkdir(parents=True,exist_ok=True)
BLEND=ROOT/'art/blender/props/pillar_deflect_ring.blend'
BLEND.parent.mkdir(parents=True,exist_ok=True)
s=iso.create_rig('MAP',(192,96))
s.camera.rotation_euler=(math.radians(55),0,math.pi/4)
s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,0,12))
s.eevee.taa_render_samples=16
s.render.image_settings.compression=100
s.render.dither_intensity=0
s.camera.data.ortho_scale*=192/186
bpy.context.preferences.filepaths.save_version=0
random.seed(29)
bronze=iso.material('blackened bronze',(.115,.083,.045),.65,.65)
edge=iso.material('worn brass edges',(.27,.215,.125),.6,.6)
stone=iso.material('inlaid charcoal stone',(.065,.078,.082),0,.9)
patina=iso.material('muted verdigris',(.085,.155,.132),.4,.8)
groove=iso.material('engraved recess',(.021,.025,.028),.3,.8)
arc=iso.material('pale blue electrical arc',(.46,.73,.83),0,.5,emission=1)
arc['rainfall_emissive']=True
# Every surface is coplanar: no vertical geometry and no baked shadow.
def face(name,verts,mat):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([(x,y,0) for x,y in verts],[],[list(range(len(verts)))]);mesh.update()
    ob=bpy.data.objects.new(name,mesh);s.collection.objects.link(ob);ob.data.materials.append(mat);return ob
# Avoid coplanar overlap: nested disjoint bands and explicit gaps.
def band(name,r0,r1,a0,a1,mat,n=120):
    n=max(2,int(n*abs(a1-a0)/(2*math.pi)))
    pts=[(r*math.cos(a0+(a1-a0)*i/n),r*math.sin(a0+(a1-a0)*i/n)) for r,seq in [(r1,range(n+1)),(r0,range(n,-1,-1))] for i in seq]
    return face(name,pts,mat)
T=2*math.pi
band('stone inset border',.897,1.048,0,T,stone)
# Ring sits inside stone border, with an empty engraved channel.
band('outer bronze rim',.871,.897,0,T,edge)
band('outer bronze band',.824,.871,0,T,bronze)
band('inner bronze band',.735,.783,0,T,bronze)
band('inner worn rim',.719,.735,0,T,edge)
band('deep electrical groove',.786,.819,0,T,groove)
# Broken arc runs in the channel, separated into jagged segments.
for j,(a,b) in enumerate([(0.12,1.48),(1.62,2.58),(2.72,4.07),(4.27,5.98)]):
    pts=[]
    count=38
    for i in range(count+1):
        t=a+(b-a)*i/count;r=.802+random.uniform(-.006,.006)
        pts.append((t,r))
    verts=[((r+d)*math.cos(t),(r+d)*math.sin(t)) for d,seq in [(.006,pts),(-.006,pts[::-1])] for t,r in seq]
    face('electrical arc '+str(j),verts,arc)
# Four inward-pointing engraved chevrons in the open interior.
for j in range(4):
    a=math.pi/4+j*math.pi/2
    shape=[(-.105,.64),(0,.52),(.105,.64),(.075,.665),(0,.585),(-.075,.665)]
    face('ritual chevron '+str(j),[(x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a)) for x,y in shape],edge)
# Broken flat chain links distributed inside the circle silhouette.
for j,a in enumerate([.35,1.85,3.4,4.85,5.35]):
    cx,cy=.955*math.cos(a),.955*math.sin(a)
    for k in range(2):
        pts=[]
        for r,seq in [(1,range(19)),(.53,range(18,-1,-1))]:
            for q in seq:
                t=.28+(T-.65)*q/18
                x=.044*r*math.cos(t)+k*.045-.022;y=.022*r*math.sin(t)
                pts.append((cx+x*math.cos(a)-y*math.sin(a),cy+x*math.sin(a)+y*math.cos(a)))
        face('broken chain %s %s'%(j,k),pts,edge if k else bronze)
# Small interrupted patina / chips on inset stone, no procedural grain.
for j in range(28):
    a=random.random()*T;r=random.uniform(.916,1.021);w=random.uniform(.004,.012)
    band('weathering '+str(j),r,r+w,a,a+random.uniform(.012,.045),patina if j%3 else groove)
# Stone chips overlay replaced by slight depth-free render ordering would z-fight;
# use a material-index surface displacement smaller than a micron solely for ordering.
for ob in s.objects:
    if ob.type=='MESH':
        if ob.name.startswith(('broken chain','weathering')):
            for v in ob.data.vertices:v.co.z=.000001
        for v in ob.data.vertices:
            x,y=v.co.x,v.co.y;u=(x+y)/math.sqrt(2);d=(-x+y)/math.sqrt(2)*(.5/math.sin(math.radians(35)))
            v.co.x=(u-d)/math.sqrt(2);v.co.y=(u+d)/math.sqrt(2)
for ob in s.objects:
    if ob.type=='LIGHT':ob.data.use_shadow=False
cel.install('prop',normals=False)
path=OUT/'pillar_deflect_ring.png'
iso.common.configure_passes(path)
tree=s.compositing_node_group
for node in list(tree.nodes):
    if node.bl_idname=='CompositorNodeOutputFile':tree.nodes.remove(node)
s.render.filepath=str(path)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.render.render(write_still=True)
# Separate neutral emission mask; no tinted RGB and no normal pass.
s.compositing_node_group=None
for mat in bpy.data.materials:
    mat.use_nodes=True;n=mat.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission')
    e.inputs[0].default_value=(1,1,1,1) if mat==arc else (0,0,0,1)
    mat.node_tree.links.new(e.outputs[0],o.inputs['Surface'])
s.render.resolution_x=192;s.render.resolution_y=96
s.render.filepath=str(OUT/'pillar_deflect_ring_e.png');bpy.ops.render.render(write_still=True)
from PIL import Image
for p,size in [(path,(192,96)),(OUT/'pillar_deflect_ring_e.png',(96,48))]:
    with Image.open(p) as im:im.convert('RGBA').resize(size,Image.Resampling.HAMMING).save(p,optimize=True,compress_level=9)
print('PASS pillar_deflect_ring diffuse=192x96 emission=96x48 normals=False')



