"""AR1 action retake: cel creature, 192 logical cells, copper accent, no normals.
Blender background only. --source-only / --finish / --verify / --reuse.
"""
import sys, math, json
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/characters'))
import bpy
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel
from mathutils import Vector, Matrix
import cd_cd2_pipeline as cd
import iso_rig
from PIL import Image
# Preserve cell alignment while assembling the nonempty copper emission masks.
_optimize_png=iso_rig.optimize_png
def preserve_contract_pass(path,crop=False,margin=6):
    if Path(path).stem.endswith('_e'):return (0,0,192,192)
    return _optimize_png(path,crop,margin)
iso_rig.optimize_png=preserve_contract_pass
OUT=ROOT/'game/assets/sprites/characters/arpenteuse'
SOURCE=ROOT/'art/blender/characters/arpenteuse.blend'
RAW=SOURCE.with_name('arpenteuse_frames')
ANIMS={'idle':8,'run':8,'plant':5,'loop':6,'whip':8,'attack':6,'cast':4,'cast_ult':6,'death':8}
F60={'plant':[5,5,4,8,8],'loop':[4,4,5,6,6,6],'whip':[4,4,4,4,8,9,9,8]}
RENDER_ANIMS={'plant','loop','whip'}
DIRS=cd.iso_rig.DIRECTIONS
FPS={'idle':8,'run':12,'plant':10,'loop':12,'whip':14,'attack':12,'cast':10,'cast_ult':12,'death':10}

