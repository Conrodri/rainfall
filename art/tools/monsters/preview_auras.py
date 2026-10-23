"""Assemble only existing Blender renders; validate and package elite overlays."""
import sys,json,subprocess
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'vendor'))
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[3]
NAMES=['elite_burn','elite_slow','elite_poison']
def additive(base,overlay):
    rgb=overlay.convert('RGB');alpha=overlay.getchannel('A')
    weighted=Image.merge('RGB',tuple(ImageChops.multiply(c,alpha) for c in rgb.split()))
    return ImageChops.add(base.convert('RGB'),weighted).convert('RGBA')
def main():
    brute=Image.open(ROOT/'art/renders/monsters/brute_tier3/run/se_00.png').convert('RGBA').resize((160,160),Image.Resampling.LANCZOS)
    preview=Image.new('RGBA',(1280,640),'#2B3340');report={}
    frames={}
    for row,name in enumerate(NAMES):
        subprocess.run([sys.executable,str(Path(__file__).with_name('pack_monsters.py')),'fx/elites',name,'160','default:12','--dirlist','x'],check=True)
        folder=ROOT/'art/renders/monsters'/name
        frames[name]=[];margins=[]
        for i in range(8):
            path=folder/'default'/f'x_{i:02d}.png'
            im=Image.open(path).convert('RGBA');em=Image.open(path.with_stem(path.stem+'_e')).convert('RGBA')
            assert im.size==(320,320) and im.tobytes()==em.tobytes()
            im=im.resize((160,160),Image.Resampling.LANCZOS);frames[name].append(im)
            bb=im.getchannel('A').getbbox();assert bb
            margins.append(min(bb[0],bb[1],160-bb[2],160-bb[3]))
            tile=Image.new('RGBA',(160,160),'#2B3340');tile.alpha_composite(brute);tile=additive(tile,im)
            preview.paste(tile,(i*160,row*160))
        first=Image.open(folder/'default/x_00.png').convert('RGBA')
        endpoint=Image.open(folder/'default/_loop_endpoint.png').convert('RGBA')
        exact=first.tobytes()==endpoint.tobytes()
        assert exact, name+' loop mismatch'
        assert min(margins)>=4
        own=preview.crop((0,row*160,1280,(row+1)*160));own.save(folder/'_preview.png')
        report[name]={'frames':8,'fps':12,'render_size':320,'final_size':160,'loop_endpoint_pixel_identical':exact,'emission_identical':True,'minimum_margin_px':min(margins),'ground_diameter_units':1.8,'pivot_percent':70,'normal_map':False}
    for i in range(8):
        tile=Image.new('RGBA',(160,160),'#2B3340');tile.alpha_composite(brute)
        for name in NAMES:tile=additive(tile,frames[name][i])
        preview.paste(tile,(160*i,480))
    preview.convert('RGB').save(ROOT/'art/renders/monsters/elite_auras_preview.png')
    (ROOT/'art/renders/monsters/elite_auras_validation.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()
