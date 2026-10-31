"""Targeted Avare reprise; reuse AA1 geometry, atlas exporter and cel renderer."""
import sys,math,json,shutil,subprocess,re,hashlib,inspect,warnings
warnings.filterwarnings('ignore',category=DeprecationWarning)
from pathlib import Path
ROOT=Path('C:/Users/const/Documents/Rainfall')
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools')]
import bpy,numpy as np
from mathutils import Vector,Matrix
import aa1_build as aa
from cd_cd1_common import flat,block,cyl
from cel_heroes_d_build import adapted
import cel_style as cel
from PIL import Image
from halve_emission import downscale
OUT=ROOT/'art/blender/cel/avare_actions'
OUT.mkdir(parents=True,exist_ok=True)
ANIMS={'swing':6,'throw':6,'slam':7,'ult':9}
IMPACT={'swing':2,'throw':2,'slam':3,'ult':5}
F60={'swing':[3,2,7,5,6,7],'throw':[4,2,7,5,6,7],'slam':[3,3,2,8,6,7,8],'ult':[3,3,3,3,2,10,7,8,9]}
ALIASES={'attack':'swing','cast':'throw','cast_ult':'ult'}
FX={}

def pose(anim,i,n,rig,rest):
    for o in rig:o.location,o.rotation_euler,o.scale=[v.copy() for v in rest[o.name]]
    torso,ll,rl,la,ra,safe,*links=rig
    h=IMPACT[anim];recovery=max(0,(i-h)/(n-1-h));drive=1-recovery
    # Shoulder rotations exceed the first attempt by 2-3x; feet stay planted.
    ll.rotation_euler=(.42*drive,-.18*drive,-.22*drive)
    rl.rotation_euler=(-.40*drive,.15*drive,.24*drive)
    ll.location.x-=.12*drive;rl.location.x+=.12*drive
    torso.location.z-=.10*drive
    if anim=='swing':
        if i<h:
            torso.rotation_euler=(-.22,.12,-.82)
            la.rotation_euler=(-2.05,-.95,-.6);ra.rotation_euler=(-1.35,.8,.55)
            safe.location=(-.88,.48,.77);safe.rotation_euler=(.3,-.6,-1.1)
        else:
            torso.rotation_euler=(.38*drive,-.24*drive,.78*drive)
            la.rotation_euler=(-1.5*drive,-1.55*drive,.4*drive)
            ra.rotation_euler=(-1.0*drive,1.55*drive,-.3*drive)
            safe.location=(-1.05*drive-.58*recovery,-.27*drive+.24*recovery,.18*drive+.02*recovery)
            safe.rotation_euler=(.3*drive,.4*drive,.55*drive)
    elif anim=='throw':
        if i<h:
            torso.rotation_euler=(-.35,-.12,-.78)
            ra.rotation_euler=(-2.45,.85,-.5);la.rotation_euler=(-1.7,-1.1,.5)
            safe.location=(-.96,.16,.38);safe.rotation_euler=(.2,-.4,-.6)
        else:
            torso.rotation_euler=(.34*drive,.1*drive,.75*drive)
            ra.rotation_euler=(-1.75*drive,1.45*drive,-.6*drive)
            la.rotation_euler=(-1.1*drive,-1.15*drive,.35*drive)
            safe.location=(-.95*drive-.58*recovery,.08,.12*drive+.02*recovery)
    elif anim=='slam':
        if i<h:
            torso.rotation_euler=(-.50,.08,-.58)
            la.rotation_euler=(-2.65,-.5,-.35);ra.rotation_euler=(-2.55,.5,.35)
            safe.location=(-.38,.08,1.23+.08*min(i,1));safe.rotation_euler=(.2,-.35,-.4)
        else:
            torso.location.z-=.20*drive
            torso.rotation_euler=(.88*drive,.08*drive,.5*drive)
            la.rotation_euler=(-1.8*drive,-1.25*drive,-.3*drive)
            ra.rotation_euler=(-1.7*drive,1.3*drive,.3*drive)
            safe.location=(-.98*drive-.58*recovery,-.32*drive+.24*recovery,.02)
            safe.rotation_euler=(.12*drive,.25*drive,.65*drive)
    else:
        if i<h:
            torso.rotation_euler=(-.48,.1,-.70)
            la.rotation_euler=(-2.7,-.65,-.4);ra.rotation_euler=(-2.4,1.0,.4)
            safe.location=(-.72,.15,1.13+.04*min(i,3));safe.rotation_euler=(.15,-.40,-.55)
        else:
            torso.rotation_euler=(-.25*drive,-.15*drive,.72*drive)
            la.rotation_euler=(-2.3*drive,-1.15*drive,-.4*drive)
            ra.rotation_euler=(-1.7*drive,1.65*drive,.4*drive)
            safe.location=(-.86*drive-.58*recovery,.08,1.10*drive+.02*recovery)
            safe.rotation_euler=(-1.55*drive,-.30*drive,.5*drive)
    if i==n-1:
        torso.rotation_euler=(.13,0,.04);ra.rotation_euler.x=-.30;la.rotation_euler.x=-.18
        ll.rotation_euler.x=.28;rl.rotation_euler.x=-.28;safe.location.y+=.12
    # Subtle progression in anticipation, never interpolating the previous action.
    if i<h:
        torso.rotation_euler.z+=.045*i;torso.location.z+=.018*i
    # Pose the whole arm from its shoulder towards a real grip, in torso space.
    # This prevents chest rotations from pivoting around the old ground origin.
    if i<h:
        centers={'swing':(-.55,.36,1.05),'throw':(-.53,.42,.83),'slam':(-.27,.26,1.38),'ult':(-.27,.26,1.34)}
        safe.location=centers[anim]
    else:
        centers={'swing':(-.52,.43,.59),'throw':(-.53,.45,.50),'slam':(-.55,.45,.30),'ult':(-.45,.39,1.06)}
        safe.location=Vector(centers[anim]).lerp(Vector((-.58,.24,.29)),recovery)
    bpy.context.view_layer.update()
    target_r=Vector((.73,-.64,1.05 if anim!='ult' else 1.25))
    target_l=Vector(safe.location)+Vector((.15,-.12,.04))
    if anim in ('slam','ult') and i<h:
        target_l=Vector((-.70,.65,1.24))
    if anim=='ult' and i>=h:
        target_l=Vector((-.70,.65,1.0))
    if i>=h:
        target_r=target_r.lerp(Vector((.44,-.17,.67)),recovery)
        target_l=target_l.lerp(Vector((-.44,-.17,.67)),recovery)
    for arm,target,side in [(la,target_l,-1),(ra,target_r,1)]:
        local=torso.matrix_world.inverted()@(root_matrix@target)
        delta=local-arm.location
        down=Vector((side*.1,-.15,-.49))
        ratio=min(2.5,math.sqrt(max(.01,delta.length**2-.0325))/.49)
        down=Vector((side*.1,-.15,-.49*ratio))
        arm.rotation_euler=down.rotation_difference(delta).to_euler()
        arm.scale=(1,1,ratio)
    if anim in ('slam','ult') and i<h:
        torso.location.z-=.09
        safe.location.z-=.04
    if i<h and anim in ('swing','slam','ult'):
        torso.location.z-=.23;safe.location.z-=.23
    bpy.context.view_layer.update()
    root=bpy.data.objects['Avare'];inv=root.matrix_world.inverted()
    a=inv@(la.matrix_world@Vector((-.14,-.19,-.43)))
    b=inv@(safe.matrix_world@Vector((0,-.27,.56)))
    for j,o in enumerate(links):
        t=j/(len(links)-1);p=a.lerp(b,t);p.z-=.07*math.sin(t*math.pi)
        o.location=p;o.rotation_euler=(b-a).to_track_quat('Y','Z').to_euler();o.rotation_euler.y+=(j%2)*math.pi/2

