"""Batch interactif MCP : une frame par tick, progression et reprise inspectables."""
import bpy, json, traceback
from pathlib import Path
NS={'__name__':'ardent_batch_build'}
BASE=Path(r'C:\Users\const\Documents\Rainfall\art')
exec(compile((BASE/'tools/ardent_build.py').read_text(encoding='utf-8-sig'),'ardent_build.py','exec'),NS)
JOBS=[(kind,anim,d,i) for kind in ['diffuse','normal','emission'] for anim in ['idle','run'] for d in NS['DIRS'] for i in range(8)]
INDEX=0

def tick():
    global INDEX
    try:
        assert Path(bpy.data.filepath)==NS['BLEND'],'Active blend changed: stop without saving'
        kind,anim,d,i=JOBS[INDEX]
        NS['render_one'](anim,d,i,kind)
        INDEX+=1
        progress={'completed':INDEX,'total':len(JOBS),'last':[kind,anim,d,i],'status':'running'}
        if INDEX==len(JOBS):
            bpy.context.scene.frame_set(1);bpy.data.objects['Ardent_Root'].rotation_euler.z=0
            bpy.ops.wm.save_as_mainfile(filepath=str(NS['BLEND']))
            progress['status']='complete'
        (BASE/'renders/ardent/progress.json').write_text(json.dumps(progress))
        return .05 if INDEX<len(JOBS) else None
    except Exception:
        (BASE/'renders/ardent/progress.json').write_text(json.dumps({'completed':INDEX,'status':'error','error':traceback.format_exc()}))
        return None

bpy.ops.wm.save_as_mainfile(filepath=str(NS['BLEND']))
bpy.app.timers.register(tick,first_interval=.5)