def rig_body():
    source=ROOT/'art/blender/characters/cd_arpenteuse.blend'
    if source.exists():
        bpy.ops.wm.open_mainfile(filepath=str(source))
        if '--inspect' in sys.argv:
            print('AR1_INSPECT',[(o.name,o.type,o.parent.name if o.parent else None) for o in bpy.context.scene.objects][:24],flush=True)
            return None
    root=next((o for o in bpy.context.scene.objects if o.name.startswith('Arpenteuse') and o.type=='EMPTY'),None)
    if root:
        for ob in list(bpy.context.scene.objects):
            ob.animation_data_clear()
        bpy.context.scene.frame_set(1)
        root.location=(0,0,0);root.rotation_euler=(0,0,0);root.scale=(1,1,1)
        # Remove presentation trail, ultimate pose and presentation environment.
        for ob in list(bpy.context.scene.objects):
            if ob==root:continue
            ancestors=[];p=ob.parent
            while p:ancestors.append(p);p=p.parent
            if root not in ancestors or any(p.name.startswith(('Ground trail','Tendeur closed')) for p in ancestors) or ob.name.startswith(('Ground trail','Tendeur closed')):
                bpy.data.objects.remove(ob,do_unlink=True)
        for ob in root.children:
            if ob.name.startswith('Arm '):ob.rotation_euler=(0,0,0)
    else:
        # Approved .blend contains the composed design board, not the actor.
        # Rebuild its original geometry using the exact CD2 modelling recipe.
        bpy.ops.wm.read_factory_settings(use_empty=True)
        cd.studio();root,_,_=cd.arpenteuse()
        for ob in list(root.children_recursive):
            ancestors=[];p=ob.parent
            while p:ancestors.append(p.name);p=p.parent
            if ob.type in ('MESH','CURVE') and ('Ground trail' in ancestors or 'Chain lead' in ob.name):bpy.data.objects.remove(ob,do_unlink=True)
    bpy.context.view_layer.update()
    objects=[]
    for ob in list(root.children_recursive):
        if ob.type not in ('MESH','CURVE'):continue
        parents=[];p=ob.parent
        while p:parents.append(p.name);p=p.parent
        kind='body'
        for side in (-1,1):
            if 'Arm '+str(side) in parents:kind='arm'+str(side)
            if 'Booted leg '+str(side) in parents:kind='leg'+str(side)
        if ob.name.startswith(('Split storm coat panel','Stitched coat seam')):kind='coat'
        if ob.name.startswith(('Long human','Angular jaw','Nose','Sunken','Narrow tired','Cheekbone','Closed severe','Close leather','Cap visor')):kind='head'
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
        bpy.ops.object.convert(target='MESH');ob=bpy.context.object
        world=ob.matrix_world.copy();ob.parent=None;ob.matrix_world=Matrix.Identity(4);ob.data.transform(world)
        objects.append((ob,kind))
    # Real deform rig: knees, elbows, neck and independently weighted coat quarters.
    data=bpy.data.armatures.new('Arpenteuse anatomical rig');rig=bpy.data.objects.new('AR1_rig',data);bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    def bone(n,a,b,parent=None):
        o=data.edit_bones.new(n);o.head=a;o.tail=b
        if parent:o.parent=data.edit_bones[parent]
    bone('root',(0,0,0),(0,0,.85));bone('spine',(0,0,.85),(0,0,1.43),'root');bone('head',(0,0,1.43),(0,0,1.78),'spine')
    for side in (-1,1):
        s=str(side);x=side*.095
        bone('thigh'+s,(x,0,.86),(side*.12,.025,.44),'root')
        bone('shin'+s,(side*.12,.025,.44),(side*.13,-.015,.09),'thigh'+s)
        bone('upper'+s,(side*.23,0,1.36),(side*.325,.025,1.08),'spine')
        bone('fore'+s,(side*.325,.025,1.08),(side*.31,-.10,.75),'upper'+s)
        bone('coat'+s,(side*.12,0,.98),(side*.25,0,.22),'root')
    bpy.ops.object.mode_set(mode='OBJECT')
    for ob,kind in objects:
        groups={n:ob.vertex_groups.new(name=n) for n in data.bones.keys()}
        for v in ob.data.vertices:
            z=v.co.z
            weights={'spine':1}
            if kind=='head':weights={'head':1}
            elif kind.startswith('arm'):
                side=kind[3:];f=max(0,min(1,(1.15-z)/.16));weights={'upper'+side:1-f,'fore'+side:f}
            elif kind.startswith('leg'):
                side=kind[3:];f=max(0,min(1,(.51-z)/.16));weights={'thigh'+side:1-f,'shin'+side:f}
            elif kind=='coat':
                side='1' if v.co.x>=0 else '-1';f=max(0,min(1,(.98-z)/.55));weights={'root':1-f,'coat'+side:f}
            for name,w in weights.items():
                if w>0:groups[name].add([v.index],w,'REPLACE')
        ob.parent=rig;mod=ob.modifiers.new('AR1 deformation','ARMATURE');mod.object=rig
    for ob in list(bpy.context.scene.objects):
        if ob.type=='EMPTY':bpy.data.objects.remove(ob,do_unlink=True)
    # Join skinned parts: avoids hundreds of render draw calls, preserves materials/groups.
    bpy.ops.object.select_all(action='DESELECT')
    for ob,_ in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0][0];bpy.ops.object.join()
    body=bpy.context.object;body.name='Arpenteuse final waxed coat bronze instruments'
    rig.scale=(.80,)*3
    s=iso_rig.create_rig('CREA',192,reset=False);s.camera.data.shift_y=.21
    # Load shared boss lighting without disturbing the finished mesh.
    for ob in list(s.objects):
        if ob.type=='LIGHT':bpy.data.objects.remove(ob,do_unlink=True)
    for name,pos,power,col,size in [('AR1 warm key',(-3,-4,6),480,(1,.76,.53),3),('AR1 cold fill',(3,-1,4),180,(.50,.66,.85),3),('AR1 edge',(2,3,4),320,(.63,.73,.83),2)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=col;d.shape='DISK';d.size=size
        ob=bpy.data.objects.new(name,d);s.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,0,.8))-ob.location).to_track_quat('-Z','Y').to_euler()
    s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.18,.18,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    s.eevee.taa_render_samples=16;s.render.threads_mode='FIXED';s.render.threads=8
    s.view_layers[0].use_pass_normal=False;s.view_layers[0].use_pass_emit=True
    s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
    s.render.dither_intensity=0
    s['AR1_contract']=json.dumps({'cell':192,'pivot':[96,136.32],'R':iso_rig.R,'directions':list(DIRS),'source':'cd_arpenteuse.blend','body_emission':False,'impact_frame':'N/2','animations':ANIMS})
    # AO is embedded by a shader node, shared with the official rig.
    iso_rig.bake_ao_shadows(body)
    return rig

