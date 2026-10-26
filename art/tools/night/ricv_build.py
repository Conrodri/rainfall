"""RICV: TOP Eevee cel sprites; assembly only in Pillow; no normal exports."""
import sys, math, random, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/night'))
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import m3_build as m
import cel_style as cel
import bpy
from PIL import Image
RAW=ROOT/'art/blender/ricv'; RAW.mkdir(parents=True,exist_ok=True)
DEST=ROOT/'game/assets/sprites/characters/rictus/variants'
SPECS={'montreur_hand_slam':(384,8,False,8/.3),'pendulum_knife':(96,4,True,16),'pirouette_burst':(608,6,False,24)}
def rod(a,b,r,mat): return m.ui.rod(a,b,r,mat)
def arc(radius,a,b,width,mat,z=.03): return m.ribbon(radius,a,b,width,mat,z,13)
def hand(f):
    # Articulated narrow spectral phalanges, five independent strings.
    offset=[.46,.34,.2,.08,0,0,0,0][f]
    if f<6:
        fade=1 if f<5 else .45
        ghost=m.ui.mat('#648A83',.5,.15)
        p=ghost.node_tree.nodes.get('Principled BSDF');p.inputs['Alpha'].default_value=.62*fade
        ghost.surface_render_method='DITHERED'
        m.mesh('spectral metacarpals',[(-.18,-.36+offset,.08),(.17,-.36+offset,.08),(.25,.14+offset,.08),(.11,.25+offset,.08),(-.24,.14+offset,.08),(0,-.02+offset,.16)],[(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5)],ghost,.015)
        for j in range(5):
            x=(j-2)*.115; length=[.38,.62,.73,.64,.49][j]
            pts=[(x,-.02+offset,.13),(x*1.25,.2+offset,.1),(x*1.38,.2+length*.55+offset,.06),(x*1.48,.2+length+offset,.035)]
            if j==0:pts=[(-.18,-.15+offset,.1),(-.34,-.02+offset,.08),(-.43,.12+offset,.06),(-.48,.26+offset,.035)]
            for a,b in zip(pts,pts[1:]):rod(a,b,.024,ghost);m.ui.sphere(b,(.028,.031,.021),ghost)
            rod(pts[-2],pts[-1],.012,m.glow)
            end=pts[1]; rod((x*2,-1.38,.04),end,.007,m.glow)
        rod((-.15,-.32+offset,.09),(-.22,-.6+offset,.1),.06,ghost)
    if f>=4:
        r=[.36,.76,1.12,1.4][f-4]
        for j in range(12):
            a=j*math.tau/12
            arc(r,a,a+.43,.055*(1-(f-4)*.21),m.glow)
            if f<7:arc(r-.09,a+.05,a+.35,.07,m.silver,.012)
def knife(f):
    # Heavy broad blade, point initially +X; local knot only, no trailing string.
    m.mesh('broad forged pendulum', [(-.2,-.16,.04),(.35,-.19,.04),(.63,0,.045),(.35,.19,.04),(-.2,.16,.04),(-.12,0,.14),(.36,0,.13)],[(0,1,6,5),(1,2,6),(2,3,6),(3,4,5,6),(4,0,5)],m.silver,.008)
    rod((-.24,-.23,.04),(-.24,.23,.04),.035,m.iron)
    rod((-.55,0,.04),(-.25,0,.04),.07,m.wood)
    for x in [-.5,-.43,-.36]:rod((x,-.065,.06),(x+.025,.065,.06),.012,m.iron)
    pts=[(-.58+.065*math.cos(j*math.tau/32),.09*math.sin(j*math.tau/32),.06) for j in range(33)]
    m.ui.curve(pts,.012,m.glow)
    rod((-.54,-.03,.06),(-.59,.035,.065),.018,m.silver)
    for o in list(bpy.context.scene.objects):
        if o.type not in {'LIGHT','CAMERA'}:o.rotation_euler.z+=f*math.pi/2

