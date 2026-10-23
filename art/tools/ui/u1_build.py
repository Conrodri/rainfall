"""U1: face-on forged iron / patinated bronze UI. Background Blender only.
Geometry and studio rig reuse ui_kit; worn shaders follow ash_lord_build.
All dimensions are pixels in an orthographic XZ modelling plane.
"""
import sys, math, json, random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_kit import *
D=ROOT/'game/assets/sprites/ui/da'; D.mkdir(parents=True,exist_ok=True)
T=ROOT/'art/tools/ui'; ROWS=[]; random.seed(21026)

def worn(name,lo,hi,metal=.6,rough=.55):
    m=mat(lo,rough,metal);m.name=name;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=22;noise.inputs['Detail'].default_value=3
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=rgba(lo);ramp.color_ramp.elements[1].color=rgba(hi)
    l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
    fine=n.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=135
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.28;bump.inputs['Distance'].default_value=.55
    l.new(fine.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
    return m

def poly(points,m,y=-3,depth=2,bevel=.6):return slab(points,m,depth,y,bevel)
def rect(w,h,m,y=0,c=5,depth=2):return slab(rrect(w,h,c,1),m,depth,y,.6)
def frame(w,h,b,m,y=-3,c=6):return rr_ring(w,h,c,b,m,2,y,.5,1)
def line(points,m,r=.7,y=-7):return curve([(x,y,z) for x,z in points],r,m,'engraved inlay')
def disk(x,z,r,m,y=-7):return flat_disk((x,y,z),r,1.6,m)
def diamond(x,z,r,m,y=-8):return poly([(x,z+r),(x-r*.64,z),(x,z-r),(x+r*.64,z)],m,y)

def begin(name,w,h):
    s=bpy.data.scenes.new('U1 '+name);bpy.context.window.scene=s;setup_render()
    s.eevee.taa_render_samples=16;s.render.resolution_percentage=100
    front_camera(w,h,w*2,h*2);s.camera.location=(0,-1500,0);aim(s.camera,(0,0,0));s.camera.data.clip_end=3000
    s.world.node_tree.nodes['Background'].inputs[1].default_value=.18
    for o in s.objects:
        if o.type=='LIGHT':
            o.data.energy=2.5 if 'chaud' in o.name else .65;o.data.angle=.15
    global iron,bronze,edge,leather,ember,blue,blood
    iron=worn('Blackened forged iron','#141719','#454844')
    bronze=worn('Patinated bronze verdigris','#33483F','#8DBBA8')
    edge=worn('Worn brass rivets','#65533A','#C0A77A',.65,.48)
    leather=worn('Dark soaked leather','#0C1012','#232926',0,.9)
    ember=mat('#9E3512',.45,.2,'#FF6D1C',1.4);ember.name='Ember emission'
    blue=mat('#174856',.35,.25,'#60BED8',.95);blue.name='Cold rune emission'
    blood=mat('#500B0F',.4,.15,'#BD1D27',.8);blood.name='Blood emission'
    return s

def corners(w,h,inset=13):
    for sx in [-1,1]:
        for sz in [-1,1]:
            x=sx*(w/2-inset);z=sz*(h/2-inset)
            disk(x,z,2.4,edge);line([(x-1,z),(x+1,z)],iron,.4,y=-9)
            line([(x-sx*6,z+sz*3),(x-sx*11,z+sz*3),(x-sx*15,z-sz*1)],bronze,.65)

def panel(w,h,accent=None,pressed=False,disabled=False,hollow=False):
    w-=6;h-=6
    if not hollow:rect(w-4,h-4,leather,2,c=9)
    frame(w,h,6,iron,c=10);frame(w-8,h-8,2.2,bronze,-5,c=7)
    frame(w-17,h-17,.9,edge,-6,c=5)
    if w>150 and h>65:corners(w,h)
    if accent:
        frame(w-24,h-24,1.5 if not pressed else 2.5,accent,-7,c=4)
        for sx in [-1,1]:diamond(sx*(w/2-19),0,5,accent)
    if pressed:frame(w-30,h-30,2,iron,-9,c=3)

def gear():
    pts=[]
    for i in range(48):
        a=i*math.tau/48;r=35 if i%4 in (1,2) else 29
        pts.append((r*math.sin(a),r*math.cos(a)))
    poly(pts,iron);ring(rrect(30,30,15,8),rrect(18,18,9,8),bronze,3,-7,.7)
    for a in range(0,360,60):
        t=math.radians(a);disk(24*math.cos(t),24*math.sin(t),2,edge)

def gauntlet():
    # Articulated steel palm, four separated fingers, thumb and leather cuff.
    poly([(-19,-18),(-18,9),(-11,18),(15,15),(22,0),(14,-22)],iron,-1,5,1)
    poly([(-17,-19),(-14,5),(11,11),(18,-1),(11,-20)],bronze,-6,2,1)
    for i,(x,top) in enumerate([(-15,30),(-5,36),(5,35),(15,28)]):
        poly([(x-3,7),(x-4,top-4),(x-2,top),(x+3,top-1),(x+4,8)],iron,-4,4,.8)
        for z in [14,22,top-3]:line([(x-2,z),(x+2,z+1)],edge,.65,y=-8)
    poly([(-17,3),(-29,13),(-33,9),(-30,0),(-20,-11)],iron,-3,4,1)
    poly([(-21,-22),(16,-24),(20,-35),(-24,-34)],leather,0,4)
    line([(-23,-27),(18,-29)],edge,1,y=-6)
    for x in [-12,0,12]:disk(x,-27,1.8,edge)

def icon(kind,size):
    if kind in ['gold','level_badge']:
        r=size*.42;disk(0,0,r,iron,-1);disk(0,0,r-3,bronze,-4)
        torus((0,-7,0),r-6,1,edge)
        for i in range(12):
            a=i*math.tau/12;line([((r-8)*math.cos(a),(r-8)*math.sin(a)),((r-11)*math.cos(a),(r-11)*math.sin(a))],edge,.7)
        if kind=='gold':
            diamond(0,0,14,edge);line([(-7,-9),(0,10),(7,-9)],iron,1.5,y=-11)
    elif kind in ['xp','ruby']:
        m=blue if kind=='xp' else blood
        poly([(0,26),(-19,8),(-14,-16),(0,-26),(18,-10),(21,10)],iron,-1,4)
        for pts in [[(0,22),(-15,7),(0,2)],[(0,22),(0,2),(17,9)],[(0,2),(-15,7),(-11,-13),(0,-22)],[(0,2),(0,-22),(14,-9),(17,9)]]:poly(pts,m,-6,2,.25)
        line([(0,22),(0,2),(-11,-13)],edge,.5,y=-9)
    elif kind=='pause':
        panel(size-6,size-6)
        for x in [-10,10]:
            o=rect(9,35,bronze,-8,c=1);o.location.x=x
            line([(x-2,-14),(x-2,14)],edge,1,y=-11)
    elif kind=='settings':gear()
    elif kind=='interact':gauntlet()

def mini(kind):
    # Distinct symbols built in 3D at final mobile size.
    if kind.startswith('chest'):
        m=edge if kind!='chest_legendary' else ember
        rect(23,16,iron,0,c=2);rect(23,6,bronze,-4,c=2).location.z=5
        for x in [-8,8]:
            o=rect(2,15,m,-6,c=.3);o.location.x=x
        rect(4,5,m,-8,c=.4)
        if kind!='chest':line([(-8,11),(0,14),(8,11)],m,.9)
        if kind=='chest_legendary':diamond(0,10,3,ember)
    elif kind=='pillar':
        rect(10,20,bronze);rect(18,4,edge,-4,c=1).location.z=-10
        rect(16,4,edge,-4,c=1).location.z=10;line([(0,-6),(0,6)],blue,1)
    elif kind=='teleporter':
        torus((0,-3,0),10,2,bronze);torus((0,-6,0),7,1,blue)
        for x in [-11,11]:diamond(x,0,3,edge)
    elif kind=='boss':
        poly([(-7,9),(-12,14),(-13,3),(-9,-6),(-4,-9),(4,-9),(9,-6),(13,3),(12,14),(7,9)],iron)
        poly([(-7,7),(7,7),(6,-5),(0,-10),(-6,-5)],bronze,-6)
        for x in [-4,4]:diamond(x,1,2,blood)
    elif kind=='capsule':
        rect(14,25,iron,c=5);rect(8,16,blue,-5,c=2)
        for z in [-10,10]:rect(16,3,edge,-7,c=.5).location.z=z
    elif kind=='player':poly([(0,13),(-10,-10),(0,-5),(10,-10)],ember,-3)

def fill(w,h,m):
    p=m.node_tree.nodes.get('Principled BSDF');n=m.node_tree.nodes;l=m.node_tree.links
    tc=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');l.new(tc.outputs['Generated'],sep.inputs[0])
    ramp=n.new('ShaderNodeValToRGB');base=tuple(p.inputs['Base Color'].default_value)
    col=tuple(p.inputs['Emission Color'].default_value) if p.inputs['Emission Strength'].default_value else base
    ramp.color_ramp.elements[0].color=tuple(v*.22 for v in col[:3])+(1,)
    ramp.color_ramp.elements[1].color=col;l.new(sep.outputs['Z'],ramp.inputs[0])
    l.new(ramp.outputs[0],p.inputs['Base Color']);l.new(ramp.outputs[0],p.inputs['Emission Color'])
    rect(w-4,h-4,m,-1,c=2)
    # Separate raised translucent-looking glass strip catches the studio key.
    line([(-w/2+5,h*.27),(w/2-5,h*.27)],m,.65,y=-4)
    for sx in [-1,1]:line([(sx*(w/2-6),-h*.2),(sx*(w/2-6),h*.2)],edge,.6,y=-5)

def vignette():
    m=bpy.data.materials.new('Blood vignette transparent falloff');m.use_nodes=True
    n=m.node_tree.nodes;l=m.node_tree.links;n.clear();out=n.new('ShaderNodeOutputMaterial')
    tc=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');l.new(tc.outputs['Generated'],sep.inputs[0])
    vals=[]
    for ax in ['X','Z']:
        sub=n.new('ShaderNodeMath');sub.operation='SUBTRACT';sub.inputs[1].default_value=.5;l.new(sep.outputs[ax],sub.inputs[0])
        ab=n.new('ShaderNodeMath');ab.operation='ABSOLUTE';l.new(sub.outputs[0],ab.inputs[0]);vals.append(ab)
    mx=n.new('ShaderNodeMath');mx.operation='MAXIMUM'
    for i,v in enumerate(vals):l.new(v.outputs[0],mx.inputs[i])
    remap=n.new('ShaderNodeMapRange');remap.clamp=True;remap.interpolation_type='SMOOTHERSTEP'
    remap.inputs['From Min'].default_value=.27;remap.inputs['From Max'].default_value=.5;remap.inputs['To Max'].default_value=.85
    l.new(mx.outputs[0],remap.inputs['Value'])
    tr=n.new('ShaderNodeBsdfTransparent');em=n.new('ShaderNodeEmission');em.inputs[0].default_value=rgba('#8C0A12')
    mix=n.new('ShaderNodeMixShader');l.new(remap.outputs[0],mix.inputs[0]);l.new(tr.outputs[0],mix.inputs[1]);l.new(em.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs[0])
    rect(1024,1024,m,0,c=0,depth=.2)

def emit_pass(s,path):
    saved=[]
    for m in {slot.material for o in s.objects if o.type=='MESH' or o.type=='CURVE' for slot in o.material_slots if slot.material}:
        p=m.node_tree.nodes.get('Principled BSDF')
        if not p:continue
        out=m.node_tree.nodes.get('Material Output');sock=out.inputs['Surface'];link=sock.links[0];saved.append((m,sock,link.from_socket))
        em=m.node_tree.nodes.new('ShaderNodeEmission');em.inputs[0].default_value=p.inputs['Emission Color'].default_value;em.inputs[1].default_value=p.inputs['Emission Strength'].default_value
        if p.inputs['Emission Color'].is_linked:m.node_tree.links.new(p.inputs['Emission Color'].links[0].from_socket,em.inputs[0])
        m.node_tree.links.new(em.outputs[0],sock)
    render_to(path)
    for m,sock,orig in saved:m.node_tree.links.new(orig,sock)

def make(name,w,h,build,margins=None,emission=False):
    s=begin(name,w,h);build();render_to(D/(name+'.png'))
    if emission:emit_pass(s,D/(name+'_e.png'))
    row=dict(name=name,size=[w,h],frames=1,passes=['diffuse']+(['emission'] if emission else []),normal='none: face-on UI',emission=bool(emission))
    if margins:
        row['nine_slice']=dict(left=margins[0],top=margins[1],right=margins[2],bottom=margins[3]);row['content_insets']=row['nine_slice']
        (D/(name+'.json')).write_text(json.dumps(row,indent=2))
    ROWS.append(row)

if __name__=='__main__':
    for name,w,h,m in [('panel_9slice',384,384,28),('panel_small_9slice',192,192,24),('header_banner',640,96,24),('timer_plate',256,80,22),('keycap_9slice',64,64,14)]:
        make(name,w,h,lambda w=w,h=h:panel(w,h),[m]*4 if name!='header_banner' else [28,20,28,20])
    make('divider',512,24,lambda:(line([(-250,0),(-22,0)],bronze,1.4),line([(22,0),(250,0)],bronze,1.4),diamond(0,0,8,edge),diamond(-15,0,3,bronze),diamond(15,0,3,bronze)))
    for state in ['normal','hover','pressed','disabled','primary','primary_hover','primary_pressed','danger']:
        def button(state=state):
            panel(320,96,ember if 'primary' in state else blood if state=='danger' else blue if state=='hover' else None,'pressed' in state)
            if state=='disabled':
                # Desaturate and darken the material itself; no decorative active glow.
                for m in [bronze,edge]:
                    for n in m.node_tree.nodes:
                        if n.type=='VALTORGB':
                            for e in n.color_ramp.elements:e.color=rgba('#3A403D')
            if state in ['primary_hover']:frame(282,58,1,edge,-9,c=3)
        make('button_'+state,320,96,button,[28,24,28,24],state.startswith('primary') or state in ['hover','danger'])
    for kind,w,h in [('hp',512,48),('xp',512,28),('boss',1024,64)]:
        def bar(w=w,h=h,kind=kind):
            frame(w-6,h-6,4,iron,c=6);frame(w-12,h-12,1.4,bronze,-6,c=3)
            for sx in [-1,1]:
                disk(sx*(w/2-11),0,2,edge,-9)
            if kind=='boss':
                for sx in [-1,1]:diamond(sx*(w/2-22),0,13,edge)
        make('bar_frame_'+kind,w,h,bar,[32 if kind=='boss' else 18,10,32 if kind=='boss' else 18,10])
        fh={'hp':32,'xp':16,'boss':40}[kind]
        make('bar_fill_'+kind,w,fh,lambda w=w,fh=fh,kind=kind:fill(w,fh,blue if kind=='xp' else blood),emission=True)
    make('bar_fill_hp_lost',512,32,lambda:fill(512,32,mat('#EAD6B5',.55,.15)))
    for name,size in [('level_badge',96),('gold',64),('xp',64),('ruby',64),('pause',96),('settings',96),('interact',96)]:
        make(name if name=='level_badge' else 'icon_'+name,size,size,lambda name=name,size=size:icon(name,size),emission=name in ['xp','ruby'])
    def minimap():
        torus((0,-1,0),148,6,iron);torus((0,-7,0),140,2,bronze);torus((0,-8,0),151,1,edge)
        for i in range(8):
            a=i*math.tau/8;disk(145*math.sin(a),145*math.cos(a),3,edge,-10)
        for sx in [-1,1]:
            for sz in [-1,1]:line([(sx*118,sz*84),(sx*128,sz*94),(sx*98,sz*124),(sx*86,sz*114)],bronze,2)
    make('minimap_frame',320,320,minimap)
    make('minimap_player',32,32,lambda:mini('player'),emission=True)
    for kind in ['chest','chest_large','chest_legendary','pillar','teleporter','boss','capsule']:
        make('minimap_'+kind,32,32,lambda kind=kind:mini(kind),emission=kind in ['chest_legendary','pillar','teleporter','boss','capsule'])
    make('vignette_hit',1024,1024,vignette)
    (T/'_u1_inventory.json').write_text(json.dumps(dict(style='STYLE.md + STYLE_boss_da.md',camera='orthographic front',render_scale=2,samples=16,assets=ROWS),indent=2))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ui/u1_library.blend'))
    print('PASS U1 render',len(ROWS),'assets',flush=True)
