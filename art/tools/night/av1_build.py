"""AV1: approved Averse design, hierarchical animation rig, CREA atlases and PBR spell emblems.
Background Blender only. --source-only / --resume / --icons-only / --verify.
Pillow is used solely for resizing, assembly and pixel verification.
"""
import sys, math, json, hashlib, re, subprocess
from pathlib import Path
sys.dont_write_bytecode=True
import bpy
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/characters'),str(ROOT/'art/tools/iso')]
import iso_rig
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel
from ardent_iso_build import worn, mesh, rod, rings, bead, empty
from cd_cd1_common import block, cyl, tube, rgb
from PIL import Image
DEST=ROOT/'game/assets/sprites/characters/averse'
SOURCE=ROOT/'art/blender/characters/averse.blend'
WORK=ROOT/'art/blender/characters/averse_frames'
ICONS=ROOT/'game/assets/sprites/icons/spells'
ANIMS={'idle':8,'run':8,'cast':5,'wave':6,'crue':9,'stumble':3,'attack':6,'cast_ult':8,'death':8}
DIRS=iso_rig.DIRECTIONS
FPS={'idle':8,'run':14,'cast':12,'wave':12,'crue':12,'stumble':10,'attack':12,'cast_ult':12,'death':10}
F60={'attack':[3,3,2,2,5,5],'wave':[4,4,4,5,9,9],'cast':[5,5,4,7,7],'crue':[5,5,4,4,4,10,10,9,9]}

def parent_keep(o,p):
    m=o.matrix_world.copy();o.parent=p;o.matrix_world=m

