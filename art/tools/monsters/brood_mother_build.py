"""R8b: mist forest PBR remodel, preserved hierarchy and animation timelines."""
import sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
from _r8b_geometry import brood
def build():
    root,body,head,abd,wings,legs,eggs,swarm,chunks,core,belly=brood()
    def animate(a,i,n,f):
        t=i*math.tau/n;p=i/(n-1);run=a=='run';dead=p if a=='death' else 0;sp=p if a=='phase2' else 0
        body.location=(0,0,.05*math.sin(2*t) if run else .06*math.sin(t) if a=='idle' else -.55*dead)
        body.rotation_euler=(.1 if run else 0,0,.04*math.sin(t) if run else .5*dead);body.scale=(1,1,1-.2*dead);key(body,f)
        ax=-.15 if run else 0
        if a=='cast_a':ax+=1.0*math.sin(p*math.pi)
        if a=='cast_b':ax-=.9*math.sin(p*math.pi)
        if a=='attack':ax-=.35*math.sin(p*math.pi)
        abd.rotation_euler.x=ax
        q=1+(.06*math.sin(t) if a=='idle' else 0)+(.12*sp+.06*sp*math.sin(8*p) if a=='phase2' else 0)+(.25*math.sin(p*math.pi) if a=='attack' else 0)
        abd.scale=(q,q,q);key(abd,f)
        head.rotation_euler.x=.4*math.sin(p*math.pi) if a=='attack' else 0;key(head,f)
        for w,sign in wings:
            flap=.55*math.sin(t*3 if a in('idle','run') else p*math.pi*(5 if a=='phase2' else 2))
            if a=='cast_b':flap=.5+.8*math.sin(p*math.pi)
            w.rotation_euler=(0,-sign*(.15+flap),0);key(w,f)
        for leg,sign,k in legs:
            x=.5*math.sin(t+k*.65+(math.pi if (k+(sign==1))%2 else 0)) if run else .12*math.sin(t+k) if a=='idle' else .6*dead
            if a=='attack':x=-.5*math.sin(p*math.pi) if k==0 else 0
            leg.rotation_euler=(x,0,sign*(.1*math.sin(2*t) if run else 0)+sign*.8*dead);key(leg,f)
        q=(.5+.5*min(1,(i-3)/3)) if a=='cast_a' and i>=3 else .001;eggs.scale=(q,q,q);key(eggs,f)
        q=(.4+.8*p) if a=='cast_b' and i>=2 else .001;swarm.scale=(q,q,q);swarm.rotation_euler.z=t if a=='cast_b' else 0;key(swarm,f)
        for j,(o,loc) in enumerate(chunks):
            o.location=loc+Vector((math.sin(j*2.4)*(sp+dead)*.5,math.cos(j)*(sp+dead)*.5,sp*.1-dead*.7));key(o,f)
        pulse(core,f,1.6+1.0*math.sin(t) if a!='phase2' else 2+5*p)
    export('brood_mother',root,animate)
if __name__=='__main__':build()
