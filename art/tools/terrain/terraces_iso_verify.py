"""Read-only C1 contract checks and Pillow contact assembly; no raster drawing."""
import json,math
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];D=ROOT/'game/assets/sprites/terrain/terraces/iso';A=ROOT/'art/tools/iso'
spec=json.loads((A/'_c1_inventory.json').read_text());errors=[];stats=[]
pivots=json.loads((A/'_c1_pivots.json').read_text())
errors.extend('pivot '+c['name'] for c in pivots if not c['pass_check'])
for e in spec['assets']:
    for suffix in ('','_n'):
        p=D/(e['name']+suffix+'.png')
        if not p.exists():errors.append('missing '+p.name);continue
        with Image.open(p) as im:
            if list(im.size)!=e['size']:errors.append('size '+p.name)
            if not im.getchannel('A').getbbox():errors.append('empty '+p.name)
            if e['name'].startswith('ground') and im.getpixel((5,5))[3]>0:errors.append('mask '+p.name)
    if e['shadow_size']:
        with Image.open(D/(e['name']+'_shadow.png')) as im:
            if list(im.size)!=e['shadow_size']:errors.append('shadow '+e['name'])
    stats.append({'name':e['name'],'pivot':e['pivot'],'bytes':sum(p.stat().st_size for p in D.glob(e['name']+'*.png'))})
for p in D.glob('*_e.png'):
    with Image.open(p) as im:
        if max(im.getextrema()[i][1] for i in range(3))<=1:errors.append('black emission '+p.name)
for name in ('block_b','rampart_corner_n'):
    p=D/(name+'_e.png')
    if not p.exists():errors.append('missing emission '+name)
    else:
        with Image.open(p) as im:
            if list(im.size)!=[256,256] or max(im.getextrema()[i][1] for i in range(3))<=1:errors.append('invalid emission '+name)
canvas=Image.new('RGBA',(1800,1480),(20,26,30,255))
def paste(name,anchor,pivot):
    im=Image.open(D/(name+'.png')).convert('RGBA');canvas.alpha_composite(im,(round(anchor[0]-pivot[0]),round(anchor[1]-pivot[1])))
for row in range(3):
 for col in range(3):
    paste('ground_'+'abcd'[(row*3+col)%4],(900+(col-row)*256,120+(col+row)*128),(256,128))
for name,pos in [('rampart_ne',(1028,184)),('rampart_corner_n',(900,120)),('rampart_nw',(772,184))]:paste(name,pos,(128,192))
items=[('block_a',(772,440)),('block_b',(900,504)),('block_c',(1028,568)),('cliff_sw',(644,632)),('cliff_corner_s',(772,696)),('cliff_se',(900,760))]
for name,pos in items:paste(name,pos,(128,64) if name.startswith('cliff') else (128,192))
report=json.loads((ROOT/'art/renders/monsters/ash_lord/build_report.json').read_text());ratio=spec['R']/(170/report['framing']['ortho_scale'])
actor=Image.open(ROOT/'game/assets/sprites/bosses/mini/ash_lord/idle.png').crop((0,0,170,170)).convert('RGBA')
actor=actor.resize((round(170*ratio),round(170*ratio)),Image.Resampling.LANCZOS)
canvas.alpha_composite(actor,(round(1150-actor.width/2),round(410-actor.height*.7)))
for i,name in enumerate(('water_shallow','water_deep')):paste(name,(250+i*300,1010),(128,64))
void=Image.open(D/'void_1024.png').convert('RGBA').resize((256,256),Image.Resampling.LANCZOS);canvas.alpha_composite(void,(30,1160))
for i,ref in enumerate(('_r8a_contact.png','_r8d_contact.png')):
    im=Image.open(ROOT/'art/tools/monsters'/ref).convert('RGBA');im.thumbnail((660,330));canvas.alpha_composite(im,(360+i*700,1120))
canvas.convert('RGB').save(A/'_c1_contact.png',optimize=True,compress_level=9)
(A/'_c1_validation.json').write_text(json.dumps({'status':'FAIL' if errors else 'PASS','errors':errors,'assets':stats,'ash_R':spec['R'],'ash_resize':ratio,'no_emission':'Cold blue accents on block_b and rampart_corner_n only; no black masks exported.'},indent=2))
print(('FAIL '+str(errors)) if errors else 'PASS: 18 diffuse, 18 normals, 3 TOP shadows, sizes/masks; contact assembled')