def source():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/cd_averse.blend'))
    s=bpy.context.scene
    root=next(o for o in s.objects if o.name.startswith('Averse /'))
    root.name='Averse';root.location=(0,0,0);root.rotation_euler=(0,0,0)
    keep={root,*root.children_recursive}
    for o in list(s.objects):
        if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
    for o in keep:
        o.hide_render=False;o.animation_data_clear()
        if o.type=='MESH':
            for mod in o.modifiers:
                if mod.type=='SUBSURF':mod.levels=1;mod.render_levels=1
        if o.type=='CURVE':o.data.bevel_resolution=1;o.data.resolution_u=6
    bpy.context.view_layer.update()
    # Freeze presentation modifiers once, preserving the artist's approved geometry.
    deps=bpy.context.evaluated_depsgraph_get()
    for o in list(root.children_recursive):
        if o.type not in ('MESH','CURVE'):continue
        evaluated=o.evaluated_get(deps)
        data=bpy.data.meshes.new_from_object(evaluated,depsgraph=deps)
        new=bpy.data.objects.new(o.name+'__baked',data);s.collection.objects.link(new)
        new.parent=o.parent;new.matrix_world=o.matrix_world.copy()
        name=o.name;bpy.data.objects.remove(o,do_unlink=True);new.name=name
    bpy.context.view_layer.update()
    body=bpy.data.objects['Body'];legs=[]
    for side in (-1,1):
        leg=empty('Leg L' if side<0 else 'Leg R',(side*.09,0,.62),root)
        bpy.context.view_layer.update()
        for o in list(body.children):
            if o.name.startswith(('Trouser leg','Shaped boot')):
                if o.type=='MESH':x=sum((o.matrix_world@v.co).x for v in o.data.vertices)/len(o.data.vertices)
                else:x=o.matrix_world.translation.x
                if x*side>0:parent_keep(o,leg)
        legs.append(leg)
    torso=empty('Torso sway',(0,0,.90),root);bpy.context.view_layer.update()
    for o in list(root.children):
        if o not in [torso,*legs]:parent_keep(o,torso)
    jar=bpy.data.objects['Amphora'];arms=[bpy.data.objects['Arm L'],bpy.data.objects['Arm R']]
    hood=bpy.data.objects['Hood']
    # Hand-held bronze rain nozzle, repeating the amphora's patina and cyan sight glass.
    bronze=worn('AV1 hammered bronze fittings','293D36','897650',1,.43)
    black=worn('AV1 wet blackened iron','13191C','454A49',.7,.5)
    water=bpy.data.materials.get('Single accent / cyan water')
    if water is None:water=next(m for m in bpy.data.materials if 'cyan water' in m.name)
    nozzle=empty('Rain needle nozzle',(.09,-.18,-.48),arms[1])
    cyl('Tapered bronze rain spout',(0,.02,0),(0,-.16,.04),.022,bronze,nozzle,16,r2=.009)
    for yy in (-.01,-.07):cyl('Nozzle rib',(0,yy,0),(0,yy-.012,.004),.029,black,nozzle,16)
    bead('Cyan pressure aperture',(0,-.172,.044),(.008,.005,.008),water,nozzle)
    # Back-facing water is the resource mask. Store its normalized geometry range explicitly.
    level=next(o for o in jar.children if o.name.startswith('Water level'))
    level['resource_mask']='cyan _e sight glass; normalized fill is bottom-to-top in local Z'
    root.scale=(.87,.87,.87)
    s=iso_rig.create_rig('CREA',192,reset=False);s.camera.data.shift_y=.21
    s.view_layers[0].use_pass_normal=False;s.view_layers[0].use_pass_emit=True
    s.eevee.taa_render_samples=12;s.render.threads_mode='FIXED';s.render.threads=8
    # Parallel studio rays keep all atlas cells under exactly the same illumination.
    for o in list(s.objects):
        if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
    for name,loc,energy,color in [('AV1 warm studio key',(-4,-6,8),2.5,(1,.76,.53)),('AV1 cool studio rim',(4,3,5),1.3,(.50,.66,.85))]:
        bpy.ops.object.light_add(type='SUN',location=loc);o=bpy.context.object;o.name=name;o.data.energy=energy;o.data.color=color;o.data.angle=.15
        o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    s.world.color=(.18,.18,.18)
    iso_rig.bake_ao_shadows(root)
    rig=[torso,*legs,*arms,hood,jar]
    rest={o.name:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in rig}
    manifest={};start=1
    for anim,n in ANIMS.items():
        s.timeline_markers.new(anim,frame=start);manifest[anim]={'start':start,'frames':n,'fps':FPS[anim],'loop':anim in ('idle','run')}
        for i in range(n):
            pose(anim,i,n,rig,rest)
            for o in rig:
                o.keyframe_insert('location',frame=start+i);o.keyframe_insert('rotation_euler',frame=start+i);o.keyframe_insert('scale',frame=start+i)
        start+=n+4
    s['animation_manifest']=json.dumps(manifest);s['render_px_per_u']=iso_rig.R;s['ground_pivot_px']=[96,136.32]
    s['AV1_notes']='Approved CD amphora and gaunt hood retained. Weighted asymmetric gait, separate leg pivots, rain nozzle. Cyan sight glass emission is water resource mask. Attack impact index 3/6.'
    s.frame_start=1;s.frame_end=start-5;s.render.fps=12;s.frame_set(1)
    root.rotation_euler=(0,0,0)
    bpy.context.preferences.filepaths.save_version=0;SOURCE.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    return root,manifest

