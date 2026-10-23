"""UI 2/2 : joystick, cadres de sorts, bouton Interagir, jauge de difficulté, boutons de menu 9-slice. Blender background.
-- joystick | spell | interact | difficulty | menu pour un sous-ensemble."""
import sys, math, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_kit import *
UI=ROOT/'game/assets/sprites/ui'
RAW=ROOT/'art/renders/ui/ui'
def circ(d,n=12):return rrect(d,d,d/2,n)
def emi(h,s=1.0):return mat(h,.3,0,h,s)

# ---------------------------------------------------------------- joystick
def joystick_base():
    stone=mat('#4A5565',.75,.1); dark=mat('#232A36',.8)
    trans=mat('#1E2530',.7); trans.surface_render_method='BLENDED'
    trans.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.62
    ring(circ(2.3),circ(1.7),stone,.28,0,.05,'Anneau pierre')
    ring(circ(1.78),circ(1.62),dark,.2,-.06,.02,'Levre')
    ring(circ(1.5),circ(1.44),emi('#FF7A1F',1.1),.06,-.1,.01,'Lisere braise')
    slab(circ(1.66),trans,.08,.08,0,'Fond translucide')
    for i in range(4):
        t=i*math.pi/2
        o=bevelled_box((1.0*math.sin(t),-.12,1.0*math.cos(t)),(.12,.06,.22),emi('#FFB347',.9),.015); o.rotation_euler[1]=t
    for i in range(12):
        t=i*math.tau/12+math.pi/12
        sphere((2.0/2*1.0*math.sin(t)*1.0*.98+0,-.15,1.0*1.0*math.cos(t)*0+ (2.0/2)*math.cos(t)*.98),(.05,.04,.05),a.steel) if False else None
        sphere((1.0*1.0*math.sin(t)*1.0*1.0*1.0*0+1.0*math.sin(t)*1.0,0,0),(.0001,.0001,.0001),a.steel) if False else None
    for i in range(12):
        t=i*math.tau/12+math.pi/12
        sphere((.98*1.0*math.sin(t)*1.0*1.0*1.0+0*t,-.17,.98*math.cos(t)*1.0),(.001,.001,.001),a.steel) if False else None
    for i in range(12):
        t=i*math.tau/12+math.pi/12
        sphere((1.0*math.sin(t)*1.0*1.0+.0,-.17,1.0*math.cos(t)),(.001,.001,.001),a.steel) if False else None
    for i in range(12):
        t=i*math.tau/12+math.pi/12
        sphere((1.03*math.sin(t)*1.0 if False else 0.0,0,0),(.0001,.0001,.0001),a.steel) if False else None

def joystick_knob():
    cu=mat('#B8662E',.22,.85)
    sphere((0,0,0),(.9,.9,.9),cu)
    sphere((-.28,-.55,.33),(.26,.12,.2),mat('#FFD9A8',.2,0,'#FFD9A8',.5))
    t=torus((0,-.3,0),.62,.07,emi('#FF7A1F',1.6)); t.rotation_euler=(math.pi/2+.0,0,0)
    sphere((0,-.75,0),(.2,.1,.2),emi('#FFE9A8',2.0))

def make_joystick():
    new_scene('joystick_base'); joystick_base(); outline(meshes()); front_camera(2.46,2.46,512,512,20)
    raw=RAW/'joystick_base.png'; render_to(raw); post(dict(mode='resize',src=str(raw),dst=str(UI/'joystick/joystick_base.png'),w=256,h=256))
    new_scene('joystick_knob'); joystick_knob(); outline(meshes()); front_camera(2.0,2.0,512,512,0)
    raw=RAW/'joystick_knob.png'; render_to(raw); post(dict(mode='fit',src=str(raw),dst=str(UI/'joystick/joystick_knob.png'),w=128,h=128,margin=4))
    print('UI_OK joystick',flush=True)

# ---------------------------------------------------------------- cadres de sorts
STATES={
 'normal':dict(body='#3A4458',rim='#FF7A1F',rim_s=1.4,bolt='#8E9AAB',depth=.34,y=0),
 'pressed':dict(body='#222A38',rim='#FFB347',rim_s=2.4,bolt='#5E6B7D',depth=.2,y=.08),
 'cooldown':dict(body='#2E343E',rim='#4A5565',rim_s=.1,bolt='#555D69',depth=.34,y=0),
}
def spell_frame(st):
    d=STATES[st]; body=mat(d['body'],.5,.5);
    y=d['y']
    ring(circ(2.3),circ(1.6),body,d['depth'],y,.05,'Anneau')
    ring(circ(1.72),circ(1.58),mat('#161B24',.7),.2,y-.08,.02,'Creux')
    ring(circ(1.62),circ(1.54),emi(d['rim'],d['rim_s']) if d['rim_s']>.2 else mat(d['rim'],.6),.08,y-.12,.01,'Lisere')
    for i in range(8):
        t=i*math.tau/8+math.pi/8
        sphere((1.0*1.0*1.0*1.0*.0+1.0*math.sin(t)*1.0+0,0,0),(.0001,.0001,.0001),body) if False else None
        sphere((1.0*0+ (1.0)*math.sin(t)*1.0*1.0*1.0+0,0,0),(.0001,.0001,.0001),body) if False else None
    for i in range(8):
        t=i*math.tau/8+math.pi/8; r=1.43
        sphere((r*math.sin(t),y-.19,r*math.cos(t)),(.075,.05,.075),mat(d['bolt'],.35,.7))
    for i in range(4):
        t=i*math.pi/2
        o=bevelled_box((1.43*math.sin(t)*0+ (1.16*math.sin(t)),y-.13,1.16*math.cos(t)),(.1,.06,.2),emi(d['rim'],d['rim_s']) if d['rim_s']>.2 else mat(d['rim'],.6),.01); o.rotation_euler[1]=t

