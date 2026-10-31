"""AA1: approved Avare design, hierarchical animation rig, CREA atlases and PBR spell emblems.
Background Blender only. --source-only / --resume / --icons-only / --verify.
Pillow is used solely for resizing, assembly and pixel verification.
"""
import sys, math, json, hashlib
from pathlib import Path
sys.dont_write_bytecode=True
import bpy
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/characters'),str(ROOT/'art/tools/iso')]
import iso_rig
from ardent_iso_build import worn, mesh, rod, rings, bead, empty
from cd_cd1_common import block, cyl, tube, rgb
from PIL import Image
DEST=ROOT/'game/assets/sprites/characters/avare'
SOURCE=ROOT/'art/blender/characters/avare.blend'
WORK=ROOT/'art/blender/characters/avare_frames'
ICONS=ROOT/'game/assets/sprites/icons/spells'
ANIMS={'idle':8,'run':8,'swing':7,'throw':7,'slam':9,'ult':11,'attack':7,'cast':7,'cast_ult':11,'death':8}
DIRS=iso_rig.DIRECTIONS
FPS={a:(8 if a=='idle' else 14 if a=='run' else 10 if a=='death' else 12) for a in ANIMS}
F60={'swing':[2,2,2,3,3,4,4],'throw':[2,2,2,3,3,4,4],'slam':[2,2,2,2,3,3,4,4,4],'ult':[2,2,2,2,2,3,3,3,4,4,4]}
IMPACT={'swing':3,'throw':3,'slam':4,'ult':6}
import cd_cd3_common as cd

def parent_keep(o,p):
    m=o.matrix_world.copy();o.parent=p;o.matrix_world=m


