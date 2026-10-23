"""BO1 Bourbe. Background Eevee only; source CD3, spatially weighted articulated rig.
Run Blender --background --python this_file [-- --reuse | --icons | --contact].
Pillow only assembles/crops/resizes and verifies Blender renders.
"""
import sys, math, json, shutil, time
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT/'art/tools/iso'), str(ROOT/'art/tools/characters'), str(ROOT/'art/tools/ui')]
import bpy
from mathutils import Vector, Matrix
import iso_rig
from PIL import Image
OUT = ROOT/'game/assets/sprites/characters/bourbe'
WORK = ROOT/'art/blender/characters/bourbe_frames'
SOURCE = ROOT/'art/blender/characters/bourbe.blend'
DIRS = list(iso_rig.DIRECTIONS)
ANIMS = dict(idle=8, run=8, slap=4, throw=4, recall=4, sink=4, rise=4, attack=4, cast=4, cast_ult=6, death=8)
ALIASES = {'attack':'slap', 'cast':'throw'}

def build_model():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/cd_bourbe.blend'))
    root = next(o for o in bpy.data.objects if o.name.startswith('BOURBE'))
    children = list(root.children_recursive)
    motte = next(o for o in children if o.name.startswith('Motte —'))
    excluded = {motte, *motte.children_recursive}
    keep = {root, *children} - excluded
    for o in list(bpy.data.objects):
        if o not in keep or o.name.startswith('Anneau allié'): bpy.data.objects.remove(o, do_unlink=True)
    root.location=(0,0,0);root.rotation_euler=(0,0,0);root.scale=(1,1,1)
    # Material response retains the approved sculpt but makes wet clay and bronze distinct.
    for m in bpy.data.materials:
        if not m.use_nodes: continue
        p=m.node_tree.nodes.get('Principled BSDF')
        if not p: continue
        if 'bronze' in m.name.lower(): p.inputs['Metallic'].default_value=1
        if 'Argile' in m.name:
            p.inputs['Coat Weight'].default_value=.28;p.inputs['Coat Roughness'].default_value=.23
        if 'Unique feu' in m.name:
            from cd_cd3_common import rgb
            p.inputs['Emission Color'].default_value=rgb('8DDBA8');p.inputs['Emission Strength'].default_value=1.4
    s=iso_rig.create_rig('CREA',192,reset=False)
    s.camera.data.shift_y=.21
    # Replace presentation lighting with the shared boss studio.
    for o in list(s.objects):
        if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
    for name,kind,loc,power,color,size in [('warm key','AREA',(-3,-4,6),480,(1,.76,.53),3),('cold fill','AREA',(4,-1,3),170,(.50,.66,.85),3),('wet rim','AREA',(1,3,4),430,(.60,.76,.84),2)]:
        d=bpy.data.lights.new(name,kind);d.energy=power;d.color=color;d.shape='DISK';d.size=size
        o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.65))-o.location).to_track_quat('-Z','Y').to_euler()
    s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.18,.18,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.3
    s.view_layers[0].use_pass_normal=True;s.view_layers[0].use_pass_emit=True
    # Bake the CD3 surface modifiers once before assigning deform weights.
    meshes=[]
    for o in list(root.children_recursive):
        if o.type not in {'MESH','CURVE'}:continue
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        bpy.ops.object.convert(target='MESH');o=bpy.context.object
        world=o.matrix_world.copy();o.data.transform(world);o.matrix_world=Matrix.Identity(4);o.parent=root
        meshes.append(o)
    data=bpy.data.armatures.new('Bourbe tendons');rig=bpy.data.objects.new('Bourbe_Rig',data);s.collection.objects.link(rig);rig.parent=root
    bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
    segments={'pelvis':((0,0,.33),(0,0,.58),None), 'chest':((0,0,.58),(0,0,1.02),'pelvis'), 'head':((0,0,1.02),(0,0,1.30),'chest')}
    for side,sign in [('L',-1),('R',1)]:
        segments['arm.'+side]=((sign*.29,0,.94),(sign*.41,-.05,.65),'chest')
        segments['hand.'+side]=((sign*.41,-.05,.65),(sign*.45,-.17,.27),'arm.'+side)
        segments['leg.'+side]=((sign*.18,0,.43),(sign*.21,0,.14),'pelvis')
        segments['foot.'+side]=((sign*.21,0,.14),(sign*.21,-.24,.045),'leg.'+side)
    for name,(a,b,parent) in segments.items():
        bone=data.edit_bones.new(name);bone.head=a;bone.tail=b
        if parent:bone.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    def distance(p,a,b):
        a,b=Vector(a),Vector(b);v=b-a;t=max(0,min(1,(p-a).dot(v)/v.length_squared));return (p-a-t*v).length
    for o in meshes:
        groups={k:o.vertex_groups.new(name=k) for k in segments}
        for v in o.data.vertices:
            p=v.co
            side='L' if p.x<0 else 'R'
            # A continuous field avoids a hard skinning seam at the armpits.
            names=['pelvis','chest','head','arm.'+side,'hand.'+side,'leg.'+side,'foot.'+side]
            if o.name.startswith(('Bande de bronze','Rivet de cerclage','Strates du front')):
                z=sum(q.co.z for q in o.data.vertices)/len(o.data.vertices) if v.index==0 else rigid_z
                rigid_z=z;names=['pelvis' if z<.6 else 'head' if z>1.08 else 'chest']
            weights={k:1/max(.018,distance(p,*segments[k][:2]))**4 for k in names};total=sum(weights.values())
            for k,w in weights.items():
                if w/total>.001:groups[k].add([v.index],w/total,'REPLACE')
        mod=o.modifiers.new('Tendons de racines / skin','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=True
    iso_rig.bake_ao_shadows(root)
    rig.show_in_front=True;s.eevee.taa_render_samples=8;s.render.threads_mode='FIXED';s.render.threads=8
    s['ground_pivot_px']=[96,136.32];s['render_px_per_u']=iso_rig.R
    s['BO1']='CD3 approved sculpt; cold green follet; articulated wet clay, root tendons, broken bronze; no ground shadow'
    for anim,n in ANIMS.items():
        rig.animation_data_clear()
        for f in range(n):
            pose(rig,anim,f,n)
            for b in rig.pose.bones:
                b.keyframe_insert('rotation_euler',frame=f+1);b.keyframe_insert('location',frame=f+1);b.keyframe_insert('scale',frame=f+1)
        rig.animation_data.action.name='bourbe_'+anim;rig.animation_data.action.use_fake_user=True
    rig.animation_data_clear();pose(rig,'idle',0,8)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    return root,rig

def pose(rig,anim,f,n):
    anim=ALIASES.get(anim,anim);t=f/max(1,n-1);phase=f/n*math.tau
    for b in rig.pose.bones:b.rotation_mode='XYZ';b.rotation_euler=(0,0,0);b.location=(0,0,0);b.scale=(1,1,1)
    def rot(name,x=0,y=0,z=0):rig.pose.bones[name].rotation_euler=(x,y,z)
    pelvis=rig.pose.bones['pelvis'];chest=rig.pose.bones['chest']
    if anim=='idle':
        chest.scale=(1+.018*math.sin(phase),1+.025*math.sin(phase),1+.012*math.sin(phase));rot('chest',.025*math.cos(phase),0,.018*math.sin(phase));rot('head',.022*math.cos(phase),.035*math.sin(phase),0)
        rot('arm.L',.045*math.sin(phase+.6),0,-.03);rot('arm.R',-.05*math.sin(phase-.6),0,.04)
    elif anim=='run':
        pelvis.location.y=.025*abs(math.sin(phase));rot('chest',.12+.035*math.cos(phase),.025*math.cos(phase),.08*math.sin(phase))
        for side,sgn in [('L',1),('R',-1)]:
            rot('leg.'+side,.40*sgn*math.sin(phase),0,0);rot('foot.'+side,-.15*sgn*math.sin(phase)+.16*max(0,sgn*math.cos(phase)),0,0)
            rot('arm.'+side,-.33*sgn*math.sin(phase),0,.05*sgn);rot('hand.'+side,-.1-.16*max(0,sgn*math.sin(phase)),0,0)
    elif anim=='slap':
        # The broad hand crosses the front on exact frame N/2.
        rot('chest',.06,0,[.18,.40,-.48,0][f]);rot('arm.R',[-.2,-1.15,-1.10,0][f],0,[-.15,-.65,.8,0][f]);rot('hand.R',[-.2,-.6,.25,0][f],0,0)
        rot('arm.L',-.25,0,-.15)
    elif anim=='throw':
        rot('chest',[-.1,-.20,.22,0][f],0,[.1,.2,-.25,0][f]);rot('arm.R',[-.6,-1.55,-1.30,0][f],0,[.1,.25,-.25,0][f]);rot('hand.R',[-.3,-.65,.15,0][f])
        rot('arm.L',-.35,0,-.3)
    elif anim=='recall':
        v=[.35,1,.65,0][f];rot('arm.L',-.9*v,0,-.8*v);rot('arm.R',-.9*v,0,.8*v);rot('hand.L',-.5*v);rot('hand.R',-.5*v);chest.scale=(1+.08*v,1+.04*v,1)
    elif anim in ('sink','rise','cast_ult','death'):
        v=t if anim in ('sink','cast_ult','death') else 1-t
        if anim=='cast_ult':v=max(0,(t-.15)/.85)
        pelvis.location.y=-.36*v;pelvis.scale=(1+.30*v,1-.78*v,1+.23*v)
        rot('chest',.30*v);rot('arm.L',-.65*v,0,-.7*v);rot('arm.R',-.65*v,0,.7*v)
        if anim=='death':pelvis.scale=(1+.65*v,1-.94*v,1+.5*v);rot('head',.7*v);rot('hand.L',.6*v);rot('hand.R',.6*v)
    bpy.context.view_layer.update()

def resources():
    ext=[];subs=[];animations=[]
    for i,(anim,n) in enumerate(ANIMS.items()):
        eid=i*2+1;cid='c'+str(i)
        for k,suffix in enumerate(('','_n')):ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/bourbe/{anim}{suffix}.png" id="{eid+k}"]')
        subs.append(f'[sub_resource type="CanvasTexture" id="{cid}"]\ndiffuse_texture = ExtResource("{eid}")\nnormal_texture = ExtResource("{eid+1}")')
        for row,d in enumerate(DIRS):
            frames=[]
            for f in range(n):
                aid=f'a{i}_{row}_{f}';subs.append(f'[sub_resource type="AtlasTexture" id="{aid}"]\natlas = SubResource("{cid}")\nregion = Rect2({f*192}, {row*192}, 192, 192)')
                frames.append('{"duration": 1.0, "texture": SubResource("'+aid+'")}')
            speed=8 if anim=='idle' else 12
            animations.append('{"frames": ['+', '.join(frames)+f'], "loop": {str(anim in ("idle","run")).lower()}, "name": &"{anim}_{d}", "speed": {speed}.0'+'}')
    (OUT/'bourbe.tres').write_text(f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(subs)+1} format=3]\n\n'+'\n\n'.join(ext+subs)+'\n\n[resource]\nanimations = ['+',\n'.join(animations)+']\n')

