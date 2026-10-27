"""TOCP3: five replacements. Reuse T2 isolated renderer and approved icon studio."""
from pathlib import Path
import sys, math, inspect, re, json, shutil
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools')]
WORK=ROOT/'art/blender/cel/tocp3'
GAME=ROOT/'game/assets/sprites/characters/tocsin'
ICONS=ROOT/'game/assets/sprites/icons/spells'
ANIMS={'throw_arm_l':4,'throw_arm_r':4,'cast':6}
DIRS=['e','se','s','sw','w','nw','n','ne']

def render():
    import bpy
    from mathutils import Vector, Euler
    import t2_build as base, iso_rig as iso, cel_style as cel
    WORK.mkdir(parents=True,exist_ok=True)
    base.OUT=WORK; base.configure()
    # Do not enumerate or write the obsolete pass, including temporary outputs.
    for fn in (iso.render_frame,base.render_tiles):
        src=inspect.getsource(fn).replace("('_n','_e')","('_e',)").replace("('','_n','_e')","('','_e')")
        exec(compile(src,fn.__code__.co_filename,'exec'),fn.__globals__)
    # Cel replaces Principled nodes: discard the source's now-invalid RNA sockets.
    base.emissions=[]
    cel.install('creature',normals=False)
    cel.toon_materials('creature')
    old_pose=base.pose
    evidence=[]
    def pose(anim,i):
        for ob in base.mods.values():ob.scale=(1,1,1)
        old_pose('idle',0)
        base.mods['head'].rotation_euler=(0,0,0)
        torso=base.mods['torso']
        if anim.startswith('throw_arm'):
            side=anim[-1];arm=base.mods['arm_'+side]
            pulse=[0,-.65,1,.12][i]
            torso.rotation_euler.x=.16*pulse
            torso.rotation_euler.z=(.11 if side=='l' else -.11)*pulse
            arm.rotation_euler=( [.70,1.85,-1.15,0][i], .14 if side=='l' else -.14,0)
            base.mods['arm_'+('r' if side=='l' else 'l')].rotation_euler.x=[-.18,-.35,.35,0][i]
            if i>=2:arm.scale=(0,0,0)
        else:
            pulse=[0,-.30,-.6,1,.26,0][i]
            torso.rotation_euler.x=.055*pulse
            arm=base.mods['arm_l']
            local=Vector((-.22,-.08,-.50))
            target=Vector((0,-.335,.77))
            contact=local.rotation_difference(target-arm.location)
            windup=Euler((.50,-.65,-.3)).to_quaternion()
            weight=[0,0,0,1,.72,0][i]
            quat=windup.slerp(contact,weight) if i in (1,2,3,4) else Euler((0,0,0)).to_quaternion()
            arm.rotation_euler=quat.to_euler()
            if i==3:arm.location=target-quat@local
            base.mods['arm_r'].rotation_euler.x=-.12*max(0,pulse)
            if i==3:evidence.append({'contact_error_u':(arm.location+quat@local-target).length})
        # The root and both feet remain fixed throughout every action.
        base.root.location=(0,0,0)
        for k in ('leg_l','leg_r'):
            base.mods[k].location=base.rest[k][0];base.mods[k].rotation_euler=(0,0,0)
        base.mods['neck_steam'].rotation_euler.z=.12*math.sin(i*2.1)
    base.pose=pose
    for anim,n in ANIMS.items():
        for d in DIRS:
            for i in range(n):
                pose(anim,i)
                if (WORK/anim/d/f'torso_{i:02d}.png').exists() and not ('--refresh-throws' in sys.argv and anim.startswith('throw_') and i<2):continue
                base.render_tiles(anim,d,i)
        print('PASS render '+anim,flush=True)
    (WORK/'pose.json').write_text(json.dumps(evidence))
    render_icons()

