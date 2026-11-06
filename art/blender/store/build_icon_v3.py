"""V3 store icon; reuse store construction helpers, read-only boss source."""
from pathlib import Path
import sys, math, random, shutil, json, hashlib
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent))
import build_store as old
W=old.WORK; random.seed(61126)
if not (W/'icon_v3a_backup.png').exists():shutil.copy2(W/'icon_master.png',W/'icon_v3a_backup.png')
root=old.load_boss();s=bpy.context.scene
for o in s.objects:
    if o.type in ('MESH','CURVE'):o.hide_render=o not in root.children_recursive
for o in root.children_recursive:
    if o.type in ('MESH','CURVE'):
        o.hide_render=any(k in o.name for k in ('induction arc','runoff','rivulet','Rain-polished'))
black=old.material('V3 blackened bronze',(.006,.008,.010),.18)
edge=old.material('V3 worn silver bronze',(.012,.018,.024),.18)
white=old.material('V3 white crystal',(.85,.97,1),.2,16)
for o in root.children_recursive:
    if o.type not in ('MESH','CURVE'):continue
    o.data.materials.clear()
    o.data.materials.append(white if any(k in o.name for k in ('Heart first','Crystal shaded')) else edge if any(k in o.name for k in ('arris','shackle','arm chain')) else black)
stone=old.material('V3 ruined basalt',(.025,.032,.040),.0)
silver=old.material('V3 cold stone edges',(.045,.060,.075),.0)
cyan=old.flat('V3 halo cyan',(.42,.86,1.3))
red=old.flat('V3 ember',(.85,.018,.007))
fg=[];bg=[]
def tube(name,pts,r,mat,group=fg):
    o=old.common.tube(name,pts,r,mat);group.append(o);return o
def mesh(name,vs,fs,mat,group=bg):
    o=old.mesh(name,vs,fs,mat);group.append(o);return o
def arc(name,cx,y,cz,rx,rz,a,b,r,mat,group=fg):
    return tube(name,[(cx+rx*math.cos(t),y,cz+rz*math.sin(t)) for t in [a+(b-a)*i/40 for i in range(41)]],r,mat,group)
# Carved basalt: rough mineral surface, block voussoirs and nested mouldings.
for mat in (stone,silver):
    ns=mat.node_tree.nodes; bs=next(n for n in ns if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Roughness'].default_value=.91
    noise=ns.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=19
    bump=ns.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.48;bump.inputs['Distance'].default_value=.055
    mat.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);mat.node_tree.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
def ogive(width,base,spring,peak,y):
    return [(-width,y,base),(-width,y,spring)]+[(-width*(1-t)**.70,y,spring+(peak-spring)*t) for t in [i/32 for i in range(1,33)]]+[(width*t**.70,y,peak-(peak-spring)*t) for t in [i/32 for i in range(1,33)]]+[(width,y,base)]
def masonry(name,pts,width,depth,mat):
    for a,b in zip(pts,pts[1:]):
        a,b=Vector(a),Vector(b);t=(b-a).normalized();n=Vector((t.z,0,-t.x));a+=t*.008;b-=t*.008
        vs=[tuple(c+n*width*u+Vector((0,depth*v,0))) for c in (a,b) for u,v in ((-1,-1),(1,-1),(1,1),(-1,1))]
        o=mesh(name,vs,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],mat,fg)
        bevel=o.modifiers.new('Eroded arris','BEVEL');bevel.width=.018;bevel.segments=2
for i in range(3):
    masonry('V3 carved ogival voussoir',ogive(2.10+i*.16,.08,3.55,5.64+i*.13,1.25+i*.07),.082,.15,stone if i!=1 else silver)