def render_actor():
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    # Back-facing cells have no visible follet, but their aligned emission atlas
    # still requires a real black pass. The shared helper normally omits it.
    optimize=iso_rig.optimize_png
    def preserve_pass(path,*args,**kwargs):
        if Path(path).stem.endswith('_e'):return (0,0,192,192)
        return optimize(path,*args,**kwargs)
    iso_rig.optimize_png=preserve_pass
    root,rig=build_model()
    refresh=sys.argv[sys.argv.index('--refresh')+1].split(',') if '--refresh' in sys.argv else []
    for anim,n in ANIMS.items():
        if anim in ALIASES:
            for suffix in ('','_n','_e'):shutil.copyfile(OUT/(ALIASES[anim]+suffix+'.png'),OUT/(anim+suffix+'.png'))
            continue
        for row,d in enumerate(DIRS):
            for f in range(n):
                p=WORK/anim/f'{d}_{f:02}.png'
                if '--reuse' in sys.argv and anim not in refresh and all(p.with_name(p.stem+x+'.png').exists() for x in ('','_n','_e')):continue
                pose(rig,anim,f,n);root.rotation_euler.z=iso_rig.DIRECTIONS[d]
                for attempt in range(4):
                    try:
                        iso_rig.render_frame(p);break
                    except PermissionError:
                        if attempt==3:raise
                        time.sleep(.3)
        for suffix in ('','_n','_e'):
            sheet=Image.new('RGBA',(n*192,8*192))
            for row,d in enumerate(DIRS):
                for f in range(n):
                    with Image.open(WORK/anim/f'{d}_{f:02}{suffix}.png') as im:
                        cell=im.convert('RGBA')
                    if suffix:
                        with Image.open(WORK/anim/f'{d}_{f:02}.png') as diffuse:cell.putalpha(diffuse.getchannel('A'))
                    sheet.paste(cell,(f*192,row*192))
            sheet.save(OUT/(anim+suffix+'.png'),optimize=True)
        print('BO1 PASS '+anim,flush=True)
    resources()
    (OUT/'bo1_manifest.json').write_text(json.dumps({'status':'PASS','source':'cd_bourbe.blend','cell':192,'pivot':[96,136.32],'px_per_u':iso_rig.R,'directions':DIRS,'animations':ANIMS,'impact_frame':{'slap':2,'attack':2,'throw':2,'cast':2,'recall':2,'sink':2,'cast_ult':3},'accent':'#8DDBA8','lot':'1/3: actor + spell icons; familiars and ground VFX reserved for following lots'},indent=2))

