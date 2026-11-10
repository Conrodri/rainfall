import bpy
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
BLEND = os.path.join(ROOT, 'art', 'blender', 'storm_core_halo.blend')
PNG = os.path.join(ROOT, 'game', 'assets', 'sprites', 'pickups', 'storm_core_halo.png')

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.eevee.taa_render_samples = 16
scene.render.resolution_x = scene.render.resolution_y = 128
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.world.color = (0, 0, 0)

mat = bpy.data.materials.new('Storm Core | soft cyan radial emission')
mat.use_nodes = True
mat.surface_render_method = 'BLENDED'
n = mat.node_tree.nodes
L = mat.node_tree.links
n.clear()
out = n.new('ShaderNodeOutputMaterial')
geo = n.new('ShaderNodeNewGeometry')
ln = n.new('ShaderNodeVectorMath')
ln.operation = 'LENGTH'  # rayon 0..1 (plan de -1 a 1)
L.new(geo.outputs['Position'], ln.inputs[0])
ramp = n.new('ShaderNodeValToRGB')
ramp.color_ramp.interpolation = 'EASE'
ramp.color_ramp.elements[0].position = 0.0
ramp.color_ramp.elements[0].color = (0.85, 0.85, 0.85, 1)
ramp.color_ramp.elements[1].position = 1.0
ramp.color_ramp.elements[1].color = (0, 0, 0, 1)
e = ramp.color_ramp.elements.new(0.45)
e.color = (0.35, 0.35, 0.35, 1)
L.new(ln.outputs['Value'], ramp.inputs['Fac'])
em = n.new('ShaderNodeEmission')
em.inputs['Color'].default_value = (0x82 / 255, 0xD6 / 255, 0xE5 / 255, 1)
em.inputs['Strength'].default_value = 1.0
tr = n.new('ShaderNodeBsdfTransparent')
mix = n.new('ShaderNodeMixShader')
L.new(ramp.outputs['Color'], mix.inputs[0])
L.new(tr.outputs[0], mix.inputs[1])
L.new(em.outputs[0], mix.inputs[2])
L.new(mix.outputs[0], out.inputs['Surface'])

bpy.ops.mesh.primitive_plane_add(size=2, location=(0, 0, 0))
plane = bpy.context.object
plane.data.materials.append(mat)
cam_data = bpy.data.cameras.new('Halo Camera')
cam = bpy.data.objects.new('Halo Camera', cam_data)
scene.collection.objects.link(cam)
cam.location = (0, 0, 3)
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 2
scene.camera = cam
scene.render.filepath = PNG
os.makedirs(os.path.dirname(BLEND), exist_ok=True)
os.makedirs(os.path.dirname(PNG), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.render.render(write_still=True)
print('PASS storm_core_halo rendered 128x128 RGBA')
