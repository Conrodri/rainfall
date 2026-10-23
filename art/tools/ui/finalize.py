"""Recadrage/réduction et planche de contrôle uniquement; aucun dessin d'asset."""
import sys, json, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image, ImageDraw, ImageFont

def finalize(src,dst):
    im=Image.open(src).convert('RGBA'); bbox=im.getchannel('A').getbbox()
    if not bbox:raise ValueError(f'Image vide: {src}')
    crop=im.crop(bbox); side=max(crop.size)
    square=Image.new('RGBA',(side,side)); square.alpha_composite(crop,((side-crop.width)//2,(side-crop.height)//2))
    square=square.resize((232,232),Image.Resampling.LANCZOS)
    out=Image.new('RGBA',(256,256)); out.alpha_composite(square,(12,12))
    Path(dst).parent.mkdir(parents=True,exist_ok=True); out.save(dst)

def contact():
    paths=[ROOT/'game/assets/sprites/icons/items'/f'{s}.png' for s in IDS]
    sheet=Image.new('RGB',(5*320,4*352),(43,51,64)); draw=ImageDraw.Draw(sheet)
    report=[]; fingerprints=set()
    for i,p in enumerate(paths):
        im=Image.open(p).convert('RGBA'); x=(i%5)*320; y=(i//5)*352
        sheet.paste(im,(x,y),im); small=im.resize((64,64),Image.Resampling.LANCZOS); sheet.paste(small,(x+256,y+96),small)
        draw.text((x+6,y+264),p.stem,fill=(230,230,230))
        a=im.getchannel('A'); box=a.getbbox()
        digest=hashlib.sha256(im.tobytes()).hexdigest()
        assert digest not in fingerprints, f'Doublon: {p.stem}'
        fingerprints.add(digest)
        raw=Image.open(ROOT/'art/renders/ui/items'/p.name)
        assert raw.size==(512,512) and raw.mode=='RGBA'
        assert abs((box[0]+box[2])/2-128)<=1 and abs((box[1]+box[3])/2-128)<=1
        assert im.size==(256,256) and box and min(box[:2])>=10 and max(box[2:])<=246
        assert a.getextrema()==(0,255)
        report.append({'id':p.stem,'bbox':box,'rgba':True})
    sheet.save(ROOT/'art/renders/ui/contact_items_a.png')
    (ROOT/'art/renders/ui/items_a_validation.json').write_text(json.dumps(report,indent=2))
IDS=['lentille_aiguisee','sablier_fele','antidote','botte_rapiecee','pierre_a_aiguiser','bague_de_vigueur','amulette_de_cuir','aimant_de_poche','sifflet_de_chasse','etincelle','flocon','fiole_verte','pavois_fele','coeur_de_mousse','piece_porte_bonheur','eclat_d_experience','plume_d_empenne']
if __name__=='__main__':
    if sys.argv[1:] == ['--contact']:contact()
    else:finalize(*sys.argv[1:3])
