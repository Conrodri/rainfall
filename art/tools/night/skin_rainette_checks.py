"""Read-only Godot validation; temporary text resource, no game script changes."""
from pathlib import Path
import sys, json, subprocess, tempfile, zipfile
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
sys.path[:0]=[str(ROOT/'art/tools/cel'),str(ROOT/'art/tools')]
import cel_style as cel
import texture_budget as budget

def run(label,args):
    result=subprocess.run([cel.GODOT,'--headless','--path',str(ROOT/'game')]+args,capture_output=True,text=True,encoding='utf8',errors='replace',timeout=240)
    output=result.stdout+result.stderr
    (HERE/('_skin_rainette_'+label+'.log')).write_text(output,encoding='utf8')
    errors=[line for line in output.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR' in line]
    print(label,'exit',result.returncode,'errors',len(errors),*[line for line in output.splitlines() if 'RESULT:' in line][:1])
    return {'exit':result.returncode,'errors':errors,'result_ok':'RESULT: OK' in output}

def main():
    report={}
    report['import']=run('import',['--import'])
    for name in ('sprites_test','rainette_test','texture_budget_test'):
        report[name]=run(name,['res://tests/'+name+'.tscn'])
    code='''extends SceneTree
func _initialize():
    var a = load("res://assets/sprites/characters/rainette/rainette.tres")
    var b = load("res://assets/sprites/characters/rainette/skins/rainette_skin1/rainette_skin1.tres")
    if not b is SpriteFrames or not a is SpriteFrames:
        print("RESULT: FAIL type")
        quit(1)
        return
    if a.get_animation_names() != b.get_animation_names():
        print("RESULT: FAIL animations")
        quit(1)
        return
    for n in a.get_animation_names():
        if a.get_frame_count(n) != b.get_frame_count(n) or a.get_animation_speed(n) != b.get_animation_speed(n) or a.get_animation_loop(n) != b.get_animation_loop(n):
            print("RESULT: FAIL metadata")
            quit(1)
            return
    print("RESULT: OK SpriteFrames ", b.get_animation_names().size())
    quit(0)
'''
    with tempfile.TemporaryDirectory(prefix='rainette_check_') as d:
        p=Path(d)/'check.zip'
        with zipfile.ZipFile(p,'w') as z:
            z.writestr('project.godot',(ROOT/'game/project.godot').read_bytes())
            z.writestr('_rainette_check.gd',code)
        report['skin_load']=run('skin_load',['--main-pack',str(p),'--script','res://_rainette_check.gd'])
    rows=budget.scan();category=[r for r in rows if r['cat']=='characters/rainette'];skin=[r for r in category if '/skins/rainette_skin1/' in r['path']]
    report['budget']={'category':{k:sum(r[k] for r in category)/budget.MB for k in ('png','mobile')},'skin_added':{k:sum(r[k] for r in skin)/budget.MB for k in ('png','mobile')},'total_mobile':sum(r['mobile'] for r in rows)/budget.MB}
    (HERE/'_skin_rainette_checks.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print('BUDGET',json.dumps(report['budget']))

if __name__=='__main__':
    if '--probe' in sys.argv:
        with tempfile.TemporaryDirectory(prefix='rainette_probe_') as d:
            p=Path(d)/'probe.zip'
            code='extends SceneTree\nfunc _initialize():\n    print("RESULT: OK")\n    quit()\n'
            with zipfile.ZipFile(p,'w') as z:
                z.writestr('project.godot',(ROOT/'game/project.godot').read_bytes())
                z.writestr('_rainette_check.gd',code)
            print(run('probe',['--main-pack',str(p),'--script','res://_rainette_check.gd']))
    else:main()
