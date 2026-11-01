import bpy, math, shutil
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).parents[3]
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
    s.world=bpy.data.worlds.new('Night'); s.world.color=(.08,.12,.22)
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
plane('Night gradient',128,32,0,260,64,gradient('Blue night','#1E2C52','#4A6EA0'))
for radius,h,z in [(12,'#5F7DB4',1),(9,'#A9BCDD',2),(7,'#F0F4FA',3)]: disc('Round moon',150,44,z,radius,radius,material('Moon '+h,h))
def capsule(x1,x2,y,h,z,mat):
    plane('Cloud body',(x1+x2)/2,y,z,x2-x1,h,mat)
    for x in (x1,x2): disc('Rounded cloud',x,y,z,h/2,h/2,mat)
for x1,x2,y,h in [(44,142,40,8),(176,219,29,7)]:
    capsule(x1,x2,y,h,4,material('Cloud shade','#35497D'))
    capsule(x1+6,x2-4,y+1.6,h-3,4.1,material('Cloud light','#4F6A9E'))
# Layered transparent emission ellipses, entirely rendered by Eevee.
def soft(name,x,y,z,rx,ry,h,opacity=.6):
    for i in range(12,0,-1):
        f=i/12; m=material(name+str(i),h); n=m.node_tree.nodes; l=m.node_tree.links
        e=next(v for v in n if v.type=='EMISSION'); out=next(v for v in n if v.type=='OUTPUT_MATERIAL'); tr=n.new('ShaderNodeBsdfTransparent'); mix=n.new('ShaderNodeMixShader'); mix.inputs[0].default_value=opacity/8
        l.new(tr.outputs[0],mix.inputs[1]); l.new(e.outputs[0],mix.inputs[2]); l.new(mix.outputs[0],out.inputs[0]); m.surface_render_method='BLENDED'
        disc(name,x,y,z+(12-i)*.002,rx*f,ry*f,m)
for i,(x,y,w,h) in enumerate([(22,53,12,3),(56,48,8,3),(91,57,16,4),(128,51,10,3),(169,55,14,4),(202,49,8,2),(233,58,12,3)]):
    soft('Amber reflection',x,64-y,5,w/2,h/2,'#FFB35A',.9)
    disc('Ripple',x+2,64-y-2,5.1,w/3,.28,material('Amber ripple','#A6836C'))
