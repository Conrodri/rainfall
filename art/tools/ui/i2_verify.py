"""Inspect the delivered Blender source without rendering or changing it."""
import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
source=ROOT/'art/blender/ui/i2_source_00_37.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
rows=[]
for s in bpy.data.scenes:
 if not s.name.startswith('i2_'):continue
 objects=[o for o in s.objects if o.type in {'MESH','CURVE'}]
 mats={m for o in objects for m in o.data.materials if m and m.use_nodes}
 metals=[m for m in mats if m.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value==1]
 env=[n for n in s.world.node_tree.nodes if n.type=='TEX_ENVIRONMENT']
 row={'scene':s.name,'geometry':len(objects),'bevels':sum(m.type=='BEVEL' for o in objects for m in o.modifiers),'subdivisions':sum(m.type=='SUBSURF' for o in objects for m in o.modifiers),'true_metals':len(metals),'packed_hdri':bool(env and env[0].image.packed_file),'engine':s.render.engine,'samples':s.eevee.taa_render_samples,'view':s.view_settings.view_transform,'look':s.view_settings.look,'transparent':s.render.film_transparent,'area_lights':sum(o.type=='LIGHT' and o.data.type=='AREA' for o in s.objects)}
 assert row['geometry'] and row['true_metals'] and row['packed_hdri'] and row['transparent'] and row['area_lights']==3,row
 assert row['engine']=='BLENDER_EEVEE' and row['samples']==24 and row['view']=='AgX' and 'Medium High' in row['look'],row
 rows.append(row)
assert len(rows)==37,len(rows)
(ROOT/'art/tools/ui/_i2_geometry.json').write_text(json.dumps({'status':'PASS','scenes':rows},indent=2))
print('PASS 37 source scenes: PBR metals, packed HDRI, studio lights, Eevee, AgX, transparency')
