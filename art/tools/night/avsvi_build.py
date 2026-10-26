"""AVSVI: fixed seed, shared Nova geometry/camera/finishing; background only."""
import sys, math, random
from pathlib import Path
BASE=Path(__file__).resolve().parent
sys.path.insert(0,str(BASE))
import icons_norm_build as n
NAMES=['averse_bruine','averse_geyser','averse_gouttiere','averse_mousson']

def drop(x,z,h=.32,w=.065,tilt=0):
    pts=[]
    for j in range(25):
        t=math.tau*j/24
        dx=w*math.sin(t)*(1-.45*math.cos(t))
        dz=h*.5*math.cos(t)
        pts.append((x+dx*math.cos(tilt)+dz*math.sin(tilt),
                    z+dz*math.cos(tilt)-dx*math.sin(tilt)))
    n.plate(pts,n.glow,b=.012)
    n.line([(x-w*.18,z-h*.23),(x-w*.30,z+h*.05)],.012,n.heart,y=-.33)

def bruine():
    for x,z,a in [(-.31,.02,-.28),(0,.16,0),(.31,.02,.28)]:
        drop(x,z,.55,.063,a)
        n.line([(x-.035,-.40),(x-.07,-.53)],.012,n.heart)
    for x,z in [(-.48,.30),(.43,.42)]:
        n.line([(x,z),(x-.025,z-.16)],.012)

def geyser():
    n.arc(0,-.43,.30,0,math.tau,n.metal,.055,sy=.35)
    n.plate([(-.16,-.40),(-.10,.18),(-.23,.39),(-.06,.32),
             (0,.59),(.07,.32),(.24,.41),(.13,.14),(.17,-.40)],b=.025)
    n.line([(-.02,-.33),(-.025,.08),(0,.35)],.026,n.heart,y=-.34)
    for x,z,a in [(-.33,.28,-.4),(.34,.20,.4),(-.22,.52,-.5)]:
        drop(x,z,.16,.035,a)

def gouttiere():
    # Open U-section gutter: two raised metal lips, water recessed between.
    path=[(-.39,.48),(-.39,-.22),(-.30,-.39),(-.10,-.44),(.23,-.44)]
    for offset in [-.075,.075]:
        n.line([(x+offset,z) for x,z in path],.052,n.metal,y=-.24)
    n.line(path,.046,n.glow,y=-.30)
    n.line([(-.40,.42),(-.40,-.20),(-.28,-.34),(.25,-.36)],.015,n.heart,y=-.36)
    n.line([(.25,-.36),(.34,-.41),(.35,-.52)],.034)
    drop(.35,-.57,.14,.04)
    n.line([(-.55,.48),(-.23,.48)],.035,n.metal,y=-.23)

def mousson():
    # Tilted amphora, two handles and a narrow pouring neck.
    pts=[(-.53,.26),(-.50,.47),(-.33,.57),(-.10,.55),(.02,.43),
         (-.01,.27),(.13,.15),(.06,.04),(-.09,.13),(-.29,.10),(-.46,.15)]
    n.plate(pts,n.metal,b=.035)
    n.arc(-.43,.43,.13,.2,4.5,n.metal,.035,sy=.75)
    n.arc(-.06,.42,.12,-1.2,2.6,n.metal,.032,sy=.8)
    n.line([(-.46,.22),(-.27,.18),(-.10,.22)],.025,n.glow,y=-.34)
    for i in range(5):
        x=.03+i*.075
        n.line([(x,.08),(x+.06,-.10),(x+.08,-.36-i*.025)],.024 if i%2 else .032)
    # Dense rain cloud under the overflowing mouth.
    for x,z,r in [(.01,-.12,.12),(.15,-.09,.14),(.30,-.14,.12),(.39,-.19,.09)]:
        n.dot(x,z,r)
    for x in [-.03,.12,.27,.42]:
        n.line([(x,-.33),(x-.04,-.52)],.015,n.heart,y=-.36)

def run():
    n.cel.archive_folder('icons/spells')
    n.WORK.mkdir(parents=True,exist_ok=True)
    n.cel.install('icon',normals=False)
    # Reuse the existing runner, including its scene, camera, fit and resume behavior.
    n.ICONS=dict(zip(NAMES,[('#5FD4E8',f) for f in [bruine,geyser,gouttiere,mousson]]))
    sys.argv=[sys.argv[0],'--','--only',','.join(NAMES),'--resume']
    n.run()

if __name__=='__main__':run()
