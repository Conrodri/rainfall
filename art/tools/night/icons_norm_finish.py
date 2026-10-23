"""Raster contract and contact sheet. Pillow: crop, resize, assemble, inspect only."""
import sys, json, hashlib, math
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
BASE=Path(__file__).resolve().parent
WORK=ROOT/'art/blender/cel/icons_norm'
GAME=ROOT/'game/assets/sprites/icons/spells'
ARCHIVE=ROOT/'art/archive_3d/sprites/icons/spells'
REPORT=BASE/'_icons_norm_verification.json'
BOX=(10,8,121,120)

def fit_image(path):
    im=Image.open(path).convert('RGBA')
    base=Image.open(WORK/'medallion_raw.png').convert('RGBA')
    im=im.crop(base.getbbox()).resize((111,112),Image.Resampling.LANCZOS)
    # Remove filter-only outer zero rows, keeping one common transform for every emblem.
    for _ in range(3):
        if im.getbbox()==(0,0,111,112):break
        im=im.crop(im.getbbox()).resize((111,112),Image.Resampling.LANCZOS)
    out=Image.new('RGBA',(128,128));out.paste(im,BOX[:2]);return out

def fit(name):
    out=fit_image(WORK/(name+'_raw.png'))
    target=WORK/'nova_ardente_cel.png' if name=='nova_ardente_cel' else GAME/(name+'.png')
    out.save(target,compress_level=9)

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def srgb_luma(rgb):
    rgb=rgb/255
    linear=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
    return linear@np.array([.2126,.7152,.0722])

def verify():
    report=json.loads(REPORT.read_text())
    reference=np.array(Image.open(GAME/'nova_ardente.png').convert('RGBA'))
    backing=np.array(fit_image(WORK/'medallion_raw.png'))
    yy,xx=np.indices((128,128))
    # Pixel-centre ellipse of the opaque medallion; bbox also includes Lanczos feather.
    rr=((xx-65)/55)**2+((yy-63.5)/55.5)**2
    disk=rr<=1;inner=rr<=.94**2
    face_region=(rr>=.76**2)&(rr<=.89**2)
    # Same fixed outer-face sample on reference and every icon; excludes the chevrons.
    ref_face=face_region & (reference[:,:,0]<50) & (reference[:,:,1]<60)
    ref_luma=float((reference[:,:,:3]@np.array([.2126,.7152,.0722]))[ref_face].mean())
    rows={}
    for p in sorted(GAME.glob('*.png')):
        im=Image.open(p);a=np.array(im.convert('RGBA'));opaque=a[:,:,3]>=128
        rgb=a[:,:,:3].astype(float)
        delta=np.max(abs(rgb-backing[:,:,:3].astype(float)),axis=2)
        # Emblem segmentation against the exact rendered empty template (includes neutral relief).
        emblem=(delta>18)&inner&(a[:,:,3]>240)
        # The accent carries the legible silhouette, neutral support is allowed.
        mask_files=list(WORK.glob(p.stem+'_accent_mask__*.png'))
        if mask_files:
            bright=(np.array(fit_image(mask_files[0]))[:,:,0]>192)&inner
        else:
            bright=emblem&(srgb_luma(rgb)>.055)
        face=ref_face&(~emblem)
        luma=float((rgb@np.array([.2126,.7152,.0722]))[face].mean()) if face.any() else 0
        contrast=float((np.median(srgb_luma(rgb)[bright])+.05)/(np.median(srgb_luma(rgb)[face])+.05)) if bright.any() and face.any() else 0
        before=ARCHIVE/p.name
        row={'size':list(im.size),'mode':im.mode,'bbox':list(im.getbbox()),
             'disk_fill':float(opaque[disk].mean()),'outside_disk_fraction':float((opaque&~disk).sum()/max(1,opaque.sum())),
             'medallion_luminance_srgb_255':luma,'reference_luminance_srgb_255':ref_luma,
             'luminance_relative_error':abs(luma/ref_luma-1),'emblem_face_contrast':contrast,
             'emblem_pixels':int(emblem.sum()),'accent_pixels':int(bright.sum()),
             'sha256':sha(p),'archive_sha256':sha(before) if before.exists() else None,
             'hash_changed':sha(p)!=sha(before) if before.exists() else True,
             'no_normal_or_emission':not any((GAME/(p.stem+s+'.png')).exists() for s in ('_n','_e'))}
        nova=p.stem=='nova_ardente'
        row['pass']=im.size==(128,128) and im.mode=='RGBA' and im.getbbox()==BOX and row['disk_fill']>=.98 and row['outside_disk_fraction']<=.005 and row['luminance_relative_error']<=.15 and contrast>=3 and row['no_normal_or_emission'] and (not row['hash_changed'] if nova else row['hash_changed'])
        rows[p.name]=row
    protected=[p for p,h in report['protected'].items() if sha(ROOT/p)!=h]
    report.update({'icons':rows,'delivered':len(rows)-1,'after_bytes':sum(p.stat().st_size for p in GAME.glob('*.png')),
        'protected_changed':protected,'status':'PASS' if all(r['pass'] for r in rows.values()) and not protected and len(rows)==45 else 'FAIL',
        'measurement':'WCAG linear sRGB contrast of accent versus fixed outer-face sample; silhouette at alpha>=128; inscribed disk excludes the two-pixel antialias feather.'})
    REPORT.write_text(json.dumps(report,indent=2),encoding='utf8')
    bad={n:[k for k in ('disk_fill','outside_disk_fraction','luminance_relative_error','emblem_face_contrast') if (r[k]<(.98 if k=='disk_fill' else 3) if k in ('disk_fill','emblem_face_contrast') else r[k]>(.005 if k=='outside_disk_fraction' else .15))] for n,r in rows.items() if not r['pass']}
    print(report['status'],len(rows),'icons;',json.dumps(bad)[:1600])

