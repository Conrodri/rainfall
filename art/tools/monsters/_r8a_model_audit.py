"""Read-only source audit; run only in background Blender."""
import bpy,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
assert bpy.app.background
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/monsters/ash_lord.blend'))
s=bpy.context.scene;root=bpy.data.objects['AshLord'];manifest=json.loads(s['animation_manifest'])
expected={'idle':(1,6),'run':(21,8),'attack':(41,6),'cast_a':(61,8),'cast_b':(81,8),'phase2':(101,8),'death':(121,10)}
assert s['iso_rig']=='CREA' and abs(math.degrees(s.camera.rotation_euler.x)-60)<.001
assert s.render.engine=='BLENDER_EEVEE' and s.eevee.taa_render_samples==16
assert s.render.resolution_x==s.render.resolution_y==340
assert all((manifest[a]['start'],manifest[a]['frames'])==v for a,v in expected.items())
assert {m.name for m in s.timeline_markers}==set(expected)
assert all(manifest[a]['directions']==(['e','s','w','n'] if a=='run' else ['s']) for a in manifest)
meshes=[o for o in root.children_recursive if o.type=='MESH']
polygons=sum(len(o.data.polygons) for o in meshes)
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
assert triangles<20000
assert all(m.node_tree.nodes.get('ISO_Baked_AO') for m in {slot.material for o in meshes for slot in o.material_slots if slot.material})
chains=[o for o in meshes if o.name.startswith('Black iron chain')]
assert all(o.material_slots[0].link=='OBJECT' for o in chains)
report={'status':'PASS','rig':s['iso_rig'],'elevation':30,'samples':16,'polygons':polygons,'triangles':triangles,'mesh_objects':len(meshes),'chain_shared_meshes':len({o.data.name for o in chains}),'animations':manifest}
Path(__file__).with_name('_r8a_model_audit.json').write_text(json.dumps(report,indent=2))
print('PASS source CREA 30deg, Eevee 16, timelines, AO, linked chains;',triangles,'triangles')
