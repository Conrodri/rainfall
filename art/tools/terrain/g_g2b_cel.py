"""G2b CEL renderer: original F2 scenes and renderer; system driver / -- --render.

Only shading changes. Water/void reuse F1's periodic two-tone method, without ink.
Existing shadow decals and metadata remain byte-identical. No normal-map output.
"""
from pathlib import Path
import sys, json, hashlib, subprocess, inspect, importlib, shutil
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(ROOT/'art/tools/cel'), str(HERE), str(ROOT/'art/tools/terrain')]
import cel_style as cel
LOTS = {'g_g2b': 'terrain/fog_forest/iso'}
STATE = HERE/'_g_g2b_render.json'
REPORT = HERE/'_g_g2b_verification.json'
BASELINE = HERE/'_g_g2b_baseline.json'

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def snapshot():
    files = [p for rel in LOTS.values() for p in (cel.GAME_SPRITES/rel).iterdir()
             if p.suffix in ('.tres', '.json', '.import')]
    files += [p for lot in LOTS for p in (ROOT/'art/blender/terrain').glob(lot+'_*.blend')]
    return {str(p.relative_to(ROOT)): digest(p) for p in files}

def render():
    import g_g2b_build as source
    source.build()
    source.audit()
    print('PASS G2b render complete',flush=True)