for side in (-1,1):
    for x in (2.02,2.20,2.38):
        tube('V3 basalt colonette',[(side*x,1.04,.12),(side*x,1.04,3.54)],.068,stone)
        for z in (.22,.40,3.36,3.51):
            o=old.common.box('V3 sculpted capital',(side*x,1.04,z),(.20,.29,.115),stone,bevel=.027);fg.append(o)
    for z in (.68,1.51,2.28,3.05):
        tube('V3 stone fracture',[(side*2.46,.98,z+.15),(side*2.31,.97,z+.07),(side*2.34,.97,z),(side*2.15,.97,z-.10)],.012,black)
    for j in range(7):
        t=(j+1)/9;x=side*(2.44*(1-t)**.70);z=3.55+2.37*t
        mesh('V3 carved acanthus crocket',[(x,1.24,z-.10),(x+side*.22,1.23,z+.03),(x+side*.25,1.25,z+.22),(x+side*.10,1.08,z+.14),(x,1.13,z+.17)],[(0,1,3),(1,2,3),(2,4,3),(4,0,3)],stone,fg)
for z,w in ((5.98,.13),(6.17,.085)):
    mesh('V3 stone finial',[(-w,1.25,z),(0,1.13,z+.26),(w,1.25,z),(0,1.4,z-.1)],[(0,1,2),(0,3,1),(1,3,2)],silver,fg)
# Thick stone rose, recessed foils; reads as the hood's cold aureole.
for r in (.72,.88):arc('V3 carved rose rim',0,1.6,4.62,r,r,0,math.tau,.068,stone)
for j in range(8):
    a=math.tau*j/8
    arc('V3 rose stone foil',.45*math.cos(a),1.56,4.62+.45*math.sin(a),.26,.26,0,math.tau,.045,silver)
    tube('V3 stone mullion',[(.18*math.cos(a),1.55,4.62+.18*math.sin(a)),(.81*math.cos(a),1.55,4.62+.81*math.sin(a))],.033,stone)
# Fractured aureole; interrupted arcs remain readable at small sizes.
for r in (.69,.83):
    for a,b in ((.08,1.35),(1.58,2.77),(3.03,4.33),(4.65,6.03)):
        arc('V3 broken halo',0,.55,3.96,r,r,a,b,.017 if r<.8 else .009,cyan)
# Fallen angel anatomy: bent humerus, elbow, wrist and overlapping feather fans.
feather=old.material('V3 charcoal flight feathers',(.024,.031,.042),.025)
cover=old.material('V3 soft covert feathers',(.037,.048,.060),.02)
def plume(name,start,end,width,mat,seed):
    rng=random.Random(seed);a=Vector(start);b=Vector(end);d=b-a
    n=Vector((-d.z,0,d.x)).normalized();vs=[]
    # Curved vanes, uneven barb notches and a fine pointed tip.
    for k in range(13):
        t=k/12;center=a+d*t+n*(math.sin(t*math.pi)*width*.32)
        center.y-=math.sin(t*math.pi)*.055
        w=width*(math.sin(math.pi*(t*.94+.035))**.75)*(1-t*.52)
        for sign in (-1,1):
            notch=.43 if k in (7+seed%3,10) and sign==(-1 if seed%2 else 1) else 1
            vs.append(tuple(center+n*sign*w*notch))
    vs.extend([tuple(b)])
    faces=[(2*k,2*k+1,2*k+3,2*k+2) for k in range(12)]+[(24,25,26)]
    o=mesh(name,vs,faces,mat,fg)
    tube('V3 tapered feather rachis',[tuple(a+d*t+n*(math.sin(t*math.pi)*width*.32)-Vector((0,.012,0))) for t in (0,.25,.5,.75,.91)],.005,edge)
    return o
