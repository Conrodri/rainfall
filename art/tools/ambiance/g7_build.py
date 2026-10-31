import bpy, math, os, sys, random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/sprites/ambiance'
BLEND = ROOT / 'art/blender/ambiance/g7_ambience.blend'
sys.path.insert(0, str(ROOT/'art/tools/cel'))
import cel_style as cel
cel.install('vfx', normals=False)
random.seed(707)

def save(name, w, h, pixel):
    im = bpy.data.images.new(name, width=w, height=h, alpha=True)
    vals=[]
    for y in range(h):
        v=y/max(1,h-1)
        for x in range(w):
            u=x/max(1,w-1)
            r,g,b,a=pixel(u,v,x,y)
            vals.extend((r,g,b,a))
    im.pixels.foreach_set(vals)
    im.filepath_raw=str(OUT/(name+'.png'))
    im.file_format='PNG'
    im.save()
    bpy.data.images.remove(im)

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a))); return t*t*(3-2*t)

def shaft(u,v,x,y):
    # puits en haut, ouverture évasée vers le sol
    half=.08+.42*v
    d=abs(u-.5)/half
    grain=random.Random(x*91+y*131).random()-.5
    edge=1-smooth(.66,1.06,d)
    alpha=edge*(.12+.72*(1-v)**.55)*(1+grain*.035)
    return (1,1,1,max(0,min(.88,alpha)))
save('lightshaft_256x1024',256,1024,shaft)

def ceiling(u,v,x,y):
    # formes d'ombre de stalactites et racines, douces, sans raccord demandé
    n=(math.sin(u*17+math.sin(v*9)*2)+math.sin(u*37+v*11)*.35+math.sin(u*7-v*19)*.4)/1.75
    hang=.05+.40*(.5+.5*math.sin(u*21+math.sin(u*8)*1.8))
    stal=1-smooth(hang-.025,hang+.025,v)
    rootline=abs(u-(.5+.12*math.sin(v*13+u*6)))
    root=(1-smooth(.006,.022,rootline))*smooth(.03,.18,v)*(.5+.5*math.sin(v*19+u*23))
    shadow=max(0,min(1,stal*.78+root*.55))
    shade=max(.49,min(1,.985-.34*shadow+.018*n))
    return shade,shade,shade,1
save('cave_ceiling_2048',2048,2048,ceiling)

def drip(u,v,x,y):
    frame=x//64; xx=(x%64+.5)/64*2-1; yy=(y+.5)/64*2-1
    r=math.sqrt(xx*xx+yy*yy)
    radius=.34+frame*.045
    ring=math.exp(-((r-radius)/(.035+frame*.004))**2)
    inner=math.exp(-((r-(radius-.07))/.025)**2)*.17
    a=max(0,min(.9,ring*(.47-frame*.045)+inner))
    return (.57,.53,.48,a)
save('drip_ring_64',256,64,drip)

def spore(u,v,x,y):
    qx=(u-.5)/.43; qy=(v-.5)/.38
    r=math.sqrt(qx*qx+qy*qy)
    lobes=.10*math.sin(u*25+v*12)+.055*math.sin(u*41-v*29)
    a=max(0,min(.7,(1-smooth(.55,1.02,r+lobes))*.36))
    return (1,1,1,a)
save('spore_puff_128',128,128,spore)

BLEND.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
print('G7_BUILD PASS 4 assets')
