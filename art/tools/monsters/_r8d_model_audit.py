"""R8d source validation, background Blender only; no source changes."""
import bpy,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
assert bpy.app.background
reports={}
expected={'idle':(1,6),'run':(21,8),'attack':(41,6),'cast_a':(61,8),'cast_b':(81,8),'phase2':(101,8),'death':(121,10)}
for name,rootname in [('frost_bear','FrostBear'),('stone_colossus','StoneColossus')]:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/monsters'/f'{name}.blend'))
    s=bpy.context.scene;root=bpy.data.objects[rootname];manifest=json.loads(s['animation_manifest'])
    assert s['iso_rig']=='CREA' and abs(math.degrees(s.camera.rotation_euler.x)-60)<.001
    assert s.render.engine=='BLENDER_EEVEE' and s.eevee.taa_render_samples==16
    assert s.render.resolution_x==s.render.resolution_y==340
    assert all((manifest[a]['start'],manifest[a]['frames'])==v for a,v in expected.items())
    assert {m.name for m in s.timeline_markers}==set(expected)
    assert all(manifest[a]['directions']==(['e','s','w','n'] if a=='run' else ['s']) for a in manifest)
    meshes=[o for o in root.children_recursive if o.type=='MESH']
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    assert triangles<22000,(name,triangles)
    materials={slot.material for o in meshes for slot in o.material_slots if slot.material}
    assert all(m.node_tree.nodes.get('ISO_Baked_AO') for m in materials)
    # Every mesh is a closed solid, including roots, wings, drones and eggs.
    import bmesh
    nonclosed=[]
    for o in meshes:
        bm=bmesh.new();bm.from_mesh(o.data)
        if any(not e.is_manifold for e in bm.edges):nonclosed.append(o.name)
        bm.free()
    assert not nonclosed,(name,nonclosed[:5])
    reports[name]={'status':'PASS','rig':'CREA','elevation':30,'samples':16,'triangles':triangles,'mesh_objects':len(meshes),'all_meshes_closed':True,'animations':manifest}
Path(__file__).with_name('_r8d_model_audit.json').write_text(json.dumps(reports,indent=2))
print('PASS R8d sources: CREA 30 degrees, Eevee 16, AO, timelines, enclosed volumes, polygon budgets')
