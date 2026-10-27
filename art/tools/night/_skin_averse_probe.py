import bpy
from pathlib import Path
with bpy.data.libraries.load(str(Path('art/blender/characters/averse.blend').resolve()),link=False) as (a,b):b.objects=a.objects
print('SURFACES',[(o.name,[s.material.name for s in o.material_slots if s.material]) for o in bpy.data.objects if any(k in o.name.lower() for k in ('hood','amph','crack','lining','glove','hand','silver','rim','band'))])