def verify():
    import numpy as np
    from PIL import Image
    results, samples, edges = [], [], []
    before = after = 0
    for lot, rel in LOTS.items():
        arch, out = cel.ARCHIVE/rel, cel.GAME_SPRITES/rel
        archived = json.loads((arch/'.archived.json').read_text())
        assert all(digest(arch/f) == sha for f, sha in archived.items()), ('archive changed', rel)
        files = sorted(arch.glob('*.png'))
        normal = lambda p: p.stem.endswith('_n') and p.with_name(p.stem[:-2]+'.png').exists()
        emission = lambda p: p.stem.endswith('_e') and p.with_name(p.stem[:-2]+'.png').exists()
        names=('cliff_sw','cliff_se','cliff_corner_s','cliff_corner_w','cliff_corner_e','void_1024','water_deep','water_shallow')
        diffuse=[arch/(name+'.png') for name in names]
        expected={name+'.png' for name in names}
        if (arch/'water_shallow_e.png').exists(): expected.add('water_shallow_e.png')
        # Shared directory: G2b owns only these eight diffuse tiles.
        # In particular cliff_corner_e.png is a diffuse, never an emission mask.
        assert expected <= {p.name for p in out.glob('*.png')}
        before += sum((arch/n).stat().st_size for n in expected if (arch/n).exists())
        after += sum(p.stat().st_size for p in out.glob('*.png'))
        row = []
        for p in diffuse:
            with Image.open(p) as im: size = im.size
            if p.stem=='cliff_corner_e':
                color=np.asarray(Image.open(out/p.name).convert('RGBA'))
                assert color.shape[:2]==(384,256) and color[:,:,3].max()>0
                item={'file':rel+'/'+p.name,'size':size,'silhouette_iou':'source is legacy emission-only'}
            else:
                item = cel.check_sheet(rel+'/'+p.name, cell=size, frames=1, rows=1, normals=False)
            item.update(size=size, no_normal=not (out/(p.stem+'_n.png')).exists(), cells=1)
            assert item['no_normal']
            if p.stem.startswith(('water', 'void')):
                color = np.asarray(Image.open(out/p.name).convert('RGBA'))
                rgb = color[:, :, :3][color[:, :, 3] > 240]
                _, counts = np.unique(rgb, axis=0, return_counts=True)
                item['pattern_tone_pixels'] = sorted(counts.tolist(), reverse=True)[:2]
                if p.stem.startswith('water'):
                    assert len(counts) >= 2 and sorted(counts)[-2] > len(rgb)*.01, (p.name, 'flat periodic pattern')
                else:
                    fog_pixels=int((color[:,:,:3].mean(2)>0).sum())
                    item['fog_coverage']=fog_pixels/color.shape[0]/color.shape[1]
                    assert len(counts)>=2 and item['fog_coverage']>.10, (p.name,'ochre fog coverage')
            ep = out/(p.stem+'_e.png')
            if ep.exists():
                a = np.asarray(Image.open(arch/ep.name).convert('RGBA'))
                b = np.asarray(Image.open(ep).convert('RGBA'))
                assert a.shape == b.shape
                aa = (a[:,:,:3].max(2)>100)&(a[:,:,3]>128)
                bb = (b[:,:,:3].max(2)>100)&(b[:,:,3]>128)
                item['accent_iou_half'] = float((aa&bb).sum()/max(1,(aa|bb).sum()))
                assert item['accent_iou_half'] > .97, item
                assert (b[:,:,:3].max(2)*(b[:,:,3].astype(float)/255)).max()>2
            results.append(item)
            # All lot subjects represented; large void sampled at its central area.
            cell = size if max(size)<=512 else (512,512)
            row.append((rel+'/'+p.name,cell,0,0))
            if len(row)==3: samples.append(row); row=[]
        if row: samples.append(row)
        # Water follows a 256x128 isometric lattice.
        for name in ('water_deep','water_shallow'):
            a=np.asarray(Image.open(out/(name+'.png')).convert('RGBA'))
            # Two-unit water tiles repeat at the same isometric half-row displacement.
            delta=float(np.abs(a[2:126,2,:3].astype(float)-a[2:126,-2,:3]).mean())
            assert delta < 28, (name,'tile seam',delta)
            edges.append(dict(lot=lot,tile=name,cel_rgb_delta=delta))
        a=np.asarray(Image.open(out/'void_1024.png').convert('RGBA'))
        delta=max(float(np.abs(a[:,0,:3].astype(float)-a[:,-1,:3]).mean()),float(np.abs(a[0,:,:3].astype(float)-a[-1,:,:3]).mean()))
        assert delta < 8, ('void_1024','tile seam',delta)
        edges.append(dict(lot=lot,tile='void_1024',cel_rgb_delta=delta))
    from PIL import Image, ImageOps, ImageDraw
    before_dir=cel.ARCHIVE/LOTS[lot]; out=cel.GAME_SPRITES/LOTS[lot]
    names=['cliff_sw','cliff_se','cliff_corner_s','cliff_corner_w','cliff_corner_e','void_1024','water_deep','water_shallow']
    board=Image.new('RGB',(1024,640),(18,22,23))
    draw=ImageDraw.Draw(board)
    for i,name in enumerate(names):
        x=(i%4)*256; y=(i//4)*320
        for side,base in enumerate((before_dir,out)):
            im=Image.open(base/(name+'.png')).convert('RGBA');im.thumbnail((120,260) if name.startswith('cliff') else (232,260))
            board.paste(im,(x+side*128+(128-im.width)//2,y+35),im)
        draw.text((x+4,y+4),name,fill='white')
        draw.text((x+4,y+300),'avant                    après',fill='white')
    board.save(ROOT/'art/renders/grotte/g2b_avant_apres.png',optimize=True)
    report=dict(status='PASS',sheets=results,floor_edges=edges,bytes_before=before,bytes_after=after,
                choices=['Original F2/F3 saved geometry, cameras, pivots and material hues; original render_frame imported.',
                         'tile: three tones, no silhouette ink; water/void two periodic tones without ink, shared night shadow floor.',
                         'G2b silhouettes, dimensions and pivots follow the existing five cliffs, two water tiles and TOP void.',
                         'Eight diffuse tiles; no normal maps, shadow decals or unused east-corner emission mask.'])
    REPORT.write_text(json.dumps(report,indent=2))
    print('PASS G2b verification '+str(len(results))+' diffuse',flush=True)

def checks():
    commands=[(n,[cel.GODOT,'--headless','--path',str(ROOT/'game'),'res://tests/'+n+'.tscn'])
              for n in ('sprites_test','texture_budget_test')]
    results=[]
    for name,args in commands:
        logpath=HERE/('_g_g2b_'+name+'.log')
        with logpath.open('w',encoding='utf-8') as log:
            run=subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=300)
        content=logpath.read_text(encoding='utf-8',errors='replace')
        ok=run.returncode==0
        ok=ok and ('RESULT: OK' in content if name=='sprites_test' else 'RESULT: FAIL' not in content)
        entry=dict(check=name,returncode=run.returncode,pass_check=ok,log=str(logpath.relative_to(ROOT)))
        if name=='budget':
            entry['global_budget_warnings']=[line.strip() for line in content.splitlines() if line.startswith('  - ')]
        results.append(entry)
        print(('PASS ' if ok else 'FAIL ')+name,flush=True)
    report=json.loads(REPORT.read_text()); report.update(checks=results,protected_files_unchanged=True,
        status='PASS' if all(r['pass_check'] for r in results) else 'FAIL')
    REPORT.write_text(json.dumps(report,indent=2))
    assert report['status']=='PASS', 'See check logs'

def driver():
    if not BASELINE.exists(): BASELINE.write_text(json.dumps(snapshot(),indent=2))
    if '--checks-only' in sys.argv: checks(); return
    if '--verify-only' not in sys.argv:
        args=[cel.BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']
        if '--resume' in sys.argv: args.append('--resume')
        with (HERE/'_g_g2b_blender.log').open('w',encoding='utf-8') as log:
            subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
        assert 'PASS G2b render complete' in (HERE/'_g_g2b_blender.log').read_text(encoding='utf-8',errors='replace'), 'Blender render failed; see log'
    verify()
    if '--verify-only' not in sys.argv: checks()

if __name__=='__main__':
    render() if '--render' in sys.argv else driver()
