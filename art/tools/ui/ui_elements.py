"""UI 1/2 : cartes d'item, dé d100, icônes HUD. Blender background. -- cards | dice | hud pour un sous-ensemble."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_kit import *
UI=ROOT/'game/assets/sprites/ui'
RAW=ROOT/'art/renders/ui/ui'

# ---------------------------------------------------------------- cartes
def card_base(back=False):
    W,H=3.7,5.4
    stone=mat('#3E4A5C',.7,.1); edge=mat('#7C8898',.35,.6); dark=mat('#232A36',.7,.1); gold=a.gold
    ember=mat('#FF7A1F',.3,0,'#FF7A1F',1.6)
    slab(rrect(W,H,.07,3),stone,.14,.04,.02)
    rr_ring(W,H,.07,.22,edge,.24,0,.04,3)
    rr_ring(W-.46,H-.46,.04,.07,dark,.16,-.08,.02,3)
    rr_ring(W-.6,H-.6,.03,.035,ember if back else gold,.08,-.11,.01,3)
    for sx in (-1,1):
        for sz in (-1,1):
            sphere((sx*(W/2-.12),-.16,sz*(H/2-.12)),(.07,.05,.07),gold)
            sphere((sx*(W/2-.12),-.16,sz*(H/2-.12)),(.07,.05,.07),gold)
    return W,H,stone,dark,gold,ember

def card_front():
    W,H,stone,dark,gold,ember=card_base()
    # zone icône (haut) : creux sombre cerclé d'or
    slab(rrect(2.7,2.7,.1,3),dark,.1,-.1,.02)
    rr_ring(2.7,2.7,.1,.09,gold,.14,-.12,.02,3).location.z=1.25
    for o in list(bpy.context.scene.objects):pass
    # déplacer la zone icône vers le haut
    return W,H

def build_card_front():
    W,H,stone,dark,gold,ember=card_base()
    zi=1.2
    s=slab(rrect(2.7,2.7,.1,3),dark,.1,-.1,.02); s.location.z=zi
    r=rr_ring(2.7,2.7,.1,.1,gold,.14,-.12,.02,3); r.location.z=zi
    # bandeau de nom
    bevelled_box((0,-.12,-.5),(3.0,.12,.5),mat('#4A5565',.6,.2),.03)
    rr_ring(3.0,.5,.05,.04,gold,.1,-.18,.01,3).location.z=-.5
    # zone de texte
    s=slab(rrect(3.0,1.7,.05,3),mat('#2F3948',.8),.08,-.1,.015); s.location.z=-1.65
    r=rr_ring(3.0,1.7,.05,.06,mat('#5E7390',.5,.4),.1,-.12,.015,3); r.location.z=-1.65

def build_card_back():
    W,H,stone,dark,gold,ember=card_base(True)
    s=slab(rrect(3.0,4.7,.06,3),dark,.1,-.1,.02)
    # losange de braise et runes concentriques
    torus((0,-.2,0),1.15,.06,gold); torus((0,-.2,0),.85,.04,ember)
    d=poly_diamond(.8,gold,.12,-.2); d2=poly_diamond(.58,dark,.1,-.28); d3=poly_diamond(.38,ember,.1,-.34)
    sphere((0,-.42,0),(.15,.1,.15),mat('#FFE9A8',.3,0,'#FFE9A8',2.5))
    for i in range(8):
        t=i*math.tau/8+math.pi/8
        o=cone((1.45*math.sin(t),-.2,1.45*math.cos(t)),.09,.34,gold if i%2 else ember,4); toward(o,(math.sin(t),0,math.cos(t)))
    for sz in (-1,1):
        for k in range(3):
            bevelled_box((0,-.16,sz*(1.55+.25*k)),(.9-.28*k,.06,.06),gold if k==0 else ember,.01)
        d4=poly_diamond(.2,gold,.1,-.2); d4.location.z=sz*2.2
    for sx in (-1,1):
        for sz in (-1,1):
            d5=poly_diamond(.18,ember,.08,-.2); d5.location=(sx*1.2,0,sz*1.9)

def poly_diamond(r,m,depth,y):
    pts=[(0,r),(r*.75,0),(0,-r),(-r*.75,0)]
    n=4; vs=[(x,yy,z) for yy in [y-depth/2,y+depth/2] for x,z in pts]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    o=bpy.data.meshes.new('Losange'); o.from_pydata(vs,[],fs); o.update()
    ob=bpy.data.objects.new('Losange',o); bpy.context.collection.objects.link(ob); ob.data.materials.append(m)
    bm=ob.modifiers.new('Bev','BEVEL'); bm.width=.02; bm.segments=2
    return ob

def make_cards():
    for name,fn in [('card_front',build_card_front),('card_back',build_card_back)]:
        new_scene(name); fn(); outline(meshes()); front_camera(3.8,5.5,768,1120)
        raw=RAW/f'{name}.png'; render_to(raw)
        post(dict(mode='resize',src=str(raw),dst=str(UI/'cards'/f'{name}.png'),w=384,h=560)); print('UI_OK',name,flush=True)

# ---------------------------------------------------------------- dé d100
def dice_scene(col, ember_hex='#FF7A1F', name='de'):
    s=new_scene(name,samples=24)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1.0,location=(0,0,0)); die=bpy.context.object; die.name='D100'
    for p in die.data.polygons:p.use_smooth=False
    die.data.materials.append(mat(col,.28,.35,col,.12))
    wire=die.copy(); wire.data=die.data.copy(); bpy.context.collection.objects.link(wire); wire.name='Aretes braise'
    wire.data.materials.clear(); wire.data.materials.append(mat(ember_hex,.3,0,ember_hex,2.2))
    w=wire.modifiers.new('Fil','WIREFRAME'); w.thickness=.028; w.use_even_offset=True
    wire.scale=(1.005,1.005,1.005)
    for o in (die,wire):o.rotation_mode='AXIS_ANGLE'
    sh=die.copy(); sh.data=die.data.copy(); bpy.context.collection.objects.link(sh); sh.name='D100_contour'
    import bmesh
    bm=bmesh.new(); bm.from_mesh(sh.data); bmesh.ops.reverse_faces(bm,faces=list(bm.faces)); bm.to_mesh(sh.data); bm.free()
    dk=mat('#1a1620',1); dk.use_backface_culling=True; sh.data.materials.clear(); sh.data.materials.append(dk); sh.scale=(1.04,1.04,1.04)
    front_camera(2.4,2.4,256,256,12)
    return die,wire

def make_dice():
    die,wire=dice_scene('#5E7390')
    axis=Vector((.45,.8,.35)).normalized()
    for k in range(20):
        ang=math.tau*k/20
        for o in (die,wire):o.rotation_axis_angle=(ang,*axis)
        for o in bpy.context.scene.objects:
            if o.name.startswith('D100_contour'):
                o.rotation_mode='AXIS_ANGLE'; o.rotation_axis_angle=(ang,*axis)
        raw=RAW/f'd100_rot_{k:02d}.png'; render_to(raw)
        post(dict(mode='resize',src=str(raw),dst=str(UI/'dice'/f'd100_rot_{k:02d}.png'),w=128,h=128))
    print('UI_OK d100_rot',flush=True)
    tints={'commun':('#7C8898','#C8D4E4'),'peu_commun':('#5FA85B','#B6F07A'),'rare':('#8A5FD0','#C79BFF'),'legendaire':('#F2C14E','#FFE9A8')}
    for n,(col,em) in tints.items():
        die,wire=dice_scene(col,em,'face_'+n)
        for o in (die,wire):o.rotation_axis_angle=(.5,*axis)
        for o in bpy.context.scene.objects:
            if o.name.startswith('D100_contour'):o.rotation_mode='AXIS_ANGLE'; o.rotation_axis_angle=(.5,*axis)
        raw=RAW/f'd100_face_{n}.png'; render_to(raw)
        post(dict(mode='resize',src=str(raw),dst=str(UI/'dice'/f'd100_face_{n}.png'),w=128,h=128)); print('UI_OK face',n,flush=True)

# ---------------------------------------------------------------- HUD
def hud_gold():
    a.disk((0,0,0),.92,.26,a.gold); torus((0,-.15,0),.78,.07,mat('#A8741A',.35,.7))
    a.disk((0,-.15,0),.65,.05,mat('#E8B43A',.3,.7))
    poly=bevelled_box((0,-.2,0),(.5,.07,.5),mat('#FFE9A8',.3,.6),.03); poly.rotation_euler[1]=math.pi/4
    for i in range(16):
        t=i*math.tau/16; sphere((.87*math.sin(t),-.14,.87*math.cos(t)),(.035,.035,.035),mat('#A8741A',.4,.6))

def hud_ruby():
    red=mat('#D1243A',.15,.1,'#D1243A',.5)
    lathe([(0,-1.0),(.45,-.4),(.78,.1),(.62,.42),(0,.55)],(0,0,0),red,8,'Rubis')
    lathe([(0,.55),(.62,.42),(.5,.5)],(0,0,0),mat('#FF6B7A',.1,.1,'#FF6B7A',.6),8,'Table')
    crystal((-.2,-.5,.35),.1,.4,mat('#FFC2C8',.1,.1,'#FFC2C8',1.0)).rotation_euler[1]=.3

def hud_xp():
    cy=mat('#5FD4E8',.15,.2,'#5FD4E8',.7)
    o=crystal((0,0,0),.6,1.9,cy); o.rotation_euler[1]=.15
    crystal((-.1,-.45,.2),.1,.5,mat('#E6FBFF',.1,.1,'#E6FBFF',1.2))
    for x,z,s in [(-.7,-.55,.5),(.65,-.5,.42)]:
        q=crystal((x,.02,z),.22,s,mat('#2A8FB0',.2,.2,'#5FD4E8',.4)); q.rotation_euler[1]=x*.5

def hud_pause():
    a.disk((0,0,0),.95,.26,a.dark); torus((0,-.16,0),.9,.07,a.steel)
    for x in (-.28,.28):
        bevelled_box((x,-.3,0),(.3,.2,.85),mat('#E9EDF4',.35,.3),.07)
    torus((0,-.14,0),.76,.025,mat('#FF7A1F',.3,0,'#FF7A1F',1.5))

def hud_settings():
    st=mat('#8E9AAB',.35,.65); a.disk((0,0,0),.65,.3,st)
    for i in range(8):
        t=i*math.tau/8
        o=bevelled_box((.78*math.sin(t),0,.78*math.cos(t)),(.3,.3,.34),st,.04); o.rotation_euler[1]=t
    torus((0,-.17,0),.52,.05,mat('#C9D2DF',.3,.6))
    a.disk((0,-.12,0),.27,.34,a.dark)
    torus((0,-.28,0),.25,.04,mat('#FF7A1F',.3,0,'#FF7A1F',1.2))

def hud_hand():
    skin=mat('#D9A98A',.55,0); shade=mat('#B98468',.6,0)
    bevelled_box((0,0,-.3),(1.0,.34,.8),skin,.16)
    for x,h,z in [(-.36,.78,.45),(-.12,.9,.55),(.12,.96,.57),(.36,.76,.45)]:
        bevelled_box((x,-.02,z),(.21,.3,h),skin,.09)
    th=bevelled_box((-.62,-.02,-.12),(.26,.3,.72),skin,.1); th.rotation_euler[1]=-.9
    bevelled_box((0,-.19,-.55),(.98,.04,.12),mat('#7A3B24',.7),.02)
    for x in (-.24,0,.24):curve([(x,-.18,.0),(x,-.18,-.1)],.02,shade)
    for x,z in [(.85,.9),(-.9,.95),(.1,1.3)]:sphere((x,0,z),(.07,.07,.07),mat('#FF7A1F',.3,0,'#FFB347',2))

def make_hud():
    for n,fn in [('icon_gold',hud_gold),('icon_ruby',hud_ruby),('icon_xp',hud_xp),('icon_pause',hud_pause),('icon_settings',hud_settings),('icon_interact_hand',hud_hand)]:
        new_scene(n); fn(); outline(meshes()); frame_object_ortho(meshes())
        raw=RAW/f'{n}.png'; render_to(raw)
        post(dict(mode='icon',src=str(raw),dst=str(UI/'hud'/f'{n}.png'),size=128,margin=6)); print('UI_OK',n,flush=True)

def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['cards','dice','hud']
    if 'cards' in args:make_cards()
    if 'dice' in args:make_dice()
    if 'hud' in args:make_hud()
    flush_post(); save_blend('ui_elements.blend' if len(args)==3 else 'ui_elements_part.blend')
if __name__=='__main__':main()
