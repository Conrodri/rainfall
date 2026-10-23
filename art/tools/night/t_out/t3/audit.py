"""T3 independent asset and resource audit. No Blender and no image drawing."""
import sys, json, re
from pathlib import Path
sys.path.insert(0,str(Path.home()/'AppData/Local/RainfallIsoDeps'))
from PIL import Image, ImageChops
ROOT=Path(__file__).resolve().parents[5]
GAME=ROOT/'game/assets/sprites/characters/tocsin'
OUT=Path(__file__).parent
DIRECTIONS=['e','se','s','sw','w','nw','n','ne']
COUNTS={'throw_arm_l':4,'throw_arm_r':4,'throw_leg_l':4,'throw_leg_r':4,'throw_head':6,'death':6,'attack':6,'cast':6,'cast_ult':6,'neck_steam':6}
errors=[]; cells=0; absent=0; normal_checks=0
for anim,n in COUNTS.items():
    folder=OUT/anim
    for d in DIRECTIONS:
        for p in (folder/d).glob('*.png'):
            if p.stem.endswith(('_n','_e')): continue
            with Image.open(p) as im:
                assert im.size==(192,192),str(p)
                a=im.getchannel('A'); box=a.getbbox()
            cells+=1
            if box and (min(box[:2])<3 or max(box[2:])>189): errors.append('clipped '+str(p)+' '+str(box))
            if box is None:
                absent+=1
                i=int(p.stem[-2:]); part=p.stem[:-3]
                allowed=anim.startswith('throw_') and part==anim[6:] and i>=(3 if part=='head' else 2) or anim=='cast_ult' and part=='head' and i>=3
                if not allowed: errors.append('unexpected empty '+str(p))
            normal=p.with_name(p.stem+'_n.png')
            if not normal.exists(): errors.append('missing normal '+str(p)); continue
            with Image.open(normal) as im:
                if ImageChops.difference(a,im.getchannel('A')).getbbox(): errors.append('normal alpha '+str(p))
            normal_checks+=1
    for suffix in ('','_n','_e'):
        p=GAME/(anim+suffix+'.png')
        if not p.exists():
            if suffix!='_e' or anim!='neck_steam': errors.append('missing atlas '+str(p))
            continue
        with Image.open(p) as im:
            if im.size!=(n*192,1536): errors.append('size '+str(p))
for anim in ('throw_arm_l','throw_arm_r','throw_leg_l','throw_leg_r','throw_head'):
    part=anim[6:]; release=3 if part=='head' else 2
    with Image.open(GAME/'layers'/part/(anim+'.png')) as im:
        for row,d in enumerate(DIRECTIONS):
            for i in range(COUNTS[anim]):
                blank=im.crop((i*192,row*192,(i+1)*192,row*192+192)).getchannel('A').getbbox() is None
                if blank!=(i>=release): errors.append('release '+anim+'/'+d+'/'+str(i))
for s in ('','_n','_e'):
    with Image.open(GAME/('regen_rivets'+s+'.png')) as im:
        if im.size!=(1152,192): errors.append('regen size')
        if s=='' and len({im.crop((i*192,0,(i+1)*192,192)).tobytes() for i in range(6)})!=6:
            errors.append('regen must have six distinct frames')
        for i in range(6):
            if not im.crop((i*192,0,(i+1)*192,192)).getchannel('A').getbbox(): errors.append('regen blank')
paths=sorted(GAME.glob('*.tres'))
for p in paths:
    src=p.read_text()
    for rel in re.findall(r'path="res://([^"]+)"',src):
        if not (ROOT/'game'/rel).exists(): errors.append('missing referenced '+rel)
    if p.name=='tocsin.tres':
        for anim in COUNTS:
            for d in DIRECTIONS:
                if '&"'+anim+'_'+d+'"' not in src: errors.append('missing animation '+anim+'_'+d)
# Embedded GDScript in a .tres follows the prior T2 audit without any .gd/.tscn.
code='extends SceneTree\nfunc _initialize() -> void:\n    var errors := 0\n    var count := 0\n'
for p in paths:
    rel='res://'+p.relative_to(ROOT/'game').as_posix()
    code+='    if not ResourceLoader.load('+json.dumps(rel)+') is SpriteFrames:\n        errors += 1\n    count += 1\n'
code+='    print("T3_RESOURCES: ", count, " loaded; errors=", errors)\n    quit(0 if errors == 0 else 1)\n'
(OUT/'verify_resources.tres').write_text('[gd_resource type="GDScript" format=3]\n\n[resource]\nscript/source = '+json.dumps(code)+'\n')
report={'result':'PASS' if not errors else 'FAIL','layer_cells':cells,'intentionally_absent':absent,'normal_alpha_checks':normal_checks,'SpriteFrames':len(paths),'errors':errors}
(OUT/'audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='errors'})); print('\n'.join(errors[:8]))
sys.exit(bool(errors))