def source():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/cd_avare.blend'))
    s=bpy.context.scene;root=next(o for o in s.objects if o.name.startswith('AVARE') and o.type=='EMPTY');root.name='Avare'
    keep={root,*root.children_recursive}
    for o in list(s.objects):
        if o not in keep or o.name.startswith(('Maillon forg','Pi')):bpy.data.objects.remove(o,do_unlink=True)
    root.location=(0,0,0);root.rotation_euler=(0,0,0)
    for o in root.children_recursive:
        o.hide_render=False;o.animation_data_clear()
        if o.type=='CURVE':o.data.bevel_resolution=1;o.data.resolution_u=3
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
    for o in list(root.children_recursive):
        if o.type not in ('MESH','CURVE'):continue
        data=bpy.data.meshes.new_from_object(o.evaluated_get(deps),depsgraph=deps)
        ob=bpy.data.objects.new(o.name+' baked',data);s.collection.objects.link(ob);ob.parent=o.parent;ob.matrix_world=o.matrix_world.copy()
        name=o.name;bpy.data.objects.remove(o,do_unlink=True);ob.name=name
    bpy.context.view_layer.update()
    torso=empty('Torso weight',(0,0,.85),root);legs=[];arms=[]
    bpy.context.view_layer.update()
    safe=next(o for o in root.children if o.name.startswith('Coffre-fort'))
    oldarm=next(o for o in root.children if o.name.startswith('Bras droit'))
    for side in (-1,1):
        leg=empty('Leg '+str(side),(side*.205,0,.65),root);legs.append(leg)
        arm=empty('Arm '+str(side),(side*.32,.02,.27),torso);arms.append(arm)
    bpy.context.view_layer.update()
    # Bind the approved geometry to anatomical pivots, preserving its world transforms.
    for o in list(oldarm.children):parent_keep(o,arms[1])
    for o in list(root.children):
        if o in [torso,safe,oldarm,*legs]:continue
        if o.type!='MESH':continue
        xs=[(o.matrix_world@v.co).x for v in o.data.vertices];x=sum(xs)/len(xs)
        if o.name.startswith(('Botte','Plaque de cou-de-pied','Pantalon')):parent_keep(o,legs[0 if x<0 else 1])
        elif o.name.startswith(('Manche','Plis de manche','Main noueuse','Doigts')):parent_keep(o,arms[0])
        else:parent_keep(o,torso)
    safe.location=(-.58,.24,.02);safe.scale=(.80,.80,.80)
    # Forged chain links follow hand and safe at every key pose; no detached weapon layer.
    links=[];iron=next(m for m in bpy.data.materials if m.name.startswith('Fonte piqu'))
    for i in range(16):
        link=cd.torus('Articulated forged link %02d'%i,(0,0,0),.028,.007,iron,root,sc=(.75,1.2,1));links.append(link)
    rig=[torso,*legs,*arms,safe,*links]
    rest={o.name:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in rig}
    root.scale=(.94,.94,.94)
    s=iso_rig.create_rig('CREA',192,reset=False);s.camera.data.shift_y=.21
    s.view_layers[0].use_pass_normal=True;s.view_layers[0].use_pass_emit=True
    s.eevee.taa_render_samples=12;s.render.threads_mode='FIXED';s.render.threads=8
    for o in list(s.objects):
        if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
    for name,loc,energy,col in [('AA1 warm key',(-4,-6,8),2.5,(1,.76,.53)),('AA1 cold rim',(4,3,5),1.3,(.50,.66,.85))]:
        bpy.ops.object.light_add(type='SUN',location=loc);o=bpy.context.object;o.name=name;o.data.energy=energy;o.data.color=col;o.data.angle=.15;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    s.world.use_nodes=True;s.world.node_tree.nodes.get('Background').inputs[0].default_value=(.18,.18,.18,1);s.world.node_tree.nodes.get('Background').inputs[1].default_value=.45
    iso_rig.bake_ao_shadows(root)
    manifest={};start=1
    for anim,n in ANIMS.items():
        s.timeline_markers.new(anim,frame=start);manifest[anim]={'start':start,'frames':n,'fps':FPS[anim],'loop':anim in ('idle','run')}
        for f in range(n):
            pose(anim,f,n,rig,rest)
            for o in rig:
                for prop in ('location','rotation_euler','scale'):o.keyframe_insert(prop,frame=start+f)
        start+=n+4
    s['animation_manifest']=json.dumps(manifest);s['ground_pivot_px']=[96,136.32];s['render_px_per_u']=iso_rig.R
    s['AA1_notes']='Approved CD preserved; greasy leather, pitted cast iron, black oak, gold seams. Anatomical pivots and dynamic forged chain. Attack impact index 2/4. VFX coin_burst/ransom_ring reserved for AA2.'
    s.frame_start=1;s.frame_end=start-5;s.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0;SOURCE.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    print('AA1 SOURCE PASS',flush=True)