for side in (-1,1):
    bones=[(side*.42,.73,3.24),(side*.98,.78,3.72),(side*1.22,.82,4.30),(side*2.04,.87,4.78)]
    tube('V3 wing humerus elbow wrist',bones,.065,black)
    tube('V3 cyan upper bone rim',[(x,y-.035,z+.035) for x,y,z in bones],.022,edge)
    # Secondaries spread in a rounded lower fan, rather than parallel slats.
    for j in range(8):
        t=j/7
        plume('V3 overlapping secondary',(side*(.62+.67*t),.78,3.47+.80*t),(side*(.87+1.03*t),.69,2.65+.54*t),.135,feather,j+20)
    # Long primaries radiate from wrist/phalanges; two torn gaps replaced by chain.
    for j in range(10):
        t=j/9;start=(side*(1.27+.75*t),.84,4.29+.47*t)
        end=(side*(1.52+1.10*t),.66,2.94+1.33*t)
        if j in ((3,7) if side<0 else (5,)):
            for k in range(9):
                f=k/9;x=start[0]+(end[0]-start[0])*f;z=start[2]+(end[2]-start[2])*f
                arc('V3 chain replacing missing primary',x,.70,z,.032 if k%2 else .051,.065,0,math.tau,.010,edge)
            continue
        plume('V3 torn long primary',start,end,.135,feather,40+j)
    # Shingled short coverts conceal the bases with organic overlapping rows.
    for row in range(3):
        for j in range(12):
            t=j/11;x=.62+1.40*t;z=3.47+1.28*t-row*.105
            plume('V3 layered short covert',(side*x,.60-row*.035,z),(side*(x+.09+.13*t),.54-row*.035,z-.27-.15*t),.073,cover,80+row*12+j)
    for j in range(3):
        x=side*(1.55+.34*j);z=2.52-.51*j
        plume('V3 falling torn feather',(x,.24,z),(x+side*(.16-.10*j),.20,z-.37),.067,feather,140+j)
# Lighting: cold behind shoulders, blood-red underneath, almost no frontal fill.
for o in s.objects:
    if o.type=='LIGHT':o.hide_render=True
