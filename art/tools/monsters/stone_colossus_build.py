"""R8d drowned terraces sculpt; original pose hierarchy and timelines preserved."""
import sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
from _r8d_geometry import colossus

def build():
    root,body,jaw,arms,legs,chunks,wave,fire=colossus()
    def animate(a,i,n,f):
        t=i*math.tau/n;p=i/(n-1);run=a=='run';dead=p if a=='death' else 0
        slam=(1 if i in (4,5) else .5 if i==6 else 0) if a=='cast_b' else 0
        body.location=(0,-(.25*math.sin(p*math.pi) if a=='cast_a' else 0),.045*math.sin(2*t) if run else .15*dead-.6*slam)
        body.rotation_euler=(.32*math.sin(p*math.pi) if a=='cast_a' else .8*dead,.03*math.cos(t) if run else 0,.035*math.sin(t) if run else .03*math.cos(t) if a=='idle' else 0)
        body.scale=(1,1,1+.018*math.sin(t) if a=='idle' else 1-.65*dead);key(body,f)
        for arm,sign in arms:
            lift=sign*.30*math.sin(t) if run else 0
            if a=='attack' and sign==1:lift=[1.0,1.35,1.6,-1.4,-.8,0][i]
            if a=='cast_a':lift=.65*math.sin(p*math.pi)
            if a=='cast_b':lift=[.4,.8,1.5,1.8,0,.03,.1,0][i]
            if a=='phase2':lift=-.6*p
            arm.rotation_euler=(lift,0,sign*(.45*p if a=='phase2' else .65*dead));key(arm,f)
        for leg,sign in legs:
            leg.rotation_euler.x=sign*.38*math.sin(t) if run else .55*dead;leg.scale=(1,1,1-.75*slam);key(leg,f)
        jaw.rotation_euler.x=.65*p if a=='phase2' else 0;key(jaw,f)
        q=(.65+p*.45) if a=='cast_b' and i>=4 else .001;wave.scale=(q,q,q);key(wave,f)
        for j,(o,loc) in enumerate(chunks):
            o.location=loc+Vector((math.sin(j*2.4)*dead*.7,0,-dead*loc.z*.7));o.rotation_euler=(dead*j,.2*dead*j,0);key(o,f)
        pulse(fire,f,(1.3+.7*math.sin(t)) if a!='phase2' else 2+5*p)
    export('stone_colossus',root,animate)
if __name__=='__main__':build()

