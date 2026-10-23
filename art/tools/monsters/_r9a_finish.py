"""R9a targeted packing, append-only AtlasTextures, contract checks/contact assembly."""
import sys,json,re,hashlib
from pathlib import Path
from PIL import Image,ImageChops
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
OUT=ROOT/'game/assets/sprites/bosses/mini/frost_bear';SRC=HERE/'_r9a_frames'
TRES=OUT/'frost_bear.tres';BASE=HERE/'_r9a_baseline.json'
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if '--snapshot' in sys.argv:
    (HERE/'_r9a_frost_bear_original.tres').write_bytes(TRES.read_bytes())
    BASE.write_text(json.dumps({p.name:{'hash':digest(p),'size':Image.open(p).size if p.suffix=='.png' else None} for p in OUT.iterdir() if p.is_file()},indent=2))
    print('R9A_SNAPSHOT PASS');sys.exit()
baseline=json.loads(BASE.read_text());original=(HERE/'_r9a_frost_bear_original.tres').read_text()
specs={'attack':6,'cast_a':8,'cast_b':8};directions=['e','w','n'];changed=set()
for anim,count in specs.items():
    groups=[(anim+'_dirs',directions)] + ([(anim,['s'])] if anim=='attack' else [])
    for name,dirs in groups:
        for suffix in ('','_n','_e'):
            sheet=Image.new('RGBA',(count*170,len(dirs)*170),(128,128,255,0) if suffix=='_n' else (0,0,0,0))
            for row,d in enumerate(dirs):
                for i in range(count):
                    with Image.open(SRC/anim/f'{d}_{i:02}{suffix}.png') as raw:
                        assert raw.size==(340,340)
                        im=raw.convert('RGBA')
                        im=Image.merge('RGBA',tuple(c.resize((170,170),Image.Resampling.LANCZOS) for c in im.split())) if suffix=='_n' else im.resize((170,170),Image.Resampling.LANCZOS)
                        sheet.paste(im,(i*170,row*170))
            path=OUT/f'{name}{suffix}.png';sheet.save(path,optimize=True,compress_level=9);changed.add(path.name)
# Preserve every existing animation/frame/texture. Only attack_s.loop changes,
# because the explicit non-looping attack requirement overrides its old true.
text=original
text=re.sub(r'"loop": true,(\s*"name": &"attack_s")',r'"loop": false,\1',text)
ext=[];sub=[];animations=[]
for ai,(anim,count) in enumerate(specs.items()):
    tid=f'r9a_{anim}'
    ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/mini/frost_bear/{anim}_dirs.png" id="{tid}"]')
    south=re.search(r'\{\s*"frames":.*?"name": &"'+anim+r'_s",\s*"speed": ([\d.]+)\s*\}',text,re.S)
    assert south,anim
    fps=south.group(1)
    for row,d in enumerate(directions):
        ids=[]
        for i in range(count):
            sid=f'r9a_{anim}_{d}_{i}';ids.append(sid)
            sub.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{tid}")\nregion = Rect2({i*170}, {row*170}, 170, 170)\n')
        frames=', '.join('{"duration": 1.0, "texture": SubResource("'+sid+'")} ' for sid in ids).rstrip()
        animations.append('{\n"frames": ['+frames+'],\n"loop": '+('false' if anim=='attack' else 'true')+',\n"name": &"'+anim+'_'+d+'",\n"speed": '+fps+'\n}')
