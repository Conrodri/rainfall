"""Crop/assemble/check only; Blender owns all drawing."""
import json, math
from pathlib import Path
from PIL import Image, ImageChops
ROOT=Path(__file__).resolve().parents[3]
RAW=ROOT/'art/renders/tocp2'; OUT=ROOT/'game/assets/sprites/characters/tocsin'
REPORT=ROOT/'art/tools/tocsin'
manifest={'ppu':64,'normal_maps':False,'source_cell':[448,320],'assets':{}}
contact=[]
for kind,n,fps in [('impact',8,20),('zone',12,24),('arc',6,24),('end',6,15)]:
    names=[f'pillar_arc_{rig}_{v}' for rig in ['top','crea'] for v in range(4)] if kind=='arc' else [f'pillar_{kind}']
    images=[]; masks=[]; bbox=None
    for name in names:
        rig=name.split('_')[-2] if kind=='arc' else 'top'
        variant=int(name[-1]) if kind=='arc' else 0
        for f in range(n):
            stem=f'{kind}_{rig}_{variant}_{f:02}'
            im=Image.open(RAW/(stem+'.png')).convert('RGBA').resize((448,320),Image.Resampling.LANCZOS)
            em=Image.open(RAW/(stem+'_e.png')).convert('RGBA').resize((448,320),Image.Resampling.LANCZOS)
            b=im.getchannel('A').getbbox(); assert b,(kind,f)
            assert b[0]>0 and b[1]>0 and b[2]<448 and b[3]<320,('clipped',kind,b)
            bbox=b if bbox is None else (min(bbox[0],b[0]),min(bbox[1],b[1]),max(bbox[2],b[2]),max(bbox[3],b[3]))
            images.append(im);masks.append(em)
    box=(bbox[0]-4,bbox[1]-4,bbox[2]+4,bbox[3]+4); w,h=box[2]-box[0],box[3]-box[1]
    cols=n; rows=len(names); sheet=Image.new('RGBA',(w*cols,h*rows)); es=Image.new('RGBA',sheet.size)
    for j,(im,em) in enumerate(zip(images,masks)):
        pos=(j%n*w,j//n*h);sheet.paste(im.crop(box),pos); es.paste(em.crop(box),pos)
    assert max(sheet.size)<=4096
    assert es.convert('RGB').getbbox(),('empty emission',kind)
    stem='pillar_'+kind
    sheet.save(OUT/(stem+'.png'),optimize=True)
    es=es.resize(((es.width+1)//2,(es.height+1)//2),Image.Resampling.LANCZOS)
    es.save(OUT/(stem+'_e.png'),optimize=True)
    pivot=[224-box[0],160-box[1]]
    offset=[w/2-pivot[0],h/2-pivot[1]]
    for suffix,div in [('',1),('_emission',2)]:
        tex=stem+('_e' if div==2 else '')+'.png'
        sx=es.width/sheet.width if div==2 else 1
        sy=es.height/sheet.height if div==2 else 1
        parts=[f'[gd_resource type="SpriteFrames" load_steps={len(images)+2} format=3]\n',f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/tocsin/{tex}" id="1"]\n']
        for j in range(len(images)):
            parts.append(f'[sub_resource type="AtlasTexture" id="f{j}"]\natlas = ExtResource("1")\nregion = Rect2({j%n*w*sx}, {j//n*h*sy}, {w*sx}, {h*sy})\n')
        anims=[]
        for row,name in enumerate(names):
            frames=', '.join('{"duration": 1.0, "texture": SubResource("f%d")}'%(row*n+f) for f in range(n))
            anims.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}'%(frames,str(kind=='zone').lower(),name,float(fps)))
        parts.append('[resource]\nanimations = ['+',\n'.join(anims)+']\n')
        parts.append(f'metadata/ppu = 64\nmetadata/pivot = Vector2({pivot[0]*sx}, {pivot[1]*sy})\nmetadata/offset = Vector2({offset[0]*sx}, {offset[1]*sy})\n')
        if div==2:parts.append(f'metadata/overlay_scale = Vector2({1/sx}, {1/sy})\n')
        (OUT/('tocsin_'+stem+suffix+'.tres')).write_text('\n'.join(parts),encoding='utf8')
    manifest['assets'][stem]={'cell':[w,h],'atlas':list(sheet.size),'emission':list(es.size),'frames':n,'animations':names,'fps':fps,'loop':kind=='zone','pivot':pivot,'offset':offset,'top_scale':[1,1],'crea_scale':[.70710678,1.4142136] if kind=='arc' else None,'emission_scale':[sheet.width/es.width,sheet.height/es.height]}
    for f in [0,n//2,n-1]:contact.append((kind,images[f].crop(box)))
    print('PASS',stem,f'{w}x{h}',f'{sheet.width}x{sheet.height}',len(names),'animations')
(REPORT/'tocp2_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
# Single contact sheet, real terrace ground, assembly only.
ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
canvas=Image.new('RGBA',(960,720))
for y in range(0,720,ground.height):
    for x in range(0,960,ground.width):canvas.paste(ground,(x,y),ground)
for i,(kind,im) in enumerate(contact):
    im.thumbnail((300,165),Image.Resampling.LANCZOS)
    canvas.alpha_composite(im,((i%3)*320+(320-im.width)//2,(i//3)*180+(180-im.height)//2))
canvas.convert('RGB').save(REPORT/'tocp2_contact.png',optimize=True)
print('PASS crop, frames, emission, atlas <=4096, contact')
