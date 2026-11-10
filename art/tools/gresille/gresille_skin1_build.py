"""Fulgurite skin: unchanged GR1d geometry and animation; materials only. Native CREA renders; resumable raw CEL/AOV pairs.
Blender: -- --render [--test]. Python: --finish / --verify.
"""
import sys, math, json, hashlib, shutil
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel'),str(Path(__file__).parent)]
RAW=ROOT/'art/renders/gresille/skin1_frames'
DEST=ROOT/'game/assets/sprites/characters/gresille/skins/gresille_skin1'
SOURCE=ROOT/'art/blender/characters/gresille_skin1.blend'
DIRS=['e','se','s','sw','w','nw','n','ne']
ANIMS={'idle':8,'run':8,'attack':4,'cast':5,'ground':6,'call':8,'death':6}
RENDER_ANIMS=list(ANIMS)
IMPACTS={'attack':2,'cast':3,'ground':3,'call':2}
CELL=192
PIVOT=[96,136.32]

def present():
    return {a:n for a,n in ANIMS.items() if all((RAW/f'{a}_{d}_{f:02d}{su}.png').exists() for d in DIRS for f in range(n) for su in ('','_e'))}

def manifest():
    return dict(character='gresille',lot='GR1c',cell=CELL,pivot=PIVOT,directions=DIRS,
        rig=dict(name='CREA',elevation=30,px_per_unit=64*math.sqrt(2),height_u=1.35),
        animations={a:dict(frames=n,fps=10 if a in ('idle','run') else 12,loop=a in ('idle','run','call'),impact=IMPACTS.get(a),source_start=1+20*list(ANIMS).index(a),**({'loop_from':3} if a=='call' else {})) for a,n in present().items()},
        planned_animations=ANIMS,aliases={'cast_ult':'call'} if 'call' in present() else {},normal_maps=False,emission_scale=.5,accent='#B9A6FF',unique_renders=sum(present().values())*8)

def resources():
    base=ROOT/'game/assets/sprites/characters/gresille/gresille.tres'
    text=base.read_text(encoding='utf8').replace('res://assets/sprites/characters/gresille/', 'res://assets/sprites/characters/gresille/skins/gresille_skin1/')
    assert 'CanvasTexture' not in text and 'normal_texture' not in text
    (DEST/'gresille_skin1.tres').write_text(text,encoding='utf8')


def finish():
    from PIL import Image
    DEST.mkdir(parents=True,exist_ok=True)
    for a,n in present().items():
        for su in ('','_e'):
            tile=CELL//2 if su else CELL
            sheet=Image.new('RGBA',(n*tile,8*tile))
            for row,d in enumerate(DIRS):
                for f in range(n):
                    with Image.open(RAW/f'{a}_{d}_{f:02d}{su}.png') as im:
                        assert im.size==(CELL,CELL)
                        frame=im.resize((tile,tile),Image.Resampling.LANCZOS) if su else im
                        sheet.paste(frame,(f*tile,row*tile))
            sheet.save(DEST/f'{a}{su}.png',optimize=True,compress_level=9)
    for su in ('','_e'):
        p=RAW/f'portrait{su}.png'
        if p.exists():
            with Image.open(p) as im:im.save(DEST/p.name,optimize=True,compress_level=9)
    # Existing SpriteFrames and manifest remain byte-for-byte unchanged.
    if sum(p.stat().st_size for p in DEST.glob('*.png'))>2_500_000:
        import subprocess,zipfile
        exe=ROOT/'art/tools/ardent_pngquant/pngquant.exe'
        if not exe.exists():
            exe.parent.mkdir(parents=True,exist_ok=True)
            with zipfile.ZipFile(ROOT/'art/blender/characters/ardent_pngquant.zip') as z:
                for name in z.namelist():
                    if name.endswith(('.exe','.dll')):(exe.parent/Path(name).name).write_bytes(z.read(name))
        for p in DEST.glob('*.png'):
            if p.stem.endswith('_e'):continue
            subprocess.run([str(exe),'256','--quality=85-100','--speed','1','--nofs','--force','--ext','.png',str(p)],check=True,capture_output=True)
    resources()
    import contextlib,io
    with contextlib.redirect_stdout(io.StringIO()):verify()
    import gresille_skin1_verify
    gresille_skin1_verify.main()


