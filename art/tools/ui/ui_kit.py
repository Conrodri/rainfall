"""Outils communs pour les éléments d'UI (boutons, cadres, cartes...) : formes arrondies 3D, caméra de face, post-traitement groupé.
Tout est modélisé dans Blender ; Pillow (fit.py) ne fait que réduire/rogner."""
import sys, math, json, subprocess
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_lib import *
import items_a as a
from mathutils import Matrix, Euler
PY=r'C:\Users\const\AppData\Local\Python\bin\python.exe'
JOBS=[]

def new_scene(name, samples=24):
    s=bpy.data.scenes.new(name); bpy.context.window.scene=s
    reset_scene(); setup_render(); s.eevee.taa_render_samples=samples; a.palette()
    return s

def front_camera(frame_w, frame_h, res_w, res_h, tilt_deg=0, shift=(0,0)):
    """Caméra orthographique de face (objets dans le plan XZ, profondeur -Y vers la caméra)."""
    s=bpy.context.scene; c=s.camera
    s.render.resolution_x=res_w; s.render.resolution_y=res_h
    t=math.radians(tilt_deg)
    c.location=(shift[0],-10*math.cos(t),10*math.sin(t)+shift[1])
    aim(c,(shift[0],0,shift[1])); c.data.ortho_scale=max(frame_w,frame_h)
    c.data.clip_end=60
    return c

def rrect(w,h,r,n=10):
    """Points (x,z) d'un rectangle arrondi centré, sens antihoraire."""
    r=min(r,w/2,h/2); pts=[]
    for cx,cz,a0 in [(w/2-r,h/2-r,0),(-w/2+r,h/2-r,90),(-w/2+r,-h/2+r,180),(w/2-r,-h/2+r,270)]:
        for i in range(n+1):
            t=math.radians(a0+90*i/n); pts.append((cx+r*math.cos(t),cz+r*math.sin(t)))
    return pts

def _mesh(name,verts,faces,m):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    import bmesh
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    for p in me.polygons:p.use_smooth=False
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o)
    if m:o.data.materials.append(m)
    return o

def slab(pts,m,depth=.2,y=0,bevel=.04,name='Plaque'):
    n=len(pts); y0,y1=y-depth/2,y+depth/2
    v=[(x,y0,z) for x,z in pts]+[(x,y1,z) for x,z in pts]
    f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    o=_mesh(name,v,f,m)
    if bevel:
        b=o.modifiers.new('Biseau','BEVEL'); b.width=bevel; b.segments=3; b.limit_method='ANGLE'
    return o

def ring(outer,inner,m,depth=.2,y=0,bevel=.03,name='Cadre'):
    """Anneau extrudé entre deux boucles de même longueur (ex. deux rrect de même n)."""
    n=len(outer); assert n==len(inner)
    y0,y1=y-depth/2,y+depth/2
    v=[(x,y0,z) for x,z in outer]+[(x,y0,z) for x,z in inner]+[(x,y1,z) for x,z in outer]+[(x,y1,z) for x,z in inner]
    O0,I0,O1,I1=0,n,2*n,3*n
    f=[]
    for i in range(n):
        j=(i+1)%n
        f+= [(O0+i,O0+j,I0+j,I0+i),(O1+i,I1+i,I1+j,O1+j),(O0+i,O1+i,O1+j,O0+j),(I0+i,I0+j,I1+j,I1+i)]
    o=_mesh(name,v,f,m)
    if bevel:
        b=o.modifiers.new('Biseau','BEVEL'); b.width=bevel; b.segments=3; b.limit_method='ANGLE'
    return o

def rr_ring(w,h,r,border,m,depth=.2,y=0,bevel=.03,n=10,name='Cadre'):
    return ring(rrect(w,h,r,n),rrect(w-2*border,h-2*border,max(r-border,.01),n),m,depth,y,bevel,name)

def flat_disk(loc,r,depth,m,rot=True):
    o=cylinder(loc,r,depth,m,48)
    if rot:o.rotation_euler[0]=math.pi/2
    return o

def group(build, loc=(0,0,0), scale=1, rot=(0,0,0), pivot=(0,0,0)):
    before=set(bpy.context.scene.objects); build()
    new=set(bpy.context.scene.objects)-before; bpy.context.view_layer.update()
    P=Matrix.Translation(pivot)
    M=Matrix.Translation(loc)@P@Euler(rot).to_matrix().to_4x4()@Matrix.Scale(scale,4)@P.inverted()
    for o in new:o.matrix_world=M@o.matrix_world
    return new

def toward(o,v):
    o.rotation_euler=Vector(v).to_track_quat('Z','Y').to_euler()

def meshes():
    return [o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}]

def post(job):
    """Ajoute un travail de post-traitement Pillow : dict(mode='resize'|'icon', src, dst, w,h|size, margin)."""
    JOBS.append(job)

def flush_post():
    if not JOBS:return
    p=ROOT/('art/renders/ui/_jobs_%d.json'%abs(hash(json.dumps(JOBS))))
    p.write_text(json.dumps(JOBS)); subprocess.run([PY,'-I',str(Path(__file__).with_name('fit.py')),str(p)],check=True); p.unlink(); JOBS.clear()

def render_raw(path):
    render_to(path)

def save_blend(name):
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ui'/name))
