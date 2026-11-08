"""Targeted Tocsin actions; existing T1/T3 geometry, cel renderer and T5 packing."""
from pathlib import Path
import sys, json, hashlib, re, shutil, math, os, gzip
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT/'game/assets/sprites/characters/tocsin'
WORK = ROOT/'art/blender/cel/tocsin_actions'
OUT = ROOT/'art/renders/feel_sorts2/tocsin_actions'
CARILLON = '--skin-carillon' in sys.argv
if CARILLON:
    WORK = WORK/'skins/tocsin_skin1'
    OUT = ROOT/'art/renders/feel_sorts2/tocsin_skin_actions'
    WORK.mkdir(parents=True,exist_ok=True)
ANIMS = {'attack':6, 'cast':6, 'throw_arm_l':4, 'throw_arm_r':4, 'throw_head':6}
F60 = {'attack':[3,3,2,12,14,22], 'cast':[4,4,4,14,16,26],
       'throw_arm_l':[6,6,6,24], 'throw_arm_r':[6,6,6,24], 'throw_head':[8,8,8,10,16,28]}
HITS = {'attack':3, 'cast':3, 'throw_arm_l':2, 'throw_arm_r':2, 'throw_head':3}
PARTS = ['torso','head','neck_steam','arm_l','arm_r','leg_l','leg_r']
DIRS = ['e','se','s','sw','w','nw','n','ne']
TARGETS = set(ANIMS)|{'cast_ult'}
sys.path[:0] = [str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools')]

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def allowed(p): return p.name.removesuffix('.png').removesuffix('_e') in TARGETS

def blocks(s):
    return {m[1] : m[0] for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n.*?(?=\n\[|\Z)',s,re.S)}

def load_frames(anim, direction, resource=None):
    from PIL import Image
    s=(resource or BASE/'tocsin.tres').read_text()
    ext={m[2]:ROOT/'game'/m[1].removeprefix('res://') for m in re.finditer(r'path="([^"]+)" id="([^"]+)"',s)}
    clip=next((x for x in s.splitlines() if '"name": &"'+anim+'_'+direction+'"' in x),None)
    if clip is None:
        # Legacy full-body resources omit throws; reconstruct their layered fallback.
        orders=json.loads((BASE/'layers_order.json').read_text())['orders'][direction]
        frames=None
        for layer in orders:
            if layer=='neck_steam':continue
            tiles=load_frames(anim,direction,BASE/f'tocsin_{layer}.tres')
            if frames is None:frames=[Image.new('RGBA',(192,192)) for _ in tiles]
            for frame,tile in zip(frames,tiles):frame.alpha_composite(tile)
        return frames
    bs=blocks(s); frames=[]
    for rid in re.findall(r'"texture": SubResource\("([^"]+)"\)',clip):
        b=bs[rid]; eid=re.search(r'atlas = ExtResource\("([^"]+)"\)',b)[1]
        x,y,w,h=map(lambda x:int(float(x)),re.search(r'region = Rect2\(([^)]+)\)',b)[1].split(','))
        margin=re.search(r'margin = Rect2\(([^)]+)\)',b)
        mx,my,mw,mh=map(lambda x:int(float(x)),margin[1].split(',')) if margin else (0,0,0,0)
        im=Image.open(ext[eid]).convert('RGBA'); tile=Image.new('RGBA',(w+mw,h+mh))
        tile.paste(im.crop((x,y,x+w,y+h)),(mx,my)); frames.append(tile)
    return frames

def outside_files():
    # Names only; never writes outside this worktree.
    parent=ROOT.parents[2]; result=[]; seen=set()
    for folder,dirs,files in os.walk(parent):
        real=os.path.normcase(os.path.realpath(folder))
        if real in seen:dirs[:]=[];continue
        seen.add(real)
        dirs[:]=[d for d in dirs if Path(folder)/d != ROOT and not os.path.islink(Path(folder)/d)
                 and not os.path.isjunction(Path(folder)/d)]
        result.extend(str(Path(folder)/f) for f in files)
    return result

def baseline():
    from PIL import Image
    OUT.mkdir(parents=True,exist_ok=True); WORK.mkdir(parents=True,exist_ok=True)
    assert not (OUT/'before.json').exists(), 'baseline already captured'
    data={'png':{},'resources':{}}
    for p in BASE.rglob('*.png'):
        if 'skins' in p.relative_to(BASE).parts: continue
        rel=p.relative_to(BASE).as_posix()
        data['png'][rel]={'sha':sha(p),'size':list(Image.open(p).size),'bytes':p.stat().st_size}
        if allowed(p):
            q=OUT/'backup'/rel; q.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,q)
    for p in list(BASE.glob('tocsin*.tres'))+[BASE/'atlas_manifest.json',BASE/'resource_animations.json']:
        data['resources'][p.name]=sha(p); shutil.copy2(p,OUT/p.name)
    (OUT/'before.json').write_text(json.dumps(data))
    with gzip.open(OUT/'outside_before.json.gz','wt') as f:json.dump(outside_files(),f)
    print('PASS baseline',len(data['png']))

def render():
    import bpy, inspect, textwrap
    from mathutils import Matrix, Vector
    from bpy_extras.object_utils import world_to_camera_view
    import t2_build as t2, t3_build as t3, iso_rig as iso
    import cel_style as cel
    import cel_heroes_tocsin_build as original
    # Reuse the approved material sync and renderer; stop before its full driver.
    source=textwrap.dedent(inspect.getsource(original.render)).split("    if '--top-only'")[0]
    source=source.replace('def render():','def install_renderer():')
    source=source.replace('tuple(c*strength for c in color[:3])','tuple(c*strength/8 for c in color[:3])')
    ns=dict(original.__dict__); exec(compile(source,__file__,'exec'),ns); ns['install_renderer']()
    t3.OUT=OUT/'raw'; t3.setup(); t2.OUT=t3.OUT
    if CARILLON:
        from skin_tocsin_build import materials
        materials()
    cel.install('creature',normals=False)
    original.adapt(t2.render_tiles)
    t2.scene.eevee.taa_render_samples=8
    setup_scene=cel.setup_scene
    def action_samples(scene=None,samples=8):return setup_scene(scene,samples=4 if getattr(t2,'current_animation','')=='cast' else 8)
    cel.setup_scene=action_samples
    elbows={}
    for key,side in [('arm_l',-1),('arm_r',1)]:
        part=t2.mods[key];elbow=bpy.data.objects.new('Action elbow '+key,None)
        bpy.context.scene.collection.objects.link(elbow);elbow.parent=part;elbow.location=(side*.16,-.02,-.21)
        bpy.context.view_layer.update()
        for ob in list(part.children):
            if ob.type=='MESH' and ob.name.startswith(('Bronze forearm','Visible piston','Tube collar','Wrist swivel','Three jointed')):
                matrix=ob.matrix_world.copy();ob.parent=elbow;ob.matrix_world=matrix
        elbows[key]=elbow
    wrist=next(o for o in t2.mods['arm_l'].children_recursive if o.type=='MESH' and o.name.startswith('Wrist swivel'))
    wrist_center=sum((Vector(v) for v in wrist.bound_box),Vector())/8
    furnace=next(o for o in t2.mods['torso'].children_recursive if o.type=='MESH' and o.name.startswith('Living furnace'))
    furnace_center=sum((Vector(v) for v in furnace.bound_box),Vector())/8
    # Reuse sculpted steam ribbons on the boiler, visible even with the head attached.
    plume=bpy.data.objects.new('Action chimney pressure',None);bpy.context.scene.collection.objects.link(plume)
    plume.parent=t2.mods['torso'];plume.location=(.15,.11,1.10-t2.rest['torso'][0].z)
    for ob in t2.mods['neck_steam'].children_recursive:
        if ob.type=='MESH':
            copy=ob.copy();copy.data=ob.data.copy();bpy.context.scene.collection.objects.link(copy);copy.parent=plume
    # Panache de vapeur modélisé (pour attack/cast/throw_head) : amas de volutes lisses, clair + dessous sombre, enfants de plume.
    def vapor_material(name,color,alpha):
        mat=bpy.data.materials.new(name);mat.use_nodes=True;mat['cel_done']=True
        nodes=mat.node_tree.nodes;nodes.clear();links=mat.node_tree.links
        output=nodes.new('ShaderNodeOutputMaterial');mix=nodes.new('ShaderNodeMixShader')
        transparent=nodes.new('ShaderNodeBsdfTransparent');emit=nodes.new('ShaderNodeEmission')
        emit.inputs['Color'].default_value=(*color,1);mix.inputs[0].default_value=alpha
        links.new(transparent.outputs[0],mix.inputs[1]);links.new(emit.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],output.inputs[0])
        return mat
    vapor_light=vapor_material('Action vapor light',(.62,.60,.54),.92);vapor_dark=vapor_material('Action vapor dark',(.20,.21,.20),.88)
    for vx,vy,vz,vr in [(0,0,.16,.20),(.13,.05,.40,.25),(-.12,.02,.62,.23),(.06,-.07,.86,.28),(.24,.09,.66,.17),(-.21,-.05,.38,.17),(.0,.10,1.12,.20)]:
        for dark in (True,False):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=18,ring_count=11,radius=.36*vr*(1.1 if dark else 1.0),location=(0,0,0))
            puff=bpy.context.object;puff.data.materials.append(vapor_dark if dark else vapor_light)
            for polygon in puff.data.polygons:polygon.use_smooth=True
            for coll in list(puff.users_collection):coll.objects.unlink(puff)
            bpy.context.scene.collection.objects.link(puff);puff.parent=plume
            puff.location=(.36*vx,.36*vy,.36*(vz-(.07 if dark else 0)))
    # Transparent copies stay within their module so T2 isolates them correctly.
    ghosts=[]
    for key in ('arm_l','arm_r','head'):
        part=t2.mods[key]
        meshes=[o for o in part.children_recursive if o.type=='MESH']
        for j in range(2):
            mat=bpy.data.materials.new('Action smear '+key+str(j));mat.use_nodes=True;mat['cel_done']=True
            nodes=mat.node_tree.nodes;nodes.clear();links=mat.node_tree.links
            output=nodes.new('ShaderNodeOutputMaterial');mix=nodes.new('ShaderNodeMixShader')
            transparent=nodes.new('ShaderNodeBsdfTransparent');emit=nodes.new('ShaderNodeEmission')
            emit.inputs['Color'].default_value=(.19,.14,.09,1);mix.inputs[0].default_value=.21-.065*j
            links.new(transparent.outputs[0],mix.inputs[1]);links.new(emit.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],output.inputs[0])
            for ob in meshes:
                ghost=ob.copy();ghost.data=ob.data.copy();ghost.data.materials.clear();ghost.data.materials.append(mat)
                bpy.context.scene.collection.objects.link(ghost);ghost.parent=part
                ghosts.append((key,j,ob,ghost,part.matrix_world.inverted()@ob.matrix_world))
    # A pose wave on the bell: physical expansion, no drawn overlay.
    records={};fails=[]; base_pose=t3.old_pose
    def pose(anim,i):
        for ob in t2.mods.values():ob.scale=(1,1,1)
        base_pose('walk',0)
        for socket,value in t2.emissions:socket.default_value=value
        for elbow in elbows.values():elbow.rotation_euler=(0,0,0);elbow.scale=(1,1,1)
        plume.scale=(0,0,0)
        t3.firing.scale=(0,0,0)
        root=t2.root;torso=t2.mods['torso'];head=t2.mods['head'];steam=t2.mods['neck_steam']
        al=t2.mods['arm_l'];ar=t2.mods['arm_r'];ll=t2.mods['leg_l'];lr=t2.mods['leg_r']
        # Gait-ready recovery; all frame sequences retain some rigid-body motion.
        ll.rotation_euler.x=.13;lr.rotation_euler.x=-.13
        al.rotation_euler.x=-.12;ar.rotation_euler.x=.12
        steam.scale=(1.15,1.1,1.1+.12*math.sin(i*1.7));steam.rotation_euler.z=.2*math.sin(i)
        if anim=='attack':
            p=[-.4,-.95,-1.35,1.45,1.0,.1][i]
            root.location.y=.26*p;root.location.z=-.08*max(0,p)+.04*max(0,-p)
            root.location.x=.10*p
            torso.rotation_euler.x=.44*p;head.rotation_euler.x=-.3*p
            al.rotation_euler.x=[-.45,-1.1,-1.5,.75,.65,.12][i];ar.rotation_euler.x=al.rotation_euler.x
            al.rotation_euler.y=-[.45,.55,.6,.8,.7,.45][i];ar.rotation_euler.y=-al.rotation_euler.y
            for elbow in elbows.values():elbow.rotation_euler.x=[-1.0,-.55,-.3,-1.45,-1.35,-1.1][i]
            if i in (3,4):
                big=1.0 if i==3 else .78
                t3.firing.scale=(2.3*big,2.9*big,2.3*big);t3.firing.location=(0,-.53,.035)
                steam.scale=(2.1*big,1.8*big,2.0*big)
                plume.scale=(.72*big,.72*big,.72*big)
            elif i==5:plume.scale=(.4,.4,.4)
        elif anim=='cast':
            lift=[-2.0,-3.05,-1.65,-.60,-.60,-.13][i]
            al.rotation_euler.x=lift;al.rotation_euler.y=[-.25,.20,-.38,-.95,-.95,-.10][i]
            ar.rotation_euler.x=[-.45,-.45,-.35,.7,.7,.12][i]
            p=[-.5,-1.25,-.7,1.5,.95,.05][i]
            torso.rotation_euler.x=.26*p;torso.rotation_euler.z=-.2*p
            root.location=(.2*p,.12*p,-.2*max(0,p)+.05*max(0,-p))
            ll.rotation_euler.x=.22;lr.rotation_euler.x=-.22
            if i in (3,4):
                k=1.0 if i==3 else .8;torso.scale=(1+.18*k,1+.16*k,1-.14*k);steam.scale=(2.2*k,1.9*k,2.4*k);plume.scale=(1.0*k,1.0*k,1.0*k)
            elbows['arm_l'].rotation_euler.x=0 if i==1 else -1.30 if i in (3,4) else -.35
            if i==1:elbows['arm_l'].scale=(1,1,1.10)
        elif anim.startswith('throw_arm_'):
            side=1 if anim.endswith('_l') else -1;part=t2.mods[anim[6:]]
            p=[-.55,-1.1,1.2,.05][i]
            root.location=(.2*side*p,.16*p,-.09*max(0,p))
            torso.rotation_euler=(.4*p,.2*side*p,.7*side*p)
            part.rotation_euler.x=[-1.1,-2.4,1.3,-.12][i]
            part.rotation_euler.y=-side*.55;part.rotation_euler.z=side*[.7,1.4,-1.0,0][i]
            part.location.x+=side*[.08,.16,0,0][i];part.location.z+=[.04,.1,0,0][i]
            other=ar if side==1 else al;other.rotation_euler.x=-.6*p
            if i>=2:part.scale=(0,0,0)
        else:
            p=[.2,.55,1,-1,-.38,.04][i]
            torso.scale=(1+.2*max(0,p),1+.24*max(0,p),1+.1*max(0,p))
            torso.rotation_euler.x=-.3*p;root.location=(0,-.15*p,-.08*abs(p))
            al.rotation_euler.x=-[.5,1.15,1.6,1.8,1.35,.12][i]
            ar.rotation_euler.x=al.rotation_euler.x
            al.rotation_euler.y=-.5*abs(p);ar.rotation_euler.y=.5*abs(p)
            head.location.z+=[0,.07,.32,0,0,0][i]
            steam.scale=(1.2+.7*abs(p),1.2+.7*abs(p),1.2+.2*abs(p))
            if i>=3:head.scale=(0,0,0)
            plume.scale=(.3+.45*abs(p),)*3
        if anim=='cast':
            if i in (1,3,4):
                # Aim the actual wrist at the overhead hold or the moving boiler.
                # Telescope the original piston; the shoulder remains in its socket.
                al.rotation_euler=(0,0,0);joint=elbows['arm_l'];joint.scale=(1,1,1)
                bpy.context.view_layer.update();shoulder=al.matrix_world.translation.copy()
                target=root.matrix_world@Vector((0,-.015,1.53)) if i==1 else furnace.matrix_world@furnace_center+Vector((0,-.035,.05))
                desired=target-shoulder
                if i==1:
                    joint.rotation_euler=(0,0,0);lo,hi=1.0,2.5
                    for _ in range(9):
                        scale=(lo+hi)/2;joint.scale=(1,1,scale);bpy.context.view_layer.update()
                        distance=((wrist.matrix_world@wrist_center)-shoulder).length
                        if distance<desired.length:lo=scale
                        else:hi=scale
                else:
                    choices=[]
                    for angle in (0,-.4,-.8,-1.2,-1.6,-2,-2.4,-2.8):
                        joint.rotation_euler.x=angle;bpy.context.view_layer.update()
                        distance=((wrist.matrix_world@wrist_center)-shoulder).length
                        choices.append((abs(distance-desired.length),angle))
                    joint.rotation_euler.x=min(choices)[1]
                bpy.context.view_layer.update();actual=(wrist.matrix_world@wrist_center)-shoulder
                al.rotation_euler=actual.rotation_difference(desired).to_euler()
            compensation=Matrix.Rotation(-t2.DIRS[getattr(t2,'current_direction','e')],3,'Z')@root.location
            ll.location-=compensation;lr.location-=compensation
        for socket,value in t2.emissions: socket.default_value=value*(2 if i==HITS[anim] else 1)
        for key,j,ob,ghost,matrix in ghosts:
            ghost.matrix_local=matrix.copy()
            ghost.location.y+=(j+1)*.085;ghost.location.z+=(j+1)*.065
            ghost.rotation_euler.x+=(j+1)*.26
            show=anim!='attack' and i==HITS[anim]-1 and key==('arm_l' if anim=='cast' else anim[6:])
            ghost.hide_render=not show
        # T2.visible resets descendants; zero scaling keeps ghosts off other frames.
            ghost.scale=ob.scale if show else (0,0,0)
    t2.pose=pose
    if '--inspect-pose' in sys.argv:
        pose('cast',1);bpy.context.view_layer.update();summary={}
        for key in ('arm_l','head'):
            part=t2.mods[key];vertices=[ob.matrix_world@Vector(v) for ob in part.children_recursive if ob.type=='MESH' and not ob.name.startswith('Action') and max(ob.matrix_world.to_scale())>1e-6 for v in ob.bound_box]
            summary[key]={'rest':list(t2.rest[key][0]),'location':list(part.location),'z_range':[min(v.z for v in vertices),max(v.z for v in vertices)]}
        print(json.dumps(summary));return
    # Bounds preflight on actual module geometry at the contractual scale/pivot.
    iso.set_frame((192,192),'CREA');t2.scene.camera.data.shift_y=.21
    for anim,n in ANIMS.items():
        for d in DIRS:
            for i in range(n):
                t2.current_direction=d
                pose(anim,i);t2.root.rotation_euler.z=t2.DIRS[d];bpy.context.view_layer.update()
                points=[]
                for part in t2.mods.values():
                    for ob in part.children_recursive:
                        if ob.type!='MESH' or max(ob.matrix_world.to_scale())<1e-6:continue
                        for corner in ob.bound_box:
                            v=world_to_camera_view(t2.scene,t2.scene.camera,ob.matrix_world@Vector(corner));points.append((v.x*192,(1-v.y)*192))
                box=[min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)]
                records[f'{anim}/{d}/{i}']=box
                if not (min(box[:2])>=-24 and max(box[2:])<=216):fails.append((anim,d,i,[round(v) for v in box]))
    (OUT/'preflight.json').write_text(json.dumps(records))
    print('FAILS',len(fails),fails[:40])
    if '--preflight' in sys.argv:print('PASS preflight' if not fails else 'FAIL preflight',len(records));return
    print('WARN loose bounds',len(fails))
    bpy.context.preferences.filepaths.save_version=0
    version=1
    while (WORK/f'actions_work_{version}.blend').exists():version+=1
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/f'actions_work_{version}.blend'))
    total=0;signature=sha(Path(__file__))
    for anim,n in ANIMS.items():
        if '--cast-only' in sys.argv and anim!='cast':continue
        if '--cast-head-only' in sys.argv and anim not in ('cast','throw_head'):continue
        if '--head-only' in sys.argv and anim!='throw_head':continue
        if '--only-anims' in sys.argv and anim not in sys.argv[sys.argv.index('--only-anims')+1].split(','):continue
        total+=n*8
        t2.current_animation=anim
        for d in DIRS:
            if '--only-dir' in sys.argv and d!=sys.argv[sys.argv.index('--only-dir')+1]:continue
            for i in range(n):
                done=t3.OUT/anim/d/f'{i:02d}.done'
                if done.exists() and done.read_text()=='PASS '+signature and '--rerender' not in sys.argv:continue
                t2.current_direction=d;t2.render_tiles(anim,d,i);done.write_text('PASS '+signature)
    (OUT/'render_completed.json').write_text(json.dumps({'source_sha256':signature,'poses':total,'result':'PASS'}))
    try:from PIL import Image as _I
    except ImportError:_I=None
    clipped=[]
    if _I is None:print('CLIPPED skipped (no PIL)');return
    for q in (t3.OUT).rglob('*_??.png'):
        if q.stem.endswith('_e'):continue
        a=_I.open(q).convert('RGBA').getchannel('A');w,h=a.size
        if any(a.crop(b).getextrema()[1]>8 for b in ((0,0,w,1),(0,h-1,w,h),(0,0,1,h),(w-1,0,w,h))):clipped.append(str(q.relative_to(t3.OUT)))
    print('CLIPPED',len(clipped),clipped[:20])
    print(f'PASS render {total} poses / 7 layers',flush=True)