def board():
    groups=[['nova_ardente','nova_ardente_cel'],
       ['eclat_de_braise','cendres','brasier','braises_errantes'],['pilier_de_flamme','pluie_de_meteores','phenix'],
       ['dagues_demi_lune','eventail','toupie','doublures']]
    for prefix in ('tocsin','averse','arpenteuse','rainette','avare','bourbe','vigie','morfil'):
        groups.append([p.stem for p in sorted(GAME.glob(prefix+'_*.png'))])
    groups.append(['dodge'])
    sheet=Image.new('RGBA',(1400,len(groups)*176+16),'#14110C')
    frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
    # Underlay: scaled alpha from the actual circular frame, no Pillow drawing.
    ref=Image.open(GAME/'nova_ardente.png').convert('RGBA')
    underlay=Image.new('RGBA',(128,128),(232,226,214,0))
    underlay.putalpha(ref.getchannel('A').point(lambda v:round(v*.18)))
    def tile(path,size):
        canvas=Image.new('RGBA',(size,size),(20,17,12,255))
        # spell_button.gd: r=size/2-4, underlay radius=.8*r, icon side=.72*size.
        diameter=round((size-8)*.8)
        backing_side=round(diameter/(110/128))
        blue=Image.new('RGBA',(128,128),(20,23,33,0))
        blue.putalpha(ref.getchannel('A').point(lambda v:round(v*.85)))
        offset=((size-backing_side)//2,)*2
        canvas.alpha_composite(blue.resize((backing_side,backing_side),Image.Resampling.LANCZOS),offset)
        canvas.alpha_composite(underlay.resize((backing_side,backing_side),Image.Resampling.LANCZOS),offset)
        side=round(size*.72)
        canvas.alpha_composite(Image.open(path).convert('RGBA').resize((side,side),Image.Resampling.LANCZOS),((size-side)//2,)*2)
        canvas.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS))
        return canvas
    order=[]
    for row,names in enumerate(groups):
        for col,name in enumerate(names):
            x=12+col*347;y=16+row*176
            new=WORK/'nova_ardente_cel.png' if name=='nova_ardente_cel' else GAME/(name+'.png')
            old=ARCHIVE/(name+'.png')
            if old.exists():sheet.alpha_composite(tile(old,72),(x,y+39))
            sheet.alpha_composite(tile(new,150),(x+79,y))
            sheet.alpha_composite(tile(new,72),(x+237,y+39))
            order.append(name)
    sheet.convert('RGB').save(BASE/'_icons_norm_contact.png',optimize=True)
    (BASE/'_icons_norm_contact.txt').write_text('\n'.join(' | '.join(g) for g in groups),encoding='utf8')
    print('PASS contact',sheet.size)

if __name__=='__main__':
    if sys.argv[1]=='fit':fit(sys.argv[2])
    elif sys.argv[1]=='verify':verify()
    elif sys.argv[1]=='board':board()