def make_spell():
    for st,name in [('normal','spell_frame'),('pressed','spell_frame_pressed'),('cooldown','spell_frame_cooldown')]:
        new_scene(name); spell_frame(st); outline(meshes()); front_camera(2.44,2.44,320,320,0)
        raw=RAW/f'{name}.png'; render_to(raw); post(dict(mode='resize',src=str(raw),dst=str(UI/f'{name}.png'),w=160,h=160))
    new_scene('spell_cooldown_ring'); ring(circ(2.3),circ(1.86),emi('#FFE9A8',1.2),.12,0,.02,'AnneauRecharge'); outline(meshes(),.012); front_camera(2.44,2.44,320,320,0)
    raw=RAW/'spell_cooldown_ring.png'; render_to(raw); post(dict(mode='resize',src=str(raw),dst=str(UI/'spell_cooldown_ring.png'),w=160,h=160))
    print('UI_OK spell',flush=True)

# ---------------------------------------------------------------- bouton Interagir
IST={
 'normal':dict(ring='#3A4458',face='#C2501A',fe='#FF7A1F',fs=.7,f1='#FFE9A8',f2='#FFB347',fs2=1.4,depth=.3,y=0,scale=1.0,rim='#FF7A1F',rs=1.4),
 'pressed':dict(ring='#222A38',face='#8A3410',fe='#C23B12',fs=.3,f1='#E8C690',f2='#E08A30',fs2=.8,depth=.16,y=.1,scale=.9,rim='#FFB347',rs=2.0),
 'disabled':dict(ring='#2E343E',face='#4A5160',fe='#4A5160',fs=0,f1='#7C8898',f2='#6A7686',fs2=0,depth=.3,y=0,scale=1.0,rim='#4A5565',rs=0),
}
def interact(st):
    d=IST[st]; y=d['y']
    ring(circ(2.3),circ(1.7),mat(d['ring'],.5,.5),d['depth'],y,.05,'Anneau')
    if d['rs']>0:ring(circ(1.76),circ(1.66),emi(d['rim'],d['rs']),.08,y-.12,.01,'Lisere')
    else:ring(circ(1.76),circ(1.66),mat(d['rim'],.6),.08,y-.12,.01,'Lisere')
    face=mat(d['face'],.35,.15,d['fe'],d['fs']) if d['fs']>0 else mat(d['face'],.6,.1)
    slab(circ(1.66),face,.16,y+.05,.04,'Face')
    k=d['scale']
    f1=mat(d['f1'],.35,0,d['f1'],d['fs2']) if d['fs2']>0 else mat(d['f1'],.6)
    f2=mat(d['f2'],.35,0,d['f2'],d['fs2']) if d['fs2']>0 else mat(d['f2'],.6)
    def fl(x,z,r,h,m,bend,yy):
        o=lathe([(0,-h*.5),(r*.65,-h*.42),(r,-h*.2),(r*.82,h*.03),(r*.38,h*.25),(0,h*.5)],(x*k,yy,z*k),m,24,'Flamme')
        for v in o.data.vertices:
            t=max(0,(v.co.z/h+.1)); v.co.x+=bend*t*t
        o.scale=(k,.28*k,k); return o
    fl(0,.08,.42,1.15,f2,.3,y-.17); fl(-.3,-.1,.22,.7,f2,-.2,y-.17); fl(.3,-.12,.2,.6,f2,.2,y-.17)
    fl(0,-.08,.2,.6,f1,.1,y-.25)
    for i in range(4):
        t=i*math.pi/2+math.pi/4
        sphere((1.35*math.sin(t),y-.1,1.35*math.cos(t)),(.06,.05,.06),mat(d['ring'],.4,.7) if st!='normal' else a.gold)

def make_interact():
    for st in IST:
        n=f'interact_{st}'; new_scene(n); interact(st); outline(meshes()); front_camera(2.44,2.44,400,400,0)
        raw=RAW/f'{n}.png'; render_to(raw); post(dict(mode='resize',src=str(raw),dst=str(UI/'interact'/f'{n}.png'),w=200,h=200))
    print('UI_OK interact',flush=True)