def fixed_positions(rects,size):
    """MaxRects, without rotation: retain each existing PNG's physical dimensions."""
    W,H=size
    for order in [lambda k:rects[k][0]*rects[k][1],lambda k:rects[k][1],lambda k:rects[k][0],lambda k:max(rects[k])]:
        free=[(0,0,W,H)];positions={}
        for key in sorted(rects,key=order,reverse=True):
            w,h=rects[key]
            fits=[(min(fw-w,fh-h),fw*fh-w*h,y,x) for x,y,fw,fh in free if w<=fw and h<=fh]
            if not fits:break
            _,_,y,x=min(fits);positions[key]=(x,y);next_free=[]
            for fx,fy,fw,fh in free:
                if x>=fx+fw or x+w<=fx or y>=fy+fh or y+h<=fy:next_free.append((fx,fy,fw,fh));continue
                if x>fx:next_free.append((fx,fy,x-fx,fh))
                if x+w<fx+fw:next_free.append((x+w,fy,fx+fw-x-w,fh))
                if y>fy:next_free.append((fx,fy,fw,y-fy))
                if y+h<fy+fh:next_free.append((fx,y+h,fw,fy+fh-y-h))
            free=[]
            for f in sorted(set(next_free)):
                if not any(f!=g and f[0]>=g[0] and f[1]>=g[1] and f[0]+f[2]<=g[0]+g[2] and f[1]+f[3]<=g[1]+g[3] for g in next_free):free.append(f)
        if len(positions)==len(rects):return positions
    raise AssertionError(('atlas cannot retain original dimensions',size,len(rects),sum(w*h for w,h in rects.values())))

