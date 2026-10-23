"""Render saved mini-boss scenes without rebuilding. Background Blender only."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
assert bpy.app.background
names=sys.argv[sys.argv.index('--')+1:]
samples='--samples' in names
for name in [n for n in names if not n.startswith('--')]:
    bpy.ops.wm.open_mainfile(filepath=str(ART/'blender/monsters'/f'{name}.blend'))
    root=bpy.data.objects[{'stone_colossus':'StoneColossus','frost_bear':'FrostBear','rust_archon':'RustArchon','ash_lord':'AshLord','bramble_queen':'BrambleQueen','brood_mother':'BroodMother'}[name]]
    if samples:
        render_all(name,root,{'idle':(1,1)},{'idle':['s']},resume=('--resume' in names if name in ('ash_lord','bramble_queen','brood_mother','rust_archon','frost_bear','stone_colossus') else True))
    else:render_all(name,root,ANIMS,DIRECTIONS,resume=('--resume' in names if name in ('ash_lord','bramble_queen','brood_mother','rust_archon','frost_bear','stone_colossus') else True))