s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.008,.014,.023,1)
s.world.node_tree.nodes['Background'].inputs[1].default_value=.12
def light(name,pos,target,power,color,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
light('V3 divine rim',(-.5,1.1,5.7),(0,0,3),300,(.70,.89,1),1.5)
light('V3 cold side rim',(2,.5,4.4),(0,0,3),220,(.54,.80,1),1.2)
light('V3 blood uplight',(0,-.45,.06),(0,.6,2.1),2600,(1,.012,.025),2.2)
light('V3 dim frontal fill',(-2,-4,4),(0,0,2.8),65,(.42,.58,.68),4)
light('V3 heart spill',(0,-1,2.8),(0,0,2.7),28,(.76,.94,1),.35)
light('V3 red rear flood',(0,1.15,.12),(0,1.3,3.0),2100,(1,.025,.012),2.6)
light('V3 white hood rim',(0,.8,4.9),(0,0,3.7),220,(.8,.94,1),.85)
ICON_SCALE=5.75
cam=old.camera((0,-12,3.10),(0,.3,2.80),ICON_SCALE)
# Background night, rendered planes of rays, diagonal rainfall and flooded floor.
for i in range(32):
    z=-2+i*.30;v=max(0,1-abs(z-4.8)/6)
    mat=old.flat('V3 night gradient',(.002+.010*v,.004+.028*v,.008+.046*v))
    mesh('V3 night', [(-9,4,z),(9,4,z),(9,4,z+.31),(-9,4,z+.31)],[(0,1,2,3)],mat)
# Smooth participating volumes: shafts originate above/behind the rose.
vol=bpy.data.materials.new('V3 soft rose light volume');vol.use_nodes=True
ns=vol.node_tree.nodes;ns.clear();links=vol.node_tree.links
out=ns.new('ShaderNodeOutputMaterial');v=ns.new('ShaderNodeVolumePrincipled')
v.inputs['Color'].default_value=(.57,.80,1,1);v.inputs['Anisotropy'].default_value=.25
v.inputs['Emission Color'].default_value=(.55,.84,1,1)
tex=ns.new('ShaderNodeTexCoord');sub=ns.new('ShaderNodeVectorMath');sub.operation='SUBTRACT';sub.inputs[1].default_value=(.5,.5,0)
links.new(tex.outputs['Generated'],sub.inputs[0])
mul=ns.new('ShaderNodeVectorMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=(1,1,0);links.new(sub.outputs['Vector'],mul.inputs[0])
length=ns.new('ShaderNodeVectorMath');length.operation='LENGTH';links.new(mul.outputs['Vector'],length.inputs[0])
rad=ns.new('ShaderNodeMapRange');rad.interpolation_type='SMOOTHERSTEP';rad.inputs['From Min'].default_value=.12;rad.inputs['From Max'].default_value=.50;rad.inputs['To Min'].default_value=1;rad.inputs['To Max'].default_value=0;links.new(length.outputs['Value'],rad.inputs['Value'])
sep=ns.new('ShaderNodeSeparateXYZ');links.new(tex.outputs['Generated'],sep.inputs[0])
fade=ns.new('ShaderNodeMapRange');fade.interpolation_type='SMOOTHERSTEP';fade.inputs['From Min'].default_value=.02;fade.inputs['From Max'].default_value=.48;links.new(sep.outputs['Z'],fade.inputs['Value'])
factor=ns.new('ShaderNodeMath');factor.operation='MULTIPLY';links.new(rad.outputs[0],factor.inputs[0]);links.new(fade.outputs[0],factor.inputs[1])
for socket,strength in (('Density',.055),('Emission Strength',.43)):
    gain=ns.new('ShaderNodeMath');gain.operation='MULTIPLY';gain.inputs[1].default_value=strength;links.new(factor.outputs[0],gain.inputs[0]);links.new(gain.outputs[0],v.inputs[socket])
links.new(v.outputs['Volume'],out.inputs['Volume'])
for j in range(7):
    a=Vector((-.42+j*.14,2.05,5.58));b=Vector((-2.65+j*.88,.10,1.40));d=a-b
    bpy.ops.mesh.primitive_cone_add(vertices=32,radius1=.32 if j%2 else .42,radius2=.055,depth=d.length,location=(a+b)/2)
    o=bpy.context.object;o.name='V3 descending rose volumetric ray';o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(vol);bg.append(o)
water=old.material('V3 black flood',(.035,.001,.003),.55, .12)
ns=water.node_tree.nodes;bs=next(n for n in ns if n.type=='BSDF_PRINCIPLED');bs.inputs['Roughness'].default_value=.19
pos=ns.new('ShaderNodeNewGeometry');stretch=ns.new('ShaderNodeVectorMath');stretch.operation='MULTIPLY';stretch.inputs[1].default_value=(1.4,12,1)
noise=ns.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=1.8;noise.inputs['Detail'].default_value=2
ramp=ns.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.33;ramp.color_ramp.elements[0].color=(.003,.00005,.0002,1);ramp.color_ramp.elements[1].position=.72;ramp.color_ramp.elements[1].color=(.12,.0005,.004,1)
water.node_tree.links.new(pos.outputs['Position'],stretch.inputs[0]);water.node_tree.links.new(stretch.outputs[0],noise.inputs['Vector']);water.node_tree.links.new(noise.outputs['Fac'],ramp.inputs[0]);water.node_tree.links.new(ramp.outputs[0],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=.85
mesh('V3 flooded floor',[(-100,-100,-.08),(100,-100,-.08),(100,4,-.08),(-100,4,-.08)],[(0,1,2,3)],water)
for i in range(32):
    z=i*.085;fade=(1-i/32)**1.8
    mat=old.flat('V3 blood mist',(.29*fade+.008,.005+.017*i/32,.014+.024*i/32))
    mesh('V3 rising blood glow',[(-6,2.4,z),(6,2.4,z),(6,2.4,z+.086),(-6,2.4,z+.086)],[(0,1,2,3)],mat)
for j in range(170):
    z=random.uniform(-.02,.018);x=random.uniform(-3,3);y=random.uniform(-14,2.6)
    w=random.uniform(.03,.33)*(1 if abs(x)>1.3 else .7)
    mat=old.flat('V3 red water reflection',(.08+random.random()*.26,.002,.008))
    mesh('V3 ember ripple',[(x-w,y,z),(x+w,y,z),(x+w*.8,y+.018,z),(x-w*.8,y+.018,z)],[(0,1,2,3)],mat)
for j in range(18):
    x=random.uniform(-2.2,2.2);y=random.uniform(-1.2,2.0);r=random.uniform(.06,.24)
    tube('V3 rain ring on black water',[(x+r*math.cos(t),y+r*math.sin(t),-.048) for t in [math.tau*k/32 for k in range(33)]],.0035,red,bg)
s.eevee.use_raytracing=True
for j in range(220):
    x=random.uniform(-4,4);z=random.uniform(-.2,7);y=random.choice((-.95,2.1))
    length=random.uniform(.055,.22);w=random.uniform(.002,.006)
    mat=old.flat('V3 lit raindrop',(.12,.25,.32) if z>2 else (.8,.016,.025))
    mesh('V3 diagonal rain',[(x,y,z),(x+w,y,z),(x+w+.045,y,z+length),(x+.045,y,z+length)],[(0,1,2,3)],mat)
for j in range(95):
    x=random.uniform(-2.25,2.25);z=random.uniform(.15,2.65);y=random.uniform(-.7,1.8);w=random.uniform(.008,.019)
    mesh('V3 rising blood ember',[(x-w,y,z),(x+w,y,z+.018),(x+.018,y,z+random.uniform(.035,.09))],[(0,1,2)],red)
for j in range(95):
    x=random.uniform(-1.4,1.4);z=random.uniform(2.5,4.9);y=1.88;w=random.uniform(.003,.010)
    mesh('V3 suspended lit dust',[(x-w,y,z),(x+w,y,z),(x,y,z+w*3)],[(0,1,2)],cyan)
fg.extend(o for o in root.children_recursive if o.type in ('MESH','CURVE') and not o.hide_render)
s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=24
s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8'
s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast'
old.base_compositor(None)
tree=s.compositing_node_group;output=next(n for n in tree.nodes if n.type=='GROUP_OUTPUT');sock=output.inputs['Image'].links[0].from_socket
g=tree.nodes.new('CompositorNodeGlare');g.inputs['Type'].default_value='Fog Glow';g.inputs['Quality'].default_value='Medium';g.inputs['Threshold'].default_value=1.1
tree.links.new(sock,g.inputs['Image']);tree.links.new(g.outputs['Image'],output.inputs['Image'])
def render(name,size,transparent=False):
    s.render.resolution_x=s.render.resolution_y=size;s.render.resolution_percentage=100
    s.render.film_transparent=transparent;s.render.filepath=str(W/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(W/'rain_sower_icon_v3.blend'))
render('icon_master',1024)
# Fit the complete adaptive subject to a conservative 124 px geometric radius.
for o in bg:o.hide_render=True
bpy.context.view_layer.update();inv=cam.matrix_world.inverted();pts=[]
deps=bpy.context.evaluated_depsgraph_get()
for o in fg:
    ob=o.evaluated_get(deps)
    if ob.type in ('MESH','CURVE'):
        me=ob.to_mesh();pts.extend(inv@(ob.matrix_world@v.co) for v in me.vertices);ob.to_mesh_clear()
radius=max(math.hypot(p.x,p.y) for p in pts)
cam.data.ortho_scale=2*radius*432/240
# No bloom on alpha: prevents invisible glow pixels from escaping the safe circle.
tree.links.new(sock,output.inputs['Image'])
render('icon_foreground_432',864,True)
for o in fg:o.hide_render=True
for o in bg:o.hide_render=False
tree.links.new(g.outputs['Image'],output.inputs['Image'])
cam.data.ortho_scale=ICON_SCALE
render('icon_background_432',864)
print('PASS icon_v3: 3 renders; source read only; no normal pass',flush=True)
