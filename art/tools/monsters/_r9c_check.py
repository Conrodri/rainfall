"""Final R9c contract audit and contact assembly; Pillow never draws assets."""
import json,re,hashlib
from pathlib import Path
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
names=('rust_archon','stone_colossus')
canvas=Image.new('RGB',(1080,1080),(105,105,105))
reports=[]
for col,name in enumerate(names):
    folder=ROOT/f'game/assets/sprites/bosses/mini/{name}'
    baseline=json.loads((HERE/f'_r9c_{name}_baseline.json').read_text())
    allowed={f'attack{x}.png' for x in ('','_n','_e')}|{name+'.tres'}
    for filename,meta in baseline.items():
        path=folder/filename
        if filename not in allowed:
            assert hashlib.sha256(path.read_bytes()).hexdigest()==meta['hash'],(name,filename)
        if meta['size']:assert list(Image.open(path).size)==meta['size']
    text=(folder/f'{name}.tres').read_text()
    paths=re.findall(r'path="res://([^\"]+)"',text)
    assert all((ROOT/'game'/p).is_file() for p in paths)
    assert len(re.findall(r'\[sub_resource',text))+len(paths)+1==int(re.search(r'load_steps=(\d+)',text)[1])
    original=(HERE/f'_r9c_{name}_original.tres').read_text()
    blocks=lambda t:{re.search(r'"name": &"([^"]+)"',b)[1]:b.strip() for b in re.findall(r'\{\s*"frames":.*?"speed": [\d.]+\s*\}',t,re.S)}
    old,new=blocks(original),blocks(text)
    assert len(new)==len(old)+9
    for anim,block in old.items():
        assert new[anim]==(block.replace('"loop": true','"loop": false') if anim=='attack_s' else block)
    for anim in ('attack','cast_a','cast_b'):
        south=old[anim+'_s']
        for direction in ('e','w','n'):
            block=new[anim+'_'+direction]
            assert re.search(r'"speed": ([\d.]+)',block)[1]==re.search(r'"speed": ([\d.]+)',south)[1]
            assert ('"loop": false' if anim=='attack' else re.search(r'"loop": (true|false)',south)[0]) in block
    assert 'RESULT: OK' in (HERE/f'_r9c_{name}_godot.log').read_bytes().decode('utf-16')
    report=json.loads((HERE/f'_r9c_{name}_verification.json').read_text());reports.append(report)
    with Image.open(HERE/f'_r9c_{name}_contact.png') as im:canvas.paste(im,(col*540,0))
    for row,anim in enumerate(('cast_a','cast_b')):
        with Image.open(folder/f'{anim}_dirs.png') as sh:
            for direction in range(3):
                tile=sh.crop((4*170,direction*170,5*170,(direction+1)*170)).convert('RGBA')
                bg=Image.new('RGBA',(170,170),(105,105,105,255));bg.alpha_composite(tile)
                canvas.paste(bg.convert('RGB'),(col*540+direction*180+5,720+row*180+5))
canvas.save(HERE/'_r9c_contact.png',optimize=True)
(HERE/'_r9c_verification.json').write_text(json.dumps({'result':'PASS','bosses':reports,'contact':{'boss_columns':names,'attack_rows':['s','e','w','n'],'attack_columns':[2,3,5],'bottom_rows':['cast_a frame 4 e/w/n','cast_b frame 4 e/w/n']}},indent=2))
print('R9C PASS: 2 bosses; 18 added animations; originals preserved; sprites_test RESULT: OK')
