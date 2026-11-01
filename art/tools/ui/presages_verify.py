from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[3];out=root/'game/assets/sprites/icons/omens'
ids=['pluie_de_cendres','carapaces','fievre','eveil_des_elites','marche_noir','offrande','usure','maree','ciel_clair']
contact=Image.new('RGB',(9*112,126),(30,30,30));d=ImageDraw.Draw(contact);ok=True
for i,name in enumerate(ids):
 im=Image.open(out/(name+'.png')).convert('RGBA');ok &= im.size==(128,128) and im.getchannel('A').getextrema()[0]==0
 sm=im.resize((48,48),Image.Resampling.LANCZOS);crop=sm.crop((5,5,43,43));visible=sum(a>32 for a in crop.getchannel('A').getdata());ok &= visible>120
 contact.paste(im.resize((96,96),Image.Resampling.LANCZOS),(i*112+8,4),im.resize((96,96),Image.Resampling.LANCZOS));d.text((i*112+2,103),name,fill='white')
contact.save(root/'art/tools/ui/_presages_contact.png',optimize=True)
print(('PASS' if ok else 'FAIL')+' size=128x128 transparent_alpha=checked symbol48=checked')
