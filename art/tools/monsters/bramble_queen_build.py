"""R8b: mist forest PBR remodel, preserved hierarchy and animation timelines."""
import sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
from _r8b_geometry import queen
def build():
    root,body,head,arms,roots,puddle,ringo,chunks,glow=queen()
    def animate(a,i,n,f):
        t=i*math.tau/n;p=i/(n-1);run=a=='run';dead=p if a=='death' else 0;sp=p if a=='phase2' else 0
        body.location=(0,0,.04*math.sin(2*t) if run else .1*math.sin(t) if a=='idle' else -.12*dead)
        body.rotation_euler=(-.1*math.sin(p*math.pi) if a=='cast_a' else .08 if run else -.9*dead,0,.04*math.sin(t) if run else 0)
        body.scale=(1+.04*sp,1+.04*sp,1);key(body,f)
        head.rotation_euler=(.2*math.sin(p*math.pi) if a=='cast_a' else -.3*math.sin(p*math.pi) if a=='cast_b' else 0,0,.05*math.sin(t) if a=='idle' else 0);key(head,f)
        for arm,sign in arms:
            ax=.35*sign*math.sin(t) if run else 0;ay=0
            if a=='attack':ax=sign*[0,-.7,-1.5,.9,.5,0][i] if sign==1 else 0
            if a=='cast_a':ax=.15;ay=-sign*.5*math.sin(p*math.pi)
            if a=='cast_b':ax=0;ay=-sign*2.5*math.sin(p*math.pi)
            if a=='phase2':ay=-sign*(.5+1.6*math.sin(p*math.pi))
            if a=='idle':ay=-sign*(.08+.04*math.sin(t))
            arm.rotation_euler=(ax,ay,0);key(arm,f)
        for j,r in enumerate(roots):
            r.rotation_euler.z=math.radians(-62+j*15.5)+(.12*math.sin(t+j) if a in('idle','run') else .25*math.sin(p*3+j)*(1 if a=='phase2' else 0)+dead*.3)
            key(r,f)
        q=(.5+.5*min(1,(i-2)/3)) if a=='cast_a' and i>=3 else .001;puddle.scale=(q,q,q);key(puddle,f)
        q=(.4+.6*p) if a=='cast_b' and i>=4 else .001;ringo.scale=(q,q,q);key(ringo,f)
        for j,(o,loc) in enumerate(chunks):
            o.location=loc+Vector((math.sin(j*2.4)*dead*.5,0,-dead*loc.z*.6));o.rotation_euler=(dead*j,0,0);key(o,f)
        pulse(glow,f,1.2+.6*math.sin(t) if a!='phase2' else 2+4*p)
    export('bramble_queen',root,animate)
if __name__=='__main__':build()
