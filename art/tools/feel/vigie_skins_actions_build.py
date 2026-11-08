"""Render existing skin materials with the shared Vigie action solver; targeted audit."""
import sys, os, json, re, hashlib, shutil, subprocess
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'game/assets/sprites/characters/vigie'
WORK=ROOT/'art/blender/cel/skins/vigie_actions_audit'
WORK.mkdir(parents=True,exist_ok=True)
ANIMS={'attack':5,'flare':6,'net':5,'volley':8}
ALIASES={'cast':'flare','cast_ult':'volley'}
SKINS={'vigie_skin1':'art/tools/night/skin_vigie_build.py','vigie_avant_la_pluie':'art/tools/cosmetics/panoplie_vigie_avant_la_pluie_build.py'}
BLENDER='C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def outside():
    parent=ROOT.parents[2]
    assert parent.name=='Rainfall',parent
    result=[]
    for directory,dirs,files in os.walk(parent):
        dirs[:]=[d for d in dirs if Path(directory,d)!=ROOT]
        result.extend(str(Path(directory,f)) for f in files)
    return sorted(result)
def snapshot():
    data={'outside':outside(),'skins':{}}
    for skin in SKINS:
        folder=BASE/'skins'/skin
        data['skins'][skin]={p.name:{'bytes':p.stat().st_size,'sha':sha(p)} for p in folder.iterdir() if p.is_file()}
        # Tracked originals for action sheets; renderer may already have assembled one.
        for name in data['skins'][skin]:
            if name.removesuffix('.png').removesuffix('_e') not in {*ANIMS,*ALIASES}:continue
            original=subprocess.run(['git','show','HEAD:'+str((folder/name).relative_to(ROOT)).replace('\\','/')],cwd=ROOT,capture_output=True,check=True).stdout
            data['skins'][skin][name]={'bytes':len(original),'sha':hashlib.sha256(original).hexdigest()}
    (WORK/'before.json').write_text(json.dumps(data))
    print('PASS baseline')
def entries(s):
    body=s[s.index('animations = [')+len('animations = ['):]
    result=[];depth=0
    for i,c in enumerate(body):
        if c=='{':
            if depth==0:start=i
            depth+=1
        elif c=='}':
            depth-=1
            if depth==0:result.append(body[start:i+1])
    return result
def is_action(e):
    return re.search(r'"name"\s*:\s*&?"([^"]+)"',e).group(1).rsplit('_',1)[0] in {*ANIMS,*ALIASES}
def resources(path,base):
    raw=path.read_bytes();nl='\r\n' if b'\r\n' in raw else '\n'
    s=raw.decode().replace('\r\n','\n');b=base.read_text()
    ext=re.findall(r'\[ext_resource[^\]]+\]',s)
    def extmap(text):
        return {re.search(r'id="([^"]+)"',e).group(1):Path(re.search(r'path="([^"]+)"',e).group(1)).name for e in re.findall(r'\[ext_resource[^\]]+\]',text)}
    skinids={v:k for k,v in extmap(s).items()};baseids=extmap(b)
    pattern=r'\[sub_resource[^\]]*id="([^"]+)"\][\s\S]*?(?=\n\[|\Z)'
    oldsubs={m.group(1):m.group(0).rstrip() for m in re.finditer(pattern,s)}
    basesubs={m.group(1):m.group(0).rstrip() for m in re.finditer(pattern,b)}
    kept=[e for e in entries(s) if not is_action(e)]
    needed=set(re.findall(r'SubResource\("([^"]+)"\)',','.join(kept)))
    subs=[v for k,v in oldsubs.items() if k in needed]
    new=[e for e in entries(b) if is_action(e)]
    seen=set()
    for sid in re.findall(r'SubResource\("([^"]+)"\)',','.join(new)):
        if sid in seen:continue
        seen.add(sid);block=basesubs[sid].replace('id="'+sid+'"','id="skin_'+sid+'"')
        block=re.sub(r'ExtResource\("([^"]+)"\)',lambda m:'ExtResource("'+skinids[baseids[m[1]]]+'")',block)
        subs.append(block)
    new=[re.sub(r'SubResource\("([^"]+)"\)',lambda m:'SubResource("skin_'+m[1]+'")',e) for e in new]
    header=re.search(r'^\[gd_resource[^\]]+\]',s).group(0)
    header=re.sub(r'load_steps=\d+','load_steps='+str(len(ext)+len(subs)+1),header)
    result=header+'\n\n'+'\n\n'.join(ext)+'\n\n'+'\n\n'.join(subs)+'\n\n[resource]\nanimations = [\n'+',\n'.join(kept+new)+'\n]\n'
    path.write_bytes(result.replace('\n',nl).encode())
    assert [e for e in entries(path.read_text()) if not is_action(e)]==kept
    assert ('\r\n' in path.read_bytes().decode())==(nl=='\r\n')