# ---------------------------------------------------------------- jauge de difficulté
LEVELS={1:('calme','#7C98B8','#B8D4F0'),2:('tension','#F2C14E','#FFE9A8'),3:('alerte','#FF8A2A','#FFC070'),4:('fournaise','#D02A1E','#FF7A5A'),5:('cataclysme','#3A1A5A','#FF7A1F')}
NAMES={1:'calme',2:'tension',3:'alerte',4:'fournaise',5:'cataclysme'}
def gauge(level):
    nm,col,hi=LEVELS[level]
    W,H=4.9,1.7
    plate=mat('#2B3340',.5,.5)
    slab(rrect(W,H,.3,6),plate,.3,0,.05)
    rr_ring(W,H,.3,.14,mat('#5E7390',.35,.6),.34,0,.04,6)
    rr_ring(W-.36,H-.36,.2,.05,emi('#FF7A1F',.7+.15*level),.1,-.2,.01,6)
    for sx in (-1,1):sphere((sx*(W/2-.1),-.2,0),(.07,.05,.07),a.gold)
    xs=[-1.8+.9*i for i in range(5)]
    for i,x in enumerate(xs):
        lit=i<level
        rr=rrect(.78,1.0,.2,4)
        sock=slab(rr,mat('#14181F',.8),.14,-.12,.02,'Alveole'); sock.location.x=x
        if lit:
            if level==5:
                gm=mat('#2A1440',.15,.2,'#7A2AB8',.9); core=emi('#FF7A1F',2.2)
            else:
                gm=mat(col,.15,.2,col,1.2); core=emi(hi,2.0)
            g=lathe([(0,-.5),(.3,-.2),(.34,.1),(.18,.4),(0,.46)],(x,-.3,0),gm,8,'Gemme'); g.scale=(1.0,.55,1.0)
            sphere((x,-.47,.05),(.1,.06,.12),core)
            if level>=3:
                c=cone((x,-.3,.62),.12+.02*level,.3+.06*level,emi(hi if level<5 else '#FF7A1F',1.6),5)
        else:
            lathe([(0,-.4),(.26,-.16),(.28,.08),(.14,.32),(0,.36)],(x,-.2,0),mat('#323A48',.5,.2),8,'Gemme eteinte').scale=(1,.4,1)

def make_difficulty():
    for lv in range(1,6):
        n=f'diff_{lv}_{NAMES[lv]}'; new_scene(n); gauge(lv); outline(meshes()); front_camera(5.0,1.9,768,288,0)
        raw=RAW/f'{n}.png'; render_to(raw); post(dict(mode='resize',src=str(raw),dst=str(UI/'difficulty'/f'{n}.png'),w=256,h=96))
    print('UI_OK difficulty',flush=True)

# ---------------------------------------------------------------- boutons de menu
def button(w,h,variant):
    S={'normal':('#4A5565','#232A36','#FF7A1F',1.0,.26,0),'pressed':('#2E3745','#161B24','#FFB347',1.7,.14,.06),'primary':('#7A3B24','#2A140C','#FFB347',1.5,.28,0)}[variant]
    base,dark,emc,ems,depth,y=S
    slab(rrect(w,h,.1,3),mat(base,.75,.12),depth,y,.04,'Plaque')
    rr_ring(w,h,.1,.1,mat(dark if variant!='primary' else '#A8541E',.45,.4),depth+.04,y,.04,3)
    rr_ring(w-.2,h-.2,.06,.035,emi(emc,ems),.07,y-.14,.01,3)
    for sx in (-1,1):
        for sz in (-1,1):
            sphere((sx*(w/2-.12),y-.15,sz*(h/2-.12)),(.05,.04,.05),a.gold if variant!='pressed' else mat('#8A7030',.5,.6))

def make_menu():
    for n,(w,h,v) in {'button_normal':(1.92,.96,'normal'),'button_pressed':(1.92,.96,'pressed'),'button_primary':(2.56,1.12,'primary')}.items():
        new_scene(n); button(w-.04,h-.04,v); outline(meshes()); front_camera(w,h,int(w*200),int(h*200),0)
        raw=RAW/f'{n}.png'; render_to(raw); post(dict(mode='resize',src=str(raw),dst=str(UI/'menu'/f'{n}.png'),w=int(w*100),h=int(h*100)))
    (UI/'menu').mkdir(parents=True,exist_ok=True)
    (UI/'menu'/'button_9slice.json').write_text(json.dumps({
        'description':'Marges 9-slice (px) : bords et centre unis, détails (rivets) dans les coins.',
        'button_normal':{'size':[192,96],'margin_left':24,'margin_top':24,'margin_right':24,'margin_bottom':24},
        'button_pressed':{'size':[192,96],'margin_left':24,'margin_top':24,'margin_right':24,'margin_bottom':24},
        'button_primary':{'size':[256,112],'margin_left':24,'margin_top':24,'margin_right':24,'margin_bottom':24}},indent=2,ensure_ascii=False),encoding='utf8')
    print('UI_OK menu',flush=True)

def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['joystick','spell','interact','difficulty','menu']
    for k,f in [('joystick',make_joystick),('spell',make_spell),('interact',make_interact),('difficulty',make_difficulty),('menu',make_menu)]:
        if k in args:f()
    flush_post(); save_blend('ui_elements2.blend' if len(args)==5 else 'ui_elements2_part.blend')
if __name__=='__main__':main()
