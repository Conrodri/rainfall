"""Pipeline Blender Rainfall : camera fixe, pivot sol 70%, rendus RGBA 2x.
Importer depuis un script execute exclusivement par Blender --background --python.
Les sorties restent en 2x; pack_monsters effectue la reduction LANCZOS.
"""
import bpy, math, sys, json
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ART = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ART/'tools'))
import passes
DIRS = ['e','se','s','sw','w','nw','n','ne']

def material(name, hexcolor, emission=.32, luminous=False):
    rgb=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
    rgb=[v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*rgb,1)
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Roughness'].default_value=.78;p.inputs['Specular IOR Level'].default_value=.2
    p.inputs['Emission Color'].default_value=(*rgb,1);p.inputs['Emission Strength'].default_value=emission
    m['rainfall_emissive']=luminous
    return m

def empty(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=loc;return o

def finish(o,name,loc,scale,mat,parent):
    o.name=name;o.parent=parent;o.location=loc;o.scale=scale;o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def sphere(name,loc,scale,mat,parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16)
    return finish(bpy.context.object,name,loc,scale,mat,parent)

def cone(name,loc,r1,r2,depth,mat,parent=None,scale=(1,1,1)):
    bpy.ops.mesh.primitive_cone_add(vertices=32,radius1=r1,radius2=r2,depth=depth)
    o=finish(bpy.context.object,name,loc,scale,mat,parent)
    b=o.modifiers.new('Soft edges','BEVEL');b.width=.012;b.segments=2
    return o

def cube(name,loc,scale,mat,parent=None,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=2)
    o=finish(bpy.context.object,name,loc,scale,mat,parent)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    b=o.modifiers.new('Rounded edges','BEVEL');b.width=bevel;b.segments=3
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o

def segment(name,a,b,r,mat,parent=None):
    a,b=Vector(a),Vector(b);o=cone(name,(a+b)/2,r,r*.82,(b-a).length,mat,parent)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def setup_scene(size=112):
    assert bpy.app.background, 'Background Blender required'
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=s.render.resolution_y=size*2
    s.render.resolution_percentage=100;s.render.film_transparent=True
    s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8'
    s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
    if hasattr(s,'eevee'):s.eevee.taa_render_samples=16
    s.world=bpy.data.worlds.new('Rainfall ambient');s.world.use_nodes=True
    bg=s.world.node_tree.nodes['Background'];bg.inputs[0].default_value=(.17,.21,.29,1);bg.inputs[1].default_value=.65
    for name,loc,power,color,kind in [
        ('Warm upper left',(-3,-4,6),2.4,(1,.76,.53),'SUN'),
        ('Cool fill',(3,-2,4),220,(.46,.62,1),'AREA'),
        ('Cold silhouette rim',(2,3,4),330,(.624,.722,.847),'AREA')]:
        ld=bpy.data.lights.new(name,kind);ld.energy=power;ld.color=color
        if kind=='SUN':ld.angle=.15
        else:ld.shape='DISK';ld.size=4 if 'fill' in name else 2.5
        o=bpy.data.objects.new(name,ld);s.collection.objects.link(o);o.location=loc
        o.rotation_euler=(Vector((0,0,.6))-o.location).to_track_quat('-Z','Y').to_euler()
    cam=bpy.data.objects.new('Fixed camera 55 degrees',bpy.data.cameras.new('Orthographic'))
    s.collection.objects.link(cam);target=Vector((0,0,.65))
    cam.location=target+Vector((0,-4*math.cos(math.radians(55)),4*math.sin(math.radians(55))))
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.3;s.camera=cam
    return s

def pose(root,frame,direction):
    bpy.context.scene.frame_set(frame);root.rotation_euler.z=math.radians(90-45*DIRS.index(direction));bpy.context.view_layer.update()

def fit_camera(root,animations,size=112,directions=None):
    s=bpy.context.scene;cam=s.camera;bpy.context.view_layer.update();inv=cam.matrix_world.inverted();ground=inv@Vector((0,0,0))
    xmin=ymin=1e9;xmax=ymax=-1e9
    for anim,(start,count) in animations.items():
        for i in range(count):
            for d in directions.get(anim,DIRS) if directions else DIRS:
                pose(root,start+i,d);deps=bpy.context.evaluated_depsgraph_get()
                for obj in s.objects:
                    if obj.type!='MESH' or obj.hide_render:continue
                    ev=obj.evaluated_get(deps);mesh=ev.to_mesh()
                    for v in mesh.vertices:
                        q=inv@(ev.matrix_world@v.co)-ground
                        xmin=min(xmin,q.x);xmax=max(xmax,q.x);ymin=min(ymin,q.y);ymax=max(ymax,q.y)
                    ev.to_mesh_clear()
    margin=9/size # 4px transparent + 2px outline + filter support
    scale=max(max(abs(xmin),abs(xmax))/(.5-margin),ymax/(.7-margin),-ymin/(.3-margin))
    cam.data.ortho_scale=scale;cam.data.shift_y=0;bpy.context.view_layer.update()
    cam.data.shift_y=world_to_camera_view(s,cam,Vector((0,0,0))).y-.30
    report={'ortho_scale':scale,'ground_pivot_percent':70,'bounds_camera':[xmin,xmax,ymin,ymax],'final_frame':size,'render_frame':size*2}
    s['framing_note']=json.dumps(report);return report

def diffuse_compositor(scene):
    # Derive the 2px final outline from coverage, entirely inside Blender.
    t,out=passes._tree(scene,'Monster diffuse contour')
    r=t.nodes.new('CompositorNodeRLayers');r.scene=scene
    if scene.get('diffuse_contour_pixels',2)==0:
        t.links.new(r.outputs['Image'],out.inputs['Image']);return
    dil=t.nodes.new('CompositorNodeDilateErode')
    if 'Size' in dil.inputs:dil.inputs['Size'].default_value=4
    else:dil.distance=4
    t.links.new(r.outputs['Alpha'],dil.inputs[0])
    outline=passes._setalpha(t,(.0103,.008,.0144,1),dil.outputs[0])
    color=passes._over(t,outline,r.outputs['Image']);t.links.new(color,out.inputs['Image'])

def render_all(name,root,animations,directions=None,resume=False):
    s=bpy.context.scene;base=ART/'renders/monsters'/name;base.mkdir(parents=True,exist_ok=True)
    diffuse_compositor(s)
    for anim,(start,count) in animations.items():
        folder=base/anim;folder.mkdir(exist_ok=True)
        for d in directions.get(anim,DIRS) if directions else DIRS:
            for i in range(count):
                pose(root,start+i,d);path=folder/f'{d}_{i:02d}.png'
                if resume and all(path.with_stem(path.stem+suffix).exists() for suffix in ('','_n','_e')):continue
                s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
                passes.render_normal_pass(path.with_stem(path.stem+'_n'),path,s)
                passes.render_emission_pass(path.with_stem(path.stem+'_e'),path,s)
                print('MONSTER_FRAME',anim,d,i,flush=True)
    pose(root,1,'s')