def pose(rig,anim,f,n):
    for b in rig.pose.bones:b.rotation_mode='XYZ';b.rotation_euler=(0,0,0);b.location=(0,0,0)
    p=rig.pose.bones;t=f/n;w=t*math.tau;q=f/max(1,n-1);hit={'plant':2,'loop':2,'whip':4}.get(anim,n//2)
    if anim in RENDER_ANIMS:
        strength={'plant':[.8,1,1,.4,.06],'loop':[.8,1,1,.6,.25,.04],'whip':[.7,.85,1,1,1,.65,.3,.04]}[anim][f]
        p['spine'].rotation_euler.x=({'plant':[-.38,-.2,.42,.18,.02],'loop':[-.1,.15,.28,.18,.08,0],'whip':[.4,.55,.65,-.25,-.18,.12,.08,0]}[anim][f])
    pulse=(f/hit if f<=hit else (n-1-f)/max(1,n-1-hit))
    p['root'].location.y=.008*math.sin(w);p['head'].rotation_euler.y=.025*math.sin(w)
    if anim=='idle':
        p['root'].location.y=.012*math.sin(w+.2)
        p['spine'].rotation_euler.x=.035*math.cos(w)
        p['spine'].rotation_euler.y=.04*math.sin(w)
        p['head'].rotation_euler.y=.075*math.sin(w+.55)
    for side in (-1,1):
        s=str(side);phase=w+(math.pi if side<0 else 0)
        p['upper'+s].rotation_euler.x=.025*math.sin(phase)
        p['fore'+s].rotation_euler.x=.06
        p['coat'+s].rotation_euler.x=.015*math.sin(phase)
        if anim=='run':
            p['root'].location.y=.026*(1-math.cos(2*w));p['spine'].rotation_euler.x=.09
            p['thigh'+s].rotation_euler.x=.52*math.sin(phase)
            p['shin'+s].rotation_euler.x=-.58*max(0,-math.sin(phase))
            p['upper'+s].rotation_euler.x=-.44*math.sin(phase)
            p['fore'+s].rotation_euler.x=.24+.20*max(0,math.sin(phase))
            p['coat'+s].rotation_euler.x=.22*math.sin(phase-.5)
        elif anim in ('plant','cast'):
            if anim=='plant':
                pulse=[.85,1,1,.4,.05][f]
                u=[0,-.25,1,.65,.18][f];p['root'].location.y=(-.12 if f<2 else -.05)*pulse;p['spine'].rotation_euler.x=[-.42,-.18,.42,.16,0][f]
                p['upper'+s].rotation_euler.x=((-1.55 if side==1 else .42) if f==2 else (.95 if side==1 and f==0 else -.25))*pulse
                p['fore'+s].rotation_euler.x=((-1.05 if side==1 else .3) if f==2 else (-.8 if f==1 and side==1 else .15))*pulse
                p['upper'+s].rotation_euler.z=-side*(.85 if f==2 else .35)*pulse
                p['fore'+s].rotation_euler.x=.05 if f==2 and side==1 else p['fore'+s].rotation_euler.x
                p['coat'+s].rotation_euler.x=.12*pulse
            else:
                p['root'].location.y=-.16*pulse;p['spine'].rotation_euler.x=.40*pulse
                p['thigh'+s].rotation_euler.x=.32*pulse;p['shin'+s].rotation_euler.x=-.45*pulse
                p['upper'+s].rotation_euler.x=(-.85 if side==1 else .25)*pulse
                p['fore'+s].rotation_euler.x=(-.55 if side==1 else .2)*pulse
        elif anim=='loop':
            p['root'].location.y=[.02,.08,-.05,-.10,-.04,0][f];p['spine'].rotation_euler.y=[0,-.25,.95,.45,.16,0][f]
            p['upper'+s].rotation_euler.x=([-1.35,-1.0,-1.75,-.9,-.45,-.2][f] if side==1 else [.85,.45,.65,.35,.15,0][f]);p['upper'+s].rotation_euler.z=-side*[.95,.4,1.0,.55,.25,0][f]
            p['fore'+s].rotation_euler.x=[-.3,-.75,.02,-.35,-.15,.05][f];p['coat'+s].rotation_euler.y=side*[.08,.16,.12,.08,.04,0][f]
            p['coat'+s].rotation_euler.x=.12 if f==1 else 0
        elif anim in ('whip','attack','cast_ult'):
            if anim=='whip':
                crouch=[-.18,-.25,-.22,-.1,1.1,.9,.55,.2][f];twist=[-.15,-.25,-.15,.35,.9,.5,.2,0][f]
                crouch=[-.04,-.07,-.09,-.03,.04,.025,.01,0][f]
                p['root'].location.y=crouch;p['spine'].rotation_euler.y=twist;p['spine'].rotation_euler.x=[-.4,-.48,-.35,.15,0,0,0,0][f]
                p['upper1'].rotation_euler.x=[-.35,-.55,-.8,.45,-2.5,-2.1,-1.4,-.5][f];p['upper-1'].rotation_euler.x=[-.45,-.75,-1.0,.3,-2.4,-2.0,-1.3,-.5][f]
                p['fore1'].rotation_euler.x=[-.5,-.75,-.65,-.25,-.1,-.25,-.3,.04][f];p['fore-1'].rotation_euler.x=[-.4,-.65,-.6,-.2,-.1,-.25,-.3,.04][f]
                p['upper1'].rotation_euler.z=-.35*strength;p['upper-1'].rotation_euler.z=.35*strength
                p['coat1'].rotation_euler.y=.12*strength;p['coat-1'].rotation_euler.y=-.09*strength
            else:
                twist=[0,-.25,-.7,.68,.25,0][f]
                p['spine'].rotation_euler.y=twist;p['spine'].rotation_euler.x=.15*pulse
                p['upper1'].rotation_euler.x=[0,.55,1.15,-1.15,-.5,0][f]
                p['upper1'].rotation_euler.z=-.45*pulse;p['fore1'].rotation_euler.x=-.75*pulse
                p['upper-1'].rotation_euler.x=-.6*pulse;p['fore-1'].rotation_euler.x=-.4*pulse
                p['coat1'].rotation_euler.y=.18*pulse;p['coat-1'].rotation_euler.y=-.18*pulse
            if anim=='cast_ult':p['root'].location.y=-.10*pulse;p['upper-1'].rotation_euler.z=.55*pulse
        elif anim=='death':
            p['root'].rotation_euler.x=.30*q;p['root'].location.y=-.48*q
            p['spine'].rotation_euler.x=1.0*q;p['head'].rotation_euler.x=.35*q
            p['upper'+s].rotation_euler.z=-side*.36*q;p['fore'+s].rotation_euler.x=-.4*q
            p['thigh'+s].rotation_euler.x=-.70*q;p['shin'+s].rotation_euler.x=1.5*q

def action_chain(rig,anim,f):
    for ob in list(bpy.data.objects):
        if ob.name.startswith('AR1 action chain'):bpy.data.objects.remove(ob,do_unlink=True)
    bpy.context.view_layer.update()
    hit={'plant':2,'loop':2,'whip':4}[anim];n=ANIMS[anim]
    gain=1 if f==hit else (.72 if f<hit else max(.12,(n-1-f)/(n-hit)))
    mat=bpy.data.materials.get('AR1 hot copper')
    if mat is None:
        mat=bpy.data.materials.new('AR1 hot copper');mat.use_nodes=True
        bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.38,.12,.025,1)
        bs.inputs['Emission Color'].default_value=(1,.19,.012,1);bs.inputs['Emission Strength'].default_value=1
        mat['rainfall_emissive']=True
    cel.toon_materials('creature')
    # Cel's accent AOV follows this emission; impact doubles the material strength.
    for node in mat.node_tree.nodes:
        if node.type=='BSDF_PRINCIPLED':node.inputs['Emission Strength'].default_value=2 if f==hit else 1
        if node.type=='EMISSION':node.inputs['Strength'].default_value=2 if f==hit else 1
        if node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=(.32,.0608,.00384,1) if f==hit else (.16,.0304,.00192,1)
    hand=rig.pose.bones['fore1'].tail.copy()
    if anim=='whip':end=Vector((.28,-.12,2.48 if f==hit else 1.05+gain*.95))
    elif anim=='plant':end=Vector((1.12*gain,-.28,1.42 if f==hit else .9))
    else:end=Vector((1.16*gain,-.18,1.98 if f==hit else 1.3))
    trails=3 if f==hit-1 or anim=='whip' and f<3 else 1
    if f==hit:trails=2
    from bpy_extras.object_utils import world_to_camera_view
    scene=bpy.context.scene;cam=scene.camera
    right=cam.matrix_world.to_quaternion()@Vector((1,0,0));up=cam.matrix_world.to_quaternion()@Vector((0,1,0))
    aspect=scene.render.resolution_x/scene.render.resolution_y
    def projected(v,x=None,y=None):
        world=rig.matrix_world@v;uv=world_to_camera_view(scene,cam,world)
        xx=min(.94,max(.06,uv.x)) if x is None else x
        yy=min(.94,max(.08,uv.y)) if y is None else y
        world+=right*((xx-uv.x)*cam.data.ortho_scale*aspect)+up*((yy-uv.y)*cam.data.ortho_scale)
        return rig.matrix_world.inverted()@world
    for trail in range(trails):
        curve=bpy.data.curves.new('AR1 action chain','CURVE');curve.dimensions='3D';curve.bevel_depth=.013 if trail==0 else .007;curve.bevel_resolution=0;curve.resolution_u=1
        spline=curve.splines.new('POLY');spline.points.add(16)
        for j,pt in enumerate(spline.points):
            t=j/16;v=hand.lerp(end,t)
            if f==hit:
                # Two taut stretches of the same chain, pulled wide at maximum extension.
                other=rig.pose.bones['fore-1'].tail.copy() if trail else hand
                target=projected(end,x=.11 if trail else .89,y=.91 if anim=='whip' else .86)
                v=other.lerp(target,t)
            if f!=hit:v.y+=math.sin(t*math.pi)*(.28+trail*.12);v.z-=math.sin(t*math.pi)*.28
            if trail and f!=hit:v.x+=(trail-1.5)*.3*math.sin(t*math.pi);v.z-=trail*.08
            pt.co=(*projected(v),1)
        ob=bpy.data.objects.new('AR1 action chain',curve);bpy.context.collection.objects.link(ob);ob.parent=rig;curve.materials.append(mat)

