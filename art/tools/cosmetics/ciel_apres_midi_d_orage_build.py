import bpy, math, shutil
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\const\Documents\Rainfall\.claude\worktrees\agent-aa7c224c816eb5fed')
O=ROOT/'art/renders/cosmetics/ciel'
O.mkdir(parents=True,exist_ok=True)
def linear(v): return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def color(h): return tuple(linear(int(h[i:i+2],16)/255) for i in (1,3,5))
def material(name, h, emission=1):
    c=color(h) if isinstance(h,str) else h
    m=bpy.data.materials.new(name); m.use_nodes=True
    n=m.node_tree.nodes; n.clear(); e=n.new('ShaderNodeEmission'); e.inputs[0].default_value=(*[v/max(1,emission) for v in c],1); e.inputs[1].default_value=emission
    out=n.new('ShaderNodeOutputMaterial'); m.node_tree.links.new(e.outputs[0],out.inputs['Surface']); return m
def setup(w,h):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'; s.eevee.taa_render_samples=32
    s.render.resolution_x=w; s.render.resolution_y=h; s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.film_transparent=False
    s.view_settings.view_transform='Standard'; s.view_settings.look='None'; s.view_settings.exposure=0; s.view_settings.gamma=1
    s.world=bpy.data.worlds.new('Storm'); s.world.color=(.08,.12,.22)
    s.render.image_settings.color_depth='8'; s.render.dither_intensity=0; return s
def mesh(name,vs,mat):
    me=bpy.data.meshes.new(name); me.from_pydata(vs,[],[tuple(range(len(vs)))]); me.materials.append(mat)
    ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob); return ob
def disc(name,x,y,z,rx,ry,mat):
    return mesh(name,[(x+rx*math.cos(i*math.tau/96),y+ry*math.sin(i*math.tau/96),z) for i in range(96)],mat)
def plane(name,x,y,z,w,h,mat): return mesh(name,[(x-w/2,y-h/2,z),(x+w/2,y-h/2,z),(x+w/2,y+h/2,z),(x-w/2,y+h/2,z)],mat)
def gradient(name,top,bottom):
    m=material(name,top); n=m.node_tree.nodes; l=m.node_tree.links; e=next(v for v in n if v.type=='EMISSION')
    tc=n.new('ShaderNodeTexCoord'); sep=n.new('ShaderNodeSeparateXYZ'); ramp=n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color=(*color(bottom),1); ramp.color_ramp.elements[1].color=(*color(top),1)
    l.new(tc.outputs['Generated'],sep.inputs[0]); l.new(sep.outputs['Y'],ramp.inputs[0]); l.new(ramp.outputs[0],e.inputs[0]); return m
def render(s,path): s.render.filepath=str(path); bpy.ops.render.render(write_still=True)
s=setup(256,64)
c=bpy.data.cameras.new('Square pixels'); cam=bpy.data.objects.new('Square pixels',c); bpy.context.collection.objects.link(cam); cam.location=(128,32,200); c.type='ORTHO'; c.ortho_scale=256; s.camera=cam
# Pure vertical gradient backdrop.
plane('Storm gradient',128,32,0,320,64,gradient('Ocher storm','#2E3347','#C98A4A'))
# Three cloud bands, rounded cel masses and warm lower rims.
def capsule(x1,x2,y,h,z,mat):
    plane('Cloud mass',(x1+x2)/2,y,z,x2-x1,h,mat)
    for x in (x1,x2): disc('Cloud round end',x,y,z,h/2,h/2,mat)
for x1,x2,y,h in [(30,105,15,9),(112,204,25,10),(42,220,42,8)]:
    capsule(x1,x2,y,h,2,material('Cloud shadow','#3A3F57'))
    capsule(x1+6,x2-6,y+2,h*.66,2.1,material('Cloud light','#6A6683'))
    capsule(x1+8,x2-8,y-h*.32,h*.2,2.2,material('Warm cloud hem','#E8A864'))
# Diffuse warm break and lower reflected streaks.
for i in range(12,0,-1): disc('Warm opening',150,42,3+(12-i)*.01,10*i/12,10*i/12,material('Opening glow '+str(i),'#F2B66E'))
for i,(x,y,w,h) in enumerate([(28,53,12,3),(62,49,9,2),(97,57,16,3),(137,52,13,3),(176,56,17,4),(215,50,11,2)]):
    disc('Ocher water reflection',x,64-y,4,w/2,h/2,material('Reflection '+str(i),'#E0A060'))