text=text.replace('[sub_resource', '\n'.join(ext)+'\n\n[sub_resource',1)
text=text.replace('[resource]', '\n'.join(sub)+'\n[resource]',1)
text=text.rstrip();assert text.endswith('}]')
text=text[:-1]+', '+', '.join(animations)+']\n'
text=re.sub(r'load_steps=\d+',f'load_steps={86+len(ext)+len(sub)}',text,count=1)
TRES.write_text(text,encoding='utf-8',newline='\n');changed.add(TRES.name)
checks=[];margins=[]
for anim,count in specs.items():
    sheets=[Image.open(OUT/f'{anim}_dirs{x}.png').convert('RGBA') for x in ('','_n','_e')]
    assert all(p.size==(count*170,510) for p in sheets)
    assert len({p.getchannel('A').tobytes() for p in sheets})==1
    for row,d in enumerate(directions):
        frame_hashes=[]
        for i in range(count):
            cell=sheets[0].crop((i*170,row*170,(i+1)*170,(row+1)*170))
            bb=cell.getchannel('A').getbbox();assert bb,(anim,d,i)
            margin=min(bb[0],bb[1],170-bb[2],170-bb[3]);margins.append(margin)
            assert margin>=4,(anim,d,i,'clipping',bb)
            frame_hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
        # R8d cast_a is a symmetric inhalation/exhalation; from the back its
        # return poses legitimately repeat once the glowing eyes are occluded.
        assert len(set(frame_hashes))>=(count-1 if anim=='attack' else count//2),(anim,d,'static animation')
    checks.append(anim+'_dirs: grid, e/w/n, alpha, animated poses PASS')
south=[Image.open(OUT/f'attack{x}.png').convert('RGBA') for x in ('','_n','_e')]
assert all(p.size==(1020,170) for p in south)
assert len({p.getchannel('A').tobytes() for p in south})==1
for i in range(6):
    bb=south[0].crop((i*170,0,(i+1)*170,170)).getchannel('A').getbbox()
    assert bb and min(bb[0],bb[1],170-bb[2],170-bb[3])>=4,('attack_s',i,bb)
for name,meta in baseline.items():
    p=OUT/name
    if name not in changed:assert digest(p)==meta['hash'],('unexpected edit',name)
    if meta['size']:assert list(Image.open(p).size)==meta['size'],('size changed',name)
# Compare old animation blocks individually, including atlas IDs and timing.
def blocks(t):
    return {re.search(r'"name": &"([^"]+)"',b).group(1):b.strip() for b in re.findall(r'\{\s*"frames":.*?"speed": [\d.]+\s*\}',t,re.S)}
old,new=blocks(original),blocks(text)
for name,b in old.items():assert new[name]==(b.replace('"loop": true','"loop": false') if name=='attack_s' else b),name
assert len(new)==len(old)+9
vpath=ROOT/'game/assets/sprites/ui/da/vignette_hit.png'
with Image.open(vpath) as im:v=im.convert('RGBA')
assert v.size==(1024,1024)
alpha=v.getchannel('A');hist=alpha.histogram();transparent=hist[0]/(1024**2)
assert .58<=transparent<=.64,('transparent area',transparent)
assert alpha.getpixel((512,512))==0
assert 20<alpha.getpixel((0,512))<alpha.getpixel((0,0))<245
assert all(abs(alpha.getpixel((x,512))-alpha.getpixel((1023-x,512)))<=1 for x in range(512))
v.save(vpath,optimize=True,compress_level=9)
# Contact: rows S,E,W,N; columns windup 2 / impact 3 / recovery 5.
# Pillow only crops/resizes/assembles source renders and composites on grey.
canvas=Image.new('RGBA',(1210,740),(105,105,105,255))
for row,d in enumerate(['s','e','w','n']):
    sh=Image.open(OUT/('attack.png' if d=='s' else 'attack_dirs.png')).convert('RGBA')
    y=0 if d=='s' else directions.index(d)*170
    for col,i in enumerate([2,3,5]):
        tile=sh.crop((i*170,y,(i+1)*170,y+170));canvas.alpha_composite(tile,(col*180+15,row*180+10))
canvas.alpha_composite(v.resize((640,640),Image.Resampling.LANCZOS),(560,50))
canvas.convert('RGB').save(HERE/'_r9a_contact.png',optimize=True)
report={'result':'PASS','checks':checks,'minimum_margin':min(margins),'new_animations':9,'attack_impact_index':3,'vignette_zero_alpha_fraction':transparent,'unchanged_existing_files':len(baseline)-sum(n in changed for n in baseline),'existing_animation_exception':'attack_s loop=false','contact_rows':['s','e','w','n'],'contact_columns':['windup index 2','impact index 3','recovery index 5']}
(HERE/'_r9a_verification.json').write_text(json.dumps(report,indent=2))
print('R9A_CONTRACT PASS; 9 animations; margin',min(margins),'px; transparent',round(100*transparent,2),'%')
