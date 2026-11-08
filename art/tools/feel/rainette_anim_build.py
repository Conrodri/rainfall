"""Rainette tongue/goo_projectile only; staged verification before four PNG replacements."""
from pathlib import Path
import sys, math, json, hashlib, shutil, os, ast
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
RAW=ROOT/'art/renders/feel_sorts2/rainette_vfx_a'
DEST=ROOT/'game/assets/sprites/characters/rainette/effects'
SPECS={'tongue':(512,33000),'goo_projectile':(128,7000)}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def outside():
    base=ROOT.parents[2];out=[]
    for folder,dirs,files in os.walk(base):
        dirs[:]=[d for d in dirs if d not in ('.git','.claude') and not os.path.isjunction(Path(folder,d))]
        out.extend(str(Path(folder,f)) for f in files)
    return sorted(out)
def prepare():
    from PIL import Image
    RAW.mkdir(parents=True,exist_ok=True);(RAW/'baseline').mkdir(exist_ok=True)
    data={'files':{},'resources':{},'outside':outside()}
    for key,(c,_) in SPECS.items():
        for suffix in ('','_e'):
            p=DEST/key/(key+suffix+'.png');shutil.copy2(p,RAW/'baseline'/p.name)
            data['files'][p.name]={'bytes':p.stat().st_size,'hash':sha(p)}
        im=Image.open(DEST/key/(key+'.png')).convert('RGBA')
        data[key]=[im.crop((f*c,0,(f+1)*c,c)).getchannel('A').getbbox() for f in range(4)]
        for p in (DEST/key).glob('*.tres'):data['resources'][str(p)]=sha(p)
    (RAW/'baseline.json').write_text(json.dumps(data));print('PASS baseline')
def render():
    import bpy
    from mathutils import Vector
    sys.path[:0]=[str(ROOT/'art/tools'/d) for d in ('night','characters','iso','cel')]
    import iso_rig,cel_style as cel
    from ardent_iso_build import mesh,bead,empty
    from cd_cd1_common import tube,flat
    tree=ast.parse((ROOT/'art/tools/night/ra2_build.py').read_text(encoding='utf-8'))
    fn=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='ribbon')
    ns={'Vector':Vector,'math':math,'mesh':mesh};exec(compile(ast.Module(body=[fn],type_ignores=[]),'<ribbon-only>','exec'),ns)
    for key,(cell,_) in SPECS.items():
        work=ROOT/'art/blender/cel/feel2';work.mkdir(parents=True,exist_ok=True)
        src=ROOT/f'art/blender/characters/rainette_{key}.blend';copy=work/f'rainette_vfx_a_{key}_source.blend'
        if src.exists() and not copy.exists():shutil.copy2(src,copy)
        for f in range(4):
            s=iso_rig.create_rig('CREA',cell);s.render.threads_mode='FIXED';s.render.threads=8;s.eevee.taa_render_samples=8
            root=empty('Rainette '+key)
            wet=flat('Olive wet mire','59643B');dark=flat('Deep mire','343F28')
            flesh=flat('Dark fleshy tongue','934C60');ridge=flat('Raised muscle','BA7780')
            jade=flat('Vocal jade','8DBBA8',1.4-f*.24);foam=flat('Wet pale foam','D5E6C5',.9-f*.15)
            if key=='tongue':
                length=[4.5,3.65,2.5,1.6][f]
                pts=[(-216/iso_rig.R+length*(j/64),(.23+.045*f)*math.sin(j/64*math.tau)*math.sin(j/64*math.pi),.105+.1*math.sin(j/64*math.pi)) for j in range(65)]
                ns['ribbon']('Thick muscular S tongue',pts,.225,.105,flesh,root)
                for sign in (-1,1):tube('Wet muscle ridge',[(x,y+sign*.12,z+.10) for x,y,z in pts],.020,ridge,root)
                tube('Wet specular glint',[(x,y-.035,z+.112) for x,y,z in pts[8:31]],.014,foam,root)
                x,y,z=pts[-1];bead('Bulging sticky tip',(x-.015,y,z+.015),(.135,.24,.135),flesh,root)
                bead('Wet tip highlight',(x+.035,y-.07,z+.13),(.055,.10,.022),foam,root)
                for j in range(7-f):
                    a=j*2.399;reach=(.23 if f==0 else .16)*(1+.15*math.sin(j))
                    end=(min(x+.11,x+math.cos(a)*reach),y+math.sin(a)*reach*1.5,z+.11+.10*(j%3))
                    tube('Snap saliva thread',[(x-.07,y,z+.11),((x-.07+end[0])*.5,(y+end[1])*.5,z+.15),end],.011,jade,root)
                    bead('Snap saliva drop',end,(.024,.035,.044),foam if j%3==0 else jade,root)
                for j in range(5):
                    xx,yy,zz=pts[13+j*9]
                    tube('Hanging saliva',[(xx,yy-.11,zz),(xx-.10,yy-.17,zz-.15),(xx-.17,yy-.12,zz-.055)],.010,jade,root)
                    bead('Viscous drop',(xx-.10,yy-.17,zz-.14),(.026,.025,.040),jade,root)
            else:
                phase=f*math.tau/4
                bead('Heavy elongated mire globule',(-.015,0,0),(.255,.17+.012*math.sin(phase),.15),wet,root)
                bead('Wet jade core',(.065,-.025,.095),(.13,.115,.065),jade,root)
                bead('Rolling dark underside',(-.06,-.07,-.065),(.20,.095,.065),dark,root)
                for j in range(4):
                    a=j*math.tau/4+phase*.17
                    pts=[(-.51+t*.66,.13*math.cos(a)*math.sin(t*math.pi),.12*math.sin(a)*math.sin(t*math.pi)) for t in [n/24 for n in range(25)]]
                    tube('Stretched mucus spine',pts,.019,wet if j%2 else jade,root)
                for j in range(4):
                    xx=-.36-j*.075-.012*math.sin(phase+j)
                    bead('Spat trailing drop',(xx,.035*math.sin(j*2+phase),.035*math.cos(j+phase)),(.044-j*.007,.034-j*.005,.038-j*.006),jade if j==0 else wet,root)
                tube('Foam glint',[(.04,-.06,.155),(.11,-.025,.15),(.17,.01,.12)],.014,foam,root)
            folder=RAW/key;folder.mkdir(exist_ok=True);p=folder/f'{f}.png'
            cel.install('vfx',normals=False);iso_rig.common.configure_passes(p)
            if f==0:
                blend=work/f'rainette_vfx_a_{key}.blend'
                if blend.exists():blend=work/f'rainette_vfx_a_{key}_{__import__("time").time_ns()}.blend'
                bpy.ops.wm.save_as_mainfile(filepath=str(blend))
            s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
            emitted=list(folder.glob(str(f)+'_e__*.png'));assert len(emitted)==1
            emitted[0].replace(folder/f'{f}_e.png');assert not list(folder.glob('*_n*.png'))
    print('PASS 8 Eevee cel vfx frames')