def verify():
    from PIL import Image, ImageStat
    assert not list(DEST.glob('*_n.png'))
    tres=(DEST/'gresille_skin1.tres').read_text()
    assert 'CanvasTexture' not in tres and 'normal_texture' not in tres
    margin=192;count=0
    for a,n in present().items():
        with Image.open(DEST/f'{a}.png') as im,Image.open(DEST/f'{a}_e.png') as em:
            im=im.convert('RGBA');em=em.convert('RGBA')
            assert im.size==(192*n,1536) and em.size==(96*n,768)
            for row in range(8):
                sig=set();feet=[]
                for f in range(n):
                    fr=im.crop((f*192,row*192,(f+1)*192,(row+1)*192));box=fr.getchannel('A').getbbox()
                    assert box,(a,row,f,'empty')
                    m=min(box[0],box[1],192-box[2],192-box[3]);margin=min(margin,m)
                    assert m>=3,(a,row,f,'clipping',box)
                    assert min(fr.getchannel('A').getextrema())==0
                    data=fr.get_flattened_data() if hasattr(fr,'get_flattened_data') else fr.getdata()
                    pixels=[p for p in data if p[3]>200]
                    lum=[max(p[:3]) for p in pixels];assert max(lum)-min(lum)>65
                    sig.add(hashlib.sha256(fr.tobytes()).digest());feet.append(box[3])
                    er=em.crop((f*96,row*96,(f+1)*96,(row+1)*96))
                    peak=max(c.getextrema()[1] for c in er.split()[:3])
                    assert peak==0 if a=='death' and f==n-1 else peak>30,(a,row,f,'emission')
                    count+=1
                assert len(sig)==n,(a,row,'duplicate phases')
                if a not in ('run','death'):assert max(feet)-min(feet)<=1,(a,row,'sliding feet')
            for f in range(n):assert len({hashlib.sha256(im.crop((f*192,r*192,(f+1)*192,(r+1)*192)).tobytes()).digest() for r in range(8)})==8
    for su,size in [('',(256,256)),('_e',(128,128))]:
        with Image.open(DEST/f'portrait{su}.png') as im:assert im.size==size and im.getbbox()
    weight=sum(p.stat().st_size for p in DEST.glob('*.png'))
    assert weight<=2_500_000,weight
    assert count==360,count
    print(f'GR1d PASS: {count} frames; margin {margin}px; PNG {weight} bytes; native 192; emission half; no normals',flush=True)

# PBR settings retained as metadata; the shared CEL pass uses the explicit ramps below.
SKIN={
 'wool':('16181C','25282F','3A3E46',0,.20),
 'rubber':('C9CBC4','E0E1DA','F0F0EA',0,.45),
 'glass':('0E1218','1B222B','2A323C',.3,.22),
 'edge':('8E9096','AFB2B9','C9CCD2',.9,.24),
 'copper':('6E7178','91959C','B4B8BF',.9,.30),
 'patina':('6E7178','91959C','B4B8BF',.9,.30),
 'staff_bronze':('14161A','202329','2A2D33',.1,.92),
 'staff_edge':('24272D','4C515B','777E89',.45,.80),
}

def skin_materials(g):
    M=g.materials()
    for key,(a,b,c,metal,rough) in SKIN.items():
        if key.startswith('staff_'):continue
        ma=g.worn('Fulgurite / '+key,a,c,metal,rough)
        ma['gresille_surface']='gutta-percha lisse' if key=='rubber' else 'Fulgurite / '+key
        M[key]=ma
    return M