def pose(anim,i,n,rig,rest):
    torso,ll,lr,al,ar,hood,jar=rig
    for o in rig:o.location,o.rotation_euler,o.scale=[v.copy() for v in rest[o.name]]
    t=math.tau*i/n;p=i/(n-1);pulse=math.sin(math.pi*p)
    torso.rotation_euler.x=.025;torso.location.z+=.006*math.sin(t)
    hood.rotation_euler.x=.025*math.sin(t+.4)
    jar.rotation_euler.x=-.018*math.sin(t+.7)
    if anim=='run':
        torso.rotation_euler.x=.12;torso.rotation_euler.z=.045*math.sin(t);torso.location.z+=.022*math.cos(2*t)
        for j,leg in enumerate((ll,lr)):
            a=t+j*math.pi;leg.rotation_euler.x=.48*math.sin(a);leg.location.z+=.06*max(0,math.cos(a))
        al.rotation_euler.x=-.38*math.sin(t);ar.rotation_euler.x=.28*math.sin(t)
        hood.rotation_euler.x=-.04+.025*math.cos(t);jar.rotation_euler.x=-.05+.045*math.sin(t-.8)
    elif anim in ('cast','wave','crue','cast_ult','attack'):
        if anim=='attack':
            # Dip toward the back amphora, blade smear, held impact and readable recovery.
            if i<=1:k=[.42,1.0][i];ar.rotation_euler.x=.75*k;jar.rotation_euler.x=-.48*k;torso.rotation_euler.x=-.22*k;torso.rotation_euler.z=-.18*k
            elif i==2:ar.rotation_euler.x=-2.15;ar.rotation_euler.z=.55;al.rotation_euler.x=-.72;jar.rotation_euler.x=.45;torso.rotation_euler.z=.38
            elif i==3:ar.rotation_euler.x=-1.85;ar.rotation_euler.z=.18;al.rotation_euler.x=-.32;torso.rotation_euler.x=-.32;torso.rotation_euler.z=.20
            else:k=(i-3)/2;ar.rotation_euler.x=-1.85*(1-k);ar.rotation_euler.z=.18*(1-k);jar.rotation_euler.x=-.08*k;torso.rotation_euler.x=-.32*(1-k)
        elif anim=='cast':
            vals=[-.45,-.75,-1.05,-.15,.10][i];ar.rotation_euler.x=vals;al.rotation_euler.x=-.55 if i<3 else -.18;jar.rotation_euler.x=[-.85,-1.05,-.78,.06,0][i];torso.rotation_euler.x=.24 if i<3 else -.05
        elif anim=='wave':
            if i<2: k=[.5,1][i];torso.rotation_euler.x=.35*k;torso.location.z-=.08*k;jar.rotation_euler.x=-.65*k
            elif i==2:ar.rotation_euler.x=-2.05;al.rotation_euler.x=-1.8;jar.rotation_euler.x=.55;torso.rotation_euler.z=.28
            elif i==3:ar.rotation_euler.x=-1.8;al.rotation_euler.x=-1.65;ar.rotation_euler.z=.18;al.rotation_euler.z=-.18;jar.rotation_euler.x=1.0;torso.rotation_euler.x=-.16
            else:k=(i-3)/2;ar.rotation_euler.x=-1.8*(1-k);al.rotation_euler.x=-1.65*(1-k);jar.rotation_euler.x=1.0*(1-k);torso.location.z-=.06*(1-k)
            al.scale.x=ar.scale.x=1.20 if i<=3 else 1.0
        else:
            if anim=='crue':
                angles=[-.15,-.65,-1.15,-1.65,-2.15,-2.7,-2.15,-1.0,-.15];lift=[0,.18,.38,.58,.42,.1,0,0,0][i];ar.rotation_euler.x=angles[i];al.rotation_euler.x=angles[i]*.83;jar.rotation_euler.x=[-.35,-.85,-1.15,-1.55,.15,1.55,.8,.15,-.08][i];torso.location.z+=lift;torso.rotation_euler.x=-.12 if i<5 else -.30 if i==5 else -.12*(8-i)/3;hood.rotation_euler.x=-.12 if i<5 else .08
                if i==5:jar.scale*=1.15
            else:
                for side,arm in [(-1,al),(1,ar)]:arm.rotation_euler.x=-1.55*pulse;arm.rotation_euler.y=side*.3*pulse
                torso.rotation_euler.x=-.17*pulse;torso.location.z-=.075*pulse;hood.rotation_euler.x=-.20*pulse;jar.rotation_euler.x=.2*pulse
    elif anim=='stumble':
        k=[.15,1,.35][i];torso.rotation_euler.x=.42*k;torso.rotation_euler.y=-.17*k;torso.location.z-=.10*k
        al.rotation_euler.x=-.80*k;ar.rotation_euler.x=-.60*k;ll.rotation_euler.x=-.38*k;lr.rotation_euler.x=.28*k;jar.rotation_euler.x=.16*k
    elif anim=='death':
        # Knees buckle first, then collapse across the grounded amphora; no floating final corpse.
        k=p*p*(3-2*p);torso.location.z-=.63*k;torso.location.y+=.11*k
        torso.rotation_euler.x=.86*k;torso.rotation_euler.y=.34*k
        ll.rotation_euler.x=-1.05*k;lr.rotation_euler.x=-.88*k
        ll.location.z-=.37*k;lr.location.z-=.37*k
        al.rotation_euler.x=-.55*k;ar.rotation_euler.x=-.32*k;jar.rotation_euler.x=-.20*k;hood.rotation_euler.x=.25*k

    if anim in F60:
        impact={'attack':3,'wave':3,'cast':2,'crue':5}[anim]
        k=1 if i<=impact else max(0,1-(i-impact)/(n-1-impact))
        al.rotation_euler.z-=.65*k;ar.rotation_euler.z+=.65*k
        torso.rotation_euler.x*=1.65;torso.rotation_euler.z*=1.8
        if anim=='attack':
            jar.location.y+=[.10,.20,-.22,-.32,-.12,0][i]
            jar.rotation_euler.x*=1.5
        if anim=='wave':
            jar.location.y+=[.15,.28,-.20,-.40,-.18,0][i]
            jar.rotation_euler.x*=1.65
            jar.location.z+=.14*k
        if anim=='cast':
            jar.location.y-=[.10,.25,.34,.15,0][i]
            jar.rotation_euler.x=abs(jar.rotation_euler.x)*1.65
        if anim=='crue':
            torso.location.z=rest[torso.name][0].z
            jar.location.z+=[.20,.42,.65,.82,.72,.40,.22,.10,0][i]
            jar.location.x-=.22*k;jar.location.y-=.22*k
            if i==5:jar.scale=rest[jar.name][2]*1.35
            if i==8:
                torso.rotation_euler.x=.12;ll.rotation_euler.x=.35;lr.rotation_euler.x=-.35
                al.rotation_euler.x=-.28;ar.rotation_euler.x=.24