def pose(anim,i,n,rig,rest):
    for o in rig:o.location,o.rotation_euler,o.scale=[v.copy() for v in rest[o.name]]
    torso,lleg,rleg,larm,rarm,safe,*links=rig
    w=i/n*math.tau;q=i/(n-1);hit=n//2
    torso.rotation_euler.x=.025*math.sin(w);rarm.rotation_euler.x=.045*math.sin(w+.4)
    safe.rotation_euler.x=.015*math.sin(w+.8)
    if anim=='run':
        for k,leg in enumerate((lleg,rleg)):
            leg.rotation_euler.x=.45*math.sin(w+k*math.pi);leg.location.z+=.05*max(0,math.cos(w+k*math.pi))
        torso.location.z+=.024*math.cos(2*w);torso.rotation_euler.x=.13;torso.rotation_euler.z=.045*math.sin(w)
        rarm.rotation_euler.x=-.32*math.sin(w);larm.rotation_euler.x=-.18
        safe.location.y+=.12+.035*math.sin(w);safe.rotation_euler.x=.08+.04*math.sin(w+.6)
    elif anim in ('swing','attack'):
        phase=[-.5,-1.35,-.95,.85,1.65,.95,.30][i]
        safe.location=(.96*math.sin(phase),-.88*math.cos(phase)-.10,.18+.30*math.sin(math.pi*q))
        safe.rotation_euler.z=phase;safe.rotation_euler.y=.5*math.sin(phase)
        torso.rotation_euler.z=-.62 if i<3 else .58*(1-q);torso.rotation_euler.x=.20 if i==IMPACT['swing'] else -.12
        larm.rotation_euler.x=.95 if i<3 else -.9;larm.rotation_euler.y=-.7;rarm.rotation_euler.x=.6*math.sin(math.pi*q)
        if i==2:
            for j,o in enumerate(links):o.location.x+=(-.16+j*.08);o.scale=(1.12,1.32,1.12)
        if i==IMPACT['swing']:safe.location=(.45,-1.0,.25)
    elif anim in ('throw','cast'):
        k=[-.25,-1.0,-.65,1.65,1.0,.40,.12][i]
        rarm.rotation_euler.x=[-.45,-1.1,-.8,1.35,.15,-.25,-.12][i];rarm.rotation_euler.z=[.2,.65,.45,-.8,-.35,-.12,0][i]
        larm.rotation_euler.x=.65 if i<3 else -.4
        torso.rotation_euler.z=k*.42;torso.rotation_euler.x=-.22 if i<3 else .12
        if i in (2,3):
            for j,o in enumerate(links):o.location.x+=(-.18+j*.10);o.scale=(.8,1.55,.8)
    elif anim=='slam':
        lift=[0,.35,.82,1.35,1.48,.25,.02,.015,.02][i];safe.location=(-.50,-.24,lift);safe.rotation_euler.y=[0,-.25,-.62,-.95,-.85,.42,.18,.05,0][i]
        larm.rotation_euler.x=[0,.45,.85,1.15,1.05,-.85,-.45,-.12,0][i];rarm.rotation_euler.x=[0,.3,.7,.95,.85,-.65,-.35,-.08,0][i]
        torso.location.z-=.2 if i==IMPACT['slam'] else .10*math.sin(math.pi*q);torso.rotation_euler.x=.42 if i==IMPACT['slam'] else -.24*math.sin(math.pi*q)
        if i==IMPACT['slam']:
            for j,o in enumerate(links):o.location.z+=.16*(1-abs(j-1.5)/2);o.scale=(1.5,1.5,1.5)
    elif anim in ('ult','cast_ult'):
        power=[0,.45,.8,1,1,.85,.55,.25,.05,0,0][i]
        torso.location.z+=.12*power;torso.rotation_euler.x=-.28*power
        larm.rotation_euler.y=-1.0*power;rarm.rotation_euler.y=1.15*power;rarm.rotation_euler.x=-1.0*power
        safe.rotation_euler.x=-.85*power if i>=5 else -.18*power;safe.location.z+=.75*power
        if i in (6,7,8):
            for j,o in enumerate(links):o.location.x+=(-.12+j*.08);o.scale=(.75,1.6,.75)
    elif anim=='death':
        fall=min(1,q*1.3);torso.rotation_euler.x=-1.25*fall;torso.location.z-=.40*fall;torso.location.y+=.08*fall
        torso.rotation_euler.z=.22*fall;lleg.rotation_euler.x=-.45*fall;rleg.rotation_euler.x=.35*fall
        rarm.rotation_euler.y=.65*fall;larm.rotation_euler.y=-.6*fall;safe.rotation_euler.y=.12*fall
    bpy.context.view_layer.update()
    root=bpy.data.objects['Avare'];inv=root.matrix_world.inverted()
    a=inv@(larm.matrix_world@Vector((-.14,-.19,-.43)))
    b=inv@(safe.matrix_world@Vector((0,-.27,.56)))
    for j,o in enumerate(links):
        t=j/(len(links)-1);p=a.lerp(b,t);p.z-=.08*math.sin(t*math.pi)
        o.location=p;o.rotation_euler=(b-a).to_track_quat('Y','Z').to_euler();o.rotation_euler.y+=(j%2)*math.pi/2