def icons():
    import i2_build as kit
    from cd_cd3_common import rgb
    dest=ROOT/'game/assets/sprites/icons/spells';dest.mkdir(parents=True,exist_ok=True)
    for name in ('gifle_de_vase','detacher','rappel','bourbier'):
        s=kit.studio('BO1_'+name);s.eevee.taa_render_samples=16
        iron=kit.surface('engraved black iron','#101719','#353C3A',1,.48)
        bronze=kit.surface('worn verdigris bronze','#253F37','#718879',1,.40)
        mud=kit.surface('wet layered clay','#161E24','#39434A',0,.32)
        rootmat=kit.surface('root tendons','#20251D','#535343',0,.69)
        glow=kit.mat('#233D2E',.5,0,'#8DDBA8',1.4)
        back=kit.disk(0,0,.86,iron,.12,.13)
        for j in range(15):
            a=j*math.tau/15
            kit.rod([.76*math.cos(a),.035,.76*math.sin(a)],[.66*math.cos(a+.035),.035,.66*math.sin(a+.035)],.008,bronze)
        def path(points,r=.025,m=bronze):return kit.smooth_curve(points,r,m)
        def clod(x,z,r=.17):
            ob=kit.bead(x,z,r,y=-.16,m=mud);return ob
        if name=='gifle_de_vase':
            kit.disk(-.10,-.1,.25,mud,-.17,.15)
            for j in range(4):path([(-.31+j*.13,-.24,.0),(-.34+j*.15,-.25,.28),(-.35+j*.16,-.22,.44-(j==3)*.12)],.056,mud)
            path([(-.54,-.34,-.37),(-.23,-.36,-.50),(.20,-.35,-.43),(.53,-.29,-.13)],.022,bronze)
            path([(-.04,-.35,-.20),(.04,-.37,-.01),(.00,-.35,.16)],.019,glow)
        elif name=='detacher':
            clod(-.31,-.24,.26);clod(.30,.28,.19)
            path([(-.28,-.36,-.15),(-.03,-.37,.0),(.13,-.35,.20)],.024,rootmat)
            path([(-.34,-.41,-.27),(-.27,-.42,-.12),(-.31,-.40,-.03)],.018,glow)
            path([(.27,-.35,.19),(.32,-.36,.29),(.29,-.33,.37)],.018,glow)
            for x,z,r in [(.02,-.13,.045),(.08,.07,.035),(.18,.05,.027)]:clod(x,z,r)
        elif name=='rappel':
            kit.disk(0,0,.20,mud,-.2,.18)
            for j in range(3):
                a=j*math.tau/3+.3;x=.52*math.cos(a);z=.52*math.sin(a);clod(x,z,.13)
                path([(x,-.24,z),(x*.7-z*.15,-.29,z*.7+x*.15),(x*.30,-.32,z*.30)],.027,bronze)
                path([(x*.42,-.36,z*.42),(0,-.38,0)],.017,glow)
        else:
            for j in range(3):
                r=.24+j*.17;path([(r*math.cos(a),-.22,.68*r*math.sin(a)-.18) for a in [i*math.tau/40 for i in range(41)]],.025,bronze)
            for j in range(4):
                x=-.25+j*.15;path([(x,-.24,-.16),(x-.03,-.26,.08),(x+.04,-.25,.32),(x+.015,-.23,.50-abs(x))],.04,mud)
            path([(-.025,-.36,-.12),(.025,-.36,.07),(-.015,-.34,.25),(.03,-.30,.37)],.022,glow)
        for ob in kit.meshes():
            if ob.type=='MESH' and not any(m.type=='BEVEL' for m in ob.modifiers):
                b=ob.modifiers.new('worn bevel','BEVEL');b.width=.009;b.segments=3
        s.camera.location=(.30,-10,2.2);kit.aim(s.camera,(0,0,0));s.camera.data.type='ORTHO';s.camera.data.ortho_scale=2.25
        s.render.resolution_x=256;s.render.resolution_y=256;s.render.resolution_percentage=100;s.render.film_transparent=True
        s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
        p=ROOT/f'art/blender/characters/bourbe_icon_{name}.png';s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
        with Image.open(p) as im:im.convert('RGBA').resize((128,128),Image.Resampling.LANCZOS).save(dest/f'bourbe_{name}.png',optimize=True)
        bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'art/blender/characters/bourbe_icon_{name}.blend'))
        print('BO1 PASS icon '+name,flush=True)