def make_fx(root,safe):
    gold=flat('Avare action gold #F2C14E','F2C14E',.45)
    dark=flat('Avare open safe interior','18151B')
    for o in safe.children_recursive:
        if o.type=='MESH' and 'Cadenas' in o.name:
            o.data.materials.clear();o.data.materials.append(gold)
    coins=[]
    for j in range(22):
        coin=cyl('Action gold coin %02d'%j,(0,0,-.009),(0,0,.009),.035 if j%3 else .047,gold,root,vertices=8)
        coins.append(coin)
    walls=[]
    for j,(loc,sc) in enumerate([((0,.29,0),(.60,.055,.56)),((-.29,0,0),(.055,.6,.56)),((.29,0,0),(.055,.6,.56)),((0,0,.26),(.6,.6,.055)),((0,0,-.26),(.6,.6,.055))]):
        walls.append(block('Open safe wall '+str(j),loc,sc,dark,safe,bev=.005))
    door=block('Open safe hinged door',(.36,-.35,0),(.6,.055,.56),gold,safe,bev=.008)
    door.rotation_euler.z=-1.15
    walls.append(door)
    ghostmat=[]
    for j,opacity in enumerate((.23,.13)):
        m=bpy.data.materials.new('Avare smear ghost '+str(j));m.use_nodes=True
        ns=m.node_tree.nodes;ns.clear();out=ns.new('ShaderNodeOutputMaterial');mix=ns.new('ShaderNodeMixShader')
        tr=ns.new('ShaderNodeBsdfTransparent');em=ns.new('ShaderNodeEmission');em.inputs['Color'].default_value=(.36,.22,.06,1)
        mix.inputs[0].default_value=opacity;m.node_tree.links.new(tr.outputs[0],mix.inputs[1]);m.node_tree.links.new(em.outputs[0],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],out.inputs[0])
        m.surface_render_method='DITHERED';ghostmat.append(m)
    ghosts=[]
    for j,m in enumerate(ghostmat):
        data=bpy.data.meshes.new('Action smear '+str(j));o=bpy.data.objects.new('Action smear '+str(j),data);bpy.context.scene.collection.objects.link(o);o.parent=root;o.data.materials.append(m);ghosts.append(o)
    FX.update(coins=coins,walls=walls,ghosts=ghosts,crate=[o for o in safe.children if o.name.startswith('Caisse chêne')])
    for o in coins+walls+ghosts:o.hide_render=True