def optimize(path,budget):
    if path.stat().st_size<=budget:return
    original=Image.open(path).convert('RGBA')
    for colors in (256,192,128,96,64,48,32):
        original.quantize(colors=colors,method=Image.Quantize.FASTOCTREE,dither=Image.Dither.NONE).save(path,optimize=True,compress_level=9)
        if path.stat().st_size<=budget:return
    raise AssertionError(('budget',str(path),path.stat().st_size,budget))
def finish():
    before=json.loads((WORK/'before.json').read_text());report={};contact=Image.new('RGBA',(1024,4*64))
    for si,skin in enumerate(SKINS):
        folder=BASE/'skins'/skin;old=before['skins'][skin];report[skin]={}
        for a,n in ANIMS.items():
            p=folder/(a+'.png');optimize(p,old[p.name]['bytes']*1.3)
            shutil.copy2(BASE/(a+'_e.png'),folder/(a+'_e.png'))
            with Image.open(p) as im:
                assert im.size==Image.open(BASE/p.name).size==(192*n,1536)
                rgba=np.array(im.convert('RGBA'));hashes=[]
                for row in range(8):
                    frames=[]
                    for f in range(n):
                        tile=rgba[row*192:(row+1)*192,f*192:(f+1)*192]
                        assert (tile[:,:,3]>0).sum()>60,(skin,a,row,f)
                        rgb=tile[:,:,:3][tile[:,:,3]>128];assert np.ptp(rgb.astype(int))>20
                        frames.append(hashlib.sha256(tile.tobytes()).hexdigest())
                    assert len(set(frames))==n,(skin,a,row,'duplicate')
                    hashes.extend(frames)
                # One row per action, southeast; two skins, all frames at 64 px.
                for f in range(n):
                    tile=im.crop((f*192,192,(f+1)*192,384)).resize((64,64),Image.Resampling.LANCZOS)
                    contact.paste(tile,(si*512+f*64,list(ANIMS).index(a)*64))
            e=folder/(a+'_e.png');assert sha(e)==sha(BASE/e.name)
            with Image.open(e) as em:
                assert em.size==(96*n,768);assert np.array(em.convert('RGB')).max()>0
            assert e.stat().st_size<=old[e.name]['bytes']*1.3,('emission budget',str(e))
            report[skin][a]={'before':old[p.name]['bytes'],'after':p.stat().st_size,'emission_before':old[e.name]['bytes'],'emission_after':e.stat().st_size}
        for alias,a in ALIASES.items():
            for suffix in ('','_e'):
                p=folder/(alias+suffix+'.png')
                if p.exists():shutil.copy2(folder/(a+suffix+'.png'),p);assert p.stat().st_size<=old[p.name]['bytes']*1.3
        for filename in (skin+'.tres',skin+'_emission.tres'):
            p=folder/filename;base=BASE/('vigie_emission.tres' if 'emission' in filename else 'vigie.tres')
            if p.exists():resources(p,base)
        allowed={a+s+'.png' for a in [*ANIMS,*ALIASES] for s in ('','_e')}|{skin+'.tres',skin+'_emission.tres'}
        for name,meta in old.items():
            if name not in allowed:assert sha(folder/name)==meta['sha'],('untouched',skin,name)
        assert not list(folder.glob('*_n.png'))
        assert not any(t in (folder/(skin+'.tres')).read_text() for t in ('CanvasTexture','normal_texture'))
    target=ROOT/'art/renders/feel_sorts2/after_vigie_skins.png';target.parent.mkdir(parents=True,exist_ok=True);contact.save(target,optimize=True)
    new=set(outside())-set(before['outside']);assert not new,('outside new files',sorted(new)[:5])
    (WORK/'report.json').write_text(json.dumps(report,indent=2));print('PASS dimensions alpha contrast distinct frames emission SHA256 budgets untouched files outside worktree; '+json.dumps(report))
def render():
    for skin,script in SKINS.items():
        with (WORK/(skin+'.log')).open('w') as log:
            subprocess.run([BLENDER,'--background','--python',str(ROOT/script),'--','--render','--actions'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    finish()
if __name__=='__main__':
    if '--snapshot' in sys.argv:snapshot()
    elif '--finish' in sys.argv:finish()
    else:render()

