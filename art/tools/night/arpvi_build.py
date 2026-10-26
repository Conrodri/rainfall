"""ARPVI: copper round-link reliefs; shared Nova runner, fixed seed 331."""
import sys, math
from pathlib import Path
BASE=Path(__file__).resolve().parent
sys.path.insert(0,str(BASE))
import icons_norm_build as n
NAMES=['arpenteuse_chaine_lestee','arpenteuse_noeud','arpenteuse_jalons','arpenteuse_cerceau']

def lestee():
    n.chain([(-.05,.56),(-.09,.42),(-.06,.28),(.01,.14),(.04,0)])
    n.sphere((.04,-.28,-.31),(.265,.20,.265),n.metal,name='heavy iron ballast')
    n.arc(.04,-.31,.263,.35,2.75,n.glow,.026,y=-.40)
    n.arc(.04,-.31,.21,.65,1.8,n.heart,.012,y=-.46)

def noeud():
    # Two crossing loops with alternating depth: a compact, visibly tied knot.
    for k in range(20):
        a=math.tau*k/20
        x=.43*math.sin(a);z=.28*math.sin(2*a)
        n.arc(x,z,.082,0,math.tau,n.glow,.023,22,sy=.7 if k%2 else 1,y=-.29-.07*math.cos(a))
    n.chain([(-.43,-.25),(-.50,-.38),(.43,.25),(.50,.38)])
    n.plate([(0,.13),(.035,.035),(.13,0),(.035,-.035),(0,-.13),(-.035,-.035),(-.13,0),(-.035,.035)],n.heart,y=-.44,b=.008)

def jalons():
    for x in [-.43,0,.43]:
        n.plate([(x-.045,.43),(x+.045,.43),(x+.045,-.29),(x,-.49),(x-.045,-.29)],n.metal,b=.012)
        n.line([(x-.05,.43),(x+.05,.43)],.035,n.glow)
        n.line([(x-.02,.32),(x-.02,-.24)],.014,n.heart,y=-.33)
    n.chain([(x,.11) for x in [-.43,-.287,-.144,0,.144,.287,.43]])

def cerceau():
    n.chain([(.52*math.cos(math.tau*j/23),.52*math.sin(math.tau*j/23)) for j in range(23)],closed=True)

def run():
    n.cel.archive_folder('icons/spells')
    n.cel.install('icon',normals=False)
    n.ICONS=dict(zip(NAMES,[('#FF7A1F',f) for f in [lestee,noeud,jalons,cerceau]]))
    sys.argv=[sys.argv[0],'--','--only',','.join(NAMES),'--resume']
    n.run()

if __name__=='__main__':run()
