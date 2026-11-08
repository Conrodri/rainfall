"""Inspect the saved action copy: emission keys, smear state and render contract."""
import sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/feel'))
from vigie_actions_build import WORK,ANIMS,HITS
import bpy
bpy.ops.wm.open_mainfile(filepath=str(WORK/'vigie.blend'))
s=bpy.context.scene
m=bpy.data.materials['Vigie_DISTRESS_RED']
nd=next(n for n in m.node_tree.nodes if n.type=='OUTPUT_AOV')
ghosts=[o for o in s.objects if o.name.startswith(('Blackened_longbow_limb_','Emissive_hemp_bowstring_','R_thin_sleeve','R_forearm_oilskin','R_gaunt_hand')) and o.data and any(ma and ma.name.startswith('Translucent action ghost') for ma in o.data.materials)]
report={}
assert s.render.engine=='CYCLES' or s.render.engine=='BLENDER_EEVEE'
assert s.render.engine=='BLENDER_EEVEE' and s.eevee.taa_render_samples==8
for ai,(a,n) in enumerate(ANIMS.items()):
    s.frame_set(ai*20+1);base=tuple(nd.inputs['Color'].default_value)
    factors=[];smear=[]
    for f in range(n):
        s.frame_set(ai*20+1+f)
        factor=nd.inputs['Color'].default_value[0]/base[0]
        assert abs(factor-(2 if f==HITS[a] else 1))<1e-5,(a,f,factor)
        visible=sum(not o.hide_render for o in ghosts)
        assert bool(visible)==(a!='attack' and f==HITS[a]-1),(a,f,visible)
        factors.append(round(factor,2));smear.append(visible)
    report[a]={'emission_factors':factors,'smear_objects':smear}
assert all('_n__' not in getattr(n,'file_name','') for n in s.compositing_node_group.nodes if n.type=='OUTPUT_FILE')
(WORK/'blend_verification.json').write_text(json.dumps(report,indent=2))
print('PASS Eevee 8; emission x2; one smear before impact; no normal output',flush=True)
