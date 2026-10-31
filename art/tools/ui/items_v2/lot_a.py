"""Pilot A: four worn, credible inventory objects."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from iv2_lib import *

def eclair_en_bouteille():
    wood=mat('#7A4E2E');edge=mat('#493020');grain=mat('#B78B59');iron=mat('#68685F');brass=mat('#D9C99E');black=mat('#171B1C');glow=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=1)
    # Continuous waist, flat soundboard, thick dark sides.
    pts=[(0,-1.42),(-.36,-1.38),(-.60,-1.16),(-.68,-.85),(-.59,-.52),(-.38,-.27),(-.39,-.06),(-.52,.18),(-.46,.43),(-.26,.59),(.24,.59),(.46,.44),(.51,.18),(.37,-.06),(.38,-.27),(.61,-.53),(.66,-.88),(.58,-1.18),(.33,-1.38)]
    pts=[(x*1.28,z) for x,z in pts]
    plate(pts,.34,edge,'Ukulele bent sides',bevel=.05)
    plate([(x*.96,z*.98) for x,z in pts],.035,wood,'Spruce soundboard',y=-.185,bevel=.02)
    bevelled_box((.02,-.03,.98),(.23,.20,1.15),edge,.025,'Neck heel')
    bevelled_box((.02,-.18,1.02),(.215,.05,1.15),wood,.012,'Fingerboard')
    plate([(-.14,1.48),(-.19,1.98),(-.11,2.12),(.15,2.10),(.21,1.96),(.15,1.48)],.16,wood,'Headstock',y=-.045)
    disk(0,-.13,.225,brass,y=-.222);disk(0,-.13,.185,black,y=-.25)
    bevelled_box((0,-.255,-.89),(.48,.075,.12),edge,.015,'Bridge')
    for z in [.52,.68,.84,1.,1.16,1.31,1.43]:line([(-.09,z),(.12,z)],iron,.009,y=-.224,name='Frets')
    for x in [-.078,-.026,.026,.078]:line([(x,-.89),(x,1.88)],brass,.011,y=-.30,name='Four strings')
    for x in [-.24,.25]:
        for z in [1.69,1.94]:
            line([(x*.5,z),(x,z)],iron,.022,y=-.07,name='Tuning shaft')
            bevelled_box((x,-.075,z),(.105,.085,.08),brass,.014,'Tuning key')
    for x,z in [(-.48,-1.02),(.42,-.70),(-.32,.30)]:line([(x,z-.16),(x+.04,z),(x+.02,z+.13)],grain,.009,y=-.212,name='Worn grain')
    line([(-.16,-1.24),(-.07,-1.02),(-.13,-.78),(-.02,-.61)],glow,.030,y=-.226,name='Electric wood split')
    line([(-.07,-1.02),(.12,-.95),(.20,-.84)],glow,.021,y=-.226)
    line([(-.37,.47),(.12,.30),(-.12,.08),(.35,-.17)],glow,.038,y=-.34,name='Short lightning across strings')

def de_pipe():
    dark=mat('#294A35');mid=mat('#46664A');light=mat('#647B53');vein=mat('#8D9564');gold=mat('#F2C14E',emit_hex='#F2C14E',emit_strength=.85)
    line([(0,.02),(-.12,-.61),(-.40,-1.15)],mid,.055,y=.025,name='Short bent stem')
    # Five separate heart blades: central cleft, pointed root, faceted ridge.
    shape=[(0,0),(-.29,.30),(-.42,.60),(-.39,.82),(-.23,.95),(-.08,.93),(0,.79),(.10,.94),(.26,.96),(.40,.83),(.42,.62),(.29,.30)]
    for i in range(5):
        a=math.radians(i*72+3);co,si=math.cos(a),math.sin(a)
        def pos(x,z):return (x*co-z*si,z*co+x*si+.16)
        poly=[pos(x,z+.08) for x,z in shape]
        plate(poly,.075,dark,'Heart leaf %d'%(i+1),y=.02+i*.006,bevel=.018)
        plate([pos(x*.82,z*.85+.14) for x,z in shape],.018,mid,'Leaf face',y=-.033,bevel=.009)
        plate([pos(0,.17),pos(-.27,.64),pos(-.22,.87),pos(-.05,.83),pos(0,.67)],.01,light,'Leaf angular plane',y=-.049,bevel=0)
        line([pos(0,.18),pos(0,.68)],vein,.013,y=-.068,name='Midrib')
        for z in [.36,.52]:
            for side in [-1,1]:line([pos(0,z),pos(side*.20,z+.18)],vein,.008,y=-.069,name='Lateral veins')
    line([(0,.34),(-.015,.58),(-.03,.77)],gold,.012,y=-.087,name='Golden vein')
    sphere((-.14,-.11,.76),(.043,.031,.052),gold,'Single gold dew')

def moisson():
    wood=mat('#A17C50');worn=mat('#C5A16D');steel=mat('#A8B5B8');edge=mat('#DEE7E5');black=mat('#292C2B');rust=mat('#6B3A22');red=mat('#EF6039',emit_hex='#FF633B',emit_strength=1)
    line([(.46,-1.75),(.33,-1.05),(.24,-.32),(.36,.48),(.27,1.27),(.15,1.72)],wood,.088,y=.035,name='Long curved ash snath')
    line([(.43,-1.59),(.29,-.78),(.28,-.35)],worn,.012,y=-.032,name='Shaft worn edge')
    for x,z in [(.29,-.63),(.33,.46)]:
        line([(x,z),(x+.32,z+.03),(x+.39,z+.20)],black,.037,y=-.04,name='Grip iron socket')
        line([(x+.39,z+.17),(x+.41,z+.43)],wood,.062,y=-.04,name='Side handgrip')
    blade=[(.22,1.67),(-.12,1.85),(-.62,1.89),(-1.10,1.73),(-1.49,1.43),(-1.76,1.07),(-1.90,.64),(-1.61,1.02),(-1.26,1.28),(-.88,1.40),(-.81,1.36),(-.75,1.43),(-.36,1.46),(.20,1.39)]
    blade=[(x,z+max(0,z-1.45)*.55) for x,z in blade]
    plate(blade,.07,steel,'Forged sweeping blade',y=-.035,bevel=.016)
    line([(-1.87,.67),(-1.59,1.05),(-1.25,1.31),(-.90,1.43),(-.81,1.39),(-.75,1.46),(-.36,1.49),(.13,1.43)],edge,.017,y=-.083,name='Chipped honed bevel')
    line([(-.11,1.72),(-.60,1.77),(-1.02,1.64),(-1.39,1.37)],black,.020,y=-.083,name='Blade fuller')
    line([(-1.73,.86),(-1.58,1.06),(-1.35,1.24),(-1.20,1.31),(-.91,1.42)],red,.030,y=-.113,name='Ember on cutting edge')
    for z in [1.39,1.58]:
        bevelled_box((.18,-.01,z),(.28,.24,.12),black,.018,'Mounting collar');disk(.18,z,.033,rust,y=-.15)
    for x,z in [(-.51,1.67),(-.68,1.62)]:disk(x,z,.024,rust,y=-.09,depth=.012)

def lentille_aiguisee():
    iron=mat('#343B39');bronze=mat('#697B68');brass=mat('#A8946E');leather=mat('#49362E');wear=mat('#80644D');glass=mat('#506E73');facet=mat('#769194');dark=mat('#273E43');glow=mat('#8A6AB0',emit_hex='#8A6AB0',emit_strength=.9)
    cx,cz=-.20,.48
    line([(.27,-.12),(1.05,-1.27)],iron,.105,y=.02,name='Tang')
    line([(.46,-.40),(1.03,-1.24)],leather,.125,y=-.01,name='Leather grip')
    for i in range(6):
        t=i/6;x=.46+.54*t;z=-.40-.80*t
        line([(x-.076,z-.055),(x+.077,z+.055)],wear,.018,y=-.13,name='Grip binding')
    disk(1.06,-1.30,.135,bronze,y=-.025,depth=.17)
    disk(cx,cz,.76,iron,y=.015,depth=.17)
    disk(cx,cz,.676,glass,y=-.092,depth=.045)
    plate([(-.78,.78),(-.46,1.04),(.15,.99),(.40,.68),(-.05,.64)],.012,facet,'Smoky glass plane',y=-.127,bevel=0)
    plate([(-.76,.23),(-.33,-.12),(.20,.02),(.41,.35),(-.05,.22)],.012,dark,'Lower glass plane',y=-.129,bevel=0)
    torus((cx,-.145,cz),.727,.051,bronze,'Patinated retaining ring')
    torus((cx,-.16,cz),.664,.014,brass,'Thin worn inner lip')
    for a in [35,145,245]:
        t=math.radians(a);x=cx+.73*math.cos(t);z=cz+.73*math.sin(t)
        disk(x,z,.043,brass,y=-.20,depth=.03);line([(x-.022,z),(x+.022,z)],iron,.008,y=-.222,name='Screw slot')
    line([(-.72,.80),(-.41,.65),(-.35,.35),(-.04,.20)],dark,.012,y=-.155,name='Old fracture')
    line([(-.41,.65),(-.19,.80),(.10,.78)],dark,.009,y=-.155)
    line([(-.35,.35),(-.13,.29),(-.04,.20)],glow,.013,y=-.174,name='Arcane fracture accent')
    for x,z in [(-.64,.98),(.24,.87),(-.60,.02)]:line([(x-.04,z-.02),(x+.035,z+.025)],brass,.015,y=-.205,name='Rim wear')

def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    if set(chosen)-set(IDS):raise ValueError('Unknown item')
    scenes=[]
    for ident in chosen:
        scenes.append(reset(ident));globals()[ident]();deliver(ident)
    for s in list(bpy.data.scenes):
        if s not in scenes:bpy.data.scenes.remove(s)
    out=ROOT/'art/blender/items_v2/lot_a.blend';out.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.scene.render.use_file_extension=True
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    print('PASS lot_a '+str(len(chosen))+' icons',flush=True)
if __name__=='__main__':main()


