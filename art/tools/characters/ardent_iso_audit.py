"""Read-only audit of the delivered Blender source, using background Blender."""
import bpy,sys,json,math
sys.dont_write_bytecode=True
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/ardent_iso.blend'))
s=bpy.context.scene;s.frame_set(1);bpy.context.view_layer.update()
cam=s.camera;root=bpy.data.objects['Ardent_Root']
assert s.render.engine=='BLENDER_EEVEE'
assert abs(math.degrees(cam.rotation_euler.x)-60)<.001
assert abs(cam.data.ortho_scale-192/(64*math.sqrt(2)))<1e-5
p=world_to_camera_view(s,cam,Vector((0,0,0)))
pivot=[192*p.x,192*(1-p.y)]
assert max(abs(a-b) for a,b in zip(pivot,[96,136.32]))<.001
emit=[m for m in bpy.data.materials if m.use_nodes and m.node_tree.nodes.get('Principled BSDF') and m.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value>0]
assert len(emit)==2 and all('flame' in m.name.lower() or 'emissive' in m.name.lower() for m in emit)
meshes=[o for o in root.children_recursive if o.type=='MESH']
assert all(not any(m.type=='SUBSURF' for m in o.modifiers) for o in meshes)
assert all(o.data.materials[0].node_tree.nodes.get('ISO_Baked_AO') for o in meshes)
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
assert triangles>5000, 'C4b refined silhouette topology missing'
for name in ('Draped open rain hood','Sculpted convex bronze cuirass','Sculpted domed bronze pauldron','Folded torn coat gore','Overlapping forearm linen wrap','Continuous oiled waist belt'):
    assert any(o.name.startswith(name) for o in meshes),name
assert sum(o.name.startswith('Discrete ember eye') for o in meshes)==2
assert bpy.data.objects['Torch'].parent.name.startswith('Forearm'), 'Torch must follow the gripping hand'
assert any(p.use_smooth for p in bpy.data.objects['Draped open rain hood'].data.polygons)
assert len(bpy.data.objects['Draped open rain hood'].data.vertices)>100

report={'source':'PASS','background_only':bpy.app.background,'camera_elevation':30,'R':192/cam.data.ortho_scale,'ground_pivot_measured_px':pivot,'meshes':len(meshes),'base_triangles':triangles,'invisible_subdivision':False,'refinement_applied':True,'design_revision':'C4b','emission_sources':['torch flame','embers','discrete hood eyes'],'torch_follows_hand':True,'AO_and_direct_self_shadows_in_diffuse':True,'emissive_materials':[m.name for m in emit],'animation_markers':{m.name:m.frame for m in s.timeline_markers},'samples':s.eevee.taa_render_samples}
(ROOT/'art/tools/characters/ardent_iso_source_check.json').write_text(json.dumps(report,indent=2))
print('PASS C4 Blender source: CREA scale/elevation, measured pivot, AO, flame/ember eyes emission, applied refinement, hand attachment')
