import subprocess,json,re
from pathlib import Path
r=Path(r'C:/Users/const/Documents/Rainfall');here=r/'art/tools/night';godot=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe';results={}
for name in ['import','sprites','loot_ui','chest_reveal','ui_theme','texture_budget']:
 args=[godot,'--headless','--path',str(r/'game')]+(['--import'] if name=='import' else [f'res://tests/{name}_test.tscn'])
 log=here/f'_cel_icons_final_{name}.log'
 with log.open('w',encoding='utf-8') as f:
  try: proc=subprocess.run(args,cwd=r,stdout=f,stderr=subprocess.STDOUT,timeout=180,creationflags=subprocess.CREATE_NO_WINDOW);code=proc.returncode
  except subprocess.TimeoutExpired:code=-1
 txt=log.read_text(errors='replace');errs=[s for s in txt.splitlines() if re.search(r'ERROR:|SCRIPT ERROR:|Parse Error:',s)];ok=code==0 and (name=='import' or 'RESULT: OK' in txt) and not errs
 results[name]={'ok':ok,'returncode':code,'errors':errs[:5],'result_ok':'RESULT: OK' in txt};print(name,'PASS' if ok else 'FAIL',flush=True)
(here/'_cel_icons_godot.json').write_text(json.dumps(results,indent=2))
assert all(x['ok'] for x in results.values()),results
