"""Vigvi: fixed-seed scout reliefs, Nova medallion; background Blender only."""
import sys, math, subprocess, random
from pathlib import Path
BASE=Path(__file__).resolve().parent
sys.path.insert(0,str(BASE))
import icons_norm_build as n
from ui_kit import bpy, mat
ROOT=n.ROOT
WORK=ROOT/'art/blender/cel/vigvi'
NAMES=['vigie_tir_double','vigie_fanal','vigie_chausse_trapes','vigie_tir_de_signal']

def emblem(kind):
    if kind==0:
        # Two parallel nocked arrows, separated shafts and bronze bowstring.
        for dx,dz in [(-.15,.14),(.15,-.14)]:
            n.arrow((-.44+dx,-.40+dz),(.38+dx,.42+dz),.115,n.glow,True)
        n.arc(-.11,-.09,.49,-.18,2.94,n.wood,.035,sy=.86)
        n.line([(-.59,-.01),(.35,-.20)],.012,n.metal,y=-.39)
    elif kind==1:
        # Ascent arc, burning flare, short radial beams.
        n.arc(-.22,-.22,.47,-1.85,1.20,n.glow,.047,sy=1.12)
        n.arrow((-.02,.02),(.24,.48),.125,n.heart,True)
        n.dot(.23,.42,.105,n.heart)
        for a in [-.45,.35,1.12,1.91,2.65]:
            n.line([(.23+.17*math.cos(a),.42+.17*math.sin(a)),(.23+.28*math.cos(a),.42+.28*math.sin(a))],.018,n.glow)
    elif kind==2:
        # Low ring of four iron caltrops, single embedded arrow.
        for a in [.25,1.85,3.4,4.95]:
            x=.43*math.cos(a);z=-.16+.25*math.sin(a)
            n.plate([(x-.13,z-.08),(x-.035,z+.02),(x,z+.23),(x+.045,z+.015),(x+.15,z-.075),(x+.01,z-.035)],n.metal,b=.012)
            n.line([(x,z+.035),(x,z+.17)],.013,n.glow,y=-.37)
        n.arc(0,-.16,.49,0,math.tau,n.glow,.014,sy=.57)
        n.arrow((.08,.57),(-.13,-.30),.105,n.glow,True)
    else:
        # Monumental upright signal arrow and eight-point star at its summit.
        n.arrow((0,-.64),(0,.50),.21,n.glow,True)
        n.line([(0,-.47),(0,.25)],.023,n.heart,y=-.39)
        points=[]
        for i in range(16):
            a=i*math.tau/16;r=(.24 if i%4==0 else .16) if i%2==0 else .055
            points.append((r*math.cos(a),.46+r*math.sin(a)))
        n.plate(points,n.heart,y=-.42,d=.055,b=.008)

def run():
    random.seed(331)
    n.cel.archive_folder('icons/spells')
    WORK.mkdir(parents=True,exist_ok=True)
    n.WORK=WORK
    s=n.scene('medallion');s.eevee.taa_render_samples=8
    bpy.ops.render.render(write_still=True)
    for i,name in enumerate(NAMES):
        s=n.scene(name,lambda i=i:emblem(i),'#FF3A4F')
        s.eevee.taa_render_samples=8
        bpy.ops.render.render(write_still=True)
        subprocess.run([n.PY,str(BASE/'vigvi_finish.py'),'fit',name],check=True,stdout=subprocess.DEVNULL)
        print('PASS '+name,flush=True)
        bpy.context.window.scene=bpy.data.scenes[0]
        bpy.data.scenes.remove(s)
        bpy.data.orphans_purge(do_recursive=True)

if __name__=='__main__':run()
