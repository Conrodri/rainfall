"""M3 assembly and structural checks only; no raster drawing."""
import json,re,hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT/'art/tools/night';RAW=BASE/'m3_raw'
DEST=ROOT/'game/assets/sprites/characters/rictus'
NAMES=['dagues_demi_lune','eventail','toupie','doublures']
SIZES={'knife':(64,4,1),'knife_planted':(64,1,8),'dagger_arc':(672,4,1),'spin_blur':(288,4,1),'double_burst':(512,6,1)}
errors=[];checks=[]
for name,(size,n,d) in SIZES.items():
    for sheet in (['top','crea'] if name=='double_burst' else ['default']):
        p=DEST/name/(sheet+'.png');im=Image.open(p).convert('RGBA')
        if im.size!=(size*n,size*d):errors.append(name+': dimensions')
        for j in range(d):
            hashes=[]
            for f in range(n):
                cell=im.crop((f*size,j*size,(f+1)*size,(j+1)*size));box=cell.getbbox()
                if not box:errors.append(name+': empty')
                elif min(box[:2])<1 or max(box[2:])>=size:errors.append(name+': clipped')
                hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
            if n>1 and len(set(hashes))!=n:errors.append(name+': duplicate frames')
        checks.append({'asset':name+'/'+sheet,'size':list(im.size)})
    p=DEST/name/(name+'.tres');content=p.read_text()
    for path in re.findall('path="res://([^"]+)"',content):
        if not (ROOT/'game'/path).exists():errors.append('missing '+path)

# Embedded GDScript resource: no .gd/.tscn creation or changes.
paths=[p for name in SIZES for p in (DEST/name).glob('*.tres')]
source='extends SceneTree\nfunc _initialize() -> void:\n    var failed := 0\n    var count := 0\n'
for p in paths:
    rel='res://'+p.relative_to(ROOT/'game').as_posix()
    source+='    if ResourceLoader.load('+json.dumps(rel)+') == null:\n        failed += 1\n    count += 1\n'
source+='    print("M3_RESOURCES: ", count, " loaded; errors=", failed)\n    quit(0 if failed == 0 else 1)\n'
(BASE/'m3_verify.tres').write_text('[gd_resource type="GDScript" format=3]\n\n[resource]\nscript/source = '+json.dumps(source)+'\n')

canvas=Image.new('RGBA',(1536,1648),(20,24,25,255))
def put(p,x,y,w,h=None):
    im=Image.open(p).convert('RGBA');im.thumbnail((w,h or w),Image.Resampling.LANCZOS);canvas.alpha_composite(im,(x+(w-im.width)//2,y))
def tile(p,x,y,size,framed=False):
    im=Image.open(p).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
    if framed:im.alpha_composite(Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA').resize((size,size),Image.Resampling.LANCZOS))
    canvas.alpha_composite(im,(x,y))
for p,x in [('art/tools/characters/_m2_contact.png',0),('art/tools/iso/_c4_contact.png',300),('art/tools/ui/_i2_contact.png',600),('art/tools/iso/_c1_contact.png',900)]:put(ROOT/p,x,0,296,210)
put(ROOT/'game/assets/sprites/ui/portraits/rictus.png',1232,0,256)
for row,names in enumerate([NAMES,['eclat_de_braise','braises_errantes','nova_ardente','pilier_de_flamme']]):
    for i,name in enumerate(names):
        x=52+i*300;y=270+row*160;p=ROOT/'game/assets/sprites/icons/spells'/f'{name}.png'
        tile(p,x,y,128,True);tile(p,x+144,y+32,64,True)
for f in range(4):
    p=RAW/f'knife_{f}.png';tile(p,1260+f%2*128,285+f//2*128,128)
for f in range(4):put(RAW/f'arc_{f}.png',f*300,610,288)
put(RAW/'arc_2_n.png',1220,610,152);put(RAW/'arc_2_e.png',1380,610,152)
for f in range(4):put(RAW/f'spin_{f}.png',f*300,910,288)
for d in range(8):tile(RAW/f'planted_{d}.png',1224+(d%2)*136,830+(d//2)*104,96)
for f in range(6):
    put(RAW/f'burst_top_{f}.png',f*256,1205,246,208)
    put(RAW/f'burst_crea_{f}.png',f*256,1420,246,208)
put(ROOT/'game/assets/sprites/characters/montreur/string_tile/string_tile.png',1260,790,256,16)
canvas.convert('RGB').save(BASE/'_m3_contact.png',compress_level=9)
report={'errors':errors,'checks':checks,'choices':['Dagues de bois ferre, rivets et ligatures argent; axe +X.','Demi-lune au sol, rayon 320 px, centre (336,336), disparition en filaments.','Explosion de copeaux, porcelaine et fils rompus; pas de feu.','Icones: arche de deux dagues, eventail de cinq lames, toupie tournee en bois, masques feles suspendus. Studio I2 reutilise, accent argent spectral #9FC8C0.'],'contracts':'Les sous-assets M3, les quatre icones et le portrait etaient absents au debut; creation necessaire. Aucun .tres existant modifie.','contact':'References et portrait; Rictus puis Ardent en medaillons 128/64; arc + passes, spin + couteaux plantes; explosions TOP puis CREA.','blend_source':'art/blender/characters/rictus.blend','additive':['spin_blur'],'emission':'_e fournis seulement si non noirs; emission auto via NormalMaps; couteaux sans emission.'}
(BASE/'m3_report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf8')
print('M3_STRUCTURE:', 'PASS' if not errors else 'FAIL '+str(errors),'; resources=',len(paths))
