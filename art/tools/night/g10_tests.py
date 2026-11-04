"""G10 requested Godot checks; logs only, one-line result per check."""
from pathlib import Path
import subprocess,sys,time,json
ROOT=Path(__file__).resolve().parents[3]
WORK=ROOT/'art/blender/cel/g10'
GODOT=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
results={}
with (WORK/'budget.log').open('w') as f:
    p=subprocess.run([sys.executable,str(ROOT/'art/tools/texture_budget.py')],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
results['texture_budget.py']=p.returncode==0
for scene in ('sprites_test','minibosses_test','miniboss_mechanics_test','texture_budget_test'):
    path=WORK/(scene+'.log')
    for attempt in range(2):
        with path.open('w') as f:
            try:
                p=subprocess.run([GODOT,'--headless','--fixed-fps','60','--path',str(ROOT/'game'),'res://tests/'+scene+'.tscn'],stdout=f,stderr=subprocess.STDOUT,timeout=600)
            except subprocess.TimeoutExpired:
                results[scene]=False;break
        log=path.read_text(errors='replace')
        if ('lock' in log.lower()) and attempt==0: time.sleep(30);continue
        results[scene]=p.returncode==0 and 'RESULT: OK' in log;break
    print(scene+': '+('RESULT: OK' if results[scene] else 'FAIL'),flush=True)
(WORK/'tests.json').write_text(json.dumps(results,indent=2))
sys.exit(0 if all(results.values()) else 1)
