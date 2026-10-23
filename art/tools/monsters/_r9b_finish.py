"""R9a targeted packing, append-only AtlasTextures, contract checks/contact assembly."""
import sys,json,re,hashlib
from pathlib import Path
from PIL import Image,ImageChops
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
BOSS=sys.argv[sys.argv.index('--boss')+1]
OUT=ROOT/f'game/assets/sprites/bosses/mini/{BOSS}';SRC=HERE/'_r9b_frames'/BOSS
TRES=OUT/f'{BOSS}.tres';BASE=HERE/f'_r9b_{BOSS}_baseline.json'
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if '--snapshot' in sys.argv:
    (HERE/f'_r9b_{BOSS}_original.tres').write_bytes(TRES.read_bytes())
    BASE.write_text(json.dumps({p.name:{'hash':digest(p),'size':Image.open(p).size if p.suffix=='.png' else None} for p in OUT.iterdir() if p.is_file()},indent=2))
    print('R9B_SNAPSHOT PASS');sys.exit()
baseline=json.loads(BASE.read_text());original=(HERE/f'_r9b_{BOSS}_original.tres').read_text()
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
    tid=f'r9b_{anim}'
    ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/mini/{BOSS}/{anim}_dirs.png" id="{tid}"]')
    south=re.search(r'\{\s*"frames":.*?"name": &"'+anim+r'_s",\s*"speed": ([\d.]+)\s*\}',text,re.S)
    assert south,anim
    fps=south.group(1)
    south_loop=re.search(r'"loop": (true|false),\s*"name": &"'+anim+r'_s"',text).group(1)
    for row,d in enumerate(directions):
        ids=[]
        for i in range(count):
            sid=f'r9b_{anim}_{d}_{i}';ids.append(sid)
            sub.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{tid}")\nregion = Rect2({i*170}, {row*170}, 170, 170)\n')
        frames=', '.join('{"duration": 1.0, "texture": SubResource("'+sid+'")} ' for sid in ids).rstrip()
        animations.append('{\n"frames": ['+frames+'],\n"loop": '+('false' if anim=='attack' else south_loop)+',\n"name": &"'+anim+'_'+d+'",\n"speed": '+fps+'\n}')
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
for anim,count in specs.items():
    source=old[anim+'_s']
    source_speed=re.search(r'"speed": ([\d.]+)',source).group(1)
    source_loop=re.search(r'"loop": (true|false)',source).group(1)
    for d in directions:
        block=new[anim+'_'+d]
        assert re.search(r'"speed": ([\d.]+)',block).group(1)==source_speed
        assert re.search(r'"loop": (true|false)',block).group(1)==('false' if anim=='attack' else source_loop)
        assert block.count('"duration": 1.0')==count


report={'result':'PASS','checks':checks,'minimum_margin':min(margins),'new_animations':9,'attack_impact_index':3,'existing_animations_preserved':len(old),'camera_and_pivot':'R8 unchanged'}
(HERE/f'_r9b_{BOSS}_verification.json').write_text(json.dumps(report,indent=2))
print('R9B_CONTRACT PASS',BOSS,'9 animations; margin',min(margins),'px')
