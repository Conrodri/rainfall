"""Targeted Rainette skin action export, budgets and structural verification."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'game/assets/sprites/characters/rainette'
OUT=BASE/'skins/rainette_skin1'
REPORT=ROOT/'art/renders/feel_sorts2'
ACTIONS={'attack':7,'spit':6,'belch':7,'cast':6,'cast_ult':7}
F60={'attack':[2,2,3,7,4,5,6],'spit':[6,2,8,4,5,6],'belch':[6,6,2,12,6,7,8]}
DIRS=('e','se','s','sw','w','nw','n','ne')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def outside():
    found=set();workspace=str(ROOT).lower()
    for folder,dirs,files in os.walk(ROOT.parents[2]):
        dirs[:]=[d for d in dirs if str(Path(folder)/d).lower()!=workspace and str(Path(folder)/d).lower()!=str(ROOT.parent).lower() and not os.path.isjunction(Path(folder)/d) and not (Path(folder)/d).is_symlink()]
        found.update(str(Path(folder)/f) for f in files)
    return found

def entries(s):
    body=s[s.index('animations = [')+len('animations = ['):]
    result={};depth=0
    for i,c in enumerate(body):
        if c=='{':
            if depth==0:begin=i
            depth+=1
        elif c=='}':
            depth-=1
            if depth==0:
                block=body[begin:i+1];name=re.search(r'"name"\s*:\s*&?"([^"]+)"',block).group(1)
                result[name]=block
    return result

def patch_resources(filename):
    target=OUT/filename
    if not target.exists():return
    src=BASE/('rainette_emission.tres' if 'emission' in filename else 'rainette.tres')
    raw=target.read_bytes();nl='\r\n' if b'\r\n' in raw else '\n'
    old=raw.decode().replace('\r\n','\n');base=src.read_text();new=old
    oldentries=entries(old);baseentries=entries(base)
    def exts(s):return {re.search(r'id="([^"]+)"',m).group(1):Path(re.search(r'path="([^"]+)"',m).group(1)).name for m in re.findall(r'\[ext_resource[^\]]+\]',s)}
    be=exts(base);oe={v:k for k,v in exts(old).items()}
    subs={m.group(1):m.group(0).rstrip() for m in re.finditer(r'\[sub_resource[^\]]*id="([^"]+)"\][\s\S]*?(?=\n\[|\Z)',base)}
    added={}
    for a in ACTIONS:
        for d in DIRS:
            name=a+'_'+d;block=baseentries[name]
            for sid in re.findall(r'SubResource\("([^"]+)"\)',block):
                new_id='skin_'+sid
                if new_id not in added:
                    sub=subs[sid].replace('id="'+sid+'"','id="'+new_id+'"')
                    sub=re.sub(r'ExtResource\("([^"]+)"\)',lambda m:'ExtResource("'+oe[be[m.group(1)]]+'")',sub)
                    added[new_id]=sub
                block=block.replace('SubResource("'+sid+'")','SubResource("'+new_id+'")')
            new=new.replace(oldentries[name],block,1)
    # Discard prior action atlas resources only when no untouched entry needs them.
    used=set(re.findall(r'SubResource\("([^"]+)"\)',''.join(v for k,v in oldentries.items() if k not in {a+'_'+d for a in ACTIONS for d in DIRS})))
    obsolete={sid for a in ACTIONS for d in DIRS for sid in re.findall(r'SubResource\("([^"]+)"\)',oldentries[a+'_'+d])}-used
    for sid in obsolete:
        new=re.sub(r'\[sub_resource[^\]]*id="'+re.escape(sid)+r'"\][\s\S]*?(?=\n\[|\Z)','',new)
    new=new.replace('[resource]','\n\n'.join(added.values())+'\n\n[resource]',1)
    new=re.sub(r'load_steps=\d+','load_steps='+str(len(re.findall(r'^\[(?:ext_resource|sub_resource)',new,re.M))+1),new,count=1)
    target.write_bytes(new.replace('\n',nl).encode())
    after=entries(new)
    assert all(after[k]==v for k,v in oldentries.items() if k not in {a+'_'+d for a in ACTIONS for d in DIRS})
    assert b'\r\n' in target.read_bytes() if nl=='\r\n' else b'\r\n' not in target.read_bytes()
    assert 'CanvasTexture' not in new and 'normal_texture' not in new
    for a,n in ACTIONS.items():
        timing=F60[{'cast':'spit','cast_ult':'belch'}.get(a,a)]
        for d in DIRS:
            block=after[a+'_'+d];speed=float(re.search(r'"speed":\s*([\d.]+)',block).group(1))
            durations=list(map(float,re.findall(r'"duration":\s*([\d.]+)',block)))
            assert durations==[f*speed/60 for f in timing] and len(durations)==n

def driver_actions():
    from PIL import Image
    import numpy as np
    REPORT.mkdir(parents=True,exist_ok=True)
    touched={a+s+'.png' for a in ACTIONS for s in ('','_e')}
    before={p.name:{'bytes':p.stat().st_size,'sha256':digest(p)} for p in OUT.iterdir() if p.is_file()}
    outside_before=outside()
    (REPORT/'rainette_skin1_before.json').write_text(json.dumps(before))
    log=REPORT/'rainette_skin1_actions.log'
    command=[r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe','--background','--threads','2','--python-exit-code','1','--python',str(ROOT/'art/tools/night/skin_rainette_build.py'),'--','--render','--actions']
    with log.open('w') as f:subprocess.run(command,stdout=f,stderr=subprocess.STDOUT,check=True)
    exe=ROOT/'art/blender/cel/rainette_actions/bin/pngquant.exe'
    for a in ('attack','spit','belch'):
        p=OUT/(a+'.png');aliases=[k for k,v in {'cast':'spit','cast_ult':'belch'}.items() if v==a]
        budget=min(before[k+'.png']['bytes']*1.3 for k in [a]+aliases)
        for colors in (256,192,128,96,64,48,32):
            if p.stat().st_size<=budget:break
            subprocess.run([str(exe),str(colors),'--speed','1','--nofs','--force','--ext','.png',str(p)],check=True,capture_output=True)
        assert p.stat().st_size<=budget
        for alias in aliases:shutil.copy2(p,OUT/(alias+'.png'))
    for a in ACTIONS:shutil.copy2(BASE/(a+'_e.png'),OUT/(a+'_e.png'))
    for filename in ('rainette_skin1.tres','rainette_skin1_emission.tres'):patch_resources(filename)
    rows=[];sizes={}
    for a,n in ACTIONS.items():
        p=OUT/(a+'.png');ep=OUT/(a+'_e.png')
        with Image.open(p) as im,Image.open(BASE/p.name) as base,Image.open(ep) as e:
            assert im.size==base.size==(n*192,8*192)
            assert e.size==((im.width+1)//2,(im.height+1)//2)
            arr=np.asarray(im.convert('RGBA'));mask=np.asarray(e.convert('RGBA'))
            assert ((mask[:,:,:3].max(2)>0)&(mask[:,:,3]>0)).any()
            for row in range(8):
                hashes=[]
                for f in range(n):
                    cell=arr[row*192:(row+1)*192,f*192:(f+1)*192]
                    assert (cell[:,:,3]>128).sum()>100
                    assert np.ptp(cell[:,:,:3][cell[:,:,3]>128])>20
                    hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
                assert len(set(hashes))==n,(a,row)
            rows.append(im.crop((0,192,im.width,384)).resize((n*128,128),Image.Resampling.LANCZOS))
        assert digest(ep)==digest(BASE/ep.name)
        for name in (p.name,ep.name):
            sizes[name]=[before[name]['bytes'],(OUT/name).stat().st_size]
            assert sizes[name][1]<=sizes[name][0]*1.3,(name,sizes[name])
    board=Image.new('RGBA',(max(im.width for im in rows),128*len(rows)))
    for i,im in enumerate(rows):board.paste(im,(0,i*128))
    board.save(REPORT/'after_rainette_skin1.png',optimize=True)
    resource_names={'rainette_skin1.tres','rainette_skin1_emission.tres'}
    assert all(digest(OUT/name)==data['sha256'] for name,data in before.items() if name not in touched|resource_names)
    assert not list(OUT.glob('*_n.png'))
    appeared=sorted(outside()-outside_before)
    report={'sizes':sizes,'outside_new_files':appeared,'checks':'dimensions alpha contrast distinct_frames F60 emission_sha256 untouched_files line_endings'}
    (REPORT/'rainette_skin1_actions_report.json').write_text(json.dumps(report,indent=2))
    assert not appeared,appeared[:5]
    print('PASS rainette_skin1 actions '+json.dumps(sizes))