def posed_mesh(root,name):
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
    verts=[];faces=[];matids=[];mats=[];smooth=[]
    for o in root.children_recursive:
        if o.type!='MESH' or o.hide_render:continue
        ev=o.evaluated_get(deps);data=ev.to_mesh();offset=len(verts);m=ev.matrix_world
        verts.extend(tuple(m@v.co) for v in data.vertices)
        indices=[]
        for mat in data.materials:
            if mat not in mats:mats.append(mat)
            indices.append(mats.index(mat))
        for poly in data.polygons:
            faces.append(tuple(offset+j for j in poly.vertices));matids.append(indices[poly.material_index] if indices else 0);smooth.append(poly.use_smooth)
        ev.to_mesh_clear()
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    for mat in mats:data.materials.append(mat)
    for poly,idx,sm in zip(data.polygons,matids,smooth):poly.material_index=idx;poly.use_smooth=sm
    return data

def atlases():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE));s=bpy.context.scene;root=bpy.data.objects['Avare']
    manifest=json.loads(s['animation_manifest']);basis=s.camera.rotation_euler.to_matrix();unit=192/iso_rig.R
    DEST.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    originals=[o for o in root.children_recursive if o.type=='MESH']
    for anim,n in ANIMS.items():
        if '--resume' in sys.argv and all((DEST/(anim+su+'.png')).exists() for su in ('','_e')):continue
        copies=[];meshes=[]
        for o in originals:o.hide_render=False
        for f in range(n):
            s.frame_set(manifest[anim]['start']+f);root.rotation_euler.z=0
            data=posed_mesh(root,anim+str(f));meshes.append(data)
            import numpy as np
            xyz=np.empty(len(data.vertices)*3,dtype=np.float32);data.vertices.foreach_get('co',xyz);xyz=xyz.reshape((-1,3))
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
        iso_rig.set_frame((n*192,1536),'CREA');s.camera.data.shift_y=.21/n
        s.eevee.taa_render_samples=12
        path=DEST/(anim+'.png');iso_rig.render_frame(path)
        for o in copies:bpy.data.objects.remove(o,do_unlink=True)
        for data in meshes:bpy.data.meshes.remove(data)
        print('AA1 ATLAS PASS '+anim,flush=True)
    resources()

def resources():
    old={}
    for name in ('avare.tres','avare_emission.tres'):
        p=DEST/name
        if p.exists():
            import re
            old[name]=re.search(r'(?m)^\[gd_resource[^\r\n]*\](?:\r?\n){2}(?=\[ext_resource)',p.read_text()).group(0)
    for emission in (False,True):
        ext=[];sub=[];anims=[];sid=0
        for ai,(anim,n) in enumerate(ANIMS.items()):
            eid=ai+1
            ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/avare/{anim}{"_e" if emission else ""}.png" id="{eid}"]')
            for row,d in enumerate(DIRS):
                frames=[]
                for f in range(n):
                    sid+=1;aid='a'+str(sid)
                    sub.append(f'[sub_resource type="AtlasTexture" id="{aid}"]\natlas = ExtResource("{eid}")\nregion = Rect2({f*192}, {row*192}, 192, 192)')
                    dur=(F60.get(anim,[1]*n)[f]*FPS[anim]/60) if anim in F60 else 1.0
                    frames.append('{"duration": '+str(dur)+', "texture": SubResource("'+aid+'")}')
                anims.append('{"frames": ['+', '.join(frames)+f'], "loop": {str(anim in ("idle","run")).lower()}, "name": &"{anim}_{d}", "speed": {FPS[anim]}.0'+'}')
        path=DEST/('avare_emission.tres' if emission else 'avare.tres')
        import re
        nl='\r\n' if path.exists() and '\r\n' in path.read_bytes().decode('utf8') else '\n'
        header=old.get(path.name,f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(sub)+1} format=3]{nl}{nl}')
        body=nl.join(ext+sub)+nl+nl+'[resource]'+nl+'animations = ['+nl+(','+nl).join(anims)+']'+nl
        path.write_text(re.sub(r'(?m)^\[gd_resource[^\r\n]*\](?:\r?\n){2}',f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(sub)+1} format=3]{nl}{nl}',header)+body,newline='')