def fixed_atlas(sheets,layout,size):
    from PIL import Image
    rects={tuple(f['region']):tuple(f['region'][2:]) for f in layout['frames']}
    # Passe d'amplitude : si les recadrages ne tiennent plus dans la taille d'origine, la hauteur grandit par pas de 8 px (<= +40 % de surface).
    W0,H0=size;positions=None
    for extra in range(0,int(H0*.4)+1,8):
        try:positions=fixed_positions(rects,[W0,H0+extra]);size=[W0,H0+extra];break
        except AssertionError:continue
    if positions is None:positions=fixed_positions(rects,size)
    packed={s:Image.new('RGBA',tuple(size)) for s in sheets}
    for region,(x,y) in positions.items():
        rx,ry,w,h=region
        for s,im in sheets.items():packed[s].paste(im.crop((rx,ry,rx+w,ry+h)),(x,y))
    result=json.loads(json.dumps(layout));result['size']=list(size)
    for f in result['frames']:
        region=tuple(f['region']);f['region']=[*positions[region],*region[2:]]
    return packed,result

def split_atlas(sheets,layout,size,raw_layout):
    """Spill to the existing source PNG rather than resizing a contractual atlas."""
    from PIL import Image
    try:return fixed_atlas(sheets,layout,size)
    except AssertionError:pass
    rects={tuple(f['region']):tuple(f['region'][2:]) for f in layout['frames']}
    kept={};positions={}
    for region in sorted(rects,key=lambda r:r[2]*r[3]):
        candidate=dict(kept);candidate[region]=rects[region]
        try:new_positions=fixed_positions(candidate,size)
        except AssertionError:continue
        kept=candidate;positions=new_positions
    assert kept,('no crop fits',size)
    packed={s:Image.new('RGBA',tuple(size)) for s in sheets}
    for region,(x,y) in positions.items():
        rx,ry,w,h=region
        for s,im in sheets.items():packed[s].paste(im.crop((rx,ry,rx+w,ry+h)),(x,y))
    result=json.loads(json.dumps(layout));result['size']=list(size);result['spill_frames']=0
    for i,f in enumerate(result['frames']):
        region=tuple(f['region'])
        if region in kept:f['region']=[*positions[region],*region[2:]]
        else:
            f['region']=raw_layout['frames'][i]['region'];f['atlas']='source';result['spill_frames']+=1
    return packed,result