def render_icons():
    import bpy
    import icons_norm_build as kit
    kit.WORK=WORK;WORK.mkdir(parents=True,exist_ok=True)
    def pillar():
        metal=kit.mat('#5F8F80',.75,.7);iron=kit.mat('#303A37',.8,.65)
        brass=kit.mat('#A8946E',.7,.7)
        cold=kit.mat('#8FD9FF',.6,0,'#8FD9FF',2.2)
        kit.plate([(-.30,-.46),(.29,-.46),(.28,-.32),(.14,-.23),(-.14,-.23)],iron)
        kit.plate([(-.14,-.29),(.15,-.29),(.17,.28),(-.16,.28)],metal)
        for z in (-.19,-.06,.07,.20):kit.line([(-.17,z),(.17,z+.04)],.022,brass)
        kit.plate([(-.22,.27),(.22,.27),(.22,.42),(-.22,.42)],metal)
        for x in (-.18,0,.18):kit.line([(x,.34),(x*1.3,.53),(x*1.1,.62)],.028,iron)
        kit.line([(-.13,.38),(.13,.38)],.024,kit.glow)
        for s in (-1,1):
            kit.line([(s*.18,.51),(s*.35,.35),(s*.28,.20),(s*.49,.04),(s*.39,-.14),(s*.58,-.37)],.018,cold)
        kit.arc(0,-.44,.58,math.pi,math.tau,iron,.025,sy=.22)
    def bell():
        bronze=kit.mat('#668A76',.75,.7);iron=kit.mat('#303A37',.8,.65)
        kit.plate([(-.30,-.15),(-.21,.02),(-.17,.38),(-.07,.49),(.11,.49),(.21,.34),(.23,.02),(.34,-.15)],bronze)
        kit.line([(-.34,-.15),(.37,-.15)],.045,iron)
        kit.dot(.015,-.22,.065,kit.glow)
        kit.line([(-.51,.45),(-.24,.12)],.049,iron,y=-.41)
        kit.plate([(-.29,.22),(-.15,.10),(-.05,.23),(-.20,.36)],iron,y=-.42)
        for r in (.37,.53,.70):kit.arc(.035,-.13,r,math.pi*1.02,math.pi*2.02,kit.glow,.021,sy=.48)
        for a in (-.5,.4,1.4):kit.line([(-.17+.09*math.cos(a),.15+.09*math.sin(a)),(-.17+.19*math.cos(a),.15+.19*math.sin(a))],.018)
    for name,emblem in [('tocsin_bras_pilier',pillar),('tocsin_coup_de_tocsin',bell)]:
        if (WORK/(name+'_raw.png')).exists():continue
        scene=kit.scene(name,emblem,'#FF7A1F');scene.eevee.taa_render_samples=8
        scene.render.threads_mode='FIXED';scene.render.threads=8
        bpy.ops.render.render(write_still=True)
        print('PASS render '+name,flush=True)

