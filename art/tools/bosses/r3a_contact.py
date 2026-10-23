"""One final contact board; Pillow crops and assembles existing sheets only."""
from PIL import Image
from pack_cerf import DST, SRC

rows = [
    [(f'idle_p{p}',0,0) for p in (1,2,3)]+[(f'walk_p{p}',0,0) for p in (1,2,3)],
    [('auto',f,0) for f in range(6)],
    [('spell_a',f,0) for f in (0,1,2,3,4,5)],
    [('spell_b',f,0) for f in (0,1,2,3,4,6)],
    [(a,f,0) for a in ('trans_p2','trans_p3') for f in (0,4,7)],
    [('death',0,0),('death',5,0),('death',8,0),('vanish',4,0),('reappear',2,0),('walk_p3',4,3)],
    [('antlers',0,0),('wisp',0,0),('wisp_explode',3,0),('ground_mist',0,0),('ground_wisp_trail',0,0),('idle_p3',3,0)],
]
board=Image.new('RGBA',(1536,256*len(rows)),(40,48,49,255))
for row,cells in enumerate(rows):
    for col,(anim,f,d) in enumerate(cells):
        size=64 if anim in ('wisp','wisp_explode','ground_wisp_trail') else 256
        with Image.open(DST/f'{anim}.png') as sheet:
            cell=sheet.convert('RGBA').crop((f*size,d*size,(f+1)*size,(d+1)*size))
        board.alpha_composite(cell,(col*256+(256-size)//2,row*256+(256-size)//2))
board.save(SRC/'contact_r3a.png')
print('PASS single contact: 42 cells / 19 animations')