def burst(f):
    rng=random.Random(414)
    radius=[.48,.91,1.32,1.7,2,2.2][f]
    for j in range(24):
        a=j*math.tau/24+rng.uniform(-.045,.045)
        arc(radius,a,a+.18,.045*(1-f*.12),m.glow)
        arc(radius-.06,a-.07,a+.14,.08*(1-f*.1),m.silver,.015)
        reach=radius*(.78 if f<2 else .91)
        pts=[(reach*math.cos(a-.12),reach*math.sin(a-.12),.04),((radius-.03)*math.cos(a), (radius-.03)*math.sin(a),.04),(radius*math.cos(a+.08),radius*math.sin(a+.08),.04)]
        m.ui.curve(pts,.009,m.glow)
        rr=radius*rng.uniform(.64,.97); x,y=rr*math.cos(a),rr*math.sin(a)
        o=m.ui.sphere((x,y,.07),(.045,.012,.018),m.wood if j%3 else m.silver);o.rotation_euler.z=a+.7
    if f<2:
        for j in range(8):arc(.13+j*.035,0,math.tau-.03,.017,m.iron)

def resource(name,size,count,loop,speed,emission=False):
    suffix='_e' if emission else ''; step=1
    path=f'res://assets/sprites/characters/rictus/variants/{name}/default{suffix}.png'
    txt=f'[gd_resource type="SpriteFrames" load_steps={count+2} format=3]\n\n[ext_resource type="Texture2D" path="{path}" id="default"]\n\n'
    for f in range(count):txt+=f'[sub_resource type="AtlasTexture" id="default_{f}"]\natlas = ExtResource("default")\nregion = Rect2({f*size//step}, 0, {size//step}, {size//step})\n\n'
    frames=[{'duration':1.0,'texture':f'SubResource("default_{f}")'} for f in range(count)]
    entries=', '.join('{"duration": 1.0, "texture": '+x['texture']+'}' for x in frames)
    txt+='[resource]\nanimations = [{"frames": ['+entries+f'], "loop": {str(loop).lower()}, "name": &"default", "speed": {speed}'+'}]\n'
    (DEST/name/(name+('_emission' if emission else '')+'.tres')).write_text(txt)

def build():
    for name,(size,count,loop,speed) in SPECS.items():
        dest=DEST/name;dest.mkdir(parents=True,exist_ok=True)
        sheets={s:Image.new('RGBA',(size*count,size)) for s in ['','_e']}
        for f in range(count):
            m.iso.create_rig('TOP',size,reset=True);m.palette()
            s=bpy.context.scene;s.eevee.taa_render_samples=12
            s.render.threads_mode='FIXED';s.render.threads=8
            if name=='pendulum_knife':s.camera.data.ortho_scale=size/64
            {'montreur_hand_slam':hand,'pendulum_knife':knife,'pirouette_burst':burst}[name](f)
            path=RAW/f'{name}_{f}.png'
            cel.install('vfx',normals=False)
            m.iso.common.configure_passes(path)
            s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
            emission=list(RAW.glob(path.stem+'_e__*.png'))
            assert len(emission)==1,emission
            for suffix,p in [('',path),('_e',emission[0])]:
                im=Image.open(p).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
                sheets[suffix].paste(im,(f*size,0))
            emission[0].unlink()
        for suffix,im in sheets.items():
            if suffix:im=im.resize((im.width//2,im.height//2),Image.Resampling.LANCZOS)
            im.save(dest/f'default{suffix}.png',compress_level=9)
        resource(name,size,count,loop,speed);resource(name,size,count,loop,speed,True)
        cel.check_sheet(f'characters/rictus/variants/{name}/default.png',cell=size,frames=count,rows=1,normals=False)
        print('RICV PASS',name,flush=True)
    contact()
def contact():
    board=Image.new('RGB',(2048,6*256))
    for bi,bg in enumerate(['#0A0D12','#2E3238']):
        for row,(name,(size,count,_,_)) in enumerate(SPECS.items()):
            y=(bi*3+row)*256;board.paste(Image.new('RGB',(2048,256),bg),(0,y))
            sheet=Image.open(DEST/name/'default.png').convert('RGBA')
            for f in range(count):
                tile=sheet.crop((f*size,0,(f+1)*size,size));tile.thumbnail((248,248),Image.Resampling.LANCZOS)
                board.paste(tile,(f*256+(256-tile.width)//2,y+(256-tile.height)//2),tile)
    board.save(ROOT/'art/tools/night/_ricv_contact.png')
if __name__=='__main__':build()
