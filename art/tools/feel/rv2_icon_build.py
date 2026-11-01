"""Single Rictus Saccade icon, derived from the Rictus spell emblem builder."""
import sys, math, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'art/tools/night'
sys.dont_write_bytecode=True
sys.path.insert(0,str(BASE))
import icons_norm_build as n

def emblem():
    # Unmarked dark medallion; broad spectral return stroke sweeps upward.
    n.arc(0,0,.77,3.68,5.83,n.glow,.045,n=48,sy=.86,y=-.34)
    n.arc(0,0,.70,3.72,5.78,n.heart,.020,n=48,sy=.86,y=-.36)
    # Taut silver wire continues from the blade to the puppet's wooden hand.
    n.line([(-.48,-.48),(-.30,-.30),(-.08,-.08),(.15,.15),(.39,.38)],.022,n.glow,y=-.38)
    n.line([(-.48,-.48),(-.30,-.30),(-.08,-.08),(.15,.15),(.39,.38)],.010,n.heart,y=-.40)
    # Large single double-edged blade, diagonal from lower-left to upper-right.
    n.plate([(-.27,-.30),(-.06,-.10),(.42,.39),(.68,.68),(.56,.30),(.02,-.24)],n.metal,y=-.42,d=.045,b=.012)
    n.line([(-.20,-.27),(.42,.34),(.68,.68)],.019,n.heart,y=-.47)
    # Dark wooden grip and unmistakable puppet hand at the lower end of the tether.
    n.line([(-.39,-.42),(-.20,-.24)],.065,n.wood,y=-.49)
    n.line([(-.38,-.44),(-.19,-.25)],.018,n.heart,y=-.52)
    n.dot(-.48,-.49,.095,n.wood,y=-.54)
    n.line([(-.54,-.47),(-.60,-.38)],.028,n.wood,y=-.55)
    n.line([(-.47,-.55),(-.40,-.61)],.028,n.wood,y=-.55)
    # Four bright, compact silver sparks.
    for x,y in [(.48,.48),(-.10,.42),(.56,.12),(-.40,.06)]:
        n.line([(x-.035,y),(x+.035,y)],.014,n.glow,y=-.58)
        n.line([(x,y-.035),(x,y+.035)],.014,n.glow,y=-.58)
        n.dot(x,y,.020,n.heart,y=-.59)

if __name__=='__main__':
    random.seed(331)
    n.WORK=ROOT/'art/blender/feel2/rv2_icon'
    n.WORK.mkdir(parents=True,exist_ok=True)
    s=n.scene('rv2_icon',emblem,'#8CCBD0')
    s.eevee.taa_render_samples=8
    s.render.resolution_percentage=100
    s.render.filepath=str(ROOT/'art/renders/feel_sorts2/rv2_icon.png')
    n.bpy.ops.render.render(write_still=True)
    n.bpy.ops.wm.save_as_mainfile(filepath=str(n.WORK/'rv2_icon.blend'))
    print('PASS rv2_icon rendered and saved')