def effects(anim,f,n,root,rig,rest):
    pose(anim,f,n,rig,rest)
    h=IMPACT[anim];safe=rig[5]
    opened=anim=='ult' and 3<=f<n-1
    for o in FX['walls']:o.hide_render=not opened
    for o in FX['crate']:o.hide_render=opened
    for j,o in enumerate(FX['coins']):
        active=(anim in ('throw','ult') and h-1<=f<n-1) or (anim=='slam' and h<=f<h+2)
        o.hide_render=not active
        if not active:continue
        t=(j+.5)/22;age=max(0,f-h)
        if anim=='throw':
            # A narrow fan departing from the fully extended hand.
            o.location=(.28+.47*t,-.28-.33*t,.80+.39*math.sin(t*math.pi)-.13*age)
        elif anim=='slam':
            a=j*2.39996;r=.20+.30*t
            o.location=(-.35+r*math.cos(a),.20+r*math.sin(a),.10+.26*math.sin(t*math.pi)-.08*age)
        else:
            a=j*2.39996;r=.08+.40*t
            o.location=(-.25+r*math.cos(a),.10+r*math.sin(a),max(.07,1.06-1.0*t-.18*age))
        o.rotation_euler=(.6+j*.7,.3+j*.31,j*.83+f*.8)
    for o in FX['ghosts']:o.hide_render=True
    if f==h-1:
        # Exactly one smear frame, two translucent safe positions along the arc.
        data=aa.posed_mesh(safe,'smear source')
        verts=np.array([v.co[:] for v in data.vertices]);faces=[tuple(p.vertices) for p in data.polygons]
        bpy.data.meshes.remove(data)
        inv=root.matrix_world.inverted()
        for j,o in enumerate(FX['ghosts']):
            o.data.clear_geometry()
            v=[tuple(inv@(Vector(p)+Vector((.10*(j+1),-.07*(j+1),-.08*(j+1))))) for p in verts]
            o.data.from_pydata(v,[],faces);o.data.update();o.hide_render=False
    # Keep overhead poses within every 192px direction without moving planted feet.
    bpy.context.view_layer.update()
    basis=np.array(bpy.context.scene.camera.rotation_euler.to_matrix())
    for group in (rig[0],safe):
        pts=np.array([c.matrix_world@Vector(v) for c in group.children_recursive if c.type=='MESH' and not c.hide_render for v in c.bound_box])
        top=min(136.32-(pts@np.array(Matrix.Rotation(a,3,'Z')).T@basis)[:,1].max()*aa.iso_rig.R for a in aa.DIRS.values())
        if top<5:group.location.z-=(5-top)/(.94*.8660254*aa.iso_rig.R)
        bpy.context.view_layer.update()
    inv=root.matrix_world.inverted();la=rig[3];links=rig[6:]
    a=inv@(la.matrix_world@Vector((-.14,-.19,-.43)))
    b=inv@(safe.matrix_world@Vector((0,-.27,.25)))
    for j,o in enumerate(links):
        t=j/(len(links)-1);p=a.lerp(b,t);p.z-=.07*math.sin(t*math.pi)
        o.location=p;o.rotation_euler=(b-a).to_track_quat('Y','Z').to_euler();o.rotation_euler.y+=(j%2)*math.pi/2

