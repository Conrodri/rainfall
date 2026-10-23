import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
for name,r in [('stone_colossus','StoneColossus')]:
 bpy.ops.wm.open_mainfile(filepath=str(ART/'blender/monsters'/f'{name}.blend'))
 render_all(name,bpy.data.objects[r],{'cast_b':ANIMS['cast_b']},DIRECTIONS)
