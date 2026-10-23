"""Numerical atlas/anchor verification and Godot loading; no workspace GDScript.
Run with system Python after m2_build.py. Pillow is used only for verification.
"""
import json, hashlib, subprocess, tempfile
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
GODOT=Path(r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe')
ASSETS=ROOT/'game/assets/sprites/characters'
ANIMS={'rictus':{'idle':8,'run':8,'slash':4,'throw':4,'spin':8,'stagger':3,'summon':6,'lift':3,'death':6,'throw_ult':6},'montreur':{'hover':6,'pull':4}}
DIRS=['e','se','s','sw','w','nw','n','ne']
report={'frames':0,'sheets':0,'clipped':[],'static':[],'alpha_bounds':{}}
manifest=json.loads((ASSETS/'rictus/strings.json').read_text())
for actor,anims in ANIMS.items():
    for a,n in anims.items():
        dirs=['e'] if a=='spin' else DIRS
        hashes={d:set() for d in dirs};union=[192,192,0,0]
        for suffix in ('','_n','_e'):
            with Image.open(ASSETS/actor/(a+suffix+'.png')) as im:
                assert im.mode=='RGBA' and im.size==(n*192,len(dirs)*192),(actor,a,suffix,im.size)
                report['sheets']+=1
                for row,d in enumerate(dirs):
                    for i in range(n):
                        frame=im.crop((i*192,row*192,(i+1)*192,(row+1)*192))
                        if suffix:continue
                        report['frames']+=1;b=frame.getchannel('A').getbbox();assert b,(actor,a,d,i,'empty')
                        union=[min(union[0],b[0]),min(union[1],b[1]),max(union[2],b[2]),max(union[3],b[3])]
                        if min(b[:2])<2 or max(b[2:])>190:report['clipped'].append([actor,a,d,i,b])
                        hashes[d].add(hashlib.sha256(frame.tobytes()).hexdigest())
                        points=manifest[actor][a][d][i]
                        assert len(points)==5
                        for p in points.values():assert 0<p[0]+96<192 and 0<p[1]+136.32<192,(actor,a,d,i,p)
        report['alpha_bounds'][actor+'/'+a]=union
        for d,unique in hashes.items():
            if len(unique)!=n:report['static'].append([actor,a,d,len(unique),n])
assert report['frames']==472
assert not report['clipped'],report['clipped'][:5]
assert not report['static'],report['static'][:5]
for a in ('slash','throw','summon','throw_ult'):
    n=ANIMS['rictus'][a]
    for frames in manifest['animations'][a].values():
        assert frames[n//2]['frame']==n//2
gd='''extends SceneTree
func _initialize():
    var total := 0
    for actor in ["rictus", "montreur"]:
        var sf = load("res://assets/sprites/characters/" + actor + "/" + actor + ".tres")
        assert(sf is SpriteFrames)
        for anim in sf.get_animation_names():
            if String(anim).begins_with("death_"):
                assert(not sf.get_animation_loop(anim))
            for frame in range(sf.get_frame_count(anim)):
                var tex = sf.get_frame_texture(anim, frame)
                assert(tex is AtlasTexture and tex.atlas is CanvasTexture)
                assert(tex.atlas.diffuse_texture != null and tex.atlas.normal_texture != null)
                assert(tex.region.size == Vector2(192, 192))
                total += 1
    assert(total == 472)
    print("M2 LOAD RESULT: OK / ", total, " frames / CanvasTexture diffuse+normal / death non-looping")
    quit()
'''
with tempfile.TemporaryDirectory(prefix='rainfall_m2_') as temp:
    script=Path(temp)/'m2_load.gd';script.write_text(gd,encoding='utf8')
    for label,args in [('import',['--editor','--import']),('load',['--script',str(script)]),('sprites_test',['res://tests/sprites_test.tscn'])]:
        cmd=[str(GODOT),'--headless','--path',str(ROOT/'game')]+args
        if label=='import':cmd+=['--quit']
        result=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf8',errors='replace',timeout=180)
        (HERE/('_m2b_'+label+'.log')).write_text(result.stdout,encoding='utf8')
        errors=[line for line in result.stdout.splitlines() if 'ERROR:' in line or 'SCRIPT ERROR' in line]
        if label=='import':
            report['editor_shutdown_diagnostics']=errors
            errors=[e for e in errors if 'resources still in use at exit' not in e and 'Pages in use exist at exit' not in e]
        assert result.returncode==0 and not errors,(label,result.returncode,errors[:3])
        if label=='load':assert 'M2 LOAD RESULT: OK' in result.stdout
        if label=='sprites_test':assert 'RESULT: OK' in result.stdout
        report[label]='PASS'
(HERE/'_m2b_verification.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('PASS M2: 472 animated frames, 36 RGBA sheets, anchors, margins, Godot loads, sprites_test RESULT: OK')
