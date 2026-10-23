"""Sequential R5c render/pack, with the original SpriteFrames preserved byte for byte."""
import subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];TOOLS=Path(__file__).resolve().parent
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
SPECS=['idle:10','run:12','attack:12','cast_a:12','cast_b:12','phase2:8:noloop','death:12:noloop']
for name in sys.argv[1:] or ['frost_bear','rust_archon','stone_colossus']:
    path=TOOLS/f'_r5c_{name}_pipeline.log'
    with path.open('w') as log:
        subprocess.run([BLENDER,'--background','--python',str(TOOLS/'r5c_render.py'),'--',name],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
        assert f'DONE {name}' in path.read_text(), 'Blender script failed; see log'
        subprocess.run([sys.executable,str(TOOLS/'pack_monsters.py'),'bosses/mini',name,'170',*SPECS,'--anim-dirs','run=e,s,w,n','--preserve-tres'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    subprocess.run([sys.executable,str(TOOLS/'r5c_inventory.py'),'--check'],cwd=ROOT,check=True)
    print('PASS complete',name,flush=True)