def posed_mesh(root,name):
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
    verts=[];faces=[];matids=[];mats=[]
    for o in root.children_recursive:
        if o.type!='MESH' or o.hide_render:continue
        ev=o.evaluated_get(deps);data=ev.to_mesh();offset=len(verts);m=ev.matrix_world
        verts.extend(tuple(m@v.co) for v in data.vertices)
        indices=[]
        for mat in data.materials:
            if mat not in mats:mats.append(mat)
            indices.append(mats.index(mat))
        for poly in data.polygons:
            faces.append(tuple(offset+j for j in poly.vertices));matids.append(indices[poly.material_index] if indices else 0)
        ev.to_mesh_clear()
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    for mat in mats:data.materials.append(mat)
    for poly,idx in zip(data.polygons,matids):poly.material_index=idx;poly.use_smooth=True
    return data

def atlases():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):dst.scenes=src.scenes
    s=dst.scenes[0];s.compositing_node_group=None;bpy.context.window.scene=s
    root=bpy.data.objects['Averse']
    cel.toon_materials('creature');bpy.context.view_layer.update()
    manifest=json.loads(s['animation_manifest'])
    s.frame_set(1)
    rig=[bpy.data.objects[k] for k in ('Torso sway','Leg L','Leg R','Arm L','Arm R','Hood','Amphora')]
    rest={o.name:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in rig}
    for anim in F60:
        start=manifest[anim]['start'];manifest[anim]['frames']=ANIMS[anim]
        for f in range(ANIMS[anim]):
            pose(anim,f,ANIMS[anim],rig,rest)
            for o in rig:
                for prop in ('location','rotation_euler','scale'):o.keyframe_insert(prop,frame=start+f)
    s['animation_manifest']=json.dumps(manifest)
    s.frame_set(1);bpy.context.preferences.filepaths.save_version=0
    basis=s.camera.rotation_euler.to_matrix();unit=192/iso_rig.R
    DEST.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    originals=[o for o in root.children_recursive if o.type=='MESH']
    for anim,n in ANIMS.items():
        if '--resume' in sys.argv and anim not in ('attack','wave','cast','crue'):continue
        # The four requested action atlases are always refreshed under --resume.
        s['iso_frame']=[n*192,1536]
        copies=[];meshes=[]
        for o in originals:o.hide_render=False
        for f in range(n):
            s.frame_set(manifest[anim]['start']+f);root.rotation_euler.z=0
            bpy.context.view_layer.update()
            effects=[]
            impact={'attack':3,'wave':3,'cast':2,'crue':5}[anim]
            water=bpy.data.materials.get('AV1 action cyan')
            if water is None:
                water=bpy.data.materials.new('AV1 action cyan');water.use_nodes=True
                bs=water.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.02,.35,.46,1)
                bs.inputs['Emission Color'].default_value=(.05,.75,1,1);bs.inputs['Emission Strength'].default_value=1.0
                water['rainfall_emissive']=True
                cel.toon_materials('creature');bpy.context.view_layer.update()
            if f in (impact-1,impact) or (anim=='crue' and f<4):
                before=set(bpy.data.objects)
                if anim=='crue' and f<4:
                    for ghost in range(2):
                        jar=max((o for o in bpy.data.objects['Amphora'].children_recursive if o.type=='MESH'),key=lambda o:len(o.data.vertices));ev=jar.evaluated_get(bpy.context.evaluated_depsgraph_get())
                        gm=bpy.data.meshes.new_from_object(ev);gm.materials.clear()
                        ghostmat=bpy.data.materials.get('AV1 translucent jar ghost')
                        if ghostmat is None:
                            ghostmat=bpy.data.materials.new('AV1 translucent jar ghost');ghostmat.use_nodes=True;ghostmat['cel_done']=True
                            nt=ghostmat.node_tree;nt.nodes.clear();out=nt.nodes.new('ShaderNodeOutputMaterial');mix=nt.nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=.20
                            tr=nt.nodes.new('ShaderNodeBsdfTransparent');em=nt.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(.03,.42,.55,1)
                            nt.links.new(tr.outputs[0],mix.inputs[1]);nt.links.new(em.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],out.inputs['Surface'])
                        gm.materials.append(ghostmat)
                        go=bpy.data.objects.new('Amphora rising ghost',gm);s.collection.objects.link(go);go.parent=root
                        go.matrix_world=jar.matrix_world.copy();go.location.z-=(ghost+1)*.14;go.scale*=.96-ghost*.06
                    for j in range(5):bead('Ascending cyan drop',(-.38+j*.18,-.12,.9+f*.10+j*.08),(.026,.026,.065),water,root)
                else:
                    reach=.66 if anim=='crue' else .54
                    for j in range(3 if f==impact-1 else 2):
                        pts=[(.40*math.cos(k*math.pi/12+j*.19),-.18-reach*math.sin(k*math.pi/12+j*.19),.90+.22*math.sin(k*math.pi/12)) for k in range(13)]
                        if anim=='cast':pts=[(.18,-.38,.88-k*.052) for k in range(13)]
                        tube('Water action arc',pts,.015 if f==impact-1 else .025,water,root)
                effects=list(set(bpy.data.objects)-before)
            for ob in effects:
                if ob.type=='CURVE':
                    bpy.context.view_layer.update()
                    deps=bpy.context.evaluated_depsgraph_get()
                    md=bpy.data.meshes.new_from_object(ob.evaluated_get(deps))
                    replacement=bpy.data.objects.new(ob.name+' mesh',md);s.collection.objects.link(replacement)
                    replacement.parent=root;replacement.matrix_world=ob.matrix_world.copy()
                    ob.hide_render=True
                    effects.append(replacement)
            print('BUILD',anim,f,flush=True)
            data=posed_mesh(root,anim+str(f));meshes.append(data)
            boost=(2.5 if anim=='crue' else 2.0) if f==impact else 1.0
            if boost>1:
                for mi,mat in enumerate(list(data.materials)):
                    if not mat.use_nodes:continue
                    nodes=[nd for nd in mat.node_tree.nodes if nd.type=='BSDF_PRINCIPLED' and nd.inputs['Emission Strength'].default_value>.01]
                    if nodes or mat.get('rainfall_emissive'):
                        mat=mat.copy();mat.name+=' impact';data.materials[mi]=mat
                        for nd in mat.node_tree.nodes:
                            if nd.type=='BSDF_PRINCIPLED':nd.inputs['Emission Strength'].default_value*=boost
                            elif nd.type=='EMISSION':nd.inputs['Strength'].default_value*=boost
                            elif nd.type=='OUTPUT_AOV':
                                col=nd.inputs['Color'].default_value;nd.inputs['Color'].default_value=tuple(v*boost for v in col[:3])+(col[3],)
                        mat['rainfall_emissive']=True
            for ob in effects:ob.hide_render=True
            import numpy as np
            xyz=np.empty(len(data.vertices)*3,dtype=np.float32);data.vertices.foreach_get('co',xyz);xyz=xyz.reshape((-1,3))
            fit=1.0
            for angle in DIRS.values():
                q=xyz@np.array(Matrix.Rotation(angle,3,'Z')).T@np.array(basis)
                fit=min(fit,92/(max(abs(q[:,0].min()),abs(q[:,0].max()))*iso_rig.R),132/(q[:,1].max()*iso_rig.R))
            if fit<1:
                xyz*=fit;data.vertices.foreach_set('co',xyz.reshape(-1));data.update()
            for direction,angle in DIRS.items():
                projected=xyz@np.array(Matrix.Rotation(angle,3,'Z')).T@np.array(basis)
                lo=projected.min(axis=0);hi=projected.max(axis=0)
                bounds=[96+lo[0]*iso_rig.R,136.32-hi[1]*iso_rig.R,96+hi[0]*iso_rig.R,136.32-lo[1]*iso_rig.R]
                assert min(bounds[:2])>=3 and max(bounds[2:])<=189,(anim,f,direction,[round(float(v),1) for v in bounds])
            for row,(d,angle) in enumerate(DIRS.items()):
                o=bpy.data.objects.new(anim+'_'+d+'_'+str(f),data);s.collection.objects.link(o)
                o.rotation_euler.z=angle
                o.location=basis@Vector(((f-(n-1)/2)*unit,(3.5-row)*unit,0));copies.append(o)
        for o in originals:o.hide_render=True
        iso_rig.set_frame((n*192,1536),'CREA');s['iso_frame']=[n*192,1536];s.camera.data.shift_y=.21/n
        s.eevee.taa_render_samples=12
        path=DEST/(anim+'.png')
        bpy.context.view_layer.update()
        cel.install('creature',normals=False)
        iso_rig.common.configure_passes(path)
        s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        with Image.open(path) as im:im.resize((n*192,1536),Image.Resampling.LANCZOS).save(path,optimize=True,compress_level=9)
        candidates=list(DEST.glob(anim+'_e__*.png'))
        assert len(candidates)==1, candidates
        with Image.open(candidates[0]) as im:
            im.resize((n*96,768),Image.Resampling.LANCZOS).save(DEST/(anim+'_e.png'),optimize=True,compress_level=9)
        candidates[0].unlink()
        for o in copies:bpy.data.objects.remove(o,do_unlink=True)
        for data in meshes:bpy.data.meshes.remove(data)
        print('AV1 ATLAS PASS '+anim,flush=True)
    resources()