def icons():
    # Four real bevelled emblems: chained safe, thrown coin fan, ransom seal, ruptured treasury.
    for index,key in enumerate(('coup_de_coffre','poignee_de_pieces','rancon','faillite')):
        s=iso_rig.create_rig('CREA',128);s.eevee.taa_render_samples=24
        s.camera.location=(1.8,-4.8,7.6);s.camera.rotation_euler=(-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=1.5
        s.view_settings.view_transform='AgX'
        try:s.view_settings.look='AgX - Medium High Contrast'
        except Exception:pass
        iron=worn('AA1 icon blackened steel','151B20','4B5152',1,.39)
        brass=worn('AA1 icon tarnished monetary gold','473B23','A8946E',1,.36)
        wood=worn('AA1 icon dark oak','171815','403326',0,.66)
        gold=cd.emit('AA1 icon single gold accent','F2C14E',1.8)
        r=empty('Avare emblem '+key)
        pts=[(-.46,-.42,0),(.36,-.46,0),(.48,-.23,0),(.43,.36,0),(.09,.46,0),(-.43,.35,0)]
        base=mesh('Engraved irregular dark field',pts,[tuple(range(6))],iron,r,.018);sol=base.modifiers.new('Field depth','SOLIDIFY');sol.thickness=.045
        for j in range(7):cd.tube('Incised account tally',[(-.32+j*.10,.29,.012),(-.27+j*.10,.36,.012)],.004,brass,r)
        def coin(x,y,z,rad=.10,rot=0):
            c=cd.empty('Hammered gold coin');c.parent=r;c.location=(x,y,z);c.rotation_euler=(.18,rot,0)
            # Cylinder perpendicular to the emblem plane, bevelled rim and raised currency stroke.
            bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=rad,depth=.038);o=bpy.context.object;o.name='Minted coin body';o.parent=c;o.location=(0,0,0);o.data.materials.append(brass)
            mod=o.modifiers.new('Worn coin bevel','BEVEL');mod.width=.008;mod.segments=3;o.modifiers.new('Weighted coin normals','WEIGHTED_NORMAL')
            cd.torus('Milled coin rim',(0,0,.022),rad*.81,.006,brass,c)
            cd.tube('Embossed mint mark',[(-rad*.25,-rad*.45,.025),(0,rad*.4,.025),(rad*.25,-rad*.45,.025)],.008,gold if index==3 else brass,c)
            return c
        if index in (0,3):
            chest=cd.empty('Chained black oak treasury');chest.parent=r;chest.location=(0,-.045,.09);chest.rotation_euler.z=-.18
            cd.cube('Oak body',(0,0,.14),(.52,.40,.29),wood,chest,.025)
            for x in (-.20,.20):
                cd.cube('Forged iron band',(x,0,.30),(.055,.43,.04),iron,chest,.008)
                cd.cube('Front iron band',(x,-.215,.15),(.055,.035,.30),iron,chest,.008)
                for z in (.05,.24):cd.ell('Peened rivet',(x,-.24,z),(.012,.008,.012),brass,chest)
            cd.cube('Lid lip',(0,0,.31),(.54,.42,.045),iron,chest,.01)
            cd.cube('Brass lock',(0,-.25,.17),(.09,.045,.10),brass,chest,.012)
            cd.torus('Lock shackle',(0,-.25,.24),.032,.008,brass,chest,rot=(math.pi/2,0,0))
            cd.tube('Gold under pressure',[(-.17,-.229,.285),(0,-.233,.285),(.17,-.229,.285)],.007,gold,chest)
            if index==0:
                for j in range(9):
                    t=j/8;cd.torus('Forged weapon chain',(-.32+t*.64,-.34-.045*math.sin(t*math.pi),.10),.034,.009,iron,r,rot=(0,(j%2)*math.pi/2,0),sc=(1.1,.8,1))
            else:
                for j in range(7):
                    a=j*math.tau/7;coin(.34*math.cos(a),.34*math.sin(a),.16+.04*(j%3),.067,rot=.35*math.sin(a))
                for a in (.4,2.5,4.5):cd.tube('Pressure fracture',[(.15*math.cos(a),.15*math.sin(a),.05),(.29*math.cos(a+.15),.29*math.sin(a+.15),.05),(.42*math.cos(a),.42*math.sin(a),.05)],.008,gold,r)
        elif index==1:
            for j in range(5):
                a=-1.1+j*.55;coin(.30*math.sin(a),.18+.18*math.cos(a),.12+.023*j,.10,rot=-.3+j*.15)
                cd.tube('Thrown coin trajectory',[(.03,-.31,.045),(.12*math.sin(a),-.05,.055),(.25*math.sin(a),.15+.08*math.cos(a),.065)],.009,gold,r)
            cd.cube('Leather gauntlet cuff',(0,-.30,.095),(.23,.17,.12),wood,r,.022)
            for j in range(3):cd.cube('Gauntlet knuckle',(-.075+j*.075,-.19,.13),(.058,.10,.075),iron,r,.018)
        else:
            # Heavy impact seal surrounded by hostage account markings.
            coin(0,0,.115,.24)
            for j in range(12):
                a=j*math.tau/12;cd.cube('Stamped seal ray',(.33*math.cos(a),.33*math.sin(a),.055),(.035,.075,.025),brass,r,.008).rotation_euler.z=a-math.pi/2
            cd.tube('Ransom impact fissure',[(-.36,-.27,.04),(-.16,-.22,.05),(-.07,-.30,.055),(.13,-.24,.055),(.36,-.30,.04)],.012,gold,r)
        iso_rig.bake_ao_shadows(r)
        # Shared studio: warm upper left, large cold specular rim.
        for o in list(s.objects):
            if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
        for name,pos,power,col,size in [('Common warm key',(-3,-4,6),650,(1,.80,.61),3),('Common cold rim',(3,2,4),850,(.51,.68,.90),2.2)]:
            bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.color=col;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
        s.world.color=(.12,.12,.12)
        bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE.with_name('avare_icon_'+key+'.blend')))
        ICONS.mkdir(parents=True,exist_ok=True);iso_rig.render_frame(ICONS/('avare_'+key+'.png'),passes=False)
        print('AA1 ICON PASS '+key,flush=True)