render(s,O/'sky_nuit_de_lanternes_256x64.png')
# Preserve the established halo asset exactly.
shutil.copy2(ROOT/'game/assets/sprites/ambiance/lantern_glow_64.png',O/'lantern_glow_64.png')
def preview():
    sc=setup(256,256)
    def cube(name, loc, scale, mat, bevel=0):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); o.data.materials.append(mat)
        if bevel: b=o.modifiers.new('Soft edges','BEVEL'); b.width=bevel; b.segments=2
        return o
    def diamond(name,cx,cy,z,rx,ry,mat,thick=.08):
        verts=[(cx,cy-ry,z),(cx+rx,cy,z),(cx,cy+ry,z),(cx-rx,cy,z),(cx,cy-ry,z-thick),(cx+rx,cy,z-thick),(cx,cy+ry,z-thick),(cx-rx,cy,z-thick)]
        faces=[(0,1,2,3),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0),(4,7,6,5)]
        mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.materials.append(mat); ob=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(ob)
        bevel=ob.modifiers.new('Chamfered ink edges','BEVEL'); bevel.width=.025; bevel.segments=1
        ob.modifiers.new('Weighted stone normals','WEIGHTED_NORMAL'); return ob
    stone=material('Stone top','#5A6A86'); edge=material('Stone bevel','#3E4C68'); ink=material('Fine ink','#303F59'); water=material('Water','#2E5A8A'); wood=material('Wood','#6F5146')
    gold=material('Emissive paper strength 5','#FFB35A',5); cap=material('Lantern caps','#9B6343')
    cube('Lower ink silhouette',(0,0,.18),(3.45,2.65,.4),ink,.07)
    cube('Lower stone terrace',(0,0,.23),(3.38,2.58,.38),stone,.075)
    cube('Upper ink silhouette',(0,.76,.49),(3.0,.91,.36),ink,.05)
    cube('Upper stone terrace',(0,.76,.53),(2.94,.85,.32),edge,.05)
    cube('Basin rim',(-.05,-.28,.452),(2.5,1.24,.045),ink,.06)
    cube('Blue water',(-.05,-.28,.48),(2.36,1.10,.025),water,.04)
    # Cool reflected lunar disc and three bright ripples on the water plane.
    disc('Reflected moon',-.45,-.22,.50,.20,.20,material('Moon reflection','#BCCFE8'))
    for i in range(3):
        plane('Vertical moon trail',-.45,-.48-i*.15,.51,.25-i*.045,.036,material('Reflected silver','#A9BCDD'))
    for i,(x,y) in enumerate([(-1.18,.55),(.15,.80),(1.18,.30)]):
        z=.72 if y>.4 else .43
        cube('Wooden post',(x,y,z+.36),(.055,.055,.72),wood,.012)
        # Paper is visible on every face; frame uses narrow external ribs.
        cube('Luminous paper',(x,y,z+.86),(.31,.27,.40),gold,.055)
        for dz in (-.22,.22): cube('Lantern cap',(x,y,z+.86+dz),(.36,.31,.045),cap,.015)
        for dx in (-.15,.15): cube('Fine paper rib',(x+dx,y-.14,z+.86),(.012,.012,.38),cap,.003)
        for j in range(3):
            disc('Warm stone pool',x,y,z+.005+j*.002,.38-j*.07,.28-j*.05,material('Warm stone '+str(j),['#7C735F','#A78962','#BC945E'][j]))
        ld=bpy.data.lights.new('Warm lantern','POINT'); ld.energy=35; ld.color=(1,.45,.12); ob=bpy.data.objects.new('Warm lantern',ld); bpy.context.collection.objects.link(ob); ob.location=(x,y,z+.8)
    camd=bpy.data.cameras.new('Preview iso 2 to 1'); cam=bpy.data.objects.new('Preview iso 2 to 1',camd); bpy.context.collection.objects.link(cam)
    target=Vector((0,0,.85)); cam.location=target+Vector((6,-6,math.sqrt(24))); cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler(); camd.type='ORTHO'; camd.ortho_scale=5.4; sc.camera=cam
    right=cam.rotation_euler.to_matrix()@Vector((1,0,0)); up=cam.rotation_euler.to_matrix()@Vector((0,1,0)); toward=cam.rotation_euler.to_matrix()@Vector((0,0,1))
    def billboard(ob,px,py,depth):
        ob.rotation_euler=cam.rotation_euler; ob.location=target+right*((px-128)*5.4/256)+up*((128-py)*5.4/256)+toward*depth
    bg=plane('Full frame blue night',0,0,0,5.6,5.6,gradient('Background','#1E2C52','#3A5A86')); billboard(bg,128,128,-7)
    for radius,h,depth in [(18,'#354D79',-5.2),(14,'#5F7DB4',-5.1),(11,'#F0F4FA',-5)]:
        ob=disc('Round sky moon',0,0,0,radius*5.4/256,radius*5.4/256,material('Lunar halo',h)); billboard(ob,48,40,depth)
    # Round camera-facing halos behind the paper, rendered as transparent Eevee geometry.
    from bpy_extras.object_utils import world_to_camera_view
    for ob in list(bpy.data.objects):
        if ob.name.startswith('Luminous paper'):
            bpy.context.view_layer.update(); p=world_to_camera_view(sc,cam,ob.location)
            before=set(bpy.data.objects); soft('Warm round aura',0,0,0,.43,.43,'#FFB35A',.38)
            for halo in set(bpy.data.objects)-before:
                z=halo.location.z; billboard(halo,p.x*256,(1-p.y)*256,-.05+z)
    for px,py in [(38,116),(88,91),(177,79),(221,139),(123,213)]:
        ob=disc('Pale green firefly',0,0,0,.028,.028,material('Firefly','#C8FF9A',4)); billboard(ob,px,py,4)
    sc.render.filepath=str(ROOT/'game/assets/sprites/cosmetics/previews/nuit_de_lanternes.png')
    bpy.ops.render.render(write_still=True)
    sc.render.use_file_extension=True; bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/ciel_nuit_de_lanternes.blend'))
    dest=ROOT/'game/assets/sprites/ambiance'
    for name in ['sky_nuit_de_lanternes_256x64.png','lantern_glow_64.png']: shutil.copyfile(O/name,dest/name)
preview()
print('PASS Blender sky / halo / preview / blend',flush=True)