def resources():
    selected=('attack','wave','cast','crue') if '--resume' in sys.argv else tuple(ANIMS)
    for emission in (False,True):
        ext=[];sub=[];anims=[];sid=0
        for ai,(anim,n) in enumerate(ANIMS.items()):
            if anim not in selected:continue
            eid='av_action_'+str(ai+1);cid='c'+str(ai)
            suffix='_e' if emission else ''
            ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/averse/{anim}{suffix}.png" id="{eid}"]')
            if not emission: pass
            for row,d in enumerate(DIRS):
                frames=[]
                for f in range(n):
                    sid+=1;aid='av_action_'+str(sid);atlas=f'ExtResource("{eid}")'
                    sub.append(f'[sub_resource type="AtlasTexture" id="{aid}"]\natlas = {atlas}\nregion = Rect2({f*192}, {row*192}, 192, 192)')
                    duration=F60[anim][f]*FPS[anim]/60 if anim in F60 else 1.0
                    frames.append('{"duration": '+str(duration)+', "texture": SubResource("'+aid+'")}')
                anims.append('{"frames": ['+', '.join(frames)+f'], "loop": {str(anim in ("idle","run")).lower()}, "name": &"{anim}_{d}", "speed": {FPS[anim]}.0'+'}')
        path=DEST/('averse_emission.tres' if emission else 'averse.tres')
        baseline=subprocess.check_output(['git','show','HEAD:'+path.relative_to(ROOT).as_posix()],cwd=ROOT).decode().replace('\r\n','\n')
        base_header,base_animations=baseline.split('[resource]\nanimations = [',1)
        entries=re.findall(r'\{"frames":.*?"name": &"([^\"]+)".*?\}(?=,\n|\]\s*$)',base_animations,re.S)
        kept=[]
        for match in re.finditer(r'\{"frames":.*?"name": &"([^\"]+)".*?\}(?=,\n|\]\s*$)',base_animations,re.S):
            if match.group(1).rsplit('_',1)[0] not in selected:kept.append(match.group(0))
        header=base_header.rstrip()+'\n\n'+'\n\n'.join(ext+sub)+'\n\n'
        header=re.sub(r'load_steps=\d+', 'load_steps='+str(header.count('[ext_resource')+header.count('[sub_resource')+1),header)
        path.write_text(header+'[resource]\nanimations = ['+',\n'.join(kept+anims)+']\n')

