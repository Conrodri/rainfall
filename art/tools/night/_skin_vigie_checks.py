"""Scoped import policy and headless checks; never edits game scripts/default assets."""
import sys, subprocess, tempfile, json, os
from pathlib import Path
from skin_vigie_build import ROOT,OUT,HERE,GODOT,BASE
sys.path.insert(0,str(ROOT/'art/tools'))
import texture_budget as budget
walk=os.walk
try:
    budget.os.walk=lambda path:walk(OUT)
    budget.main(['--apply-policy'])
finally:budget.os.walk=walk
results={}
def run(name,args):
    p=subprocess.run([GODOT,'--headless','--path',str(ROOT/'game'),*args],cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf8',errors='replace',timeout=240)
    (HERE/('_skin_vigie_'+name+'.log')).write_text(p.stdout,encoding='utf8')
    errors=[l for l in p.stdout.splitlines() if 'ERROR:' in l or 'SCRIPT ERROR' in l]
    results[name]={'exit':p.returncode,'errors':errors,'result':[l for l in p.stdout.splitlines() if 'RESULT:' in l]}
    print(name+': '+str(results[name]),flush=True)
run('import',['--import'])
for name in ('sprites','vigie','texture_budget'):run(name,['res://tests/'+name+'_test.tscn'])
# Temporary external test, removed immediately; no .gd or .tscn delivered/modified.
fd,p=tempfile.mkstemp(suffix='.gd',prefix='vigie_skin_load_');os.close(fd)
try:
    Path(p).write_text('extends SceneTree\nfunc _initialize():\n var a=load("res://assets/sprites/characters/vigie/vigie.tres")\n var b=load("res://assets/sprites/characters/vigie/skins/vigie_skin1/vigie_skin1.tres")\n if a is SpriteFrames and b is SpriteFrames and a.get_animation_names()==b.get_animation_names():\n  print("RESULT: OK")\n  quit(0)\n else:\n  print("RESULT: FAIL")\n  quit(1)\n')
    run('load',['--script',p])
finally:Path(p).unlink(missing_ok=True)
(HERE/'_skin_vigie_headless.json').write_text(json.dumps(results,indent=2))
p=subprocess.run([sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--json',str(HERE/'_skin_vigie_budget_after.json')],cwd=ROOT,stdout=subprocess.PIPE,text=True,encoding='utf8',errors='replace')
before=json.loads((HERE/'_skin_vigie_budget_before.json').read_text());after=json.loads((HERE/'_skin_vigie_budget_after.json').read_text())
a=before['categories']['characters/vigie'];b=after['categories']['characters/vigie']
print('BUDGET before '+str(a)+' after '+str(b));print('DELTA '+str({k:(b[k]-a[k])/1048576 for k in ('png','mobile')}));print('GLOBAL mobile '+str(after['total']['mobile']/1048576))
