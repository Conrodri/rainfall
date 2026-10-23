"""4 cadres de rareté + 8 icônes de sorts d'Ardent. Blender background. -- noms pour un sous-ensemble."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_kit import *
import items_b as b
poly=b.poly
OUT=ROOT/'game/assets/sprites/icons'
RAW=ROOT/'art/renders/ui/spells'
FRAMES={'frame_commun':'#7C8898','frame_peu_commun':'#5FA85B','frame_rare':'#8A5FD0','frame_legendaire':'#F2C14E'}
SPELLS=['eclat_de_braise','nova_ardente','cendres','brasier','braises_errantes','pilier_de_flamme','pluie_de_meteores','phenix']

def tint(h,k):
    h=h.lstrip('#'); c=[int(h[i:i+2],16) for i in (0,2,4)]
    c=[max(0,min(255,round(v*k if k<1 else v+(255-v)*(k-1)))) for v in c]
    return '#%02X%02X%02X'%tuple(c)

def frame(name):
    col=FRAMES[name]; leg=name.endswith('legendaire')
    base=mat(tint(col,1.12),.4,.45 if leg else .3,col,.5); dark=mat(tint(col,.5),.5,.3); light=mat(tint(col,1.5),.3,.5,tint(col,1.5),.3)
    ember=mat('#FF7A1F',.3,0,'#FFB347',2.0) if leg else mat(tint(col,1.25),.3,.4)
    W=2.3
    rr_ring(W,W,.46,.4,base,.3,0,.05)
    rr_ring(W-.56,W-.56,.3,.12,dark,.16,-.14,.025)
    rr_ring(W-.14,W-.14,.42,.05,light,.07,-.15,.015)
    rr_ring(W-.66,W-.66,.26,.04,ember,.06,-.2,.01)
    for sx in (-1,1):
        for sz in (-1,1):
            sphere((sx*.9,-.2,sz*.9),(.1,.08,.1),light if not leg else mat('#FFB347',.3,0,'#FFB347',1.5))
    for sx in (-1,1):
        bevelled_box((sx*1.0,-.15,0),(.07,.06,.5),dark,.02); bevelled_box((0,-.15,sx*1.0),(.5,.06,.07),dark,.02)
    if leg:
        for sx in (-1,1):
            sphere((sx*.0,-.2,sx*1.0),(.12,.06,.07),mat('#FFE9A8',.3,0,'#FFE9A8',2.0))
            sphere((sx*1.0,-.2,0),(.07,.06,.12),mat('#FFE9A8',.3,0,'#FFE9A8',2.0))

def flame(x,z,r,h,m,bend=0,y=0):
    o=lathe([(0,-h*.5),(r*.65,-h*.42),(r,-h*.2),(r*.82,h*.03),(r*.38,h*.25),(0,h*.5)],(x,y,z),m,24,'Flamme')
    for v in o.data.vertices:
        t=max(0,(v.co.z/h+.1)); v.co.x+=bend*t*t
    o.scale.y=.65; return o

def emi(h,s=1.0,rough=.3):return mat(h,rough,0,h,s)

def eclat_de_braise():
    def build():
        sphere((0,0,0),(.62,.62,.62),emi('#FF7A1F',.9))
        sphere((.05,-.14,0),(.4,.36,.4),emi('#FFB347',1.2))
        sphere((.1,-.26,.02),(.2,.18,.2),emi('#FFE9A8',1.5))
        o=cone((.92,0,0),.46,1.1,emi('#FF7A1F',.9),8); o.rotation_euler[1]=math.pi/2
        o=cone((.92,-.1,0),.3,.95,emi('#FFB347',1.1),8); o.rotation_euler[1]=math.pi/2
        for i,(dx,dz,L) in enumerate([(-1.0,.28,.9),(-1.15,-.1,1.1),(-.95,-.42,.8)]):
            o=cone((dx,0,dz),.26,L,emi('#FF7A1F',.9) if i!=1 else emi('#FFB347',1.0),6); o.rotation_euler[1]=-math.pi/2
        for x,z in [(-1.5,.6),(-1.65,-.5),(-1.0,.8)]:sphere((x,0,z),(.06,.06,.06),a.gold)
    group(build,rot=(0,math.radians(35),0))

def nova_ardente():
    fire=emi('#FF7A1F',.9); gl=emi('#FFB347',1.1)
    torus((0,0,0),.82,.17,fire); torus((0,-.08,0),.82,.09,gl)
    for i in range(14):
        t=i*math.tau/14; L=.62 if i%2==0 else .42
        r=.95+L/2
        o=cone((r*math.sin(t),0,r*math.cos(t)),.17,L,fire if i%2==0 else gl,6); toward(o,(math.sin(t),0,math.cos(t)))
    for i in range(7):
        t=i*math.tau/7+.2
        o=cone(((.5)*math.sin(t),0,.5*math.cos(t)),.08,.22,gl,4); toward(o,(math.sin(t),0,math.cos(t)))
    sphere((0,0,0),(.2,.1,.2),emi('#FFE9A8',1.5))

def cendres():
    ash=mat('#4A5565',.9); ash2=mat('#2B3340',.9); ash3=mat('#6A7686',.9)
    for x,z,sx,sz,m in [(0,-.55,1.1,.4,ash2),(-.5,-.3,.6,.4,ash),(.5,-.3,.6,.38,ash),(0,-.1,.55,.45,ash3),(-.15,.15,.32,.28,ash)]:
        sphere((x,0,z),(sx,sx*.8,sz),m)
    hot=emi('#FF7A1F',1.4)
    for x,z in [(-.3,-.12),(.3,-.1),(.05,-.35),(-.65,-.5),(.7,-.5),(0,.2)]:
        sphere((x,-.5,z),(.11,.05,.08),hot)
    curve([(-.2,-.55,-.2),(-.05,-.55,-.05),(.1,-.55,-.2),(.25,-.55,-.05)],.04,emi('#FFB347',1.2))
    smoke=mat('#8A96A6',.9)
    for x,z,r in [(-.1,.6,.28),(.2,.95,.22),(-.18,1.25,.2),(.1,1.5,.14)]:sphere((x,.05,z),(r,r*.7,r),smoke)
    for x,z in [(-.6,.5),(.65,.35),(.4,.9)]:sphere((x,-.2,z),(.06,.06,.06),a.orange)

def brasier():
    iron=mat('#2B3340',.55,.45); steel=a.steel
    lathe([(0,-.55),(.45,-.5),(.8,-.2),(.95,.15),(.82,.18),(0,.05)],(0,0,-.35),iron,32)
    torus((0,0,-.18),.9,.08,steel).rotation_euler[0]=0
    for x in (-.5,0,.5):
        bevelled_box((x,0,-1.0),(.14,.14,.55),iron,.03).rotation_euler[1]=x*.4
    cylinder((0,0,-.2),.82,.05,emi('#FF7A1F',1.2))
    flame(0,.55,.62,2.0,emi('#FF7A1F',.9),.5)
    flame(-.5,.15,.36,1.2,emi('#FF7A1F',.9),-.3); flame(.5,.1,.34,1.1,emi('#FF7A1F',.9),.3)
    f=flame(0,.35,.38,1.3,emi('#FFB347',1.1),.25); f.location.y=-.32
    f=flame(0,.1,.2,.7,emi('#FFE9A8',1.5),.1); f.location.y=-.55
    for x,z in [(-.9,.75),(.85,1.0),(.2,1.65)]:sphere((x,0,z),(.07,.07,.1),a.gold)

def orb(x,z,r,tailx,tailz):
    sphere((x,0,z),(r,r,r),emi('#FF7A1F',.9)); sphere((x,-r*.4,z),(r*.65,r*.5,r*.65),emi('#FFB347',1.2))
    sphere((x,-r*.7,z),(r*.3,r*.2,r*.3),emi('#FFE9A8',1.6))
    o=cone((x+tailx*r*1.8,0,z+tailz*r*1.8),r*.8,r*3,emi('#FF7A1F',.9),6); toward(o,(-tailx,0,-tailz)) if False else None
    d=Vector((tailx,0,tailz)); toward(o,-d)
    return o

def braises_errantes():
    gold=a.gold
    t=torus((0,.15,0),1.05,.045,gold); t.rotation_euler=(1.25,0,.35); t.scale=(1,1.0,1)
    ell=lambda ang:(1.05*math.cos(ang)*math.cos(.35)-.4*math.sin(ang)*math.sin(.35)*0,0,.45*math.sin(ang))
    for ang in (.5,2.6,4.7):
        x=1.0*math.cos(ang); z=.58*math.sin(ang)*1.0
        dx,dz=-math.sin(ang),.58*math.cos(ang); n=math.hypot(dx,dz)
        orb(x,z,.36,-dx/n,-dz/n)
        torus((x,-.25,z),.42,.035,gold)
    sphere((0,0,0),(.13,.13,.13),emi('#FFE9A8',2))
    for x,z in [(-.9,.9),(.9,-.95),(.1,1.0)]:sphere((x,0,z),(.06,.06,.06),gold)

def pilier_de_flamme():
    fire=emi('#FF7A1F',.9); gl=emi('#FFB347',1.1); core=emi('#FFE9A8',1.5)
    torus((0,0,-.95),.8,.05,a.gold).scale=(1,1,1)
    cyl=cylinder((0,0,-1.02),.82,.1,a.dark)
    cylinder((0,0,-.98),.7,.06,emi('#C23B12',1.0))
    lathe([(0,-.9),(.52,-.86),(.62,-.4),(.5,.5),(.3,1.1),(.12,1.6),(0,1.9)],(0,0,-.05),fire,28)
    lathe([(0,-.85),(.34,-.8),(.4,-.3),(.3,.5),(.17,1.0),(0,1.4)],(0,-.2,-.05),gl,28)
    lathe([(0,-.8),(.17,-.75),(.2,-.2),(.12,.45),(0,.8)],(0,-.35,-.05),core,28)
    for i in range(6):
        t=i*math.tau/6
        o=cone((.75*math.sin(t),.75*math.cos(t)*.0,-.75+.4*(i%2)),.14,.65+.2*(i%2),fire if i%2 else gl,5)
        o.location=(.78*math.sin(t),-.1*abs(math.cos(t)),-.6+.3*(i%2))
    for z in (-.35,.35,.95):torus((0,0,z),.55-z*.15,.045,a.gold)
    for x,z,r,h,m in [(-.62,-.1,.22,1.0,fire),(.62,.0,.2,.9,fire),(-.4,.7,.16,.7,gl),(.4,.9,.15,.65,gl)]:flame(x,z,r,h,m,x*.4)
    for x,z in [(-.55,1.1),(.5,1.45),(.15,2.1),(-.4,.2)]:sphere((x,0,z),(.06,.06,.09),a.gold)

def meteor(x,z,s):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=s,location=(x,0,z)); r=bpy.context.object
    r.scale=(1,.9,.9); r.data.materials.append(mat('#3F2B1E',.8))
    bm=r.modifiers.new('Bev','BEVEL'); bm.width=s*.08; bm.segments=2
    for dx,dz,k in [(.3,.1,.35),(-.15,.35,.3)]:
        sphere((x+dx*s,-s*.75,z+dz*s),(s*k*.8,s*.12,s*k*.7),emi('#FF7A1F',1.6))
    d=Vector((1,0,-1)).normalized()
    c=cone((x,0,z),s*.95,s*3.2,emi('#FF7A1F',.9),8); c.location=(x-d.x*s*2.0,0,z-d.z*s*2.0); toward(c,-d)
    c=cone((x,-.1,z),s*.6,s*2.6,emi('#FFB347',1.1),8); c.location=(x-d.x*s*1.6,-.1,z-d.z*s*1.6); toward(c,-d)
    sphere((x-d.x*s*.2,-s*.2,z-d.z*s*.2),(s*.5,s*.4,s*.5),emi('#FFB347',.8)) if False else None

def pluie_de_meteores():
    for x,z,s in [(.55,.75,.52),(-.5,-.1,.42),(.7,-.7,.36)]:meteor(x,z,s)
    for x,z in [(-.9,.8),(.1,.2),(-.2,-.8),(1.0,.05)]:sphere((x,0,z),(.06,.06,.06),a.gold)

def phenix():
    fire=emi('#FF7A1F',.9); gl=emi('#FFB347',1.2); core=emi('#FFE9A8',1.6); gold=emi('#F2C14E',1.0)
    for s in (-1,1):
        for k,(ang,L,m) in enumerate([(2.15,1.35,fire),(1.75,1.55,gl),(1.35,1.6,fire),(.95,1.45,gl),(.6,1.2,fire)]):
            bx,bz=s*.22,.15; tx,tz=bx+s*L*math.cos(ang-.2)*.95,bz+L*math.sin(ang)*.62
            mx,mz=(bx+tx)/2,(bz+tz)/2; dx,dz=tx-bx,tz-bz; n=math.hypot(dx,dz); px,pz=-dz/n*.2,dx/n*.2
            poly([(bx,bz),(mx+px,mz+pz),(tx,tz),(mx-px,mz-pz)],m,.1,-.04*k+.1)
    sphere((0,-.1,-.1),(.34,.26,.55),gl); sphere((0,-.25,-.05),(.2,.12,.38),core)
    sphere((0,-.12,.55),(.2,.18,.2),gl)
    c=cone((.27,-.12,.55),.08,.3,gold,4); c.rotation_euler[1]=math.pi/2
    sphere((.09,-.3,.6),(.045,.02,.045),a.dark)
    for dx,dz in [(-.08,.8),(0,.88),(.1,.78)]:
        poly([(dx-.05,dz-.05),(dx,dz+.2),(dx+.05,dz-.05)],gold,.05,-.1)
    for i,(x,L) in enumerate([(-.3,1.3),(-.1,1.5),(.1,1.5),(.3,1.3)]):
        poly([(x,-.45),(x+.17,-.45-L*.5),(x*1.8,-.45-L),(x-.17,-.45-L*.5)],gold if i%3==0 else (fire if i%2 else gl),.07,.0)
    for x,z in [(-1.5,.2),(1.45,.8),(1.1,-.5),(-1.1,-.6)]:sphere((x,0,z),(.06,.06,.06),a.gold)

def render_spells(chosen):
    for n in chosen:
        s=new_scene(n)
        globals()[n]()
        outline(meshes()); frame_object_ortho(meshes())
        raw=RAW/f'{n}.png'; render_to(raw)
        post(dict(mode='icon',src=str(raw),dst=str(OUT/'spells'/f'{n}.png'),size=256,margin=12)); print('SPELL_OK',n,flush=True)

def render_frames(chosen):
    for n in chosen:
        s=new_scene(n); frame(n); outline(meshes()); front_camera(2.42,2.42,512,512)
        raw=RAW/f'{n}.png'; render_to(raw)
        post(dict(mode='resize',src=str(raw),dst=str(OUT/f'{n}.png'),w=256,h=256)); print('FRAME_OK',n,flush=True)

def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    fr=[n for n in FRAMES if not args or n in args]; sp=[n for n in SPELLS if not args or n in args]
    render_frames(fr); render_spells(sp); flush_post()
    s=bpy.data.scenes
    for x in list(s):
        if len(s)>1 and x==bpy.context.scene and False:pass
    save_blend('spells_frames.blend' if not args else 'spells_frames_part.blend')
if __name__=='__main__':main()