def source_atlas(sheets,layout,size):
    from PIL import Image
    n=layout['source_size'][0]//192;cw,ch=size[0]//n,size[1]//8
    if any(f['region'][2]>cw or f['region'][3]>ch for f in layout['frames']):return fixed_atlas(sheets,layout,size)
    result=json.loads(json.dumps(layout));result['size']=list(size)
    images={s:Image.new('RGBA',tuple(size)) for s in sheets}
    for row in range(8):
        for i in range(n):
            f=result['frames'][row*n+i];rx,ry,w,h=f['region'];x=i*cw+(cw-w)//2;y=row*ch+(ch-h)//2
            for suffix,im in sheets.items():images[suffix].paste(im.crop((rx,ry,rx+w,ry+h)),(x,y))
            f['region']=[x,y,w,h]
    return images,result

def finish():
    from PIL import Image
    import inspect
    import t5_build as t5
    from halve_emission import downscale
    before=json.loads((OUT/'before.json').read_text());orders=json.loads((BASE/'layers_order.json').read_text())['orders']
    stage=OUT/'stage';stage.mkdir(exist_ok=True);t5.GAME=stage;t5.PASSES=['','_e']
    # A one-pixel transparent gutter retains exact alpha while fitting the old PNGs.
    pack_source=inspect.getsource(t5.pack).replace(')-4',')-1').replace(')+4',')+1')
    exec(compile(pack_source,str(ROOT/'art/tools/night/t5_build.py'),'exec'),t5.__dict__)
    manifest=json.loads((OUT/'atlas_manifest.json').read_text());layouts={};exports={}
    def save(path,im):
        rel=path.relative_to(BASE).as_posix()
        if path.stem.endswith('_e'):
            if not any(c.getextrema()[1]>1 for c in im.split()[:3]):return
            im=downscale(im)
        im.save(path,optimize=True,compress_level=9)
        if rel in before['png']:
            assert list(im.size)==before['png'][rel]['size'],(rel,'size',im.size,before['png'][rel]['size'])
            assert path.stat().st_size<=before['png'][rel]['bytes']*1.6,(rel,'weight',path.stat().st_size,before['png'][rel]['bytes'])
    for anim,n in ANIMS.items():
        sheets={(k,s):Image.new('RGBA',(n*192,1536)) for k in PARTS for s in ('','_e')}
        full={s:Image.new('RGBA',(n*192,1536)) for s in ('','_e')}
        for row,d in enumerate(DIRS):
            for i in range(n):
                for k in orders[d]:
                    for suffix in ('','_e'):
                        path=OUT/'raw'/anim/d/f'{k}_{i:02d}{suffix}.png'
                        if not path.exists():assert suffix=='_e';continue
                        tile=Image.open(path).convert('RGBA');sheets[k,suffix].paste(tile,(i*192,row*192))
                        arm_hold=anim=='cast' and ((k=='arm_l' and i==4) or (k=='arm_r' and i in (0,4)))
                        stable=arm_hold or (k=='head' and anim in ('cast','throw_arm_l','throw_arm_r')) or k.startswith('leg_') or k=='neck_steam'
                        if stable:
                            donor_index=3 if k=='neck_steam' and anim=='throw_head' and i>=3 else 0
                            if arm_hold:donor_index=1 if i==0 else 3
                            donor_path=path.with_name(f'{k}_{donor_index:02d}{suffix}.png')
                            if donor_path.exists():
                                donor=Image.open(donor_path).convert('RGBA');a=tile.getchannel('A').getbbox();b=donor.getchannel('A').getbbox()
                                if a and b:
                                    dx=round((a[0]+a[2]-b[0]-b[2])/2);dy=round((a[1]+a[3]-b[1]-b[3])/2)
                                    tile=Image.new('RGBA',(192,192));tile.paste(donor,(dx,dy))
                                    sheets[k,suffix].paste(tile,(i*192,row*192))
                        if k!='neck_steam' or (anim=='throw_head' and i>=3):full[suffix].alpha_composite(tile,(i*192,row*192))
        # T5 crops are recomputed from the 192px native cells, including smear alpha.
        for layer in PARTS+['composite']:
            folder=stage/'layers'/layer;folder.mkdir(parents=True,exist_ok=True)
            for suffix in ('','_e'):
                im=full[suffix] if layer=='composite' else sheets[layer,suffix]
                if suffix and not any(c.getextrema()[1]>1 for c in im.split()[:3]):continue
                im.save(folder/(anim+suffix+'.png'),compress_level=6)
            layout=t5.pack(layer,anim)
            packed={s:Image.open(folder/'packed'/(anim+s+'.png')).convert('RGBA') for s in layout['passes']}
            dest=BASE if layer=='composite' else BASE/'layers'/layer
            oldsize=before['png'][(dest/(anim+'.png')).relative_to(BASE).as_posix()]['size']
            raw,raw_layout=source_atlas(packed,layout,oldsize)
            for suffix,im in raw.items():exports[dest/(anim+suffix+'.png')]=im
            if layer=='composite':layouts[layer,anim]=raw_layout
            else:
                packed_size=before['png'][(dest/'packed'/(anim+'.png')).relative_to(BASE).as_posix()]['size']
                final,final_layout=(raw,json.loads(json.dumps(raw_layout))) if packed_size==oldsize else split_atlas(packed,layout,packed_size,raw_layout)
                for suffix,im in final.items():exports[dest/'packed'/(anim+suffix+'.png')]=im
                layouts[layer,anim]=final_layout
                final_layout['source_atlas_size']=oldsize
                final_layout['source_frames']=raw_layout['frames']
                final_layout['bytes_after']=packed_size[0]*packed_size[1]*4*len(final)
                manifest[layer+'/'+anim]=final_layout
    # Cast ultimate is the exact existing alias, including every layer and mask.
    for path,im in list(exports.items()):
        if path.stem in ('cast','cast_e'):exports[path.with_name(path.name.replace('cast','cast_ult'))]=im.copy()
    for layer in PARTS+['composite']:
        layouts[layer,'cast_ult']=json.loads(json.dumps(layouts[layer,'cast']))
        if layer!='composite':manifest[layer+'/cast_ult']=layouts[layer,'cast_ult']
    # Everything is reviewable in art/ before changing the game assets.
    budget_errors=[]
    for path,im in exports.items():
        if path.stem in ('cast_ult','cast_ult_e'):continue
        rel=path.relative_to(BASE).as_posix()
        q=OUT/'exports'/rel;q.parent.mkdir(parents=True,exist_ok=True)
        if path.stem.endswith('_e'):im=downscale(im)
        im.save(q,optimize=True,compress_level=9)
        if rel in before['png']:
            assert im.size[0]*im.size[1]<=before['png'][rel]['size'][0]*before['png'][rel]['size'][1]*1.4,(rel,'size',im.size,before['png'][rel]['size'])
            budget=before['png'][rel]['bytes']*1.6
            if path.stem in ('cast','cast_e'):budget=min(budget,before['png'][rel.replace('cast','cast_ult')]['bytes']*1.6)
            if q.stat().st_size>budget:
                import subprocess,zipfile
                exe=WORK/'bin/pngquant.exe'
                if not exe.exists():
                    exe.parent.mkdir(exist_ok=True)
                    with zipfile.ZipFile(ROOT/'art/blender/characters/ardent_pngquant.zip') as archive:
                        for name in archive.namelist():
                            if name.endswith(('.exe','.dll')):(exe.parent/Path(name).name).write_bytes(archive.read(name))
                subprocess.run([str(exe),'256','--quality=85-100','--speed','1','--nofs','--force','--ext','.png',str(q)],check=True,capture_output=True)
            if q.stat().st_size>budget:budget_errors.append((rel,q.stat().st_size,before['png'][rel]['bytes']))
    for path in list(exports):
        if path.stem in ('cast','cast_e'):
            src=OUT/'exports'/path.relative_to(BASE);dst=src.with_name(src.name.replace('cast','cast_ult'))
            shutil.copy2(src,dst)
            rel=dst.relative_to(OUT/'exports').as_posix()
            if dst.stat().st_size>before['png'][rel]['bytes']*1.6:budget_errors.append((rel,dst.stat().st_size,before['png'][rel]['bytes']))
    (OUT/'layouts.json').write_text(json.dumps({k+'/'+a:v for (k,a),v in layouts.items()}))
    (OUT/'new_atlas_manifest.json').write_text(json.dumps(manifest,indent=2))
    (OUT/'budget_errors.json').write_text(json.dumps(budget_errors,indent=2))
    print('FAIL' if budget_errors else 'PASS','staged',len(exports),'PNG','budget_errors',len(budget_errors),flush=True)
    for error in budget_errors[:10]:print(error,flush=True)