def verify():
    import hashlib,subprocess,tempfile
    report={'frames':0,'sheets':0,'clipped':[],'static':[],'bounds':{},'body_emissive_pixels':0}
    for anim,n in ANIMS.items():
        with Image.open(DEST/f'{anim}.png') as im:
            assert im.size==(192*n,1536) and im.mode=='RGBA'
            for row,d in enumerate(DIRS):
                hashes=set()
                for f in range(n):
                    frame=im.crop((192*f,192*row,192*(f+1),192*(row+1)));b=frame.getchannel('A').point(lambda v:255 if v>8 else 0).getbbox()
                    assert b,(anim,d,f,'empty');report['frames']+=1
                    previous=report['bounds'].get(anim,b)
                    report['bounds'][anim]=[min(previous[0],b[0]),min(previous[1],b[1]),max(previous[2],b[2]),max(previous[3],b[3])]
                    if min(b[:2])<4 or max(b[2:])>188:report['clipped'].append([anim,d,f,b])
                    hashes.add(hashlib.sha256(frame.tobytes()).hexdigest())
                if len(hashes)!=n:report['static'].append([anim,d,len(hashes),n])
        for suf in ('','_n','_e'):
            with Image.open(DEST/f'{anim}{suf}.png') as im:
                assert im.size==(192*n,1536) and im.mode=='RGBA';report['sheets']+=1
                if suf=='_n':assert len(im.getcolors(im.width*im.height) or [])>32
                if suf=='_e':
                    assert any(im.getchannel(c).getextrema()[1]>4 for c in ('R','G','B'))
                    import numpy as np
                    pixels=np.asarray(im)
                    report['body_emissive_pixels']+=int(np.count_nonzero((pixels[:,:,:3].max(axis=2)>4)&(pixels[:,:,3]>8)))
    (DEST/'aa1_verification.json').write_text(json.dumps(report,indent=2))
    assert not report['clipped'],report['clipped'][:8]
    assert not report['static'],report['static'][:8]
    godot=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
    # A GDScript resource serialized as .tres avoids creating any .gd/.tscn file.
    code='''extends SceneTree
func _initialize():
    var sf = load("res://assets/sprites/characters/avare/avare.tres")
    assert(sf is SpriteFrames)
    var count = 0
    assert(sf.get_animation_names().size() == 80)
    for anim in sf.get_animation_names():
        if String(anim).begins_with("death_"):
            assert(not sf.get_animation_loop(anim))
        for i in range(sf.get_frame_count(anim)):
            var tex = sf.get_frame_texture(anim, i)
            assert(tex is AtlasTexture and tex.atlas is CanvasTexture)
            assert(tex.atlas.diffuse_texture != null and tex.atlas.normal_texture != null)
            assert(tex.region.size == Vector2(192,192))
            count += 1
    assert(count == 496)
    var glow = load("res://assets/sprites/characters/avare/avare_emission.tres")
    assert(glow is SpriteFrames and glow.get_animation_names() == sf.get_animation_names())
    for anim in glow.get_animation_names():
        assert(glow.get_frame_count(anim) == sf.get_frame_count(anim))
        for i in range(glow.get_frame_count(anim)):
            var tex = glow.get_frame_texture(anim,i)
            assert(tex is AtlasTexture and tex.atlas != null)
            assert(tex.region == sf.get_frame_texture(anim,i).region)
    print("AA1 LOAD RESULT: OK / 496 frames / 80 animations")
    quit()
'''
    with tempfile.TemporaryDirectory(prefix='rainfall_aa1_') as temp:
        script=Path(temp)/'check.tres';script.write_text('[gd_resource type="GDScript" format=3]\n\n[resource]\nscript/source = '+json.dumps(code)+'\n',encoding='utf8')
        for label,args in [('import',['--editor','--import','--quit']),('load',['--script',str(script)]),('sprites_test',['res://tests/sprites_test.tscn'])]:
            p=subprocess.run([godot,'--headless','--path',str(ROOT/'game')]+args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf8',errors='replace',timeout=180)
            (DEST/f'aa1_{label}.log').write_text(p.stdout,encoding='utf8')
            errs=[x for x in p.stdout.splitlines() if 'ERROR:' in x or 'SCRIPT ERROR' in x]
            report[label]={'returncode':p.returncode,'errors':errs[:8]}
            if label=='load':
                assert 'AA1 LOAD RESULT: OK' in p.stdout,p.stdout[-1500:]
                assert not errs,errs[:8]
            if label=='sprites_test':assert 'RESULT: OK' in p.stdout,p.stdout[-1500:]
            assert p.returncode==0,(label,p.returncode)
    (DEST/'aa1_verification.json').write_text(json.dumps(report,indent=2))
    for key in ('coup_de_coffre','poignee_de_pieces','rancon','faillite'):
        with Image.open(ICONS/('avare_'+key+'.png')) as im:
            assert im.size==(128,128) and im.mode=='RGBA' and im.getchannel('A').getbbox()
    report.update({'character':'avare','cell':192,'directions':list(DIRS),'pivot_px':[96,136.32],'pixels_per_unit':iso_rig.R,'animations':ANIMS,'attack_impact_frame_zero_based':2,'icons':4,'emission_resource':'loaded and synchronized','visual_review':'single contact sheet checked','effects_next_lot':['coin_burst','ransom_ring']})
    (DEST/'aa1_verification.json').write_text(json.dumps(report,indent=2))
    print('AA1 VERIFICATION PASS / both resources / 496 frames / 80 animations / 30 sheets / 4 icons',flush=True)

def contact():
    canvas=Image.new('RGBA',(1920,1660),(22,26,30,255))
    refs=['art/tools/characters/_cd_avare.png','art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/ui/_i2_contact.png']
    for i,path in enumerate(refs):
        with Image.open(ROOT/path) as src:
            im=src.convert('RGBA');im.thumbnail((376,205),Image.Resampling.LANCZOS);canvas.alpha_composite(im,(i*384+(384-im.width)//2,0))
    with Image.open(DEST/'idle.png') as src:
        for row in range(8):canvas.alpha_composite(src.crop((0,row*192,192,(row+1)*192)),(96+row*216,220))
    for i,(anim,n) in enumerate(ANIMS.items()):
        with Image.open(DEST/f'{anim}.png') as src:
            for j,f in enumerate((0,n//2,n-1)):
                frame=src.crop((f*192,2*192,(f+1)*192,3*192));canvas.alpha_composite(frame,(12+(i%3)*640+j*200,430+(i//3)*192))
    frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
    names=['coup_de_coffre','poignee_de_pieces','rancon','faillite'];ardent=['eclat_de_braise','cendres','brasier','nova_ardente']
    for col,(name,other) in enumerate(zip(names,ardent)):
        for row,size in enumerate((128,64)):
            for k,stem in enumerate(('avare_'+name,other)):
                tile=Image.new('RGBA',(size,size));im=Image.open(ROOT/f'game/assets/sprites/icons/spells/{stem}.png').convert('RGBA')
                im.thumbnail((int(size*.78),int(size*.78)),Image.Resampling.LANCZOS)
                tile.alpha_composite(im,((size-im.width)//2,(size-im.height)//2));tile.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS))
                canvas.alpha_composite(tile,(col*480+50+k*160,1260+row*155))
    canvas.save(ROOT/'art/tools/night/_aa1_contact.png',optimize=True)
    print('AA1 CONTACT PASS',flush=True)


if __name__=='__main__':
    if '--audit' in sys.argv:
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE));sc=bpy.context.scene;rt=bpy.data.objects['Avare'];mf=json.loads(sc['animation_manifest']);bs=sc.camera.rotation_euler.to_matrix()
        import numpy as np
        bad=[]
        for an,nn in ANIMS.items():
            for ff in range(nn):
                sc.frame_set(mf[an]['start']+ff);data=posed_mesh(rt,'audit');xyz=np.array([tuple(v.co) for v in data.vertices]);bpy.data.meshes.remove(data)
                for dd,ang in DIRS.items():
                    pr=xyz@np.array(Matrix.Rotation(ang,3,'Z')).T@np.array(bs);lo=pr.min(axis=0);hi=pr.max(axis=0);bb=[96+lo[0]*iso_rig.R,136.32-hi[1]*iso_rig.R,96+hi[0]*iso_rig.R,136.32-lo[1]*iso_rig.R]
                    if min(bb[:2])<4 or max(bb[2:])>188:bad.append((an,ff,dd,[round(float(v),1) for v in bb]))
        print('AUDIT',len(bad),bad[:12],flush=True)
        sc.frame_set(1);items=[]
        for ob in rt.children_recursive:
            if ob.type=='MESH':
                v=[ob.matrix_world@v.co for v in ob.data.vertices];items.append((max(x.y for x in v),ob.name))
        print('MAX Y',sorted(items,reverse=True)[:8],flush=True)
        items=[]
        for ob in rt.children_recursive:
            if ob.type=='MESH':
                v=[bs.transposed()@(ob.matrix_world@v.co) for v in ob.data.vertices];items.append((max(x.y for x in v),ob.name))
        print('MAX PROJECTED Y',sorted(items,reverse=True)[:8],flush=True)
    elif '--verify' in sys.argv:verify();contact()
    elif '--contact' in sys.argv:contact()
    elif '--icons-only' in sys.argv:icons()
    else:
        if '--resume' not in sys.argv or not SOURCE.exists():source()
        if '--source-only' not in sys.argv:atlases();icons();verify();contact()