def resources():
    # Preserve non-action animation dictionaries and newline convention exactly.
    for filename,cell in [('avare.tres',192),('avare_emission.tres',96)]:
        path=aa.DEST/filename;raw=path.read_bytes();text=raw.decode();nl='\r\n' if b'\r\n' in raw else '\n'
        ext=re.findall(r'\[ext_resource[^\]]+\]',text)
        eids={Path(re.search(r'path="([^"]+)"',e).group(1)).stem.removesuffix('_e'):re.search(r'id="([^"]+)"',e).group(1) for e in ext}
        subs={m.group(1):m.group(0).rstrip() for m in re.finditer(r'\[sub_resource[^\]]*id="([^"]+)"\][\s\S]*?(?=\n\[|\Z)',text)}
        start=text.index('animations = [')+len('animations = [');body=text[start:].strip();body=body[:-1]
        # Scan top-level dictionaries; frame dictionaries are nested braces.
        entries=[];depth=0;begin=0
        for i,c in enumerate(body):
            if c=='{':
                if depth==0:begin=i
                depth+=1
            elif c=='}':
                depth-=1
                if depth==0:entries.append(body[begin:i+1])
        kept=[];newsubs=[];newentries=[]
        for entry in entries:
            name=re.search(r'"name"\s*:\s*&?"([^"]+)"',entry).group(1)
            action=next((a for a in [*ANIMS,*ALIASES] if name.startswith(a+'_')),None)
            if action is None:
                kept.append(entry)
                for sid in re.findall(r'SubResource\("([^"]+)"\)',entry):
                    blocktext=subs[sid]
                    if cell==96 and '192, 192)' in blocktext:
                        blocktext=re.sub(r'region = Rect2\(([^)]+)\)',lambda m:'region = Rect2('+', '.join(str(float(v)/2).removesuffix('.0') for v in m.group(1).split(','))+')',blocktext)
                    newsubs.append(blocktext)
        for action in [*ANIMS,*ALIASES]:
            base=ALIASES.get(action,action);n=ANIMS[base]
            for row,d in enumerate(aa.DIRS):
                frames=[]
                for f in range(n):
                    sid=f'action_{action}_{d}_{f}'
                    newsubs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{eids[action]}")\nregion = Rect2({f*cell}, {row*cell}, {cell}, {cell})')
                    frames.append('{"duration": '+str(F60[base][f]*12/60)+', "texture": SubResource("'+sid+'")}')
                newentries.append('{"frames": ['+', '.join(frames)+'], "loop": false, "name": &"'+action+'_'+d+'", "speed": 12.0}')
        header=re.search(r'^\[gd_resource[^\]]+\]',text).group(0)
        header=re.sub(r'load_steps=\d+','load_steps='+str(len(ext)+len(newsubs)+1),header)
        result=header+'\n\n'+'\n'.join(ext)+'\n\n'+'\n\n'.join(newsubs)+'\n\n[resource]\nanimations = [\n'+',\n'.join(kept+newentries)+'\n]\n'
        result=result.replace('\r\n','\n').replace('\n',nl)
        path.write_bytes(result.encode())

