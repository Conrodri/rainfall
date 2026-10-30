from pathlib import Path
from PIL import Image
import json,re,hashlib
R=Path('C:/Users/const/Documents/Rainfall');B=R/'art/blender/vfx';before=json.loads((B/'spell_before.json').read_text());report={};contact=Image.new('RGBA',(960,720),(24,21,23,255))
for row,(kind,items) in enumerate(before.items()):
 d=R/'game/assets/sprites/vfx'/kind;size,count={'ardent_nova':(512,10),'ardent_ashes':(384,8),'ardent_brasier':(640,12)}[kind]
 frames=[Image.open(B/'ardent_spell_frames'/kind/'default'/('%02d.png'%i)).convert('RGBA') for i in range(count)]
 assert len({hashlib.sha256(im.tobytes()).hexdigest() for im in frames})==count
 for im in frames:
  box=im.getbbox();assert box and min(box[:2])>0 and box[2]<size and box[3]<size,(kind,box)
  assert im.getchannel('A').getextrema()==(0,255)
  assert max(im.convert('RGB').getextrema()[0])>80
 energy=[]
 for i in range(count):
  em=Image.open(B/'ardent_spell_frames'/kind/'default'/('%02d_e.png'%i)).convert('RGB');energy.append(sum(sum(v) for v in em.getdata()))
 if kind!='ardent_ashes':assert energy[0]==max(energy) and energy[-1]<energy[0]*.25,(kind,energy)
 for name,info in items.items():
  im=Image.open(d/name);assert list(im.size)==info['size'],name
  if name.endswith('_e.png'):
   diff=Image.open(d/(name[:-6]+'.png'));assert im.size==tuple((n+1)//2 for n in diff.size)
   assert max(im.convert('RGB').getextrema()[0])>0
  assert not any(k in name for k in ('_n.png','__Image','_fix'))
 text=(d/(kind+'.tres')).read_text();assert 'CanvasTexture' not in text and 'normal_texture' not in text
 old=sum(x['bytes'] for x in items.values());new=sum((d/n).stat().st_size for n in items);assert new<=old*1.3
 report[kind]={'before_bytes':old,'after_bytes':new,'frames':count,'sizes':{n:info['size'] for n,info in items.items()},'energy':energy}
 for col,i in enumerate([0,count//2,count-1]):
  im=frames[i].copy();im.thumbnail((310,230));contact.alpha_composite(im,(col*320+(320-im.width)//2,row*240+(240-im.height)//2))
end=Image.open(B/'ardent_spell_frames/ardent_ashes/end/03.png');assert end.getbbox() is None
contact.convert('RGB').save(B/'spells_contact.jpg',quality=90)
(B/'spells_verification.json').write_text(json.dumps(report,indent=2));print('PASS dimensions alpha contrast distinct frames emission peak tail extinction budget; '+str({k:(v['before_bytes'],v['after_bytes']) for k,v in report.items()}))
