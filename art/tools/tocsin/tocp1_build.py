"""TOCP1: reuse T4 studio, CD geometry helpers and shared cel compositor. No normals."""
from pathlib import Path
import sys, math, json, inspect, shutil
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools')]
WORK=ROOT/'art/blender/cel/tocp1'
GAME=ROOT/'game/assets/sprites/characters/tocsin'
ANIMS={'arm_fly':6,'arm_clamp':8,'arm_ground':1}
DIRS=['e','se','s','sw','w','nw','n','ne']

def render():
    import bpy
    from mathutils import Matrix,Vector
    import t4_build as t4, cel_style as cel, iso_rig as iso
    WORK.mkdir(parents=True,exist_ok=True)
    t4.OUT=WORK; t4.setup(); cd=t4.cd; scene=t4.scene
    # Preserve the approved worn material sources; replace only detached arm geometry.
    arm=cd.empty('TOCP1 elbow pillar')
    iron=cd.worn('TOCP1 forged iron','292C2B','646C63',.75,.85)
    bronze=cd.worn('TOCP1 worn verdigris bronze','36544C','789A80',.7,.8)
    copper=cd.worn('TOCP1 dark copper windings','653C28','AA7850',.8,.65)
    brass=cd.worn('TOCP1 worn brass','69604B','B3A17D',.7,.75)
    dark=cd.flat('TOCP1 recess','222A28')
    hot=cd.flat('TOCP1 furnace FF7A1F','FF7A1F',1.6)
    cold=cd.flat('TOCP1 arc 8FD9FF','8FD9FF',2.2)
    smoke=cd.flat('TOCP1 neutral smoke','60685F')
    # Bent upper-arm remnant and broad elbow shoe; forearm planted vertically.
    cd.cyl('Quick release socket',(-.28,.10,.10),(-.18,.08,.13),.115,bronze,arm)
    cd.cyl('Upper arm piston',(-.20,.08,.12),(0,0,.23),.075,iron,arm)
    cd.cyl('Elbow axle',(-.15,0,.17),(.15,0,.17),.105,brass,arm)
    cd.block('Elbow ground shoe',(0,0,.075),(.32,.32,.12),iron,arm,.018)
    cd.cyl('Forearm bronze casing',(0,0,.21),(0,0,.86),.13,bronze,arm,vertices=12,r2=.155)
    for z in [.26,.85]: cd.ring('Retaining iron collar',z,.15,.15,0,.027,iron,arm)
    for a in [0,math.pi/2,math.pi,math.pi*1.5]:
        x,y=math.cos(a),math.sin(a)
        cd.cyl('Exposed piston',(x*.145,y*.145,.29),(x*.145,y*.145,.79),.016,brass,arm,12)
    points=[]
    for j in range(145):
        q=j/144; a=q*math.tau*4.5
        points.append((.161*math.cos(a),.161*math.sin(a),.34+q*.41))
    cd.tube('Copper induction coil',points,.019,copper,arm)
    for z in [.28,.84]: cd.rivets(arm,z,.157,.157,0,brass,n=8)
    cd.cyl('Gauntlet open palm',(0,0,.86),(0,0,1.015),.174,bronze,arm,12,r2=.19)
    cd.cyl('Gauntlet dark open bowl',(0,0,1.014),(0,0,1.025),.143,dark,arm,16)
    cd.ring('Furnace rim',1.023,.151,.151,0,.014,hot,arm)
    cd.cyl('Head furnace core',(0,0,1.026),(0,0,1.035),.078,hot,arm,16)
    fingertips=[]
    for j in range(3):
        a=j*math.tau/3+.28; c,s=math.cos(a),math.sin(a)
        pts=[(.15*c,.15*s,.98),(.22*c,.22*s,1.13),(.23*c,.23*s,1.25),(.19*c,.19*s,1.30)]
        cd.tube('Open articulated iron finger',pts,.033,iron,arm)
        cd.bead('Knuckle bronze hinge',pts[1],(.042,.042,.042),brass,arm)
        fingertips.append(Vector(pts[-1]))
    arcs=[]
    for phase in range(8):
        group=cd.empty('Arc phase '+str(phase),parent=arm)
        for j in range(2):
            a=fingertips[(phase+j)%3]; b=fingertips[(phase+j+1)%3]
            pts=[]
            for k in range(7):
                p=a.lerp(b,k/6)
                if 0<k<6:p+=Vector((.025*math.sin(k*2.7+phase),.02*math.cos(k*3+phase),.035*math.sin(k*4+phase)))
                pts.append(tuple(p))
            cd.tube('Blue white crackle',pts,.007 if j else .009,cold,group)
        arcs.append(group)
    embers=cd.empty('Lob ember trail')
    for j in range(11):
        x=.12*math.sin(j*2.4); y=.27+j*.045; z=.60+.11*math.sin(j*1.7)
        cd.bead('Flying ember',(x,y,z),(.012,.02,.012),hot,embers)
    wisps=cd.empty('Pickup smoke')
    for j in range(2):
        cd.tube('Cooling grey wisp',[(.08*j,.06,.15),(.08*j+.025,.06,.25),(.08*j-.01,.06,.33)],.008,smoke,wisps)
    shadow=cd.empty('Baked ground shadow')
    cd.bead('Contact shadow',(0,0,.012),(.28,.22,.012),dark,shadow)
    cel.install('creature',normals=False)
    cel.toon_materials('creature')
    # Reuse the renderer with only its obsolete normal-pass enumeration removed.
    source=inspect.getsource(iso.render_frame).replace("for suffix in ('_n','_e'):","for suffix in ('_e',):")
    exec(compile(source,iso.__file__,'exec'),iso.__dict__)
    scene.render.threads_mode='FIXED';scene.render.threads=8
    scene.eevee.taa_render_samples=8
    for anim,n in ANIMS.items():
        for row,d in enumerate(DIRS):
            for i in range(n):
                path=WORK/anim/d/f'{i:02d}.png'
                if path.exists() and path.with_name(path.stem+'_e.png').exists() and not (anim=='arm_ground' and '--refresh-ground' in sys.argv):continue
                t4.reset_parts()
                arm.location=(0,0,0);arm.rotation_euler=(0,0,0)
                t4.t1.visible(arm,True)
                for j,g in enumerate(arcs):t4.t1.visible(g,anim=='arm_clamp' and j==i)
                t4.t1.visible(embers,anim=='arm_fly')
                t4.t1.visible(wisps,anim=='arm_ground')
                t4.t1.visible(shadow,anim!='arm_fly')
                hot.node_tree.nodes.get('Emission').inputs['Strength'].default_value=(1.4+.45*math.sin(i*math.tau/n)) if anim!='arm_ground' else 0
                for node in hot.node_tree.nodes:
                    if node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=tuple(c*(1.4+.45*math.sin(i*math.tau/n)) for c in cd.rgb('FF7A1F')[:3])+(1,) if anim!='arm_ground' else (0,0,0,1)
                # Root supplies direction; arm supplies roll about its own forearm axis.
                angle=t4.DIRS[d]
                rot=Matrix.Rotation(angle,4,'Z')
                if anim=='arm_fly':rot=rot@Matrix.Rotation(math.pi/2,4,'X')@Matrix.Rotation(i*math.tau/n,4,'Z')
                elif anim=='arm_ground':rot=rot@Matrix.Rotation(math.pi/2,4,'X')@Matrix.Rotation(-.18,4,'Y')
                arm.rotation_euler=rot.to_euler()
                if anim=='arm_fly':arm.location=-(rot.to_3x3()@Vector((0,0,.65)))+Vector((0,0,.55))
                elif anim=='arm_ground':t4.center(arm,.025)
                embers.rotation_euler.z=angle
                wisps.rotation_euler.z=angle;wisps.location.x=.012*i
                t4.t1.frame(192,.21)
                iso.render_frame(path,passes=True)
        print('TOCP1 RENDER PASS '+anim,flush=True)