# Sky asset is already approved; do not regenerate it.
def preview():
    sc=setup(256,256)
    def cube(name,loc,scale,mat,bevel=0):
        bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(mat)
        if bevel: m=o.modifiers.new('Rounded cel edge','BEVEL'); m.width=bevel; m.segments=2
        return o
    def diamond(name,x,y,z,rx,ry,mat):
        return mesh(name,[(x,y-ry,z),(x+rx,y,z),(x,y+ry,z),(x-rx,y,z)],mat)
    moss=material('Moss','#56683F'); dark=material('Moss shadow','#3E4C2E'); ink=material('Bark ink','#34271F'); wood=material('Cedar bark','#5A4636'); barklit=material('Bark cel','#78604A'); water=material('Pool','#536F83'); glint=material('Warm reflection','#FFC878',1.35); leaf=material('Cedar leaves','#8A9A4A')
    cube('Mossy ground',(0,0,0),(3.5,2.7,.28),dark,.08); cube('Upper moss terrace',(0,.72,.19),(2.85,.8,.25),moss,.06)
    cube('Reflecting pool',(-.25,-.25,.17),(1.5,.65,.035),water,.12)
    for x,y in [(-1.15,.35),(.95,.45)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.22,depth=1.65,location=(x,y,.92)); t=bpy.context.object; t.name='Cedar trunk cylinder'; t.data.materials.append(wood)
        bevel=t.modifiers.new('Soft bark edge','BEVEL'); bevel.width=.025; bevel.segments=1
        for dx,dy in [(-.27,-.1),(.24,-.08),(0,.23)]:
            cube('Cedar root',(x+dx*.5,y+dy*.5,.19),(.3,.16,.19),wood,.05)
        # Narrow ink seams and warm bark planes, constrained to the visible face.
        for dx in [-.12,0,.12]: cube('Fine bark seam',(x+dx,y-.216,.91),(.012,.006,1.38),ink,.003)
        cube('Warm bark plane',(x-.08,y-.225,.92),(.09,.008,1.42),barklit,.01)
    # Warm sky reflected as simple luminous streaks.
    for i in range(4): cube('Water glint',(-.75+i*.34,-.26,.205),(.22,.045,.008),glint,.015)
    camd=bpy.data.cameras.new('Preview iso 2 to 1'); cam=bpy.data.objects.new('Preview iso 2 to 1',camd); bpy.context.collection.objects.link(cam); target=Vector((0,0,.65)); cam.location=target+Vector((6,-6,math.sqrt(24))); cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler(); camd.type='ORTHO'; camd.ortho_scale=3.6; sc.camera=cam
    right=cam.rotation_euler.to_matrix()@Vector((1,0,0)); up=cam.rotation_euler.to_matrix()@Vector((0,1,0)); toward=cam.rotation_euler.to_matrix()@Vector((0,0,1))
    def billboard(ob,px,py,depth): ob.rotation_euler=cam.rotation_euler; ob.location=target+right*((px-128)*4.5/256)+up*((128-py)*4.5/256)+toward*depth
    bg=plane('Full frame storm sky',0,0,0,5.6,5.6,gradient('Storm backdrop','#2E3347','#8A6A4A')); billboard(bg,128,128,-7)
    raymat=bpy.data.materials.new('Translucent warm rays'); raymat.diffuse_color=(*color('#FFC878'),.22); raymat.use_nodes=True
    rn=raymat.node_tree.nodes; rn.clear(); tr=rn.new('ShaderNodeBsdfTransparent'); em=rn.new('ShaderNodeEmission'); em.inputs[0].default_value=(*color('#FFC878'),1); em.inputs[1].default_value=.65
    mix=rn.new('ShaderNodeMixShader'); mix.inputs[0].default_value=.22; out=rn.new('ShaderNodeOutputMaterial'); raymat.node_tree.links.new(tr.outputs[0],mix.inputs[1]); raymat.node_tree.links.new(em.outputs[0],mix.inputs[2]); raymat.node_tree.links.new(mix.outputs[0],out.inputs['Surface']); raymat.surface_render_method='BLENDED'
    mixnode=next(n for n in raymat.node_tree.nodes if n.type=='MIX_SHADER')
    rt=raymat.node_tree.nodes.new('ShaderNodeTexCoord'); rs=raymat.node_tree.nodes.new('ShaderNodeSeparateXYZ'); rr=raymat.node_tree.nodes.new('ShaderNodeValToRGB')
    ramp=rr.color_ramp; ramp.elements[0].position=0; ramp.elements[0].color=(0,0,0,1); ramp.elements[1].position=1; ramp.elements[1].color=(0,0,0,1)
    for pos in (.18,.5,.82):
        el=ramp.elements.new(pos); v=.22 if pos==.5 else 0; el.color=(v,v,v,1)
    raymat.node_tree.links.new(rt.outputs['Generated'],rs.inputs[0]); raymat.node_tree.links.new(rs.outputs['X'],rr.inputs[0]); raymat.node_tree.links.new(rr.outputs['Color'],mixnode.inputs[0])
    for x,y,ang in [(92,96,-.61),(145,103,-.61),(195,91,-.61)]:
        ob=plane('Oblique warm ray',0,0,0,.42,1.9,raymat); billboard(ob,x,y,-3); ob.rotation_euler.rotate_axis('Z',ang)
    for px,py in [(80,88),(118,105),(158,80),(198,112),(142,187),(175,177)]:
        ob=diamond('Falling cedar leaf',0,0,0,.085,.13,leaf); billboard(ob,px,py,-2)
    fog=material('Low pale mist','#B7AE9B',.8); mist=plane('Low mist',0,0,0,3.2,.24,fog); billboard(mist,128,211,1)
    sc.render.filepath=str(ROOT/'game/assets/sprites/cosmetics/previews/apres_midi_d_orage.png'); bpy.ops.render.render(write_still=True)
    bpy.context.preferences.filepaths.save_version=0; bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/ciel_apres_midi_d_orage.blend'))

preview()
print('PASS storm sky / preview / blend',flush=True)