def resource_exports():
    layouts=json.loads((OUT/'layouts.json').read_text());new_inventory=json.loads((OUT/'resource_animations.json').read_text())
    animation_re=r'\{"frames": \[(.*?)\], "loop": (true|false), "name": &"([^"]+)", "speed": ([0-9.]+)\}'
    inventory_changed=False;changed=[]
    for original in sorted(BASE.glob('tocsin*.tres')):
        data=(OUT/original.name).read_bytes();newline='\r\n' if b'\r\n' in data else '\n';s=data.decode().replace('\r\n','\n')
        # The old parts resource referenced a nonexistent black arm_ground mask.
        # A null emission frame preserves that clip without delivering a black PNG.
        missing=[]
        for m in re.finditer(r'\[ext_resource[^\n]*path="([^"]+)" id="([^"]+)"\][^\n]*\n',s):
            path=ROOT/'game'/m[1].removeprefix('res://')
            if not path.exists() and not (OUT/'exports'/path.relative_to(BASE)).exists():
                assert m[1].endswith('_e.png'),('missing diffuse',m[1]);missing.append((m[0],m[2]))
        for declaration,eid in missing:
            for rid,b in blocks(s).items():
                if 'atlas = ExtResource("'+eid+'")' in b:
                    s=s.replace(b,'').replace('SubResource("'+rid+'")','null')
            s=s.replace(declaration,'')
        ext={m[2]:m[1] for m in re.finditer(r'path="([^"]+)" id="([^"]+)"',s)};bs=blocks(s);replacements={};added=[]
        composite=original.name in ('tocsin.tres','tocsin_emission.tres');emission=original.stem.endswith('_emission')
        def set_block(rid,frame,scale=(1,1)):
            b=bs[rid];sx,sy=scale
            if frame.get('atlas')=='source':
                eid=re.search(r'atlas = ExtResource\("([^"]+)"\)',b)[1]
                rel=ext[eid].replace('/packed/','/');newid='source_'+eid
                if newid not in ext:
                    ext[newid]=rel;added.append('[ext_resource type="Texture2D" path="'+rel+'" id="'+newid+'"]\n\n')
                b=b.replace('atlas = ExtResource("'+eid+'")','atlas = ExtResource("'+newid+'")')
                scale=image_ratio(rel) if rel.endswith('_e.png') else (1,1);sx,sy=scale
            region=[v/(sx if j%2==0 else sy) for j,v in enumerate(frame['region'])]
            margin=[v/(sx if j%2==0 else sy) for j,v in enumerate(frame['margin'])]
            rect=lambda v:', '.join(f'{x:.8g}' for x in v)
            b=re.sub(r'region = Rect2\([^)]+\)','region = Rect2('+rect(region)+')',b)
            if 'margin = Rect2(' in b:b=re.sub(r'margin = Rect2\([^)]+\)','margin = Rect2('+rect(margin)+')',b)
            else:b=b.rstrip()+'\nmargin = Rect2('+rect(margin)+')\n'
            if rid in replacements:assert replacements[rid]==b,(original.name,rid,'shared differing frame')
            replacements[rid]=b
        def image_ratio(rel):
            from PIL import Image
            path=ROOT/'game'/rel.removeprefix('res://');q=OUT/'exports'/path.relative_to(BASE)
            if not q.exists():q=path
            dw,dh=Image.open(q.with_name(q.name.replace('_e.png','.png'))).size
            ew,eh=Image.open(q).size
            return dw/ew,dh/eh
        def clip_replace(m):
            name=m[3];anim,d=name.rsplit('_',1) if '_' in name else ('','')
            if anim not in TARGETS or d not in DIRS:return m[0]
            refs=re.findall(r'SubResource\("([^"]+)"\)',m[1]);a='cast' if anim=='cast_ult' else anim
            assert len(refs)==ANIMS[a],(original.name,name,len(refs))
            for i,rid in enumerate(refs):
                # Les spills du lot précédent pointaient vers l'atlas source : on revient à l'atlas packé avant de recalculer la région.
                cur=re.search(r'atlas = ExtResource\("([^"]+)"\)',bs[rid])[1]
                if cur.startswith('source_') and cur[7:] in ext:bs[rid]=bs[rid].replace('atlas = ExtResource("'+cur+'")','atlas = ExtResource("'+cur[7:]+'")')
                eid=re.search(r'atlas = ExtResource\("([^"]+)"\)',bs[rid])[1];rel=ext[eid]
                layer=rel.split('/layers/')[1].split('/')[0] if '/layers/' in rel else 'composite'
                frame=layouts[layer+'/'+anim]['frames'][DIRS.index(d)*len(refs)+i]
                set_block(rid,frame,image_ratio(rel) if emission else (1,1))
            speed=float(m[4]);frames=', '.join('{"duration": '+f'{F60[a][i]*speed/60:.8g}'+', "texture": SubResource("'+rid+'")}' for i,rid in enumerate(refs))
            return '{"frames": ['+frames+'], "loop": false, "name": &"'+name+'", "speed": '+m[4]+'}'
        s=re.sub(animation_re,clip_replace,s,flags=re.S)
        # Full-body throw images existed but their fallback clips were missing.
        if composite:
            for anim in ('throw_arm_l','throw_arm_r','throw_head'):
                if '"name": &"'+anim+'_e"' in s:continue
                eid='action_'+anim;rel='res://assets/sprites/characters/tocsin/'+anim+('_e' if emission else '')+'.png'
                ext[eid]=rel;added.append('[ext_resource type="Texture2D" path="'+rel+'" id="'+eid+'"]\n\n')
                for row,d in enumerate(DIRS):
                    refs=[]
                    for i in range(ANIMS[anim]):
                        rid='action_'+anim+'_'+d+'_'+str(i)
                        bs[rid]='[sub_resource type="AtlasTexture" id="'+rid+'"]\natlas = ExtResource("'+eid+'")\nregion = Rect2(0, 0, 1, 1)\n'
                        frame=layouts['composite/'+anim]['frames'][row*ANIMS[anim]+i]
                        set_block(rid,frame,image_ratio(rel) if emission else (1,1))
                        refs.append('{"duration": '+f'{F60[anim][i]*12/60:.8g}'+', "texture": SubResource("'+rid+'")}')
                    clip='{"frames": ['+', '.join(refs)+'], "loop": false, "name": &"'+anim+'_'+d+'", "speed": 12.0}'
                    s=s.rstrip();assert s.endswith(']');s=s[:-1].rstrip()+',\n'+clip+'\n]\n'
            for rid,b in replacements.items():
                if rid not in blocks(s):s=s.replace('[resource]',b+'\n[resource]',1)
        # Correct legacy emission coordinates against the actual half-size PNGs.
        counterpart=OUT/original.name.replace('_emission','')
        old_diff=blocks(counterpart.read_text()) if emission and counterpart.exists() else {}
        for rid,b in bs.items():
            if rid in replacements:continue
            eid=re.search(r'atlas = ExtResource\("([^"]+)"\)',b)
            if not eid or eid[1] not in ext or not ext[eid[1]].endswith('_e.png'):continue
            region=re.search(r'region = Rect2\(([^)]+)\)',b)
            diffregion=re.search(r'region = Rect2\(([^)]+)\)',old_diff.get(rid,''))
            if not diffregion or diffregion[1]!=region[1]:continue
            margin=re.search(r'margin = Rect2\(([^)]+)\)',b)
            frame={'region':[float(v) for v in region[1].split(',')], 'margin':[float(v) for v in margin[1].split(',')] if margin else [0,0,0,0]}
            set_block(rid,frame,image_ratio(ext[eid[1]]))
        s=re.sub(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n.*?(?=\n\[|\Z)',lambda m:replacements.get(m[1],m[0]),s,flags=re.S)
        used=set(re.findall(r'SubResource\("([^"]+)"\)',s))
        s=re.sub(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n.*?(?=\n\[|\Z)',lambda m:m[0] if m[1] in used else '',s,flags=re.S)
        if added:
            first=s.index('[sub_resource');s=s[:first]+''.join(added)+s[first:]
        count=1+len(re.findall(r'\[(?:ext_resource|sub_resource)\b',s));s=re.sub(r'load_steps=\d+','load_steps='+str(count),s,count=1)
        assert 'CanvasTexture' not in s and 'normal_texture' not in s,original.name
        names=re.findall(r'"name": &"([^"]+)"',s)
        if set(names)!=set(re.findall(r'"name": &"([^"]+)"',data.decode())):
            new_inventory[original.name]=names;inventory_changed=True
        encoded=s.replace('\n',newline).encode()
        if encoded!=data:
            q=OUT/'exports'/original.name;q.write_bytes(encoded);changed.append(original.name)
    if inventory_changed:(OUT/'exports/resource_animations.json').write_text(json.dumps(new_inventory,indent=2))
    shutil.copy2(OUT/'new_atlas_manifest.json',OUT/'exports/atlas_manifest.json')
    print('PASS resources',len(changed),'inventory_changed',inventory_changed)

def install():
    assert (OUT/'outside_before.json.gz').exists()
    assert json.loads((OUT/'verify_staged.json').read_text())['result']=='PASS','staged verification required'
    for p in (OUT/'exports').rglob('*'):
        if p.is_file():shutil.copy2(p,BASE/p.relative_to(OUT/'exports'))
    print('PASS installed')

if __name__=='__main__':
    if '--baseline' in sys.argv:baseline()
    elif '--render' in sys.argv:render()
    elif '--finish' in sys.argv:finish();resource_exports()
    elif '--install' in sys.argv:install()