def skin_finish(g,M):
    for key,(a,b,c,metal,rough) in SKIN.items():
        ma=M[key];ma.name='Fulgurite / '+key
        ma['metallic']=metal;ma['roughness']=rough
        ramp=ma.node_tree.nodes.get('CEL tones')
        if ramp:
            for stop,h in zip(ramp.color_ramp.elements,(a,b,c)):stop.color=g.rgb(h)
        for node in ma.node_tree.nodes:
            if node.bl_idname=='ShaderNodeMapRange' and key=='wool':
                node.inputs['To Min'].default_value=.94;node.inputs['To Max'].default_value=1.02
            if node.bl_idname=='ShaderNodeBump' and key.startswith('staff_'):
                node.inputs['Strength'].default_value=.42;node.inputs['Distance'].default_value=.003
            if node.bl_idname=='ShaderNodeTexNoise' and key.startswith('staff_'):
                node.inputs['Scale'].default_value=115;node.inputs['Detail'].default_value=3

def build():
    import bpy
    import iso_rig,cel_style as cel,gresille_build as g
    from mathutils import Vector,Quaternion
    import random
    random.seed(73)
    RAW.mkdir(parents=True,exist_ok=True)
    s=iso_rig.create_rig('CREA',CELL,target=(0,0,0));s.camera.data.shift_y=.21
    s.render.resolution_x=s.render.resolution_y=CELL
    s.render.threads_mode='FIXED';s.render.threads=6;s.render.fps=10
    g.RETOUCH['wool']=('16181C','3A3E46')
    M=skin_materials(g);body=g.build_body(M);body.name='Gresille_pelvis'
    g.build_variant(body,'C',M)
    for ob in body.children:
        if ob.type=='CURVE' and ob.name.startswith(('Arc dans','Filament latéral','Charge isolateur')):
            ob.data.bevel_depth*=1.6
        if ob.type=='MESH' and ob.name.startswith('Arc dans'):
            for i in range(0,len(ob.data.vertices),6):
                ring=list(ob.data.vertices)[i:i+6];c=sum((v.co for v in ring),Vector())/6
                for v in ring:v.co=c+(v.co-c)*1.6
    facing=g.empty('Gresille_facing');body.parent=facing
    def node(name,pos,parent):
        ob=g.empty(name);ob.location=pos;ob.parent=parent;return ob
    torso=node('Gresille_torso',(0,0,.84),body)
    head=node('Gresille_head',(0,0,.30),torso)
    bpy.context.view_layer.update()
    def attach(ob,parent):
        mat=ob.matrix_world.copy();ob.parent=parent;ob.matrix_world=mat
    def center(ob):
        pts=[ob.matrix_world@Vector(c) for c in ob.bound_box]
        return sum(pts,Vector())/8
    limbs={}
    for side in [-1,1]:
        tag='L' if side==-1 else 'R';fy=-.025 if side==1 else .025
        hip=Vector((side*.092,.012,.758));knee=Vector((side*.104,-.022+fy,.49));ankle=Vector((side*.104,fy,.135))
        shoulder=Vector((side*.128,.004,1.075));elbow=Vector((side*.201,-.025,.919));wrist=Vector((side*.244,-.103,.776))
        th=node('Thigh_'+tag,hip,body);sh=node('Calf_boot_'+tag,knee-hip,th)
        arm=node('Upper_arm_'+tag,shoulder-Vector((0,0,.84)),torso);fore=node('Forearm_glove_'+tag,elbow-shoulder,arm)
        hand=node('Hand_socket_'+tag,wrist-elbow,fore)
        limbs[side]=(th,sh,arm,fore,hand,hip,knee,ankle,shoulder,elbow,wrist)
    bpy.context.view_layer.update()
    # Preserve source face, lattice cape, rack and all three detailed jars.
    for ob in list(body.children):
        if ob.type not in ('MESH','CURVE'):continue
        n=ob.name;c=center(ob);side=1 if c.x>0 else -1;ls=limbs[side]
        if n.startswith(('Jambe longue','Manche sans')):
            bpy.data.objects.remove(ob,do_unlink=True);continue
        if n.startswith(('Câble gainé','Collier de câble')):
            bpy.data.objects.remove(ob,do_unlink=True);continue
        if n.startswith(('Botte','Semelle','Lèvre souple','Couture arrière','Plis obliques')):attach(ob,ls[1])
        elif n.startswith(('Plis de coude','Manchette','Paume','Doigt','Couture de doigt','Pouce')):attach(ob,ls[3])
        elif c.z>1.145 and (abs(c.x)<.115 and c.y<.105) and not n.startswith(('Leyde','Cerclage','Arc dans','Charge isolateur','Borne','Montant','Traverse','Reflet de verre')):attach(ob,head)
        elif c.z>.85:attach(ob,torso)
    bpy.context.view_layer.update()
    for side,ls in limbs.items():
        th,sh,arm,fore,hand,hip,knee,ankle,shoulder,elbow,wrist=ls
        fy=-.025 if side==1 else .025;x=side*.092
        pieces=[('Femur',[(hip,.081,.086),((x+side*.005,.006,.675),.077,.077),((x+side*.010,-.014+fy,.565),.060,.061),(knee,.050,.051)],th),
                ('Calf',[(knee,.050,.051),((x+side*.013,-.014+fy,.435),.052,.052),((x+side*.012,.004+fy,.35),.053,.055)],sh),
                ('Sleeve_upper',[(shoulder,.042,.045),((side*.157,.002,1.048),.038,.040),((side*.178,-.005,.985),.034,.036),(elbow,.031,.033)],arm),
                ('Sleeve_fore',[(elbow,.031,.033),((side*.222,-.058,.858),.029,.029),((side*.239,-.088,.798),.025,.026)],fore)]
        for name,sections,parent in pieces:
            ob=g.sweep(name+str(side),sections,M['wool'],None);attach(ob,parent)
        for name,p,r,parent in [('Knee_join',knee,.050,sh),('Elbow_join',elbow,.031,fore)]:
            ob=g.ell(name+str(side),p,(r,r,r),M['wool']);attach(ob,parent)
    # Rod socket is on the anatomical right; grip remains at .70 of the .90 shaft.
    staff=node('Short_rod_right_socket',(0,0,0),limbs[1][4])
    accent=next(m for m in bpy.data.materials if m.get('rainfall_emissive'))
    M['staff_bronze']=M['copper'].copy();M['staff_edge']=M['edge'].copy()
    g.sweep('Short_rod_bronze',[((0,0,-.70),.024,.024),((0,0,.18),.024,.024)],M['staff_bronze'],staff,N=12)
    for z in [.05,.10,.15]:
        ob=g.loft('Blue_glass_insulator',[(z-.013,.024,.024,0),(z-.005,.058,.058,0),(z+.006,.058,.058,0),(z+.014,.024,.024,0)],M['glass'],staff,N=24)
        g.torus('Lilac_insulator_ring',(0,0,z+.007),.054,.010,accent,staff)
    g.sweep('Polished_point',[((0,0,.18),.024,.024),((0,0,.28),.0008,.0008)],M['staff_edge'],staff,N=12)
    tip=g.ell('Attack_lilac_tip',(0,0,.257),(.015,.015,.024),accent,staff)
    charged=[]
    for i,x in enumerate([-.050,-.025,0,.025,.050]):
        charged.append(g.tube('Call_rising_lilac_lock',[(x,-.024,.21),(x*1.16,-.028,.28),(x*1.35,-.022,.36+(i%2)*.025)],.009,accent,head))
    for x,y,base,r,h in [(-.177,.115,1.033,.057,.36),(0,.139,1.065,.059,.38),(.177,.115,1.033,.057,.36)]:
        for z in (base+h*.30,base+h*.63):
            ob=g.torus('Call_full_Leyde',(x,y,z),r*1.04,.007,accent,None);attach(ob,torso);charged.append(ob)
    glow_objects=[o for o in bpy.data.objects if o.type in ('MESH','CURVE') and any(m and m.get('rainfall_emissive') for m in o.data.materials)]
    cables={side:g.tube('Dynamic_sheathed_cable_'+str(side),[(0,0,0)]*5,.012,M['rubber'],body) for side in [-1,1]}
    def solve(upper,lower,start,joint,end,target,pole):
        a=(joint-start).length;b=(end-joint).length;v=target-start
        dist=min(a+b-.0001,max(abs(a-b)+.0001,v.length));direction=v.normalized()
        p=Vector(pole);p-=direction*p.dot(direction);p.normalize()
        along=(a*a-b*b+dist*dist)/(2*dist)
        mid=start+direction*along+p*math.sqrt(max(0,a*a-along*along))
        q=(joint-start).rotation_difference(mid-start);upper.rotation_mode='QUATERNION';upper.rotation_quaternion=q
        lower.rotation_mode='QUATERNION';lower.rotation_quaternion=(end-joint).rotation_difference(q.inverted()@(start+direction*dist-mid))
    def pose(a,f,n,bake=True):
        t=f/n;phase=math.tau*((f-2)/6 if a=='call' and f>=2 else t);breath=math.sin(phase);stride=math.sin(phase)
        action={'attack':[0,1,.65,.12],'cast':[0,.45,1,.7,.10],'ground':[0,.45,1,.85,.32,.08]}.get(a,[0]*n)[f]
        body.location=(0,0,0);body.rotation_euler=(0,0,0)
        torso.location=(0,0,.84);torso.rotation_euler=(0,0,0);head.rotation_euler=(0,0,0)
        if a=='idle':
            torso.scale=(1+.008*breath,1+.014*breath,1+.008*breath)
            torso.rotation_euler.y=.012*math.cos(phase)
            head.rotation_euler.z=.015*math.cos(phase)
        else:torso.scale=(1,1,1)
        if a=='run':
            body.location.z=.026*(1-math.cos(phase*2))
            torso.rotation_euler=(.11,.025*math.cos(phase),.035*stride)
            head.rotation_euler.z=.02*math.cos(phase)
        if a=='call':
            torso.rotation_euler=(.025*breath,0,.045*math.cos(phase))
            head.rotation_euler=(-.09-.025*breath,.04*math.cos(phase),0)
        if a=='death':
            fall=[0,0,.12,.48,.82,1][f];body.rotation_euler.y=-math.pi*.49*fall
            torso.rotation_euler.x=[0,.30,.48,.35,.18,.12][f]
            body.location.x=.58*fall;body.location.z=-.28*min(1,f)
        bpy.context.view_layer.update()
        for side,ls in limbs.items():
            th,sh,arm,fore,hand,hip,knee,ankle,shoulder,elbow,wrist=ls
            th.rotation_mode=sh.rotation_mode='QUATERNION';th.rotation_quaternion=sh.rotation_quaternion=Quaternion()
            if a=='run':
                swing=stride*side;target=ankle+Vector((0,-.25*swing,.10*max(0,swing)-body.location.z))
                solve(th,sh,hip,knee,ankle,target,(0,-1,0))
            elif a=='death':
                th.rotation_quaternion=Quaternion((1,0,0),[0,-.85,-1.10,-.85,-.65,-.58][f]);sh.rotation_quaternion=Quaternion((1,0,0),[0,1.65,1.9,1.6,1.3,1.2][f])
            target=wrist.copy()
            if a=='idle' and side==1:target=Vector((.275,-.135,.723))
            if a=='run':target+=Vector((0,.115*stride*side,.035+.035*stride*side))
            if a=='attack' and side==1:target=wrist.lerp(shoulder+Vector((.055,-.315,-.04)),action)
            if a=='cast' and side==-1:target=wrist.lerp(shoulder+Vector((-.05,-.315,.025)),action)
            if a=='cast' and side==1:target=wrist+Vector((.035,.12*action,.02*action))
            if a=='ground':target=Vector((.035,-.20,.73+(.085 if side==-1 else 0)+.15*(1-action)))
            if a=='call':
                lift=[0,.55,1,1,1,1,1,1][f]
                target=wrist.lerp(Vector((.025,-.14,1.335+side*.035+.006*breath)),lift)
            # Targets are in original body coordinates; torso motions are removed for IK.
            bpy.context.view_layer.update()
            if a=='idle' and side==1:
                target=torso.matrix_world.inverted()@(body.matrix_world@target)+Vector((0,0,.84))
            solve(arm,fore,shoulder,elbow,wrist,target,(side, .3,0))
        bpy.context.view_layer.update()
        # Planted idle rod keeps its tip and attitude fixed despite breathing.
        if a=='idle':
            grip=limbs[1][4].matrix_world.translation
            desired=body.matrix_world.copy();desired.translation=grip
            staff.matrix_world=desired
        else:
            staff.location=(0,0,0);staff.rotation_euler=(.35 if a=='run' else -.35 if a=='attack' else 0,.12,0)
        if a in ('attack','cast','ground'):
            grip=limbs[1][4].matrix_world.translation
            direction=Vector((0,-1,.08)) if a=='attack' else Vector((.12,.45,1)) if a=='cast' else Vector((0,0,1))
            staff.matrix_world=direction.to_track_quat('Z','Y').to_matrix().to_4x4();staff.matrix_world.translation=grip
        if a=='call':
            staff.matrix_world=facing.matrix_world.copy();staff.matrix_world.translation=limbs[1][4].matrix_world.translation-Vector((0,0,.12*min(1,f/2)))
        if a=='death':
            bpy.context.view_layer.update()
            floor=min((o.matrix_world@Vector(c)).z for o in body.children_recursive if o.type=='MESH' and o not in staff.children_recursive for c in o.bound_box)
            body.location.z+=.025-floor;bpy.context.view_layer.update()
            if f>=2:
                direction=Vector((.91,.40,.035 if f==2 else 0))
                staff.matrix_world=facing.matrix_world@direction.to_track_quat('Z','Y').to_matrix().to_4x4()
                staff.matrix_world.translation=facing.matrix_world@Vector((.05,-.32,.095))
        for ob in glow_objects:
            visible=not (a=='death' and f==n-1)
            if ob in charged:visible=visible and a=='call' and f>=1
            ob.scale=(1,1,1) if visible else (.00001,.00001,.00001)
            if ob in charged and visible and ob.name.startswith('Call_rising'):ob.scale=(1,1,.55+.45*min(1,f/2)+.06*breath)
            if bake:ob.keyframe_insert('scale')
        tip.scale=(1,1,1) if a=='attack' and action>.5 else (.001,.001,.001)
        if bake:tip.keyframe_insert('scale')
        bpy.context.view_layer.update()
        for side,cable in cables.items():
            grip=body.matrix_world.inverted()@limbs[side][4].matrix_world.translation
            top=body.matrix_world.inverted()@(torso.matrix_world@Vector((side*.177,.115,1.393-.84)))
            pts=[top,top+Vector((side*.065,-.015,-.15)),grip+Vector((side*.075,.085,.18)),grip+Vector((side*.035,-.02,.07)),grip]
            if a=='call':pts=[top,top+Vector((side*.04,-.02,-.12)),grip+Vector((side*.04,.07,-.08)),grip+Vector((side*.025,.02,-.035)),grip]
            for p,co in zip(cable.data.splines[0].bezier_points,pts):
                p.co=co
                if bake:p.keyframe_insert('co')
        if bake:
            for ob in [body,torso,head,staff,*[o for ls in limbs.values() for o in ls[:5]]]:
                for prop in ('location','rotation_quaternion' if ob.rotation_mode=='QUATERNION' else 'rotation_euler','scale'):ob.keyframe_insert(prop)
    for ai,(a,n) in enumerate(ANIMS.items()):
        start=1+20*ai;s.timeline_markers.new(a,frame=start)
        for f in range(n):s.frame_set(start+f);pose(a,f,n)
    s.frame_start=1;s.frame_end=126;s['GR1_manifest']=json.dumps(manifest())
    cel.install('creature',normals=False);cel.setup_scene(s,samples=16);cel.toon_materials('creature');g.surface_finish(M)
    skin_finish(g,M)
    def accent_base(path):
        tree=getattr(s,'node_tree',None)
        if tree is None:tree=bpy.data.node_groups.new('Gresille_CEL','CompositorNodeTree');s.compositing_node_group=tree
        tree.nodes.clear();nodes=tree.nodes;links=tree.links
        if not any(x.name=='Image' and x.in_out=='OUTPUT' for x in tree.interface.items_tree):tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
        rl=nodes.new('CompositorNodeRLayers');out=nodes.new('NodeGroupOutput');links.new(rl.outputs['Image'],out.inputs['Image'])
        file=nodes.new('CompositorNodeOutputFile');file.directory=str(path.parent);file.file_name=path.stem+'_e__';file.file_output_items.new('RGBA','Image')
        file.format.media_type='IMAGE';file.format.file_format='PNG';file.format.color_mode='RGBA';file.format.color_depth='8';links.new(rl.outputs[cel.AOV],file.inputs[0])
    # Preserve identical shaft and coat readability through native CEL ink.
    layer=s.view_layers[0];aov=layer.aovs.add();aov.name='Staff_readability';aov.type='VALUE'
    for key in ('staff_bronze','staff_edge','wool'):
        out=M[key].node_tree.nodes.new('ShaderNodeOutputAOV');out.aov_name='Staff_readability';out.inputs['Value'].default_value=1
    output=RAW/'current.png';cel.cel_passes(output,'creature',base_configure=accent_base,normals=False)
    tree=getattr(s,'node_tree',None) or s.compositing_node_group
    rl=next(n for n in tree.nodes if n.bl_idname=='CompositorNodeRLayers')
    out=next(n for n in tree.nodes if n.bl_idname=='NodeGroupOutput')
    ink=out.inputs['Image'].links[0].from_socket
    amount=tree.nodes.new('ShaderNodeMath');amount.operation='MULTIPLY';amount.inputs[1].default_value=.85
    delta=tree.nodes.new('ShaderNodeVectorMath');delta.operation='SUBTRACT'
    scale=tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE'
    add=tree.nodes.new('ShaderNodeVectorMath');add.operation='ADD'
    alpha=tree.nodes.new('CompositorNodeSetAlpha');alpha.inputs['Type'].default_value='Replace Alpha'
    tree.links.new(rl.outputs['Staff_readability'],amount.inputs[0])
    tree.links.new(rl.outputs['Image'],delta.inputs[0]);tree.links.new(ink,delta.inputs[1])
    tree.links.new(delta.outputs[0],scale.inputs[0]);tree.links.new(amount.outputs[0],scale.inputs['Scale'])
    tree.links.new(ink,add.inputs[0]);tree.links.new(scale.outputs[0],add.inputs[1])
    tree.links.new(add.outputs[0],alpha.inputs['Image']);tree.links.new(rl.outputs['Alpha'],alpha.inputs['Alpha'])
    tree.links.new(alpha.outputs[0],out.inputs['Image'])
    s.render.resolution_x=s.render.resolution_y=CELL
    s.frame_set(1);facing.rotation_euler.z=iso_rig.DIRECTIONS['se'];bpy.context.view_layer.update()
    if '--preflight' in sys.argv:
        from bpy_extras.object_utils import world_to_camera_view
        failures=[];minimum=192;worst={}
        for ai,(a,n) in enumerate(ANIMS.items()):
            for d in DIRS:
                facing.rotation_euler.z=iso_rig.DIRECTIONS[d]
                for f in range(n):
                    s.frame_set(1+20*ai+f);bpy.context.view_layer.update()
                    points=[world_to_camera_view(s,s.camera,o.matrix_world@Vector(c)) for o in facing.children_recursive if o.type in ('MESH','CURVE') and min(o.scale)>.0001 for c in o.bound_box]
                    margin=min(min(p.x,p.y,1-p.x,1-p.y)*192 for p in points);minimum=min(minimum,margin)
                    if margin<3:failures.append((a,d,f,round(margin,2)))
                    if margin<worst.get(a,(192,))[0]:
                        culprit=min((min(p.x,p.y,1-p.x,1-p.y)*192,o.name) for o in facing.children_recursive if o.type in ('MESH','CURVE') and min(o.scale)>.0001 for p in [world_to_camera_view(s,s.camera,o.matrix_world@Vector(c)) for c in o.bound_box])
                        worst[a]=(round(margin,2),d,f,culprit[1])
        print('GR1d PREFLIGHT',worst,flush=True);return
    SOURCE.parent.mkdir(parents=True,exist_ok=True);s.render.filepath=str(output)
    # Avoid backups; only the dedicated skin source is written.
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    from PIL import Image
    def render_pair(p,size):
        s.render.resolution_x=s.render.resolution_y=size;s.render.filepath=str(output)
        for stale in RAW.glob('current_e__*.png'):stale.unlink()
        bpy.ops.render.render(write_still=True)
        accents=list(RAW.glob('current_e__*.png'));assert len(accents)==1
        for src,dest in [(output,p),(accents[0],p.with_name(p.stem+'_e.png'))]:
            with Image.open(src) as im:
                assert im.size==(size,size)
                final=im.convert('RGBA')
                if p.stem=='portrait' and src!=output:final=final.resize((128,128),Image.Resampling.LANCZOS)
                final.save(dest,optimize=True,compress_level=9)
            src.unlink()
    # First frame is always idle_se, independently validated before the batch.
    test=RAW/'idle_se_00.png'
    if not test.exists() or not test.with_name('idle_se_00_e.png').exists():render_pair(test,CELL)
    with Image.open(test) as im:
        box=im.getchannel('A').getbbox();assert box and min(*box[:2],192-box[2],192-box[3])>=3,box
    if '--test' in sys.argv:
        print('GR1a TEST PASS: idle_se_00 192x192; alpha margin >=3',flush=True);return
    for a in RENDER_ANIMS:
        n=ANIMS[a];ai=list(ANIMS).index(a)
        for d in DIRS:
            for f in range(n):
                p=RAW/f'{a}_{d}_{f:02d}.png'
                if p.exists() and p.with_name(p.stem+'_e.png').exists():continue
                s.frame_set(1+20*ai+f);facing.rotation_euler.z=iso_rig.DIRECTIONS[d];bpy.context.view_layer.update();render_pair(p,CELL)
    if not all((RAW/f'portrait{su}.png').exists() for su in ('','_e')):
        s.frame_set(1);facing.rotation_euler.z=iso_rig.DIRECTIONS['se'];bpy.context.view_layer.update()
        camera_settings=(s.camera.data.ortho_scale,s.camera.data.shift_y,s.camera.location.z)
        s.camera.data.ortho_scale=1.72;s.camera.data.shift_y=0;s.camera.location.z+=.73
        render_pair(RAW/'portrait.png',256)
        s.camera.data.ortho_scale,s.camera.data.shift_y,s.camera.location.z=camera_settings
    finish()
    s['GR1_manifest']=json.dumps(manifest())
    s.frame_set(1);facing.rotation_euler.z=iso_rig.DIRECTIONS['se']
    s.render.resolution_x=s.render.resolution_y=CELL
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))

if __name__=='__main__':
    if '--render' in sys.argv:build()
    elif '--finish' in sys.argv:finish()
    elif '--verify' in sys.argv:verify()
