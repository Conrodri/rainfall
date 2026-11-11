from PIL import Image
from pathlib import Path
import colorsys
root=Path(__file__).resolve().parents[3]
out=root/'game/assets/sprites/cosmetics/sillages/givre'
particle=Image.open(out/'particle_32.png').convert('RGBA')
step=Image.open(out/'step_64.png').convert('RGBA')
ground=Image.open(root/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA').resize((128,128))
assert particle.size==(128,128) and step.size==(64,64)
frames=[]; maxima=[]; distinct=[]; bad=[]
for i in range(16):
    box=((i%4)*32,(i//4)*32,(i%4+1)*32,(i//4+1)*32)
    f=particle.crop(box); frames.append(f); maxima.append(max(a for *_,a in f.getdata()))
    distinct.append(f.tobytes())
    for r,g,b,a in f.getdata():
        if a:
            h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
            if 0<=h<=40/360 and s>.5: bad.append((i,h,s))
sheet=Image.new('RGBA',(512,512))
for i,f in enumerate(frames):
    bg=ground.copy(); overlay=Image.new('RGBA',(128,128)); overlay.alpha_composite(f.resize((128,128),Image.Resampling.NEAREST)); bg.alpha_composite(overlay)
    sheet.alpha_composite(bg.convert('RGBA'),((i%4)*128,(i//4)*128))
sheet.convert('RGB').save(root/'art/tools/cosmetics/_sillage_givre_contact.png')
stepmax=max(a for *_,a in step.getdata())
print(f'CHECK particle={particle.size} step={step.size} preview={Image.open(root/"game/assets/sprites/cosmetics/previews/givre.png").size} step_alpha={stepmax} frame_alpha={maxima} distinct={len(set(distinct))}/16 warm={len(bad)}')
