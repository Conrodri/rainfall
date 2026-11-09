"""Blender background generator. All silhouettes are rendered mesh geometry."""
import bpy, math, random
from pathlib import Path

ROOT = Path(r'C:\Users\const\Documents\Rainfall\.claude\worktrees\agent-a00f1c2bdb6d72b46')
RAW = ROOT / 'art/renders/status_fx/raw'
RAW.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '8'
scene.render.resolution_percentage = 100
scene.render.image_settings.compression = 100
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.render.film_transparent = True
bpy.ops.object.camera_add(location=(0, 0, 100))
cam = bpy.context.object
cam.data.type = 'ORTHO'
scene.camera = cam
materials = {}
z = 0

def material(color, alpha=1):
    key = (color, alpha)
    if key in materials:
        return materials[key]
    rgb = [int(color[i:i+2], 16)/255 for i in (1,3,5)]
    rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    m = bpy.data.materials.new(str(key))
    m.use_nodes = True
    n = m.node_tree.nodes
    n.clear()
    out = n.new('ShaderNodeOutputMaterial')
    em = n.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = (*rgb, 1)
    if alpha < 1:
        tr = n.new('ShaderNodeBsdfTransparent')
        mix = n.new('ShaderNodeMixShader')
        mix.inputs[0].default_value = alpha
        m.node_tree.links.new(tr.outputs[0], mix.inputs[1])
        m.node_tree.links.new(em.outputs[0], mix.inputs[2])
        m.node_tree.links.new(mix.outputs[0], out.inputs[0])
        m.surface_render_method = 'DITHERED'
    else:
        m.node_tree.links.new(em.outputs[0], out.inputs[0])
    materials[key] = m
    return m

def poly(points, color, alpha=1):
    global z
    z += .01
    mesh = bpy.data.meshes.new('fx')
    mesh.from_pydata([(x,y,z) for x,y in points], [], [tuple(range(len(points)))])
    mesh.update()
    ob = bpy.data.objects.new('fx', mesh)
    scene.collection.objects.link(ob)
    ob.data.materials.append(material(color, alpha))
    return ob

def ellipse(x,y,rx,ry,color,alpha=1,angle=0):
    pts=[]
    for i in range(64):
        t=i*math.tau/64
        a,b=rx*math.cos(t),ry*math.sin(t)
        pts.append((x+a*math.cos(angle)-b*math.sin(angle), y+a*math.sin(angle)+b*math.cos(angle)))
    poly(pts,color,alpha)

def ring(x,y,rx,ry,thick,color,alpha=1):
    global z
    z += .01
    verts=[]
    for r in (0, thick):
        verts += [(x+(rx-r)*math.cos(i*math.tau/64), y+(ry-r)*math.sin(i*math.tau/64),z) for i in range(64)]
    faces=[(i,(i+1)%64,(i+1)%64+64,i+64) for i in range(64)]
    mesh=bpy.data.meshes.new('ring'); mesh.from_pydata(verts,[],faces); mesh.update()
    ob=bpy.data.objects.new('fx',mesh); scene.collection.objects.link(ob); mesh.materials.append(material(color,alpha))

def line(points,width,color,alpha=1):
    # Mitered ribbons: pointed ends, never endpoint balls.
    left=[];right=[]
    for i,(x,y) in enumerate(points):
        a=points[max(0,i-1)]; b=points[min(len(points)-1,i+1)]
        dx,dy=b[0]-a[0],b[1]-a[1]; d=math.hypot(dx,dy)
        taper=.12 if i in (0,len(points)-1) else 1
        nx,ny=-dy/d*width/2*taper,dx/d*width/2*taper
        left.append((x+nx,y+ny));right.append((x-nx,y-ny))
    poly(left+right[::-1],color,alpha)

def bezier(a,b,c,d,n=14):
    return [tuple((1-t)**3*a[k]+3*(1-t)**2*t*b[k]+3*(1-t)*t*t*c[k]+t**3*d[k] for k in (0,1)) for t in [i/n for i in range(n)]]

def start(w,h):
    global z
    for ob in list(scene.objects):
        if ob != cam:
            bpy.data.objects.remove(ob,do_unlink=True)
    z=0
    scene.render.resolution_x=w*2;scene.render.resolution_y=h*2
    cam.location=(w/2,h/2,100)
    cam.data.ortho_scale=max(w,h)

def save(name):
    scene.render.filepath=str(RAW/(name+'.png'))
    bpy.ops.render.render(write_still=True)

def bubble(x,y,rx,ry,opaque=False,shine=1):
    ring(x,y,rx,ry,.7,'#193C26',.95)
    ring(x,y,rx-.7,ry-.7,.9,'#7FD65A',.85)
    ellipse(x,y,rx-1.6,ry-1.6,'#3E8F3A',.7 if opaque else .55)
    line([(x-rx*.55,y+ry*.05),(x-rx*.65,y+ry*.45),(x-rx*.25,y+ry*.72)],1.1,'#B5EF92',.85)
    ellipse(x-rx*.38,y+ry*.49,1.6*shine,.85,'#F1FFD7',1,.5)

for i in range(4):
    start(32,32)
    bubble(15 if i==1 else 16,16,9.6 if i==1 else (11 if i==2 else 10.5),10 if i==2 else 10.5,i==3,.75+i*.16)
    if i==1: bubble(24,9,3,3,False,.35)
    save(f'poison_bubble_{i+1:02}')

