"""Icônes d'invite de touches 3D neutres (aucune marque, aucun texte). Blender background.
Specs : key_1x1 64x64, key_2x1 128x64, mouse_* / pad_* 64x64, crosshair 96x96. Sorties game/assets/sprites/ui/prompts/ (+ crosshair.png dans ui/).
Usage : blender --background --python prompts.py [-- nom ...]"""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_kit import *
UI=ROOT/'game/assets/sprites/ui'
OUT=UI/'prompts'
RAW=ROOT/'art/renders/ui/prompts'
EMB=lambda s=1.6: mat('#FF7A1F',.3,0,'#FF9A3A',s)

# ---------------------------------------------------------------- touches
def key(w):
    base=mat('#2B3340',.55,.3); cap=mat('#E9EDF4',.35,.1)
    bevelled_box((0,0,0),(w*1.0,.5,1.0),base,.1,'Socle')
    bevelled_box((0,-.3,.04),(w*.86,.3,.8),cap,.12,'Capuchon')
    bevelled_box((0,-.47,.04),(w*.7,.04,.6),mat('#C9D2DF',.5),.02,'Creux')

# ---------------------------------------------------------------- souris
def mouse(which):
    body=mat('#8E9AAB',.4,.3); dark=mat('#2B3340',.6,.2)
    s=sphere((0,0,-.05),(.82,.34,1.2),body,'Corps')
    hl={'left':(-1,),'right':(1,),'wheel':()}[which]
    for sx in (-1,1):
        m=EMB() if sx in hl else mat('#C9D2DF',.35,.1)
        bevelled_box((sx*.3,-.22,.55),(.5,.18,.65),m,.06,'Bouton')
    curve([(0,-.28,.15),(0,-.28,1.0)],.03,dark,'Fente')
    curve([(-.78,-.2,.15),(.78,-.2,.15)],.03,dark,'Fente2')
    wm=EMB(2.2) if which=='wheel' else mat('#3A4458',.4,.4)
    bevelled_box((0,-.32,.6),(.14,.14,.44),wm,.05,'Molette')

# ---------------------------------------------------------------- manette : boutons
def pad_btn(col):
    emit=col
    a.disk((0,0,0),.85,.3,mat('#2B3340',.5,.4)); torus((0,-.17,0),.78,.07,mat('#8E9AAB',.35,.6))
    a.disk((0,-.2,0),.66,.08,mat(col,.28,.1,emit,.25))
    sphere((-.2,-.28,.22),(.14,.05,.1),mat('#FFFFFF',.2,0,'#FFFFFF',.6),'Reflet')

def pad_pos(pos):
    pts={'bottom':(0,-.62),'right':(.62,0),'left':(-.62,0),'top':(0,.62)}
    cross=mat('#2B3340',.55,.3)
    bevelled_box((0,0,0),(.9,.2,.28),cross,.05,'Croix1'); bevelled_box((0,0,0),(.28,.2,.9),cross,.05,'Croix2')
    a.disk((0,0,0),1.0,.12,mat('#3A4458',.6,.2))
    for k,(x,z) in pts.items():
        m=EMB(2.0) if k==pos else mat('#5E6B7D',.5,.3)
        a.disk((x*1.0,-.15,z*1.0),.3,.18,m)

# ---------------------------------------------------------------- manette : épaules
def pad_shoulder(kind,side):
    sx=-1 if side=='l' else 1
    body=mat('#3A4458',.5,.35)
    bevelled_box((0,0,-.55),(2.3,.5,.85),body,.2,'Corps')
    bevelled_box((0,-.27,-.6),(1.7,.1,.5),mat('#2B3340',.6,.2),.05,'Plastron')
    for s in (-1,1):
        hot=(s==sx)
        # gâchette (arrière, haute) et bumper (devant, fin)
        t=EMB(1.8) if (hot and kind=='t') else mat('#8E9AAB',.4,.4)
        b=EMB(1.8) if (hot and kind=='b') else mat('#C9D2DF',.4,.3)
        bevelled_box((s*.88,.06,.45),(.7,.42,.55),t,.12,'Gachette')
        bevelled_box((s*.88,-.2,.08),(.82,.3,.24),b,.08,'Bumper')

