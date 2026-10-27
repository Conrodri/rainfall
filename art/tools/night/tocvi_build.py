"""TOCVI: deterministic relief variants; approved TOCP3 kit icons retained."""
import sys, math, random
from pathlib import Path
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
sys.path.insert(0,str(BASE))
import icons_norm_build as k
import bpy
WORK=ROOT/'art/blender/cel/tocvi'
k.WORK=WORK

def smoke(points,r):
    k.line(points,r,k.pale,y=-.43)

def furnace():
    metal=k.mat('#5F8F80',.75,.7)
    k.plate([(-.55,-.42),(-.14,-.42),(-.12,.02),(-.47,.15),(-.59,-.05)],metal)
    k.plate([(-.51,-.30),(-.22,-.30),(-.22,-.06),(-.49,-.02)],k.dark,y=-.38)
    for x in (-.46,-.36,-.26):k.line([(x,-.26),(x+.035,-.09)],.025,k.glow,y=-.41)
    k.plate([(-.23,.02),(-.08,.18),(.06,.09),(-.10,-.08)],metal,y=-.36)
    # Widening diagonal cone, three separated white vapour curls.
    for j in range(3):
        z=.02+j*.12
        smoke([(-.03,z),(.15,z+.11),(.37,z+.10),(.53,z+.22),(.46,z+.33),(.29,z+.32)],.037+j*.009)
    for x,z in [(-.07,-.16),(.10,-.07),(.23,-.12)]:k.dot(x,z,.023,k.glow,y=-.45)

def smoking_head():
    metal=k.mat('#5F8F80',.75,.7)
    k.plate([(-.40,-.44),(-.28,-.23),(-.23,.08),(-.12,.19),(.10,.19),(.23,.07),(.28,-.24),(.40,-.44)],metal)
    k.line([(-.41,-.44),(.41,-.44)],.045,k.dark)
    k.line([(-.07,.06),(.02,-.10),(-.04,-.22),(.09,-.37)],.028,k.glow,y=-.40)
    for x in (-.13,.13):k.line([(x-.04,-.08),(x+.04,-.08)],.024,k.dark,y=-.42)
    # Heavy asymmetric mushroom plume, different silhouette from base bell.
    for x,z,r in [(-.10,.27,.13),(-.30,.35,.17),(-.32,.52,.17),(-.10,.56,.20),(.12,.49,.19),(.32,.47,.14)]:
        k.sphere((x,-.34,z),(r,r*.60,r*.73),k.pale)
    for x,z in [(-.42,.14),(.40,.21),(.25,.02)]:
        k.line([(x,z),(x+.025,z+.075)],.019,k.glow,y=-.47)

def run():
    random.seed(331);WORK.mkdir(parents=True,exist_ok=True)
    k.cel.archive_folder('icons/spells')
    s=k.scene('medallion');s.render.threads_mode='FIXED';s.render.threads=8
    bpy.ops.render.render(write_still=True)
    for name,fn in [('tocsin_vapeur',furnace),('tocsin_tete_fumigene',smoking_head)]:
        s=k.scene(name,fn,'#FF7A1F');s.render.threads_mode='FIXED';s.render.threads=8
        bpy.ops.render.render(write_still=True)
        print('PASS '+name,flush=True)
if __name__=='__main__':
    run()
    import subprocess
    subprocess.run([k.PY,str(BASE/'tocvi_finish.py')],check=True)