def finish():
    from PIL import Image,ImageChops
    import numpy as np
    import cel_style as cel
    from halve_emission import downscale
    import icons_norm_finish as iconfit
    cel.archive_folder('characters/tocsin');cel.archive_folder('icons/spells')
    backup=WORK/'before'
    def save(im,p):
        if p.exists() and not (backup/p.relative_to(ROOT/'game')).exists():
            dest=backup/p.relative_to(ROOT/'game');dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
        p.parent.mkdir(parents=True,exist_ok=True);im.save(p,optimize=True,compress_level=9)
    orders=json.loads((GAME/'layers_order.json').read_text())['orders']
    specs={};report={}
    for anim,n in ANIMS.items():
        full=[Image.new('RGBA',(192,192)) for _ in range(n*8)]
        emit=[im.copy() for im in full]
        for layer in ('torso','head','neck_steam','arm_l','arm_r','leg_l','leg_r'):
            tiles=[];etiles=[]
            for row,d in enumerate(DIRS):
                for i in range(n):
                    p=WORK/anim/d/f'{layer}_{i:02d}.png'
                    tiles.append(Image.open(p).convert('RGBA'))
                    ep=p.with_name(p.stem+'_e.png')
                    etiles.append(Image.open(ep).convert('RGBA') if ep.exists() else Image.new('RGBA',(192,192)))
            if layer.startswith('leg_'):
                for row in range(8):
                    assert all(ImageChops.difference(tiles[row*n],tiles[row*n+i]).getbbox() is None for i in range(n)),(anim,layer,'moving foot')
            pack(tiles,etiles,f'layers/{layer}/{anim}.png',n,specs,save)
            # Packed names remain the runtime entry points; one constant crop per animation.
            for suffix in ('','_e'):
                p=GAME/f'layers/{layer}/{anim}{suffix}.png'
                if p.exists():save(Image.open(p),p.parent/'packed'/p.name)
            specs[f'layers/{layer}/packed/{anim}.png']=specs[f'layers/{layer}/{anim}.png']
        # Composite in the existing per-direction depth order, never an invented order.
        for row,d in enumerate(DIRS):
            for i in range(n):
                for layer in orders[d]:
                    if layer=='neck_steam':continue
                    p=WORK/anim/d/f'{layer}_{i:02d}.png';full[row*n+i].alpha_composite(Image.open(p).convert('RGBA'))
                    ep=p.with_name(p.stem+'_e.png')
                    if ep.exists():emit[row*n+i].alpha_composite(Image.open(ep).convert('RGBA'))
        pack(full,emit,anim+'.png',n,specs,save)
        report[anim]={'frames':n,'dirs':8,'impact':3 if anim=='cast' else 2,'feet_static':True}
    # Change only AtlasTexture blocks that belong to these three animations.
    for p in GAME.rglob('*.tres'):
        text=p.read_text(encoding='utf-8');ext={i:r.removesuffix('_e.png')+'.png' if r.endswith('_e.png') else r for r,i in re.findall(r'path="res://assets/sprites/characters/tocsin/([^"\n]+)" id="([^"\n]+)"',text)}
        frameids={}
        for frames,name in re.findall(r'\{"frames": \[(.*?)\].*?"name": &"([^"\n]+)"',text):
            for anim,n in ANIMS.items():
                if name in [anim+'_'+d for d in DIRS]:
                    row=DIRS.index(name[len(anim)+1:])
                    for i,sid in enumerate(re.findall(r'SubResource\("([^"]+)"\)',frames)):frameids[sid]=(row,i)
        def block(m):
            part=m[0];sid=re.search(r'id="([^"]+)"',part)[1]
            atlas=re.search(r'atlas = ExtResource\("([^"]+)"\)',part)
            if sid not in frameids or not atlas or ext.get(atlas[1]) not in specs:return part
            x,y,w,h=specs[ext[atlas[1]]];row,i=frameids[sid]
            part=re.sub(r'region = Rect2\([^)]+\)',f'region = Rect2({i*w}, {row*h}, {w}, {h})',part)
            part=re.sub(r'margin = Rect2\([^)]+\)\n?','',part)
            return part.rstrip()+f'\nmargin = Rect2({x}, {y}, {192-w}, {192-h})\n\n'
        new=re.sub(r'\[sub_resource type="AtlasTexture"[^\[]+',block,text)
        if new!=text:
            dest=backup/p.relative_to(ROOT/'game');dest.parent.mkdir(parents=True,exist_ok=True)
            if not dest.exists():shutil.copy2(p,dest)
            p.write_text(new,encoding='utf-8')
    for name in ('tocsin_bras_pilier','tocsin_coup_de_tocsin'):
        raw=WORK/(name+'_raw.png');assert raw.exists()
        # Approved medallion uses the exact same backing, camera and fit as neighbours.
        save(iconfit.fit_image(raw),ICONS/(name+'.png'))
    report['sheets']=specs
    report['scale']='R=64*sqrt(2); CREA x=0.70710678, y=1.4142136; 64px/u; scalar 1.0'
    (WORK/'verification.json').write_text(json.dumps(report,indent=2))
    print('PASS export: 5 deliverables')

def pack(tiles,etiles,rel,n,specs,save):
    from PIL import Image
    from halve_emission import downscale
    boxes=[im.getchannel('A').getbbox() for im in tiles];boxes=[b for b in boxes if b]
    assert boxes,rel
    x=min(b[0] for b in boxes)-4;y=min(b[1] for b in boxes)-4
    x1=max(b[2] for b in boxes)+4;y1=max(b[3] for b in boxes)+4
    assert x>=0 and y>=0 and x1<=192 and y1<=192,(rel,'clip',(x,y,x1,y1))
    w,h=x1-x,y1-y;specs[rel]=[x,y,w,h]
    sheet=Image.new('RGBA',(w*n,h*8));em=Image.new('RGBA',sheet.size)
    for k,(a,b) in enumerate(zip(tiles,etiles)):
        row,i=divmod(k,n);sheet.paste(a.crop((x,y,x1,y1)),(i*w,row*h));em.paste(b.crop((x,y,x1,y1)),(i*w,row*h))
    save(sheet,GAME/rel)
    if max(c.getextrema()[1] for c in em.split()[:3])>2:save(downscale(em),(GAME/rel).with_name(Path(rel).stem+'_e.png'))

if __name__=='__main__':
    if '--finish' in sys.argv:finish()
    else:render()
