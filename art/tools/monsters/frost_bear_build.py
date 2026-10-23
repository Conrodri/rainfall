"""R8d drowned terraces sculpt; original pose hierarchy and timelines preserved."""
import sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
from _r8d_geometry import bear

def build():
    root,body,head,legs,breath,crown,glow=bear()
    def animate(a,i,n,f):
        t=i*math.tau/n;p=i/(n-1);dead=p if a=='death' else 0;rear=p if a=='phase2' else 0
        body.location=(0,.25*rear,.05*math.sin(2*t) if a=='run' else .28*rear+.28*dead)
        body.rotation_euler=(-.45*rear,.65*dead+(.035*math.cos(t) if a=='run' else 0),.025*math.sin(t) if a=='run' else .035*math.cos(t) if a=='idle' else 0)
        body.scale=(1+.018*math.sin(t) if a=='idle' else 1,1,1-.65*dead);key(body,f)
        head.rotation_euler.x=(-.55*math.sin(p*math.pi) if a=='cast_b' else .18 if a=='cast_a' else 0)-.15*rear
        head.location=(0,-.87-(.08*math.sin(p*math.pi) if a=='cast_a' else 0),.97+(.16*math.sin(p*math.pi) if a=='cast_b' else 0));key(head,f)
        for leg,sign,y in legs:
            x=sign*(1 if y<0 else -1)*.55*math.sin(t) if a=='run' else 0
            if a=='attack' and y<0 and sign==1:x=[.65,.95,1.2,-1.15,-.6,0][i]
            if y<0:x+=.5*rear
            leg.rotation_euler=(x,sign*.5*dead,0);key(leg,f)
        q=.12+.02*math.sin(t) if a=='idle' else (.65+.35*math.sin(p*math.pi) if a=='cast_a' else .001)
        breath.scale=(q,q,q);key(breath,f)
        q=.75+p*.45 if a=='cast_b' and i>=3 else .001;crown.scale=(q,q,q);key(crown,f)
        pulse(glow,f,.7+.6*(1+math.sin(t)) if a!='phase2' else 1+p*2)
    export('frost_bear',root,animate)
if __name__=='__main__':build()