def pad_stick(side):
    sx=-1 if side=='l' else 1
    bevelled_box((0,0,0),(2.3,.5,1.5),mat('#3A4458',.5,.35),.25,'Corps')
    for s,(x,z) in {-1:(-.55,.12),1:(.55,-.3)}.items():
        pass
    for x,z,hot in [(-.55,.15,sx==-1),(.55,-.3,sx==1)]:
        a.disk((x,-.3,z),.42,.12,mat('#1a1620',.7))
        torus((x,-.36,z),.4,.05,EMB(1.8) if hot else mat('#5E6B7D',.5,.4))
        a.disk((x,-.46,z),.26,.22,mat('#E9EDF4',.35,.15) if hot else mat('#8E9AAB',.4,.3))
        sphere((x,-.58,z),(.2,.08,.2),mat('#FFFFFF',.3) if hot else mat('#6A7686',.4,.3))

# ---------------------------------------------------------------- réticule
def crosshair():
    c=mat('#FFE9A8',.3,0,'#FFE9A8',1.2)
    torus((0,0,0),.62,.035,c,'Anneau')
    for t in range(4):
        a_=t*math.pi/2; dx,dz=math.sin(a_),math.cos(a_)
        bevelled_box((dx*.9,0,dz*.9),(.1 if dz==0 else .06,.06,.1 if dx==0 else .06) if False else ((.28,.06,.06) if dx else (.06,.06,.28)),c,.015,'Repere')
    sphere((0,0,0),(.045,.03,.045),c,'Point')

B=lambda f,*a_:(lambda:f(*a_))
ITEMS=[
 ('key_1x1',B(key,1.0),'icon',(64,64)),
 ('key_2x1',B(key,2.0),'fit',(128,64)),
 ('mouse_left',B(mouse,'left'),'icon',(64,64)),
 ('mouse_right',B(mouse,'right'),'icon',(64,64)),
 ('mouse_wheel',B(mouse,'wheel'),'icon',(64,64)),
 ('pad_a',B(pad_btn,'#5FA85B'),'icon',(64,64)),
 ('pad_b',B(pad_btn,'#D0402A'),'icon',(64,64)),
 ('pad_x',B(pad_btn,'#4F86D8'),'icon',(64,64)),
 ('pad_y',B(pad_btn,'#F2C14E'),'icon',(64,64)),
 ('pad_btn_bottom',B(pad_pos,'bottom'),'icon',(64,64)),
 ('pad_btn_right',B(pad_pos,'right'),'icon',(64,64)),
 ('pad_btn_left',B(pad_pos,'left'),'icon',(64,64)),
 ('pad_btn_top',B(pad_pos,'top'),'icon',(64,64)),
 ('pad_lt',B(pad_shoulder,'t','l'),'icon',(64,64)),
 ('pad_rt',B(pad_shoulder,'t','r'),'icon',(64,64)),
 ('pad_lb',B(pad_shoulder,'b','l'),'icon',(64,64)),
 ('pad_rb',B(pad_shoulder,'b','r'),'icon',(64,64)),
 ('pad_stick_left',B(pad_stick,'l'),'icon',(64,64)),
 ('pad_stick_right',B(pad_stick,'r'),'icon',(64,64)),
]

def main():
    only=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for n,fn,mode,(w,h) in ITEMS:
        if only and n not in only:continue
        new_scene(n,24); fn(); outline(meshes(),.02); frame_object_ortho(meshes(),.05)
        raw=RAW/f'{n}.png'; render_to(raw)
        if mode=='icon':post(dict(mode='icon',src=str(raw),dst=str(OUT/f'{n}.png'),size=w,margin=3))
        else:post(dict(mode='fit',src=str(raw),dst=str(OUT/f'{n}.png'),w=w,h=h,margin=3))
        print('UI_OK',n,flush=True)
    if not only or 'crosshair' in only:
        new_scene('crosshair',24); crosshair(); outline(meshes(),.018); front_camera(2.0,2.0,512,512,0)
        raw=RAW/'crosshair.png'; render_to(raw); post(dict(mode='resize',src=str(raw),dst=str(UI/'crosshair.png'),w=96,h=96)); print('UI_OK crosshair',flush=True)
    flush_post(); save_blend('prompts.blend' if not only else 'prompts_part.blend')
if __name__=='__main__':main()
