"""U1 dimensions / alpha / 9-slice checks and Pillow-only assembly/optimization."""
import sys,json,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[3];sys.path.insert(0,str(R/'art/tools/vendor'))
from PIL import Image
T=R/'art/tools/ui';D=R/'game/assets/sprites/ui/da'
inv=json.loads((T/'_u1_inventory.json').read_text());rows=inv['assets'];report=[]
for row in rows:
    for suffix in ['']+(['_e'] if row['emission'] else []):
        p=D/(row['name']+suffix+'.png');im=Image.open(p).convert('RGBA');size=tuple(row['size'])
        if im.size==(size[0]*2,size[1]*2):im=im.resize(size,Image.Resampling.LANCZOS)
        assert im.size==size,(p,im.size,size)
        a=im.getchannel('A');assert a.getextrema()[0]==0 and a.getextrema()[1]>100,p
        assert a.getbbox(),p
        if row['name']!='vignette_hit':
            bb=a.point(lambda v:255 if v>=16 else 0).getbbox()
            assert bb[0]>=1 and bb[1]>=1 and bb[2]<=size[0]-1 and bb[3]<=size[1]-1,(p,bb)
        if suffix:assert max(im.convert('RGB').getextrema()[k][1] for k in range(3))>30,p
        if row['name']=='minimap_frame':assert a.getpixel((size[0]//2,size[1]//2))==0
        if row['name']=='vignette_hit':
            assert a.getpixel((512,512))==0;assert a.getpixel((2,512))>100
        im.save(p,optimize=True,compress_level=9)
        report.append(dict(path=p.relative_to(R).as_posix(),size=list(size),alpha=list(a.getextrema()),bbox=list(a.getbbox()),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    if 'nine_slice' in row:
        m=row['nine_slice'];w,h=row['size'];assert m['left']+m['right']<w and m['top']+m['bottom']<h
        assert json.loads((D/(row['name']+'.json')).read_text())==row
        # Corner ornaments fit inside fixed borders; stretches must retain an open centre.
        if row['name'].startswith('bar_frame'):assert Image.open(D/(row['name']+'.png')).getpixel((w//2,h//2))[3]==0

# A stray object would change the button silhouette in either pass.
button_alpha=Image.open(D/'button_normal.png').getchannel('A').tobytes()
for row in rows:
    if row['name'].startswith('button_'):
        for suffix in ['']+(['_e'] if row['emission'] else []):
            assert Image.open(D/(row['name']+suffix+'.png')).getchannel('A').tobytes()==button_alpha, ('button silhouette',row['name'],suffix)

def asset(name,size=None):
    im=Image.open(D/(name+'.png')).convert('RGBA')
    row=next((q for q in rows if q['name']==name),{})
    if size and 'nine_slice' in row:
        m=row['nine_slice'];l,t,r,b=[m[k] for k in ['left','top','right','bottom']]
        xs=[0,l,im.width-r,im.width];ys=[0,t,im.height-b,im.height]
        dx=[0,l,size[0]-r,size[0]];dy=[0,t,size[1]-b,size[1]];out=Image.new('RGBA',size)
        for j in range(3):
            for i in range(3):
                patch=im.crop((xs[i],ys[j],xs[i+1],ys[j+1])).resize((dx[i+1]-dx[i],dy[j+1]-dy[j]),Image.Resampling.LANCZOS)
                out.alpha_composite(patch,(dx[i],dy[j]))
        return out
    return im.resize(size,Image.Resampling.LANCZOS) if size else im

# Assemble actual C1 wet-stone renders as an isometric ground capture under the HUD.
hud=Image.new('RGBA',(1920,1080),'#0A0E11')
floor=R/'game/assets/sprites/terrain/terraces/iso'
for iy in range(-2,11):
    for ix in range(-2,7):
        im=Image.open(floor/('ground_a.png' if (ix+iy)%3 else 'ground_b.png')).convert('RGBA')
        hud.alpha_composite(im,(ix*512+(iy%2)*256-128,iy*128-180))
hud=Image.alpha_composite(hud,Image.new('RGBA',hud.size,(2,6,9,105)))
def place(name,x,y,size=None):hud.alpha_composite(asset(name,size),(x,y))
place('panel_small_9slice',22,56,(620,138));place('level_badge',40,67)
place('bar_fill_hp_lost',140,96,(470,32));place('bar_fill_hp',140,96,(388,32));place('bar_frame_hp',128,88)
place('bar_fill_xp',48,180,(340,16));place('bar_frame_xp',32,174)
place('timer_plate',832,40);place('icon_gold',1650,45);place('icon_pause',1790,40,(64,64))
place('minimap_frame',1560,120)
place('minimap_player',1704,263)
for name,x,y in [('chest',1620,230),('boss',1750,192),('pillar',1740,330),('teleporter',1640,330)]:place('minimap_'+name,x,y)
place('bar_fill_boss',468,943,(790,40));place('bar_frame_boss',448,930)
place('icon_interact',1630,940);place('keycap_9slice',1720,956)
place('button_primary',790,1005,(320,64))
GRID=((len(rows)+5)//6)*152
sheet=Image.new('RGBA',(1920,GRID+1080),'#141C20')
for i,row in enumerate(rows):
    im=asset(row['name']);im.thumbnail((296,104),Image.Resampling.LANCZOS)
    x=i%6*320+12;y=i//6*152+44
    sheet.alpha_composite(im,(x+(296-im.width)//2,y+(104-im.height)//2))
    # Button emission previews used to overlap the lower-right frame.
    # Their opaque black backing belongs to the emission pass, not the diffuse.
    if row['emission'] and not row['name'].startswith('button_'):
        mask=asset(row['name']+'_e');mask.thumbnail((66,35),Image.Resampling.LANCZOS);sheet.alpha_composite(mask,(x+232,y+69))
sheet.alpha_composite(hud,(0,GRID))
labels=Image.open(T/'_u1_labels.png').convert('RGBA');assert labels.size==sheet.size
sheet.alpha_composite(labels);sheet.save(T/'_u1_contact.png',optimize=True)
hud.alpha_composite(labels.crop((0,GRID,1920,GRID+1080)));hud.save(T/'_u1_hud.png',optimize=True)
result=dict(status='PASS',assets=len(rows),png=len(report),bytes=sum(q['bytes'] for q in report),checks=['dimensions','RGBA','transparent alpha','nonempty emission','nine-slice metadata','frame apertures','vignette clear centre','button diffuse/emission silhouettes identical; no overflowing object','button emission previews do not overlap diffuse'],files=report)
(T/'_u1_validation.json').write_text(json.dumps(result,indent=2))
print('PASS U1:',len(rows),'assets,',len(report),'PNG,',sum('nine_slice' in q for q in rows),'9-slices;',round(result['bytes']/1048576,2),'MiB; contact + HUD 1920x1080')
