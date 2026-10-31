"""Targeted baseline and contract checks; Pillow only inspects/assembles."""
import hashlib, io, json, subprocess, sys
from pathlib import Path
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'art/renders/feel_sorts2'
BASE = OUT/'taliant_vfx_baseline.json'
SPECS = dict(cut_circle=(6,320), cut_thrust=(5,448), cut_crescent=(6,480), twin_draw=(8,352))

def thickness(a):
    # Largest axis-aligned opaque square: conservative visible thickness.
    mask=a>=192; prev=np.zeros(mask.shape[1]+1,dtype=int); best=0
    for row in mask:
        curr=np.zeros_like(prev)
        for x in np.flatnonzero(row):
            curr[x+1]=1+min(prev[x],prev[x+1],curr[x]); best=max(best,int(curr[x+1]))
        prev=curr
    return best

def files(name):
    return sorted((ROOT/'game/assets/sprites/characters/morfil'/name).rglob('*'))

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    baseline='--baseline' in sys.argv
    data={} if baseline else json.loads(BASE.read_text())
    report={}; board=Image.new('RGBA',(1024,4*160),(47,53,61,255))
    for row,(name,(n,s)) in enumerate(SPECS.items()):
        folder=ROOT/'game/assets/sprites/characters/morfil'/name
        paths=[p for p in files(name) if p.is_file()]
        p=folder/(name+'.png'); im=Image.open(p).convert('RGBA'); a=np.asarray(im)[:,:,3]
        mass=float(a[:,:s].sum()/255); thick=thickness(a[:,:s])
        if baseline:
            data[name]={'alpha0':mass,'thickness':thick,'files':{str(f.relative_to(ROOT)):{'hash':hashlib.sha256(f.read_bytes()).hexdigest(),'bytes':f.stat().st_size} for f in paths},'head':{str(f.relative_to(ROOT)):len(subprocess.check_output(['git','show','HEAD:'+f.relative_to(ROOT).as_posix()])) for f in paths if f.suffix=='.png' and not f.name.endswith('_n.png')}}
            print(name,'alpha0',round(mass),'thickness',thick)
            continue
        old=data[name]; ratio=mass/old['alpha0']; e=Image.open(folder/(name+'_e.png')).convert('RGBA'); ea=np.asarray(e)
        framehash=[hashlib.sha256(im.crop((f*s,0,(f+1)*s,s)).tobytes()).hexdigest() for f in range(n)]
        masses=[float(a[:,f*s:(f+1)*s].sum()/255) for f in range(n)]
        errors=[]
        if im.size!=(n*s,s) or e.size!=((n*s+1)//2,(s+1)//2):errors.append('dimensions')
        if ratio<3:errors.append('alpha<3x')
        if thick<s*.10 or (name=='cut_thrust' and thick<s*.25):errors.append('thickness')
        if len(set(framehash))!=n or min(masses)<=0 or masses[0]<max(masses[1:]):errors.append('frames')
        if not ((ea[:,:,:3]>32).any(axis=2)&(ea[:,:,3]>0)).any():errors.append('emission')
        if a.min()!=0 or a.max()!=255:errors.append('alpha')
        if np.ptp(np.asarray(im)[:,:,:3][a>192].astype(int))<80:errors.append('contrast')
        for f in paths:
            rel=str(f.relative_to(ROOT)); before=old['files'].get(rel)
            if f.suffix=='.png' and f.name.endswith('_n.png'):errors.append('normal')
            if f.suffix=='.png' and rel in old['head'] and f.stat().st_size>old['head'][rel]*1.3:errors.append('weight:'+f.name)
            if f.suffix=='.tres' and (not before or hashlib.sha256(f.read_bytes()).hexdigest()!=before['hash']):errors.append('tres')
        entry=dict(alpha_ratio=round(ratio,3),thickness=thick,alpha_frames=[round(v) for v in masses],before_bytes=old['head'][str(p.relative_to(ROOT))],after_bytes=p.stat().st_size,errors=errors)
        report[name]=entry
        print(name,json.dumps(entry,separators=(',',':')))
        for f in range(n):
            cell=im.crop((f*s,0,(f+1)*s,s)); cell.thumbnail((128,152));board.alpha_composite(cell,(f*128+(128-cell.width)//2,row*160+(160-cell.height)//2))
    if baseline:
        assert not BASE.exists(),'Baseline already exists'
        BASE.write_text(json.dumps(data,indent=2))
    else:
        (OUT/'taliant_vfx_verification.json').write_text(json.dumps(report,indent=2))
        board.convert('RGB').save(OUT/'after_vfx_taliant.png',optimize=True)
        assert not any(v['errors'] for v in report.values()),'FAIL contract'
        print('PASS TALIANT VFX')

if __name__=='__main__':main()