def deliver():
    from PIL import Image,ImageStat
    meta=json.loads((RAW/'baseline.json').read_text());report={};pending=[]
    board=Image.new('RGBA',(1024,320),(58,62,70,255))
    for key,(c,limit) in SPECS.items():
        for suffix in ('','_e'):
            unit=c if not suffix else (c+1)//2;atlas=Image.new('RGBA',(unit*4,unit));bounds=[];mass=[]
            for f in range(4):
                im=Image.open(RAW/key/f'{f}{suffix}.png').convert('RGBA').resize((unit,unit),Image.Resampling.LANCZOS)
                bounds.append(im.getchannel('A').getbbox());mass.append(sum(im.getchannel('A').getdata()));atlas.paste(im,(f*unit,0))
            p=RAW/(key+suffix+'.png');budget=min(limit if not suffix else 100000,int(meta['files'][p.name]['bytes']*1.30))
            for colors in ((64,48,32) if not suffix else (32,24,16)):
                atlas.quantize(colors=colors,method=Image.Quantize.FASTOCTREE).save(p,optimize=True)
                if p.stat().st_size<=budget:break
            assert p.stat().st_size<=budget,(p.name,p.stat().st_size,budget)
            final=Image.open(p).convert('RGBA');assert final.size==(unit*4,unit)
            hashes=[]
            for f in range(4):
                frame=final.crop((f*unit,0,(f+1)*unit,unit));assert frame.getchannel('A').getbbox()
                assert max(ImageStat.Stat(frame).sum[:3])>100
                if not suffix:assert max(ImageStat.Stat(frame).stddev[:3])>10
                hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
            assert len(set(hashes))==4
            if not suffix:
                old=meta[key][2 if key=='tongue' else 0]
                assert abs(bounds[0][0]-old[0])<=4,(key,bounds[0],old)
                assert abs(bounds[0][2]-old[2])<=6,(key,bounds[0],old)
                if key=='tongue':assert mass[0]>mass[1]>mass[2]>mass[3]
                if key=='tongue':board.alpha_composite(final.resize((1024,256),Image.Resampling.LANCZOS),(0,0))
                else:
                    for f in range(4):board.alpha_composite(final.crop((f*c,0,(f+1)*c,c)).resize((96,96),Image.Resampling.LANCZOS),(f*256+80,224))
            report[p.name]={'before':meta['files'][p.name]['bytes'],'after':p.stat().st_size,'size':final.size,'bbox':bounds,'distinct':len(set(hashes))}
            pending.append((p,DEST/key/p.name))
    assert all(sha(Path(p))==h for p,h in meta['resources'].items())
    assert not set(outside()).difference(meta['outside']),'New files outside worktrees'
    for src,dst in pending:shutil.copy2(src,dst);assert sha(src)==sha(dst)
    board.convert('RGB').save(ROOT/'art/renders/feel_sorts2/after_vfx_rainette_a.png',optimize=True)
    (RAW/'verification.json').write_text(json.dumps(report,indent=2))
    print('PASS dimensions bytes alpha emission contrast distinct frames pivots .tres external paths; '+json.dumps({k:[v['before'],v['after']] for k,v in report.items()}))
if __name__=='__main__':
    if '--render' in sys.argv:render()
    elif '--deliver' in sys.argv:deliver()
    else:prepare()
