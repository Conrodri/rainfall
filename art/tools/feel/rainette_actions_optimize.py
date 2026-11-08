"""Existing pngquant tool, targeted action budgets; no pixel drawing."""
from pathlib import Path
import json,subprocess,shutil,zipfile
ROOT=Path(__file__).resolve().parents[3]
WORK=ROOT/'art/blender/cel/rainette_actions';BASE=ROOT/'game/assets/sprites/characters/rainette'
EXE=WORK/'bin/pngquant.exe'
if not EXE.exists():
    EXE.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(ROOT/'art/blender/characters/ardent_pngquant.zip') as z:
        for name in z.namelist():
            if name.endswith(('.exe','.dll')):(EXE.parent/Path(name).name).write_bytes(z.read(name))
before=json.loads((WORK/'before.json').read_text());sizes={}
for action in ('attack','spit','belch'):
    for suffix in ('','_e'):
        p=BASE/(action+suffix+'.png');budget=before[p.name]['bytes']*1.3
        if p.stat().st_size>budget:
            subprocess.run([str(EXE),'256','--quality=85-100','--speed','1','--nofs','--force','--ext','.png',str(p)],check=True,capture_output=True)
        assert p.stat().st_size<=budget,(p.name,p.stat().st_size,budget)
        sizes[p.name]=p.stat().st_size
for alias,action in {'cast':'spit','cast_ult':'belch'}.items():
    for suffix in ('','_e'):shutil.copy2(BASE/(action+suffix+'.png'),BASE/(alias+suffix+'.png'))
(WORK/'sizes.json').write_text(json.dumps(sizes))
print('PASS optimized',sizes)