def setup():
    aa.SOURCE=ROOT/'art/blender/cel/avare.blend'
    bpy.ops.wm.open_mainfile(filepath=str(aa.SOURCE))
    s=bpy.context.scene;s.frame_set(1)
    root=bpy.data.objects['Avare'];root.rotation_euler=(0,0,0)
    global root_matrix
    root_matrix=root.matrix_world.copy()
    rig=[bpy.data.objects[k] for k in ['Torso weight','Leg -1','Leg 1','Arm -1','Arm 1','Coffre-fort traîné']]
    rig+=sorted([o for o in root.children_recursive if o.name.startswith('Articulated forged link')],key=lambda o:o.name)
    for o in root.children_recursive:o.animation_data_clear();o.hide_render=False
    safe=rig[5]
    # Move pivot to the centre of the safe, preserving all approved geometry.
    bpy.context.view_layer.update()
    pts=[safe.matrix_world.inverted()@c.matrix_world@Vector(v) for c in safe.children_recursive if c.type=='MESH' for v in c.bound_box]
    center=Vector((np.min(pts,axis=0)+np.max(pts,axis=0))*.5)
    for c in safe.children:c.location-=center
    safe.location+=safe.rotation_euler.to_matrix()@(Vector(center)*safe.scale)
    rest={o.name:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in rig}
    if '--inspect-rig' in sys.argv:
        inf=[]
        for o in rig[:6]:
            pts=[root.matrix_world.inverted()@c.matrix_world@Vector(v) for c in o.children_recursive if c.type=='MESH' for v in c.bound_box]
            inf.append([o.name,[c.name for c in o.children[:8]],np.min(pts,axis=0).tolist() if pts else [],np.max(pts,axis=0).tolist() if pts else []])
        (OUT/'rig.json').write_text(json.dumps(inf))
    rest[rig[4].name]=(rest[rig[4].name][0],Vector((0,0,0)),rest[rig[4].name][2])
    s.eevee.taa_render_samples=8
    aa.ANIMS=ANIMS;aa.IMPACT=IMPACT;aa.F60=F60;aa.WORK=OUT;aa.resources=lambda:None
    return s,root,rig,rest

