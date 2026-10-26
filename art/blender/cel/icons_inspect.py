import bpy,json
from pathlib import Path
r=Path(r'C:/Users/const/Documents/Rainfall');out={}
for name in ['i1_batch_1','i1_batch_5','i2_source_00_37','u2_source','ui_elements','ui_elements_part','ui_elements2_part','crit_icon']:
 p=r/'art/blender/ui'/f'{name}.blend'
 bpy.ops.wm.open_mainfile(filepath=str(p))
 out[name]=[{'name':s.name,'objects':len(s.objects),'size':[s.render.resolution_x,s.render.resolution_y],'path':s.render.filepath} for s in bpy.data.scenes]
(r/'art/blender/cel/icons_sources.json').write_text(json.dumps(out,indent=2))
print('PASS source inventory')
