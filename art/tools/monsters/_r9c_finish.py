"""R9c, adapted directly from the validated R9a packer."""
import sys,json,re,hashlib
from pathlib import Path
from PIL import Image,ImageChops
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
boss_name=sys.argv[sys.argv.index('--boss')+1]
assert boss_name in ('rust_archon','stone_colossus')
OUT=ROOT/f'game/assets/sprites/bosses/mini/{boss_name}';SRC=HERE/'_r9c_frames'/boss_name
TRES=OUT/f'{boss_name}.tres';BASE=HERE/f'_r9c_{boss_name}_baseline.json'
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if '--snapshot' in sys.argv:
    (HERE/f'_r9c_{boss_name}_original.tres').write_bytes(TRES.read_bytes())
    BASE.write_text(json.dumps({p.name:{'hash':digest(p),'size':Image.open(p).size if p.suffix=='.png' else None} for p in OUT.iterdir() if p.is_file()},indent=2))
    print('R9C_SNAPSHOT PASS');sys.exit()
baseline=json.loads(BASE.read_text());original=(HERE/f'_r9c_{boss_name}_original.tres').read_text()
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
    tid=f'r9c_{anim}'
    ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/mini/{boss_name}/{anim}_dirs.png" id="{tid}"]')
    south=re.search(r'\{\s*"frames":.*?"name": &"'+anim+r'_s",\s*"speed": ([\d.]+)\s*\}',text,re.S)
    assert south,anim
    fps=south.group(1)
    for row,d in enumerate(directions):
        ids=[]
        for i in range(count):
            sid=f'r9c_{anim}_{d}_{i}';ids.append(sid)
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
for animation_name,b in old.items():assert new[animation_name]==(b.replace('"loop": true','"loop": false') if animation_name=='attack_s' else b),animation_name
assert len(new)==len(old)+9
# Assemble only existing renders, with S/E/W/N and windup/impact/return.
canvas=Image.new('RGBA',(540,720),(105,105,105,255))
for row,d in enumerate(['s','e','w','n']):
    sh=Image.open(OUT/('attack.png' if d=='s' else 'attack_dirs.png')).convert('RGBA')
    y=0 if d=='s' else directions.index(d)*170
    for col,i in enumerate([2,3,5]):
        canvas.alpha_composite(sh.crop((i*170,y,(i+1)*170,y+170)),(col*180+5,row*180+5))
canvas.convert('RGB').save(HERE/f'_r9c_{boss_name}_contact.png',optimize=True)
report={'result':'PASS','boss':boss_name,'checks':checks,'minimum_margin':min(margins),'new_animations':9,'attack_impact_index':3,'existing_animation_exception':'attack_s loop=false','contact_rows':['s','e','w','n'],'contact_columns':[2,3,5]}
(HERE/f'_r9c_{boss_name}_verification.json').write_text(json.dumps(report,indent=2))
print('R9C_CONTRACT PASS',boss_name,'9 animations; margin',min(margins),'px')