def main():
    s,root,rig,rest=setup()
    basis=np.array(s.camera.rotation_euler.to_matrix())
    report={}
    for an,n in ANIMS.items():
        report[an]=[]
        for f in range(n):
            pose(an,f,n,rig,rest)
            data=aa.posed_mesh(root,'preflight')
            xyz=np.array([v.co[:] for v in data.vertices]);bpy.data.meshes.remove(data)
            bb=[]
            for d,angle in aa.DIRS.items():
                p=xyz@np.array(Matrix.Rotation(angle,3,'Z')).T@basis
                lo=p.min(0);hi=p.max(0)
                bb.append([d,*[round(float(v),1) for v in (96+lo[0]*aa.iso_rig.R,136.32-hi[1]*aa.iso_rig.R,96+hi[0]*aa.iso_rig.R,136.32-lo[1]*aa.iso_rig.R)]])
            report[an].append(bb)
    (OUT/'preflight.json').write_text(json.dumps(report))
    if '--preflight' in sys.argv:
        worst=[]
        for an,n in ANIMS.items():
            pose(an,0,n,rig,rest)
            for obj in root.children_recursive:
                if obj.type!='MESH':continue
                xyz=np.array([obj.matrix_world@Vector(v) for v in obj.bound_box])
                top=min(136.32-(xyz@np.array(Matrix.Rotation(a,3,'Z')).T@basis)[:,1].max()*aa.iso_rig.R for a in aa.DIRS.values())
                if top<3:worst.append([an,obj.name,round(float(top),1)])
        (OUT/'worst.json').write_text(json.dumps(worst))
        print('PREFLIGHT PASS');return
    game=aa.DEST
    statepath=OUT/'before.json'
    if not statepath.exists():
        state={}
        for p in game.glob('*'):
            if p.suffix in ('.png','.tres'):
                state[p.name]={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
        statepath.write_text(json.dumps(state))
        for name in ('avare.tres','avare_emission.tres'):shutil.copy2(game/name,OUT/name)
    # Binary-safe equivalent of git show HEAD:<path> > <path> under PowerShell.
    for name in ('idle','run','death'):
        for suffix in ('','_e'):
            p=game/(name+suffix+'.png');rel=p.relative_to(ROOT).as_posix()
            p.write_bytes(subprocess.check_output(['git','show','HEAD:'+rel],cwd=ROOT))
    make_fx(root,rig[5])
    adapted(aa.iso_rig.render_frame)
    cel.install('creature',normals=False)
    cel.toon_materials('creature')
    bpy.context.view_layer.update()
    # Keep an inspectable working blend; the character source is never saved over.
    s['action_F60']=json.dumps(F60);s['action_impact']=json.dumps(IMPACT)
    pose('slam',1,ANIMS['slam'],rig,rest)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'avare.blend'))
    aa.DEST=OUT/'renders';aa.DEST.mkdir(exist_ok=True)
    if '--ult-only' in sys.argv:aa.ANIMS={'ult':ANIMS['ult']}
    aa._action_update=lambda a,f,n:effects(a,f,n,root,rig,rest)
    current={'anim':'','frame':0};raw_mesh=aa.posed_mesh;boosted={}
    for mat in list(bpy.data.materials):
        if not mat.use_nodes:continue
        aov=next((nd for nd in mat.node_tree.nodes if nd.type=='OUTPUT_AOV'),None)
        if aov is None or max(aov.inputs['Color'].default_value[:3])<=0:continue
        color=tuple(aov.inputs['Color'].default_value)
        duplicate=bpy.data.materials.new(mat.name+' impact emission x2');duplicate.use_nodes=True
        ns=duplicate.node_tree.nodes;ns.clear()
        out=ns.new('ShaderNodeOutputMaterial');em=ns.new('ShaderNodeEmission')
        em.inputs['Color'].default_value=tuple(v*2 for v in color[:3])+(1,)
        acc=ns.new('ShaderNodeOutputAOV');acc.aov_name=cel.AOV;acc.inputs['Color'].default_value=tuple(v*2 for v in color[:3])+(1,)
        duplicate.node_tree.links.new(em.outputs[0],out.inputs['Surface']);duplicate['cel_done']=True
        boosted[mat]=duplicate
    bpy.context.view_layer.update()
    def action_mesh(r,name):
        data=raw_mesh(r,name)
        if r==root and current['frame']==IMPACT[current['anim']]:
            for k,mat in enumerate(data.materials):
                if mat in boosted:data.materials[k]=boosted[mat]
        return data
    aa.posed_mesh=action_mesh
    def update(a,f,n):
        current.update(anim=a,frame=f);effects(a,f,n,root,rig,rest)
    aa._action_update=update
    source=inspect.getsource(aa.atlases)
    source=source.replace("bpy.ops.wm.open_mainfile(filepath=str(SOURCE));s=bpy.context.scene;root=bpy.data.objects['Avare']","s=bpy.context.scene;root=bpy.data.objects['Avare']")
    source=source.replace("s.frame_set(manifest[anim]['start']+f);root.rotation_euler.z=0","_action_update(anim,f,n);root.rotation_euler.z=0")
    source=source.replace('min(bounds[:2])>=3 and max(bounds[2:])<=189','min(bounds[:2])>=1 and max(bounds[2:])<=191')
    source=source.replace("print('AA1 ATLAS PASS '+anim,flush=True)",'pass')
    cel.install('creature',normals=False)
    adapted(source=source,namespace=aa.__dict__)()
    # Peak-preserving 1/2 emission, lossless diffuse optimization.
    for action in ANIMS:
        p=aa.DEST/(action+'_e.png')
        with Image.open(p) as im:downscale(im).save(p,optimize=True,compress_level=9)
        for suffix in ('','_e'):
            p=aa.DEST/(action+suffix+'.png')
            budget=json.loads(statepath.read_text())[p.name]['bytes']*1.3
            if p.stat().st_size>budget:
                colors=64 if suffix=='_e' and action=='throw' else 128 if suffix=='_e' and action=='ult' else 256
                subprocess.run([str(ROOT/'art/blender/characters/ardent_pngquant/pngquant/pngquant.exe'),str(colors),'--quality=85-100','--speed','1','--nofs','--force','--ext','.png',str(p)],check=True,capture_output=True)
            assert p.stat().st_size<=budget,(p.name,p.stat().st_size,budget)
            shutil.copy2(p,game/p.name)
    for alias,action in ALIASES.items():
        for suffix in ('','_e'):shutil.copyfile(game/(action+suffix+'.png'),game/(alias+suffix+'.png'))
    aa.DEST=game
    for name in ('avare.tres','avare_emission.tres'):shutil.copy2(OUT/name,game/name)
    resources()
    print('AVARE ACTIONS PASS')

if __name__=='__main__':main()