def contact():
    rows=[]
    for anim,n in ANIMS.items():
        with Image.open(OUT/(anim+'.png')) as sheet:
            row=Image.new('RGBA',(8*192,192))
            for y in range(8):row.paste(sheet.crop(((n//2)*192,y*192,(n//2+1)*192,(y+1)*192)),(y*192,0))
            rows.append(row)
    # Full front-facing motion strips verify anticipation, impact and recovery.
    for anim in ('run','slap','throw','recall','sink','rise','cast_ult','death'):
        with Image.open(OUT/(anim+'.png')) as im:
            row=Image.new('RGBA',(1536,192));row.paste(im.crop((0,384,im.width,576)),(0,0));rows.append(row)
    dest=ROOT/'game/assets/sprites/icons/spells'
    names=['bourbe_gifle_de_vase','bourbe_detacher','bourbe_rappel','bourbe_bourbier','eclat_de_braise','nova_ardente','cendres','brasier','braises_errantes','pilier_de_flamme','pluie_de_meteores','phenix']
    with Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png') as im:frame=im.convert('RGBA')
    for size in (128,64):
        row=Image.new('RGBA',(1536,128))
        for j,name in enumerate(names):
            with Image.open(dest/(name+'.png')) as im:icon=im.convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
            med=Image.new('RGBA',(size,size));med.alpha_composite(icon);med.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS));row.paste(med,(j*size,0))
        rows.append(row)
    board=Image.new('RGBA',(1536,sum(r.height for r in rows)),(23,29,32,255));y=0
    for row in rows:board.alpha_composite(row,(0,y));y+=row.height
    board.convert('RGB').save(ROOT/'art/tools/night/_bo1_contact.png',optimize=True)
    print('BO1 PASS contact',flush=True)

if __name__=='__main__':
    if '--contact' in sys.argv:contact()
    elif '--icons' in sys.argv:icons()
    else:render_actor();icons();contact()