def icons():
    # Four cast bronze votive emblems, inset into a dark engraved field; no perimeter frame.
    for index,key in enumerate(('goutte_lame','vague','flaque_miroir','crue')):
        s=iso_rig.create_rig('CREA',128);s.eevee.taa_render_samples=24
        s.camera.location=(2.6,-4.8,6.8);s.camera.rotation_euler=(-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=1.5
        s.view_settings.view_transform='AgX'
        try:s.view_settings.look='AgX - Medium High Contrast'
        except Exception:pass
        bronze=worn('Icon AV1 weathered bronze','293B36','A8946E',1,.38)
        iron=worn('Icon AV1 engraved wet basalt','10191E','333E46',.65,.42)
        water=bpy.data.materials.new('Icon restrained cyan water');water.use_nodes=True
        p=water.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=rgb('215C69');p.inputs['Metallic'].default_value=.65;p.inputs['Roughness'].default_value=.24;p.inputs['Emission Color'].default_value=rgb('5FD4E8');p.inputs['Emission Strength'].default_value=.8
        r=empty('Averse '+key)
        # Broken, bevelled slate field follows the silhouette rather than adding a bar or border.
        verts=[(-.48,-.43,0),(.35,-.48,0),(.49,-.20,0),(.43,.38,0),(.10,.48,0),(-.43,.36,0)]
        base=mesh('Irregular engraved dark field',verts,[tuple(range(6))],iron,r,.018)
        solid=base.modifiers.new('Stone thickness','SOLIDIFY');solid.thickness=.05
        for j in range(6):
            x=-.32+j*.12;tube('Incised rain tally',[(x,.27,.009),(x+.06,.36,.009)],.005,bronze,r)
        if index==0:
            # Sharp droplet blade, convex bevels catching the common studio key.
            pts=[(0,-.43,.10),(-.18,-.02,.10),(-.13,.22,.10),(0,.39,.10),(.13,.22,.10),(.18,-.02,.10),(0,.02,.21)]
            mesh('Forged droplet blade',pts,[(j,(j+1)%6,6) for j in range(6)],bronze,r,.018)
            tube('Cyan blade fuller',[(0,-.31,.13),(0,-.03,.225),(0,.26,.15)],.014,water,r)
        elif index==1:
            for j in range(3):
                pts=[(-.38+k*.038,-.20+j*.18+.055*math.sin(k*.37),.08+.035*math.sin(k*.20)) for k in range(21)]
                tube('Cast breaking wave crest',pts,.034,bronze,r)
                tube('Cyan water in wave groove',[(x,y-.023,z+.025) for x,y,z in pts],.010,water,r)
            tube('Hooked wave foam',[(.27,.2,.10),(.36,.25,.15),(.37,.35,.19),(.29,.37,.21),(.25,.32,.20)],.035,bronze,r)
        elif index==2:
            for j in range(3):
                a=.34-j*.085;pts=[(a*math.cos(k*math.tau/64),a*.70*math.sin(k*math.tau/64),.065+j*.015) for k in range(65)]
                tube('Bronze mirror ripple',pts,.017,bronze,r)
            bead('Dark convex mirror',(0,0,.07),(.25,.17,.02),water,r)
            tube('Reflection fracture',[(-.18,-.06,.098),(-.03,-.03,.104),(.03,.04,.104),(.18,.08,.098)],.009,bronze,r)
        else:
            rings('Miniature open flood amphora',[(.06,.12,.10,0),(.12,.18,.14,0),(.28,.19,.15,0),(.40,.11,.09,0),(.47,.11,.09,0)],bronze,r,24,False)
            for side in (-1,1):tube('Amphora handle',[(side*.11,0,.40),(side*.24,0,.40),(side*.25,0,.26),(side*.17,0,.23)],.023,bronze,r)
            for j in range(3):
                a=.27+j*.065;tube('Expanding flood crest',[(a*math.cos(k*math.tau/48),a*math.sin(k*math.tau/48),.05) for k in range(49)],.012,water,r)
            tube('Overflow cyan channel',[(-.05,-.09,.44),(-.09,-.15,.35),(-.06,-.16,.20),(0,-.20,.07)],.017,water,r)
        iso_rig.bake_ao_shadows(r)
        for o in s.objects:
            if o.type=='LIGHT':
                if o.type=='LIGHT' and o.data.type=='AREA':o.data.energy=650
        s.world.color=(.18,.18,.18)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE.with_name('averse_icon_'+key+'.blend')))
        path=ICONS/('averse_'+key+'.png');iso_rig.render_frame(path,passes=False)
        print('AV1 ICON PASS '+key,flush=True)