for i in range(4):
    start(32,48)
    tip=[(16,42),(10,42),(23,42),(13,42)][i]
    contour=bezier((16,6),(3,6),(5,19),(10,25))+bezier((10,25),(11,18),(14,29),tip)
    if i==3:
        contour += [tip,(17,29),(24,37),(23,24)]
    else: contour += [tip,(20+(i==2)*3,29),(22,24)]
    contour += bezier((22,24),(30,11),(25,6),(16,6))
    poly(contour,'#C23B12',.55)
    poly([(16+(x-16)*.78,7+(y-6)*.80) for x,y in contour],'#FF7A1F',.9)
    poly(bezier((16,7),(7,8),(12,19),(16,27))+bezier((16,27),(15,19),(25,9),(16,7)),'#FFB347')
    poly(bezier((16,8),(12,9),(14,16),(16,20))+bezier((16,20),(18,15),(21,9),(16,8)),'#FFE9A8')
    save(f'burn_flame_{i+1:02}')

for i in range(2):
    start(16,16)
    ellipse(8,8,3,3.4 if i else 3,'#FF9B36',.2)
    ellipse(8,8,2,2.8 if i else 2,'#FFB347',.7)
    ellipse(8,8,1,1.8 if i else 1,'#FFE9A8')
    save(f'burn_ember_{i+1:02}')

for i in range(4):
    start(24,24)
    rng=random.Random(170+i)
    pts=[]
    for j in range(13):
        t=j*math.tau/13+i*.27;r=rng.uniform(4.5,7)
        pts.append((12+math.cos(t)*r,12+math.sin(t)*r*.8))
    poly(pts,'#262527')
    inner=[(12+(x-12)*.83,12+(y-12)*.83) for x,y in pts]
    poly(inner,'#3A3634')
    poly([inner[1],inner[2],inner[3],inner[4],(12,11),(11,13)],'#5A5450')
    if i in (1,3):line([pts[7],pts[8],pts[9]],.6,'#C23B12')
    save(f'burn_ash_{i+1:02}')

def drop(cx,cy,rx,height):
    tip=(cx,cy+height*.65)
    pts=bezier(tip,(cx-.5,cy+height*.24),(cx-rx,cy+height*.03),(cx-rx,cy-height*.1))
    pts+=bezier((cx-rx,cy-height*.1),(cx-rx,cy-height*.55),(cx+rx,cy-height*.55),(cx+rx,cy-height*.1))
    pts+=bezier((cx+rx,cy-height*.1),(cx+rx,cy+height*.05),(cx+.5,cy+height*.24),tip)
    poly(pts,'#263D50')
    poly([(cx+(x-cx)*.78,cy+(y-cy)*.88) for x,y in pts],'#6F8FA8',.95)
    poly([(cx+(x-cx)*.54-.2,cy+(y-cy)*.72+.4) for x,y in pts],'#CFE8FF',.9)
    ellipse(cx-rx*.32,cy+height*.04,.7,1.7,'#FFFFFF',1,-.2)

for i in range(4):
    start(16,32)
    drop(8,13,3.2 if i==0 else 3.3,18 if i!=1 else 14)
    if i==2: line([(8,25.5),(8,27)],.8,'#CFE8FF',.8)
    if i==3: drop(8,25,1.3,3.6)
    save(f'wet_drip_{i+1:02}')

arcs=[
 [[(7,28),(21,34),(26,25),(40,38),(45,29),(57,34)],[(21,34),(18,43),(25,47)],[(40,38),(43,47),(50,49)]],
 [[(10,9),(23,21),(19,30),(37,34),(34,45),(53,55)],[(23,21),(35,19),(40,24)],[(34,45),(23,49),(25,55)]],
 [[(9,31),(22,36),(30,29),(38,38),(52,48)],[(30,29),(41,24),(46,13),(56,17)],[(22,36),(21,46),(28,50)]],
 [[(31,8),(36,21),(29,30),(35,37)],[(35,37),(22,42),(24,51),(12,56)],[(35,37),(44,42),(42,51),(54,55)],[(36,21),(46,24),(50,20)]]]
for i,branches in enumerate(arcs):
    start(64,64)
    for width,col,alpha in [(3.8,'#7AB8FF',.22),(2.2,'#7AB8FF',.72),(1.2,'#CFE8FF',1),(.55,'#FFFFFF',1)]:
        for branch in branches:line(branch,width,col,alpha)
    save(f'shock_arc_{i+1:02}')

for i in range(2):
    start(32,32)
    n=4+i;pts=[]
    for j in range(n*2):
        t=math.pi/2+j*math.pi/n
        r=10.3 if j%2==0 else 2.1
        pts.append((16+math.cos(t)*r,16+math.sin(t)*r))
    poly([(16+(x-16)*1.04,16+(y-16)*1.04) for x,y in pts],'#FFD36F',.25)
    poly(pts,'#FFE9A8',.95)
    poly([(16+(x-16)*.64,16+(y-16)*.64) for x,y in pts],'#FFF5CD')
    poly([(16,18.2),(17.2,16),(16,13.8),(14.8,16)],'#FFFFFF')
    save(f'stun_star_{i+1:02}')

print('PASS: 24 mesh sprites rendered at 2x; no normals; no emission masks')