def resources(boxes=None):
    import re
    path=OUT/'arpenteuse.tres';text=path.read_text(encoding='utf8')
    for anim in RENDER_ANIMS:
        n=ANIMS[anim];idx=list(ANIMS).index(anim);extid=2*idx+1
        # Rebuild the animation array with one dictionary per name; leave every other entry intact.
    arr=text.index('animations = [')+len('animations = [');close=text.rfind(']');chunk=text[arr:close]
    items=[];i=0
    while i<len(chunk):
        if chunk[i]=='{':
            st=i;depth=0;quoted=False;esc=False
            while i<len(chunk):
                c=chunk[i]
                if quoted:
                    if esc:esc=False
                    elif c=='\\\\':esc=True
                    elif c=='\"':quoted=False
                elif c=='\"':quoted=True
                elif c=='{':depth+=1
                elif c=='}':
                    depth-=1
                    if depth==0:break
                i+=1
            items.append(chunk[st:i+1])
        i+=1
    rebuilt=[];seen=set()
    for item in items:
        match=re.search(r'\"name\": &\"([^\"]+)\"',item)
        if not match:continue
        name=match.group(1)
        if name not in seen and name.split('_')[0] not in RENDER_ANIMS:
            rebuilt.append(item);seen.add(name)
    for anim in RENDER_ANIMS:
        idx=list(ANIMS).index(anim)
        for row,d in enumerate(DIRS):
            frames=[]
            for f in range(ANIMS[anim]):
                sid=10000+idx*100+row*10+f
                frames.append(f'{{\"duration\": {F60[anim][f]*FPS[anim]/60:.6g}, \"texture\": SubResource(\"{sid}\")}}')
            rebuilt.append(f'{{\"frames\": [{", ".join(frames)}], \"loop\": false, \"name\": &\"{anim}_{d}\", \"speed\": {FPS[anim]}.0}}')
    text=text[:arr]+",\n".join(rebuilt)+text[close:]
    # Replace only action atlases; all unrelated animation dictionaries remain verbatim.
    blocks=[]
    for anim in sorted(RENDER_ANIMS):
        idx=list(ANIMS).index(anim);extid=2*idx+1;l,t,r,b=boxes[anim];cw,ch=r-l,b-t
        text=re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\n(?:(?!\[).)*?atlas = ExtResource\("'+str(extid)+r'"\)(?:(?!\[).)*?(?=\[)', '', text, flags=re.S)
        for row in range(8):
            for f in range(ANIMS[anim]):
                sid=10000+idx*100+row*10+f
                blocks.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{extid}")\nregion = Rect2({f*cw}, {row*ch}, {cw}, {ch})\nmargin = Rect2({l}, {t}, {192-cw}, {192-ch})\n')
    text=text.replace('[resource]', '\n'.join(blocks)+'\n[resource]')
    text='\n'.join(line for line in text.splitlines() if not any(f'/{anim}_n.png' in line for anim in RENDER_ANIMS))+'\n'
    count=sum(1 for line in text.splitlines() if line.startswith('[ext_resource') or line.startswith('[sub_resource'))+1
    text=re.sub(r'load_steps=\d+',f'load_steps={count}',text,count=1)
    path.write_text(text,encoding='utf8')


def finish():
    boxes={}
    for anim in RENDER_ANIMS:
        n=ANIMS[anim];frames=[];bounds=[]
        for row,d in enumerate(DIRS):
            for f in range(n):
                with Image.open(RAW/anim/f'{d}_{f:02}.png') as src:
                    frames.append(src.convert('RGBA'));bounds.append(frames[-1].getchannel('A').getbbox())
        box=(max(0,min(b[0] for b in bounds)-3)//2*2,max(0,min(b[1] for b in bounds)-3)//2*2,min(192,(max(b[2] for b in bounds)+4)//2*2),min(192,(max(b[3] for b in bounds)+4)//2*2));boxes[anim]=box
        cw,ch=box[2]-box[0],box[3]-box[1]
        for suffix in ('','_e'):
            sheet=Image.new('RGBA',(cw*n,ch*8))
            for row,d in enumerate(DIRS):
                for f in range(n):
                    with Image.open(RAW/anim/f'{d}_{f:02}{suffix}.png') as src:sheet.paste(src.crop(box),(f*cw,row*ch))
            if suffix:sheet=sheet.resize(((sheet.width+1)//2,(sheet.height+1)//2),Image.Resampling.LANCZOS)
            sheet.save(OUT/f'{anim}{suffix}.png',optimize=True,compress_level=9)
    resources(boxes)
    (RAW/'packing.json').write_text(json.dumps(boxes))
    print('AR1 SHEETS PASS',sum(ANIMS[a] for a in RENDER_ANIMS)*8,flush=True)

def icons():
    sys.path.insert(0,str(ROOT/'art/tools/ui'))
    import i2_build as ui
    target=ROOT/'game/assets/sprites/icons/spells'
    for name in ('chaine','boucle','piquet','tendeur'):
        s=ui.studio('arpenteuse_'+name)
        copper=ui.surface('heat tarnished copper','#361C13','#A57046',1,.37)
        ui.disk(0,0,.87,ui.black,.10,.14)
        ui.engraving(0,0,.77,y=.015,n=32,m=ui.iron)
        # Forged interlocking links, not painted symbols.
        if name=='chaine':pts=[(-.50+i*.1,-.20,.40-i*.08) for i in range(11)]
        elif name=='boucle':pts=[(.53*math.cos(i*math.tau/22),-.20,.48*math.sin(i*math.tau/22)) for i in range(22)]
        elif name=='piquet':pts=[(-.5+i*.1,-.20,-.42) for i in range(11)]
        else:pts=[(-.64+i*.128,-.20,.12+(.14*abs(i-5))) for i in range(11)]
        for i,p in enumerate(pts):
            o=ui.torus(p,.067,.019,copper if i%4 else ui.accent);o.scale=(1.45,1,1)
            o.rotation_euler=(math.pi/2,0,math.pi/4+(i%2)*.65)
        if name=='piquet':
            ui.rod((.08,-.31,-.62),(.08,-.31,.57),.065,ui.steel)
            ui.disk(.08,.48,.12,copper,-.32,.09)
            ui.rod((-.19,-.34,.48),(.34,-.34,.48),.045,copper)
        if name=='tendeur':
            for a in (-1,1):
                ui.rod((a*.55,-.24,.26),(a*.25,-.25,-.10),.058,copper)
                ui.rod((a*.25,-.25,-.10),(a*.52,-.25,-.47),.048,copper)
            ui.disk(0,-.10,.13,ui.iron,-.25,.12);ui.jewel(0,-.10,ui.accent,r=.045,y=-.34)
        for ob in ui.meshes():
            if ob.type=='MESH' and not ob.modifiers:
                m=ob.modifiers.new('forged bevel','BEVEL');m.width=.008;m.segments=3
        s.camera.location=(.55,-10,1.9);ui.aim(s.camera,(0,0,0));s.camera.data.type='ORTHO';s.camera.data.ortho_scale=2.06
        s.render.resolution_x=256;s.render.resolution_y=256;s.eevee.taa_render_samples=24
        path=target/f'arpenteuse_{name}.png';s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        with Image.open(path) as im:im.resize((128,128),Image.Resampling.LANCZOS).save(path,optimize=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE.with_name('arpenteuse_icon_'+name+'.blend')))
    print('AR1 ICONS PASS',flush=True)

def legacy_verify():
    import hashlib,subprocess,tempfile
    report={'frames':0,'sheets':0,'clipped':[],'static':[],'bounds':{},'body_emissive_pixels':0}
    for anim in RENDER_ANIMS:
        n=ANIMS[anim]
        with Image.open(OUT/f'{anim}.png') as im:
            assert im.size==(192*n,1536) and im.mode=='RGBA'
            for row,d in enumerate(DIRS):
                hashes=set()
                for f in range(n):
                    frame=im.crop((192*f,192*row,192*(f+1),192*(row+1)));b=frame.getchannel('A').point(lambda v:255 if v>8 else 0).getbbox()
                    assert b,(anim,d,f,'empty');report['frames']+=1
                    if min(b[:2])<4 or max(b[2:])>188:report['clipped'].append([anim,d,f,b])
                    hashes.add(hashlib.sha256(frame.tobytes()).hexdigest())
                if len(hashes)!=n:report['static'].append([anim,d,len(hashes),n])
        for suf in ('',):
            with Image.open(OUT/f'{anim}{suf}.png') as im:
                assert im.size==(192*n,1536) and im.mode=='RGBA';report['sheets']+=1
    (OUT/'ar1_verification.json').write_text(json.dumps(report,indent=2))
    assert not report['clipped'],report['clipped'][:8]
    assert not report['static'],report['static'][:8]
    print('AR1 VISUAL PASS',report['frames'],flush=True)
    return
    godot=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
    # A GDScript resource serialized as .tres avoids creating any .gd/.tscn file.
    code='''extends SceneTree
func _initialize():
    var sf = load("res://assets/sprites/characters/arpenteuse/arpenteuse.tres")
    assert(sf is SpriteFrames)
    var count = 0
    assert(sf.get_animation_names().size() == 72)
    for anim in sf.get_animation_names():
        if String(anim).begins_with("death_"):
            assert(not sf.get_animation_loop(anim))
        for i in range(sf.get_frame_count(anim)):
            var tex = sf.get_frame_texture(anim, i)
            assert(tex is AtlasTexture and tex.atlas is CanvasTexture)
            assert(tex.atlas.diffuse_texture != null and tex.atlas.normal_texture != null)
            assert(tex.region.size == Vector2(192,192))
            count += 1
    assert(count == 432)
    print("AR1 LOAD RESULT: OK / 432 frames / 72 animations")
    quit()
'''
    with tempfile.TemporaryDirectory(prefix='rainfall_ar1_') as temp:
        script=Path(temp)/'check.tres';script.write_text('[gd_resource type="GDScript" format=3]\n\n[resource]\nscript/source = '+json.dumps(code)+'\n',encoding='utf8')
        for label,args in [('import',['--editor','--import','--quit']),('load',['--script',str(script)]),('sprites_test',['res://tests/sprites_test.tscn'])]:
            p=subprocess.run([godot,'--headless','--path',str(ROOT/'game')]+args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf8',errors='replace',timeout=180)
            (OUT/f'ar1_{label}.log').write_text(p.stdout,encoding='utf8')
            errs=[x for x in p.stdout.splitlines() if 'ERROR:' in x or 'SCRIPT ERROR' in x]
            report[label]={'returncode':p.returncode,'errors':errs[:8]}
            if label=='load':
                assert 'AR1 LOAD RESULT: OK' in p.stdout,p.stdout[-1500:]
                assert not errs,errs[:8]
            if label=='sprites_test':assert 'RESULT: OK' in p.stdout,p.stdout[-1500:]
            assert p.returncode==0,(label,p.returncode)
    (OUT/'ar1_verification.json').write_text(json.dumps(report,indent=2))
    print('AR1 VERIFICATION PASS',flush=True)

def contact():
    canvas=Image.new('RGBA',(1920,1420),(22,26,30,255))
    refs=['art/tools/characters/_cd_arpenteuse.png','art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/ui/_i2_contact.png']
    for i,path in enumerate(refs):
        with Image.open(ROOT/path) as src:
            im=src.convert('RGBA');im.thumbnail((376,205),Image.Resampling.LANCZOS);canvas.alpha_composite(im,(i*384+(384-im.width)//2,0))
    with Image.open(OUT/'idle.png') as src:
        for row in range(8):canvas.alpha_composite(src.crop((0,row*192,192,(row+1)*192)),(96+row*216,220))
    for i,(anim,n) in enumerate(ANIMS.items()):
        with Image.open(OUT/f'{anim}.png') as src:
            for j,f in enumerate((0,n//2,n-1)):
                frame=src.crop((f*192,2*192,(f+1)*192,3*192));canvas.alpha_composite(frame,(12+(i%3)*640+j*200,430+(i//3)*192))
    frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
    names=['chaine','boucle','piquet','tendeur'];ardent=['eclat_de_braise','cendres','brasier','nova_ardente']
    for col,(name,other) in enumerate(zip(names,ardent)):
        for row,size in enumerate((128,64)):
            for k,stem in enumerate(('arpenteuse_'+name,other)):
                tile=Image.new('RGBA',(size,size));im=Image.open(ROOT/f'game/assets/sprites/icons/spells/{stem}.png').convert('RGBA')
                im.thumbnail((int(size*.78),int(size*.78)),Image.Resampling.LANCZOS)
                tile.alpha_composite(im,((size-im.width)//2,(size-im.height)//2));tile.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS))
                canvas.alpha_composite(tile,(col*480+50+k*160,1040+row*155))
    canvas.save(ROOT/'art/tools/night/_ar1_contact.png',optimize=True)
    print('AR1 CONTACT PASS',flush=True)

def verify():
    sys.path.insert(0,str(ROOT/'art/tools/night'))
    import ar1_action_verify
    if not ar1_action_verify.verify('--contact' in sys.argv):raise RuntimeError('AR1 verification FAIL')

def run():
    OUT.mkdir(parents=True,exist_ok=True);SOURCE.parent.mkdir(parents=True,exist_ok=True)
    if '--icons' in sys.argv:icons();return
    if '--finish' in sys.argv or '--' in sys.argv and 'finish' in sys.argv:finish();return
    if '--verify' in sys.argv or '--' in sys.argv and 'verify' in sys.argv:verify();return
    if '--contact' in sys.argv:verify();return
    rig=rig_body();s=bpy.context.scene;start=1
    cel.install('creature',normals=False)
    # Keep the shared renderer, removing its obsolete normal-file enumeration in memory.
    import inspect
    code=inspect.getsource(iso_rig.render_frame).replace("('_n','_e')","('_e',)")
    exec(compile(code,'<AR1 emission-only renderer>','exec'),iso_rig.__dict__)
    s.eevee.taa_render_samples=16
    if rig is None:return
    for anim in RENDER_ANIMS:
        n=ANIMS[anim]
        s.timeline_markers.new(anim,frame=start)
        for f in range(n):
            pose(rig,anim,f,n)
            for b in rig.pose.bones:
                b.keyframe_insert('rotation_euler',frame=start+f);b.keyframe_insert('location',frame=start+f)
        start+=n+8
    s.frame_end=start;s.frame_set(1);bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    if '--source-only' in sys.argv:return
    for anim,n in ANIMS.items():
        if anim not in RENDER_ANIMS:continue
        for direction,angle in DIRS.items():
            for f in range(n):
                path=RAW/anim/f'{direction}_{f:02}.png'
                if '--reuse' in sys.argv and path.exists():continue
                rig.animation_data_clear();pose(rig,anim,f,n);rig.rotation_euler.z=angle
                action_chain(rig,anim,f)
                iso_rig.render_frame(path)
            print('AR1 ROW',anim,direction,flush=True)
    finish()
    verify()

if __name__=='__main__':run()