def contact_verify():
    report={'character':'averse','cell':192,'directions':list(DIRS),'pivot':[96,136.32],'R':iso_rig.R,'animations':{},'attack_impact_frame_zero_based':3,'water_mask':'cyan sight glass in _e; local vertical fill','icons':[]}
    board=Image.new('RGBA',(1536,9*192+384),(20,25,29,255))
    for row,(anim,n) in enumerate(ANIMS.items()):
        if anim not in ('attack','wave','cast','crue'):continue
        sizes=[];digests=[]
        for su in ('','_e'):
            with Image.open(DEST/(anim+su+'.png')) as im:
                expected=(96*n,768) if su=='_e' else (192*n,1536)
                assert im.size==expected,(anim,su,im.size)
                assert im.getchannel('A').getbbox(),(anim,su,'empty')
                sizes.append(list(im.size))
                if not su:
                    # Distinct frames, transparent margins, all eight directions populated.
                    for d in range(8):
                        hashes=[]
                        for f in range(n):
                            cell=im.crop((f*192,d*192,(f+1)*192,(d+1)*192));bb=cell.getbbox()
                            assert bb and bb[0]>=4 and bb[1]>=4 and bb[2]<=188 and bb[3]<=188,(anim,d,f,bb)
                            hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
                    if anim in ('attack','wave','cast','crue'):assert len(set(hashes))==n,(anim,d,'duplicate frames')
                    for d in range(8):
                        cell=im.crop(((n//2)*192,d*192,(n//2+1)*192,(d+1)*192));board.alpha_composite(cell,(d*192,row*192))
        report['animations'][anim]={'frames':n,'fps':FPS[anim],'sizes':sizes,'directions':8}
    frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
    keys=['averse_goutte_lame','averse_vague','averse_flaque_miroir','averse_crue','eclat_de_braise','nova_ardente','cendres','brasier']
    for j,key in enumerate(keys):
        path=ICONS/(key+'.png')
        if not path.exists():continue
        im=Image.open(path).convert('RGBA')
        if key.startswith('averse'):assert im.size==(128,128);report['icons'].append(key)
        for size,y in [(128,9*192),(64,9*192+160)]:
            tile=Image.new('RGBA',(size,size),(0,0,0,0));tile.alpha_composite(im.resize((size,size),Image.Resampling.LANCZOS));tile.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS));board.alpha_composite(tile,(j*192+(192-size)//2,y))
    # Approved reference crops on the same unique inspection board.
    for j,path in enumerate([ROOT/'art/tools/characters/_cd_averse.png',ROOT/'art/tools/iso/_c4_contact.png',ROOT/'art/tools/characters/_m2_contact.png',ROOT/'art/tools/ui/_i2_contact.png']):
        if path.exists():
            im=Image.open(path).convert('RGBA');im.thumbnail((375,140),Image.Resampling.LANCZOS);board.alpha_composite(im,(j*384,9*192+240))
    board.save(ROOT/'art/tools/night/_av1_contact.png',optimize=True)
    (DEST/'averse_manifest.json').write_text(json.dumps(report,indent=2))
    print('AV1 VERIFY PASS: 72 animations, 472 directional frames, 27 atlases, 4 icons',flush=True)

if __name__=='__main__':
    if '--verify' in sys.argv:subprocess.run(['python',str(ROOT/'art/tools/night/av1_actions_check.py'),'--audit'],check=True)
    elif '--icons-only' in sys.argv:icons()
    else:
        if '--resume' not in sys.argv or not SOURCE.exists() or '--rebuild-source' in sys.argv:source()
        if '--source-only' not in sys.argv:
            atlases()
            if '--resume' not in sys.argv:icons()
            subprocess.run([sys.executable if 'blender' not in sys.executable.lower() else 'python',str(ROOT/'art/tools/night/av1_actions_check.py')],check=True)
            print('PASS AV1 action render',flush=True)
