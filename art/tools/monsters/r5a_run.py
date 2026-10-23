"""Sequential R5a render/pack driver. Swarm render has already completed."""
import subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
TOOLS=Path(__file__).resolve().parent
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
SPECS=[('swarm_tier1',96,['run:14']),('shooter_tier2',112,['run:14','attack:12:noloop']),('leaper_tier2',112,['run:14','charge:12:noloop']),('brute_tier3',160,['run:12','attack:12:noloop','cast:12:noloop'])]
for name,size,anims in SPECS:
    with (TOOLS/f'_r5a_{name}_pipeline.log').open('w') as log:
        if name!='swarm_tier1':
            subprocess.run([BLENDER,'--background','--python',str(TOOLS/'lowcam_monster.py'),'--',name],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
            assert f'DONE {name}' in (TOOLS/f'_r5a_{name}_pipeline.log').read_text(), 'Blender script failed'
        subprocess.run([sys.executable,str(TOOLS/'pack_monsters.py'),'monsters',name,str(size),*anims,'--dirs','--preserve-tres'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    subprocess.run([sys.executable,str(TOOLS/'r5a_inventory.py'),'--check'],cwd=ROOT,check=True)
    print('PASS complete',name,flush=True)