def finish():
    from PIL import Image,ImageChops
    import numpy as np
    import cel_style as cel
    from halve_emission import downscale
    cel.archive_folder('characters/tocsin')
    backup=WORK/'before';backup.mkdir(parents=True,exist_ok=True)
    report={}
    for anim,n in ANIMS.items():
        for p in [GAME/(anim+s+'.png') for s in ('','_e')]+[GAME/('tocsin_'+anim+s+'.tres') for s in ('','_emission')]:
            if p.exists() and not (backup/p.name).exists():shutil.copy2(p,backup/p.name)
        tiles=[];box=None
        for d in DIRS:
            for i in range(n):
                p=WORK/anim/d/f'{i:02d}.png'
                im=Image.open(p).convert('RGBA');bb=im.getchannel('A').getbbox();assert bb
                assert bb[0]>0 and bb[1]>0 and bb[2]<192 and bb[3]<192,(anim,d,i,'clipping',bb)
                box=bb if box is None else (min(box[0],bb[0]),min(box[1],bb[1]),max(box[2],bb[2]),max(box[3],bb[3]))
                tiles.append(im)
        box=(box[0]-4,box[1]-4,box[2]+4,box[3]+4)
        x,y,x1,y1=box;w,h=x1-x,y1-y
        sheet=Image.new('RGBA',(w*n,h*8));es=Image.new('RGBA',sheet.size)
        for idx,im in enumerate(tiles):
            row,col=divmod(idx,n);sheet.paste(im.crop(box),(col*w,row*h))
            p=WORK/anim/DIRS[row]/f'{col:02d}_e.png'
            es.paste(Image.open(p).convert('RGBA').crop(box),(col*w,row*h))
        sheet.save(GAME/(anim+'.png'),optimize=True,compress_level=9)
        emissive=anim!='arm_ground'
        if emissive:
            em=downscale(es);assert np.asarray(em)[...,:3].max()>2
            em.save(GAME/(anim+'_e.png'),optimize=True,compress_level=9)
        else:
            p=GAME/(anim+'_e.png')
            if p.exists():p.unlink()
        # Atlas margins keep the original logical 192 cell and 96/136.32 pivot.
        for emission in (False,True):
            path=GAME/('tocsin_'+anim+('_emission' if emission else '')+'.tres')
            if emission and not emissive:
                # Keep the existing resource valid, with an empty set of animations.
                path.write_text('[gd_resource type="SpriteFrames" format=3]\n\n[resource]\nanimations = []\n');continue
            subs=[];anims=[]
            for row,d in enumerate(DIRS):
                frames=[]
                for i in range(n):
                    sid=f'f{row}_{i}';subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\nregion = Rect2({i*w}, {row*h}, {w}, {h})\nmargin = Rect2({x}, {y}, {192-w}, {192-h})')
                    frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
                fps=10.0 if anim=='arm_fly' else 8.0 if anim=='arm_clamp' else 2.0
                anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(anim!='arm_fly').lower()+', "name": &"'+anim+'_'+d+'", "speed": '+str(fps)+'}')
            tex=anim+('_e' if emission else '')+'.png'
            path.write_text(f'[gd_resource type="SpriteFrames" load_steps={len(subs)+2} format=3]\n\n[ext_resource type="Texture2D" path="res://assets/sprites/characters/tocsin/{tex}" id="1"]\n\n'+'\n\n'.join(subs)+'\n\n[resource]\nanimations = [\n'+',\n'.join(anims)+'\n]\n')
        report[anim]={'frames':n,'directions':8,'crop':box,'cell':[w,h],'atlas':list(sheet.size),'logical_cell':192,'pivot':[96,136.32],'emission':emissive}
    (WORK/'verification.json').write_text(json.dumps(report,indent=2))
    print('TOCP1 EXPORT PASS '+json.dumps(report))

if __name__=='__main__':
    if '--finish' in sys.argv:finish()
    else:render()
