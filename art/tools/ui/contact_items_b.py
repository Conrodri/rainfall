"""Assemblage et validation des rendus B, sans dessin d'asset."""
import sys,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image,ImageDraw
IDS=['cristal_de_feu','givre','horloge_arcanique','lame_jumelle','venin_concentre','cape_de_brume','epines','eclair_en_bouteille','rune_de_portee','morsure_vorace','tonique_vital','orbe_de_veille','sang_chaud','marque_du_chasseur','carquois_affute','pointe_perforante','aimant_d_ame']
sheet=Image.new('RGB',(1600,1408),(43,51,64));draw=ImageDraw.Draw(sheet);report=[];hashes=set()
for i,ident in enumerate(IDS):
    p=ROOT/'game/assets/sprites/icons/items'/f'{ident}.png';im=Image.open(p)
    assert im.size==(256,256) and im.mode=='RGBA'
    alpha=im.getchannel('A');box=alpha.getbbox();assert box and min(box[:2])>=10 and max(box[2:])<=246
    assert alpha.getextrema()==(0,255)
    assert abs((box[0]+box[2])/2-128)<=1 and abs((box[1]+box[3])/2-128)<=1
    raw=Image.open(ROOT/'art/renders/ui/items'/p.name);assert raw.size==(512,512) and raw.mode=='RGBA'
    digest=hashlib.sha256(im.tobytes()).hexdigest();assert digest not in hashes;hashes.add(digest)
    x=i%5*320;y=i//5*352;sheet.paste(im,(x,y),im)
    small=im.resize((64,64),Image.Resampling.LANCZOS);sheet.paste(small,(x+256,y+96),small)
    draw.text((x+6,y+264),ident,fill=(230,230,230))
    report.append({'id':ident,'bbox':box,'rgba':True,'sha256':digest})
sheet.save(ROOT/'art/renders/ui/contact_items_b.png')
(ROOT/'art/renders/ui/items_b_validation.json').write_text(json.dumps(report,indent=2))
print('17 PNG valides : RGBA, 256 px, marges, centrage, unicite; bruts 512 px.')
